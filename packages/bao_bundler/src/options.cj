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
// AllowUnresolved - defined in bundler_options.cj

/// 允许未解析模式
// AllowUnresolvedMode - defined in bundler_options.cj

// ============================================================================
// 外部模块配置
// 严格翻译自: options.zig:83 ExternalModules
// ============================================================================

/// 外部模块配置
// 严格翻译自: options.zig:83 ExternalModules
// ExternalModules - defined in bundler_options.cj

/// 通配符模式
// 严格翻译自: options.zig:88 ExternalModules.WildcardPattern
// WildcardPattern - defined in bundler_options.cj

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
// ModuleType - defined in package.cj

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
        if (s.size > 0 && s[0] == UInt8(46)) {  // '.'
            s = s[1..]
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

        if (match (this) { case Target.Node => true case _ => false }) {
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
// SideEffects - defined in resolver.cj

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
// ESMConditions - defined in bundler_options.cj

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
        if (str[0] == UInt8(64)) {  // '@'
            let firstSlash = str.indexOf("/")
            match (firstSlash) {
                case Some(i) =>
                    let remainder = str[Int64(i) + 1..]
                    let lastSlash = remainder.indexOf("/")
                    match (lastSlash) {
                        case Some(j) => return str[0..Int64(i) + Int64(j) + 2]
                        case None => ()
                    }
                case None => ()
            }
        }
        let firstSlash = str.indexOf("/")
        match (firstSlash) {
            case Some(i) => return str[0..Int64(i)]
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
// ResolveFileExtensions - defined in bundler_options.cj

/// 扩展名分组
// 严格翻译自: options.zig:1556 ResolveFileExtensions.Group
// ExtensionGroup - defined in bundler_options.cj

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

// BundleOptions - defined in bundler_options.cj
// ForceNodeEnv - defined in bundler_options.cj

// ============================================================================
// 全局缓存
// ============================================================================

/// 全局缓存模式
// GlobalCache - defined elsewhere

// ============================================================================
// 转换选项
// 严格翻译自: options.zig:2108 TransformOptions
// ============================================================================

/// 转换选项
// 严格翻译自: options.zig:2108 TransformOptions
// TransformOptions - defined in transpiler.cj

// ============================================================================
// 转换结果
// 严格翻译自: options.zig:2163 TransformResult
// ============================================================================

/// 转换结果
// TransformResult - defined in transpiler.cj

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
// OutputFile - defined elsewhere

// ============================================================================
// 环境配置
// 严格翻译自: options.zig:2198 Env
// ============================================================================

/// 环境配置
// 严格翻译自: options.zig:2198 Env
// EnvConfig - defined elsewhere

/// DotEnv 行为
// DotEnvBehavior - defined elsewhere

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
// EntryPointKind - defined elsewhere

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
// PathTemplate - defined elsewhere

/// 路径模板占位符
// 严格翻译自: options.zig:2578 PathTemplate.Placeholder
// PathTemplatePlaceholder - defined elsewhere

// ============================================================================
// 导入类型
// ============================================================================

/// 导入类型
// ImportKind - defined elsewhere

// ============================================================================
// 打包目标
// ============================================================================

/// 打包目标 (用于多目标构建)
// BundleTarget - defined elsewhere

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
                if (extname.size > 0 && extname[0] == UInt8(46)) {  // '.'
                    extname = extname[1..]
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
        s = s[originHost.size..]
    }

    // 去除 origin path 前缀
    if (originPath.size > 1 && s.startsWith(originPath)) {
        s = s[originPath.size..]
    }

    let specifier = s
    var query = ""

    // 分离查询字符串
    let queryIndex = s.indexOf("?")
    match (queryIndex) {
        case Some(i) =>
            query = s[Int64(i)..]
            s = s[0..Int64(i)]
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
            for (key in defines.keys()) {
                match (defines.get(key)) {
                    case Some(v) => userDefines.put(key, v)
                    case None => ()
                }
            }
        case None => ()
    }

    // 环境变量定义
    let envNotDisable = match (envBehavior) { case DotEnvBehavior.Disable => false case _ => true }
    let envNotLoadAll = match (envBehavior) { case DotEnvBehavior.LoadAll => false case _ => true }
    if (envNotDisable && envNotLoadAll) {
        for (key in envDefaults.keys()) {
            if (!userDefines.contains(key)) {
                match (envDefaults.get(key)) {
                    case Some(v) => userDefines.put(key, v)
                    case None => ()
                }
            }
        }
    }

    // NODE_ENV 处理
    if (envNotLoadAll) {
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
            for (key in input.keys()) {
                match (input.get(key)) {
                    case Some(l) => loaders.put(key, l)
                    case None => ()
                }
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
    let isBrowser = match (target) { case Target.Browser => true case _ => false }
    if (isBrowser) {
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
    opts.defines.clear()

    // 清理加载器映射
    opts.loaders.clear()

    // 清理入口点
    opts.entryPoints.clear()

    // 清理外部依赖
    opts.externals.clear()
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
        env.defaults.append(EnvEntry(keys[i], values[i]))
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
        case Some(i) => normalizedPath = normalizedPath[Int64(i) + toplevelPath.size..]
        case None => ()
    }

    // node_modules 路径
    let nodeModuleIndex = normalizedPath.indexOf("node_modules/")
    match (nodeModuleIndex) {
        case Some(i) => normalizedPath = normalizedPath[Int64(i) + "node_modules".size + 1..]
        case None =>
            // 添加 "./" 前缀
            if (!normalizedPath.startsWith("./")) {
                normalizedPath = "./${normalizedPath}"
            }
    }

    result.put("kind", kind.toAPI())
    result.put("path", normalizedPath)
    result.put("env", "env_config")
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
// DevServerRef - defined elsewhere

/// Framework 引用 (简化)
// 严格翻译自: options.zig:1786 bun.bake.Framework
// FrameworkRef - defined elsewhere
