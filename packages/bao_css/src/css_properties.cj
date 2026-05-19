// bao_css - CSS Properties (CSS 属性定义)
// 严格翻译自: bun/src/css/properties/
//   对应: properties/properties.zig - Property union (所有 CSS 属性)
//   对应: PropertyId - 属性标识符
//   对应: PropertyIdTag - 属性标签 (用于枚举匹配)
//   对应: 逻辑属性分组 - LogicalGroup, PropertyCategory
// ============================================================================

package bao_css

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
        let lower = property
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
        let lower = property
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
        let lower = property
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
        let lower = property
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
        let lower = property
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
            case "border-color" =>
                ArrayList<String>(["border-top-color", "border-right-color", "border-bottom-color", "border-left-color"])
            case "border-style" =>
                ArrayList<String>(["border-top-style", "border-right-style", "border-bottom-style", "border-left-style"])
            case "border-width" =>
                ArrayList<String>(["border-top-width", "border-right-width", "border-bottom-width", "border-left-width"])
            case "border" =>
                ArrayList<String>(["border-width", "border-style", "border-color"])
            case "border-top" =>
                ArrayList<String>(["border-top-width", "border-top-style", "border-top-color"])
            case "border-bottom" =>
                ArrayList<String>(["border-bottom-width", "border-bottom-style", "border-bottom-color"])
            case "border-left" =>
                ArrayList<String>(["border-left-width", "border-left-style", "border-left-color"])
            case "border-right" =>
                ArrayList<String>(["border-right-width", "border-right-style", "border-right-color"])
            case "border-block" =>
                ArrayList<String>(["border-block-start-width", "border-block-end-width", "border-block-start-style", "border-block-end-style", "border-block-start-color", "border-block-end-color"])
            case "border-inline" =>
                ArrayList<String>(["border-inline-start-width", "border-inline-end-width", "border-inline-start-style", "border-inline-end-style", "border-inline-start-color", "border-inline-end-color"])
            case "outline" =>
                ArrayList<String>(["outline-color", "outline-style", "outline-width"])
            case "list-style" =>
                ArrayList<String>(["list-style-type", "list-style-position", "list-style-image"])
            case "columns" =>
                ArrayList<String>(["column-width", "column-count"])
            case "flex" =>
                ArrayList<String>(["flex-grow", "flex-shrink", "flex-basis"])
            case "flex-flow" =>
                ArrayList<String>(["flex-direction", "flex-wrap"])
            case "gap" =>
                ArrayList<String>(["row-gap", "column-gap"])
            case "grid" =>
                ArrayList<String>(["grid-template-rows", "grid-template-columns", "grid-template-areas", "grid-auto-rows", "grid-auto-columns", "grid-auto-flow"])
            case "grid-template" =>
                ArrayList<String>(["grid-template-columns", "grid-template-rows", "grid-template-areas"])
            case "grid-area" =>
                ArrayList<String>(["grid-row-start", "grid-row-end", "grid-column-start", "grid-column-end"])
            case "grid-column" =>
                ArrayList<String>(["grid-column-start", "grid-column-end"])
            case "grid-row" =>
                ArrayList<String>(["grid-row-start", "grid-row-end"])
            case "text-decoration" =>
                ArrayList<String>(["text-decoration-line", "text-decoration-style", "text-decoration-color"])
            case "text-emphasis" =>
                ArrayList<String>(["text-emphasis-style", "text-emphasis-color"])
            case "inset" =>
                ArrayList<String>(["top", "right", "bottom", "left"])
            case "inset-block" =>
                ArrayList<String>(["inset-block-start", "inset-block-end"])
            case "inset-inline" =>
                ArrayList<String>(["inset-inline-start", "inset-inline-end"])
            case "margin-block" =>
                ArrayList<String>(["margin-block-start", "margin-block-end"])
            case "margin-inline" =>
                ArrayList<String>(["margin-inline-start", "margin-inline-end"])
            case "padding-block" =>
                ArrayList<String>(["padding-block-start", "padding-block-end"])
            case "padding-inline" =>
                ArrayList<String>(["padding-inline-start", "padding-inline-end"])
            case "scroll-margin" =>
                ArrayList<String>(["scroll-margin-top", "scroll-margin-right", "scroll-margin-bottom", "scroll-margin-left"])
            case "scroll-margin-block" =>
                ArrayList<String>(["scroll-margin-block-start", "scroll-margin-block-end"])
            case "scroll-margin-inline" =>
                ArrayList<String>(["scroll-margin-inline-start", "scroll-margin-inline-end"])
            case "scroll-padding" =>
                ArrayList<String>(["scroll-padding-top", "scroll-padding-right", "scroll-padding-bottom", "scroll-padding-left"])
            case "scroll-padding-block" =>
                ArrayList<String>(["scroll-padding-block-start", "scroll-padding-block-end"])
            case "scroll-padding-inline" =>
                ArrayList<String>(["scroll-padding-inline-start", "scroll-padding-inline-end"])
            case "container" =>
                ArrayList<String>(["container-name", "container-type"])
            case "caret" =>
                ArrayList<String>(["caret-color", "caret-shape"])
            case "offset" =>
                ArrayList<String>(["offset-position", "offset-path", "offset-distance", "offset-rotate", "offset-anchor"])
            case "place-content" =>
                ArrayList<String>(["align-content", "justify-content"])
            case "place-items" =>
                ArrayList<String>(["align-items", "justify-items"])
            case "place-self" =>
                ArrayList<String>(["align-self", "justify-self"])
            case _ =>
                ArrayList<String>()
        }
    }

    // ========================================================================
    // 属性类型分类 (严格翻译自 properties.zig 中的宏)
    // ========================================================================

    /// 属性的有效供应商前缀
    /// 严格翻译自 properties.zig 中的 valid_prefixes 字段
    public static func getValidPrefixes(property: String): ArrayList<String> {
        let lower = property
        match (lower) {
            case "animation" | "animation-name" | "animation-duration" |
                 "animation-timing-function" | "animation-delay" |
                 "animation-iteration-count" | "animation-direction" |
                 "animation-fill-mode" | "animation-play-state" =>
                ArrayList<String>(["-webkit-", "-moz-"])
            case "transition" | "transition-property" | "transition-duration" |
                 "transition-delay" | "transition-timing-function" =>
                ArrayList<String>(["-webkit-", "-moz-"])
            case "transform" | "transform-origin" =>
                ArrayList<String>(["-webkit-", "-moz-", "-ms-"])
            case "transform-style" | "perspective" | "perspective-origin" |
                 "backface-visibility" =>
                ArrayList<String>(["-webkit-", "-moz-"])
            case "flex" | "flex-grow" | "flex-shrink" | "flex-basis" =>
                ArrayList<String>(["-webkit-"])
            case "flex-direction" | "flex-wrap" | "flex-flow" =>
                ArrayList<String>(["-webkit-", "-ms-"])
            case "order" =>
                ArrayList<String>(["-webkit-"])
            case "align-content" | "align-items" | "align-self" =>
                ArrayList<String>(["-webkit-"])
            case "box-sizing" =>
                ArrayList<String>(["-webkit-", "-moz-"])
            case "border-radius" | "border-top-left-radius" | "border-top-right-radius" |
                 "border-bottom-left-radius" | "border-bottom-right-radius" =>
                ArrayList<String>(["-webkit-", "-moz-"])
            case "border-image" =>
                ArrayList<String>(["-webkit-", "-moz-"])
            case "background-clip" =>
                ArrayList<String>(["-webkit-", "-moz-"])
            case "box-shadow" =>
                ArrayList<String>(["-webkit-", "-moz-"])
            case "filter" | "backdrop-filter" =>
                ArrayList<String>(["-webkit-"])
            case "user-select" =>
                ArrayList<String>(["-webkit-", "-moz-", "-ms-"])
            case "appearance" =>
                ArrayList<String>(["-webkit-", "-moz-", "-ms-"])
            case "text-decoration" | "text-decoration-line" | "text-decoration-style" |
                 "text-decoration-color" =>
                ArrayList<String>(["-webkit-", "-moz-"])
            case "text-size-adjust" =>
                ArrayList<String>(["-webkit-", "-moz-", "-ms-"])
            case "hyphens" =>
                ArrayList<String>(["-webkit-", "-moz-", "-ms-"])
            case "tab-size" =>
                ArrayList<String>(["-moz-"])
            case "clip-path" =>
                ArrayList<String>(["-webkit-"])
            case "text-emphasis" | "text-emphasis-style" | "text-emphasis-color" |
                 "text-emphasis-position" =>
                ArrayList<String>(["-webkit-"])
            case "mask" | "mask-image" | "mask-position" | "mask-size" |
                 "mask-repeat" | "mask-origin" | "mask-clip" | "mask-composite" =>
                ArrayList<String>(["-webkit-"])
            case "box-decoration-break" =>
                ArrayList<String>(["-webkit-"])
            case "font-feature-settings" | "font-variant-ligatures" |
                 "font-language_override" =>
                ArrayList<String>(["-webkit-"])
            case _ => ArrayList<String>()
        }
    }

    /// 获取属性是否需要供应商前缀
    /// 严格翻译自 properties.zig 中的 unprefixed 字段
    public static func isUnprefixed(property: String): Bool {
        let lower = property
        match (lower) {
            case "box-orient" | "box-direction" | "box-ordinal-group" |
                 "box-align" | "box-flex" | "box-flex-group" | "box-pack" |
                 "box-lines" =>
                false // 旧版 2009 flexbox 属性，只有前缀版本
            case "flex-pack" | "flex-order" | "flex-align" | "flex-item-align" |
                 "flex-line-pack" | "flex-positive" | "flex-negative" |
                 "flex-preferred-size" =>
                false // 旧版 2012 flexbox 属性，只有前缀版本
            case _ => true
        }
    }
}

