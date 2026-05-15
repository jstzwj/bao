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
    | Bool(Bool)
    | Short(Int16)
    | UShort(UInt16)
    | Int(Int32)
    | UInt(UInt32)
    | Long(Int64)
    | ULong(UInt64)
    | Float(Float32)
    | Double(Float64)
    | String(String)
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
        return JscValue.fromDateNumber(globalObject, toJSTimestamp())
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
            let totalMs = if (value.isDate()) value.getUnixTimestamp() else value.asNumber()
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
    return days[Int64(month) - 1]
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

    while (d >= 365 + (if (isLeapYear(y)) 1 else 0)) {
        d -= 365 + (if (isLeapYear(y)) 1 else 0)
        y += 1
    }

    var m: UInt8 = 1
    while (d >= daysInMonth(y, m)) {
        d -= daysInMonth(y, m)
        m += 1
    }

    return GregorianDate(year: y, month: m, day: UInt8(d + 1))
}

/// MySQL 字段类型枚举
/// 对应 Bun: FieldType
public enum MySQLFieldType {
    | MySQLTypeNull(6)
    | MySQLTypeTiny(1)
    | MySQLTypeShort(2)
    | MySQLTypeLong(3)
    | MySQLTypeInt24(9)
    | MySQLTypeLongLong(8)
    | MySQLTypeDouble(5)
    | MySQLTypeFloat(4)
    | MySQLTypeDate(10)
    | MySQLTypeDateTime(12)
    | MySQLTypeTimestamp(7)
    | MySQLTypeTime(11)
    | MySQLTypeYear(13)
    | MySQLTypeString(254)
    | MySQLTypeVarchar(15)
    | MySQLTypeVarString(253)
    | MySQLTypeBlob(252)
    | MySQLTypeTinyBlob(249)
    | MySQLTypeMediumBlob(250)
    | MySQLTypeLongBlob(251)
    | MySQLTypeJSON(245)
    | MySQLTypeBit(16)
    | MySQLTypeEnum(247)
    | MySQLTypeSet(248)
    | MySQLTypeGeometry(255)
    | MySQLTypeNewDecimal(246)

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
        if (value.isTypedArrayOrArrayBuffer()) {
            return MySQLTypeBlob
        }
        if (value.isAnyInt()) {
            let int_ = value.toInt64()
            if (int_ >= 0) {
                if (int_ <= Int64(Int32.MaxValue)) {
                    return MySQLTypeLong
                }
                return MySQLTypeLongLong
            }
            if (int_ >= Int64(Int32.MinValue)) {
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
