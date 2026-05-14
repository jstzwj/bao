// bao_core - 日志系统
// 严格翻译自: src/ast/logger.zig (1523L)
//   Bun 的编译器/运行时日志系统
//   包含: Log/Msg/Location/Range/Source 等类型
package bao_core

import bao_collections.*

// ============================================================================
// Kind - 日志消息类型
// 严格翻译自: src/ast/logger.zig:1-41
//   pub const Kind = enum(u8) { err, warn, note, debug, verbose }
// ============================================================================

/// 日志消息类型 - 对应 Bun logger.Kind
public enum LogKind {
    | Error    // err = 0
    | Warning  // warn = 1
    | Note     // note = 2
    | Debug    // debug = 3
    | Verbose  // verbose = 4

    /// 是否应该打印 - 对应 Bun Kind.shouldPrint
    public func shouldPrint(level: LogLevel): Bool {
        match (level) {
            case Error => match (this) {
                case Error | Note => true
                case _ => false
            }
            case Warning => match (this) {
                case Error | Warning | Note => true
                case _ => false
            }
            case Info | Debug => this != Verbose
            case Verbose => true
        }
    }

    /// 类型名称 - 对应 Bun Kind.string
    public func name(): String {
        match (this) {
            case Error => "error"
            case Warning => "warn"
            case Note => "note"
            case Debug => "debug"
            case Verbose => "verbose"
        }
    }
}

/// 日志级别 - 对应 Bun Log.Level
public enum LogLevel {
    | Verbose  // 最低
    | Debug
    | Info
    | Warning
    | Error    // 最高
}

// ============================================================================
// Loc - 位置标记
// 严格翻译自: src/ast/logger.zig:44-71
//   pub const Loc = struct { start: i32 = -1 }
// ============================================================================

/// 位置标记 - 对应 Bun logger.Loc
/// start = -1 表示空位置
public class Loc {
    public var start: Int32

    /// 空位置 - 对应 Bun Loc.Empty
    public static let EMPTY = Loc(-1)

    public init(start: Int32) {
        this.start = start
    }

    public init() {
        this.start = -1
    }

    /// 转为 usize - 对应 Bun Loc.toUsize
    public func toIndex(): Int64 {
        return if (start < 0) { 0 } else { Int64(start) }
    }

    /// 是否为空 - 对应 Bun Loc.isEmpty
    public func isEmpty(): Bool {
        return start == -1
    }

    /// 相等 - 对应 Bun Loc.eql
    public func eql(other: Loc): Bool {
        return start == other.start
    }
}

// ============================================================================
// Range - 源码范围
// 严格翻译自: src/ast/logger.zig Range
// ============================================================================

/// 源码范围 - 对应 Bun logger.Range
public class Range {
    public var loc: Loc
    public var length: Int32

    /// 空范围
    public static let EMPTY = Range(Loc.EMPTY, 0)

    public init(loc: Loc, length: Int32) {
        this.loc = loc
        this.length = length
    }

    public init() {
        this.loc = Loc.EMPTY
        this.length = 0
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return loc.isEmpty() && length == 0
    }
}

// ============================================================================
// Location - 完整源码位置
// 严格翻译自: src/ast/logger.zig:73-160
//   pub const Location = struct {
//       file: string,
//       namespace: string = "file",
//       line_text: ?string = null,
//       length: usize = 0,
//       offset: usize = 0,
//       line: i32,
//       column: i32,
//   }
// ============================================================================

/// 完整源码位置 - 对应 Bun logger.Location
public class SourceLocation {
    /// 文件路径
    public var file: String
    /// 命名空间 (默认 "file")
    public var namespace: String
    /// 当前行文本
    public var lineText: ?String
    /// 高亮长度
    public var length: Int64
    /// 字节偏移
    public var offset: Int64
    /// 行号 (1-based, <= 0 表示无行信息)
    public var line: Int32
    /// 列号 (0-based, 字节偏移)
    public var column: Int32

    public init(file: String, line: Int32, column: Int32) {
        this.file = file
        this.namespace = "file"
        this.lineText = None
        this.length = 0
        this.offset = 0
        this.line = line
        this.column = column
    }

    public init(file: String, namespace: String, line: Int32, column: Int32,
                offset: Int64, length: Int64, lineText: ?String) {
        this.file = file
        this.namespace = namespace
        this.lineText = lineText
        this.length = length
        this.offset = offset
        this.line = line
        this.column = column
    }

    /// 格式化为字符串
    public func toString(): String {
        if (line > 0) {
            return "${file}:${line}:${column}"
        }
        return file
    }
}

