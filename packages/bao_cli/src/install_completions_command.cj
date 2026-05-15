// 严格翻译自: src/cli/install_completions_command.zig
package bao_cli

import bao_core.*
import bao_install.*

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

    /// 执行安装补全命令
    /// 对应 Bun: InstallCompletionsCommand.exec()
    public static func exec(allocator: Allocator): Unit {
        // 静默失败于自动更新
        val failExitCode: Int64 = if (!EnvVar.IS_BUN_AUTO_UPDATE.get()) 1 else 0

        var cwdBuf = PathBuffer()
        val stdout = Stdio.stdout()

        // 检测当前 shell
        var shell = Shell.unknown
        val shellName = EnvVar.SHELL.platformGet()
        if (shellName != None) {
            shell = Shell.fromEnv(shellName!!)
        }

        // 获取当前工作目录
        val cwd = Sys.getcwd(cwdBuf)
        if (cwd == None) {
            if (failExitCode == 1) {
                if (!stdout.isTty()) {
                    stdout.writeAll(shell.completions())
                    Global.exit(0)
                }
            }
            Output.prettyErrorLn("<r><red>error<r>: Could not get current working directory")
            Global.exit(failExitCode)
        }

        // 安装 bunx 符号链接
        installBunxSymlink(cwd!!)

        // 根据 shell 类型安装补全
        when (shell) {
            case Shell.unknown => {
                Output.errGeneric("Unknown or unsupported shell. Please set $SHELL to one of zsh, fish, or bash.")
                Output.note("To manually output completions, run 'bao getcompletes'")
                Global.exit(failExitCode)
            }
            case _ => {}
        }

        if (!EnvVar.IS_BUN_AUTO_UPDATE.get()) {
            if (!stdout.isTty()) {
                stdout.writeAll(shell.completions())
                Global.exit(0)
            }
        }

        // 查找补全目录
        var completionsDir = ""
        val (outputDir, foundDir) = findCompletionsDir(shell, cwd!!, failExitCode)
        if (outputDir == None) {
            Output.prettyErrorLn("<r><red>error:<r> Could not find a directory to install completions in.\n")

            if (shell == Shell.zsh) {
                Output.prettyErrorLn("\nzsh tip: One of the directories in $fpath might work. If you use oh-my-zsh, try mkdir $HOME/.oh-my-zsh/completions; and bao completions again.\n.")
            }

            Output.printErrorLn("Please either pipe it:\n   bao completions > /to/a/file\n\n Or pass a directory:\n\n   bao completions /my/completions/dir\n")
            Global.exit(failExitCode)
        }

        completionsDir = foundDir

        val filename = when (shell) {
            case Shell.fish => "bao.fish"
            case Shell.zsh => "_bao"
            case Shell.bash => "bao.completion.bash"
            case _ => "bao-completions"
        }

        // 写入补全文件
        val outputDirHandle = outputDir!!
        val outputFile = outputDirHandle.createFileZ(filename, true)
        if (outputFile == None) {
            Output.prettyErrorLn("<r><red>error:<r> Could not open ${filename} for writing")
            Global.exit(failExitCode)
        }

        val writeResult = outputFile!!.writeAll(shell.completions())
        if (writeResult.isErr) {
            Output.prettyErrorLn("<r><red>error:<r> Could not write to ${filename}")
            Global.exit(failExitCode)
        }

        outputFile!!.close()
        outputDirHandle.close()

        // zsh: 检查是否需要在 .zshrc 中加载补全文件
        if (shell == Shell.zsh) {
            val completionsPath = outputFile!!.getFdPath()
            configureZshrc(completionsPath, failExitCode)
        }

        Output.prettyErrorLn("<r><d>Installed completions to ${completionsDir}/${filename}<r>\n")
        Output.flush()
    }

    /// 查找补全目录
    /// 对应 Bun: 根据不同 shell 在多个位置搜索补全目录
    private static func findCompletionsDir(shell: Shell, cwd: String, failExitCode: Int64): (?DirectoryHandle, String) {
        var completionsDir = ""

        when (shell) {
            case Shell.fish => {
                // 检查 XDG_CONFIG_HOME
                val configDir = EnvVar.XDG_CONFIG_HOME.get()
                if (configDir != None) {
                    val dir = Path.joinAbsString(cwd, [configDir!!, "./fish/completions"])
                    val handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle != None) {
                        return (handle, dir)
                    }
                }

                // 检查 XDG_DATA_HOME
                val dataDir = EnvVar.XDG_DATA_HOME.get()
                if (dataDir != None) {
                    val dir = Path.joinAbsString(cwd, [dataDir!!, "./fish/completions"])
                    val handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle != None) {
                        return (handle, dir)
                    }
                }

                // 检查 HOME/.config/fish/completions
                val homeDir = EnvVar.HOME.get()
                if (homeDir != None) {
                    val dir = Path.joinAbsString(cwd, [homeDir!!, "./.config/fish/completions"])
                    val handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle != None) {
                        return (handle, dir)
                    }
                }

                // 检查 macOS homebrew fish 路径
                if (Platform.isMac) {
                    if (!Platform.isAarch64) {
                        completionsDir = "/usr/local/share/fish/completions"
                        val handle = DirectoryHandle.openDirAbsolute(completionsDir)
                        if (handle != None) {
                            return (handle, completionsDir)
                        }
                    } else {
                        completionsDir = "/opt/homebrew/share/fish/completions"
                        val handle = DirectoryHandle.openDirAbsolute(completionsDir)
                        if (handle != None) {
                            return (handle, completionsDir)
                        }
                    }
                }

                // /etc/fish/completions
                completionsDir = "/etc/fish/completions"
                val etcHandle = DirectoryHandle.openDirAbsolute(completionsDir)
                if (etcHandle != None) {
                    return (etcHandle, completionsDir)
                }
            }
            case Shell.zsh => {
                // 检查 fpath 环境变量
                val fpath = EnvVar.fpath.get()
                if (fpath != None) {
                    val splitter = fpath!!.split(' ')
                    for (dir in splitter) {
                        val handle = DirectoryHandle.openDirAbsolute(dir)
                        if (handle != None) {
                            return (handle, dir)
                        }
                    }
                }

                // 检查 XDG_DATA_HOME
                val dataDir = EnvVar.XDG_DATA_HOME.get()
                if (dataDir != None) {
                    val dir = Path.joinAbsString(cwd, [dataDir!!, "./zsh-completions"])
                    val handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle != None) {
                        return (handle, dir)
                    }
                }

                // 检查 BUN_INSTALL
                val installDir = EnvVar.BUN_INSTALL.get()
                if (installDir != None) {
                    val handle = DirectoryHandle.openDirAbsolute(installDir!!)
                    if (handle != None) {
                        return (handle, installDir!!)
                    }
                }

                // 检查 HOME 下的各种路径
                val homeDir = EnvVar.HOME.get()
                if (homeDir != None) {
                    // oh-my-zsh/completions
                    val omzDir = Path.joinAbsString(cwd, [homeDir!!, "./.oh-my-zsh/completions"])
                    val omzHandle = DirectoryHandle.openDirAbsolute(omzDir)
                    if (omzHandle != None) {
                        return (omzHandle, omzDir)
                    }

                    // .bun
                    val bunDir = Path.joinAbsString(cwd, [homeDir!!, "./.bun"])
                    val bunHandle = DirectoryHandle.openDirAbsolute(bunDir)
                    if (bunHandle != None) {
                        return (bunHandle, bunDir)
                    }
                }

                // 尝试系统级路径
                val dirsToTry = [
                    "/usr/local/share/zsh/site-functions",
                    "/usr/local/share/zsh/completions",
                    "/opt/homebrew/share/zsh/completions",
                    "/opt/homebrew/share/zsh/site-functions"
                ]
                for (dir in dirsToTry) {
                    val handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle != None) {
                        return (handle, dir)
                    }
                }
            }
            case Shell.bash => {
                // 检查 XDG_DATA_HOME
                val dataDir = EnvVar.XDG_DATA_HOME.get()
                if (dataDir != None) {
                    val dir = Path.joinAbsString(cwd, [dataDir!!, "./bash-completion/completions"])
                    val handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle != None) {
                        return (handle, dir)
                    }
                }

                // 检查 XDG_CONFIG_HOME
                val configDir = EnvVar.XDG_CONFIG_HOME.get()
                if (configDir != None) {
                    val dir = Path.joinAbsString(cwd, [configDir!!, "./bash-completion/completions"])
                    val handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle != None) {
                        return (handle, dir)
                    }
                }

                // 检查 HOME 下的路径
                val homeDir = EnvVar.HOME.get()
                if (homeDir != None) {
                    // oh-my-bash
                    val ombDir = Path.joinAbsString(cwd, [homeDir!!, "./.oh-my-bash/custom/completions"])
                    val ombHandle = DirectoryHandle.openDirAbsolute(ombDir)
                    if (ombHandle != None) {
                        return (ombHandle, ombDir)
                    }

                    // .bash_completion.d
                    val bcdDir = Path.joinAbsString(cwd, [homeDir!!, "./.bash_completion.d"])
                    val bcdHandle = DirectoryHandle.openDirAbsolute(bcdDir)
                    if (bcdHandle != None) {
                        return (bcdHandle, bcdDir)
                    }
                }

                // 尝试系统级路径
                val dirsToTry = [
                    "/opt/homebrew/share/bash-completion/completions/",
                    "/opt/local/share/bash-completion/completions/"
                ]
                for (dir in dirsToTry) {
                    val handle = DirectoryHandle.openDirAbsolute(dir)
                    if (handle != None) {
                        return (handle, dir)
                    }
                }
            }
            case _ => {}
        }

        return (None, "")
    }

    /// 安装 bunx 符号链接
    /// 对应 Bun: installBunxSymlink / installBunxSymlinkPosix
    private static func installBunxSymlink(cwd: String): Unit {
        val buf = PathBuffer()

        // 如果 bunx 已经存在于 PATH 中则跳过
        if (Which.which(buf, EnvVar.PATH.get() ?: cwd, cwd, bunxName) != None) {
            return
        }

        // 获取当前可执行文件路径
        val exe = Sys.selfExePath()
        if (exe == None) {
            return
        }

        val exeDir = Path.dirname(exe!!)
        val target = "${exeDir}/${bunxName}"

        // 尝试在同一目录下创建符号链接
        if (Syscall.symlink(exe!!, target)) {
            return
        }

        // 尝试 BUN_INSTALL/bin
        val installDir = EnvVar.BUN_INSTALL.get()
        if (installDir != None) {
            val installTarget = "${installDir!!}/bin/${bunxName}"
            if (Syscall.symlink(exe!!, installTarget)) {
                return
            }
        }

        // 尝试 $HOME/.bun/bin
        val homeDir = EnvVar.HOME.get()
        if (homeDir != None) {
            val homeTarget = "${homeDir!!}/.bun/bin/${bunxName}"
            if (Syscall.symlink(exe!!, homeTarget)) {
                return
            }
        }

        // 尝试 $HOME/.local/bin
        if (homeDir != None) {
            val localTarget = "${homeDir!!}/.local/bin/${bunxName}"
            if (Syscall.symlink(exe!!, localTarget)) {
                return
            }
        }
    }

    /// 配置 zsh .zshrc 以加载补全
    /// 对应 Bun: 检查 .zshrc 是否已包含补全路径, 否则追加
    private static func configureZshrc(completionsPath: String, failExitCode: Int64): Unit {
        var zshrcFilepath = ""

        // 尝试按优先级打开 .zshrc
        val dotZshrc: ?FileHandle = openZshrc(zshrcFilepath)
        if (dotZshrc == None) {
            // 需要告诉用户手动添加
            Output.prettyErrorLn("<r>To enable completions, add this to your .zshrc:\n      <b>[ -s \"${completionsPath}\" ] && source \"${completionsPath}\"")
            return
        }

        // 读取 .zshrc 内容
        val inputSize = Math.max(dotZshrc!!.getEndPos(), 65536)
        val buf = dotZshrc!!.preadAll(0, inputSize)
        if (buf == None) {
            Output.prettyErrorLn("<r>To enable completions, add this to your .zshrc:\n      <b>[ -s \"${completionsPath}\" ] && source \"${completionsPath}\"")
            return
        }

        val contents = buf!!

        // 检查是否已包含补全路径
        if (contents.contains(completionsPath) || contents.contains("# bao completions\n")) {
            // 已存在, 无需添加
            dotZshrc!!.close()
            return
        }

        // 追加补全加载行
        val extra = "\n# bao completions\n[ -s \"${completionsPath}\" ] && source \"${completionsPath}\"\n"
        dotZshrc!!.pwriteAll(extra, contents.length)
        dotZshrc!!.close()

        Output.prettyErrorLn("<r><d>Enabled loading bao's completions in .zshrc<r>")
    }

    /// 打开 .zshrc 文件
    /// 对应 Bun: 按优先级查找 ZDOTDIR/.zshrc, HOME/.zshrc, HOME/.zshenv
    private static func openZshrc(outPath: StringBuilder): ?FileHandle {
        // ZDOTDIR/.zshrc
        val zdotDir = EnvVar.ZDOTDIR.get()
        if (zdotDir != None) {
            val path = "${zdotDir!!}/.zshrc"
            val handle = FileHandle.openReadWrite(path)
            if (handle != None) {
                outPath.append(path)
                return handle
            }
        }

        // HOME/.zshrc
        val homeDir = EnvVar.HOME.get()
        if (homeDir != None) {
            val path = "${homeDir!!}/.zshrc"
            val handle = FileHandle.openReadWrite(path)
            if (handle != None) {
                outPath.append(path)
                return handle
            }
        }

        // HOME/.zshenv
        if (homeDir != None) {
            val path = "${homeDir!!}/.zshenv"
            val handle = FileHandle.openReadWrite(path)
            if (handle != None) {
                outPath.append(path)
                return handle
            }
        }

        return None
    }
}
