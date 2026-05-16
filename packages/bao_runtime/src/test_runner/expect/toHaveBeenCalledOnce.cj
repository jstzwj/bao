// 严格翻译自: src/runtime/test_runner/expect/toHaveBeenCalledOnce.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner
import bao_jsc.*

/// toHaveBeenCalledOnce() - 检查mock函数是否只被调用一次
/// 用法: expect(mockFn).toHaveBeenCalledOnce()
public func toHaveBeenCalledOnce(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveBeenCalledOnce", matcherParamsFmt: "<green>expected<r>")

    this.incrementExpectCallCounter()

    let calls = JSMockFunction.getCalls(globalThis: globalThis, value: value)
    if (!calls.jsType().isArray()) {
        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        defer { formatter.deinit() }
        return globalThis.throw_("Expected value must be a mock function: {f}", args: [value.toFmt(formatter)])
    }

    let callsLength = calls.getLength(globalThis: globalThis)
    var pass = callsLength == 1

    let not = this.flags.not
    if (not) { pass = !pass }
    if (pass) { return JSValue.jsUndefined }

    // 处理失败
    if (not) {
        let signature = Expect.getSignature(matcherName: "toHaveBeenCalledOnce", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected number of calls: not <green>1<r>\nReceived number of calls: <red>{d}<r>\n",
            args: [callsLength])
    }

    let signature = Expect.getSignature(matcherName: "toHaveBeenCalledOnce", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected number of calls: <green>1<r>\nReceived number of calls: <red>{d}<r>\n",
        args: [callsLength])
}
