// 严格翻译自: src/runtime/test_runner/expect/toBeTypeOf.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toBeTypeOf() - 检查值的类型名称
/// 用法: expect(received).toBeTypeOf("string")
public func toBeTypeOf(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toBeTypeOf() requires 1 argument")
    }

    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeTypeOf", matcherParamsFmt: "")

    let expected = arguments[0]
    expected.ensureStillAlive()

    if (!expected.isString()) {
        return globalThis.throwInvalidArgumentsValue("toBeTypeOf() requires a string argument")
    }

    let expectedType = expected.toString()
    `this`.incrementExpectCallCounter()

    let validTypes = ["function", "object", "bigint", "boolean", "number", "string", "symbol", "undefined"]
    var isValidType = false
    for (vt in validTypes) {
        if (vt == expectedType) { isValidType = true; break }
    }
    if (!isValidType) {
        return globalThis.throwInvalidArgumentsValue("toBeTypeOf() requires a valid type string argument ('function', 'object', 'bigint', 'boolean', 'number', 'string', 'symbol', 'undefined')")
    }
    let typeOf = expectedType

    let not = `this`.flags.not
    var pass = false
    var whatIsTheType: String = ""

    // Checking for function/class should be done before everything else
    if (value.isCallable()) {
        whatIsTheType = "function"
    } else if (value.isObject() || value.jsType().isArray() || value.isNull()) {
        whatIsTheType = "object"
    } else if (value.isBigInt()) {
        whatIsTheType = "bigint"
    } else if (value.isBoolean()) {
        whatIsTheType = "boolean"
    } else if (value.isNumber()) {
        whatIsTheType = "number"
    } else if (value.jsType().isString()) {
        whatIsTheType = "string"
    } else if (value.isSymbol()) {
        whatIsTheType = "symbol"
    } else if (value.isUndefined()) {
        whatIsTheType = "undefined"
    } else {
        return globalThis.throw_("Internal consistency error: unknown JsValue type")
    }

    pass = typeOf == whatIsTheType

    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    let received = value.toFmt(formatter)
    let expectedStr = expected.toFmt(formatter)

    if (not) {
        let signature = Expect.getSignature("toBeTypeOf", "", true)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected type: not <green>{f}<r>\nReceived type: <red>\"{s}\"<r>\nReceived value: <red>{f}<r>\n",
            args: [expectedStr, whatIsTheType, received])
    }

    let signature = Expect.getSignature("toBeTypeOf", "", false)
    return `this`.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected type: <green>{f}<r>\nReceived type: <red>\"{s}\"<r>\nReceived value: <red>{f}<r>\n",
        args: [expectedStr, whatIsTheType, received])
}
