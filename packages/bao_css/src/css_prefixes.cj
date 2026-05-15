// bao_css - CSS 浏览器前缀处理
// 严格翻译自: bun/src/css/prefixes.zig
//   对应: prefixes.zig Feature enum - CSS 特性枚举
//   对应: Feature.prefixesFor() - 根据浏览器版本计算所需前缀
//   对应: Feature.isFlex2009() - 是否需要 2009 旧版 flexbox 前缀
//   对应: Feature.isWebkitGradient() - 是否需要旧版 -webkit-gradient() 语法
//
// 注意: 此文件由 build-prefixes.js 自动生成
// 版本号编码: (major << 16) | (minor << 8) | patch
// 例如: Chrome 4.0 = 262144, Chrome 12 = 786432
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// 浏览器版本号编码
// 严格翻译自: prefixes.zig 中的版本比较逻辑
// 版本号编码: (major << 16) | (minor << 8) | patch
// ============================================================================

/// 浏览器版本编码工具
public class CssBrowserVersion {
    /// 编码版本号
    public static func encode(major: Int64, minor: Int64, patch: Int64): Int64 {
        (major << 16) | (minor << 8) | patch
    }

    /// Chrome 版本编码
    public static func chrome(major: Int64): Int64 {
        encode(major, 0, 0)
    }

    /// Firefox 版本编码
    public static func firefox(major: Int64): Int64 {
        encode(major, 0, 0)
    }

    /// Safari 版本编码
    public static func safari(major: Int64, minor: Int64): Int64 {
        encode(major, minor, 0)
    }

    /// iOS Safari 版本编码
    public static func iosSaf(major: Int64, minor: Int64): Int64 {
        encode(major, minor, 0)
    }

    /// Android 版本编码
    public static func android(major: Int64, minor: Int64): Int64 {
        encode(major, minor, 0)
    }

    /// Edge 版本编码
    public static func edge(major: Int64): Int64 {
        encode(major, 0, 0)
    }

    /// Opera 版本编码
    public static func opera(major: Int64, minor: Int64): Int64 {
        encode(major, minor, 0)
    }

    /// IE 版本编码
    public static func ie(major: Int64): Int64 {
        encode(major, 0, 0)
    }

    /// Samsung 版本编码
    public static func samsung(major: Int64, minor: Int64): Int64 {
        encode(major, minor, 0)
    }
}

// ============================================================================
// 浏览器版本配置
// 严格翻译自: css_parser.zig Browsers struct
// ============================================================================

/// 浏览器目标版本
/// 严格翻译自 Browsers struct (targets.zig)
/// 各字段为编码后的版本号，None 表示不 targeting 该浏览器
public class CssBrowserTargets {
    public var android: ?Int64
    public var chrome: ?Int64
    public var edge: ?Int64
    public var firefox: ?Int64
    public var ie: ?Int64
    public var iosSaf: ?Int64
    public var opera: ?Int64
    public var safari: ?Int64
    public var samsung: ?Int64

    public init() {
        this.android = None
        this.chrome = None
        this.edge = None
        this.firefox = None
        this.ie = None
        this.iosSaf = None
        this.opera = None
        this.safari = None
        this.samsung = None
    }

    /// 检查浏览器版本是否在指定范围内
    public static func versionInRange(version: ?Int64, minVersion: Int64, maxVersion: Int64): Bool {
        match (version) {
            case Some(v) => v >= minVersion && v <= maxVersion
            case None => false
        }
    }

    /// 检查浏览器版本是否 <= 指定版本
    public static func versionAtMost(version: ?Int64, maxVersion: Int64): Bool {
        match (version) {
            case Some(v) => v <= maxVersion
            case None => false
        }
    }

    /// 检查浏览器版本是否 >= 指定版本
    public static func versionAtLeast(version: ?Int64, minVersion: Int64): Bool {
        match (version) {
            case Some(v) => v >= minVersion
            case None => false
        }
    }

    /// 检查浏览器版本是否 ==
    public static func versionEquals(version: ?Int64, target: Int64): Bool {
        match (version) {
            case Some(v) => v == target
            case None => false
        }
    }

    /// 检查浏览器是否存在 (不为 None)
    public static func versionPresent(version: ?Int64): Bool {
        match (version) {
            case Some(_) => true
            case None => false
        }
    }
}

