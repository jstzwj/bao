// 严格翻译自: src/cli/install_completions_command.zig
package bao_cli

import bao_core.*
import bao_install.*
import bao_collections.*
import bao_io.*

// ============================================================================
// InstallCompletionsCommand — 安装 shell 补全命令
// 严格翻译自: src/cli/install_completions_command.zig
//
// 为 fish/zsh/bash 安装 bun 补全脚本, 安装 bunx 符号链接,
// 在 zsh 中自动配置 .zshrc 加载补全
// ============================================================================

/// install completions 命令
/// 对应 Bun: InstallCompletionsCommand
public class InstallCompletionsCommand {
    // bunx 名称
    private static let bunxName: String = "baox"

    /// 路径拼接辅助函数 (避免 Path 名称冲突)
    private static func joinPaths(parts: Array<String>): String {
        var result = ""
        var i: Int64 = 0
        while (i < parts.size) {
            let part = parts[i]
            if (part.isEmpty()) { i += 1; continue }
            if (result.size > 0 && !result.endsWith("/")) {
                result = result + "/"
            }
            if (i > 0 && part.startsWith("/")) {
                result = result + part.substring(1)
            } else {
                result = result + part
            }
            i += 1
        }
        return result
    }

    /// 执行安装补全命令
    /// 对应 Bun: InstallCompletionsCommand.exec()
    public static func exec(allocator: Allocator): Unit {
        // 静默失败于自动更新
        let failExitCode: Int32 = 1

        // 检测当前 shell
        var shell = Shell.unknown
        let shellName = Env.SHELL.getString()
        if (shellName.isSome()) {
            shell = Shell.fromEnv(shellName.getOrThrow())
        }

        // 获取当前工作目录
        let cwd = Sys.getcwd()

        // 安装 bunx 符号链接
        installBunxSymlink(cwd)

        // 根据 shell 类型安装补全
        match (shell) {
            case Shell.unknown =>
                Output.errGeneric("Unknown or unsupported shell. Please set $SHELL to one of zsh, fish, or bash.")
                Output.note("To manually output completions, run 'bao getcompletes'")
                Global.exit(failExitCode)
            case _ => ()
        }

        if (!Env.getBool("IS_BUN_AUTO_UPDATE")) {
            if (!Output.isStdoutTTY()) {
                Output.print(shell.completions())
                Global.exit(0)
            }
        }

        // 查找补全目录
        var completionsDir = ""
        let (outputDir, foundDir) = findCompletionsDir(shell, cwd, failExitCode)
        if (outputDir.isNone()) {
            Output.prettyErrorln("<r><red>error:<r> Could not find a directory to install completions in.\n")

            match (shell) {
                case Shell.zsh =>
                    Output.prettyErrorln("\nzsh tip: One of the directories in $fpath might work. If you use oh-my-zsh, try mkdir $HOME/.oh-my-zsh/completions; and bao completions again.\n.")
                case _ => ()
            }

            Output.printErrorln("Please either pipe it:\n   bao completions > /to/a/file\n\n Or pass a directory:\n\n   bao completions /my/completions/dir\n")
            Global.exit(failExitCode)
        }

        completionsDir = foundDir

        let filename = match (shell) {
            case Shell.fish => "bao.fish"
            case Shell.zsh => "_bao"
            case Shell.bash => "bao.completion.bash"
            case _ => "bao-completions"
        }

        // 写入补全文件
        let outputDirHandle = outputDir.getOrThrow()
        let outputFile = outputDirHandle.createFileZ(filename, true)
        if (outputFile.isNone()) {
            Output.prettyErrorln("<r><red>error:<r> Could not open ${filename} for writing")
            Global.exit(failExitCode)
        }

        let writeResult = outputFile.getOrThrow().writeAll(shell.completions())
        if (writeResult.isErr()) {
            Output.prettyErrorln("<r><red>error:<r> Could not write to ${filename}")
            Global.exit(failExitCode)
        }

        outputFile.getOrThrow().close()
        outputDirHandle.close()

        // zsh: 检查是否需要在 .zshrc 中加载补全文件
        match (shell) {
            case Shell.zsh =>
                let completionsPath = outputFile.getOrThrow().getFdPath()
                configureZshrc(completionsPath, failExitCode)
            case _ => ()
        }

        Output.prettyErrorln("<r><d>Installed completions to ${completionsDir}/${filename}<r>\n")
        Output.flush()
    }

