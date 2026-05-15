// bao_css - CSS @container 容器规则
// 严格翻译自: bun/src/css/rules/container.rs
//   对应: rules/container.zig - ContainerName, ContainerSizeFeatureId,
//     ContainerCondition, StyleQuery, ContainerRule
package bao.css

import bao_core.*
import bao_collections.*

// ============================================================================
// 容器名称
// 严格翻译自: rules/container.rs ContainerName struct
// ============================================================================

/// CSS <container-name>
/// 严格翻译自 ContainerName struct { v: CustomIdent }
/// 容器查询的名称
public class CssContainerName {
    /// 容器名称
    public var name: String

    public init(name: String) {
        this.name = name
    }

    /// 深拷贝
    public func deepClone(): CssContainerName {
        CssContainerName(name)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 ContainerName.to_css
    public func toCss(): String {
        name
    }

    public func toString(): String {
        name
    }
}

// ============================================================================
// 容器尺寸特征 ID
// 严格翻译自: rules/container.rs ContainerSizeFeatureId enum
// ============================================================================

/// CSS 容器尺寸特征标识
/// 严格翻译自 ContainerSizeFeatureId enum
public enum CssContainerSizeFeatureId {
    | Width         // width 尺寸容器特征
    | Height        // height 尺寸容器特征
    | InlineSize    // inline-size 尺寸容器特征
    | BlockSize     // block-size 尺寸容器特征
    | AspectRatio   // aspect-ratio 尺寸容器特征
    | Orientation   // orientation 尺寸容器特征

    /// 获取值类型
    /// 严格翻译自 FeatureIdTrait.value_type
    public func valueType(): CssMediaFeatureType {
        match (this) {
            case Width => CssMediaFeatureType.Length
            case Height => CssMediaFeatureType.Length
            case InlineSize => CssMediaFeatureType.Length
            case BlockSize => CssMediaFeatureType.Length
            case AspectRatio => CssMediaFeatureType.Ratio
            case Orientation => CssMediaFeatureType.Ident
        }
    }

    /// 转为 CSS 文本
    public func toCss(): String {
        match (this) {
            case Width => "width"
            case Height => "height"
            case InlineSize => "inline-size"
            case BlockSize => "block-size"
            case AspectRatio => "aspect-ratio"
            case Orientation => "orientation"
        }
    }
}

// ============================================================================
// 媒体特征类型
// ============================================================================

/// CSS 媒体特征值类型
/// 严格翻译自 MediaFeatureType enum
public enum CssMediaFeatureType {
    | Length
    | Ratio
    | Ident
    | Boolean
    | Integer
    | Resolution
}

// ============================================================================
// 查询运算符
// ============================================================================

/// CSS 查询条件运算符
/// 严格翻译自 Operator enum
public enum CssQueryOperator {
    | And
    | Or
}

// ============================================================================
// 样式查询
// 严格翻译自: rules/container.rs StyleQuery enum
// ============================================================================

/// CSS 样式查询
/// 严格翻译自 StyleQuery enum { Feature(Property), Not(Box<StyleQuery>), Operation { operator, conditions } }
/// 表示容器条件中的样式查询
public class CssStyleQuery {
    public enum CssStyleQueryKind {
        | Feature      // 样式特征
        | Not          // 否定
        | Operation    // 操作 (and/or)
    }

    public var kind: CssStyleQueryKind
    /// 特征属性名
    public var featureProperty: String
    /// 特征值
    public var featureValue: String
    /// 否定子条件
    public var notCondition: ?CssStyleQuery
    /// 操作运算符
    public var operator: CssQueryOperator
    /// 操作条件列表
    public var conditions: ArrayList<CssStyleQuery>

    public init(featureProperty: String, featureValue: String) {
        this.kind = CssStyleQueryKind.Feature
        this.featureProperty = featureProperty
        this.featureValue = featureValue
        this.notCondition = None
        this.operator = CssQueryOperator.And
        this.conditions = ArrayList<CssStyleQuery>()
    }

    public init(not: CssStyleQuery) {
        this.kind = CssStyleQueryKind.Not
        this.featureProperty = ""
        this.featureValue = ""
        this.notCondition = Some(not)
        this.operator = CssQueryOperator.And
        this.conditions = ArrayList<CssStyleQuery>()
    }

    public init(operator: CssQueryOperator, conditions: ArrayList<CssStyleQuery>) {
        this.kind = CssStyleQueryKind.Operation
        this.featureProperty = ""
        this.featureValue = ""
        this.notCondition = None
        this.operator = operator
        this.conditions = conditions
    }

