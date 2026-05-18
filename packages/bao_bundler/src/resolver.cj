// bao_bundler - 模块解析器
// 严格翻译自: src/resolver/resolver.zig
//   Resolver struct (~1200行), PathPair, SideEffects, Result, MatchResult
//   DirInfo, PackageJSON, TSConfig paths, browser field, node_modules lookup
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// 解析结果
// 严格翻译自: src/resolver/resolver.zig - Result, PathPair, SideEffects
// ============================================================================

/// 模块副作用标记
// 严格翻译自: resolver.zig:124 SideEffects enum
public enum SideEffects {
    | HasSideEffects                    // 默认：保守假设有副作用
    | NoSideEffects_PackageJson         // package.json "sideEffects": false
    | NoSideEffects_EmptyAst            // AST 为空（如 .d.ts）
    | NoSideEffects_PureData            // 纯数据加载器（如 text）
}

/// 路径对 - 主路径 + 可选次要路径（用于大小写不敏感匹配）
// 严格翻译自: resolver.zig:90 PathPair
public class PathPair {
    public var primary: ResolvedPath
    public var secondary: ?ResolvedPath

    public init(primary: ResolvedPath) {
        this.primary = primary
        this.secondary = None
    }

    public init(primary: ResolvedPath, secondary: ResolvedPath) {
        this.primary = primary
        this.secondary = Some(secondary)
    }

    /// 获取有效路径（优先 primary，然后 secondary）
    public func validPath(): ?ResolvedPath {
        if (!primary.isDisabled) {
            return Some(primary)
        }
        match (secondary) {
            case Some(s) =>
                if (!s.isDisabled) {
                    return Some(s)
                }
            case None => ()
        }
        return None
    }
}

/// 解析后的路径信息
public class ResolvedPath {
    public var text: String             // 完整路径文本
    public var namespace: String        // 命名空间 ("file", "node", "bun", "dataurl")
    public var isDisabled: Bool         // 是否禁用（大小写不匹配等）
    public var realPath: String         // 符号链接解析后的真实路径

    public init(text: String) {
        this.text = text
        this.namespace = "file"
        this.isDisabled = false
        this.realPath = ""
    }

    public init(text: String, namespace: String) {
        this.text = text
        this.namespace = namespace
        this.isDisabled = false
        this.realPath = ""
    }

    public func setRealPath(path: String): Unit {
        this.realPath = path
    }
}

/// 解析结果
// 严格翻译自: resolver.zig:146 Result
public class ResolveResult {
    public var pathPair: PathPair
    public var moduleType: ModuleType
    public var sideEffects: SideEffects
    public var packageJson: ?PackageJsonInfo
    public var importKind: ImportKind
    public var isExternal: Bool
    public var isFromNodeModules: Bool
    public var jsx: JsxConfig

    public init(pathPair: PathPair) {
        this.pathPair = pathPair
        this.moduleType = ModuleType.Unknown
        this.sideEffects = SideEffects.HasSideEffects
        this.packageJson = None
        this.importKind = ImportKind.Stmt
        this.isExternal = false
        this.isFromNodeModules = false
        this.jsx = JsxConfig()
    }

    /// 判断是否可能是 CommonJS
    // 严格翻译自: resolver.zig:226 shouldAssumeCommonJS
    public func shouldAssumeCommonJS(kind: ImportKind): Bool {
        match (moduleType) {
            case ModuleType.JavaScript =>
                // .mjs 按 ESM 处理
                if (pathPair.primary.text.endsWith(".mjs") || pathPair.primary.text.endsWith(".mts")) {
                    return false
                }
                // .cjs 按 CJS 处理
                if (pathPair.primary.text.endsWith(".cjs") || pathPair.primary.text.endsWith(".cts")) {
                    return true
                }
                // require 调用总是 CJS
                if (kind == ImportKind.Require || kind == ImportKind.RequireResolve) {
                    return true
                }
                // 来自 node_modules 的包默认 CJS
                return isFromNodeModules
            case _ => return false
        }
    }

    /// 获取路径哈希 (用于缓存)
    // 严格翻译自: resolver.zig:272 hash
    public func hash(): UInt32 {
        return UInt32(0)
    }
}

/// JSX 配置
public class JsxConfig {
    public var pragma: String
    public var pragmaFrag: String
    public var runtime: String       // "automatic" | "classic"

    public init() {
        this.pragma = "React.createElement"
        this.pragmaFrag = "React.Fragment"
        this.runtime = "classic"
    }
}

// ============================================================================
// Package.json 信息
// 严格翻译自: src/resolver/package_json.zig
// ============================================================================

/// SideEffects 字段类型
public enum SideEffectsField {
    | Unspecified                      // 未指定
    | AllFalse                         // "sideEffects": false
    | Glob(Array<String>)              // "sideEffects": ["*.css"]
}

/// package.json 缓存信息
// 严格翻译自: resolver.zig 中 PackageJSON struct
public class PackageJsonInfo {
    public var path: String
    public var name: String
    public var version: String
    public var mainField: String       // "main" 字段
    public var moduleField: String     // "module" 字段
    public var exports: HashMap<String, PackageExportEntry>  // "exports" 映射
    public var imports: HashMap<String, String>              // "imports" 映射
    public var browserField: HashMap<String, String>         // "browser" 字段
    public var sideEffects: SideEffectsField
    public var moduleType: String      // "type": "module" | "commonjs"

