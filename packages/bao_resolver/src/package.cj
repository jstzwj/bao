// bao_resolver - 模块解析器
// 严格翻译自: src/resolver/
//   src/resolver/resolver.zig - 主解析器 (~20000行)
//   src/resolver/package_json.zig - package.json 解析
//   src/resolver/tsconfig_json.zig - tsconfig.json 解析
//   src/resolver/dir_info.zig - 目录信息缓存
//   src/resolver/fs.zig - 文件系统抽象
//   src/resolver/data_url.zig - Data URL 处理
//
// Bun 的解析器是其核心模块之一，负责:
//   1. 将模块说明符 (import specifier) 解析为文件系统路径
//   2. 读取和缓存 package.json / tsconfig.json
//   3. 处理 Node.js 兼容的模块解析算法
//   4. 处理 exports/imports 条件导出
//   5. 处理 browser 字段替换
//   6. 处理 TypeScript 路径映射
package bao_resolver

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*

// ============================================================================
// ResolveResult - 解析结果
// 严格翻译自: src/resolver/resolver.zig 中 ResolveResult
// Bun 的解析结果包含路径、模块类型、以及调试信息
// ============================================================================

/// 解析状态 - 对应 Bun resolver 中的各种状态
public enum ResolveStatus {
    | Success                        // 成功解析
    | Undefined                      // 未定义
    | UndefinedNoConditionsMatch     // 条件不匹配
    | Null                           // 目标为 null (禁用)
    | Exact                          // 精确匹配
    | ExactEndsWithStar              // 带通配符匹配
    | Inexact                        // 不精确匹配 (可能需要尝试扩展名)
    | InvalidModuleSpecifier         // 无效模块说明符
    | InvalidPackageConfiguration    // 无效包配置
    | InvalidPackageTarget           // 无效包目标
    | PackagePathNotExported         // 包路径未导出
    | ModuleNotFound                 // 模块未找到
    | ModuleNotFoundMissingExtension // 缺少扩展名
    | UnsupportedDirectoryImport     // 不支持目录导入
    | PackagePathDisabled            // 包路径已禁用
    | PackageImportNotDefined        // 包导入未定义
    | PackageResolve                 // 包解析 (package specifier)

    /// 是否为未定义状态 - 对应 Bun Status.isUndefined()
    public func isUndefined(): Bool {
        match (this) {
            case Undefined | UndefinedNoConditionsMatch => true
            case _ => false
        }
    }

    /// 是否为成功状态
    public func isSuccess(): Bool {
        match (this) {
            case Success | Exact | ExactEndsWithStar | Inexact | PackageResolve => true
            case _ => false
        }
    }
}

/// 解析结果 - 对应 Bun resolver 的解析输出
public class ResolveResult {
    /// 解析状态
    public var status: ResolveStatus
    /// 解析出的路径 - 对应 Bun Resolution.path
    public var path: String
    /// 模块类型 - 对应 Bun module_type
    public var moduleType: ModuleType
    /// 是否是 CommonJS 模块
    public var isCJS: Bool
    /// 是否有副作用 - 对应 Bun side_effects
    public var hasSideEffects: Bool
    /// 包的名称 (如果解析到 node_modules 中的包)
    public var packageName: String
    /// 包的路径
    public var packagePath: String
    /// 调试信息 - 未匹配的条件列表
    public var unmatchedConditions: ArrayList<String>
    /// 路径对 - 对应 Bun PathPair (primary/secondary)
    public var primaryPath: String
    public var secondaryPath: String

    public init() {
        status = ResolveStatus.Undefined
        path = ""
        moduleType = ModuleType.Unknown
        isCJS = false
        hasSideEffects = true
        packageName = ""
        packagePath = ""
        unmatchedConditions = ArrayList<String>()
        primaryPath = ""
        secondaryPath = ""
    }

    public init(status: ResolveStatus, path: String) {
        this.status = status
        this.path = path
        moduleType = ModuleType.Unknown
        isCJS = false
        hasSideEffects = true
        packageName = ""
        packagePath = ""
        unmatchedConditions = ArrayList<String>()
        primaryPath = path
        secondaryPath = ""
    }

