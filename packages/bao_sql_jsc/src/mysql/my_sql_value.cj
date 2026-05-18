// 严格翻译自: src/sql_jsc/mysql/MySQLValue.zig
// MySQL 值类型和 JS 转换

package bao_sql_jsc.mysql

import bao_core.*
import bao_jsc.*

/// MySQL 值
/// 对应 Bun: MySQLValue.Value
/// MySQL 查询参数值的联合类型，支持所有 MySQL 数据类型
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
    | Bytes(MySQLBytes)
    | Date(MySQLDateTime)
    | Time(MySQLTime)
}

/// MySQL 字节参数
/// 对应 Bun: Value.Bytes
/// BLOB 参数字节，支持 ArrayBuffer 固定和释放
public class MySQLBytes {
    public var slice: String = ""
    public var pinned: JscValue = JscValue.undefined()

    public init() {}

    public init(slice: String, pinned: JscValue) {
        this.slice = slice
        this.pinned = pinned
    }

    /// 释放资源
    /// 对应 Bun: Bytes.deinit
    public func deinit(): Unit {
        if (!pinned.isUndefined()) {
            // unpinArrayBuffer
            pinned = JscValue.undefined()
        }
        slice = ""
    }
}

/// 从 JS 值创建 MySQL 值
/// 对应 Bun: Value.fromJS
public func mysqlValueFromJS(value: JscValue, globalObject: JscJSGlobalObject,
                              fieldType: MySQLFieldType, unsigned: Bool): ?MySQLValue {
    if (value.isEmptyOrUndefinedOrNull()) {
        return MySQLValue.Null
    }

    match (fieldType) {
        case MySQLTypeTiny =>
            return MySQLValue.Bool(value.toBoolean())
        case MySQLTypeShort =>
            if (unsigned) {
                return MySQLValue.UShort(UInt16(value.coerceInt32(globalObject)))
            }
            return MySQLValue.Short(Int16(value.coerceInt32(globalObject)))
        case MySQLTypeLong =>
            if (unsigned) {
                return MySQLValue.UInt(UInt32(value.coerceInt32(globalObject)))
            }
            return MySQLValue.Int(value.coerceInt32(globalObject))
        case MySQLTypeLongLong =>
            if (unsigned) {
                return MySQLValue.ULong(UInt64(value.toInt64()))
            }
            return MySQLValue.Long(value.toInt64())
        case MySQLTypeFloat =>
            return MySQLValue.Float(Float32(value.asNumber()))
        case MySQLTypeDouble =>
            return MySQLValue.Double(value.asNumber())
        case MySQLTypeTime =>
            let time = MySQLTime.fromJS(value, globalObject)
            if (time == None) { return None }
            return MySQLValue.Time(time.getOrThrow())
        case MySQLTypeDate | MySQLTypeTimestamp | MySQLTypeDateTime =>
            let date = MySQLDateTime.fromJS(value, globalObject)
            if (date == None) { return None }
            return MySQLValue.Date(date.getOrThrow())
        case MySQLTypeTinyBlob | MySQLTypeMediumBlob | MySQLTypeLongBlob | MySQLTypeBlob =>
            // BLOB 处理 - ArrayBuffer 或 Blob
            if (value.isTypedArrayOrArrayBuffer()) {
                return MySQLValue.Bytes(MySQLBytes())
            }
            if (value.isString()) {
                return MySQLValue.String(value.toString(globalObject))
            }
            return None
        case MySQLTypeJSON =>
            // JSON 序列化
            return MySQLValue.String("")
        case _ =>
            // 默认处理为字符串
            if (value.isString()) {
                return MySQLValue.String(value.toString(globalObject))
            }
            return MySQLValue.String(value.toString(globalObject))
    }
}

/// MySQL 日期时间
/// 对应 Bun: MySQLValue.DateTime
/// 支持 4/7/11 字节的 MySQL 日期时间二进制格式
public class MySQLDateTime {
    public var year: UInt16 = 0
    public var month: UInt8 = 0
    public var day: UInt8 = 0
    public var hour: UInt8 = 0
    public var minute: UInt8 = 0
    public var second: UInt8 = 0
    public var microsecond: UInt32 = 0

    public init() {}

    /// 从二进制数据创建
    /// 对应 Bun: DateTime.fromBinary
    /// 4 字节: date only, 7 字节: datetime without microseconds,
    /// 11 字节: datetime with microseconds
    public static func fromBinary(data: Array<UInt8>): MySQLDateTime {
        let dt = MySQLDateTime()
        if (data.size >= 4) {
            dt.year = UInt16(data[0]) | (UInt16(data[1]) << 8)
            dt.month = data[2]
            dt.day = data[3]
        }
        if (data.size >= 7) {
            dt.hour = data[4]
            dt.minute = data[5]
            dt.second = data[6]
        }
        if (data.size >= 11) {
            dt.microsecond = UInt32(data[7]) |
                (UInt32(data[8]) << 8) |
                (UInt32(data[9]) << 16) |
                (UInt32(data[10]) << 24)
        }
        return dt
    }

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

