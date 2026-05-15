// bao_css - CSS @keyframes 关键帧规则
// 严格翻译自: bun/src/css/rules/keyframes.rs
//   对应: rules/keyframes.zig - KeyframesName, KeyframeSelector, Keyframe, KeyframesRule
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// 关键帧名称
// 严格翻译自: rules/keyframes.rs KeyframesName enum
// ============================================================================

/// CSS <keyframes-name>
/// 严格翻译自 KeyframesName union { Ident(CustomIdent), Custom(&'static [u8]) }
/// 关键帧名称可以是自定义标识符或引号字符串
public class CssKeyframesName {
    public enum CssKeyframesNameKind {
        | Ident   // <custom-ident>
        | Custom  // <string>
    }

    public var kind: CssKeyframesNameKind
    /// 标识符值 (Ident 时使用)
    public var identValue: String
    /// 字符串值 (Custom 时使用)
    public var stringValue: String

    public init(ident: String) {
        this.kind = CssKeyframesNameKind.Ident
        this.identValue = ident
        this.stringValue = ""
    }

    public init(custom: String) {
        this.kind = CssKeyframesNameKind.Custom
        this.identValue = ""
        this.stringValue = custom
    }

    /// 获取名称值
    /// 严格翻译自 KeyframesName 的底层值
    public func value(): String {
        match (kind) {
            case Ident => identValue
            case Custom => stringValue
        }
    }