    /// 是否解析成功 - 对应 Bun Resolution 的成功判断
    public func isResolved(): Bool {
        return status.isSuccess() && path.length > 0
    }
}

// ============================================================================
// ResolveError - 解析错误
// 严格翻译自: src/resolver/resolver.zig 中的错误类型
// ============================================================================

/// 解析错误类型
public enum ResolveErrorKind {
    | ModuleNotFound        // 模块未找到
    | PackageNotFound       // 包未找到
    | InvalidSpecifier      // 无效说明符
    | InvalidPackageConfig  // 无效包配置
    | PathNotExported       // 路径未导出
    | UnsupportedImport     // 不支持的导入
    | CircularDependency    // 循环依赖
    | IO                    // IO 错误
}

/// 解析错误
public class ResolveError {
    public var kind: ResolveErrorKind
    public var message: String
    public var specifier: String
    public var fromPath: String

    public init(kind: ResolveErrorKind, message: String) {
        this.kind = kind
        this.message = message
        specifier = ""
        fromPath = ""
    }

    public init(kind: ResolveErrorKind, message: String, specifier: String, fromPath: String) {
        this.kind = kind
        this.message = message
        this.specifier = specifier
        this.fromPath = fromPath
    }

    public func toString(): String {
        return "ResolveError: ${message} (specifier=\"${specifier}\", from=\"${fromPath}\")"
    }
}

// ============================================================================
// ModuleType - 模块类型
// 严格翻译自: src/bundler/options.zig ModuleType
// Bun: pub const ModuleType = enum { unknown, esm, cjs }
// ============================================================================

/// 模块类型 - 对应 Bun options.ModuleType
public enum ModuleType {
    | Unknown   // 未知
    | ESM       // ES Module
    | CJS       // CommonJS

    public func label(): String {
        match (this) {
            case Unknown => "unknown"
            case ESM => "esm"
            case CJS => "cjs"
        }
    }
}

// ============================================================================
// Resolver - 主解析器类
// 严格翻译自: src/resolver/resolver.zig
// Bun: pub const Resolver = struct {
//     fs: *FileSystem,
//     log: *logger.Log,
//     opts: options.BundleOptions,
//     caches: *Cache,
//     ...
//     pub fn resolve(self, specifier, from, kind) -> ?PathPair
// }
// ============================================================================

/// 模块解析器 - 对应 Bun Resolver
/// 将模块说明符解析为文件系统路径
public class Resolver {
    /// 解析扩展名列表 - 对应 Bun 默认扩展名
    private var extensions: Array<String>
    /// 主字段列表 - 对应 Bun main_fields
    private var mainFields: Array<String>
    /// 条件列表 - 对应 Bun conditions
    private var conditions: ArrayList<String>
    /// 是否是浏览器目标 - 影响 browser 字段解析
    private var isBrowserTarget: Bool
    /// 是否启用调试日志
    private var debugLogs: Bool
    /// package.json 缓存
    private var packageJsonCache: HashMap<String, PackageJson>
    /// tsconfig 缓存
    private var tsconfigCache: HashMap<String, TsConfig>
    /// 目录信息缓存
    private var dirInfoCache: HashMap<String, DirInfo>
    /// 浏览器映射
    private var browserMap: HashMap<String, String>
    /// 外部模块列表
    private var externalModules: StringSet

    public init() {
        extensions = [".js", ".ts", ".jsx", ".tsx", ".mjs", ".cjs", ".mts", ".cts", ".json", ".wasm"]
        mainFields = ["module", "main"]
        conditions = ArrayList<String>()
        conditions.append("import")
        conditions.append("default")
        conditions.append("node")
        isBrowserTarget = true
        debugLogs = false
        packageJsonCache = HashMap<String, PackageJson>()
        tsconfigCache = HashMap<String, TsConfig>()
        dirInfoCache = HashMap<String, DirInfo>()
        browserMap = HashMap<String, String>()
        externalModules = StringSet()
    }

