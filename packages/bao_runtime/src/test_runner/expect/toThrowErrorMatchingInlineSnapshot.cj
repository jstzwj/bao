// 严格翻译自: src/runtime/test_runner/expect/toThrowErrorMatchingInlineSnapshot.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner
import bao_jsc.*

/// toThrowErrorMatchingInlineSnapshot() - 检查抛出的错误是否匹配行内快照
/// 用法: expect(fn).toThrowErrorMatchingInlineSnapshot(snapshot?)
public func toThrowErrorMatchingInlineSnapshot(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(2)
    let arguments = arguments_.slice()

    this.incrementExpectCallCounter()

    let not = this.flags.not
    if (not) {
        let signature = Expect.getSignature(matcherName: "toThrowErrorMatchingInlineSnapshot", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Snapshot matchers cannot be used with <b>not<r>\n", args: [])
    }

    var hasExpected = false
    var expectedString = ZigString.Empty
    if (arguments.length == 0) {
        // 无参数
    } else if (arguments.length == 1 ){
        if (arguments[0].isString() ){
            hasExpected = true
            arguments[0].toZigString(result: expectedString, globalThis: globalThis)
        } else {
            return this.throw_(globalThis: globalThis, signature: "",
                fmt: "\n\nMatcher error: Expected first argument to be a string\n", args: [])
        }
    } else {
        return this.throw_(globalThis: globalThis, signature: "",
            fmt: "\n\nMatcher error: Expected zero or one arguments\n", args: [])
    }

    var expected = expectedString.toSlice(allocator: default_allocator)
    defer { expected.deinit() }

    let expectedSlice: ?String = if (hasExpected) { expected.slice() } else { None }

    let valueOrNull: ?JSValue = this.fnToErrStringOrUndefined(globalThis: globalThis,
        value: this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toThrowErrorMatchingInlineSnapshot", matcherParamsFmt: "<green>properties<r><d>, <r>hint")
    )
    if (valueOrNull == None) {
        let signature = Expect.getSignature(matcherName: "toThrowErrorMatchingInlineSnapshot", args: "", not: false)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Received function did not throw\n", args: [])
    }
    let value: JSValue = valueOrNull.getOrThrow()

    return this.inlineSnapshot(globalThis: globalThis, callFrame: callFrame, value: value, propertyMatchers: None, expected: expectedSlice, matcherName: "toThrowErrorMatchingInlineSnapshot")
}
