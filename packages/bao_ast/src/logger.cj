// bao_ast - AST 日志系统
// 严格翻译自: src/ast/logger.zig (1523L)
//   Kind - 日志消息类型 (err, warn, note, debug, verbose)
//   Loc - 源码位置 (start: i32)
//   Location - 完整源码位置 (file, line, column, line_text)
//   Range - 源码范围 (loc + len)
//   Data - 消息数据 (text + location)
//   Msg - 日志消息 (kind + data + notes)
//   Log - 日志收集器 (msgs, errors, warnings)
//   Source - 源文件 (path, contents, index)
//
// 注意: bao_core/logger.cj 已包含基础日志类型 (LogKind, LogLevel, Loc, Range,
//       SourceLocation, MsgData, LogMsg, Log)
// 本文件补充 AST 特定的日志类型，与 bao_core/logger.cj 配合使用
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// ASTLogKind - AST 日志消息类型
// 严格翻译自: src/ast/logger.zig:1-41
//   pub const Kind = enum(u8) { err = 0, warn = 1, note = 2, debug = 3, verbose = 4 }
// 注意: 本文件使用 ASTLogKind 以避免与 bao_core.LogKind 冲突
// ============================================================================

/// AST 日志消息类型 - 对应 Bun logger.Kind
/// Bun: pub const Kind = enum(u8) { err, warn, note, debug, verbose }
public enum ASTLogKind {
    | Error    // err = 0
    | Warning  // warn = 1
    | Note     // note = 2
    | Debug    // debug = 3
    | Verbose  // verbose = 4

    /// 是否应该打印 - 对应 Bun Kind.shouldPrint()
    /// Bun: pub inline fn shouldPrint(this: Kind, other: Log.Level) bool
    public func shouldPrint(level: ASTLogLevel): Bool {
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

    /// 类型名称 - 对应 Bun Kind.string()
    /// Bun: pub inline fn string(self: Kind) []const u8
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

/// AST 日志级别 - 对应 Bun Log.Level
/// Bun: pub const Level = enum(i8) { verbose, debug, info, warn, err }
public enum ASTLogLevel {
    | Verbose  // 0 - 最低
    | Debug    // 1
    | Info     // 2
    | Warning  // 3
    | Error    // 4 - 最高

    /// 是否至少达到指定级别 - 对应 Bun Level.atLeast()
    /// Bun: pub fn atLeast(this: Level, other: Level) bool
    public func atLeast(other: ASTLogLevel): Bool {
        return ordinal() <= other.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case Verbose => 0
            case Debug => 1
            case Info => 2
            case Warning => 3
            case Error => 4
        }
    }
}

// ============================================================================
// ASTLoc - AST 源码位置标记
// 严格翻译自: src/ast/logger.zig:44-71
//   pub const Loc = struct { start: i32 = -1 }
// 注意: 使用 ASTLoc 以与 bao_core.Loc 区分
// ============================================================================

/// AST 源码位置 - 对应 Bun logger.Loc
/// Bun: pub const Loc = struct { start: i32 = -1 }
/// start 为字节偏移，-1 表示空位置
/// 不要标记为 packed struct（Bun 源码中有明确注释）
public class ASTLoc {
    /// 字节偏移 - 对应 Bun Loc.start: i32
    public var start: Int32

    /// 空位置 - 对应 Bun Loc.Empty = Loc{ .start = -1 }
    public static let EMPTY: ASTLoc = ASTLoc(-1)

    public init(start: Int32) {
        this.start = start
    }

    public init() {
        this.start = -1
    }

    /// 转为可空 - 对应 Bun Loc.toNullable()
    /// Bun: pub inline fn toNullable(loc: Loc) ?Loc
    public func toNullable(): ?ASTLoc {
        return if (start == -1) { None } else { Some(this) }
    }

    /// 转为 usize 索引 - 对应 Bun Loc.i() / Loc.toUsize
    /// Bun: pub inline fn i(self: *const Loc) usize
    public func i(): Int64 {
        return if (start < 0) { Int64(0) } else { Int64(start) }
    }

