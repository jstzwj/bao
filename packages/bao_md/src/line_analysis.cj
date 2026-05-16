// Line analysis functions
// Translated from: src/md/line_analysis.zig
package bao_md

import std.collection.*

// ============================================================================
// Setext underline detection
// ============================================================================

public class SetextResult {
    public var is_setext: Bool = false
    public var level: UInt32 = 0
    public init() {}
    public init(is_setext: Bool, level: UInt32) {
        this.is_setext = is_setext
        this.level = level
    }
}

public func isSetextUnderline(parser: Parser, off: OFF): SetextResult {
    let c = UInt8(parser.text[Int64(off)])
    if (c != UInt8(0x3D) && c != UInt8(0x2D)) {
        return SetextResult()
    }

    var pos = Int64(off)
    while (pos < Int64(parser.size) && UInt8(parser.text[pos]) == c) {
        pos += 1
    }

    while (pos < Int64(parser.size) && isBlank(UInt8(parser.text[pos]))) {
        pos += 1
    }

    if (pos >= Int64(parser.size) || isNewline(UInt8(parser.text[pos]))) {
        let level: UInt32 = if (c == UInt8(0x3D)) { 1 } else { 2 }
        return SetextResult(true, level)
    }

    return SetextResult()
}

// ============================================================================
// Horizontal rule detection
// ============================================================================

public func isHrLine(parser: Parser, off: OFF): Bool {
    let c = UInt8(parser.text[Int64(off)])
    if (c != UInt8(0x2D) && c != UInt8(0x5F) && c != UInt8(0x2A)) {
        return false
    }

    var pos = Int64(off)
    var count: UInt32 = 0
    while (pos < Int64(parser.size) && !isNewline(UInt8(parser.text[pos]))) {
        if (UInt8(parser.text[pos]) == c) {
            count += 1
        } else if (!isBlank(UInt8(parser.text[pos]))) {
            return false
        }
        pos += 1
    }

    return count >= 3
}

// ============================================================================
// ATX heading detection
// ============================================================================

public class AtxResult {
    public var is_atx: Bool = false
    public var level: UInt32 = 0
    public var content_beg: OFF = 0
    public init() {}
    public init(is_atx: Bool, level: UInt32, content_beg: OFF) {
        this.is_atx = is_atx
        this.level = level
        this.content_beg = content_beg
    }
}

public func isAtxHeaderLine(parser: Parser, off: OFF): AtxResult {
    var pos = Int64(off)
    var level: UInt32 = 0

    while (pos < Int64(parser.size) && UInt8(parser.text[pos]) == UInt8(0x23)) {
        level += 1
        pos += 1
    }

    if (level == 0 || level > 6) {
        return AtxResult()
    }

    if (pos < Int64(parser.size) && !isBlank(UInt8(parser.text[pos])) && !isNewline(UInt8(parser.text[pos]))) {
        if (!parser.flags.permissive_atx_headers) {
            return AtxResult()
        }
    }

    while (pos < Int64(parser.size) && isBlank(UInt8(parser.text[pos]))) {
        pos += 1
    }

    return AtxResult(true, level, UInt32(pos))
}

// ============================================================================
// Code fence detection
// ============================================================================

public class FenceResult {
    public var is_fence: Bool = false
    public var fence_data: UInt32 = 0
    public init() {}
    public init(is_fence: Bool, fence_data: UInt32) {
        this.is_fence = is_fence
        this.fence_data = fence_data
    }
}

public func isOpeningCodeFence(parser: Parser, off: OFF): FenceResult {
    if (Int64(off) >= Int64(parser.size)) {
        return FenceResult()
    }
    let fence_char = UInt8(parser.text[Int64(off)])
    var pos = Int64(off)
    var count: UInt32 = 0

    while (pos < Int64(parser.size) && UInt8(parser.text[pos]) == fence_char) {
        count += 1
        pos += 1
    }

    if (count < 3) {
        return FenceResult()
    }

    if (fence_char == UInt8(0x60)) {
        var check = pos
        while (check < Int64(parser.size) && !isNewline(UInt8(parser.text[check]))) {
            if (UInt8(parser.text[check]) == UInt8(0x60)) {
                return FenceResult()
            }
            check += 1
        }
    }

    let data: UInt32 = UInt32(fence_char) | (count << 8)
    return FenceResult(true, data)
}

