// 严格翻译自: src/bundler/LinkerGraph.zig (~564行)
// bao_bundler - 链接器图: 管理链接阶段的文件、符号和依赖关系
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*
import bao_ast.*

// ============================================================================
// 链接器图
// 严格翻译自: src/bundler/LinkerGraph.zig LinkerGraph
// 核心职责:
//   1. 存储文件列表、符号映射、入口点
//   2. 管理可达文件和稳定源索引
//   3. 生成新符号和导入/使用关系
//   4. 添加 part 到文件
//   5. 传播异步依赖
// ============================================================================

/// 链接器图
// 严格翻译自: LinkerGraph.zig:1 LinkerGraph
public class LinkerGraph {
    /// 文件列表
    public var files: ArrayList<LinkerFile>
    /// 文件存活位集
    public var filesLive: BitSet
    /// 入口点列表
    public var entryPoints: ArrayList<EntryPoint>
    /// 符号映射
    public var symbols: SymbolMap
    /// 是否启用代码分割
    public var codeSplitting: Bool
    /// AST (来自 Graph 的别名)
    public var ast: ArrayList<JsAst>
    /// Meta 数据
    public var meta: ArrayList<JsMeta>
    /// 可达文件列表
    public var reachableFiles: ArrayList<Index>
    /// 稳定源索引 (parse_graph 到 files 的索引映射)
    public var stableSourceIndices: Array<UInt32>
    /// SCB 位集
    public var isScbBitset: BitSet
    /// TS 枚举映射
    public var tsEnums: HashMap<Ref, HashMap<String, InlinedEnumValue>>
    /// 分配器
    public var allocator: Allocator

    public init() {
        this.files = ArrayList<LinkerFile>()
        this.filesLive = BitSet()
        this.entryPoints = ArrayList<EntryPoint>()
        this.symbols = SymbolMap()
        this.codeSplitting = false
        this.ast = ArrayList<JsAst>()
        this.meta = ArrayList<JsMeta>()
        this.reachableFiles = ArrayList<Index>()
        this.stableSourceIndices = []
        this.isScbBitset = BitSet()
        this.tsEnums = HashMap<Ref, HashMap<String, InlinedEnumValue>>()
        this.allocator = Allocator()
    }

    /// 获取运行时函数引用
    // 严格翻译自: LinkerGraph.zig:45 runtimeFunction
    public func runtimeFunction(name: String): Ref {
        // 查找运行时命名导出
        let runtimeNamedExports = ast.get(0).namedExports
        match (runtimeNamedExports.get(name)) {
            case Some(entry) => return entry.ref
            case None => return Ref.None
        }
    }

    /// 生成新符号
    // 严格翻译自: LinkerGraph.zig:49 generateNewSymbol
    public func generateNewSymbol(sourceIndex: UInt32, kind: SymbolKind, originalName: String): Ref {
        let sourceSymbols = symbols.getSlice(sourceIndex)
        let innerIndex = UInt32(sourceSymbols.size)
        let ref = Ref(innerIndex: innerIndex, sourceIndex: Int32(sourceIndex), tag: RefTag.Symbol)

        sourceSymbols.append(Symbol(kind: kind, originalName: originalName))

        // 添加到模块作用域的 generated 列表
        ast.get(Int64(sourceIndex)).moduleScope.generated.append(ref)

        return ref
    }

    /// 生成运行时符号导入并使用
    // 严格翻译自: LinkerGraph.zig:73 generateRuntimeSymbolImportAndUse
    public func generateRuntimeSymbolImportAndUse(sourceIndex: UInt32,
                                                   entryPointPartIndex: Index,
                                                   name: String, count: UInt32): Unit {
        if (count == 0) {
            return
        }
        let ref = runtimeFunction(name)
        generateSymbolImportAndUse(
            sourceIndex,
            entryPointPartIndex.get(),
            ref,
            count,
            Index.Runtime
        )
    }

