// 严格翻译自: src/runtime/test_runner/expect/toHaveProperty.zig

package bao_runtime.test_runner.expect

/// toHaveProperty() - 检查对象是否具有指定属性
/// 用法: expect(obj).toHaveProperty(path) / expect(obj).toHaveProperty(path, value)
public func toHaveProperty(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(2)
    let arguments = arguments_.slice()

    if arguments.length < 1 {
        return globalThis.throwInvalidArguments("toHaveProperty() requires at least 1 argument")
    }

    this.incrementExpectCallCounter()

    let expectedPropertyPath = arguments[0]
    expectedPropertyPath.ensureStillAlive()
    let expectedProperty: ?JSValue = if arguments.length > 1 { arguments[1] } else { None }
    if (let ev = expectedProperty) { ev.ensureStillAlive() }

    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toHaveProperty", matcherParamsFmt: "<green>path<r><d>, <r><green>value<r>")

    if !expectedPropertyPath.isString() && !expectedPropertyPath.isIterable(globalThis: globalThis) {
        return globalThis.throw_("Expected path must be a string or an array")
    }

    let not = this.flags.not

    var pass = !value.isUndefinedOrNull()
    var receivedProperty: JSValue = JSValue.zero

    if pass {
        receivedProperty = value.getIfPropertyExistsFromPath(globalThis: globalThis, path: expectedPropertyPath)
        pass = receivedProperty != JSValue.zero
    }

    if pass && expectedProperty != None {
        pass = receivedProperty.jestDeepEquals(expectedProperty!, globalThis: globalThis)
    }

    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    // 处理失败
    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    if not {
        if expectedProperty != None {
            let signature = Expect.getSignature(matcherName: "toHaveProperty", args: "<green>path<r><d>, <r><green>value<r>", not: true)
            if receivedProperty != JSValue.zero {
                return this.throw_(globalThis: globalThis, signature: signature,
                    fmt: "\n\nExpected path: <green>{f}<r>\n\nExpected value: not <green>{f}<r>\n",
                    args: [expectedPropertyPath.toFmt(formatter), expectedProperty!.toFmt(formatter)])
            }
        }

        let signature = Expect.getSignature(matcherName: "toHaveProperty", args: "<green>path<r>", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\nExpected path: not <green>{f}<r>\n\nReceived value: <red>{f}<r>\n",
            args: [expectedPropertyPath.toFmt(formatter), receivedProperty.toFmt(formatter)])
    }

    if expectedProperty != None {
        let signature = Expect.getSignature(matcherName: "toHaveProperty", args: "<green>path<r><d>, <r><green>value<r>", not: false)
        if receivedProperty != JSValue.zero {
            // deep equal case
            let diffFormat = DiffFormatter(received: receivedProperty, expected: expectedProperty!, globalThis: globalThis)
            return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n{f}\n", args: [diffFormat])
        }

        let fmt = "\n\nExpected path: <green>{f}<r>\n\nExpected value: <green>{f}<r>\n\n" +
            "Unable to find property\n"
        return this.throw_(globalThis: globalThis, signature: signature, fmt: fmt,
            args: [expectedPropertyPath.toFmt(formatter), expectedProperty!.toFmt(formatter)])
    }

    let signature = Expect.getSignature(matcherName: "toHaveProperty", args: "<green>path<r>", not: false)
    return this.throw_(globalThis: globalThis, signature: signature,
        fmt: "\n\nExpected path: <green>{f}<r>\n\nUnable to find property\n",
        args: [expectedPropertyPath.toFmt(formatter)])
}
