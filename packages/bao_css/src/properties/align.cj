// bao_css - CSS Properties: Align
// 严格翻译自: bun/src/css/properties/align.rs
//   对应: align.zig - CSS 对齐属性
//   对应: AlignContent, AlignItems, AlignSelf, JustifyContent, JustifyItems, JustifySelf
//   对应: PlaceContent, PlaceItems, PlaceSelf, Gap
//   对应: ContentDistribution, ContentPosition, OverflowPosition, SelfPosition
// ============================================================================

package bao.css

import bao_core.*

// ============================================================================
// ContentDistribution
// 严格翻译自 ContentDistribution (DefineEnumProperty)
// ============================================================================

/// <content-distribution> 值
/// 严格翻译自 ContentDistribution
public enum ContentDistribution {
    | SpaceBetween    // "space-between"
    | SpaceAround     // "space-around"
    | SpaceEvenly     // "space-evenly"
    | Stretch         // "stretch"

    public func toCss(): String {
        match (this) {
            case SpaceBetween => "space-between"
            case SpaceAround => "space-around"
            case SpaceEvenly => "space-evenly"
            case Stretch => "stretch"
        }
    }

    public func parse(input: String): Option<ContentDistribution> {
        let lower = input.toLowerCase()
        match (lower) {
            case "space-between" => Some(ContentDistribution.SpaceBetween)
            case "space-around" => Some(ContentDistribution.SpaceAround)
            case "space-evenly" => Some(ContentDistribution.SpaceEvenly)
            case "stretch" => Some(ContentDistribution.Stretch)
            case _ => None
        }
    }
}

// ============================================================================
// OverflowPosition
// 严格翻译自 OverflowPosition (DefineEnumProperty)
// ============================================================================

/// <overflow-position> 值
/// 严格翻译自 OverflowPosition
public enum OverflowPosition {
    | Safe    // "safe"
    | Unsafe  // "unsafe"

    public func toCss(): String {
        match (this) {
            case Safe => "safe"
            case Unsafe => "unsafe"
        }
    }

    public func parse(input: String): Option<OverflowPosition> {
        let lower = input.toLowerCase()
        match (lower) {
            case "safe" => Some(OverflowPosition.Safe)
            case "unsafe" => Some(OverflowPosition.Unsafe)
            case _ => None
        }
    }
}

// ============================================================================
// ContentPosition
// 严格翻译自 ContentPosition (DefineEnumProperty)
// ============================================================================

/// <content-position> 值
/// 严格翻译自 ContentPosition
public enum ContentPosition {
    | Center    // "center"
    | Start     // "start"
    | End       // "end"
    | FlexStart // "flex-start"
    | FlexEnd   // "flex-end"

    public func toCss(): String {
        match (this) {
            case Center => "center"
            case Start => "start"
            case End => "end"
            case FlexStart => "flex-start"
            case FlexEnd => "flex-end"
        }
    }

    public func parse(input: String): Option<ContentPosition> {
        let lower = input.toLowerCase()
        match (lower) {
            case "center" => Some(ContentPosition.Center)
            case "start" => Some(ContentPosition.Start)
            case "end" => Some(ContentPosition.End)
            case "flex-start" => Some(ContentPosition.FlexStart)
            case "flex-end" => Some(ContentPosition.FlexEnd)
            case _ => None
        }
    }
}

// ============================================================================
// SelfPosition
// 严格翻译自 SelfPosition (DefineEnumProperty)
// ============================================================================

/// <self-position> 值
/// 严格翻译自 SelfPosition
public enum SelfPosition {
    | Center    // "center"
    | Start     // "start"
    | End       // "end"
    | SelfStart // "self-start"
    | SelfEnd   // "self-end"
    | FlexStart // "flex-start"
    | FlexEnd   // "flex-end"

    public func toCss(): String {
        match (this) {
            case Center => "center"
            case Start => "start"
            case End => "end"
            case SelfStart => "self-start"
            case SelfEnd => "self-end"
            case FlexStart => "flex-start"
            case FlexEnd => "flex-end"
        }
    }

    public func parse(input: String): Option<SelfPosition> {
        let lower = input.toLowerCase()
        match (lower) {
            case "center" => Some(SelfPosition.Center)
            case "start" => Some(SelfPosition.Start)
            case "end" => Some(SelfPosition.End)
            case "self-start" => Some(SelfPosition.SelfStart)
            case "self-end" => Some(SelfPosition.SelfEnd)
            case "flex-start" => Some(SelfPosition.FlexStart)
            case "flex-end" => Some(SelfPosition.FlexEnd)
            case _ => None
        }
    }
}

// ============================================================================
// BaselinePosition
// 严格翻译自 BaselinePosition
// ============================================================================

/// <baseline-position> 值
/// 严格翻译自 BaselinePosition
public enum BaselinePosition {
    | First  // "baseline" / "first baseline"
    | Last   // "last baseline"

    public func toCss(): String {
        match (this) {
            case First => "baseline"
            case Last => "last baseline"
        }
    }
}

// ============================================================================
// AlignContent
// 严格翻译自 AlignContent
// ============================================================================