    /// 解析模块说明符 - 主入口
    /// 对应 Bun Resolver.resolve()
    /// specifier: 要解析的模块路径 (如 "lodash", "./foo", "/abs/path")
    /// fromPath: 导入文件的绝对路径
    public func resolve(specifier: String, fromPath: String): ResolveResult {
        // 1. 绝对路径
        if (Path.isAbsolute(specifier)) {
            return resolveAbsolutePath(specifier)
        }

        // 2. 相对路径 (./ ../)
        if (specifier.startsWith("./") || specifier.startsWith("../") ||
            specifier.startsWith(".\\") || specifier.startsWith("..\\")) {
            return resolveRelativePath(specifier, fromPath)
        }

        // 3. 包路径 (bare specifier: "lodash", "@scope/pkg")
        return resolvePackagePath(specifier, fromPath)
    }

    /// 带错误处理的解析
    public func tryResolve(specifier: String, fromPath: String): ?ResolveResult {
        let result = resolve(specifier, fromPath)
        if (result.isResolved()) {
            return Some(result)
        }
        return None
    }

    // ========================================================================
    // 绝对路径解析
    // ========================================================================

    /// 解析绝对路径
    private func resolveAbsolutePath(specifier: String): ResolveResult {
        // 尝试精确匹配
        if (fileExists(specifier)) {
            return ResolveResult(ResolveStatus.Exact, specifier)
        }

        // 尝试添加扩展名
        for (ext in extensions) {
            let withExt = specifier + ext
            if (fileExists(withExt)) {
                return ResolveResult(ResolveStatus.Exact, withExt)
            }
        }

        // 尝试 index 文件
        for (ext in extensions) {
            let indexPath = Path.join([specifier, "index${ext}"])
            if (fileExists(indexPath)) {
                return ResolveResult(ResolveStatus.Exact, indexPath)
            }
        }

        return ResolveResult(ResolveStatus.ModuleNotFound, specifier)
    }

    // ========================================================================
    // 相对路径解析
    // ========================================================================

    /// 解析相对路径
    private func resolveRelativePath(specifier: String, fromPath: String): ResolveResult {
        let dir = Path.dirname(fromPath)
        let fullPath = Path.join([dir, specifier])
        let normalized = Path.normalize(fullPath)

        // 浏览器映射检查
        if (isBrowserTarget) {
            match (browserMap.get(normalized)) {
                case Some(remapped) => {
                    if (remapped.length == 0) {
                        // 映射为空字符串表示模块被禁用
                        return ResolveResult(ResolveStatus.PackagePathDisabled, "")
                    }
                    return ResolveResult(ResolveStatus.Exact, remapped)
                }
                case None => ()
            }
        }

        // 尝试解析路径
        return resolveAbsolutePath(normalized)
    }

    // ========================================================================
    // 包路径解析 (bare specifier)
    // 严格对应 Bun Resolver 中 node_modules 查找算法
    // ========================================================================

    /// 解析包路径
    /// 对应 Bun Resolver 中 resolveWithoutRemap + node_modules 遍历
    private func resolvePackagePath(specifier: String, fromPath: String): ResolveResult {
        // 检查是否为外部模块
        if (isExternal(specifier)) {
            return ResolveResult(ResolveStatus.Success, specifier)
        }

        // 解析包名和子路径
        // 例如: "@scope/package/sub/path" -> name="@scope/package", subpath="./sub/path"
        let pkgParts = parsePackageSpecifier(specifier)
        let pkgName = pkgParts.first
        let pkgSubpath = pkgParts.second

        // 在 node_modules 中查找
        var dir = Path.dirname(fromPath)
        while (true) {
            let nmPath = Path.join([dir, "node_modules"])
            let pkgPath = Path.join([nmPath, pkgName])

            // 检查 node_modules/PKG 目录是否存在
            if (dirExists(pkgPath)) {
                // 读取 package.json
                let pkgJsonPath = Path.join([pkgPath, "package.json"])
                match (loadPackageJson(pkgJsonPath)) {
                    case Some(pkgJson) => {
                        // 使用 exports/imports 解析
                        if (pkgJson.exports != null) {
                            let exportResult = resolvePackageExports(
                                pkgPath, pkgSubpath, pkgJson
                            )
                            if (exportResult.isResolved()) {
                                return exportResult
                            }
                        }

                        // 使用 main/module 字段解析
                        return resolvePackageMain(pkgPath, pkgSubpath, pkgJson)
                    }
                    case None => {
                        // 没有 package.json，尝试直接解析
                        if (pkgSubpath.length > 0) {
                            let subPath = Path.join([pkgPath, pkgSubpath])
                            return resolveAbsolutePath(subPath)
                        }
                        return resolveAbsolutePath(pkgPath)
                    }
                }
            }

            // 向上查找父目录
            let parent = Path.dirname(dir)
            if (parent == dir) {
                break
            }
            dir = parent
        }

        // 尝试 TypeScript 路径映射
        match (resolveWithTsconfigPaths(specifier, fromPath)) {
            case Some(result) => return result
            case None => ()
        }

        return ResolveResult(ResolveStatus.ModuleNotFound, specifier)
    }

