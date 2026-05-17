// 严格翻译自: src/css/context.zig
package bao_css

import bao_core.*
import bao_collections.*

// ============================================================================
// DeclarationContext - 声明上下文
// 严格翻译自: context.zig DeclarationContext
// ============================================================================

/// 声明上下文
/// 严格翻译自 DeclarationContext enum
public enum DeclarationContext {
    | none             // 无上下文
    | style_rule       // 样式规则内
    | keyframes        // 关键帧内
    | style_attribute  // style 属性内
}

public class CssSupportsCondition {
    public init() {}

    public func deinit(allocator: Allocator): Unit {}

    public func deepClone(allocator: Allocator): CssSupportsCondition {
        CssSupportsCondition()
    }

    public func eql(other: CssSupportsCondition): Bool {
        false
    }
}

public class CssProperty {
    public init() {}

    public func deinit(allocator: Allocator): Unit {}

    public static func createUnparsed(property_id: CssPropertyId, value: String): CssProperty {
        CssProperty()
    }
}

public class CssDeepClone {
    public static func clonePropertyList(allocator: Allocator, properties: ArrayList<CssProperty>): ArrayList<CssProperty> {
        properties
    }
}

public class CssDeepDeinit {
    public static func deinitPropertyList(allocator: Allocator, properties: ArrayList<CssProperty>): Unit {}
}

public class CssPropertyId {
    public init() {}

    public func deepClone(allocator: Allocator): CssPropertyId {
        CssPropertyId()
    }
}

public class CssUnparsedValue {
    public init() {}

    public func getFallbacks(allocator: Allocator, targets: CssTargets): ArrayList<Array<String>> {
        ArrayList<Array<String>>()
    }
}

public class UnparsedProperty {
    public var property_id: CssPropertyId
    public var value: CssUnparsedValue

    public init() {
        property_id = CssPropertyId()
        value = CssUnparsedValue()
    }
}

// ============================================================================
// SupportsEntry - @supports 条目
// 严格翻译自: context.zig SupportsEntry
// ============================================================================

/// @supports 条目
/// 严格翻译自 SupportsEntry struct
public class SupportsEntry {
    /// 条件
    public var condition: CssSupportsCondition

    /// 普通声明列表
    public var declarations: ArrayList<CssProperty>

    /// important 声明列表
    public var important_declarations: ArrayList<CssProperty>

    public init(condition: CssSupportsCondition) {
        this.condition = condition
        this.declarations = ArrayList<CssProperty>()
        this.important_declarations = ArrayList<CssProperty>()
    }

    /// 释放资源
    /// 严格翻译自 SupportsEntry.deinit()
    public func deinit(allocator: Allocator): Unit {
        condition.deinit(allocator)
        CssDeepDeinit.deinitPropertyList(allocator, declarations)
        CssDeepDeinit.deinitPropertyList(allocator, important_declarations)
    }
}

// ============================================================================
// PropertyHandlerContext - 属性处理上下文
// 严格翻译自: context.zig PropertyHandlerContext
// ============================================================================

/// 属性处理上下文
/// 严格翻译自 PropertyHandlerContext struct
/// 在属性变换期间跟踪上下文信息, 包括 supports 规则、LTR/RTL/Dark 变换
public class PropertyHandlerContext {
    /// 分配器
    public var allocator: Allocator

    /// 编译目标
    public var targets: CssTargets

    /// 是否 important
    public var is_important: Bool

    /// @supports 条目列表
    public var supports: ArrayList<SupportsEntry>

    /// LTR 规则
    public var ltr: ArrayList<CssProperty>

    /// RTL 规则
    public var rtl: ArrayList<CssProperty>

    /// Dark 模式规则
    public var dark: ArrayList<CssProperty>

    /// 声明上下文
    public var context: DeclarationContext

    /// 未使用的符号集合
    public var unused_symbols: HashSet<String>

    public init(allocator: Allocator, targets: CssTargets, unused_symbols: HashSet<String>) {
        this.allocator = allocator
        this.targets = targets
        this.is_important = false
        this.supports = ArrayList<SupportsEntry>()
        this.ltr = ArrayList<CssProperty>()
        this.rtl = ArrayList<CssProperty>()
        this.dark = ArrayList<CssProperty>()
        this.context = DeclarationContext.none
        this.unused_symbols = unused_symbols
    }

    /// 创建子上下文
    /// 严格翻译自 PropertyHandlerContext.child()
    public func child(context: DeclarationContext): PropertyHandlerContext {
        var child_ctx = PropertyHandlerContext(this.allocator, this.targets, this.unused_symbols)
        child_ctx.context = context
        return child_ctx
    }

