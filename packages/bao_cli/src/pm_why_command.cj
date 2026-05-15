// 严格翻译自: src/cli/pm_why_command.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// PmWhyCommand — bun pm why 命令
// 严格翻译自: src/cli/pm_why_command.zig - PmWhyCommand struct
// ============================================================================

/// pm why 命令: 解释包为什么被安装
/// 对应 Bun: PmWhyCommand
/// 薄包装器, 委托给 WhyCommand.execFromPm()
public class PmWhyCommand {
    /// 执行 pm why 命令
    /// 对应 Bun: PmWhyCommand.exec()
    public static func exec(ctx: CommandContext, pm: PackageManager, positionals: ArrayList<String>): Unit {
        WhyCommand.execFromPm(ctx, pm, positionals)
    }
}
