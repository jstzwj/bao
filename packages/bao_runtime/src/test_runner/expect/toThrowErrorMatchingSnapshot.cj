// 严格翻译自: src/runtime/test_runner/expect/toThrowErrorMatchingSnapshot.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner
import bao_jsc.*

/// toThrowErrorMatchingSnapshot() - 检查抛出的错误是否匹配快照
/// 用法: expect(fn).toThrowErrorMatchingSnapshot(hint?)
public func toThrowErrorMatchingSnapshot(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(2)
    let arguments = arguments_.slice()

    this.incrementExpectCallCounter()

    let not = this.flags.not
    if (not) {
        let signature = Expect.getSignature(matcherName: "toThrowErrorMatchingSnapshot", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Snapshot matchers cannot be used with <b>not<r>\n", args: [])
    }

    var buntestStrong = this.bunTest()
    if (buntestStrong == None) {
        let signature = Expect.getSignature(matcherName: "toThrowErrorMatchingSnapshot", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Snapshot matchers cannot be used outside of a test\n", args: [])
    }
    defer { buntestStrong.deinit() }

    var hintString = ZigString.Empty
    if (arguments.length == 0) {
        // 无参数
    } else if (arguments.length == 1 ){
        if (arguments[0].isString() ){
            hintString = arguments[0].toZigString(globalThis: globalThis)
        } else {
            return this.throw_(globalThis: globalThis, signature: "",
                fmt: "\n\nMatcher error: Expected first argument to be a string\n", args: [])
        }
    } else {
        return this.throw_(globalThis: globalThis, signature: "",
            fmt: "\n\nMatcher error: Expected zero or one arguments\n", args: [])
    }

    var hint = hintString.toSlice(allocator: default_allocator)
    defer { hint.deinit() }

    let valueOrNull: ?JSValue = this.fnToErrStringOrUndefined(globalThis: globalThis,
        value: this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toThrowErrorMatchingSnapshot", matcherParamsFmt: "<green>properties<r><d>, <r>hint")
    )
    if (valueOrNull == None) {
        let signature = Expect.getSignature(matcherName: "toThrowErrorMatchingSnapshot", args: "", not: false)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Received function did not throw\n", args: [])
    }
    let value: JSValue = valueOrNull.getOrThrow()

    return this.snapshot(globalThis: globalThis, value: value, propertyMatchers: None, hint: hint.slice(), matcherName: "toThrowErrorMatchingSnapshot")
}
