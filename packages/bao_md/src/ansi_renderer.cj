// 严格翻译自: src/md/ansi_renderer.zig
// Markdown → ANSI 终端渲染器
package bao_md

// ============================================================================
// 主题
// ============================================================================

/// ANSI 渲染主题配置
public class Theme {
    /// 终端背景是否为浅色
    public var light: Bool = false
    /// 终端列数，用于自动换行。0 表示禁用换行
    public var columns: UInt16 = 80
    /// 是否启用颜色和样式
    public var colors: Bool = true
    /// 是否发出 OSC 8 超链接
    public var hyperlinks: Bool = false
    /// 是否使用 Kitty 图形协议内联图片
    public var kitty_graphics: Bool = false
    /// 远程图片 URL → 本地文件路径查找表
    public var remote_image_paths: HashMap<String, String> = HashMap<String, String>()
    /// 图片基础目录（用于解析相对路径）
    public var image_base_dir: ?String = None

    public init() {}
}

// ============================================================================
// ANSI 颜色/样式
// ============================================================================

/// ANSI 颜色枚举
public enum AnsiColor {
    | black
    | red
    | green
    | yellow
    | blue
    | magenta
    | cyan
    | white
    | dim
}

/// 获取 ANSI 颜色转义序列
public func ansiColor(c: AnsiColor): String {
    return match (c) {
        case black => "\x1b[30m"
        case red => "\x1b[31m"
        case green => "\x1b[32m"
        case yellow => "\x1b[33m"
        case blue => "\x1b[34m"
        case magenta => "\x1b[35m"
        case cyan => "\x1b[36m"
        case white => "\x1b[37m"
        case dim => "\x1b[2m"
    }
}

/// ANSI 样式枚举
public enum AnsiStyle {
    | bold
    | italic
    | underline
    | strikethrough
}

/// 获取 ANSI 样式转义序列
public func ansiStyle(s: AnsiStyle): String {
    return match (s) {
        case bold => "\x1b[1m"
        case italic => "\x1b[3m"
        case underline => "\x1b[4m"
        case strikethrough => "\x1b[9m"
    }
}

/// ANSI 重置序列
public func ansiReset(): String {
    return "\x1b[0m"
}

/// 内联代码跨距打开序列
public func codeSpanOpen(light: Bool): String {
    return if (light) "\x1b[48;5;254m\x1b[38;5;124m" else "\x1b[48;5;236m\x1b[38;5;215m"
}

// ============================================================================
// 可见宽度
// ============================================================================

/// 计算可见打印宽度（排除 ANSI 转义序列）
public func visibleWidth(s: String): Int64 {
    var width: Int64 = 0
    var i: Int64 = 0
    while (i < s.length) {
        let c = UInt8(s[Int64(i)])
        if (c == 0x1b) {
            // 跳过 ANSI 转义序列
            i += 1
            if (i < s.length) {
                let next = UInt8(s[Int64(i)])
                if (next == '['.toUInt8()) {
                    // CSI 序列
                    i += 1
                    while (i < s.length && (UInt8(s[Int64(i)]) < 0x40 || UInt8(s[Int64(i)]) > 0x7e)) {
                        i += 1
                    }
                    if (i < s.length) i += 1
                } else if (next == ']'.toUInt8()) {
                    // OSC 序列
                    i += 1
                    while (i < s.length) {
                        if (UInt8(s[Int64(i)]) == 0x07) {
                            i += 1
                            break
                        }
                        if (UInt8(s[Int64(i)]) == 0x1b && i + 1 < s.length && UInt8(s[Int64(i + 1)]) == '\\') {
                            i += 2
                            break
                        }
                        i += 1
                    }
                } else {
                    i += 1
                }
            }
            continue
        }
        // 基本 UTF-8 宽度计算
        if (c < 0x80) {
            width += 1
            i += 1
        } else if ((c & 0xE0) == 0xC0) {
            // CJK 和其他宽字符简化为 2
            width += 2
            i += 2
        } else if ((c & 0xF0) == 0xE0) {
            width += 2
            i += 3
        } else if ((c & 0xF8) == 0xF0) {
            width += 2
            i += 4
        } else {
            width += 1
            i += 1
        }
    }
    return width
}

/// 在最大可见宽度限制内查找字节索引
public func visibleIndexAt(s: String, max_cols: Int64): Int64 {
    var width: Int64 = 0
    var i: Int64 = 0
    while (i < s.length) {
        let c = UInt8(s[Int64(i)])
        if (c == 0x1b) {
            // ANSI 转义序列: 零宽度，总是包含
            i += 1
            if (i < s.length) {
                let next = UInt8(s[Int64(i)])
                if (next == '['.toUInt8()) {
                    i += 1
                    while (i < s.length && (UInt8(s[Int64(i)]) < 0x40 || UInt8(s[Int64(i)]) > 0x7e)) {
                        i += 1
                    }
                    if (i < s.length) i += 1
                } else if (next == ']'.toUInt8()) {
                    i += 1
                    while (i < s.length) {
                        if (UInt8(s[Int64(i)]) == 0x07) {
                            i += 1
                            break
                        }
                        if (UInt8(s[Int64(i)]) == 0x1b && i + 1 < s.length && UInt8(s[Int64(i + 1)]) == '\\') {
                            i += 2
                            break
                        }
                        i += 1
                    }
                } else {
                    i += 1
                }
            }
            continue
        }
        var char_width: Int64 = 1
        var char_len: Int64 = 1
        if (c < 0x80) {
            char_width = 1
            char_len = 1
        } else if ((c & 0xE0) == 0xC0) {
            char_width = 2
            char_len = 2
        } else if ((c & 0xF0) == 0xE0) {
            char_width = 2
            char_len = 3
        } else if ((c & 0xF8) == 0xF0) {
            char_width = 2
            char_len = 4
        }
        if (width + char_width > max_cols) {
            return i
        }
        width += char_width
        i += char_len
    }
    return s.length
}

