// 严格翻译自: src/runtime/test_runner/expect/toContainKey.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toContainKey() - 检查对象是否包含指定键
/// 用法: expect(received).toContainKey(expected)
public func toContainKey(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toContainKey() takes 1 argument")
    }

    `this`.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toContainKey", matcherParamsFmt: "<green>expected<r>")
    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }

    let not = `this`.flags.not
    if (!value.isObject()) {
        return globalThis.throwInvalidArgumentsValue("Expected value must be an object")
    }

    let global = globalThis.globalThis
    var pass = value.hasProperty(expected.toSliceOrNull(global).getOrThrow())

    if (not) { pass = !pass }
    if (pass) { return thisValue }

    // 处理失败
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)
    if (not) {
        let receivedFmt = value.toFmt(formatter)
        let expectedLine = "Expected to not contain: <green>{f}<r>\nReceived: <red>{f}<r>\n"
        let signature = Expect.getSignature("toContainKey", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine, args: [expectedFmt, receivedFmt])
    }

    let expectedLine = "Expected to contain: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature("toContainKey", "<green>expected<r>", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
