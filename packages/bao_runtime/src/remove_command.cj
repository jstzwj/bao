// 严格翻译自: src/runtime/cli/remove_command.zig
package bao_runtime

import bao_core.*
import bao_install.*

/// remove 命令: 从项目中移除依赖
public class RemoveCommand {
    /// 执行 remove 命令
    public static func exec(ctx: CommandContext): Unit {
        Output.prettyln("bao remove - not yet implemented")
    }
}
