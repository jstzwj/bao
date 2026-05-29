// 严格翻译自: src/cli/publish_command.zig
// bao publish - 发布包到 npm registry
package bao_cli.commands

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_http.*
import bao_hash.*
import bao_install.*
import bao_install.package_manager.CommandLineArguments
import bao_install.package_manager.CommandContext
import bao_libarchive.*
import std.convert.*

// ============================================================================
// publish 命令 - 对应 bun publish
// 严格翻译自: src/cli/publish_command.zig (PublishCommand)
// 核心流程: pack tarball → 验证包信息 → 认证检查 → 上传到 registry
//
// Bun publish 特性:
//   - 支持从 tarball 路径直接发布: bun publish path/to/tarball.tgz
//   - 支持从 workspace 发布
//   - 支持 --dry-run, --tag, --access, --otp
//   - 支持 tolerate-republish 跳过已存在的版本
//   - 支持 prepublish/publish/postpublish 生命周期脚本
//   - 支持 web 认证 (auth_url + done_url 轮询)
//   - 支持 OTP 重新认证
//   - 支持 bin 规范化 (string → object, directories.bin)
//   - 支持 README 内容嵌入
// ============================================================================

/// Publish 配置
/// 严格翻译自: src/cli/publish_command.zig PublishCommand.Context
public class PublishConfig {
    /// 包名
    public var packageName: String
    /// 包版本
    public var packageVersion: String
    /// tarball 绝对路径
    public var absTarballPath: String
    /// tarball 字节内容
    public var tarballBytes: Array<Byte>
    /// SHA1 校验和
    public var shasum: String
    /// SHA512 integrity
    public var integrity: String
    /// 是否使用 workspaces
    public var usesWorkspaces: Bool
    /// 规范化的包信息 JSON
    public var normalizedPkgInfo: String
    /// publish 生命周期脚本
    public var publishScript: ?String
    /// postpublish 生命周期脚本
    public var postpublishScript: ?String
    /// 脚本环境
    public var scriptEnv: DotEnvLoader
    /// 访问级别 (public / restricted)
    public var access: ?String

    public init() {
        packageName = ""
        packageVersion = ""
        absTarballPath = ""
        tarballBytes = []
        shasum = ""
        integrity = ""
        usesWorkspaces = false
        normalizedPkgInfo = ""
        publishScript = None
        postpublishScript = None
        scriptEnv = DotEnvLoader()
        access = None
    }
}

/// Publish 命令选项
/// 严格翻译自: src/cli/publish_command.zig PackageManager.CommandLineArguments.parse(.publish)
public class PublishOptions {
    /// 发布标签 (--tag, 默认 "latest")
    public var tag: String
    /// 访问级别 (--access: public / restricted)
    public var access: ?String
    /// 一次性密码 (--otp)
    public var otp: ?String
    /// 认证类型 (--auth-type: legacy / web)
    public var authType: String
    /// 干跑模式 (--dry-run)
    public var dryRun: Bool
    /// 允许重新发布 (--tolerate-republish)
    public var tolerateRepublish: Bool
    /// 静默模式
    public var silent: Bool
    /// tarball 路径 (位置参数)
    public var tarballPath: ?String

    public init() {
        tag = "latest"
        access = None
        otp = None
        authType = "legacy"
        dryRun = false
        tolerateRepublish = false
        silent = false
        tarballPath = None
    }
}

/// README 信息
/// 严格翻译自: src/cli/publish_command.zig PublishCommand.ReadmeInfo
public class ReadmeInfo {
    public var filename: String
    public var contents: String

    public init(filename: String, contents: String) {
        this.filename = filename
        this.contents = contents
    }
}

/// Publish 错误类型
/// 严格翻译自: Context.FromTarballError
public enum PublishError {
    | outOfMemory
    | missingPackageJSON
    | invalidPackageJSON
    | missingPackageName
    | missingPackageVersion
    | invalidPackageName
    | invalidPackageVersion
    | privatePackage
    | restrictedUnscopedPackage
    | needAuth
}

/// 访问级别
/// 严格翻译自: PackageManager.Options.Access
public enum AccessLevel {
    | `public`
    | restricted

    public static func fromStr(s: String): ?AccessLevel {
        if (s == "public") { return AccessLevel.`public` }
        if (s == "restricted") { return AccessLevel.restricted }
        return None
    }

    public operator func ==(right: AccessLevel): Bool {
        return match (this) {
            case `public` => match (right) { case `public` => true case _ => false }
            case restricted => match (right) { case restricted => true case _ => false }
        }
    }
    public operator func !=(right: AccessLevel): Bool { !(this == right) }
}

// ============================================================================
// Publish 命令执行器
// 严格翻译自: src/cli/publish_command.zig PublishCommand
//
// 对应 Bun:
//   pub const PublishCommand = struct {
//       pub fn exec(ctx: Command.Context) !void { ... }
//   }
// ============================================================================

public class PublishCommand {
    private var logger: Logger
    private var manager: ?PackageManager

    public init() {
        logger = Logger()
        manager = None
    }