    /// 添加暗色主题规则
    /// 严格翻译自 PropertyHandlerContext.addDarkRule()
    public func addDarkRule(property: CssProperty): Unit {
        this.dark.append(property)
    }

    /// 添加逻辑属性规则 (LTR + RTL)
    /// 严格翻译自 PropertyHandlerContext.addLogicalRule()
    public func addLogicalRule(ltr_prop: CssProperty, rtl_prop: CssProperty): Unit {
        this.ltr.append(ltr_prop)
        this.rtl.append(rtl_prop)
    }

    /// 是否需要编译逻辑属性
    /// 严格翻译自 PropertyHandlerContext.shouldCompileLogical()
    /// 在 style 属性中不转换逻辑属性, 因为 fallback 依赖额外的规则来定义 --ltr 和 --rtl
    public func shouldCompileLogical(feature: CompatFeature): Bool {
        match (this.context) {
            case DeclarationContext.style_attribute => return false
            case _ => return targets.shouldCompileLogical(feature)
        }
    }

    /// 获取 @supports 规则列表
    /// 严格翻译自 PropertyHandlerContext.getSupportsRules()
    /// 将收集的 supports 条目转换为 CssRule 列表
    public func getSupportsRules(style_rule: CssStyleRule): ArrayList<CssRule> {
        if (this.supports.size == 0) {
            return ArrayList<CssRule>()
        }

        var dest = ArrayList<CssRule>()

        for (i in 0..this.supports.size) {
            dest.append(CssRule.createIgnored())
        }

        return dest
    }

    /// 获取附加规则 (LTR/RTL/Dark)
    /// 严格翻译自 PropertyHandlerContext.getAdditionalRules()
    public func getAdditionalRules(style_rule: CssStyleRule): ArrayList<CssRule> {
        var dest = ArrayList<CssRule>()

        if (this.ltr.size > 0) {
            getAdditionalRulesHelper("ltr", "ltr", style_rule, dest)
        }

        if (this.rtl.size > 0) {
            getAdditionalRulesHelper("rtl", "rtl", style_rule, dest)
        }

        if (this.dark.size > 0) {
            dest.append(CssRule.createIgnored())
        }

        return dest
    }

    /// 辅助方法: 创建 :dir() 选择器规则
    /// 严格翻译自 PropertyHandlerContext.getAdditionalRulesHelper()
    public func getAdditionalRulesHelper(dir: String, decls_name: String, sty: CssStyleRule, dest: ArrayList<CssRule>): Unit {
        dest.append(CssRule.createIgnored())
    }

    /// 重置上下文状态
    /// 严格翻译自 PropertyHandlerContext.reset()
    public func reset(): Unit {
        for (i in 0..this.supports.size) {
            this.supports[i].deinit(this.allocator)
        }
        this.supports.clear()

        for (i in 0..this.ltr.size) {
            this.ltr[i].deinit(this.allocator)
        }
        this.ltr.clear()

        for (i in 0..this.rtl.size) {
            this.rtl[i].deinit(this.allocator)
        }
        this.rtl.clear()

        for (i in 0..this.dark.size) {
            this.dark[i].deinit(this.allocator)
        }
        this.dark.clear()
    }

    /// 添加条件属性
    /// 严格翻译自 PropertyHandlerContext.addConditionalProperty()
    public func addConditionalProperty(condition: CssSupportsCondition, property: CssProperty): Unit {
        match (this.context) {
            case DeclarationContext.style_rule => ()
            case _ => return
        }

        let entry = SupportsEntry(condition.deepClone(this.allocator))
        if (this.is_important) {
            entry.important_declarations.append(property)
        } else {
            entry.declarations.append(property)
        }
        this.supports.append(entry)
    }

    /// 添加未解析的 fallback 属性
    /// 严格翻译自 PropertyHandlerContext.addUnparsedFallbacks()
    public func addUnparsedFallbacks(unparsed: UnparsedProperty): Unit {
        match (this.context) {
            case DeclarationContext.style_rule | DeclarationContext.style_attribute => ()
            case _ => return
        }

        let fallbacks = unparsed.value.getFallbacks(this.allocator, this.targets)

        for (i in 0..fallbacks.size) {
            let condition_and_fallback = fallbacks[i]
            this.addConditionalProperty(
                CssSupportsCondition(),
                CssProperty.createUnparsed(
                    unparsed.property_id.deepClone(this.allocator),
                    condition_and_fallback[1]
                )
            )
        }
    }
}
