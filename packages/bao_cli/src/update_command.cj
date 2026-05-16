// 严格翻译自: src/cli/update_command.rs
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// UpdateCommand — bun update 命令
// 严格翻译自: src/cli/update_command.rs - UpdateCommand struct
//
// 核心流程:
//   1. 解析命令行参数 (CommandLineArguments.parse)
//   2. 如果是交互模式 (--interactive), 委托给 UpdateInteractiveCommand
//   3. 否则委托给 pm_update_package_json.updatePackageJsonAndInstallCatchError
// ============================================================================

/// update 命令: 更新依赖
/// 对应 Bun: UpdateCommand
public class UpdateCommand {
    /// 执行 update 命令
    /// 对应 Bun: UpdateCommand.exec()
    public static func exec(ctx: CommandContext): Unit {
        // PORT NOTE: dropped `ctx.allocator` arg — global mimalloc per §Allocators
        let cli = CommandLineArguments.parse(Subcommand.update)

        if (cli.interactive) {
            UpdateInteractiveCommand.exec(ctx)
        } else {
            // 委托给 pm_update_package_json 模块
            match (updatePackageJsonAndInstallCatchError(ctx, Subcommand.update)) {
                case Ok(_) => return
                case Err(e) => {
                    Output.prettyErrorLn("<r><red>error<r>: ${e.name}")
                    Global.exit(1)
                }
            }
        }
    }
}