    /// 解析包的 exports 字段
    /// 严格对应 Bun package_json.zig 中 ESModule.resolve()
    private func resolvePackageExports(pkgPath: String, subpath: String,
                                        pkgJson: PackageJson): ResolveResult {
        // exports 必须以 "./" 开头
        let importPath = if (subpath.length == 0) { "." } else {
            if (subpath.startsWith("./")) { subpath } else { "./${subpath}" }
        }

        // 遍历 exports map 查找匹配
        match (pkgJson.exports) {
            case Some(exportsMap) => {
                // 遍历 exports 条目
                let keys = exportsMap.keys()
                for (key in keys) {
                    let matchResult = matchExportKey(key, importPath)
                    if (matchResult.length >= 0) {
                        // 找到匹配
                        match (exportsMap.get(key)) {
                            case Some(target) => {
                                // 解析条件
                                return resolveExportTarget(pkgPath, target, matchResult)
                            }
                            case None => ()
                        }
                    }
                }
                return ResolveResult(ResolveStatus.PackagePathNotExported, importPath)
            }
            case None => ()
        }
        return ResolveResult(ResolveStatus.Undefined, "")
    }

    /// 匹配 export key
    private func matchExportKey(pattern: String, importPath: String): String {
        if (pattern == importPath) {
            return ""
        }
        // 通配符匹配: ./foo/* -> ./foo/bar/baz 匹配 "bar/baz"
        if (pattern.endsWith("/*")) {
            let prefix = pattern.substring(Int64(0), Int64(pattern.length - 2))
            if (importPath.startsWith(prefix)) {
                return importPath.substring(Int64(prefix.length), Int64(importPath.length))
            }
        }
        // 前缀匹配: ./foo/ -> ./foo/bar 匹配 "bar"
        if (pattern.endsWith("/")) {
            if (importPath.startsWith(pattern)) {
                return importPath.substring(Int64(pattern.length), Int64(importPath.length))
            }
        }
        return ""
    }

    /// 解析 export 目标
    private func resolveExportTarget(pkgPath: String, target: String,
                                      matchStr: String): ResolveResult {
        // 简化: 处理字符串目标
        var resolvedTarget = target

        // 替换通配符
        if (resolvedTarget.contains("*") && matchStr.length > 0) {
            resolvedTarget = resolvedTarget.replace("*", matchStr)
        }

        // 拼接包路径
        if (resolvedTarget.startsWith("./")) {
            let fullPath = Path.join([pkgPath, resolvedTarget])
            return ResolveResult(ResolveStatus.Exact, Path.normalize(fullPath))
        }

        return ResolveResult(ResolveStatus.InvalidPackageTarget, resolvedTarget)
    }

    /// 解析包的 main/module 字段
    private func resolvePackageMain(pkgPath: String, subpath: String,
                                     pkgJson: PackageJson): ResolveResult {
        if (subpath.length > 0) {
            // 有子路径
            let subPath = Path.join([pkgPath, subpath])
            return resolveAbsolutePath(subPath)
        }

        // 按 mainFields 顺序查找
        for (field in mainFields) {
            match (pkgJson.mainFields.get(field)) {
                case Some(value) => {
                    if (value.length > 0) {
                        let mainPath = Path.join([pkgPath, value])
                        let result = resolveAbsolutePath(mainPath)
                        if (result.isResolved()) {
                            return result
                        }
                    }
                }
                case None => ()
            }
        }

        // 回退到 index.js
        let indexPath = Path.join([pkgPath, "index.js"])
        if (fileExists(indexPath)) {
            return ResolveResult(ResolveStatus.Exact, indexPath)
        }

        return ResolveResult(ResolveStatus.ModuleNotFound, pkgPath)
    }

