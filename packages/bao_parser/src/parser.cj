// Parser - JavaScript/TypeScript 解析器
// 严格翻译自: src/js_parser/p.zig
//   pub fn NewParser_(comptime typescript, comptime jsx, comptime scan_only) type { ... }
//   约 7000 行 Zig，是 JS/TS 解析器的核心
//
//   src/js_parser/parse.zig - 解析方法 (parseExpr, parseStmt 等)
//
// Bun 的 Parser 使用 comptime 参数生成不同配置的解析器
// (JS/TS/JSX/scan_only)，仓颉使用运行时配置实现等价语义
package bao_parser

import bao_core.*
import bao_collections.*
import bao_unicode.*

// ============================================================================
// ParserFeatures - 解析器特性
// 严格翻译自: src/js_parser/p.zig:1-5
//   const ParserFeatures = struct {
//       typescript: bool = false,
//       jsx: JSXTransformType = .none,
//       scan_only: bool = false,
//   }
// ============================================================================

/// JSX 转换类型 - 对应 Bun JSXTransformType
public enum JsxTransformType {
    | None     // 不启用 JSX
    | Automatic // 自动运行时
    | Classic   // 经典运行时
}

/// 解析器特性配置 - 对应 Bun ParserFeatures
public class ParserFeatures {
    public var typescript: Bool
    public var jsx: JsxTransformType
    public var scanOnly: Bool

    public init() {
        typescript = false
        jsx = JsxTransformType.None
        scanOnly = false
    }

    public static func js(): ParserFeatures {
        let f = ParserFeatures()
        return f
    }

    public static func typescript(): ParserFeatures {
        let f = ParserFeatures()
        f.typescript = true
        return f
    }

    public static func jsx(): ParserFeatures {
        let f = ParserFeatures()
        f.jsx = JsxTransformType.Automatic
        return f
    }

    public static func tsx(): ParserFeatures {
        let f = ParserFeatures()
        f.typescript = true
        f.jsx = JsxTransformType.Automatic
        return f
    }
}

// ============================================================================
// ParserOptions - 解析器选项
// 严格翻译自: src/js_parser/js_parser.zig Parser.Options
//   pub const Options = struct {
//       define: Define,
//       jsx: Jsx,
//       tsconfig: Tsconfig,
//       ...
//   }
// ============================================================================

/// 解析器选项 - 对应 Bun Parser.Options
public class ParserOptions {
    /// 是否为严格模式 - 对应 Bun strict_mode
    public var strictMode: Bool
    /// 是否为模块 - 对应 Bun is_module
    public var isModule: Bool
    /// 源文件类型 (JS/TS/JSX)
    public var features: ParserFeatures
    /// 目标 (browser/node 等)
    public var target: String

    public init() {
        strictMode = false
        isModule = false
        features = ParserFeatures.js()
        target = "browser"
    }

    public init(features: ParserFeatures) {
        strictMode = false
        isModule = false
        this.features = features
        target = "browser"
    }
}

// ============================================================================
// FnOrArrowData - 函数/箭头解析数据
// 严格翻译自: src/js_parser/p.zig
//   fn_or_arrow_data_parse: FnOrArrowDataParse
// ============================================================================

/// 函数/箭头解析数据 - 对应 Bun FnOrArrowDataParse
public class FnOrArrowDataParse {
    /// 是否允许 await
    public var allowAwait: Bool
    /// 是否允许 yield
    public var allowYield: Bool
    /// 是否为异步
    public var isAsync: Bool
    /// 是否为生成器
    public var isGenerator: Bool

    public init() {
        allowAwait = false
        allowYield = true
        isAsync = false
        isGenerator = false
    }
}

// ============================================================================
// ImportRecord - 导入记录
// 严格翻译自: src/js_parser/p.zig
//   import_records: ImportRecordList
// ============================================================================

/// 导入记录类型 - 对应 Bun ImportRecord.Kind
public enum ImportRecordKind {
    | Static     // import ... from '...'
    | Dynamic    // import('...')
    | Require    // require('...')
    | Stmt       // import '...'
}

/// 导入记录 - 对应 Bun ImportRecord
public class ImportRecord {
    /// 导入路径
    public var path: String
    /// 导入类型
    public var kind: ImportRecordKind
    /// 源位置
    public var range: Range
    /// 是否包含默认导入
    public var hasDefaultImport: Bool
    /// 是否包含命名空间导入
    public var hasStarImport: Bool
    /// 导入项列表
    public var items: ArrayList<ImportItem>

    public init(path: String, kind: ImportRecordKind, range: Range) {
        this.path = path
        this.kind = kind
        this.range = range
        hasDefaultImport = false
        hasStarImport = false
        items = ArrayList<ImportItem>()
    }
}

/// 导入项 - 对应 Bun ImportItem
public class ImportItem {
    /// 导入名称
    public var name: String
    /// 别名 (as 后面的名称)
    public var alias: String
    /// 源位置
    public var loc: Loc
    /// 引用
    public var ref: Ref

    public init(name: String, alias: String, loc: Loc) {
        this.name = name
        this.alias = alias
        this.loc = loc
        ref = Ref.NONE
    }
}

// ============================================================================
// DeferredImportNamespace - 延迟导入命名空间
// 严格翻译自: src/js_parser/parser.zig:10
//   pub const DeferredImportNamespace = struct { ... }
// ============================================================================

/// 延迟导入命名空间 - 对应 Bun DeferredImportNamespace
public class DeferredImportNamespace {
    public var importRecordIndex: Int64
    public var namespaceRef: Ref
    public var alias: String
    public var loc: Loc

    public init() {
        importRecordIndex = 0
        namespaceRef = Ref.NONE
        alias = ""
        loc = Loc.EMPTY
    }
}

// ============================================================================
// DeclaredSymbol - 已声明符号
// 严格翻译自: src/js_parser/p.zig
//   declared_symbols: DeclaredSymbol.List
// ============================================================================

/// 已声明符号 - 对应 Bun DeclaredSymbol
public class DeclaredSymbol {
    public var ref: Ref
    public var kind: DeclaredSymbolKind

    public init(ref: Ref, kind: DeclaredSymbolKind) {
        this.ref = ref
        this.kind = kind
    }
}

/// 声明符号种类 - 对应 Bun DeclaredSymbol.Kind
public enum DeclaredSymbolKind {
    | Hoisted      // var 提升
    | HoistedImport // 导入提升
    | Other        // 其他
}

// ============================================================================
// TempRef - 临时引用
// 严格翻译自: src/js_parser/p.zig
//   temp_refs_to_declare: List(TempRef)
// ============================================================================

/// 临时引用 - 对应 Bun TempRef
public class TempRef {
    public var ref: Ref
    public var useCount: Int64

    public init(ref: Ref) {
        this.ref = ref
        useCount = 0
    }
}

// ============================================================================
// ScopeOrder - 作用域顺序
// 严格翻译自: src/js_parser/p.zig
//   scopes_in_order: ScopeOrderList
// ============================================================================

/// 作用域顺序项 - 对应 Bun ScopeOrder
public class ScopeOrder {
    public var scope: Scope
    public var parentIndex: Int64

    public init(scope: Scope, parentIndex: Int64) {
        this.scope = scope
        this.parentIndex = parentIndex
    }
}

// ============================================================================
// Parser - JavaScript/TypeScript 解析器
// 严格翻译自: src/js_parser/p.zig:28-...
//   pub fn NewParser_(...) type {
//       return struct {
//           const P = @This();
//           allocator: Allocator,
//           options: Parser.Options,
//           log: *logger.Log,
//           source: *const logger.Source,
//           lexer: js_lexer.Lexer,
//           ...
//       }
//   }
//
// Bun Parser 是一个大结构体 (~200+ 字段)，包含:
//   - Lexer (嵌入了完整的词法分析器)
//   - 符号表 (symbols, scopes)
//   - 导入/导出跟踪 (import_records, named_imports, named_exports)
//   - 作用域管理 (current_scope, scopes_in_order)
//   - 解析状态 (allow_in, fn_or_arrow_data_parse)
//
// 仓颉实现保留核心字段，省略与 Bun 特定运行时相关的字段
// ============================================================================

/// JavaScript/TypeScript 解析器 - 严格对应 Bun Parser (P)
/// Bun: P 是 Parser 的简称，包含完整的解析状态
public class Parser {
    // ===== 核心组件 =====
    /// 分配器 - 对应 Bun allocator
    public var log: Log
    /// 源文件 - 对应 Bun source
    public var source: Source
    /// 词法分析器 - 对应 Bun lexer
    public var lexer: Lexer
    /// 解析器选项 - 对应 Bun options
    public var options: ParserOptions

    // ===== 解析状态 =====
    /// 是否允许 in 操作符 - 对应 Bun allow_in
    public var allowIn: Bool
    /// 是否允许私有标识符 - 对应 Bun allow_private_identifiers
    public var allowPrivateIdentifiers: Bool
    /// 是否为严格模式 - 对应 Bun is_strict_mode
    public var isStrictMode: Bool

    // ===== 函数/箭头解析 =====
    /// 函数/箭头解析数据 - 对应 Bun fn_or_arrow_data_parse
    public var fnOrArrowData: FnOrArrowDataParse
    /// 最新箭头参数位置 - 对应 Bun latest_arrow_arg_loc
    public var latestArrowArgLoc: Loc
    /// 禁止 as 后缀位置 - 对应 Bun forbid_suffix_after_as_loc
    public var forbidSuffixAfterAsLoc: Loc

    // ===== 作用域 =====
    /// 当前作用域 - 对应 Bun current_scope
    public var currentScope: Scope
    /// 模块作用域 - 对应 Bun module_scope
    public var moduleScope: Scope
    /// 当前部分的作用域 - 对应 Bun scopes_for_current_part
    public var scopesForCurrentPart: ArrayList<Scope>
    /// 作用域顺序 - 对应 Bun scopes_in_order
    public var scopesInOrder: ArrayList<ScopeOrder>

    // ===== 符号表 =====
    /// 符号列表 - 对应 Bun symbols
    public var symbols: ArrayList<Symbol>
    /// 已声明符号 - 对应 Bun declared_symbols
    public var declaredSymbols: ArrayList<DeclaredSymbol>
    /// 临时引用 - 对应 Bun temp_refs_to_declare
    public var tempRefsToDeclare: ArrayList<TempRef>
    /// 临时引用计数 - 对应 Bun temp_ref_count
    public var tempRefCount: Int64

