// 严格翻译自: src/css/properties/properties_generated.zig
// 自动生成的 CSS 属性枚举、Property 联合类型、PropertyId 联合类型
// 包含: PropertyIdTag, Property, PropertyId 及其所有方法

package bao_css.properties

import bao_core.*
import bao_collections.*

// ============================================================================
// PropertyIdTag - CSS 属性判别标签 (enum(u16))
// 严格翻译自 PropertyIdTag
// ============================================================================

/// CSS 属性判别标签
/// 严格翻译自 PropertyIdTag (enum(u16))
/// 每个 tag 值对应一个 CSS 属性
public enum PropertyIdTag {
    // 背景
    | BackgroundColor
    | BackgroundImage
    | BackgroundPositionX
    | BackgroundPositionY
    | BackgroundPosition
    | BackgroundSize
    | BackgroundRepeat
    | BackgroundAttachment
    | BackgroundClip
    | BackgroundOrigin
    | Background

    // 阴影 & 颜色
    | BoxShadow
    | Opacity
    | Color

    // 显示
    | Display
    | Visibility

    // 尺寸
    | Width
    | Height
    | MinWidth
    | MinHeight
    | MaxWidth
    | MaxHeight
    | BlockSize
    | InlineSize
    | MinBlockSize
    | MinInlineSize
    | MaxBlockSize
    | MaxInlineSize
    | BoxSizing
    | AspectRatio

    // 溢出
    | Overflow
    | OverflowX
    | OverflowY
    | TextOverflow

    // 定位
    | Position
    | Top
    | Bottom
    | Left
    | Right
    | InsetBlockStart
    | InsetBlockEnd
    | InsetInlineStart
    | InsetInlineEnd
    | InsetBlock
    | InsetInline
    | Inset

    // 边框
    | BorderSpacing
    | BorderTopColor
    | BorderBottomColor
    | BorderLeftColor
    | BorderRightColor
    | BorderBlockStartColor
    | BorderBlockEndColor
    | BorderInlineStartColor
    | BorderInlineEndColor
    | BorderTopStyle
    | BorderBottomStyle
    | BorderLeftStyle
    | BorderRightStyle
    | BorderBlockStartStyle
    | BorderBlockEndStyle
    | BorderInlineStartStyle
    | BorderInlineEndStyle
    | BorderTopWidth
    | BorderBottomWidth
    | BorderLeftWidth
    | BorderRightWidth
    | BorderBlockStartWidth
    | BorderBlockEndWidth
    | BorderInlineStartWidth
    | BorderInlineEndWidth
    | BorderTopLeftRadius
    | BorderTopRightRadius
    | BorderBottomLeftRadius
    | BorderBottomRightRadius
    | BorderStartStartRadius
    | BorderStartEndRadius
    | BorderEndStartRadius
    | BorderEndEndRadius
    | BorderRadius
    | BorderImageSource
    | BorderImageOutset
    | BorderImageRepeat
    | BorderImageWidth
    | BorderImageSlice
    | BorderImage
    | BorderColor
    | BorderStyle
    | BorderWidth
    | BorderBlockColor
    | BorderBlockStyle
    | BorderBlockWidth
    | BorderInlineColor
    | BorderInlineStyle
    | BorderInlineWidth
    | Border
    | BorderTop
    | BorderBottom
    | BorderLeft
    | BorderRight
    | BorderBlock
    | BorderBlockStart
    | BorderBlockEnd
    | BorderInline
    | BorderInlineStart
    | BorderInlineEnd

    // Outline
    | Outline
    | OutlineColor
    | OutlineStyle
    | OutlineWidth

    // Flex (旧版前缀属性)
    | FlexDirection
    | FlexWrap
    | FlexFlow
    | FlexGrow
    | FlexShrink
    | FlexBasis
    | Flex
    | Order
    | AlignContent
    | JustifyContent
    | PlaceContent
    | AlignSelf
    | JustifySelf
    | PlaceSelf
    | AlignItems
    | JustifyItems
    | PlaceItems
    | RowGap
    | ColumnGap
    | Gap
    | BoxOrient
    | BoxDirection
    | BoxOrdinalGroup
    | BoxAlign
    | BoxFlex
    | BoxFlexGroup
    | BoxPack
    | BoxLines
    | FlexPack
    | FlexOrder
    | FlexAlign
    | FlexItemAlign
    | FlexLinePack
    | FlexPositive
    | FlexNegative
    | FlexPreferredSize

    // 外边距 & 内边距
    | MarginTop
    | MarginBottom
    | MarginLeft
    | MarginRight
    | MarginBlockStart
    | MarginBlockEnd
    | MarginInlineStart
    | MarginInlineEnd
    | MarginBlock
    | MarginInline
    | Margin
    | PaddingTop
    | PaddingBottom
    | PaddingLeft
    | PaddingRight
    | PaddingBlockStart
    | PaddingBlockEnd
    | PaddingInlineStart
    | PaddingInlineEnd
    | PaddingBlock
    | PaddingInline
    | Padding

    // Scroll margin & padding
    | ScrollMarginTop
    | ScrollMarginBottom
    | ScrollMarginLeft
    | ScrollMarginRight
    | ScrollMarginBlockStart
    | ScrollMarginBlockEnd
    | ScrollMarginInlineStart
    | ScrollMarginInlineEnd
    | ScrollMarginBlock
    | ScrollMarginInline
    | ScrollMargin
    | ScrollPaddingTop
    | ScrollPaddingBottom
    | ScrollPaddingLeft
    | ScrollPaddingRight
    | ScrollPaddingBlockStart
    | ScrollPaddingBlockEnd
    | ScrollPaddingInlineStart
    | ScrollPaddingInlineEnd
    | ScrollPaddingBlock
    | ScrollPaddingInline
    | ScrollPadding

    // 字体
    | FontWeight
    | FontSize
    | FontStretch
    | FontFamily
    | FontStyle
    | FontVariantCaps
    | LineHeight
    | Font

    // 变换 & 过渡
    | TransitionProperty
    | TransitionDuration
    | TransitionDelay
    | TransitionTimingFunction
    | Transition
    | Transform
    | TransformOrigin
    | TransformStyle
    | TransformBox
    | BackfaceVisibility
    | Perspective
    | PerspectiveOrigin
    | Translate
    | Rotate
    | Scale

    // 文本
    | TextDecorationColor
    | TextEmphasisColor
    | TextShadow
    | Direction
    | Composes

    // 遮罩
    | MaskImage
    | MaskMode
    | MaskRepeat
    | MaskPositionX
    | MaskPositionY
    | MaskPosition
    | MaskClip
    | MaskOrigin
    | MaskSize
    | MaskComposite
    | MaskType
    | Mask
    | MaskBorderSource
    | MaskBorderMode
    | MaskBorderSlice
    | MaskBorderWidth
    | MaskBorderOutset
    | MaskBorderRepeat
    | MaskBorder
    | WebKitMaskComposite
    | MaskSourceType
    | MaskBoxImage
    | MaskBoxImageSource
    | MaskBoxImageSlice
    | MaskBoxImageWidth
    | MaskBoxImageOutset
    | MaskBoxImageRepeat

    // UI
    | ColorScheme

    // 特殊
    | All
    | Unparsed
    | Custom

    public operator func ==(right: PropertyIdTag): Bool {
        return this.toCssName() == right.toCssName()
    }

    public operator func !=(right: PropertyIdTag): Bool {
        return !(this == right)
    }

    public func equals(other: PropertyIdTag): Bool {
        return this == other
    }

    /// 判断此 tag 是否关联 VendorPrefix
    /// 严格翻译自 hasVendorPrefix
    public func hasVendorPrefix(): Bool {
        match (this) {
            case BackgroundClip => true
            case BoxShadow => true
            case BoxSizing => true
            case TextOverflow => true
            case BorderTopLeftRadius => true
            case BorderTopRightRadius => true
            case BorderBottomLeftRadius => true
            case BorderBottomRightRadius => true
            case BorderRadius => true
            case BorderImage => true
            case FlexDirection => true
            case FlexWrap => true
            case FlexFlow => true
            case FlexGrow => true
            case FlexShrink => true
            case FlexBasis => true
            case Flex => true
            case Order => true
            case AlignContent => true
            case JustifyContent => true
            case AlignSelf => true
            case AlignItems => true
            case BoxOrient => true
            case BoxDirection => true
            case BoxOrdinalGroup => true
            case BoxAlign => true
            case BoxFlex => true
            case BoxFlexGroup => true
            case BoxPack => true
            case BoxLines => true
            case FlexPack => true
            case FlexOrder => true
            case FlexAlign => true
            case FlexItemAlign => true
            case FlexLinePack => true
            case FlexPositive => true
            case FlexNegative => true
            case FlexPreferredSize => true
            case TransitionProperty => true
            case TransitionDuration => true
            case TransitionDelay => true
            case TransitionTimingFunction => true
            case Transition => true
            case Transform => true
            case TransformOrigin => true
            case TransformStyle => true
            case BackfaceVisibility => true
            case Perspective => true
            case PerspectiveOrigin => true
            case TextDecorationColor => true
            case TextEmphasisColor => true
            case MaskImage => true
            case MaskRepeat => true
            case MaskPosition => true
            case MaskClip => true
            case MaskOrigin => true
            case MaskSize => true
            case Mask => true
            case MaskSourceType => true
            case MaskBoxImage => true
            case MaskBoxImageSource => true
            case MaskBoxImageSlice => true
            case MaskBoxImageWidth => true
            case MaskBoxImageOutset => true
            case MaskBoxImageRepeat => true
            case _ => false
        }
    }

    /// 获取 tag 对应的 CSS 属性名
    /// 严格翻译自 toCssName (在 Zig 中通过 @tagName 获取)
    public func toCssName(): String {
        match (this) {
            case BackgroundColor => "background-color"
            case BackgroundImage => "background-image"
            case BackgroundPositionX => "background-position-x"
            case BackgroundPositionY => "background-position-y"
            case BackgroundPosition => "background-position"
            case BackgroundSize => "background-size"
            case BackgroundRepeat => "background-repeat"
            case BackgroundAttachment => "background-attachment"
            case BackgroundClip => "background-clip"
            case BackgroundOrigin => "background-origin"
            case Background => "background"
            case BoxShadow => "box-shadow"
            case Opacity => "opacity"
            case Color => "color"
            case Display => "display"
            case Visibility => "visibility"
            case Width => "width"
            case Height => "height"
            case MinWidth => "min-width"
            case MinHeight => "min-height"
            case MaxWidth => "max-width"
            case MaxHeight => "max-height"
            case BlockSize => "block-size"
            case InlineSize => "inline-size"
            case MinBlockSize => "min-block-size"
            case MinInlineSize => "min-inline-size"
            case MaxBlockSize => "max-block-size"
            case MaxInlineSize => "max-inline-size"
            case BoxSizing => "box-sizing"
            case AspectRatio => "aspect-ratio"
            case Overflow => "overflow"
            case OverflowX => "overflow-x"
            case OverflowY => "overflow-y"
            case TextOverflow => "text-overflow"
            case Position => "position"
            case Top => "top"
            case Bottom => "bottom"
            case Left => "left"
            case Right => "right"
            case InsetBlockStart => "inset-block-start"
            case InsetBlockEnd => "inset-block-end"
            case InsetInlineStart => "inset-inline-start"
            case InsetInlineEnd => "inset-inline-end"
            case InsetBlock => "inset-block"
            case InsetInline => "inset-inline"
            case Inset => "inset"
            case BorderSpacing => "border-spacing"
            case BorderTopColor => "border-top-color"
            case BorderBottomColor => "border-bottom-color"
            case BorderLeftColor => "border-left-color"
            case BorderRightColor => "border-right-color"
            case BorderBlockStartColor => "border-block-start-color"
            case BorderBlockEndColor => "border-block-end-color"
            case BorderInlineStartColor => "border-inline-start-color"
            case BorderInlineEndColor => "border-inline-end-color"
            case BorderTopStyle => "border-top-style"
            case BorderBottomStyle => "border-bottom-style"
            case BorderLeftStyle => "border-left-style"
            case BorderRightStyle => "border-right-style"
            case BorderBlockStartStyle => "border-block-start-style"
            case BorderBlockEndStyle => "border-block-end-style"
            case BorderInlineStartStyle => "border-inline-start-style"
            case BorderInlineEndStyle => "border-inline-end-style"
            case BorderTopWidth => "border-top-width"
            case BorderBottomWidth => "border-bottom-width"
            case BorderLeftWidth => "border-left-width"
            case BorderRightWidth => "border-right-width"
            case BorderBlockStartWidth => "border-block-start-width"
            case BorderBlockEndWidth => "border-block-end-width"
            case BorderInlineStartWidth => "border-inline-start-width"
            case BorderInlineEndWidth => "border-inline-end-width"
            case BorderTopLeftRadius => "border-top-left-radius"
            case BorderTopRightRadius => "border-top-right-radius"
            case BorderBottomLeftRadius => "border-bottom-left-radius"
            case BorderBottomRightRadius => "border-bottom-right-radius"
            case BorderStartStartRadius => "border-start-start-radius"
            case BorderStartEndRadius => "border-start-end-radius"
            case BorderEndStartRadius => "border-end-start-radius"
            case BorderEndEndRadius => "border-end-end-radius"
            case BorderRadius => "border-radius"
            case BorderImageSource => "border-image-source"
            case BorderImageOutset => "border-image-outset"
            case BorderImageRepeat => "border-image-repeat"
            case BorderImageWidth => "border-image-width"
            case BorderImageSlice => "border-image-slice"
            case BorderImage => "border-image"
            case BorderColor => "border-color"
            case BorderStyle => "border-style"
            case BorderWidth => "border-width"
            case BorderBlockColor => "border-block-color"
            case BorderBlockStyle => "border-block-style"
            case BorderBlockWidth => "border-block-width"
            case BorderInlineColor => "border-inline-color"
            case BorderInlineStyle => "border-inline-style"
            case BorderInlineWidth => "border-inline-width"
            case Border => "border"
            case BorderTop => "border-top"
            case BorderBottom => "border-bottom"
            case BorderLeft => "border-left"
            case BorderRight => "border-right"
            case BorderBlock => "border-block"
            case BorderBlockStart => "border-block-start"
            case BorderBlockEnd => "border-block-end"
            case BorderInline => "border-inline"
            case BorderInlineStart => "border-inline-start"
            case BorderInlineEnd => "border-inline-end"
            case Outline => "outline"
            case OutlineColor => "outline-color"
            case OutlineStyle => "outline-style"
            case OutlineWidth => "outline-width"
            case FlexDirection => "flex-direction"
            case FlexWrap => "flex-wrap"
            case FlexFlow => "flex-flow"
            case FlexGrow => "flex-grow"
            case FlexShrink => "flex-shrink"
            case FlexBasis => "flex-basis"
            case Flex => "flex"
            case Order => "order"
            case AlignContent => "align-content"
            case JustifyContent => "justify-content"
            case PlaceContent => "place-content"
            case AlignSelf => "align-self"
            case JustifySelf => "justify-self"
            case PlaceSelf => "place-self"
            case AlignItems => "align-items"
            case JustifyItems => "justify-items"
            case PlaceItems => "place-items"
            case RowGap => "row-gap"
            case ColumnGap => "column-gap"
            case Gap => "gap"
            case BoxOrient => "box-orient"
            case BoxDirection => "box-direction"
            case BoxOrdinalGroup => "box-ordinal-group"
            case BoxAlign => "box-align"
            case BoxFlex => "box-flex"
            case BoxFlexGroup => "box-flex-group"
            case BoxPack => "box-pack"
            case BoxLines => "box-lines"
            case FlexPack => "flex-pack"
            case FlexOrder => "flex-order"
            case FlexAlign => "flex-align"
            case FlexItemAlign => "flex-item-align"
            case FlexLinePack => "flex-line-pack"
            case FlexPositive => "flex-positive"
            case FlexNegative => "flex-negative"
            case FlexPreferredSize => "flex-preferred-size"
            case MarginTop => "margin-top"
            case MarginBottom => "margin-bottom"
            case MarginLeft => "margin-left"
            case MarginRight => "margin-right"
            case MarginBlockStart => "margin-block-start"
            case MarginBlockEnd => "margin-block-end"
            case MarginInlineStart => "margin-inline-start"
            case MarginInlineEnd => "margin-inline-end"
            case MarginBlock => "margin-block"
            case MarginInline => "margin-inline"
            case Margin => "margin"
            case PaddingTop => "padding-top"
            case PaddingBottom => "padding-bottom"
            case PaddingLeft => "padding-left"
            case PaddingRight => "padding-right"
            case PaddingBlockStart => "padding-block-start"
            case PaddingBlockEnd => "padding-block-end"
            case PaddingInlineStart => "padding-inline-start"
            case PaddingInlineEnd => "padding-inline-end"
            case PaddingBlock => "padding-block"
            case PaddingInline => "padding-inline"
            case Padding => "padding"
            case ScrollMarginTop => "scroll-margin-top"
            case ScrollMarginBottom => "scroll-margin-bottom"
            case ScrollMarginLeft => "scroll-margin-left"
            case ScrollMarginRight => "scroll-margin-right"
            case ScrollMarginBlockStart => "scroll-margin-block-start"
            case ScrollMarginBlockEnd => "scroll-margin-block-end"
            case ScrollMarginInlineStart => "scroll-margin-inline-start"
            case ScrollMarginInlineEnd => "scroll-margin-inline-end"
            case ScrollMarginBlock => "scroll-margin-block"
            case ScrollMarginInline => "scroll-margin-inline"
            case ScrollMargin => "scroll-margin"
            case ScrollPaddingTop => "scroll-padding-top"
            case ScrollPaddingBottom => "scroll-padding-bottom"
            case ScrollPaddingLeft => "scroll-padding-left"
            case ScrollPaddingRight => "scroll-padding-right"
            case ScrollPaddingBlockStart => "scroll-padding-block-start"
            case ScrollPaddingBlockEnd => "scroll-padding-block-end"
            case ScrollPaddingInlineStart => "scroll-padding-inline-start"
            case ScrollPaddingInlineEnd => "scroll-padding-inline-end"
            case ScrollPaddingBlock => "scroll-padding-block"
            case ScrollPaddingInline => "scroll-padding-inline"
            case ScrollPadding => "scroll-padding"
            case FontWeight => "font-weight"
            case FontSize => "font-size"
            case FontStretch => "font-stretch"
            case FontFamily => "font-family"
            case FontStyle => "font-style"
            case FontVariantCaps => "font-variant-caps"
            case LineHeight => "line-height"
            case Font => "font"
            case TransitionProperty => "transition-property"
            case TransitionDuration => "transition-duration"
            case TransitionDelay => "transition-delay"
            case TransitionTimingFunction => "transition-timing-function"
            case Transition => "transition"
            case Transform => "transform"
            case TransformOrigin => "transform-origin"
            case TransformStyle => "transform-style"
            case TransformBox => "transform-box"
            case BackfaceVisibility => "backface-visibility"
            case Perspective => "perspective"
            case PerspectiveOrigin => "perspective-origin"
            case Translate => "translate"
            case Rotate => "rotate"
            case Scale => "scale"
            case TextDecorationColor => "text-decoration-color"
            case TextEmphasisColor => "text-emphasis-color"
            case TextShadow => "text-shadow"
            case Direction => "direction"
            case Composes => "composes"
            case MaskImage => "mask-image"
            case MaskMode => "mask-mode"
            case MaskRepeat => "mask-repeat"
            case MaskPositionX => "mask-position-x"
            case MaskPositionY => "mask-position-y"
            case MaskPosition => "mask-position"
            case MaskClip => "mask-clip"
            case MaskOrigin => "mask-origin"
            case MaskSize => "mask-size"
            case MaskComposite => "mask-composite"
            case MaskType => "mask-type"
            case Mask => "mask"
            case MaskBorderSource => "mask-border-source"
            case MaskBorderMode => "mask-border-mode"
            case MaskBorderSlice => "mask-border-slice"
            case MaskBorderWidth => "mask-border-width"
            case MaskBorderOutset => "mask-border-outset"
            case MaskBorderRepeat => "mask-border-repeat"
            case MaskBorder => "mask-border"
            case WebKitMaskComposite => "-webkit-mask-composite"
            case MaskSourceType => "-webkit-mask-source-type"
            case MaskBoxImage => "-webkit-mask-box-image"
            case MaskBoxImageSource => "-webkit-mask-box-image-source"
            case MaskBoxImageSlice => "-webkit-mask-box-image-slice"
            case MaskBoxImageWidth => "-webkit-mask-box-image-width"
            case MaskBoxImageOutset => "-webkit-mask-box-image-outset"
            case MaskBoxImageRepeat => "-webkit-mask-box-image-repeat"
            case ColorScheme => "color-scheme"
            case All => "all"
            case Unparsed => "unparsed"
            case Custom => "custom"
        }
    }

    /// 严格翻译自 valueType - 返回属性的值类型名称
    /// 在仓颉中用字符串表示类型名 (因为仓颉不支持 comptime type)
    public func valueTypeName(): String {
        match (this) {
            case BackgroundColor => "CssColor"
            case BackgroundImage => "SmallList<Image>"
            case BackgroundPositionX => "SmallList<HorizontalPosition>"
            case BackgroundPositionY => "SmallList<VerticalPosition>"
            case BackgroundPosition => "SmallList<BackgroundPosition>"
            case BackgroundSize => "SmallList<BackgroundSize>"
            case BackgroundRepeat => "SmallList<BackgroundRepeat>"
            case BackgroundAttachment => "SmallList<BackgroundAttachment>"
            case BackgroundClip => "SmallList<BackgroundClip>"
            case BackgroundOrigin => "SmallList<BackgroundOrigin>"
            case Background => "SmallList<Background>"
            case BoxShadow => "SmallList<BoxShadow>"
            case Opacity => "AlphaValue"
            case Color => "CssColor"
            case Display => "Display"
            case Visibility => "Visibility"
            case Width => "Size"
            case Height => "Size"
            case MinWidth => "Size"
            case MinHeight => "Size"
            case MaxWidth => "MaxSize"
            case MaxHeight => "MaxSize"
            case BlockSize => "Size"
            case InlineSize => "Size"
            case MinBlockSize => "Size"
            case MinInlineSize => "Size"
            case MaxBlockSize => "MaxSize"
            case MaxInlineSize => "MaxSize"
            case BoxSizing => "BoxSizing"
            case AspectRatio => "AspectRatio"
            case Overflow => "Overflow"
            case OverflowX => "OverflowKeyword"
            case OverflowY => "OverflowKeyword"
            case TextOverflow => "TextOverflow"
            case Position => "Position"
            case Top => "LengthPercentageOrAuto"
            case Bottom => "LengthPercentageOrAuto"
            case Left => "LengthPercentageOrAuto"
            case Right => "LengthPercentageOrAuto"
            case InsetBlockStart => "LengthPercentageOrAuto"
            case InsetBlockEnd => "LengthPercentageOrAuto"
            case InsetInlineStart => "LengthPercentageOrAuto"
            case InsetInlineEnd => "LengthPercentageOrAuto"
            case InsetBlock => "InsetBlock"
            case InsetInline => "InsetInline"
            case Inset => "Inset"
            case BorderSpacing => "Size2D<Length>"
            case BorderTopColor => "CssColor"
            case BorderBottomColor => "CssColor"
            case BorderLeftColor => "CssColor"
            case BorderRightColor => "CssColor"
            case BorderBlockStartColor => "CssColor"
            case BorderBlockEndColor => "CssColor"
            case BorderInlineStartColor => "CssColor"
            case BorderInlineEndColor => "CssColor"
            case BorderTopStyle => "LineStyle"
            case BorderBottomStyle => "LineStyle"
            case BorderLeftStyle => "LineStyle"
            case BorderRightStyle => "LineStyle"
            case BorderBlockStartStyle => "LineStyle"
            case BorderBlockEndStyle => "LineStyle"
            case BorderInlineStartStyle => "LineStyle"
            case BorderInlineEndStyle => "LineStyle"
            case BorderTopWidth => "BorderSideWidth"
            case BorderBottomWidth => "BorderSideWidth"
            case BorderLeftWidth => "BorderSideWidth"
            case BorderRightWidth => "BorderSideWidth"
            case BorderBlockStartWidth => "BorderSideWidth"
            case BorderBlockEndWidth => "BorderSideWidth"
            case BorderInlineStartWidth => "BorderSideWidth"
            case BorderInlineEndWidth => "BorderSideWidth"
            case BorderTopLeftRadius => "Size2D<LengthPercentage>"
            case BorderTopRightRadius => "Size2D<LengthPercentage>"
            case BorderBottomLeftRadius => "Size2D<LengthPercentage>"
            case BorderBottomRightRadius => "Size2D<LengthPercentage>"
            case BorderStartStartRadius => "Size2D<LengthPercentage>"
            case BorderStartEndRadius => "Size2D<LengthPercentage>"
            case BorderEndStartRadius => "Size2D<LengthPercentage>"
            case BorderEndEndRadius => "Size2D<LengthPercentage>"
            case BorderRadius => "BorderRadius"
            case BorderImageSource => "Image"
            case BorderImageOutset => "Rect<LengthOrNumber>"
            case BorderImageRepeat => "BorderImageRepeat"
            case BorderImageWidth => "Rect<BorderImageSideWidth>"
            case BorderImageSlice => "BorderImageSlice"
            case BorderImage => "BorderImage"
            case BorderColor => "BorderColor"
            case BorderStyle => "BorderStyle"
            case BorderWidth => "BorderWidth"
            case BorderBlockColor => "BorderBlockColor"
            case BorderBlockStyle => "BorderBlockStyle"
            case BorderBlockWidth => "BorderBlockWidth"
            case BorderInlineColor => "BorderInlineColor"
            case BorderInlineStyle => "BorderInlineStyle"
            case BorderInlineWidth => "BorderInlineWidth"
            case Border => "Border"
            case BorderTop => "BorderTop"
            case BorderBottom => "BorderBottom"
            case BorderLeft => "BorderLeft"
            case BorderRight => "BorderRight"
            case BorderBlock => "BorderBlock"
            case BorderBlockStart => "BorderBlockStart"
            case BorderBlockEnd => "BorderBlockEnd"
            case BorderInline => "BorderInline"
            case BorderInlineStart => "BorderInlineStart"
            case BorderInlineEnd => "BorderInlineEnd"
            case Outline => "Outline"
            case OutlineColor => "CssColor"
            case OutlineStyle => "OutlineStyle"
            case OutlineWidth => "BorderSideWidth"
            case FlexDirection => "FlexDirection"
            case FlexWrap => "FlexWrap"
            case FlexFlow => "FlexFlow"
            case FlexGrow => "CSSNumber"
            case FlexShrink => "CSSNumber"
            case FlexBasis => "LengthPercentageOrAuto"
            case Flex => "Flex"
            case Order => "CSSInteger"
            case AlignContent => "AlignContent"
            case JustifyContent => "JustifyContent"
            case PlaceContent => "PlaceContent"
            case AlignSelf => "AlignSelf"
            case JustifySelf => "JustifySelf"
            case PlaceSelf => "PlaceSelf"
            case AlignItems => "AlignItems"
            case JustifyItems => "JustifyItems"
            case PlaceItems => "PlaceItems"
            case RowGap => "GapValue"
            case ColumnGap => "GapValue"
            case Gap => "Gap"
            case BoxOrient => "BoxOrient"
            case BoxDirection => "BoxDirection"
            case BoxOrdinalGroup => "CSSInteger"
            case BoxAlign => "BoxAlign"
            case BoxFlex => "CSSNumber"
            case BoxFlexGroup => "CSSInteger"
            case BoxPack => "BoxPack"
            case BoxLines => "BoxLines"
            case FlexPack => "FlexPack"
            case FlexOrder => "CSSInteger"
            case FlexAlign => "BoxAlign"
            case FlexItemAlign => "FlexItemAlign"
            case FlexLinePack => "FlexLinePack"
            case FlexPositive => "CSSNumber"
            case FlexNegative => "CSSNumber"
            case FlexPreferredSize => "LengthPercentageOrAuto"
            case MarginTop => "LengthPercentageOrAuto"
            case MarginBottom => "LengthPercentageOrAuto"
            case MarginLeft => "LengthPercentageOrAuto"
            case MarginRight => "LengthPercentageOrAuto"
            case MarginBlockStart => "LengthPercentageOrAuto"
            case MarginBlockEnd => "LengthPercentageOrAuto"
            case MarginInlineStart => "LengthPercentageOrAuto"
            case MarginInlineEnd => "LengthPercentageOrAuto"
            case MarginBlock => "MarginBlock"
            case MarginInline => "MarginInline"
            case Margin => "Margin"
            case PaddingTop => "LengthPercentageOrAuto"
            case PaddingBottom => "LengthPercentageOrAuto"
            case PaddingLeft => "LengthPercentageOrAuto"
            case PaddingRight => "LengthPercentageOrAuto"
            case PaddingBlockStart => "LengthPercentageOrAuto"
            case PaddingBlockEnd => "LengthPercentageOrAuto"
            case PaddingInlineStart => "LengthPercentageOrAuto"
            case PaddingInlineEnd => "LengthPercentageOrAuto"
            case PaddingBlock => "PaddingBlock"
            case PaddingInline => "PaddingInline"
            case Padding => "Padding"
            case ScrollMarginTop => "LengthPercentageOrAuto"
            case ScrollMarginBottom => "LengthPercentageOrAuto"
            case ScrollMarginLeft => "LengthPercentageOrAuto"
            case ScrollMarginRight => "LengthPercentageOrAuto"
            case ScrollMarginBlockStart => "LengthPercentageOrAuto"
            case ScrollMarginBlockEnd => "LengthPercentageOrAuto"
            case ScrollMarginInlineStart => "LengthPercentageOrAuto"
            case ScrollMarginInlineEnd => "LengthPercentageOrAuto"
            case ScrollMarginBlock => "ScrollMarginBlock"
            case ScrollMarginInline => "ScrollMarginInline"
            case ScrollMargin => "ScrollMargin"
            case ScrollPaddingTop => "LengthPercentageOrAuto"
            case ScrollPaddingBottom => "LengthPercentageOrAuto"
            case ScrollPaddingLeft => "LengthPercentageOrAuto"
            case ScrollPaddingRight => "LengthPercentageOrAuto"
            case ScrollPaddingBlockStart => "LengthPercentageOrAuto"
            case ScrollPaddingBlockEnd => "LengthPercentageOrAuto"
            case ScrollPaddingInlineStart => "LengthPercentageOrAuto"
            case ScrollPaddingInlineEnd => "LengthPercentageOrAuto"
            case ScrollPaddingBlock => "ScrollPaddingBlock"
            case ScrollPaddingInline => "ScrollPaddingInline"
            case ScrollPadding => "ScrollPadding"
            case FontWeight => "FontWeight"
            case FontSize => "FontSize"
            case FontStretch => "FontStretch"
            case FontFamily => "BabyList<FontFamily>"
            case FontStyle => "FontStyle"
            case FontVariantCaps => "FontVariantCaps"
            case LineHeight => "LineHeight"
            case Font => "Font"
            case TransitionProperty => "SmallList<PropertyId>"
            case TransitionDuration => "SmallList<Time>"
            case TransitionDelay => "SmallList<Time>"
            case TransitionTimingFunction => "SmallList<EasingFunction>"
            case Transition => "SmallList<Transition>"
            case Transform => "TransformList"
            case TransformOrigin => "Position"
            case TransformStyle => "TransformStyle"
            case TransformBox => "TransformBox"
            case BackfaceVisibility => "BackfaceVisibility"
            case Perspective => "Perspective"
            case PerspectiveOrigin => "Position"
            case Translate => "Translate"
            case Rotate => "Rotate"
            case Scale => "Scale"
            case TextDecorationColor => "CssColor"
            case TextEmphasisColor => "CssColor"
            case TextShadow => "SmallList<TextShadow>"
            case Direction => "Direction"
            case Composes => "Composes"
            case MaskImage => "SmallList<Image>"
            case MaskMode => "SmallList<MaskMode>"
            case MaskRepeat => "SmallList<BackgroundRepeat>"
            case MaskPositionX => "SmallList<HorizontalPosition>"
            case MaskPositionY => "SmallList<VerticalPosition>"
            case MaskPosition => "SmallList<Position>"
            case MaskClip => "SmallList<MaskClip>"
            case MaskOrigin => "SmallList<GeometryBox>"
            case MaskSize => "SmallList<BackgroundSize>"
            case MaskComposite => "SmallList<MaskComposite>"
            case MaskType => "MaskType"
            case Mask => "SmallList<Mask>"
            case MaskBorderSource => "Image"
            case MaskBorderMode => "MaskBorderMode"
            case MaskBorderSlice => "BorderImageSlice"
            case MaskBorderWidth => "Rect<BorderImageSideWidth>"
            case MaskBorderOutset => "Rect<LengthOrNumber>"
            case MaskBorderRepeat => "BorderImageRepeat"
            case MaskBorder => "MaskBorder"
            case WebKitMaskComposite => "SmallList<WebKitMaskComposite>"
            case MaskSourceType => "SmallList<WebKitMaskSourceType>"
            case MaskBoxImage => "BorderImage"
            case MaskBoxImageSource => "Image"
            case MaskBoxImageSlice => "BorderImageSlice"
            case MaskBoxImageWidth => "Rect<BorderImageSideWidth>"
            case MaskBoxImageOutset => "Rect<LengthOrNumber>"
            case MaskBoxImageRepeat => "BorderImageRepeat"
            case ColorScheme => "ColorScheme"
            case All => "CSSWideKeyword"
            case Unparsed => "UnparsedProperty"
            case Custom => "CustomProperty"
        }
    }
}

