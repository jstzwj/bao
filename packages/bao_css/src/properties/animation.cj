// bao_css - CSS Properties: Animation
// 严格翻译自: bun/src/css/properties/animation.rs
//   对应: animation.zig - CSS 动画属性
//   对应: Animation, AnimationName, AnimationIterationCount
//   对应: AnimationDirection, AnimationPlayState, AnimationFillMode
//   对应: AnimationComposition, AnimationTimeline, ScrollTimeline, ViewTimeline
//   对应: AnimationRange, AnimationRangeStart, AnimationRangeEnd
//   对应: AnimationAttachmentRange, TimelineRangeName
//   对应: Scroller, ScrollAxis
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// AnimationDirection
// 严格翻译自 AnimationDirection (DefineEnumProperty)
// ============================================================================

/// animation-direction 属性值
/// 严格翻译自 AnimationDirection
public enum AnimationDirection {
    | Normal
    | Reverse
    | Alternate
    | AlternateReverse

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case Reverse => "reverse"
            case Alternate => "alternate"
            case AlternateReverse => "alternate-reverse"
        }
    }

    public static func default(): AnimationDirection {
        AnimationDirection.Normal
    }
}

// ============================================================================
// AnimationPlayState
// 严格翻译自 AnimationPlayState (DefineEnumProperty)
// ============================================================================

/// animation-play-state 属性值
/// 严格翻译自 AnimationPlayState
public enum AnimationPlayState {
    | Running
    | Paused

    public func toCss(): String {
        match (this) {
            case Running => "running"
            case Paused => "paused"
        }
    }

    public static func default(): AnimationPlayState {
        AnimationPlayState.Running
    }
}

// ============================================================================
// AnimationFillMode
// 严格翻译自 AnimationFillMode (DefineEnumProperty)
// ============================================================================

/// animation-fill-mode 属性值
/// 严格翻译自 AnimationFillMode
public enum AnimationFillMode {
    | None
    | Forwards
    | Backwards
    | Both

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Forwards => "forwards"
            case Backwards => "backwards"
            case Both => "both"
        }
    }

    public static func default(): AnimationFillMode {
        AnimationFillMode.None
    }
}

// ============================================================================
// AnimationComposition
// 严格翻译自 AnimationComposition (DefineEnumProperty)
// ============================================================================

/// animation-composition 属性值
/// 严格翻译自 AnimationComposition
public enum AnimationComposition {
    | Replace
    | Add
    | Accumulate

    public func toCss(): String {
        match (this) {
            case Replace => "replace"
            case Add => "add"
            case Accumulate => "accumulate"
        }
    }
}

// ============================================================================
// AnimationIterationCount
// 严格翻译自 AnimationIterationCount
// ============================================================================

/// animation-iteration-count 属性值
/// 严格翻译自 AnimationIterationCount
public enum AnimationIterationCount {
    | Number(Float64)  // 动画重复次数
    | Infinite        // 无限重复

    public func toCss(): String {
        match (this) {
            case Number(n) => n.toString()
            case Infinite => "infinite"
        }
    }

    public static func default(): AnimationIterationCount {
        AnimationIterationCount.Number(1.0)
    }
}

// ============================================================================
// AnimationName
// 严格翻译自 AnimationName
// ============================================================================

/// animation-name 属性值
/// 严格翻译自 AnimationName
public enum AnimationName {
    | None             // "none" 关键字
    | Ident(String)    // @keyframes 规则标识符
    | Str(String)      // 字符串名称

    public func toCss(): String {
        match (this) {
            case None => "none"
            case Ident(s) => s
            case Str(s) => s
        }
    }
}

// ============================================================================
// Scroller
// 严格翻译自 Scroller (DefineEnumProperty)
// ============================================================================

/// scroll() 函数中的 scroller
/// 严格翻译自 Scroller
public enum Scroller {
    | Root     // 文档视口作为滚动容器
    | Nearest  // 最近的祖先滚动容器
    | Self_    // 元素自身的主盒子

    public func toCss(): String {
        match (this) {
            case Root => "root"
            case Nearest => "nearest"
            case Self_ => "self"
        }
    }

    public static func default(): Scroller {
        Scroller.Nearest
    }
}

// ============================================================================
// ScrollAxis
// 严格翻译自 ScrollAxis (DefineEnumProperty)
// ============================================================================