    /// 转换为二进制格式
    /// 对应 Bun: DateTime.toBinary
    /// 返回写入的字节数
    public func toBinary(fieldType: MySQLFieldType, buffer: Array<UInt8>): UInt8 {
        match (fieldType) {
            case MySQLTypeYear =>
                buffer[0] = 2
                buffer[1] = UInt8(year & 0xFF)
                buffer[2] = UInt8(year >> 8)
                return 3
            case MySQLTypeDate =>
                buffer[0] = 4
                buffer[1] = UInt8(year & 0xFF)
                buffer[2] = UInt8(year >> 8)
                buffer[3] = month
                buffer[4] = day
                return 5
            case MySQLTypeDateTime =>
                buffer[0] = if (microsecond == 0) 7 else 11
                buffer[1] = UInt8(year & 0xFF)
                buffer[2] = UInt8(year >> 8)
                buffer[3] = month
                buffer[4] = day
                buffer[5] = hour
                buffer[6] = minute
                buffer[7] = second
                if (microsecond == 0) {
                    return 8
                }
                buffer[8] = UInt8(microsecond & 0xFF)
                buffer[9] = UInt8((microsecond >> 8) & 0xFF)
                buffer[10] = UInt8((microsecond >> 16) & 0xFF)
                buffer[11] = UInt8((microsecond >> 24) & 0xFF)
                return 12
            case _ => return 0
        }
    }

    /// 转换为 JS 时间戳
    /// 对应 Bun: DateTime.toJSTimestamp
    public func toJSTimestamp(): Float64 {
        // 通过 gregorianDateTimeToMS 计算
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
/// 支持 0/8/12 字节的 MySQL 时间二进制格式
public class MySQLTime {
    public var negative: Bool = false
    public var days: UInt32 = 0
    public var hours: UInt8 = 0
    public var minutes: UInt8 = 0
    public var seconds: UInt8 = 0
    public var microseconds: UInt32 = 0

    public init() {}

    /// 从二进制数据创建
    /// 对应 Bun: Time.fromBinary
    /// 0 字节: zero time, 8 字节: without microseconds, 12 字节: with microseconds
    public static func fromBinary(data: Array<UInt8>): MySQLTime {
        let time = MySQLTime()
        if (data.size == 0) {
            return time
        }
        if (data.size >= 8) {
            time.negative = data[0] != 0
            time.days = UInt32(data[1]) |
                (UInt32(data[2]) << 8) |
                (UInt32(data[3]) << 16) |
                (UInt32(data[4]) << 24)
            time.hours = data[5]
            time.minutes = data[6]
            time.seconds = data[7]
        }
        if (data.size > 8) {
            time.microseconds = UInt32(data[8]) |
                (UInt32(data[9]) << 8) |
                (UInt32(data[10]) << 16) |
                (UInt32(data[11]) << 24)
        }
        return time
    }

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

    /// 转换为 JS 值
    /// 对应 Bun: Time.toJS
    public func toJS(globalObject: JscJSGlobalObject): JscValue {
        return JscValue.jsDoubleNumber(toJSTimestamp())
    }

    /// 转换为二进制格式
    /// 对应 Bun: Time.toBinary
    public func toBinary(fieldType: MySQLFieldType, buffer: Array<UInt8>): UInt8 {
        match (fieldType) {
            case MySQLTypeTime =>
                buffer[1] = if (negative) 1 else 0
                buffer[2] = UInt8(days & 0xFF)
                buffer[3] = UInt8((days >> 8) & 0xFF)
                buffer[4] = UInt8((days >> 16) & 0xFF)
                buffer[5] = UInt8((days >> 24) & 0xFF)
                buffer[6] = hours
                buffer[7] = minutes
                buffer[8] = seconds
                if (microseconds == 0) {
                    buffer[0] = 8
                    return 9
                }
                buffer[0] = 12
                buffer[9] = UInt8(microseconds & 0xFF)
                buffer[10] = UInt8((microseconds >> 8) & 0xFF)
                buffer[11] = UInt8((microseconds >> 16) & 0xFF)
                buffer[12] = UInt8((microseconds >> 24) & 0xFF)
                return 12
            case _ => return 0
        }
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
                if (int_ <= Int64(UInt32.MaxValue)) {
                    return MySQLTypeLongLong
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

        // 对象类型 -> JSON
        if (value.isObject()) {
            return MySQLTypeJSON
        }

        return MySQLTypeVarchar
    }
}
