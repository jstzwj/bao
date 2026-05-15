// 严格翻译自: src/sql_jsc/postgres/types/PostgresString.zig
// Postgres 字符串类型 JS 转换

package bao_sql_jsc.postgres.types

import bao_core.*
import bao_jsc.*

/// Postgres 字符串类型转换
/// 对应 Bun: types/PostgresString.zig
public class PostgresStringType {
    public static let TO: Int32 = 25
    public static let FROM: Array<Int16> = [1002]

    /// 转换为 JS 字符串值
    /// 对应 Bun: PostgresString.toJS
    public static func toJS(globalObject: JscJSGlobalObject,
                             value: String): JscValue {
        return JscValue(value)
    }

    /// 带类型转换
    /// 对应 Bun: PostgresString.toJSWithType
    public static func toJSWithType(globalObject: JscJSGlobalObject,
                                     value: Array<UInt8>): JscValue {
        let str = String.fromUtf8(value)
        return JscValue(str)
    }
}
