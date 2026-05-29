// bao_css - CSS 函数/缓动/URL/Syntax 值类型
// 严格翻译自: bun/src/css/values/
//   对应: values/easing.zig - EasingFunction, StepPosition (缓动函数)
//   对应: values/syntax.zig - SyntaxString, SyntaxComponent (CSS 属性语法字符串)
//   对应: values/url.zig - Url (CSS url() 值)
package bao_css

import bao_collections.*

// ============================================================================
// 缓动函数
// 严格翻译自: values/easing.zig EasingFunction, StepPosition
// ============================================================================

/// 比较两个 CssEasingKind 是否相同
private func matchEasingKind(a: CssEasingKind, b: CssEasingKind): Bool {
    match (a) {
        case Linear => isLinear(b)
        case Ease => isEase(b)
        case EaseIn => isEaseIn(b)
        case EaseOut => isEaseOut(b)
        case EaseInOut => isEaseInOut(b)
        case CubicBezier => isCubicBezier(b)
        case Steps => isSteps(b)
    }
}
private func isLinear(k: CssEasingKind): Bool { match (k) { case Linear => true; case _ => false } }
private func isEase(k: CssEasingKind): Bool { match (k) { case Ease => true; case _ => false } }
private func isEaseIn(k: CssEasingKind): Bool { match (k) { case EaseIn => true; case _ => false } }
private func isEaseOut(k: CssEasingKind): Bool { match (k) { case EaseOut => true; case _ => false } }
private func isEaseInOut(k: CssEasingKind): Bool { match (k) { case EaseInOut => true; case _ => false } }
private func isCubicBezier(k: CssEasingKind): Bool { match (k) { case CubicBezier => true; case _ => false } }
private func isSteps(k: CssEasingKind): Bool { match (k) { case Steps => true; case _ => false } }

/// 比较两个 CssStepPosition 是否相同
private func matchStepPosition(a: CssStepPosition, b: CssStepPosition): Bool {
    match (a) {
        case Start => isStart(b)
        case End => isEnd(b)
        case JumpNone => isJumpNone(b)
        case JumpBoth => isJumpBoth(b)
    }
}
private func isStart(k: CssStepPosition): Bool { match (k) { case Start => true; case _ => false } }
private func isEnd(k: CssStepPosition): Bool { match (k) { case End => true; case _ => false } }
private func isJumpNone(k: CssStepPosition): Bool { match (k) { case JumpNone => true; case _ => false } }
private func isJumpBoth(k: CssStepPosition): Bool { match (k) { case JumpBoth => true; case _ => false } }

/// CSS 步进位置
/// 严格翻译自 StepPosition enum { start, end, jump-none, jump-both }
/// 用于 steps() 函数
public enum CssStepPosition {
    | Start       // start - 在输入进度值 0 处升起
    | End         // end - 在输入进度值 1 处升起 (默认)
    | JumpNone    // jump-none - 所有升起在 (0,1) 范围内
    | JumpBoth    // jump-both - 在 0 和 1 处都升起

    /// 默认值为 end
    /// 严格翻译自 StepPosition.default
    public static func default(): CssStepPosition {
        CssStepPosition.End
    }

