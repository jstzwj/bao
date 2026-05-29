// 严格翻译自: src/runtime/test_runner/expect/toEqualIgnoringWhitespace.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// 去除多余空白（将连续空白替换为单个空格，并去除首尾空白）
private func normalizeWhitespace(s: String): String {
    var result = ""
    var inWhitespace = false
    for (c in s.runes()) {
        if (c == Rune(0x20) || c == Rune(0x09) || c == Rune(0x0A) || c == Rune(0x0D)) {
            if (!inWhitespace) {
                result = result + " "
                inWhitespace = true
            }
        } else {
            result = result + c.toString()
            inWhitespace = false
        }
    }
    result.trimEnd().trimStart()
}

/// toEqualIgnoringWhitespace() - 检查去除空白后是否相等
/// 用法: expect(received).toEqualIgnoringWhitespace(expected)
public func toEqualIgnoringWhitespace(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toEqualIgnoringWhitespace() requires 1 argument")
    }

    `this`.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()

    if (!expected.isString()) {
        return globalThis.throw_("toEqualIgnoringWhitespace() requires the first argument to be a string")
    }

    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toEqualIgnoringWhitespace", matcherParamsFmt: "<green>expected<r>")

    if (!value.isString()) {
        let formatter = ConsoleFormatter()
        // defer { formatter.deinit() }
        return globalThis.throw_("Received value must be a string: {f}", args: [value.toFmt(formatter)])
    }

    let global = globalThis.globalThis
    let valueStr = value.toSliceOrNull(global)
    let expectedStr = expected.toSliceOrNull(global)

    // 去除空白后比较
    let normalizedValue = if (valueStr.isSome()) { normalizeWhitespace(valueStr.getOrThrow()) } else { "" }
    let normalizedExpected = if (expectedStr.isSome()) { normalizeWhitespace(expectedStr.getOrThrow()) } else { "" }

    let not = `this`.flags.not
    var pass = normalizedValue == normalizedExpected

    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)

    if (not) {
        let signature = Expect.getSignature("toEqualIgnoringWhitespace", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected: not <green>{f}<r>\nReceived: <red>{f}<r>\n",
            args: [expectedFmt, valueFmt])
    }

    let signature = Expect.getSignature("toEqualIgnoringWhitespace", "<green>expected<r>", false)
    return `this`.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected: <green>{f}<r>\nReceived: <red>{f}<r>\n",
        args: [expectedFmt, valueFmt])
}
