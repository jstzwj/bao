// 严格翻译自: src/runtime/api/cron_parser.rs
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// CronExpression - Cron 表达式解析器和下次触发时间计算器
// 对应 Bun: src/runtime/api/cron_parser.rs
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
///   - 命名天: SUN-SAT, Sun-Sat, Sunday-Saturday (不区分大小写)
///   - 命名月: JAN-DEC, Jan-Dec, January-December (不区分大小写)
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

    public init() {
        minutes = 0
        hours = 0
        days = 0
        months = 0
        weekdays = 0
        daysIsWildcard = false
        weekdaysIsWildcard = false
    }

    public init(
        minutes: UInt64,
        hours: UInt32,
        days: UInt32,
        months: UInt16,
        weekdays: UInt8,
        daysIsWildcard: Bool,
        weekdaysIsWildcard: Bool,
    ) {
        this.minutes = minutes
        this.hours = hours
        this.days = days
        this.months = months
        this.weekdays = weekdays
        this.daysIsWildcard = daysIsWildcard
        this.weekdaysIsWildcard = weekdaysIsWildcard
    }

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
                    "Invalid cron expression: too many fields. Bun.cron uses 5 fields (minute hour day month weekday) \u{2014} seconds are not supported"
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

        public func errorMessageBytes(): Array<UInt8> {
            return errorMessage().toUtf8().toArray()
        }
    }

    // ========================================================================
    // 解析
    // ========================================================================

    /// 解析 5 字段 cron 表达式或预定义昵称为 CronExpression
    public static func parse(input: Array<UInt8>): CronExpression {
        let expr = Strings.trim(input, [' ', '\t'])

        // 检查预定义昵称
        if (!expr.isEmpty && expr[0] == UInt8('@')) {
            if (let result = parseNickname(expr)) {
                return result
            }
            throw Error.invalidField
        }

        var count: Int = 0
        var fields: Array<Array<UInt8>> = Array<Array<UInt8>>()

        var i: Int = 0
        while (i < expr.size) {
            // 跳过空格/制表符
            while (i < expr.size && (expr[i] == UInt8(' ') || expr[i] == UInt8('\t'))) {
                i++
            }
            if (i >= expr.size) { break }

            let start = i
            while (i < expr.size && expr[i] != UInt8(' ') && expr[i] != UInt8('\t')) {
                i++
            }
            if (count >= 5) {
                throw Error.tooManyFields
            }
            var field = Array<UInt8>()
            for (j in start..i) {
                field.append(expr[j])
            }
            fields.append(field)
            count++
        }

        if (count != 5) {
            throw Error.tooFewFields
        }

        return CronExpression(
            minutes: parseField64(fields[0], 0, 59, NameKind.none),
            hours: parseField32(fields[1], 0, 23, NameKind.none),
            days: parseField32(fields[2], 1, 31, NameKind.none),
            months: parseField16(fields[3], 1, 12, NameKind.month),
            weekdays: parseField8(fields[4], 0, 7, NameKind.weekday),
            daysIsWildcard: fields[2].size == 1 && fields[2][0] == UInt8('*'),
            weekdaysIsWildcard: fields[4].size == 1 && fields[4][0] == UInt8('*'),
        )
    }

    /// 解析字符串版本
    public static func parse(input: String): CronExpression {
        return parse(input.toUtf8().toArray())
    }

    /// 验证 cron 表达式字符串 (不分配)
    public static func validate(expr: Array<UInt8>): Bool {
        try {
            _ = parse(expr)
            return true
        } catch {
            return false
        }
    }

    /// 验证 cron 表达式字符串
    public static func validate(expr: String): Bool {
        return validate(expr.toUtf8().toArray())
    }

    // ========================================================================
    // 格式化
    // ========================================================================

    /// 将表达式格式化为标准化的数字 "M H D Mo W" 字符串
    /// 适合 crontab 使用. 返回写入 buf 的切片
    public func formatNumeric(buf: Array<UInt8>): Array<UInt8> {
        formatBitfield64(buf, minutes, 0, 59)
        buf.append(UInt8(' '))
        formatBitfield32(buf, hours, 0, 23)
        buf.append(UInt8(' '))
        formatBitfield32(buf, days, 1, 31)
        buf.append(UInt8(' '))
        formatBitfield16(buf, months, 1, 12)
        buf.append(UInt8(' '))
        formatBitfield8(buf, weekdays, 0, 6)
        return buf
    }

    /// 格式化为字符串
    public func formatNumericString(): String {
        let buf = Array<UInt8>()
        formatNumeric(buf)
        return String.fromUtf8(buf)
    }

    // ========================================================================
    // 下次触发时间
    // ========================================================================

    /// 计算匹配此表达式的下一个 UTC 时间 (毫秒时间戳)
    /// 严格在 fromMs 之后. 在 8 年内未找到匹配则返回 none
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
            // 否则 `*` 字段匹配所有
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
    public static func parseField64(field: Array<UInt8>, min: UInt8, max: UInt8, kind: NameKind): UInt64 {
        if (field.isEmpty) { throw Error.invalidField }
        var result: UInt64 = 0

        // 按 ',' 分割
        var partStart: Int = 0
        for (i in 0..field.size + 1) {
            if (i == field.size || field[i] == UInt8(',')) {
                if (i == partStart) { throw Error.invalidField }

                var part = Array<UInt8>()
                for (j in partStart..i) {
                    part.append(field[j])
                }

                // 按 '/' 分割以获取步长
                var basePart = part
                var stepStr: ?Array<UInt8> = none
                var slashCount: Int = 0

                for (j in 0..part.size) {
                    if (part[j] == UInt8('/')) {
                        slashCount++
                        if (slashCount == 1) {
                            basePart = Array<UInt8>()
                            for (k in 0..j) {
                                basePart.append(part[k])
                            }
                            stepStr = Array<UInt8>()
                            for (k in (j + 1)..part.size) {
                                stepStr.get().append(part[k])
                            }
                        }
                    }
                }
                if (slashCount > 1) { throw Error.invalidStep }

                let step: UInt8 = if (let s = stepStr) {
                    if (s.isEmpty) { throw Error.invalidStep }
                    let parsed = parseDecimal8(s)
                    if (parsed == none) { throw Error.invalidStep }
                    parsed.get()
                } else {
                    1
                }
                if (step == 0) { throw Error.invalidStep }

                var rangeMin: UInt8 = 0
                var rangeMax: UInt8 = 0

                if (basePart.size == 1 && basePart[0] == UInt8('*')) {
                    rangeMin = min
                    rangeMax = max
                } else if (let rangeParts = splitRange(basePart)) {
                    let lo = parseValue(rangeParts[0], min, max, kind)
                    if (lo == none) { throw Error.invalidNumber }
                    let hi = parseValue(rangeParts[1], min, max, kind)
                    if (hi == none) { throw Error.invalidNumber }
                    if (lo.get() > hi.get()) { throw Error.invalidRange }
                    rangeMin = lo.get()
                    rangeMax = hi.get()
                } else {
                    let lo = parseValue(basePart, min, max, kind)
                    if (lo == none) { throw Error.invalidNumber }
                    rangeMin = lo.get()
                    rangeMax = if (stepStr != none) { max } else { lo.get() }
                }

                // 设置位
                var ii: UInt8 = rangeMin
                while (ii <= rangeMax) {
                    result |= UInt64(1) << UInt64(ii)
                    if (UInt16(ii) + UInt16(step) > UInt16(rangeMax)) { break }
                    ii += step
                }

                partStart = i + 1
            }
        }

        // 星期: 将位 7 (星期日别名) 折叠到位 0
        // 范围扩展后, 使 5-7, 0-7 等像 Vixie/croner/cron-parser 一样工作
        if (kind == NameKind.weekday) {
            result = (result | (result >> 7)) & 0x7F
        }

        return result
    }

    /// 解析单个 cron 字段 (32位位集)
    public static func parseField32(field: Array<UInt8>, min: UInt8, max: UInt8, kind: NameKind): UInt32 {
        return UInt32(parseField64(field, min, max, kind) & 0xFFFFFFFF)
    }

    /// 解析单个 cron 字段 (16位位集)
    public static func parseField16(field: Array<UInt8>, min: UInt8, max: UInt8, kind: NameKind): UInt16 {
        return UInt16(parseField64(field, min, max, kind) & 0xFFFF)
    }

    /// 解析单个 cron 字段 (8位位集)
    public static func parseField8(field: Array<UInt8>, min: UInt8, max: UInt8, kind: NameKind): UInt8 {
        return UInt8(parseField64(field, min, max, kind) & 0xFF)
    }

    /// 在 '-' 上分割范围表达式, 如果不是范围则返回 none
    public static func splitRange(base: Array<UInt8>): ?(Array<UInt8>, Array<UInt8>) {
        var idx: ?Int = none
        for (i in 0..base.size) {
            if (base[i] == UInt8('-')) {
                idx = i
                break
            }
        }
        if (idx == none || idx.get() == 0 || idx.get() == base.size - 1) { return none }

        let idxVal = idx.get()
        var rest = Array<UInt8>()
        for (i in (idxVal + 1)..base.size) {
            rest.append(base[i])
        }

        // rest 中不允许有额外的 '-'
        for (i in 0..rest.size) {
            if (rest[i] == UInt8('-')) { return none }
        }

        var first = Array<UInt8>()
        for (i in 0..idxVal) {
            first.append(base[i])
        }
        return (first, rest)
    }

    /// 解析单个值 (数字或名称), 验证范围
    public static func parseValue(str: Array<UInt8>, min: UInt8, max: UInt8, kind: NameKind): ?UInt8 {
        // 先尝试命名值查找 (不区分大小写)
        match (kind) {
            case .weekday =>
                if (let v = lookupWeekday(str)) { return v }
            case .month =>
                if (let v = lookupMonth(str)) { return v }
            case .none => ()
        }

        let val = parseDecimal8(str)
        if (val == none) { return none }
        if (val.get() < min || val.get() > max) { return none }
        return val.get()
    }

    // ========================================================================
    // 昵称解析
    // ========================================================================

    /// 解析预定义昵称
    public static func parseNickname(expr: Array<UInt8>): ?CronExpression {
        if (eqlCaseInsensitiveASCII(expr, "@yearly") || eqlCaseInsensitiveASCII(expr, "@annually")) {
            return CronExpression(
                minutes: 1,
                hours: 1,
                days: 1 << 1,
                months: 1 << 1,
                weekdays: allWeekdays,
                daysIsWildcard: false,
                weekdaysIsWildcard: true,
            )
        }
        if (eqlCaseInsensitiveASCII(expr, "@monthly")) {
            return CronExpression(
                minutes: 1,
                hours: 1,
                days: 1 << 1,
                months: allMonths,
                weekdays: allWeekdays,
                daysIsWildcard: false,
                weekdaysIsWildcard: true,
            )
        }
        if (eqlCaseInsensitiveASCII(expr, "@weekly")) {
            return CronExpression(
                minutes: 1,
                hours: 1,
                days: allDays,
                months: allMonths,
                weekdays: 1,
                daysIsWildcard: true,
                weekdaysIsWildcard: false,
            )
        }
        if (eqlCaseInsensitiveASCII(expr, "@daily") || eqlCaseInsensitiveASCII(expr, "@midnight")) {
            return CronExpression(
                minutes: 1,
                hours: 1,
                days: allDays,
                months: allMonths,
                weekdays: allWeekdays,
                daysIsWildcard: true,
                weekdaysIsWildcard: true,
            )
        }
        if (eqlCaseInsensitiveASCII(expr, "@hourly")) {
            return CronExpression(
                minutes: 1,
                hours: allHours,
                days: allDays,
                months: allMonths,
                weekdays: allWeekdays,
                daysIsWildcard: true,
                weekdaysIsWildcard: true,
            )
        }
        return none
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 检查位集中特定位是否设置 (64位)
    public static func bitSet64(set: UInt64, pos: UInt64): Bool {
        return (set >> pos) & 1 != 0
    }

    /// 检查位集中特定位是否设置 (32位)
    public static func bitSet32(set: UInt32, pos: UInt32): Bool {
        return (set >> pos) & 1 != 0
    }

    /// 检查位集中特定位是否设置 (16位)
    public static func bitSet16(set: UInt16, pos: UInt16): Bool {
        return (set >> pos) & 1 != 0
    }

    /// 检查位集中特定位是否设置 (8位)
    public static func bitSet8(set: UInt8, pos: UInt8): Bool {
        return (set >> pos) & 1 != 0
    }

    /// 格式化位字段为 cron 字段字符串 (64位)
    /// 如果所有位都设置了则为 "*", 否则为逗号分隔的值
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
                let s = i.toString()
                for (c in s) {
                    buf.append(UInt8(c))
                }
                first = false
            }
        }
    }

    /// 格式化位字段为 cron 字段字符串 (32位)
    public static func formatBitfield32(buf: Array<UInt8>, bits: UInt32, min: UInt8, max: UInt8): Unit {
        formatBitfield64(buf, UInt64(bits), min, max)
    }

    /// 格式化位字段为 cron 字段字符串 (16位)
    public static func formatBitfield16(buf: Array<UInt8>, bits: UInt16, min: UInt8, max: UInt8): Unit {
        formatBitfield64(buf, UInt64(bits), min, max)
    }

    /// 格式化位字段为 cron 字段字符串 (8位)
    public static func formatBitfield8(buf: Array<UInt8>, bits: UInt8, min: UInt8, max: UInt8): Unit {
        formatBitfield64(buf, UInt64(bits), min, max)
    }

    /// 解析十进制字符串为 UInt8
    public static func parseDecimal8(s: Array<UInt8>): ?UInt8 {
        if (s.isEmpty) { return none }
        var result: UInt8 = 0
        for (i in 0..s.size) {
            let c = s[i]
            if (c < UInt8('0') || c > UInt8('9')) { return none }
            let digit = c - UInt8('0')
            // 检查溢出
            if (result > (UInt8(255) - digit) / 10) { return none }
            result = result * 10 + digit
        }
        return result
    }

    /// 不区分大小写 ASCII 比较 (字节数组)
    public static func eqlCaseInsensitiveASCII(a: Array<UInt8>, b: String): Bool {
        let bBytes = b.toUtf8().toArray()
        if (a.size != bBytes.size) { return false }
        for (i in 0..a.size) {
            let ca = a[i]
            let cb = bBytes[i]
            if (toLowerASCII(ca) != toLowerASCII(cb)) { return false }
        }
        return true
    }

    /// ASCII 转小写
    public static func toLowerASCII(c: UInt8): UInt8 {
        if (c >= UInt8('A') && c <= UInt8('Z')) {
            return c + (UInt8('a') - UInt8('A'))
        }
        return c
    }

    /// 不区分大小写查找星期名称
    public static func lookupWeekday(str: Array<UInt8>): ?UInt8 {
        let names: Array<(String, UInt8)> = [
            ("sun", 0), ("mon", 1), ("tue", 2), ("wed", 3),
            ("thu", 4), ("fri", 5), ("sat", 6),
            ("sunday", 0), ("monday", 1), ("tuesday", 2),
            ("wednesday", 3), ("thursday", 4), ("friday", 5), ("saturday", 6),
        ]
        for ((name, value) in names) {
            if (eqlCaseInsensitiveASCII(str, name)) {
                return value
            }
        }
        return none
    }

    /// 不区分大小写查找月份名称
    public static func lookupMonth(str: Array<UInt8>): ?UInt8 {
        let names: Array<(String, UInt8)> = [
            ("jan", 1), ("feb", 2), ("mar", 3), ("apr", 4),
            ("may", 5), ("jun", 6), ("jul", 7), ("aug", 8),
            ("sep", 9), ("oct", 10), ("nov", 11), ("dec", 12),
            ("january", 1), ("february", 2), ("march", 3), ("april", 4),
            ("june", 6), ("july", 7), ("august", 8), ("september", 9),
            ("october", 10), ("november", 11), ("december", 12),
        ]
        for ((name, value) in names) {
            if (eqlCaseInsensitiveASCII(str, name)) {
                return value
            }
        }
        return none
    }

    // ========================================================================
    // 常量
    // ========================================================================

    /// 所有小时代码 (位 0-23 全部设置)
    public static let allHours: UInt32 = (1 << 24) - 1

    /// 所有日代码 (位 1-31 全部设置)
    public static let allDays: UInt32 = UInt32((UInt64(1) << 32) - 1) & ~UInt32(1)

    /// 所有月代码 (位 1-12 全部设置)
    public static let allMonths: UInt16 = UInt16((UInt32(1) << 13) - 1) & ~UInt16(1)

    /// 所有星期代码 (位 0-6 全部设置)
    public static let allWeekdays: UInt8 = UInt8((1 << 7) - 1)

    // ========================================================================
    // 字符串辅助
    // ========================================================================

    /// 字符串 trim 辅助 (去除首尾空白)
    public static func trimBytes(input: Array<UInt8>, chars: Array<UInt8>): Array<UInt8> {
        var start: Int = 0
        var end: Int = input.size
        while (start < end) {
            var found = false
            for (c in chars) {
                if (input[start] == c) { found = true; break }
            }
            if (!found) { break }
            start++
        }
        while (end > start) {
            var found = false
            for (c in chars) {
                if (input[end - 1] == c) { found = true; break }
            }
            if (!found) { break }
            end--
        }
        var result = Array<UInt8>()
        for (i in start..end) {
            result.append(input[i])
        }
        return result
    }

    /// 字符串辅助 - 兼容旧接口
    public static func trim(input: Array<UInt8>, chars: Array<UInt8>): Array<UInt8> {
        return trimBytes(input, chars)
    }

    /// 计算 popcount
    public static func popCount64(v: UInt64): Int {
        var count: Int = 0
        var temp = v
        while (temp != 0) {
            count += Int(temp & 1)
            temp >>= 1
        }
        return count
    }

    /// 计算 popcount32
    public static func popCount32(v: UInt32): Int {
        var count: Int = 0
        var temp = v
        while (temp != 0) {
            count += Int(temp & 1)
            temp >>= 1
        }
        return count
    }

    /// 计算 trailing zeros (64位)
    public static func trailingZeros64(v: UInt64): Int {
        if (v == 0) { return 64 }
        var count: Int = 0
        var temp = v
        while ((temp & 1) == 0) {
            count++
            temp >>= 1
        }
        return count
    }

    /// 计算 trailing zeros (32位)
    public static func trailingZeros32(v: UInt32): Int {
        if (v == 0) { return 32 }
        var count: Int = 0
        var temp = v
        while ((temp & 1) == 0) {
            count++
            temp >>= 1
        }
        return count
    }
}

// ============================================================================
// 字符串辅助 (Strings)
// ============================================================================

/// 字符串工具类
public class Strings {
    /// 去除首尾空白字符
    public static func trim(input: Array<UInt8>, chars: Array<UInt8>): Array<UInt8> {
        return CronExpression.trimBytes(input, chars)
    }

    /// 去除首尾空白字符 (字符串版本)
    public static func trim(input: String, chars: Array<UInt8>): Array<UInt8> {
        return trim(input.toUtf8().toArray(), chars)
    }

    /// 查找字符在字节数组中的位置
    public static func indexOf(input: Array<UInt8>, ch: UInt8): ?Int {
        for (i in 0..input.size) {
            if (input[i] == ch) { return i }
        }
        return none
    }
}
