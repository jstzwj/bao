// 严格翻译自: src/md/html_renderer.zig
// HTML 渲染器 — 将 Markdown 转换为 HTML
package bao_md

// ============================================================================
// HTML 渲染器
// ============================================================================

/// HTML 渲染器
public class HtmlRenderer {
    public var out: StringBuilder = StringBuilder()
    public var src_text: String = ""
    public var image_nesting_level: UInt32 = 0
    public var saved_img_title: String = ""
    public var tag_filter: Bool = false
    public var tag_filter_raw_depth: UInt32 = 0
    public var autolink_headings: Bool = false
    public var heading_buf: StringBuilder = StringBuilder()
    public var heading_tracker: HeadingIdTracker = HeadingIdTracker()
    public var in_heading: Bool = false
    public var oom: Bool = false

    public init() {}

    public init(srcText: String, renderOpts: RenderOptions) {
        this.src_text = srcText
        this.tag_filter = renderOpts.tag_filter
        this.autolink_headings = renderOpts.autolink_headings
        this.heading_tracker = HeadingIdTracker(renderOpts.heading_ids)
    }

    /// 获取渲染器接口
    public func renderer(): Renderer {
        let rend = Renderer()
        rend.html_renderer = this
        return rend
    }

    /// 获取最终字符串
    public func toOwnedString(): String {
        if (oom) {
            return ""
        }
        return out.toString()
    }

    // ========================================
    // 块级渲染
    // ========================================

    /// 进入块
    public func enterBlock(blockType: BlockType, data: UInt32, flags: UInt32): Unit {
        match (blockType) {
            case BlockType.doc => ()
            case BlockType.`quote` => {
                ensureNewline()
                write("<blockquote>\n")
            }
            case BlockType.ul => {
                ensureNewline()
                write("<ul>\n")
            }
            case BlockType.ol => {
                ensureNewline()
                if (data == 1) {
                    write("<ol>\n")
                } else {
                    write("<ol start=\"")
                    writeDecimal(data)
                    write("\">\n")
                }
            }
            case BlockType.li => {
                let taskMark = taskMarkFromData(data)
                if (taskMark != 0) {
                    write("<li class=\"task-list-item\">")
                    if (isTaskChecked(taskMark)) {
                        write("<input type=\"checkbox\" class=\"task-list-item-checkbox\" disabled checked>")
                    } else {
                        write("<input type=\"checkbox\" class=\"task-list-item-checkbox\" disabled>")
                    }
                } else {
                    write("<li>")
                }
            }
            case BlockType.hr => {
                ensureNewline()
                write("<hr />\n")
            }
            case BlockType.h => {
                ensureNewline()
                if (heading_tracker.enabled) {
                    heading_tracker.enterHeading()
                    in_heading = true
                } else {
                    let tag = match (data) {
                        case 1 => "<h1>"
                        case 2 => "<h2>"
                        case 3 => "<h3>"
                        case 4 => "<h4>"
                        case 5 => "<h5>"
                        case _ => "<h6>"
                    }
                    write(tag)
                }
            }
            case BlockType.code => {
                ensureNewline()
                write("<pre><code")
                if ((flags & BLOCK_FENCED_CODE) != 0) {
                    let infoBeg = data
                    // 找到语言标记的结束位置（信息字符串的第一个单词）
                    var langEnd: Int64 = infoBeg
                    while (langEnd < src_text.size && !isBlank(UInt8(src_text[Int64(langEnd)])) && !isNewline(UInt8(src_text[Int64(langEnd)]))) {
                        langEnd += 1
                    }
                    if (langEnd > infoBeg) {
                        write(" class=\"language-")
                        writeWithEntityDecoding(src_text.substring(infoBeg, langEnd))
                        write("\"")
                    }
                }
                write(">")
            }
            case BlockType.html => ensureNewline()
            case BlockType.p => {
                ensureNewline()
                write("<p>")
            }
            case BlockType.table => {
                ensureNewline()
                write("<table>\n")
            }
            case BlockType.thead => write("<thead>\n")
            case BlockType.tbody => write("<tbody>\n")
            case BlockType.tr => write("<tr>")
            case BlockType.th => {
                write("<th")
                let alignName = alignmentName(alignmentFromData(data))
                if (alignName != None) {
                    write(" align=\"")
                    write(alignName.get())
                    write("\"")
                }
                write(">")
            }
            case BlockType.td => {
                write("<td")
                let alignName = alignmentName(alignmentFromData(data))
                if (alignName != None) {
                    write(" align=\"")
                    write(alignName.get())
                    write("\"")
                }
                write(">")
            }
        }
    }

