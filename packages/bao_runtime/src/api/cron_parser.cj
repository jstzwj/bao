// 严格翻译自: src/runtime/api/cron_parser.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// CronExpression - Cron 表达式解析器和下次触发时间计算器
// 对应 Bun: src/runtime/api/cron_parser.zig
// ============================================================================

/// Cron 表达式解析器
/// 解析标准 5 字段 cron 表达式 (分钟 小时 日 月 星期)
/// 为位集表示, 并计算下一个匹配的 UTC 时间
///
/// 支持:
///   - 通配符: *
///   - 列表: 1,3,5
///   - 范围: 1-5
///   - 步长: */15, 1-30/2
///   - 命名天: SUN-SAT (不区分大小写)
///   - 命名月: JAN-DEC (不区分大小写)
///   - 星期天作为 7: 星期字段接受 7 作为 0 的别名
///   - 昵称: @yearly, @annually, @monthly, @weekly, @daily, @midnight, @hourly
public class CronExpression {
    public var minutes: UInt64   // 位 0-59
    public var hours: UInt32     // 位 0-23
    public var days: UInt32      // 位 1-31
    public var months: UInt16    // 位 1-12
    public var weekdays: UInt8   // 位 0-6 (0=星期日)
    public var daysIsWildcard: Bool    // 日字段是否为 *
    public var weekdaysIsWildcard: Bool // 星期字段是否为 *

    // ========================================================================
    // 错误定义
    // ========================================================================

    public enum Error {
        case invalidField
        case invalidStep
        case invalidRange
        case invalidNumber
        case tooManyFields
        case tooFewFields

        public func errorMessage(): String {
            match (this) {
                case .tooFewFields =>
                    "Invalid cron expression: expected 5 space-separated fields (minute hour day month weekday)"
                case .tooManyFields =>
                    "Invalid cron expression: too many fields. Bun.cron uses 5 fields (minute hour day month weekday) — seconds are not supported"
                case .invalidStep =>
                    "Invalid cron expression: step value must be a positive integer"
                case .invalidRange =>
                    "Invalid cron expression: range must be ascending (use 'a,b' or 'a-max,0-b' for wrap-around)"
                case .invalidNumber =>
                    "Invalid cron expression: value out of range for field"
                case .invalidField =>
                    "Invalid cron expression: unrecognized field syntax"
            }
        }
    }

    // ========================================================================
    // 解析
    // ========================================================================

    /// 解析 5 字段 cron 表达式或预定义昵称为 CronExpression
    public static func parse(input: String): CronExpression {
        let expr = input.trim(' ', '\t')

        // 检查预定义昵称
        if (expr.count > 0 && expr[0] == '@') {
            if (let result = parseNickname(expr)) {
                return result
            }
            throw Error.invalidField
        }

        let fields = expr.split(' ', '\t').filter({ s => !s.isEmpty() })
        if (fields.count > 5) { throw Error.tooManyFields }
        if (fields.count != 5) { throw Error.tooFewFields }

        return CronExpression(
            minutes: parseField64(fields[0], 0, 59, NameKind.none),
            hours: parseField32(fields[1], 0, 23, NameKind.none),
            days: parseField32(fields[2], 1, 31, NameKind.none),
            months: parseField16(fields[3], 1, 12, NameKind.month),
            weekdays: parseField8(fields[4], 0, 7, NameKind.weekday),
            daysIsWildcard: fields[2] == "*",
            weekdaysIsWildcard: fields[4] == "*",
        )
    }

    /// 验证 cron 表达式
    public static func validate(expr: String): Bool {
        try {
            _ = parse(expr)
            return true
        } catch {
            return false
        }
    }

    // ========================================================================
    // 格式化
    // ========================================================================

    /// 将表达式格式化为标准化的数字 "M H D Mo W" 字符串
    public func formatNumeric(buf: Array<UInt8>): String {
        formatBitfield64(buf, minutes, 0, 59)
        buf.append(UInt8(' '))
        formatBitfield32(buf, hours, 0, 23)
        buf.append(UInt8(' '))
        formatBitfield32(buf, days, 1, 31)
        buf.append(UInt8(' '))
        formatBitfield16(buf, months, 1, 12)
        buf.append(UInt8(' '))
        formatBitfield8(buf, weekdays, 0, 6)
        return String.fromUtf8(buf.toArray())
    }

    // ========================================================================
    // 下次触发时间
    // ========================================================================

