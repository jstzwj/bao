// bao_css - CSS 标识符值类型
// 严格翻译自: bun/src/css/values/ident.rs
//   对应: values/ident.zig - CustomIdent, DashedIdent, Ident
package bao_css.values

import bao_core.*

// ============================================================================
// 自定义标识符
// 严格翻译自: values/ident.rs CustomIdent struct
// ============================================================================

/// CSS <custom-ident>
/// 严格翻译自 CustomIdent struct { v: *const [u8] }
/// CSS 自定义标识符 (排除 CSS 全局关键字)
public class CssCustomIdent {
    public var value: String

    public init(value: String) {
        this.value = value
    }

    /// 深拷贝
    /// 严格翻译自 CustomIdent.deep_clone — arena slice identity copy
    public func deepClone(): CssCustomIdent {
        CssCustomIdent(value)
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        value
    }

    public func toString(): String {
        value
    }
}

// ============================================================================
// 虚线标识符
// 严格翻译自: values/ident.rs DashedIdent struct
// ============================================================================

/// CSS <dashed-ident>
/// 严格翻译自 DashedIdent struct { v: *const [u8] }
/// 以 -- 开头的标识符 (CSS 自定义属性)
public class CssDashedIdent {
    public var value: String

    public init(value: String) {
        this.value = value
    }

    /// 深拷贝
    /// 严格翻译自 DashedIdent.deep_clone
    public func deepClone(): CssDashedIdent {
        CssDashedIdent(value)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 DashedIdentFns.to_css — 前缀 -- + serialize_name
    public func toCss(): String {
        if (value.startsWith("--")) {
            value
        } else {
            "--${value}"
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 标识符
// 严格翻译自: values/ident.rs Ident struct
// ============================================================================

/// CSS <ident>
/// 严格翻译自 Ident struct { v: *const [u8] }
/// 普通 CSS 标识符
public class CssIdent {
    public var value: String

    public init(value: String) {
        this.value = value
    }

    /// 深拷贝
    /// 严格翻译自 Ident.deep_clone
    public func deepClone(): CssIdent {
        CssIdent(value)
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        value
    }

    public func toString(): String {
        value
    }
}
