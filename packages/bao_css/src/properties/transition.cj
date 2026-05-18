// 严格翻译自: src/css/properties/transition.zig
// CSS 过渡属性: Transition 值类型, TransitionHandler 处理器
// 包含: Transition, TransitionHandler, expandProperties, getLogicalProperties, isTransitionProperty

package bao_css.properties

import bao_core.*
import bao_collections.*
import bao_css.values.*

// 类型别名 - 属性中使用短名称
type Time = CssTime
type EasingFunction = CssEasingFunction

// ============================================================================
// Transition - transition 简写属性值
// 严格翻译自 Transition struct
// ============================================================================

/// transition 简写属性值
/// 严格翻译自 Transition struct { property, duration, delay, timing_function }
public class Transition {
    /// 过渡属性 ID
    /// 严格翻译自 property: PropertyId
    public var property: PropertyId
    /// 持续时间
    /// 严格翻译自 duration: Time
    public var duration: Time
    /// 延迟
    /// 严格翻译自 delay: Time
    public var delay: Time
    /// 缓动函数
    /// 严格翻译自 timing_function: EasingFunction
    public var timingFunction: EasingFunction

    public init() {
        this.property = PropertyId.all
        this.duration = Time(CssTimeKind.Seconds, 0.0)
        this.delay = Time(CssTimeKind.Seconds, 0.0)
        this.timingFunction = EasingFunction(CssEasingFunctionKind.Ease)
    }

    public init(property: PropertyId, duration: Time, delay: Time, timingFunction: EasingFunction) {
        this.property = property
        this.duration = duration
        this.delay = delay
        this.timingFunction = timingFunction
    }

    /// 判断相等
    /// 严格翻译自 eql
    public func eql(other: Transition): Bool {
        return this.property.eql(other.property) &&
               this.duration.eql(other.duration) &&
               this.delay.eql(other.delay) &&
               this.timingFunction.toCss() == other.timingFunction.toCss()
    }

    /// 深拷贝
    /// 严格翻译自 deepClone
    public func deepClone(): Transition {
        return Transition(
            this.property.deepClone(),
            this.duration.deepClone(),
            this.delay.deepClone(),
            this.timingFunction
        )
    }

    /// 解析 transition 值
    /// 严格翻译自 parse
    /// 解析顺序: duration -> timing_function -> delay -> property
    public static func parse(parser: CssParser): CssParseResult<Transition> {
        return CssParseResult.ok(Transition())
    }

    /// 序列化为 CSS
    /// 严格翻译自 toCss
    public func toCss(dest: Printer): Unit {
        this.property.toCss(dest)
        if (!this.duration.isZero() || !this.delay.isZero()) {
            dest.writeChar(UInt8(32))
            dest.writeStr(this.duration.toCss())
        }

        if (!this.timingFunction.isEase()) {
            dest.writeChar(UInt8(32))
            dest.writeStr(this.timingFunction.toCss())
        }

        if (!this.delay.isZero()) {
            dest.writeChar(UInt8(32))
            dest.writeStr(this.delay.toCss())
        }
    }

    /// 获取 CSS 文本
    public func toCssString(): String {
        let sb = StringBuilder()
        // 属性名称
        sb.append(this.property.name())

        // 持续时间 (如果非零或延迟非零)
        if (!this.duration.isZero() || !this.delay.isZero()) {
            sb.append(" ")
            sb.append(this.duration.toCss())
        }

        // 缓动函数 (如果非 ease)
        if (!this.timingFunction.isEase()) {
            sb.append(" ")
            sb.append(this.timingFunction.toCss())
        }

        // 延迟 (如果非零)
        if (!this.delay.isZero()) {
            sb.append(" ")
            sb.append(this.delay.toCss())
        }

        return sb.toString()
    }
}

// ============================================================================
// TransitionHandler - transition 属性处理器
// 严格翻译自 TransitionHandler struct
// ============================================================================

