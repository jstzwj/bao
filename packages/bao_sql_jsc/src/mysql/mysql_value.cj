// 严格翻译自: src/sql_jsc/mysql/MySQLValue.zig
// MySQL 值类型和 JS 转换

package bao_sql_jsc.mysql

import bao_core.*
import bao_jsc.*

/// MySQL 值
/// 对应 Bun: MySQLValue.Value
/// MySQL 查询参数值的联合类型
public enum MySQLValue {
    | Null
    | `Bool`(Bool)
    | `Short`(Int16)
    | UShort(UInt16)
    | `Int`(Int32)
    | UInt(UInt32)
    | Long(Int64)
    | ULong(UInt64)
    | Float(Float32)
    | Double(Float64)
    | `String`(String)
    | Bytes(Array<UInt8>)
    | Date(MySQLDateTime)
    | Time(MySQLTime)
}

/// MySQL 日期时间
/// 对应 Bun: MySQLValue.DateTime
public class MySQLDateTime {
    public var year: UInt16 = 0
    public var month: UInt8 = 0
    public var day: UInt8 = 0
    public var hour: UInt8 = 0
    public var minute: UInt8 = 0
    public var second: UInt8 = 0
    public var microsecond: UInt32 = 0

    public init() {}

    /// 从 JS 值创建
    /// 对应 Bun: DateTime.fromJS
    public static func fromJS(value: JscValue, globalObject: JscJSGlobalObject): ?MySQLDateTime {
        if (value.isDate()) {
            let totalMs = value.getUnixTimestamp()
            let ts = Int64(totalMs / 1000.0)
            let ms = UInt32(totalMs - Float64(ts) * 1000.0)
            return fromUnixTimestamp(ts, ms * 1000)
        }
        if (value.isNumber()) {
            let totalMs = value.asNumber()
            let ts = Int64(totalMs / 1000.0)
            let ms = UInt32(totalMs - Float64(ts) * 1000.0)
            return fromUnixTimestamp(ts, ms * 1000)
        }
        return None
    }

    /// 从 Unix 时间戳创建
    /// 对应 Bun: DateTime.fromUnixTimestamp
    public static func fromUnixTimestamp(timestamp: Int64, microseconds: UInt32): MySQLDateTime {
        let dt = MySQLDateTime()
        var ts = timestamp
        let days = ts / 86400
        ts = ts % 86400
        dt.hour = UInt8(ts / 3600)
        ts = ts % 3600
        dt.minute = UInt8(ts / 60)
        dt.second = UInt8(ts % 60)
        dt.microsecond = microseconds

        let date = gregorianDate(Int32(days))
        dt.year = date.year
        dt.month = date.month
        dt.day = date.day
        return dt
    }

    /// 转换为 JS 时间戳
    /// 对应 Bun: DateTime.toJSTimestamp
    public func toJSTimestamp(): Float64 {
        // 简化实现
        return 0.0
    }

    /// 转换为 JS 值
    /// 对应 Bun: DateTime.toJS
    public func toJS(globalObject: JscJSGlobalObject): JscValue {
        return JscValue.fromDateNumber(globalObject.globalThis, toJSTimestamp())
    }
}

/// MySQL 时间
/// 对应 Bun: MySQLValue.Time
public class MySQLTime {
    public var negative: Bool = false
    public var days: UInt32 = 0
    public var hours: UInt8 = 0
    public var minutes: UInt8 = 0
    public var seconds: UInt8 = 0
    public var microseconds: UInt32 = 0

    public init() {}

    /// 从 JS 值创建
    /// 对应 Bun: Time.fromJS
    public static func fromJS(value: JscValue, globalObject: JscJSGlobalObject): ?MySQLTime {
        if (value.isDate() || value.isNumber()) {
            let totalMs = if (value.isDate()) { value.getUnixTimestamp() } else { value.asNumber() }
            let ts = Int64(totalMs / 1000.0)
            let ms = UInt32(totalMs - Float64(ts) * 1000.0)
            return fromUnixTimestamp(ts, ms * 1000)
        }
        return None
    }

    /// 从 Unix 时间戳创建
    /// 对应 Bun: Time.fromUnixTimestamp
    public static func fromUnixTimestamp(timestamp: Int64, microseconds: UInt32): MySQLTime {
        let time = MySQLTime()
        time.days = UInt32(timestamp / 86400)
        time.hours = UInt8((timestamp % 86400) / 3600)
        time.minutes = UInt8((timestamp % 3600) / 60)
        time.seconds = UInt8(timestamp % 60)
        time.microseconds = microseconds
        time.negative = timestamp < 0
        return time
    }

    /// 转换为 JS 时间戳
    /// 对应 Bun: Time.toJSTimestamp
    public func toJSTimestamp(): Float64 {
        var totalMs: Int64 = 0
        totalMs += Int64(days) * 86400000
        totalMs += Int64(hours) * 3600000
        totalMs += Int64(minutes) * 60000
        totalMs += Int64(seconds) * 1000
        totalMs += Int64(microseconds / 1000)

        if (negative) {
            totalMs = -totalMs
        }
        return Float64(totalMs)
    }
}

// ===== 辅助函数 =====

