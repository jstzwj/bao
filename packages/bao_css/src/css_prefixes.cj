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
package bao_css

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

    public operator func ==(right: CssFeature): Bool {
        this.toString() == right.toString()
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

    /// 查找指定特性在目标浏览器中需要的前缀 (CssBrowsers 重载)
    public static func prefixesFor(feature: CssFeature, browsers: CssBrowsers): VendorPrefix {
        let targets = CssBrowserTargets()
        targets.chrome = browsers.chrome.map { v => Int64(v) }
        targets.firefox = browsers.firefox.map { v => Int64(v) }
        targets.safari = browsers.safari.map { v => Int64(v) }
        targets.edge = browsers.edge.map { v => Int64(v) }
        targets.ie = browsers.ie.map { v => Int64(v) }
        targets.opera = browsers.opera.map { v => Int64(v) }
        targets.iosSaf = browsers.ios_saf.map { v => Int64(v) }
        targets.android = browsers.android.map { v => Int64(v) }
        targets.samsung = browsers.samsung.map { v => Int64(v) }
        prefixesFor(feature, targets)
    }

    /// 查找指定特性在目标浏览器中需要的前缀
    /// 严格翻译自 Feature.prefixesFor
    public static func prefixesFor(feature: CssFeature, browsers: CssBrowserTargets): VendorPrefix {
        var prefixes = VendorPrefix()
        prefixes.none = true

        // border_radius 组
        if (matchFeatureBorderRadius(feature)) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 263168)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 262144)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 131072, 198144)) { prefixes.moz = true }
            if (CssBrowserTargets.versionAtMost(browsers.iosSaf, 197120)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 262144)) { prefixes.webkit = true }
            return prefixes
        }

        // box_shadow
        if (feature == CssFeature.BoxShadow) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 196608)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 589824)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 197888, 198144)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 262656)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 327680)) { prefixes.webkit = true }
            return prefixes
        }

        // animation 组 (含 at_keyframes)
        if (matchFeatureAnimation(feature)) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 2752512)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 327680, 983040)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 524544)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionEquals(browsers.opera, 786432)) { prefixes.o = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 1900544)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 262144, 524288)) { prefixes.webkit = true }
            return prefixes
        }

        // transition 组
        if (matchFeatureTransition(feature)) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 262656)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 1638400)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 262144, 983040)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 393216)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 655360, 786432)) { prefixes.o = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 393216)) { prefixes.webkit = true }
            return prefixes
        }

        // transform / transform_origin
        if (feature == CssFeature.Transform || feature == CssFeature.TransformOrigin) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 2293760)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 197888, 983040)) { prefixes.moz = true }
            if (CssBrowserTargets.versionAtMost(browsers.ie, 589824)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 524544)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 656640, 786432)) { prefixes.o = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 1441792)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 524288)) { prefixes.webkit = true }
            return prefixes
        }

        // perspective / perspective_origin / transform_style
        if (feature == CssFeature.Perspective || feature == CssFeature.PerspectiveOrigin || feature == CssFeature.TransformStyle) {
            if (CssBrowserTargets.versionInRange(browsers.android, 196608, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 786432, 2293760)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 655360, 983040)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 524544)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 1441792)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 262144, 524288)) { prefixes.webkit = true }
            return prefixes
        }

        // backface_visibility
        if (feature == CssFeature.BackfaceVisibility) {
            if (CssBrowserTargets.versionInRange(browsers.android, 196608, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 786432, 2293760)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 655360, 983040)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 983552)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 1441792)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 262144, 983552)) { prefixes.webkit = true }
            return prefixes
        }

        // gradients 组
        if (feature == CssFeature.LinearGradient || feature == CssFeature.RepeatingLinearGradient ||
            feature == CssFeature.RadialGradient || feature == CssFeature.RepeatingRadialGradient) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 262656)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 1638400)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 198144, 983040)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 393216)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 721152, 786432)) { prefixes.o = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 262144, 393216)) { prefixes.webkit = true }
            return prefixes
        }

        // box_sizing
        if (feature == CssFeature.BoxSizing) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 196608)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 589824)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 131072, 1835008)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 262656)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 327680)) { prefixes.webkit = true }
            return prefixes
        }

        // filter
        if (feature == CssFeature.Filter) {
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1179648, 3407872)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 393216, 589824)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 2555904)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 393216, 589824)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 393728)) { prefixes.webkit = true }
            return prefixes
        }

        // filter_function
        if (feature == CssFeature.FilterFunction) {
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 589824, 590592)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtMost(browsers.safari, 589824)) { prefixes.webkit = true }
            return prefixes
        }

        // backdrop_filter
        if (feature == CssFeature.BackdropFilter) {
            if (CssBrowserTargets.versionInRange(browsers.edge, 1114112, 1179648)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 589824, 1115648)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 589824, 1115648)) { prefixes.webkit = true }
            return prefixes
        }

        // element
        if (feature == CssFeature.Element) {
            if (CssBrowserTargets.versionInRange(browsers.firefox, 131072, 8650752)) { prefixes.moz = true }
            return prefixes
        }

        // columns 组
        if (feature == CssFeature.Columns || feature == CssFeature.ColumnWidth ||
            feature == CssFeature.ColumnGap || feature == CssFeature.ColumnRule ||
            feature == CssFeature.ColumnRuleColor || feature == CssFeature.ColumnRuleWidth ||
            feature == CssFeature.ColumnCount || feature == CssFeature.ColumnRuleStyle ||
            feature == CssFeature.ColumnSpan || feature == CssFeature.ColumnFill) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 3211264)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 131072, 3342336)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 524544)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 2359296)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 524288)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtMost(browsers.samsung, 262144)) { prefixes.webkit = true }
            return prefixes
        }

        // break 组
        if (feature == CssFeature.BreakBefore || feature == CssFeature.BreakAfter || feature == CssFeature.BreakInside) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 3211264)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 524544)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 2359296)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 524288)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtMost(browsers.samsung, 262144)) { prefixes.webkit = true }
            return prefixes
        }

        // user_select
        if (feature == CssFeature.UserSelect) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 3473408)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 786432, 1179648)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 131072, 4456448)) { prefixes.moz = true }
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 655360)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 1179648)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 2621440)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 1179648)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 327680)) { prefixes.webkit = true }
            return prefixes
        }

        // flex 组
        if (matchFeatureFlex(feature)) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 262656)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 1835008)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 131072, 1376256)) { prefixes.moz = true }
            if (CssBrowserTargets.versionEquals(browsers.ie, 655360)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 524544)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 1048576)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 524288)) { prefixes.webkit = true }
            return prefixes
        }

        // calc
        if (feature == CssFeature.Calc) {
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1245184, 1638400)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 262144, 983040)) { prefixes.moz = true }
            if (CssBrowserTargets.versionAtMost(browsers.iosSaf, 393216)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtMost(browsers.safari, 393216)) { prefixes.webkit = true }
            return prefixes
        }

        // background_origin / background_size
        if (feature == CssFeature.BackgroundOrigin || feature == CssFeature.BackgroundSize) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 131840)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtMost(browsers.firefox, 198144)) { prefixes.moz = true }
            if (CssBrowserTargets.versionAtMost(browsers.opera, 655360)) { prefixes.o = true }
            return prefixes
        }

        // background_clip
        if (feature == CssFeature.BackgroundClip) {
            if (CssBrowserTargets.versionInRange(browsers.android, 262144, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 7798784)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 786432, 917504)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 5177344, 7798784)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 393216, 852992)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 6881280)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 262144, 852224)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 1572864)) { prefixes.webkit = true }
            return prefixes
        }

        // font_feature_settings 组
        if (feature == CssFeature.FontFeatureSettings || feature == CssFeature.FontVariantLigatures ||
            feature == CssFeature.FontLanguageOverride) {
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1048576, 3080192)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 262144, 2162688)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 2228224)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtMost(browsers.samsung, 262144)) { prefixes.webkit = true }
            return prefixes
        }

        // font_kerning
        if (feature == CssFeature.FontKerning) {
            if (CssBrowserTargets.versionAtMost(browsers.android, 263168)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1900544, 2097152)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 524288, 721664)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 1048576, 1245184)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 458752, 589824)) { prefixes.webkit = true }
            return prefixes
        }

        // border_image
        if (feature == CssFeature.BorderImage) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 262656)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 917504)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 197888, 917504)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 327680)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 720896, 786688)) { prefixes.o = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 327936)) { prefixes.webkit = true }
            return prefixes
        }

        // pseudo_element_selection
        if (feature == CssFeature.PseudoElementSelection) {
            if (CssBrowserTargets.versionInRange(browsers.firefox, 131072, 3997696)) { prefixes.moz = true }
            return prefixes
        }

        // pseudo_element_placeholder
        if (feature == CssFeature.PseudoElementPlaceholder) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 3670016)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 786432, 1179648)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 1179648, 3276800)) { prefixes.moz = true }
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 655360)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 262656, 655360)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 2818048)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 327680, 655360)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 393728)) { prefixes.webkit = true }
            return prefixes
        }

        // pseudo_class_placeholder_shown
        if (feature == CssFeature.PseudoClassPlaceholderShown) {
            if (CssBrowserTargets.versionInRange(browsers.firefox, 262144, 3276800)) { prefixes.moz = true }
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 655360)) { prefixes.ms = true }
            return prefixes
        }

        // hyphens
        if (feature == CssFeature.Hyphens) {
            if (CssBrowserTargets.versionInRange(browsers.edge, 786432, 1179648)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 393216, 2752512)) { prefixes.moz = true }
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 655360)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 262656, 1050112)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 327936, 1050112)) { prefixes.webkit = true }
            return prefixes
        }

        // pseudo_class_fullscreen
        if (feature == CssFeature.PseudoClassFullscreen) {
            if (CssBrowserTargets.versionInRange(browsers.chrome, 983040, 4587520)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 655360, 4128768)) { prefixes.moz = true }
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 720896)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 4128768)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 327936, 1049344)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 590336)) { prefixes.webkit = true }
            return prefixes
        }

        // pseudo_element_backdrop
        if (feature == CssFeature.PseudoElementBackdrop) {
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 2097152, 2359296)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 786432, 1179648)) { prefixes.ms = true }
            if (CssBrowserTargets.versionPresent(browsers.ie)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 1245184, 1507328)) { prefixes.webkit = true }
            return prefixes
        }

        // pseudo_element_file_selector_button
        if (feature == CssFeature.PseudoElementFileSelectorButton) {
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 5767168)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 786432, 1179648)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 5177344, 5767168)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 655360)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 917504)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 4849664)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 917504)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 917504)) { prefixes.webkit = true }
            return prefixes
        }

        // pseudo_class_autofill
        if (feature == CssFeature.PseudoClassAutofill) {
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 7143424)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 5177344, 7143424)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 918784)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 6225920)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 917760)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 1310720)) { prefixes.webkit = true }
            return prefixes
        }

        // tab_size
        if (feature == CssFeature.TabSize) {
            if (CssBrowserTargets.versionInRange(browsers.firefox, 262144, 5898240)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 656896, 786688)) { prefixes.o = true }
            return prefixes
        }

        // max_content / min_content
        if (feature == CssFeature.MaxContent || feature == CssFeature.MinContent) {
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1441792, 2949120)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 196608, 4259840)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 458752, 852992)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 2097152)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 393472, 655616)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtMost(browsers.samsung, 262144)) { prefixes.webkit = true }
            return prefixes
        }

        // fill / fill_available
        if (feature == CssFeature.Fill || feature == CssFeature.FillAvailable) {
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1441792, 8519680)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 8323072)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 5177344, 8323072)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 196608, 4259840)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 458752, 852992)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtLeast(browsers.opera, 983040)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 393472, 655616)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 1638400)) { prefixes.webkit = true }
            return prefixes
        }

        // fit_content
        if (feature == CssFeature.FitContent) {
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1441792, 2949120)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 196608, 6094848)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 458752, 852992)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 2097152)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 393472, 655616)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtMost(browsers.samsung, 262144)) { prefixes.webkit = true }
            return prefixes
        }

        // stretch
        if (feature == CssFeature.Stretch) {
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1441792, 8519680)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 196608, 8650752)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 8323072)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 5177344, 8323072)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 458752, 1179648)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtLeast(browsers.opera, 983040)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 458752, 1179648)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 327680, 1638400)) { prefixes.webkit = true }
            return prefixes
        }

        // zoom_in / zoom_out
        if (feature == CssFeature.ZoomIn || feature == CssFeature.ZoomOut) {
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 2359296)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 131072, 1507328)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 1507328)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 524288)) { prefixes.webkit = true }
            return prefixes
        }

        // grab / grabbing
        if (feature == CssFeature.Grab || feature == CssFeature.Grabbing) {
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 4390912)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 131072, 1703936)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 3538944)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 655616)) { prefixes.webkit = true }
            return prefixes
        }

        // sticky
        if (feature == CssFeature.Sticky) {
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 393216, 786944)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 393472, 786688)) { prefixes.webkit = true }
            return prefixes
        }

        // touch_action
        if (feature == CssFeature.TouchAction) {
            if (CssBrowserTargets.versionEquals(browsers.ie, 655360)) { prefixes.ms = true }
            return prefixes
        }

        // text_decoration_skip / text_decoration_skip_ink
        if (feature == CssFeature.TextDecorationSkip || feature == CssFeature.TextDecorationSkipInk) {
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 524288, 1179648)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 459008, 786432)) { prefixes.webkit = true }
            return prefixes
        }

        // text_decoration
        if (feature == CssFeature.TextDecoration) {
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 524288, 1179648)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 524288, 1179648)) { prefixes.webkit = true }
            return prefixes
        }

        // text_decoration_color / text_decoration_line / text_decoration_style
        if (feature == CssFeature.TextDecorationColor || feature == CssFeature.TextDecorationLine ||
            feature == CssFeature.TextDecorationStyle) {
            if (CssBrowserTargets.versionInRange(browsers.firefox, 393216, 2293760)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 524288, 786432)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 524288, 786432)) { prefixes.webkit = true }
            return prefixes
        }

        // text_size_adjust
        if (feature == CssFeature.TextSizeAdjust) {
            if (CssBrowserTargets.versionAtMost(browsers.firefox, 8323072)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 786432, 1179648)) { prefixes.ms = true }
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 655360)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 327680, 1179648)) { prefixes.webkit = true }
            return prefixes
        }

        // mask 组
        if (matchFeatureMask(feature)) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 7798784)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 5177344, 7798784)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 983552)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 6881280)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 262144, 983552)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 1572864)) { prefixes.webkit = true }
            return prefixes
        }

        // clip_path
        if (feature == CssFeature.ClipPath) {
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1572864, 3538944)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 458752, 589824)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 2686976)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 458752, 589824)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 327680)) { prefixes.webkit = true }
            return prefixes
        }

        // box_decoration_break
        if (feature == CssFeature.BoxDecorationBreak) {
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1441792, 8519680)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 8323072)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 5177344, 8323072)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 458752, 1179648)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtLeast(browsers.opera, 983040)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 393472, 1179648)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 1638400)) { prefixes.webkit = true }
            return prefixes
        }

        // object_fit / object_position
        if (feature == CssFeature.ObjectFit || feature == CssFeature.ObjectPosition) {
            if (CssBrowserTargets.versionInRange(browsers.opera, 656896, 786688)) { prefixes.o = true }
            return prefixes
        }

        // shape 组
        if (feature == CssFeature.ShapeMargin || feature == CssFeature.ShapeOutside || feature == CssFeature.ShapeImageThreshold) {
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 524288, 655360)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 459008, 655360)) { prefixes.webkit = true }
            return prefixes
        }

        // text_overflow
        if (feature == CssFeature.TextOverflow) {
            if (CssBrowserTargets.versionInRange(browsers.opera, 589824, 786432)) { prefixes.o = true }
            return prefixes
        }

        // at_viewport
        if (feature == CssFeature.AtViewport) {
            if (CssBrowserTargets.versionInRange(browsers.edge, 786432, 1179648)) { prefixes.ms = true }
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 655360)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 720896, 786688)) { prefixes.o = true }
            return prefixes
        }

        // at_resolution
        if (feature == CssFeature.AtResolution) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131840, 262656)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 1835008)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 197888, 983040)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 262144, 984576)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 591104, 786432)) { prefixes.o = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 262144, 984576)) { prefixes.webkit = true }
            return prefixes
        }

        // text_align_last
        if (feature == CssFeature.TextAlignLast) {
            if (CssBrowserTargets.versionInRange(browsers.firefox, 786432, 3145728)) { prefixes.moz = true }
            return prefixes
        }

        // pixelated
        if (feature == CssFeature.Pixelated) {
            if (CssBrowserTargets.versionInRange(browsers.firefox, 198144, 4194304)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 327680, 393216)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 722432, 786688)) { prefixes.o = true }
            if (CssBrowserTargets.versionAtMost(browsers.safari, 393216)) { prefixes.webkit = true }
            return prefixes
        }

        // image_rendering
        if (feature == CssFeature.ImageRendering) {
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 458752)) { prefixes.ms = true }
            return prefixes
        }

        // inline 方向属性
        if (feature == CssFeature.BorderInlineStart || feature == CssFeature.BorderInlineEnd ||
            feature == CssFeature.MarginInlineStart || feature == CssFeature.MarginInlineEnd ||
            feature == CssFeature.PaddingInlineStart || feature == CssFeature.PaddingInlineEnd) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 4456448)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 196608, 2621440)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 786432)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 3604480)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 786432)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 590336)) { prefixes.webkit = true }
            return prefixes
        }

        // block 方向属性
        if (feature == CssFeature.BorderBlockStart || feature == CssFeature.BorderBlockEnd ||
            feature == CssFeature.MarginBlockStart || feature == CssFeature.MarginBlockEnd ||
            feature == CssFeature.PaddingBlockStart || feature == CssFeature.PaddingBlockEnd) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 4456448)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 786432)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 3604480)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 786432)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 590336)) { prefixes.webkit = true }
            return prefixes
        }

        // appearance
        if (feature == CssFeature.Appearance) {
            if (CssBrowserTargets.versionInRange(browsers.android, 131328, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 5439488)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 786432, 1179648)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 5177344, 5439488)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 131072, 5177344)) { prefixes.moz = true }
            if (CssBrowserTargets.versionPresent(browsers.ie)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 983552)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 4718592)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 983552)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 851968)) { prefixes.webkit = true }
            return prefixes
        }

        // scroll_snap 组
        if (feature == CssFeature.ScrollSnapType || feature == CssFeature.ScrollSnapCoordinate ||
            feature == CssFeature.ScrollSnapDestination || feature == CssFeature.ScrollSnapPointsX ||
            feature == CssFeature.ScrollSnapPointsY) {
            if (CssBrowserTargets.versionInRange(browsers.edge, 786432, 1179648)) { prefixes.ms = true }
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 655360)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 589824, 656128)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 589824, 655616)) { prefixes.webkit = true }
            return prefixes
        }

        // flow_into / flow_from / region_fragment
        if (feature == CssFeature.FlowInto || feature == CssFeature.FlowFrom || feature == CssFeature.RegionFragment) {
            if (CssBrowserTargets.versionInRange(browsers.chrome, 983040, 1179648)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 786432, 1179648)) { prefixes.ms = true }
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 655360)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 458752, 720896)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 393472, 720896)) { prefixes.webkit = true }
            return prefixes
        }

        // image_set
        if (feature == CssFeature.ImageSet) {
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1376256, 7340032)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 5177344, 7340032)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 393216, 590592)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 6422528)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 393216, 590080)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 1441792)) { prefixes.webkit = true }
            return prefixes
        }

        // writing_mode
        if (feature == CssFeature.WritingMode) {
            if (CssBrowserTargets.versionInRange(browsers.android, 196608, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 524288, 3080192)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 328960)) { prefixes.ms = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 327680, 656128)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 2228224)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 327936, 655616)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtMost(browsers.samsung, 262144)) { prefixes.webkit = true }
            return prefixes
        }

        // cross_fade
        if (feature == CssFeature.CrossFade) {
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1114112, 8519680)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 8323072)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 5177344, 8323072)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 327680, 590592)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtLeast(browsers.opera, 983040)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 327936, 590080)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 1638400)) { prefixes.webkit = true }
            return prefixes
        }

        // pseudo_class_read_only / pseudo_class_read_write
        if (feature == CssFeature.PseudoClassReadOnly || feature == CssFeature.PseudoClassReadWrite) {
            if (CssBrowserTargets.versionInRange(browsers.firefox, 196608, 5046272)) { prefixes.moz = true }
            return prefixes
        }

        // text_emphasis 组
        if (feature == CssFeature.TextEmphasis || feature == CssFeature.TextEmphasisPosition ||
            feature == CssFeature.TextEmphasisStyle || feature == CssFeature.TextEmphasisColor) {
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1638400, 6422528)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 5177344, 6422528)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 5570560)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 393472, 458752)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 1114112)) { prefixes.webkit = true }
            return prefixes
        }

        // display_grid / grid 组
        if (feature == CssFeature.DisplayGrid || feature == CssFeature.InlineGrid ||
            feature == CssFeature.GridTemplateColumns || feature == CssFeature.GridTemplateRows ||
            feature == CssFeature.GridRowStart || feature == CssFeature.GridColumnStart ||
            feature == CssFeature.GridRowEnd || feature == CssFeature.GridColumnEnd ||
            feature == CssFeature.GridRow || feature == CssFeature.GridColumn ||
            feature == CssFeature.GridArea || feature == CssFeature.GridTemplate ||
            feature == CssFeature.GridTemplateAreas || feature == CssFeature.PlaceSelf ||
            feature == CssFeature.GridColumnAlign || feature == CssFeature.GridRowAlign) {
            if (CssBrowserTargets.versionInRange(browsers.edge, 786432, 983040)) { prefixes.ms = true }
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 655360)) { prefixes.ms = true }
            return prefixes
        }

        // text_spacing
        if (feature == CssFeature.TextSpacing) {
            if (CssBrowserTargets.versionInRange(browsers.edge, 786432, 1179648)) { prefixes.ms = true }
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 524288)) { prefixes.ms = true }
            return prefixes
        }

        // pseudo_class_any_link
        if (feature == CssFeature.PseudoClassAnyLink) {
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 263171)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.chrome, 983040, 4194304)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 196608, 3211264)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 393216, 524544)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 3342336)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 393472, 524288)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 327680, 524800)) { prefixes.webkit = true }
            return prefixes
        }

        // isolate
        if (feature == CssFeature.Isolate) {
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1048576, 3080192)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 655360, 3211264)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 393216, 656128)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 983040, 2228224)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 393216, 655616)) { prefixes.webkit = true }
            return prefixes
        }

        // plaintext
        if (feature == CssFeature.Plaintext) {
            if (CssBrowserTargets.versionInRange(browsers.firefox, 655360, 3211264)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 393216, 656128)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 393216, 655616)) { prefixes.webkit = true }
            return prefixes
        }

        // isolate_override
        if (feature == CssFeature.IsolateOverride) {
            if (CssBrowserTargets.versionInRange(browsers.firefox, 1114112, 3211264)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 458752, 656128)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 458752, 655616)) { prefixes.webkit = true }
            return prefixes
        }

        // overscroll_behavior
        if (feature == CssFeature.OverscrollBehavior) {
            if (CssBrowserTargets.versionInRange(browsers.edge, 786432, 1114112)) { prefixes.ms = true }
            if (CssBrowserTargets.versionAtLeast(browsers.ie, 655360)) { prefixes.ms = true }
            return prefixes
        }

        // text_orientation
        if (feature == CssFeature.TextOrientation) {
            if (CssBrowserTargets.versionInRange(browsers.safari, 655616, 852224)) { prefixes.webkit = true }
            return prefixes
        }

        // print_color_adjust / color_adjust
        if (feature == CssFeature.PrintColorAdjust || feature == CssFeature.ColorAdjust) {
            if (CssBrowserTargets.versionInRange(browsers.chrome, 1114112, 8519680)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.android, 263168, 8323072)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 5177344, 8323072)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 3145728, 6291456)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 393216, 983552)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionAtLeast(browsers.opera, 983040)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 393216, 983552)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 262144, 1638400)) { prefixes.webkit = true }
            return prefixes
        }

        // any_pseudo
        if (feature == CssFeature.AnyPseudo) {
            if (CssBrowserTargets.versionInRange(browsers.chrome, 786432, 5701632)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.edge, 5177344, 5701632)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.firefox, 262144, 5111808)) { prefixes.moz = true }
            if (CssBrowserTargets.versionInRange(browsers.opera, 917504, 4784128)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.safari, 327680, 851968)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.iosSaf, 327680, 851968)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.samsung, 65536, 917504)) { prefixes.webkit = true }
            if (CssBrowserTargets.versionInRange(browsers.android, 2424832, 5701632)) { prefixes.webkit = true }
            return prefixes
        }

        return prefixes
    }

    private static func matchFeatureBorderRadius(f: CssFeature): Bool {
        f == CssFeature.BorderRadius || f == CssFeature.BorderTopLeftRadius ||
        f == CssFeature.BorderTopRightRadius || f == CssFeature.BorderBottomRightRadius ||
        f == CssFeature.BorderBottomLeftRadius
    }

    private static func matchFeatureAnimation(f: CssFeature): Bool {
        f == CssFeature.Animation || f == CssFeature.AnimationName ||
        f == CssFeature.AnimationDuration || f == CssFeature.AnimationDelay ||
        f == CssFeature.AnimationDirection || f == CssFeature.AnimationFillMode ||
        f == CssFeature.AnimationIterationCount || f == CssFeature.AnimationPlayState ||
        f == CssFeature.AnimationTimingFunction || f == CssFeature.AtKeyframes
    }

    private static func matchFeatureTransition(f: CssFeature): Bool {
        f == CssFeature.Transition || f == CssFeature.TransitionProperty ||
        f == CssFeature.TransitionDuration || f == CssFeature.TransitionDelay ||
        f == CssFeature.TransitionTimingFunction
    }

    private static func matchFeatureFlex(f: CssFeature): Bool {
        f == CssFeature.DisplayFlex || f == CssFeature.InlineFlex ||
        f == CssFeature.Flex || f == CssFeature.FlexGrow || f == CssFeature.FlexShrink ||
        f == CssFeature.FlexBasis || f == CssFeature.FlexDirection || f == CssFeature.FlexWrap ||
        f == CssFeature.FlexFlow || f == CssFeature.JustifyContent || f == CssFeature.Order ||
        f == CssFeature.AlignItems || f == CssFeature.AlignSelf || f == CssFeature.AlignContent
    }

    private static func matchFeatureMask(f: CssFeature): Bool {
        f == CssFeature.MaskClip || f == CssFeature.MaskComposite || f == CssFeature.MaskImage ||
        f == CssFeature.MaskOrigin || f == CssFeature.MaskRepeat || f == CssFeature.MaskBorderRepeat ||
        f == CssFeature.MaskBorderSource || f == CssFeature.Mask || f == CssFeature.MaskPosition ||
        f == CssFeature.MaskSize || f == CssFeature.MaskBorder || f == CssFeature.MaskBorderOutset ||
        f == CssFeature.MaskBorderWidth || f == CssFeature.MaskBorderSlice
    }

    /// 检查是否需要 2009 旧版 flexbox 语法
    /// 严格翻译自 Feature.isFlex2009
    /// 2009 flexbox 使用 -webkit-box 等属性
    public static func isFlex2009(browsers: CssBrowserTargets): Bool {
        if (CssBrowserTargets.versionInRange(browsers.android, 131328, 262656)) { return true }
        if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 1310720)) { return true }
        if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 393216)) { return true }
        if (CssBrowserTargets.versionInRange(browsers.safari, 196864, 393216)) { return true }
        return false
    }

    /// 检查是否需要旧版 -webkit-gradient() 语法
    /// 严格翻译自 Feature.isWebkitGradient
    public static func isWebkitGradient(browsers: CssBrowserTargets): Bool {
        if (CssBrowserTargets.versionInRange(browsers.android, 131328, 196608)) { return true }
        if (CssBrowserTargets.versionInRange(browsers.chrome, 262144, 589824)) { return true }
        if (CssBrowserTargets.versionInRange(browsers.iosSaf, 197120, 393216)) { return true }
        if (CssBrowserTargets.versionInRange(browsers.safari, 262144, 393216)) { return true }
        return false
    }

    // ========================================================================
    // 附加版本常量
    // 严格翻译自: prefixes.zig 中的具体版本比较值
    // ========================================================================

    /// 编码后的版本号常量 (用于 prefixesFor 中未覆盖的特殊值)
    /// Chrome 6 = 0x060000
    static let CHROME_6: Int64 = 393216
    /// Chrome 7
    static let CHROME_7: Int64 = 458752
    /// Chrome 9
    static let CHROME_9: Int64 = 589824
    /// Chrome 10
    static let CHROME_10: Int64 = 655360
    /// Chrome 11
    static let CHROME_11: Int64 = 720896
    /// Chrome 13
    static let CHROME_13: Int64 = 851968
    /// Chrome 16
    static let CHROME_16: Int64 = 1048576
    /// Chrome 17
    static let CHROME_17: Int64 = 1114112
    /// Chrome 20
    static let CHROME_20: Int64 = 1310720
    /// Chrome 21
    static let CHROME_21: Int64 = 1376256
    /// Chrome 22
    static let CHROME_22: Int64 = 1441792
    /// Chrome 24
    static let CHROME_24: Int64 = 1572864
    /// Chrome 26
    static let CHROME_26: Int64 = 1703936
    /// Chrome 28
    static let CHROME_28: Int64 = 1835008
    /// Chrome 29
    static let CHROME_29: Int64 = 1900544
    /// Chrome 30
    static let CHROME_30: Int64 = 1966080
    /// Chrome 32
    static let CHROME_32: Int64 = 2097152
    /// Chrome 34
    static let CHROME_34: Int64 = 2228224
    /// Chrome 36
    static let CHROME_36: Int64 = 2359296
    /// Chrome 38
    static let CHROME_38: Int64 = 2490368
    /// Chrome 40
    static let CHROME_40: Int64 = 2621440
    /// Chrome 42
    static let CHROME_42: Int64 = 2752512
    /// Chrome 44
    static let CHROME_44: Int64 = 2883584
    /// Chrome 45
    static let CHROME_45: Int64 = 2949120
    /// Chrome 47
    static let CHROME_47: Int64 = 3080192
    /// Chrome 48
    static let CHROME_48: Int64 = 3145728
    /// Chrome 49
    static let CHROME_49: Int64 = 3211264
    /// Chrome 51
    static let CHROME_51: Int64 = 3342336
    /// Chrome 53
    static let CHROME_53: Int64 = 3473408
    /// Chrome 54
    static let CHROME_54: Int64 = 3538944
    /// Chrome 57
    static let CHROME_57: Int64 = 3735552
    /// Chrome 58
    static let CHROME_58: Int64 = 3801088
    /// Chrome 59
    static let CHROME_59: Int64 = 3866624
    /// Chrome 60
    static let CHROME_60: Int64 = 3932160
    /// Chrome 61
    static let CHROME_61: Int64 = 3997696
    /// Chrome 62
    static let CHROME_62: Int64 = 4063232
    /// Chrome 63
    static let CHROME_63: Int64 = 4128768
    /// Chrome 64
    static let CHROME_64: Int64 = 4194304
    /// Chrome 65
    static let CHROME_65: Int64 = 4259840
    /// Chrome 66
    static let CHROME_66: Int64 = 4325376
    /// Chrome 67
    static let CHROME_67: Int64 = 4390912
    /// Chrome 69
    static let CHROME_69: Int64 = 4521984
    /// Chrome 70
    static let CHROME_70: Int64 = 4587520
    /// Chrome 71
    static let CHROME_71: Int64 = 4653056
    /// Chrome 76
    static let CHROME_76: Int64 = 4980736
    /// Chrome 78
    static let CHROME_78: Int64 = 5111808
    /// Chrome 80
    static let CHROME_80: Int64 = 5242880
    /// Chrome 83
    static let CHROME_83: Int64 = 5439488
    /// Chrome 85
    static let CHROME_85: Int64 = 5570560
    /// Chrome 86
    static let CHROME_86: Int64 = 5636096
    /// Chrome 87
    static let CHROME_87: Int64 = 5701632
    /// Chrome 88
    static let CHROME_88: Int64 = 5767168
    /// Chrome 89
    static let CHROME_89: Int64 = 5832704
    /// Chrome 90
    static let CHROME_90: Int64 = 5898240
    /// Chrome 91
    static let CHROME_91: Int64 = 5963776
    /// Chrome 92
    static let CHROME_92: Int64 = 6029312
    /// Chrome 93
    static let CHROME_93: Int64 = 6094848
    /// Chrome 99
    static let CHROME_99: Int64 = 6488064
    /// Chrome 101
    static let CHROME_101: Int64 = 6619136
    /// Chrome 102
    static let CHROME_102: Int64 = 6684672
    /// Chrome 104
    static let CHROME_104: Int64 = 6815744
    /// Chrome 105
    static let CHROME_105: Int64 = 6881280
    /// Chrome 106
    static let CHROME_106: Int64 = 6946816
    /// Chrome 107
    static let CHROME_107: Int64 = 7012352
    /// Chrome 108
    static let CHROME_108: Int64 = 7077888
    /// Chrome 111
    static let CHROME_111: Int64 = 7274496
    /// Chrome 112
    static let CHROME_112: Int64 = 7340032
    /// Chrome 114
    static let CHROME_114: Int64 = 7471104
    /// Chrome 116
    static let CHROME_116: Int64 = 7602176
    /// Chrome 117
    static let CHROME_117: Int64 = 7667712
    /// Chrome 118
    static let CHROME_118: Int64 = 7733248
    /// Chrome 119
    static let CHROME_119_GENERATED: Int64 = 7798784
    /// Chrome 120
    static let CHROME_120: Int64 = 7864320
    /// Chrome 122
    static let CHROME_122: Int64 = 7995392
    /// Chrome 123
    static let CHROME_123: Int64 = 8060928
    /// Chrome 124
    static let CHROME_124: Int64 = 8126464
    /// Chrome 125
    static let CHROME_125: Int64 = 8192000
    /// Chrome 126
    static let CHROME_126: Int64 = 8257536
    /// Chrome 127
    static let CHROME_127: Int64 = 8323072
    /// Chrome 128
    static let CHROME_128: Int64 = 8388608
    /// Chrome 129
    static let CHROME_129: Int64 = 8454144
    /// Chrome 130
    static let CHROME_130: Int64 = 8519680
    /// Chrome 131
    static let CHROME_131: Int64 = 8585216

    /// Firefox 版本常量
    static let FX_3: Int64 = 196608
    static let FX_3_5: Int64 = 229376
    static let FX_21: Int64 = 1376256
    static let FX_25: Int64 = 1638400
    static let FX_31: Int64 = 2031616
    static let FX_36: Int64 = 2359296
    static let FX_39: Int64 = 2555904
    static let FX_44: Int64 = 2883584
    static let FX_46: Int64 = 3014656
    static let FX_47: Int64 = 3080192
    static let FX_48: Int64 = 3145728
    static let FX_51: Int64 = 3342336
    static let FX_55: Int64 = 3604480
    static let FX_57: Int64 = 3735552
    static let FX_59: Int64 = 3866624
    static let FX_60_GENERATED: Int64 = 3932160
    static let FX_61: Int64 = 3997696
    static let FX_63: Int64 = 4128768
    static let FX_66: Int64 = 4325376
    static let FX_69: Int64 = 4521984
    static let FX_72: Int64 = 4718592
    static let FX_80: Int64 = 5242880
    static let FX_92: Int64 = 6029312
    static let FX_97: Int64 = 6356992
    static let FX_98: Int64 = 6422528
    static let FX_101: Int64 = 6619136
    static let FX_102: Int64 = 6684672
    static let FX_112: Int64 = 7340032
    static let FX_113: Int64 = 7405568
    static let FX_114: Int64 = 7471104
    static let FX_115: Int64 = 7536640
    static let FX_119: Int64 = 7798784
    static let FX_120: Int64 = 7864320
    static let FX_124: Int64 = 8126464
    static let FX_125: Int64 = 8192000
    static let FX_126: Int64 = 8257536
    static let FX_128: Int64 = 8388608
    static let FX_129: Int64 = 8454144
    static let FX_130: Int64 = 8519680
    static let FX_131: Int64 = 8585216
    static let FX_132: Int64 = 8650752
}
