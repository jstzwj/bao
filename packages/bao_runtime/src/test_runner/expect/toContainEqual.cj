// 严格翻译自: src/runtime/test_runner/expect/toContainEqual.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toContainEqual() - 检查数组是否深度包含期望值
/// 用法: expect(received).toContainEqual(expected)
public func toContainEqual(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toContainEqual() takes 1 argument")
    }

    `this`.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toContainEqual", matcherParamsFmt: "<green>expected<r>")

    let not = `this`.flags.not
    var pass = false
    let global = globalThis.globalThis

    let valueType = value.jsType()
    let expectedType = expected.jsType()

    if (valueType.isArray()) {
        var itr = value.arrayIterator(global)
        while (let Some(item) <- itr.next()) {
            if (item.jestDeepEquals(expected, globalThis: globalThis)) {
                pass = true
                break
            }
        }
    } else if (valueType.isStringLike() && expectedType.isStringLike()) {
        let valueString = value.toSliceOrNull(global)
        let expectedString = expected.toSliceOrNull(global)

        if (valueString.isSome() && expectedString.isSome()) {
            pass = valueString.getOrThrow().contains(expectedString.getOrThrow())
        }
    } else if (value.isIterable(global)) {
        var expectedEntry = ExpectedEntry(globalThis, expected, pass)
        value.forEach(global, expectedEntry, { vm, globalObject, entry_, item =>
            let entryOpt = entry_ as ExpectedEntry
            if (entryOpt.isSome()) {
                let entry = entryOpt.getOrThrow()
                if (item.jestDeepEquals(entry.expected, globalThis: globalThis)) {
                    entry.pass = true
                }
            }
        })
    } else {
        return globalThis.throw_("Received value must be an array type, or both received and expected values must be strings.")
    }

    if (not) { pass = !pass }
    if (pass) { return thisValue }

    // 处理失败
    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)
    if (not) {
        let expectedLine = "Expected to not contain: <green>{f}<r>\n"
        let signature = Expect.getSignature("toContainEqual", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine, args: [expectedFmt])
    }

    let expectedLine = "Expected to contain: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature("toContainEqual", "<green>expected<r>", false)
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
