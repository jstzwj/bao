// 严格翻译自: src/runtime/test_runner/expect/toContain.zig

package bao_runtime

/// toContain() - 检查值是否包含期望值
/// 用法: expect(received).toContain(expected)
public func toContain(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toContain() takes 1 argument")
    }

    this.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toContain", matcherParamsFmt: "<green>expected<r>")

    let not = this.flags.not
    var pass = false

    if value.jsTypeLoose().isArrayLike() {
        var itr = value.arrayIterator(globalThis: globalThis)
        while (let item = itr.next()) {
            if item.isSameValue(expected, globalThis: globalThis) {
                pass = true
                break
            }
        }
    } else if value.isStringLiteral() && expected.isStringLiteral() {
        let valueString = value.toSlice(globalThis: globalThis, allocator: default_allocator)
        defer { valueString.deinit() }
        let expectedString = expected.toSlice(globalThis: globalThis, allocator: default_allocator)
        defer { expectedString.deinit() }

        if expectedString.length == 0 { // 空字符串边界情况
            pass = true
        } else if strings.contains(valueString.slice(), expectedString.slice()) {
            pass = true
        } else if valueString.length == 0 && expectedString.length == 0 { // 两个空字符串
            pass = true
        }
    } else if value.isIterable(globalThis: globalThis) {
        var expectedEntry = ExpectedEntry(globalThis: globalThis, expected: expected, pass: &pass)
        value.forEach(globalThis: globalThis, context: &expectedEntry, callback: { vm, globalObject, entry_, item =>
            let entry = entry_ as ExpectedEntry
            if item.isSameValue(entry.expected, entry.globalThis) {
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
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)
    if not {
        let receivedFmt = value.toFmt(formatter)
        let expectedLine = "Expected to not contain: <green>{f}<r>\nReceived: <red>{f}<r>\n"
        let signature = Expect.getSignature(matcherName: "toContain", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine, args: [expectedFmt, receivedFmt])
    }

    let expectedLine = "Expected to contain: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature(matcherName: "toContain", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}

// 用于 forEach 回调的上下文
private class ExpectedEntry {
    var globalThis: JSGlobalObject
    var expected: JSValue
    var pass: Bool
}