    /// 执行 publish 命令
    // 严格翻译自: src/cli/publish_command.zig PublishCommand.exec
    //
    // Bun 原始流程:
    //   1. 解析命令行参数 (.publish)
    //   2. 初始化 PackageManager
    //   3. 如果有 tarball 路径参数 → fromTarballPath
    //     否则 → fromWorkspace (先 pack 再 publish)
    //   4. 调用 publish() 上传到 registry
    //   5. 运行 publish/postpublish 生命周期脚本
    public func execute(args: ArrayList<String>): Int64 {
        let opts = parseArgs(args)

        if (!opts.silent) {
            Output.prettyLn("<r><b>bao publish <r><d>v${Global.packageJsonVersionWithSha}<r>")
        }

        // 解析命令行参数
        let cli = CommandLineArguments.parseForPublish(opts)

        // 初始化 PackageManager
        let initResultOpt = CommandLineArguments.initForPublish(cli)
        if (initResultOpt.isNone()) {
            if (!opts.silent) {
                Output.errGeneric("missing package.json, nothing to publish")
            }
            return 1
        }
        let initResult = initResultOpt.getOrThrow()
        let (pm, originalCwd) = initResult
        manager = pm

        // 分支: 从 tarball 路径发布 vs 从 workspace 发布
        if (opts.tarballPath.isSome()) {
            // 从 tarball 路径发布
            // 严格翻译自: Context(false).fromTarballPath
            let config = fromTarballPath(opts.tarballPath.getOrThrow(), pm, opts)
            if (config.isNone()) { return 1 }
            let cfg = config.getOrThrow()
            let result = publish(cfg, opts, false)
            if (result == 0) {
                let versionDisplay = DependencyInfo.withoutBuildTag(cfg.packageVersion)
                let dryRunSuffix = if (opts.dryRun) { " (dry-run)" } else { "" }
                Output.prettyLn("\n<green> +<r> ${cfg.packageName}@${versionDisplay}${dryRunSuffix}")
            }
            return result
        } else {
            // 从 workspace 发布 (先 pack)
            // 严格翻译自: Context(true).fromWorkspace
            let config = fromWorkspace(pm)
            if (config.isNone()) { return 1 }
            let cfg = config.getOrThrow()

            // 删除临时 tarball
            // 严格翻译自: _ = bun.sys.unlink(context.abs_tarball_path)
            Sys.unlink(cfg.absTarballPath)

            let result = publish(cfg, opts, true)
            if (result == 0) {
                let versionDisplay = DependencyInfo.withoutBuildTag(cfg.packageVersion)
                let dryRunSuffix = if (opts.dryRun) { " (dry-run)" } else { "" }
                Output.prettyLn("\n<green> +<r> ${cfg.packageName}@${versionDisplay}${dryRunSuffix}")

                // 运行 publish/postpublish 生命周期脚本
                // 严格翻译自: publish_command.zig → publish_script / postpublish_script
                if (pm.options.`do`.runScripts) {
                    let absWorkspacePath = withoutTrailingSlash(
                        pm.originalPackageJsonPath.substring(
                            0, pm.originalPackageJsonPath.size - "package.json".size
                        )
                    )
                    cfg.scriptEnv.put("npm_command", "publish")

                    // 运行 publish 脚本
                    if (cfg.publishScript.isSome()) {
                        RunCommand.runPackageScriptForeground(
                            CommandContext(), cfg.publishScript.getOrThrow(), "publish", absWorkspacePath,
                            cfg.scriptEnv, ArrayList<String>(), pm.options.logLevel == InstallLogLevel.Silent.toInt64(), false
                        )
                    }

                    // 运行 postpublish 脚本
                    if (cfg.postpublishScript.isSome()) {
                        RunCommand.runPackageScriptForeground(
                            CommandContext(), cfg.postpublishScript.getOrThrow(), "postpublish", absWorkspacePath,
                            cfg.scriptEnv, ArrayList<String>(), pm.options.logLevel == InstallLogLevel.Silent.toInt64(), false
                        )
                    }
                }
            }
            return result
        }
    }

    /// 从 tarball 路径准备发布上下文
    // 严格翻译自: src/cli/publish_command.zig Context(false).fromTarballPath
    //
    // Bun 原始流程:
    //   1. 解析绝对路径
    //   2. 读取 tarball 文件
    //   3. 使用 Archive.Iterator 遍历 tarball 内容
    //   4. 提取 package.json 和 README
    //   5. 计算 unpacked_size 和 total_files
    //   6. 计算校验和 (SHA1 + SHA512)
    //   7. 构建规范化包信息
    private func fromTarballPath(path: String, pm: PackageManager, opts: PublishOptions): ?PublishConfig {
        let absPath = Path.resolve(path)

        // 读取 tarball
        let tarballBytes = BaoFile.readAllBytes(absPath)
        if (tarballBytes.isErr()) {
            logger.error("Failed to read tarball: '${path}'")
            return None
        }
        let bytes = tarballBytes.result().getOrThrow()
        let config = PublishConfig()
        config.absTarballPath = absPath
        config.tarballBytes = bytes

        var totalFiles: Int64 = 0
        var unpackedSize: Int64 = 0
        var maybePackageJsonContents: ?String = None
        var maybeReadme: ?ReadmeInfo = None

        // 从 tarball 中遍历并提取 package.json 和 README
        // 严格翻译自: Archive.Iterator 遍历
        Output.print("\n")

        let entriesOpt = Archiver.extractRawEntries(bytes)
        if (entriesOpt.isNone()) {
            logger.error("Failed to read tarball entries: '${path}'")
            return None
        }
        let entries = entriesOpt.getOrThrow()
        for (entry in entries) {
            let pathname = entry.pathname
            let size = entry.size

            unpackedSize += Math.max(0, size)
            if (entry.entryType == EntryType.File) {
                totalFiles += 1
            }

            // 去掉 "package/" 前缀 (npm 期望所有路径都有 package/ 前缀)
            let slashIdx = pathname.indexOfAny("/\\")
            if (slashIdx >= 0) {
                let stripped = pathname.substring(slashIdx + 1)
                if (stripped.size == 0) {
                    continue
                }

                let sizeStr = formatSize(size)
                Output.pretty("<b><cyan>packed<r> ${sizeStr} ${stripped}\n")

                if (entry.entryType != EntryType.File) {
                    continue
                }

                // 检查是否是根目录文件 (package.json, README 等)
                if (!stripped.containsAny("/\\")) {
                    let filename = stripped

                    // 检查 package.json
                    if (maybePackageJsonContents.isNone() &&
                        filename.equalsIgnoreCase("package.json")) {
                        maybePackageJsonContents = String.fromUtf8(entry.data)
                    }
                    // 检查 README
                    else if (maybeReadme.isNone() && isReadmeFilename(filename)) {
                        let readmeContents = String.fromUtf8(entry.data)
                        if (readmeContents.size > 0) {
                            maybeReadme = ReadmeInfo(filename, readmeContents)
                        }
                    }
                }
            } else {
                let sizeStr = formatSize(size)
                Output.pretty("<b><cyan>packed<r> ${sizeStr} ${pathname}\n")
            }
        }

        // 验证 package.json 存在
        let packageJsonContents = maybePackageJsonContents
        if (packageJsonContents.isNone()) {
            logger.error("failed to find package.json in tarball '${path}'")
            return None
        }

        // 解析 package.json
        // 严格翻译自: JSON.parsePackageJSONUTF8(source, manager.log, ctx.allocator)
        let parser = JsonParser()
        let json = parser.parse(packageJsonContents.getOrThrow())
        if (json.isNone()) {
            logger.error("failed to parse tarball package.json")
            return None
        }
        let root = json.getOrThrow()

        // 检查 private 字段
        let isPrivate = JsonHelper.getBool(root, "private") ?? false
        if (isPrivate) {
            logger.error("attempted to publish a private package")
            return None
        }

        // 检查 publishConfig
        let publishConfig = JsonHelper.getObject(root, "publishConfig")
        if (publishConfig.isSome()) {
            let pc = publishConfig.getOrThrow()
            if (opts.tag == "latest") {
                let tagVal = JsonHelper.getString(pc, "tag")
                if (tagVal.isSome()) {
                    opts.tag = tagVal.getOrThrow()
                }
            }
            if (opts.access.isNone()) {
                let accessVal = JsonHelper.getString(pc, "access")
                if (accessVal.isSome()) {
                    let a = accessVal.getOrThrow()
                    let accessLevel = AccessLevel.fromStr(a)
                    if (accessLevel.isNone()) {
                        Output.errGeneric("invalid `access` value: '${a}'")
                        return None
                    }
                    opts.access = Some(a)
                }
            }
        }

        // 获取 name
        let name = JsonHelper.getString(root, "name")
        if (name.isNone() || name.getOrThrow().isEmpty()) {
            logger.error("missing `name` string in package.json")
            return None
        }

        // 检查作用域包的 access 约束
        let isScoped = DependencyInfo.isScopedPackageName(name.getOrThrow())
        if (opts.access.isSome() && opts.access.getOrThrow() == "restricted" && !isScoped) {
            logger.error("unable to restrict access to unscoped package")
            return None
        }

        // 获取 version
        let version = JsonHelper.getString(root, "version")
        if (version.isNone() || version.getOrThrow().isEmpty()) {
            logger.error("missing `version` string in package.json")
            return None
        }

        config.packageName = name.getOrThrow()
        config.packageVersion = version.getOrThrow()

        // 计算校验和
        config.shasum = Sha1.hashHex(bytes)
        config.integrity = "sha512-" + Base64Encode.encode(Sha512.hash(bytes))

        // 构建规范化包信息
        config.normalizedPkgInfo = normalizedPackage(
            pm, config.packageName, config.packageVersion,
            root, packageJsonContents.getOrThrow(), config.shasum, config.integrity,
            maybeReadme
        )

        // 打印摘要
        var summaryStats = PackStats()
        summaryStats.totalFiles = totalFiles
        summaryStats.unpackedSize = unpackedSize
        summaryStats.packedSize = bytes.size
        summaryStats.printSummary(Some(config.shasum), Some(config.integrity), pm.options.logLevel == InstallLogLevel.Silent.toInt64())

        return config
    }

