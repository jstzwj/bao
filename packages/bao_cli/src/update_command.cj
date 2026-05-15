// 严格翻译自: src/cli/update_command.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// UpdateCommand — bun update 命令
// 严格翻译自: src/cli/update_command.zig - UpdateCommand struct
// ============================================================================

/// update 命令: 更新依赖
/// 对应 Bun: UpdateCommand
public class UpdateCommand {
    /// 执行 update 命令
    /// 对应 Bun: UpdateCommand.exec()
    public static func exec(ctx: CommandContext): Unit {
        let cli = PackageManager.CommandLineArguments.parse(ctx, Subcommand.update)

        if (cli.interactive) {
            UpdateInteractiveCommand.exec(ctx)
        } else {
            PackageManager.updatePackageJSONAndInstallCatchError(ctx, Subcommand.update)
        }
    }
}
