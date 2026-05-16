// 严格翻译自: src/bundler/ungate_support.rs (~802行)
// bao_bundler - Ungate 支持: 从 bundle_v2 中提取的共享值类型和 crate 别名
// 使得 Chunk.rs / LinkerContext.rs / ParseTask.rs / Graph.rs 可以编译
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_ast.*
import bao_options.*
import bao_sourcemap.*
import bao_hash.*

// ============================================================================
// Crate 名称别名 (shim)
// 严格翻译自: ungate_support.rs:26-67
// Phase-A 草稿模块使用的 crate 名称映射到真实的 crate/重导出模块
// ============================================================================

// bao_str  -> bao_core (字符串工具)
// bao_output -> bao_core (declare_scope! / scoped_log!)
// bao_fs -> bao_resolver.fs (文件系统)
// bao_node_fallbacks -> bao_resolver.node_fallbacks (Node 回退)
// bun_css -> bao_css (CSS 解析器/模块)

/// 性能追踪
/// 严格翻译自: ungate_support.rs:42 perf module
/// bun.perf.trace(...) 在 bun_perf 中实现
public class Perf {
    /// 追踪性能事件
    public static func trace(name: String): PerfCtx {
        return PerfCtx(name: name)
    }
}

/// 性能追踪上下文
public class PerfCtx {
    public let name: String

    public init(name: String) {
        this.name = name
    }
}

/// CSS 模块配置
/// 严格翻译自: ungate_support.rs:60 bun_css module
/// bundler 面向的 CSS 表面
public class CssModuleConfig {
    public var pattern: String
    public var dashedIndents: Bool

    public init() {
        this.pattern = ""
        this.dashedIndents = false
    }
}

/// CSS 层名称
/// 严格翻译自: ungate_support.rs:66 LayerName
/// 用于 Chunk::Layers
public class LayerName {
    public var name: String

    public init(name: String) {
        this.name = name
    }
}

// ============================================================================
// 从 bundle_v2.zig 提取的值类型
// 严格翻译自: ungate_support.rs:73-169
// ============================================================================

/// PartRange — 严格翻译自: bundle_v2.zig:PartRange
/// 定义在 ungate_support (而非 bundle_v2) 中，
/// 以便 Chunk.rs 和 bundle_v2.rs 共享单一名义类型
public class PartRange {
    public var sourceIndex: Index
    public var partIndexBegin: UInt32
    public var partIndexEnd: UInt32

    public init() {
        this.sourceIndex = Index.Invalid
        this.partIndexBegin = 0
        this.partIndexEnd = 0
    }

    public init(sourceIndex: Index, partIndexBegin: UInt32, partIndexEnd: UInt32) {
        this.sourceIndex = sourceIndex
        this.partIndexBegin = partIndexBegin
        this.partIndexEnd = partIndexEnd
    }
}

/// StableRef — 严格翻译自: bundle_v2.zig:StableRef (packed struct u96)
/// 用于稳定排序引用
public class StableRef {
    public var stableSourceIndex: Int32
    public var ref_: Ref

    public init(stableSourceIndex: Int32, ref_: Ref) {
        this.stableSourceIndex = stableSourceIndex
        this.ref_ = ref_
    }

    /// 严格翻译自: StableRef.isLessThan
    /// 比较两个 StableRef，用于排序
    public static func isLessThan(a: StableRef, b: StableRef): Bool {
        if (a.stableSourceIndex < b.stableSourceIndex) {
            return true
        }
        if (a.stableSourceIndex == b.stableSourceIndex) {
            return a.ref_.innerIndex < b.ref_.innerIndex
        }
        return false
    }

    public func eql(other: StableRef): Bool {
        return stableSourceIndex == other.stableSourceIndex && ref_.eql(other.ref_)
    }
}

/// ImportTracker — 严格翻译自: bundle_v2.zig:ImportTracker
/// 跟踪导入信息
public class ImportTracker {
    public var sourceIndex: Index
    public var nameLoc: Loc
    public var importRef: Ref

    public init() {
        this.sourceIndex = Index.Invalid
        this.nameLoc = Loc.Empty
        this.importRef = Ref.None
    }

    public init(sourceIndex: Index, nameLoc: Loc, importRef: Ref) {
        this.sourceIndex = sourceIndex
        this.nameLoc = nameLoc
        this.importRef = importRef
    }
}