    /// 从 workspace 准备发布上下文
    // 严格翻译自: src/cli/publish_command.zig Context(true).fromWorkspace
    //
    // Bun 原始流程:
    //   1. 加载 lockfile
    //   2. 调用 Pack.pack() 打包
    //   3. 返回打包结果
    private func fromWorkspace(pm: PackageManager): ?PublishConfig {
        // 读取 package.json 验证
        let pkgContent = BaoFile.readAllText("package.json")
        if (pkgContent.isErr()) {
            logger.error("No package.json found from current directory")
            return None
        }
        let content = pkgContent.result().getOrThrow()

        let parser = JsonParser()
        let json = parser.parse(content)
        if (json.isNone()) {
            logger.error("Failed to parse package.json")
            return None
        }
        let root = json.getOrThrow()

        // 验证必要字段
        let name = JsonHelper.getString(root, "name")
        if (name.isNone()) {
            logger.error("missing `name` string in package.json")
            return None
        }
        if (name.getOrThrow().isEmpty()) {
            logger.error("package.json `name` field must be a non-empty string")
            return None
        }

        let version = JsonHelper.getString(root, "version")
        if (version.isNone()) {
            logger.error("missing `version` string in package.json")
            return None
        }
        if (version.getOrThrow().isEmpty()) {
            logger.error("package.json `version` field must be a non-empty string")
            return None
        }

        // 检查 private 字段
        let isPrivate = JsonHelper.getBool(root, "private") ?? false
        if (isPrivate) {
            logger.error("Attempted to publish a private package")
            return None
        }

        // 检查 publishConfig.access
        let publishConfig = JsonHelper.getObject(root, "publishConfig")
        if (publishConfig.isSome()) {
            let pc = publishConfig.getOrThrow()
            let accessVal = JsonHelper.getString(pc, "access")
            if (accessVal.isSome()) {
                let a = accessVal.getOrThrow()
                let accessLevel = AccessLevel.fromStr(a)
                if (accessLevel.isNone()) {
                    Output.errGeneric("invalid `access` value: '${a}'")
                    return None
                }
            }
        }

        // 检查作用域包的 access 约束
        let isScoped = DependencyInfo.isScopedPackageName(name.getOrThrow())
        if (pm.options.publishConfig.access.isSome() && pm.options.publishConfig.access.getOrThrow() == "restricted" && !isScoped) {
            logger.error("unable to restrict access to unscoped package")
            return None
        }

        // 查找 README
        let absWorkspacePath = withoutTrailingSlash(
            pm.originalPackageJsonPath.substring(
                0, pm.originalPackageJsonPath.size - "package.json".size
            )
        )
        let maybeReadme = findWorkspaceReadme(absWorkspacePath)

        // 使用 PackCommand 打包
        let packCmd = PackCommand()
        let packArgs = ArrayList<String>()
        if (pm.options.logLevel == InstallLogLevel.Silent.toInt64()) {
            packArgs.append("--silent")
        }
        let packResult = packCmd.execute(packArgs)

        // 生成 tarball 路径
        let pkgName = name.getOrThrow()
        let pkgVersion = version.getOrThrow()
        let tarballPath = PackFormatter.fmtTarballFilename(pkgName, pkgVersion)

        // 读取 tarball
        let config = PublishConfig()
        config.packageName = pkgName
        config.packageVersion = pkgVersion
        config.absTarballPath = Path.resolve(tarballPath)
        config.usesWorkspaces = true

        let tarballBytes = BaoFile.readAllBytes(config.absTarballPath)
        if (tarballBytes.isErr()) {
            logger.error("Failed to read created tarball")
            return None
        }
        let bytes = tarballBytes.result().getOrThrow()
        config.tarballBytes = bytes
        config.shasum = Sha1.hashHex(bytes)
        config.integrity = "sha512-" + Base64Encode.encode(Sha512.hash(bytes))

        // 构建规范化包信息
        config.normalizedPkgInfo = normalizedPackage(
            pm, config.packageName, config.packageVersion,
            root, content, config.shasum, config.integrity,
            maybeReadme
        )

        // 提取生命周期脚本
        let scripts = JsonHelper.getObject(root, "scripts")
        if (scripts.isSome()) {
            let scriptsObj = scripts.getOrThrow()
            config.publishScript = JsonHelper.getString(scriptsObj, "publish")
            config.postpublishScript = JsonHelper.getString(scriptsObj, "postpublish")
        }

        return config
    }

