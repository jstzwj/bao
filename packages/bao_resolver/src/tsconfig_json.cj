// tsconfig.json 解析器
// 严格翻译自: src/resolver/tsconfig_json.rs (866行)
//   Bun 的 tsconfig.json 解析器，包含:
//     - TSConfigJSON: TypeScript 配置结构
//     - JsonCache: JSON 解析缓存
//     - JsonMode: JSON 解析模式
//     - JsxFieldSet: JSX 字段集
//     - ImportsNotUsedAsValue: importsNotUsedAsValues 枚举
//     - PathsMap: 路径映射表
package bao_resolver

import bao_core.*
import bao_collections.*

// ============================================================================
// JsonMode - JSON 解析模式
// 严格翻译自: tsconfig_json.rs:21-25
//   pub enum JsonMode { Json, Jsonc }
// ============================================================================

/// JSON 解析模式 - 对应 Bun JsonMode
public enum JsonMode {
    | Json    // 严格 JSON
    | Jsonc   // JSON with Comments (tsconfig.json)
}

// ============================================================================
// JsxField - JSX 字段枚举
// 严格翻译自: tsconfig_json.rs:136-143
//   pub enum JsxField { Factory, Fragment, ImportSource, Runtime, Development }
// ============================================================================

/// JSX 字段 - 对应 Bun JsxField
/// 用于跟踪 tsconfig.json 中哪些 JSX 字段被显式设置
public enum JsxField {
    | Factory
    | Fragment
    | ImportSource
    | Runtime
    | Development

    public operator func ==(right: JsxField): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case Factory => 0
            case Fragment => 1
            case ImportSource => 2
            case Runtime => 3
            case Development => 4
        }
    }
}

// ============================================================================
// JsxFieldSet - JSX 字段集
// 严格翻译自: tsconfig_json.rs:145
//   pub type JsxFieldSet = EnumSet<JsxField>
// ============================================================================

/// JSX 字段集 - 对应 Bun JsxFieldSet
/// 记录 tsconfig.json 中哪些 JSX 字段被显式设置
public class JsxFieldSet {
    public var factory: Bool
    public var fragment: Bool
    public var importSource: Bool
    public var runtime: Bool
    public var development: Bool

    public init() {
        factory = false
        fragment = false
        importSource = false
        runtime = false
        development = false
    }

    /// 是否为空
    public func isEmpty(): Bool {
        !factory && !fragment && !importSource && !runtime && !development
    }

    /// 插入字段
    public func insert(field: JsxField): Unit {
        match (field) {
            case Factory => factory = true
            case Fragment => fragment = true
            case ImportSource => importSource = true
            case Runtime => runtime = true
            case Development => development = true
        }
    }

    /// 是否包含字段
    public func contains(field: JsxField): Bool {
        match (field) {
            case Factory => factory
            case Fragment => fragment
            case ImportSource => importSource
            case Runtime => runtime
            case Development => development
        }
    }
}

// ============================================================================
// TSConfigJSON - TypeScript 配置结构
// 严格翻译自: tsconfig_json.rs:147-198
//   pub struct TSConfigJSON { abs_path, base_url, paths, jsx, ... }
// ============================================================================

/// TypeScript 配置 - 对应 Bun TSConfigJSON
/// tsconfig.json 的解析结果，包含编译器选项和路径映射
public class TSConfigJSON {
    /// 配置文件绝对路径
    public var absPath: String
    /// compilerOptions.baseUrl 的绝对路径
    public var baseUrl: String
    /// paths 使用的 baseUrl (当 baseUrl 缺失时为 ".")
    /// 对应 TypeScript 4.1 "paths without baseUrl" 功能
    public var baseUrlForPaths: String
    /// 继承的父配置路径 (extends 字段)
    public var extends: String
    /// compilerOptions.paths 路径映射
    /// 键是匹配模式，值是回退路径数组
    /// 模式和路径都可以有一个 "*" 通配符
    public var paths: HashMap<String, Array<String>>
    /// JSX 配置
    public var jsx: JSXPragma
    /// JSX 字段是否被显式设置
    public var jsxFlags: JsxFieldSet
    /// useDefineForClassFields 选项
    public var useDefineForClassFields: ?Bool
    /// preserveImportsNotUsedAsValues 选项
    public var preserveImportsNotUsedAsValues: ?Bool
    /// emitDecoratorMetadata 选项
    public var emitDecoratorMetadata: Bool
    /// experimentalDecorators 选项
    public var experimentalDecorators: Bool

