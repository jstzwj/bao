// 严格翻译自: src/runtime/test_runner/expect/toBeSymbol.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toBeSymbol() - 检查值是否为Symbol类型
/// 用法: expect(received).toBeSymbol()
public func toBeSymbol(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeSymbol", matcherParamsFmt: "")

    `this`.incrementExpectCallCounter()

    let not = `this`.flags.not
    let pass = value.isSymbol() != not

    if (pass) { return JsValue.jsUndefined() }

    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    let received = value.toFmt(formatter)

    if (not) {
        let signature = Expect.getSignature("toBeSymbol", "", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
    }

    let signature = Expect.getSignature("toBeSymbol", "", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
}
