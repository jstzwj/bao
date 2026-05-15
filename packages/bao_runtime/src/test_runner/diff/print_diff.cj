// print_diff.cj - 差异打印
// 严格翻译自 bun/src/runtime/test_runner/diff/printDiff.zig

package bao_runtime.test_runner.diff

// ========== ANSI颜色常量 ==========
public class DiffColors {
    public static let red: String = "\u{1b}[31m"
    public static let green: String = "\u{1b}[32m"
    public static let yellow: String = "\u{1b}[33m"
    public static let invert: String = "\u{1b}[7m"
    public static let underline: String = "\u{1b}[4m"
    public static let dim: String = "\u{1b}[2m"
    public static let white: String = "\u{1b}[97m"
    public static let reset: String = "\u{1b}[0m"
}

// ========== 前缀样式 ==========

/// 前缀样式
public class PrefixStyle {
    public var msg: String
    public var color: String

    public init(msg: String, color: String) {
        this.msg = msg
        this.color = color
    }
}

public class PrefixStyles {
    public static let inserted: PrefixStyle = PrefixStyle(msg: "+ ", color: DiffColors.red)
    public static let removed: PrefixStyle = PrefixStyle(msg: "- ", color: DiffColors.green)
    public static let equal: PrefixStyle = PrefixStyle(msg: "  ", color: "")
    public static let singleLineInserted: PrefixStyle = PrefixStyle(msg: "Received: ", color: "")
    public static let singleLineRemoved: PrefixStyle = PrefixStyle(msg: "Expected: ", color: "")
}

/// 文本样式
public class Style {
    public var prefix: PrefixStyle
    public var textColor: String

    public init(prefix: PrefixStyle, textColor: String) {
        this.prefix = prefix
        this.textColor = textColor
    }
}

// ========== 基础样式 ==========

public class BaseStyles {
    public static let redBgInserted: Style = Style(prefix: PrefixStyles.inserted, textColor: DiffColors.red + DiffColors.invert)
    public static let greenBgRemoved: Style = Style(prefix: PrefixStyles.removed, textColor: DiffColors.green + DiffColors.invert)
    public static let dimEqual: Style = Style(prefix: PrefixStyles.equal, textColor: DiffColors.dim)
    public static let redFgInserted: Style = Style(prefix: PrefixStyles.inserted, textColor: DiffColors.red)
    public static let greenFgRemoved: Style = Style(prefix: PrefixStyles.removed, textColor: DiffColors.green)
    public static let dimInserted: Style = Style(prefix: PrefixStyles.inserted, textColor: DiffColors.dim)
    public static let dimRemoved: Style = Style(prefix: PrefixStyles.removed, textColor: DiffColors.dim)
}

// ========== 差异配置 ==========

/// 差异打印配置
public class DiffConfig {
    public var minBytesBeforeChunking: UInt64
    public var chunkContextLines: UInt64
    public var enableAnsiColors: Bool
    public var truncateThreshold: UInt64
    public var truncateContext: UInt64

    public init() {
        minBytesBeforeChunking = 2048  // 2KB
        chunkContextLines = 5
        enableAnsiColors = true
        truncateThreshold = 2048  // 2KB
        truncateContext = 100
    }

    public static func `default`(isAgent: Bool, enableAnsiColors: Bool): DiffConfig {
        let config = DiffConfig()
        if isAgent {
            config.minBytesBeforeChunking = 0
            config.chunkContextLines = 1
            config.truncateThreshold = 1024
            config.truncateContext = 50
        }
        config.enableAnsiColors = enableAnsiColors
        return config
    }
}

/// 差异段模式
public enum DiffSegmentMode {
    case equal
    case removed
    case inserted
    case modified
}

/// 差异段
public class DiffSegment {
    public var removed: String
    public var inserted: String
    public var mode: DiffSegmentMode
    public var removedLineCount: UInt64 = 0
    public var insertedLineCount: UInt64 = 0
    public var skip: Bool = false

    public init(removed: String, inserted: String, mode: DiffSegmentMode) {
        this.removed = removed
        this.inserted = inserted
        this.mode = mode
    }
}

/// 修改段样式选项
public class ModifiedStyle {
    public var singleLine: Bool
    public init(singleLine: Bool) {
        this.singleLine = singleLine
    }
}

// ========== 打印函数 ==========

/// 移除尾随换行符
func removeTrailingNewline(text: String): String {
    if text.endsWith("\n") {
        return text[0..text.length - 1]
    }
    return text
}

