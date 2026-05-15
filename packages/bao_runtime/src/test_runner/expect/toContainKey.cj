// 严格翻译自: src/runtime/test_runner/expect/toContainKey.zig

package bao_runtime.test_runner.expect

/// toContainKey() - 检查对象是否包含指定键
/// 用法: expect(received).toContainKey(expected)
public func toContainKey(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toContainKey() takes 1 argument")
    }

    this.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toContainKey", matcherParamsFmt: "<green>expected<r>")
    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }

    let not = this.flags.not
    if !value.isObject() {
        return globalThis.throwInvalidArguments("Expected value must be an object\nReceived: {f}", args: [value.toFmt(formatter)])
    }

    var pass = value.hasOwnPropertyValue(globalThis: globalThis, key: expected)

    if not { pass = !pass }
    if pass { return thisValue }

    // 处理失败
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)
    if not {
        let receivedFmt = value.toFmt(formatter)
        let expectedLine = "Expected to not contain: <green>{f}<r>\nReceived: <red>{f}<r>\n"
        let signature = Expect.getSignature(matcherName: "toContainKey", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine, args: [expectedFmt, receivedFmt])
    }

    let expectedLine = "Expected to contain: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature(matcherName: "toContainKey", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
