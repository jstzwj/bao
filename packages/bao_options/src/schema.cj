// Schema - 序列化 schema API 类型定义
// 严格翻译自: bun/src/options_types/schema.rs
//   schema.rs 注释标记为 "GENERATED: re-exported from peechy"，
//   手动展开的类型定义，供 bundler/options, runtime/cli 等模块使用。
//   包含 Writer, ResolveMode, MessageLevel, Target, Loader, SourceMapMode,
//   Jsx, JsxRuntime, StringMap, LoaderMap, EnvConfig, BunInstall 等核心类型。
package bao_options

import bao_core.*
import bao_collections.*

// ============================================================================
// SchemaWriter - schema 二进制写入器
// 严格翻译自: schema.rs - Writer<'a>
//   pub struct Writer<'a> { writable: &'a mut Vec<u8> }
//   序列化 schema 消息到字节缓冲区。
// ============================================================================

/// Schema 二进制写入器 - 对应 Bun schema.Writer
/// 将结构化数据编码为二进制格式
public class SchemaWriter {
    private var buffer: StringBuilder

    public init() {
        buffer = StringBuilder()
    }

    public init(buffer: StringBuilder) {
        this.buffer = buffer
    }

    /// 获取缓冲区
    public func getBuffer(): StringBuilder {
        buffer
    }

    /// 写入原始字节
    public func write(bytes: Array<UInt8>): Unit {
        for (b in bytes) {
            buffer.append(Char(b))
        }
    }

    /// 写入单个字节
    public func writeByte(byte: UInt8): Unit {
        buffer.append(Char(byte))
    }

    /// 写入整数 (原生字节序)
    public func writeInt(value: Int64): Unit {
        buffer.append(value.toString())
    }

    /// 写入字段 ID
    public func writeFieldId(id: UInt8): Unit {
        writeByte(id)
    }

    /// 写入枚举值
    public func writeEnum(value: Int64): Unit {
        writeInt(value)
    }

    /// 写入长度前缀的字节数组
    public func writeArrayU8(slice: String): Unit {
        writeInt(slice.size)
        buffer.append(slice)
    }

    /// 结束消息 (写入 0 终止符)
    public func endMessage(): Unit {
        writeByte(0)
    }

    /// 获取输出字符串
    public func toString(): String {
        buffer.toString()
    }
}

// ============================================================================
// ResolveMode - 解析模式
// 严格翻译自: schema.rs - api::ResolveMode
//   #[repr(u8)]
//   pub enum ResolveMode { _none = 0, Disable = 1, Lazy = 2, Dev = 3, Bundle = 4 }
// ============================================================================

/// 解析模式 - 对应 Bun api::ResolveMode
public enum ResolveMode {
    | None       // 0 - 未指定
    | Disable    // 1 - 禁用解析
    | Lazy       // 2 - 延迟解析
    | Dev        // 3 - 开发模式
    | Bundle     // 4 - 打包模式

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case Disable => 1
            case Lazy => 2
            case Dev => 3
            case Bundle => 4
        }
    }

    public static func fromRaw(value: UInt8): ResolveMode {
        match (value) {
            case 0 => ResolveMode.None
            case 1 => ResolveMode.Disable
            case 2 => ResolveMode.Lazy
            case 3 => ResolveMode.Dev
            case 4 => ResolveMode.Bundle
            case _ => ResolveMode.None
        }
    }
}

// ============================================================================
// MessageLevel - 日志消息级别
// 严格翻译自: schema.rs - api::MessageLevel
//   #[repr(u32)]
//   pub enum MessageLevel { _none = 0, Err = 1, Warn = 2, Note = 3, Info = 4, Debug = 5 }
// ============================================================================

/// 日志消息级别 - 对应 Bun api::MessageLevel
public enum MessageLevel {
    | None   // 0
    | Err    // 1
    | Warn   // 2
    | Note   // 3
    | Info   // 4
    | Debug  // 5

