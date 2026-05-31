// MySQL 数据包头
// 严格翻译自: src/sql/mysql/protocol/PacketHeader.zig
package bao_runtime.sql.mysql

import bao_core.*

/// MySQL 协议数据包头
/// 对应 Bun: PacketHeader
/// 包含长度 (3 字节) 和序列号 (1 字节)
public class PacketHeader {
    /// 包体长度 (最多 16MB)
    public var length: UInt32  // 原始为 u24，仓颉用 UInt32
    /// 序列号
    public var sequenceId: UInt8

    /// 包头固定大小 = 4 字节
    public static let SIZE: Int64 = 4

    public init() {
        length = 0
        sequenceId = 0
    }

    public init(length: UInt32, sequenceId: UInt8) {
        this.length = length
        this.sequenceId = sequenceId
    }

    /// 从字节解码包头
    /// 对应 Bun: PacketHeader.decode
    public static func decode(bytes: Array<UInt8>): ?PacketHeader {
        if (bytes.size < 4) {
            return None
        }
        let header = PacketHeader()
        header.length = UInt32(bytes[0]) |
            (UInt32(bytes[1]) << 8) |
            (UInt32(bytes[2]) << 16)
        header.sequenceId = bytes[3]
        return header
    }

    /// 编码包头为 4 字节
    /// 对应 Bun: PacketHeader.encode
    public func encode(): Array<UInt8> {
        let result = Array<UInt8>(4, item: 0)
        result[0] = UInt8(length & 0xff)
        result[1] = UInt8((length >> 8) & 0xff)
        result[2] = UInt8((length >> 16) & 0xff)
        result[3] = sequenceId
        return result
    }
}