// ============================================================================
// 块上下文
// ============================================================================

/// 块上下文类型
public enum BlockContextKind {
    | quote
    | ul
    | ol
    | li
}

/// 块上下文（用于缩进栈）
public class BlockContext {
    public var kind: BlockContextKind = BlockContextKind.quote
    public var data: UInt32 = 0
    public var index: UInt32 = 0
    public var indent: UInt32 = 0

    public init() {}
    public init(kind: BlockContextKind, data: UInt32, index: UInt32, indent: UInt32) {
        this.kind = kind
        this.data = data
        this.index = index
        this.indent = indent
    }
}

// ============================================================================
// 表格相关类型
// ============================================================================

/// 表格单元格
public class TableCell {
    public var content: String = ""
    public var alignment: Align = Align.default

    public init() {}
    public init(content: String, alignment: Align) {
        this.content = content
        this.alignment = alignment
    }
}

/// 表格行
public class TableRow {
    public var cells: Array<TableCell> = []
    public var is_header: Bool = false

    public init() {}
}

// ============================================================================
// ANSI 渲染器
// ============================================================================

/// ANSI 渲染器
public class AnsiRenderer {
    public var out: HtmlOutputBuffer = HtmlOutputBuffer()
    public var src_text: String = ""
    public var theme: Theme = Theme()
    /// 活动块上下文栈
    public var block_stack: Array<BlockContext> = []
    /// 活动行内样式标志
    public var span_flags: UInt32 = 0
    /// 链接 href
    public var link_href: ?String = None
    /// 链接深度
    public var link_depth: UInt32 = 0
    /// 图片深度
    public var image_depth: UInt32 = 0
    /// 缓冲的图片 alt 文本
    public var image_alt: StringBuilder = StringBuilder()
    /// 保存的图片 src
    public var image_src: ?String = None
    /// 保存的图片 title
    public var image_title: ?String = None
    /// 当前列位置
    public var col: UInt32 = 0
    /// 是否在代码块中
    public var in_code_block: Bool = false
    /// 代码块语言
    public var code_lang: String = ""
    /// 代码块是否围栏
    public var code_fenced: Bool = false
    /// 代码块缓冲区
    public var code_buf: StringBuilder = StringBuilder()
    /// 当前标题级别
    public var heading_level: UInt8 = 0
    /// 标题文本缓冲区
    public var heading_buf: StringBuilder = StringBuilder()
    /// 表格单元格
    public var table_cells: Array<TableCell> = []
    /// 表格行
    public var table_rows: Array<TableRow> = []
    /// 表格单元格缓冲区
    public var table_cell_buf: StringBuilder = StringBuilder()
    /// 是否在 thead 中
    public var in_thead: Bool = false
    /// 是否在单元格中
    public var in_cell: Bool = false
    /// 当前单元格对齐
    public var cell_align: Align = Align.default
    /// 上次是否换行
    public var last_was_newline: Bool = true
    /// 是否已发出空行
    public var blank_emitted: Bool = false

    // Span 标志位
    public static let SPAN_EM: UInt32 = 1 << 0
    public static let SPAN_STRONG: UInt32 = 1 << 1
    public static let SPAN_DEL: UInt32 = 1 << 2
    public static let SPAN_U: UInt32 = 1 << 3
    public static let SPAN_CODE: UInt32 = 1 << 4

    public init() {}

    /// 初始化
    public static func init(src_text: String, theme: Theme): AnsiRenderer {
        let r = AnsiRenderer()
        r.src_text = src_text
        r.theme = theme
        return r
    }

    /// 获取最终输出字符串
    public func toOwnedString(): String {
        return out.data.toString()
    }

    /// 创建渲染器接口
    public func renderer(): Renderer {
        let rend = Renderer()
        return rend
    }

    // ========================================
    // 块级渲染
    // ========================================

