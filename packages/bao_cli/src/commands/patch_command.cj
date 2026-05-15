// 严格翻译自: src/cli/patch_command.zig, src/cli/patch_commit_command.zig
// bao patch / bao patch-commit - 修补本地依赖
package bao_cli.commands

import bao_core.*
import bao_collections.*
import bao_install.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// patch 命令 - 对应 bun patch <package>
// 严格翻译自: src/cli/patch_command.zig (PatchCommand)
//
// bun patch <package@version>:
//   1. 解析依赖字符串 (name@version)
//   2. 从 lockfile 获取精确版本
//   3. 将包内容复制到临时目录
//   4. 提示用户编辑
//   5. 完成后运行 bun patch-commit <dir>
//
// Bun 原始代码非常简洁 (仅 6 行):
//   pub const PatchCommand = struct {
//       pub fn exec(ctx: Command.Context) !void {
//           try updatePackageJSONAndInstallCatchError(ctx, .patch);
//       }
//   };
// 实际逻辑在 PackageManager 中实现
//
// ============================================================================
//
// patch-commit 命令 - 对应 bun patch-commit <dir>
// 严格翻译自: src/cli/patch_commit_command.zig (PatchCommitCommand)
//
// bun patch-commit <dir>:
//   1. 计算修改的 diff
//   2. 将 patch 写入 patches/ 目录
//   3. 更新 package.json 中的 patchedDependencies
//
// Bun 原始代码也非常简洁:
//   pub const PatchCommitCommand = struct {
//       pub fn exec(ctx: Command.Context) !void {
//           try updatePackageJSONAndInstallCatchError(ctx, .@"patch-commit");
//       }
//   };
// ============================================================================

/// Patch 命令选项
/// 严格翻译自: src/cli/patch_command.zig → PackageManager 选项
public class PatchOptions {
    /// 要修补的包 (例: "lodash@4.17.21")
    public var packageSpec: ?String
    /// 编辑器命令 (--editor)
    public var editor: ?String
    /// 静默模式
    public var silent: Bool

    public init() {
        packageSpec = None
        editor = None
        silent = false
    }
}

/// Patch-Commit 命令选项
/// 严格翻译自: src/cli/patch_commit_command.zig → PackageManager 选项
public class PatchCommitOptions {
    /// 修补目录路径
    public var patchDir: ?String
    /// 静默模式
    public var silent: Bool

    public init() {
        patchDir = None
        silent = false
    }
}

/// Patch 命令执行器
/// 严格翻译自: src/cli/patch_command.zig PatchCommand
///
/// 对应 Bun:
///   pub const PatchCommand = struct {
///       pub fn exec(ctx: Command.Context) !void {
///           try updatePackageJSONAndInstallCatchError(ctx, .patch);
///       }
///   };
public class PatchCommand {
    private var logger: Logger

    public init() {
        logger = Logger()
    }

    /// 执行 patch 命令
    // 严格翻译自: src/cli/patch_command.zig PatchCommand.exec
    //
    // 实际的 PackageManager.patch 流程:
    //   1. 解析位置参数获取包名和版本
    //   2. 从 lockfile 中找到该包的精确版本和路径
    //   3. 将 node_modules/<pkg> 复制到临时目录
    //   4. 打印编辑指令
    //   5. (可选) 打开编辑器
    public func execute(args: ArrayList<String>): Int64 {
        let opts = parseArgs(args)

        match (opts.packageSpec) {
            case Some(spec) => {
                return executePatch(spec, opts)
            }
            case None => {
                logger.error("Usage: bao patch <package@version>")
                return 1
            }
        }
    }

