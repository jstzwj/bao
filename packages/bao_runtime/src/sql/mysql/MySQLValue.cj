// MySQL 值类型
// 严格翻译自: src/sql_jsc/mysql/MySQLValue.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 值类型
/// 对应 Bun: MySQLValue.Value (union enum)
/// 表示预编译语句中的参数值
public enum MySQLValueData {
    | null
    | bool(Bool)
    | short(Int16)
    | ushort(UInt16)
    | int(Int32)
    | uint(UInt32)
    | long(Int64)
    | ulong(UInt64)
    | float(Float32)
    | double(Float64)
    | string(Array<UInt8>)
    | bytes(Array<UInt8>)
    | date(MySQLDateTime)
    | time(MySQLTime)

    /// 是否为 null
    public func isNull(): Bool {
        match (this) {
            case null => true
            case _ => false
        }
    }

    /// 将值转为 SQLData (用于二进制协议编码)
    /// 对应 Bun: Value.toData
    public func toData(fieldType: FieldType): Array<UInt8> {
        match (this) {
            case null => Array<UInt8>()
            case bool(b) =>
                let arr = Array<UInt8>(1, item: 0)
                arr[0] = if (b) 1 else 0
                return arr
            case short(s) =>
                let arr = Array<UInt8>(2, item: 0)
                arr[0] = UInt8(s & 0xff)
                arr[1] = UInt8((s >> 8) & 0xff)
                return arr
            case ushort(s) =>
                let arr = Array<UInt8>(2, item: 0)
                arr[0] = UInt8(s & 0xff)
                arr[1] = UInt8((s >> 8) & 0xff)
                return arr
            case int(i) =>
                let arr = Array<UInt8>(4, item: 0)
                arr[0] = UInt8(i & 0xff)
                arr[1] = UInt8((i >> 8) & 0xff)
                arr[2] = UInt8((i >> 16) & 0xff)
                arr[3] = UInt8((i >> 24) & 0xff)
                return arr
            case uint(i) =>
                let arr = Array<UInt8>(4, item: 0)
                arr[0] = UInt8(i & 0xff)
                arr[1] = UInt8((i >> 8) & 0xff)
                arr[2] = UInt8((i >> 16) & 0xff)
                arr[3] = UInt8((i >> 24) & 0xff)
                return arr
            case long(l) =>
                let arr = Array<UInt8>(8, item: 0)
                arr[0] = UInt8(l & 0xff)
                arr[1] = UInt8((l >> 8) & 0xff)
                arr[2] = UInt8((l >> 16) & 0xff)
                arr[3] = UInt8((l >> 24) & 0xff)
                arr[4] = UInt8((l >> 32) & 0xff)
                arr[5] = UInt8((l >> 40) & 0xff)
                arr[6] = UInt8((l >> 48) & 0xff)
                arr[7] = UInt8((l >> 56) & 0xff)
                return arr
            case ulong(l) =>
                let arr = Array<UInt8>(8, item: 0)
                arr[0] = UInt8(l & 0xff)
                arr[1] = UInt8((l >> 8) & 0xff)
                arr[2] = UInt8((l >> 16) & 0xff)
                arr[3] = UInt8((l >> 24) & 0xff)
                arr[4] = UInt8((l >> 32) & 0xff)
                arr[5] = UInt8((l >> 40) & 0xff)
                arr[6] = UInt8((l >> 48) & 0xff)
                arr[7] = UInt8((l >> 56) & 0xff)
                return arr
            case float(f) =>
                let bits = Float32.toBits(f)
                let arr = Array<UInt8>(4, item: 0)
                arr[0] = UInt8(bits & 0xff)
                arr[1] = UInt8((bits >> 8) & 0xff)
                arr[2] = UInt8((bits >> 16) & 0xff)
                arr[3] = UInt8((bits >> 24) & 0xff)
                return arr
            case double(d) =>
                let bits = Float64.toBits(d)
                let arr = Array<UInt8>(8, item: 0)
                arr[0] = UInt8(bits & 0xff)
                arr[1] = UInt8((bits >> 8) & 0xff)
                arr[2] = UInt8((bits >> 16) & 0xff)
                arr[3] = UInt8((bits >> 24) & 0xff)
                arr[4] = UInt8((bits >> 32) & 0xff)
                arr[5] = UInt8((bits >> 40) & 0xff)
                arr[6] = UInt8((bits >> 48) & 0xff)
                arr[7] = UInt8((bits >> 56) & 0xff)
                return arr
            case string(s) => s
            case bytes(b) => b
            case date(d) => d.toBinary(fieldType)
            case time(t) => t.toBinary(fieldType)
        }
    }
}

