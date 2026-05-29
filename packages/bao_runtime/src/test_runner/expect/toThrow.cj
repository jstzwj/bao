// 严格翻译自: src/runtime/test_runner/expect/toThrow.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// toThrow() - 检查函数是否抛出异常
/// 用法: expect(fn).toThrow() / expect(fn).toThrow("message") / expect(fn).toThrow(ErrorClass)
public func toThrow(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments = callFrame.argumentsAsArray(1)

    `this`.incrementExpectCallCounter()

    let global = globalThis.globalThis

    // 解析 expected_value
    var expectedValue: JsValue = JsValue.zero
    let value = arguments[0]
    if (value.isUndefined()) {
        expectedValue = JsValue.zero
    } else if (value.isUndefinedOrNull() || (!value.isObject() && !value.isString())) {
        let formatter = ConsoleFormatter()
        expectedValue = globalThis.throw_("Expected value must be string or Error: {f}", args: [value.toFmt(formatter)])
    } else if (value.isObject()) {
        // Check for asymmetric matcher (expect.any)
        let anyMatcher = ExpectAny.fromJS(value)
        if (anyMatcher.isSome()) {
            // Simplified: use the value directly as expected
            expectedValue = value
        }
    } else if (value.isString()) {
        // `.toThrow("") behaves the same as `.toThrow()`
        let s = value.toString()
        if (s.size == 0) {
            expectedValue = JsValue.zero
        } else {
            expectedValue = value
        }
    } else {
        expectedValue = value
    }
    expectedValue.ensureStillAlive()

    let not = `this`.flags.not

    let throwResult = `this`.getValueAsToThrow(globalThis: globalThis, value: `this`.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toThrow", matcherParamsFmt: "<green>expected<r>"))
    let result_ = throwResult.first
    let returnValueFromFunction = throwResult.second

    let didThrow = result_.isSome()

    // ========== not 分支 ==========
    if (not) {
        let signature = Expect.getSignature("toThrow", "<green>expected<r>", true)

        if (!didThrow) {
            return JsValue.jsUndefined()
        }

        let result = result_.getOrThrow()
        let formatter = ConsoleFormatter()

        // expected 为空或 undefined
        if (expectedValue == JsValue.zero || expectedValue.isUndefined()) {
            let signatureNoArgs = Expect.getSignature("toThrow", "", true)
            let errOpt = result.toError()
            if (errOpt.isSome()) {
                let err = errOpt.getOrThrow()
                let name: JsValue = err.getTruthyComptime(globalThis: globalThis, key: "name") ?? JsValue.jsUndefined()
                let message: JsValue = err.getTruthyComptime(globalThis: globalThis, key: "message") ?? JsValue.jsUndefined()
                let fmt = signatureNoArgs + "\n\nError name: <red>{f}<r>\nError message: <red>{f}<r>\n"
                return `this`.throw_(globalThis: globalThis, signature: signatureNoArgs, fmt: fmt, args: [name.toFmt(formatter), message.toFmt(formatter)])
            }
            // non error thrown
            let fmt = signatureNoArgs + "\n\nThrown value: <red>{f}<r>\n"
            return `this`.throw_(globalThis: globalThis, signature: signatureNoArgs, fmt: fmt, args: [result.toFmt(formatter)])
        }

        // expected 是字符串 (部分匹配)
        if (expectedValue.isString()) {
            var receivedMessage: JsValue = JsValue.jsUndefined()
            if (result.isObject()) {
                let tmpMsg = result.get(global, "message")
                if (tmpMsg.isSome()) {
                    receivedMessage = tmpMsg.getOrThrow()
                }
            } else {
                receivedMessage = JsValue.jsString(result.toString())
            }
            if (globalThis.hasException()) { return JsValue.zero }

            // partial match
            let expectedSlice = expectedValue.toSliceOrNull(global)
            let receivedSlice = receivedMessage.toSliceOrNull(global)
            if (receivedSlice.isSome() && expectedSlice.isSome() && !receivedSlice.getOrThrow().contains(expectedSlice.getOrThrow())) {
                return JsValue.jsUndefined()
            }

            return `this`.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected substring: not <green>{f}<r>\nReceived message: <red>{f}<r>\n",
                args: [expectedValue.toFmt(formatter), receivedMessage.toFmt(formatter)])
        }

        // expected 是正则表达式
        if (expectedValue.isRegExp()) {
            var receivedMessage: JsValue = JsValue.jsUndefined()
            if (result.isObject()) {
                let tmpMsg = result.get(global, "message")
                if (tmpMsg.isSome()) {
                    receivedMessage = tmpMsg.getOrThrow()
                }
            } else {
                receivedMessage = JsValue.jsString(result.toString())
            }
            if (globalThis.hasException()) { return JsValue.zero }

            let testFnOpt = expectedValue.get(global, "test")
            if (testFnOpt.isSome()) {
                let testFn = testFnOpt.getOrThrow()
                let matches = testFn.call(global, expectedValue, [receivedMessage])
                if (!matches.toBoolean()) {
                    return JsValue.jsUndefined()
                }
            }

            return `this`.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected pattern: not <green>{f}<r>\nReceived message: <red>{f}<r>\n",
                args: [expectedValue.toFmt(formatter), receivedMessage.toFmt(formatter)])
        }

        // expected 含有 message 属性 (完全匹配)
        let expectedMessageOpt = expectedValue.get(global, "message")
        if (expectedMessageOpt.isSome()) {
            let expectedMessage = expectedMessageOpt.getOrThrow()
            var receivedMessage: JsValue = JsValue.jsUndefined()
            if (result.isObject()) {
                let tmpMsg = result.get(global, "message")
                if (tmpMsg.isSome()) {
                    receivedMessage = tmpMsg.getOrThrow()
                }
            } else {
                receivedMessage = JsValue.jsString(result.toString())
            }
            if (globalThis.hasException()) { return JsValue.zero }

            // no partial match for this case
            if (!expectedMessage.isSameValue(receivedMessage, global)) {
                return JsValue.jsUndefined()
            }

            return `this`.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected message: not <green>{f}<r>\n",
                args: [expectedMessage.toFmt(formatter)])
        }

        // 检查 instanceof
        if (!result.isInstanceOf(global, expectedValue)) {
            return JsValue.jsUndefined()
        }

        var receivedMessage: JsValue = JsValue.jsUndefined()
        let tmpMsg2 = result.get(global, "message")
        if (tmpMsg2.isSome()) {
            receivedMessage = tmpMsg2.getOrThrow()
        }
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected constructor: not <green>{f}<r>\n\nReceived message: <red>{f}<r>\n",
            args: [expectedValue.toFmt(formatter), receivedMessage.toFmt(formatter)])
    }

    // ========== 正向分支: didThrow ==========
    if (didThrow) {
        if (expectedValue == JsValue.zero || expectedValue.isUndefined()) {
            return JsValue.jsUndefined()
        }

        let rawResult = result_.getOrThrow()
        let errOpt2 = rawResult.toError()
        let result = if (errOpt2.isSome()) { errOpt2.getOrThrow() } else { rawResult }

        var receivedMessage: ?JsValue = None
        if (result.isObject()) {
            receivedMessage = result.get(global, "message")
        } else {
            receivedMessage = JsValue.jsString(result.toString())
        }

        // expected 是字符串
        if (expectedValue.isString()) {
            if (receivedMessage.isSome()) {
                let recvMsg = receivedMessage.getOrThrow()
                // partial match
                let expectedSlice = expectedValue.toSliceOrNull(global)
                let receivedSlice = recvMsg.toSliceOrNull(global)
                if (receivedSlice.isSome() && expectedSlice.isSome() && receivedSlice.getOrThrow().contains(expectedSlice.getOrThrow())) {
                    return JsValue.jsUndefined()
                }
            }

            let formatter = ConsoleFormatter()
            let signature = Expect.getSignature("toThrow", "<green>expected<r>", false)

            if (receivedMessage.isSome()) {
                return `this`.throw_(globalThis: globalThis, signature: signature,
                    fmt: "\n\nExpected substring: <green>{f}<r>\nReceived message: <red>{f}<r>\n",
                    args: [expectedValue.toFmt(formatter), receivedMessage.getOrThrow().toFmt(formatter)])
            }

            return `this`.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected substring: <green>{f}<r>\nReceived value: <red>{f}<r>",
                args: [expectedValue.toFmt(formatter), result.toFmt(formatter)])
        }

        // expected 是正则表达式
        if (expectedValue.isRegExp()) {
            if (receivedMessage.isSome()) {
                let recvMsg = receivedMessage.getOrThrow()
                let testFnOpt = expectedValue.get(global, "test")
                if (testFnOpt.isSome()) {
                    let testFn = testFnOpt.getOrThrow()
                    let matches = testFn.call(global, expectedValue, [recvMsg])
                    if (matches.toBoolean()) {
                        return JsValue.jsUndefined()
                    }
                }
            }

            let formatter = ConsoleFormatter()

            if (receivedMessage.isSome()) {
                let signature = Expect.getSignature("toThrow", "<green>expected<r>", false)
                return `this`.throw_(globalThis: globalThis, signature: signature,
                    fmt: "\n\nExpected pattern: <green>{f}<r>\nReceived message: <red>{f}<r>\n",
                    args: [expectedValue.toFmt(formatter), receivedMessage.getOrThrow().toFmt(formatter)])
            }

            let signature = Expect.getSignature("toThrow", "<green>expected<r>", false)
            return `this`.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected pattern: <green>{f}<r>\nReceived value: <red>{f}<r>",
                args: [expectedValue.toFmt(formatter), result.toFmt(formatter)])
        }

        // 非对称匹配器
        if (Expect.isAsymmetricMatcher(expectedValue)) {
            let signature = Expect.getSignature("toThrow", "<green>expected<r>", false)
            let isEqual = result.jestDeepEquals(expectedValue, globalThis: globalThis)

            if (globalThis.hasException()) {
                return JsValue.zero
            }

            if (isEqual) {
                return JsValue.jsUndefined()
            }

            let formatter = ConsoleFormatter()
            return `this`.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected value: <green>{f}<r>\nReceived value: <red>{f}<r>\n",
                args: [expectedValue.toFmt(formatter), result.toFmt(formatter)])
        }

        // expected 含有 message 属性
        let expectedMsgOpt = expectedValue.get(global, "message")
        if (expectedMsgOpt.isSome()) {
            let expectedMessage = expectedMsgOpt.getOrThrow()
            let signature = Expect.getSignature("toThrow", "<green>expected<r>", false)

            if (receivedMessage.isSome()) {
                let recvMsg = receivedMessage.getOrThrow()
                if (recvMsg.isSameValue(expectedMessage, global)) {
                    return JsValue.jsUndefined()
                }
            }

            let formatter = ConsoleFormatter()

            if (receivedMessage.isSome()) {
                return `this`.throw_(globalThis: globalThis, signature: signature,
                    fmt: "\n\nExpected message: <green>{f}<r>\nReceived message: <red>{f}<r>\n",
                    args: [expectedMessage.toFmt(formatter), receivedMessage.getOrThrow().toFmt(formatter)])
            }

            return `this`.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected message: <green>{f}<r>\nReceived value: <red>{f}<r>\n",
                args: [expectedMessage.toFmt(formatter), result.toFmt(formatter)])
        }

        // instanceof 检查
        if (result.isInstanceOf(global, expectedValue)) {
            return JsValue.jsUndefined()
        }

        // 构造函数不匹配
        let formatter = ConsoleFormatter()
        let signature = Expect.getSignature("toThrow", "<green>expected<r>", false)

        if (receivedMessage.isSome()) {
            return `this`.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected constructor: <green>{f}<r>\nReceived constructor: <red>{f}<r>\n\nReceived message: <red>{f}<r>\n",
                args: [expectedValue.toFmt(formatter), result.toFmt(formatter), receivedMessage.getOrThrow().toFmt(formatter)])
        }

        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected constructor: <green>{f}<r>\nReceived constructor: <red>{f}<r>\n\nReceived value: <red>{f}<r>\n",
            args: [expectedValue.toFmt(formatter), result.toFmt(formatter)])
    }

    // ========== 未抛出异常 ==========
    let result = returnValueFromFunction
    let formatter = ConsoleFormatter()
    let receivedLine = "Received function did not throw\nReceived value: <red>{f}<r>\n"

    if (expectedValue == JsValue.zero || expectedValue.isUndefined()) {
        let signature = Expect.getSignature("toThrow", "", false)
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n" + receivedLine,
            args: [result.toFmt(formatter)])
    }

    let signature = Expect.getSignature("toThrow", "<green>expected<r>", false)

    if (expectedValue.isString()) {
        let expectedFmt = "\n\nExpected substring: <green>{f}<r>\n\n" + receivedLine
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: expectedFmt,
            args: [expectedValue.toFmt(formatter), result.toFmt(formatter)])
    }

    if (expectedValue.isRegExp()) {
        let expectedFmt = "\n\nExpected pattern: <green>{f}<r>\n\n" + receivedLine
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: expectedFmt,
            args: [expectedValue.toFmt(formatter), result.toFmt(formatter)])
    }

    let expectedMsgOpt2 = expectedValue.get(global, "message")
    if (expectedMsgOpt2.isSome()) {
        let expectedFmt = "\n\nExpected message: <green>{f}<r>\n\n" + receivedLine
        return `this`.throw_(globalThis: globalThis, signature: signature,
            fmt: expectedFmt,
            args: [expectedMsgOpt2.getOrThrow().toFmt(formatter), result.toFmt(formatter)])
    }

    let expectedFmt = "\n\nExpected constructor: <green>{f}<r>\n\n" + receivedLine
    return `this`.throw_(globalThis: globalThis, signature: signature,
        fmt: expectedFmt,
        args: [expectedValue.toFmt(formatter), result.toFmt(formatter)])
}
