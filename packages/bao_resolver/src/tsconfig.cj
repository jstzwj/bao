// tsconfig.json 解析器
// 严格翻译自: src/resolver/tsconfig_json.zig
//
// Bun 的 tsconfig_json.zig 包含:
//   pub const TSConfigJSON = struct {
//       abs_path: string,
//       base_url: string,
//       base_url_for_paths: string,
//       extends: string,
//       paths: PathsMap,         // StringArrayHashMap([]string)
//       jsx: options.JSX.Pragma,
//       jsx_flags: JSXFieldSet,
//       use_define_for_class_fields: ?bool,
//       preserve_imports_not_used_as_values: ?bool,
//       emit_decorator_metadata: bool,
//       experimental_decorators: bool,
//   }
//
// 核心功能:
//   1. 解析 compilerOptions 中的所有字段
//   2. 处理 paths 映射 (@foo/* -> ./src/*)
//   3. 处理 extends 继承链
//   4. JSX 配置解析
//   5. ${configDir} 模板变量替换
package bao_resolver

import bao_core.*
import bao_collections.*

// ============================================================================
// TsConfig - tsconfig.json 解析结果
// 严格翻译自: src/resolver/tsconfig_json.zig TSConfigJSON
// ============================================================================

/// tsconfig.json 解析结果
/// 对应 Bun TSConfigJSON 结构体
public class TsConfig {
    /// 配置文件的绝对路径 - 对应 Bun abs_path
    public var absPath: String
    /// 继承的配置文件路径 - 对应 Bun extends
    public var extends: String
    /// compilerOptions.baseUrl - 对应 Bun base_url
    public var baseUrl: String
    /// 用于 paths 解析的 baseUrl (如果 paths 存在但 baseUrl 为空则为 ".")
    /// 对应 Bun base_url_for_paths
    public var baseUrlForPaths: String
    /// 路径映射 - 对应 Bun paths: PathsMap
    /// Bun: StringArrayHashMap([]string) - 键为模式，值为替换路径数组
    public var paths: HashMap<String, ArrayList<String>>
    /// 根目录 - 对应 Bun compilerOptions.rootDir
    public var rootDir: String
    /// 根目录列表 - 对应 Bun compilerOptions.rootDirs
    public var rootDirs: ArrayList<String>
    /// 输出目录 - 对应 Bun compilerOptions.outDir
    public var outDir: String
    /// JSX 配置
    public var jsx: JSXConfig
    /// 是否使用 define for class fields - 对应 Bun use_define_for_class_fields
    public var useDefineForClassFields: ?Bool
    /// 是否保留未使用的 import - 对应 Bun preserve_imports_not_used_as_values
    public var preserveImportsNotUsedAsValues: Bool
    /// 是否发射装饰器元数据 - 对应 Bun emit_decorator_metadata
    public var emitDecoratorMetadata: Bool
    /// 是否启用实验性装饰器 - 对应 Bun experimental_decorators
    public var experimentalDecorators: Bool
    /// 是否启用严格模式 - 对应 Bun compilerOptions.strict
    public var strict: Bool
    /// 目标 - 对应 Bun compilerOptions.target
    public var target: String
    /// 模块解析策略 - 对应 Bun compilerOptions.moduleResolution
    public var moduleResolution: String
    /// 模块后缀 - 对应 Bun compilerOptions.moduleSuffixes
    public var moduleSuffixes: ArrayList<String>
    /// 原始 JSON 文本
    public var rawJson: String

    public init() {
        absPath = ""
        extends = ""
        baseUrl = ""
        baseUrlForPaths = ""
        paths = HashMap<String, ArrayList<String>>()
        rootDir = ""
        rootDirs = ArrayList<String>()
        outDir = ""
        jsx = JSXConfig()
        useDefineForClassFields = None
        preserveImportsNotUsedAsValues = false
        emitDecoratorMetadata = false
        experimentalDecorators = false
        strict = false
        target = ""
        moduleResolution = ""
        moduleSuffixes = ArrayList<String>()
        rawJson = ""
    }

    /// 是否有 baseUrl - 对应 Bun TSConfigJSON.hasBaseURL()
    public func hasBaseUrl(): Bool {
        return baseUrl.length > 0
    }