    /// 是否为空 - 对应 Bun Loc.isEmpty()
    /// Bun: pub inline fn isEmpty(this: Loc) bool
    public func isEmpty(): Bool {
        return start == EMPTY.start
    }

    /// 相等比较 - 对应 Bun Loc.eql()
    public func eql(other: ASTLoc): Bool {
        return start == other.start
    }
}

// ============================================================================
// ASTRange - AST 源码范围
// 严格翻译自: src/ast/logger.zig:546-578
//   pub const Range = struct { loc: Loc = Loc.Empty, len: i32 = 0 }
// ============================================================================

/// AST 源码范围 - 对应 Bun logger.Range
/// Bun: pub const Range = struct { loc: Loc = Loc.Empty, len: i32 = 0 }
/// 不要标记为 packed struct（Bun 源码中有明确注释）
public class ASTRange {
    /// 起始位置 - 对应 Bun Range.loc
    public var loc: ASTLoc
    /// 长度 - 对应 Bun Range.len
    public var len: Int32

    /// 空范围 - 对应 Bun Range.none
    public static let NONE: ASTRange = ASTRange()

    /// 已弃用: 使用 .none
    /// Bun: pub const None = none;
    public static let EMPTY: ASTRange = ASTRange()

    public init() {
        this.loc = ASTLoc.EMPTY
        this.len = 0
    }

    public init(loc: ASTLoc, len: Int32) {
        this.loc = loc
        this.len = len
    }

    public init(start: Int32, len: Int32) {
        this.loc = ASTLoc(start)
        this.len = len
    }

    /// 获取范围内的文本 - 对应 Bun Range.in()
    /// Bun: pub fn in(this: Range, buf: []const u8) []const u8
    public func inBuf(buf: String): String {
        if (loc.start < 0 || len <= 0) {
            return ""
        }
        let s = Int64(loc.start)
        let end = if (s + Int64(len) > buf.size) { buf.size } else { s + Int64(len) }
        if (s >= buf.size) {
            return ""
        }
        return buf[Int64(s)..Int64(end)]
    }

    /// 是否包含偏移 - 对应 Bun Range.contains()
    /// Bun: pub fn contains(this: Range, k: i32) bool
    public func contains(k: Int32): Bool {
        return k >= loc.start && k < loc.start + len
    }

    /// 是否为空 - 对应 Bun Range.isEmpty()
    public func isEmpty(): Bool {
        return len == 0 && loc.start == ASTLoc.EMPTY.start
    }

    /// 结束位置 - 对应 Bun Range.end()
    /// Bun: pub fn end(self: *const Range) Loc
    public func end(): ASTLoc {
        return ASTLoc(loc.start + len)
    }

    /// 结束位置 (usize) - 对应 Bun Range.endI()
    public func endI(): Int64 {
        return Int64(loc.start + len)
    }
}

// ============================================================================
// ASTLocation - AST 完整源码位置
// 严格翻译自: src/ast/logger.zig:73-194
//   pub const Location = struct {
//       file: string, namespace: string = "file",
//       line_text: ?string = null, length: usize = 0, offset: usize = 0,
//       line: i32, column: i32
//   }
// 字段排序已优化以减少填充
// ============================================================================

/// AST 完整源码位置 - 对应 Bun logger.Location
/// Bun: pub const Location = struct { file, namespace, line_text, length, offset, line, column }
public class ASTLocation {
    /// 文件路径 - 对应 Bun Location.file: string
    public var file: String
    /// 命名空间 (默认 "file") - 对应 Bun Location.namespace
    public var namespace: String
    /// 当前行文本 - 对应 Bun Location.line_text: ?string
    /// 避免重新获取源代码
    public var lineText: ?String
    /// 高亮长度 - 对应 Bun Location.length: usize
    /// 0 表示仅指向单个字符
    public var length: Int64
    /// 字节偏移 - 对应 Bun Location.offset: usize
    public var offset: Int64
    /// 行号 (1-based) - 对应 Bun Location.line: i32
    /// Line <= 0 表示没有行和列信息
    public var line: Int32
    /// 列号 (0-based, 字节偏移) - 对应 Bun Location.column: i32
    public var column: Int32

