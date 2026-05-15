// bao_css - CSS Rule (CSS 规则类型)
// 严格翻译自: bun/src/css/rules/
//   对应: rules/rules.zig - CssRule union, CssRuleList
//   对应: rules/style.zig - StyleRule
//   对应: rules/import.zig - ImportRule
//   对应: rules/media.zig - MediaRule
//   对应: rules/keyframes.zig - KeyframesRule
//   对应: rules/font_face.zig - FontFaceRule
//   对应: rules/supports.zig - SupportsRule
//   对应: rules/layer.zig - LayerStatementRule, LayerBlockRule
//   对应: rules/container.zig - ContainerRule
//   对应: rules/namespace.zig - NamespaceRule
//   对应: rules/unknown.zig - UnknownAtRule
package bao_css

import bao_core.*
import bao_collections.*

// ============================================================================
// CSS 规则类型
// 严格翻译自: rules/rules.zig CssRule union(enum)
// ============================================================================

/// CSS 规则类型标签
public enum CssRuleKind {
    | Media
    | Import
    | Style
    | Keyframes
    | FontFace
    | FontPaletteValues
    | Page
    | Supports
    | CounterStyle
    | Namespace
    | MozDocument
    | Nesting
    | Viewport
    | CustomMedia
    | LayerStatement
    | LayerBlock
    | Property
    | Container
    | Scope
    | StartingStyle
    | Ignored
    | Unknown
}

// ============================================================================
// CSS 规则 - 统一规则容器
// 严格翻译自: CssRule union
// ============================================================================

/// CSS 规则
/// 统一表示所有 CSS 规则类型
/// 严格对应 Bun CssRule union
public class CssRule {
    /// 规则类型
    public var kind: CssRuleKind
    /// 样式规则
    public var styleRule: ?CssStyleRule
    /// @media 规则
    public var mediaRule: ?CssAtMediaRule
    /// @import 规则
    public var importRule: ?CssAtImportRule
    /// @keyframes 规则
    public var keyframesRule: ?CssAtKeyframesRule
    /// @font-face 规则
    public var fontFaceRule: ?CssAtFontFaceRule
    /// @supports 规则
    public var supportsRule: ?CssAtSupportsRule
    /// @layer 声明规则
    public var layerStatementRule: ?CssAtLayerStatementRule
    /// @layer 块规则
    public var layerBlockRule: ?CssAtLayerBlockRule
    /// @container 规则
    public var containerRule: ?CssAtContainerRule
    /// @namespace 规则
    public var namespaceRule: ?CssAtNamespaceRule
    /// @property 规则
    public var propertyRule: ?CssAtPropertyRule
    /// 未知 @规则
    public var unknownRule: ?CssUnknownAtRule
    /// 位置信息
    public var position: ?CssTokenPosition

    private init(kind: CssRuleKind) {
        this.kind = kind
        this.styleRule = None
        this.mediaRule = None
        this.importRule = None
        this.keyframesRule = None
        this.fontFaceRule = None
        this.supportsRule = None
        this.layerStatementRule = None
        this.layerBlockRule = None
        this.containerRule = None
        this.namespaceRule = None
        this.propertyRule = None
        this.unknownRule = None
        this.position = None
    }

    // 工厂方法
    public static func createStyle(rule: CssStyleRule): CssRule {
        let r = CssRule(CssRuleKind.Style)
        r.styleRule = Some(rule)
        return r
    }

    public static func createMedia(rule: CssAtMediaRule): CssRule {
        let r = CssRule(CssRuleKind.Media)
        r.mediaRule = Some(rule)
        return r
    }

    public static func createImport(rule: CssAtImportRule): CssRule {
        let r = CssRule(CssRuleKind.Import)
        r.importRule = Some(rule)
        return r
    }

    public static func createKeyframes(rule: CssAtKeyframesRule): CssRule {
        let r = CssRule(CssRuleKind.Keyframes)
        r.keyframesRule = Some(rule)
        return r
    }

    public static func createFontFace(rule: CssAtFontFaceRule): CssRule {
        let r = CssRule(CssRuleKind.FontFace)
        r.fontFaceRule = Some(rule)
        return r
    }

