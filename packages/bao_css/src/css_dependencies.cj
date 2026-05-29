// bao_css - CSS Dependencies (CSS 依赖分析)
// 严格翻译自: bun/src/css/dependencies.zig
//   对应: Dependency union - 依赖类型 (@import, url())
//   对应: ImportDependency - @import 依赖
//   对应: UrlDependency - url() 依赖
//   对应: DependencyOptions - 依赖分析选项
//   对应: SourceRange - 源码位置范围
//   对应: Location - 行列位置
package bao_css

import bao_core.*
import bao_collections.*
import bao_hash.*

// ============================================================================
// 依赖分析选项
// 严格翻译自: dependencies.zig DependencyOptions
// ============================================================================

/// 依赖分析选项
/// 严格翻译自 DependencyOptions struct
public class CssDependencyOptions {
    /// 是否移除 @import 规则
    public var removeImports: Bool

    public init() {
        this.removeImports = false
    }

    public static func default(): CssDependencyOptions {
        CssDependencyOptions()
    }
}

// ============================================================================
// 依赖类型
// 严格翻译自: dependencies.zig Dependency union
// ============================================================================

/// 依赖类型
public enum CssDependencyKind {
    | Import  // @import 依赖
    | Url     // url() 依赖
}

// ============================================================================
// 源码位置
// 严格翻译自: dependencies.zig Location, SourceRange
// ============================================================================

/// 源码中的行列位置
/// 严格翻译自 Location struct
public class CssLocation {
    /// 行号 (1-based)
    public var line: Int64
    /// 列号 (1-based)
    public var column: Int64

    public init() {
        this.line = 1
        this.column = 1
    }

    public init(line: Int64, column: Int64) {
        this.line = line
        this.column = column
    }

    public func toString(): String {
        "${line}:${column}"
    }
}

/// 源码位置范围
/// 严格翻译自 SourceRange struct
public class CssSourceRange {
    /// 文件路径
    public var filePath: String
    /// 起始位置
    public var start: CssLocation
    /// 结束位置
    public var end: CssLocation

    public init() {
        this.filePath = ""
        this.start = CssLocation()
        this.end = CssLocation()
    }

    public init(filePath: String, start: CssLocation, end: CssLocation) {
        this.filePath = filePath
        this.start = start
        this.end = end
    }

    /// 从位置、偏移和长度创建范围
    /// 严格翻译自 SourceRange.new
    public static func from(filePath: String, loc: CssLocation, offset: Int64, len: Int64): CssSourceRange {
        CssSourceRange(
            filePath,
            CssLocation(loc.line, loc.column + offset),
            CssLocation(loc.line, loc.column + offset + len - 1)
        )
    }

    public func toString(): String {
        "${filePath}:${start.toString()}-${end.toString()}"
    }
}

// ============================================================================
// 依赖
// 严格翻译自: dependencies.zig ImportDependency, UrlDependency, Dependency
// ============================================================================

/// @import 依赖
/// 严格翻译自 ImportDependency struct
public class CssImportDependency {
    /// 导入 URL
    public var url: String
    /// 占位符 (替换后的 hash)
    public var placeholder: String
    /// 可选 supports() 条件
    public var supports: ?String
    /// 媒体查询
    public var media: ?String
    /// 源码位置
    public var loc: CssSourceRange

    public init(url: String, placeholder: String) {
        this.url = url
        this.placeholder = placeholder
        this.supports = None
        this.media = None
        this.loc = CssSourceRange()
    }

    public func toString(): String {
        "@import \"${url}\""
    }
}

/// url() 依赖
/// 严格翻译自 UrlDependency struct
public class CssUrlDependency {
    /// URL
    public var url: String
    /// 占位符
    public var placeholder: String
    /// 源码位置
    public var loc: CssSourceRange

    public init(url: String, placeholder: String) {
        this.url = url
        this.placeholder = placeholder
        this.loc = CssSourceRange()
    }

    public func toString(): String {
        "url(${url})"
    }
}

/// CSS 依赖
/// 严格翻译自 Dependency union
public class CssDependency {
    /// 依赖类型
    public var kind: CssDependencyKind
    /// @import 依赖
    public var importDep: ?CssImportDependency
    /// url() 依赖
    public var urlDep: ?CssUrlDependency

