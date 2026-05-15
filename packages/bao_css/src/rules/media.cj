// bao_css - CSS @media 媒体规则
// 严格翻译自: bun/src/css/rules/media.rs
//   对应: rules/media.zig - MediaRule
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// @media 规则
// 严格翻译自: rules/media.rs MediaRule<R>
// ============================================================================

/// CSS @media 规则
/// 严格翻译自 MediaRule struct { query: MediaList, rules: CssRuleList<R>, loc: Location }
/// 表示一个 @media 规则，包含媒体查询和子规则列表
public class CssMediaRuleFull {
    /// 媒体查询文本
    public var query: String
    /// 子规则列表
    public var rules: CssRuleList
    /// 位置信息
    public var loc: CssLocation

    public init(query: String, rules: CssRuleList) {
        this.query = query
        this.rules = rules
        this.loc = CssLocation()
    }

    /// 媒体查询是否总是匹配 (minify 时可省略 @media 包裹)
    /// 严格翻译自 MediaRule.to_css 中 minify 分支
    public func alwaysMatches(): Bool {
        query == "all" || query == "not all" == false && query.length == 0
    }

    /// 深拷贝
    /// 严格翻译自 MediaRule.deep_clone
    public func deepClone(): CssMediaRuleFull {
        CssMediaRuleFull(query, rules.deepClone())
    }

    /// 转为 CSS 文本
    /// 严格翻译自 MediaRule.to_css
    public func toCss(indent: String, minify: Bool): String {
        let sb = StringBuilder()
        sb.append("${indent}@media ${query} {\n")
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
        toCss("", false)
    }
}