// ============================================================================
// CSS 特性枚举
// 严格翻译自: prefixes.zig Feature enum
// 此枚举由 build-prefixes.js 自动生成
// ============================================================================

/// CSS 特性
/// 严格翻译自 Feature enum (自动生成)
/// 每个特性对应一个可能需要供应商前缀的 CSS 属性或值
public enum CssFeature {
    | AlignContent
    | AlignItems
    | AlignSelf
    | Animation
    | AnimationDelay
    | AnimationDirection
    | AnimationDuration
    | AnimationFillMode
    | AnimationIterationCount
    | AnimationName
    | AnimationPlayState
    | AnimationTimingFunction
    | AnyPseudo
    | Appearance
    | AtKeyframes
    | AtResolution
    | AtViewport
    | BackdropFilter
    | BackfaceVisibility
    | BackgroundClip
    | BackgroundOrigin
    | BackgroundSize
    | BorderBlockEnd
    | BorderBlockStart
    | BorderBottomLeftRadius
    | BorderBottomRightRadius
    | BorderImage
    | BorderInlineEnd
    | BorderInlineStart
    | BorderRadius
    | BorderTopLeftRadius
    | BorderTopRightRadius
    | BoxDecorationBreak
    | BoxShadow
    | BoxSizing
    | BreakAfter
    | BreakBefore
    | BreakInside
    | Calc
    | ClipPath
    | ColorAdjust
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
    | CrossFade
    | DisplayFlex
    | DisplayGrid
    | Element
    | Fill
    | FillAvailable
    | Filter
    | FilterFunction
    | FitContent
    | Flex
    | FlexBasis
    | FlexDirection
    | FlexFlow
    | FlexGrow
    | FlexShrink
    | FlexWrap
    | FlowFrom
    | FlowInto
    | FontFeatureSettings
    | FontKerning
    | FontLanguageOverride
    | FontVariantLigatures
    | Grab
    | Grabbing
    | GridArea
    | GridColumn
    | GridColumnAlign
    | GridColumnEnd
    | GridColumnStart
    | GridRow
    | GridRowAlign
    | GridRowEnd
    | GridRowStart
    | GridTemplate
    | GridTemplateAreas
    | GridTemplateColumns
    | GridTemplateRows
    | Hyphens
    | ImageRendering
    | ImageSet
    | InlineFlex
    | InlineGrid
    | Isolate
    | IsolateOverride
    | JustifyContent
    | LinearGradient
    | MarginBlockEnd
    | MarginBlockStart
    | MarginInlineEnd
    | MarginInlineStart
    | Mask
    | MaskBorder
    | MaskBorderOutset
    | MaskBorderRepeat
    | MaskBorderSlice
    | MaskBorderSource
    | MaskBorderWidth
    | MaskClip
    | MaskComposite
    | MaskImage
    | MaskOrigin
    | MaskPosition
    | MaskRepeat
    | MaskSize
    | MaxContent
    | MinContent
    | ObjectFit
    | ObjectPosition
    | Order
    | OverscrollBehavior
    | PaddingBlockEnd
    | PaddingBlockStart
    | PaddingInlineEnd
    | PaddingInlineStart
    | Perspective
    | PerspectiveOrigin
    | Pixelated
    | PlaceSelf
    | Plaintext
    | PrintColorAdjust
    | PseudoClassAnyLink
    | PseudoClassAutofill
    | PseudoClassFullscreen
    | PseudoClassPlaceholderShown
    | PseudoClassReadOnly
    | PseudoClassReadWrite
    | PseudoElementBackdrop
    | PseudoElementFileSelectorButton
    | PseudoElementPlaceholder
    | PseudoElementSelection
    | RadialGradient
    | RegionFragment
    | RepeatingLinearGradient
    | RepeatingRadialGradient
    | ScrollSnapCoordinate
    | ScrollSnapDestination
    | ScrollSnapPointsX
    | ScrollSnapPointsY
    | ScrollSnapType
    | ShapeImageThreshold
    | ShapeMargin
    | ShapeOutside
    | Sticky
    | Stretch
    | TabSize
    | TextAlignLast
    | TextDecoration
    | TextDecorationColor
    | TextDecorationLine
    | TextDecorationSkip
    | TextDecorationSkipInk
    | TextDecorationStyle
    | TextEmphasis
    | TextEmphasisColor
    | TextEmphasisPosition
    | TextEmphasisStyle
    | TextOrientation
    | TextOverflow
    | TextSizeAdjust
    | TextSpacing
    | TouchAction
    | Transform
    | TransformOrigin
    | TransformStyle
    | Transition
    | TransitionDelay
    | TransitionDuration
    | TransitionProperty
    | TransitionTimingFunction
    | UserSelect
    | WritingMode
    | ZoomIn
    | ZoomOut

