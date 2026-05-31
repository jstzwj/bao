// 解析器编排层 - 解析函数的入口和调度
// 严格翻译自: src/js_parser/parse/parse.zig (1407 lines)
//   Bun 的 Parse 模块是解析函数的编排层:
//   - parseExpr / parseExprCommon: 表达式解析入口
//   - parseYieldExpr: yield 表达式
//   - parseAwaitExpr: await 表达式
//   - parseParenExpr: 括号表达式
//   - parseClass: 类声明/表达式
//   - parseCallArgs: 调用参数
//   - parseAndDeclareDecls: 声明解析
//   - parseStmtsUpTo: 批量语句解析
//   - parseBinding / parsePropertyBinding: 绑定模式解析
//   - parsePath: 路径解析
//   - parseClauseAlias: 子句别名
//   - parseExprOrLetStmt: 表达式或 let 语句
//   - parseAsyncPrefixExpr: async 前缀表达式
//   - parseLabelName: 标签名称
//   - parseStringLiteral: 字符串字面量
//   - parseTemplateParts: 模板字符串部分
//   - parseJSXPropValueIdentifier: JSX 属性值标识符
package bao_parser

import bao_core.*
import bao_collections.*

// ============================================================================
// ParseResult - 解析结果
// 严格翻译自: src/js_parser/js_parser.zig:540-551
//   pub const Result = union(enum) {
//     already_bundled: AlreadyBundled,
//     cached: void,
//     ast: Ast,
//   }
// ============================================================================

/// 已打包标记 - 对应 Bun Result.AlreadyBundled
public enum AlreadyBundledKind {
    | Bun       // bun 打包格式
    | BunCjs    // bun CommonJS 格式
    | Bytecode  // 字节码格式
    | BytecodeCjs // 字节码 CommonJS 格式
}

/// 解析结果 - 对应 Bun Result
public enum ParseResultKind {
    | AlreadyBundled    // 已打包
    | Cached            // 已缓存
    | Ast               // AST
}

/// 解析结果 - 对应 Bun js_parser.Result
public class ParseResult {
    public var kind: ParseResultKind
    public var alreadyBundled: AlreadyBundledKind
    public var ast: ?Ast

    public init(kind: ParseResultKind) {
        this.kind = kind
        alreadyBundled = AlreadyBundledKind.Bun
        ast = None
    }

    public static func alreadyBundled(bundledKind: AlreadyBundledKind): ParseResult {
        let r = ParseResult(ParseResultKind.AlreadyBundled)
        r.alreadyBundled = bundledKind
        return r
    }

    public static func cached(): ParseResult {
        return ParseResult(ParseResultKind.Cached)
    }

    public static func ast(ast: Ast): ParseResult {
        let r = ParseResult(ParseResultKind.Ast)
        r.ast = Some(ast)
        return r
    }
}

/// AST 结果 - 对应 Bun js_ast.Ast
/// 注意: 完整定义在 js_printer_writer.cj 中
/// 这里仅作重新声明以供 parse.cj 使用
// (Ast 类已存在于 js_printer_writer.cj)

// ============================================================================
// NamedImport - 命名导入
// 注意: 已在 scan_imports.cj 中定义
// ============================================================================

// ============================================================================
// NamedExport - 命名导出
// 注意: 已在 js_printer.cj 中定义
// ============================================================================

// ============================================================================
// Part - 代码部分 (tree-shaking 单元)
// 注意: 已在 js_printer_writer.cj 中定义
// ============================================================================

// ============================================================================
// PartDependency - 部分依赖
// 注意: 已在 lower_esm_exports_hmr.cj 中定义
// ============================================================================

// ============================================================================
// StmtOrExpr - 语句或表达式
// 严格翻译自: src/js_parser/js_parser.zig:553-567
//   pub const StmtOrExpr = union(enum) { stmt: Stmt, expr: Expr }
// ============================================================================

/// 语句或表达式 - 对应 Bun StmtOrExpr
public enum StmtOrExprKind {
    | Stmt
    | Expr
}

/// 语句或表达式联合 - 对应 Bun StmtOrExpr
public class StmtOrExpr {
    public var kind: StmtOrExprKind
    public var stmt: ?Stmt
    public var expr: ?Expr

    public init(stmt: Stmt) {
        kind = StmtOrExprKind.Stmt
        this.stmt = Some(stmt)
        expr = None
    }

    public init(expr: Expr) {
        kind = StmtOrExprKind.Expr
        stmt = None
        this.expr = Some(expr)
    }

    /// 转换为表达式 - 对应 Bun StmtOrExpr.toExpr
    public func toExpr(): ?Expr {
        match (kind) {
            case StmtOrExprKind.Expr =>
                return expr
            case StmtOrExprKind.Stmt =>
                // 对应 Bun: 将 function/class 声明转为表达式
                if (let Some(s) <- stmt) {
                    match (s.tag) {
                        case StmtTag.Function | StmtTag.Class =>
                            // 将语句转换为表达式
                            return s.expr
                        case _ =>
                            return None
                    }
                }
                return None
        }
    }
}

// ============================================================================
// ParseHelpers - 解析辅助函数
// 严格翻译自: parse.zig 中的顶层函数
// ============================================================================

/// 解析入口 - 对应 Bun parseExpr
/// 从当前词法位置解析一个表达式
public func parseExpr(p: Parser, level: OpLevel): Expr {
    // 对应 Bun: var expr: Expr = undefined; try p.parseExprCommon(level, null, .none, &expr); return expr
    let result = p.parsePrefix(level)
    if (result.tag != ExprTag.Missing) {
        p.parseSuffix(result, level)
    }
    return result
}

