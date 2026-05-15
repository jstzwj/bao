// bao_css - CSS 缓动函数
// 严格翻译自: bun/src/css/values/easing.rs
//   对应: values/easing.zig - EasingFunction, CubicBezier, Steps, StepPosition
package bao_css.values

import bao_core.*

// ============================================================================
// 步进位置
// 严格翻译自: values/easing.rs StepPosition enum
// ============================================================================

/// CSS steps() 步进位置
/// 严格翻译自 StepPosition enum { Start, End, JumpNone, JumpBoth }
public enum CssStepPosition {
    | Start      // 第一次上升在输入进度值 0
    | End        // 最后一次上升在输入进度值 1 (默认)
    | JumpNone   // 所有上升在 (0, 1) 范围内
    | JumpBoth   // 第一次上升在 0，最后一次上升在 1

    public func toCss(): String {
        match (this) {
            case Start => "start"
            case End => "end"
            case JumpNone => "jump-none"
            case JumpBoth => "jump-both"
        }
    }
}

// ============================================================================
// 三次贝塞尔曲线
// 严格翻译自: values/easing.rs CubicBezier struct
// ============================================================================

/// CSS cubic-bezier() 参数
/// 严格翻译自 CubicBezier struct { x1, y1, x2, y2: CSSNumber }
public class CssCubicBezier {
    public var x1: Float64
    public var y1: Float64
    public var x2: Float64
    public var y2: Float64

    public init(x1: Float64, y1: Float64, x2: Float64, y2: Float64) {
        this.x1 = x1
        this.y1 = y1
        this.x2 = x2
        this.y2 = y2
    }

    /// 相等比较
    public func eql(other: CssCubicBezier): Bool {
        x1 == other.x1 && y1 == other.y1 && x2 == other.x2 && y2 == other.y2
    }
}

// ============================================================================
// 步进函数
// 严格翻译自: values/easing.rs Steps struct
// ============================================================================

/// CSS steps() 参数
/// 严格翻译自 Steps struct { count: CSSInteger, position: StepPosition }
public class CssSteps {
    /// 间隔数
    public var count: Int64
    /// 步进位置
    public var position: CssStepPosition

    public init(count: Int64, position: CssStepPosition) {
        this.count = count
        this.position = position
    }

    public init() {
        this.count = 0
        this.position = CssStepPosition.End
    }
}

// ============================================================================
// 缓动函数
// 严格翻译自: values/easing.rs EasingFunction enum
// ============================================================================

/// CSS <easing-function>
/// 严格翻译自 EasingFunction enum { Linear, Ease, EaseIn, EaseOut, EaseInOut, CubicBezier, Steps }
public class CssEasingFunction {
    public enum CssEasingFunctionKind {
        | Linear
        | Ease         // 等效于 cubic-bezier(0.25, 0.1, 0.25, 1)
        | EaseIn       // 等效于 cubic-bezier(0.42, 0, 1, 1)
        | EaseOut      // 等效于 cubic-bezier(0, 0, 0.58, 1)
        | EaseInOut    // 等效于 cubic-bezier(0.42, 0, 0.58, 1)
        | CubicBezier
        | Steps
    }

    public var kind: CssEasingFunctionKind
    /// 三次贝塞尔参数
    public var cubicBezier: ?CssCubicBezier
    /// 步进参数
    public var steps: ?CssSteps

    public init(kind: CssEasingFunctionKind) {
        this.kind = kind
        this.cubicBezier = None
        this.steps = None
    }

    public init(cubicBezier: CssCubicBezier) {
        this.kind = CssEasingFunctionKind.CubicBezier
        this.cubicBezier = Some(cubicBezier)
        this.steps = None
    }

    public init(steps: CssSteps) {
        this.kind = CssEasingFunctionKind.Steps
        this.cubicBezier = None
        this.steps = Some(steps)
    }

    /// 是否等效于 ease
    /// 严格翻译自 EasingFunction.is_ease
    public func isEase(): Bool {
        if (kind == CssEasingFunctionKind.Ease) { return true }
        match (cubicBezier) {
            case Some(cb) => cb.eql(CssCubicBezier(0.25, 0.1, 0.25, 1.0))
            case None => false
        }
    }

    /// 转为 CSS 文本
    /// 严格翻译自 EasingFunction.to_css
    public func toCss(): String {
        match (kind) {
            case Linear => "linear"
            case Ease => "ease"
            case EaseIn => "ease-in"
            case EaseOut => "ease-out"
            case EaseInOut => "ease-in-out"
            case CubicBezier => {
                match (cubicBezier) {
                    case Some(cb) => {
                        // 检查是否匹配预设值
                        if (cb.eql(CssCubicBezier(0.25, 0.1, 0.25, 1.0))) { return "ease" }
                        if (cb.eql(CssCubicBezier(0.42, 0.0, 1.0, 1.0))) { return "ease-in" }
                        if (cb.eql(CssCubicBezier(0.0, 0.0, 0.58, 1.0))) { return "ease-out" }
                        if (cb.eql(CssCubicBezier(0.42, 0.0, 0.58, 1.0))) { return "ease-in-out" }
                        "cubic-bezier(${cb.x1}, ${cb.y1}, ${cb.x2}, ${cb.y2})"
                    }
                    case None => "cubic-bezier(0, 0, 1, 1)"
                }
            }
            case Steps => {
                match (steps) {
                    case Some(s) => {
                        if (s.count == 1 && s.position == CssStepPosition.Start) { return "step-start" }
                        if (s.count == 1 && s.position == CssStepPosition.End) { return "step-end" }
                        "steps(${s.count}, ${s.position.toCss()})"
                    }
                    case None => "steps(1, end)"
                }
            }
        }
    }

    /// 是否为有效的缓动函数名
    /// 严格翻译自 EasingFunction.is_ident
    public static func isIdent(s: String): Bool {
        let lower = s.toLower()
        lower == "linear" || lower == "ease" || lower == "ease-in" || lower == "ease-out" || lower == "ease-in-out" || lower == "step-start" || lower == "step-end"
    }

    public func toString(): String {
        toCss()
    }
}
