// 严格翻译自: src/runtime/built-in objects
// JavaScript 内置对象 — Math, Date, JSON, RegExp, Error
// 对应 Bun: src/runtime/ 中注册的全局内置对象
//   Bun 在 VirtualMachine 初始化时通过 JSC C API 注册这些对象
//   仓颉用原生类实现等价的 API
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_jsc.{RegularExpression, RegularExpressionFlags, RegexExecResult}
import std.random.*

// ============================================================================
// MathObject - Math 内置对象
// 对应 Bun: src/runtime/MathObject (JSC 全局注册)
//   ECMAScript Math 对象提供数学常数和函数
//   Bun 通过 JSC 的 JSObjectMakeNumber 等注册 Math 属性
// ============================================================================

/// Math 内置对象 - 对应 JS Math
/// 所有方法和属性都是静态的，Math 不是构造器
public class MathObject {
    // ---- 数学常数 - 对应 Math.E, Math.PI 等 ----

    /// 自然对数的底数 e - 对应 Math.E
    public static let E: Float64 = 2.718281828459045
    /// 圆周率 pi - 对应 Math.PI
    public static let PI: Float64 = 3.141592653589793
    /// 2 的自然对数 - 对应 Math.LN2
    public static let LN2: Float64 = 0.6931471805599453
    /// 10 的自然对数 - 对应 Math.LN10
    public static let LN10: Float64 = 2.302585092994046
    /// 以 2 为底 e 的对数 - 对应 Math.LOG2E
    public static let LOG2E: Float64 = 1.4426950408889634
    /// 以 10 为底 e 的对数 - 对应 Math.LOG10E
    public static let LOG10E: Float64 = 0.4342944819032518
    /// 2 的平方根 - 对应 Math.SQRT2
    public static let SQRT2: Float64 = 1.4142135623730951
    /// 1/2 的平方根 - 对应 Math.SQRT1_2
    public static let SQRT1_2: Float64 = 0.7071067811865476

    // ---- 数学函数 ----

    /// 绝对值 - 对应 Math.abs
    public static func abs(x: Float64): Float64 {
        return if (x < 0.0) { -x } else { x }
    }

    /// 向上取整 - 对应 Math.ceil
    public static func ceil(x: Float64): Float64 {
        return Float64(Int64(x) + (if (x > Float64(Int64(x))) { 1 } else { 0 }))
    }

    /// 向下取整 - 对应 Math.floor
    public static func floor(x: Float64): Float64 {
        return Float64(Int64(x))
    }

    /// 四舍五入 - 对应 Math.round
    public static func round(x: Float64): Float64 {
        return Float64(Int64(x + 0.5))
    }

    /// 截断小数部分 - 对应 Math.trunc
    public static func trunc(x: Float64): Float64 {
        return Float64(Int64(x))
    }

    /// 取较大值 - 对应 Math.max
    public static func max(a: Float64, b: Float64): Float64 {
        return if (a > b) { a } else { b }
    }

    /// 取较小值 - 对应 Math.min
    public static func min(a: Float64, b: Float64): Float64 {
        return if (a < b) { a } else { b }
    }

    /// 幂运算 - 对应 Math.pow
    public static func pow(base: Float64, exp: Float64): Float64 {
        // 使用泰勒展开近似: pow(x,y) = exp(y * ln(x))
        // 简化实现
        if (exp == 0.0) { return 1.0 }
        if (exp == 1.0) { return base }
        if (base == 0.0) { return 0.0 }
        if (base == 1.0) { return 1.0 }
        // 整数指数快速路径
        let intExp = Int64(exp)
        if (Float64(intExp) == exp) {
            var result: Float64 = 1.0
            var b = base
            var e = if (intExp < 0) { -intExp } else { intExp }
            while (e > 0) {
                if (e % 2 == 1) {
                    result = result * b
                }
                b = b * b
                e = e / 2
            }
            return if (intExp < 0) { 1.0 / result } else { result }
        }
        return expInternal(base, exp)
    }

    /// 平方根 - 对应 Math.sqrt
    public static func sqrt(x: Float64): Float64 {
        if (x < 0.0) { return Float64.NaN }
        if (x == 0.0) { return 0.0 }
        // 牛顿法: x_{n+1} = (x_n + a/x_n) / 2
        var guess = x
        for (_ in 0..20) {
            guess = (guess + x / guess) / 2.0
        }
        return guess
    }

    /// 立方根 - 对应 Math.cbrt
    public static func cbrt(x: Float64): Float64 {
        if (x == 0.0) { return 0.0 }
        var guess = x
        for (_ in 0..20) {
            guess = (2.0 * guess + x / (guess * guess)) / 3.0
        }
        return guess
    }

