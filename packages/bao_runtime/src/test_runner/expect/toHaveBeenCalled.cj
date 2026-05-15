// 严格翻译自: src/runtime/test_runner/expect/toHaveBeenCalled.zig

package bao_runtime.test_runner.expect

/// toHaveBeenCalled() - 检查mock函数是否被调用
/// 用法: expect(mockFn).toHaveBeenCalled()
public func toHaveBeenCalled(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let firstArgument = callFrame.argumentsAsArray(1)[0]

    if !firstArgument.isUndefined() {
        return globalThis.throwInvalidArguments("toHaveBeenCalled() must not have an argument")
    }

    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveBeenCalled", matcherParamsFmt: "")

    let calls = JSMockFunction.getCalls(globalThis: globalThis, value: value)
    this.incrementExpectCallCounter()
    if !calls.jsType().isArray() {
        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        defer { formatter.deinit() }
        return globalThis.throw_("Expected value must be a mock function: {f}", args: [value.toFmt(formatter)])
    }

    let callsLength = calls.getLength(globalThis: globalThis)
    var pass = callsLength > 0

    let not = this.flags.not
    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    // 处理失败
    if not {
        let signature = Expect.getSignature(matcherName: "toHaveBeenCalled", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected number of calls: <green>0<r>\nReceived number of calls: <red>{d}<r>\n",
            args: [callsLength])
    }

    let signature = Expect.getSignature(matcherName: "toHaveBeenCalled", args: "", not: false)
    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected number of calls: \\>= <green>1<r>\nReceived number of calls: <red>{d}<r>\n",
        args: [callsLength])
}