    public static func createSupports(rule: CssAtSupportsRule): CssRule {
        let r = CssRule(CssRuleKind.Supports)
        r.supportsRule = Some(rule)
        return r
    }

    public static func createLayerStatement(rule: CssAtLayerStatementRule): CssRule {
        let r = CssRule(CssRuleKind.LayerStatement)
        r.layerStatementRule = Some(rule)
        return r
    }

    public static func createLayerBlock(rule: CssAtLayerBlockRule): CssRule {
        let r = CssRule(CssRuleKind.LayerBlock)
        r.layerBlockRule = Some(rule)
        return r
    }

    public static func createContainer(rule: CssAtContainerRule): CssRule {
        let r = CssRule(CssRuleKind.Container)
        r.containerRule = Some(rule)
        return r
    }

    public static func createNamespace(rule: CssAtNamespaceRule): CssRule {
        let r = CssRule(CssRuleKind.Namespace)
        r.namespaceRule = Some(rule)
        return r
    }

    public static func createProperty(rule: CssAtPropertyRule): CssRule {
        let r = CssRule(CssRuleKind.Property)
        r.propertyRule = Some(rule)
        return r
    }

    public static func createUnknown(rule: CssUnknownAtRule): CssRule {
        let r = CssRule(CssRuleKind.Unknown)
        r.unknownRule = Some(rule)
        return r
    }

    public static func createIgnored(): CssRule {
        CssRule(CssRuleKind.Ignored)
    }

    /// 转为 CSS 文本
    public func toCss(indent: String): String {
        match (kind) {
            case CssRuleKind.Style =>
                match (styleRule) {
                    case Some(r) => r.toCss(indent)
                    case None => ""
                }
            case CssRuleKind.Media =>
                match (mediaRule) {
                    case Some(r) => r.toCss(indent)
                    case None => ""
                }
            case CssRuleKind.Import =>
                match (importRule) {
                    case Some(r) => r.toCss()
                    case None => ""
                }
            case CssRuleKind.Keyframes =>
                match (keyframesRule) {
                    case Some(r) => r.toCss(indent)
                    case None => ""
                }
            case CssRuleKind.FontFace =>
                match (fontFaceRule) {
                    case Some(r) => r.toCss(indent)
                    case None => ""
                }
            case CssRuleKind.Supports =>
                match (supportsRule) {
                    case Some(r) => r.toCss(indent)
                    case None => ""
                }
            case CssRuleKind.LayerStatement =>
                match (layerStatementRule) {
                    case Some(r) => r.toCss()
                    case None => ""
                }
            case CssRuleKind.LayerBlock =>
                match (layerBlockRule) {
                    case Some(r) => r.toCss(indent)
                    case None => ""
                }
            case CssRuleKind.Container =>
                match (containerRule) {
                    case Some(r) => r.toCss(indent)
                    case None => ""
                }
            case CssRuleKind.Namespace =>
                match (namespaceRule) {
                    case Some(r) => r.toCss()
                    case None => ""
                }
            case CssRuleKind.Property =>
                match (propertyRule) {
                    case Some(r) => r.toCss(indent)
                    case None => ""
                }
            case CssRuleKind.Unknown =>
                match (unknownRule) {
                    case Some(r) => r.toCss(indent)
                    case None => ""
                }
            case CssRuleKind.Ignored => ""
            case _ => ""
        }
    }

    /// 转为字符串
    public func toString(): String {
        toCss("")
    }
}

// ============================================================================
// 规则列表
// 严格翻译自: rules/rules.zig CssRuleList
// ============================================================================

/// CSS 规则列表
/// 严格翻译自 CssRuleList
public class CssRuleList {
    /// 规则数组
    public var rules: ArrayList<CssRule>

    public init() {
        this.rules = ArrayList<CssRule>()
    }

    public init(rules: ArrayList<CssRule>) {
        this.rules = rules
    }

    public func length(): Int64 {
        rules.size
    }

    public func isEmpty(): Bool {
        rules.size == 0
    }

    public func append(rule: CssRule): Unit {
        rules.append(rule)
    }

