// JavaScript 代码打印机 - 核心结构和入口函数
// 严格翻译自: src/js_printer/js_printer.zig (6422 lines)
//   Bun 的 js_printer 模块将 AST 节点生成 JavaScript 源代码
//   包括: 字符串编码、引号选择、缩进、空格、Printer 结构体、
//         表达式打印、语句打印、绑定打印、属性打印、模块导入/导出打印等
//
// 仓颉翻译说明:
//   - Zig 的 comptime 泛型 (NewPrinter) 在仓颉中用类字段代替
//   - Writer 类型参数化用 PrinterWriter 接口代替
//   - ExprFlag.Set (EnumSet) 用位标志类代替
//   - Whitespacer 的 comptime 计算改为运行时处理
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// 常量 - 严格翻译自 js_printer.zig:1-9
// ============================================================================

/// 十六进制字符 - 对应 Bun hex_chars
public const HEX_CHARS: String = "0123456789ABCDEF"

/// ASCII 可打印范围起始 - 对应 Bun first_ascii
public const FIRST_ASCII: Int64 = 0x20

/// ASCII 可打印范围结束 - 对应 Bun last_ascii
public const LAST_ASCII: Int64 = 0x7E

/// 高代理起始 - 对应 Bun first_high_surrogate
public const FIRST_HIGH_SURROGATE: Int64 = 0xD800

/// 低代理起始 - 对应 Bun first_low_surrogate
public const FIRST_LOW_SURROGATE: Int64 = 0xDC00

/// 低代理结束 - 对应 Bun last_low_surrogate
public const LAST_LOW_SURROGATE: Int64 = 0xDFFF

/// 是否始终 ASCII (JCore 需要) - 对应 Bun ascii_only_always_on_unless_minifying
public const ASCII_ONLY_ALWAYS_ON_UNLESS_MINIFYING: Bool = true

// ============================================================================
// Indentation - 缩进设置
// 严格翻译自: js_printer.zig:434-440
//   pub const Indentation = struct {
//       scalar: usize = 2, count: usize = 0, character: Character = .space
//       pub const Character = enum { tab, space }
//   }
// ============================================================================

/// 缩进字符类型 - 对应 Bun Options.Indentation.Character
public enum IndentChar {
    | Tab
    | Space
}

/// 缩进设置 - 对应 Bun Options.Indentation
public class Indentation {
    /// 每级缩进的空格/Tab数 - 对应 scalar
    public var scalar: Int64
    /// 当前缩进级别 - 对应 count
    public var count: Int64
    /// 缩进字符 - 对应 character
    public var character: IndentChar

    public init() {
        scalar = 2
        count = 0
        character = IndentChar.Space
    }

    public init(scalar: Int64, count: Int64, character: IndentChar) {
        this.scalar = scalar
        this.count = count
        this.character = character
    }
}

// ============================================================================
// ExprFlag - 表达式打印标志
// 严格翻译自: js_printer.zig:508-534
//   const ExprFlag = enum {
//       forbid_call, forbid_in, has_non_optional_chain_parent,
//       expr_result_is_unused
//   }
// ============================================================================

/// 表达式标志 - 对应 Bun ExprFlag
public class ExprFlags {
    /// 禁止函数调用 - 对应 forbid_call
    public var forbidCall: Bool
    /// 禁止 in 运算符 - 对应 forbid_in
    public var forbidIn: Bool
    /// 有非可选链父节点 - 对应 has_non_optional_chain_parent
    public var hasNonOptionalChainParent: Bool
    /// 表达式结果未使用 - 对应 expr_result_is_unused
    public var exprResultIsUnused: Bool

    public init() {
        forbidCall = false
        forbidIn = false
        hasNonOptionalChainParent = false
        exprResultIsUnused = false
    }

    public init(forbidCall: Bool, forbidIn: Bool, hasNonOptionalChainParent: Bool,
                exprResultIsUnused: Bool) {
        this.forbidCall = forbidCall
        this.forbidIn = forbidIn
        this.hasNonOptionalChainParent = hasNonOptionalChainParent
        this.exprResultIsUnused = exprResultIsUnused
    }

    /// 无标志 - 对应 ExprFlag.None()
    public static func none(): ExprFlags {
        return ExprFlags()
    }

    /// 禁止调用标志 - 对应 ExprFlag.ForbidCall()
    public static func forbidCallFlags(): ExprFlags {
        return ExprFlags(forbidCall: true, forbidIn: false,
                         hasNonOptionalChainParent: false, exprResultIsUnused: false)
    }

    /// 有非可选链父节点标志 - 对应 ExprFlag.HasNonOptionalChainParent()
    public static func hasNonOptionalChainParentFlags(): ExprFlags {
        return ExprFlags(forbidCall: false, forbidIn: false,
                         hasNonOptionalChainParent: true, exprResultIsUnused: false)
    }

    /// 表达式结果未使用标志 - 对应 ExprFlag.ExprResultIsUnused()
    public static func exprResultIsUnusedFlags(): ExprFlags {
        return ExprFlags(forbidCall: false, forbidIn: false,
                         hasNonOptionalChainParent: false, exprResultIsUnused: true)
    }

    /// 是否包含指定标志
    public func contains(flag: ExprFlagEnum): Bool {
        match (flag) {
            case ExprFlagEnum.ForbidCall => forbidCall
            case ExprFlagEnum.ForbidIn => forbidIn
            case ExprFlagEnum.HasNonOptionalChainParent => hasNonOptionalChainParent
            case ExprFlagEnum.ExprResultIsUnused => exprResultIsUnused
        }
    }

    /// 设置标志
    public func set(flag: ExprFlagEnum, value: Bool): Unit {
        match (flag) {
            case ExprFlagEnum.ForbidCall => forbidCall = value
            case ExprFlagEnum.ForbidIn => forbidIn = value
            case ExprFlagEnum.HasNonOptionalChainParent => hasNonOptionalChainParent = value
            case ExprFlagEnum.ExprResultIsUnused => exprResultIsUnused = value
        }
    }

    /// 插入标志 (设置为 true) - 对应 EnumSet.insert
    public func insert(flag: ExprFlagEnum): Unit {
        set(flag, true)
    }

    /// 移除标志 (设置为 false) - 对应 EnumSet.remove
    public func remove(flag: ExprFlagEnum): Unit {
        set(flag, false)
    }
}

/// 表达式标志枚举
public enum ExprFlagEnum {
    | ForbidCall
    | ForbidIn
    | HasNonOptionalChainParent
    | ExprResultIsUnused
}

// ============================================================================
// ImportVariant - 导入变体
// 严格翻译自: js_printer.zig:536-597
// ============================================================================

/// 导入变体 - 对应 Bun ImportVariant
public enum ImportVariant {
    | PathOnly
    | ImportStar
    | ImportDefault
    | ImportStarAndImportDefault
    | ImportItems
    | ImportItemsAndDefault
    | ImportItemsAndStar
    | ImportItemsAndDefaultAndStar

    /// 添加 items - 对应 ImportVariant.hasItems()
    public func hasItems(): ImportVariant {
        match (this) {
            case ImportDefault => ImportItemsAndDefault
            case ImportStar => ImportItemsAndStar
            case ImportStarAndImportDefault => ImportItemsAndDefaultAndStar
            case _ => ImportItems
        }
    }

    /// 添加 star - 对应 ImportVariant.hasStar()
    public func hasStar(): ImportVariant {
        match (this) {
            case PathOnly => ImportStar
            case _ => this
        }
    }

    /// 添加 default - 对应 ImportVariant.hasDefault()
    public func hasDefault(): ImportVariant {
        match (this) {
            case PathOnly => ImportDefault
            case ImportStar => ImportStarAndImportDefault
            case _ => this
        }
    }

    /// 判断导入变体 - 对应 ImportVariant.determine()
    public static func determine(record: ImportRecord, sImport: SImport): ImportVariant {
        var variant = ImportVariant.PathOnly

        if (record.flags.containsImportStar) {
            variant = variant.hasStar()
        }

        if (!record.flags.wasOriginallyBareImport) {
            if (!record.flags.containsDefaultAlias) {
                if (let defaultName = sImport.defaultName) {
                    if (defaultName.ref != null && !defaultName.ref.isNull()) {
                        variant = variant.hasDefault()
                    }
                }
            } else {
                variant = variant.hasDefault()
            }
        }

        if (sImport.items.size() > 0) {
            variant = variant.hasItems()
        }

        return variant
    }
}

