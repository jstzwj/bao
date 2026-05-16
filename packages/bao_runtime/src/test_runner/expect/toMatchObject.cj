// 严格翻译自: src/runtime/test_runner/expect/toMatchObject.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner
import bao_jsc.*

/// toMatchObject() - 检查对象是否深度匹配
/// 用法: expect(received).toMatchObject(expected)
public func toMatchObject(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let args = callFrame.argumentsOld(1).slice()

    this.incrementExpectCallCounter()

    let not = this.flags.not

    let receivedObject: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toMatchObject", matcherParamsFmt: "<green>expected<r>")

    if (!receivedObject.isObject()) {
        let matcherError = "\n\n<b>Matcher error<r>: <red>received<r> value must be a non-null object\n"
        if (not) {
            let signature = Expect.getSignature(matcherName: "toMatchObject", args: "<green>expected<r>", not: true)
            return this.throw_(globalThis: globalThis, signature: signature, fmt: matcherError, args: [])
        }

        let signature = Expect.getSignature(matcherName: "toMatchObject", args: "<green>expected<r>", not: false)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: matcherError, args: [])
    }

    if (args.length < 1 || !args[0].isObject()) {
        let matcherError = "\n\n<b>Matcher error<r>: <green>expected<r> value must be a non-null object\n"
        if (not) {
            let signature = Expect.getSignature(matcherName: "toMatchObject", args: "", not: true)
            return this.throw_(globalThis: globalThis, signature: signature, fmt: matcherError, args: [])
        }
        let signature = Expect.getSignature(matcherName: "toMatchObject", args: "", not: false)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: matcherError, args: [])
    }

    let propertyMatchers = args[0]

    var pass = receivedObject.jestDeepMatch(propertyMatchers, globalThis: globalThis, partial: true)

    if (not) { pass = !pass }
    if (pass) { return JSValue.jsUndefined }

    // 处理失败
    let diffFormatter = DiffFormatter(received: receivedObject, expected: propertyMatchers, globalThis: globalThis, not: not)

    if (not) {
        let signature = Expect.getSignature(matcherName: "toMatchObject", args: "<green>expected<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormatter])
    }

    let signature = Expect.getSignature(matcherName: "toMatchObject", args: "<green>expected<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormatter])
}
