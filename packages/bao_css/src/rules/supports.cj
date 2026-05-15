// bao_css - CSS @supports 支持规则
// 严格翻译自: bun/src/css/rules/supports.rs
//   对应: rules/supports.zig - SupportsCondition, Declaration, SupportsRule
package bao_css.rules

import bao_core.*
import bao_collections.*

// ============================================================================
// Supports 声明
// 严格翻译自: rules/supports.rs Declaration struct
// ============================================================================

/// CSS @supports 声明条件
/// 严格翻译自 Declaration struct { property_id: PropertyId, value: &'static [u8] }
/// 表示 @supports 中要评估的声明
public class CssSupportsDeclaration {
    /// 属性 ID
    public var propertyId: String
    /// 属性值
    public var value: String

    public init(propertyId: String, value: String) {
        this.propertyId = propertyId
        this.value = value
    }

    /// 深拷贝
    public func deepClone(): CssSupportsDeclaration {
        CssSupportsDeclaration(propertyId, value)
    }

    /// 相等比较
    /// 严格翻译自 Declaration.eql
    public func eql(other: CssSupportsDeclaration): Bool {
        propertyId == other.propertyId && value == other.value
    }
}

// ============================================================================
// Supports 条件
// 严格翻译自: rules/supports.rs SupportsCondition enum
// ============================================================================

/// CSS <supports-condition>
/// 严格翻译自 SupportsCondition enum { Not, And, Or, Declaration, Selector, Unknown }
/// 用于 @supports 和 @import 规则
public class CssSupportsCondition {
    public enum CssSupportsConditionKind {
        | Not           // not 表达式
        | And           // and 表达式
        | Or            // or 表达式
        | Declaration   // 声明评估
        | Selector      // 选择器评估
        | Unknown       // 未知条件
    }

    public var kind: CssSupportsConditionKind
    /// not 子条件
    public var notCondition: ?CssSupportsCondition
    /// and/or 条件列表
    public var conditions: ArrayList<CssSupportsCondition>
    /// 声明条件
    public var declaration: ?CssSupportsDeclaration
    /// 选择器文本
    public var selector: String
    /// 未知条件文本
    public var unknown: String

    public init(not: CssSupportsCondition) {
        this.kind = CssSupportsConditionKind.Not
        this.notCondition = Some(not)
        this.conditions = ArrayList<CssSupportsCondition>()
        this.declaration = None
        this.selector = ""
        this.unknown = ""
    }

    public init(andConditions: ArrayList<CssSupportsCondition>) {
        this.kind = CssSupportsConditionKind.And
        this.notCondition = None
        this.conditions = andConditions
        this.declaration = None
        this.selector = ""
        this.unknown = ""
    }

    public init(orConditions: ArrayList<CssSupportsCondition>) {
        this.kind = CssSupportsConditionKind.Or
        this.notCondition = None
        this.conditions = orConditions
        this.declaration = None
        this.selector = ""
        this.unknown = ""
    }

    public init(declaration: CssSupportsDeclaration) {
        this.kind = CssSupportsConditionKind.Declaration
        this.notCondition = None
        this.conditions = ArrayList<CssSupportsCondition>()
        this.declaration = Some(declaration)
        this.selector = ""
        this.unknown = ""
    }

    public init(selector: String) {
        this.kind = CssSupportsConditionKind.Selector
        this.notCondition = None
        this.conditions = ArrayList<CssSupportsCondition>()
        this.declaration = None
        this.selector = selector
        this.unknown = ""
    }

    public init(unknown: String, kind: CssSupportsConditionKind) {
        this.kind = kind
        this.notCondition = None
        this.conditions = ArrayList<CssSupportsCondition>()
        this.declaration = None
        this.selector = ""
        this.unknown = unknown
    }

    /// 深拷贝
    /// 严格翻译自 SupportsCondition.deep_clone
    public func deepClone(): CssSupportsCondition {
        match (kind) {
            case Not => {
                match (notCondition) {
                    case Some(c) => CssSupportsCondition(c.deepClone())
                    case None => CssSupportsCondition("", CssSupportsConditionKind.Unknown)
                }
            }
            case And => {
                let newConds = ArrayList<CssSupportsCondition>()
                for (c in conditions) {
                    newConds.append(c.deepClone())
                }
                CssSupportsCondition(newConds)
            }
            case Or => {
                let newConds = ArrayList<CssSupportsCondition>()
                for (c in conditions) {
                    newConds.append(c.deepClone())
                }
                let cond = CssSupportsCondition(newConds)
                cond.kind = CssSupportsConditionKind.Or
                return cond
            }
            case Declaration => {
                match (declaration) {
                    case Some(d) => CssSupportsCondition(d.deepClone())
                    case None => CssSupportsCondition("", CssSupportsConditionKind.Unknown)
                }
            }
            case Selector => CssSupportsCondition(selector)
            case Unknown => CssSupportsCondition(unknown, CssSupportsConditionKind.Unknown)
        }
    }

