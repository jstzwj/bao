// 严格翻译自: src/cli/upgrade_command.zig
// bao upgrade - 自升级 Bao 运行时
package bao_cli.commands

import bao_core.*
import bao_collections.*
import bao_install.*
import bao_io.*
import bao_path.*
import bao_http.*
import bao_sys.*
import std.convert.*

// ============================================================================
// upgrade 命令 - 对应 bun upgrade
// 严格翻译自: src/cli/upgrade_command.zig (UpgradeCommand)
// 核心流程: 获取最新版本 -> 下载 zip -> 解压 -> 替换可执行文件
// ============================================================================

/// 版本信息
/// 严格翻译自: src/cli/upgrade_command.zig Version struct
public class UpgradeVersion {
    /// 下载链接
    public var zipUrl: String
    /// 版本标签 (例: "bao-v0.2.0")
    public var tag: String
    /// 原始 JSON 响应缓冲
    public var rawBody: String
    /// 包大小 (字节)
    public var size: Int64

    public init(zipUrl: String, tag: String) {
        this.zipUrl = zipUrl
        this.tag = tag
        this.rawBody = ""
        this.size = 0
    }

    /// 从 tag 中提取可读版本号
    // 严格翻译自: Version.name()
    public func name(): ?String {
        if (tag.size <= "bao-v".size || !tag.startsWith("bao-v")) {
            if (tag == "canary") {
                // canary 构建使用时间戳哈希
                return "canary"
            }
            return Some(tag)
        }
        return Some(tag.substring("bao-v".size))
    }

    /// 检查是否是当前版本
    // 严格翻译自: Version.isCurrent()
    public func isCurrent(): Bool {
        return tag == "bao-v${BAO_VERSION}"
    }
}

/// 平台信息
/// 严格翻译自: src/cli/upgrade_command.zig platform_label, arch_label, triplet
public class PlatformInfo {
    /// 操作系统标识
    public static func osLabel(): String {
        // 仓颉运行时检测平台
        let os = Sys.osName()
        if (os.startsWith("Mac") || os.startsWith("Darwin")) {
            return "darwin"
        } else if (os.startsWith("Win")) {
            return "windows"
        } else if (os.startsWith("Linux")) {
            return "linux"
        }
        return "unknown"
    }

    /// CPU 架构标识
    public static func archLabel(): String {
        let arch = Sys.archName()
        if (arch.contains("aarch64") || arch.contains("arm64")) {
            return "aarch64"
        }
        return "x64"
    }

    /// 平台三元组 (例: "linux-x64", "darwin-aarch64")
    public static func triplet(): String {
        return osLabel() + "-" + archLabel()
    }

    /// 文件夹名称
    public static func folderName(): String {
        return "bao-" + triplet()
    }

    /// zip 文件名
    public static func zipFilename(): String {
        return folderName() + ".zip"
    }
}

/// upgrade 命令选项
public class UpgradeOptions {
    /// 使用 canary 频道
    public var canary: Bool
    /// 回退到 stable 频道
    public var stable: Bool
    /// 干跑模式 (不实际替换)
    public var dryRun: Bool
    /// 自定义 registry (用于下载)
    public var registry: ?String

    public init() {
        canary = false
        stable = false
        dryRun = false
        registry = None
    }
}

/// upgrade 命令执行器
/// 严格翻译自: src/cli/upgrade_command.zig UpgradeCommand
/// 核心流程:
///   1. 检查 GitHub Releases API 获取最新版本
///   2. 下载对应平台的 zip 文件
///   3. 解压到临时目录
///   4. 验证新版本二进制
///   5. 替换当前可执行文件
public class UpgradeCommand {
    private var logger: Logger
    /// 当前平台信息
    private var platform: PlatformInfo

    public init() {
        logger = Logger()
        platform = PlatformInfo()
    }

    /// 执行 upgrade 命令
    // 严格翻译自: src/cli/upgrade_command.zig UpgradeCommand.exec
    public func execute(args: ArrayList<String>): Unit {
        // 检查用户没有传包名 (upgrade 是升级 bao 自身, 不是升级包)
        for (arg in args) {
            if (!arg.startsWith("--")) {
                logger.error("This command upgrades Bao itself and does not take package names.")
                logger.info("Use `bao update ${arg}` instead.")
                return
            }
        }

        let opts = parseArgs(args)

        try {
            if (opts.canary) {
                upgradeCanary(opts)
            } else {
                upgradeStable(opts)
            }
        } catch (e: Exception) {
            logger.error("Bao upgrade failed: ${e.message}")
            logger.info("Please upgrade manually:")
            logger.info("  curl -fsSL https://bao.dev/install | bash")
        }
    }