    /// 规范化包信息
    // 严格翻译自: src/cli/publish_command.zig PublishCommand.normalizedPackage
    //
    // Bun 原始流程:
    //   1. 设置 _id, _integrity, _nodeVersion, _npmVersion
    //   2. 设置 integrity, shasum
    //   3. 嵌入 README 内容
    //   4. 构建 dist 对象 (integrity, shasum, tarball URL)
    //   5. 规范化 bin (string → object, directories.bin)
    //   6. 序列化为 JSON
    private func normalizedPackage(
        pm: PackageManager, packageName: String, packageVersion: String,
        json: JsonValue, jsonSource: String, shasum: String, integrity: String,
        readme: ?ReadmeInfo
    ): String {
        let registry = pm.scopeForPackageName(packageName)
        let versionWithoutBuildTag = DependencyInfo.withoutBuildTag(packageVersion)

        let integrityFmt = "sha512-${integrity}"

        // 设置 npm 元数据字段
        // 严格翻译自: json.setString(allocator, "_id", ...)
        JsonHelper.setString(json, "_id", "${packageName}@${versionWithoutBuildTag}")
        JsonHelper.setString(json, "_integrity", integrityFmt)
        JsonHelper.setString(json, "_nodeVersion", "18.0.0")
        JsonHelper.setString(json, "_npmVersion", "10.8.3")
        JsonHelper.setString(json, "integrity", integrityFmt)
        JsonHelper.setString(json, "shasum", shasum)

        // 嵌入 README 内容到 registry 负载
        // 严格翻译自: if (readme) |r| { if (json.get("readme") == null) ... }
        if (readme.isSome()) {
            let r = readme.getOrThrow()
            if (JsonHelper.getField(json, "readme").isNone()) {
                JsonHelper.setString(json, "readme", r.contents)
                JsonHelper.setString(json, "readmeFilename", r.filename)
            }
        }

        // 构建 dist 对象
        // 严格翻译自: dist_props[0] = integrity, dist_props[1] = shasum, dist_props[2] = tarball
        let registryUrl = registry.url
        var registryHost = registryUrl
        if (registryHost.startsWith("https://")) { registryHost = registryHost.substring(8) }
        if (registryHost.startsWith("http://")) { registryHost = registryHost.substring(7) }
        registryHost = registryHost.removeTrailingSlash("/")
        let tarballFilename = PackFormatter.fmtTarballFilename(packageName, packageVersion)
        let tarballUrl = "http://${registryHost}/${packageName}/-/${tarballFilename}"

        // 构建 dist 对象
        let distObj = JsonValue.newObjectFrom([
            ("integrity", integrityFmt),
            ("shasum", shasum),
            ("tarball", tarballUrl)
        ])
        JsonHelper.setField(json, "dist", distObj)

        // 规范化 bin 字段
        // 严格翻译自: normalizeBin()
        normalizeBin(pm, json, packageName)

        // 序列化为 JSON (压缩)
        return JsonHelper.serializeMinified(json, jsonSource)
    }

