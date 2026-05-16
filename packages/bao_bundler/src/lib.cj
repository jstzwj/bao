// 严格翻译自: src/bundler/lib.rs (~398行)
// bao_bundler - 库根: 模块声明、类型重导出、crate 公共表面
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_ast.*
import bao_options.*

// ============================================================================
// 库根 — 模块声明与重导出
// 严格翻译自: src/bundler/lib.rs
// 在 Bun 中，lib.rs 是 bundler crate 的根模块，负责:
//   1. 声明所有子模块 (mod 声明)
//   2. 重导出核心类型 (pub use)
//   3. 定义公共接口类型 (OutputKind、AdditionalFile 等)
//   4. 提供 link-interface (DevServerHandle、VmLoaderCtx)
//   5. 实现 Default for OutputFile.Options/OptionsData
//
// 在仓颉中，包的根由 package.cj + 其他 .cj 文件组成，
// lib.cj 作为集中化的模块声明和重导出文件。
// ============================================================================

// ──────────────────────────────────────────────────────────────────────────
// 模块声明 (对应 Rust mod 声明)
// 在仓颉中，同一包内的所有 .cj 文件自动可见，无需显式 mod 声明。
// 这里仅列出对应关系，用于参考。
//
// 对应 Rust mod:
//   pub mod ungate_support;          -> ungate_support.cj
//   pub mod DeferredBatchTask;       -> deferred_batch_task.cj
//   pub mod Graph;                   -> graph.cj
//   pub mod IndexStringMap;          -> index_string_map.cj
//   pub mod PathToSourceIndexMap;    -> path_to_source_index_map.cj
//   pub mod BundleThread;            -> bundle_thread.cj
//   pub mod ServerComponentParseTask;-> server_component_parse_task.cj
//   pub mod HTMLImportManifest;      -> html_import_manifest.cj
//   pub mod HTMLScanner;             -> h_t_m_l_scanner.cj
//   pub mod cache;                   -> cache.cj
//   pub mod entry_points;            -> entry_points.cj
//   pub mod output_file;             -> output_file.cj
//   pub mod thread_pool;             -> thread_pool_bundler.cj
//   pub mod AstBuilder;              -> ast_builder.cj
//   pub mod analyze_transpiled_module;-> analyze_transpiled_module.cj
//   pub mod bundled_ast;             -> bundled_ast.cj
//   pub mod barrel_imports;          -> barrel_imports.cj
//   pub mod chunk;                   -> chunk.cj
//   pub mod defines;                 -> defines.cj
//   pub mod defines_table;           -> defines_table.cj
//   pub mod linker;                  -> linker.cj
//   pub mod linker_graph;            -> linker_graph.cj
//   pub mod bundle_v2;               -> bundle_v2.cj
//   pub mod linker_context;          -> linker_context.cj
//   pub mod options;                 -> options.cj + bundler_options.cj
//   pub mod parse_task;              -> parse_task.cj
//   pub mod transpiler;              -> transpiler.cj
//   pub mod plugin;                  -> plugin.cj
//   pub mod resolver;                -> resolver.cj
//   pub mod tree_shake;              -> tree_shake.cj
//   pub mod code_gen;                -> code_gen.cj
//   pub mod css_lexer;               -> css_lexer.cj
//   pub mod css_parser;              -> css_parser.cj
//   pub mod css_selector;            -> css_selector.cj
//   pub mod css_values;              -> css_values.cj
// ──────────────────────────────────────────────────────────────────────────

