// 严格翻译自: src/runtime/test_runner/expect/toBeDefined.zig

package bao_runtime.test_runner.expect

/// toBeDefined() - 检查值是否已定义（非undefined）
/// 用法: expect(received).toBeDefined()
public func toBeDefined(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeDefined", matcherParamsFmt: "")

    this.incrementExpectCallCounter()

    let not = this.flags.not
    var pass = !value.isUndefined()
    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    // 处理失败
    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    if not {
        let receivedLine = "Received: <red>{f}<r>\n"
        let signature = Expect.getSignature(matcherName: "toBeDefined", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + receivedLine, args: [valueFmt])
    }

    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature(matcherName: "toBeDefined", args: "", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + receivedLine, args: [valueFmt])
}
