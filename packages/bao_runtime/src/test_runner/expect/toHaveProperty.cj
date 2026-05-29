// 严格翻译自: src/runtime/test_runner/expect/toHaveProperty.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toHaveProperty() - 检查对象是否具有指定属性
/// 用法: expect(obj).toHaveProperty(path) / expect(obj).toHaveProperty(path, value)
public func toHaveProperty(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(2)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toHaveProperty() requires at least 1 argument")
    }

    `this`.incrementExpectCallCounter()

    let expectedPropertyPath = arguments[0]
    expectedPropertyPath.ensureStillAlive()
    let expectedProperty: ?JsValue = if (arguments.size > 1) { arguments[1] } else { None }
    if (expectedProperty.isSome()) { expectedProperty.getOrThrow().ensureStillAlive() }

    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveProperty", matcherParamsFmt: "<green>path<r><d>, <r><green>value<r>")

    if (!expectedPropertyPath.isString() && !expectedPropertyPath.isIterable(globalThis.globalThis) ){
        return globalThis.throw_("Expected path must be a string or an array")
    }

    let not = `this`.flags.not

    var pass = !value.isUndefinedOrNull()
    var receivedProperty: JsValue = JsValue.zero

    if (pass) {
        let propOpt = value.getIfPropertyExistsFromPath(globalThis.globalThis, expectedPropertyPath)
        if (propOpt.isSome()) {
            receivedProperty = propOpt.getOrThrow()
        }
        pass = receivedProperty != JsValue.zero
    }

    if (pass && expectedProperty.isSome()) {
        pass = receivedProperty.jestDeepEquals(expectedProperty.getOrThrow(), globalThis: globalThis)
    }

    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    // 处理失败
    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    if (not) {
        if (expectedProperty.isSome()) {
            let signature = Expect.getSignature("toHaveProperty", "<green>path<r><d>, <r><green>value<r>", true)
            if (receivedProperty != JsValue.zero) {
                return `this`.throw_(globalThis: globalThis, signature: signature,
                    fmt: "\n\nExpected path: <green>{f}<r>\n\nExpected value: not <green>{f}<r>\n",
                    args: [expectedPropertyPath.toFmt(formatter), expectedProperty.getOrThrow().toFmt(formatter)])
            }
        }

        let signature = Expect.getSignature("toHaveProperty", "<green>path<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected path: not <green>{f}<r>\n\nReceived value: <red>{f}<r>\n",
            args: [expectedPropertyPath.toFmt(formatter), receivedProperty.toFmt(formatter)])
    }

    if (expectedProperty.isSome()) {
        let signature = Expect.getSignature("toHaveProperty", "<green>path<r><d>, <r><green>value<r>", false)
        if (receivedProperty != JsValue.zero) {
            // deep equal case
            let diffFormat = DiffFormatter(receivedProperty, expectedProperty.getOrThrow(), globalThis, false)
            return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormat])
        }

        let fmt = "\n\nExpected path: <green>{f}<r>\n\nExpected value: <green>{f}<r>\n\n" +
            "Unable to find property\n"
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: fmt,
            args: [expectedPropertyPath.toFmt(formatter), expectedProperty.getOrThrow().toFmt(formatter)])
    }

    let signature = Expect.getSignature("toHaveProperty", "<green>path<r>", false)
    return `this`.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected path: <green>{f}<r>\n\nUnable to find property\n",
        args: [expectedPropertyPath.toFmt(formatter)])
}