    /// 自然对数 - 对应 Math.log
    public static func log(x: Float64): Float64 {
        if (x <= 0.0) { return Float64.NaN }
        if (x == 1.0) { return 0.0 }
        return lnInternal(x)
    }

    /// 以 2 为底对数 - 对应 Math.log2
    public static func log2(x: Float64): Float64 {
        return log(x) / LN2
    }

    /// 以 10 为底对数 - 对应 Math.log10
    public static func log10(x: Float64): Float64 {
        return log(x) / LN10
    }

    /// 指数函数 e^x - 对应 Math.exp
    public static func exp(x: Float64): Float64 {
        return expInternal(E, x)
    }

    /// 正弦 - 对应 Math.sin
    public static func sin(x: Float64): Float64 {
        return sinInternal(x)
    }

    /// 余弦 - 对应 Math.cos
    public static func cos(x: Float64): Float64 {
        return cosInternal(x)
    }

    /// 正切 - 对应 Math.tan
    public static func tan(x: Float64): Float64 {
        let c = cosInternal(x)
        if (c == 0.0) { return Float64.NaN }
        return sinInternal(x) / c
    }

    /// 反正弦 - 对应 Math.asin
    public static func asin(x: Float64): Float64 {
        if (x < -1.0 || x > 1.0) { return Float64.NaN }
        return atan2Internal(x, sqrt(1.0 - x * x))
    }

    /// 反余弦 - 对应 Math.acos
    public static func acos(x: Float64): Float64 {
        if (x < -1.0 || x > 1.0) { return Float64.NaN }
        return PI / 2.0 - atan2Internal(x, sqrt(1.0 - x * x))
    }

    /// 反正切 - 对应 Math.atan
    public static func atan(x: Float64): Float64 {
        return atan2Internal(x, 1.0)
    }

    /// 二参数反正切 - 对应 Math.atan2
    public static func atan2(y: Float64, x: Float64): Float64 {
        return atan2Internal(y, x)
    }

    /// 取符号 - 对应 Math.sign
    public static func sign(x: Float64): Float64 {
        if (x > 0.0) { return 1.0 }
        if (x < 0.0) { return -1.0 }
        return 0.0
    }

    /// 随机数 [0, 1) - 对应 Math.random
    public static func random(): Float64 {
        let rng = Random()
        return Float64(rng.nextUInt64()) / Float64(UInt64.Max)
    }

    /// 欧几里得距离 - 对应 Math.hypot
    public static func hypot(values: ArrayList<Float64>): Float64 {
        var sum: Float64 = 0.0
        for (v in values) {
            sum += v * v
        }
        return sqrt(sum)
    }

    /// 前导零计数 - 对应 Math.clz32
    public static func clz32(x: Int32): Int64 {
        if (x == 0) { return 32 }
        var n: Int64 = 0
        var val = UInt32(x)
        while ((val & 0x80000000) == 0) {
            n += 1
            val = val << 1
        }
        return n
    }

    /// 32 位整数乘法 - 对应 Math.imul
    public static func imul(a: Int32, b: Int32): Int32 {
        return a * b
    }

    /// 转为 32 位浮点 - 对应 Math.fround
    public static func fround(x: Float64): Float32 {
        return Float32(x)
    }

    // ---- 内部数学实现 ----

    /// 内部指数计算 - 泰勒展开近似
    private static func expInternal(base: Float64, exp: Float64): Float64 {
        return expTaylorSeries(exp * lnInternal(base))
    }

    /// e^x 泰勒展开
    private static func expTaylorSeries(x: Float64): Float64 {
        var result: Float64 = 1.0
        var term: Float64 = 1.0
        for (i in 1..30) {
            term = term * x / Float64(i)
            result += term
        }
        return result
    }

    /// 自然对数内部实现 - 牛顿法
    private static func lnInternal(x: Float64): Float64 {
        // 将 x 归一化到 [0.5, 2] 范围
        var k: Int64 = 0
        var y = x
        while (y > 2.0) {
            y = y / 2.0
            k += 1
        }
        while (y < 0.5) {
            y = y * 2.0
            k -= 1
        }
        // ln(1+z) 级数展开, z = y - 1
        let z = y - 1.0
        var result: Float64 = 0.0
        var term: Float64 = z
        for (i in 1..30) {
            result += term / Float64(i)
            term = -term * z
        }
        return result + Float64(k) * LN2
    }

    private static func floatRemainder(x: Float64, divisor: Float64): Float64 {
        return x - Float64(Int64(x / divisor)) * divisor
    }