/// scroll() 函数中的滚动轴
/// 严格翻译自 ScrollAxis
public enum ScrollAxis {
    | Block   // 块轴
    | Inline  // 内联轴
    | X       // 水平轴
    | Y       // 垂直轴

    public func toCss(): String {
        match (this) {
            case Block => "block"
            case Inline => "inline"
            case X => "x"
            case Y => "y"
        }
    }

    public static func default(): ScrollAxis {
        ScrollAxis.Block
    }
}

// ============================================================================
// AnimationTimeline
// 严格翻译自 AnimationTimeline
// ============================================================================

/// animation-timeline 属性值
/// 严格翻译自 AnimationTimeline
public enum AnimationTimeline {
    | Auto                           // DocumentTimeline
    | None                           // 不关联时间线
    | DashedIdent(String)            // 通过名称引用的时间线
    | Scroll(ScrollTimeline)         // scroll() 函数
    | View(ViewTimeline)             // view() 函数

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case None => "none"
            case DashedIdent(d) => d
            case Scroll(st) => "scroll(" + st.toCss() + ")"
            case View(vt) => "view(" + vt.toCss() + ")"
        }
    }

    public static func default(): AnimationTimeline {
        AnimationTimeline.Auto
    }
}

// ============================================================================
// ScrollTimeline
// 严格翻译自 ScrollTimeline
// ============================================================================

/// scroll() 函数
/// 严格翻译自 ScrollTimeline
public class ScrollTimeline {
    public var scroller: Scroller     // 滚动容器
    public var axis: ScrollAxis       // 滚动轴

    public init(scroller: Scroller, axis: ScrollAxis) {
        this.scroller = scroller
        this.axis = axis
    }

    public func toCss(): String {
        return scroller.toCss() + " " + axis.toCss()
    }
}

// ============================================================================
// ViewTimeline
// 严格翻译自 ViewTimeline
// ============================================================================

/// view() 函数
/// 严格翻译自 ViewTimeline
public class ViewTimeline {
    public var axis: ScrollAxis       // 滚动轴
    public var inset: String          // 视图进度可见范围调整

    public init(axis: ScrollAxis, inset: String) {
        this.axis = axis
        this.inset = inset
    }

    public func toCss(): String {
        return axis.toCss()
    }
}

// ============================================================================
// TimelineRangeName
// 严格翻译自 TimelineRangeName
// ============================================================================

/// 视图进度时间线范围名称
/// 严格翻译自 TimelineRangeName
public enum TimelineRangeName {
    | Cover         // 完整范围
    | Contain       // 包含范围
    | Entry         // 进入范围
    | Exit          // 退出范围
    | EntryCrossing // 进入交叉范围
    | ExitCrossing  // 退出交叉范围

    public func toCss(): String {
        match (this) {
            case Cover => "cover"
            case Contain => "contain"
            case Entry => "entry"
            case Exit => "exit"
            case EntryCrossing => "entry-crossing"
            case ExitCrossing => "exit-crossing"
        }
    }
}

// ============================================================================
// AnimationAttachmentRange
// 严格翻译自 AnimationAttachmentRange
// ============================================================================

/// 动画附件范围
/// 严格翻译自 AnimationAttachmentRange
public enum AnimationAttachmentRange {
    | Normal                // 附件范围从时间线开始
    | LengthPercentage(String) // 指定点
    | TimelineRange(TimelineRangeNameValuePair) // 命名时间线范围

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case LengthPercentage(lp) => lp
            case TimelineRange(tr) => tr.toCss()
        }
    }
}

/// TimelineRange 名称 + 偏移
/// 严格翻译自 TimelineRange payload
public class TimelineRangeNameValuePair {
    public var name: TimelineRangeName  // 时间线范围名称
    public var offset: String           // 偏移

    public init(name: TimelineRangeName, offset: String) {
        this.name = name
        this.offset = offset
    }

    public func toCss(): String {
        return name.toCss() + " " + offset
    }
}

// ============================================================================
// AnimationRangeStart / AnimationRangeEnd
// 严格翻译自 AnimationRangeStart / AnimationRangeEnd
// ============================================================================

/// animation-range-start 属性值
/// 严格翻译自 AnimationRangeStart
public class AnimationRangeStart {
    public var v: AnimationAttachmentRange