    /// 升级到 stable 版本
    // 严格翻译自: src/cli/upgrade_command.zig _exec (stable path)
    private func upgradeStable(opts: UpgradeOptions): Unit {
        // 步骤1: 获取最新版本信息
        logger.info("Fetching latest version...")
        let version = getLatestVersion(opts)

        if (version.isNone()) {
            logger.error("Could not fetch latest version from GitHub")
            return
        }
        let ver = version.getOrThrow()
        let verName = ver.name()
        if (verName.isNone()) {
            logger.error("Could not determine version name")
        } else {
            let name = verName.getOrThrow()
            // 检查是否已是最新
            if (ver.isCurrent()) {
                logger.success("You're already on the latest version of Bao (${name})")
                return
            }

            logger.info("Bao v${name} is out! You're on v${BAO_VERSION}")

            // 步骤2: 下载 zip
            logger.info("Downloading...")
            let zipData = downloadZip(ver, opts)
            if (zipData.isNone()) {
                logger.error("Download failed")
            } else {
                let data = zipData.getOrThrow()
                if (data.size == 0) {
                    logger.error("Downloaded empty content")
                    return
                }

                if (opts.dryRun) {
                    logger.info("Dry run: would download ${data.size} bytes for v${name}")
                    return
                }

                // 步骤3: 解压到临时目录
                let tmpDir = extractToTemp(data, name)
                if (tmpDir.isNone()) {
                    logger.error("Extraction failed")
                } else {
                    let dir = tmpDir.getOrThrow()
                    // 步骤4: 验证
                    let verified = verifyBinary(dir, name)
                    if (verified) {
                        // 步骤5: 替换可执行文件
                        let replaced = replaceExecutable(dir)
                        if (replaced) {
                            logger.success("Upgraded to Bao v${name}!")
                            logger.info("What's new: https://bao.dev/blog/release-notes/${name}")
                        } else {
                            logger.error("Failed to replace executable")
                            logger.info("Please upgrade manually")
                        }
                    } else {
                        logger.error("Binary verification failed")
                    }
                    // 清理临时目录
                    BaoFile.removeRecursive(dir)
                }
            }
        }
    }

    /// 升级到 canary 版本
    // 严格翻译自: src/cli/upgrade_command.zig canary path
    private func upgradeCanary(opts: UpgradeOptions): Unit {
        logger.info("Upgrading to canary build...")
        let zipUrl = "https://github.com/bao-dev/bao/releases/download/canary/${PlatformInfo.zipFilename()}"
        let version = UpgradeVersion(zipUrl, "canary")
        // 复用 stable 的下载和替换流程
        let zipData = downloadZip(version, opts)
        if (zipData.isNone()) {
            logger.error("Canary build not available for this platform yet")
        } else {
            let data = zipData.getOrThrow()
            let tmpDir = extractToTemp(data, "canary")
            if (tmpDir.isNone()) {
                logger.error("Extraction failed")
            } else {
                let dir = tmpDir.getOrThrow()
                let replaced = replaceExecutable(dir)
                if (replaced) {
                    logger.success("Upgraded to latest canary build!")
                    logger.info("Report bugs: https://github.com/bao-dev/bao/issues")
                }
                BaoFile.removeRecursive(dir)
            }
        }
    }

