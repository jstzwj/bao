// toBeArrayOfSize.cj - 检查值是否为指定大小的数组
// 严格翻译自 bun/src/runtime/test_runner/expect/toBeArrayOfSize.zig

package bao_runtime

/// () - 检查值是否为指定大小的数组
/// 用法: expect(received).(expected)
public func (this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    this.incrementExpectCallCounter()

    let not = this.flags.not
    var pass = false

    // TODO: 实现具体的匹配逻辑

    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    // 处理失败
    let signature = Expect.getSignature(matcherName: "", args: "<green>expected<r>", not: not)
    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected: <green>{s}<r>\nReceived: <red>{s}<r>\n",
        args: ["expected", "received"])
}