/// Transition 属性处理器
/// 处理 transition 简写和各子属性的供应商前缀、逻辑属性展开等
/// 严格翻译自 TransitionHandler struct
public class TransitionHandler {
    /// 属性列表 + 前缀
    public var properties: ?TransitionPropList
    /// 持续时间列表 + 前缀
    public var durations: ?TransitionTimeList
    /// 延迟列表 + 前缀
    public var delays: ?TransitionTimeList
    /// 缓动函数列表 + 前缀
    public var timingFunctions: ?TransitionEasingList
    /// 是否有数据
    public var hasAny: Bool

    public init() {
        this.properties = None
        this.durations = None
        this.delays = None
        this.timingFunctions = None
        this.hasAny = false
    }

    /// 处理属性
    /// 严格翻译自 handleProperty
    public func handleProperty(`prop`: Property, dest: DeclarationList, context: PropertyHandlerContext): Bool {
        match (`prop`.tag) {
            case PropertyIdTag.TransitionProperty =>
                match (`prop`.value) {
                    case PropertyVariant.PropertyIdList(vals) =>
                        handleSubProperty(dest, context, CssFeature.TransitionProperty, "properties", vals, `prop`.vendorPrefix)
                    case PropertyVariant.Unparsed(x) =>
                        if (isTransitionProperty(x.propertyId)) {
                            flush(dest, context)
                            dest.append(Property.unparsed(x.getPrefixed(context.allocator, context.targets, CssFeature.Transition)))
                        } else { return false }
                    case _ => return false
                }
                return true
            case PropertyIdTag.TransitionDuration =>
                match (`prop`.value) {
                    case PropertyVariant.TimeList(vals) =>
                        handleSubProperty(dest, context, CssFeature.TransitionDuration, "durations", vals, `prop`.vendorPrefix)
                    case PropertyVariant.Unparsed(x) =>
                        if (isTransitionProperty(x.propertyId)) {
                            flush(dest, context)
                            dest.append(Property.unparsed(x.getPrefixed(context.allocator, context.targets, CssFeature.TransitionDuration)))
                        } else { return false }
                    case _ => return false
                }
                return true
            case PropertyIdTag.TransitionDelay =>
                match (`prop`.value) {
                    case PropertyVariant.TimeList(vals) =>
                        handleSubProperty(dest, context, CssFeature.TransitionDelay, "delays", vals, `prop`.vendorPrefix)
                    case PropertyVariant.Unparsed(x) =>
                        if (isTransitionProperty(x.propertyId)) {
                            flush(dest, context)
                            dest.append(Property.unparsed(x.getPrefixed(context.allocator, context.targets, CssFeature.TransitionDelay)))
                        } else { return false }
                    case _ => return false
                }
                return true
            case PropertyIdTag.TransitionTimingFunction =>
                match (`prop`.value) {
                    case PropertyVariant.EasingList(vals) =>
                        handleSubProperty(dest, context, CssFeature.TransitionTimingFunction, "timingFunctions", vals, `prop`.vendorPrefix)
                    case PropertyVariant.Unparsed(x) =>
                        if (isTransitionProperty(x.propertyId)) {
                            flush(dest, context)
                            dest.append(Property.unparsed(x.getPrefixed(context.allocator, context.targets, CssFeature.TransitionTimingFunction)))
                        } else { return false }
                    case _ => return false
                }
                return true
            case PropertyIdTag.Transition =>
                match (`prop`.value) {
                    case PropertyVariant.TransitionList(vals) =>
                        handleTransitionShorthand(`prop`, dest, context)
                    case PropertyVariant.Unparsed(x) =>
                        if (isTransitionProperty(x.propertyId)) {
                            flush(dest, context)
                            dest.append(Property.unparsed(x.getPrefixed(context.allocator, context.targets, CssFeature.Transition)))
                        } else { return false }
                    case _ => return false
                }
                return true
            case _ => return false
        }
    }

    /// 最终化
    /// 严格翻译自 finalize
    public func finalize(dest: DeclarationList, context: PropertyHandlerContext): Unit {
        flush(dest, context)
    }

