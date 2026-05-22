// 解析结果类型
// 严格翻译自: src/resolver/result.rs (579行)
//   Resolver output and bookkeeping types:
//     - PathPair: 路径对 (primary/secondary)
//     - Result: 解析结果 (path_pair, jsx, package_json, flags)
//     - ResultFlags: 结果标志位
//     - ResultUnion: 结果联合体 (Success/Failure/Pending/NotFound)
//     - MatchResult: 匹配结果
//     - MatchResultUnion: 匹配结果联合体
//     - PendingResolution: 待解决的模块
//     - DebugLogs: 调试日志
//     - DebugMeta: 调试元数据
//     - DirEntryResolveQueueItem: 目录解析队列项
package bao_resolver

import bao_core.*
import bao_collections.*

// ============================================================================
// SideEffectsData - 副作用数据
// 严格翻译自: result.rs:30-36
//   pub struct SideEffectsData { source, range, is_side_effects_array_in_json }
// ============================================================================

/// 副作用数据 - 对应 Bun SideEffectsData
public class SideEffectsDataResult {
    public var source: String
    public var rangeStart: Int64
    public var rangeEnd: Int64
    public var isSideEffectsArrayInJson: Bool

    public init(source: String, rangeStart: Int64, rangeEnd: Int64) {
        this.source = source
        this.rangeStart = rangeStart
        this.rangeEnd = rangeEnd
        isSideEffectsArrayInJson = false
    }
}

// ============================================================================
// PathPair - 路径对
// 严格翻译自: result.rs:38-91
//   pub struct PathPair { primary: Path, secondary: Option<Path> }
// ============================================================================

/// 路径对 - 对应 Bun PathPair
/// 用于支持 module/main 双路径解析:
///   primary 指向 ESM 文件 (module 字段)
///   secondary 指向 CJS 文件 (main 字段)
public class ResultPathPair {
    public var primary: ResolverPath
    public var secondary: ?ResolverPath

    public init() {
        primary = ResolverPath("")
        secondary = None
    }

    public init(primary: ResolverPath) {
        this.primary = primary
        this.secondary = None
    }

    public init(primary: ResolverPath, secondary: ?ResolverPath) {
        this.primary = primary
        this.secondary = secondary
    }

    /// 遍历所有可用路径 - 对应 Bun PathPair.iter()
    public func iterate(): ArrayList<ResolverPath> {
        let result = ArrayList<ResolverPath>()
        if (!primary.isDisabled) {
            result.append(primary)
        }
        match (secondary) {
            case Some(sec) =>
                if (!sec.isDisabled) {
                    result.append(sec)
                }
            case None => ()
        }
        result
    }
}

// ============================================================================
// SideEffects - 副作用枚举
// 严格翻译自: result.rs:94 引用的 bun_ast::SideEffects
// ============================================================================

// ============================================================================
// ResultFlags - 解析结果标志位
// 严格翻译自: result.rs:144-208
//   bitflags! { pub struct ResultFlags: u8 { ... } }
// ============================================================================

/// 解析结果标志位 - 对应 Bun ResultFlags
/// 将多个布尔标志打包到一个字节中以减少内存占用
public class ResultFlags {
    public var isExternal: Bool
    public var isExternalAndRewriteImportPath: Bool
    public var isStandaloneModule: Bool
    public var isFromNodeModules: Bool
    public var preserveUnusedImportsTs: Bool
    public var emitDecoratorMetadata: Bool
    public var experimentalDecorators: Bool

    public init() {
        isExternal = false
        isExternalAndRewriteImportPath = false
        isStandaloneModule = false
        isFromNodeModules = false
        preserveUnusedImportsTs = false
        emitDecoratorMetadata = false
        experimentalDecorators = false
    }
}

// ============================================================================
// Result - 解析结果
// 严格翻译自: result.rs:99-308
//   pub struct Result { path_pair, jsx, package_json, ... }
// ============================================================================

/// 模块解析结果 - 对应 Bun Result
public class Result {
    public var pathPair: ResultPathPair
    public var jsx: JSXConfig
    public var packageJson: ?PackageJson
    public var diffCase: ?String
    public var primarySideEffectsData: SideEffectsKind
    public var moduleType: ModuleType
    public var debugMeta: ?DebugMeta
    public var dirnameFd: Int64
    public var fileFd: Int64
    public var importKind: ImportKind
    public var flags: ResultFlags

