// diff_format.cj - 差异格式化
// 严格翻译自 bun/src/runtime/test_runner/diff_format.zig

package bao_runtime.test_runner

import bao_jsc.{JSGlobalObject, JsValue, Output, StringBuilder}
import bao_collections.ArrayList
import bao_collections.HashMap

// ========== DiffFormatter - 差异格式化器 ==========

/// 差异格式化器，用于在测试失败时显示期望值和接收值之间的差异
public class DiffFormatter {
    public var receivedString: ?String = None
    public var expectedString: ?String = None
    public var received: ?JsValue = None
    public var expected: ?JsValue = None
    public var globalThis: JSGlobalObject
    public var not: Bool = false

    public init() {}

    public init(receivedString: ?String, expectedString: ?String, globalThis: JSGlobalObject, not: Bool) {
        this.receivedString = receivedString
        this.expectedString = expectedString
        this.globalThis = globalThis
        this.not = not
    }

    public init(received: JsValue, expected: JsValue, globalThis: JSGlobalObject, not: Bool) {
        this.received = received
        this.expected = expected
        this.globalThis = globalThis
        this.not = not
    }

    /// 格式化差异
    public func format(writer: StringWriter) {
        let diffConfig = DiffConfig.default(isAgent: Output.isAIAgent(), enableAnsiColors: Output.enableAnsiColorsStderr())

        // 如果已有字符串, 直接比较
        if (expectedString.isSome() && receivedString.isSome()) {
            let received = receivedString ?? ""
            let expected = expectedString ?? ""
            printDiffMain(not: not, receivedSlice: received, expectedSlice: expected, writer: writer, config: diffConfig)
            return
        }

        if (received.isNone() || expected.isNone()) { return }

        // 将JS值转换为字符串进行比较
        let receivedValue = received.getOrThrow()
        let expectedValue = expected.getOrThrow()

        var receivedBuf = StringBuilder()
        var expectedBuf = StringBuilder()

        // 使用JestPrettyFormat格式化
        let fmtOptions = JestPrettyFormat.FormatOptions(
            enableColors: false,
            addNewline: false,
            flush: false,
            quoteStrings: true
        )

        JestPrettyFormat.format(
            level: MessageLevel.debug_,
            global: globalThis,
            vals: [receivedValue],
            len: 1,
            writer: receivedBuf,
            options: fmtOptions
        )

        JestPrettyFormat.format(
            level: MessageLevel.debug_,
            global: globalThis,
            vals: [expectedValue],
            len: 1,
            writer: expectedBuf,
            options: fmtOptions
        )

        var receivedSlice = receivedBuf.toString()
        var expectedSlice = expectedBuf.toString()

        // 移除首尾换行
        if (receivedSlice.startsWith("\n")) { receivedSlice = receivedSlice[1..] }
        if (expectedSlice.startsWith("\n")) { expectedSlice = expectedSlice[1..] }
        if (receivedSlice.endsWith("\n")) { receivedSlice = receivedSlice[0..receivedSlice.size - 1] }
        if (expectedSlice.endsWith("\n")) { expectedSlice = expectedSlice[0..expectedSlice.size - 1] }

        printDiffMain(not: not, receivedSlice: receivedSlice, expectedSlice: expectedSlice, writer: writer, config: diffConfig)
    }
}
