// MySQL JS 值转换绑定
// 严格翻译自: src/sql_jsc/mysql/MySQLValue.zig
//
// 负责 MySQL 参数值与 JS 值的双向转换:
// - fieldTypeFromJS: JS 值 → MySQL 字段类型推断
// - Value.fromJS: JS 值 → MySQL 参数值 (用于预编译语句绑定)
// - DateTime/Time 的 JS ↔ MySQL 转换
package bao_runtime.sql.mysql

import bao_core.*
import bao_runtime.sql.shared.*

/// MySQL 字段类型推断
/// 对应 Bun: fieldTypeFromJS
/// 从 JS 值推断合适的 MySQL 字段类型
public class FieldTypeFromJS {
    /// 从 JS 值推断字段类型
    /// 对应 Bun: fieldTypeFromJS.call
    public static func call(globalObject: JSValueRef, value: JSValueRef, unsigned: Box<Bool>): FieldType {
        // null/undefined
        if (value.isEmptyOrUndefinedOrNull()) {
            return FieldType.MYSQL_TYPE_NULL
        }

        // JS 字符串
        if (value.isString()) {
            return FieldType.MYSQL_TYPE_VARCHAR
        }

        // JS Date
        if (value.isDate()) {
            return FieldType.MYSQL_TYPE_DATETIME
        }

        // ArrayBuffer / TypedArray
        if (value.isArrayBuffer()) {
            return FieldType.MYSQL_TYPE_BLOB
        }

        // BigInt
        if (value.isBigInt()) {
            return FieldType.MYSQL_TYPE_LONGLONG
        }

        // JS 布尔值
        if (value.isBoolean()) {
            return FieldType.MYSQL_TYPE_TINY
        }

        // JS 整数
        if (value.isAnyInt()) {
            let intVal = value.toInt64()
            if (intVal >= 0) {
                if (intVal <= Int64(Int32.MaxValue)) {
                    return FieldType.MYSQL_TYPE_LONG
                }
                if (intVal <= Int64(UInt32.MaxValue)) {
                    unsigned.value = true
                    return FieldType.MYSQL_TYPE_LONG
                }
                return FieldType.MYSQL_TYPE_LONGLONG
            }
            if (intVal >= Int64(Int32.MinValue)) {
                return FieldType.MYSQL_TYPE_LONG
            }
            return FieldType.MYSQL_TYPE_LONGLONG
        }

        // JS number (浮点)
        if (value.isNumber()) {
            return FieldType.MYSQL_TYPE_DOUBLE
        }

        // JSON 对象
        if (value.isObject()) {
            return FieldType.MYSQL_TYPE_JSON
        }

        return FieldType.MYSQL_TYPE_VARCHAR
    }
}

/// MySQL 参数值 JS 转换
/// 对应 Bun: Value.fromJS
/// 将 JS 值转为 MySQL 参数值
public class MySQLValueFromJS {
    /// 从 JS 值创建参数值
    /// 对应 Bun: Value.fromJS
    public static func fromJS(
        value: JSValueRef,
        globalObject: JSValueRef,
        fieldType: FieldType,
        unsigned: Bool
    ): MySQLValueData {
        if (value.isEmptyOrUndefinedOrNull()) {
            return MySQLValueData.null
        }

        match (fieldType) {
            case MYSQL_TYPE_TINY =>
                return MySQLValueData.bool(value.toBoolean())
            case MYSQL_TYPE_SHORT =>
                if (unsigned) {
                    return MySQLValueData.ushort(value.toUInt16())
                }
                return MySQLValueData.short(value.toInt16())
            case MYSQL_TYPE_LONG =>
                if (unsigned) {
                    return MySQLValueData.uint(value.toUInt32())
                }
                return MySQLValueData.int(value.toInt32())
            case MYSQL_TYPE_LONGLONG =>
                if (unsigned) {
                    return MySQLValueData.ulong(value.toUInt64())
                }
                return MySQLValueData.long(value.toInt64())
            case MYSQL_TYPE_FLOAT =>
                return MySQLValueData.float(value.toFloat32())
            case MYSQL_TYPE_DOUBLE =>
                return MySQLValueData.double(value.toFloat64())
            case MYSQL_TYPE_TIME =>
                return MySQLValueData.time(MySQLTimeFromJS.fromJS(value, globalObject))
            case MYSQL_TYPE_DATE =>
                return MySQLValueData.date(MySQLDateTimeFromJS.fromJS(value, globalObject))
            case MYSQL_TYPE_DATETIME =>
                return MySQLValueData.date(MySQLDateTimeFromJS.fromJS(value, globalObject))
            case MYSQL_TYPE_TIMESTAMP =>
                return MySQLValueData.date(MySQLDateTimeFromJS.fromJS(value, globalObject))
            case MYSQL_TYPE_TINY_BLOB =>
                return MySQLValueData.bytes(value.toBytes())
            case MYSQL_TYPE_MEDIUM_BLOB =>
                return MySQLValueData.bytes(value.toBytes())
            case MYSQL_TYPE_LONG_BLOB =>
                return MySQLValueData.bytes(value.toBytes())
            case MYSQL_TYPE_BLOB =>
                return MySQLValueData.bytes(value.toBytes())
            case MYSQL_TYPE_JSON =>
                return MySQLValueData.string(value.toJSONString())
            case _ =>
                // 默认: 字符串
                return MySQLValueData.string(value.toString())
        }
    }
}

