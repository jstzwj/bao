// bao_css - CSS @starting-style 起始样式规则
// 严格翻译自: bun/src/css/rules/starting_style.rs
//   对应: rules/starting_style.zig - StartingStyleRule
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// @starting-style 规则
// 严格翻译自: rules/starting_style.rs StartingStyleRule<R>
// ============================================================================

/// CSS @starting-style 规则
/// 严格翻译自 StartingStyleRule struct { rules: CssRuleList<R>, loc: Location }
/// 表示一个 @starting-style 规则
public class CssStartingStyleRule {
    /// 子规则列表
    public var rules: CssRuleList
    /// 位置信息
    public var loc: CssLocation

    public init(rules: CssRuleList) {
        this.rules = rules
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 StartingStyleRule.deep_clone
    public func deepClone(): CssStartingStyleRule {
        CssStartingStyleRule(rules.deepClone())
    }

    /// 转为 CSS 文本
    /// 严格翻译自 StartingStyleRule.to_css
    public func toCss(indent: String): String {
        let sb = StringBuilder()
        sb.append("${indent}@starting-style {\n")
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