    /// 查找补全目录
    /// 对应 Bun: 根据不同 shell 在多个位置搜索补全目录
    private static func findCompletionsDir(shell: Shell, cwd: String, failExitCode: Int32): (?DirectoryHandle, String) {
        var completionsDir = ""

        match (shell) {
            case Shell.fish =>
                // 检查 XDG_CONFIG_HOME
                let configDir = Env.get("XDG_CONFIG_HOME")
                if (configDir.isSome()) {
                    let dir = joinPaths([cwd,configDir.getOrThrow(), "./fish/completions"])
                    let handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle.isSome()) {
                        return (handle, dir)
                    }
                }

                // 检查 XDG_DATA_HOME
                let dataDir = Env.get("XDG_DATA_HOME")
                if (dataDir.isSome()) {
                    let dir = joinPaths([cwd,dataDir.getOrThrow(), "./fish/completions"])
                    let handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle.isSome()) {
                        return (handle, dir)
                    }
                }

                // 检查 HOME/.config/fish/completions
                let homeDir = Env.HOME.getString()
                if (homeDir.isSome()) {
                    let dir = joinPaths([cwd,homeDir.getOrThrow(), "./.config/fish/completions"])
                    let handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle.isSome()) {
                        return (handle, dir)
                    }
                }

                // 检查 macOS homebrew fish 路径
                if (Environment.IS_MAC) {
                    if (!Environment.IS_AARCH64) {
                        completionsDir = "/usr/local/share/fish/completions"
                        let handle = DirectoryHandle.openDirAbsolute(completionsDir)
                        if (handle.isSome()) {
                            return (handle, completionsDir)
                        }
                    } else {
                        completionsDir = "/opt/homebrew/share/fish/completions"
                        let handle = DirectoryHandle.openDirAbsolute(completionsDir)
                        if (handle.isSome()) {
                            return (handle, completionsDir)
                        }
                    }
                }

                // /etc/fish/completions
                completionsDir = "/etc/fish/completions"
                let etcHandle = DirectoryHandle.openDirAbsolute(completionsDir)
                if (etcHandle.isSome()) {
                    return (etcHandle, completionsDir)
                }
            case Shell.zsh =>
                // 检查 fpath 环境变量
                let fpath = Env.get("fpath")
                if (fpath.isSome()) {
                    let splitter = fpath.getOrThrow().split(' ')
                    for (dir in splitter) {
                        let handle = DirectoryHandle.openDirAbsolute(dir)
                        if (handle.isSome()) {
                            return (handle, dir)
                        }
                    }
                }

                // 检查 XDG_DATA_HOME
                let dataDir = Env.get("XDG_DATA_HOME")
                if (dataDir.isSome()) {
                    let dir = joinPaths([cwd,dataDir.getOrThrow(), "./zsh-completions"])
                    let handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle.isSome()) {
                        return (handle, dir)
                    }
                }

                // 检查 BUN_INSTALL
                let installDir = Env.get("BUN_INSTALL")
                if (installDir.isSome()) {
                    let handle = DirectoryHandle.openDirAbsolute(installDir.getOrThrow())
                    if (handle.isSome()) {
                        return (handle, installDir.getOrThrow())
                    }
                }

                // 检查 HOME 下的各种路径
                let homeDir = Env.HOME.getString()
                if (homeDir.isSome()) {
                    // oh-my-zsh/completions
                    let omzDir = joinPaths([cwd,homeDir.getOrThrow(), "./.oh-my-zsh/completions"])
                    let omzHandle = DirectoryHandle.openDirAbsolute(omzDir)
                    if (omzHandle.isSome()) {
                        return (omzHandle, omzDir)
                    }

                    // .bun
                    let bunDir = joinPaths([cwd,homeDir.getOrThrow(), "./.bun"])
                    let bunHandle = DirectoryHandle.openDirAbsolute(bunDir)
                    if (bunHandle.isSome()) {
                        return (bunHandle, bunDir)
                    }
                }

                // 尝试系统级路径
                let dirsToTry = [
                    "/usr/local/share/zsh/site-functions",
                    "/usr/local/share/zsh/completions",
                    "/opt/homebrew/share/zsh/completions",
                    "/opt/homebrew/share/zsh/site-functions"
                ]
                for (dir in dirsToTry) {
                    let handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle.isSome()) {
                        return (handle, dir)
                    }
                }
            case Shell.bash =>
                // 检查 XDG_DATA_HOME
                let dataDir = Env.get("XDG_DATA_HOME")
                if (dataDir.isSome()) {
                    let dir = joinPaths([cwd,dataDir.getOrThrow(), "./bash-completion/completions"])
                    let handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle.isSome()) {
                        return (handle, dir)
                    }
                }

                // 检查 XDG_CONFIG_HOME
                let configDir = Env.get("XDG_CONFIG_HOME")
                if (configDir.isSome()) {
                    let dir = joinPaths([cwd,configDir.getOrThrow(), "./bash-completion/completions"])
                    let handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle.isSome()) {
                        return (handle, dir)
                    }
                }

                // 检查 HOME 下的路径
                let homeDir = Env.HOME.getString()
                if (homeDir.isSome()) {
                    // oh-my-bash
                    let ombDir = joinPaths([cwd,homeDir.getOrThrow(), "./.oh-my-bash/custom/completions"])
                    let ombHandle = DirectoryHandle.openDirAbsolute(ombDir)
                    if (ombHandle.isSome()) {
                        return (ombHandle, ombDir)
                    }

                    // .bash_completion.d
                    let bcdDir = joinPaths([cwd,homeDir.getOrThrow(), "./.bash_completion.d"])
                    let bcdHandle = DirectoryHandle.openDirAbsolute(bcdDir)
                    if (bcdHandle.isSome()) {
                        return (bcdHandle, bcdDir)
                    }
                }

                // 尝试系统级路径
                let dirsToTry = [
                    "/opt/homebrew/share/bash-completion/completions/",
                    "/opt/local/share/bash-completion/completions/"
                ]
                for (dir in dirsToTry) {
                    let handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle.isSome()) {
                        return (handle, dir)
                    }
                }
            case _ => ()
        }

        return (None, "")
    }

    /// 安装 bunx 符号链接
    /// 对应 Bun: installBunxSymlink / installBunxSymlinkPosix
    private static func installBunxSymlink(cwd: String): Unit {
        // 如果 bunx 已经存在于 PATH 中则跳过
        let whichResult = Sys.which(bunxName)
        if (whichResult.isSome()) {
            return
        }

        // 获取当前可执行文件路径
        let exe = Sys.selfExePath()
        if (exe.isEmpty()) {
            return
        }

        let exeDir = joinPaths([exe, ".."])
        let target = "${exeDir}/${bunxName}"

        // 尝试在同一目录下创建符号链接
        if (tryCreateSymlink(exe, target)) {
            return
        }

        // 尝试 BUN_INSTALL/bin
        let installDir = Env.get("BUN_INSTALL")
        if (installDir.isSome()) {
            let installTarget = "${installDir.getOrThrow()}/bin/${bunxName}"
            if (tryCreateSymlink(exe, installTarget)) {
                return
            }
        }

        // 尝试 $HOME/.bun/bin
        let homeDir = Env.HOME.getString()
        if (homeDir.isSome()) {
            let homeTarget = "${homeDir.getOrThrow()}/.bun/bin/${bunxName}"
            if (tryCreateSymlink(exe, homeTarget)) {
                return
            }
        }

        // 尝试 $HOME/.local/bin
        if (homeDir.isSome()) {
            let localTarget = "${homeDir.getOrThrow()}/.local/bin/${bunxName}"
            if (tryCreateSymlink(exe, localTarget)) {
                return
            }
        }
    }

    /// 尝试创建符号链接
    private static func tryCreateSymlink(target: String, linkpath: String): Bool {
        return BaoFile.createSymlink(target, linkpath)
    }

    /// 配置 zsh .zshrc 以加载补全
    /// 对应 Bun: 检查 .zshrc 是否已包含补全路径, 否则追加
    private static func configureZshrc(completionsPath: String, failExitCode: Int32): Unit {
        var zshrcFilepath = IccStringBuilder()

        // 尝试按优先级打开 .zshrc
        let dotZshrc: ?FileHandle = openZshrc(zshrcFilepath)
        if (dotZshrc.isNone()) {
            // 需要告诉用户手动添加
            Output.prettyErrorln("<r>To enable completions, add this to your .zshrc:\n      <b>[ -s \"${completionsPath}\" ] && source \"${completionsPath}\"")
            return
        }

        // 读取 .zshrc 内容
        let inputSize = Math.max(dotZshrc.getOrThrow().getEndPos(), 65536)
        let buf = dotZshrc.getOrThrow().preadAll(0, inputSize)
        if (buf.isNone()) {
            Output.prettyErrorln("<r>To enable completions, add this to your .zshrc:\n      <b>[ -s \"${completionsPath}\" ] && source \"${completionsPath}\"")
            return
        }

        let contents = buf.getOrThrow()

        // 检查是否已包含补全路径
        if (contents.contains(completionsPath) || contents.contains("# bao completions\n")) {
            // 已存在, 无需添加
            dotZshrc.getOrThrow().close()
            return
        }

        // 追加补全加载行
        let extra = "\n# bao completions\n[ -s \"${completionsPath}\" ] && source \"${completionsPath}\"\n"
        dotZshrc.getOrThrow().pwriteAll(extra, contents.size)
        dotZshrc.getOrThrow().close()

        Output.prettyErrorln("<r><d>Enabled loading bao's completions in .zshrc<r>")
    }

    /// 打开 .zshrc 文件
    /// 对应 Bun: 按优先级查找 ZDOTDIR/.zshrc, HOME/.zshrc, HOME/.zshenv
    private static func openZshrc(outPath: IccStringBuilder): ?FileHandle {
        // ZDOTDIR/.zshrc
        let zdotDir = Env.get("ZDOTDIR")
        if (zdotDir.isSome()) {
            let path = "${zdotDir.getOrThrow()}/.zshrc"
            let handle = FileHandle.openReadWrite(path)
            if (handle.isSome()) {
                outPath.append(path)
                return handle
            }
        }

        // HOME/.zshrc
        let homeDir = Env.HOME.getString()
        if (homeDir.isSome()) {
            let path = "${homeDir.getOrThrow()}/.zshrc"
            let handle = FileHandle.openReadWrite(path)
            if (handle.isSome()) {
                outPath.append(path)
                return handle
            }
        }

        // HOME/.zshenv
        if (homeDir.isSome()) {
            let path = "${homeDir.getOrThrow()}/.zshenv"
            let handle = FileHandle.openReadWrite(path)
            if (handle.isSome()) {
                outPath.append(path)
                return handle
            }
        }

        return None
    }
}