    public init(v: AnimationAttachmentRange) {
        this.v = v
    }

    public func toCss(): String {
        return v.toCss()
    }
}

/// animation-range-end 属性值
/// 严格翻译自 AnimationRangeEnd
public class AnimationRangeEnd {
    public var v: AnimationAttachmentRange

    public init(v: AnimationAttachmentRange) {
        this.v = v
    }

    public func toCss(): String {
        return v.toCss()
    }
}

// ============================================================================
// AnimationRange
// 严格翻译自 AnimationRange
// ============================================================================

/// animation-range 简写属性值
/// 严格翻译自 AnimationRange
public class AnimationRange {
    public var start: AnimationRangeStart  // 动画附件范围开始
    public var end: AnimationRangeEnd      // 动画附件范围结束

    public init(start: AnimationRangeStart, end: AnimationRangeEnd) {
        this.start = start
        this.end = end
    }

    public func toCss(): String {
        return start.toCss() + " " + end.toCss()
    }
}

// ============================================================================
// Animation
// 严格翻译自 Animation (简写属性)
// ============================================================================

/// animation 简写属性值
/// 严格翻译自 Animation
public class Animation {
    public var name: AnimationName                // 动画名称
    public var duration: String                   // 持续时间（秒/毫秒）
    public var timingFunction: String             // 缓动函数
    public var iterationCount: AnimationIterationCount // 迭代次数
    public var direction: AnimationDirection       // 方向
    public var playState: AnimationPlayState       // 播放状态
    public var delay: String                       // 延迟时间
    public var fillMode: AnimationFillMode         // 填充模式
    public var timeline: AnimationTimeline         // 时间线

    public init() {
        this.name = AnimationName.None
        this.duration = "0s"
        this.timingFunction = "ease"
        this.iterationCount = AnimationIterationCount.Number(1.0)
        this.direction = AnimationDirection.Normal
        this.playState = AnimationPlayState.Running
        this.delay = "0s"
        this.fillMode = AnimationFillMode.None
        this.timeline = AnimationTimeline.Auto
    }

    public init(name: AnimationName, duration: String, timingFunction: String,
                iterationCount: AnimationIterationCount, direction: AnimationDirection,
                playState: AnimationPlayState, delay: String, fillMode: AnimationFillMode,
                timeline: AnimationTimeline) {
        this.name = name
        this.duration = duration
        this.timingFunction = timingFunction
        this.iterationCount = iterationCount
        this.direction = direction
        this.playState = playState
        this.delay = delay
        this.fillMode = fillMode
        this.timeline = timeline
    }

    /// 供应商前缀映射
    /// 严格翻译自 VENDOR_PREFIX_MAP
    public static let vendorPrefixMap: ArrayList<(String, Bool)> = ArrayList<String>([
        ("name", true), ("duration", true), ("timing_function", true),
        ("iteration_count", true), ("direction", true), ("play_state", true),
        ("delay", true), ("fill_mode", true)
    ])

    public func toCss(): String {
        var parts = ArrayList<String>()

        // 名称（如果有非默认值才输出）
        if (match (name) { case None => false case _ => true }) {
            // duration / delay（如果非零）
            if (duration != "0s" || delay != "0s") {
                parts.append(duration)
            }

            // timing-function（如果非 ease）
            if (timingFunction != "ease") {
                parts.append(timingFunction)
            }

            // delay（如果非零）
            if (delay != "0s") {
                parts.append(delay)
            }

            // iteration-count（如果非默认）
            if (iterationCount != AnimationIterationCount.Number(1.0)) {
                parts.append(iterationCount.toCss())
            }

            // direction（如果非默认）
            if (direction != AnimationDirection.Normal) {
                parts.append(direction.toCss())
            }

            // fill-mode（如果非默认）
            if (fillMode != AnimationFillMode.None) {
                parts.append(fillMode.toCss())
            }

            // play-state（如果非默认）
            if (playState != AnimationPlayState.Running) {
                parts.append(playState.toCss())
            }
        }

        parts.append(name.toCss())

        // timeline（如果非默认）
        if (match (name) { case None => false case _ => true }) {
            if (timeline != AnimationTimeline.Auto) {
                parts.append(timeline.toCss())
            }
        }

        return String.join(" ", parts)
    }
}
