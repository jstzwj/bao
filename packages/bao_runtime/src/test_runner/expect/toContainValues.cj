// 严格翻译自: src/runtime/test_runner/expect/toContainValues.zig

package bao_runtime

/// toContainValues() - 检查对象是否包含所有指定值
/// 用法: expect(received).toContainValues(expected)
public func toContainValues(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toContainValues() takes 1 argument")
    }

    this.incrementExpectCallCounter()

    let expected = arguments[0]
    if !expected.jsType().isArray() {
        return globalThis.throwInvalidArgumentType("toContainValues", argName: "expected", expectedType: "array")
    }
    expected.ensureStillAlive()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toContainValues", matcherParamsFmt: "<green>expected<r>")

    let not = this.flags.not
    var pass = true

    if !value.isUndefinedOrNull() {
        let values = value.values(globalThis: globalThis)
        var itr = expected.arrayIterator(globalThis: globalThis)
        let count = values.getLength(globalThis: globalThis)

        while (let item = itr.next()) {
            var i: UInt32 = 0
            var found = false
            while i < count {
                let key = values.getIndex(globalThis: globalThis, index: i)
                if key.jestDeepEquals(item, globalThis: globalThis) {
                    found = true
                    break
                }
                i++
            }
            if !found {
                pass = false
                break
            }
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
        return this.throw_(globalThis: globalThis, signature: Expect.getSignature(matcherName: "toContainValues", args: "<green>expected<r>", not: true),
            fmt: "\n\n" + expectedLine, args: [expectedFmt, receivedFmt])
    }

    let expectedLine = "Expected to contain: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    return this.throw_(globalThis: globalThis, signature: Expect.getSignature(matcherName: "toContainValues", args: "<green>expected<r>", not: false),
        fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
