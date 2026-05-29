// 严格翻译自: src/runtime/test_runner/expect/toContainAllKeys.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toContainAllKeys() - 检查对象是否恰好包含所有指定键
/// 用法: expect(received).toContainAllKeys(expected)
public func toContainAllKeys(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toContainAllKeys() takes 1 argument")
    }

    `this`.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toContainAllKeys", matcherParamsFmt: "<green>expected<r>")

    if (!expected.jsType().isArray()) {
        return globalThis.throwInvalidArgumentsValue("Expected expected to be a array for 'toContainAllKeys'.")
    }

    let not = `this`.flags.not
    var pass = false
    let global = globalThis.globalThis

    let count = expected.getLength(global)

    let keys = JsValue.keys(value, global)
    if (keys.getLength(global) == count) {
        var itr = keys.arrayIterator(global)
        var allMatch = true
        while (let Some(item) <- itr.next()) {
            var i: UInt32 = 0
            var found = false
            while (i < UInt32(count)) {
                let key = expected.getIndex(global, i)
                if (item.jestDeepEquals(key, globalThis: globalThis)) {
                    found = true
                    break
                }
                i++
            }
            if (!found) {
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
    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    let keysFmt = keys.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)
    if (not) {
        let receivedFmt = keys.toFmt(formatter)
        let expectedLine = "Expected to not contain all keys: <green>{f}<r>\nReceived: <red>{f}<r>\n"
        return `this`.throw_(globalThis: globalThis, signature: Expect.getSignature("toContainAllKeys", "<green>expected<r>", true),
            fmt: "\n\n" + expectedLine, args: [expectedFmt, receivedFmt])
    }

    let expectedLine = "Expected to contain all keys: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    return `this`.throw_(globalThis: globalThis, signature: Expect.getSignature("toContainAllKeys", "<green>expected<r>", false),
        fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, keysFmt])
}