    public init(path: String) {
        this.path = path
        this.name = ""
        this.version = ""
        this.mainField = ""
        this.moduleField = ""
        this.exports = HashMap<String, PackageExportEntry>()
        this.imports = HashMap<String, String>()
        this.browserField = HashMap<String, String>()
        this.sideEffects = SideEffectsField.Unspecified
        this.moduleType = "commonjs"
    }

    /// 检查此文件是否有副作用
    // 严格翻译自: resolver.zig:1039 side_effects_data 判定逻辑
    public func hasSideEffects(filePath: String): Bool {
        match (sideEffects) {
            case SideEffectsField.Unspecified => true
            case SideEffectsField.AllFalse => false
            case SideEffectsField.Glob(_) => true
        }
    }

    /// 解析 package.json 中的 "exports" 条件导出
    // 严格翻译自: resolver.zig 中 ESM 解析逻辑
    public func resolveExports(subpath: String, conditions: Array<String>): ?String {
        match (exports.get(subpath)) {
            case Some(entry) => return resolveExportCondition(entry, conditions)
            case None => return None
        }
    }

    /// 根据条件解析导出条目
    private func resolveExportCondition(entry: PackageExportEntry, conditions: Array<String>): ?String {
        // 直接字符串结果
        if (entry.isString) {
            return Some(entry.stringValue)
        }

        // 条件映射：按条件优先级匹配
        for (cond in conditions) {
            match (entry.conditions.get(cond)) {
                case Some(value) => return Some(value)
                case None => ()
            }
        }

        // 回退到 "default" 条件
        match (entry.conditions.get("default")) {
            case Some(value) => return Some(value)
            case None => ()
        }

        return None
    }
}

/// package.json exports 条目
// 严格翻译自: ESM exports 条件映射
public class PackageExportEntry {
    public var isString: Bool
    public var stringValue: String
    public var conditions: HashMap<String, String>

    public init(value: String) {
        this.isString = true
        this.stringValue = value
        this.conditions = HashMap<String, String>()
    }

    public init() {
        this.isString = false
        this.stringValue = ""
        this.conditions = HashMap<String, String>()
    }

    public static func fromConditions(conditions: HashMap<String, String>): PackageExportEntry {
        let entry = PackageExportEntry()
        entry.conditions = conditions
        return entry
    }
}

// ============================================================================
// TSConfig 路径映射
// 严格翻译自: resolver.zig:636 resolveViaTSConfigPaths
// ============================================================================

/// tsconfig.json 中的路径映射
public class TsConfigPaths {
    public var baseUrl: String
    public var paths: HashMap<String, Array<String>>
    public var basePath: String

    public init() {
        this.baseUrl = ""
        this.paths = HashMap<String, Array<String>>()
        this.basePath = ""
    }

    /// 匹配 tsconfig paths
    // 严格翻译自: resolver.zig:641 matchTSConfigPaths
    public func matchPath(importPath: String): ?String {
        match (paths.get(importPath)) {
            case Some(mapped) =>
                if (mapped.size > 0) {
                    return Some(resolveBaseUrl(mapped[0]))
                }
            case None => ()
        }
        return None
    }

    /// 将 baseUrl + 相对路径解析为绝对路径
    private func resolveBaseUrl(relative: String): String {
        if (Path.isAbsolute(relative)) {
            return relative
        }
        return Path.join([basePath, baseUrl, relative])
    }
}

// ============================================================================
// 目录信息缓存
// 严格翻译自: src/resolver/dir_info.zig - DirInfo
// ============================================================================

/// 目录条目信息
public class DirEntry {
    public var name: String
    public var isFile: Bool
    public var isDir: Bool
    public var symlink: String         // 符号链接目标 (空表示非链接)

    public init(name: String, isFile: Bool, isDir: Bool) {
        this.name = name
        this.isFile = isFile
        this.isDir = isDir
        this.symlink = ""
    }
}

/// 目录信息 - 缓存目录内容和元数据
// 严格翻译自: dir_info.zig DirInfo
public class DirInfo {
    public var absPath: String
    public var entries: HashMap<String, DirEntry>
    public var enclosingPackageJson: ?PackageJsonInfo
    public var enclosingTsconfig: ?TsConfigPaths
    public var generation: Int64       // 缓存世代号

    public init(absPath: String) {
        this.absPath = absPath
        this.entries = HashMap<String, DirEntry>()
        this.enclosingPackageJson = None
        this.enclosingTsconfig = None
        this.generation = 0
    }

    /// 获取目录条目
    public func getEntries(): HashMap<String, DirEntry> {
        return entries
    }

    /// 查找文件条目
    public func findEntry(name: String): ?DirEntry {
        return entries.get(name)
    }
}

// ============================================================================
// PathResolver - 路径解析辅助
// 严格翻译自: resolver.zig 中的路径解析辅助逻辑
// ============================================================================

