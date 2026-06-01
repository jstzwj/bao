// MySQL 数据包类型标记
// 严格翻译自: src/sql/mysql/protocol/PacketType.zig
package bao_runtime.sql.mysql

/// MySQL 协议数据包类型
/// 对应 Bun: PacketType (enum u8)
public enum PacketType {
    | OK            // 0x00
    | Eof           // 0xfe
    | Error         // 0xff
    | LocalInfile   // 0xfb
    | Handshake     // 0x0a
    | MoreData      // 0x01
}

/// 认证切换的固定值
public let AUTH_SWITCH: UInt8 = 0xfe
