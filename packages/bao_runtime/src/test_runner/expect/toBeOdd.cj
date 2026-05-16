// 严格翻译自: src/runtime/test_runner/expect/toBeOdd.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner
import bao_jsc.*

/// toBeOdd() - 检查值是否为奇数
/// 用法: expect(received).toBeOdd()
public func toBeOdd(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeOdd", matcherParamsFmt: "")

    this.incrementExpectCallCounter()

    let not = this.flags.not
    var pass = false

    if (value.isNumber()) {
        let num = value.asNumber()
        pass = num == Float64.trunc(num) && Int64(num) % 2 != 0
    }

    if (not) { pass = !pass }
    if (pass) { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let received = value.toFmt(formatter)

    if (not) {
        let signature = Expect.getSignature(matcherName: "toBeOdd", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
    }

    let signature = Expect.getSignature(matcherName: "toBeOdd", args: "", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
}