    public func toRaw(): UInt32 {
        match (this) {
            case None => 0
            case Err => 1
            case Warn => 2
            case Note => 3
            case Info => 4
            case Debug => 5
        }
    }
}

// ============================================================================
// UnhandledRejections - 未处理拒绝策略
// 严格翻译自: schema.rs - api::UnhandledRejections
//   #[repr(u8)]
//   pub enum UnhandledRejections {
//       Strict = 0, Throw = 1, Warn = 2, None = 3, WarnWithErrorCode = 4, Bun = 5,
//   }
// ============================================================================

/// 未处理 Promise 拒绝策略 - 对应 Bun api::UnhandledRejections
public enum UnhandledRejectionMode {
    | Strict            // 0 - 严格模式
    | Throw             // 1 - 抛出异常
    | Warn              // 2 - 警告
    | None              // 3 - 无操作
    | WarnWithErrorCode // 4 - 带错误码警告
    | Bun               // 5 - Bun 默认策略

    public func toRaw(): UInt8 {
        match (this) {
            case Strict => 0
            case Throw => 1
            case Warn => 2
            case None => 3
            case WarnWithErrorCode => 4
            case Bun => 5
        }
    }
}

/// 未处理拒绝策略映射工具
public class UnhandledRejectionMap {
    private static let MAP: HashMap<String, UnhandledRejectionMode> = buildMap()

    private static func buildMap(): HashMap<String, UnhandledRejectionMode> {
        let m = HashMap<String, UnhandledRejectionMode>()
        m.put("strict", UnhandledRejectionMode.Strict)
        m.put("throw", UnhandledRejectionMode.Throw)
        m.put("warn", UnhandledRejectionMode.Warn)
        m.put("none", UnhandledRejectionMode.None)
        m.put("warn-with-error-code", UnhandledRejectionMode.WarnWithErrorCode)
        return m
    }

    /// 从字符串查找策略
    public static func lookup(name: String): ?UnhandledRejectionMode {
        MAP.get(name)
    }
}

// ============================================================================
// SourceMapMode - Source Map 模式
// 严格翻译自: schema.rs - api::SourceMapMode
//   #[repr(u8)]
//   pub enum SourceMapMode { None, Inline, External, Linked }
// ============================================================================

/// Source Map 模式 - 对应 Bun api::SourceMapMode
public enum SourceMapMode {
    | None       // 无 source map
    | Inline     // 内联 base64
    | External   // 外部 .map 文件
    | Linked     // 链接的外部文件

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case Inline => 1
            case External => 2
            case Linked => 3
        }
    }
}

/// SourceMap 类型别名
public type SourceMap = SourceMapMode

// ============================================================================
// Target - 编译目标平台
// 严格翻译自: schema.rs - api::Target
//   #[repr(u8)]
//   pub enum Target { _none = 0, browser = 1, node = 2, bun = 3, bun_macro = 4 }
// ============================================================================

/// 编译目标平台 - 对应 Bun api::Target
public enum SchemaTarget {
    | None       // 0 - 未指定
    | Browser    // 1 - 浏览器
    | Node       // 2 - Node.js
    | Bun        // 3 - Bun 运行时
    | BunMacro   // 4 - Bun 宏

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case Browser => 1
            case Node => 2
            case Bun => 3
            case BunMacro => 4
        }
    }

    public static func fromRaw(value: UInt8): SchemaTarget {
        match (value) {
            case 0 => SchemaTarget.None
            case 1 => SchemaTarget.Browser
            case 2 => SchemaTarget.Node
            case 3 => SchemaTarget.Bun
            case 4 => SchemaTarget.BunMacro
            case _ => SchemaTarget.Browser
        }
    }
}

// ============================================================================
// Loader - 文件加载器类型
// 严格翻译自: schema.rs - api::Loader
//   #[repr(u8)]
//   pub enum Loader { _none = 254, jsx = 1, js = 2, ts = 3, tsx = 4, ... }
// ============================================================================