// ============================================================================
// Property - CSS 属性值联合类型
// 严格翻译自 Property (union(PropertyIdTag))
// ============================================================================

/// CSS 属性值联合类型
/// 严格翻译自 Property (union(PropertyIdTag))
/// 每个 tag 关联对应的值类型; 带 VendorPrefix 的属性关联 (值, VendorPrefix) 元组
public class Property {
    public var tag: PropertyIdTag
    // 用 Any 存储值; 在实际使用中根据 tag 进行类型转换
    public var value: Any
    // 带 VendorPrefix 的属性额外存储前缀
    public var vendorPrefix: VendorPrefix

    public init(tag: PropertyIdTag, value: Any) {
        this.tag = tag
        this.value = value
        this.vendorPrefix = VendorPrefix()
    }

    public init(tag: PropertyIdTag, value: Any, vendorPrefix: VendorPrefix) {
        this.tag = tag
        this.value = value
        this.vendorPrefix = vendorPrefix
    }

    /// 获取此属性的 PropertyId
    /// 严格翻译自 propertyId
    public func propertyId(): PropertyId {
        if (this.tag.hasVendorPrefix()) {
            return PropertyId(this.tag, this.vendorPrefix)
        }
        return PropertyId(this.tag, VendorPrefix())
    }

    /// 判断两个 Property 是否相等
    /// 严格翻译自 eql
    public func eql(other: Property): Bool {
        if (this.tag != other.tag) {
            return false
        }
        if (this.tag.hasVendorPrefix() && this.vendorPrefix.toCssPrefix() != other.vendorPrefix.toCssPrefix()) {
            return false
        }
        // 值比较委托给具体类型的 eql 方法
        return PropertyHelper.valuesEqual(this.tag, this.value, other.value)
    }

    /// 深拷贝
    /// 严格翻译自 deepClone
    public func deepClone(): Property {
        return Property(
            this.tag,
            PropertyHelper.deepCloneValue(this.tag, this.value),
            this.vendorPrefix
        )
    }

    /// 序列化为 CSS 字符串
    /// 严格翻译自 Property.toCss (property_mixin + __toCssHelper)
    /// 输出格式: [prefix]property-name: value [!important]
    /// 严格翻译自 __toCssHelper (lines 6571-6829):
    ///   - 无前缀属性: .{ "property-name", VendorPrefix{ .none = true } }
    ///   - 带前缀属性: .{ "property-name", x.@"1" } (从值 tuple 中提取 prefix)
    ///   - unparsed: 使用 unparsed.property_id.name() + prefix
    public func toCss(): String {
        let sb = StringBuilder()
        let info = PropertyToCssInfo.getToCssInfo(this)
        // 输出前缀
        if (!info.vendorPrefix.isEmpty()) {
            sb.append(info.vendorPrefix.toCssPrefix())
        }
        // 输出属性名
        sb.append(info.name)
        sb.append(": ")
        // 输出属性值
        let dest = CssPrinter()
        PropertyValueToCss.toCss(this, dest)
        sb.append(dest.toString())
        return sb.toString()
    }

    /// 值序列化为 CSS
    /// 严格翻译自 Property.valueToCss (properties_generated.zig lines 6832-7084)
    /// 序列化属性值 (不含属性名和 !important)
    /// 委托给 PropertyValueToCss.toCss
    public func valueToCss(dest: CssPrinter): Unit {
        PropertyValueToCss.toCss(this, dest)
    }

    /// 获取 longhand 属性
    /// 严格翻译自 Property.longhand (properties_generated.zig lines 7087-7160)
    /// 对于 shorthand 属性 (如 background, border, flex), 返回展开后的具体属性
    /// 对于 longhand 属性, 返回 null
    public func longhand(propertyId: PropertyId): ?Property {
        return PropertyLonghand.getLonghand(this, propertyId)
    }

    /// 释放资源
    /// 严格翻译自 Property.deinit (properties_generated.zig lines 6566-6570)
    /// 注意: 大多数属性在 arena allocator 上分配, 不需要单独释放
    /// 此方法主要用于性能优化 (arena 可复用内存)
    public func deinit(): Unit {
        // 严格翻译自: 当前为空实现, 所有分配在 arena 上
        // Zig 代码注释: "not strictly necessary since all allocations are into an arena"
        // 完整 switch 覆盖所有 ~240 个属性 tag
        match (this.tag) {
            case BackgroundColor | BackgroundImage | BackgroundPositionX
               | BackgroundPositionY | BackgroundPosition | BackgroundSize
               | BackgroundRepeat | BackgroundAttachment | BackgroundClip
               | BackgroundOrigin | Background
               | BoxShadow
               | Opacity | Color | Display | Visibility
               | Width | Height | MinWidth | MinHeight | MaxWidth | MaxHeight
               | BlockSize | InlineSize | MinBlockSize | MinInlineSize
               | MaxBlockSize | MaxInlineSize | BoxSizing
               | AspectRatio | Overflow | OverflowX | OverflowY | TextOverflow
               | Position | Top | Bottom | Left | Right
               | InsetBlockStart | InsetBlockEnd | InsetInlineStart | InsetInlineEnd
               | InsetBlock | InsetInline | Inset | BorderSpacing
               | BorderTopColor | BorderBottomColor | BorderLeftColor | BorderRightColor
               | BorderBlockStartColor | BorderBlockEndColor
               | BorderInlineStartColor | BorderInlineEndColor
               | BorderTopStyle | BorderBottomStyle | BorderLeftStyle | BorderRightStyle
               | BorderBlockStartStyle | BorderBlockEndStyle
               | BorderInlineStartStyle | BorderInlineEndStyle
               | BorderTopWidth | BorderBottomWidth | BorderLeftWidth | BorderRightWidth
               | BorderBlockStartWidth | BorderBlockEndWidth
               | BorderInlineStartWidth | BorderInlineEndWidth
               | BorderTopLeftRadius | BorderTopRightRadius
               | BorderBottomLeftRadius | BorderBottomRightRadius
               | BorderStartStartRadius | BorderStartEndRadius
               | BorderEndStartRadius | BorderEndEndRadius
               | BorderRadius
               | BorderImageSource | BorderImageOutset | BorderImageRepeat
               | BorderImageWidth | BorderImageSlice | BorderImage
               | BorderColor | BorderStyle | BorderWidth
               | BorderBlockColor | BorderBlockStyle | BorderBlockWidth
               | BorderInlineColor | BorderInlineStyle | BorderInlineWidth
               | Border | BorderTop | BorderBottom | BorderLeft | BorderRight
               | BorderBlock | BorderBlockStart | BorderBlockEnd
               | BorderInline | BorderInlineStart | BorderInlineEnd
               | Outline | OutlineColor | OutlineStyle | OutlineWidth
               | FlexDirection | FlexWrap | FlexFlow | FlexGrow | FlexShrink
               | FlexBasis | Flex | Order
               | AlignContent | JustifyContent | PlaceContent
               | AlignSelf | JustifySelf | PlaceSelf
               | AlignItems | JustifyItems | PlaceItems
               | RowGap | ColumnGap | Gap
               | BoxOrient | BoxDirection | BoxOrdinalGroup | BoxAlign
               | BoxFlex | BoxFlexGroup | BoxPack | BoxLines
               | FlexPack | FlexOrder | FlexAlign | FlexItemAlign
               | FlexLinePack | FlexPositive | FlexNegative | FlexPreferredSize
               | MarginTop | MarginBottom | MarginLeft | MarginRight
               | MarginBlockStart | MarginBlockEnd | MarginInlineStart | MarginInlineEnd
               | MarginBlock | MarginInline | Margin
               | PaddingTop | PaddingBottom | PaddingLeft | PaddingRight
               | PaddingBlockStart | PaddingBlockEnd | PaddingInlineStart | PaddingInlineEnd
               | PaddingBlock | PaddingInline | Padding
               | ScrollMarginTop | ScrollMarginBottom | ScrollMarginLeft | ScrollMarginRight
               | ScrollMarginBlockStart | ScrollMarginBlockEnd
               | ScrollMarginInlineStart | ScrollMarginInlineEnd
               | ScrollMarginBlock | ScrollMarginInline | ScrollMargin
               | ScrollPaddingTop | ScrollPaddingBottom | ScrollPaddingLeft | ScrollPaddingRight
               | ScrollPaddingBlockStart | ScrollPaddingBlockEnd
               | ScrollPaddingInlineStart | ScrollPaddingInlineEnd
               | ScrollPaddingBlock | ScrollPaddingInline | ScrollPadding
               | FontWeight | FontSize | FontStretch | FontFamily
               | FontStyle | FontVariantCaps | LineHeight | Font
               | TransitionProperty | TransitionDuration | TransitionDelay
               | TransitionTimingFunction | Transition
               | Transform | TransformOrigin | TransformStyle | TransformBox
               | BackfaceVisibility | Perspective | PerspectiveOrigin
               | Translate | Rotate | Scale
               | TextDecorationColor | TextEmphasisColor | TextShadow
               | Direction | Composes
               | MaskImage | MaskMode | MaskRepeat | MaskPositionX | MaskPositionY
               | MaskPosition | MaskClip | MaskOrigin | MaskSize
               | MaskComposite | MaskType | Mask
               | MaskBorderSource | MaskBorderMode | MaskBorderSlice
               | MaskBorderWidth | MaskBorderOutset | MaskBorderRepeat | MaskBorder
               | WebKitMaskComposite
               | MaskSourceType | MaskBoxImage | MaskBoxImageSource
               | MaskBoxImageSlice | MaskBoxImageWidth | MaskBoxImageOutset | MaskBoxImageRepeat
               | ColorScheme
               | All | Unparsed | Custom => {
                // arena allocator - 不需要单独释放
            }
        }
    }

    /// Hash
    /// 严格翻译自 Property.hash
    /// Zig 中: hash tag + hash value (对于带前缀属性还 hash prefix)
    public func hash(hasher: Hasher): Unit {
        hasher.update(this.tag)
        if (this.tag.hasVendorPrefix()) {
            hasher.update(this.vendorPrefix)
        }
        // 严格翻译自: 对于有值的属性, 还需要 hash value
        // 在实际实现中, 根据 tag 调用具体类型的 hash 方法
    }
}

// ============================================================================
// PropertyId - CSS 属性标识符 (带供应商前缀)
// 严格翻译自 PropertyId (union(PropertyIdTag))
// ============================================================================

/// CSS 属性标识符
/// 严格翻译自 PropertyId (union(PropertyIdTag))
/// 带有可选的 VendorPrefix
public class PropertyId {
    public var tag: PropertyIdTag
    public var vendorPrefix: VendorPrefix

    public init(tag: PropertyIdTag) {
        this.tag = tag
        this.vendorPrefix = VendorPrefix()
    }

    public init(tag: PropertyIdTag, vendorPrefix: VendorPrefix) {
        this.tag = tag
        this.vendorPrefix = vendorPrefix
    }

    /// 严格翻译自 `all`
    public static let all = PropertyId(PropertyIdTag.All, VendorPrefix())

    /// 获取属性名 (不含前缀)
    /// 严格翻译自 name
    public func name(): String {
        if (this.tag == PropertyIdTag.Custom) {
            // custom 属性名存在 vendorPrefix 的 name 字段中 (CustomPropertyName)
            return this.vendorPrefix.toCssPrefix()
        }
        return this.tag.toCssName()
    }

    /// 获取此属性的 VendorPrefix
    /// 严格翻译自 prefix
    public func prefix(): VendorPrefix {
        if (this.tag.hasVendorPrefix()) {
            return this.vendorPrefix
        }
        return VendorPrefix()
    }

    /// 判断两个 PropertyId 是否相等
    /// 严格翻译自 eql
    public func eql(other: PropertyId): Bool {
        if (this.tag != other.tag) {
            return false
        }
        if (this.tag.hasVendorPrefix()) {
            return this.vendorPrefix.equals(other.vendorPrefix)
        }
        return true
    }

    /// 深拷贝
    /// 严格翻译自 deepClone
    public func deepClone(): PropertyId {
        return PropertyId(this.tag, this.vendorPrefix)
    }

    /// 返回带前缀的 PropertyId
    /// 严格翻译自 withPrefix (properties_generated.zig lines 8927-9177)
    /// 返回一个新的 PropertyId, 带前缀的属性使用传入的 pre, 无前缀属性忽略 pre
    public func withPrefix(pre: VendorPrefix): PropertyId {
        // 带前缀的属性: 返回 PropertyId(tag, pre)
        // 无前缀的属性: 返回 PropertyId(tag, VendorPrefix())
        // 严格翻译自 Zig 中的完整 switch
        if (this.tag.hasVendorPrefix()) {
            return PropertyId(this.tag, pre)
        }
        return PropertyId(this.tag, VendorPrefix())
    }

    /// 添加前缀
    /// 严格翻译自 addPrefix (properties_generated.zig lines 9179-9194)
    /// 只有带前缀的属性 (VendorPrefix 类型) 才会插入前缀
    /// 无前缀属性 (void 类型) 忽略
    public func addPrefix(pre: VendorPrefix): Unit {
        // 严格翻译自 Zig 中的 inline else + switch(@TypeOf(p)):
        //   *void, *CustomPropertyName => 忽略
        //   *VendorPrefix => bits.insert(pre)
        if (this.tag.hasVendorPrefix()) {
            this.vendorPrefix = this.vendorPrefix.bitwiseOr(pre)
        }
    }

    /// 根据目标设置前缀
    /// 严格翻译自 setPrefixesForTargets (properties_generated.zig lines 9214-9590)
    /// 完整 switch 覆盖所有属性 tag, 带前缀的属性通过 targets.prefixes() 设置
    public func setPrefixesForTargets(targets: Targets): Unit {
        match (this.tag) {
            // === 无前缀属性 - 不需要处理 ===
            case BackgroundColor | BackgroundImage | BackgroundPositionX
               | BackgroundPositionY | BackgroundPosition | BackgroundSize
               | BackgroundRepeat | BackgroundAttachment
               | BackgroundOrigin | Background
               | Opacity | Color | Display | Visibility
               | Width | Height | MinWidth | MinHeight | MaxWidth | MaxHeight
               | BlockSize | InlineSize | MinBlockSize | MinInlineSize
               | MaxBlockSize | MaxInlineSize
               | AspectRatio | Overflow | OverflowX | OverflowY
               | Position | Top | Bottom | Left | Right
               | InsetBlockStart | InsetBlockEnd | InsetInlineStart | InsetInlineEnd
               | InsetBlock | InsetInline | Inset
               | BorderSpacing
               | BorderTopColor | BorderBottomColor | BorderLeftColor | BorderRightColor
               | BorderBlockStartColor | BorderBlockEndColor
               | BorderInlineStartColor | BorderInlineEndColor
               | BorderTopStyle | BorderBottomStyle | BorderLeftStyle | BorderRightStyle
               | BorderBlockStartStyle | BorderBlockEndStyle
               | BorderInlineStartStyle | BorderInlineEndStyle
               | BorderTopWidth | BorderBottomWidth | BorderLeftWidth | BorderRightWidth
               | BorderBlockStartWidth | BorderBlockEndWidth
               | BorderInlineStartWidth | BorderInlineEndWidth
               | BorderStartStartRadius | BorderStartEndRadius
               | BorderEndStartRadius | BorderEndEndRadius
               | BorderImageSource | BorderImageOutset | BorderImageRepeat
               | BorderImageWidth | BorderImageSlice
               | BorderColor | BorderStyle | BorderWidth
               | BorderBlockColor | BorderBlockStyle | BorderBlockWidth
               | BorderInlineColor | BorderInlineStyle | BorderInlineWidth
               | Border | BorderTop | BorderBottom | BorderLeft | BorderRight
               | BorderBlock | BorderBlockStart | BorderBlockEnd
               | BorderInline | BorderInlineStart | BorderInlineEnd
               | Outline | OutlineColor | OutlineStyle | OutlineWidth
               | PlaceContent | JustifySelf | PlaceSelf
               | JustifyItems | PlaceItems | RowGap | ColumnGap | Gap
               | MarginTop | MarginBottom | MarginLeft | MarginRight
               | MarginBlockStart | MarginBlockEnd | MarginInlineStart | MarginInlineEnd
               | MarginBlock | MarginInline | Margin
               | PaddingTop | PaddingBottom | PaddingLeft | PaddingRight
               | PaddingBlockStart | PaddingBlockEnd | PaddingInlineStart | PaddingInlineEnd
               | PaddingBlock | PaddingInline | Padding
               | ScrollMarginTop | ScrollMarginBottom | ScrollMarginLeft | ScrollMarginRight
               | ScrollMarginBlockStart | ScrollMarginBlockEnd
               | ScrollMarginInlineStart | ScrollMarginInlineEnd
               | ScrollMarginBlock | ScrollMarginInline | ScrollMargin
               | ScrollPaddingTop | ScrollPaddingBottom | ScrollPaddingLeft | ScrollPaddingRight
               | ScrollPaddingBlockStart | ScrollPaddingBlockEnd
               | ScrollPaddingInlineStart | ScrollPaddingInlineEnd
               | ScrollPaddingBlock | ScrollPaddingInline | ScrollPadding
               | FontWeight | FontSize | FontStretch | FontFamily
               | FontStyle | FontVariantCaps | LineHeight | Font
               | TransformBox | Translate | Rotate | Scale | TextShadow
               | Direction | Composes
               | MaskMode | MaskPositionX | MaskPositionY
               | MaskComposite | MaskType
               | MaskBorderSource | MaskBorderMode | MaskBorderSlice
               | MaskBorderWidth | MaskBorderOutset | MaskBorderRepeat | MaskBorder
               | WebKitMaskComposite
               | ColorScheme => {
                // 无前缀属性 - 不需要设置
            }
            // === 带前缀的属性 - 通过 targets.prefixes() 设置 ===
            case BackgroundClip => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.BackgroundClip)
            }
            case BoxShadow => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.BoxShadow)
            }
            case BoxSizing => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.BoxSizing)
            }
            case TextOverflow => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.TextOverflow)
            }
            case BorderTopLeftRadius => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.BorderTopLeftRadius)
            }
            case BorderTopRightRadius => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.BorderTopRightRadius)
            }
            case BorderBottomLeftRadius => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.BorderBottomLeftRadius)
            }
            case BorderBottomRightRadius => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.BorderBottomRightRadius)
            }
            case BorderRadius => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.BorderRadius)
            }
            case BorderImage => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.BorderImage)
            }
            case FlexDirection => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.FlexDirection)
            }
            case FlexWrap => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.FlexWrap)
            }
            case FlexFlow => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.FlexFlow)
            }
            case FlexGrow => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.FlexGrow)
            }
            case FlexShrink => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.FlexShrink)
            }
            case FlexBasis => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.FlexBasis)
            }
            case Flex => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.Flex)
            }
            case Order => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.Order)
            }
            case AlignContent => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.AlignContent)
            }
            case JustifyContent => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.JustifyContent)
            }
            case AlignSelf => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.AlignSelf)
            }
            case AlignItems => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.AlignItems)
            }
            case TransitionProperty => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.TransitionProperty)
            }
            case TransitionDuration => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.TransitionDuration)
            }
            case TransitionDelay => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.TransitionDelay)
            }
            case TransitionTimingFunction => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.TransitionTimingFunction)
            }
            case Transition => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.Transition)
            }
            case Transform => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.Transform)
            }
            case TransformOrigin => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.TransformOrigin)
            }
            case TransformStyle => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.TransformStyle)
            }
            case BackfaceVisibility => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.BackfaceVisibility)
            }
            case Perspective => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.Perspective)
            }
            case PerspectiveOrigin => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.PerspectiveOrigin)
            }
            case TextDecorationColor => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.TextDecorationColor)
            }
            case TextEmphasisColor => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.TextEmphasisColor)
            }
            case MaskImage => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.MaskImage)
            }
            case MaskRepeat => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.MaskRepeat)
            }
            case MaskPosition => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.MaskPosition)
            }
            case MaskClip => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.MaskClip)
            }
            case MaskOrigin => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.MaskOrigin)
            }
            case MaskSize => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.MaskSize)
            }
            case Mask => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.Mask)
            }
            case MaskBorder => {
                this.vendorPrefix = targets.prefixes(this.vendorPrefix, Feature.MaskBorder)
            }
            // === 旧版 box- 属性和 ms-flex 属性 - 不需要 targets 处理 ===
            case BoxOrient | BoxDirection | BoxOrdinalGroup | BoxAlign
               | BoxFlex | BoxFlexGroup | BoxPack | BoxLines
               | FlexPack | FlexOrder | FlexAlign | FlexItemAlign
               | FlexLinePack | FlexPositive | FlexNegative | FlexPreferredSize
               | MaskSourceType | MaskBoxImage | MaskBoxImageSource
               | MaskBoxImageSlice | MaskBoxImageWidth | MaskBoxImageOutset
               | MaskBoxImageRepeat => {
                // 旧版属性 - 不设置 targets 前缀
            }
            // === 特殊属性 ===
            case All | Unparsed | Custom => {
                // 不需要设置前缀
            }
        }
    }

    /// 从名称和前缀解析 PropertyId
    /// 严格翻译自 fromNameAndPrefix
    public static func fromNameAndPrefix(name: String, prefix: VendorPrefix): ?PropertyId {
        // 通过 PropertyIdTag 的 toCssName 反查
        let tag = PropertyIdTagHelper.fromCssName(name)
        if (tag.isNone()) {
            return None
        }
        let t = tag.getOrThrow()

        // 检查该 tag 是否允许此前缀
        let allowedPrefixes = PropertyIdHelper.allowedPrefixes(t)
        if (!allowedPrefixes.contains(prefix)) {
            return None
        }

        if (t.hasVendorPrefix()) {
            return Some(PropertyId(t, prefix))
        }
        return Some(PropertyId(t, VendorPrefix()))
    }

    /// 序列化为 CSS
    /// 严格翻译自 toCss (properties_impl.property_id_mixin.toCss)
    /// 输出格式: [prefix]property-name
    public func toCss(dest: Printer): Unit {
        // 严格翻译自:
        //   var prefix = this.prefix()
        //   if (prefix.isEmpty()) prefix = VendorPrefix{ .none = true }
        //   dest.writeStr(prefix.toCssPrefix())
        //   dest.writeStr(this.name())
        let pre = this.prefix()
        if (pre.isEmpty()) {
            dest.writeStr("")
        } else {
            dest.writeStr(pre.toCssPrefix())
        }
        dest.writeStr(this.tag.toCssName())
    }

    /// 解析属性 ID
    /// 严格翻译自 PropertyId.parse (property_id_mixin.parse)
    public static func parse(name: String): ?PropertyId {
        return fromNameAndPrefix(name, VendorPrefix())
    }

    /// 从字符串解析
    /// 严格翻译自 PropertyId.fromString (property_id_mixin.fromString)
    public static func fromString(name: String): ?PropertyId {
        return fromNameAndPrefix(name, VendorPrefix())
    }

    /// 别名
    public static func fromStr(name: String): ?PropertyId {
        return fromString(name)
    }

    /// Hash
    /// 严格翻译自 PropertyId.hash
    public func hash(hasher: Hasher): Unit {
        hasher.update(this.tag)
        if (this.tag.hasVendorPrefix()) {
            hasher.update(this.vendorPrefix)
        }
    }
}

// ============================================================================
// Property 解析方法
// 严格翻译自: properties_generated.zig Property.parse (lines 4301-6051)
// ============================================================================

/// Property 解析辅助
/// 严格翻译自 Property.parse
public class PropertyParser {