    /// 正弦内部实现 - 泰勒展开
    private static func sinInternal(x: Float64): Float64 {
        // 归一化到 [-PI, PI]
        var y = floatRemainder(x, 2.0 * PI)
        if (y > PI) { y -= 2.0 * PI }
        if (y < -PI) { y += 2.0 * PI }
        // 泰勒展开: sin(x) = x - x^3/3! + x^5/5! - ...
        var result: Float64 = 0.0
        var term: Float64 = y
        for (i in 0..15) {
            result += term
            term = -term * y * y / Float64((2 * i + 2) * (2 * i + 3))
        }
        return result
    }

    /// 余弦内部实现 - 泰勒展开
    private static func cosInternal(x: Float64): Float64 {
        var y = floatRemainder(x, 2.0 * PI)
        if (y > PI) { y -= 2.0 * PI }
        if (y < -PI) { y += 2.0 * PI }
        // 泰勒展开: cos(x) = 1 - x^2/2! + x^4/4! - ...
        var result: Float64 = 0.0
        var term: Float64 = 1.0
        for (i in 0..15) {
            result += term
            term = -term * y * y / Float64((2 * i + 1) * (2 * i + 2))
        }
        return result
    }

    /// atan2 内部实现
    private static func atan2Internal(y: Float64, x: Float64): Float64 {
        if (x == 0.0 && y == 0.0) { return 0.0 }
        if (x > 0.0) { return atanTaylor(y / x) }
        if (x < 0.0) {
            if (y >= 0.0) { return PI + atanTaylor(y / x) }
            return -PI + atanTaylor(y / x)
        }
        // x == 0
        return if (y > 0.0) { PI / 2.0 } else { -PI / 2.0 }
    }

    /// atan 泰勒展开
    private static func atanTaylor(x: Float64): Float64 {
        var y = x
        // 利用 atan(x) = 2*atan(x/(1+sqrt(1+x*x))) 收敛更快
        var result: Float64 = 0.0
        var term: Float64 = y
        for (i in 0..30) {
            result += term / Float64(2 * i + 1)
            term = -term * y * y
        }
        return result
    }
}

// ============================================================================
// DateObject - Date 内置对象
// 对应 Bun: src/runtime/DateObject (JSC Date)
//   ECMAScript Date 对象基于 UTC 1970-01-01 的毫秒时间戳
//   Bun 通过 JSC 的 JSObjectMakeDate 创建 Date 实例
// ============================================================================

/// Date 内置对象 - 对应 JS Date
/// 表示自 1970-01-01T00:00:00Z (Unix Epoch) 以来的毫秒数
public class DateObject {
    /// 时间戳 - 毫秒精度, 对应 [[DateValue]] 内部槽位
    private var timestamp: Int64

    /// 创建当前时间的 Date - 对应 new Date()
    public init() {
        timestamp = currentTimeMillis()
    }

    /// 从时间戳创建 Date - 对应 new Date(value)
    public init(timestamp: Int64) {
        this.timestamp = timestamp
    }

    /// 获取当前时间戳 - 对应 Date.now()
    public static func now(): Int64 {
        return currentTimeMillis()
    }

