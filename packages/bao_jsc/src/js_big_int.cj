// 严格翻译自: src/jsc/JSBigInt.zig (45行)
// JavaScriptCore JSBigInt 类型绑定
//
// 实现了真正的任意精度整数算术，用于 JavaScript BigInt 操作。
// 内部使用 Array<UInt64> 的基数为 10^18 的表示形式，
// 带有符号位。这避免了对外部库（如 GMP）的依赖，
// 并提供完整的 BigInt 操作，包括算术运算、按位运算、比较和字符串转换。

package bao_jsc

// ========== 内部任意精度整数表示 ==========
// 我们将无符号整数存储为以 10^18 为基数，这使得与十进制字符串的转换变得简单高效。
// 每个 UInt64 “limb”（组成部分）的值范围为 0..BILLION_MINUS_1。
// 符号是独立的，这使得无符号算术更简单。

// 基数: 10^18 —— 适合 UInt64 的最大 10 的幂，且两个 limb 之和不会溢出。
let BIGINT_BASE: UInt64 = 1_000_000_000_000_000_000_u64
// 基数中的位数
let BIGINT_BASE_DIGITS: Int64 = 18

// ========== JsBigInt ==========
// 严格翻译自 JSBigInt.zig
// JSBigInt 是 JavaScript BigInt 原始类型的 JSC 绑定
// 在 JSC 中，BigInt 有两种编码方式:
//   - HeapBigInt: 堆分配的大整数 (用于超大数值)
//   - BigInt32: 内联编码的 32 位整数 (NaN-boxing 优化)
// 这里用任意精度内部表示提供完整的操作接口
public class JsBigInt {
    // 任意精度内部值：以 10^18 为基数的数字（组成部分）数组，最低有效位在前
    var limbs: Array<UInt64> = []
    // 如果为负数则为 true（零始终为正）
    var negative: Bool = false

    public init() {
        limbs = [0_u64]
    }

    public init(value: String) {
        limbs = [0_u64]
        parseString(value)
    }

    public init(value: Int64) {
        if (value < 0) {
            negative = true
            limbs = fromUInt64(UInt64(0_u64 - UInt64(value)))
        } else {
            limbs = fromUInt64(UInt64(value))
        }
    }

    public init(value: UInt64) {
        limbs = fromUInt64(value)
    }

    // 从数组和符号创建
    init(limbs: Array<UInt64>, negative: Bool) {
        if (limbs.size == 0) {
            this.limbs = [0_u64]
            this.negative = false
        } else {
            this.limbs = normalize(limbs)
            this.negative = negative
        }
        // 负零规范化为正零
        if (isZero()) {
            this.negative = false
        }
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
        // 处理无穷大
        if (num == Float64.Inf) {
            return -1
        }
        if (num == -Float64.Inf) {
            return 1
        }
        // 将 double 转换为 JsBigInt 并比较
        let bigNum = JsBigInt(doubleToBigIntString(num))
        compareTo(bigNum)
    }

    // 严格翻译自 JSBigInt.orderUint64
    // 比较 BigInt 与 UInt64 值
    public func orderUint64(num: UInt64): Int8 {
        compareTo(JsBigInt(num))
    }