public func isClosingCodeFence(parser: Parser, off: OFF, fence_data: UInt32): Bool {
    let fence_char: UInt8 = UInt8(fence_data & 0xFF)
    let fence_count = fence_data >> 8

    var pos = Int64(off)
    var count: UInt32 = 0
    while (pos < Int64(parser.size) && UInt8(parser.text[pos]) == fence_char) {
        count += 1
        pos += 1
    }

    if (count < fence_count) {
        return false
    }

    while (pos < Int64(parser.size) && isBlank(UInt8(parser.text[pos]))) {
        pos += 1
    }

    return pos >= Int64(parser.size) || isNewline(UInt8(parser.text[pos]))
}

// ============================================================================
// HTML block detection
// ============================================================================

public func isHtmlBlockStartCondition(parser: Parser, off: OFF): UInt8 {
    if (Int64(off + 1) >= Int64(parser.size)) {
        return 0
    }

    // type 1: <script, <pre, <style, <textarea
    if (UInt8(parser.text[Int64(off + 1)]) != UInt8(0x2F) &&
        (matchHtmlTag(parser, Int64(off), "script") || matchHtmlTag(parser, Int64(off), "pre") ||
         matchHtmlTag(parser, Int64(off), "style") || matchHtmlTag(parser, Int64(off), "textarea"))) {
        return 1
    }

    // type 2: <!--
    if (Int64(off + 3) < Int64(parser.size) &&
        UInt8(parser.text[Int64(off + 1)]) == UInt8(0x21) && UInt8(parser.text[Int64(off + 2)]) == UInt8(0x2D) && UInt8(parser.text[Int64(off + 3)]) == UInt8(0x2D)) {
        return 2
    }

    // type 3: <?
    if (UInt8(parser.text[Int64(off + 1)]) == UInt8(0x3F)) {
        return 3
    }

    // type 4: <! followed by uppercase letter
    if (UInt8(parser.text[Int64(off + 1)]) == UInt8(0x21) && Int64(off + 2) < Int64(parser.size)) {
        let ch = UInt8(parser.text[Int64(off + 2)])
        if (ch >= UInt8(0x41) && ch <= UInt8(0x5A)) {
            return 4
        }
    }

    // type 5: <![CDATA[
    if (Int64(off + 9) <= Int64(parser.size) &&
        asciiCaseEql(parser.text[Int64(off + 1)..Int64(off + 9)], "![CDATA[")) {
        return 5
    }

    // type 6: block-level tags
    if (isBlockLevelHtmlTag(parser, Int64(off))) {
        return 6
    }

    // type 7: complete open/close tags
    if (isCompleteHtmlTag(parser, Int64(off))) {
        return 7
    }

    return 0
}

