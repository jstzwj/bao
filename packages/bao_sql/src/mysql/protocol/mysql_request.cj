// MySQL 请求构造
// 对应 Bun: src/sql/mysql/MySQLRequest.zig
package bao_sql.mysql.protocol

/// MySQL 请求构造工具
/// 对应 Bun: MySQLRequest
///
/// 提供执行查询和准备语句的请求构造方法
public class MySQLRequest {
    /// 执行查询请求
    /// 对应 Bun: MySQLRequest.executeQuery
    ///
    /// 向服务器发送 COM_QUERY 命令
    /// 每次发送查询时重置序列 ID 为 0
    public static func executeQuery(query: String, writer: MySQLPacketWriter): Unit {
        // 重置序列 ID 为 0
        var packet = writer.start(0)
        writer.int1(UInt8(0x03)) // COM_QUERY
        writer.write(query.toArray())
        packet.end()
    }

    /// 准备语句请求
    /// 对应 Bun: MySQLRequest.prepareRequest
    ///
    /// 向服务器发送 COM_STMT_PREPARE 命令
    public static func prepareRequest(query: String, writer: MySQLPacketWriter): Unit {
        var packet = writer.start(0)
        writer.int1(UInt8(0x16)) // COM_STMT_PREPARE
        writer.write(query.toArray())
        packet.end()
    }
}
