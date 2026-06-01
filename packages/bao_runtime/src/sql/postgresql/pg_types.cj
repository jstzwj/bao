// PostgreSQL 整数类型
// 严格翻译自: bun/src/sql/postgres/types/int_types.zig
//   pub const int4 = u32;
//   pub const PostgresInt32 = int4;
//   pub const int8 = i64;
//   pub const PostgresInt64 = int8;
//   pub const short = u16;
//   pub const PostgresShort = u16;
package bao_runtime.sql.postgresql

/// PostgreSQL int4 类型（无符号 32 位）
public type PostgresInt32 = UInt32

/// PostgreSQL int8 类型（有符号 64 位）
public type PostgresInt64 = Int64

/// PostgreSQL short 类型（无符号 16 位）
public type PostgresShort = UInt16

/// int4 类型别名
public type PGInt4 = UInt32

/// int8 类型别名
public type PGInt8 = Int64

/// short 类型别名
public type PGShort = UInt16

/// 将 int4 值转为大端字节数组
/// 对应 Bun Int32()
public func int32ToBytes(value: UInt32): Array<UInt8> {
    let b0 = UInt8(value & 0xFF)
    let b1 = UInt8((value >> 8) & 0xFF)
    let b2 = UInt8((value >> 16) & 0xFF)
    let b3 = UInt8((value >> 24) & 0xFF)
    // 网络字节序（大端）
    return [b3, b2, b1, b0]
}

/// 将 int4 值转为大端字节数组（用于协议消息）
public func int32BigEndian(value: UInt32): Array<UInt8> {
    let b0 = UInt8((value >> 24) & 0xFF)
    let b1 = UInt8((value >> 16) & 0xFF)
    let b2 = UInt8((value >> 8) & 0xFF)
    let b3 = UInt8(value & 0xFF)
    return [b0, b1, b2, b3]
}

/// 将 Int16 值转为大端字节数组
public func int16BigEndian(value: UInt16): Array<UInt8> {
    let b0 = UInt8((value >> 8) & 0xFF)
    let b1 = UInt8(value & 0xFF)
    return [b0, b1]
}

/// 从大端字节数组读取 UInt16
public func readUInt16BE(bytes: Array<UInt8>, offset: Int64): UInt16 {
    let b0 = UInt16(bytes[offset]) << 8
    let b1 = UInt16(bytes[offset + 1])
    return b0 | b1
}

/// 从大端字节数组读取 UInt32
public func readUInt32BE(bytes: Array<UInt8>, offset: Int64): UInt32 {
    let b0 = UInt32(bytes[offset]) << 24
    let b1 = UInt32(bytes[offset + 1]) << 16
    let b2 = UInt32(bytes[offset + 2]) << 8
    let b3 = UInt32(bytes[offset + 3])
    return b0 | b1 | b2 | b3
}

/// 从大端字节数组读取 Int64
public func readInt64BE(bytes: Array<UInt8>, offset: Int64): Int64 {
    let b0 = Int64(bytes[offset]) << 56
    let b1 = Int64(bytes[offset + 1]) << 48
    let b2 = Int64(bytes[offset + 2]) << 40
    let b3 = Int64(bytes[offset + 3]) << 32
    let b4 = Int64(bytes[offset + 4]) << 24
    let b5 = Int64(bytes[offset + 5]) << 16
    let b6 = Int64(bytes[offset + 6]) << 8
    let b7 = Int64(bytes[offset + 7])
    return b0 | b1 | b2 | b3 | b4 | b5 | b6 | b7
}
