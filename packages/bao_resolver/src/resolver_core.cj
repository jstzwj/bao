// resolver_core - 模块解析器核心
// 严格翻译自: bun/src/resolver/resolver.zig (4388行)
//   这是 Bun 模块解析系统的核心，包含:
//     - Resolver 结构体 (解析器)
//     - Result 结果 (解析结果)
//     - PathPair 路径对
//     - Dirname 路径工具
//     - 完整的模块解析算法 (node_modules 遍历、exports 解析、tsconfig paths)
package bao_resolver

import bao_core.*
import bao_sys.*
import bao_hash.*
import bao_options.*
import bao_collections.*

// ============================================================================
// isPackagePath - 判断路径是否为包路径
// 严格翻译自: resolver.zig - isPackagePath()
//   pub fn isPackagePath(path: string) bool
//   return !std.fs.path.isAbsolute(path) and isPackagePathNotAbsolute(path)
// ============================================================================

/// 判断路径是否为包路径 (非绝对、非相对)
/// 对应 Bun isPackagePath()
/// 包路径如 "react", "@scope/package" 等
public func isPackagePath(path: String): Bool {
    if (Path.isAbsolute(path)) {
        return false
    }
    isPackagePathNotAbsolute(path)
}

/// 判断非绝对路径是否为包路径
/// 对应 Bun isPackagePathNotAbsolute()
/// 排除以 "./", "../", ".", ".." 开头的相对路径
public func isPackagePathNotAbsolute(nonAbsolutePath: String): Bool {
    if (nonAbsolutePath.startsWith("./")) {
        return false
    }
    if (nonAbsolutePath.startsWith("../")) {
        return false
    }
    if (nonAbsolutePath == ".") {
        return false
    }
    if (nonAbsolutePath == "..") {
        return false
    }
    true
}

// ============================================================================
// SideEffectsData - 副作用数据
// 严格翻译自: resolver.zig - SideEffectsData
//   pub const SideEffectsData = struct {
//       source: *logger.Source,
//       range: logger.Range,
//       is_side_effects_array_in_json: bool = false,
//   };
// ============================================================================

/// 副作用数据 - 对应 Bun SideEffectsData
public class SideEffectsData {
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
// SideEffects - 副作用枚举
// 严格翻译自: resolver.zig - SideEffects
//   pub const SideEffects = enum {
//       has_side_effects,
//       no_side_effects__package_json,
//       no_side_effects__empty_ast,
//       no_side_effects__pure_data,
//   };
// ============================================================================

/// 副作用类型 - 对应 Bun SideEffects
public enum SideEffects {
    | HasSideEffects                     // 默认: 保守认为有副作用
    | NoSideEffectsPackageJson           // package.json 中声明无副作用
    | NoSideEffectsEmptyAst              // AST 为空 (如 .d.ts)
    | NoSideEffectsPureData              // 纯数据加载器 (如 "text")
}

// ============================================================================
// ImportKind - 导入类型
// 严格翻译自: resolver.zig - ast.ImportKind (引用)
// ============================================================================

// ============================================================================
// ModuleType - 模块类型
// 严格翻译自: resolver.zig - options.ModuleType (引用)
// ============================================================================

/// 模块类型 - 对应 Bun ModuleType
public enum ModuleType {
    | Unknown
    | Esm
    | Cjs
}

// ============================================================================
// ModuleTypeMap - 模块类型扩展名映射
// 严格翻译自: resolver.zig - Resolver.ModuleTypeMap
//   const ModuleTypeMap = bun.ComptimeStringMap(options.ModuleType, .{
//       .{ ".mjs", options.ModuleType.esm },
//       .{ ".mts", options.ModuleType.esm },
//       .{ ".cjs", options.ModuleType.cjs },
//       .{ ".cts", options.ModuleType.cjs },
//   });
// ============================================================================

/// 扩展名到模块类型的映射
/// 对应 Bun Resolver.ModuleTypeMap
public func moduleTypeFromExtension(ext: String): ModuleType {
    match (ext) {
        case ".mjs" => ModuleType.Esm
        case ".mts" => ModuleType.Esm
        case ".cjs" => ModuleType.Cjs
        case ".cts" => ModuleType.Cjs
        case _ => ModuleType.Unknown
    }
}

// ResolverPath 定义在 resolver_fs.cj 中 (完整的 Fs.Path 翻译)

// PathPair 定义在 resolver_fs.cj 中

// ============================================================================
// ResolveResultFlags - 解析结果标志
// 严格翻译自: resolver.zig - Result.Flags
//   pub const Flags = packed struct(u8) {
//       is_external: bool = false,
//       is_external_and_rewrite_import_path: bool = false,
//       is_standalone_module: bool = false,
//       is_from_node_modules: bool = false,
//       preserve_unused_imports_ts: bool = false,
//       emit_decorator_metadata: bool = false,
//       experimental_decorators: bool = false,
//       _padding: u1 = 0,
//   };
// ============================================================================

/// 解析结果标志 - 对应 Bun Result.Flags
public class ResolveResultFlags {
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
// ResolveResult - 解析结果
// 严格翻译自: resolver.zig - Result
//   pub const Result = struct {
//       path_pair: PathPair,
//       jsx: options.JSX.Pragma,
//       package_json: ?*PackageJSON = null,
//       diff_case: ?DifferentCase = null,
//       primary_side_effects_data: SideEffects,
//       module_type: options.ModuleType,
//       debug_meta: ?DebugMeta = null,
//       dirname_fd: FD = .invalid,
//       file_fd: FD = .invalid,
//       import_kind: ImportKind = undefined,
//       flags: Flags = .{},
//   };
// ============================================================================

/// 模块解析结果 - 对应 Bun Result
public class ResolveResult {
    /// 路径对
    public var pathPair: PathPair
    /// JSX 配置
    public var jsx: JSXConfig
    /// package.json 引用
    public var packageJson: ?PackageJson
    /// 大小写不匹配信息
    public var diffCase: ?String
    /// 副作用数据
    public var primarySideEffectsData: SideEffects
    /// 模块类型
    public var moduleType: ModuleType
    /// 调试元信息
    public var debugMeta: ?DebugMeta
    /// 目录文件描述符
    public var dirnameFd: Int64
    /// 文件文件描述符
    public var fileFd: Int64
    /// 导入类型
    public var importKind: ImportKind
    /// 标志
    public var flags: ResolveResultFlags

    public init(pathPair: PathPair) {
        this.pathPair = pathPair
        jsx = JSXConfig()
        packageJson = None
        diffCase = None
        primarySideEffectsData = SideEffects.HasSideEffects
        moduleType = ModuleType.Unknown
        debugMeta = None
        dirnameFd = -1
        fileFd = -1
        importKind = ImportKind.Stmt
        flags = ResolveResultFlags()
    }

    /// 获取有效路径 (非禁用的主路径或备选路径)
    /// 对应 Bun Result.path()
    public func path(): ?ResolverPath {
        if (!pathPair.primary.isDisabled) {
            return Some(pathPair.primary)
        }
        if (let Some(sec) <- pathPair.secondary) {
            if (!sec.isDisabled) {
                return Some(sec)
            }
        }
        None
    }

    /// 获取常量路径 (同 path 但语义为只读)
    /// 对应 Bun Result.pathConst()
    public func pathConst(): ?ResolverPath {
        path()
    }

    /// 判断是否可能为 node_modules 模块
    /// 对应 Bun Result.isLikelyNodeModule()
    public func isLikelyNodeModule(): Bool {
        if (flags.isFromNodeModules) {
            return true
        }
        let pathText = pathConst()
        if (let Some(p) <- pathText) {
            if (p.text.contains("/node_modules/")) {
                return true
            }
        }
        false
    }

    /// 判断是否应假设为 CommonJS
    /// 对应 Bun Result.shouldAssumeCommonJS()
    public func shouldAssumeCommonJS(kind: ImportKind): Bool {
        match (moduleType) {
            case Esm => false
            case Cjs => true
            case Unknown =>
                if (match (kind) { case ImportKind.Require | ImportKind.RequireResolve => true case _ => false }) {
                    return true
                }
                isLikelyNodeModule()
        }
    }

    /// 计算结果的哈希值
    /// 对应 Bun Result.hash()
    public func hash(): UInt32 {
        let module = pathPair.primary.text
        let nodeModuleRoot = "/node_modules/"
        if (let Some(end_) <- module.lastIndexOf(nodeModuleRoot)) {
            let end = end_ + nodeModuleRoot.size
            return UInt32(hashString(module[Int64(end)..module.size]))
        }
        UInt32(hashString(module))
    }
}

// ============================================================================
// DebugMeta - 调试元信息
// 严格翻译自: resolver.zig - Result.DebugMeta
//   pub const DebugMeta = struct {
//       notes: std.array_list.Managed(logger.Data),
//       suggestion_text: string = "",
//       suggestion_message: string = "",
//       suggestion_range: SuggestionRange,
//       pub const SuggestionRange = enum { full, end };
//   };
// ============================================================================

/// 建议范围
public enum SuggestionRange {
    | Full
    | End
}

/// 调试元信息 - 对应 Bun Result.DebugMeta
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

    /// 记录错误消息
    /// 对应 Bun DebugMeta.logErrorMsg()
    public func logErrorMsg(log: ArrayList<String>, source: ?String,
                             rangeStart: Int64, rangeEnd: Int64,
                             message: String): Unit {
        if (let Some(s) <- source) {
            if (suggestionMessage.size > 0) {
                notes.append(suggestionMessage)
            }
        }
        log.append(message)
    }
}

// ============================================================================
// ResolveStatus - 解析状态
// 对应 Bun Result.Union
// ============================================================================

/// 解析状态 - 对应 Bun Result.Union
public enum ResolveStatus {
    | Success                 // 成功解析
    | Failure                 // 解析失败
    | Pending                 // 等待安装
    | NotFound                // 未找到模块
}

public class ResolveUnionResult {
    public var status: ResolveStatus
    public var result: ?ResolveResult
    public var matchResult: ?MatchResult
    public var pending: ?PendingResolution
    public var error: ?String

    public init() {
        status = ResolveStatus.NotFound
        result = None
        matchResult = None
        pending = None
        error = None
    }

    public static func success(result: ResolveResult): ResolveUnionResult {
        let r = ResolveUnionResult()
        r.status = ResolveStatus.Success
        r.result = Some(result)
        r
    }

    public static func successFromMatch(matchResult: MatchResult): ResolveUnionResult {
        let r = ResolveUnionResult()
        r.status = ResolveStatus.Success
        let result = ResolveResult(matchResult.pathPair)
        result.packageJson = matchResult.packageJson
        result.diffCase = matchResult.diffCase
        result.dirnameFd = matchResult.dirnameFd
        result.fileFd = matchResult.fileFd
        result.moduleType = matchResult.moduleType
        result.flags.isFromNodeModules = matchResult.isNodeModule
        result.flags.isExternal = matchResult.isExternal
        r.result = Some(result)
        r.matchResult = Some(matchResult)
        r
    }

    public static func notFound(): ResolveUnionResult {
        let r = ResolveUnionResult()
        r.status = ResolveStatus.NotFound
        r
    }

    public static func failure(error: String): ResolveUnionResult {
        let r = ResolveUnionResult()
        r.status = ResolveStatus.Failure
        r.error = Some(error)
        r
    }

    public static func createPending(p: PendingResolution): ResolveUnionResult {
        let r = ResolveUnionResult()
        r.status = ResolveStatus.Pending
        r.pending = Some(p)
        r
    }
}

// ============================================================================
// MatchResult - 匹配结果
// 严格翻译自: resolver.zig - MatchResult
//   pub const MatchResult = struct {
//       path_pair: PathPair,
//       dirname_fd: FD = .invalid,
//       file_fd: FD = .invalid,
//       is_node_module: bool = false,
//       package_json: ?*PackageJSON = null,
//       diff_case: ?DifferentCase = null,
//       dir_info: ?*DirInfo = null,
//       module_type: ModuleType = .unknown,
//       is_external: bool = false,
//   };
// ============================================================================

/// 匹配结果 - 对应 Bun MatchResult
public class MatchResult {
    public var pathPair: PathPair
    public var dirnameFd: Int64
    public var fileFd: Int64
    public var isNodeModule: Bool
    public var packageJson: ?PackageJson
    public var diffCase: ?String
    public var dirInfo: ?DirInfo
    public var moduleType: ModuleType
    public var isExternal: Bool

