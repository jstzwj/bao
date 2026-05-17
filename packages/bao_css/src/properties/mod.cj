// bao_css - CSS 属性定义模块入口
// 严格翻译自: bun/src/css/properties/mod.rs
//   对应: properties/properties.zig - Property definitions, handlers, shorthands
package bao_css.properties

import bao_core.*
import bao_collections.*
import bao_css.values.*

// ============================================================================
// CSS 厂商前缀 (属性用)
// ============================================================================

/// CSS 厂商前缀 (属性 ID 专用)
public class CssVendorPrefix {
    public var prefix: String

    public init() {
        this.prefix = ""
    }

    public init(prefix: String) {
        this.prefix = prefix
    }

    public func toCss(): String {
        prefix
    }

    public func toString(): String {
        prefix
    }
}

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
    private static func parseIdent(id: String): ?CssWideKeyword {
        let lower = id.toAsciiLower()
        if (lower == "initial") { return Some(CssWideKeyword.Initial) }
        if (lower == "inherit") { return Some(CssWideKeyword.Inherit) }
        if (lower == "unset") { return Some(CssWideKeyword.Unset) }
        if (lower == "revert") { return Some(CssWideKeyword.Revert) }
        if (lower == "revert-layer") { return Some(CssWideKeyword.RevertLayer) }
        None
    }

    public static func parse(input: CssParser): ?CssWideKeyword {
        let ident = input.expectIdent()
        match (ident) {
            case Some(id) => parseIdent(id)
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

    public operator func ==(rhs: CssWideKeyword): Bool {
        this.toCss() == rhs.toCss()
    }
}
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
        id.toCss() == other.id.toCss() && valueText == other.valueText
    }

    public func toString(): String {
        toCss(false)
    }
}

// ============================================================================
// 解析基础设施存根类型
// 用于编译属性解析方法 - 完整实现在后续翻译中
// ============================================================================

/// CSS 解析器 (存根)
/// 严格翻译自: bun/src/css/parser.rs CssParser
public class CssParser {
    private var input: String
    private var pos: Int64

    public init(input: String) {
        this.input = input
        this.pos = 0
    }

    /// 期望标识符
    public func expectIdent(): ?String {
        if (pos >= input.size) { return None }
        // 简单实现: 读取到下一个空白或结尾
        let start = pos
        while (pos < input.size) {
            let c = input[pos]
            if (c == UInt8(32) || c == UInt8(9) || c == UInt8(10) || c == UInt8(59)) { break }
            pos += 1
        }
        if (pos > start) {
            return Some(input[start..pos])
        }
        None
    }

    /// 跳过空白
    public func skipWhitespace(): Unit {
        while (pos < input.size) {
            let c = input[pos]
            if (c != UInt8(32) && c != UInt8(9) && c != UInt8(10) && c != UInt8(13)) { break }
            pos += 1
        }
    }

    /// 查看小写标识符
    public func peekIdentLowercase(): ?String {
        let saved = pos
        skipWhitespace()
        let result = expectIdent()
        pos = saved
        match (result) {
            case Some(s) => Some(s.toAsciiLower())
            case None => None
        }
    }

    /// 前进一个字符
    public func advance(): Unit {
        if (pos < input.size) {
            pos += 1
        }
    }

    /// 前进 n 个字符
    public func advance(n: Int64): Unit {
        pos += n
        if (pos > input.size) {
            pos = input.size
        }
    }

    /// 是否已到结尾
    public func eof(): Bool {
        pos >= input.size
    }

    /// 获取剩余输入
    public func remaining(): String {
        if (pos >= input.size) { return "" }
        input[pos..input.size]
    }

    /// 查看下一个字符
    public func peek(): ?UInt8 {
        if (pos >= input.size) { return None }
        Some(UInt8(input[pos]))
    }

    /// 消费字符
    public func consume(): ?UInt8 {
        if (pos >= input.size) { return None }
        let c = UInt8(input[pos])
        pos += 1
        Some(c)
    }

