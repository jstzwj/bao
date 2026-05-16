// 严格翻译自: src/runtime/test_runner/expect/toContainValue.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner
import bao_jsc.*

/// toContainValue() - 检查对象是否包含指定值
/// 用法: expect(received).toContainValue(expected)
public func toContainValue(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(1)
    let arguments = arguments_.slice()

    if (arguments.length < 1) {
        return globalThis.throwInvalidArguments("toContainValue() takes 1 argument")
    }

    this.incrementExpectCallCounter()

    let expected = arguments[0]
    expected.ensureStillAlive()
    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toContainValue", matcherParamsFmt: "<green>expected<r>")

    let not = this.flags.not
    var pass = false

    if (!value.isUndefinedOrNull()) {
        let values = value.values(globalThis: globalThis)
        var itr = values.arrayIterator(globalThis: globalThis)
        while (let Some(item) <- itr.next()) {
            if (item.jestDeepEquals(expected, globalThis: globalThis)) {
                pass = true
                break
            }
        }
    }

    if (not) { pass = !pass }
    if (pass) { return thisValue }

    // 处理失败
    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let valueFmt = value.toFmt(formatter)
    let expectedFmt = expected.toFmt(formatter)
    if (not) {
        let receivedFmt = value.toFmt(formatter)
        let expectedLine = "Expected to not contain: <green>{f}<r>\nReceived: <red>{f}<r>\n"
        return this.throw_(globalThis: globalThis, signature: Expect.getSignature(matcherName: "toContainValue", args: "<green>expected<r>", not: true),
            fmt: "\n\n" + expectedLine, args: [expectedFmt, receivedFmt])
    }

    let expectedLine = "Expected to contain: <green>{f}<r>\n"
    let receivedLine = "Received: <red>{f}<r>\n"
    return this.throw_(globalThis: globalThis, signature: Expect.getSignature(matcherName: "toContainValue", args: "<green>expected<r>", not: false),
        fmt: "\n\n" + expectedLine + receivedLine, args: [expectedFmt, valueFmt])
}