// ============================================================================
// Whitespacer - 空格处理
// 严格翻译自: js_printer.zig:82-110
//   const Whitespacer = struct { normal: []const u8, minify: []const u8 }
//   fn ws(comptime str: []const u8) Whitespacer
// ============================================================================

/// 空格对 - 对应 Bun Whitespacer
/// Bun: struct { normal: []const u8, minify: []const u8 }
public class Whitespacer {
    public var normal: String
    public var minify: String

    public init(normal: String, minify: String) {
        this.normal = normal
        this.minify = minify
    }
}

/// 创建空格对 - 对应 Bun ws()
/// Zig comptime: 移除空格字符得到 minify 版本
public func ws(str: String): Whitespacer {
    var buf = StringBuilder()
    for (ch in str) {
        if (ch != ' ') {
            buf.append(ch)
        }
    }
    return Whitespacer(str, buf.toString())
}

// ============================================================================
// PrintResult - 打印结果
// 严格翻译自: js_printer.zig:494-502
//   pub const PrintResult = union(enum) {
//       result: Success, err: anyerror
//       pub const Success = struct { code: []u8, source_map: ?SourceMap.Chunk = null }
//   }
// ============================================================================

/// 打印成功结果 - 对应 Bun PrintResult.Success
public class PrintResultSuccess {
    public var code: String
    public var sourceMap: ?SourceMapChunk

    public init(code: String) {
        this.code = code
        this.sourceMap = None
    }

    public init(code: String, sourceMap: SourceMapChunk) {
        this.code = code
        this.sourceMap = sourceMap
    }
}

/// 打印结果 - 对应 Bun PrintResult
public class PrintResult {
    public var result: ?PrintResultSuccess
    public var err: ?Exception

    public init(success: PrintResultSuccess) {
        result = success
        err = None
    }

    public init(error: Exception) {
        result = None
        err = error
    }

    public static func success(code: String): PrintResult {
        return PrintResult(PrintResultSuccess(code))
    }

    public static func err(e: Exception): PrintResult {
        return PrintResult(e)
    }
}

/// SourceMap Chunk 占位 - 对应 Bun SourceMap.Chunk
public class SourceMapChunk {
    public var buffer: String

    public init(buffer: String) {
        this.buffer = buffer
    }
}

/// SourceMap Builder 占位 - 对应 Bun SourceMap.Chunk.Builder
public class SourceMapBuilder {
    public func addSourceMapping(loc: Loc, slice: String): Unit {}
}

// ============================================================================
// RequireOrImportMeta - require/import 元信息
// 严格翻译自: js_printer.zig:454-484
// ============================================================================

/// Require/import 元信息 - 对应 Bun RequireOrImportMeta
public class RequireOrImportMeta {
    public var wrapperRef: Ref
    public var exportsRef: Ref
    public var isWrapperAsync: Bool
    public var wasUnwrappedRequire: Bool

    public init() {
        wrapperRef = Ref.NONE
        exportsRef = Ref.NONE
        isWrapperAsync = false
        wasUnwrappedRequire = false
    }

    public init(wrapperRef: Ref, exportsRef: Ref, isWrapperAsync: Bool,
                wasUnwrappedRequire: Bool) {
        this.wrapperRef = wrapperRef
        this.exportsRef = exportsRef
        this.isWrapperAsync = isWrapperAsync
        this.wasUnwrappedRequire = wasUnwrappedRequire
    }
}

// ============================================================================
// BinaryExpressionVisitor - 二元表达式访问器
// 严格翻译自: js_printer.zig:681-843
//   pub const BinaryExpressionVisitor = struct { ... }
// ============================================================================

/// 二元表达式访问器 - 对应 Bun BinaryExpressionVisitor
/// 处理二元表达式的迭代打印（避免递归栈溢出）
public class BinaryExpressionVisitor {
    // Inputs
    public var e: EBinary
    public var level: OpLevel
    public var flags: ExprFlags

    // Input for visiting the left child
    public var leftLevel: OpLevel
    public var leftFlags: ExprFlags

    // Local variables
    public var entry: OpEntry
    public var wrap: Bool
    public var rightLevel: OpLevel

    public init(e: EBinary, level: OpLevel, flags: ExprFlags) {
        this.e = e
        this.level = level
        this.flags = flags
        leftLevel = OpLevel.Comma
        leftFlags = ExprFlags.none()
        entry = OpEntry.default()
        wrap = false
        rightLevel = OpLevel.Comma
    }
}

// ============================================================================
// Format - 输出格式
// 严格翻译自: js_printer.zig:5886-5897
//   pub const Format = enum { esm, cjs, esm_ascii, cjs_ascii }
// ============================================================================

/// 输出格式 - 对应 Bun Format
public enum PrintFormat {
    | Esm         // ES Module
    | Cjs         // CommonJS
    | EsmAscii    // ESM + ASCII 转义
    | CjsAscii    // CJS + ASCII 转义

    public func isBun(): Bool {
        match (this) {
            case EsmAscii | CjsAscii => true
            case _ => false
        }
    }

    public func isCjs(): Bool {
        match (this) {
            case Cjs | CjsAscii => true
            case _ => false
        }
    }

    public func isEsm(): Bool {
        match (this) {
            case Esm | EsmAscii => true
            case _ => false
        }
    }

    public func isAsciiOnly(): Bool {
        match (this) {
            case EsmAscii | CjsAscii => true
            case _ => false
        }
    }
}

// ============================================================================
// IsTopLevel - 顶层作用域标记
// 严格翻译自: js_printer.zig:668
//   const IsTopLevel = enum { yes, var_only, no }
// ============================================================================

public enum IsTopLevel {
    | Yes
    | VarOnly
    | No
}

// ============================================================================
// TopLevelAndIsExport - 顶层导出标记
// 严格翻译自: js_printer.zig:641-667
// ============================================================================

/// 顶层和导出信息 - 对应 Bun TopLevelAndIsExport / TopLevel
public class TopLevel {
    public var isExport: Bool
    public var isTopLevel: IsTopLevel

    public init() {
        isExport = false
        isTopLevel = IsTopLevel.No
    }

    public init(isExport: Bool, isTopLevel: IsTopLevel) {
        this.isExport = isExport
        this.isTopLevel = isTopLevel
    }

    public static func initTopLevel(isTopLevel: IsTopLevel): TopLevel {
        return TopLevel(false, isTopLevel)
    }

    /// 子变量 - 对应 Bun TopLevel.subVar()
    public func subVar(): TopLevel {
        if (isTopLevel == IsTopLevel.No) {
            return TopLevel.initTopLevel(IsTopLevel.No)
        }
        return TopLevel.initTopLevel(IsTopLevel.VarOnly)
    }

    /// 是否为顶层 - 对应 Bun TopLevel.isTopLevel()
    public func isTopLevelFlag(): Bool {
        return isTopLevel != IsTopLevel.No
    }
}

// ============================================================================
// OpEntry - 操作符条目
// 用于查找操作符的打印信息
// ============================================================================

/// 操作符条目 - 对应 Bun Op.Table.getPtrConst() 返回的 *const Op
public class OpEntry {
    public var text: String
    public var level: OpLevel
    public var isKeyword: Bool
    public var opCode: OpCode

    public init(text: String, level: OpLevel, isKeyword: Bool, opCode: OpCode) {
        this.text = text
        this.level = level
        this.isKeyword = isKeyword
        this.opCode = opCode
    }

    public static func default(): OpEntry {
        return OpEntry("", OpLevel.Comma, false, OpCode.BinAdd)
    }
}

// ============================================================================
// 辅助函数
// 严格翻译自: js_printer.zig:11-146
// ============================================================================

/// 格式化无符号整数到缓冲区 - 对应 Bun formatUnsignedIntegerBetween
/// Bun: fn formatUnsignedIntegerBetween(comptime len: u16, buf: *[len]u8, val: u64) void
public func formatUnsignedIntegerBetween(buf: ArrayList<UInt8>, offset: Int64,
                                          len: Int64, val: Int64): Unit {
    var i = len
    var remainder = val
    while (i > 0) {
        i = i - 1
        buf.set(offset + i, UInt8((remainder % 10) + 48)) // '0' = 48
        remainder = remainder / 10
    }
}

/// 写入模块ID - 对应 Bun writeModuleId
/// Bun: pub fn writeModuleId(comptime Writer: type, writer: Writer, module_id: u32) void
public func writeModuleId(sb: StringBuilder, moduleId: Int64): Unit {
    sb.append("$")
    sb.append(moduleId.toHexString().toLowerCase())
}