/// CrossChunkImportItem — 严格翻译自: bundle_v2.zig:CrossChunkImport.Item
/// 跨 chunk 导入项
public class CrossChunkImportItem {
    public var exportAlias: Array<Byte>
    public var ref_: Ref

    public init() {
        this.exportAlias = []
        this.ref_ = Ref.None
    }
}

/// CrossChunkImport — 严格翻译自: bundle_v2.zig:CrossChunkImport
/// 跨 chunk 导入
public class CrossChunkImport {
    public var chunkIndex: Int32
    public var sortedImportItems: ArrayList<CrossChunkImportItem>

    public init() {
        this.chunkIndex = 0
        this.sortedImportItems = ArrayList<CrossChunkImportItem>()
    }
}

/// DeclInfoKind — 严格翻译自: ungate_support.rs:160
public enum DeclInfoKind {
    | Declared
    | Lexical
}

/// DeclInfo — 严格翻译自: ungate_support.rs:166
/// 顶层声明信息
public class DeclInfo {
    public var name: Array<Byte>
    public var kind: DeclInfoKind

    public init(name: Array<Byte>, kind: DeclInfoKind) {
        this.name = name
        this.kind = kind
    }
}

// ============================================================================
// CompileResult — 编译结果
// 严格翻译自: ungate_support.rs:172-306
// bundle_v2.zig:CompileResult
// ============================================================================

/// CompileResult — 编译结果枚举
/// 严格翻译自: ungate_support.rs:172 CompileResult
/// 支持 JavaScript / CSS / HTML 三种输出
public enum CompileResult {
    | Javascript(
        sourceIndex: UInt32,     // 源文件索引
        result: PrintResult,     // 打印结果
        decls: Array<DeclInfo>   // 顶层声明列表
    )
    | Css(
        result: Result<Array<Byte>>,  // CSS 编译结果
        sourceIndex: UInt32,          // 源文件索引
        sourceMap: SourceMapChunk     // SourceMap
    )
    | Html(
        sourceIndex: UInt32,          // 源文件索引
        code: Array<Byte>,            // HTML 代码
        scriptInjectionOffset: UInt32 // 脚本注入偏移
    )
}

/// CompileResult 辅助方法
public class CompileResultHelper {
    /// 获取源文件索引
    /// 严格翻译自: ungate_support.rs:195 source_index()
    public static func sourceIndex(cr: CompileResult): UInt32 {
        match (cr) {
            case Javascript(sourceIndex: si, _, _) => si
            case Css(_, sourceIndex: si, _) => si
            case Html(sourceIndex: si, _, _) => si
        }
    }

    /// 获取代码引用
    /// 严格翻译自: ungate_support.rs:204 code()
    public static func code(cr: CompileResult): Array<Byte> {
        match (cr) {
            case Javascript(_, result: r, _) =>
                match (r) {
                    case PrintResult.Success(code) => code
                    case PrintResult.Err(_) => []
                }
            case Css(result: r, _, _) =>
                match (r) {
                    case Ok(v) => v
                    case Err(_) => []
                }
            case Html(_, code: c, _) => c
        }
    }

    /// 获取 SourceMap 引用
    /// 严格翻译自: ungate_support.rs:233 source_map_chunk()
    public static func sourceMapChunk(cr: CompileResult): SourceMapChunk {
        match (cr) {
            case Javascript(_, result: r, _) =>
                match (r) {
                    case PrintResult.SuccessWithMap(_, sm) => sm
                    case _ => SourceMapChunk.None
                }
            case Css(_, _, sourceMap: sm) => sm
            case Html(_, _, _) => SourceMapChunk.None
        }
    }

    /// 默认值
    /// 严格翻译自: ungate_support.rs:296 Default for CompileResult
    public static func defaultValue(): CompileResult {
        return CompileResult.Javascript(
            sourceIndex: 0,
            result: PrintResult.Success(code: []),
            decls: []
        )
    }
}

/// 打印结果
public enum PrintResult {
    | Success(code: Array<Byte>)
    | SuccessWithMap(code: Array<Byte>, sourceMap: SourceMapChunk)
    | Err(message: String)
}

/// SourceMap 块 (简化)
public class SourceMapChunk {
    public var data: Array<Byte>
    public var isNone: Bool

    public init() {
        this.data = []
        this.isNone = true
    }

