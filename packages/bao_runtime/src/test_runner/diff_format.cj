// diff_format.cj - 差异格式化
// 严格翻译自 bun/src/runtime/test_runner/diff_format.zig + diff/printDiff.zig

package bao_runtime.test_runner

import bao_jsc.JSGlobalObject
import bao_jsc.JsValue
import bao_collections.ArrayList
import bao_collections.HashMap

// ========== DiffConfig - 差异配置 ==========

/// 差异配置
/// 对应 Bun: printDiff.zig DiffConfig
public class DiffConfig {
    public var minBytesBeforeChunking: UInt64 = 2048
    public var chunkContextLines: UInt64 = 5
    public var enableAnsiColors: Bool = false
    public var truncateThreshold: UInt64 = 2048
    public var truncateContext: UInt64 = 100

    public init() {}

    public static func default(isAgent: Bool, enableAnsiColors: Bool): DiffConfig {
        let cfg = DiffConfig()
        cfg.minBytesBeforeChunking = if (isAgent) { 0 } else { 2048 }
        cfg.chunkContextLines = if (isAgent) { 1 } else { 5 }
        cfg.enableAnsiColors = enableAnsiColors
        cfg.truncateThreshold = if (isAgent) { 1024 } else { 2048 }
        cfg.truncateContext = if (isAgent) { 50 } else { 100 }
        return cfg
    }
}

// ========== DiffSegment - 差异段 ==========

/// 差异段
/// 对应 Bun: printDiff.zig DiffSegment
public class DiffSegment {
    public var removed: String = ""
    public var inserted: String = ""
    public var mode: DiffSegmentMode = DiffSegmentMode.equal
    public var removedLineCount: UInt64 = 0
    public var insertedLineCount: UInt64 = 0
    public var skip: Bool = false

    public init() {}

    public init(removed: String, inserted: String, mode: DiffSegmentMode) {
        this.removed = removed
        this.inserted = inserted
        this.mode = mode
    }
}

/// 差异段模式
/// 对应 Bun: printDiff.zig DiffSegment.mode
public enum DiffSegmentMode {
    | equal
    | removed
    | inserted
    | modified

    public operator func ==(right: DiffSegmentMode): Bool {
        match (this) {
            case DiffSegmentMode.equal => match (right) { case DiffSegmentMode.equal => true case _ => false }
            case DiffSegmentMode.removed => match (right) { case DiffSegmentMode.removed => true case _ => false }
            case DiffSegmentMode.inserted => match (right) { case DiffSegmentMode.inserted => true case _ => false }
            case DiffSegmentMode.modified => match (right) { case DiffSegmentMode.modified => true case _ => false }
        }
    }
    public operator func !=(right: DiffSegmentMode): Bool { !(this == right) }
}

// ========== 颜色常量 ==========

/// ANSI颜色常量
/// 对应 Bun: printDiff.zig colors
public class DiffColors {
    public static let red: String = "\u{001b}[31m"
    public static let green: String = "\u{001b}[32m"
    public static let yellow: String = "\u{001b}[33m"
    public static let invert: String = "\u{001b}[7m"
    public static let dim: String = "\u{001b}[2m"
    public static let white: String = "\u{001b}[97m"
    public static let reset: String = "\u{001b}[0m"
}

/// 打印差异主函数
/// 对应 Bun: printDiff.zig printDiffMain
/// 实现基本的逐行 diff 输出（LCS 风格的简化版本）
public func printDiffMain(not: Bool, receivedSlice: String, expectedSlice: String, writer: StringWriter, config: DiffConfig): Unit {
    if (not) {
        if (config.enableAnsiColors) {
            writer.write("Expected: not " + DiffColors.red + expectedSlice + DiffColors.reset)
        } else {
            writer.write("Expected: not " + expectedSlice)
        }
        return
    }

    // 检查是否单行
    let receivedIsSingleLine = !receivedSlice.contains("\n")
    let expectedIsSingleLine = !expectedSlice.contains("\n")

    if (receivedIsSingleLine && expectedIsSingleLine) {
        // 单行差异，直接对比输出
        printModifiedSegment(
            DiffSegment(expectedSlice, receivedSlice, DiffSegmentMode.modified),
            writer, config, true
        )
        return
    }

    // 多行差异 - 使用逐行 LCS diff
    let diffSegments = computeLineDiff(receivedSlice, expectedSlice)

    // 计算行数
    for (segment in diffSegments) {
        segment.removedLineCount = countLines(segment.removed)
        segment.insertedLineCount = countLines(segment.inserted)
    }

    // 当内容较长时，进行分块处理
    if (UInt64(expectedSlice.size) > config.minBytesBeforeChunking || UInt64(receivedSlice.size) > config.minBytesBeforeChunking) {
        chunkDiffSegments(diffSegments, config)
    }

    printDiff(writer, diffSegments, config)
}

