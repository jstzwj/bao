// 严格翻译自: src/runtime/test_runner/expect/toBeArrayOfSize.zig

package bao_runtime.test_runner.expect

/// toBeArrayOfSize() - 检查值是否为指定大小的数组
/// 用法: expect(received).toBeArrayOfSize(size)
public func toBeArrayOfSize(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toBeArrayOfSize() requires 1 argument")
    }

    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeArrayOfSize", matcherParamsFmt: "")

    let size = arguments[0]
    size.ensureStillAlive()

    if !size.isAnyInt() {
        return globalThis.throw_("toBeArrayOfSize() requires the first argument to be a number")
    }

    this.incrementExpectCallCounter()

    let not = this.flags.not
    var pass = value.jsType().isArray() && Int32(value.getLength(globalThis: globalThis)) == size.toInt32()

    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let received = value.toFmt(formatter)

    if not {
        let signature = Expect.getSignature(matcherName: "toBeArrayOfSize", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
    }

    let signature = Expect.getSignature(matcherName: "toBeArrayOfSize", args: "", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nReceived: <red>{f}<r>\n", args: [received])
}
