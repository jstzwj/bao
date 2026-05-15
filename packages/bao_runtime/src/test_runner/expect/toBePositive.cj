// 严格翻译自: src/runtime/test_runner/expect/toBePositive.zig

package bao_runtime.test_runner.expect

/// toBePositive() - 检查值是否为正数
/// 用法: expect(received).toBePositive()
public func toBePositive(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBePositive", matcherParamsFmt: "")

    this.incrementExpectCallCounter()

    let not = this.flags.not
    let pass = value.isNumber() && value.asNumber() > 0 != not

    if pass { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let received = value.toFmt(formatter)

    if not {
        let signature = Expect.getSignature(matcherName: "toBePositive", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
    }

    let signature = Expect.getSignature(matcherName: "toBePositive", args: "", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
}
