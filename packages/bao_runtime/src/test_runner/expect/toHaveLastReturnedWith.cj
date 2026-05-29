// 严格翻译自: src/runtime/test_runner/expect/toHaveLastReturnedWith.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toHaveLastReturnedWith() - 检查mock函数最后一次返回的值
/// 用法: expect(mockFn).toHaveLastReturnedWith(expected)
public func toHaveLastReturnedWith(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveBeenLastReturnedWith", matcherParamsFmt: "<green>expected<r>")

    let expected = callFrame.argumentsAsArray(1)[0]
    `this`.incrementExpectCallCounter()

    let global = globalThis.globalThis
    let returns = JSMockFunction.getReturnValues(globalThis: global, value: value)
    if (!returns.jsType().isArray()) {
        let formatter = ConsoleFormatter()
        // defer { formatter.deinit() }
        return globalThis.throw_("Expected value must be a mock function: {f}", args: [value.toFmt(formatter)])
    }

    let callsCount: UInt32 = UInt32(returns.getLength(global))
    var pass = false
    var lastReturnValue: JsValue = JsValue.jsUndefined()
    var lastCallThrew = false
    var lastErrorValue: JsValue = JsValue.jsUndefined()

    if (callsCount > 0) {
        let lastResult = returns.getIndex(global, callsCount - 1)

        if (lastResult.isObject()) {
            let resultType = lastResult.get(global, "type") ?? JsValue.jsUndefined()
            if (resultType.isString()) {
                let typeStr = resultType.toString()

                if (typeStr == "return") {
                    lastReturnValue = lastResult.get(global, "value") ?? JsValue.jsUndefined()

                    if (lastReturnValue.jestDeepEquals(expected, globalThis: globalThis)) {
                        pass = true
                    }
                } else if (typeStr == "throw") {
                    lastCallThrew = true
                    lastErrorValue = lastResult.get(global, "value") ?? JsValue.jsUndefined()
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

    let signature = Expect.getSignature("toHaveBeenLastReturnedWith", "<green>expected<r>", false)

    if (`this`.flags.not) {
        let notSignature = Expect.getSignature("toHaveBeenLastReturnedWith", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: notSignature,
            fmt: "\n\nExpected mock function not to have last returned: <green>{f}<r>\nBut it did.\n",
            args: [expected.toFmt(formatter)])
    }

    if (callsCount == 0) {
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nThe mock function was not called.", args: [])
    }

    if (lastCallThrew) {
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nThe last call threw an error: <red>{f}<r>\n",
            args: [lastErrorValue.toFmt(formatter)])
    }

    // 如果可能则显示 diff
    if (expected.isString() && lastReturnValue.isString()) {
        let diffFormat = DiffFormatter(lastReturnValue, expected, globalThis, false)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormat])
    }

    return `this`.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected: <green>{f}<r>\nReceived: <red>{f}<r>",
        args: [expected.toFmt(formatter), lastReturnValue.toFmt(formatter)])
}
