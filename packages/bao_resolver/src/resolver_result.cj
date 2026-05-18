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

/// 副作用类型 - 对应 Bun SideEffects
public enum SideEffectsKind {
    | HasSideEffects               // 默认: 保守认为有副作用
    | NoSideEffectsPackageJson     // package.json 中声明无副作用
    | NoSideEffectsEmptyAst        // AST 为空 (如 .d.ts)
    | NoSideEffectsPureData        // 纯数据加载器 (如 "text")

    public operator func ==(right: SideEffectsKind): Bool {
        ordinal() == right.ordinal()
    }

    public operator func !=(right: SideEffectsKind): Bool {
        !(this == right)
    }

    public func ordinal(): Int64 {
        match (this) {
            case HasSideEffects => 0
            case NoSideEffectsPackageJson => 1
            case NoSideEffectsEmptyAst => 2
            case NoSideEffectsPureData => 3
        }
    }
}

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
// ResolveUnionResult - 解析联合结果
// 严格翻译自: result.rs ResultUnion 的包装
// ============================================================================

/// 解析联合结果 - 对应 Bun ResultUnion 的包装
public class ResolveUnionResult {
    public var status: ResultStatus
    public var result: ?Result
    public var matchResult: ?MatchResult
    public var pending: ?PendingResolution
    public var error: ?String

    public init() {
        status = ResultStatus.NotFound
        result = None
        matchResult = None
        pending = None
        error = None
    }

    public static func success(result: Result): ResolveUnionResult {
        let r = ResolveUnionResult()
        r.status = ResultStatus.Success
        r.result = Some(result)
        r
    }

    public static func notFound(): ResolveUnionResult {
        let r = ResolveUnionResult()
        r.status = ResultStatus.NotFound
        r
    }

    public static func failure(error: String): ResolveUnionResult {
        let r = ResolveUnionResult()
        r.status = ResultStatus.Failure
        r.error = Some(error)
        r
    }

    public static func createPending(p: PendingResolution): ResolveUnionResult {
        let r = ResolveUnionResult()
        r.status = ResultStatus.Pending
        r.pending = Some(p)
        r
    }
}

// ============================================================================
// DebugMeta - 调试元数据
// 严格翻译自: result.rs:310-371
//   pub struct DebugMeta { notes, suggestion_text, suggestion_message, ... }
// ============================================================================

/// 建议范围 - 对应 Bun SuggestionRange
public enum SuggestionRange {
    | Full
    | End
}

/// 调试元数据 - 对应 Bun DebugMeta
public class DebugMeta {
    public var notes: ArrayList<String>
    public var suggestionText: String
    public var suggestionMessage: String
    public var suggestionRange: SuggestionRange

    public init() {
        notes = ArrayList<String>()
        suggestionText = ""
        suggestionMessage = ""
        suggestionRange = SuggestionRange.Full
    }
}

// ============================================================================
// DirEntryResolveQueueItem - 目录解析队列项
// 严格翻译自: result.rs:373-416
// ============================================================================

/// 目录解析队列项 - 对应 Bun DirEntryResolveQueueItem
public class DirEntryResolveQueueItem {
    public var hash: UInt64
    public var index: Int64
    public var unsafePath: String
    public var safePath: String
    public var fd: Int64

    public init() {
        hash = 0
        index = -1
        unsafePath = ""
        safePath = ""
        fd = -1
    }
}

// ============================================================================
// DebugLogs - 调试日志
// 严格翻译自: result.rs:418-476
//   pub struct DebugLogs { what, indent, notes }
// ============================================================================

/// 调试日志 - 对应 Bun DebugLogs
public class DebugLogs {
    public var what: String
    public var indent: String
    public var notes: ArrayList<String>

    public init() {
        what = ""
        indent = ""
        notes = ArrayList<String>()
    }

    /// 增加缩进 - 对应 Bun DebugLogs.increase_indent()
    public func increaseIndent(): Unit {
        indent = "${indent} "
    }

    /// 减少缩进 - 对应 Bun DebugLogs.decrease_indent()
    public func decreaseIndent(): Unit {
        if (indent.size > 0) {
            indent = indent[0..indent.size - 1]
        }
    }

    /// 添加备注 - 对应 Bun DebugLogs.add_note()
    public func addNote(text: String): Unit {
        if (indent.size > 0) {
            notes.append("${indent}${text}")
        } else {
            notes.append(text)
        }
    }
}

/// 刷新模式 - 对应 Bun FlushMode
public enum FlushMode {
    | Fail
    | Success
}

// ============================================================================
// MatchResult - 匹配结果
// 严格翻译自: result.rs:478-504
//   pub struct MatchResult { path_pair, dirname_fd, file_fd, ... }
// ============================================================================

/// 匹配结果 - 对应 Bun MatchResult
public class MatchResult {
    public var pathPair: ResultPathPair
    public var dirnameFd: Int64
    public var fileFd: Int64
    public var isNodeModule: Bool
    public var packageJson: ?PackageJson
    public var diffCase: ?String
    public var dirInfo: ?DirInfo
    public var moduleType: ModuleType
    public var isExternal: Bool