    /// 计算匹配此表达式的下一个 UTC 时间 (毫秒时间戳)
    public func next(globalObject: JsGlobalObject, fromMs: Float64): ?Float64 {
        var dt = globalObject.msToGregorianDateTimeUTC(fromMs)
        let startYear = dt.year
        dt.minute += 1
        dt.second = 0

        while (dt.year - startYear <= 8) {
            // 规范化溢出 + 通过 UTC 往返重新计算星期
            dt = globalObject.msToGregorianDateTimeUTC(
                globalObject.gregorianDateTimeToMSUTC(dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second, 0)
            )

            if (!bitSet16(months, UInt16(dt.month))) {
                dt.month += 1
                dt.day = 1
                dt.hour = 0
                dt.minute = 0
                continue
            }

            // POSIX: 如果 DOM 和 DOW 都受限 (非 `*`), 任一匹配即可
            let dayOk = bitSet32(days, UInt32(dt.day))
            let weekdayOk = bitSet8(weekdays, UInt8(dt.weekday))
            let dayMatch = if (!daysIsWildcard && !weekdaysIsWildcard)
                dayOk || weekdayOk
            else
                dayOk && weekdayOk

            if (!dayMatch) {
                dt.day += 1
                dt.hour = 0
                dt.minute = 0
                continue
            }

            if (!bitSet32(hours, UInt32(dt.hour))) {
                dt.hour += 1
                dt.minute = 0
                continue
            }

            if (!bitSet64(minutes, UInt64(dt.minute))) {
                dt.minute += 1
                continue
            }

            return globalObject.gregorianDateTimeToMSUTC(dt.year, dt.month, dt.day, dt.hour, dt.minute, 0, 0)
        }

        return none
    }

    // ========================================================================
    // 字段解析
    // ========================================================================

    /// 名称种类
    public enum NameKind {
        case none
        case weekday
        case month
    }

    /// 解析单个 cron 字段 (64位位集)
    public static func parseField64(field: String, min: Int, max: Int, kind: NameKind): UInt64 {
        if (field.isEmpty()) { throw Error.invalidField }
        var result: UInt64 = 0
        for (part in field.split(',')) {
            if (part.isEmpty()) { throw Error.invalidField }

            let stepParts = part.split('/', maxSplits: 1)
            let base = stepParts[0]
            let stepStr = stepParts.count > 1 ? stepParts[1] : ""
            if (stepParts.count > 2) { throw Error.invalidStep }

            let step: Int = if (stepStr.count > 0) {
                try Int.parse(stepStr, radix: 10)
            } else {
                1
            }
            if (step == 0) { throw Error.invalidStep }

            var rangeMin: Int = 0
            var rangeMax: Int = 0

            if (base == "*") {
                rangeMin = min
                rangeMax = max
            } else {
                let rangeParts = splitRange(base)
                if (rangeParts != null) {
                    let lo = try parseValue(rangeParts[0], min, max, kind)
                    let hi = try parseValue(rangeParts[1], min, max, kind)
                    if (lo > hi) { throw Error.invalidRange }
                    rangeMin = lo
                    rangeMax = hi
                } else {
                    let lo = try parseValue(base, min, max, kind)
                    rangeMin = lo
                    rangeMax = stepStr.count > 0 ? max : lo
                }
            }

            // 设置位
            var i = rangeMin
            while (i <= rangeMax) {
                result |= UInt64(1) << UInt64(i)
                if (UInt8(i) + UInt8(step) > UInt8(rangeMax)) { break }
                i += step
            }
        }

        // 星期: 将位 7 (星期日别名) 折叠到位 0
        if (kind == NameKind.weekday) {
            result = (result | (result >> 7)) & 0x7F
        }

        return result
    }

    /// 解析单个 cron 字段 (32位位集)
    public static func parseField32(field: String, min: Int, max: Int, kind: NameKind): UInt32 {
        return UInt32(parseField64(field, min, max, kind) & 0xFFFFFFFF)
    }

    /// 解析单个 cron 字段 (16位位集)
    public static func parseField16(field: String, min: Int, max: Int, kind: NameKind): UInt16 {
        return UInt16(parseField64(field, min, max, kind) & 0xFFFF)
    }

    /// 解析单个 cron 字段 (8位位集)
    public static func parseField8(field: String, min: Int, max: Int, kind: NameKind): UInt8 {
        return UInt8(parseField64(field, min, max, kind) & 0xFF)
    }

    /// 在 '-' 上分割范围表达式
    public static func splitRange(base: String): ?(String, String) {
        let idx = base.indexOf('-')
        if (idx == null || idx == 0 || idx == base.count - 1) { return none }
        let rest = base.substring(idx + 1)
        if (rest.indexOf('-') != null) { return none }
        return (base.substring(0, idx), rest)
    }

    /// 解析单个值 (数字或名称), 验证范围
    public static func parseValue(str: String, min: Int, max: Int, kind: NameKind): Int {
        // 先尝试命名值查找
        match (kind) {
            case .weekday =>
                if (let v = weekdayMap.getASCIICaseInsensitive(str)) { return v }
            case .month =>
                if (let v = monthMap.getASCIICaseInsensitive(str)) { return v }
            case .none => ()
        }

        guard let val = Int.parse(str, radix: 10) else {
            throw Error.invalidNumber
        }
        if (val < min || val > max) { throw Error.invalidNumber }
        return val
    }

    // ========================================================================
    // 昵称解析
    // ========================================================================

