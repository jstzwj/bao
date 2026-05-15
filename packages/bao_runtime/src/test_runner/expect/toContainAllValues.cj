// 严格翻译自: src/runtime/test_runner/expect/toContainAllValues.zig

package bao_runtime.test_runner.expect

/// toContainAllValues() - 检查对象是否恰好包含所有指定值
/// 用法: expect(received).toContainAllValues(expected)
public func toContainAllValues(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toContainAllValues() takes 1 argument")
    }

    this.incrementExpectCallCounter()

    let expected = arguments[0]
    if !expected.jsType().isArray() {
        return globalThis.throwInvalidArgumentType("toContainAllValues", argName: "expected", expectedType: "array")
    }
    expected.ensureStillAlive()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toContainAllValues", matcherParamsFmt: "<green>expected<r>")

    let not = this.flags.not
    var pass = false

    if !value.isUndefinedOrNull() {
        let values = value.values(globalThis: globalThis)
        var itr = expected.arrayIterator(globalThis: globalThis)
        let count = values.getLength(globalThis: globalThis)
        let expectedLength = expected.getLength(globalThis: globalThis)

        if count == expectedLength {
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
                // 如果找到了则继续检查下一个 expected item
            }
            // 所有 expected items 都找到了
            pass = true
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
        let expectedLine = "Expected to not contain all values: <green>{f}<r>\nReceived: <red>{f}<r>\n"
        return this.throw_(globalThis: globalThis, signature: Expect.getSignature(matcherName: "toContainAllValues", args: "<green>expected<r>", not: true),
            fmt: "\n\n" + expectedLine, args: [expectedFmt, receivedFmt])
    }

    let expectedLine = "Expected to contain all values: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    return this.throw_(globalThis: globalThis, signature: Expect.getSignature(matcherName: "toContainAllValues", args: "<green>expected<r>", not: false),
        fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
