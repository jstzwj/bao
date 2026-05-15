// 严格翻译自: src/runtime/test_runner/expect/toBeOneOf.zig

package bao_runtime

/// toBeOneOf() - 检查值是否在给定集合中
/// 用法: expect(received).toBeOneOf(list)
public func toBeOneOf(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toBeOneOf() takes 1 argument")
    }

    this.incrementExpectCallCounter()

    let expected = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeOneOf", matcherParamsFmt: "<green>expected<r>")
    let listValue: JSValue = arguments[0]

    let not = this.flags.not
    var pass = false

    if listValue.jsTypeLoose().isArrayLike() {
        var itr = listValue.arrayIterator(globalThis: globalThis)
        while (let item = itr.next()) {
            // jest-extended uses `deepEqual`, instead of `toBe`
            if item.jestDeepEquals(expected, globalThis: globalThis) {
                pass = true
                break
            }
        }
    } else if listValue.isIterable(globalThis: globalThis) {
        var expectedEntry = ExpectedEntry(globalThis: globalThis, expected: expected, pass: &pass)
        listValue.forEach(globalThis: globalThis, context: &expectedEntry, callback: { vm, globalObject, entry_, item =>
            let entry = entry_ as ExpectedEntry
            if item.jestDeepEquals(entry.expected, entry.globalThis) {
                entry.pass = true
            }
        })
    } else {
        return globalThis.throw_("Received value must be an array type, or both received and expected values must be strings.")
    }

    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    // 处理失败
    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let valueFmt = listValue.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)
    if not {
        let receivedFmt = listValue.toFmt(formatter)
        let expectedLine = "Expected to not be one of: <green>{f}<r>\nReceived: <red>{f}<r>\n"
        let signature = Expect.getSignature(matcherName: "toBeOneOf", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine, args: [receivedFmt, expectedFmt])
    }

    let expectedLine = "Expected to be one of: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature(matcherName: "toBeOneOf", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [valueFmt, expectedFmt])
}

// 用于 forEach 回调的上下文
private class ExpectedEntry {
    var globalThis: JSGlobalObject
    var expected: JSValue
    var pass: Bool
}