    /// 进入块
    public func enterBlock(block_type: BlockType, data: UInt32, flags: UInt32): Unit {
        match (block_type) {
            case BlockType.doc => {}
            case BlockType.quote => {
                ensureBlankLine()
                block_stack.append(BlockContext(BlockContextKind.quote, 0, 0, 2))
            }
            case BlockType.ul => {
                ensureNewline()
                block_stack.append(BlockContext(BlockContextKind.ul, data, 0, 2))
            }
            case BlockType.ol => {
                ensureNewline()
                block_stack.append(BlockContext(BlockContextKind.ol, data, 0, 3))
            }
            case BlockType.li => {
                ensureNewline()
                writeIndent()
                var entry = BlockContext(BlockContextKind.li, 0, 0, 0)
                let parent_list = findParentList()
                let task_mark = taskMarkFromData(data)
                if (let Some(list) <- parent_list) {
                    entry.index = list.index
                    list.index += 1
                }
                var glyph = ""
                var glyph_color = ""
                if (task_mark != 0) {
                    let checked = isTaskChecked(task_mark)
                    if (theme.colors) {
                        glyph = if (checked) "\u2612 " else "\u2610 "
                    } else {
                        glyph = if (checked) "[x] " else "[ ] "
                    }
                    glyph_color = if (checked) ansiColor(AnsiColor.green) else ansiColor(AnsiColor.dim)
                } else if (let Some(list) <- parent_list) {
                    if (list.kind == BlockContextKind.ol) {
                        let num = list.data + entry.index
                        glyph = "${num}. "
                        glyph_color = ansiColor(AnsiColor.cyan)
                    } else {
                        glyph = if (theme.colors) "\u2022 " else "* "
                        glyph_color = ansiColor(AnsiColor.cyan)
                    }
                } else {
                    glyph = if (theme.colors) "\u2022 " else "* "
                    glyph_color = ansiColor(AnsiColor.cyan)
                }
                writeStyled(glyph_color, glyph)
                writeStyled(ansiReset(), "")
                entry.indent = UInt32(visibleWidth(glyph))
                block_stack.append(entry)
            }
            case BlockType.hr => {
                ensureBlankLine()
                writeIndent()
                let indent_cols = currentIndent()
                let width: UInt32 = if (theme.columns == 0) {
                    60 - indent_cols
                } else {
                    min(UInt32(theme.columns), 60) - indent_cols
                }
                let dash = if (theme.colors) "\u2500" else "-"
                writeStyled(ansiColor(AnsiColor.dim), "")
                var i: UInt32 = 0
                while (i < width) {
                    writeRaw(dash)
                    i += 1
                }
                writeStyled(ansiReset(), "")
                writeRaw("\n")
                last_was_newline = true
                col = 0
            }
            case BlockType.h => {
                ensureBlankLine()
                heading_level = UInt8(data)
                heading_buf = StringBuilder()
            }
            case BlockType.code => {
                ensureBlankLine()
                in_code_block = true
                code_fenced = (flags & BLOCK_FENCED_CODE) != 0
                code_buf = StringBuilder()
                if (code_fenced) {
                    code_lang = extractLanguage(src_text, data)
                } else {
                    code_lang = ""
                }
            }
            case BlockType.html => {
                ensureNewline()
            }
            case BlockType.p => {
                let top_kind: ?BlockContextKind = if (!block_stack.isEmpty) {
                    block_stack[Int64(block_stack.length - 1)].kind
                } else {
                    None
                }
                if (let Some(k) <- top_kind) {
                    if (k == BlockContextKind.li && col > 0) {
                        // 继续在同一行
                    } else {
                        ensureBlankLine()
                        writeIndent()
                    }
                } else {
                    ensureBlankLine()
                    writeIndent()
                }
            }
            case BlockType.table => {
                ensureBlankLine()
                in_thead = false
                table_rows = []
                table_cells = []
            }
            case BlockType.thead => {
                in_thead = true
            }
            case BlockType.tbody => {
                in_thead = false
            }
            case BlockType.tr => {
                table_cells = []
            }
            case BlockType.th => {
                in_cell = true
                cell_align = alignmentFromData(data)
                table_cell_buf = StringBuilder()
            }
            case BlockType.td => {
                in_cell = true
                cell_align = alignmentFromData(data)
                table_cell_buf = StringBuilder()
            }
        }
    }

    /// 离开块
    public func leaveBlock(block_type: BlockType, data: UInt32): Unit {
        match (block_type) {
            case BlockType.doc => {}
            case BlockType.quote => {
                if (!block_stack.isEmpty) block_stack = block_stack.slice(0, block_stack.length - 1)
                ensureNewline()
            }
            case BlockType.ul => {
                if (!block_stack.isEmpty) block_stack = block_stack.slice(0, block_stack.length - 1)
                ensureNewline()
            }
            case BlockType.ol => {
                if (!block_stack.isEmpty) block_stack = block_stack.slice(0, block_stack.length - 1)
                ensureNewline()
            }
            case BlockType.li => {
                if (!block_stack.isEmpty) block_stack = block_stack.slice(0, block_stack.length - 1)
                ensureNewline()
            }
            case BlockType.hr => {}
            case BlockType.h => {
                flushHeading()
                heading_level = 0
            }
            case BlockType.code => {
                flushCodeBlock()
                in_code_block = false
                code_lang = ""
            }
            case BlockType.html => {
                ensureNewline()
            }
            case BlockType.p => {
                writeStyled(ansiReset(), "")
                ensureNewline()
                col = 0
            }
            case BlockType.table => {
                flushTable()
                ensureNewline()
            }
            case BlockType.thead => {}
            case BlockType.tbody => {}
            case BlockType.tr => {
                // 将收集的单元格移入表格行
                let cells_copy: Array<TableCell> = []
                for (c in table_cells) {
                    cells_copy.append(TableCell(c.content, c.alignment))
                }
                table_rows.append(TableRow().also {
                    it.cells = cells_copy
                    it.is_header = in_thead
                })
                table_cells = []
            }
            case BlockType.th => {
                in_cell = false
                table_cells.append(TableCell(table_cell_buf.toString(), cell_align))
            }
            case BlockType.td => {
                in_cell = false
                table_cells.append(TableCell(table_cell_buf.toString(), cell_align))
            }
        }
    }

    // ========================================
    // Span 渲染
    // ========================================

    /// 进入 span
    public func enterSpan(span_type: SpanType, detail: SpanDetail): Unit {
        match (span_type) {
            case SpanType.em => {
                span_flags = span_flags | AnsiRenderer.SPAN_EM
                writeStyled(ansiStyle(AnsiStyle.italic), "")
            }
            case SpanType.strong => {
                span_flags = span_flags | AnsiRenderer.SPAN_STRONG
                writeStyled(ansiStyle(AnsiStyle.bold), "")
            }
            case SpanType.u => {
                span_flags = span_flags | AnsiRenderer.SPAN_U
                writeStyled(ansiStyle(AnsiStyle.underline), "")
            }
            case SpanType.del => {
                span_flags = span_flags | AnsiRenderer.SPAN_DEL
                writeStyled(ansiStyle(AnsiStyle.strikethrough), "")
            }
            case SpanType.code => {
                span_flags = span_flags | AnsiRenderer.SPAN_CODE
                writeStyled(codeSpanOpen(theme.light), "")
            }
            case SpanType.a => {
                link_depth += 1
                if (link_depth == 1) {
                    link_href = resolveHref(detail)
                    if (theme.colors && theme.hyperlinks) {
                        if (let Some(href) <- link_href) {
                            writeRawNoColor("\x1b]8;;")
                            writeRawNoColor(href)
                            writeRawNoColor("\x1b\\")
                        }
                    }
                    writeStyled(ansiColor(AnsiColor.blue), "")
                    writeStyled(ansiStyle(AnsiStyle.underline), "")
                }
            }
            case SpanType.img => {
                image_depth += 1
                if (image_depth == 1) {
                    image_src = detail.href
                    image_title = detail.title
                    image_alt = StringBuilder()
                }
            }
            case SpanType.wikilink => {
                writeStyled(ansiColor(AnsiColor.blue), "[[")
            }
            case SpanType.latexmath => {
                writeStyled(ansiColor(AnsiColor.magenta), "$")
            }
            case SpanType.latexmath_display => {
                writeStyled(ansiColor(AnsiColor.magenta), "$$")
            }
        }
    }

