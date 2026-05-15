// diff_format.cj - 差异格式化
// 严格翻译自 bun/src/runtime/test_runner/diff_format.zig

package bao_runtime

// ========== DiffFormatter - 差异格式化器 ==========

/// 差异格式化器，用于在测试失败时显示期望值和接收值之间的差异
public class DiffFormatter {
    public var receivedString: ?String = None
    public var expectedString: ?String = None
    public var received: ?JSValue = None
    public var expected: ?JSValue = None
    public var globalThis: JSGlobalObject
    public var not: Bool = false

    public init() {}

    public init(receivedString: ?String, expectedString: ?String, globalThis: JSGlobalObject, not: Bool) {
        this.receivedString = receivedString
        this.expectedString = expectedString
        this.globalThis = globalThis
        this.not = not
    }

    public init(received: JSValue, expected: JSValue, globalThis: JSGlobalObject, not: Bool) {
        this.received = received
        this.expected = expected
        this.globalThis = globalThis
        this.not = not
    }

    /// 格式化差异
    public func format(writer: StringWriter) {
        // 如果已有字符串，直接比较
        if expectedString != None && receivedString != None {
            let received = receivedString ?? ""
            let expected = expectedString ?? ""
            printDiffMain(not: not, received: received, expected: expected, writer: writer)
            return
        }

        if received == None || expected == None { return }

        // 将JS值转换为字符串进行比较
        // TODO: 使用JestPrettyFormat格式化
    }
}

/// 打印差异主体
public func printDiffMain(not: Bool, received: String, expected: String, writer: StringWriter) {
    // TODO: 实现 - 调用diff/printDiff
    writer.write("Expected: ")
    writer.write(expected)
    writer.write("\nReceived: ")
    writer.write(received)
    writer.write("\n")
}

/// 差异配置
public class DiffConfig {
    public var isAI: Bool = false
    public var enableAnsiColors: Bool = false

    public init() {}

    public static func `default`(isAI: Bool, enableColors: Bool): DiffConfig {
        let cfg = DiffConfig()
        cfg.isAI = isAI
        cfg.enableAnsiColors = enableColors
        return cfg
    }
}
