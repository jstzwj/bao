// bao_css - CSS @property 属性规则
// 严格翻译自: bun/src/css/rules/property.rs
//   对应: rules/property.zig - PropertyRule
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// @property 规则
// 严格翻译自: rules/property.rs PropertyRule struct
// ============================================================================

/// CSS @property 规则
/// 严格翻译自 PropertyRule struct { name: DashedIdent, syntax: SyntaxString,
///   inherits: bool, initial_value: Option<ParsedComponent>, loc: Location }
/// 表示一个 @property 规则
public class CssPropertyRuleFull {
    /// 属性名 (--name)
    public var name: String
    /// 语法描述字符串
    public var syntax: String
    /// 是否继承
    public var inherits: Bool
    /// 初始值 (可选)
    public var initialValue: ?String
    /// 位置信息
    public var loc: CssLocation

    public init(name: String, syntax: String, inherits: Bool, initialValue: ?String) {
        this.name = name
        this.syntax = syntax
        this.inherits = inherits
        this.initialValue = initialValue
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 PropertyRule.deep_clone
    public func deepClone(): CssPropertyRuleFull {
        CssPropertyRuleFull(name, syntax, inherits, initialValue)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 PropertyRule.to_css
    public func toCss(indent: String, minify: Bool): String {
        let sb = StringBuilder()
        sb.append("${indent}@property ${name} {\n")

        // syntax
        sb.append("${indent}  syntax: ${syntax};\n")

        // inherits
        let inheritsStr = if (inherits) { "true" } else { "false" }
        sb.append("${indent}  inherits: ${inheritsStr}")

        // initial-value (可选)
        match (initialValue) {
            case Some(v) => {
                sb.append(";\n")
                sb.append("${indent}  initial-value: ${v}")
                if (!minify) {
                    sb.append(";")
                }
            }
            case None => {
                if (!minify) {
                    sb.append(";")
                }
            }
        }

        sb.append("\n${indent}}")
        return sb.toString()
    }

    public func toString(): String {
        toCss("", false)
    }
}