/// MySQL 日期时间
/// 对应 Bun: Value.DateTime
public class MySQLDateTime {
    public var year: UInt16
    public var month: UInt8
    public var day: UInt8
    public var hour: UInt8
    public var minute: UInt8
    public var second: UInt8
    public var microsecond: UInt32

    public init() {
        year = 0
        month = 0
        day = 0
        hour = 0
        minute = 0
        second = 0
        microsecond = 0
    }

    /// 从二进制数据解析
    /// 对应 Bun: DateTime.fromBinary
    public static func fromBinary(val: Array<UInt8>): MySQLDateTime {
        let dt = MySQLDateTime()
        if (val.size == 4) {
            dt.year = UInt16(val[0]) | (UInt16(val[1]) << 8)
            dt.month = val[2]
            dt.day = val[3]
        } else if (val.size == 7) {
            dt.year = UInt16(val[0]) | (UInt16(val[1]) << 8)
            dt.month = val[2]
            dt.day = val[3]
            dt.hour = val[4]
            dt.minute = val[5]
            dt.second = val[6]
        } else if (val.size == 11) {
            dt.year = UInt16(val[0]) | (UInt16(val[1]) << 8)
            dt.month = val[2]
            dt.day = val[3]
            dt.hour = val[4]
            dt.minute = val[5]
            dt.second = val[6]
            dt.microsecond = UInt32(val[7]) |
                (UInt32(val[8]) << 8) |
                (UInt32(val[9]) << 16) |
                (UInt32(val[10]) << 24)
        }
        return dt
    }

    /// 转为二进制
    /// 对应 Bun: DateTime.toBinary
    public func toBinary(fieldType: FieldType): Array<UInt8> {
        match (fieldType) {
            case MYSQL_TYPE_YEAR =>
                let arr = Array<UInt8>(3, item: 0)
                arr[0] = 2  // length
                arr[1] = UInt8(year & 0xff)
                arr[2] = UInt8((year >> 8) & 0xff)
                return arr
            case MYSQL_TYPE_DATE =>
                let arr = Array<UInt8>(5, item: 0)
                arr[0] = 4  // length
                arr[1] = UInt8(year & 0xff)
                arr[2] = UInt8((year >> 8) & 0xff)
                arr[3] = month
                arr[4] = day
                return arr
            case MYSQL_TYPE_DATETIME =>
                if (microsecond == 0) {
                    let arr = Array<UInt8>(8, item: 0)
                    arr[0] = 7  // length
                    arr[1] = UInt8(year & 0xff)
                    arr[2] = UInt8((year >> 8) & 0xff)
                    arr[3] = month
                    arr[4] = day
                    arr[5] = hour
                    arr[6] = minute
                    arr[7] = second
                    return arr
                } else {
                    let arr = Array<UInt8>(12, item: 0)
                    arr[0] = 11  // length
                    arr[1] = UInt8(year & 0xff)
                    arr[2] = UInt8((year >> 8) & 0xff)
                    arr[3] = month
                    arr[4] = day
                    arr[5] = hour
                    arr[6] = minute
                    arr[7] = second
                    arr[8] = UInt8(microsecond & 0xff)
                    arr[9] = UInt8((microsecond >> 8) & 0xff)
                    arr[10] = UInt8((microsecond >> 16) & 0xff)
                    arr[11] = UInt8((microsecond >> 24) & 0xff)
                    return arr
                }
            case _ => Array<UInt8>()
        }
    }

    /// 从 Unix 时间戳创建
    /// 对应 Bun: DateTime.fromUnixTimestamp
    public static func fromUnixTimestamp(timestamp: Int64, microseconds: UInt32): MySQLDateTime {
        var ts = timestamp
        let days = ts / 86400
        ts = ts % 86400

        let hour = ts / 3600
        ts = ts % 3600

        let minute = ts / 60
        let second = ts % 60

        let date = gregorianDate(Int32(days))
        let dt = MySQLDateTime()
        dt.year = date.year
        dt.month = date.month
        dt.day = date.day
        dt.hour = UInt8(hour)
        dt.minute = UInt8(minute)
        dt.second = UInt8(second)
        dt.microsecond = microseconds
        return dt
    }
}

/// MySQL 时间类型
/// 对应 Bun: Value.Time
public class MySQLTime {
    public var negative: Bool
    public var days: UInt32
    public var hours: UInt8
    public var minutes: UInt8
    public var seconds: UInt8
    public var microseconds: UInt32

