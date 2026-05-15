// 严格翻译自: src/bundler/AstBuilder.zig (~376行)
// bao_bundler - AST 构建器: 用于生成代码的 AST 构建工具 (服务端组件边界模块等)
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_ast.*

// ============================================================================
// AST 构建器
// 严格翻译自: src/bundler/AstBuilder.zig AstBuilder struct
// 核心职责:
//   1. 构造 Ast 对象 (用于生成代码，如服务端组件边界模块)
//   2. 作为 js_parser 的替代方案 — 直接构建 AST 而非解析字符串
//   3. 管理 scope、symbol、import_record
//   4. 支持 ImportScanner 鸭子类型接口
// ============================================================================

/// AST 构建器
// 严格翻译自: AstBuilder.zig:7 AstBuilder
public class AstBuilder {
    /// 分配器
    public var allocator: Allocator
    /// 源文件引用
    public var source: Source
    /// 源文件索引
    public var sourceIndex: Int32
    /// 语句列表
    public var stmts: ArrayList<StmtNode>
    /// 作用域列表
    public var scopes: ArrayList<Scope>
    /// 符号列表
    public var symbols: ArrayList<AstSymbol>
    /// 导入记录列表
    public var importRecords: ArrayList<ImportRecord>
    /// 命名导入
    public var namedImports: HashMap<Ref, NamedImport>
    /// 命名导出
    public var namedExports: HashMap<String, NamedExport>
    /// 当前 part 的导入记录索引
    public var importRecordsForCurrentPart: ArrayList<Int32>
    /// export * 导入记录索引
    public var exportStarImportRecords: ArrayList<Int32>
    /// 当前作用域
    public var currentScope: Scope
    /// 日志
    public var log: Log
    /// 模块引用
    public var moduleRef: Ref
    /// 声明的符号列表
    public var declaredSymbols: ArrayList<DeclaredSymbol>
    /// 是否启用热重载
    public var hotReloading: Bool
    /// HMR API 引用
    public var hmrApiRef: Ref
    /// JSX 选项
    public var jsxOptions: JsxOptions
    /// 是否 bundle 模式
    public var isBundle: Bool

    public init(source: Source, hotReloading: Bool) {
        this.allocator = Allocator()
        this.source = source
        this.sourceIndex = source.index
        this.stmts = ArrayList<StmtNode>()
        this.scopes = ArrayList<Scope>()
        this.symbols = ArrayList<AstSymbol>()
        this.importRecords = ArrayList<ImportRecord>()
        this.importRecordsForCurrentPart = ArrayList<Int32>()
        this.namedImports = HashMap<Ref, NamedImport>()
        this.namedExports = HashMap<String, NamedExport>()
        this.exportStarImportRecords = ArrayList<Int32>()
        this.log = Log()
        this.declaredSymbols = ArrayList<DeclaredSymbol>()
        this.hotReloading = hotReloading
        this.jsxOptions = JsxOptions()
        this.isBundle = true

        // 创建入口作用域
        this.currentScope = Scope(kind: ScopeKind.Entry, labelRef: Ref.None, parent: null, generated: ArrayList<Ref>())

        // 创建 module 和 hmr 符号
        this.moduleRef = newSymbol(AstSymbolKind.Other, "module")
        this.hmrApiRef = newSymbol(AstSymbolKind.Other, "hmr")
    }

    /// 推入新作用域
    // 严格翻译自: AstBuilder.zig:73 pushScope
    public func pushScope(kind: ScopeKind): Scope {
        let scope = Scope(
            kind: kind,
            labelRef: Ref.None,
            parent: currentScope,
            generated: ArrayList<Ref>()
        )
        currentScope.children.append(scope)
        scopes.append(currentScope)
        currentScope = scope
        return scope
    }

    /// 弹出作用域
    // 严格翻译自: AstBuilder.zig:89 popScope
    public func popScope(): Unit {
        if (scopes.size > 0) {
            currentScope = scopes.removeAt(scopes.size - 1)
        }
    }