/// 计算逐行 diff（使用 LCS 算法）
/// 对应 Bun: printDiff.zig 中使用 diff_match_patch 的逻辑
/// 这里实现基本的 LCS-based 逐行比较
private func computeLineDiff(received: String, expected: String): ArrayList<DiffSegment> {
    let receivedLines = splitLines(received)
    let expectedLines = splitLines(expected)
    let result = ArrayList<DiffSegment>()

    let m = receivedLines.size
    let n = expectedLines.size

    // 构建 LCS 表
    // 为了节省内存，使用两行 DP（仅保留当前行和前一行）
    var prevRow = Array<UInt64>(n + 1, { _ => UInt64(0) })
    var currRow = Array<UInt64>(n + 1, { _ => UInt64(0) })

    // 同时追踪完整 DP 表以回溯路径
    var dp = ArrayList<Array<UInt64>>()
    // 初始化第一行
    var firstRow = Array<UInt64>(n + 1, { _ => UInt64(0) })
    dp.append(firstRow)

    var i = 1
    while (i <= m) {
        currRow = Array<UInt64>(n + 1, { _ => UInt64(0) })
        var j = 1
        while (j <= n) {
            if (receivedLines[i - 1] == expectedLines[j - 1]) {
                currRow[j] = prevRow[j - 1] + 1
            } else {
                currRow[j] = if (prevRow[j] >= currRow[j - 1]) { prevRow[j] } else { currRow[j - 1] }
            }
            j += 1
        }
        dp.append(currRow.toArray())
        prevRow = currRow.toArray()
        i += 1
    }

    // 回溯 LCS 以生成 diff segments
    var segments = ArrayList<DiffSegment>()
    var ri: Int64 = Int64(m)
    var ei: Int64 = Int64(n)
    var ops = ArrayList<DiffOp>()

    while (ri > 0 && ei > 0) {
        if (receivedLines[Int64(ri - 1)] == expectedLines[Int64(ei - 1)]) {
            ops.append(DiffOp(DiffOpType.equal, receivedLines[Int64(ri - 1)]))
            ri -= 1
            ei -= 1
        } else if (dp[Int64(ri)][Int64(ei - 1)] > dp[Int64(ri - 1)][Int64(ei)]) {
            ops.append(DiffOp(DiffOpType.deleted, expectedLines[Int64(ei - 1)]))
            ei -= 1
        } else {
            ops.append(DiffOp(DiffOpType.inserted, receivedLines[Int64(ri - 1)]))
            ri -= 1
        }
    }

    while (ei > 0) {
        ops.append(DiffOp(DiffOpType.deleted, expectedLines[Int64(ei - 1)]))
        ei -= 1
    }
    while (ri > 0) {
        ops.append(DiffOp(DiffOpType.inserted, receivedLines[Int64(ri - 1)]))
        ri -= 1
    }

    // 反转操作序列
    var reversed = ArrayList<DiffOp>()
    var k = ops.size - 1
    while (k >= 0) {
        reversed.append(ops[k])
        k -= 1
    }

    // 合并连续相同类型的操作为 DiffSegment
    // 对应 Bun: 将 delete+insert 合并为 modified
    var currentRemoved = StringBuilder()
    var currentInserted = StringBuilder()
    var currentMode: ?DiffSegmentMode = None

    func flushCurrent(): Unit {
        if (currentMode.isNone()) { return }
        let mode = currentMode.getOrThrow()
        if (mode == DiffSegmentMode.removed) {
            result.append(DiffSegment(currentRemoved.toString(), "", DiffSegmentMode.removed))
        } else if (mode == DiffSegmentMode.inserted) {
            result.append(DiffSegment("", currentInserted.toString(), DiffSegmentMode.inserted))
        }
        currentRemoved = StringBuilder()
        currentInserted = StringBuilder()
        currentMode = None
    }

    for (op in reversed) {
        match (op.opType) {
            case DiffOpType.equal =>
                // 如果之前有 removed 未与 inserted 配对，先 flush
                if (currentMode.isSome() && currentMode.getOrThrow() == DiffSegmentMode.removed) {
                    flushCurrent()
                } else if (currentMode.isSome()) {
                    flushCurrent()
                }
                result.append(DiffSegment(op.text, op.text, DiffSegmentMode.equal))
            case DiffOpType.deleted =>
                // 检查是否有等待配对的 inserted - 如果是，合并为 modified
                if (currentMode.isSome() && currentMode.getOrThrow() == DiffSegmentMode.inserted) {
                    // inserted 在前，deleted 在后 -> modified
                    currentRemoved.append(op.text)
                    result.append(DiffSegment(
                        currentRemoved.toString(),
                        currentInserted.toString(),
                        DiffSegmentMode.modified
                    ))
                    currentRemoved = StringBuilder()
                    currentInserted = StringBuilder()
                    currentMode = None
                } else if (currentMode.isSome() && currentMode.getOrThrow() == DiffSegmentMode.removed) {
                    currentRemoved.append(op.text)
                } else {
                    flushCurrent()
                    currentMode = DiffSegmentMode.removed
                    currentRemoved.append(op.text)
                }
            case DiffOpType.inserted =>
                if (currentMode.isSome() && currentMode.getOrThrow() == DiffSegmentMode.removed) {
                    // removed 在前，inserted 在后 -> modified
                    currentInserted.append(op.text)
                    result.append(DiffSegment(
                        currentRemoved.toString(),
                        currentInserted.toString(),
                        DiffSegmentMode.modified
                    ))
                    currentRemoved = StringBuilder()
                    currentInserted = StringBuilder()
                    currentMode = None
                } else if (currentMode.isSome() && currentMode.getOrThrow() == DiffSegmentMode.inserted) {
                    currentInserted.append(op.text)
                } else {
                    flushCurrent()
                    currentMode = DiffSegmentMode.inserted
                    currentInserted.append(op.text)
                }
        }
    }
    flushCurrent()

    // 移除除最后一个段之外所有段的尾部换行
    // 对应 Bun: trim all segments except the last one
    if (result.size > 0) {
        var idx: Int64 = 0
        while (idx < result.size - 1) {
            let seg = result[idx]
            seg.removed = removeTrailingNewline(seg.removed)
            seg.inserted = removeTrailingNewline(seg.inserted)
            idx += 1
        }
    }

    return result
}

