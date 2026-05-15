// 严格翻译自: src/runtime/test_runner/expect/toEqual.zig

package bao_runtime.test_runner.expect

/// toEqual() - 深度相等比较
/// 用法: expect(received).toEqual(expected)
public func toEqual(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toEqual() requires 1 argument")
    }

    this.incrementExpectCallCounter()

    let expected = arguments[0]
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toEqual", matcherParamsFmt: "<green>expected<r>")

    let not = this.flags.not
    var pass = value.jestDeepEquals(expected, globalThis: globalThis)

    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    // 处理失败
    let diffFormatter = DiffFormatter(received: value, expected: expected, globalThis: globalThis, not: not)

    if not {
        let signature = Expect.getSignature(matcherName: "toEqual", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormatter])
    }

    let signature = Expect.getSignature(matcherName: "toEqual", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormatter])
}
