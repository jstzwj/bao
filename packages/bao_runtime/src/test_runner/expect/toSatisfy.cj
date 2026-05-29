// 严格翻译自: src/runtime/test_runner/expect/toSatisfy.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toSatisfy() - 检查值是否满足自定义谓词
/// 用法: expect(received).toSatisfy(predicate)
public func toSatisfy(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toSatisfy() requires 1 argument")
    }

    `this`.incrementExpectCallCounter()

    let predicate = arguments[0]
    predicate.ensureStillAlive()

    if (!predicate.isCallable()) {
        return globalThis.throw_("toSatisfy() argument must be a function")
    }

    let valueOpt = capturedValueGetCached(thisValue)
    if (valueOpt.isNone()) {
        return globalThis.throw_("Internal consistency error: the expect(value) was garbage collected but it should not have been!")
    }
    let value = valueOpt.getOrThrow()
    value.ensureStillAlive()

    let global = globalThis.globalThis
    let result = predicate.callWithCatch(globalThis: globalThis, thisValue: JsValue.jsUndefined(), args: [value])

    let not = `this`.flags.not
    let pass = (result.isBoolean() && result.toBoolean()) != not

    if (pass) { return JsValue.jsUndefined() }

    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }

    if (not) {
        let signature = Expect.getSignature("toSatisfy", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected: not <green>{f}<r>\n", args: [predicate.toFmt(formatter)])
    }

    let signature = Expect.getSignature("toSatisfy", "<green>expected<r>", false)
    return `this`.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected: <green>{f}<r>\nReceived: <red>{f}<r>\n",
        args: [predicate.toFmt(formatter), value.toFmt(formatter)])
}
