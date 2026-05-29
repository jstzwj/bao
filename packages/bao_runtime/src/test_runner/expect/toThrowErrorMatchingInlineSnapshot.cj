// 严格翻译自: src/runtime/test_runner/expect/toThrowErrorMatchingInlineSnapshot.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toThrowErrorMatchingInlineSnapshot() - 检查抛出的错误是否匹配行内快照
/// 用法: expect(fn).toThrowErrorMatchingInlineSnapshot(snapshot?)
public func toThrowErrorMatchingInlineSnapshot(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(2)
    let arguments = arguments_.slice()

    `this`.incrementExpectCallCounter()

    let not = `this`.flags.not
    if (not) {
        let signature = Expect.getSignature("toThrowErrorMatchingInlineSnapshot", "", true)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Snapshot matchers cannot be used with <b>not<r>\n", args: [])
    }

    var hasExpected = false
    var expectedString = ""
    if (arguments.size == 0) {
        // 无参数
    } else if (arguments.size == 1) {
        if (arguments[0].isString()) {
            hasExpected = true
            expectedString = arguments[0].toString()
        } else {
            return `this`.throw_(globalThis: globalThis, signature: "",
                fmt: "\n\nMatcher error: Expected first argument to be a string\n", args: [])
        }
    } else {
        return `this`.throw_(globalThis: globalThis, signature: "",
            fmt: "\n\nMatcher error: Expected zero or one arguments\n", args: [])
    }

    let expectedSlice: ?String = if (hasExpected) { expectedString } else { Option<String>.None }

    let fnValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toThrowErrorMatchingInlineSnapshot", matcherParamsFmt: "<green>properties<r><d>, <r>hint")
    let throwResult = `this`.getValueAsToThrow(globalThis: globalThis, value: fnValue)
    let threwValue = throwResult.first

    if (threwValue.isNone()) {
        let signature = Expect.getSignature("toThrowErrorMatchingInlineSnapshot", "", false)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Received function did not throw\n", args: [])
    }

    let value = threwValue.getOrThrow()
    return `this`.inlineSnapshot(globalThis: globalThis, callFrame: callFrame, value: value, propertyMatchers: Option<JsValue>.None, result: expectedSlice, fnName: "toThrowErrorMatchingInlineSnapshot")
}
