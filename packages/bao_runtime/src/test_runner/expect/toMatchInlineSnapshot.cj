// 严格翻译自: src/runtime/test_runner/expect/toMatchInlineSnapshot.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner
import bao_jsc.*

/// toMatchInlineSnapshot() - 行内快照匹配
/// 用法: expect(received).toMatchInlineSnapshot(snapshot) / expect(received).toMatchInlineSnapshot(properties, hint)
public func toMatchInlineSnapshot(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(2)
    let arguments = arguments_.slice()

    this.incrementExpectCallCounter()

    let not = this.flags.not
    if (not) {
        let signature = Expect.getSignature(matcherName: "toMatchInlineSnapshot", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Snapshot matchers cannot be used with <b>not<r>\n", args: [])
    }

    var hasExpected = false
    var expectedString = ZigString.Empty
    var propertyMatchers: ?JSValue = None
    if (arguments.length == 0) {
        // 无参数
    } else if (arguments.length == 1 ){
        if (arguments[0].isString() ){
            hasExpected = true
            arguments[0].toZigString(result: expectedString, globalThis: globalThis)
        } else if (arguments[0].isObject()) {
            propertyMatchers = arguments[0]
        } else {
            return this.throw_(globalThis: globalThis, signature: "",
                fmt: "\n\nMatcher error: Expected first argument to be a string or object\n", args: [])
        }
    } else {
        if (!arguments[0].isObject()) {
            let signature = Expect.getSignature(matcherName: "toMatchInlineSnapshot", args: "<green>properties<r><d>, <r>hint", not: false)
            return this.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nMatcher error: Expected <green>properties<r> must be an object\n", args: [])
        }

        propertyMatchers = arguments[0]

        if (arguments[1].isString() ){
            hasExpected = true
            arguments[1].toZigString(result: expectedString, globalThis: globalThis)
        }
    }

    var expected = expectedString.toSlice(allocator: default_allocator)
    defer { expected.deinit() }

    let expectedSlice: ?String = if (hasExpected) { expected.slice() } else { None }

    let value = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toMatchInlineSnapshot", matcherParamsFmt: "<green>properties<r><d>, <r>hint")
    return this.inlineSnapshot(globalThis: globalThis, callFrame: callFrame, value: value, propertyMatchers: propertyMatchers, result: expectedSlice, fnName: "toMatchInlineSnapshot")
}
