// 严格翻译自: src/runtime/test_runner/expect/toBeInstanceOf.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toBeInstanceOf() - 检查值是否为指定类的实例
/// 用法: expect(received).toBeInstanceOf(Expected)
public func toBeInstanceOf(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toBeInstanceOf() requires 1 argument")
    }

    `this`.incrementExpectCallCounter()
    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }

    let expectedValue = arguments[0]
    if (!expectedValue.isConstructor()) {
        return globalThis.throw_("Expected value must be a function: {f}", args: [expectedValue.toFmt(formatter)])
    }
    expectedValue.ensureStillAlive()

    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeInstanceOf", matcherParamsFmt: "<green>expected<r>")

    let not = `this`.flags.not
    var pass = value.isInstanceOf(globalThis.globalThis, expectedValue)
    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    // 处理失败
    let expectedFmt = expectedValue.toFmt(formatter)
    let valueFmt = value.toFmt(formatter)
    if (not) {
        let expectedLine = "Expected constructor: not <green>{f}<r>\n"
        let receivedLine = "Received value: <red>{f}<r>\n"
        let signature = Expect.getSignature("toBeInstanceOf", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
    }

    let expectedLine = "Expected constructor: <green>{f}<r>\n"
    let receivedLine = "Received value: <red>{f}<r>\n"
    let signature = Expect.getSignature("toBeInstanceOf", "<green>expected<r>", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