    /// 是否需要括号
    /// 严格翻译自 SupportsCondition.needs_parens
    public func needsParens(parent: CssSupportsCondition): Bool {
        match (kind) {
            case Not => true
            case And => parent.kind != CssSupportsConditionKind.And
            case Or => parent.kind != CssSupportsConditionKind.Or
            case _ => false
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 SupportsCondition.to_css
    public func toCss(): String {
        match (kind) {
            case Not => {
                match (notCondition) {
                    case Some(c) => {
                        let css = c.toCss()
                        if (c.needsParens(this)) {
                            " not (${css})"
                        } else {
                            " not ${css}"
                        }
                    }
                    case None => ""
                }
            }
            case And => {
                let parts = ArrayList<String>()
                for (c in conditions) {
                    let css = c.toCss()
                    if (c.needsParens(this)) {
                        parts.append("(${css})")
                    } else {
                        parts.append(css)
                    }
                }
                String.join(" and ", parts)
            }
            case Or => {
                let parts = ArrayList<String>()
                for (c in conditions) {
                    let css = c.toCss()
                    if (c.needsParens(this)) {
                        parts.append("(${css})")
                    } else {
                        parts.append(css)
                    }
                }
                String.join(" or ", parts)
            }
            case Declaration => {
                match (declaration) {
                    case Some(d) => "(${d.propertyId}: ${d.value})"
                    case None => ""
                }
            }
            case Selector => "selector(${selector})"
            case Unknown => unknown
        }
    }

    /// 相等比较
    /// 严格翻译自 SupportsCondition.eql
    public func eql(other: CssSupportsCondition): Bool {
        if (kind != other.kind) { return false }
        match (kind) {
            case Not => {
                match (notCondition, other.notCondition) {
                    case (Some(a), Some(b)) => a.eql(b)
                    case _ => false
                }
            }
            case And => {
                if (conditions.size != other.conditions.size) { return false }
                for (i in 0..conditions.size) {
                    if (!conditions[i].eql(other.conditions[i])) { return false }
                }
                return true
            }
            case Or => {
                if (conditions.size != other.conditions.size) { return false }
                for (i in 0..conditions.size) {
                    if (!conditions[i].eql(other.conditions[i])) { return false }
                }
                return true
            }
            case Declaration => {
                match (declaration, other.declaration) {
                    case (Some(a), Some(b)) => a.eql(b)
                    case _ => false
                }
            }
            case Selector => selector == other.selector
            case Unknown => unknown == other.unknown
        }
    }
}

// ============================================================================
// @supports 规则
// 严格翻译自: rules/supports.rs SupportsRule<R>
// ============================================================================

/// CSS @supports 规则
/// 严格翻译自 SupportsRule struct { condition, rules, loc }
/// 表示一个 @supports 规则
public class CssSupportsRuleFull {
    /// supports 条件
    public var condition: CssSupportsCondition
    /// 子规则列表
    public var rules: CssRuleList
    /// 位置信息
    public var loc: CssLocation

    public init(condition: CssSupportsCondition, rules: CssRuleList) {
        this.condition = condition
        this.rules = rules
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 SupportsRule.deep_clone
    public func deepClone(): CssSupportsRuleFull {
        CssSupportsRuleFull(condition.deepClone(), rules.deepClone())
    }

    /// 转为 CSS 文本
    /// 严格翻译自 SupportsRule.to_css
    public func toCss(indent: String): String {
        let sb = StringBuilder()
        sb.append("${indent}@supports ${condition.toCss()} {\n")
        for (rule in rules.rules) {
            let css = rule.toCss(indent + "  ")
            if (css.length > 0) {
                sb.append("${indent}  ${css}\n")
            }
        }
        sb.append("${indent}}")
        return sb.toString()
    }

    public func toString(): String {
        toCss("")
    }
}