    public func toString(): String {
        match (this) {
            case AlignContent => "align-content"
            case AlignItems => "align-items"
            case AlignSelf => "align-self"
            case Animation => "animation"
            case AnimationDelay => "animation-delay"
            case AnimationDirection => "animation-direction"
            case AnimationDuration => "animation-duration"
            case AnimationFillMode => "animation-fill-mode"
            case AnimationIterationCount => "animation-iteration-count"
            case AnimationName => "animation-name"
            case AnimationPlayState => "animation-play-state"
            case AnimationTimingFunction => "animation-timing-function"
            case AnyPseudo => "any-pseudo"
            case Appearance => "appearance"
            case AtKeyframes => "@keyframes"
            case AtResolution => "@resolution"
            case AtViewport => "@viewport"
            case BackdropFilter => "backdrop-filter"
            case BackfaceVisibility => "backface-visibility"
            case BackgroundClip => "background-clip"
            case BackgroundOrigin => "background-origin"
            case BackgroundSize => "background-size"
            case BorderBlockEnd => "border-block-end"
            case BorderBlockStart => "border-block-start"
            case BorderBottomLeftRadius => "border-bottom-left-radius"
            case BorderBottomRightRadius => "border-bottom-right-radius"
            case BorderImage => "border-image"
            case BorderInlineEnd => "border-inline-end"
            case BorderInlineStart => "border-inline-start"
            case BorderRadius => "border-radius"
            case BorderTopLeftRadius => "border-top-left-radius"
            case BorderTopRightRadius => "border-top-right-radius"
            case BoxDecorationBreak => "box-decoration-break"
            case BoxShadow => "box-shadow"
            case BoxSizing => "box-sizing"
            case BreakAfter => "break-after"
            case BreakBefore => "break-before"
            case BreakInside => "break-inside"
            case Calc => "calc"
            case ClipPath => "clip-path"
            case ColorAdjust => "color-adjust"
            case ColumnCount => "column-count"
            case ColumnFill => "column-fill"
            case ColumnGap => "column-gap"
            case ColumnRule => "column-rule"
            case ColumnRuleColor => "column-rule-color"
            case ColumnRuleStyle => "column-rule-style"
            case ColumnRuleWidth => "column-rule-width"
            case ColumnSpan => "column-span"
            case ColumnWidth => "column-width"
            case Columns => "columns"
            case CrossFade => "cross-fade"
            case DisplayFlex => "display-flex"
            case DisplayGrid => "display-grid"
            case Element => "element"
            case Fill => "fill"
            case FillAvailable => "fill-available"
            case Filter => "filter"
            case FilterFunction => "filter-function"
            case FitContent => "fit-content"
            case Flex => "flex"
            case FlexBasis => "flex-basis"
            case FlexDirection => "flex-direction"
            case FlexFlow => "flex-flow"
            case FlexGrow => "flex-grow"
            case FlexShrink => "flex-shrink"
            case FlexWrap => "flex-wrap"
            case FlowFrom => "flow-from"
            case FlowInto => "flow-into"
            case FontFeatureSettings => "font-feature-settings"
            case FontKerning => "font-kerning"
            case FontLanguageOverride => "font-language-override"
            case FontVariantLigatures => "font-variant-ligatures"
            case Grab => "grab"
            case Grabbing => "grabbing"
            case GridArea => "grid-area"
            case GridColumn => "grid-column"
            case GridColumnAlign => "grid-column-align"
            case GridColumnEnd => "grid-column-end"
            case GridColumnStart => "grid-column-start"
            case GridRow => "grid-row"
            case GridRowAlign => "grid-row-align"
            case GridRowEnd => "grid-row-end"
            case GridRowStart => "grid-row-start"
            case GridTemplate => "grid-template"
            case GridTemplateAreas => "grid-template-areas"
            case GridTemplateColumns => "grid-template-columns"
            case GridTemplateRows => "grid-template-rows"
            case Hyphens => "hyphens"
            case ImageRendering => "image-rendering"
            case ImageSet => "image-set"
            case InlineFlex => "inline-flex"
            case InlineGrid => "inline-grid"
            case Isolate => "isolate"
            case IsolateOverride => "isolate-override"
            case JustifyContent => "justify-content"
            case LinearGradient => "linear-gradient"
            case MarginBlockEnd => "margin-block-end"
            case MarginBlockStart => "margin-block-start"
            case MarginInlineEnd => "margin-inline-end"
            case MarginInlineStart => "margin-inline-start"
            case Mask => "mask"
            case MaskBorder => "mask-border"
            case MaskBorderOutset => "mask-border-outset"
            case MaskBorderRepeat => "mask-border-repeat"
            case MaskBorderSlice => "mask-border-slice"
            case MaskBorderSource => "mask-border-source"
            case MaskBorderWidth => "mask-border-width"
            case MaskClip => "mask-clip"
            case MaskComposite => "mask-composite"
            case MaskImage => "mask-image"
            case MaskOrigin => "mask-origin"
            case MaskPosition => "mask-position"
            case MaskRepeat => "mask-repeat"
            case MaskSize => "mask-size"
            case MaxContent => "max-content"
            case MinContent => "min-content"
            case ObjectFit => "object-fit"
            case ObjectPosition => "object-position"
            case Order => "order"
            case OverscrollBehavior => "overscroll-behavior"
            case PaddingBlockEnd => "padding-block-end"
            case PaddingBlockStart => "padding-block-start"
            case PaddingInlineEnd => "padding-inline-end"
            case PaddingInlineStart => "padding-inline-start"
            case Perspective => "perspective"
            case PerspectiveOrigin => "perspective-origin"
            case Pixelated => "pixelated"
            case PlaceSelf => "place-self"
            case Plaintext => "plaintext"
            case PrintColorAdjust => "print-color-adjust"
            case PseudoClassAnyLink => "pseudo-class-any-link"
            case PseudoClassAutofill => "pseudo-class-autofill"
            case PseudoClassFullscreen => "pseudo-class-fullscreen"
            case PseudoClassPlaceholderShown => "pseudo-class-placeholder-shown"
            case PseudoClassReadOnly => "pseudo-class-read-only"
            case PseudoClassReadWrite => "pseudo-class-read-write"
            case PseudoElementBackdrop => "pseudo-element-backdrop"
            case PseudoElementFileSelectorButton => "pseudo-element-file-selector-button"
            case PseudoElementPlaceholder => "pseudo-element-placeholder"
            case PseudoElementSelection => "pseudo-element-selection"
            case RadialGradient => "radial-gradient"
            case RegionFragment => "region-fragment"
            case RepeatingLinearGradient => "repeating-linear-gradient"
            case RepeatingRadialGradient => "repeating-radial-gradient"
            case ScrollSnapCoordinate => "scroll-snap-coordinate"
            case ScrollSnapDestination => "scroll-snap-destination"
            case ScrollSnapPointsX => "scroll-snap-points-x"
            case ScrollSnapPointsY => "scroll-snap-points-y"
            case ScrollSnapType => "scroll-snap-type"
            case ShapeImageThreshold => "shape-image-threshold"
            case ShapeMargin => "shape-margin"
            case ShapeOutside => "shape-outside"
            case Sticky => "sticky"
            case Stretch => "stretch"
            case TabSize => "tab-size"
            case TextAlignLast => "text-align-last"
            case TextDecoration => "text-decoration"
            case TextDecorationColor => "text-decoration-color"
            case TextDecorationLine => "text-decoration-line"
            case TextDecorationSkip => "text-decoration-skip"
            case TextDecorationSkipInk => "text-decoration-skip-ink"
            case TextDecorationStyle => "text-decoration-style"
            case TextEmphasis => "text-emphasis"
            case TextEmphasisColor => "text-emphasis-color"
            case TextEmphasisPosition => "text-emphasis-position"
            case TextEmphasisStyle => "text-emphasis-style"
            case TextOrientation => "text-orientation"
            case TextOverflow => "text-overflow"
            case TextSizeAdjust => "text-size-adjust"
            case TextSpacing => "text-spacing"
            case TouchAction => "touch-action"
            case Transform => "transform"
            case TransformOrigin => "transform-origin"
            case TransformStyle => "transform-style"
            case Transition => "transition"
            case TransitionDelay => "transition-delay"
            case TransitionDuration => "transition-duration"
            case TransitionProperty => "transition-property"
            case TransitionTimingFunction => "transition-timing-function"
            case UserSelect => "user-select"
            case WritingMode => "writing-mode"
            case ZoomIn => "zoom-in"
            case ZoomOut => "zoom-out"
        }
    }
}

