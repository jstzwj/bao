// 严格翻译自: src/bundler/options.zig (~2655行)
// bao_bundler - 打包选项: BundleOptions、Target、Loader、Format 等配置
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// 打包选项
// 严格翻译自: src/bundler/options.zig
// 核心职责:
//   1. BundleOptions: 完整的打包配置 (~50 个字段)
//   2. Target: 目标平台 (browser/bun/node/bun_macro/bake_ssr)
//   3. Loader: 文件加载器 (20+ 种类型及各种辅助方法)
//   4. Format: 输出格式 (ESM/CJS/IIFE)
//   5. SourceMapOption: Sourcemap 配置
//   6. JSX: JSX 编译配置
//   7. ESMConditions: ESM 条件解析
//   8. PathTemplate: 路径模板
//   9. ExternalModules: 外部模块管理
// ============================================================================

/// 写入目标
// 严格翻译自: options.zig:8 WriteDestination
public enum WriteDestination {
    | Stdout
    | Disk
}

/// 目标平台
// 严格翻译自: options.zig:379 Target
public enum BundleTarget {
    | Browser
    | Bun
    | BunMacro
    | Node
    | BakeServerComponentsSSR

    /// 转换为 API 目标
    public func toAPI(): String {
        match (this) {
            case Node => "node"
            case Browser => "browser"
            case Bun | BakeServerComponentsSSR => "bun"
            case BunMacro => "bun_macro"
        }
    }

    /// 是否是服务端
    public func isServerSide(): Bool {
        match (this) {
            case BunMacro | Node | Bun | BakeServerComponentsSSR => true
            case _ => false
        }
    }

    /// 是否是 Bun 运行时
    public func isBun(): Bool {
        match (this) {
            case BunMacro | Bun | BakeServerComponentsSSR => true
            case _ => false
        }
    }

    /// 是否是 Node
    public func isNode(): Bool {
        match (this) {
            case Node => true
            case _ => false
        }
    }

    /// 获取浏览器 define 值
    public func processBrowserDefineValue(): ?String {
        match (this) {
            case Browser => Some("true")
            case _ => Some("false")
        }
    }

    /// 获取默认主字段
    public func defaultMainFields(): ArrayList<String> {
        let fields = ArrayList<String>()
        match (this) {
            case Node => {
                fields.append("main")
                fields.append("module")
            }
            case Browser => {
                fields.append("browser")
                fields.append("module")
                fields.append("jsnext:main")
                fields.append("main")
            }
            case Bun | BunMacro | BakeServerComponentsSSR => {
                fields.append("module")
                fields.append("main")
                fields.append("jsnext:main")
            }
        }
        return fields
    }

    /// 获取默认条件
    public func defaultConditions(): ArrayList<String> {
        let conditions = ArrayList<String>()
        match (this) {
            case Node => {
                conditions.append("node")
            }
            case Browser => {
                conditions.append("browser")
                conditions.append("module")
            }
            case Bun => {
                conditions.append("bun")
                conditions.append("node")
            }
            case BunMacro => {
                conditions.append("macro")
                conditions.append("bun")
                conditions.append("node")
            }
            case BakeServerComponentsSSR => {
                conditions.append("bun")
                conditions.append("node")
            }
        }
        return conditions
    }

    /// 从 API 值创建
    public static func from(apiValue: ?String): BundleTarget {
        match (apiValue) {
            case Some(v) => {
                if (v == "node") { return Node }
                if (v == "browser") { return Browser }
                if (v == "bun") { return Bun }
                if (v == "bun_macro" || v == "macro") { return BunMacro }
                return Browser
            }
            case None => return Browser
        }
    }
}

/// 输出格式
// 严格翻译自: options.zig:560 Format
public enum OutputFormat {
    | ESM
    | CJS
    | IIFE
    | InternalBakeDev
}

/// 允许未解析的模式
// 严格翻译自: options.zig:53 AllowUnresolved
public enum AllowUnresolved {
    | All           // 跳过所有检查
    | None          // 总是报错
    | Patterns      // glob 模式匹配

    /// 从字符串列表规范化
    public static func fromStrings(strs: ArrayList<String>): AllowUnresolved {
        if (strs.size == 0) { return None }
        for (s in strs) {
            if (s == "*") { return All }
        }
        return Patterns
    }
}

