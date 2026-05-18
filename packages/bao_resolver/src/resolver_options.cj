// 解析器选项
// 严格翻译自: src/resolver/options.rs
//   Resolver-tier options — the canonical resolver-input types.
//   包含:
//     - Packages: 打包策略
//     - ExternalModules: 外部模块配置
//     - WildcardPattern: 通配符模式
//     - Conditions: 条件导出映射
//     - ExtOrder / ExtensionOrder: 扩展名顺序
//     - BundleOptions: 解析器打包选项子集
//     - TargetMainFields: 各目标平台默认 main 字段顺序
package bao_resolver

import bao_core.*
import bao_collections.*

// ============================================================================
// Packages - 打包策略
// 严格翻译自: options.rs:16-21
//   pub enum Packages { Bundle, External }
// ============================================================================

/// 打包策略 - 对应 Bun Packages
/// Bun: pub enum Packages { #[default] Bundle, External }
public enum PackageStrategy {
    | Bundle     // 正常打包 (默认)
    | External   // 所有包标记为外部

    public operator func ==(right: PackageStrategy): Bool {
        match (this) {
            case Bundle => match (right) { case Bundle => true case _ => false }
            case External => match (right) { case External => true case _ => false }
        }
    }

    public operator func !=(right: PackageStrategy): Bool {
        !(this == right)
    }
}

// ============================================================================
// WildcardPattern - 通配符外部模式
// 严格翻译自: options.rs:41-45
//   pub struct WildcardPattern { prefix: Box<[u8]>, suffix: Box<[u8]> }
// ============================================================================

/// 通配符外部模式 - 对应 Bun WildcardPattern
public class WildcardPattern {
    public var prefix: String
    public var suffix: String

    public init(prefix: String, suffix: String) {
        this.prefix = prefix
        this.suffix = suffix
    }

    /// 匹配检查 - 对应 Bun Resolver.matchesUserExternalPattern()
    public func matches(importPath: String): Bool {
        if (importPath.size >= prefix.size + suffix.size &&
            importPath.startsWith(prefix) &&
            importPath.endsWith(suffix)) {
            return true
        }
        false
    }
}

// ============================================================================
// ExternalModules - 外部模块配置
// 严格翻译自: options.rs:24-50
//   pub struct ExternalModules { patterns, abs_paths, node_modules }
// ============================================================================

/// 外部模块配置 - 对应 Bun ExternalModules
public class ExternalModules {
    public var patterns: ArrayList<WildcardPattern>
    public var absPaths: HashSet<String>
    public var nodeModules: HashSet<String>

    public init() {
        patterns = ArrayList<WildcardPattern>()
        absPaths = HashSet<String>()
        nodeModules = HashSet<String>()
    }
}

// ============================================================================
// Conditions - 条件导出映射
// 严格翻译自: options.rs:53-58
//   pub struct Conditions { import, require, style }
// ============================================================================

/// 条件导出映射 - 对应 Bun Conditions
/// 每种导入类型有不同的条件匹配映射
public class Conditions {
    /// import 条件
    public var importConditions: HashMap<String, Bool>
    /// require 条件
    public var requireConditions: HashMap<String, Bool>
    /// style 条件
    public var styleConditions: HashMap<String, Bool>

    public init() {
        importConditions = HashMap<String, Bool>()
        requireConditions = HashMap<String, Bool>()
        styleConditions = HashMap<String, Bool>()
    }
}

// ============================================================================
// ExtOrder - 扩展名顺序标签
// 严格翻译自: options.rs:67-83
//   pub enum ExtOrder { DefaultDefault, DefaultEsm, NodeModulesDefault,
//                       NodeModulesEsm, Css, MainField }
// ============================================================================