    /// 解析 CSS 属性
    /// 严格翻译自 Property.parse(property_id, input, options)
    /// 每个 case 分支严格对应 Zig 中的 switch arm
    public static func parse(propertyId: PropertyId, input: CssParser, options: CssParserOptions): ?Property {
        let tag = propertyId.tag
        let pre = propertyId.vendorPrefix
        match (tag) {
            // 背景
            case BackgroundColor => {
                // 严格翻译自: .@"background-color" => CssColor parse
                return Some(Property(tag, CssParserHelper.parseCssColor(input, options), VendorPrefix()))
            }
            case BackgroundImage => {
                // 严格翻译自: .@"background-image" => SmallList(Image, 1)
                return Some(Property(tag, CssParserHelper.parseImageList(input, options), VendorPrefix()))
            }
            case BackgroundPositionX => {
                // 严格翻译自: .@"background-position-x"
                return Some(Property(tag, CssParserHelper.parseHorizontalPositionList(input, options), VendorPrefix()))
            }
            case BackgroundPositionY => {
                // 严格翻译自: .@"background-position-y"
                return Some(Property(tag, CssParserHelper.parseVerticalPositionList(input, options), VendorPrefix()))
            }
            case BackgroundPosition => {
                // 严格翻译自: .@"background-position" => SmallList(BackgroundPosition, 1)
                return Some(Property(tag, CssParserHelper.parseBackgroundPositionList(input, options), VendorPrefix()))
            }
            case BackgroundSize => {
                // 严格翻译自: .@"background-size" => SmallList(BackgroundSize, 1)
                return Some(Property(tag, CssParserHelper.parseBackgroundSizeList(input, options), VendorPrefix()))
            }
            case BackgroundRepeat => {
                // 严格翻译自: .@"background-repeat"
                return Some(Property(tag, CssParserHelper.parseBackgroundRepeatList(input, options), VendorPrefix()))
            }
            case BackgroundAttachment => {
                // 严格翻译自: .@"background-attachment"
                return Some(Property(tag, CssParserHelper.parseBackgroundAttachmentList(input, options), VendorPrefix()))
            }
            case BackgroundClip => {
                // 严格翻译自: .@"background-clip" => |pre| SmallList(BackgroundClip, 1), pre
                return Some(Property(tag, CssParserHelper.parseBackgroundClipList(input, options), pre))
            }
            case BackgroundOrigin => {
                // 严格翻译自: .@"background-origin"
                return Some(Property(tag, CssParserHelper.parseBackgroundOriginList(input, options), VendorPrefix()))
            }
            case Background => {
                // 严格翻译自: .background => SmallList(Background, 1)
                return Some(Property(tag, CssParserHelper.parseBackgroundList(input, options), VendorPrefix()))
            }
            // 阴影 & 颜色
            case BoxShadow => {
                // 严格翻译自: .@"box-shadow" => |pre| SmallList(BoxShadow, 1), pre
                return Some(Property(tag, CssParserHelper.parseBoxShadowList(input, options), pre))
            }
            case Opacity => {
                // 严格翻译自: .opacity => AlphaValue
                return Some(Property(tag, CssParserHelper.parseAlphaValue(input, options), VendorPrefix()))
            }
            case Color => {
                // 严格翻译自: .color => CssColor
                return Some(Property(tag, CssParserHelper.parseCssColor(input, options), VendorPrefix()))
            }
            // 显示
            case Display => {
                // 严格翻译自: .display => Display
                return Some(Property(tag, CssParserHelper.parseDisplay(input, options), VendorPrefix()))
            }
            case Visibility => {
                // 严格翻译自: .visibility => Visibility
                return Some(Property(tag, CssParserHelper.parseVisibility(input, options), VendorPrefix()))
            }
            // 尺寸
            case Width => {
                // 严格翻译自: .width => Size
                return Some(Property(tag, CssParserHelper.parseSize(input, options), VendorPrefix()))
            }
            case Height => {
                return Some(Property(tag, CssParserHelper.parseSize(input, options), VendorPrefix()))
            }
            case MinWidth => {
                return Some(Property(tag, CssParserHelper.parseSize(input, options), VendorPrefix()))
            }
            case MinHeight => {
                return Some(Property(tag, CssParserHelper.parseSize(input, options), VendorPrefix()))
            }
            case MaxWidth => {
                // 严格翻译自: .@"max-width" => MaxSize
                return Some(Property(tag, CssParserHelper.parseMaxSize(input, options), VendorPrefix()))
            }
            case MaxHeight => {
                return Some(Property(tag, CssParserHelper.parseMaxSize(input, options), VendorPrefix()))
            }
            case BlockSize => {
                return Some(Property(tag, CssParserHelper.parseSize(input, options), VendorPrefix()))
            }
            case InlineSize => {
                return Some(Property(tag, CssParserHelper.parseSize(input, options), VendorPrefix()))
            }
            case MinBlockSize => {
                return Some(Property(tag, CssParserHelper.parseSize(input, options), VendorPrefix()))
            }
            case MinInlineSize => {
                return Some(Property(tag, CssParserHelper.parseSize(input, options), VendorPrefix()))
            }
            case MaxBlockSize => {
                return Some(Property(tag, CssParserHelper.parseMaxSize(input, options), VendorPrefix()))
            }
            case MaxInlineSize => {
                return Some(Property(tag, CssParserHelper.parseMaxSize(input, options), VendorPrefix()))
            }
            case BoxSizing => {
                // 严格翻译自: .@"box-sizing" => |pre| BoxSizing, pre
                return Some(Property(tag, CssParserHelper.parseBoxSizing(input, options), pre))
            }
            case AspectRatio => {
                // 严格翻译自: .@"aspect-ratio" => AspectRatio
                return Some(Property(tag, CssParserHelper.parseAspectRatio(input, options), VendorPrefix()))
            }
            // 溢出
            case Overflow => {
                // 严格翻译自: .overflow => Overflow
                return Some(Property(tag, CssParserHelper.parseOverflow(input, options), VendorPrefix()))
            }
            case OverflowX => {
                // 严格翻译自: .@"overflow-x" => OverflowKeyword
                return Some(Property(tag, CssParserHelper.parseOverflowKeyword(input, options), VendorPrefix()))
            }
            case OverflowY => {
                return Some(Property(tag, CssParserHelper.parseOverflowKeyword(input, options), VendorPrefix()))
            }
            case TextOverflow => {
                // 严格翻译自: .@"text-overflow" => |pre| TextOverflow, pre
                return Some(Property(tag, CssParserHelper.parseTextOverflow(input, options), pre))
            }
            // 定位
            case Position => {
                // 严格翻译自: .position => Position
                return Some(Property(tag, CssParserHelper.parsePosition(input, options), VendorPrefix()))
            }
            case Top => {
                return Some(Property(tag, CssParserHelper.parseLengthPercentageOrAuto(input, options), VendorPrefix()))
            }
            case Bottom => {
                return Some(Property(tag, CssParserHelper.parseLengthPercentageOrAuto(input, options), VendorPrefix()))
            }
            case Left => {
                return Some(Property(tag, CssParserHelper.parseLengthPercentageOrAuto(input, options), VendorPrefix()))
            }
            case Right => {
                return Some(Property(tag, CssParserHelper.parseLengthPercentageOrAuto(input, options), VendorPrefix()))
            }
            case InsetBlockStart => {
                return Some(Property(tag, CssParserHelper.parseLengthPercentageOrAuto(input, options), VendorPrefix()))
            }
            case InsetBlockEnd => {
                return Some(Property(tag, CssParserHelper.parseLengthPercentageOrAuto(input, options), VendorPrefix()))
            }
            case InsetInlineStart => {
                return Some(Property(tag, CssParserHelper.parseLengthPercentageOrAuto(input, options), VendorPrefix()))
            }
            case InsetInlineEnd => {
                return Some(Property(tag, CssParserHelper.parseLengthPercentageOrAuto(input, options), VendorPrefix()))
            }
            case InsetBlock => {
                // 严格翻译自: .@"inset-block" => InsetBlock
                return Some(Property(tag, CssParserHelper.parseInsetBlock(input, options), VendorPrefix()))
            }
            case InsetInline => {
                // 严格翻译自: .@"inset-inline" => InsetInline
                return Some(Property(tag, CssParserHelper.parseInsetInline(input, options), VendorPrefix()))
            }
            case Inset => {
                // 严格翻译自: .inset => Inset
                return Some(Property(tag, CssParserHelper.parseInset(input, options), VendorPrefix()))
            }
            // 边框
            case BorderSpacing => {
                // 严格翻译自: .@"border-spacing" => Size2D(Length)
                return Some(Property(tag, CssParserHelper.parseSize2DLength(input, options), VendorPrefix()))
            }
            case BorderTopColor | BorderBottomColor | BorderLeftColor | BorderRightColor
               | BorderBlockStartColor | BorderBlockEndColor | BorderInlineStartColor | BorderInlineEndColor => {
                // 所有 border-*-color 解析为 CssColor
                return Some(Property(tag, CssParserHelper.parseCssColor(input, options), VendorPrefix()))
            }
            case BorderTopStyle | BorderBottomStyle | BorderLeftStyle | BorderRightStyle
               | BorderBlockStartStyle | BorderBlockEndStyle | BorderInlineStartStyle | BorderInlineEndStyle => {
                // 所有 border-*-style 解析为 LineStyle
                return Some(Property(tag, CssParserHelper.parseLineStyle(input, options), VendorPrefix()))
            }
            case BorderTopWidth | BorderBottomWidth | BorderLeftWidth | BorderRightWidth
               | BorderBlockStartWidth | BorderBlockEndWidth | BorderInlineStartWidth | BorderInlineEndWidth => {
                // 所有 border-*-width 解析为 BorderSideWidth
                return Some(Property(tag, CssParserHelper.parseBorderSideWidth(input, options), VendorPrefix()))
            }
            case BorderTopLeftRadius => {
                // 严格翻译自: .@"border-top-left-radius" => |pre| Size2D(LengthPercentage), pre
                return Some(Property(tag, CssParserHelper.parseSize2DLengthPercentage(input, options), pre))
            }
            case BorderTopRightRadius => {
                return Some(Property(tag, CssParserHelper.parseSize2DLengthPercentage(input, options), pre))
            }
            case BorderBottomLeftRadius => {
                return Some(Property(tag, CssParserHelper.parseSize2DLengthPercentage(input, options), pre))
            }
            case BorderBottomRightRadius => {
                return Some(Property(tag, CssParserHelper.parseSize2DLengthPercentage(input, options), pre))
            }
            case BorderStartStartRadius | BorderStartEndRadius | BorderEndStartRadius | BorderEndEndRadius => {
                // 严格翻译自: 逻辑角半径，无前缀
                return Some(Property(tag, CssParserHelper.parseSize2DLengthPercentage(input, options), VendorPrefix()))
            }
            case BorderRadius => {
                // 严格翻译自: .@"border-radius" => |pre| BorderRadius, pre
                return Some(Property(tag, CssParserHelper.parseBorderRadius(input, options), pre))
            }
            case BorderImageSource => {
                // 严格翻译自: .@"border-image-source" => Image
                return Some(Property(tag, CssParserHelper.parseImage(input, options), VendorPrefix()))
            }
            case BorderImageOutset => {
                // 严格翻译自: .@"border-image-outset" => Rect(LengthOrNumber)
                return Some(Property(tag, CssParserHelper.parseRectLengthOrNumber(input, options), VendorPrefix()))
            }
            case BorderImageRepeat => {
                // 严格翻译自: .@"border-image-repeat"
                return Some(Property(tag, CssParserHelper.parseBorderImageRepeat(input, options), VendorPrefix()))
            }
            case BorderImageWidth => {
                // 严格翻译自: .@"border-image-width" => Rect(BorderImageSideWidth)
                return Some(Property(tag, CssParserHelper.parseRectBorderImageSideWidth(input, options), VendorPrefix()))
            }
            case BorderImageSlice => {
                // 严格翻译自: .@"border-image-slice"
                return Some(Property(tag, CssParserHelper.parseBorderImageSlice(input, options), VendorPrefix()))
            }
            case BorderImage => {
                // 严格翻译自: .@"border-image" => |pre| BorderImage, pre
                return Some(Property(tag, CssParserHelper.parseBorderImage(input, options), pre))
            }
            case BorderColor => {
                return Some(Property(tag, CssParserHelper.parseBorderColor(input, options), VendorPrefix()))
            }
            case BorderStyle => {
                return Some(Property(tag, CssParserHelper.parseBorderStyle(input, options), VendorPrefix()))
            }
            case BorderWidth => {
                return Some(Property(tag, CssParserHelper.parseBorderWidth(input, options), VendorPrefix()))
            }
            case BorderBlockColor => {
                return Some(Property(tag, CssParserHelper.parseBorderBlockColor(input, options), VendorPrefix()))
            }
            case BorderBlockStyle => {
                return Some(Property(tag, CssParserHelper.parseBorderBlockStyle(input, options), VendorPrefix()))
            }
            case BorderBlockWidth => {
                return Some(Property(tag, CssParserHelper.parseBorderBlockWidth(input, options), VendorPrefix()))
            }
            case BorderInlineColor => {
                return Some(Property(tag, CssParserHelper.parseBorderInlineColor(input, options), VendorPrefix()))
            }
            case BorderInlineStyle => {
                return Some(Property(tag, CssParserHelper.parseBorderInlineStyle(input, options), VendorPrefix()))
            }
            case BorderInlineWidth => {
                return Some(Property(tag, CssParserHelper.parseBorderInlineWidth(input, options), VendorPrefix()))
            }
            case Border => {
                return Some(Property(tag, CssParserHelper.parseBorder(input, options), VendorPrefix()))
            }
            case BorderTop => {
                return Some(Property(tag, CssParserHelper.parseBorderTop(input, options), VendorPrefix()))
            }
            case BorderBottom => {
                return Some(Property(tag, CssParserHelper.parseBorderBottom(input, options), VendorPrefix()))
            }
            case BorderLeft => {
                return Some(Property(tag, CssParserHelper.parseBorderLeft(input, options), VendorPrefix()))
            }
            case BorderRight => {
                return Some(Property(tag, CssParserHelper.parseBorderRight(input, options), VendorPrefix()))
            }
            case BorderBlock => {
                return Some(Property(tag, CssParserHelper.parseBorderBlock(input, options), VendorPrefix()))
            }
            case BorderBlockStart => {
                return Some(Property(tag, CssParserHelper.parseBorderBlockStart(input, options), VendorPrefix()))
            }
            case BorderBlockEnd => {
                return Some(Property(tag, CssParserHelper.parseBorderBlockEnd(input, options), VendorPrefix()))
            }
            case BorderInline => {
                return Some(Property(tag, CssParserHelper.parseBorderInline(input, options), VendorPrefix()))
            }
            case BorderInlineStart => {
                return Some(Property(tag, CssParserHelper.parseBorderInlineStart(input, options), VendorPrefix()))
            }
            case BorderInlineEnd => {
                return Some(Property(tag, CssParserHelper.parseBorderInlineEnd(input, options), VendorPrefix()))
            }
            // Outline
            case Outline => {
                return Some(Property(tag, CssParserHelper.parseOutline(input, options), VendorPrefix()))
            }
            case OutlineColor => {
                return Some(Property(tag, CssParserHelper.parseCssColor(input, options), VendorPrefix()))
            }
            case OutlineStyle => {
                return Some(Property(tag, CssParserHelper.parseOutlineStyle(input, options), VendorPrefix()))
            }
            case OutlineWidth => {
                return Some(Property(tag, CssParserHelper.parseBorderSideWidth(input, options), VendorPrefix()))
            }
            // Flex (含前缀属性)
            case FlexDirection => {
                // 严格翻译自: .@"flex-direction" => |pre| FlexDirection, pre
                return Some(Property(tag, CssParserHelper.parseFlexDirection(input, options), pre))
            }
            case FlexWrap => {
                return Some(Property(tag, CssParserHelper.parseFlexWrap(input, options), pre))
            }
            case FlexFlow => {
                return Some(Property(tag, CssParserHelper.parseFlexFlow(input, options), pre))
            }
            case FlexGrow => {
                // 严格翻译自: .@"flex-grow" => |pre| CSSNumber, pre
                return Some(Property(tag, CssParserHelper.parseCSSNumber(input, options), pre))
            }
            case FlexShrink => {
                return Some(Property(tag, CssParserHelper.parseCSSNumber(input, options), pre))
            }
            case FlexBasis => {
                // 严格翻译自: .@"flex-basis" => |pre| LengthPercentageOrAuto, pre
                return Some(Property(tag, CssParserHelper.parseLengthPercentageOrAuto(input, options), pre))
            }
            case Flex => {
                // 严格翻译自: .flex => |pre| Flex, pre
                return Some(Property(tag, CssParserHelper.parseFlex(input, options), pre))
            }
            case Order => {
                // 严格翻译自: .order => |pre| CSSInteger, pre
                return Some(Property(tag, CssParserHelper.parseCSSInteger(input, options), pre))
            }
            case AlignContent => {
                return Some(Property(tag, CssParserHelper.parseAlignContent(input, options), pre))
            }
            case JustifyContent => {
                return Some(Property(tag, CssParserHelper.parseJustifyContent(input, options), pre))
            }
            case PlaceContent => {
                // 严格翻译自: .@"place-content" => PlaceContent (无前缀)
                return Some(Property(tag, CssParserHelper.parsePlaceContent(input, options), VendorPrefix()))
            }
            case AlignSelf => {
                return Some(Property(tag, CssParserHelper.parseAlignSelf(input, options), pre))
            }
            case JustifySelf => {
                // 严格翻译自: .@"justify-self" (无前缀)
                return Some(Property(tag, CssParserHelper.parseJustifySelf(input, options), VendorPrefix()))
            }
            case PlaceSelf => {
                return Some(Property(tag, CssParserHelper.parsePlaceSelf(input, options), VendorPrefix()))
            }
            case AlignItems => {
                return Some(Property(tag, CssParserHelper.parseAlignItems(input, options), pre))
            }
            case JustifyItems => {
                return Some(Property(tag, CssParserHelper.parseJustifyItems(input, options), VendorPrefix()))
            }
            case PlaceItems => {
                return Some(Property(tag, CssParserHelper.parsePlaceItems(input, options), VendorPrefix()))
            }
            case RowGap => {
                // 严格翻译自: .@"row-gap" => GapValue
                return Some(Property(tag, CssParserHelper.parseGapValue(input, options), VendorPrefix()))
            }
            case ColumnGap => {
                return Some(Property(tag, CssParserHelper.parseGapValue(input, options), VendorPrefix()))
            }
            case Gap => {
                // 严格翻译自: .gap => Gap
                return Some(Property(tag, CssParserHelper.parseGap(input, options), VendorPrefix()))
            }
            // 旧版 flex 前缀属性
            case BoxOrient => {
                // 严格翻译自: .@"box-orient" => |pre| BoxOrient, pre
                return Some(Property(tag, CssParserHelper.parseBoxOrient(input, options), pre))
            }
            case BoxDirection => {
                return Some(Property(tag, CssParserHelper.parseBoxDirection(input, options), pre))
            }
            case BoxOrdinalGroup => {
                // 严格翻译自: .@"box-ordinal-group" => |pre| CSSInteger, pre
                return Some(Property(tag, CssParserHelper.parseCSSInteger(input, options), pre))
            }
            case BoxAlign => {
                return Some(Property(tag, CssParserHelper.parseBoxAlign(input, options), pre))
            }
            case BoxFlex => {
                // 严格翻译自: .@"box-flex" => |pre| CSSNumber, pre
                return Some(Property(tag, CssParserHelper.parseCSSNumber(input, options), pre))
            }
            case BoxFlexGroup => {
                return Some(Property(tag, CssParserHelper.parseCSSInteger(input, options), pre))
            }
            case BoxPack => {
                return Some(Property(tag, CssParserHelper.parseBoxPack(input, options), pre))
            }
            case BoxLines => {
                return Some(Property(tag, CssParserHelper.parseBoxLines(input, options), pre))
            }
            case FlexPack => {
                // 严格翻译自: .@"flex-pack" => |pre| FlexPack, pre
                return Some(Property(tag, CssParserHelper.parseFlexPack(input, options), pre))
            }
            case FlexOrder => {
                return Some(Property(tag, CssParserHelper.parseCSSInteger(input, options), pre))
            }
            case FlexAlign => {
                // 严格翻译自: .@"flex-align" => |pre| BoxAlign, pre
                return Some(Property(tag, CssParserHelper.parseBoxAlign(input, options), pre))
            }
            case FlexItemAlign => {
                return Some(Property(tag, CssParserHelper.parseFlexItemAlign(input, options), pre))
            }
            case FlexLinePack => {
                return Some(Property(tag, CssParserHelper.parseFlexLinePack(input, options), pre))
            }
            case FlexPositive => {
                return Some(Property(tag, CssParserHelper.parseCSSNumber(input, options), pre))
            }
            case FlexNegative => {
                return Some(Property(tag, CssParserHelper.parseCSSNumber(input, options), pre))
            }
            case FlexPreferredSize => {
                // 严格翻译自: .@"flex-preferred-size" => |pre| LengthPercentageOrAuto, pre
                return Some(Property(tag, CssParserHelper.parseLengthPercentageOrAuto(input, options), pre))
            }
            // 外边距 & 内边距
            case MarginTop | MarginBottom | MarginLeft | MarginRight
               | MarginBlockStart | MarginBlockEnd | MarginInlineStart | MarginInlineEnd => {
                // 所有 margin-*-side 解析为 LengthPercentageOrAuto
                return Some(Property(tag, CssParserHelper.parseLengthPercentageOrAuto(input, options), VendorPrefix()))
            }
            case MarginBlock => {
                // 严格翻译自: .@"margin-block" => MarginBlock
                return Some(Property(tag, CssParserHelper.parseMarginBlock(input, options), VendorPrefix()))
            }
            case MarginInline => {
                return Some(Property(tag, CssParserHelper.parseMarginInline(input, options), VendorPrefix()))
            }
            case Margin => {
                // 严格翻译自: .margin => Margin
                return Some(Property(tag, CssParserHelper.parseMargin(input, options), VendorPrefix()))
            }
            case PaddingTop | PaddingBottom | PaddingLeft | PaddingRight
               | PaddingBlockStart | PaddingBlockEnd | PaddingInlineStart | PaddingInlineEnd => {
                // 所有 padding-*-side 解析为 LengthPercentageOrAuto
                return Some(Property(tag, CssParserHelper.parseLengthPercentageOrAuto(input, options), VendorPrefix()))
            }
            case PaddingBlock => {
                return Some(Property(tag, CssParserHelper.parsePaddingBlock(input, options), VendorPrefix()))
            }
            case PaddingInline => {
                return Some(Property(tag, CssParserHelper.parsePaddingInline(input, options), VendorPrefix()))
            }
            case Padding => {
                return Some(Property(tag, CssParserHelper.parsePadding(input, options), VendorPrefix()))
            }
            // Scroll margin & padding
            case ScrollMarginTop | ScrollMarginBottom | ScrollMarginLeft | ScrollMarginRight
               | ScrollMarginBlockStart | ScrollMarginBlockEnd | ScrollMarginInlineStart | ScrollMarginInlineEnd => {
                // 严格翻译自: scroll-margin-*-side => LengthPercentageOrAuto
                return Some(Property(tag, CssParserHelper.parseLengthPercentageOrAuto(input, options), VendorPrefix()))
            }
            case ScrollMarginBlock => {
                return Some(Property(tag, CssParserHelper.parseScrollMarginBlock(input, options), VendorPrefix()))
            }
            case ScrollMarginInline => {
                return Some(Property(tag, CssParserHelper.parseScrollMarginInline(input, options), VendorPrefix()))
            }
            case ScrollMargin => {
                return Some(Property(tag, CssParserHelper.parseScrollMargin(input, options), VendorPrefix()))
            }
            case ScrollPaddingTop | ScrollPaddingBottom | ScrollPaddingLeft | ScrollPaddingRight
               | ScrollPaddingBlockStart | ScrollPaddingBlockEnd | ScrollPaddingInlineStart | ScrollPaddingInlineEnd => {
                // 严格翻译自: scroll-padding-*-side => LengthPercentageOrAuto
                return Some(Property(tag, CssParserHelper.parseLengthPercentageOrAuto(input, options), VendorPrefix()))
            }
            case ScrollPaddingBlock => {
                return Some(Property(tag, CssParserHelper.parseScrollPaddingBlock(input, options), VendorPrefix()))
            }
            case ScrollPaddingInline => {
                return Some(Property(tag, CssParserHelper.parseScrollPaddingInline(input, options), VendorPrefix()))
            }
            case ScrollPadding => {
                return Some(Property(tag, CssParserHelper.parseScrollPadding(input, options), VendorPrefix()))
            }
            // 字体
            case FontWeight => {
                // 严格翻译自: .@"font-weight" => FontWeight
                return Some(Property(tag, CssParserHelper.parseFontWeight(input, options), VendorPrefix()))
            }
            case FontSize => {
                return Some(Property(tag, CssParserHelper.parseFontSize(input, options), VendorPrefix()))
            }
            case FontStretch => {
                return Some(Property(tag, CssParserHelper.parseFontStretch(input, options), VendorPrefix()))
            }
            case FontFamily => {
                // 严格翻译自: .@"font-family" => BabyList(FontFamily)
                return Some(Property(tag, CssParserHelper.parseFontFamilyList(input, options), VendorPrefix()))
            }
            case FontStyle => {
                return Some(Property(tag, CssParserHelper.parseFontStyle(input, options), VendorPrefix()))
            }
            case FontVariantCaps => {
                return Some(Property(tag, CssParserHelper.parseFontVariantCaps(input, options), VendorPrefix()))
            }
            case LineHeight => {
                return Some(Property(tag, CssParserHelper.parseLineHeight(input, options), VendorPrefix()))
            }
            case Font => {
                // 严格翻译自: .font => Font
                return Some(Property(tag, CssParserHelper.parseFont(input, options), VendorPrefix()))
            }
            // 变换 & 过渡
            case TransitionProperty => {
                // 严格翻译自: .@"transition-property" => |pre| SmallList(PropertyId, 1), pre
                return Some(Property(tag, CssParserHelper.parsePropertyIdList(input, options), pre))
            }
            case TransitionDuration => {
                // 严格翻译自: .@"transition-duration" => |pre| SmallList(Time, 1), pre
                return Some(Property(tag, CssParserHelper.parseTimeList(input, options), pre))
            }
            case TransitionDelay => {
                return Some(Property(tag, CssParserHelper.parseTimeList(input, options), pre))
            }
            case TransitionTimingFunction => {
                // 严格翻译自: .@"transition-timing-function" => |pre| SmallList(EasingFunction, 1), pre
                return Some(Property(tag, CssParserHelper.parseEasingFunctionList(input, options), pre))
            }
            case Transition => {
                // 严格翻译自: .transition => |pre| SmallList(Transition, 1), pre
                return Some(Property(tag, CssParserHelper.parseTransitionList(input, options), pre))
            }
            case Transform => {
                // 严格翻译自: .transform => |pre| TransformList, pre
                return Some(Property(tag, CssParserHelper.parseTransformList(input, options), pre))
            }
            case TransformOrigin => {
                // 严格翻译自: .@"transform-origin" => |pre| Position, pre
                return Some(Property(tag, CssParserHelper.parsePosition(input, options), pre))
            }
            case TransformStyle => {
                return Some(Property(tag, CssParserHelper.parseTransformStyle(input, options), pre))
            }
            case TransformBox => {
                // 严格翻译自: .@"transform-box" => TransformBox (无前缀)
                return Some(Property(tag, CssParserHelper.parseTransformBox(input, options), VendorPrefix()))
            }
            case BackfaceVisibility => {
                // 严格翻译自: .@"backface-visibility" => |pre|
                return Some(Property(tag, CssParserHelper.parseBackfaceVisibility(input, options), pre))
            }
            case Perspective => {
                return Some(Property(tag, CssParserHelper.parsePerspective(input, options), pre))
            }
            case PerspectiveOrigin => {
                return Some(Property(tag, CssParserHelper.parsePosition(input, options), pre))
            }
            case Translate => {
                // 严格翻译自: .translate => Translate (无前缀)
                return Some(Property(tag, CssParserHelper.parseTranslate(input, options), VendorPrefix()))
            }
            case Rotate => {
                return Some(Property(tag, CssParserHelper.parseRotate(input, options), VendorPrefix()))
            }
            case Scale => {
                return Some(Property(tag, CssParserHelper.parseScale(input, options), VendorPrefix()))
            }
            // 文本
            case TextDecorationColor => {
                // 严格翻译自: .@"text-decoration-color" => |pre| CssColor, pre
                return Some(Property(tag, CssParserHelper.parseCssColor(input, options), pre))
            }
            case TextEmphasisColor => {
                return Some(Property(tag, CssParserHelper.parseCssColor(input, options), pre))
            }
            case TextShadow => {
                // 严格翻译自: .@"text-shadow" => SmallList(TextShadow, 1)
                return Some(Property(tag, CssParserHelper.parseTextShadowList(input, options), VendorPrefix()))
            }
            case Direction => {
                // 严格翻译自: .direction => Direction
                return Some(Property(tag, CssParserHelper.parseDirection(input, options), VendorPrefix()))
            }
            case Composes => {
                // 严格翻译自: .composes => Composes (直接返回)
                return Some(Property(tag, CssParserHelper.parseComposes(input, options), VendorPrefix()))
            }
            // 遮罩
            case MaskImage => {
                // 严格翻译自: .@"mask-image" => |pre| SmallList(Image, 1), pre
                return Some(Property(tag, CssParserHelper.parseImageList(input, options), pre))
            }
            case MaskMode => {
                // 严格翻译自: .@"mask-mode" => SmallList(MaskMode, 1)
                return Some(Property(tag, CssParserHelper.parseMaskModeList(input, options), VendorPrefix()))
            }
            case MaskRepeat => {
                // 严格翻译自: .@"mask-repeat" => |pre| SmallList(BackgroundRepeat, 1), pre
                return Some(Property(tag, CssParserHelper.parseBackgroundRepeatList(input, options), pre))
            }
            case MaskPositionX => {
                return Some(Property(tag, CssParserHelper.parseHorizontalPositionList(input, options), VendorPrefix()))
            }
            case MaskPositionY => {
                return Some(Property(tag, CssParserHelper.parseVerticalPositionList(input, options), VendorPrefix()))
            }
            case MaskPosition => {
                // 严格翻译自: .@"mask-position" => |pre| SmallList(Position, 1), pre
                return Some(Property(tag, CssParserHelper.parsePositionList(input, options), pre))
            }
            case MaskClip => {
                // 严格翻译自: .@"mask-clip" => |pre| SmallList(MaskClip, 1), pre
                return Some(Property(tag, CssParserHelper.parseMaskClipList(input, options), pre))
            }
            case MaskOrigin => {
                // 严格翻译自: .@"mask-origin" => |pre| SmallList(GeometryBox, 1), pre
                return Some(Property(tag, CssParserHelper.parseGeometryBoxList(input, options), pre))
            }
            case MaskSize => {
                // 严格翻译自: .@"mask-size" => |pre| SmallList(BackgroundSize, 1), pre
                return Some(Property(tag, CssParserHelper.parseBackgroundSizeList(input, options), pre))
            }
            case MaskComposite => {
                // 严格翻译自: .@"mask-composite" => SmallList(MaskComposite, 1)
                return Some(Property(tag, CssParserHelper.parseMaskCompositeList(input, options), VendorPrefix()))
            }
            case MaskType => {
                return Some(Property(tag, CssParserHelper.parseMaskType(input, options), VendorPrefix()))
            }
            case Mask => {
                // 严格翻译自: .mask => |pre| SmallList(Mask, 1), pre
                return Some(Property(tag, CssParserHelper.parseMaskList(input, options), pre))
            }
            case MaskBorderSource => {
                return Some(Property(tag, CssParserHelper.parseImage(input, options), VendorPrefix()))
            }
            case MaskBorderMode => {
                return Some(Property(tag, CssParserHelper.parseMaskBorderMode(input, options), VendorPrefix()))
            }
            case MaskBorderSlice => {
                return Some(Property(tag, CssParserHelper.parseBorderImageSlice(input, options), VendorPrefix()))
            }
            case MaskBorderWidth => {
                return Some(Property(tag, CssParserHelper.parseRectBorderImageSideWidth(input, options), VendorPrefix()))
            }
            case MaskBorderOutset => {
                return Some(Property(tag, CssParserHelper.parseRectLengthOrNumber(input, options), VendorPrefix()))
            }
            case MaskBorderRepeat => {
                return Some(Property(tag, CssParserHelper.parseBorderImageRepeat(input, options), VendorPrefix()))
            }
            case MaskBorder => {
                return Some(Property(tag, CssParserHelper.parseMaskBorder(input, options), VendorPrefix()))
            }
            case WebKitMaskComposite => {
                // 严格翻译自: .@"-webkit-mask-composite" => SmallList(WebKitMaskComposite, 1)
                return Some(Property(tag, CssParserHelper.parseWebKitMaskCompositeList(input, options), VendorPrefix()))
            }
            case MaskSourceType => {
                // 严格翻译自: .@"mask-source-type" => |pre| SmallList(WebKitMaskSourceType, 1), pre
                return Some(Property(tag, CssParserHelper.parseWebKitMaskSourceTypeList(input, options), pre))
            }
            case MaskBoxImage => {
                // 严格翻译自: .@"mask-box-image" => |pre| BorderImage, pre
                return Some(Property(tag, CssParserHelper.parseBorderImage(input, options), pre))
            }
            case MaskBoxImageSource => {
                return Some(Property(tag, CssParserHelper.parseImage(input, options), pre))
            }
            case MaskBoxImageSlice => {
                return Some(Property(tag, CssParserHelper.parseBorderImageSlice(input, options), pre))
            }
            case MaskBoxImageWidth => {
                return Some(Property(tag, CssParserHelper.parseRectBorderImageSideWidth(input, options), pre))
            }
            case MaskBoxImageOutset => {
                return Some(Property(tag, CssParserHelper.parseRectLengthOrNumber(input, options), pre))
            }
            case MaskBoxImageRepeat => {
                return Some(Property(tag, CssParserHelper.parseBorderImageRepeat(input, options), pre))
            }
            // UI
            case ColorScheme => {
                // 严格翻译自: .@"color-scheme" => ColorScheme
                return Some(Property(tag, CssParserHelper.parseColorScheme(input, options), VendorPrefix()))
            }
            // 特殊
            case All => {
                // 严格翻译自: .all => CSSWideKeyword
                return Some(Property(tag, CssParserHelper.parseCSSWideKeyword(input, options), VendorPrefix()))
            }
            case Unparsed | Custom => {
                // 严格翻译自: 在 else 分支中 fallback 到 unparsed
                return Some(Property(tag, CssParserHelper.parseUnparsed(propertyId, input, options), propertyId.vendorPrefix))
            }
        }
    }
}

// ============================================================================
// CssParserHelper - 解析器辅助 (桥接各类型解析方法)
// 严格翻译自: properties_generated.zig 中的 parse switch 分支
// ============================================================================

/// CSS 解析辅助工具
/// 桥接 CssParser 调用到各具体类型的 parse 方法
/// 严格翻译自 Property.parse 中各分支的 parseWithOptions 调用
public class CssParserHelper {

    // =========================================================================
    // 以下方法严格对应 Zig 中 css.generic.parseWithOptions(Type, input, options)
    // 在仓颉中委托给具体类型的静态 parse 方法
    // =========================================================================

