// 严格翻译自: src/runtime/test_runner/expect/toSatisfy.zig

package bao_runtime

/// toSatisfy() - 检查值是否满足自定义谓词
/// 用法: expect(received).toSatisfy(predicate)
public func toSatisfy(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toSatisfy() requires 1 argument")
    }

    this.incrementExpectCallCounter()

    let predicate = arguments[0]
    predicate.ensureStillAlive()

    if !predicate.isCallable() {
        return globalThis.throw_("toSatisfy() argument must be a function")
    }

    let value = Expect.js.capturedValueGetCached(thisValue) ?? {
        return globalThis.throw_("Internal consistency error: the expect(value) was garbage collected but it should not have been!")
    }()
    value.ensureStillAlive()

    let result = predicate.callWithCatch(globalThis: globalThis, thisValue: JSValue.jsUndefined, args: [value])
    if (let e = result.exception) {
        let fmt = ZigString.init("toSatisfy() predicate threw an exception")
        return globalThis.throwValue(globalThis.createAggregateError(errors: [e], message: fmt))
    }

    let not = this.flags.not
    let pass = (result.value.isBoolean() && result.value.toBoolean()) != not

    if pass { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }

    if not {
        let signature = Expect.getSignature(matcherName: "toSatisfy", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected: not <green>{f}<r>\n", args: [predicate.toFmt(formatter)])
    }

    let signature = Expect.getSignature(matcherName: "toSatisfy", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected: <green>{f}<r>\nReceived: <red>{f}<r>\n",
        args: [predicate.toFmt(formatter), value.toFmt(formatter)])
}