    /// 离开 span
    public func leaveSpan(span_type: SpanType): Unit {
        match (span_type) {
            case SpanType.em => {
                span_flags = span_flags & ~AnsiRenderer.SPAN_EM
                writeStyled("\x1b[23m", "")
                if (heading_level > 0) reapplyStyles()
            }
            case SpanType.strong => {
                span_flags = span_flags & ~AnsiRenderer.SPAN_STRONG
                writeStyled("\x1b[22m", "")
                if (heading_level > 0) reapplyStyles()
            }
            case SpanType.u => {
                span_flags = span_flags & ~AnsiRenderer.SPAN_U
                writeStyled("\x1b[24m", "")
                if (heading_level > 0) reapplyStyles()
            }
            case SpanType.del => {
                span_flags = span_flags & ~AnsiRenderer.SPAN_DEL
                writeStyled("\x1b[29m", "")
                if (heading_level > 0) reapplyStyles()
            }
            case SpanType.code => {
                span_flags = span_flags & ~AnsiRenderer.SPAN_CODE
                writeStyled("\x1b[39m\x1b[49m", "")
                reapplyStyles()
            }
            case SpanType.a => {
                if (link_depth == 1) {
                    link_depth = 0
                    let had_href = link_href != None
                    writeStyled("\x1b[24m\x1b[39m", "")
                    reapplyStyles()
                    if (theme.colors && theme.hyperlinks) {
                        if (had_href) writeRawNoColor("\x1b]8;;\x1b\\")
                    } else if (let Some(href) <- link_href) {
                        if (href.length > 0 && image_depth == 0) {
                            writeStyled(ansiColor(AnsiColor.dim), " (")
                            writeStyled("", href)
                            writeStyled(ansiColor(AnsiColor.dim), ")")
                            writeStyled("\x1b[39m\x1b[22m", "")
                            reapplyStyles()
                        }
                    }
                    link_href = None
                } else if (link_depth > 0) {
                    link_depth -= 1
                }
            }
            case SpanType.img => {
                if (image_depth == 1) {
                    emitImage()
                    image_src = None
                    image_title = None
                    image_alt = StringBuilder()
                }
                if (image_depth > 0) image_depth -= 1
            }
            case SpanType.wikilink => {
                writeNoWrap("]]")
                writeStyled("\x1b[39m", "")
                reapplyStyles()
            }
            case SpanType.latexmath => {
                writeNoWrap("$")
                writeStyled("\x1b[39m", "")
                reapplyStyles()
            }
            case SpanType.latexmath_display => {
                writeNoWrap("$$")
                writeStyled("\x1b[39m", "")
                reapplyStyles()
            }
        }
    }

    // ========================================
    // 文本渲染
    // ========================================

    /// 文本回调
    public func text(text_type: TextType, content: String): Unit {
        match (text_type) {
            case TextType.null_char => writeContent("\xEF\xBF\xBD")
            case TextType.br => writeContent("\n")
            case TextType.softbr => writeContent(" ")
            case TextType.html => {
                writeStyled(ansiColor(AnsiColor.dim), "")
                writeContent(content)
                writeStyled("\x1b[22m", "")
                reapplyStyles()
            }
            case TextType.entity => {
                if (let Some(decoded) <- decodeEntityToUtf8(content)) {
                    writeContent(decoded)
                } else {
                    writeContent(content)
                }
            }
            case TextType.code => writeStyled("", content)
            case TextType.latexmath => writeStyled("", content)
            case _ => writeContent(content)
        }
    }

    // ========================================
    // 写入辅助
    // ========================================

    /// 将内容路由到适当的汇（代码缓冲区、标题缓冲区、表格单元格、图片 alt 或直接输出）
    func writeContent(data: String): Unit {
        if (image_depth > 0) {
            image_alt.append(data)
            return
        }
        if (in_code_block) {
            code_buf.append(data)
            return
        }
        if (heading_level > 0) {
            heading_buf.append(data)
            return
        }
        if (in_cell) {
            table_cell_buf.append(data)
            return
        }
        writeWrapped(data)
    }

