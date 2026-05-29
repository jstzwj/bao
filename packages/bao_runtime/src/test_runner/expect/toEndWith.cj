// 严格翻译自: src/runtime/test_runner/expect/toEndWith.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toEndWith() - 检查字符串是否以指定后缀结尾
/// 用法: expect(received).toEndWith(expected)
public func toEndWith(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toEndWith() requires 1 argument")
    }

    let expected = arguments[0]
    expected.ensureStillAlive()

    if (!expected.isString()) {
        return globalThis.throw_("toEndWith() requires the first argument to be a string")
    }

    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toEndWith", matcherParamsFmt: "<green>expected<r>")

    `this`.incrementExpectCallCounter()
    let global = globalThis.globalThis

    var pass = value.isString()
    if (pass) {
        let valueString = value.toSliceOrNull(global)
        let expectedString = expected.toSliceOrNull(global)
        if (expectedString.isSome() && expectedString.getOrThrow().size == 0) {
            pass = true
        } else if (valueString.isSome() && expectedString.isSome()) {
            pass = valueString.getOrThrow().endsWith(expectedString.getOrThrow())
        } else {
            pass = false
        }
    }

    let not = `this`.flags.not
    if (not) { pass = !pass }

    if (pass) { return JsValue.jsUndefined() }

    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)

    if (not) {
        let expectedLine = "Expected to not end with: <green>{f}<r>\n"
        let receivedLine = "Received: <red>{f}<r>\n"
        let signature = Expect.getSignature("toEndWith", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
    }

    let expectedLine = "Expected to end with: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature("toEndWith", "<green>expected<r>", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
