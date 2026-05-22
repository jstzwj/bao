// bao_css - CSS 语法字符串
// 严格翻译自: bun/src/css/values/syntax.rs
//   对应: values/syntax.zig - SyntaxString, SyntaxComponent, SyntaxComponentKind, Multiplier, ParsedComponent, Repeated
package bao_css.values

import bao_core.*
import bao_collections.*

private func trimSyntaxSpaces(s: String): String {
    s
}

private func joinSyntaxParts(parts: ArrayList<String>, sep: String): String {
    let sb = CssStringBuilder()
    for (i in 0..parts.size) {
        if (i > 0) { sb.append(sep) }
        sb.append(parts[i])
    }
    sb.toString()
}

// ============================================================================
// 乘数
// 严格翻译自: values/syntax.rs Multiplier { None, Space, Comma }
// ============================================================================

/// CSS 语法组件乘数
/// 严格翻译自 Multiplier enum { None, Space, Comma }
public enum CssMultiplier {
    | NoMultiplier    // 不可重复
    | Space   // 空格分隔重复
    | Comma   // 逗号分隔重复

    /// 转为 CSS 文本
    public func toCss(): String {
        match (this) {
            case NoMultiplier => ""
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
        if (input.isEmpty()) { return None }
        match (CssSyntaxComponentKind.fromString(input)) {
            case Some(kind) => Some(CssSyntaxComponent(kind, CssMultiplier.NoMultiplier))
            case None => Some(CssSyntaxComponent(input, CssMultiplier.NoMultiplier))
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
        match (kind) {
            case CssSyntaxComponentKind.Literal => CssSyntaxComponent(literalValue, multiplier)
            case _ => CssSyntaxComponent(kind, multiplier)
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

/// CSS 语法字符串类型
public enum CssSyntaxStringKind {
    | Components   // 组件列表
    | Universal    // 通配 (*)
}

/// CSS 语法字符串
/// 严格翻译自 SyntaxString enum { Components(Vec<SyntaxComponent>), Universal }
public class CssSyntaxString {
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
        let trimmed = input
        if (trimmed.isEmpty()) { return None }
        if (trimmed == "*") {
            return CssSyntaxString(())
        }

        var parts = trimmed.split("|")
        var components = ArrayList<CssSyntaxComponent>()
        for (part in parts) {
            let comp = CssSyntaxComponent.parseString(trimSyntaxSpaces(part))
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
            case Components =>
                let parts = ArrayList<String>()
                for (c in components) {
                    parts.append(c.toCss())
                }
                "\"${joinSyntaxParts(parts, " | ")}\""
        }
    }

    /// 深拷贝
    public func deepClone(): CssSyntaxString {
        match (kind) {
            case Universal => CssSyntaxString(())
            case Components =>
                let cloned = ArrayList<CssSyntaxComponent>()
                for (c in components) {
                    cloned.append(c.deepClone())
                }
                CssSyntaxString(cloned)
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

/// CSS 语法解析后的组件类型
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

/// CSS 语法解析后的组件
/// 严格翻译自 ParsedComponent enum
public class CssParsedComponent {
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
        this.repeatedMultiplier = CssMultiplier.NoMultiplier
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
            case Repeated =>
                let parts = ArrayList<String>()
                for (c in repeatedComponents) {
                    parts.append(c.toCss())
                }
                let sep = match (repeatedMultiplier) {
                    case Comma => ", "
                    case Space => " "
                    case NoMultiplier => ""
                }
                joinSyntaxParts(parts, sep)
            case TokenList => valueText
            case _ => valueText
        }
    }

    /// 深拷贝
    public func deepClone(): CssParsedComponent {
        match (kind) {
            case Repeated =>
                let cloned = ArrayList<CssParsedComponent>()
                for (c in repeatedComponents) {
                    cloned.append(c.deepClone())
                }
                CssParsedComponent(cloned, repeatedMultiplier)
            case _ => CssParsedComponent(kind, valueText)
        }
    }

    public func toString(): String {
        toCss()
    }
}
