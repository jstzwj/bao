// bao_css - CSS 属性定义模块入口
// 严格翻译自: bun/src/css/properties/mod.rs
//   对应: properties/properties.zig - Property definitions, handlers, shorthands
package bao_css.properties

import bao_core.*
import bao_collections.*
import bao_css.values.*
import bao_css.rules.*

// ============================================================================
// CSS 宽关键字
// 严格翻译自: properties/mod.rs CSSWideKeyword
// ============================================================================

/// CSS 宽关键字
/// 严格翻译自 CSSWideKeyword enum { Initial, Inherit, Unset, Revert, RevertLayer }
public enum CssWideKeyword {
    | Initial      // 初始值
    | Inherit      // 继承值
    | Unset        // unset
    | Revert       // revert
    | RevertLayer  // revert-layer

    /// 解析
    public static func parse(input: CssParser): ?CssWideKeyword {
        let ident = input.expectIdent()
        match (ident) {
            case Some(id) => {
                let lower = id.toLower()
                match (lower) {
                    "initial" => Some(CssWideKeyword.Initial)
                    "inherit" => Some(CssWideKeyword.Inherit)
                    "unset" => Some(CssWideKeyword.Unset)
                    "revert" => Some(CssWideKeyword.Revert)
                    "revert-layer" => Some(CssWideKeyword.RevertLayer)
                    case _ => None
                }
            }
            case None => None
        }
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (this) {
            case Initial => "initial"
            case Inherit => "inherit"
            case Unset => "unset"
            case Revert => "revert"
            case RevertLayer => "revert-layer"
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// CSS 属性 ID
// 严格翻译自: properties/properties_generated.rs PropertyId, PropertyIdTag
// ============================================================================

/// CSS 属性 ID
/// 严格翻译自 PropertyId struct
public class CssPropertyId {
    public var tag: CssPropertyIdTag
    public var vendorPrefix: CssVendorPrefix

    public init(tag: CssPropertyIdTag) {
        this.tag = tag
        this.vendorPrefix = CssVendorPrefix()
    }

    public init(tag: CssPropertyIdTag, vendorPrefix: CssVendorPrefix) {
        this.tag = tag
        this.vendorPrefix = vendorPrefix
    }

    /// 获取属性名
    public func name(): String {
        tag.propertyName()
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        let prefix = vendorPrefix.toCss()
        "${prefix}${tag.propertyName()}"
    }

    public func toString(): String {
        toCss()
    }
}

/// CSS 属性 ID 标签
/// 严格翻译自 PropertyIdTag enum (249 variants from properties_generated)
/// 这里只列出常用属性, 完整列表在 properties_generated.cj
public enum CssPropertyIdTag {
    // 盒模型
    | Width
    | Height
    | MinWidth
    | MinHeight
    | MaxWidth
    | MaxHeight
    | Margin
    | MarginTop
    | MarginRight
    | MarginBottom
    | MarginLeft
    | Padding
    | PaddingTop
    | PaddingRight
    | PaddingBottom
    | PaddingLeft
    | BoxSizing

    // 边框
    | Border
    | BorderTop
    | BorderRight
    | BorderBottom
    | BorderLeft
    | BorderWidth
    | BorderStyle
    | BorderColor
    | BorderRadius
    | BorderImage
    | Outline
    | OutlineWidth
    | OutlineStyle
    | OutlineColor
    | OutlineOffset

    // 背景
    | Background
    | BackgroundColor
    | BackgroundImage
    | BackgroundPosition
    | BackgroundSize
    | BackgroundRepeat
    | BackgroundAttachment
    | BackgroundClip
    | BackgroundOrigin

    // 文本
    | Color
    | Font
    | FontFamily
    | FontSize
    | FontStyle
    | FontWeight
    | FontStretch
    | LineHeight
    | TextAlign
    | TextDecoration
    | TextTransform
    | TextShadow
    | LetterSpacing
    | WordSpacing
    | WhiteSpace
    | TextOverflow
    | TextIndent
    | WordBreak
    | OverflowWrap

    // 布局
    | Display
    | Position
    | Top
    | Right
    | Bottom
    | Left
    | Float
    | Clear
    | ZIndex
    | Overflow
    | OverflowX
    | OverflowY

    // 弹性布局
    | Flex
    | FlexDirection
    | FlexWrap
    | FlexFlow
    | JustifyContent
    | AlignItems
    | AlignSelf
    | AlignContent
    | FlexGrow
    | FlexShrink
    | FlexBasis
    | Order
    | Gap
    | RowGap
    | ColumnGap

    // 网格布局
    | Grid
    | GridTemplate
    | GridTemplateRows
    | GridTemplateColumns
    | GridTemplateAreas
    | GridRow
    | GridColumn
    | GridArea
    | GridGap
    | GridRowGap
    | GridColumnGap

    // 变换
    | Transform
    | TransformOrigin
    | TransformStyle
    | Scale
    | Rotate
    | Translate

    // 过渡/动画
    | Transition
    | TransitionProperty
    | TransitionDuration
    | TransitionTimingFunction
    | TransitionDelay
    | Animation
    | AnimationName
    | AnimationDuration
    | AnimationTimingFunction
    | AnimationDelay
    | AnimationIterationCount
    | AnimationDirection
    | AnimationFillMode
    | AnimationPlayState

    // 效果
    | Opacity
    | Visibility
    | BoxShadow
    | Filter
    | BackdropFilter
    | MixBlendMode
    | BackgroundBlendMode
    | ClipPath
    | Mask
    | MaskImage
    | MaskPosition
    | MaskSize
    | MaskRepeat
    | MaskOrigin
    | MaskClip

    // 尺寸
    | AspectRatio
    | Contain
    | Content
    | Container
    | ContainerType
    | ContainerName

    // 其他
    | Cursor
    | PointerEvents
    | UserSelect
    | Resize
    | Appearance
    | ListStyle
    | ListStyleType
    | ListStylePosition
    | ListStyleImage
    | TableLayout
    | BorderCollapse
    | BorderSpacing
    | CaptionSide
    | VerticalAlign
    | ContentVisibility
    | Isolation
    | WillChange
    | TouchAction
    | ScrollBehavior
    | ScrollbarWidth
    | ScrollbarGutter
    | ScrollSnapType
    | ScrollSnapAlign
    | ScrollPadding
    | OverscrollBehavior
    | AccentColor
    | CaretColor
    | ColorScheme
    | ImgRendering

    /// 获取属性名
    public func propertyName(): String {
        match (this) {
            case Width => "width"
            case Height => "height"
            case MinWidth => "min-width"
            case MinHeight => "min-height"
            case MaxWidth => "max-width"
            case MaxHeight => "max-height"
            case Margin => "margin"
            case MarginTop => "margin-top"
            case MarginRight => "margin-right"
            case MarginBottom => "margin-bottom"
            case MarginLeft => "margin-left"
            case Padding => "padding"
            case PaddingTop => "padding-top"
            case PaddingRight => "padding-right"
            case PaddingBottom => "padding-bottom"
            case PaddingLeft => "padding-left"
            case BoxSizing => "box-sizing"
            case Border => "border"
            case BorderTop => "border-top"
            case BorderRight => "border-right"
            case BorderBottom => "border-bottom"
            case BorderLeft => "border-left"
            case BorderWidth => "border-width"
            case BorderStyle => "border-style"
            case BorderColor => "border-color"
            case BorderRadius => "border-radius"
            case BorderImage => "border-image"
            case Outline => "outline"
            case OutlineWidth => "outline-width"
            case OutlineStyle => "outline-style"
            case OutlineColor => "outline-color"
            case OutlineOffset => "outline-offset"
            case Background => "background"
            case BackgroundColor => "background-color"
            case BackgroundImage => "background-image"
            case BackgroundPosition => "background-position"
            case BackgroundSize => "background-size"
            case BackgroundRepeat => "background-repeat"
            case BackgroundAttachment => "background-attachment"
            case BackgroundClip => "background-clip"
            case BackgroundOrigin => "background-origin"
            case Color => "color"
            case Font => "font"
            case FontFamily => "font-family"
            case FontSize => "font-size"
            case FontStyle => "font-style"
            case FontWeight => "font-weight"
            case FontStretch => "font-stretch"
            case LineHeight => "line-height"
            case TextAlign => "text-align"
            case TextDecoration => "text-decoration"
            case TextTransform => "text-transform"
            case TextShadow => "text-shadow"
            case LetterSpacing => "letter-spacing"
            case WordSpacing => "word-spacing"
            case WhiteSpace => "white-space"
            case TextOverflow => "text-overflow"
            case TextIndent => "text-indent"
            case WordBreak => "word-break"
            case OverflowWrap => "overflow-wrap"
            case Display => "display"
            case Position => "position"
            case Top => "top"
            case Right => "right"
            case Bottom => "bottom"
            case Left => "left"
            case Float => "float"
            case Clear => "clear"
            case ZIndex => "z-index"
            case Overflow => "overflow"
            case OverflowX => "overflow-x"
            case OverflowY => "overflow-y"
            case Flex => "flex"
            case FlexDirection => "flex-direction"
            case FlexWrap => "flex-wrap"
            case FlexFlow => "flex-flow"
            case JustifyContent => "justify-content"
            case AlignItems => "align-items"
            case AlignSelf => "align-self"
            case AlignContent => "align-content"
            case FlexGrow => "flex-grow"
            case FlexShrink => "flex-shrink"
            case FlexBasis => "flex-basis"
            case Order => "order"
            case Gap => "gap"
            case RowGap => "row-gap"
            case ColumnGap => "column-gap"
            case Grid => "grid"
            case GridTemplate => "grid-template"
            case GridTemplateRows => "grid-template-rows"
            case GridTemplateColumns => "grid-template-columns"
            case GridTemplateAreas => "grid-template-areas"
            case GridRow => "grid-row"
            case GridColumn => "grid-column"
            case GridArea => "grid-area"
            case GridGap => "grid-gap"
            case GridRowGap => "grid-row-gap"
            case GridColumnGap => "grid-column-gap"
            case Transform => "transform"
            case TransformOrigin => "transform-origin"
            case TransformStyle => "transform-style"
            case Scale => "scale"
            case Rotate => "rotate"
            case Translate => "translate"
            case Transition => "transition"
            case TransitionProperty => "transition-property"
            case TransitionDuration => "transition-duration"
            case TransitionTimingFunction => "transition-timing-function"
            case TransitionDelay => "transition-delay"
            case Animation => "animation"
            case AnimationName => "animation-name"
            case AnimationDuration => "animation-duration"
            case AnimationTimingFunction => "animation-timing-function"
            case AnimationDelay => "animation-delay"
            case AnimationIterationCount => "animation-iteration-count"
            case AnimationDirection => "animation-direction"
            case AnimationFillMode => "animation-fill-mode"
            case AnimationPlayState => "animation-play-state"
            case Opacity => "opacity"
            case Visibility => "visibility"
            case BoxShadow => "box-shadow"
            case Filter => "filter"
            case BackdropFilter => "backdrop-filter"
            case MixBlendMode => "mix-blend-mode"
            case BackgroundBlendMode => "background-blend-mode"
            case ClipPath => "clip-path"
            case Mask => "mask"
            case MaskImage => "mask-image"
            case MaskPosition => "mask-position"
            case MaskSize => "mask-size"
            case MaskRepeat => "mask-repeat"
            case MaskOrigin => "mask-origin"
            case MaskClip => "mask-clip"
            case AspectRatio => "aspect-ratio"
            case Contain => "contain"
            case Content => "content"
            case Container => "container"
            case ContainerType => "container-type"
            case ContainerName => "container-name"
            case Cursor => "cursor"
            case PointerEvents => "pointer-events"
            case UserSelect => "user-select"
            case Resize => "resize"
            case Appearance => "appearance"
            case ListStyle => "list-style"
            case ListStyleType => "list-style-type"
            case ListStylePosition => "list-style-position"
            case ListStyleImage => "list-style-image"
            case TableLayout => "table-layout"
            case BorderCollapse => "border-collapse"
            case BorderSpacing => "border-spacing"
            case CaptionSide => "caption-side"
            case VerticalAlign => "vertical-align"
            case ContentVisibility => "content-visibility"
            case Isolation => "isolation"
            case WillChange => "will-change"
            case TouchAction => "touch-action"
            case ScrollBehavior => "scroll-behavior"
            case ScrollbarWidth => "scrollbar-width"
            case ScrollbarGutter => "scrollbar-gutter"
            case ScrollSnapType => "scroll-snap-type"
            case ScrollSnapAlign => "scroll-snap-align"
            case ScrollPadding => "scroll-padding"
            case OverscrollBehavior => "overscroll-behavior"
            case AccentColor => "accent-color"
            case CaretColor => "caret-color"
            case ColorScheme => "color-scheme"
            case ImgRendering => "image-rendering"
        }
    }
}

// ============================================================================
// CSS 属性值
// 严格翻译自: properties/properties_generated.rs Property
// ============================================================================

/// CSS 属性
/// 严格翻译自 Property enum (249 variants with typed payloads)
/// 简化为统一的键值存储
public class CssProperty {
    public var id: CssPropertyId
    /// 属性值 CSS 文本
    public var valueText: String
    /// 是否为 !important
    public var important: Bool
    /// CSS 宽关键字 (如果有)
    public var wideKeyword: ?CssWideKeyword

    public init(id: CssPropertyId, value: String) {
        this.id = id
        this.valueText = value
        this.important = false
        this.wideKeyword = None
    }

    public init(id: CssPropertyId, keyword: CssWideKeyword) {
        this.id = id
        this.valueText = keyword.toCss()
        this.important = false
        this.wideKeyword = Some(keyword)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Property::value_to_css
    public func toCss(minify: Bool): String {
        let importantStr = if (important) { " !important" } else { "" }
        "${id.toCss()}: ${valueText}${importantStr}"
    }

    /// 深拷贝
    public func deepClone(): CssProperty {
        let p = CssProperty(id, valueText)
        p.important = important
        p.wideKeyword = wideKeyword
        p
    }

    /// 相等比较
    public func eql(other: CssProperty): Bool {
        id.tag == other.id.tag && valueText == other.valueText
    }

    public func toString(): String {
        toCss(false)
    }
}