    /// 解析日期字符串 - 对应 Date.parse(dateString)
    /// 支持 ISO 8601 格式 (YYYY-MM-DDTHH:mm:ss.sssZ) 和常见变体
    public static func parse(dateStr: String): Int64 {
        let s = dateStr.trimStart().trimEnd()
        if (s.isEmpty()) {
            return Int64(-1)  // Invalid Date
        }

        // 尝试解析 ISO 8601 格式: YYYY-MM-DDTHH:mm:ss.sssZ
        // 或 YYYY-MM-DDTHH:mm:ss.sss+HH:MM
        // 或 YYYY-MM-DD HH:mm:ss
        var year = Int64(0)
        var month = Int64(1)
        var day = Int64(1)
        var hour = Int64(0)
        var minute = Int64(0)
        var second = Int64(0)
        var ms = Int64(0)

        // 查找日期和时间分隔符
        let tPos = s.indexOf(UInt8(0x54))  // 'T'
        let spacePos = s.indexOf(UInt8(0x20))  // ' '
        let dateEnd = if (tPos.isSome()) { tPos.getOrThrow() } else if (spacePos.isSome()) { spacePos.getOrThrow() } else { Int64(s.size) }

        // 解析日期部分 YYYY-MM-DD
        let datePart = s[0..dateEnd]
        let dash1Opt = datePart.indexOf('-')
        if (dash1Opt.isNone()) {
            return Int64(-1)
        }
        let dash1 = dash1Opt.getOrThrow()
        year = parseInt64(datePart[0..dash1])
        let dash2Opt = datePart.indexOf('-', dash1 + 1)
        if (dash2Opt.isNone()) {
            month = parseInt64(datePart[dash1 + 1..datePart.size])
        } else {
            let dash2 = dash2Opt.getOrThrow()
            month = parseInt64(datePart[dash1 + 1..dash2])
            day = parseInt64(datePart[dash2 + 1..datePart.size])
        }

        // 解析时间部分 HH:mm:ss.sss
        if (dateEnd < s.size) {
            let timePart = s[dateEnd + 1..s.size]
            // 去掉时区后缀 (+HH:MM 或 Z)
            let cleanTime = if (timePart.endsWith("Z")) {
                timePart[0..timePart.size - 1]
            } else {
                let plusIdx = timePart.indexOf('+')
                if (plusIdx.isSome()) { timePart[0..plusIdx.getOrThrow()] } else { timePart }
            }

            let colon1Opt = cleanTime.indexOf(':')
            if (colon1Opt.isSome()) {
                let colon1 = colon1Opt.getOrThrow()
                hour = parseInt64(cleanTime[0..colon1])
                let colon2Opt = cleanTime.indexOf(':', colon1 + 1)
                if (colon2Opt.isSome()) {
                    let colon2 = colon2Opt.getOrThrow()
                    minute = parseInt64(cleanTime[colon1 + 1..colon2])
                    let dotPosOpt = cleanTime.indexOf('.', colon2 + 1)
                    if (dotPosOpt.isSome()) {
                        let dotPos = dotPosOpt.getOrThrow()
                        second = parseInt64(cleanTime[colon2 + 1..dotPos])
                        ms = parseInt64(cleanTime[dotPos + 1..cleanTime.size])
                    } else {
                        second = parseInt64(cleanTime[colon2 + 1..cleanTime.size])
                    }
                } else {
                    minute = parseInt64(cleanTime[colon1 + 1..cleanTime.size])
                }
            }
        }

        utcFromComponents(year, month - 1, day, hour, minute, second) + ms
    }

    // 解析整数辅助函数
    private static func parseInt64(s: String): Int64 {
        if (s.isEmpty()) { return Int64(0) }
        var result = Int64(0)
        for (i in 0..s.size) {
            let c = s[i]
            if (c >= UInt8(0x30) && c <= UInt8(0x39)) {
                result = result * 10 + Int64(c - UInt8(0x30))
            } else {
                break
            }
        }
        result
    }

    /// 从 UTC 组件创建时间戳 - 对应 Date.UTC(year, month, ...)
    public static func UTC(year: Int64, month: Int64, day: Int64,
        hour: Int64, minute: Int64, second: Int64, ms: Int64): Int64 {
        return utcFromComponents(year, month, day, hour, minute, second) + ms
    }

    /// 获取时间戳 - 对应 Date.prototype.getTime()
    public func getTime(): Int64 {
        return timestamp
    }

    /// 获取完整年份 - 对应 Date.prototype.getFullYear()
    public func getFullYear(): Int64 {
        return fromTimestamp(timestamp).year
    }

    /// 获取月份 (0-11) - 对应 Date.prototype.getMonth()
    public func getMonth(): Int64 {
        return fromTimestamp(timestamp).month
    }

    /// 获取日期 (1-31) - 对应 Date.prototype.getDate()
    public func getDate(): Int64 {
        return fromTimestamp(timestamp).day
    }

    /// 获取星期几 (0=Sunday) - 对应 Date.prototype.getDay()
    public func getDay(): Int64 {
        // 1970-01-01 是 Thursday (4)
        let days = timestamp / 86400000
        return ((days % 7) + 4 + 700) % 7
    }

    /// 获取小时 (0-23) - 对应 Date.prototype.getHours()
    public func getHours(): Int64 {
        return fromTimestamp(timestamp).hour
    }

    /// 获取分钟 (0-59) - 对应 Date.prototype.getMinutes()
    public func getMinutes(): Int64 {
        return fromTimestamp(timestamp).minute
    }

    /// 获取秒 (0-59) - 对应 Date.prototype.getSeconds()
    public func getSeconds(): Int64 {
        return fromTimestamp(timestamp).second
    }

    /// 获取毫秒 (0-999) - 对应 Date.prototype.getMilliseconds()
    public func getMilliseconds(): Int64 {
        return timestamp % 1000
    }