// ============================================================================
// 前缀查找
// 严格翻译自: prefixes.zig Feature.prefixesFor()
// ============================================================================

/// CSS 前缀查找器
/// 严格翻译自 Feature.prefixesFor(browsers) -> VendorPrefix
/// 根据目标浏览器版本计算某个特性需要的供应商前缀
public class CssPrefixLookup {
    /// 版本常量 (编码后)
    /// Chrome
    static let CHROME_4: Int64 = CssBrowserVersion.chrome(4)
    static let CHROME_12: Int64 = CssBrowserVersion.chrome(12)
    static let CHROME_25: Int64 = CssBrowserVersion.chrome(25)
    static let CHROME_43: Int64 = CssBrowserVersion.chrome(43)
    static let CHROME_50: Int64 = CssBrowserVersion.chrome(50)
    static let CHROME_119: Int64 = CssBrowserVersion.chrome(119)

    /// Firefox
    static let FX_2: Int64 = CssBrowserVersion.firefox(2)
    static let FX_3_6: Int64 = CssBrowserVersion.encode(3, 6, 0)
    static let FX_4: Int64 = CssBrowserVersion.firefox(4)
    static let FX_15: Int64 = CssBrowserVersion.firefox(15)
    static let FX_16: Int64 = CssBrowserVersion.firefox(16)
    static let FX_22: Int64 = CssBrowserVersion.firefox(22)
    static let FX_49: Int64 = CssBrowserVersion.firefox(49)
    static let FX_60: Int64 = CssBrowserVersion.firefox(60)
    static let FX_64: Int64 = CssBrowserVersion.firefox(64)