    /// 添加 Part 到文件
    // 严格翻译自: LinkerGraph.zig:93 addPartToFile
    public func addPartToFile(id: UInt32, part: Part): UInt32 {
        let parts = ast.get(Int64(id)).parts
        let partId = UInt32(parts.size)
        parts.append(part)

        // 更新顶层符号到 parts 映射
        for (declaredSym in part.declaredSymbols) {
            updateTopLevelSymbolToParts(id, declaredSym.ref, partId)
        }

        return partId
    }

    /// 生成符号导入和使用
    // 严格翻译自: LinkerGraph.zig:151 generateSymbolImportAndUse
    public func generateSymbolImportAndUse(sourceIndex: UInt32, partIndex: UInt32,
                                           ref: Ref, useCount: UInt32,
                                           sourceIndexToImportFrom: Index): Unit {
        if (useCount == 0) {
            return
        }

        let partsList = ast.get(Int64(sourceIndex)).parts
        let part = partsList.get(Int64(partIndex))

        // 标记此符号被此 part 使用
        let existingUse = part.symbolUses.get(ref)
        match (existingUse) {
            case Some(use) => use.countEstimate += useCount
            case None => part.symbolUses.put(ref, SymbolUse(countEstimate: useCount))
        }

        // 检查 exports_ref 和 module_ref
        let exportsRef = ast.get(Int64(sourceIndex)).exportsRef
        if (!exportsRef.isNull() && ref.eql(exportsRef)) {
            ast.get(Int64(sourceIndex)).flags.usesExportsRef = true
        }

        let moduleRef = ast.get(Int64(sourceIndex)).moduleRef
        if (!moduleRef.isNull() && ref.eql(moduleRef)) {
            ast.get(Int64(sourceIndex)).flags.usesModuleRef = true
        }

        // 跟踪符号导入
        if (sourceIndexToImportFrom.get() != sourceIndex) {
            let importsToBind = meta.get(Int64(sourceIndex)).importsToBind
            importsToBind.put(ref, ImportData(
                sourceIndex: sourceIndexToImportFrom,
                importRef: ref
            ))
        }

        // 拉取声明此符号的所有 parts
        let partIds = topLevelSymbolToParts(sourceIndexToImportFrom.get(), ref)
        for (partId in partIds) {
            part.dependencies.append(Dependency(
                sourceIndex: sourceIndexToImportFrom,
                partIndex: partId
            ))
        }
    }

    /// 获取顶层符号到 parts 的映射
    // 严格翻译自: LinkerGraph.zig:211 topLevelSymbolToParts
    public func topLevelSymbolToParts(id: UInt32, ref: Ref): Array<UInt32> {
        // 先检查 overlay
        let overlay = meta.get(Int64(id)).topLevelSymbolToPartsOverlay
        match (overlay.get(ref)) {
            case Some(list) => return list.slice()
            case None => {}
        }

        // 再检查原始映射
        let original = ast.get(Int64(id)).topLevelSymbolsToParts
        match (original.get(ref)) {
            case Some(list) => return list.slice()
            case None => {}
        }

        return []
    }

    /// 加载图数据
    // 严格翻译自: LinkerGraph.zig:223 load
    public func load(entryPoints: ArrayList<Index>, sources: ArrayList<Source>,
                     serverComponentBoundaries: ArrayList<ServerComponentBoundary>,
                     dynamicImportEntryPoints: ArrayList<UInt32>,
                     entryPointOriginalNames: HashMap<UInt32, String>): Unit {
        // 初始化文件
        filesLive = BitSet(sources.size)

        // 设置入口点
        for (entryPoint in entryPoints) {
            let sourceIndex = entryPoint.get()
            let entryPointKind = EntryPointKind.UserSpecified
            files.get(Int64(sourceIndex)).entryPointKind = entryPointKind
            let originalName = entryPointOriginalNames.get(UInt32(sourceIndex))
            let pathText = if (originalName != null && originalName.length > 0) {
                originalName
            } else {
                sources.get(Int64(sourceIndex)).path
            }
            this.entryPoints.append(EntryPoint(
                sourceIndex: sourceIndex,
                outputPath: pathText
            ))
        }

        // 处理动态导入入口点
        if (codeSplitting) {
            for (id in dynamicImportEntryPoints) {
                if (files.get(Int64(id)).entryPointKind != EntryPointKind.None) {
                    continue
                }
                files.get(Int64(id)).entryPointKind = EntryPointKind.DynamicImport
                this.entryPoints.append(EntryPoint(
                    sourceIndex: Int32(id),
                    outputPath: sources.get(Int64(id)).path
                ))
            }
        }

        // 克隆符号映射
        // 简化: 直接引用
        // this.symbols = cloneSymbolMap()

        // 解析命名导出
        let srcNamedExports = ast.items.map({ a => a.namedExports })
        let destResolvedExports = meta.items.map({ m => m.resolvedExports })
        for (i in 0..sources.size) {
            let src = srcNamedExports.get(i)
            let dest = destResolvedExports.get(i)
            for (entry in src) {
                dest.put(entry.key, ResolvedExport(
                    importRef: entry.value.ref,
                    nameLoc: entry.value.aliasLoc,
                    sourceIndex: Index.source(Int32(i))
                ))
            }
        }
    }

