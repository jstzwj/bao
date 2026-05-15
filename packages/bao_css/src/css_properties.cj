// bao_css - CSS Properties (CSS 属性定义)
// 严格翻译自: bun/src/css/properties/
//   对应: properties/properties.zig - Property union (所有 CSS 属性)
//   对应: PropertyId - 属性标识符
//   对应: PropertyIdTag - 属性标签 (用于枚举匹配)
//   对应: 逻辑属性分组 - LogicalGroup, PropertyCategory
// ============================================================================

package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// 属性分类
// 严格翻译自: logical.zig PropertyCategory, LogicalGroup
// ============================================================================

/// CSS 属性类别
/// 严格翻译自 PropertyCategory
public enum CssPropertyCategory {
    | Layout          // 布局: display, position, float, ...
    | BoxModel        // 盒模型: width, height, margin, padding, ...
    | Typography      // 排版: font, text, line-height, ...
    | Visual          // 视觉: color, background, border, ...
    | Animation       // 动画: transition, animation, transform, ...
    | Interaction     // 交互: cursor, user-select, ...
    | Transform       // 变换: transform, perspective, ...
    | Custom          // 自定义: --*
    | Other           // 其他

    public func name(): String {
        match (this) {
            case Layout => "layout"
            case BoxModel => "box-model"
            case Typography => "typography"
            case Visual => "visual"
            case Animation => "animation"
            case Interaction => "interaction"
            case Transform => "transform"
            case Custom => "custom"
            case Other => "other"
        }
    }
}

/// 逻辑属性分组
/// 严格翻译自 LogicalGroup
public enum CssLogicalGroup {
    | Margin
    | Padding
    | Inset
    | ScrollMargin
    | ScrollPadding
    | BorderRadius
    | BorderWidth
    | BorderStyle
    | BorderColor
    | Size
    | None

    public func name(): String {
        match (this) {
            case Margin => "margin"
            case Padding => "padding"
            case Inset => "inset"
            case ScrollMargin => "scroll-margin"
            case ScrollPadding => "scroll-padding"
            case BorderRadius => "border-radius"
            case BorderWidth => "border-width"
            case BorderStyle => "border-style"
            case BorderColor => "border-color"
            case Size => "size"
            case None => "none"
        }
    }
}

// ============================================================================
// 属性 ID
// 严格翻译自: properties/properties.zig PropertyId, PropertyIdTag
// ============================================================================