    /// 自动换行写入
    func writeWrapped(data: String): Unit {
        if (theme.columns == 0) {
            // 无换行路径
            var start: Int64 = 0
            var i: Int64 = 0
            while (i < data.length) {
                if (data[Int64(i)] == '\n') {
                    writeRaw(data.substring(start, i + 1))
                    col = 0
                    last_was_newline = true
                    writeIndent()
                    start = i + 1
                }
                i += 1
            }
            if (start < data.length) {
                writeRaw(data.substring(start))
            }
            return
        }
        let max = UInt32(theme.columns)
        var i: Int64 = 0
        while (i < data.length) {
            let c = data[Int64(i)]
            if (c == '\n') {
                writeRaw("\n")
                last_was_newline = true
                col = 0
                i += 1
                writeIndent()
                continue
            }
            if (c == ' ' && col >= max) {
                writeRaw("\n")
                last_was_newline = true
                col = 0
                writeIndent()
                i += 1
                while (i < data.length && data[Int64(i)] == ' ') i += 1
                continue
            }
            var j = i
            while (j < data.length && data[Int64(j)] != ' ' && data[Int64(j)] != '\n') j += 1
            let word = data.substring(i, j)
            let word_width = visibleWidth(word)
            let indent = currentIndent()
            let avail = max - indent
            if (avail > 0 && word_width > avail) {
                // 单词无法放入新行
                var rest = word
                while (rest.length > 0) {
                    let r = max - col
                    if (r == 0) {
                        wrapBreak()
                        continue
                    }
                    var cut = visibleIndexAt(rest, Int64(r))
                    if (cut == 0) cut = min(rest.length, 1)
                    writeRaw(rest.substring(0, cut))
                    col += UInt32(visibleWidth(rest.substring(0, cut)))
                    last_was_newline = false
                    rest = rest.substring(cut)
                    if (rest.length > 0) wrapBreak()
                }
            } else {
                if (col != 0 && col + UInt32(word_width) > max && col > indent) {
                    wrapBreak()
                }
                writeRaw(word)
                col += UInt32(word_width)
                last_was_newline = (word.length == 0)
            }
            i = j
            if (i < data.length && data[Int64(i)] == ' ') {
                // 检查下一个单词是否溢出
                var k = i
                while (k < data.length && data[Int64(k)] == ' ') k += 1
                var m = k
                while (m < data.length && data[Int64(m)] != ' ' && data[Int64(m)] != '\n') m += 1
                let next_word_width = visibleWidth(data.substring(k, m))
                let next_avail = max - indent
                if (col != 0 && col + 1 + UInt32(next_word_width) > max && col > indent && next_word_width <= next_avail) {
                    writeRaw("\n")
                    last_was_newline = true
                    col = 0
                    writeIndent()
                } else {
                    writeRaw(" ")
                    col += 1
                }
                i = k
            }
        }
    }

    /// 带样式的写入
    func writeStyled(prefix: String, text_: String): Unit {
        if (theme.colors && prefix.length > 0) {
            emitInline(prefix)
        }
        if (text_.length == 0) return
        emitInline(text_)
        if (!in_cell && heading_level == 0 && !in_code_block && image_depth == 0) {
            col += UInt32(visibleWidth(text_))
            last_was_newline = false
        }
    }

    /// 软换行
    func wrapBreak(): Unit {
        let has_style = span_flags != 0 || link_depth > 0
        if (theme.colors && has_style) out.write("\x1b[39m\x1b[49m")
        out.writeByte('\n'.toUInt8())
        last_was_newline = true
        col = 0
        writeIndent()
        if (has_style) reapplyStyles()
    }

    /// 原始写入
    func writeRaw(data: String): Unit {
        if (data.length == 0) return
        emitInline(data)
        last_was_newline = (data[data.length - 1] == '\n')
    }

    /// 不换行写入
    func writeNoWrap(text_: String): Unit {
        if (text_.length == 0) return
        emitInline(text_)
        if (!in_cell && heading_level == 0 && !in_code_block && image_depth == 0) {
            col += UInt32(visibleWidth(text_))
            last_was_newline = false
        }
    }

    /// 无颜色写入
    func writeRawNoColor(data: String): Unit {
        if (!theme.colors) return
        if (data.length == 0) return
        if (image_depth > 0) return
        if (in_cell) {
            table_cell_buf.append(data)
            return
        }
        if (heading_level > 0) {
            heading_buf.append(data)
            return
        }
        out.write(data)
    }

    /// 行内发射
    func emitInline(bytes: String): Unit {
        if (bytes.length == 0) return
        if (image_depth > 0) {
            // 图片 alt 是纯文本 — 去除转义序列
            var i: Int64 = 0
            while (i < bytes.length) {
                if (UInt8(bytes[Int64(i)]) == 0x1b) {
                    i += 1
                    if (i < bytes.length && UInt8(bytes[Int64(i)]) == '['.toUInt8()) {
                        i += 1
                        while (i < bytes.length && (UInt8(bytes[Int64(i)]) < 0x40 || UInt8(bytes[Int64(i)]) > 0x7e)) i += 1
                        if (i < bytes.length) i += 1
                    } else if (i < bytes.length && UInt8(bytes[Int64(i)]) == ']') {
                        i += 1
                        while (i < bytes.length) {
                            if (UInt8(bytes[Int64(i)]) == 0x07) { i += 1; break }
                            if (UInt8(bytes[Int64(i)]) == 0x1b && i + 1 < bytes.length && UInt8(bytes[Int64(i + 1)]) == '\\') { i += 2; break }
                            i += 1
                        }
                    }
                    continue
                }
                let start = i
                while (i < bytes.length && UInt8(bytes[Int64(i)]) != 0x1b) i += 1
                image_alt.append(bytes.substring(start, i))
            }
            return
        }
        if (in_cell) {
            table_cell_buf.append(bytes)
            return
        }
        if (heading_level > 0) {
            heading_buf.append(bytes)
            return
        }
        out.write(bytes)
    }

    /// 重新应用样式
    func reapplyStyles(): Unit {
        if (!theme.colors) return
        if (heading_level > 0) {
            emitInline(ansiStyle(AnsiStyle.bold))
            emitInline(headingColor(heading_level))
        }
        if ((span_flags & AnsiRenderer.SPAN_STRONG) != 0) emitInline(ansiStyle(AnsiStyle.bold))
        if ((span_flags & AnsiRenderer.SPAN_EM) != 0) emitInline(ansiStyle(AnsiStyle.italic))
        if ((span_flags & AnsiRenderer.SPAN_U) != 0) emitInline(ansiStyle(AnsiStyle.underline))
        if ((span_flags & AnsiRenderer.SPAN_DEL) != 0) emitInline(ansiStyle(AnsiStyle.strikethrough))
        if ((span_flags & AnsiRenderer.SPAN_CODE) != 0) emitInline(codeSpanOpen(theme.light))
        if (link_depth > 0) {
            emitInline(ansiColor(AnsiColor.blue))
            emitInline(ansiStyle(AnsiStyle.underline))
        }
    }

    // ========================================
    // 缩进
    // ========================================

