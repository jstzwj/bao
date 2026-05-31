// JavaScript 代码打印机 - Writer 和入口函数
// 严格翻译自: src/js_printer/js_printer.zig:5606-6423
//   包括: WriteResult, NewWriter, BufferWriter, BufferPrinter, DirectWriter,
//         Format, GenerateSourceMap, getSourceMapBuilder, printAst, printJSON,
//         print, printWithWriter, printWithWriterAndPlatform, printCommonJS,
//         serializeModuleInfo
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// WriteResult - 写入结果
// 严格翻译自: js_printer.zig:5606-5610
// ============================================================================

/// 写入结果 - 对应 Bun WriteResult
public class WriteResult {
    public var offset: Int64
    public var length: Int64
    public var endOffset: Int64

    public init() {
        offset = 0
        length = 0
        endOffset = 0
    }

    public init(offset: Int64, length: Int64, endOffset: Int64) {
        this.offset = offset
        this.length = length
        this.endOffset = endOffset
    }
}

// ============================================================================
// BufferWriter - 缓冲区写入器
// 严格翻译自: js_printer.zig:5756-5875
//   pub const BufferWriter = struct { buffer, written, sentinel, ... }
// ============================================================================

/// 缓冲区写入器 - 对应 Bun BufferWriter
public class BufferWriter {
    /// 底层缓冲区 - 对应 buffer: MutableString
    public var buffer: MutableString
    /// 已写入数据 - 对应 written: []u8
    public var written: String
    /// 是否追加空字节 - 对应 append_null_byte
    public var appendNullByte: Bool
    /// 是否追加换行 - 对应 append_newline
    public var appendNewline: Bool
    /// 近似换行计数 - 对应 approximate_newline_count
    public var approximateNewlineCount: Int64
    /// 最后两个字节 - 对应 last_bytes: [2]u8
    public var lastBytes: Array<UInt8>

    public init() {
        buffer = MutableString()
        written = ""
        appendNullByte = false
        appendNewline = false
        approximateNewlineCount = 0
        lastBytes = Array<UInt8>(2, repeat: 0)
    }

    public init(allocator: Allocator) {
        buffer = MutableString()
        written = ""
        appendNullByte = false
        appendNewline = false
        approximateNewlineCount = 0
        lastBytes = Array<UInt8>(2, repeat: 0)
    }

    /// 获取最后字节 - 对应 getLastByte()
    public func getLastByte(): UInt8 {
        return lastBytes[1]
    }

    /// 获取倒数第二字节 - 对应 getLastLastByte()
    public func getLastLastByte(): UInt8 {
        return lastBytes[0]
    }

    /// 获取已写入数据 - 对应 getWritten()
    public func getWritten(): String {
        return buffer.toString()
    }

    /// 获取可变缓冲区 - 对应 getMutableBuffer()
    public func getMutableBuffer(): MutableString {
        return buffer
    }

    /// 取出缓冲区 - 对应 takeBuffer()
    public func takeBuffer(): MutableString {
        let result = buffer
        buffer = MutableString()
        return result
    }

    /// 写入单字节 - 对应 writeByte()
    public func writeByte(byte: UInt8): Int64 {
        buffer.appendChar(byte)
        approximateNewlineCount += if (byte == 10) { Int64(1) } else { Int64(0) }
        lastBytes[0] = lastBytes[1]
        lastBytes[1] = byte
        return 1
    }

    /// 写入字节序列 - 对应 writeAll()
    public func writeAll(bytes: String): Int64 {
        buffer.appendStr(bytes)
        let len = Int64(bytes.size)
        if (len > 0 && bytes[Int64(bytes.size) - 1] == 10) {
            approximateNewlineCount += 1
        }
        if (len >= 2) {
            lastBytes[0] = bytes[Int64(bytes.size) - 2]
            lastBytes[1] = bytes[Int64(bytes.size) - 1]
        } else if (len >= 1) {
            lastBytes[0] = lastBytes[1]
            lastBytes[1] = bytes[Int64(bytes.size) - 1]
        }
        return len
    }

    /// 获取切片 - 对应 slice()
    public func slice(): String {
        return buffer.toString()
    }

    /// 重置 - 对应 reset()
    public func reset(): Unit {
        buffer.reset()
        approximateNewlineCount = 0
        written = ""
    }

    /// 完成 - 对应 done()
    public func done(): Unit {
        if (appendNewline) {
            appendNewline = false
            buffer.appendChar(10)
        }
        written = buffer.toString()
    }

