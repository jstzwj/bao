// bao_css - CSS @custom-media 自定义媒体规则
// 严格翻译自: bun/src/css/rules/custom_media.rs
//   对应: rules/custom_media.zig - CustomMediaRule
package bao_css.rules

import bao_core.*
import bao_collections.*

// ============================================================================
// @custom-media 规则
// 严格翻译自: rules/custom_media.rs CustomMediaRule struct
// ============================================================================

/// CSS @custom-media 规则
/// 严格翻译自 CustomMediaRule struct { name: DashedIdent, query: MediaList, loc: Location }
/// 表示一个 @custom-media 规则
public class CssCustomMediaRule {
    /// 媒体名称 (--name)
    public var name: String
    /// 媒体查询
    public var query: String
    /// 位置信息
    public var loc: CssLocation

    public init(name: String, query: String) {
        this.name = name
        this.query = query
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 CustomMediaRule.deep_clone
    public func deepClone(): CssCustomMediaRule {
        CssCustomMediaRule(name, query)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 CustomMediaRule.to_css
    public func toCss(): String {
        "@custom-media ${name} ${query};"
    }

    public func toString(): String {
        toCss()
    }
}
