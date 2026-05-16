// 严格翻译自: src/runtime/test_runner/expect/toBeCloseTo.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner
import bao_jsc.*

/// toBeCloseTo() - 检查浮点数是否近似相等
/// 用法: expect(received).toBeCloseTo(expected, precision?)
public func toBeCloseTo(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let thisArguments = callFrame.argumentsOld(2)
    let arguments = thisArguments.slice()

    this.incrementExpectCallCounter()

    if (arguments.length < 1) {
        return globalThis.throwInvalidArguments("toBeCloseTo() requires at least 1 argument. Expected value must be a number")
    }

    let expected_ = arguments[0]
    if (!expected_.isNumber()) {
        return globalThis.throwInvalidArgumentType("toBeCloseTo", argName: "expected", expectedType: "number")
    }

    var precision: Float64 = 2.0
    if (arguments.length > 1 ){
        let precision_ = arguments[1]
        if (!precision_.isNumber()) {
            return globalThis.throwInvalidArgumentType("toBeCloseTo", argName: "precision", expectedType: "number")
        }
        precision = precision_.asNumber()
    }

    let received_: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeCloseTo", matcherParamsFmt: "<green>expected<r>, precision")
    if (!received_.isNumber()) {
        return globalThis.throwInvalidArgumentType("expect", argName: "received", expectedType: "number")
    }

    var expected = expected_.asNumber()
    var received = received_.asNumber()

    if (std.math.isNegativeInf(expected)) {
        expected = -expected
    }

    if (std.math.isNegativeInf(received)) {
        received = -received
    }

    if (std.math.isPositiveInf(expected) && std.math.isPositiveInf(received)) {
        return JSValue.jsUndefined
    }

    let expectedDiff = bun.pow(10.0, -precision) / 2.0
    let actualDiff = Float64.abs(received - expected)
    var pass = actualDiff < expectedDiff

    let not = this.flags.not
    if (not) { pass = !pass }

    if (pass) { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }

    let expectedFmt = expected_.toFmt(formatter)
    let receivedFmt = received_.toFmt(formatter)

    let expectedLine = "Expected: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let expectedPrecision = "Expected precision: {d}\n"
    let expectedDifference = "Expected difference: \\< <green>{d}<r>\n"
    let receivedDifference = "Received difference: <red>{d}<r>\n"

    let suffixFmt = "\n\n" + expectedLine + receivedLine + "\n" + expectedPrecision + expectedDifference + receivedDifference

    if (not) {
        let signature = Expect.getSignature(matcherName: "toBeCloseTo", args: "<green>expected<r>, precision", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: suffixFmt, args: [expectedFmt, receivedFmt, precision, expectedDiff, actualDiff])
    }

    let signature = Expect.getSignature(matcherName: "toBeCloseTo", args: "<green>expected<r>, precision", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: suffixFmt, args: [expectedFmt, receivedFmt, precision, expectedDiff, actualDiff])
}