    /// 合并 JSX 配置 - 对应 Bun TSConfigJSON.mergeJSX()
    /// 用于 extends 链中的配置合并
    public func mergeJSX(current: JSXConfig): JSXConfig {
        var out = current

        if (jsx.factoryWasSet) {
            out.factory = jsx.factory
            out.factoryWasSet = true
        }
        if (jsx.fragmentWasSet) {
            out.fragment = jsx.fragment
            out.fragmentWasSet = true
        }
        if (jsx.importSourceWasSet) {
            out.importSource = jsx.importSource
            out.importSourceWasSet = true
        }
        if (jsx.runtimeWasSet) {
            out.runtime = jsx.runtime
            out.runtimeWasSet = true
        }
        if (jsx.developmentWasSet) {
            out.development = jsx.development
            out.developmentWasSet = true
        }

        return out
    }
}

/// JSX 配置 - 对应 Bun options.JSX.Pragma
/// Bun:
///   pub const Pragma = struct {
///       factory: []string = &.{"React", "createElement"},
///       fragment: []string = &.{"React", "Fragment"},
///       runtime: Runtime = .classic,
///       import_source: string = "react",
///       package_name: string = "",
///       development: bool = false,
///   }
public class JSXConfig {
    /// 工厂函数 - 对应 Bun jsx.factory (如 ["React", "createElement"])
    public var factory: String
    /// Fragment 组件 - 对应 Bun jsx.fragment
    public var fragment: String
    /// 运行时 - 对应 Bun jsx.runtime
    public var runtime: JSXRuntimeType
    /// 导入源 - 对应 Bun jsx.import_source
    public var importSource: String
    /// 包名 - 对应 Bun jsx.package_name
    public var packageName: String
    /// 开发模式 - 对应 Bun jsx.development
    public var development: Bool

    // 标记哪些字段被显式设置 (用于 extends 合并)
    public var factoryWasSet: Bool
    public var fragmentWasSet: Bool
    public var runtimeWasSet: Bool
    public var importSourceWasSet: Bool
    public var developmentWasSet: Bool

    public init() {
        factory = "React.createElement"
        fragment = "React.Fragment"
        runtime = JSXRuntimeType.Classic
        importSource = "react"
        packageName = ""
        development = false
        factoryWasSet = false
        fragmentWasSet = false
        runtimeWasSet = false
        importSourceWasSet = false
        developmentWasSet = false
    }
}

/// JSX 运行时类型 - 对应 Bun options.JSX.Runtime
/// Bun: pub const Runtime = enum { classic, automatic, solid }
public enum JSXRuntimeType {
    | Classic       // React.createElement
    | Automatic     // jsx/jsxs from react/jsx-runtime
    | Solid         // Solid.js

    public static func fromString(s: String): ?JSXRuntimeType {
        let lower = s.toLowerCase()
        match (lower) {
            case "classic" => Some(JSXRuntimeType.Classic)
            case "automatic" => Some(JSXRuntimeType.Automatic)
            case "solid" => Some(JSXRuntimeType.Solid)
            case "preserve" => Some(JSXRuntimeType.Classic)  // preserve 映射为 classic
            case "react" => Some(JSXRuntimeType.Automatic)
            case "react-jsx" => Some(JSXRuntimeType.Automatic)
            case "react-jsxdev" => Some(JSXRuntimeType.Automatic)
            case "react-native" => Some(JSXRuntimeType.Classic)
            case _ => None
        }
    }
}

// ============================================================================
// TsConfigParser - tsconfig.json 解析器
// 严格翻译自: src/resolver/tsconfig_json.zig TSConfigJSON.parse()
// Bun 的 parse 函数约 300 行，解析所有 compilerOptions 字段
// ============================================================================

/// tsconfig.json 解析器 - 对应 Bun TSConfigJSON.parse()
public class TsConfigParser {
    private var source: String
    private var pos: Int64

    public init() {
        source = ""
        pos = 0
    }