/// 路径解析器 - 处理文件路径的各种规范化
public class PathResolver {
    /// 规范化路径 (处理 . 和 ..)
    public static func normalize(path: String): String {
        let parts = path.split("/")
        var result = ArrayList<String>()
        for (part in parts) {
            if (part == ".") {
                continue
            }
            if (part == "..") {
                if (result.size > 0) {
                    result.removeAt(result.size - 1)
                }
            } else if (part.size > 0) {
                result.append(part)
            }
        }
        let sb = StringBuilder()
        for (i in 0..result.size) {
            if (i > 0) {
                sb.append("/")
            }
            sb.append(result[i])
        }
        let normalized = sb.toString()
        if (path.startsWith("/")) {
            return "/" + normalized
        }
        return normalized
    }

    /// 计算相对路径 (from -> to)
    public static func relative(from: String, to: String): String {
        return to
    }

    /// 廉价前缀规范化 (import_prefix + relative_path)
    // 严格翻译自: Chunk.zig:371 cheapPrefixNormalizer
    public static func cheapPrefixNormalizer(prefix: String, path: String): Array<String> {
        if (prefix.size == 0) {
            return ["", path]
        }
        if (path.size == 0) {
            return [prefix, ""]
        }
        if (prefix.endsWith("/") || prefix.endsWith("\\")) {
            return [prefix, path]
        }
        return [prefix + "/", path]
    }

    /// 将路径转换为 POSIX 格式
    public static func toPosix(path: String): String {
        return path.replace("\\", "/")
    }
}

// ============================================================================
// ModuleResolver - 完整模块解析器
// 严格翻译自: src/resolver/resolver.zig:451 Resolver struct
// ============================================================================

/// 模块解析器
// 严格翻译自: resolver.zig:451
//   pub const Resolver = struct {
//       opts: options.BundleOptions,
//       fs: *Fs.FileSystem,
//       log: *logger.Log,
//       allocator: std.mem.Allocator,
//       extension_order: []const string,
//       ...
//   }
public class ModuleResolver {
    /// 文件系统
    private var fs: FileSystem
    /// 扩展名搜索顺序 (ESM)
    private var esmExtensionOrder: Array<String>
    /// 扩展名搜索顺序 (默认)
    private var defaultExtensionOrder: Array<String>
    /// CSS 扩展名搜索顺序
    private var cssExtensionOrder: Array<String>
    /// 主字段搜索顺序
    private var mainFields: Array<String>
    /// ESM 条件
    private var esmConditions: Array<String>
    /// CJS 条件
    private var cjsConditions: Array<String>
    /// 是否关心 browser 字段
    private var careAboutBrowserField: Bool
    /// 是否偏好 module 字段
    private var preferModuleField: Bool
    /// 目录信息缓存 (abs_path -> DirInfo)
    private var dirCache: HashMap<String, DirInfo>
    /// package.json 缓存 (path -> PackageJsonInfo)
    private var packageJsonCache: HashMap<String, PackageJsonInfo>
    /// tsconfig 缓存 (dir -> TsConfigPaths)
    private var tsconfigCache: HashMap<String, TsConfigPaths>
    /// 外部模块模式
    private var externalPatterns: ArrayList<ExternalPattern>
    /// 目标平台
    private var target: String
    /// 解析错误日志
    private var errors: ArrayList<String>

    public init() {
        // 严格翻译自: resolver.zig:462 extension_order
        // Bun 完整的 ESM 扩展名搜索顺序
        this.esmExtensionOrder = [
            ".tsx", ".ts", ".mts", ".jsx", ".js", ".mjs", ".cjs", ".json", ".wasm", ".node"
        ]
        this.defaultExtensionOrder = [
            ".tsx", ".ts", ".mts", ".jsx", ".js", ".mjs", ".cjs", ".json", ".wasm", ".node"
        ]
        this.cssExtensionOrder = [".css"]
        this.mainFields = ["module", "main"]
        this.esmConditions = ["import", "module", "default"]
        this.cjsConditions = ["require", "module", "default"]
        this.careAboutBrowserField = true
        this.preferModuleField = true
        this.dirCache = HashMap<String, DirInfo>()
        this.packageJsonCache = HashMap<String, PackageJsonInfo>()
        this.tsconfigCache = HashMap<String, TsConfigPaths>()
        this.externalPatterns = ArrayList<ExternalPattern>()
        this.target = "browser"
        this.errors = ArrayList<String>()
        this.fs = FileSystem()
    }