/// CSS 属性 ID 标签
/// 严格翻译自 PropertyIdTag
/// 用于在编译时匹配属性类型
public enum CssPropertyIdTag {
    | AlignContent
    | AlignItems
    | AlignSelf
    | Animation
    | AnimationComposition
    | AnimationDelay
    | AnimationDirection
    | AnimationDuration
    | AnimationFillMode
    | AnimationIterationCount
    | AnimationName
    | AnimationPlayState
    | AnimationTimingFunction
    | AnimationTimeline
    | Appearance
    | AspectRatio
    | BackdropFilter
    | BackfaceVisibility
    | Background
    | BackgroundAttachment
    | BackgroundBlendMode
    | BackgroundClip
    | BackgroundColor
    | BackgroundImage
    | BackgroundOrigin
    | BackgroundPosition
    | BackgroundPositionX
    | BackgroundPositionY
    | BackgroundRepeat
    | BackgroundSize
    | BlockSize
    | Border
    | BorderBlock
    | BorderBlockColor
    | BorderBlockStyle
    | BorderBlockWidth
    | BorderBlockEnd
    | BorderBlockEndColor
    | BorderBlockEndStyle
    | BorderBlockEndWidth
    | BorderBlockStart
    | BorderBlockStartColor
    | BorderBlockStartStyle
    | BorderBlockStartWidth
    | BorderBottom
    | BorderBottomColor
    | BorderBottomLeftRadius
    | BorderBottomRightRadius
    | BorderBottomStyle
    | BorderBottomWidth
    | BorderCollapse
    | BorderColor
    | BorderEndEndRadius
    | BorderEndStartRadius
    | BorderImage
    | BorderImageOutset
    | BorderImageRepeat
    | BorderImageSlice
    | BorderImageSource
    | BorderImageWidth
    | BorderInline
    | BorderInlineColor
    | BorderInlineStyle
    | BorderInlineWidth
    | BorderInlineEnd
    | BorderInlineEndColor
    | BorderInlineEndStyle
    | BorderInlineEndWidth
    | BorderInlineStart
    | BorderInlineStartColor
    | BorderInlineStartStyle
    | BorderInlineStartWidth
    | BorderLeft
    | BorderLeftColor
    | BorderLeftStyle
    | BorderLeftWidth
    | BorderRadius
    | BorderRight
    | BorderRightColor
    | BorderRightStyle
    | BorderRightWidth
    | BorderSpacing
    | BorderStartEndRadius
    | BorderStartStartRadius
    | BorderStyle
    | BorderTop
    | BorderTopColor
    | BorderTopLeftRadius
    | BorderTopRightRadius
    | BorderTopStyle
    | BorderTopWidth
    | BorderWidth
    | Bottom
    | BoxDecorationBreak
    | BoxShadow
    | BoxSizing
    | CaptionSide
    | Caret
    | CaretColor
    | CaretShape
    | Clear
    | ClipPath
    | Color
    | ColorScheme
    | ColumnCount
    | ColumnFill
    | ColumnGap
    | ColumnRule
    | ColumnRuleColor
    | ColumnRuleStyle
    | ColumnRuleWidth
    | ColumnSpan
    | ColumnWidth
    | Columns
    | Composes
    | Contain
    | Container
    | ContainerName
    | ContainerType
    | Content
    | ContentVisibility
    | CounterIncrement
    | CounterReset
    | CounterSet
    | Cursor
    | Direction
    | Display
    | EmptyCells
    | Flex
    | FlexBasis
    | FlexDirection
    | FlexFlow
    | FlexGrow
    | FlexShrink
    | FlexWrap
    | Float
    | Font
    | FontFamily
    | FontFeatureSettings
    | FontKerning
    | FontLanguageOverride
    | FontOpticalSizing
    | FontPalette
    | FontSize
    | FontSizeAdjust
    | FontStretch
    | FontStyle
    | FontSynthesis
    | FontSynthesisSmallCaps
    | FontSynthesisStyle
    | FontSynthesisWeight
    | FontVariant
    | FontVariantAlternates
    | FontVariantCaps
    | FontVariantEastAsian
    | FontVariantLigatures
    | FontVariantNumeric
    | FontVariantPosition
    | FontVariationSettings
    | FontWeight
    | ForcedColorAdjust
    | Gap
    | Grid
    | GridArea
    | GridAutoColumns
    | GridAutoFlow
    | GridAutoRows
    | gridColumn
    | GridColumnEnd
    | GridColumnStart
    | GridRow
    | GridRowEnd
    | GridRowStart
    | GridTemplate
    | GridTemplateAreas
    | GridTemplateColumns
    | GridTemplateRows
    | Height
    | Hyphens
    | ImageRendering
    | Inherit
    | Initial
    | InlineSize
    | Inset
    | InsetBlock
    | InsetBlockEnd
    | InsetBlockStart
    | InsetInline
    | InsetInlineEnd
    | InsetInlineStart
    | Isolation
    | JustifyContent
    | JustifyItems
    | JustifySelf
    | Left
    | LetterSpacing
    | LineBreak
    | LineHeight
    | ListStyle
    | ListStyleImage
    | ListStylePosition
    | ListStyleType
    | Margin
    | MarginBlock
    | MarginBlockEnd
    | MarginBlockStart
    | MarginBottom
    | MarginInline
    | MarginInlineEnd
    | MarginInlineStart
    | MarginLeft
    | MarginRight
    | MarginTop
    | MaxBlockSize
    | MaxHeight
    | MaxInlineSize
    | MaxWidth
    | MinBlockSize
    | MinHeight
    | MinInlineSize
    | MinWidth
    | MixBlendMode
    | ObjectFit
    | ObjectPosition
    | Offset
    | OffsetAnchor
    | OffsetDistance
    | OffsetPath
    | OffsetPosition
    | OffsetRotate
    | Opacity
    | Order
    | Orphans
    | Outline
    | OutlineColor
    | OutlineOffset
    | OutlineStyle
    | OutlineWidth
    | Overflow
    | OverflowAnchor
    | OverflowClipMargin
    | OverflowWrap
    | OverflowX
    | OverflowY
    | OverscrollBehavior
    | OverscrollBehaviorBlock
    | OverscrollBehaviorInline
    | OverscrollBehaviorX
    | OverscrollBehaviorY
    | Padding
    | PaddingBlock
    | PaddingBlockEnd
    | PaddingBlockStart
    | PaddingBottom
    | PaddingInline
    | PaddingInlineEnd
    | PaddingInlineStart
    | PaddingLeft
    | PaddingRight
    | PaddingTop
    | PageBreakAfter
    | PageBreakBefore
    | PageBreakInside
    | Perspective
    | PerspectiveOrigin
    | PlaceContent
    | PlaceItems
    | PlaceSelf
    | PointerEvents
    | Position
    | Quotes
    | Resize
    | Right
    | Rotate
    | RowGap
    | Scale
    | ScrollBehavior
    | ScrollMargin
    | ScrollMarginBlock
    | ScrollMarginBlockEnd
    | ScrollMarginBlockStart
    | ScrollMarginBottom
    | ScrollMarginInline
    | ScrollMarginInlineEnd
    | ScrollMarginInlineStart
    | ScrollMarginLeft
    | ScrollMarginRight
    | ScrollMarginTop
    | ScrollPadding
    | ScrollPaddingBlock
    | ScrollPaddingBlockEnd
    | ScrollPaddingBlockStart
    | ScrollPaddingBottom
    | ScrollPaddingInline
    | ScrollPaddingInlineEnd
    | ScrollPaddingInlineStart
    | ScrollPaddingLeft
    | ScrollPaddingRight
    | ScrollPaddingTop
    | ScrollSnapAlign
    | ScrollSnapStop
    | ScrollSnapType
    | ScrollbarColor
    | ScrollbarGutter
    | ScrollbarWidth
    | TableLayout
    | TextAlign
    | TextAlignLast
    | TextDecoration
    | TextDecorationColor
    | TextDecorationLine
    | TextDecorationSkipInk
    | TextDecorationStyle
    | TextDecorationThickness
    | TextEmphasis
    | TextEmphasisColor
    | TextEmphasisPosition
    | TextEmphasisStyle
    | TextIndent
    | TextJustify
    | TextOrientation
    | TextOverflow
    | TextShadow
    | TextSizeAdjust
    | TextTransform
    | TextUnderlineOffset
    | TextUnderlinePosition
    | Top
    | TouchAction
    | Transform
    | TransformBox
    | TransformOrigin
    | TransformStyle
    | Transition
    | TransitionDelay
    | TransitionDuration
    | TransitionProperty
    | TransitionTimingFunction
    | Translate
    | UnicodeBidi
    | Unset
    | UserSelect
    | VerticalAlign
    | Visibility
    | WhiteSpace
    | Widows
    | Width
    | WordBreak
    | WordSpacing
    | WordWrap
    | WritingMode
    | ZIndex
    | Zoom
    | Custom
    | All
    | RevertLayer
    | Unparsed
}

