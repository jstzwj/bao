// MySQL 结果集头包
// 对应 Bun: src/sql/mysql/protocol/ResultSetHeader.zig
package bao_sql.mysql.protocol

/// MySQL 结果集头包
/// 对应 Bun: ResultSetHeader (struct)
///
/// 服务器发送此包表示查询结果的列数
public class ResultSetHeader {
    /// 字段数量 (长度编码整数)
    /// 对应 Bun: field_count u64
    public var fieldCount: UInt64

    public init() {
        fieldCount = 0
    }

    public init(fieldCount: UInt64) {
        this.fieldCount = fieldCount
    }

    /// 从读取器解码结果集头
    /// 对应 Bun: ResultSetHeader.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        // 字段数量 (长度编码整数)
        fieldCount = reader.encodedLenInt()
    }
}