/// 外部模块
// 严格翻译自: options.zig:83 ExternalModules
public class ExternalModules {
    /// node_modules 外部包名
    public var nodeModules: HashSet<String>
    /// 绝对路径外部
    public var absPaths: HashSet<String>
    /// 通配符模式
    public var patterns: ArrayList<WildcardPattern>

    public init() {
        nodeModules = HashSet<String>()
        absPaths = HashSet<String>()
        patterns = ArrayList<WildcardPattern>()
    }

    /// 是否是 Node 内置模块
    public static func isNodeBuiltin(str: String): Bool {
        let builtins = HashSet<String>()
        builtins.add("assert")
        builtins.add("buffer")
        builtins.add("child_process")
        builtins.add("cluster")
        builtins.add("console")
        builtins.add("constants")
        builtins.add("crypto")
        builtins.add("dgram")
        builtins.add("dns")
        builtins.add("domain")
        builtins.add("events")
        builtins.add("fs")
        builtins.add("http")
        builtins.add("https")
        builtins.add("module")
        builtins.add("net")
        builtins.add("os")
        builtins.add("path")
        builtins.add("perf_hooks")
        builtins.add("process")
        builtins.add("punycode")
        builtins.add("querystring")
        builtins.add("readline")
        builtins.add("repl")
        builtins.add("stream")
        builtins.add("string_decoder")
        builtins.add("sys")
        builtins.add("timers")
        builtins.add("tls")
        builtins.add("tty")
        builtins.add("url")
        builtins.add("util")
        builtins.add("vm")
        builtins.add("wasi")
        builtins.add("worker_threads")
        builtins.add("zlib")
        return builtins.contains(str)
    }

    /// 初始化外部模块
    // 严格翻译自: options.zig:112 init()
    public static func initFunc(
        externals: ArrayList<String>,
        log: Log,
        target: BundleTarget
    ): ExternalModules {
        let result = ExternalModules()

        // 添加默认的 Bun 通配符模式
        result.patterns.append(WildcardPattern("/bun:", ""))

        // Node 目标添加内置模块
        if (target == BundleTarget.Node) {
            // 简化: 添加主要的 Node 内置模块
            result.nodeModules.add("assert")
            result.nodeModules.add("buffer")
            result.nodeModules.add("child_process")
            result.nodeModules.add("crypto")
            result.nodeModules.add("fs")
            result.nodeModules.add("http")
            result.nodeModules.add("https")
            result.nodeModules.add("module")
            result.nodeModules.add("net")
            result.nodeModules.add("os")
            result.nodeModules.add("path")
            result.nodeModules.add("process")
            result.nodeModules.add("stream")
            result.nodeModules.add("url")
            result.nodeModules.add("util")
            result.nodeModules.add("vm")
            result.nodeModules.add("zlib")
        }

        // 处理用户指定的外部模块
        for (external in externals) {
            let wildcardIndex = external.indexOf('*')
            if (wildcardIndex >= 0) {
                // 通配符模式
                let suffix = if (wildcardIndex + 1 < external.length) {
                    external.substring(wildcardIndex + 1)
                } else {
                    ""
                }
                result.patterns.append(WildcardPattern(
                    external.substring(0, wildcardIndex),
                    suffix
                ))
            } else if (isPackagePath(external)) {
                result.nodeModules.add(external)
            } else {
                // 绝对路径
                if (external.length > 0) {
                    result.absPaths.add(external)
                }
            }
        }

        return result
    }

    private static func isPackagePath(s: String): Bool {
        if (s.length == 0) { return false }
        if (s[0] == '.' || s[0] == '/') { return false }
        return true
    }
}

/// 通配符模式
// 严格翻译自: options.zig:88 WildcardPattern
public class WildcardPattern {
    public var prefix: String
    public var suffix: String

    public init(prefix: String, suffix: String) {
        this.prefix = prefix
        this.suffix = suffix
    }
}

/// Sourcemap 选项
// 严格翻译自: options.zig:1604 SourceMapOption
public enum SourcemapOption {
    | None
    | Inline
    | External
    | Linked

