// bao_css - CSS Properties: Properties Implementation
// 严格翻译自: bun/src/css/properties/properties_impl.rs
//   对应: properties_impl.zig - CSS 属性实现辅助
//   对应: Property::variant_tag, property_id_mixin, property_mixin
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// Property (简化表示)
// 严格翻译自 Property 联合体的核心接口
// ============================================================================

/// CSS 属性值联合类型（简化表示）
/// 严格翻译自 Property
///
/// 注意：完整的 Property 是一个大型联合类型，包含所有 CSS 属性的值。
/// 此处提供核心接口定义，具体属性值的类型在各属性模块中定义。
public class Property {
    public var tag: PropertyIdTag        // 属性标签
    public var value: String             // 属性值的 CSS 表示
    public var important: Bool           // 是否 !important
    public var prefix: String            // 供应商前缀

    public init(tag: PropertyIdTag, value: String, important: Bool, prefix: String) {
        this.tag = tag
        this.value = value
        this.important = important
        this.prefix = prefix
    }

    /// 获取原始属性标签（不穿透 Unparsed）
    /// 严格翻译自 Property::variant_tag
    public func variantTag(): PropertyIdTag {
        return tag
    }

    /// 序列化为 CSS
    /// 严格翻译自 property_mixin::to_css
    public func toCss(): String {
        if (important) {
            return prefix + tag.toCssName() + ": " + value + " !important"
        }
        return prefix + tag.toCssName() + ": " + value
    }
}

// ============================================================================
// PropertyId
// 严格翻译自 PropertyId
// ============================================================================

/// CSS 属性标识符
/// 严格翻译自 PropertyId
public class PropertyId {
    public var tag: PropertyIdTag   // 属性标签
    public var prefix: String       // 供应商前缀

    public init(tag: PropertyIdTag, prefix: String) {
        this.tag = tag
        this.prefix = prefix
    }

    /// 序列化为 CSS 属性名
    /// 严格翻译自 property_id_mixin::to_css
    public func toCss(): String {
        return prefix + tag.toCssName()
    }