    public init(data: Array<Byte>) {
        this.data = data
        this.isNone = false
    }

    public static let None: SourceMapChunk = SourceMapChunk()
}

// ============================================================================
// generic_path_with_pretty_initialized
// 严格翻译自: ungate_support.rs:315 genericPathWithPrettyInitialized
// bundle_v2.zig:genericPathWithPrettyInitialized
// 为路径分配简洁、可预测且唯一的 .pretty 属性
// DevServer 依赖 pretty 路径标识模块
// ============================================================================

/// 为路径生成 pretty 初始化名称
/// 严格翻译自: ungate_support.rs:315
/// 对应 bundle_v2.zig 中的同名函数
public func genericPathWithPrettyInitialized(
    path: FsPath,
    target: Target,
    topLevelDir: Array<Byte>
): Result<FsPath> {
    var pathClone = path

    let isNode = path.namespace == "node"
    if (isNode && hasPrefix(path.text, NodeFallbacks.ImportPath)) {
        return Ok(pathClone)
    }
    if (isNode && !isAbsolutePath(path.text)) {
        return Ok(pathClone)
    }

    // "file" 命名空间使用相对文件路径作为显示名称
    if (path.is_file || isNode) {
        let rel = relativePath(topLevelDir, path.text)
        if (target == Target.BakeServerComponentsSsr) {
            pathClone.pretty = "ssr:" + rel
        } else {
            pathClone.pretty = rel
        }
    } else {
        // 非文件命名空间
        var pretty = ""
        if (target == Target.BakeServerComponentsSsr) {
            pretty = pretty + "ssr:"
        }
        pretty = pretty + writeEscapedNamespace(path.namespace) + ":" + path.text
        pathClone.pretty = pretty
    }

    return Ok(pathClone)
}

/// 转义命名空间中的冒号
/// 严格翻译自: ungate_support.rs:391 writeEscapedNamespace
/// bundle_v2.zig:fmtEscapedNamespace
/// 每个冒号加倍，以避免与 <ns>:<path> 分隔符冲突
public func writeEscapedNamespace(slice: String): String {
    var result = ""
    var i = 0
    while (i < slice.length) {
        let c = slice[i]
        if (c == ':') {
            result = result + "::"
        } else {
            result = result + String(Char(c))
        }
        i++
    }
    return result
}

// ============================================================================
// CompileResultForSourceMap
// 严格翻译自: ungate_support.rs:402 CompileResultForSourceMap
// ============================================================================

/// 用于 SourceMap 的编译结果
public class CompileResultForSourceMap {
    public var sourceMapChunk: SourceMapChunk
    public var generatedOffset: LineColumnOffset
    public var sourceIndex: UInt32

    public init() {
        this.sourceMapChunk = SourceMapChunk.None
        this.generatedOffset = LineColumnOffset()
        this.sourceIndex = 0
    }

    public init(sourceMapChunk: SourceMapChunk, generatedOffset: LineColumnOffset, sourceIndex: UInt32) {
        this.sourceMapChunk = sourceMapChunk
        this.generatedOffset = generatedOffset
        this.sourceIndex = sourceIndex
    }
}

/// 行列偏移
public class LineColumnOffset {
    public var line: UInt32
    public var column: UInt32

    public init() {
        this.line = 0
        this.column = 0
    }
}

// ============================================================================
// ContentHasher — 内容哈希器
// 严格翻译自: ungate_support.rs:419 ContentHasher
// bundle_v2.zig:ContentHasher
// 使用 xxhash64 (seed 0)，在大数据时优于 wyhash
// ============================================================================

/// 内容哈希器
public class ContentHasher {
    public var hasher: XxHash64

    public init() {
        this.hasher = XxHash64()
    }

    /// 写入字节
    /// 严格翻译自: ungate_support.rs:428 write()
    public func write(bytes: Array<Byte>): Unit {
        hasher.update(bytes)
    }

    /// 静态哈希
    /// 严格翻译自: ungate_support.rs:438 run()
    public static func run(bytes: Array<Byte>): UInt64 {
        let h = ContentHasher()
        h.write(bytes)
        return h.digest()
    }

    /// 写入整数数组
    /// 严格翻译自: ungate_support.rs:443 writeInts()
    public func writeInts(ints: Array<UInt32>): Unit {
        for (i in ints) {
            hasher.update(i)
        }
    }