    /// 解析 tsconfig.json 文本
    /// 对应 Bun TSConfigJSON.parse(allocator, log, source, json_cache)
    public func parse(text: String): TsConfig {
        source = text
        pos = 0
        let result = TsConfig()
        result.rawJson = text

        // tsconfig.json 实际不是严格的 JSON (允许注释和尾逗号)
        // Bun 使用特殊的 JSON 解析器处理 (json_cache.parseTSConfig)
        // 此处使用简化解析

        skipWhitespace()
        if (pos >= source.length || source[Int64(pos)] != Char('{')) {
            return result
        }
        pos += 1  // skip '{'

        // 解析顶层属性
        while (pos < source.length) {
            skipWhitespaceAndComments()
            if (pos >= source.length || source[Int64(pos)] == Char('}')) {
                break
            }

            let key = parseKey()
            skipWhitespaceAndComments()

            if (pos < source.length && source[Int64(pos)] == Char(':')) {
                pos += 1
            }
            skipWhitespaceAndComments()

            match (key) {
                case "extends" => {
                    result.extends = parseStringValue()
                }
                case "compilerOptions" => {
                    parseCompilerOptions(result)
                }
                case "include" | "exclude" | "files" => {
                    skipValue()
                }
                case "references" => {
                    skipValue()
                }
                case _ => {
                    skipValue()
                }
            }

            skipWhitespaceAndComments()
            if (pos < source.length && source[Int64(pos)] == Char(',')) {
                pos += 1
            }
        }

        // 设置 base_url_for_paths
        // 对应 Bun: result.base_url_for_paths = if (result.base_url.len > 0) result.base_url else "."
        if (result.paths.size > 0) {
            result.baseUrlForPaths = if (result.baseUrl.length > 0) { result.baseUrl } else { "." }
        }

        return result
    }

    // ========================================================================
    // compilerOptions 解析
    // 严格对应 Bun tsconfig_json.zig 中 compilerOptions 解析
    // ========================================================================

    /// 解析 compilerOptions 对象
    /// 对应 Bun TSConfigJSON.parse() 中 "compilerOptions" 分支
    private func parseCompilerOptions(result: TsConfig): Unit {
        skipWhitespaceAndComments()
        if (pos >= source.length || source[Int64(pos)] != Char('{')) {
            return
        }
        pos += 1  // skip '{'

        while (pos < source.length) {
            skipWhitespaceAndComments()
            if (pos >= source.length || source[Int64(pos)] == Char('}')) {
                pos += 1
                break
            }

            let key = parseKey()
            skipWhitespaceAndComments()
            if (pos < source.length && source[Int64(pos)] == Char(':')) {
                pos += 1
            }
            skipWhitespaceAndComments()

            // 根据 key 解析对应值
            // 严格对应 Bun 中的各字段解析逻辑
            match (key) {
                case "baseUrl" => {
                    result.baseUrl = parseStringValue()
                }
                case "rootDir" => {
                    result.rootDir = parseStringValue()
                }
                case "rootDirs" => {
                    result.rootDirs = parseStringArray()
                }
                case "outDir" => {
                    result.outDir = parseStringValue()
                }
                case "paths" => {
                    result.paths = parsePathsMap()
                }
                case "strict" => {
                    result.strict = parseBoolValue()
                }
                case "target" => {
                    result.target = parseStringValue()
                }
                case "moduleResolution" => {
                    result.moduleResolution = parseStringValue()
                }
                case "moduleSuffixes" => {
                    result.moduleSuffixes = parseStringArray()
                }
                case "jsx" => {
                    let jsxValue = parseStringValue()
                    match (JSXRuntimeType.fromString(jsxValue.toLowerCase())) {
                        case Some(runtime) => {
                            result.jsx.runtime = runtime
                            result.jsx.runtimeWasSet = true
                        }
                        case None => {}
                    }
                }
                case "jsxFactory" => {
                    result.jsx.factory = parseStringValue()
                    result.jsx.factoryWasSet = true
                }
                case "jsxFragmentFactory" => {
                    result.jsx.fragment = parseStringValue()
                    result.jsx.fragmentWasSet = true
                }
                case "jsxImportSource" => {
                    let source = parseStringValue()
                    result.jsx.importSource = source
                    result.jsx.importSourceWasSet = true
                    // 检测 Solid.js
                    if (source.startsWith("solid-js")) {
                        result.jsx.runtime = JSXRuntimeType.Solid
                        result.jsx.runtimeWasSet = true
                    }
                }
                case "useDefineForClassFields" => {
                    result.useDefineForClassFields = Some(parseBoolValue())
                }
                case "importsNotUsedAsValues" => {
                    let val = parseStringValue()
                    match (val) {
                        case "preserve" | "error" => {
                            result.preserveImportsNotUsedAsValues = true
                        }
                        case _ => {}
                    }
                }
                case "emitDecoratorMetadata" => {
                    result.emitDecoratorMetadata = parseBoolValue()
                }
                case "experimentalDecorators" => {
                    result.experimentalDecorators = parseBoolValue()
                }
                case "declaration" | "declarationDir" | "sourceMap" |
                     "inlineSourceMap" | "inlineSources" | "outFile" |
                     "declarationMap" | "esModuleInterop" | "allowSyntheticDefaultImports" |
                     "forceConsistentCasingInFileNames" | "skipLibCheck" |
                     "isolatedModules" | "verbatimModuleSyntax" | "resolveJsonModule" |
                     "allowJs" | "checkJs" | "noEmit" | "noEmitOnError" |
                     "removeComments" | "preserveConstEnums" | "stripInternal" => {
                    skipValue()
                }
                case _ => {
                    skipValue()
                }
            }

            skipWhitespaceAndComments()
            if (pos < source.length && source[Int64(pos)] == Char(',')) {
                pos += 1
            }
        }
    }

