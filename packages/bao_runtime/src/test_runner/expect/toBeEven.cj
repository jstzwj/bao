// 严格翻译自: src/runtime/test_runner/expect/toBeEven.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toBeEven() - 检查值是否为偶数
/// 用法: expect(received).toBeEven()
public func toBeEven(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeEven", matcherParamsFmt: "")

    `this`.incrementExpectCallCounter()

    let not = `this`.flags.not
    var pass = false

    if (value.isNumber()) {
        let num = value.asNumber()
        let truncated = if (num >= 0.0) { Float64(Int64(num)) } else { -Float64(Int64(-num)) }
        pass = num == truncated && Int64(num) % 2 == 0
    }

    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    let received = value.toFmt(formatter)

    if (not) {
        let signature = Expect.getSignature("toBeEven", "", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
    }

    let signature = Expect.getSignature("toBeEven", "", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
}