    /// 解析数字
    /// 简单实现: 读取连续的数字和小数点字符
    public func parseNumber(): ?Float64 {
        skipWhitespace()
        if (pos >= input.size) { return None }
        let start = pos
        // 允许负号
        if (pos < input.size && (input[pos] == UInt8(45) || input[pos] == UInt8(43))) {
            pos += 1
        }
        // 读取数字部分
        var hasDot = false
        while (pos < input.size) {
            let c = input[pos]
            if (c >= UInt8(48) && c <= UInt8(57)) {
                pos += 1
            } else if (c == UInt8(46) && !hasDot) {
                hasDot = true
                pos += 1
            } else {
                break
            }
        }
        if (pos > start) {
            return Some(0.0)
        }
        return None
    }

    /// 尝试解析一个数字 (返回 Option)
    public func tryParseNumber(): ?Float64 {
        parseNumber()
    }

    /// 期望逗号
    public func expectComma(): Unit {
        skipWhitespace()
        if (pos < input.size && input[pos] == UInt8(44)) {
            pos += 1
        }
    }

    /// 尝试解析逗号
    public func tryParseComma(): Bool {
        skipWhitespace()
        if (pos < input.size && input[pos] == UInt8(44)) {
            pos += 1
            return true
        }
        return false
    }

    /// 获取上次解析的数字
    public func lastParsedNumber(): Float64 {
        0.0
    }

    /// 期望 URL 值
    public func expectUrl(): ?String {
        skipWhitespace()
        if (pos < input.size && input[pos] == UInt8(40)) {
            pos += 1
            skipWhitespace()
        }
        let start = pos
        while (pos < input.size && input[pos] != UInt8(41)) {
            pos += 1
        }
        if (pos > start) {
            return Some(input[start..pos])
        }
        return None
    }
}

/// CSS 解析选项 (存根)
/// 严格翻译自: CssParserOptions
public class CssParserOptions {
    public init() {}
}

/// CSS 解析错误
/// 严格翻译自: CssParseError
public class CssParseError {
    public var message: String
    public var line: Int64
    public var column: Int64

    public init(message: String) {
        this.message = message
        this.line = 0
        this.column = 0
    }
}

/// CSS 解析结果
/// 严格翻译自: CssParseResult<T>
public enum CssParseResult<T> {
    | Ok(T)
    | Err(CssParseError)

    public static func ok(value: T): CssParseResult<T> {
        CssParseResult<T>.Ok(value)
    }

    public static func err(e: CssParseError): CssParseResult<T> {
        CssParseResult<T>.Err(e)
    }

    public func isOk(): Bool {
        match (this) {
            case Ok(_) => true
            case Err(_) => false
        }
    }

    public func isErr(): Bool {
        match (this) {
            case Ok(_) => false
            case Err(_) => true
        }
    }

    public func getValue(): ?T {
        match (this) {
            case Ok(v) => Some(v)
            case Err(_) => None
        }
    }

    public func getError(): ?CssParseError {
        match (this) {
            case Ok(_) => None
            case Err(e) => Some(e)
        }
    }
}

/// CSS 打印器 (属性用存根)
/// 与 bao_css.CssPrinter 不同, 这是属性序列化的简化版本
/// 严格翻译自: Printer (property serialization)
public class Printer {
    private var sb: StringBuilder
    public var minify: Bool

    public init() {
        this.sb = StringBuilder()
        this.minify = false
    }

    public init(minify: Bool) {
        this.sb = StringBuilder()
        this.minify = minify
    }

    public func writeStr(s: String): Unit {
        sb.append(s)
    }

    public func writeChar(c: UInt8): Unit {
        sb.append(c)
    }

    public func getOutput(): String {
        sb.toString()
    }

    public func toString(): String {
        getOutput()
    }

    public func addFmtError(): Unit {
        sb.append("/* error */")
    }
}

/// CSS 导入记录 (存根)
/// 严格翻译自: ImportRecord
public class ImportRecord {
    public var url: String
    public init() {
        this.url = ""
    }
}

/// CSS 浏览器版本 (存根)
/// 严格翻译自: CssBrowserVersion
public class CssBrowserVersion {
    public var browser: String
    public var version: Int64
    public init() {
        this.browser = ""
        this.version = 0
    }
}

/// CSS 属性处理器上下文 (存根)
/// 严格翻译自: PropertyHandlerContext
public class PropertyHandlerContext {
    public init() {}
}

/// CSS 声明列表 (存根)
/// 严格翻译自: DeclarationList
public class DeclarationList {
    public var declarations: ArrayList<CssProperty>
    public init() {
        this.declarations = ArrayList<CssProperty>()
    }
}
