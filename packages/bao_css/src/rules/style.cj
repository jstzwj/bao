// bao_css - CSS StyleRule 样式规则
// 严格翻译自: bun/src/css/rules/style.rs
//   对应: rules/style.zig - StyleRule
package bao.css

import bao_core.*
import bao_collections.*
import bao_hash.*

// ============================================================================
// CSS 样式规则
// 严格翻译自: rules/style.rs StyleRule<R>
// ============================================================================

/// CSS 样式规则
/// 严格翻译自 StyleRule struct { selectors, vendor_prefix, declarations, rules, loc }
/// 表示一个 CSS 样式规则，包含选择器列表、声明块和嵌套规则
public class CssStyleRuleFull {
    /// 选择器列表
    public var selectors: CssSelectorList
    /// 供应商前缀
    public var vendorPrefix: VendorPrefix
    /// 声明块
    public var declarations: CssDeclarationBlock
    /// 嵌套规则
    public var rules: ArrayList<CssRule>
    /// 位置信息
    public var loc: CssLocation

    public init(selectors: CssSelectorList, declarations: CssDeclarationBlock, rules: ArrayList<CssRule>) {
        this.selectors = selectors
        this.declarations = declarations
        this.rules = rules
        this.vendorPrefix = VendorPrefix()
        this.loc = CssLocation()
    }

    public init(selectors: CssSelectorList, declarations: CssDeclarationBlock, rules: ArrayList<CssRule>, vendorPrefix: VendorPrefix, loc: CssLocation) {
        this.selectors = selectors
        this.declarations = declarations
        this.rules = rules
        this.vendorPrefix = vendorPrefix
        this.loc = loc
    }

    /// 是否为空规则
    /// 严格翻译自 StyleRule.isEmpty
    public func isEmpty(): Bool {
        selectors.isEmpty() || (declarations.isEmpty() && rules.size == 0)
    }

    /// 返回规则哈希键 (选择器 + 属性)
    /// 严格翻译自 StyleRule.hash_key
    public func hashKey(): Int64 {
        let hasher = Wyhash()
        hasher.update(selectors.toString())
        declarations.hashPropertyIds(hasher)
        return hasher.finalize()
    }

    /// 判断是否为重复规则 (相同选择器 + 相同属性)
    /// 严格翻译自 StyleRule.is_duplicate
    public func isDuplicate(other: CssStyleRuleFull): Bool {
        declarations.len() == other.declarations.len() &&
        selectors.toString() == other.selectors.toString()
    }

    /// 深拷贝
    /// 严格翻译自 StyleRule.deep_clone
    public func deepClone(): CssStyleRuleFull {
        let rule = CssStyleRuleFull(selectors, declarations.deepClone(), ArrayList<CssRule>())
        rule.vendorPrefix = vendorPrefix
        rule.loc = loc
        return rule
    }

    /// 转为 CSS 文本
    /// 严格翻译自 StyleRule.to_css
    /// 如果供应商前缀为空，输出基本样式；否则为每个前缀输出一份
    public func toCss(indent: String): String {
        if (isEmpty()) { return "" }

        let sb = StringBuilder()

        // 处理供应商前缀
        if (vendorPrefix.isEmpty()) {
            sb.append(toCssBase(indent))
        } else {
            var firstRule = true
            let prefixes = vendorPrefix.getPrefixes()
            for (prefix in prefixes) {
                if (!firstRule) {
                    sb.append("\n")
                }
                firstRule = false
                sb.append(toCssWithPrefix(indent, prefix))
            }
        }

        return sb.toString()
    }

    /// 基本样式输出 (无前缀)
    private func toCssBase(indent: String): String {
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

    /// 带前缀的样式输出
    private func toCssWithPrefix(indent: String, prefix: String): String {
        let sb = StringBuilder()
        let prefixStr = vendorPrefixToPrefixString(prefix)
        sb.append("${indent}${prefixStr}${selectors.toString()}")
        sb.append(declarations.toCssBlock(indent))
        return sb.toString()
    }

    private func vendorPrefixToPrefixString(prefix: String): String {
        match (prefix) {
            case "webkit" => "-webkit-"
            case "moz" => "-moz-"
            case "ms" => "-ms-"
            case "o" => "-o-"
            case _ => ""
        }
    }

    public func toString(): String {
        toCss("")
    }
}