// ============================================================================
// CSS-wide 关键字
// 严格翻译自: properties/properties.zig CSSWideKeyword enum
// ============================================================================

/// CSS 全局关键字
/// 严格翻译自 CSSWideKeyword enum { initial, inherit, unset, revert, revert-layer }
public enum CssWideKeyword {
    | Initial      // 初始值
    | Inherit      // 继承
    | Unset        // unset (继承或初始)
    | Revert       // 回退到上层来源
    | RevertLayer  // 回退到上层层叠层

    public func toCss(): String {
        match (this) {
            case Initial => "initial"
            case Inherit => "inherit"
            case Unset => "unset"
            case Revert => "revert"
            case RevertLayer => "revert-layer"
        }
    }

    /// 从字符串解析
    /// 严格翻译自 CSSWideKeyword.parse
    public static func parse(input: String): ?CssWideKeyword {
        match (input) {
            case "initial" => Some(CssWideKeyword.Initial)
            case "inherit" => Some(CssWideKeyword.Inherit)
            case "unset" => Some(CssWideKeyword.Unset)
            case "revert" => Some(CssWideKeyword.Revert)
            case "revert-layer" => Some(CssWideKeyword.RevertLayer)
            case _ => None
        }
    }

    public operator func ==(right: CssWideKeyword): Bool {
        this.toCss() == right.toCss()
    }
}

// ============================================================================
// 属性前缀处理器
// 严格翻译自: properties/prefix_handler.zig 的关键逻辑
// ============================================================================

/// CSS 属性前缀处理工具
/// 严格翻译自 prefix_handler
public class CssPropertyPrefixHandler {
    /// 从属性名中提取供应商前缀和基础属性名
    /// 严格翻译自 property_id_mixin::from_string 中的前缀提取
    public static func extractPrefix(name: String): (String, String) {
        if (name.startsWith("-webkit-")) {
            ("-webkit-", name[8..name.size])
        } else if (name.startsWith("-moz-")) {
            ("-moz-", name[5..name.size])
        } else if (name.startsWith("-ms-")) {
            ("-ms-", name[4..name.size])
        } else if (name.startsWith("-o-")) {
            ("-o-", name[3..name.size])
        } else {
            ("", name)
        }
    }

    /// 为属性名添加供应商前缀
    public static func addPrefix(name: String, prefix: String): String {
        prefix + name
    }

    /// 移除属性名中的供应商前缀
    public static func stripPrefix(name: String): String {
        let (prefix, base) = extractPrefix(name)
        base
    }
}
