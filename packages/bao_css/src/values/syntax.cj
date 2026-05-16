// bao_css - CSS 语法字符串
// 严格翻译自: bun/src/css/values/syntax.rs
//   对应: values/syntax.zig - SyntaxString, SyntaxComponent, SyntaxComponentKind, Multiplier, ParsedComponent, Repeated
package bao_css.values

import bao_core.*
import bao_collections.*

// ============================================================================
// 乘数
// 严格翻译自: values/syntax.rs Multiplier { None, Space, Comma }
// ============================================================================

/// CSS 语法组件乘数
/// 严格翻译自 Multiplier enum { None, Space, Comma }
public enum CssMultiplier {
    | None    // 不可重复
    | Space   // 空格分隔重复
    | Comma   // 逗号分隔重复

    /// 转为 CSS 文本
    public func toCss(): String {
        match (this) {
            case None => ""
            case Space => "+"
            case Comma => "#"
        }
    }
}

// ============================================================================
// 语法组件类型
// 严格翻译自: values/syntax.rs SyntaxComponentKind
// ============================================================================

/// CSS 语法组件类型
/// 严格翻译自 SyntaxComponentKind enum
public enum CssSyntaxComponentKind {
    | Length             // <length>
    | Number             // <number>
    | Percentage         // <percentage>
    | LengthPercentage   // <length-percentage>
    | Color              // <color>
    | Image              // <image>
    | Url                // <url>
    | Integer            // <integer>
    | Angle              // <angle>
    | Time               // <time>
    | Resolution         // <resolution>
    | TransformFunction  // <transform-function>
    | TransformList      // <transform-list>
    | CustomIdent        // <custom-ident>
    | Literal            // 字面量

    /// 获取类型名称
    /// 严格翻译自 SyntaxComponentKind::to_css
    public func typeName(): String {
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

    /// 从字符串解析
    /// 严格翻译自 SyntaxComponentKind::parse_string
    public static func fromString(name: String): ?CssSyntaxComponentKind {
        let lower = name.toLower()
        match (lower) {
            "length" => Some(CssSyntaxComponentKind.Length)
            "number" => Some(CssSyntaxComponentKind.Number)
            "percentage" => Some(CssSyntaxComponentKind.Percentage)
            "length-percentage" => Some(CssSyntaxComponentKind.LengthPercentage)
            "color" => Some(CssSyntaxComponentKind.Color)
            "image" => Some(CssSyntaxComponentKind.Image)
            "url" => Some(CssSyntaxComponentKind.Url)
            "integer" => Some(CssSyntaxComponentKind.Integer)
            "angle" => Some(CssSyntaxComponentKind.Angle)
            "time" => Some(CssSyntaxComponentKind.Time)
            "resolution" => Some(CssSyntaxComponentKind.Resolution)
            "transform-function" => Some(CssSyntaxComponentKind.TransformFunction)
            "transform-list" => Some(CssSyntaxComponentKind.TransformList)
            "custom-ident" => Some(CssSyntaxComponentKind.CustomIdent)
            case _ => None
        }
    }
}

// ============================================================================
// 语法组件
// 严格翻译自: values/syntax.rs SyntaxComponent { kind, multiplier }
// ============================================================================

/// CSS 语法组件
/// 严格翻译自 SyntaxComponent struct { kind: SyntaxComponentKind, multiplier: Multiplier }
public class CssSyntaxComponent {
    public var kind: CssSyntaxComponentKind
    public var multiplier: CssMultiplier
    /// 字面量值 (仅 kind == Literal 时有值)
    public var literalValue: String

    public init(kind: CssSyntaxComponentKind, multiplier: CssMultiplier) {
        this.kind = kind
        this.multiplier = multiplier
        this.literalValue = ""
    }

    public init(literal: String, multiplier: CssMultiplier) {
        this.kind = CssSyntaxComponentKind.Literal
        this.multiplier = multiplier
        this.literalValue = literal
    }

