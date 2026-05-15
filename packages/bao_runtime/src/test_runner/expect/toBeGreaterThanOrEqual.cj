// 严格翻译自: src/runtime/test_runner/expect/toBeGreaterThanOrEqual.zig

package bao_runtime

/// toBeGreaterThanOrEqual() - 检查值是否大于等于期望值
/// 用法: expect(received).toBeGreaterThanOrEqual(expected)
public func toBeGreaterThanOrEqual(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toBeGreaterThanOrEqual() requires 1 argument")
    }

    this.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()

    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeGreaterThanOrEqual", matcherParamsFmt: "<green>expected<r>")

    let not = this.flags.not
    var pass = false

    if value.isNumber() && expected.isNumber() {
        pass = value.asNumber() >= expected.asNumber()
    } else if value.isBigInt() && expected.isBigInt() {
        pass = value.toBigInt(globalThis: globalThis) >= expected.toBigInt(globalThis: globalThis)
    }

    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let expectedFmt = expected.toFmt(formatter)
    let valueFmt = value.toFmt(formatter)

    if not {
        let signature = Expect.getSignature(matcherName: "toBeGreaterThanOrEqual", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected: not <green>{f}<r>\nReceived: <red>{f}<r>\n",
            args: [expectedFmt, valueFmt])
    }

    let signature = Expect.getSignature(matcherName: "toBeGreaterThanOrEqual", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected: <green>{f}<r>\nReceived: <red>{f}<r>\n",
        args: [expectedFmt, valueFmt])
}
