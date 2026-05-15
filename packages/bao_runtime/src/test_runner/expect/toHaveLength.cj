// 严格翻译自: src/runtime/test_runner/expect/toHaveLength.zig

package bao_runtime

/// toHaveLength() - 检查值是否具有指定长度
/// 用法: expect(received).toHaveLength(expected)
public func toHaveLength(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toHaveLength() takes 1 argument")
    }

    this.incrementExpectCallCounter()

    let expected: JSValue = arguments[0]
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveLength", matcherParamsFmt: "<green>expected<r>")

    if !value.isObject() && !value.isString() {
        let fmt = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        return globalThis.throw_("Received value does not have a length property: {f}", args: [value.toFmt(fmt)])
    }

    if !expected.isNumber() {
        let fmt = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        return globalThis.throw_("Expected value must be a non-negative integer: {f}", args: [expected.toFmt(fmt)])
    }

    let expectedLength: Float64 = expected.asNumber()
    if Float64.round(expectedLength) != expectedLength || std.math.isInf(expectedLength) || std.math.isNan(expectedLength) || expectedLength < 0 {
        let fmt = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        return globalThis.throw_("Expected value must be a non-negative integer: {f}", args: [expected.toFmt(fmt)])
    }

    let not = this.flags.not
    var pass = false

    let actualLength = value.getLengthIfPropertyExistsInternal(globalThis: globalThis)

    if actualLength == std.math.inf(Float64) {
        let fmt = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        return globalThis.throw_("Received value does not have a length property: {f}", args: [value.toFmt(fmt)])
    } else if std.math.isNan(actualLength) {
        return globalThis.throw_("Received value has non-number length property: {}", args: [actualLength])
    }

    if actualLength == expectedLength {
        pass = true
    }

    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    // 处理失败
    if not {
        let expectedLine = "Expected length: not <green>{d}<r>\n"
        let signature = Expect.getSignature(matcherName: "toHaveLength", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine, args: [expectedLength])
    }

    let expectedLine = "Expected length: <green>{d}<r>\n"
    let receivedLine = "Received length: <red>{d}<r>\n"
    let signature = Expect.getSignature(matcherName: "toHaveLength", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedLength, actualLength])
}
