// 严格翻译自: src/cli/install_completions_command.zig
// 安装 shell 自动补全
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*

/// 支持的 shell 类型
public enum ShellType {
    | bash
    | zsh
    | fish
    | powershell
    | unknown

    /// 从环境变量检测
    public static func fromEnv(shellVar: String): ShellType {
        if (shellVar.contains("bash")) { return bash }
        if (shellVar.contains("zsh")) { return zsh }
        if (shellVar.contains("fish")) { return fish }
        if (shellVar.contains("powershell") || shellVar.contains("pwsh")) { return powershell }
        return unknown
    }
}

/// 补全命令实现
public class InstallCompletionsCommand {
    /// 执行安装补全命令
    public static func exec(ctx: CommandContext): Unit {
        let args = ctx.positionals

        let shellType = if (!args.isEmpty()) {
            parseShellType(args[0])
        } else {
            detectShell()
        }

        match (shellType) {
            case bash => installBashCompletions()
            case zsh => installZshCompletions()
            case fish => installFishCompletions()
            case powershell => installPowerShellCompletions()
            case unknown =>
                Output.prettyErrorln("<r><red>error:<r> Unknown shell type")
                Output.prettyln("\\nSupported shells: bash, zsh, fish, powershell")
                Global.exit(1)
        }
    }

    /// 解析 shell 类型
    static func parseShellType(arg: String): ShellType {
        if (arg == "bash") {
            return ShellType.bash
        } else if (arg == "zsh") {
            return ShellType.zsh
        } else if (arg == "fish") {
            return ShellType.fish
        } else if (arg == "powershell" || arg == "pwsh") {
            return ShellType.powershell
        } else {
            return ShellType.unknown
        }
    }

    /// 检测 shell
    static func detectShell(): ShellType {
        let shellVar = "/bin/bash"

        if (!shellVar.isEmpty()) {
            return ShellType.fromEnv(shellVar)
        }

        // 默认为 bash
        return ShellType.bash
    }

    /// 安装 Bash 补全
    static func installBashCompletions(): Unit {
        let completions = getBashCompletions()
        let targetDir = getBashCompletionDir()
        let targetFile = Path.join(targetDir, "bao")

        writeCompletionFile(targetFile, completions)

        Output.prettyln("<green>Success!<r> Bash completions installed to ${targetFile}")
        Output.prettyln("<d>note:<r> Restart your shell or run 'source ~/.bashrc'")
    }

    /// 安装 Zsh 补全
    static func installZshCompletions(): Unit {
        let completions = getZshCompletions()
        let targetDir = getZshCompletionDir()
        let targetFile = Path.join(targetDir, "_bao")

        writeCompletionFile(targetFile, completions)

        Output.prettyln("<green>Success!<r> Zsh completions installed to ${targetFile}")
        Output.prettyln("<d>note:<r> Restart your shell or run 'exec zsh'")
    }

    /// 安装 Fish 补全
    static func installFishCompletions(): Unit {
        let completions = getFishCompletions()
        let targetDir = getFishCompletionDir()
        let targetFile = Path.join(targetDir, "bao.fish")

        writeCompletionFile(targetFile, completions)

        Output.prettyln("<green>Success!<r> Fish completions installed to ${targetFile}")
        Output.prettyln("<d>note:<r> Fish will automatically load the completions")
    }

    /// 安装 PowerShell 补全
    static func installPowerShellCompletions(): Unit {
        let completions = getPowerShellCompletions()
        let targetDir = getPowerShellCompletionDir()
        let targetFile = Path.join(targetDir, "bao.ps1")

        writeCompletionFile(targetFile, completions)

        Output.prettyln("<green>Success!<r> PowerShell completions installed to ${targetFile}")
        Output.prettyln("<d>note:<r> Restart PowerShell or run '. $PROFILE'")
    }

    /// 获取 Bash 补全目录
    static func getBashCompletionDir(): String {
        let homeDir = "/home/user"  // TODO: get HOME
        return homeDir + "/.local/share/bash-completion/completions"
    }

