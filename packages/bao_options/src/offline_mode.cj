// OfflineMode - 离线模式
// 严格翻译自: bun/src/options_types/OfflineMode.zig
//   pub const OfflineMode = enum { online, latest, offline };
package bao_options

// ============================================================================
// OfflineMode - 离线模式
// 严格翻译自: OfflineMode.zig
// ============================================================================

/// 离线模式 - 对应 Bun OfflineMode
public enum OfflineMode {
    | Online   // 在线模式
    | Latest   // 获取最新
    | Offline  // 离线模式

    /// 从字符串解析
    public static func fromString(slice: String): ?OfflineMode {
        match (slice) {
            case "offline" => OfflineMode.Offline
            case "latest" => OfflineMode.Latest
            case "online" => OfflineMode.Online
            case _ => None
        }
    }
}
