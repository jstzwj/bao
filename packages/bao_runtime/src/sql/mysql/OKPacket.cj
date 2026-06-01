// MySQL OK 数据包
// 严格翻译自: src/sql/mysql/protocol/OKPacket.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_sql.*
import bao_sql.mysql.protocol.*
import bao_runtime.sql.shared.*

/// MySQL OK 响应包
/// 对应 Bun: OKPacket
/// 服务器返回操作成功时发送此包
public class OKPacket {
    /// 包头 (0x00 或 0xfe)
    public var header: UInt8
    /// 影响的行数
    public var affectedRows: UInt64
    /// 最后插入 ID
    public var lastInsertId: UInt64
    /// 状态标志
    public var statusFlags: StatusFlags
    /// 警告数
    public var warnings: UInt16
    /// 附加信息
    public var info: SQLData
    /// 会话状态变更
    public var sessionStateChanges: SQLData
    /// 包大小
    public var packetSize: UInt32

    public init() {
        header = 0x00
        affectedRows = 0
        lastInsertId = 0
        statusFlags = StatusFlags()
        warnings = 0
        info = SQLData.empty()
        sessionStateChanges = SQLData.empty()
        packetSize = 0
    }

    /// 释放资源
    /// 对应 Bun: OKPacket.deinit
    public func deinit(): Unit {
        info.deinit()
        sessionStateChanges.deinit()
    }

    /// 从 Reader 解码
    /// 对应 Bun: OKPacket.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        var readSize: Int64 = 5  // header + status flags + warnings

        header = reader.int8()
        if (header != 0x00 && header != 0xfe) {
            return  // InvalidOKPacket
        }

        // Affected rows (长度编码整数)
        let affectedResult = reader.encodedLenIntWithSize()
        affectedRows = affectedResult.value
        readSize = affectedResult.bytesRead

        // Last insert ID (长度编码整数)
        let insertResult = reader.encodedLenIntWithSize()
        lastInsertId = insertResult.value
        readSize = insertResult.bytesRead

        // Status flags (2 字节)
        let sf = reader.int16()
        statusFlags = StatusFlags.fromInt(sf)

        // Warnings (2 字节)
        warnings = reader.int16()

        // Info (剩余字节)
        let peeked = reader.peek()
        if (peeked.size > 0 && packetSize > UInt32(readSize)) {
            let remaining = Int64(packetSize) - readSize
            if (remaining > 0) {
                info = SQLData.fromTemporary(reader.read(remaining))
            }
        }
    }
}