/// 文件加载器类型 - 对应 Bun api::Loader
public enum Loader {
    | None           // 254 - 未指定
    | Jsx            // 1 - JSX
    | Js             // 2 - JavaScript
    | Ts             // 3 - TypeScript
    | Tsx            // 4 - TSX
    | Css            // 5 - CSS
    | File           // 6 - 文件 (复制)
    | Json           // 7 - JSON
    | Jsonc          // 8 - JSONC
    | Toml           // 9 - TOML
    | Wasm           // 10 - WebAssembly
    | Napi           // 11 - N-API 原生模块
    | Base64         // 12 - Base64 编码
    | DataUrl        // 13 - Data URL
    | Text           // 14 - 文本
    | Bunsh          // 15 - Bun Shell
    | Sqlite         // 16 - SQLite
    | SqliteEmbedded // 17 - 嵌入式 SQLite
    | Html           // 18 - HTML
    | Yaml           // 19 - YAML
    | Json5          // 20 - JSON5
    | Markdown       // 21 - Markdown

    public func toRaw(): UInt8 {
        match (this) {
            case None => 254
            case Jsx => 1
            case Js => 2
            case Ts => 3
            case Tsx => 4
            case Css => 5
            case File => 6
            case Json => 7
            case Jsonc => 8
            case Toml => 9
            case Wasm => 10
            case Napi => 11
            case Base64 => 12
            case DataUrl => 13
            case Text => 14
            case Bunsh => 15
            case Sqlite => 16
            case SqliteEmbedded => 17
            case Html => 18
            case Yaml => 19
            case Json5 => 20
            case Markdown => 21
        }
    }

    public static func fromRaw(n: UInt8): Loader {
        match (n) {
            case 1 => Loader.Jsx
            case 2 => Loader.Js
            case 3 => Loader.Ts
            case 4 => Loader.Tsx
            case 5 => Loader.Css
            case 6 => Loader.File
            case 7 => Loader.Json
            case 8 => Loader.Jsonc
            case 9 => Loader.Toml
            case 10 => Loader.Wasm
            case 11 => Loader.Napi
            case 12 => Loader.Base64
            case 13 => Loader.DataUrl
            case 14 => Loader.Text
            case 15 => Loader.Bunsh
            case 16 => Loader.Sqlite
            case 17 => Loader.SqliteEmbedded
            case 18 => Loader.Html
            case 19 => Loader.Yaml
            case 20 => Loader.Json5
            case 21 => Loader.Markdown
            case _ => Loader.None
        }
    }
}

// ============================================================================
// ImportKind - schema 层导入类型
// 严格翻译自: schema.rs - api::ImportKind
//   #[repr(u8)]
//   pub enum ImportKind { _none = 0, entry_point = 1, stmt = 2, ... }
// ============================================================================

/// Schema 层导入类型 - 对应 Bun api::ImportKind
public enum SchemaImportKind {
    | None           // 0
    | EntryPoint     // 1
    | Stmt           // 2
    | Require        // 3
    | Dynamic        // 4
    | RequireResolve // 5
    | At             // 6
    | Url            // 7
    | Internal       // 8

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case EntryPoint => 1
            case Stmt => 2
            case Require => 3
            case Dynamic => 4
            case RequireResolve => 5
            case At => 6
            case Url => 7
            case Internal => 8
        }
    }
}

// ============================================================================
// CssInJsBehavior - CSS-in-JS 行为
// 严格翻译自: schema.rs - api::CssInJsBehavior
//   #[repr(u8)]
//   pub enum CssInJsBehavior { _none = 0, Facade = 1, ... }
// ============================================================================

/// CSS-in-JS 行为 - 对应 Bun api::CssInJsBehavior
public enum CssInJsBehavior {
    | None              // 0
    | Facade            // 1
    | FacadeOnImportCss // 2
    | AutoOnImportCss   // 3

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case Facade => 1
            case FacadeOnImportCss => 2
            case AutoOnImportCss => 3
        }
    }
}