// ============================================================================
// linker_context 子模块声明
// 严格翻译自: src/bundler/lib.rs linker_context { ... }
// 在 Bun 中，linker_context/ 是一个子目录，包含约 22 个子模块:
//   scanImportsAndExports   -> linker_scan.cj
//   computeChunks           -> linker_generate.cj
//   computeCrossChunkDependencies -> linker_compute_cross_chunk_deps.cj
//   convertStmtsForChunk    -> linker_generate.cj
//   convertStmtsForChunkForDevServer -> linker_generate.cj
//   doStep5                 -> linker_generate.cj
//   findAllImportedPartsInJSOrder -> linker_find_imported_parts.cj
//   findImportedCSSFilesInJSOrder -> linker_generate.cj
//   findImportedFilesInCSSOrder -> linker_generate.cj
//   generateChunksInParallel -> linker_generate.cj
//   generateCodeForFileInChunkJS -> linker_generate.cj
//   generateCodeForLazyExport -> linker_generate_lazy_export.cj
//   generateCompileResultForCssChunk -> linker_generate.cj
//   generateCompileResultForHtmlChunk -> linker_generate.cj
//   generateCompileResultForJSChunk -> linker_generate.cj
//   postProcessCSSChunk     -> linker_generate.cj
//   postProcessHTMLChunk    -> linker_generate.cj
//   postProcessJSChunk      -> linker_generate.cj
//   prepareCssAstsForChunk  -> linker_generate.cj
//   renameSymbolsInChunk    -> linker_rename_symbols.cj
//   MetafileBuilder         -> linker_metafile.cj
//   OutputFileListBuilder   -> output_file_list_builder.cj
//   StaticRouteVisitor      -> static_route_visitor.cj
//   writeOutputFilesToDisk  -> output_file.cj
// ============================================================================

// ============================================================================
// 公共类型重导出
// 严格翻译自: src/bundler/lib.rs pub use 声明
// ============================================================================

/// AdditionalFile — 严格翻译自: lib.rs:206 AdditionalFile
/// 对应 bundle_v2.zig 中的 AdditionalFile
public enum AdditionalFile {
    | SourceIndex(UInt32)
    | OutputFile(UInt32)
}

/// OutputKind — 严格翻译自: lib.rs:242 options::OutputKind
/// jsc.API.BuildArtifact.OutputKind (JSBundler.zig:1799)
/// 表示输出文件的类型标签
public enum OutputKind {
    | Chunk          // "chunk"
    | Asset          // "asset"
    | EntryPoint     // "entry-point"
    | Sourcemap      // "sourcemap"
    | Bytecode       // "bytecode"
    | ModuleInfo     // "module_info"
    | MetafileJson   // "metafile-json"
    | MetafileMarkdown // "metafile-markdown"
}

/// OutputKind 辅助方法
public class OutputKindHelper {
    /// 严格翻译自: lib.rs:264 OutputKind::is_file_in_standalone_mode
    /// JSBundler.zig:1809
    /// 判断该输出类型是否是独立模式下的文件
    /// (非 sourcemap/bytecode/module_info/metafile 类型)
    public static func isFileInStandaloneMode(kind: OutputKind): Bool {
        match (kind) {
            case Sourcemap => false
            case Bytecode => false
            case ModuleInfo => false
            case MetafileJson => false
            case MetafileMarkdown => false
            case _ => true
        }
    }

    /// 获取 JS 面向的标签字符串
    public static func toStaticStr(kind: OutputKind): String {
        match (kind) {
            case Chunk => "chunk"
            case Asset => "asset"
            case EntryPoint => "entry-point"
            case Sourcemap => "sourcemap"
            case Bytecode => "bytecode"
            case ModuleInfo => "module_info"
            case MetafileJson => "metafile-json"
            case MetafileMarkdown => "metafile-markdown"
        }
    }
}

/// Side — 严格翻译自: lib.rs:279 options::Side
/// bun.bake.Side (bake.zig:874)
/// 表示输出属于哪个图 (客户端/服务端)
public enum Side {
    | Client   // 客户端图
    | Server   // 服务端图
    | SSR      // 服务端渲染图
}

/// Framework — 严格翻译自: lib.rs:288 options::Framework
/// bun.bake.Framework 的最小定义
/// 框架路由配置 (用于 bake 模式)
public class Framework {
    public var name: String
    public var version: String
    public var router: FrameworkRouter