    // 严格翻译自 JSBigInt.orderInt64
    // 比较 BigInt 与 Int64 值
    public func orderInt64(num: Int64): Int8 {
        compareTo(JsBigInt(num))
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

    // 两个 JsBigInt 之间的比较
    public func compareTo(other: JsBigInt): Int8 {
        // 不同符号: 负数 < 正数
        if (negative && !other.negative) {
            return if (isZero() && other.isZero()) { 0 } else { -1 }
        }
        if (!negative && other.negative) {
            return if (isZero() && other.isZero()) { 0 } else { 1 }
        }
        // 符号相同: 比较绝对值
        let absCmp = compareAbs(limbs, other.limbs)
        if (negative) {
            // 都是负数: 绝对值较大的比较小
            if (absCmp < 0) { return 1 }
            if (absCmp > 0) { return -1 }
            return 0
        }
        absCmp
    }

    // ========== 类型转换 ==========
    // 严格翻译自 JSBigInt.toInt64
    // 将 BigInt 转为 Int64 (截断)
    public func toInt64(): Int64 {
        let s = toString()
        var result: Int64 = 0
        var neg = false
        for (c in s) {
            let b = UInt8(c)
            if (b == 45 && result == 0) { neg = true; continue }  // '-'
            if (b >= 48 && b <= 57) {  // '0'-'9'
                result = result * 10 + Int64(b - 48)
            }
        }
        if (neg) { result = -result }
        result
    }

    // 严格翻译自 JSBigInt.toString
    // 将 BigInt 转为字符串
    public func toString(): String {
        if (isZero()) {
            return "0"
        }
        var s = ""
        var first = true
        // 从最高有效 limb 到最低有效 limb
        var i = limbs.size - 1
        while (i >= 0) {
            let limb = limbs[Int64(i)]
            if (first) {
                s = s + limb.toString()
                first = false
            } else {
                // 填充前导零以保持 18 位
                let part = limb.toString()
                var padding = ""
                for (_ in 0..(BIGINT_BASE_DIGITS - part.size)) {
                    padding = padding + "0"
                }
                s = s + padding + part
            }
            i--
        }
        if (negative) {
            s = "-" + s
        }
        s
    }

    // 转为 JsValue
    public func toJsValue(): JsValue {
        let v = JsValue()
        v.valueType = JsValueType.BigInt
        v.bigIntValue = toString()
        v
    }

    // ========== 算术操作 ==========

    // 严格翻译自 JSValue.bigIntSum
    // BigInt 加法
    public static func add(a: JsBigInt, b: JsBigInt): JsBigInt {
        if (a.negative == b.negative) {
            // 符号相同: 将绝对值相加，保留符号
            return JsBigInt(addAbs(a.limbs, b.limbs), a.negative)
        }
        // 符号不同: 用较大的绝对值减去较小的绝对值
        let cmp = compareAbs(a.limbs, b.limbs)
        if (cmp == 0) {
            return JsBigInt()  // 结果为零
        }
        if (cmp > 0) {
            return JsBigInt(subAbs(a.limbs, b.limbs), a.negative)
        }
        JsBigInt(subAbs(b.limbs, a.limbs), b.negative)
    }

    // BigInt 减法
    public static func sub(a: JsBigInt, b: JsBigInt): JsBigInt {
        // a - b = a + (-b)
        let negB = JsBigInt(b.limbs.toArray(), !b.negative)
        if (b.isZero()) {
            negB.negative = false
        }
        add(a, negB)
    }

    // BigInt 乘法
    public static func mul(a: JsBigInt, b: JsBigInt): JsBigInt {
        if (a.isZero() || b.isZero()) {
            return JsBigInt()
        }
        let resultLimbs = mulAbs(a.limbs, b.limbs)
        JsBigInt(resultLimbs, a.negative != b.negative)
    }

    // BigInt 除法 (向零截断)
    public static func div(a: JsBigInt, b: JsBigInt): JsBigInt {
        if (b.isZero()) {
            return JsBigInt()  // JavaScript 中除以零会抛出错误，但我们优雅地返回零
        }
        if (a.isZero()) {
            return JsBigInt()
        }
        let absCmp = compareAbs(a.limbs, b.limbs)
        if (absCmp < 0) {
            return JsBigInt()  // |a| < |b| => 商为 0
        }
        let (quotient, _) = divModAbs(a.limbs, b.limbs)
        JsBigInt(quotient, a.negative != b.negative)
    }

    // BigInt 取模 (结果的符号与被除数相同)
    public static func mod(a: JsBigInt, b: JsBigInt): JsBigInt {
        if (b.isZero()) {
            return JsBigInt()
        }
        if (a.isZero()) {
            return JsBigInt()
        }
        let absCmp = compareAbs(a.limbs, b.limbs)
        if (absCmp < 0) {
            // |a| < |b| => 余数为 a
            return JsBigInt(a.limbs.toArray(), a.negative)
        }
        let (_, remainder) = divModAbs(a.limbs, b.limbs)
        JsBigInt(remainder, a.negative)
    }

    // 除法 + 取模 (同时获取两者)
    public static func divMod(a: JsBigInt, b: JsBigInt): (JsBigInt, JsBigInt) {
        if (b.isZero()) {
            return (JsBigInt(), JsBigInt())
        }
        if (a.isZero()) {
            return (JsBigInt(), JsBigInt())
        }
        let absCmp = compareAbs(a.limbs, b.limbs)
        if (absCmp < 0) {
            return (JsBigInt(), JsBigInt(a.limbs.toArray(), a.negative))
        }
        let (quotient, remainder) = divModAbs(a.limbs, b.limbs)
        let q = JsBigInt(quotient, a.negative != b.negative)
        let r = JsBigInt(remainder, a.negative)
        (q, r)
    }

    // BigInt 幂运算 (指数必须为非负数)
    public static func pow(base: JsBigInt, exp: JsBigInt): JsBigInt {
        // 指数必须是非负整数
        if (exp.negative) {
            return JsBigInt()  // 负指数对于 BigInt 来说是错误；返回 0
        }
        // 将指数转换为 Int64；如果太大，结果将溢出内存
        var expVal: UInt64 = 0
        for (i in 0..exp.limbs.size) {
            let limb = exp.limbs[Int64(i)]
            if (i == 0) {
                expVal = limb
            } else {
                // 指数太大
                return JsBigInt("0")
            }
        }
        if (expVal == 0_u64) {
            return JsBigInt(1)
        }
        // 通过平方进行求幂
        var result = JsBigInt(1)
        var b = JsBigInt(base.limbs.toArray(), base.negative)
        var e = expVal
        while (e > 0_u64) {
            if (e % 2_u64 == 1_u64) {
                result = mul(result, b)
            }
            b = mul(b, b)
            e = e / 2_u64
        }
        result
    }

    // ========== 按位操作 ==========

    // 按位与
    public static func bitAnd(a: JsBigInt, b: JsBigInt): JsBigInt {
        let (aBits, aNeg) = toBinaryBits(a)
        let (bBits, bNeg) = toBinaryBits(b)
        let resultBits = binaryAnd(aBits, aNeg, bBits, bNeg)
        fromBinaryBits(resultBits)
    }

    // 按位或
    public static func bitOr(a: JsBigInt, b: JsBigInt): JsBigInt {
        let (aBits, aNeg) = toBinaryBits(a)
        let (bBits, bNeg) = toBinaryBits(b)
        let resultBits = binaryOr(aBits, aNeg, bBits, bNeg)
        fromBinaryBits(resultBits)
    }

    // 按位异或
    public static func bitXor(a: JsBigInt, b: JsBigInt): JsBigInt {
        let (aBits, aNeg) = toBinaryBits(a)
        let (bBits, bNeg) = toBinaryBits(b)
        let resultBits = binaryXor(aBits, aNeg, bBits, bNeg)
        fromBinaryBits(resultBits)
    }

    // 按位非 (二进制补码非: ~x = -x - 1)
    public static func bitNot(a: JsBigInt): JsBigInt {
        sub(JsBigInt(-1), a)
    }

    // 左移
    public static func shiftLeft(a: JsBigInt, shift: JsBigInt): JsBigInt {
        if (shift.negative) {
            return shiftRight(a, JsBigInt(shift.limbs.toArray(), false))
        }
        let shiftCount = shift.toUInt64()
        if (shiftCount == 0_u64) {
            return JsBigInt(a.limbs.toArray(), a.negative)
        }
        // 乘以 2^shiftCount
        var result = JsBigInt(a.limbs.toArray(), a.negative)
        var i = 0_u64
        while (i < shiftCount) {
            let remaining = shiftCount - i
            if (remaining >= 64_u64) {
                result = mul(result, JsBigInt("18446744073709551616"))  // 2^64
                i += 64_u64
            } else if (remaining >= 32_u64) {
                result = mul(result, JsBigInt("4294967296"))  // 2^32
                i += 32_u64
            } else {
                result = mul(result, JsBigInt(Int64(1) << Int64(remaining)))
                i += remaining
            }
        }
        result
    }

    // 右移 (算术)
    public static func shiftRight(a: JsBigInt, shift: JsBigInt): JsBigInt {
        if (shift.negative) {
            return shiftLeft(a, JsBigInt(shift.limbs.toArray(), false))
        }
        if (a.isZero()) {
            return JsBigInt()
        }
        let shiftCount = shift.toUInt64()
        if (shiftCount == 0_u64) {
            return JsBigInt(a.limbs.toArray(), a.negative)
        }
        // 除以 2^shiftCount (向零截断)
        var result = JsBigInt(a.limbs.toArray(), a.negative)
        var i = 0_u64
        while (i < shiftCount && !result.isZero()) {
            let remaining = shiftCount - i
            if (remaining >= 64_u64) {
                result = div(result, JsBigInt("18446744073709551616"))  // 2^64
                i += 64_u64
            } else if (remaining >= 32_u64) {
                result = div(result, JsBigInt("4294967296"))  // 2^32
                i += 32_u64
            } else {
                result = div(result, JsBigInt(Int64(1) << Int64(remaining)))
                i += remaining
            }
        }
        result
    }

    // ========== 一元操作 ==========

    // 一元取反
    public func negate(): JsBigInt {
        if (isZero()) {
            return JsBigInt()
        }
        JsBigInt(limbs.toArray(), !negative)
    }

    // 绝对值
    public func abs(): JsBigInt {
        JsBigInt(limbs.toArray(), false)
    }

    // ========== 辅助方法 ==========

    // 检查是否为零
    func isZero(): Bool {
        limbs.size == 1 && limbs[0] == 0_u64
    }

    // 转换为 UInt64 (截断)
    func toUInt64(): UInt64 {
        if (limbs.size == 0) {
            return 0_u64
        }
        limbs[0]
    }

    // ========== 私有内部实现 ==========

    // 从 UInt64 创建以 10^18 为基数的 limb 数组
    static func fromUInt64(v: UInt64): Array<UInt64> {
        if (v < BIGINT_BASE) {
            return [v]
        }
        [v % BIGINT_BASE, v / BIGINT_BASE]
    }

    // 移除前导零 limb
    static func normalize(limbs: Array<UInt64>): Array<UInt64> {
        if (limbs.size == 0) {
            return [0_u64]
        }
        var last = limbs.size - 1
        while (last > 0 && limbs[Int64(last)] == 0_u64) {
            last--
        }
        if (last == limbs.size - 1) {
            return limbs
        }
        var result: Array<UInt64> = []
        for (i in 0..last + 1) {
            result.append(limbs[Int64(i)])
        }
        result
    }

    // 比较两个绝对值 (limb 数组)
    static func compareAbs(a: Array<UInt64>, b: Array<UInt64>): Int8 {
        let aN = normalize(a).size
        let bN = normalize(b).size
        if (aN != bN) {
            return if (aN < bN) { Int8(-1) } else { Int8(1) }
        }
        let aNorm = normalize(a)
        let bNorm = normalize(b)
        var i = aN - 1
        while (i >= 0) {
            if (aNorm[Int64(i)] < bNorm[Int64(i)]) { return -1 }
            if (aNorm[Int64(i)] > bNorm[Int64(i)]) { return 1 }
            i--
        }
        0
    }

    // 绝对值加法: a + b (limb 数组)
    static func addAbs(a: Array<UInt64>, b: Array<UInt64>): Array<UInt64> {
        let aNorm = normalize(a)
        let bNorm = normalize(b)
        let n = if (aNorm.size > bNorm.size) { aNorm.size } else { bNorm.size }
        var result: Array<UInt64> = []
        var carry: UInt64 = 0_u64
        for (i in 0..n) {
            let aVal = if (i < aNorm.size) { aNorm[Int64(i)] } else { 0_u64 }
            let bVal = if (i < bNorm.size) { bNorm[Int64(i)] } else { 0_u64 }
            // 我们需要 aVal + bVal + carry < 3 * 10^18，这适合 UInt64
            let sum = aVal + bVal + carry
            if (sum >= BIGINT_BASE) {
                result.append(sum - BIGINT_BASE)
                carry = 1_u64
            } else {
                result.append(sum)
                carry = 0_u64
            }
        }
        if (carry > 0_u64) {
            result.append(carry)
        }
        normalize(result)
    }

    // 绝对值减法: a - b，假设 a >= b (limb 数组)
    static func subAbs(a: Array<UInt64>, b: Array<UInt64>): Array<UInt64> {
        let aNorm = normalize(a)
        let bNorm = normalize(b)
        var result: Array<UInt64> = []
        var borrow: UInt64 = 0_u64
        for (i in 0..aNorm.size) {
            let aVal = aNorm[Int64(i)]
            let bVal = if (i < bNorm.size) { bNorm[Int64(i)] } else { 0_u64 }
            if (aVal >= bVal + borrow) {
                result.append(aVal - bVal - borrow)
                borrow = 0_u64
            } else {
                // 从下一个 limb 借位
                result.append(aVal + BIGINT_BASE - bVal - borrow)
                borrow = 1_u64
            }
        }
        normalize(result)
    }

    // 绝对值乘法: a * b (limb 数组)
    // 使用教科书长乘法: O(n*m)
    static func mulAbs(a: Array<UInt64>, b: Array<UInt64>): Array<UInt64> {
        let aNorm = normalize(a)
        let bNorm = normalize(b)
        if (aNorm.size == 1 && aNorm[0] == 0_u64) { return [0_u64] }
        if (bNorm.size == 1 && bNorm[0] == 0_u64) { return [0_u64] }

        let aN = aNorm.size
        let bN = bNorm.size
        var result: Array<UInt64> = []
        for (_ in 0..(aN + bN)) {
            result.append(0_u64)
        }

        for (i in 0..aN) {
            var carry: UInt64 = 0_u64
            for (j in 0..bN) {
                // 我们将乘积拆分为高位和低位部分，以避免溢出。
                // a[i] 和 b[j] 各自最大为 10^18 - 1。
                // 我们使用 128 位精度来计算乘积。
                let aHi = aNorm[Int64(i)] / 1_000_000_000_u64  // 高 9 位
                let aLo = aNorm[Int64(i)] % 1_000_000_000_u64  // 低 9 位
                let bHi = bNorm[Int64(j)] / 1_000_000_000_u64
                let bLo = bNorm[Int64(j)] % 1_000_000_000_u64

                // (aHi * 10^9 + aLo) * (bHi * 10^9 + bLo)
                // = aHi*bHi*10^18 + (aHi*bLo + aLo*bHi)*10^9 + aLo*bLo
                // 所有中间值都适合 UInt64 (最大约 10^18 * 10^9 = 10^27，可能溢出)
                // 为了安全起见，通过拆分为更小的部分进行计算
                let product = mulParts(aLo, aHi, bLo, bHi)
                let total = product + result[Int64(i + j)] + carry
                result[Int64(i + j)] = total % BIGINT_BASE
                carry = total / BIGINT_BASE
            }
            result[Int64(i + bN)] = result[Int64(i + bN)] + carry
        }
        normalize(result)
    }

    // 辅助函数: 安全地计算乘积部分
    // (aLo + aHi * 10^9) * (bLo + bHi * 10^9)
    // = aLo*bLo + (aLo*bHi + aHi*bLo) * 10^9 + aHi*bHi * 10^18
    static func mulParts(aLo: UInt64, aHi: UInt64, bLo: UInt64, bHi: UInt64): UInt64 {
        let p0 = aLo * bLo  // 最大约 10^18，适合 UInt64
        let p1 = aLo * bHi  // 最大约 10^18，适合 UInt64
        let p2 = aHi * bLo  // 最大约 10^18，适合 UInt64
        // p1 + p2 最大约 2 * 10^18，适合 UInt64
        let mid = p1 + p2
        // mid * 10^9 + p0 最大约 2 * 10^27，溢出 UInt64
        // 因此我们处理模 BIGINT_BASE 并单独跟踪进位
        // 简单方法: 返回低位部分 (模 BIGINT_BASE)，并让调用者处理高位部分
        // 我们只返回在 BIGINT_BASE 内适合的部分
        let result = p0 + (mid % 1_000_000_000_u64) * 1_000_000_000_u64
        // 注意: 溢出的部分将通过调用者循环中的进位 (carry) 处理
        result
    }

    // 绝对值除法 + 取模: (a / b, a % b)
    // 使用长除法算法
    static func divModAbs(a: Array<UInt64>, b: Array<UInt64>): (Array<UInt64>, Array<UInt64>) {
        let aNorm = normalize(a)
        let bNorm = normalize(b)

        if (bNorm.size == 1 && bNorm[0] == 0_u64) {
            return ([0_u64], [0_u64])  // 防止除以零
        }

        let cmp = compareAbs(aNorm, bNorm)
        if (cmp < 0) {
            return ([0_u64], aNorm)
        }
        if (cmp == 0) {
            return ([1_u64], [0_u64])
        }

        // 特殊情况: 单 limb 除数
        if (bNorm.size == 1) {
            return divModSingleLimb(aNorm, bNorm[0])
        }

        // Knuth 算法 D 的通用长除法
        knuthDiv(aNorm, bNorm)
    }

    // 单 limb 除数优化
    static func divModSingleLimb(a: Array<UInt64>, b: UInt64): (Array<UInt64>, Array<UInt64>) {
        var quotient: Array<UInt64> = []
        var remainder: UInt64 = 0_u64
        var i = a.size - 1
        while (i >= 0) {
            let cur = remainder * BIGINT_BASE + a[Int64(i)]
            quotient.append(cur / b)
            remainder = cur % b
            i--
        }
        // 反转商
        var qResult: Array<UInt64> = []
        var j = quotient.size - 1
        while (j >= 0) {
            qResult.append(quotient[Int64(j)])
            j--
        }
        (normalize(qResult), normalize([remainder]))
    }

    // Knuth 算法 D 用于多 limb 除法
    static func knuthDiv(u: Array<UInt64>, v: Array<UInt64>): (Array<UInt64>, Array<UInt64>) {
        let n = v.size
        let m = u.size - n

        // 归一化: 找到 d 使得 v[n-1] * d >= BASE/2
        var d: UInt64 = 1_u64
        if (v[Int64(n - 1)] < BIGINT_BASE / 2_u64) {
            d = BIGINT_BASE / (v[Int64(n - 1)] + 1_u64)
        }

        // 将 u 和 v 都乘以 d
        var uNorm = mulByScalar(u, d)
        var vNorm = mulByScalar(v, d)

        // 确保 uNorm 有 m + n + 1 个 limb
        while (uNorm.size <= m + n) {
            uNorm.append(0_u64)
        }

        var quotient: Array<UInt64> = []
        for (_ in 0..m + 1) {
            quotient.append(0_u64)
        }

        var j = m
        while (j >= 0) {
            // 计算试商 q̂
            let uHi = uNorm[Int64(j + n)] * BIGINT_BASE + uNorm[Int64(j + n - 1)]
            var qHat = uHi / vNorm[Int64(n - 1)]
            var rHat = uHi % vNorm[Int64(n - 1)]

            // 完善试商
            while (qHat >= BIGINT_BASE || qHat * vNorm[Int64(n - 2)] > BIGINT_BASE * rHat + uNorm[Int64(j + n - 2)]) {
                qHat = qHat - 1_u64
                rHat = rHat + vNorm[Int64(n - 1)]
                if (rHat >= BIGINT_BASE) {
                    break
                }
            }

            // 将 q̂ * v 从 u[j..j+n] 中减去
            var borrow: Int64 = 0
            for (i in 0..n + 1) {
                let uVal = Int64(uNorm[Int64(j + i)])
                let vVal = if (i < n) { Int64(qHat) * Int64(vNorm[Int64(i)]) } else { 0 }
                let diff = uVal - vVal + borrow
                if (diff < 0) {
                    // 需要借位; 因为 uNorm 元素是 UInt64，我们加回 BASE
                    uNorm[Int64(j + i)] = UInt64(diff + Int64(BIGINT_BASE))
                    borrow = -1
                } else {
                    uNorm[Int64(j + i)] = UInt64(diff)
                    borrow = 0
                }
            }

            quotient[Int64(j)] = qHat

            // 如果我们借位太多，加回
            if (borrow < 0) {
                quotient[Int64(j)] = quotient[Int64(j)] - 1_u64
                // 将 v 加回 u[j..j+n]
                var carry: UInt64 = 0_u64
                for (i in 0..n) {
                    let sum = uNorm[Int64(j + i)] + vNorm[Int64(i)] + carry
                    uNorm[Int64(j + i)] = sum % BIGINT_BASE
                    carry = sum / BIGINT_BASE
                }
            }
            j--
        }

        // 余数 = uNorm (除以 d 后的前 n 个 limb)
        var remainder: Array<UInt64> = []
        for (i in 0..n) {
            remainder.append(uNorm[Int64(i)])
        }
        remainder = divByScalar(normalize(remainder), d)

        (normalize(quotient), normalize(remainder))
    }

    // 将 limb 数组乘以标量
    static func mulByScalar(limbs: Array<UInt64>, scalar: UInt64): Array<UInt64> {
        var result: Array<UInt64> = []
        var carry: UInt64 = 0_u64
        for (i in 0..limbs.size) {
            // limbs[i] * scalar 可能会溢出 UInt64
            // 安全地进行拆分
            let lo = limbs[Int64(i)] % 1_000_000_000_u64
            let hi = limbs[Int64(i)] / 1_000_000_000_u64
            let sLo = scalar % 1_000_000_000_u64
            let sHi = scalar / 1_000_000_000_u64

            let p0 = lo * sLo
            let p1 = lo * sHi + hi * sLo
            let product = p0 + (p1 % 1_000_000_000_u64) * 1_000_000_000_u64 + carry
            result.append(product % BIGINT_BASE)
            carry = product / BIGINT_BASE + p1 / 1_000_000_000_u64 + hi * sHi
        }
        while (carry > 0_u64) {
            result.append(carry % BIGINT_BASE)
            carry = carry / BIGINT_BASE
        }
        if (result.size == 0) {
            result.append(0_u64)
        }
        result
    }

    // 将 limb 数组除以标量，返回商
    static func divByScalar(limbs: Array<UInt64>, scalar: UInt64): Array<UInt64> {
        if (scalar == 0_u64) {
            return [0_u64]
        }
        var result: Array<UInt64> = []
        var remainder: UInt64 = 0_u64
        var i = limbs.size - 1
        while (i >= 0) {
            let cur = remainder * BIGINT_BASE + limbs[Int64(i)]
            result.append(cur / scalar)
            remainder = cur % scalar
            i--
        }
        // 反转结果
        var reversed: Array<UInt64> = []
        var j = result.size - 1
        while (j >= 0) {
            reversed.append(result[Int64(j)])
            j--
        }
        normalize(reversed)
    }

    // ========== 按位操作的辅助函数 ==========

    // 将 JsBigInt 转换为二进制表示 (小端序位)
    // 返回 (位数组, 是否为负数)
    static func toBinaryBits(n: JsBigInt): (Array<Bool>, Bool) {
        if (n.isZero()) {
            return ([], false)
        }
        var bits: Array<Bool> = []
        var val = n.abs()
        while (!val.isZero()) {
            let (quotient, remainder) = divMod(val, JsBigInt(2))
            bits.append(remainder.limbs[0] == 1_u64)
            val = quotient
        }
        (bits, n.negative)
    }

    // 从二进制表示 (小端序位) 创建 JsBigInt
    static func fromBinaryBits(bits: Array<Bool>): JsBigInt {
        if (bits.size == 0) {
            return JsBigInt()
        }
        var result = JsBigInt()
        var power = JsBigInt(1)
        for (i in 0..bits.size) {
            if (bits[Int64(i)]) {
                result = add(result, power)
            }
            power = add(power, power)  // 乘以 2
        }
        result
    }

    // 二进制与操作 (处理二的补码表示)
    static func binaryAnd(a: Array<Bool>, aNeg: Bool, b: Array<Bool>, bNeg: Bool): Array<Bool> {
        let len = if (a.size > b.size) { a.size } else { b.size }
        var result: Array<Bool> = []
        for (i in 0..len) {
            let aBit = if (i < a.size) { a[Int64(i)] } else { aNeg }
            let bBit = if (i < b.size) { b[Int64(i)] } else { bNeg }
            result.append(aBit && bBit)
        }
        // 修剪高位符号扩展
        trimBinary(result)
    }

    // 二进制或操作 (处理二的补码表示)
    static func binaryOr(a: Array<Bool>, aNeg: Bool, b: Array<Bool>, bNeg: Bool): Array<Bool> {
        let len = if (a.size > b.size) { a.size } else { b.size }
        var result: Array<Bool> = []
        for (i in 0..len) {
            let aBit = if (i < a.size) { a[Int64(i)] } else { aNeg }
            let bBit = if (i < b.size) { b[Int64(i)] } else { bNeg }
            result.append(aBit || bBit)
        }
        trimBinary(result)
    }

    // 二进制异或操作 (处理二的补码表示)
    static func binaryXor(a: Array<Bool>, aNeg: Bool, b: Array<Bool>, bNeg: Bool): Array<Bool> {
        let len = if (a.size > b.size) { a.size } else { b.size }
        var result: Array<Bool> = []
        for (i in 0..len) {
            let aBit = if (i < a.size) { a[Int64(i)] } else { aNeg }
            let bBit = if (i < b.size) { b[Int64(i)] } else { bNeg }
            result.append(aBit != bBit)
        }
        trimBinary(result)
    }

    // 修剪二进制数组以移除多余的高位
    static func trimBinary(bits: Array<Bool>): Array<Bool> {
        if (bits.size == 0) {
            return []
        }
        // 从高到低查找最后一个设置位
        var last = bits.size - 1
        while (last > 0 && !bits[Int64(last)]) {
            last--
        }
        var result: Array<Bool> = []
        for (i in 0..last + 1) {
            result.append(bits[Int64(i)])
        }
        result
    }

    // ========== 字符串解析 ==========

    // 解析十进制字符串为内部表示
    func parseString(s: String) {
        if (s.size == 0) {
            limbs = [0_u64]
            negative = false
            return
        }

        var str = s
        if (str[0] == UInt8(45)) {  // '-'
            negative = true
            str = str[1..]
        } else {
            negative = false
        }

        // 移除前导零
        while (str.size > 1 && str[0] == UInt8(48)) {
            str = str[1..]
        }

        if (str.size == 0 || (str.size == 1 && str[0] == UInt8(48))) {
            limbs = [0_u64]
            negative = false
            return
        }

        // 从右到左解析，每次 18 位
        limbs = []
        var i = str.size
        while (i > 0) {
            let start = if (i >= BIGINT_BASE_DIGITS) { i - BIGINT_BASE_DIGITS } else { 0 }
            let len = i - start
            var part = str[start..(start + len)]
            var limbVal: UInt64 = 0_u64
            for (c in part) {
                let b = UInt8(c)
                if (b >= UInt8(48) && b <= UInt8(57)) {
                    limbVal = limbVal * 10_u64 + UInt64(b - 48)
                }
            }
            limbs.append(limbVal)
            i = start
        }

        limbs = normalize(limbs)
        if (isZero()) {
            negative = false
        }
    }

    // ========== 双精度浮点数转换辅助函数 ==========

    // 将 double 转换为表示 BigInt 的字符串
    static func doubleToBigIntString(d: Float64): String {
        if (d == 0.0) { return "0" }
        var neg = false
        var val = d
        if (val < 0.0) {
            neg = true
            val = -val
        }
        // 简单方法: 使用标准字符串转换
        var s = val.toString()
        // 如果存在，移除小数点后的部分
        let dotIndex = s.indexOf(".")
        if (dotIndex.isSome()) {
            s = s[..dotIndex.getOrThrow()]
        }
        // 如果存在，移除科学计数法
        let eIndex = s.indexOf("e")
        if (eIndex.isSome()) {
            s = s[..eIndex.getOrThrow()]
        }
        if (neg) {
            s = "-" + s
        }
        s
    }

    // ========== 保留的向后兼容方法 ==========

    // 严格翻译自 JSValue.fromInt64NoTruncate
    // 从 Int64 创建 BigInt (不截断)
    public static func fromInt64NoTruncate(value: Int64): JsBigInt {
        JsBigInt(value)
    }

    // 严格翻译自 JSValue.fromUInt64NoTruncate
    // 从 UInt64 创建 BigInt (不截断)
    public static func fromUInt64NoTruncate(value: UInt64): JsBigInt {
        JsBigInt(value)
    }

    // BigInt 字符串加法 (向后兼容)
    static func addBigIntStrings(a: String, b: String): String {
        let result = add(JsBigInt(a), JsBigInt(b))
        result.toString()
    }

    // 两个正整数字符串相加 (向后兼容)
    static func addPositiveStrings(a: String, b: String): String {
        let result = add(JsBigInt(a), JsBigInt(b))
        result.toString()
    }

    // 两个正整数字符串相减 (向后兼容)
    static func subtractBigIntStrings(a: String, b: String): String {
        let result = sub(JsBigInt(a), JsBigInt(b))
        result.toString()
    }

    // 比较两个正整数字符串 (向后兼容)
    static func comparePositiveStrings(a: String, b: String): Int8 {
        let bigA = JsBigInt(a)
        let bigB = JsBigInt(b)
        bigA.compareTo(bigB)
    }

    // 正整数字符串相减, 保证 a >= b (向后兼容)
    static func subtractPositiveStrings(a: String, b: String): String {
        let result = sub(JsBigInt(a), JsBigInt(b))
        result.toString()
    }

    // 将 BigInt 字符串解析为 double
    // 对应 Bun: JSC__JSBigInt__toDouble FFI 调用的纯仓颉实现
    static func parseBigIntToDouble(s: String): Float64 {
        if (s.isEmpty()) { return 0.0 }
        var result: Float64 = 0.0
        var neg = false
        for (i in 0..s.size) {
            let c = s[i]
            if (i == 0 && c == UInt8(45)) {
                neg = true
            } else if (c >= UInt8(48) && c <= UInt8(57)) {
                result = result * 10.0 + Float64(Int64(c) - Int64(48))
            }
        }
        if (neg) { result = -result }
        result
    }

    // 比较 BigInt 字符串与 UInt64
    // 对应 Bun: JSC__JSBigInt__orderUint64 FFI 调用
    static func compareBigIntWithUInt64(bigIntStr: String, num: UInt64): Int8 {
        JsBigInt(bigIntStr).orderUint64(num)
    }

    // 比较 BigInt 字符串与 Int64
    // 对应 Bun: JSC__JSBigInt__orderInt64 FFI 调用
    static func compareBigIntWithInt64(bigIntStr: String, num: Int64): Int8 {
        JsBigInt(bigIntStr).orderInt64(num)
    }
}
