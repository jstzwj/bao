// 严格翻译自: src/runtime/test_runner/expect/toEndWith.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner
import bao_jsc.*

/// toEndWith() - 检查字符串是否以指定后缀结尾
/// 用法: expect(received).toEndWith(expected)
public func toEndWith(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.length < 1) {
        return globalThis.throwInvalidArguments("toEndWith() requires 1 argument")
    }

    let expected = arguments[0]
    expected.ensureStillAlive()

    if (!expected.isString()) {
        return globalThis.throw_("toEndWith() requires the first argument to be a string")
    }

    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toEndWith", matcherParamsFmt: "<green>expected<r>")

    this.incrementExpectCallCounter()

    var pass = value.isString()
    if (pass) {
        let valueString = value.toSliceOrNull(globalThis: globalThis)
        defer { valueString.deinit() }
        let expectedString = expected.toSliceOrNull(globalThis: globalThis)
        defer { expectedString.deinit() }
        pass = strings.endsWith(valueString.slice(), expectedString.slice()) || expectedString.length == 0
    }

    let not = this.flags.not
    if (not) { pass = !pass }

    if (pass) { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)

    if (not) {
        let expectedLine = "Expected to not end with: <green>{f}<r>\n"
        let receivedLine = "Received: <red>{f}<r>\n"
        let signature = Expect.getSignature(matcherName: "toEndWith", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
    }

    let expectedLine = "Expected to end with: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature(matcherName: "toEndWith", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
