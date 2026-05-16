// 严格翻译自: src/runtime/test_runner/expect/toContainAllKeys.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner
import bao_jsc.*

/// toContainAllKeys() - 检查对象是否恰好包含所有指定键
/// 用法: expect(received).toContainAllKeys(expected)
public func toContainAllKeys(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.length < 1) {
        return globalThis.throwInvalidArguments("toContainAllKeys() takes 1 argument")
    }

    this.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toContainAllKeys", matcherParamsFmt: "<green>expected<r>")

    if (!expected.jsType().isArray()) {
        return globalThis.throwInvalidArgumentType("toContainAllKeys", argName: "expected", expectedType: "array")
    }

    let not = this.flags.not
    var pass = false

    let count = expected.getLength(globalThis: globalThis)

    let keys = value.keys(globalThis: globalThis)
    if (keys.getLength(globalThis: globalThis) == count) {
        var itr = keys.arrayIterator(globalThis: globalThis)
        var allMatch = true
        while (let Some(item) <- itr.next()) {
            var i: UInt32 = 0
            var found = false
            while (i < count) {
                let key = expected.getIndex(globalThis: globalThis, index: i)
                if (item.jestDeepEquals(key, globalThis: globalThis)) {
                    found = true
                    break
                }
                i++
            }
            if (!found ){
                allMatch = false
                break
            }
        }
        if (allMatch) {
            pass = true
        }
    }

    if (not) { pass = !pass }
    if (pass) { return thisValue }

    // 处理失败
    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let keysFmt = keys.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)
    if (not) {
        let receivedFmt = keys.toFmt(formatter)
        let expectedLine = "Expected to not contain all keys: <green>{f}<r>\nReceived: <red>{f}<r>\n"
        return this.throw_(globalThis: globalThis, signature: Expect.getSignature(matcherName: "toContainAllKeys", args: "<green>expected<r>", not: true),
            fmt: "\n\n" + expectedLine, args: [expectedFmt, receivedFmt])
    }

    let expectedLine = "Expected to contain all keys: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    return this.throw_(globalThis: globalThis, signature: Expect.getSignature(matcherName: "toContainAllKeys", args: "<green>expected<r>", not: false),
        fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, keysFmt])
}