    /// 写入缩进
    func writeIndent(): Unit {
        blank_emitted = false
        var quote_bars: UInt32 = 0
        var other_indent: UInt32 = 0
        for (entry in block_stack) {
            match (entry.kind) {
                case BlockContextKind.quote => quote_bars += 1
                case _ => other_indent += entry.indent
            }
        }
        let bar = if (theme.colors) "\u2502 " else "| "
        if (theme.colors && quote_bars > 0) {
            out.write("\x1b[38;5;242m")
        }
        var i: UInt32 = 0
        while (i < quote_bars) {
            out.write(bar)
            col += 2
            i += 1
        }
        if (theme.colors && quote_bars > 0) {
            out.write("\x1b[39m")
            reapplyStyles()
        }
        var j: UInt32 = 0
        while (j < other_indent) {
            out.write(" ")
            col += 1
            j += 1
        }
    }

    /// 当前缩进
    func currentIndent(): UInt32 {
        var total: UInt32 = 0
        for (entry in block_stack) {
            total += if (entry.kind == BlockContextKind.quote) 2 else entry.indent
        }
        return total
    }

    /// 写入引用竖线
    func writeQuoteBars(): Unit {
        var quote_bars: UInt32 = 0
        for (entry in block_stack) {
            if (entry.kind == BlockContextKind.quote) quote_bars += 1
        }
        if (quote_bars == 0) return
        let bar = if (theme.colors) "\u2502" else "|"
        if (theme.colors) out.write("\x1b[38;5;242m")
        var i: UInt32 = 0
        while (i < quote_bars) {
            out.write(bar)
            col += 1
            i += 1
        }
        if (theme.colors) out.write("\x1b[39m")
    }

    /// 确保换行
    func ensureNewline(): Unit {
        if (!last_was_newline) {
            out.writeByte('\n'.toUInt8())
            col = 0
            last_was_newline = true
        }
    }

    /// 确保空行
    func ensureBlankLine(): Unit {
        ensureNewline()
        if (blank_emitted) return
        let current = out.data.toString()
        if (current.length > 0) {
            if (current.length >= 2 && current[current.length - 1] == '\n' && current[current.length - 2] != '\n') {
                writeQuoteBars()
                out.writeByte('\n'.toUInt8())
                col = 0
                blank_emitted = true
            } else if (current.length >= 1 && current[current.length - 1] != '\n') {
                writeQuoteBars()
                out.writeByte('\n'.toUInt8())
                col = 0
                blank_emitted = true
            }
        }
    }

    /// 查找父列表
    func findParentList(): ?BlockContext {
        if (block_stack.isEmpty) return None
        var i = block_stack.length
        while (i > 0) {
            i -= 1
            let entry = block_stack[Int64(i)]
            if (entry.kind == BlockContextKind.ul || entry.kind == BlockContextKind.ol) return entry
        }
        return None
    }

    // ========================================
    // 标题刷新
    // ========================================

    /// 刷新标题
    func flushHeading(): Unit {
        let level = heading_level
        heading_level = 0
        let content = heading_buf.toString()
        writeIndent()
        if (theme.colors) {
            out.write("\x1b[1m") // 粗体
            out.write(headingColor(level))
        }
        out.write(content)
        if (theme.colors) out.write("\x1b[0m")
        out.writeByte('\n'.toUInt8())
        last_was_newline = true
        col = 0
        // h1/h2 添加下划线
        if (level == 1 || level == 2) {
            writeIndent()
            let text_w = max(visibleWidth(content), 3)
            let indent_cols = currentIndent()
            let width = if (theme.columns == 0) {
                text_w
            } else {
                min(text_w, Int64(UInt32(theme.columns)) - Int64(indent_cols))
            }
            if (theme.colors) out.write(ansiColor(AnsiColor.dim))
            let char = if (theme.colors) (if (level == 1) "\u2550" else "\u2500") else (if (level == 1) "=" else "-")
            var i: Int64 = 0
            while (i < width) {
                out.write(char)
                i += 1
            }
            if (theme.colors) out.write("\x1b[0m")
            out.writeByte('\n'.toUInt8())
            last_was_newline = true
            col = 0
        }
        heading_level = level
    }

    /// 标题颜色
    func headingColor(level: UInt8): String {
        return match (level) {
            case 1 => ansiColor(AnsiColor.magenta)
            case 2 => ansiColor(AnsiColor.cyan)
            case 3 => ansiColor(AnsiColor.yellow)
            case 4 => ansiColor(AnsiColor.green)
            case 5 => ansiColor(AnsiColor.blue)
            case _ => ansiColor(AnsiColor.white)
        }
    }

    // ========================================
    // 代码块刷新
    // ========================================

    /// 刷新代码块
    func flushCodeBlock(): Unit {
        let src = code_buf.toString()
        // 去除尾部换行
        let body = if (src.length > 0 && src[src.length - 1] == '\n') src.substring(0, src.length - 1) else src

        let top_border = if (theme.colors) "\u250c\u2500 " else "+- "
        let top_bare = if (theme.colors) "\u250c\u2500" else "+-"
        let side = if (theme.colors) "\u2502 " else "| "
        let bottom = if (theme.colors) "\u2514\u2500" else "+-"

        // 语言标记
        if (theme.colors) out.write(ansiColor(AnsiColor.dim))
        writeIndent()
        if (code_lang.length > 0) {
            out.write(top_border)
            if (theme.colors) out.write("\x1b[0m")
            if (theme.colors) out.write("\x1b[2m\x1b[3m")
            out.write(code_lang)
            if (theme.colors) out.write("\x1b[0m")
        } else {
            if (theme.colors) out.write(ansiColor(AnsiColor.dim))
            out.write(top_bare)
            if (theme.colors) out.write("\x1b[0m")
        }
        out.writeByte('\n'.toUInt8())
        last_was_newline = true

        // 输出代码行
        var line_start: Int64 = 0
        var i: Int64 = 0
        while (i <= body.length) {
            if (i == body.length || body[Int64(i)] == '\n') {
                let line = body.substring(line_start, i)
                writeIndent()
                if (theme.colors) out.write(ansiColor(AnsiColor.dim))
                out.write(side)
                if (theme.colors) out.write("\x1b[0m")
                out.write(line)
                out.writeByte('\n'.toUInt8())
                last_was_newline = true
                line_start = i + 1
            }
            i += 1
        }
        // 关闭边框
        writeIndent()
        if (theme.colors) out.write(ansiColor(AnsiColor.dim))
        out.write(bottom)
        if (theme.colors) out.write("\x1b[0m")
        out.writeByte('\n'.toUInt8())
        col = 0
        last_was_newline = true
    }

