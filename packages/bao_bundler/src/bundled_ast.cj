// 严格翻译自: src/bundler/bundled_ast.zig (~130行)
// bao_bundler - BundledAst: 打包专用精简 AST (比 Ast 更轻量)
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_ast.*

// ============================================================================
// BundledAst
// 严格翻译自: src/bundler/bundled_ast.zig BundledAst
// 在 Linux 上，打包器中最热门的函数是 MultiArrayList.ensureTotalCapacity
// 所以我们制作了 Ast 的精简版，减少内存分配
// ============================================================================

/// 打包用 AST
// 严格翻译自: bundled_ast.zig:9 BundledAst
// 比 Ast 更精简，减少内存分配
public class BundledAstSlim {
    /// 预估换行数量
    public var approximateNewlineCount: UInt32
    /// 嵌套作用域槽数
    public var nestedScopeSlotCounts: SlotCounts
    /// 导出种类
    public var exportsKind: ExportsKindValue
    /// 导入记录
    public var importRecords: ImportRecordList
    /// hashbang
    public var hashbang: String
    /// Part 列表
    public var parts: PartList
    /// CSS 样式表
    public var css: Any
    /// CSS URL
    public var urlForCss: String
    /// 符号列表
    public var symbols: SymbolList
    /// 模块作用域
    public var moduleScope: ScopeInfo
    /// 字符频率
    public var charFreq: CharFreqInfo
    /// 导出引用
    public var exportsRef: RefValue
    /// 模块引用
    public var moduleRef: RefValue
    /// 包装器引用
    public var wrapperRef: RefValue
    /// require 引用
    public var requireRef: RefValue
    /// 顶层 await 关键字范围
    public var topLevelAwaitKeyword: RangeValue
    /// TLA 检查
    public var tlaCheck: TlaCheckInfo
    /// 命名导入
    public var namedImports: HashMap<RefValue, NamedImportInfo>
    /// 命名导出
    public var namedExports: HashMap<String, NamedExportInfo>
    /// export * 导入记录索引
    public var exportStarImportRecords: Array<UInt32>
    /// 顶层符号到 parts 的映射
    public var topLevelSymbolsToParts: HashMap<RefValue, BabyListUInt32>
    /// CommonJS 命名导出
    public var commonjsNamedExports: HashMap<String, CommonJSNamedExportInfo>
    /// 重定向导入记录索引
    public var redirectImportRecordIndex: UInt32
    /// 目标平台
    public var target: TargetValue
    /// TS 枚举映射
    public var tsEnums: HashMap<RefValue, HashMap<String, InlinedEnumValueInfo>>
    /// 标志位
    public var flags: BundledAstFlagsValue

    public init() {
        this.approximateNewlineCount = 0
        this.nestedScopeSlotCounts = SlotCounts()
        this.exportsKind = ExportsKindValue.None
        this.importRecords = ImportRecordList()
        this.hashbang = ""
        this.parts = PartList()
        this.css = null
        this.urlForCss = ""
        this.symbols = SymbolList()
        this.moduleScope = ScopeInfo()
        this.charFreq = CharFreqInfo()
        this.exportsRef = RefValue.None
        this.moduleRef = RefValue.None
        this.wrapperRef = RefValue.None
        this.requireRef = RefValue.None
        this.topLevelAwaitKeyword = RangeValue.None
        this.tlaCheck = TlaCheckInfo()
        this.namedImports = HashMap<RefValue, NamedImportInfo>()
        this.namedExports = HashMap<String, NamedExportInfo>()
        this.exportStarImportRecords = []
        this.topLevelSymbolsToParts = HashMap<RefValue, BabyListUInt32>()
        this.commonjsNamedExports = HashMap<String, CommonJSNamedExportInfo>()
        this.redirectImportRecordIndex = UInt32.MAX
        this.target = TargetValue.Browser
        this.tsEnums = HashMap<RefValue, HashMap<String, InlinedEnumValueInfo>>()
        this.flags = BundledAstFlagsValue()
    }

