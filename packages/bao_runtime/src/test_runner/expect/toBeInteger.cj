// 严格翻译自: src/runtime/test_runner/expect/toBeInteger.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toBeInteger() - 检查值是否为整数
/// 用法: expect(received).toBeInteger()
public func toBeInteger(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeInteger", matcherParamsFmt: "")

    `this`.incrementExpectCallCounter()

    let not = `this`.flags.not
    let pass = value.isAnyInt() != not

    if (pass) { return JsValue.jsUndefined() }

    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    let received = value.toFmt(formatter)

    if (not) {
        let signature = Expect.getSignature("toBeInteger", "", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
    }

    let signature = Expect.getSignature("toBeInteger", "", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
}