    /// 转为 CSS 文本
    public func toCss(indent: String): String {
        let sb = StringBuilder()
        for (rule in rules) {
            let css = rule.toCss(indent)
            if (css.length > 0) {
                sb.append("${indent}${css}\n")
            }
        }
        return sb.toString()
    }

    public func toString(): String {
        toCss("")
    }
}

// ============================================================================
// 样式规则
// 严格翻译自: rules/style.zig StyleRule
// ============================================================================

/// CSS 样式规则
/// 严格翻译自 StyleRule
public class CssStyleRule {
    /// 选择器列表
    public var selectors: CssSelectorList
    /// 声明块
    public var declarations: CssDeclarationBlock
    /// 嵌套规则
    public var rules: ArrayList<CssRule>
    /// 供应商前缀
    public var vendorPrefix: VendorPrefix
    /// 位置信息
    public var position: ?CssTokenPosition

    public init(selectors: CssSelectorList, declarations: CssDeclarationBlock, rules: ArrayList<CssRule>) {
        this.selectors = selectors
        this.declarations = declarations
        this.rules = rules
        this.vendorPrefix = VendorPrefix()
        this.position = None
    }

    /// 是否为空规则
    /// 严格翻译自 StyleRule.isEmpty
    public func isEmpty(): Bool {
        selectors.isEmpty() || (declarations.isEmpty() && rules.size == 0)
    }

    /// 返回规则哈希键 (选择器 + 属性)
    /// 严格翻译自 StyleRule.hashKey
    public func hashKey(): Int64 {
        let hasher = Wyhash()
        hasher.update(selectors.toString())
        declarations.hashPropertyIds(hasher)
        return hasher.finalize()
    }

    /// 判断是否为重复规则 (相同选择器 + 相同属性)
    /// 严格翻译自 StyleRule.isDuplicate
    public func isDuplicate(other: CssStyleRule): Bool {
        declarations.len() == other.declarations.len() &&
        selectors.toString() == other.selectors.toString()
    }

    /// 深拷贝
    /// 严格翻译自 StyleRule.deepClone
    public func deepClone(): CssStyleRule {
        let rule = CssStyleRule(selectors, declarations.deepClone(), ArrayList<CssRule>())
        rule.vendorPrefix = vendorPrefix
        rule.position = position
        return rule
    }

    /// 转为 CSS 文本
    public func toCss(indent: String): String {
        if (isEmpty()) { return "" }

        let sb = StringBuilder()
        sb.append("${indent}${selectors.toString()}")
        sb.append(declarations.toCssBlock(indent))

        // 嵌套规则
        if (rules.size > 0) {
            for (rule in rules) {
                let nestedCss = rule.toCss(indent + "  ")
                if (nestedCss.length > 0) {
                    sb.append("\n${indent}  ${nestedCss}")
                }
            }
        }

        return sb.toString()
    }
}

// ============================================================================
// @media 规则
// 严格翻译自: rules/media.zig MediaRule
// ============================================================================

/// CSS @media 规则
public class CssAtMediaRule {
    /// 媒体查询文本
    public var query: String
    /// 子规则列表
    public var rules: CssRuleList
    /// 位置信息
    public var position: ?CssTokenPosition

    public init(query: String, rules: CssRuleList) {
        this.query = query
        this.rules = rules
        this.position = None
    }

    public func toCss(indent: String): String {
        let sb = StringBuilder()
        sb.append("@media ${query} {\n")
        for (rule in rules.rules) {
            let css = rule.toCss(indent + "  ")
            if (css.length > 0) {
                sb.append("${indent}  ${css}\n")
            }
        }
        sb.append("${indent}}")
        return sb.toString()
    }
}

// ============================================================================
// @import 规则
// 严格翻译自: rules/import.zig ImportRule
// ============================================================================

/// CSS @import 规则
public class CssAtImportRule {
    /// 导入 URL
    public var url: String
    /// 条件 (media query, layer, supports)
    public var conditions: String
    /// 位置信息
    public var position: ?CssTokenPosition

    public init(url: String, conditions: String) {
        this.url = url
        this.conditions = conditions
        this.position = None
    }