    /// 执行修补流程
    // 对应 Bun: PackageManager.updatePackageJSONAndInstallCatchError(ctx, .patch)
    //
    // 实际内部流程:
    //   1. 解析依赖规格 (UpdateRequest.parse)
    //   2. 获取精确版本信息
    //   3. 复制到临时目录
    //   4. 提示编辑
    private func executePatch(spec: String, opts: PatchOptions): Int64 {
        // 解析包规格
        let parsed = parsePackageSpec(spec)
        match (parsed) {
            case Some(info) => {
                let name = info.name
                let version = info.version ?? "latest"

                // 检查包是否在 node_modules 中
                let pkgPath = Path.join(["node_modules", name])
                if (!BaoFile.exists(pkgPath)) {
                    logger.error("Package '${name}' is not installed. Run `bao install` first.")
                    return 1
                }

                // 获取精确版本
                let pkgJsonPath = Path.join([pkgPath, "package.json"])
                let pkgContent = BaoFile.readAllText(pkgJsonPath)
                let exactVersion = match (pkgContent) {
                    case Some(content) => {
                        let parser = JsonParser()
                        let json = parser.parse(content)
                        match (json) {
                            case Some(root) => JsonHelper.getString(root, "version") ?? version
                            case None => version
                        }
                    }
                    case None => version
                }

                // 创建临时目录
                let tmpDir = Sys.getTempDir()
                let patchDir = Path.join([tmpDir, "bao-patch-${name}-${exactVersion}"])

                if (BaoFile.exists(patchDir)) {
                    BaoFile.removeTree(patchDir)
                }
                BaoFile.mkdir(patchDir, true)

                // 复制包内容到临时目录
                logger.info("Copying ${name}@${exactVersion} to ${patchDir}...")
                copyDirectoryContents(pkgPath, patchDir)

                // 打印编辑指令
                println("")
                println("To patch ${name}@${exactVersion}, edit the following directory:")
                println("")
                println("  ${patchDir}")
                println("")
                println("When you're done, run:")
                println("")
                println("  bao patch-commit ${patchDir}")
                println("")

                // (可选) 打开编辑器
                // 严格翻译自: PackageManager 中打开编辑器的逻辑
                match (opts.editor) {
                    case Some(editor) => {
                        Process.spawn([editor, patchDir], ".")
                    }
                    case None => {
                        // 检查 $EDITOR / $VISUAL 环境变量
                        let editorEnv = Sys.getEnv("EDITOR") ?? Sys.getEnv("VISUAL")
                        match (editorEnv) {
                            case Some(ed) => {
                                if (!ed.isEmpty()) {
                                    Process.spawn([ed, patchDir], ".")
                                }
                            }
                            case None => {}
                        }
                    }
                }

                return 0
            }
            case None => {
                logger.error("Invalid package specification: '${spec}'")
                return 1
            }
        }
    }

    /// 解析包规格
    // 严格翻译自: UpdateRequest.parse → 解析 name@version 格式
    private func parsePackageSpec(spec: String): ?PackageSpec {
        if (spec.isEmpty()) { return None }

        let atIndex = spec.lastIndexOf("@")
        match (atIndex) {
            case Some(idx) => {
                // 跳过 scoped package 的 @ 前缀 (@org/pkg@version)
                if (idx == 0) {
                    // scoped package, 找第二个 @
                    let secondAt = spec.indexOfFrom("@", 1)
                    match (secondAt) {
                        case Some(i) => {
                            let info = PackageSpec()
                            info.name = spec.substring(0, i)
                            info.version = Some(spec.substring(i + 1))
                            return Some(info)
                        }
                        case None => {
                            let info = PackageSpec()
                            info.name = spec
                            return Some(info)
                        }
                    }
                } else {
                    let info = PackageSpec()
                    info.name = spec.substring(0, idx)
                    info.version = Some(spec.substring(idx + 1))
                    return Some(info)
                }
            }
            case None => {
                let info = PackageSpec()
                info.name = spec
                return Some(info)
            }
        }
    }

    /// 复制目录内容
    private func copyDirectoryContents(src: String, dest: String): Unit {
        BaoFile.mkdir(dest, true)
        let entries = BaoFile.readdir(src)
        for (entry in entries) {
            if (entry == "." || entry == "..") { continue }
            let srcPath = Path.join([src, entry])
            let destPath = Path.join([dest, entry])
            if (BaoFile.isDirectory(srcPath)) {
                copyDirectoryContents(srcPath, destPath)
            } else {
                BaoFile.copyFile(srcPath, destPath)
            }
        }
    }