// ============================================================================
// PackagesMode - 包处理模式
// 严格翻译自: schema.rs - api::PackagesMode
//   #[repr(u8)]
//   pub enum PackagesMode { Bundle = 0, External = 1 }
// ============================================================================

/// 包处理模式 - 对应 Bun api::PackagesMode
public enum PackagesMode {
    | Bundle    // 0 - 打包
    | External  // 1 - 外部

    public func toRaw(): UInt8 {
        match (this) {
            case Bundle => 0
            case External => 1
        }
    }
}

/// Packages 类型别名
public type Packages = PackagesMode

// ============================================================================
// StringMap - 字符串键值映射
// 严格翻译自: schema.rs - api::StringMap
//   pub struct StringMap { pub keys: Vec<Box<[u8]>>, pub values: Vec<Box<[u8]>> }
// ============================================================================

/// 字符串键值映射 - 对应 Bun api::StringMap
public class StringMap {
    public var keys: Array<String>
    public var values: Array<String>

    public init() {
        keys = Array<String>()
        values = Array<String>()
    }

    public init(keys: Array<String>, values: Array<String>) {
        this.keys = keys
        this.values = values
    }

    /// 空 StringMap 常量
    public static let EMPTY: StringMap = StringMap()

    /// 获取键值对数量
    public func len(): Int64 {
        keys.size
    }

    /// 根据键查找值
    public func get(key: String): ?String {
        for (i in 0..keys.size) {
            if (keys[i] == key) {
                return Some(values[i])
            }
        }
        return None
    }

    /// 序列化到写入器
    public func encode(w: SchemaWriter): Unit {
        w.writeInt(keys.size)
        for (k in keys) {
            w.writeArrayU8(k)
        }
        w.writeInt(values.size)
        for (v in values) {
            w.writeArrayU8(v)
        }
    }
}

// ============================================================================
// LoaderMap - 加载器映射
// 严格翻译自: schema.rs - api::LoaderMap
//   pub struct LoaderMap { pub extensions: Vec<Box<[u8]>>, pub loaders: Vec<Loader> }
// ============================================================================

/// 加载器映射 - 对应 Bun api::LoaderMap
/// 文件扩展名到加载器类型的映射
public class LoaderMap {
    public var extensions: Array<String>
    public var loaders: Array<Loader>

    public init() {
        extensions = Array<String>()
        loaders = Array<Loader>()
    }
}

// ============================================================================
// JsxConfig - schema 层 JSX 配置
// 严格翻译自: schema.rs - api::Jsx
//   pub struct Jsx {
//       pub factory: Box<[u8]>,
//       pub runtime: JsxRuntime,
//       pub fragment: Box<[u8]>,
//       pub development: bool,
//       pub import_source: Box<[u8]>,
//       pub side_effects: bool,
//   }
// ============================================================================

/// Schema 层 JSX 配置 - 对应 Bun api::Jsx
public class JsxConfig {
    public var factory: String
    public var runtime: JsxRuntime
    public var fragment: String
    public var development: Bool
    public var importSource: String
    public var sideEffects: Bool

    public init() {
        factory = ""
        runtime = JsxRuntime.None
        fragment = ""
        development = false
        importSource = ""
        sideEffects = false
    }
}

// ============================================================================
// EnvConfig - 环境变量配置
// 严格翻译自: schema.rs - api::EnvConfig
//   pub struct EnvConfig { pub prefix: Option<Box<[u8]>>, pub defaults: Option<StringMap> }
// ============================================================================

/// 环境变量配置 - 对应 Bun api::EnvConfig
public class EnvConfig {
    public var prefix: ?String
    public var defaults: ?StringMap

    public init() {
        prefix = None
        defaults = None
    }
}

// ============================================================================
// DotEnvBehavior - .env 文件行为
// 严格翻译自: schema.rs - api::DotEnvBehavior (来自 bun_dotenv)
// ============================================================================

