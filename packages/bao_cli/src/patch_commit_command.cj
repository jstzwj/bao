// 严格翻译自: src/cli/patch_commit_command.zig
package bao_cli

import bao_core.*
import bao_install.*

// ============================================================================
// PatchCommitCommand — patch-commit 子命令
// 严格翻译自: src/cli/patch_commit_command.zig
//
// 委托给 PackageManager.updatePackageJSONAndInstallCatchError
// ============================================================================

/// patch-commit 命令
/// 对应 Bun: PatchCommitCommand
public class PatchCommitCommand {
    /// 执行 patch-commit 命令
    /// 对应 Bun: PatchCommitCommand.exec()
    public static func exec(ctx: CommandContext): Unit {
        PackageManager.updatePackageJSONAndInstallCatchError(ctx, Subcommand.patchCommit)
    }
}