    public init() {
        this.file = ""
        this.namespace = "file"
        this.lineText = None
        this.length = 0
        this.offset = 0
        this.line = -1
        this.column = -1
    }

    public init(file: String, namespace: String, line: Int32, column: Int32,
                length: Int64, offset: Int64, lineText: ?String) {
        this.file = file
        this.namespace = namespace
        this.line = line
        this.column = column
        this.length = length
        this.offset = offset
        this.lineText = lineText
    }

    public init(file: String, line: Int32, column: Int32) {
        this.file = file
        this.namespace = "file"
        this.line = line
        this.column = column
        this.lineText = None
        this.length = 0
        this.offset = 0
    }

    /// 格式化为字符串
    public func toString(): String {
        if (line > 0 && column >= 0) {
            return "${file}:${line}:${column}"
        } else if (line > 0) {
            return "${file}:${line}"
        }
        return file
    }
}

// ============================================================================
// ASTMsgData - AST 消息数据
// 严格翻译自: src/ast/logger.zig:196-369
//   pub const Data = struct { text: string, location: ?Location = null }
// ============================================================================

/// AST 消息数据 - 对应 Bun logger.Data
/// Bun: pub const Data = struct { text: string, location: ?Location = null }
public class ASTMsgData {
    /// 消息文本 - 对应 Bun Data.text: string
    public var text: String
    /// 源码位置 - 对应 Bun Data.location: ?Location
    public var location: ?ASTLocation

    public init(text: String) {
        this.text = text
        this.location = None
    }

    public init(text: String, location: ?ASTLocation) {
        this.text = text
        this.location = location
    }

    /// 格式化输出 - 对应 Bun Data.writeFormat()
    /// Bun: pub fn writeFormat(this, to, kind, redact_sensitive_information, enable_ansi_colors)
    public func toString(): String {
        match (location) {
            case Some(loc) =>
                return "${text}\n  at ${loc.toString()}"
            case None =>
                return text
        }
    }
}

// ============================================================================
// BabyString - 轻量字符串引用
// 严格翻译自: src/ast/logger.zig:371-385
//   pub const BabyString = packed struct(u32) { offset: u16, len: u16 }
// ============================================================================

/// 轻量字符串引用 - 对应 Bun BabyString
/// Bun: pub const BabyString = packed struct(u32) { offset: u16, len: u16 }
/// 用于在父字符串中存储子字符串的偏移和长度
public class BabyString {
    /// 偏移 - 对应 Bun BabyString.offset: u16
    public var offset: UInt16
    /// 长度 - 对应 Bun BabyString.len: u16
    public var length: UInt16

    public init(offset: UInt16, length: UInt16) {
        this.offset = offset
        this.length = length
    }

    /// 在父字符串中查找子字符串 - 对应 Bun BabyString.in()
    /// Bun: pub fn in(parent: string, text: string) BabyString
    public static func inParent(parent: String, text: String): BabyString {
        let idx = parent.indexOf(text)
        if (idx >= 0) {
            return BabyString(UInt16(idx), UInt16(text.size))
        }
        return BabyString(UInt16(0), UInt16(0))
    }