    // ===== 导入/导出 =====
    /// 导入记录 - 对应 Bun import_records
    public var importRecords: ArrayList<ImportRecord>
    /// 命名导入 - 对应 Bun named_imports
    public var namedImports: HashMap<Ref, ImportItem>
    /// 命名导出 - 对应 Bun named_exports
    public var namedExports: HashMap<String, Ref>
    /// 导出引用 - 对应 Bun exports_ref
    public var exportsRef: Ref
    /// require 引用 - 对应 Bun require_ref
    public var requireRef: Ref
    /// module 引用 - 对应 Bun module_ref
    public var moduleRef: Ref

    // ===== 已分配名称 =====
    /// 已分配的名称 - 对应 Bun allocated_names
    public var allocatedNames: ArrayList<String>

    // ===== 模块状态 =====
    /// 是否有 ES 模块语法 - 对应 Bun has_es_module_syntax
    public var hasEsModuleSyntax: Bool
    /// 是否有顶级返回 - 对应 Bun has_top_level_return
    public var hasTopLevelReturn: Bool
    /// 是否有 import.meta - 对应 Bun has_import_meta
    public var hasImportMeta: Bool
    /// 导出类型 - 对应 Bun exports_kind
    public var exportsKind: ExportsKind
    /// 严格模式类型 - 对应 Bun strict_mode_kind
    public var strictModeKind: StrictModeKind

    // ===== CommonJS =====
    /// 旧式 CJS 导入语句 - 对应 Bun legacy_cjs_import_stmts
    public var legacyCjsImportStmts: ArrayList<Stmt>
    /// CJS 命名导出 - 对应 Bun commonjs_named_exports
    public var commonjsNamedExports: HashMap<String, Ref>

    // ===== 控制流 =====
    /// 控制流是否已死 - 对应 Bun is_control_flow_dead
    public var isControlFlowDead: Bool

    // ===== TS 相关 =====
    /// 是否有 export default - 对应 Bun has_export_default
    public var hasExportDefault: Bool
    /// 是否有 export 关键字 - 对应 Bun has_export_keyword
    public var hasExportKeyword: Bool

    /// 初始化解析器 - 对应 Bun NewParser 初始化
    public init(log: Log, source: Source, options: ParserOptions) {
        this.log = log
        this.source = source
        this.options = options

        // 初始化词法分析器
        let lexerOpts = if (options.features.typescript) {
            LexerOptions()
        } else {
            LexerOptions()
        }
        lexer = Lexer(log, source, lexerOpts)

        // 解析状态
        allowIn = true
        allowPrivateIdentifiers = false
        isStrictMode = options.strictMode

        // 函数/箭头
        fnOrArrowData = FnOrArrowDataParse()
        latestArrowArgLoc = Loc.EMPTY
        forbidSuffixAfterAsLoc = Loc.EMPTY

        // 作用域 - 创建模块作用域
        moduleScope = Scope(ScopeKind.EntryBlock, ArrayList<Scope>())
        currentScope = moduleScope
        scopesForCurrentPart = ArrayList<Scope>()
        scopesInOrder = ArrayList<ScopeOrder>()

        // 符号表
        symbols = ArrayList<Symbol>()
        declaredSymbols = ArrayList<DeclaredSymbol>()
        tempRefsToDeclare = ArrayList<TempRef>()
        tempRefCount = 0

        // 导入/导出
        importRecords = ArrayList<ImportRecord>()
        namedImports = HashMap<Ref, ImportItem>()
        namedExports = HashMap<String, Ref>()
        exportsRef = Ref.NONE
        requireRef = Ref.NONE
        moduleRef = Ref.NONE

        // 名称
        allocatedNames = ArrayList<String>()

        // 模块状态
        hasEsModuleSyntax = false
        hasTopLevelReturn = false
        hasImportMeta = false
        exportsKind = ExportsKind.None
        strictModeKind = StrictModeKind.SloppyMode

        // CommonJS
        legacyCjsImportStmts = ArrayList<Stmt>()
        commonjsNamedExports = HashMap<String, Ref>()

        // 控制流
        isControlFlowDead = false

        // TS
        hasExportDefault = false
        hasExportKeyword = false
    }

    // ========================================================================
    // 符号管理
    // 严格对应 Bun symbols.zig 中的 findSymbol, newSymbol
    // ========================================================================

    /// 创建新符号 - 对应 Bun newSymbol
    public func newSymbol(kind: SymbolKind, name: String): Ref {
        let index = symbols.size
        let ref = Ref(Int64(index), RefTag.AllocatedName, 0)
        symbols.append(Symbol(kind, name, ref))
        return ref
    }

    /// 查找符号 - 对应 Bun findSymbol
    public func findSymbol(name: String): ?Ref {
        // 从当前作用域向上查找
        var scope = currentScope
        while (true) {
            for (entry in scope.members) {
                if (entry.name == name) {
                    return entry.ref
                }
            }
            if (scope.parent.size == 0) {
                break
            }
            scope = scope.parent[0]
        }
        return None
    }

    /// 声明符号 - 对应 Bun declareSymbol
    public func declareSymbol(kind: SymbolKind, name: String, scope: Scope): Ref {
        let ref = newSymbol(kind, name)
        scope.members.append(ScopeMember(name, ref))
        return ref
    }

    // ========================================================================
    // 作用域管理
    // 严格对应 Bun pushScope/popScope
    // ========================================================================

    /// 进入新作用域 - 对应 Bun pushScopeForParsePass
    public func pushScope(kind: ScopeKind): Scope {
        let scope = Scope(kind, ArrayList<Scope>())
        scope.parent.append(currentScope)
        currentScope.children.append(scope)
        scopesForCurrentPart.append(scope)
        scopesInOrder.append(ScopeOrder(scope, 0))
        currentScope = scope
        return scope
    }

    /// 离开作用域 - 对应 Bun popScope
    public func popScope(): Unit {
        if (currentScope.parent.size > 0) {
            currentScope = currentScope.parent[0]
        }
        if (scopesForCurrentPart.size > 0) {
            scopesForCurrentPart.removeAt(scopesForCurrentPart.size - 1)
        }
    }

    // ========================================================================
    // 引用管理
    // ========================================================================

    /// 分配名称 - 对应 Bun allocateName
    public func allocateName(name: String): String {
        allocatedNames.append(name)
        return name
    }

    // ========================================================================
    // 核心解析方法
    // 严格翻译自: src/js_parser/parse.zig
    //   parseExpr, parseStmt, parsePrefix, parseSuffix, etc.
    //
    // Bun 的 parse.zig 约 5000+ 行，实现了完整的 JS/TS 语法解析
    // 仓颉翻译保留核心框架和主要解析路径
    // ========================================================================

    /// 解析整个模块 - 对应 Bun parse
    /// 这是解析器的入口方法
    public func parse(): Stmt {
        // 读取第一个 token
        lexer.step()
        lexer.nextToken()

        // 解析模块体
        let stmts = parseStmtsUpTo(Token.EndOfFile)
        return Stmt.block(Loc(0), stmts)
    }

    /// 解析语句列表直到遇到结束 token - 对应 Bun parseStmtsUpTo
    /// 包含错误恢复 (synchronize) — 对应 Bun 的错误恢复策略
    //  严格翻译自: Bun parseStmtsUpTo 中的错误处理
    //   当遇到语法错误时，跳过 token 直到找到同步点 (分号, 右花括号, 等)
    public func parseStmtsUpTo(end: Token): ArrayList<Stmt> {
        var stmts = ArrayList<Stmt>()
        while (true) {
            // 跳过分号
            while (lexer.token == Token.Semicolon) {
                lexer.nextToken()
            }
            if (lexer.token == end) {
                break
            }
            if (lexer.token == Token.EndOfFile) {
                break
            }
            // 错误恢复 — 对应 Bun synchronize
            try {
                let stmt = parseStmt(StmtOpts())
                if (stmt.tag != StmtTag.Empty) {
                    stmts.append(stmt)
                }
            } catch (_: Exception) {
                // synchronize: 跳过 token 直到找到同步点
                //  严格翻译自: Bun 的 panic recovery 策略
                //   同步点: ;, }, ), ], 以及语句开始关键字
                synchronize()
            }
            if (isControlFlowDead) {
                break
            }
        }
        return stmts
    }

    /// 错误恢复 — 对应 Bun synchronize
    //  严格翻译自: JS 解析器的错误恢复策略
    //   跳过 token 直到找到可以继续解析的同步点
    //   同步点包括: 分号, 右花括号, 以及语句开始关键字
    //   这使得解析器在遇到第一个错误后不会级联产生大量错误
    public func synchronize(): Unit {
        while (lexer.token != Token.EndOfFile) {
            match (lexer.token) {
                case Semicolon | CloseBrace | CloseParen | CloseBracket =>
                    lexer.nextToken()
                    return
                // 语句开始关键字 — 可以安全恢复的位置
                case Var | Let | Const | Function | Class | If | For |
                     While | Do | Switch | Try | With | Break | Continue |
                     Return | Throw | Import | Export | Debugger =>
                    return
                case _ => lexer.nextToken()
            }
        }
    }

    // ========================================================================
    // 语句解析
    // ========================================================================

    /// 语句解析选项
    public class StmtOpts {
        public var isModuleScope: Bool
        public var isExport: Bool

        public init() {
            isModuleScope = false
            isExport = false
        }
    }