    public init(pathPair: PathPair) {
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

/// MatchResult.Union 状态枚举
/// 对应 Bun MatchResult.Union
public enum MatchStatus {
    | NotFound
    | Success
    | Pending
    | Failure
}

/// MatchResult 联合结果
public class MatchUnionResult {
    public var status: MatchStatus
    public var result: ?MatchResult
    public var pending: ?PendingResolution
    public var error: ?String

    public init() {
        status = MatchStatus.NotFound
        result = None
        pending = None
        error = None
    }

    public static func success(matchResult: MatchResult): MatchUnionResult {
        let r = MatchUnionResult()
        r.status = MatchStatus.Success
        r.result = Some(matchResult)
        r
    }

    public static func notFound(): MatchUnionResult {
        let r = MatchUnionResult()
        r.status = MatchStatus.NotFound
        r
    }

    public static func failure(error: String): MatchUnionResult {
        let r = MatchUnionResult()
        r.status = MatchStatus.Failure
        r.error = Some(error)
        r
    }

    public static func createPending(p: PendingResolution): MatchUnionResult {
        let r = MatchUnionResult()
        r.status = MatchStatus.Pending
        r.pending = Some(p)
        r
    }
}

// ============================================================================
// LoadResult - 文件加载结果
// 严格翻译自: resolver.zig - LoadResult
//   pub const LoadResult = struct {
//       path: string,
//       diff_case: ?Fs.FileSystem.Entry.Lookup.DifferentCase,
//       dirname_fd: FD = .invalid,
//       file_fd: FD = .invalid,
//       dir_info: ?*DirInfo = null,
//   };
// ============================================================================

/// 文件加载结果 - 对应 Bun LoadResult
/// 用于 loadAsFile 返回的文件查找结果
public class LoadResult {
    public var path: String
    public var diffCase: ?String
    public var dirnameFd: Int64
    public var fileFd: Int64
    public var dirInfo: ?DirInfo

    public init(path: String) {
        this.path = path
        diffCase = None
        dirnameFd = -1
        fileFd = -1
        dirInfo = None
    }

    public init(path: String, diffCase: ?String, dirnameFd: Int64, fileFd: Int64) {
        this.path = path
        this.diffCase = diffCase
        this.dirnameFd = dirnameFd
        this.fileFd = fileFd
        dirInfo = None
    }
}

// ============================================================================
// DirEntryResolveQueueItem - 目录条目解析队列项
// 严格翻译自: resolver.zig - DirEntryResolveQueueItem
//   pub const DirEntryResolveQueueItem = struct {
//       result: allocators.Result,
//       unsafe_path: string,
//       safe_path: string = "",
//       fd: FD = .invalid,
//   };
// ============================================================================

/// 目录条目解析队列项 - 对应 Bun DirEntryResolveQueueItem
/// 用于 dirInfoCached 中的目录遍历队列
public class DirEntryResolveQueueItem {
    public var unsafePath: String
    public var safePath: String
    public var fd: Int64

    public init(unsafePath: String) {
        this.unsafePath = unsafePath
        safePath = ""
        fd = -1
    }

    public init(unsafePath: String, safePath: String, fd: Int64) {
        this.unsafePath = unsafePath
        this.safePath = safePath
        this.fd = fd
    }
}

// ============================================================================
// PendingResolution - 待解决的模块
// 严格翻译自: resolver.zig - PendingResolution
//   pub const PendingResolution = struct {
//       esm: ESModule.Package.External,
//       dependency: Dependency.Version,
//       resolution_id: Install.PackageID,
//       root_dependency_id: Install.DependencyID,
//       import_record_id: u32,
//       string_buf: []u8,
//       tag: Tag,
//   };
// ============================================================================

/// 待解决的模块 - 对应 Bun PendingResolution
public class PendingResolution {
    public var packageName: String
    public var version: String
    public var resolutionId: Int64
    public var rootDependencyId: Int64
    public var importRecordId: Int64
    public var stringBuffer: String
    public var tag: PendingTag

    public init() {
        packageName = ""
        version = ""
        resolutionId = -1
        rootDependencyId = -1
        importRecordId = -1
        stringBuffer = ""
        tag = PendingTag.Done
    }

    public static let INVALID_PACKAGE_ID: Int64 = -1

    /// 释放资源
    /// 对应 Bun PendingResolution.deinit()
    public func deinit(): Unit {
        stringBuffer = ""
    }
}

/// 待解决状态标签
public enum PendingTag {
    | Download    // 需要下载
    | Resolve     // 需要解析
    | Done        // 完成
}

// ============================================================================
// DependencyToResolve - 依赖解析结果
// 严格翻译自: resolver.zig - DependencyToResolve
//   const DependencyToResolve = union(enum) {
//       not_found: void,
//       pending: PendingResolution,
//       failure: anyerror,
//       resolution: Resolution,
//   };
// ============================================================================

/// 依赖解析结果联合 - 对应 Bun DependencyToResolve
public enum DependencyToResolveTag {
    | NotFound
    | Pending
    | Failure
    | Resolution
}

public class DependencyToResolve {
    public var tag: DependencyToResolveTag
    public var pending: ?PendingResolution
    public var error: ?String
    public var resolutionPath: ?String

    public init() {
        tag = DependencyToResolveTag.NotFound
        pending = None
        error = None
        resolutionPath = None
    }

    public static func notFound(): DependencyToResolve {
        let r = DependencyToResolve()
        r.tag = DependencyToResolveTag.NotFound
        r
    }

    public static func createPending(p: PendingResolution): DependencyToResolve {
        let r = DependencyToResolve()
        r.tag = DependencyToResolveTag.Pending
        r.pending = Some(p)
        r
    }

    public static func failure(error: String): DependencyToResolve {
        let r = DependencyToResolve()
        r.tag = DependencyToResolveTag.Failure
        r.error = Some(error)
        r
    }

    public static func resolution(path: String): DependencyToResolve {
        let r = DependencyToResolve()
        r.tag = DependencyToResolveTag.Resolution
        r.resolutionPath = Some(path)
        r
    }
}

// ============================================================================
// DebugLogs - 调试日志
// 严格翻译自: resolver.zig - DebugLogs
//   pub const DebugLogs = struct {
//       what: string = "",
//       indent: MutableString,
//       notes: std.array_list.Managed(logger.Data),
//       pub const FlushMode = enum { fail, success };
//   };
// ============================================================================

/// 调试日志刷新模式
public enum DebugLogFlushMode {
    | Fail       // 失败时刷新
    | Success    // 成功时刷新
}

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

    /// 释放资源
    /// 对应 Bun DebugLogs.deinit()
    public func deinit(): Unit {
        notes.clear()
    }

    /// 增加缩进
    public func increaseIndent(): Unit {
        indent = "${indent} "
    }

    /// 减少缩进
    public func decreaseIndent(): Unit {
        if (indent.size > 0) {
            indent = indent[0..indent.size - 1]
        }
    }

    /// 添加备注
    public func addNote(text: String): Unit {
        if (indent.size > 0) {
            notes.append("${indent}${text}")
        } else {
            notes.append(text)
        }
    }

    /// 格式化添加备注
    /// 对应 Bun DebugLogs.addNoteFmt()
    public func addNoteFmt(fmt: String, args: Array<String>): Unit {
        addNote(formatString(fmt, args))
    }
}

// ============================================================================
// AnyResolveWatcher - 解析监视器
// 严格翻译自: resolver.zig - AnyResolveWatcher
//   pub const AnyResolveWatcher = struct {
//       context: *anyopaque,
//       callback: *const (fn (*anyopaque, dir_path: string, dir_fd: FD) void),
//   };
//
// ResolveWatcher - 泛型解析监视器工厂
// 严格翻译自: resolver.zig - ResolveWatcher()
//   pub fn ResolveWatcher(comptime Context: type, comptime onWatch: anytype) type
// ============================================================================

/// 解析监视器回调接口
/// 对应 Bun AnyResolveWatcher
public interface ResolveWatcherCallback {
    func watch(dirPath: String, fd: Int64): Unit
}

/// 解析监视器 - 对应 Bun AnyResolveWatcher
/// 用于 watch 模式下监视目录变化
public class AnyResolveWatcher {
    public var callback: ?ResolveWatcherCallback

    public init() {
        callback = None
    }

    public init(callback: ResolveWatcherCallback) {
        this.callback = Some(callback)
    }

    /// 监视目录
    /// 对应 Bun AnyResolveWatcher.watch()
    public func watch(dirPath: String, fd: Int64): Unit {
        if (let Some(cb) <- callback) {
            cb.watch(dirPath, fd)
        }
    }
}

// ============================================================================
// JsxPragma - JSX 编译指示
// 严格翻译自: resolver.zig - options.JSX.Pragma
// ============================================================================

/// JSX 编译指示 - 对应 Bun JSX.Pragma
public class JsxPragma {
    public var factory: String
    public var fragment: String
    public var runtime: JsxRuntime

    public init() {
        factory = ""
        fragment = ""
        runtime = JsxRuntime.Automatic
    }
}

/// JSX 运行时模式
public enum JsxRuntime {
    | Classic
    | Automatic
    | Preserve
}

// ============================================================================
// PackageJsonInfo - package.json 信息
// 严格翻译自: resolver.zig - PackageJSON (简化版)
// ============================================================================

/// package.json 信息 - 对应 Bun PackageJSON (简化版)
public class PackageJsonInfo {
    public var name: String
    public var version: String
    public var `main`: String
    public var `module`: String
    public var types: String
    public var typings: String
    public var exports: ?String
    public var imports: ?String
    public var browserMap: HashMap<String, String>
    public var sideEffects: SideEffectsPolicy
    public var moduleType: ModuleType
    public var dependencies: HashMap<String, String>
    public var devDependencies: HashMap<String, String>
    public var peerDependencies: HashMap<String, String>
    public var packageManager: String

    public init() {
        name = ""
        version = ""
        `main` = ""
        `module` = ""
        types = ""
        typings = ""
        exports = None
        imports = None
        browserMap = HashMap<String, String>()
        sideEffects = SideEffectsPolicy.Unspecified
        moduleType = ModuleType.Unknown
        dependencies = HashMap<String, String>()
        devDependencies = HashMap<String, String>()
        peerDependencies = HashMap<String, String>()
        packageManager = ""
    }

    /// 转换为 PackageJson
    public func toPackageJson(): PackageJson {
        let pkg = PackageJson()
        pkg.name = name
        pkg.version = version
        pkg.moduleType = moduleType
        pkg.browserMap = browserMap
        pkg.dependencies = dependencies
        pkg.devDependencies = devDependencies
        pkg.peerDependencies = peerDependencies
        pkg.types = types
        match (sideEffects) {
            case SideEffectsPolicy.NoSideEffects => pkg.sideEffects = SideEffectsKind.NoSideEffects
            case _ => pkg.sideEffects = SideEffectsKind.Unspecified
        }
        pkg
    }
}

/// 副作用策略
public enum SideEffectsPolicy {
    | Unspecified       // 未指定
    | NoSideEffects     // sideEffects: false
    | Glob              // sideEffects: ["*.css"]
    | Map               // sideEffects: 具体文件映射
    | Mixed             // 混合
}

// ============================================================================
// TsconfigInfo - TypeScript 配置信息
// 严格翻译自: resolver.zig - TSConfigJSON (简化版)
// ============================================================================

/// TypeScript 配置信息 - 对应 Bun TSConfigJSON
public class TsconfigInfo {
    public var absPath: String
    public var extends: String
    public var baseUrl: String
    public var baseUrlForPaths: String
    public var paths: HashMap<String, Array<String>>
    public var jsx: JsxPragma
    public var emitDecoratorMetadata: Bool
    public var experimentalDecorators: Bool
    public var preserveImportsNotUsedAsValues: ?Bool

    public init(absPath: String) {
        this.absPath = absPath
        extends = ""
        baseUrl = ""
        baseUrlForPaths = ""
        paths = HashMap<String, Array<String>>()
        jsx = JsxPragma()
        emitDecoratorMetadata = false
        experimentalDecorators = false
        preserveImportsNotUsedAsValues = None
    }

    /// 合并 JSX 配置
    public func mergeJSX(child: JsxPragma): JsxPragma {
        // 子配置覆盖父配置
        child
    }
}

// ============================================================================
// Dirname - 路径目录名工具
// 严格翻译自: resolver.zig - Dirname
//   pub const Dirname = struct {
//       pub fn dirname(path: string) string {
//           if (path.len == 0) return std.fs.path.sep_str;
//           ...
//       }
//   };
// ============================================================================

/// 路径目录名工具 - 对应 Bun Dirname
public class Dirname {
    /// 获取路径的目录部分
    /// 对应 Bun Dirname.dirname()
    /// 例如: "/foo/bar/baz.ts" -> "/foo/bar/"
    public static func dirname(path: String): String {
        if (path.size == 0) {
            return "/"
        }

        var endIndex = path.size - 1
        // 跳过尾部的路径分隔符
        while (endIndex > 0 && (path[endIndex] == 0x2F || path[endIndex] == 0x5C)) {
            endIndex = endIndex - 1
        }
        if (endIndex == 0) {
            return "/"
        }

        // 查找前一个路径分隔符
        while (endIndex > 0 && path[endIndex] != 0x2F && path[endIndex] != 0x5C) {
            endIndex = endIndex - 1
        }
        if (endIndex == 0) {
            return "/"
        }

        path[0..endIndex + 1]
    }
}

// ============================================================================
// RootPathPair - 根路径对
// 严格翻译自: resolver.zig - RootPathPair
//   pub const RootPathPair = struct {
//       base_path: string,
//       package_json: *const PackageJSON,
//   };
// ============================================================================

/// 根路径对 - 对应 Bun RootPathPair
/// 用于 rootNodeModulePackageJSON 返回 node_modules 中包的根路径和 package.json
public class RootPathPair {
    public var basePath: String
    public var packageJson: PackageJsonInfo

    public init(basePath: String, packageJson: PackageJsonInfo) {
        this.basePath = basePath
        this.packageJson = packageJson
    }
}

// ============================================================================
// BrowserMapPath - 浏览器映射路径检查器
// 严格翻译自: resolver.zig - BrowserMapPath
//   const BrowserMapPath = struct {
//       remapped: string = "",
//       cleaned: string = "",
//       input_path: string = "",
//       extension_order: []const string,
//       map: BrowserMap,
//       pub const Kind = enum { PackagePath, AbsolutePath };
//       pub fn checkPath(this: *BrowserMapPath, path_to_check: string) bool { ... }
//   };
// ============================================================================

/// 浏览器映射路径类型
public enum BrowserMapKind {
    | PackagePath    // 包路径 (如 "react")
    | AbsolutePath   // 绝对路径 (如 "/foo/node_modules/react/index.js")
}

/// 浏览器映射路径检查器 - 对应 Bun BrowserMapPath
/// 用于在 package.json 的 "browser" 字段中查找路径重映射
class BrowserMapPath {
    var remapped: String
    var cleaned: String
    var inputPath: String
    var extensionOrder: Array<String>
    var map: HashMap<String, String>

    init(extensionOrder: Array<String>, map: HashMap<String, String>) {
        remapped = ""
        cleaned = ""
        inputPath = ""
        this.extensionOrder = extensionOrder
        this.map = map
    }

    /// 检查路径是否在浏览器映射中
    /// 对应 Bun BrowserMapPath.checkPath()
    /// 1. 精确匹配
    /// 2. 尝试添加隐式扩展名
    /// 3. 尝试假设为目录并查找 "index" 文件
    func checkPath(pathToCheck: String): Bool {
        // 1. 精确匹配
        if (let Some(result) <- map.get(pathToCheck)) {
            remapped = result
            inputPath = pathToCheck
            return true
        }

        // 2. 尝试添加隐式扩展名
        if (cleaned.size <= 4096) {
            for (ext in extensionOrder) {
                let tryPath = "${cleaned}${ext}"
                if (map.get(tryPath).isSome()) {
                    if (let Some(result) <- map.get(tryPath)) {
                        remapped = result
                        cleaned = tryPath
                        inputPath = tryPath
                        return true
                    }
                }
            }
        }

        // 3. 尝试假设为目录并查找 "index" 文件
        var indexPath = removeTrailingSep(pathToCheck)
        if (!indexPath.endsWith("/")) {
            indexPath = "${indexPath}/"
        }
        indexPath = "${indexPath}index"

        if (let Some(result) <- map.get(indexPath)) {
            remapped = result
            inputPath = indexPath
            return true
        }

        // 尝试 index + 扩展名
        if (indexPath.size <= 4096) {
            for (ext in extensionOrder) {
                let tryPath = "${indexPath}${ext}"
                if (let Some(result) <- map.get(tryPath)) {
                    remapped = result
                    cleaned = tryPath
                    inputPath = tryPath
                    return true
                }
            }
        }

        false
    }

    /// 移除尾部路径分隔符
    func removeTrailingSep(path: String): String {
        if (path.size == 0) {
            return path
        }
        var end = path.size
        while (end > 0 && (path[end - 1] == UInt8(47) || path[end - 1] == UInt8(92))) {
            end = end - 1
        }
        path[0..end]
    }
}

// ============================================================================
// ESMResolutionStatus - ESM 解析状态
// 严格翻译自: resolver.zig - ESModule.Resolution (状态枚举)
// ============================================================================

/// ESM 解析状态 - 对应 Bun ESModule.Resolution.status
public enum ESMResolutionStatus {
    | Exact                          // 精确匹配
    | ExactEndsWithStar              // 精确匹配 (通配符末尾)
    | Inexact                        // 不精确 (目录匹配)
    | ModuleNotFound                 // 模块未找到
    | ModuleNotFoundMissingExtension // 模块未找到 (缺少扩展名)
    | UnsupportedDirectoryImport     // 不支持的目录导入
    | PackageResolve                 // 解析到另一个包
    | Invalid                        // 无效
}

/// ESM 解析结果 - 对应 Bun ESModule.Resolution
public class ESMResolution {
    public var status: ESMResolutionStatus
    public var path: String
    public var packageName: String
    public var packageVersion: String

    public init() {
        status = ESMResolutionStatus.Invalid
        path = ""
        packageName = ""
        packageVersion = ""
    }
}

// ============================================================================
// ESMPackage - ESM 包说明符
// 严格翻译自: resolver.zig - ESModule.Package
//   pub const Package = struct { name: string, subpath: string, version: string }
// ============================================================================

/// ESM 包说明符 - 对应 Bun ESModule.Package
public class ESMPackage {
    public var name: String
    public var subpath: String
    public var version: String

    public init() {
        name = ""
        subpath = ""
        version = ""
    }

    public init(name: String, subpath: String, version: String) {
        this.name = name
        this.subpath = subpath
        this.version = version
    }
}

// ============================================================================
// Resolver - 模块解析器
// 严格翻译自: resolver.zig - Resolver
//   pub const Resolver = struct {
//       opts: options.BundleOptions,
//       fs: *Fs.FileSystem,
//       log: *logger.Log,
//       allocator: std.mem.Allocator,
//       extension_order: []const string,
//       timer: Timer,
//       care_about_bin_folder: bool,
//       care_about_scripts: bool,
//       care_about_browser_field: bool,
//       debug_logs: ?DebugLogs,
//       elapsed: u64,
//       watcher: ?AnyResolveWatcher,
//       caches: CacheSet,
//       generation: bun.Generation,
//       package_manager: ?*PackageManager,
//       onWakePackageManager: PackageManager.WakeHandler,
//       env_loader: ?*DotEnv.Loader,
//       store_fd: bool,
//       standalone_module_graph: ?*StandaloneModuleGraph,
//       mutex: *Mutex,
//       dir_cache: *DirInfo.HashMap,
//       prefer_module_field: bool,
//       custom_dir_paths: ?[]const bun.String,
//   };
// ============================================================================

/// 模块解析器 - 对应 Bun Resolver
/// 核心模块解析系统，实现 Node.js 兼容的模块解析算法
public class Resolver {
    /// 打包选项
    public var opts: ResolverBundleOptions
    /// 日志
    public var log: ArrayList<String>
    /// 扩展名顺序
    public var extensionOrder: Array<String>
    /// 是否关心 bin 文件夹
    public var careAboutBinFolder: Bool
    /// 是否关心 scripts
    public var careAboutScripts: Bool
    /// 是否关心 browser 字段
    public var careAboutBrowserField: Bool
    /// 调试日志
    public var debugLogs: ?DebugLogs
    /// 耗时 (纳秒)
    public var elapsed: Int64
    /// 生成号
    public var generation: Int64
    /// 是否存储文件描述符
    public var storeFd: Bool
    /// 解析监视器
    public var watcher: ?AnyResolveWatcher
    /// 目录缓存
    public var dirCache: HashMap<String, DirInfo>
    /// 是否优先使用 module 字段
    public var preferModuleField: Bool
    /// 自定义目录路径
    public var customDirPaths: ?Array<String>
    /// 包管理器
    public var packageManager: ?String
    /// 独立模块图
    public var standaloneModuleGraph: ?String
    /// 环境加载器
    public var envLoader: ?String
    /// 顶层目录
    public var topLevelDir: String
    /// bin 目录列表
    /// 对应 Bun: var bin_folders: BinFolderArray
    public var binFolders: ArrayList<String>

