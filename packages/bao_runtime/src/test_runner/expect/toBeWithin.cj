// 严格翻译自: src/runtime/test_runner/expect/toBeWithin.zig

package bao_runtime

/// toBeWithin() - 检查值是否在指定范围内 [start, end)
/// 用法: expect(received).toBeWithin(start, end)
public func toBeWithin(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(2)
    let arguments = arguments_.slice()

    if arguments.length < 2 {
        return globalThis.throwInvalidArguments("toBeWithin() requires 2 arguments")
    }

    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toBeWithin", matcherParamsFmt: "<green>start<r><d>, <r><green>end<r>")

    let startValue = arguments[0]
    startValue.ensureStillAlive()
    if !startValue.isNumber() {
        return globalThis.throw_("toBeWithin() requires the first argument to be a number")
    }

    let endValue = arguments[1]
    endValue.ensureStillAlive()
    if !endValue.isNumber() {
        return globalThis.throw_("toBeWithin() requires the second argument to be a number")
    }

    this.incrementExpectCallCounter()

    var pass = value.isNumber()
    if pass {
        let num = value.asNumber()
        pass = num >= startValue.asNumber() && num < endValue.asNumber()
    }

    let not = this.flags.not
    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let startFmt = startValue.toFmt(formatter)
    let endFmt = endValue.toFmt(formatter)
    let receivedFmt = value.toFmt(formatter)

    if not {
        let expectedLine = "Expected: not between <green>{f}<r> <d>(inclusive)<r> and <green>{f}<r> <d>(exclusive)<r>\n"
        let receivedLine = "Received: <red>{f}<r>\n"
        let signature = Expect.getSignature(matcherName: "toBeWithin", args: "<green>start<r><d>, <r><green>end<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [startFmt, endFmt, receivedFmt])
    }

    let expectedLine = "Expected: between <green>{f}<r> <d>(inclusive)<r> and <green>{f}<r> <d>(exclusive)<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    let signature = Expect.getSignature(matcherName: "toBeWithin", args: "<green>start<r><d>, <r><green>end<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [startFmt, endFmt, receivedFmt])
}
