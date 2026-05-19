// 严格翻译自: src/bundler/options.zig (~2655行)
// bao_bundler - 打包选项: 定义 Bundle/Transform 选项、加载器类型、目标平台等
package bao_bundler

import bao_core.*
import bao_collections.*
import bao_parser.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// 写入目标
// 严格翻译自: options.zig:8 WriteDestination
// ============================================================================

/// 写入目标
public enum WriteDestination {
    | Stdout   // 输出到标准输出
    | Disk     // 写入磁盘
}

// ============================================================================
// 允许未解析模式
// 严格翻译自: options.zig:53 AllowUnresolved
// ============================================================================

/// 允许未解析模式
public class AllowUnresolved {
    /// 模式类型
    public var mode: AllowUnresolvedMode
    /// glob 模式列表
    public var patterns: Array<String>

    /// 默认值
    public static let default: AllowUnresolved = AllowUnresolved(AllowUnresolvedMode.All)

    public init(mode: AllowUnresolvedMode) {
        this.mode = mode
        this.patterns = []
    }

    public init(patterns: Array<String>) {
        this.mode = AllowUnresolvedMode.Patterns
        this.patterns = patterns
    }

    /// 从字符串数组创建
    // 严格翻译自: options.zig:65 fromStrings()
    public static func fromStrings(strs: Array<String>): AllowUnresolved {
        if (strs.size == 0) {
            return AllowUnresolved(AllowUnresolvedMode.None_)
        }
        for (s in strs) {
            if (s == "*") {
                return AllowUnresolved(AllowUnresolvedMode.All)
            }
        }
        return AllowUnresolved(strs)
    }

    /// 检查是否允许给定的形状
    // 严格翻译自: options.zig:72 allows()
    public func allows(shape: String): Bool {
        match (mode) {
            case AllowUnresolvedMode.All => return true
            case AllowUnresolvedMode.None_ => return false
            case AllowUnresolvedMode.Patterns =>
                // 简化: glob 匹配
                for (p in patterns) {
                    if (globMatch(p, shape)) {
                        return true
                    }
                }
                return false
        }
    }

    /// 简化的 glob 匹配
    private func globMatch(pattern: String, text: String): Bool {
        return text.startsWith(pattern) || text == pattern
    }
}

/// 允许未解析模式
public enum AllowUnresolvedMode {
    | All       // 跳过所有检查
    | None_     // 总是报错
    | Patterns  // glob 模式
}

// ============================================================================
// 外部模块配置
// 严格翻译自: options.zig:83 ExternalModules
// ============================================================================

/// 外部模块配置
// 严格翻译自: options.zig:83 ExternalModules
public class ExternalModules {
    /// node_modules 外部模块集合
    public var nodeModules: HashSet<String>
    /// 绝对路径外部模块集合
    public var absPaths: HashSet<String>
    /// 通配符模式列表
    public var patterns: Array<WildcardPattern>

    public init() {
        nodeModules = HashSet<String>()
        absPaths = HashSet<String>()
        patterns = [WildcardPattern("/bun:", "")]
    }

    /// 初始化外部模块
    // 严格翻译自: options.zig:112 init()
    public static func init(
        externals: Array<String>,
        target: Target
    ): ExternalModules {
        var result = ExternalModules()

        // Node 目标: 添加 Node 内置模块
        match (target) {
            case Node =>
                for (pattern in NodeBuiltinPatterns) {
                    result.nodeModules.put(pattern)
                }
            case Bun =>
                // Bun 目标: 不添加 Node 内置模块
                ()
            case _ => ()
        }

        if (externals.size == 0) {
            return result
        }

        var patternsList = ArrayList<WildcardPattern>()
        patternsList.append(WildcardPattern("/bun:", ""))

        for (external in externals) {
            let starIndex = external.indexOf("*")
            match (starIndex) {
                case Some(i) =>
                    // 检查是否有第二个 *
                    let rest = external.substring(i + 1)
                    if (rest.indexOf("*") != None) {
                        // 错误: 不能有多个 *
                        return result
                    }
                    patternsList.append(WildcardPattern(
                        external.substring(0, i),
                        external.substring(i + 1)
                    ))
                case None =>
                    if (isPackagePath(external)) {
                        result.nodeModules.put(external)
                    } else {
                        // 绝对路径
                        result.absPaths.put(external)
                    }
            }
        }

        result.patterns = patternsList.toArray()
        return result
    }

    /// 检查是否是 Node 内置模块
    // 严格翻译自: options.zig:93 isNodeBuiltin()
    public static func isNodeBuiltin(str: String): Bool {
        for (builtin in NodeBuiltinPatterns) {
            if (str == builtin || str == "node:${builtin}") {
                return true
            }
        }
        return false
    }

    /// 检查是否是包路径
    private static func isPackagePath(external: String): Bool {
        return !external.startsWith(".") && !external.startsWith("/")
    }
}

/// 通配符模式
// 严格翻译自: options.zig:88 ExternalModules.WildcardPattern
public class WildcardPattern {
    public var prefix: String
    public var suffix: String

    public init(prefix: String, suffix: String) {
        this.prefix = prefix
        this.suffix = suffix
    }
}

/// Node 内置模块模式列表
public let NodeBuiltinPatterns: Array<String> = [
    "assert", "async_hooks", "buffer", "child_process", "cluster",
    "console", "constants", "crypto", "dgram", "diagnostics_channel",
    "dns", "domain", "events", "fs", "http", "http2", "https",
    "inspector", "module", "net", "os", "path", "perf_hooks",
    "process", "punycode", "querystring", "readline", "repl",
    "stream", "string_decoder", "sys", "test", "timers", "tls",
    "trace_events", "tty", "url", "util", "v8", "vm", "wasi",
    "worker_threads", "zlib"
]

/// Bun Node 兼容内置模块列表
// 严格翻译自: options.zig:248 BunNodeBuiltinPatternsCompat
public let BunNodeBuiltinPatternsCompat: Array<String> = [
    "assert", "async_hooks", "child_process", "cluster",
    "console", "constants", "crypto", "dgram", "diagnostics_channel",
    "dns", "domain", "events", "http", "http2", "https",
    "inspector", "module", "net", "os", "perf_hooks",
    "punycode", "querystring", "readline", "repl",
    "stream", "string_decoder", "sys", "timers", "tls",
    "trace_events", "tty", "url", "util", "v8", "vm", "wasi",
    "worker_threads", "zlib"
]

// ============================================================================
// 模块类型
// 严格翻译自: options.zig:368 ModuleType
// ============================================================================

/// 模块类型
public enum ModuleType {
    | Unknown
    | CJS      // CommonJS
    | ESM      // ES Module

    /// 从字符串列表解析
    public static func fromString(str: String): ModuleType {
        match (str) {
            case "commonjs" => ModuleType.CJS
            case "module" => ModuleType.ESM
            case _ => ModuleType.Unknown
        }
    }
}

// ============================================================================
// 加载器类型
// 严格翻译自: options.zig:568 Loader
// Bun 支持的所有文件加载器类型
// ============================================================================

/// 加载器类型
// 严格翻译自: options.zig:568 Loader
public enum Loader {
    | Jsx             // .jsx
    | Js              // .js, .mjs, .cjs
    | Ts              // .ts, .mts, .cts
    | Tsx             // .tsx
    | Css             // .css
    | File            // 文件 (复制)
    | Json            // .json
    | Jsonc           // .jsonc
    | Toml            // .toml
    | Wasm            // .wasm
    | Napi            // .node
    | Base64          // base64 编码
    | DataUrl         // data URL
    | Text            // .txt
    | Bunsh           // .sh (Bun shell)
    | Sqlite          // .sqlite
    | SqliteEmbedded  // .sqlite (嵌入)
    | Html            // .html
    | Yaml            // .yaml, .yml
    | Json5           // .json5
    | Md              // .md, .markdown

    /// 是否是 CSS
    public func isCSS(): Bool {
        match (this) {
            case Css => true
            case _ => false
        }
    }

    /// 是否是 JS 类语言
    public func isJSLike(): Bool {
        match (this) {
            case Jsx | Js | Ts | Tsx => true
            case _ => false
        }
    }

    /// 是否是 TypeScript
    public func isTypeScript(): Bool {
        match (this) {
            case Ts | Tsx => true
            case _ => false
        }
    }

    /// 是否是 JSX
    public func isJSX(): Bool {
        match (this) {
            case Jsx | Tsx => true
            case _ => false
        }
    }

    /// 是否是 JS 类语言 (包含 isJSLike)
    // 严格翻译自: options.zig:859 isJavaScriptLike()
    public func isJavaScriptLike(): Bool {
        return isJSLike()
    }

    /// 是否是 JS 类语言或 JSON
    public func isJavaScriptLikeOrJSON(): Bool {
        match (this) {
            case Jsx | Js | Ts | Tsx | Json | Jsonc | Toml | Yaml | Json5 => true
            case _ => false
        }
    }

    /// 是否可以在打包时复制
    public func shouldCopyForBundling(): Bool {
        match (this) {
            case File | Napi | Sqlite | SqliteEmbedded | Wasm => true
            case _ => false
        }
    }

    /// 是否可以有 sourcemap
    public func canHaveSourceMap(): Bool {
        match (this) {
            case Jsx | Js | Ts | Tsx => true
            case _ => false
        }
    }

    /// 是否可以被 Bun 运行
    public func canBeRunByBun(): Bool {
        match (this) {
            case Jsx | Js | Ts | Tsx | Wasm | Bunsh => true
            case _ => false
        }
    }

    /// 处理空文件
    public func handlesEmptyFile(): Bool {
        match (this) {
            case Wasm | File | Text => true
            case _ => false
        }
    }

    /// 是否是 SQLite
    // 严格翻译自: options.zig:625 isSQLite()
    public func isSQLite(): Bool {
        match (this) {
            case Sqlite | SqliteEmbedded => true
            case _ => false
        }
    }

