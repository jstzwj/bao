// debug.cj - 调试输出
// 严格翻译自 bun/src/runtime/test_runner/debug.zig

package bao_runtime.test_runner

import bao_collections.ArrayList
import bao_collections.HashMap
import bao_sys.OS

// ========== DebugGroup - 调试分组 ==========

/// 调试日志分组工具
public class DebugGroup {
    private var indent: UInt64 = 0
    private var lastWasStart: Bool = false

    /// 获取日志是否启用
    /// 对应 Bun: bun.env_var.WANTS_LOUD.get()
    public static func getLogEnabled(): Bool {
        match (OS.getEnv("WANTS_LOUD")) {
            case Some(value) =>
                return value == "1" || value == "true" || value == "yes"
            case None => return false
        }
    }

    /// 打印缩进
    private func printIndent(buf: StringBuilder) {
        buf.append("\u{1b}[90m")
        for (i in 0..indent) {
            buf.append("| ")
        }
        buf.append("\u{1b}[m")
    }

    /// 开始带位置信息的分组
    public func begin(file: String, line: UInt64, column: UInt64, fnName: String) {
        beginMsg("\u{1b}[36m" + file + "\u{1b}[37m:\u{1b}[93m" + line.toString() + "\u{1b}[37m:\u{1b}[33m" + column.toString() + "\u{1b}[37m: \u{1b}[35m" + fnName + "\u{1b}[m")
    }

    /// 开始带消息的分组
    public func beginMsg(message: String) {
        if (!DebugGroup.getLogEnabled()) { return }

        var buf = StringBuilder()
        printIndent(buf)
        buf.append("\u{1b}[32m++ \u{1b}[0m")
        buf.append(message)
        buf.append("\n")
        indent += 1
        lastWasStart = true
    }

    /// 结束分组
    public func end(): Unit {
        if (!DebugGroup.getLogEnabled()) { return }
        if (indent > 0) { indent -= 1 }
        // defer { lastWasStart = false }
        if (lastWasStart) { return }

        var buf = StringBuilder()
        printIndent(buf)
        buf.append("\u{1b}[32m" + (if (lastWasStart) { "+-" } else { "--" }) + "\u{1b}[m\n")
    }

    /// 输出日志
    public func log(message: String): Unit {
        if (!DebugGroup.getLogEnabled()) { return }
        var buf = StringBuilder()
        printIndent(buf)
        buf.append(message)
        buf.append("\n")
        lastWasStart = false
    }
}

/// 全局调试组实例
public let group = DebugGroup()

// ========== Debug - 调试工具 ==========

/// 调试工具，提供测试框架内部的调试日志输出
public class Debug {
    /// 转储子条目
    public static func dumpSub(current: TestScheduleEntry): Unit {
        if (!DebugGroup.getLogEnabled()) { return }
        match (current) {
            case TestScheduleEntry.describe(descScope) => dumpDescribe(descScope)
            case TestScheduleEntry.testCallback(execEntry) => dumpTest(execEntry, "test")
        }
    }

    /// 转储describe作用域
    public static func dumpDescribe(describe: DescribeScope): Unit {
        if (!DebugGroup.getLogEnabled()) { return }
        let nameStr = describe.base.name ?? "(unnamed)"
        group.beginMsg("describe \"" + nameStr + "\" (concurrent=" + describe.base.concurrent.toString() + ")")
        // defer { group.end() }

        for (entry in describe.beforeAll) { dumpTest(entry, "beforeAll") }
        for (entry in describe.beforeEach) { dumpTest(entry, "beforeEach") }
        for (entry in describe.entries) { dumpSub(entry) }
        for (entry in describe.afterEach) { dumpTest(entry, "afterEach") }
        for (entry in describe.afterAll) { dumpTest(entry, "afterAll") }
    }

    /// 转储测试条目
    public static func dumpTest(current: ExecutionEntry, label: String): Unit {
        if (!DebugGroup.getLogEnabled()) { return }
        let nameStr = current.base.name ?? "(unnamed)"
        group.beginMsg("" + label + " \"" + nameStr + "\" (concurrent=" + current.base.concurrent.toString() + ")")
        group.end()
    }

    /// 转储执行顺序
    public static func dumpOrder(execution: Execution): Unit {
        if (!DebugGroup.getLogEnabled()) { return }
        group.beginMsg("dumpOrder")
        // defer { group.end() }

        for (i in 0..execution.groups.size) {
            let groupValue = execution.groups[i]
            group.beginMsg("" + i.toString() + " ConcurrentGroup (" + groupValue.sequenceStart.toString() + "-" + groupValue.sequenceEnd.toString() + ")")
            // defer { group.end() }

            var sequenceIdx: UInt64 = 0
            for (j in 0..(groupValue.sequenceEnd - groupValue.sequenceStart)) {
                let sequence = execution.sequences[Int64(groupValue.sequenceStart + j)]
                group.beginMsg("" + sequenceIdx.toString() + " Sequence (" + sequence.remainingRepeatCount.toString() + "x)")
                // defer { group.end() }

                var currentEntry = sequence.firstEntry
                while (currentEntry.isSome()) {
                    let entry = currentEntry.getOrThrow()
                    let entryName = entry.base.name ?? "(unnamed)"
                    group.log("ExecutionEntry \"" + entryName + "\"")
                    currentEntry = entry.next
                }
                sequenceIdx += 1
            }
        }
    }
}
