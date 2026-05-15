// 严格翻译自: src/runtime/test_runner/expect/toHaveBeenCalledWith.zig

package bao_runtime

/// toHaveBeenCalledWith() - 检查mock函数是否以指定参数被调用
/// 用法: expect(mockFn).toHaveBeenCalledWith(...expected)
public func toHaveBeenCalledWith(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments = callFrame.arguments()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveBeenCalledWith", matcherParamsFmt: "<green>...expected<r>")

    this.incrementExpectCallCounter()

    let calls = JSMockFunction.getCalls(globalThis: globalThis, value: value)
    if !calls.jsType().isArray() {
        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        defer { formatter.deinit() }
        let signature = Expect.getSignature(matcherName: "toHaveBeenCalledWith", args: "<green>...expected<r>", not: false)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nMatcher error: <red>received<r> value must be a mock function\nReceived: {f}",
            args: [value.toFmt(formatter)])
    }

    var pass = false

    let callsCount: UInt32 = calls.getLength(globalThis: globalThis)
    if callsCount > 0 {
        var itr = calls.arrayIterator(globalThis: globalThis)
        while (let callItem = itr.next()) {
            if callItem == JSValue.zero || !callItem.jsType().isArray() {
                return globalThis.throw_("Internal error: expected mock call item to be an array of arguments.")
            }

            if callItem.getLength(globalThis: globalThis) != arguments.length {
                continue
            }

            var callItr = callItem.arrayIterator(globalThis: globalThis)
            var match = true
            while (let callArg = callItr.next()) {
                if !callArg.jestDeepEquals(arguments[callItr.i - 1], globalThis: globalThis) {
                    match = false
                    break
                }
            }

            if match {
                pass = true
                break
            }
        }
    }

    if pass != this.flags.not {
        return JSValue.jsUndefined
    }

    // 处理失败
    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }

    let expectedArgsJsArray = JSValue.createEmptyArray(globalThis: globalThis, length: arguments.length)
    for (arg, i) in arguments {
        expectedArgsJsArray.putIndex(globalThis: globalThis, index: UInt32(i), value: arg)
    }
    expectedArgsJsArray.ensureStillAlive()

    if this.flags.not {
        let signature = Expect.getSignature(matcherName: "toHaveBeenCalledWith", args: "<green>...expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected mock function not to have been called with: <green>{f}<r>\nBut it was.",
            args: [expectedArgsJsArray.toFmt(formatter)])
    }
    let signature = Expect.getSignature(matcherName: "toHaveBeenCalledWith", args: "<green>...expected<r>", not: false)

    if callsCount == 0 {
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected: <green>{f}<r>\nBut it was not called.",
            args: [expectedArgsJsArray.toFmt(formatter)])
    }

    // 如果只有一次调用，提供漂亮的 diff
    if callsCount == 1 {
        let receivedCallArgs = calls.getIndex(globalThis: globalThis, index: 0)
        let diffFormat = DiffFormatter(received: receivedCallArgs, expected: expectedArgsJsArray, globalThis: globalThis, not: false)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormat])
    }

    // 多次调用时，列出所有调用帮助调试
    let listFormatter = AllCallsWithArgsFormatter(globalThis: globalThis, calls: calls, formatter: formatter)

    let fmt =
        "    <green>Expected<r>: {f}\n" +
        "    <red>Received<r>:\n" +
        "{f}\n\n" +
        "    Number of calls: {d}"

    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\n" + fmt + "\n",
        args: [expectedArgsJsArray.toFmt(formatter), listFormatter, callsCount])
}