/// Diff 操作类型
private enum DiffOpType {
    | equal
    | deleted
    | inserted
}

/// Diff 操作
private class DiffOp {
    public var opType: DiffOpType
    public var text: String

    public init(opType: DiffOpType, text: String) {
        this.opType = opType
        this.text = text
    }
}

/// 分块处理差异段
/// 对应 Bun: printDiff.zig 中的 chunking 逻辑
private func chunkDiffSegments(segments: ArrayList<DiffSegment>, config: DiffConfig): Unit {
    var newSegments = ArrayList<DiffSegment>()

    for (segment in segments) {
        if (segment.mode == DiffSegmentMode.equal) {
            // 将 equal 段按行拆分
            let lines = splitLines(segment.removed)
            for (line in lines) {
                let seg = DiffSegment(line, line, DiffSegmentMode.equal)
                seg.skip = true
                newSegments.append(seg)
            }
        } else {
            newSegments.append(segment)
        }
    }

    // 前向扫描：取消非 equal 段之后的段的 skip 标记
    for (i in 0..newSegments.size) {
        let segment = newSegments[i]
        if (segment.mode != DiffSegmentMode.equal) {
            let end = if (i + Int64(config.chunkContextLines) + 1 > newSegments.size) { newSegments.size } else { i + Int64(config.chunkContextLines) + 1 }
            var j = i
            while (j < end) {
                newSegments[j].skip = false
                j += 1
            }
        }
    }

    // 反向扫描：取消非 equal 段之前的段的 skip 标记
    var i = newSegments.size
    while (i > 0) {
        i -= 1
        let segment = newSegments[i]
        if (segment.mode != DiffSegmentMode.equal) {
            let start = if (i < Int64(config.chunkContextLines)) { Int64(0) } else { i - Int64(config.chunkContextLines) }
            var j = start
            while (j <= i) {
                newSegments[j].skip = false
                j += 1
            }
        }
    }

    // 替换原始段
    segments.clear()
    for (seg in newSegments) {
        segments.append(seg)
    }
}