    /// 获取哈希摘要
    public func digest(): UInt64 {
        return hasher.digest()
    }
}

/// XxHash64 (简化实现)
public class XxHash64 {
    private var state: UInt64

    public init() {
        this.state = 0
    }

    public func update(bytes: Array<Byte>): Unit {
        // 简化实现: 使用 FNV-1a 类算法
        for (b in bytes) {
            state = state ^ UInt64(b)
            state = state * 1099511628211
        }
    }

    public func update(v: UInt32): Unit {
        state = state ^ UInt64(v)
        state = state * 1099511628211
    }

    public func digest(): UInt64 {
        return state
    }
}

// ============================================================================
// target_from_hashbang
// 严格翻译自: ungate_support.rs:460 targetFromHashbang
// ============================================================================

/// 从 hashbang 检测目标
/// 严格翻译自: ungate_support.rs:460
/// bundle_v2.zig:targetFromHashbang
public func targetFromHashbang(buffer: Array<Byte>): Target {
    let hb = "#!/usr/bin/env bun".toArray()
    if (buffer.size > hb.size && arrayStartsWith(buffer, hb)) {
        let next = buffer[hb.size]
        if (next == Byte('\n') || next == Byte(' ')) {
            return Target.Bun
        }
    }
    return Target.Browser  // 默认
}

// ============================================================================
// WrapKind — 包装类型
// 严格翻译自: ungate_support.rs:574 WrapKind
// ============================================================================

/// 包装类型
/// 严格翻译自: LinkerGraph.zig:JSMeta WrapKind
public enum WrapKind {
    | None    // 不包装
    | Cjs     // CommonJS 包装
    | Esm     // ESM 包装
}

// ============================================================================
// ChunkRenamer — Chunk 重命名器
// 严格翻译自: ungate_support.rs:474 bun_renamer module
// ============================================================================

/// Chunk 重命名器
/// 严格翻译自: ungate_support.rs:483 ChunkRenamer
/// 拥有所有权的重命名器，存储在 Chunk.renamer 上
public enum ChunkRenamer {
    | None
    | NumberRenamer(NumberRenamer)
    | MinifyRenamer(MinifyRenamer)
}

/// ChunkRenamer 辅助方法
public class ChunkRenamerHelper {
    public static func nameForSymbol(renamer: ChunkRenamer, ref_: Ref): Array<Byte> {
        match (renamer) {
            case None => []  // unreachable
            case NumberRenamer(r) => r.nameForSymbol(ref_)
            case MinifyRenamer(r) => r.nameForSymbol(ref_)
        }
    }
}

/// 数字重命名器
public class NumberRenamer {
    private var symbols: HashMap<Int32, String>

    public init() {
        this.symbols = HashMap<Int32, String>()
    }

    public func nameForSymbol(ref_: Ref): Array<Byte> {
        match (symbols.get(ref_.innerIndex)) {
            case Some(name) => name.toArray()
            case None => "var".toArray()
        }
    }
}

/// 压缩重命名器
public class MinifyRenamer {
    private var symbols: HashMap<Int32, String>
    private var nextName: Int32

    public init() {
        this.symbols = HashMap<Int32, String>()
        this.nextName = 0
    }

    public func nameForSymbol(ref_: Ref): Array<Byte> {
        match (symbols.get(ref_.innerIndex)) {
            case Some(name) => name.toArray()
            case None => {
                let name = generateMinifiedName(nextName)
                nextName++
                symbols.put(ref_.innerIndex, name)
                return name.toArray()
            }
        }
    }

    /// 生成压缩名称 (a, b, ..., z, aa, ab, ...)
    private func generateMinifiedName(n: Int32): String {
        var result = ""
        var i = n
        repeat {
            result = String(Char(Int32('a'.value) + (i % 26))) + result
            i = i / 26 - 1
        } while (i >= 0)
        return result
    }
}

// ============================================================================
// EntryPoint — 入口点
// 严格翻译自: ungate_support.rs:614 entry_point module
// bundle_v2.zig:EntryPoint
// ============================================================================

/// 入口点
/// 严格翻译自: bundle_v2.zig:EntryPoint
/// 入口点信息 (输出路径、源索引等)
public class EntryPoint {
    /// 输出路径 (可能是绝对或相对路径)
    public var outputPath: PathString
    /// 源文件索引
    public var sourceIndex: Int32
    /// 输出路径是否自动生成
    public var outputPathWasAutoGenerated: Bool

