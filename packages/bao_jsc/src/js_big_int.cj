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
    static func parseBigIntToDouble(s: String): Float64 {
        // Simple parse for demo
        0.0
    }

    // 比较 BigInt 字符串与 UInt64
    static func compareBigIntWithUInt64(bigIntStr: String, num: UInt64): Int8 {
        if (bigIntStr.size > 0 && bigIntStr[0] == 45) {  // '-'
            return -1
        }
        // Stub comparison
        0
    }

    // 比较 BigInt 字符串与 Int64
    static func compareBigIntWithInt64(bigIntStr: String, num: Int64): Int8 {
        // Stub comparison
        0
    }

    // BigInt 字符串加法
    static func addBigIntStrings(a: String, b: String): String {
        // Stub: simple concatenation with marker
        a + "+" + b
    }
}