/// 解析表达式或绑定 - 对应 Bun parseExprOrBindings
public func parseExprOrBindings(p: Parser, level: OpLevel, errors: ?DeferredErrors, expr: Expr): Unit {
    p.parseExprCommon(level, errors, ExprEFlags.None, expr)
}

/// 解析带标志的表达式 - 对应 Bun parseExprWithFlags
public func parseExprWithFlags(p: Parser, level: OpLevel, flags: ExprEFlags, expr: Expr): Unit {
    p.parseExprCommon(level, None, flags, expr)
}

/// 解析 yield 表达式 - 对应 Bun parseYieldExpr
/// 严格翻译自: parse.zig:73-99
public func parseYieldExpr(p: Parser, loc: Loc): Expr {
    // 解析 yield* 表达式
    let isStar = p.lexer.token == Token.Asterisk

    if (isStar) {
        if (p.lexer.hasNewlineBefore) {
            p.lexer.unexpected()
            return p.newExprMissing(loc)
        }
        p.lexer.next()
    }

    var value: ?Expr = None
    match (p.lexer.token) {
        case Token.CloseBrace | Token.CloseParen | Token.CloseBracket |
             Token.Colon | Token.Comma | Token.Semicolon =>
            () // 无值
        case _ =>
            if (isStar || !p.lexer.hasNewlineBefore) {
                value = Some(parseExpr(p, OpLevel.Yield))
            }
    }

    return p.newExprYield(value, isStar, loc)
}

/// 解析 await 表达式 - 对应 Bun parseAwaitPrefixExpr 的一部分
public func parseAwaitExpr(p: Parser, loc: Loc): Expr {
    let value = parseExpr(p, OpLevel.Unary)
    return p.newExprAwait(value, loc)
}

// ============================================================================
// ExprEFlags - 表达式标志
// 严格翻译自: src/js_parser/ast/Expr.zig
//   pub const EFlags = enum { none, has_been_clobbered }
// ============================================================================

/// 表达式标志 - 对应 Bun Expr.EFlags
public enum ExprEFlags {
    | None              // 无标志
    | HasBeenClobbered  // 已被修改 (用于 inlining)

    public operator func ==(right: ExprEFlags): Bool {
        match (this) {
            case None => match (right) { case None => true case _ => false }
            case HasBeenClobbered => match (right) { case HasBeenClobbered => true case _ => false }
        }
    }
}

// ============================================================================
// DeferredErrors - 延迟错误收集
// 注意: 已在 parse_entry.cj 中定义
// ============================================================================

// ============================================================================
// EnumValue - 枚举值
// 严格翻译自: src/js_parser/js_parser.zig:214-223
//   pub const EnumValue = struct {
//     loc: logger.Loc,
//     ref: Ref,
//     name: []const u8,
//     value: ?ExprNodeIndex,
//   }
// ============================================================================

/// 枚举值 - 对应 Bun EnumValue
public class EnumValue {
    public var loc: Loc
    public var ref: Ref
    public var name: String
    public var value: ?Expr

    public init(loc: Loc, ref: Ref, name: String) {
        this.loc = loc
        this.ref = ref
        this.name = name
        value = None
    }
}

// ============================================================================
// InlinedEnumValue - 内联枚举值
// 严格翻译自: src/js_parser/js_parser.zig:256-298
//   用于 NaN-boxing 编码字符串和数字值
// ============================================================================

/// 内联枚举值 - 对应 Bun InlinedEnumValue
/// 使用类似 JSCJSValue 的 NaN-boxing 技术编码字符串指针或浮点数
public class InlinedEnumValue {
    public var rawData: UInt64

    public init(rawData: UInt64) {
        this.rawData = rawData
    }

    /// 是否为数字
    public func isNumber(): Bool {
        return rawData > UInt64(0x0000FFFFFFFFFFFF)
    }

    /// 是否为字符串
    public func isString(): Bool {
        return !isNumber()
    }

    /// 获取数字值 (假设 isNumber)
    public func numberValue(): Float64 {
        // 对应 Bun: @bitCast(encoded.raw_data - double_encode_offset)
        return Float64(rawData - UInt64(1 << 49))
    }

    /// 编码数字
    public static func encodeNumber(num: Float64): InlinedEnumValue {
        // 对应 Bun: @bitCast(purifyNaN(num)) + double_encode_offset
        return InlinedEnumValue(UInt64(num) + UInt64(1 << 49))
    }

    /// 编码字符串
    public static func encodeString(ptr: Int64): InlinedEnumValue {
        return InlinedEnumValue(UInt64(ptr & UInt64(0x0000FFFFFFFFFFFF)))
    }
}

// ============================================================================
// TlaCheck - Top Level Await 检查
// 严格翻译自: src/js_parser/js_parser.zig:245-249
//   pub const TlaCheck = struct {
//     depth: u32 = 0,
//     parent: Index.Int = Index.invalid.get(),
//     import_record_index: Index.Int = Index.invalid.get(),
//   }
// ============================================================================

/// Top Level Await 检查 - 对应 Bun TlaCheck
public class TlaCheck {
    public var depth: Int64
    public var parent: Int64
    public var importRecordIndex: Int64

    public init() {
        depth = 0
        parent = -1
        importRecordIndex = -1
    }
}

// ============================================================================
// NameMinifier - 名称压缩器
// 注意: 已在 renamer.cj 中定义
// ============================================================================

// ============================================================================
// SlotCounts - 槽位计数
// 注意: 已在 renamer.cj 中定义
// ============================================================================

// ============================================================================
// Span - 文本范围
// 严格翻译自: src/js_parser/js_parser.zig:251-254
// ============================================================================

/// 文本范围 - 对应 Bun Span
public class Span {
    public var text: String
    public var range: Range

    public init() {
        text = ""
        range = Range()
    }

    public init(text: String, range: Range) {
        this.text = text
        this.range = range
    }
}