    /// 规范化 bin 字段
    // 严格翻译自: src/cli/publish_command.zig PublishCommand.normalizeBin
    //
    // Bun 原始流程:
    //   1. 如果 bin 是字符串 → 转换为 { packageName: binPath }
    //   2. 如果 bin 是对象 → 验证每个条目的路径存在
    //   3. 如果没有 bin 但有 directories.bin → 扫描目录生成 bin 对象
    private func normalizeBin(pm: PackageManager, json: JsonValue, packageName: String): Unit {
        let binField = JsonHelper.getField(json, "bin")
        if (binField.isSome()) {
            let binValue = binField.getOrThrow()
            let binStr = binValue.asString()
            if (binStr.isSome()) {
                // bin 是字符串 → 转换为 { packageName: normalizedBinPath }
                var normalizedStr = Path.normalize(binStr.getOrThrow())
                if (normalizedStr.startsWith("./")) { normalizedStr = normalizedStr.substring(2) }
                let normalized = normalizedStr
                let workspaceRoot = pm.originalPackageJsonPath.substring(
                    0, pm.originalPackageJsonPath.size - "package.json".size
                )
                if (!Sys.existsAt(workspaceRoot, normalized)) {
                    Output.warn("bin '${normalized}' does not exist")
                }

                let binObj = JsonValue.newObjectFrom([(packageName, normalized)])
                JsonHelper.setField(json, "bin", binObj)
            } else if (binValue.isObject()) {
                // bin 是对象 → 验证每个条目
                let binObj = binValue
                let keys = binObj.keys()
                let newBinObj = JsonValue.newObject()
                for (key in keys) {
                    let value = binObj.getString(key)
                    if (value.isSome() && !value.getOrThrow().isEmpty()) {
                        var normalizedKeyStr = Path.normalize(key)
                        if (normalizedKeyStr.startsWith("./")) { normalizedKeyStr = normalizedKeyStr.substring(2) }
                        let normalizedKey = normalizedKeyStr
                        var normalizedValueStr = Path.normalize(value.getOrThrow())
                        if (normalizedValueStr.startsWith("./")) { normalizedValueStr = normalizedValueStr.substring(2) }
                        let normalizedValue = normalizedValueStr

                        let workspaceRoot = pm.originalPackageJsonPath.substring(
                            0, pm.originalPackageJsonPath.size - "package.json".size
                        )
                        if (!Sys.existsAt(workspaceRoot, normalizedValue)) {
                            Output.warn("bin '${normalizedValue}' does not exist")
                        }
                        JsonHelper.setString(newBinObj, normalizedKey, normalizedValue)
                    }
                }
                JsonHelper.setField(json, "bin", newBinObj)
            }
        } else {
            // 没有直接的 bin → 检查 directories.bin
            let directories = JsonHelper.getObject(json, "directories")
            if (directories.isSome()) {
                let dirs = directories.getOrThrow()
                let binDir = JsonHelper.getString(dirs, "bin")
                if (binDir.isSome() && !binDir.getOrThrow().isEmpty()) {
                    var normalizedBinDirStr = Path.normalize(binDir.getOrThrow())
                    if (normalizedBinDirStr.startsWith("./")) { normalizedBinDirStr = normalizedBinDirStr.substring(2) }
                    let normalizedBinDir = normalizedBinDirStr.removeTrailingSlash("/")

                    if (normalizedBinDir.size > 0) {
                        let workspaceRoot = pm.originalPackageJsonPath.substring(
                            0, pm.originalPackageJsonPath.size - "package.json".size
                        )

                        if (!Sys.existsAt(workspaceRoot, normalizedBinDir)) {
                            Output.warn("bin directory '${normalizedBinDir}' does not exist")
                        } else {
                            // 扫描 bin 目录生成 bin 对象
                            let binObj = JsonValue.newObject()
                            let entries = Sys.readDirRecursive(
                                Path.join([workspaceRoot, normalizedBinDir]), Int64(10)
                            )
                            for (entry in entries) {
                                let name = Path.basename(entry)
                                if (name.size == 0 || name == "." || name == "..") {
                                    continue
                                }
                                JsonHelper.setString(binObj, name, entry)
                            }
                            JsonHelper.setField(json, "bin", binObj)
                        }
                    }
                }
            }
        }
    }

    /// 在工作区目录中查找 README
    // 严格翻译自: src/cli/publish_command.zig PublishCommand.findWorkspaceReadme
    //
    // 匹配 npm 的 {README,README.*} glob (不区分大小写)
    public static func findWorkspaceReadme(absWorkspacePath: String): ?ReadmeInfo {
        let entries = Sys.readDir(absWorkspacePath)
        for (entry in entries) {
            if (BaoFile.isDirectory(Path.join([absWorkspacePath, entry]))) {
                continue
            }
            let name = entry
            if (!isReadmeFilename(name)) {
                continue
            }

            let contents = BaoFile.readAllText(Path.join([absWorkspacePath, name]))
            if (contents.isOk()) {
                return ReadmeInfo(name, contents.result().getOrThrow())
            }
            return None
        }
        return None
    }

    /// 检查文件名是否是 README (不区分大小写)
    // 严格翻译自: isReadmeFilenameT()
    public static func isReadmeFilename(name: String): Bool {
        let README = "README"
        if (name.size < README.size) { return false }
        if (!name.substring(0, README.size).equalsIgnoreCase(README)) { return false }
        return name.size == README.size || name[README.size] == UInt8(46)
    }

    /// 检查是否是 README (OS 路径字符)
    public static func isReadmeOSPath(name: String): Bool {
        return isReadmeFilename(name)
    }

    /// 构建发布请求头
    // 严格翻译自: src/cli/publish_command.zig PublishCommand.constructPublishHeaders
    //
    // Bun 原始流程:
    //   1. accept: */*
    //   2. accept-encoding: gzip,deflate
    //   3. authorization: Bearer/Basic token
    //   4. content-type: application/json (如果有 body)
    //   5. npm-auth-type: web/legacy
    //   6. npm-otp: (如果提供 OTP)
    //   7. npm-command: publish
    //   8. user-agent: bao/...
    //   9. Connection: keep-alive
    //   10. Host: registry host
    //   11. Content-Length: (如果有 body)
    private static func constructPublishHeaders(
        registry: RegistryInfo, maybeJsonLen: ?Int64, maybeOtp: ?String,
        usesWorkspaces: Bool, authType: ?String
    ): HashMap<String, String> {
        let headers = HashMap<String, String>()

        let npmAuthType = if (maybeOtp.isNone()) {
            authType ?? "web"
        } else {
            "legacy"
        }
        let ciName: ?String = None  // CI detection stub

        headers.put("accept", "*/*")
        headers.put("accept-encoding", "gzip,deflate")

        if (!registry.token.isEmpty()) {
            headers.put("authorization", "Bearer ${registry.token}")
        } else if (!registry.auth.isEmpty()) {
            headers.put("authorization", "Basic ${registry.auth}")
        }

        if (maybeJsonLen.isSome()) {
            headers.put("content-type", "application/json")
        }

        headers.put("npm-auth-type", npmAuthType)
        if (maybeOtp.isSome()) {
            headers.put("npm-otp", maybeOtp.getOrThrow())
        }
        headers.put("npm-command", "publish")

        let wsStr = if (usesWorkspaces) { "true" } else { "false" }
        let ciStr = if (ciName.isSome()) { " ci/${ciName.getOrThrow()}" } else { "" }
        headers.put("user-agent", "${Global.userAgent} ${Global.osName} ${Global.archName} workspaces/${wsStr}${ciStr}")

        headers.put("Connection", "keep-alive")
        headers.put("Host", registry.host)

        if (maybeJsonLen.isSome()) {
            headers.put("Content-Length", "${maybeJsonLen.getOrThrow()}")
        }

        return headers
    }

