// bao_css - CSS @tailwind 规则 (Tailwind CSS 专用)
// 严格翻译自: bun/src/css/rules/tailwind.rs
//   对应: rules/tailwind.zig - TailwindAtRule, TailwindStyleName
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// Tailwind 样式名
// 严格翻译自: rules/tailwind.rs TailwindStyleName enum
// ============================================================================

/// Tailwind CSS 样式名
/// 严格翻译自 TailwindStyleName enum { Base, Components, Utilities, Variants }
public enum CssTailwindStyleName {
    | Base         // 基础样式
    | Components   // 组件类
    | Utilities    // 实用工具类
    | Variants     // 变体 (hover, focus, responsive, dark mode 等)

    public func toCss(): String {
        match (this) {
            case Base => "base"
            case Components => "components"
            case Utilities => "utilities"
            case Variants => "variants"
        }
    }
}

// ============================================================================
// @tailwind 规则
// 严格翻译自: rules/tailwind.rs TailwindAtRule struct
// ============================================================================

/// CSS @tailwind 规则
/// 严格翻译自 TailwindAtRule struct { style_name: TailwindStyleName, loc: Location }
/// Tailwind CSS 专用 @规则
public class CssTailwindAtRule {
    /// 样式名
    public var styleName: CssTailwindStyleName
    /// 位置信息
    public var loc: CssLocation

    public init(styleName: CssTailwindStyleName) {
        this.styleName = styleName
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 TailwindAtRule.deep_clone — Copy
    public func deepClone(): CssTailwindAtRule {
        CssTailwindAtRule(styleName)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 TailwindAtRule.to_css
    public func toCss(): String {
        "@tailwind ${styleName.toCss()};"
    }

    public func toString(): String {
        toCss()
    }
}
