// MySQL EOF 数据包
// 严格翻译自: src/sql/mysql/protocol/EOFPacket.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_sql.*
import bao_sql.mysql.protocol.*

/// MySQL EOF 包
/// 对应 Bun: EOFPacket
/// 在 CLIENT_DEPRECATE_EOF 之前，服务器发送此包标记结果集结束
public class EOFPacket {
    /// 包头 (0xfe)
    public var header: UInt8
    /// 警告数
    public var warnings: UInt16
    /// 状态标志
    public var statusFlags: StatusFlags

    public init() {
        header = 0xfe
        warnings = 0
        statusFlags = StatusFlags()
    }

    /// 从 Reader 解码
    /// 对应 Bun: EOFPacket.decodeInternal
    public func decode(reader: MySQLPacketReader): Unit {
        header = reader.int8()
        if (header != 0xfe) {
            return  // InvalidEOFPacket
        }

        warnings = reader.int16()
        statusFlags = StatusFlags.fromInt(reader.int16())
    }
}