    /// 获取切片 - 对应 Bun BabyString.slice()
    /// Bun: pub fn slice(this: BabyString, container: string) string
    public func slice(container: String): String {
        let s = Int64(offset)
        let e = Int64(offset) + Int64(length)
        if (s >= container.size || e > container.size) {
            return ""
        }
        return container[s..e]
    }
}

// ============================================================================
// ASTMsg - AST 日志消息
// 严格翻译自: src/ast/logger.zig:387-542
//   pub const Msg = struct {
//       kind: Kind = Kind.err,
//       data: Data,
//       notes: []Data = &.{},
//       redact_sensitive_information: bool = false,
//   }
// ============================================================================

/// AST 日志消息元数据 - 对应 Bun Msg.Metadata
/// Bun: pub const Metadata = union(enum) { build, resolve: Resolve }
public class ASTMsgMetadata {
    /// 是否为构建消息
    public var isBuild: Bool
    /// 解析相关数据 (如果是 resolve 类型)
    public var resolveSpecifier: ?BabyString
    /// 导入类型
    public var importKind: Int64
    /// 错误
    public var errorName: ?String

    public init() {
        this.isBuild = true
        this.resolveSpecifier = None
        this.importKind = 0
        this.errorName = None
    }

    /// 创建构建类型元数据
    public static func build(): ASTMsgMetadata {
        let m = ASTMsgMetadata()
        m.isBuild = true
        return m
    }

    /// 创建解析类型元数据
    public static func resolve(specifier: BabyString, importKind: Int64): ASTMsgMetadata {
        let m = ASTMsgMetadata()
        m.isBuild = false
        m.resolveSpecifier = Some(specifier)
        m.importKind = importKind
        m.errorName = Some("ModuleNotFound")
        return m
    }
}

/// AST 日志消息 - 对应 Bun logger.Msg
/// Bun: pub const Msg = struct { kind, data, metadata, notes, redact_sensitive_information }
public class ASTMsg {
    /// 消息类型 - 对应 Bun Msg.kind: Kind
    public var kind: ASTLogKind
    /// 消息数据 - 对应 Bun Msg.data: Data
    public var data: ASTMsgData
    /// 元数据 - 对应 Bun Msg.metadata: Metadata
    public var metadata: ASTMsgMetadata
    /// 附加注释 - 对应 Bun Msg.notes: []Data
    public var notes: ArrayList<ASTMsgData>
    /// 是否遮盖敏感信息 - 对应 Bun Msg.redact_sensitive_information
    public var redactSensitiveInfo: Bool

    public init(kind: ASTLogKind, data: ASTMsgData) {
        this.kind = kind
        this.data = data
        this.metadata = ASTMsgMetadata.build()
        this.notes = ArrayList<ASTMsgData>()
        this.redactSensitiveInfo = false
    }

    public init(kind: ASTLogKind, data: ASTMsgData, notes: ArrayList<ASTMsgData>) {
        this.kind = kind
        this.data = data
        this.metadata = ASTMsgMetadata.build()
        this.notes = notes
        this.redactSensitiveInfo = false
    }

    /// 克隆 - 对应 Bun Msg.clone()
    /// Bun: pub fn clone(this: *const Msg, allocator: std.mem.Allocator) OOM!Msg
    public func clone(): ASTMsg {
        let msg = ASTMsg(kind, data)
        msg.metadata = metadata
        msg.redactSensitiveInfo = redactSensitiveInfo
        for (note in notes) {
            msg.notes.append(note)
        }
        return msg
    }

    /// 添加注释
    public func addNote(note: ASTMsgData): Unit {
        notes.append(note)
    }

    /// 格式化输出 - 对应 Bun Msg.writeFormat()
    public func toString(): String {
        var sb = StringBuilder()
        sb.append(kind.name())
        sb.append(": ")
        sb.append(data.toString())
        for (note in notes) {
            sb.append("\n\n")
            sb.append(ASTLogKind.Note.name())
            sb.append(": ")
            sb.append(note.toString())
        }
        return sb.toString()
    }
}

// ============================================================================
// ASTLog - AST 日志收集器
// 严格翻译自: src/ast/logger.zig:580-1250
//   pub const Log = struct {
//       warnings: u32 = 0,
//       errors: u32 = 0,
//       msgs: std.array_list.Managed(Msg),
//       level: Level = ...,
//       clone_line_text: bool = false,
//   }
// ============================================================================

/// AST 日志收集器 - 对应 Bun logger.Log
/// Bun: pub const Log = struct { msgs, errors, warnings, level, clone_line_text }
/// 收集 AST 编译过程中的所有日志消息
public class ASTLog {
    /// 警告计数 - 对应 Bun Log.warnings: u32
    public var warnings: Int32
    /// 错误计数 - 对应 Bun Log.errors: u32
    public var errors: Int32
    /// 所有消息 - 对应 Bun Log.msgs: std.array_list.Managed(Msg)
    public var msgs: ArrayList<ASTMsg>
    /// 日志级别 - 对应 Bun Log.level: Level
    public var level: ASTLogLevel
    /// 是否克隆行文本 - 对应 Bun Log.clone_line_text
    public var cloneLineText: Bool

