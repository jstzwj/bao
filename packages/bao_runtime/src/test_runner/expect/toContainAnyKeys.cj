// 严格翻译自: src/runtime/test_runner/expect/toContainAnyKeys.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toContainAnyKeys() - 检查对象是否包含任一指定键
/// 用法: expect(received).toContainAnyKeys(expected)
public func toContainAnyKeys(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toContainAnyKeys() takes 1 argument")
    }

    `this`.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toContainAnyKeys", matcherParamsFmt: "<green>expected<r>")

    if (!expected.jsType().isArray()) {
        return globalThis.throwInvalidArgumentsValue("Expected expected to be a array for 'toContainAnyKeys'.")
    }

    let not = `this`.flags.not
    var pass = false
    let global = globalThis.globalThis

    let count = expected.getLength(global)

    if (value.isObject()) {
        var i: UInt32 = 0
        while (i < UInt32(count)) {
            let key = expected.getIndex(global, i)

            if (value.hasOwnProperty(global, key)) {
                pass = true
                break
            }
            i++
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
        let expectedLine = "Expected to not contain: <green>{f}<r>\nReceived: <red>{f}<r>\n"
        let signature = Expect.getSignature("toContainAnyKeys", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine, args: [expectedFmt, receivedFmt])
    }

    let expectedLine = "Expected to contain: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature("toContainAnyKeys", "<green>expected<r>", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
