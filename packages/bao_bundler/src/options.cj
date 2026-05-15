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
        return this == Loader.Css
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

    /// 从字符串解析
    public static func fromString(slice: String): Loader {
        var s = slice
        if (s.length > 0 && s[0] == '.') {
            s = s.substring(1)
        }
        match (s.toLowerCase()) {
            case "js" | "mjs" | "cjs" => Loader.Js
            case "jsx" => Loader.Jsx
            case "ts" | "mts" | "cts" => Loader.Ts
            case "tsx" => Loader.Tsx
            case "css" => Loader.Css
            case "file" => Loader.File
            case "json" => Loader.Json
            case "jsonc" => Loader.Jsonc
            case "toml" => Loader.Toml
            case "yaml" | "yml" => Loader.Yaml
            case "json5" => Loader.Json5
            case "wasm" => Loader.Wasm
            case "napi" | "node" => Loader.Napi
            case "base64" => Loader.Base64
            case "dataurl" => Loader.DataUrl
            case "txt" | "text" => Loader.Text
            case "sh" => Loader.Bunsh
            case "sqlite" => Loader.Sqlite
            case "sqlite_embedded" => Loader.SqliteEmbedded
            case "html" => Loader.Html
            case "md" | "markdown" => Loader.Md
            case _ => Loader.File
        }
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
            case Text | Json | Jsonc | Toml | Yaml | Json5 | File | Md => SideEffects.NoSideEffectsPureData
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
        match (this) {
            case ESM => ModuleType.ESM
            case CJS => ModuleType.CJS
            case _ => ModuleType.ESM
        }
    }
}

// ============================================================================
// 模块类型
// 严格翻译自: options.zig:368 ModuleType
// ============================================================================

/// 模块类型
public enum ModuleType {
    | Unknown
    | CJS     // CommonJS
    | ESM     // ES Module
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
}

// ============================================================================
// 副作用
// ============================================================================

/// 副作用类型
public enum SideEffects {
    | HasSideEffects                // 有副作用
    | NoSideEffectsPureData         // 无副作用 (纯数据)
    | NoSideEffectsPackageJson      // 无副作用 (package.json 声明)
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
// Bundle 选项
// 严格翻译自: options.zig:1670 BundleOptions
// 这是打包器的主要配置结构
// ============================================================================

/// Bundle 选项
// 严格翻译自: options.zig:1670 BundleOptions
public class BundleOptions {
    /// banner 文本
    public var banner: String
    /// footer 文本
    public var footer: String
    /// 定义 (宏替换)
    public var define: Define
    /// 要丢弃的 API
    public var drop: Array<String>
    /// 加载器映射
    public var loaders: HashMap<String, Loader>
    /// 解析目录
    public var resolveDir: String
    /// JSX 配置
    public var jsx: JsxPragma
    /// 是否发出装饰器元数据
    public var emitDecoratorMetadata: Bool
    /// 是否使用实验性装饰器
    public var experimentalDecorators: Bool
    /// 是否自动导入 JSX
    public var autoImportJsx: Bool
    /// 是否允许运行时
    public var allowRuntime: Bool
    /// 输出目录
    public var outputDir: String
    /// 根目录
    public var rootDir: String
    /// 是否写入磁盘
    public var write: Bool
    /// 是否生产模式
    public var production: Bool
    /// 输出格式
    public var outputFormat: OutputFormat
    /// 目标平台
    public var target: Target
    /// 主字段
    public var mainFields: Array<String>
    /// 入口点列表
    public var entryPoints: Array<String>
    /// 入口命名模板
    public var entryNaming: String
    /// 资源命名模板
    public var assetNaming: String
    /// chunk 命名模板
    public var chunkNaming: String
    /// 公共路径
    public var publicPath: String
    /// 输出扩展名映射
    public var outExtensions: HashMap<String, String>
    /// 是否启用 tree-shaking
    public var treeShaking: Bool
    /// 是否启用代码分割
    public var codeSplitting: Bool
    /// sourcemap 选项
    public var sourceMap: SourceMapOption
    /// 包选项
    public var packages: PackagesOption
    /// 是否启用 CSS 分块
    public var cssChunking: Bool
    /// 是否压缩空白
    public var minifyWhitespace: Bool
    /// 是否压缩语法
    public var minifySyntax: Bool
    /// 是否压缩标识符
    public var minifyIdentifiers: Bool
    /// 是否保持名称
    public var keepNames: Bool
    /// 是否启用死代码消除
    public var deadCodeElimination: Bool
    /// 是否忽略 DCE 注解
    public var ignoreDceAnnotations: Bool
    /// 是否发出 DCE 注解
    public var emitDceAnnotations: Bool
    /// 是否生成字节码
    public var bytecode: Bool
    /// 是否编译为独立 HTML
    public var compileToStandaloneHtml: Bool
    /// 是否生成 metafile
    public var metafile: Bool
    /// metafile JSON 路径
    public var metafileJsonPath: String
    /// 是否启用内联
    public var inlining: Bool
    /// 外部模块配置
    public var external: ExternalModules
    /// 是否禁止转译
    public var disableTranspilation: Bool