    public init(absPath: String) {
        this.absPath = absPath
        baseUrl = ""
        baseUrlForPaths = ""
        extends = ""
        paths = HashMap<String, Array<String>>()
        jsx = JSXPragma()
        jsxFlags = JsxFieldSet()
        useDefineForClassFields = None
        preserveImportsNotUsedAsValues = Some(false)
        emitDecoratorMetadata = false
        experimentalDecorators = false
    }
}

// ============================================================================
// JSXPragma - JSX 编译指示
// 严格翻译自: tsconfig_json.rs 引用的 options::jsx::Pragma
//   Zig 默认: factory=["React","createElement"], fragment=["React","Fragment"]
// ============================================================================

/// JSX 编译指示 - 对应 Bun JSX.Pragma
public class JSXPragma {
    /// 工厂函数 (如 ["React", "createElement"])
    public var factory: Array<String>
    /// 片段函数 (如 ["React", "Fragment"])
    public var fragment: Array<String>
    /// 运行时模式
    public var runtime: JSXRuntimeMode
    /// 开发模式
    public var development: Bool
    /// 导入源 (如 "react")
    public var importSource: String
    /// 包名 (如 "solid-js")
    public var packageName: String

    public init() {
        factory = ["React", "createElement"]
        fragment = ["React", "Fragment"]
        runtime = JSXRuntimeMode.Automatic
        development = false
        importSource = "react"
        packageName = ""
    }

    public init(factory: Array<String>, fragment: Array<String>) {
        this.factory = factory
        this.fragment = fragment
        runtime = JSXRuntimeMode.Automatic
        development = false
        importSource = "react"
        packageName = ""
    }
}

/// JSX 运行时模式 - 对应 Bun JSX.Runtime
public enum JSXRuntimeMode {
    | Classic       // 经典模式: React.createElement
    | Automatic     // 自动模式: React 17+ 自动导入
    | Preserve      // 保留: 不转换 JSX
    | Solid         // Solid.js 模式

    public operator func ==(right: JSXRuntimeMode): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case Classic => 0
            case Automatic => 1
            case Preserve => 2
            case Solid => 3
        }
    }
}

// ============================================================================
// ImportsNotUsedAsValue - importsNotUsedAsValues 枚举
// 严格翻译自: tsconfig_json.rs:200-213
//   pub enum ImportsNotUsedAsValue { Preserve, Err, Remove, Invalid }
// ============================================================================

/// importsNotUsedAsValues 选项 - 对应 Bun ImportsNotUsedAsValue
public enum ImportsNotUsedAsValue {
    | Preserve    // 保留未使用的导入
    | Err         // 报错
    | Remove      // 移除
    | Invalid     // 无效值

    public operator func ==(right: ImportsNotUsedAsValue): Bool {
        ordinal() == right.ordinal()
    }

    public func ordinal(): Int64 {
        match (this) {
            case Preserve => 0
            case Err => 1
            case Remove => 2
            case Invalid => 3
        }
    }
}

/// importsNotUsedAsValues 查找表 - 对应 IMPORTS_NOT_USED_AS_VALUE_LIST
public let IMPORTS_NOT_USED_AS_VALUE_MAP: HashMap<String, ImportsNotUsedAsValue> = { =>
    let m = HashMap<String, ImportsNotUsedAsValue>()
    m.put("preserve", ImportsNotUsedAsValue.Preserve)
    m.put("error", ImportsNotUsedAsValue.Err)
    m.put("remove", ImportsNotUsedAsValue.Remove)
    m
}()

// ============================================================================
// TSConfigJSON 方法
// ============================================================================

/// TSConfigJSON 扩展方法
public class TSConfigJSONHelper {

    /// 是否有 baseUrl - 对应 TSConfigJSON.has_base_url()
    public static func hasBaseUrl(config: TSConfigJSON): Bool {
        config.baseUrl.size > 0
    }