// ============================================================================
// 属性工具
// ============================================================================

/// CSS 属性工具函数
public class CssPropertyUtils {
    /// 获取属性的逻辑分组
    public static func getLogicalGroup(property: String): CssLogicalGroup {
        let lower = property.toLowerCase()
        match (lower) {
            case "margin" | "margin-top" | "margin-right" | "margin-bottom" |
                 "margin-left" | "margin-block" | "margin-block-start" |
                 "margin-block-end" | "margin-inline" | "margin-inline-start" |
                 "margin-inline-end" => CssLogicalGroup.Margin
            case "padding" | "padding-top" | "padding-right" | "padding-bottom" |
                 "padding-left" | "padding-block" | "padding-block-start" |
                 "padding-block-end" | "padding-inline" | "padding-inline-start" |
                 "padding-inline-end" => CssLogicalGroup.Padding
            case "inset" | "top" | "right" | "bottom" | "left" |
                 "inset-block" | "inset-block-start" | "inset-block-end" |
                 "inset-inline" | "inset-inline-start" | "inset-inline-end" => CssLogicalGroup.Inset
            case "border-radius" | "border-top-left-radius" |
                 "border-top-right-radius" | "border-bottom-left-radius" |
                 "border-bottom-right-radius" => CssLogicalGroup.BorderRadius
            case "width" | "height" | "min-width" | "min-height" |
                 "max-width" | "max-height" | "inline-size" | "block-size" |
                 "min-inline-size" | "min-block-size" |
                 "max-inline-size" | "max-block-size" => CssLogicalGroup.Size
            case _ => CssLogicalGroup.None
        }
    }

