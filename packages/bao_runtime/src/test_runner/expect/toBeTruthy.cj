// 严格翻译自: src/runtime/test_runner/expect/toBeTruthy.zig

package bao_runtime.test_runner.expect

/// toBeTruthy() - 检查值是否为真值
/// 用法: expect(received).toBeTruthy()
public func toBeTruthy(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeTruthy", matcherParamsFmt: "")

    this.incrementExpectCallCounter()

    let not = this.flags.not
    var pass = false

    let truthy = value.toBoolean()
    if truthy { pass = true }

    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    // 处理失败
    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    if not {
        let receivedLine = "Received: <red>{f}<r>\n"
        let signature = Expect.getSignature(matcherName: "toBeTruthy", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + receivedLine, args: [valueFmt])
    }

    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature(matcherName: "toBeTruthy", args: "", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + receivedLine, args: [valueFmt])
}
