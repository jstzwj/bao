// 严格翻译自: src/jsc/JSBigInt.zig (45行)
// JavaScriptCore JSBigInt 类型绑定

package bao_jsc

// ========== JSBigInt ==========
// 严格翻译自 JSBigInt.zig
// JSBigInt 是 JavaScript BigInt 原始类型的 JSC 绑定
// 在 JSC 中，BigInt 有两种编码方式:
//   - HeapBigInt: 堆分配的大整数 (用于超大数值)
//   - BigInt32: 内联编码的 32 位整数 (NaN-boxing 优化)
// 这里用字符串表示内部值，提供完整的操作接口
public class JsBigInt {
    // 内部值存储 (十进制字符串表示)
    public var value: String = "0"

    public init() {}

    public init(value: String) {
        this.value = value
    }

    public init(value: Int64) {
        this.value = value.toString()
    }

    public init(value: UInt64) {
        this.value = value.toString()
    }

    // ========== FFI 绑定 ==========
    // 严格翻译自 JSBigInt.fromJS
    // 从 JsValue 中提取 JSBigInt (如果它是 BigInt 类型)
    public static func fromJS(value: JsValue): ?JsBigInt {
        if (value.isBigInt()) {
            return JsBigInt(value.bigIntValue)
        }
        None
    }

    // ========== 比较操作 ==========
    // 严格翻译自 JSBigInt.orderDouble
    // 比较 BigInt 与 double 值
    // 返回: -1 (this < num), 0 (this == num), 1 (this > num)
    public func orderDouble(num: Float64): Int8 {
        // 特殊处理 NaN
        if (num != num) {
            return 1  // BigInt > NaN
        }
        // 尝试将 BigInt 转为 double 比较
        let bigNum = parseBigIntToDouble(value)
        if (bigNum < num) { return -1 }
        if (bigNum > num) { return 1 }
        0
    }

    // 严格翻译自 JSBigInt.orderUint64
    // 比较 BigInt 与 UInt64 值
    public func orderUint64(num: UInt64): Int8 {
        let cmp = compareBigIntWithUInt64(value, num)
        cmp
    }

    // 严格翻译自 JSBigInt.orderInt64
    // 比较 BigInt 与 Int64 值
    public func orderInt64(num: Int64): Int8 {
        let cmp = compareBigIntWithInt64(value, num)
        cmp
    }

    // 严格翻译自 JSBigInt.order (泛型版本)
    // 统一的比较入口
    public func order(num: Float64): Int8 {
        orderDouble(num)
    }

    public func order(num: Int64): Int8 {
        orderInt64(num)
    }

    public func order(num: UInt64): Int8 {
        orderUint64(num)
    }

    // ========== 类型转换 ==========
    // 严格翻译自 JSBigInt.toInt64
    // 将 BigInt 转为 Int64 (截断)
    public func toInt64(): Int64 {
        // Simple parse: try to convert string to Int64
        var result: Int64 = 0
        var negative = false
        for (c in value) {
            let b = UInt8(c)
            if (b == 45 && result == 0) { negative = true; continue }  // '-'
            if (b >= 48 && b <= 57) {  // '0'-'9'
                result = result * 10 + Int64(b - 48)
            }
        }
        if (negative) { result = -result }
        result
    }

    // 严格翻译自 JSBigInt.toString
    // 将 BigInt 转为字符串
    public func toString(): String {
        value
    }

    // 转为 JsValue
    public func toJsValue(): JsValue {
        let v = JsValue()
        v.valueType = JsValueType.BigInt
        v.bigIntValue = value
        v
    }

    // ========== 算术操作 ==========

    // 严格翻译自 JSValue.bigIntSum
    // BigInt 加法
    public static func add(a: JsBigInt, b: JsBigInt): JsBigInt {
        let result = addBigIntStrings(a.value, b.value)
        JsBigInt(result)
    }

    // 严格翻译自 JSValue.fromInt64NoTruncate
    // 从 Int64 创建 BigInt (不截断)
    public static func fromInt64NoTruncate(value: Int64): JsBigInt {
        JsBigInt(value)
    }

    // 严格翻译自 JSValue.fromUInt64NoTruncate
    // 从 UInt64 创建 BigInt (不截断)
    public static func fromUInt64NoTruncate(value: UInt64): JsBigInt {
        JsBigInt(value.toString())
    }

    // ========== 辅助方法 ==========

    // 将 BigInt 字符串解析为 double
    // 对应 Bun: JSC__JSBigInt__toDouble FFI 调用的纯仓颉实现
    static func parseBigIntToDouble(s: String): Float64 {
        if (s.isEmpty) { return 0.0 }
        var result: Float64 = 0.0
        var negative = false
        var i = 0
        // 跳过前导空格
        while (i < s.size && (s[i] == ' ')) { i++ }
        if (i < s.size && s[i] == '-') { negative = true; i++ }
        else if (i < s.size && s[i] == '+') { i++ }
        // 整数部分
        while (i < s.size) {
            let c = s[i]
            if (c >= '0' && c <= '9') {
                result = result * 10.0 + Float64(Int64(c) - Int64('0'))
                i++
            } else if (c == '.') {
                i++
                break
            } else {
                break
            }
        }
        // 小数部分 (BigInt 理论上无小数, 但解析时兼容)
        var fraction: Float64 = 0.1
        while (i < s.size) {
            let c = s[i]
            if (c >= '0' && c <= '9') {
                result += Float64(Int64(c) - Int64('0')) * fraction
                fraction *= 0.1
                i++
            } else {
                break
            }
        }
        if (negative) { result = -result }
        result
    }

