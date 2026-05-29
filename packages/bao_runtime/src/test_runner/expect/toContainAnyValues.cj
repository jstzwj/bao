// 严格翻译自: src/runtime/test_runner/expect/toContainAnyValues.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toContainAnyValues() - 检查对象是否包含任一指定值
/// 用法: expect(received).toContainAnyValues(expected)
public func toContainAnyValues(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toContainAnyValues() takes 1 argument")
    }

    `this`.incrementExpectCallCounter()

    let expected = arguments[0]
    if (!expected.jsType().isArray()) {
        return globalThis.throwInvalidArgumentsValue("Expected expected to be a array for 'toContainAnyValues'.")
    }
    expected.ensureStillAlive()
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toContainAnyValues", matcherParamsFmt: "<green>expected<r>")

    let not = `this`.flags.not
    var pass = false
    let global = globalThis.globalThis

    if (!value.isUndefinedOrNull()) {
        let values = JsValue.values(value, global)
        var itr = expected.arrayIterator(global)
        let count = values.getLength(global)

        while (let Some(item) <- itr.next()) {
            var i: UInt32 = 0
            while (i < UInt32(count)) {
                let key = values.getIndex(global, i)
                if (key.jestDeepEquals(item, globalThis: globalThis)) {
                    pass = true
                    break  // outer
                }
                i++
            }
            if (pass) { break }
        }
    }

    if (not) { pass = !pass }
    if (pass) { return thisValue }

    // 处理失败
    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)
    if (not) {
        let receivedFmt = value.toFmt(formatter)
        let expectedLine = "Expected to not contain any of the following values: <green>{f}<r>\nReceived: <red>{f}<r>\n"
        return `this`.throw_(globalThis: globalThis, signature: Expect.getSignature("toContainAnyValues", "<green>expected<r>", true),
            fmt: "\n\n" + expectedLine, args: [expectedFmt, receivedFmt])
    }

    let expectedLine = "Expected to contain any of the following values: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    return `this`.throw_(globalThis: globalThis, signature: Expect.getSignature("toContainAnyValues", "<green>expected<r>", false),
        fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
