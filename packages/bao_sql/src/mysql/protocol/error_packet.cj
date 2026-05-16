// MySQL 错误包
// 对应 Bun: src/sql/mysql/protocol/ErrorPacket.zig
package bao_sql.mysql.protocol

/// MySQL 错误包选项
/// 对应 Bun: MySQLErrorOptions (struct)
public class MySQLErrorOptions {
    public var code: String
    public var errno: ?UInt16
    public var sqlState: ?Array<UInt8>

    public init(code: String) {
        this.code = code
        this.errno = None
        this.sqlState = None
    }
}

/// MySQL 错误包
/// 对应 Bun: ErrorPacket (struct)
///
/// 服务器发送的错误响应包
public class ErrorPacket {
    /// 包头 (0xff)
    /// 对应 Bun: header u8
    public var header: UInt8

    /// 错误码
    /// 对应 Bun: error_code u16
    public var errorCode: UInt16

    /// SQL 状态标记 ('#')
    /// 对应 Bun: sql_state_marker ?u8
    public var sqlStateMarker: ?UInt8

    /// SQL 状态 (5 字节)
    /// 对应 Bun: sql_state ?[5]u8
    public var sqlState: ?Array<UInt8>

    /// 错误消息
    /// 对应 Bun: error_message Data
    public var errorMessage: Array<UInt8>

    public init() {
        header = 0xff
        errorCode = 0
        sqlStateMarker = None
        sqlState = None
        errorMessage = Array<UInt8>()
    }

    /// 释放资源
    /// 对应 Bun: ErrorPacket.deinit
    public func deinit(): Unit {
        errorMessage = Array<UInt8>()
    }

    /// 从读取器解码错误包
    /// 对应 Bun: ErrorPacket.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        header = reader.int8()
        if (header != 0xff) {
            throw MySQLProtocolException("InvalidErrorPacket")
        }

        errorCode = reader.int16()

        // 检查是否有 SQL 状态标记
        let nextByte = reader.int8()
        if (nextByte == 0x23) {
            sqlStateMarker = Some(nextByte)
            let sqlStateData = reader.read(5)
            sqlState = Some(sqlStateData)
        } else {
            // 没有 SQL 状态，回退一字节
            sqlStateMarker = None
            sqlState = None
            reader.skip(-1)
        }

        // 读取错误消息 (剩余部分)
        let remaining = reader.peek()
        if (remaining.size > 0) {
            errorMessage = reader.read(remaining.size)
        }
    }
}
