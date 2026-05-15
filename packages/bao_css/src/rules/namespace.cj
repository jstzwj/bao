// bao_css - CSS @namespace 命名空间规则
// 严格翻译自: bun/src/css/rules/namespace.rs
//   对应: rules/namespace.zig - NamespaceRule
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// @namespace 规则
// 严格翻译自: rules/namespace.rs NamespaceRule struct
// ============================================================================

/// CSS @namespace 规则
/// 严格翻译自 NamespaceRule struct { prefix: Option<Ident>, url: CssString, loc: Location }
/// 表示一个 @namespace 规则
public class CssNamespaceRuleFull {
    /// 可选命名空间前缀，None 为默认命名空间
    public var prefix: ?String
    /// 命名空间 URL
    public var url: String
    /// 位置信息
    public var loc: CssLocation

    public init(prefix: ?String, url: String) {
        this.prefix = prefix
        this.url = url
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 NamespaceRule.deep_clone
    public func deepClone(): CssNamespaceRuleFull {
        CssNamespaceRuleFull(prefix, url)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 NamespaceRule.to_css
    public func toCss(): String {
        match (prefix) {
            case Some(p) => "@namespace ${p} \"${url}\";"
            case None => "@namespace \"${url}\";"
        }
    }

    public func toString(): String {
        toCss()
    }
}