/// .env 文件加载行为
public enum DotEnvBehavior {
    | Disable     // 禁用 .env 加载
    | Auto        // 自动加载
    | LoadAll     // 加载所有 .env 文件
    | Prefix      // 仅加载带前缀的变量
}

// ============================================================================
// LoadedEnvConfig - 已加载的环境变量配置
// 严格翻译自: schema.rs - api::LoadedEnvConfig
// ============================================================================

/// 已加载的环境变量配置 - 对应 Bun api::LoadedEnvConfig
public class LoadedEnvConfig {
    public var dotenv: DotEnvBehavior
    public var defaults: StringMap
    public var prefix: String

    public init() {
        dotenv = DotEnvBehavior.Auto
        defaults = StringMap()
        prefix = ""
    }
}

// ============================================================================
// FrameworkEntryPointType - 框架入口点类型
// 严格翻译自: schema.rs - api::FrameworkEntryPointType
// ============================================================================

/// 框架入口点类型 - 对应 Bun api::FrameworkEntryPointType
public enum FrameworkEntryPointType {
    | None       // 0
    | Client     // 1
    | Server     // 2
    | Fallback   // 3

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case Client => 1
            case Server => 2
            case Fallback => 3
        }
    }
}

// ============================================================================
// FrameworkEntryPoint - 框架入口点
// 严格翻译自: schema.rs - api::FrameworkEntryPoint
// ============================================================================

/// 框架入口点 - 对应 Bun api::FrameworkEntryPoint
public class FrameworkEntryPoint {
    public var kind: FrameworkEntryPointType
    public var path: String
    public var env: LoadedEnvConfig

    public init() {
        kind = FrameworkEntryPointType.None
        path = ""
        env = LoadedEnvConfig()
    }
}

// ============================================================================
// FrameworkEntryPointMap - 框架入口点映射
// 严格翻译自: schema.rs - api::FrameworkEntryPointMap
// ============================================================================

/// 框架入口点映射 - 对应 Bun api::FrameworkEntryPointMap
public class FrameworkEntryPointMap {
    public var client: ?FrameworkEntryPoint
    public var server: ?FrameworkEntryPoint
    public var fallback: ?FrameworkEntryPoint

    public init() {
        client = None
        server = None
        fallback = None
    }
}

// ============================================================================
// LoadedFramework - 已加载的框架配置
// 严格翻译自: schema.rs - api::LoadedFramework
// ============================================================================

/// 已加载的框架配置 - 对应 Bun api::LoadedFramework
public class LoadedFramework {
    public var packageName: String
    public var displayName: String
    public var development: Bool
    public var entryPoints: FrameworkEntryPointMap
    public var clientCssInJs: CssInJsBehavior
    public var overrideModules: StringMap

    public init() {
        packageName = ""
        displayName = ""
        development = true
        entryPoints = FrameworkEntryPointMap()
        clientCssInJs = CssInJsBehavior.None
        overrideModules = StringMap()
    }
}

// ============================================================================
// TransformOptions - 转换选项
// 严格翻译自: schema.rs - api::TransformOptions
//   完整字段集，顺序与 Zig 结构体一致。
//   Default 等价于 std.mem.zeroes(TransformOptions)。
// ============================================================================

/// 转换选项 - 对应 Bun api::TransformOptions
/// 打包/转换操作的完整配置
public class TransformOptions {
    // -- JSX --
    public var jsx: ?JsxConfig

    // -- TypeScript --
    public var tsconfigOverride: ?String

    // -- 解析 --
    public var resolve: ?ResolveMode
    public var origin: ?String
    public var absoluteWorkingDir: ?String

    // -- 定义 --
    public var define: ?StringMap

    // -- 丢弃 --
    public var drop: Array<String>

    // -- 特性标志 --
    public var featureFlags: Array<String>