    /// 解析预定义昵称
    public static func parseNickname(expr: String): ?CronExpression {
        if (expr.eqlCaseInsensitiveASCII("@yearly") || expr.eqlCaseInsensitiveASCII("@annually")) {
            return CronExpression(minutes: 1, hours: 1, days: 1 << 1, months: 1 << 1, weekdays: allWeekdays, daysIsWildcard: false, weekdaysIsWildcard: true)
        }
        if (expr.eqlCaseInsensitiveASCII("@monthly")) {
            return CronExpression(minutes: 1, hours: 1, days: 1 << 1, months: allMonths, weekdays: allWeekdays, daysIsWildcard: false, weekdaysIsWildcard: true)
        }
        if (expr.eqlCaseInsensitiveASCII("@weekly")) {
            return CronExpression(minutes: 1, hours: 1, days: allDays, months: allMonths, weekdays: 1, daysIsWildcard: true, weekdaysIsWildcard: false)
        }
        if (expr.eqlCaseInsensitiveASCII("@daily") || expr.eqlCaseInsensitiveASCII("@midnight")) {
            return CronExpression(minutes: 1, hours: 1, days: allDays, months: allMonths, weekdays: allWeekdays, daysIsWildcard: true, weekdaysIsWildcard: true)
        }
        if (expr.eqlCaseInsensitiveASCII("@hourly")) {
            return CronExpression(minutes: 1, hours: allHours, days: allDays, months: allMonths, weekdays: allWeekdays, daysIsWildcard: true, weekdaysIsWildcard: true)
        }
        return none
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 检查位集中特定位是否设置
    public static func bitSet64(set: UInt64, pos: UInt64): Bool {
        return (set >> pos) & 1 != 0
    }

    public static func bitSet32(set: UInt32, pos: UInt32): Bool {
        return (set >> pos) & 1 != 0
    }

    public static func bitSet16(set: UInt16, pos: UInt16): Bool {
        return (set >> pos) & 1 != 0
    }

    public static func bitSet8(set: UInt8, pos: UInt8): Bool {
        return (set >> pos) & 1 != 0
    }

    /// 格式化位字段为 cron 字段字符串
    public static func formatBitfield64(buf: Array<UInt8>, bits: UInt64, min: UInt8, max: UInt8): Unit {
        var popCount: Int = 0
        var temp = bits
        while (temp != 0) {
            popCount += Int(temp & 1)
            temp >>= 1
        }

        if (popCount == Int(max) - Int(min) + 1) {
            buf.append(UInt8('*'))
            return
        }

        var first = true
        for (i in Int(min)..Int(max + 1)) {
            if ((bits >> UInt64(i)) & 1 != 0) {
                if (!first) { buf.append(UInt8(',')) }
                buf.appendRange(String.fromUtf8(i.toString()).toUtf8())
                first = false
            }
        }
    }

    public static func formatBitfield32(buf: Array<UInt8>, bits: UInt32, min: UInt8, max: UInt8): Unit {
        formatBitfield64(buf, UInt64(bits), min, max)
    }

    public static func formatBitfield16(buf: Array<UInt8>, bits: UInt16, min: UInt8, max: UInt8): Unit {
        formatBitfield64(buf, UInt64(bits), min, max)
    }

    public static func formatBitfield8(buf: Array<UInt8>, bits: UInt8, min: UInt8, max: UInt8): Unit {
        formatBitfield64(buf, UInt64(bits), min, max)
    }

    // ========================================================================
    // 常量
    // ========================================================================

    public static let allHours: UInt32 = (1 << 24) - 1
    public static let allDays: UInt32 = UInt32((UInt64(1) << 32) - 1) & ~UInt32(1)
    public static let allMonths: UInt16 = UInt16((UInt32(1) << 13) - 1) & ~UInt16(1)
    public static let allWeekdays: UInt8 = UInt8((1 << 7) - 1)

    // ========================================================================
    // 名称映射
    // ========================================================================

    /// 星期名称映射
    public static let weekdayMap: Map<String, Int> = {
        let m = HashMap<String, Int>()
        m["sun"] = 0
        m["mon"] = 1
        m["tue"] = 2
        m["wed"] = 3
        m["thu"] = 4
        m["fri"] = 5
        m["sat"] = 6
        m["sunday"] = 0
        m["monday"] = 1
        m["tuesday"] = 2
        m["wednesday"] = 3
        m["thursday"] = 4
        m["friday"] = 5
        m["saturday"] = 6
        return m
    }()

    /// 月份名称映射
    public static let monthMap: Map<String, Int> = {
        let m = HashMap<String, Int>()
        m["jan"] = 1
        m["feb"] = 2
        m["mar"] = 3
        m["apr"] = 4
        m["may"] = 5
        m["jun"] = 6
        m["jul"] = 7
        m["aug"] = 8
        m["sep"] = 9
        m["oct"] = 10
        m["nov"] = 11
        m["dec"] = 12
        m["january"] = 1
        m["february"] = 2
        m["march"] = 3
        m["april"] = 4
        m["june"] = 6
        m["july"] = 7
        m["august"] = 8
        m["september"] = 9
        m["october"] = 10
        m["november"] = 11
        m["december"] = 12
        return m
    }()
}