/// 扩展名顺序标签 - 对应 Bun ExtOrder
/// 用于选择不同的扩展名解析顺序
public enum ExtOrder {
    | DefaultDefault      // 默认 (CJS/通用)
    | DefaultEsm          // 默认 (ESM)
    | NodeModulesDefault  // node_modules (CJS/通用)
    | NodeModulesEsm      // node_modules (ESM)
    | Css                 // CSS
    | MainField           // main 字段解析

    public operator func ==(right: ExtOrder): Bool {
        ordinal() == right.ordinal()
    }

    public operator func !=(right: ExtOrder): Bool {
        !(this == right)
    }

    public func ordinal(): Int64 {
        match (this) {
            case DefaultDefault => 0
            case DefaultEsm => 1
            case NodeModulesDefault => 2
            case NodeModulesEsm => 3
            case Css => 4
            case MainField => 5
        }
    }
}

// ============================================================================
// ExtensionOrderGroup / ExtensionOrder - 扩展名顺序
// 严格翻译自: options.rs:92-168
// ============================================================================

/// 扩展名顺序组 - 对应 Bun ExtensionOrderGroup
public class ExtensionOrderGroup {
    public var defaultOrder: Array<String>
    public var esmOrder: Array<String>

    public init() {
        defaultOrder = EXTENSION_ORDER_DEFAULT
        esmOrder = MODULE_EXTENSION_ORDER_DEFAULT
    }

    public init(defaultOrder: Array<String>, esmOrder: Array<String>) {
        this.defaultOrder = defaultOrder
        this.esmOrder = esmOrder
    }
}

/// 扩展名顺序 - 对应 Bun ExtensionOrder
public class ExtensionOrder {
    public var defaultGroup: ExtensionOrderGroup
    public var nodeModules: ExtensionOrderGroup
    public var css: Array<String>

    public init() {
        defaultGroup = ExtensionOrderGroup()
        nodeModules = ExtensionOrderGroup(
            NODE_MODULES_EXTENSION_ORDER,
            NODE_MODULES_MODULE_EXTENSION_ORDER
        )
        css = CSS_EXTENSION_ORDER
    }
}

// ============================================================================
// 扩展名默认值 - 严格翻译自 options.rs:170-193
//   bundle_options::defaults::*
// ============================================================================

/// CSS 扩展名顺序 - 对应 CSS_EXTENSION_ORDER
public let CSS_EXTENSION_ORDER: Array<String> = [".css"]

/// 默认扩展名顺序 - 对应 EXTENSION_ORDER
/// .tsx, .ts, .jsx, .cts, .cjs, .js, .mjs, .mts, .json
public let EXTENSION_ORDER_DEFAULT: Array<String> = [
    ".tsx", ".ts", ".jsx", ".cts", ".cjs", ".js", ".mjs", ".mts", ".json"
]

/// ESM 模块扩展名顺序 - 对应 MODULE_EXTENSION_ORDER
/// .tsx, .jsx, .mts, .ts, .mjs, .js, .cts, .cjs, .json
public let MODULE_EXTENSION_ORDER_DEFAULT: Array<String> = [
    ".tsx", ".jsx", ".mts", ".ts", ".mjs", ".js", ".cts", ".cjs", ".json"
]

/// node_modules 扩展名顺序 - 对应 node_modules::EXTENSION_ORDER
public let NODE_MODULES_EXTENSION_ORDER: Array<String> = [
    ".jsx", ".cjs", ".js", ".mjs", ".mts", ".tsx", ".ts", ".cts", ".json"
]

/// node_modules ESM 扩展名顺序 - 对应 node_modules::MODULE_EXTENSION_ORDER
public let NODE_MODULES_MODULE_EXTENSION_ORDER: Array<String> = [
    ".mjs", ".jsx", ".js", ".mts", ".tsx", ".ts", ".cjs", ".cts", ".json"
]

// ============================================================================
// ResolverBundleOptions - 解析器打包选项
// 严格翻译自: options.rs:207-299
//   pub struct BundleOptions { target, packages, jsx, ... }
// ============================================================================

