// 严格翻译自: src/sql/postgres/protocol/Close.zig
// PostgreSQL Close 消息
package bao_sql.postgres.protocol

/// PostgreSQL Close 消息
/// Byte1('C') - 标识为 Close 命令
/// Int32 - 消息长度
/// Byte1 - 'S' 关闭预编译语句, 'P' 关闭 portal
/// String - 预编译语句或 portal 的名称
/// 对应 Bun: Close
public class Close {
    public var p: PortalOrPreparedStatement

    public init(p: PortalOrPreparedStatement) {
        this.p = p
    }

    /// 写入 Close 消息
    /// 对应 Bun: Close.writeInternal
    public func writeTo(writer: ArrayListWriter): Unit {
        let nameSlice = p.slice()
        let count: UInt32 = 4 + 1 + UInt32(nameSlice.size) + 1
        // header: 'C' + length(4) + tag(1)
        writer.write([UInt8(67)])
        writer.int4(count)
        writer.write([p.tag()])
        writer.string(nameSlice)
    }
}
