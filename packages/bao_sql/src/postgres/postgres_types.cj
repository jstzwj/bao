// 严格翻译自: src/sql/postgres/PostgresTypes.zig
// PostgreSQL 类型定义和导入
package bao_sql.postgres

import bao_sql.postgres.types.Tag

/// PostgreSQL 类型定义
/// 对应 Bun: PostgresTypes (re-exports)
public class PostgresTypes {

    /// 将整数转为 4 字节大端数组
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
