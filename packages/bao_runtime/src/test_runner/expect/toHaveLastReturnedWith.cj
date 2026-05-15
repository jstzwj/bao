// 严格翻译自: src/runtime/test_runner/expect/toHaveLastReturnedWith.zig

package bao_runtime.test_runner.expect

/// toHaveLastReturnedWith() - 检查mock函数最后一次返回的值
/// 用法: expect(mockFn).toHaveLastReturnedWith(expected)
public func toHaveLastReturnedWith(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveBeenLastReturnedWith", matcherParamsFmt: "<green>expected<r>")

    let expected = callFrame.argumentsAsArray(1)[0]
    this.incrementExpectCallCounter()

    let returns = JSMockFunction.getReturns(globalThis: globalThis, value: value)
    if !returns.jsType().isArray() {
        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        defer { formatter.deinit() }
        return globalThis.throw_("Expected value must be a mock function: {f}", args: [value.toFmt(formatter)])
    }

    let callsCount: UInt32 = returns.getLength(globalThis: globalThis)
    var pass = false
    var lastReturnValue: JSValue = JSValue.jsUndefined
    var lastCallThrew = false
    var lastErrorValue: JSValue = JSValue.jsUndefined

    if callsCount > 0 {
        let lastResult = returns.getDirectIndex(globalThis: globalThis, index: callsCount - 1)

        if lastResult.isObject() {
            let resultType = lastResult.get(globalThis: globalThis, key: "type") ?? JSValue.jsUndefined
            if resultType.isString() {
                let typeStr = resultType.toBunString(globalThis: globalThis)
                defer { typeStr.deref() }

                if typeStr.eqlComptime("return") {
                    lastReturnValue = lastResult.get(globalThis: globalThis, key: "value") ?? JSValue.jsUndefined

                    if lastReturnValue.jestDeepEquals(expected, globalThis: globalThis) {
                        pass = true
                    }
                } else if typeStr.eqlComptime("throw") {
                    lastCallThrew = true
                    lastErrorValue = lastResult.get(globalThis: globalThis, key: "value") ?? JSValue.jsUndefined
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

    let signature = Expect.getSignature(matcherName: "toHaveBeenLastReturnedWith", args: "<green>expected<r>", not: false)

    if this.flags.not {
        let notSignature = Expect.getSignature(matcherName: "toHaveBeenLastReturnedWith", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: notSignature,
            fmt: "\n\nExpected mock function not to have last returned: <green>{f}<r>\nBut it did.\n",
            args: [expected.toFmt(formatter)])
    }

    if callsCount == 0 {
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nThe mock function was not called.", args: [])
    }

    if lastCallThrew {
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nThe last call threw an error: <red>{f}<r>\n",
            args: [lastErrorValue.toFmt(formatter)])
    }

    // 如果可能则显示 diff
    if expected.isString() && lastReturnValue.isString() {
        let diffFormat = DiffFormatter(received: lastReturnValue, expected: expected, globalThis: globalThis, not: false)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormat])
    }

    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected: <green>{f}<r>\nReceived: <red>{f}<r>",
        args: [expected.toFmt(formatter), lastReturnValue.toFmt(formatter)])
}
