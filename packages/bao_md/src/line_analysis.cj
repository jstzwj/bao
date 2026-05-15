// 严格翻译自: src/md/line_analysis.zig
// 行分析函数
package bao_md

// ============================================================================
// Setext 下划线检测
// ============================================================================

/// Setext 下划线检测结果
public class SetextResult {
    public var is_setext: Bool = false
    public var level: UInt32 = 0
    public init() {}
}

/// 检查给定偏移量是否为 setext 下划线
public func isSetextUnderline(parser: Parser, off: OFF): SetextResult {
    let c = UInt8(parser.text[Int64(off)])
    if (c != '='.toUInt8() && c != '-'.toUInt8()) {
        return SetextResult()
    }

    var pos = Int64(off)
    while (pos < parser.size && UInt8(parser.text[pos]) == c) {
        pos += 1
    }

    // 跳过尾部空格
    while (pos < parser.size && isBlank(UInt8(parser.text[pos]))) {
        pos += 1
    }

    if (pos >= parser.size || isNewline(UInt8(parser.text[pos]))) {
        let level: UInt32 = if (c == '='.toUInt8()) 1 else 2
        return SetextResult(true, level)
    }

    return SetextResult()
}

// ============================================================================
// 水平线检测
// ============================================================================

/// 检查给定偏移量是否为水平线
public func isHrLine(parser: Parser, off: OFF): Bool {
    let c = UInt8(parser.text[Int64(off)])
    if (c != '-'.toUInt8() && c != '_'.toUInt8() && c != '*'.toUInt8()) {
        return false
    }

    var pos = Int64(off)
    var count: UInt32 = 0
    while (pos < parser.size && !isNewline(UInt8(parser.text[pos]))) {
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
// ATX 标题检测
// ============================================================================

/// ATX 标题检测结果
public class AtxResult {
    public var is_atx: Bool = false
    public var level: UInt32 = 0
    public var content_beg: OFF = 0
    public init() {}
}

/// 检查给定偏移量是否为 ATX 标题行
public func isAtxHeaderLine(parser: Parser, off: OFF): AtxResult {
    var pos = Int64(off)
    var level: UInt32 = 0

    while (pos < parser.size && parser.text[pos] == '#') {
        level += 1
        pos += 1
    }

    if (level == 0 || level > 6) {
        return AtxResult()
    }

    // 必须后跟空格或行尾
    if (pos < parser.size && !isBlank(UInt8(parser.text[pos])) && !isNewline(UInt8(parser.text[pos]))) {
        if (!parser.flags.permissive_atx_headers) {
            return AtxResult()
        }
    }

    // 跳过 # 后的空格
    while (pos < parser.size && isBlank(UInt8(parser.text[pos]))) {
        pos += 1
    }

    return AtxResult(true, level, UInt32(pos))
}

// ============================================================================
// 代码围栏检测
// ============================================================================

/// 代码围栏检测结果
public class FenceResult {
    public var is_fence: Bool = false
    public var fence_data: UInt32 = 0
    public init() {}
}

/// 检查是否为开始代码围栏
public func isOpeningCodeFence(parser: Parser, off: OFF): FenceResult {
    if (off >= parser.size) {
        return FenceResult()
    }
    let fence_char = UInt8(parser.text[Int64(off)])
    var pos = Int64(off)
    var count: UInt32 = 0

    while (pos < parser.size && UInt8(parser.text[pos]) == fence_char) {
        count += 1
        pos += 1
    }

    if (count < 3) {
        return FenceResult()
    }

    // 反引号围栏不能在信息字符串中有反引号
    if (fence_char == '`'.toUInt8()) {
        var check = pos
        while (check < parser.size && !isNewline(UInt8(parser.text[check]))) {
            if (UInt8(parser.text[check]) == '`'.toUInt8()) {
                return FenceResult()
            }
            check += 1
        }
    }

    let data: UInt32 = UInt32(fence_char) | (count << 8)
    return FenceResult(true, data)
}

/// 检查是否为结束代码围栏
public func isClosingCodeFence(parser: Parser, off: OFF, fence_data: UInt32): Bool {
    let fence_char: UInt8 = UInt8(fence_data & 0xFF)
    let fence_count = fence_data >> 8

    var pos = Int64(off)
    var count: UInt32 = 0
    while (pos < parser.size && UInt8(parser.text[pos]) == fence_char) {
        count += 1
        pos += 1
    }

    if (count < fence_count) {
        return false
    }

    while (pos < parser.size && isBlank(UInt8(parser.text[pos]))) {
        pos += 1
    }

    return pos >= parser.size || isNewline(UInt8(parser.text[pos]))
}

// ============================================================================
// HTML 块检测
// ============================================================================

/// 检查 HTML 块起始条件
public func isHtmlBlockStartCondition(parser: Parser, off: OFF): UInt8 {
    if (Int64(off + 1) >= parser.size) {
        return 0
    }

    // 类型 1: <script, <pre, <style, <textarea
    if (UInt8(parser.text[Int64(off + 1)]) != '/'.toUInt8() &&
        (matchHtmlTag(parser, Int64(off), "script") || matchHtmlTag(parser, Int64(off), "pre") ||
         matchHtmlTag(parser, Int64(off), "style") || matchHtmlTag(parser, Int64(off), "textarea"))) {
        return 1
    }

    // 类型 2: <!--
    if (Int64(off + 3) < parser.size &&
        parser.text[Int64(off + 1)] == '!' && parser.text[Int64(off + 2)] == '-' && parser.text[Int64(off + 3)] == '-') {
        return 2
    }

    // 类型 3: <?
    if (parser.text[Int64(off + 1)] == '?') {
        return 3
    }

    // 类型 4: <! 后跟大写字母
    if (parser.text[Int64(off + 1)] == '!' && Int64(off + 2) < parser.size) {
        let c = UInt8(parser.text[Int64(off + 2)])
        if (c >= 'A'.toUInt8() && c <= 'Z'.toUInt8()) {
            return 4
        }
    }

    // 类型 5: <![CDATA[
    if (Int64(off + 9) <= parser.size &&
        parser.text.substring(Int64(off + 1), Int64(off + 9)) == "![CDATA[") {
        return 5
    }

    // 类型 6: 块级标签
    if (isBlockLevelHtmlTag(parser, Int64(off))) {
        return 6
    }

    // 类型 7: 任何完整的开放或关闭标签
    if (isCompleteHtmlTag(parser, Int64(off))) {
        return 7
    }

    return 0
}

/// 检查 HTML 块结束条件
public func isHtmlBlockEndCondition(parser: Parser, off: OFF, block_type: UInt8): Bool {
    if (block_type >= 6) {
        return Int64(off) >= parser.size || isNewline(UInt8(parser.text[Int64(off)]))
    }

    var pos = Int64(off)
    while (pos < parser.size && !isNewline(UInt8(parser.text[pos]))) {
        match (block_type) {
            case 1 => {
                if (parser.text[pos] == '<' && pos + 1 < parser.size && parser.text[pos + 1] == '/') {
                    if (matchHtmlTag(parser, pos, "script") || matchHtmlTag(parser, pos, "pre") ||
                        matchHtmlTag(parser, pos, "style") || matchHtmlTag(parser, pos, "textarea")) {
                        return true
                    }
                }
            }
            case 2 => {
                if (parser.text[pos] == '-' && pos + 2 < parser.size &&
                    parser.text[pos + 1] == '-' && parser.text[pos + 2] == '>') {
                    return true
                }
            }
            case 3 => {
                if (parser.text[pos] == '?' && pos + 1 < parser.size && parser.text[pos + 1] == '>') {
                    return true
                }
            }
            case 4 => {
                if (parser.text[pos] == '>') {
                    return true
                }
            }
            case 5 => {
                if (parser.text[pos] == ']' && pos + 2 < parser.size &&
                    parser.text[pos + 1] == ']' && parser.text[pos + 2] == '>') {
                    return true
                }
            }
            case _ => return false
        }
        pos += 1
    }
    return false
}

/// 匹配 HTML 标签
public func matchHtmlTag(parser: Parser, off: Int64, tag: String): Bool {
    if (off + 1 + tag.length >= parser.size) {
        return false
    }
    var pos = off + 1
    if (pos < parser.size && parser.text[pos] == '/') {
        pos += 1
    }
    if (pos + tag.length > parser.size) {
        return false
    }
    if (!asciiCaseEql(parser.text.substring(pos, pos + tag.length), tag)) {
        return false
    }
    pos += tag.length
    if (pos >= parser.size) {
        return true
    }
    let after = UInt8(parser.text[pos])
    return after == '>'.toUInt8() || after == '/'.toUInt8() || isBlank(after) || isNewline(after)
}

/// 检查是否为块级 HTML 标签
public func isBlockLevelHtmlTag(parser: Parser, off: Int64): Bool {
    let block_tags: Array<String> = [
        "address", "article", "aside", "base", "basefont", "blockquote", "body",
        "caption", "center", "col", "colgroup", "dd", "details", "dialog",
        "dir", "div", "dl", "dt", "fieldset", "figcaption", "figure",
        "footer", "form", "frame", "frameset", "h1", "h2", "h3",
        "h4", "h5", "h6", "head", "header", "hr", "html",
        "iframe", "legend", "li", "link", "main", "menu", "menuitem",
        "nav", "noframes", "ol", "optgroup", "option", "p", "param",
        "search", "section", "summary", "table", "tbody", "td", "tfoot",
        "th", "thead", "title", "tr", "track", "ul",
    ]

    for (tag in block_tags) {
        if (matchHtmlTag(parser, off, tag)) {
            return true
        }
    }
    return false
}

/// 检查是否为完整的 HTML 标签
public func isCompleteHtmlTag(parser: Parser, off: Int64): Bool {
    if (off + 1 >= parser.size) {
        return false
    }
    var pos = off + 1
    let c = UInt8(parser.text[pos])

    // 关闭标签
    if (c == '/'.toUInt8()) {
        pos += 1
        if (pos >= parser.size || !isAlpha(UInt8(parser.text[pos]))) {
            return false
        }
        while (pos < parser.size && (isAlphaNum(UInt8(parser.text[pos])) || parser.text[pos] == '-')) {
            pos += 1
        }
        while (pos < parser.size && isBlank(UInt8(parser.text[pos]))) {
            pos += 1
        }
        if (pos >= parser.size || parser.text[pos] != '>') {
            return false
        }
        pos += 1
        while (pos < parser.size && isBlank(UInt8(parser.text[pos]))) {
            pos += 1
        }
        return pos >= parser.size || isNewline(UInt8(parser.text[pos]))
    }

    // 开放标签
    if (!isAlpha(c)) {
        return false
    }
    while (pos < parser.size && (isAlphaNum(UInt8(parser.text[pos])) || parser.text[pos] == '-')) {
        pos += 1
    }

    // 解析属性
    while (true) {
        let ws_start = pos
        while (pos < parser.size && isBlank(UInt8(parser.text[pos]))) {
            pos += 1
        }
        if (pos >= parser.size || isNewline(UInt8(parser.text[pos]))) {
            return false
        }
        if (parser.text[pos] == '>') {
            pos += 1
            break
        }
        if (parser.text[pos] == '/' && pos + 1 < parser.size && parser.text[pos + 1] == '>') {
            pos += 2
            break
        }
        if (pos == ws_start) {
            return false
        }

        // 属性名
        if (!isAlpha(UInt8(parser.text[pos])) && parser.text[pos] != '_' && parser.text[pos] != ':') {
            return false
        }
        pos += 1
        while (pos < parser.size && (isAlphaNum(UInt8(parser.text[pos])) ||
               parser.text[pos] == '_' || parser.text[pos] == ':' ||
               parser.text[pos] == '.' || parser.text[pos] == '-')) {
            pos += 1
        }

        // 可选属性值
        var ws_pos = pos
        while (ws_pos < parser.size && isBlank(UInt8(parser.text[ws_pos]))) {
            ws_pos += 1
        }
        if (ws_pos < parser.size && parser.text[ws_pos] == '=') {
            pos = ws_pos + 1
            while (pos < parser.size && isBlank(UInt8(parser.text[pos]))) {
                pos += 1
            }
            if (pos >= parser.size || isNewline(UInt8(parser.text[pos]))) {
                return false
            }
            if (parser.text[pos] == '"') {
                pos += 1
                while (pos < parser.size && parser.text[pos] != '"') {
                    pos += 1
                }
                if (pos >= parser.size) {
                    return false
                }
                pos += 1
            } else if (parser.text[pos] == '\'') {
                pos += 1
                while (pos < parser.size && parser.text[pos] != '\'') {
                    pos += 1
                }
                if (pos >= parser.size) {
                    return false
                }
                pos += 1
            } else {
                while (pos < parser.size && !isBlank(UInt8(parser.text[pos])) &&
                       parser.text[pos] != '"' && parser.text[pos] != '\'' &&
                       parser.text[pos] != '=' && parser.text[pos] != '<' &&
                       parser.text[pos] != '>' && parser.text[pos] != '`') {
                    pos += 1
                }
            }
        } else {
            pos = ws_start
        }
    }

    while (pos < parser.size && isBlank(UInt8(parser.text[pos]))) {
        pos += 1
    }
    return pos >= parser.size || isNewline(UInt8(parser.text[pos]))
}

// ============================================================================
// 表格下划线检测
// ============================================================================

/// 表格下划线检测结果
public class TableUnderlineResult {
    public var is_underline: Bool = false
    public var col_count: UInt32 = 0
    public init() {}
}

/// 检查给定偏移量是否为表格下划线
public func isTableUnderline(parser: Parser, off: OFF): TableUnderlineResult {
    var pos = Int64(off)
    var col_count: UInt32 = 0
    var had_pipe = false

    // 跳过前导管道符
    if (pos < parser.size && parser.text[pos] == '|') {
        had_pipe = true
        pos += 1
        while (pos < parser.size && isBlank(UInt8(parser.text[pos]))) {
            pos += 1
        }
    }

    while (pos < parser.size && !isNewline(UInt8(parser.text[pos]))) {
        let has_left_colon = pos < parser.size && parser.text[pos] == ':'
        if (has_left_colon) {
            pos += 1
        }

        var dash_count: UInt32 = 0
        while (pos < parser.size && parser.text[pos] == '-') {
            dash_count += 1
            pos += 1
        }

        if (dash_count == 0) {
            return TableUnderlineResult()
        }

        let has_right_colon = pos < parser.size && parser.text[pos] == ':'
        if (has_right_colon) {
            pos += 1
        }

        // 确定对齐方式
        if (col_count < TABLE_MAXCOLCOUNT) {
            parser.table_alignments[Int64(col_count)] = if (has_left_colon && has_right_colon) {
                Align.center
            } else if (has_left_colon) {
                Align.left
            } else if (has_right_colon) {
                Align.right
            } else {
                Align.default
            }
        }

        col_count += 1

        while (pos < parser.size && isBlank(UInt8(parser.text[pos]))) {
            pos += 1
        }

        if (pos < parser.size && parser.text[pos] == '|') {
            had_pipe = true
            pos += 1
            while (pos < parser.size && isBlank(UInt8(parser.text[pos]))) {
                pos += 1
            }
            if (pos >= parser.size || isNewline(UInt8(parser.text[pos]))) {
                break
            }
        } else if (pos >= parser.size || isNewline(UInt8(parser.text[pos]))) {
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

/// 计算表格行中的列数
public func countTableRowColumns(parser: Parser, beg: OFF, end: OFF): UInt32 {
    let row = parser.text.substring(Int64(beg), Int64(end))
    var col_count: UInt32 = 0
    var pos: Int64 = 0

    while (pos < row.length && isBlank(UInt8(row[pos]))) {
        pos += 1
    }

    if (pos < row.length && row[pos] == '|') {
        pos += 1
    }

    var in_cell = false
    while (pos < row.length) {
        if (row[pos] == '|') {
            col_count += 1
            in_cell = false
            pos += 1
        } else if (row[pos] == '\\' && pos + 1 < row.length) {
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
// 容器标记检测
// ============================================================================

/// 容器标记检测结果
public class ContainerMarkResult {
    public var is_container: Bool = false
    public var container: Container = Container()
    public var off: OFF = 0
    public init() {}
}

/// 检查给定偏移量是否为容器标记
public func isContainerMark(parser: Parser, indent: UInt32, off: OFF): ContainerMarkResult {
    if (Int64(off) >= parser.size) {
        return ContainerMarkResult()
    }

    // 缩进 >= 代码缩进偏移表示这是缩进代码，不是容器
    if (indent >= parser.code_indent_offset) {
        return ContainerMarkResult()
    }

    let c = UInt8(parser.text[Int64(off)])

    // 引用块
    if (c == '>'.toUInt8()) {
        return ContainerMarkResult(true, Container(), off + 1).also {
            it.container.ch = '>'.toUInt8()
            it.container.mark_indent = indent
            it.container.contents_indent = indent + 1
        }
    }

    // 无序列表: -, +, *
    if ((c == '-'.toUInt8() || c == '+'.toUInt8() || c == '*'.toUInt8()) &&
        Int64(off + 1) < parser.size && isBlank(UInt8(parser.text[Int64(off + 1)]))) {
        return ContainerMarkResult(true, Container(), off + 1).also {
            it.container.ch = c
            it.container.mark_indent = indent
            it.container.contents_indent = indent + 1
        }
    }
    // 空无序列表项
    if ((c == '-'.toUInt8() || c == '+'.toUInt8() || c == '*'.toUInt8()) &&
        (Int64(off + 1) >= parser.size || isNewline(UInt8(parser.text[Int64(off + 1)])))) {
        return ContainerMarkResult(true, Container(), off + 1).also {
            it.container.ch = c
            it.container.mark_indent = indent
            it.container.contents_indent = indent + 1
        }
    }

    // 有序列表: 数字后跟 . 或 )
    if (isDigit(c)) {
        var pos = Int64(off)
        var num: UInt32 = 0
        while (pos < parser.size && isDigit(UInt8(parser.text[pos])) && pos - Int64(off) < 9) {
            num = num * 10 + UInt32(UInt8(parser.text[pos]) - '0'.toUInt8())
            pos += 1
        }
        if (pos < parser.size && (UInt8(parser.text[pos]) == '.'.toUInt8() || UInt8(parser.text[pos]) == ')'.toUInt8())) {
            let delim = UInt8(parser.text[pos])
            pos += 1
            if (pos < parser.size && isBlank(UInt8(parser.text[pos]))) {
                let mark_width = UInt32(pos - Int64(off))
                return ContainerMarkResult(true, Container(), UInt32(pos)).also {
                    it.container.ch = delim
                    it.container.start = num
                    it.container.mark_indent = indent
                    it.container.contents_indent = indent + mark_width
                }
            }
            if (pos >= parser.size || isNewline(UInt8(parser.text[pos]))) {
                let mark_width = UInt32(pos - Int64(off))
                return ContainerMarkResult(true, Container(), UInt32(pos)).also {
                    it.container.ch = delim
                    it.container.start = num
                    it.container.mark_indent = indent
                    it.container.contents_indent = indent + mark_width
                }
            }
        }
    }

    return ContainerMarkResult()
}
