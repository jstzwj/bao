// bao_css - CSS Properties: Flex
// 严格翻译自: bun/src/css/properties/flex.rs
//   对应: flex.zig - CSS 弹性布局属性
//   对应: FlexDirection, FlexWrap, FlexFlow, Flex
//   对应: BoxOrient, BoxDirection, BoxAlign, BoxPack, BoxLines
//   对应: FlexPack, FlexItemAlign, FlexLinePack, FlexHandler
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// FlexDirection
// 严格翻译自 FlexDirection (DefineEnumProperty)
// ============================================================================

/// flex-direction 属性值
/// 严格翻译自 FlexDirection
public enum FlexDirection {
    | Row          // 行
    | RowReverse   // 行反转
    | Column       // 列
    | ColumnReverse // 列反转

    public func toCss(): String {
        match (this) {
            case Row => "row"
            case RowReverse => "row-reverse"
            case Column => "column"
            case ColumnReverse => "column-reverse"
        }
    }

    public static func default(): FlexDirection {
        FlexDirection.Row
    }
}

// ============================================================================
// FlexWrap
// 严格翻译自 FlexWrap (DefineEnumProperty)
// ============================================================================

/// flex-wrap 属性值
/// 严格翻译自 FlexWrap
public enum FlexWrap {
    | Nowrap     // 不换行
    | Wrap       // 换行
    | WrapReverse // 换行反转

    public func toCss(): String {
        match (this) {
            case Nowrap => "nowrap"
            case Wrap => "wrap"
            case WrapReverse => "wrap-reverse"
        }
    }

    public static func default(): FlexWrap {
        FlexWrap.Nowrap
    }
}

// ============================================================================
// FlexFlow
// 严格翻译自 FlexFlow
// ============================================================================

/// flex-flow 简写属性值
/// 严格翻译自 FlexFlow
public class FlexFlow {
    public var direction: FlexDirection  // 方向
    public var wrap: FlexWrap            // 换行方式

    public init(direction: FlexDirection, wrap: FlexWrap) {
        this.direction = direction
        this.wrap = wrap
    }

    public func toCss(): String {
        var parts = ArrayList<String>()
        if (direction != FlexDirection.default() || wrap == FlexWrap.default()) {
            parts.append(direction.toCss())
        }
        if (wrap != FlexWrap.default()) {
            parts.append(wrap.toCss())
        }
        if (parts.isEmpty()) {
            return "row"
        }
        return String.join(" ", parts)
    }
}

// ============================================================================
// Flex
// 严格翻译自 Flex
// ============================================================================

/// flex 简写属性值
/// 严格翻译自 Flex
public class Flex {
    public var grow: Float64               // 弹性增长因子
    public var shrink: Float64             // 弹性收缩因子
    public var basis: String               // 弹性基准

    public init(grow: Float64, shrink: Float64, basis: String) {
        this.grow = grow
        this.shrink = shrink
        this.basis = basis
    }

    public static func none(): Flex {
        Flex(grow: 0.0, shrink: 0.0, basis: "auto")
    }

    public func toCss(): String {
        if (grow == 0.0 && shrink == 0.0 && basis == "auto") {
            return "none"
        }

        var parts = ArrayList<String>()
        if (grow != 1.0 || shrink != 1.0 || basis != "0%") {
            parts.append(grow.toString())
            if (shrink != 1.0) {
                parts.append(shrink.toString())
            }
        }
        if (basis != "0%") {
            parts.append(basis)
        }

        return String.join(" ", parts)
    }
}

// ============================================================================
// BoxOrient (旧版 2009)
// 严格翻译自 BoxOrient (DefineEnumProperty)
// ============================================================================

/// box-orient 旧版属性值
/// 严格翻译自 BoxOrient
public enum BoxOrient {
    | Horizontal  // 水平
    | Vertical    // 垂直
    | InlineAxis  // 内联轴
    | BlockAxis   // 块轴

