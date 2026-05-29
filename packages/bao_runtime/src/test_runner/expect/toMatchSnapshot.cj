// 严格翻译自: src/runtime/test_runner/expect/toMatchSnapshot.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toMatchSnapshot() - 快照匹配
/// 用法: expect(received).toMatchSnapshot() / expect(received).toMatchSnapshot(hint) / expect(received).toMatchSnapshot(properties, hint)
public func toMatchSnapshot(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(2)
    let arguments = arguments_.slice()

    `this`.incrementExpectCallCounter()

    let not = `this`.flags.not
    if (not) {
        let signature = Expect.getSignature("toMatchSnapshot", "", true)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Snapshot matchers cannot be used with <b>not<r>\n", args: [])
    }

    var buntestStrong = `this`.bunTest()
    if (buntestStrong.isNone()) {
        let signature = Expect.getSignature("toMatchSnapshot", "", true)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Snapshot matchers cannot be used outside of a test\n", args: [])
    }
    // defer { buntestStrong.deinit() }

    var hintString = ""
    var propertyMatchers: ?JsValue = None
    if (arguments.size == 0) {
        // 无参数
    } else if (arguments.size == 1) {
        if (arguments[0].isString()) {
            hintString = arguments[0].toString()
        } else if (arguments[0].isObject()) {
            propertyMatchers = arguments[0]
        } else {
            return `this`.throw_(globalThis: globalThis, signature: "",
                fmt: "\n\nMatcher error: Expected first argument to be a string or object\n", args: [])
        }
    } else {
        if (!arguments[0].isObject()) {
            let signature = Expect.getSignature("toMatchSnapshot", "<green>properties<r><d>, <r>hint", false)
            return `this`.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nMatcher error: Expected <green>properties<r> must be an object\n", args: [])
        }

        propertyMatchers = arguments[0]

        if (arguments[1].isString()) {
            hintString = arguments[1].toString()
        } else {
            return `this`.throw_(globalThis: globalThis, signature: "",
                fmt: "\n\nMatcher error: Expected second argument to be a string\n", args: [])
        }
    }

    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toMatchSnapshot", matcherParamsFmt: "<green>properties<r><d>, <r>hint")

    return `this`.snapshot(globalThis: globalThis, value: value, propertyMatchers: propertyMatchers, hint: hintString, fnName: "toMatchSnapshot")
}