    public init() {
        pathPair = ResultPathPair()
        jsx = JSXConfig()
        packageJson = None
        diffCase = None
        primarySideEffectsData = SideEffectsKind.HasSideEffects
        moduleType = ModuleType.Unknown
        debugMeta = None
        dirnameFd = -1
        fileFd = -1
        importKind = ImportKind.Stmt
        flags = ResultFlags()
    }

    public init(pathPair: ResultPathPair) {
        this.pathPair = pathPair
        jsx = JSXConfig()
        packageJson = None
        diffCase = None
        primarySideEffectsData = SideEffectsKind.HasSideEffects
        moduleType = ModuleType.Unknown
        debugMeta = None
        dirnameFd = -1
        fileFd = -1
        importKind = ImportKind.Stmt
        flags = ResultFlags()
    }

    /// 获取路径 (非禁用的) - 对应 Bun Result.path()
    public func path(): ?ResolverPath {
        if (!pathPair.primary.isDisabled) {
            return Some(pathPair.primary)
        }
        match (pathPair.secondary) {
            case Some(sec) =>
                if (!sec.isDisabled) {
                    return Some(sec)
                }
            case None => ()
        }
        None
    }

    /// 是否可能为 node_modules 模块 - 对应 Bun Result.is_likely_node_module()
    public func isLikelyNodeModule(): Bool {
        if (flags.isFromNodeModules) {
            return true
        }
        match (path()) {
            case Some(p) => p.text.contains("/node_modules/")
            case None => false
        }
    }

    /// 是否应假设为 CommonJS - 对应 Bun Result.should_assume_common_js()
    public func shouldAssumeCommonJS(kind: ImportKind): Bool {
        match (moduleType) {
            case ModuleType.Esm => false
            case ModuleType.Cjs => true
            case ModuleType.Unknown =>
                if (match (kind) {
                    case ImportKind.Require | ImportKind.RequireResolve => true
                    case _ => false
                }) {
                    return true
                }
                isLikelyNodeModule()
        }
    }
}

// ============================================================================
// ResultUnion - 解析结果联合体
// 严格翻译自: result.rs:210-215
//   pub enum ResultUnion { Success, Failure, Pending, NotFound }
// ============================================================================

/// 解析结果联合体 - 对应 Bun ResultUnion
public enum ResultStatus {
    | Success                 // 成功解析
    | Failure                 // 解析失败
    | Pending                 // 等待安装
    | NotFound                // 未找到模块

    public operator func ==(right: ResultStatus): Bool {
        ordinal() == right.ordinal()
    }

    public operator func !=(right: ResultStatus): Bool {
        !(this == right)
    }

    public func ordinal(): Int64 {
        match (this) {
            case Success => 0
            case Failure => 1
            case Pending => 2
            case NotFound => 3
        }
    }
}

// ============================================================================
// DebugMeta - 调试元数据
// 严格翻译自: result.rs:310-371
//   pub struct DebugMeta { notes, suggestion_text, suggestion_message, ... }
// ============================================================================

// SuggestionRange 和 DebugMeta 定义在 resolver_core.cj 中

// ============================================================================
// DirEntryResolveQueueItem - 目录解析队列项
// 严格翻译自: result.rs:373-416
// ============================================================================

// DirEntryResolveQueueItem 定义在 resolver_core.cj 中

/// 刷新模式 - 对应 Bun FlushMode
public enum FlushMode {
    | Fail
    | Success
}

// ============================================================================
// MatchResultUnion - 匹配结果联合体
// 严格翻译自: result.rs:506-511
// ============================================================================

/// 匹配结果联合体 - 对应 Bun MatchResultUnion
public class MatchResultUnion {
    public var status: ResultStatus
    public var result: ?MatchResult
    public var pending: ?PendingResolution
    public var error: ?String

    public init() {
        status = ResultStatus.NotFound
        result = None
        pending = None
        error = None
    }

    public static func notFound(): MatchResultUnion {
        MatchResultUnion()
    }

    public static func success(result: MatchResult): MatchResultUnion {
        let r = MatchResultUnion()
        r.status = ResultStatus.Success
        r.result = Some(result)
        r
    }
}

/// 待解决列表
public class PendingResolutionList {
    public var items: ArrayList<PendingResolution>

    public init() {
        items = ArrayList<PendingResolution>()
    }
}

// ============================================================================
// LoadResult - 加载结果
// 严格翻译自: result.rs:573-580
//   pub struct LoadResult { path, diff_case, dirname_fd, file_fd, dir_info }
// ============================================================================

// LoadResult 定义在 resolver_core.cj 中