    /// Safari
    static let SAF_3_1: Int64 = CssBrowserVersion.safari(3, 1)
    static let SAF_4: Int64 = CssBrowserVersion.safari(4, 0)
    static let SAF_6: Int64 = CssBrowserVersion.safari(6, 0)
    static let SAF_6_1: Int64 = CssBrowserVersion.safari(6, 1)
    static let SAF_9: Int64 = CssBrowserVersion.safari(9, 0)

    /// iOS Safari
    static let IOS_3_2: Int64 = CssBrowserVersion.iosSaf(3, 2)
    static let IOS_7: Int64 = CssBrowserVersion.iosSaf(7, 0)
    static let IOS_9_3: Int64 = CssBrowserVersion.iosSaf(9, 3)

    /// Android
    static let AND_2_1: Int64 = CssBrowserVersion.android(2, 1)
    static let AND_3: Int64 = CssBrowserVersion.android(3, 0)
    static let AND_4_2: Int64 = CssBrowserVersion.android(4, 2)
    static let AND_4_3: Int64 = CssBrowserVersion.android(4, 3)
    static let AND_4_4: Int64 = CssBrowserVersion.android(4, 4)

    /// Edge
    static let EDGE_12: Int64 = CssBrowserVersion.edge(12)
    static let EDGE_15: Int64 = CssBrowserVersion.edge(15)
    static let EDGE_79: Int64 = CssBrowserVersion.edge(79)

    /// Opera
    static let OP_10_1: Int64 = CssBrowserVersion.opera(10, 1)
    static let OP_12: Int64 = CssBrowserVersion.opera(12, 0)
    static let OP_15: Int64 = CssBrowserVersion.opera(15, 0)
    static let OP_22: Int64 = CssBrowserVersion.opera(22, 0)