    // ========================================================================
    // paths 映射解析
    // 严格对应 Bun tsconfig_json.zig 中 "paths" 解析
    //
    // Bun:
    //   paths: PathsMap = bun.StringArrayHashMap([]string)
    //   每个 key 可以有零或一个 "*" 通配符
    //   每个 value 是替换路径的数组
    //
    // 示例:
    //   "paths": {
    //     "@foo/*": ["src/*", "generated/*"],
    //     "@bar/utils": ["src/utils/index"]
    //   }
    //
    // 验证:
    //   isValidTSConfigPathPattern - 检查最多一个 "*"
    //   isValidTSConfigPathNoBaseURLPattern - 检查路径模式有效性
    // ========================================================================

    /// 解析 paths 映射
    /// 对应 Bun 中 "paths" 字段解析
    private func parsePathsMap(): HashMap<String, ArrayList<String>> {
        let result = HashMap<String, ArrayList<String>>()
        skipWhitespaceAndComments()

        if (pos >= source.length || source[Int64(pos)] != Char('{')) {
            return result
        }
        pos += 1  // skip '{'

        while (pos < source.length) {
            skipWhitespaceAndComments()
            if (pos >= source.length || source[Int64(pos)] == Char('}')) {
                pos += 1
                break
            }

            let pattern = parseStringValue()
            skipWhitespaceAndComments()

            if (pos < source.length && source[Int64(pos)] == Char(':')) {
                pos += 1
            }
            skipWhitespaceAndComments()

            // 验证路径模式 - 对应 Bun isValidTSConfigPathPattern
            if (isValidPathPattern(pattern)) {
                // 解析替换路径数组
                let replacements = parseStringArray()
                if (replacements.size > 0) {
                    // 过滤无效的替换路径
                    let validReplacements = ArrayList<String>()
                    for (replacement in replacements) {
                        if (isValidPathPattern(replacement)) {
                            validReplacements.append(replacement)
                        }
                    }
                    if (validReplacements.size > 0) {
                        result.put(pattern, validReplacements)
                    }
                }
            } else {
                skipValue()
            }

            skipWhitespaceAndComments()
            if (pos < source.length && source[Int64(pos)] == Char(',')) {
                pos += 1
            }
        }

        return result
    }

    /// 验证路径模式 - 对应 Bun isValidTSConfigPathPattern()
    /// 检查模式中最多有一个 "*" 通配符
    private func isValidPathPattern(text: String): Bool {
        var foundAsterisk = false
        for (ch in text) {
            if (ch == Char('*')) {
                if (foundAsterisk) {
                    // 第二个 '*'，无效
                    return false
                }
                foundAsterisk = true
            }
        }
        return true
    }