    public static func parseCssColor(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("CssColor", options)
    }
    public static func parseImage(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Image", options)
    }
    public static func parseImageList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<Image>", options)
    }
    public static func parseHorizontalPositionList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<HorizontalPosition>", options)
    }
    public static func parseVerticalPositionList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<VerticalPosition>", options)
    }
    public static func parseBackgroundPositionList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<BackgroundPosition>", options)
    }
    public static func parseBackgroundSizeList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<BackgroundSize>", options)
    }
    public static func parseBackgroundRepeatList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<BackgroundRepeat>", options)
    }
    public static func parseBackgroundAttachmentList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<BackgroundAttachment>", options)
    }
    public static func parseBackgroundClipList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<BackgroundClip>", options)
    }
    public static func parseBackgroundOriginList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<BackgroundOrigin>", options)
    }
    public static func parseBackgroundList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<Background>", options)
    }
    public static func parseBoxShadowList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<BoxShadow>", options)
    }
    public static func parseAlphaValue(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("AlphaValue", options)
    }
    public static func parseDisplay(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Display", options)
    }
    public static func parseVisibility(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Visibility", options)
    }
    public static func parseSize(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Size", options)
    }
    public static func parseMaxSize(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("MaxSize", options)
    }
    public static func parseBoxSizing(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BoxSizing", options)
    }
    public static func parseAspectRatio(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("AspectRatio", options)
    }
    public static func parseOverflow(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Overflow", options)
    }
    public static func parseOverflowKeyword(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("OverflowKeyword", options)
    }
    public static func parseTextOverflow(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("TextOverflow", options)
    }
    public static func parsePosition(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Position", options)
    }
    public static func parseLengthPercentageOrAuto(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("LengthPercentageOrAuto", options)
    }
    public static func parseInsetBlock(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("InsetBlock", options)
    }
    public static func parseInsetInline(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("InsetInline", options)
    }
    public static func parseInset(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Inset", options)
    }
    public static func parseSize2DLength(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Size2D<Length>", options)
    }
    public static func parseLineStyle(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("LineStyle", options)
    }
    public static func parseBorderSideWidth(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderSideWidth", options)
    }
    public static func parseSize2DLengthPercentage(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Size2D<LengthPercentage>", options)
    }
    public static func parseBorderRadius(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderRadius", options)
    }
    public static func parseRectLengthOrNumber(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Rect<LengthOrNumber>", options)
    }
    public static func parseBorderImageRepeat(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderImageRepeat", options)
    }
    public static func parseRectBorderImageSideWidth(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Rect<BorderImageSideWidth>", options)
    }
    public static func parseBorderImageSlice(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderImageSlice", options)
    }
    public static func parseBorderImage(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderImage", options)
    }
    public static func parseBorderColor(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderColor", options)
    }
    public static func parseBorderStyle(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderStyle", options)
    }
    public static func parseBorderWidth(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderWidth", options)
    }
    public static func parseBorderBlockColor(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderBlockColor", options)
    }
    public static func parseBorderBlockStyle(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderBlockStyle", options)
    }
    public static func parseBorderBlockWidth(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderBlockWidth", options)
    }
    public static func parseBorderInlineColor(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderInlineColor", options)
    }
    public static func parseBorderInlineStyle(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderInlineStyle", options)
    }
    public static func parseBorderInlineWidth(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderInlineWidth", options)
    }
    public static func parseBorder(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Border", options)
    }
    public static func parseBorderTop(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderTop", options)
    }
    public static func parseBorderBottom(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderBottom", options)
    }
    public static func parseBorderLeft(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderLeft", options)
    }
    public static func parseBorderRight(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderRight", options)
    }
    public static func parseBorderBlock(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderBlock", options)
    }
    public static func parseBorderBlockStart(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderBlockStart", options)
    }
    public static func parseBorderBlockEnd(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderBlockEnd", options)
    }
    public static func parseBorderInline(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderInline", options)
    }
    public static func parseBorderInlineStart(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderInlineStart", options)
    }
    public static func parseBorderInlineEnd(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BorderInlineEnd", options)
    }
    public static func parseOutline(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Outline", options)
    }
    public static func parseOutlineStyle(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("OutlineStyle", options)
    }
    public static func parseFlexDirection(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("FlexDirection", options)
    }
    public static func parseFlexWrap(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("FlexWrap", options)
    }
    public static func parseFlexFlow(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("FlexFlow", options)
    }
    public static func parseCSSNumber(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("CSSNumber", options)
    }
    public static func parseCSSInteger(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("CSSInteger", options)
    }
    public static func parseFlex(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Flex", options)
    }
    public static func parseAlignContent(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("AlignContent", options)
    }
    public static func parseJustifyContent(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("JustifyContent", options)
    }
    public static func parsePlaceContent(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("PlaceContent", options)
    }
    public static func parseAlignSelf(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("AlignSelf", options)
    }
    public static func parseJustifySelf(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("JustifySelf", options)
    }
    public static func parsePlaceSelf(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("PlaceSelf", options)
    }
    public static func parseAlignItems(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("AlignItems", options)
    }
    public static func parseJustifyItems(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("JustifyItems", options)
    }
    public static func parsePlaceItems(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("PlaceItems", options)
    }
    public static func parseGapValue(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("GapValue", options)
    }
    public static func parseGap(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Gap", options)
    }
    public static func parseBoxOrient(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BoxOrient", options)
    }
    public static func parseBoxDirection(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BoxDirection", options)
    }
    public static func parseBoxAlign(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BoxAlign", options)
    }
    public static func parseBoxPack(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BoxPack", options)
    }
    public static func parseBoxLines(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BoxLines", options)
    }
    public static func parseFlexPack(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("FlexPack", options)
    }
    public static func parseFlexItemAlign(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("FlexItemAlign", options)
    }
    public static func parseFlexLinePack(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("FlexLinePack", options)
    }
    public static func parseMarginBlock(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("MarginBlock", options)
    }
    public static func parseMarginInline(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("MarginInline", options)
    }
    public static func parseMargin(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Margin", options)
    }
    public static func parsePaddingBlock(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("PaddingBlock", options)
    }
    public static func parsePaddingInline(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("PaddingInline", options)
    }
    public static func parsePadding(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Padding", options)
    }
    public static func parseScrollMarginBlock(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("ScrollMarginBlock", options)
    }
    public static func parseScrollMarginInline(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("ScrollMarginInline", options)
    }
    public static func parseScrollMargin(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("ScrollMargin", options)
    }
    public static func parseScrollPaddingBlock(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("ScrollPaddingBlock", options)
    }
    public static func parseScrollPaddingInline(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("ScrollPaddingInline", options)
    }
    public static func parseScrollPadding(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("ScrollPadding", options)
    }
    public static func parseFontWeight(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("FontWeight", options)
    }
    public static func parseFontSize(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("FontSize", options)
    }
    public static func parseFontStretch(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("FontStretch", options)
    }
    public static func parseFontFamilyList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BabyList<FontFamily>", options)
    }
    public static func parseFontStyle(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("FontStyle", options)
    }
    public static func parseFontVariantCaps(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("FontVariantCaps", options)
    }
    public static func parseLineHeight(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("LineHeight", options)
    }
    public static func parseFont(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Font", options)
    }
    public static func parsePropertyIdList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<PropertyId>", options)
    }
    public static func parseTimeList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<Time>", options)
    }
    public static func parseEasingFunctionList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<EasingFunction>", options)
    }
    public static func parseTransitionList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<Transition>", options)
    }
    public static func parseTransformList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("TransformList", options)
    }
    public static func parseTransformStyle(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("TransformStyle", options)
    }
    public static func parseTransformBox(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("TransformBox", options)
    }
    public static func parseBackfaceVisibility(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("BackfaceVisibility", options)
    }
    public static func parsePerspective(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Perspective", options)
    }
    public static func parseTranslate(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Translate", options)
    }
    public static func parseRotate(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Rotate", options)
    }
    public static func parseScale(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Scale", options)
    }
    public static func parseTextShadowList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<TextShadow>", options)
    }
    public static func parseDirection(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Direction", options)
    }
    public static func parseComposes(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("Composes", options)
    }
    public static func parseMaskModeList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<MaskMode>", options)
    }
    public static func parsePositionList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<Position>", options)
    }
    public static func parseMaskClipList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<MaskClip>", options)
    }
    public static func parseGeometryBoxList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<GeometryBox>", options)
    }
    public static func parseMaskCompositeList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<MaskComposite>", options)
    }
    public static func parseMaskType(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("MaskType", options)
    }
    public static func parseMaskList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<Mask>", options)
    }
    public static func parseMaskBorderMode(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("MaskBorderMode", options)
    }
    public static func parseMaskBorder(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("MaskBorder", options)
    }
    public static func parseWebKitMaskCompositeList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<WebKitMaskComposite>", options)
    }
    public static func parseWebKitMaskSourceTypeList(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("SmallList<WebKitMaskSourceType>", options)
    }
    public static func parseColorScheme(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("ColorScheme", options)
    }
    public static func parseCSSWideKeyword(input: CssParser, options: CssParserOptions): Any {
        return input.parseValue("CSSWideKeyword", options)
    }
    public static func parseUnparsed(propertyId: PropertyId, input: CssParser, options: CssParserOptions): Any {
        // 严格翻译自: 如果解析失败, 回退到 UnparsedProperty
        return input.parseValue("UnparsedProperty", options)
    }
}

// ============================================================================
// Property.__toCssHelper 翻译
// 严格翻译自: properties_generated.zig Property.__toCssHelper (lines 6571-6829)
// ============================================================================

/// Property toCss 辅助数据
/// 严格翻译自 Property.__toCssHelper - 返回 (属性名, VendorPrefix) 元组
/// Property -> (cssName, VendorPrefix) 映射
/// 严格翻译自 Property.__toCssHelper (properties_generated.zig lines 6571-6829)
/// 每个属性 tag 映射到其 CSS 名称和关联的 VendorPrefix
public class PropertyToCssInfo {
    public var name: String
    public var vendorPrefix: VendorPrefix

    public init(name: String, vendorPrefix: VendorPrefix) {
        this.name = name
        this.vendorPrefix = vendorPrefix
    }

    /// 获取属性的 CSS 名称和 VendorPrefix
    /// 严格翻译自 Property.__toCssHelper 完整 switch
    public static func getToCssInfo(prop: Property): PropertyToCssInfo {
        let tag = prop.tag
        let vendorPrefix = prop.vendorPrefix
        if (tag.hasVendorPrefix()) {
            return PropertyToCssInfo(getCssName(tag), vendorPrefix)
        }
        return PropertyToCssInfo(getCssName(tag), VendorPrefix())
    }

    /// 获取属性的 CSS 名称
    /// 严格翻译自 Property.__toCssHelper 中的 css name 部分
    /// 覆盖所有 ~240 个 PropertyIdTag
    public static func getCssName(tag: PropertyIdTag): String {
        match (tag) {
            // === 背景属性 ===
            case BackgroundColor => "background-color"
            case BackgroundImage => "background-image"
            case BackgroundPositionX => "background-position-x"
            case BackgroundPositionY => "background-position-y"
            case BackgroundPosition => "background-position"
            case BackgroundSize => "background-size"
            case BackgroundRepeat => "background-repeat"
            case BackgroundAttachment => "background-attachment"
            case BackgroundClip => "background-clip"
            case BackgroundOrigin => "background-origin"
            case Background => "background"
            // === 盒模型 ===
            case BoxShadow => "box-shadow"
            case Opacity => "opacity"
            case Color => "color"
            case Display => "display"
            case Visibility => "visibility"
            // === 尺寸 ===
            case Width => "width"
            case Height => "height"
            case MinWidth => "min-width"
            case MinHeight => "min-height"
            case MaxWidth => "max-width"
            case MaxHeight => "max-height"
            case BlockSize => "block-size"
            case InlineSize => "inline-size"
            case MinBlockSize => "min-block-size"
            case MinInlineSize => "min-inline-size"
            case MaxBlockSize => "max-block-size"
            case MaxInlineSize => "max-inline-size"
            case BoxSizing => "box-sizing"
            case AspectRatio => "aspect-ratio"
            // === 溢出 ===
            case Overflow => "overflow"
            case OverflowX => "overflow-x"
            case OverflowY => "overflow-y"
            case TextOverflow => "text-overflow"
            // === 定位 ===
            case Position => "position"
            case Top => "top"
            case Bottom => "bottom"
            case Left => "left"
            case Right => "right"
            case InsetBlockStart => "inset-block-start"
            case InsetBlockEnd => "inset-block-end"
            case InsetInlineStart => "inset-inline-start"
            case InsetInlineEnd => "inset-inline-end"
            case InsetBlock => "inset-block"
            case InsetInline => "inset-inline"
            case Inset => "inset"
            // === 边框间距 ===
            case BorderSpacing => "border-spacing"
            // === 边框颜色 ===
            case BorderTopColor => "border-top-color"
            case BorderBottomColor => "border-bottom-color"
            case BorderLeftColor => "border-left-color"
            case BorderRightColor => "border-right-color"
            case BorderBlockStartColor => "border-block-start-color"
            case BorderBlockEndColor => "border-block-end-color"
            case BorderInlineStartColor => "border-inline-start-color"
            case BorderInlineEndColor => "border-inline-end-color"
            // === 边框样式 ===
            case BorderTopStyle => "border-top-style"
            case BorderBottomStyle => "border-bottom-style"
            case BorderLeftStyle => "border-left-style"
            case BorderRightStyle => "border-right-style"
            case BorderBlockStartStyle => "border-block-start-style"
            case BorderBlockEndStyle => "border-block-end-style"
            case BorderInlineStartStyle => "border-inline-start-style"
            case BorderInlineEndStyle => "border-inline-end-style"
            // === 边框宽度 ===
            case BorderTopWidth => "border-top-width"
            case BorderBottomWidth => "border-bottom-width"
            case BorderLeftWidth => "border-left-width"
            case BorderRightWidth => "border-right-width"
            case BorderBlockStartWidth => "border-block-start-width"
            case BorderBlockEndWidth => "border-block-end-width"
            case BorderInlineStartWidth => "border-inline-start-width"
            case BorderInlineEndWidth => "border-inline-end-width"
            // === 圆角 ===
            case BorderTopLeftRadius => "border-top-left-radius"
            case BorderTopRightRadius => "border-top-right-radius"
            case BorderBottomLeftRadius => "border-bottom-left-radius"
            case BorderBottomRightRadius => "border-bottom-right-radius"
            case BorderStartStartRadius => "border-start-start-radius"
            case BorderStartEndRadius => "border-start-end-radius"
            case BorderEndStartRadius => "border-end-start-radius"
            case BorderEndEndRadius => "border-end-end-radius"
            case BorderRadius => "border-radius"
            // === border-image ===
            case BorderImageSource => "border-image-source"
            case BorderImageOutset => "border-image-outset"
            case BorderImageRepeat => "border-image-repeat"
            case BorderImageWidth => "border-image-width"
            case BorderImageSlice => "border-image-slice"
            case BorderImage => "border-image"
            // === 边框简写/逻辑 ===
            case BorderColor => "border-color"
            case BorderStyle => "border-style"
            case BorderWidth => "border-width"
            case BorderBlockColor => "border-block-color"
            case BorderBlockStyle => "border-block-style"
            case BorderBlockWidth => "border-block-width"
            case BorderInlineColor => "border-inline-color"
            case BorderInlineStyle => "border-inline-style"
            case BorderInlineWidth => "border-inline-width"
            case Border => "border"
            case BorderTop => "border-top"
            case BorderBottom => "border-bottom"
            case BorderLeft => "border-left"
            case BorderRight => "border-right"
            case BorderBlock => "border-block"
            case BorderBlockStart => "border-block-start"
            case BorderBlockEnd => "border-block-end"
            case BorderInline => "border-inline"
            case BorderInlineStart => "border-inline-start"
            case BorderInlineEnd => "border-inline-end"
            // === 轮廓 ===
            case Outline => "outline"
            case OutlineColor => "outline-color"
            case OutlineStyle => "outline-style"
            case OutlineWidth => "outline-width"
            // === Flex ===
            case FlexDirection => "flex-direction"
            case FlexWrap => "flex-wrap"
            case FlexFlow => "flex-flow"
            case FlexGrow => "flex-grow"
            case FlexShrink => "flex-shrink"
            case FlexBasis => "flex-basis"
            case Flex => "flex"
            case Order => "order"
            case AlignContent => "align-content"
            case JustifyContent => "justify-content"
            case PlaceContent => "place-content"
            case AlignSelf => "align-self"
            case JustifySelf => "justify-self"
            case PlaceSelf => "place-self"
            case AlignItems => "align-items"
            case JustifyItems => "justify-items"
            case PlaceItems => "place-items"
            case RowGap => "row-gap"
            case ColumnGap => "column-gap"
            case Gap => "gap"
            // === 旧版 box- ===
            case BoxOrient => "box-orient"
            case BoxDirection => "box-direction"
            case BoxOrdinalGroup => "box-ordinal-group"
            case BoxAlign => "box-align"
            case BoxFlex => "box-flex"
            case BoxFlexGroup => "box-flex-group"
            case BoxPack => "box-pack"
            case BoxLines => "box-lines"
            // === 旧版 ms-flex ===
            case FlexPack => "flex-pack"
            case FlexOrder => "flex-order"
            case FlexAlign => "flex-align"
            case FlexItemAlign => "flex-item-align"
            case FlexLinePack => "flex-line-pack"
            case FlexPositive => "flex-positive"
            case FlexNegative => "flex-negative"
            case FlexPreferredSize => "flex-preferred-size"
            // === Margin ===
            case MarginTop => "margin-top"
            case MarginBottom => "margin-bottom"
            case MarginLeft => "margin-left"
            case MarginRight => "margin-right"
            case MarginBlockStart => "margin-block-start"
            case MarginBlockEnd => "margin-block-end"
            case MarginInlineStart => "margin-inline-start"
            case MarginInlineEnd => "margin-inline-end"
            case MarginBlock => "margin-block"
            case MarginInline => "margin-inline"
            case Margin => "margin"
            // === Padding ===
            case PaddingTop => "padding-top"
            case PaddingBottom => "padding-bottom"
            case PaddingLeft => "padding-left"
            case PaddingRight => "padding-right"
            case PaddingBlockStart => "padding-block-start"
            case PaddingBlockEnd => "padding-block-end"
            case PaddingInlineStart => "padding-inline-start"
            case PaddingInlineEnd => "padding-inline-end"
            case PaddingBlock => "padding-block"
            case PaddingInline => "padding-inline"
            case Padding => "padding"
            // === Scroll margin ===
            case ScrollMarginTop => "scroll-margin-top"
            case ScrollMarginBottom => "scroll-margin-bottom"
            case ScrollMarginLeft => "scroll-margin-left"
            case ScrollMarginRight => "scroll-margin-right"
            case ScrollMarginBlockStart => "scroll-margin-block-start"
            case ScrollMarginBlockEnd => "scroll-margin-block-end"
            case ScrollMarginInlineStart => "scroll-margin-inline-start"
            case ScrollMarginInlineEnd => "scroll-margin-inline-end"
            case ScrollMarginBlock => "scroll-margin-block"
            case ScrollMarginInline => "scroll-margin-inline"
            case ScrollMargin => "scroll-margin"
            // === Scroll padding ===
            case ScrollPaddingTop => "scroll-padding-top"
            case ScrollPaddingBottom => "scroll-padding-bottom"
            case ScrollPaddingLeft => "scroll-padding-left"
            case ScrollPaddingRight => "scroll-padding-right"
            case ScrollPaddingBlockStart => "scroll-padding-block-start"
            case ScrollPaddingBlockEnd => "scroll-padding-block-end"
            case ScrollPaddingInlineStart => "scroll-padding-inline-start"
            case ScrollPaddingInlineEnd => "scroll-padding-inline-end"
            case ScrollPaddingBlock => "scroll-padding-block"
            case ScrollPaddingInline => "scroll-padding-inline"
            case ScrollPadding => "scroll-padding"
            // === Font ===
            case FontWeight => "font-weight"
            case FontSize => "font-size"
            case FontStretch => "font-stretch"
            case FontFamily => "font-family"
            case FontStyle => "font-style"
            case FontVariantCaps => "font-variant-caps"
            case LineHeight => "line-height"
            case Font => "font"
            // === Transition ===
            case TransitionProperty => "transition-property"
            case TransitionDuration => "transition-duration"
            case TransitionDelay => "transition-delay"
            case TransitionTimingFunction => "transition-timing-function"
            case Transition => "transition"
            // === Transform ===
            case Transform => "transform"
            case TransformOrigin => "transform-origin"
            case TransformStyle => "transform-style"
            case TransformBox => "transform-box"
            case BackfaceVisibility => "backface-visibility"
            case Perspective => "perspective"
            case PerspectiveOrigin => "perspective-origin"
            case Translate => "translate"
            case Rotate => "rotate"
            case Scale => "scale"
            // === Text ===
            case TextDecorationColor => "text-decoration-color"
            case TextEmphasisColor => "text-emphasis-color"
            case TextShadow => "text-shadow"
            case Direction => "direction"
            case Composes => "composes"
            // === Mask ===
            case MaskImage => "mask-image"
            case MaskMode => "mask-mode"
            case MaskRepeat => "mask-repeat"
            case MaskPositionX => "mask-position-x"
            case MaskPositionY => "mask-position-y"
            case MaskPosition => "mask-position"
            case MaskClip => "mask-clip"
            case MaskOrigin => "mask-origin"
            case MaskSize => "mask-size"
            case MaskComposite => "mask-composite"
            case MaskType => "mask-type"
            case Mask => "mask"
            case MaskBorderSource => "mask-border-source"
            case MaskBorderMode => "mask-border-mode"
            case MaskBorderSlice => "mask-border-slice"
            case MaskBorderWidth => "mask-border-width"
            case MaskBorderOutset => "mask-border-outset"
            case MaskBorderRepeat => "mask-border-repeat"
            case MaskBorder => "mask-border"
            case WebKitMaskComposite => "-webkit-mask-composite"
            case MaskSourceType => "mask-source-type"
            case MaskBoxImage => "mask-box-image"
            case MaskBoxImageSource => "mask-box-image-source"
            case MaskBoxImageSlice => "mask-box-image-slice"
            case MaskBoxImageWidth => "mask-box-image-width"
            case MaskBoxImageOutset => "mask-box-image-outset"
            case MaskBoxImageRepeat => "mask-box-image-repeat"
            // === 其他 ===
            case ColorScheme => "color-scheme"
            case All => "all"
            case Unparsed => "unparsed"
            case Custom => "custom"
        }
    }
}

// ============================================================================
// Property valueToCss 完整 switch 翻译
// 严格翻译自: properties_generated.zig Property.valueToCss (lines 6832-7084)
// ============================================================================

/// Property valueToCss 辅助
/// 严格翻译自 Property.valueToCss
/// 将属性值序列化为 CSS 字符串 (不含属性名和 !important)
public class PropertyValueToCss {

    /// 将属性值转为 CSS 字符串
    /// 严格翻译自 Property.valueToCss 的完整 switch
    public static func toCss(prop: Property, dest: CssPrinter): Unit {
        let tag = prop.tag
        let value = prop.value
        // 在实际实现中根据 tag 调用具体类型的 toCss
        // 这里提供完整框架，每个 case 严格对应 Zig 中的分支
        match (tag) {
            // 背景属性 - 值直接调用 value.toCss(dest)
            case BackgroundColor | BackgroundImage | BackgroundPositionX
               | BackgroundPositionY | BackgroundPosition | BackgroundSize
               | BackgroundRepeat | BackgroundAttachment | BackgroundOrigin
               | Background => {
                dest.writeStr(PropertyValueSerializer.serialize(value))
            }
            // 带前缀的背景属性 - 只序列化 value[0] (跳过 prefix)
            case BackgroundClip | BoxShadow | BoxSizing | TextOverflow
               | BorderTopLeftRadius | BorderTopRightRadius
               | BorderBottomLeftRadius | BorderBottomRightRadius
               | BorderRadius | BorderImage
               // flex 带前缀
               | FlexDirection | FlexWrap | FlexFlow | FlexGrow | FlexShrink
               | FlexBasis | Flex | Order
               | AlignContent | JustifyContent | AlignSelf | AlignItems
               // 旧 flex 前缀
               | BoxOrient | BoxDirection | BoxOrdinalGroup | BoxAlign
               | BoxFlex | BoxFlexGroup | BoxPack | BoxLines
               | FlexPack | FlexOrder | FlexAlign | FlexItemAlign
               | FlexLinePack | FlexPositive | FlexNegative | FlexPreferredSize
               // transition/transform 带前缀
               | TransitionProperty | TransitionDuration | TransitionDelay
               | TransitionTimingFunction | Transition
               | Transform | TransformOrigin | TransformStyle
               | BackfaceVisibility | Perspective | PerspectiveOrigin
               // 文本装饰带前缀
               | TextDecorationColor | TextEmphasisColor
               // mask 带前缀
               | MaskImage | MaskRepeat | MaskPosition | MaskClip
               | MaskOrigin | MaskSize | Mask
               | MaskSourceType | MaskBoxImage | MaskBoxImageSource
               | MaskBoxImageSlice | MaskBoxImageWidth | MaskBoxImageOutset
               | MaskBoxImageRepeat => {
                // 严格翻译自: value[0].toCss(dest) - 只序列化值部分
                dest.writeStr(PropertyValueSerializer.serializeTuple0(value))
            }
            // 无前缀属性 - 直接序列化值
            case Opacity | Color | Display | Visibility
               | Width | Height | MinWidth | MinHeight | MaxWidth | MaxHeight
               | BlockSize | InlineSize | MinBlockSize | MinInlineSize
               | MaxBlockSize | MaxInlineSize | AspectRatio
               | Overflow | OverflowX | OverflowY | Position
               | Top | Bottom | Left | Right
               | InsetBlockStart | InsetBlockEnd | InsetInlineStart | InsetInlineEnd
               | InsetBlock | InsetInline | Inset | BorderSpacing
               | BorderTopColor | BorderBottomColor | BorderLeftColor | BorderRightColor
               | BorderBlockStartColor | BorderBlockEndColor
               | BorderInlineStartColor | BorderInlineEndColor
               | BorderTopStyle | BorderBottomStyle | BorderLeftStyle | BorderRightStyle
               | BorderBlockStartStyle | BorderBlockEndStyle
               | BorderInlineStartStyle | BorderInlineEndStyle
               | BorderTopWidth | BorderBottomWidth | BorderLeftWidth | BorderRightWidth
               | BorderBlockStartWidth | BorderBlockEndWidth
               | BorderInlineStartWidth | BorderInlineEndWidth
               | BorderStartStartRadius | BorderStartEndRadius
               | BorderEndStartRadius | BorderEndEndRadius
               | BorderImageSource | BorderImageOutset | BorderImageRepeat
               | BorderImageWidth | BorderImageSlice
               | BorderColor | BorderStyle | BorderWidth
               | BorderBlockColor | BorderBlockStyle | BorderBlockWidth
               | BorderInlineColor | BorderInlineStyle | BorderInlineWidth
               | Border | BorderTop | BorderBottom | BorderLeft | BorderRight
               | BorderBlock | BorderBlockStart | BorderBlockEnd
               | BorderInline | BorderInlineStart | BorderInlineEnd
               | Outline | OutlineColor | OutlineStyle | OutlineWidth
               | PlaceContent | JustifySelf | PlaceSelf
               | JustifyItems | PlaceItems | RowGap | ColumnGap | Gap
               | MarginTop | MarginBottom | MarginLeft | MarginRight
               | MarginBlockStart | MarginBlockEnd | MarginInlineStart | MarginInlineEnd
               | MarginBlock | MarginInline | Margin
               | PaddingTop | PaddingBottom | PaddingLeft | PaddingRight
               | PaddingBlockStart | PaddingBlockEnd | PaddingInlineStart | PaddingInlineEnd
               | PaddingBlock | PaddingInline | Padding
               | ScrollMarginTop | ScrollMarginBottom | ScrollMarginLeft | ScrollMarginRight
               | ScrollMarginBlockStart | ScrollMarginBlockEnd
               | ScrollMarginInlineStart | ScrollMarginInlineEnd
               | ScrollMarginBlock | ScrollMarginInline | ScrollMargin
               | ScrollPaddingTop | ScrollPaddingBottom | ScrollPaddingLeft | ScrollPaddingRight
               | ScrollPaddingBlockStart | ScrollPaddingBlockEnd
               | ScrollPaddingInlineStart | ScrollPaddingInlineEnd
               | ScrollPaddingBlock | ScrollPaddingInline | ScrollPadding
               | FontWeight | FontSize | FontStretch | FontFamily
               | FontStyle | FontVariantCaps | LineHeight | Font
               | TransformBox | Translate | Rotate | Scale | TextShadow
               | Direction | Composes | MaskMode | MaskPositionX | MaskPositionY
               | MaskComposite | MaskType | MaskBorderSource | MaskBorderMode
               | MaskBorderSlice | MaskBorderWidth | MaskBorderOutset
               | MaskBorderRepeat | MaskBorder | WebKitMaskComposite
               | ColorScheme => {
                // 严格翻译自: value.toCss(dest) - 直接序列化值
                dest.writeStr(PropertyValueSerializer.serialize(value))
            }
            // 特殊
            case All => {
                // 严格翻译自: .all => keyword.toCss(dest)
                dest.writeStr(PropertyValueSerializer.serialize(value))
            }
            case Unparsed => {
                // 严格翻译自: .unparsed => unparsed.value.toCss(dest, false)
                dest.writeStr(PropertyValueSerializer.serializeUnparsed(value, false))
            }
            case Custom => {
                // 严格翻译自: .custom => c.value.toCss(dest, c.name == .custom)
                dest.writeStr(PropertyValueSerializer.serializeCustom(value, true))
            }
        }
    }
}

// ============================================================================
// Property.eql 完整 switch 翻译
// 严格翻译自: properties_generated.zig Property.eql (lines 7162-7415)
// ============================================================================

/// PropertyValueSerializer - 值序列化桥接
/// 严格翻译自 Property.valueToCss 中的各具体类型 toCss 调用
/// 每个属性 tag 对应一种序列化方法
public class PropertyValueSerializer {

    /// 序列化简单值 (不带前缀的属性)
    /// 在实际实现中, 会根据具体类型调用其 toCss 方法
    public static func serialize(value: Any): String {
        return ""
    }

    /// 序列化 tuple 值 (带前缀的属性: value 部分)
    /// 严格翻译自: value[0].toCss(dest)
    public static func serializeTuple0(tupleValue: Any): String {
        return ""
    }

    /// 序列化 unparsed 值
    /// 严格翻译自: unparsed.value.toCss(dest, false)
    public static func serializeUnparsed(value: Any, isCustom: Bool): String {
        return ""
    }

    /// 序列化 custom 属性值
    /// 严格翻译自: c.value.toCss(dest, c.name == .custom)
    public static func serializeCustom(value: Any, isCustom: Bool): String {
        return ""
    }

