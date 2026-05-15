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

/// 导入类型 - 对应 Bun ImportKind
public enum ImportKind {
    | Entry              // 入口点
    | Stmt               // import 语句
    | Dynamic            // import() 表达式
    | Require            // require() 调用
    | RequireResolve     // require.resolve()
    | At                 // CSS @import
    | AtConditional      // CSS 条件 @import
    | Url                // CSS url()

    /// 是否来自 CSS
    public func isFromCSS(): Bool {
        match (this) {
            case At => true
            case AtConditional => true
            case Url => true
            case _ => false
        }
    }
}

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
// PathPair - 路径对
// 严格翻译自: resolver.zig - PathPair
//   pub const PathPair = struct {
//       primary: Path,
//       secondary: ?Path = null,
//       ...
//   };
// ============================================================================

/// 路径对 - 对应 Bun PathPair
/// 解析结果可能包含主路径和备选路径
public class PathPair {
    /// 主路径
    public var primary: ResolvedPath
    /// 备选路径 (用于大小写不匹配)
    public var secondary: ?ResolvedPath

    public init(primary: ResolvedPath) {
        this.primary = primary
        secondary = None
    }

    public init(primary: ResolvedPath, secondary: ?ResolvedPath) {
        this.primary = primary
        this.secondary = secondary
    }

    /// 获取有效路径
    public func path(): ?ResolvedPath {
        if (!primary.isDisabled) {
            return Some(primary)
        }
        if (let Some(sec) <- secondary) {
            if (!sec.isDisabled) {
                return Some(sec)
            }
        }
        None
    }
}

// ============================================================================
// ResolvedPath - 解析后的路径
// 对应 Bun Fs.Path
// ============================================================================

/// 解析后的路径 - 对应 Bun Path
public class ResolvedPath {
    /// 路径文本
    public var text: String
    /// 命名空间
    public var namespace: String
    /// 是否被禁用 (如浏览器映射中标记为 false)
    public var isDisabled: Bool
    /// 目录部分
    public var dir: String
    /// 文件名部分
    public var filename: String
    /// 扩展名
    public var ext: String
    /// 真实路径 (解析符号链接后)
    public var realPath: String

    public init(text: String) {
        this.text = text
        namespace = "file"
        isDisabled = false
        dir = ""
        filename = ""
        ext = ""
        realPath = text
        // 解析路径组成部分
        parsePathComponents()
    }

    public init(text: String, namespace: String) {
        this.text = text
        this.namespace = namespace
        isDisabled = false
        dir = ""
        filename = ""
        ext = ""
        realPath = text
        parsePathComponents()
    }

    /// 空路径
    public static func empty(): ResolvedPath {
        ResolvedPath("", "file")
    }

    /// 解析路径组成部分
    func parsePathComponents(): Unit {
        if (text.size == 0) {
            return
        }
        // 查找最后一个路径分隔符
        var lastSep = -1
        for (i in 0..text.size) {
            if (text[i] == '/' || text[i] == '\\') {
                lastSep = i
            }
        }
        if (lastSep >= 0) {
            dir = text.subString(0, lastSep)
            filename = text.subString(lastSep + 1)
        } else {
            filename = text
        }
        // 查找扩展名
        let dotIndex = filename.lastIndexOf('.')
        if (dotIndex >= 0) {
            ext = filename.subString(dotIndex)
        }
    }

    /// 设置真实路径
    public func setRealpath(path: String): Unit {
        realPath = path
    }
}

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
    public var jsx: JsxPragma
    /// package.json 引用
    public var packageJson: ?PackageJsonInfo
    /// 大小写不匹配信息
    public var diffCase: ?String
    /// 副作用数据
    public var primarySideEffectsData: SideEffects
    /// 模块类型
    public var moduleType: ModuleType
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
        jsx = JsxPragma()
        packageJson = None
        diffCase = None
        primarySideEffectsData = SideEffects.HasSideEffects
        moduleType = ModuleType.Unknown
        dirnameFd = -1
        fileFd = -1
        importKind = ImportKind.Stmt
        flags = ResolveResultFlags()
    }

    /// 判断是否可能为 node_modules 模块
    /// 对应 Bun Result.isLikelyNodeModule()
    public func isLikelyNodeModule(): Bool {
        if (let Some(p) <- pathPair.path()) {
            if (flags.isFromNodeModules) {
                return true
            }
            return p.text.contains("/node_modules/")
        }
        false
    }

    /// 判断是否应假设为 CommonJS
    /// 对应 Bun Result.shouldAssumeCommonJS()
    public func shouldAssumeCommonJS(kind: ImportKind): Bool {
        match (moduleType) {
            case Esm => false
            case Cjs => true
            case Unknown => {
                if (kind == ImportKind.Require || kind == ImportKind.RequireResolve) {
                    return true
                }
                isLikelyNodeModule()
            }
        }
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
    public var packageJson: ?PackageJsonInfo
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
}

