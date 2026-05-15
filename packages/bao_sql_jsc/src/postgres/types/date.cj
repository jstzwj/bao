// 严格翻译自: src/sql_jsc/postgres/types/date.zig
// Postgres 日期/时间戳类型 JS 转换

package bao_sql_jsc

import bao_core.*
import bao_jsc.*

/// Postgres 纪元（2000-01-01 00:00:00 UTC 的 Unix 毫秒时间戳）
let POSTGRES_EPOCH_MS: Float64 = 946684800000.0

/// 日期类型转换
/// 对应 Bun: types/date.zig
public class PostgresDateType {
    public static let TO: Int32 = 1184
    public static let FROM: Array<Int16> = [1082, 1114, 1184]

    /// 从二进制数据解析日期
    /// 对应 Bun: date.fromBinary
    public static func fromBinary(bytes: Array<UInt8>): Float64 {
        if (bytes.size < 8) {
            return 0.0
        }
        let microseconds = readBEInt64(bytes)
        let doubleMicroseconds = Float64(microseconds)
        return (doubleMicroseconds / 1000.0) + POSTGRES_EPOCH_MS
    }

    /// 从 JS 值转换
    /// 对应 Bun: date.fromJS
    public static func fromJS(globalObject: JscJSGlobalObject,
                               value: JscValue): Int64 {
        let doubleValue = if (value.isDate()) {
            value.getUnixTimestamp()
        } else if (value.isNumber()) {
            value.asNumber()
        } else {
            0.0
        }

        let unixTimestamp = Int64(doubleValue)
        return (unixTimestamp - Int64(POSTGRES_EPOCH_MS)) * 1000
    }

    /// 转换为 JS Date 值
    /// 对应 Bun: date.toJS
    public static func toJS(globalObject: JscJSGlobalObject, microseconds: Int64): JscValue {
        let ms = microseconds / 1000 + Int64(POSTGRES_EPOCH_MS)
        return JscValue.fromDateNumber(globalObject, Float64(ms))
    }
}
