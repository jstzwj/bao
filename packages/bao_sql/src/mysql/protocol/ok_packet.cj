// MySQL OK 包
// 对应 Bun: src/sql/mysql/protocol/OKPacket.zig
package bao_sql.mysql.protocol

/// MySQL OK 响应包
/// 对应 Bun: OKPacket (struct)
///
/// 服务器在成功完成命令后发送 OK 包
public class OKPacket {
    /// 包头 (0x00 或 0xfe 表示 EOF)
    /// 对应 Bun: header u8
    public var header: UInt8

    /// 受影响的行数
    /// 对应 Bun: affected_rows u64
    public var affectedRows: UInt64

    /// 最后插入的自增 ID
    /// 对应 Bun: last_insert_id u64
    public var lastInsertId: UInt64

    /// 状态标志
    /// 对应 Bun: status_flags StatusFlags
    public var statusFlags: StatusFlags

    /// 警告数
    /// 对应 Bun: warnings u16
    public var warnings: UInt16

    /// 附加信息
    /// 对应 Bun: info Data
    public var info: Array<UInt8>

    /// 会话状态变更
    /// 对应 Bun: session_state_changes Data
    public var sessionStateChanges: Array<UInt8>

    /// 包大小
    /// 对应 Bun: packet_size u24
    public var packetSize: UInt32

    public init() {
        header = 0x00
        affectedRows = 0
        lastInsertId = 0
        statusFlags = StatusFlags()
        warnings = 0
        info = Array<UInt8>()
        sessionStateChanges = Array<UInt8>()
        packetSize = 0
    }

    public init(packetSize: UInt32) {
        header = 0x00
        affectedRows = 0
        lastInsertId = 0
        statusFlags = StatusFlags()
        warnings = 0
        info = Array<UInt8>()
        sessionStateChanges = Array<UInt8>()
        this.packetSize = packetSize
    }

    /// 释放资源
    /// 对应 Bun: OKPacket.deinit
    public func deinit(): Unit {
        info = Array<UInt8>()
        sessionStateChanges = Array<UInt8>()
    }

    /// 从读取器解码 OK 包
    /// 对应 Bun: OKPacket.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        var readSize: Int64 = 5 // header + status flags + warnings

        header = reader.int8()
        if (header != 0x00 && header != 0xfe) {
            throw MySQLError.InvalidOKPacket
        }

        // 受影响的行数 (长度编码整数)
        affectedRows = reader.encodedLenIntWithSize(&readSize)

        // 最后插入 ID (长度编码整数)
        lastInsertId = reader.encodedLenIntWithSize(&readSize)

        // 状态标志
        statusFlags = StatusFlags.fromInt(reader.int16())
        // 警告数
        warnings = reader.int16()

        // 附加信息 (EOF 终止字符串)
        let peek = reader.peek()
        if (peek.size > 0 && packetSize > UInt32(readSize)) {
            let remaining = packetSize - UInt32(readSize)
            info = reader.read(Int64(remaining))
        }
    }
}
