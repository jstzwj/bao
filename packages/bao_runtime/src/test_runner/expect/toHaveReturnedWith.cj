// 严格翻译自: src/runtime/test_runner/expect/toHaveReturnedWith.zig

package bao_runtime.test_runner.expect

/// toHaveReturnedWith() - 检查mock函数是否以指定值返回
/// 用法: expect(mockFn).toHaveReturnedWith(expected)
public func toHaveReturnedWith(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveReturnedWith", matcherParamsFmt: "<green>expected<r>")

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

    var successfulReturns = ArrayList<JSValue>(allocator: globalThis.bunVM().allocator)
    defer { successfulReturns.deinit() }

    var hasErrors = false

    // 检查 pass 条件并收集成功返回
    var i: UInt32 = 0
    while i < callsCount {
        let result = returns.getDirectIndex(globalThis: globalThis, index: i)

        if result.isObject() {
            let resultType = result.get(globalThis: globalThis, key: "type") ?? JSValue.jsUndefined
            if resultType.isString() {
                let typeStr = resultType.toBunString(globalThis: globalThis)
                defer { typeStr.deref() }

                if typeStr.eqlComptime("return") {
                    let resultValue = result.get(globalThis: globalThis, key: "value") ?? JSValue.jsUndefined
                    successfulReturns.append(resultValue)

                    // 只在还没 pass 时检查
                    if !pass {
                        if resultValue.jestDeepEquals(expected, globalThis: globalThis) {
                            pass = true
                        }
                    }
                } else if typeStr.eqlComptime("throw") {
                    hasErrors = true
                }
            }
        }
        i++
    }

    if pass != this.flags.not {
        return JSValue.jsUndefined
    }

    // 处理失败
    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }

    let signature = Expect.getSignature(matcherName: "toHaveReturnedWith", args: "<green>expected<r>", not: false)

    if this.flags.not {
        let notSignature = Expect.getSignature(matcherName: "toHaveReturnedWith", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: notSignature,
            fmt: "\n\nExpected mock function not to have returned: <green>{f}<r>\n",
            args: [expected.toFmt(formatter)])
    }

    // 没找到匹配
    let successfulReturnsCount = successfulReturns.length

    // 只有一次成功返回且无错误
    if callsCount == 1 && successfulReturnsCount == 1 {
        let received = successfulReturns[0]
        if expected.isString() && received.isString() {
            let diffFormat = DiffFormatter(received: received, expected: expected, globalThis: globalThis, not: false)
            return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormat])
        }

        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected: <green>{f}<r>\nReceived: <red>{f}<r>",
            args: [expected.toFmt(formatter), received.toFmt(formatter)])
    }

    if hasErrors {
        // 有些调用抛出了错误
        let listFormatter = AllCallsFormatter(globalThis: globalThis, returns: returns, formatter: formatter)
        let fmt =
            "Some calls errored:\n\n" +
            "    Expected: {f}\n" +
            "    Received:\n" +
            "{f}\n\n" +
            "    Number of returns: {d}\n" +
            "    Number of calls:   {d}"

        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n" + fmt + "\n",
            args: [expected.toFmt(formatter), listFormatter, successfulReturnsCount, callsCount])
    } else {
        // 多次返回但无匹配
        let listFormatter = SuccessfulReturnsFormatter(globalThis: globalThis, successfulReturns: successfulReturns, formatter: formatter)
        let fmt =
            "    <green>Expected<r>: {f}\n" +
            "    <red>Received<r>:\n" +
            "{f}\n\n" +
            "    Number of returns: {d}"

        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n" + fmt + "\n",
            args: [expected.toFmt(formatter), listFormatter, successfulReturnsCount])
    }
}