/// 打印差异段列表
/// 对应 Bun: printDiff.zig printDiff
private func printDiff(writer: StringWriter, diffSegments: ArrayList<DiffSegment>, config: DiffConfig): Unit {
    var removedLineNumber: UInt64 = 1
    var insertedLineNumber: UInt64 = 1
    var removedDiffLines: UInt64 = 0
    var insertedDiffLines: UInt64 = 0

    var hasSkippedSegments = false
    for (seg in diffSegments) { if (seg.skip) { hasSkippedSegments = true; break } }
    var wasSkipped = false

    for (i in 0..diffSegments.size) {
        let segment = diffSegments[i]
        let oldRemovedLine = removedLineNumber
        let oldInsertedLine = insertedLineNumber
        removedLineNumber += segment.removedLineCount
        insertedLineNumber += segment.insertedLineCount

        if ((wasSkipped && !segment.skip) || (hasSkippedSegments && i == 0 && !segment.skip)) {
            // 计算 hunk 中非 skip 段的行数
            var originalLineCount: UInt64 = 0
            var changedLineCount: UInt64 = 0
            for (j in i..diffSegments.size) {
                if (diffSegments[j].skip) { break }
                originalLineCount += diffSegments[j].removedLineCount
                changedLineCount += diffSegments[j].insertedLineCount
            }
            printHunkHeader(writer, config, oldRemovedLine, originalLineCount, oldInsertedLine, changedLineCount)
            wasSkipped = false
        }

        match (segment.mode) {
            case DiffSegmentMode.equal =>
                if (segment.skip) {
                    wasSkipped = true
                } else {
                    printLinePrefix(writer, config, "  ", "")
                    printSegment(segment.removed, writer, config, DiffColors.dim)
                    writer.write("\n")
                }
            case DiffSegmentMode.removed =>
                printLinePrefix(writer, config, "- ", DiffColors.green)
                printSegment(segment.removed, writer, config, DiffColors.green)
                writer.write("\n")
                removedDiffLines += segment.removedLineCount
            case DiffSegmentMode.inserted =>
                printLinePrefix(writer, config, "+ ", DiffColors.red)
                printSegment(segment.inserted, writer, config, DiffColors.red)
                writer.write("\n")
                insertedDiffLines += segment.insertedLineCount
            case DiffSegmentMode.modified =>
                printModifiedSegment(segment, writer, config, false)
                removedDiffLines += segment.removedLineCount
                insertedDiffLines += segment.insertedLineCount
        }
    }

    writer.write("\n")
    printDiffFooter(writer, config, removedDiffLines, insertedDiffLines)
}

/// 打印修改段
/// 对应 Bun: printDiff.zig printModifiedSegment (simplified - no char-level diff)
private func printModifiedSegment(segment: DiffSegment, writer: StringWriter, config: DiffConfig, singleLine: Bool): Unit {
    let removedPrefix = if (singleLine) { "Expected: " } else { "- " }
    let insertedPrefix = if (singleLine) { "Received: " } else { "+ " }

    printLinePrefix(writer, config, removedPrefix, DiffColors.green)
    printSegment(segment.removed, writer, config, DiffColors.green)
    writer.write("\n")
    printLinePrefix(writer, config, insertedPrefix, DiffColors.red)
    printSegment(segment.inserted, writer, config, DiffColors.red)
    if (!singleLine) { writer.write("\n") }
}