    // -- 解析选项 --
    public var preserveSymlinks: ?Bool

    // -- 入口点 --
    public var entryPoints: Array<String>

    // -- 写入 --
    public var write: ?Bool

    // -- 注入 --
    public var inject: Array<String>

    // -- 输出 --
    public var outputDir: ?String

    // -- 外部模块 --
    public var external: Array<String>

    // -- 加载器 --
    public var loaders: ?LoaderMap

    // -- 主字段 --
    public var mainFields: Array<String>

    // -- 目标 --
    public var target: ?SchemaTarget

    // -- 服务 --
    public var serve: ?Bool

    // -- 环境文件 --
    public var envFiles: Array<String>
    public var disableDefaultEnvFiles: Bool

    // -- 扩展名顺序 --
    public var extensionOrder: Array<String>

    // -- 摘要 --
    public var noSummary: ?Bool

    // -- HMR --
    public var disableHmr: Bool

    // -- 端口 --
    public var port: ?UInt16

    // -- 日志级别 --
    public var logLevel: ?MessageLevel

    // -- Source Map --
    public var sourceMap: ?SourceMapMode

    // -- 条件 --
    public var conditions: Array<String>

    // -- 包模式 --
    public var packages: ?PackagesMode

    // -- DCE --
    public var ignoreDceAnnotations: Bool

    // -- Serve 子选项 --
    public var servePlugins: ?Array<String>
    public var serveMinifySyntax: ?Bool
    public var serveMinifyWhitespace: ?Bool
    public var serveMinifyIdentifiers: ?Bool
    public var serveEnvBehavior: DotEnvBehavior
    public var serveEnvPrefix: ?String
    public var serveSplitting: Bool
    public var servePublicPath: ?String
    public var serveHmr: ?Bool
    public var serveDefine: ?StringMap

    // -- 插件 --
    public var allowAddons: ?Bool

    // -- 未处理拒绝 --
    public var unhandledRejections: ?UnhandledRejectionMode

    // -- bunfig 路径 --
    public var bunfigPath: String

    public init() {
        jsx = None
        tsconfigOverride = None
        resolve = None
        origin = None
        absoluteWorkingDir = None
        define = None
        drop = Array<String>()
        featureFlags = Array<String>()
        preserveSymlinks = None
        entryPoints = Array<String>()
        write = None
        inject = Array<String>()
        outputDir = None
        external = Array<String>()
        loaders = None
        mainFields = Array<String>()
        target = None
        serve = None
        envFiles = Array<String>()
        disableDefaultEnvFiles = false
        extensionOrder = Array<String>()
        noSummary = None
        disableHmr = false
        port = None
        logLevel = None
        sourceMap = None
        conditions = Array<String>()
        packages = None
        ignoreDceAnnotations = false
        servePlugins = None
        serveMinifySyntax = None
        serveMinifyWhitespace = None
        serveMinifyIdentifiers = None
        serveEnvBehavior = DotEnvBehavior.Auto
        serveEnvPrefix = None
        serveSplitting = false
        servePublicPath = None
        serveHmr = None
        serveDefine = None
        allowAddons = None
        unhandledRejections = None
        bunfigPath = ""
    }
}

// ============================================================================
// NpmRegistry - NPM 注册表配置
// 严格翻译自: schema.rs - api::NpmRegistry
// ============================================================================

/// NPM 注册表配置 - 对应 Bun api::NpmRegistry
public class NpmRegistry {
    public var url: String
    public var username: String
    public var password: String
    public var token: String
    public var email: String

    public init() {
        url = ""
        username = ""
        password = ""
        token = ""
        email = ""
    }

    /// 复制
    public func dupe(): NpmRegistry {
        let copy = NpmRegistry()
        copy.url = url
        copy.username = username
        copy.password = password
        copy.token = token
        copy.email = email
        return copy
    }
}

// ============================================================================
// BunInstall - 安装配置
// 严格翻译自: schema.rs - api::BunInstall
//   完整字段集，Default 等价于 std.mem.zeroes(BunInstall)。
// ============================================================================