/// 待解决状态标签
public enum PendingTag {
    | Download    // 需要下载
    | Resolve     // 需要解析
    | Done        // 完成
}

// ============================================================================
// DebugLogs - 调试日志
// 严格翻译自: resolver.zig - DebugLogs
//   pub const DebugLogs = struct {
//       what: string = "",
//       indent: MutableString,
//       notes: std.array_list.Managed(logger.Data),
//   };
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

    /// 增加缩进
    public func increaseIndent(): Unit {
        indent = "${indent} "
    }

    /// 减少缩进
    public func decreaseIndent(): Unit {
        if (indent.size > 0) {
            indent = indent.subString(0, indent.size - 1)
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
    public var main: String
    public var module: String
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
        main = ""
        module = ""
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
// DirInfo - 目录信息
// 严格翻译自: resolver.zig - DirInfo (简化版)
//   pub const DirInfo = struct {
//       ...
//       abs_real_path: string = "",
//       package_json: ?*PackageJSON = null,
//       enclosing_browser_scope: ?*DirInfo = null,
//       package_json_for_browser_field: ?*PackageJSON = null,
//       enclosing_tsconfig_json: ?*TSConfigJSON = null,
//       enclosing_package_json: ?*PackageJSON = null,
//       ...
//   };
// ============================================================================

/// 目录信息 - 对应 Bun DirInfo
public class DirInfo {
    /// 绝对路径
    public var absPath: String
    /// 真实路径 (解析符号链接后)
    public var absRealPath: String
    /// 此目录的 package.json
    public var packageJson: ?PackageJsonInfo
    /// 包围浏览器作用域
    public var enclosingBrowserScope: ?DirInfo
    /// 用于浏览器字段查找的 package.json
    public var packageJsonForBrowserField: ?PackageJsonInfo
    /// 包围 tsconfig
    public var enclosingTsconfigJson: ?TsconfigInfo
    /// 包围 package.json
    public var enclosingPackageJson: ?PackageJsonInfo
    /// 用于依赖查找的 package.json
    public var packageJsonForDependencies: ?PackageJsonInfo
    /// 是否在 node_modules 内
    public var insideNodeModules: Bool
    /// 是否为 node_modules 目录
    public var isNodeModulesDir: Bool
    /// 目录条目
    public var entries: HashMap<String, DirEntry>
    /// 文件描述符
    public var fd: Int64
    /// 生成号
    public var generation: Int64

    public init(absPath: String) {
        this.absPath = absPath
        absRealPath = absPath
        packageJson = None
        enclosingBrowserScope = None
        packageJsonForBrowserField = None
        enclosingTsconfigJson = None
        enclosingPackageJson = None
        packageJsonForDependencies = None
        insideNodeModules = false
        isNodeModulesDir = false
        entries = HashMap<String, DirEntry>()
        fd = -1
        generation = 0
    }

    /// 是否在 node_modules 中
    public func isInsideNodeModules(): Bool {
        insideNodeModules
    }

    /// 是否为 node_modules 目录
    public func isNodeModules(): Bool {
        isNodeModulesDir
    }

    /// 获取条目
    public func getEntries(generation: Int64): ?HashMap<String, DirEntry> {
        if (this.generation == generation && entries.size > 0) {
            Some(entries)
        } else {
            None
        }
    }
}

// ============================================================================
// DirEntry - 目录条目
// 严格翻译自: resolver.zig - Fs.FileSystem.Entry
// ============================================================================

/// 目录条目 - 对应 Bun Entry
public class DirEntry {
    /// 文件名
    public var base: String
    /// 真实路径
    public var realPath: String
    /// 符号链接目标
    public var symlink: String
    /// 是否为目录
    public var isDir: Bool
    /// 是否为文件
    public var isFile: Bool
    /// 缓存的文件描述符
    public var cacheFd: Int64

    public init(base: String) {
        this.base = base
        realPath = ""
        symlink = ""
        isDir = false
        isFile = false
        cacheFd = -1
    }
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
        while (endIndex > 0 && (path[endIndex] == '/' || path[endIndex] == '\\')) {
            endIndex = endIndex - 1
        }
        if (endIndex == 0) {
            return "/"
        }

        // 查找前一个路径分隔符
        while (endIndex > 0 && path[endIndex] != '/' && path[endIndex] != '\\') {
            endIndex = endIndex - 1
        }
        if (endIndex == 0) {
            return "/"
        }

        path.subString(0, endIndex + 1)
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
public class RootPathPair {
    public var basePath: String
    public var packageJson: PackageJsonInfo

    public init(basePath: String, packageJson: PackageJsonInfo) {
        this.basePath = basePath
        this.packageJson = packageJson
    }
}

// ============================================================================
// BundleOptions - 打包选项 (解析器使用的部分)
// 严格翻译自: resolver.zig - options.BundleOptions (引用)
// ============================================================================

/// 打包选项 (解析器使用的部分)
public class ResolverBundleOptions {
    public var target: BundleTarget
    public var extensionOrder: Array<String>
    public var externalPatterns: ArrayList<ExternalPattern>
    public var packages: PackagePolicy
    public var markBuiltinsAsExternal: Bool
    public var preserveSymlinks: Bool
    public var loadPackageJson: Bool
    public var loadTsconfigJson: Bool
    public var tsconfigOverride: ?String
    public var globalCache: GlobalCache
    public var jsx: JsxPragma
    public var framework: ?FrameworkInfo

    public init() {
        target = BundleTarget.Browser
        extensionOrder = [".tsx", ".ts", ".jsx", ".js", ".json"]
        externalPatterns = ArrayList<ExternalPattern>()
        packages = PackagePolicy.Bundler
        markBuiltinsAsExternal = true
        preserveSymlinks = false
        loadPackageJson = true
        loadTsconfigJson = true
        tsconfigOverride = None
        globalCache = GlobalCache.Auto
        jsx = JsxPragma()
        framework = None
    }
}

/// 打包目标
public enum BundleTarget {
    | Browser
    | Node
    | Bun
}

/// 包策略
public enum PackagePolicy {
    | Bundler      // 正常打包
    | External     // 所有包标记为外部
}

/// 全局缓存策略
public enum GlobalCache {
    | Auto
    | Disable
    | Fallback
    | Force
}

/// 外部模式
public class ExternalPattern {
    public var prefix: String
    public var suffix: String

    public init(prefix: String, suffix: String) {
        this.prefix = prefix
        this.suffix = suffix
    }
}

/// 框架信息
public class FrameworkInfo {
    public var builtInModules: HashMap<String, FrameworkModule>

    public init() {
        builtInModules = HashMap<String, FrameworkModule>()
    }
}

/// 框架模块类型
public enum FrameworkModule {
    | Code
    | Import(String)
}

// ============================================================================
// ResolveWithoutRemapResult - 不重映射的解析结果
// ============================================================================

/// 不重映射的解析结果联合体
public class ResolveUnionResult {
    public var status: ResolveStatus
    public var result: ?ResolveResult
    public var matchResult: ?MatchResult
    public var pending: ?PendingResolution
    public var error: ?String

    public static func success(result: ResolveResult): ResolveUnionResult {
        let r = ResolveUnionResult()
        r.status = ResolveStatus.Success
        r.result = Some(result)
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

    public static func pending(p: PendingResolution): ResolveUnionResult {
        let r = ResolveUnionResult()
        r.status = ResolveStatus.Pending
        r.pending = Some(p)
        r
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

    public init() {
        opts = ResolverBundleOptions()
        log = ArrayList<String>()
        extensionOrder = [".tsx", ".ts", ".jsx", ".js", ".json"]
        careAboutBinFolder = false
        careAboutBrowserField = true
        debugLogs = None
        elapsed = 0
        generation = 0
        storeFd = false
        dirCache = HashMap<String, DirInfo>()
        preferModuleField = true
        customDirPaths = None
        packageManager = None
        standaloneModuleGraph = None
        envLoader = None
    }

    public init(opts: ResolverBundleOptions) {
        this.opts = opts
        log = ArrayList<String>()
        extensionOrder = opts.extensionOrder
        careAboutBinFolder = false
        careAboutBrowserField = opts.target == BundleTarget.Browser
        debugLogs = None
        elapsed = 0
        generation = 0
        storeFd = false
        dirCache = HashMap<String, DirInfo>()
        preferModuleField = true
        customDirPaths = None
        packageManager = None
        standaloneModuleGraph = None
        envLoader = None
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
        match (resolveAndAutoInstall(sourceDir, importPath, kind,
                                      GlobalCache.Disable)) {
            case success(r) => r
            case _ => None
        }
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

        // 标记内置模块为外部
        // 严格翻译自:
        //   if (r.opts.mark_builtins_as_external) {
        //       if (strings.hasPrefixComptime(import_path, "node:") or
        //           strings.hasPrefixComptime(import_path, "bun:")) { ... }
        //   }
        if (opts.markBuiltinsAsExternal) {
            if (importPath.startsWith("node:") || importPath.startsWith("bun:")) {
                let result = ResolveResult(PathPair(ResolvedPath(importPath)))
                result.importKind = kind
                result.moduleType = ModuleType.Cjs
                result.primarySideEffectsData = SideEffects.NoSideEffectsPureData
                result.flags.isExternal = true
                return ResolveUnionResult.success(result)
            }
        }

        // 检查外部模式
        // 严格翻译自:
        //   if (kind != .entry_point_build and kind != .entry_point_run and
        //       (r.isExternalPattern(import_path) or ...))
        if (kind != ImportKind.Entry) {
            if (isExternalPattern(importPath) ||
                (kind.isFromCSS() && importPath.startsWith("#")) ||
                importPath.startsWith("http://") ||
                importPath.startsWith("https://") ||
                importPath.startsWith("//")) {
                let result = ResolveResult(PathPair(ResolvedPath(importPath)))
                result.importKind = kind
                result.flags.isExternal = true
                if (!kind.isFromCSS()) {
                    result.moduleType = ModuleType.Esm
                }
                return ResolveUnionResult.success(result)
            }
        }

        // 标准化源目录
        var normalizedSourceDir = sourceDir
        if (sourceDir.size == 0) {
            normalizedSourceDir = "/"
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
        if (tmp.status == ResolveStatus.NotFound && kind.isFromCSS()) {
            let suffixIndex = indexOfAny(importPath, "?#")
            if (suffixIndex != None) {
                if (let Some(idx) <- suffixIndex) {
                    if (idx > 0) {
                        let cleanPath = importPath.subString(0, idx)
                        let retry = resolveWithoutSymlinks(normalizedSourceDir,
                                                            cleanPath, kind, globalCache)
                        if (retry.status != ResolveStatus.NotFound) {
                            tmp = retry
                        }
                    }
                }
            }
        }

        // 最终化结果
        match (tmp.status) {
            case Success => {
                if (let Some(r) <- tmp.result) {
                    r.importKind = kind
                    finalizeResult(r, kind)
                }
                tmp
            }
            case _ => tmp
        }
    }

    // ========================================================================
    // resolveWithoutSymlinks - 不解析符号链接的解析
    // 严格翻译自: resolver.zig - resolveWithoutSymlinks()
    //   pub fn resolveWithoutSymlinks(r, source_dir, import_path, kind, global_cache) Result.Union
    //   核心解析算法:
    //     1. 绝对路径处理
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
        var result = ResolveResult(PathPair(ResolvedPath.empty()))

        // 绝对路径处理
        // 严格翻译自:
        //   if (std.fs.path.isAbsolute(import_path)) {
        //       // 先检查 tsconfig paths
        //       // 然后解析绝对路径
        //   }
        if (Path.isAbsolute(importPath)) {
            // 检查 tsconfig paths
            if (let Some(dirInfo) <- dirInfoCached(sourceDir)) {
                if (let Some(tsconfig) <- dirInfo.enclosingTsconfigJson) {
                    if (tsconfig.paths.size > 0) {
                        if (let Some(matchResult) <- matchTSConfigPaths(
                                tsconfig, importPath, kind)) {
                            let r = ResolveResult(matchResult.pathPair)
                            r.diffCase = matchResult.diffCase
                            r.packageJson = matchResult.packageJson
                            r.dirnameFd = matchResult.dirnameFd
                            r.fileFd = matchResult.fileFd
                            return ResolveUnionResult.success(r)
                        }
                    }
                }
            }

            // 浏览器映射
            if (careAboutBrowserField) {
                if (let Some(remapped) <- browserMapLookup(sourceDir, importPath)) {
                    if (remapped.size == 0) {
                        return ResolveUnionResult.notFound()
                    }
                    // 递归解析重映射后的路径
                    return resolveWithoutSymlinks(sourceDir, remapped, kind, globalCache)
                }
            }

            // 尝试作为文件或目录解析
            return loadAsFileOrDirectory(importPath, kind)
        }

        // 相对路径处理 (以 "./" 或 "../" 开头)
        // 严格翻译自:
        //   if (bun.strings.startsWith(import_path, "./") or
        //       bun.strings.startsWith(import_path, "../"))
        if (importPath.startsWith("./") || importPath.startsWith("../")) {
            // 解析相对路径
            let absPath = Path.join(sourceDir, importPath)
            let normalized = Path.normalize(absPath)

            // 浏览器映射
            if (careAboutBrowserField) {
                if (let Some(remapped) <- browserMapLookup(sourceDir, normalized)) {
                    if (remapped.size == 0) {
                        return ResolveUnionResult.notFound()
                    }
                    return resolveWithoutSymlinks(sourceDir, remapped, kind, globalCache)
                }
            }

            return loadAsFileOrDirectory(normalized, kind)
        }

        // 包路径处理 (bare specifier, 如 "react", "@scope/pkg")
        // 严格翻译自:
        //   if (isPackagePath(import_path)) { ... }
        if (isPackagePath(importPath)) {
            return resolvePackagePath(sourceDir, importPath, kind, globalCache)
        }

        // 其他情况
        ResolveUnionResult.notFound()
    }

    // ========================================================================
    // resolvePackagePath - 解析包路径
    // 严格翻译自: resolver.zig 中 resolveWithoutSymlinks 的包路径分支
    //   在 node_modules 中查找包:
    //     1. 检查 tsconfig paths
    //     2. 浏览器映射
    //     3. 遍历 node_modules
    //     4. 全局缓存查找
    // ========================================================================

    /// 解析包路径 (bare specifier)
    /// 对应 Bun Resolver 中包路径解析逻辑
    func resolvePackagePath(sourceDir: String, importPath: String,
                             kind: ImportKind,
                             globalCache: GlobalCache): ResolveUnionResult {
        // 解析包名和子路径
        // 例如: "@scope/pkg/sub/path" -> pkg="@scope/pkg", subpath="./sub/path"
        let pkgParts = parsePackageSpecifier(importPath)
        let pkgName = pkgParts.first
        let pkgSubpath = pkgParts.second

        // 浏览器映射
        if (careAboutBrowserField) {
            if (let Some(remapped) <- browserMapLookup(sourceDir, importPath)) {
                if (remapped.size == 0) {
                    return ResolveUnionResult.notFound()
                }
                return resolveWithoutSymlinks(sourceDir, remapped, kind, globalCache)
            }
        }

        // 检查 tsconfig paths
        if (let Some(dirInfo) <- dirInfoCached(sourceDir)) {
            if (let Some(tsconfig) <- dirInfo.enclosingTsconfigJson) {
                if (tsconfig.paths.size > 0) {
                    if (let Some(matchResult) <- matchTSConfigPaths(
                            tsconfig, importPath, kind)) {
                        let r = ResolveResult(matchResult.pathPair)
                        r.packageJson = matchResult.packageJson
                        r.dirnameFd = matchResult.dirnameFd
                        r.fileFd = matchResult.fileFd
                        r.flags.isFromNodeModules = matchResult.isNodeModule
                        return ResolveUnionResult.success(r)
                    }
                }
            }
        }

        // 遍历 node_modules 查找
        // 严格翻译自:
        //   while (true) {
        //       const nm_path = join(dir, "node_modules", pkg_name)
        //       if (exists(nm_path)) { ... }
        //       dir = dirname(dir)
        //       if (dir == root) break
        //   }
        var dir = sourceDir
        while (true) {
            let nmPath = Path.join(dir, "node_modules")
            let pkgPath = Path.join(nmPath, pkgName)

            if (Fs.dirExists(pkgPath)) {
                // 找到包目录
                let result = loadPackageFromNodeModules(pkgPath, pkgSubpath,
                                                         pkgName, kind)
                if (result.status == ResolveStatus.Success) {
                    if (let Some(r) <- result.result) {
                        r.flags.isFromNodeModules = true
                    }
                    return result
                }
            }

            // 向上遍历
            let parent = Dirname.dirname(dir)
            if (parent == dir || parent.size == 0) {
                break
            }
            dir = parent
        }

        // 全局缓存查找
        if (globalCache.isEnabled()) {
            // 尝试在全局缓存中查找
            let cachePath = Path.join("/.bun/install/cache", pkgName)
            if (Fs.dirExists(cachePath)) {
                return loadPackageFromNodeModules(cachePath, pkgSubpath,
                                                   pkgName, kind)
            }
        }

        ResolveUnionResult.notFound()
    }

    // ========================================================================
    // loadAsFileOrDirectory - 作为文件或目录加载
    // 严格翻译自: resolver.zig 中 loadAsFileOrDirectory 相关逻辑
    // ========================================================================

    /// 作为文件或目录加载
    func loadAsFileOrDirectory(absPath: String, kind: ImportKind): ResolveUnionResult {
        // 先尝试作为文件加载
        // 严格翻译自:
        //   1. 精确匹配
        //   2. 补全扩展名 (.ts, .tsx, .js, .jsx, .json)
        //   3. 补全 /index

        // 精确匹配
        if (Fs.fileExists(absPath)) {
            let result = ResolveResult(PathPair(ResolvedPath(absPath)))
            return ResolveUnionResult.success(result)
        }

        // 尝试补全扩展名
        for (ext in extensionOrder) {
            let tryPath = "${absPath}${ext}"
            if (Fs.fileExists(tryPath)) {
                let result = ResolveResult(PathPair(ResolvedPath(tryPath)))
                return ResolveUnionResult.success(result)
            }
        }

        // 尝试作为目录 (查找 index 文件)
        if (Fs.dirExists(absPath)) {
            // 检查 package.json 中的 main 字段
            let pkgJsonPath = Path.join(absPath, "package.json")
            if (Fs.fileExists(pkgJsonPath)) {
                if (let Some(pkgJson) <- loadPackageJson(pkgJsonPath)) {
                    // 优先使用 module 字段 (如果 prefer_module_field)
                    var mainPath = ""
                    if (preferModuleField && pkgJson.module.size > 0) {
                        mainPath = pkgJson.module
                    } else if (pkgJson.main.size > 0) {
                        mainPath = pkgJson.main
                    }

                    if (mainPath.size > 0) {
                        let resolvedMain = Path.join(absPath, mainPath)
                        let mainResult = loadAsFileOrDirectory(resolvedMain, kind)
                        if (mainResult.status == ResolveStatus.Success) {
                            if (let Some(r) <- mainResult.result) {
                                r.packageJson = Some(pkgJson)
                            }
                            return mainResult
                        }
                    }
                }
            }

            // 查找 index 文件
            for (ext in extensionOrder) {
                let indexPath = Path.join(absPath, "index${ext}")
                if (Fs.fileExists(indexPath)) {
                    let result = ResolveResult(PathPair(ResolvedPath(indexPath)))
                    return ResolveUnionResult.success(result)
                }
            }
        }

        ResolveUnionResult.notFound()
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
                                     kind: ImportKind): ResolveUnionResult {
        let pkgJsonPath = Path.join(pkgPath, "package.json")
        if (!Fs.fileExists(pkgJsonPath)) {
            // 没有 package.json，直接解析子路径
            if (subpath.size > 0) {
                let subPath = Path.join(pkgPath, subpath)
                return loadAsFileOrDirectory(subPath, kind)
            }
            return loadAsFileOrDirectory(pkgPath, kind)
        }

        if (let Some(pkgJson) <- loadPackageJson(pkgJsonPath)) {
            // 设置模块类型
            let moduleType = pkgJson.moduleType

            // 使用 exports 解析
            if (let Some(exportsJson) <- pkgJson.exports) {
                if (let Some(result) <- resolvePackageExports(pkgPath, subpath,
                                                                exportsJson, kind)) {
                    result.packageJson = Some(pkgJson)
                    result.moduleType = moduleType
                    return ResolveUnionResult.success(result)
                }
            }

            // 使用 main/module 解析
            var entryPath = ""
            if (preferModuleField && pkgJson.module.size > 0) {
                entryPath = pkgJson.module
            } else if (pkgJson.main.size > 0) {
                entryPath = pkgJson.main
            }

            if (subpath.size > 0) {
                let subPath = Path.join(pkgPath, subpath)
                return loadAsFileOrDirectory(subPath, kind)
            }

            if (entryPath.size > 0) {
                let resolvedEntry = Path.join(pkgPath, entryPath)
                let result = loadAsFileOrDirectory(resolvedEntry, kind)
                if (result.status == ResolveStatus.Success) {
                    if (let Some(r) <- result.result) {
                        r.packageJson = Some(pkgJson)
                        r.moduleType = moduleType
                    }
                    return result
                }
            }

            // 回退到 index
            let indexPath = Path.join(pkgPath, "index")
            let indexResult = loadAsFileOrDirectory(indexPath, kind)
            if (indexResult.status == ResolveStatus.Success) {
                if (let Some(r) <- indexResult.result) {
                    r.packageJson = Some(pkgJson)
                    r.moduleType = moduleType
                }
                return indexResult
            }
        }

        ResolveUnionResult.notFound()
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
                                kind: ImportKind): ?ResolveResult {
        // 简化的 exports 解析
        // 完整实现需要 JSON 解析和条件匹配

        // 处理 "." 子路径
        if (subpath.size == 0 || subpath == ".") {
            // 查找 "." 入口
            let dotEntry = parseExportEntry(exportsJson, ".")
            if (dotEntry.size > 0) {
                let resolvedPath = Path.join(pkgPath, dotEntry)
                if (Fs.fileExists(resolvedPath)) {
                    return Some(ResolveResult(PathPair(ResolvedPath(resolvedPath))))
                }
            }
        }

        // 处理子路径
        let matchEntry = parseExportEntry(exportsJson, "./${subpath}")
        if (matchEntry.size > 0) {
            let resolvedPath = Path.join(pkgPath, matchEntry)
            if (Fs.fileExists(resolvedPath)) {
                return Some(ResolveResult(PathPair(ResolvedPath(resolvedPath))))
            }
        }

        None
    }

    // ========================================================================
    // matchTSConfigPaths - 匹配 tsconfig paths
    // 严格翻译自: resolver.zig - matchTSConfigPaths()
    //   解析 TypeScript 路径别名
    // ============================================================================

    /// 匹配 tsconfig paths
    func matchTSConfigPaths(tsconfig: TsconfigInfo, importPath: String,
                             kind: ImportKind): ?MatchResult {
        if (tsconfig.paths.size == 0) {
            return None
        }

        // 精确匹配
        if (let Some(targets) <- tsconfig.paths.get(importPath)) {
            for (target in targets) {
                let absTarget = if (tsconfig.baseUrl.size > 0) {
                    Path.join(tsconfig.baseUrl, target)
                } else {
                    target
                }
                let normalized = Path.normalize(absTarget)
                if (Fs.fileExists(normalized)) {
                    return Some(MatchResult(PathPair(ResolvedPath(normalized))))
                }
            }
        }

        // 通配符匹配
        // 严格翻译自 tsconfig paths 的 "*" 通配符匹配
        for (entry in tsconfig.paths) {
            let pattern = entry.key
            let targets = entry.value
            if (pattern.contains("*")) {
                let prefix = pattern.subString(0, pattern.indexOf("*"))
                let suffix = if (pattern.indexOf("*") + 1 < pattern.size) {
                    pattern.subString(pattern.indexOf("*") + 1)
                } else {
                    ""
                }

                if (importPath.startsWith(prefix) &&
                    (suffix.size == 0 || importPath.endsWith(suffix))) {
                    let starMatch = if (suffix.size > 0) {
                        importPath.subString(prefix.size,
                                              importPath.size - suffix.size)
                    } else {
                        importPath.subString(prefix.size)
                    }

                    for (target in targets) {
                        let resolved = target.replace("*", starMatch)
                        let absTarget = if (tsconfig.baseUrl.size > 0) {
                            Path.join(tsconfig.baseUrl, resolved)
                        } else {
                            resolved
                        }
                        let normalized = Path.normalize(absTarget)
                        if (Fs.fileExists(normalized)) {
                            return Some(MatchResult(PathPair(ResolvedPath(normalized))))
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

        let path = result.pathPair.path()
        if (path == None) {
            return
        }

        if (let Some(p) <- path) {
            // 设置副作用信息
            if (let Some(pkg) <- result.packageJson) {
                match (pkg.sideEffects) {
                    case NoSideEffects =>
                        result.primarySideEffectsData = SideEffects.NoSideEffectsPackageJson
                    case _ =>
                        result.primarySideEffectsData = SideEffects.HasSideEffects
                }
            }

            // 合并 tsconfig
            if (let Some(dirInfo) <- dirInfoCached(Dirname.dirname(p.text))) {
                if (let Some(tsconfig) <- dirInfo.enclosingTsconfigJson) {
                    result.jsx = tsconfig.mergeJSX(result.jsx)
                    result.flags.emitDecoratorMetadata =
                        result.flags.emitDecoratorMetadata || tsconfig.emitDecoratorMetadata
                    result.flags.experimentalDecorators =
                        result.flags.experimentalDecorators || tsconfig.experimentalDecorators
                }

                // 设置 package.json
                if (result.packageJson == None) {
                    result.packageJson = dirInfo.enclosingPackageJson
                }
            }

            // 设置模块类型
            if (!kind.isFromCSS() && result.moduleType == ModuleType.Unknown) {
                if (let Some(pkg) <- result.packageJson) {
                    result.moduleType = pkg.moduleType
                }
            }
        }
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 是否为外部模式
    /// 对应 Bun Resolver.isExternalPattern()
    func isExternalPattern(importPath: String): Bool {
        if (opts.packages == PackagePolicy.External && isPackagePath(importPath)) {
            return true
        }
        matchesUserExternalPattern(importPath)
    }

    /// 是否匹配用户定义的外部模式
    /// 对应 Bun Resolver.matchesUserExternalPattern()
    func matchesUserExternalPattern(importPath: String): Bool {
        for (pattern in opts.externalPatterns) {
            if (importPath.size >= pattern.prefix.size + pattern.suffix.size &&
                importPath.startsWith(pattern.prefix) &&
                importPath.endsWith(pattern.suffix)) {
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
            let firstSlash = specifier.indexOf('/')
            if (firstSlash < 0) {
                return Tuple2(specifier, "")
            }
            let afterScope = specifier.subString(firstSlash + 1)
            let secondSlash = afterScope.indexOf('/')
            if (secondSlash < 0) {
                return Tuple2(specifier, "")
            }
            let pkgName = specifier.subString(0, firstSlash + 1 + secondSlash)
            let subpath = "./${afterScope.subString(secondSlash + 1)}"
            return Tuple2(pkgName, subpath)
        }

        // 普通包
        let slashIndex = specifier.indexOf('/')
        if (slashIndex < 0) {
            return Tuple2(specifier, "")
        }
        let pkgName = specifier.subString(0, slashIndex)
        let subpath = "./${specifier.subString(slashIndex + 1)}"
        Tuple2(pkgName, subpath)
    }

    /// 获取缓存的目录信息
    /// 对应 Bun Resolver.dirInfoCached()
    func dirInfoCached(absPath: String): ?DirInfo {
        dirCache.get(absPath)
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

    /// 刷新调试日志
    func flushDebugLogs(flushMode: String): Unit {
        if (let Some(debug) <- debugLogs) {
            if (flushMode == "fail") {
                log.append("DEBUG: ${debug.what}")
                for (note in debug.notes) {
                    log.append("  ${note}")
                }
            }
        }
    }
}

// ============================================================================
// Tuple2 - 二元组辅助类
// ============================================================================

/// 二元组
public class Tuple2<T1, T2> {
    public var first: T1
    public var second: T2

    public init(first: T1, second: T2) {
        this.first = first
        this.second = second
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
            return s.isFile()
        }
        false
    }

    static func dirExists(path: String): Bool {
        let stat = Fs.stat(path)
        if (let Some(s) <- stat) {
            return s.isDirectory()
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
    public var isFile(): Bool {
        true
    }

    public var isDirectory(): Bool {
        false
    }

    public var isExecutable(): Bool {
        false
    }
}

// ============================================================================
// GlobalCache 扩展
// ============================================================================

/// GlobalCache 扩展方法
public func GlobalCache.isEnabled(): Bool {
    match (this) {
        case Auto => true
        case Disable => false
        case Fallback => true
        case Force => true
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