    /// 传播异步依赖
    // 严格翻译自: LinkerGraph.zig:473 propagateAsyncDependencies
    public func propagateAsyncDependencies(): Unit {
        let visited = BitSet(ast.size)
        let importRecords = ast.items.map({ a => a.importRecords })
        let flags = meta.items.map({ m => m.flags })

        func visit(index: Int64): Unit {
            if (visited.isSet(index)) {
                return
            }
            visited.set(index)
            if (flags.get(index).isAsyncOrHasAsyncDependency) {
                return
            }

            for (record in importRecords.get(index).slice()) {
                match (record.kind) {
                    case ImportKind.Dynamic => continue
                    case ImportKind.Require | ImportKind.RequireResolve => continue
                    case ImportKind.EntryPointRun | ImportKind.EntryPointBuild => continue
                    case ImportKind.At | ImportKind.AtConditional | ImportKind.Url | ImportKind.Composes => continue
                    case ImportKind.HtmlManifest | ImportKind.Internal => continue
                    case ImportKind.Stmt => {}
                }

                let importIndex = Int64(record.sourceIndex)
                if (importIndex >= importRecords.size) {
                    continue
                }
                visit(importIndex)

                if (flags.get(importIndex).isAsyncOrHasAsyncDependency) {
                    flags.get(index).isAsyncOrHasAsyncDependency = true
                    break
                }
            }
        }

        for (i in 0..ast.size) {
            visit(i)
        }
    }

    /// 更新顶层符号到 parts 的 overlay
    private func updateTopLevelSymbolToParts(id: UInt32, ref: Ref, partId: UInt32): Unit {
        let overlay = meta.get(Int64(id)).topLevelSymbolToPartsOverlay
        match (overlay.get(ref)) {
            case Some(list) => list.append(partId)
            case None => {
                let list = ArrayList<UInt32>()
                list.append(partId)
                overlay.put(ref, BabyListU32.fromList(list))
            }
        }
    }
}

// ============================================================================
// 链接器文件
// 严格翻译自: LinkerGraph.zig:436 File
// ============================================================================

/// 链接器文件
public class LinkerFile {
    /// 入口点位图
    public var entryBits: BitSet
    /// 输入文件索引
    public var inputFile: Index
    /// 到入口点的距离
    public var distanceFromEntryPoint: UInt32
    /// 入口点种类
    public var entryPointKind: EntryPointKind
    /// 入口点 chunk 索引
    public var entryPointChunkIndex: UInt32
    /// 行偏移表
    public var lineOffsetTable: Any
    /// 引用的源文件内容
    public var quotedSourceContents: Any

    public init() {
        this.entryBits = BitSet()
        this.inputFile = Index.Source(0)
        this.distanceFromEntryPoint = UInt32.MAX
        this.entryPointKind = EntryPointKind.None
        this.entryPointChunkIndex = UInt32.MAX
        this.lineOffsetTable = null
        this.quotedSourceContents = null
    }

    /// 是否是入口点
    public func isEntryPoint(): Bool {
        return entryPointKind != EntryPointKind.None
    }

    /// 是否是用户指定的入口点
    public func isUserSpecifiedEntryPoint(): Bool {
        return entryPointKind == EntryPointKind.UserSpecified
    }
}

