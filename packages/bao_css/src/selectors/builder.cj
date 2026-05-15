// 严格翻译自: src/css/selectors/builder.zig
// 选择器构建器模块 - 从 servo/lightningcss 移植
// 用于在解析过程中安全高效地构建选择器
package bao_css.selectors

import bao_core.*
import bao_collections.*

// ============================================================================
// SelectorBuilder - 选择器构建器
// 严格翻译自: selectors/builder.zig SelectorBuilder(Impl)
//
// 选择器表示设计优化匹配, 有以下要求:
// - 所有简单选择器和组合符与 Component 实例存储在同一缓冲区中
// - 顶层复合选择器从右到左存储 (匹配顺序)
// - 每个组合符的简单选择器从左到右存储
// ============================================================================

/// 选择器构建器
/// 严格翻译自 SelectorBuilder(Impl) struct
/// 在解析过程中从左到右收集选择器数据, 然后 build() 生成最终的 Selector
public class SelectorBuilder {
    /// 简单选择器序列 (从左到右, 不含组合符)
    /// 严格翻译自 simple_selectors: SmallList(GenericComponent, 32)
    public var simple_selectors: ArrayList<SelectorComponent>

    /// 组合符及其左侧复合选择器的长度
    /// 严格翻译自 combinators: SmallList(struct { Combinator, usize }, 32)
    public var combinators: ArrayList<SelectorCombinatorEntry>

    /// 当前复合选择器的长度
    /// 严格翻译自 current_len: usize
    public var current_len: Int64

    public init() {
        this.simple_selectors = ArrayList<SelectorComponent>()
        this.combinators = ArrayList<SelectorCombinatorEntry>()
        this.current_len = 0
    }

    /// 是否有组合符
    /// 严格翻译自 SelectorBuilder.hasCombinators()
    public func hasCombinators(): Bool {
        return combinators.size > 0
    }

    /// 完成当前复合选择器并开始新的, 以给定组合符分隔
    /// 严格翻译自 SelectorBuilder.pushCombinator()
    public func pushCombinator(combinator: SelectorCombinator): Unit {
        combinators.append(SelectorCombinatorEntry(combinator, current_len))
        current_len = 0
    }

    /// 将简单选择器推入当前复合选择器
    /// 严格翻译自 SelectorBuilder.pushSimpleSelector()
    public func pushSimpleSelector(ss: SelectorComponent): Unit {
        simple_selectors.append(ss)
        current_len += 1
    }

    /// 添加嵌套前缀 (& 后代组合符)
    /// 严格翻译自 SelectorBuilder.addNestingPrefix()
    public func addNestingPrefix(): Unit {
        combinators.insert(0, SelectorCombinatorEntry(SelectorCombinator.descendant, 1))
        simple_selectors.insert(0, SelectorComponent.nesting)
    }

    /// 构建选择器
    /// 严格翻译自 SelectorBuilder.build()
    /// 消费构建器内容, 生成最终的选择器组件列表
    public func build(parsed_pseudo: Bool, parsed_slotted: Bool, parsed_part: Bool): SelectorBuildResult {
        let specificity = computeSpecificity(simple_selectors)
        let flags = SelectorFlags(
            has_pseudo: parsed_pseudo,
            has_slotted: parsed_slotted,
            has_part: parsed_part
        )
        return buildWithSpecificityAndFlags(
            SpecificityAndFlags(specificity: specificity, flags: flags)
        )
    }