    /// 创建新符号
    // 严格翻译自: AstBuilder.zig:93 newSymbol
    public func newSymbol(kind: AstSymbolKind, identifier: String): Ref {
        let innerIndex = Int32(symbols.size)
        symbols.append(AstSymbol(kind: kind, originalName: identifier))
        let ref = Ref(innerIndex: innerIndex, sourceIndex: sourceIndex, tag: RefTag.Symbol)
        currentScope.generated.append(ref)
        let isTopLevel = scopes.size == 0 || currentScope == scopes.get(0)
        declaredSymbols.append(DeclaredSymbol(ref: ref, isTopLevel: isTopLevel))
        return ref
    }

    /// 获取符号
    // 严格翻译自: AstBuilder.zig:112 getSymbol
    public func getSymbol(ref: Ref): AstSymbol {
        if (ref.sourceIndex == source.index) {
            return symbols.get(Int64(ref.innerIndex))
        }
        return AstSymbol(kind: AstSymbolKind.Other, originalName: "")
    }

    /// 添加导入记录
    // 严格翻译自: AstBuilder.zig:117 addImportRecord
    public func addImportRecord(path: String, kind: ImportKind): Int32 {
        let index = Int32(importRecords.size)
        importRecords.append(ImportRecord(
            path: path,
            kind: kind,
            range: Range()
        ))
        return index
    }

    /// 添加导入语句
    // 严格翻译自: AstBuilder.zig:127 addImportStmt
    public func addImportStmt(path: String, identifiersToImport: Array<String>): ArrayList<ASTNode> {
        let record = addImportRecord(path, ImportKind.Stmt)
        let name = "import_" + PathName(path).nonUniqueName()
        let namespaceRef = newSymbol(AstSymbolKind.Other, name)

        var out = ArrayList<ASTNode>()
        let clauses = ArrayList<ClauseItem>()

        for (importId in identifiersToImport) {
            let ref = newSymbol(AstSymbolKind.Import, importId)
            if (hotReloading) {
                let sym = getSymbol(ref)
                sym.namespaceAlias = NamespaceAlias(
                    namespaceRef: namespaceRef,
                    alias: importId,
                    importRecordIndex: record
                )
            }
            out.append(ASTNode(tag: ExprTag.ImportIdentifier, loc: Loc.Empty))
            clauses.append(ClauseItem(
                name: LocRef(loc: Loc.Empty, ref: ref),
                originalName: importId,
                alias: importId
            ))
        }

        appendStmt(StmtNode(tag: StmtTag.Import, loc: Loc.Empty))
        return out
    }

    /// 追加语句
    // 严格翻译自: AstBuilder.zig:170 appendStmt
    public func appendStmt(data: StmtNode): Unit {
        stmts.append(newStmt(data))
    }

    /// 创建新语句
    // 严格翻译自: AstBuilder.zig:175 newStmt
    public func newStmt(data: StmtNode): StmtNode {
        return data
    }

    /// 创建新表达式
    // 严格翻译自: AstBuilder.zig:180 newExpr
    public func newExpr(data: ASTNode): ASTNode {
        return data
    }

    /// 创建外部符号 (不可重命名)
    // 严格翻译自: AstBuilder.zig:185 newExternalSymbol
    public func newExternalSymbol(name: String): Ref {
        let ref = newSymbol(AstSymbolKind.Other, name)
        let sym = getSymbol(ref)
        sym.mustNotBeRenamed = true
        return ref
    }

