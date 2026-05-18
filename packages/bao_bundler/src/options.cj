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
        match (slice) {
            case "js" | ".js" | "mjs" | ".mjs" | "cjs" | ".cjs" => Loader.Js
            case "jsx" | ".jsx" => Loader.Jsx
            case "ts" | ".ts" | "mts" | ".mts" | "cts" | ".cts" => Loader.Ts
            case "tsx" | ".tsx" => Loader.Tsx
            case "css" | ".css" => Loader.Css
            case "json" | ".json" => Loader.Json
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
        return ModuleType.JavaScript
    }
}

// ============================================================================
// 模块类型
// 严格翻译自: options.zig:368 ModuleType
// ============================================================================// ============================================================================
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
// ============================================================================// ============================================================================
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
// 严格翻译自: options.zig:1670 BundleOptions// ============================================================================
// 外部模块配置
// 严格翻译自: options.zig:83 ExternalModules
// ============================================================================/// Node 内置模块模式列表
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
        return if (development) { importSource.development } else { importSource.production }
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