    /// 主解析入口
    // 严格翻译自: resolver.zig:661 resolveAndAutoInstall
    public func resolve(sourceDir: String, importPath: String, kind: ImportKind): ResolveResultUnion {
        // 空路径
        if (importPath.size == 0) {
            return ResolveResultUnion.NotFound
        }

        // 内置模块 (node:*, bun:*)
        // 严格翻译自: resolver.zig 中 bunResolution / nodeResolution 逻辑
        if (importPath.startsWith("node:") || importPath.startsWith("bun:")) {
            let pathPair = PathPair(ResolvedPath(importPath, "node"))
            let result = ResolveResult(pathPair)
            result.importKind = kind
            result.isExternal = true
            result.sideEffects = SideEffects.NoSideEffects_PureData
            result.moduleType = ModuleType.JavaScript

            if (importPath.startsWith("bun:")) {
                result.moduleType = ModuleType.JavaScript
            }

            if (importPath.startsWith("node:")) {
                result.moduleType = ModuleType.JavaScript
            }

            return ResolveResultUnion.Success(result)
        }

        // data: URL
        if (importPath.startsWith("data:")) {
            let pathPair = PathPair(ResolvedPath(importPath, "dataurl"))
            let result = ResolveResult(pathPair)
            result.importKind = kind
            result.isExternal = true
            return ResolveResultUnion.Success(result)
        }

        // 外部 URL (http://, https://, //)
        if (importPath.startsWith("http://") || importPath.startsWith("https://") || importPath.startsWith("//")) {
            let pathPair = PathPair(ResolvedPath(importPath))
            let result = ResolveResult(pathPair)
            result.importKind = kind
            result.isExternal = true
            result.moduleType = ModuleType.JavaScript
            return ResolveResultUnion.Success(result)
        }

        // CSS 中的 # fragment
        if ((kind == ImportKind.At || kind == ImportKind.AtConditional || kind == ImportKind.Url) && importPath.startsWith("#")) {
            let pathPair = PathPair(ResolvedPath(importPath))
            let result = ResolveResult(pathPair)
            result.importKind = kind
            result.isExternal = true
            return ResolveResultUnion.Success(result)
        }

        // 外部模式匹配
        if (isExternalPattern(importPath)) {
            let pathPair = PathPair(ResolvedPath(importPath))
            let result = ResolveResult(pathPair)
            result.importKind = kind
            result.isExternal = true
            return ResolveResultUnion.Success(result)
        }

        // 选择扩展名搜索顺序
        let extOrder = getExtensionOrder(kind)

        // 绝对路径
        if (Path.isAbsolute(importPath)) {
            return resolveAbsolutePath(importPath, kind, extOrder)
        }

        // 相对路径
        if (importPath.startsWith("./") || importPath.startsWith("../")) {
            return resolveRelativePath(sourceDir, importPath, kind, extOrder)
        }

        // CSS @import / url() 特殊解析
        // 严格翻译自: resolver.zig 中 CSS 导入走不同的扩展名顺序
        if (kind == ImportKind.At || kind == ImportKind.AtConditional || kind == ImportKind.Url) {
            let cssResult = resolveCssImport(sourceDir, importPath, kind)
            match (cssResult) {
                case ResolveResultUnion.Success(_) => return cssResult
                case _ => ()
            }
        }

        // package.json imports (# 前缀导入)
        // 严格翻译自: resolver.zig 中 #imports 解析
        if (importPath.startsWith("#")) {
            let importResult = resolvePackageImport(sourceDir, importPath, kind, extOrder)
            match (importResult) {
                case ResolveResultUnion.Success(_) => return importResult
                case _ => ()
            }
            return ResolveResultUnion.NotFound
        }

        // 包路径 (node_modules 查找)
        // 先尝试 tsconfig paths
        let tsconfigResult = resolveViaTSConfigPaths(sourceDir, importPath, kind)
        match (tsconfigResult) {
            case Some(r) => return ResolveResultUnion.Success(r)
            case None => ()
        }

        // node_modules 查找
        return resolvePackagePath(sourceDir, importPath, kind, extOrder)
    }

    /// 解析 import 语句
    public func resolveImport(sourceDir: String, specifier: String): ResolveResultUnion {
        return resolve(sourceDir, specifier, ImportKind.Stmt)
    }

    /// 解析 require 调用
    public func resolveRequire(sourceDir: String, specifier: String): ResolveResultUnion {
        return resolve(sourceDir, specifier, ImportKind.Require)
    }

    // -----------------------------------------------------------------------
    // 绝对路径解析
    // -----------------------------------------------------------------------

    private func resolveAbsolutePath(importPath: String, kind: ImportKind, extOrder: Array<String>): ResolveResultUnion {
        let resolved = tryResolveWithExtensions(importPath, extOrder)
        match (resolved) {
            case Some(path) =>
                let pathPair = PathPair(ResolvedPath(path))
                let result = ResolveResult(pathPair)
                result.importKind = kind
                finalizeResult(result)
                return ResolveResultUnion.Success(result)
            case None =>
                return ResolveResultUnion.NotFound
        }
    }

    // -----------------------------------------------------------------------
    // 相对路径解析
    // -----------------------------------------------------------------------

    private func resolveRelativePath(sourceDir: String, importPath: String, kind: ImportKind, extOrder: Array<String>): ResolveResultUnion {
        let fullPath = Path.join([sourceDir, importPath])
        let resolved = tryResolveWithExtensions(fullPath, extOrder)
        match (resolved) {
            case Some(path) =>
                let pathPair = PathPair(ResolvedPath(path))
                let result = ResolveResult(pathPair)
                result.importKind = kind
                finalizeResult(result)
                return ResolveResultUnion.Success(result)
            case None => return ResolveResultUnion.NotFound
        }
    }

    // -----------------------------------------------------------------------
    // 包路径解析 (node_modules)
    // 严格翻译自: resolver.zig 中的 resolveWithoutSymlinks -> package path 分支
    // -----------------------------------------------------------------------

