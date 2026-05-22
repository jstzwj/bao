// bao_css - CSS Properties: Display
// 严格翻译自: bun/src/css/properties/display.rs
//   对应: display.zig - CSS 显示属性
//   对应: Display, DisplayKeyword, DisplayPair
//   对应: DisplayOutside, DisplayInside, Visibility
// ============================================================================

package bao_css.properties

import bao_core.*
import bao_collections.*

// ============================================================================
// Visibility
// 严格翻译自 Visibility (DefineEnumProperty)
// ============================================================================

/// visibility 属性值
/// 严格翻译自 Visibility
public enum Visibility {
    | Visible   // 可见
    | Hidden    // 隐藏
    | Collapse  // 折叠

    public func toCss(): String {
        match (this) {
            case Visible => "visible"
            case Hidden => "hidden"
            case Collapse => "collapse"
        }
    }
}

// ============================================================================
// DisplayKeyword
// 严格翻译自 DisplayKeyword (DefineEnumProperty)
// ============================================================================

/// display 关键字
/// 严格翻译自 DisplayKeyword
public enum DisplayKeyword {
    | NoneValue
    | Contents
    | TableRowGroup
    | TableHeaderGroup
    | TableFooterGroup
    | TableRow
    | TableCell
    | TableColumnGroup
    | TableColumn
    | TableCaption
    | RubyBase
    | RubyText
    | RubyBaseContainer
    | RubyTextContainer

    public func toCss(): String {
        match (this) {
            case NoneValue => "none"
            case Contents => "contents"
            case TableRowGroup => "table-row-group"
            case TableHeaderGroup => "table-header-group"
            case TableFooterGroup => "table-footer-group"
            case TableRow => "table-row"
            case TableCell => "table-cell"
            case TableColumnGroup => "table-column-group"
            case TableColumn => "table-column"
            case TableCaption => "table-caption"
            case RubyBase => "ruby-base"
            case RubyText => "ruby-text"
            case RubyBaseContainer => "ruby-base-container"
            case RubyTextContainer => "ruby-text-container"
        }
    }
}

// ============================================================================
// DisplayOutside
// 严格翻译自 DisplayOutside (DefineEnumProperty)
// ============================================================================

/// <display-outside> 值
/// 严格翻译自 DisplayOutside
public enum DisplayOutside {
    | Block
    | Inline
    | RunIn

    public func toCss(): String {
        match (this) {
            case Block => "block"
            case Inline => "inline"
            case RunIn => "run-in"
        }
    }

    public operator func ==(rhs: DisplayOutside): Bool {
        this.toCss() == rhs.toCss()
    }

    public operator func !=(rhs: DisplayOutside): Bool {
        this.toCss() != rhs.toCss()
    }
}

// ============================================================================
// DisplayInside
// 严格翻译自 DisplayInside
// ============================================================================

/// <display-inside> 值
/// 严格翻译自 DisplayInside
public enum DisplayInside {
    | Flow
    | FlowRoot
    | Table
    | Flex(String)    // 供应商前缀（"" / "-webkit-" / "-ms-"）
    | Box(String)     // 供应商前缀（"-webkit-" / "-moz-"）
    | Grid
    | Ruby

    public func toCss(): String {
        match (this) {
            case Flow => "flow"
            case FlowRoot => "flow-root"
            case Table => "table"
            case Flex(prefix) => prefix + "flex"
            case Box(prefix) => prefix + "box"
            case Grid => "grid"
            case Ruby => "ruby"
        }
    }

    public operator func ==(rhs: DisplayInside): Bool {
        match (this) {
            case Flow => match (rhs) { case Flow => true case _ => false }
            case FlowRoot => match (rhs) { case FlowRoot => true case _ => false }
            case Table => match (rhs) { case Table => true case _ => false }
            case Flex(p1) => match (rhs) { case Flex(p2) => p1 == p2 case _ => false }
            case Box(p1) => match (rhs) { case Box(p2) => p1 == p2 case _ => false }
            case Grid => match (rhs) { case Grid => true case _ => false }
            case Ruby => match (rhs) { case Ruby => true case _ => false }
        }
    }

    public operator func !=(rhs: DisplayInside): Bool {
        !(this == rhs)
    }
}

// ============================================================================
// DisplayPair
// 严格翻译自 DisplayPair
// ============================================================================

/// display 内外值对
/// 严格翻译自 DisplayPair
public class DisplayPair {
    public var outside: DisplayOutside    // 外部显示值
    public var inside: DisplayInside      // 内部显示值
    public var isListItem: Bool           // 是否为列表项

    public init(outside: DisplayOutside, inside: DisplayInside, isListItem: Bool) {
        this.outside = outside
        this.inside = inside
        this.isListItem = isListItem
    }

    private func getDefaultOutside(): DisplayOutside {
        match (inside) {
            case Ruby => DisplayOutside.Inline
            case _ => DisplayOutside.Block
        }
    }

    public func toCss(): String {
        // 特殊快捷方式
        if (outside == DisplayOutside.Inline && !isListItem) {
            if (inside == DisplayInside.FlowRoot) { return "inline-block" }
            if (inside == DisplayInside.Table) { return "inline-table" }
            if (inside == DisplayInside.Grid) { return "inline-grid" }
        }

        var parts = ArrayList<String>()
        let defaultOutside = getDefaultOutside()
        if (outside != defaultOutside || (inside == DisplayInside.Flow && !isListItem)) {
            parts.append(outside.toCss())
        }
        if (inside != DisplayInside.Flow) {
            parts.append(inside.toCss())
        }
        if (isListItem) {
            parts.append("list-item")
        }
        if (parts.isEmpty()) {
            return "block"
        }
        var partArr = Array<String>(parts.size, repeat: "")
        var pi: Int64 = 0
        for (p in parts) { partArr[pi] = p; pi += 1 }
        return String.join(partArr, delimiter: " ")
    }
}

// ============================================================================
// Display
// 严格翻译自 Display
// ============================================================================

/// display 属性值
/// 严格翻译自 Display
public enum Display {
    | Keyword(DisplayKeyword)  // 显示关键字
    | Pair(DisplayPair)        // 内外值对

    public func toCss(): String {
        match (this) {
            case Keyword(kw) => kw.toCss()
            case Pair(p) => p.toCss()
        }
    }
}