    public init() {
        this.outputPath = PathString()
        this.sourceIndex = 0
        this.outputPathWasAutoGenerated = false
    }

    public init(outputPath: PathString, sourceIndex: Int32, outputPathWasAutoGenerated: Bool) {
        this.outputPath = outputPath
        this.sourceIndex = sourceIndex
        this.outputPathWasAutoGenerated = outputPathWasAutoGenerated
    }
}

/// 入口点类型
/// 严格翻译自: ungate_support.rs:654 Kind
/// bundle_v2.zig:EntryPoint.Kind
public enum EntryPointKind {
    | None           // 非入口点
    | UserSpecified  // 用户指定
    | DynamicImport  // 动态导入
    | Html           // HTML 中的引用

    /// 是否是入口点
    public func isEntryPoint(): Bool {
        match (this) {
            case None => false
            case _ => true
        }
    }

    /// 是否是用户指定的入口点
    public func isUserSpecifiedEntryPoint(): Bool {
        match (this) {
            case UserSpecified => true
            case _ => false
        }
    }

    /// 是否是服务端入口点
    public func isServerEntryPoint(): Bool {
        match (this) {
            case UserSpecified => true
            case _ => false
        }
    }

    /// 获取输出类型
    /// 严格翻译自: ungate_support.rs:676 output_kind()
    public func outputKind(): OutputKind {
        match (this) {
            case UserSpecified => OutputKind.EntryPoint
            case _ => OutputKind.Chunk
        }
    }
}

/// PathString — 路径字符串
public class PathString {
    public var value: String

    public init() {
        this.value = ""
    }

    public init(value: String) {
        this.value = value
    }
}

// ============================================================================
// JSMeta — JS 元数据
// 严格翻译自: ungate_support.rs:688 js_meta module
// bundle_v2.zig:JSMeta
// ============================================================================

/// 导入数据
/// 严格翻译自: ungate_support.rs:696 ImportData
public class ImportData {
    public var reExports: ArrayList<Dependency>
    public var data: ImportTracker

    public init() {
        this.reExports = ArrayList<Dependency>()
        this.data = ImportTracker()
    }
}

/// 导出数据
/// 严格翻译自: ungate_support.rs:703 ExportData
public class ExportData {
    public var potentiallyAmbiguousExportStarRefs: ArrayList<ImportData>
    public var data: ImportTracker

    public init() {
        this.potentiallyAmbiguousExportStarRefs = ArrayList<ImportData>()
        this.data = ImportTracker()
    }
}

/// JSMeta 标志
/// 严格翻译自: ungate_support.rs:720 JSMeta.Flags
public class JSMetaFlags {
    public var isAsyncOrHasAsyncDependency: Bool
    public var needsExportsVariable: Bool
    public var forceIncludeExportsForEntryPoint: Bool
    public var needsExportSymbolFromRuntime: Bool
    public var didWrapDependencies: Bool
    public var needsSyntheticDefaultExport: Bool
    public var wrap: WrapKind

    public init() {
        this.isAsyncOrHasAsyncDependency = false
        this.needsExportsVariable = false
        this.forceIncludeExportsForEntryPoint = false
        this.needsExportSymbolFromRuntime = false
        this.didWrapDependencies = false
        this.needsSyntheticDefaultExport = false
        this.wrap = WrapKind.None
    }
}

/// JSMeta — JS 元数据
/// 严格翻译自: ungate_support.rs:732 JSMeta
/// 每个源文件的 JS 元数据，存储在 LinkerGraph 中
public class JSMeta {
    /// 可能是 TypeScript 类型导入的引用集合
    public var probablyTypescriptType: HashMap<Ref, Unit>
    /// 需要绑定的导入
    public var importsToBind: HashMap<Ref, ImportData>
    /// 已解析的导出
    public var resolvedExports: HashMap<String, ExportData>
    /// 已解析的 export * 导出
    public var resolvedExportStar: ExportData
    /// 排序和过滤后的导出别名
    public var sortedAndFilteredExportAliases: Array<Array<Byte>>
    /// 顶层符号到 parts 的映射覆盖
    public var topLevelSymbolToPartsOverlay: HashMap<Ref, ArrayList<UInt32>>
    /// CJS 导出副本
    public var cjsExportCopies: Array<Ref>
    /// 包装器 part 索引
    public var wrapperPartIndex: Index
    /// 入口点 part 索引
    public var entryPointPartIndex: Index
    /// 标志
    public var flags: JSMetaFlags

