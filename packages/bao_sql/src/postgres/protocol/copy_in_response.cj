// 严格翻译自: src/sql/postgres/protocol/CopyInResponse.zig
// PostgreSQL CopyInResponse 消息
package bao_sql.postgres.protocol

/// PostgreSQL CopyInResponse 消息
/// 对应 Bun: CopyInResponse
/// TODO: 尚未完全实现
public class CopyInResponse {
    /// 从读取器解码
    /// 对应 Bun: CopyInResponse.decodeInternal
    /// 注意: 原始实现中此函数标记为 panic("TODO: not implemented")
    public static func decode(reader: StackReaderImpl): ?CopyInResponse {
        // TODO: 尚未完全实现
        return CopyInResponse()
    }
}