    public func toCss(): String {
        if (conditions.length > 0) {
            return "@import \"${url}\" ${conditions};"
        }
        return "@import \"${url}\";"
    }
}

// ============================================================================
// @keyframes 规则
// 严格翻译自: rules/keyframes.zig KeyframesRule
// ============================================================================

/// 关键帧块 (from/to/百分比)
public class CssKeyframeBlock {
    /// 选择器列表 (from, to, 0%, 100%, ...)
    public var selectors: ArrayList<String>
    /// 声明块
    public var declarations: CssDeclarationBlock

    public init(selectors: ArrayList<String>, declarations: CssDeclarationBlock) {
        this.selectors = selectors
        this.declarations = declarations
    }

    public func toCss(indent: String): String {
        let selectorStr = String.join(", ", selectors)
        let sb = StringBuilder()
        sb.append("${indent}${selectorStr} {\n")
        for (decl in declarations.declarations) {
            sb.append("${indent}  ${decl.toString()};\n")
        }
        for (decl in declarations.importantDeclarations) {
            sb.append("${indent}  ${decl.toString()};\n")
        }
        sb.append("${indent}}")
        return sb.toString()
    }
}

/// CSS @keyframes 规则
public class CssAtKeyframesRule {
    /// 规则名 (@-webkit-keyframes, @keyframes, ...)
    public var name: String
    /// 动画名
    public var animationName: String
    /// 关键帧块列表
    public var keyframes: ArrayList<CssKeyframeBlock>
    /// 供应商前缀
    public var vendorPrefix: VendorPrefix
    /// 位置信息
    public var position: ?CssTokenPosition

    public init(name: String, animationName: String, keyframes: ArrayList<CssKeyframeBlock>) {
        this.name = name
        this.animationName = animationName
        this.keyframes = keyframes
        this.vendorPrefix = VendorPrefix()
        this.position = None
    }

    public func toCss(indent: String): String {
        let sb = StringBuilder()
        sb.append("${indent}@${name} ${animationName} {\n")
        for (block in keyframes) {
            sb.append(block.toCss(indent + "  "))
            sb.append("\n")
        }
        sb.append("${indent}}")
        return sb.toString()
    }
}

// ============================================================================
// @font-face 规则
// ============================================================================

/// CSS @font-face 规则
public class CssAtFontFaceRule {
    /// 声明块
    public var declarations: CssDeclarationBlock
    /// 位置信息
    public var position: ?CssTokenPosition

    public init(declarations: CssDeclarationBlock) {
        this.declarations = declarations
        this.position = None
    }

    public func toCss(indent: String): String {
        let sb = StringBuilder()
        sb.append("${indent}@font-face")
        sb.append(declarations.toCssBlock(indent))
        return sb.toString()
    }
}

// ============================================================================
// @supports 规则
// ============================================================================

/// CSS @supports 规则
public class CssAtSupportsRule {
    /// 条件文本
    public var condition: String
    /// 子规则列表
    public var rules: CssRuleList
    /// 位置信息
    public var position: ?CssTokenPosition

    public init(condition: String, rules: CssRuleList) {
        this.condition = condition
        this.rules = rules
        this.position = None
    }

    public func toCss(indent: String): String {
        let sb = StringBuilder()
        sb.append("${indent}@supports ${condition} {\n")
        for (rule in rules.rules) {
            let css = rule.toCss(indent + "  ")
            if (css.length > 0) {
                sb.append("${indent}  ${css}\n")
            }
        }
        sb.append("${indent}}")
        return sb.toString()
    }
}

// ============================================================================
// @layer 规则
// 严格翻译自: rules/layer.zig LayerStatementRule, LayerBlockRule
// ============================================================================

/// CSS @layer 声明规则
public class CssAtLayerStatementRule {
    /// layer 名称列表
    public var names: String
    /// 位置信息
    public var position: ?CssTokenPosition

    public init(names: String) {
        this.names = names
        this.position = None
    }

    public func toCss(): String {
        if (names.length > 0) {
            return "@layer ${names};"
        }
        return "@layer;"
    }
}

