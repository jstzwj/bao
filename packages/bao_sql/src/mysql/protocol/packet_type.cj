// 严格翻译自: src/sql/mysql/protocol/PacketType.zig
// MySQL 协议包类型

package bao_sql.mysql.protocol

/// MySQL 协议包类型标识
/// 严格翻译自 Bun: PacketType (enum u8)
/// 包含服务端包、客户端/服务端共享包类型
public enum PacketType {
    // 服务端包
    | OK
    | EOF
    | ERROR
    | LOCAL_INFILE

    // 客户端/服务端共享包
    | HANDSHAKE
    | MORE_DATA

    /// AUTH_SWITCH 常量，值为 0xfe
    public static const AUTH_SWITCH: UInt8 = 0xfe

    public func value(): UInt8 {
        match (this) {
            case PacketType.OK => UInt8(0x00)
            case PacketType.EOF => UInt8(0xfe)
            case PacketType.ERROR => UInt8(0xff)
            case PacketType.LOCAL_INFILE => UInt8(0xfb)
            case PacketType.HANDSHAKE => UInt8(0x0a)
            case PacketType.MORE_DATA => UInt8(0x01)
        }
    }
}
