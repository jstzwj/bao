// 严格翻译自: src/sql/postgres/protocol/Describe.zig
// PostgreSQL Describe 消息
package bao_sql.postgres.protocol

/// PostgreSQL Describe 消息
/// 对应 Bun: Describe
public class Describe {
    public var p: PortalOrPreparedStatement

    public init(p: PortalOrPreparedStatement) {
        this.p = p
    }

    /// 写入 Describe 消息
    /// 对应 Bun: Describe.writeInternal
    public func writeTo(writer: ArrayListWriter): Unit {
        let message = p.slice()
        writer.write([UInt8(68)])
        let len = writer.length()
        writer.write([p.tag()])
        writer.string(message)
        len.write()
    }
}
