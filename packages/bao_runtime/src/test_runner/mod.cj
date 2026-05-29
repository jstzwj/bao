// mod.cj - 测试运行器模块级工具
// 严格翻译自 bun/src/runtime/test_runner/mod.rs
//
// 本文件对应 Bun 的 mod.rs，包含:
// - makeFormatter: 格式化器工厂函数
// - BigIntCompare: BigInt 比较结果枚举
// - OrderingRelation: 数值排序关系枚举
// - numericOrderingMatcher: 通用数值比较匹配器
// - Extension traits: JSValueTestExt, JSGlobalObjectTestExt, FormatterTestExt
// - unaryPredicateMatcher: 一元谓词匹配器工具

package bao_runtime.test_runner

import bao_jsc.{CallFrame, ComparisonResult, ConsoleFormatter, AnsiColors, Formatter, JsObject, JSGlobalObject, JsValue}
import bao_collections.ArrayList
import bao_collections.HashMap

// ========== JSGlobalObject 扩展 - 测试运行器所需方法 ==========

extend JSGlobalObject {

    /// 抛出带格式化的错误
    public func throwPretty(fmt: String, args: ArrayList<Any>): JsValue {
        let message = AnsiColors.prettyFmt(fmt, false)
        throwError(message)
        return JsValue.jsUndefined()
    }

    /// 抛出带格式化的错误 (Array版本)
    public func throwPretty(fmt: String, args: Array<Any>): JsValue {
        let message = AnsiColors.prettyFmt(fmt, false)
        throwError(message)
        return JsValue.jsUndefined()
    }

    /// throw 的别名（对应 scope_functions 中的 `throw`）
    public func `throw`(message: String): JsValue {
        return throw_(message)
    }

}

// ========== ConsoleFormatter 扩展 ==========

extend ConsoleFormatter {
    /// 格式化单个值
    public func formatValue(value: JsValue, global: JsObject): String {
        return value.toString()
    }
}

/// ConsoleFormatter 格式化工具
public class ConsoleFormatterExtensions {
    public static func formatValue(formatter: ConsoleFormatter, value: JsValue, global: JsObject): String {
        return formatter.formatValue(value, global)
    }
}

// ========== ConsoleFormatter 扩展 - 便捷格式化方法 ==========

extend ConsoleFormatter {
    /// 单参数格式化
    /// 对应 Bun: ConsoleFormatter 单参数 format
    /// 委托给 formatValue 进行实际格式化
    public func format(value: JsValue): String {
        return formatValue(value, globalThis)
    }
}

// ========== 格式化器工厂 ==========

/// 创建格式化器
///
/// 所有匹配器统一使用的格式化器创建函数。
/// 设置 quote_strings = true 以便在断言消息中正确显示字符串值。
///
/// 对应 Bun: `pub fn make_formatter(global: &JSGlobalObject) -> Formatter<'_>`
public func makeFormatter(global: JSGlobalObject): ConsoleFormatter {
    let formatter = ConsoleFormatter()
    formatter.quoteStrings = true
    formatter.globalThis = global.globalThis
    return formatter
}

// ========== BigInt 比较 ==========

/// BigInt 比较结果
///
/// 对应 Bun: `pub enum BigIntCompare { LessThan, Equal, GreaterThan, Undefined }`
/// 用于 toBeGreaterThan/toBeLessThan 等数值比较匹配器中的 BigInt 比较路径。
public enum BigIntCompare {
    | lessThan
    | equal
    | greaterThan
    | undefined

    /// 从 JsValue 的 ComparisonResult 转换
    public static func fromComparisonResult(result: ComparisonResult): BigIntCompare {
        match (result) {
            case ComparisonResult.Equal => BigIntCompare.equal
            case ComparisonResult.GreaterThan => BigIntCompare.greaterThan
            case ComparisonResult.LessThan => BigIntCompare.lessThan
            case ComparisonResult.UndefinedResult | ComparisonResult.InvalidComparison => BigIntCompare.undefined
        }
    }
}

// ========== 数值排序关系 ==========

/// 数值排序关系
///
/// 对应 Bun: `pub(super) enum OrderingRelation { Gt, Ge, Lt, Le }`
/// 用于 toBeGreaterThan/toBeGreaterThanOrEqual/toBeLessThan/toBeLessThanOrEqual
/// 的共享匹配器实现。
public enum OrderingRelation {
    | gt   // >
    | ge   // >=
    | lt   // <
    | le   // <=

    /// 操作符字形（已转义，用于 throwPretty）
    public func glyph(): String {
        match (this) {
            case gt => "\\>"
            case ge => "\\>="
            case lt => "\\<"
            case le => "\\<="
        }
    }

    /// 浮点数比较
    public func cmpF64(a: Float64, b: Float64): Bool {
        match (this) {
            case gt => a > b
            case ge => a >= b
            case lt => a < b
            case le => a <= b
        }
    }