    public init() {
        this.name = ""
        this.version = ""
        this.router = FrameworkRouter()
    }

    public init(name: String, version: String, router: FrameworkRouter) {
        this.name = name
        this.version = version
        this.router = router
    }
}

/// 框架路由配置
public class FrameworkRouter {
    public var ext: String
    public var dir: String

    public init() {
        this.ext = ""
        this.dir = ""
    }
}

// ============================================================================
// DevServerHandle link-interface
// 严格翻译自: lib.rs:326-342 DevServerHandle
// DevServer 的擦除句柄，通过 vtable 派发方法调用
//
// 在 Bun Rust 中使用 bun_dispatch::link_interface! 宏生成 trait + vtable
// 在仓颉中，使用接口 (interface) + 类实现
// ============================================================================

/// DevServer 接口句柄
/// 严格翻译自: lib.rs:326 DevServerHandle[Bake]
/// 擦除的 DevServer 句柄，支持跨模块派发
public interface DevServerHandle {
    /// 获取 barrel 需要导出的映射
    func barrelNeededExports(): StringHashMap<StringHashMap<Unit>>

    /// 记录解析失败的日志
    func logForResolutionFailures(absPath: Array<Byte>, graph: BakeGraph): Log

    /// 完成打包
    func finalizeBundle(bv2: BundleV2, result: DevServerOutput): Result<Unit>

    /// 处理解析任务失败
    func handleParseTaskFailure(err: Error, graph: BakeGraph, absPath: Array<Byte>, log: Log, bv2: BundleV2): Result<Unit>

    /// 放入或覆盖资源
    func putOrOverwriteAsset(path: Unit, contents: Array<Byte>, contentHash: UInt64): Result<Unit>

    /// 跟踪解析失败
    func trackResolutionFailure(importSource: Array<Byte>, specifier: Array<Byte>, renderer: BakeGraph, loader: Loader): Result<Unit>

    /// 检查文件是否已缓存
    func isFileCached(absPath: Array<Byte>, side: Side): CacheEntry

    /// 获取资源哈希
    func assetHash(absPath: Array<Byte>): UInt64

    /// 获取当前 bundle 启动数据
    func currentBundleStartData(): Unit

    /// 注册 barrel 延迟
    func registerBarrelWithDeferrals(path: Array<Byte>): Result<Unit>

    /// 注册 barrel 导出
    func registerBarrelExport(barrelPath: Array<Byte>, alias: Array<Byte>): Unit
}

/// VmLoaderCtx 接口
/// 严格翻译自: lib.rs:346 VmLoaderCtx[Runtime]
/// VirtualMachine 加载器上下文，用于 normalize_specifier / get_loader_and_virtual_source
public interface VmLoaderCtx {
    /// 获取源主机
    func originHost(): Array<Byte>

    /// 获取源路径
    func originPath(): Array<Byte>

    /// 获取加载器映射
    func loaders(): StringHashMap<Loader>

    /// 获取 eval 源
    func evalSource(): Source

    /// 获取 main 入口
    func main(): Array<Byte>

    /// 读取目录信息中的 package.json
    func readDirInfoPackageJson(dir: Array<Byte>): PackageJSON

    /// 检查是否是 blob URL
    func isBlobUrl(specifier: Array<Byte>): Bool

    /// 解析 blob
    func resolveBlob(specifier: Array<Byte>): OpaqueBlob

    /// 获取 blob 加载器
    func blobLoader(blob: OpaqueBlob): Loader

    /// 获取 blob 文件名
    func blobFileName(blob: OpaqueBlob): String

    /// blob 是否需要读文件
    func blobNeedsReadFile(blob: OpaqueBlob): Bool

    /// 获取 blob 共享视图
    func blobSharedView(blob: OpaqueBlob): Array<Byte>

    /// 释放 blob
    func blobDeinit(blob: OpaqueBlob): Unit
}

// ============================================================================
// 辅助类型
// ============================================================================