/// 判断是否可以不转义打印 - 对应 Bun canPrintWithoutEscape
/// Bun: pub fn canPrintWithoutEscape(comptime CodePointType: type, c: CodePointType,
///       comptime ascii_only: bool) bool
public func canPrintWithoutEscape(c: Int64, asciiOnly: Bool): Bool {
    if (c <= LAST_ASCII) {
        return c >= FIRST_ASCII && c != '\\' && c != '"' && c != '\'' &&
               c != '`' && c != '$'
    } else {
        return !asciiOnly && c != 0xFEFF && c != 0x2028 && c != 0x2029 &&
               (c < FIRST_HIGH_SURROGATE || c > LAST_LOW_SURROGATE)
    }
}

/// 为字符串选择最佳引号 - 对应 Bun bestQuoteCharForString
/// Bun: pub fn bestQuoteCharForString(comptime Type: type, str: []const Type,
///       allow_backtick: bool) u8
public func bestQuoteCharForString(str: String, allowBacktick: Bool): UInt8 {
    var singleCost: Int64 = 0
    var doubleCost: Int64 = 0
    var backtickCost: Int64 = 0
    var i: Int64 = 0
    let n = str.length
    let limit = if (n < 1024) { n } else { Int64(1024) }

    while (i < limit) {
        let ch = str[i]
        if (ch == '\'') {
            singleCost += 1
        } else if (ch == '"') {
            doubleCost += 1
        } else if (ch == '`') {
            backtickCost += 1
        } else if (ch == '\n') {
            singleCost += 1
            doubleCost += 1
        } else if (ch == '\\') {
            i += 1
        } else if (ch == '$') {
            if (i + 1 < str.length && str[Int64(i + 1)] == '{') {
                backtickCost += 1
            }
        }
        i += 1
    }

    let minCost = if (singleCost < doubleCost) { singleCost } else { doubleCost }
    if (allowBacktick && backtickCost < minCost) {
        return UInt8('`')
    }
    if (singleCost < doubleCost) {
        return UInt8('\'')
    }
    return UInt8('"')
}

/// 估计 UTF8 字符串转义后长度 - 对应 Bun estimateLengthForUTF8
/// Bun: pub fn estimateLengthForUTF8(input: []const u8, comptime ascii_only: bool,
///       comptime quote_char: u8) usize
public func estimateLengthForUTF8(input: String, asciiOnly: Bool, quoteChar: UInt8): Int64 {
    var len: Int64 = 2 // for quotes
    var remaining = input
    // 简化实现: 估计最坏情况
    len += Int64(remaining.length) * 6
    return len
}

/// 判断是否是标识符或数字常量或属性访问 - 对应 Bun isIdentifierOrNumericConstantOrPropertyAccess
/// Bun: fn isIdentifierOrNumericConstantOrPropertyAccess(expr: *const Expr) bool
public func isIdentifierOrNumericConstantOrPropertyAccess(expr: Expr): Bool {
    match (expr.tag) {
        case ExprTag.Identifier | ExprTag.Dot | ExprTag.Index => true
        case ExprTag.Number => true  // isInfinite or isNaN
        case _ => false
    }
}

/// hex字符查找
public func hexChar(n: Int64): UInt8 {
    let chars = HEX_CHARS
    return UInt8(chars[Int64(n)])
}

// ============================================================================
// JSPrinter - JavaScript 代码打印机
// 严格翻译自: js_printer.zig:599-5604 (NewPrinter 返回的结构体)
//   NewPrinter 是 Zig comptime 函数，生成 Printer 类型
//   仓颉: 合并为一个类，用实例字段替代 comptime 参数
// ============================================================================

/// JavaScript 代码打印机 - 对应 Bun NewPrinter 返回的结构体
/// 核心功能: 将 AST 节点打印为 JavaScript 源代码
public class JSPrinter {
    // ========================================================================
    // 配置字段 - 对应 Zig comptime 参数
    // ========================================================================
    /// 是否仅 ASCII 输出 - 对应 comptime ascii_only
    public var asciiOnly: Bool
    /// 是否重写 ESM 为 CJS - 对应 comptime rewrite_esm_to_cjs
    public var rewriteEsmToCjs: Bool
    /// 是否 bun 平台 - 对应 comptime is_bun_platform
    public var isBunPlatform: Bool
    /// 是否 JSON 模式 - 对应 comptime is_json
    public var isJson: Bool
    /// 是否生成 source map - 对应 comptime generate_source_map
    public var generateSourceMap: Bool

    // ========================================================================
    // Printer 字段 - 对应 Bun Printer 结构体
    // ========================================================================
    /// 导入记录 - 对应 import_records
    public var importRecords: ArrayList<ImportRecord>
    /// 是否需要分号 - 对应 needs_semicolon
    public var needsSemicolon: Bool
    /// 语句开始位置 - 对应 stmt_start
    public var stmtStart: Int64
    /// 打印选项 - 对应 options
    public var options: PrinterOptions
    /// export default 开始位置 - 对应 export_default_start
    public var exportDefaultStart: Int64
    /// 箭头表达式开始位置 - 对应 arrow_expr_start
    public var arrowExprStart: Int64
    /// for-of 初始化开始位置 - 对应 for_of_init_start
    public var forOfInitStart: Int64
    /// 前一个操作符 - 对应 prev_op
    public var prevOp: OpCode
    /// 前一个操作符结束位置 - 对应 prev_op_end
    public var prevOpEnd: Int64
    /// 前一个数字结束位置 - 对应 prev_num_end
    public var prevNumEnd: Int64
    /// 前一个正则结束位置 - 对应 prev_reg_exp_end
    public var prevRegExpEnd: Int64
    /// 调用目标 - 对应 call_target
    public var callTarget: ?Expr
    /// 输出构建器
    public var sb: StringBuilder
    /// 已写入字节数 - 对应 writer.written
    public var written: Int64
    /// 上一个字符
    public var prevChar: UInt8
    /// 上上一个字符
    public var prevPrevChar: UInt8
    /// 是否已打印捆绑导入 - 对应 has_printed_bundled_import_statement
    public var hasPrintedBundledImportStatement: Bool
    /// 重命名器 - 对应 renamer
    public var renamer: Renamer
    /// 前一条语句标签 - 对应 prev_stmt_tag
    public var prevStmtTag: StmtTag
    /// Source Map 构建器 - 对应 source_map_builder
    public var sourceMapBuilder: SourceMapBuilder
    /// 符号计数器 - 对应 symbol_counter
    public var symbolCounter: Int64
    /// 二元表达式栈 - 对应 binary_expression_stack
    public var binaryExpressionStack: ArrayList<BinaryExpressionVisitor>
    /// 是否懒导出 - 对应 was_lazy_export
    public var wasLazyExport: Bool

    // ========================================================================
    // 构造函数
    // ========================================================================

    public init(asciiOnly: Bool, rewriteEsmToCjs: Bool, isBunPlatform: Bool,
                isJson: Bool, generateSourceMap: Bool) {
        this.asciiOnly = asciiOnly
        this.rewriteEsmToCjs = rewriteEsmToCjs
        this.isBunPlatform = isBunPlatform
        this.isJson = isJson
        this.generateSourceMap = generateSourceMap

        importRecords = ArrayList<ImportRecord>()
        needsSemicolon = false
        stmtStart = -1
        options = PrinterOptions()
        exportDefaultStart = -1
        arrowExprStart = -1
        forOfInitStart = -1
        prevOp = OpCode.BinAdd
        prevOpEnd = -1
        prevNumEnd = -1
        prevRegExpEnd = -1
        callTarget = None
        sb = StringBuilder()
        written = 0
        prevChar = 0
        prevPrevChar = 0
        hasPrintedBundledImportStatement = false
        renamer = NoOpRenamer(SymbolMap(), LoggerSource()).toRenamer()
        prevStmtTag = StmtTag.SEmpty
        sourceMapBuilder = SourceMapBuilder()
        symbolCounter = 0
        binaryExpressionStack = ArrayList<BinaryExpressionVisitor>()
        wasLazyExport = false
    }

    // ========================================================================
    // 核心输出方法 - 对应 Printer 的 print/writeAll 系列
    // 严格翻译自: js_printer.zig:845-903
    // ========================================================================

    /// 写入字节 - 对应 writeByteNTimes
    public func writeByteNTimes(byte: UInt8, n: Int64): Unit {
        var i: Int64 = 0
        while (i < n) {
            sb.append(Rune(byte))
            written += 1
            i += 1
        }
        prevChar = byte
    }