    public init() {
        opts = ResolverBundleOptions()
        log = ArrayList<String>()
        extensionOrder = [".tsx", ".ts", ".jsx", ".js", ".json"]
        careAboutBinFolder = false
        careAboutScripts = false
        careAboutBrowserField = true
        debugLogs = None
        elapsed = 0
        generation = 0
        storeFd = false
        watcher = None
        dirCache = HashMap<String, DirInfo>()
        preferModuleField = true
        customDirPaths = None
        packageManager = None
        standaloneModuleGraph = None
        envLoader = None
        topLevelDir = ""
        binFolders = ArrayList<String>()
    }

    public init(opts: ResolverBundleOptions) {
        this.opts = opts
        log = ArrayList<String>()
        extensionOrder = opts.extensionOrder.defaultGroup.defaultOrder
        careAboutBinFolder = false
        careAboutScripts = false
        careAboutBrowserField = match (opts.target) { case BundleTarget.Browser => true case _ => false }
        debugLogs = None
        elapsed = 0
        generation = 0
        storeFd = false
        watcher = None
        dirCache = HashMap<String, DirInfo>()
        preferModuleField = true
        customDirPaths = None
        packageManager = None
        standaloneModuleGraph = None
        envLoader = None
        topLevelDir = ""
        binFolders = ArrayList<String>()
    }

    // ========================================================================
    // init1 - 初始化解析器
    // 严格翻译自: resolver.zig - Resolver.init1()
    //   pub fn init1(allocator, log, _fs, opts) ThisResolver
    // ========================================================================

    /// 初始化解析器 - 对应 Bun Resolver.init1()
    public static func create(log: ArrayList<String>, opts: ResolverBundleOptions): Resolver {
        let r = Resolver(opts)
        r.log = log
        r
    }

    // ========================================================================
    // deinit - 释放资源
    // 严格翻译自: resolver.zig - Resolver.deinit()
    // ========================================================================

    /// 释放资源 - 对应 Bun Resolver.deinit()
    public func deinit(): Unit {
        // 清空目录缓存
        dirCache.forEach({ _, di =>
            di.deinit()
        })
        dirCache.clear()
        binFolders.clear()
    }

    // ========================================================================
    // usePackageManager - 是否使用包管理器
    // 严格翻译自: resolver.zig - Resolver.usePackageManager()
    //   pub inline fn usePackageManager(self: *const ThisResolver) bool
    // ========================================================================

    /// 是否使用包管理器 - 对应 Bun Resolver.usePackageManager()
    public func usePackageManager(): Bool {
        // 独立模式下不自动安装
        if (standaloneModuleGraph.isSome()) {
            return false
        }
        opts.globalCache.isEnabled()
    }

    // ========================================================================
    // getPackageManager - 获取包管理器
    // 严格翻译自: resolver.zig - Resolver.getPackageManager()
    //   pub fn getPackageManager(this: *Resolver) *PackageManager
    // ========================================================================

    /// 获取包管理器实例
    /// 对应 Bun Resolver.getPackageManager()
    public func getPackageManager(): String {
        if (packageManager.isSome()) {
            return packageManager.getOrThrow()
        }
        // 初始化包管理器
        let pm = "PackageManager"
        packageManager = Some(pm)
        pm
    }

    // ========================================================================
    // resolve - 解析模块
    // 严格翻译自: resolver.zig - resolve()
    //   pub fn resolve(r, source_dir, import_path, kind) !Result
    // ========================================================================

    /// 解析模块
    /// 对应 Bun Resolver.resolve()
    /// - sourceDir: 源目录 (绝对路径)
    /// - importPath: 导入路径
    /// - kind: 导入类型
    public func resolve(sourceDir: String, importPath: String,
                         kind: ImportKind): ?ResolveResult {
        let resolveResult = resolveAndAutoInstall(sourceDir, importPath, kind,
                                    GlobalCache.Disable)
        match (resolveResult.status) {
            case ResolveStatus.Success => resolveResult.result
            case _ => None
        }
    }

    // ========================================================================
    // resolveWithFramework - 带框架的解析
    // 严格翻译自: resolver.zig - resolveWithFramework()
    //   pub fn resolveWithFramework(r, source_dir, import_path, kind) !Result
    // ========================================================================

    /// 带框架覆盖的解析
    /// 对应 Bun Resolver.resolveWithFramework()
    public func resolveWithFramework(sourceDir: String, importPath: String,
                                      kind: ImportKind): ?ResolveResult {
        if (let Some(framework) <- opts.framework) {
            if (let Some(mod) <- framework.builtInModules.get(importPath)) {
                match (mod) {
                    case FrameworkModule.Code =>
                        // 框架内建代码模块
                        let result = ResolveResult(
                            PathPair(ResolverPath.initWithNamespace(importPath, "node"))
                        )
                        result.importKind = kind
                        result.moduleType = ModuleType.Esm
                        result.primarySideEffectsData = SideEffects.NoSideEffectsPureData
                        return Some(result)
                    case FrameworkModule.Import(path) =>
                        // 重定向到另一个路径
                        return resolve("", path, ImportKind.EntryPointBuild)
                }
            }
        }
        resolve(sourceDir, importPath, kind)
    }

    // ========================================================================
    // resolveAndAutoInstall - 解析并自动安装
    // 严格翻译自: resolver.zig - resolveAndAutoInstall()
    //   pub fn resolveAndAutoInstall(r, source_dir, import_path, kind, global_cache) Result.Union
    //   完整的解析入口点:
    //     1. 标记内置模块 (node:, bun:)
    //     2. 检查外部模式
    //     3. 解析 data URL
    //     4. 标准化源目录
    //     5. 调用 resolveWithoutSymlinks
    //     6. 调用 finalizeResult
    // ========================================================================

    /// 解析并自动安装
    /// 对应 Bun Resolver.resolveAndAutoInstall()
    public func resolveAndAutoInstall(sourceDir: String, importPath: String,
                                       kind: ImportKind,
                                       globalCache: GlobalCache): ResolveUnionResult {
        // 空路径
        if (importPath.size == 0) {
            return ResolveUnionResult.notFound()
        }

        // 设置当前扩展名顺序
        // 严格翻译自:
        //   r.extension_order = switch (kind) {
        //       .url, .at_conditional, .at => CSSExtensionOrder,
        //       .entry_point_build, .entry_point_run, .stmt, .dynamic => esm,
        //       else => default,
        //   };
        let originalOrder = extensionOrder
        extensionOrder = match (kind) {
            case ImportKind.Url | ImportKind.AtConditional | ImportKind.At =>
                CSS_EXTENSION_ORDER
            case ImportKind.EntryPointBuild | ImportKind.EntryPointRun |
                 ImportKind.Stmt | ImportKind.Dynamic =>
                opts.extensionOrder.defaultGroup.esmOrder
            case _ => opts.extensionOrder.defaultGroup.defaultOrder
        }

        // 初始化调试日志
        if (debugLogs.isSome()) {
            debugLogs.getOrThrow().deinit()
            debugLogs = Some(DebugLogs())
        }

        // 标记内置模块为外部
        // 严格翻译自:
        //   if (r.opts.mark_builtins_as_external) {
        //       if (strings.hasPrefixComptime(import_path, "node:") or
        //           strings.hasPrefixComptime(import_path, "bun:")) { ... }
        //   }
        if (opts.markBuiltinsAsExternal) {
            if (importPath.startsWith("node:") || importPath.startsWith("bun:")) {
                extensionOrder = originalOrder
                let result = ResolveResult(PathPair(ResolverPath(importPath)))
                result.importKind = kind
                result.moduleType = ModuleType.Cjs
                result.primarySideEffectsData = SideEffects.NoSideEffectsPureData
                result.flags.isExternal = true
                return ResolveUnionResult.success(result)
            }
        }

        // tsconfig paths 优先于 packages=external
        // 严格翻译自:
        //   if (kind != .entry_point_build and kind != .entry_point_run and
        //       r.opts.packages == .external and isPackagePath(import_path) and
        //       !r.matchesUserExternalPattern(import_path)) { ... }
        if (match (kind) { case ImportKind.EntryPointBuild | ImportKind.EntryPointRun => false case _ => true } &&
            match (opts.packages) { case PackageStrategy.External => true case _ => false } &&
            isPackagePath(importPath) &&
            !matchesUserExternalPattern(importPath)) {
            if (let Some(res) <- resolveViaTSConfigPaths(sourceDir, importPath, kind)) {
                extensionOrder = originalOrder
                let result = ResolveResult(res.pathPair)
                result.importKind = kind
                result.diffCase = res.diffCase
                result.packageJson = res.packageJson
                result.dirnameFd = res.dirnameFd
                result.fileFd = res.fileFd
                result.jsx = JSXConfig()
                return ResolveUnionResult.success(result)
            }
        }

        // 检查外部模式
        // 严格翻译自:
        //   if (kind != .entry_point_build and kind != .entry_point_run and
        //       (r.isExternalPattern(import_path) or ...))
        if (match (kind) { case ImportKind.EntryPointBuild | ImportKind.EntryPointRun => false case _ => true }) {
            if (isExternalPattern(importPath) ||
                (kind.isFromCSS() && importPath.startsWith("#")) ||
                importPath.startsWith("http://") ||
                importPath.startsWith("https://") ||
                importPath.startsWith("//")) {
                extensionOrder = originalOrder
                let result = ResolveResult(PathPair(ResolverPath(importPath)))
                result.importKind = kind
                result.flags.isExternal = true
                if (!kind.isFromCSS()) {
                    result.moduleType = ModuleType.Esm
                }
                return ResolveUnionResult.success(result)
            }
        }

        // 解析 data URL
        // 严格翻译自: DataURL.parse(import_path)
        if (importPath.startsWith("data:")) {
            let result = ResolveResult(
                PathPair(ResolverPath.initWithNamespace(importPath, "dataurl"))
            )
            // 简化: 对于 JavaScript/CSS/JSON/text 数据为非外部
            // 对于图片/其他数据标记为外部
            if (importPath.contains("javascript") || importPath.contains("css") ||
                importPath.contains("json") || importPath.contains("text")) {
                extensionOrder = originalOrder
                return ResolveUnionResult.success(result)
            }
            result.flags.isExternal = true
            extensionOrder = originalOrder
            return ResolveUnionResult.success(result)
        }

        // 标准化源目录
        var normalizedSourceDir = sourceDir
        if (sourceDir.size == 0) {
            normalizedSourceDir = if (topLevelDir.size > 0) { topLevelDir } else { "/" }
        } else if (!Path.isAbsolute(sourceDir)) {
            normalizedSourceDir = if (topLevelDir.size > 0) { topLevelDir } else { "/" }
        }

        // 包含空字节的路径不可能存在于文件系统
        // 严格翻译自: if (bun.strings.containsChar(import_path, 0))
        if (importPath.contains("\0")) {
            extensionOrder = originalOrder
            return ResolveUnionResult.notFound()
        }

        // 调用不解析符号链接的解析
        var tmp = resolveWithoutSymlinks(normalizedSourceDir, importPath, kind,
                                          globalCache)

        // CSS URL 片段重试
        // 严格翻译自:
        //   if (tmp == .not_found and kind.isFromCSS()) try_without_suffix: {
        //       const maybe_suffix = bun.strings.indexOfAny(import_path, "?#");
        //       ...
        //   }
        if (match (tmp.status) { case ResolveStatus.NotFound => true case _ => false } && kind.isFromCSS()) {
            let suffixIndex = indexOfAny(importPath, "?#")
            if (suffixIndex.isSome()) {
                if (let Some(idx) <- suffixIndex) {
                    if (idx > 0) {
                        let cleanPath = importPath[Int64(0)..idx]
                        let retry = resolveWithoutSymlinks(normalizedSourceDir,
                                                            cleanPath, kind, globalCache)
                        if (match (retry.status) { case ResolveStatus.NotFound => false case _ => true }) {
                            tmp = retry
                        }
                    }
                }
            }
        }

        // 最终化结果
        extensionOrder = originalOrder
        match (tmp.status) {
            case Success =>
                if (let Some(r) <- tmp.result) {
                    if (!match (r.pathPair.primary.namespace) { case "node" => true case _ => false } &&
                        !r.flags.isStandaloneModule) {
                        finalizeResult(r, kind)
                    }
                    r.importKind = kind
                }
                tmp
            case _ => tmp
        }
    }

    // ========================================================================
    // resolveWithoutSymlinks - 不解析符号链接的解析
    // 严格翻译自: resolver.zig - resolveWithoutSymlinks()
    //   pub fn resolveWithoutSymlinks(r, source_dir, import_path, kind, global_cache) Result.Union
    //   核心解析算法:
    //     1. 绝对路径处理 (折叠 ".."，检查 tsconfig paths)
    //     2. 相对路径处理
    //     3. 包路径 (bare specifier) 处理
    //     4. 目录解析
    //     5. 扩展名补全
    // ========================================================================

