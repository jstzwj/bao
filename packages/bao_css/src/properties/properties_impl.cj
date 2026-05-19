// bao_css - CSS Properties: Properties Implementation
// 严格翻译自: bun/src/css/properties/properties_impl.rs
//   对应: properties_impl.zig - CSS 属性实现辅助
//   对应: Property::variant_tag, property_id_mixin, property_mixin
// ============================================================================

package bao_css.properties

import bao_core.*
import bao_collections.*

// ============================================================================
// Property (简化表示)
// 严格翻译自 Property 联合体的核心接口
// ============================================================================

/// CSS 属性值联合类型（简化表示）
/// 严格翻译自 Property
///
/// 注意：完整的 Property 是一个大型联合类型，包含所有 CSS 属性的值。
/// 此处提供核心接口定义，具体属性值的类型在各属性模块中定义。
public class PropertySimple {
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
public class PropertyIdSimple {
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
    public static func fromString(name: String): PropertyIdSimple {
        // 去除供应商前缀
        var prefix = ""
        var trimmedName = name
        if (name.startsWith("-webkit-")) {
            prefix = "-webkit-"
            trimmedName = name[8..name.size]
        } else if (name.startsWith("-moz-")) {
            prefix = "-moz-"
            trimmedName = name[5..name.size]
        } else if (name.startsWith("-ms-")) {
            prefix = "-ms-"
            trimmedName = name[4..name.size]
        } else if (name.startsWith("-o-")) {
            prefix = "-o-"
            trimmedName = name[3..name.size]
        }

        // 查找匹配的属性标签
        var tag = propertyIdTagFromName(trimmedName)
        return PropertyIdSimple(tag, prefix)
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
    if (name == "transform-origin") { return PropertyIdTag.TransformOrigin }
    if (name == "transform-style") { return PropertyIdTag.TransformStyle }
    if (name == "transform-box") { return PropertyIdTag.TransformBox }
    if (name == "transition") { return PropertyIdTag.Transition }
    if (name == "transition-property") { return PropertyIdTag.TransitionProperty }
    if (name == "transition-duration") { return PropertyIdTag.TransitionDuration }
    if (name == "transition-timing-function") { return PropertyIdTag.TransitionTimingFunction }
    if (name == "transition-delay") { return PropertyIdTag.TransitionDelay }
    if (name == "perspective") { return PropertyIdTag.Perspective }
    if (name == "perspective-origin") { return PropertyIdTag.PerspectiveOrigin }
    if (name == "backface-visibility") { return PropertyIdTag.BackfaceVisibility }
    if (name == "translate") { return PropertyIdTag.Translate }
    if (name == "rotate") { return PropertyIdTag.Rotate }
    if (name == "scale") { return PropertyIdTag.Scale }

    // 动画
    if (name == "animation") { return PropertyIdTag.Animation }
    if (name == "animation-name") { return PropertyIdTag.AnimationName }
    if (name == "animation-duration") { return PropertyIdTag.AnimationDuration }
    if (name == "animation-timing-function") { return PropertyIdTag.AnimationTimingFunction }
    if (name == "animation-delay") { return PropertyIdTag.AnimationDelay }
    if (name == "animation-iteration-count") { return PropertyIdTag.AnimationIterationCount }
    if (name == "animation-direction") { return PropertyIdTag.AnimationDirection }
    if (name == "animation-fill-mode") { return PropertyIdTag.AnimationFillMode }
    if (name == "animation-play-state") { return PropertyIdTag.AnimationPlayState }
    if (name == "animation-composition") { return PropertyIdTag.AnimationComposition }
    if (name == "animation-timeline") { return PropertyIdTag.AnimationTimeline }

    // 字体
    if (name == "font") { return PropertyIdTag.Font }
    if (name == "font-family") { return PropertyIdTag.FontFamily }
    if (name == "font-size") { return PropertyIdTag.FontSize }
    if (name == "font-weight") { return PropertyIdTag.FontWeight }
    if (name == "font-style") { return PropertyIdTag.FontStyle }
    if (name == "font-stretch") { return PropertyIdTag.FontStretch }
    if (name == "font-variant") { return PropertyIdTag.FontVariant }
    if (name == "font-variant-caps") { return PropertyIdTag.FontVariantCaps }
    if (name == "font-feature-settings") { return PropertyIdTag.FontFeatureSettings }
    if (name == "font-kerning") { return PropertyIdTag.FontKerning }
    if (name == "font-language-override") { return PropertyIdTag.FontLanguageOverride }
    if (name == "font-optical-sizing") { return PropertyIdTag.FontOpticalSizing }
    if (name == "font-palette") { return PropertyIdTag.FontPalette }
    if (name == "font-size-adjust") { return PropertyIdTag.FontSizeAdjust }
    if (name == "font-synthesis") { return PropertyIdTag.FontSynthesis }
    if (name == "font-variant-alternates") { return PropertyIdTag.FontVariantAlternates }
    if (name == "font-variant-east-asian") { return PropertyIdTag.FontVariantEastAsian }
    if (name == "font-variant-ligatures") { return PropertyIdTag.FontVariantLigatures }
    if (name == "font-variant-numeric") { return PropertyIdTag.FontVariantNumeric }
    if (name == "font-variant-position") { return PropertyIdTag.FontVariantPosition }
    if (name == "font-variation-settings") { return PropertyIdTag.FontVariationSettings }
    if (name == "line-height") { return PropertyIdTag.LineHeight }
    if (name == "vertical-align") { return PropertyIdTag.VerticalAlign }

    // Flex & Grid
    if (name == "flex") { return PropertyIdTag.Flex }
    if (name == "flex-grow") { return PropertyIdTag.FlexGrow }
    if (name == "flex-shrink") { return PropertyIdTag.FlexShrink }
    if (name == "flex-basis") { return PropertyIdTag.FlexBasis }
    if (name == "flex-direction") { return PropertyIdTag.FlexDirection }
    if (name == "flex-wrap") { return PropertyIdTag.FlexWrap }
    if (name == "flex-flow") { return PropertyIdTag.FlexFlow }
    if (name == "gap") { return PropertyIdTag.Gap }
    if (name == "row-gap") { return PropertyIdTag.RowGap }
    if (name == "column-gap") { return PropertyIdTag.ColumnGap }
    if (name == "grid") { return PropertyIdTag.Grid }
    if (name == "grid-area") { return PropertyIdTag.GridArea }
    if (name == "grid-auto-columns") { return PropertyIdTag.GridAutoColumns }
    if (name == "grid-auto-flow") { return PropertyIdTag.GridAutoFlow }
    if (name == "grid-auto-rows") { return PropertyIdTag.GridAutoRows }
    if (name == "grid-column") { return PropertyIdTag.gridColumn }
    if (name == "grid-column-end") { return PropertyIdTag.GridColumnEnd }
    if (name == "grid-column-start") { return PropertyIdTag.GridColumnStart }
    if (name == "grid-row") { return PropertyIdTag.GridRow }
    if (name == "grid-row-end") { return PropertyIdTag.GridRowEnd }
    if (name == "grid-row-start") { return PropertyIdTag.GridRowStart }
    if (name == "grid-template") { return PropertyIdTag.GridTemplate }
    if (name == "grid-template-areas") { return PropertyIdTag.GridTemplateAreas }
    if (name == "grid-template-columns") { return PropertyIdTag.GridTemplateColumns }
    if (name == "grid-template-rows") { return PropertyIdTag.GridTemplateRows }
    if (name == "order") { return PropertyIdTag.Order }
    if (name == "justify-content") { return PropertyIdTag.JustifyContent }
    if (name == "justify-items") { return PropertyIdTag.JustifyItems }
    if (name == "justify-self") { return PropertyIdTag.JustifySelf }
    if (name == "align-content") { return PropertyIdTag.AlignContent }
    if (name == "align-items") { return PropertyIdTag.AlignItems }
    if (name == "align-self") { return PropertyIdTag.AlignSelf }
    if (name == "place-content") { return PropertyIdTag.PlaceContent }
    if (name == "place-items") { return PropertyIdTag.PlaceItems }
    if (name == "place-self") { return PropertyIdTag.PlaceSelf }

    // 文本
    if (name == "text-decoration") { return PropertyIdTag.TextDecoration }
    if (name == "text-decoration-color") { return PropertyIdTag.TextDecorationColor }
    if (name == "text-decoration-line") { return PropertyIdTag.TextDecorationLine }
    if (name == "text-decoration-style") { return PropertyIdTag.TextDecorationStyle }
    if (name == "text-decoration-thickness") { return PropertyIdTag.TextDecorationThickness }
    if (name == "text-decoration-skip-ink") { return PropertyIdTag.TextDecorationSkipInk }
    if (name == "text-emphasis") { return PropertyIdTag.TextEmphasis }
    if (name == "text-emphasis-color") { return PropertyIdTag.TextEmphasisColor }
    if (name == "text-emphasis-position") { return PropertyIdTag.TextEmphasisPosition }
    if (name == "text-emphasis-style") { return PropertyIdTag.TextEmphasisStyle }
    if (name == "text-shadow") { return PropertyIdTag.TextShadow }
    if (name == "text-align") { return PropertyIdTag.TextAlign }
    if (name == "text-align-last") { return PropertyIdTag.TextAlignLast }
    if (name == "text-indent") { return PropertyIdTag.TextIndent }
    if (name == "text-justify") { return PropertyIdTag.TextJustify }
    if (name == "text-overflow") { return PropertyIdTag.TextOverflow }
    if (name == "text-transform") { return PropertyIdTag.TextTransform }
    if (name == "text-size-adjust") { return PropertyIdTag.TextSizeAdjust }
    if (name == "text-underline-offset") { return PropertyIdTag.TextUnderlineOffset }
    if (name == "text-underline-position") { return PropertyIdTag.TextUnderlinePosition }
    if (name == "text-orientation") { return PropertyIdTag.TextOrientation }
    if (name == "text-rendering") { return PropertyIdTag.Custom }
    if (name == "white-space") { return PropertyIdTag.WhiteSpace }
    if (name == "word-break") { return PropertyIdTag.WordBreak }
    if (name == "word-spacing") { return PropertyIdTag.WordSpacing }
    if (name == "word-wrap") { return PropertyIdTag.WordWrap }
    if (name == "overflow-wrap") { return PropertyIdTag.OverflowWrap }
    if (name == "letter-spacing") { return PropertyIdTag.LetterSpacing }
    if (name == "line-break") { return PropertyIdTag.LineBreak }
    if (name == "tab-size") { return PropertyIdTag.Custom }
    if (name == "hyphens") { return PropertyIdTag.Hyphens }

    // 方向 & 书写模式
    if (name == "direction") { return PropertyIdTag.Direction }
    if (name == "unicode-bidi") { return PropertyIdTag.UnicodeBidi }
    if (name == "writing-mode") { return PropertyIdTag.WritingMode }

    // 背景
    if (name == "background-color") { return PropertyIdTag.BackgroundColor }
    if (name == "background-image") { return PropertyIdTag.BackgroundImage }
    if (name == "background-position") { return PropertyIdTag.BackgroundPosition }
    if (name == "background-position-x") { return PropertyIdTag.BackgroundPositionX }
    if (name == "background-position-y") { return PropertyIdTag.BackgroundPositionY }
    if (name == "background-size") { return PropertyIdTag.BackgroundSize }
    if (name == "background-repeat") { return PropertyIdTag.BackgroundRepeat }
    if (name == "background-attachment") { return PropertyIdTag.BackgroundAttachment }
    if (name == "background-clip") { return PropertyIdTag.BackgroundClip }
    if (name == "background-origin") { return PropertyIdTag.BackgroundOrigin }

    // 边框圆角
    if (name == "border-top-left-radius") { return PropertyIdTag.BorderTopLeftRadius }
    if (name == "border-top-right-radius") { return PropertyIdTag.BorderTopRightRadius }
    if (name == "border-bottom-left-radius") { return PropertyIdTag.BorderBottomLeftRadius }
    if (name == "border-bottom-right-radius") { return PropertyIdTag.BorderBottomRightRadius }
    if (name == "border-start-start-radius") { return PropertyIdTag.BorderStartStartRadius }
    if (name == "border-start-end-radius") { return PropertyIdTag.BorderStartEndRadius }
    if (name == "border-end-start-radius") { return PropertyIdTag.BorderEndStartRadius }
    if (name == "border-end-end-radius") { return PropertyIdTag.BorderEndEndRadius }

    // 边框图片
    if (name == "border-image") { return PropertyIdTag.BorderImage }
    if (name == "border-image-outset") { return PropertyIdTag.BorderImageOutset }
    if (name == "border-image-repeat") { return PropertyIdTag.BorderImageRepeat }
    if (name == "border-image-slice") { return PropertyIdTag.BorderImageSlice }
    if (name == "border-image-source") { return PropertyIdTag.BorderImageSource }
    if (name == "border-image-width") { return PropertyIdTag.BorderImageWidth }
    if (name == "border-spacing") { return PropertyIdTag.BorderSpacing }

    // 逻辑边框
    if (name == "border-block") { return PropertyIdTag.BorderBlock }
    if (name == "border-block-start") { return PropertyIdTag.BorderBlockStart }
    if (name == "border-block-end") { return PropertyIdTag.BorderBlockEnd }
    if (name == "border-block-color") { return PropertyIdTag.BorderBlockColor }
    if (name == "border-block-style") { return PropertyIdTag.BorderBlockStyle }
    if (name == "border-block-width") { return PropertyIdTag.BorderBlockWidth }
    if (name == "border-inline") { return PropertyIdTag.BorderInline }
    if (name == "border-inline-start") { return PropertyIdTag.BorderInlineStart }
    if (name == "border-inline-end") { return PropertyIdTag.BorderInlineEnd }
    if (name == "border-inline-color") { return PropertyIdTag.BorderInlineColor }
    if (name == "border-inline-style") { return PropertyIdTag.BorderInlineStyle }
    if (name == "border-inline-width") { return PropertyIdTag.BorderInlineWidth }

    // 外边距
    if (name == "margin-top") { return PropertyIdTag.MarginTop }
    if (name == "margin-bottom") { return PropertyIdTag.MarginBottom }
    if (name == "margin-left") { return PropertyIdTag.MarginLeft }
    if (name == "margin-right") { return PropertyIdTag.MarginRight }
    if (name == "margin-block-start") { return PropertyIdTag.MarginBlockStart }
    if (name == "margin-block-end") { return PropertyIdTag.MarginBlockEnd }
    if (name == "margin-inline-start") { return PropertyIdTag.MarginInlineStart }
    if (name == "margin-inline-end") { return PropertyIdTag.MarginInlineEnd }
    if (name == "margin-block") { return PropertyIdTag.MarginBlock }
    if (name == "margin-inline") { return PropertyIdTag.MarginInline }

    // 内边距
    if (name == "padding-top") { return PropertyIdTag.PaddingTop }
    if (name == "padding-bottom") { return PropertyIdTag.PaddingBottom }
    if (name == "padding-left") { return PropertyIdTag.PaddingLeft }
    if (name == "padding-right") { return PropertyIdTag.PaddingRight }
    if (name == "padding-block-start") { return PropertyIdTag.PaddingBlockStart }
    if (name == "padding-block-end") { return PropertyIdTag.PaddingBlockEnd }
    if (name == "padding-inline-start") { return PropertyIdTag.PaddingInlineStart }
    if (name == "padding-inline-end") { return PropertyIdTag.PaddingInlineEnd }
    if (name == "padding-block") { return PropertyIdTag.PaddingBlock }
    if (name == "padding-inline") { return PropertyIdTag.PaddingInline }

    // 滚动边距
    if (name == "scroll-margin") { return PropertyIdTag.ScrollMargin }
    if (name == "scroll-margin-top") { return PropertyIdTag.ScrollMarginTop }
    if (name == "scroll-margin-bottom") { return PropertyIdTag.ScrollMarginBottom }
    if (name == "scroll-margin-left") { return PropertyIdTag.ScrollMarginLeft }
    if (name == "scroll-margin-right") { return PropertyIdTag.ScrollMarginRight }
    if (name == "scroll-margin-block-start") { return PropertyIdTag.ScrollMarginBlockStart }
    if (name == "scroll-margin-block-end") { return PropertyIdTag.ScrollMarginBlockEnd }
    if (name == "scroll-margin-inline-start") { return PropertyIdTag.ScrollMarginInlineStart }
    if (name == "scroll-margin-inline-end") { return PropertyIdTag.ScrollMarginInlineEnd }
    if (name == "scroll-margin-block") { return PropertyIdTag.ScrollMarginBlock }
    if (name == "scroll-margin-inline") { return PropertyIdTag.ScrollMarginInline }

    // 滚动内边距
    if (name == "scroll-padding") { return PropertyIdTag.ScrollPadding }
    if (name == "scroll-padding-top") { return PropertyIdTag.ScrollPaddingTop }
    if (name == "scroll-padding-bottom") { return PropertyIdTag.ScrollPaddingBottom }
    if (name == "scroll-padding-left") { return PropertyIdTag.ScrollPaddingLeft }
    if (name == "scroll-padding-right") { return PropertyIdTag.ScrollPaddingRight }
    if (name == "scroll-padding-block-start") { return PropertyIdTag.ScrollPaddingBlockStart }
    if (name == "scroll-padding-block-end") { return PropertyIdTag.ScrollPaddingBlockEnd }
    if (name == "scroll-padding-inline-start") { return PropertyIdTag.ScrollPaddingInlineStart }
    if (name == "scroll-padding-inline-end") { return PropertyIdTag.ScrollPaddingInlineEnd }
    if (name == "scroll-padding-block") { return PropertyIdTag.ScrollPaddingBlock }
    if (name == "scroll-padding-inline") { return PropertyIdTag.ScrollPaddingInline }

    // 滚动吸附
    if (name == "scroll-snap-align") { return PropertyIdTag.ScrollSnapAlign }
    if (name == "scroll-snap-stop") { return PropertyIdTag.ScrollSnapStop }
    if (name == "scroll-snap-type") { return PropertyIdTag.ScrollSnapType }
    if (name == "scroll-behavior") { return PropertyIdTag.ScrollBehavior }
    if (name == "overscroll-behavior") { return PropertyIdTag.OverscrollBehavior }
    if (name == "overscroll-behavior-block") { return PropertyIdTag.OverscrollBehaviorBlock }
    if (name == "overscroll-behavior-inline") { return PropertyIdTag.OverscrollBehaviorInline }
    if (name == "overscroll-behavior-x") { return PropertyIdTag.OverscrollBehaviorX }
    if (name == "overscroll-behavior-y") { return PropertyIdTag.OverscrollBehaviorY }

    // 滚动条
    if (name == "scrollbar-color") { return PropertyIdTag.ScrollbarColor }
    if (name == "scrollbar-gutter") { return PropertyIdTag.ScrollbarGutter }
    if (name == "scrollbar-width") { return PropertyIdTag.ScrollbarWidth }

    // 列表
    if (name == "list-style") { return PropertyIdTag.ListStyle }
    if (name == "list-style-image") { return PropertyIdTag.ListStyleImage }
    if (name == "list-style-position") { return PropertyIdTag.ListStylePosition }
    if (name == "list-style-type") { return PropertyIdTag.ListStyleType }

    // 多列
    if (name == "columns") { return PropertyIdTag.Columns }
    if (name == "column-count") { return PropertyIdTag.ColumnCount }
    if (name == "column-fill") { return PropertyIdTag.ColumnFill }
    if (name == "column-rule") { return PropertyIdTag.ColumnRule }
    if (name == "column-rule-color") { return PropertyIdTag.ColumnRuleColor }
    if (name == "column-rule-style") { return PropertyIdTag.ColumnRuleStyle }
    if (name == "column-rule-width") { return PropertyIdTag.ColumnRuleWidth }
    if (name == "column-span") { return PropertyIdTag.ColumnSpan }
    if (name == "column-width") { return PropertyIdTag.ColumnWidth }

    // 表格
    if (name == "table-layout") { return PropertyIdTag.TableLayout }
    if (name == "border-collapse") { return PropertyIdTag.BorderCollapse }
    if (name == "caption-side") { return PropertyIdTag.CaptionSide }
    if (name == "empty-cells") { return PropertyIdTag.EmptyCells }

    // UI
    if (name == "cursor") { return PropertyIdTag.Cursor }
    if (name == "user-select") { return PropertyIdTag.UserSelect }
    if (name == "pointer-events") { return PropertyIdTag.PointerEvents }
    if (name == "touch-action") { return PropertyIdTag.TouchAction }
    if (name == "resize") { return PropertyIdTag.Resize }
    if (name == "appearance") { return PropertyIdTag.Appearance }
    if (name == "caret-color") { return PropertyIdTag.CaretColor }
    if (name == "caret-shape") { return PropertyIdTag.CaretShape }
    if (name == "caret") { return PropertyIdTag.Caret }
    if (name == "box-decoration-break") { return PropertyIdTag.BoxDecorationBreak }

    // 其他
    if (name == "z-index") { return PropertyIdTag.ZIndex }
    if (name == "zoom") { return PropertyIdTag.Zoom }
    if (name == "opacity") { return PropertyIdTag.Opacity }
    if (name == "visibility") { return PropertyIdTag.Visibility }
    if (name == "color-scheme") { return PropertyIdTag.ColorScheme }
    if (name == "forced-color-adjust") { return PropertyIdTag.ForcedColorAdjust }
    if (name == "isolation") { return PropertyIdTag.Isolation }
    if (name == "mix-blend-mode") { return PropertyIdTag.MixBlendMode }
    if (name == "object-fit") { return PropertyIdTag.ObjectFit }
    if (name == "object-position") { return PropertyIdTag.ObjectPosition }
    if (name == "filter") { return PropertyIdTag.Custom }
    if (name == "backdrop-filter") { return PropertyIdTag.BackdropFilter }
    if (name == "clip-path") { return PropertyIdTag.ClipPath }
    if (name == "contain") { return PropertyIdTag.Contain }
    if (name == "container") { return PropertyIdTag.Container }
    if (name == "container-name") { return PropertyIdTag.ContainerName }
    if (name == "container-type") { return PropertyIdTag.ContainerType }
    if (name == "content") { return PropertyIdTag.Content }
    if (name == "content-visibility") { return PropertyIdTag.ContentVisibility }
    if (name == "counter-increment") { return PropertyIdTag.CounterIncrement }
    if (name == "counter-reset") { return PropertyIdTag.CounterReset }
    if (name == "counter-set") { return PropertyIdTag.CounterSet }
    if (name == "quotes") { return PropertyIdTag.Quotes }
    if (name == "orphans") { return PropertyIdTag.Orphans }
    if (name == "widows") { return PropertyIdTag.Widows }
    if (name == "page-break-after") { return PropertyIdTag.PageBreakAfter }
    if (name == "page-break-before") { return PropertyIdTag.PageBreakBefore }
    if (name == "page-break-inside") { return PropertyIdTag.PageBreakInside }
    if (name == "image-rendering") { return PropertyIdTag.ImageRendering }
    if (name == "aspect-ratio") { return PropertyIdTag.AspectRatio }
    if (name == "float") { return PropertyIdTag.Float }
    if (name == "clear") { return PropertyIdTag.Clear }
    if (name == "outline-color") { return PropertyIdTag.OutlineColor }
    if (name == "outline-style") { return PropertyIdTag.OutlineStyle }
    if (name == "outline-width") { return PropertyIdTag.OutlineWidth }
    if (name == "outline-offset") { return PropertyIdTag.OutlineOffset }
    if (name == "overflow-anchor") { return PropertyIdTag.OverflowAnchor }
    if (name == "overflow-clip-margin") { return PropertyIdTag.OverflowClipMargin }
    if (name == "overflow-wrap") { return PropertyIdTag.OverflowWrap }
    if (name == "composes") { return PropertyIdTag.Composes }
    if (name == "all") { return PropertyIdTag.All }
    if (name == "inherit") { return PropertyIdTag.Inherit }
    if (name == "initial") { return PropertyIdTag.Initial }
    if (name == "unset") { return PropertyIdTag.Unset }
    if (name == "revert-layer") { return PropertyIdTag.RevertLayer }

    // 偏移路径
    if (name == "offset") { return PropertyIdTag.Offset }
    if (name == "offset-anchor") { return PropertyIdTag.OffsetAnchor }
    if (name == "offset-distance") { return PropertyIdTag.OffsetDistance }
    if (name == "offset-path") { return PropertyIdTag.OffsetPath }
    if (name == "offset-position") { return PropertyIdTag.OffsetPosition }
    if (name == "offset-rotate") { return PropertyIdTag.OffsetRotate }

    // 默认返回 Custom
    return PropertyIdTag.Custom
}

// ============================================================================
// PropertyIdTag -> CSS Name Helper
// 严格翻译自: property_id_mixin::to_css / PropertyId.name()
// ============================================================================

/// PropertyIdTag 的 CSS 名称转换辅助
/// 严格翻译自 PropertyId 的 name() 方法
public class PropertyIdTagHelper {
    /// 将 PropertyIdTag 转为 CSS 属性名
    /// 严格翻译自 property_id_mixin::to_css
    public static func toCssName(tag: PropertyIdTag): String {
        match (tag) {
            case PropertyIdTag.BackgroundColor => "background-color"
            case PropertyIdTag.BackgroundImage => "background-image"
            case PropertyIdTag.BackgroundPositionX => "background-position-x"
            case PropertyIdTag.BackgroundPositionY => "background-position-y"
            case PropertyIdTag.BackgroundPosition => "background-position"
            case PropertyIdTag.BackgroundSize => "background-size"
            case PropertyIdTag.BackgroundRepeat => "background-repeat"
            case PropertyIdTag.BackgroundAttachment => "background-attachment"
            case PropertyIdTag.BackgroundClip => "background-clip"
            case PropertyIdTag.BackgroundOrigin => "background-origin"
            case PropertyIdTag.Background => "background"
            case PropertyIdTag.BoxShadow => "box-shadow"
            case PropertyIdTag.Opacity => "opacity"
            case PropertyIdTag.Color => "color"
            case PropertyIdTag.Display => "display"
            case PropertyIdTag.Visibility => "visibility"
            case PropertyIdTag.Width => "width"
            case PropertyIdTag.Height => "height"
            case PropertyIdTag.MinWidth => "min-width"
            case PropertyIdTag.MinHeight => "min-height"
            case PropertyIdTag.MaxWidth => "max-width"
            case PropertyIdTag.MaxHeight => "max-height"
            case PropertyIdTag.BlockSize => "block-size"
            case PropertyIdTag.InlineSize => "inline-size"
            case PropertyIdTag.MinBlockSize => "min-block-size"
            case PropertyIdTag.MinInlineSize => "min-inline-size"
            case PropertyIdTag.MaxBlockSize => "max-block-size"
            case PropertyIdTag.MaxInlineSize => "max-inline-size"
            case PropertyIdTag.BoxSizing => "box-sizing"
            case PropertyIdTag.AspectRatio => "aspect-ratio"
            case PropertyIdTag.Overflow => "overflow"
            case PropertyIdTag.OverflowX => "overflow-x"
            case PropertyIdTag.OverflowY => "overflow-y"
            case PropertyIdTag.Position => "position"
            case PropertyIdTag.Top => "top"
            case PropertyIdTag.Bottom => "bottom"
            case PropertyIdTag.Left => "left"
            case PropertyIdTag.Right => "right"
            case PropertyIdTag.Inset => "inset"
            case PropertyIdTag.InsetBlock => "inset-block"
            case PropertyIdTag.InsetInline => "inset-inline"
            case PropertyIdTag.InsetBlockStart => "inset-block-start"
            case PropertyIdTag.InsetBlockEnd => "inset-block-end"
            case PropertyIdTag.InsetInlineStart => "inset-inline-start"
            case PropertyIdTag.InsetInlineEnd => "inset-inline-end"
            case PropertyIdTag.Border => "border"
            case PropertyIdTag.BorderTop => "border-top"
            case PropertyIdTag.BorderBottom => "border-bottom"
            case PropertyIdTag.BorderLeft => "border-left"
            case PropertyIdTag.BorderRight => "border-right"
            case PropertyIdTag.BorderColor => "border-color"
            case PropertyIdTag.BorderTopColor => "border-top-color"
            case PropertyIdTag.BorderBottomColor => "border-bottom-color"
            case PropertyIdTag.BorderLeftColor => "border-left-color"
            case PropertyIdTag.BorderRightColor => "border-right-color"
            case PropertyIdTag.BorderStyle => "border-style"
            case PropertyIdTag.BorderTopStyle => "border-top-style"
            case PropertyIdTag.BorderBottomStyle => "border-bottom-style"
            case PropertyIdTag.BorderLeftStyle => "border-left-style"
            case PropertyIdTag.BorderRightStyle => "border-right-style"
            case PropertyIdTag.BorderWidth => "border-width"
            case PropertyIdTag.BorderTopWidth => "border-top-width"
            case PropertyIdTag.BorderBottomWidth => "border-bottom-width"
            case PropertyIdTag.BorderLeftWidth => "border-left-width"
            case PropertyIdTag.BorderRightWidth => "border-right-width"
            case PropertyIdTag.BorderRadius => "border-radius"
            case PropertyIdTag.BorderTopLeftRadius => "border-top-left-radius"
            case PropertyIdTag.BorderTopRightRadius => "border-top-right-radius"
            case PropertyIdTag.BorderBottomLeftRadius => "border-bottom-left-radius"
            case PropertyIdTag.BorderBottomRightRadius => "border-bottom-right-radius"
            case PropertyIdTag.BorderStartStartRadius => "border-start-start-radius"
            case PropertyIdTag.BorderStartEndRadius => "border-start-end-radius"
            case PropertyIdTag.BorderEndStartRadius => "border-end-start-radius"
            case PropertyIdTag.BorderEndEndRadius => "border-end-end-radius"
            case PropertyIdTag.BorderImage => "border-image"
            case PropertyIdTag.BorderImageOutset => "border-image-outset"
            case PropertyIdTag.BorderImageRepeat => "border-image-repeat"
            case PropertyIdTag.BorderImageSlice => "border-image-slice"
            case PropertyIdTag.BorderImageSource => "border-image-source"
            case PropertyIdTag.BorderImageWidth => "border-image-width"
            case PropertyIdTag.BorderSpacing => "border-spacing"
            case PropertyIdTag.BorderBlock => "border-block"
            case PropertyIdTag.BorderBlockStart => "border-block-start"
            case PropertyIdTag.BorderBlockEnd => "border-block-end"
            case PropertyIdTag.BorderBlockColor => "border-block-color"
            case PropertyIdTag.BorderBlockStyle => "border-block-style"
            case PropertyIdTag.BorderBlockWidth => "border-block-width"
            case PropertyIdTag.BorderInline => "border-inline"
            case PropertyIdTag.BorderInlineStart => "border-inline-start"
            case PropertyIdTag.BorderInlineEnd => "border-inline-end"
            case PropertyIdTag.BorderInlineColor => "border-inline-color"
            case PropertyIdTag.BorderInlineStyle => "border-inline-style"
            case PropertyIdTag.BorderInlineWidth => "border-inline-width"
            case PropertyIdTag.Outline => "outline"
            case PropertyIdTag.OutlineColor => "outline-color"
            case PropertyIdTag.OutlineStyle => "outline-style"
            case PropertyIdTag.OutlineWidth => "outline-width"
            case PropertyIdTag.OutlineOffset => "outline-offset"
            case PropertyIdTag.Transform => "transform"
            case PropertyIdTag.TransformOrigin => "transform-origin"
            case PropertyIdTag.TransformStyle => "transform-style"
            case PropertyIdTag.TransformBox => "transform-box"
            case PropertyIdTag.Transition => "transition"
            case PropertyIdTag.TransitionProperty => "transition-property"
            case PropertyIdTag.TransitionDuration => "transition-duration"
            case PropertyIdTag.TransitionTimingFunction => "transition-timing-function"
            case PropertyIdTag.TransitionDelay => "transition-delay"
            case PropertyIdTag.Perspective => "perspective"
            case PropertyIdTag.PerspectiveOrigin => "perspective-origin"
            case PropertyIdTag.BackfaceVisibility => "backface-visibility"
            case PropertyIdTag.Translate => "translate"
            case PropertyIdTag.Rotate => "rotate"
            case PropertyIdTag.Scale => "scale"
            case PropertyIdTag.Animation => "animation"
            case PropertyIdTag.AnimationName => "animation-name"
            case PropertyIdTag.AnimationDuration => "animation-duration"
            case PropertyIdTag.AnimationTimingFunction => "animation-timing-function"
            case PropertyIdTag.AnimationDelay => "animation-delay"
            case PropertyIdTag.AnimationIterationCount => "animation-iteration-count"
            case PropertyIdTag.AnimationDirection => "animation-direction"
            case PropertyIdTag.AnimationFillMode => "animation-fill-mode"
            case PropertyIdTag.AnimationPlayState => "animation-play-state"
            case PropertyIdTag.AnimationComposition => "animation-composition"
            case PropertyIdTag.AnimationTimeline => "animation-timeline"
            case PropertyIdTag.Font => "font"
            case PropertyIdTag.FontFamily => "font-family"
            case PropertyIdTag.FontSize => "font-size"
            case PropertyIdTag.FontWeight => "font-weight"
            case PropertyIdTag.FontStyle => "font-style"
            case PropertyIdTag.FontStretch => "font-stretch"
            case PropertyIdTag.FontVariant => "font-variant"
            case PropertyIdTag.FontVariantCaps => "font-variant-caps"
            case PropertyIdTag.FontFeatureSettings => "font-feature-settings"
            case PropertyIdTag.FontKerning => "font-kerning"
            case PropertyIdTag.FontLanguageOverride => "font-language-override"
            case PropertyIdTag.FontOpticalSizing => "font-optical-sizing"
            case PropertyIdTag.FontPalette => "font-palette"
            case PropertyIdTag.LineHeight => "line-height"
            case PropertyIdTag.VerticalAlign => "vertical-align"
            case PropertyIdTag.Flex => "flex"
            case PropertyIdTag.FlexGrow => "flex-grow"
            case PropertyIdTag.FlexShrink => "flex-shrink"
            case PropertyIdTag.FlexBasis => "flex-basis"
            case PropertyIdTag.FlexDirection => "flex-direction"
            case PropertyIdTag.FlexWrap => "flex-wrap"
            case PropertyIdTag.FlexFlow => "flex-flow"
            case PropertyIdTag.Gap => "gap"
            case PropertyIdTag.RowGap => "row-gap"
            case PropertyIdTag.ColumnGap => "column-gap"
            case PropertyIdTag.Grid => "grid"
            case PropertyIdTag.GridArea => "grid-area"
            case PropertyIdTag.GridAutoColumns => "grid-auto-columns"
            case PropertyIdTag.GridAutoFlow => "grid-auto-flow"
            case PropertyIdTag.GridAutoRows => "grid-auto-rows"
            case PropertyIdTag.gridColumn => "grid-column"
            case PropertyIdTag.GridColumnEnd => "grid-column-end"
            case PropertyIdTag.GridColumnStart => "grid-column-start"
            case PropertyIdTag.GridRow => "grid-row"
            case PropertyIdTag.GridRowEnd => "grid-row-end"
            case PropertyIdTag.GridRowStart => "grid-row-start"
            case PropertyIdTag.GridTemplate => "grid-template"
            case PropertyIdTag.GridTemplateAreas => "grid-template-areas"
            case PropertyIdTag.GridTemplateColumns => "grid-template-columns"
            case PropertyIdTag.GridTemplateRows => "grid-template-rows"
            case PropertyIdTag.Order => "order"
            case PropertyIdTag.JustifyContent => "justify-content"
            case PropertyIdTag.JustifyItems => "justify-items"
            case PropertyIdTag.JustifySelf => "justify-self"
            case PropertyIdTag.AlignContent => "align-content"
            case PropertyIdTag.AlignItems => "align-items"
            case PropertyIdTag.AlignSelf => "align-self"
            case PropertyIdTag.PlaceContent => "place-content"
            case PropertyIdTag.PlaceItems => "place-items"
            case PropertyIdTag.PlaceSelf => "place-self"
            case PropertyIdTag.TextDecoration => "text-decoration"
            case PropertyIdTag.TextDecorationColor => "text-decoration-color"
            case PropertyIdTag.TextDecorationLine => "text-decoration-line"
            case PropertyIdTag.TextDecorationStyle => "text-decoration-style"
            case PropertyIdTag.TextDecorationThickness => "text-decoration-thickness"
            case PropertyIdTag.TextDecorationSkipInk => "text-decoration-skip-ink"
            case PropertyIdTag.TextEmphasis => "text-emphasis"
            case PropertyIdTag.TextEmphasisColor => "text-emphasis-color"
            case PropertyIdTag.TextEmphasisPosition => "text-emphasis-position"
            case PropertyIdTag.TextEmphasisStyle => "text-emphasis-style"
            case PropertyIdTag.TextShadow => "text-shadow"
            case PropertyIdTag.TextAlign => "text-align"
            case PropertyIdTag.TextAlignLast => "text-align-last"
            case PropertyIdTag.TextIndent => "text-indent"
            case PropertyIdTag.TextJustify => "text-justify"
            case PropertyIdTag.TextOverflow => "text-overflow"
            case PropertyIdTag.TextTransform => "text-transform"
            case PropertyIdTag.TextSizeAdjust => "text-size-adjust"
            case PropertyIdTag.TextUnderlineOffset => "text-underline-offset"
            case PropertyIdTag.TextUnderlinePosition => "text-underline-position"
            case PropertyIdTag.TextOrientation => "text-orientation"
            case PropertyIdTag.WhiteSpace => "white-space"
            case PropertyIdTag.WordBreak => "word-break"
            case PropertyIdTag.WordSpacing => "word-spacing"
            case PropertyIdTag.WordWrap => "word-wrap"
            case PropertyIdTag.OverflowWrap => "overflow-wrap"
            case PropertyIdTag.LetterSpacing => "letter-spacing"
            case PropertyIdTag.LineBreak => "line-break"
            case PropertyIdTag.Hyphens => "hyphens"
            case PropertyIdTag.Direction => "direction"
            case PropertyIdTag.UnicodeBidi => "unicode-bidi"
            case PropertyIdTag.WritingMode => "writing-mode"
            case PropertyIdTag.MarginTop => "margin-top"
            case PropertyIdTag.MarginBottom => "margin-bottom"
            case PropertyIdTag.MarginLeft => "margin-left"
            case PropertyIdTag.MarginRight => "margin-right"
            case PropertyIdTag.MarginBlockStart => "margin-block-start"
            case PropertyIdTag.MarginBlockEnd => "margin-block-end"
            case PropertyIdTag.MarginInlineStart => "margin-inline-start"
            case PropertyIdTag.MarginInlineEnd => "margin-inline-end"
            case PropertyIdTag.MarginBlock => "margin-block"
            case PropertyIdTag.MarginInline => "margin-inline"
            case PropertyIdTag.PaddingTop => "padding-top"
            case PropertyIdTag.PaddingBottom => "padding-bottom"
            case PropertyIdTag.PaddingLeft => "padding-left"
            case PropertyIdTag.PaddingRight => "padding-right"
            case PropertyIdTag.PaddingBlockStart => "padding-block-start"
            case PropertyIdTag.PaddingBlockEnd => "padding-block-end"
            case PropertyIdTag.PaddingInlineStart => "padding-inline-start"
            case PropertyIdTag.PaddingInlineEnd => "padding-inline-end"
            case PropertyIdTag.PaddingBlock => "padding-block"
            case PropertyIdTag.PaddingInline => "padding-inline"
            case PropertyIdTag.ScrollMargin => "scroll-margin"
            case PropertyIdTag.ScrollMarginTop => "scroll-margin-top"
            case PropertyIdTag.ScrollMarginBottom => "scroll-margin-bottom"
            case PropertyIdTag.ScrollMarginLeft => "scroll-margin-left"
            case PropertyIdTag.ScrollMarginRight => "scroll-margin-right"
            case PropertyIdTag.ScrollMarginBlockStart => "scroll-margin-block-start"
            case PropertyIdTag.ScrollMarginBlockEnd => "scroll-margin-block-end"
            case PropertyIdTag.ScrollMarginInlineStart => "scroll-margin-inline-start"
            case PropertyIdTag.ScrollMarginInlineEnd => "scroll-margin-inline-end"
            case PropertyIdTag.ScrollMarginBlock => "scroll-margin-block"
            case PropertyIdTag.ScrollMarginInline => "scroll-margin-inline"
            case PropertyIdTag.ScrollPadding => "scroll-padding"
            case PropertyIdTag.ScrollPaddingTop => "scroll-padding-top"
            case PropertyIdTag.ScrollPaddingBottom => "scroll-padding-bottom"
            case PropertyIdTag.ScrollPaddingLeft => "scroll-padding-left"
            case PropertyIdTag.ScrollPaddingRight => "scroll-padding-right"
            case PropertyIdTag.ScrollPaddingBlockStart => "scroll-padding-block-start"
            case PropertyIdTag.ScrollPaddingBlockEnd => "scroll-padding-block-end"
            case PropertyIdTag.ScrollPaddingInlineStart => "scroll-padding-inline-start"
            case PropertyIdTag.ScrollPaddingInlineEnd => "scroll-padding-inline-end"
            case PropertyIdTag.ScrollPaddingBlock => "scroll-padding-block"
            case PropertyIdTag.ScrollPaddingInline => "scroll-padding-inline"
            case PropertyIdTag.ScrollSnapAlign => "scroll-snap-align"
            case PropertyIdTag.ScrollSnapStop => "scroll-snap-stop"
            case PropertyIdTag.ScrollSnapType => "scroll-snap-type"
            case PropertyIdTag.ScrollBehavior => "scroll-behavior"
            case PropertyIdTag.OverscrollBehavior => "overscroll-behavior"
            case PropertyIdTag.OverscrollBehaviorBlock => "overscroll-behavior-block"
            case PropertyIdTag.OverscrollBehaviorInline => "overscroll-behavior-inline"
            case PropertyIdTag.OverscrollBehaviorX => "overscroll-behavior-x"
            case PropertyIdTag.OverscrollBehaviorY => "overscroll-behavior-y"
            case PropertyIdTag.ScrollbarColor => "scrollbar-color"
            case PropertyIdTag.ScrollbarGutter => "scrollbar-gutter"
            case PropertyIdTag.ScrollbarWidth => "scrollbar-width"
            case PropertyIdTag.ListStyle => "list-style"
            case PropertyIdTag.ListStyleImage => "list-style-image"
            case PropertyIdTag.ListStylePosition => "list-style-position"
            case PropertyIdTag.ListStyleType => "list-style-type"
            case PropertyIdTag.Columns => "columns"
            case PropertyIdTag.ColumnCount => "column-count"
            case PropertyIdTag.ColumnFill => "column-fill"
            case PropertyIdTag.ColumnRule => "column-rule"
            case PropertyIdTag.ColumnRuleColor => "column-rule-color"
            case PropertyIdTag.ColumnRuleStyle => "column-rule-style"
            case PropertyIdTag.ColumnRuleWidth => "column-rule-width"
            case PropertyIdTag.ColumnSpan => "column-span"
            case PropertyIdTag.ColumnWidth => "column-width"
            case PropertyIdTag.TableLayout => "table-layout"
            case PropertyIdTag.BorderCollapse => "border-collapse"
            case PropertyIdTag.CaptionSide => "caption-side"
            case PropertyIdTag.EmptyCells => "empty-cells"
            case PropertyIdTag.Cursor => "cursor"
            case PropertyIdTag.UserSelect => "user-select"
            case PropertyIdTag.PointerEvents => "pointer-events"
            case PropertyIdTag.TouchAction => "touch-action"
            case PropertyIdTag.Resize => "resize"
            case PropertyIdTag.Appearance => "appearance"
            case PropertyIdTag.CaretColor => "caret-color"
            case PropertyIdTag.CaretShape => "caret-shape"
            case PropertyIdTag.Caret => "caret"
            case PropertyIdTag.BoxDecorationBreak => "box-decoration-break"
            case PropertyIdTag.ZIndex => "z-index"
            case PropertyIdTag.Zoom => "zoom"
            case PropertyIdTag.ColorScheme => "color-scheme"
            case PropertyIdTag.ForcedColorAdjust => "forced-color-adjust"
            case PropertyIdTag.Isolation => "isolation"
            case PropertyIdTag.MixBlendMode => "mix-blend-mode"
            case PropertyIdTag.ObjectFit => "object-fit"
            case PropertyIdTag.ObjectPosition => "object-position"
            case PropertyIdTag.BackdropFilter => "backdrop-filter"
            case PropertyIdTag.ClipPath => "clip-path"
            case PropertyIdTag.Contain => "contain"
            case PropertyIdTag.Container => "container"
            case PropertyIdTag.ContainerName => "container-name"
            case PropertyIdTag.ContainerType => "container-type"
            case PropertyIdTag.Content => "content"
            case PropertyIdTag.ContentVisibility => "content-visibility"
            case PropertyIdTag.CounterIncrement => "counter-increment"
            case PropertyIdTag.CounterReset => "counter-reset"
            case PropertyIdTag.CounterSet => "counter-set"
            case PropertyIdTag.Quotes => "quotes"
            case PropertyIdTag.Orphans => "orphans"
            case PropertyIdTag.Widows => "widows"
            case PropertyIdTag.PageBreakAfter => "page-break-after"
            case PropertyIdTag.PageBreakBefore => "page-break-before"
            case PropertyIdTag.PageBreakInside => "page-break-inside"
            case PropertyIdTag.ImageRendering => "image-rendering"
            case PropertyIdTag.Float => "float"
            case PropertyIdTag.Clear => "clear"
            case PropertyIdTag.OverflowAnchor => "overflow-anchor"
            case PropertyIdTag.OverflowClipMargin => "overflow-clip-margin"
            case PropertyIdTag.Offset => "offset"
            case PropertyIdTag.OffsetAnchor => "offset-anchor"
            case PropertyIdTag.OffsetDistance => "offset-distance"
            case PropertyIdTag.OffsetPath => "offset-path"
            case PropertyIdTag.OffsetPosition => "offset-position"
            case PropertyIdTag.OffsetRotate => "offset-rotate"
            case PropertyIdTag.Composes => "composes"
            case PropertyIdTag.All => "all"
            case PropertyIdTag.Inherit => "inherit"
            case PropertyIdTag.Initial => "initial"
            case PropertyIdTag.Unset => "unset"
            case PropertyIdTag.RevertLayer => "revert-layer"
            case PropertyIdTag.Custom => "custom"
            case PropertyIdTag.Unparsed => "unparsed"
            case _ => "unknown"
        }
    }
}
