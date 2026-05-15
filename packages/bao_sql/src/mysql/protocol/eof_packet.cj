// MySQL EOF 包
// 对应 Bun: src/sql/mysql/protocol/EOFPacket.zig
package bao_sql

/// MySQL EOF 包
/// 对应 Bun: EOFPacket (struct)
///
/// 在 CLIENT_DEPRECATE_EOF 未设置时，服务器使用 EOF 包来标记
/// 结果集的结束或字段定义列表的结束
public class EOFPacket {
    /// 包头 (0xfe)
    /// 对应 Bun: header u8
    public var header: UInt8

    /// 警告计数
    /// 对应 Bun: warnings u16
    public var warnings: UInt16

    /// 状态标志
    /// 对应 Bun: status_flags StatusFlags
    public var statusFlags: StatusFlags

    public init() {
        header = 0xfe
        warnings = 0
        statusFlags = StatusFlags()
    }

    public init(header: UInt8, warnings: UInt16, statusFlags: StatusFlags) {
        this.header = header
        this.warnings = warnings
        this.statusFlags = statusFlags
    }

    /// 从读取器解码 EOF 包
    /// 对应 Bun: EOFPacket.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        header = reader.int8()
        if (header != 0xfe) {
            throw MySQLError.InvalidEOFPacket
        }

        warnings = reader.int16()
        statusFlags = StatusFlags.fromInt(reader.int16())
    }
}