    /// 从字符串解析
    public static func fromString(slice: String): ?Loader {
        var s = slice
        if (s.size > 0 && s[0] == '.') {
            s = s.substring(1)
        }

        match (s) {
            case "js" | "mjs" | "cjs" => Loader.Js
            case "jsx" => Loader.Jsx
            case "ts" | "mts" | "cts" => Loader.Ts
            case "tsx" => Loader.Tsx
            case "css" => Loader.Css
            case "json" => Loader.Json
            case "jsonc" => Loader.Jsonc
            case "toml" => Loader.Toml
            case "wasm" => Loader.Wasm
            case "napi" | "node" => Loader.Napi
            case "dataurl" => Loader.DataUrl
            case "base64" => Loader.Base64
            case "txt" | "text" => Loader.Text
            case "sh" => Loader.Bunsh
            case "sqlite" => Loader.Sqlite
            case "sqlite_embedded" => Loader.SqliteEmbedded
            case "html" => Loader.Html
            case "yaml" | "yml" => Loader.Yaml
            case "json5" => Loader.Json5
            case "md" | "markdown" => Loader.Md
            case _ => None
        }
    }

    /// 从 API Loader 转换
    // 严格翻译自: options.zig:823 fromAPI()
    public static func fromAPI(loader: Int64): Loader {
        // 简化: 根据 API 值映射
        match (loader) {
            case 0 => Loader.Jsx
            case 1 => Loader.Js
            case 2 => Loader.Ts
            case 3 => Loader.Tsx
            case 4 => Loader.Css
            case 5 => Loader.File
            case 6 => Loader.Json
            case 7 => Loader.Jsonc
            case 8 => Loader.Toml
            case 9 => Loader.Wasm
            case 10 => Loader.Napi
            case 11 => Loader.Base64
            case 12 => Loader.DataUrl
            case 13 => Loader.Text
            case 14 => Loader.Bunsh
            case 15 => Loader.Sqlite
            case 16 => Loader.SqliteEmbedded
            case 17 => Loader.Html
            case 18 => Loader.Yaml
            case 19 => Loader.Json5
            case 20 => Loader.Md
            case _ => Loader.File
        }
    }

    /// 转换为 API Loader
    // 严格翻译自: options.zig:799 toAPI()
    public func toAPI(): Int64 {
        match (this) {
            case Jsx => 0
            case Js => 1
            case Ts => 2
            case Tsx => 3
            case Css => 4
            case File => 5
            case Json => 6
            case Jsonc => 7
            case Toml => 8
            case Wasm => 9
            case Napi => 10
            case Base64 => 11
            case DataUrl => 12
            case Text => 13
            case Bunsh => 14
            case Sqlite => 15
            case SqliteEmbedded => 16
            case Html => 17
            case Yaml => 18
            case Json5 => 19
            case Md => 20
        }
    }

    /// 从文件名获取加载器
    // 严格翻译自: options.zig:877 forFileName()
    public static func forFileName(filename: String, loaders: HashMap<String, Loader>): ?Loader {
        let ext = Path.extname(filename)
        if (ext.size == 0 || ext == ".") {
            return None
        }
        return loaders.get(ext)
    }

    /// 获取标准输入文件名
    public func stdinName(): String {
        match (this) {
            case Jsx => "input.jsx"
            case Js => "input.js"
            case Ts => "input.ts"
            case Tsx => "input.tsx"
            case Css => "input.css"
            case File => "input"
            case Json => "input.json"
            case Toml => "input.toml"
            case Yaml => "input.yaml"
            case Json5 => "input.json5"
            case Wasm => "input.wasm"
            case Napi => "input.node"
            case Text => "input.txt"
            case Bunsh => "input.sh"
            case Html => "input.html"
            case Md => "input.md"
            case _ => "input"
        }
    }

    /// 副作用评估
    public func sideEffects(): SideEffects {
        match (this) {
            case Text | Json | Jsonc | Toml | Yaml | Json5 | File | Md => SideEffects.NoSideEffects_PureData
            case _ => SideEffects.HasSideEffects
        }
    }

    /// 禁用 HTML
    public func disableHTML(): Loader {
        match (this) {
            case Html => Loader.File
            case _ => this
        }
    }

    /// 是否支持客户端入口点
    public func supportsClientEntryPoint(): Bool {
        match (this) {
            case Jsx | Js | Ts | Tsx => true
            case _ => false
        }
    }
}

// ============================================================================
// 默认加载器映射
// 严格翻译自: options.zig:1041 defaultLoaders
// ============================================================================

/// 默认加载器映射
public func defaultLoaders(): HashMap<String, Loader> {
    var loaders = HashMap<String, Loader>()
    loaders.put(".jsx", Loader.Jsx)
    loaders.put(".json", Loader.Json)
    loaders.put(".js", Loader.Jsx)
    loaders.put(".mjs", Loader.Js)
    loaders.put(".cjs", Loader.Js)
    loaders.put(".css", Loader.Css)
    loaders.put(".ts", Loader.Ts)
    loaders.put(".tsx", Loader.Tsx)
    loaders.put(".mts", Loader.Ts)
    loaders.put(".cts", Loader.Ts)
    loaders.put(".toml", Loader.Toml)
    loaders.put(".yaml", Loader.Yaml)
    loaders.put(".yml", Loader.Yaml)
    loaders.put(".wasm", Loader.Wasm)
    loaders.put(".node", Loader.Napi)
    loaders.put(".txt", Loader.Text)
    loaders.put(".text", Loader.Text)
    loaders.put(".html", Loader.Html)
    loaders.put(".jsonc", Loader.Jsonc)
    loaders.put(".json5", Loader.Json5)
    loaders.put(".md", Loader.Md)
    loaders.put(".markdown", Loader.Md)
    loaders.put(".sh", Loader.Bunsh)
    return loaders
}

// ============================================================================
// 目标平台
// 严格翻译自: options.zig:379 Target
// ============================================================================

/// 目标平台
// 严格翻译自: options.zig:379 Target
public enum Target {
    | Browser                 // 浏览器
    | Bun                     // Bun 运行时
    | BunMacro                // Bun 宏
    | Node                    // Node.js
    | BakeServerComponentsSsr // Bake SSR

    /// 从 API Target 转换
    // 严格翻译自: options.zig:465 from()
    public static func from(apiTarget: ?String): Target {
        match (apiTarget) {
            case Some(t) =>
                match (t) {
                    case "node" => Target.Node
                    case "browser" => Target.Browser
                    case "bun" => Target.Bun
                    case "bun_macro" | "macro" => Target.BunMacro
                    case _ => Target.Browser
                }
            case None => Target.Browser
        }
    }

    /// 转换为 API Target
    // 严格翻译自: options.zig:398 toAPI()
    public func toAPI(): String {
        match (this) {
            case Node => "node"
            case Browser => "browser"
            case Bun => "bun"
            case BunMacro => "bun_macro"
            case BakeServerComponentsSsr => "bun"
        }
    }

    /// 是否是服务端
    public func isServerSide(): Bool {
        match (this) {
            case BunMacro | Node | Bun | BakeServerComponentsSsr => true
            case _ => false
        }
    }

