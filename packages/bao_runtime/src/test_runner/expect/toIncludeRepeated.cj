// 严格翻译自: src/runtime/test_runner/expect/toIncludeRepeated.zig

package bao_runtime.test_runner.expect

import bao_runtime.test_runner.*
import bao_jsc.*

/// 计算子串在字符串中出现的次数
private func countSubstring(haystack: String, needle: String): UInt32 {
    if (needle.size == 0) { return 0 }
    var count: UInt32 = 0
    var start = 0
    while (start <= haystack.size - needle.size) {
        if (haystack.indexOf(needle, start) == start) {
            count++
            start += needle.size
        } else {
            start++
        }
    }
    return count
}

/// toIncludeRepeated() - 检查字符串是否包含期望子串指定次数
/// 用法: expect(received).toIncludeRepeated(substring, count)
public func toIncludeRepeated(`this`: Expect, globalThis: JSGlobalObject, callFrame: CallFrame): JsValue {
    // defer { `this`.postMatch(globalThis: globalThis) }

    let thisValue = callFrame.`this`()
    let arguments_ = callFrame.argumentsOld(2)
    let arguments = arguments_.slice()

    if (arguments.size < 2) {
        return globalThis.throwInvalidArgumentsValue("toIncludeRepeated() requires 2 arguments")
    }

    `this`.incrementExpectCallCounter()

    let substring = arguments[0]
    substring.ensureStillAlive()

    if (!substring.isString()) {
        return globalThis.throw_("toIncludeRepeated() requires the first argument to be a string")
    }

    let count = arguments[1]
    count.ensureStillAlive()

    if (!count.isAnyInt()) {
        return globalThis.throw_("toIncludeRepeated() requires the second argument to be a number")
    }

    let countAsNum = count.toU32()

    let expectStringOpt = capturedValueGetCached(thisValue)
    if (expectStringOpt.isNone()) {
        return globalThis.throw_("Internal consistency error: the expect(value) was garbage collected but it should not have been!")
    }
    let expectString = expectStringOpt.getOrThrow()

    if (!expectString.isString()) {
        return globalThis.throw_("toIncludeRepeated() requires the expect(value) to be a string")
    }

    let not = `this`.flags.not
    var pass = false

    let global = globalThis.globalThis
    let expectStringAsStr = expectString.toSliceOrNull(global)
    let subStringAsStr = substring.toSliceOrNull(global)

    if (!subStringAsStr.isSome() || subStringAsStr.getOrThrow().size == 0) {
        return globalThis.throw_("toIncludeRepeated() requires the first argument to be a non-empty string")
    }

    let actualCount: UInt32 = if (expectStringAsStr.isSome()) {
        countSubstring(expectStringAsStr.getOrThrow(), subStringAsStr.getOrThrow())
    } else { UInt32(0) }
    pass = actualCount == countAsNum

    if (not) { pass = !pass }
    if (pass) { return JsValue.jsUndefined() }

    let formatter = ConsoleFormatter()
    // defer { formatter.deinit() }
    let expectStringFmt = expectString.toFmt(formatter)
    let substringFmt = substring.toFmt(formatter)
    let timesFmt = count.toFmt(formatter)

    let receivedLine = "Received: <red>{f}<r>\n"

    if (not) {
        if (countAsNum == 0) {
            let expectedLine = "Expected to include: <green>{f}<r> \n"
            let signature = Expect.getSignature("toIncludeRepeated", "<green>expected<r>", true)
            return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [substringFmt, expectStringFmt])
        } else if (countAsNum == 1) {
            let expectedLine = "Expected not to include: <green>{f}<r> \n"
            let signature = Expect.getSignature("toIncludeRepeated", "<green>expected<r>", true)
            return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [substringFmt, expectStringFmt])
        } else {
            let expectedLine = "Expected not to include: <green>{f}<r> <green>{f}<r> times \n"
            let signature = Expect.getSignature("toIncludeRepeated", "<green>expected<r>", true)
            return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [substringFmt, timesFmt, expectStringFmt])
        }
    }

    if (countAsNum == 0) {
        let expectedLine = "Expected to not include: <green>{f}<r>\n"
        let signature = Expect.getSignature("toIncludeRepeated", "<green>expected<r>", false)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [substringFmt, expectStringFmt])
    } else if (countAsNum == 1) {
        let expectedLine = "Expected to include: <green>{f}<r>\n"
        let signature = Expect.getSignature("toIncludeRepeated", "<green>expected<r>", false)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [substringFmt, expectStringFmt])
    } else {
        let expectedLine = "Expected to include: <green>{f}<r> <green>{f}<r> times \n"
        let signature = Expect.getSignature("toIncludeRepeated", "<green>expected<r>", false)
        return `this`.throw_(globalThis: globalThis, signature: signature, fmt: "\n\n" + expectedLine + receivedLine, args: [substringFmt, timesFmt, expectStringFmt])
    }
}