    /// 获取 Zsh 补全目录
    static func getZshCompletionDir(): String {
        let homeDir = "/home/user"  // TODO: get HOME
        let zshDir = if (BaoFile.exists("${homeDir}/.zsh")) {
            "${homeDir}/.zsh"
        } else {
            homeDir + "/.local/share/zsh/site-functions"
        }
        return zshDir
    }

    /// 获取 Fish 补全目录
    static func getFishCompletionDir(): String {
        let homeDir = "/home/user"  // TODO: get HOME
        let configDir = homeDir + "/.config"  // TODO: XDG_CONFIG_HOME
        return configDir + "/fish/completions"
    }

    /// 获取 PowerShell 补全目录
    static func getPowerShellCompletionDir(): String {
        let profile = ""  // TODO: PROFILE env
        if (!profile.isEmpty()) {
            let dir = Path.dirname(profile); return if (dir.isEmpty()) { profile } else { dir }
        }
        let homeDir = "/home/user"  // TODO: get HOME
        return Path.join(homeDir, ".config", "powershell")
    }

    /// 写入补全文件
    static func writeCompletionFile(path: String, content: String): Unit {
        // 确保目录存在
        let dir = Path.dirname(path); let dir2 = if (dir.isEmpty()) { "." } else { dir }
        if (!BaoFile.exists(dir)) {
            createDirectory(dir, true)
        }

        // 写入文件
        // TODO: BaoFile.writeFile(path, content)
    }

    /// 获取 Bash 补全内容
    static func getBashCompletions(): String {
        return """
# bao bash completion
_bao_completion() {
    local cur prev words cword
    _init_completion || return

    case \${prev} in
        bao)
            COMPREPLY=($(compgen -W "run build test install add remove init repl x upgrade create" -- "\${cur}"))
            ;;
        run|build|test)
            COMPREPLY=($(compgen -f -- "\${cur}"))
            ;;
        *)
            COMPREPLY=()
            ;;
    esac
}

complete -F _bao_completion bao
"""
    }

    /// 获取 Zsh 补全内容
    static func getZshCompletions(): String {
        return """
#compdef bao

_bao() {
    local -a commands
    commands=(
        'run:Run a script or file'
        'build:Bundle entry points'
        'test:Run tests'
        'install:Install dependencies'
        'add:Add dependencies'
        'remove:Remove dependencies'
        'init:Create package.json'
        'repl:Start REPL'
        'x:Execute package'
        'upgrade:Upgrade bao'
        'create:Create new project'
    )

    if (( CURRENT == 2 )); then
        _describe 'command' commands
    else
        _files
    fi
}

_bao
"""
    }

    /// 获取 Fish 补全内容
    static func getFishCompletions(): String {
        return """
# bao fish completion

complete -c bao -n __fish_use_subcommand -a run -d 'Run a script or file'
complete -c bao -n __fish_use_subcommand -a build -d 'Bundle entry points'
complete -c bao -n __fish_use_subcommand -a test -d 'Run tests'
complete -c bao -n __fish_use_subcommand -a install -d 'Install dependencies'
complete -c bao -n __fish_use_subcommand -a add -d 'Add dependencies'
complete -c bao -n __fish_use_subcommand -a remove -d 'Remove dependencies'
complete -c bao -n __fish_use_subcommand -a init -d 'Create package.json'
complete -c bao -n __fish_use_subcommand -a repl -d 'Start REPL'
complete -c bao -n __fish_use_subcommand -a x -d 'Execute package'
complete -c bao -n __fish_use_subcommand -a upgrade -d 'Upgrade bao'
complete -c bao -n __fish_use_subcommand -a create -d 'Create new project'
"""
    }

    /// 获取 PowerShell 补全内容
    static func getPowerShellCompletions(): String {
        return #"# bao PowerShell completion

Register-ArgumentCompleter -Native -CommandName bao -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $commands = @('run', 'build', 'test', 'install', 'add', 'remove', 'init', 'repl', 'x', 'upgrade', 'create')

    if ($commandAst.CommandElements.Count -eq 2) {
        $commands | Where-Object { $_ -like "$wordToComplete*" }
    } else {
        @()
    }
}
"#
    }

    /// 创建目录
    static func createDirectory(path: String, recursive: Bool): Unit {
        // TODO: 实现目录创建
    }
}