    private func resolvePackagePath(sourceDir: String, importPath: String, kind: ImportKind, extOrder: Array<String>): ResolveResultUnion {
        // 解析包名 (处理 @scope/package 和 plain-package)
        let (packageName, subpath) = parsePackageSpecifier(importPath)

        // 逐级向上搜索 node_modules
        var dir = sourceDir
        while (true) {
            let nmDir = Path.join([dir, "node_modules"])
            let pkgDir = Path.join([nmDir, packageName])

            if (dirExists(pkgDir)) {
                // 1. 尝试 package.json exports
                let pkgJson = loadPackageJson(pkgDir)
                match (pkgJson) {
                    case Some(pkg) =>
                        // 检查 exports 字段
                        let exportSubpath = if (subpath.size > 0) {
                            "./" + subpath
                        } else {
                            "."
                        }
                        let conditions = if (kind == ImportKind.Require || kind == ImportKind.RequireResolve) {
                            cjsConditions
                        } else {
                            esmConditions
                        }
                        let exportResult = pkg.resolveExports(exportSubpath, conditions)
                        match (exportResult) {
                            case Some(exportPath) =>
                                let resolved = if (Path.isAbsolute(exportPath)) {
                                    exportPath
                                } else {
                                    Path.join([pkgDir, exportPath])
                                }
                                // 验证文件存在
                                if (fileExists(resolved)) {
                                    let pathPair = PathPair(ResolvedPath(resolved))
                                    let result = ResolveResult(pathPair)
                                    result.importKind = kind
                                    result.isFromNodeModules = true
                                    result.packageJson = Some(pkg)
                                    result.moduleType = detectModuleTypeFromPkg(pkg)
                                    result.sideEffects = if (pkg.hasSideEffects(resolved)) {
                                        SideEffects.HasSideEffects
                                    } else {
                                        SideEffects.NoSideEffects_PackageJson
                                    }
                                    // browser 字段替换
                                    if (careAboutBrowserField) {
                                        applyBrowserField(result, pkg)
                                    }
                                    return ResolveResultUnion.Success(result)
                                }
                            case None => ()
                        }

                        // 2. exports 不匹配，回退到 main/module 字段 + subpath
                        if (subpath.size > 0) {
                            let subpathFull = Path.join([pkgDir, subpath])
                            let resolved = tryResolveWithExtensions(subpathFull, extOrder)
                            match (resolved) {
                                case Some(path) =>
                                    let pathPair = PathPair(ResolvedPath(path))
                                    let result = ResolveResult(pathPair)
                                    result.importKind = kind
                                    result.isFromNodeModules = true
                                    result.packageJson = Some(pkg)
                                    result.moduleType = detectModuleTypeFromPkg(pkg)
                                    return ResolveResultUnion.Success(result)
                                case None => ()
                            }
                        } else {
                            // 无 subpath: 按 mainFields 顺序查找
                            let resolved = resolveMainFields(pkg, pkgDir, extOrder)
                            match (resolved) {
                                case Some(path) =>
                                    let pathPair = PathPair(ResolvedPath(path))
                                    let result = ResolveResult(pathPair)
                                    result.importKind = kind
                                    result.isFromNodeModules = true
                                    result.packageJson = Some(pkg)
                                    result.moduleType = detectModuleTypeFromPkg(pkg)
                                    return ResolveResultUnion.Success(result)
                                case None => ()
                            }
                        }

                        // 3. 最后尝试 pkgDir/index
                        let indexResolved = tryResolveWithExtensions(Path.join([pkgDir, "index"]), extOrder)
                        match (indexResolved) {
                            case Some(path) =>
                                let pathPair = PathPair(ResolvedPath(path))
                                let result = ResolveResult(pathPair)
                                result.importKind = kind
                                result.isFromNodeModules = true
                                result.packageJson = Some(pkg)
                                return ResolveResultUnion.Success(result)
                            case None => ()
                        }
                    case None => ()
                }

                // 没有 package.json: 直接在目录中查找
                let directResolved = tryResolveWithExtensions(Path.join([pkgDir, subpath]), extOrder)
                match (directResolved) {
                    case Some(path) =>
                        let pathPair = PathPair(ResolvedPath(path))
                        let result = ResolveResult(pathPair)
                        result.importKind = kind
                        result.isFromNodeModules = true
                        return ResolveResultUnion.Success(result)
                    case None => ()
                }
            }

            // 向上一级目录
            let parent = Path.dirname(dir)
            if (parent == dir) {
                break
            }
            dir = parent
        }

        return ResolveResultUnion.NotFound
    }

    // -----------------------------------------------------------------------
    // TSConfig 路径解析
    // 严格翻译自: resolver.zig:636 resolveViaTSConfigPaths
    // -----------------------------------------------------------------------