    /// 验证没有 baseUrl 时的路径模式
    /// 对应 Bun isValidTSConfigPathNoBaseURLPattern()
    /// 当没有设置 baseUrl 时，路径必须是相对或绝对的
    private func isValidPathWithoutBaseUrl(text: String): Bool {
        if (text.length == 0) {
            return false
        }
        // 相对路径
        if (text.startsWith("./") || text.startsWith("../") ||
            text.startsWith(".\\") || text.startsWith("..\\")) {
            return true
        }
        // 单独的 "."
        if (text == "." || text == "..") {
            return true
        }
        // 绝对路径
        if (text.startsWith("/") || text.startsWith("\\")) {
            return true
        }
        return false
    }

    // ========================================================================
    // extends 链解析
    // 严格对应 Bun tsconfig_json.zig 中 extends 处理
    // 以及 resolver.zig 中 extends 合并逻辑
    //
    // Bun 处理 extends 链:
    //   1. 解析 extends 路径为绝对路径
    //   2. 加载被继承的 tsconfig.json
    //   3. 递归处理 (支持多层继承)
    //   4. 子配置覆盖父配置
    // ========================================================================

    /// 解析 extends 链并合并配置
    /// 对应 Bun resolver.zig 中 tsconfig extends 合并逻辑
    public func resolveExtends(config: TsConfig,
                                loadFile: (String) -> ?String): TsConfig {
        if (config.extends.length == 0) {
            return config
        }

        // 解析 extends 路径
        let extendsPath = resolveExtendsPath(config.extends, config.absPath)
        match (loadFile(extendsPath)) {
            case Some(content) => {
                let parentConfig = parse(content)
                parentConfig.absPath = extendsPath

                // 递归解析父配置的 extends
                let resolvedParent = resolveExtends(parentConfig, loadFile)

                // 合并: 子配置覆盖父配置
                return mergeConfigs(resolvedParent, config)
            }
            case None => {
                return config
            }
        }
    }

    /// 解析 extends 路径
    private func resolveExtendsPath(extends: String, fromDir: String): String {
        if (extends.startsWith("./") || extends.startsWith("../")) {
            return Path.join([fromDir, extends])
        }
        // 包路径: "tsconfig/base" -> node_modules/tsconfig/base.json
        return extends
    }

    /// 合并两个 tsconfig - 子配置覆盖父配置
    /// 对应 Bun resolver.zig 中 extends 合并逻辑
    private func mergeConfigs(parent: TsConfig, child: TsConfig): TsConfig {
        let result = TsConfig()
        result.absPath = child.absPath
        result.rawJson = child.rawJson

        // extends: 子配置的 extends 链已经解析
        result.extends = ""

        // baseUrl: 子配置优先
        result.baseUrl = if (child.baseUrl.length > 0) { child.baseUrl } else { parent.baseUrl }

        // paths: 合并 (子配置的 paths 添加到父配置上)
        result.paths = HashMap<String, ArrayList<String>>()
        let parentKeys = parent.paths.keys()
        for (key in parentKeys) {
            match (parent.paths.get(key)) {
                case Some(v) => result.paths.put(key, v)
                case None => {}
            }
        }
        let childKeys = child.paths.keys()
        for (key in childKeys) {
            match (child.paths.get(key)) {
                case Some(v) => result.paths.put(key, v)
                case None => {}
            }
        }

        // baseUrlForPaths
        if (result.paths.size > 0) {
            result.baseUrlForPaths = if (result.baseUrl.length > 0) { result.baseUrl } else { "." }
        }

        // 其他字段: 子配置优先
        result.rootDir = if (child.rootDir.length > 0) { child.rootDir } else { parent.rootDir }
        result.outDir = if (child.outDir.length > 0) { child.outDir } else { parent.outDir }
        result.strict = child.strict || parent.strict
        result.target = if (child.target.length > 0) { child.target } else { parent.target }
        result.moduleResolution = if (child.moduleResolution.length > 0) { child.moduleResolution } else { parent.moduleResolution }

        // JSX: 使用 mergeJSX 合并
        result.jsx = parent.mergeJSX(child.jsx)

        // 布尔字段: 子配置优先
        result.useDefineForClassFields = if (child.useDefineForClassFields != None) { child.useDefineForClassFields } else { parent.useDefineForClassFields }
        result.preserveImportsNotUsedAsValues = child.preserveImportsNotUsedAsValues || parent.preserveImportsNotUsedAsValues
        result.emitDecoratorMetadata = child.emitDecoratorMetadata || parent.emitDecoratorMetadata
        result.experimentalDecorators = child.experimentalDecorators || parent.experimentalDecorators

        return result
    }

