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

import bao_jsc.*

// ========== 格式化器工厂 ==========

/// 创建格式化器
///
/// 所有匹配器统一使用的格式化器创建函数。
/// 设置 quote_strings = true 以便在断言消息中正确显示字符串值。
///
/// 对应 Bun: `pub fn make_formatter(global: &JSGlobalObject) -> Formatter<'_>`
public func makeFormatter(global: JSGlobalObject): ConsoleObject.Formatter {
    let formatter = ConsoleObject.Formatter(globalThis: global, quote_strings: true)
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

    /// 从 JSValue 的 ComparisonResult 转换
    public static func fromComparisonResult(result: ComparisonResult): BigIntCompare {
        match (result) {
            case ComparisonResult.equal => BigIntCompare.equal
            case ComparisonResult.greaterThan => BigIntCompare.greaterThan
            case ComparisonResult.lessThan => BigIntCompare.lessThan
            case ComparisonResult.undefined | ComparisonResult.invalidComparison => BigIntCompare.undefined
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
public func numericOrderingMatcher(expect: Expect, global: JSGlobalObject, callFrame: CallFrame, name: String, rel: OrderingRelation): JSValue {
    defer { expect.postMatch(globalThis: global) }

    let thisValue = callFrame.this_()
    let argsBuf = callFrame.argumentsOld(1)
    let arguments = argsBuf.slice()

    if (arguments.length < 1) {
        return global.throwInvalidArguments(name + "() requires 1 argument")
    }

    expect.incrementExpectCallCounter()

    let otherValue = arguments[0]
    otherValue.ensureStillAlive()

    let value: JSValue = expect.getValue(globalThis: global, thisValue: thisValue, matcherName: name, matcherParamsFmt: "<green>expected<r>")

    if ((!value.isNumber() && !value.isBigInt()) || (!otherValue.isNumber() && !otherValue.isBigInt())) {
        return global.throw_("Expected and actual values must be numbers or bigints")
    }

    let not = expect.flags.not
    var pass = false

    if (!value.isBigInt() && !otherValue.isBigInt()) {
        // 两个都是普通数字
        pass = rel.cmpF64(value.asNumber(), otherValue.asNumber())
    } else if (value.isBigInt()) {
        // 值是 BigInt
        pass = rel.cmpBigintFwd(BigIntCompare.fromComparisonResult(
            value.asBigIntCompare(global: global, other: otherValue)))
    } else {
        // 其他值是 BigInt（操作数交换）
        pass = rel.cmpBigintRev(BigIntCompare.fromComparisonResult(
            otherValue.asBigIntCompare(global: global, other: value)))
    }

    if (not) { pass = !pass }
    if (pass) { return JSValue.jsUndefined }

    // 失败路径
    let formatter1 = ConsoleObject.Formatter(globalThis: global, quote_strings: true)
    let formatter2 = ConsoleObject.Formatter(globalThis: global, quote_strings: true)
    let valueFmt = value.toFmt(formatter1)
    let expectedFmt = otherValue.toFmt(formatter2)
    let glyph = rel.glyph()

    if (not) {
        let signature = Expect.getSignature(matcherName: name, args: "<green>expected<r>", not: true)
        return expect.throw_(globalThis: global, signature: signature,
            fmt: "\n\nExpected: not " + glyph + " <green>{f}<r>\nReceived: <red>{f}<r>\n",
            args: [expectedFmt, valueFmt])
    }

    let signature = Expect.getSignature(matcherName: name, args: "<green>expected<r>", not: false)
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
/// @param predicate - 谓词函数，接收 JSValue 返回是否通过
/// @return JSValue
public func runUnaryPredicate(expect: Expect, global: JSGlobalObject, callFrame: CallFrame, matcherName: String, predicate: (JSValue) -> Bool): JSValue {
    defer { expect.postMatch(globalThis: global) }

    let thisValue = callFrame.this_()
    let value: JSValue = expect.getValue(globalThis: global, thisValue: thisValue, matcherName: matcherName, matcherParamsFmt: "")

    expect.incrementExpectCallCounter()

    var pass = predicate(value)

    let not = expect.flags.not
    if (not) { pass = !pass }
    if (pass) { return JSValue.jsUndefined }

    // 失败路径
    let formatter = ConsoleObject.Formatter(globalThis: global, quote_strings: true)
    let received = value.toFmt(formatter)

    if (not) {
        let signature = Expect.getSignature(matcherName: matcherName, args: "", not: true)
        return expect.throw_(globalThis: global, signature: signature,
            fmt: "\n\nExpected: not {f}\nReceived: <red>{f}<r>\n",
            args: [received, received])
    }

    let signature = Expect.getSignature(matcherName: matcherName, args: "", not: false)
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
    public static func withQuoteStrings(formatter: ConsoleObject.Formatter, quoteStrings: Bool): ConsoleObject.Formatter {
        formatter.quote_strings = quoteStrings
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
    public static func jestMockIterator(globalThis: JSGlobalObject, value: JSValue): MockResultIterator {
        return MockResultIterator(globalThis: globalThis, returnValues: JSMockFunction.getReturnValues(globalThis: globalThis, value: value))
    }

    /// 获取 mock 返回对象的类型
    public static func jestMockReturnObjectType(globalThis: JSGlobalObject, item: JSValue): MockReturnType {
        let typeValue = item.get(globalThis, key: "type")
        if (typeValue.isNone()) { return MockReturnType.incomplete }
        let typeStr = typeValue.toSliceOrNull(globalThis: globalThis) ?? ""
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
    private let globalThis: JSGlobalObject
    private let returnValues: JSValue
    private var index: Int32 = 0
    private let length: Int32

    public init(globalThis: JSGlobalObject, returnValues: JSValue) {
        this.globalThis = globalThis
        this.returnValues = returnValues
        this.length = returnValues.getLength(globalThis: globalThis)
    }

    public func next(): ?JSValue {
        if (index >= length) { return None }
        let item = returnValues.getIndex(globalThis: globalThis, index: index)
        index += 1
        return item
    }
}
