// 严格翻译自: src/sql_jsc/postgres/types/json.zig
// Postgres JSON 类型 JS 转换

package bao_sql_jsc.postgres.types

import bao_core.*
import bao_jsc.*

/// JSON 类型转换
/// 对应 Bun: types/json.zig
public class PostgresJsonType {
    public static let TO: Int32 = 114
    public static let FROM: Array<Int16> = [114, 3802]

    /// 转换为 JS 值（解析 JSON）
    /// 对应 Bun: json.toJS
    /// 解析 JSON 字符串并返回 JS 值 (对象/数组/原始类型)
    public static func toJS(globalObject: JscJSGlobalObject,
                             data: Array<UInt8>): JscValue {
        let str = String.fromUtf8(data)
        // 使用 JSC 的 JSON.parse 来解析 JSON 字符串
        // 对应 Bun: globalObject.prettyPrintJSON(str) / JSC FFI JSONParse
        // 通过 JSC JSGlobalObject 的 JSON.parse 能力来解析
        let parsed = globalObject.jsonParse(str)
        match (parsed) {
            case Some(value) => return value
            case None => return JscValue(str)
        }
    }
}