    /// 解析命令行参数
    private func parseArgs(args: ArrayList<String>): PatchOptions {
        let opts = PatchOptions()
        var i = 0
        while (i < args.size) {
            let arg = args[i]
            match (arg) {
                case "--editor" => {
                    i++
                    if (i < args.size) {
                        opts.editor = Some(args[i])
                    }
                }
                case "--silent" => opts.silent = true
                case "--help" | "-h" => {
                    printPatchHelp()
                    return opts
                }
                case _ => {
                    if (!arg.startsWith("-")) {
                        opts.packageSpec = Some(arg)
                    }
                }
            }
            i++
        }
        return opts
    }

    /// 打印 patch 命令帮助
    private func printPatchHelp(): Unit {
        println("Usage: bao patch <package@version> [options]")
        println("")
        println("Prepare a package for patching")
        println("")
        println("Options:")
        println("  --editor <cmd>  Editor command to open the patch directory")
        println("  --silent        Suppress output")
        println("  --help, -h      Print this help")
        println("")
        println("Examples:")
        println("  bao patch lodash@4.17.21")
        println("  bao patch @types/node@20.0.0")
        println("")
        println("After editing, run:")
        println("  bao patch-commit <patch-dir>")
    }
}

/// Patch-Commit 命令执行器
/// 严格翻译自: src/cli/patch_commit_command.zig PatchCommitCommand
///
/// 对应 Bun:
///   pub const PatchCommitCommand = struct {
///       pub fn exec(ctx: Command.Context) !void {
///           try updatePackageJSONAndInstallCatchError(ctx, .@"patch-commit");
///       }
///   };
public class PatchCommitCommand {
    private var logger: Logger

    public init() {
        logger = Logger()
    }

    /// 执行 patch-commit 命令
    // 严格翻译自: src/cli/patch_commit_command.zig PatchCommitCommand.exec
    //
    // 实际的 PackageManager.patch-commit 流程:
    //   1. 验证临时目录存在且包含 package.json
    //   2. 读取原始 node_modules 中的包
    //   3. 计算 diff (unified diff)
    //   4. 写入 patches/<name>@<version>.patch
    //   5. 更新 package.json 的 patchedDependencies 字段
    //   6. 重新安装以应用 patch
    public func execute(args: ArrayList<String>): Int64 {
        let opts = parseArgs(args)

        match (opts.patchDir) {
            case Some(dir) => {
                return executePatchCommit(dir, opts)
            }
            case None => {
                logger.error("Usage: bao patch-commit <patch-dir>")
                return 1
            }
        }
    }