    public func toCss(): String {
        match (this) {
            case Horizontal => "horizontal"
            case Vertical => "vertical"
            case InlineAxis => "inline-axis"
            case BlockAxis => "block-axis"
        }
    }
}

// ============================================================================
// BoxDirection (旧版 2009)
// 严格翻译自 BoxDirection (DefineEnumProperty)
// ============================================================================

/// box-direction 旧版属性值
/// 严格翻译自 BoxDirection
public enum BoxDirection {
    | Normal   // 正常方向
    | Reverse  // 反转方向

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case Reverse => "reverse"
        }
    }
}

// ============================================================================
// BoxAlign (旧版 2009)
// 严格翻译自 BoxAlign (DefineEnumProperty)
// ============================================================================

/// box-align 旧版属性值
/// 严格翻译自 BoxAlign
public enum BoxAlign {
    | Start     // 对齐到起始
    | End       // 对齐到结束
    | Center    // 居中
    | Baseline  // 基线对齐
    | Stretch   // 拉伸

    public func toCss(): String {
        match (this) {
            case Start => "start"
            case End => "end"
            case Center => "center"
            case Baseline => "baseline"
            case Stretch => "stretch"
        }
    }
}

// ============================================================================
// BoxPack (旧版 2009)
// 严格翻译自 BoxPack (DefineEnumProperty)
// ============================================================================

/// box-pack 旧版属性值
/// 严格翻译自 BoxPack
public enum BoxPack {
    | Start    // 对齐到起始
    | End      // 对齐到结束
    | Center   // 居中
    | Justify  // 两端对齐

    public func toCss(): String {
        match (this) {
            case Start => "start"
            case End => "end"
            case Center => "center"
            case Justify => "justify"
        }
    }
}

// ============================================================================
// BoxLines (旧版 2009)
// 严格翻译自 BoxLines (DefineEnumProperty)
// ============================================================================

/// box-lines 旧版属性值
/// 严格翻译自 BoxLines
public enum BoxLines {
    | Single   // 单行
    | Multiple // 多行

    public func toCss(): String {
        match (this) {
            case Single => "single"
            case Multiple => "multiple"
        }
    }
}

// ============================================================================
// FlexPack (旧版 2012)
// 严格翻译自 FlexPack (DefineEnumProperty)
// ============================================================================

/// flex-pack 旧版属性值
/// 严格翻译自 FlexPack
public enum FlexPack {
    | Start      // 对齐到起始
    | End        // 对齐到结束
    | Center     // 居中
    | Justify    // 两端对齐
    | Distribute // 均匀分布

    public func toCss(): String {
        match (this) {
            case Start => "start"
            case End => "end"
            case Center => "center"
            case Justify => "justify"
            case Distribute => "distribute"
        }
    }
}

// ============================================================================
// FlexItemAlign (旧版 2012)
// 严格翻译自 FlexItemAlign (DefineEnumProperty)
// ============================================================================

/// flex-item-align 旧版属性值
/// 严格翻译自 FlexItemAlign
public enum FlexItemAlign {
    | Auto      // 自动
    | Start     // 对齐到起始
    | End       // 对齐到结束
    | Center    // 居中
    | Baseline  // 基线对齐
    | Stretch   // 拉伸

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case Start => "start"
            case End => "end"
            case Center => "center"
            case Baseline => "baseline"
            case Stretch => "stretch"
        }
    }
}

// ============================================================================
// FlexLinePack (旧版 2012)
// 严格翻译自 FlexLinePack (DefineEnumProperty)
// ============================================================================

/// flex-line-pack 旧版属性值
/// 严格翻译自 FlexLinePack
public enum FlexLinePack {
    | Start      // 对齐到起始
    | End        // 对齐到结束
    | Center     // 居中
    | Justify    // 两端对齐
    | Distribute // 均匀分布
    | Stretch    // 拉伸

    public func toCss(): String {
        match (this) {
            case Start => "start"
            case End => "end"
            case Center => "center"
            case Justify => "justify"
            case Distribute => "distribute"
            case Stretch => "stretch"
        }
    }
}
