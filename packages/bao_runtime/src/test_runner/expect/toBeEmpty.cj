// 严格翻译自: src/runtime/test_runner/expect/toBeEmpty.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toBeEmpty() - 检查值是否为空（空字符串、空数组、空对象等）
/// 用法: expect(received).toBeEmpty()
public func toBeEmpty(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeEmpty", matcherParamsFmt: "")

    `this`.incrementExpectCallCounter()

    let not = `this`.flags.not
    var pass = false

    if (value.isString()) {
        let s = value.toSliceOrNull(globalThis.globalThis)
        // defer { s.deinit() }
        if (s.isSome()) {
            pass = s.getOrThrow().size == 0
        }
    } else if (value.jsType().isArray()) {
        pass = value.getLength(globalThis.globalThis) == 0
    } else if (value.isObject()) {
        pass = value.getLength(globalThis.globalThis) == 0
    } else {
        pass = value.isUndefinedOrNull()
    }

    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    let received = value.toFmt(formatter)

    if (not) {
        let signature = Expect.getSignature("toBeEmpty", "", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
    }

    let signature = Expect.getSignature("toBeEmpty", "", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
}