    /// 从 GitHub API 获取最新版本
    // 严格翻译自: src/cli/upgrade_command.zig getLatestVersion
    private func getLatestVersion(opts: UpgradeOptions): ?UpgradeVersion {
        // 请求 GitHub Releases API
        let apiDomain = match (opts.registry) {
            case Some(reg) => reg
            case None => "api.github.com"
        }
        let apiUrl = "https://${apiDomain}/repos/bao-dev/bao/releases/latest"

        let client = HttpClient()
        let resp = client.get(apiUrl, HashMap<String, String>())
        if (resp.status == 200) {
            // 解析 JSON 响应
            let bodyBytes = resp.body.getOrThrow()
            let bodySb = StringBuilder()
            for (b in bodyBytes) {
                bodySb.append(String(Rune(UInt32(b))))
            }
            let bodyStr = bodySb.toString()
            let parser = JsonParser()
            let json = parser.parse(bodyStr)
            if (json.isSome()) {
                let root = json.getOrThrow()
                var tag = ""
                var zipUrl = ""
                var size: Int64 = 0

                // 提取 tag_name
                let tagOpt = JsonHelper.getString(root, "tag_name")
                if (tagOpt.isNone()) { return None }
                tag = tagOpt.getOrThrow()

                // 在 assets 中查找匹配平台的 zip
                let assetsArr = root.getArray("assets")
                if (assetsArr.isSome()) {
                    let assets = assetsArr.getOrThrow()
                    for (asset in assets) {
                        let contentType = JsonHelper.getString(asset, "content_type")
                        if (contentType.isSome()) {
                            let ct = contentType.getOrThrow()
                            if (ct == "application/zip") {
                                let assetName = JsonHelper.getString(asset, "name")
                                if (assetName.isSome()) {
                                    let n = assetName.getOrThrow()
                                    if (n == PlatformInfo.zipFilename()) {
                                        let dlUrl = JsonHelper.getString(asset, "browser_download_url")
                                        if (dlUrl.isSome()) { zipUrl = dlUrl.getOrThrow() }
                                        let sizeStr = JsonHelper.getString(asset, "size")
                                        if (sizeStr.isSome()) {
                                            size = Int64.parse(sizeStr.getOrThrow())
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if (tag.size > 0 && zipUrl.size > 0) {
                    let ver = UpgradeVersion(zipUrl, tag)
                    ver.rawBody = bodyStr
                    ver.size = size
                    return Some(ver)
                }
            }
        } else if (resp.status == 404) {
            logger.error("No releases found")
        } else if (resp.status == 403) {
            logger.error("GitHub rate limit exceeded. Set GITHUB_TOKEN env var.")
        } else {
            logger.error("GitHub returned status ${resp.status}")
        }
        return None
    }

    /// 下载 zip 文件
    // 严格翻译自: src/cli/upgrade_command.zig zip download section
    private func downloadZip(version: UpgradeVersion, opts: UpgradeOptions): ?Array<Byte> {
        let client = HttpClient()
        let resp = client.get(version.zipUrl, HashMap<String, String>())
        if (resp.status == 200) {
            if (resp.body.isSome()) {
                return Some(resp.body.getOrThrow())
            }
            return None
        }
        logger.error("Download failed with status ${resp.status}")
        return None
    }

    /// 解压到临时目录
    private func extractToTemp(data: Array<Byte>, versionName: String): ?String {
        let tmpDir = Sys.getTempDir()
        let extractDir = Path.join([tmpDir, "bao-upgrade-${versionName}"])

        // 创建目录
        BaoFile.mkdir(extractDir, true)

        // 写入 zip 文件
        let zipPath = Path.join([extractDir, "bao.zip"])
        BaoFile.writeAllBytes(zipPath, data)

        // 解压 (调用系统 unzip)
        let exitCode = Process.`spawn`(["unzip", "-q", "-o", zipPath], extractDir)
        if (exitCode == 0) {
            return Some(extractDir)
        }
        logger.error("Unzip failed with exit code ${exitCode}")
        return None
    }

    /// 验证新二进制文件
    private func verifyBinary(extractDir: String, versionName: String): Bool {
        let exeName = if (Sys.osName().startsWith("Win")) { "bao.exe" } else { "bao" }
        let folderName = PlatformInfo.folderName()
        let exePath = Path.join([extractDir, folderName, exeName])

        // 检查文件是否存在
        if (!BaoFile.exists(exePath)) {
            logger.error("Binary not found at ${exePath}")
            return false
        }

        // 运行 --version 验证
        let exitCode = Process.`spawn`([exePath, "--version"], extractDir)
        return exitCode == 0
    }

    /// 替换当前可执行文件
    // 严格翻译自: src/cli/upgrade_command.zig moveFileZ section
    private func replaceExecutable(extractDir: String): Bool {
        let currentExe = Sys.getExecutablePath()
        let exeName = if (Sys.osName().startsWith("Win")) { "bao.exe" } else { "bao" }
        let folderName = PlatformInfo.folderName()
        let newExePath = Path.join([extractDir, folderName, exeName])

        // 在 POSIX 上, 直接 move
        // 在 Windows 上, 需要先 rename 旧文件 (因为运行中的 exe 被锁)
        let os = Sys.osName()
        if (os.startsWith("Win")) {
            // Windows: rename old -> .outdated, then move new
            let outdated = currentExe + ".outdated"
            let renamed = BaoFile.rename(currentExe, outdated)
            if (!renamed) {
                logger.error("Could not rename current executable")
                return false
            }
            let moved = BaoFile.rename(newExePath, currentExe)
            if (!moved) {
                // 恢复
                BaoFile.rename(outdated, currentExe)
                logger.error("Could not move new executable")
                return false
            }
            return true
        } else {
            // POSIX: 直接覆盖
            return BaoFile.rename(newExePath, currentExe)
        }
    }

    /// 解析命令行参数
    private func parseArgs(args: ArrayList<String>): UpgradeOptions {
        let opts = UpgradeOptions()
        for (arg in args) {
            match (arg) {
                case "--canary" => opts.canary = true
                case "--stable" => opts.stable = true
                case "--dry-run" => opts.dryRun = true
                case "--help" | "-h" =>
                    printUpgradeHelp()
                    return opts
                case _ => logger.warn("Unknown option: ${arg}")
            }
        }
        return opts
    }

    /// 打印 upgrade 命令帮助
    private func printUpgradeHelp(): Unit {
        println("Usage: bao upgrade [options]")
        println("")
        println("Upgrade Bao to the latest version")
        println("")
        println("Options:")
        println("  --canary     Upgrade to canary build")
        println("  --stable     Upgrade to latest stable (default)")
        println("  --dry-run    Don't actually replace the binary")
        println("  --help, -h   Print this help")
    }
}
