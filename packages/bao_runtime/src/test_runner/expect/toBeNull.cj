// 严格翻译自: src/runtime/test_runner/expect/toBeNull.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toBeNull() - 检查值是否为null
/// 用法: expect(received).toBeNull()
public func toBeNull(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeNull", matcherParamsFmt: "")

    `this`.incrementExpectCallCounter()

    let not = `this`.flags.not
    var pass = value.isNull()
    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    // 处理失败
    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    if (not) {
        let receivedLine = "Received: <red>{f}<r>\n"
        let signature = Expect.getSignature("toBeNull", "", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + receivedLine, args: [valueFmt])
    }

    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature("toBeNull", "", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + receivedLine, args: [valueFmt])
}
