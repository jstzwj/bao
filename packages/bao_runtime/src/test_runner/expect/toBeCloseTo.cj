// 严格翻译自: src/runtime/test_runner/expect/toBeCloseTo.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*
import std.math.*

/// toBeCloseTo() - 检查浮点数是否近似相等
/// 用法: expect(received).toBeCloseTo(expected, precision?)
public func toBeCloseTo(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let thisArguments = callFrame.argumentsOld(2)
    let arguments = thisArguments.slice()

    `this`.incrementExpectCallCounter()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toBeCloseTo() requires at least 1 argument. Expected value must be a number")
    }

    let expected_ = arguments[0]
    if (!expected_.isNumber()) {
        return globalThis.throwInvalidArgumentsValue("Expected expected to be a number for 'toBeCloseTo'.")
    }

    var precision: Float64 = 2.0
    if (arguments.size > 1 ){
        let precision_ = arguments[1]
        if (!precision_.isNumber()) {
            return globalThis.throwInvalidArgumentsValue("Expected precision to be a number for 'toBeCloseTo'.")
        }
        precision = precision_.asNumber()
    }

    let received_: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeCloseTo", matcherParamsFmt: "<green>expected<r>, precision")
    if (!received_.isNumber()) {
        return globalThis.throwInvalidArgumentsValue("Expected received to be a number for 'expect'.")
    }

    var expected = expected_.asNumber()
    var received = received_.asNumber()

    if ((expected == -Float64.Inf)) {
        expected = -expected
    }

    if ((received == -Float64.Inf)) {
        received = -received
    }

    if ((expected == Float64.Inf) && (received == Float64.Inf)) {
        return JsValue.jsUndefined()
    }

    let expectedDiff = pow(10.0, -precision) / 2.0
    let actualDiff = if (received - expected >= 0.0) { received - expected } else { expected - received }
    var pass = actualDiff < expectedDiff

    let not = `this`.flags.not
    if (not) { pass = !pass }

    if (pass) { return JsValue.jsUndefined() }

    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }

    let expectedFmt = expected_.toFmt(formatter)
    let receivedFmt = received_.toFmt(formatter)

    let expectedLine = "Expected: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let expectedPrecision = "Expected precision: {d}\n"
    let expectedDifference = "Expected difference: \\< <green>{d}<r>\n"
    let receivedDifference = "Received difference: <red>{d}<r>\n"

    let suffixFmt = "\n\n" + expectedLine + receivedLine + "\n" + expectedPrecision + expectedDifference + receivedDifference

    if (not) {
        let signature = Expect.getSignature("toBeCloseTo", "<green>expected<r>, precision", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: suffixFmt, args: [expectedFmt, receivedFmt, precision, expectedDiff, actualDiff])
    }

    let signature = Expect.getSignature("toBeCloseTo", "<green>expected<r>, precision", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: suffixFmt, args: [expectedFmt, receivedFmt, precision, expectedDiff, actualDiff])
}
