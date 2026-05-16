// 严格翻译自: src/sql/postgres/protocol/Execute.zig
// PostgreSQL Execute 消息
package bao_sql.postgres.protocol

/// PostgreSQL Execute 消息
/// 对应 Bun: Execute
public class Execute {
    public var maxRows: UInt32
    public var p: PortalOrPreparedStatement

    public init(p: PortalOrPreparedStatement, maxRows: UInt32) {
        this.p = p
        this.maxRows = maxRows
    }

    /// 写入 Execute 消息
    /// 对应 Bun: Execute.writeInternal
    public func writeTo(writer: ArrayListWriter): Unit {
        writer.write([UInt8(69)])
        let len = writer.length()

        match (p) {
            case PortalOrPreparedStatement.portal(s) => writer.string(s)
            case PortalOrPreparedStatement.prepared_statement(_) => writer.write([UInt8(0)])
        }

        writer.int4(maxRows)
        len.write()
    }
}