/// 打印差异的主要入口
public func printDiffMain(not: Bool, receivedSlice: String, expectedSlice: String, writer: StringWriter, config: DiffConfig) {
    if not {
        if config.enableAnsiColors {
            writer.write("Expected: not " + DiffColors.red + expectedSlice + DiffColors.reset)
        } else {
            writer.write("Expected: not ${expectedSlice}")
        }
        return
    }

    // 检查是否为单行差异
    if !receivedSlice.contains("\n") && !expectedSlice.contains("\n") {
        let segment = DiffSegment(removed: expectedSlice, inserted: receivedSlice, mode: DiffSegmentMode.modified)
        printModifiedSegment(segment: segment, writer: writer, config: config, modifiedStyle: ModifiedStyle(singleLine: true))
        return
    }

    // 多行差异 - 使用差异算法
    let dmp = DiffMatchPatch()
    let linesToChars = dmp.diffLinesToChars(text1: expectedSlice, text2: receivedSlice)
    var charDiffs = dmp.diff(before: linesToChars.chars1, after: linesToChars.chars2, checkLines: false)
    var diffs = dmp.diffCharsToLines(diffs: charDiffs, lineArray: linesToChars.lineArray)

    var diffSegments = Array<DiffSegment>()
    for diff in diffs {
        if diff.operation == DiffOperation.delete {
            diffSegments.append(DiffSegment(removed: diff.text, inserted: "", mode: DiffSegmentMode.removed))
        } else if diff.operation == DiffOperation.insert {
            if diffSegments.length > 0 && diffSegments[diffSegments.length - 1].mode == DiffSegmentMode.removed {
                diffSegments[diffSegments.length - 1].inserted = diff.text
                diffSegments[diffSegments.length - 1].mode = DiffSegmentMode.modified
            } else {
                diffSegments.append(DiffSegment(removed: "", inserted: diff.text, mode: DiffSegmentMode.inserted))
            }
        } else if diff.operation == DiffOperation.equal {
            diffSegments.append(DiffSegment(removed: diff.text, inserted: diff.text, mode: DiffSegmentMode.equal))
        }
    }

    // 修剪所有段（除最后一个）的尾随换行
    for i in 0..diffSegments.length {
        if i < diffSegments.length - 1 {
            diffSegments[i].removed = removeTrailingNewline(diffSegments[i].removed)
            diffSegments[i].inserted = removeTrailingNewline(diffSegments[i].inserted)
        }
    }

    // 确定是否需要分块
    if expectedSlice.length > config.minBytesBeforeChunking || receivedSlice.length > config.minBytesBeforeChunking {
        var newDiffSegments = Array<DiffSegment>()

        for segment in diffSegments {
            if segment.mode == DiffSegmentMode.equal {
                let lines = segment.removed.split(separator: "\n")
                for line in lines {
                    let seg = DiffSegment(removed: line, inserted: line, mode: DiffSegmentMode.equal)
                    seg.skip = true
                    newDiffSegments.append(seg)
                }
            } else {
                newDiffSegments.append(segment)
            }
        }

        diffSegments = newDiffSegments

        // 正向传递: 取消非等号段之后的段的跳过标记
        for i in 0..diffSegments.length {
            if diffSegments[i].mode != DiffSegmentMode.equal {
                let end = min(i + config.chunkContextLines + 1, diffSegments.length)
                for j in i..end {
                    diffSegments[j].skip = false
                }
            }
        }

        // 反向传递: 取消非等号段之前的段的跳过标记
        var ri = diffSegments.length
        while ri > 0 {
            ri -= 1
            if diffSegments[ri].mode != DiffSegmentMode.equal {
                let start = ri - config.chunkContextLines > 0 ? ri - config.chunkContextLines : 0
                for j in start..ri + 1 {
                    diffSegments[j].skip = false
                }
            }
        }
    }

    // 计算行数
    for segment in diffSegments {
        for ch in segment.removed {
            if ch == '\n' { segment.removedLineCount += 1 }
        }
        segment.removedLineCount += 1

        for ch in segment.inserted {
            if ch == '\n' { segment.insertedLineCount += 1 }
        }
        segment.insertedLineCount += 1
    }

    printDiff(writer: writer, diffSegments: diffSegments, config: config)
}

