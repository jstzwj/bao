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
public enum CssSupportsConditionKind {
    | Not           // not 表达式
    | And           // and 表达式
    | Or            // or 表达式
    | Declaration   // 声明评估
    | Selector      // 选择器评估
    | Unknown       // 未知条件

    public func toString(): String {
        match (this) {
            case Not => "Not"
            case And => "And"
            case Or => "Or"
            case Declaration => "Declaration"
            case Selector => "Selector"
            case Unknown => "Unknown"
        }
    }

    public operator func ==(rhs: CssSupportsConditionKind): Bool {
        this.toString() == rhs.toString()
    }

    public operator func !=(rhs: CssSupportsConditionKind): Bool {
        !(this == rhs)
    }
}

public class CssSupportsCondition {
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

    public init(kind!: CssSupportsConditionKind, conditions!: ArrayList<CssSupportsCondition>) {
        this.kind = kind
        this.notCondition = None
        this.conditions = conditions
        this.declaration = None
        this.selector = ""
        this.unknown = ""
    }

    public static func and(conditions: ArrayList<CssSupportsCondition>): CssSupportsCondition {
        CssSupportsCondition(kind: CssSupportsConditionKind.And, conditions: conditions)
    }

    public static func or(conditions: ArrayList<CssSupportsCondition>): CssSupportsCondition {
        CssSupportsCondition(kind: CssSupportsConditionKind.Or, conditions: conditions)
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

    private func deepCloneNot(): CssSupportsCondition {
        match (notCondition) {
            case Some(c) => CssSupportsCondition(c.deepClone())
            case None => CssSupportsCondition("", CssSupportsConditionKind.Unknown)
        }
    }

    private func deepCloneAnd(): CssSupportsCondition {
        let newConds = ArrayList<CssSupportsCondition>()
        for (c in conditions) {
            newConds.append(c.deepClone())
        }
        CssSupportsCondition(kind: CssSupportsConditionKind.And, conditions: newConds)
    }

    private func deepCloneOr(): CssSupportsCondition {
        let newConds = ArrayList<CssSupportsCondition>()
        for (c in conditions) {
            newConds.append(c.deepClone())
        }
        CssSupportsCondition(kind: CssSupportsConditionKind.Or, conditions: newConds)
    }

    private func deepCloneDeclaration(): CssSupportsCondition {
        match (declaration) {
            case Some(d) => CssSupportsCondition(d.deepClone())
            case None => CssSupportsCondition("", CssSupportsConditionKind.Unknown)
        }
    }

    /// 深拷贝
    /// 严格翻译自 SupportsCondition.deep_clone
    public func deepClone(): CssSupportsCondition {
        match (kind) {
            case Not => deepCloneNot()
            case And => deepCloneAnd()
            case Or => deepCloneOr()
            case Declaration => deepCloneDeclaration()
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

    private func notChildToCss(c: CssSupportsCondition): String {
        let css = c.toCss()
        if (c.needsParens(this)) {
            " not (${css})"
        } else {
            " not ${css}"
        }
    }

    private func notToCss(): String {
        match (notCondition) {
            case Some(c) => notChildToCss(c)
            case None => ""
        }
    }

    private func conditionsToCss(sep: String): String {
        let parts = ArrayList<String>()
        for (c in conditions) {
            let css = c.toCss()
            if (c.needsParens(this)) {
                parts.append("(${css})")
            } else {
                parts.append(css)
            }
        }
        var partArr = Array<String>(parts.size, repeat: "")
        var pi: Int64 = 0
        for (p in parts) { partArr[pi] = p; pi += 1 }
        String.join(partArr, delimiter: sep)
    }

    private func declarationToCss(): String {
        match (declaration) {
            case Some(d) => "(${d.propertyId}: ${d.value})"
            case None => ""
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 SupportsCondition.to_css
    public func toCss(): String {
        match (kind) {
            case Not => notToCss()
            case And => conditionsToCss(" and ")
            case Or => conditionsToCss(" or ")
            case Declaration => declarationToCss()
            case Selector => "selector(${selector})"
            case Unknown => unknown
        }
    }

    /// 相等比较
    /// 严格翻译自 SupportsCondition.eql
    public func eql(other: CssSupportsCondition): Bool {
        if (!(kind == other.kind)) { return false }
        eqlInner(other)
    }

    private func eqlNot(other: CssSupportsCondition): Bool {
        match (notCondition) {
            case Some(a) => match (other.notCondition) { case Some(b) => a.eql(b) case None => false }
            case None => match (other.notCondition) { case None => true case Some(_) => false }
        }
    }

    private func eqlConditions(other: CssSupportsCondition): Bool {
        if (conditions.size != other.conditions.size) { return false }
        var i: Int64 = 0
        while (i < conditions.size) {
            if (!conditions[i].eql(other.conditions[i])) { return false }
            i += 1
        }
        true
    }

    private func eqlDeclaration(other: CssSupportsCondition): Bool {
        match (declaration) {
            case Some(a) => match (other.declaration) { case Some(b) => a.eql(b) case None => false }
            case None => match (other.declaration) { case None => true case Some(_) => false }
        }
    }

    private func eqlInner(other: CssSupportsCondition): Bool {
        match (kind) {
            case Not => eqlNot(other)
            case And => eqlConditions(other)
            case Or => eqlConditions(other)
            case Declaration => eqlDeclaration(other)
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
        sb.append(indent)
        sb.append("@supports ")
        sb.append(condition.toCss())
        sb.append(" {\n")
        for (rule in rules.v) {
            let css = rule.toString()
            if (css.size > 0) {
                sb.append(indent)
                sb.append("  ")
                sb.append(css)
                sb.append("\n")
            }
        }
        sb.append(indent)
        sb.append("}")
        return sb.toString()
    }

    public func toString(): String {
        toCss("")
    }
}
