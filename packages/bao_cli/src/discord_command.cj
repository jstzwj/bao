// 严格翻译自: src/cli/discord_command.zig
package bao_cli

import bao_core.*

// ============================================================================
// DiscordCommand — 打开 Discord 链接
// 严格翻译自: src/cli/discord_command.zig - DiscordCommand struct
// ============================================================================

/// Discord 命令: 打开 Bun Discord 服务器链接
public class DiscordCommand {
    private static let discordUrl = "https://bun.com/discord"

    /// 执行命令: 打开 Discord URL
    public static func exec(): Unit {
        Open.openURL(discordUrl)
    }
}