    /// 深拷贝
    /// 严格翻译自 StyleQuery.deep_clone
    public func deepClone(): CssStyleQuery {
        match (kind) {
            case Feature => CssStyleQuery(featureProperty, featureValue)
            case Not => {
                match (notCondition) {
                    case Some(c) => CssStyleQuery(c.deepClone())
                    case None => CssStyleQuery("", "")
                }
            }
            case Operation => {
                let newConditions = ArrayList<CssStyleQuery>()
                for (c in conditions) {
                    newConditions.append(c.deepClone())
                }
                CssStyleQuery(operator, newConditions)
            }
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 StyleQuery.to_css → condition_to_css
    public func toCss(): String {
        match (kind) {
            case Feature => "(${featureProperty}: ${featureValue})"
            case Not => {
                match (notCondition) {
                    case Some(c) => "not ${c.toCss()}"
                    case None => ""
                }
            }
            case Operation => {
                let parts = ArrayList<String>()
                for (c in conditions) {
                    parts.append(c.toCss())
                }
                let sep = match (operator) {
                    case And => " and "
                    case Or => " or "
                }
                String.join(sep, parts)
            }
        }
    }
}

// ============================================================================
// 容器条件
// 严格翻译自: rules/container.rs ContainerCondition enum
// ============================================================================

/// CSS 容器条件
/// 严格翻译自 ContainerCondition enum { Feature, Not, Operation, Style }
/// 表示 @container 规则的条件
public class CssContainerCondition {
    public enum CssContainerConditionKind {
        | Feature      // 尺寸特征
        | Not          // 否定
        | Operation    // 操作 (and/or)
        | Style        // 样式查询
    }

    public var kind: CssContainerConditionKind
    /// 尺寸特征名
    public var featureName: String
    /// 尺寸特征值
    public var featureValue: String
    /// 否定子条件
    public var notCondition: ?CssContainerCondition
    /// 操作运算符
    public var operator: CssQueryOperator
    /// 操作条件列表
    public var conditions: ArrayList<CssContainerCondition>
    /// 样式查询
    public var styleQuery: ?CssStyleQuery

    public init(featureName: String, featureValue: String) {
        this.kind = CssContainerConditionKind.Feature
        this.featureName = featureName
        this.featureValue = featureValue
        this.notCondition = None
        this.operator = CssQueryOperator.And
        this.conditions = ArrayList<CssContainerCondition>()
        this.styleQuery = None
    }

    public init(not: CssContainerCondition) {
        this.kind = CssContainerConditionKind.Not
        this.featureName = ""
        this.featureValue = ""
        this.notCondition = Some(not)
        this.operator = CssQueryOperator.And
        this.conditions = ArrayList<CssContainerCondition>()
        this.styleQuery = None
    }

    public init(operator: CssQueryOperator, conditions: ArrayList<CssContainerCondition>) {
        this.kind = CssContainerConditionKind.Operation
        this.featureName = ""
        this.featureValue = ""
        this.notCondition = None
        this.operator = operator
        this.conditions = conditions
        this.styleQuery = None
    }

    public init(style: CssStyleQuery) {
        this.kind = CssContainerConditionKind.Style
        this.featureName = ""
        this.featureValue = ""
        this.notCondition = None
        this.operator = CssQueryOperator.And
        this.conditions = ArrayList<CssContainerCondition>()
        this.styleQuery = Some(style)
    }

    /// 深拷贝
    /// 严格翻译自 ContainerCondition.deep_clone
    public func deepClone(): CssContainerCondition {
        match (kind) {
            case Feature => CssContainerCondition(featureName, featureValue)
            case Not => {
                match (notCondition) {
                    case Some(c) => CssContainerCondition(c.deepClone())
                    case None => CssContainerCondition("", "")
                }
            }
            case Operation => {
                let newConditions = ArrayList<CssContainerCondition>()
                for (c in conditions) {
                    newConditions.append(c.deepClone())
                }
                CssContainerCondition(operator, newConditions)
            }
            case Style => {
                match (styleQuery) {
                    case Some(q) => CssContainerCondition(q.deepClone())
                    case None => CssContainerCondition("", "")
                }
            }
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 ContainerCondition.to_css → condition_to_css
    public func toCss(): String {
        match (kind) {
            case Feature => "(${featureName}: ${featureValue})"
            case Not => {
                match (notCondition) {
                    case Some(c) => "not ${c.toCss()}"
                    case None => ""
                }
            }
            case Operation => {
                let parts = ArrayList<String>()
                for (c in conditions) {
                    parts.append(c.toCss())
                }
                let sep = match (operator) {
                    case And => " and "
                    case Or => " or "
                }
                String.join(sep, parts)
            }
            case Style => {
                match (styleQuery) {
                    case Some(q) => "style(${q.toCss()})"
                    case None => ""
                }
            }
        }
    }
}

// ============================================================================
// @container 规则
// 严格翻译自: rules/container.rs ContainerRule<R>
// ============================================================================

/// CSS @container 规则
/// 严格翻译自 ContainerRule struct { name, condition, rules, loc }
/// 表示一个 @container 规则
public class CssContainerRuleFull {
    /// 容器名称 (可选)
    public var name: ?CssContainerName
    /// 容器条件
    public var condition: CssContainerCondition
    /// 子规则列表
    public var rules: CssRuleList
    /// 位置信息
    public var loc: CssLocation

    public init(name: ?CssContainerName, condition: CssContainerCondition, rules: CssRuleList) {
        this.name = name
        this.condition = condition
        this.rules = rules
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 ContainerRule.deep_clone
    public func deepClone(): CssContainerRuleFull {
        let clonedName = match (name) {
            case Some(n) => Some(n.deepClone())
            case None => None
        }
        CssContainerRuleFull(clonedName, condition.deepClone(), rules.deepClone())
    }

    /// 转为 CSS 文本
    /// 严格翻译自 ContainerRule.to_css
    public func toCss(indent: String): String {
        let sb = StringBuilder()
        match (name) {
            case Some(n) => sb.append("${indent}@container ${n.toCss()} ${condition.toCss()} {\n")
            case None => sb.append("${indent}@container ${condition.toCss()} {\n")
        }
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
