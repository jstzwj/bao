// bao_css - CSS 函数/缓动/URL/Syntax 值类型
// 严格翻译自: bun/src/css/values/
//   对应: values/easing.zig - EasingFunction, StepPosition (缓动函数)
//   对应: values/syntax.zig - SyntaxString, SyntaxComponent (CSS 属性语法字符串)
//   对应: values/url.zig - Url (CSS url() 值)
package bao_css

import bao_core.*
import bao_collections.*

// ============================================================================
// 缓动函数
// 严格翻译自: values/easing.zig EasingFunction, StepPosition
// ============================================================================

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
        let lower = ident.toLowerCase()
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

    public enum CssEasingKind {
        | Linear
        | Ease
        | EaseIn
        | EaseOut
        | EaseInOut
        | CubicBezier
        | Steps
    }

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
        let lower = ident.toLowerCase()
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
        let lower = s.toLowerCase()
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
    public func eql(other: CssEasingFunction): Bool {
        if (kind != other.kind) { return false }
        match (kind) {
            case Linear | Ease | EaseIn | EaseOut | EaseInOut => true
            case CubicBezier =>
                x1 == other.x1 && y1 == other.y1 &&
                x2 == other.x2 && y2 == other.y2
            case Steps =>
                stepCount == other.stepCount && stepPosition == other.stepPosition
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
            case CubicBezier => {
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
            }
            case Steps => {
                // 简写: steps(1, start) -> step-start
                if (stepCount == 1 && stepPosition == CssStepPosition.Start) {
                    return "step-start"
                }
                if (stepCount == 1 && stepPosition == CssStepPosition.End) {
                    return "step-end"
                }
                "steps(${stepCount}, ${stepPosition.toCss()})"
            }
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
        if (url.isEmpty()) { return false }

        // 以 '.' 开头为相对
        let first = url[0]
        if (first == '.') { return false }

        // 以 '/' 开头为绝对
        if (first == '/') { return true }

        // 以 '#' 开头为片段 URL (相对文档)
        if (first == '#') { return true }

        // 检查是否有 scheme (如 http:, data:, file:)
        // scheme 必须以字母开头
        if (!first.isAsciiAlpha()) { return false }

        var i = 0
        while (i < url.size) {
            let c = url[i]
            if (c.isAsciiAlpha() || (c >= '0' && c <= '9') ||
                c == '+' || c == '-' || c == '.') {
                i++
            } else if (c == ':') {
                return true
            } else {
                break
            }
        }
        return false
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
    private static func canBeUnquoted(url: String): Bool {
        if (url.isEmpty()) { return false }
        // 简单检查: 不含空格、引号、括号等
        for (c in url) {
            if (c == ' ' || c == '"' || c == '\'' ||
                c == '(' || c == ')' || c == '\\' ||
                c == '\n' || c == '\r' || c == '\t') {
                return false
            }
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
        let lower = name.toLowerCase()
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
        let trimmed = input.trimStart()
        if (trimmed.isEmpty()) { return None }

        var kind: ?CssSyntaxComponentKind = None
        var multiplier = CssSyntaxMultiplier.None
        var remaining = trimmed

        if (trimmed.startsWith("<")) {
            // 数据类型: <length>, <number>, ...
            let endIdx = trimmed.indexOf(">")
            match (endIdx) {
                case Some(idx) =>
                    let name = trimmed.substring(1, idx)
                    kind = CssSyntaxComponentKind.parse(name)
                    remaining = trimmed.substring(idx + 1)
                case None => return None
            }
        } else {
            // 字面值标识符
            var endIdx = 0
            while (endIdx < remaining.size && isNameCodePoint(remaining[endIdx])) {
                endIdx++
            }
            if (endIdx == 0) { return None }
            let literal = remaining.substring(0, endIdx)
            remaining = remaining.substring(endIdx)
            return Some(CssSyntaxComponent(literal))
        }

        match (kind) {
            case Some(k) => {
                // transform-list 不可有倍率
                if (k == CssSyntaxComponentKind.TransformList) {
                    return Some(CssSyntaxComponent(k, CssSyntaxMultiplier.None))
                }
                // 检查倍率
                let trimmedRemaining = remaining.trimStart()
                if (trimmedRemaining.startsWith("+")) {
                    multiplier = CssSyntaxMultiplier.Space
                } else if (trimmedRemaining.startsWith("#")) {
                    multiplier = CssSyntaxMultiplier.Comma
                }
                Some(CssSyntaxComponent(k, multiplier))
            }
            case None => None
        }
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
        (c >= UInt8('A') && c <= UInt8('Z')) ||
        (c >= UInt8('a') && c <= UInt8('z')) ||
        c >= 0x80 || c == UInt8('_')
    }

    /// 是否为名称码点
    private static func isNameCodePoint(c: UInt8): Bool {
        isIdentStart(c) || (c >= UInt8('0') && c <= UInt8('9')) || c == UInt8('-')
    }
}

/// CSS 语法字符串
/// 严格翻译自 SyntaxString union(enum) { components, universal }
/// 用于 @property 规则定义自定义属性语法
/// 参考: https://drafts.css-houdini.org/css-properties-values-api/#syntax-strings
public class CssSyntaxString {
    public var kind: CssSyntaxStringKind
    public var components: ArrayList<CssSyntaxComponent>

    public enum CssSyntaxStringKind {
        | Components
        | Universal
    }

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
        let trimmed = input.trim()
        if (trimmed.isEmpty()) { return None }

        // 通用语法
        if (trimmed == "*") {
            return Some(CssSyntaxString.universal())
        }

        var remaining = trimmed
        let components = ArrayList<CssSyntaxComponent>()

        while (true) {
            let component = CssSyntaxComponent.parse(remaining)
            match (component) {
                case Some(comp) =>
                    components.append(comp)
                    // 更新 remaining (移除已解析部分)
                    // 简化: 逐字符扫描找到 | 或结尾
                    remaining = skipParsed(remaining)
                case None => return None
            }

            remaining = remaining.trimStart()
            if (remaining.isEmpty()) { break }

            if (remaining.startsWith("|")) {
                remaining = remaining.substring(1)
                continue
            }

            return None
        }

        if (components.size == 0) { return None }
        Some(CssSyntaxString(components))
    }

    /// 转为 CSS 文本 (带引号)
    /// 严格翻译自 SyntaxString.toCss
    public func toCss(): String {
        match (kind) {
            case Universal => "\"*\""
            case Components => {
                var parts = ArrayList<String>()
                for (comp in components) {
                    parts.append(comp.toCss())
                }
                "\"${String.join("|", parts)}\""
            }
        }
    }

    public func toString(): String {
        toCss()
    }

    /// 跳过已解析的部分，返回剩余字符串
    private static func skipParsed(input: String): String {
        var i = 0
        // 跳过 <type> 或 identifier
        if (i < input.size && input[i] == '<') {
            i++
            while (i < input.size && input[i] != '>') { i++ }
            if (i < input.size) { i++ }
        } else {
            while (i < input.size && CssSyntaxComponent.isNameCodePoint(UInt8(input[i]))) { i++ }
        }
        // 跳过倍率
        if (i < input.size && (input[i] == '+' || input[i] == '#')) { i++ }
        if (i < input.size) {
            input.substring(i)
        } else {
            ""
        }
    }
}

/// 解析后的组件值
/// 严格翻译自 ParsedComponent union(enum)
/// SyntaxString.parseValue 的返回类型
public class CssParsedComponent {
    public var kind: CssParsedComponentKind
    public var textValue: String
    public var components: ArrayList<CssParsedComponent>
    public var multiplier: CssSyntaxMultiplier

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
            case Repeated => {
                var parts = ArrayList<String>()
                for (comp in components) {
                    parts.append(comp.toCss())
                }
                match (multiplier) {
                    case Comma => String.join(", ", parts)
                    case Space => String.join(" ", parts)
                    case None => textValue
                }
            }
            case _ => textValue
        }
    }

    public func toString(): String {
        toCss()
    }
}
