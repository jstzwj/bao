// MySQL 包头
// 对应 Bun: src/sql/mysql/protocol/PacketHeader.zig
package bao_sql.mysql.protocol

/// MySQL 协议包头
/// 对应 Bun: PacketHeader (struct)
///
/// MySQL 协议包头部固定为 4 字节:
/// - 3 字节: payload 长度 (小端序)
/// - 1 字节: 序列号
public class PacketHeader {
    /// payload 长度 (低 24 位, 最大 16MB)
    /// 对应 Bun: length u24
    public var length: UInt32

    /// 序列号
    /// 对应 Bun: sequence_id u8
    public var sequenceId: UInt8

    /// 包头固定大小
    public static let size: Int64 = 4

    public init() {
        length = 0
        sequenceId = 0
    }

    public init(length: UInt32, sequenceId: UInt8) {
        this.length = length
        this.sequenceId = sequenceId
    }

    /// 从字节流解码包头
    /// 对应 Bun: PacketHeader.decode
    public static func decode(bytes: Array<UInt8>): ?PacketHeader {
        if (bytes.size < 4) {
            return None
        }

        let length: UInt32 = UInt32(bytes[0]) |
            (UInt32(bytes[1]) << 8) |
            (UInt32(bytes[2]) << 16)
        let sequenceId: UInt8 = bytes[3]

        return Some(PacketHeader(length, sequenceId))
    }

    /// 将包头编码为 4 字节数组
    /// 对应 Bun: PacketHeader.encode
    public func encode(): Array<UInt8> {
        let result = Array<UInt8>(4, repeat: UInt8(0))
        result[0] = UInt8(length & 0xff)
        result[1] = UInt8((length >> 8) & 0xff)
        result[2] = UInt8((length >> 16) & 0xff)
        result[3] = sequenceId
        return result
    }
}
