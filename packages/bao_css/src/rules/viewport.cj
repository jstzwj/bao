// bao_css - CSS @viewport 视口规则
// 严格翻译自: bun/src/css/rules/viewport.rs
//   对应: rules/viewport.zig - ViewportRule
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// @viewport 规则
// 严格翻译自: rules/viewport.rs ViewportRule struct
// ============================================================================

/// CSS @viewport 规则
/// 严格翻译自 ViewportRule struct { vendor_prefix, declarations, loc }
/// 表示一个 @viewport 规则
public class CssViewportRule {
    /// 供应商前缀 (如 -ms-)
    public var vendorPrefix: VendorPrefix
    /// 声明块
    public var declarations: CssDeclarationBlock
    /// 位置信息
    public var loc: CssLocation

    public init(vendorPrefix: VendorPrefix, declarations: CssDeclarationBlock) {
        this.vendorPrefix = vendorPrefix
        this.declarations = declarations
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 ViewportRule.deep_clone
    public func deepClone(): CssViewportRule {
        CssViewportRule(vendorPrefix, declarations.deepClone())
    }

    /// 转为 CSS 文本
    /// 严格翻译自 ViewportRule.to_css
    public func toCss(indent: String): String {
        let sb = StringBuilder()
        sb.append("${indent}@")
        // 供应商前缀
        let prefixStr = vendorPrefix.toPrefixString()
        sb.append("${prefixStr}viewport")
        sb.append(declarations.toCssBlock(indent))
        return sb.toString()
    }

    public func toString(): String {
        toCss("")
    }
}