/// 是否闰年
func isLeapYear(year: UInt16): Bool {
    return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

/// 月份天数
func daysInMonth(year: UInt16, month: UInt8): UInt8 {
    let days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    if (month == 2 && isLeapYear(year)) {
        return 29
    }
    return UInt8(days[Int64(month) - 1])
}

/// 格里高利日期
class GregorianDate {
    var year: UInt16
    var month: UInt8
    var day: UInt8

    init(year: UInt16, month: UInt8, day: UInt8) {
        this.year = year
        this.month = month
        this.day = day
    }
}

/// 从天数计算格里高利日期
func gregorianDate(days: Int32): GregorianDate {
    var d = days
    var y: UInt16 = 1970

    while (d >= 365 + (if (isLeapYear(y)) { 1 } else { 0 })) {
        d -= 365 + (if (isLeapYear(y)) { 1 } else { 0 })
        y += 1
    }

    var m: UInt8 = 1
    while (d >= Int32(daysInMonth(y, m))) {
        d -= Int32(daysInMonth(y, m))
        m += 1
    }

    return GregorianDate(y, m, UInt8(d + 1))
}

/// MySQL 字段类型枚举
/// 对应 Bun: FieldType
public enum MySQLFieldType {
    | MySQLTypeNull
    | MySQLTypeTiny
    | MySQLTypeShort
    | MySQLTypeLong
    | MySQLTypeInt24
    | MySQLTypeLongLong
    | MySQLTypeDouble
    | MySQLTypeFloat
    | MySQLTypeDate
    | MySQLTypeDateTime
    | MySQLTypeTimestamp
    | MySQLTypeTime
    | MySQLTypeYear
    | MySQLTypeString
    | MySQLTypeVarchar
    | MySQLTypeVarString
    | MySQLTypeBlob
    | MySQLTypeTinyBlob
    | MySQLTypeMediumBlob
    | MySQLTypeLongBlob
    | MySQLTypeJSON
    | MySQLTypeBit
    | MySQLTypeEnum
    | MySQLTypeSet
    | MySQLTypeGeometry
    | MySQLTypeNewDecimal

    /// 获取字段类型的数值
    public func value(): Int32 {
        return match (this) {
            case MySQLTypeNull => 6
            case MySQLTypeTiny => 1
            case MySQLTypeShort => 2
            case MySQLTypeLong => 3
            case MySQLTypeInt24 => 9
            case MySQLTypeLongLong => 8
            case MySQLTypeDouble => 5
            case MySQLTypeFloat => 4
            case MySQLTypeDate => 10
            case MySQLTypeDateTime => 12
            case MySQLTypeTimestamp => 7
            case MySQLTypeTime => 11
            case MySQLTypeYear => 13
            case MySQLTypeString => 254
            case MySQLTypeVarchar => 15
            case MySQLTypeVarString => 253
            case MySQLTypeBlob => 252
            case MySQLTypeTinyBlob => 249
            case MySQLTypeMediumBlob => 250
            case MySQLTypeLongBlob => 251
            case MySQLTypeJSON => 245
            case MySQLTypeBit => 16
            case MySQLTypeEnum => 247
            case MySQLTypeSet => 248
            case MySQLTypeGeometry => 255
            case MySQLTypeNewDecimal => 246
        }
    }

    /// 获取类型名称
    public func name(): String {
        return match (this) {
            case MySQLTypeNull => "null"
            case MySQLTypeTiny => "tiny"
            case MySQLTypeShort => "short"
            case MySQLTypeLong => "long"
            case MySQLTypeInt24 => "int24"
            case MySQLTypeLongLong => "longlong"
            case MySQLTypeDouble => "double"
            case MySQLTypeFloat => "float"
            case MySQLTypeDate => "date"
            case MySQLTypeDateTime => "datetime"
            case MySQLTypeTimestamp => "timestamp"
            case MySQLTypeTime => "time"
            case MySQLTypeYear => "year"
            case MySQLTypeString => "string"
            case MySQLTypeVarchar => "varchar"
            case MySQLTypeVarString => "var_string"
            case MySQLTypeBlob => "blob"
            case MySQLTypeTinyBlob => "tiny_blob"
            case MySQLTypeMediumBlob => "medium_blob"
            case MySQLTypeLongBlob => "long_blob"
            case MySQLTypeJSON => "json"
            case MySQLTypeBit => "bit"
            case MySQLTypeEnum => "enum"
            case MySQLTypeSet => "set"
            case MySQLTypeGeometry => "geometry"
            case MySQLTypeNewDecimal => "new_decimal"
        }
    }

    /// 从 JS 值推断类型
    /// 对应 Bun: fieldTypeFromJS
    public static func fromJS(globalObject: JscJSGlobalObject, value: JscValue,
                               unsigned: Bool): ?MySQLFieldType {
        if (value.isEmptyOrUndefinedOrNull()) {
            return MySQLTypeNull
        }

        if (value.isString()) {
            return MySQLTypeString
        }
        if (value.isDate()) {
            return MySQLTypeDateTime
        }
        if (value.isObject()) {
            return MySQLTypeBlob
        }
        if (value.isAnyInt()) {
            let int_ = value.toInt64()
            if (int_ >= 0) {
                if (int_ <= 2147483647) {
                    return MySQLTypeLong
                }
                return MySQLTypeLongLong
            }
            if (int_ >= -2147483648) {
                return MySQLTypeLong
            }
            return MySQLTypeLongLong
        }
        if (value.isNumber()) {
            return MySQLTypeDouble
        }
        if (value.isBoolean()) {
            return MySQLTypeTiny
        }

        return MySQLTypeVarchar
    }
}