    // ========================================================================
    // ${configDir} 模板变量替换
    // 严格对应 Bun tsconfig_json.zig 中 strReplacingTemplates()
    //
    // TypeScript 5.5 引入了 ${configDir} 模板变量:
    //   "outDir": "${configDir}/dist"
    // 被替换为 tsconfig.json 所在目录的绝对路径
    // ========================================================================

    /// 替换 ${configDir} 模板变量
    /// 对应 Bun strReplacingTemplates()
    public func replaceConfigDir(input: String, configDir: String): String {
        if (!input.contains("${configDir}")) {
            return input
        }
        return input.replace("${configDir}", configDir)
    }

    // ========================================================================
    // 成员表达式解析 (用于 JSX)
    // 严格对应 Bun parseMemberExpressionForJSX()
    //
    // "React.createElement" -> ["React", "createElement"]
    // "h" -> ["h"]
    // ========================================================================

    /// 解析 JSX 成员表达式
    /// 对应 Bun parseMemberExpressionForJSX()
    public func parseMemberExpression(text: String): ArrayList<String> {
        let parts = ArrayList<String>()
        if (text.length == 0) {
            return parts
        }

        let sb = StringBuilder()
        for (ch in text) {
            if (ch == Char('.')) {
                let part = sb.toString()
                if (part.length > 0 && isValidIdentifier(part)) {
                    parts.append(part)
                } else {
                    return ArrayList<String>()  // 无效
                }
                sb.clearBuffer()
            } else {
                sb.append(ch)
            }
        }

        let lastPart = sb.toString()
        if (lastPart.length > 0 && isValidIdentifier(lastPart)) {
            parts.append(lastPart)
        } else {
            return ArrayList<String>()
        }

        return parts
    }

    /// 检查是否为有效的 JavaScript 标识符
    private func isValidIdentifier(s: String): Bool {
        if (s.length == 0) {
            return false
        }
        let first = s[Int64(0)]
        let fv = first.value
        if (!((fv >= 97 && fv <= 122) || (fv >= 65 && fv <= 90) || fv == 95 || fv == 36)) {
            return false
        }
        for (ch in s) {
            let v = ch.value
            if (!((v >= 97 && v <= 122) || (v >= 65 && v <= 90) ||
                  (v >= 48 && v <= 57) || v == 95 || v == 36)) {
                return false
            }
        }
        return true
    }

    // ========================================================================
    // 基础解析工具
    // ========================================================================

