// 严格翻译自: src/runtime/api/cron_parser.zig
//   CronExpression — cron 表达式解析器和下次匹配计算器
//   支持标准 5 字段 cron 表达式 (minute hour day month weekday)
//   解析为位集表示，计算下一个匹配的 UTC 时间
//
//   支持:
//     - 通配符: *
//     - 列表: 1,3,5
//     - 范围: 1-5
//     - 步进: */15, 1-30/2
//     - 命名日期: SUN-SAT, Sunday-Saturday (大小写不敏感)
//     - 命名月份: JAN-DEC, January-December (大小写不敏感)
//     - Sunday as 7: weekday 字段接受 7 作为 0 的别名
//     - 昵称: @yearly, @annually, @monthly, @weekly, @daily, @midnight, @hourly
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}
import bao_core.*

// ============================================================================
// 常量 — 全位集掩码
// 翻译自: cron_parser.zig all_hours / all_days / all_months / all_weekdays
// ============================================================================

/// 所有小时位集 (bits 0-23): (1 << 24) - 1
public let ALL_HOURS: UInt32 = 0x00FFFFFF  // (1 << 24) - 1 = 16777215

/// 所有日期位集 (bits 1-31): 全部 bits 为 1 但 bit 0 清零
public let ALL_DAYS: UInt32 = 0xFFFFFFFE   // ~1 = 4294967294

/// 所有月份位集 (bits 1-12): bits 1-12 置位
public let ALL_MONTHS: UInt16 = 0x1FFE     // ((1 << 13) - 1) & ~1

/// 所有星期位集 (bits 0-6): (1 << 7) - 1
public let ALL_WEEKDAYS: UInt8 = 0x7F      // 127

// ============================================================================
// CronExpressionError — cron 表达式解析错误
// 翻译自: cron_parser.zig CronExpression.Error
// ============================================================================

/// cron 表达式解析错误类型
public enum CronExpressionError {
    | invalidField
    | invalidStep
    | invalidRange
    | invalidNumber
    | tooManyFields
    | tooFewFields

    /// 获取错误信息
    /// 翻译自: CronExpression.errorMessage(e) []const u8
    public func errorMessage(): String {
        match (this) {
            case tooFewFields =>
                "Invalid cron expression: expected 5 space-separated fields (minute hour day month weekday)"
            case tooManyFields =>
                "Invalid cron expression: too many fields. Bun.cron uses 5 fields (minute hour day month weekday) -- seconds are not supported"
            case invalidStep =>
                "Invalid cron expression: step value must be a positive integer"
            case invalidRange =>
                "Invalid cron expression: range must be ascending (use 'a,b' or 'a-max,0-b' for wrap-around)"
            case invalidNumber =>
                "Invalid cron expression: value out of range for field"
            case invalidField =>
                "Invalid cron expression: unrecognized field syntax"
        }
    }
}

// ============================================================================
// CronExpression — cron 表达式解析结果
// 翻译自: cron_parser.zig pub const CronExpression = struct { ... }
// ============================================================================

/// CronExpression — cron 表达式的位集表示
/// minutes: bits 0-59, hours: bits 0-23, days: bits 1-31
/// months: bits 1-12, weekdays: bits 0-6 (0=Sunday)
public class CronExpression {
    /// 分钟位集 (bits 0-59)
    public var minutes: UInt64 = UInt64(0)
    /// 小时位集 (bits 0-23)
    public var hours: UInt32 = UInt32(0)
    /// 日期位集 (bits 1-31)
    public var days: UInt32 = UInt32(0)
    /// 月份位集 (bits 1-12)
    public var months: UInt16 = UInt16(0)
    /// 星期位集 (bits 0-6, 0=Sunday)
    public var weekdays: UInt8 = UInt8(0)
    /// true 如果 day-of-month 字段是 *
    public var daysIsWildcard: Bool = true
    /// true 如果 weekday 字段是 *
    public var weekdaysIsWildcard: Bool = true

    public init() {}

    public init(
        minutes!: UInt64, hours!: UInt32, days!: UInt32,
        months!: UInt16, weekdays!: UInt8,
        daysIsWildcard!: Bool, weekdaysIsWildcard!: Bool
    ) {
        this.minutes = minutes
        this.hours = hours
        this.days = days
        this.months = months
        this.weekdays = weekdays
        this.daysIsWildcard = daysIsWildcard
        this.weekdaysIsWildcard = weekdaysIsWildcard
    }

