// 严格翻译自: src/sql_jsc/postgres/types/json.zig
// Postgres JSON 类型 JS 转换

package bao_sql_jsc

import bao_core.*
import bao_jsc.*

/// JSON 类型转换
/// 对应 Bun: types/json.zig
public class PostgresJsonType {
    public static let TO: Int32 = 114
    public static let FROM: Array<Int16> = [114, 3802]

    /// 转换为 JS 值（解析 JSON）
    /// 对应 Bun: json.toJS
    public static func toJS(globalObject: JscJSGlobalObject,
                             data: Array<UInt8>): JscValue {
        let str = String.fromUtf8(data)
        return JscValue.parseJSON(globalObject, str)
    }
}
