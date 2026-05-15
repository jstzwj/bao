// bao_css - CSS Properties: Properties Generated
// 严格翻译自: bun/src/css/properties/properties_generated.rs
//   对应: properties_generated.zig - 自动生成的 CSS 属性枚举
//   对应: PropertyIdTag (所有 CSS 属性的判别标签)
//   对应: Property (所有 CSS 属性值的联合类型)
//   对应: PropertyId (属性标识符，带供应商前缀)
// ============================================================================

package bao.css

import bao_core.*

// ============================================================================
// PropertyIdTag
// 严格翻译自 PropertyIdTag (enum(u16))
// ============================================================================

/// CSS 属性判别标签
/// 严格翻译自 PropertyIdTag
///
/// 这是一个枚举类型，每个变体对应一个 CSS 属性。
/// 用于 Property 和 PropertyId 的判别。
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
    | BorderColor
    | BorderBlockColor
    | BorderBlockStartColor
    | BorderBlockEndColor
    | BorderInlineColor
    | BorderInlineStartColor
    | BorderInlineEndColor
    | BorderTopStyle
    | BorderBottomStyle
    | BorderLeftStyle
    | BorderRightStyle
    | BorderStyle
    | BorderBlockStyle
    | BorderBlockStartStyle
    | BorderBlockEndStyle
    | BorderInlineStyle
    | BorderInlineStartStyle
    | BorderInlineEndStyle
    | BorderTopWidth
    | BorderBottomWidth
    | BorderLeftWidth
    | BorderRightWidth
    | BorderWidth
    | BorderBlockWidth
    | BorderBlockStartWidth
    | BorderBlockEndWidth
    | BorderInlineWidth
    | BorderInlineStartWidth
    | BorderInlineEndWidth
    | Border
    | BorderBlock
    | BorderBlockStart
    | BorderBlockEnd
    | BorderInline
    | BorderInlineStart
    | BorderInlineEnd
    | BorderRadius
    | BorderTopLeftRadius
    | BorderTopRightRadius
    | BorderBottomLeftRadius
    | BorderBottomRightRadius
    | BorderImage
    | BorderImageSource
    | BorderImageSlice
    | BorderImageWidth
    | BorderImageOutset
    | BorderImageRepeat
    | Outline
    | OutlineColor
    | OutlineStyle
    | OutlineWidth
    | OutlineOffset

    // 外边距 & 内边距
    | MarginTop
    | MarginBottom
    | MarginLeft
    | MarginRight
    | Margin
    | MarginBlockStart
    | MarginBlockEnd
    | MarginBlock
    | MarginInlineStart
    | MarginInlineEnd
    | MarginInline
    | PaddingTop
    | PaddingBottom
    | PaddingLeft
    | PaddingRight
    | Padding
    | PaddingBlockStart
    | PaddingBlockEnd
    | PaddingBlock
    | PaddingInlineStart
    | PaddingInlineEnd
    | PaddingInline
    | ScrollMarginTop
    | ScrollMarginBottom
    | ScrollMarginLeft
    | ScrollMarginRight
    | ScrollMargin
    | ScrollMarginBlockStart
    | ScrollMarginBlockEnd
    | ScrollMarginBlock
    | ScrollMarginInlineStart
    | ScrollMarginInlineEnd
    | ScrollMarginInline
    | ScrollPaddingTop
    | ScrollPaddingBottom
    | ScrollPaddingLeft
    | ScrollPaddingRight
    | ScrollPadding
    | ScrollPaddingBlockStart
    | ScrollPaddingBlockEnd
    | ScrollPaddingBlock
    | ScrollPaddingInlineStart
    | ScrollPaddingInlineEnd
    | ScrollPaddingInline

    // 文本
    | TextTransform
    | TextDecoration
    | TextDecorationLine
    | TextDecorationColor
    | TextDecorationStyle
    | TextDecorationThickness
    | TextShadow
    | TextSizeAdjust
    | TextIndent
    | TextAlign
    | TextAlignLast
    | TextJustify
    | WordSpacing
    | LetterSpacing
    | WhiteSpace
    | WordBreak
    | LineBreak
    | Hyphens
    | OverflowWrap
    | Direction
    | UnicodeBidi
    | BoxDecorationBreak

    // 字体
    | FontFamily
    | FontWeight
    | FontSize
    | FontStretch
    | FontStyle
    | FontVariantCaps
    | LineHeight
    | Font
    | VerticalAlign

    // Flex
    | FlexDirection
    | FlexWrap
    | FlexFlow
    | FlexGrow
    | FlexShrink
    | FlexBasis
    | Flex
    | JustifyContent
    | AlignItems
    | AlignSelf
    | AlignContent
    | JustifyItems
    | JustifySelf
    | Order
    | Gap
    | RowGap
    | ColumnGap
    | PlaceContent
    | PlaceItems
    | PlaceSelf

    // Grid
    | GridTemplateColumns
    | GridTemplateRows
    | GridTemplateAreas
    | GridAutoColumns
    | GridAutoRows
    | GridAutoFlow
    | GridColumnStart
    | GridColumnEnd
    | GridRowStart
    | GridRowEnd
    | GridColumn
    | GridRow
    | GridArea

    // 变换 & 过渡
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
    | Transition
    | TransitionProperty
    | TransitionDuration
    | TransitionDelay
    | TransitionTimingFunction

    // 动画
    | Animation
    | AnimationName
    | AnimationDuration
    | AnimationTimingFunction
    | AnimationDelay
    | AnimationIterationCount
    | AnimationDirection
    | AnimationFillMode
    | AnimationPlayState
    | AnimationComposition
    | AnimationTimeline
    | AnimationRange

    // 滤镜 & 效果
    | Filter
    | BackdropFilter
    | BoxShadow  // 重复已移除

    // 遮罩
    | MaskImage
    | MaskPosition
    | MaskSize
    | MaskRepeat
    | MaskClip
    | MaskOrigin
    | MaskComposite
    | MaskMode
    | Mask
    | MaskBorder
    | MaskBorderSource
    | MaskBorderSlice
    | MaskBorderWidth
    | MaskBorderOutset
    | MaskBorderRepeat
    | MaskBorderMode
    | MaskType
    | WebKitMaskComposite
    | MaskSourceType
    | MaskBoxImageSource
    | MaskBoxImageSlice
    | MaskBoxImageWidth
    | MaskBoxImageOutset
    | MaskBoxImageRepeat
    | MaskBoxImage
    | ClipPath

    // UI
    | ColorScheme
    | Cursor
    | CaretColor
    | CaretShape
    | Caret
    | UserSelect
    | Appearance
    | Resize

    // SVG
    | Fill
    | Stroke
    | StrokeWidth
    | StrokeLinecap
    | StrokeLinejoin
    | StrokeDasharray
    | StrokeDashoffset
    | StrokeMiterlimit
    | MarkerStart
    | MarkerMid
    | MarkerEnd
    | Marker
    | ColorInterpolation
    | ColorRendering
    | ShapeRendering
    | TextRendering
    | ImageRendering

    // 容器
    | ContainerType
    | ContainerName
    | Container

    // 列表
    | ListStyleType
    | ListStylePosition
    | ListStyleImage
    | ListStyle
    | MarkerSide
    | CounterIncrement
    | CounterReset
    | CounterSet

    // 自定义 / 未解析
    | Unparsed
    | Custom

    /// 获取属性的 CSS 名称
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
            case Inset => "inset"
            case InsetBlock => "inset-block"
            case InsetInline => "inset-inline"
            case InsetBlockStart => "inset-block-start"
            case InsetBlockEnd => "inset-block-end"
            case InsetInlineStart => "inset-inline-start"
            case InsetInlineEnd => "inset-inline-end"
            case Margin => "margin"
            case MarginTop => "margin-top"
            case MarginBottom => "margin-bottom"
            case MarginLeft => "margin-left"
            case MarginRight => "margin-right"
            case MarginBlock => "margin-block"
            case MarginBlockStart => "margin-block-start"
            case MarginBlockEnd => "margin-block-end"
            case MarginInline => "margin-inline"
            case MarginInlineStart => "margin-inline-start"
            case MarginInlineEnd => "margin-inline-end"
            case Padding => "padding"
            case PaddingTop => "padding-top"
            case PaddingBottom => "padding-bottom"
            case PaddingLeft => "padding-left"
            case PaddingRight => "padding-right"
            case PaddingBlock => "padding-block"
            case PaddingBlockStart => "padding-block-start"
            case PaddingBlockEnd => "padding-block-end"
            case PaddingInline => "padding-inline"
            case PaddingInlineStart => "padding-inline-start"
            case PaddingInlineEnd => "padding-inline-end"
            case Border => "border"
            case BorderTop => "border-top"
            case BorderBottom => "border-bottom"
            case BorderLeft => "border-left"
            case BorderRight => "border-right"
            case BorderColor => "border-color"
            case BorderTopColor => "border-top-color"
            case BorderBottomColor => "border-bottom-color"
            case BorderLeftColor => "border-left-color"
            case BorderRightColor => "border-right-color"
            case BorderStyle => "border-style"
            case BorderTopStyle => "border-top-style"
            case BorderBottomStyle => "border-bottom-style"
            case BorderLeftStyle => "border-left-style"
            case BorderRightStyle => "border-right-style"
            case BorderWidth => "border-width"
            case BorderTopWidth => "border-top-width"
            case BorderBottomWidth => "border-bottom-width"
            case BorderLeftWidth => "border-left-width"
            case BorderRightWidth => "border-right-width"
            case BorderRadius => "border-radius"
            case BorderTopLeftRadius => "border-top-left-radius"
            case BorderTopRightRadius => "border-top-right-radius"
            case BorderBottomLeftRadius => "border-bottom-left-radius"
            case BorderBottomRightRadius => "border-bottom-right-radius"
            case BorderImage => "border-image"
            case BorderImageSource => "border-image-source"
            case BorderImageSlice => "border-image-slice"
            case BorderImageWidth => "border-image-width"
            case BorderImageOutset => "border-image-outset"
            case BorderImageRepeat => "border-image-repeat"
            case Outline => "outline"
            case OutlineColor => "outline-color"
            case OutlineStyle => "outline-style"
            case OutlineWidth => "outline-width"
            case OutlineOffset => "outline-offset"
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
            case Transition => "transition"
            case TransitionProperty => "transition-property"
            case TransitionDuration => "transition-duration"
            case TransitionDelay => "transition-delay"
            case TransitionTimingFunction => "transition-timing-function"
            case Animation => "animation"
            case AnimationName => "animation-name"
            case AnimationDuration => "animation-duration"
            case AnimationTimingFunction => "animation-timing-function"
            case AnimationDelay => "animation-delay"
            case AnimationIterationCount => "animation-iteration-count"
            case AnimationDirection => "animation-direction"
            case AnimationFillMode => "animation-fill-mode"
            case AnimationPlayState => "animation-play-state"
            case AnimationComposition => "animation-composition"
            case AnimationTimeline => "animation-timeline"
            case AnimationRange => "animation-range"
            case Font => "font"
            case FontFamily => "font-family"
            case FontWeight => "font-weight"
            case FontSize => "font-size"
            case FontStretch => "font-stretch"
            case FontStyle => "font-style"
            case FontVariantCaps => "font-variant-caps"
            case LineHeight => "line-height"
            case VerticalAlign => "vertical-align"
            case FlexDirection => "flex-direction"
            case FlexWrap => "flex-wrap"
            case FlexFlow => "flex-flow"
            case FlexGrow => "flex-grow"
            case FlexShrink => "flex-shrink"
            case FlexBasis => "flex-basis"
            case Flex => "flex"
            case JustifyContent => "justify-content"
            case AlignItems => "align-items"
            case AlignSelf => "align-self"
            case AlignContent => "align-content"
            case JustifyItems => "justify-items"
            case JustifySelf => "justify-self"
            case Order => "order"
            case Gap => "gap"
            case RowGap => "row-gap"
            case ColumnGap => "column-gap"
            case PlaceContent => "place-content"
            case PlaceItems => "place-items"
            case PlaceSelf => "place-self"
            case GridTemplateColumns => "grid-template-columns"
            case GridTemplateRows => "grid-template-rows"
            case GridTemplateAreas => "grid-template-areas"
            case GridAutoColumns => "grid-auto-columns"
            case GridAutoRows => "grid-auto-rows"
            case GridAutoFlow => "grid-auto-flow"
            case GridColumnStart => "grid-column-start"
            case GridColumnEnd => "grid-column-end"
            case GridRowStart => "grid-row-start"
            case GridRowEnd => "grid-row-end"
            case GridColumn => "grid-column"
            case GridRow => "grid-row"
            case GridArea => "grid-area"
            case Filter => "filter"
            case BackdropFilter => "backdrop-filter"
            case TextTransform => "text-transform"
            case TextDecoration => "text-decoration"
            case TextDecorationLine => "text-decoration-line"
            case TextDecorationColor => "text-decoration-color"
            case TextDecorationStyle => "text-decoration-style"
            case TextDecorationThickness => "text-decoration-thickness"
            case TextShadow => "text-shadow"
            case TextSizeAdjust => "text-size-adjust"
            case TextIndent => "text-indent"
            case TextAlign => "text-align"
            case TextAlignLast => "text-align-last"
            case TextJustify => "text-justify"
            case WordSpacing => "word-spacing"
            case LetterSpacing => "letter-spacing"
            case WhiteSpace => "white-space"
            case WordBreak => "word-break"
            case LineBreak => "line-break"
            case Hyphens => "hyphens"
            case OverflowWrap => "overflow-wrap"
            case Direction => "direction"
            case UnicodeBidi => "unicode-bidi"
            case BoxDecorationBreak => "box-decoration-break"
            case ColorScheme => "color-scheme"
            case Cursor => "cursor"
            case CaretColor => "caret-color"
            case CaretShape => "caret-shape"
            case Caret => "caret"
            case UserSelect => "user-select"
            case Appearance => "appearance"
            case Resize => "resize"
            case Fill => "fill"
            case Stroke => "stroke"
            case StrokeWidth => "stroke-width"
            case StrokeLinecap => "stroke-linecap"
            case StrokeLinejoin => "stroke-linejoin"
            case StrokeDasharray => "stroke-dasharray"
            case StrokeDashoffset => "stroke-dashoffset"
            case StrokeMiterlimit => "stroke-miterlimit"
            case MarkerStart => "marker-start"
            case MarkerMid => "marker-mid"
            case MarkerEnd => "marker-end"
            case Marker => "marker"
            case ColorInterpolation => "color-interpolation"
            case ColorRendering => "color-rendering"
            case ShapeRendering => "shape-rendering"
            case TextRendering => "text-rendering"
            case ImageRendering => "image-rendering"
            case ContainerType => "container-type"
            case ContainerName => "container-name"
            case Container => "container"
            case ListStyleType => "list-style-type"
            case ListStylePosition => "list-style-position"
            case ListStyleImage => "list-style-image"
            case ListStyle => "list-style"
            case MarkerSide => "marker-side"
            case CounterIncrement => "counter-increment"
            case CounterReset => "counter-reset"
            case CounterSet => "counter-set"
            case MaskImage => "mask-image"
            case MaskPosition => "mask-position"
            case MaskSize => "mask-size"
            case MaskRepeat => "mask-repeat"
            case MaskClip => "mask-clip"
            case MaskOrigin => "mask-origin"
            case MaskComposite => "mask-composite"
            case MaskMode => "mask-mode"
            case Mask => "mask"
            case MaskBorder => "mask-border"
            case MaskBorderSource => "mask-border-source"
            case MaskBorderSlice => "mask-border-slice"
            case MaskBorderWidth => "mask-border-width"
            case MaskBorderOutset => "mask-border-outset"
            case MaskBorderRepeat => "mask-border-repeat"
            case MaskBorderMode => "mask-border-mode"
            case MaskType => "mask-type"
            case WebKitMaskComposite => "-webkit-mask-composite"
            case MaskSourceType => "-webkit-mask-source-type"
            case ClipPath => "clip-path"
            case ScrollMargin => "scroll-margin"
            case ScrollMarginTop => "scroll-margin-top"
            case ScrollMarginBottom => "scroll-margin-bottom"
            case ScrollMarginLeft => "scroll-margin-left"
            case ScrollMarginRight => "scroll-margin-right"
            case ScrollMarginBlock => "scroll-margin-block"
            case ScrollMarginBlockStart => "scroll-margin-block-start"
            case ScrollMarginBlockEnd => "scroll-margin-block-end"
            case ScrollMarginInline => "scroll-margin-inline"
            case ScrollMarginInlineStart => "scroll-margin-inline-start"
            case ScrollMarginInlineEnd => "scroll-margin-inline-end"
            case ScrollPadding => "scroll-padding"
            case ScrollPaddingTop => "scroll-padding-top"
            case ScrollPaddingBottom => "scroll-padding-bottom"
            case ScrollPaddingLeft => "scroll-padding-left"
            case ScrollPaddingRight => "scroll-padding-right"
            case ScrollPaddingBlock => "scroll-padding-block"
            case ScrollPaddingBlockStart => "scroll-padding-block-start"
            case ScrollPaddingBlockEnd => "scroll-padding-block-end"
            case ScrollPaddingInline => "scroll-padding-inline"
            case ScrollPaddingInlineStart => "scroll-padding-inline-start"
            case ScrollPaddingInlineEnd => "scroll-padding-inline-end"
            case BorderSpacing => "border-spacing"
            case BorderBlockColor => "border-block-color"
            case BorderBlockStartColor => "border-block-start-color"
            case BorderBlockEndColor => "border-block-end-color"
            case BorderInlineColor => "border-inline-color"
            case BorderInlineStartColor => "border-inline-start-color"
            case BorderInlineEndColor => "border-inline-end-color"
            case BorderBlockStyle => "border-block-style"
            case BorderBlockStartStyle => "border-block-start-style"
            case BorderBlockEndStyle => "border-block-end-style"
            case BorderInlineStyle => "border-inline-style"
            case BorderInlineStartStyle => "border-inline-start-style"
            case BorderInlineEndStyle => "border-inline-end-style"
            case BorderBlockWidth => "border-block-width"
            case BorderBlockStartWidth => "border-block-start-width"
            case BorderBlockEndWidth => "border-block-end-width"
            case BorderInlineWidth => "border-inline-width"
            case BorderInlineStartWidth => "border-inline-start-width"
            case BorderInlineEndWidth => "border-inline-end-width"
            case BorderBlock => "border-block"
            case BorderBlockStart => "border-block-start"
            case BorderBlockEnd => "border-block-end"
            case BorderInline => "border-inline"
            case BorderInlineStart => "border-inline-start"
            case BorderInlineEnd => "border-inline-end"
            case MaskBoxImageSource => "-webkit-mask-box-image-source"
            case MaskBoxImageSlice => "-webkit-mask-box-image-slice"
            case MaskBoxImageWidth => "-webkit-mask-box-image-width"
            case MaskBoxImageOutset => "-webkit-mask-box-image-outset"
            case MaskBoxImageRepeat => "-webkit-mask-box-image-repeat"
            case MaskBoxImage => "-webkit-mask-box-image"
            case Unparsed => "unparsed"
            case Custom => "custom"
        }
    }
}