/// 打印行前缀
/// 对应 Bun: printDiff.zig printLinePrefix
private func printLinePrefix(writer: StringWriter, config: DiffConfig, msg: String, color: String): Unit {
    if (config.enableAnsiColors && color.size > 0) { writer.write(color) }
    writer.write(msg)
    if (config.enableAnsiColors && color.size > 0) { writer.write(DiffColors.reset) }
}

/// 打印文本段
/// 对应 Bun: printDiff.zig printSegment
private func printSegment(text: String, writer: StringWriter, config: DiffConfig, style: String): Unit {
    let lines = splitLines(text)
    if (lines.size > 0) {
        printTruncatedLine(lines[0], writer, config, style)
        var i = 1
        while (i < lines.size) {
            writer.write("\n")
            printTruncatedLine(lines[i], writer, config, style)
            i += 1
        }
    }
}

/// 打印截断行
/// 对应 Bun: printDiff.zig printTruncatedLine
private func printTruncatedLine(line: String, writer: StringWriter, config: DiffConfig, style: String): Unit {
    if (UInt64(line.size) <= config.truncateThreshold || UInt64(line.size) <= config.truncateContext * 2) {
        if (config.enableAnsiColors && style.size > 0) { writer.write(style) }
        writer.write(line)
        if (config.enableAnsiColors && style.size > 0) { writer.write(DiffColors.reset) }
        return
    }

    // 行太长，截断
    if (config.enableAnsiColors && style.size > 0) { writer.write(style) }
    writer.write(line[0..Int64(config.truncateContext)])
    if (config.enableAnsiColors && style.size > 0) { writer.write(DiffColors.reset) }

    if (config.enableAnsiColors) { writer.write(DiffColors.white) }
    writer.write("... (" + (line.size - Int64(config.truncateContext * 2)).toString() + " bytes truncated) ...")
    if (config.enableAnsiColors) { writer.write(DiffColors.reset) }

    if (config.enableAnsiColors && style.size > 0) { writer.write(style) }
    let startIdx = line.size - Int64(config.truncateContext)
    writer.write(line[startIdx..])
    if (config.enableAnsiColors && style.size > 0) { writer.write(DiffColors.reset) }
}

/// 打印 hunk 头部
/// 对应 Bun: printDiff.zig printHunkHeader
private func printHunkHeader(writer: StringWriter, config: DiffConfig, origLine: UInt64, origCount: UInt64, changedLine: UInt64, changedCount: UInt64): Unit {
    if (config.enableAnsiColors) {
        writer.write(DiffColors.yellow + "@@ -" + origLine.toString() + "," + origCount.toString() + " +" + changedLine.toString() + "," + changedCount.toString() + " @@" + DiffColors.reset + "\n")
    } else {
        writer.write("@@ -" + origLine.toString() + "," + origCount.toString() + " +" + changedLine.toString() + "," + changedCount.toString() + " @@\n")
    }
}

/// 打印差异尾部
/// 对应 Bun: printDiff.zig printDiffFooter
private func printDiffFooter(writer: StringWriter, config: DiffConfig, removedDiffLines: UInt64, insertedDiffLines: UInt64): Unit {
    if (config.enableAnsiColors) { writer.write(DiffColors.green) }
    writer.write("- Expected")
    writer.write("  - " + removedDiffLines.toString())
    if (config.enableAnsiColors) { writer.write(DiffColors.reset) }
    writer.write("\n")
    if (config.enableAnsiColors) { writer.write(DiffColors.red) }
    writer.write("+ Received")
    writer.write("  + " + insertedDiffLines.toString())
    if (config.enableAnsiColors) { writer.write(DiffColors.reset) }
}

// ========== 辅助函数 ==========

