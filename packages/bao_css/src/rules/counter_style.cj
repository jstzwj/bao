// bao_css - CSS @counter-style 计数器样式规则
// 严格翻译自: bun/src/css/rules/counter_style.rs
//   对应: rules/counter_style.zig - CounterStyleRule
package bao_css.rules

import bao_core.*
import bao_collections.*

// ============================================================================
// @counter-style 规则
// 严格翻译自: rules/counter_style.rs CounterStyleRule struct
// ============================================================================

/// CSS @counter-style 规则
/// 严格翻译自 CounterStyleRule struct { name: CustomIdent, declarations: DeclarationBlock<'static>, loc: Location }
/// 表示一个 @counter-style 规则
public class CssCounterStyleRule {
    /// 计数器样式名称
    public var name: String
    /// 声明块
    public var declarations: CssDeclarationBlock
    /// 位置信息
    public var loc: CssLocation

    public init(name: String, declarations: CssDeclarationBlock) {
        this.name = name
        this.declarations = declarations
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 CounterStyleRule.deep_clone
    public func deepClone(): CssCounterStyleRule {
        CssCounterStyleRule(name, declarations.deepClone())
    }

    /// 转为 CSS 文本
    /// 严格翻译自 CounterStyleRule.to_css
    public func toCss(indent: String): String {
        let sb = StringBuilder()
        sb.append("${indent}@counter-style ${name}")
        sb.append(declarations.toCssBlock(indent))
        return sb.toString()
    }

    public func toString(): String {
        toCss("")
    }
}
