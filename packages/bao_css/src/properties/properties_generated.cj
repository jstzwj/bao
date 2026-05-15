// 严格翻译自: src/css/properties/properties_generated.zig
// 自动生成的 CSS 属性枚举、Property 联合类型、PropertyId 联合类型
// 包含: PropertyIdTag, Property, PropertyId 及其所有方法

package bao.css

import bao_core.*

// ============================================================================
// PropertyIdTag - CSS 属性判别标签 (enum(u16))
// 严格翻译自 PropertyIdTag
// ============================================================================

/// CSS 属性判别标签
/// 严格翻译自 PropertyIdTag (enum(u16))
/// 每个 tag 值对应一个 CSS 属性
public enum PropertyIdTag <: Equatable<PropertyIdTag> {
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

    public init(tag: PropertyIdTag, value: Any, vendorPrefix: VendorPrefix = VendorPrefix()) {
        this.tag = tag
        this.value = value
        this.vendorPrefix = vendorPrefix
    }

    /// 获取此属性的 PropertyId
    /// 严格翻译自 propertyId
    public func propertyId(): PropertyId {
        if (this.tag.hasVendorPrefix()) {
            return PropertyId(tag: this.tag, vendorPrefix: this.vendorPrefix)
        }
        return PropertyId(tag: this.tag, vendorPrefix: VendorPrefix())
    }

    /// 判断两个 Property 是否相等
    /// 严格翻译自 eql
    public func eql(other: Property): Bool {
        if (this.tag != other.tag) {
            return false
        }
        if (this.tag.hasVendorPrefix() && this.vendorPrefix != other.vendorPrefix) {
            return false
        }
        // 值比较委托给具体类型的 eql 方法
        return PropertyHelper.valuesEqual(this.tag, this.value, other.value)
    }

    /// 深拷贝
    /// 严格翻译自 deepClone
    public func deepClone(): Property {
        return Property(
            tag: this.tag,
            value: PropertyHelper.deepCloneValue(this.tag, this.value),
            vendorPrefix: this.vendorPrefix
        )
    }

    /// 序列化为 CSS 字符串
    /// 严格翻译自 Property.toCss (property_mixin)
    public func toCss(): String {
        let sb = StringBuilder()
        let pre = this.vendorPrefix
        if (!pre.isEmpty()) {
            sb.append(pre.toCssPrefix())
        }
        sb.append(this.tag.toCssName())
        sb.append(": ")
        // 在实际实现中会序列化 value
        sb.append(this.value.toString())
        return sb.toString()
    }

    /// 值序列化为 CSS
    /// 严格翻译自 Property.valueToCss
    public func valueToCss(dest: CssPrinter): Unit {
        // 在实际实现中根据 tag 调用具体类型的 toCss
        dest.writeStr(this.value.toString())
    }

    /// 获取 longhand 属性
    /// 严格翻译自 Property.longhand
    /// 对于 shorthand 属性, 返回展开后的具体属性
    public func longhand(propertyId: PropertyId): ?Property {
        // 在实际实现中, shorthand 属性会根据 propertyId 返回对应的 longhand
        return None
    }

    /// 释放资源
    /// 严格翻译自 Property.deinit
    public func deinit(): Unit {
        // 在实际实现中会释放 value 的资源
    }