    /// 使用给定的特异性和标志构建选择器
    /// 严格翻译自 SelectorBuilder.buildWithSpecificityAndFlags()
    ///
    /// 注意: 原始 servo 代码将组件以反向顺序存储以优化匹配
    /// 但我们不需要匹配选择器, 所以按原始顺序存储
    public func buildWithSpecificityAndFlags(spec: SpecificityAndFlags): SelectorBuildResult {
        let rest_and_current = splitFromEnd(simple_selectors, current_len)
        var rest_of_simple_selectors = rest_and_current[0]
        var current_simple_selectors = rest_and_current[1]

        var components = ArrayList<SelectorComponent>()

        var current_simple_selectors_i: Int64 = 0
        var combinator_i: Int64 = combinators.size - 1

        while (true) {
            if (current_simple_selectors_i < current_simple_selectors.size) {
                components.append(current_simple_selectors[current_simple_selectors_i])
                current_simple_selectors_i += 1
            } else {
                if (combinator_i >= 0) {
                    let entry = combinators[combinator_i]
                    let split = splitFromEnd(rest_of_simple_selectors, entry.len)
                    rest_of_simple_selectors = split[0]
                    current_simple_selectors_i = 0
                    current_simple_selectors = split[1]
                    combinator_i -= 1
                    components.append(SelectorComponent.combinator(entry.combinator))
                } else {
                    break
                }
            }
        }

        return SelectorBuildResult(
            specificity_and_flags: spec,
            components: components
        )
    }

    /// 从末尾分割数组
    /// 严格翻译自 SelectorBuilder.splitFromEnd()
    public static func splitFromEnd(s: ArrayList<SelectorComponent>, at: Int64): ArrayList<SelectorComponent>[] {
        let midpoint = s.size - at
        var left = ArrayList<SelectorComponent>()
        var right = ArrayList<SelectorComponent>()
        for (i in 0..s.size) {
            if (i < midpoint) {
                left.append(s[i])
            } else {
                right.append(s[i])
            }
        }
        return [left, right]
    }
}

/// 选择器组合符条目 (组合符 + 左侧复合选择器长度)
/// 严格翻译自 struct { Combinator, usize }
public class SelectorCombinatorEntry {
    public var combinator: SelectorCombinator
    public var len: Int64

    public init(combinator: SelectorCombinator, len: Int64) {
        this.combinator = combinator
        this.len = len
    }
}

/// 构建结果
/// 严格翻译自 BuildResult struct
public class SelectorBuildResult {
    public var specificity_and_flags: SpecificityAndFlags
    public var components: ArrayList<SelectorComponent>

    public init(specificity_and_flags: SpecificityAndFlags, components: ArrayList<SelectorComponent>) {
        this.specificity_and_flags = specificity_and_flags
        this.components = components
    }
}

/// 特异性和标志
/// 严格翻译自 SpecificityAndFlags struct
public class SpecificityAndFlags {
    public var specificity: UInt32
    public var flags: SelectorFlags

    public init(specificity: UInt32, flags: SelectorFlags) {
        this.specificity = specificity
        this.flags = flags
    }
}

/// 选择器标志
/// 严格翻译自 SelectorFlags
public class SelectorFlags {
    public var has_pseudo: Bool
    public var has_slotted: Bool
    public var has_part: Bool

    public init(has_pseudo: Bool, has_slotted: Bool, has_part: Bool) {
        this.has_pseudo = has_pseudo
        this.has_slotted = has_slotted
        this.has_part = has_part
    }
}

/// 计算特异性
/// 严格翻译自 compute_specificity()
public func computeSpecificity(components: ArrayList<SelectorComponent>): UInt32 {
    var a: UInt32 = 0  // ID 选择器
    var b: UInt32 = 0  // 类、属性、伪类选择器
    var c: UInt32 = 0  // 类型、伪元素选择器

    for (i in 0..components.size) {
        let comp = components[i]
        match (comp) {
            case SelectorComponent.id_selector(_) => a += 1
            case SelectorComponent.class_selector(_) => b += 1
            case SelectorComponent.attribute_selector(_) => b += 1
            case SelectorComponent.pseudo_class(_) => b += 1
            case SelectorComponent.type_selector(_) => c += 1
            case SelectorComponent.pseudo_element(_) => c += 1
            case SelectorComponent.nesting => b += 1
            case SelectorComponent.combinator(_) => ()  // 组合符不影响特异性
            case _ => ()
        }
    }

    return (a << 20) | (b << 10) | c
}
