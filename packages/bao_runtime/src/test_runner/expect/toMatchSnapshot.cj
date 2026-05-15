// 严格翻译自: src/runtime/test_runner/expect/toMatchSnapshot.zig

package bao_runtime

/// toMatchSnapshot() - 快照匹配
/// 用法: expect(received).toMatchSnapshot() / expect(received).toMatchSnapshot(hint) / expect(received).toMatchSnapshot(properties, hint)
public func toMatchSnapshot(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(2)
    let arguments = arguments_.slice()

    this.incrementExpectCallCounter()

    let not = this.flags.not
    if not {
        let signature = Expect.getSignature(matcherName: "toMatchSnapshot", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Snapshot matchers cannot be used with <b>not<r>\n", args: [])
    }

    var buntestStrong = this.bunTest() ?? {
        let signature = Expect.getSignature(matcherName: "toMatchSnapshot", args: "", not: true)
        return this.throw_(globalThis: globalThis, signature: signature,
            fmt: "\n\n<b>Matcher error<r>: Snapshot matchers cannot be used outside of a test\n", args: [])
    }()
    defer { buntestStrong.deinit() }

    var hintString = ZigString.Empty
    var propertyMatchers: ?JSValue = None
    if arguments.length == 0 {
        // 无参数
    } else if arguments.length == 1 {
        if arguments[0].isString() {
            arguments[0].toZigString(result: &hintString, globalThis: globalThis)
        } else if arguments[0].isObject() {
            propertyMatchers = arguments[0]
        } else {
            return this.throw_(globalThis: globalThis, signature: "",
                fmt: "\n\nMatcher error: Expected first argument to be a string or object\n", args: [])
        }
    } else {
        if !arguments[0].isObject() {
            let signature = Expect.getSignature(matcherName: "toMatchSnapshot", args: "<green>properties<r><d>, <r>hint", not: false)
            return this.throw_(globalThis: globalThis, signature: signature,
                fmt: "\n\nMatcher error: Expected <green>properties<r> must be an object\n", args: [])
        }

        propertyMatchers = arguments[0]

        if arguments[1].isString() {
            arguments[1].toZigString(result: &hintString, globalThis: globalThis)
        } else {
            return this.throw_(globalThis: globalThis, signature: "",
                fmt: "\n\nMatcher error: Expected second argument to be a string\n", args: [])
        }
    }

    var hint = hintString.toSlice(allocator: default_allocator)
    defer { hint.deinit() }

    let value: JSValue = this.getValue(globalThis: globalThis, thisValue: thisValue, matcherName: "toMatchSnapshot", matcherParamsFmt: "<green>properties<r><d>, <r>hint")

    return this.snapshot(globalThis: globalThis, value: value, propertyMatchers: propertyMatchers, hint: hint.slice(), matcherName: "toMatchSnapshot")
}