public func isHtmlBlockEndCondition(parser: Parser, off: OFF, block_type: UInt8): Bool {
    if (block_type >= 6) {
        return Int64(off) >= Int64(parser.size) || isNewline(UInt8(parser.text[Int64(off)]))
    }

    var pos = Int64(off)
    while (pos < Int64(parser.size) && !isNewline(UInt8(parser.text[pos]))) {
        if (block_type == 1) {
            if (UInt8(parser.text[pos]) == UInt8(0x3C) && pos + 1 < Int64(parser.size) && UInt8(parser.text[pos + 1]) == UInt8(0x2F)) {
                if (matchHtmlTag(parser, pos, "script") || matchHtmlTag(parser, pos, "pre") ||
                    matchHtmlTag(parser, pos, "style") || matchHtmlTag(parser, pos, "textarea")) {
                    return true
                }
            }
        } else if (block_type == 2) {
            if (UInt8(parser.text[pos]) == UInt8(0x2D) && pos + 2 < Int64(parser.size) &&
                UInt8(parser.text[pos + 1]) == UInt8(0x2D) && UInt8(parser.text[pos + 2]) == UInt8(0x3E)) {
                return true
            }
        } else if (block_type == 3) {
            if (UInt8(parser.text[pos]) == UInt8(0x3F) && pos + 1 < Int64(parser.size) && UInt8(parser.text[pos + 1]) == UInt8(0x3E)) {
                return true
            }
        } else if (block_type == 4) {
            if (UInt8(parser.text[pos]) == UInt8(0x3E)) {
                return true
            }
        } else if (block_type == 5) {
            if (UInt8(parser.text[pos]) == UInt8(0x5D) && pos + 2 < Int64(parser.size) &&
                UInt8(parser.text[pos + 1]) == UInt8(0x5D) && UInt8(parser.text[pos + 2]) == UInt8(0x3E)) {
                return true
            }
        } else {
            return false
        }
        pos += 1
    }
    return false
}

public func matchHtmlTag(parser: Parser, off: Int64, tag: String): Bool {
    if (off + 1 + tag.size >= Int64(parser.size)) {
        return false
    }
    var pos = off + 1
    if (pos < Int64(parser.size) && UInt8(parser.text[pos]) == UInt8(0x2F)) {
        pos += 1
    }
    if (pos + tag.size > Int64(parser.size)) {
        return false
    }
    if (!asciiCaseEql(parser.text[pos..pos + tag.size], tag)) {
        return false
    }
    pos += tag.size
    if (pos >= Int64(parser.size)) {
        return true
    }
    let after = UInt8(parser.text[pos])
    return after == UInt8(0x3E) || after == UInt8(0x2F) || isBlank(after) || isNewline(after)
}

public func isBlockLevelHtmlTag(parser: Parser, off: Int64): Bool {
    let block_tags = ArrayList<String>()
    block_tags.add("address")
    block_tags.add("article")
    block_tags.add("aside")
    block_tags.add("base")
    block_tags.add("basefont")
    block_tags.add("blockquote")
    block_tags.add("body")
    block_tags.add("caption")
    block_tags.add("center")
    block_tags.add("col")
    block_tags.add("colgroup")
    block_tags.add("dd")
    block_tags.add("details")
    block_tags.add("dialog")
    block_tags.add("dir")
    block_tags.add("div")
    block_tags.add("dl")
    block_tags.add("dt")
    block_tags.add("fieldset")
    block_tags.add("figcaption")
    block_tags.add("figure")
    block_tags.add("footer")
    block_tags.add("form")
    block_tags.add("frame")
    block_tags.add("frameset")
    block_tags.add("h1")
    block_tags.add("h2")
    block_tags.add("h3")
    block_tags.add("h4")
    block_tags.add("h5")
    block_tags.add("h6")
    block_tags.add("head")
    block_tags.add("header")
    block_tags.add("hr")
    block_tags.add("html")
    block_tags.add("iframe")
    block_tags.add("legend")
    block_tags.add("li")
    block_tags.add("link")
    block_tags.add("main")
    block_tags.add("menu")
    block_tags.add("menuitem")
    block_tags.add("nav")
    block_tags.add("noframes")
    block_tags.add("ol")
    block_tags.add("optgroup")
    block_tags.add("option")
    block_tags.add("p")
    block_tags.add("param")
    block_tags.add("search")
    block_tags.add("section")
    block_tags.add("summary")
    block_tags.add("table")
    block_tags.add("tbody")
    block_tags.add("td")
    block_tags.add("tfoot")
    block_tags.add("th")
    block_tags.add("thead")
    block_tags.add("title")
    block_tags.add("tr")
    block_tags.add("track")
    block_tags.add("ul")

    for (j in 0..block_tags.size) {
        if (matchHtmlTag(parser, off, block_tags[j])) {
            return true
        }
    }
    return false
}