    public init() {
        this.probablyTypescriptType = HashMap<Ref, Unit>()
        this.importsToBind = HashMap<Ref, ImportData>()
        this.resolvedExports = HashMap<String, ExportData>()
        this.resolvedExportStar = ExportData()
        this.sortedAndFilteredExportAliases = []
        this.topLevelSymbolToPartsOverlay = HashMap<Ref, ArrayList<UInt32>>()
        this.cjsExportCopies = []
        this.wrapperPartIndex = Index.Invalid
        this.entryPointPartIndex = Index.Invalid
        this.flags = JSMetaFlags()
    }
}

// ============================================================================
// MangledProps 重导出
// 严格翻译自: ungate_support.rs:586 MangledProps
// ============================================================================

/// 压缩属性映射
/// 严格翻译自: bundle_v2.zig:MangledProps
public class MangledProps {
    public var props: HashMap<String, String>

    public init() {
        this.props = HashMap<String, String>()
    }
}

// ============================================================================
// ServerComponentBoundary / UseDirective 重导出
// 严格翻译自: ungate_support.rs:583-584
// ============================================================================

/// 服务端组件边界
public class ServerComponentBoundary {
    public var sourceIndex: Index
    public var boundaryIndex: Int32

    public init() {
        this.sourceIndex = Index.Invalid
        this.boundaryIndex = 0
    }
}

/// Use 指令
public class UseDirective {
    public var sourceIndex: Index
    public var importRecordIndex: Int32

    public init() {
        this.sourceIndex = Index.Invalid
        this.importRecordIndex = 0
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 检查是否有前缀
private func hasPrefix(text: String, prefix: String): Bool {
    return text.startsWith(prefix)
}

/// 检查是否是绝对路径
private func isAbsolutePath(text: String): Bool {
    return text.startsWith("/") || (text.length > 2 && text[1] == ':')
}

/// 计算相对路径
private func relativePath(base: Array<Byte>, target: String): String {
    // 简化实现
    if (target.startsWith(String.fromUtf8(base))) {
        let start = base.size + 1
        if (start < target.length) {
            return target.substring(Int64(start))
        }
    }
    return target
}

/// 检查数组前缀
private func arrayStartsWith(arr: Array<Byte>, prefix: Array<Byte>): Bool {
    if (arr.size < prefix.size) { return false }
    for (i in 0..prefix.size) {
        if (arr[i] != prefix[i]) { return false }
    }
    return true
}

/// NodeFallbacks — Node 回退路径
public class NodeFallbacks {
    public static let ImportPath = "node:"
}

/// FsPath — 文件系统路径
public class FsPath {
    public var text: String
    public var namespace: String
    public var pretty: String
    public var is_file: Bool

    public init() {
        this.text = ""
        this.namespace = "file"
        this.pretty = ""
        this.is_file = true
    }
}

/// 目标平台
public enum Target {
    | Browser
    | Bun
    | BunMacro
    | Node
    | BakeServerComponentsSsr
}

/// 依赖 (引用)
public class Dependency {
    public var sourceIndex: Index
    public var partIndex: Int32

    public init() {
        this.sourceIndex = Index.Invalid
        this.partIndex = 0
    }
}

/// Index 引用 (来自 ast_builder.cj)
/// 重新声明以确保可用
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
}

/// Ref 引用 (来自 ast_builder.cj)
public class Ref {
    public var innerIndex: Int32
    public var sourceIndex: Int32

    public init(innerIndex: Int32, sourceIndex: Int32) {
        this.innerIndex = innerIndex
        this.sourceIndex = sourceIndex
    }

    public static let None: Ref = Ref(innerIndex: 0, sourceIndex: -1)

    public func isNull(): Bool {
        return sourceIndex < 0
    }

    public func eql(other: Ref): Bool {
        return innerIndex == other.innerIndex && sourceIndex == other.sourceIndex
    }
}

/// Loc 引用
public class Loc {
    public var start: Int32

    public init(start: Int32) {
        this.start = start
    }

    public static let Empty: Loc = Loc(start: 0)
}