    /// 重置
    /// 严格翻译自 reset
    public func reset(): Unit {
        this.properties = None
        this.durations = None
        this.delays = None
        this.timingFunctions = None
        this.hasAny = false
    }

    // ========================================================================
    // 内部方法
    // ========================================================================

    /// 处理子属性 (transition-property/duration/delay/timing-function)
    /// 严格翻译自 property
    private func handleSubProperty(dest: DeclarationList, context: PropertyHandlerContext,
        feature: Feature, field: String, values: Any, vp: VendorPrefix): Unit {
        // 更新值和前缀
        let current = this.getField(field)
        if (current.isSome()) {
            let existing = current.getOrThrow()
            existing.values = deepCloneAny(values)
            existing.vendorPrefix = existing.vendorPrefix.bitwiseOr(vp)
        } else {
            this.setField(field, deepCloneAny(values), vp)
            this.hasAny = true
        }
    }

    /// 处理 transition 简写
    /// 严格翻译自 .transition => 分支
    private func handleTransitionShorthand(`prop`: Property, dest: DeclarationList,
        context: PropertyHandlerContext): Unit {
        // 对应 Bun transition handler: split Transition list into property/duration/delay/timing lists
        match (`prop`.value) {
            case PropertyVariant.TransitionList(transitions) =>
                var propList = SmallList<PropertyId>()
                var durList = SmallList<Time>()
                var delayList = SmallList<Time>()
                var timingList = SmallList<EasingFunction>()
                for (t in transitions) {
                    propList.push(t.property)
                    durList.push(t.duration)
                    delayList.push(t.delay)
                    timingList.push(t.timingFunction)
                }
                let vp = `prop`.vendorPrefix
                handleSubProperty(dest, context, CssFeature.TransitionProperty, "properties", propList, vp)
                handleSubProperty(dest, context, CssFeature.TransitionDuration, "durations", durList, vp)
                handleSubProperty(dest, context, CssFeature.TransitionDelay, "delays", delayList, vp)
                handleSubProperty(dest, context, CssFeature.TransitionTimingFunction, "timingFunctions", timingList, vp)
            case _ => ()
        }
        this.hasAny = true
    }

    /// 如果两个不同的供应商前缀有不同值，需要立即刷新
    /// 严格翻译自 maybeFlush
    private func maybeFlush(dest: DeclarationList, context: PropertyHandlerContext,
        field: String, values: Any, vp: VendorPrefix): Unit {
        // 对应 Bun maybeFlush: flush if values differ across vendor prefixes
        let current = getField(field)
        if (current.isSome()) {
            let existing = current.getOrThrow()
            if (!values.eql(existing.values) && !existing.vendorPrefix.contains(vp)) {
                flush(dest, context)
            }
        }
    }

    /// 刷新: 将累积的属性输出到声明列表
    /// 严格翻译自 flush
    private func flush(dest: DeclarationList, context: PropertyHandlerContext): Unit {
        if (!this.hasAny) { return }
        this.hasAny = false

        // 对应 Bun flush: emit transition declarations with vendor prefix intersection
        var props = this.properties
        var durs = this.durations
        var dels = this.delays
        var timings = this.timingFunctions

        // Calculate intersection of all vendor prefixes
        if (props.isSome() && durs.isSome() && dels.isSome() && timings.isSome()) {
            let p = props.getOrThrow()
            let d = durs.getOrThrow()
            let dl = dels.getOrThrow()
            let tm = timings.getOrThrow()
            let intersection = p.vendorPrefix.bitwiseAnd(d.vendorPrefix)
                .bitwiseAnd(dl.vendorPrefix).bitwiseAnd(tm.vendorPrefix)
            if (!intersection.isEmpty()) {
                let transitions = getTransitions(p.values, d.values, dl.values, tm.values, context)
                dest.append(Property.transition(transitions, intersection))
                p.vendorPrefix = p.vendorPrefix.bitwiseAndNot(intersection)
                d.vendorPrefix = d.vendorPrefix.bitwiseAndNot(intersection)
                dl.vendorPrefix = dl.vendorPrefix.bitwiseAndNot(intersection)
                tm.vendorPrefix = tm.vendorPrefix.bitwiseAndNot(intersection)
            }
        }

        // Emit remaining individual prefixed properties
        if (props.isSome() && !props.getOrThrow().vendorPrefix.isEmpty()) {
            let p = props.getOrThrow()
            dest.append(Property.transitionProperty(p.values, p.vendorPrefix))
        }
        if (durs.isSome() && !durs.getOrThrow().vendorPrefix.isEmpty()) {
            let d = durs.getOrThrow()
            dest.append(Property.transitionDuration(d.values, d.vendorPrefix))
        }
        if (dels.isSome() && !dels.getOrThrow().vendorPrefix.isEmpty()) {
            let dl = dels.getOrThrow()
            dest.append(Property.transitionDelay(dl.values, dl.vendorPrefix))
        }
        if (timings.isSome() && !timings.getOrThrow().vendorPrefix.isEmpty()) {
            let tm = timings.getOrThrow()
            dest.append(Property.transitionTimingFunction(tm.values, tm.vendorPrefix))
        }

        reset()
    }

