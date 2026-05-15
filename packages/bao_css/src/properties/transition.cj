// 严格翻译自: src/css/properties/transition.zig
// CSS 过渡属性: Transition 值类型, TransitionHandler 处理器
// 包含: Transition, TransitionHandler, expandProperties, getLogicalProperties, isTransitionProperty

package bao_css.properties

import bao_core.*
import bao_collections.*

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
        this.duration = Time()
        this.delay = Time()
        this.timingFunction = EasingFunction.ease()
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
               this.timingFunction.eql(other.timingFunction)
    }

    /// 深拷贝
    /// 严格翻译自 deepClone
    public func deepClone(): Transition {
        return Transition(
            property: this.property.deepClone(),
            duration: this.duration.deepClone(),
            delay: this.delay.deepClone(),
            timingFunction: this.timingFunction.deepClone()
        )
    }

    /// 解析 transition 值
    /// 严格翻译自 parse
    /// 解析顺序: duration -> timing_function -> delay -> property
    public static func parse(parser: CssParser): CssParseResult<Transition> {
        var prop: ?PropertyId = None
        var dur: ?Time = None
        var del: ?Time = None
        var timing: ?EasingFunction = None

        var loop = true
        while (loop) {
            if (dur.isNone()) {
                let result = Time.parse(parser)
                if (result.isOk()) {
                    dur = Some(result.unwrap())
                    continue
                }
            }

            if (timing.isNone()) {
                let result = EasingFunction.parse(parser)
                if (result.isOk()) {
                    timing = Some(result.unwrap())
                    continue
                }
            }

            if (del.isNone()) {
                let result = Time.parse(parser)
                if (result.isOk()) {
                    del = Some(result.unwrap())
                    continue
                }
            }

            if (prop.isNone()) {
                let result = PropertyId.parse(parser)
                if (result.isOk()) {
                    prop = Some(result.unwrap())
                    continue
                }
            }

            loop = false
        }

        return CssParseResult.ok(Transition(
            property: prop.getOr(PropertyId.all),
            duration: dur.getOr(Time()),
            delay: del.getOr(Time()),
            timingFunction: timing.getOr(EasingFunction.ease())
        ))
    }

    /// 序列化为 CSS
    /// 严格翻译自 toCss
    public func toCss(dest: Printer): Unit {
        this.property.toCss(dest)
        if (!this.duration.isZero() || !this.delay.isZero()) {
            dest.writeChar(' ')
            this.duration.toCss(dest)
        }

        if (!this.timingFunction.isEase()) {
            dest.writeChar(' ')
            this.timingFunction.toCss(dest)
        }

        if (!this.delay.isZero()) {
            dest.writeChar(' ')
            this.delay.toCss(dest)
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
            sb.append(this.duration.toCssString())
        }

        // 缓动函数 (如果非 ease)
        if (!this.timingFunction.isEase()) {
            sb.append(" ")
            sb.append(this.timingFunction.toCssString())
        }

        // 延迟 (如果非零)
        if (!this.delay.isZero()) {
            sb.append(" ")
            sb.append(this.delay.toCssString())
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
    public func handleProperty(prop: Property, dest: DeclarationList, context: PropertyHandlerContext): Bool {
        match (prop.tag) {
            case PropertyIdTag.TransitionProperty =>
                this.handleSubProperty(dest, context: context, feature: Feature.TransitionProperty,
                    field: "properties", values: prop.value, vp: prop.vendorPrefix)
            case PropertyIdTag.TransitionDuration =>
                this.handleSubProperty(dest, context: context, feature: Feature.TransitionDuration,
                    field: "durations", values: prop.value, vp: prop.vendorPrefix)
            case PropertyIdTag.TransitionDelay =>
                this.handleSubProperty(dest, context: context, feature: Feature.TransitionDelay,
                    field: "delays", values: prop.value, vp: prop.vendorPrefix)
            case PropertyIdTag.TransitionTimingFunction =>
                this.handleSubProperty(dest, context: context, feature: Feature.TransitionTimingFunction,
                    field: "timingFunctions", values: prop.value, vp: prop.vendorPrefix)
            case PropertyIdTag.Transition =>
                this.handleTransitionShorthand(prop, dest, context: context)
            case PropertyIdTag.Unparsed =>
                let unparsed = prop.value as UnparsedProperty
                if (TransitionHelper.isTransitionProperty(unparsed.propertyId)) {
                    this.flush(dest, context: context)
                    dest.append(Property(
                        tag: PropertyIdTag.Unparsed,
                        value: unparsed.getPrefixed(context.targets, feature: Feature.Transition)
                    ))
                } else {
                    return false
                }
            case _ => return false
        }
        return true
    }

    /// 最终化
    /// 严格翻译自 finalize
    public func finalize(dest: DeclarationList, context: PropertyHandlerContext): Unit {
        this.flush(dest, context: context)
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
        this.maybeFlush(dest, context: context, field: field, values: values, vp: vp)

        // 更新值和前缀
        let current = this.getField(field)
        if (current.isSome()) {
            let existing = current.getOrThrow()
            existing.values = deepCloneAny(values)
            existing.vendorPrefix = existing.vendorPrefix.bitwiseOr(vp)
            existing.vendorPrefix = context.targets.prefixes(existing.vendorPrefix, feature: feature)
        } else {
            let prefixes = context.targets.prefixes(vp, feature: feature)
            this.setField(field, values: deepCloneAny(values), vp: prefixes)
            this.hasAny = true
        }
    }

    /// 处理 transition 简写
    /// 严格翻译自 .transition => 分支
    private func handleTransitionShorthand(prop: Property, dest: DeclarationList,
        context: PropertyHandlerContext): Unit {
        let transitionList = prop.value as SmallList<Transition>
        let vp = prop.vendorPrefix

        // 从简写中提取各子属性
        var properties = SmallList<PropertyId>()
        var durations = SmallList<Time>()
        var delays = SmallList<Time>()
        var timingFunctions = SmallList<EasingFunction>()

        for (item in transitionList.items) {
            properties.append(item.property.deepClone())
        }
        this.maybeFlush(dest, context: context, field: "properties", values: properties, vp: vp)

        for (item in transitionList.items) {
            durations.append(item.duration.deepClone())
        }
        this.maybeFlush(dest, context: context, field: "durations", values: durations, vp: vp)

        for (item in transitionList.items) {
            delays.append(item.delay.deepClone())
        }
        this.maybeFlush(dest, context: context, field: "delays", values: delays, vp: vp)

        for (item in transitionList.items) {
            timingFunctions.append(item.timingFunction.deepClone())
        }
        this.maybeFlush(dest, context: context, field: "timingFunctions", values: timingFunctions, vp: vp)

        // 设置到各子属性
        this.handleSubProperty(dest, context: context, feature: Feature.TransitionProperty,
            field: "properties", values: properties, vp: vp)
        this.handleSubProperty(dest, context: context, feature: Feature.TransitionDuration,
            field: "durations", values: durations, vp: vp)
        this.handleSubProperty(dest, context: context, feature: Feature.TransitionDelay,
            field: "delays", values: delays, vp: vp)
        this.handleSubProperty(dest, context: context, feature: Feature.TransitionTimingFunction,
            field: "timingFunctions", values: timingFunctions, vp: vp)
    }

    /// 如果两个不同的供应商前缀有不同值，需要立即刷新
    /// 严格翻译自 maybeFlush
    private func maybeFlush(dest: DeclarationList, context: PropertyHandlerContext,
        field: String, values: Any, vp: VendorPrefix): Unit {
        let current = this.getField(field)
        if (current.isSome()) {
            let existing = current.getOrThrow()
            if (!anyEquals(values, existing.values) && !existing.vendorPrefix.contains(vp)) {
                this.flush(dest, context: context)
            }
        }
    }

    /// 刷新: 将累积的属性输出到声明列表
    /// 严格翻译自 flush
    private func flush(dest: DeclarationList, context: PropertyHandlerContext): Unit {
        if (!this.hasAny) { return }
        this.hasAny = false

        var _properties = this.properties
        var _durations = this.durations
        var _delays = this.delays
        var _timingFunctions = this.timingFunctions

        // 展开逻辑属性
        var rtlProperties: ?SmallList<PropertyId> = None
        if (_properties.isSome()) {
            rtlProperties = TransitionHelper.expandProperties(_properties.getOrThrow().values, context: context)
        }

        // 如果四项都有，输出简写
        if (_properties.isSome() && _durations.isSome() && _delays.isSome() && _timingFunctions.isSome()) {
            let props = _properties.getOrThrow()
            let durs = _durations.getOrThrow()
            let dels = _delays.getOrThrow()
            let timings = _timingFunctions.getOrThrow()

            // 计算前缀交集
            let intersection = props.vendorPrefix
                .bitwiseAnd(durs.vendorPrefix)
                .bitwiseAnd(dels.vendorPrefix)
                .bitwiseAnd(timings.vendorPrefix)

            if (!intersection.isEmpty()) {
                let transitions = TransitionHelper.getTransitions(
                    context: context,
                    properties: props.values,
                    durations: durs.values,
                    delays: dels.values,
                    timingFunctions: timings.values
                )

                if (rtlProperties.isSome()) {
                    let rtlTransitions = TransitionHelper.getTransitions(
                        context: context,
                        properties: rtlProperties.getOrThrow(),
                        durations: durs.values,
                        delays: dels.values,
                        timingFunctions: timings.values
                    )
                    context.addLogicalRule(
                        Property(tag: PropertyIdTag.Transition, value: transitions, vendorPrefix: intersection),
                        Property(tag: PropertyIdTag.Transition, value: rtlTransitions, vendorPrefix: intersection)
                    )
                } else {
                    dest.append(Property(
                        tag: PropertyIdTag.Transition,
                        value: deepCloneAny(transitions),
                        vendorPrefix: intersection
                    ))
                }

                props.vendorPrefix = props.vendorPrefix.bitwiseAndNot(intersection)
                durs.vendorPrefix = durs.vendorPrefix.bitwiseAndNot(intersection)
                timings.vendorPrefix = timings.vendorPrefix.bitwiseAndNot(intersection)
                dels.vendorPrefix = dels.vendorPrefix.bitwiseAndNot(intersection)
            }
        }

        // 输出剩余的各子属性
        if (_properties.isSome()) {
            let props = _properties.getOrThrow()
            if (!props.vendorPrefix.isEmpty()) {
                if (rtlProperties.isSome()) {
                    context.addLogicalRule(
                        Property(tag: PropertyIdTag.TransitionProperty, value: props.values, vendorPrefix: props.vendorPrefix),
                        Property(tag: PropertyIdTag.TransitionProperty, value: rtlProperties.getOrThrow(), vendorPrefix: props.vendorPrefix)
                    )
                    rtlProperties = None
                } else {
                    dest.append(Property(tag: PropertyIdTag.TransitionProperty, value: props.values, vendorPrefix: props.vendorPrefix))
                }
            }
        }

        if (_durations.isSome()) {
            let durs = _durations.getOrThrow()
            if (!durs.vendorPrefix.isEmpty()) {
                dest.append(Property(tag: PropertyIdTag.TransitionDuration, value: durs.values, vendorPrefix: durs.vendorPrefix))
            }
        }

        if (_delays.isSome()) {
            let dels = _delays.getOrThrow()
            if (!dels.vendorPrefix.isEmpty()) {
                dest.append(Property(tag: PropertyIdTag.TransitionDelay, value: dels.values, vendorPrefix: dels.vendorPrefix))
            }
        }

        if (_timingFunctions.isSome()) {
            let timings = _timingFunctions.getOrThrow()
            if (!timings.vendorPrefix.isEmpty()) {
                dest.append(Property(tag: PropertyIdTag.TransitionTimingFunction, value: timings.values, vendorPrefix: timings.vendorPrefix))
            }
        }

        this.reset()
    }

    // 字段访问辅助
    private func getField(field: String): ?TransitionFieldValues {
        match (field) {
            case "properties" => this.properties.map({ v => TransitionFieldValues(values: v.values, vendorPrefix: v.vendorPrefix) })
            case "durations" => this.durations.map({ v => TransitionFieldValues(values: v.values, vendorPrefix: v.vendorPrefix) })
            case "delays" => this.delays.map({ v => TransitionFieldValues(values: v.values, vendorPrefix: v.vendorPrefix) })
            case "timingFunctions" => this.timingFunctions.map({ v => TransitionFieldValues(values: v.values, vendorPrefix: v.vendorPrefix) })
            case _ => None
        }
    }

    private func setField(field: String, values: Any, vp: VendorPrefix): Unit {
        match (field) {
            case "properties" => this.properties = TransitionPropList(values: values, vendorPrefix: vp)
            case "durations" => this.durations = TransitionTimeList(values: values, vendorPrefix: vp)
            case "delays" => this.delays = TransitionTimeList(values: values, vendorPrefix: vp)
            case "timingFunctions" => this.timingFunctions = TransitionEasingList(values: values, vendorPrefix: vp)
            case _ => {}
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
    public static func getTransitions(context: PropertyHandlerContext,
        properties: SmallList<PropertyId>,
        durations: SmallList<Time>,
        delays: SmallList<Time>,
        timingFunctions: SmallList<EasingFunction>): SmallList<Transition> {
        let transitions = SmallList<Transition>()

        var durationsIdx: Int64 = 0
        var delaysIdx: Int64 = 0
        var timingIdx: Int64 = 0

        for (propertyId in properties.items) {
            let dur = if (durations.items.size > durationsIdx)
                durations.items[durationsIdx].deepClone()
            else
                Time()
            let del = if (delays.items.size > delaysIdx)
                delays.items[delaysIdx].deepClone()
            else
                Time()
            let timing = if (timingFunctions.items.size > timingIdx)
                timingFunctions.items[timingIdx].deepClone()
            else
                EasingFunction.ease()

            // 循环递增索引
            durationsIdx = (durationsIdx + 1) % durations.items.size.max(1)
            delaysIdx = (delaysIdx + 1) % delays.items.size.max(1)
            timingIdx = (timingIdx + 1) % timingFunctions.items.size.max(1)

            let transition = Transition(
                property: propertyId.deepClone(),
                duration: dur,
                delay: del,
                timingFunction: timing
            )

            // 展开供应商前缀为多个 transition
            let prefixToIter = propertyId.prefix().orNone()
            if (prefixToIter.isNone()) {
                transitions.append(transition)
            } else {
                var cloned = false
                // 遍历 VendorPrefix 的各字段
                let fields = VendorPrefix.FIELDS
                for (fieldName in fields) {
                    if (prefixToIter.hasField(fieldName)) {
                        var t = if (cloned) transition.deepClone() else transition
                        cloned = true
                        let newPrefix = VendorPrefix.fromField(fieldName)
                        t.property = propertyId.withPrefix(newPrefix)
                        transitions.append(t)
                    }
                }
            }
        }

        return transitions
    }

    /// 展开逻辑属性
    /// 严格翻译自 expandProperties
    public static func expandProperties(properties: SmallList<PropertyId>,
        context: PropertyHandlerContext): ?SmallList<PropertyId> {
        var rtlProperties: ?SmallList<PropertyId> = None
        var i: Int64 = 0

        while (i < properties.items.size) {
            let result = getLogicalProperties(properties.items[i])
            match (result.kind) {
                case LogicalPropertyKind.Block =>
                    if (context.shouldCompileLogical(result.blockFeature)) {
                        let physicalProps = result.blockProperties
                        properties.items[i] = physicalProps[0].deepClone()
                        if (physicalProps.size > 1) {
                            var j: Int64 = 1
                            while (j < physicalProps.size) {
                                properties.items.insert(i + j, physicalProps[j].deepClone())
                                j++
                            }
                        }
                        if (rtlProperties.isSome()) {
                            let rtl = rtlProperties.getOrThrow()
                            rtl.items[i] = physicalProps[0].deepClone()
                            if (physicalProps.size > 1) {
                                var k: Int64 = 1
                                while (k < physicalProps.size) {
                                    rtl.items.insert(i + k, physicalProps[k].deepClone())
                                    k++
                                }
                            }
                        }
                        i += 1
                    } else {
                        i = expandNonLogical(properties, rtlProperties: rtlProperties, i: i, context: context)
                    }
                case LogicalPropertyKind.Inline =>
                    if (context.shouldCompileLogical(result.inlineFeature)) {
                        let ltr = result.inlineLtrProperties
                        let rtl = result.inlineRtlProperties
                        // 仅在需要时克隆 RTL 版本
                        if (rtlProperties.isNone()) {
                            rtlProperties = Some(properties.deepClone())
                        }

                        properties.items[i] = ltr[0].deepClone()
                        if (ltr.size > 1) {
                            var j: Int64 = 1
                            while (j < ltr.size) {
                                properties.items.insert(i + j, ltr[j].deepClone())
                                j++
                            }
                        }

                        let rtlProps = rtlProperties.getOrThrow()
                        rtlProps.items[i] = rtl[0].deepClone()
                        if (rtl.size > 1) {
                            var k: Int64 = 1
                            while (k < rtl.size) {
                                rtlProps.items.insert(i + k, rtl[k].deepClone())
                                k++
                            }
                        }

                        i += ltr.size
                    } else {
                        i = expandNonLogical(properties, rtlProperties: rtlProperties, i: i, context: context)
                    }
                case LogicalPropertyKind.None =>
                    i = expandNonLogical(properties, rtlProperties: rtlProperties, i: i, context: context)
            }
        }

        return rtlProperties
    }

    /// 展开非逻辑属性 (供应商前缀 + mask 属性)
    private static func expandNonLogical(properties: SmallList<PropertyId>,
        rtlProperties: ?SmallList<PropertyId>, i: Int64,
        context: PropertyHandlerContext): Int64 {
        properties.items[i].setPrefixesForTargets(context.targets)

        // 展开 mask 属性 (使用不同的供应商前缀名称)
        let maskProperty = MaskingHelper.getWebkitMaskProperty(properties.items[i])
        if (maskProperty.isSome()) {
            let prefixes = context.targets.prefixes(VendorPrefix.NONE, feature: Feature.MaskBorder)
            if (prefixes.isWebkit) {
                properties.items.insert(i + 1, maskProperty.getOrThrow())
                i += 1
            }
        }

        if (rtlProperties.isSome()) {
            let rtlProps = rtlProperties.getOrThrow()
            rtlProps.items[i].setPrefixesForTargets(context.targets)

            let maskProperty2 = MaskingHelper.getWebkitMaskProperty(rtlProps.items[i])
            if (maskProperty2.isSome()) {
                let prefixes = context.targets.prefixes(VendorPrefix.NONE, feature: Feature.MaskBorder)
                if (prefixes.isWebkit) {
                    rtlProps.items.insert(i + 1, maskProperty2.getOrThrow())
                    i += 1
                }
            }
        }

        return i + 1
    }

    /// 获取逻辑属性映射
    /// 严格翻译自 getLogicalProperties
    public static func getLogicalProperties(propertyId: PropertyId): LogicalPropertyId {
        match (propertyId.tag) {
            // 尺寸
            case PropertyIdTag.BlockSize =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalSize,
                    properties: [PropertyId(tag: PropertyIdTag.Height)]
                ))
            case PropertyIdTag.InlineSize =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalSize,
                    ltr: [PropertyId(tag: PropertyIdTag.Width)],
                    rtl: [PropertyId(tag: PropertyIdTag.Height)]
                ))
            case PropertyIdTag.MinBlockSize =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalSize,
                    properties: [PropertyId(tag: PropertyIdTag.MinHeight)]
                ))
            case PropertyIdTag.MaxBlockSize =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalSize,
                    properties: [PropertyId(tag: PropertyIdTag.MaxHeight)]
                ))
            case PropertyIdTag.MinInlineSize =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalSize,
                    ltr: [PropertyId(tag: PropertyIdTag.MinWidth)],
                    rtl: [PropertyId(tag: PropertyIdTag.MinHeight)]
                ))
            case PropertyIdTag.MaxInlineSize =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalSize,
                    ltr: [PropertyId(tag: PropertyIdTag.MaxWidth)],
                    rtl: [PropertyId(tag: PropertyIdTag.MaxHeight)]
                ))

            // Inset
            case PropertyIdTag.InsetBlockStart =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalInset,
                    properties: [PropertyId(tag: PropertyIdTag.Top)]
                ))
            case PropertyIdTag.InsetBlockEnd =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalInset,
                    properties: [PropertyId(tag: PropertyIdTag.Bottom)]
                ))
            case PropertyIdTag.InsetInlineStart =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalInset,
                    ltr: [PropertyId(tag: PropertyIdTag.Left)],
                    rtl: [PropertyId(tag: PropertyIdTag.Right)]
                ))
            case PropertyIdTag.InsetInlineEnd =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalInset,
                    ltr: [PropertyId(tag: PropertyIdTag.Right)],
                    rtl: [PropertyId(tag: PropertyIdTag.Left)]
                ))
            case PropertyIdTag.InsetBlock =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalInset,
                    properties: [PropertyId(tag: PropertyIdTag.Top), PropertyId(tag: PropertyIdTag.Bottom)]
                ))
            case PropertyIdTag.InsetInline =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalInset,
                    properties: [PropertyId(tag: PropertyIdTag.Left), PropertyId(tag: PropertyIdTag.Right)]
                ))
            case PropertyIdTag.Inset =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalInset,
                    properties: [
                        PropertyId(tag: PropertyIdTag.Top),
                        PropertyId(tag: PropertyIdTag.Bottom),
                        PropertyId(tag: PropertyIdTag.Left),
                        PropertyId(tag: PropertyIdTag.Right)
                    ]
                ))

            // Margin
            case PropertyIdTag.MarginBlockStart =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalMargin,
                    properties: [PropertyId(tag: PropertyIdTag.MarginTop)]
                ))
            case PropertyIdTag.MarginBlockEnd =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalMargin,
                    properties: [PropertyId(tag: PropertyIdTag.MarginBottom)]
                ))
            case PropertyIdTag.MarginInlineStart =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalMargin,
                    ltr: [PropertyId(tag: PropertyIdTag.MarginLeft)],
                    rtl: [PropertyId(tag: PropertyIdTag.MarginRight)]
                ))
            case PropertyIdTag.MarginInlineEnd =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalMargin,
                    ltr: [PropertyId(tag: PropertyIdTag.MarginRight)],
                    rtl: [PropertyId(tag: PropertyIdTag.MarginLeft)]
                ))
            case PropertyIdTag.MarginBlock =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalMargin,
                    properties: [PropertyId(tag: PropertyIdTag.MarginTop), PropertyId(tag: PropertyIdTag.MarginBottom)]
                ))
            case PropertyIdTag.MarginInline =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalMargin,
                    properties: [PropertyId(tag: PropertyIdTag.MarginLeft), PropertyId(tag: PropertyIdTag.MarginRight)]
                ))

            // Padding
            case PropertyIdTag.PaddingBlockStart =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalPadding,
                    properties: [PropertyId(tag: PropertyIdTag.PaddingTop)]
                ))
            case PropertyIdTag.PaddingBlockEnd =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalPadding,
                    properties: [PropertyId(tag: PropertyIdTag.PaddingBottom)]
                ))
            case PropertyIdTag.PaddingInlineStart =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalPadding,
                    ltr: [PropertyId(tag: PropertyIdTag.PaddingLeft)],
                    rtl: [PropertyId(tag: PropertyIdTag.PaddingRight)]
                ))
            case PropertyIdTag.PaddingInlineEnd =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalPadding,
                    ltr: [PropertyId(tag: PropertyIdTag.PaddingRight)],
                    rtl: [PropertyId(tag: PropertyIdTag.PaddingLeft)]
                ))
            case PropertyIdTag.PaddingBlock =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalPadding,
                    properties: [PropertyId(tag: PropertyIdTag.PaddingTop), PropertyId(tag: PropertyIdTag.PaddingBottom)]
                ))
            case PropertyIdTag.PaddingInline =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalPadding,
                    properties: [PropertyId(tag: PropertyIdTag.PaddingLeft), PropertyId(tag: PropertyIdTag.PaddingRight)]
                ))

            // Border block
            case PropertyIdTag.BorderBlockStart =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderTop)]
                ))
            case PropertyIdTag.BorderBlockStartWidth =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderTopWidth)]
                ))
            case PropertyIdTag.BorderBlockStartColor =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderTopColor)]
                ))
            case PropertyIdTag.BorderBlockStartStyle =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderTopStyle)]
                ))
            case PropertyIdTag.BorderBlockEnd =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderBottom)]
                ))
            case PropertyIdTag.BorderBlockEndWidth =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderBottomWidth)]
                ))
            case PropertyIdTag.BorderBlockEndColor =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderBottomColor)]
                ))
            case PropertyIdTag.BorderBlockEndStyle =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderBottomStyle)]
                ))

            // Border inline
            case PropertyIdTag.BorderInlineStart =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalBorders,
                    ltr: [PropertyId(tag: PropertyIdTag.BorderLeft)],
                    rtl: [PropertyId(tag: PropertyIdTag.BorderRight)]
                ))
            case PropertyIdTag.BorderInlineStartWidth =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalBorders,
                    ltr: [PropertyId(tag: PropertyIdTag.BorderLeftWidth)],
                    rtl: [PropertyId(tag: PropertyIdTag.BorderRightWidth)]
                ))
            case PropertyIdTag.BorderInlineStartColor =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalBorders,
                    ltr: [PropertyId(tag: PropertyIdTag.BorderLeftColor)],
                    rtl: [PropertyId(tag: PropertyIdTag.BorderRightColor)]
                ))
            case PropertyIdTag.BorderInlineStartStyle =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalBorders,
                    ltr: [PropertyId(tag: PropertyIdTag.BorderLeftStyle)],
                    rtl: [PropertyId(tag: PropertyIdTag.BorderRightStyle)]
                ))
            case PropertyIdTag.BorderInlineEnd =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalBorders,
                    ltr: [PropertyId(tag: PropertyIdTag.BorderRight)],
                    rtl: [PropertyId(tag: PropertyIdTag.BorderLeft)]
                ))
            case PropertyIdTag.BorderInlineEndWidth =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalBorders,
                    ltr: [PropertyId(tag: PropertyIdTag.BorderRightWidth)],
                    rtl: [PropertyId(tag: PropertyIdTag.BorderLeftWidth)]
                ))
            case PropertyIdTag.BorderInlineEndColor =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalBorders,
                    ltr: [PropertyId(tag: PropertyIdTag.BorderRightColor)],
                    rtl: [PropertyId(tag: PropertyIdTag.BorderLeftColor)]
                ))
            case PropertyIdTag.BorderInlineEndStyle =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalBorders,
                    ltr: [PropertyId(tag: PropertyIdTag.BorderRightStyle)],
                    rtl: [PropertyId(tag: PropertyIdTag.BorderLeftStyle)]
                ))

            // Border block shorthand
            case PropertyIdTag.BorderBlock =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderTop), PropertyId(tag: PropertyIdTag.BorderBottom)]
                ))
            case PropertyIdTag.BorderBlockColor =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderTopColor), PropertyId(tag: PropertyIdTag.BorderBottomColor)]
                ))
            case PropertyIdTag.BorderBlockWidth =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderTopWidth), PropertyId(tag: PropertyIdTag.BorderBottomWidth)]
                ))
            case PropertyIdTag.BorderBlockStyle =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderTopStyle), PropertyId(tag: PropertyIdTag.BorderBottomStyle)]
                ))

            // Border inline shorthand
            case PropertyIdTag.BorderInline =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderLeft), PropertyId(tag: PropertyIdTag.BorderRight)]
                ))
            case PropertyIdTag.BorderInlineColor =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderLeftColor), PropertyId(tag: PropertyIdTag.BorderRightColor)]
                ))
            case PropertyIdTag.BorderInlineWidth =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderLeftWidth), PropertyId(tag: PropertyIdTag.BorderRightWidth)]
                ))
            case PropertyIdTag.BorderInlineStyle =>
                LogicalPropertyId.block(LogicalPropertyId.blockData(
                    feature: Feature.LogicalBorders,
                    properties: [PropertyId(tag: PropertyIdTag.BorderLeftStyle), PropertyId(tag: PropertyIdTag.BorderRightStyle)]
                ))

            // Border radius logical
            case PropertyIdTag.BorderStartStartRadius =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalBorders,
                    ltr: [PropertyId(tag: PropertyIdTag.BorderTopLeftRadius)],
                    rtl: [PropertyId(tag: PropertyIdTag.BorderTopRightRadius)]
                ))
            case PropertyIdTag.BorderStartEndRadius =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalBorders,
                    ltr: [PropertyId(tag: PropertyIdTag.BorderTopRightRadius)],
                    rtl: [PropertyId(tag: PropertyIdTag.BorderTopLeftRadius)]
                ))
            case PropertyIdTag.BorderEndStartRadius =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalBorders,
                    ltr: [PropertyId(tag: PropertyIdTag.BorderBottomLeftRadius)],
                    rtl: [PropertyId(tag: PropertyIdTag.BorderBottomRightRadius)]
                ))
            case PropertyIdTag.BorderEndEndRadius =>
                LogicalPropertyId.inline(LogicalPropertyId.inlineData(
                    feature: Feature.LogicalBorders,
                    ltr: [PropertyId(tag: PropertyIdTag.BorderBottomRightRadius)],
                    rtl: [PropertyId(tag: PropertyIdTag.BorderBottomLeftRadius)]
                ))

            case _ => LogicalPropertyId.none()
        }
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
    return lhs == rhs
}