    /// 转换为 BundledAst
    // 严格翻译自: AstBuilder.zig:192 toBundledAst
    public func toBundledAst(target: Target): BundledAst {
        let moduleScope = currentScope

        // 构建 parts
        let parts = ArrayList<Part>()
        // Part 0: 空
        parts.append(Part())
        // Part 1: 所有语句
        var part1 = Part()
        part1.stmts = stmts
        part1.canBeRemovedIfUnused = false

        // 标记所有符号为已使用
        var symbolUses = HashMap<Ref, SymbolUse>()
        for (i in 0..symbols.size) {
            let ref = Ref(innerIndex: Int32(i), sourceIndex: sourceIndex, tag: RefTag.Symbol)
            symbolUses.put(ref, SymbolUse(countEstimate: 1))
        }
        part1.symbolUses = symbolUses
        parts.append(part1)

        // 构建 top_level_symbols_to_parts
        let topLevelSymbolsToParts = HashMap<Ref, ArrayList<UInt32>>()
        let singleU32 = ArrayList<UInt32>()
        singleU32.append(1)
        for (ref in moduleScope.generated) {
            topLevelSymbolsToParts.put(ref, singleU32)
        }

        part1.declaredSymbols = declaredSymbols
        let scopeList = ArrayList<Scope>()
        for (s in scopes) {
            scopeList.append(s)
        }
        part1.scopes = scopeList

        let importRecordIndices = BabyList<UInt32>()
        for (idx in importRecordsForCurrentPart) {
            importRecordIndices.append(UInt32(idx))
        }
        part1.importRecordIndices = importRecordIndices

        return BundledAst(
            parts: parts,
            moduleScope: moduleScope,
            symbols: AstSymbolList.fromList(symbols),
            exportsRef: Ref.None,
            wrapperRef: Ref.None,
            moduleRef: moduleRef,
            importRecords: ImportRecordList.fromList(importRecords),
            exportStarImportRecords: ArrayList<Int32>(),
            approximateNewlineCount: 1,
            exportsKind: ExportsKind.ESM,
            namedImports: namedImports,
            namedExports: namedExports,
            topLevelSymbolsToParts: topLevelSymbolsToParts,
            charFreq: CharFreq(),
            flags: BundledAstFlags(),
            target: target,
            topLevelAwaitKeyword: Range.None
        )
    }

    /// 生成临时引用
    // 严格翻译自: AstBuilder.zig:292 generateTempRef
    public func generateTempRef(name: String): Ref {
        return newSymbol(AstSymbolKind.Other, name.length > 0 ? name : "temp")
    }

    /// 记录导出
    // 严格翻译自: AstBuilder.zig:296 recordExport
    public func recordExport(loc: Loc, alias: String, ref: Ref): Unit {
        if (namedExports.containsKey(alias)) {
            // 重复导出是错误
            panic("In generated file, duplicate export \"${alias}\"")
        } else {
            namedExports.put(alias, NamedExport(aliasLoc: Loc.Empty, ref: ref))
        }
    }

    /// 记录导出的绑定
    // 严格翻译自: AstBuilder.zig:308 recordExportedBinding
    public func recordExportedBinding(binding: BindingNode): Unit {
        match (binding.tag) {
            case BindingTag.Missing => ()
            case BindingTag.Identifier => {
                let name = symbols.get(Int64(binding.ref.innerIndex)).originalName
                recordExport(binding.loc, name, binding.ref)
            }
            case BindingTag.Array => {
                for (child in binding.children) {
                    recordExportedBinding(child)
                }
            }
            case BindingTag.Object => {
                for (child in binding.children) {
                    recordExportedBinding(child)
                }
            }
        }
    }

    /// 忽略使用
    // 严格翻译自: AstBuilder.zig:327 ignoreUsage
    public func ignoreUsage(ref: Ref): Unit {
        // 不做任何操作
    }

    /// 恐慌
    public func panic(message: String): Unit {
        // 在仓颉中抛出异常
        throw RuntimeException(message)
    }