public func isCompleteHtmlTag(parser: Parser, off: Int64): Bool {
    if (off + 1 >= Int64(parser.size)) {
        return false
    }
    var pos = off + 1
    let c = UInt8(parser.text[pos])

    // closing tag
    if (c == UInt8(0x2F)) {
        pos += 1
        if (pos >= Int64(parser.size) || !isAlpha(UInt8(parser.text[pos]))) {
            return false
        }
        while (pos < Int64(parser.size) && (isAlphaNum(UInt8(parser.text[pos])) || UInt8(parser.text[pos]) == UInt8(0x2D))) {
            pos += 1
        }
        while (pos < Int64(parser.size) && isBlank(UInt8(parser.text[pos]))) {
            pos += 1
        }
        if (pos >= Int64(parser.size) || UInt8(parser.text[pos]) != UInt8(0x3E)) {
            return false
        }
        pos += 1
        while (pos < Int64(parser.size) && isBlank(UInt8(parser.text[pos]))) {
            pos += 1
        }
        return pos >= Int64(parser.size) || isNewline(UInt8(parser.text[pos]))
    }

    // open tag
    if (!isAlpha(c)) {
        return false
    }
    while (pos < Int64(parser.size) && (isAlphaNum(UInt8(parser.text[pos])) || UInt8(parser.text[pos]) == UInt8(0x2D))) {
        pos += 1
    }

    // parse attributes
    while (true) {
        let ws_start = pos
        while (pos < Int64(parser.size) && isBlank(UInt8(parser.text[pos]))) {
            pos += 1
        }
        if (pos >= Int64(parser.size) || isNewline(UInt8(parser.text[pos]))) {
            return false
        }
        if (UInt8(parser.text[pos]) == UInt8(0x3E)) {
            pos += 1
            break
        }
        if (UInt8(parser.text[pos]) == UInt8(0x2F) && pos + 1 < Int64(parser.size) && UInt8(parser.text[pos + 1]) == UInt8(0x3E)) {
            pos += 2
            break
        }
        if (pos == ws_start) {
            return false
        }

        // attribute name
        if (!isAlpha(UInt8(parser.text[pos])) && UInt8(parser.text[pos]) != UInt8(0x5F) && UInt8(parser.text[pos]) != UInt8(0x3A)) {
            return false
        }
        pos += 1
        while (pos < Int64(parser.size) && (isAlphaNum(UInt8(parser.text[pos])) ||
               UInt8(parser.text[pos]) == UInt8(0x5F) || UInt8(parser.text[pos]) == UInt8(0x3A) ||
               UInt8(parser.text[pos]) == UInt8(0x2E) || UInt8(parser.text[pos]) == UInt8(0x2D))) {
            pos += 1
        }

        // optional attribute value
        var ws_pos = pos
        while (ws_pos < Int64(parser.size) && isBlank(UInt8(parser.text[ws_pos]))) {
            ws_pos += 1
        }
        if (ws_pos < Int64(parser.size) && UInt8(parser.text[ws_pos]) == UInt8(0x3D)) {
            pos = ws_pos + 1
            while (pos < Int64(parser.size) && isBlank(UInt8(parser.text[pos]))) {
                pos += 1
            }
            if (pos >= Int64(parser.size) || isNewline(UInt8(parser.text[pos]))) {
                return false
            }
            if (UInt8(parser.text[pos]) == UInt8(0x22)) {
                pos += 1
                while (pos < Int64(parser.size) && UInt8(parser.text[pos]) != UInt8(0x22)) {
                    pos += 1
                }
                if (pos >= Int64(parser.size)) {
                    return false
                }
                pos += 1
            } else if (UInt8(parser.text[pos]) == UInt8(0x27)) {
                pos += 1
                while (pos < Int64(parser.size) && UInt8(parser.text[pos]) != UInt8(0x27)) {
                    pos += 1
                }
                if (pos >= Int64(parser.size)) {
                    return false
                }
                pos += 1
            } else {
                while (pos < Int64(parser.size) && !isBlank(UInt8(parser.text[pos])) &&
                       UInt8(parser.text[pos]) != UInt8(0x22) && UInt8(parser.text[pos]) != UInt8(0x27) &&
                       UInt8(parser.text[pos]) != UInt8(0x3D) && UInt8(parser.text[pos]) != UInt8(0x3C) &&
                       UInt8(parser.text[pos]) != UInt8(0x3E) && UInt8(parser.text[pos]) != UInt8(0x60)) {
                    pos += 1
                }
            }
        } else {
            pos = ws_start
        }
    }

    while (pos < Int64(parser.size) && isBlank(UInt8(parser.text[pos]))) {
        pos += 1
    }
    return pos >= Int64(parser.size) || isNewline(UInt8(parser.text[pos]))
}

