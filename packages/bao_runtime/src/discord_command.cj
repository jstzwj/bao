// 严格翻译自: src/runtime/cli/discord_command.zig
package bao_runtime

import bao_core.*

// ============================================================================
// DiscordCommand — 打开 Discord 链接
// 严格翻译自: src/runtime/cli/discord_command.zig - DiscordCommand struct
// ============================================================================

/// Discord 命令: 打开 Bun Discord 服务器链接
/// 对应 Bun: DiscordCommand
public class DiscordCommand {
    private static let discordUrl = "https://bun.com/discord"

    /// 执行命令: 打开 Discord URL
    /// 对应 Bun: DiscordCommand.exec()
    public static func exec(): Unit {
        Output.prettyln("Join our community: ${discordUrl}")
    }
}