/// 打印差异
public func printDiff(writer: StringWriter, diffSegments: Array<DiffSegment>, config: DiffConfig) {
    var removedLineNumber: UInt64 = 1
    var insertedLineNumber: UInt64 = 1
    var removedDiffLines: UInt64 = 0
    var insertedDiffLines: UInt64 = 0

    var hasSkippedSegments = false
    for seg in diffSegments {
        if seg.skip {
            hasSkippedSegments = true
            break
        }
    }

    var wasSkipped = false
    for i in 0..diffSegments.length {
        let segment = diffSegments[i]

        if (wasSkipped && !segment.skip) || (hasSkippedSegments && i == 0 && !segment.skip) {
            var originalLineCount: UInt64 = 0
            var changedLineCount: UInt64 = 0
            for j in i..diffSegments.length {
                if diffSegments[j].skip { break }
                originalLineCount += diffSegments[j].removedLineCount
                changedLineCount += diffSegments[j].insertedLineCount
            }
            printHunkHeader(writer: writer, config: config, originalLineNumber: removedLineNumber, originalLineCount: originalLineCount, changedLineNumber: insertedLineNumber, changedLineCount: changedLineCount)
            wasSkipped = false
        }

        match (segment.mode) {
            case DiffSegmentMode.equal => {
                if segment.skip {
                    wasSkipped = true
                } else {
                    printLinePrefix(writer: writer, config: config, prefix: PrefixStyles.equal)
                    printSegment(text: segment.removed, writer: writer, config: config, style: BaseStyles.dimEqual)
                    writer.write("\n")
                }
            }
            case DiffSegmentMode.removed => {
                printLinePrefix(writer: writer, config: config, prefix: PrefixStyles.removed)
                printSegment(text: segment.removed, writer: writer, config: config, style: BaseStyles.greenFgRemoved)
                writer.write("\n")
                removedDiffLines += segment.removedLineCount
            }
            case DiffSegmentMode.inserted => {
                printLinePrefix(writer: writer, config: config, prefix: PrefixStyles.inserted)
                printSegment(text: segment.inserted, writer: writer, config: config, style: BaseStyles.redFgInserted)
                writer.write("\n")
                insertedDiffLines += segment.insertedLineCount
            }
            case DiffSegmentMode.modified => {
                printModifiedSegment(segment: segment, writer: writer, config: config, modifiedStyle: ModifiedStyle(singleLine: false))
                removedDiffLines += segment.removedLineCount
                insertedDiffLines += segment.insertedLineCount
            }
        }

        removedLineNumber += segment.removedLineCount
        insertedLineNumber += segment.insertedLineCount
    }

    writer.write("\n")
    printDiffFooter(writer: writer, config: config, removedDiffLines: removedDiffLines, insertedDiffLines: insertedDiffLines)
}

/// 打印行前缀
func printLinePrefix(writer: StringWriter, config: DiffConfig, prefix: PrefixStyle) {
    if config.enableAnsiColors { writer.write(prefix.color) }
    writer.write(prefix.msg)
    if config.enableAnsiColors { writer.write(DiffColors.reset) }
}

/// 打印截断行
func printTruncatedLine(line: String, writer: StringWriter, config: DiffConfig, style: Style) {
    if line.length <= config.truncateThreshold || line.length <= config.truncateContext * 2 {
        if config.enableAnsiColors { writer.write(style.textColor) }
        writer.write(line)
        if config.enableAnsiColors { writer.write(DiffColors.reset) }
        return
    }

    // 行太长, 截断
    if config.enableAnsiColors { writer.write(style.textColor) }
    writer.write(line[0..config.truncateContext])
    if config.enableAnsiColors { writer.write(DiffColors.reset) }

    if config.enableAnsiColors { writer.write(DiffColors.white) }
    writer.write("... (${line.length - 2 * config.truncateContext} bytes truncated) ...")
    if config.enableAnsiColors { writer.write(DiffColors.reset) }

    if config.enableAnsiColors { writer.write(style.textColor) }
    writer.write(line[line.length - config.truncateContext..])
    if config.enableAnsiColors { writer.write(DiffColors.reset) }
}

/// 打印段
func printSegment(text: String, writer: StringWriter, config: DiffConfig, style: Style) {
    let lines = text.split(separator: "\n")
    if lines.length > 0 {
        printTruncatedLine(lines[0], writer: writer, config: config, style: style)
    }
    for i in 1..lines.length {
        writer.write("\n")
        printLinePrefix(writer: writer, config: config, prefix: style.prefix)
        printTruncatedLine(lines[i], writer: writer, config: config, style: style)
    }
}