    /// 解析 JSON key (支持引号和无引号 key，因为 tsconfig 允许尾逗号)
    private func parseKey(): String {
        skipWhitespaceAndComments()
        if (pos >= source.length) {
            return ""
        }
        // 尝试引号字符串
        if (source[Int64(pos)] == Char('"') || source[Int64(pos)] == Char('\'')) {
            return parseStringValue()
        }
        // 无引号 key (tsconfig 特殊语法)
        let sb = StringBuilder()
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char(':') || ch == Char('{') || ch == Char('}') ||
                ch == Char(',') || ch == Char(' ') || ch == Char('\t') ||
                ch == Char('\n') || ch == Char('\r')) {
                break
            }
            sb.append(ch)
            pos += 1
        }
        return sb.toString().trim()
    }

    /// 解析字符串值
    private func parseStringValue(): String {
        skipWhitespaceAndComments()
        if (pos >= source.length) {
            return ""
        }
        let ch = source[Int64(pos)]
        if (ch != Char('"') && ch != Char('\'')) {
            return ""
        }
        let quote = ch
        pos += 1

        let sb = StringBuilder()
        while (pos < source.length) {
            let c = source[Int64(pos)]
            if (c == Char('\\') && pos + 1 < source.length) {
                pos += 1
                let escaped = source[Int64(pos)]
                match (escaped.value) {
                    case 34 => sb.append(Char(34))
                    case 92 => sb.append(Char(92))
                    case 47 => sb.append(Char(47))
                    case 98 => sb.append(Char(8))
                    case 102 => sb.append(Char(12))
                    case 110 => sb.append(Char(10))
                    case 114 => sb.append(Char(13))
                    case 116 => sb.append(Char(9))
                    case _ => sb.append(escaped)
                }
                pos += 1
            } else if (c == quote) {
                pos += 1
                break
            } else {
                sb.append(c)
                pos += 1
            }
        }
        return sb.toString()
    }

    /// 解析布尔值
    private func parseBoolValue(): Bool {
        skipWhitespaceAndComments()
        if (pos >= source.length) {
            return false
        }
        if (source[Int64(pos)] == Char('t')) {
            pos += 4  // skip "true"
            return true
        }
        if (source[Int64(pos)] == Char('f')) {
            pos += 5  // skip "false"
            return false
        }
        skipValue()
        return false
    }

    /// 解析字符串数组
    private func parseStringArray(): ArrayList<String> {
        let result = ArrayList<String>()
        skipWhitespaceAndComments()
        if (pos >= source.length || source[Int64(pos)] != Char('[')) {
            return result
        }
        pos += 1  // skip '['

        while (pos < source.length) {
            skipWhitespaceAndComments()
            if (pos >= source.length || source[Int64(pos)] == Char(']')) {
                pos += 1
                break
            }
            let str = parseStringValue()
            if (str.length > 0) {
                result.append(str)
            }
            skipWhitespaceAndComments()
            if (pos < source.length && source[Int64(pos)] == Char(',')) {
                pos += 1
            }
        }

        return result
    }

    /// 跳过值
    private func skipValue(): Unit {
        if (pos >= source.length) {
            return
        }
        let ch = source[Int64(pos)]
        if (ch == Char('"') || ch == Char('\'')) {
            pos += 1
            while (pos < source.length) {
                if (source[Int64(pos)] == Char('\\') && pos + 1 < source.length) {
                    pos += 2
                } else if (source[Int64(pos)] == ch) {
                    pos += 1
                    break
                } else {
                    pos += 1
                }
            }
        } else if (ch == Char('{')) {
            var depth = 1
            pos += 1
            while (pos < source.length && depth > 0) {
                if (source[Int64(pos)] == Char('{')) { depth += 1 }
                else if (source[Int64(pos)] == Char('}')) { depth -= 1 }
                pos += 1
            }
        } else if (ch == Char('[')) {
            var depth = 1
            pos += 1
            while (pos < source.length && depth > 0) {
                if (source[Int64(pos)] == Char('[')) { depth += 1 }
                else if (source[Int64(pos)] == Char(']')) { depth -= 1 }
                pos += 1
            }
        } else {
            while (pos < source.length) {
                let c = source[Int64(pos)]
                if (c == Char(',') || c == Char('}') || c == Char(']') || c == Char('\n')) {
                    break
                }
                pos += 1
            }
        }
    }

    /// 跳过空白和注释 (tsconfig 支持 // 和 /* */ 注释)
    private func skipWhitespaceAndComments(): Unit {
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char(' ') || ch == Char('\t') || ch == Char('\n') || ch == Char('\r')) {
                pos += 1
            } else if (ch == Char('/') && pos + 1 < source.length) {
                let next = source[Int64(pos + 1)]
                if (next == Char('/')) {
                    // 行注释
                    pos += 2
                    while (pos < source.length && source[Int64(pos)] != Char('\n')) {
                        pos += 1
                    }
                } else if (next == Char('*')) {
                    // 块注释
                    pos += 2
                    while (pos + 1 < source.length) {
                        if (source[Int64(pos)] == Char('*') && source[Int64(pos + 1)] == Char('/')) {
                            pos += 2
                            break
                        }
                        pos += 1
                    }
                } else {
                    break
                }
            } else {
                break
            }
        }
    }

    private func skipWhitespace(): Unit {
        while (pos < source.length) {
            let ch = source[Int64(pos)]
            if (ch == Char(' ') || ch == Char('\t') || ch == Char('\n') || ch == Char('\r')) {
                pos += 1
            } else {
                break
            }
        }
    }
}