/// align-content 属性值
/// 严格翻译自 AlignContent
public enum AlignContent {
    | Normal
    | BaselinePosition(BaselinePosition)
    | ContentDistribution(ContentDistribution)
    | ContentPosition(AlignContentContentPosition)

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case BaselinePosition(bp) => bp.toCss()
            case ContentDistribution(cd) => cd.toCss()
            case ContentPosition(cp) => cp.toCss()
        }
    }
}

/// AlignContent 的 ContentPosition 包装
/// 严格翻译自 AlignContentContentPosition
public class AlignContentContentPosition {
    public var overflow: Option<OverflowPosition>  // 溢出对齐模式
    public var value: ContentPosition               // 内容位置关键字

    public init(overflow: Option<OverflowPosition>, value: ContentPosition) {
        this.overflow = overflow
        this.value = value
    }

    public func toCss(): String {
        let prefix = match (overflow) {
            case Some(op) => op.toCss() + " "
            case None => ""
        }
        return prefix + value.toCss()
    }
}

// ============================================================================
// AlignItems
// 严格翻译自 AlignItems
// ============================================================================

/// align-items 属性值
/// 严格翻译自 AlignItems
public enum AlignItems {
    | Normal
    | Stretch
    | BaselinePosition(BaselinePosition)
    | SelfPosition(AlignItemsSelfPosition)

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case Stretch => "stretch"
            case BaselinePosition(bp) => bp.toCss()
            case SelfPosition(sp) => sp.toCss()
        }
    }
}

/// AlignItems 的 SelfPosition 包装
/// 严格翻译自 AlignItemsSelfPosition
public class AlignItemsSelfPosition {
    public var overflow: Option<OverflowPosition>
    public var value: SelfPosition

    public init(overflow: Option<OverflowPosition>, value: SelfPosition) {
        this.overflow = overflow
        this.value = value
    }

    public func toCss(): String {
        let prefix = match (overflow) {
            case Some(op) => op.toCss() + " "
            case None => ""
        }
        return prefix + value.toCss()
    }
}

// ============================================================================
// AlignSelf
// 严格翻译自 AlignSelf
// ============================================================================

/// align-self 属性值
/// 严格翻译自 AlignSelf
public enum AlignSelf {
    | Auto
    | Normal
    | Stretch
    | BaselinePosition(BaselinePosition)
    | SelfPosition(AlignSelfSelfPosition)

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case Normal => "normal"
            case Stretch => "stretch"
            case BaselinePosition(bp) => bp.toCss()
            case SelfPosition(sp) => sp.toCss()
        }
    }
}

/// AlignSelf 的 SelfPosition 包装
/// 严格翻译自 AlignSelfSelfPosition
public class AlignSelfSelfPosition {
    public var overflow: Option<OverflowPosition>
    public var value: SelfPosition

    public init(overflow: Option<OverflowPosition>, value: SelfPosition) {
        this.overflow = overflow
        this.value = value
    }

    public func toCss(): String {
        let prefix = match (overflow) {
            case Some(op) => op.toCss() + " "
            case None => ""
        }
        return prefix + value.toCss()
    }
}

// ============================================================================
// JustifyContent
// 严格翻译自 JustifyContent
// ============================================================================

/// justify-content 属性值
/// 严格翻译自 JustifyContent
public enum JustifyContent {
    | Normal
    | ContentDistribution(ContentDistribution)
    | ContentPosition(JustifyContentContentPosition)
    | Left(JustifyLeftRight)
    | Right(JustifyLeftRight)

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case ContentDistribution(cd) => cd.toCss()
            case ContentPosition(cp) => cp.toCss()
            case Left(lr) => lr.toCss("left")
            case Right(lr) => lr.toCss("right")
        }
    }
}

/// JustifyContent 的 ContentPosition 包装
/// 严格翻译自 JustifyContentContentPosition
public class JustifyContentContentPosition {
    public var value: ContentPosition
    public var overflow: Option<OverflowPosition>

    public init(value: ContentPosition, overflow: Option<OverflowPosition>) {
        this.value = value
        this.overflow = overflow
    }

    public func toCss(): String {
        let prefix = match (overflow) {
            case Some(op) => op.toCss() + " "
            case None => ""
        }
        return prefix + value.toCss()
    }
}

/// JustifyContent Left/Right 的包装
/// 严格翻译自 JustifyContent Left/Right payload
public class JustifyLeftRight {
    public var overflow: Option<OverflowPosition>

    public init(overflow: Option<OverflowPosition>) {
        this.overflow = overflow
    }

    public func toCss(direction: String): String {
        let prefix = match (overflow) {
            case Some(op) => op.toCss() + " "
            case None => ""
        }
        return prefix + direction
    }
}

// ============================================================================
// JustifyItems
// 严格翻译自 JustifyItems
// ============================================================================

