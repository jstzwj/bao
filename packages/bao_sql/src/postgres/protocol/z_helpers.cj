// 严格翻译自: src/sql/postgres/protocol/zHelpers.zig
// PostgreSQL 协议辅助函数
package bao_sql.postgres.protocol

/// PostgreSQL 协议辅助函数
/// 对应 Bun: zHelpers
public class ZHelpers {
    /// 计算以 null 结尾的字节数 (如果非空则 +1)
    /// 对应 Bun: zCount
    public static func zCount(slice: String): Int64 {
        if (slice.size > 0) {
            return Int64(slice.size) + 1
        }
        return 0
    }

    /// 计算 field 的字节数 (前缀 + 值)
    /// 对应 Bun: zFieldCount
    public static func zFieldCount(prefix: String, slice: String): Int64 {
        if (slice.size > 0) {
            return zCount(prefix) + zCount(slice)
        }
        return zCount(prefix)
    }
}