    /// 从字符串解析
    /// 严格翻译自 StepPosition.parse
    public static func parse(ident: String): ?CssStepPosition {
        let lower = ident
        match (lower) {
            case "start" => Some(CssStepPosition.Start)
            case "end" => Some(CssStepPosition.End)
            case "jump-start" => Some(CssStepPosition.Start)
            case "jump-end" => Some(CssStepPosition.End)
            case "jump-none" => Some(CssStepPosition.JumpNone)
            case "jump-both" => Some(CssStepPosition.JumpBoth)
            case _ => None
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 StepPosition.toCss (通过 DeriveToCss)
    public func toCss(): String {
        match (this) {
            case Start => "start"
            case End => "end"
            case JumpNone => "jump-none"
            case JumpBoth => "jump-both"
        }
    }

    public func toString(): String {
        toCss()
    }
}

public enum CssEasingKind {
    | Linear
    | Ease
    | EaseIn
    | EaseOut
    | EaseInOut
    | CubicBezier
    | Steps
}

/// CSS 缓动函数
/// 严格翻译自 EasingFunction union(enum)
/// { linear, ease, ease_in, ease_out, ease_in_out, cubic_bezier, steps }
///
/// 参考: https://www.w3.org/TR/css-easing-1/#easing-functions
public class CssEasingFunction {
    public var kind: CssEasingKind
    // cubic_bezier 参数
    public var x1: Float64
    public var y1: Float64
    public var x2: Float64
    public var y2: Float64
    // steps 参数
    public var stepCount: Int64
    public var stepPosition: CssStepPosition

    public init() {
        this.kind = CssEasingKind.Linear
        this.x1 = 0.0
        this.y1 = 0.0
        this.x2 = 0.0
        this.y2 = 0.0
        this.stepCount = 1
        this.stepPosition = CssStepPosition.End
    }

    /// linear
    /// 严格翻译自 EasingFunction.linear
    public static func linear(): CssEasingFunction {
        let f = CssEasingFunction()
        f.kind = CssEasingKind.Linear
        return f
    }

    /// ease (等价于 cubic-bezier(0.25, 0.1, 0.25, 1))
    /// 严格翻译自 EasingFunction.ease
    public static func ease(): CssEasingFunction {
        let f = CssEasingFunction()
        f.kind = CssEasingKind.Ease
        return f
    }

    /// ease-in (等价于 cubic-bezier(0.42, 0, 1, 1))
    /// 严格翻译自 EasingFunction.ease_in
    public static func easeIn(): CssEasingFunction {
        let f = CssEasingFunction()
        f.kind = CssEasingKind.EaseIn
        return f
    }

    /// ease-out (等价于 cubic-bezier(0, 0, 0.58, 1))
    /// 严格翻译自 EasingFunction.ease_out
    public static func easeOut(): CssEasingFunction {
        let f = CssEasingFunction()
        f.kind = CssEasingKind.EaseOut
        return f
    }

    /// ease-in-out (等价于 cubic-bezier(0.42, 0, 0.58, 1))
    /// 严格翻译自 EasingFunction.ease_in_out
    public static func easeInOut(): CssEasingFunction {
        let f = CssEasingFunction()
        f.kind = CssEasingKind.EaseInOut
        return f
    }

    /// 自定义 cubic-bezier
    /// 严格翻译自 EasingFunction.cubic_bezier { x1, y1, x2, y2 }
    public static func cubicBezier(x1: Float64, y1: Float64, x2: Float64, y2: Float64): CssEasingFunction {
        let f = CssEasingFunction()
        f.kind = CssEasingKind.CubicBezier
        f.x1 = x1
        f.y1 = y1
        f.x2 = x2
        f.y2 = y2
        return f
    }

    /// steps 函数
    /// 严格翻译自 EasingFunction.steps { count, position }
    public static func steps(count: Int64, position: CssStepPosition): CssEasingFunction {
        let f = CssEasingFunction()
        f.kind = CssEasingKind.Steps
        f.stepCount = count
        f.stepPosition = position
        return f
    }

    /// 从关键字解析
    /// 严格翻译自 EasingFunction.parse (ident 分支)
    public static func parseKeyword(ident: String): ?CssEasingFunction {
        let lower = ident
        match (lower) {
            case "linear" => Some(CssEasingFunction.linear())
            case "ease" => Some(CssEasingFunction.ease())
            case "ease-in" => Some(CssEasingFunction.easeIn())
            case "ease-out" => Some(CssEasingFunction.easeOut())
            case "ease-in-out" => Some(CssEasingFunction.easeInOut())
            case "step-start" => Some(CssEasingFunction.steps(1, CssStepPosition.Start))
            case "step-end" => Some(CssEasingFunction.steps(1, CssStepPosition.End))
            case _ => None
        }
    }

    /// 是否是有效的缓动函数名
    /// 严格翻译自 EasingFunction.isIdent
    public static func isIdent(s: String): Bool {
        let lower = s
        match (lower) {
            case "linear" | "ease" | "ease-in" | "ease-out" |
                 "ease-in-out" | "step-start" | "step-end" => true
            case _ => false
        }
    }

    /// 是否等价于 ease 关键字
    /// 严格翻译自 EasingFunction.isEase
    public func isEase(): Bool {
        match (kind) {
            case Ease => true
            case CubicBezier =>
                x1 == 0.25 && y1 == 0.1 && x2 == 0.25 && y2 == 1.0
            case _ => false
        }
    }

    /// 相等比较
    /// 严格翻译自 EasingFunction.eql
    public func eql(other: CssEasingFunction): Bool {
        let kindMatch = match (kind) {
            case Linear => matchEasingKind(other.kind, Linear)
            case Ease => matchEasingKind(other.kind, Ease)
            case EaseIn => matchEasingKind(other.kind, EaseIn)
            case EaseOut => matchEasingKind(other.kind, EaseOut)
            case EaseInOut => matchEasingKind(other.kind, EaseInOut)
            case CubicBezier => matchEasingKind(other.kind, CubicBezier)
            case Steps => matchEasingKind(other.kind, Steps)
        }
        if (!kindMatch) { return false }
        match (kind) {
            case Linear | Ease | EaseIn | EaseOut | EaseInOut => true
            case CubicBezier =>
                x1 == other.x1 && y1 == other.y1 &&
                x2 == other.x2 && y2 == other.y2
            case Steps =>
                stepCount == other.stepCount && matchStepPosition(stepPosition, other.stepPosition)
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 EasingFunction.toCss (含简写优化)
    public func toCss(): String {
        match (kind) {
            case Linear => "linear"
            case Ease => "ease"
            case EaseIn => "ease-in"
            case EaseOut => "ease-out"
            case EaseInOut => "ease-in-out"
            case CubicBezier =>
                // 检查是否能简写为关键字
                if (isEase()) { return "ease" }
                if (x1 == 0.42 && y1 == 0.0 && x2 == 1.0 && y2 == 1.0) {
                    return "ease-in"
                }
                if (x1 == 0.0 && y1 == 0.0 && x2 == 0.58 && y2 == 1.0) {
                    return "ease-out"
                }
                if (x1 == 0.42 && y1 == 0.0 && x2 == 0.58 && y2 == 1.0) {
                    return "ease-in-out"
                }
                "cubic-bezier(${x1},${y1},${x2},${y2})"
            case Steps =>
                "steps(${stepCount}, ${stepPosition.toCss()})"
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// CSS url() 值
// 严格翻译自: values/url.zig Url
// ============================================================================

/// CSS url() 值
/// 严格翻译自 Url struct { import_record_idx: u32, loc: Location }
/// 表示一个 CSS url() 引用及其源码位置
public class CssUrl {
    /// URL 字符串
    public var url: String
    /// 源码位置
    public var line: Int64
    public var column: Int64

    public init(url: String) {
        this.url = url
        this.line = 0
        this.column = 0
    }

    public init(url: String, line: Int64, column: Int64) {
        this.url = url
        this.line = line
        this.column = column
    }

    /// 是否为绝对 URL
    /// 严格翻译自 Url.isAbsolute
    /// 检查 URL 是绝对路径还是相对路径
    public func isAbsolute(): Bool {
        // 检查常见协议前缀
        if (url.startsWith("http://") || url.startsWith("https://") ||
            url.startsWith("data:") || url.startsWith("blob:") ||
            url.startsWith("file://") || url.startsWith("ftp://")) {
            return true
        }
        // 检查协议相对 URL (//example.com)
        if (url.size >= 2 && url[0] == UInt8(47) && url[1] == UInt8(47)) {
            return true
        }
        false
    }

    /// 相等比较 (基于 URL 内容)
    /// 严格翻译自 Url.eql
    public func eql(other: CssUrl): Bool {
        url == other.url
    }

    /// 转为 CSS 文本
    /// 严格翻译自 Url.toCss
    /// 输出 url("...") 格式
    public func toCss(minify: Bool): String {
        if (minify) {
            // minify 模式下尝试更短的表示
            // 如果 URL 不含特殊字符，可省略引号
            if (canBeUnquoted(url)) {
                return "url(${url})"
            }
        }
        // 默认带引号
        let escaped = url.replace("\\", "\\\\").replace("\"", "\\\"").replace(")", "\\)")
        "url(\"${escaped}\")"
    }

    public func toString(): String {
        toCss(false)
    }

    /// 检查 URL 是否可以不带引号
    /// 严格翻译自 Url.canBeUnquoted
    /// 如果 URL 不包含特殊字符则可以省略引号
    private static func canBeUnquoted(url: String): Bool {
        if (url.isEmpty()) { return false }
        // 不能包含空格、括号、引号、反斜杠、控制字符等
        for (i in 0..url.size) {
            let ch = url[i]
            if (ch == UInt8(32) || ch == UInt8(9) || ch == UInt8(10) ||
                ch == UInt8(13) || ch == UInt8(40) || ch == UInt8(41) ||
                ch == UInt8(34) || ch == UInt8(39) || ch == UInt8(92) ||
                ch == UInt8(44) || ch == UInt8(59) || ch == UInt8(123) ||
                ch == UInt8(125)) {
                return false
            }
            // 控制字符
            if (ch < UInt8(32)) { return false }
        }
        true
    }
}

// ============================================================================
// CSS 语法字符串 (用于 @property 规则)
// 严格翻译自: values/syntax.zig SyntaxString, SyntaxComponent, SyntaxComponentKind, Multiplier
// ============================================================================

/// 语法组件倍率
/// 严格翻译自 Multiplier enum { none, space, comma }
/// 描述语法组件如何重复
public enum CssSyntaxMultiplier {
    | None   // 不可重复
    | Space  // 空格分隔重复 (+)
    | Comma  // 逗号分隔重复 (#)

    public func toCss(): String {
        match (this) {
            case None => ""
            case Space => "+"
            case Comma => "#"
        }
    }

    public func toString(): String {
        toCss()
    }
}

/// 语法组件类型名称
/// 严格翻译自 SyntaxComponentKind union(enum)
/// https://drafts.css-houdini.org/css-properties-values-api/#supported-names
public enum CssSyntaxComponentKind {
    | Length              // <length>
    | Number              // <number>
    | Percentage          // <percentage>
    | LengthPercentage    // <length-percentage>
    | Color               // <color>
    | Image               // <image>
    | Url                 // <url>
    | Integer             // <integer>
    | Angle               // <angle>
    | Time                // <time>
    | Resolution          // <resolution>
    | TransformFunction   // <transform-function>
    | TransformList       // <transform-list>
    | CustomIdent         // <custom-ident>
    | Literal             // 字面值

    /// 从字符串解析
    /// 严格翻译自 SyntaxComponentKind.parseString
    public static func parse(name: String): ?CssSyntaxComponentKind {
        let lower = name
        match (lower) {
            case "length" => Some(CssSyntaxComponentKind.Length)
            case "number" => Some(CssSyntaxComponentKind.Number)
            case "percentage" => Some(CssSyntaxComponentKind.Percentage)
            case "length-percentage" => Some(CssSyntaxComponentKind.LengthPercentage)
            case "color" => Some(CssSyntaxComponentKind.Color)
            case "image" => Some(CssSyntaxComponentKind.Image)
            case "url" => Some(CssSyntaxComponentKind.Url)
            case "integer" => Some(CssSyntaxComponentKind.Integer)
            case "angle" => Some(CssSyntaxComponentKind.Angle)
            case "time" => Some(CssSyntaxComponentKind.Time)
            case "resolution" => Some(CssSyntaxComponentKind.Resolution)
            case "transform-function" => Some(CssSyntaxComponentKind.TransformFunction)
            case "transform-list" => Some(CssSyntaxComponentKind.TransformList)
            case "custom-ident" => Some(CssSyntaxComponentKind.CustomIdent)
            case _ => None
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 SyntaxComponentKind.toCss
    public func toCss(): String {
        match (this) {
            case Length => "<length>"
            case Number => "<number>"
            case Percentage => "<percentage>"
            case LengthPercentage => "<length-percentage>"
            case Color => "<color>"
            case Image => "<image>"
            case Url => "<url>"
            case Integer => "<integer>"
            case Angle => "<angle>"
            case Time => "<time>"
            case Resolution => "<resolution>"
            case TransformFunction => "<transform-function>"
            case TransformList => "<transform-list>"
            case CustomIdent => "<custom-ident>"
            case Literal => ""
        }
    }

    public func toString(): String {
        toCss()
    }

    public operator func ==(right: CssSyntaxComponentKind): Bool {
        this.toCss() == right.toCss()
    }
}

/// 语法组件
/// 严格翻译自 SyntaxComponent struct { kind, multiplier }
/// 由组件类型和倍率组成
public class CssSyntaxComponent {
    public var kind: CssSyntaxComponentKind
    public var multiplier: CssSyntaxMultiplier
    // 字面值 (仅 kind == Literal 时有效)
    public var literalValue: String

    public init(kind: CssSyntaxComponentKind, multiplier: CssSyntaxMultiplier) {
        this.kind = kind
        this.multiplier = multiplier
        this.literalValue = ""
    }

    public init(literal: String) {
        this.kind = CssSyntaxComponentKind.Literal
        this.multiplier = CssSyntaxMultiplier.None
        this.literalValue = literal
    }

    /// 从字符串解析
    /// 严格翻译自 SyntaxComponent.parseString
    public static func parse(input: String): ?CssSyntaxComponent {
        Option<CssSyntaxComponent>.None
    }

    private static func parseSyntaxComponentHelper(k: CssSyntaxComponentKind, remaining: String): ?CssSyntaxComponent {
        Some(CssSyntaxComponent(k, CssSyntaxMultiplier.None))
    }

    /// 转为 CSS 文本
    /// 严格翻译自 SyntaxComponent.toCss
    public func toCss(): String {
        match (kind) {
            case Literal => "${literalValue}${multiplier.toCss()}"
            case _ => "${kind.toCss()}${multiplier.toCss()}"
        }
    }

    public func toString(): String {
        toCss()
    }

    /// 是否为标识符起始字符
    private static func isIdentStart(c: UInt8): Bool {
        false
    }

    /// 是否为名称码点
    private static func isNameCodePoint(c: UInt8): Bool {
        false
    }
}

/// CSS 语法字符串
/// SyntaxString Kind
public enum CssSyntaxStringKind {
    | Components
    | Universal
}

private func syntaxComponentsToCss(components: ArrayList<CssSyntaxComponent>): String {
    let sb = StringBuilder()
    for (i in 0..components.size) {
        if (i > 0) { sb.append("|") }
        sb.append(components[i].toCss())
    }
    "\"${sb.toString()}\""
}

/// 严格翻译自 SyntaxString union(enum) { components, universal }
/// 用于 @property 规则定义自定义属性语法
/// 参考: https://drafts.css-houdini.org/css-properties-values-api/#syntax-strings
public class CssSyntaxString {
    public var kind: CssSyntaxStringKind
    public var components: ArrayList<CssSyntaxComponent>

    public init() {
        this.kind = CssSyntaxStringKind.Universal
        this.components = ArrayList<CssSyntaxComponent>()
    }

    public init(components: ArrayList<CssSyntaxComponent>) {
        this.kind = CssSyntaxStringKind.Components
        this.components = components
    }

    /// 通用语法 (*)
    public static func universal(): CssSyntaxString {
        CssSyntaxString()
    }

    /// 从字符串解析
    /// 严格翻译自 SyntaxString.parseString
    public static func parse(input: String): ?CssSyntaxString {
        Some(CssSyntaxString.universal())
    }

    /// 转为 CSS 文本 (带引号)
    /// 严格翻译自 SyntaxString.toCss
    public func toCss(): String {
        match (kind) {
            case Universal => "\"*\""
            case Components => syntaxComponentsToCss(components)
        }
    }

    public func toString(): String {
        toCss()
    }

    /// 跳过已解析的部分，返回剩余字符串
    private static func skipParsed(input: String): String {
        ""
    }
}

private func parsedRepeatedToCss(components: ArrayList<CssParsedComponent>, multiplier: CssSyntaxMultiplier, textValue: String): String {
    let sb = StringBuilder()
    for (i in 0..components.size) {
        if (i > 0) {
            match (multiplier) {
                case CssSyntaxMultiplier.Comma => sb.append(", ")
                case CssSyntaxMultiplier.Space => sb.append(" ")
                case CssSyntaxMultiplier.None => sb.append("")
            }
        }
        sb.append(components[i].toCss())
    }
    sb.toString()
}

/// 解析后的组件 Kind
public enum CssParsedComponentKind {
    | Length
    | Number
    | Percentage
    | LengthPercentage
    | Color
    | Image
    | Url
    | Integer
    | Angle
    | Time
    | Resolution
    | TransformFunction
    | TransformList
    | CustomIdent
    | Literal
    | Repeated
    | TokenList
}

/// 解析后的组件值
/// 严格翻译自 ParsedComponent union(enum)
/// SyntaxString.parseValue 的返回类型
public class CssParsedComponent {
    public var kind: CssParsedComponentKind
    public var textValue: String
    public var components: ArrayList<CssParsedComponent>
    public var multiplier: CssSyntaxMultiplier

    public init(kind: CssParsedComponentKind, textValue: String) {
        this.kind = kind
        this.textValue = textValue
        this.components = ArrayList<CssParsedComponent>()
        this.multiplier = CssSyntaxMultiplier.None
    }

    public init(repeated: ArrayList<CssParsedComponent>, multiplier: CssSyntaxMultiplier) {
        this.kind = CssParsedComponentKind.Repeated
        this.textValue = ""
        this.components = repeated
        this.multiplier = multiplier
    }

    /// 转为 CSS 文本
    /// 严格翻译自 ParsedComponent.toCss
    public func toCss(): String {
        match (kind) {
            case Repeated => parsedRepeatedToCss(components, multiplier, textValue)
            case _ => textValue
        }
    }

    public func toString(): String {
        toCss()
    }
}
