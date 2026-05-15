// toStrictEqual.cj - 严格深度相等断言
// 严格翻译自 bun/src/runtime/test_runner/expect/toStrictEqual.zig

package bao_runtime

/// toStrictEqual() - 严格深度相等比较
/// 用法: expect(received).toStrictEqual(expected)
public func toStrictEqual(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    this.incrementExpectCallCounter()

    let expected = callFrame.argument(0) ?? return JSValue.zero
    let value = this.getValue(globalThis: globalThis, thisValue: callFrame.this_(), matcherName: "toStrictEqual", matcherParamsFmt: "<green>expected<r>")

    let not = this.flags.not
    var pass = value.jestStrictDeepEquals(expected, globalThis: globalThis)

    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    let diffFormatter = DiffFormatter(received: value, expected: expected, globalThis: globalThis, not: not)

    if not {
        let signature = Expect.getSignature(matcherName: "toStrictEqual", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormatter])
    }

    let signature = Expect.getSignature(matcherName: "toStrictEqual", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormatter])
}