/// Bake 图类型 (简化)
/// 严格翻译自: bake_types.zig Graph
public enum BakeGraph {
    | Client
    | Server
    | SSR
}

/// BundleV2 引用 (前向声明)
/// 实际实现在 bundle_v2.cj
public class BundleV2 {
    public var options: BundleOptions

    public init() {
        this.options = BundleOptions()
    }
}

/// DevServer 输出 (简化)
/// 实际实现在 bundle_v2.cj
public class DevServerOutput {
    public var chunks: ArrayList<Chunk>

    public init() {
        this.chunks = ArrayList<Chunk>()
    }
}

/// CacheEntry (简化)
public class CacheEntry {
    public var hash: UInt64
    public var isValid: Bool

    public init() {
        this.hash = 0
        this.isValid = false
    }
}

/// OpaqueBlob (简化)
public class OpaqueBlob {
    public var id: Int64

    public init() {
        this.id = 0
    }
}

/// StringHashMap 别名
public type StringHashMap<V> = HashMap<String, V>

/// Chunk 引用
public class Chunk {
    public var id: Int64
    public var filename: String

    public init() {
        this.id = 0
        this.filename = ""
    }
}

/// Source 引用
public class Source {
    public var path: String
    public var index: Int32

    public init() {
        this.path = ""
        this.index = 0
    }
}

/// Log 引用
public class Log {
    public var errors: Int32
    public var warnings: Int32

    public init() {
        this.errors = 0
        this.warnings = 0
    }
}

/// Loader 引用 (来自 bao_ast)
public type Loader = String

/// Error 引用 (来自 bao_core)
public class Error {
    public var message: String

    public init(message: String) {
        this.message = message
    }
}

/// Result 别名
public type Result<T> = Result<T, Error>

/// PackageJSON 引用
public class PackageJSON {
    public var path: String

    public init() {
        this.path = ""
    }
}

// ============================================================================
// OutputFile.Options Defaults
// 严格翻译自: lib.rs:368-398 Default for output_file::OptionsData / Options
// ============================================================================

/// OutputFile 初始化选项数据
/// 严格翻译自: lib.rs:369 OptionsData
public class OutputFileOptionsData {
    /// Buffer 数据
    public var data: Array<Byte>

    public init() {
        this.data = []
    }
}

/// OutputFile 初始化选项
/// 严格翻译自: lib.rs:376 Options
public class OutputFileInitOptions {
    public var loader: Loader
    public var inputLoader: Loader
    public var hash: UInt64
    public var sourceMapIndex: Int32
    public var bytecodeIndex: Int32
    public var moduleInfoIndex: Int32
    public var outputPath: String
    public var sourceIndex: IndexOptional
    public var size: Int32
    public var inputPath: String
    public var displaySize: Int32
    public var outputKind: OutputKind
    public var isExecutable: Bool
    public var data: OutputFileOptionsData
    public var side: Side
    public var entryPointIndex: Int32
    public var referencedCssChunks: ArrayList<UInt32>
    public var bakeExtra: BakeExtra

    public init() {
        this.loader = ""
        this.inputLoader = ""
        this.hash = 0
        this.sourceMapIndex = 0
        this.bytecodeIndex = 0
        this.moduleInfoIndex = 0
        this.outputPath = ""
        this.sourceIndex = IndexOptional.None
        this.size = 0
        this.inputPath = ""
        this.displaySize = 0
        this.outputKind = OutputKind.Chunk
        this.isExecutable = false
        this.data = OutputFileOptionsData()
        this.side = Side.Client
        this.entryPointIndex = 0
        this.referencedCssChunks = ArrayList<UInt32>()
        this.bakeExtra = BakeExtra()
    }
}

/// Index 可选值
/// 严格翻译自: output_file.zig IndexOptional
public enum IndexOptional {
    | None
    | Some(UInt32)
}

/// Bake 额外信息
/// 严格翻译自: output_file.zig BakeExtra
public class BakeExtra {
    public var isDevServer: Bool

    public init() {
        this.isDevServer = false
    }
}