    /// 默认日志级别 - 对应 Bun Log.default_log_level
    public static var defaultLogLevel: ASTLogLevel = ASTLogLevel.Warning

    public init() {
        msgs = ArrayList<ASTMsg>()
        warnings = 0
        errors = 0
        level = defaultLogLevel
        cloneLineText = false
    }

    /// 是否有错误 - 对应 Bun Log.hasErrors()
    /// Bun: pub inline fn hasErrors(this: *const Log) bool
    public func hasErrors(): Bool {
        return errors > 0
    }

    /// 是否有任何消息 (错误或警告) - 对应 Bun Log.hasAny()
    /// Bun: pub fn hasAny(this: *const Log) bool
    public func hasAny(): Bool {
        return (warnings + errors) > 0
    }

    /// 重置 - 对应 Bun Log.reset()
    /// Bun: pub fn reset(this: *Log) void
    public func reset(): Unit {
        msgs.clear()
        warnings = 0
        errors = 0
    }

    /// 添加消息 - 对应 Bun Log.addMsg()
    /// Bun: pub fn addMsg(self: *Log, msg: Msg) OOM!void
    public func addMsg(msg: ASTMsg): Unit {
        msgs.append(msg)
    }

    /// 添加错误 - 对应 Bun Log.addError()
    /// Bun: pub fn addError(self: *Log, _source: ?*const Source, loc: Loc, text: string)
    public func addError(source: ?ASTLocation, loc: ASTLoc, text: String): Unit {
        errors += 1
        let data = ASTMsgData(text, source)
        let msg = ASTMsg(ASTLogKind.Error, data)
        msgs.append(msg)
    }

    /// 添加错误 (直接文本) - 对应 Bun Log.addError() 简化版
    public func addErrorText(text: String): Unit {
        errors += 1
        msgs.append(ASTMsg(ASTLogKind.Error, ASTMsgData(text)))
    }

    /// 添加范围错误 - 对应 Bun Log.addRangeError()
    /// Bun: pub fn addRangeError(log: *Log, source: ?*const Source, r: Range, text: string)
    public func addRangeError(source: ?ASTLocation, range: ASTRange, text: String): Unit {
        errors += 1
        let data = ASTMsgData(text, source)
        msgs.append(ASTMsg(ASTLogKind.Error, data))
    }

    /// 添加警告 - 对应 Bun Log.addWarning()
    /// Bun: pub fn addWarning(log: *Log, source: ?*const Source, l: Loc, text: string)
    public func addWarning(source: ?ASTLocation, loc: ASTLoc, text: String): Unit {
        if (!ASTLogKind.Warning.shouldPrint(level)) {
            return
        }
        warnings += 1
        let data = ASTMsgData(text, source)
        msgs.append(ASTMsg(ASTLogKind.Warning, data))
    }

    /// 添加警告 (直接文本)
    public func addWarningText(text: String): Unit {
        if (!ASTLogKind.Warning.shouldPrint(level)) {
            return
        }
        warnings += 1
        msgs.append(ASTMsg(ASTLogKind.Warning, ASTMsgData(text)))
    }