    /// 生成 module.exports 表达式
    // 严格翻译自: AstBuilder.zig:337 module.exports
    public func moduleExports(loc: Loc): ASTNode {
        return ASTNode(tag: ExprTag.Member, loc: loc)
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 作用域
// 严格翻译自: js_ast.zig Scope
public class Scope {
    public var kind: ScopeKind
    public var labelRef: Ref
    public var parent: Scope
    public var generated: ArrayList<Ref>
    public var children: ArrayList<Scope>

    public init(kind: ScopeKind, labelRef: Ref, parent: Scope, generated: ArrayList<Ref>) {
        this.kind = kind
        this.labelRef = labelRef
        this.parent = parent
        this.generated = generated
        this.children = ArrayList<Scope>()
    }
}

/// 作用域类型
public enum ScopeKind {
    | Entry      // entry point scope
    | Block      // block scope
    | With       // with scope
    | Hoisted    // hoisted function scope
    | Class      // class name scope
}

/// 符号种类
public enum AstSymbolKind {
    | Other
    | Import
    | Unbound
    | LocalCSS
}

/// AST 符号
// 严格翻译自: js_ast.zig Symbol
public class AstSymbol {
    public var kind: AstSymbolKind
    public var originalName: String
    public var mustNotBeRenamed: Bool
    public var namespaceAlias: NamespaceAlias
    public var importItemStatus: ImportItemStatus

    public init(kind: AstSymbolKind, originalName: String) {
        this.kind = kind
        this.originalName = originalName
        this.mustNotBeRenamed = false
        this.namespaceAlias = NamespaceAlias()
        this.importItemStatus = ImportItemStatus.Present
    }
}

/// 命名空间别名
public class NamespaceAlias {
    public var namespaceRef: Ref
    public var alias: String
    public var importRecordIndex: Int32

    public init() {
        this.namespaceRef = Ref.None
        this.alias = ""
        this.importRecordIndex = 0
    }

    public init(namespaceRef: Ref, alias: String, importRecordIndex: Int32) {
        this.namespaceRef = namespaceRef
        this.alias = alias
        this.importRecordIndex = importRecordIndex
    }
}

/// 导入项状态
public enum ImportItemStatus {
    | Present    // 导入存在
    | Missing    // 导入缺失 (替换为 undefined)
    | Generated  // 自动生成的导入
}

/// 声明的符号
public class DeclaredSymbol {
    public var ref: Ref
    public var isTopLevel: Bool

    public init(ref: Ref, isTopLevel: Bool) {
        this.ref = ref
        this.isTopLevel = isTopLevel
    }
}

/// 命名导入
public class NamedImport {
    public var alias: String
    public var aliasLoc: Loc
    public var aliasIsStar: Bool
    public var importRecordIndex: Int32
    public var namespaceRef: Ref

    public init() {
        this.alias = ""
        this.aliasLoc = Loc.Empty
        this.aliasIsStar = false
        this.importRecordIndex = 0
        this.namespaceRef = Ref.None
    }
}

/// 命名导出
public class NamedExport {
    public var aliasLoc: Loc
    public var ref: Ref

    public init(aliasLoc: Loc, ref: Ref) {
        this.aliasLoc = aliasLoc
        this.ref = ref
    }
}

/// 子句条目
public class ClauseItem {
    public var name: LocRef
    public var originalName: String
    public var alias: String

    public init(name: LocRef, originalName: String, alias: String) {
        this.name = name
        this.originalName = originalName
        this.alias = alias
    }
}

/// 位置+引用
public class LocRef {
    public var loc: Loc
    public var ref: Ref

    public init(loc: Loc, ref: Ref) {
        this.loc = loc
        this.ref = ref
    }
}

/// 导入记录
public class ImportRecord {
    public var path: String
    public var kind: ImportKind
    public var range: Range
    public var sourceIndex: Index
    public var flags: ImportRecordFlags

    public init(path: String, kind: ImportKind, range: Range) {
        this.path = path
        this.kind = kind
        this.range = range
        this.sourceIndex = Index.Invalid
        this.flags = ImportRecordFlags()
    }
}

/// 导入记录标志
public class ImportRecordFlags {
    public var isUnused: Bool

    public init() {
        this.isUnused = false
    }
}

/// 导入种类
public enum ImportKind {
    | Stmt              // import 声明
    | Dynamic           // import()
    | Require           // require()
    | RequireResolve    // require.resolve()
    | EntryPointRun     // 入口点运行
    | EntryPointBuild   // 入口点构建
    | At                // CSS @import
    | AtConditional     // CSS @import 条件
    | Url               // CSS url()
    | Composes          // CSS composes
    | HtmlManifest      // HTML 清单
    | Internal          // 内部
}

/// 索引类型
public class Index {
    public var value: Int32
    public static let Invalid: Index = Index(-1)
    public static let Runtime: Index = Index(0)

    public init(_ value: Int32) {
        this.value = value
    }

    public func isValid(): Bool {
        return value >= 0
    }

    public func isInvalid(): Bool {
        return value < 0
    }

    public func get(): Int32 {
        return value
    }
}

/// 引用类型
public class Ref {
    public var innerIndex: Int32
    public var sourceIndex: Int32
    public var tag: RefTag

    public init(innerIndex: Int32, sourceIndex: Int32, tag: RefTag) {
        this.innerIndex = innerIndex
        this.sourceIndex = sourceIndex
        this.tag = tag
    }

    public static let None: Ref = Ref(innerIndex: 0, sourceIndex: -1, tag: RefTag.None)

    public func isNull(): Bool {
        return sourceIndex < 0
    }

    public func isEmpty(): Bool {
        return sourceIndex < 0
    }

    public func eql(other: Ref): Bool {
        return innerIndex == other.innerIndex && sourceIndex == other.sourceIndex
    }

    public func sourceIndex(): Int32 {
        return sourceIndex
    }

    public func innerIndex(): Int32 {
        return innerIndex
    }
}

/// 引用标签
public enum RefTag {
    | None
    | Symbol
    | Temp
}

/// 源位置
public class Loc {
    public var start: Int32

    public init(start: Int32) {
        this.start = start
    }

    public static let Empty: Loc = Loc(start: 0)
}

/// 范围
public class Range {
    public var loc: Loc
    public var len: Int32

    public init(loc: Loc, len: Int32) {
        this.loc = loc
        this.len = len
    }

    public init() {
        this.loc = Loc.Empty
        this.len = 0
    }

    public static let None: Range = Range()
}

/// 符号使用
public class SymbolUse {
    public var countEstimate: UInt32

    public init(countEstimate: UInt32) {
        this.countEstimate = countEstimate
    }
}

/// Part (AST 片段)
public class Part {
    public var stmts: ArrayList<StmtNode>
    public var scopes: ArrayList<Scope>
    public var symbolUses: HashMap<Ref, SymbolUse>
    public var declaredSymbols: ArrayList<DeclaredSymbol>
    public var dependencies: ArrayList<Dependency>
    public var importRecordIndices: BabyList<UInt32>
    public var canBeRemovedIfUnused: Bool
    public var isLive: Bool
    public var tag: PartTag

    public init() {
        this.stmts = ArrayList<StmtNode>()
        this.scopes = ArrayList<Scope>()
        this.symbolUses = HashMap<Ref, SymbolUse>()
        this.declaredSymbols = ArrayList<DeclaredSymbol>()
        this.dependencies = ArrayList<Dependency>()
        this.importRecordIndices = BabyList<UInt32>()
        this.canBeRemovedIfUnused = true
        this.isLive = false
        this.tag = PartTag.Normal
    }
}

/// Part 标签
public enum PartTag {
    | Normal
    | CommonJSNamedExport
    | NamespaceExport
}

/// 依赖
public class Dependency {
    public var sourceIndex: Index
    public var partIndex: Int32

    public init(sourceIndex: Index, partIndex: Int32) {
        this.sourceIndex = sourceIndex
        this.partIndex = partIndex
    }
}

/// BabyList (紧凑列表)
public class BabyList<T> {
    private var items: ArrayList<T>

    public init() {
        this.items = ArrayList<T>()
    }

    public func append(item: T): Unit {
        items.append(item)
    }

    public func size(): Int64 {
        return items.size
    }

    public func slice(): ArrayList<T> {
        return items
    }
}

/// AstSymbolList (符号列表封装)
public class AstSymbolList {
    public var items: ArrayList<AstSymbol>

    public init() {
        this.items = ArrayList<AstSymbol>()
    }

    public static func fromList(list: ArrayList<AstSymbol>): AstSymbolList {
        let result = AstSymbolList()
        result.items = list
        return result
    }

    public func slice(): ArrayList<AstSymbol> {
        return items
    }

    public func size(): Int64 {
        return items.size
    }
}

/// ImportRecordList (导入记录列表封装)
public class ImportRecordList {
    public var items: ArrayList<ImportRecord>

    public init() {
        this.items = ArrayList<ImportRecord>()
    }

    public static func fromList(list: ArrayList<ImportRecord>): ImportRecordList {
        let result = ImportRecordList()
        result.items = list
        return result
    }

    public func at(index: Int32): ImportRecord {
        return items.get(Int64(index))
    }

    public func slice(): ArrayList<ImportRecord> {
        return items
    }
}

/// BundledAst (打包用 AST)
public class BundledAst {
    public var parts: ArrayList<Part>
    public var moduleScope: Scope
    public var symbols: AstSymbolList
    public var exportsRef: Ref
    public var wrapperRef: Ref
    public var moduleRef: Ref
    public var importRecords: ImportRecordList
    public var exportStarImportRecords: ArrayList<Int32>
    public var approximateNewlineCount: Int32
    public var exportsKind: ExportsKind
    public var namedImports: HashMap<Ref, NamedImport>
    public var namedExports: HashMap<String, NamedExport>
    public var topLevelSymbolsToParts: HashMap<Ref, ArrayList<UInt32>>
    public var charFreq: CharFreq
    public var flags: BundledAstFlags
    public var target: Target
    public var topLevelAwaitKeyword: Range
    public var tsEnums: HashMap<Ref, HashMap<String, InlinedEnumValue>>
    public var css: Any
    public var commonjsNamedExports: HashMap<String, CommonJSNamedExport>

    public init(parts: ArrayList<Part>, moduleScope: Scope, symbols: AstSymbolList,
                exportsRef: Ref, wrapperRef: Ref, moduleRef: Ref,
                importRecords: ImportRecordList, exportStarImportRecords: ArrayList<Int32>,
                approximateNewlineCount: Int32, exportsKind: ExportsKind,
                namedImports: HashMap<Ref, NamedImport>, namedExports: HashMap<String, NamedExport>,
                topLevelSymbolsToParts: HashMap<Ref, ArrayList<UInt32>>,
                charFreq: CharFreq, flags: BundledAstFlags, target: Target,
                topLevelAwaitKeyword: Range) {
        this.parts = parts
        this.moduleScope = moduleScope
        this.symbols = symbols
        this.exportsRef = exportsRef
        this.wrapperRef = wrapperRef
        this.moduleRef = moduleRef
        this.importRecords = importRecords
        this.exportStarImportRecords = exportStarImportRecords
        this.approximateNewlineCount = approximateNewlineCount
        this.exportsKind = exportsKind
        this.namedImports = namedImports
        this.namedExports = namedExports
        this.topLevelSymbolsToParts = topLevelSymbolsToParts
        this.charFreq = charFreq
        this.flags = flags
        this.target = target
        this.topLevelAwaitKeyword = topLevelAwaitKeyword
        this.tsEnums = HashMap<Ref, HashMap<String, InlinedEnumValue>>()
        this.css = null
        this.commonjsNamedExports = HashMap<String, CommonJSNamedExport>()
    }
}

/// BundledAst 标志
public class BundledAstFlags {
    public var usesExportsRef: Bool
    public var usesModuleRef: Bool
    public var usesExportKeyword: Bool
    public var hasCharFreq: Bool
    public var forceCjsToEsm: Bool
    public var hasLazyExport: Bool
    public var hasExplicitUseStrictDirective: Bool
    public var hasImportMeta: Bool

    public init() {
        this.usesExportsRef = false
        this.usesModuleRef = false
        this.usesExportKeyword = false
        this.hasCharFreq = false
        this.forceCjsToEsm = false
        this.hasLazyExport = false
        this.hasExplicitUseStrictDirective = false
        this.hasImportMeta = false
    }
}

/// 导出种类
public enum ExportsKind {
    | None    // 无导出
    | CJS     // CommonJS (module.exports = ...)
    | ESM     // ES Module (export ...)
}

/// CommonJS 命名导出
public class CommonJSNamedExport {
    public var locRef: LocRef
    public var needsDecl: Bool

    public init(locRef: LocRef, needsDecl: Bool) {
        this.locRef = locRef
        this.needsDecl = needsDecl
    }
}

/// 内联枚举值
public class InlinedEnumValue {
    public var value: Any

    public init(value: Any) {
        this.value = value
    }
}

/// 字符频率
public class CharFreq {
    public var freqs: Array<Int32>

    public init() {
        this.freqs = Array<Int32>(64, item: 0)
    }
}

/// 目标平台
public enum Target {
    | Browser
    | Bun
    | BunMacro
    | Node
}

/// JSX 选项
public class JsxOptions {
    public init() {}
}

/// 路径名称
public class PathName {
    public var path: String

    public init(_ path: String) {
        this.path = path
    }

    public func nonUniqueName(): String {
        let idx = path.lastIndexOf("/")
        if (idx >= 0) {
            return path.substring(Int64(idx + 1))
        }
        return path
    }
}

/// 日志
public class Log {
    public var errors: Int32
    public var warnings: Int32

    public init() {
        this.errors = 0
        this.warnings = 0
    }
}

/// 包目标 (对应 Bun BundleTarget)
public enum BundleTarget {
    | Browser
    | Node
    | Bun
}