// ============================================================================
// Table underline detection
// ============================================================================

public class TableUnderlineResult {
    public var is_underline: Bool = false
    public var col_count: UInt32 = 0
    public init() {}
    public init(is_underline: Bool, col_count: UInt32) {
        this.is_underline = is_underline
        this.col_count = col_count
    }
}

public func isTableUnderline(parser: Parser, off: OFF): TableUnderlineResult {
    var pos = Int64(off)
    var col_count: UInt32 = 0
    var had_pipe = false

    if (pos < Int64(parser.size) && UInt8(parser.text[pos]) == UInt8(0x7C)) {
        had_pipe = true
        pos += 1
        while (pos < Int64(parser.size) && isBlank(UInt8(parser.text[pos]))) {
            pos += 1
        }
    }

    while (pos < Int64(parser.size) && !isNewline(UInt8(parser.text[pos]))) {
        let has_left_colon = pos < Int64(parser.size) && UInt8(parser.text[pos]) == UInt8(0x3A)
        if (has_left_colon) {
            pos += 1
        }

        var dash_count: UInt32 = 0
        while (pos < Int64(parser.size) && UInt8(parser.text[pos]) == UInt8(0x2D)) {
            dash_count += 1
            pos += 1
        }

        if (dash_count == 0) {
            return TableUnderlineResult()
        }

        let has_right_colon = pos < Int64(parser.size) && UInt8(parser.text[pos]) == UInt8(0x3A)
        if (has_right_colon) {
            pos += 1
        }

        if (col_count < TABLE_MAXCOLCOUNT) {
            parser.table_alignments[Int64(col_count)] = if (has_left_colon && has_right_colon) {
                Align.center
            } else if (has_left_colon) {
                Align.left
            } else if (has_right_colon) {
                Align.right
            } else {
                Align.`default`
            }
        }

        col_count += 1

        while (pos < Int64(parser.size) && isBlank(UInt8(parser.text[pos]))) {
            pos += 1
        }

        if (pos < Int64(parser.size) && UInt8(parser.text[pos]) == UInt8(0x7C)) {
            had_pipe = true
            pos += 1
            while (pos < Int64(parser.size) && isBlank(UInt8(parser.text[pos]))) {
                pos += 1
            }
            if (pos >= Int64(parser.size) || isNewline(UInt8(parser.text[pos]))) {
                break
            }
        } else if (pos >= Int64(parser.size) || isNewline(UInt8(parser.text[pos]))) {
            break
        } else {
            return TableUnderlineResult()
        }
    }

    if (col_count == 0 || (!had_pipe && col_count < 2)) {
        return TableUnderlineResult()
    }

    parser.table_col_count = col_count
    return TableUnderlineResult(true, col_count)
}

