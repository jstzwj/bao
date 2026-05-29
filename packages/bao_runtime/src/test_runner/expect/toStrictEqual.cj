// 严格翻译自: src/runtime/test_runner/expect/toStrictEqual.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toStrictEqual() - 严格深度相等比较
/// 用法: expect(received).toStrictEqual(expected)
public func toStrictEqual(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.size < 1) {
        return globalThis.throwInvalidArgumentsValue("toStrictEqual() requires 1 argument")
    }

    `this`.incrementExpectCallCounter()

    let expected = arguments[0]
    let value: JsValue = `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toStrictEqual", matcherParamsFmt: "<green>expected<r>")

    let not = `this`.flags.not
    var pass = value.jestDeepEquals(expected, globalThis: globalThis)

    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    // 处理失败
    let diffFormatter = DiffFormatter(value, expected, globalThis, not)

    if (not) {
        let signature = Expect.getSignature("toStrictEqual", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormatter])
    }

    let signature = Expect.getSignature("toStrictEqual", "<green>expected<r>", false)
    return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormatter])
}
