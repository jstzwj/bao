// 严格翻译自: src/sql/postgres/types/int_types.zig
// PostgreSQL 整数类型定义
package bao_sql.postgres.types

/// int4: PostgreSQL 32 位无符号整数
public type int4 = UInt32
/// int8: PostgreSQL 64 位有符号整数
public type int8 = Int64
/// short: PostgreSQL 16 位无符号整数
public type short = UInt16

/// PostgresInt32 类型别名
public type PostgresInt32 = UInt32
/// PostgresInt64 类型别名
public type PostgresInt64 = Int64
/// PostgresShort 类型别名
public type PostgresShort = UInt16

/// PostgreSQL 整数类型工具
/// 对应 Bun: int_types.zig
public class IntTypes {

    /// 将整数转为 4 字节大端字节数组
    /// 对应 Bun: Int32 (function)
    public static func int32(value: UInt32): Array<UInt8> {
        let arr = Array<UInt8>(4, repeat: UInt8(0))
        arr[0] = UInt8((value >> 24) & 0xFF)
        arr[1] = UInt8((value >> 16) & 0xFF)
        arr[2] = UInt8((value >> 8) & 0xFF)
        arr[3] = UInt8(value & 0xFF)
        return arr
    }
}
