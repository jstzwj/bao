// 模块加载器
// 严格翻译自: src/ast/loader.rs (342行)
//   bundler/options.zig Loader + SideEffects.
//   包含:
//     - Loader: 模块加载器枚举 (Jsx, Js, Ts, Tsx, Css, File, Json, ...)
//     - LoaderOptional: 可选加载器 (none 或具体值)
//     - SideEffects: 副作用枚举
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// Loader - 模块加载器
// 严格翻译自: loader.rs:17-43
//   pub enum Loader { Jsx=0, Js=1, Ts=2, Tsx=3, Css=4, File=5, Json=6, ... }
// ============================================================================

/// 模块加载器 - 对应 Bun Loader
/// 决定如何加载和解析不同类型的文件
/// 注意: 最大整数值只能追加，不能修改，因为有多个 FFI 依赖
public enum Loader {
    | Jsx              // 0 - JSX 文件
    | Js               // 1 - JavaScript 文件
    | Ts               // 2 - TypeScript 文件
    | Tsx              // 3 - TSX 文件
    | Css              // 4 - CSS 文件
    | File             // 5 - 通用文件 (复制)
    | Json             // 6 - JSON 文件
    | Jsonc            // 7 - JSONC 文件 (带注释)
    | Toml             // 8 - TOML 文件
    | Wasm             // 9 - WebAssembly 文件
    | Napi             // 10 - N-API 原生模块
    | Base64           // 11 - Base64 编码
    | Dataurl          // 12 - Data URL
    | Text             // 13 - 纯文本
    | Bunsh            // 14 - Shell 脚本
    | Sqlite           // 15 - SQLite 数据库
    | SqliteEmbedded   // 16 - 嵌入式 SQLite
    | Html             // 17 - HTML 文件
    | Yaml             // 18 - YAML 文件
    | Json5            // 19 - JSON5 文件
    | Md               // 20 - Markdown 文件

