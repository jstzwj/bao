// 严格翻译自: src/sql_jsc/postgres/types/bytea.zig
// Postgres bytea 类型 JS 转换

package bao_sql_jsc

import bao_core.*
import bao_jsc.*

/// bytea 类型常量和转换
/// 对应 Bun: types/bytea.zig
public class PostgresByteaType {
    public static let TO: Int32 = 17
    public static let FROM: Array<Int16> = [17]

    /// 转换为 JS Buffer 值
    /// 对应 Bun: bytea.toJS
    public static func toJS(globalObject: JscJSGlobalObject,
                             data: Array<UInt8>): JscValue {
        return JscValue.createBuffer(globalObject, data)
    }
}