    /// 解析 5 字段 cron 表达式或预定义昵称为 CronExpression
    /// 翻译自: CronExpression.parse(input) Error!CronExpression
    public static func parse(input!: String): ?CronExpression {
        let expr = input.trimAscii()

        // 检查预定义昵称
        if (expr.size > 0 && expr.toArray()[0] == UInt8(64)) {  // '@' = 64
            return parseNickname(expr: expr)
        }

        // 按空格分割为 5 个字段
        let fields = expr.split(" ")
        // 过滤空字段
        var filteredFields = Array<String>()
        for (f in fields) {
            let trimmed = f.trimAscii()
            if (trimmed.size > 0) {
                filteredFields = filteredFields.concat([trimmed])
            }
        }

        if (filteredFields.size < 5) {
            return None
        }
        if (filteredFields.size > 5) {
            return None
        }

        // 解析每个字段
        let minutesResult = parseField64(field: filteredFields[0], min: Int64(0), max: Int64(6), kind: NameKind.none)
        if (minutesResult.isNone()) { return None }
        let hoursResult = parseField32(field: filteredFields[1], min: Int64(0), max: Int64(2), kind: NameKind.none)
        if (hoursResult.isNone()) { return None }
        let daysResult = parseField32(field: filteredFields[2], min: Int64(1), max: Int64(3), kind: NameKind.none)
        if (daysResult.isNone()) { return None }
        let monthsResult = parseField16(field: filteredFields[3], min: Int64(1), max: Int64(1), kind: NameKind.month)
        if (monthsResult.isNone()) { return None }
        let weekdaysResult = parseField8(field: filteredFields[4], min: Int64(0), max: Int64(7), kind: NameKind.weekday)
        if (weekdaysResult.isNone()) { return None }

        return CronExpression(
            minutes: minutesResult.getOrThrow(),
            hours: hoursResult.getOrThrow(),
            days: daysResult.getOrThrow(),
            months: monthsResult.getOrThrow(),
            weekdays: weekdaysResult.getOrThrow(),
            daysIsWildcard: filteredFields[2] == "*",
            weekdaysIsWildcard: filteredFields[4] == "*"
        )
    }

    /// 验证 cron 表达式是否有效
    /// 翻译自: CronExpression.validate(expr) bool
    public static func validate(expr!: String): Bool {
        parse(input: expr).isSome()
    }

    /// 将表达式格式化为标准化的数字 "M H D Mo W" 字符串
    /// 翻译自: CronExpression.formatNumeric(buf) []const u8
    public func formatNumeric(): String {
        var parts = Array<String>()
        parts = parts.concat([formatBitfield64(bits: minutes, min: Int64(0), max: Int64(5))])
        parts = parts.concat([formatBitfield32(bits: hours, min: Int64(0), max: Int64(2))])
        parts = parts.concat([formatBitfield32(bits: days, min: Int64(1), max: Int64(3))])
        parts = parts.concat([formatBitfield16(bits: months, min: Int64(1), max: Int64(1))])
        parts = parts.concat([formatBitfield8(bits: weekdays, min: Int64(0), max: Int64(6))])
        var result = ""
        for (i in 0..parts.size) {
            if (i > 0) { result = result + " " }
            result = result + parts[Int64(i)]
        }
        return result
    }

    /// 计算下一个匹配的 UTC 时间 (ms since epoch)，严格在 fromMs 之后
    /// 翻译自: CronExpression.next(globalObject, from_ms) ?f64
    /// 返回 None 如果在 8 年内没有匹配
    public func next(globalObject!: JsGlobalObject, fromMs!: Float64): ?Float64 {
        // 简化实现: 使用 Date 计算下一个匹配时间
        // 完整实现需要 JSC 的 GregorianDateTime API
        var dt = msToDateTime(ms: fromMs)
        let startYear = dt.year
        dt.minute = dt.minute + 1
        dt.second = 0

        var yearDelta: Int64 = 0
        while (yearDelta <= 8) {
            // 规范化溢出
            normalizeDateTime(dt: dt)
            yearDelta = dt.year - startYear
            if (yearDelta > 8) { break }

            // 检查月份
            if (!bitSet16(set: months, pos: Int64(dt.month))) {
                dt.month = dt.month + 1
                dt.day = 1
                dt.hour = 0
                dt.minute = 0
                continue
            }

            // POSIX: 如果 DOM 和 DOW 都是非通配符，则任一匹配即可
            let dayOk = bitSet32(set: days, pos: Int64(dt.day))
            let weekdayOk = bitSet8(set: weekdays, pos: Int64(dt.weekday))
            let dayMatch = if (!daysIsWildcard && !weekdaysIsWildcard) {
                dayOk || weekdayOk
            } else {
                dayOk && weekdayOk
            }
            if (!dayMatch) {
                dt.day = dt.day + 1
                dt.hour = 0
                dt.minute = 0
                continue
            }

            // 检查小时
            if (!bitSet32(set: hours, pos: Int64(dt.hour))) {
                dt.hour = dt.hour + 1
                dt.minute = 0
                continue
            }

            // 检查分钟
            if (!bitSet64(set: minutes, pos: Int64(dt.minute))) {
                dt.minute = dt.minute + 1
                continue
            }

            // 找到匹配
            return dateTimeToMs(dt: dt)
        }
        return None
    }