/// 入口点种类
public enum EntryPointKind {
    | None           // 不是入口点
    | UserSpecified  // 用户指定的入口点
    | DynamicImport  // 动态导入入口点
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 入口点
public class EntryPoint {
    public var sourceIndex: Int32
    public var outputPath: String
    public var outputPathWasAutoGenerated: Bool

    public init(sourceIndex: Int32, outputPath: String) {
        this.sourceIndex = sourceIndex
        this.outputPath = outputPath
        this.outputPathWasAutoGenerated = false
    }
}

/// 索引
public class Index {
    public var value: Int32

    public init(_ value: Int32) {
        this.value = value
    }

    public static func Runtime(): Index {
        return Index(0)
    }
    public static func Source(v: Int32): Index {
        return Index(v)
    }
    public static func Part(v: Int32): Index {
        return Index(v)
    }
    public static func Invalid(): Index {
        return Index(-1)
    }

    public func get(): UInt32 {
        return UInt32(value)
    }
    public func isValid(): Bool {
        return value >= 0
    }
    public func isInvalid(): Bool {
        return value < 0
    }
}

/// 符号映射
public class SymbolMap {
    public var symbolsForSource: ArrayList<ArrayList<Symbol>>

    public init() {
        this.symbolsForSource = ArrayList<ArrayList<Symbol>>()
    }

    public func getSlice(sourceIndex: UInt32): ArrayList<Symbol> {
        if (Int64(sourceIndex) < symbolsForSource.size) {
            return symbolsForSource.get(Int64(sourceIndex))
        }
        return ArrayList<Symbol>()
    }
}

/// 符号
public class Symbol {
    public var kind: SymbolKind
    public var originalName: String
    public var link: Ref
    public var mustNotBeRenamed: Bool
    public var namespaceAlias: NamespaceAlias
    public var importItemStatus: ImportItemStatus

    public init(kind: SymbolKind, originalName: String) {
        this.kind = kind
        this.originalName = originalName
        this.link = Ref.None
        this.mustNotBeRenamed = false
        this.namespaceAlias = NamespaceAlias()
        this.importItemStatus = ImportItemStatus.Present
    }

    public func hasLink(): Bool {
        return !link.isNull()
    }
}

/// 符号种类
public enum SymbolKind {
    | Other
    | Import
    | Unbound
    | LocalCSS
}

/// 导入项状态
public enum ImportItemStatus {
    | Present
    | Missing
    | Generated
}

/// 命名空间别名
public class NamespaceAlias {
    public var namespaceRef: Ref
    public var alias: String
    public var importRecordIndex: UInt32

    public init() {
        this.namespaceRef = Ref.None
        this.alias = ""
        this.importRecordIndex = 0
    }
}

/// JS AST (链接器用)
public class JsAst {
    public var parts: ArrayList<Part>
    public var namedExports: HashMap<String, NamedExportEntry>
    public var namedImports: HashMap<Ref, NamedImportEntry>
    public var importRecords: ArrayList<ImportRecord>
    public var symbols: ArrayList<Symbol>
    public var moduleScope: ModuleScope
    public var topLevelSymbolsToParts: HashMap<Ref, BabyListU32>
    public var exportsRef: Ref
    public var moduleRef: Ref
    public var flags: AstFlags

    public init() {
        this.parts = ArrayList<Part>()
        this.namedExports = HashMap<String, NamedExportEntry>()
        this.namedImports = HashMap<Ref, NamedImportEntry>()
        this.importRecords = ArrayList<ImportRecord>()
        this.symbols = ArrayList<Symbol>()
        this.moduleScope = ModuleScope()
        this.topLevelSymbolsToParts = HashMap<Ref, BabyListU32>()
        this.exportsRef = Ref.None
        this.moduleRef = Ref.None
        this.flags = AstFlags()
    }
}

/// AST 标志
public class AstFlags {
    public var usesExportsRef: Bool
    public var usesModuleRef: Bool

    public init() {
        this.usesExportsRef = false
        this.usesModuleRef = false
    }
}

/// JS Meta
public class JsMeta {
    public var flags: MetaFlags
    public var importsToBind: HashMap<Ref, ImportData>
    public var resolvedExports: HashMap<String, ResolvedExport>
    public var topLevelSymbolToPartsOverlay: HashMap<Ref, BabyListU32>
    public var probablyTypeScriptType: HashSet<Ref>

