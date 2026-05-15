// bao_css - CSS Properties: Margin & Padding
// 严格翻译自: bun/src/css/properties/margin_padding.rs
//   对应: margin_padding.zig - CSS 外边距和内边距属性
//   对应: Inset, InsetBlock, InsetInline
//   对应: Margin, MarginBlock, MarginInline
//   对应: Padding, PaddingBlock, PaddingInline
//   对应: ScrollMargin, ScrollMarginBlock, ScrollMarginInline
//   对应: ScrollPadding, ScrollPaddingBlock, ScrollPaddingInline
// ============================================================================

package bao_css.properties

import bao_core.*

// ============================================================================
// Rect 简写类型 (top/right/bottom/left)
// 严格翻译自 define_rect_shorthand! 宏生成的结构体
// ============================================================================

/// inset 属性值 (top/right/bottom/left)
/// 严格翻译自 Inset (RectShorthand)
public class Inset {
    public var top: String
    public var right: String
    public var bottom: String
    public var left: String

    public init(top: String, right: String, bottom: String, left: String) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    public static func default(): Inset {
        Inset(top: "auto", right: "auto", bottom: "auto", left: "auto")
    }

    public func toCss(): String {
        return serializeRect(top, right, bottom, left)
    }
}

/// margin 属性值 (top/right/bottom/left)
/// 严格翻译自 Margin (RectShorthand)
public class Margin {
    public var top: String
    public var right: String
    public var bottom: String
    public var left: String

    public init(top: String, right: String, bottom: String, left: String) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    public static func default(): Margin {
        Margin(top: "0", right: "0", bottom: "0", left: "0")
    }

    public func toCss(): String {
        return serializeRect(top, right, bottom, left)
    }
}

/// padding 属性值 (top/right/bottom/left)
/// 严格翻译自 Padding (RectShorthand)
public class Padding {
    public var top: String
    public var right: String
    public var bottom: String
    public var left: String

    public init(top: String, right: String, bottom: String, left: String) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    public static func default(): Padding {
        Padding(top: "0", right: "0", bottom: "0", left: "0")
    }

    public func toCss(): String {
        return serializeRect(top, right, bottom, left)
    }
}

/// scroll-margin 属性值 (top/right/bottom/left)
/// 严格翻译自 ScrollMargin (RectShorthand)
public class ScrollMargin {
    public var top: String
    public var right: String
    public var bottom: String
    public var left: String

    public init(top: String, right: String, bottom: String, left: String) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    public static func default(): ScrollMargin {
        ScrollMargin(top: "0", right: "0", bottom: "0", left: "0")
    }

    public func toCss(): String {
        return serializeRect(top, right, bottom, left)
    }
}

/// scroll-padding 属性值 (top/right/bottom/left)
/// 严格翻译自 ScrollPadding (RectShorthand)
public class ScrollPadding {
    public var top: String
    public var right: String
    public var bottom: String
    public var left: String

    public init(top: String, right: String, bottom: String, left: String) {
        this.top = top
        this.right = right
        this.bottom = bottom
        this.left = left
    }

    public static func default(): ScrollPadding {
        ScrollPadding(top: "auto", right: "auto", bottom: "auto", left: "auto")
    }

    public func toCss(): String {
        return serializeRect(top, right, bottom, left)
    }
}

// ============================================================================
// Size 简写类型 (block_start/block_end 或 inline_start/inline_end)
// 严格翻译自 impl_size_shorthand! 宏生成的结构体
// ============================================================================

/// inset-block 属性值 (block_start/block_end)
/// 严格翻译自 InsetBlock (SizeShorthand)
public class InsetBlock {
    public var blockStart: String
    public var blockEnd: String

    public init(blockStart: String, blockEnd: String) {
        this.blockStart = blockStart
        this.blockEnd = blockEnd
    }

    public static func default(): InsetBlock {
        InsetBlock(blockStart: "auto", blockEnd: "auto")
    }

    public func toCss(): String {
        return serializeSize(blockStart, blockEnd)
    }
}

/// inset-inline 属性值 (inline_start/inline_end)
/// 严格翻译自 InsetInline (SizeShorthand)
public class InsetInline {
    public var inlineStart: String
    public var inlineEnd: String

    public init(inlineStart: String, inlineEnd: String) {
        this.inlineStart = inlineStart
        this.inlineEnd = inlineEnd
    }

    public static func default(): InsetInline {
        InsetInline(inlineStart: "auto", inlineEnd: "auto")
    }

    public func toCss(): String {
        return serializeSize(inlineStart, inlineEnd)
    }
}