    /// 添加范围警告 - 对应 Bun Log.addRangeWarning()
    public func addRangeWarning(source: ?ASTLocation, range: ASTRange, text: String): Unit {
        if (!ASTLogKind.Warning.shouldPrint(level)) {
            return
        }
        warnings += 1
        let data = ASTMsgData(text, source)
        msgs.append(ASTMsg(ASTLogKind.Warning, data))
    }

    /// 添加 verbose 日志 - 对应 Bun Log.addVerbose()
    /// Bun: pub fn addVerbose(log: *Log, source: ?*const Source, loc: Loc, text: string)
    public func addVerbose(source: ?ASTLocation, loc: ASTLoc, text: String): Unit {
        if (!ASTLogKind.Verbose.shouldPrint(level)) {
            return
        }
        let data = ASTMsgData(text, source)
        msgs.append(ASTMsg(ASTLogKind.Verbose, data))
    }

    /// 添加带注释的 verbose 日志 - 对应 Bun Log.addVerboseWithNotes()
    public func addVerboseWithNotes(source: ?ASTLocation, loc: ASTLoc,
                                     text: String, notes: ArrayList<ASTMsgData>): Unit {
        if (!ASTLogKind.Verbose.shouldPrint(level)) {
            return
        }
        let data = ASTMsgData(text, source)
        let msg = ASTMsg(ASTLogKind.Verbose, data, notes)
        msgs.append(msg)
    }

    /// 添加调试日志 - 对应 Bun Log.addRangeDebug()
    public func addDebug(source: ?ASTLocation, range: ASTRange, text: String): Unit {
        if (!ASTLogKind.Debug.shouldPrint(level)) {
            return
        }
        let data = ASTMsgData(text, source)
        msgs.append(ASTMsg(ASTLogKind.Debug, data))
    }

    /// 添加带注释的范围错误 - 对应 Bun Log.addRangeErrorWithNotes()
    public func addRangeErrorWithNotes(source: ?ASTLocation, range: ASTRange,
                                        text: String, notes: ArrayList<ASTMsgData>): Unit {
        errors += 1
        let data = ASTMsgData(text, source)
        msgs.append(ASTMsg(ASTLogKind.Error, data, notes))
    }

    /// 添加带注释的范围警告 - 对应 Bun Log.addRangeWarningWithNotes()
    public func addRangeWarningWithNotes(source: ?ASTLocation, range: ASTRange,
                                          text: String, notes: ArrayList<ASTMsgData>): Unit {
        if (!ASTLogKind.Warning.shouldPrint(level)) {
            return
        }
        warnings += 1
        let data = ASTMsgData(text, source)
        msgs.append(ASTMsg(ASTLogKind.Warning, data, notes))
    }

    /// 添加带注释的调试日志 - 对应 Bun Log.addRangeDebugWithNotes()
    public func addRangeDebugWithNotes(source: ?ASTLocation, range: ASTRange,
                                        text: String, notes: ArrayList<ASTMsgData>): Unit {
        if (!ASTLogKind.Debug.shouldPrint(level)) {
            return
        }
        let data = ASTMsgData(text, source)
        msgs.append(ASTMsg(ASTLogKind.Debug, data, notes))
    }

    /// 添加符号重复声明错误 - 对应 Bun Log.addSymbolAlreadyDeclaredError()
    /// Bun: pub fn addSymbolAlreadyDeclaredError(self, allocator, source, name, new_loc, old_loc)
    public func addSymbolAlreadyDeclaredError(
        source: ?ASTLocation, name: String, newLoc: ASTLoc, oldLoc: ASTLoc): Unit {
        errors += 1
        let notes = ArrayList<ASTMsgData>()
        notes.append(ASTMsgData("\"${name}\" was originally declared here"))
        let msg = ASTMsg(
            ASTLogKind.Error,
            ASTMsgData("\"${name}\" has already been declared", source),
            notes
        )
        msgs.append(msg)
    }

    /// 克隆到另一个日志 - 对应 Bun Log.cloneTo()
    /// Bun: pub fn cloneTo(self: *Log, other: *Log) OOM!void
    public func cloneTo(other: ASTLog): Unit {
        for (msg in msgs) {
            other.msgs.append(msg)
        }
        other.warnings += warnings
        other.errors += errors
    }