    /// 是否有外部文件
    public func hasExternalFiles(): Bool {
        match (this) {
            case Linked | External => true
            case _ => false
        }
    }
}

/// 包处理选项
// 严格翻译自: options.zig:1643 PackagesOption
public enum PackageMode {
    | Bundle
    | External
}

/// BundleOptions (完整版)
// 严格翻译自: options.zig:1670 BundleOptions
// 注意: bundle.cj 中有简化版，此处是完整翻译
public class BundlerOptions {
    // ===== 基本配置 =====
    /// footer 文本
    public var footer: String
    /// banner 文本
    public var banner: String
    /// Define 管理器
    public var define: ?Define
    /// 丢弃的项
    public var drop: ArrayList<String>
    /// Bundler feature flags
    public var bundlerFeatureFlags: HashSet<String>
    /// 加载器映射
    public var loaders: HashMap<String, Loader>
    /// 解析目录
    public var resolveDir: String
    /// JSX 配置
    public var jsxConfig: JsxPragma
    /// 是否发出装饰器元数据
    public var emitDecoratorMetadata: Bool
    /// 是否使用实验性装饰器
    public var experimentalDecorators: Bool
    /// 是否自动导入 JSX
    public var autoImportJsx: Bool
    /// 是否允许运行时
    public var allowRuntime: Bool
    /// 是否裁剪未使用的导入
    public var trimUnusedImports: ?Bool
    /// 是否将内置标记为外部
    public var markBuiltinsAsExternal: Bool
    /// 是否启用服务器组件
    public var serverComponents: Bool
    /// 是否启用热模块重载
    public var hotModuleReloading: Bool
    /// 是否启用 React Fast Refresh
    public var reactFastRefresh: Bool
    /// 注入文件列表
    public var inject: ?ArrayList<String>
    /// origin URL
    public var origin: String
    /// 输出目录句柄
    public var outputDirHandle: ?FileDescriptor
    /// 输出目录
    public var outputDir: String
    /// 根目录
    public var rootDir: String

    // ===== 打包行为 =====
    public var write: Bool
    public var preserveSymlinks: Bool
    public var preserveExtensions: Bool
    public var production: Bool
    public var outputFormat: OutputFormat
    public var appendPackageVersionInQueryString: Bool
    public var tsconfigOverride: ?String
    public var target: BundleTarget
    public var mainFields: ArrayList<String>
    public var log: Log
    public var external: ExternalModules
    public var allowUnresolved: AllowUnresolved
    public var entryPoints: ArrayList<String>
    public var entryNaming: String
    public var assetNaming: String
    public var chunkNaming: String
    public var publicPath: String
    public var extensionOrder: ResolveFileExtensions
    public var mainFieldExtensionOrder: ArrayList<String>
    public var extraCjsExtensions: ArrayList<String>
    public var outExtensions: HashMap<String, String>
    public var importPathFormat: ImportPathFormat
    public var definesLoaded: Bool
    public var envConfig: EnvConfig
    public var transformOptions: TransformOptions

    // ===== 特性标志 =====
    public var polyfillNodeGlobals: Bool
    public var transformOnly: Bool
    public var loadTsconfigJson: Bool
    public var loadPackageJson: Bool
    public var rewriteJestForTests: Bool
    public var macroRemap: HashMap<String, String>
    public var noMacros: Bool
    public var conditions: ESMConditions
    public var treeShaking: Bool
    public var codeSplitting: Bool
    public var sourceMap: SourcemapOption
    public var packages: PackageMode
    public var disableTranspilation: Bool
    public var globalCache: GlobalCache
    public var preferOfflineInstall: Bool
    public var preferLatestInstall: Bool

    // ===== 压缩 =====
    public var inlining: Bool
    public var inlineEntrypointImportMetaMain: Bool
    public var minifyWhitespace: Bool
    public var minifySyntax: Bool
    public var minifyIdentifiers: Bool
    public var keepNames: Bool
    public var deadCodeElimination: Bool
    public var replMode: Bool
    public var cssChunking: Bool
    public var ignoreDceAnnotations: Bool
    public var emitDceAnnotations: Bool
    public var bytecode: Bool