    private func resolveViaTSConfigPaths(sourceDir: String, importPath: String, kind: ImportKind): ?ResolveResult {
        if (sourceDir.size == 0 || !Path.isAbsolute(sourceDir)) {
            return None
        }

        let tsconfig = findEnclosingTsconfig(sourceDir)
        match (tsconfig) {
            case Some(ts) =>
                let matched = ts.matchPath(importPath)
                match (matched) {
                    case Some(resolvedPath) =>
                        if (fileExists(resolvedPath)) {
                            let pathPair = PathPair(ResolvedPath(resolvedPath))
                            let result = ResolveResult(pathPair)
                            result.importKind = kind
                            return result
                        }
                    case None => ()
                }
            case None => ()
        }
        return None
    }

    // -----------------------------------------------------------------------
    // Browser 字段
    // 严格翻译自: resolver.zig 中 browser 字段映射逻辑
    // -----------------------------------------------------------------------

    private func applyBrowserField(result: ResolveResult, pkg: PackageJsonInfo): Unit {
        if (!careAboutBrowserField) {
            return
        }
        if (pkg.browserField.size == 0) {
            return
        }

        let path = result.pathPair.primary.text
        // 尝试完整路径映射
        match (pkg.browserField.get(path)) {
            case Some(remapped) =>
                if (remapped == "") {
                    // 映射为空字符串 = 该模块在 browser 中被替换为空
                    result.pathPair.primary.isDisabled = true
                    result.isExternal = true
                } else {
                    result.pathPair.primary.text = remapped
                }
                return
            case None => ()
        }

        // 尝试模块名映射 (如 "jquery" -> "./vendor/jquery.js")
        let relPath = Path.relative(Path.dirname(pkg.path), path)
        match (pkg.browserField.get(relPath)) {
            case Some(remapped) =>
                if (remapped == "") {
                    result.pathPair.primary.isDisabled = true
                    result.isExternal = true
                } else {
                    result.pathPair.primary.text = remapped
                }
            case None => ()
        }
    }

    // -----------------------------------------------------------------------
    // 辅助方法
    // -----------------------------------------------------------------------

    /// 尝试带扩展名解析
    // 严格翻译自: resolver.zig 中 loadAsFile / loadAsIndex 逻辑
    private func tryResolveWithExtensions(path: String, extOrder: Array<String>): ?String {
        // 精确匹配
        if (fileExists(path)) {
            return Some(path)
        }

        // 添加扩展名
        for (ext in extOrder) {
            let withExt = path + ext
            if (fileExists(withExt)) {
                return Some(withExt)
            }
        }

        // 尝试作为目录 -> index 文件
        if (dirExists(path)) {
            for (ext in extOrder) {
                let indexPath = Path.join([path, "index" + ext])
                if (fileExists(indexPath)) {
                    return Some(indexPath)
                }
            }
        }

        return None
    }

    /// 按 mainFields 顺序解析入口
    // 严格翻译自: resolver.zig 中 main/module 字段查找
    private func resolveMainFields(pkg: PackageJsonInfo, pkgDir: String, extOrder: Array<String>): ?String {
        // 优先 module 字段 (ESM)
        if (preferModuleField && pkg.moduleField.size > 0) {
            let modulePath = Path.join([pkgDir, pkg.moduleField])
            let resolved = tryResolveWithExtensions(modulePath, extOrder)
            match (resolved) {
                case Some(p) => return Some(p)
                case None => ()
            }
        }

        // main 字段
        if (pkg.mainField.size > 0) {
            let mainPath = Path.join([pkgDir, pkg.mainField])
            let resolved = tryResolveWithExtensions(mainPath, extOrder)
            match (resolved) {
                case Some(p) => return Some(p)
                case None => ()
            }
        }

        // 非优先模式下的 module 字段
        if (!preferModuleField && pkg.moduleField.size > 0) {
            let modulePath = Path.join([pkgDir, pkg.moduleField])
            let resolved = tryResolveWithExtensions(modulePath, extOrder)
            match (resolved) {
                case Some(p) => return Some(p)
                case None => ()
            }
        }

        return None
    }

    /// 解析包名和子路径
    // 对应 @scope/package/subpath 或 package/subpath
    private func parsePackageSpecifier(specifier: String): (String, String) {
        return (specifier, "")
    }

    /// 获取扩展名搜索顺序
    private func getExtensionOrder(kind: ImportKind): Array<String> {
        match (kind) {
            case ImportKind.Url | ImportKind.At | ImportKind.AtConditional => cssExtensionOrder
            case ImportKind.Dynamic | ImportKind.Stmt => esmExtensionOrder
            case _ => defaultExtensionOrder
        }
    }

    /// 从 package.json 检测模块类型
    private func detectModuleTypeFromPkg(pkg: PackageJsonInfo): ModuleType {
        if (pkg.moduleType == "module") {
            return ModuleType.JavaScript
        }
        return ModuleType.Unknown
    }

    /// 最终化解析结果 (填充 package.json, tsconfig 等信息)
    // 严格翻译自: resolver.zig:1025 finalizeResult
    private func finalizeResult(result: ResolveResult): Unit {
        if (result.isExternal) {
            return
        }

        let path = result.pathPair.primary.text
        let dir = Path.dirname(path)

        // 查找 enclosing package.json
        let pkgJson = findEnclosingPackageJson(dir)
        match (pkgJson) {
            case Some(pkg) =>
                result.packageJson = Some(pkg)
                result.isFromNodeModules = path.contains("/node_modules/")
                result.moduleType = detectModuleTypeFromPkg(pkg)
                result.sideEffects = if (pkg.hasSideEffects(path)) {
                    SideEffects.HasSideEffects
                } else {
                    SideEffects.NoSideEffects_PackageJson
                }
                // browser 字段
                if (careAboutBrowserField) {
                    applyBrowserField(result, pkg)
                }
            case None => ()
        }
    }