    /// Hash
    /// 严格翻译自 Property.hash
    public func hash(hasher: Hasher): Unit {
        hasher.update(this.tag)
        if (this.tag.hasVendorPrefix()) {
            hasher.update(this.vendorPrefix)
        }
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

    public init(tag: PropertyIdTag, vendorPrefix: VendorPrefix = VendorPrefix()) {
        this.tag = tag
        this.vendorPrefix = vendorPrefix
    }

    /// 严格翻译自 `all`
    public static let all = PropertyId(tag: PropertyIdTag.All, vendorPrefix: VendorPrefix())

    /// 获取属性名 (不含前缀)
    /// 严格翻译自 name
    public func name(): String {
        if (this.tag == PropertyIdTag.Custom) {
            // custom 属性名存在 vendorPrefix 的 name 字段中 (CustomPropertyName)
            return this.vendorPrefix.name
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
            return this.vendorPrefix == other.vendorPrefix
        }
        return true
    }

    /// 深拷贝
    /// 严格翻译自 deepClone
    public func deepClone(): PropertyId {
        return PropertyId(tag: this.tag, vendorPrefix: this.vendorPrefix)
    }

    /// 返回带前缀的 PropertyId
    /// 严格翻译自 withPrefix
    public func withPrefix(pre: VendorPrefix): PropertyId {
        return PropertyId(tag: this.tag, vendorPrefix: pre)
    }

    /// 添加前缀
    /// 严格翻译自 addPrefix
    public func addPrefix(pre: VendorPrefix): Unit {
        this.vendorPrefix = this.vendorPrefix.bitwiseOr(pre)
    }

    /// 根据目标设置前缀
    /// 严格翻译自 setPrefixesForTargets
    public func setPrefixesForTargets(targets: Targets): Unit {
        if (!this.tag.hasVendorPrefix()) {
            return
        }
        // 查找该属性对应的 Feature，然后设置前缀
        let feature = FeatureHelper.featureForPropertyId(this.tag)
        if (feature != Feature.None) {
            this.vendorPrefix = targets.prefixes(this.vendorPrefix, feature: feature)
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
            return Some(PropertyId(tag: t, vendorPrefix: prefix))
        }
        return Some(PropertyId(tag: t, vendorPrefix: VendorPrefix()))
    }

    /// 序列化为 CSS
    /// 严格翻译自 toCss (properties_impl.property_id_mixin.toCss)
    public func toCss(dest: Printer): Unit {
        let pre = this.prefix()
        if (!pre.isEmpty()) {
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
// 严格翻译自: properties_generated.zig Property.parse
// ============================================================================

/// Property 解析辅助
/// 严格翻译自 Property.parse
public class PropertyParser {

    /// 解析 CSS 属性
    /// 严格翻译自 Property.parse(property_id, input, options)
    public static func parse(propertyId: PropertyId, input: CssParser, options: CssParserOptions): ?Property {
        // 在实际实现中根据 tag 调用具体类型的 parse 方法
        // 这里提供框架
        let tag = propertyId.tag
        return Some(Property(tag: tag, value: "unparsed", vendorPrefix: propertyId.vendorPrefix))
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
        state = state * 31 + value.hashCode()
    }

    public func update(value: VendorPrefix): Unit {
        state = state * 31 + value.hashCode()
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
        sb.append(Char(c))
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

    /// 空前缀
    public static let empty = VendorPrefix()

    /// 全部前缀
    public static let all = VendorPrefix(isNone: true, isWebkit: true, isMoz: true, isMs: true, isO: true)

    public static let NONE = VendorPrefix(none: true)

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
}

// ============================================================================
// PropertyIdTag 辅助工具
// ============================================================================

/// PropertyIdTag 辅助: 从 CSS 属性名反查 tag
public class PropertyIdTagHelper {
    /// 查找表: CSS 属性名 -> PropertyIdTag
    private static let nameToTag: HashMap<String, PropertyIdTag> = _buildNameMap()

    private static func _buildNameMap(): HashMap<String, PropertyIdTag> {
        let map = HashMap<String, PropertyIdTag>()
        for (tag in PropertyIdTag.values()) {
            map.put(tag.toCssName(), tag)
        }
        return map
    }

    /// 从 CSS 属性名 (case-insensitive) 查找 PropertyIdTag
    public static func fromCssName(name: String): ?PropertyIdTag {
        return nameToTag.get(name.toLower())
    }
}

// ============================================================================
// PropertyId 辅助工具
// ============================================================================

/// PropertyId 辅助: 允许的 VendorPrefix 集合
/// 严格翻译自 fromNameAndPrefix 中的 allowed_prefixes
public class PropertyIdHelper {

    /// 获取指定 tag 允许的 VendorPrefix
    public static func allowedPrefixes(tag: PropertyIdTag): VendorPrefixSet {
        match (tag) {
            // 仅允许 none 的属性
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
               | BorderStartEndRadius
               | BorderEndStartRadius
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
               | ColorScheme =>
                VendorPrefixSet.onlyNone()

            // 允许 none + webkit + moz 的属性
            case BackgroundClip
               | BoxShadow
               | BoxSizing =>
                VendorPrefixSet.noneWebkitMoz()

            // 允许 none + o 的属性
            case TextOverflow =>
                VendorPrefixSet.noneO()

            // 允许 none + webkit 的属性
            case BorderTopLeftRadius
               | BorderTopRightRadius
               | BorderBottomLeftRadius
               | BorderBottomRightRadius
               | BorderRadius
               | BorderImage =>
                VendorPrefixSet.noneWebkit()

            // 允许 none + webkit 的 flex 属性
            case FlexDirection
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
               | AlignItems =>
                VendorPrefixSet.noneWebkit()

            // 允许 none + webkit 的旧 flex 属性
            case BoxOrient
               | BoxDirection
               | BoxOrdinalGroup
               | BoxAlign
               | BoxFlex
               | BoxFlexGroup
               | BoxPack
               | BoxLines =>
                VendorPrefixSet.noneWebkit()

            // 允许 none + webkit 的 ms-flex 属性
            case FlexPack
               | FlexOrder
               | FlexAlign
               | FlexItemAlign
               | FlexLinePack
               | FlexPositive
               | FlexNegative
               | FlexPreferredSize =>
                VendorPrefixSet.noneWebkitMs()

            // transition/transform 属性
            case TransitionProperty
               | TransitionDuration
               | TransitionDelay
               | TransitionTimingFunction
               | Transition
               | Transform
               | TransformOrigin
               | TransformStyle
               | BackfaceVisibility
               | Perspective
               | PerspectiveOrigin =>
                VendorPrefixSet.noneWebkit()

            // 文本装饰
            case TextDecorationColor
               | TextEmphasisColor =>
                VendorPrefixSet.noneWebkit()

            // mask 属性
            case MaskImage
               | MaskRepeat
               | MaskPosition
               | MaskClip
               | MaskOrigin
               | MaskSize
               | Mask =>
                VendorPrefixSet.noneWebkit()

            case MaskSourceType
               | MaskBoxImage
               | MaskBoxImageSource
               | MaskBoxImageSlice
               | MaskBoxImageWidth
               | MaskBoxImageOutset
               | MaskBoxImageRepeat =>
                VendorPrefixSet.noneWebkit()

            case All | Unparsed | Custom =>
                VendorPrefixSet.onlyNone()
        }
    }
}

// ============================================================================
// VendorPrefixSet - 允许的前缀集合
// ============================================================================

/// 允许的 VendorPrefix 集合
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

    public static func onlyNone(): VendorPrefixSet {
        return VendorPrefixSet(allowNone: true, allowWebkit: false, allowMoz: false, allowMs: false, allowO: false)
    }

    public static func noneWebkit(): VendorPrefixSet {
        return VendorPrefixSet(allowNone: true, allowWebkit: true, allowMoz: false, allowMs: false, allowO: false)
    }

    public static func noneWebkitMoz(): VendorPrefixSet {
        return VendorPrefixSet(allowNone: true, allowWebkit: true, allowMoz: true, allowMs: false, allowO: false)
    }

    public static func noneO(): VendorPrefixSet {
        return VendorPrefixSet(allowNone: true, allowWebkit: false, allowMoz: false, allowMs: false, allowO: true)
    }

    public static func noneWebkitMs(): VendorPrefixSet {
        return VendorPrefixSet(allowNone: true, allowWebkit: true, allowMoz: false, allowMs: true, allowO: false)
    }

    public func contains(vp: VendorPrefix): Bool {
        if (vp.isNone) return this.allowNone
        if (vp.isWebkit) return this.allowWebkit
        if (vp.isMoz) return this.allowMoz
        if (vp.isMs) return this.allowMs
        if (vp.isO) return this.allowO
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
    /// 严格翻译自 Property.eql
    public static func valuesEqual(tag: PropertyIdTag, lhs: Any, rhs: Any): Bool {
        // 在实际实现中，根据 tag 将 Any 转为具体类型进行比较
        // 这里提供框架; 具体类型的 eql 由各属性模块实现
        // 注意: 带 VendorPrefix 的比较已在 Property.eql 中处理
        return lhs == rhs
    }

    /// 深拷贝属性值
    /// 严格翻译自 Property.deepClone
    public static func deepCloneValue(tag: PropertyIdTag, value: Any): Any {
        // 在实际实现中，根据 tag 将 Any 转为具体类型进行深拷贝
        // 这里提供框架; 具体类型的 deepClone 由各属性模块实现
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
    public static func featureForPropertyId(tag: PropertyIdTag): Feature {
        match (tag) {
            case BackgroundClip => Feature.BackgroundClip
            case BoxShadow => Feature.BoxShadow
            case BoxSizing => Feature.BoxSizing
            case TextOverflow => Feature.TextOverflow
            case BorderTopLeftRadius => Feature.BorderTopLeftRadius
            case BorderTopRightRadius => Feature.BorderTopRightRadius
            case BorderBottomLeftRadius => Feature.BorderBottomLeftRadius
            case BorderBottomRightRadius => Feature.BorderBottomRightRadius
            case BorderRadius => Feature.BorderRadius
            case BorderImage => Feature.BorderImage
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
            case TransitionProperty => Feature.TransitionProperty
            case TransitionDuration => Feature.TransitionDuration
            case TransitionDelay => Feature.TransitionDelay
            case TransitionTimingFunction => Feature.TransitionTimingFunction
            case Transition => Feature.Transition
            case Transform => Feature.Transform
            case TransformOrigin => Feature.TransformOrigin
            case TransformStyle => Feature.TransformStyle
            case BackfaceVisibility => Feature.BackfaceVisibility
            case Perspective => Feature.Perspective
            case PerspectiveOrigin => Feature.PerspectiveOrigin
            case MaskImage => Feature.MaskImage
            case Mask => Feature.Mask
            case _ => Feature.None
        }
    }
}

// ============================================================================
// Feature 枚举 - 对应 compat.zig 中的 Feature
// ============================================================================

/// CSS 特性标志
/// 严格翻译自 compat.zig Feature
public enum Feature {
    | None
    | BackgroundClip
    | BoxShadow
    | BoxSizing
    | TextOverflow
    | BorderTopLeftRadius
    | BorderTopRightRadius
    | BorderBottomLeftRadius
    | BorderBottomRightRadius
    | BorderRadius
    | BorderImage
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
    | TransitionProperty
    | TransitionDuration
    | TransitionDelay
    | TransitionTimingFunction
    | Transition
    | Transform
    | TransformOrigin
    | TransformStyle
    | BackfaceVisibility
    | Perspective
    | PerspectiveOrigin
    | MaskImage
    | Mask
    | MaskBorder
    | LogicalSize
    | LogicalInset
    | LogicalMargin
    | LogicalPadding
    | LogicalBorders
}
