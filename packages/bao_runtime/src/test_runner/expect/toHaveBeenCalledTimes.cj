// 严格翻译自: src/runtime/test_runner/expect/toHaveBeenCalledTimes.zig

package bao_runtime.test_runner.expect

/// toHaveBeenCalledTimes() - 检查mock函数被调用的次数
/// 用法: expect(mockFn).toHaveBeenCalledTimes(times)
public func toHaveBeenCalledTimes(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveBeenCalledTimes", matcherParamsFmt: "<green>expected<r>")

    this.incrementExpectCallCounter()

    let calls = JSMockFunction.getCalls(globalThis: globalThis, value: value)
    if !calls.jsType().isArray() {
        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        defer { formatter.deinit() }
        return globalThis.throw_("Expected value must be a mock function: {f}", args: [value.toFmt(formatter)])
    }

    if arguments.length < 1 || !arguments[0].isUInt32AsAnyInt() {
        return globalThis.throwInvalidArguments("toHaveBeenCalledTimes() requires 1 non-negative integer argument")
    }

    let times = arguments[0].coerceInt32(globalThis: globalThis)

    var pass = Int32(calls.getLength(globalThis: globalThis)) == times

    let not = this.flags.not
    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    // 处理失败
    if not {
        let signature = Expect.getSignature(matcherName: "toHaveBeenCalledTimes", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected number of calls: not <green>{d}<r>\nReceived number of calls: <red>{d}<r>\n",
            args: [times, calls.getLength(globalThis: globalThis)])
    }

    let signature = Expect.getSignature(matcherName: "toHaveBeenCalledTimes", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected number of calls: <green>{d}<r>\nReceived number of calls: <red>{d}<r>\n",
        args: [times, calls.getLength(globalThis: globalThis)])
}