    // ========================================================================
    // 内部辅助方法
    // ========================================================================
}

// ============================================================================
// DateTime 内部结构 — 用于 cron next() 计算
// ============================================================================

class DateTimeParts {
    var year: Int64
    var month: Int64
    var day: Int64
    var hour: Int64
    var minute: Int64
    var second: Int64
    var weekday: Int64

    init() {
        year = 2024
        month = 1
        day = 1
        hour = 0
        minute = 0
        second = 0
        weekday = 1  // Monday
    }
}

// ============================================================================
// 位操作辅助函数
// 翻译自: cron_parser.zig bitSet / formatBitfield
// ============================================================================

/// 检查位集中指定位置是否置位 — UInt64 版本
func bitSet64(set!: UInt64, pos!: Int64): Bool {
    if (pos < 0 || pos >= 64) { return false }
    ((set >> pos) & UInt64(1)) != UInt64(0)
}

/// 检查位集中指定位置是否置位 — UInt32 版本
func bitSet32(set!: UInt32, pos!: Int64): Bool {
    if (pos < 0 || pos >= 32) { return false }
    ((set >> pos) & UInt32(1)) != UInt32(0)
}

/// 检查位集中指定位置是否置位 — UInt16 版本
func bitSet16(set!: UInt16, pos!: Int64): Bool {
    if (pos < 0 || pos >= 16) { return false }
    ((set >> pos) & UInt16(1)) != UInt16(0)
}

/// 检查位集中指定位置是否置位 — UInt8 版本
func bitSet8(set!: UInt8, pos!: Int64): Bool {
    if (pos < 0 || pos >= 8) { return false }
    ((set >> pos) & UInt8(1)) != UInt8(0)
}