    /// BigInt 比较结果（正向）
    public func cmpBigintFwd(r: BigIntCompare): Bool {
        match (this) {
            case gt => match (r) {
                case BigIntCompare.greaterThan => true
                case _ => false
            }
            case ge => match (r) {
                case BigIntCompare.greaterThan | BigIntCompare.equal => true
                case _ => false
            }
            case lt => match (r) {
                case BigIntCompare.lessThan => true
                case _ => false
            }
            case le => match (r) {
                case BigIntCompare.lessThan | BigIntCompare.equal => true
                case _ => false
            }
        }
    }

    /// BigInt 比较结果（反向，操作数交换）
    public func cmpBigintRev(r: BigIntCompare): Bool {
        match (this) {
            case gt => match (r) {
                case BigIntCompare.lessThan => true
                case _ => false
            }
            case ge => match (r) {
                case BigIntCompare.lessThan | BigIntCompare.equal => true
                case _ => false
            }
            case lt => match (r) {
                case BigIntCompare.greaterThan => true
                case _ => false
            }
            case le => match (r) {
                case BigIntCompare.greaterThan | BigIntCompare.equal => true
                case _ => false
            }
        }
    }
}

// ========== 通用数值排序匹配器 ==========

/// 通用数值排序匹配器
///
/// 对应 Bun: `Expect::numeric_ordering_matcher()`
/// 被 toBeGreaterThan/toBeGreaterThanOrEqual/toBeLessThan/toBeLessThanOrEqual 共享。
/// 四个 Zig 匹配器仅区别于名称、操作符和 BigIntCompare 判断，
/// 此函数将它们统一为一个参数化的实现。
public func numericOrderingMatcher(expect: Expect, global: JSGlobalObject, callFrame: CallFrame, name: String, rel: OrderingRelation): JsValue {
    let thisValue = callFrame.`this`()
    let argsBuf = callFrame.argumentsOld(1)
    let arguments = argsBuf.slice()

    if (arguments.size < 1) {
        expect.postMatch(globalThis: global)
        return global.throwInvalidArgumentsValue(name + "() requires 1 argument")
    }

    expect.incrementExpectCallCounter()

    let otherValue = arguments[0]
    otherValue.ensureStillAlive()

    let value: JsValue = expect.getValue(globalThis: global, thisValue: thisValue, matcherName: name, matcherParamsFmt: "<green>expected<r>")

    if ((!value.isNumber() && !value.isBigInt()) || (!otherValue.isNumber() && !otherValue.isBigInt())) {
        expect.postMatch(globalThis: global)
        global.throwError("Expected and actual values must be numbers or bigints")
        return JsValue.jsUndefined()
    }

    let not = expect.flags.not
    var pass = false

    if (!value.isBigInt() && !otherValue.isBigInt()) {
        pass = rel.cmpF64(value.asNumber(), otherValue.asNumber())
    } else if (value.isBigInt()) {
        pass = rel.cmpBigintFwd(BigIntCompare.fromComparisonResult(
            value.asBigIntCompare(global.globalThis, otherValue)))
    } else {
        pass = rel.cmpBigintRev(BigIntCompare.fromComparisonResult(
            otherValue.asBigIntCompare(global.globalThis, value)))
    }

    if (not) { pass = !pass }
    if (pass) {
        expect.postMatch(globalThis: global)
        return JsValue.jsUndefined()
    }

    let formatter1 = ConsoleFormatter()
    formatter1.quoteStrings = true
    formatter1.globalThis = global.globalThis
    let formatter2 = ConsoleFormatter()
    formatter2.quoteStrings = true
    formatter2.globalThis = global.globalThis
    let valueFmt = ConsoleFormatterExtensions.formatValue(formatter1, value, global.globalThis)
    let expectedFmt = ConsoleFormatterExtensions.formatValue(formatter2, otherValue, global.globalThis)
    let glyph = rel.glyph()

    if (not) {
        let signature = Expect.getSignature(name, "<green>expected<r>", true)
        expect.postMatch(globalThis: global)
        return expect.throw_(globalThis: global, signature: signature,
            fmt: "\n\nExpected: not " + glyph + " <green>{f}<r>\nReceived: <red>{f}<r>\n",
            args: [expectedFmt, valueFmt])
    }

    let signature = Expect.getSignature(name, "<green>expected<r>", false)
    expect.postMatch(globalThis: global)
    return expect.throw_(globalThis: global, signature: signature,
        fmt: "\n\nExpected: " + glyph + " <green>{f}<r>\nReceived: <red>{f}<r>\n",
        args: [expectedFmt, valueFmt])
}

// ========== 一元谓词匹配器工具 ==========