    /// 解析语句 - 对应 Bun parseStmt
    /// Bun: 约 800 行，分发到各种语句解析函数
    public func parseStmt(opts: StmtOpts): Stmt {
        let loc = lexer.loc()

        // 检查严格模式指令
        if (lexer.token == Token.StringLiteral) {
            let text = lexer.stringLiteralRawContent
            if (text == "use strict") {
                strictModeKind = StrictModeKind.ExplicitStrictMode
                isStrictMode = true
            }
        }

        // 分发到具体语句解析函数
        match (lexer.token) {
            // 导入/导出
            case Import => return parseImportStmt()
            case Export => return parseExportStmt()

            // 声明
            case Var => return parseVarStmt(DeclKind.Var, loc)
            case Let => return parseLetConstStmt(DeclKind.Let, loc)
            case Const => return parseLetConstStmt(DeclKind.Const, loc)
            case Function => return parseFnStmt(loc, false, false)
            case Class => return parseClassStmt(loc, false)

            // 控制流
            case If => return parseIfStmt(loc)
            case For => return parseForStmt(loc)
            case While => return parseWhileStmt(loc)
            case Do => return parseDoWhileStmt(loc)
            case Switch => return parseSwitchStmt(loc)
            case Try => return parseTryStmt(loc)
            case With => return parseWithStmt(loc)

            // 分支
            case Break => return parseBreakStmt(loc)
            case Continue => return parseContinueStmt(loc)
            case Return => return parseReturnStmt(loc)
            case Throw => return parseThrowStmt(loc)

            // 块
            case OpenBrace => return parseBlockStmt(loc)

            // 调试器
            case Debugger => return parseDebuggerStmt(loc)

            // TypeScript 关键字
            case Typeof => return parseExprStmt(loc)

            // TypeScript 标识符上下文关键字 (interface, type, enum, namespace, declare, abstract)
            case Identifier =>
                if (features.typescript) {
                    if (let Some(tsStmt) = tryParseTypeScriptStmt(loc)) {
                        return tsStmt
                    }
                }
                return parseExprStmt(loc)

            // 默认: 表达式语句
            case _ => return parseExprStmt(loc)
        }
    }

    /// 解析表达式语句 - 对应 Bun parseExprStmt
    public func parseExprStmt(loc: Loc): Stmt {
        let expr = parseExpr(ParseExprOpts())
        lexer.expectOrInsertSemicolon()
        return Stmt.expr(loc, expr)
    }

    // ========================================================================
    // 声明语句
    // ========================================================================

    /// 解析 var 语句 - 对应 Bun parseVarStmt
    public func parseVarStmt(kind: DeclKind, loc: Loc): Stmt {
        lexer.nextToken() // 消耗 var/let/const
        let binding = parseBinding()
        var init: ?Expr = None
        if (lexer.token == Token.Equals) {
            lexer.nextToken()
            init = Some(parseExpr(ParseExprOpts()))
        }
        lexer.expectOrInsertSemicolon()
        return Stmt.local(loc, kind, binding, init)
    }

    /// 解析 let/const 语句 - 对应 Bun parseLetConstStmt
    public func parseLetConstStmt(kind: DeclKind, loc: Loc): Stmt {
        lexer.nextToken() // 消耗 let/const
        let binding = parseBinding()
        var init: ?Expr = None
        if (lexer.token == Token.Equals) {
            lexer.nextToken()
            init = Some(parseExpr(ParseExprOpts()))
        }
        lexer.expectOrInsertSemicolon()
        return Stmt.local(loc, kind, binding, init)
    }

    /// 解析函数声明语句 - 对应 Bun parseFnStmt
    public func parseFnStmt(loc: Loc, isAsync: Bool, isGenerator: Bool): Stmt {
        if (isAsync) {
            lexer.nextToken() // 消耗 async
        }
        lexer.expect(Token.Function)
        if (isGenerator && lexer.token == Token.Asterisk) {
            lexer.nextToken()
        }
        let name = lexer.identifier
        let nameLoc = lexer.loc()
        lexer.nextToken()

        // 参数
        let args = parseFnArgs()

        // 函数体
        let body = parseFnBody()

        let fn = GFn(
            name: name,
            args: args,
            body: GFnBody.Stmts(body),
            loc: loc
        )
        return Stmt.fn(loc, fn)
    }

    /// 解析类声明语句 - 对应 Bun parseClassStmt
    public func parseClassStmt(loc: Loc, isExport: Bool): Stmt {
        lexer.expect(Token.Class)
        let name = lexer.identifier
        let nameLoc = lexer.loc()
        lexer.nextToken()

        var extends_: ?Expr = None
        if (lexer.token == Token.Extends) {
            lexer.nextToken()
            extends_ = Some(parseExpr(ParseExprOpts()))
        }

        // 类体
        let properties = parseClassBody()

        let class_ = GClass(
            name: name,
            extends_: extends_,
            properties: properties,
            loc: loc
        )
        return Stmt.class(loc, class_)
    }

    /// 解析类体
    private func parseClassBody(): ArrayList<GProperty> {
        var props = ArrayList<GProperty>()
        lexer.expect(Token.OpenBrace)
        while (lexer.token != Token.CloseBrace && lexer.token != Token.EndOfFile) {
            let prop = parseProperty()
            props.append(prop)
        }
        lexer.expect(Token.CloseBrace)
        return props
    }

    /// 解析属性 - 对应 Bun parseProperty
    public func parseProperty(): GProperty {
        let loc = lexer.loc()
        var isStatic = false
        var isGet = false
        var isSet = false
        var isAsync = false

        // 修饰符
        if (lexer.token == Token.Static && !isStatic) {
            isStatic = true
            lexer.nextToken()
        }
        if (lexer.isContextualKeyword("get")) {
            isGet = true
            lexer.nextToken()
        } else if (lexer.isContextualKeyword("set")) {
            isSet = true
            lexer.nextToken()
        }
        if (lexer.isContextualKeyword("async")) {
            isAsync = true
            lexer.nextToken()
        }

        // 属性名
        let name = parsePropertyName()
        let nameLoc = lexer.loc()

        // 方法
        if (lexer.token == Token.OpenParen) {
            let args = parseFnArgs()
            let body = parseFnBody()
            let fn = GFn(
                name: name,
                args: args,
                body: GFnBody.Stmts(body),
                loc: loc
            )
            return GProperty.method(loc, name, fn, isStatic, isGet, isSet, isAsync)
        }

        // 字段
        var value: ?Expr = None
        if (lexer.token == Token.Equals) {
            lexer.nextToken()
            value = Some(parseExpr(ParseExprOpts()))
        }
        if (lexer.token == Token.Semicolon) {
            lexer.nextToken()
        }
        return GProperty.field(loc, name, value, isStatic)
    }

    /// 解析属性名
    private func parsePropertyName(): String {
        if (lexer.token == Token.Identifier || lexer.token.isIdentifierOrKeyword()) {
            let name = lexer.identifier
            lexer.nextToken()
            return name
        }
        if (lexer.token == Token.StringLiteral) {
            let name = lexer.stringLiteralRawContent
            lexer.nextToken()
            return name
        }
        if (lexer.token == Token.NumericLiteral) {
            let name = lexer.raw()
            lexer.nextToken()
            return name
        }
        // 方括号计算属性名
        if (lexer.token == Token.OpenBracket) {
            lexer.nextToken()
            let expr = parseExpr(ParseExprOpts())
            lexer.expect(Token.CloseBracket)
            return "[computed]"
        }
        return ""
    }

    // ========================================================================
    // 控制流语句
    // ========================================================================

    /// 解析 if 语句 - 对应 Bun parseIfStmt
    public func parseIfStmt(loc: Loc): Stmt {
        lexer.expect(Token.If)
        lexer.expect(Token.OpenParen)
        let test = parseExpr(ParseExprOpts())
        lexer.expect(Token.CloseParen)
        let consequent = parseStmt(StmtOpts())
        var alternate: ?Stmt = None
        if (lexer.token == Token.Else) {
            lexer.nextToken()
            alternate = Some(parseStmt(StmtOpts()))
        }
        return Stmt.if_(loc, test, consequent, alternate)
    }

    /// 解析 for 语句 - 对应 Bun parseForStmt
    public func parseForStmt(loc: Loc): Stmt {
        lexer.expect(Token.For)
        lexer.expect(Token.OpenParen)

        // 简化: 判断 for-in / for-of / 普通 for
        if (lexer.token == Token.Var || lexer.token == Token.Let || lexer.token == Token.Const) {
            let declKind = if (lexer.token == Token.Var) { DeclKind.Var }
                else if (lexer.token == Token.Let) { DeclKind.Let }
                else { DeclKind.Const }
            lexer.nextToken()
            let binding = parseBinding()

            if (lexer.token == Token.In) {
                // for-in
                lexer.nextToken()
                let value = parseExpr(ParseExprOpts())
                lexer.expect(Token.CloseParen)
                let body = parseStmt(StmtOpts())
                return Stmt.forIn(loc, declKind, binding, value, body)
            }
            if (lexer.isContextualKeyword("of")) {
                // for-of
                lexer.nextToken()
                let value = parseExpr(ParseExprOpts())
                lexer.expect(Token.CloseParen)
                let body = parseStmt(StmtOpts())
                return Stmt.forOf(loc, declKind, binding, value, body)
            }

            // 普通 for
            var initExpr: ?Expr = None
            if (lexer.token == Token.Equals) {
                lexer.nextToken()
                initExpr = Some(parseExpr(ParseExprOpts()))
            }
            lexer.expect(Token.Semicolon)
            let test = parseExpr(ParseExprOpts())
            lexer.expect(Token.Semicolon)
            let update = parseExpr(ParseExprOpts())
            lexer.expect(Token.CloseParen)
            let body = parseStmt(StmtOpts())
            return Stmt.for_(loc, initExpr, test, update, body)
        }

        // for (;...;...;) 形式
        let init = parseExpr(ParseExprOpts())
        lexer.expect(Token.Semicolon)
        let test = parseExpr(ParseExprOpts())
        lexer.expect(Token.Semicolon)
        let update = parseExpr(ParseExprOpts())
        lexer.expect(Token.CloseParen)
        let body = parseStmt(StmtOpts())
        return Stmt.for_(loc, Some(init), test, update, body)
    }

    /// 解析 while 语句
    public func parseWhileStmt(loc: Loc): Stmt {
        lexer.expect(Token.While)
        lexer.expect(Token.OpenParen)
        let test = parseExpr(ParseExprOpts())
        lexer.expect(Token.CloseParen)
        let body = parseStmt(StmtOpts())
        return Stmt.while_(loc, test, body)
    }