    public init() {
        pathPair = ResultPathPair()
        dirnameFd = -1
        fileFd = -1
        isNodeModule = false
        packageJson = None
        diffCase = None
        dirInfo = None
        moduleType = ModuleType.Unknown
        isExternal = false
    }

    public init(pathPair: ResultPathPair) {
        this.pathPair = pathPair
        dirnameFd = -1
        fileFd = -1
        isNodeModule = false
        packageJson = None
        diffCase = None
        dirInfo = None
        moduleType = ModuleType.Unknown
        isExternal = false
    }
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

// ============================================================================
// PendingResolution - 待解决的模块
// 严格翻译自: result.rs:513-564
//   pub struct PendingResolution { esm, dependency, resolution_id, ... }
// ============================================================================

/// 待解决状态标签 - 对应 Bun PendingResolutionTag
public enum PendingResolutionTag {
    | Download    // 需要下载
    | Resolve     // 需要解析
    | Done        // 完成

    public operator func ==(right: PendingResolutionTag): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case Download => 0
            case Resolve => 1
            case Done => 2
        }
    }
}

/// 待解决的模块 - 对应 Bun PendingResolution
public class PendingResolution {
    public var packageName: String
    public var version: String
    public var resolutionId: Int64
    public var rootDependencyId: Int64
    public var importRecordId: UInt32
    public var stringBuffer: String
    public var tag: PendingResolutionTag

    public init() {
        packageName = ""
        version = ""
        resolutionId = -1
        rootDependencyId = -1
        importRecordId = UInt32.MAX
        stringBuffer = ""
        tag = PendingResolutionTag.Download
    }

    public static let INVALID_PACKAGE_ID: Int64 = -1
}

/// 待解决列表
public typealias PendingResolutionList = ArrayList<PendingResolution>

// ============================================================================
// LoadResult - 加载结果
// 严格翻译自: result.rs:573-580
//   pub struct LoadResult { path, diff_case, dirname_fd, file_fd, dir_info }
// ============================================================================

/// 加载结果 - 对应 Bun LoadResult
public class LoadResult {
    public var path: String
    public var diffCase: ?String
    public var dirnameFd: Int64
    public var fileFd: Int64
    public var dirInfo: ?DirInfo

    public init() {
        path = ""
        diffCase = None
        dirnameFd = -1
        fileFd = -1
        dirInfo = None
    }
}

// ============================================================================
// ModuleType - 模块类型
// ============================================================================

/// 模块类型 - 对应 Bun ModuleType
public enum ModuleType {
    | Unknown
    | Esm
    | Cjs

    public operator func ==(right: ModuleType): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case Unknown => 0
            case Esm => 1
            case Cjs => 2
        }
    }
}

// ============================================================================
// JSXConfig - JSX 配置
// ============================================================================

/// JSX 配置 - 对应 Bun JSX.Pragma
public class JSXConfig {
    public var factory: String
    public var fragment: String
    public var runtime: JSXRuntime
    public var development: Bool
    public var importSource: String
    public var packageName: String

    public init() {
        factory = "React.createElement"
        fragment = "React.Fragment"
        runtime = JSXRuntime.Automatic
        development = false
        importSource = ""
        packageName = ""
    }
}

/// JSX 运行时模式
public enum JSXRuntime {
    | Classic
    | Automatic
    | Preserve
    | Solid
}

// ============================================================================
// DirInfo - 目录信息
// ============================================================================

/// 目录信息 - 对应 Bun DirInfo
public class DirInfo {
    public var absPath: String
    public var enclosingTsconfigJson: ?TsConfig
    public var enclosingPackageJson: ?PackageJson
    public var hasNodeModules: Bool

    public init(absPath: String) {
        this.absPath = absPath
        enclosingTsconfigJson = None
        enclosingPackageJson = None
        hasNodeModules = false
    }
}

/// TypeScript 配置 - 对应 Bun TSConfigJSON
public class TsConfig {
    public var absPath: String
    public var baseUrl: String
    public var paths: HashMap<String, Array<String>>
    public var jsx: JSXConfig
    public var emitDecoratorMetadata: Bool
    public var experimentalDecorators: Bool

    public init(absPath: String) {
        this.absPath = absPath
        baseUrl = ""
        paths = HashMap<String, Array<String>>()
        jsx = JSXConfig()
        emitDecoratorMetadata = false
        experimentalDecorators = false
    }
}

/// package.json 引用类型
public class PackageJson {
    public var name: String
    public var version: String
    public var moduleType: ModuleType
    public var browserMap: HashMap<String, String>
    public var dependencies: HashMap<String, String>
    public var sideEffects: SideEffectsKind
    public var types: String

    public init() {
        name = ""
        version = ""
        moduleType = ModuleType.Unknown
        browserMap = HashMap<String, String>()
        dependencies = HashMap<String, String>()
        sideEffects = SideEffectsKind.HasSideEffects
        types = ""
    }
}
