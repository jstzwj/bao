// 严格翻译自: src/sql/postgres/protocol/CopyOutResponse.zig
// PostgreSQL CopyOutResponse 消息
package bao_sql.postgres.protocol

/// PostgreSQL CopyOutResponse 消息
/// 对应 Bun: CopyOutResponse
/// TODO: 尚未完全实现
public class CopyOutResponse {
    /// 从读取器解码
    /// 对应 Bun: CopyOutResponse.decodeInternal
    /// 注意: 原始实现中此函数标记为 panic("TODO: not implemented")
    public static func decode(reader: StackReaderImpl): ?CopyOutResponse {
        // TODO: 尚未完全实现
        return CopyOutResponse()
    }
}