    /// 刷新 - 对应 flush()
    public func flush(): Unit {
        // 空操作
    }
}

// ============================================================================
// DirectWriter - 直接文件写入器
// 严格翻译自: js_printer.zig:5742-5754
// ============================================================================

/// 直接写入器 - 对应 Bun DirectWriter
public class DirectWriter {
    public var handle: Int64 // 文件描述符

    public init(handle: Int64) {
        this.handle = handle
    }

    public func write(buf: String): Int64 {
        // 简化: 实际应调用系统写入
        return Int64(buf.size)
    }

    public func writeAll(buf: String): Unit {
        write(buf)
    }
}

// ============================================================================
// 入口函数
// 严格翻译自: js_printer.zig:5936-6379
// ============================================================================

/// AST 信息 (简化)
public class Ast {
    public var importRecords: ArrayList<ImportRecord>
    public var parts: ArrayList<Part>
    public var symbols: ArrayList<Symbol>
    public var namedExports: HashMap<String, NamedExport>
    public var exportsKind: ExportsKind
    public var usesRequireRef: Bool
    public var usesExportsRef: Bool
    public var usesModuleRef: Bool
    public var exportsRef: Ref
    public var moduleRef: Ref
    public var requireRef: Ref
    public var hasLazyExport: Bool
    public var approximateNewlineCount: Int64
    public var topLevelAwaitKeyword: String
    public var exportStarImportRecords: ArrayList<Int64>
    public var moduleScope: Scope
    public var nestedScopeSlotCounts: ScopeSlotCounts
    public var charFreq: ?CharFrequency

    public init() {
        importRecords = ArrayList<ImportRecord>()
        parts = ArrayList<Part>()
        symbols = ArrayList<Symbol>()
        namedExports = HashMap<String, NamedExport>()
        exportsKind = ExportsKind.ExportsNone
        usesRequireRef = false
        usesExportsRef = false
        usesModuleRef = false
        exportsRef = Ref.NONE
        moduleRef = Ref.NONE
        requireRef = Ref.NONE
        hasLazyExport = false
        approximateNewlineCount = 0
        topLevelAwaitKeyword = ""
        exportStarImportRecords = ArrayList<Int64>()
        moduleScope = Scope(0, ScopeKind.Block)
        parts = ArrayList<Part>()
        nestedScopeSlotCounts = ScopeSlotCounts()
        charFreq = None
    }
}

/// Part - AST 部分
public enum PartTag {
    | PartNone
    | DeadDueToInlining
    | Normal
}

public class Part {
    public var stmts: ArrayList<Stmt>
    public var symbolUses: HashMap<Ref, Int64>
    public var declaredSymbols: ArrayList<Ref>
    public var importRecordIndices: ArrayList<UInt32>
    public var tag: PartTag
    public var dependencies: ArrayList<PartDependency>

    public init() {
        stmts = ArrayList<Stmt>()
        symbolUses = HashMap<Ref, Int64>()
        declaredSymbols = ArrayList<Ref>()
        importRecordIndices = ArrayList<UInt32>()
        tag = PartTag.PartNone
        dependencies = ArrayList<PartDependency>()
    }
}

/// Scope 占位
public class PrinterScope {}

/// ScopeSlotCounts 占位
public class ScopeSlotCounts {}

/// CharFrequency 占位
public class CharFrequency {}

/// ExportsKind - 已在 package.cj 中定义

/// Allocator 占位
public class Allocator {}

// ============================================================================
// 打印入口函数
// ============================================================================

/// 打印 AST - 对应 printAst()
/// Bun: pub fn printAst(comptime Writer: type, _writer: Writer, tree: Ast,
///       symbols: js_ast.Symbol.Map, source: *const logger.Source,
///       comptime ascii_only: bool, opts: Options,
///       comptime generate_source_map: bool) !usize
public func printAst(asciiOnly: Bool, tree: Ast, symbols: SymbolMap,
                      source: LoggerSource, opts: PrinterOptions,
                      generateSourceMap: Bool): PrintResult {
    let renamerInst = NoOpRenamer(symbols, source).toRenamer()
    return printWithRenamer(asciiOnly, tree, opts, renamerInst,
                             tree.parts, generateSourceMap)
}