    /// 从字符串解析属性标识符
    /// 严格翻译自 property_id_mixin::from_string
    public static func fromString(name: String): PropertyId {
        // 去除供应商前缀
        var prefix = ""
        var trimmedName = name
        if (name.startsWith("-webkit-")) {
            prefix = "-webkit-"
            trimmedName = name.substring(8)
        } else if (name.startsWith("-moz-")) {
            prefix = "-moz-"
            trimmedName = name.substring(5)
        } else if (name.startsWith("-ms-")) {
            prefix = "-ms-"
            trimmedName = name.substring(4)
        } else if (name.startsWith("-o-")) {
            prefix = "-o-"
            trimmedName = name.substring(3)
        }

        // 查找匹配的属性标签
        var tag = propertyIdTagFromName(trimmedName)
        return PropertyId(tag: tag, prefix: prefix)
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 从 CSS 属性名获取 PropertyIdTag
/// 严格翻译自 PropertyId::from_name_and_prefix 的查找逻辑
public func propertyIdTagFromName(name: String): PropertyIdTag {
    // 背景
    if (name == "background-color") { return PropertyIdTag.BackgroundColor }
    if (name == "background-image") { return PropertyIdTag.BackgroundImage }
    if (name == "background-position-x") { return PropertyIdTag.BackgroundPositionX }
    if (name == "background-position-y") { return PropertyIdTag.BackgroundPositionY }
    if (name == "background-position") { return PropertyIdTag.BackgroundPosition }
    if (name == "background-size") { return PropertyIdTag.BackgroundSize }
    if (name == "background-repeat") { return PropertyIdTag.BackgroundRepeat }
    if (name == "background-attachment") { return PropertyIdTag.BackgroundAttachment }
    if (name == "background-clip") { return PropertyIdTag.BackgroundClip }
    if (name == "background-origin") { return PropertyIdTag.BackgroundOrigin }
    if (name == "background") { return PropertyIdTag.Background }

    // 阴影 & 颜色
    if (name == "box-shadow") { return PropertyIdTag.BoxShadow }
    if (name == "opacity") { return PropertyIdTag.Opacity }
    if (name == "color") { return PropertyIdTag.Color }

    // 显示
    if (name == "display") { return PropertyIdTag.Display }
    if (name == "visibility") { return PropertyIdTag.Visibility }

    // 尺寸
    if (name == "width") { return PropertyIdTag.Width }
    if (name == "height") { return PropertyIdTag.Height }
    if (name == "min-width") { return PropertyIdTag.MinWidth }
    if (name == "min-height") { return PropertyIdTag.MinHeight }
    if (name == "max-width") { return PropertyIdTag.MaxWidth }
    if (name == "max-height") { return PropertyIdTag.MaxHeight }
    if (name == "block-size") { return PropertyIdTag.BlockSize }
    if (name == "inline-size") { return PropertyIdTag.InlineSize }
    if (name == "min-block-size") { return PropertyIdTag.MinBlockSize }
    if (name == "min-inline-size") { return PropertyIdTag.MinInlineSize }
    if (name == "max-block-size") { return PropertyIdTag.MaxBlockSize }
    if (name == "max-inline-size") { return PropertyIdTag.MaxInlineSize }
    if (name == "box-sizing") { return PropertyIdTag.BoxSizing }
    if (name == "aspect-ratio") { return PropertyIdTag.AspectRatio }

    // 溢出
    if (name == "overflow") { return PropertyIdTag.Overflow }
    if (name == "overflow-x") { return PropertyIdTag.OverflowX }
    if (name == "overflow-y") { return PropertyIdTag.OverflowY }
    if (name == "text-overflow") { return PropertyIdTag.TextOverflow }

    // 定位
    if (name == "position") { return PropertyIdTag.Position }
    if (name == "top") { return PropertyIdTag.Top }
    if (name == "bottom") { return PropertyIdTag.Bottom }
    if (name == "left") { return PropertyIdTag.Left }
    if (name == "right") { return PropertyIdTag.Right }
    if (name == "inset") { return PropertyIdTag.Inset }
    if (name == "inset-block") { return PropertyIdTag.InsetBlock }
    if (name == "inset-inline") { return PropertyIdTag.InsetInline }
    if (name == "inset-block-start") { return PropertyIdTag.InsetBlockStart }
    if (name == "inset-block-end") { return PropertyIdTag.InsetBlockEnd }
    if (name == "inset-inline-start") { return PropertyIdTag.InsetInlineStart }
    if (name == "inset-inline-end") { return PropertyIdTag.InsetInlineEnd }

    // 边框
    if (name == "border") { return PropertyIdTag.Border }
    if (name == "border-top") { return PropertyIdTag.BorderTop }
    if (name == "border-bottom") { return PropertyIdTag.BorderBottom }
    if (name == "border-left") { return PropertyIdTag.BorderLeft }
    if (name == "border-right") { return PropertyIdTag.BorderRight }
    if (name == "border-color") { return PropertyIdTag.BorderColor }
    if (name == "border-top-color") { return PropertyIdTag.BorderTopColor }
    if (name == "border-bottom-color") { return PropertyIdTag.BorderBottomColor }
    if (name == "border-left-color") { return PropertyIdTag.BorderLeftColor }
    if (name == "border-right-color") { return PropertyIdTag.BorderRightColor }
    if (name == "border-style") { return PropertyIdTag.BorderStyle }
    if (name == "border-top-style") { return PropertyIdTag.BorderTopStyle }
    if (name == "border-bottom-style") { return PropertyIdTag.BorderBottomStyle }
    if (name == "border-left-style") { return PropertyIdTag.BorderLeftStyle }
    if (name == "border-right-style") { return PropertyIdTag.BorderRightStyle }
    if (name == "border-width") { return PropertyIdTag.BorderWidth }
    if (name == "border-top-width") { return PropertyIdTag.BorderTopWidth }
    if (name == "border-bottom-width") { return PropertyIdTag.BorderBottomWidth }
    if (name == "border-left-width") { return PropertyIdTag.BorderLeftWidth }
    if (name == "border-right-width") { return PropertyIdTag.BorderRightWidth }
    if (name == "border-radius") { return PropertyIdTag.BorderRadius }
    if (name == "border-image") { return PropertyIdTag.BorderImage }
    if (name == "outline") { return PropertyIdTag.Outline }

    // 变换 & 过渡
    if (name == "transform") { return PropertyIdTag.Transform }
    if (name == "transition") { return PropertyIdTag.Transition }

    // 动画
    if (name == "animation") { return PropertyIdTag.Animation }

    // 字体
    if (name == "font") { return PropertyIdTag.Font }

    // Flex & Grid
    if (name == "flex") { return PropertyIdTag.Flex }
    if (name == "gap") { return PropertyIdTag.Gap }

    // 文本
    if (name == "text-align") { return PropertyIdTag.TextAlign }
    if (name == "text-decoration") { return PropertyIdTag.TextDecoration }
    if (name == "text-shadow") { return PropertyIdTag.TextShadow }
    if (name == "white-space") { return PropertyIdTag.WhiteSpace }

    // UI
    if (name == "cursor") { return PropertyIdTag.Cursor }
    if (name == "appearance") { return PropertyIdTag.Appearance }
    if (name == "color-scheme") { return PropertyIdTag.ColorScheme }

    // 默认返回 Custom
    return PropertyIdTag.Custom
}