    /// 合并 JSX 配置 - 对应 TSConfigJSON.merge_jsx()
    /// 仅覆盖在 tsconfig 中被显式设置的字段
    public static func mergeJSX(config: TSConfigJSON, current: JSXPragma): JSXPragma {
        let out = JSXPragma(current.factory, current.fragment)
        out.runtime = current.runtime
        out.development = current.development
        out.importSource = current.importSource
        out.packageName = current.packageName

        if (config.jsxFlags.factory) {
            out.factory = config.jsx.factory
        }
        if (config.jsxFlags.fragment) {
            out.fragment = config.jsx.fragment
        }
        if (config.jsxFlags.importSource) {
            out.importSource = config.jsx.importSource
        }
        if (config.jsxFlags.runtime) {
            out.runtime = config.jsx.runtime
        }
        if (config.jsxFlags.development) {
            out.development = config.jsx.development
        }
        out
    }

    /// 验证 tsconfig 路径模式 - 对应 is_valid_tsconfig_path_pattern()
    /// 检查模式中是否包含超过一个 "*" 通配符
    public static func isValidPathPattern(text: String): Bool {
        var foundAsterisk = false
        for (i in 0..text.size) {
            if (text[i] == UInt8(42)) { // '*'
                if (foundAsterisk) {
                    return false
                }
                foundAsterisk = true
            }
        }
        true
    }

    /// 验证无 baseUrl 时的路径模式 - 对应 is_valid_tsconfig_path_no_base_url_pattern()
    /// 当没有 baseUrl 时，路径必须是相对路径或绝对路径
    public static func isValidPathNoBaseUrlPattern(text: String): Bool {
        let n = text.size
        if (n == 0) {
            return false
        }
        if (n == 1) {
            return text[0] == UInt8(46) // '.'
        }
        if (n == 2) {
            return text[0] == UInt8(46) && (text[1] == UInt8(46) || text[1] == UInt8(47))
        }
        let c0 = text[0]
        let c1 = text[1]
        let c2 = text[2]

        let startsWithDotSlash = c0 == UInt8(46) && (c1 == UInt8(47) || c1 == UInt8(92))
        let startsWithDotDotSlash = c0 == UInt8(46) && c1 == UInt8(46) && (c2 == UInt8(47) || c2 == UInt8(92))
        if (startsWithDotSlash || startsWithDotDotSlash) {
            return true
        }

        // 绝对 Unix 路径 "/"
        if (c0 == UInt8(47)) {
            return true
        }

        false
    }

    /// 解析 JSX 成员表达式 - 对应 parse_member_expression_for_jsx()
    /// 将 "React.createElement" 解析为 ["React", "createElement"]
    public static func parseMemberExpressionForJSX(text: String): Array<String> {
        if (text.size == 0) {
            return []
        }
        text.split(".")
    }

    /// 替换 ${configDir} 模板变量 - 对应 str_replacing_templates()
    /// TypeScript 5.5 引入的 ${configDir} 模板变量支持
    public static func replaceConfigDir(input: String, configDir: String): String {
        if (!input.contains("${configDir}")) {
            return input
        }
        input.replace("${configDir}", configDir)
    }
}

// ============================================================================
// JsonCache - JSON 解析缓存
// 严格翻译自: tsconfig_json.rs:36-126
//   pub struct JsonCache { bump: Option<Arena> }
// ============================================================================

/// JSON 解析缓存 - 对应 Bun JsonCache
/// 缓存 JSON 解析的 arena 分配器，用于 package.json 和 tsconfig.json 解析
/// arena 从不重置 — package.json/tsconfig.json AST 在进程生命周期内缓存
public class JsonCache {
    /// 缓存的解析结果
    private var cache: HashMap<String, Any>

    public init() {
        cache = HashMap<String, Any>()
    }

    /// 解析 tsconfig - 对应 parse_tsconfig()
    public func parseTSConfig(source: String): ?TSConfigJSON {
        // 简化实现: 实际需要 JSON 解析器
        None
    }

    /// 解析 package.json - 对应 parse_package_json()
    public func parsePackageJson(source: String): ?PackageJsonInfo {
        // 简化实现: 实际需要 JSON 解析器
        None
    }
}