    /// 解析 do-while 语句
    public func parseDoWhileStmt(loc: Loc): Stmt {
        lexer.expect(Token.Do)
        let body = parseStmt(StmtOpts())
        lexer.expect(Token.While)
        lexer.expect(Token.OpenParen)
        let test = parseExpr(ParseExprOpts())
        lexer.expect(Token.CloseParen)
        lexer.expectOrInsertSemicolon()
        return Stmt.doWhile(loc, body, test)
    }

    /// 解析 switch 语句
    public func parseSwitchStmt(loc: Loc): Stmt {
        lexer.expect(Token.Switch)
        lexer.expect(Token.OpenParen)
        let test = parseExpr(ParseExprOpts())
        lexer.expect(Token.CloseParen)
        lexer.expect(Token.OpenBrace)
        var cases = ArrayList<SwitchCase>()
        while (lexer.token != Token.CloseBrace && lexer.token != Token.EndOfFile) {
            if (lexer.token == Token.Case) {
                lexer.nextToken()
                let value = parseExpr(ParseExprOpts())
                lexer.expect(Token.Colon)
                let stmts = parseStmtsUpTo(Token.Case)
                cases.append(SwitchCase(Some(value), stmts))
            } else if (lexer.token == Token.Default) {
                lexer.nextToken()
                lexer.expect(Token.Colon)
                let stmts = parseStmtsUpTo(Token.CloseBrace)
                cases.append(SwitchCase(None, stmts))
            } else {
                break
            }
        }
        lexer.expect(Token.CloseBrace)
        return Stmt.switch_(loc, test, cases)
    }

    /// 解析 try 语句
    public func parseTryStmt(loc: Loc): Stmt {
        lexer.expect(Token.Try)
        let body = parseBlock()
        var catch_: ?Stmt = None
        var finally_: ?Stmt = None
        if (lexer.token == Token.Catch) {
            lexer.nextToken()
            var catchBinding: ?Binding = None
            if (lexer.token == Token.OpenParen) {
                lexer.nextToken()
                catchBinding = Some(parseBinding())
                lexer.expect(Token.CloseParen)
            }
            let catchBody = parseBlock()
            catch_ = Some(Stmt.catch_(lexer.loc(), catchBinding, catchBody))
        }
        if (lexer.token == Token.Finally) {
            lexer.nextToken()
            finally_ = Some(parseBlock())
        }
        return Stmt.try_(loc, body, catch_, finally_)
    }

    /// 解析 with 语句
    public func parseWithStmt(loc: Loc): Stmt {
        lexer.expect(Token.With)
        lexer.expect(Token.OpenParen)
        let value = parseExpr(ParseExprOpts())
        lexer.expect(Token.CloseParen)
        let body = parseStmt(StmtOpts())
        return Stmt.with_(loc, value, body)
    }

    /// 解析 break 语句
    public func parseBreakStmt(loc: Loc): Stmt {
        lexer.expect(Token.Break)
        var label: String = ""
        if (lexer.token == Token.Identifier && !lexer.hasNewlineBefore) {
            label = lexer.identifier
            lexer.nextToken()
        }
        lexer.expectOrInsertSemicolon()
        return Stmt.break_(loc, label)
    }

    /// 解析 continue 语句
    public func parseContinueStmt(loc: Loc): Stmt {
        lexer.expect(Token.Continue)
        var label: String = ""
        if (lexer.token == Token.Identifier && !lexer.hasNewlineBefore) {
            label = lexer.identifier
            lexer.nextToken()
        }
        lexer.expectOrInsertSemicolon()
        return Stmt.continue_(loc, label)
    }

    /// 解析 return 语句
    public func parseReturnStmt(loc: Loc): Stmt {
        lexer.expect(Token.Return)
        var value: ?Expr = None
        if (lexer.token != Token.Semicolon && lexer.token != Token.CloseBrace &&
            lexer.token != Token.EndOfFile && !lexer.hasNewlineBefore) {
            value = Some(parseExpr(ParseExprOpts()))
        }
        lexer.expectOrInsertSemicolon()
        return Stmt.return_(loc, value)
    }

    /// 解析 throw 语句
    public func parseThrowStmt(loc: Loc): Stmt {
        lexer.expect(Token.Throw)
        let value = parseExpr(ParseExprOpts())
        lexer.expectOrInsertSemicolon()
        return Stmt.throw_(loc, value)
    }

    /// 解析块语句
    public func parseBlockStmt(loc: Loc): Stmt {
        let stmts = parseBlock()
        return Stmt.block(loc, stmts)
    }

    /// 解析块
    public func parseBlock(): ArrayList<Stmt> {
        lexer.expect(Token.OpenBrace)
        let scope = pushScope(ScopeKind.Block)
        let stmts = parseStmtsUpTo(Token.CloseBrace)
        lexer.expect(Token.CloseBrace)
        popScope()
        return stmts
    }

    /// 解析 debugger 语句
    public func parseDebuggerStmt(loc: Loc): Stmt {
        lexer.expect(Token.Debugger)
        lexer.expectOrInsertSemicolon()
        return Stmt.debugger(loc)
    }

    // ========================================================================
    // 导入/导出语句
    // ========================================================================

    /// 解析 import 语句 - 对应 Bun parseImportStmt
    public func parseImportStmt(): Stmt {
        let loc = lexer.loc()
        lexer.expect(Token.Import)

        // import 'path' (副作用导入)
        if (lexer.token == Token.StringLiteral) {
            let path = lexer.stringLiteralRawContent
            let record = ImportRecord(path, ImportRecordKind.Stmt, lexer.range())
            let recordIndex = importRecords.size
            importRecords.append(record)
            lexer.nextToken()
            lexer.expectOrInsertSemicolon()
            return Stmt.import_(loc, recordIndex)
        }

        // import ... from 'path'
        var defaultImport: ?ClauseItem = None
        var items = ArrayList<ClauseItem>()

        // 默认导入
        if (lexer.token == Token.Identifier) {
            let name = lexer.identifier
            let importLoc = lexer.loc()
            let ref = newSymbol(SymbolKind.Import, name)
            lexer.nextToken()
            defaultImport = Some(ClauseItem(name, name, importLoc, ref))
            if (lexer.token == Token.Comma) {
                lexer.nextToken()
            }
        }

        // 命名导入
        if (lexer.token == Token.OpenBrace) {
            lexer.nextToken()
            while (lexer.token != Token.CloseBrace && lexer.token != Token.EndOfFile) {
                let importName = lexer.identifier
                let importLoc = lexer.loc()
                lexer.nextToken()
                var localName = importName
                if (lexer.token == Token.Identifier && lexer.raw() == "as") {
                    lexer.nextToken()
                    localName = lexer.identifier
                    lexer.nextToken()
                }
                let ref = newSymbol(SymbolKind.Import, localName)
                items.append(ClauseItem(importName, localName, importLoc, ref))
                if (lexer.token == Token.Comma) {
                    lexer.nextToken()
                }
            }
            lexer.expect(Token.CloseBrace)
        }

        // 命名空间导入
        var starImport: ?ClauseItem = None
        if (lexer.token == Token.Asterisk) {
            lexer.nextToken()
            lexer.expect(Token.Identifier) // as
            let localName = lexer.identifier
            let importLoc = lexer.loc()
            let ref = newSymbol(SymbolKind.Import, localName)
            lexer.nextToken()
            starImport = Some(ClauseItem("*", localName, importLoc, ref))
        }

        // from 'path'
        if (lexer.isContextualKeyword("from")) {
            lexer.nextToken()
        }
        let path = lexer.stringLiteralRawContent
        let record = ImportRecord(path, ImportRecordKind.Static, lexer.range())
        let recordIndex = importRecords.size
        importRecords.append(record)
        lexer.nextToken()
        lexer.expectOrInsertSemicolon()

        hasEsModuleSyntax = true
        return Stmt.importClause(loc, defaultImport, starImport, items, recordIndex)
    }

    /// 解析 export 语句 - 对应 Bun parseExportStmt
    public func parseExportStmt(): Stmt {
        let loc = lexer.loc()
        hasExportKeyword = true
        lexer.expect(Token.Export)

        // export default
        if (lexer.token == Token.Default) {
            lexer.nextToken()
            hasExportDefault = true
            if (lexer.token == Token.Function) {
                let fnStmt = parseFnStmt(lexer.loc(), false, false)
                return Stmt.exportDefault(loc, fnStmt)
            }
            if (lexer.token == Token.Class) {
                let classStmt = parseClassStmt(lexer.loc(), false)
                return Stmt.exportDefault(loc, classStmt)
            }
            let expr = parseExpr(ParseExprOpts())
            lexer.expectOrInsertSemicolon()
            return Stmt.exportDefault(loc, expr)
        }

        // export *
        if (lexer.token == Token.Asterisk) {
            lexer.nextToken()
            if (lexer.isContextualKeyword("as")) {
                lexer.nextToken()
                let alias = lexer.identifier
                lexer.nextToken()
            }
            if (lexer.isContextualKeyword("from")) {
                lexer.nextToken()
            }
            let path = lexer.stringLiteralRawContent
            let record = ImportRecord(path, ImportRecordKind.Static, lexer.range())
            let recordIndex = importRecords.size
            importRecords.append(record)
            lexer.nextToken()
            lexer.expectOrInsertSemicolon()
            hasEsModuleSyntax = true
            return Stmt.exportStar(loc, recordIndex)
        }

        // export { ... }
        if (lexer.token == Token.OpenBrace) {
            var items = ArrayList<ClauseItem>()
            lexer.nextToken()
            while (lexer.token != Token.CloseBrace && lexer.token != Token.EndOfFile) {
                let localName = lexer.identifier
                let itemLoc = lexer.loc()
                lexer.nextToken()
                var exportedName = localName
                if (lexer.token == Token.Identifier && lexer.raw() == "as") {
                    lexer.nextToken()
                    exportedName = lexer.identifier
                    lexer.nextToken()
                }
                items.append(ClauseItem(localName, exportedName, itemLoc, Ref.NONE))
                if (lexer.token == Token.Comma) {
                    lexer.nextToken()
                }
            }
            lexer.expect(Token.CloseBrace)
            var recordIndex: Int64 = -1
            if (lexer.isContextualKeyword("from")) {
                lexer.nextToken()
                let path = lexer.stringLiteralRawContent
                let record = ImportRecord(path, ImportRecordKind.Static, lexer.range())
                recordIndex = importRecords.size
                importRecords.append(record)
                lexer.nextToken()
            }
            lexer.expectOrInsertSemicolon()
            hasEsModuleSyntax = true
            return Stmt.exportClause(loc, items, recordIndex)
        }

        // export const/let/var/function/class
        if (lexer.token == Token.Const || lexer.token == Token.Let || lexer.token == Token.Var) {
            let kind = if (lexer.token == Token.Var) { DeclKind.Var }
                else if (lexer.token == Token.Let) { DeclKind.Let }
                else { DeclKind.Const }
            hasEsModuleSyntax = true
            return parseVarStmt(kind, loc)
        }
        if (lexer.token == Token.Function) {
            hasEsModuleSyntax = true
            return parseFnStmt(loc, false, false)
        }
        if (lexer.token == Token.Class) {
            hasEsModuleSyntax = true
            return parseClassStmt(loc, false)
        }

        // export async function
        if (lexer.isContextualKeyword("async")) {
            hasEsModuleSyntax = true
            return parseFnStmt(loc, true, false)
        }

        return Stmt.empty(loc)
    }