    /// 追加到另一个日志并清空自身 - 对应 Bun Log.appendTo()
    /// Bun: pub fn appendTo(self: *Log, other: *Log) OOM!void
    public func appendTo(other: ASTLog): Unit {
        cloneTo(other)
        msgs.clear()
    }

    /// 清空并释放 - 对应 Bun Log.clearAndFree() / Log.deinit()
    /// Bun: pub fn deinit(log: *Log) void
    public func clearAndFree(): Unit {
        msgs.clear()
    }

    /// 打印所有消息 - 对应 Bun Log.print()
    /// Bun: 先打印警告，再打印错误
    public func printMessages(): String {
        var sb = StringBuilder()
        // 警告在前，错误在后
        if (warnings > 0 && errors > 0) {
            for (msg in msgs) {
                if (msg.kind != ASTLogKind.Error) {
                    if (msg.kind.shouldPrint(level)) {
                        sb.append(msg.toString())
                        sb.append("\n\n")
                    }
                }
            }
            for (msg in msgs) {
                if (msg.kind == ASTLogKind.Error) {
                    if (msg.kind.shouldPrint(level)) {
                        sb.append(msg.toString())
                        sb.append("\n\n")
                    }
                }
            }
        } else {
            for (msg in msgs) {
                if (msg.kind.shouldPrint(level)) {
                    sb.append(msg.toString())
                    sb.append("\n\n")
                }
            }
        }
        return sb.toString()
    }
}

// ============================================================================
// ASTSource - AST 源文件
// 严格翻译自: src/ast/logger.zig:1255-1502
//   pub const Source = struct {
//       path: fs.Path,
//       contents: string,
//       contents_is_recycled: bool = false,
//       identifier_name: string = "",
//       index: Index = Index.source(0),
//   }
// ============================================================================

/// AST 错误位置信息 - 对应 Bun Source.ErrorPosition
/// Bun: pub const ErrorPosition = struct { line_start, line_end, column_count, line_count }
public class ErrorPosition {
    /// 行开始字节偏移
    public var lineStart: Int64
    /// 行结束字节偏移
    public var lineEnd: Int64
    /// 列号
    public var columnCount: Int64
    /// 行号
    public var lineCount: Int64

    public init(lineStart: Int64, lineEnd: Int64, columnCount: Int64, lineCount: Int64) {
        this.lineStart = lineStart
        this.lineEnd = lineEnd
        this.columnCount = columnCount
        this.lineCount = lineCount
    }
}

/// AST 源文件 - 对应 Bun logger.Source
/// Bun: pub const Source = struct { path, contents, contents_is_recycled, identifier_name, index }
public class ASTSource {
    /// 文件路径 - 对应 Bun Source.path: fs.Path
    public var path: String
    /// 命名空间 - 对应 Bun Source.path.namespace
    public var namespace: String
    /// 文件内容 - 对应 Bun Source.contents: string
    public var contents: String
    /// 内容是否为回收内存 - 对应 Bun Source.contents_is_recycled
    public var contentsIsRecycled: Bool
    /// 可读标识符名称 - 对应 Bun Source.identifier_name
    public var identifierName: String
    /// 源文件索引 - 对应 Bun Source.index: Index
    public var index: SourceIndex

    public init(path: String, contents: String) {
        this.path = path
        this.namespace = "file"
        this.contents = contents
        this.contentsIsRecycled = false
        this.identifierName = ""
        this.index = SourceIndex.source(UInt32(0))
    }

    public init(path: String, namespace: String, contents: String) {
        this.path = path
        this.namespace = namespace
        this.contents = contents
        this.contentsIsRecycled = false
        this.identifierName = ""
        this.index = SourceIndex.source(UInt32(0))
    }

