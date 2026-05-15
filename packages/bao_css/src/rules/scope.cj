// bao_css - CSS @scope 范围规则
// 严格翻译自: bun/src/css/rules/scope.rs
//   对应: rules/scope.zig - ScopeRule
package bao_css.rules

import bao_core.*
import bao_collections.*

// ============================================================================
// @scope 规则
// 严格翻译自: rules/scope.rs ScopeRule<R>
// ============================================================================

/// CSS @scope 规则
/// 严格翻译自 ScopeRule struct { scope_start, scope_end, rules, loc }
/// @scope (<scope-start>) [to (<scope-end>)]? { <stylesheet> }
public class CssScopeRule {
    /// 范围起始选择器列表
    public var scopeStart: ?String
    /// 范围结束选择器列表
    public var scopeEnd: ?String
    /// 子规则列表
    public var rules: CssRuleList
    /// 位置信息
    public var loc: CssLocation

    public init(scopeStart: ?String, scopeEnd: ?String, rules: CssRuleList) {
        this.scopeStart = scopeStart
        this.scopeEnd = scopeEnd
        this.rules = rules
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 ScopeRule.deep_clone
    public func deepClone(): CssScopeRule {
        CssScopeRule(scopeStart, scopeEnd, rules.deepClone())
    }

    /// 转为 CSS 文本
    /// 严格翻译自 ScopeRule.to_css
    public func toCss(indent: String, minify: Bool): String {
        let sb = StringBuilder()
        sb.append("${indent}@scope")

        // scope-start
        match (scopeStart) {
            case Some(start) => {
                sb.append(" (${start})")
            }
            case None => {}
        }

        // scope-end
        match (scopeEnd) {
            case Some(end) => {
                sb.append(" to (${end})")
            }
            case None => {}
        }

        sb.append(" {\n")

        // 子规则
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