/// 打印 JSON - 对应 printJSON()
/// Bun: pub fn printJSON(comptime Writer: type, _writer: Writer, expr: Expr,
///       source: *const logger.Source, opts: Options) !usize
public func printJSON(expr: Expr, source: LoggerSource,
                       opts: PrinterOptions): PrintResult {
    let printer = JSPrinter(false, false, false, true, false)
    let renamerInst = NoOpRenamer(SymbolMap(), source).toRenamer()
    printer.initPrinter(renamerInst, ArrayList<ImportRecord>(), opts,
                         SourceMapBuilder())

    printer.printExpr(expr, OpLevel.Comma, ExprFlags.none())
    let code = printer.getResult()
    return PrintResult.success(code)
}

/// 打印 - 对应 print()
/// Bun: pub fn print(allocator, target, ast, source, opts, import_records,
///       parts, renamer, comptime generate_source_maps) PrintResult
public func printJs(target: String, ast: Ast, source: LoggerSource,
                     opts: PrinterOptions, importRecords: ArrayList<ImportRecord>,
                     parts: ArrayList<Part>, renamer: Renamer,
                     generateSourceMaps: Bool): PrintResult {
    let isBun = target == "bun"
    return printWithWriterAndPlatform(
        isBun, ast, source, opts, importRecords, parts, renamer, generateSourceMaps)
}

/// 带平台打印 - 对应 printWithWriterAndPlatform()
/// Bun: pub fn printWithWriterAndPlatform(comptime Writer, writer,
///       comptime is_bun_platform, ast, source, opts, import_records,
///       parts, renamer, comptime generate_source_maps) PrintResult
public func printWithWriterAndPlatform(isBunPlatform: Bool, ast: Ast,
                                         source: LoggerSource,
                                         opts: PrinterOptions,
                                         importRecords: ArrayList<ImportRecord>,
                                         parts: ArrayList<Part>,
                                         renamer: Renamer,
                                         generateSourceMaps: Bool): PrintResult {
    let asciiOnly = isBunPlatform
    let printer = JSPrinter(asciiOnly, false, isBunPlatform, false, generateSourceMaps)
    printer.initPrinter(renamer, importRecords, opts, SourceMapBuilder())
    printer.wasLazyExport = ast.hasLazyExport

    for (part in parts) {
        for (stmt in part.stmts) {
            printer.printStmt(stmt, TopLevel.initTopLevel(IsTopLevel.Yes))
            printer.printSemicolonIfNeeded()
        }
    }

    let code = printer.getResult()
    return PrintResult.success(code)
}

/// 打印 CommonJS - 对应 printCommonJS()
/// Bun: pub fn printCommonJS(comptime Writer, _writer, tree, symbols,
///       source, comptime ascii_only, opts, comptime generate_source_map) !usize
public func printCommonJS(tree: Ast, symbols: SymbolMap,
                            source: LoggerSource, asciiOnly: Bool,
                            opts: PrinterOptions,
                            generateSourceMap: Bool): PrintResult {
    let printer = JSPrinter(asciiOnly, true, false, false, generateSourceMap)
    let renamerInst = NoOpRenamer(symbols, source).toRenamer()
    printer.initPrinter(renamerInst, tree.importRecords, opts, SourceMapBuilder())

    for (part in tree.parts) {
        for (stmt in part.stmts) {
            printer.printStmt(stmt, TopLevel.initTopLevel(IsTopLevel.Yes))
            printer.printSemicolonIfNeeded()
        }
    }

    printer.print("\n\n")
    let code = printer.getResult()
    return PrintResult.success(code)
}

/// 带重命名器打印 - 内部辅助
public func printWithRenamer(asciiOnly: Bool, tree: Ast, opts: PrinterOptions,
                               renamer: Renamer, parts: ArrayList<Part>,
                               generateSourceMap: Bool): PrintResult {
    let printer = JSPrinter(asciiOnly, false, asciiOnly, false, generateSourceMap)
    printer.initPrinter(renamer, tree.importRecords, opts, SourceMapBuilder())
    printer.wasLazyExport = tree.hasLazyExport

    for (part in parts) {
        for (stmt in part.stmts) {
            printer.printStmt(stmt, TopLevel.initTopLevel(IsTopLevel.Yes))
            printer.printSemicolonIfNeeded()
        }
    }

    let code = printer.getResult()
    return PrintResult.success(code)
}

// ============================================================================
// ImportRecordFlags - 导入记录标志
// ============================================================================

// ImportRecordFlags - 已在 scan_imports.cj 中定义

// HashMap uses bao_collections.HashMap (imported via bao_collections.*)

