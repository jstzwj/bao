// 严格翻译自: src/runtime/test_runner/expect/toBeTypeOf.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner
import bao_jsc.*

/// toBeTypeOf() - 检查值的类型名称
/// 用法: expect(received).toBeTypeOf("string")
public func toBeTypeOf(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.length < 1) {
        return globalThis.throwInvalidArguments("toBeTypeOf() requires 1 argument")
    }

    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeTypeOf", matcherParamsFmt: "")

    let expected = arguments[0]
    expected.ensureStillAlive()

    if (!expected.isString()) {
        return globalThis.throwInvalidArguments("toBeTypeOf() requires a string argument")
    }

    let expectedType = expected.toBunString(globalThis: globalThis)
    defer { expectedType.deref() }
    this.incrementExpectCallCounter()

    let typeOfOpt = expectedType.inMap(JSTypeOfMap)
    if (typeOfOpt == None) {
        return globalThis.throwInvalidArguments("toBeTypeOf() requires a valid type string argument ('function', 'object', 'bigint', 'boolean', 'number', 'string', 'symbol', 'undefined')")
    }
    let typeOf = typeOfOpt.getOrThrow()

    let not = this.flags.not
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
        return globalThis.throw_("Internal consistency error: unknown JSValue type")
    }

    pass = strings.eql(typeOf, whatIsTheType)

    if (not) { pass = !pass }
    if (pass) { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let received = value.toFmt(formatter)
    let expectedStr = expected.toFmt(formatter)

    if (not) {
        let signature = Expect.getSignature(matcherName: "toBeTypeOf", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected type: not <green>{f}<r>\nReceived type: <red>\"{s}\"<r>\nReceived value: <red>{f}<r>\n",
            args: [expectedStr, whatIsTheType, received])
    }

    let signature = Expect.getSignature(matcherName: "toBeTypeOf", args: "", not: false)
    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected type: <green>{f}<r>\nReceived type: <red>\"{s}\"<r>\nReceived value: <red>{f}<r>\n",
        args: [expectedStr, whatIsTheType, received])
}

// 类型名称映射表
private func getJSTypeOfMap(): HashMap<String, String> {
    let m = HashMap<String, String>()
    m.put("function", "function")
    m.put("object", "object")
    m.put("bigint", "bigint")
    m.put("boolean", "boolean")
    m.put("number", "number")
    m.put("string", "string")
    m.put("symbol", "symbol")
    m.put("undefined", "undefined")
    return m
}
private let JSTypeOfMap = getJSTypeOfMap()