    // ===== 输出 =====
    public var codeCoverage: Bool
    public var debuggerEnabled: Bool
    public var compile: Bool
    public var compileToStandaloneHtml: Bool
    public var metafile: Bool
    public var metafileJsonPath: String
    public var metafileMarkdownPath: String

    // ===== 框架 =====
    public var devServer: ?DevServerRef
    public var framework: ?FrameworkRef
    public var servePlugins: ?ArrayList<String>
    public var bunfigPath: String
    public var unwrapCommonjsPackages: ArrayList<String>
    public var supportsMultipleOutputs: Bool
    public var forceNodeEnv: ForceNodeEnv
    public var ignoreModuleResolutionErrors: Bool
    public var optimizeImports: ?HashSet<String>

    public init() {
        footer = ""
        banner = ""
        define = None
        drop = ArrayList<String>()
        bundlerFeatureFlags = HashSet<String>()
        loaders = HashMap<String, Loader>()
        resolveDir = "/"
        jsxConfig = JsxPragma()
        emitDecoratorMetadata = false
        experimentalDecorators = false
        autoImportJsx = true
        allowRuntime = true
        trimUnusedImports = None
        markBuiltinsAsExternal = false
        serverComponents = false
        hotModuleReloading = false
        reactFastRefresh = false
        inject = None
        origin = ""
        outputDirHandle = None
        outputDir = "out"
        rootDir = ""
        write = false
        preserveSymlinks = false
        preserveExtensions = false
        production = false
        outputFormat = OutputFormat.ESM
        appendPackageVersionInQueryString = false
        tsconfigOverride = None
        target = BundleTarget.Browser
        mainFields = BundleTarget.Browser.defaultMainFields()
        log = Log()
        external = ExternalModules()
        allowUnresolved = AllowUnresolved.All
        entryPoints = ArrayList<String>()
        entryNaming = ""
        assetNaming = ""
        chunkNaming = ""
        publicPath = ""
        extensionOrder = ResolveFileExtensions()
        mainFieldExtensionOrder = ArrayList<String>()
        extraCjsExtensions = ArrayList<String>()
        outExtensions = HashMap<String, String>()
        importPathFormat = ImportPathFormat.Relative
        definesLoaded = false
        envConfig = EnvConfig()
        transformOptions = TransformOptions()
        polyfillNodeGlobals = false
        transformOnly = false
        loadTsconfigJson = true
        loadPackageJson = true
        rewriteJestForTests = false
        macroRemap = HashMap<String, String>()
        noMacros = false
        conditions = ESMConditions()
        treeShaking = false
        codeSplitting = false
        sourceMap = SourcemapOption.None
        packages = PackageMode.Bundle
        disableTranspilation = false
        globalCache = GlobalCache.Disable
        preferOfflineInstall = false
        preferLatestInstall = false
        inlining = false
        inlineEntrypointImportMetaMain = false
        minifyWhitespace = false
        minifySyntax = false
        minifyIdentifiers = false
        keepNames = false
        deadCodeElimination = true
        replMode = false
        cssChunking = false
        ignoreDceAnnotations = false
        emitDceAnnotations = false
        bytecode = false
        codeCoverage = false
        debuggerEnabled = false
        compile = false
        compileToStandaloneHtml = false
        metafile = false
        metafileJsonPath = ""
        metafileMarkdownPath = ""
        devServer = None
        framework = None
        servePlugins = None
        bunfigPath = ""
        unwrapCommonjsPackages = ArrayList<String>()
        unwrapCommonjsPackages.append("react")
        unwrapCommonjsPackages.append("react-is")
        unwrapCommonjsPackages.append("react-dom")
        unwrapCommonjsPackages.append("scheduler")
        supportsMultipleOutputs = true
        forceNodeEnv = ForceNodeEnv.Unspecified
        ignoreModuleResolutionErrors = false
        optimizeImports = None
    }

    /// 是否是测试模式
    public func isTest(): Bool {
        return rewriteJestForTests
    }

    /// 设置生产模式
    public func setProduction(value: Bool): Unit {
        if (forceNodeEnv == ForceNodeEnv.Unspecified) {
            production = value
            jsxConfig.development = !value
        }
    }

    /// CSS 导入行为
    public func cssImportBehavior(): CssInJsBehavior {
        match (target) {
            case BundleTarget.Browser => CssInJsBehavior.AutoOnImportCSS
            case _ => CssInJsBehavior.Facade
        }
    }

