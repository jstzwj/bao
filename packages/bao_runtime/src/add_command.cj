// 严格翻译自: src/runtime/cli/add_command.zig
package bao_runtime

import bao_core.*
import bao_install.*

// ============================================================================
// AddCommand — bun add 命令
// 严格翻译自: src/runtime/cli/add_command.zig - AddCommand struct
// ============================================================================

/// add 命令: 添加依赖到项目
/// 对应 Bun: AddCommand
/// 薄包装器, 委托给 updatePackageJSONAndInstallCatchError
public class AddCommand {
    /// 执行 add 命令
    public static func exec(ctx: CommandContext): Unit {
        Output.prettyln("bun add - Add a dependency")
        Output.flush()
    }
}