    /// 构建发布请求体
    // 严格翻译自: src/cli/publish_command.zig PublishCommand.constructPublishRequestBody
    //
    // Bun 原始流程:
    //   1. 构建 _id, name
    //   2. 构建 dist-tags: { tag: version }
    //   3. 构建 versions: { version: normalizedPkgInfo }
    //   4. 构建 access: public/restricted/null
    //   5. 构建 _attachments: { filename: { content_type, data (base64), length } }
    private static func constructPublishRequestBody(config: PublishConfig, opts: PublishOptions): String {
        let tag = if (opts.tag.size > 0) { opts.tag } else { "latest" }
        let encodedTarballLen = Base64Encode.encodeLen(config.tarballBytes.size)
        let versionWithoutBuildTag = DependencyInfo.withoutBuildTag(config.packageVersion)

        var buf = StringBuilder()

        // _id, name
        buf.append("{\"_id\":\"${config.packageName}\",\"name\":\"${config.packageName}\"")

        // dist-tags
        buf.append(",\"dist-tags\":{\"${tag}\":\"${versionWithoutBuildTag}\"}")

        // versions
        buf.append(",\"versions\":{\"${versionWithoutBuildTag}\":${config.normalizedPkgInfo}}")

        // access
        if (opts.access.isSome()) {
            buf.append(",\"access\":\"${opts.access.getOrThrow()}\"")
        } else {
            buf.append(",\"access\":null")
        }

        // _attachments
        let tarballFilename = PackFormatter.fmtTarballFilename(config.packageName, config.packageVersion)
        buf.append(",\"_attachments\":{\"${tarballFilename}\":{\"content_type\":\"application/octet-stream\",\"data\":\"")

        // Base64 编码 tarball
        let base64Data = Base64Encode.encode(config.tarballBytes)
        buf.append(base64Data)

        buf.append("\",\"length\":${config.tarballBytes.size}}}}")

        return buf.toString()
    }

    /// 执行发布到 registry
    // 严格翻译自: src/cli/publish_command.zig PublishCommand.publish
    //
    // Bun 原始流程:
    //   1. 获取 registry scope 和认证信息
    //   2. 检查认证 (token / auth)
    //   3. 如果 tolerate-republish, 检查版本是否已存在
    //   4. 打印 Tag/Access/Registry 信息
    //   5. 构建 发布请求体
    //   6. 构建 请求头
    //   7. PUT 请求发送到 registry
    //   8. 处理响应:
    //     - 401 → 检查 www-authenticate 头 → OTP 提示或 web 认证
    //     - 其他错误 → 显示错误信息
    //     - 成功 → 返回
    private func publish(config: PublishConfig, opts: PublishOptions, directoryPublish: Bool): Int64 {
        let pm = manager.getOrThrow()
        // 步骤1: 获取 registry 信息
        // 严格翻译自: ctx.manager.scopeForPackageName(package_name)
        let registry = pm.scopeForPackageName(config.packageName)

        // 步骤2: 检查认证
        // 严格翻译自: if (registry.token.len == 0 and ...) return error.NeedAuth
        if (registry.token.isEmpty() && registry.auth.isEmpty()) {
            Output.errGeneric("missing authentication (run <cyan>`bao x npm login`<r>)")
            return 1
        }

        // 步骤3: 检查 tolerate-republish
        // 严格翻译自: if (tolerate_republish) { checkPackageVersionExists(...) }
        if (opts.tolerateRepublish) {
            let versionWithoutBuildTag = DependencyInfo.withoutBuildTag(config.packageVersion)
            let exists = checkPackageVersionExists(
                config.packageName, versionWithoutBuildTag, registry
            )
            if (exists) {
                Output.warn("Registry already knows about version ${versionWithoutBuildTag}; skipping.")
                return 0
            }
        }

        // 打印发布信息
        // 严格翻译自:
        //   Output.pretty("Tag: {s}\nAccess: {s}\nRegistry: {s}\n", ...)
        let tagDisplay = if (opts.tag.size > 0) { opts.tag } else { "latest" }
        let accessDisplay = opts.access ?? "default"
        Output.pretty("<b><blue>Tag<r>: ${tagDisplay}\n")
        Output.pretty("<b><blue>Access<r>: ${accessDisplay}\n")
        Output.pretty("<b><blue>Registry<r>: ${registry.url}\n")

        // dry-run 在此停止
        if (opts.dryRun) {
            return 0
        }

        // 步骤4: 构建发布请求体
        let publishReqBody = constructPublishRequestBody(config, opts)

        // 步骤5: 构建发布 URL
        let registryUrl = registry.url.removeTrailingSlash("/")
        let encodedName = urlEncodePackageName(config.packageName)
        let publishUrl = "${registryUrl}/${encodedName}"

        // 步骤6: 构建请求头并发送 PUT 请求
        // 严格翻译自: http.AsyncHTTP.initSync(.PUT, ...)
        let publishHeaders = constructPublishHeaders(
            registry, publishReqBody.size, opts.otp,
            config.usesWorkspaces, opts.authType
        )

        let client = HttpClient()
        let resp = client.put(publishUrl, publishReqBody, publishHeaders)

        // 处理错误状态码
        if (resp.status >= 400) {
            // 检查是否需要 OTP
            // 严格翻译自: publish_command.zig → prompt_for_otp
            var promptForOtp = false
            if (resp.status == 401) {
                let wwwAuthenticate = resp.headers.get("www-authenticate")
                if (wwwAuthenticate.isSome()) {
                    let authHeader = wwwAuthenticate.getOrThrow()
                    let parts = authHeader.split(",")
                    var foundOtp = false
                    for (part in parts) {
                        let trimmed = part.trim()
                        if (trimmed.equalsIgnoreCase("ipaddress")) {
                            Output.errGeneric("login is not allowed from your IP address")
                            return 1
                        } else if (trimmed.equalsIgnoreCase("otp")) {
                            foundOtp = true
                        }
                    }
                    if (foundOtp) {
                        promptForOtp = true
                    } else {
                        Output.errGeneric("unable to authenticate, need: ${authHeader}")
                        return 1
                    }
                } else {
                    // 检查响应体中是否包含 "one-time pass"
                    if (resp.text().contains("one-time pass")) {
                        promptForOtp = true
                    }
                }
            }

            if (!promptForOtp) {
                // 通用错误
                Output.errGeneric("Publish failed with status ${resp.status}")
                if (!resp.text().isEmpty()) {
                    Output.errGeneric("Response: ${resp.text()}")
                }
                return 1
            }

            // 检查 npm-notice 头
            let notice = resp.headers.getIfOtherIsAbsent("npm-notice", "x-local-cache")
            if (notice.isSome()) {
                Output.prettyError("\n")
                Output.note("${notice.getOrThrow()}")
                Output.flush()
            }

            // 获取 OTP (交互式或 web 认证)
            let otp = getOTP(config, registry, resp, directoryPublish)

            // 使用 OTP 重试
            let otpHeaders = constructPublishHeaders(
                registry, publishReqBody.size, otp,
                config.usesWorkspaces, opts.authType
            )

            let otpResp = client.put(publishUrl, publishReqBody, otpHeaders)
            if (otpResp.status >= 400) {
                Output.errGeneric("Publish failed with status ${otpResp.status}")
                if (!otpResp.text().isEmpty()) {
                    Output.errGeneric("Response: ${otpResp.text()}")
                }
                return 1
            }
            // 成功 → 检查 npm-notice
            let otpNotice = otpResp.headers.getIfOtherIsAbsent("npm-notice", "x-local-cache")
            if (otpNotice.isSome()) {
                Output.prettyError("\n")
                Output.note("${otpNotice.getOrThrow()}")
                Output.flush()
            }
        }
        // 成功 (200, 201 等)
        return 0
    }