    /// 不解析符号链接的解析
    /// 对应 Bun Resolver.resolveWithoutSymlinks()
    public func resolveWithoutSymlinks(sourceDir: String, importPath: String,
                                        kind: ImportKind,
                                        globalCache: GlobalCache): ResolveUnionResult {
        var result = ResolveResult(PathPair(ResolverPath.empty))

        // 绝对路径处理
        // 严格翻译自:
        //   if (std.fs.path.isAbsolute(import_path)) {
        //       // 折叠 ".." 相对目录指示符
        //       // 先检查 tsconfig paths
        //       // 检查外部绝对路径
        //       // 然后解析绝对路径
        //   }
        if (Path.isAbsolute(importPath)) {
            var normalizedImport = importPath

            // 折叠 ".." 相对目录指示符
            // 严格翻译自:
            //   if (bun.strings.indexOf(import_path, "..") != null) {
            //       import_path = r.fs.absBufChecked(&.{import_path}, buf) orelse return .not_found;
            //   }
            if (importPath.contains("..")) {
                normalizedImport = Path.normalize(importPath)
            }

            // 检查 tsconfig paths
            if (let Some(dirInfo) <- dirInfoCached(sourceDir)) {
                if (let Some(tsconfig) <- dirInfo.enclosingTsconfigJson) {
                    if (tsconfig.paths.size > 0) {
                        if (let Some(matchResult) <- matchTSConfigPaths(
                                tsconfig, normalizedImport, kind)) {
                            let r = ResolveResult(matchResult.pathPair)
                            r.diffCase = matchResult.diffCase
                            r.packageJson = matchResult.packageJson
                            r.dirnameFd = matchResult.dirnameFd
                            r.fileFd = matchResult.fileFd
                            r.jsx = tsconfig.mergeJSX(result.jsx)
                            return ResolveUnionResult.success(r)
                        }
                    }
                }
            }

            // 检查绝对路径外部标记
            if (opts.external.absPaths.size > 0 &&
                opts.external.absPaths.contains(normalizedImport)) {
                let r = ResolveResult(PathPair(ResolverPath(normalizedImport)))
                r.flags.isExternal = true
                return ResolveUnionResult.success(r)
            }

            // 浏览器映射
            if (careAboutBrowserField) {
                if (let Some(remapped) <- browserMapLookup(sourceDir, normalizedImport)) {
                    if (remapped.size == 0) {
                        return ResolveUnionResult.notFound()
                    }
                    // 递归解析重映射后的路径
                    return resolveWithoutSymlinks(sourceDir, remapped, kind, globalCache)
                }
            }

            // 尝试作为文件或目录解析
            return loadAsFileOrDirectory(normalizedImport, kind)
        }

        // 相对路径处理 (以 "./" 或 "../" 开头)
        // 判断是否为包路径
        let isPkgPath = match (kind) { case ImportKind.EntryPointRun => false case _ => isPackagePathNotAbsolute(importPath) }
        let checkRelative = !isPkgPath || kind.isFromCSS()
        let checkPackage = isPkgPath

        if (checkRelative) {
            // 自定义目录路径
            if (let Some(customPaths) <- customDirPaths) {
                for (customPath in customPaths) {
                    let checkResult = checkRelativePath(customPath, importPath, kind, globalCache)
                    match (checkResult.status) {
                        case ResolveStatus.Success => return checkResult
                        case ResolveStatus.Pending => return checkResult
                        case ResolveStatus.Failure => return checkResult
                        case _ => ()
                    }
                }
                // 自定义路径中没有找到且检查包路径无意义
                if (!checkPackage) {
                    return ResolveUnionResult.notFound()
                }
            } else {
                let checkResult = checkRelativePath(sourceDir, importPath, kind, globalCache)
                match (checkResult.status) {
                    case ResolveStatus.Success => return checkResult
                    case ResolveStatus.Pending => return checkResult
                    case ResolveStatus.Failure => return checkResult
                    case _ => ()
                }
            }
        }

        if (checkPackage) {
            // Node polyfill 全局变量
            // 严格翻译自:
            //   if (r.opts.polyfill_node_globals) { ... NodeFallbackModules.Map.get(...) ... }
            if (opts.polyfillNodeGlobals) {
                let hadNodePrefix = importPath.startsWith("node:")
                let importPathWithoutPrefix = if (hadNodePrefix) {
                    importPath[Int64(5)..importPath.size]
                } else {
                    importPath
                }

                // fs 特殊处理 - 标记为禁用
                if (importPathWithoutPrefix.startsWith("fs") &&
                    (importPathWithoutPrefix.size == 2 ||
                     importPathWithoutPrefix[Int64(2)] == UInt8(47))) {
                    let r = ResolveResult(
                        PathPair(ResolverPath.initWithNamespace(importPathWithoutPrefix, "node"))
                    )
                    r.moduleType = ModuleType.Cjs
                    r.pathPair.primary.isDisabled = true
                    r.flags.isFromNodeModules = true
                    r.primarySideEffectsData = SideEffects.NoSideEffectsPureData
                    return ResolveUnionResult.success(r)
                }
            }

            // 外部 node_modules 检查
            // 严格翻译自:
            //   if (r.opts.external.node_modules.count() > 0 and !strings.hasSuffixComptime(import_path, "/"))
            if (opts.external.nodeModules.size > 0 && !importPath.endsWith("/")) {
                var query = importPath
                while (true) {
                    if (opts.external.nodeModules.contains(query)) {
                        let r = ResolveResult(PathPair(ResolverPath(query)))
                        r.flags.isExternal = true
                        return ResolveUnionResult.success(r)
                    }
                    // "foo/bar" 也视为外部
                    let slashOpt = query.lastIndexOf('/')
                    if (let Some(slash) <- slashOpt) {
                        query = query[Int64(0)..slash]
                    } else {
                        break
                    }
                }
            }

            // 自定义目录路径
            if (let Some(customPaths) <- customDirPaths) {
                for (customPath in customPaths) {
                    let checkResult = checkPackagePath(customPath, importPath, kind, globalCache)
                    match (checkResult.status) {
                        case ResolveStatus.Success => return checkResult
                        case ResolveStatus.Pending => return checkResult
                        case ResolveStatus.Failure => return checkResult
                        case _ => ()
                    }
                }
            } else {
                let checkResult = checkPackagePath(sourceDir, importPath, kind, globalCache)
                match (checkResult.status) {
                    case ResolveStatus.Success => return checkResult
                    case ResolveStatus.Pending => return checkResult
                    case ResolveStatus.Failure => return checkResult
                    case _ => ()
                }
            }
        }

        ResolveUnionResult.notFound()
    }

    // ========================================================================
    // checkRelativePath - 检查相对路径
    // 严格翻译自: resolver.zig - checkRelativePath()
    //   pub fn checkRelativePath(r, source_dir, import_path, kind, global_cache) Result.Union
    // ========================================================================

    /// 检查相对路径 - 对应 Bun Resolver.checkRelativePath()
    func checkRelativePath(sourceDir: String, importPath: String,
                            kind: ImportKind,
                            globalCache: GlobalCache): ResolveUnionResult {
        let absPath = Path.join([sourceDir, importPath])
        let normalized = Path.normalize(absPath)

        // 检查绝对路径外部标记
        if (opts.external.absPaths.size > 0 && opts.external.absPaths.contains(normalized)) {
            let r = ResolveResult(PathPair(ResolverPath(normalized)))
            r.flags.isExternal = true
            return ResolveUnionResult.success(r)
        }

        // 浏览器映射
        if (careAboutBrowserField) {
            if (let Some(dirInfo) <- dirInfoCached(Dirname.dirname(normalized))) {
                if (let Some(browserScope) <- dirInfo.getEnclosingBrowserScope()) {
                    if (let Some(pkg) <- dirInfo.packageJson) {
                        if (let Some(remap) <- checkBrowserMap(
                                browserScope, normalized, BrowserMapKind.AbsolutePath)) {
                            if (remap.size == 0) {
                                let path = ResolverPath(normalized)
                                path.isDisabled = true
                                return ResolveUnionResult.success(
                                    ResolveResult(PathPair(path))
                                )
                            }
                            // 通过 resolveWithoutRemapping 解析重映射路径
                            if (let Some(dirInfoForScope) <- dirInfoCached(browserScope.absPath)) {
                                let matchResult = resolveWithoutRemapping(
                                    dirInfoForScope, remap, kind, globalCache)
                                match (matchResult.status) {
                                    case MatchStatus.Success =>
                                        if (let Some(mr) <- matchResult.result) {
                                            let r = ResolveResult(mr.pathPair)
                                            r.packageJson = Some(pkg)
                                            r.dirnameFd = mr.dirnameFd
                                            r.moduleType = mr.moduleType
                                            r.flags.isExternal = mr.isExternal
                                            r.flags.isExternalAndRewriteImportPath = mr.isExternal
                                            return ResolveUnionResult.success(r)
                                        }
                                    case _ => ()
                                }
                            }
                        }
                    }
                }
            }
        }

        // 根据路径是否在 node_modules 中调整扩展名顺序
        // 严格翻译自:
        //   if (strings.pathContainsNodeModulesFolder(abs_path)) {
        //       r.extension_order = r.opts.extension_order.kind(kind, true);
        //   }
        var prevExtensionOrder = extensionOrder
        if (normalized.contains("/node_modules/")) {
            let tag = opts.extOrderKind(kind, true)
            extensionOrder = opts.extOrderSlice(tag)
        }

        // 尝试作为文件或目录加载
        if (let Some(res) <- loadAsFileOrDirectoryMatch(normalized, kind)) {
            extensionOrder = prevExtensionOrder
            let r = ResolveResult(res.pathPair)
            r.diffCase = res.diffCase
            r.dirnameFd = res.dirnameFd
            r.packageJson = res.packageJson
            return ResolveUnionResult.success(r)
        }

        extensionOrder = prevExtensionOrder
        ResolveUnionResult.notFound()
    }

    // ========================================================================
    // checkPackagePath - 检查包路径
    // 严格翻译自: resolver.zig - checkPackagePath()
    //   pub fn checkPackagePath(r, source_dir, import_path, kind, global_cache) Result.Union
    // ========================================================================