    /// 离开块
    public func leaveBlock(blockType: BlockType, data: UInt32): Unit {
        match (blockType) {
            case BlockType.doc => ()
            case BlockType.`quote` => write("</blockquote>\n")
            case BlockType.ul => write("</ul>\n")
            case BlockType.ol => write("</ol>\n")
            case BlockType.li => write("</li>\n")
            case BlockType.hr => ()
            case BlockType.h => {
                if (heading_tracker.enabled && in_heading) {
                    let slug = heading_tracker.leaveHeading()
                    if (slug.size > 0) {
                        // 写入带 id 的开始标签
                        let openTag = match (data) {
                            case 1 => "<h1"
                            case 2 => "<h2"
                            case 3 => "<h3"
                            case 4 => "<h4"
                            case 5 => "<h5"
                            case _ => "<h6"
                        }
                        out.write(openTag)
                        out.write(" id=\"")
                        out.write(slug)
                        out.write("\">")
                        if (autolink_headings) {
                            out.write("<a href=\"#")
                            out.write(slug)
                            out.write("\">")
                        }
                        // 刷新缓冲的标题内容
                        out.write(heading_buf.toString())
                        if (autolink_headings) {
                            out.write("</a>")
                        }
                        let closeTag = match (data) {
                            case 1 => "</h1>\n"
                            case 2 => "</h2>\n"
                            case 3 => "</h3>\n"
                            case 4 => "</h4>\n"
                            case 5 => "</h5>\n"
                            case _ => "</h6>\n"
                        }
                        out.write(closeTag)
                        heading_buf = StringBuilder()
                        heading_tracker.clearAfterHeading()
                    } else {
                        let tag = match (data) {
                            case 1 => "</h1>\n"
                            case 2 => "</h2>\n"
                            case 3 => "</h3>\n"
                            case 4 => "</h4>\n"
                            case 5 => "</h5>\n"
                            case _ => "</h6>\n"
                        }
                        write(tag)
                    }
                } else {
                    let tag = match (data) {
                        case 1 => "</h1>\n"
                        case 2 => "</h2>\n"
                        case 3 => "</h3>\n"
                        case 4 => "</h4>\n"
                        case 5 => "</h5>\n"
                        case _ => "</h6>\n"
                    }
                    write(tag)
                }
                in_heading = false
            }
            case BlockType.code => write("</code></pre>\n")
            case BlockType.html => ()
            case BlockType.p => write("</p>\n")
            case BlockType.table => write("</table>\n")
            case BlockType.thead => write("</thead>\n")
            case BlockType.tbody => write("</tbody>\n")
            case BlockType.tr => write("</tr>\n")
            case BlockType.th => write("</th>")
            case BlockType.td => write("</td>")
        }
    }

    // ========================================
    // 行内渲染
    // ========================================

    /// 进入行内元素
    public func enterSpan(spanType: SpanType, detail: SpanDetail): Unit {
        if (image_nesting_level > 0) {
            if (spanType == SpanType.img) {
                image_nesting_level += 1
            }
            return
        }

        match (spanType) {
            case SpanType.em => write("<em>")
            case SpanType.strong => write("<strong>")
            case SpanType.u => write("<u>")
            case SpanType.code => write("<code>")
            case SpanType.del => write("<del>")
            case SpanType.latexmath => write("<x-equation>")
            case SpanType.latexmath_display => write("<x-equation type=\"display\">")
            case SpanType.a => {
                write("<a href=\"")
                if (detail.permissive_autolink) {
                    // 宽松自动链接使用 HTML 转义
                    if (detail.autolink_email) {
                        write("mailto:")
                    }
                    if (detail.autolink_www) {
                        write("http://")
                    }
                    writeHtmlEscaped(detail.href)
                } else if (detail.autolink) {
                    // 标准自动链接: 仅百分号编码
                    if (detail.autolink_email) {
                        write("mailto:")
                    }
                    writeUrlEscaped(detail.href)
                } else {
                    // 普通链接: 完整实体/转义处理
                    if (detail.autolink_email) {
                        write("mailto:")
                    }
                    writeUrlWithEscapes(detail.href)
                }
                write("\"")
                if (detail.title.size > 0) {
                    write(" title=\"")
                    writeTitleWithEscapes(detail.title)
                    write("\"")
                }
                write(">")
            }
            case SpanType.img => {
                saved_img_title = detail.title
                write("<img src=\"")
                writeUrlWithEscapes(detail.href)
                write("\" alt=\"")
                image_nesting_level += 1
            }
            case SpanType.wikilink => {
                write("<x-wikilink data-target=\"")
                writeHtmlEscaped(detail.href)
                write("\">")
            }
        }
    }