/// 运行一元谓词匹配器
///
/// 对应 Bun: `Expect::run_unary_predicate()`
/// 用于 toBeTrue/toBeFalse/toBeNull/toBeUndefined/toBeNaN 等简单的布尔谓词匹配器。
///
/// @param expect - Expect 实例
/// @param global - 全局对象
/// @param callFrame - 调用帧
/// @param matcherName - 匹配器名称（如 "toBeTrue"）
/// @param predicate - 谓词函数，接收 JsValue 返回是否通过
/// @return JsValue
public func runUnaryPredicate(expect: Expect, global: JSGlobalObject, callFrame: CallFrame, matcherName: String, predicate: (JsValue) -> Bool): JsValue {
    let thisValue = callFrame.`this`()
    let value: JsValue = expect.getValue(globalThis: global, thisValue: thisValue, matcherName: matcherName, matcherParamsFmt: "")

    expect.incrementExpectCallCounter()

    var pass = predicate(value)

    let not = expect.flags.not
    if (not) { pass = !pass }
    if (pass) {
        expect.postMatch(globalThis: global)
        return JsValue.jsUndefined()
    }

    let formatter = ConsoleFormatter()
    formatter.quoteStrings = true
    formatter.globalThis = global.globalThis
    let received = ConsoleFormatterExtensions.formatValue(formatter, value, global.globalThis)

    if (not) {
        let signature = Expect.getSignature(matcherName, "", true)
        expect.postMatch(globalThis: global)
        return expect.throw_(globalThis: global, signature: signature,
            fmt: "\n\nExpected: not {f}\nReceived: <red>{f}<r>\n",
            args: [received, received])
    }

    let signature = Expect.getSignature(matcherName, "", false)
    expect.postMatch(globalThis: global)
    return expect.throw_(globalThis: global, signature: signature,
        fmt: "\n\nReceived: <red>{f}<r>\n",
        args: [received])
}

// ========== Formatter 扩展 ==========

/// Formatter 扩展工具
///
/// 对应 Bun: `pub trait FormatterTestExt: Sized { fn with_quote_strings(self, b: bool) -> Self; }`
/// 提供 builder 风格的配置方法。
public class FormatterTestExt {
    /// 设置引用字符串选项
    public static func withQuoteStrings(formatter: ConsoleFormatter, quoteStrings: Bool): ConsoleFormatter {
        formatter.quoteStrings = quoteStrings
        return formatter
    }
}

// ========== Mock 返回类型枚举 ==========

/// Mock 返回对象类型
///
/// 用于 toHaveReturned/toHaveReturnedTimes 等匹配器。
public enum MockReturnType {
    | return_    // 正常返回
    | throw_    // 抛出异常
    | incomplete // 尚未完成
}

// ========== Mock 辅助工具 ==========

/// Mock 相关辅助工具函数
///
/// 对应 Bun 中 expect.zig 中的 Mock 命名空间。
public class MockHelpers {
    /// 获取 mock 函数的调用记录迭代器
    public static func jestMockIterator(globalThis!: JsObject, value!: JsValue): MockResultIterator {
        return MockResultIterator(globalThis, JSMockFunction.getReturnValues(globalThis: globalThis, value: value))
    }

    /// 获取 mock 返回对象的类型
    public static func jestMockReturnObjectType(globalThis!: JsObject, item!: JsValue): MockReturnType {
        let typeValue = item.get(globalThis, "type")
        if (typeValue.isNone()) { return MockReturnType.incomplete }
        let typeStr = typeValue.getOrThrow().toSliceOrNull(globalThis) ?? ""
        match (typeStr) {
            case "return" => return MockReturnType.return_
            case "throw" => return MockReturnType.throw_
            case _ => return MockReturnType.incomplete
        }
    }
}

/// Mock 结果迭代器
///
/// 遍历 mock 函数的所有返回结果。
public class MockResultIterator {
    private let globalThis: JsObject
    private let returnValues: JsValue
    private var index: Int32 = 0
    private let length: Int32

    public init(globalThis: JsObject, returnValues: JsValue) {
        this.globalThis = globalThis
        this.returnValues = returnValues
        this.length = Int32(returnValues.getLength(globalThis))
    }

    public func next(): ?JsValue {
        if (index >= length) { return None }
        let item = returnValues.getIndex(globalThis, UInt32(index))
        index += 1
        return item
    }
}

// ========== String 扩展 - test_runner 所需的 toSlice ==========

extend String {
    /// 将 String 转为切片
    /// 对应 Bun: BunString.toSlice / string.toSlice
    /// 在 Cangjie 中 String 本身就是值类型，直接返回自身
    /// 保留 allocator 参数以匹配 Bun API 签名
    public func toSlice(allocator!: Any): String {
        this
    }

    /// 将 String 转为切片（带 global 参数）
    /// 对应 Bun: JSValue.toSlice(globalThis)
    /// 在 Cangjie 中 String 本身就是值类型，直接返回自身
    public func toSlice(global!: JsObject): String {
        this
    }
}