/// justify-items 属性值
/// 严格翻译自 JustifyItems
public enum JustifyItems {
    | Normal
    | Stretch
    | BaselinePosition(BaselinePosition)
    | SelfPosition(JustifyItemsSelfPosition)
    | Left(JustifyLeftRight)
    | Right(JustifyLeftRight)
    | Legacy(LegacyJustify)

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case Stretch => "stretch"
            case BaselinePosition(bp) => bp.toCss()
            case SelfPosition(sp) => sp.toCss()
            case Left(lr) => lr.toCss("left")
            case Right(lr) => lr.toCss("right")
            case Legacy(l) => l.toCss()
        }
    }
}

/// JustifyItems 的 SelfPosition 包装
/// 严格翻译自 JustifyItemsSelfPosition
public class JustifyItemsSelfPosition {
    public var value: SelfPosition
    public var overflow: Option<OverflowPosition>

    public init(value: SelfPosition, overflow: Option<OverflowPosition>) {
        this.value = value
        this.overflow = overflow
    }

    public func toCss(): String {
        let prefix = match (overflow) {
            case Some(op) => op.toCss() + " "
            case None => ""
        }
        return prefix + value.toCss()
    }
}

// ============================================================================
// JustifySelf
// 严格翻译自 JustifySelf
// ============================================================================

/// justify-self 属性值
/// 严格翻译自 JustifySelf
public enum JustifySelf {
    | Auto
    | Normal
    | Stretch
    | BaselinePosition(BaselinePosition)
    | SelfPosition(JustifySelfSelfPosition)
    | Left(JustifyLeftRight)
    | Right(JustifyLeftRight)

    public func toCss(): String {
        match (this) {
            case Auto => "auto"
            case Normal => "normal"
            case Stretch => "stretch"
            case BaselinePosition(bp) => bp.toCss()
            case SelfPosition(sp) => sp.toCss()
            case Left(lr) => lr.toCss("left")
            case Right(lr) => lr.toCss("right")
        }
    }
}

/// JustifySelf 的 SelfPosition 包装
/// 严格翻译自 JustifySelfSelfPosition
public class JustifySelfSelfPosition {
    public var value: SelfPosition
    public var overflow: Option<OverflowPosition>

    public init(value: SelfPosition, overflow: Option<OverflowPosition>) {
        this.value = value
        this.overflow = overflow
    }

    public func toCss(): String {
        let prefix = match (overflow) {
            case Some(op) => op.toCss() + " "
            case None => ""
        }
        return prefix + value.toCss()
    }
}

// ============================================================================
// LegacyJustify
// 严格翻译自 LegacyJustify
// ============================================================================

/// 旧版 justify 关键字
/// 严格翻译自 LegacyJustify
public enum LegacyJustify {
    | Left
    | Right
    | Center

    public func toCss(): String {
        let inner = match (this) {
            case Left => "left"
            case Right => "right"
            case Center => "center"
        }
        return "legacy " + inner
    }
}

// ============================================================================
// GapValue / Gap
// 严格翻译自 GapValue / Gap
// ============================================================================

/// gap 值（column-gap / row-gap）
/// 严格翻译自 GapValue
public enum GapValue {
    | Normal
    | LengthPercentage(String)  // 长度百分比字符串表示

    public func toCss(): String {
        match (this) {
            case Normal => "normal"
            case LengthPercentage(lp) => lp
        }
    }
}

/// gap 简写属性值
/// 严格翻译自 Gap
public class Gap {
    public var row: GapValue     // 行间距
    public var column: GapValue  // 列间距

    public init(row: GapValue, column: GapValue) {
        this.row = row
        this.column = column
    }

    public func toCss(): String {
        if (row == column) {
            return row.toCss()
        }
        return row.toCss() + " " + column.toCss()
    }
}

// ============================================================================
// PlaceContent
// 严格翻译自 PlaceContent
// ============================================================================

/// place-content 简写属性值
/// 严格翻译自 PlaceContent
public class PlaceContent {
    public var align: AlignContent    // 对齐
    public var justify: JustifyContent // 对齐内容

    public init(align: AlignContent, justify: JustifyContent) {
        this.align = align
        this.justify = justify
    }

    public func toCss(): String {
        return align.toCss() + " " + justify.toCss()
    }
}

// ============================================================================
// PlaceItems
// 严格翻译自 PlaceItems
// ============================================================================

/// place-items 简写属性值
/// 严格翻译自 PlaceItems
public class PlaceItems {
    public var align: AlignItems      // 对齐项目
    public var justify: JustifyItems   // 对齐内容

    public init(align: AlignItems, justify: JustifyItems) {
        this.align = align
        this.justify = justify
    }

    public func toCss(): String {
        return align.toCss() + " " + justify.toCss()
    }
}

// ============================================================================
// PlaceSelf
// 严格翻译自 PlaceSelf
// ============================================================================

/// place-self 简写属性值
/// 严格翻译自 PlaceSelf
public class PlaceSelf {
    public var align: AlignSelf       // 对齐自身
    public var justify: JustifySelf    // 对齐内容

    public init(align: AlignSelf, justify: JustifySelf) {
        this.align = align
        this.justify = justify
    }

    public func toCss(): String {
        return align.toCss() + " " + justify.toCss()
    }
}