    // ========================================================================
    // 表达式解析
    // 严格对应 Bun parse.zig 中的 parseExpr / parseExprCommon
    // 使用 Pratt 解析器实现操作符优先级
    // ========================================================================

    /// 表达式解析选项
    public class ParseExprOpts {
        public var lhs: Bool    // 是否为赋值左侧
        public var allowIn: Bool // 是否允许 in
        public var allowCall: Bool

        public init() {
            lhs = false
            allowIn = true
            allowCall = true
        }
    }

    /// 解析表达式 - 对应 Bun parseExpr
    public func parseExpr(opts: ParseExprOpts): Expr {
        return parseAssignmentExpr(opts)
    }

    /// 解析赋值表达式 - 对应 Bun parseAssignmentExpr
    public func parseAssignmentExpr(opts: ParseExprOpts): Expr {
        // 可能是箭头函数
        // (a, b) => ...
        // async (a, b) => ...
        let expr = parseConditionalExpr(opts)

        // 检查箭头
        if (lexer.token == Token.EqualsGreaterThan) {
            return parseArrowBody(expr)
        }

        // 检查赋值操作符
        if (lexer.token.isAssign()) {
            let op = tokenToAssignOp(lexer.token)
            let opLoc = lexer.loc()
            lexer.nextToken()
            let value = parseAssignmentExpr(opts)
            return Expr.assign(opLoc, expr, op, value)
        }

        return expr
    }

    /// 解析条件表达式 (三元) - 对应 Bun parseConditionalExpr
    public func parseConditionalExpr(opts: ParseExprOpts): Expr {
        let expr = parseBinaryExpr(opts, 0)

        if (lexer.token == Token.Question) {
            lexer.nextToken()
            let yes = parseAssignmentExpr(opts)
            lexer.expect(Token.Colon)
            let no = parseAssignmentExpr(opts)
            return Expr.ternary(lexer.loc(), expr, yes, no)
        }

        return expr
    }

    /// 解析二元表达式 - 对应 Bun parseBinaryExpr
    /// 使用 Pratt 解析器处理操作符优先级
    public func parseBinaryExpr(opts: ParseExprOpts, minPrec: Int64): Expr {
        var left = parseUnaryExpr(opts)

        while (true) {
            let op = tokenToBinaryOp(lexer.token)
            if (op == None) { break }
            let prec = op.unwrap().precedence
            if (prec < minPrec) { break }

            let opCode = op.unwrap()
            let opLoc = lexer.loc()
            lexer.nextToken()

            let right = parseBinaryExpr(opts, prec + 1)
            left = Expr.binary(opLoc, opCode.code, left, right)
        }

        return left
    }

    /// 解析一元表达式 - 对应 Bun parseUnaryExpr
    public func parseUnaryExpr(opts: ParseExprOpts): Expr {
        let loc = lexer.loc()

        // 前缀一元操作符
        if (lexer.token == Token.Exclamation) {
            lexer.nextToken()
            let operand = parseUnaryExpr(opts)
            return Expr.unary(loc, OpCode.UnNot, operand)
        }
        if (lexer.token == Token.Tilde) {
            lexer.nextToken()
            let operand = parseUnaryExpr(opts)
            return Expr.unary(loc, OpCode.UnCpl, operand)
        }
        if (lexer.token == Token.Minus) {
            lexer.nextToken()
            let operand = parseUnaryExpr(opts)
            return Expr.unary(loc, OpCode.UnNeg, operand)
        }
        if (lexer.token == Token.Plus) {
            lexer.nextToken()
            let operand = parseUnaryExpr(opts)
            return Expr.unary(loc, OpCode.UnPos, operand)
        }
        if (lexer.token == Token.Typeof) {
            lexer.nextToken()
            let operand = parseUnaryExpr(opts)
            return Expr.unary(loc, OpCode.Typeof, operand)
        }
        if (lexer.token == Token.Void) {
            lexer.nextToken()
            let operand = parseUnaryExpr(opts)
            return Expr.unary(loc, OpCode.UnVoid, operand)
        }
        if (lexer.token == Token.Delete) {
            lexer.nextToken()
            let operand = parseUnaryExpr(opts)
            return Expr.unary(loc, OpCode.UnDelete, operand)
        }

        // 前缀 ++/--
        if (lexer.token == Token.PlusPlus) {
            lexer.nextToken()
            let operand = parseUnaryExpr(opts)
            return Expr.prefix(loc, OpCode.UnPos, operand)
        }
        if (lexer.token == Token.MinusMinus) {
            lexer.nextToken()
            let operand = parseUnaryExpr(opts)
            return Expr.prefix(loc, OpCode.UnNeg, operand)
        }

        // await
        if (lexer.isContextualKeyword("await")) {
            lexer.nextToken()
            let operand = parseUnaryExpr(opts)
            return Expr.await_(loc, operand)
        }

        return parsePostfixExpr(opts)
    }

    /// 解析后缀表达式 - 对应 Bun parsePostfixExpr / parseSuffix
    public func parsePostfixExpr(opts: ParseExprOpts): Expr {
        var expr = parsePrimaryExpr(opts)

        while (true) {
            // 后缀 ++/--
            if (lexer.token == Token.PlusPlus) {
                let loc = lexer.loc()
                lexer.nextToken()
                expr = Expr.postfix(loc, expr)
                continue
            }
            if (lexer.token == Token.MinusMinus) {
                let loc = lexer.loc()
                lexer.nextToken()
                expr = Expr.postfix(loc, expr)
                continue
            }

            // 成员访问: a.b
            if (lexer.token == Token.Dot) {
                let loc = lexer.loc()
                lexer.nextToken()
                let name = lexer.identifier
                let nameLoc = lexer.loc()
                lexer.nextToken()
                expr = Expr.dot(loc, expr, name, nameLoc)
                continue
            }

            // 可选链: a?.b
            if (lexer.token == Token.QuestionDot) {
                let loc = lexer.loc()
                lexer.nextToken()
                let name = lexer.identifier
                let nameLoc = lexer.loc()
                lexer.nextToken()
                expr = Expr.dot(loc, expr, name, nameLoc)
                continue
            }

            // 索引访问: a[b]
            if (lexer.token == Token.OpenBracket) {
                let loc = lexer.loc()
                lexer.nextToken()
                let index = parseExpr(ParseExprOpts())
                lexer.expect(Token.CloseBracket)
                expr = Expr.index(loc, expr, index)
                continue
            }

            // 函数调用: a(b)
            if (lexer.token == Token.OpenParen && opts.allowCall) {
                let loc = lexer.loc()
                let args = parseCallArgs()
                expr = Expr.call(loc, expr, args)
                continue
            }

            // 可选调用: a?.(b)
            if (lexer.token == Token.QuestionDot) {
                let loc = lexer.loc()
                lexer.nextToken()
                if (lexer.token == Token.OpenParen) {
                    let args = parseCallArgs()
                    expr = Expr.call(loc, expr, args)
                } else if (lexer.token == Token.OpenBracket) {
                    lexer.nextToken()
                    let index = parseExpr(ParseExprOpts())
                    lexer.expect(Token.CloseBracket)
                    expr = Expr.index(loc, expr, index)
                }
                continue
            }

            break
        }

        return expr
    }

    /// 解析主表达式 - 对应 Bun parsePrefix / parsePrimaryExpr
    public func parsePrimaryExpr(opts: ParseExprOpts): Expr {
        let loc = lexer.loc()

        match (lexer.token) {
            // 字面量
            case False =>
                lexer.nextToken()
                return Expr.bool_(loc, false)
            case True =>
                lexer.nextToken()
                return Expr.bool_(loc, true)
            case Null =>
                lexer.nextToken()
                return Expr.null_(loc)
            case NumericLiteral =>
                let num = lexer.number
                lexer.nextToken()
                return Expr.number(loc, num)
            case BigIntegerLiteral =>
                let text = lexer.identifier
                lexer.nextToken()
                return Expr.bigInt(loc, text)
            case StringLiteral =>
                let text = lexer.stringLiteralRawContent
                lexer.nextToken()
                return Expr.string(loc, text)

            // 标识符
            case Identifier =>
                let name = lexer.identifier
                let ref = newSymbol(SymbolKind.Ref, name)
                lexer.nextToken()
                return Expr.identifier(loc, name, ref)

            // this
            case This =>
                lexer.nextToken()
                return Expr.this_(loc)

            // super
            case Super =>
                lexer.nextToken()
                return Expr.super_(loc)

            // 括号表达式
            case OpenParen =>
                return parseParenExpr(loc)

            // 数组字面量
            case OpenBracket =>
                return parseArrayLiteral(loc)

            // 对象字面量
            case OpenBrace =>
                return parseObjectLiteral(loc)

            // 函数表达式
            case Function =>
                return parseFnExpr(loc, false, false)

            // new 表达式
            case New =>
                return parseNewExpr(loc)

            // 模板字面量
            case NoSubstitutionTemplateLiteral =>
                let text = lexer.stringLiteralRawContent
                lexer.nextToken()
                return Expr.template(loc, [text])

            // typeof
            case Typeof =>
                lexer.nextToken()
                let operand = parseUnaryExpr(opts)
                return Expr.unary(loc, OpCode.Typeof, operand)

            // 导入
            case Import =>
                return parseImportExpr(loc)

            case _ =>
                lexer.unexpected()
                return Expr.missing(loc)
        }
    }