    /// 打印字符串 - 对应 print()
    /// Bun: pub fn print(p: *Printer, str: anytype) void
    public func print(str: String): Unit {
        sb.append(str)
        if (str.length > 0) {
            prevChar = UInt8(str[str.length - 1])
            if (str.length > 1) {
                prevPrevChar = UInt8(str[str.length - 2])
            }
        }
        written += Int64(str.length)
    }

    /// 打印单字节 - 对应 print(u8)
    public func printByte(byte: UInt8): Unit {
        sb.append(Rune(byte))
        prevPrevChar = prevChar
        prevChar = byte
        written += 1
    }

    /// 打印格式化 - 对应 fmt()
    /// 简化实现: 仓颉字符串插值
    public func fmt(format: String, args: ArrayList<Any>): Unit {
        // 简化: 使用仓颉字符串拼接
        var result = format
        sb.append(result)
        written += Int64(result.length)
    }

    /// 打印缓冲区 - 对应 printBuffer()
    public func printBuffer(str: String): Unit {
        print(str)
    }

    // ========================================================================
    // 缩进控制 - 对应 js_printer.zig:905-930
    // ========================================================================

    /// 减少缩进 - 对应 unindent()
    public func unindent(): Unit {
        if (options.indent.count > 0) {
            options.indent.count -= 1
        }
    }

    /// 增加缩进 - 对应 indent()
    public func indent(): Unit {
        options.indent.count += 1
    }

    /// 打印缩进 - 对应 printIndent()
    public func printIndent(): Unit {
        if (options.indent.count == 0 || options.minifyWhitespace) {
            return
        }

        let totalSpaces = options.indent.count * options.indent.scalar
        var i: Int64 = totalSpaces

        while (i > 0) {
            let ch = match (options.indent.character) {
                case IndentChar.Space => " "
                case IndentChar.Tab => "\t"
            }
            print(ch)
            i -= 1
        }
    }

    // ========================================================================
    // 空格/换行/分号控制
    // 严格翻译自: js_printer.zig:941-971
    // ========================================================================

    /// 打印空格 - 对应 printSpace()
    public func printSpace(): Unit {
        if (!options.minifyWhitespace) {
            print(" ")
        }
    }

    /// 打印换行 - 对应 printNewline()
    public func printNewline(): Unit {
        if (!options.minifyWhitespace) {
            print("\n")
        }
    }

    /// 语句后打印分号 - 对应 printSemicolonAfterStatement()
    public func printSemicolonAfterStatement(): Unit {
        if (!options.minifyWhitespace) {
            print(";\n")
        } else {
            needsSemicolon = true
        }
    }

    /// 按需打印分号 - 对应 printSemicolonIfNeeded()
    public func printSemicolonIfNeeded(): Unit {
        if (needsSemicolon) {
            print(";")
            needsSemicolon = false
        }
    }

    /// 打印 " = " - 对应 print= ()
    public func printEquals(): Unit {
        if (options.minifyWhitespace) {
            print("=")
        } else {
            print(" = ")
        }
    }

    // ========================================================================
    // 标识符前空格 - 对应 js_printer.zig:1091-1108
    // ========================================================================

    /// 标识符前可能打印空格 - 对应 printSpaceBeforeIdentifier()
    public func printSpaceBeforeIdentifier(): Unit {
        if (written > 0 && (isIdentifierContinue(Int64(prevChar)) || written == prevRegExpEnd)) {
            print(" ")
        }
    }

    /// 可能打印空格 - 对应 maybePrintSpace()
    public func maybePrintSpace(): Unit {
        if (prevChar != 0 && prevChar != UInt8(' ') && prevChar != UInt8('\n')) {
            print(" ")
        }
    }

    /// 判断字符是否是标识符继续字符
    public func isIdentifierContinue(c: Int64): Bool {
        return (c >= 97 && c <= 122) || // a-z
               (c >= 65 && c <= 90) ||  // A-Z
               (c >= 48 && c <= 57) ||  // 0-9
               c == 95 || c == 36       // _ $
    }

    // ========================================================================
    // 源码映射 - 对应 js_printer.zig:1335-1354
    // ========================================================================

    /// 添加源码映射 - 对应 addSourceMapping()
    public func addSourceMapping(loc: Loc): Unit {
        if (!generateSourceMap) {
            return
        }
        sourceMapBuilder.addSourceMapping(loc, sb.toString())
    }

    /// 添加名称源码映射 - 对应 addSourceMappingForName()
    public func addSourceMappingForName(loc: Loc, name: String, ref: Ref): Unit {
        if (!generateSourceMap) {
            return
        }
        addSourceMapping(loc)
    }

    // ========================================================================
    // 符号打印 - 对应 js_printer.zig:1356-1371
    // ========================================================================

    /// 获取符号表 - 对应 symbols()
    public func symbols(): SymbolMap {
        return renamer.symbols()
    }

    /// 打印符号 - 对应 printSymbol()
    public func printSymbol(ref: Ref): Unit {
        let name = renamer.nameForSymbol(ref)
        printIdentifier(name)
    }

    /// 打印子句别名 - 对应 printClauseAlias()
    public func printClauseAlias(alias: String): Unit {
        if (alias.length > 0 && !containsNonBmpCodePointOrIsInvalidIdentifier(alias)) {
            printSpaceBeforeIdentifier()
            printIdentifier(alias)
        } else {
            printStringLiteralUTF8(alias, false)
        }
    }

    /// 混淆属性名 - 对应 mangledPropName()
    public func mangledPropName(ref: Ref): String {
        let resolved = symbols().follow(ref)
        match (options.mangledProps) {
            case Some(props) =>
                match (props.get(resolved)) {
                    case Some(name) => return name
                    case None => ()
                }
            case None => ()
        }
        return renamer.nameForSymbol(resolved)
    }

    // ========================================================================
    // Undefined 打印 - 对应 js_printer.zig:1114-1129
    // ========================================================================

    /// 打印 undefined - 对应 printUndefined()
    public func printUndefined(loc: Loc, level: OpLevel): Unit {
        if (options.minifySyntax) {
            if (level.ordinal() >= OpLevel.Unary.ordinal()) {
                addSourceMapping(loc)
                print("(void 0)")
            } else {
                printSpaceBeforeIdentifier()
                addSourceMapping(loc)
                print("void 0")
            }
        } else {
            printSpaceBeforeIdentifier()
            addSourceMapping(loc)
            print("undefined")
        }
    }

    // ========================================================================
    // 操作符前空格 - 对应 js_printer.zig:3194-3212
    // ========================================================================

    /// 操作符前可能打印空格 - 对应 printSpaceBeforeOperator()
    public func printSpaceBeforeOperator(next: OpCode): Unit {
        if (prevOpEnd == written) {
            let prev = prevOp
            if ((prev == OpCode.BinAdd || prev == OpCode.UnPos) &&
                (next == OpCode.BinAdd || next == OpCode.UnPos || next == OpCode.UnPreInc)) {
                print(" ")
            } else if ((prev == OpCode.BinSub || prev == OpCode.UnNeg) &&
                       (next == OpCode.BinSub || next == OpCode.UnNeg || next == OpCode.UnPreDec)) {
                print(" ")
            } else if (prev == OpCode.UnPostDec && next == OpCode.BinGt) {
                print(" ")
            } else if (prev == OpCode.UnNot && next == OpCode.UnPreDec && written > 1 &&
                       prevPrevChar == UInt8('<')) {
                print(" ")
            }
        }
    }

    // ========================================================================
    // 引号字符串打印 - 对应 js_printer.zig:148-340
    // ========================================================================