/// 安装配置 - 对应 Bun api::BunInstall
public class BunInstall {
    // -- 注册表 --
    public var defaultRegistry: ?NpmRegistry
    public var scoped: ?HashMap<String, NpmRegistry>

    // -- 锁文件 --
    public var lockfilePath: ?String
    public var saveLockfilePath: ?String
    public var saveLockfile: ?Bool
    public var saveYarnLockfile: ?Bool
    public var saveTextLockfile: ?Bool
    public var frozenLockfile: ?Bool

    // -- 缓存 --
    public var cacheDirectory: ?String
    public var disableCache: ?Bool
    public var disableManifestCache: ?Bool

    // -- 安装选项 --
    public var dryRun: ?Bool
    public var force: ?Bool
    public var production: ?Bool
    public var exact: ?Bool
    public var ignoreScripts: ?Bool

    // -- 依赖类型 --
    public var saveDev: ?Bool
    public var saveOptional: ?Bool
    public var savePeer: ?Bool

    // -- 全局 --
    public var globalDir: ?String
    public var globalBinDir: ?String
    public var globalStore: ?Bool

    // -- 并发 --
    public var concurrentScripts: ?UInt32

    // -- 安全 --
    public var cafile: ?String
    public var securityScanner: ?String
    public var minimumReleaseAge: ?Float64
    public var minimumReleaseAgeExcludes: ?Array<String>

    // -- 链接 --
    public var linkWorkspacePackages: ?Bool
    public var nativeBinLinks: Array<String>

    // -- 包管理器 --
    public var hoistPattern: ?String
    public var publicHoistPattern: ?String

    public init() {
        defaultRegistry = None
        scoped = None
        lockfilePath = None
        saveLockfilePath = None
        saveLockfile = None
        saveYarnLockfile = None
        saveTextLockfile = None
        frozenLockfile = None
        cacheDirectory = None
        disableCache = None
        disableManifestCache = None
        dryRun = None
        force = None
        production = None
        exact = None
        ignoreScripts = None
        saveDev = None
        saveOptional = None
        savePeer = None
        globalDir = None
        globalBinDir = None
        globalStore = None
        concurrentScripts = None
        cafile = None
        securityScanner = None
        minimumReleaseAge = None
        minimumReleaseAgeExcludes = None
        linkWorkspacePackages = None
        nativeBinLinks = Array<String>()
        hoistPattern = None
        publicHoistPattern = None
    }
}

// ============================================================================
// FallbackStep - 降级步骤
// 严格翻译自: schema.rs - api::FallbackStep
// ============================================================================

/// 降级步骤 - 对应 Bun api::FallbackStep
public enum FallbackStep {
    | None               // 0
    | SsrDisabled        // 1 - SSR 禁用
    | CreateVM           // 2 - 创建虚拟机
    | ConfigureRouter    // 3 - 配置路由
    | ConfigureDefines   // 4 - 配置定义
    | ResolveEntryPoint  // 5 - 解析入口点
    | LoadEntryPoint     // 6 - 加载入口点
    | EvalEntryPoint     // 7 - 执行入口点
    | FetchEventHandler  // 8 - 获取事件处理器

    public func toRaw(): UInt8 {
        match (this) {
            case None => 0
            case SsrDisabled => 1
            case CreateVM => 2
            case ConfigureRouter => 3
            case ConfigureDefines => 4
            case ResolveEntryPoint => 5
            case LoadEntryPoint => 6
            case EvalEntryPoint => 7
            case FetchEventHandler => 8
        }
    }
}

// ============================================================================
// JsException - JS 异常信息
// 严格翻译自: schema.rs - api::JsException
// ============================================================================

/// JS 异常信息 - 对应 Bun api::JsException
public class JsException {
    public var name: ?String
    public var message: ?String
    public var runtimeType: ?UInt16
    public var code: ?UInt8