    /// 获取 OTP (一次性密码)
    // 严格翻译自: src/cli/publish_command.zig PublishCommand.getOTP
    //
    // Bun 原始流程:
    //   1. 尝试解析响应 JSON 中的 authUrl 和 doneUrl
    //   2. 如果有 authUrl → 显示认证 URL 框, 等待用户按 Enter 打开浏览器
    //   3. 轮询 doneUrl 直到获得 200 (成功) 或错误
    //   4. 返回 token
    //   5. 如果没有 web 认证 → 回退到经典 OTP 提示
    private func getOTP(
        config: PublishConfig, registry: RegistryInfo,
        response: Response, directoryPublish: Bool
    ): String {
        // 尝试解析响应 JSON
        let parser = JsonParser()
        let json = parser.parse(response.text())

        if (json.isSome()) {
            let root = json.getOrThrow()
            let authUrlStr = JsonHelper.getString(root, "authUrl")
            let doneUrlStr = JsonHelper.getString(root, "doneUrl")

            if (authUrlStr.isSome() && doneUrlStr.isSome()) {
                // Web 认证流程
                // 严格翻译自: Output.prettyln("Authenticate your account at...")
                Output.prettyLn("\nAuthenticate your account at (press <b>ENTER<r> to open in browser):\n")

                // 绘制认证 URL 框
                let horizontal = if (Output.enableAnsiColorsStdout) { "─" } else { "-" }
                let vertical = if (Output.enableAnsiColorsStdout) { "│" } else { "|" }
                let topLeft = if (Output.enableAnsiColorsStdout) { "┌" } else { "|" }
                let topRight = if (Output.enableAnsiColorsStdout) { "┐" } else { "|" }
                let bottomLeft = if (Output.enableAnsiColorsStdout) { "└" } else { "|" }
                let bottomRight = if (Output.enableAnsiColorsStdout) { "┘" } else { "|" }

                let padding = 1
                let width = padding * 2 + authUrlStr.getOrThrow().size

                Output.print("${topLeft}")
                for (_ in 0..width) { Output.print("${horizontal}") }
                Output.println("${topRight}")

                Output.print("${vertical}")
                for (_ in 0..padding) { Output.print(" ") }
                Output.pretty("<b>${authUrlStr.getOrThrow()}<r>")
                for (_ in 0..padding) { Output.print(" ") }
                Output.println("${vertical}")

                Output.print("${bottomLeft}")
                for (_ in 0..width) { Output.print("${horizontal}") }
                Output.println("${bottomRight}")
                Output.flush()

                // 在另一个线程等待用户按 Enter 后打开浏览器
                let authUrl = authUrlStr.getOrThrow()
                let doneUrl = doneUrlStr.getOrThrow()

                // 启动后台线程等待 Enter 键并打开浏览器
                spawn {
                    pressEnterToOpenInBrowser(authUrl)
                }

                // 构建认证请求头
                let authHeaders = constructPublishHeaders(
                    registry, None, None,
                    config.usesWorkspaces, None
                )

                // 轮询 doneUrl
                let client = HttpClient()
                while (true) {
                    let pollResp = client.get(doneUrl, authHeaders)
                    match (pollResp.status) {
                        case 202 =>
                            // 重试
                            let retryAfter = pollResp.headers.get("retry-after")
                            let nanoseconds = if (retryAfter.isSome()) {
                                let retryStr = retryAfter.getOrThrow()
                                let seconds = Int64.parse(retryStr.trim())
                                if (seconds > 0) { seconds * 1000 * 1000 * 1000 } else { 500 * 1000 * 1000 }
                            } else {
                                500 * 1000 * 1000
                            }
                            Sys.sleep(nanoseconds)
                            continue
                        case 200 =>
                            // 登录成功
                            let doneJson = parser.parse(pollResp.text())
                            if (doneJson.isNone()) {
                                Output.errGeneric("WebLogin: failed to parse response json")
                                return ""
                            }
                            let doneRoot = doneJson.getOrThrow()
                            let token = JsonHelper.getString(doneRoot, "token")
                            if (token.isSome()) {
                                return token.getOrThrow()
                            }
                            Output.errGeneric("WebLogin: missing `token` field in response json")
                            return ""
                        case _ =>
                            // 错误
                            Output.errGeneric("OTP polling failed with status ${pollResp.status}")
                            return ""
                    }
                }
            }
        }

        // 经典 OTP 提示
        // 严格翻译自: prompt(ctx.allocator, "\nThis operation requires a one-time password.\nEnter OTP: ", "")
        Output.print("\nThis operation requires a one-time password.\nEnter OTP: ")
        Output.flush()
        return Terminal.readLine()
    }