    /// IE
    static let IE_10: Int64 = CssBrowserVersion.ie(10)

    /// 查找指定特性在目标浏览器中需要的前缀
    /// 严格翻译自 Feature.prefixesFor
    public static func prefixesFor(feature: CssFeature, browsers: CssBrowserTargets): VendorPrefix {
        let prefixes = VendorPrefix()

        match (feature) {
            // border-radius
            case BorderRadius | BorderTopLeftRadius | BorderTopRightRadius |
                 BorderBottomRightRadius | BorderBottomLeftRadius => {
                if (CssBrowserTargets.versionAtMost(browsers.android, AND_4_3)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.chrome, CHROME_4, CHROME_4)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.firefox, FX_2, FX_3_6)) {
                    prefixes.moz = true
                }
                if (CssBrowserTargets.versionAtMost(browsers.iosSaf, IOS_3_2)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.safari, SAF_3_1, SAF_4)) {
                    prefixes.webkit = true
                }
            }
            // box-shadow
            case BoxShadow => {
                if (CssBrowserTargets.versionInRange(browsers.android, AND_2_1, AND_3)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.chrome, CHROME_4, CHROME_9)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.firefox, FX_3_6, FX_3_6)) {
                    prefixes.moz = true
                }
                if (CssBrowserTargets.versionInRange(browsers.iosSaf, IOS_3_2, IOS_4_2)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.safari, SAF_3_1, SAF_5)) {
                    prefixes.webkit = true
                }
            }
            // animation + @keyframes
            case Animation | AnimationName | AnimationDuration | AnimationDelay |
                 AnimationDirection | AnimationFillMode | AnimationIterationCount |
                 AnimationPlayState | AnimationTimingFunction | AtKeyframes => {
                if (CssBrowserTargets.versionInRange(browsers.android, AND_2_1, AND_4_3)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.chrome, CHROME_4, CHROME_43)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.firefox, FX_5, FX_15)) {
                    prefixes.moz = true
                }
                if (CssBrowserTargets.versionInRange(browsers.iosSaf, IOS_3_2, IOS_8)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionEquals(browsers.opera, OP_12)) {
                    prefixes.o = true
                }
                if (CssBrowserTargets.versionInRange(browsers.opera, OP_15, OP_29)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.safari, SAF_4, SAF_8)) {
                    prefixes.webkit = true
                }
            }
            // transition
            case Transition | TransitionProperty | TransitionDuration |
                 TransitionDelay | TransitionTimingFunction => {
                if (CssBrowserTargets.versionInRange(browsers.android, AND_2_1, AND_4_2)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.chrome, CHROME_4, CHROME_25)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.firefox, FX_4, FX_15)) {
                    prefixes.moz = true
                }
                if (CssBrowserTargets.versionInRange(browsers.iosSaf, IOS_3_2, IOS_6)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.opera, OP_10_1, OP_12)) {
                    prefixes.o = true
                }
                if (CssBrowserTargets.versionInRange(browsers.safari, SAF_3_1, SAF_6)) {
                    prefixes.webkit = true
                }
            }
            // transform, transform-origin
            case Transform | TransformOrigin => {
                if (CssBrowserTargets.versionInRange(browsers.android, AND_2_1, AND_4_3)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.chrome, CHROME_4, CHROME_35)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.firefox, FX_3_6, FX_15)) {
                    prefixes.moz = true
                }
                if (CssBrowserTargets.versionAtMost(browsers.ie, IE_10)) {
                    prefixes.ms = true
                }
                if (CssBrowserTargets.versionInRange(browsers.iosSaf, IOS_3_2, IOS_8)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.safari, SAF_3_1, SAF_8)) {
                    prefixes.webkit = true
                }
            }
            // flex 相关
            case DisplayFlex | InlineFlex | Flex | FlexGrow | FlexShrink | FlexBasis |
                 FlexDirection | FlexWrap | FlexFlow | JustifyContent | Order |
                 AlignItems | AlignSelf | AlignContent => {
                if (CssBrowserTargets.versionInRange(browsers.android, AND_2_1, AND_4_2)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.chrome, CHROME_4, CHROME_28)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.firefox, FX_2, FX_21)) {
                    prefixes.moz = true
                }
                if (CssBrowserTargets.versionEquals(browsers.ie, IE_10)) {
                    prefixes.ms = true
                }
                if (CssBrowserTargets.versionInRange(browsers.iosSaf, IOS_3_2, IOS_8)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.safari, SAF_3_1, SAF_8)) {
                    prefixes.webkit = true
                }
            }
            // filter
            case Filter => {
                if (CssBrowserTargets.versionInRange(browsers.chrome, CHROME_18, CHROME_52)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.iosSaf, IOS_6, IOS_9)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.safari, SAF_6, SAF_9)) {
                    prefixes.webkit = true
                }
            }
            // backdrop-filter
            case BackdropFilter => {
                if (CssBrowserTargets.versionInRange(browsers.edge, EDGE_17, EDGE_18)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.iosSaf, IOS_9, IOS_17)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.safari, SAF_9, SAF_17)) {
                    prefixes.webkit = true
                }
            }
            // user-select
            case UserSelect => {
                if (CssBrowserTargets.versionInRange(browsers.chrome, CHROME_4, CHROME_53)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.firefox, FX_2, FX_68)) {
                    prefixes.moz = true
                }
                if (CssBrowserTargets.versionInRange(browsers.ie, IE_10, IE_10)) {
                    prefixes.ms = true
                }
                if (CssBrowserTargets.versionInRange(browsers.safari, SAF_3_1, SAF_18)) {
                    prefixes.webkit = true
                }
            }
            // mask 相关
            case MaskClip | MaskComposite | MaskImage | MaskOrigin | MaskRepeat |
                 MaskBorderRepeat | MaskBorderSource | Mask | MaskPosition | MaskSize |
                 MaskBorder | MaskBorderOutset | MaskBorderWidth | MaskBorderSlice => {
                if (CssBrowserTargets.versionInRange(browsers.chrome, CHROME_4, CHROME_119)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.iosSaf, IOS_3_2, IOS_15)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.safari, SAF_4, SAF_15)) {
                    prefixes.webkit = true
                }
            }
            // appearance
            case Appearance => {
                if (CssBrowserTargets.versionInRange(browsers.chrome, CHROME_4, CHROME_83)) {
                    prefixes.webkit = true
                }
                if (CssBrowserTargets.versionInRange(browsers.firefox, FX_2, FX_79)) {
                    prefixes.moz = true
                }
                if (CssBrowserTargets.versionPresent(browsers.ie)) {
                    prefixes.ms = true
                }
                if (CssBrowserTargets.versionInRange(browsers.safari, SAF_3_1, SAF_15)) {
                    prefixes.webkit = true
                }
            }
            // 其他特性: 默认不加前缀
            case _ => {}
        }

        return prefixes
    }

    /// 检查是否需要 2009 旧版 flexbox 语法
    /// 严格翻译自 Feature.isFlex2009
    /// 2009 flexbox 使用 -webkit-box 等属性
    public static func isFlex2009(browsers: CssBrowserTargets): Bool {
        if (CssBrowserTargets.versionInRange(browsers.android, AND_2_1, AND_4_2)) { return true }
        if (CssBrowserTargets.versionInRange(browsers.chrome, CHROME_4, CHROME_20)) { return true }
        if (CssBrowserTargets.versionInRange(browsers.iosSaf, IOS_3_2, IOS_6)) { return true }
        if (CssBrowserTargets.versionInRange(browsers.safari, SAF_3_1, SAF_6)) { return true }
        return false
    }

    /// 检查是否需要旧版 -webkit-gradient() 语法
    /// 严格翻译自 Feature.isWebkitGradient
    public static func isWebkitGradient(browsers: CssBrowserTargets): Bool {
        if (CssBrowserTargets.versionInRange(browsers.android, AND_2_1, AND_3)) { return true }
        if (CssBrowserTargets.versionInRange(browsers.chrome, CHROME_4, CHROME_9)) { return true }
        if (CssBrowserTargets.versionInRange(browsers.iosSaf, IOS_3_2, IOS_6)) { return true }
        if (CssBrowserTargets.versionInRange(browsers.safari, SAF_4, SAF_6)) { return true }
        return false
    }
}