/// MySQL DateTime JS 转换
/// 对应 Bun: Value.DateTime 的 JS 转换方法
public class MySQLDateTimeFromJS {
    /// 从 JS 值创建 DateTime
    /// 对应 Bun: DateTime.fromJS
    public static func fromJS(value: JSValueRef, globalObject: JSValueRef): MySQLDateTime {
        if (value.isDate()) {
            let totalMs = value.getUnixTimestamp()
            let ts = Int64(totalMs / 1000.0)
            let ms = UInt32((totalMs - Float64(ts) * 1000.0))
            return MySQLDateTime.fromUnixTimestamp(ts, ms * 1000)
        }

        if (value.isNumber()) {
            let totalMs = value.asNumber()
            let ts = Int64(totalMs / 1000.0)
            let ms = UInt32((totalMs - Float64(ts) * 1000.0))
            return MySQLDateTime.fromUnixTimestamp(ts, ms * 1000)
        }

        return MySQLDateTime()
    }

    /// DateTime 转 JS
    /// 对应 Bun: DateTime.toJS
    public static func toJS(dt: MySQLDateTime, globalObject: JSValueRef): JSValueRef {
        let ms = toJSTimestamp(dt, globalObject)
        return JSValueRef.fromDateNumber(ms)
    }

    /// DateTime 转 JS 时间戳
    /// 对应 Bun: DateTime.toJSTimestamp
    public static func toJSTimestamp(dt: MySQLDateTime, globalObject: JSValueRef): Float64 {
        // 简化实现: 将日期转为 UTC 毫秒时间戳
        var ms: Float64 = 0.0

        // 年 → 天
        var days: Int64 = 0
        var y: UInt16 = 1970
        while (y < dt.year) {
            days += 365 + (if (isLeapYear(y)) 1 else 0)
            y += 1
        }
        var m: UInt8 = 1
        while (m < dt.month) {
            days += Int64(daysInMonth(y, m))
            m += 1
        }
        days += Int64(dt.day) - 1

        ms = Float64(days) * 86400000.0
        ms += Float64(dt.hour) * 3600000.0
        ms += Float64(dt.minute) * 60000.0
        ms += Float64(dt.second) * 1000.0
        ms += Float64(dt.microsecond / 1000)

        return ms
    }
}

/// MySQL Time JS 转换
/// 对应 Bun: Value.Time 的 JS 转换方法
public class MySQLTimeFromJS {
    /// 从 JS 值创建 Time
    /// 对应 Bun: Time.fromJS
    public static func fromJS(value: JSValueRef, globalObject: JSValueRef): MySQLTime {
        if (value.isDate()) {
            let totalMs = value.getUnixTimestamp()
            let ts = Int64(totalMs / 1000.0)
            let ms = UInt32((totalMs - Float64(ts) * 1000.0))
            return MySQLTime.fromUnixTimestamp(ts, ms * 1000)
        }

        if (value.isNumber()) {
            let totalMs = value.asNumber()
            let ts = Int64(totalMs / 1000.0)
            let ms = UInt32((totalMs - Float64(ts) * 1000.0))
            return MySQLTime.fromUnixTimestamp(ts, ms * 1000)
        }

        return MySQLTime()
    }

    /// Time 转 JS
    /// 对应 Bun: Time.toJS
    public static func toJS(time: MySQLTime): JSValueRef {
        return JSValueRef.jsDoubleNumber(toJSTimestamp(time))
    }

    /// Time 转 JS 时间戳
    /// 对应 Bun: Time.toJSTimestamp
    public static func toJSTimestamp(time: MySQLTime): Float64 {
        var totalMs: Int64 = 0
        totalMs += Int64(time.days) * 86400000
        totalMs += Int64(time.hours) * 3600000
        totalMs += Int64(time.minutes) * 60000
        totalMs += Int64(time.seconds) * 1000
        totalMs += Int64(time.microseconds / 1000)

        if (time.negative) {
            totalMs = -totalMs
        }

        return Float64(totalMs)
    }
}

/// Box<T> 用于输出参数
public class Box<T> {
    public var value: T

    public init(value: T) {
        this.value = value
    }
}

// ============================================================================
// JSValueRef 扩展方法
// ============================================================================

/// JS 值类型判断扩展
public func isLeapYear(year: UInt16): Bool {
    return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

public func daysInMonth(year: UInt16, month: UInt8): UInt8 {
    let days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    if (month == 2 && isLeapYear(year)) {
        return 29
    }
    return days[Int64(month) - 1]
}