    /// 转换为完整 Ast
    // 严格翻译自: bundled_ast.zig:74 toAST
    public func toAST(): AstInfo {
        return AstInfo(
            approximateNewlineCount: approximateNewlineCount,
            exportsKind: exportsKind,
            importRecords: importRecords,
            hashbang: hashbang,
            parts: parts,
            symbols: symbols,
            moduleScope: moduleScope,
            charFreq: charFreq,
            exportsRef: exportsRef,
            moduleRef: moduleRef,
            wrapperRef: wrapperRef,
            requireRef: requireRef,
            topLevelAwaitKeyword: topLevelAwaitKeyword,
            namedImports: namedImports,
            namedExports: namedExports,
            exportStarImportRecords: exportStarImportRecords,
            topLevelSymbolsToParts: topLevelSymbolsToParts,
            commonjsNamedExports: commonjsNamedExports,
            target: target,
            tsEnums: tsEnums,
            flags: flags
        )
    }
}

// ============================================================================
// BundledAst 标志位
// 严格翻译自: bundled_ast.zig:55 Flags (packed struct u16)
// ============================================================================

/// BundledAst 标志位
public class BundledAstFlagsValue {
    /// 使用 exports 引用 (CommonJS)
    public var usesExportsRef: Bool
    /// 使用 module 引用 (CommonJS)
    public var usesModuleRef: Bool
    /// 使用 export 关键字
    public var usesExportKeyword: Bool
    /// 有字符频率数据
    public var hasCharFreq: Bool
    /// 强制 CJS 转 ESM
    public var forceCjsToEsm: Bool
    /// 有懒导出
    public var hasLazyExport: Bool
    /// CommonJS module.exports 赋值降级
    public var commonjsModuleExportsAssignedDeoptimized: Bool
    /// 有显式 "use strict" 指令
    public var hasExplicitUseStrictDirective: Bool
    /// 有 import.meta
    public var hasImportMeta: Bool