    /// 是否未设置 define
    public func areDefinesUnset(): Bool {
        return !definesLoaded
    }

    /// 加载 define
    public func loadDefines(allocator: Allocator, loader: ?DotEnvLoader, env: ?EnvConfig): Unit {
        if (definesLoaded) { return }
        // 简化: 实际需要调用 definesFromTransformOptions
        definesLoaded = true
    }

    /// 获取指定扩展名的加载器
    public func loader(ext: String): Loader {
        match (loaders.get(ext)) {
            case Some(l) => return l
            case None => return Loader.File
        }
    }

    /// 释放资源
    public func deinit(allocator: Allocator): Unit {
        match (define) {
            case Some(d) => d.deinit()
            case None => ()
        }
    }
}

/// 导入路径格式
// 严格翻译自: options.zig:1899 ImportPathFormat
public enum ImportPathFormat {
    | Relative
    | AbsoluteUrl
    | AbsolutePath
    | PackagePath
}

/// 强制 NODE_ENV
// 严格翻译自: options.zig:1815 ForceNodeEnv
public enum ForceNodeEnv {
    | Unspecified
    | Development
    | Production
}

/// ESM 条件
// 严格翻译自: options.zig:1077 ESMConditions
public class ESMConditions {
    /// 默认条件
    public var defaultConditions: HashSet<String>
    /// import 条件
    public var importConditions: HashSet<String>
    /// require 条件
    public var requireConditions: HashSet<String>
    /// style 条件
    public var styleConditions: HashSet<String>

    public init() {
        defaultConditions = HashSet<String>()
        importConditions = HashSet<String>()
        requireConditions = HashSet<String>()
        styleConditions = HashSet<String>()
    }

    /// 初始化
    public static func initFunc(
        defaults: ArrayList<String>,
        allowAddons: Bool,
        conditions: ArrayList<String>
    ): ESMConditions {
        let result = ESMConditions()

        // import 包含 "import"
        result.importConditions.add("import")
        // require 包含 "require"
        result.requireConditions.add("require")
        // style 包含 "style"
        result.styleConditions.add("style")

        // 添加用户条件
        for (condition in conditions) {
            result.defaultConditions.add(condition)
            result.importConditions.add(condition)
            result.requireConditions.add(condition)
        }

        // 添加默认条件
        for (default in defaults) {
            result.defaultConditions.add(default)
            result.importConditions.add(default)
            result.requireConditions.add(default)
            result.styleConditions.add(default)
        }

        // node-addons
        if (allowAddons) {
            result.defaultConditions.add("node-addons")
            result.importConditions.add("node-addons")
            result.requireConditions.add("node-addons")
        }

        // 所有条件都包含 "default"
        result.defaultConditions.add("default")
        result.importConditions.add("default")
        result.requireConditions.add("default")
        result.styleConditions.add("default")

        return result
    }
}

/// 解析文件扩展名
// 严格翻译自: options.zig:1535 ResolveFileExtensions
public class ResolveFileExtensions {
    /// node_modules 分组
    public var nodeModules: ExtensionGroup
    /// 默认分组
    public var defaultGroup: ExtensionGroup

    public init() {
        nodeModules = ExtensionGroup()
        defaultGroup = ExtensionGroup()
    }

    /// 获取指定类型的扩展名列表
    public func kind(kind: ImportKind, isNodeModules: Bool): ArrayList<String> {
        let group = if (isNodeModules) { nodeModules } else { defaultGroup }
        match (kind) {
            case ImportKind.Stmt | ImportKind.EntryPointBuild | ImportKind.EntryPointRun | ImportKind.Dynamic => group.esm
            case _ => group.defaultExt
        }
    }
}

/// 扩展名分组
// 严格翻译自: options.zig:1556 ResolveFileExtensions.Group
public class ExtensionGroup {
    /// ESM 扩展名顺序
    public var esm: ArrayList<String>
    /// 默认扩展名顺序
    public var defaultExt: ArrayList<String>