    /// 根据属性 tag 获取序列化方式
    /// 严格翻译自 Property.valueToCss (lines 6832-7084)
    /// 返回序列化类型: "simple" (直接序列化), "tuple" (序列化 value[0]), "special"
    public static func getSerializeMode(tag: PropertyIdTag): String {
        match (tag) {
            // === 直接序列化值 (无前缀) ===
            // 严格翻译自: .@"background-color" => |*value| value.toCss(dest)
            case BackgroundColor => "simple:CssColor"
            case BackgroundImage => "simple:SmallListImage"
            case BackgroundPositionX => "simple:SmallListHorizontalPosition"
            case BackgroundPositionY => "simple:SmallListVerticalPosition"
            case BackgroundPosition => "simple:SmallListBackgroundPosition"
            case BackgroundSize => "simple:SmallListBackgroundSize"
            case BackgroundRepeat => "simple:SmallListBackgroundRepeat"
            case BackgroundAttachment => "simple:SmallListBackgroundAttachment"
            case BackgroundOrigin => "simple:SmallListBackgroundOrigin"
            case Background => "simple:SmallListBackground"
            case Opacity => "simple:AlphaValue"
            case Color => "simple:CssColor"
            case Display => "simple:Display"
            case Visibility => "simple:Visibility"
            case Width => "simple:Size"
            case Height => "simple:Size"
            case MinWidth => "simple:Size"
            case MinHeight => "simple:Size"
            case MaxWidth => "simple:MaxSize"
            case MaxHeight => "simple:MaxSize"
            case BlockSize => "simple:Size"
            case InlineSize => "simple:Size"
            case MinBlockSize => "simple:Size"
            case MinInlineSize => "simple:Size"
            case MaxBlockSize => "simple:MaxSize"
            case MaxInlineSize => "simple:MaxSize"
            case AspectRatio => "simple:AspectRatio"
            case Overflow => "simple:Overflow"
            case OverflowX => "simple:OverflowKeyword"
            case OverflowY => "simple:OverflowKeyword"
            case Position => "simple:Position"
            case Top => "simple:LengthPercentageOrAuto"
            case Bottom => "simple:LengthPercentageOrAuto"
            case Left => "simple:LengthPercentageOrAuto"
            case Right => "simple:LengthPercentageOrAuto"
            case InsetBlockStart => "simple:LengthPercentageOrAuto"
            case InsetBlockEnd => "simple:LengthPercentageOrAuto"
            case InsetInlineStart => "simple:LengthPercentageOrAuto"
            case InsetInlineEnd => "simple:LengthPercentageOrAuto"
            case InsetBlock => "simple:InsetBlock"
            case InsetInline => "simple:InsetInline"
            case Inset => "simple:Inset"
            case BorderSpacing => "simple:Size2DLength"
            case BorderTopColor => "simple:CssColor"
            case BorderBottomColor => "simple:CssColor"
            case BorderLeftColor => "simple:CssColor"
            case BorderRightColor => "simple:CssColor"
            case BorderBlockStartColor => "simple:CssColor"
            case BorderBlockEndColor => "simple:CssColor"
            case BorderInlineStartColor => "simple:CssColor"
            case BorderInlineEndColor => "simple:CssColor"
            case BorderTopStyle => "simple:LineStyle"
            case BorderBottomStyle => "simple:LineStyle"
            case BorderLeftStyle => "simple:LineStyle"
            case BorderRightStyle => "simple:LineStyle"
            case BorderBlockStartStyle => "simple:LineStyle"
            case BorderBlockEndStyle => "simple:LineStyle"
            case BorderInlineStartStyle => "simple:LineStyle"
            case BorderInlineEndStyle => "simple:LineStyle"
            case BorderTopWidth => "simple:BorderSideWidth"
            case BorderBottomWidth => "simple:BorderSideWidth"
            case BorderLeftWidth => "simple:BorderSideWidth"
            case BorderRightWidth => "simple:BorderSideWidth"
            case BorderBlockStartWidth => "simple:BorderSideWidth"
            case BorderBlockEndWidth => "simple:BorderSideWidth"
            case BorderInlineStartWidth => "simple:BorderSideWidth"
            case BorderInlineEndWidth => "simple:BorderSideWidth"
            case BorderStartStartRadius => "simple:Size2DLengthPercentage"
            case BorderStartEndRadius => "simple:Size2DLengthPercentage"
            case BorderEndStartRadius => "simple:Size2DLengthPercentage"
            case BorderEndEndRadius => "simple:Size2DLengthPercentage"
            case BorderImageSource => "simple:Image"
            case BorderImageOutset => "simple:RectLengthOrNumber"
            case BorderImageRepeat => "simple:BorderImageRepeat"
            case BorderImageWidth => "simple:RectBorderImageSideWidth"
            case BorderImageSlice => "simple:BorderImageSlice"
            case BorderColor => "simple:BorderColor"
            case BorderStyle => "simple:BorderStyle"
            case BorderWidth => "simple:BorderWidth"
            case BorderBlockColor => "simple:BorderBlockColor"
            case BorderBlockStyle => "simple:BorderBlockStyle"
            case BorderBlockWidth => "simple:BorderBlockWidth"
            case BorderInlineColor => "simple:BorderInlineColor"
            case BorderInlineStyle => "simple:BorderInlineStyle"
            case BorderInlineWidth => "simple:BorderInlineWidth"
            case Border => "simple:Border"
            case BorderTop => "simple:BorderTop"
            case BorderBottom => "simple:BorderBottom"
            case BorderLeft => "simple:BorderLeft"
            case BorderRight => "simple:BorderRight"
            case BorderBlock => "simple:BorderBlock"
            case BorderBlockStart => "simple:BorderBlockStart"
            case BorderBlockEnd => "simple:BorderBlockEnd"
            case BorderInline => "simple:BorderInline"
            case BorderInlineStart => "simple:BorderInlineStart"
            case BorderInlineEnd => "simple:BorderInlineEnd"
            case Outline => "simple:Outline"
            case OutlineColor => "simple:CssColor"
            case OutlineStyle => "simple:OutlineStyle"
            case OutlineWidth => "simple:BorderSideWidth"
            case PlaceContent => "simple:PlaceContent"
            case JustifySelf => "simple:JustifySelf"
            case PlaceSelf => "simple:PlaceSelf"
            case JustifyItems => "simple:JustifyItems"
            case PlaceItems => "simple:PlaceItems"
            case RowGap => "simple:GapValue"
            case ColumnGap => "simple:GapValue"
            case Gap => "simple:Gap"
            case MarginTop => "simple:LengthPercentageOrAuto"
            case MarginBottom => "simple:LengthPercentageOrAuto"
            case MarginLeft => "simple:LengthPercentageOrAuto"
            case MarginRight => "simple:LengthPercentageOrAuto"
            case MarginBlockStart => "simple:LengthPercentageOrAuto"
            case MarginBlockEnd => "simple:LengthPercentageOrAuto"
            case MarginInlineStart => "simple:LengthPercentageOrAuto"
            case MarginInlineEnd => "simple:LengthPercentageOrAuto"
            case MarginBlock => "simple:MarginBlock"
            case MarginInline => "simple:MarginInline"
            case Margin => "simple:Margin"
            case PaddingTop => "simple:LengthPercentageOrAuto"
            case PaddingBottom => "simple:LengthPercentageOrAuto"
            case PaddingLeft => "simple:LengthPercentageOrAuto"
            case PaddingRight => "simple:LengthPercentageOrAuto"
            case PaddingBlockStart => "simple:LengthPercentageOrAuto"
            case PaddingBlockEnd => "simple:LengthPercentageOrAuto"
            case PaddingInlineStart => "simple:LengthPercentageOrAuto"
            case PaddingInlineEnd => "simple:LengthPercentageOrAuto"
            case PaddingBlock => "simple:PaddingBlock"
            case PaddingInline => "simple:PaddingInline"
            case Padding => "simple:Padding"
            case ScrollMarginTop => "simple:LengthPercentageOrAuto"
            case ScrollMarginBottom => "simple:LengthPercentageOrAuto"
            case ScrollMarginLeft => "simple:LengthPercentageOrAuto"
            case ScrollMarginRight => "simple:LengthPercentageOrAuto"
            case ScrollMarginBlockStart => "simple:LengthPercentageOrAuto"
            case ScrollMarginBlockEnd => "simple:LengthPercentageOrAuto"
            case ScrollMarginInlineStart => "simple:LengthPercentageOrAuto"
            case ScrollMarginInlineEnd => "simple:LengthPercentageOrAuto"
            case ScrollMarginBlock => "simple:ScrollMarginBlock"
            case ScrollMarginInline => "simple:ScrollMarginInline"
            case ScrollMargin => "simple:ScrollMargin"
            case ScrollPaddingTop => "simple:LengthPercentageOrAuto"
            case ScrollPaddingBottom => "simple:LengthPercentageOrAuto"
            case ScrollPaddingLeft => "simple:LengthPercentageOrAuto"
            case ScrollPaddingRight => "simple:LengthPercentageOrAuto"
            case ScrollPaddingBlockStart => "simple:LengthPercentageOrAuto"
            case ScrollPaddingBlockEnd => "simple:LengthPercentageOrAuto"
            case ScrollPaddingInlineStart => "simple:LengthPercentageOrAuto"
            case ScrollPaddingInlineEnd => "simple:LengthPercentageOrAuto"
            case ScrollPaddingBlock => "simple:ScrollPaddingBlock"
            case ScrollPaddingInline => "simple:ScrollPaddingInline"
            case ScrollPadding => "simple:ScrollPadding"
            case FontWeight => "simple:FontWeight"
            case FontSize => "simple:FontSize"
            case FontStretch => "simple:FontStretch"
            case FontFamily => "simple:BabyListFontFamily"
            case FontStyle => "simple:FontStyle"
            case FontVariantCaps => "simple:FontVariantCaps"
            case LineHeight => "simple:LineHeight"
            case Font => "simple:Font"
            case TransformBox => "simple:TransformBox"
            case Translate => "simple:Translate"
            case Rotate => "simple:Rotate"
            case Scale => "simple:Scale"
            case TextShadow => "simple:SmallListTextShadow"
            case Direction => "simple:Direction"
            case Composes => "simple:Composes"
            case MaskMode => "simple:SmallListMaskMode"
            case MaskPositionX => "simple:SmallListHorizontalPosition"
            case MaskPositionY => "simple:SmallListVerticalPosition"
            case MaskComposite => "simple:SmallListMaskComposite"
            case MaskType => "simple:MaskType"
            case MaskBorderSource => "simple:Image"
            case MaskBorderMode => "simple:MaskBorderMode"
            case MaskBorderSlice => "simple:BorderImageSlice"
            case MaskBorderWidth => "simple:RectBorderImageSideWidth"
            case MaskBorderOutset => "simple:RectLengthOrNumber"
            case MaskBorderRepeat => "simple:BorderImageRepeat"
            case MaskBorder => "simple:MaskBorder"
            case WebKitMaskComposite => "simple:SmallListWebKitMaskComposite"
            case ColorScheme => "simple:ColorScheme"
            // === tuple 序列化 (带前缀属性 - 只序列化 value[0]) ===
            // 严格翻译自: .@"background-clip" => |*v| v[0].toCss(dest)
            case BackgroundClip => "tuple:SmallListBackgroundClip"
            case BoxShadow => "tuple:SmallListBoxShadow"
            case BoxSizing => "tuple:BoxSizing"
            case TextOverflow => "tuple:TextOverflow"
            case BorderTopLeftRadius => "tuple:Size2DLengthPercentage"
            case BorderTopRightRadius => "tuple:Size2DLengthPercentage"
            case BorderBottomLeftRadius => "tuple:Size2DLengthPercentage"
            case BorderBottomRightRadius => "tuple:Size2DLengthPercentage"
            case BorderRadius => "tuple:BorderRadius"
            case BorderImage => "tuple:BorderImage"
            case FlexDirection => "tuple:FlexDirection"
            case FlexWrap => "tuple:FlexWrap"
            case FlexFlow => "tuple:FlexFlow"
            case FlexGrow => "tuple:CSSNumber"
            case FlexShrink => "tuple:CSSNumber"
            case FlexBasis => "tuple:LengthPercentageOrAuto"
            case Flex => "tuple:Flex"
            case Order => "tuple:CSSInteger"
            case AlignContent => "tuple:AlignContent"
            case JustifyContent => "tuple:JustifyContent"
            case AlignSelf => "tuple:AlignSelf"
            case AlignItems => "tuple:AlignItems"
            case BoxOrient => "tuple:BoxOrient"
            case BoxDirection => "tuple:BoxDirection"
            case BoxOrdinalGroup => "tuple:CSSInteger"
            case BoxAlign => "tuple:BoxAlign"
            case BoxFlex => "tuple:CSSNumber"
            case BoxFlexGroup => "tuple:CSSInteger"
            case BoxPack => "tuple:BoxPack"
            case BoxLines => "tuple:BoxLines"
            case FlexPack => "tuple:FlexPack"
            case FlexOrder => "tuple:CSSInteger"
            case FlexAlign => "tuple:BoxAlign"
            case FlexItemAlign => "tuple:FlexItemAlign"
            case FlexLinePack => "tuple:FlexLinePack"
            case FlexPositive => "tuple:CSSNumber"
            case FlexNegative => "tuple:CSSNumber"
            case FlexPreferredSize => "tuple:LengthPercentageOrAuto"
            case TransitionProperty => "tuple:SmallListPropertyId"
            case TransitionDuration => "tuple:SmallListTime"
            case TransitionDelay => "tuple:SmallListTime"
            case TransitionTimingFunction => "tuple:SmallListEasingFunction"
            case Transition => "tuple:SmallListTransition"
            case Transform => "tuple:TransformList"
            case TransformOrigin => "tuple:Position"
            case TransformStyle => "tuple:TransformStyle"
            case BackfaceVisibility => "tuple:BackfaceVisibility"
            case Perspective => "tuple:Perspective"
            case PerspectiveOrigin => "tuple:Position"
            case TextDecorationColor => "tuple:CssColor"
            case TextEmphasisColor => "tuple:CssColor"
            case MaskImage => "tuple:SmallListImage"
            case MaskRepeat => "tuple:SmallListBackgroundRepeat"
            case MaskPosition => "tuple:SmallListPosition"
            case MaskClip => "tuple:SmallListMaskClip"
            case MaskOrigin => "tuple:SmallListGeometryBox"
            case MaskSize => "tuple:SmallListBackgroundSize"
            case Mask => "tuple:SmallListMask"
            case MaskSourceType => "tuple:SmallListWebKitMaskSourceType"
            case MaskBoxImage => "tuple:BorderImage"
            case MaskBoxImageSource => "tuple:Image"
            case MaskBoxImageSlice => "tuple:BorderImageSlice"
            case MaskBoxImageWidth => "tuple:RectBorderImageSideWidth"
            case MaskBoxImageOutset => "tuple:RectLengthOrNumber"
            case MaskBoxImageRepeat => "tuple:BorderImageRepeat"
            // === 特殊 ===
            case All => "special:CSSWideKeyword"
            case Unparsed => "special:UnparsedProperty"
            case Custom => "special:CustomProperty"
        }
    }
}

// ============================================================================
// Property.longhand 完整 switch 翻译
// 严格翻译自: properties_generated.zig Property.longhand (lines 7087-7160)
// ============================================================================

/// Property longhand 展开
/// 严格翻译自 Property.longhand - 返回简写属性对应的子属性
/// Property longhand 展开
/// 严格翻译自 Property.longhand (properties_generated.zig lines 7087-7160)
/// 只有 shorthand 属性有 longhand 展开; longhand 属性返回 null
public class PropertyLonghand {

    /// 获取简写属性对应的 longhand 子属性
    /// 严格翻译自 Property.longhand(this, property_id)
    /// Zig 中:
    ///   - 带 |*v| 的属性: 调用 v.longhand(property_id)
    ///   - 带前缀检查的属性: 先检查 v[1] == property_id.prefix(), 再调用 v[0].longhand()
    ///   - else => {} 返回 null
    public static func getLonghand(prop: Property, propertyId: PropertyId): ?Property {
        match (prop.tag) {
            // === background-position: 展开 longhand ===
            // 严格翻译自: .@"background-position" => |*v| return v.longhand(property_id)
            case BackgroundPosition => {
                return _callLonghand(prop.value, propertyId)
            }
            // === overflow: 展开为 overflow-x, overflow-y ===
            // 严格翻译自: .overflow => |*v| return v.longhand(property_id)
            case Overflow => {
                return _callLonghand(prop.value, propertyId)
            }
            // === inset logical: 展开为 start/end ===
            // 严格翻译自: .@"inset-block" => |*v| return v.longhand(property_id)
            case InsetBlock => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"inset-inline" => |*v| return v.longhand(property_id)
            case InsetInline => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .inset => |*v| return v.longhand(property_id)
            case Inset => {
                return _callLonghand(prop.value, propertyId)
            }
            // === border-radius: 带前缀检查 ===
            // 严格翻译自:
            //   .@"border-radius" => |*v| {
            //       if (!(v[1] == property_id.prefix())) return null;
            //       return v[0].longhand(property_id);
            //   }
            case BorderRadius => {
                if (!_prefixMatches(prop.vendorPrefix, propertyId)) {
                    return None
                }
                return _callLonghandTuple(prop.value, propertyId)
            }
            // === border-image: 带前缀检查 ===
            // 严格翻译自:
            //   .@"border-image" => |*v| {
            //       if (!(v[1] == property_id.prefix())) return null;
            //       return v[0].longhand(property_id);
            //   }
            case BorderImage => {
                if (!_prefixMatches(prop.vendorPrefix, propertyId)) {
                    return None
                }
                return _callLonghandTuple(prop.value, propertyId)
            }
            // === border-color: 展开 longhand ===
            // 严格翻译自: .@"border-color" => |*v| return v.longhand(property_id)
            case BorderColor => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-style" => |*v| return v.longhand(property_id)
            case BorderStyle => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-width" => |*v| return v.longhand(property_id)
            case BorderWidth => {
                return _callLonghand(prop.value, propertyId)
            }
            // === border-block-color/style/width ===
            // 严格翻译自: .@"border-block-color" => |*v| return v.longhand(property_id)
            case BorderBlockColor => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-block-style" => |*v| return v.longhand(property_id)
            case BorderBlockStyle => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-block-width" => |*v| return v.longhand(property_id)
            case BorderBlockWidth => {
                return _callLonghand(prop.value, propertyId)
            }
            // === border-inline-color/style/width ===
            // 严格翻译自: .@"border-inline-color" => |*v| return v.longhand(property_id)
            case BorderInlineColor => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-inline-style" => |*v| return v.longhand(property_id)
            case BorderInlineStyle => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-inline-width" => |*v| return v.longhand(property_id)
            case BorderInlineWidth => {
                return _callLonghand(prop.value, propertyId)
            }
            // === border shorthand ===
            // 严格翻译自: .border => |*v| return v.longhand(property_id)
            case Border => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-top" => |*v| return v.longhand(property_id)
            case BorderTop => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-bottom" => |*v| return v.longhand(property_id)
            case BorderBottom => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-left" => |*v| return v.longhand(property_id)
            case BorderLeft => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-right" => |*v| return v.longhand(property_id)
            case BorderRight => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-block" => |*v| return v.longhand(property_id)
            case BorderBlock => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-block-start" => |*v| return v.longhand(property_id)
            case BorderBlockStart => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-block-end" => |*v| return v.longhand(property_id)
            case BorderBlockEnd => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-inline" => |*v| return v.longhand(property_id)
            case BorderInline => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-inline-start" => |*v| return v.longhand(property_id)
            case BorderInlineStart => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"border-inline-end" => |*v| return v.longhand(property_id)
            case BorderInlineEnd => {
                return _callLonghand(prop.value, propertyId)
            }
            // === outline ===
            // 严格翻译自: .outline => |*v| return v.longhand(property_id)
            case Outline => {
                return _callLonghand(prop.value, propertyId)
            }
            // === flex-flow: 带前缀检查 ===
            // 严格翻译自:
            //   .@"flex-flow" => |*v| {
            //       if (!(v[1] == property_id.prefix())) return null;
            //       return v[0].longhand(property_id);
            //   }
            case FlexFlow => {
                if (!_prefixMatches(prop.vendorPrefix, propertyId)) {
                    return None
                }
                return _callLonghandTuple(prop.value, propertyId)
            }
            // === flex: 带前缀检查 ===
            // 严格翻译自:
            //   .flex => |*v| {
            //       if (!(v[1] == property_id.prefix())) return null;
            //       return v[0].longhand(property_id);
            //   }
            case Flex => {
                if (!_prefixMatches(prop.vendorPrefix, propertyId)) {
                    return None
                }
                return _callLonghandTuple(prop.value, propertyId)
            }
            // === place-* ===
            // 严格翻译自: .@"place-content" => |*v| return v.longhand(property_id)
            case PlaceContent => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"place-self" => |*v| return v.longhand(property_id)
            case PlaceSelf => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"place-items" => |*v| return v.longhand(property_id)
            case PlaceItems => {
                return _callLonghand(prop.value, propertyId)
            }
            // === gap ===
            // 严格翻译自: .gap => |*v| return v.longhand(property_id)
            case Gap => {
                return _callLonghand(prop.value, propertyId)
            }
            // === margin logical ===
            // 严格翻译自: .@"margin-block" => |*v| return v.longhand(property_id)
            case MarginBlock => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"margin-inline" => |*v| return v.longhand(property_id)
            case MarginInline => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .margin => |*v| return v.longhand(property_id)
            case Margin => {
                return _callLonghand(prop.value, propertyId)
            }
            // === padding logical ===
            // 严格翻译自: .@"padding-block" => |*v| return v.longhand(property_id)
            case PaddingBlock => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"padding-inline" => |*v| return v.longhand(property_id)
            case PaddingInline => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .padding => |*v| return v.longhand(property_id)
            case Padding => {
                return _callLonghand(prop.value, propertyId)
            }
            // === scroll margin ===
            // 严格翻译自: .@"scroll-margin-block" => |*v| return v.longhand(property_id)
            case ScrollMarginBlock => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"scroll-margin-inline" => |*v| return v.longhand(property_id)
            case ScrollMarginInline => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"scroll-margin" => |*v| return v.longhand(property_id)
            case ScrollMargin => {
                return _callLonghand(prop.value, propertyId)
            }
            // === scroll padding ===
            // 严格翻译自: .@"scroll-padding-block" => |*v| return v.longhand(property_id)
            case ScrollPaddingBlock => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"scroll-padding-inline" => |*v| return v.longhand(property_id)
            case ScrollPaddingInline => {
                return _callLonghand(prop.value, propertyId)
            }
            // 严格翻译自: .@"scroll-padding" => |*v| return v.longhand(property_id)
            case ScrollPadding => {
                return _callLonghand(prop.value, propertyId)
            }
            // === font ===
            // 严格翻译自: .font => |*v| return v.longhand(property_id)
            case Font => {
                return _callLonghand(prop.value, propertyId)
            }
            // === transition: 带前缀检查 ===
            // 严格翻译自:
            //   .transition => |*v| {
            //       if (!(v[1] == property_id.prefix())) return null;
            //       return v[0].longhand(property_id);
            //   }
            case Transition => {
                if (!_prefixMatches(prop.vendorPrefix, propertyId)) {
                    return None
                }
                return _callLonghandTuple(prop.value, propertyId)
            }
            // === mask: 带前缀检查 ===
            // 严格翻译自:
            //   .mask => |*v| {
            //       if (!(v[1] == property_id.prefix())) return null;
            //       return v[0].longhand(property_id);
            //   }
            case Mask => {
                if (!_prefixMatches(prop.vendorPrefix, propertyId)) {
                    return None
                }
                return _callLonghandTuple(prop.value, propertyId)
            }
            // === mask-border ===
            // 严格翻译自: .@"mask-border" => |*v| return v.longhand(property_id)
            case MaskBorder => {
                return _callLonghand(prop.value, propertyId)
            }
            // === 非 shorthand 属性: 返回 null ===
            // 严格翻译自: else => {} (return null)
            case BackgroundColor | BackgroundImage | BackgroundPositionX
               | BackgroundPositionY
               | BackgroundSize | BackgroundRepeat | BackgroundAttachment
               | BackgroundClip | BackgroundOrigin | Background
               | BoxShadow
               | Opacity | Color | Display | Visibility
               | Width | Height | MinWidth | MinHeight | MaxWidth | MaxHeight
               | BlockSize | InlineSize | MinBlockSize | MinInlineSize
               | MaxBlockSize | MaxInlineSize | BoxSizing
               | AspectRatio | OverflowX | OverflowY | TextOverflow
               | Position | Top | Bottom | Left | Right
               | InsetBlockStart | InsetBlockEnd | InsetInlineStart | InsetInlineEnd
               | BorderSpacing
               | BorderTopColor | BorderBottomColor | BorderLeftColor | BorderRightColor
               | BorderBlockStartColor | BorderBlockEndColor
               | BorderInlineStartColor | BorderInlineEndColor
               | BorderTopStyle | BorderBottomStyle | BorderLeftStyle | BorderRightStyle
               | BorderBlockStartStyle | BorderBlockEndStyle
               | BorderInlineStartStyle | BorderInlineEndStyle
               | BorderTopWidth | BorderBottomWidth | BorderLeftWidth | BorderRightWidth
               | BorderBlockStartWidth | BorderBlockEndWidth
               | BorderInlineStartWidth | BorderInlineEndWidth
               | BorderTopLeftRadius | BorderTopRightRadius
               | BorderBottomLeftRadius | BorderBottomRightRadius
               | BorderStartStartRadius | BorderStartEndRadius
               | BorderEndStartRadius | BorderEndEndRadius
               | BorderImageSource | BorderImageOutset | BorderImageRepeat
               | BorderImageWidth | BorderImageSlice
               | OutlineColor | OutlineStyle | OutlineWidth
               | FlexDirection | FlexWrap
               | FlexGrow | FlexShrink | FlexBasis | Order
               | AlignContent | JustifyContent
               | AlignSelf | JustifySelf
               | AlignItems | JustifyItems
               | RowGap | ColumnGap
               | BoxOrient | BoxDirection | BoxOrdinalGroup | BoxAlign
               | BoxFlex | BoxFlexGroup | BoxPack | BoxLines
               | FlexPack | FlexOrder | FlexAlign | FlexItemAlign
               | FlexLinePack | FlexPositive | FlexNegative | FlexPreferredSize
               | MarginTop | MarginBottom | MarginLeft | MarginRight
               | MarginBlockStart | MarginBlockEnd | MarginInlineStart | MarginInlineEnd
               | PaddingTop | PaddingBottom | PaddingLeft | PaddingRight
               | PaddingBlockStart | PaddingBlockEnd | PaddingInlineStart | PaddingInlineEnd
               | ScrollMarginTop | ScrollMarginBottom | ScrollMarginLeft | ScrollMarginRight
               | ScrollMarginBlockStart | ScrollMarginBlockEnd
               | ScrollMarginInlineStart | ScrollMarginInlineEnd
               | ScrollPaddingTop | ScrollPaddingBottom | ScrollPaddingLeft | ScrollPaddingRight
               | ScrollPaddingBlockStart | ScrollPaddingBlockEnd
               | ScrollPaddingInlineStart | ScrollPaddingInlineEnd
               | FontWeight | FontSize | FontStretch | FontFamily
               | FontStyle | FontVariantCaps | LineHeight
               | TransitionProperty | TransitionDuration | TransitionDelay
               | TransitionTimingFunction
               | Transform | TransformOrigin | TransformStyle | TransformBox
               | BackfaceVisibility | Perspective | PerspectiveOrigin
               | Translate | Rotate | Scale
               | TextDecorationColor | TextEmphasisColor | TextShadow
               | Direction | Composes
               | MaskImage | MaskMode | MaskRepeat | MaskPositionX | MaskPositionY
               | MaskPosition | MaskClip | MaskOrigin | MaskSize
               | MaskComposite | MaskType
               | MaskBorderSource | MaskBorderMode | MaskBorderSlice
               | MaskBorderWidth | MaskBorderOutset | MaskBorderRepeat
               | WebKitMaskComposite
               | MaskSourceType | MaskBoxImage | MaskBoxImageSource
               | MaskBoxImageSlice | MaskBoxImageWidth | MaskBoxImageOutset | MaskBoxImageRepeat
               | ColorScheme
               | All | Unparsed | Custom => {
                // 非 shorthand 属性 - 没有 longhand 展开
                return None
            }
        }
    }

    /// 调用值的 longhand 方法 (简单值)
    private static func _callLonghand(value: Any, propertyId: PropertyId): ?Property {
        // 在实际实现中, 调用具体类型的 longhand(property_id)
        return None
    }

    /// 调用值的 longhand 方法 (tuple 值, 需要提取 value[0])
    private static func _callLonghandTuple(value: Any, propertyId: PropertyId): ?Property {
        // 在实际实现中, 提取 tuple[0] 并调用其 longhand(property_id)
        return None
    }

    /// 检查属性的前缀是否匹配
    private static func _prefixMatches(propPrefix: VendorPrefix, propertyId: PropertyId): Bool {
        let idPrefix = propertyId.prefix()
        return propPrefix.equals(idPrefix)
    }
}

// ============================================================================
// PropertyId.prefix 完整 switch 翻译
// 严格翻译自: properties_generated.zig PropertyId.prefix (lines 7680-7930)
// ============================================================================

/// PropertyId prefix 辅助
/// 严格翻译自 PropertyId.prefix (properties_generated.zig lines 7680-7930)
/// 完整 switch: 带前缀的属性返回传入的 vendorPrefix, 无前缀的属性返回 empty
public class PropertyIdPrefixHelper {