    /// 离开行内元素
    public func leaveSpan(spanType: SpanType): Unit {
        if (image_nesting_level > 0) {
            if (spanType == SpanType.img) {
                image_nesting_level -= 1
                if (image_nesting_level == 0) {
                    write("\"")
                    if (saved_img_title.size > 0) {
                        write(" title=\"")
                        writeTitleWithEscapes(saved_img_title)
                        write("\"")
                    }
                    write(" />")
                    saved_img_title = ""
                }
            }
            return
        }

        match (spanType) {
            case SpanType.em => write("</em>")
            case SpanType.strong => write("</strong>")
            case SpanType.u => write("</u>")
            case SpanType.a => write("</a>")
            case SpanType.code => write("</code>")
            case SpanType.del => write("</del>")
            case SpanType.latexmath => write("</x-equation>")
            case SpanType.latexmath_display => write("</x-equation>")
            case SpanType.wikilink => write("</x-wikilink>")
            case SpanType.img => () // 在上方处理
        }
    }

    // ========================================
    // 文本渲染
    // ========================================

    /// 渲染文本
    public func text(textType: TextType, content: String): Unit {
        let inImage = image_nesting_level > 0

        // 为 slug 生成跟踪纯文本
        heading_tracker.trackText(textType, content)

        match (textType) {
            case TextType.null_char => write("\u{EF}\u{BF}\u{BD}")
            case TextType.br => {
                if (inImage) {
                    write(" ")
                } else {
                    write("<br />\n")
                }
            }
            case TextType.softbr => {
                if (inImage) {
                    write(" ")
                } else {
                    write("\n")
                }
            }
            case TextType.html => {
                if (tag_filter) {
                    updateTagFilterRawDepth(content)
                    writeHtmlWithTagFilter(content)
                } else {
                    write(content)
                }
            }
            case TextType.entity => writeEntity(content)
            case TextType.code => {
                // 在代码跨度中，换行符变成空格
                var start: Int64 = 0
                for (j in 0..content.size) {
                    if (content[j] == '\n') {
                        if (j > start) {
                            writeHtmlEscaped(content.substring(start, j))
                        }
                        write(" ")
                        start = j + 1
                    }
                }
                if (start < content.size) {
                    writeHtmlEscaped(content.substring(start))
                }
            }
            case _ => {
                // 在标签过滤的禁用标签内，以原始文本发出
                if (tag_filter && tag_filter_raw_depth > 0) {
                    write(content)
                } else {
                    writeHtmlEscaped(content)
                }
            }
        }
    }

    // ========================================
    // HTML 写入工具
    // ========================================

    /// 写入数据（考虑标题缓冲）
    public func write(data: String): Unit {
        if (in_heading) {
            heading_buf.append(data)
        } else {
            out.append(data)
        }
    }

    /// 确保换行
    func ensureNewline(): Unit {
        if (in_heading) {
            if (heading_buf.size > 0 && heading_buf.toString()[heading_buf.size - 1] != '\n') {
                heading_buf.append('\n')
            }
        } else {
            let s = out.toString()
            if (s.size > 0 && s[s.size - 1] != '\n') {
                out.append('\n')
            }
        }
    }

    /// HTML 转义写入
    public func writeHtmlEscaped(txt: String): Unit {
        var i: Int64 = 0
        while (i < txt.size) {
            let c = txt[i]
            match (c) {
                case '&' => write("&amp;")
                case '<' => write("&lt;")
                case '>' => write("&gt;")
                case '"' => write("&quot;")
                case _ => {
                    // 直接写入
                    let start = i
                    while (i < txt.size && txt[i] != '&' && txt[i] != '<' && txt[i] != '>' && txt[i] != '"') {
                        i += 1
                    }
                    if (i > start) {
                        write(txt.substring(start, i))
                    }
                    continue
                }
            }
            i += 1
        }
    }

    /// URL 转义写入
    func writeUrlEscaped(txt: String): Unit {
        for (i in 0..txt.size) {
            writeUrlByte(UInt8(txt[i]))
        }
    }

