// 严格翻译自: src/runtime/test_runner/expect/toEqualIgnoringWhitespace.zig

package bao_runtime.test_runner.expect

/// toEqualIgnoringWhitespace() - 检查去除空白后是否相等
/// 用法: expect(received).toEqualIgnoringWhitespace(expected)
public func toEqualIgnoringWhitespace(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toEqualIgnoringWhitespace() requires 1 argument")
    }

    this.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()

    if !expected.isString() {
        return globalThis.throw_("toEqualIgnoringWhitespace() requires the first argument to be a string")
    }

    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toEqualIgnoringWhitespace", matcherParamsFmt: "<green>expected<r>")

    if !value.isString() {
        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        defer { formatter.deinit() }
        return globalThis.throw_("Received value must be a string: {f}", args: [value.toFmt(formatter)])
    }

    let valueStr = value.toSliceOrNull(globalThis: globalThis)
    defer { valueStr.deinit() }
    let expectedStr = expected.toSliceOrNull(globalThis: globalThis)
    defer { expectedStr.deinit() }

    // 去除空白后比较
    let normalizedValue = strings.normalizeWhitespace(valueStr.slice())
    let normalizedExpected = strings.normalizeWhitespace(expectedStr.slice())

    let not = this.flags.not
    var pass = strings.eql(normalizedValue, normalizedExpected)

    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)

    if not {
        let signature = Expect.getSignature(matcherName: "toEqualIgnoringWhitespace", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected: not <green>{f}<r>\nReceived: <red>{f}<r>\n",
            args: [expectedFmt, valueFmt])
    }

    let signature = Expect.getSignature(matcherName: "toEqualIgnoringWhitespace", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected: <green>{f}<r>\nReceived: <red>{f}<r>\n",
        args: [expectedFmt, valueFmt])
}
