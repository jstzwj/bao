// MySQL 包类型
// 对应 Bun: src/sql/mysql/protocol/PacketType.zig
package bao_sql

/// MySQL 协议包类型标识
/// 对应 Bun: PacketType (enum u8)
public enum PacketType <: UInt8 {
    // 服务器包类型
    | OK(UInt8)            // 0x00 - OK 包
    | EOF(UInt8)           // 0xfe - EOF 包
    | ERROR(UInt8)         // 0xff - 错误包
    | LOCAL_INFILE(UInt8)  // 0xfb - 本地文件请求

    // 客户端/服务器包类型
    | HANDSHAKE(UInt8)     // 0x0a - 握手包
    | MORE_DATA(UInt8)     // 0x01 - 更多数据

    /// 认证切换包 (值与 EOF 相同，都是 0xfe)
    public static let AUTH_SWITCH: UInt8 = 0xfe
}