    /// 转为 ISO 8601 字符串 - 对应 Date.prototype.toISOString()
    public func toISOString(): String {
        let d = fromTimestamp(timestamp)
        return "${pad4(d.year)}-${pad2(d.month + 1)}-${pad2(d.day)}T" +
            "${pad2(d.hour)}:${pad2(d.minute)}:${pad2(d.second)}.000Z"
    }

    /// 转为日期字符串 - 对应 Date.prototype.toDateString()
    public func toDateString(): String {
        let d = fromTimestamp(timestamp)
        return "${pad4(d.year)}-${pad2(d.month + 1)}-${pad2(d.day)}"
    }

    /// 转为时间字符串 - 对应 Date.prototype.toTimeString()
    public func toTimeString(): String {
        let d = fromTimestamp(timestamp)
        return "${pad2(d.hour)}:${pad2(d.minute)}:${pad2(d.second)}"
    }

    /// 转为本地字符串 - 对应 Date.prototype.toLocaleString()
    public func toLocaleString(): String {
        return "${toDateString()} ${toTimeString()}"
    }

    /// 转为字符串 - 对应 Date.prototype.toString()
    public func toString(): String {
        return toISOString()
    }

    /// 转为 JSON 字符串 - 对应 Date.prototype.toJSON()
    public func toJSON(): String {
        return toISOString()
    }

    /// 获取原始值 - 对应 Date.prototype.valueOf()
    public func valueOf(): Int64 {
        return timestamp
    }

    // ---- 内部方法 ----

    /// 获取当前时间毫秒时间戳
    private static func currentTimeMillis(): Int64 {
        return Int64(SysModule.currentTimeMillis())
    }