// ============================================================================
// MsgData - 日志消息数据
// 严格翻译自: src/ast/logger.zig Data
// ============================================================================

/// 日志消息数据 - 对应 Bun logger.Data
public class MsgData {
    /// 消息文本
    public var text: String
    /// 源码位置 (可选)
    public var location: ?SourceLocation
    /// 源码范围 (可选)
    public var range: ?Range

    public init(text: String) {
        this.text = text
        this.location = None
        this.range = None
    }

    public init(text: String, location: SourceLocation) {
        this.text = text
        this.location = Some(location)
        this.range = None
    }

    public init(text: String, location: ?SourceLocation, range: ?Range) {
        this.text = text
        this.location = location
        this.range = range
    }
}

// ============================================================================
// Msg - 日志消息
// 严格翻译自: src/ast/logger.zig Msg
//   pub const Msg = struct {
//       kind: Kind,
//       data: Data,
//       notes: []const Note,
//       ...
//   }
// ============================================================================

/// 日志消息 - 对应 Bun logger.Msg
public class LogMsg {
    /// 消息类型
    public var kind: LogKind
    /// 消息数据
    public var data: MsgData
    /// 附加注释
    public var notes: ArrayList<MsgData>
    /// 错误码 (可选)
    public var code: ?String

    public init(kind: LogKind, data: MsgData) {
        this.kind = kind
        this.data = data
        this.notes = ArrayList<MsgData>()
        this.code = None
    }

    public init(kind: LogKind, text: String) {
        this.kind = kind
        this.data = MsgData(text)
        this.notes = ArrayList<MsgData>()
        this.code = None
    }

    /// 添加注释 - 对应 Bun Msg 带注释
    public func addNote(note: MsgData): Unit {
        notes.append(note)
    }

    /// 格式化输出
    public func toString(): String {
        var sb = StringBuilder()
        match (kind) {
            case Error => sb.append("error: ")
            case Warning => sb.append("warn: ")
            case Note => sb.append("note: ")
            case Debug => sb.append("debug: ")
            case Verbose => sb.append("verbose: ")
        }
        match (code) {
            case Some(c) => sb.append("[${c}] ")
            case None => ()
        }
        sb.append(data.text)
        match (data.location) {
            case Some(loc) => sb.append("\n  at ${loc.toString()}")
            case None => ()
        }
        for (note in notes) {
            sb.append("\n  note: ${note.text}")
        }
        return sb.toString()
    }
}

// ============================================================================
// Log - 日志收集器
// 严格翻译自: src/ast/logger.zig Log
//   pub const Log = struct {
//       msgs: ArrayList(Msg),
//       errors: u32 = 0,
//       warnings: u32 = 0,
//       ...
//   }
// ============================================================================

/// 日志收集器 - 对应 Bun logger.Log
/// 收集编译/运行时过程中的所有日志消息
public class Log {
    /// 所有消息
    public var msgs: ArrayList<LogMsg>
    /// 错误计数
    public var errors: Int32
    /// 警告计数
    public var warnings: Int32

    public init() {
        msgs = ArrayList<LogMsg>()
        errors = 0
        warnings = 0
    }

    /// 添加错误 - 对应 Bun Log.addError
    public func addError(source: ?SourceLocation, text: String): Unit {
        let data = MsgData(text, source)
        msgs.append(LogMsg(LogKind.Error, data))
        errors += 1
    }

    /// 添加错误 (带范围)
    public func addRangeError(range: Range, text: String): Unit {
        let data = MsgData(text, None, Some(range))
        msgs.append(LogMsg(LogKind.Error, data))
        errors += 1
    }

    /// 添加警告 - 对应 Bun Log.addWarning
    public func addWarning(source: ?SourceLocation, text: String): Unit {
        let data = MsgData(text, source)
        msgs.append(LogMsg(LogKind.Warning, data))
        warnings += 1
    }

    /// 添加调试信息 - 对应 Bun Log.addDebug
    public func addDebug(text: String): Unit {
        msgs.append(LogMsg(LogKind.Debug, text))
    }

    /// 添加注释 - 对应 Bun Log.addNote
    public func addNote(text: String): Unit {
        msgs.append(LogMsg(LogKind.Note, text))
    }

    /// 是否有错误
    public func hasErrors(): Bool {
        return errors > 0
    }

    /// 是否有警告
    public func hasWarnings(): Bool {
        return warnings > 0
    }