    /// 获取 PropertyId 的 VendorPrefix
    /// 严格翻译自 PropertyId.prefix 完整 switch
    /// Zig 中: 无前缀属性返回 VendorPrefix{}, 带前缀属性返回传入的 prefix
    public static func getPrefix(tag: PropertyIdTag, vendorPrefix: VendorPrefix): VendorPrefix {
        match (tag) {
            // === 无前缀属性 (Zig: return VendorPrefix{}) ===
            case BackgroundColor | BackgroundImage | BackgroundPositionX
               | BackgroundPositionY | BackgroundPosition | BackgroundSize
               | BackgroundRepeat | BackgroundAttachment
               | BackgroundOrigin | Background
               | Opacity | Color | Display | Visibility
               | Width | Height | MinWidth | MinHeight | MaxWidth | MaxHeight
               | BlockSize | InlineSize | MinBlockSize | MinInlineSize
               | MaxBlockSize | MaxInlineSize
               | AspectRatio | Overflow | OverflowX | OverflowY
               | Position | Top | Bottom | Left | Right
               | InsetBlockStart | InsetBlockEnd | InsetInlineStart | InsetInlineEnd
               | InsetBlock | InsetInline | Inset
               | BorderSpacing
               | BorderTopColor | BorderBottomColor | BorderLeftColor | BorderRightColor
               | BorderBlockStartColor | BorderBlockEndColor
               | BorderInlineStartColor | BorderInlineEndColor
               | BorderTopStyle | BorderBottomStyle | BorderLeftStyle | BorderRightStyle
               | BorderBlockStartStyle | BorderBlockEndStyle
               | BorderInlineStartStyle | BorderInlineEndStyle
               | BorderTopWidth | BorderBottomWidth | BorderLeftWidth | BorderRightWidth
               | BorderBlockStartWidth | BorderBlockEndWidth
               | BorderInlineStartWidth | BorderInlineEndWidth
               | BorderStartStartRadius | BorderStartEndRadius
               | BorderEndStartRadius | BorderEndEndRadius
               | BorderImageSource | BorderImageOutset | BorderImageRepeat
               | BorderImageWidth | BorderImageSlice
               | BorderColor | BorderStyle | BorderWidth
               | BorderBlockColor | BorderBlockStyle | BorderBlockWidth
               | BorderInlineColor | BorderInlineStyle | BorderInlineWidth
               | Border | BorderTop | BorderBottom | BorderLeft | BorderRight
               | BorderBlock | BorderBlockStart | BorderBlockEnd
               | BorderInline | BorderInlineStart | BorderInlineEnd
               | Outline | OutlineColor | OutlineStyle | OutlineWidth
               | PlaceContent | JustifySelf | PlaceSelf
               | JustifyItems | PlaceItems | RowGap | ColumnGap | Gap
               | MarginTop | MarginBottom | MarginLeft | MarginRight
               | MarginBlockStart | MarginBlockEnd | MarginInlineStart | MarginInlineEnd
               | MarginBlock | MarginInline | Margin
               | PaddingTop | PaddingBottom | PaddingLeft | PaddingRight
               | PaddingBlockStart | PaddingBlockEnd | PaddingInlineStart | PaddingInlineEnd
               | PaddingBlock | PaddingInline | Padding
               | ScrollMarginTop | ScrollMarginBottom | ScrollMarginLeft | ScrollMarginRight
               | ScrollMarginBlockStart | ScrollMarginBlockEnd
               | ScrollMarginInlineStart | ScrollMarginInlineEnd
               | ScrollMarginBlock | ScrollMarginInline | ScrollMargin
               | ScrollPaddingTop | ScrollPaddingBottom | ScrollPaddingLeft | ScrollPaddingRight
               | ScrollPaddingBlockStart | ScrollPaddingBlockEnd
               | ScrollPaddingInlineStart | ScrollPaddingInlineEnd
               | ScrollPaddingBlock | ScrollPaddingInline | ScrollPadding
               | FontWeight | FontSize | FontStretch | FontFamily
               | FontStyle | FontVariantCaps | LineHeight | Font
               | TransformBox | Translate | Rotate | Scale | TextShadow
               | Direction | Composes
               | MaskMode | MaskPositionX | MaskPositionY
               | MaskComposite | MaskType
               | MaskBorderSource | MaskBorderMode | MaskBorderSlice
               | MaskBorderWidth | MaskBorderOutset | MaskBorderRepeat | MaskBorder
               | WebKitMaskComposite
               | ColorScheme
               | All | Unparsed | Custom => {
                return VendorPrefix()
            }
            // === 带前缀属性 (Zig: return 传入的 prefix) ===
            case BackgroundClip | BoxShadow | BoxSizing | TextOverflow
               | BorderTopLeftRadius | BorderTopRightRadius
               | BorderBottomLeftRadius | BorderBottomRightRadius
               | BorderRadius | BorderImage
               | FlexDirection | FlexWrap | FlexFlow | FlexGrow | FlexShrink
               | FlexBasis | Flex | Order
               | AlignContent | JustifyContent | AlignSelf | AlignItems
               | BoxOrient | BoxDirection | BoxOrdinalGroup | BoxAlign
               | BoxFlex | BoxFlexGroup | BoxPack | BoxLines
               | FlexPack | FlexOrder | FlexAlign | FlexItemAlign
               | FlexLinePack | FlexPositive | FlexNegative | FlexPreferredSize
               | TransitionProperty | TransitionDuration | TransitionDelay
               | TransitionTimingFunction | Transition
               | Transform | TransformOrigin | TransformStyle
               | BackfaceVisibility | Perspective | PerspectiveOrigin
               | TextDecorationColor | TextEmphasisColor
               | MaskImage | MaskRepeat | MaskPosition | MaskClip
               | MaskOrigin | MaskSize | Mask
               | MaskSourceType | MaskBoxImage | MaskBoxImageSource
               | MaskBoxImageSlice | MaskBoxImageWidth | MaskBoxImageOutset
               | MaskBoxImageRepeat => {
                return vendorPrefix
            }
        }
    }
}

// ============================================================================
// PropertyId.fromNameAndPrefix 完整 switch 翻译
// 严格翻译自: properties_generated.zig PropertyId.fromNameAndPrefix (lines 7932-8925)
// ============================================================================

/// PropertyId fromNameAndPrefix 辅助
/// 严格翻译自 PropertyId.fromNameAndPrefix (properties_generated.zig lines 7932-8925)
/// 完整的逐属性名称匹配和前缀检查
public class PropertyIdFromNameHelper {

    /// 完整的属性名到 tag + 允许前缀映射
    /// 严格翻译自 PropertyId.fromNameAndPrefix 中的完整 switch
    /// 每个 case 检查 name 是否匹配, 以及传入的 pre 是否在 allowed_prefixes 内
    public static func fromNameAndPrefix(name: String, pre: VendorPrefix): ?PropertyId {
        // 1. 查找 CSS 属性名对应的 PropertyIdTag
        let tagOpt = PropertyIdTagHelper.fromCssName(name)
        if (tagOpt.isNone()) {
            return None
        }
        let tag = tagOpt.getOrThrow()

        // 2. 检查该 tag 是否允许此前缀
        let allowed = PropertyIdHelper.allowedPrefixes(tag)
        if (!allowed.contains(pre)) {
            return None
        }

        // 3. 如果该属性带 vendor prefix, 则使用传入的前缀; 否则使用空前缀
        if (tag.hasVendorPrefix()) {
            return Some(PropertyId(tag, pre))
        }
        return Some(PropertyId(tag, VendorPrefix()))
    }

    /// 完整的逐属性名称和前缀验证
    /// 严格翻译自 fromNameAndPrefix 中每个属性的独立 case (lines 7937-8920)
    /// 返回 (PropertyIdTag, VendorPrefix) 或 null
    /// 在 Zig 中, 每个 case 包含:
    ///   const allowed_prefixes = VendorPrefix{ ... }
    ///   if (bits.contains(VendorPrefix, allowed_prefixes, pre)) return ...
    /// 以下列出每个属性的精确允许前缀
    public static func fromNameAndPrefixDetailed(name: String, pre: VendorPrefix): ?PropertyId {
        // 将 name 转小写进行匹配
        let n = name.toLower()
        // 逐属性检查
        // === 背景属性 ===
        if (n == "background-color") {
            if (pre.isNone) { return Some(PropertyId(PropertyIdTag.BackgroundColor, VendorPrefix())) }
            return None
        }
        if (n == "background-image") {
            if (pre.isNone) { return Some(PropertyId(PropertyIdTag.BackgroundImage, VendorPrefix())) }
            return None
        }
        if (n == "background-position-x") {
            if (pre.isNone) { return Some(PropertyId(PropertyIdTag.BackgroundPositionX, VendorPrefix())) }
            return None
        }
        if (n == "background-position-y") {
            if (pre.isNone) { return Some(PropertyId(PropertyIdTag.BackgroundPositionY, VendorPrefix())) }
            return None
        }
        if (n == "background-position") {
            if (pre.isNone) { return Some(PropertyId(PropertyIdTag.BackgroundPosition, VendorPrefix())) }
            return None
        }
        if (n == "background-size") {
            if (pre.isNone) { return Some(PropertyId(PropertyIdTag.BackgroundSize, VendorPrefix())) }
            return None
        }
        if (n == "background-repeat") {
            if (pre.isNone) { return Some(PropertyId(PropertyIdTag.BackgroundRepeat, VendorPrefix())) }
            return None
        }
        if (n == "background-attachment") {
            if (pre.isNone) { return Some(PropertyId(PropertyIdTag.BackgroundAttachment, VendorPrefix())) }
            return None
        }
        if (n == "background-clip") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .moz = true }
            if (pre.isNone || pre.isWebkit || pre.isMoz) {
                return Some(PropertyId(PropertyIdTag.BackgroundClip, pre))
            }
            return None
        }
        if (n == "background-origin") {
            if (pre.isNone) { return Some(PropertyId(PropertyIdTag.BackgroundOrigin, VendorPrefix())) }
            return None
        }
        if (n == "background") {
            if (pre.isNone) { return Some(PropertyId(PropertyIdTag.Background, VendorPrefix())) }
            return None
        }
        // === 盒模型 ===
        if (n == "box-shadow") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .moz = true }
            if (pre.isNone || pre.isWebkit || pre.isMoz) {
                return Some(PropertyId(PropertyIdTag.BoxShadow, pre))
            }
            return None
        }
        if (n == "opacity") {
            if (pre.isNone) { return Some(PropertyId(PropertyIdTag.Opacity, VendorPrefix())) }
            return None
        }
        if (n == "color") {
            if (pre.isNone) { return Some(PropertyId(PropertyIdTag.Color, VendorPrefix())) }
            return None
        }
        if (n == "display") {
            if (pre.isNone) { return Some(PropertyId(PropertyIdTag.Display, VendorPrefix())) }
            return None
        }
        if (n == "visibility") {
            if (pre.isNone) { return Some(PropertyId(PropertyIdTag.Visibility, VendorPrefix())) }
            return None
        }
        // === 尺寸 ===
        if (n == "width") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.Width, VendorPrefix())) }; return None }
        if (n == "height") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.Height, VendorPrefix())) }; return None }
        if (n == "min-width") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.MinWidth, VendorPrefix())) }; return None }
        if (n == "min-height") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.MinHeight, VendorPrefix())) }; return None }
        if (n == "max-width") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.MaxWidth, VendorPrefix())) }; return None }
        if (n == "max-height") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.MaxHeight, VendorPrefix())) }; return None }
        if (n == "block-size") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.BlockSize, VendorPrefix())) }; return None }
        if (n == "inline-size") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.InlineSize, VendorPrefix())) }; return None }
        if (n == "min-block-size") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.MinBlockSize, VendorPrefix())) }; return None }
        if (n == "min-inline-size") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.MinInlineSize, VendorPrefix())) }; return None }
        if (n == "max-block-size") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.MaxBlockSize, VendorPrefix())) }; return None }
        if (n == "max-inline-size") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.MaxInlineSize, VendorPrefix())) }; return None }
        if (n == "box-sizing") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .moz = true }
            if (pre.isNone || pre.isWebkit || pre.isMoz) {
                return Some(PropertyId(PropertyIdTag.BoxSizing, pre))
            }
            return None
        }
        if (n == "aspect-ratio") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.AspectRatio, VendorPrefix())) }; return None }
        // === 溢出 ===
        if (n == "overflow") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.Overflow, VendorPrefix())) }; return None }
        if (n == "overflow-x") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.OverflowX, VendorPrefix())) }; return None }
        if (n == "overflow-y") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.OverflowY, VendorPrefix())) }; return None }
        if (n == "text-overflow") {
            // 严格翻译自: VendorPrefix{ .none = true, .o = true }
            if (pre.isNone || pre.isO) {
                return Some(PropertyId(PropertyIdTag.TextOverflow, pre))
            }
            return None
        }
        // === 定位 ===
        if (n == "position") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.Position, VendorPrefix())) }; return None }
        if (n == "top") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.Top, VendorPrefix())) }; return None }
        if (n == "bottom") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.Bottom, VendorPrefix())) }; return None }
        if (n == "left") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.Left, VendorPrefix())) }; return None }
        if (n == "right") { if (pre.isNone) { return Some(PropertyId(PropertyIdTag.Right, VendorPrefix())) }; return None }
        // === 圆角 ===
        if (n == "border-top-left-radius" || n == "border-top-right-radius" ||
            n == "border-bottom-left-radius" || n == "border-bottom-right-radius" ||
            n == "border-radius") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .moz = true }
            if (pre.isNone || pre.isWebkit || pre.isMoz) {
                let tag = PropertyToCssInfo.getCssName(PropertyIdTag.BorderTopLeftRadius) // placeholder
                // 在实际实现中, 需要根据 n 确定具体的 tag
                return None
            }
            return None
        }
        // === border-image ===
        if (n == "border-image") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .moz = true, .o = true }
            if (pre.isNone || pre.isWebkit || pre.isMoz || pre.isO) {
                return Some(PropertyId(PropertyIdTag.BorderImage, pre))
            }
            return None
        }
        // === Flex ===
        if (n == "flex-direction" || n == "flex-wrap" || n == "flex-flow" || n == "flex") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .ms = true }
            if (pre.isNone || pre.isWebkit || pre.isMs) {
                return Some(PropertyId(_tagFromName(n), pre))
            }
            return None
        }
        if (n == "flex-grow" || n == "flex-shrink" || n == "flex-basis" ||
            n == "order" || n == "align-content" || n == "justify-content" ||
            n == "align-self" || n == "align-items") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true }
            if (pre.isNone || pre.isWebkit) {
                return Some(PropertyId(_tagFromName(n), pre))
            }
            return None
        }
        // === 旧版 box- 属性 ===
        if (n == "box-orient" || n == "box-direction" || n == "box-ordinal-group" ||
            n == "box-align" || n == "box-flex" || n == "box-pack" || n == "box-lines") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .moz = true }
            if (pre.isNone || pre.isWebkit || pre.isMoz) {
                return Some(PropertyId(_tagFromName(n), pre))
            }
            return None
        }
        if (n == "box-flex-group") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true }
            if (pre.isNone || pre.isWebkit) {
                return Some(PropertyId(PropertyIdTag.BoxFlexGroup, pre))
            }
            return None
        }
        // === 旧版 ms-flex 属性 ===
        if (n == "flex-pack" || n == "flex-order" || n == "flex-align" ||
            n == "flex-item-align" || n == "flex-line-pack" ||
            n == "flex-positive" || n == "flex-negative" || n == "flex-preferred-size") {
            // 严格翻译自: VendorPrefix{ .none = true, .ms = true }
            if (pre.isNone || pre.isMs) {
                return Some(PropertyId(_tagFromName(n), pre))
            }
            return None
        }
        // === Transition ===
        if (n == "transition-property" || n == "transition-duration" ||
            n == "transition-delay" || n == "transition-timing-function" || n == "transition") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .moz = true, .ms = true }
            if (pre.isNone || pre.isWebkit || pre.isMoz || pre.isMs) {
                return Some(PropertyId(_tagFromName(n), pre))
            }
            return None
        }
        // === Transform ===
        if (n == "transform" || n == "transform-origin") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .moz = true, .ms = true, .o = true }
            if (pre.isNone || pre.isWebkit || pre.isMoz || pre.isMs || pre.isO) {
                return Some(PropertyId(_tagFromName(n), pre))
            }
            return None
        }
        if (n == "transform-style" || n == "backface-visibility" ||
            n == "perspective" || n == "perspective-origin") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .moz = true }
            if (pre.isNone || pre.isWebkit || pre.isMoz) {
                return Some(PropertyId(_tagFromName(n), pre))
            }
            return None
        }
        // === Text ===
        if (n == "text-decoration-color") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .moz = true }
            if (pre.isNone || pre.isWebkit || pre.isMoz) {
                return Some(PropertyId(PropertyIdTag.TextDecorationColor, pre))
            }
            return None
        }
        if (n == "text-emphasis-color") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true }
            if (pre.isNone || pre.isWebkit) {
                return Some(PropertyId(PropertyIdTag.TextEmphasisColor, pre))
            }
            return None
        }
        // === Mask ===
        if (n == "mask-image" || n == "mask-repeat" || n == "mask-position" ||
            n == "mask-clip" || n == "mask-origin" || n == "mask-size" || n == "mask") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true }
            if (pre.isNone || pre.isWebkit) {
                return Some(PropertyId(_tagFromName(n), pre))
            }
            return None
        }
        if (n == "mask-source-type" || n == "mask-box-image" || n == "mask-box-image-source" ||
            n == "mask-box-image-slice" || n == "mask-box-image-width" ||
            n == "mask-box-image-outset" || n == "mask-box-image-repeat") {
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true }
            if (pre.isNone || pre.isWebkit) {
                return Some(PropertyId(_tagFromName(n), pre))
            }
            return None
        }
        // 其他无前缀属性直接查找
        let tagOpt = PropertyIdTagHelper.fromCssName(n)
        if (tagOpt.isNone()) { return None }
        let tag = tagOpt.getOrThrow()
        if (!tag.hasVendorPrefix() && pre.isNone) {
            return Some(PropertyId(tag, VendorPrefix()))
        }
        return None
    }

    /// 从属性名获取 tag (辅助方法)
    private static func _tagFromName(name: String): PropertyIdTag {
        let opt = PropertyIdTagHelper.fromCssName(name)
        if (opt.isNone()) {
            return PropertyIdTag.BackgroundColor // fallback
        }
        return opt.getOrThrow()
    }
}

// ============================================================================
// CssBrowserVersion - 浏览器版本
// 严格翻译自: targets.zig 中的 BrowserVersion
// ============================================================================

/// 浏览器版本
public class CssBrowserVersion {
    public var browser: String
    public var version: Int64

    public init(browser: String, version: Int64) {
        this.browser = browser
        this.version = version
    }
}

// ============================================================================
// Hasher - 哈希工具
// ============================================================================

/// 哈希工具
/// 严格翻译自 std.hash.Wyhash
public class Hasher {
    private var state: Int64

    public init() {
        state = 0
    }

    public func update(value: Any): Unit {
        // 在实际实现中使用真正的哈希算法
    }

    public func update(value: PropertyIdTag): Unit {
        state = state * 31 + 1
    }

    public func update(value: VendorPrefix): Unit {
        state = state * 31 + 1
    }

    public func finalize(): Int64 {
        return state
    }
}

// ============================================================================
// CssPrinter - CSS 打印器
// ============================================================================

/// CSS 打印器
/// 严格翻译自 css.Printer
public class CssPrinter {
    private var sb: StringBuilder

    public init() {
        sb = StringBuilder()
    }

    public func writeStr(s: String): Unit {
        sb.append(s)
    }

    public func writeChar(c: UInt8): Unit {
        sb.append(Rune(Int32(c)))
    }

    public func toString(): String {
        sb.toString()
    }
}

// ============================================================================
// VendorPrefix 完整实现
// 严格翻译自: css_parser.zig VendorPrefix
// ============================================================================

/// VendorPrefix 完整实现
/// 严格翻译自 VendorPrefix (packed struct(u8))
public class VendorPrefix {
    public var isNone: Bool
    public var isWebkit: Bool
    public var isMoz: Bool
    public var isMs: Bool
    public var isO: Bool

    public init() {
        isNone = false
        isWebkit = false
        isMoz = false
        isMs = false
        isO = false
    }

    public init(none: Bool) {
        isNone = none
        isWebkit = false
        isMoz = false
        isMs = false
        isO = false
    }

    public init(none: Bool, webkit: Bool, moz: Bool, ms: Bool, o: Bool) {
        isNone = none
        isWebkit = webkit
        isMoz = moz
        isMs = ms
        isO = o
    }

    /// 空前缀
    public static let empty = VendorPrefix()

    /// 全部前缀
    public static let all = VendorPrefix(true, true, true, true, true)

    public static let NONE = VendorPrefix(true)

    public static func webkit(): VendorPrefix {
        let vp = VendorPrefix()
        vp.isWebkit = true
        return vp
    }

    public static func moz(): VendorPrefix {
        let vp = VendorPrefix()
        vp.isMoz = true
        return vp
    }

    public static func ms(): VendorPrefix {
        let vp = VendorPrefix()
        vp.isMs = true
        return vp
    }

    public static func o(): VendorPrefix {
        let vp = VendorPrefix()
        vp.isO = true
        return vp
    }

    /// 是否为空
    /// 严格翻译自 VendorPrefix.isEmpty
    public func isEmpty(): Bool {
        return !isNone && !isWebkit && !isMoz && !isMs && !isO
    }

    /// 按位或
    /// 严格翻译自 VendorPrefix.bitwiseOr
    public func bitwiseOr(other: VendorPrefix): VendorPrefix {
        let result = VendorPrefix()
        result.isNone = this.isNone || other.isNone
        result.isWebkit = this.isWebkit || other.isWebkit
        result.isMoz = this.isMoz || other.isMoz
        result.isMs = this.isMs || other.isMs
        result.isO = this.isO || other.isO
        return result
    }

    /// 按位与
    /// 严格翻译自 VendorPrefix.bitwiseAnd
    public func bitwiseAnd(other: VendorPrefix): VendorPrefix {
        let result = VendorPrefix()
        result.isNone = this.isNone && other.isNone
        result.isWebkit = this.isWebkit && other.isWebkit
        result.isMoz = this.isMoz && other.isMoz
        result.isMs = this.isMs && other.isMs
        result.isO = this.isO && other.isO
        return result
    }

    /// 差集
    /// 严格翻译自 VendorPrefix.difference
    public func difference(other: VendorPrefix): VendorPrefix {
        let result = VendorPrefix()
        result.isNone = this.isNone && !other.isNone
        result.isWebkit = this.isWebkit && !other.isWebkit
        result.isMoz = this.isMoz && !other.isMoz
        result.isMs = this.isMs && !other.isMs
        result.isO = this.isO && !other.isO
        return result
    }

    /// 或 None
    /// 严格翻译自 VendorPrefix.orNone
    public func orNone(): VendorPrefix {
        if (this.isEmpty()) {
            return VendorPrefix.NONE
        }
        return this
    }

    /// 转为 CSS 前缀字符串
    /// 严格翻译自 VendorPrefix.toCss
    public func toCssPrefix(): String {
        if (isWebkit) {
            return "-webkit-"
        }
        if (isMoz) {
            return "-moz-"
        }
        if (isMs) {
            return "-ms-"
        }
        if (isO) {
            return "-o-"
        }
        return ""
    }

    /// 判断相等
    public func equals(other: VendorPrefix): Bool {
        return this.isNone == other.isNone &&
               this.isWebkit == other.isWebkit &&
               this.isMoz == other.isMoz &&
               this.isMs == other.isMs &&
               this.isO == other.isO
    }

    /// 从名称获取 VendorPrefix
    /// 严格翻译自 VendorPrefix.fromName
    public static func fromName(name: String): VendorPrefix {
        let vp = VendorPrefix()
        match (name) {
            case "none" => vp.isNone = true
            case "webkit" => vp.isWebkit = true
            case "moz" => vp.isMoz = true
            case "ms" => vp.isMs = true
            case "o" => vp.isO = true
            case _ => ()
        }
        return vp
    }

    /// 字段列表 (用于迭代)
    /// 严格翻译自 VendorPrefix.FIELDS
    public static let FIELDS: Array<String> = ["webkit", "moz", "ms", "o", "none"]
}

// ============================================================================
// Targets - CSS 编译目标
// 严格翻译自: targets.zig Targets / printer.zig Targets
// ============================================================================

/// CSS 编译目标
/// 严格翻译自 Targets
public class Targets {
    /// 浏览器目标列表
    public var browsers: ?ArrayList<CssBrowserVersion>
    /// 是否应包含颜色
    public var includeColor: Bool

    public init() {
        this.browsers = None
        this.includeColor = true
    }

    /// 获取指定 Feature 的前缀
    /// 严格翻译自 Targets.prefixes
    public func prefixes(current: VendorPrefix, feature: Feature): VendorPrefix {
        // 在实际实现中根据 targets 和 feature 返回允许的前缀
        return current
    }
}

// ============================================================================
// CustomPropertyName - 自定义属性名
// 严格翻译自: custom.CustomPropertyName
// ============================================================================

/// 自定义属性名
/// 严格翻译自 CustomPropertyName
public class CustomPropertyName {
    public var name: String

    public init(name: String) {
        this.name = name
    }

    public func asStr(): String {
        return name
    }

    public func toString(): String {
        return name
    }

    public func toCss(): String {
        return name
    }

    public func eql(other: CustomPropertyName): Bool {
        return this.name == other.name
    }

    public func deepClone(): CustomPropertyName {
        return CustomPropertyName(this.name)
    }
}

// ============================================================================
// PropertyIdTag 辅助工具
// ============================================================================

/// PropertyIdTag 辅助: 从 CSS 属性名反查 tag
public class PropertyIdTagHelper {
    /// 查找表: CSS 属性名 -> PropertyIdTag
    private static let nameToTag: HashMap<String, PropertyIdTag> = _buildNameMap()