    /// 从字符串解析
    /// 严格翻译自 SyntaxComponent::parse_string
    public static func parseString(input: String): ?CssSyntaxComponent {
        let trimmed = input.trimStart(Array<UInt8>(' '))
        if (trimmed.isEmpty()) { return None }

        let kind: ?CssSyntaxComponentKind
        var remaining = trimmed

        if (trimmed.startsWith("<")) {
            // 数据类型
            let endIdx = trimmed.indexOf('>')
            match (endIdx) {
                case Some(idx) => {
                    let name = trimmed.subString(1, idx - 1)
                    kind = CssSyntaxComponentKind.fromString(name)
                    remaining = if (idx + 1 < trimmed.size) { trimmed.subString(idx + 1) } else { "" }
                }
                case None => return None
            }
        } else {
            // 字面量标识符
            kind = Some(CssSyntaxComponentKind.Literal)
            remaining = ""
        }

        let k = match (kind) {
            case Some(kk) => kk
            case None => return None
        }

        // 检查乘数
        var mult = CssMultiplier.None
        if (remaining.size > 0) {
            if (remaining[0] == '+') {
                mult = CssMultiplier.Space
            } else if (remaining[0] == '#') {
                mult = CssMultiplier.Comma
            }
        }

        // TransformList 不允许乘数
        if (k == CssSyntaxComponentKind.TransformList) {
            mult = CssMultiplier.None
        }

        if (k == CssSyntaxComponentKind.Literal) {
            CssSyntaxComponent(literal: trimmed, multiplier: mult)
        } else {
            Some(CssSyntaxComponent(k, mult))
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 SyntaxComponent::to_css
    public func toCss(): String {
        let base = match (kind) {
            case CssSyntaxComponentKind.Literal => literalValue
            case _ => kind.typeName()
        }
        "${base}${multiplier.toCss()}"
    }

    /// 深拷贝
    public func deepClone(): CssSyntaxComponent {
        if (kind == CssSyntaxComponentKind.Literal) {
            CssSyntaxComponent(literal: literalValue, multiplier: multiplier)
        } else {
            CssSyntaxComponent(kind, multiplier)
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 语法字符串
// 严格翻译自: values/syntax.rs SyntaxString { Components, Universal }
// ============================================================================

/// CSS 语法字符串
/// 严格翻译自 SyntaxString enum { Components(Vec<SyntaxComponent>), Universal }
public class CssSyntaxString {
    public enum CssSyntaxStringKind {
        | Components   // 组件列表
        | Universal    // 通配 (*)
    }

    public var kind: CssSyntaxStringKind
    public var components: ArrayList<CssSyntaxComponent>

    public init(components: ArrayList<CssSyntaxComponent>) {
        this.kind = CssSyntaxStringKind.Components
        this.components = components
    }

    public init(universal: Unit) {
        this.kind = CssSyntaxStringKind.Universal
        this.components = ArrayList<CssSyntaxComponent>()
    }

    /// 从字符串解析
    /// 严格翻译自 SyntaxString::parse_string
    public static func parseString(input: String): ?CssSyntaxString {
        let trimmed = input.trim()
        if (trimmed.isEmpty()) { return None }
        if (trimmed == "*") {
            return CssSyntaxString(universal: ())
        }

        var parts = trimmed.split("|")
        var components = ArrayList<CssSyntaxComponent>()
        for (part in parts) {
            let comp = CssSyntaxComponent.parseString(part.trim())
            match (comp) {
                case Some(c) => components.append(c)
                case None => return None
            }
        }

        if (components.isEmpty()) {
            None
        } else {
            CssSyntaxString(components)
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 SyntaxString::to_css
    public func toCss(): String {
        match (kind) {
            case Universal => "\"*\""
            case Components => {
                let parts = ArrayList<String>()
                for (c in components) {
                    parts.append(c.toCss())
                }
                "\"${String.join(" | ", parts)}\""
            }
        }
    }

    /// 深拷贝
    public func deepClone(): CssSyntaxString {
        match (kind) {
            case Universal => CssSyntaxString(universal: ())
            case Components => {
                let cloned = ArrayList<CssSyntaxComponent>()
                for (c in components) {
                    cloned.append(c.deepClone())
                }
                CssSyntaxString(cloned)
            }
        }
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// 解析后的组件
// 严格翻译自: values/syntax.rs ParsedComponent
// ============================================================================

/// CSS 语法解析后的组件
/// 严格翻译自 ParsedComponent enum
public class CssParsedComponent {
    public enum CssParsedComponentKind {
        | Length             // <length> 值
        | Number             // <number> 值
        | Percentage         // <percentage> 值
        | LengthPercentage   // <length-percentage> 值
        | Color              // <color> 值
        | Image              // <image> 值
        | Url                // <url> 值
        | Integer            // <integer> 值
        | Angle              // <angle> 值
        | Time               // <time> 值
        | Resolution         // <resolution> 值
        | TransformFunction  // <transform-function> 值
        | TransformList      // <transform-list> 值
        | CustomIdent        // <custom-ident> 值
        | Literal            // 字面量值
        | Repeated           // 重复组件
        | TokenList          // 原始 token 流
    }

    public var kind: CssParsedComponentKind
    /// 值的 CSS 文本表示
    public var valueText: String
    /// 重复的子组件
    public var repeatedComponents: ArrayList<CssParsedComponent>
    /// 重复的乘数
    public var repeatedMultiplier: CssMultiplier

    public init(kind: CssParsedComponentKind, value: String) {
        this.kind = kind
        this.valueText = value
        this.repeatedComponents = ArrayList<CssParsedComponent>()
        this.repeatedMultiplier = CssMultiplier.None
    }

    public init(repeated: ArrayList<CssParsedComponent>, multiplier: CssMultiplier) {
        this.kind = CssParsedComponentKind.Repeated
        this.valueText = ""
        this.repeatedComponents = repeated
        this.repeatedMultiplier = multiplier
    }

    /// 转为 CSS 文本
    /// 严格翻译自 ParsedComponent::to_css
    public func toCss(): String {
        match (kind) {
            case Repeated => {
                let parts = ArrayList<String>()
                for (c in repeatedComponents) {
                    parts.append(c.toCss())
                }
                let sep = match (repeatedMultiplier) {
                    case Comma => ", "
                    case Space => " "
                    case None => ""
                }
                String.join(sep, parts)
            }
            case TokenList => valueText
            case _ => valueText
        }
    }

    /// 深拷贝
    public func deepClone(): CssParsedComponent {
        match (kind) {
            case Repeated => {
                let cloned = ArrayList<CssParsedComponent>()
                for (c in repeatedComponents) {
                    cloned.append(c.deepClone())
                }
                CssParsedComponent(repeated: cloned, multiplier: repeatedMultiplier)
            }
            case _ => CssParsedComponent(kind, valueText)
        }
    }

    public func toString(): String {
        toCss()
    }
}