    /// 深拷贝
    /// 严格翻译自 KeyframesName.deep_clone
    public func deepClone(): CssKeyframesName {
        match (kind) {
            case Ident => CssKeyframesName(ident: identValue)
            case Custom => CssKeyframesName(custom: stringValue)
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 KeyframesName.to_css
    public func toCss(): String {
        match (kind) {
            case Ident => identValue
            case Custom => {
                // CSS-wide 关键字和 none 不能去除引号
                if (isReservedCustomIdent(stringValue)) {
                    "\"${stringValue}\""
                } else {
                    stringValue
                }
            }
        }
    }

    /// 是否为保留的自定义标识符
    private func isReservedCustomIdent(s: String): Bool {
        s == "none" || s == "initial" || s == "inherit" || s == "unset" || s == "default"
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 关键帧选择器
// 严格翻译自: rules/keyframes.rs KeyframeSelector enum
// ============================================================================

/// CSS 关键帧选择器
/// 严格翻译自 KeyframeSelector union { Percentage(f32), From, To }
/// 表示 @keyframes 中的 from/to/百分比选择器
public class CssKeyframeSelector {
    public enum CssKeyframeSelectorKind {
        | Percentage  // 百分比选择器
        | From        // from 关键字 (= 0%)
        | To          // to 关键字 (= 100%)
    }

    public var kind: CssKeyframeSelectorKind
    /// 百分比值 (Percentage 时使用)
    public var percentageValue: Float64

    public init(kind: CssKeyframeSelectorKind) {
        this.kind = kind
        this.percentageValue = 0.0
    }

    public init(percentage: Float64) {
        this.kind = CssKeyframeSelectorKind.Percentage
        this.percentageValue = percentage
    }

    /// 深拷贝
    /// 严格翻译自 KeyframeSelector.deep_clone — Percentage 是 Copy
    public func deepClone(): CssKeyframeSelector {
        let s = CssKeyframeSelector(kind)
        s.percentageValue = percentageValue
        return s
    }

    /// 转为 CSS 文本
    /// 严格翻译自 KeyframeSelector.to_css
    public func toCss(minify: Bool): String {
        match (kind) {
            case Percentage => {
                if (minify && percentageValue == 1.0) {
                    "to"
                } else {
                    "${percentageValue * 100.0}%"
                }
            }
            case From => {
                if (minify) { "0%" } else { "from" }
            }
            case To => "to"
        }
    }

    public func toString(): String {
        toCss(false)
    }
}

// ============================================================================
// 关键帧
// 严格翻译自: rules/keyframes.rs Keyframe struct
// ============================================================================

/// CSS 关键帧
/// 严格翻译自 Keyframe struct { selectors, declarations }
/// 表示 @keyframes 中的一个关键帧
public class CssKeyframeFull {
    /// 关键帧选择器列表
    public var selectors: ArrayList<CssKeyframeSelector>
    /// 声明块
    public var declarations: CssDeclarationBlock

    public init(selectors: ArrayList<CssKeyframeSelector>, declarations: CssDeclarationBlock) {
        this.selectors = selectors
        this.declarations = declarations
    }

    /// 深拷贝
    /// 严格翻译自 Keyframe.deep_clone
    public func deepClone(): CssKeyframeFull {
        let newSelectors = ArrayList<CssKeyframeSelector>()
        for (s in selectors) {
            newSelectors.append(s.deepClone())
        }
        return CssKeyframeFull(newSelectors, declarations.deepClone())
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Keyframe.to_css
    public func toCss(indent: String, minify: Bool): String {
        let sb = StringBuilder()
        // 选择器列表 (逗号分隔)
        var first = true
        for (sel in selectors) {
            if (!first) { sb.append(", ") }
            first = false
            sb.append(sel.toCss(minify))
        }
        sb.append(declarations.toCssBlock(indent))
        return sb.toString()
    }
}

// ============================================================================
// @keyframes 规则
// 严格翻译自: rules/keyframes.rs KeyframesRule struct
// ============================================================================

/// CSS @keyframes 规则
/// 严格翻译自 KeyframesRule struct { name, keyframes, vendor_prefix, loc }
/// 表示一个完整的 @keyframes 规则
public class CssKeyframesRuleFull {
    /// 动画名称
    public var name: CssKeyframesName
    /// 关键帧列表
    public var keyframes: ArrayList<CssKeyframeFull>
    /// 供应商前缀
    public var vendorPrefix: VendorPrefix
    /// 位置信息
    public var loc: CssLocation

    public init(name: CssKeyframesName, keyframes: ArrayList<CssKeyframeFull>) {
        this.name = name
        this.keyframes = keyframes
        this.vendorPrefix = VendorPrefix()
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 KeyframesRule.deep_clone
    public func deepClone(): CssKeyframesRuleFull {
        let newKeyframes = ArrayList<CssKeyframeFull>()
        for (kf in keyframes) {
            newKeyframes.append(kf.deepClone())
        }
        let rule = CssKeyframesRuleFull(name.deepClone(), newKeyframes)
        rule.vendorPrefix = vendorPrefix
        rule.loc = loc
        return rule
    }

    /// 转为 CSS 文本
    /// 严格翻译自 KeyframesRule.to_css
    /// 为每个供应商前缀输出一份
    public func toCss(indent: String, minify: Bool): String {
        let sb = StringBuilder()
        var firstRule = true

        let prefixes = getOrderedPrefixes()
        for (prefix in prefixes) {
            if (vendorPrefix.hasPrefix(prefix)) {
                if (!firstRule) {
                    if (!minify) { sb.append("\n") }
                    sb.append("\n")
                }
                firstRule = false

                let prefixStr = vendorPrefixToAtRule(prefix)
                sb.append("${indent}@${prefixStr}keyframes ${name.toCss()}")
                if (!minify) { sb.append(" ") }
                sb.append("{\n")

                for (kf in keyframes) {
                    sb.append(kf.toCss(indent + "  ", minify))
                    sb.append("\n")
                }

                sb.append("${indent}}")
            }
        }

        return sb.toString()
    }

    /// 获取排序后的前缀列表
    /// 严格翻译自 PREFIXES 数组: [webkit, moz, ms, o, none]
    private func getOrderedPrefixes(): ArrayList<String> {
        let list = ArrayList<String>()
        list.append("webkit")
        list.append("moz")
        list.append("ms")
        list.append("o")
        list.append("none")
        return list
    }

    private func vendorPrefixToAtRule(prefix: String): String {
        match (prefix) {
            case "webkit" => "-webkit-"
            case "moz" => "-moz-"
            case "ms" => "-ms-"
            case "o" => "-o-"
            case _ => ""
        }
    }

    /// 获取后备规则 (当前返回空)
    /// 严格翻译自 KeyframesRule.get_fallbacks — Zig 中是编译时存根
    public func getFallbacks(): ArrayList<CssRule> {
        ArrayList<CssRule>()
    }

    public func toString(): String {
        toCss("", false)
    }
}
