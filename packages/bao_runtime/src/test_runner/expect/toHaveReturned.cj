// 严格翻译自: src/runtime/test_runner/expect/toHaveReturned.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toHaveReturned() - 检查mock函数是否有返回
/// 用法: expect(mockFn).toHaveReturned()
public func toHaveReturned(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments = callFrame.argumentsAsArray(1)
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveReturned", matcherParamsFmt: "<green>expected<r>")

    `this`.incrementExpectCallCounter()

    let global = globalThis.globalThis
    let returns = JSMockFunction.getReturnValues(globalThis: global, value: value)
    if (!returns.jsType().isArray()) {
        let formatter = ConsoleFormatter()
        return globalThis.throw_("Expected value must be a mock function: {f}", args: [value.toFmt(formatter)])
    }

    let expectedSuccessCount: Int32 = if (arguments.size > 0 && !arguments[0].isUndefined()) {
        return globalThis.throwInvalidArgumentsValue("toHaveReturned() must not have an argument")
    } else {
        1
    }

    var pass = false
    let callsCount = UInt32(returns.getLength(global))

    var actualSuccessCount: Int32 = 0
    var totalCallCount: Int32 = 0
    var i: UInt32 = 0
    while (i < callsCount) {
        let item = returns.getIndex(global, i)
        if (item.isObject()) {
            let resultType = item.get(global, "type") ?? JsValue.jsUndefined()
            if (resultType.isString()) {
                let typeStr = resultType.toString()
                if (typeStr == "return") {
                    actualSuccessCount++
                }
            }
        }
        totalCallCount++
        i++
    }

    pass = actualSuccessCount >= expectedSuccessCount

    let not = `this`.flags.not
    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    let signature = Expect.getSignature("toHaveReturned", "<green>expected<r>", not)
    var str = ">= "
    var spc = "   "
    if (not) {
        str = "< "
        spc = "  "
    }

    return `this`.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected number of successful returns: {s}<green>{d}<r>\nReceived number of successful returns: {s}<red>{d}<r>\nReceived number of calls:             {s}<red>{d}<r>\n",
        args: [str, expectedSuccessCount, spc, actualSuccessCount, spc, totalCallCount])
}

/// toHaveReturnedTimes() - 检查mock函数返回的次数
/// 用法: expect(mockFn).toHaveReturnedTimes(times)
public func toHaveReturnedTimes(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments = callFrame.argumentsAsArray(1)
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveReturnedTimes", matcherParamsFmt: "<green>expected<r>")

    `this`.incrementExpectCallCounter()

    let global = globalThis.globalThis
    let returns = JSMockFunction.getReturnValues(globalThis: global, value: value)
    if (!returns.jsType().isArray()) {
        let formatter = ConsoleFormatter()
        return globalThis.throw_("Expected value must be a mock function: {f}", args: [value.toFmt(formatter)])
    }

    if (arguments.size < 1 || !arguments[0].isAnyInt()) {
        return globalThis.throwInvalidArgumentsValue("toHaveReturnedTimes() requires 1 non-negative integer argument")
    }

    let expectedSuccessCount = arguments[0].toInt32()
    let callsCount = UInt32(returns.getLength(global))

    var pass = false
    var actualSuccessCount: Int32 = 0
    var totalCallCount: Int32 = 0
    var i: UInt32 = 0
    while (i < callsCount) {
        let item = returns.getIndex(global, i)
        if (item.isObject()) {
            let resultType = item.get(global, "type") ?? JsValue.jsUndefined()
            if (resultType.isString()) {
                let typeStr = resultType.toString()
                if (typeStr == "return") {
                    actualSuccessCount++
                }
            }
        }
        totalCallCount++
        i++
    }

    pass = actualSuccessCount == expectedSuccessCount

    let not = `this`.flags.not
    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    let signature = Expect.getSignature("toHaveReturnedTimes", "<green>expected<r>", not)
    var str = "!= "
    var spc = "   "
    if (!not) {
        str = "== "
    }

    return `this`.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected number of successful returns: {s}<green>{d}<r>\nReceived number of successful returns: {s}<red>{d}<r>\nReceived number of calls:             {s}<red>{d}<r>\n",
        args: [str, expectedSuccessCount, spc, actualSuccessCount, spc, totalCallCount])
}