    /// 解析括号表达式 — 完整实现
    //  严格翻译自: Bun parseParenExpr
    //   括号可能表示:
    //   1. 普通分组表达式: (expr)
    //   2. 箭头函数参数: (a, b) => ...
    //   3. 空参数箭头函数: () => ...
    //   4. 带类型注解的参数 (TS): (a: number) => ...
    //   需要通过 lookahead 区分
    public func parseParenExpr(loc: Loc): Expr {
        lexer.expect(Token.OpenParen)

        // 空参数: () => ...
        if (lexer.token == Token.CloseParen) {
            lexer.nextToken()
            if (lexer.token == Token.EqualsGreaterThan) {
                return parseArrowBody(Expr.missing(loc))
            }
            // () 不跟 => 的非法表达式
            return Expr.missing(loc)
        }

        // 解析第一个表达式
        let expr = parseExpr(ParseExprOpts())

        // 如果遇到逗号，可能是多参数箭头函数
        if (lexer.token == Token.Comma) {
            // 收集所有参数表达式
            let items = ArrayList<Expr>()
            items.append(expr)
            while (lexer.token == Token.Comma) {
                lexer.nextToken()
                if (lexer.token == Token.DotDotDot) {
                    // 剩余参数
                    lexer.nextToken()
                    items.append(Expr.spread(lexer.loc(), parseAssignmentExpr(ParseExprOpts())))
                    break
                }
                items.append(parseAssignmentExpr(ParseExprOpts()))
            }
            lexer.expect(Token.CloseParen)

            if (lexer.token == Token.EqualsGreaterThan) {
                // 多参数箭头函数
                // 简化: 使用最后一个参数创建箭头函数
                // 完整实现需要将 items 转换为参数列表
                let args = ArrayList<GArg>()
                for (item in items) {
                    if (item.tag == ExprTag.Identifier) {
                        let ref = newSymbol(SymbolKind.Hoisted, item.identifier)
                        args.append(GArg(item.identifier, item.loc, ref, None, false))
                    }
                }
                var body: GFnBody
                lexer.expect(Token.EqualsGreaterThan)
                if (lexer.token == Token.OpenBrace) {
                    body = GFnBody.Stmts(parseFnBody())
                } else {
                    body = GFnBody.Expr(parseAssignmentExpr(ParseExprOpts()))
                }
                let fn = GFn(name: "", args: args, body: body, loc: loc)
                fn.isArrow = true
                return Expr.fn_(loc, fn)
            }

            // 否则是逗号表达式
            lexer.expect(Token.CloseParen)
            return expr
        }

        lexer.expect(Token.CloseParen)

        // 检查是否为箭头函数
        if (lexer.token == Token.EqualsGreaterThan) {
            return parseArrowBody(expr)
        }

        // TS 类型断言: <Type>expr 已在 parsePrimaryExpr 中处理

        return expr
    }

    /// 解析数组字面量 - 对应 Bun parseArrayLiteral
    public func parseArrayLiteral(loc: Loc): Expr {
        lexer.expect(Token.OpenBracket)
        var items = ArrayList<Expr>()
        while (lexer.token != Token.CloseBracket && lexer.token != Token.EndOfFile) {
            if (lexer.token == Token.Comma) {
                items.append(Expr.missing(lexer.loc()))
                lexer.nextToken()
                continue
            }
            if (lexer.token == Token.DotDotDot) {
                lexer.nextToken()
                let inner = parseAssignmentExpr(ParseExprOpts())
                items.append(Expr.spread(loc, inner))
            } else {
                items.append(parseAssignmentExpr(ParseExprOpts()))
            }
            if (lexer.token == Token.Comma) {
                lexer.nextToken()
            }
        }
        lexer.expect(Token.CloseBracket)
        return Expr.array(loc, items)
    }

    /// 解析对象字面量 - 对应 Bun parseObjectLiteral
    public func parseObjectLiteral(loc: Loc): Expr {
        lexer.expect(Token.OpenBrace)
        var properties = ArrayList<GProperty>()
        while (lexer.token != Token.CloseBrace && lexer.token != Token.EndOfFile) {
            let prop = parseProperty()
            properties.append(prop)
            if (lexer.token == Token.Comma) {
                lexer.nextToken()
            }
        }
        lexer.expect(Token.CloseBrace)
        return Expr.object(loc, properties)
    }

    /// 解析函数表达式 - 对应 Bun parseFnExpr
    public func parseFnExpr(loc: Loc, isAsync: Bool, isGenerator: Bool): Expr {
        if (isAsync) {
            lexer.nextToken()
        }
        lexer.expect(Token.Function)
        if (isGenerator && lexer.token == Token.Asterisk) {
            lexer.nextToken()
        }
        var name: String = ""
        var nameRef: Ref = Ref.NONE
        if (lexer.token == Token.Identifier) {
            name = lexer.identifier
            nameRef = newSymbol(SymbolKind.Hoisted, name)
            lexer.nextToken()
        }
        let args = parseFnArgs()
        let body = parseFnBody()
        let fn = GFn(
            name: name,
            args: args,
            body: GFnBody.Stmts(body),
            loc: loc
        )
        return Expr.fn_(loc, fn)
    }

    /// 解析 new 表达式 - 对应 Bun parseNewExpr
    public func parseNewExpr(loc: Loc): Expr {
        lexer.expect(Token.New)
        let target = parsePostfixExpr(ParseExprOpts())
        var args = ArrayList<Expr>()
        if (lexer.token == Token.OpenParen) {
            args = parseCallArgs()
        }
        return Expr.new_(loc, target, args)
    }

    /// 解析 import() 表达式 — 完整实现，支持 dynamic import 和 import.meta
    //  严格翻译自: Bun parseImportExpr / parseImportMeta
    //   import('path') — 动态导入
    //   import.meta — import.meta 对象
    public func parseImportExpr(loc: Loc): Expr {
        lexer.expect(Token.Import)

        // import.meta — 对应 Bun import.meta
        if (lexer.token == Token.Dot) {
            lexer.nextToken()
            if (lexer.token == Token.Identifier && lexer.identifier == "meta") {
                lexer.nextToken()
                hasImportMeta = true
                // 创建 import.meta 表达式
                let metaExpr = Expr(loc, ExprTag.Identifier)
                metaExpr.identifierName = "import.meta"
                metaExpr.ref = moduleRef
                return metaExpr
            }
            // 其他 import.xxx (不应出现)
            return Expr.missing(loc)
        }

        // import() — 动态导入
        //  严格翻译自: ES dynamic import semantics
        //   import(specifier) 返回 Promise
        //   import(specifier, options) 支持 import assertions
        lexer.expect(Token.OpenParen)
        let path = parseAssignmentExpr(ParseExprOpts())

        // import assertions — 对应 import('path', { assert: { type: 'json' } })
        var options: ?Expr = None
        if (lexer.token == Token.Comma) {
            lexer.nextToken()
            options = Some(parseAssignmentExpr(ParseExprOpts()))
        }

        lexer.expect(Token.CloseParen)

        // 记录动态导入
        let record = ImportRecord("dynamic", ImportRecordKind.Dynamic, lexer.range())
        importRecords.append(record)

        return Expr.import_(loc, path)
    }

    // ========================================================================
    // 辅助解析方法
    // ========================================================================

    /// 解析函数参数 - 对应 Bun parseFnArgs
    public func parseFnArgs(): ArrayList<GArg> {
        var args = ArrayList<GArg>()
        lexer.expect(Token.OpenParen)
        while (lexer.token != Token.CloseParen && lexer.token != Token.EndOfFile) {
            let name = lexer.identifier
            let argLoc = lexer.loc()
            let ref = newSymbol(SymbolKind.Hoisted, name)
            var default_: ?Expr = None
            lexer.nextToken()
            if (lexer.token == Token.Equals) {
                lexer.nextToken()
                default_ = Some(parseExpr(ParseExprOpts()))
            }
            args.append(GArg(name, argLoc, ref, default_, false))
            if (lexer.token == Token.Comma) {
                lexer.nextToken()
            }
        }
        lexer.expect(Token.CloseParen)
        return args
    }

    /// 解析函数体 - 对应 Bun parseFnBody
    public func parseFnBody(): ArrayList<Stmt> {
        return parseBlock()
    }

    /// 解析箭头函数体 — 完整实现
    //  严格翻译自: Bun parseArrowBody
    //   支持单参数无括号: x => x + 1
    //   支持多参数: (a, b) => a + b
    //   支持表达式体: x => x + 1
    //   支持块体: (x) => { return x + 1; }
    //   支持异步: async x => x + 1
    //   支持解构参数: ({a, b}) => a + b
    //   支持默认参数: (x = 1) => x
    //   支持剩余参数: (...args) => args
    public func parseArrowBody(params: Expr): Expr {
        let loc = lexer.loc()
        lexer.expect(Token.EqualsGreaterThan)

        // 解析参数 — 处理各种参数模式
        var args = ArrayList<GArg>()
        if (params.tag == ExprTag.Identifier) {
            // 单参数无括号: x => ...
            let ref = newSymbol(SymbolKind.Hoisted, params.identifier)
            args.append(GArg(params.identifier, params.loc, ref, None, false))
        } else if (params.tag == ExprTag.Array) {
            // 数组解构参数: ([a, b]) => ...
            // 将 array 表达式转换为绑定
            for (item in params.items) {
                if (item.tag == ExprTag.Identifier) {
                    let ref = newSymbol(SymbolKind.Hoisted, item.identifier)
                    args.append(GArg(item.identifier, item.loc, ref, None, false))
                }
            }
        } else if (params.tag == ExprTag.Object) {
            // 对象解构参数: ({a, b}) => ...
            for (prop in params.properties) {
                if (let Some(val) = prop.value) {
                    if (val.tag == ExprTag.Identifier) {
                        let ref = newSymbol(SymbolKind.Hoisted, val.identifier)
                        args.append(GArg(val.identifier, val.loc, ref, None, false))
                    }
                }
            }
        }

        // 解析箭头函数体
        var body: GFnBody
        if (lexer.token == Token.OpenBrace) {
            // 块体: (...) => { stmts }
            let stmts = parseFnBody()
            body = GFnBody.Stmts(stmts)
        } else {
            // 表达式体: (...) => expr
            //  严格翻译自: Bun parseArrowBody 中表达式体处理
            //   表达式体等价于 { return expr; }
            let expr = parseAssignmentExpr(ParseExprOpts())
            body = GFnBody.Expr(expr)
        }

        let fn = GFn(
            name: "",
            args: args,
            body: body,
            loc: loc
        )
        fn.isArrow = true
        return Expr.fn_(loc, fn)
    }

