// 严格翻译自: src/runtime/test_runner/expect/toBeEmpty.zig

package bao_runtime

/// toBeEmpty() - 检查值是否为空（空字符串、空数组、空对象等）
/// 用法: expect(received).toBeEmpty()
public func toBeEmpty(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeEmpty", matcherParamsFmt: "")

    this.incrementExpectCallCounter()

    let not = this.flags.not
    var pass = false

    if value.isString() {
        let s = value.toSliceOrNull(globalThis: globalThis)
        defer { s.deinit() }
        pass = s.slice().length == 0
    } else if value.jsType().isArray() {
        pass = value.getLength(globalThis: globalThis) == 0
    } else if value.isObject() {
        pass = try value.getLength(globalThis: globalThis) == 0
    } else {
        pass = value.isUndefinedOrNull()
    }

    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let received = value.toFmt(formatter)

    if not {
        let signature = Expect.getSignature(matcherName: "toBeEmpty", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
    }

    let signature = Expect.getSignature(matcherName: "toBeEmpty", args: "", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
}
