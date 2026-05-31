// MySQL Error 数据包
// 严格翻译自: src/sql/mysql/protocol/ErrorPacket.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 错误响应包
/// 对应 Bun: ErrorPacket
public class ErrorPacket {
    /// 包头 (0xff)
    public var header: UInt8
    /// 错误码
    public var errorCode: UInt16
    /// SQL 状态标记 ('#')
    public var sqlStateMarker: ?UInt8
    /// SQL 状态 (5 字节)
    public var sqlState: ?Array<UInt8>
    /// 错误消息
    public var errorMessage: SQLData

    public init() {
        header = 0xff
        errorCode = 0
        sqlStateMarker = None
        sqlState = None
        errorMessage = SQLData.empty()
    }

    /// 释放资源
    /// 对应 Bun: ErrorPacket.deinit
    public func deinit(): Unit {
        errorMessage.deinit()
    }

    /// 从 Reader 解码
    /// 对应 Bun: ErrorPacket.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        header = reader.readInt8()
        if (header != 0xff) {
            return  // InvalidErrorPacket
        }

        errorCode = reader.readInt16()

        // 检查是否有 SQL 状态标记
        let nextByte = reader.readInt8()
        if (nextByte == UInt8('#')) {
            sqlStateMarker = UInt8('#')
            let stateData = reader.readBytes(5)
            sqlState = stateData.slice()
        } else {
            // 无 SQL 状态，回退 1 字节
            reader.skip(-1)
        }

        // 读取错误消息 (剩余字节)
        let peeked = reader.peek()
        if (peeked.size > 0) {
            errorMessage = reader.readBytes(peeked.size)
        }
    }

    /// 创建 MySQL 错误信息
    public static func createMySQLError(code: String, errno: ?UInt16, sqlState: ?Array<UInt8>): ErrorPacket {
        let pkt = ErrorPacket()
        pkt.errorCode = errno.getOr(0)
        pkt.sqlState = sqlState
        pkt.errorMessage = SQLData.fromString(code)
        return pkt
    }
}