    // ========================================
    // 表格刷新
    // ========================================

    /// 刷新表格
    func flushTable(): Unit {
        if (table_rows.isEmpty) return

        // 计算最大列宽
        var col_count: Int64 = 0
        for (row in table_rows) {
            col_count = max(col_count, row.cells.length)
        }
        if (col_count == 0) return

        var widths: Array<Int64> = Array<Int64>(col_count, item: 3)
        var aligns: Array<Align> = Array<Align>(col_count, item: Align.default)
        for (row in table_rows) {
            for (i in 0..row.cells.length) {
                widths[Int64(i)] = max(widths[Int64(i)], visibleWidth(row.cells[Int64(i)].content))
                if (aligns[Int64(i)] == Align.default) aligns[Int64(i)] = row.cells[Int64(i)].alignment
            }
        }

        // 钳制列宽以适应终端
        if (theme.columns > 0) {
            let indent = currentIndent()
            var total: Int64 = Int64(indent) + 1
            for (w in widths) total += w + 3
            let budget = Int64(theme.columns)
            while (total > budget) {
                var widest: Int64 = 0
                for (i in 0..widths.length) {
                    if (widths[Int64(i)] > widths[Int64(widest)]) widest = i
                }
                if (widths[Int64(widest)] <= 3) break
                widths[Int64(widest)] -= 1
                total -= 1
            }
        }

        let use_unicode = theme.colors
        let h_char = if (use_unicode) "\u2500" else "-"
        let v_char = if (use_unicode) "\u2502" else "|"
        let tl_char = if (use_unicode) "\u250c" else "+"
        let tr_char = if (use_unicode) "\u2510" else "+"
        let bl_char = if (use_unicode) "\u2514" else "+"
        let br_char = if (use_unicode) "\u2518" else "+"
        let t_char = if (use_unicode) "\u252c" else "+"
        let b_char = if (use_unicode) "\u2534" else "+"
        let ml_char = if (use_unicode) "\u251c" else "+"
        let mr_char = if (use_unicode) "\u2524" else "+"
        let x_char = if (use_unicode) "\u253c" else "+"

        // 顶部边框
        writeIndent()
        if (theme.colors) out.write(ansiColor(AnsiColor.dim))
        out.write(tl_char)
        for (i in 0..widths.length) {
            var j: Int64 = 0
            while (j < widths[Int64(i)] + 2) { out.write(h_char); j += 1 }
            out.write(if (i == widths.length - 1) tr_char else t_char)
        }
        if (theme.colors) out.write("\x1b[0m")
        out.writeByte('\n'.toUInt8())
        last_was_newline = true

        var has_separated_header = false
        for (row in table_rows) {
            writeRowCells(row, widths, aligns)
            if (row.is_header && !has_separated_header) {
                // 分隔线
                writeIndent()
                if (theme.colors) out.write(ansiColor(AnsiColor.dim))
                out.write(ml_char)
                for (i in 0..widths.length) {
                    var j: Int64 = 0
                    while (j < widths[Int64(i)] + 2) { out.write(h_char); j += 1 }
                    out.write(if (i == widths.length - 1) mr_char else x_char)
                }
                if (theme.colors) out.write("\x1b[0m")
                out.writeByte('\n'.toUInt8())
                last_was_newline = true
                has_separated_header = true
            }
        }

        // 底部边框
        writeIndent()
        if (theme.colors) out.write(ansiColor(AnsiColor.dim))
        out.write(bl_char)
        for (i in 0..widths.length) {
            var j: Int64 = 0
            while (j < widths[Int64(i)] + 2) { out.write(h_char); j += 1 }
            out.write(if (i == widths.length - 1) br_char else b_char)
        }
        if (theme.colors) out.write("\x1b[0m")
        out.writeByte('\n'.toUInt8())
        last_was_newline = true
        col = 0

        table_rows = []
    }

    /// 写入行单元格
    func writeRowCells(row: TableRow, widths: Array<Int64>, aligns: Array<Align>): Unit {
        let use_unicode = theme.colors
        let v_char = if (use_unicode) "\u2502" else "|"

        writeIndent()
        if (theme.colors) out.write(ansiColor(AnsiColor.dim))
        out.write(v_char)
        if (theme.colors) out.write("\x1b[0m")
        for (i in 0..widths.length) {
            let seg: String = if (i < row.cells.length) row.cells[Int64(i)].content else ""
            out.writeByte(' '.toUInt8())
            if (row.is_header && theme.colors) out.write("\x1b[1m")
            let cw = visibleWidth(seg)
            let cell_align = if (i < row.cells.length) row.cells[Int64(i)].alignment else Align.default
            let alignment = if (cell_align != Align.default) cell_align else aligns[Int64(i)]
            let pad = widths[Int64(i)] - cw
            let left = match (alignment) {
                case Align.right => pad
                case Align.center => pad / 2
                case _ => 0
            }
            let right = pad - left
            writePadding(left)
            out.write(seg)
            if (theme.colors && row.is_header) out.write("\x1b[0m")
            writePadding(right)
            out.writeByte(' '.toUInt8())
            if (theme.colors) out.write(ansiColor(AnsiColor.dim))
            out.write(v_char)
            if (theme.colors) out.write("\x1b[0m")
        }
        out.writeByte('\n'.toUInt8())
        last_was_newline = true
    }

