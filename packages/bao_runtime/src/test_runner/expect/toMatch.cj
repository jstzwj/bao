// 严格翻译自: src/runtime/test_runner/expect/toMatch.zig

package bao_runtime

/// toMatch() - 检查字符串是否匹配正则或包含子串
/// 用法: expect(received).toMatch(expected)
public func toMatch(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toMatch() requires 1 argument")
    }

    this.incrementExpectCallCounter()

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }

    let expectedValue = arguments[0]
    if !expectedValue.isString() && !expectedValue.isRegExp() {
        return globalThis.throw_("Expected value must be a string or regular expression: {f}", args: [expectedValue.toFmt(formatter)])
    }
    expectedValue.ensureStillAlive()

    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toMatch", matcherParamsFmt: "<green>expected<r>")

    if !value.isString() {
        return globalThis.throw_("Received value must be a string: {f}", args: [value.toFmt(formatter)])
    }

    let not = this.flags.not
    var pass: Bool = {
        if expectedValue.isString() {
            return value.stringIncludes(globalThis: globalThis, expected: expectedValue)
        } else if expectedValue.isRegExp() {
            return expectedValue.toMatch(globalThis: globalThis, value: value)
        }
        return false
    }

    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    // 处理失败
    let expectedFmt = expectedValue.toFmt(formatter)
    let valueFmt = value.toFmt(formatter)

    if not {
        let expectedLine = "Expected substring or pattern: not <green>{f}<r>\n"
        let receivedLine = "Received: <red>{f}<r>\n"
        let signature = Expect.getSignature(matcherName: "toMatch", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
    }

    let expectedLine = "Expected substring or pattern: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature(matcherName: "toMatch", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
