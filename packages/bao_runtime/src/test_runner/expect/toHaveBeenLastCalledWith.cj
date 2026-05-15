// 严格翻译自: src/runtime/test_runner/expect/toHaveBeenLastCalledWith.zig

package bao_runtime

/// toHaveBeenLastCalledWith() - 检查mock函数最后一次调用的参数
/// 用法: expect(mockFn).toHaveBeenLastCalledWith(...expected)
public func toHaveBeenLastCalledWith(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments = callFrame.arguments()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveBeenLastCalledWith", matcherParamsFmt: "<green>...expected<r>")

    this.incrementExpectCallCounter()

    let calls = JSMockFunction.getCalls(globalThis: globalThis, value: value)
    if !calls.jsType().isArray() {
        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        defer { formatter.deinit() }
        let signature = Expect.getSignature(matcherName: "toHaveBeenLastCalledWith", args: "<green>...expected<r>", not: false)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nMatcher error: <red>received<r> value must be a mock function\nReceived: {f}",
            args: [value.toFmt(formatter)])
    }

    let totalCalls: UInt32 = calls.getLength(globalThis: globalThis)
    var lastCallValue: JSValue = JSValue.zero

    var pass = totalCalls > 0

    if pass {
        lastCallValue = calls.getIndex(globalThis: globalThis, index: totalCalls - 1)

        if !lastCallValue.jsType().isArray() {
            let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
            defer { formatter.deinit() }
            return globalThis.throw_("Expected value must be a mock function with calls: {f}", args: [value.toFmt(formatter)])
        }

        if lastCallValue.getLength(globalThis: globalThis) != arguments.length {
            pass = false
        } else {
            var itr = lastCallValue.arrayIterator(globalThis: globalThis)
            while (let callArg = itr.next()) {
                if !callArg.jestDeepEquals(arguments[itr.i - 1], globalThis: globalThis) {
                    pass = false
                    break
                }
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
        let signature = Expect.getSignature(matcherName: "toHaveBeenLastCalledWith", args: "<green>...expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected last call not to be with: <green>{f}<r>\nBut it was.",
            args: [expectedArgsJsArray.toFmt(formatter)])
    }
    let signature = Expect.getSignature(matcherName: "toHaveBeenLastCalledWith", args: "<green>...expected<r>", not: false)

    if totalCalls == 0 {
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected: <green>{f}<r>\nBut it was not called.",
            args: [expectedArgsJsArray.toFmt(formatter)])
    }

    let diffFormat = DiffFormatter(received: lastCallValue, expected: expectedArgsJsArray, globalThis: globalThis, not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormat])
}
