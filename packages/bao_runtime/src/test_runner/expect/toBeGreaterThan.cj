// 严格翻译自: src/runtime/test_runner/expect/toBeGreaterThan.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toBeGreaterThan() - 检查值是否大于期望值
/// 用法: expect(received).toBeGreaterThan(expected)
public func toBeGreaterThan(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toBeGreaterThan() requires 1 argument")
    }

    `this`.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()

    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeGreaterThan", matcherParamsFmt: "<green>expected<r>")

    let not = `this`.flags.not
    var pass = false

    if (value.isNumber() && expected.isNumber()) {
        pass = value.asNumber() > expected.asNumber()
    } else if (value.isBigInt() && expected.isBigInt()) {
        pass = value.toBigInt(globalThis: globalThis) > expected.toBigInt(globalThis: globalThis)
    }

    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    let expectedFmt = expected.toFmt(formatter)
    let valueFmt = value.toFmt(formatter)

    if (not) {
        let signature = Expect.getSignature("toBeGreaterThan", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected: not <green>{f}<r>\nReceived: <red>{f}<r>\n",
            args: [expectedFmt, valueFmt])
    }

    let signature = Expect.getSignature("toBeGreaterThan", "<green>expected<r>", false)
    return `this`.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected: <green>{f}<r>\nReceived: <red>{f}<r>\n",
        args: [expectedFmt, valueFmt])
}