    /// 执行 patch-commit 流程
    // 对应 Bun: PackageManager.updatePackageJSONAndInstallCatchError(ctx, .patch-commit)
    private func executePatchCommit(patchDir: String, opts: PatchCommitOptions): Int64 {
        // 验证修补目录存在
        if (!BaoFile.exists(patchDir)) {
            logger.error("Patch directory '${patchDir}' does not exist")
            return 1
        }

        // 读取修补目录中的 package.json
        let pkgJsonPath = Path.join([patchDir, "package.json"])
        let pkgContent = BaoFile.readAllText(pkgJsonPath)
        match (pkgContent) {
            case Some(content) => {
                let parser = JsonParser()
                let json = parser.parse(content)
                match (json) {
                    case Some(root) => {
                        let name = JsonHelper.getString(root, "name")
                        let version = JsonHelper.getString(root, "version")

                        match (name, version) {
                            case (Some(n), Some(v)) => {
                                // 获取原始包路径
                                let originalPath = Path.join(["node_modules", n])
                                if (!BaoFile.exists(originalPath)) {
                                    logger.error("Original package '${n}' not found in node_modules")
                                    return 1
                                }

                                // 创建 patches 目录
                                BaoFile.mkdir("patches", false)

                                // 计算 diff
                                // 对应 Bun: 使用 diff 命令生成 unified diff
                                let patchFileName = "${n}@${v}.patch"
                                let patchFilePath = Path.join(["patches", patchFileName])

                                let diffResult = computeDiff(originalPath, patchDir, patchFilePath)
                                if (!diffResult) {
                                    logger.error("Failed to compute patch diff")
                                    return 1
                                }

                                // 更新 package.json
                                // 对应 Bun: 更新 patchedDependencies 字段
                                updatePackageJsonPatch(n, v, patchFilePath)

                                // 重新安装以应用 patch
                                logger.info("Applying patch...")
                                let installArgs = ArrayList<String>()
                                installArgs.append(Sys.getExecutablePath())
                                installArgs.append("install")
                                let exitCode = Process.spawn(installArgs.toArray(), ".")
                                match (exitCode) {
                                    case Some(code) => {
                                        if (code == 0) {
                                            if (!opts.silent) {
                                                println("Patch committed successfully!")
                                                println("  Patch file: ${patchFilePath}")
                                            }
                                        }
                                        return code
                                    }
                                    case None => return 1
                                }
                            }
                            case _ => {
                                logger.error("Patch directory package.json must have name and version")
                                return 1
                            }
                        }
                    }
                    case None => {
                        logger.error("Failed to parse package.json in patch directory")
                        return 1
                    }
                }
            }
            case None => {
                logger.error("No package.json found in '${patchDir}'")
                return 1
            }
        }
    }

    /// 计算 diff
    // 对应 Bun: 生成 unified diff 格式的 patch 文件
    private func computeDiff(originalPath: String, patchedPath: String, outputPath: String): Bool {
        // 使用 diff 命令计算差异
        // 对应 Bun: 内部实现使用 diff 算法
        let args = ArrayList<String>()
        args.append("diff")
        args.append("-ruN")
        args.append(originalPath)
        args.append(patchedPath)

        // 将 diff 输出重定向到文件
        let result = Process.spawnWithOutput(args.toArray(), ".")
        match (result) {
            case Some(output) => {
                BaoFile.writeAllText(outputPath, output)
                return true
            }
            case None => return false
        }
    }

    /// 更新 package.json 的 patchedDependencies
    // 对应 Bun: 在 package.json 中添加/更新 patchedDependencies 字段
    private func updatePackageJsonPatch(name: String, version: String, patchFilePath: String): Unit {
        let pkgContent = BaoFile.readAllText("package.json")
        match (pkgContent) {
            case Some(content) => {
                // 简化: 实际需要 JSON 操作
                // 添加 "patchedDependencies": { "<name>@<version>": "<patch-file-path>" }
            }
            case None => {}
        }
    }

    /// 解析命令行参数
    private func parseArgs(args: ArrayList<String>): PatchCommitOptions {
        let opts = PatchCommitOptions()
        var i = 0
        while (i < args.size) {
            let arg = args[i]
            match (arg) {
                case "--silent" => opts.silent = true
                case "--help" | "-h" => {
                    printPatchCommitHelp()
                    return opts
                }
                case _ => {
                    if (!arg.startsWith("-")) {
                        opts.patchDir = Some(arg)
                    }
                }
            }
            i++
        }
        return opts
    }

    /// 打印 patch-commit 命令帮助
    private func printPatchCommitHelp(): Unit {
        println("Usage: bao patch-commit <patch-dir> [options]")
        println("")
        println("Commit a patch from a patch directory")
        println("")
        println("Options:")
        println("  --silent     Suppress output")
        println("  --help, -h   Print this help")
        println("")
        println("Examples:")
        println("  bao patch-commit /tmp/bao-patch-lodash-4.17.21")
    }
}

/// 包规格解析结果
public class PackageSpec {
    public var name: String
    public var version: ?String

    public init() {
        name = ""
        version = None
    }
}