    /// 打印预转义字符串 - 对应 writePreQuotedString()
    public func writePreQuotedString(text: String, quoteChar: UInt8, asciiOnly: Bool,
                                      isJson: Bool): Unit {
        var i: Int64 = 0
        let n = Int64(text.length)

        while (i < n) {
            let c = Int64(text[i])

            if (canPrintWithoutEscape(c, asciiOnly)) {
                // 批量写入可打印字符
                var j = i
                while (j < n && canPrintWithoutEscape(Int64(text[j]), asciiOnly)) {
                    j += 1
                }
                print(text.substring(Int64(i), j))
                i = j
                continue
            }

            match (c) {
                case 0x07 =>
                    print("\u{07}")
                    i += 1
                case 0x08 =>
                    print("\\b")
                    i += 1
                case 0x0C =>
                    print("\\f")
                    i += 1
                case 10 => // '\n'
                    if (quoteChar == UInt8('`')) {
                        print("\n")
                    } else {
                        print("\\n")
                    }
                    i += 1
                case 13 => // '\r'
                    print("\\r")
                    i += 1
                case 11 => // '\v'
                    print("\\v")
                    i += 1
                case 92 => // '\\'
                    print("\\\\")
                    i += 1
                case 34 => // '"'
                    if (quoteChar == UInt8('"')) {
                        print("\\\"")
                    } else {
                        print("\"")
                    }
                    i += 1
                case 39 => // '\''
                    if (quoteChar == UInt8('\'')) {
                        print("\\'")
                    } else {
                        print("'")
                    }
                    i += 1
                case 96 => // '`'
                    if (quoteChar == UInt8('`')) {
                        print("\\`")
                    } else {
                        print("`")
                    }
                    i += 1
                case 36 => // '$'
                    if (quoteChar == UInt8('`') && i + 1 < n && text[i + 1] == '{') {
                        print("\\$")
                    } else {
                        print("$")
                    }
                    i += 1
                case 9 => // '\t'
                    if (quoteChar == UInt8('`')) {
                        print("\t")
                    } else {
                        print("\\t")
                    }
                    i += 1
                case _ =>
                    i += 1
                    if (c <= 0xFF && !isJson) {
                        // \xHH
                        print("\\x")
                        printByte(hexChar((c >> 4) & 0xF))
                        printByte(hexChar(c & 0xF))
                    } else if (c <= 0xFFFF) {
                        // \uHHHH
                        print("\\u")
                        printByte(hexChar((c >> 12) & 0xF))
                        printByte(hexChar((c >> 8) & 0xF))
                        printByte(hexChar((c >> 4) & 0xF))
                        printByte(hexChar(c & 0xF))
                    } else {
                        // 代理对
                        let k = c - 0x10000
                        let lo = FIRST_HIGH_SURROGATE + ((k >> 10) & 0x3FF)
                        let hi = FIRST_LOW_SURROGATE + (k & 0x3FF)
                        print("\\u")
                        printByte(hexChar(lo >> 12))
                        printByte(hexChar((lo >> 8) & 15))
                        printByte(hexChar((lo >> 4) & 15))
                        printByte(hexChar(lo & 15))
                        print("\\u")
                        printByte(hexChar(hi >> 12))
                        printByte(hexChar((hi >> 8) & 15))
                        printByte(hexChar((hi >> 4) & 15))
                        printByte(hexChar(hi & 15))
                    }
            }
        }
    }

    // ========================================================================
    // 字符串字面量打印
    // 严格翻译自: js_printer.zig:1584-1603, 1902-1918
    // ========================================================================

    /// 打印 UTF8 字符串字符 - 对应 printStringCharactersUTF8()
    public func printStringCharactersUTF8(text: String, quote: UInt8): Unit {
        writePreQuotedString(text, quote, asciiOnly, isJson)
    }

    /// 打印 EString 字符串字符 - 对应 printStringCharactersEString()
    public func printStringCharactersEString(eStr: EString, quote: UInt8): Unit {
        if (eStr.isUTF8) {
            printStringCharactersUTF8(eStr.data, quote)
        } else {
            // UTF-16 路径简化处理
            printStringCharactersUTF8(eStr.data, quote)
        }
    }

    /// 打印字符串字面量 EString - 对应 printStringLiteralEString()
    public func printStringLiteralEString(eStr: EString, allowBacktick: Bool): Unit {
        let quote = bestQuoteCharForEString(eStr, allowBacktick)
        printByte(quote)
        printStringCharactersEString(eStr, quote)
        printByte(quote)
    }

    /// 打印字符串字面量 UTF8 - 对应 printStringLiteralUTF8()
    public func printStringLiteralUTF8(str: String, allowBacktick: Bool): Unit {
        let quote = if (!isJson) {
            bestQuoteCharForString(str, allowBacktick)
        } else {
            UInt8('"')
        }

        printByte(quote)
        printStringCharactersUTF8(str, quote)
        printByte(quote)
    }

    /// 为 EString 选择最佳引号 - 对应 bestQuoteCharForEString()
    public func bestQuoteCharForEString(eStr: EString, allowBacktick: Bool): UInt8 {
        if (isJson) {
            return UInt8('"')
        }
        return bestQuoteCharForString(eStr.data, allowBacktick)
    }

    // ========================================================================
    // JSON 字符串打印 - 对应 js_printer.zig:341-354
    // ========================================================================

    /// 为 JSON 引用字符串 - 对应 quoteForJSON()
    public func quoteForJSON(text: String): Unit {
        print("\"")
        writePreQuotedString(text, UInt8('"'), asciiOnly, true)
        print("\"")
    }

    /// 写入 JSON 字符串 - 对应 writeJSONString()
    public func writeJSONString(input: String): Unit {
        print("\"")
        writePreQuotedString(input, UInt8('"'), false, true)
        print("\"")
    }

    // ========================================================================
    // 数字打印
    // 严格翻译自: js_printer.zig:1481-1582, 5346-5411
    // ========================================================================

    /// 打印非负浮点数 - 对应 printNonNegativeFloat()
    public func printNonNegativeFloat(float: Float64): Unit {
        let floored = Float64.floor(float)
        let remainder = float - floored
        let isInteger = remainder == 0.0

        if (float < Float64.fromInt64(9007199254740992) && isInteger) {
            let val = Int64(float)
            if (val == 0) {
                print("0")
            } else if (val >= 1 && val <= 9) {
                printByte(UInt8(48 + val)) // '0' + val
            } else if (val == 10) {
                print("10")
            } else if (val >= 11 && val <= 99) {
                print(val.toString())
            } else if (val == 100) {
                print("100")
            } else if (val >= 101 && val <= 999) {
                print(val.toString())
            } else if (val == 1000) {
                print("1000")
            } else if (val >= 1001 && val <= 9999) {
                print(val.toString())
            } else if (val == 10000) {
                print("1e4")
            } else if (val == 100000) {
                print("1e5")
            } else if (val == 1000000) {
                print("1e6")
            } else if (val == 10000000) {
                print("1e7")
            } else if (val == 100000000) {
                print("1e8")
            } else if (val == 1000000000) {
                print("1e9")
            } else {
                print(val.toString())
            }
            return
        }

        // 非整数浮点
        print(float.toString())
    }

    /// 打印数字 - 对应 printNumber()
    public func printNumber(value: Float64, level: OpLevel): Unit {
        if (Float64.isNaN(value)) {
            printSpaceBeforeIdentifier()
            print("NaN")
        } else if (Float64.isInfinite(value)) {
            let isNegative = Float64.signbit(value) && !Float64.isNaN(value)
            let wrap = (level.ordinal() >= OpLevel.Multiplicative.ordinal()) ||
                       (isNegative && level.ordinal() >= OpLevel.Unary.ordinal())

            if (wrap) {
                print("(")
            }

            if (isNegative) {
                printSpaceBeforeOperator(OpCode.UnNeg)
                print("-")
            } else {
                printSpaceBeforeIdentifier()
            }

            if (isJson || (!options.minifySyntax && options.hasRunSymbolRenamer)) {
                print("Infinity")
            } else if (options.minifyWhitespace) {
                print("1/0")
            } else {
                print("1 / 0")
            }

            if (wrap) {
                print(")")
            }
        } else if (!Float64.signbit(value)) {
            printSpaceBeforeIdentifier()
            printNonNegativeFloat(Float64.abs(value))
            prevNumEnd = written
        } else if (level.ordinal() >= OpLevel.Unary.ordinal()) {
            print("(-")
            printNonNegativeFloat(Float64.abs(value))
            print(")")
        } else {
            printSpaceBeforeOperator(OpCode.UnNeg)
            print("-")
            printNonNegativeFloat(Float64.abs(value))
            prevNumEnd = written
        }
    }

    // ========================================================================
    // 标识符打印 - 对应 js_printer.zig:5263-5344
    // ========================================================================

    /// 打印标识符 - 对应 printIdentifier()
    public func printIdentifier(identifier: String): Unit {
        if (asciiOnly) {
            printIdentifierAsciiOnly(identifier)
        } else {
            print(identifier)
        }
    }

    /// 仅 ASCII 标识符打印 - 对应 printIdentifierAsciiOnly()
    public func printIdentifierAsciiOnly(identifier: String): Unit {
        var asciiStart: Int64 = 0
        var isAscii = false

        for (i in 0..Int64(identifier.length)) {
            let c = Int64(identifier[i])
            if (c >= FIRST_ASCII && c <= LAST_ASCII) {
                if (!isAscii) {
                    asciiStart = i
                    isAscii = true
                }
            } else {
                if (isAscii) {
                    print(identifier.substring(asciiStart, i))
                    isAscii = false
                }
                print("\\u{")
                print(c.toHexString().toLowerCase())
                print("}")
            }
        }

        if (isAscii) {
            print(identifier.substring(asciiStart))
        }
    }

