// bao_css - CSS @layer 层规则
// 严格翻译自: bun/src/css/rules/layer.rs
//   对应: rules/layer.zig - LayerName, LayerBlockRule, LayerStatementRule
package bao_css.rules

import bao_core.*
import bao_collections.*

// ============================================================================
// 层名称
// 严格翻译自: rules/layer.rs LayerName struct
// ============================================================================

/// CSS 级联层名称
/// 严格翻译自 LayerName struct { v: SmallList<&'static [u8], 1> }
/// 存储为段列表，因为点号表示法 (a.b.c) 创建子层
public class CssLayerName {
    /// 层名称段列表
    public var segments: ArrayList<String>

    public init(segments: ArrayList<String>) {
        this.segments = segments
    }

    public init(name: String) {
        this.segments = ArrayList<String>()
        this.segments.append(name)
    }

    public init() {
        this.segments = ArrayList<String>()
    }

    /// 相等比较
    /// 严格翻译自 LayerName.eql
    public func eql(other: CssLayerName): Bool {
        if (segments.size != other.segments.size) { return false }
        for (i in 0..segments.size) {
            if (segments[i] != other.segments[i]) { return false }
        }
        return true
    }

    /// 深拷贝
    /// 严格翻译自 LayerName.deep_clone — 段是 Copy
    public func deepClone(): CssLayerName {
        let newSegments = ArrayList<String>()
        for (s in segments) {
            newSegments.append(s)
        }
        return CssLayerName(newSegments)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 LayerName.to_css — 段用点号分隔
    public func toCss(): String {
        String.join(".", segments)
    }

    /// 是否为空名称
    public func isEmpty(): Bool {
        segments.size == 0
    }

    public func toString(): String {
        toCss()
    }
}

// ============================================================================
// @layer 块规则
// 严格翻译自: rules/layer.rs LayerBlockRule<R>
// ============================================================================

/// CSS @layer 块规则
/// 严格翻译自 LayerBlockRule struct { name: Option<LayerName>, rules: CssRuleList<R>, loc: Location }
/// 表示一个 @layer 块规则
public class CssLayerBlockRuleFull {
    /// 层名称，None 为匿名层
    public var name: ?CssLayerName
    /// 子规则列表
    public var rules: CssRuleList
    /// 位置信息
    public var loc: CssLocation

    public init(name: ?CssLayerName, rules: CssRuleList) {
        this.name = name
        this.rules = rules
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 LayerBlockRule.deep_clone
    public func deepClone(): CssLayerBlockRuleFull {
        let clonedName = match (name) {
            case Some(n) => Some(n.deepClone())
            case None => None
        }
        CssLayerBlockRuleFull(clonedName, rules.deepClone())
    }

    /// 转为 CSS 文本
    /// 严格翻译自 LayerBlockRule.to_css
    public func toCss(indent: String): String {
        let sb = StringBuilder()
        match (name) {
            case Some(n) => sb.append("${indent}@layer ${n.toCss()} {\n")
            case None => sb.append("${indent}@layer {\n")
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

// ============================================================================
// @layer 声明规则
// 严格翻译自: rules/layer.rs LayerStatementRule
// ============================================================================

/// CSS @layer 声明规则
/// 严格翻译自 LayerStatementRule struct { names: SmallList<LayerName, 1>, loc: Location }
/// 表示一个 @layer 声明规则 (无块体，仅声明层名)
public class CssLayerStatementRuleFull {
    /// 层名称列表
    public var names: ArrayList<CssLayerName>
    /// 位置信息
    public var loc: CssLocation

    public init(names: ArrayList<CssLayerName>) {
        this.names = names
        this.loc = CssLocation()
    }

    /// 深拷贝
    /// 严格翻译自 LayerStatementRule.deep_clone
    public func deepClone(): CssLayerStatementRuleFull {
        let newNames = ArrayList<CssLayerName>()
        for (n in names) {
            newNames.append(n.deepClone())
        }
        return CssLayerStatementRuleFull(newNames)
    }

    /// 转为 CSS 文本
    /// 严格翻译自 LayerStatementRule.to_css
    public func toCss(): String {
        if (names.size > 0) {
            let nameStrs = ArrayList<String>()
            for (n in names) {
                nameStrs.append(n.toCss())
            }
            return "@layer ${String.join(", ", nameStrs)};"
        }
        return "@layer;"
    }

    public func toString(): String {
        toCss()
    }
}