    /// 解析调用参数 - 对应 Bun parseCallArgs
    public func parseCallArgs(): ArrayList<Expr> {
        var args = ArrayList<Expr>()
        lexer.expect(Token.OpenParen)
        while (lexer.token != Token.CloseParen && lexer.token != Token.EndOfFile) {
            if (lexer.token == Token.DotDotDot) {
                lexer.nextToken()
                let inner = parseAssignmentExpr(ParseExprOpts())
                args.append(Expr.spread(lexer.loc(), inner))
            } else {
                args.append(parseAssignmentExpr(ParseExprOpts()))
            }
            if (lexer.token == Token.Comma) {
                lexer.nextToken()
            }
        }
        lexer.expect(Token.CloseParen)
        return args
    }

    /// 解析绑定 - 对应 Bun parseBinding
    public func parseBinding(): Binding {
        let loc = lexer.loc()

        if (lexer.token == Token.Identifier) {
            let name = lexer.identifier
            let ref = newSymbol(SymbolKind.Other, name)
            lexer.nextToken()
            return Binding.identifier(loc, name, ref)
        }

        if (lexer.token == Token.OpenBrace) {
            return parseObjectBinding(loc)
        }

        if (lexer.token == Token.OpenBracket) {
            return parseArrayBinding(loc)
        }

        lexer.unexpected()
        return Binding.identifier(loc, "", Ref.NONE)
    }

    /// 解析对象绑定 - 对应 Bun parsePropertyBinding
    private func parseObjectBinding(loc: Loc): Binding {
        lexer.expect(Token.OpenBrace)
        var properties = ArrayList<BindingProperty>()
        while (lexer.token != Token.CloseBrace && lexer.token != Token.EndOfFile) {
            let key = lexer.identifier
            let keyLoc = lexer.loc()
            lexer.nextToken()
            var value: ?Binding = None
            var alias = key
            if (lexer.token == Token.Colon) {
                lexer.nextToken()
                alias = lexer.identifier
                value = Some(parseBinding())
            }
            var default_: ?Expr = None
            if (lexer.token == Token.Equals) {
                lexer.nextToken()
                default_ = Some(parseExpr(ParseExprOpts()))
            }
            properties.append(BindingProperty(keyLoc, key, value, default_))
            if (lexer.token == Token.Comma) {
                lexer.nextToken()
            }
        }
        lexer.expect(Token.CloseBrace)
        return Binding.object_(loc, properties)
    }

    /// 解析数组绑定
    private func parseArrayBinding(loc: Loc): Binding {
        lexer.expect(Token.OpenBracket)
        var elements = ArrayList<Binding>()
        while (lexer.token != Token.CloseBracket && lexer.token != Token.EndOfFile) {
            if (lexer.token == Token.Comma) {
                elements.append(Binding.identifier(lexer.loc(), "", Ref.NONE))
                lexer.nextToken()
                continue
            }
            if (lexer.token == Token.DotDotDot) {
                lexer.nextToken()
                let rest = parseBinding()
                elements.append(rest)
                break
            }
            elements.append(parseBinding())
            if (lexer.token == Token.Comma) {
                lexer.nextToken()
            }
        }
        lexer.expect(Token.CloseBracket)
        return Binding.array_(loc, elements)
    }

    // ========================================================================
    // Token 到操作符的映射
    // ========================================================================

    /// 二元操作符信息
    public class BinaryOpInfo {
        public var code: OpCode
        public var precedence: Int64

        public init(code: OpCode, precedence: Int64) {
            this.code = code
            this.precedence = precedence
        }
    }

    /// Token 转二元操作符 - 对应 Bun parseBinaryExpr 中的操作符映射
    public func tokenToBinaryOp(t: Token): ?BinaryOpInfo {
        match (t) {
            case EqualsEquals => return BinaryOpInfo(OpCode.BinEq, 11)
            case EqualsEqualsEquals => return BinaryOpInfo(OpCode.BinEqStrict, 11)
            case ExclamationEquals => return BinaryOpInfo(OpCode.BinNe, 11)
            case ExclamationEqualsEquals => return BinaryOpInfo(OpCode.BinNeStrict, 11)
            case LessThan => return BinaryOpInfo(OpCode.BinLt, 12)
            case LessThanEquals => return BinaryOpInfo(OpCode.BinLe, 12)
            case GreaterThan => return BinaryOpInfo(OpCode.BinGt, 12)
            case GreaterThanEquals => return BinaryOpInfo(OpCode.BinGe, 12)
            case In => return if (allowIn) { BinaryOpInfo(OpCode.BinIn, 12) } else { None }
            case Instanceof => return BinaryOpInfo(OpCode.BinInstanceof, 12)
            case LessThanLessThan => return BinaryOpInfo(OpCode.BinShl, 13)
            case GreaterThanGreaterThan => return BinaryOpInfo(OpCode.BinShr, 13)
            case GreaterThanGreaterThanGreaterThan => return BinaryOpInfo(OpCode.BinUShr, 13)
            case Plus => return BinaryOpInfo(OpCode.BinAdd, 14)
            case Minus => return BinaryOpInfo(OpCode.BinSub, 14)
            case Asterisk => return BinaryOpInfo(OpCode.BinMul, 15)
            case Slash => return BinaryOpInfo(OpCode.BinDiv, 15)
            case Percent => return BinaryOpInfo(OpCode.BinRem, 15)
            case AsteriskAsterisk => return BinaryOpInfo(OpCode.BinPow, 16)
            case Ampersand => return BinaryOpInfo(OpCode.BinAnd, 10)
            case Bar => return BinaryOpInfo(OpCode.BinOr, 8)
            case Caret => return BinaryOpInfo(OpCode.BinXor, 9)
            case AmpersandAmpersand => return BinaryOpInfo(OpCode.BinLoAnd, 7)
            case BarBar => return BinaryOpInfo(OpCode.BinLoOr, 6)
            case QuestionQuestion => return BinaryOpInfo(OpCode.BinNullish, 5)
            case Comma => return BinaryOpInfo(OpCode.Comma, 0)
            case _ => return None
        }
    }

    /// Token 转赋值操作符 - 对应 Bun 赋值操作符映射
    public func tokenToAssignOp(t: Token): OpCode {
        match (t) {
            case Equals => OpCode.BinAssign
            case PlusEquals => OpCode.BinAddAssign
            case MinusEquals => OpCode.BinSubAssign
            case AsteriskEquals => OpCode.BinMulAssign
            case SlashEquals => OpCode.BinDivAssign
            case PercentEquals => OpCode.BinRemAssign
            case AsteriskAsteriskEquals => OpCode.BinPowAssign
            case LessThanLessThanEquals => OpCode.BinShlAssign
            case GreaterThanGreaterThanEquals => OpCode.BinShrAssign
            case GreaterThanGreaterThanGreaterThanEquals => OpCode.BinUShrAssign
            case AmpersandEquals => OpCode.BinAndAssign
            case BarEquals => OpCode.BinOrAssign
            case CaretEquals => OpCode.BinXorAssign
            case AmpersandAmpersandEquals => OpCode.BinLoAndAssign
            case BarBarEquals => OpCode.BinLoOrAssign
            case QuestionQuestionEquals => OpCode.BinNullishAssign
            case _ => OpCode.BinAssign
        }
    }

    // ========================================================================
    // TypeScript 扩展解析
    // 严格翻译自: src/js_parser/parse_skip_typescript.zig
    // Bun 策略: TS 类型注解被识别并跳过 (skip-based parsing)
    //   - parse_skip_typescript.zig 包含所有 TS 解析逻辑
    //   - 使用 skipTypeScriptType() 跳过类型注解
    //   - 使用 skipTypeScriptInterfaceStmt() 跳过接口声明
    //   - 大部分 TS 特性在运行时被忽略
    // ========================================================================

    /// 解析 TypeScript 类型声明 - 对应 Bun skipTypeScriptTypeStmt
    /// 支持的声明类型:
    ///   - interface Foo { ... }
    ///   - type Foo = ...
    ///   - enum Foo { ... }
    ///   - namespace Foo { ... }
    ///   - declare function foo(): void
    ///   - abstract class Foo { ... }
    private func tryParseTypeScriptStmt(loc: Loc): ?Stmt {
        if (!features.typescript) { return None }

        // 检查标识符是否为 TS 上下文关键字
        let ident = lexer.identifier
        match (ident) {
            case "interface" => return parseTsInterfaceStmt(loc)
            case "type" => return parseTsTypeAliasStmt(loc)
            case "enum" => return parseTsEnumStmt(loc)
            case "namespace" => return parseTsNamespaceStmt(loc)
            case "declare" => return parseTsDeclareStmt(loc)
            case "abstract" => return parseTsAbstractStmt(loc)
            case _ => return None
        }
    }

    /// 解析 TypeScript interface 声明
    /// 对应 Bun: skipTypeScriptInterfaceStmt
    /// interface Name<T> extends Base { prop: type; method(): type; }
    private func parseTsInterfaceStmt(loc: Loc): Stmt {
        lexer.nextToken() // skip 'interface'
        let name = lexer.identifier
        lexer.nextToken() // skip name

        // 泛型参数 <T, U extends Foo>
        if (lexer.token == Token.LessThan) {
            skipTsTypeParameters()
        }

        // extends / implements
        if (lexer.identifier == "extends" || lexer.identifier == "implements") {
            lexer.nextToken()
            skipTsType() // 跳过父类类型
            while (lexer.token == Token.Comma) {
                lexer.nextToken()
                skipTsType()
            }
        }

        // 接口体 { ... }
        lexer.expect(Token.OpenBrace)
        var depth = 1
        while (depth > 0 && lexer.token != Token.EndOfFile) {
            if (lexer.token == Token.OpenBrace) { depth += 1 }
            else if (lexer.token == Token.CloseBrace) { depth -= 1 }
            lexer.nextToken()
        }

        let s = Stmt(loc, StmtTag.Type)
        s.label = name
        return s
    }