    public init() {
        this.usesExportsRef = false
        this.usesModuleRef = false
        this.usesExportKeyword = false
        this.hasCharFreq = false
        this.forceCjsToEsm = false
        this.hasLazyExport = false
        this.commonjsModuleExportsAssignedDeoptimized = false
        this.hasExplicitUseStrictDirective = false
        this.hasImportMeta = false
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 槽数计数
public class SlotCounts {
    public init() {}
}

/// 导出种类值
public enum ExportsKindValue {
    | None
    | CJS
    | ESM
}

/// 引用值
public class RefValue {
    public var innerIndex: UInt32
    public var sourceIndex: UInt32
    public var tag: UInt8

    public init(innerIndex: UInt32, sourceIndex: UInt32, tag: UInt8) {
        this.innerIndex = innerIndex
        this.sourceIndex = sourceIndex
        this.tag = tag
    }

    public static let None: RefValue = RefValue(innerIndex: 0, sourceIndex: UInt32.MAX, tag: 0)

    public func isNull(): Bool {
        return sourceIndex == UInt32.MAX
    }

    public func isEmpty(): Bool {
        return sourceIndex == UInt32.MAX
    }

    public func isValid(): Bool {
        return sourceIndex != UInt32.MAX
    }

    public func eql(other: RefValue): Bool {
        return innerIndex == other.innerIndex && sourceIndex == other.sourceIndex
    }

    public func innerIndex(): UInt32 {
        return innerIndex
    }

    public func sourceIndex(): UInt32 {
        return sourceIndex
    }
}

/// 范围值
public class RangeValue {
    public var loc: Int32
    public var len: Int32

    public init(loc: Int32, len: Int32) {
        this.loc = loc
        this.len = len
    }

    public static let None: RangeValue = RangeValue(loc: 0, len: 0)

    public func length(): Int32 {
        return len
    }
}

/// 作用域信息
public class ScopeInfo {
    public var kind: UInt8
    public var parent: ScopeInfo
    public var children: ArrayList<ScopeInfo>
    public var generated: ArrayList<RefValue>

    public init() {
        this.kind = 0
        this.parent = null
        this.children = ArrayList<ScopeInfo>()
        this.generated = ArrayList<RefValue>()
    }
}

/// 字符频率信息
public class CharFreqInfo {
    public var freqs: Array<Int32>

    public init() {
        this.freqs = Array<Int32>(64, item: 0)
    }
}

/// TLA 检查信息
public class TlaCheckInfo {
    public var depth: UInt32
    public var parent: UInt32
    public var importRecordIndex: UInt32

    public init() {
        this.depth = 0
        this.parent = UInt32.MAX
        this.importRecordIndex = 0
    }
}

/// 命名导入信息
public class NamedImportInfo {
    public var alias: String
    public var aliasLoc: Int32
    public var aliasIsStar: Bool
    public var importRecordIndex: UInt32
    public var namespaceRef: RefValue

    public init() {
        this.alias = ""
        this.aliasLoc = 0
        this.aliasIsStar = false
        this.importRecordIndex = 0
        this.namespaceRef = RefValue.None
    }
}

/// 命名导出信息
public class NamedExportInfo {
    public var aliasLoc: Int32
    public var ref: RefValue

    public init(aliasLoc: Int32, ref: RefValue) {
        this.aliasLoc = aliasLoc
        this.ref = ref
    }
}

/// CommonJS 命名导出信息
public class CommonJSNamedExportInfo {
    public var loc: Int32
    public var ref: RefValue
    public var needsDecl: Bool

    public init(loc: Int32, ref: RefValue, needsDecl: Bool) {
        this.loc = loc
        this.ref = ref
        this.needsDecl = needsDecl
    }
}

/// 目标平台值
public enum TargetValue {
    | Browser
    | Bun
    | BunMacro
    | Node
}

/// 内联枚举值信息
public class InlinedEnumValueInfo {
    public var value: Any

    public init(value: Any) {
        this.value = value
    }
}

/// BabyList<UInt32>
public class BabyListUInt32 {
    public var items: ArrayList<UInt32>

    public init() {
        this.items = ArrayList<UInt32>()
    }

    public func slice(): ArrayList<UInt32> {
        return items
    }
}

/// Part 列表
public class PartList {
    public var items: ArrayList<PartInfo>

    public init() {
        this.items = ArrayList<PartInfo>()
    }

    public func len(): Int64 {
        return items.size
    }

    public func slice(): ArrayList<PartInfo> {
        return items
    }

    public func at(index: Int32): PartInfo {
        return items.get(Int64(index))
    }

    public func mut(index: Int32): PartInfo {
        return items.get(Int64(index))
    }
}

/// Part 信息
public class PartInfo {
    public var stmts: ArrayList<StmtNode>
    public var scopes: ArrayList<ScopeInfo>
    public var symbolUses: HashMap<RefValue, SymbolUseInfo>
    public var declaredSymbols: ArrayList<DeclaredSymbolInfo>
    public var dependencies: ArrayList<DependencyInfo>
    public var importRecordIndices: BabyListUInt32
    public var canBeRemovedIfUnused: Bool
    public var isLive: Bool
    public var tag: PartTagValue

    public init() {
        this.stmts = ArrayList<StmtNode>()
        this.scopes = ArrayList<ScopeInfo>()
        this.symbolUses = HashMap<RefValue, SymbolUseInfo>()
        this.declaredSymbols = ArrayList<DeclaredSymbolInfo>()
        this.dependencies = ArrayList<DependencyInfo>()
        this.importRecordIndices = BabyListUInt32()
        this.canBeRemovedIfUnused = true
        this.isLive = false
        this.tag = PartTagValue.Normal
    }
}

/// Part 标签值
public enum PartTagValue {
    | Normal
    | CommonJSNamedExport
    | NamespaceExport
}

/// 符号使用信息
public class SymbolUseInfo {
    public var countEstimate: UInt32

    public init(countEstimate: UInt32) {
        this.countEstimate = countEstimate
    }
}

/// 声明符号信息
public class DeclaredSymbolInfo {
    public var ref: RefValue
    public var isTopLevel: Bool

    public init(ref: RefValue, isTopLevel: Bool) {
        this.ref = ref
        this.isTopLevel = isTopLevel
    }
}

/// 依赖信息
public class DependencyInfo {
    public var sourceIndex: UInt32
    public var partIndex: UInt32

    public init(sourceIndex: UInt32, partIndex: UInt32) {
        this.sourceIndex = sourceIndex
        this.partIndex = partIndex
    }
}

/// 导入记录列表
public class ImportRecordList {
    public var items: ArrayList<ImportRecordInfo>

    public init() {
        this.items = ArrayList<ImportRecordInfo>()
    }

    public func len(): Int64 {
        return items.size
    }

    public func at(index: Int32): ImportRecordInfo {
        return items.get(Int64(index))
    }

    public func slice(): ArrayList<ImportRecordInfo> {
        return items
    }
}

/// 导入记录信息
public class ImportRecordInfo {
    public var path: String
    public var kind: UInt8
    public var sourceIndex: UInt32
    public var range: RangeValue

    public init() {
        this.path = ""
        this.kind = 0
        this.sourceIndex = UInt32.MAX
        this.range = RangeValue.None
    }
}

/// 符号列表
public class SymbolList {
    public var items: ArrayList<SymbolInfo>

    public init() {
        this.items = ArrayList<SymbolInfo>()
    }

    public func slice(): ArrayList<SymbolInfo> {
        return items
    }
}

/// 符号信息
public class SymbolInfo {
    public var kind: UInt8
    public var originalName: String
    public var mustNotBeRenamed: Bool

    public init(kind: UInt8, originalName: String) {
        this.kind = kind
        this.originalName = originalName
        this.mustNotBeRenamed = false
    }
}

/// Ast 信息 (转换结果)
public class AstInfo {
    public var approximateNewlineCount: UInt32
    public var exportsKind: ExportsKindValue
    public var importRecords: ImportRecordList
    public var hashbang: String
    public var parts: PartList
    public var symbols: SymbolList
    public var moduleScope: ScopeInfo
    public var charFreq: CharFreqInfo
    public var exportsRef: RefValue
    public var moduleRef: RefValue
    public var wrapperRef: RefValue
    public var requireRef: RefValue
    public var topLevelAwaitKeyword: RangeValue
    public var namedImports: HashMap<RefValue, NamedImportInfo>
    public var namedExports: HashMap<String, NamedExportInfo>
    public var exportStarImportRecords: Array<UInt32>
    public var topLevelSymbolsToParts: HashMap<RefValue, BabyListUInt32>
    public var commonjsNamedExports: HashMap<String, CommonJSNamedExportInfo>
    public var target: TargetValue
    public var tsEnums: HashMap<RefValue, HashMap<String, InlinedEnumValueInfo>>
    public var flags: BundledAstFlagsValue

    public init(approximateNewlineCount: UInt32, exportsKind: ExportsKindValue,
                importRecords: ImportRecordList, hashbang: String, parts: PartList,
                symbols: SymbolList, moduleScope: ScopeInfo, charFreq: CharFreqInfo,
                exportsRef: RefValue, moduleRef: RefValue, wrapperRef: RefValue,
                requireRef: RefValue, topLevelAwaitKeyword: RangeValue,
                namedImports: HashMap<RefValue, NamedImportInfo>,
                namedExports: HashMap<String, NamedExportInfo>,
                exportStarImportRecords: Array<UInt32>,
                topLevelSymbolsToParts: HashMap<RefValue, BabyListUInt32>,
                commonjsNamedExports: HashMap<String, CommonJSNamedExportInfo>,
                target: TargetValue, tsEnums: HashMap<RefValue, HashMap<String, InlinedEnumValueInfo>>,
                flags: BundledAstFlagsValue) {
        this.approximateNewlineCount = approximateNewlineCount
        this.exportsKind = exportsKind
        this.importRecords = importRecords
        this.hashbang = hashbang
        this.parts = parts
        this.symbols = symbols
        this.moduleScope = moduleScope
        this.charFreq = charFreq
        this.exportsRef = exportsRef
        this.moduleRef = moduleRef
        this.wrapperRef = wrapperRef
        this.requireRef = requireRef
        this.topLevelAwaitKeyword = topLevelAwaitKeyword
        this.namedImports = namedImports
        this.namedExports = namedExports
        this.exportStarImportRecords = exportStarImportRecords
        this.topLevelSymbolsToParts = topLevelSymbolsToParts
        this.commonjsNamedExports = commonjsNamedExports
        this.target = target
        this.tsEnums = tsEnums
        this.flags = flags
    }
}