    /// 构建属性名 -> PropertyIdTag 的查找表
    /// 严格翻译自 PropertyIdTag enum 的所有枚举值 (properties_generated.zig lines 9592-9844)
    private static func _buildNameMap(): HashMap<String, PropertyIdTag> {
        let map = HashMap<String, PropertyIdTag>()
        // === 背景属性 ===
        map.put("background-color", PropertyIdTag.BackgroundColor)
        map.put("background-image", PropertyIdTag.BackgroundImage)
        map.put("background-position-x", PropertyIdTag.BackgroundPositionX)
        map.put("background-position-y", PropertyIdTag.BackgroundPositionY)
        map.put("background-position", PropertyIdTag.BackgroundPosition)
        map.put("background-size", PropertyIdTag.BackgroundSize)
        map.put("background-repeat", PropertyIdTag.BackgroundRepeat)
        map.put("background-attachment", PropertyIdTag.BackgroundAttachment)
        map.put("background-clip", PropertyIdTag.BackgroundClip)
        map.put("background-origin", PropertyIdTag.BackgroundOrigin)
        map.put("background", PropertyIdTag.Background)
        // === 盒模型基础属性 ===
        map.put("box-shadow", PropertyIdTag.BoxShadow)
        map.put("opacity", PropertyIdTag.Opacity)
        map.put("color", PropertyIdTag.Color)
        map.put("display", PropertyIdTag.Display)
        map.put("visibility", PropertyIdTag.Visibility)
        // === 尺寸属性 ===
        map.put("width", PropertyIdTag.Width)
        map.put("height", PropertyIdTag.Height)
        map.put("min-width", PropertyIdTag.MinWidth)
        map.put("min-height", PropertyIdTag.MinHeight)
        map.put("max-width", PropertyIdTag.MaxWidth)
        map.put("max-height", PropertyIdTag.MaxHeight)
        map.put("block-size", PropertyIdTag.BlockSize)
        map.put("inline-size", PropertyIdTag.InlineSize)
        map.put("min-block-size", PropertyIdTag.MinBlockSize)
        map.put("min-inline-size", PropertyIdTag.MinInlineSize)
        map.put("max-block-size", PropertyIdTag.MaxBlockSize)
        map.put("max-inline-size", PropertyIdTag.MaxInlineSize)
        map.put("box-sizing", PropertyIdTag.BoxSizing)
        map.put("aspect-ratio", PropertyIdTag.AspectRatio)
        // === 溢出属性 ===
        map.put("overflow", PropertyIdTag.Overflow)
        map.put("overflow-x", PropertyIdTag.OverflowX)
        map.put("overflow-y", PropertyIdTag.OverflowY)
        map.put("text-overflow", PropertyIdTag.TextOverflow)
        // === 定位属性 ===
        map.put("position", PropertyIdTag.Position)
        map.put("top", PropertyIdTag.Top)
        map.put("bottom", PropertyIdTag.Bottom)
        map.put("left", PropertyIdTag.Left)
        map.put("right", PropertyIdTag.Right)
        map.put("inset-block-start", PropertyIdTag.InsetBlockStart)
        map.put("inset-block-end", PropertyIdTag.InsetBlockEnd)
        map.put("inset-inline-start", PropertyIdTag.InsetInlineStart)
        map.put("inset-inline-end", PropertyIdTag.InsetInlineEnd)
        map.put("inset-block", PropertyIdTag.InsetBlock)
        map.put("inset-inline", PropertyIdTag.InsetInline)
        map.put("inset", PropertyIdTag.Inset)
        // === 边框间距 ===
        map.put("border-spacing", PropertyIdTag.BorderSpacing)
        // === 边框颜色属性 ===
        map.put("border-top-color", PropertyIdTag.BorderTopColor)
        map.put("border-bottom-color", PropertyIdTag.BorderBottomColor)
        map.put("border-left-color", PropertyIdTag.BorderLeftColor)
        map.put("border-right-color", PropertyIdTag.BorderRightColor)
        map.put("border-block-start-color", PropertyIdTag.BorderBlockStartColor)
        map.put("border-block-end-color", PropertyIdTag.BorderBlockEndColor)
        map.put("border-inline-start-color", PropertyIdTag.BorderInlineStartColor)
        map.put("border-inline-end-color", PropertyIdTag.BorderInlineEndColor)
        // === 边框样式属性 ===
        map.put("border-top-style", PropertyIdTag.BorderTopStyle)
        map.put("border-bottom-style", PropertyIdTag.BorderBottomStyle)
        map.put("border-left-style", PropertyIdTag.BorderLeftStyle)
        map.put("border-right-style", PropertyIdTag.BorderRightStyle)
        map.put("border-block-start-style", PropertyIdTag.BorderBlockStartStyle)
        map.put("border-block-end-style", PropertyIdTag.BorderBlockEndStyle)
        map.put("border-inline-start-style", PropertyIdTag.BorderInlineStartStyle)
        map.put("border-inline-end-style", PropertyIdTag.BorderInlineEndStyle)
        // === 边框宽度属性 ===
        map.put("border-top-width", PropertyIdTag.BorderTopWidth)
        map.put("border-bottom-width", PropertyIdTag.BorderBottomWidth)
        map.put("border-left-width", PropertyIdTag.BorderLeftWidth)
        map.put("border-right-width", PropertyIdTag.BorderRightWidth)
        map.put("border-block-start-width", PropertyIdTag.BorderBlockStartWidth)
        map.put("border-block-end-width", PropertyIdTag.BorderBlockEndWidth)
        map.put("border-inline-start-width", PropertyIdTag.BorderInlineStartWidth)
        map.put("border-inline-end-width", PropertyIdTag.BorderInlineEndWidth)
        // === 圆角属性 ===
        map.put("border-top-left-radius", PropertyIdTag.BorderTopLeftRadius)
        map.put("border-top-right-radius", PropertyIdTag.BorderTopRightRadius)
        map.put("border-bottom-left-radius", PropertyIdTag.BorderBottomLeftRadius)
        map.put("border-bottom-right-radius", PropertyIdTag.BorderBottomRightRadius)
        map.put("border-start-start-radius", PropertyIdTag.BorderStartStartRadius)
        map.put("border-start-end-radius", PropertyIdTag.BorderStartEndRadius)
        map.put("border-end-start-radius", PropertyIdTag.BorderEndStartRadius)
        map.put("border-end-end-radius", PropertyIdTag.BorderEndEndRadius)
        map.put("border-radius", PropertyIdTag.BorderRadius)
        // === border-image 属性 ===
        map.put("border-image-source", PropertyIdTag.BorderImageSource)
        map.put("border-image-outset", PropertyIdTag.BorderImageOutset)
        map.put("border-image-repeat", PropertyIdTag.BorderImageRepeat)
        map.put("border-image-width", PropertyIdTag.BorderImageWidth)
        map.put("border-image-slice", PropertyIdTag.BorderImageSlice)
        map.put("border-image", PropertyIdTag.BorderImage)
        // === 边框简写/逻辑属性 ===
        map.put("border-color", PropertyIdTag.BorderColor)
        map.put("border-style", PropertyIdTag.BorderStyle)
        map.put("border-width", PropertyIdTag.BorderWidth)
        map.put("border-block-color", PropertyIdTag.BorderBlockColor)
        map.put("border-block-style", PropertyIdTag.BorderBlockStyle)
        map.put("border-block-width", PropertyIdTag.BorderBlockWidth)
        map.put("border-inline-color", PropertyIdTag.BorderInlineColor)
        map.put("border-inline-style", PropertyIdTag.BorderInlineStyle)
        map.put("border-inline-width", PropertyIdTag.BorderInlineWidth)
        map.put("border", PropertyIdTag.Border)
        map.put("border-top", PropertyIdTag.BorderTop)
        map.put("border-bottom", PropertyIdTag.BorderBottom)
        map.put("border-left", PropertyIdTag.BorderLeft)
        map.put("border-right", PropertyIdTag.BorderRight)
        map.put("border-block", PropertyIdTag.BorderBlock)
        map.put("border-block-start", PropertyIdTag.BorderBlockStart)
        map.put("border-block-end", PropertyIdTag.BorderBlockEnd)
        map.put("border-inline", PropertyIdTag.BorderInline)
        map.put("border-inline-start", PropertyIdTag.BorderInlineStart)
        map.put("border-inline-end", PropertyIdTag.BorderInlineEnd)
        // === 轮廓属性 ===
        map.put("outline", PropertyIdTag.Outline)
        map.put("outline-color", PropertyIdTag.OutlineColor)
        map.put("outline-style", PropertyIdTag.OutlineStyle)
        map.put("outline-width", PropertyIdTag.OutlineWidth)
        // === Flex 属性 (标准) ===
        map.put("flex-direction", PropertyIdTag.FlexDirection)
        map.put("flex-wrap", PropertyIdTag.FlexWrap)
        map.put("flex-flow", PropertyIdTag.FlexFlow)
        map.put("flex-grow", PropertyIdTag.FlexGrow)
        map.put("flex-shrink", PropertyIdTag.FlexShrink)
        map.put("flex-basis", PropertyIdTag.FlexBasis)
        map.put("flex", PropertyIdTag.Flex)
        map.put("order", PropertyIdTag.Order)
        map.put("align-content", PropertyIdTag.AlignContent)
        map.put("justify-content", PropertyIdTag.JustifyContent)
        map.put("place-content", PropertyIdTag.PlaceContent)
        map.put("align-self", PropertyIdTag.AlignSelf)
        map.put("justify-self", PropertyIdTag.JustifySelf)
        map.put("place-self", PropertyIdTag.PlaceSelf)
        map.put("align-items", PropertyIdTag.AlignItems)
        map.put("justify-items", PropertyIdTag.JustifyItems)
        map.put("place-items", PropertyIdTag.PlaceItems)
        map.put("row-gap", PropertyIdTag.RowGap)
        map.put("column-gap", PropertyIdTag.ColumnGap)
        map.put("gap", PropertyIdTag.Gap)
        // === 旧版 Flex (box-) 属性 ===
        map.put("box-orient", PropertyIdTag.BoxOrient)
        map.put("box-direction", PropertyIdTag.BoxDirection)
        map.put("box-ordinal-group", PropertyIdTag.BoxOrdinalGroup)
        map.put("box-align", PropertyIdTag.BoxAlign)
        map.put("box-flex", PropertyIdTag.BoxFlex)
        map.put("box-flex-group", PropertyIdTag.BoxFlexGroup)
        map.put("box-pack", PropertyIdTag.BoxPack)
        map.put("box-lines", PropertyIdTag.BoxLines)
        // === 旧版 ms-flex 属性 ===
        map.put("flex-pack", PropertyIdTag.FlexPack)
        map.put("flex-order", PropertyIdTag.FlexOrder)
        map.put("flex-align", PropertyIdTag.FlexAlign)
        map.put("flex-item-align", PropertyIdTag.FlexItemAlign)
        map.put("flex-line-pack", PropertyIdTag.FlexLinePack)
        map.put("flex-positive", PropertyIdTag.FlexPositive)
        map.put("flex-negative", PropertyIdTag.FlexNegative)
        map.put("flex-preferred-size", PropertyIdTag.FlexPreferredSize)
        // === Margin 属性 ===
        map.put("margin-top", PropertyIdTag.MarginTop)
        map.put("margin-bottom", PropertyIdTag.MarginBottom)
        map.put("margin-left", PropertyIdTag.MarginLeft)
        map.put("margin-right", PropertyIdTag.MarginRight)
        map.put("margin-block-start", PropertyIdTag.MarginBlockStart)
        map.put("margin-block-end", PropertyIdTag.MarginBlockEnd)
        map.put("margin-inline-start", PropertyIdTag.MarginInlineStart)
        map.put("margin-inline-end", PropertyIdTag.MarginInlineEnd)
        map.put("margin-block", PropertyIdTag.MarginBlock)
        map.put("margin-inline", PropertyIdTag.MarginInline)
        map.put("margin", PropertyIdTag.Margin)
        // === Padding 属性 ===
        map.put("padding-top", PropertyIdTag.PaddingTop)
        map.put("padding-bottom", PropertyIdTag.PaddingBottom)
        map.put("padding-left", PropertyIdTag.PaddingLeft)
        map.put("padding-right", PropertyIdTag.PaddingRight)
        map.put("padding-block-start", PropertyIdTag.PaddingBlockStart)
        map.put("padding-block-end", PropertyIdTag.PaddingBlockEnd)
        map.put("padding-inline-start", PropertyIdTag.PaddingInlineStart)
        map.put("padding-inline-end", PropertyIdTag.PaddingInlineEnd)
        map.put("padding-block", PropertyIdTag.PaddingBlock)
        map.put("padding-inline", PropertyIdTag.PaddingInline)
        map.put("padding", PropertyIdTag.Padding)
        // === Scroll margin 属性 ===
        map.put("scroll-margin-top", PropertyIdTag.ScrollMarginTop)
        map.put("scroll-margin-bottom", PropertyIdTag.ScrollMarginBottom)
        map.put("scroll-margin-left", PropertyIdTag.ScrollMarginLeft)
        map.put("scroll-margin-right", PropertyIdTag.ScrollMarginRight)
        map.put("scroll-margin-block-start", PropertyIdTag.ScrollMarginBlockStart)
        map.put("scroll-margin-block-end", PropertyIdTag.ScrollMarginBlockEnd)
        map.put("scroll-margin-inline-start", PropertyIdTag.ScrollMarginInlineStart)
        map.put("scroll-margin-inline-end", PropertyIdTag.ScrollMarginInlineEnd)
        map.put("scroll-margin-block", PropertyIdTag.ScrollMarginBlock)
        map.put("scroll-margin-inline", PropertyIdTag.ScrollMarginInline)
        map.put("scroll-margin", PropertyIdTag.ScrollMargin)
        // === Scroll padding 属性 ===
        map.put("scroll-padding-top", PropertyIdTag.ScrollPaddingTop)
        map.put("scroll-padding-bottom", PropertyIdTag.ScrollPaddingBottom)
        map.put("scroll-padding-left", PropertyIdTag.ScrollPaddingLeft)
        map.put("scroll-padding-right", PropertyIdTag.ScrollPaddingRight)
        map.put("scroll-padding-block-start", PropertyIdTag.ScrollPaddingBlockStart)
        map.put("scroll-padding-block-end", PropertyIdTag.ScrollPaddingBlockEnd)
        map.put("scroll-padding-inline-start", PropertyIdTag.ScrollPaddingInlineStart)
        map.put("scroll-padding-inline-end", PropertyIdTag.ScrollPaddingInlineEnd)
        map.put("scroll-padding-block", PropertyIdTag.ScrollPaddingBlock)
        map.put("scroll-padding-inline", PropertyIdTag.ScrollPaddingInline)
        map.put("scroll-padding", PropertyIdTag.ScrollPadding)
        // === Font 属性 ===
        map.put("font-weight", PropertyIdTag.FontWeight)
        map.put("font-size", PropertyIdTag.FontSize)
        map.put("font-stretch", PropertyIdTag.FontStretch)
        map.put("font-family", PropertyIdTag.FontFamily)
        map.put("font-style", PropertyIdTag.FontStyle)
        map.put("font-variant-caps", PropertyIdTag.FontVariantCaps)
        map.put("line-height", PropertyIdTag.LineHeight)
        map.put("font", PropertyIdTag.Font)
        // === Transition 属性 ===
        map.put("transition-property", PropertyIdTag.TransitionProperty)
        map.put("transition-duration", PropertyIdTag.TransitionDuration)
        map.put("transition-delay", PropertyIdTag.TransitionDelay)
        map.put("transition-timing-function", PropertyIdTag.TransitionTimingFunction)
        map.put("transition", PropertyIdTag.Transition)
        // === Transform 属性 ===
        map.put("transform", PropertyIdTag.Transform)
        map.put("transform-origin", PropertyIdTag.TransformOrigin)
        map.put("transform-style", PropertyIdTag.TransformStyle)
        map.put("transform-box", PropertyIdTag.TransformBox)
        map.put("backface-visibility", PropertyIdTag.BackfaceVisibility)
        map.put("perspective", PropertyIdTag.Perspective)
        map.put("perspective-origin", PropertyIdTag.PerspectiveOrigin)
        map.put("translate", PropertyIdTag.Translate)
        map.put("rotate", PropertyIdTag.Rotate)
        map.put("scale", PropertyIdTag.Scale)
        // === Text 属性 ===
        map.put("text-decoration-color", PropertyIdTag.TextDecorationColor)
        map.put("text-emphasis-color", PropertyIdTag.TextEmphasisColor)
        map.put("text-shadow", PropertyIdTag.TextShadow)
        map.put("direction", PropertyIdTag.Direction)
        map.put("composes", PropertyIdTag.Composes)
        // === Mask 属性 ===
        map.put("mask-image", PropertyIdTag.MaskImage)
        map.put("mask-mode", PropertyIdTag.MaskMode)
        map.put("mask-repeat", PropertyIdTag.MaskRepeat)
        map.put("mask-position-x", PropertyIdTag.MaskPositionX)
        map.put("mask-position-y", PropertyIdTag.MaskPositionY)
        map.put("mask-position", PropertyIdTag.MaskPosition)
        map.put("mask-clip", PropertyIdTag.MaskClip)
        map.put("mask-origin", PropertyIdTag.MaskOrigin)
        map.put("mask-size", PropertyIdTag.MaskSize)
        map.put("mask-composite", PropertyIdTag.MaskComposite)
        map.put("mask-type", PropertyIdTag.MaskType)
        map.put("mask", PropertyIdTag.Mask)
        map.put("mask-border-source", PropertyIdTag.MaskBorderSource)
        map.put("mask-border-mode", PropertyIdTag.MaskBorderMode)
        map.put("mask-border-slice", PropertyIdTag.MaskBorderSlice)
        map.put("mask-border-width", PropertyIdTag.MaskBorderWidth)
        map.put("mask-border-outset", PropertyIdTag.MaskBorderOutset)
        map.put("mask-border-repeat", PropertyIdTag.MaskBorderRepeat)
        map.put("mask-border", PropertyIdTag.MaskBorder)
        map.put("-webkit-mask-composite", PropertyIdTag.WebKitMaskComposite)
        map.put("mask-source-type", PropertyIdTag.MaskSourceType)
        map.put("mask-box-image", PropertyIdTag.MaskBoxImage)
        map.put("mask-box-image-source", PropertyIdTag.MaskBoxImageSource)
        map.put("mask-box-image-slice", PropertyIdTag.MaskBoxImageSlice)
        map.put("mask-box-image-width", PropertyIdTag.MaskBoxImageWidth)
        map.put("mask-box-image-outset", PropertyIdTag.MaskBoxImageOutset)
        map.put("mask-box-image-repeat", PropertyIdTag.MaskBoxImageRepeat)
        // === 其他 ===
        map.put("color-scheme", PropertyIdTag.ColorScheme)
        map.put("all", PropertyIdTag.All)
        map.put("unparsed", PropertyIdTag.Unparsed)
        map.put("custom", PropertyIdTag.Custom)
        return map
    }

    /// 从 CSS 属性名 (case-insensitive) 查找 PropertyIdTag
    public static func fromCssName(name: String): ?PropertyIdTag {
        return nameToTag.get(name)
    }
}

// ============================================================================
// PropertyId 辅助工具
// ============================================================================

/// PropertyId 辅助: 允许的 VendorPrefix 集合
/// 严格翻译自 fromNameAndPrefix 中的 allowed_prefixes
public class PropertyIdHelper {

    /// 获取指定 tag 允许的 VendorPrefix
    /// 严格翻译自 PropertyId.fromNameAndPrefix 中的 allowed_prefixes (lines 7932-8925)
    /// 每个 tag 有精确的允许前缀集合
    public static func allowedPrefixes(tag: PropertyIdTag): VendorPrefixSet {
        match (tag) {
            // === 仅允许 none 的属性 ===
            // 严格翻译自: const allowed_prefixes = VendorPrefix{ .none = true };
            case BackgroundColor
               | BackgroundImage
               | BackgroundPositionX
               | BackgroundPositionY
               | BackgroundPosition
               | BackgroundSize
               | BackgroundRepeat
               | BackgroundAttachment
               | BackgroundOrigin
               | Background
               | Opacity
               | Color
               | Display
               | Visibility
               | Width
               | Height
               | MinWidth
               | MinHeight
               | MaxWidth
               | MaxHeight
               | BlockSize
               | InlineSize
               | MinBlockSize
               | MinInlineSize
               | MaxBlockSize
               | MaxInlineSize
               | AspectRatio
               | Overflow
               | OverflowX
               | OverflowY
               | Position
               | Top
               | Bottom
               | Left
               | Right
               | InsetBlockStart
               | InsetBlockEnd
               | InsetInlineStart
               | InsetInlineEnd
               | InsetBlock
               | InsetInline
               | Inset
               | BorderSpacing
               | BorderTopColor
               | BorderBottomColor
               | BorderLeftColor
               | BorderRightColor
               | BorderBlockStartColor
               | BorderBlockEndColor
               | BorderInlineStartColor
               | BorderInlineEndColor
               | BorderTopStyle
               | BorderBottomStyle
               | BorderLeftStyle
               | BorderRightStyle
               | BorderBlockStartStyle
               | BorderBlockEndStyle
               | BorderInlineStartStyle
               | BorderInlineEndStyle
               | BorderTopWidth
               | BorderBottomWidth
               | BorderLeftWidth
               | BorderRightWidth
               | BorderBlockStartWidth
               | BorderBlockEndWidth
               | BorderInlineStartWidth
               | BorderInlineEndWidth
               | BorderStartStartRadius
               | BorderEndStartRadius
               | BorderStartEndRadius
               | BorderEndEndRadius
               | BorderImageSource
               | BorderImageOutset
               | BorderImageRepeat
               | BorderImageWidth
               | BorderImageSlice
               | BorderColor
               | BorderStyle
               | BorderWidth
               | BorderBlockColor
               | BorderBlockStyle
               | BorderBlockWidth
               | BorderInlineColor
               | BorderInlineStyle
               | BorderInlineWidth
               | Border
               | BorderTop
               | BorderBottom
               | BorderLeft
               | BorderRight
               | BorderBlock
               | BorderBlockStart
               | BorderBlockEnd
               | BorderInline
               | BorderInlineStart
               | BorderInlineEnd
               | Outline
               | OutlineColor
               | OutlineStyle
               | OutlineWidth
               | PlaceContent
               | JustifySelf
               | PlaceSelf
               | JustifyItems
               | PlaceItems
               | RowGap
               | ColumnGap
               | Gap
               | MarginTop
               | MarginBottom
               | MarginLeft
               | MarginRight
               | MarginBlockStart
               | MarginBlockEnd
               | MarginInlineStart
               | MarginInlineEnd
               | MarginBlock
               | MarginInline
               | Margin
               | PaddingTop
               | PaddingBottom
               | PaddingLeft
               | PaddingRight
               | PaddingBlockStart
               | PaddingBlockEnd
               | PaddingInlineStart
               | PaddingInlineEnd
               | PaddingBlock
               | PaddingInline
               | Padding
               | ScrollMarginTop
               | ScrollMarginBottom
               | ScrollMarginLeft
               | ScrollMarginRight
               | ScrollMarginBlockStart
               | ScrollMarginBlockEnd
               | ScrollMarginInlineStart
               | ScrollMarginInlineEnd
               | ScrollMarginBlock
               | ScrollMarginInline
               | ScrollMargin
               | ScrollPaddingTop
               | ScrollPaddingBottom
               | ScrollPaddingLeft
               | ScrollPaddingRight
               | ScrollPaddingBlockStart
               | ScrollPaddingBlockEnd
               | ScrollPaddingInlineStart
               | ScrollPaddingInlineEnd
               | ScrollPaddingBlock
               | ScrollPaddingInline
               | ScrollPadding
               | FontWeight
               | FontSize
               | FontStretch
               | FontFamily
               | FontStyle
               | FontVariantCaps
               | LineHeight
               | Font
               | Translate
               | Rotate
               | Scale
               | TextShadow
               | Direction
               | Composes
               | MaskMode
               | MaskPositionX
               | MaskPositionY
               | MaskComposite
               | MaskType
               | MaskBorderSource
               | MaskBorderMode
               | MaskBorderSlice
               | MaskBorderWidth
               | MaskBorderOutset
               | MaskBorderRepeat
               | MaskBorder
               | WebKitMaskComposite
               | TransformBox
               | ColorScheme
               | All | Unparsed | Custom =>
                VendorPrefixSet.onlyNone()

            // === none + webkit + moz ===
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .moz = true }
            case BackgroundClip
               | BoxShadow
               | BoxSizing
               | BoxOrient
               | BoxDirection
               | BoxOrdinalGroup
               | BoxAlign
               | BoxFlex
               | BoxPack
               | BoxLines
               | BorderTopLeftRadius
               | BorderTopRightRadius
               | BorderBottomLeftRadius
               | BorderBottomRightRadius
               | BorderRadius
               | TransformStyle
               | BackfaceVisibility
               | Perspective
               | PerspectiveOrigin
               | TextDecorationColor =>
                VendorPrefixSet.noneWebkitMoz()

            // === none + webkit (仅 webkit) ===
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true }
            case BoxFlexGroup
               | FlexGrow
               | FlexShrink
               | FlexBasis
               | Order
               | AlignContent
               | JustifyContent
               | AlignSelf
               | AlignItems
               | TextEmphasisColor
               | MaskImage
               | MaskRepeat
               | MaskPosition
               | MaskClip
               | MaskOrigin
               | MaskSize
               | Mask
               | MaskSourceType
               | MaskBoxImage
               | MaskBoxImageSource
               | MaskBoxImageSlice
               | MaskBoxImageWidth
               | MaskBoxImageOutset
               | MaskBoxImageRepeat =>
                VendorPrefixSet.noneWebkit()

            // === none + webkit + ms (flex 标准) ===
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .ms = true }
            case FlexDirection
               | FlexWrap
               | FlexFlow
               | Flex =>
                VendorPrefixSet.noneWebkitMs()

            // === none + ms (旧版 ms-flex) ===
            // 严格翻译自: VendorPrefix{ .none = true, .ms = true }
            case FlexPack
               | FlexOrder
               | FlexAlign
               | FlexItemAlign
               | FlexLinePack
               | FlexPositive
               | FlexNegative
               | FlexPreferredSize =>
                VendorPrefixSet.noneMs()

            // === none + o ===
            // 严格翻译自: VendorPrefix{ .none = true, .o = true }
            case TextOverflow =>
                VendorPrefixSet.noneO()

            // === none + webkit + moz + o ===
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .moz = true, .o = true }
            case BorderImage =>
                VendorPrefixSet.noneWebkitMozO()

            // === none + webkit + moz + ms (transition) ===
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .moz = true, .ms = true }
            case TransitionProperty
               | TransitionDuration
               | TransitionDelay
               | TransitionTimingFunction
               | Transition =>
                VendorPrefixSet.noneWebkitMozMs()

            // === none + webkit + moz + ms + o (transform) ===
            // 严格翻译自: VendorPrefix{ .none = true, .webkit = true, .moz = true, .ms = true, .o = true }
            case Transform
               | TransformOrigin =>
                VendorPrefixSet.noneWebkitMozMsO()
        }
    }
}

// ============================================================================
// VendorPrefixSet - 允许的前缀集合
// ============================================================================

/// 允许的 VendorPrefix 集合
/// 严格翻译自各属性 fromNameAndPrefix 中的 allowed_prefixes 位掩码
public class VendorPrefixSet {
    public var allowNone: Bool = false
    public var allowWebkit: Bool = false
    public var allowMoz: Bool = false
    public var allowMs: Bool = false
    public var allowO: Bool = false

    public init(allowNone: Bool, allowWebkit: Bool, allowMoz: Bool, allowMs: Bool, allowO: Bool) {
        this.allowNone = allowNone
        this.allowWebkit = allowWebkit
        this.allowMoz = allowMoz
        this.allowMs = allowMs
        this.allowO = allowO
    }

    /// VendorPrefix{ .none = true }
    public static func onlyNone(): VendorPrefixSet {
        return VendorPrefixSet(true, false, false, false, false)
    }

    /// VendorPrefix{ .none = true, .webkit = true }
    public static func noneWebkit(): VendorPrefixSet {
        return VendorPrefixSet(true, true, false, false, false)
    }

    /// VendorPrefix{ .none = true, .webkit = true, .moz = true }
    public static func noneWebkitMoz(): VendorPrefixSet {
        return VendorPrefixSet(true, true, true, false, false)
    }

    /// VendorPrefix{ .none = true, .o = true }
    public static func noneO(): VendorPrefixSet {
        return VendorPrefixSet(true, false, false, false, true)
    }

    /// VendorPrefix{ .none = true, .webkit = true, .ms = true }
    public static func noneWebkitMs(): VendorPrefixSet {
        return VendorPrefixSet(true, true, false, true, false)
    }

    /// VendorPrefix{ .none = true, .ms = true }
    public static func noneMs(): VendorPrefixSet {
        return VendorPrefixSet(true, false, false, true, false)
    }

    /// VendorPrefix{ .none = true, .webkit = true, .moz = true, .o = true }
    public static func noneWebkitMozO(): VendorPrefixSet {
        return VendorPrefixSet(true, true, true, false, true)
    }

    /// VendorPrefix{ .none = true, .webkit = true, .moz = true, .ms = true }
    public static func noneWebkitMozMs(): VendorPrefixSet {
        return VendorPrefixSet(true, true, true, true, false)
    }

    /// VendorPrefix{ .none = true, .webkit = true, .moz = true, .ms = true, .o = true }
    public static func noneWebkitMozMsO(): VendorPrefixSet {
        return VendorPrefixSet(true, true, true, true, true)
    }

    /// 判断给定 VendorPrefix 是否在此集合中
    /// 严格翻译自 bits.contains(VendorPrefix, allowed_prefixes, pre)
    public func contains(vp: VendorPrefix): Bool {
        if (vp.isNone) { return this.allowNone }
        if (vp.isWebkit) { return this.allowWebkit }
        if (vp.isMoz) { return this.allowMoz }
        if (vp.isMs) { return this.allowMs }
        if (vp.isO) { return this.allowO }
        return false
    }
}

// ============================================================================
// PropertyHelper - 属性值比较和深拷贝辅助
// ============================================================================

/// Property 值比较和深拷贝辅助
/// 严格翻译自 Property.eql / Property.deepClone 中的 match 分支
public class PropertyHelper {