    // 比较 BigInt 字符串与 UInt64
    // 对应 Bun: JSC__JSBigInt__orderUint64 FFI 调用
    static func compareBigIntWithUInt64(bigIntStr: String, num: UInt64): Int8 {
        if (bigIntStr.size > 0 && bigIntStr[0] == '-') {  // 负数 < 任何 UInt64
            return -1
        }
        // 尝试解析为 UInt64 进行精确比较
        var parsed: UInt64 = 0
        var overflow = false
        for (c in bigIntStr) {
            if (c >= '0' && c <= '9') {
                let digit = UInt64(Int64(c) - Int64('0'))
                if (parsed > (UInt64.MAX - digit) / 10) {
                    overflow = true
                    break
                }
                parsed = parsed * 10 + digit
            }
        }
        if (overflow) {
            // 字符串表示的值超过 UInt64 范围, 一定大于 num
            return 1
        }
        if (parsed < num) { return -1 }
        if (parsed > num) { return 1 }
        0
    }

    // 比较 BigInt 字符串与 Int64
    // 对应 Bun: JSC__JSBigInt__orderInt64 FFI 调用
    static func compareBigIntWithInt64(bigIntStr: String, num: Int64): Int8 {
        var negative = false
        var start = 0
        if (bigIntStr.size > 0 && bigIntStr[0] == '-') {
            negative = true
            start = 1
        }
        var parsed: Int64 = 0
        var overflow = false
        for (i in start..bigIntStr.size) {
            let c = bigIntStr[i]
            if (c >= '0' && c <= '9') {
                let digit = Int64(Int64(c) - Int64('0'))
                if (parsed > (Int64.MAX - digit) / 10) {
                    overflow = true
                    break
                }
                parsed = parsed * 10 + digit
            }
        }
        if (negative) { parsed = -parsed }
        if (overflow) {
            // 超出 Int64 范围, 用 double 近似比较
            let d = parseBigIntToDouble(bigIntStr)
            let n = Float64(num)
            if (d < n) { return -1 }
            if (d > n) { return 1 }
            return 0
        }
        if (parsed < num) { return -1 }
        if (parsed > num) { return 1 }
        0
    }

    // BigInt 字符串加法
    // 实现真正的十进制大整数加法
    static func addBigIntStrings(a: String, b: String): String {
        // 处理负数
        if (a.size > 0 && a[0] == '-') {
            if (b.size > 0 && b[0] == '-') {
                // (-a) + (-b) = -(a+b)
                return "-" + addPositiveStrings(a.substring(1), b.substring(1))
            } else {
                // (-a) + b = b - a
                return subtractBigIntStrings(b, a.substring(1))
            }
        }
        if (b.size > 0 && b[0] == '-') {
            // a + (-b) = a - b
            return subtractBigIntStrings(a, b.substring(1))
        }
        return addPositiveStrings(a, b)
    }

    // 两个正整数字符串相加
    static func addPositiveStrings(a: String, b: String): String {
        var i = Int64(a.size) - 1
        var j = Int64(b.size) - 1
        var carry = 0
        var result = Array<UInt8>()
        while (i >= 0 || j >= 0 || carry > 0) {
            var sum = carry
            if (i >= 0) {
                sum += Int32(a[Int64(i)]) - Int32('0')
                i--
            }
            if (j >= 0) {
                sum += Int32(b[Int64(j)]) - Int32('0')
                j--
            }
            carry = sum / 10
            result.append(UInt8(sum % 10 + Int32('0')))
        }
        // 反转结果
        var sb = StringBuilder()
        for (k in (result.size - 1)..0..>(-1)) {
            sb.append(Char(result[k]))
        }
        if (sb.toString().isEmpty) { "0" }
        else { sb.toString() }
    }

    // 两个正整数字符串相减 (假设 a >= b)
    static func subtractBigIntStrings(a: String, b: String): String {
        // 先比较大小
        let cmp = comparePositiveStrings(a, b)
        if (cmp == 0) { return "0" }
        if (cmp < 0) {
            return "-" + subtractPositiveStrings(b, a)
        }
        return subtractPositiveStrings(a, b)
    }

    // 比较两个正整数字符串
    static func comparePositiveStrings(a: String, b: String): Int8 {
        let aLen = a.size
        let bLen = b.size
        if (aLen != bLen) {
            return if (aLen < bLen) { Int8(-1) } else { Int8(1) }
        }
        for (i in 0..aLen) {
            if (a[i] != b[i]) {
                return if (a[i] < b[i]) { Int8(-1) } else { Int8(1) }
            }
        }
        0
    }

    // 正整数字符串相减, 保证 a >= b
    static func subtractPositiveStrings(a: String, b: String): String {
        var i = Int64(a.size) - 1
        var j = Int64(b.size) - 1
        var borrow = 0
        var result = Array<UInt8>()
        while (i >= 0) {
            var diff = Int32(a[Int64(i)]) - Int32('0') - borrow
            if (j >= 0) {
                diff -= Int32(b[Int64(j)]) - Int32('0')
                j--
            }
            if (diff < 0) {
                diff += 10
                borrow = 1
            } else {
                borrow = 0
            }
            result.append(UInt8(diff + Int32('0')))
            i--
        }
        // 反转并去除前导零
        var sb = StringBuilder()
        var leadingZero = true
        for (k in (result.size - 1)..0..>(-1)) {
            if (leadingZero && result[k] == UInt8('0')) { continue }
            leadingZero = false
            sb.append(Char(result[k]))
        }
        if (sb.toString().isEmpty) { "0" }
        else { sb.toString() }
    }
}
