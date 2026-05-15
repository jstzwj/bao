// 严格翻译自: src/runtime/test_runner/expect/toBeObject.zig

package bao_runtime.test_runner.expect

/// toBeObject() - 检查值是否为对象类型
/// 用法: expect(received).toBeObject()
public func toBeObject(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeObject", matcherParamsFmt: "")

    this.incrementExpectCallCounter()

    let not = this.flags.not
    let pass = value.isObject() != not

    if pass { return thisValue }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let received = value.toFmt(formatter)

    if not {
        let signature = Expect.getSignature(matcherName: "toBeObject", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected value <b>not<r> to be an object\n\nReceived: <red>{f}<r>\n",
            args: [received])
    }

    let signature = Expect.getSignature(matcherName: "toBeObject", args: "", not: false)
    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected value to be an object\n\nReceived: <red>{f}<r>\n",
        args: [received])
}
