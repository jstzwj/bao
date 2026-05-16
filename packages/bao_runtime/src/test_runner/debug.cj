// debug.cj - 调试输出
// 严格翻译自 bun/src/runtime/test_runner/debug.zig

package bao_runtime.test_runner

import bao_jsc.*
import std.collection.*

// ========== Debug - 调试工具 ==========

/// 调试工具，提供测试框架内部的调试日志输出
public class Debug {
    /// 转储子条目
    public static func dumpSub(current: TestScheduleEntry) {
        if (!group.getLogEnabled()) { return }
        match (current) {
            case TestScheduleEntry.describe(describe) => dumpDescribe(describe: describe)
            case TestScheduleEntry.testCallback(testCallback) => dumpTest(current: testCallback, label: "test")
        }
    }

    /// 转储describe作用域
    public static func dumpDescribe(describe: DescribeScope) {
        if (!group.getLogEnabled()) { return }
        group.beginMsg("describe \"" + describe.base.name ?? "(unnamed)" + "\" (concurrent=" + describe.base.concurrent + ", mode=${describe.base.mode}, only=${describe.base.only}, has_callback=${describe.base.hasCallback})")
        defer { group.end() }

        for (entry in describe.beforeAll.toArray()) { dumpTest(current: entry, label: "beforeAll") }
        for (entry in describe.beforeEach.toArray()) { dumpTest(current: entry, label: "beforeEach") }
        for (entry in describe.entries.toArray()) { dumpSub(current: entry) }
        for (entry in describe.afterEach.toArray()) { dumpTest(current: entry, label: "afterEach") }
        for (entry in describe.afterAll.toArray()) { dumpTest(current: entry, label: "afterAll") }
    }

    /// 转储测试条目
    public static func dumpTest(current: ExecutionEntry, label: String) {
        if (!group.getLogEnabled()) { return }
        group.beginMsg("" + label + " \"" + current.base.name ?? "(unnamed)" + "\" (concurrent=" + current.base.concurrent + ", only=" + current.base.only + ")")
        group.end()
    }

    /// 转储执行顺序
    public static func dumpOrder(execution: Execution) {
        if (!group.getLogEnabled()) { return }
        group.beginMsg("dumpOrder")
        defer { group.end() }

        for (i in 0..execution.groups.size) {
            let groupValue = execution.groups[i]
            group.beginMsg("" + i + " ConcurrentGroup (" + groupValue.sequenceStart + "-${groupValue.sequenceEnd})")
            defer { group.end() }

            var sequenceIdx: UInt64 = 0
            for (j in 0..(groupValue.sequenceEnd - groupValue.sequenceStart)) {
                let sequence = execution.sequences[groupValue.sequenceStart + j]
                group.beginMsg("" + sequenceIdx + " Sequence (" + sequence.remainingRepeatCount + "x)")
                defer { group.end() }

                var currentEntry = sequence.firstEntry
                while (currentEntry != None) {
                    let entry = currentEntry.getOrThrow()
                    group.log("ExecutionEntry \"" + entry.base.name ?? "(unnamed)" + "\" (concurrent=" + entry.base.concurrent + ", mode=" + entry.base.mode + ", only=" + entry.base.only + ", has_callback=" + entry.base.hasCallback + ")")
                    currentEntry = entry.next
                }
                sequenceIdx += 1
            }
        }
    }
}

// ========== DebugGroup - 调试分组 ==========

/// 调试日志分组工具
public class DebugGroup {
    private var indent: UInt64 = 0
    private var lastWasStart: Bool = false

    /// 获取日志是否启用
    public static func getLogEnabled(): Bool {
        return EnvVar.WANTS_LOUD.get()
    }

    /// 打印缩进
    private func printIndent(writer: StringWriter) {
        writer.write("\u{1b}[90m")
        for (i in 0..indent) {
            writer.write("| ")
        }
        writer.write("\u{1b}[m")
    }

    /// 开始带位置信息的分组
    public func begin(file: String, line: UInt64, column: UInt64, fnName: String) {
        beginMsg("\u{1b}[36m" + file + "\u{1b}[37m:\u{1b}[93m" + line + "\u{1b}[37m:\u{1b}[33m${column}\u{1b}[37m: \u{1b}[35m${fnName}\u{1b}[m")
    }

    /// 开始带消息的分组
    public func beginMsg(message: String) {
        if (!DebugGroup.getLogEnabled()) { return }

        var buf = StringBuilder()
        let writer = StringWriter(buf)
        printIndent(writer: writer)
        writer.write("\u{1b}[32m++ \u{1b}[0m")
        writer.write(message)
        writer.write("\n")
        writer.flush()
        indent += 1
        lastWasStart = true
    }

    /// 结束分组
    public func end() {
        if (!DebugGroup.getLogEnabled()) { return }
        if (indent > 0) { indent -= 1 }
        defer { lastWasStart = false }
        if (lastWasStart) { return }

        var buf = StringBuilder()
        let writer = StringWriter(buf)
        printIndent(writer: writer)
        writer.write("\u{1b}[32m" + (if (lastWasStart) { "+-" } else { "--" }) + "\u{1b}[m\n")
        writer.flush()
    }

    /// 输出日志
    public func log(message: String) {
        if (!DebugGroup.getLogEnabled()) { return }
        var buf = StringBuilder()
        let writer = StringWriter(buf)
        printIndent(writer: writer)
        writer.write(message)
        writer.write("\n")
        writer.flush()
        lastWasStart = false
    }
}

/// 全局调试组实例
public let group = DebugGroup()