    // ========================================================================
    // 正则表达式打印 - 对应 js_printer.zig:3247-3322
    // ========================================================================

    /// 打印正则表达式 - 对应 printRegExpLiteral()
    public func printRegExpLiteral(e: ERegExp): Unit {
        // 避免形成单行注释
        if (written > 0 && prevChar == UInt8('/')) {
            print(" ")
        }

        if (isBunPlatform) {
            // ASCII 转义非ASCII字符
            var asciiStart: Int64 = 0
            var isAscii = false
            let value = e.value

            for (i in 0..Int64(value.length)) {
                let c = Int64(value[i])
                if (c >= FIRST_ASCII && c <= LAST_ASCII) {
                    if (!isAscii) {
                        asciiStart = i
                        isAscii = true
                    }
                } else {
                    if (isAscii) {
                        print(value.substring(asciiStart, i))
                        isAscii = false
                    }
                    if (c <= 0xFFFF) {
                        print("\\u")
                        printByte(hexChar(c >> 12))
                        printByte(hexChar((c >> 8) & 15))
                        printByte(hexChar((c >> 4) & 15))
                        printByte(hexChar(c & 15))
                    } else {
                        let k = c - 0x10000
                        let lo = FIRST_HIGH_SURROGATE + ((k >> 10) & 0x3FF)
                        let hi = FIRST_LOW_SURROGATE + (k & 0x3FF)
                        print("\\u")
                        printByte(hexChar(lo >> 12))
                        printByte(hexChar((lo >> 8) & 15))
                        printByte(hexChar((lo >> 4) & 15))
                        printByte(hexChar(lo & 15))
                        print("\\u")
                        printByte(hexChar(hi >> 12))
                        printByte(hexChar((hi >> 8) & 15))
                        printByte(hexChar((hi >> 4) & 15))
                        printByte(hexChar(hi & 15))
                    }
                }
            }
            if (isAscii) {
                print(value.substring(asciiStart))
            }
        } else {
            print(e.value)
        }

        prevRegExpEnd = written
    }

    // ========================================================================
    // 注释打印 - 对应 js_printer.zig:5413-5441
    // ========================================================================

    /// 打印缩进注释 - 对应 printIndentedComment()
    public func printIndentedComment(text: String): Unit {
        if (text.startsWith("/*")) {
            // 多行注释重新缩进
            var remaining = text
            var newlineIndex = remaining.indexOf('\n')
            while (newlineIndex >= 0) {
                if (newlineIndex > 0 && remaining[newlineIndex - 1] == '\r') {
                    print(remaining.substring(0, newlineIndex - 1))
                    print("\n")
                } else {
                    print(remaining.substring(0, newlineIndex + 1))
                }
                printIndent()
                remaining = remaining.substring(newlineIndex + 1)
                newlineIndex = remaining.indexOf('\n')
            }
            print(remaining)
            printNewline()
        } else {
            // 单行注释后必须有换行
            var t = text
            if (t.length > 0 && t[t.length - 1] == '\r') {
                t = t.substring(0, t.length - 1)
            }
            print(t)
            print("\n")
        }
    }

    // ========================================================================
    // Whitespacer 打印 - 对应 js_printer.zig:1473-1479
    // ========================================================================

    /// 打印 Whitespacer - 对应 printWhitespacer()
    public func printWhitespacer(spacer: Whitespacer): Unit {
        if (options.minifyWhitespace) {
            print(spacer.minify)
        } else {
            print(spacer.normal)
        }
    }

    // ========================================================================
    // @__PURE__ 注释 - 对应 js_printer.zig:1896-1900
    // ========================================================================

    /// 打印纯函数注释 - 对应 printPure()
    public func printPure(): Unit {
        if (options.printDceAnnotations) {
            printWhitespacer(ws("/* @__PURE__ */ "))
        }
    }

    // ========================================================================
    // 初始化 - 对应 js_printer.zig:5443-5467
    // ========================================================================

    /// 初始化打印机 - 对应 init()
    public func initPrinter(renamer: Renamer, importRecords: ArrayList<ImportRecord>,
                             opts: PrinterOptions, sourceMapBuilder: SourceMapBuilder): Unit {
        this.renamer = renamer
        this.importRecords = importRecords
        this.options = opts
        this.sourceMapBuilder = sourceMapBuilder
        this.sb = StringBuilder()
        this.written = 0
        this.needsSemicolon = false
        this.stmtStart = -1
        this.exportDefaultStart = -1
        this.arrowExprStart = -1
        this.forOfInitStart = -1
        this.prevOp = OpCode.BinAdd
        this.prevOpEnd = -1
        this.prevNumEnd = -1
        this.prevRegExpEnd = -1
        this.callTarget = None
        this.hasPrintedBundledImportStatement = false
        this.prevStmtTag = StmtTag.SEmpty
        this.symbolCounter = 0
        this.binaryExpressionStack = ArrayList<BinaryExpressionVisitor>()
        this.wasLazyExport = false
    }

    // ========================================================================
    // require/import 表达式打印
    // 严格翻译自: js_printer.zig:1619-1894
    // ========================================================================

    /// 是否未绑定 eval 标识符 - 对应 isUnboundEvalIdentifier()
    public func isUnboundEvalIdentifier(value: Expr): Bool {
        match (value.tag) {
            case ExprTag.Identifier => {
                let ident = value // e_identifier
                if (value.ref.isSourceContentsSlice()) {
                    return false
                }
                let symbol = symbols().get(symbols().follow(value.ref))
                if (let some = symbol) {
                    return some.kind == SymbolKind.Unbound && some.originalName == "eval"
                }
                return false
            }
            case _ => false
        }
    }

    /// 是否未绑定标识符 - 对应 isUnboundIdentifier()
    public func isUnboundIdentifier(expr: Expr): Bool {
        if (expr.tag != ExprTag.Identifier) {
            return false
        }
        let ref = expr.ref
        let symbol = symbols().get(symbols().follow(ref))
        if (let some = symbol) {
            return some.kind == SymbolKind.Unbound
        }
        return false
    }

    /// 获取导入记录 - 对应 importRecord()
    public func importRecord(index: Int64): ImportRecord {
        return importRecords[Int64(index)]
    }

    /// 打印 require 错误 - 对应 printRequireError()
    public func printRequireError(text: String): Unit {
        print("(()=>{throw new Error(\"Cannot require module \"+")
        printStringLiteralUTF8(text, false)
        print(");})()")
    }

    /// 打印禁用导入 - 对应 printDisabledImport()
    public func printDisabledImport(): Unit {
        printWhitespacer(ws("(() => ({})"))
    }

    /// .then 前缀 - 对应 printDotThenPrefix()
    public func printDotThenPrefix(): OpLevel {
        print(".then(() => ")
        return OpLevel.Comma
    }

    /// .then 后缀 - 对应 printDotThenSuffix()
    public func printDotThenSuffix(): Unit {
        print(")")
    }

    // ========================================================================
    // 模块导入记录路径打印 - 对应 js_printer.zig:4827-4843
    // ========================================================================

    /// 打印导入记录路径 - 对应 printImportRecordPath()
    public func printImportRecordPath(record: ImportRecord): Unit {
        let quote = bestQuoteCharForString(record.pathText, false)
        printByte(quote)
        printStringCharactersUTF8(record.pathText, quote)
        printByte(quote)
    }

    // ========================================================================
    // 模块导出符号打印 - 对应 js_printer.zig:4823-4825
    // ========================================================================

    /// 打印 module.exports - 对应 printModuleExportSymbol()
    public func printModuleExportSymbol(): Unit {
        print("module.exports")
    }

    // ========================================================================
    // 模块ID打印 - 对应 js_printer.zig:4965-4978
    // ========================================================================

    /// 打印模块ID调用 - 对应 printCallModuleID()
    public func printCallModuleID(moduleId: Int64): Unit {
        printModuleId(moduleId)
        print("()")
    }

    /// 打印模块ID - 对应 printModuleId()
    public func printModuleId(moduleId: Int64): Unit {
        print("$")
        print(moduleId.toHexString().toLowerCase())
    }