/// CSS @layer 块规则
public class CssAtLayerBlockRule {
    /// layer 名称 (空为匿名 layer)
    public var name: String
    /// 子规则列表
    public var rules: CssRuleList
    /// 位置信息
    public var position: ?CssTokenPosition

    public init(name: String, rules: CssRuleList) {
        this.name = name
        this.rules = rules
        this.position = None
    }

    public func toCss(indent: String): String {
        let sb = StringBuilder()
        if (name.length > 0) {
            sb.append("${indent}@layer ${name} {\n")
        } else {
            sb.append("${indent}@layer {\n")
        }
        for (rule in rules.rules) {
            let css = rule.toCss(indent + "  ")
            if (css.length > 0) {
                sb.append("${indent}  ${css}\n")
            }
        }
        sb.append("${indent}}")
        return sb.toString()
    }
}

// ============================================================================
// @container 规则
// ============================================================================

/// CSS @container 规则
public class CssAtContainerRule {
    /// container 名称
    public var name: String
    /// 条件文本
    public var condition: String
    /// 子规则列表
    public var rules: CssRuleList
    /// 位置信息
    public var position: ?CssTokenPosition

    public init(name: String, condition: String, rules: CssRuleList) {
        this.name = name
        this.condition = condition
        this.rules = rules
        this.position = None
    }

    public func toCss(indent: String): String {
        let sb = StringBuilder()
        if (name.length > 0) {
            sb.append("${indent}@container ${name} ${condition} {\n")
        } else {
            sb.append("${indent}@container ${condition} {\n")
        }
        for (rule in rules.rules) {
            let css = rule.toCss(indent + "  ")
            if (css.length > 0) {
                sb.append("${indent}  ${css}\n")
            }
        }
        sb.append("${indent}}")
        return sb.toString()
    }
}

// ============================================================================
// @namespace 规则
// ============================================================================

/// CSS @namespace 规则
public class CssAtNamespaceRule {
    /// 命名空间声明文本
    public var declaration: String
    /// 位置信息
    public var position: ?CssTokenPosition

    public init(declaration: String) {
        this.declaration = declaration
        this.position = None
    }

    public func toCss(): String {
        "@namespace ${declaration};"
    }
}

// ============================================================================
// @property 规则
// ============================================================================

/// CSS @property 规则
public class CssAtPropertyRule {
    /// 属性名
    public var name: String
    /// 声明块
    public var declarations: CssDeclarationBlock
    /// 位置信息
    public var position: ?CssTokenPosition

    public init(name: String, declarations: CssDeclarationBlock) {
        this.name = name
        this.declarations = declarations
        this.position = None
    }

    public func toCss(indent: String): String {
        let sb = StringBuilder()
        sb.append("${indent}@property ${name}")
        sb.append(declarations.toCssBlock(indent))
        return sb.toString()
    }
}

// ============================================================================
// 未知 @规则
// 严格翻译自: rules/unknown.zig UnknownAtRule
// ============================================================================

/// 未知 @规则
public class CssUnknownAtRule {
    /// @规则名
    public var name: String
    /// 前导内容
    public var prelude: String
    /// 声明块
    public var declarations: CssDeclarationBlock
    /// 子规则列表 (可选)
    public var rules: ?CssRuleList
    /// 位置信息
    public var position: ?CssTokenPosition

    public init(name: String, prelude: String, declarations: CssDeclarationBlock) {
        this.name = name
        this.prelude = prelude
        this.declarations = declarations
        this.rules = None
        this.position = None
    }

    public func toCss(indent: String): String {
        match (rules) {
            case Some(ruleList) =>
                let sb = StringBuilder()
                sb.append("${indent}@${name} ${prelude} {\n")
                for (rule in ruleList.rules) {
                    let css = rule.toCss(indent + "  ")
                    if (css.length > 0) {
                        sb.append("${indent}  ${css}\n")
                    }
                }
                sb.append("${indent}}")
                return sb.toString()
            case None =>
                let sb = StringBuilder()
                sb.append("${indent}@${name} ${prelude}")
                if (!declarations.isEmpty()) {
                    sb.append(declarations.toCssBlock(indent))
                } else {
                    sb.append(";")
                }
                return sb.toString()
        }
    }
}
