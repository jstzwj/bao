// 严格翻译自: src/runtime/test_runner/expect/toContain.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toContain() - 检查值是否包含期望值
/// 用法: expect(received).toContain(expected)
public func toContain(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toContain() takes 1 argument")
    }

    `this`.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toContain", matcherParamsFmt: "<green>expected<r>")

    let not = `this`.flags.not
    var pass = false
    let global = globalThis.globalThis

    if (value.isArray()) {
        var itr = value.arrayIterator(global)
        while (let Some(item) <- itr.next()) {
            if (item.isSameValue(expected, global)) {
                pass = true
                break
            }
        }
    } else if (value.isStringLiteral() && expected.isStringLiteral()) {
        let valueString = value.toSliceOrNull(global)
        let expectedString = expected.toSliceOrNull(global)

        if (expectedString.isSome() && expectedString.getOrThrow().size == 0) {
            pass = true
        } else if (valueString.isSome() && expectedString.isSome() && valueString.getOrThrow().contains(expectedString.getOrThrow())) {
            pass = true
        } else if (valueString.isSome() && valueString.getOrThrow().size == 0 && expectedString.isSome() && expectedString.getOrThrow().size == 0) {
            pass = true
        }
    } else if (value.isIterable(global)) {
        var expectedEntry = ExpectedEntry(globalThis, expected, pass)
        value.forEach(global, expectedEntry, { vm, globalObject, entry_, item =>
            let entryOpt = entry_ as ExpectedEntry
            if (entryOpt.isSome()) {
                let entry = entryOpt.getOrThrow()
                if (item.isSameValue(entry.expected, globalObject)) {
                    entry.pass = true
                }
            }
        })
    } else {
        return globalThis.throw_("Received value must be an array type, or both received and expected values must be strings.")
    }

    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    // 处理失败
    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)
    if (not) {
        let receivedFmt = value.toFmt(formatter)
        let expectedLine = "Expected to not contain: <green>{f}<r>\nReceived: <red>{f}<r>\n"
        let signature = Expect.getSignature("toContain", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine, args: [expectedFmt, receivedFmt])
    }

    let expectedLine = "Expected to contain: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature("toContain", "<green>expected<r>", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}

// 用于 forEach 回调的上下文
private class ExpectedEntry {
    var globalThis: JSGlobalObject
    var expected: JsValue
    var pass: Bool

    public init(globalThis: JSGlobalObject, expected: JsValue, pass: Bool) {
        this.globalThis = globalThis
        this.expected = expected
        this.pass = pass
    }
}
