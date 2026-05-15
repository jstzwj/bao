// 严格翻译自: src/runtime/test_runner/expect/toHaveNthReturnedWith.zig

package bao_runtime.test_runner.expect

/// toHaveNthReturnedWith() - 检查mock函数第N次返回的值
/// 用法: expect(mockFn).toHaveNthReturnedWith(n, expected)
public func toHaveNthReturnedWith(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveNthReturnedWith", matcherParamsFmt: "<green>n<r>, <green>expected<r>")

    let (nthArg, expected) = callFrame.argumentsAsArray(2)

    // 验证 n 是数字
    if !nthArg.isAnyInt() {
        return globalThis.throwInvalidArguments("toHaveNthReturnedWith() first argument must be an integer")
    }

    let n = nthArg.toInt32()
    if n <= 0 {
        return globalThis.throwInvalidArguments("toHaveNthReturnedWith() n must be greater than 0")
    }

    this.incrementExpectCallCounter()
    let returns = JSMockFunction.getReturns(globalThis: globalThis, value: value)
    if !returns.jsType().isArray() {
        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        defer { formatter.deinit() }
        return globalThis.throw_("Expected value must be a mock function: {f}", args: [value.toFmt(formatter)])
    }

    let callsCount: UInt32 = returns.getLength(globalThis: globalThis)
    let index: UInt32 = UInt32(n - 1) // 转为 0-based index

    var pass = false
    var nthReturnValue: JSValue = JSValue.jsUndefined
    var nthCallThrew = false
    var nthErrorValue: JSValue = JSValue.jsUndefined
    var nthCallExists = false

    if index < callsCount {
        nthCallExists = true
        let nthResult = returns.getDirectIndex(globalThis: globalThis, index: index)
        if nthResult.isObject() {
            let resultType = nthResult.get(globalThis: globalThis, key: "type") ?? JSValue.jsUndefined
            if resultType.isString() {
                let typeStr = resultType.toBunString(globalThis: globalThis)
                defer { typeStr.deref() }
                if typeStr.eqlComptime("return") {
                    nthReturnValue = nthResult.get(globalThis: globalThis, key: "value") ?? JSValue.jsUndefined
                    if nthReturnValue.jestDeepEquals(expected, globalThis: globalThis) {
                        pass = true
                    }
                } else if typeStr.eqlComptime("throw") {
                    nthCallThrew = true
                    nthErrorValue = nthResult.get(globalThis: globalThis, key: "value") ?? JSValue.jsUndefined
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

    let signature = Expect.getSignature(matcherName: "toHaveNthReturnedWith", args: "<green>n<r>, <green>expected<r>", not: false)

    if this.flags.not {
        let notSignature = Expect.getSignature(matcherName: "toHaveNthReturnedWith", args: "<green>n<r>, <green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: notSignature,
            fmt: "\n\nExpected mock function not to have returned on call {d}: <green>{f}<r>\nBut it did.\n",
            args: [n, expected.toFmt(formatter)])
    }

    if !nthCallExists {
        let pluralSuffix = if callsCount == 1 { "" } else { "s" }
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nThe mock function was called {d} time{s}, but call {d} was requested.\n",
            args: [callsCount, pluralSuffix, n])
    }

    if nthCallThrew {
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nCall {d} threw an error: <red>{f}<r>\n",
            args: [n, nthErrorValue.toFmt(formatter)])
    }

    // 如果可能则显示 diff
    if expected.isString() && nthReturnValue.isString() {
        let diffFormat = DiffFormatter(received: nthReturnValue, expected: expected, globalThis: globalThis, not: false)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nCall {d}:\n{f}\n",
            args: [n, diffFormat])
    }

    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nCall {d}:\nExpected: <green>{f}<r>\nReceived: <red>{f}<r>",
        args: [n, expected.toFmt(formatter), nthReturnValue.toFmt(formatter)])
}