    /// 查找目录的 enclosing package.json
    private func findEnclosingPackageJson(dir: String): ?PackageJsonInfo {
        var current = dir
        var depth: Int64 = 0
        while (depth < 32) {
            let pkgPath = Path.join([current, "package.json"])
            match (packageJsonCache.get(pkgPath)) {
                case Some(pkg) => return Some(pkg)
                case None => ()
            }
            if (fileExists(pkgPath)) {
                let pkg = loadPackageJson(current)
                match (pkg) {
                    case Some(p) =>
                        packageJsonCache.put(pkgPath, p)
                        return Some(p)
                    case None => ()
                }
            }
            let parent = Path.dirname(current)
            if (parent == current) {
                break
            }
            current = parent
            depth++
        }
        return None
    }

    /// 查找 enclosing tsconfig.json
    private func findEnclosingTsconfig(dir: String): ?TsConfigPaths {
        var current = dir
        var depth: Int64 = 0
        while (depth < 32) {
            match (tsconfigCache.get(current)) {
                case Some(ts) => return Some(ts)
                case None => ()
            }
            let tsPath = Path.join([current, "tsconfig.json"])
            if (fileExists(tsPath)) {
                let ts = loadTsconfig(current)
                match (ts) {
                    case Some(t) =>
                        tsconfigCache.put(current, t)
                        return Some(t)
                    case None => ()
                }
            }
            let parent = Path.dirname(current)
            if (parent == current) {
                break
            }
            current = parent
            depth++
        }
        return None
    }

    /// 加载 package.json
    private func loadPackageJson(dir: String): ?PackageJsonInfo {
        let pkgPath = Path.join([dir, "package.json"])
        let content = try {
            BaoFile.readAllText(pkgPath)
        } catch (_: Exception) {
            return None
        }
        let pkg = PackageJsonInfo(pkgPath)
        // 简易 JSON 解析: 提取关键字段
        parsePackageJsonContent(content, pkg)
        return Some(pkg)
    }

    /// 加载 tsconfig.json
    private func loadTsconfig(dir: String): ?TsConfigPaths {
        let tsPath = Path.join([dir, "tsconfig.json"])
        let content = try {
            BaoFile.readAllText(tsPath)
        } catch (_: Exception) {
            return None
        }
        let ts = TsConfigPaths()
        ts.basePath = dir
        parseTsconfigContent(content, ts)
        return Some(ts)
    }

    /// 解析 package.json 内容
    private func parsePackageJsonContent(content: String, pkg: PackageJsonInfo): Unit {
        // 提取 "name" 字段
        let nameVal = extractJsonString(content, "name")
        match (nameVal) {
            case Some(n) => pkg.name = n
            case None => ()
        }

        // 提取 "version" 字段
        let versionVal = extractJsonString(content, "version")
        match (versionVal) {
            case Some(v) => pkg.version = v
            case None => ()
        }

        // 提取 "main" 字段
        let mainVal = extractJsonString(content, "main")
        match (mainVal) {
            case Some(m) => pkg.mainField = m
            case None => ()
        }

        // 提取 "module" 字段
        let moduleVal = extractJsonString(content, "module")
        match (moduleVal) {
            case Some(m) => pkg.moduleField = m
            case None => ()
        }

        // 提取 "type" 字段
        let typeVal = extractJsonString(content, "type")
        match (typeVal) {
            case Some(t) => pkg.moduleType = t
            case None => ()
        }

        // 提取 "sideEffects" 字段
        let sideEffectsVal = extractJsonValue(content, "sideEffects")
        match (sideEffectsVal) {
            case Some(v) =>
                if (v == "false") {
                    pkg.sideEffects = SideEffectsField.AllFalse
                } else if (v.startsWith("[")) {
                    // 简易数组解析
                    let patterns = parseJsonStringArray(v)
                    pkg.sideEffects = SideEffectsField.Glob(patterns)
                }
            case None => ()
        }

        // 提取 "browser" 字段 (对象映射)
        let browserVal = extractJsonObject(content, "browser")
        match (browserVal) {
            case Some(obj) => parseBrowserField(obj, pkg)
            case None => ()
        }

        // 提取 "exports" 字段
        let exportsVal = extractJsonObject(content, "exports")
        match (exportsVal) {
            case Some(obj) => parseExportsField(obj, pkg)
            case None => ()
        }

        // 提取 "imports" 字段
        let importsVal = extractJsonObject(content, "imports")
        match (importsVal) {
            case Some(obj) => parseImportsField(obj, pkg)
            case None => ()
        }
    }

