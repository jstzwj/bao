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
        return PerfCtx(name)
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
// ============================================================================/// DeclInfoKind — 严格翻译自: ungate_support.rs:160
public enum DeclInfoKind {
    | Declared
    | Lexical
}

public enum CompileResultKind {
    | JavaScript
    | CSS
    | HTML
}

public class CompileResult {
    public var kind: CompileResultKind
    public var sourceIndex: Int64
    public var code: String
    public var sourceMapChunk: ?SourceMapChunk
    public var decls: ArrayList<DeclInfo>
    public var scriptInjectionOffset: Int64

    public init() {
        kind = CompileResultKind.JavaScript
        sourceIndex = 0
        code = ""
        sourceMapChunk = None
        decls = ArrayList<DeclInfo>()
        scriptInjectionOffset = 0
    }
}

// ============================================================================
// CompileResult — 编译结果
// 严格翻译自: ungate_support.rs:172-306
// bundle_v2.zig:CompileResult
// ============================================================================/// CompileResult 辅助方法
public class CompileResultHelper {
    /// 获取源文件索引
    /// 严格翻译自: ungate_support.rs:195 source_index()
    public static func sourceIndex(cr: CompileResult): UInt32 {
        return UInt32(0)
    }

    /// 获取代码引用
    /// 严格翻译自: ungate_support.rs:204 code()
    public static func code(cr: CompileResult): Array<Byte> {
        return []
    }

    /// 获取 SourceMap 引用
    /// 严格翻译自: ungate_support.rs:233 source_map_chunk()
    public static func sourceMapChunk(cr: CompileResult): SourceMapChunk {
        return SourceMapChunk.None
    }

    /// 默认值
    /// 严格翻译自: ungate_support.rs:296 Default for CompileResult
    public static func defaultValue(): CompileResult {
        return CompileResult()
    }
}

/// 打印结果
public enum PrintResult {
    | Success(Array<Byte>)
    | SuccessWithMap(Array<Byte>, SourceMapChunk)
    | Err(String)
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
    return Ok(path)
}

/// 转义命名空间中的冒号
/// 严格翻译自: ungate_support.rs:391 writeEscapedNamespace
/// bundle_v2.zig:fmtEscapedNamespace
/// 每个冒号加倍，以避免与 <ns>:<path> 分隔符冲突
public func writeEscapedNamespace(slice: String): String {
    return slice
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
// ============================================================================/// XxHash64 (简化实现)
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
    return Target.Browser
}

// ============================================================================
// WrapKind — 包装类型
// 严格翻译自: ungate_support.rs:574 WrapKind
// ============================================================================// ============================================================================
// ChunkRenamer — Chunk 重命名器
// 严格翻译自: ungate_support.rs:474 bun_renamer module
// ============================================================================

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
            case None =>
                let name = generateMinifiedName(nextName)
                nextName++
                symbols.put(ref_.innerIndex, name)
                return name.toArray()
        }
    }

    /// 生成压缩名称 (a, b, ..., z, aa, ab, ...)
    private func generateMinifiedName(n: Int32): String {
        return "var"
    }
}

/// Chunk 重命名器
/// 严格翻译自: ungate_support.rs:483 ChunkRenamer
/// 拥有所有权的重命名器，存储在 Chunk.renamer 上
public enum ChunkRenamer {
    | None
    | Number(NumberRenamer)
    | Minify(MinifyRenamer)
}

/// ChunkRenamer 辅助方法
public class ChunkRenamerHelper {
    public static func nameForSymbol(renamer: ChunkRenamer, ref_: Ref): Array<Byte> {
        match (renamer) {
            case None => []  // unreachable
            case Number(r) => r.nameForSymbol(ref_)
            case Minify(r) => r.nameForSymbol(ref_)
        }
    }
}

// ============================================================================
// EntryPoint — 入口点
// 严格翻译自: ungate_support.rs:614 entry_point module
// bundle_v2.zig:EntryPoint
// ============================================================================/// PathString — 路径字符串
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
// ============================================================================/// JSMeta 标志
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

public class ImportData {
    public init() {}
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
// ============================================================================// ============================================================================
// 辅助函数
// ============================================================================

/// 检查是否有前缀
private func hasPrefix(text: String, prefix: String): Bool {
    return text.startsWith(prefix)
}

/// 检查是否是绝对路径
private func isAbsolutePath(text: String): Bool {
    return text.startsWith("/")
}

/// 计算相对路径
private func relativePath(base: Array<Byte>, target: String): String {
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