/// 打印修改段
func printModifiedSegment(segment: DiffSegment, writer: StringWriter, config: DiffConfig, modifiedStyle: ModifiedStyle) {
    let removedPrefix = modifiedStyle.singleLine ? PrefixStyles.singleLineRemoved : PrefixStyles.removed
    let insertedPrefix = modifiedStyle.singleLine ? PrefixStyles.singleLineInserted : PrefixStyles.inserted

    // 使用字符级差异
    let dmp = DiffMatchPatch()
    var charDiff = dmp.diff(before: segment.removed, after: segment.inserted, checkLines: true)
    charDiff = dmp.cleanupSemantic(diffs: charDiff)

    // 检查差异是否太大(超过2/3被修改)
    var deletedHighlightedLength: UInt64 = 0
    var insertedHighlightedLength: UInt64 = 0
    for item in charDiff {
        match (item.operation) {
            case DiffOperation.delete => deletedHighlightedLength += UInt64(item.text.length)
            case DiffOperation.insert => insertedHighlightedLength += UInt64(item.text.length)
            case DiffOperation.equal => {}
        }
    }

    if (deletedHighlightedLength > 10 && deletedHighlightedLength > UInt64(segment.removed.length) / 3 * 2) ||
       (insertedHighlightedLength > 10 && insertedHighlightedLength > UInt64(segment.inserted.length) / 3 * 2) {
        // 差异太大, 跳过字符级差异
        printModifiedSegmentWithoutDiffDiff(writer: writer, config: config, segment: segment, modifiedStyle: modifiedStyle)
        return
    }

    // 打印删除部分
    printLinePrefix(writer: writer, config: config, prefix: removedPrefix)
    for item in charDiff {
        match (item.operation) {
            case DiffOperation.delete => {
                let onlyHighlightable = shouldHighlightCharAll(text: item.text)
                if onlyHighlightable {
                    printSegment(text: item.text, writer: writer, config: config, style: BaseStyles.greenBgRemoved)
                } else {
                    printSegment(text: item.text, writer: writer, config: config, style: BaseStyles.greenFgRemoved)
                }
            }
            case DiffOperation.insert => {}
            case DiffSegmentMode.equal => {
                printSegment(text: item.text, writer: writer, config: config, style: BaseStyles.dimEqual)
            }
        }
    }
    writer.write("\n")

    // 打印插入部分
    printLinePrefix(writer: writer, config: config, prefix: insertedPrefix)
    for item in charDiff {
        match (item.operation) {
            case DiffOperation.delete => {}
            case DiffOperation.insert => {
                let onlyHighlightable = shouldHighlightCharAll(text: item.text)
                if onlyHighlightable {
                    printSegment(text: item.text, writer: writer, config: config, style: BaseStyles.redBgInserted)
                } else {
                    printSegment(text: item.text, writer: writer, config: config, style: BaseStyles.redFgInserted)
                }
            }
            case DiffOperation.equal => {
                printSegment(text: item.text, writer: writer, config: config, style: BaseStyles.dimInserted)
            }
        }
    }
    if !modifiedStyle.singleLine { writer.write("\n") }
}

/// 无字符级差异的修改段打印
func printModifiedSegmentWithoutDiffDiff(writer: StringWriter, config: DiffConfig, segment: DiffSegment, modifiedStyle: ModifiedStyle) {
    let removedPrefix = modifiedStyle.singleLine ? PrefixStyles.singleLineRemoved : PrefixStyles.removed
    let insertedPrefix = modifiedStyle.singleLine ? PrefixStyles.singleLineInserted : PrefixStyles.inserted

    printLinePrefix(writer: writer, config: config, prefix: removedPrefix)
    printSegment(text: segment.removed, writer: writer, config: config, style: BaseStyles.greenFgRemoved)
    writer.write("\n")
    printLinePrefix(writer: writer, config: config, prefix: insertedPrefix)
    printSegment(text: segment.inserted, writer: writer, config: config, style: BaseStyles.redFgInserted)
    if !modifiedStyle.singleLine { writer.write("\n") }
}

/// 检查是否所有字符都是空白/控制字符
func shouldHighlightCharAll(text: String): Bool {
    for ch in text {
        if ch <= '\u{20}' || ch == '\u{7F}' { continue }
        return false
    }
    return true
}

/// 打印差异页脚
func printDiffFooter(writer: StringWriter, config: DiffConfig, removedDiffLines: UInt64, insertedDiffLines: UInt64) {
    if config.enableAnsiColors { writer.write(BaseStyles.greenFgRemoved.prefix.color) }
    writer.write(BaseStyles.greenFgRemoved.prefix.msg)
    writer.write("Expected")
    writer.write("  ${BaseStyles.greenFgRemoved.prefix.msg}${removedDiffLines}")
    if config.enableAnsiColors { writer.write(DiffColors.reset) }
    writer.write("\n")
    if config.enableAnsiColors { writer.write(BaseStyles.redFgInserted.prefix.color) }
    writer.write(BaseStyles.redFgInserted.prefix.msg)
    writer.write("Received")
    writer.write("  ${BaseStyles.redFgInserted.prefix.msg}${insertedDiffLines}")
    if config.enableAnsiColors { writer.write(DiffColors.reset) }
}

/// 打印块头
func printHunkHeader(writer: StringWriter, config: DiffConfig, originalLineNumber: UInt64, originalLineCount: UInt64, changedLineNumber: UInt64, changedLineCount: UInt64) {
    if config.enableAnsiColors {
        writer.write("${DiffColors.yellow}@@ -${originalLineNumber},${originalLineCount} +${changedLineNumber},${changedLineCount} @@${DiffColors.reset}\n")
    } else {
        writer.write("@@ -${originalLineNumber},${originalLineCount} +${changedLineNumber},${changedLineCount} @@\n")
    }
}
