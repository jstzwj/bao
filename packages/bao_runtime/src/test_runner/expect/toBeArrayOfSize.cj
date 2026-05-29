// 严格翻译自: src/runtime/test_runner/expect/toBeArrayOfSize.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toBeArrayOfSize() - 检查值是否为指定大小的数组
/// 用法: expect(received).toBeArrayOfSize(size)
public func toBeArrayOfSize(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toBeArrayOfSize() requires 1 argument")
    }

    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeArrayOfSize", matcherParamsFmt: "")

    let size = arguments[0]
    size.ensureStillAlive()

    if (!size.isAnyInt()) {
        return globalThis.throwInvalidArgumentsValue("toBeArrayOfSize() requires the first argument to be a number")
    }

    `this`.incrementExpectCallCounter()

    let not = `this`.flags.not
    var pass = value.jsType().isArray() && Int32(value.getLength(globalThis.globalThis)) == size.toInt32()

    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    let formatter = ConsoleFormatter()
    let received = value.toFmt(formatter)

    if (not) {
        let signature = Expect.getSignature("toBeArrayOfSize", "", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
    }

    let signature = Expect.getSignature("toBeArrayOfSize", "", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
}