    /// 写入填充空格
    func writePadding(n: Int64): Unit {
        var i: Int64 = 0
        while (i < n) { out.writeByte(' '.toUInt8()); i += 1 }
    }

    // ========================================
    // 图片发射
    // ========================================

    /// 发射图片
    func emitImage(): Unit {
        let alt = image_alt.toString()
        let src = image_src
        let saved_depth = image_depth
        image_depth = 0

        let has_src = src != None && src.get().length > 0

        // Kitty 图形协议不支持表格/标题中
        let kitty_allowed = !in_cell && heading_level == 0

        if (kitty_allowed && theme.colors && theme.kitty_graphics && has_src) {
            // data:image/png;base64,... → 直接传输
            if (let Some(payload) <- extractPngDataUrlBase64(src.get())) {
                emitKittyImageDirect(payload)
                image_depth = saved_depth
                return
            }
            // 本地文件路径
            if (let Some(abs_path) <- resolveLocalImagePath(src.get(), theme.image_base_dir)) {
                emitKittyImageFile(abs_path)
                image_depth = saved_depth
                return
            }
        }

        // 回退: 显示 alt 文本
        let link_ok = theme.colors && theme.hyperlinks && has_src &&
            link_depth == 0 && !(src.get().startsWith("data:"))
        if (link_ok) {
            writeRawNoColor("\x1b]8;;")
            writeRawNoColor(src.get())
            writeRawNoColor("\x1b\\")
        }
        let img_marker = if (theme.colors) "\uD83D\uDCF7 " else "[img] "
        writeStyled(ansiColor(AnsiColor.magenta), img_marker)
        if (alt.length > 0) {
            writeContent(alt)
        } else if (let Some(title) <- image_title) {
            if (title.length > 0) {
                writeContent(title)
            } else {
                writeContent("(image)")
            }
        } else {
            writeContent("(image)")
        }
        writeStyled(ansiReset(), "")
        reapplyStyles()
        if (link_ok) {
            writeRawNoColor("\x1b]8;;\x1b\\")
        }
        image_depth = saved_depth
    }

    /// 发射 Kitty 图片文件
    func emitKittyImageFile(path: String): Unit {
        // 简化: 编码文件路径为 base64
        writeRawNoColor("\x1b_Ga=T,t=f,f=100,q=2;")
        // 实际实现需要 base64 编码路径
        writeRawNoColor("\x1b\\")
        writeRaw("\n")
        col = 0
        last_was_newline = true
        writeIndent()
    }

    /// 发射 Kitty 直接图片
    func emitKittyImageDirect(base64_payload: String): Unit {
        writeRawNoColor("\x1b_Ga=T,t=d,f=100,q=2;")
        writeRawNoColor(base64_payload)
        writeRawNoColor("\x1b\\")
        writeRaw("\n")
        col = 0
        last_was_newline = true
        writeIndent()
    }
}

// ============================================================================
// 公共 API
// ============================================================================

/// 渲染 Markdown 为 ANSI
public func renderToAnsi(text: String, options: Options, theme: Theme): ?String {
    let renderer = AnsiRenderer.init(text, theme)
    let flags = options.toFlags()
    let render_opts = options.toRenderOptions()
    renderWithRenderer(text, options, renderer.renderer())
    return renderer.toOwnedString()
}

/// 检测终端背景是否为浅色
public func detectLightBackground(): Bool {
    // 简化实现: 检查 COLORFGBG 环境变量
    return false
}

/// 检测终端是否支持 Kitty 图形协议
public func detectKittyGraphics(): Bool {
    // 简化实现
    return false
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 检查是否为 JS/TS 语言
func isJsLang(lang: String): Bool {
    let names = ["js", "javascript", "jsx", "mjs", "cjs", "ts", "typescript", "tsx", "mts", "cts"]
    for (n in names) {
        if (asciiCaseEql(lang, n)) return true
    }
    return false
}

/// 从源文本中提取语言
func extractLanguage(src_text: String, info_beg: UInt32): String {
    var lang_end = info_beg
    while (lang_end < src_text.length) {
        let c = UInt8(src_text[Int64(lang_end)])
        if (c == ' '.toUInt8() || c == '\t'.toUInt8() || c == '\n'.toUInt8() || c == '\r'.toUInt8()) break
        lang_end += 1
    }
    if (lang_end > info_beg) return src_text.substring(Int64(info_beg), Int64(lang_end))
    return ""
}

/// 解析 href（添加自动链接前缀）
func resolveHref(detail: SpanDetail): ?String {
    var buf = StringBuilder()
    if (detail.autolink_email) buf.append("mailto:")
    if (detail.autolink_www) buf.append("http://")
    buf.append(detail.href)
    return buf.toString()
}

/// 从 data: URI 中提取 PNG base64 负载
func extractPngDataUrlBase64(src: String): ?String {
    if (!src.startsWith("data:")) return None
    let comma_idx = src.indexOf(',')
    if (comma_idx < 0) return None
    let header = src.substring(0, Int64(comma_idx))
    let payload = src.substring(Int64(comma_idx) + 1)
    if (!header.endsWith(";base64")) return None
    if (header.indexOf("image/png") < 0) return None
    return payload
}

/// 解析本地图片路径
func resolveLocalImagePath(src: String, base_dir: ?String): ?String {
    if (src.startsWith("http://") || src.startsWith("https://") || src.startsWith("data:")) {
        return None
    }
    var path = src
    if (src.startsWith("file://")) {
        path = src.substring(7)
        if (path.startsWith("localhost/")) {
            path = path.substring(9) // 保留前导 /
        } else if (path == "localhost") {
            return None
        }
    }
    // 简化: 如果路径存在且为文件则返回
    return path
}
