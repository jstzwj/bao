// 严格翻译自: src/runtime/test_runner/expect/toHaveLength.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*
import std.math.*

/// toHaveLength() - 检查值是否具有指定长度
/// 用法: expect(received).toHaveLength(expected)
public func toHaveLength(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toHaveLength() takes 1 argument")
    }

    `this`.incrementExpectCallCounter()

    let expected: JsValue = arguments[0]
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveLength", matcherParamsFmt: "<green>expected<r>")

    if (!value.isObject() && !value.isString()) {
        let fmt = ConsoleFormatter()
        return globalThis.throw_("Received value does not have a length property: {f}", args: [value.toFmt(fmt)])
    }

    if (!expected.isNumber()) {
        let fmt = ConsoleFormatter()
        return globalThis.throw_("Expected value must be a non-negative integer: {f}", args: [expected.toFmt(fmt)])
    }

    let expectedLength: Float64 = expected.asNumber()
    if (round(expectedLength) != expectedLength || expectedLength == Float64.Inf || expectedLength == -Float64.Inf || expectedLength.isNaN() || expectedLength < 0.0) {
        let fmt = ConsoleFormatter()
        return globalThis.throw_("Expected value must be a non-negative integer: {f}", args: [expected.toFmt(fmt)])
    }

    let not = `this`.flags.not
    var pass = false

    let actualLength = value.getLengthIfPropertyExistsInternal(globalThis.globalThis)

    if (actualLength == Int64.Max) {
        let fmt = ConsoleFormatter()
        return globalThis.throw_("Received value does not have a length property: {f}", args: [value.toFmt(fmt)])
    } else if (actualLength < 0) {
        return globalThis.throw_("Received value has non-number length property: {}", args: [Float64(actualLength)])
    }

    if (Float64(actualLength) == expectedLength) {
        pass = true
    }

    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    // 处理失败
    if (not) {
        let expectedLine = "Expected length: not <green>{d}<r>\n"
        let signature = Expect.getSignature("toHaveLength", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine, args: [expectedLength])
    }

    let expectedLine = "Expected length: <green>{d}<r>\n"
    let receivedLine = "Received length: <red>{d}<r>\n"
    let signature = Expect.getSignature("toHaveLength", "<green>expected<r>", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedLength, actualLength])
}