    /// 总消息数
    public func count(): Int64 {
        return msgs.size
    }

    /// 打印所有消息 - 对应 Bun Log.print
    public func print(): Unit {
        for (msg in msgs) {
            println(msg.toString())
        }
    }

    /// 打印到字符串
    public func printToString(): String {
        var sb = StringBuilder()
        for (msg in msgs) {
            sb.append(msg.toString())
            sb.append("\n")
        }
        return sb.toString()
    }

    /// 清空 - 对应 Bun Log.clear
    public func clear(): Unit {
        msgs.clear()
        errors = 0
        warnings = 0
    }

    /// 几乎为空 (只有注释) - 对应 Bun Log.almostEmpty
    public func almostEmpty(): Bool {
        return errors == 0 && warnings == 0
    }

    /// 添加模块解析错误 - 对应 Bun Log.addResolveError
    public func addResolveError(importer: String, specifier: String, reason: String): Unit {
        addError(Some(SourceLocation(importer, 0, 0)),
            "Could not resolve \"${specifier}\" from \"${importer}\": ${reason}")
    }

    /// 添加符号重复声明错误 - 对应 Bun Log.addSymbolAlreadyDeclaredError
    public func addSymbolAlreadyDeclaredError(name: String, originalLoc: ?SourceLocation): Unit {
        addError(originalLoc, "\"${name}\" has already been declared")
    }

    // ========================================================================
    // 更多日志方法 - 严格翻译自: src/ast/logger.zig:671-900
    // ========================================================================

    /// 添加带位置和范围的错误 - 对应 Bun Log.addFormattedMsg(.err, ...)
    /// 严格翻译自: logger.zig:792-816 addFormattedMsg
    public func addRangeErrorFmt(source: ?SourceLocation, text: String, range: ?Range): Unit {
        let data = MsgData(text, source, range)
        let msg = LogMsg(LogKind.Error, data)
        msgs.append(msg)
        errors += 1
    }

    /// 添加带位置的警告 - 对应 Bun Log.addWarningFmt
    /// 严格翻译自: logger.zig addFormattedMsg(.warn, ...)
    public func addRangeWarningFmt(source: ?SourceLocation, text: String, range: ?Range): Unit {
        let data = MsgData(text, source, range)
        let msg = LogMsg(LogKind.Warning, data)
        msgs.append(msg)
        warnings += 1
    }

    /// 添加 verbose 日志 - 对应 Bun Log.addVerbose
    /// 严格翻译自: logger.zig:676-684
    public func addVerbose(source: ?SourceLocation, text: String): Unit {
        let data = MsgData(text, source)
        msgs.append(LogMsg(LogKind.Verbose, data))
    }

    /// 添加带注释的 verbose 日志 - 对应 Bun Log.addVerboseWithNotes
    /// 严格翻译自: logger.zig:770-779
    public func addVerboseWithNotes(source: ?SourceLocation, text: String, notes: ArrayList<MsgData>): Unit {
        let data = MsgData(text, source)
        let msg = LogMsg(LogKind.Verbose, data)
        for (note in notes) {
            msg.addNote(note)
        }
        msgs.append(msg)
    }

    /// 添加带注释的错误 - 对应 Bun Log 中带 notes 的错误
    public func addErrorWithNotes(source: ?SourceLocation, text: String, notes: ArrayList<MsgData>): Unit {
        let data = MsgData(text, source)
        let msg = LogMsg(LogKind.Error, data)
        for (note in notes) {
            msg.addNote(note)
        }
        msgs.append(msg)
        errors += 1
    }

    /// 克隆到另一个 Log - 对应 Bun Log.cloneTo
    /// 严格翻译自: logger.zig:690-716
    public func cloneTo(other: Log): Unit {
        for (msg in msgs) {
            other.msgs.append(msg)
        }
        other.warnings += warnings
        other.errors += errors
    }

    /// 追加到另一个 Log 并清空自身 - 对应 Bun Log.appendTo
    /// 严格翻译自: logger.zig:718-721
    public func appendTo(other: Log): Unit {
        cloneTo(other)
        clear()
    }

    /// 是否有任何消息 (错误或警告) - 对应 Bun Log.hasAny
    /// 严格翻译自: logger.zig:608-610
    public func hasAny(): Bool {
        return (warnings + errors) > 0
    }

    /// 获取日志级别 - 对应 Bun Log.Level
    /// 严格翻译自: logger.zig:627-656
    public func shouldPrint(kind: LogKind, level: LogLevel): Bool {
        return kind.shouldPrint(level)
    }
}
