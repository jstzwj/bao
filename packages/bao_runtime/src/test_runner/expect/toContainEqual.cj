// 严格翻译自: src/runtime/test_runner/expect/toContainEqual.zig

package bao_runtime.test_runner.expect

/// toContainEqual() - 检查数组是否深度包含期望值
/// 用法: expect(received).toContainEqual(expected)
public func toContainEqual(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toContainEqual() takes 1 argument")
    }

    this.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toContainEqual", matcherParamsFmt: "<green>expected<r>")

    let not = this.flags.not
    var pass = false

    let valueType = value.jsType()
    let expectedType = expected.jsType()

    if valueType.isArrayLike() {
        var itr = value.arrayIterator(globalThis: globalThis)
        while (let item = itr.next()) {
            if item.jestDeepEquals(expected, globalThis: globalThis) {
                pass = true
                break
            }
        }
    } else if valueType.isStringLike() && expectedType.isStringLike() {
        if expectedType.isStringObjectLike() && valueType.isString() {
            pass = false
        } else {
            let valueString = value.toSliceOrNull(globalThis: globalThis)
            defer { valueString.deinit() }
            let expectedString = expected.toSliceOrNull(globalThis: globalThis)
            defer { expectedString.deinit() }

            // jest does not have a `typeof === "string"` check for `toContainEqual`.
            // it immediately spreads the value into an array.
            let expectedIter = strings.CodepointIterator.init(expectedString.slice())
            var expectedCursor = CodepointIterator.Cursor()
            _ = expectedIter.next(cursor: &expectedCursor)

            pass = if expectedIter.next(cursor: &expectedCursor) {
                false
            } else {
                strings.indexOf(valueString.slice(), expectedString.slice()) != None
            }
        }
    } else if value.isIterable(globalThis: globalThis) {
        var expectedEntry = ExpectedEntry(globalThis: globalThis, expected: expected, pass: &pass)
        value.forEach(globalThis: globalThis, context: &expectedEntry, callback: { vm, globalObject, entry_, item =>
            let entry = entry_ as ExpectedEntry
            if item.jestDeepEquals(entry.expected, globalObject) {
                entry.pass = true
            }
        })
    } else {
        return globalThis.throw_("Received value must be an array type, or both received and expected values must be strings.")
    }

    if not { pass = !pass }
    if pass { return thisValue }

    // 处理失败
    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)
    if not {
        let expectedLine = "Expected to not contain: <green>{f}<r>\n"
        let signature = Expect.getSignature(matcherName: "toContainEqual", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine, args: [expectedFmt])
    }

    let expectedLine = "Expected to contain: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature(matcherName: "toContainEqual", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}

// 用于 forEach 回调的上下文
private class ExpectedEntry {
    var globalThis: JSGlobalObject
    var expected: JSValue
    var pass: Bool
}
