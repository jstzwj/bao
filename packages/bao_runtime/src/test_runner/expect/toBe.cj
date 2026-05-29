// toBe.cj - Object.is()严格相等断言
// 严格翻译自 bun/src/runtime/test_runner/expect/toBe.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toBe() - Object.is()严格相等比较
/// 用法: expect(received).toBe(expected)
public func toBe(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    `this`.incrementExpectCallCounter()

    let right = callFrame.argument(0)
    if (right.isUndefinedOrNull()) { return JsValue.jsUndefined() }

    let left = `this`.getValue(globalThis: globalThis, thisValue: callFrame.`this`(), matcherName: "toBe", matcherParamsFmt: "<green>expected<r>")

    let not = `this`.flags.not
    var pass = right.isSameValue(left, globalThis.globalThis)

    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    let formatter = ConsoleFormatter()

    // 处理失败 - 输出差异信息
    if (not) {
        let signature = Expect.getSignature("toBe", "<green>expected<r>", true)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\nExpected: not <green>{s}<r>\n", args: [right.toFmt(formatter)])
    }

    let signature = Expect.getSignature("toBe", "<green>expected<r>", false)

    // 检查是否deep equal相等
    if (left.deepEquals(right, globalThis.globalThis)) {
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nIf this test should pass, replace \"toBe\" with \"toEqual\" or \"toStrictEqual\"\n\nExpected: <green>{s}<r>\nReceived: serializes to the same string\n",
            args: [right.toFmt(formatter)])
    }

    // 字符串差异
    if (right.isString() && left.isString()) {
        let diffFormat = DiffFormatter(left, right, globalThis, not)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormat])
    }

    return `this`.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected: <green>{s}<r>\nReceived: <red>{s}<r>\n",
        args: [right.toFmt(formatter), left.toFmt(formatter)])
}
