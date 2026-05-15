// 严格翻译自: src/runtime/test_runner/expect/toBeBoolean.zig

package bao_runtime.test_runner.expect

/// toBeBoolean() - 检查值是否为布尔类型
/// 用法: expect(received).toBeBoolean()
public func toBeBoolean(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeBoolean", matcherParamsFmt: "")

    this.incrementExpectCallCounter()

    let not = this.flags.not
    let pass = value.isBoolean() != not

    if pass { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let received = value.toFmt(formatter)

    if not {
        let signature = Expect.getSignature(matcherName: "toBeBoolean", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
    }

    let signature = Expect.getSignature(matcherName: "toBeBoolean", args: "", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
}