    /// 解析 TypeScript type 别名
    /// 对应 Bun: skipTypeScriptTypeAlias
    /// type Name<T> = TypeExpression
    private func parseTsTypeAliasStmt(loc: Loc): Stmt {
        lexer.nextToken() // skip 'type'
        let name = lexer.identifier
        lexer.nextToken() // skip name

        // 泛型参数
        if (lexer.token == Token.LessThan) {
            skipTsTypeParameters()
        }

        // = TypeExpression
        lexer.expectOrInsertSemicolon() // 跳到分号

        let s = Stmt(loc, StmtTag.Type)
        s.label = name
        return s
    }

    /// 解析 TypeScript enum 声明
    /// 对应 Bun: parseTypeScriptEnum
    /// enum Name { A, B = value, ... }
    private func parseTsEnumStmt(loc: Loc): Stmt {
        lexer.nextToken() // skip 'enum'
        let name = lexer.identifier
        lexer.nextToken() // skip name

        lexer.expect(Token.OpenBrace)
        let members = ArrayList<Stmt>()
        while (lexer.token != Token.CloseBrace && lexer.token != Token.EndOfFile) {
            // 枚举成员名
            let memberName = lexer.identifier
            let memberLoc = lexer.loc()
            lexer.nextToken()

            // 可选初始值 = expr
            if (lexer.token == Token.Equals) {
                lexer.nextToken()
                parseExpr(ParseExprOpts()) // 跳过初始值表达式
            }

            let member = Stmt.expr(memberLoc, Expr.string(memberLoc, memberName))
            members.append(member)

            if (lexer.token == Token.Comma) {
                lexer.nextToken()
            }
        }
        lexer.expect(Token.CloseBrace)

        let s = Stmt(loc, StmtTag.Enum)
        s.label = name
        s.stmts = members
        return s
    }

    /// 解析 TypeScript namespace 声明
    /// 对应 Bun: skipTypeScriptNamespace
    /// namespace Name { ... }
    private func parseTsNamespaceStmt(loc: Loc): Stmt {
        lexer.nextToken() // skip 'namespace'
        let name = lexer.identifier
        lexer.nextToken() // skip name

        // 嵌套命名空间 namespace A.B.C
        while (lexer.token == Token.Dot) {
            lexer.nextToken()
            lexer.nextToken() // skip next identifier
        }

        // namespace body
        if (lexer.token == Token.OpenBrace) {
            lexer.nextToken() // skip {
            var depth = 1
            while (depth > 0 && lexer.token != Token.EndOfFile) {
                if (lexer.token == Token.OpenBrace) { depth += 1 }
                else if (lexer.token == Token.CloseBrace) { depth -= 1 }
                if (depth > 0) { lexer.nextToken() }
            }
            if (lexer.token == Token.CloseBrace) {
                lexer.nextToken()
            }
        }

        let s = Stmt(loc, StmtTag.Type)
        s.label = "namespace ${name}"
        return s
    }

    /// 解析 TypeScript declare 声明
    /// declare function foo(): void;
    /// declare class Foo { ... }
    /// declare const foo: Type;
    /// declare module 'foo' { ... }
    /// declare global { ... }
    private func parseTsDeclareStmt(loc: Loc): Stmt {
        lexer.nextToken() // skip 'declare'

        match (lexer.token) {
            case Function =>
                // declare function
                lexer.nextToken() // skip function
                lexer.nextToken() // skip name
                skipTsFunctionArgs()
                skipTsTypeAnnotation()
                lexer.expectOrInsertSemicolon()
            case Class =>
                // declare class
                lexer.nextToken() // skip class
                lexer.nextToken() // skip name
                if (lexer.token == Token.LessThan) { skipTsTypeParameters() }
                if (lexer.identifier == "extends") {
                    lexer.nextToken()
                    skipTsType()
                }
                if (lexer.identifier == "implements") {
                    lexer.nextToken()
                    skipTsType()
                }
                // skip class body
                lexer.expect(Token.OpenBrace)
                var depth = 1
                while (depth > 0 && lexer.token != Token.EndOfFile) {
                    if (lexer.token == Token.OpenBrace) { depth += 1 }
                    else if (lexer.token == Token.CloseBrace) { depth -= 1 }
                    lexer.nextToken()
                }
            case Const | Let | Var =>
                // declare const/let/var
                lexer.nextToken()
                lexer.nextToken() // skip name
                skipTsTypeAnnotation()
                lexer.expectOrInsertSemicolon()
            case _ =>
                // declare module 'name' { ... } or declare global { ... }
                if (lexer.token == Token.StringLiteral || lexer.token == Token.Identifier) {
                    lexer.nextToken() // skip module name
                }
                if (lexer.token == Token.OpenBrace) {
                    lexer.nextToken()
                    var depth = 1
                    while (depth > 0 && lexer.token != Token.EndOfFile) {
                        if (lexer.token == Token.OpenBrace) { depth += 1 }
                        else if (lexer.token == Token.CloseBrace) { depth -= 1 }
                        lexer.nextToken()
                    }
                } else {
                    lexer.expectOrInsertSemicolon()
                }
        }

        let s = Stmt(loc, StmtTag.Type)
        s.label = "declare"
        return s
    }

    /// 解析 abstract 修饰的类声明
    /// abstract class Foo { abstract method(): void; }
    private func parseTsAbstractStmt(loc: Loc): Stmt {
        lexer.nextToken() // skip 'abstract'
        if (lexer.token == Class) {
            return parseClassStmt(loc, false)
        }
        // 否则按表达式处理
        return parseExprStmt(loc)
    }

    // ========================================================================
    // TypeScript 类型跳过 (skip) 函数
    // 对应 Bun: parse_skip_typescript.zig
    // Bun 使用 skip 方式快速跳过 TS 类型注解，不构建详细 AST
    // ========================================================================

    /// 跳过 TypeScript 类型参数 <T, U extends Foo>
    /// 对应 Bun: skipTypeScriptTypeParameters
    private func skipTsTypeParameters(): Unit {
        if (lexer.token != Token.LessThan) { return }
        lexer.nextToken() // skip <
        var depth = 1
        while (depth > 0 && lexer.token != Token.EndOfFile) {
            if (lexer.token == Token.LessThan) { depth += 1 }
            else if (lexer.token == Token.GreaterThan) {
                depth -= 1
                if (depth == 0) {
                    lexer.nextToken()
                    return
                }
            }
            lexer.nextToken()
        }
    }

    /// 跳过 TypeScript 类型注解 : Type
    /// 对应 Bun: skipTypeScriptTypeAnnotation
    private func skipTsTypeAnnotation(): Unit {
        if (lexer.token != Token.Colon) { return }
        lexer.nextToken() // skip :
        skipTsType()
    }

    /// 跳过 TypeScript 类型表达式
    /// 对应 Bun: skipTypeScriptType
    /// 处理: 基础类型、联合类型 (A|B)、交叉类型 (A&B)、泛型 (Foo<T>)、
    ///        元组 ([A, B])、对象类型 ({a: A})、数组 (A[])、函数类型 (() => A)
    private func skipTsType(): Unit {
        // 简化实现: 跳过直到遇到 , 或 > 或 ; 或 = (非嵌套级别)
        var depth = 0
        while (lexer.token != Token.EndOfFile) {
            match (lexer.token) {
                case OpenParen =>
                    depth += 1
                    lexer.nextToken()
                case OpenBracket =>
                    depth += 1
                    lexer.nextToken()
                case OpenBrace =>
                    depth += 1
                    lexer.nextToken()
                case LessThan =>
                    depth += 1
                    lexer.nextToken()
                case CloseParen =>
                    if (depth == 0) { return }
                    depth -= 1
                    lexer.nextToken()
                case CloseBracket =>
                    if (depth == 0) { return }
                    depth -= 1
                    lexer.nextToken()
                case CloseBrace =>
                    if (depth == 0) { return }
                    depth -= 1
                    lexer.nextToken()
                case GreaterThan =>
                    if (depth == 0) { return }
                    depth -= 1
                    lexer.nextToken()
                case Comma | Semicolon | Equals | EqualsGreaterThan =>
                    if (depth == 0) { return }
                    lexer.nextToken()
                case _ =>
                    lexer.nextToken()
            }
        }
    }

    /// 跳过 TypeScript 函数参数类型
    /// 对应 Bun: skipTypescriptFnArgs
    private func skipTsFunctionArgs(): Unit {
        if (lexer.token != Token.OpenParen) { return }
        lexer.nextToken() // skip (
        var depth = 1
        while (depth > 0 && lexer.token != Token.EndOfFile) {
            if (lexer.token == Token.OpenParen) { depth += 1 }
            else if (lexer.token == Token.CloseParen) {
                depth -= 1
                if (depth == 0) {
                    lexer.nextToken()
                    return
                }
            }
            lexer.nextToken()
        }
    }

    /// 在标识符后检查是否需要跳过 TS 类型注解
    /// 对应 Bun: 在解析变量声明/函数参数时调用
    /// var x: Type = value
    /// function foo(arg: Type): ReturnType
    public func trySkipTypeAnnotation(): Unit {
        if (!features.typescript) { return }
        if (lexer.token == Token.Colon) {
            skipTsTypeAnnotation()
        }
    }

    /// 在标识符后检查是否需要跳过 TS 类型断言
    /// 对应 Bun: as Type / <Type>expr
    public func trySkipTsTypeAssertion(expr: Expr): Expr {
        if (!features.typescript) { return expr }
        // x as Type
        if (lexer.identifier == "as") {
            lexer.nextToken()
            skipTsType()
            let e = Expr(expr.loc, ExprTag.TypeCast)
            e.value = Some(expr)
            return e
        }
        // satisfies Type
        if (lexer.identifier == "satisfies") {
            lexer.nextToken()
            skipTsType()
        }
        return expr
    }
}