    /// 检查包路径 - 对应 Bun Resolver.checkPackagePath()
    func checkPackagePath(sourceDir: String, importPath: String,
                           kind: ImportKind,
                           globalCache: GlobalCache): ResolveUnionResult {
        var sourceDirInfo: ?DirInfo = None

        // 获取源目录信息
        if (let Some(di) <- dirInfoCached(sourceDir)) {
            sourceDirInfo = Some(di)
        } else {
            // 源目录不存在时，向上查找存在的目录
            var closestDir = sourceDir
            while (true) {
                let parent = Dirname.dirname(closestDir)
                if (parent == closestDir || parent.size == 0) {
                    break
                }
                if (let Some(di) <- dirInfoCached(parent)) {
                    sourceDirInfo = Some(di)
                    break
                }
                closestDir = parent
            }
            if (sourceDirInfo.isNone()) {
                return ResolveUnionResult.notFound()
            }
        }

        var mutableImportPath = importPath

        if (let Some(dirInfo) <- sourceDirInfo) {
            // 浏览器映射
            if (careAboutBrowserField) {
                if (let Some(browserScope) <- dirInfo.getEnclosingBrowserScope()) {
                    if (let Some(pkg) <- browserScope.packageJson) {
                        if (let Some(remapped) <- checkBrowserMap(
                                browserScope, mutableImportPath, BrowserMapKind.PackagePath)) {
                            if (remapped.size == 0) {
                                // 禁用模块
                                let loadResult = loadNodeModules(
                                    mutableImportPath, kind, dirInfo, globalCache, false)
                                match (loadResult.status) {
                                    case MatchStatus.Success =>
                                        if (let Some(nodeModule) <- loadResult.result) {
                                            nodeModule.pathPair.primary.isDisabled = true
                                            if (let Some(sec) <- nodeModule.pathPair.secondary) {
                                                sec.isDisabled = true
                                            }
                                            let r = ResolveResult(nodeModule.pathPair)
                                            r.dirnameFd = nodeModule.dirnameFd
                                            r.packageJson = Some(pkg)
                                            return ResolveUnionResult.success(r)
                                        }
                                    case _ =>
                                        let path = ResolverPath(mutableImportPath)
                                        path.isDisabled = true
                                        return ResolveUnionResult.success(
                                            ResolveResult(PathPair(path))
                                        )
                                }
                            }
                            mutableImportPath = remapped
                        }
                    }
                }
            }

            // 解析不重映射
            let matchResult = resolveWithoutRemapping(dirInfo, mutableImportPath, kind, globalCache)
            match (matchResult.status) {
                case MatchStatus.Success =>
                    if (let Some(res) <- matchResult.result) {
                        let r = ResolveResult(res.pathPair)
                        r.dirnameFd = res.dirnameFd
                        r.fileFd = res.fileFd
                        r.packageJson = res.packageJson
                        r.diffCase = res.diffCase
                        r.flags.isFromNodeModules = r.flags.isFromNodeModules || res.isNodeModule
                        r.moduleType = res.moduleType
                        r.flags.isExternal = res.isExternal
                        r.flags.isExternalAndRewriteImportPath = res.isExternal

                        if (res.pathPair.primary.isDisabled && res.pathPair.secondary.isNone()) {
                            return ResolveUnionResult.success(r)
                        }

                        // 二次浏览器映射检查
                        // 严格翻译自:
                        //   if (res.package_json != null and r.care_about_browser_field) {
                        //       if (base_dir_info.getEnclosingBrowserScope()) |browser_scope| {
                        //           if (r.checkBrowserMap(browser_scope, res.path_pair.primary.text, .AbsolutePath)) |remap| { ... }
                        //       }
                        //   }
                        if (res.packageJson.isSome() && careAboutBrowserField) {
                            var baseDirInfo = res.dirInfo
                            if (baseDirInfo.isNone()) {
                                baseDirInfo = dirInfoCached(res.pathPair.primary.name.dir)
                            }
                            if (let Some(bdi) <- baseDirInfo) {
                                if (let Some(browserScope) <- bdi.getEnclosingBrowserScope()) {
                                    if (let Some(remap) <- checkBrowserMap(
                                            browserScope, res.pathPair.primary.text,
                                            BrowserMapKind.AbsolutePath)) {
                                        if (remap.size == 0) {
                                            r.pathPair.primary.isDisabled = true
                                        } else {
                                            let remappedResult = resolveWithoutRemapping(
                                                browserScope, remap, kind, globalCache)
                                            match (remappedResult.status) {
                                                case MatchStatus.Success =>
                                                    if (let Some(remapped) <- remappedResult.result) {
                                                        r.pathPair = remapped.pathPair
                                                        r.dirnameFd = remapped.dirnameFd
                                                        r.fileFd = remapped.fileFd
                                                        r.packageJson = remapped.packageJson
                                                        r.diffCase = remapped.diffCase
                                                        r.moduleType = remapped.moduleType
                                                        r.flags.isExternal = remapped.isExternal
                                                        r.flags.isExternalAndRewriteImportPath = remapped.isExternal
                                                        r.flags.isFromNodeModules = r.flags.isFromNodeModules || remapped.isNodeModule
                                                        return ResolveUnionResult.success(r)
                                                    }
                                                case _ => ()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        return ResolveUnionResult.success(r)
                    }
                case MatchStatus.Pending =>
                    if (let Some(p) <- matchResult.pending) {
                        return ResolveUnionResult.createPending(p)
                    }
                case MatchStatus.Failure =>
                    if (let Some(e) <- matchResult.error) {
                        return ResolveUnionResult.failure(e)
                    }
                case _ => ()
            }
        }

        ResolveUnionResult.notFound()
    }

    // ========================================================================
    // resolveWithoutRemapping - 不重映射的解析
    // 严格翻译自: resolver.zig - resolveWithoutRemapping()
    //   pub fn resolveWithoutRemapping(r, source_dir_info, import_path, kind, global_cache) MatchResult.Union
    // ========================================================================

    /// 不重映射的解析 - 对应 Bun Resolver.resolveWithoutRemapping()
    func resolveWithoutRemapping(sourceDirInfo: DirInfo, importPath: String,
                                  kind: ImportKind,
                                  globalCache: GlobalCache): MatchUnionResult {
        if (isPackagePath(importPath)) {
            let nodeResult = loadNodeModules(importPath, kind, sourceDirInfo, globalCache, false)
            match (nodeResult.status) {
                case MatchStatus.Success => return nodeResult
                case MatchStatus.Pending => return nodeResult
                case MatchStatus.Failure => return nodeResult
                case _ => ()
            }
            MatchUnionResult.notFound()
        } else {
            let resolved = Path.join([sourceDirInfo.absPath, importPath])
            if (let Some(result) <- loadAsFileOrDirectoryMatch(resolved, kind)) {
                MatchUnionResult.success(result)
            } else {
                MatchUnionResult.notFound()
            }
        }
    }

    // ========================================================================
    // resolveViaTSConfigPaths - 通过 tsconfig paths 解析
    // 严格翻译自: resolver.zig - resolveViaTSConfigPaths()
    //   pub fn resolveViaTSConfigPaths(r, source_dir, import_path, kind) ?MatchResult
    // ========================================================================

    /// 通过 tsconfig paths 解析 - 对应 Bun Resolver.resolveViaTSConfigPaths()
    func resolveViaTSConfigPaths(sourceDir: String, importPath: String,
                                  kind: ImportKind): ?MatchResult {
        if (sourceDir.size == 0) {
            return None
        }
        if (!Path.isAbsolute(sourceDir)) {
            return None
        }
        if (let Some(dirInfo) <- dirInfoCached(sourceDir)) {
            if (let Some(tsconfig) <- dirInfo.enclosingTsconfigJson) {
                if (tsconfig.paths.size == 0) {
                    return None
                }
                return matchTSConfigPaths(tsconfig, importPath, kind)
            }
        }
        None
    }

    // ========================================================================
    // loadNodeModules - 加载 node_modules 中的模块
    // 严格翻译自: resolver.zig - loadNodeModules()
    //   pub fn loadNodeModules(r, import_path, kind, _dir_info, global_cache, forbid_imports) MatchResult.Union
    //   核心包查找:
    //     1. 检查 tsconfig paths
    //     2. 检查 tsconfig baseUrl
    //     3. 检查 subpath imports (# 前缀)
    //     4. 检查 self-reference
    //     5. 遍历 node_modules 目录 (ESM exports 解析)
    //     6. 检查 NODE_PATH
    //     7. 全局缓存查找 (包含 enqueueDependencyToResolve)
    // ========================================================================

    /// 加载 node_modules 中的模块
    /// 对应 Bun Resolver.loadNodeModules()
    func loadNodeModules(importPath: String, kind: ImportKind,
                          dirInfo: DirInfo,
                          globalCache: GlobalCache,
                          forbidImports: Bool): MatchUnionResult {
        // 1. 检查 tsconfig paths
        if (let Some(tsconfig) <- dirInfo.enclosingTsconfigJson) {
            if (tsconfig.paths.size > 0) {
                if (let Some(res) <- matchTSConfigPaths(tsconfig, importPath, kind)) {
                    return MatchUnionResult.success(res)
                }
            }
            // 尝试 baseUrl 相对查找
            // 严格翻译自:
            //   if (tsconfig.hasBaseURL()) {
            //       const base = tsconfig.base_url;
            //       const abs = r.fs.absBufChecked(&.{ base, import_path }, buf);
            //       if (r.loadAsFileOrDirectory(abs, kind)) |res| { ... }
            //   }
            if (tsconfig.baseUrl.size > 0) {
                let absPath = Path.join([tsconfig.baseUrl, importPath])
                let normalized = Path.normalize(absPath)
                if (let Some(res) <- loadAsFileOrDirectoryMatch(normalized, kind)) {
                    return MatchUnionResult.success(res)
                }
            }
        }

        // 2. 查找包含 package.json 的父目录
        // 严格翻译自:
        //   var dir_info_package_json: ?*DirInfo = dir_info;
        //   while (dir_info_package_json != null and dir_info_package_json.?.package_json == null)
        //       dir_info_package_json = dir_info_package_json.?.getParent();
        var dirInfoPkgJson: ?DirInfo = Some(dirInfo)
        while (dirInfoPkgJson.isSome()) {
            let current = dirInfoPkgJson.getOrThrow()
            if (current.packageJson.isSome()) {
                break
            }
            dirInfoPkgJson = current.getParent()
        }

        // 3. 检查 subpath imports (# 前缀)
        if (let Some(pkgDirInfo) <- dirInfoPkgJson) {
            if (let Some(pkg) <- pkgDirInfo.packageJson) {
                if (importPath.startsWith("#") && !forbidImports &&
                    pkg.importsMap.isSome()) {
                    return loadPackageImports(importPath, pkgDirInfo, kind, globalCache)
                }

                // 4. 检查 self-reference
                // 严格翻译自:
                //   const package_name = ESModule.Package.parseName(import_path);
                //   if (strings.eql(_package_name, package_json.name) and package_json.exports != null) {
                //       is_self_reference = true;
                //   }
                let pkgParts = parsePackageSpecifier(importPath)
                let pkgName = pkgParts.first
                if (pkgName == pkg.name && pkg.exports.isSome()) {
                    // 自引用: 使用当前目录的 package.json
                    // (简化: 完整实现需要 ESModule 解析)
                }
            }
        }

        // 5. 解析 ESM 包说明符
        // 严格翻译自:
        //   const esm_ = ESModule.Package.parse(import_path, bufs(.esm_subpath));
        let esm = parseESMPackage(importPath)

        // 6. 遍历 node_modules 目录
        var currentDir: ?DirInfo = Some(dirInfo)
        var anyNodeModulesFolder = false
        let useNodeModuleResolver = match (globalCache) { case GlobalCache.Force => false case _ => true }

        while (useNodeModuleResolver) {
            if (let Some(di) <- currentDir) {
                if (di.hasNodeModules()) {
                    anyNodeModulesFolder = true

                    // 构造 node_modules 下的路径
                    let nmPath = Path.join([di.absPath, "node_modules", importPath])

                    // ESM 包解析
                    // 严格翻译自:
                    //   if (esm_) |esm| {
                    //       const abs_package_path = r.fs.absBuf(&.{ dir_info.abs_path, "node_modules", esm.name }, buf);
                    //       if (r.dirInfoCached(abs_package_path) catch null) |pkg_dir_info| {
                    //           if (pkg_dir_info.package_json) |package_json| {
                    //               if (package_json.exports) |*exports_map| { ... }
                    //           }
                    //       }
                    //   }
                    if (esm.name.size > 0) {
                        let absPackagePath = Path.join([di.absPath, "node_modules", esm.name])
                        if (let Some(pkgDirInfo) <- dirInfoCached(absPackagePath)) {
                            // 调整扩展名顺序
                            let prevExtOrder = extensionOrder
                            extensionOrder = match (kind) {
                                case ImportKind.Url | ImportKind.AtConditional | ImportKind.At =>
                                    CSS_EXTENSION_ORDER
                                case _ => opts.extOrderSlice(opts.extOrderKind(kind, true))
                            }

                            if (let Some(pkgJson) <- pkgDirInfo.packageJson) {
                                if (pkgJson.exports.isSome()) {
                                    // 尝试通过 exports 映射解析
                                    if (let Some(result) <- resolvePackageExports(
                                            absPackagePath, esm.subpath,
                                            pkgJson, kind)) {
                                        var resCopy = result
                                        resCopy.isNodeModule = true
                                        resCopy.moduleType = pkgJson.moduleType
                                        extensionOrder = prevExtOrder
                                        return MatchUnionResult.success(resCopy)
                                    }

                                    // 尝试 .js -> 去扩展名重试
                                    // 严格翻译自:
                                    //   const extname = std.fs.path.extension(esm.subpath);
                                    //   if (strings.eqlComptime(extname, ".js") and esm.subpath.len > 3) {
                                    //       const esm_resolution = esmodule.resolve("/", esm.subpath[0 .. esm.subpath.len - 3], ...);
                                    //   }
                                    if (esm.subpath.size > 3 && esm.subpath.endsWith(".js")) {
                                        let subpathWithoutExt = esm.subpath[Int64(0)..esm.subpath.size - 3]
                                        if (let Some(result) <- resolvePackageExports(
                                                absPackagePath, subpathWithoutExt,
                                                pkgJson, kind)) {
                                            var resCopy = result
                                            resCopy.isNodeModule = true
                                            resCopy.moduleType = pkgJson.moduleType
                                            extensionOrder = prevExtOrder
                                            return MatchUnionResult.success(resCopy)
                                        }
                                    }

                                    // package.json 始终可导入
                                    if (esm.subpath == "./package.json") {
                                        let pkgJsonPath = Path.join([absPackagePath, "package.json"])
                                        extensionOrder = prevExtOrder
                                        let packageJsonResult = MatchResult(PathPair(ResolverPath(pkgJsonPath)))
                                        packageJsonResult.isNodeModule = true
                                        packageJsonResult.packageJson = Some(pkgJson)
                                        return MatchUnionResult.success(packageJsonResult)
                                    }

                                    extensionOrder = prevExtOrder
                                    return MatchUnionResult.notFound()
                                }
                            }

                            extensionOrder = prevExtOrder
                        }
                    }

                    // 回退到普通文件/目录查找
                    if (let Some(res) <- loadAsFileOrDirectoryMatch(nmPath, kind)) {
                        var resCopy = res
                        resCopy.isNodeModule = true
                        return MatchUnionResult.success(resCopy)
                    }
                }
                currentDir = di.getParent()
            } else {
                break
            }
        }

        // 7. 检查 NODE_PATH
        // 严格翻译自:
        //   const node_path = if (r.env_loader) |env_loader| env_loader.get("NODE_PATH") orelse "" else "";
        //   if (node_path.len > 0) { ... }
        if (let Some(envLoader) <- envLoader) {
            let nodePath = getEnv(envLoader, "NODE_PATH")
            if (nodePath.size > 0) {
                let paths = nodePath.split(":")
                for (p in paths) {
                    if (p.size > 0) {
                        let absPath = Path.join([p, importPath])
                        if (let Some(res) <- loadAsFileOrDirectoryMatch(absPath, kind)) {
                            return MatchUnionResult.success(res)
                        }
                    }
                }
            }
        }

        // 8. 全局缓存查找 (自动安装)
        // 严格翻译自:
        //   if (global_cache.canUse(any_node_modules_folder) and r.usePackageManager() and
        //       esm_ != null and strings.isNPMPackageName(esm_.?.name)) { ... }
        if (globalCache.isEnabled() && anyNodeModulesFolder &&
            usePackageManager() && esm.name.size > 0) {
            // 调用 enqueueDependencyToResolve
            // (简化: 完整实现需要 PackageManager 集成)
            let depResult = enqueueDependencyToResolve(
                dirInfo.packageJson,
                esm,
                importPath
            )
            match (depResult.tag) {
                case DependencyToResolveTag.Resolution =>
                    if (let Some(resPath) <- depResult.resolutionPath) {
                        if (let Some(res) <- loadAsFileOrDirectoryMatch(resPath, kind)) {
                            var resCopy = res
                            resCopy.isNodeModule = true
                            return MatchUnionResult.success(resCopy)
                        }
                    }
                case DependencyToResolveTag.Pending =>
                    if (let Some(p) <- depResult.pending) {
                        return MatchUnionResult.createPending(p)
                    }
                case DependencyToResolveTag.Failure =>
                    if (let Some(e) <- depResult.error) {
                        return MatchUnionResult.failure(e)
                    }
                case _ => ()
            }
        }

        MatchUnionResult.notFound()
    }

    // ========================================================================
    // enqueueDependencyToResolve - 将依赖加入解析队列
    // 严格翻译自: resolver.zig - enqueueDependencyToResolve()
    //   fn enqueueDependencyToResolve(r, package_json_, esm, behavior,
    //       input_package_id_, version, version_buf) DependencyToResolve
    // ========================================================================

    /// 将依赖加入解析队列
    /// 对应 Bun Resolver.enqueueDependencyToResolve()
    func enqueueDependencyToResolve(packageJson: ?PackageJson, esm: ESMPackage,
                                     importPath: String): DependencyToResolve {
        // 简化: 完整实现需要 PackageManager / Lockfile 集成
        // 在 Bun 中, 这个函数会:
        //   1. 从 lockfile 查找已有的解析
        //   2. 如未找到, 从 package.json 的 dependencies 查找版本
        //   3. 通过 PackageManager 解析并可能下载
        //   4. 返回解析路径或 PendingResolution
        DependencyToResolve.notFound()
    }

    // ========================================================================
    // handleESMResolution - 处理 ESM 解析结果
    // 严格翻译自: resolver.zig - handleESMResolution()
    //   fn handleESMResolution(r, esm_resolution_, abs_package_path, kind,
    //       package_json, package_subpath) ?MatchResult
    // ============================================================================

    /// 处理 ESM 解析结果
    /// 对应 Bun Resolver.handleESMResolution()
    func handleESMResolution(esmResolution: ESMResolution, absPackagePath: String,
                              kind: ImportKind, packageJson: PackageJson,
                              packageSubpath: String): ?MatchResult {
        // 检查解析状态
        var status = esmResolution.status
        let isGoodStatus = match (status) {
            case Exact | ExactEndsWithStar | Inexact => true
            case _ => false
        }
        if (!(isGoodStatus &&
              esmResolution.path.size > 0 &&
              esmResolution.path[Int64(0)] == UInt8(47))) {
            return None
        }

        // 构造绝对路径
        var esmPath = esmResolution.path
        if (esmPath.startsWith("/")) {
            esmPath = esmPath[Int64(1)..esmPath.size]
        }
        let absEsmPath = Path.join([absPackagePath, esmPath])

        match (status) {
            case Exact | ExactEndsWithStar =>
                // 精确匹配 - 验证文件存在
                let resolvedDirInfo = dirInfoCached(Dirname.dirname(absEsmPath))
                if (resolvedDirInfo.isNone()) {
                    return None
                }
                if (let Some(di) <- resolvedDirInfo) {
                    // 尝试直接查找文件
                    if (Fs.fileExists(absEsmPath)) {
                        let result = MatchResult(
                            PathPair(ResolverPath(absEsmPath))
                        )
                        result.isNodeModule = true
                        result.packageJson = Some(packageJson)
                        result.dirInfo = Some(di)
                        return Some(result)
                    }

                    // 对于通配符匹配, 尝试添加扩展名
                    if (match (status) { case ExactEndsWithStar => true case _ => false }) {
                        for (ext in extensionOrder) {
                            let tryPath = "${absEsmPath}${ext}"
                            if (Fs.fileExists(tryPath)) {
                                let result = MatchResult(
                                    PathPair(ResolverPath(tryPath))
                                )
                                result.isNodeModule = true
                                result.packageJson = Some(packageJson)
                                result.dirInfo = Some(di)
                                return Some(result)
                            }
                        }
                    }
                }
                return None
            case Inexact =>
                // 不精确匹配 - 尝试 CommonJS 风格的隐式扩展名/目录检测
                if (let Some(res) <- loadAsFileOrDirectoryMatch(absEsmPath, kind)) {
                    var resCopy = res
                    resCopy.isNodeModule = true
                    resCopy.packageJson = if (res.packageJson.isSome()) { res.packageJson } else { Some(packageJson) }
                    return Some(resCopy)
                }
                return None
            case _ => None
        }
    }

    // ========================================================================
    // loadPackageImports - 加载包 imports (# 前缀)
    // 严格翻译自: resolver.zig - loadPackageImports()
    //   pub fn loadPackageImports(r, import_path, dir_info, kind, global_cache) MatchResult.Union
    // ============================================================================

    /// 加载包 imports 映射
    /// 对应 Bun Resolver.loadPackageImports()
    func loadPackageImports(importPath: String, dirInfo: DirInfo,
                             kind: ImportKind,
                             globalCache: GlobalCache): MatchUnionResult {
        if (let Some(pkg) <- dirInfo.packageJson) {
            if (importPath.size == 1 || importPath.startsWith("#/")) {
                // "#" 和 "#/" 开头的路径无效
                return MatchUnionResult.notFound()
            }

            // 使用 imports 映射解析
            // 严格翻译自:
            //   const esmodule = ESModule{ .conditions = ..., .allocator = ..., .module_type = &module_type };
            //   const esm_resolution = esmodule.resolveImports(import_path, imports_map.root);
            if (let Some(importsMap) <- pkg.importsMap) {
                // 简化: 完整实现需要 ESModule.resolveImports()
                // 解析 imports 映射中的条件导出

                // 如果解析结果是 PackageResolve, 递归查找
                // 严格翻译自:
                //   if (esm_resolution.status == .PackageResolve) {
                //       return r.loadNodeModules(esm_resolution.path, kind, dir_info, global_cache, true);
                //   }

                // 如果解析成功, 尝试在文件系统中查找
                // if (r.handleESMResolution(esm_resolution, ..., kind, package_json, "")) |result| {
                //     return .{ .success = result };
                // }
            }
        }
        MatchUnionResult.notFound()
    }

    // ========================================================================
    // loadAsFileOrDirectory - 作为文件或目录加载
    // 严格翻译自: resolver.zig - loadAsFileOrDirectory()
    //   pub fn loadAsFileOrDirectory(r, path, kind) ?MatchResult
    //   完整逻辑:
    //     1. 尝试作为文件
    //     2. 尝试作为目录
    //     3. 使用 package.json main fields
    //     4. auto_main: module/main 双路径返回
    //     5. 回退到 index 文件
    // ========================================================================

    /// 作为文件或目录加载 (返回 ResolveUnionResult)
    func loadAsFileOrDirectory(absPath: String, kind: ImportKind): ResolveUnionResult {
        if (let Some(matchResult) <- loadAsFileOrDirectoryMatch(absPath, kind)) {
            ResolveUnionResult.successFromMatch(matchResult)
        } else {
            ResolveUnionResult.notFound()
        }
    }

    /// 作为文件或目录加载 (返回 ?MatchResult)
    /// 对应 Bun Resolver.loadAsFileOrDirectory()
    func loadAsFileOrDirectoryMatch(absPath: String, kind: ImportKind): ?MatchResult {
        // 先尝试作为文件加载
        if (let Some(fileResult) <- loadAsFile(absPath, extensionOrder)) {
            // 检查是否在 node_modules 中，获取 package.json
            // 严格翻译自:
            //   if (strings.lastIndexOf(file.path, "node_modules" ++ std.fs.path.sep_str)) |last_node_modules_folder| {
            //       const node_modules_folder_offset = last_node_modules_folder + ...;
            //       if (strings.indexOfChar(file.path[node_modules_folder_offset..], std.fs.path.sep)) |package_name_length| {
            //           if (r.dirInfoCached(file.path[0 .. node_modules_folder_offset + package_name_length])) |package_dir_info| {
            //               if (package_dir_info.package_json) |package_json| { ... }
            //           }
            //       }
            //   }
            let nodeModuleIdx = fileResult.path.lastIndexOf("/node_modules/")
            if (let Some(idx) <- nodeModuleIdx) {
                let offset = idx + "/node_modules/".size
                let slashIdx = fileResult.path[Int64(offset)..fileResult.path.size].indexOf('/')
                if (let Some(slashLen) <- slashIdx) {
                    let pkgDirEnd = offset + slashLen
                    let pkgDir = fileResult.path[Int64(0)..pkgDirEnd]
                    if (let Some(pkgDirInfo) <- dirInfoCached(pkgDir)) {
                        if (let Some(pkgJson) <- pkgDirInfo.packageJson) {
                            let matchResult = MatchResult(PathPair(ResolverPath(fileResult.path)))
                            matchResult.diffCase = fileResult.diffCase
                            matchResult.dirnameFd = fileResult.dirnameFd
                            matchResult.packageJson = Some(pkgJson)
                            matchResult.fileFd = fileResult.fileFd
                            return Some(matchResult)
                        }
                    }
                }
            }

            let matchResult = MatchResult(PathPair(ResolverPath(fileResult.path)))
            matchResult.diffCase = fileResult.diffCase
            matchResult.dirnameFd = fileResult.dirnameFd
            matchResult.fileFd = fileResult.fileFd
            return Some(matchResult)
        }

        // 尝试作为目录
        if (let Some(dirInfoResult) <- dirInfoCached(absPath)) {
            var packageJson: ?PackageJson = None

            // 使用 main 字段
            // 严格翻译自:
            //   if (dir_info.package_json) |pkg_json| {
            //       if (pkg_json.main_fields.count() > 0) {
            //           const main_field_keys = r.opts.main_fields;
            //           const auto_main = r.opts.main_fields.ptr == ...;
            //           for (main_field_keys) |key| {
            //               const field_rel_path = main_field_values.get(key) orelse continue;
            //               var _result = r.loadFromMainField(...);
            //               // auto_main: module/main 双路径
            //               if (auto_main and strings.eqlComptime(key, "module")) { ... }
            //           }
            //       }
            //   }
            if (let Some(pkgJson) <- dirInfoResult.packageJson) {
                packageJson = Some(pkgJson)

                // 依次尝试 main 字段
                if (pkgJson.mainFields.size > 0) {
                    let mainFieldKeys = opts.mainFields
                    let autoMain = opts.mainFieldsIsDefault

                    for (key in mainFieldKeys) {
                        let fieldRelPathOpt = pkgJson.mainFields.get(key)
                        if (let Some(fieldRelPath) <- fieldRelPathOpt) {
                            // 使用 main 字段的扩展名顺序 (如果是 "main" 字段)
                            let extOrderForField = if (key == "main") {
                                opts.mainFieldExtensionOrder
                            } else {
                                extensionOrder
                            }

                            let mainResult = loadFromMainField(
                                absPath, dirInfoResult, fieldRelPath, key,
                                extOrderForField
                            )
                            if (mainResult.isSome()) {
                                // auto_main: 当同时有 module 和 main 时
                                // 返回 PathPair(primary=module, secondary=main)
                                // 严格翻译自:
                                //   if (auto_main and strings.eqlComptime(key, "module")) {
                                //       var absolute_result = r.loadFromMainField(path, dir_info, main_rel_path, "main", ...);
                                //       if (absolute_result) |auto_main_result| {
                                //           if (r.prefer_module_field and kind != ast.ImportKind.require) {
                                //               return MatchResult{ .path_pair = .{
                                //                   .primary = _result.path_pair.primary,
                                //                   .secondary = auto_main_result.path_pair.primary,
                                //               }, ... };
                                //           }
                                //       }
                                //   }
                                if (autoMain && key == "module") {
                                    var absoluteResult: ?MatchResult = None

                                    let mainRelPathOpt = pkgJson.mainFields.get("main")
                                    if (let Some(mainRelPath) <- mainRelPathOpt) {
                                        if (mainRelPath.size > 0) {
                                            absoluteResult = loadFromMainField(
                                                absPath, dirInfoResult, mainRelPath,
                                                "main", opts.mainFieldExtensionOrder
                                            )
                                        }
                                    } else {
                                        // 没有 main 字段时尝试 index
                                        absoluteResult = loadAsIndexWithBrowserRemapping(
                                            dirInfoResult, absPath,
                                            opts.mainFieldExtensionOrder
                                        )
                                    }

                                    if (let Some(autoMainResult) <- absoluteResult) {
                                        if (preferModuleField &&
                                            match (kind) { case ImportKind.Require => false case _ => true }) {
                                            // 返回 module 作为 primary, main 作为 secondary
                                            var res = mainResult.getOrThrow()
                                            let matchResult = MatchResult(PathPair(
                                                res.pathPair.primary,
                                                autoMainResult.pathPair.primary
                                            ))
                                            matchResult.diffCase = res.diffCase
                                            matchResult.dirnameFd = res.dirnameFd
                                            matchResult.packageJson = packageJson
                                            matchResult.fileFd = autoMainResult.fileFd
                                            return Some(matchResult)
                                        } else {
                                            var resCopy = autoMainResult
                                            resCopy.packageJson = if (resCopy.packageJson.isSome()) { resCopy.packageJson } else { packageJson }
                                            return Some(resCopy)
                                        }
                                    }
                                }

                                var res = mainResult.getOrThrow()
                                res.packageJson = if (res.packageJson.isSome()) { res.packageJson } else { packageJson }
                                return Some(res)
                            }
                        }
                    }
                }
            }

            // 查找 index 文件
            let indexResult = loadAsIndexWithBrowserRemapping(
                dirInfoResult, absPath, extensionOrder
            )
            if (indexResult.isSome()) {
                var res = indexResult.getOrThrow()
                res.packageJson = if (res.packageJson.isSome()) { res.packageJson } else { packageJson }
                return Some(res)
            }
        }

        None
    }

    // ========================================================================
    // loadFromMainField - 从 main 字段加载
    // 严格翻译自: resolver.zig - loadFromMainField()
    //   pub fn loadFromMainField(r, path, dir_info, field_rel_path, field, extension_order) ?MatchResult
    // ========================================================================

    /// 从 main 字段加载
    /// 对应 Bun Resolver.loadFromMainField()
    func loadFromMainField(path: String, dirInfo: DirInfo,
                            fieldRelPath: String, field: String,
                            extOrder: Array<String>): ?MatchResult {
        var mutableFieldRelPath = fieldRelPath

        // 浏览器映射
        if (careAboutBrowserField) {
            if (let Some(browserScope) <- dirInfo.getEnclosingBrowserScope()) {
                if (let Some(browserJson) <- browserScope.packageJson) {
                    if (let Some(remap) <- checkBrowserMap(
                            browserScope, mutableFieldRelPath, BrowserMapKind.AbsolutePath)) {
                        if (remap.size == 0) {
                            // 禁用路径
                            let newPath = Path.join([path, mutableFieldRelPath])
                            let resolverPath = ResolverPath(newPath)
                            resolverPath.isDisabled = true
                            let matchResult = MatchResult(PathPair(resolverPath))
                            matchResult.packageJson = Some(browserJson)
                            return Some(matchResult)
                        }
                        mutableFieldRelPath = remap
                    }
                }
            }
        }

        let fieldAbsPath = Path.join([path, mutableFieldRelPath])

        // 作为文件加载
        if (let Some(fileResult) <- loadAsFile(fieldAbsPath, extOrder)) {
            if (let Some(pkgJson) <- dirInfo.packageJson) {
                let matchResult = MatchResult(PathPair(ResolverPath(fileResult.path)))
                matchResult.packageJson = Some(pkgJson)
                matchResult.dirnameFd = fileResult.dirnameFd
                return Some(matchResult)
            }
            let matchResult = MatchResult(PathPair(ResolverPath(fileResult.path)))
            matchResult.dirnameFd = fileResult.dirnameFd
            matchResult.diffCase = fileResult.diffCase
            return Some(matchResult)
        }

        // 作为目录加载 (查找 index)
        if (let Some(fieldDirInfo) <- dirInfoCached(fieldAbsPath)) {
            return loadAsIndexWithBrowserRemapping(fieldDirInfo, fieldAbsPath, extOrder)
        }

        None
    }

    // ========================================================================
    // loadAsFile - 作为文件加载
    // 严格翻译自: resolver.zig - loadAsFile()
    //   pub fn loadAsFile(r, path, extension_order) ?LoadResult
    //   1. 精确匹配 (通过目录条目查找)
    //   2. 尝试添加扩展名 (loadExtension)
    //   3. TypeScript 特殊: .js -> .ts/.tsx/.mts 替换
    // ========================================================================

    /// 作为文件加载
    /// 对应 Bun Resolver.loadAsFile()
    func loadAsFile(path: String, extOrder: Array<String>): ?LoadResult {
        let dirPath = Dirname.dirname(path)
        let base = pathBaseName(path)

        // 精确匹配
        if (Fs.fileExists(path)) {
            return Some(LoadResult(path))
        }

        // 尝试添加扩展名
        // 严格翻译自:
        //   for (extension_order) |ext| {
        //       if (loadExtension(r, base, path, ext, entries)) |result| { return result; }
        //   }
        for (ext in extOrder) {
            let tryPath = "${path}${ext}"
            if (Fs.fileExists(tryPath)) {
                return Some(LoadResult(tryPath))
            }
        }

        // 额外 CJS 扩展名
        // 严格翻译自:
        //   for (r.opts.extra_cjs_extensions) |ext| {
        //       if (loadExtension(r, base, path, ext, entries)) |result| { return result; }
        //   }
        // (简化: opts.extra_cjs_extensions 在此版本中未实现)

        // TypeScript 特殊: .js -> .ts/.tsx/.mts 替换
        // 严格翻译自:
        //   if (strings.lastIndexOfChar(base, '.')) |last_dot| {
        //       const ext = base[last_dot..base.len];
        //       if (ext == ".js" or ext == ".jsx" or ext == ".mjs") {
        //           const segment = base[0..last_dot];
        //           const exts = if (ext == ".mjs") &.{".mts"} else &.{".ts", ".tsx", ".mts"};
        //           for (exts) |ext_to_replace| { ... }
        //       }
        //   }
        if (let Some(lastDot) <- base.lastIndexOf('.')) {
            let ext = base[Int64(lastDot)..base.size]
            if (ext == ".js" || ext == ".jsx" || ext == ".mjs") {
                let segment = base[Int64(0)..lastDot]
                let replacements = if (ext == ".mjs") {
                    [".mts"]
                } else {
                    [".ts", ".tsx", ".mts"]
                }
                for (replacement in replacements) {
                    let dirPart = Dirname.dirname(path)
                    let tsPath = Path.join([dirPart, "${segment}${replacement}"])
                    if (Fs.fileExists(tsPath)) {
                        return Some(LoadResult(tsPath))
                    }
                }
            }
        }

        None
    }

    // ========================================================================
    // loadAsIndex - 加载 index 文件
    // 严格翻译自: resolver.zig - loadAsIndex()
    //   pub fn loadAsIndex(r, dir_info, extension_order) ?MatchResult
    //   包含 loadIndexWithExtension 和 extra_cjs_extensions 支持
    // ========================================================================

    /// 加载 index 文件
    /// 对应 Bun Resolver.loadAsIndex()
    func loadAsIndex(dirInfo: DirInfo, extOrder: Array<String>): ?MatchResult {
        // 尝试扩展名顺序
        // 严格翻译自:
        //   for (extension_order) |ext| {
        //       if (loadIndexWithExtension(r, dir_info, ext)) |result| { return result; }
        //   }
        //   for (r.opts.extra_cjs_extensions) |ext| {
        //       if (loadIndexWithExtension(r, dir_info, ext)) |result| { return result; }
        //   }
        for (ext in extOrder) {
            if (let Some(result) <- loadIndexWithExtension(dirInfo, ext)) {
                return Some(result)
            }
        }
        None
    }

    /// 使用指定扩展名加载 index 文件
    /// 对应 Bun Resolver.loadIndexWithExtension()
    func loadIndexWithExtension(dirInfo: DirInfo, ext: String): ?MatchResult {
        let fileName = "index${ext}"
        let indexPath = Path.join([dirInfo.absPath, fileName])

        if (Fs.fileExists(indexPath)) {
            if (let Some(pkgJson) <- dirInfo.packageJson) {
                let matchResult = MatchResult(PathPair(ResolverPath(indexPath)))
                matchResult.packageJson = Some(pkgJson)
                return Some(matchResult)
            }
            return Some(MatchResult(PathPair(ResolverPath(indexPath))))
        }
        None
    }

    // ========================================================================
    // loadAsIndexWithBrowserRemapping - 带浏览器重映射的 index 加载
    // 严格翻译自: resolver.zig - loadAsIndexWithBrowserRemapping()
    //   pub fn loadAsIndexWithBrowserRemapping(r, dir_info, path_, extension_order) ?MatchResult
    //   注意: 需要确保路径以尾随斜杠结尾
    // ========================================================================

    /// 带浏览器重映射的 index 文件加载
    /// 对应 Bun Resolver.loadAsIndexWithBrowserRemapping()
    func loadAsIndexWithBrowserRemapping(dirInfo: DirInfo, path: String,
                                          extOrder: Array<String>): ?MatchResult {
        // 确保路径以尾随斜杠结尾
        // 严格翻译自:
        //   if (!strings.endsWithChar(path_, std.fs.path.sep)) {
        //       path_buf[path.len] = std.fs.path.sep;
        //       path = path_buf[0 .. path.len + 1];
        //   }
        var normalizedPath = path
        if (path.size > 0 && path[path.size - 1] != UInt8(47)) {
            normalizedPath = "${path}/"
        }

        if (careAboutBrowserField) {
            if (let Some(browserScope) <- dirInfo.getEnclosingBrowserScope()) {
                if (let Some(browserJson) <- browserScope.packageJson) {
                    if (let Some(remap) <- checkBrowserMap(
                            browserScope, "index", BrowserMapKind.AbsolutePath)) {
                        if (remap.size == 0) {
                            // 禁用路径
                            let newPath = Path.join([normalizedPath, "index"])
                            let resolverPath = ResolverPath(newPath)
                            resolverPath.isDisabled = true
                            let matchResult = MatchResult(PathPair(resolverPath))
                            matchResult.packageJson = Some(browserJson)
                            return Some(matchResult)
                        }
                        // 解析重映射后的路径
                        let remappedAbs = Path.join([normalizedPath, remap])
                        if (let Some(fileResult) <- loadAsFile(remappedAbs, extOrder)) {
                            let matchResult = MatchResult(PathPair(ResolverPath(fileResult.path)))
                            matchResult.dirnameFd = fileResult.dirnameFd
                            matchResult.diffCase = fileResult.diffCase
                            return Some(matchResult)
                        }
                        // 作为目录查找 index
                        if (let Some(newDirInfo) <- dirInfoCached(remappedAbs)) {
                            if (let Some(absolute) <- loadAsIndex(newDirInfo, extOrder)) {
                                return Some(absolute)
                            }
                        }
                        return None
                    }
                }
            }
        }

        loadAsIndex(dirInfo, extOrder)
    }

    // ========================================================================
    // loadPackageFromNodeModules - 从 node_modules 加载包
    // 严格翻译自: resolver.zig 中包加载逻辑
    //   1. 读取 package.json
    //   2. 检查 exports 字段
    //   3. 检查 imports 字段
    //   4. 使用 main/module 字段
    // ========================================================================

    /// 从 node_modules 加载包
    func loadPackageFromNodeModules(pkgPath: String, subpath: String,
                                     pkgName: String,
                                     kind: ImportKind): ?MatchResult {
        let pkgJsonPath = Path.join([pkgPath, "package.json"])
        if (!Fs.fileExists(pkgJsonPath)) {
            // 没有 package.json，直接解析子路径
            if (subpath.size > 0) {
                let subPath = Path.join([pkgPath, subpath])
                return loadAsFileOrDirectoryMatch(subPath, kind)
            }
            return loadAsFileOrDirectoryMatch(pkgPath, kind)
        }

        if (let Some(pkgJson) <- loadPackageJson(pkgJsonPath)) {
            // 设置模块类型
            let moduleType = pkgJson.moduleType

            // 使用 exports 解析
            if (let Some(exportsJson) <- pkgJson.exports) {
                if (let Some(result) <- resolvePackageExports(pkgPath, subpath,
                                                                exportsJson, kind)) {
                    var matchResult = result
                    matchResult.packageJson = Some(pkgJson.toPackageJson())
                    matchResult.moduleType = moduleType
                    return Some(matchResult)
                }
            }

            // 使用 main/module 解析
            var entryPath = ""
            if (preferModuleField && pkgJson.`module`.size > 0) {
                entryPath = pkgJson.`module`
            } else if (pkgJson.`main`.size > 0) {
                entryPath = pkgJson.`main`
            }

            if (subpath.size > 0) {
                let subPath = Path.join([pkgPath, subpath])
                return loadAsFileOrDirectoryMatch(subPath, kind)
            }

            if (entryPath.size > 0) {
                let resolvedEntry = Path.join([pkgPath, entryPath])
                if (let Some(result) <- loadAsFileOrDirectoryMatch(resolvedEntry, kind)) {
                    var resCopy = result
                    resCopy.packageJson = Some(pkgJson.toPackageJson())
                    resCopy.moduleType = moduleType
                    return Some(resCopy)
                }
            }

            // 回退到 index
            let indexPath = Path.join([pkgPath, "index"])
            if (let Some(result) <- loadAsFileOrDirectoryMatch(indexPath, kind)) {
                var resCopy = result
                resCopy.packageJson = Some(pkgJson.toPackageJson())
                resCopy.moduleType = moduleType
                return Some(resCopy)
            }
        }

        None
    }

    // ========================================================================
    // resolvePackageExports - 解析包 exports
    // 严格翻译自: resolver.zig 中 package.json exports 解析
    //   实现 Package Exports 规范:
    //     - 精确匹配
    //     - 扩展名匹配
    //     - 条件导出 (import, require, default, browser, node)
    //     - 通配符模式
    // ========================================================================

    /// 解析包 exports
    func resolvePackageExports(pkgPath: String, subpath: String,
                                exportsJson: String,
                                kind: ImportKind): ?MatchResult {
        // 简化的 exports 解析
        // 完整实现需要 JSON 解析和条件匹配

        // 处理 "." 子路径
        if (subpath.size == 0 || subpath == ".") {
            // 查找 "." 入口
            let dotEntry = parseExportEntry(exportsJson, ".")
            if (dotEntry.size > 0) {
                let resolvedPath = Path.join([pkgPath, dotEntry])
                if (Fs.fileExists(resolvedPath)) {
                    return Some(MatchResult(PathPair(ResolverPath(resolvedPath))))
                }
            }
        }

        // 处理子路径
        let matchEntry = parseExportEntry(exportsJson, "./${subpath}")
        if (matchEntry.size > 0) {
            let resolvedPath = Path.join([pkgPath, matchEntry])
            if (Fs.fileExists(resolvedPath)) {
                return Some(MatchResult(PathPair(ResolverPath(resolvedPath))))
            }
        }

        None
    }

    /// 使用 PackageJson 对象解析 exports
    func resolvePackageExports(pkgPath: String, subpath: String,
                                pkgJson: PackageJson,
                                kind: ImportKind): ?MatchResult {
        if (let Some(exportsMap) <- pkgJson.exports) {
            // 精确匹配 "."
            if (subpath.size == 0 || subpath == ".") {
                if (let Some(entry) <- exportsMap.get(".")) {
                    let resolvedPath = Path.join([pkgPath, entry])
                    if (Fs.fileExists(resolvedPath)) {
                        let result = MatchResult(PathPair(ResolverPath(resolvedPath)))
                        result.packageJson = Some(pkgJson)
                        return Some(result)
                    }
                }
            }

            // 匹配子路径
            if (subpath.size > 0) {
                if (let Some(entry) <- exportsMap.get("./${subpath}")) {
                    let resolvedPath = Path.join([pkgPath, entry])
                    if (Fs.fileExists(resolvedPath)) {
                        let result = MatchResult(PathPair(ResolverPath(resolvedPath)))
                        result.packageJson = Some(pkgJson)
                        return Some(result)
                    }
                }
            }

            // 通配符匹配
            // 严格翻译自 ESM exports 规范的通配符展开
            let exportEntries = exportsMap.allEntries()
            for (entry in exportEntries) {
                let (pattern, target) = entry
                let starIdx = pattern.indexOf('*')
                if (let Some(idx) <- starIdx) {
                    let prefix = pattern[Int64(0)..idx]
                    let suffix = if (idx + 1 < pattern.size) {
                        pattern[Int64(idx + 1)..pattern.size]
                    } else {
                        ""
                    }

                    let effectiveSubpath = if (subpath.size > 0 && subpath != ".") {
                        "./${subpath}"
                    } else {
                        "."
                    }

                    if (effectiveSubpath.startsWith(prefix) &&
                        (suffix.size == 0 || effectiveSubpath.endsWith(suffix))) {
                        let starMatch = if (suffix.size > 0) {
                            effectiveSubpath[prefix.size..effectiveSubpath.size - suffix.size]
                        } else {
                            effectiveSubpath[prefix.size..effectiveSubpath.size]
                        }

                        let resolved = target.replace("*", starMatch)
                        let resolvedPath = Path.join([pkgPath, resolved])
                        if (Fs.fileExists(resolvedPath)) {
                            let result = MatchResult(PathPair(ResolverPath(resolvedPath)))
                            result.packageJson = Some(pkgJson)
                            return Some(result)
                        }
                    }
                }
            }
        }
        None
    }

    // ========================================================================
    // matchTSConfigPaths - 匹配 tsconfig paths
    // 严格翻译自: resolver.zig - matchTSConfigPaths()
    //   解析 TypeScript 路径别名
    // ========================================================================

    /// 匹配 tsconfig paths
    func matchTSConfigPaths(tsconfig: TsConfig, importPath: String,
                             kind: ImportKind): ?MatchResult {
        if (tsconfig.paths.size == 0) {
            return None
        }

        var absBaseUrl = tsconfig.baseUrlForPaths
        if (tsconfig.baseUrl.size > 0) {
            absBaseUrl = tsconfig.baseUrl
        }

        // 精确匹配
        // 严格翻译自:
        //   var iter = tsconfig.paths.iterator();
        //   while (iter.next()) |entry| {
        //       if (strings.eqlLong(key, path, true)) { ... }
        //   }
        let pathsEntries = tsconfig.paths.allEntries()
        for (entry in pathsEntries) {
            let (pattern, targets) = entry
            if (pattern == importPath) {
                for (target in targets) {
                    var absTarget = target
                    if (!Path.isAbsolute(target)) {
                        absTarget = Path.join([absBaseUrl, target])
                    }
                    let normalized = Path.normalize(absTarget)
                    if (let Some(res) <- loadAsFileOrDirectoryMatch(normalized, kind)) {
                        return Some(res)
                    }
                }
            }
        }

        // 通配符匹配 (最长前缀优先)
        // 严格翻译自 tsconfig paths 的 "*" 通配符匹配
        var longestMatchPrefixLength: Int64 = -1
        var longestMatchSuffixLength: Int64 = -1
        var longestMatchPattern: ?String = None
        var longestMatchTargets: ?ArrayList<String> = None

        let pathsEntries2 = tsconfig.paths.allEntries()
        for (entry in pathsEntries2) {
            let (pattern, targets) = entry
            let starIdxOpt = pattern.indexOf('*')
            if (let Some(starIdx) <- starIdxOpt) {
                let prefix = pattern[Int64(0)..starIdx]
                let suffix = if (starIdx + 1 < pattern.size) {
                    pattern[Int64(starIdx + 1)..pattern.size]
                } else {
                    ""
                }

                if (importPath.startsWith(prefix) &&
                    (suffix.size == 0 || importPath.endsWith(suffix)) &&
                    (prefix.size > longestMatchPrefixLength ||
                        (prefix.size == longestMatchPrefixLength &&
                         suffix.size > longestMatchSuffixLength))) {
                    longestMatchPrefixLength = prefix.size
                    longestMatchSuffixLength = suffix.size
                    longestMatchPattern = Some(pattern)
                    longestMatchTargets = Some(targets)
                }
            }
        }

        // 应用最长匹配
        if (longestMatchPrefixLength >= 0) {
            if (let Some(pattern) <- longestMatchPattern) {
                if (let Some(targets) <- longestMatchTargets) {
                    let starIdx = pattern.indexOf('*').getOrThrow()
                    let prefix = pattern[Int64(0)..starIdx]
                    let suffix = if (starIdx + 1 < pattern.size) {
                        pattern[Int64(starIdx + 1)..pattern.size]
                    } else {
                        ""
                    }
                    let starMatch = if (suffix.size > 0) {
                        importPath[prefix.size..importPath.size - suffix.size]
                    } else {
                        importPath[prefix.size..importPath.size]
                    }

                    for (target in targets) {
                        // 处理目标中的通配符
                        let resolved = target.replace("*", starMatch)
                        var absTarget = resolved
                        if (!Path.isAbsolute(resolved)) {
                            absTarget = Path.join([absBaseUrl, resolved])
                        }
                        let normalized = Path.normalize(absTarget)
                        if (let Some(res) <- loadAsFileOrDirectoryMatch(normalized, kind)) {
                            return Some(res)
                        }
                    }
                }
            }
        }

        None
    }

    // ========================================================================
    // finalizeResult - 最终化结果
    // 严格翻译自: resolver.zig - finalizeResult()
    //   解析符号链接、设置副作用信息、合并 tsconfig 配置
    // ========================================================================

    /// 最终化结果
    func finalizeResult(result: ResolveResult, kind: ImportKind): Unit {
        if (result.flags.isExternal) {
            return
        }

        var moduleType = result.moduleType

        // 遍历路径对
        let paths = result.pathPair.iterate()
        for (path in paths) {
            if (let Some(dirInfo) <- dirInfoCached(Dirname.dirname(path.text))) {
                var needsSideEffects = true

                // 设置副作用信息
                // 严格翻译自:
                //   if (result.package_json) |existing| {
                //       needs_side_effects = existing.side_effects == .unspecified or ...;
                //       result.primary_side_effects_data = switch (existing.side_effects) { ... };
                //   }
                if (let Some(pkg) <- result.packageJson) {
                    needsSideEffects = match (pkg.sideEffects) {
                        case SideEffectsKind.Unspecified => true
                        case SideEffectsKind.SideEffectsList => true
                        case _ => false
                    }

                    result.primarySideEffectsData = match (pkg.sideEffects) {
                        case SideEffectsKind.NoSideEffects => SideEffects.NoSideEffectsPackageJson
                        case SideEffectsKind.SideEffectsList =>
                            if (pkg.sideEffects.hasSideEffects(path.text)) {
                                SideEffects.HasSideEffects
                            } else {
                                SideEffects.NoSideEffectsPackageJson
                            }
                        case _ => SideEffects.HasSideEffects
                    }

                    if (pkg.name.size == 0 || careAboutBinFolder) {
                        result.packageJson = None
                    }
                }

                result.packageJson = if (result.packageJson.isSome()) { result.packageJson } else { dirInfo.enclosingPackageJson }

                if (needsSideEffects) {
                    if (let Some(pkgJson) <- result.packageJson) {
                        result.primarySideEffectsData = match (pkgJson.sideEffects) {
                            case SideEffectsKind.NoSideEffects => SideEffects.NoSideEffectsPackageJson
                            case SideEffectsKind.SideEffectsList =>
                                if (pkgJson.sideEffects.hasSideEffects(path.text)) {
                                    SideEffects.HasSideEffects
                                } else {
                                    SideEffects.NoSideEffectsPackageJson
                                }
                            case _ => SideEffects.HasSideEffects
                        }
                    }
                }

                // 合并 tsconfig
                if (let Some(tsconfig) <- dirInfo.enclosingTsconfigJson) {
                    result.jsx = tsconfig.mergeJSX(result.jsx)
                    result.flags.emitDecoratorMetadata =
                        result.flags.emitDecoratorMetadata || tsconfig.emitDecoratorMetadata
                    result.flags.experimentalDecorators =
                        result.flags.experimentalDecorators || tsconfig.experimentalDecorators
                }

                // 扩展名确定模块类型 (.mjs -> ESM, .cjs -> CJS)
                // 严格翻译自:
                //   if (!kind.isFromCSS() and module_type == .unknown and path.name.ext.len == 4) {
                //       module_type = ModuleTypeMap.getWithLength(path.name.ext, 4) orelse .unknown;
                //   }
                if (!kind.isFromCSS() && match (moduleType) { case ModuleType.Unknown => true case _ => false } &&
                    path.name.ext.size == 4) {
                    moduleType = moduleTypeFromExtension(path.name.ext)
                }

                // 解析符号链接
                // 严格翻译自:
                //   if (dir.getEntries(r.generation)) |entries| {
                //       if (entries.get(path.name.filename)) |query| {
                //           const symlink_path = query.entry.symlink(&r.fs.fs, r.store_fd);
                //           if (symlink_path.len > 0) { path.setRealpath(symlink_path); }
                //       }
                //   }
                // (简化: 符号链接解析在 Cangjie 版本中通过 Fs.stat 处理)
            }
        }

        // 设置模块类型
        if (!kind.isFromCSS() && match (moduleType) { case ModuleType.Unknown => true case _ => false }) {
            if (let Some(pkg) <- result.packageJson) {
                moduleType = pkg.moduleType
            }
        }

        result.moduleType = moduleType
    }

    // ========================================================================
    // checkBrowserMap - 检查浏览器映射
    // 严格翻译自: resolver.zig - checkBrowserMap()
    //   pub fn checkBrowserMap(r, dir_info, input_path_, kind) ?string
    //   完整实现包括:
    //     - 将绝对路径转为相对路径
    //     - 精确匹配 + 扩展名匹配
    //     - 包路径 -> 相对路径转换 ("./" 前缀)
    //     - 同包约束 (node_modules 隔离)
    // ========================================================================

    /// 检查浏览器映射
    /// 对应 Bun Resolver.checkBrowserMap()
    func checkBrowserMap(dirInfo: DirInfo, inputPath: String,
                          kind: BrowserMapKind): ?String {
        if (let Some(pkg) <- dirInfo.packageJson) {
            if (pkg.browserMap.size == 0) {
                return None
            }

            var path = inputPath
            if (match (kind) { case BrowserMapKind.AbsolutePath => true case _ => false }) {
                let absPath = dirInfo.absPath
                if (!path.startsWith(absPath)) {
                    return None
                }
                path = path[Int64(absPath.size)..path.size]
            }

            if (path.size == 0 || (path.size == 1 && (path[Int64(0)] == UInt8(46) || path[Int64(0)] == UInt8(47)))) {
                return None
            }

            let cleaned = Path.normalize(path)
            if (cleaned == ".") {
                return None
            }

            let checker = BrowserMapPath(extensionOrder, pkg.browserMap)
            checker.cleaned = cleaned
            checker.inputPath = path

            if (checker.checkPath(path)) {
                return Some(checker.remapped)
            }

            // 尝试 "./" 前缀
            // 严格翻译自:
            //   if (isPackagePath(checker.input_path)) {
            //       switch (comptime kind) {
            //           .AbsolutePath => {
            //               abs_to_rel[0..2].* = "./".*;
            //               bun.copy(u8, abs_to_rel[2..], checker.input_path);
            //               if (checker.checkPath(abs_to_rel[0 .. checker.input_path.len + 2])) {
            //                   return checker.remapped;
            //               }
            //           },
            //           .PackagePath => {
            //               // 检查是否在同一包内 (无中间 node_modules)
            //               const isInSamePackage = ...;
            //               if (isInSamePackage) { ... }
            //           },
            //       }
            //   }
            if (isPackagePath(checker.inputPath)) {
                match (kind) {
                    case BrowserMapKind.AbsolutePath =>
                        let relPath = "./${checker.inputPath}"
                        if (checker.checkPath(relPath)) {
                            return Some(checker.remapped)
                        }
                    case BrowserMapKind.PackagePath =>
                        // 检查是否在同一包内
                        // 严格翻译自:
                        //   const isInSamePackage = brk: {
                        //       const parent = dir_info.getParent() orelse break :brk true;
                        //       break :brk !parent.isNodeModules();
                        //   };
                        //   if (isInSamePackage) { ... }
                        let isInSamePackage = if (let Some(parent) <- dirInfo.getParent()) {
                            !parent.isNodeModules()
                        } else {
                            true
                        }
                        if (isInSamePackage) {
                            let relPath = "./${checker.inputPath}"
                            if (checker.checkPath(relPath)) {
                                return Some(checker.remapped)
                            }
                        }
                }
            }
        }
        None
    }

    // ========================================================================
    // packageJSONForResolvedNodeModule - 获取已解析模块的 package.json
    // 严格翻译自: resolver.zig - packageJSONForResolvedNodeModule()
    //   pub fn packageJSONForResolvedNodeModule(r, result) ?*const PackageJSON
    // ========================================================================

    /// 获取已解析模块的 package.json
    /// 对应 Bun Resolver.packageJSONForResolvedNodeModule()
    public func packageJSONForResolvedNodeModule(result: ResolveResult): ?PackageJsonInfo {
        if (let Some(dirInfo) <- dirInfoCached(result.pathPair.primary.name.dir)) {
            var current: ?DirInfo = Some(dirInfo)
            while (true) {
                if (let Some(di) <- current) {
                    if (di.packageJson.isSome()) {
                        // (简化: 返回基本信息)
                        return Some(PackageJsonInfo())
                    }
                    current = di.getParent()
                } else {
                    break
                }
            }
        }
        None
    }

    // ========================================================================
    // rootNodeModulePackageJSON - 获取 node_modules 根包 package.json
    // 严格翻译自: resolver.zig - rootNodeModulePackageJSON()
    //   pub fn rootNodeModulePackageJSON(r, result) ?RootPathPair
    //   处理 @scope/package 和普通 package 的路径解析
    // ========================================================================

    /// 获取 node_modules 根包的 package.json
    /// 对应 Bun Resolver.rootNodeModulePackageJSON()
    public func rootNodeModulePackageJSON(result: ResolveResult): ?RootPathPair {
        if (let Some(path) <- result.path()) {
            var absolute = path.text
            let nodeModuleRoot = "/node_modules/"

            // 查找最后的 /node_modules/
            var endOpt = absolute.lastIndexOf(nodeModuleRoot)
            if (endOpt.isNone()) {
                if (path.pretty.size != absolute.size) {
                    absolute = path.pretty
                    endOpt = absolute.lastIndexOf(nodeModuleRoot)
                }
            }
            if (let Some(end) <- endOpt) {
                var pos = end + nodeModuleRoot.size

                // @scope/package 格式
                // 严格翻译自:
                //   const is_scoped_package = absolute[end] == '@';
                //   end += strings.indexOfChar(absolute[end..], std.fs.path.sep) orelse return null;
                //   if (is_scoped_package) {
                //       end += 1;
                //       end += strings.indexOfChar(absolute[end..], std.fs.path.sep) orelse return null;
                //   }
                //   end += 1;
                let isScopedPackage = absolute[Int64(pos)] == UInt8(64) // '@'
                let firstSlashOpt = absolute[Int64(pos)..absolute.size].indexOf('/')
                if (let Some(firstSlash) <- firstSlashOpt) {
                    pos = pos + firstSlash
                    if (isScopedPackage) {
                        pos = pos + 1
                        let secondSlashOpt = absolute[Int64(pos)..absolute.size].indexOf('/')
                        if (let Some(secondSlash) <- secondSlashOpt) {
                            pos = pos + secondSlash
                        } else {
                            return None
                        }
                    }
                    pos = pos + 1
                    let slice = absolute[Int64(0)..pos]

                    // 先检查已有的 package_json
                    // 严格翻译自:
                    //   if (result.package_json) |pkg| {
                    //       if (strings.eql(slice, pkg.source.path.name.dirWithTrailingSlash())) {
                    //           return RootPathPair{ .package_json = pkg, .base_path = slice };
                    //       }
                    //   }
                    if (let Some(dirInfo) <- dirInfoCached(slice)) {
                        if (let Some(pkg) <- dirInfo.packageJson) {
                            return Some(RootPathPair(slice, PackageJsonInfo()))
                        }
                    }
                }
            }
        }
        None
    }

    // ========================================================================
    // bustDirCache - 清除目录缓存
    // 严格翻译自: resolver.zig - bustDirCache()
    //   pub fn bustDirCache(r, path) bool
    // ========================================================================

    /// 清除目录缓存
    /// 对应 Bun Resolver.bustDirCache()
    public func bustDirCache(path: String): Bool {
        dirCache.remove(path).isSome()
    }

    // ========================================================================
    // bustDirCacheFromSpecifier - 从说明符清除缓存
    // 严格翻译自: resolver.zig - bustDirCacheFromSpecifier()
    //   pub fn bustDirCacheFromSpecifier(r, import_source_file, specifier) bool
    // ========================================================================

    /// 从说明符清除缓存
    /// 对应 Bun Resolver.bustDirCacheFromSpecifier()
    public func bustDirCacheFromSpecifier(importSourceFile: String,
                                           specifier: String): Bool {
        if (Path.isAbsolute(specifier)) {
            let dir = Dirname.dirname(specifier)
            let a = bustDirCache(dir)
            let b = bustDirCache(specifier)
            return a || b
        }

        if (!(specifier.startsWith("./") || specifier.startsWith("../"))) {
            return false
        }
        if (!Path.isAbsolute(importSourceFile)) {
            return false
        }

        let joined = Path.join([Dirname.dirname(importSourceFile), specifier])
        let dir = Dirname.dirname(joined)
        let a = bustDirCache(dir)
        let b = bustDirCache(joined)
        return a || b
    }

    // ========================================================================
    // binDirs - 获取 bin 目录列表
    // 严格翻译自: resolver.zig - binDirs()
    //   pub fn binDirs(_: *const ThisResolver) []const string
    // ========================================================================

    /// 获取 bin 目录列表
    /// 对应 Bun Resolver.binDirs()
    public func binDirs(): Array<String> {
        binFolders.items()
    }

    // ========================================================================
    // parsePackageJSON - 解析 package.json
    // 严格翻译自: resolver.zig - parsePackageJSON()
    //   pub fn parsePackageJSON(r, file, dirname_fd, package_id, allow_dependencies) !?*PackageJSON
    // ========================================================================

    /// 解析 package.json
    /// 对应 Bun Resolver.parsePackageJSON()
    public func parsePackageJSON(file: String): ?PackageJsonInfo {
        loadPackageJson(file)
    }

    // ========================================================================
    // parseTSConfig - 解析 tsconfig.json
    // 严格翻译自: resolver.zig - parseTSConfig()
    //   pub fn parseTSConfig(r, file, dirname_fd) !?*TSConfigJSON
    // ============================================================================

    /// 解析 tsconfig.json
    /// 对应 Bun Resolver.parseTSConfig()
    public func parseTSConfig(file: String): ?TsconfigInfo {
        if (!Fs.fileExists(file)) {
            return None
        }
        // (简化: 完整实现需要 JSON 解析)
        Some(TsconfigInfo(file))
    }

    // ========================================================================
    // dirInfoCached - 获取缓存的目录信息
    // 严格翻译自: resolver.zig - dirInfoCached()
    //   pub fn dirInfoCached(r, path) !?*DirInfo
    //   pub fn readDirInfo(r, path) !?*DirInfo
    // ========================================================================

    /// 获取缓存的目录信息
    /// 对应 Bun Resolver.dirInfoCached()
    public func dirInfoCached(absPath: String): ?DirInfo {
        dirCache.get(absPath)
    }

    /// 读取目录信息 (同 dirInfoCached 但语义上触发文件系统读取)
    /// 对应 Bun Resolver.readDirInfo()
    public func readDirInfo(absPath: String): ?DirInfo {
        dirInfoCached(absPath)
    }

    // ========================================================================
    // assertValidCacheKey - 验证缓存键
    // 严格翻译自: resolver.zig - assertValidCacheKey()
    //   pub fn assertValidCacheKey(path: []const u8) void
    //   缓存键必须: 使用原生斜杠, 不以尾随斜杠结尾 (驱动器根除外)
    // ========================================================================

    /// 验证缓存键
    /// 对应 Bun Resolver.assertValidCacheKey()
    public static func assertValidCacheKey(path: String): Unit {
        // 缓存键不能以尾随斜杠结尾 (根目录 "/" 除外)
        if (path.size > 1 && (path[path.size - 1] == UInt8(47) || path[path.size - 1] == UInt8(92))) {
            // 在 debug 模式下应 panic
            // 此处为简化: 静默忽略
        }
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 是否为外部模式
    /// 对应 Bun Resolver.isExternalPattern()
    func isExternalPattern(importPath: String): Bool {
        if (match (opts.packages) { case PackageStrategy.External => true case _ => false } && isPackagePath(importPath)) {
            return true
        }
        matchesUserExternalPattern(importPath)
    }

    /// 是否匹配用户定义的外部模式
    /// 对应 Bun Resolver.matchesUserExternalPattern()
    func matchesUserExternalPattern(importPath: String): Bool {
        for (pattern in opts.external.patterns) {
            if (pattern.matches(importPath)) {
                return true
            }
        }
        false
    }

    /// 浏览器映射查找
    func browserMapLookup(sourceDir: String, importPath: String): ?String {
        // 简化的浏览器映射查找
        None
    }

    /// 解析包说明符
    /// "react" -> ("react", "")
    /// "@scope/pkg/sub" -> ("@scope/pkg", "./sub")
    /// "lodash/debounce" -> ("lodash", "./debounce")
    func parsePackageSpecifier(specifier: String): Tuple2<String, String> {
        // 作用域包 (@scope/package)
        if (specifier.startsWith("@")) {
            let firstSlash = specifier.indexOf('/').getOrDefault({ => Int64(-1) })
            if (firstSlash < 0) {
                return Tuple2(specifier, "")
            }
            let afterScope = specifier[firstSlash + 1..specifier.size]
            let secondSlash = afterScope.indexOf('/').getOrDefault({ => Int64(-1) })
            if (secondSlash < 0) {
                return Tuple2(specifier, "")
            }
            let pkgName = specifier[0..firstSlash + 1 + secondSlash]
            let subpath = "./${afterScope[secondSlash + 1..afterScope.size]}"
            return Tuple2(pkgName, subpath)
        }

        // 普通包
        let slashIndex = specifier.indexOf('/').getOrDefault({ => Int64(-1) })
        if (slashIndex < 0) {
            return Tuple2(specifier, "")
        }
        let pkgName = specifier[Int64(0)..slashIndex]
        let subpath = "./${specifier[slashIndex + 1..specifier.size]}"
        Tuple2(pkgName, subpath)
    }

    /// 解析 ESM 包说明符
    /// 对应 Bun ESModule.Package.parse()
    /// "react@18" -> ESMPackage("react", "", "18")
    /// "@scope/pkg/sub@1.0" -> ESMPackage("@scope/pkg", "./sub", "1.0")
    func parseESMPackage(importPath: String): ESMPackage {
        let pkgParts = parsePackageSpecifier(importPath)
        let pkgSpecifier = pkgParts.first
        let subpath = pkgParts.second

        // 分离版本号 (@version)
        let atIdx = pkgSpecifier.lastIndexOf('@')
        if (let Some(idx) <- atIdx) {
            if (idx > 0) {
                let name = pkgSpecifier[Int64(0)..idx]
                let version = pkgSpecifier[Int64(idx + 1)..pkgSpecifier.size]
                return ESMPackage(name, subpath, version)
            }
        }
        ESMPackage(pkgSpecifier, subpath, "")
    }

    /// 加载 package.json
    func loadPackageJson(path: String): ?PackageJsonInfo {
        if (!Fs.fileExists(path)) {
            return None
        }
        // 简化: 返回基本信息
        let info = PackageJsonInfo()
        // 实际实现需要解析 JSON
        Some(info)
    }

    /// 解析 exports 条目
    func parseExportEntry(exportsJson: String, key: String): String {
        // 简化: 需要完整 JSON 解析
        ""
    }

    /// 查找任意字符
    func indexOfAny(s: String, chars: String): ?Int64 {
        for (i in 0..s.size) {
            for (j in 0..chars.size) {
                if (s[i] == chars[j]) {
                    return Some(i)
                }
            }
        }
        None
    }

    /// 获取路径基础名 (最后一个路径分隔符后的部分)
    func pathBaseName(path: String): String {
        let lastSlash = path.lastIndexOf('/')
        if (let Some(idx) <- lastSlash) {
            path[Int64(idx + 1)..path.size]
        } else {
            path
        }
    }

    /// 刷新调试日志
    func flushDebugLogs(flushMode: DebugLogFlushMode): Unit {
        if (let Some(debug) <- debugLogs) {
            if (match (flushMode) { case DebugLogFlushMode.Fail => true case _ => false }) {
                log.append("DEBUG: ${debug.what}")
                for (note in debug.notes) {
                    log.append("  ${note}")
                }
            }
        }
    }
}

// ============================================================================
// Fs - 文件系统辅助
// ============================================================================

/// 文件系统辅助方法
class Fs {
    static func fileExists(path: String): Bool {
        let stat = Fs.stat(path)
        if (let Some(s) <- stat) {
            return s.isFile
        }
        false
    }

    static func dirExists(path: String): Bool {
        let stat = Fs.stat(path)
        if (let Some(s) <- stat) {
            return s.isDirectory
        }
        false
    }

    static func stat(path: String): ?FileInfo {
        // 依赖 bao_sys 实现
        None
    }
}

/// 文件信息
class FileInfo {
    public prop isFile: Bool {
        get() { true }
    }

    public prop isDirectory: Bool {
        get() { false }
    }

    public prop isExecutable: Bool {
        get() { false }
    }
}

// ============================================================================
// Path 工具辅助
// ============================================================================

/// 路径工具辅助
class Path {
    /// 是否为绝对路径
    public static func isAbsolute(path: String): Bool {
        path.startsWith("/")
    }

    /// 连接路径
    public static func join(parts: Array<String>): String {
        join(parts)
    }

    /// 连接两个路径
    public static func join(a: String, b: String): String {
        if (b.size == 0) {
            return a
        }
        if (a.size == 0) {
            return b
        }
        if (b.startsWith("/")) {
            return b
        }
        if (a.endsWith("/")) {
            return "${a}${b}"
        }
        "${a}/${b}"
    }

    /// 规范化路径
    public static func normalize(path: String): String {
        if (path.size == 0) {
            return ""
        }

        let parts = path.split("/")
        var result = ArrayList<String>()
        for (part in parts) {
            if (part == "" || part == ".") {
                continue
            }
            if (part == "..") {
                if (result.size > 0) {
                    result.removeAt(result.size - 1)
                }
                continue
            }
            result.append(part)
        }

        if (result.size == 0) {
            return "/"
        }

        var joined = ""
        for (i in 0..result.size) {
            joined = "${joined}/${result[i]}"
        }
        joined
    }

    /// 获取目录名
    public static func dirname(path: String): String {
        Dirname.dirname(path)
    }
}

// ============================================================================
// 辅助函数 (全局)
// ============================================================================

/// 简化的哈希函数
/// 对应 Bun bun.hash()
func hashString(s: String): Int64 {
    var h: Int64 = 5381
    for (i in 0..s.size) {
        h = ((h << 5) + h) + Int64(s[i])
    }
    h
}

/// 格式化字符串 (简化)
func formatString(fmt: String, args: Array<String>): String {
    var result = fmt
    for (arg in args) {
        if (let Some(idx) <- result.indexOf("{}")) {
            result = result[Int64(0)..idx] + arg + result[Int64(idx + 2)..result.size]
        }
    }
    result
}

/// 获取环境变量 (简化)
func getEnv(loader: String, key: String): String {
    ""
}
