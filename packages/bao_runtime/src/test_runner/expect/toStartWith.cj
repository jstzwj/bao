// 严格翻译自: src/runtime/test_runner/expect/toStartWith.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toStartWith() - 检查字符串是否以指定前缀开头
/// 用法: expect(received).toStartWith(expected)
public func toStartWith(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toStartWith() requires 1 argument")
    }

    let expected = arguments[0]
    expected.ensureStillAlive()

    if (!expected.isString()) {
        return globalThis.throw_("toStartWith() requires the first argument to be a string")
    }

    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toStartWith", matcherParamsFmt: "<green>expected<r>")

    `this`.incrementExpectCallCounter()
    let global = globalThis.globalThis

    var pass = value.isString()
    if (pass) {
        let valueString = value.toSliceOrNull(global)
        let expectedString = expected.toSliceOrNull(global)
        if (expectedString.isSome() && expectedString.getOrThrow().size == 0) {
            pass = true
        } else if (valueString.isSome() && expectedString.isSome()) {
            pass = valueString.getOrThrow().startsWith(expectedString.getOrThrow())
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
        let expectedLine = "Expected to not start with: <green>{f}<r>\n"
        let receivedLine = "Received: <red>{f}<r>\n"
        let signature = Expect.getSignature("toStartWith", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
    }

    let expectedLine = "Expected to start with: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature("toStartWith", "<green>expected<r>", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