    /// 初始化空文件 - 对应 Bun Source.initEmptyFile()
    /// Bun: pub fn initEmptyFile(filepath: string) Source
    public static func initEmptyFile(filepath: String): ASTSource {
        return ASTSource(filepath, "")
    }

    /// 初始化路径字符串 - 对应 Bun Source.initPathString()
    /// Bun: pub fn initPathString(pathString: string, contents: string) Source
    public static func initPathString(pathString: String, contents: String): ASTSource {
        return ASTSource(pathString, contents)
    }

    /// 获取范围内的文本 - 对应 Bun Source.textForRange()
    /// Bun: pub fn textForRange(self: *const Source, r: Range) string
    public func textForRange(r: ASTRange): String {
        return r.inBuf(contents)
    }

    /// 是否为 WebAssembly 文件 - 对应 Bun Source.isWebAssembly()
    /// Bun: pub fn isWebAssembly(this: *Source) bool
    public func isWebAssembly(): Bool {
        if (contents.size < 4) {
            return false
        }
        // 检查 "\0asm" 魔数 (0x6d736100)
        return contents[0..4] == "\u0000asm"
    }

    /// 初始化错误位置 - 对应 Bun Source.initErrorPosition()
    /// Bun: pub fn initErrorPosition(self: *const Source, offset_loc: Loc) ErrorPosition
    /// 计算给定偏移位置的行列信息
    public func initErrorPosition(offsetLoc: ASTLoc): ErrorPosition {
        if (offsetLoc.isEmpty()) {
            return ErrorPosition(0, 0, 1, 1)
        }

        let offset = if (Int64(offsetLoc.start) > contents.size - 1) {
            contents.size - 1
        } else {
            Int64(offsetLoc.start)
        }

        var lineStart: Int64 = 0
        var lineCount: Int64 = 1
        var columnNumber: Int64 = 1
        var prevCodePoint: Int32 = 0

        // 遍历到偏移位置，计算行列
        var i: Int64 = 0
        while (i < offset) {
            let c = Int32(contents[Int64(i)].value)
            match (c) {
                case 10 => { // '\n'
                    columnNumber = 1
                    lineStart = i + 1
                    if (prevCodePoint != 13) { // '\r'
                        lineCount += 1
                    }
                }
                case 13 => { // '\r'
                    columnNumber = 0
                    lineStart = i + 1
                    lineCount += 1
                }
                case _ => {
                    columnNumber += 1
                }
            }
            prevCodePoint = c
            i += 1
        }

        // 扫描到行尾
        var lineEnd: Int64 = contents.size
        var j = offset
        while (j < contents.size) {
            let c = Int32(contents[Int64(j)].value)
            if (c == 13 || c == 10) { // '\r' || '\n'
                lineEnd = j
                break
            }
            j += 1
        }

        let adjustedLineStart = if (lineStart > 0) { lineStart - 1 } else { lineStart }
        return ErrorPosition(adjustedLineStart, lineEnd, columnNumber, lineCount)
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// usize 转 Loc - 对应 Bun usize2Loc()
/// Bun: pub inline fn usize2Loc(loc: usize) Loc
public func usize2Loc(loc: Int64): ASTLoc {
    return ASTLoc(Int32(loc))
}

/// 创建范围数据 - 对应 Bun rangeData()
/// Bun: pub fn rangeData(source: ?*const Source, r: Range, text: string) Data
public func rangeData(source: ?ASTSource, r: ASTRange, text: String): ASTMsgData {
    match (source) {
        case Some(s) =>
            if (r.isEmpty()) {
                return ASTMsgData(text, Some(ASTLocation(
                    s.path, s.namespace, -1, -1, 0, 0, ""
                )))
            }
            let pos = s.initErrorPosition(r.loc)
            return ASTMsgData(text, Some(ASTLocation(
                s.path, s.namespace,
                Int32(pos.lineCount), Int32(pos.columnCount),
                Int64(r.len), Int64(r.loc.start),
                None
            )))
        case None =>
            return ASTMsgData(text, None)
    }
}
