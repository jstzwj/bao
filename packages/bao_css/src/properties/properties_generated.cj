// 严格翻译自: src/css/properties/properties_generated.zig
// 自动生成的 CSS 属性枚举、Property 联合类型、PropertyId 联合类型
// 包含: PropertyIdTag, Property, PropertyId 及其所有方法

package bao_css.properties

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
            | BackgroundClip => true
            | BoxShadow => true
            | BoxSizing => true
            | TextOverflow => true
            | BorderTopLeftRadius => true
            | BorderTopRightRadius => true
            | BorderBottomLeftRadius => true
            | BorderBottomRightRadius => true
            | BorderRadius => true
            | BorderImage => true
            | FlexDirection => true
            | FlexWrap => true
            | FlexFlow => true
            | FlexGrow => true
            | FlexShrink => true
            | FlexBasis => true
            | Flex => true
            | Order => true
            | AlignContent => true
            | JustifyContent => true
            | AlignSelf => true
            | AlignItems => true
            | BoxOrient => true
            | BoxDirection => true
            | BoxOrdinalGroup => true
            | BoxAlign => true
            | BoxFlex => true
            | BoxFlexGroup => true
            | BoxPack => true
            | BoxLines => true
            | FlexPack => true
            | FlexOrder => true
            | FlexAlign => true
            | FlexItemAlign => true
            | FlexLinePack => true
            | FlexPositive => true
            | FlexNegative => true
            | FlexPreferredSize => true
            | TransitionProperty => true
            | TransitionDuration => true
            | TransitionDelay => true
            | TransitionTimingFunction => true
            | Transition => true
            | Transform => true
            | TransformOrigin => true
            | TransformStyle => true
            | BackfaceVisibility => true
            | Perspective => true
            | PerspectiveOrigin => true
            | TextDecorationColor => true
            | TextEmphasisColor => true
            | MaskImage => true
            | MaskRepeat => true
            | MaskPosition => true
            | MaskClip => true
            | MaskOrigin => true
            | MaskSize => true
            | Mask => true
            | MaskSourceType => true
            | MaskBoxImage => true
            | MaskBoxImageSource => true
            | MaskBoxImageSlice => true
            | MaskBoxImageWidth => true
            | MaskBoxImageOutset => true
            | MaskBoxImageRepeat => true
            | _ => false
        }
    }

    /// 获取 tag 对应的 CSS 属性名
    /// 严格翻译自 toCssName (在 Zig 中通过 @tagName 获取)
    public func toCssName(): String {
        match (this) {
            | BackgroundColor => "background-color"
            | BackgroundImage => "background-image"
            | BackgroundPositionX => "background-position-x"
            | BackgroundPositionY => "background-position-y"
            | BackgroundPosition => "background-position"
            | BackgroundSize => "background-size"
            | BackgroundRepeat => "background-repeat"
            | BackgroundAttachment => "background-attachment"
            | BackgroundClip => "background-clip"
            | BackgroundOrigin => "background-origin"
            | Background => "background"
            | BoxShadow => "box-shadow"
            | Opacity => "opacity"
            | Color => "color"
            | Display => "display"
            | Visibility => "visibility"
            | Width => "width"
            | Height => "height"
            | MinWidth => "min-width"
            | MinHeight => "min-height"
            | MaxWidth => "max-width"
            | MaxHeight => "max-height"
            | BlockSize => "block-size"
            | InlineSize => "inline-size"
            | MinBlockSize => "min-block-size"
            | MinInlineSize => "min-inline-size"
            | MaxBlockSize => "max-block-size"
            | MaxInlineSize => "max-inline-size"
            | BoxSizing => "box-sizing"
            | AspectRatio => "aspect-ratio"
            | Overflow => "overflow"
            | OverflowX => "overflow-x"
            | OverflowY => "overflow-y"
            | TextOverflow => "text-overflow"
            | Position => "position"
            | Top => "top"
            | Bottom => "bottom"
            | Left => "left"
            | Right => "right"
            | InsetBlockStart => "inset-block-start"
            | InsetBlockEnd => "inset-block-end"
            | InsetInlineStart => "inset-inline-start"
            | InsetInlineEnd => "inset-inline-end"
            | InsetBlock => "inset-block"
            | InsetInline => "inset-inline"
            | Inset => "inset"
            | BorderSpacing => "border-spacing"
            | BorderTopColor => "border-top-color"
            | BorderBottomColor => "border-bottom-color"
            | BorderLeftColor => "border-left-color"
            | BorderRightColor => "border-right-color"
            | BorderBlockStartColor => "border-block-start-color"
            | BorderBlockEndColor => "border-block-end-color"
            | BorderInlineStartColor => "border-inline-start-color"
            | BorderInlineEndColor => "border-inline-end-color"
            | BorderTopStyle => "border-top-style"
            | BorderBottomStyle => "border-bottom-style"
            | BorderLeftStyle => "border-left-style"
            | BorderRightStyle => "border-right-style"
            | BorderBlockStartStyle => "border-block-start-style"
            | BorderBlockEndStyle => "border-block-end-style"
            | BorderInlineStartStyle => "border-inline-start-style"
            | BorderInlineEndStyle => "border-inline-end-style"
            | BorderTopWidth => "border-top-width"
            | BorderBottomWidth => "border-bottom-width"
            | BorderLeftWidth => "border-left-width"
            | BorderRightWidth => "border-right-width"
            | BorderBlockStartWidth => "border-block-start-width"
            | BorderBlockEndWidth => "border-block-end-width"
            | BorderInlineStartWidth => "border-inline-start-width"
            | BorderInlineEndWidth => "border-inline-end-width"
            | BorderTopLeftRadius => "border-top-left-radius"
            | BorderTopRightRadius => "border-top-right-radius"
            | BorderBottomLeftRadius => "border-bottom-left-radius"
            | BorderBottomRightRadius => "border-bottom-right-radius"
            | BorderStartStartRadius => "border-start-start-radius"
            | BorderStartEndRadius => "border-start-end-radius"
            | BorderEndStartRadius => "border-end-start-radius"
            | BorderEndEndRadius => "border-end-end-radius"
            | BorderRadius => "border-radius"
            | BorderImageSource => "border-image-source"
            | BorderImageOutset => "border-image-outset"
            | BorderImageRepeat => "border-image-repeat"
            | BorderImageWidth => "border-image-width"
            | BorderImageSlice => "border-image-slice"
            | BorderImage => "border-image"
            | BorderColor => "border-color"
            | BorderStyle => "border-style"
            | BorderWidth => "border-width"
            | BorderBlockColor => "border-block-color"
            | BorderBlockStyle => "border-block-style"
            | BorderBlockWidth => "border-block-width"
            | BorderInlineColor => "border-inline-color"
            | BorderInlineStyle => "border-inline-style"
            | BorderInlineWidth => "border-inline-width"
            | Border => "border"
            | BorderTop => "border-top"
            | BorderBottom => "border-bottom"
            | BorderLeft => "border-left"
            | BorderRight => "border-right"
            | BorderBlock => "border-block"
            | BorderBlockStart => "border-block-start"
            | BorderBlockEnd => "border-block-end"
            | BorderInline => "border-inline"
            | BorderInlineStart => "border-inline-start"
            | BorderInlineEnd => "border-inline-end"
            | Outline => "outline"
            | OutlineColor => "outline-color"
            | OutlineStyle => "outline-style"
            | OutlineWidth => "outline-width"
            | FlexDirection => "flex-direction"
            | FlexWrap => "flex-wrap"
            | FlexFlow => "flex-flow"
            | FlexGrow => "flex-grow"
            | FlexShrink => "flex-shrink"
            | FlexBasis => "flex-basis"
            | Flex => "flex"
            | Order => "order"
            | AlignContent => "align-content"
            | JustifyContent => "justify-content"
            | PlaceContent => "place-content"
            | AlignSelf => "align-self"
            | JustifySelf => "justify-self"
            | PlaceSelf => "place-self"
            | AlignItems => "align-items"
            | JustifyItems => "justify-items"
            | PlaceItems => "place-items"
            | RowGap => "row-gap"
            | ColumnGap => "column-gap"
            | Gap => "gap"
            | BoxOrient => "box-orient"
            | BoxDirection => "box-direction"
            | BoxOrdinalGroup => "box-ordinal-group"
            | BoxAlign => "box-align"
            | BoxFlex => "box-flex"
            | BoxFlexGroup => "box-flex-group"
            | BoxPack => "box-pack"
            | BoxLines => "box-lines"
            | FlexPack => "flex-pack"
            | FlexOrder => "flex-order"
            | FlexAlign => "flex-align"
            | FlexItemAlign => "flex-item-align"
            | FlexLinePack => "flex-line-pack"
            | FlexPositive => "flex-positive"
            | FlexNegative => "flex-negative"
            | FlexPreferredSize => "flex-preferred-size"
            | MarginTop => "margin-top"
            | MarginBottom => "margin-bottom"
            | MarginLeft => "margin-left"
            | MarginRight => "margin-right"
            | MarginBlockStart => "margin-block-start"
            | MarginBlockEnd => "margin-block-end"
            | MarginInlineStart => "margin-inline-start"
            | MarginInlineEnd => "margin-inline-end"
            | MarginBlock => "margin-block"
            | MarginInline => "margin-inline"
            | Margin => "margin"
            | PaddingTop => "padding-top"
            | PaddingBottom => "padding-bottom"
            | PaddingLeft => "padding-left"
            | PaddingRight => "padding-right"
            | PaddingBlockStart => "padding-block-start"
            | PaddingBlockEnd => "padding-block-end"
            | PaddingInlineStart => "padding-inline-start"
            | PaddingInlineEnd => "padding-inline-end"
            | PaddingBlock => "padding-block"
            | PaddingInline => "padding-inline"
            | Padding => "padding"
            | ScrollMarginTop => "scroll-margin-top"
            | ScrollMarginBottom => "scroll-margin-bottom"
            | ScrollMarginLeft => "scroll-margin-left"
            | ScrollMarginRight => "scroll-margin-right"
            | ScrollMarginBlockStart => "scroll-margin-block-start"
            | ScrollMarginBlockEnd => "scroll-margin-block-end"
            | ScrollMarginInlineStart => "scroll-margin-inline-start"
            | ScrollMarginInlineEnd => "scroll-margin-inline-end"
            | ScrollMarginBlock => "scroll-margin-block"
            | ScrollMarginInline => "scroll-margin-inline"
            | ScrollMargin => "scroll-margin"
            | ScrollPaddingTop => "scroll-padding-top"
            | ScrollPaddingBottom => "scroll-padding-bottom"
            | ScrollPaddingLeft => "scroll-padding-left"
            | ScrollPaddingRight => "scroll-padding-right"
            | ScrollPaddingBlockStart => "scroll-padding-block-start"
            | ScrollPaddingBlockEnd => "scroll-padding-block-end"
            | ScrollPaddingInlineStart => "scroll-padding-inline-start"
            | ScrollPaddingInlineEnd => "scroll-padding-inline-end"
            | ScrollPaddingBlock => "scroll-padding-block"
            | ScrollPaddingInline => "scroll-padding-inline"
            | ScrollPadding => "scroll-padding"
            | FontWeight => "font-weight"
            | FontSize => "font-size"
            | FontStretch => "font-stretch"
            | FontFamily => "font-family"
            | FontStyle => "font-style"
            | FontVariantCaps => "font-variant-caps"
            | LineHeight => "line-height"
            | Font => "font"
            | TransitionProperty => "transition-property"
            | TransitionDuration => "transition-duration"
            | TransitionDelay => "transition-delay"
            | TransitionTimingFunction => "transition-timing-function"
            | Transition => "transition"
            | Transform => "transform"
            | TransformOrigin => "transform-origin"
            | TransformStyle => "transform-style"
            | TransformBox => "transform-box"
            | BackfaceVisibility => "backface-visibility"
            | Perspective => "perspective"
            | PerspectiveOrigin => "perspective-origin"
            | Translate => "translate"
            | Rotate => "rotate"
            | Scale => "scale"
            | TextDecorationColor => "text-decoration-color"
            | TextEmphasisColor => "text-emphasis-color"
            | TextShadow => "text-shadow"
            | Direction => "direction"
            | Composes => "composes"
            | MaskImage => "mask-image"
            | MaskMode => "mask-mode"
            | MaskRepeat => "mask-repeat"
            | MaskPositionX => "mask-position-x"
            | MaskPositionY => "mask-position-y"
            | MaskPosition => "mask-position"
            | MaskClip => "mask-clip"
            | MaskOrigin => "mask-origin"
            | MaskSize => "mask-size"
            | MaskComposite => "mask-composite"
            | MaskType => "mask-type"
            | Mask => "mask"
            | MaskBorderSource => "mask-border-source"
            | MaskBorderMode => "mask-border-mode"
            | MaskBorderSlice => "mask-border-slice"
            | MaskBorderWidth => "mask-border-width"
            | MaskBorderOutset => "mask-border-outset"
            | MaskBorderRepeat => "mask-border-repeat"
            | MaskBorder => "mask-border"
            | WebKitMaskComposite => "-webkit-mask-composite"
            | MaskSourceType => "-webkit-mask-source-type"
            | MaskBoxImage => "-webkit-mask-box-image"
            | MaskBoxImageSource => "-webkit-mask-box-image-source"
            | MaskBoxImageSlice => "-webkit-mask-box-image-slice"
            | MaskBoxImageWidth => "-webkit-mask-box-image-width"
            | MaskBoxImageOutset => "-webkit-mask-box-image-outset"
            | MaskBoxImageRepeat => "-webkit-mask-box-image-repeat"
            | ColorScheme => "color-scheme"
            | All => "all"
            | Unparsed => "unparsed"
            | Custom => "custom"
        }
    }

    /// 严格翻译自 valueType - 返回属性的值类型名称
    /// 在仓颉中用字符串表示类型名 (因为仓颉不支持 comptime type)
    public func valueTypeName(): String {
        match (this) {
            | BackgroundColor => "CssColor"
            | BackgroundImage => "SmallList<Image>"
            | BackgroundPositionX => "SmallList<HorizontalPosition>"
            | BackgroundPositionY => "SmallList<VerticalPosition>"
            | BackgroundPosition => "SmallList<BackgroundPosition>"
            | BackgroundSize => "SmallList<BackgroundSize>"
            | BackgroundRepeat => "SmallList<BackgroundRepeat>"
            | BackgroundAttachment => "SmallList<BackgroundAttachment>"
            | BackgroundClip => "SmallList<BackgroundClip>"
            | BackgroundOrigin => "SmallList<BackgroundOrigin>"
            | Background => "SmallList<Background>"
            | BoxShadow => "SmallList<BoxShadow>"
            | Opacity => "AlphaValue"
            | Color => "CssColor"
            | Display => "Display"
            | Visibility => "Visibility"
            | Width => "Size"
            | Height => "Size"
            | MinWidth => "Size"
            | MinHeight => "Size"
            | MaxWidth => "MaxSize"
            | MaxHeight => "MaxSize"
            | BlockSize => "Size"
            | InlineSize => "Size"
            | MinBlockSize => "Size"
            | MinInlineSize => "Size"
            | MaxBlockSize => "MaxSize"
            | MaxInlineSize => "MaxSize"
            | BoxSizing => "BoxSizing"
            | AspectRatio => "AspectRatio"
            | Overflow => "Overflow"
            | OverflowX => "OverflowKeyword"
            | OverflowY => "OverflowKeyword"
            | TextOverflow => "TextOverflow"
            | Position => "Position"
            | Top => "LengthPercentageOrAuto"
            | Bottom => "LengthPercentageOrAuto"
            | Left => "LengthPercentageOrAuto"
            | Right => "LengthPercentageOrAuto"
            | InsetBlockStart => "LengthPercentageOrAuto"
            | InsetBlockEnd => "LengthPercentageOrAuto"
            | InsetInlineStart => "LengthPercentageOrAuto"
            | InsetInlineEnd => "LengthPercentageOrAuto"
            | InsetBlock => "InsetBlock"
            | InsetInline => "InsetInline"
            | Inset => "Inset"
            | BorderSpacing => "Size2D<Length>"
            | BorderTopColor => "CssColor"
            | BorderBottomColor => "CssColor"
            | BorderLeftColor => "CssColor"
            | BorderRightColor => "CssColor"
            | BorderBlockStartColor => "CssColor"
            | BorderBlockEndColor => "CssColor"
            | BorderInlineStartColor => "CssColor"
            | BorderInlineEndColor => "CssColor"
            | BorderTopStyle => "LineStyle"
            | BorderBottomStyle => "LineStyle"
            | BorderLeftStyle => "LineStyle"
            | BorderRightStyle => "LineStyle"
            | BorderBlockStartStyle => "LineStyle"
            | BorderBlockEndStyle => "LineStyle"
            | BorderInlineStartStyle => "LineStyle"
            | BorderInlineEndStyle => "LineStyle"
            | BorderTopWidth => "BorderSideWidth"
            | BorderBottomWidth => "BorderSideWidth"
            | BorderLeftWidth => "BorderSideWidth"
            | BorderRightWidth => "BorderSideWidth"
            | BorderBlockStartWidth => "BorderSideWidth"
            | BorderBlockEndWidth => "BorderSideWidth"
            | BorderInlineStartWidth => "BorderSideWidth"
            | BorderInlineEndWidth => "BorderSideWidth"
            | BorderTopLeftRadius => "Size2D<LengthPercentage>"
            | BorderTopRightRadius => "Size2D<LengthPercentage>"
            | BorderBottomLeftRadius => "Size2D<LengthPercentage>"
            | BorderBottomRightRadius => "Size2D<LengthPercentage>"
            | BorderStartStartRadius => "Size2D<LengthPercentage>"
            | BorderStartEndRadius => "Size2D<LengthPercentage>"
            | BorderEndStartRadius => "Size2D<LengthPercentage>"
            | BorderEndEndRadius => "Size2D<LengthPercentage>"
            | BorderRadius => "BorderRadius"
            | BorderImageSource => "Image"
            | BorderImageOutset => "Rect<LengthOrNumber>"
            | BorderImageRepeat => "BorderImageRepeat"
            | BorderImageWidth => "Rect<BorderImageSideWidth>"
            | BorderImageSlice => "BorderImageSlice"
            | BorderImage => "BorderImage"
            | BorderColor => "BorderColor"
            | BorderStyle => "BorderStyle"
            | BorderWidth => "BorderWidth"
            | BorderBlockColor => "BorderBlockColor"
            | BorderBlockStyle => "BorderBlockStyle"
            | BorderBlockWidth => "BorderBlockWidth"
            | BorderInlineColor => "BorderInlineColor"
            | BorderInlineStyle => "BorderInlineStyle"
            | BorderInlineWidth => "BorderInlineWidth"
            | Border => "Border"
            | BorderTop => "BorderTop"
            | BorderBottom => "BorderBottom"
            | BorderLeft => "BorderLeft"
            | BorderRight => "BorderRight"
            | BorderBlock => "BorderBlock"
            | BorderBlockStart => "BorderBlockStart"
            | BorderBlockEnd => "BorderBlockEnd"
            | BorderInline => "BorderInline"
            | BorderInlineStart => "BorderInlineStart"
            | BorderInlineEnd => "BorderInlineEnd"
            | Outline => "Outline"
            | OutlineColor => "CssColor"
            | OutlineStyle => "OutlineStyle"
            | OutlineWidth => "BorderSideWidth"
            | FlexDirection => "FlexDirection"
            | FlexWrap => "FlexWrap"
            | FlexFlow => "FlexFlow"
            | FlexGrow => "CSSNumber"
            | FlexShrink => "CSSNumber"
            | FlexBasis => "LengthPercentageOrAuto"
            | Flex => "Flex"
            | Order => "CSSInteger"
            | AlignContent => "AlignContent"
            | JustifyContent => "JustifyContent"
            | PlaceContent => "PlaceContent"
            | AlignSelf => "AlignSelf"
            | JustifySelf => "JustifySelf"
            | PlaceSelf => "PlaceSelf"
            | AlignItems => "AlignItems"
            | JustifyItems => "JustifyItems"
            | PlaceItems => "PlaceItems"
            | RowGap => "GapValue"
            | ColumnGap => "GapValue"
            | Gap => "Gap"
            | BoxOrient => "BoxOrient"
            | BoxDirection => "BoxDirection"
            | BoxOrdinalGroup => "CSSInteger"
            | BoxAlign => "BoxAlign"
            | BoxFlex => "CSSNumber"
            | BoxFlexGroup => "CSSInteger"
            | BoxPack => "BoxPack"
            | BoxLines => "BoxLines"
            | FlexPack => "FlexPack"
            | FlexOrder => "CSSInteger"
            | FlexAlign => "BoxAlign"
            | FlexItemAlign => "FlexItemAlign"
            | FlexLinePack => "FlexLinePack"
            | FlexPositive => "CSSNumber"
            | FlexNegative => "CSSNumber"
            | FlexPreferredSize => "LengthPercentageOrAuto"
            | MarginTop => "LengthPercentageOrAuto"
            | MarginBottom => "LengthPercentageOrAuto"
            | MarginLeft => "LengthPercentageOrAuto"
            | MarginRight => "LengthPercentageOrAuto"
            | MarginBlockStart => "LengthPercentageOrAuto"
            | MarginBlockEnd => "LengthPercentageOrAuto"
            | MarginInlineStart => "LengthPercentageOrAuto"
            | MarginInlineEnd => "LengthPercentageOrAuto"
            | MarginBlock => "MarginBlock"
            | MarginInline => "MarginInline"
            | Margin => "Margin"
            | PaddingTop => "LengthPercentageOrAuto"
            | PaddingBottom => "LengthPercentageOrAuto"
            | PaddingLeft => "LengthPercentageOrAuto"
            | PaddingRight => "LengthPercentageOrAuto"
            | PaddingBlockStart => "LengthPercentageOrAuto"
            | PaddingBlockEnd => "LengthPercentageOrAuto"
            | PaddingInlineStart => "LengthPercentageOrAuto"
            | PaddingInlineEnd => "LengthPercentageOrAuto"
            | PaddingBlock => "PaddingBlock"
            | PaddingInline => "PaddingInline"
            | Padding => "Padding"
            | ScrollMarginTop => "LengthPercentageOrAuto"
            | ScrollMarginBottom => "LengthPercentageOrAuto"
            | ScrollMarginLeft => "LengthPercentageOrAuto"
            | ScrollMarginRight => "LengthPercentageOrAuto"
            | ScrollMarginBlockStart => "LengthPercentageOrAuto"
            | ScrollMarginBlockEnd => "LengthPercentageOrAuto"
            | ScrollMarginInlineStart => "LengthPercentageOrAuto"
            | ScrollMarginInlineEnd => "LengthPercentageOrAuto"
            | ScrollMarginBlock => "ScrollMarginBlock"
            | ScrollMarginInline => "ScrollMarginInline"
            | ScrollMargin => "ScrollMargin"
            | ScrollPaddingTop => "LengthPercentageOrAuto"
            | ScrollPaddingBottom => "LengthPercentageOrAuto"
            | ScrollPaddingLeft => "LengthPercentageOrAuto"
            | ScrollPaddingRight => "LengthPercentageOrAuto"
            | ScrollPaddingBlockStart => "LengthPercentageOrAuto"
            | ScrollPaddingBlockEnd => "LengthPercentageOrAuto"
            | ScrollPaddingInlineStart => "LengthPercentageOrAuto"
            | ScrollPaddingInlineEnd => "LengthPercentageOrAuto"
            | ScrollPaddingBlock => "ScrollPaddingBlock"
            | ScrollPaddingInline => "ScrollPaddingInline"
            | ScrollPadding => "ScrollPadding"
            | FontWeight => "FontWeight"
            | FontSize => "FontSize"
            | FontStretch => "FontStretch"
            | FontFamily => "BabyList<FontFamily>"
            | FontStyle => "FontStyle"
            | FontVariantCaps => "FontVariantCaps"
            | LineHeight => "LineHeight"
            | Font => "Font"
            | TransitionProperty => "SmallList<PropertyId>"
            | TransitionDuration => "SmallList<Time>"
            | TransitionDelay => "SmallList<Time>"
            | TransitionTimingFunction => "SmallList<EasingFunction>"
            | Transition => "SmallList<Transition>"
            | Transform => "TransformList"
            | TransformOrigin => "Position"
            | TransformStyle => "TransformStyle"
            | TransformBox => "TransformBox"
            | BackfaceVisibility => "BackfaceVisibility"
            | Perspective => "Perspective"
            | PerspectiveOrigin => "Position"
            | Translate => "Translate"
            | Rotate => "Rotate"
            | Scale => "Scale"
            | TextDecorationColor => "CssColor"
            | TextEmphasisColor => "CssColor"
            | TextShadow => "SmallList<TextShadow>"
            | Direction => "Direction"
            | Composes => "Composes"
            | MaskImage => "SmallList<Image>"
            | MaskMode => "SmallList<MaskMode>"
            | MaskRepeat => "SmallList<BackgroundRepeat>"
            | MaskPositionX => "SmallList<HorizontalPosition>"
            | MaskPositionY => "SmallList<VerticalPosition>"
            | MaskPosition => "SmallList<Position>"
            | MaskClip => "SmallList<MaskClip>"
            | MaskOrigin => "SmallList<GeometryBox>"
            | MaskSize => "SmallList<BackgroundSize>"
            | MaskComposite => "SmallList<MaskComposite>"
            | MaskType => "MaskType"
            | Mask => "SmallList<Mask>"
            | MaskBorderSource => "Image"
            | MaskBorderMode => "MaskBorderMode"
            | MaskBorderSlice => "BorderImageSlice"
            | MaskBorderWidth => "Rect<BorderImageSideWidth>"
            | MaskBorderOutset => "Rect<LengthOrNumber>"
            | MaskBorderRepeat => "BorderImageRepeat"
            | MaskBorder => "MaskBorder"
            | WebKitMaskComposite => "SmallList<WebKitMaskComposite>"
            | MaskSourceType => "SmallList<WebKitMaskSourceType>"
            | MaskBoxImage => "BorderImage"
            | MaskBoxImageSource => "Image"
            | MaskBoxImageSlice => "BorderImageSlice"
            | MaskBoxImageWidth => "Rect<BorderImageSideWidth>"
            | MaskBoxImageOutset => "Rect<LengthOrNumber>"
            | MaskBoxImageRepeat => "BorderImageRepeat"
            | ColorScheme => "ColorScheme"
            | All => "CSSWideKeyword"
            | Unparsed => "UnparsedProperty"
            | Custom => "CustomProperty"
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
            | BackgroundColor
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
            | BackgroundClip
               | BoxShadow
               | BoxSizing =>
                VendorPrefixSet.noneWebkitMoz()

            // 允许 none + o 的属性
            | TextOverflow =>
                VendorPrefixSet.noneO()

            // 允许 none + webkit 的属性
            | BorderTopLeftRadius
               | BorderTopRightRadius
               | BorderBottomLeftRadius
               | BorderBottomRightRadius
               | BorderRadius
               | BorderImage =>
                VendorPrefixSet.noneWebkit()

            // 允许 none + webkit 的 flex 属性
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
               | AlignItems =>
                VendorPrefixSet.noneWebkit()

            // 允许 none + webkit 的旧 flex 属性
            | BoxOrient
               | BoxDirection
               | BoxOrdinalGroup
               | BoxAlign
               | BoxFlex
               | BoxFlexGroup
               | BoxPack
               | BoxLines =>
                VendorPrefixSet.noneWebkit()

            // 允许 none + webkit 的 ms-flex 属性
            | FlexPack
               | FlexOrder
               | FlexAlign
               | FlexItemAlign
               | FlexLinePack
               | FlexPositive
               | FlexNegative
               | FlexPreferredSize =>
                VendorPrefixSet.noneWebkitMs()

            // transition/transform 属性
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
               | PerspectiveOrigin =>
                VendorPrefixSet.noneWebkit()

            // 文本装饰
            | TextDecorationColor
               | TextEmphasisColor =>
                VendorPrefixSet.noneWebkit()

            // mask 属性
            | MaskImage
               | MaskRepeat
               | MaskPosition
               | MaskClip
               | MaskOrigin
               | MaskSize
               | Mask =>
                VendorPrefixSet.noneWebkit()

            | MaskSourceType
               | MaskBoxImage
               | MaskBoxImageSource
               | MaskBoxImageSlice
               | MaskBoxImageWidth
               | MaskBoxImageOutset
               | MaskBoxImageRepeat =>
                VendorPrefixSet.noneWebkit()

            | All | Unparsed | Custom =>
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
            | BackgroundClip => Feature.BackgroundClip
            | BoxShadow => Feature.BoxShadow
            | BoxSizing => Feature.BoxSizing
            | TextOverflow => Feature.TextOverflow
            | BorderTopLeftRadius => Feature.BorderTopLeftRadius
            | BorderTopRightRadius => Feature.BorderTopRightRadius
            | BorderBottomLeftRadius => Feature.BorderBottomLeftRadius
            | BorderBottomRightRadius => Feature.BorderBottomRightRadius
            | BorderRadius => Feature.BorderRadius
            | BorderImage => Feature.BorderImage
            | FlexDirection => Feature.FlexDirection
            | FlexWrap => Feature.FlexWrap
            | FlexFlow => Feature.FlexFlow
            | FlexGrow => Feature.FlexGrow
            | FlexShrink => Feature.FlexShrink
            | FlexBasis => Feature.FlexBasis
            | Flex => Feature.Flex
            | Order => Feature.Order
            | AlignContent => Feature.AlignContent
            | JustifyContent => Feature.JustifyContent
            | AlignSelf => Feature.AlignSelf
            | AlignItems => Feature.AlignItems
            | TransitionProperty => Feature.TransitionProperty
            | TransitionDuration => Feature.TransitionDuration
            | TransitionDelay => Feature.TransitionDelay
            | TransitionTimingFunction => Feature.TransitionTimingFunction
            | Transition => Feature.Transition
            | Transform => Feature.Transform
            | TransformOrigin => Feature.TransformOrigin
            | TransformStyle => Feature.TransformStyle
            | BackfaceVisibility => Feature.BackfaceVisibility
            | Perspective => Feature.Perspective
            | PerspectiveOrigin => Feature.PerspectiveOrigin
            | MaskImage => Feature.MaskImage
            | Mask => Feature.Mask
            | _ => Feature.None
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