    /// URL 字节写入
    func writeUrlByte(byte: UInt8): Unit {
        match (byte) {
            case '&'.toUInt8() => write("&amp;")
            case '\''.toUInt8() => write("&#x27;")
            case 'A'.toUInt8(), 'B'.toUInt8(), 'C'.toUInt8(), 'D'.toUInt8(), 'E'.toUInt8(), 'F'.toUInt8(),
                 'G'.toUInt8(), 'H'.toUInt8(), 'I'.toUInt8(), 'J'.toUInt8(), 'K'.toUInt8(), 'L'.toUInt8(),
                 'M'.toUInt8(), 'N'.toUInt8(), 'O'.toUInt8(), 'P'.toUInt8(), 'Q'.toUInt8(), 'R'.toUInt8(),
                 'S'.toUInt8(), 'T'.toUInt8(), 'U'.toUInt8(), 'V'.toUInt8(), 'W'.toUInt8(), 'X'.toUInt8(),
                 'Y'.toUInt8(), 'Z'.toUInt8() => write(String.fromUInt8(byte))
            case 'a'.toUInt8(), 'b'.toUInt8(), 'c'.toUInt8(), 'd'.toUInt8(), 'e'.toUInt8(), 'f'.toUInt8(),
                 'g'.toUInt8(), 'h'.toUInt8(), 'i'.toUInt8(), 'j'.toUInt8(), 'k'.toUInt8(), 'l'.toUInt8(),
                 'm'.toUInt8(), 'n'.toUInt8(), 'o'.toUInt8(), 'p'.toUInt8(), 'q'.toUInt8(), 'r'.toUInt8(),
                 's'.toUInt8(), 't'.toUInt8(), 'u'.toUInt8(), 'v'.toUInt8(), 'w'.toUInt8(), 'x'.toUInt8(),
                 'y'.toUInt8(), 'z'.toUInt8() => write(String.fromUInt8(byte))
            case '0'.toUInt8(), '1'.toUInt8(), '2'.toUInt8(), '3'.toUInt8(), '4'.toUInt8(),
                 '5'.toUInt8(), '6'.toUInt8(), '7'.toUInt8(), '8'.toUInt8(), '9'.toUInt8() => write(String.fromUInt8(byte))
            case '-'.toUInt8(), '.'.toUInt8(), '_'.toUInt8(), '~'.toUInt8(),
                 ':'.toUInt8(), '/'.toUInt8(), '?'.toUInt8(), '#'.toUInt8(), '@'.toUInt8(),
                 '!'.toUInt8(), '$'.toUInt8(), '('.toUInt8(), ')'.toUInt8(), '*'.toUInt8(),
                 '+'.toUInt8(), ','.toUInt8(), ';'.toUInt8(), '='.toUInt8(), '%'.toUInt8() => write(String.fromUInt8(byte))
            case _ => {
                // 百分号编码
                write("%")
                write(String.fromUInt8(hexDigit(UInt8(byte >> 4))))
                write(String.fromUInt8(hexDigit(byte & 0x0F)))
            }
        }
    }

    /// URL 带转义写入
    func writeUrlWithEscapes(txt: String): Unit {
        var i: Int64 = 0
        while (i < txt.size) {
            if (txt[i] == '\\' && i + 1 < txt.size && isAsciiPunctuation(UInt8(txt[i + 1]))) {
                writeUrlByte(UInt8(txt[i + 1]))
                i += 2
            } else if (txt[i] == '&') {
                let endPos = findEntity(txt, i)
                if (endPos != None) {
                    writeEntityToUrl(txt.substring(i, endPos.get()))
                    i = endPos.get()
                } else {
                    write("&amp;")
                    i += 1
                }
            } else {
                writeUrlByte(UInt8(txt[i]))
                i += 1
            }
        }
    }

    /// 标题带转义写入
    func writeTitleWithEscapes(txt: String): Unit {
        var i: Int64 = 0
        while (i < txt.size) {
            if (txt[i] == '\\' && i + 1 < txt.size && isAsciiPunctuation(UInt8(txt[i + 1]))) {
                writeHtmlEscaped(txt.substring(i + 1, i + 2))
                i += 2
            } else if (txt[i] == '&') {
                let endPos = findEntity(txt, i)
                if (endPos != None) {
                    writeEntity(txt.substring(i, endPos.get()))
                    i = endPos.get()
                } else {
                    write("&amp;")
                    i += 1
                }
            } else {
                writeHtmlEscaped(txt.substring(i, i + 1))
                i += 1
            }
        }
    }

