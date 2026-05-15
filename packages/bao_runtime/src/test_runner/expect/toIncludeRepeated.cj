// 严格翻译自: src/runtime/test_runner/expect/toIncludeRepeated.zig

package bao_runtime

/// toIncludeRepeated() - 检查字符串是否包含期望子串指定次数
/// 用法: expect(received).toIncludeRepeated(substring, count)
public func toIncludeRepeated(this: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JSValue {
    defer { this.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.this_()
    let arguments_ = callFrame.argumentsOld(2)
    let arguments = arguments_.slice()

    if arguments.length < 2 {
        return globalThis.throwInvalidArguments("toIncludeRepeated() requires 2 arguments")
    }

    this.incrementExpectCallCounter()

    let substring = arguments[0]
    substring.ensureStillAlive()

    if !substring.isString() {
        return globalThis.throw_("toIncludeRepeated() requires the first argument to be a string")
    }

    let count = arguments[1]
    count.ensureStillAlive()

    if !count.isAnyInt() {
        return globalThis.throw_("toIncludeRepeated() requires the second argument to be a number")
    }

    let countAsNum = count.toU32()

    let expectString = Expect.js.capturedValueGetCached(thisValue) ?? {
        return globalThis.throw_("Internal consistency error: the expect(value) was garbage collected but it should not have been!")
    }()

    if !expectString.isString() {
        return globalThis.throw_("toIncludeRepeated() requires the expect(value) to be a string")
    }

    let not = this.flags.not
    var pass = false

    let expectStringAsStr = expectString.toSliceOrNull(globalThis: globalThis)
    defer { expectStringAsStr.deinit() }
    let subStringAsStr = substring.toSliceOrNull(globalThis: globalThis)
    defer { subStringAsStr.deinit() }

    if subStringAsStr.slice().length == 0 {
        return globalThis.throw_("toIncludeRepeated() requires the first argument to be a non-empty string")
    }

    let actualCount = std.mem.count<UInt8>(expectStringAsStr.slice(), subStringAsStr.slice())
    pass = actualCount == countAsNum

    if not { pass = !pass }
    if pass { return JSValue.jsUndefined }

    let formatter = ConsoleObject.Formatter(globalThis: globalThis, quote_strings: true)
    defer { formatter.deinit() }
    let expectStringFmt = expectString.toFmt(formatter)
    let substringFmt = substring.toFmt(formatter)
    let timesFmt = count.toFmt(formatter)

    let receivedLine = "Received: <red>{f}<r>\n"

    if not {
        if countAsNum == 0 {
            let expectedLine = "Expected to include: <green>{f}<r> \n"
            let signature = Expect.getSignature(matcherName: "toIncludeRepeated", args: "<green>expected<r>", not: true)
            return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [substringFmt, expectStringFmt])
        } else if countAsNum == 1 {
            let expectedLine = "Expected not to include: <green>{f}<r> \n"
            let signature = Expect.getSignature(matcherName: "toIncludeRepeated", args: "<green>expected<r>", not: true)
            return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [substringFmt, expectStringFmt])
        } else {
            let expectedLine = "Expected not to include: <green>{f}<r> <green>{f}<r> times \n"
            let signature = Expect.getSignature(matcherName: "toIncludeRepeated", args: "<green>expected<r>", not: true)
            return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [substringFmt, timesFmt, expectStringFmt])
        }
    }

    if countAsNum == 0 {
        let expectedLine = "Expected to not include: <green>{f}<r>\n"
        let signature = Expect.getSignature(matcherName: "toIncludeRepeated", args: "<green>expected<r>", not: false)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [substringFmt, expectStringFmt])
    } else if countAsNum == 1 {
        let expectedLine = "Expected to include: <green>{f}<r>\n"
        let signature = Expect.getSignature(matcherName: "toIncludeRepeated", args: "<green>expected<r>", not: false)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [substringFmt, expectStringFmt])
    } else {
        let expectedLine = "Expected to include: <green>{f}<r> <green>{f}<r> times \n"
        let signature = Expect.getSignature(matcherName: "toIncludeRepeated", args: "<green>expected<r>", not: false)
        return this.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [substringFmt, timesFmt, expectStringFmt])
    }
}
