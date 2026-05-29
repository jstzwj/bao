// 严格翻译自: src/runtime/test_runner/expect/toHaveNthReturnedWith.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toHaveNthReturnedWith() - 检查mock函数第N次返回的值
/// 用法: expect(mockFn).toHaveNthReturnedWith(n, expected)
public func toHaveNthReturnedWith(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveNthReturnedWith", matcherParamsFmt: "<green>n<r>, <green>expected<r>")

    let argsArray = callFrame.argumentsAsArray(2)
    let nthArg = argsArray[0]
    let expected = argsArray[1]

    // 验证 n 是数字
    if (!nthArg.isAnyInt()) {
        return globalThis.throwInvalidArgumentsValue("toHaveNthReturnedWith() first argument must be an integer")
    }

    let n = nthArg.toInt32()
    if (n <= 0) {
        return globalThis.throwInvalidArgumentsValue("toHaveNthReturnedWith() n must be greater than 0")
    }

    `this`.incrementExpectCallCounter()
    let global = globalThis.globalThis
    let returns = JSMockFunction.getReturnValues(globalThis: global, value: value)
    if (!returns.jsType().isArray()) {
        let formatter = ConsoleFormatter()
        // defer { formatter.deinit() }
        return globalThis.throw_("Expected value must be a mock function: {f}", args: [value.toFmt(formatter)])
    }

    let callsCount: UInt32 = UInt32(returns.getLength(global))
    let index: UInt32 = UInt32(n - 1) // 转为 0-based index

    var pass = false
    var nthReturnValue: JsValue = JsValue.jsUndefined()
    var nthCallThrew = false
    var nthErrorValue: JsValue = JsValue.jsUndefined()
    var nthCallExists = false

    if (index < callsCount) {
        nthCallExists = true
        let nthResult = returns.getIndex(global, index)
        if (nthResult.isObject()) {
            let resultType = nthResult.get(global, "type") ?? JsValue.jsUndefined()
            if (resultType.isString()) {
                let typeStr = resultType.toString()
                if (typeStr == "return") {
                    nthReturnValue = nthResult.get(global, "value") ?? JsValue.jsUndefined()
                    if (nthReturnValue.jestDeepEquals(expected, globalThis: globalThis)) {
                        pass = true
                    }
                } else if (typeStr == "throw") {
                    nthCallThrew = true
                    nthErrorValue = nthResult.get(global, "value") ?? JsValue.jsUndefined()
                }
            }
        }
    }

    if (pass != `this`.flags.not) {
        return JsValue.jsUndefined()
    }

    // 处理失败
    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }

    let signature = Expect.getSignature("toHaveNthReturnedWith", "<green>n<r>, <green>expected<r>", false)

    if (`this`.flags.not) {
        let notSignature = Expect.getSignature("toHaveNthReturnedWith", "<green>n<r>, <green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: notSignature,
            fmt: "\n\nExpected mock function not to have returned on call {d}: <green>{f}<r>\nBut it did.\n",
            args: [n, expected.toFmt(formatter)])
    }

    if (!nthCallExists) {
        let pluralSuffix = if (callsCount == 1) { "" } else { "s" }
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nThe mock function was called {d} time{s}, but call {d} was requested.\n",
            args: [callsCount, pluralSuffix, n])
    }

    if (nthCallThrew) {
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nCall {d} threw an error: <red>{f}<r>\n",
            args: [n, nthErrorValue.toFmt(formatter)])
    }

    // 如果可能则显示 diff
    if (expected.isString() && nthReturnValue.isString()) {
        let diffFormat = DiffFormatter(nthReturnValue, expected, globalThis, false)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nCall {d}:\n{f}\n",
            args: [n, diffFormat])
    }

    return `this`.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nCall {d}:\nExpected: <green>{f}<r>\nReceived: <red>{f}<r>",
        args: [n, expected.toFmt(formatter), nthReturnValue.toFmt(formatter)])
}
