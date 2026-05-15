// 严格翻译自: src/runtime/test_runner/expect/toStartWith.zig

package bao_runtime.test_runner.expect

/// toStartWith() - 检查字符串是否以指定前缀开头
/// 用法: expect(received).toStartWith(expected)
public func toStartWith(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toStartWith() requires 1 argument")
    }

    let expected = arguments[0]
    expected.ensureStillAlive()

    if !expected.isString() {
        return globalThis.throw_("toStartWith() requires the first argument to be a string")
    }

    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toStartWith", matcherParamsFmt: "<green>expected<r>")

    this.incrementExpectCallCounter()

    var pass = value.isString()
    if pass {
        let valueString = value.toSliceOrNull(globalThis: globalThis)
        defer { valueString.deinit() }
        let expectedString = expected.toSliceOrNull(globalThis: globalThis)
        defer { expectedString.deinit() }
        pass = strings.startsWith(valueString.slice(), expectedString.slice()) || expectedString.length == 0
    }

    let not = this.flags.not
    if not { pass = !pass }

    if pass { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)

    if not {
        let expectedLine = "Expected to not start with: <green>{f}<r>\n"
        let receivedLine = "Received: <red>{f}<r>\n"
        let signature = Expect.getSignature(matcherName: "toStartWith", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
    }

    let expectedLine = "Expected to start with: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature(matcherName: "toStartWith", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