/// 毫秒时间戳转 DateTime
func msToDateTime(ms!: Float64): DateTimeParts {
    let dt = DateTimeParts()
    // 简化实现 — 完整版需要 Unix epoch 算法
    let totalSeconds = Int64(ms / 1000.0)
    let totalMinutes = totalSeconds / 60
    let totalHours = totalMinutes / 60
    let totalDays = totalHours / 24

    // 从 Unix epoch (1970-01-01 Thursday) 开始计算
    var remainingDays = totalDays

    // 计算年份
    var year: Int64 = 1970
    while (true) {
        let daysInYear = if (isLeapYear(year: year)) { 366 } else { 365 }
        if (remainingDays < daysInYear) { break }
        remainingDays = remainingDays - daysInYear
        year += 1
    }
    dt.year = year

    // 计算月份
    let daysInMonths = if (isLeapYear(year: year)) {
        [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    } else {
        [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    }
    var month: Int64 = 0
    while (month < 12 && remainingDays >= daysInMonths[Int64(month)]) {
        remainingDays = remainingDays - daysInMonths[Int64(month)]
        month += 1
    }
    dt.month = month + 1  // 1-based
    dt.day = remainingDays + 1  // 1-based

    let remainingHours = totalHours - totalDays * 24
    dt.hour = remainingHours

    let remainingMinutes = totalMinutes - totalHours * 60
    dt.minute = remainingMinutes

    dt.second = totalSeconds - totalMinutes * 60

    // 计算 weekday (Zeller 或 Tomohiko Sakamoto)
    dt.weekday = dayOfWeek(year: dt.year, month: dt.month, day: dt.day)

    dt
}

/// DateTime 转毫秒时间戳
func dateTimeToMs(dt!: DateTimeParts): Float64 {
    // 简化实现 — 将日期转为 Unix timestamp
    var totalDays: Int64 = 0

    // 累加年份
    var y: Int64 = 1970
    while (y < dt.year) {
        totalDays = totalDays + (if (isLeapYear(year: y)) { 366 } else { 365 })
        y += 1
    }

    // 累加月份
    let daysInMonths = if (isLeapYear(year: dt.year)) {
        [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    } else {
        [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    }
    var m: Int64 = 0
    while (m < dt.month - 1) {
        totalDays = totalDays + daysInMonths[Int64(m)]
        m += 1
    }

    totalDays = totalDays + dt.day - 1

    let totalSeconds = totalDays * 86400 + dt.hour * 3600 + dt.minute * 60 + dt.second
    Float64(totalSeconds) * 1000.0
}

/// 规范化 DateTime (处理溢出)
func normalizeDateTime(dt!: DateTimeParts): Unit {
    // 规范化秒
    while (dt.second >= 60) {
        dt.second = dt.second - 60
        dt.minute = dt.minute + 1
    }

    // 规范化分钟
    while (dt.minute >= 60) {
        dt.minute = dt.minute - 60
        dt.hour = dt.hour + 1
    }

    // 规范化小时
    while (dt.hour >= 24) {
        dt.hour = dt.hour - 24
        dt.day = dt.day + 1
    }

    // 规范化天
    let daysInMonths = if (isLeapYear(year: dt.year)) {
        [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    } else {
        [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    }
    while (dt.month <= 12 && dt.day > daysInMonths[Int64(dt.month - 1)]) {
        dt.day = dt.day - daysInMonths[Int64(dt.month - 1)]
        dt.month = dt.month + 1
    }

    // 规范化月
    while (dt.month > 12) {
        dt.month = dt.month - 12
        dt.year = dt.year + 1
    }

    // 重新计算 weekday
    dt.weekday = dayOfWeek(year: dt.year, month: dt.month, day: dt.day)
}

/// 是否闰年
func isLeapYear(year!: Int64): Bool {
    (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
}

/// 计算星期几 (0=Sunday)
/// 使用 Tomohiko Sakamoto 算法
func dayOfWeek(year!: Int64, month!: Int64, day!: Int64): Int64 {
    let t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
    var y = year
    if (month < 3) { y = y - 1 }
    let dow = (y + y / 4 - y / 100 + y / 400 + t[Int64(month - 1)] + day) % 7
    // 转换为 0=Sunday
    (dow + 6) % 7  // Monday=0 in Sakamoto -> Sunday=0 in cron
}

// ============================================================================
// 字段解析函数
// 翻译自: cron_parser.zig parseField / parseValue / splitRange
// ============================================================================

/// NameKind — 字段名称类型
public enum NameKind {
    | none
    | weekday
    | month
}

/// 解析单个 cron 字段为 UInt64 位集
/// 翻译自: parseField(u64, field, min, max, kind)
func parseField64(field!: String, min!: Int64, max!: Int64, kind!: NameKind): ?UInt64 {
    if (field.size == 0) { return None }
    var result: UInt64 = UInt64(0)
    let parts = field.split(",")
    for (part in parts) {
        let trimmed = part.trimAscii()
        if (trimmed.size == 0) { return None }

        // 按 '/' 分割步进
        let stepParts = trimmed.split("/")
        if (stepParts.size > 2) { return None }

        let base = stepParts[0]
        let step: Int64 = if (stepParts.size == 2) {
            let s = parsePositiveInt(s: stepParts[1])
            if (s.isNone()) { return None }
            let sv = s.getOrThrow()
            if (sv == 0) { return None }
            sv
        } else {
            1
        }

        var rangeMin: Int64 = min
        var rangeMax: Int64 = max

        if (base == "*") {
            rangeMin = min
            rangeMax = max
        } else {
            let rangeResult = splitRange(base: base)
            if (rangeResult.isSome()) {
                let rp = rangeResult.getOrThrow()
                let lo = parseValue(str: rp[0], min: min, max: max, kind: kind)
                if (lo.isNone()) { return None }
                let hi = parseValue(str: rp[1], min: min, max: max, kind: kind)
                if (hi.isNone()) { return None }
                let loVal = lo.getOrThrow()
                let hiVal = hi.getOrThrow()
                if (loVal > hiVal) { return None }
                rangeMin = loVal
                rangeMax = hiVal
            } else {
                let lo = parseValue(str: base, min: min, max: max, kind: kind)
                if (lo.isNone()) { return None }
                rangeMin = lo.getOrThrow()
                rangeMax = if (stepParts.size == 2) { max } else { rangeMin }
            }
        }

        // 设置位
        var i = rangeMin
        while (i <= rangeMax) {
            if (i >= 0 && i < 64) {
                result = result | (UInt64(1) << i)
            }
            if (i + step > rangeMax) { break }
            i += step
        }
    }

    // Weekday: 将 bit 7 (Sunday 别名) 折叠到 bit 0
    if (match (kind) { case NameKind.weekday => true case _ => false }) {
        result = (result | (result >> 7)) & UInt64(0x7F)
    }

    Some(result)
}

/// 解析单个 cron 字段为 UInt32 位集
func parseField32(field!: String, min!: Int64, max!: Int64, kind!: NameKind): ?UInt32 {
    let result64 = parseField64(field: field, min: min, max: max, kind: kind)
    if (result64.isNone()) { return None }
    Some(UInt32(result64.getOrThrow() & UInt64(0xFFFFFFFF)))
}

/// 解析单个 cron 字段为 UInt16 位集
func parseField16(field!: String, min!: Int64, max!: Int64, kind!: NameKind): ?UInt16 {
    let result64 = parseField64(field: field, min: min, max: max, kind: kind)
    if (result64.isNone()) { return None }
    Some(UInt16(result64.getOrThrow() & UInt64(0xFFFF)))
}

/// 解析单个 cron 字段为 UInt8 位集
func parseField8(field!: String, min!: Int64, max!: Int64, kind!: NameKind): ?UInt8 {
    let result64 = parseField64(field: field, min: min, max: max, kind: kind)
    if (result64.isNone()) { return None }
    Some(UInt8(result64.getOrThrow() & UInt64(0xFF)))
}

/// 在 '-' 处分割范围表达式，如果不是范围则返回 None
func splitRange(base!: String): ?Array<String> {
    let idx = base.indexOf("-")
    if (idx.isNone()) { return None }
    let i = idx.getOrThrow()
    if (i <= 0 || i >= base.size - 1) { return None }
    let rest = base[Int64(i + 1)..]
    if (rest.indexOf("-").isSome()) { return None }
    [base[Int64(0)..Int64(i)], rest]
}

/// 解析单个值 (数字或名称)
func parseValue(str!: String, min!: Int64, max!: Int64, kind!: NameKind): ?Int64 {
    // 先尝试命名值查找
    if (match (kind) { case NameKind.weekday => true case _ => false }) {
        let v = lookupWeekday(name: str)
        if (v.isSome()) { return v }
    } else if (match (kind) { case NameKind.month => true case _ => false }) {
        let v = lookupMonth(name: str)
        if (v.isSome()) { return v }
    }

    // 尝试解析为数字
    let val = parsePositiveInt(s: str)
    if (val.isNone()) { return None }
    let v = val.getOrThrow()
    if (v < min || v > max) { return None }
    Some(v)
}

/// 查找星期名称
func lookupWeekday(name!: String): ?Int64 {
    let lower = toLowerAsciiStr(s: name)
    if (lower == "sun" || lower == "sunday") { return Some(0) }
    if (lower == "mon" || lower == "monday") { return Some(1) }
    if (lower == "tue" || lower == "tuesday") { return Some(2) }
    if (lower == "wed" || lower == "wednesday") { return Some(3) }
    if (lower == "thu" || lower == "thursday") { return Some(4) }
    if (lower == "fri" || lower == "friday") { return Some(5) }
    if (lower == "sat" || lower == "saturday") { return Some(6) }
    None
}

/// 查找月份名称
func lookupMonth(name!: String): ?Int64 {
    let lower = toLowerAsciiStr(s: name)
    if (lower == "jan" || lower == "january") { return Some(1) }
    if (lower == "feb" || lower == "february") { return Some(2) }
    if (lower == "mar" || lower == "march") { return Some(3) }
    if (lower == "apr" || lower == "april") { return Some(4) }
    if (lower == "may") { return Some(5) }
    if (lower == "jun" || lower == "june") { return Some(6) }
    if (lower == "jul" || lower == "july") { return Some(7) }
    if (lower == "aug" || lower == "august") { return Some(8) }
    if (lower == "sep" || lower == "september") { return Some(9) }
    if (lower == "oct" || lower == "october") { return Some(10) }
    if (lower == "nov" || lower == "november") { return Some(11) }
    if (lower == "dec" || lower == "december") { return Some(12) }
    None
}

/// ASCII 转小写辅助函数
func toLowerAsciiStr(s!: String): String {
    var result = ""
    for (c in s.toArray()) {
        if (c >= UInt8(65) && c <= UInt8(90)) {
            result = result + String(Rune(UInt32(c + UInt8(32))))
        } else {
            result = result + String(Rune(UInt32(c)))
        }
    }
    result
}

/// 解析正整数
func parsePositiveInt(s!: String): ?Int64 {
    if (s.size == 0) { return None }
    var result: Int64 = 0
    for (c in s) {
        if (c < UInt8(48) || c > UInt8(57)) { return None }
        result = result * 10 + Int64(c) - Int64(48)
    }
    Some(result)
}

// ============================================================================
// 昵称解析
// 翻译自: cron_parser.zig parseNickname
// ============================================================================

/// 解析 cron 预定义昵称
func parseNickname(expr!: String): ?CronExpression {
    let lower = toLowerAsciiStr(s: expr)
    if (lower == "@yearly" || lower == "@annually") {
        return CronExpression(
            minutes: UInt64(1), hours: UInt32(1), days: UInt32(2),
            months: UInt16(2), weekdays: ALL_WEEKDAYS,
            daysIsWildcard: false, weekdaysIsWildcard: true
        )
    }
    if (lower == "@monthly") {
        return CronExpression(
            minutes: UInt64(1), hours: UInt32(1), days: UInt32(2),
            months: ALL_MONTHS, weekdays: ALL_WEEKDAYS,
            daysIsWildcard: false, weekdaysIsWildcard: true
        )
    }
    if (lower == "@weekly") {
        return CronExpression(
            minutes: UInt64(1), hours: UInt32(1), days: ALL_DAYS,
            months: ALL_MONTHS, weekdays: UInt8(1),
            daysIsWildcard: true, weekdaysIsWildcard: false
        )
    }
    if (lower == "@daily" || lower == "@midnight") {
        return CronExpression(
            minutes: UInt64(1), hours: UInt32(1), days: ALL_DAYS,
            months: ALL_MONTHS, weekdays: ALL_WEEKDAYS,
            daysIsWildcard: true, weekdaysIsWildcard: true
        )
    }
    if (lower == "@hourly") {
        return CronExpression(
            minutes: UInt64(1), hours: ALL_HOURS, days: ALL_DAYS,
            months: ALL_MONTHS, weekdays: ALL_WEEKDAYS,
            daysIsWildcard: true, weekdaysIsWildcard: true
        )
    }
    None
}

// ============================================================================
// 位集格式化
// 翻译自: cron_parser.zig formatBitfield
// ============================================================================

/// 格式化 UInt64 位集为 cron 字段字符串
func formatBitfield64(bits!: UInt64, min!: Int64, max!: Int64): String {
    // 检查是否所有位都置位
    var allSet: Bool = true
    var count: Int64 = 0
    var i = min
    while (i <= max) {
        if (bitSet64(set: bits, pos: i)) {
            count += 1
        } else {
            allSet = false
        }
        i += 1
    }
    if (count == max - min + 1) { return "*" }

    var result = ""
    var first = true
    i = min
    while (i <= max) {
        if (bitSet64(set: bits, pos: i)) {
            if (!first) { result = result + "," }
            result = result + i.toString()
            first = false
        }
        i += 1
    }
    result
}

/// 格式化 UInt32 位集为 cron 字段字符串
func formatBitfield32(bits!: UInt32, min!: Int64, max!: Int64): String {
    formatBitfield64(bits: UInt64(bits), min: min, max: max)
}

/// 格式化 UInt16 位集为 cron 字段字符串
func formatBitfield16(bits!: UInt16, min!: Int64, max!: Int64): String {
    formatBitfield64(bits: UInt64(bits), min: min, max: max)
}

/// 格式化 UInt8 位集为 cron 字段字符串
func formatBitfield8(bits!: UInt8, min!: Int64, max!: Int64): String {
    formatBitfield64(bits: UInt64(bits), min: min, max: max)
}