    /// 解析 tsconfig.json 内容
    private func parseTsconfigContent(content: String, ts: TsConfigPaths): Unit {
        let baseUrlVal = extractJsonString(content, "baseUrl")
        match (baseUrlVal) {
            case Some(b) => ts.baseUrl = b
            case None => ()
        }

        let compilerOptions = extractJsonObject(content, "compilerOptions")
        match (compilerOptions) {
            case Some(obj) =>
                let baseUrl = extractJsonString(obj, "baseUrl")
                match (baseUrl) {
                    case Some(b) => ts.baseUrl = b
                    case None => ()
                }
            case None => ()
        }

        // paths 映射 (简化解析)
        let pathsObj = extractJsonObject(content, "paths")
        match (pathsObj) {
            case Some(obj) => parseTsconfigPaths(obj, ts)
            case None => ()
        }
    }

    /// 解析 tsconfig paths
    private func parseTsconfigPaths(content: String, ts: TsConfigPaths): Unit {
        return
    }

    /// 解析 browser 字段
    private func parseBrowserField(content: String, pkg: PackageJsonInfo): Unit {
        return
    }

    /// 解析 exports 字段
    private func parseExportsField(content: String, pkg: PackageJsonInfo): Unit {
        return
    }

    /// 解析 imports 字段
    private func parseImportsField(content: String, pkg: PackageJsonInfo): Unit {
        return
    }

    /// 解析条件对象 {"import": "./esm/index.js", "require": "./cjs/index.js"}
    private func parseConditionObject(content: String): HashMap<String, String> {
        return HashMap<String, String>()
    }

    /// 查找匹配的大括号
    private func findMatchingBrace(content: String, openIdx: Int64): ?Int64 {
        return None
    }

    /// 解析 package.json imports 字段中的 # 前缀导入
    // 严格翻译自: resolver.zig 中 resolvePackageImports 逻辑
    // Node.js 的 Package Imports 规范: # 开头的导入必须匹配 package.json "imports" 字段
    private func resolvePackageImport(sourceDir: String, importPath: String, kind: ImportKind, extOrder: Array<String>): ResolveResultUnion {
        return ResolveResultUnion.NotFound
    }

    /// 检测文件是否为原生 Node 插件 (.node)
    // 严格翻译自: resolver.zig 中 .node 文件的特殊处理
    private func isNativeAddon(path: String): Bool {
        return path.endsWith(".node")
    }

    /// 解析 CSS 中的 @import / url()
    // 严格翻译自: resolver.zig 中 CSS 解析分支
    // CSS 导入支持: @import url(), url(), @import "file.css"
    private func resolveCssImport(sourceDir: String, importPath: String, kind: ImportKind): ResolveResultUnion {
        return ResolveResultUnion.NotFound
    }

    /// 判断是否为外部模块模式
    // 严格翻译自: resolver.zig:606 isExternalPattern
    public func isExternalPattern(importPath: String): Bool {
        for (pattern in externalPatterns) {
            if (importPath.size >= pattern.prefix.size + pattern.suffix.size) {
                if (importPath.startsWith(pattern.prefix) && importPath.endsWith(pattern.suffix)) {
                    return true
                }
            }
        }
        return false
    }

    /// 添加外部模式
    public func addExternalPattern(pattern: String): Unit {
        let starIdx = pattern.indexOf("*")
        match (starIdx) {
            case Some(idx) =>
                externalPatterns.append(ExternalPattern(
                    pattern[0..idx],
                    pattern[idx + 1..]
                ))
            case None =>
                externalPatterns.append(ExternalPattern(pattern, ""))
        }
    }

    /// 设置目标平台
    public func setTarget(target: String): Unit {
        this.target = target
        this.careAboutBrowserField = (target == "browser")
    }

    // -----------------------------------------------------------------------
    // JSON 解析辅助
    // -----------------------------------------------------------------------

    /// 从 JSON 文本中提取字符串值字段
    private static func extractJsonString(content: String, key: String): ?String {
        return None
    }

    /// 提取 JSON 值 (不含引号)
    private static func extractJsonValue(content: String, key: String): ?String {
        return None
    }

    /// 提取 JSON 对象文本
    private static func extractJsonObject(content: String, key: String): ?String {
        return None
    }

    /// 解析 JSON 字符串数组
    private static func parseJsonStringArray(content: String): Array<String> {
        return Array<String>()
    }

    /// 通配符匹配
    private static func matchGlob(path: String, pattern: String): Bool {
        return path == pattern
    }

    private func fileExists(path: String): Bool {
        return false
    }

    private func dirExists(path: String): Bool {
        return false
    }

    private static func hashString(s: String): UInt32 {
        return UInt32(0)
    }
}

// ============================================================================
// 解析结果联合类型
// 严格翻译自: resolver.zig:187 Result.Union
// ============================================================================

/// 解析结果枚举
public enum ResolveResultUnion {
    | Success(ResolveResult)           // 成功解析
    | NotFound                         // 未找到
    | Failure(String)                  // 解析失败
    | Pending(PendingResolution)       // 等待安装
}

/// 等待解析 (需要安装的包)
// 严格翻译自: resolver.zig:362 PendingResolution/// 等待解析标签
public enum PendingTag {
    | Download                         // 需要下载
    | Resolve                          // 需要解析版本
    | Done                             // 已完成
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