    /// 带实体解码的写入
    func writeWithEntityDecoding(txt: String): Unit {
        var i: Int64 = 0
        while (i < txt.size) {
            if (txt[i] == '&') {
                let endPos = findEntity(txt, i)
                if (endPos != None) {
                    writeEntity(txt.substring(i, endPos.get()))
                    i = endPos.get()
                    continue
                }
            } else if (txt[i] == '\\' && i + 1 < txt.size && isAsciiPunctuation(UInt8(txt[i + 1]))) {
                writeHtmlEscaped(txt.substring(i + 1, i + 2))
                i += 2
                continue
            }
            writeHtmlEscaped(txt.substring(i, i + 1))
            i += 1
        }
    }

    /// 写入实体
    func writeEntity(entityText: String): Unit {
        let decoded = decodeEntityToUtf8(entityText)
        if (decoded.size > 0) {
            writeHtmlEscaped(decoded)
        } else {
            write(entityText)
        }
    }

    /// 将实体解码为 URL 字节
    func writeEntityToUrl(entityText: String): Unit {
        let decoded = decodeEntityToUtf8(entityText)
        if (decoded.size > 0) {
            for (i in 0..decoded.size) {
                writeUrlByte(UInt8(decoded[i]))
            }
        } else {
            writeUrlEscaped(entityText)
        }
    }

    /// 写入十进制数
    func writeDecimal(value: UInt32): Unit {
        if (value == 0) {
            write("0")
            return
        }
        var v = value
        var buf: Array<UInt8> = []
        while (v > 0) {
            buf.append(UInt8('0'.toInt()) + UInt8(v % 10))
            v /= 10
        }
        // 反向写入
        var i = buf.size - 1
        while (i >= 0) {
            write(String.fromUInt8(buf[Int64(i)]))
            i -= 1
        }
    }

    // ========================================
    // 标签过滤
    // ========================================

    /// 更新标签过滤原始区域深度
    func updateTagFilterRawDepth(content: String): Unit {
        if (content.size < 2 || content[0] != '<') {
            return
        }
        if (content[1] == '/') {
            // 关闭标签
            if (isDisallowedTag(content) && tag_filter_raw_depth > 0) {
                tag_filter_raw_depth -= 1
            }
        } else {
            // 打开标签（非自关闭）
            if (isDisallowedTag(content)) {
                if (content.size < 2 || !(content[content.size - 2] == '/' && content[content.size - 1] == '>')) {
                    tag_filter_raw_depth += 1
                }
            }
        }
    }

    /// 带标签过滤的 HTML 写入
    func writeHtmlWithTagFilter(content: String): Unit {
        var start: Int64 = 0
        var i: Int64 = 0
        while (i < content.size) {
            if (content[i] == '<' && isDisallowedTag(content.substring(i))) {
                if (i > start) {
                    write(content.substring(start, i))
                }
                write("&lt;")
                start = i + 1
            }
            i += 1
        }
        if (start < content.size) {
            write(content.substring(start))
        }
    }

    /// 检查是否为禁用标签
    func isDisallowedTag(content: String): Bool {
        if (content.size < 2 || content[0] != '<') {
            return false
        }
        let afterLt: Int64 = if (content[1] == '/') { 2 } else { 1 }
        if (afterLt >= content.size) {
            return false
        }

        let disallowed: Array<String> = [
            "title", "textarea", "style", "xmp", "iframe",
            "noembed", "noframes", "script", "plaintext"
        ]
        for (tag in disallowed) {
            if (matchTagNameCI(content, afterLt, tag)) {
                return true
            }
        }
        return false
    }

    /// 大小写不敏感的标签名匹配
    func matchTagNameCI(content: String, pos: Int64, tag: String): Bool {
        if (pos + tag.size > content.size) {
            return false
        }
        if (!asciiCaseEql(content.substring(pos, pos + tag.size), tag)) {
            return false
        }
        let end = pos + tag.size
        if (end >= content.size) {
            return true
        }
        let c = content[end]
        return c == '>' || c == ' ' || c == '\t' || c == '\n' || c == '/'
    }

    // ========================================
    // 静态辅助
    // ========================================

    /// 十六进制数字
    func hexDigit(v: UInt8): UInt8 {
        return if (v < 10) { UInt8('0'.toInt()) + v } else { UInt8('A'.toInt()) + v - 10 }
    }
}