    public init(importDep: CssImportDependency) {
        this.kind = CssDependencyKind.Import
        this.importDep = Some(importDep)
        this.urlDep = None
    }

    public init(urlDep: CssUrlDependency) {
        this.kind = CssDependencyKind.Url
        this.importDep = None
        this.urlDep = Some(urlDep)
    }

    /// 获取依赖 URL
    public func getUrl(): String {
        match (kind) {
            case CssDependencyKind.Import =>
                match (importDep) {
                    case Some(dep) => dep.url
                    case None => ""
                }
            case CssDependencyKind.Url =>
                match (urlDep) {
                    case Some(dep) => dep.url
                    case None => ""
                }
        }
    }

    /// 获取占位符
    public func getPlaceholder(): String {
        match (kind) {
            case CssDependencyKind.Import =>
                match (importDep) {
                    case Some(dep) => dep.placeholder
                    case None => ""
                }
            case CssDependencyKind.Url =>
                match (urlDep) {
                    case Some(dep) => dep.placeholder
                    case None => ""
                }
        }
    }

    public func toString(): String {
        getUrl()
    }
}

// ============================================================================
// 依赖分析器
// 严格翻译自: dependencies.zig 中的分析逻辑
// ============================================================================

/// CSS 依赖分析器
/// 从 CSS AST 中提取 @import 和 url() 依赖
public class CssDependencyAnalyzer {
    /// 分析规则列表中的依赖
    /// 严格翻译自: analyze_dependencies 逻辑
    public static func analyze(rules: CssRuleList, filePath: String): ArrayList<CssDependency> {
        let dependencies = ArrayList<CssDependency>()
        analyzeRules(rules, filePath, dependencies)
        return dependencies
    }

    /// 递归分析规则列表
    private static func analyzeRules(rules: CssRuleList, filePath: String, dependencies: ArrayList<CssDependency>): Unit {
        for (rule in rules.rules) {
            analyzeRule(rule, filePath, dependencies)
        }
    }

    /// 分析单个规则
    private static func analyzeRule(rule: CssRule, filePath: String, dependencies: ArrayList<CssDependency>): Unit {
        match (rule.kind) {
            case CssRuleKind.Import =>
                match (rule.importRule) {
                    case Some(importRule) =>
                        let placeholder = computePlaceholder(filePath, importRule.url)
                        let dep = CssImportDependency(importRule.url, placeholder)
                        dep.loc = CssSourceRange.from(
                            filePath,
                            CssLocation(
                                match (rule.position) {
                                    case Some(pos) => pos.line
                                    case None => 1
                                },
                                match (rule.position) {
                                    case Some(pos) => pos.column
                                    case None => 1
                                }
                            ),
                            8,
                            Int64(importRule.url.size) + 2
                        )
                        dependencies.append(CssDependency(dep))
                    case None => ()
                }
            case CssRuleKind.Style =>
                match (rule.styleRule) {
                    case Some(styleRule) =>
                        // 分析声明中的 url()
                        analyzeDeclarations(styleRule.declarations, filePath, dependencies)
                        // 分析嵌套规则
                        for (nestedRule in styleRule.rules) {
                            analyzeRule(nestedRule, filePath, dependencies)
                        }
                    case None => ()
                }
            case CssRuleKind.Media =>
                match (rule.mediaRule) {
                    case Some(mediaRule) =>
                        analyzeRules(mediaRule.rules, filePath, dependencies)
                    case None => ()
                }
            case CssRuleKind.Supports =>
                match (rule.supportsRule) {
                    case Some(supportsRule) =>
                        analyzeRules(supportsRule.rules, filePath, dependencies)
                    case None => ()
                }
            case CssRuleKind.LayerBlock =>
                match (rule.layerBlockRule) {
                    case Some(layerRule) =>
                        analyzeRules(layerRule.rules, filePath, dependencies)
                    case None => ()
                }
            case CssRuleKind.Container =>
                match (rule.containerRule) {
                    case Some(containerRule) =>
                        analyzeRules(containerRule.rules, filePath, dependencies)
                    case None => ()
                }
            case CssRuleKind.Keyframes =>
                match (rule.keyframesRule) {
                    case Some(kfRule) =>
                        for (block in kfRule.keyframes) {
                            analyzeDeclarations(block.declarations, filePath, dependencies)
                        }
                    case None => ()
                }
            case CssRuleKind.FontFace =>
                match (rule.fontFaceRule) {
                    case Some(ffRule) =>
                        analyzeDeclarations(ffRule.declarations, filePath, dependencies)
                    case None => ()
                }
            case _ => ()
        }
    }