    /// 打印模块ID (假设启用) - 对应 printModuleIdAssumeEnabled()
    public func printModuleIdAssumeEnabled(moduleId: Int64): Unit {
        print("$")
        print(moduleId.toHexString().toLowerCase())
    }

    // ========================================================================
    // 捆绑导出打印 - 对应 js_printer.zig:4996-5005, 4980-4989
    // ========================================================================

    /// 打印捆绑导出 - 对应 printBundledExport()
    public func printBundledExport(name: String, identifier: String): Unit {
        print("Object.defineProperty(")
        printModuleExportSymbol()
        print(",")
        printStringLiteralUTF8(name, true)
        print(",{get: () => ")
        printIdentifier(identifier)
        print(", enumerable: true, configurable: true})")
    }

    /// 打印捆绑重导出 - 对应 printBundledRexport()
    public func printBundledRexport(name: String, importRecordIndex: Int64): Unit {
        print("Object.defineProperty(")
        printModuleExportSymbol()
        print(",")
        printStringLiteralUTF8(name, true)
        printWhitespacer(ws(",{get: () => ("))
        printLoadFromBundle(importRecordIndex)
        printWhitespacer(ws("), enumerable: true, configurable: true})"))
    }

    /// 从包中加载打印 - 对应 printLoadFromBundle()
    public func printLoadFromBundle(importRecordIndex: Int64): Unit {
        printLoadFromBundleWithoutCall(importRecordIndex)
        print("()")
    }

    /// 从包中加载打印(无调用) - 对应 printLoadFromBundleWithoutCall()
    public func printLoadFromBundleWithoutCall(importRecordIndex: Int64): Unit {
        let record = importRecord(importRecordIndex)
        if (record.pathIsDisabled) {
            printDisabledImport()
            return
        }
        printModuleId(record.moduleId)
    }

    // ========================================================================
    // 禁用导入打印
    // ========================================================================

    /// 内联禁用导入打印
    public func printDisabledImportInline(): Unit {
        printWhitespacer(ws("(() => ({})"))
    }

    // ========================================================================
    // 初始化器打印 - 对应 js_printer.zig:3610-3615
    // ========================================================================

    /// 打印初始化器 - 对应 printInitializer()
    public func printInitializer(initial: Expr): Unit {
        printSpace()
        print("=")
        printSpace()
        printExpr(initial, OpLevel.Comma, ExprFlags.none())
    }

    // ========================================================================
    // 默认绑定值打印 - 对应 js_printer.zig:3798-3805
    // ========================================================================

    /// 可能打印默认绑定值 - 对应 maybePrintDefaultBindingValue()
    public func maybePrintDefaultBindingValue(property: BProperty): Unit {
        if (let defaultVal = property.defaultValue) {
            printSpace()
            print("=")
            printSpace()
            printExpr(defaultVal, OpLevel.Comma, ExprFlags.none())
        }
    }

    // ========================================================================
    // 命名空间别名打印 - 对应 js_printer.zig:3227-3245
    // ========================================================================

    /// 打印命名空间别名 - 对应 printNamespaceAlias()
    public func printNamespaceAlias(record: ImportRecord, namespace: GNamespaceAlias): Unit {
        printSymbol(namespace.namespaceRef)

        if (namespace.alias.length == 0) {
            return
        }

        if (isIdentifierStr(namespace.alias)) {
            print(".")
            printIdentifier(namespace.alias)
        } else {
            print("[")
            printStringLiteralUTF8(namespace.alias, false)
            print("]")
        }
    }

    // ========================================================================
    // 获取结果
    // ========================================================================

    /// 获取输出字符串
    public func getResult(): String {
        return sb.toString()
    }

    /// 重置打印机
    public func reset(): Unit {
        sb = StringBuilder()
        written = 0
        needsSemicolon = false
        stmtStart = -1
        exportDefaultStart = -1
        arrowExprStart = -1
        forOfInitStart = -1
        prevOp = OpCode.BinAdd
        prevOpEnd = -1
        prevNumEnd = -1
        prevRegExpEnd = -1
        callTarget = None
        hasPrintedBundledImportStatement = false
        prevStmtTag = StmtTag.SEmpty
        symbolCounter = 0
        binaryExpressionStack = ArrayList<BinaryExpressionVisitor>()
    }
}

// ============================================================================
// PrinterOptions - 打印选项
// 严格翻译自: js_printer.zig:378-452
// ============================================================================

/// 打印选项 - 对应 Bun Options
public class PrinterOptions {
    /// 是否捆绑模式 - 对应 bundling
    public var bundling: Bool
    /// 是否转换导入 - 对应 transform_imports
    public var transformImports: Bool
    /// to_commonjs 引用 - 对应 to_commonjs_ref
    public var toCommonjsRef: Ref
    /// to_esm 引用 - 对应 to_esm_ref
    public var toEsmRef: Ref
    /// require 引用 - 对应 require_ref
    public var requireRef: ?Ref
    /// import.meta 引用 - 对应 import_meta_ref
    public var importMetaRef: Ref
    /// HMR 引用 - 对应 hmr_ref
    public var hmrRef: Ref
    /// 缩进 - 对应 indent
    public var indent: Indentation
    /// 模块哈希 - 对应 module_hash
    public var moduleHash: Int64
    /// 是否压缩空白 - 对应 minify_whitespace
    public var minifyWhitespace: Bool
    /// 是否压缩标识符 - 对应 minify_identifiers
    public var minifyIdentifiers: Bool
    /// 是否压缩语法 - 对应 minify_syntax
    public var minifySyntax: Bool
    /// 是否打印 DCE 注解 - 对应 print_dce_annotations
    public var printDceAnnotations: Bool
    /// 是否仅转换 - 对应 transform_only
    public var transformOnly: Bool
    /// 是否内联 require 和 import 错误 - 对应 inline_require_and_import_errors
    public var inlineRequireAndImportErrors: Bool
    /// 是否已运行符号重命名器 - 对应 has_run_symbol_renamer
    public var hasRunSymbolRenamer: Bool
    /// 模块类型 - 对应 module_type (Format)
    public var moduleType: PrintFormat
    /// 是否懒导出
    public var wasLazyExport: Bool
    /// 目标平台
    public var target: String
    /// CommonJS 命名导出
    public var commonjsNamedExports: HashMap<String, NamedExport>
    /// CommonJS 命名导出已去优化
    public var commonjsNamedExportsDeoptimized: Bool
    /// CommonJS module.exports 已去优化
    public var commonjsModuleExportsAssignedDeoptimized: Bool
    /// CommonJS 命名导出引用
    public var commonjsNamedExportsRef: Ref
    /// CommonJS 模块引用
    public var commonjsModuleRef: Ref
    /// 混淆属性名映射 - 对应 mangled_props
    public var mangledProps: ?HashMap<Ref, String>

    public init() {
        bundling = false
        transformImports = true
        toCommonjsRef = Ref.NONE
        toEsmRef = Ref.NONE
        requireRef = None
        importMetaRef = Ref.NONE
        hmrRef = Ref.NONE
        indent = Indentation()
        moduleHash = 0
        minifyWhitespace = false
        minifyIdentifiers = false
        minifySyntax = false
        printDceAnnotations = true
        transformOnly = false
        inlineRequireAndImportErrors = true
        hasRunSymbolRenamer = false
        moduleType = PrintFormat.Esm
        wasLazyExport = false
        target = "browser"
        commonjsNamedExports = HashMap<String, NamedExport>()
        commonjsNamedExportsDeoptimized = false
        commonjsModuleExportsAssignedDeoptimized = false
        commonjsNamedExportsRef = Ref.NONE
        commonjsModuleRef = Ref.NONE
        mangledProps = None
    }
}

// ============================================================================
// StmtTag - 语句标签 (用于 prev_stmt_tag)
// ============================================================================

public enum StmtTag {
    | SEmpty
    | SComment
    | SFunction
    | SClass
    | SExportDefault
    | SExportStar
    | SExportClause
    | SExportFrom
    | SLocal
    | SIf
    | SDoWhile
    | SForIn
    | SForOf
    | SWhile
    | SWith
    | SLabel
    | STry
    | SFor
    | SSwitch
    | SImport
    | SBlock
    | SDebugger
    | SDirective
    | SBreak
    | SContinue
    | SReturn
    | SThrow
    | SExpr

    public func isExportLike(): Bool {
        match (this) {
            case SExportDefault | SExportStar | SExportClause | SExportFrom => true
            case _ => false
        }
    }
}

// ============================================================================
// AST 数据类型占位 (在 ast.cj 中定义, 这里引用)
// ============================================================================