    /// 获取属性类别
    public static func getCategory(property: String): CssPropertyCategory {
        let lower = property.toLowerCase()
        match (lower) {
            case "display" | "position" | "float" | "clear" |
                 "flex" | "flex-direction" | "flex-wrap" | "flex-flow" |
                 "flex-grow" | "flex-shrink" | "flex-basis" |
                 "grid" | "grid-template" | "grid-area" | "grid-column" |
                 "grid-row" | "grid-auto-columns" | "grid-auto-rows" |
                 "grid-auto-flow" | "gap" | "row-gap" | "column-gap" |
                 "justify-content" | "justify-items" | "justify-self" |
                 "align-content" | "align-items" | "align-self" |
                 "place-content" | "place-items" | "place-self" |
                 "order" | "box-sizing" | "contain" |
                 "container" | "container-name" | "container-type" => CssPropertyCategory.Layout
            case "width" | "height" | "min-width" | "min-height" |
                 "max-width" | "max-height" | "margin" | "padding" |
                 "border" | "border-radius" | "inset" | "top" | "right" |
                 "bottom" | "left" | "overflow" | "overflow-x" | "overflow-y" => CssPropertyCategory.BoxModel
            case "font" | "font-family" | "font-size" | "font-weight" |
                 "font-style" | "line-height" | "letter-spacing" |
                 "word-spacing" | "text-align" | "text-decoration" |
                 "text-transform" | "text-indent" | "text-shadow" |
                 "white-space" | "word-break" | "word-wrap" |
                 "color" | "vertical-align" => CssPropertyCategory.Typography
            case "background" | "background-color" | "background-image" |
                 "background-position" | "background-size" | "background-repeat" |
                 "border-color" | "border-style" | "border-width" |
                 "box-shadow" | "outline" | "opacity" | "visibility" |
                 "filter" | "backdrop-filter" | "mix-blend-mode" |
                 "isolation" | "z-index" | "zoom" => CssPropertyCategory.Visual
            case "animation" | "animation-name" | "animation-duration" |
                 "animation-timing-function" | "animation-delay" |
                 "animation-iteration-count" | "animation-direction" |
                 "animation-fill-mode" | "animation-play-state" |
                 "transition" | "transition-property" | "transition-duration" |
                 "transition-timing-function" | "transition-delay" => CssPropertyCategory.Animation
            case "transform" | "transform-origin" | "transform-style" |
                 "perspective" | "perspective-origin" | "backface-visibility" |
                 "rotate" | "scale" | "translate" => CssPropertyCategory.Transform
            case "cursor" | "user-select" | "pointer-events" |
                 "touch-action" | "resize" | "caret-color" => CssPropertyCategory.Interaction
            case _ =>
                if (lower.startsWith("--")) { CssPropertyCategory.Custom }
                else { CssPropertyCategory.Other }
        }
    }

    /// 是否为简写属性
    public static func isShorthand(property: String): Bool {
        let lower = property.toLowerCase()
        match (lower) {
            case "margin" | "padding" | "border" | "border-radius" |
                 "border-width" | "border-style" | "border-color" |
                 "background" | "font" | "flex" | "flex-flow" |
                 "gap" | "grid" | "grid-template" | "grid-area" |
                 "grid-column" | "grid-row" | "transition" | "animation" |
                 "transform" | "outline" | "list-style" | "columns" |
                 "offset" | "text-decoration" | "text-emphasis" |
                 "inset" | "margin-block" | "margin-inline" |
                 "padding-block" | "padding-inline" |
                 "scroll-margin" | "scroll-padding" |
                 "border-block" | "border-inline" |
                 "border-block-end" | "border-block-start" |
                 "border-inline-end" | "border-inline-start" => true
            case _ => false
        }
    }

    /// 是否为继承属性
    public static func isInherited(property: String): Bool {
        let lower = property.toLowerCase()
        match (lower) {
            case "font" | "font-family" | "font-size" | "font-style" |
                 "font-weight" | "font-variant" | "line-height" |
                 "color" | "text-align" | "text-indent" | "text-transform" |
                 "white-space" | "word-break" | "word-wrap" |
                 "letter-spacing" | "word-spacing" | "direction" |
                 "writing-mode" | "visibility" | "cursor" |
                 "list-style" | "list-style-type" | "list-style-position" |
                 "list-style-image" | "quotes" | "orphans" | "widows" => true
            case _ => false
        }
    }

    /// 获取简写属性包含的子属性列表
    public static func getLonghands(property: String): ArrayList<String> {
        let lower = property.toLowerCase()
        match (lower) {
            case "margin" =>
                ArrayList<String>(["margin-top", "margin-right", "margin-bottom", "margin-left"])
            case "padding" =>
                ArrayList<String>(["padding-top", "padding-right", "padding-bottom", "padding-left"])
            case "border-radius" =>
                ArrayList<String>(["border-top-left-radius", "border-top-right-radius", "border-bottom-right-radius", "border-bottom-left-radius"])
            case "background" =>
                ArrayList<String>(["background-color", "background-image", "background-position", "background-size", "background-repeat", "background-attachment", "background-origin", "background-clip"])
            case "font" =>
                ArrayList<String>(["font-style", "font-variant", "font-weight", "font-size", "line-height", "font-family"])
            case "transition" =>
                ArrayList<String>(["transition-property", "transition-duration", "transition-timing-function", "transition-delay"])
            case "animation" =>
                ArrayList<String>(["animation-name", "animation-duration", "animation-timing-function", "animation-delay", "animation-iteration-count", "animation-direction", "animation-fill-mode", "animation-play-state"])
            case _ =>
                ArrayList<String>()
        }
    }
}