    /// 分析声明块中的 url() 依赖
    private static func analyzeDeclarations(block: CssDeclarationBlock, filePath: String, dependencies: ArrayList<CssDependency>): Unit {
        for (decl in block.declarations) {
            analyzeValueUrls(decl.value, filePath, dependencies)
        }
        for (decl in block.importantDeclarations) {
            analyzeValueUrls(decl.value, filePath, dependencies)
        }
    }

    /// 从 CSS 值中提取 url() 引用
    private static func analyzeValueUrls(value: String, filePath: String, dependencies: ArrayList<CssDependency>): Unit {
        // 查找所有 url(...) 模式
        let urlPrefix = "url("
        var i: Int64 = 0
        while (i <= value.size - urlPrefix.size) {
            // 检查是否匹配 "url("
            var matched = true
            for (j in 0..urlPrefix.size) {
                if (value[i + j] != urlPrefix[j]) {
                    matched = false
                    break
                }
            }
            if (matched) {
                let urlStart = i + urlPrefix.size
                // 跳过空白
                var pos = urlStart
                while (pos < value.size && (value[pos] == UInt8(32) || value[pos] == UInt8(9))) {
                    pos++
                }
                // 读取 URL 内容
                let sb = StringBuilder()
                if (pos < value.size && (value[pos] == UInt8(34) || value[pos] == UInt8(39))) {
                    // 带引号的 URL
                    let `quote` = value[pos]
                    pos++
                    while (pos < value.size && value[pos] != `quote`) {
                        if (value[pos] == UInt8(92) && pos + 1 < value.size) {
                            pos++
                            sb.append(value[pos])
                        } else {
                            sb.append(value[pos])
                        }
                        pos++
                    }
                    // 跳过关闭引号和右括号
                    pos++ // close quote
                    while (pos < value.size && value[pos] != UInt8(41)) { pos++ }
                } else {
                    // 不带引号的 URL
                    while (pos < value.size && value[pos] != UInt8(41)) {
                        if (value[pos] == UInt8(92) && pos + 1 < value.size) {
                            pos++
                            sb.append(value[pos])
                        } else if (value[pos] == UInt8(32) || value[pos] == UInt8(9)) {
                            break
                        } else {
                            sb.append(value[pos])
                        }
                        pos++
                    }
                }
                let urlContent = sb.toString()
                if (urlContent.size > 0) {
                    let placeholder = computePlaceholder(filePath, urlContent)
                    let urlDep = CssUrlDependency(urlContent, placeholder)
                    dependencies.append(CssDependency(urlDep))
                }
                i = pos + 1
            } else {
                i++
            }
        }
    }

    /// 计算占位符
    /// 严格翻译自 css_modules.hash
    private static func computePlaceholder(filePath: String, url: String): String {
        // 使用文件路径和 URL 生成确定性占位符
        let combined = "${filePath}_${url}"
        let h = Wyhash11.hash(combined)
        let hexChars = "0123456789abcdef"
        let sb = StringBuilder()
        var value = h
        var i: Int64 = 0
        while (i < 8) {
            let nibble = Int64(value & 0xF)
            sb.append(hexChars[nibble])
            value = value >> 4
            i++
        }
        return sb.toString()
    }

    /// 替换依赖占位符
    /// 将 CSS 中的占位符替换为实际 URL
    public static func replacePlaceholders(css: String, replacements: HashMap<String, String>): String {
        var result = css
        // 遍历所有替换映射, 将占位符替换为实际值
        for (placeholder in replacements.keys()) {
            result = result.replace(placeholder, replacements[placeholder].getOrThrow())
        }
        result
    }
}
