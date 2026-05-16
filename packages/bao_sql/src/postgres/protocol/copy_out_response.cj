// 严格翻译自: src/sql/postgres/protocol/CopyOutResponse.zig
// PostgreSQL CopyOutResponse 消息
package bao_sql.postgres.protocol

/// PostgreSQL CopyOutResponse 消息
/// 对应 Bun: CopyOutResponse
/// Bun 上游 decodeInternal 仍为 return None
public class CopyOutResponse {
    /// 从读取器解码
    /// 对应 Bun: CopyOutResponse.decodeInternal
    public static func decode(reader: StackReaderImpl): ?CopyOutResponse {
        let _ = reader
        return None
    }
}