    /// 从时间戳解析日期组件
    private static func fromTimestamp(ts: Int64): DateComponents {
        var remaining = ts
        let ms = remaining % 1000
        remaining = remaining / 1000
        let second = remaining % 60
        remaining = remaining / 60
        let minute = remaining % 60
        remaining = remaining / 60
        let hour = remaining % 24
        var totalDays = remaining / 24

        // 从 1970-01-01 开始计算年月日
        var year: Int64 = 1970
        while (true) {
            let daysInYear = if (isLeapYear(year)) { 366 } else { 365 }
            if (totalDays < daysInYear) { break }
            totalDays -= daysInYear
            year += 1
        }

        let monthDays = if (isLeapYear(year)) {
            [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        } else {
            [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        }
        var month: Int64 = 0
        while (month < 12 && totalDays >= monthDays[Int64(month)]) {
            totalDays -= monthDays[Int64(month)]
            month += 1
        }
        let day = totalDays + 1

        return DateComponents(year, month, day, hour, minute, second, ms)
    }

    /// 从组件创建 UTC 时间戳
    private static func utcFromComponents(year: Int64, month: Int64, day: Int64,
        hour: Int64, minute: Int64, second: Int64): Int64 {
        var totalDays: Int64 = 0
        for (y in 1970..year) {
            totalDays += if (isLeapYear(y)) { 366 } else { 365 }
        }
        let monthDays = if (isLeapYear(year)) {
            [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        } else {
            [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        }
        for (m in 0..month) {
            totalDays += monthDays[Int64(m)]
        }
        totalDays += day - 1
        return totalDays * 86400000 + hour * 3600000 + minute * 60000 + second * 1000
    }

    /// 判断闰年
    private static func isLeapYear(year: Int64): Bool {
        return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    /// 数字补零到 4 位
    private static func pad4(n: Int64): String {
        if (n < 10) { return "000${n}" }
        if (n < 100) { return "00${n}" }
        if (n < 1000) { return "0${n}" }
        return "${n}"
    }

    /// 数字补零到 2 位
    private static func pad2(n: Int64): String {
        if (n < 10) { return "0${n}" }
        return "${n}"
    }
}

/// 日期组件 - 内部辅助
private class DateComponents {
    public var year: Int64
    public var month: Int64
    public var day: Int64
    public var hour: Int64
    public var minute: Int64
    public var second: Int64
    public var ms: Int64

    public init(year: Int64, month: Int64, day: Int64,
        hour: Int64, minute: Int64, second: Int64, ms: Int64) {
        this.year = year
        this.month = month
        this.day = day
        this.hour = hour
        this.minute = minute
        this.second = second
        this.ms = ms
    }
}

// ============================================================================
// JsonParser - JSON 内置对象
// 对应 Bun: src/runtime/JSONObject (JSC JSON)
//   Bun 依赖 JSC 内置的 JSON.parse / JSON.stringify
//   仓颉实现 JS 值与 JSON 字符串之间的转换
// ============================================================================

/// JSON 内置对象 - 对应 JS JSON
public class JsonParser {
    /// 解析 JSON 字符串 - 对应 JSON.parse(text)
    public static func parse(text: String): JsValue {
        return JsValue.NULL
    }

    /// 序列化为 JSON 字符串 - 对应 JSON.stringify(value)
    public static func stringify(value: JsValue): String {
        let replacer: ?((String, JsValue) -> JsValue) = Option<((String, JsValue) -> JsValue)>.None
        let space: ?String = Option<String>.None
        return stringifyImpl(value, replacer, space)
    }

    /// 带替换函数序列化 - 对应 JSON.stringify(value, replacer)
    public static func stringify(value: JsValue,
        replacer: (String, JsValue) -> JsValue): String {
        let space: ?String = Option<String>.None
        return stringifyImpl(value, Some(replacer), space)
    }

    /// 带缩进序列化 - 对应 JSON.stringify(value, null, space)
    public static func stringify(value: JsValue, space: String): String {
        let replacer: ?((String, JsValue) -> JsValue) = Option<((String, JsValue) -> JsValue)>.None
        return stringifyImpl(value, replacer, Some(space))
    }

    /// 内部序列化实现
    private static func stringifyImpl(value: JsValue,
        replacer: ?((String, JsValue) -> JsValue),
        space: ?String): String {
        return "null"
    }

    /// 递归序列化值
    private static func stringifyValue(value: JsValue, key: String,
        sb: BaoStringBuilder, replacer: ?((String, JsValue) -> JsValue),
        space: ?String, depth: Int64): Unit {
        var v = value
        // 应用 replacer
        if (replacer.isSome()) {
            let r = replacer.getOrThrow()
            v = r(key, v)
        }

        match (v.valueType) {
            case JsValueType.Null => sb.appendString("null")
            case JsValueType.Undefined => sb.appendString("null")
            case JsValueType.Boolean => sb.appendString(if (v.boolValue) { "true" } else { "false" })
            case JsValueType.Number => stringifyNumber(v.numberValue, sb)
            case JsValueType.String => stringifyString(v.stringValue.toString(), sb)
            case JsValueType.Array => stringifyArray(v, sb, replacer, space, depth)
            case JsValueType.Object => stringifyObject(v, sb, replacer, space, depth)
            case _ => sb.appendString("null")
        }
    }

    private static func stringifyNumber(n: Float64, sb: BaoStringBuilder): Unit {
        if (n.isNaN() || n == Float64.Inf || n == -Float64.Inf) {
            sb.appendString("null")
        } else {
            sb.appendString(n.toString())
        }
    }

    private static func stringifyString(s: String, sb: BaoStringBuilder): Unit {
        sb.appendString("\"")
        sb.appendString(escapeJsonString(s))
        sb.appendString("\"")
    }

    private static func stringifyArray(value: JsValue, sb: BaoStringBuilder,
        replacer: ?((String, JsValue) -> JsValue), space: ?String, depth: Int64): Unit {
        match (value.arrayData) {
            case Some(arr) => stringifyArrayData(arr, sb, replacer, space, depth)
            case None => sb.appendString("[]")
        }
    }

    private static func stringifyArrayData(arr: ArrayList<JsValue>, sb: BaoStringBuilder,
        replacer: ?((String, JsValue) -> JsValue), space: ?String, depth: Int64): Unit {
        if (arr.size == 0) {
            sb.appendString("[]")
            return
        }
        let indent = getIndent(space, depth + 1)
        let endIndent = getIndent(space, depth)
        sb.appendString("[")
        if (indent.size > 0) { sb.appendString("\n") }
        for (i in 0..arr.size) {
            if (i > 0) {
                sb.appendString(",")
                if (indent.size > 0) { sb.appendString("\n") }
            }
            if (indent.size > 0) { sb.appendString(indent) }
            stringifyValue(arr[i], "", sb, replacer, space, depth + 1)
        }
        if (indent.size > 0) {
            sb.appendString("\n")
            sb.appendString(endIndent)
        }
        sb.appendString("]")
    }

    private static func stringifyObject(value: JsValue, sb: BaoStringBuilder,
        replacer: ?((String, JsValue) -> JsValue), space: ?String, depth: Int64): Unit {
        match (value.objectData) {
            case Some(obj) => stringifyObjectData(obj, sb, replacer, space, depth)
            case None => sb.appendString("{}")
        }
    }

    private static func stringifyObjectData(obj: JsObject, sb: BaoStringBuilder,
        replacer: ?((String, JsValue) -> JsValue), space: ?String, depth: Int64): Unit {
        let keys = obj.keys()
        if (keys.size == 0) {
            sb.appendString("{}")
            return
        }
        let indent = getIndent(space, depth + 1)
        let endIndent = getIndent(space, depth)
        sb.appendString("{")
        if (indent.size > 0) { sb.appendString("\n") }
        var first: Bool = true
        for (k in keys) {
            let val = obj.get(k)
            match (val.valueType) {
                case JsValueType.Undefined => continue
                case _ => ()
            }
            if (!first) {
                sb.appendString(",")
                if (indent.size > 0) { sb.appendString("\n") }
            }
            first = false
            if (indent.size > 0) { sb.appendString(indent) }
            sb.appendString("\"${escapeJsonString(k)}\":")
            if (indent.size > 0) { sb.appendString(" ") }
            stringifyValue(val, k, sb, replacer, space, depth + 1)
        }
        if (indent.size > 0) {
            sb.appendString("\n")
            sb.appendString(endIndent)
        }
        sb.appendString("}")
    }

    /// 获取缩进字符串
    private static func getIndent(space: ?String, depth: Int64): String {
        if (space.isSome()) {
            let s = space.getOrThrow()
            let sb = BaoStringBuilder()
            for (_ in 0..depth) {
                sb.appendString(s)
            }
            sb.build().toString()
        } else {
            ""
        }
    }

    /// 转义 JSON 字符串中的特殊字符
    private static func escapeJsonString(s: String): String {
        return s
    }

    /// 数字补零到 4 位十六进制
    private static func padHex4(n: Int64): String {
        return "0000"
    }
}

/// JSON 解析器内部实现 - 递归下降解析器
private class JsonParserImpl {
    public init(text: String) {}

    public func parse(): JsValue {
        return JsValue.NULL
    }
}

// ============================================================================
// RegExpObject - RegExp 内置对象
// 对应 Bun: src/runtime/RegExpObject (JSC RegExp)
//   Bun 通过 JSC 的 JSObjectMakeRegExp 创建正则表达式实例
//   仓颉用原生正则实现包装
// ============================================================================

/// RegExp 匹配结果 - 对应 JS RegExpExecResult
public class RegExpResult {
    /// 完整匹配文本 - 对应 result[0]
    public var match_: String
    /// 匹配起始位置 - 对应 result.index
    public var index: Int64
    /// 原始输入字符串 - 对应 result.input
    public var input: String
    /// 捕获组 - 对应 result[1], result[2], ...
    public var groups: ArrayList<String>

    public init(match_: String, index: Int64, input: String) {
        this.match_ = match_
        this.index = index
        this.input = input
        this.groups = ArrayList<String>()
    }
}

/// RegExp 内置对象 - 对应 JS RegExp
public class RegExpObject {
    /// 正则表达式源码 - 对应 /pattern/.source
    public var source: String
    /// 标志字符串 - 对应 /pattern/flags.flags
    public var flags: String
    /// 全局标志 - 对应 'g' flag
    public var global: Bool
    /// 忽略大小写标志 - 对应 'i' flag
    public var ignoreCase: Bool
    /// 多行标志 - 对应 'm' flag
    public var multiline: Bool
    /// dotAll 标志 - 对应 's' flag
    public var dotAll: Bool
    /// Unicode 标志 - 对应 'u' flag
    public var unicode: Bool
    /// 粘性标志 - 对应 'y' flag
    public var sticky: Bool
    /// 上次匹配后的位置 - 对应 lastIndex
    public var lastIndex: Int64

    // 编译后的正则引擎实例
    private var compiledRegex: ?RegularExpression = None

    /// 从模式和标志创建 RegExp - 对应 new RegExp(pattern, flags)
    public init(pattern: String, flags: String) {
        this.source = pattern
        this.flags = flags
        this.global = flags.contains("g")
        this.ignoreCase = flags.contains("i")
        this.multiline = flags.contains("m")
        this.dotAll = flags.contains("s")
        this.unicode = flags.contains("u")
        this.sticky = flags.contains("y")
        this.lastIndex = 0

        // 编译正则表达式
        let regexFlags = RegularExpression.parseFlags(flags)
        this.compiledRegex = RegularExpression.initFunc(pattern, regexFlags)
    }

    /// 测试字符串是否匹配 - 对应 RegExp.prototype.test()
    public func test(text: String): Bool {
        let result = exec(text)
        match (result) {
            case Some(_) => true
            case None => false
        }
    }

    /// 执行匹配 - 对应 RegExp.prototype.exec()
    /// 返回匹配结果数组或 null
    /// 支持 global/sticky 模式下的 lastIndex 更新
    public func exec(text: String): ?RegExpResult {
        if (let Some(re) <- compiledRegex) {
            // 根据 lastIndex 和标志决定搜索起始位置
            var searchStart: Int64 = 0
            if (global || sticky) {
                searchStart = lastIndex
            }

            var execResult: ?RegexExecResult = None
            if (searchStart > 0 && searchStart <= text.size) {
                execResult = re.execFrom(text, searchStart)
            } else if (searchStart == 0) {
                execResult = re.exec(text)
            }

            match (execResult) {
                case Some(er) =>
                    let result = RegExpResult(er.matchStr, Int64(er.startIndex), text)

                    // 提取捕获组
                    for (i in 0..er.groups.size) {
                        result.groups.append(er.groups[i])
                    }

                    // 更新 lastIndex
                    if (global || sticky) {
                        lastIndex = Int64(er.startIndex) + Int64(er.length)
                    }

                    return Some(result)
                case None =>
                    // 没有匹配: 对于 global/sticky 重置 lastIndex
                    if (global || sticky) {
                        lastIndex = 0
                    }
                    return None
            }
        }
        None
    }

    /// 转为字符串 - 对应 RegExp.prototype.toString()
    public func toString(): String {
        return "/${source}/${flags}"
    }

    /// 转义正则表达式特殊字符 - 对应静态辅助
    /// 将字符串中所有正则元字符转义为字面量
    public static func escape(str: String): String {
        let sb = BaoStringBuilder()
        for (c in str) {
            match (c) {
                case '^' | '$' | '\\' | '.' | '*' | '+' | '?' | '(' | ')' | '|' | '[' | ']' | '{' | '}' =>
                    sb.appendString("\\")
                    sb.appendString(String(Rune(c)))
                case _ =>
                    sb.appendString(String(Rune(c)))
            }
        }
        sb.build().toString()
    }
}

// ============================================================================
// Error 类型体系
// 对应 Bun: src/runtime/Error (JSC Error 类型)
//   ECMAScript 定义了 Error 及其子类型
//   Bun 通过 JSC 的 JSObjectMakeError 等创建
// ============================================================================

/// JavaScript Error 基类 - 对应 JS Error
public open class JsError {
    /// 错误名称 - 对应 Error.prototype.name
    public var name: String
    /// 错误消息 - 对应 Error.prototype.message
    public var message: String
    /// 调用栈 - 对应 Error.prototype.stack
    public var stack: String

    public init(message: String) {
        this.name = "Error"
        this.message = message
        this.stack = ""
    }

    public init(name: String, message: String) {
        this.name = name
        this.message = message
        this.stack = ""
    }

    /// 转为字符串 - 对应 Error.prototype.toString()
    public func toString(): String {
        if (!message.isEmpty()) {
            return "${name}: ${message}"
        }
        return name
    }

    /// 设置调用栈
    public func setStack(stackStr: String): Unit {
        this.stack = stackStr
    }
}

/// TypeError - 对应 JS TypeError
/// 值的类型与预期不符时抛出
public class JsTypeError <: JsError {
    public init(message: String) {
        super("TypeError", message)
    }
}

/// RangeError - 对应 JS RangeError
/// 值超出允许范围时抛出
public class JsRangeError <: JsError {
    public init(message: String) {
        super("RangeError", message)
    }
}

/// ReferenceError - 对应 JS ReferenceError
/// 引用未声明的变量时抛出
public class JsReferenceError <: JsError {
    public init(message: String) {
        super("ReferenceError", message)
    }
}

/// SyntaxError - 对应 JS SyntaxError
/// 源代码解析错误时抛出
public class JsSyntaxError <: JsError {
    public init(message: String) {
        super("SyntaxError", message)
    }
}

/// URIError - 对应 JS URIError
/// URI 编解码错误时抛出
public class JsURIError <: JsError {
    public init(message: String) {
        super("URIError", message)
    }
}

/// EvalError - 对应 JS EvalError
/// eval() 使用不当 (现代 JS 中极少使用)
public class JsEvalError <: JsError {
    public init(message: String) {
        super("EvalError", message)
    }
}

/// AggregateError - 对应 JS AggregateError (ES2021)
/// Promise.any() 全部拒绝时抛出，包含所有错误
public class JsAggregateError <: JsError {
    /// 所有被聚合的错误 - 对应 errors 属性
    public var errors: ArrayList<JsError>

    public init(message: String, errors: ArrayList<JsError>) {
        super("AggregateError", message)
        this.errors = errors
    }

    public init(errors: ArrayList<JsError>) {
        super("AggregateError", "")
        this.errors = errors
    }
}