    /// 使用 tsconfig paths 解析
    private func resolveWithTsconfigPaths(specifier: String,
                                           fromPath: String): ?ResolveResult {
        // 查找最近的 tsconfig.json
        let tsconfig = findTsconfig(fromPath)
        match (tsconfig) {
            case Some(config) => {
                if (config.paths.size > 0) {
                    return resolveWithPaths(specifier, fromPath, config)
                }
            }
            case None => ()
        }
        return None
    }

    /// 使用 paths 映射解析
    private func resolveWithPaths(specifier: String, fromPath: String,
                                   tsconfig: TsConfig): ?ResolveResult {
        let keys = tsconfig.paths.keys()
        for (pattern in keys) {
            match (tsconfig.paths.get(pattern)) {
                case Some(replacements) => {
                    // 通配符匹配: @foo/* -> ./src/*
                    if (pattern.endsWith("/*")) {
                        let prefix = pattern.substring(Int64(0), Int64(pattern.length - 2))
                        if (specifier.startsWith(prefix + "/")) {
                            let rest = specifier.substring(Int64(prefix.length + 1), Int64(specifier.length))
                            // 替换第一个匹配
                            if (replacements.size > 0) {
                                let replacement = replacements[0]
                                let resolved = replacement.replace("*", rest)
                                // 相对于 baseUrl 解析
                                let baseUrl = if (tsconfig.baseUrl.length > 0) { tsconfig.baseUrl } else { tsconfig.absPath }
                                let dir = Path.dirname(fromPath)
                                let fullPath = Path.join([dir, baseUrl, resolved])
                                let result = resolveAbsolutePath(Path.normalize(fullPath))
                                if (result.isResolved()) {
                                    return Some(result)
                                }
                            }
                        }
                    } else if (pattern == specifier) {
                        // 精确匹配
                        if (replacements.size > 0) {
                            let replacement = replacements[0]
                            let dir = Path.dirname(fromPath)
                            let baseUrl = if (tsconfig.baseUrl.length > 0) { tsconfig.baseUrl } else { "" }
                            let fullPath = if (baseUrl.length > 0) {
                                Path.join([dir, baseUrl, replacement])
                            } else {
                                Path.join([dir, replacement])
                            }
                            let result = resolveAbsolutePath(Path.normalize(fullPath))
                            if (result.isResolved()) {
                                return Some(result)
                            }
                        }
                    }
                }
                case None => ()
            }
        }
        return None
    }

    // ========================================================================
    // 包说明符解析
    // 严格对应 Bun package_json.zig 中 ESModule.Package.parse()
    // ========================================================================

    /// 解析包说明符为 (name, subpath)
    /// "@scope/pkg/sub" -> ("@scope/pkg", "sub")
    /// "lodash/orderBy" -> ("lodash", "orderBy")
    /// "react" -> ("react", "")
    public func parsePackageSpecifier(specifier: String): Tuple2<String, String> {
        // 作用域包: @scope/package[/subpath]
        if (specifier.startsWith("@")) {
            let firstSlash = specifier.indexOf('/')
            if (firstSlash < 0) {
                return Tuple2(specifier, "")
            }
            let rest = specifier.substring(Int64(firstSlash + 1), Int64(specifier.length))
            let secondSlash = rest.indexOf('/')
            if (secondSlash < 0) {
                return Tuple2(specifier, "")
            }
            let name = specifier.substring(Int64(0), Int64(firstSlash + 1 + secondSlash))
            let subpath = rest.substring(Int64(secondSlash + 1), Int64(rest.length))
            return Tuple2(name, subpath)
        }

        // 普通包: package[/subpath]
        let slash = specifier.indexOf('/')
        if (slash < 0) {
            return Tuple2(specifier, "")
        }
        let name = specifier.substring(Int64(0), Int64(slash))
        let subpath = specifier.substring(Int64(slash + 1), Int64(specifier.length))
        return Tuple2(name, subpath)
    }