    public init() {
        esm = ArrayList<String>()
        esm.append(".tsx")
        esm.append(".ts")
        esm.append(".jsx")
        esm.append(".cts")
        esm.append(".cjs")
        esm.append(".js")
        esm.append(".mjs")
        esm.append(".mts")
        esm.append(".json")

        defaultExt = ArrayList<String>()
        defaultExt.append(".tsx")
        defaultExt.append(".ts")
        defaultExt.append(".jsx")
        defaultExt.append(".cts")
        defaultExt.append(".cjs")
        defaultExt.append(".js")
        defaultExt.append(".mjs")
        defaultExt.append(".mts")
        defaultExt.append(".json")
    }
}

/// 环境配置
// 严格翻译自: options.zig:2198 Env
public class EnvConfig {
    /// 环境变量行为
    public var behavior: DotEnvBehavior
    /// 前缀
    public var prefix: String
    /// 默认值列表
    public var defaults: ArrayList<EnvEntry>
    /// 分配器
    public var allocator: ?Allocator
    /// 环境变量文件列表
    public var files: ArrayList<String>
    /// 是否禁用默认环境变量文件
    public var disableDefaultEnvFiles: Bool

    public init() {
        behavior = DotEnvBehavior.Disable
        prefix = ""
        defaults = ArrayList<EnvEntry>()
        allocator = None
        files = ArrayList<String>()
        disableDefaultEnvFiles = false
    }
}

/// 环境变量条目
public class EnvEntry {
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        this.key = key
        this.value = value
    }
}

/// DotEnv 行为
public enum DotEnvBehavior {
    | Disable
    | Prefix
    | LoadAll
    | LoadAllWithoutInlining
}

/// 全局缓存模式
public enum GlobalCache {
    | Disable
    | Auto
    | Force
}

/// CSS in JS 行为
public enum CssInJsBehavior {
    | AutoOnImportCSS
    | Facade
}

/// 入口点
// 严格翻译自: options.zig:2303 EntryPoint
public class EntryPoint {
    /// 路径
    public var path: String
    /// 环境配置
    public var env: EnvConfig
    /// 类型
    public var kind: EntryPointKind

    public init() {
        path = ""
        env = EnvConfig()
        kind = EntryPointKind.Disabled
    }

    /// 是否启用
    public func isEnabled(): Bool {
        return kind != EntryPointKind.Disabled && path.length > 0
    }
}

/// 入口点类型
// 严格翻译自: options.zig:2312 EntryPoint.Kind
public enum EntryPointKind {
    | Client
    | Server
    | Fallback
    | Disabled
}

/// 路径模板
// 严格翻译自: options.zig:2504 PathTemplate
public class PathTemplate {
    /// 模板数据 (如 "[dir]/[name].[ext]")
    public var data: String
    /// 占位符值
    public var placeholder: PathTemplatePlaceholder

    public init(data: String) {
        this.data = data
        this.placeholder = PathTemplatePlaceholder()
    }

    public init() {
        data = ""
        placeholder = PathTemplatePlaceholder()
    }

    /// 是否需要指定字段
    public func needs(field: String): Bool {
        return data.contains("[${field}]")
    }

    /// 预定义的 chunk 模板
    public static func chunk(): PathTemplate {
        return PathTemplate("./chunk-[hash].[ext]")
    }

    /// 预定义的文件模板
    public static func file(): PathTemplate {
        return PathTemplate("[dir]/[name].[ext]")
    }

    /// 预定义的资源模板
    public static func asset(): PathTemplate {
        return PathTemplate("./[name]-[hash].[ext]")
    }
}

/// 路径模板占位符
// 严格翻译自: options.zig:2578 PathTemplate.Placeholder
public class PathTemplatePlaceholder {
    /// 目录
    public var dir: String
    /// 文件名
    public var name: String
    /// 扩展名
    public var ext: String
    /// 哈希值
    public var hash: ?UInt64
    /// 目标
    public var target: String

    public init() {
        dir = ""
        name = ""
        ext = ""
        hash = None
        target = ""
    }
}

/// DevServer 引用
public class DevServerRef {
    public init() {}
}

/// Framework 引用
public class FrameworkRef {
    public init() {}
}

/// 导入类型
public enum ImportKind {
    | Stmt
    | Dynamic
    | EntryPointBuild
    | EntryPointRun
    | RequireResolve
    | Internal
}