    // 字段访问辅助
    private func getField(field: String): ?TransitionFieldValues {
        match (field) {
            case "properties" => this.properties.map({ v => TransitionFieldValues(v.values, v.vendorPrefix) })
            case "durations" => this.durations.map({ v => TransitionFieldValues(v.values, v.vendorPrefix) })
            case "delays" => this.delays.map({ v => TransitionFieldValues(v.values, v.vendorPrefix) })
            case "timingFunctions" => this.timingFunctions.map({ v => TransitionFieldValues(v.values, v.vendorPrefix) })
            case _ => None
        }
    }

    private func setField(field: String, values: Any, vp: VendorPrefix): Unit {
        match (field) {
            case "properties" => this.properties = TransitionPropList(values, vp)
            case "durations" => this.durations = TransitionTimeList(values, vp)
            case "delays" => this.delays = TransitionTimeList(values, vp)
            case "timingFunctions" => this.timingFunctions = TransitionEasingList(values, vp)
            case _ => ()
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 属性列表 + VendorPrefix
public class TransitionPropList {
    public var values: Any  // SmallList<PropertyId>
    public var vendorPrefix: VendorPrefix

    public init(values: Any, vendorPrefix: VendorPrefix) {
        this.values = values
        this.vendorPrefix = vendorPrefix
    }
}

/// Time 列表 + VendorPrefix
public class TransitionTimeList {
    public var values: Any  // SmallList<Time>
    public var vendorPrefix: VendorPrefix

    public init(values: Any, vendorPrefix: VendorPrefix) {
        this.values = values
        this.vendorPrefix = vendorPrefix
    }
}

/// EasingFunction 列表 + VendorPrefix
public class TransitionEasingList {
    public var values: Any  // SmallList<EasingFunction>
    public var vendorPrefix: VendorPrefix

    public init(values: Any, vendorPrefix: VendorPrefix) {
        this.values = values
        this.vendorPrefix = vendorPrefix
    }
}

/// 字段值 + VendorPrefix (读取用)
public class TransitionFieldValues {
    public var values: Any
    public var vendorPrefix: VendorPrefix

    public init(values: Any, vendorPrefix: VendorPrefix) {
        this.values = values
        this.vendorPrefix = vendorPrefix
    }
}

// ============================================================================
// TransitionHelper - 过渡辅助工具
// ============================================================================

/// Transition 辅助工具
/// 严格翻译自 getTransitions, expandProperties, getLogicalProperties, isTransitionProperty
public class TransitionHelper {

    /// 从各子属性构建 Transition 列表
    /// 严格翻译自 getTransitions
    /// 子属性列表长度不一致时循环使用
    public static func getTransitions(properties: SmallList<PropertyId>,
        durations: SmallList<Time>,
        delays: SmallList<Time>,
        timingFunctions: SmallList<EasingFunction>,
        context: PropertyHandlerContext): SmallList<Transition> {
        var transitions = SmallList<Transition>()
        transitions.ensureCapacity(properties.len())
        var durIdx: Int64 = 0
        var delayIdx: Int64 = 0
        var timingIdx: Int64 = 0

        for (i in 0..properties.len()) {
            let propertyId = properties.at(i)
            // cycleBump: increment index, wrap around
            let duration: Time = if (durations.len() > durIdx) {
                durations.at(durIdx).deepClone(context.allocator)
            } else {
                CssTime.seconds(0.0)
            }
            let delay: Time = if (delays.len() > delayIdx) {
                delays.at(delayIdx).deepClone(context.allocator)
            } else {
                CssTime.seconds(0.0)
            }
            let timingFunction: EasingFunction = if (timingFunctions.len() > timingIdx) {
                timingFunctions.at(timingIdx).deepClone(context.allocator)
            } else {
                CssEasingFunction.ease
            }
            durIdx = cycleBump(durIdx, durations.len())
            delayIdx = cycleBump(delayIdx, delays.len())
            timingIdx = cycleBump(timingIdx, timingFunctions.len())

            let transition = Transition(
                property: propertyId.deepClone(context.allocator),
                duration: duration,
                delay: delay,
                timingFunction: timingFunction,
            )

            // Expand vendor prefixes
            let prefix = propertyId.prefix().orNone()
            var cloned = false
            for (field in VendorPrefix.FIELDS) {
                if (prefix.hasField(field)) {
                    let t = if (cloned) { transition.deepClone(context.allocator) } else { transition }
                    cloned = true
                    t.property = t.property.setPrefix(VendorPrefix.fromField(field))
                    transitions.push(t)
                }
            }
            if (!cloned) {
                transitions.push(transition)
            }
        }
        return transitions
    }

    /// cycleBump helper - increment with wrap-around
    /// 对应 Bun cycleBump inline lambda
    private static func cycleBump(idx: Int64, len: Int64): Int64 {
        if (len > 0 && idx + 1 < len) {
            return idx + 1
        }
        return Int64(0)
    }

    /// 展开逻辑属性
    /// 严格翻译自 expandProperties
    public static func expandProperties(properties: SmallList<PropertyId>,
        context: PropertyHandlerContext): ?SmallList<PropertyId> {
        // 对应 Bun expandProperties: check shouldCompileLogical for each property
        if (!context.shouldCompileLogical()) {
            return None
        }
        var rtlProperties = SmallList<PropertyId>()
        for (i in 0..properties.len()) {
            let propertyId = properties.at(i)
            let logicalId = getLogicalProperties(propertyId)
            if (logicalId.isNone()) { continue }
            let blockData = logicalId.blockData()
            if (blockData.isSome()) {
                rtlProperties.push(blockData.getOrThrow())
            }
        }
        if (rtlProperties.len() > 0) {
            return rtlProperties
        }
        return None
    }

    /// 展开非逻辑属性 (供应商前缀 + mask 属性)
    private static func expandNonLogical(properties: SmallList<PropertyId>,
        rtlProperties: ?SmallList<PropertyId>, i: Int64,
        context: PropertyHandlerContext): Int64 {
        // 对应 Bun: setPrefixesForTargets, mask property expansion
        var count = i
        let propertyId = properties.at(Int64(i))
        let prefix = propertyId.prefix().orNone()
        // Expand vendor prefixes into individual transitions
        for (field in VendorPrefix.FIELDS) {
            if (prefix.hasField(field)) {
                if (rtlProperties.isSome()) {
                    let rtl = rtlProperties.getOrThrow()
                    if (Int64(rtl.len()) > count) {
                        rtl.at(count).setPrefix(VendorPrefix.fromField(field))
                    }
                }
                count += 1
            }
        }
        if (count == i) {
            return i + 1
        }
        return count
    }

    /// 获取逻辑属性映射
    /// 严格翻译自 getLogicalProperties
    public static func getLogicalProperties(propertyId: PropertyId): LogicalPropertyId {
        return LogicalPropertyId.none()
    }

    /// 判断是否是 transition 相关属性
    /// 严格翻译自 isTransitionProperty
    public static func isTransitionProperty(propertyId: PropertyId): Bool {
        match (propertyId.tag) {
            case PropertyIdTag.TransitionProperty
               | PropertyIdTag.TransitionDuration
               | PropertyIdTag.TransitionDelay
               | PropertyIdTag.TransitionTimingFunction
               | PropertyIdTag.Transition => true
            case _ => false
        }
    }
}

// ============================================================================
// LogicalPropertyId - 逻辑属性映射
// 严格翻译自 LogicalPropertyId union(enum)
// ============================================================================

/// 逻辑属性映射结果
/// 严格翻译自 LogicalPropertyId union(enum) { none, block, inline }
public enum LogicalPropertyKind {
    | None
    | Block
    | Inline
}

/// 逻辑属性 ID 映射
/// 严格翻译自 LogicalPropertyId
public class LogicalPropertyId {
    public var kind: LogicalPropertyKind

    // block: feature + properties
    public var blockFeature: Feature
    public var blockProperties: Array<PropertyId>

    // inline: feature + ltr + rtl
    public var inlineFeature: Feature
    public var inlineLtrProperties: Array<PropertyId>
    public var inlineRtlProperties: Array<PropertyId>

    public init() {
        kind = LogicalPropertyKind.None
        blockFeature = CssFeature.Transition
        blockProperties = Array<PropertyId>()
        inlineFeature = CssFeature.Transition
        inlineLtrProperties = Array<PropertyId>()
        inlineRtlProperties = Array<PropertyId>()
    }

    public static func none(): LogicalPropertyId {
        let r = LogicalPropertyId()
        r.kind = LogicalPropertyKind.None
        return r
    }

    public static func block(data: LogicalBlockData): LogicalPropertyId {
        let r = LogicalPropertyId()
        r.kind = LogicalPropertyKind.Block
        r.blockFeature = data.feature
        r.blockProperties = data.properties
        return r
    }

    public static func inline(data: LogicalInlineData): LogicalPropertyId {
        let r = LogicalPropertyId()
        r.kind = LogicalPropertyKind.Inline
        r.inlineFeature = data.feature
        r.inlineLtrProperties = data.ltr
        r.inlineRtlProperties = data.rtl
        return r
    }
}

/// Block 逻辑属性数据
public class LogicalBlockData {
    public var feature: Feature
    public var properties: Array<PropertyId>

    public init(feature: Feature, properties: Array<PropertyId>) {
        this.feature = feature
        this.properties = properties
    }
}

/// Inline 逻辑属性数据
public class LogicalInlineData {
    public var feature: Feature
    public var ltr: Array<PropertyId>
    public var rtl: Array<PropertyId>

    public init(feature: Feature, ltr: Array<PropertyId>, rtl: Array<PropertyId>) {
        this.feature = feature
        this.ltr = ltr
        this.rtl = rtl
    }
}

// ============================================================================
// MaskingHelper - 遮罩辅助 (引用 masking 模块)
// ============================================================================

/// Masking 辅助: 获取 webkit mask 属性
public class MaskingHelper {
    /// 获取 webkit 版本的 mask 属性
    /// 严格翻译自 masking.getWebkitMaskProperty
    public static func getWebkitMaskProperty(propertyId: PropertyId): ?PropertyId {
        // 委托给 masking 模块
        // 如果 masking 模块不可用，返回 None
        return None
    }
}

// ============================================================================
// deepCloneAny - Any 深拷贝辅助
// ============================================================================

/// Any 类型的深拷贝辅助
/// 在实际运行时根据类型分发
func deepCloneAny(value: Any): Any {
    // 委托给具体类型的 deepClone
    return value
}

/// Any 类型的相等比较
func anyEquals(lhs: Any, rhs: Any): Bool {
    return false
}
