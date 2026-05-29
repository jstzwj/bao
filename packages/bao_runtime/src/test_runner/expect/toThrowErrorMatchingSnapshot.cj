// 严格翻译自: src/runtime/test_runner/expect/toThrowErrorMatchingSnapshot.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toThrowErrorMatchingSnapshot() - 检查抛出的错误是否匹配快照
/// 用法: expect(fn).toThrowErrorMatchingSnapshot(hint?)
public func toThrowErrorMatchingSnapshot(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(2)
    let arguments = arguments_.slice()

    `this`.incrementExpectCallCounter()

    let not = `this`.flags.not
    if (not) {
        let signature = Expect.getSignature("toThrowErrorMatchingSnapshot", "", true)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Snapshot matchers cannot be used with <b>not<r>\n", args: [])
    }

    var buntestStrong = `this`.bunTest()
    if (buntestStrong.isNone()) {
        let signature = Expect.getSignature("toThrowErrorMatchingSnapshot", "", true)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Snapshot matchers cannot be used outside of a test\n", args: [])
    }

    var hintString = ""
    if (arguments.size == 0) {
        // 无参数
    } else if (arguments.size == 1) {
        if (arguments[0].isString()) {
            hintString = arguments[0].toString()
        } else {
            return `this`.throw_(globalThis: globalThis, signature: "",
                fmt: "\n\nMatcher error: Expected first argument to be a string\n", args: [])
        }
    } else {
        return `this`.throw_(globalThis: globalThis, signature: "",
            fmt: "\n\nMatcher error: Expected zero or one arguments\n", args: [])
    }

    let fnValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toThrowErrorMatchingSnapshot", matcherParamsFmt: "<green>properties<r><d>, <r>hint")
    let throwResult = `this`.getValueAsToThrow(globalThis: globalThis, value: fnValue)
    let threwValue = throwResult.first

    if (threwValue.isNone()) {
        let signature = Expect.getSignature("toThrowErrorMatchingSnapshot", "", false)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Received function did not throw\n", args: [])
    }

    let value = threwValue.getOrThrow()
    return `this`.snapshot(globalThis: globalThis, value: value, propertyMatchers: Option<JsValue>.None, hint: hintString, fnName: "toThrowErrorMatchingSnapshot")
}