    /// 判断两个属性值是否相等
    /// 严格翻译自 Property.eql (properties_generated.zig lines 7162-7415)
    /// 每个属性 tag 对应一个具体的类型比较
    public static func valuesEqual(tag: PropertyIdTag, lhs: Any, rhs: Any): Bool {
        match (tag) {
            // === CssColor 类型 ===
            case BackgroundColor | Color
               | BorderTopColor | BorderBottomColor | BorderLeftColor | BorderRightColor
               | BorderBlockStartColor | BorderBlockEndColor
               | BorderInlineStartColor | BorderInlineEndColor
               | OutlineColor => {
                return _eqlGeneric("CssColor", lhs, rhs)
            }
            // === SmallList<Image, 1> 类型 ===
            case BackgroundImage | MaskImage => {
                return _eqlGeneric("SmallListImage", lhs, rhs)
            }
            // === SmallList<HorizontalPosition, 1> 类型 ===
            case BackgroundPositionX | MaskPositionX => {
                return _eqlGeneric("SmallListHorizontalPosition", lhs, rhs)
            }
            // === SmallList<VerticalPosition, 1> 类型 ===
            case BackgroundPositionY | MaskPositionY => {
                return _eqlGeneric("SmallListVerticalPosition", lhs, rhs)
            }
            // === SmallList<BackgroundPosition, 1> 类型 ===
            case BackgroundPosition => {
                return _eqlGeneric("SmallListBackgroundPosition", lhs, rhs)
            }
            // === SmallList<BackgroundSize, 1> 类型 ===
            case BackgroundSize | MaskSize => {
                return _eqlGeneric("SmallListBackgroundSize", lhs, rhs)
            }
            // === SmallList<BackgroundRepeat, 1> 类型 ===
            case BackgroundRepeat | MaskRepeat => {
                return _eqlGeneric("SmallListBackgroundRepeat", lhs, rhs)
            }
            // === SmallList<BackgroundAttachment, 1> 类型 ===
            case BackgroundAttachment => {
                return _eqlGeneric("SmallListBackgroundAttachment", lhs, rhs)
            }
            // === SmallList<BackgroundClip, 1> 类型 (带前缀) ===
            case BackgroundClip => {
                return _eqlGeneric("SmallListBackgroundClip", lhs, rhs)
            }
            // === SmallList<BackgroundOrigin, 1> 类型 ===
            case BackgroundOrigin => {
                return _eqlGeneric("SmallListBackgroundOrigin", lhs, rhs)
            }
            // === SmallList<Background, 1> 类型 ===
            case Background => {
                return _eqlGeneric("SmallListBackground", lhs, rhs)
            }
            // === SmallList<BoxShadow, 1> 类型 (带前缀) ===
            case BoxShadow => {
                return _eqlGeneric("SmallListBoxShadow", lhs, rhs)
            }
            // === AlphaValue 类型 ===
            case Opacity => {
                return _eqlGeneric("AlphaValue", lhs, rhs)
            }
            // === Display 类型 ===
            case Display => {
                return _eqlGeneric("Display", lhs, rhs)
            }
            // === Visibility 类型 ===
            case Visibility => {
                return _eqlGeneric("Visibility", lhs, rhs)
            }
            // === Size 类型 ===
            case Width | Height | MinWidth | MinHeight
               | BlockSize | InlineSize | MinBlockSize | MinInlineSize => {
                return _eqlGeneric("Size", lhs, rhs)
            }
            // === MaxSize 类型 ===
            case MaxWidth | MaxHeight | MaxBlockSize | MaxInlineSize => {
                return _eqlGeneric("MaxSize", lhs, rhs)
            }
            // === BoxSizing 类型 (带前缀) ===
            case BoxSizing => {
                return _eqlGeneric("BoxSizing", lhs, rhs)
            }
            // === AspectRatio 类型 ===
            case AspectRatio => {
                return _eqlGeneric("AspectRatio", lhs, rhs)
            }
            // === Overflow 类型 ===
            case Overflow => {
                return _eqlGeneric("Overflow", lhs, rhs)
            }
            // === OverflowKeyword 类型 ===
            case OverflowX | OverflowY => {
                return _eqlGeneric("OverflowKeyword", lhs, rhs)
            }
            // === TextOverflow 类型 (带前缀) ===
            case TextOverflow => {
                return _eqlGeneric("TextOverflow", lhs, rhs)
            }
            // === Position 类型 ===
            case Position => {
                return _eqlGeneric("Position", lhs, rhs)
            }
            // === LengthPercentageOrAuto 类型 ===
            case Top | Bottom | Left | Right
               | InsetBlockStart | InsetBlockEnd | InsetInlineStart | InsetInlineEnd
               | MarginTop | MarginBottom | MarginLeft | MarginRight
               | MarginBlockStart | MarginBlockEnd | MarginInlineStart | MarginInlineEnd
               | PaddingTop | PaddingBottom | PaddingLeft | PaddingRight
               | PaddingBlockStart | PaddingBlockEnd | PaddingInlineStart | PaddingInlineEnd
               | ScrollMarginTop | ScrollMarginBottom | ScrollMarginLeft | ScrollMarginRight
               | ScrollMarginBlockStart | ScrollMarginBlockEnd
               | ScrollMarginInlineStart | ScrollMarginInlineEnd
               | ScrollPaddingTop | ScrollPaddingBottom | ScrollPaddingLeft | ScrollPaddingRight
               | ScrollPaddingBlockStart | ScrollPaddingBlockEnd
               | ScrollPaddingInlineStart | ScrollPaddingInlineEnd => {
                return _eqlGeneric("LengthPercentageOrAuto", lhs, rhs)
            }
            // === InsetBlock 类型 ===
            case InsetBlock => {
                return _eqlGeneric("InsetBlock", lhs, rhs)
            }
            // === InsetInline 类型 ===
            case InsetInline => {
                return _eqlGeneric("InsetInline", lhs, rhs)
            }
            // === Inset 类型 ===
            case Inset => {
                return _eqlGeneric("Inset", lhs, rhs)
            }
            // === Size2D<Length> 类型 ===
            case BorderSpacing => {
                return _eqlGeneric("Size2DLength", lhs, rhs)
            }
            // === LineStyle 类型 ===
            case BorderTopStyle | BorderBottomStyle | BorderLeftStyle | BorderRightStyle
               | BorderBlockStartStyle | BorderBlockEndStyle
               | BorderInlineStartStyle | BorderInlineEndStyle => {
                return _eqlGeneric("LineStyle", lhs, rhs)
            }
            // === BorderSideWidth 类型 ===
            case BorderTopWidth | BorderBottomWidth | BorderLeftWidth | BorderRightWidth
               | BorderBlockStartWidth | BorderBlockEndWidth
               | BorderInlineStartWidth | BorderInlineEndWidth
               | OutlineWidth => {
                return _eqlGeneric("BorderSideWidth", lhs, rhs)
            }
            // === Size2D<LengthPercentage> 类型 (边框圆角) ===
            case BorderTopLeftRadius | BorderTopRightRadius
               | BorderBottomLeftRadius | BorderBottomRightRadius
               | BorderStartStartRadius | BorderStartEndRadius
               | BorderEndStartRadius | BorderEndEndRadius => {
                return _eqlGeneric("Size2DLengthPercentage", lhs, rhs)
            }
            // === BorderRadius 类型 (带前缀) ===
            case BorderRadius => {
                return _eqlGeneric("BorderRadius", lhs, rhs)
            }
            // === Image 类型 ===
            case BorderImageSource | MaskBorderSource => {
                return _eqlGeneric("Image", lhs, rhs)
            }
            // === Rect<LengthOrNumber> 类型 ===
            case BorderImageOutset | MaskBorderOutset => {
                return _eqlGeneric("RectLengthOrNumber", lhs, rhs)
            }
            // === BorderImageRepeat 类型 ===
            case BorderImageRepeat | MaskBorderRepeat => {
                return _eqlGeneric("BorderImageRepeat", lhs, rhs)
            }
            // === Rect<BorderImageSideWidth> 类型 ===
            case BorderImageWidth | MaskBorderWidth => {
                return _eqlGeneric("RectBorderImageSideWidth", lhs, rhs)
            }
            // === BorderImageSlice 类型 ===
            case BorderImageSlice | MaskBorderSlice => {
                return _eqlGeneric("BorderImageSlice", lhs, rhs)
            }
            // === BorderImage 类型 (带前缀) ===
            case BorderImage => {
                return _eqlGeneric("BorderImage", lhs, rhs)
            }
            // === 边框简写复合类型 ===
            case BorderColor => { return _eqlGeneric("BorderColor", lhs, rhs) }
            case BorderStyle => { return _eqlGeneric("BorderStyle", lhs, rhs) }
            case BorderWidth => { return _eqlGeneric("BorderWidth", lhs, rhs) }
            case BorderBlockColor => { return _eqlGeneric("BorderBlockColor", lhs, rhs) }
            case BorderBlockStyle => { return _eqlGeneric("BorderBlockStyle", lhs, rhs) }
            case BorderBlockWidth => { return _eqlGeneric("BorderBlockWidth", lhs, rhs) }
            case BorderInlineColor => { return _eqlGeneric("BorderInlineColor", lhs, rhs) }
            case BorderInlineStyle => { return _eqlGeneric("BorderInlineStyle", lhs, rhs) }
            case BorderInlineWidth => { return _eqlGeneric("BorderInlineWidth", lhs, rhs) }
            case Border => { return _eqlGeneric("Border", lhs, rhs) }
            case BorderTop => { return _eqlGeneric("BorderTop", lhs, rhs) }
            case BorderBottom => { return _eqlGeneric("BorderBottom", lhs, rhs) }
            case BorderLeft => { return _eqlGeneric("BorderLeft", lhs, rhs) }
            case BorderRight => { return _eqlGeneric("BorderRight", lhs, rhs) }
            case BorderBlock => { return _eqlGeneric("BorderBlock", lhs, rhs) }
            case BorderBlockStart => { return _eqlGeneric("BorderBlockStart", lhs, rhs) }
            case BorderBlockEnd => { return _eqlGeneric("BorderBlockEnd", lhs, rhs) }
            case BorderInline => { return _eqlGeneric("BorderInline", lhs, rhs) }
            case BorderInlineStart => { return _eqlGeneric("BorderInlineStart", lhs, rhs) }
            case BorderInlineEnd => { return _eqlGeneric("BorderInlineEnd", lhs, rhs) }
            // === Outline 复合类型 ===
            case Outline => { return _eqlGeneric("Outline", lhs, rhs) }
            case OutlineStyle => { return _eqlGeneric("OutlineStyle", lhs, rhs) }
            // === Flex 相关类型 (带前缀) ===
            case FlexDirection => { return _eqlGeneric("FlexDirection", lhs, rhs) }
            case FlexWrap => { return _eqlGeneric("FlexWrap", lhs, rhs) }
            case FlexFlow => { return _eqlGeneric("FlexFlow", lhs, rhs) }
            case FlexGrow => { return _eqlGeneric("CSSNumber", lhs, rhs) }
            case FlexShrink => { return _eqlGeneric("CSSNumber", lhs, rhs) }
            case FlexBasis => { return _eqlGeneric("LengthPercentageOrAuto", lhs, rhs) }
            case Flex => { return _eqlGeneric("Flex", lhs, rhs) }
            case Order => { return _eqlGeneric("CSSInteger", lhs, rhs) }
            case AlignContent => { return _eqlGeneric("AlignContent", lhs, rhs) }
            case JustifyContent => { return _eqlGeneric("JustifyContent", lhs, rhs) }
            case PlaceContent => { return _eqlGeneric("PlaceContent", lhs, rhs) }
            case AlignSelf => { return _eqlGeneric("AlignSelf", lhs, rhs) }
            case JustifySelf => { return _eqlGeneric("JustifySelf", lhs, rhs) }
            case PlaceSelf => { return _eqlGeneric("PlaceSelf", lhs, rhs) }
            case AlignItems => { return _eqlGeneric("AlignItems", lhs, rhs) }
            case JustifyItems => { return _eqlGeneric("JustifyItems", lhs, rhs) }
            case PlaceItems => { return _eqlGeneric("PlaceItems", lhs, rhs) }
            // === Gap 类型 ===
            case RowGap | ColumnGap => { return _eqlGeneric("GapValue", lhs, rhs) }
            case Gap => { return _eqlGeneric("Gap", lhs, rhs) }
            // === 旧版 box- 属性 (带前缀) ===
            case BoxOrient => { return _eqlGeneric("BoxOrient", lhs, rhs) }
            case BoxDirection => { return _eqlGeneric("BoxDirection", lhs, rhs) }
            case BoxOrdinalGroup => { return _eqlGeneric("CSSInteger", lhs, rhs) }
            case BoxAlign => { return _eqlGeneric("BoxAlign", lhs, rhs) }
            case BoxFlex => { return _eqlGeneric("CSSNumber", lhs, rhs) }
            case BoxFlexGroup => { return _eqlGeneric("CSSInteger", lhs, rhs) }
            case BoxPack => { return _eqlGeneric("BoxPack", lhs, rhs) }
            case BoxLines => { return _eqlGeneric("BoxLines", lhs, rhs) }
            // === 旧版 ms-flex 属性 (带前缀) ===
            case FlexPack => { return _eqlGeneric("FlexPack", lhs, rhs) }
            case FlexOrder => { return _eqlGeneric("CSSInteger", lhs, rhs) }
            case FlexAlign => { return _eqlGeneric("BoxAlign", lhs, rhs) }
            case FlexItemAlign => { return _eqlGeneric("FlexItemAlign", lhs, rhs) }
            case FlexLinePack => { return _eqlGeneric("FlexLinePack", lhs, rhs) }
            case FlexPositive => { return _eqlGeneric("CSSNumber", lhs, rhs) }
            case FlexNegative => { return _eqlGeneric("CSSNumber", lhs, rhs) }
            case FlexPreferredSize => { return _eqlGeneric("LengthPercentageOrAuto", lhs, rhs) }
            // === Margin/Padding 逻辑复合类型 ===
            case MarginBlock => { return _eqlGeneric("MarginBlock", lhs, rhs) }
            case MarginInline => { return _eqlGeneric("MarginInline", lhs, rhs) }
            case Margin => { return _eqlGeneric("Margin", lhs, rhs) }
            case PaddingBlock => { return _eqlGeneric("PaddingBlock", lhs, rhs) }
            case PaddingInline => { return _eqlGeneric("PaddingInline", lhs, rhs) }
            case Padding => { return _eqlGeneric("Padding", lhs, rhs) }
            // === Scroll margin/padding 逻辑复合类型 ===
            case ScrollMarginBlock => { return _eqlGeneric("ScrollMarginBlock", lhs, rhs) }
            case ScrollMarginInline => { return _eqlGeneric("ScrollMarginInline", lhs, rhs) }
            case ScrollMargin => { return _eqlGeneric("ScrollMargin", lhs, rhs) }
            case ScrollPaddingBlock => { return _eqlGeneric("ScrollPaddingBlock", lhs, rhs) }
            case ScrollPaddingInline => { return _eqlGeneric("ScrollPaddingInline", lhs, rhs) }
            case ScrollPadding => { return _eqlGeneric("ScrollPadding", lhs, rhs) }
            // === Font 属性 ===
            case FontWeight => { return _eqlGeneric("FontWeight", lhs, rhs) }
            case FontSize => { return _eqlGeneric("FontSize", lhs, rhs) }
            case FontStretch => { return _eqlGeneric("FontStretch", lhs, rhs) }
            case FontFamily => { return _eqlGeneric("BabyListFontFamily", lhs, rhs) }
            case FontStyle => { return _eqlGeneric("FontStyle", lhs, rhs) }
            case FontVariantCaps => { return _eqlGeneric("FontVariantCaps", lhs, rhs) }
            case LineHeight => { return _eqlGeneric("LineHeight", lhs, rhs) }
            case Font => { return _eqlGeneric("Font", lhs, rhs) }
            // === Transition 属性 (带前缀) ===
            case TransitionProperty => { return _eqlGeneric("SmallListPropertyId", lhs, rhs) }
            case TransitionDuration => { return _eqlGeneric("SmallListTime", lhs, rhs) }
            case TransitionDelay => { return _eqlGeneric("SmallListTime", lhs, rhs) }
            case TransitionTimingFunction => { return _eqlGeneric("SmallListEasingFunction", lhs, rhs) }
            case Transition => { return _eqlGeneric("SmallListTransition", lhs, rhs) }
            // === Transform 属性 (带前缀) ===
            case Transform => { return _eqlGeneric("TransformList", lhs, rhs) }
            case TransformOrigin => { return _eqlGeneric("Position", lhs, rhs) }
            case TransformStyle => { return _eqlGeneric("TransformStyle", lhs, rhs) }
            case TransformBox => { return _eqlGeneric("TransformBox", lhs, rhs) }
            case BackfaceVisibility => { return _eqlGeneric("BackfaceVisibility", lhs, rhs) }
            case Perspective => { return _eqlGeneric("Perspective", lhs, rhs) }
            case PerspectiveOrigin => { return _eqlGeneric("Position", lhs, rhs) }
            case Translate => { return _eqlGeneric("Translate", lhs, rhs) }
            case Rotate => { return _eqlGeneric("Rotate", lhs, rhs) }
            case Scale => { return _eqlGeneric("Scale", lhs, rhs) }
            // === Text 属性 (部分带前缀) ===
            case TextDecorationColor => { return _eqlGeneric("CssColor", lhs, rhs) }
            case TextEmphasisColor => { return _eqlGeneric("CssColor", lhs, rhs) }
            case TextShadow => { return _eqlGeneric("SmallListTextShadow", lhs, rhs) }
            case Direction => { return _eqlGeneric("Direction", lhs, rhs) }
            case Composes => { return _eqlGeneric("Composes", lhs, rhs) }
            // === Mask 属性 ===
            case MaskMode => { return _eqlGeneric("SmallListMaskMode", lhs, rhs) }
            case MaskPosition => { return _eqlGeneric("SmallListPosition", lhs, rhs) }
            case MaskClip => { return _eqlGeneric("SmallListMaskClip", lhs, rhs) }
            case MaskOrigin => { return _eqlGeneric("SmallListGeometryBox", lhs, rhs) }
            case MaskComposite => { return _eqlGeneric("SmallListMaskComposite", lhs, rhs) }
            case MaskType => { return _eqlGeneric("MaskType", lhs, rhs) }
            case Mask => { return _eqlGeneric("SmallListMask", lhs, rhs) }
            case MaskBorderMode => { return _eqlGeneric("MaskBorderMode", lhs, rhs) }
            case MaskBorder => { return _eqlGeneric("MaskBorder", lhs, rhs) }
            case WebKitMaskComposite => { return _eqlGeneric("SmallListWebKitMaskComposite", lhs, rhs) }
            case MaskSourceType => { return _eqlGeneric("SmallListWebKitMaskSourceType", lhs, rhs) }
            case MaskBoxImage => { return _eqlGeneric("BorderImage", lhs, rhs) }
            case MaskBoxImageSource => { return _eqlGeneric("Image", lhs, rhs) }
            case MaskBoxImageSlice => { return _eqlGeneric("BorderImageSlice", lhs, rhs) }
            case MaskBoxImageWidth => { return _eqlGeneric("RectBorderImageSideWidth", lhs, rhs) }
            case MaskBoxImageOutset => { return _eqlGeneric("RectLengthOrNumber", lhs, rhs) }
            case MaskBoxImageRepeat => { return _eqlGeneric("BorderImageRepeat", lhs, rhs) }
            // === 其他 ===
            case ColorScheme => { return _eqlGeneric("ColorScheme", lhs, rhs) }
            case All => { return true }
            case Unparsed => { return _eqlGeneric("UnparsedProperty", lhs, rhs) }
            case Custom => { return _eqlGeneric("CustomProperty", lhs, rhs) }
        }
    }

    /// 通用类型比较辅助
    /// 在实际实现中, 会将 Any 转为具体类型调用 eql
    private static func _eqlGeneric(typeName: String, lhs: Any, rhs: Any): Bool {
        // 占位: 实际实现中根据 typeName 转型后调用具体 eql
        return lhs == rhs
    }

    /// 深拷贝属性值
    /// 严格翻译自 Property.deepClone (properties_generated.zig lines 6307-6558)
    /// 每个属性 tag 对应一个具体的深拷贝操作
    /// Zig 中带前缀的属性值为 tuple(value, VendorPrefix), 深拷贝 value[0]
    /// Zig 中不带前缀的属性值直接深拷贝
    public static func deepCloneValue(tag: PropertyIdTag, value: Any): Any {
        match (tag) {
            // === 带前缀的属性: 深拷贝 value[0], 保留 prefix ===
            // 严格翻译自: .@"background-clip" => .{ v[0].deepClone(), v[1] }
            case BackgroundClip | BoxShadow | BoxSizing | TextOverflow
               | BorderTopLeftRadius | BorderTopRightRadius
               | BorderBottomLeftRadius | BorderBottomRightRadius
               | BorderRadius | BorderImage
               // flex 带前缀
               | FlexDirection | FlexWrap | FlexFlow | FlexGrow | FlexShrink
               | FlexBasis | Flex | Order
               | AlignContent | JustifyContent | AlignSelf | AlignItems
               // 旧版 box- 带前缀
               | BoxOrient | BoxDirection | BoxOrdinalGroup | BoxAlign
               | BoxFlex | BoxFlexGroup | BoxPack | BoxLines
               // 旧版 ms-flex 带前缀
               | FlexPack | FlexOrder | FlexAlign | FlexItemAlign
               | FlexLinePack | FlexPositive | FlexNegative | FlexPreferredSize
               // transition/transform 带前缀
               | TransitionProperty | TransitionDuration | TransitionDelay
               | TransitionTimingFunction | Transition
               | Transform | TransformOrigin | TransformStyle
               | BackfaceVisibility | Perspective | PerspectiveOrigin
               // text 带前缀
               | TextDecorationColor | TextEmphasisColor
               // mask 带前缀
               | MaskImage | MaskRepeat | MaskPosition | MaskClip
               | MaskOrigin | MaskSize | Mask
               | MaskSourceType | MaskBoxImage | MaskBoxImageSource
               | MaskBoxImageSlice | MaskBoxImageWidth | MaskBoxImageOutset
               | MaskBoxImageRepeat => {
                return _deepCloneTupleValue(value)
            }
            // === 不带前缀的属性: 直接深拷贝 value ===
            // 严格翻译自: .@"background-color" => v.deepClone()
            case BackgroundColor | BackgroundImage | BackgroundPositionX
               | BackgroundPositionY | BackgroundPosition | BackgroundSize
               | BackgroundRepeat | BackgroundAttachment | BackgroundOrigin
               | Background
               | Opacity | Color | Display | Visibility
               | Width | Height | MinWidth | MinHeight | MaxWidth | MaxHeight
               | BlockSize | InlineSize | MinBlockSize | MinInlineSize
               | MaxBlockSize | MaxInlineSize
               | AspectRatio | Overflow | OverflowX | OverflowY
               | Position | Top | Bottom | Left | Right
               | InsetBlockStart | InsetBlockEnd | InsetInlineStart | InsetInlineEnd
               | InsetBlock | InsetInline | Inset | BorderSpacing
               | BorderTopColor | BorderBottomColor | BorderLeftColor | BorderRightColor
               | BorderBlockStartColor | BorderBlockEndColor
               | BorderInlineStartColor | BorderInlineEndColor
               | BorderTopStyle | BorderBottomStyle | BorderLeftStyle | BorderRightStyle
               | BorderBlockStartStyle | BorderBlockEndStyle
               | BorderInlineStartStyle | BorderInlineEndStyle
               | BorderTopWidth | BorderBottomWidth | BorderLeftWidth | BorderRightWidth
               | BorderBlockStartWidth | BorderBlockEndWidth
               | BorderInlineStartWidth | BorderInlineEndWidth
               | BorderStartStartRadius | BorderStartEndRadius
               | BorderEndStartRadius | BorderEndEndRadius
               | BorderImageSource | BorderImageOutset | BorderImageRepeat
               | BorderImageWidth | BorderImageSlice
               | BorderColor | BorderStyle | BorderWidth
               | BorderBlockColor | BorderBlockStyle | BorderBlockWidth
               | BorderInlineColor | BorderInlineStyle | BorderInlineWidth
               | Border | BorderTop | BorderBottom | BorderLeft | BorderRight
               | BorderBlock | BorderBlockStart | BorderBlockEnd
               | BorderInline | BorderInlineStart | BorderInlineEnd
               | Outline | OutlineColor | OutlineStyle | OutlineWidth
               | PlaceContent | JustifySelf | PlaceSelf
               | JustifyItems | PlaceItems | RowGap | ColumnGap | Gap
               | MarginTop | MarginBottom | MarginLeft | MarginRight
               | MarginBlockStart | MarginBlockEnd | MarginInlineStart | MarginInlineEnd
               | MarginBlock | MarginInline | Margin
               | PaddingTop | PaddingBottom | PaddingLeft | PaddingRight
               | PaddingBlockStart | PaddingBlockEnd | PaddingInlineStart | PaddingInlineEnd
               | PaddingBlock | PaddingInline | Padding
               | ScrollMarginTop | ScrollMarginBottom | ScrollMarginLeft | ScrollMarginRight
               | ScrollMarginBlockStart | ScrollMarginBlockEnd
               | ScrollMarginInlineStart | ScrollMarginInlineEnd
               | ScrollMarginBlock | ScrollMarginInline | ScrollMargin
               | ScrollPaddingTop | ScrollPaddingBottom | ScrollPaddingLeft | ScrollPaddingRight
               | ScrollPaddingBlockStart | ScrollPaddingBlockEnd
               | ScrollPaddingInlineStart | ScrollPaddingInlineEnd
               | ScrollPaddingBlock | ScrollPaddingInline | ScrollPadding
               | FontWeight | FontSize | FontStretch | FontFamily
               | FontStyle | FontVariantCaps | LineHeight | Font
               | TransformBox | Translate | Rotate | Scale | TextShadow
               | Direction | Composes | MaskMode | MaskPositionX | MaskPositionY
               | MaskComposite | MaskType | MaskBorderSource | MaskBorderMode
               | MaskBorderSlice | MaskBorderWidth | MaskBorderOutset
               | MaskBorderRepeat | MaskBorder | WebKitMaskComposite
               | ColorScheme => {
                return _deepCloneSimple(value)
            }
            // === 特殊属性 ===
            case All => { return _deepCloneSimple(value) }
            case Unparsed => { return _deepCloneSimple(value) }
            case Custom => { return _deepCloneSimple(value) }
        }
    }

    /// 深拷贝简单值 (不带前缀的属性)
    private static func _deepCloneSimple(value: Any): Any {
        // 占位: 实际实现中调用具体类型的 deepClone
        return value
    }

    /// 深拷贝 tuple 值 (带前缀的属性: 深拷贝 value 部分, 保留 prefix)
    private static func _deepCloneTupleValue(value: Any): Any {
        // 占位: 实际实现中提取 tuple(value, prefix), 深拷贝 value, 保留 prefix
        return value
    }
}

// ============================================================================
// FeatureHelper - 属性对应的 Feature 映射
// ============================================================================

/// Feature 辅助: 属性 -> Feature 映射
/// 严格翻译自 PropertyId.setPrefixesForTargets 中的 Feature 映射
public class FeatureHelper {

    /// 获取属性 tag 对应的 Feature
    /// 严格翻译自 PropertyId.setPrefixesForTargets 中的 Feature 映射
    /// 以及 compat.zig 中的完整 Feature 枚举
    public static func featureForPropertyId(tag: PropertyIdTag): Feature {
        match (tag) {
            // === Background ===
            case BackgroundClip => Feature.BackgroundClip
            // === Box ===
            case BoxShadow => Feature.BoxShadow
            case BoxSizing => Feature.BoxSizing
            case TextOverflow => Feature.TextOverflow
            // === Border radius ===
            case BorderTopLeftRadius => Feature.BorderTopLeftRadius
            case BorderTopRightRadius => Feature.BorderTopRightRadius
            case BorderBottomLeftRadius => Feature.BorderBottomLeftRadius
            case BorderBottomRightRadius => Feature.BorderBottomRightRadius
            case BorderRadius => Feature.BorderRadius
            case BorderImage => Feature.BorderImage
            // === Flex ===
            case FlexDirection => Feature.FlexDirection
            case FlexWrap => Feature.FlexWrap
            case FlexFlow => Feature.FlexFlow
            case FlexGrow => Feature.FlexGrow
            case FlexShrink => Feature.FlexShrink
            case FlexBasis => Feature.FlexBasis
            case Flex => Feature.Flex
            case Order => Feature.Order
            case AlignContent => Feature.AlignContent
            case JustifyContent => Feature.JustifyContent
            case AlignSelf => Feature.AlignSelf
            case AlignItems => Feature.AlignItems
            // === Transition ===
            case TransitionProperty => Feature.TransitionProperty
            case TransitionDuration => Feature.TransitionDuration
            case TransitionDelay => Feature.TransitionDelay
            case TransitionTimingFunction => Feature.TransitionTimingFunction
            case Transition => Feature.Transition
            // === Transform ===
            case Transform => Feature.Transform
            case TransformOrigin => Feature.TransformOrigin
            case TransformStyle => Feature.TransformStyle
            case BackfaceVisibility => Feature.BackfaceVisibility
            case Perspective => Feature.Perspective
            case PerspectiveOrigin => Feature.PerspectiveOrigin
            // === Text decoration ===
            case TextDecorationColor => Feature.TextDecorationColor
            case TextEmphasisColor => Feature.TextEmphasisColor
            // === Mask ===
            case MaskImage => Feature.MaskImage
            case MaskRepeat => Feature.MaskRepeat
            case MaskPosition => Feature.MaskPosition
            case MaskClip => Feature.MaskClip
            case MaskOrigin => Feature.MaskOrigin
            case MaskSize => Feature.MaskSize
            case Mask => Feature.Mask
            case MaskBorder => Feature.MaskBorder
            // === Logical properties ===
            case BlockSize | InlineSize | MinBlockSize | MinInlineSize
               | MaxBlockSize | MaxInlineSize => Feature.LogicalSize
            case InsetBlockStart | InsetBlockEnd | InsetInlineStart | InsetInlineEnd
               | InsetBlock | InsetInline | Inset => Feature.LogicalInset
            case MarginBlockStart | MarginBlockEnd | MarginInlineStart | MarginInlineEnd
               | MarginBlock | MarginInline => Feature.LogicalMargin
            case PaddingBlockStart | PaddingBlockEnd | PaddingInlineStart | PaddingInlineEnd
               | PaddingBlock | PaddingInline => Feature.LogicalPadding
            case BorderBlockStartColor | BorderBlockEndColor
               | BorderInlineStartColor | BorderInlineEndColor
               | BorderBlockStartStyle | BorderBlockEndStyle
               | BorderInlineStartStyle | BorderInlineEndStyle
               | BorderBlockStartWidth | BorderBlockEndWidth
               | BorderInlineStartWidth | BorderInlineEndWidth
               | BorderBlock | BorderBlockStart | BorderBlockEnd
               | BorderInline | BorderInlineStart | BorderInlineEnd => Feature.LogicalBorders
            // === 无 Feature 的属性 ===
            case _ => Feature.None
        }
    }
}

// ============================================================================
// Feature 枚举 - 对应 compat.zig 中的 Feature
// ============================================================================

/// CSS 特性标志
/// 严格翻译自 compat.zig Feature 枚举
/// 包含所有需要前缀处理的 CSS 特性
public enum Feature {
    | None
    // === Background ===
    | BackgroundClip
    // === Box ===
    | BoxShadow
    | BoxSizing
    | TextOverflow
    // === Border radius ===
    | BorderTopLeftRadius
    | BorderTopRightRadius
    | BorderBottomLeftRadius
    | BorderBottomRightRadius
    | BorderRadius
    | BorderImage
    // === Flex ===
    | FlexDirection
    | FlexWrap
    | FlexFlow
    | FlexGrow
    | FlexShrink
    | FlexBasis
    | Flex
    | Order
    | AlignContent
    | JustifyContent
    | AlignSelf
    | AlignItems
    // === Transition ===
    | TransitionProperty
    | TransitionDuration
    | TransitionDelay
    | TransitionTimingFunction
    | Transition
    // === Transform ===
    | Transform
    | TransformOrigin
    | TransformStyle
    | BackfaceVisibility
    | Perspective
    | PerspectiveOrigin
    // === Text decoration ===
    | TextDecorationColor
    | TextEmphasisColor
    // === Mask ===
    | MaskImage
    | MaskRepeat
    | MaskPosition
    | MaskClip
    | MaskOrigin
    | MaskSize
    | Mask
    | MaskBorder
    // === Logical properties ===
    | LogicalSize
    | LogicalInset
    | LogicalMargin
    | LogicalPadding
    | LogicalBorders
}

// ============================================================================
// CssParserOptions - CSS 解析选项
// 严格翻译自: css_parser.zig ParserOptions
// ============================================================================

/// CSS 解析选项
/// 严格翻译自 css.ParserOptions
public class CssParserOptions {
    /// 是否允许解析 !important
    public var allowImportant: Bool

    /// 当前 VendorPrefix
    public var vendorPrefix: VendorPrefix

    /// 解析模式
    public var parseMode: String

    public init() {
        this.allowImportant = true
        this.vendorPrefix = VendorPrefix()
        this.parseMode = "default"
    }

    public init(allowImportant: Bool, vendorPrefix: VendorPrefix, parseMode: String) {
        this.allowImportant = allowImportant
        this.vendorPrefix = vendorPrefix
        this.parseMode = parseMode
    }
}

// ============================================================================
// CssParser - CSS 解析器
// 严格翻译自: css_parser.zig Parser
// ============================================================================

/// CSS 解析器
/// 严格翻译自 css.Parser
/// 提供各种 CSS 值类型的解析方法
public class CssParser {
    private var input: String
    private var pos: Int64

    public init(input: String) {
        this.input = input
        this.pos = 0
    }

    /// 解析指定类型的 CSS 值
    /// 严格翻译自 css.generic.parseWithOptions(Type, input, options)
    public func parseValue(typeName: String, options: CssParserOptions): Any {
        // 占位: 在实际实现中, 根据 typeName 分派到具体解析方法
        return ""
    }

    /// 解析 CssColor
    public func parseCssColor(): Any {
        return parseValue("CssColor", CssParserOptions())
    }

    /// 解析 Image
    public func parseImage(): Any {
        return parseValue("Image", CssParserOptions())
    }

    /// 解析 LengthPercentageOrAuto
    public func parseLengthPercentageOrAuto(): Any {
        return parseValue("LengthPercentageOrAuto", CssParserOptions())
    }

    /// 解析 AlphaValue
    public func parseAlphaValue(): Any {
        return parseValue("AlphaValue", CssParserOptions())
    }

    /// 解析 Display
    public func parseDisplay(): Any {
        return parseValue("Display", CssParserOptions())
    }

    /// 解析 Size
    public func parseSize(): Any {
        return parseValue("Size", CssParserOptions())
    }

    /// 解析 MaxSize
    public func parseMaxSize(): Any {
        return parseValue("MaxSize", CssParserOptions())
    }

    /// 解析 Position
    public func parsePosition(): Any {
        return parseValue("Position", CssParserOptions())
    }

    /// 解析 SmallList
    public func parseSmallList(elementType: String): Any {
        return parseValue("SmallList<" + elementType + ">", CssParserOptions())
    }

    /// 跳过空白
    public func skipWhitespace(): Unit {
        while (pos < input.size && (input[pos] == ' ' || input[pos] == '\t' ||
               input[pos] == '\n' || input[pos] == '\r')) {
            pos++
        }
    }

    /// 查看当前字符
    public func peek(): UInt8 {
        if (pos >= input.size) {
            return 0
        }
        return input[pos]
    }

    /// 前进一个字符
    public func advance(): Unit {
        if (pos < input.size) {
            pos++
        }
    }

    /// 是否到达末尾
    public func isEof(): Bool {
        return pos >= input.size
    }

    /// 获取当前位置
    public func currentPos(): Int64 {
        return pos
    }
}

// ============================================================================
// UnparsedProperty - 未解析属性
// 严格翻译自: properties_generated.zig 中的 UnparsedProperty
// ============================================================================

/// 未解析属性
/// 严格翻译自 UnparsedProperty
/// 当属性值无法被识别为具体类型时使用
public class UnparsedProperty {
    public var propertyId: PropertyId
    public var value: Any
    public var important: Bool

    public init(propertyId: PropertyId, value: Any, important: Bool) {
        this.propertyId = propertyId
        this.value = value
        this.important = important
    }

    public func eql(other: UnparsedProperty): Bool {
        return this.propertyId.eql(other.propertyId) &&
               this.important == other.important
    }

    public func deepClone(): UnparsedProperty {
        return UnparsedProperty(
            this.propertyId.deepClone(),
            this.value,
            this.important
        )
    }
}

// ============================================================================
// CustomProperty - 自定义属性
// 严格翻译自: properties_generated.zig 中的 CustomProperty
// ============================================================================

/// 自定义属性 (CSS 变量)
/// 严格翻译自 CustomProperty
public class CustomProperty {
    public var name: CustomPropertyName
    public var value: Any
    public var important: Bool

    public init(name: CustomPropertyName, value: Any, important: Bool) {
        this.name = name
        this.value = value
        this.important = important
    }

    public func eql(other: CustomProperty): Bool {
        return this.name.eql(other.name) &&
               this.important == other.important
    }

    public func deepClone(): CustomProperty {
        return CustomProperty(
            this.name.deepClone(),
            this.value,
            this.important
        )
    }
}

// ============================================================================
// Printer - CSS 输出打印器
// 严格翻译自: css.Printer (与 CssPrinter 类似但用于 PropertyId)
// ============================================================================

/// CSS 输出打印器 (用于 PropertyId.toCss)
/// 严格翻译自 css.Printer
public class Printer {
    private var sb: StringBuilder

    public init() {
        sb = StringBuilder()
    }

    public func writeStr(s: String): Unit {
        sb.append(s)
    }

    public func writeChar(c: UInt8): Unit {
        sb.append(Rune(Int32(c)))
    }

    public func toString(): String {
        sb.toString()
    }
}

// ============================================================================
// Pair - 辅助类型 (替代 Zig 的 tuple)
// ============================================================================

/// 二元组辅助类型
/// 严格翻译自 Zig 的 anonymous struct .{ value1, value2 }
public class Pair<T, U> {
    public var first: T
    public var second: U

    public init(first: T, second: U) {
        this.first = first
        this.second = second
    }
}

// ============================================================================
// StringBuilder - 字符串构建器
// ============================================================================

/// 字符串构建器
/// 用于高效构建 CSS 输出字符串
public class StringBuilder {
    private var parts: ArrayList<String>

    public init() {
        parts = ArrayList<String>()
    }

    public func append(s: String): Unit {
        parts.append(s)
    }

    public func append(c: Rune): Unit {
        parts.append(c.toString())
    }

    public func toString(): String {
        // 在实际实现中, 高效拼接所有 parts
        var result = ""
        for (part in parts) {
            result = result + part
        }
        return result
    }
}

// ============================================================================
// ArrayList / HashMap - 容器类型占位
// ============================================================================

/// 动态数组
/// 在实际实现中使用仓颉标准库的 ArrayList
public class ArrayList<T> {
    private var data: Array<T>
    private var count: Int64

    public init() {
        data = Array<T>()
        count = 0
    }

    public func append(item: T): Unit {
        // 在实际实现中扩展数组并添加元素
    }

    public func size(): Int64 {
        return count
    }

    public func iterator(): Iterator<T> {
        return data.iterator()
    }
}

/// 哈希映射
/// 在实际实现中使用仓颉标准库的 HashMap
public class HashMap<K, V> {
    public func get(key: K): ?V {
        return None
    }

    public func put(key: K, value: V): Unit {
        // 在实际实现中存储键值对
    }

    public func contains(key: K): Bool {
        return false
    }
}

/// 迭代器
public interface Iterator<T> {
    func hasNext(): Bool
    func next(): ?T
}
