// 严格翻译自: src/runtime/test_runner/expect/toHaveReturned.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner
import bao_jsc.*

/// toHaveReturned() - 检查mock函数是否有返回
/// 用法: expect(mockFn).toHaveReturned()
public func toHaveReturned(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments = callFrame.arguments()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveReturned", matcherParamsFmt: "<green>expected<r>")

    this.incrementExpectCallCounter()

    var returns = Expect.mock.jestMockIterator(globalThis: globalThis, value: value)

    let expectedSuccessCount: Int32 = if (arguments.length > 0 && !arguments[0].isUndefined()) {
        globalThis.throwInvalidArguments("toHaveReturned() must not have an argument").toInt32()
    } else {
        1
    }

    var pass = false

    var actualSuccessCount: Int32 = 0
    var totalCallCount: Int32 = 0
    while (let Some(item) <- returns.next()) {
        let returnType = Expect.mock.jestMockReturnObject_type(globalThis: globalThis, item: item)
        if (returnType == MockReturnType.return_) {
            actualSuccessCount++
        }
        totalCallCount++
    }

    pass = actualSuccessCount >= expectedSuccessCount

    let not = this.flags.not
    if (not) { pass = !pass }
    if (pass) { return JSValue.jsUndefined }

    let signature = Expect.getSignature(matcherName: "toHaveReturned", args: "<green>expected<r>", not: not)
    var str = ">= "
    var spc = "   "
    if (not) {
        str = "< "
        spc = "  "
    }

    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected number of succesful returns: {s}<green>{d}<r>\nReceived number of succesful returns: {s}<red>{d}<r>\nReceived number of calls:             {s}<red>{d}<r>\n",
        args: [str, expectedSuccessCount, spc, actualSuccessCount, spc, totalCallCount])
}

/// toHaveReturnedTimes() - 检查mock函数返回的次数
/// 用法: expect(mockFn).toHaveReturnedTimes(times)
public func toHaveReturnedTimes(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments = callFrame.arguments()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveReturnedTimes", matcherParamsFmt: "<green>expected<r>")

    this.incrementExpectCallCounter()

    var returns = Expect.mock.jestMockIterator(globalThis: globalThis, value: value)

    if (arguments.length < 1 || !arguments[0].isUInt32AsAnyInt() ){
        return globalThis.throwInvalidArguments("toHaveReturnedTimes() requires 1 non-negative integer argument")
    }

    let expectedSuccessCount = arguments[0].coerceInt32(globalThis: globalThis)

    var pass = false

    var actualSuccessCount: Int32 = 0
    var totalCallCount: Int32 = 0
    while (let Some(item) <- returns.next()) {
        let returnType = Expect.mock.jestMockReturnObject_type(globalThis: globalThis, item: item)
        if (returnType == MockReturnType.return_) {
            actualSuccessCount++
        }
        totalCallCount++
    }

    pass = actualSuccessCount == expectedSuccessCount

    let not = this.flags.not
    if (not) { pass = !pass }
    if (pass) { return JSValue.jsUndefined }

    let signature = Expect.getSignature(matcherName: "toHaveReturnedTimes", args: "<green>expected<r>", not: not)
    var str = "!= "
    var spc = "   "
    if (!not) {
        str = "== "
    }

    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected number of succesful returns: {s}<green>{d}<r>\nReceived number of succesful returns: {s}<red>{d}<r>\nReceived number of calls:             {s}<red>{d}<r>\n",
        args: [str, expectedSuccessCount, spc, actualSuccessCount, spc, totalCallCount])
}
