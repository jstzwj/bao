// 严格翻译自: src/runtime/test_runner/expect/toHaveBeenCalledWith.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toHaveBeenCalledWith() - 检查mock函数是否以指定参数被调用
/// 用法: expect(mockFn).toHaveBeenCalledWith(...expected)
public func toHaveBeenCalledWith(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments = callFrame.argumentsAsArray(0)
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveBeenCalledWith", matcherParamsFmt: "<green>...expected<r>")

    `this`.incrementExpectCallCounter()

    let global = globalThis.globalThis
    let calls = JSMockFunction.getCalls(globalThis: global, value: value)
    if (!calls.jsType().isArray()) {
        let formatter = ConsoleFormatter()
        // defer { formatter.deinit() }
        let signature = Expect.getSignature("toHaveBeenCalledWith", "<green>...expected<r>", false)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nMatcher error: <red>received<r> value must be a mock function\nReceived: {f}",
            args: [value.toFmt(formatter)])
    }

    var pass = false

    let callsCount: UInt32 = UInt32(calls.getLength(global))
    if (callsCount > 0) {
        var itr = calls.arrayIterator(global)
        while (let Some(callItem) <- itr.next()) {
            if (callItem == JsValue.zero || !callItem.jsType().isArray()) {
                return globalThis.throw_("Internal error: expected mock call item to be an array of arguments.")
            }

            if (Int64(callItem.getLength(global)) != Int64(arguments.size)) {
                continue
            }

            var callItr = callItem.arrayIterator(global)
            var isMatch = true
            while (let Some(callArg) <- callItr.next()) {
                if (!callArg.jestDeepEquals(arguments[Int64(callItr.i - 1)], globalThis: globalThis)) {
                    isMatch = false
                    break
                }
            }

            if (isMatch) {
                pass = true
                break
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
        let signature = Expect.getSignature("toHaveBeenCalledWith", "<green>...expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected mock function not to have been called with: <green>{f}<r>\nBut it was.",
            args: [expectedArgsJsArray.toFmt(formatter)])
    }
    let signature = Expect.getSignature("toHaveBeenCalledWith", "<green>...expected<r>", false)

    if (callsCount == 0) {
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected: <green>{f}<r>\nBut it was not called.",
            args: [expectedArgsJsArray.toFmt(formatter)])
    }

    // 如果只有一次调用，提供漂亮的 diff
    if (callsCount == 1) {
        let receivedCallArgs = calls.getIndex(global, 0)
        let diffFormat = DiffFormatter(receivedCallArgs, expectedArgsJsArray, globalThis, false)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormat])
    }

    // 多次调用时，列出所有调用帮助调试
    let listFormatter = AllCallsWithArgsFormatter(globalThis, calls)

    let fmt =
        "    <green>Expected<r>: {f}\n" +
        "    <red>Received<r>:\n" +
        "{f}\n\n" +
        "    Number of calls: {d}"

    return `this`.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\n" + fmt + "\n",
        args: [expectedArgsJsArray.toFmt(formatter), listFormatter, callsCount])
}