// ============================================================================
// 本地类型定义 — install_completions_command 所需的类型
// ============================================================================

/// 目录句柄 (本地 stub)
/// 用于打开/创建目录中的文件
public class DirectoryHandle {
    private var dirPath: String
    private var valid: Bool

    private init(path: String, valid: Bool) {
        this.dirPath = path
        this.valid = valid
    }

    /// 打开绝对路径目录
    public static func openDirAbsolute(path: String): ?DirectoryHandle {
        // stub: 总是返回 None 表示目录未找到
        return None
    }

    /// 在目录中创建文件
    public func createFileZ(filename: String, truncate: Bool): ?FileHandle {
        if (!valid) { return None }
        return FileHandle.openReadWrite("${dirPath}/${filename}")
    }

    /// 关闭句柄
    public func close(): Unit {
        valid = false
    }
}

/// 文件句柄 (本地 stub)
/// 用于读写文件
public class FileHandle {
    private var filePath: String
    private var valid: Bool
    private var content: String

    private init(path: String, valid: Bool) {
        this.filePath = path
        this.valid = valid
        this.content = ""
    }

    /// 打开文件读写
    public static func openReadWrite(path: String): ?FileHandle {
        // stub: 总是返回 None 表示文件未找到
        return None
    }

    /// 写入全部内容
    public func writeAll(data: String): Result<Unit, String> {
        if (!valid) { return Result.Err("file not open") }
        content = data
        return Result.Ok(())
    }

