// MySQL 数据包类型标记
// 严格翻译自: src/sql/mysql/protocol/PacketType.zig
package bao_runtime.sql.mysql

/// MySQL 协议数据包类型
/// 对应 Bun: PacketType (enum u8)
public enum PacketType <: UInt8 {
    // 服务端包
    | OK(0x00)
    | EOF(0xfe)
    | ERROR(0xff)
    | LOCAL_INFILE(0xfb)
    // 客户端/服务端共包
    | HANDSHAKE(0x0a)
    | MORE_DATA(0x01)

    /// 认证切换的固定值
    public static let AUTH_SWITCH: UInt8 = 0xfe
}