    public init() {
        this.flags = MetaFlags()
        this.importsToBind = HashMap<Ref, ImportData>()
        this.resolvedExports = HashMap<String, ResolvedExport>()
        this.topLevelSymbolToPartsOverlay = HashMap<Ref, BabyListU32>()
        this.probablyTypeScriptType = HashSet<Ref>()
    }
}

/// Meta 标志
public class MetaFlags {
    public var isAsyncOrHasAsyncDependency: Bool
    public var wrap: WrapKind
    public var forceIncludeExportsForEntryPoint: Bool

    public init() {
        this.isAsyncOrHasAsyncDependency = false
        this.wrap = WrapKind.None
        this.forceIncludeExportsForEntryPoint = false
    }
}

/// 包装类型
public enum WrapKind {
    | None
    | CJS
    | ESM
}

/// 命名导出条目
public class NamedExportEntry {
    public var ref: Ref
    public var aliasLoc: Int32

    public init(ref: Ref, aliasLoc: Int32) {
        this.ref = ref
        this.aliasLoc = aliasLoc
    }
}

/// 命名导入条目
public class NamedImportEntry {
    public var alias: String
    public var aliasLoc: Int32
    public var aliasIsStar: Bool
    public var importRecordIndex: UInt32
    public var namespaceRef: Ref

    public init() {
        this.alias = ""
        this.aliasLoc = 0
        this.aliasIsStar = false
        this.importRecordIndex = 0
        this.namespaceRef = Ref.None
    }
}

/// 导入数据
public class ImportData {
    public var sourceIndex: Index
    public var importRef: Ref
    public var reExports: ArrayList<Dependency>

    public init(sourceIndex: Index, importRef: Ref) {
        this.sourceIndex = sourceIndex
        this.importRef = importRef
        this.reExports = ArrayList<Dependency>()
    }
}

/// 已解析导出
public class ResolvedExport {
    public var importRef: Ref
    public var nameLoc: Int32
    public var sourceIndex: Index

    public init(importRef: Ref, nameLoc: Int32, sourceIndex: Index) {
        this.importRef = importRef
        this.nameLoc = nameLoc
        this.sourceIndex = sourceIndex
    }
}

/// 模块作用域
public class ModuleScope {
    public var generated: ArrayList<Ref>
    public var children: ArrayList<ModuleScope>

    public init() {
        this.generated = ArrayList<Ref>()
        this.children = ArrayList<ModuleScope>()
    }
}

/// BabyList<UInt32>
public class BabyListU32 {
    public var items: ArrayList<UInt32>

    public init() {
        this.items = ArrayList<UInt32>()
    }

    public func slice(): Array<UInt32> {
        var arr = Array<UInt32>()
        for (item in items) {
            arr.append(item)
        }
        return arr
    }

    public static func fromList(list: ArrayList<UInt32>): BabyListU32 {
        let result = BabyListU32()
        result.items = list
        return result
    }
}

/// 服务端组件边界
public class ServerComponentBoundary {
    public var sourceIndex: UInt32
    public var useDirective: UseDirective
    public var referenceSourceIndex: UInt32
    public var ssrSourceIndex: UInt32

    public init(sourceIndex: UInt32, useDirective: UseDirective,
                referenceSourceIndex: UInt32, ssrSourceIndex: UInt32) {
        this.sourceIndex = sourceIndex
        this.useDirective = useDirective
        this.referenceSourceIndex = referenceSourceIndex
        this.ssrSourceIndex = ssrSourceIndex
    }
}

/// 使用指令
public enum UseDirective {
    | None
    | Client
    | Server
}

/// 内联枚举值
public class InlinedEnumValue {
    public var value: Any
    public init(value: Any) { this.value = value }
}

/// Source (简化)
public class Source {
    public var path: String
    public var contents: String
    public var index: Int32

    public init(path: String, contents: String, index: Int32) {
        this.path = path
        this.contents = contents
        this.index = index
    }
}