    public init() {
        this.banner = ""
        this.footer = ""
        this.define = Define()
        this.drop = []
        this.loaders = HashMap<String, Loader>()
        this.resolveDir = "/"
        this.jsx = JsxPragma()
        this.emitDecoratorMetadata = false
        this.experimentalDecorators = false
        this.autoImportJsx = true
        this.allowRuntime = true
        this.outputDir = "out"
        this.rootDir = ""
        this.write = false
        this.production = false
        this.outputFormat = OutputFormat.ESM
        this.target = Target.Browser
        this.mainFields = Target.Browser.defaultMainFields()
        this.entryPoints = []
        this.entryNaming = ""
        this.assetNaming = ""
        this.chunkNaming = ""
        this.publicPath = ""
        this.outExtensions = HashMap<String, String>()
        this.treeShaking = false
        this.codeSplitting = false
        this.sourceMap = SourceMapOption.None
        this.packages = PackagesOption.Bundle
        this.cssChunking = false
        this.minifyWhitespace = false
        this.minifySyntax = false
        this.minifyIdentifiers = false
        this.keepNames = false
        this.deadCodeElimination = true
        this.ignoreDceAnnotations = false
        this.emitDceAnnotations = false
        this.bytecode = false
        this.compileToStandaloneHtml = false
        this.metafile = false
        this.metafileJsonPath = ""
        this.inlining = false
        this.external = ExternalModules()
        this.disableTranspilation = false

        // 初始化默认加载器
        initDefaultLoaders()
    }

    /// 初始化默认加载器
    private func initDefaultLoaders(): Unit {
        loaders.put(".jsx", Loader.Jsx)
        loaders.put(".js", Loader.Js)
        loaders.put(".mjs", Loader.Js)
        loaders.put(".cjs", Loader.Js)
        loaders.put(".ts", Loader.Ts)
        loaders.put(".tsx", Loader.Tsx)
        loaders.put(".mts", Loader.Ts)
        loaders.put(".cts", Loader.Ts)
        loaders.put(".css", Loader.Css)
        loaders.put(".json", Loader.Json)
        loaders.put(".jsonc", Loader.Jsonc)
        loaders.put(".toml", Loader.Toml)
        loaders.put(".yaml", Loader.Yaml)
        loaders.put(".yml", Loader.Yaml)
        loaders.put(".json5", Loader.Json5)
        loaders.put(".wasm", Loader.Wasm)
        loaders.put(".node", Loader.Napi)
        loaders.put(".txt", Loader.Text)
        loaders.put(".text", Loader.Text)
        loaders.put(".html", Loader.Html)
        loaders.put(".md", Loader.Md)
    }

    /// 获取加载器
    public func loader(ext: String): Loader {
        match (loaders.get(ext)) {
            case Some(l) => return l
            case None => return Loader.File
        }
    }

    /// CSS 导入行为
    public func cssImportBehavior(): CssInJsBehavior {
        match (target) {
            case Browser => CssInJsBehavior.AutoOnImportCSS
            case _ => CssInJsBehavior.Facade
        }
    }
}

// ============================================================================
// 外部模块配置
// 严格翻译自: options.zig:83 ExternalModules
// ============================================================================

/// 外部模块配置
public class ExternalModules {
    /// node_modules 外部化列表
    public var nodeModules: HashSet<String>
    /// 绝对路径外部化列表
    public var absPaths: HashSet<String>
    /// 通配符模式
    public var patterns: Array<WildcardPattern>

    public init() {
        this.nodeModules = HashSet<String>()
        this.absPaths = HashSet<String>()
        this.patterns = []
    }

    /// 初始化外部模块
    public func initFunc(externals: Array<String>, target: Target): Unit {
        // 添加默认外部模式
        patterns = [WildcardPattern(prefix: "/bun:", suffix: "")]

        // Node 目标添加内置模块
        if (target == Target.Node) {
            for (builtin in NodeBuiltinPatterns) {
                nodeModules.put(builtin)
            }
        }

        // 处理用户指定的外部模块
        for (external in externals) {
            let starIdx = external.indexOf("*")
            if (starIdx >= 0) {
                // 通配符模式
                patterns.append(WildcardPattern(
                    prefix: external.substring(0, Int64(starIdx)),
                    suffix: external.substring(Int64(starIdx + 1))
                ))
            } else if (isPackagePath(external)) {
                nodeModules.put(external)
            } else {
                absPaths.put(external)
            }
        }
    }

    /// 判断是否是包路径
    private func isPackagePath(path: String): Bool {
        return !path.startsWith("/") && !path.startsWith("./") && !path.startsWith("../")
    }
}

/// 通配符模式
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
    public func getImportSource(): String {
        return if (development) importSource.development else importSource.production
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
// 辅助类型
// ============================================================================

/// 定义 (宏替换)
public class Define {
    public var entries: HashMap<String, String>

    public init() {
        this.entries = HashMap<String, String>()
    }

    public func deinit(): Unit {
        entries.clear()
    }
}

/// 扩展名解析顺序
public class ExtensionOrder {
    /// 默认扩展名顺序
    public static let Default: Array<String> = [
        ".tsx", ".ts", ".jsx", ".cts", ".cjs", ".js", ".mjs", ".mts", ".json"
    ]
    /// 模块扩展名顺序
    public static let Module: Array<String> = [
        ".tsx", ".jsx", ".mts", ".ts", ".mjs", ".js", ".cts", ".cjs", ".json"
    ]
}
