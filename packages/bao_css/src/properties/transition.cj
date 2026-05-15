// bao_css - CSS Properties: Transition
// 严格翻译自: bun/src/css/properties/transition.rs
//   对应: transition.zig - CSS 过渡属性
//   对应: Transition, TransitionHandler
// ============================================================================

package bao.css

import bao_core.*

// ============================================================================
// Transition
// 严格翻译自 Transition
// ============================================================================

/// transition 简写属性值
/// 严格翻译自 Transition
public class Transition {
    public var property: String          // 过渡属性名称
    public var duration: String          // 持续时间
    public var delay: String             // 延迟时间
    public var timingFunction: String    // 缓动函数

    public init() {
        this.property = "all"
        this.duration = "0s"
        this.delay = "0s"
        this.timingFunction = "ease"
    }

    public init(property: String, duration: String, delay: String, timingFunction: String) {
        this.property = property
        this.duration = duration
        this.delay = delay
        this.timingFunction = timingFunction
    }

    public func toCss(): String {
        var parts = ArrayList<String>()

        // 属性名称
        parts.append(property)

        // 持续时间（如果非零或延迟非零）
        if (duration != "0s" || delay != "0s") {
            parts.append(duration)
        }

        // 缓动函数（如果非 ease）
        if (timingFunction != "ease") {
            parts.append(timingFunction)
        }

        // 延迟（如果非零）
        if (delay != "0s") {
            parts.append(delay)
        }

        return String.join(" ", parts)
    }
}