/// margin-block 属性值 (block_start/block_end)
/// 严格翻译自 MarginBlock (SizeShorthand)
public class MarginBlock {
    public var blockStart: String
    public var blockEnd: String

    public init(blockStart: String, blockEnd: String) {
        this.blockStart = blockStart
        this.blockEnd = blockEnd
    }

    public static func default(): MarginBlock {
        MarginBlock(blockStart: "0", blockEnd: "0")
    }

    public func toCss(): String {
        return serializeSize(blockStart, blockEnd)
    }
}

/// margin-inline 属性值 (inline_start/inline_end)
/// 严格翻译自 MarginInline (SizeShorthand)
public class MarginInline {
    public var inlineStart: String
    public var inlineEnd: String

    public init(inlineStart: String, inlineEnd: String) {
        this.inlineStart = inlineStart
        this.inlineEnd = inlineEnd
    }

    public static func default(): MarginInline {
        MarginInline(inlineStart: "0", inlineEnd: "0")
    }

    public func toCss(): String {
        return serializeSize(inlineStart, inlineEnd)
    }
}

/// padding-block 属性值 (block_start/block_end)
/// 严格翻译自 PaddingBlock (SizeShorthand)
public class PaddingBlock {
    public var blockStart: String
    public var blockEnd: String

    public init(blockStart: String, blockEnd: String) {
        this.blockStart = blockStart
        this.blockEnd = blockEnd
    }

    public static func default(): PaddingBlock {
        PaddingBlock(blockStart: "0", blockEnd: "0")
    }

    public func toCss(): String {
        return serializeSize(blockStart, blockEnd)
    }
}

/// padding-inline 属性值 (inline_start/inline_end)
/// 严格翻译自 PaddingInline (SizeShorthand)
public class PaddingInline {
    public var inlineStart: String
    public var inlineEnd: String

    public init(inlineStart: String, inlineEnd: String) {
        this.inlineStart = inlineStart
        this.inlineEnd = inlineEnd
    }

    public static func default(): PaddingInline {
        PaddingInline(inlineStart: "0", inlineEnd: "0")
    }

    public func toCss(): String {
        return serializeSize(inlineStart, inlineEnd)
    }
}

/// scroll-margin-block 属性值 (block_start/block_end)
/// 严格翻译自 ScrollMarginBlock (SizeShorthand)
public class ScrollMarginBlock {
    public var blockStart: String
    public var blockEnd: String

    public init(blockStart: String, blockEnd: String) {
        this.blockStart = blockStart
        this.blockEnd = blockEnd
    }

    public static func default(): ScrollMarginBlock {
        ScrollMarginBlock(blockStart: "0", blockEnd: "0")
    }

    public func toCss(): String {
        return serializeSize(blockStart, blockEnd)
    }
}

/// scroll-margin-inline 属性值 (inline_start/inline_end)
/// 严格翻译自 ScrollMarginInline (SizeShorthand)
public class ScrollMarginInline {
    public var inlineStart: String
    public var inlineEnd: String

    public init(inlineStart: String, inlineEnd: String) {
        this.inlineStart = inlineStart
        this.inlineEnd = inlineEnd
    }

    public static func default(): ScrollMarginInline {
        ScrollMarginInline(inlineStart: "0", inlineEnd: "0")
    }

    public func toCss(): String {
        return serializeSize(inlineStart, inlineEnd)
    }
}

/// scroll-padding-block 属性值 (block_start/block_end)
/// 严格翻译自 ScrollPaddingBlock (SizeShorthand)
public class ScrollPaddingBlock {
    public var blockStart: String
    public var blockEnd: String

    public init(blockStart: String, blockEnd: String) {
        this.blockStart = blockStart
        this.blockEnd = blockEnd
    }

    public static func default(): ScrollPaddingBlock {
        ScrollPaddingBlock(blockStart: "auto", blockEnd: "auto")
    }

    public func toCss(): String {
        return serializeSize(blockStart, blockEnd)
    }
}

/// scroll-padding-inline 属性值 (inline_start/inline_end)
/// 严格翻译自 ScrollPaddingInline (SizeShorthand)
public class ScrollPaddingInline {
    public var inlineStart: String
    public var inlineEnd: String

    public init(inlineStart: String, inlineEnd: String) {
        this.inlineStart = inlineStart
        this.inlineEnd = inlineEnd
    }

    public static func default(): ScrollPaddingInline {
        ScrollPaddingInline(inlineStart: "auto", inlineEnd: "auto")
    }

    public func toCss(): String {
        return serializeSize(inlineStart, inlineEnd)
    }
}