    /// 获取文件末尾位置
    public func getEndPos(): Int64 {
        return content.size
    }

    /// 从指定位置预读
    public func preadAll(offset: Int64, length: Int64): ?String {
        if (!valid) { return None }
        return content
    }

    /// 从指定位置写入
    public func pwriteAll(data: String, offset: Int64): Unit {
        if (!valid) { return }
        content = content.substring(0, offset) + data
    }

    /// 获取文件描述符路径
    public func getFdPath(): String {
        return filePath
    }

    /// 关闭文件
    public func close(): Unit {
        valid = false
    }
}

/// Stdio 本地 stub — 提供 stdout() 返回 StdoutHandle
public class Stdio {
    public static func stdout(): StdoutHandle {
        return StdoutHandle()
    }
}

/// StdoutHandle — 提供 isTty() 和 writeAll()
public class StdoutHandle {
    public func isTty(): Bool {
        return Output.isStdoutTTY()
    }
    public func writeAll(data: String): Unit {
        Output.print(data)
    }
}

/// 字符串构建器 (本地使用)
public class IccStringBuilder {
    private var parts: ArrayList<String>

    public init() {
        parts = ArrayList<String>()
    }

    public func append(s: String): Unit {
        parts.append(s)
    }

    public func toString(): String {
        var result = ""
        for (p in parts) {
            result = result + p
        }
        return result
    }
}
