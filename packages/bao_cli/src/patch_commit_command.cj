// 严格翻译自: src/cli/patch_commit_command.rs
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// PatchCommitCommand — patch-commit 子命令
// 严格翻译自: src/cli/patch_commit_command.rs
//
// 委托给 pm_update_package_json.updatePackageJsonAndInstallCatchError
// 使用 MOVE_UP 模式: 因为 install 包无法访问 cli 层的 analyzer
// ============================================================================

/// patch-commit 命令
/// 对应 Bun: PatchCommitCommand
public class PatchCommitCommand {
    /// 执行 patch-commit 命令
    /// 对应 Bun: PatchCommitCommand.exec()
    public static func exec(ctx: CommandContext): Unit {
        // 委托给 pm_update_package_json 模块中的错误捕获包装器
        match (updatePackageJsonAndInstallCatchError(ctx, Subcommand.patchCommit)) {
            case Ok(_) => return
            case Err(e) => {
                Output.prettyErrorLn("<r><red>error<r>: ${e.name}")
                Global.exit(1)
            }
        }
    }
}