    public init() {
        negative = false
        days = 0
        hours = 0
        minutes = 0
        seconds = 0
        microseconds = 0
    }

    /// 从二进制数据解析
    /// 对应 Bun: Time.fromBinary
    public static func fromBinary(val: Array<UInt8>): MySQLTime {
        let t = MySQLTime()
        if (val.size == 0) {
            return t
        }
        if (val.size >= 8) {
            t.negative = val[0] != 0
            t.days = UInt32(val[1]) |
                (UInt32(val[2]) << 8) |
                (UInt32(val[3]) << 16) |
                (UInt32(val[4]) << 24)
            t.hours = val[5]
            t.minutes = val[6]
            t.seconds = val[7]
        }
        if (val.size > 8) {
            t.microseconds = UInt32(val[8]) |
                (UInt32(val[9]) << 8) |
                (UInt32(val[10]) << 16) |
                (UInt32(val[11]) << 24)
        }
        return t
    }

    /// 转为二进制
    /// 对应 Bun: Time.toBinary
    public func toBinary(fieldType: FieldType): Array<UInt8> {
        match (fieldType) {
            case MYSQL_TYPE_TIME =>
                if (microseconds == 0) {
                    let arr = Array<UInt8>(9, item: 0)
                    arr[0] = 8  // length
                    arr[1] = if (negative) 1 else 0
                    arr[2] = UInt8(days & 0xff)
                    arr[3] = UInt8((days >> 8) & 0xff)
                    arr[4] = UInt8((days >> 16) & 0xff)
                    arr[5] = UInt8((days >> 24) & 0xff)
                    arr[6] = hours
                    arr[7] = minutes
                    arr[8] = seconds
                    return arr
                } else {
                    let arr = Array<UInt8>(12, item: 0)
                    arr[0] = 12  // length
                    arr[1] = if (negative) 1 else 0
                    arr[2] = UInt8(days & 0xff)
                    arr[3] = UInt8((days >> 8) & 0xff)
                    arr[4] = UInt8((days >> 16) & 0xff)
                    arr[5] = UInt8((days >> 24) & 0xff)
                    arr[6] = hours
                    arr[7] = minutes
                    arr[8] = seconds
                    arr[9] = UInt8(microseconds & 0xff)
                    arr[10] = UInt8((microseconds >> 8) & 0xff)
                    arr[11] = UInt8((microseconds >> 16) & 0xff)
                    return arr
                }
            case _ => Array<UInt8>()
        }
    }

    /// 从 Unix 时间戳创建
    /// 对应 Bun: Time.fromUnixTimestamp
    public static func fromUnixTimestamp(timestamp: Int64, microseconds: UInt32): MySQLTime {
        let days = UInt32(timestamp / 86400)
        let hours = UInt8((timestamp % 86400) / 3600)
        let minutes = UInt8((timestamp % 3600) / 60)
        let seconds = UInt8(timestamp % 60)
        let t = MySQLTime()
        t.negative = timestamp < 0
        t.days = days
        t.hours = hours
        t.minutes = minutes
        t.seconds = seconds
        t.microseconds = microseconds
        return t
    }
}

// ============================================================================
// 辅助函数: 公历日期计算
// 对应 Bun: MySQLValue.zig 中的 isLeapYear, daysInMonth, gregorianDate
// ============================================================================

/// 判断闰年
func isLeapYear(year: UInt16): Bool {
    return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

/// 获取月份天数
func daysInMonth(year: UInt16, month: UInt8): UInt8 {
    let days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    if (month == 2 && isLeapYear(year)) {
        return 29
    }
    return days[Int64(month) - 1]
}

/// 公历日期结果
public class GregorianDate {
    public var year: UInt16
    public var month: UInt8
    public var day: UInt8

    public init(year: UInt16, month: UInt8, day: UInt8) {
        this.year = year
        this.month = month
        this.day = day
    }
}

/// 从距 1970-01-01 的天数计算公历日期
/// 对应 Bun: gregorianDate
func gregorianDate(days: Int32): GregorianDate {
    var d = days
    var y: UInt16 = 1970

    while (d >= 365 + (if (isLeapYear(y)) 1 else 0)) {
        d -= 365 + (if (isLeapYear(y)) 1 else 0)
        y += 1
    }

    var m: UInt8 = 1
    while (d >= Int32(daysInMonth(y, m))) {
        d -= Int32(daysInMonth(y, m))
        m += 1
    }

    return GregorianDate(year: y, month: m, day: UInt8(d + 1))
}