    /// 按 Enter 打开浏览器
    // 严格翻译自: pressEnterToOpenInBrowser()
    private static func pressEnterToOpenInBrowser(authUrl: String): Unit {
        // 等待用户按 Enter
        Terminal.waitForEnter()

        // 使用系统命令打开 URL
        Process.`spawn`(["open", authUrl], ".")
    }

    /// 检查版本是否已存在于 registry
    // 严格翻译自: src/cli/publish_command.zig checkPackageVersionExists
    //
    // Bun 原始流程:
    //   1. GET 请求获取包元数据
    //   2. 解析 JSON 检查 versions[version] 是否存在
    private func checkPackageVersionExists(packageName: String, version: String, registry: RegistryInfo): Bool {
        let url = "${registry.url.removeTrailingSlash("/")}/${urlEncodePackageName(packageName)}"

        let headers = HashMap<String, String>()
        headers.put("accept", "application/json")
        if (!registry.token.isEmpty()) {
            headers.put("authorization", "Bearer ${registry.token}")
        } else if (!registry.auth.isEmpty()) {
            headers.put("authorization", "Basic ${registry.auth}")
        }

        let client = HttpClient()
        let resp = client.get(url, headers)
        if (resp.status != 200) { return false }

        let parser = JsonParser()
        let json = parser.parse(resp.text())
        if (json.isNone()) { return false }
        let root = json.getOrThrow()

        // 检查 versions[version]
        let versions = JsonHelper.getObject(root, "versions")
        if (versions.isSome()) {
            let verObj = versions.getOrThrow()
            return verObj.get(version).isSome()
        }
        return false
    }

    /// 获取 registry 信息
    // 严格翻译自: ctx.manager.scopeForPackageName(package_name)
    private func getRegistry(packageName: String): RegistryInfo {
        let info = RegistryInfo()
        let pm = manager.getOrThrow()
        let scope = pm.scopeForPackageName(packageName)
        info.url = scope.url
        info.token = scope.token
        info.auth = scope.auth
        info.host = scope.url.host()
        return info
    }

    /// URL 编码包名
    private func urlEncodePackageName(name: String): String {
        return name.replace("/", "%2F")
    }

    /// 格式化字节大小
    private func formatSize(bytes: Int64): String {
        if (bytes < 1024) {
            return "${bytes} B"
        } else if (bytes < 1024 * 1024) {
            return "${bytes / 1024} kB"
        } else {
            return "${bytes / (1024 * 1024)} MB"
        }
    }

    /// 解析命令行参数
    private func parseArgs(args: ArrayList<String>): PublishOptions {
        let opts = PublishOptions()
        var i = 0
        while (i < args.size) {
            let arg = args[i]
            match (arg) {
                case "--tag" | "-t" =>
                    i++
                    if (i < args.size) {
                        opts.tag = args[i]
                    }
                case "--access" | "-a" =>
                    i++
                    if (i < args.size) {
                        opts.access = Some(args[i])
                    }
                case "--otp" =>
                    i++
                    if (i < args.size) {
                        opts.otp = Some(args[i])
                    }
                case "--auth-type" =>
                    i++
                    if (i < args.size) {
                        opts.authType = args[i]
                    }
                case "--dry-run" => opts.dryRun = true
                case "--tolerate-republish" => opts.tolerateRepublish = true
                case "--silent" => opts.silent = true
                case "--help" | "-h" =>
                    printPublishHelp()
                    return opts
                case _ =>
                    if (!arg.startsWith("-")) {
                        // 位置参数: tarball 路径
                        opts.tarballPath = Some(arg)
                    } else {
                        logger.warn("Unknown option: ${arg}")
                    }
            }
            i++
        }
        return opts
    }

    /// 打印 publish 命令帮助
    private func printPublishHelp(): Unit {
        println("Usage: bao publish [tarball] [options]")
        println("")
        println("Publish a package to the npm registry")
        println("")
        println("Options:")
        println("  --tag <tag>                   Tag for the release (default: latest)")
        println("  --access <public|restricted>  Access level for scoped packages")
        println("  --otp <code>                  One-time password for 2FA")
        println("  --auth-type <type>            Authentication type (legacy | web)")
        println("  --dry-run                     Don't actually publish")
        println("  --tolerate-republish          Skip if version already exists")
        println("  --silent                      Suppress output")
        println("  --help, -h                    Print this help")
    }
}

/// Registry 信息
/// 严格翻译自: src/cli/publish_command.zig 中的 Npm.Registry.Scope
public class RegistryInfo {
    /// Registry URL
    public var url: String
    /// 认证 token
    public var token: String
    /// Basic auth
    public var auth: String
    /// Host
    public var host: String

    public init() {
        url = "https://registry.npmjs.org"
        token = ""
        auth = ""
        host = "registry.npmjs.org"
    }
}

/// 包基本信息
/// 从 package.json 或 tarball 中提取
public class PackageBasicInfo {
    public var name: String
    public var version: String

    public init() {
        name = ""
        version = ""
    }
}

// ============================================================================
// HttpClient extensions for publish_command
// Adds instance method API over the static fetch API
// ============================================================================

extend HttpClient {
    /// PUT request as instance method
    public func put(url: String, body: String, headers: HashMap<String, String>): Response {
        let opts = FetchOptions()
        opts.method = "PUT"
        opts.body = Some(body)
        let h = Headers()
        for (k in headers.keys()) {
            h.set(k, headers.get(k) ?? "")
        }
        opts.headers = h
        return HttpClient.fetch(url, opts)
    }

    /// GET request as instance method
    public func get(url: String, headers: HashMap<String, String>): Response {
        let opts = FetchOptions()
        opts.method = "GET"
        let h = Headers()
        for (k in headers.keys()) {
            h.set(k, headers.get(k) ?? "")
        }
        opts.headers = h
        return HttpClient.fetch(url, opts)
    }
}

// Headers extension for publish_command
extend Headers {
    /// Get header value if another header is absent
    public func getIfOtherIsAbsent(name: String, otherName: String): ?String {
        let other = get(otherName)
        if (other.isSome()) { return None }
        return get(name)
    }
}
