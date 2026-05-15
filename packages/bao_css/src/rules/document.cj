// bao_css - CSS @-moz-document 规则
// 严格翻译自: bun/src/css/rules/document.rs
//   对应: rules/document.zig - MozDocumentRule
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// @-moz-document 规则
// 严格翻译自: rules/document.rs MozDocumentRule<R>
// ============================================================================

/// CSS @-moz-document 规则
/// 严格翻译自 MozDocumentRule struct { rules: CssRuleList<R>, loc: Location }
/// 仅支持 url-prefix() 无参数和 -moz 前缀
public class CssMozDocumentRule {
    /// 子规则列表
    public var rules: CssRuleList
    /// 位置信息
    public var loc: CssLocation

    public init(rules: CssRuleList) {
        this.rules = rules
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 MozDocumentRule.deep_clone
    public func deepClone(): CssMozDocumentRule {
        CssMozDocumentRule(rules.deepClone())
    }

    /// 转为 CSS 文本
    /// 严格翻译自 MozDocumentRule.to_css
    public func toCss(indent: String): String {
        let sb = StringBuilder()
        sb.append("${indent}@-moz-document url-prefix() {\n")
        for (rule in rules.rules) {
            let css = rule.toCss(indent + "  ")
            if (css.length > 0) {
                sb.append("${indent}  ${css}\n")
            }
        }
        sb.append("${indent}}")
        return sb.toString()
    }

    public func toString(): String {
        toCss("")
    }
}