/// 解析器打包选项 - 对应 Bun BundleOptions (解析器子集)
public class ResolverBundleOptions {
    public var target: BundleTarget
    public var packages: PackageStrategy
    public var extensionOrder: ExtensionOrder
    public var conditions: Conditions
    public var external: ExternalModules
    public var framework: ?FrameworkInfo
    public var globalCache: GlobalCache
    public var loadPackageJson: Bool
    public var loadTsconfigJson: Bool
    public var mainFieldExtensionOrder: Array<String>
    public var mainFields: Array<String>
    public var mainFieldsIsDefault: Bool
    public var markBuiltinsAsExternal: Bool
    public var polyfillNodeGlobals: Bool
    public var preferOfflineInstall: Bool
    public var preserveSymlinks: Bool
    public var rewriteJestForTests: Bool
    public var tsconfigOverride: ?String
    public var production: Bool
    public var outputDir: String
    public var rootDir: String
    public var publicPath: String
    public var compile: Bool
    public var supportsMultipleOutputs: Bool
    public var treeShaking: Bool
    public var allowRuntime: Bool

    public init() {
        target = BundleTarget.Browser
        packages = PackageStrategy.Bundle
        extensionOrder = ExtensionOrder()
        conditions = Conditions()
        external = ExternalModules()
        framework = None
        globalCache = GlobalCache.Auto
        loadPackageJson = true
        loadTsconfigJson = true
        mainFieldExtensionOrder = EXTENSION_ORDER_DEFAULT
        mainFields = DEFAULT_MAIN_FIELDS_BROWSER
        mainFieldsIsDefault = true
        markBuiltinsAsExternal = false
        polyfillNodeGlobals = false
        preferOfflineInstall = false
        preserveSymlinks = false
        rewriteJestForTests = false
        tsconfigOverride = None
        production = false
        outputDir = ""
        rootDir = ""
        publicPath = ""
        compile = false
        supportsMultipleOutputs = true
        treeShaking = false
        allowRuntime = true
    }

    /// 获取扩展名顺序 - 对应 BundleOptions.ext_order_slice()
    public func extOrderSlice(tag: ExtOrder): Array<String> {
        match (tag) {
            case DefaultDefault => extensionOrder.defaultGroup.defaultOrder
            case DefaultEsm => extensionOrder.defaultGroup.esmOrder
            case NodeModulesDefault => extensionOrder.nodeModules.defaultOrder
            case NodeModulesEsm => extensionOrder.nodeModules.esmOrder
            case Css => extensionOrder.css
            case MainField => mainFieldExtensionOrder
        }
    }

    /// 解析扩展名顺序类型 - 对应 ExtensionOrder.kind()
    public func extOrderKind(kind: ImportKind, isNodeModules: Bool): ExtOrder {
        match (kind) {
            case Url | AtConditional | At => ExtOrder.Css
            case Stmt | EntryPointBuild | EntryPointRun | Dynamic =>
                if (isNodeModules) {
                    ExtOrder.NodeModulesEsm
                } else {
                    ExtOrder.DefaultEsm
                }
            case _ =>
                if (isNodeModules) {
                    ExtOrder.NodeModulesDefault
                } else {
                    ExtOrder.DefaultDefault
                }
        }
    }

    /// 设置生产模式 - 对应 BundleOptions.setProduction()
    public func setProduction(value: Bool): Unit {
        production = value
    }
}

// ============================================================================
// ImportKind - 导入类型 (resolver 使用的完整版本)
// 严格翻译自: options.rs 引用的 bun_ast::ImportKind
// ============================================================================

/// 导入类型 - 对应 Bun ImportKind
public enum ImportKind {
    | Entry            // 入口点 (build)
    | EntryPointBuild  // 入口点 (build)
    | EntryPointRun    // 入口点 (run)
    | Stmt             // import 语句
    | Dynamic          // import() 表达式
    | Require          // require() 调用
    | RequireResolve   // require.resolve()
    | At               // CSS @import
    | AtConditional    // CSS 条件 @import
    | Url              // CSS url()

