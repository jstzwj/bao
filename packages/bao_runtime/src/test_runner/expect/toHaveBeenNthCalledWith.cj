// 严格翻译自: src/runtime/test_runner/expect/toHaveBeenNthCalledWith.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toHaveBeenNthCalledWith() - 检查mock函数第N次调用的参数
/// 用法: expect(mockFn).toHaveBeenNthCalledWith(n, ...expected)
public func toHaveBeenNthCalledWith(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let allArgs = callFrame.argumentsAsArray(0)
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveBeenNthCalledWith", matcherParamsFmt: "<green>n<r>, <green>...expected<r>")

    `this`.incrementExpectCallCounter()

    let global = globalThis.globalThis
    let calls = JSMockFunction.getCalls(globalThis: global, value: value)
    if (!calls.jsType().isArray()) {
        let formatter = ConsoleFormatter()
        // defer { formatter.deinit() }
        let signature = Expect.getSignature("toHaveBeenNthCalledWith", "<green>n<r>, <green>...expected<r>", false)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nMatcher error: <red>received<r> value must be a mock function\nReceived: {f}",
            args: [value.toFmt(formatter)])
    }

    if (allArgs.size == 0 || !allArgs[0].isAnyInt()) {
        return globalThis.throwInvalidArgumentsValue("toHaveBeenNthCalledWith() requires a positive integer as the first argument")
    }
    let nthCallNumI32 = allArgs[0].toInt32()

    if (nthCallNumI32 <= 0) {
        return globalThis.throwInvalidArgumentsValue("toHaveBeenNthCalledWith() first argument must be a positive integer")
    }
    let nthCallNum: UInt32 = UInt32(nthCallNumI32)

    let expectedArgs = if (allArgs.size > 1) { allArgs.slice(1, allArgs.size) } else { allArgs.slice(0, 0) }

    let totalCalls: UInt32 = UInt32(calls.getLength(global))
    var pass = totalCalls >= nthCallNum
    var nthCallValue: JsValue = JsValue.zero

    if (pass) {
        nthCallValue = calls.getIndex(global, nthCallNum - 1)

        if (!nthCallValue.jsType().isArray()) {
            return globalThis.throw_("Internal error: expected mock call item to be an array of arguments.")
        }

        if (Int64(nthCallValue.getLength(global)) != Int64(expectedArgs.size)) {
            pass = false
        } else {
            var itr = nthCallValue.arrayIterator(global)
            while (let Some(callArg) <- itr.next()) {
                if (!callArg.jestDeepEquals(expectedArgs[Int64(itr.i - 1)], globalThis: globalThis)) {
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

    let expectedArgsJsArray = JsValue.createEmptyArray(global, Int64(expectedArgs.size))
    for (i in 0..expectedArgs.size) {
        expectedArgsJsArray.putIndex(global, UInt32(i), expectedArgs[i])
    }
    expectedArgsJsArray.ensureStillAlive()

    if (`this`.flags.not) {
        let signature = Expect.getSignature("toHaveBeenNthCalledWith", "<green>n<r>, <green>...expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected call #{d} not to be with: <green>{f}<r>\nBut it was.",
            args: [nthCallNum, expectedArgsJsArray.toFmt(formatter)])
    }
    let signature = Expect.getSignature("toHaveBeenNthCalledWith", "<green>n<r>, <green>...expected<r>", false)

    // 函数调用次数不够
    if (totalCalls < nthCallNum) {
        let pluralSuffix = if (totalCalls == 1) { "" } else { "s" }
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nThe mock function was called {d} time{s}, but call {d} was requested.",
            args: [totalCalls, pluralSuffix, nthCallNum])
    }

    // 调用存在但不匹配，显示差异
    let diffFormat = DiffFormatter(nthCallValue, expectedArgsJsArray, globalThis, false)
    return `this`.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nCall #{d}:\n{f}\n",
        args: [nthCallNum, diffFormat])
}