/// EString - 字符串表达式数据
/// 对应 Bun E.String
public class EString {
    public var data: String
    public var isUTF8: Bool
    public var preferTemplate: Bool

    public init(data: String) {
        this.data = data
        isUTF8 = true
        preferTemplate = false
    }

    public init(data: String, isUTF8: Bool, preferTemplate: Bool) {
        this.data = data
        this.isUTF8 = isUTF8
        this.preferTemplate = preferTemplate
    }
}

/// ERegExp - 正则表达式数据
/// 对应 Bun E.RegExp
public class ERegExp {
    public var value: String

    public init(value: String) {
        this.value = value
    }
}

/// EBinary - 二元表达式数据
/// 对应 Bun E.Binary
public class EBinary {
    public var left: Expr
    public var right: Expr
    public var op: OpCode

    public init(left: Expr, right: Expr, op: OpCode) {
        this.left = left
        this.right = right
        this.op = op
    }
}

/// SImport - import 语句数据
/// 对应 Bun S.Import
public class SImport {
    public var importRecordIndex: Int64
    public var namespaceRef: Ref
    public var defaultName: ?LocRef
    public var items: ArrayList<ClauseItem>
    public var starNameLoc: ?Loc
    public var isSingleLine: Bool

    public init() {
        importRecordIndex = 0
        namespaceRef = Ref.NONE
        defaultName = None
        items = ArrayList<ClauseItem>()
        starNameLoc = None
        isSingleLine = true
    }
}

/// ClauseItem - 导入/导出子句项
/// 对应 Bun ClauseItem
public class ClauseItem {
    public var alias: String
    public var aliasLoc: Loc
    public var name: LocRef
    public var originalName: String

    public init() {
        alias = ""
        aliasLoc = Loc.EMPTY
        name = LocRef()
        originalName = ""
    }

    public init(alias: String, aliasLoc: Loc, name: LocRef, originalName: String) {
        this.alias = alias
        this.aliasLoc = aliasLoc
        this.name = name
        this.originalName = originalName
    }
}

/// LocRef - 位置+引用
public class LocRef {
    public var loc: Loc
    public var ref: ?Ref

    public init() {
        loc = Loc.EMPTY
        ref = None
    }

    public init(loc: Loc, ref: Ref) {
        this.loc = loc
        this.ref = ref
    }
}

/// BProperty - 绑定属性
/// 对应 Bun B.Property
public class BProperty {
    public var key: ?Expr
    public var value: Binding
    public var defaultValue: ?Expr
    public var flags: BPropertyFlags

    public init() {
        key = None
        value = Binding()
        defaultValue = None
        flags = BPropertyFlags()
    }
}

/// BPropertyFlags - 绑定属性标志
public class BPropertyFlags {
    public var isSpread: Bool
    public var isComputed: Bool
    public var wasShorthand: Bool

    public init() {
        isSpread = false
        isComputed = false
        wasShorthand = false
    }
}

/// GNamespaceAlias - 命名空间别名
/// 对应 Bun G.NamespaceAlias
public class GNamespaceAlias {
    public var namespaceRef: Ref
    public var alias: String
    public var importRecordIndex: Int64
    public var wasOriginallyPropertyAccess: Bool

    public init() {
        namespaceRef = Ref.NONE
        alias = ""
        importRecordIndex = 0
        wasOriginallyPropertyAccess = false
    }
}

/// Binding - 绑定节点占位
public class Binding {
    public var loc: Loc
    public var tag: BindingTag
    public var ref: Ref

    public init() {
        loc = Loc.EMPTY
        tag = BindingTag.BMissing
        ref = Ref.NONE
    }
}

public enum BindingTag {
    | BMissing
    | BIdentifier
    | BArray
    | BObject
}

// ============================================================================
// ImportRecord - 导入记录 (简化版)
// 对应 Bun ImportRecord
// ============================================================================

/// 导入记录 - 对应 Bun ImportRecord
public class ImportRecord {
    public var pathText: String
    public var pathPretty: String
    public var pathNamespace: String
    public var pathIsDisabled: Bool
    public var pathIsFile: Bool
    public var moduleId: Int64
    public var flags: ImportRecordFlags
    public var tag: ImportRecordTag
    public var kind: ImportRecordKind
    public var sourceIndex: SourceIndex
    public var range: Range
    public var loader: ?String

    public init() {
        pathText = ""
        pathPretty = ""
        pathNamespace = ""
        pathIsDisabled = false
        pathIsFile = true
        moduleId = 0
        flags = ImportRecordFlags()
        tag = ImportRecordTag.None
        kind = ImportRecordKind.Statement
        sourceIndex = SourceIndex.invalid()
        range = Range.NONE
        loader = None
    }
}

/// 导入记录标签
public enum ImportRecordTag {
    | None
    | Bun
    | Builtin
}

/// 导入记录种类
public enum ImportRecordKind {
    | Statement
    | Dynamic
    | Require

    public func isCommonJS(): Bool {
        match (this) {
            case Require => true
            case _ => false
        }
    }
}

/// SourceIndex 占位
public class SourceIndex {
    public var value: Int64

    public init(value: Int64) {
        this.value = value
    }

    public static func invalid(): SourceIndex {
        return SourceIndex(-1)
    }

    public func isValid(): Bool {
        return value >= 0
    }

    public func get(): Int64 {
        return value
    }
}

// ============================================================================
// NamedExport - 命名导出
// ============================================================================

/// 命名导出 - 对应 Bun NamedExport
public class NamedExport {
    public var ref: Ref
    public var loc: Loc

    public init() {
        ref = Ref.NONE
        loc = Loc.EMPTY
    }
}

// ============================================================================
// SymbolKind - 符号类型
// ============================================================================

public enum SymbolKind {
    | Unbound
    | TsEnum
    | Other
}

/// 符号占位
public class Symbol {
    public var originalName: String
    public var kind: SymbolKind
    public var namespaceAlias: ?GNamespaceAlias
    public var importItemStatus: ImportItemStatus
    public var mustNotBeRenamed: Bool

    public init() {
        originalName = ""
        kind = SymbolKind.Other
        namespaceAlias = None
        importItemStatus = ImportItemStatus.Present
        mustNotBeRenamed = false
    }
}

public enum ImportItemStatus {
    | Present
    | Missing
}

/// 符号映射占位
public class SymbolMap {
    public func follow(ref: Ref): Ref {
        return ref
    }

    public func get(ref: Ref): ?Symbol {
        return None
    }

    public func getWithLink(ref: Ref): ?Symbol {
        return get(ref)
    }
}

/// Ref 引用占位
public class Ref {
    public var innerIndex: Int64
    public var sourceIndex: Int64

    public init() {
        innerIndex = 0
        sourceIndex = 0
    }

    public init(innerIndex: Int64, sourceIndex: Int64) {
        this.innerIndex = innerIndex
        this.sourceIndex = sourceIndex
    }

    public static let NONE: Ref = Ref()

    public func isNull(): Bool {
        return innerIndex == 0 && sourceIndex == 0
    }

    public func isValid(): Bool {
        return !isNull()
    }

    public func isSourceContentsSlice(): Bool {
        return false
    }

    public func sourceIndex(): Int64 {
        return sourceIndex
    }

    public func innerIndex(): Int64 {
        return innerIndex
    }

    public func eql(other: Ref): Bool {
        return innerIndex == other.innerIndex && sourceIndex == other.sourceIndex
    }
}

// ============================================================================
// 辅助判断函数
// ============================================================================

/// 判断字符串是否是有效标识符
public func isIdentifierStr(name: String): Bool {
    if (name.length == 0) {
        return false
    }
    let first = Int64(name[0])
    if (!((first >= 97 && first <= 122) || (first >= 65 && first <= 90) ||
          first == 95 || first == 36)) {
        return false
    }
    for (i in 1..Int64(name.length)) {
        let c = Int64(name[i])
        if (!((c >= 97 && c <= 122) || (c >= 65 && c <= 90) ||
              (c >= 48 && c <= 57) || c == 95 || c == 36)) {
            return false
        }
    }
    return true
}

/// 是否包含非BMP码点或无效标识符 - 对应 containsNonBmpCodePointOrIsInvalidIdentifier
public func containsNonBmpCodePointOrIsInvalidIdentifier(alias: String): Bool {
    return !isIdentifierStr(alias)
}

/// LoggerSource 占位
public class LoggerSource {
    public var pathText: String
    public var contents: String
    public var index: SourceIndex

    public init() {
        pathText = ""
        contents = ""
        index = SourceIndex.invalid()
    }
}
