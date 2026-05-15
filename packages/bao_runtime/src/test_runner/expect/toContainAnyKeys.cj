// 严格翻译自: src/runtime/test_runner/expect/toContainAnyKeys.zig

package bao_runtime.test_runner.expect

/// toContainAnyKeys() - 检查对象是否包含任一指定键
/// 用法: expect(received).toContainAnyKeys(expected)
public func toContainAnyKeys(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toContainAnyKeys() takes 1 argument")
    }

    this.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toContainAnyKeys", matcherParamsFmt: "<green>expected<r>")

    if !expected.jsType().isArray() {
        return globalThis.throwInvalidArgumentType("toContainAnyKeys", argName: "expected", expectedType: "array")
    }

    let not = this.flags.not
    var pass = false

    let count = expected.getLength(globalThis: globalThis)

    if value.isObject() {
        var i: UInt32 = 0
        while i < count {
            let key = expected.getIndex(globalThis: globalThis, index: i)

            if value.hasOwnPropertyValue(globalThis: globalThis, key: key) {
                pass = true
                break
            }
            i++
        }
    }

    if not { pass = !pass }
    if pass { return thisValue }

    // 处理失败
    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)
    if not {
        let receivedFmt = value.toFmt(formatter)
        let expectedLine = "Expected to not contain: <green>{f}<r>\nReceived: <red>{f}<r>\n"
        let signature = Expect.getSignature(matcherName: "toContainAnyKeys", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine, args: [expectedFmt, receivedFmt])
    }

    let expectedLine = "Expected to contain: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature(matcherName: "toContainAnyKeys", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