    public init() {
        name = None
        message = None
        runtimeType = None
        code = None
    }

    /// 序列化到写入器
    public func encode(w: SchemaWriter): Unit {
        match (name) {
            case Some(v) =>
                w.writeFieldId(1)
                w.writeArrayU8(v)
            case None => {}
        }
        match (message) {
            case Some(v) =>
                w.writeFieldId(2)
                w.writeArrayU8(v)
            case None => {}
        }
        match (runtimeType) {
            case Some(v) =>
                w.writeFieldId(3)
                w.writeInt(Int64(v))
            case None => {}
        }
        match (code) {
            case Some(v) =>
                w.writeFieldId(4)
                w.writeInt(Int64(v))
            case None => {}
        }
        w.endMessage()
    }
}

// ============================================================================
// Log - 日志结构
// 严格翻译自: schema.rs - api::Log
// ============================================================================

/// 日志结构 - 对应 Bun api::Log
public class SchemaLog {
    public var warnings: UInt32
    public var errors: UInt32

    public init() {
        warnings = 0
        errors = 0
    }

    /// 序列化到写入器
    public func encode(w: SchemaWriter): Unit {
        w.writeInt(Int64(warnings))
        w.writeInt(Int64(errors))
        w.writeInt(0)  // msgs.len
    }
}

// ============================================================================
// Router - 路由信息
// 严格翻译自: schema.rs - api::Router
// ============================================================================

/// 路由信息 - 对应 Bun api::Router
public class SchemaRouter {
    public var routes: StringMap
    public var route: Int32
    public var params: StringMap

    public init() {
        routes = StringMap()
        route = 0
        params = StringMap()
    }

    /// 序列化到写入器
    public func encode(w: SchemaWriter): Unit {
        routes.encode(w)
        w.writeInt(Int64(route))
        params.encode(w)
    }
}

// ============================================================================
// Problems - 问题集合
// 严格翻译自: schema.rs - api::Problems
// ============================================================================

/// 问题集合 - 对应 Bun api::Problems
public class Problems {
    public var code: UInt16
    public var name: String
    public var exceptions: Array<JsException>
    public var build: SchemaLog

    public init() {
        code = 0
        name = ""
        exceptions = Array<JsException>()
        build = SchemaLog()
    }

    /// 序列化到写入器
    public func encode(w: SchemaWriter): Unit {
        w.writeInt(Int64(code))
        w.writeArrayU8(name)
        w.writeInt(exceptions.size)
        for (ex in exceptions) {
            ex.encode(w)
        }
        build.encode(w)
    }
}

// ============================================================================
// FallbackMessageContainer - 降级消息容器
// 严格翻译自: schema.rs - api::FallbackMessageContainer
// ============================================================================

/// 降级消息容器 - 对应 Bun api::FallbackMessageContainer
public class FallbackMessageContainer {
    public var message: ?String
    public var router: ?SchemaRouter
    public var reason: ?FallbackStep
    public var problems: ?Problems
    public var cwd: ?String

    public init() {
        message = None
        router = None
        reason = None
        problems = None
        cwd = None
    }

    /// 序列化到写入器
    public func encode(w: SchemaWriter): Unit {
        match (message) {
            case Some(v) =>
                w.writeFieldId(1)
                w.writeArrayU8(v)
            case None => {}
        }
        match (router) {
            case Some(v) =>
                w.writeFieldId(2)
                v.encode(w)
            case None => {}
        }
        match (reason) {
            case Some(v) =>
                w.writeFieldId(3)
                w.writeEnum(Int64(v.toRaw()))
            case None => {}
        }
        match (problems) {
            case Some(v) =>
                w.writeFieldId(4)
                v.encode(w)
            case None => {}
        }
        match (cwd) {
            case Some(v) =>
                w.writeFieldId(5)
                w.writeArrayU8(v)
            case None => {}
        }
        w.endMessage()
    }
}