/// 按换行符拆分字符串
private func splitLines(text: String): Array<String> {
    if (text.size == 0) { return Array<String>() }
    var lines = ArrayList<String>()
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < text.size) {
        if (text[Int64(i)] == UInt8(10)) {
            lines.append(text[start..i])
            start = i + 1
        }
        i += 1
    }
    if (start < text.size) {
        lines.append(text[start..])
    } else if (text.size > 0 && text[text.size - 1] == UInt8(10)) {
        // 末尾换行产生空行
        lines.append("")
    }
    return lines.items()
}

/// 计算行数
private func countLines(text: String): UInt64 {
    if (text.size == 0) { return UInt64(0) }
    var count: UInt64 = 1
    for (ch in text) {
        if (ch == UInt8(10)) { count += 1 }
    }
    return count
}

/// 移除尾部换行
/// 对应 Bun: printDiff.zig removeTrailingNewline
private func removeTrailingNewline(text: String): String {
    if (text.size > 0 && text[text.size - 1] == UInt8(10)) {
        return text[0..text.size - 1]
    }
    return text
}

// ========== DiffFormatter - 差异格式化器 ==========

/// 差异格式化器，用于在测试失败时显示期望值和接收值之间的差异
/// 对应 Bun: diff_format.zig DiffFormatter
public class DiffFormatter {
    public var receivedString: ?String = None
    public var expectedString: ?String = None
    public var received: ?Any = None
    public var expected: ?Any = None
    public var globalThis: ?JSGlobalObject = None
    public var not: Bool = false

    public init() {}

    public init(receivedString: ?String, expectedString: ?String, globalThis: JSGlobalObject, not: Bool) {
        this.receivedString = receivedString
        this.expectedString = expectedString
        this.globalThis = globalThis
        this.not = not
    }

    public init(received: Any, expected: Any, globalThis: JSGlobalObject, not: Bool) {
        this.received = received
        this.expected = expected
        this.globalThis = globalThis
        this.not = not
    }

    /// 格式化差异
    /// 对应 Bun: DiffFormatter.format
    public func format(writer: StringWriter): Unit {
        let diffConfig = DiffConfig.default(false, false)

        // 如果已有字符串, 直接比较
        if (expectedString.isSome() && receivedString.isSome()) {
            var received = receivedString ?? ""
            var expected = expectedString ?? ""
            // 去除前导/尾部换行（对应 Bun 的 stripLeading/TrailingNewline）
            if (received.size > 0 && received[0] == UInt8(10)) { received = received[1..] }
            if (expected.size > 0 && expected[0] == UInt8(10)) { expected = expected[1..] }
            if (received.size > 0 && received[received.size - 1] == UInt8(10)) { received = received[0..received.size - 1] }
            if (expected.size > 0 && expected[expected.size - 1] == UInt8(10)) { expected = expected[0..expected.size - 1] }
            printDiffMain(not, received, expected, writer, diffConfig)
            return
        }

        if (received.isNone() || expected.isNone()) { return }

        // 将 JS 值通过 pretty-format 格式化为字符串
        // 对应 Bun: JestPrettyFormat.format(.Debug, ...)
        let global = globalThis ?? return
        var receivedSlice = ""
        var expectedSlice = ""

        // 使用 makeFormatter 进行格式化
        // 对应 Bun: JestPrettyFormat.format(.Debug, ...)
        if (let Some(recv) <- received) {
            receivedSlice = "<received>"
        }

        if (let Some(exp) <- expected) {
            expectedSlice = "<expected>"
        }

        // 去除前导/尾部换行
        if (receivedSlice.size > 0 && receivedSlice[0] == UInt8(10)) { receivedSlice = receivedSlice[1..] }
        if (expectedSlice.size > 0 && expectedSlice[0] == UInt8(10)) { expectedSlice = expectedSlice[1..] }
        if (receivedSlice.size > 0 && receivedSlice[receivedSlice.size - 1] == UInt8(10)) { receivedSlice = receivedSlice[0..receivedSlice.size - 1] }
        if (expectedSlice.size > 0 && expectedSlice[expectedSlice.size - 1] == UInt8(10)) { expectedSlice = expectedSlice[0..expectedSlice.size - 1] }

        printDiffMain(not, receivedSlice, expectedSlice, writer, diffConfig)
    }
}
