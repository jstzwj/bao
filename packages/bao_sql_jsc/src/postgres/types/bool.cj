// 严格翻译自: src/sql_jsc/postgres/types/bool.zig
// Postgres 布尔类型 JS 转换

package bao_sql_jsc.postgres.types

import bao_core.*
import bao_jsc.*

/// 布尔类型常量
/// 对应 Bun: types/bool.zig
public class PostgresBoolType {
    public static let TO: Int32 = 16
    public static let FROM: Array<Int16> = [16]

    /// 转换为 JS 值
    /// 对应 Bun: bool.toJS
    public static func toJS(globalObject: JscJSGlobalObject, value: Bool): JscValue {
        return JscValue(value)
    }
}
