// 严格翻译自: src/runtime/test_runner/expect/toThrow.zig

package bao_runtime

/// toThrow() - 检查函数是否抛出异常
/// 用法: expect(fn).toThrow() / expect(fn).toThrow("message") / expect(fn).toThrow(ErrorClass)
public func toThrow(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments = callFrame.argumentsAsArray(1)

    this.incrementExpectCallCounter()

    // 解析 expected_value
    let expectedValue: JSValue = {
        let value = arguments[0]
        if value.isUndefined() {
            return JSValue.zero
        }
        if (value.isUndefinedOrNull() || (!value.isObject() && !value.isString())) {
            let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
            defer { formatter.deinit() }
            return globalThis.throw_("Expected value must be string or Error: {f}", args: [value.toFmt(formatter)])
        }
        if value.isObject() {
            if (ExpectAny.fromJSDirect(value)) {
                if (let innerConstructor = ExpectAny.js.constructorValueGetCached(value)) {
                    return innerConstructor
                }
            }
        } else if value.isString() {
            // `.toThrow("") behaves the same as `.toThrow()`
            let s = value.toJSString(globalThis)
            if s.length() == 0 {
                return JSValue.zero
            }
        }
        return value
    }()
    expectedValue.ensureStillAlive()

    let not = this.flags.not

    let (result_, returnValueFromFunction) = this.getValueAsToThrow(globalThis: globalThis, value: this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toThrow", matcherParamsFmt: "<green>expected<r>"))

    let didThrow = result_ != JSValue.zero

    // ========== not 分支 ==========
    if not {
        let signature = Expect.getSignature(matcherName: "toThrow", args: "<green>expected<r>", not: true)

        if !didThrow {
            return JSValue.jsUndefined
        }

        let result = result_
        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        defer { formatter.deinit() }

        // expected 为空或 undefined
        if (expectedValue == JSValue.zero || expectedValue.isUndefined()) {
            let signatureNoArgs = Expect.getSignature(matcherName: "toThrow", args: "", not: true)
            if (let err = result.toError()) {
                let name: JSValue = err.getTruthyComptime(globalThis: globalThis, key: "name") ?? JSValue.jsUndefined
                let message: JSValue = err.getTruthyComptime(globalThis: globalThis, key: "message") ?? JSValue.jsUndefined
                let fmt = signatureNoArgs + "\n\nError name: <red>{f}<r>\nError message: <red>{f}<r>\n"
                return globalThis.throwPretty(fmt, args: [name.toFmt(formatter), message.toFmt(formatter)])
            }
            // non error thrown
            let fmt = signatureNoArgs + "\n\nThrown value: <red>{f}<r>\n"
            return globalThis.throwPretty(fmt, args: [result.toFmt(formatter)])
        }

        // expected 是字符串 (部分匹配)
        if expectedValue.isString() {
            let receivedMessage: JSValue = {
                if result.isObject() {
                    return result.fastGet(globalThis: globalThis, property: .message) ?? JSValue.jsUndefined
                }
                return JSValue.fromCell(result.toJSString(globalThis))
            }()
            if globalThis.hasException() { return JSValue.zero }

            // partial match
            let expectedSlice = expectedValue.toSliceOrNull(globalThis: globalThis)
            defer { expectedSlice.deinit() }
            let receivedSlice = receivedMessage.toSliceOrNull(globalThis: globalThis)
            defer { receivedSlice.deinit() }
            if !strings.contains(receivedSlice.slice(), expectedSlice.slice()) {
                return JSValue.jsUndefined
            }

            return this.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected substring: not <green>{f}<r>\nReceived message: <red>{f}<r>\n",
                args: [expectedValue.toFmt(formatter), receivedMessage.toFmt(formatter)])
        }

        // expected 是正则表达式
        if expectedValue.isRegExp() {
            let receivedMessage: JSValue = {
                if result.isObject() {
                    return result.fastGet(globalThis: globalThis, property: .message) ?? JSValue.jsUndefined
                }
                return JSValue.fromCell(result.toJSString(globalThis))
            }()
            if globalThis.hasException() { return JSValue.zero }

            if (let testFn = expectedValue.get(globalThis: globalThis, key: "test")) {
                let matches = testFn.call(globalThis: globalThis, thisValue: expectedValue, args: [receivedMessage])
                if !matches.toBoolean() {
                    return JSValue.jsUndefined
                }
            }

            return this.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected pattern: not <green>{f}<r>\nReceived message: <red>{f}<r>\n",
                args: [expectedValue.toFmt(formatter), receivedMessage.toFmt(formatter)])
        }

        // expected 含有 message 属性 (完全匹配)
        if (let expectedMessage = expectedValue.fastGet(globalThis: globalThis, property: .message)) {
            let receivedMessage: JSValue = {
                if result.isObject() {
                    return result.fastGet(globalThis: globalThis, property: .message) ?? JSValue.jsUndefined
                }
                return JSValue.fromCell(result.toJSString(globalThis))
            }()
            if globalThis.hasException() { return JSValue.zero }

            // no partial match for this case
            if !expectedMessage.isSameValue(receivedMessage, globalThis: globalThis) {
                return JSValue.jsUndefined
            }

            return this.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected message: not <green>{f}<r>\n",
                args: [expectedMessage.toFmt(formatter)])
        }

        // 检查 instanceof
        if !result.isInstanceOf(globalThis: globalThis, expected: expectedValue) {
            return JSValue.jsUndefined
        }

        var expectedClass = ZigString.Empty
        expectedValue.getClassName(globalThis: globalThis, result: &expectedClass)
        let receivedMessage: JSValue = result.fastGet(globalThis: globalThis, property: .message) ?? JSValue.jsUndefined
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected constructor: not <green>{f}<r>\n\nReceived message: <red>{f}<r>\n",
            args: [expectedClass, receivedMessage.toFmt(formatter)])
    }

    // ========== 正向分支: didThrow ==========
    if didThrow {
        if (expectedValue == JSValue.zero || expectedValue.isUndefined()) {
            return JSValue.jsUndefined
        }

        let result = {
            if (let r = result_.toError()) {
                return r
            }
            return result_
        }()

        let receivedMessage: ?JSValue = {
            if result.isObject() {
                return result.fastGet(globalThis: globalThis, property: .message)
            }
            return JSValue.fromCell(result.toJSString(globalThis))
        }()

        // expected 是字符串
        if expectedValue.isString() {
            if (let recvMsg = receivedMessage) {
                // partial match
                let expectedSlice = expectedValue.toSliceOrNull(globalThis: globalThis)
                defer { expectedSlice.deinit() }
                let receivedSlice = recvMsg.toSlice(globalThis: globalThis, allocator: globalThis.allocator())
                defer { receivedSlice.deinit() }
                if strings.contains(receivedSlice.slice(), expectedSlice.slice()) {
                    return JSValue.jsUndefined
                }
            }

            let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
            defer { formatter.deinit() }

            let signature = Expect.getSignature(matcherName: "toThrow", args: "<green>expected<r>", not: false)

            if (let recvMsg = receivedMessage) {
                return this.throw_(globalThis: globalThis, signature: signature,
                    fmt: "\n\nExpected substring: <green>{f}<r>\nReceived message: <red>{f}<r>\n",
                    args: [expectedValue.toFmt(formatter), recvMsg.toFmt(formatter)])
            }

            return this.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected substring: <green>{f}<r>\nReceived value: <red>{f}<r>",
                args: [expectedValue.toFmt(formatter), result.toFmt(formatter)])
        }

        // expected 是正则表达式
        if expectedValue.isRegExp() {
            if (let recvMsg = receivedMessage) {
                if (let testFn = expectedValue.get(globalThis: globalThis, key: "test")) {
                    let matches = testFn.call(globalThis: globalThis, thisValue: expectedValue, args: [recvMsg])
                    if matches.toBoolean() {
                        return JSValue.jsUndefined
                    }
                }
            }

            let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
            defer { formatter.deinit() }

            if (let recvMsg = receivedMessage) {
                let signature = Expect.getSignature(matcherName: "toThrow", args: "<green>expected<r>", not: false)
                return this.throw_(globalThis: globalThis, signature: signature,
                    fmt: "\n\nExpected pattern: <green>{f}<r>\nReceived message: <red>{f}<r>\n",
                    args: [expectedValue.toFmt(formatter), recvMsg.toFmt(formatter)])
            }

            let signature = Expect.getSignature(matcherName: "toThrow", args: "<green>expected<r>", not: false)
            return this.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected pattern: <green>{f}<r>\nReceived value: <red>{f}<r>",
                args: [expectedValue.toFmt(formatter), result.toFmt(formatter)])
        }

        // 非对称匹配器
        if Expect.isAsymmetricMatcher(expectedValue) {
            let signature = Expect.getSignature(matcherName: "toThrow", args: "<green>expected<r>", not: false)
            let isEqual = result.jestStrictDeepEquals(expectedValue, globalThis: globalThis)

            if globalThis.hasException() {
                return JSValue.zero
            }

            if isEqual {
                return JSValue.jsUndefined
            }

            let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
            defer { formatter.deinit() }
            return this.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected value: <green>{f}<r>\nReceived value: <red>{f}<r>\n",
                args: [expectedValue.toFmt(formatter), result.toFmt(formatter)])
        }

        // expected 含有 message 属性
        if (let expectedMessage = expectedValue.fastGet(globalThis: globalThis, property: .message)) {
            let signature = Expect.getSignature(matcherName: "toThrow", args: "<green>expected<r>", not: false)

            if (let recvMsg = receivedMessage) {
                if recvMsg.isSameValue(expectedMessage, globalThis: globalThis) {
                    return JSValue.jsUndefined
                }
            }

            let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
            defer { formatter.deinit() }

            if (let recvMsg = receivedMessage) {
                return this.throw_(globalThis: globalThis, signature: signature,
                    fmt: "\n\nExpected message: <green>{f}<r>\nReceived message: <red>{f}<r>\n",
                    args: [expectedMessage.toFmt(formatter), recvMsg.toFmt(formatter)])
            }

            return this.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nExpected message: <green>{f}<r>\nReceived value: <red>{f}<r>\n",
                args: [expectedMessage.toFmt(formatter), result.toFmt(formatter)])
        }

        // instanceof 检查
        if result.isInstanceOf(globalThis: globalThis, expected: expectedValue) {
            return JSValue.jsUndefined
        }

        // 构造函数不匹配
        let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
        defer { formatter.deinit() }
        var expectedClass = ZigString.Empty
        var receivedClass = ZigString.Empty
        expectedValue.getClassName(globalThis: globalThis, result: &expectedClass)
        result.getClassName(globalThis: globalThis, result: &receivedClass)
        let signature = Expect.getSignature(matcherName: "toThrow", args: "<green>expected<r>", not: false)
        let fmt = signature + "\n\nExpected constructor: <green>{f}<r>\nReceived constructor: <red>{f}<r>\n\n"

        if (let recvMsg = receivedMessage) {
            let messageFmt = fmt + "Received message: <red>{f}<r>\n"
            return globalThis.throwPretty(messageFmt, args: [expectedClass, receivedClass, recvMsg.toFmt(formatter)])
        }

        let valueFmt = fmt + "Received value: <red>{f}<r>\n"
        return globalThis.throwPretty(valueFmt, args: [expectedClass, receivedClass, result.toFmt(formatter)])
    }

    // ========== 未抛出异常 ==========
    let result = returnValueFromFunction
    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let receivedLine = "Received function did not throw\nReceived value: <red>{f}<r>\n"

    if (expectedValue == JSValue.zero || expectedValue.isUndefined()) {
        let signature = Expect.getSignature(matcherName: "toThrow", args: "", not: false)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n" + receivedLine,
            args: [result.toFmt(formatter)])
    }

    let signature = Expect.getSignature(matcherName: "toThrow", args: "<green>expected<r>", not: false)

    if expectedValue.isString() {
        let expectedFmt = "\n\nExpected substring: <green>{f}<r>\n\n" + receivedLine
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: expectedFmt,
            args: [expectedValue.toFmt(formatter), result.toFmt(formatter)])
    }

    if expectedValue.isRegExp() {
        let expectedFmt = "\n\nExpected pattern: <green>{f}<r>\n\n" + receivedLine
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: expectedFmt,
            args: [expectedValue.toFmt(formatter), result.toFmt(formatter)])
    }

    if (let expectedMessage = expectedValue.fastGet(globalThis: globalThis, property: .message)) {
        let expectedFmt = "\n\nExpected message: <green>{f}<r>\n\n" + receivedLine
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: expectedFmt,
            args: [expectedMessage.toFmt(formatter), result.toFmt(formatter)])
    }

    let expectedFmt = "\n\nExpected constructor: <green>{f}<r>\n\n" + receivedLine
    var expectedClass = ZigString.Empty
    expectedValue.getClassName(globalThis: globalThis, result: &expectedClass)
    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: expectedFmt,
        args: [expectedClass, result.toFmt(formatter)])
}
