// 严格翻译自: src/sql/postgres/protocol/CopyInResponse.zig
// PostgreSQL CopyInResponse 消息
package bao_sql.postgres.protocol

/// PostgreSQL CopyInResponse 消息
/// 对应 Bun: CopyInResponse
/// Bun 上游 decodeInternal 仍为 return None
public class CopyInResponse {
    /// 从读取器解码
    /// 对应 Bun: CopyInResponse.decodeInternal
    public static func decode(reader: StackReaderImpl): ?CopyInResponse {
        let _ = reader
        return None
    }
}