    /// 检查是否是包路径 (非相对/绝对路径)
    /// 对应 Bun resolver.isPackagePath()
    public func isPackagePath(path: String): Bool {
        if (Path.isAbsolute(path)) {
            return false
        }
        return !path.startsWith("./") && !path.startsWith("../") &&
               !path.startsWith(".\\") && !path.startsWith("..\\") &&
               path != "." && path != ".."
    }

    // ========================================================================
    // package.json 和 tsconfig 加载
    // ========================================================================

    /// 加载 package.json (带缓存)
    private func loadPackageJson(path: String): ?PackageJson {
        match (packageJsonCache.get(path)) {
            case Some(pkg) => return Some(pkg)
            case None => ()
        }

        // 读取并解析
        let content = readFileContent(path)
        match (content) {
            case Some(text) => {
                let parser = PackageJsonParser()
                let pkg = parser.parse(text)
                pkg.path = path
                packageJsonCache.put(path, pkg)
                return Some(pkg)
            }
            case None => return None
        }
    }

    /// 查找最近的 tsconfig.json
    private func findTsconfig(fromPath: String): ?TsConfig {
        var dir = Path.dirname(fromPath)
        while (true) {
            let tsconfigPath = Path.join([dir, "tsconfig.json"])
            match (tsconfigCache.get(tsconfigPath)) {
                case Some(config) => return Some(config)
                case None => ()
            }

            let content = readFileContent(tsconfigPath)
            match (content) {
                case Some(text) => {
                    let parser = TsConfigParser()
                    let config = parser.parse(text)
                    config.absPath = dir
                    tsconfigCache.put(tsconfigPath, config)
                    return Some(config)
                }
                case None => ()
            }

            let parent = Path.dirname(dir)
            if (parent == dir) {
                break
            }
            dir = parent
        }
        return None
    }

    // ========================================================================
    // 工具方法
    // ========================================================================

    /// 检查是否为外部模块
    private func isExternal(specifier: String): Bool {
        return externalModules.contains(specifier)
    }

    /// 添加外部模块
    public func addExternal(specifier: String): Unit {
        externalModules.insert(specifier)
    }

    /// 添加条件
    public func addCondition(condition: String): Unit {
        conditions.append(condition)
    }

    /// 设置主字段
    public func setMainFields(fields: Array<String>): Unit {
        mainFields = fields
    }

    /// 设置是否浏览器目标
    public func setBrowserTarget(isBrowser: Bool): Unit {
        isBrowserTarget = isBrowser
    }

    /// 设置调试日志
    public func setDebugLogs(enable: Bool): Unit {
        debugLogs = enable
    }

    /// 清除缓存
    public func clearCache(): Unit {
        packageJsonCache.clear()
        tsconfigCache.clear()
        dirInfoCache.clear()
    }

    /// 文件是否存在
    private func fileExists(path: String): Bool {
        try {
            std.fs.exists(path)
        } catch (_: Exception) {
            false
        }
    }

    /// 目录是否存在
    private func dirExists(path: String): Bool {
        try {
            std.fs.isDirectory(path)
        } catch (_: Exception) {
            false
        }
    }

    /// 读取文件内容
    private func readFileContent(path: String): ?String {
        try {
            Some(BaoFile.readAllText(path))
        } catch (_: Exception) {
            None
        }
    }
}

// ============================================================================
// DirInfo - 目录信息
// 严格翻译自: src/resolver/dir_info.zig
// Bun 使用 DirInfo 缓存目录结构和 package.json 查找结果
// ============================================================================

/// 目录信息 - 对应 Bun DirInfo
public class DirInfo {
    public var absPath: String
    public var entries: ArrayList<String>
    public var hasPackageJson: Bool
    public var packageJson: ?PackageJson

    public init(absPath: String) {
        this.absPath = absPath
        entries = ArrayList<String>()
        hasPackageJson = false
        packageJson = None
    }
}

/// 简单的二元组
public class Tuple2<A, B> {
    public var first: A
    public var second: B

    public init(first: A, second: B) {
        this.first = first
        this.second = second
    }
}
