// MySQL ResultSet Header 协议包
// 严格翻译自: src/sql/mysql/protocol/ResultSetHeader.zig
package bao_runtime.sql.mysql

/// MySQL 结果集头部
/// 对应 Bun: ResultSetHeader
/// 表示查询返回的列数
public class ResultSetHeader {
    /// 字段 (列) 数量
    public var fieldCount: UInt64

    public init() {
        fieldCount = 0
    }

    /// 从 Reader 解码
    /// 对应 Bun: ResultSetHeader.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        fieldCount = reader.readEncodedLenInt()
    }
}
