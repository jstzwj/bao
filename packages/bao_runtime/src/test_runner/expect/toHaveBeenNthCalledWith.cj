// 严格翻译自: src/runtime/test_runner/expect/toHaveBeenNthCalledWith.zig

package bao_runtime

/// toHaveBeenNthCalledWith() - 检查mock函数第N次调用的参数
/// 用法: expect(mockFn).toHaveBeenNthCalledWith(n, ...expected)
public func toHaveBeenNthCalledWith(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments = callFrame.arguments()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveBeenNthCalledWith", matcherParamsFmt: "<green>n<r>, <green>...expected<r>")

    this.incrementExpectCallCounter()

    let calls = JSMockFunction.getCalls(globalThis: globalThis, value: value)
    if !calls.jsType().isArray() {
        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        defer { formatter.deinit() }
        let signature = Expect.getSignature(matcherName: "toHaveBeenNthCalledWith", args: "<green>n<r>, <green>...expected<r>", not: false)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nMatcher error: <red>received<r> value must be a mock function\nReceived: {f}",
            args: [value.toFmt(formatter)])
    }

    if arguments.length == 0 || !arguments[0].isAnyInt() {
        return globalThis.throwInvalidArguments("toHaveBeenNthCalledWith() requires a positive integer as the first argument")
    }
    let nthCallNumI32 = arguments[0].toInt32()

    if nthCallNumI32 <= 0 {
        return globalThis.throwInvalidArguments("toHaveBeenNthCalledWith() first argument must be a positive integer")
    }
    let nthCallNum: UInt32 = UInt32(nthCallNumI32)

    let totalCalls: UInt32 = calls.getLength(globalThis: globalThis)
    var pass = totalCalls >= nthCallNum
    var nthCallValue: JSValue = JSValue.zero

    if pass {
        nthCallValue = calls.getIndex(globalThis: globalThis, index: nthCallNum - 1)
        let expectedArgs = arguments.slice(from: 1)

        if !nthCallValue.jsType().isArray() {
            return globalThis.throw_("Internal error: expected mock call item to be an array of arguments.")
        }

        if nthCallValue.getLength(globalThis: globalThis) != expectedArgs.length {
            pass = false
        } else {
            var itr = nthCallValue.arrayIterator(globalThis: globalThis)
            while (let callArg = itr.next()) {
                if !callArg.jestDeepEquals(expectedArgs[itr.i - 1], globalThis: globalThis) {
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

    let expectedArgsSlice = arguments.slice(from: 1)
    let expectedArgsJsArray = JSValue.createEmptyArray(globalThis: globalThis, length: expectedArgsSlice.length)
    for (arg, i) in expectedArgsSlice {
        expectedArgsJsArray.putIndex(globalThis: globalThis, index: UInt32(i), value: arg)
    }
    expectedArgsJsArray.ensureStillAlive()

    if this.flags.not {
        let signature = Expect.getSignature(matcherName: "toHaveBeenNthCalledWith", args: "<green>n<r>, <green>...expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected call #{d} not to be with: <green>{f}<r>\nBut it was.",
            args: [nthCallNum, expectedArgsJsArray.toFmt(formatter)])
    }
    let signature = Expect.getSignature(matcherName: "toHaveBeenNthCalledWith", args: "<green>n<r>, <green>...expected<r>", not: false)

    // 函数调用次数不够
    if totalCalls < nthCallNum {
        let pluralSuffix = if totalCalls == 1 { "" } else { "s" }
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nThe mock function was called {d} time{s}, but call {d} was requested.",
            args: [totalCalls, pluralSuffix, nthCallNum])
    }

    // 调用存在但不匹配，显示差异
    let diffFormat = DiffFormatter(received: nthCallValue, expected: expectedArgsJsArray, globalThis: globalThis, not: false)
    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nCall #{d}:\n{f}\n",
        args: [nthCallNum, diffFormat])
}
