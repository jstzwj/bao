// 严格翻译自: src/cli/shell_completions.zig
package bao_cli

import bao_core.*

// ============================================================================
// ShellCompletions — Shell 自动补全
// 严格翻译自: src/cli/shell_completions.zig
// ============================================================================

/// Shell 类型枚举
public enum Shell {
    | unknown
    | bash
    | zsh
    | fish
    | pwsh

    /// 获取对应 shell 的补全脚本内容
    /// 对应 Bun: Shell.completions()
    public func completions(): String {
        match (this) {
            case Shell.bash => CompletionsData.bashCompletions
            case Shell.zsh => CompletionsData.zshCompletions
            case Shell.fish => CompletionsData.fishCompletions
            case Shell.pwsh | Shell.unknown => ""
        }
    }

    /// 从环境变量检测 shell 类型
    /// 对应 Bun: Shell.fromEnv()
    public static func fromEnv(shell: String): Shell {
        let basename = Path.basename(shell)
        if (basename == "bash") {
            return Shell.bash
        } else if (basename == "zsh") {
            return Shell.zsh
        } else if (basename == "fish") {
            return Shell.fish
        } else if (basename == "pwsh" || basename == "powershell") {
            return Shell.pwsh
        } else {
            return Shell.unknown
        }
    }
}

/// Shell 补全输出器
/// 对应 Bun: shell_completions.zig 中顶层 print 函数
public class ShellCompletions {
    /// 命令列表
    public var commands: ArrayList<String>

    /// 描述列表
    public var descriptions: ArrayList<String>

    /// 标志列表
    public var flags: ArrayList<String>

    /// 目标 shell
    public var shell: Shell

    public init() {
        commands = ArrayList<String>()
        descriptions = ArrayList<String>()
        flags = ArrayList<String>()
        shell = Shell.unknown
    }

    /// 打印补全输出
    /// 对应 Bun: print()
    public func print(): Unit {
        Output.flush()
        if (commands.size == 0) {
            return
        }

        // fish 使用空格分隔，其他使用换行
        let delimiter = if (shell == Shell.fish) " " else "\n"

        // 第一个命令
        Output.write(commands[0])

        // 如果有描述，添加制表符和描述
        if (descriptions.size > 0) {
            Output.write("\t")
            Output.write(descriptions[0])
        }

        // 后续命令
        if (commands.size > 1) {
            var i = 1
            while (i < commands.size) {
                Output.write(delimiter)
                Output.write(commands[i])
                if (descriptions.size > 0 && i < descriptions.size) {
                    Output.write("\t")
                    Output.write(descriptions[i])
                }
                i++
            }
        }

        Output.flush()
    }
}
