// 严格翻译自: src/sql/postgres/protocol/ReadyForQuery.zig
// PostgreSQL ReadyForQuery 消息
package bao_sql.postgres.protocol

/// PostgreSQL ReadyForQuery 消息
/// 对应 Bun: ReadyForQuery
public class ReadyForQuery {
    public var status: TransactionStatusIndicator

    public init() {
        status = TransactionStatusIndicator.I
    }

    /// 从读取器解码
    /// 对应 Bun: ReadyForQuery.decodeInternal
    public static func decode(reader: StackReaderImpl): ?ReadyForQuery {
        let result = ReadyForQuery()

        let length = reader.length()
        if (length.isNone()) { return None }

        let statusByte = reader.byte()
        if (statusByte.isNone()) { return None }

        result.status = TransactionStatusIndicator.fromByte(statusByte.getOrThrow())
        return result
    }
}
