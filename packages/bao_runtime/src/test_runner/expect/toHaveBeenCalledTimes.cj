// 严格翻译自: src/runtime/test_runner/expect/toHaveBeenCalledTimes.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toHaveBeenCalledTimes() - 检查mock函数被调用的次数
/// 用法: expect(mockFn).toHaveBeenCalledTimes(times)
public func toHaveBeenCalledTimes(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveBeenCalledTimes", matcherParamsFmt: "<green>expected<r>")

    `this`.incrementExpectCallCounter()

    let global = globalThis.globalThis
    let calls = JSMockFunction.getCalls(globalThis: global, value: value)
    if (!calls.jsType().isArray()) {
        let formatter = ConsoleFormatter()
        // defer { formatter.deinit() }
        return globalThis.throw_("Expected value must be a mock function: {f}", args: [value.toFmt(formatter)])
    }

    if (arguments.size < 1 || !arguments[0].isAnyInt()) {
        return globalThis.throwInvalidArgumentsValue("toHaveBeenCalledTimes() requires 1 non-negative integer argument")
    }

    let times = arguments[0].toInt32()

    var pass = Int32(calls.getLength(global)) == times

    let not = `this`.flags.not
    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    // 处理失败
    if (not) {
        let signature = Expect.getSignature("toHaveBeenCalledTimes", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected number of calls: not <green>{d}<r>\nReceived number of calls: <red>{d}<r>\n",
            args: [times, calls.getLength(global)])
    }

    let signature = Expect.getSignature("toHaveBeenCalledTimes", "<green>expected<r>", false)
    return `this`.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected number of calls: <green>{d}<r>\nReceived number of calls: <red>{d}<r>\n",
        args: [times, calls.getLength(global)])
}