    /// 是否来自 CSS
    public func isFromCSS(): Bool {
        match (this) {
            case At | AtConditional | Url => true
            case _ => false
        }
    }
}

// ============================================================================
// BundleTarget - 打包目标平台
// 严格翻译自: options.rs 引用的 bun_ast::Target
// ============================================================================

/// 打包目标平台 - 对应 Bun Target
public enum BundleTarget {
    | Browser
    | Bun
    | BunMacro
    | Node
    | BakeServerComponentsSsr

    public func isServerSide(): Bool {
        match (this) {
            case BunMacro | Node | Bun | BakeServerComponentsSsr => true
            case Browser => false
        }
    }

    public func isBun(): Bool {
        match (this) {
            case BunMacro | Bun | BakeServerComponentsSsr => true
            case _ => false
        }
    }

    public func isNode(): Bool {
        match (this) {
            case Node => true
            case _ => false
        }
    }

    public operator func ==(right: BundleTarget): Bool {
        ordinal() == right.ordinal()
    }

    public operator func !=(right: BundleTarget): Bool {
        !(this == right)
    }

    public func ordinal(): Int64 {
        match (this) {
            case Browser => 0
            case Bun => 1
            case BunMacro => 2
            case Node => 3
            case BakeServerComponentsSsr => 4
        }
    }
}

// ============================================================================
// GlobalCache - 全局缓存策略
// ============================================================================

/// 全局缓存策略 - 对应 Bun GlobalCache
public enum GlobalCache {
    | Auto
    | Disable
    | Fallback
    | Force

    public func isEnabled(): Bool {
        match (this) {
            case Auto => true
            case Disable => false
            case Fallback => true
            case Force => true
        }
    }
}

// ============================================================================
// FrameworkInfo - 框架信息
// ============================================================================

/// 框架信息 - 对应 Bun Framework
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
// TargetMainFields - 各目标平台默认 main 字段顺序
// 严格翻译自: options.rs:319-357
//   DEFAULT_MAIN_FIELDS_NODE / BROWSER / BUN
// ============================================================================

/// Node 平台 main 字段顺序 - 对应 DEFAULT_MAIN_FIELDS_NODE
/// 注意: "module" 在 "main" 之后，因此 tree shaking 在 node 环境下不工作
/// 原因: 某些包错误地将 "module" 字段当作 "浏览器代码"
public let DEFAULT_MAIN_FIELDS_NODE: Array<String> = ["main", "module"]

/// Browser 平台 main 字段顺序 - 对应 DEFAULT_MAIN_FIELDS_BROWSER
/// "browser" 优先于 "module"，与 webpack 行为一致
public let DEFAULT_MAIN_FIELDS_BROWSER: Array<String> = [
    "browser", "module", "jsnext:main", "main"
]

/// Bun 平台 main 字段顺序 - 对应 DEFAULT_MAIN_FIELDS_BUN
public let DEFAULT_MAIN_FIELDS_BUN: Array<String> = [
    "module", "main", "jsnext:main"
]

/// 根据目标平台获取默认 main 字段
public func getDefaultMainFields(target: BundleTarget): Array<String> {
    match (target) {
        case Node => DEFAULT_MAIN_FIELDS_NODE
        case Browser => DEFAULT_MAIN_FIELDS_BROWSER
        case Bun | BunMacro | BakeServerComponentsSsr => DEFAULT_MAIN_FIELDS_BUN
    }
}

/// 获取默认条件
public func getDefaultConditions(target: BundleTarget): Array<String> {
    match (target) {
        case Node => ["node"]
        case Browser => ["browser", "module"]
        case Bun => ["bun", "node"]
        case BakeServerComponentsSsr => ["bun", "node"]
        case BunMacro => ["macro", "bun", "node"]
    }
}
