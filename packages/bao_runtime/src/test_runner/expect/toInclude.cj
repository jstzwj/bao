// 严格翻译自: src/runtime/test_runner/expect/toInclude.zig

package bao_runtime.test_runner.expect

/// toInclude() - 检查值是否包含期望子串
/// 用法: expect(received).toInclude(expected)
public func toInclude(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toInclude() requires 1 argument")
    }

    let expected = arguments[0]
    expected.ensureStillAlive()

    if !expected.isString() {
        return globalThis.throw_("toInclude() requires the first argument to be a string")
    }

    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toInclude", matcherParamsFmt: "")

    this.incrementExpectCallCounter()

    var pass = value.isString()
    if pass {
        let valueString = value.toSliceOrNull(globalThis: globalThis)
        defer { valueString.deinit() }
        let expectedString = expected.toSliceOrNull(globalThis: globalThis)
        defer { expectedString.deinit() }
        pass = strings.contains(valueString.slice(), expectedString.slice()) || expectedString.length == 0
    }

    let not = this.flags.not
    if not { pass = !pass }

    if pass { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)

    if not {
        let expectedLine = "Expected to not include: <green>{f}<r>\n"
        let receivedLine = "Received: <red>{f}<r>\n"
        let signature = Expect.getSignature(matcherName: "toInclude", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
    }

    let expectedLine = "Expected to include: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature(matcherName: "toInclude", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