public func countTableRowColumns(parser: Parser, beg: OFF, end: OFF): UInt32 {
    let row = parser.text[Int64(beg)..Int64(end)]
    var col_count: UInt32 = 0
    var pos: Int64 = 0

    while (pos < row.size && isBlank(UInt8(row[pos]))) {
        pos += 1
    }

    if (pos < row.size && UInt8(row[pos]) == UInt8(0x7C)) {
        pos += 1
    }

    var in_cell = false
    while (pos < row.size) {
        if (UInt8(row[pos]) == UInt8(0x7C)) {
            col_count += 1
            in_cell = false
            pos += 1
        } else if (UInt8(row[pos]) == UInt8(0x5C) && pos + 1 < row.size) {
            in_cell = true
            pos += 2
        } else if (isNewline(UInt8(row[pos]))) {
            break
        } else {
            in_cell = true
            pos += 1
        }
    }
    if (in_cell) {
        col_count += 1
    }
    return col_count
}

// ============================================================================
// Container mark detection
// ============================================================================

public class ContainerMarkResult {
    public var is_container: Bool = false
    public var container: Container = Container()
    public var off: OFF = 0
    public init() {}
}

public func isContainerMark(parser: Parser, indent: UInt32, off: OFF): ContainerMarkResult {
    if (Int64(off) >= Int64(parser.size)) {
        return ContainerMarkResult()
    }

    if (indent >= parser.code_indent_offset) {
        return ContainerMarkResult()
    }

    let c = UInt8(parser.text[Int64(off)])

    // blockquote
    if (c == UInt8(0x3E)) {
        let result = ContainerMarkResult()
        result.is_container = true
        result.off = off + 1
        result.container.ch = UInt8(0x3E)
        result.container.mark_indent = indent
        result.container.contents_indent = indent + 1
        return result
    }

    // unordered list: -, +, *
    if ((c == UInt8(0x2D) || c == UInt8(0x2B) || c == UInt8(0x2A)) &&
        Int64(off + 1) < Int64(parser.size) && isBlank(UInt8(parser.text[Int64(off + 1)]))) {
        let result = ContainerMarkResult()
        result.is_container = true
        result.off = off + 1
        result.container.ch = c
        result.container.mark_indent = indent
        result.container.contents_indent = indent + 1
        return result
    }
    if ((c == UInt8(0x2D) || c == UInt8(0x2B) || c == UInt8(0x2A)) &&
        (Int64(off + 1) >= Int64(parser.size) || isNewline(UInt8(parser.text[Int64(off + 1)])))) {
        let result = ContainerMarkResult()
        result.is_container = true
        result.off = off + 1
        result.container.ch = c
        result.container.mark_indent = indent
        result.container.contents_indent = indent + 1
        return result
    }

    // ordered lists
    if (isDigit(c)) {
        var pos = Int64(off)
        var num: UInt32 = 0
        while (pos < Int64(parser.size) && isDigit(UInt8(parser.text[pos])) && pos - Int64(off) < 9) {
            num = num * 10 + UInt32(UInt8(parser.text[pos]) - UInt8(0x30))
            pos += 1
        }
        if (pos < Int64(parser.size) && (UInt8(parser.text[pos]) == UInt8(0x2E) || UInt8(parser.text[pos]) == UInt8(0x29))) {
            let delim = UInt8(parser.text[pos])
            pos += 1
            if (pos < Int64(parser.size) && isBlank(UInt8(parser.text[pos]))) {
                let mark_width = UInt32(pos - Int64(off))
                let result = ContainerMarkResult()
                result.is_container = true
                result.off = UInt32(pos)
                result.container.ch = delim
                result.container.start = num
                result.container.mark_indent = indent
                result.container.contents_indent = indent + mark_width
                return result
            }
            if (pos >= Int64(parser.size) || isNewline(UInt8(parser.text[pos]))) {
                let mark_width = UInt32(pos - Int64(off))
                let result = ContainerMarkResult()
                result.is_container = true
                result.off = UInt32(pos)
                result.container.ch = delim
                result.container.start = num
                result.container.mark_indent = indent
                result.container.contents_indent = indent + mark_width
                return result
            }
        }
    }

    return ContainerMarkResult()
}
