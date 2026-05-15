// bao_css - CSS @page 页面规则
// 严格翻译自: bun/src/css/rules/page.rs
//   对应: rules/page.zig - PageRule, PageSelector, PageMarginRule,
//     PagePseudoClass, PageMarginBox
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// 页面伪类
// 严格翻译自: rules/page.rs PagePseudoClass enum
// ============================================================================

/// CSS @page 选择器伪类
/// 严格翻译自 PagePseudoClass enum { Left, Right, First, Last, Blank }
public enum CssPagePseudoClass {
    | Left    // :left
    | Right   // :right
    | First   // :first
    | Last    // :last
    | Blank   // :blank

    public func toCss(): String {
        match (this) {
            case Left => "left"
            case Right => "right"
            case First => "first"
            case Last => "last"
            case Blank => "blank"
        }
    }
}

// ============================================================================
// 页面边距框
// 严格翻译自: rules/page.rs PageMarginBox enum
// ============================================================================

/// CSS 页面边距框
/// 严格翻译自 PageMarginBox enum (16 个边距框类型)
public enum CssPageMarginBox {
    | TopLeftCorner      // 左上角
    | TopLeft            // 左上
    | TopCenter          // 上中
    | TopRight           // 右上
    | TopRightCorner     // 右上角
    | LeftTop            // 左上侧
    | LeftMiddle         // 左中
    | LeftBottom         // 左下侧
    | RightTop           // 右上侧
    | RightMiddle        // 右中
    | RightBottom        // 右下侧
    | BottomLeftCorner   // 左下角
    | BottomLeft         // 左下
    | BottomCenter       // 下中
    | BottomRight        // 右下
    | BottomRightCorner  // 右下角

    public func toCss(): String {
        match (this) {
            case TopLeftCorner => "top-left-corner"
            case TopLeft => "top-left"
            case TopCenter => "top-center"
            case TopRight => "top-right"
            case TopRightCorner => "top-right-corner"
            case LeftTop => "left-top"
            case LeftMiddle => "left-middle"
            case LeftBottom => "left-bottom"
            case RightTop => "right-top"
            case RightMiddle => "right-middle"
            case RightBottom => "right-bottom"
            case BottomLeftCorner => "bottom-left-corner"
            case BottomLeft => "bottom-left"
            case BottomCenter => "bottom-center"
            case BottomRight => "bottom-right"
            case BottomRightCorner => "bottom-right-corner"
        }
    }
}

// ============================================================================
// 页面选择器
// 严格翻译自: rules/page.rs PageSelector struct
// ============================================================================

/// CSS @page 选择器
/// 严格翻译自 PageSelector struct { name: Option<&'static [u8]>, pseudo_classes: ArrayList<PagePseudoClass> }
public class CssPageSelector {
    /// 可选命名页面类型
    public var name: ?String
    /// 页面伪类列表
    public var pseudoClasses: ArrayList<CssPagePseudoClass>

    public init(name: ?String, pseudoClasses: ArrayList<CssPagePseudoClass>) {
        this.name = name
        this.pseudoClasses = pseudoClasses
    }

    /// 深拷贝
    /// 严格翻译自 PageSelector.deep_clone
    public func deepClone(): CssPageSelector {
        let newPseudo = ArrayList<CssPagePseudoClass>()
        for (p in pseudoClasses) {
            newPseudo.append(p)
        }
        return CssPageSelector(name, newPseudo)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 PageSelector.to_css
    public func toCss(): String {
        let sb = StringBuilder()
        match (name) {
            case Some(n) => sb.append(n)
            case None => {}
        }
        for (pseudo in pseudoClasses) {
            sb.append(":${pseudo.toCss()}")
        }
        return sb.toString()
    }
}

// ============================================================================
// 页面边距规则
// 严格翻译自: rules/page.rs PageMarginRule struct
// ============================================================================

/// CSS @page 边距规则
/// 严格翻译自 PageMarginRule struct { margin_box: PageMarginBox, declarations: DeclarationBlock, loc }
public class CssPageMarginRule {
    /// 边距框标识
    public var marginBox: CssPageMarginBox
    /// 声明块
    public var declarations: CssDeclarationBlock
    /// 位置信息
    public var loc: CssLocation

    public init(marginBox: CssPageMarginBox, declarations: CssDeclarationBlock) {
        this.marginBox = marginBox
        this.declarations = declarations
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 PageMarginRule.deep_clone
    public func deepClone(): CssPageMarginRule {
        CssPageMarginRule(marginBox, declarations.deepClone())
    }

    /// 转为 CSS 文本
    /// 严格翻译自 PageMarginRule.to_css
    public func toCss(indent: String): String {
        let sb = StringBuilder()
        sb.append("${indent}@${marginBox.toCss()}")
        sb.append(declarations.toCssBlock(indent))
        return sb.toString()
    }
}

// ============================================================================
// @page 规则
// 严格翻译自: rules/page.rs PageRule struct
// ============================================================================

/// CSS @page 规则
/// 严格翻译自 PageRule struct { selectors, declarations, rules, loc }
/// 表示一个 @page 规则
public class CssPageRule {
    /// 页面选择器列表
    public var selectors: ArrayList<CssPageSelector>
    /// 声明块
    public var declarations: CssDeclarationBlock
    /// 嵌套边距规则
    public var rules: ArrayList<CssPageMarginRule>
    /// 位置信息
    public var loc: CssLocation

    public init(selectors: ArrayList<CssPageSelector>, declarations: CssDeclarationBlock, rules: ArrayList<CssPageMarginRule>) {
        this.selectors = selectors
        this.declarations = declarations
        this.rules = rules
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 PageRule.deep_clone
    public func deepClone(): CssPageRule {
        let newSelectors = ArrayList<CssPageSelector>()
        for (s in selectors) {
            newSelectors.append(s.deepClone())
        }
        let newRules = ArrayList<CssPageMarginRule>()
        for (r in rules) {
            newRules.append(r.deepClone())
        }
        return CssPageRule(newSelectors, declarations.deepClone(), newRules)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 PageRule.to_css
    public func toCss(indent: String, minify: Bool): String {
        let sb = StringBuilder()
        sb.append("${indent}@page")
        if (selectors.size >= 1) {
            let first = selectors[0]
            if (!minify && first.name != None) {
                sb.append(" ")
            }
            let selStrs = ArrayList<String>()
            for (s in selectors) {
                selStrs.append(s.toCss())
            }
            sb.append(" ${String.join(", ", selStrs)}")
        }
        sb.append(declarations.toCssBlock(indent))

        // 边距规则
        if (rules.size > 0) {
            for (rule in rules) {
                sb.append("\n${rule.toCss(indent)}")
            }
        }

        return sb.toString()
    }

    public func toString(): String {
        toCss("", false)
    }
}
