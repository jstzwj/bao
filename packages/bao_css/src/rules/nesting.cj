// bao_css - CSS @nest 嵌套规则
// 严格翻译自: bun/src/css/rules/nesting.rs
//   对应: rules/nesting.zig - NestingRule
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// @nest 规则
// 严格翻译自: rules/nesting.rs NestingRule<R>
// ============================================================================

/// CSS @nest 规则
/// 严格翻译自 NestingRule struct { style: StyleRule<R>, loc: Location }
/// 表示一个 @nest 嵌套规则
public class CssNestingRuleFull {
    /// 底层样式规则
    public var style: CssStyleRuleFull
    /// 位置信息
    public var loc: CssLocation

    public init(style: CssStyleRuleFull) {
        this.style = style
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 NestingRule.deep_clone
    public func deepClone(): CssNestingRuleFull {
        let rule = CssNestingRuleFull(style.deepClone())
        rule.loc = loc
        return rule
    }

    /// 转为 CSS 文本
    /// 严格翻译自 NestingRule.to_css
    /// 如果没有上下文选择器，添加 @nest 前缀
    public func toCss(indent: String, hasContext: Bool): String {
        let prefix = if (hasContext) { "" } else { "@nest " }
        "${prefix}${style.toCss(indent)}"
    }

    public func toString(): String {
        toCss("", false)
    }
}