    public func ordinal(): Int64 {
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
            case Dataurl => 12
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

    public operator func ==(right: Loader): Bool {
        ordinal() == right.ordinal()
    }

    public operator func !=(right: Loader): Bool {
        !(this == right)
    }

    /// 是否为 CSS - 对应 Loader.is_css()
    public func isCss(): Bool {
        this == Loader.Css
    }

    /// 是否类 JS - 对应 Loader.is_js_like()
    public func isJsLike(): Bool {
        match (this) {
            case Jsx | Js | Ts | Tsx => true
            case _ => false
        }
    }

    /// 是否为 TypeScript - 对应 Loader.is_typescript()
    public func isTypescript(): Bool {
        match (this) {
            case Tsx | Ts => true
            case _ => false
        }
    }

    /// 是否为 JSX - 对应 Loader.is_jsx()
    public func isJsx(): Bool {
        match (this) {
            case Jsx | Tsx => true
            case _ => false
        }
    }

    /// 是否为 SQLite - 对应 Loader.is_sqlite()
    public func isSqlite(): Bool {
        match (this) {
            case Sqlite | SqliteEmbedded => true
            case _ => false
        }
    }

    /// 是否为类 JavaScript (包括 JSON) - 对应 Loader.is_javascript_like_or_json()
    public func isJavaScriptLikeOrJson(): Bool {
        match (this) {
            case Jsx | Js | Ts | Tsx | Json | Jsonc | Toml | Yaml | Json5 => true
            case _ => false
        }
    }

    /// 打包时是否复制 - 对应 Loader.should_copy_for_bundling()
    public func shouldCopyForBundling(): Bool {
        match (this) {
            case File | Napi | Sqlite | SqliteEmbedded | Wasm => true
            case _ => false
        }
    }

    /// 是否处理空文件 - 对应 Loader.handles_empty_file()
    public func handlesEmptyFile(): Bool {
        match (this) {
            case Wasm | File | Text => true
            case _ => false
        }
    }

    /// 是否可有源映射 - 对应 Loader.can_have_source_map()
    public func canHaveSourceMap(): Bool {
        match (this) {
            case Jsx | Js | Ts | Tsx => true
            case _ => false
        }
    }

    /// Bun 是否可直接运行 - 对应 Loader.can_be_run_by_bun()
    public func canBeRunByBun(): Bool {
        match (this) {
            case Jsx | Js | Ts | Tsx | Wasm | Bunsh => true
            case _ => false
        }
    }

    /// 标准输入文件名 - 对应 Loader.stdin_name()
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

    /// 副作用类型 - 对应 Loader.side_effects()
    public func sideEffects(): SideEffects {
        match (this) {
            case Text | Json | Jsonc | Toml | Yaml | Json5 | File | Md =>
                SideEffects.NoSideEffectsPureData
            case _ =>
                SideEffects.HasSideEffects
        }
    }

    /// 禁用 HTML (回退到 File) - 对应 Loader.disable_html()
    public func disableHtml(): Loader {
        match (this) {
            case Html => Loader.File
            case other => other
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
// SideEffects - 副作用枚举
// 严格翻译自: loader.rs:318-340
//   pub enum SideEffects { HasSideEffects, NoSideEffectsPackageJson, ... }
// ============================================================================

/// 副作用类型 - 对应 Bun SideEffects
public enum SideEffects {
    | HasSideEffects               // 默认: 保守认为有副作用
    | NoSideEffectsPackageJson     // package.json 中声明无副作用
    | NoSideEffectsEmptyAst        // AST 为空 (如 .d.ts)
    | NoSideEffectsPureData        // 纯数据加载器 (如 "text")

    public operator func ==(right: SideEffects): Bool {
        ordinal() == right.ordinal()
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
// LoaderOptional - 可选加载器
// 严格翻译自: loader.rs:64-117
//   pub struct LoaderOptional(pub(crate) u8) — niche-packed optional
// ============================================================================

/// 可选加载器 - 对应 Bun Loader.Optional
/// 使用 254 作为 None 标记的 niche-packed 可选值
public class LoaderOptional {
    public var value: UInt8

    public init() {
        value = NONE_VALUE
    }

    public init(loader: Loader) {
        value = UInt8(loader.ordinal())
    }

    /// None 值
    public static let NONE_VALUE: UInt8 = 254

    /// 是否为 None
    public func isNone(): Bool {
        value == LoaderOptional.NONE_VALUE
    }

    /// 是否为 Some
    public func isSome(): Bool {
        !isNone()
    }

    /// 解包 - 对应 LoaderOptional.unwrap()
    public func unwrap(): ?Loader {
        match (value) {
            case 0 => Some(Loader.Jsx)
            case 1 => Some(Loader.Js)
            case 2 => Some(Loader.Ts)
            case 3 => Some(Loader.Tsx)
            case 4 => Some(Loader.Css)
            case 5 => Some(Loader.File)
            case 6 => Some(Loader.Json)
            case 7 => Some(Loader.Jsonc)
            case 8 => Some(Loader.Toml)
            case 9 => Some(Loader.Wasm)
            case 10 => Some(Loader.Napi)
            case 11 => Some(Loader.Base64)
            case 12 => Some(Loader.Dataurl)
            case 13 => Some(Loader.Text)
            case 14 => Some(Loader.Bunsh)
            case 15 => Some(Loader.Sqlite)
            case 16 => Some(Loader.SqliteEmbedded)
            case 17 => Some(Loader.Html)
            case 18 => Some(Loader.Yaml)
            case 19 => Some(Loader.Json5)
            case 20 => Some(Loader.Md)
            case _ => None
        }
    }
}

// ============================================================================
// Loader 辅助: 从字符串解析
// 严格翻译自: loader.rs:230-245
//   pub fn from_string(slice_: &[u8]) -> Option<Loader>
// ============================================================================

/// 加载器名称到加载器类型的映射
/// 对应 Bun Loader.NAMES (phf map)
public let LOADER_NAMES: HashMap<String, Loader> = { =>
    let m = HashMap<String, Loader>()
    m.put("js", Loader.Js)
    m.put("mjs", Loader.Js)
    m.put("cjs", Loader.Js)
    m.put("cts", Loader.Ts)
    m.put("mts", Loader.Ts)
    m.put("jsx", Loader.Jsx)
    m.put("ts", Loader.Ts)
    m.put("tsx", Loader.Tsx)
    m.put("css", Loader.Css)
    m.put("file", Loader.File)
    m.put("json", Loader.Json)
    m.put("jsonc", Loader.Jsonc)
    m.put("toml", Loader.Toml)
    m.put("yaml", Loader.Yaml)
    m.put("json5", Loader.Json5)
    m.put("wasm", Loader.Wasm)
    m.put("napi", Loader.Napi)
    m.put("node", Loader.Napi)
    m.put("dataurl", Loader.Dataurl)
    m.put("base64", Loader.Base64)
    m.put("txt", Loader.Text)
    m.put("text", Loader.Text)
    m.put("sh", Loader.Bunsh)
    m.put("sqlite", Loader.Sqlite)
    m.put("sqlite_embedded", Loader.SqliteEmbedded)
    m.put("html", Loader.Html)
    m.put("md", Loader.Md)
    m.put("markdown", Loader.Md)
    m
}()

/// 从字符串解析加载器 - 对应 Bun Loader.from_string()
public func loaderFromString(slice: String): ?Loader {
    var s = slice
    if (s.size > 0 && s[0] == UInt8(46)) { // '.'
        s = s[1..s.size]
    }
    LOADER_NAMES.get(s.toAsciiLower())
}
