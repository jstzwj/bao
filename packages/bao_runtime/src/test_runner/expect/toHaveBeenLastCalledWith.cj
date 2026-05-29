// 严格翻译自: src/runtime/test_runner/expect/toHaveBeenLastCalledWith.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toHaveBeenLastCalledWith() - 检查mock函数最后一次调用的参数
/// 用法: expect(mockFn).toHaveBeenLastCalledWith(...expected)
public func toHaveBeenLastCalledWith(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments = callFrame.argumentsAsArray(0)
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveBeenLastCalledWith", matcherParamsFmt: "<green>...expected<r>")

    `this`.incrementExpectCallCounter()

    let global = globalThis.globalThis
    let calls = JSMockFunction.getCalls(globalThis: global, value: value)
    if (!calls.jsType().isArray()) {
        let formatter = ConsoleFormatter()
        // defer { formatter.deinit() }
        let signature = Expect.getSignature("toHaveBeenLastCalledWith", "<green>...expected<r>", false)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nMatcher error: <red>received<r> value must be a mock function\nReceived: {f}",
            args: [value.toFmt(formatter)])
    }

    let totalCalls: UInt32 = UInt32(calls.getLength(global))
    var lastCallValue: JsValue = JsValue.zero

    var pass = totalCalls > 0

    if (pass) {
        lastCallValue = calls.getIndex(global, totalCalls - 1)

        if (!lastCallValue.jsType().isArray()) {
            let formatter = ConsoleFormatter()
            // defer { formatter.deinit() }
            return globalThis.throw_("Expected value must be a mock function with calls: {f}", args: [value.toFmt(formatter)])
        }

        if (Int64(lastCallValue.getLength(global)) != Int64(arguments.size)) {
            pass = false
        } else {
            var itr = lastCallValue.arrayIterator(global)
            while (let Some(callArg) <- itr.next()) {
                if (!callArg.jestDeepEquals(arguments[Int64(itr.i - 1)], globalThis: globalThis)) {
                    pass = false
                    break
                }
            }
        }
    }

    if (pass != `this`.flags.not) {
        return JsValue.jsUndefined()
    }

    // 处理失败
    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }

    let expectedArgsJsArray = JsValue.createEmptyArray(global, Int64(arguments.size))
    for (i in 0..arguments.size) {
        expectedArgsJsArray.putIndex(global, UInt32(i), arguments[i])
    }
    expectedArgsJsArray.ensureStillAlive()

    if (`this`.flags.not) {
        let signature = Expect.getSignature("toHaveBeenLastCalledWith", "<green>...expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected last call not to be with: <green>{f}<r>\nBut it was.",
            args: [expectedArgsJsArray.toFmt(formatter)])
    }
    let signature = Expect.getSignature("toHaveBeenLastCalledWith", "<green>...expected<r>", false)

    if (totalCalls == 0) {
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected: <green>{f}<r>\nBut it was not called.",
            args: [expectedArgsJsArray.toFmt(formatter)])
    }

    let diffFormat = DiffFormatter(lastCallValue, expectedArgsJsArray, globalThis, false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormat])
}