    /// 是否是 Bun
    public func isBun(): Bool {
        match (this) {
            case BunMacro | Bun | BakeServerComponentsSsr => true
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
    // 严格翻译自: options.zig:428 processBrowserDefineValue()
    public func processBrowserDefineValue(): ?String {
        match (this) {
            case Browser => "true"
            case _ => None
        }
    }

    /// 获取默认主字段
    public func defaultMainFields(): Array<String> {
        match (this) {
            case Node => ["main", "module"]
            case Browser => ["browser", "module", "jsnext:main", "main"]
            case Bun | BunMacro | BakeServerComponentsSsr => ["module", "main", "jsnext:main"]
        }
    }

    /// 获取默认条件
    public func defaultConditions(): Array<String> {
        match (this) {
            case Node => ["node"]
            case Browser => ["browser", "module"]
            case Bun | BakeServerComponentsSsr => ["bun", "node"]
            case BunMacro => ["macro", "bun", "node"]
        }
    }

    /// Bake 图类型
    public func bakeGraph(): String {
        match (this) {
            case Browser => "client"
            case BakeServerComponentsSsr => "ssr"
            case BunMacro | Bun | Node => "server"
        }
    }

    /// 获取输出扩展名映射
    // 严格翻译自: options.zig:443 outExtensions()
    public func outExtensions(): HashMap<String, String> {
        var exts = HashMap<String, String>()
        let outExtensionsList = [".js", ".cjs", ".mts", ".cts", ".ts", ".tsx", ".jsx", ".json"]

        if (this == Target.Node) {
            for (ext in outExtensionsList) {
                exts.put(ext, ".mjs")
            }
        } else {
            exts.put(".mjs", ".js")
        }

        for (ext in outExtensionsList) {
            exts.put(ext, ".js")
        }

        return exts
    }
}

// ============================================================================
// 输出格式
// 严格翻译自: options.zig:560 Format
// ============================================================================

/// 输出格式
public enum OutputFormat {
    | ESM                   // ES Module
    | CJS                   // CommonJS
    | IIFE                  // IIFE (立即调用函数表达式)
    | InternalBakeDev       // Bake 开发模式内部格式

    /// 是否保持 ES6 导入/导出语法
    public func keepES6ImportExportSyntax(): Bool {
        match (this) {
            case ESM => true
            case _ => false
        }
    }

    /// 转为模块类型
    public func toModuleType(): ModuleType {
        return ModuleType.JavaScript
    }
}

// ============================================================================
// SourceMap 选项
// 严格翻译自: options.zig:1604 SourceMapOption
// ============================================================================

/// SourceMap 选项
public enum SourceMapOption {
    | None       // 不生成
    | Inline     // 内联
    | External   // 外部文件
    | Linked     // 链接 (注释)

    /// 从 API 转换
    // 严格翻译自: options.zig:1611 fromApi()
    public static func fromApi(sourceMap: ?String): SourceMapOption {
        match (sourceMap) {
            case Some("external") => SourceMapOption.External
            case Some("inline") => SourceMapOption.Inline
            case Some("linked") => SourceMapOption.Linked
            case _ => SourceMapOption.None
        }
    }

    /// 转换为 API
    // 严格翻译自: options.zig:1619 toAPI()
    public func toAPI(): String {
        match (this) {
            case External => "external"
            case Inline => "inline"
            case Linked => "linked"
            case None => "none"
        }
    }

    /// 是否有外部文件
    public func hasExternalFiles(): Bool {
        match (this) {
            case Linked | External => true
            case _ => false
        }
    }
}

// ============================================================================
// 包选项
// 严格翻译自: options.zig:1643 PackagesOption
// ============================================================================

/// 包选项
public enum PackagesOption {
    | Bundle    // 打包 node_modules
    | External  // 外部化 node_modules

    /// 从 API 转换
    // 严格翻译自: options.zig:1647 fromApi()
    public static func fromApi(packages: ?String): PackagesOption {
        match (packages) {
            case Some("external") => PackagesOption.External
            case _ => PackagesOption.Bundle
        }
    }

    /// 转换为 API
    // 严格翻译自: options.zig:1655 toAPI()
    public func toAPI(): String {
        match (this) {
            case External => "external"
            case Bundle => "bundle"
        }
    }
}

// ============================================================================
// 副作用
// ============================================================================

/// 副作用类型
public enum SideEffects {
    | HasSideEffects
    | NoSideEffects_PureData
}

// ============================================================================
// 导入路径格式
// 严格翻译自: options.zig:1899 ImportPathFormat
// ============================================================================

/// 导入路径格式
public enum ImportPathFormat {
    | Relative      // 相对路径
    | AbsoluteUrl   // 绝对 URL
    | AbsolutePath  // 绝对路径
    | PackagePath   // 包路径
}

// ============================================================================
// ESM 条件映射
// 严格翻译自: options.zig:1077 ESMConditions
// ============================================================================

/// ESM 条件映射
// 严格翻译自: options.zig:1077 ESMConditions
public class ESMConditions {
    /// 默认条件
    public var default_: HashSet<String>
    /// import 条件
    public var import_: HashSet<String>
    /// require 条件
    public var require: HashSet<String>
    /// style 条件
    public var style: HashSet<String>

    public init() {
        default_ = HashSet<String>()
        import_ = HashSet<String>()
        require = HashSet<String>()
        style = HashSet<String>()
    }

    /// 初始化 ESM 条件
    // 严格翻译自: options.zig:1083 init()
    public static func init(
        defaults: Array<String>,
        allowAddons: Bool,
        conditions: Array<String>
    ): ESMConditions {
        var cond = ESMConditions()

        // 设置特殊条件
        cond.import_.put("import")
        cond.require.put("require")
        cond.style.put("style")

        // 用户条件
        for (condition in conditions) {
            cond.import_.put(condition)
            cond.require.put(condition)
            cond.default_.put(condition)
        }

        // 默认条件
        for (default_ in defaults) {
            cond.default_.put(default_)
            cond.import_.put(default_)
            cond.require.put(default_)
            cond.style.put(default_)
        }

        // node-addons
        if (allowAddons) {
            cond.default_.put("node-addons")
            cond.import_.put("node-addons")
            cond.require.put("node-addons")
        }

        // default
        cond.default_.put("default")
        cond.import_.put("default")
        cond.require.put("default")
        cond.style.put("default")

        return cond
    }

    /// 克隆
    // 严格翻译自: options.zig:1133 clone()
    public func clone(): ESMConditions {
        var copy = ESMConditions()
        for (key in default_) { copy.default_.put(key) }
        for (key in import_) { copy.import_.put(key) }
        for (key in require) { copy.require.put(key) }
        for (key in style) { copy.style.put(key) }
        return copy
    }

    /// 追加条件列表
    // 严格翻译自: options.zig:1151 appendSlice()
    public func appendSlice(conditions: Array<String>): Unit {
        for (condition in conditions) {
            default_.put(condition)
            import_.put(condition)
            require.put(condition)
            style.put(condition)
        }
    }

    /// 追加单个条件
    // 严格翻译自: options.zig:1165 append()
    public func append(condition: String): Unit {
        default_.put(condition)
        import_.put(condition)
        require.put(condition)
        style.put(condition)
    }
}

// ============================================================================
// JSX 配置
// 严格翻译自: options.zig:1173 JSX
// ============================================================================

/// JSX 运行时
public enum JsxRuntime {
    | Classic    // React.createElement
    | Automatic  // jsx runtime
}

/// JSX 配置
// 严格翻译自: options.zig:1187 JSX.Pragma
public class JsxPragma {
    /// 工厂函数 (如 ["React", "createElement"])
    public var factory: Array<String>
    /// Fragment (如 ["React", "Fragment"])
    public var fragment: Array<String>
    /// 运行时
    public var runtime: JsxRuntime
    /// 导入源
    public var importSource: JsxImportSource
    /// 经典导入源
    public var classicImportSource: String
    /// 包名
    public var packageName: String
    /// 是否开发模式
    public var development: Bool
    /// 是否解析 JSX
    public var parse: Bool
    /// 是否有副作用
    public var sideEffects: Bool

    public init() {
        this.factory = ["React", "createElement"]
        this.fragment = ["React", "Fragment"]
        this.runtime = JsxRuntime.Automatic
        this.importSource = JsxImportSource()
        this.classicImportSource = "react"
        this.packageName = "react"
        this.development = true
        this.parse = true
        this.sideEffects = false
    }

    /// 获取导入源
    // 严格翻译自: options.zig:1222 importSource()
    public func getImportSource(): String {
        return if (development) { importSource.development } else { importSource.production }
    }

    /// 从 API 创建
    // 严格翻译自: options.zig:1333 fromApi()
    public static func fromApi(
        factory: String,
        fragment: String,
        runtime: JsxRuntime,
        importSource: String,
        development: Bool,
        sideEffects: Bool
    ): JsxPragma {
        var pragma = JsxPragma()
        if (factory.size > 0) {
            pragma.factory = factory.split(".")
        }
        if (fragment.size > 0) {
            pragma.fragment = fragment.split(".")
        }
        pragma.runtime = runtime
        pragma.sideEffects = sideEffects
        if (importSource.size > 0) {
            pragma.packageName = importSource
            pragma.classicImportSource = importSource
            pragma.importSource = JsxImportSource(
                "${importSource}/jsx-dev-runtime",
                "${importSource}/jsx-runtime"
            )
        }
        pragma.development = development
        pragma.parse = true
        return pragma
    }

    /// 解析包名
    // 严格翻译自: options.zig:1229 parsePackageName()
    public static func parsePackageName(str: String): String {
        if (str.size == 0) { return str }
        if (str[0] == '@') {
            let firstSlash = str.indexOf("/")
            match (firstSlash) {
                case Some(i) =>
                    let remainder = str.substring(i + 1)
                    let lastSlash = remainder.indexOf("/")
                    match (lastSlash) {
                        case Some(j) => return str.substring(0, i + 1 + j + 1)
                        case None => ()
                    }
                case None => ()
            }
        }
        let firstSlash = str.indexOf("/")
        match (firstSlash) {
            case Some(i) => return str.substring(0, i)
            case None => return str
        }
    }

    /// 是否是 React 类
    // 严格翻译自: options.zig:1248 isReactLike()
    public func isReactLike(): Bool {
        return packageName == "react" ||
               packageName == "@emotion/jsx" ||
               packageName == "@emotion/react"
    }

    /// 设置生产模式
    // 严格翻译自: options.zig:1280 setProduction()
    public func setProduction(isProduction: Bool): Unit {
        development = !isProduction
    }

    /// 将成员列表转为组件 (如果不同)
    // 严格翻译自: options.zig:1297 memberListToComponentsIfDifferent()
    public static func memberListToComponentsIfDifferent(
        original: Array<String>,
        new_: String
    ): Array<String> {
        let parts = new_.split(".")
        // 简化: 直接返回新值
        return parts
    }
}

/// JSX 导入源
public class JsxImportSource {
    public var development: String
    public var production: String

    public init() {
        this.development = "react/jsx-dev-runtime"
        this.production = "react/jsx-runtime"
    }

    public init(development: String, production: String) {
        this.development = development
        this.production = production
    }
}

/// JSX 默认值
// 严格翻译自: options.zig:1284 JSX.Pragma.Defaults
public class JsxDefaults {
    public static let Factory: Array<String> = ["React", "createElement"]
    public static let Fragment: Array<String> = ["React", "Fragment"]
    public static let ImportSourceDev: String = "react/jsx-dev-runtime"
    public static let ImportSource: String = "react/jsx-runtime"
    public static let JSXFunction: String = "jsx"
    public static let JSXStaticFunction: String = "jsxs"
    public static let JSXFunctionDev: String = "jsxDEV"
}

// ============================================================================
// CSS 导入行为
// ============================================================================

/// CSS 导入行为
public enum CssInJsBehavior {
    | AutoOnImportCSS
    | Facade
}

// ============================================================================
// 默认用户定义
// 严格翻译自: options.zig:1362 DefaultUserDefines
// ============================================================================

/// 默认用户定义
public class DefaultUserDefines {
    public static let NodeEnvKey: String = "process.env.NODE_ENV"
    public static let NodeEnvValue: String = "\"development\""
    public static let ProcessBrowserDefineKey: String = "process.browser"
}

// ============================================================================
// 扩展名解析顺序
// 严格翻译自: options.zig:1535 ResolveFileExtensions
// ============================================================================

/// 扩展名解析
// 严格翻译自: options.zig:1535 ResolveFileExtensions
public class ResolveFileExtensions {
    /// node_modules 分组
    public var nodeModules: ExtensionGroup
    /// 默认分组
    public var default_: ExtensionGroup

    public init() {
        nodeModules = ExtensionGroup(
            ExtensionDefaults.NodeModulesModuleExtensionOrder,
            ExtensionDefaults.NodeModulesExtensionOrder
        )
        default_ = ExtensionGroup(
            ExtensionDefaults.ModuleExtensionOrder,
            ExtensionDefaults.ExtensionOrder
        )
    }

    /// 获取对应分组
    public func group(isNodeModules: Bool): ExtensionGroup {
        return if (isNodeModules) { nodeModules } else { default_ }
    }

    /// 获取对应扩展名列表
    // 严格翻译自: options.zig:1549 kind()
    public func kind(kind_: ImportKind, isNodeModules: Bool): Array<String> {
        let g = group(isNodeModules)
        match (kind_) {
            case Stmt | EntryPointBuild | EntryPointRun | Dynamic => return g.esm
            case _ => return g.default_
        }
    }
}

/// 扩展名分组
// 严格翻译自: options.zig:1556 ResolveFileExtensions.Group
public class ExtensionGroup {
    public var esm: Array<String>
    public var default_: Array<String>

    public init(esm: Array<String>, default_: Array<String>) {
        this.esm = esm
        this.default_ = default_
    }
}

/// 扩展名顺序
public class ExtensionOrder {
    /// 默认扩展名顺序
    public static let Default: Array<String> = [
        ".tsx", ".ts", ".jsx", ".cts", ".cjs", ".js", ".mjs", ".mts", ".json"
    ]
    /// 模块扩展名顺序
    public static let Module: Array<String> = [
        ".tsx", ".jsx", ".mts", ".ts", ".mjs", ".js", ".cts", ".cjs", ".json"
    ]
    /// 主字段扩展名顺序
    public static let MainField: Array<String> = [
        ".js", ".cjs", ".cts", ".tsx", ".ts", ".jsx", ".json"
    ]
    /// CSS 扩展名顺序
    public static let CSS: Array<String> = [".css"]
}

/// 扩展名默认值
// 严格翻译自: options.zig:1907 BundleOptions.Defaults
public class ExtensionDefaults {
    public static let ExtensionOrder: Array<String> = [
        ".tsx", ".ts", ".jsx", ".cts", ".cjs", ".js", ".mjs", ".mts", ".json"
    ]
    public static let MainFieldExtensionOrder: Array<String> = [
        ".js", ".cjs", ".cts", ".tsx", ".ts", ".jsx", ".json"
    ]
    public static let ModuleExtensionOrder: Array<String> = [
        ".tsx", ".jsx", ".mts", ".ts", ".mjs", ".js", ".cts", ".cjs", ".json"
    ]
    public static let CSSExtensionOrder: Array<String> = [".css"]
    public static let NodeModulesExtensionOrder: Array<String> = [
        ".jsx", ".cjs", ".js", ".mjs", ".mts", ".tsx", ".ts", ".cts", ".json"
    ]
    public static let NodeModulesModuleExtensionOrder: Array<String> = [
        ".mjs", ".jsx", ".mts", ".js", ".cjs", ".tsx", ".ts", ".cts", ".json"
    ]
}

// ============================================================================
// Bundle 选项
// 严格翻译自: options.zig:1670 BundleOptions
// 这是打包器的主要配置结构
// ============================================================================

/// Bundle 选项
// 严格翻译自: options.zig:1670 BundleOptions
/// BundleOptions is used when ResolveMode is not set to "disable".
/// BundleOptions is effectively webpack + babel
public class BundleOptions {
    /// 页脚
    public var footer: String
    /// 头部
    public var banner: String
    /// 定义
    public var define: HashMap<String, String>
    /// 丢弃
    public var drop: Array<String>
    /// 加载器映射
    public var loaders: HashMap<String, Loader>
    /// 解析目录
    public var resolveDir: String
    /// JSX 配置
    public var jsx: JsxPragma
    /// 发射装饰器元数据
    public var emitDecoratorMetadata: Bool
    /// 实验性装饰器
    public var experimentalDecorators: Bool
    /// 自动导入 JSX
    public var autoImportJsx: Bool
    /// 允许运行时
    public var allowRuntime: Bool
    /// 裁剪未使用的导入
    public var trimUnusedImports: ?Bool
    /// 将内置模块标记为外部
    public var markBuiltinsAsExternal: Bool
    /// 服务端组件
    public var serverComponents: Bool
    /// 热模块重载
    public var hotModuleReloading: Bool
    /// React 快速刷新
    public var reactFastRefresh: Bool
    /// 注入文件列表
    public var inject: ?Array<String>
    /// 源 (URL)
    public var origin: String
    /// 输出目录
    public var outputDir: String
    /// 根目录
    public var rootDir: String
    /// node_modules bundle URL
    public var nodeModulesBundleUrl: String
    /// node_modules bundle 路径
    public var nodeModulesBundlePrettyPath: String
    /// 是否写入
    public var write: Bool
    /// 保留符号链接
    public var preserveSymlinks: Bool
    /// 保留扩展名
    public var preserveExtensions: Bool
    /// 生产模式
    public var production: Bool
    /// 输出格式
    public var outputFormat: OutputFormat
    /// 在查询字符串中附加包版本
    public var appendPackageVersionInQueryString: Bool
    /// tsconfig 覆盖
    public var tsconfigOverride: ?String
    /// 目标平台
    public var target: Target
    /// 主字段
    public var mainFields: Array<String>
    /// 外部模块
    public var external: ExternalModules
    /// 允许未解析
    public var allowUnresolved: AllowUnresolved
    /// 入口点列表
    public var entryPoints: Array<String>
    /// 入口命名
    public var entryNaming: String
    /// 资源命名
    public var assetNaming: String
    /// chunk 命名
    public var chunkNaming: String
    /// 公共路径
    public var publicPath: String
    /// 扩展名解析顺序
    public var extensionOrder: ResolveFileExtensions
    /// 主字段扩展名顺序
    public var mainFieldExtensionOrder: Array<String>
    /// 额外 CJS 扩展名
    public var extraCjsExtensions: Array<String>
    /// 输出扩展名映射
    public var outExtensions: HashMap<String, String>
    /// 导入路径格式
    public var importPathFormat: ImportPathFormat
    /// 是否已加载 defines
    public var definesLoaded: Bool
    /// 环境变量配置
    public var env: EnvConfig
    /// 是否 polyfill node globals
    public var polyfillNodeGlobals: Bool
    /// 仅转换
    public var transformOnly: Bool
    /// 是否加载 tsconfig.json
    public var loadTsconfigJson: Bool
    /// 是否加载 package.json
    public var loadPackageJson: Bool
    /// 重写 jest 用于测试
    public var rewriteJestForTests: Bool
    /// 宏重映射
    public var macroRemap: HashMap<String, String>
    /// 无宏
    public var noMacros: Bool
    /// ESM 条件
    public var conditions: ESMConditions
    /// tree-shaking
    public var treeShaking: Bool
    /// 代码分割
    public var codeSplitting: Bool
    /// source map
    public var sourceMap: SourceMapOption
    /// 包选项
    public var packages: PackagesOption
    /// 禁用转译
    public var disableTranspilation: Bool
    /// 全局缓存
    public var globalCache: GlobalCache
    /// 离线安装优先
    public var preferOfflineInstall: Bool
    /// 最新安装优先
    public var preferLatestInstall: Bool
    /// 内联
    public var inlining: Bool
    /// 内联入口点 import.meta.main
    public var inlineEntrypointImportMetaMain: Bool
    /// 压缩空白
    public var minifyWhitespace: Bool
    /// 压缩语法
    public var minifySyntax: Bool
    /// 压缩标识符
    public var minifyIdentifiers: Bool
    /// 保留名称
    public var keepNames: Bool
    /// 死代码消除
    public var deadCodeElimination: Bool
    /// REPL 模式
    public var replMode: Bool
    /// CSS 分块
    public var cssChunking: Bool
    /// 忽略 DCE 注解
    public var ignoreDceAnnotations: Bool
    /// 发射 DCE 注解
    public var emitDceAnnotations: Bool
    /// 字节码
    public var bytecode: Bool
    /// 代码覆盖率
    public var codeCoverage: Bool
    /// 调试器
    public var debugger_: Bool
    /// 编译
    public var compile: Bool
    /// 编译为独立 HTML
    public var compileToStandaloneHtml: Bool
    /// metafile
    public var metafile: Bool
    /// metafile JSON 路径
    public var metafileJsonPath: String
    /// metafile Markdown 路径
    public var metafileMarkdownPath: String
    /// 服务插件
    public var servePlugins: ?Array<String>
    /// bunfig 路径
    public var bunfigPath: String
    /// 解包 CommonJS 包列表
    public var unwrapCommonjsPackages: Array<String>
    /// 支持多输出
    public var supportsMultipleOutputs: Bool
    /// 强制 NODE_ENV
    public var forceNodeEnv: ForceNodeEnv
    /// 忽略模块解析错误
    public var ignoreModuleResolutionErrors: Bool
    /// 优化导入
    public var optimizeImports: ?HashSet<String>

    public init() {
        footer = ""
        banner = ""
        define = HashMap<String, String>()
        drop = []
        loaders = defaultLoaders()
        resolveDir = "/"
        jsx = JsxPragma()
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
        outputDir = "out"
        rootDir = ""
        nodeModulesBundleUrl = ""
        nodeModulesBundlePrettyPath = ""
        write = false
        preserveSymlinks = false
        preserveExtensions = false
        production = false
        outputFormat = OutputFormat.ESM
        appendPackageVersionInQueryString = false
        tsconfigOverride = None
        target = Target.Browser
        mainFields = Target.Browser.defaultMainFields()
        external = ExternalModules()
        allowUnresolved = AllowUnresolved(AllowUnresolvedMode.All)
        entryPoints = []
        entryNaming = ""
        assetNaming = ""
        chunkNaming = ""
        publicPath = ""
        extensionOrder = ResolveFileExtensions()
        mainFieldExtensionOrder = ExtensionDefaults.MainFieldExtensionOrder
        extraCjsExtensions = []
        outExtensions = HashMap<String, String>()
        importPathFormat = ImportPathFormat.Relative
        definesLoaded = false
        env = EnvConfig()
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
        sourceMap = SourceMapOption.None
        packages = PackagesOption.Bundle
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
        debugger_ = false
        compile = false
        compileToStandaloneHtml = false
        metafile = false
        metafileJsonPath = ""
        metafileMarkdownPath = ""
        servePlugins = None
        bunfigPath = ""
        unwrapCommonjsPackages = BundleOptions.defaultUnwrapCommonjsPackages
        supportsMultipleOutputs = true
        forceNodeEnv = ForceNodeEnv.Unspecified
        ignoreModuleResolutionErrors = false
        optimizeImports = None
    }

    /// 默认解包 CommonJS 包列表
    // 严格翻译自: options.zig:1832 default_unwrap_commonjs_packages
    public static let defaultUnwrapCommonjsPackages: Array<String> = [
        "react", "react-is", "react-dom", "scheduler",
        "react-client", "react-server", "react-refresh"
    ]

    /// 是否是测试模式
    // 严格翻译自: options.zig:1821 isTest()
    public func isTest(): Bool {
        return rewriteJestForTests
    }

    /// 设置生产模式
    // 严格翻译自: options.zig:1825 setProduction()
    public func setProduction(value: Bool): Unit {
        if (forceNodeEnv == ForceNodeEnv.Unspecified) {
            production = value
            jsx.development = !value
        }
    }

    /// CSS 导入行为
    // 严格翻译自: options.zig:1842 cssImportBehavior()
    public func cssImportBehavior(): CssInJsBehavior {
        match (target) {
            case Browser => CssInJsBehavior.AutoOnImportCSS
            case _ => CssInJsBehavior.Facade
        }
    }

    /// defines 是否未设置
    // 严格翻译自: options.zig:1851 areDefinesUnset()
    public func areDefinesUnset(): Bool {
        return !definesLoaded
    }

    /// 加载 defines
    // 严格翻译自: options.zig:1855 loadDefines()
    public func loadDefines(): Unit {
        if (definesLoaded) {
            return
        }
        // 简化: 设置默认 NODE_ENV
        if (!define.contains("process.env.NODE_ENV")) {
            define.put("process.env.NODE_ENV",
                if (production) { "\"production\"" } else { "\"development\"" }
            )
        }
        if (!define.contains("process.env.BUN_ENV")) {
            define.put("process.env.BUN_ENV",
                if (production) { "\"production\"" } else { "\"development\"" }
            )
        }
        // 浏览器 define
        match (target.processBrowserDefineValue()) {
            case Some(value) => define.put("process.browser", value)
            case None => ()
        }
        definesLoaded = true
    }

    /// 获取加载器
    // 严格翻译自: options.zig:1895 loader()
    public func loader(ext: String): Loader {
        match (loaders.get(ext)) {
            case Some(l) => return l
            case None => return Loader.File
        }
    }

    /// 从 API 创建
    // 严格翻译自: options.zig:1973 fromApi()
    public static func fromApi(
        entryPoints: Array<String>,
        target: ?String,
        outputDir: String,
        define: HashMap<String, String>,
        loaders: HashMap<String, Loader>,
        external: Array<String>,
        sourceMap: ?String,
        mainFields: Array<String>,
        conditions: Array<String>,
        jsxFactory: String,
        jsxFrag: String,
        jsxRuntime: JsxRuntime,
        jsxImportSource: String,
        development: Bool
    ): BundleOptions {
        var opts = BundleOptions()
        opts.target = Target.from(target)
        opts.entryPoints = entryPoints
        opts.outputDir = if (outputDir.size > 0) { outputDir } else { "out" }
        opts.define = define
        opts.loaders = loaders
        opts.mainFields = if (mainFields.size > 0) { mainFields } else { opts.target.defaultMainFields() }

        // 外部模块
        opts.external = ExternalModules.init(external, opts.target)

        // 输出扩展名
        opts.outExtensions = opts.target.outExtensions()

        // source map
        opts.sourceMap = SourceMapOption.fromApi(sourceMap)

        // ESM 条件
        opts.conditions = ESMConditions.init(
            opts.target.defaultConditions(),
            true,
            conditions
        )

        // tree-shaking
        opts.treeShaking = opts.target.isBun() || opts.production
        opts.inlining = opts.treeShaking
        if (opts.inlining) {
            opts.minifySyntax = true
        }

        // 目标特定设置
        match (opts.target) {
            case Node =>
                opts.importPathFormat = ImportPathFormat.Relative
                opts.allowRuntime = false
            case Bun =>
                opts.importPathFormat = ImportPathFormat.AbsolutePath
            case _ => ()
        }

        // 浏览器 polyfill
        opts.polyfillNodeGlobals = opts.target == Target.Browser

        // JSX
        opts.jsx = JsxPragma.fromApi(
            jsxFactory, jsxFrag, jsxRuntime,
            jsxImportSource, development, false
        )

        return opts
    }
}

/// 强制 NODE_ENV 模式
// 严格翻译自: options.zig:1815 ForceNodeEnv
public enum ForceNodeEnv {
    | Unspecified
    | Development
    | Production
}

// ============================================================================
// 全局缓存
// ============================================================================

/// 全局缓存模式
public enum GlobalCache {
    | Disable
    | Auto
    | Fallback
}

// ============================================================================
// 转换选项
// 严格翻译自: options.zig:2108 TransformOptions
// ============================================================================

/// 转换选项
// 严格翻译自: options.zig:2108 TransformOptions
public class TransformOptions {
    /// 页脚
    public var footer: String
    /// 头部
    public var banner: String
    /// 定义
    public var define: HashMap<String, String>
    /// 加载器
    public var loader: Loader
    /// 解析目录
    public var resolveDir: String
    /// JSX 配置
    public var jsx: ?JsxPragma
    /// React 快速刷新
    public var reactFastRefresh: Bool
    /// 注入文件列表
    public var inject: ?Array<String>
    /// 源 (URL)
    public var origin: String
    /// 保留符号链接
    public var preserveSymlinks: Bool
    /// 入口点
    public var entryPoint: String
    /// 解析路径
    public var resolvePaths: Bool
    /// tsconfig 覆盖
    public var tsconfigOverride: ?String
    /// 目标平台
    public var target: Target
    /// 主字段
    public var mainFields: Array<String>

    public init() {
        footer = ""
        banner = ""
        define = HashMap<String, String>()
        loader = Loader.Js
        resolveDir = "/"
        jsx = None
        reactFastRefresh = false
        inject = None
        origin = ""
        preserveSymlinks = false
        entryPoint = ""
        resolvePaths = false
        tsconfigOverride = None
        target = Target.Browser
        mainFields = Target.Browser.defaultMainFields()
    }

    /// 未缓存初始化
    // 严格翻译自: options.zig:2126 initUncached()
    public static func initUncached(entryPointName: String, code: String): TransformOptions {
        var opts = TransformOptions()
        opts.entryPoint = entryPointName
        opts.resolveDir = Path.dirname(entryPointName)
        opts.mainFields = Target.Browser.defaultMainFields()

        // 默认定义
        opts.define.put("process.env.NODE_ENV", "development")

        // 加载器
        let ext = Path.extname(entryPointName)
        match (defaultLoaders().get(ext)) {
            case Some(l) => opts.loader = l
            case None => opts.loader = Loader.File
        }

        // JSX
        if (opts.loader.isJSX()) {
            opts.jsx = JsxPragma()
        }

        return opts
    }
}

// ============================================================================
// 转换结果
// 严格翻译自: options.zig:2163 TransformResult
// ============================================================================

/// 转换结果
public class TransformResult {
    /// 错误列表
    public var errors: Array<LogMsg>
    /// 警告列表
    public var warnings: Array<LogMsg>
    /// 输出文件列表
    public var outputFiles: Array<OutputFile>
    /// 输出基目录
    public var outbase: String

    public init(outbase: String) {
        errors = []
        warnings = []
        outputFiles = []
        this.outbase = outbase
    }
}

/// 日志消息 (简化)
public class LogMsg {
    public var kind: String
    public var text: String

    public init(kind: String, text: String) {
        this.kind = kind
        this.text = text
    }
}

/// 输出文件 (简化)
public class OutputFile {
    public var outputPath: String
    public var content: Array<Byte>

    public init(outputPath: String, content: Array<Byte>) {
        this.outputPath = outputPath
        this.content = content
    }
}

// ============================================================================
// 环境配置
// 严格翻译自: options.zig:2198 Env
// ============================================================================

/// 环境配置
// 严格翻译自: options.zig:2198 Env
public class EnvConfig {
    /// 行为
    public var behavior: DotEnvBehavior
    /// 前缀
    public var prefix: String
    /// 默认值列表
    public var defaults: HashMap<String, String>
    /// 环境文件列表
    public var files: Array<String>
    /// 禁用默认环境文件
    public var disableDefaultEnvFiles: Bool

    public init() {
        behavior = DotEnvBehavior.Disable
        prefix = ""
        defaults = HashMap<String, String>()
        files = []
        disableDefaultEnvFiles = false
    }

    /// 设置行为从前缀
    // 严格翻译自: options.zig:2254 setBehaviorFromPrefix()
    public func setBehaviorFromPrefix(prefix: String): Unit {
        behavior = DotEnvBehavior.Disable
        this.prefix = ""
        if (prefix == "*") {
            behavior = DotEnvBehavior.LoadAll
        } else if (prefix.size > 0) {
            behavior = DotEnvBehavior.Prefix_
            this.prefix = prefix
        }
    }

    /// 转换为 API
    // 严格翻译自: options.zig:2279 toAPI()
    public func toAPI(): HashMap<String, String> {
        var result = HashMap<String, String>()
        for (entry in defaults) {
            result.put(entry.key, entry.value)
        }
        return result
    }

    /// 获取或设置值
    // 严格翻译自: options.zig:2290 getOrPutValue()
    public func getOrPutValue(key: String, value: String): Unit {
        if (!defaults.contains(key)) {
            defaults.put(key, value)
        }
    }
}

/// DotEnv 行为
public enum DotEnvBehavior {
    | Disable
    | LoadAll
    | Prefix_
}

// ============================================================================
// 入口点
// 严格翻译自: options.zig:2303 EntryPoint
// ============================================================================

/// 入口点
// 严格翻译自: options.zig:2303 EntryPoint
public class BundleEntryPoint {
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
    // 严格翻译自: options.zig:2308 isEnabled()
    public func isEnabled(): Bool {
        return kind != EntryPointKind.Disabled && path.size > 0
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

// ============================================================================
// 路由配置
// 严格翻译自: options.zig:2388 RouteConfig
// ============================================================================

/// 路由配置
// 严格翻译自: options.zig:2388 RouteConfig
public class RouteConfig {
    /// 目录
    public var dir: String
    /// 可能的目录列表
    public var possibleDirs: Array<String>
    /// 资源前缀路径
    public var assetPrefixPath: String
    /// 扩展名列表
    public var extensions: Array<String>
    /// 是否启用路由
    public var routesEnabled: Bool
    /// 静态目录
    public var staticDir: String
    /// 是否启用静态目录
    public var staticDirEnabled: Bool

    /// 默认目录
    public static let DefaultDir: String = "pages"
    /// 默认静态目录
    public static let DefaultStaticDir: String = "public"
    /// 默认扩展名
    public static let DefaultExtensions: Array<String> = ["tsx", "ts", "mjs", "jsx", "js"]

    public init() {
        dir = RouteConfig.DefaultDir
        possibleDirs = []
        assetPrefixPath = ""
        extensions = RouteConfig.DefaultExtensions
        routesEnabled = false
        staticDir = RouteConfig.DefaultStaticDir
        staticDirEnabled = false
    }

    /// 空 RouteConfig
    // 严格翻译自: options.zig:2416 zero()
    public static func zero(): RouteConfig {
        var config = RouteConfig()
        config.dir = RouteConfig.DefaultDir
        config.extensions = RouteConfig.DefaultExtensions
        config.staticDir = RouteConfig.DefaultStaticDir
        config.routesEnabled = false
        return config
    }
}

// ============================================================================
// 路径模板
// 严格翻译自: options.zig:2504 PathTemplate
// ============================================================================

/// 路径模板
// 严格翻译自: options.zig:2504 PathTemplate
public class PathTemplate {
    /// 模板数据
    public var data: String
    /// 占位符
    public var placeholder: PathTemplatePlaceholder

    public init(data: String) {
        this.data = data
        this.placeholder = PathTemplatePlaceholder()
    }

    public init(data: String, placeholder: PathTemplatePlaceholder) {
        this.data = data
        this.placeholder = placeholder
    }

    /// 检查是否需要某个字段
    // 严格翻译自: options.zig:2508 needs()
    public func needs(field: String): Bool {
        return data.contains("[${field}]")
    }

    /// 格式化
    // 严格翻译自: options.zig:2526 format()
    public func format(): String {
        var result = data
        result = result.replace("[dir]", if (placeholder.dir.size > 0) { placeholder.dir } else { "." })
        result = result.replace("[name]", placeholder.name)
        result = result.replace("[ext]", placeholder.ext)
        if (placeholder.hash != None) {
            result = result.replace("[hash]", String.fromInt64(placeholder.hash ?: 0, 16))
        }
        result = result.replace("[target]", placeholder.target)
        return result
    }

    /// chunk 模板
    // 严格翻译自: options.zig:2594 chunk
    public static func chunk(): PathTemplate {
        return PathTemplate(
            "./chunk-[hash].[ext]",
            PathTemplatePlaceholder("chunk", "js", "", None, "")
        )
    }

    /// chunk 带目标模板
    // 严格翻译自: options.zig:2603 chunkWithTarget
    public static func chunkWithTarget(): PathTemplate {
        return PathTemplate("[dir]/[target]/chunk-[hash].[ext]")
    }

    /// file 模板
    // 严格翻译自: options.zig:2612 file
    public static func file(): PathTemplate {
        return PathTemplate("[dir]/[name].[ext]")
    }

    /// file 带目标模板
    // 严格翻译自: options.zig:2617 fileWithTarget
    public static func fileWithTarget(): PathTemplate {
        return PathTemplate("[dir]/[target]/[name].[ext]")
    }

    /// asset 模板
    // 严格翻译自: options.zig:2622 asset
    public static func asset(): PathTemplate {
        return PathTemplate("./[name]-[hash].[ext]")
    }

    /// asset 带目标模板
    // 严格翻译自: options.zig:2627 assetWithTarget
    public static func assetWithTarget(): PathTemplate {
        return PathTemplate("[dir]/[target]/[name]-[hash].[ext]")
    }
}

/// 路径模板占位符
// 严格翻译自: options.zig:2578 PathTemplate.Placeholder
public class PathTemplatePlaceholder {
    public var dir: String
    public var name: String
    public var ext: String
    public var hash: ?Int64
    public var target: String

    public init() {
        dir = ""
        name = ""
        ext = ""
        hash = None
        target = ""
    }

    public init(name: String, ext: String, dir: String, hash: ?Int64, target: String) {
        this.name = name
        this.ext = ext
        this.dir = dir
        this.hash = hash
        this.target = target
    }
}

// ============================================================================
// 导入类型
// ============================================================================

/// 导入类型
public enum ImportKind {
    | Stmt              // 静态 import
    | Dynamic           // import()
    | Require           // require()
    | EntryPointBuild   // 入口点 (构建)
    | EntryPointRun     // 入口点 (运行)
    | AtConditional     // @条件导入
    | URL               // new URL()
    | Other

    /// 错误标签
    public func errorLabel(): String {
        match (this) {
            case Stmt | EntryPointBuild | EntryPointRun => "import"
            case Dynamic => "import()"
            case Require => "require()"
            case URL => "new URL()"
            case _ => "import"
        }
    }
}

// ============================================================================
// 打包目标
// ============================================================================

/// 打包目标 (用于多目标构建)
public enum BundleTarget {
    | Browser
    | Node
    | Bun
    | BakeServerComponentsSSR

    /// 转换为 API 字符串
    public func toAPI(): String {
        match (this) {
            case Browser => "browser"
            case Node => "node"
            case Bun => "bun"
            case BakeServerComponentsSSR => "bun"
        }
    }

    /// 是否是服务端
    public func isServerSide(): Bool {
        match (this) {
            case Bun | Node | BakeServerComponentsSSR => true
            case _ => false
        }
    }
}

// ============================================================================
// Loader.Optional - 可选加载器
// 严格翻译自: options.zig:591 Loader.Optional
// ============================================================================

/// 可选加载器
// 严格翻译自: options.zig:591 Loader.Optional
public enum LoaderOptional {
    | None_    // 无加载器 (值为 254)
    | Value(Loader)

    /// 解包可选加载器
    // 严格翻译自: options.zig:594 unwrap()
    public func unwrap(): ?Loader {
        match (this) {
            case None_ => None
            case Value(l) => Some(l)
        }
    }

    /// 从 API Loader 创建
    // 严格翻译自: options.zig:598 fromAPI()
    public static func fromAPI(apiLoader: Int64): LoaderOptional {
        if (apiLoader < 0) {
            return LoaderOptional.None_
        }
        return LoaderOptional.Value(Loader.fromAPI(apiLoader))
    }
}

// ============================================================================
// Loader.toMimeType - 转换为 MIME 类型
// 严格翻译自: options.zig:654 toMimeType()
// ============================================================================

/// Loader MIME 类型扩展
// 严格翻译自: options.zig:654 Loader.toMimeType()
public func loaderToMimeType(loader: Loader, paths: Array<String>): String {
    match (loader) {
        case Jsx | Js | Ts | Tsx => "application/javascript"
        case Css => "text/css"
        case Toml | Yaml | Json | Jsonc | Json5 => "application/json"
        case Wasm => "application/wasm"
        case Html | Md => "text/html"
        case _ =>
            // 按文件扩展名查找 MIME 类型
            for (path in paths) {
                let ext = Path.extname(path)
                var extname = ext
                if (extname.size > 0 && extname[0] == '.') {
                    extname = extname.substring(1)
                }
                if (extname.size > 0) {
                    let mime = mimeTypeByExtension(extname)
                    if (mime.size > 0) {
                        return mime
                    }
                }
            }
            return "application/octet-stream"
    }
}

/// Loader MIME 类型查找 (简化)
private func mimeTypeByExtension(ext: String): String {
    match (ext) {
        case "js" | "mjs" => "application/javascript"
        case "css" => "text/css"
        case "html" => "text/html"
        case "json" => "application/json"
        case "wasm" => "application/wasm"
        case "png" => "image/png"
        case "jpg" | "jpeg" => "image/jpeg"
        case "gif" => "image/gif"
        case "svg" => "image/svg+xml"
        case "txt" => "text/plain"
        case "xml" => "application/xml"
        case "pdf" => "application/pdf"
        case "zip" => "application/zip"
        case "mp4" => "video/mp4"
        case "webm" => "video/webm"
        case "webp" => "image/webp"
        case "ico" => "image/x-icon"
        case "woff" => "font/woff"
        case "woff2" => "font/woff2"
        case "ttf" => "font/ttf"
        case "otf" => "font/otf"
        case _ => ""
    }
}

// ============================================================================
// Loader.fromMimeType - 从 MIME 类型获取加载器
// 严格翻译自: options.zig:891 fromMimeType()
// ============================================================================

/// 从 MIME 类型获取加载器
// 严格翻译自: options.zig:891 Loader.fromMimeType()
public func loaderFromMimeType(mimeType: String): Loader {
    if (mimeType.startsWith("application/javascript-jsx")) {
        return Loader.Jsx
    } else if (mimeType.startsWith("application/typescript-jsx")) {
        return Loader.Tsx
    } else if (mimeType.startsWith("application/javascript")) {
        return Loader.Js
    } else if (mimeType.startsWith("application/typescript")) {
        return Loader.Ts
    } else if (mimeType.startsWith("application/json5")) {
        return Loader.Json5
    } else if (mimeType.startsWith("application/jsonc")) {
        return Loader.Jsonc
    } else if (mimeType.startsWith("application/json")) {
        return Loader.Json
    } else if (mimeType.startsWith("text/")) {
        return Loader.Text
    } else {
        // 最大容错: 默认返回 Tsx
        return Loader.Tsx
    }
}

// ============================================================================
// normalizeSpecifier - 规范化说明符
// 严格翻译自: options.zig:915 normalizeSpecifier()
// ============================================================================

/// 规范化说明符结果
// 严格翻译自: options.zig:918 返回值
public class NormalizedSpecifier {
    /// 规范化后的文件路径
    public var filePath: String
    /// 原始说明符
    public var specifier: String
    /// 查询字符串
    public var query: String

    public init(filePath: String, specifier: String, query: String) {
        this.filePath = filePath
        this.specifier = specifier
        this.query = query
    }
}

/// 规范化说明符
// 严格翻译自: options.zig:915 normalizeSpecifier()
/// 从给定的 specifier 中去除 origin host/path 前缀，分离查询字符串
public func normalizeSpecifier(
    originHost: String,
    originPath: String,
    slice: String
): NormalizedSpecifier {
    var s = slice
    if (s.size == 0) {
        return NormalizedSpecifier(s, s, "")
    }

    // 去除 origin host 前缀
    if (originHost.size > 0 && s.startsWith(originHost)) {
        s = s.substring(originHost.size)
    }

    // 去除 origin path 前缀
    if (originPath.size > 1 && s.startsWith(originPath)) {
        s = s.substring(originPath.size)
    }

    let specifier = s
    var query = ""

    // 分离查询字符串
    let queryIndex = s.indexOf("?")
    match (queryIndex) {
        case Some(i) =>
            query = s.substring(i)
            s = s.substring(0, i)
        case None => ()
    }

    return NormalizedSpecifier(s, specifier, query)
}

// ============================================================================
// getLoaderAndVirtualSource - 获取加载器和虚拟源
// 严格翻译自: options.zig:955 getLoaderAndVirtualSource()
// ============================================================================

/// 加载器结果
// 严格翻译自: options.zig:944 LoaderResult
public class LoaderResult {
    /// 加载器 (可能为空)
    public var loader: ?Loader
    /// 虚拟源 (可能为空)
    public var virtualSource: ?VirtualSource
    /// 文件路径
    public var path: String
    /// 是否主入口
    public var isMain: Bool
    /// 说明符
    public var specifier: String
    /// package.json (可能为空)
    public var packageJson: ?PackageJsonRef

    public init() {
        loader = None
        virtualSource = None
        path = ""
        isMain = false
        specifier = ""
        packageJson = None
    }
}

/// 虚拟源 (简化)
public class VirtualSource {
    public var path: String
    public var contents: String

    public init(path: String, contents: String) {
        this.path = path
        this.contents = contents
    }
}

/// package.json 引用 (简化)
public class PackageJsonRef {
    public var path: String

    public init(path: String) {
        this.path = path
    }
}

/// 获取加载器和虚拟源
// 严格翻译自: options.zig:955 getLoaderAndVirtualSource()
/// 核心路径解析函数: 根据 specifier 确定加载器类型和虚拟源
public func getLoaderAndVirtualSource(
    specifierStr: String,
    originHost: String,
    originPath: String,
    mainModule: String,
    loaders: HashMap<String, Loader>,
    evalSource: ?String,
    typeAttribute: ?String
): ?LoaderResult {
    let normalized = normalizeSpecifier(originHost, originPath, specifierStr)
    var path = normalized.filePath

    // 从路径获取加载器
    let ext = Path.extname(path)
    var loader: ?Loader = None
    match (loaders.get(ext)) {
        case Some(l) => loader = Some(l)
        case None => ()
    }

    var virtualSource: ?VirtualSource = None

    // eval/stdin 源处理
    match (evalSource) {
        case Some(src) =>
            if (specifierStr.endsWith("/[eval]") || specifierStr.endsWith("/[stdin]")) {
                virtualSource = Some(VirtualSource(path, src))
                loader = Some(Loader.Tsx)
            }
        case None => ()
    }

    // blob: URL 处理 (简化)
    if (specifierStr.startsWith("blob:")) {
        // blob URL 需要从 ObjectURLRegistry 查找
        // 简化: 默认不处理 blob URL
        return None
    }

    // ?raw 查询参数处理
    if (normalized.query == "?raw") {
        loader = Some(Loader.Text)
    }

    // type 属性覆盖加载器
    match (typeAttribute) {
        case Some(attrStr) =>
            match (Loader.fromString(attrStr)) {
                case Some(attrLoader) => loader = Some(attrLoader)
                case None => ()
            }
        case None => ()
    }

    // 是否主入口
    let isMain = specifierStr == mainModule

    var result = LoaderResult()
    result.loader = loader
    result.virtualSource = virtualSource
    result.path = path
    result.isMain = isMain
    result.specifier = normalized.specifier
    return Some(result)
}

// ============================================================================
// definesFromTransformOptions - 从转换选项构建定义
// 严格翻译自: options.zig:1374 definesFromTransformOptions()
// ============================================================================

/// 从转换选项构建定义映射
// 严格翻译自: options.zig:1374 definesFromTransformOptions()
/// 关键函数: 将用户定义、环境变量、NODE_ENV 等合并为 Define 映射
public func definesFromTransformOptions(
    inputDefine: ?HashMap<String, String>,
    target: Target,
    envBehavior: DotEnvBehavior,
    envPrefix: String,
    envDefaults: HashMap<String, String>,
    nodeEnv: ?String,
    drop: Array<String>,
    omitUnusedGlobalCalls: Bool
): HashMap<String, String> {
    var userDefines = HashMap<String, String>()

    // 合并输入定义
    match (inputDefine) {
        case Some(defines) =>
            for (entry in defines) {
                userDefines.put(entry.key, entry.value)
            }
        case None => ()
    }

    // 环境变量定义
    if (envBehavior != DotEnvBehavior.Disable &&
        envBehavior != DotEnvBehavior.LoadAll) {
        for (entry in envDefaults) {
            if (!userDefines.contains(entry.key)) {
                userDefines.put(entry.key, entry.value)
            }
        }
    }

    // NODE_ENV 处理
    if (envBehavior != DotEnvBehavior.LoadAll) {
        let quotedNodeEnv: String = match (nodeEnv) {
            case Some(env) =>
                if (env.size > 0) {
                    if ((env.startsWith("\"") && env.endsWith("\"")) ||
                        (env.startsWith("'") && env.endsWith("'"))) {
                        env
                    } else if (env == "production") {
                        "\"production\""
                    } else if (env == "development") {
                        "\"development\""
                    } else if (env == "test") {
                        "\"test\""
                    } else {
                        "\"${env}\""
                    }
                } else {
                    "\"development\""
                }
            case None => "\"development\""
        }

        if (!userDefines.contains("process.env.NODE_ENV")) {
            userDefines.put("process.env.NODE_ENV", quotedNodeEnv)
        }
        if (!userDefines.contains("process.env.BUN_ENV")) {
            userDefines.put("process.env.BUN_ENV", quotedNodeEnv)
        }

        // 浏览器 define
        match (target.processBrowserDefineValue()) {
            case Some(value) =>
                if (!userDefines.contains("process.browser")) {
                    userDefines.put("process.browser", value)
                }
            case None => ()
        }
    }

    // Bun 目标: window 定义
    if (target.isBun()) {
        if (!userDefines.contains("window")) {
            userDefines.put("window", "undefined")
        }
    }

    return userDefines
}

// ============================================================================
// loadersFromTransformOptions - 从转换选项构建加载器映射
// 严格翻译自: options.zig:1562 loadersFromTransformOptions()
// ============================================================================

/// 默认加载器扩展名 (非 Bun)
// 严格翻译自: options.zig:1492 default_loader_ext
public let defaultLoaderExtensions: Array<String> = [
    ".jsx", ".json", ".js", ".mjs", ".cjs", ".css",
    ".ts", ".tsx", ".mts", ".cts",
    ".toml", ".yaml", ".yml", ".wasm", ".txt", ".text",
    ".jsonc", ".json5"
]

/// 默认加载器扩展名 (Bun 特有)
// 严格翻译自: options.zig:1491 default_loader_ext_bun
public let defaultLoaderExtensionsBun: Array<String> = [
    ".node", ".html"
]

/// 默认加载器扩展名 (浏览器特有)
// 严格翻译自: options.zig:1509 default_loader_ext_browser
public let defaultLoaderExtensionsBrowser: Array<String> = [
    ".html"
]

/// 从转换选项构建加载器映射
// 严格翻译自: options.zig:1562 loadersFromTransformOptions()
/// 关键函数: 合并用户自定义加载器和默认加载器
public func loadersFromTransformOptions(
    inputLoaders: ?HashMap<String, Loader>,
    target: Target
): HashMap<String, Loader> {
    var loaders = HashMap<String, Loader>()

    // 合并用户加载器
    match (inputLoaders) {
        case Some(input) =>
            for (entry in input) {
                loaders.put(entry.key, entry.value)
            }
        case None => ()
    }

    // 填充默认加载器
    let defaults = defaultLoaders()
    for (ext in defaultLoaderExtensions) {
        if (!loaders.contains(ext)) {
            match (defaults.get(ext)) {
                case Some(l) => loaders.put(ext, l)
                case None => ()
            }
        }
    }

    // Bun 特有扩展名
    if (target.isBun()) {
        for (ext in defaultLoaderExtensionsBun) {
            if (!loaders.contains(ext)) {
                match (defaults.get(ext)) {
                    case Some(l) => loaders.put(ext, l)
                    case None => ()
                }
            }
        }
    }

    // 浏览器特有扩展名
    if (target == Target.Browser) {
        for (ext in defaultLoaderExtensionsBrowser) {
            if (!loaders.contains(ext)) {
                match (defaults.get(ext)) {
                    case Some(l) => loaders.put(ext, l)
                    case None => ()
                }
            }
        }
    }

    return loaders
}

// ============================================================================
// BundleOptions.deinit - 释放 BundleOptions 资源
// 严格翻译自: options.zig:1886 BundleOptions.deinit()
// ============================================================================

/// BundleOptions 扩展: 释放资源
// 严格翻译自: options.zig:1886 BundleOptions.deinit()
public func bundleOptionsDeinit(opts: BundleOptions): Unit {
    // 清理 define 映射
    opts.define.clear()

    // 清理加载器映射
    opts.loaders.clear()

    // 清理宏重映射
    opts.macroRemap.clear()

    // 清理优化导入集合
    match (opts.optimizeImports) {
        case Some(set) => set.clear()
        case None => ()
    }

    // 清理外部模块
    opts.external.nodeModules.clear()
    opts.external.absPaths.clear()
}

// ============================================================================
// JSX.Pragma.hashForRuntimeTranspiler - 运行时哈希
// 严格翻译自: options.zig:1213 hashForRuntimeTranspiler()
// ============================================================================

/// JSX Pragma 哈希 (用于运行时转译器缓存键)
// 严格翻译自: options.zig:1213 hashForRuntimeTranspiler()
/// 将 JSX 配置信息哈希到单个 UInt64 用于缓存
public func hashPragmaForRuntimeTranspiler(pragma: JsxPragma): UInt64 {
    var hash = UInt64(0)
    // 将配置字段拼接后进行简单哈希
    var combined = ""
    for (f in pragma.factory) {
        combined = combined + f + "\n"
    }
    for (f in pragma.fragment) {
        combined = combined + f + "\n"
    }
    combined = combined + pragma.importSource.development + "\n"
    combined = combined + pragma.importSource.production + "\n"
    combined = combined + pragma.classicImportSource + "\n"
    combined = combined + pragma.packageName + "\n"
    // 简化: 使用字符串哈希
    hash = UInt64(hashString(combined))
    return hash
}

/// 简单字符串哈希 (FNV-1a 变体)
private func hashString(s: String): Int64 {
    var hash = Int64(2166136261)
    for (i in 0..s.size) {
        hash = hash ^ Int64(s[i])
        hash = hash * Int64(16777619)
    }
    return hash
}

// ============================================================================
// JSX.Pragma.setImportSource - 设置导入源
// 严格翻译自: options.zig:1254 setImportSource()
// ============================================================================

/// 设置 JSX 导入源
// 严格翻译自: options.zig:1254 setImportSource()
/// 根据 package_name 自动生成 development/production 导入源路径
public func setPragmaImportSource(pragma: JsxPragma): Unit {
    let packageName = pragma.packageName
    if (packageName.size > 0) {
        pragma.importSource = JsxImportSource(
            "${packageName}/jsx-dev-runtime",
            "${packageName}/jsx-runtime"
        )
    } else {
        pragma.importSource = JsxImportSource(
            JsxDefaults.ImportSourceDev,
            JsxDefaults.ImportSource
        )
    }
}

// ============================================================================
// Env.setDefaultsMap - 设置环境默认值映射
// 严格翻译自: options.zig:2231 Env.setDefaultsMap()
// ============================================================================

/// EnvConfig 扩展: 从键值对数组设置默认值
// 严格翻译自: options.zig:2231 Env.setDefaultsMap()
public func envSetDefaultsMap(env: EnvConfig, keys: Array<String>, values: Array<String>): Unit {
    env.defaults.clear()
    if (keys.size == 0) {
        return
    }
    let count = if (keys.size < values.size) { keys.size } else { values.size }
    for (i in 0..count) {
        env.defaults.put(keys[i], values[i])
    }
}

// ============================================================================
// Env.setFromAPI - 从 API 配置设置
// 严格翻译自: options.zig:2246 Env.setFromAPI()
// ============================================================================

/// EnvConfig 扩展: 从 API 配置设置
// 严格翻译自: options.zig:2246 Env.setFromAPI()
public func envSetFromAPI(
    env: EnvConfig,
    prefix: ?String,
    defaultKeys: Array<String>,
    defaultValues: Array<String>
): Unit {
    // 设置行为
    match (prefix) {
        case Some(p) => env.setBehaviorFromPrefix(p)
        case None => ()
    }

    // 设置默认值
    envSetDefaultsMap(env, defaultKeys, defaultValues)
}

// ============================================================================
// RouteConfig.fromLoadedRoutes - 从已加载的路由创建
// 严格翻译自: options.zig:2425 RouteConfig.fromLoadedRoutes()
// ============================================================================

/// RouteConfig 扩展: 从已加载的路由配置创建
// 严格翻译自: options.zig:2425 RouteConfig.fromLoadedRoutes()
public func routeConfigFromLoadedRoutes(
    extensions: Array<String>,
    dir: String,
    assetPrefix: String,
    staticDir: String
): RouteConfig {
    var config = RouteConfig()
    config.extensions = extensions
    config.dir = dir
    config.assetPrefixPath = assetPrefix
    config.staticDir = staticDir
    config.routesEnabled = dir.size > 0
    config.staticDirEnabled = staticDir.size > 0
    return config
}

// ============================================================================
// EntryPoint.toAPI/fromLoaded/fromAPI - 入口点序列化
// 严格翻译自: options.zig:2328-2385 EntryPoint
// ============================================================================

/// BundleEntryPoint 扩展: 转换为 API 格式
// 严格翻译自: options.zig:2328 EntryPoint.toAPI()
public func entryPointToAPI(
    entryPoint: BundleEntryPoint,
    toplevelPath: String,
    kind: EntryPointKind
): ?HashMap<String, String> {
    if (kind == EntryPointKind.Disabled) {
        return None
    }
    if (entryPoint.path.size == 0) {
        return None
    }

    var result = HashMap<String, String>()
    // 规范化路径
    var normalizedPath = entryPoint.path
    let topIndex = normalizedPath.indexOf(toplevelPath)
    match (topIndex) {
        case Some(i) => normalizedPath = normalizedPath.substring(i + toplevelPath.size)
        case None => ()
    }

    // node_modules 路径
    let nodeModuleIndex = normalizedPath.indexOf("node_modules/")
    match (nodeModuleIndex) {
        case Some(i) => normalizedPath = normalizedPath.substring(i + "node_modules".size + 1)
        case None =>
            // 添加 "./" 前缀
            if (!normalizedPath.startsWith("./")) {
                normalizedPath = "./${normalizedPath}"
            }
    }

    result.put("kind", kind.toAPI())
    result.put("path", normalizedPath)
    result.put("env", entryPoint.env.toAPI().toString())
    return Some(result)
}

/// EntryPointKind 转换为 API 字符串
// 严格翻译自: options.zig:2318 EntryPoint.Kind.toAPI()
public func entryPointKindToAPI(kind: EntryPointKind): String {
    match (kind) {
        case EntryPointKind.Client => "client"
        case EntryPointKind.Server => "server"
        case EntryPointKind.Fallback => "fallback"
        case EntryPointKind.Disabled => "disabled"
    }
}

/// BundleEntryPoint 扩展: 从已加载的配置创建
// 严格翻译自: options.zig:2356 EntryPoint.fromLoaded()
public func entryPointFromLoaded(
    path: String,
    kind: EntryPointKind,
    envBehavior: DotEnvBehavior,
    envPrefix: String,
    envDefaultKeys: Array<String>,
    envDefaultValues: Array<String>
): BundleEntryPoint {
    var ep = BundleEntryPoint()
    ep.path = path
    ep.kind = kind
    ep.env.setBehaviorFromPrefix(envPrefix)
    envSetDefaultsMap(ep.env, envDefaultKeys, envDefaultValues)
    return ep
}

/// BundleEntryPoint 扩展: 从 API 消息创建
// 严格翻译自: options.zig:2367 EntryPoint.fromAPI()
public func entryPointFromAPI(
    path: ?String,
    kind: EntryPointKind,
    envPrefix: ?String,
    envDefaultKeys: Array<String>,
    envDefaultValues: Array<String>
): BundleEntryPoint {
    var ep = BundleEntryPoint()

    match (path) {
        case Some(p) => ep.path = p
        case None => ep.path = ""
    }

    ep.kind = kind

    if (ep.path.size == 0) {
        ep.kind = EntryPointKind.Disabled
        return ep
    }

    envSetFromAPI(ep.env, envPrefix, envDefaultKeys, envDefaultValues)
    return ep
}

// ============================================================================
// BundleOptions 缺失字段扩展
// 严格翻译自: options.zig:1670 BundleOptions 缺失字段
// ============================================================================

/// BundleOptions 扩展: 缺失字段容器
// 严格翻译自: options.zig:1677 bundler_feature_flags
// 严格翻译自: options.zig:1693 output_dir_handle
// 严格翻译自: options.zig:1731 transform_options
// 严格翻译自: options.zig:1753 install
// 严格翻译自: options.zig:1784 dev_server
// 严格翻译自: options.zig:1786 framework
public class BundleOptionsExtension {
    /// 打包器特性标志集合
    // 严格翻译自: options.zig:1677 bundler_feature_flags
    public var bundlerFeatureFlags: HashSet<String>

    /// 输出目录句柄
    // 严格翻译自: options.zig:1693 output_dir_handle
    public var outputDirHandle: ?String

    /// 转换选项引用
    // 严格翻译自: options.zig:1731 transform_options
    public var transformOptions: TransformOptions

    /// 安装配置
    // 严格翻译自: options.zig:1753 install
    public var install: ?BunInstallConfig

    /// 开发服务器引用
    // 严格翻译自: options.zig:1784 dev_server
    public var devServer: ?DevServerRef

    /// 框架引用
    // 严格翻译自: options.zig:1786 framework
    public var framework: ?FrameworkRef

    public init() {
        bundlerFeatureFlags = HashSet<String>()
        outputDirHandle = None
        transformOptions = TransformOptions()
        install = None
        devServer = None
        framework = None
    }
}

/// Bun 安装配置 (简化)
// 严格翻译自: options.zig:1753 api.BunInstall
public class BunInstallConfig {
    public var registry: String

    public init() {
        registry = ""
    }
}

/// DevServer 引用 (简化)
// 严格翻译自: options.zig:1784 bun.bake.DevServer
public class DevServerRef {
    public var id: String

    public init(id: String) {
        this.id = id
    }
}

/// Framework 引用 (简化)
// 严格翻译自: options.zig:1786 bun.bake.Framework
public class FrameworkRef {
    public var name: String

    public init(name: String) {
        this.name = name
    }
}
