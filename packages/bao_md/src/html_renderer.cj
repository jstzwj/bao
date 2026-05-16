// HTML renderer - translates Markdown to HTML
// Translated from: src/md/html_renderer.zig
package bao_md

import std.collection.*

// ============================================================================
// HTML Renderer
// ============================================================================

public class HtmlRenderer {
    public var out: StringBuilder = StringBuilder()
    public var src_text: String = ""
    public var image_nesting_level: UInt32 = 0
    public var saved_img_title: String = ""
    public var tag_filter: Bool = false
    public var tag_filter_raw_depth: UInt32 = 0
    public var autolink_headings: Bool = false
    public var heading_buf: StringBuilder = StringBuilder()
    public var heading_tracker: HeadingIdTracker = HeadingIdTracker(false)
    public var in_heading: Bool = false
    public var oom: Bool = false

    public init() {}

    public init(srcText: String, renderOpts: RenderOptions) {
        this.src_text = srcText
        this.tag_filter = renderOpts.tag_filter
        this.autolink_headings = renderOpts.autolink_headings
        this.heading_tracker = HeadingIdTracker(renderOpts.heading_ids)
    }

    public func renderer(): Renderer {
        let rend = Renderer()
        rend.html_renderer = this
        return rend
    }

    public func toOwnedString(): String {
        if (oom) {
            return ""
        }
        return out.toString()
    }

    // ========================================
    // Block rendering
    // ========================================

    public func enterBlock(blockType: BlockType, data: UInt32, flags: UInt32): Unit {
        match (blockType) {
            case BlockType.block_none => ()
            case BlockType.doc => ()
            case BlockType.`quote` =>
                ensureNewline()
                write("<blockquote>\n")
            case BlockType.ul =>
                ensureNewline()
                write("<ul>\n")
            case BlockType.ol =>
                ensureNewline()
                if (data == 1) {
                    write("<ol>\n")
                } else {
                    write("<ol start=\"")
                    writeDecimal(data)
                    write("\">\n")
                }
            case BlockType.li =>
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
            case BlockType.hr =>
                ensureNewline()
                write("<hr />\n")
            case BlockType.h =>
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
            case BlockType.code =>
                ensureNewline()
                write("<pre><code")
                if ((flags & BLOCK_FENCED_CODE) != 0) {
                    let infoBeg = Int64(data)
                    var langEnd: Int64 = infoBeg
                    while (langEnd < src_text.size && !isBlank(UInt8(src_text[langEnd])) && !isNewline(UInt8(src_text[langEnd]))) {
                        langEnd += 1
                    }
                    if (langEnd > infoBeg) {
                        write(" class=\"language-")
                        writeWithEntityDecoding(src_text[infoBeg..langEnd])
                        write("\"")
                    }
                }
                write(">")
            case BlockType.html => ensureNewline()
            case BlockType.p =>
                ensureNewline()
                write("<p>")
            case BlockType.table =>
                ensureNewline()
                write("<table>\n")
            case BlockType.thead => write("<thead>\n")
            case BlockType.tbody => write("<tbody>\n")
            case BlockType.tr => write("<tr>")
            case BlockType.th =>
                write("<th")
                let alignName = alignmentName(alignmentFromData(data))
                if (let Some(an) <- alignName) {
                    write(" align=\"")
                    write(an)
                    write("\"")
                }
                write(">")
            case BlockType.td =>
                write("<td")
                let alignName2 = alignmentName(alignmentFromData(data))
                if (let Some(an2) <- alignName2) {
                    write(" align=\"")
                    write(an2)
                    write("\"")
                }
                write(">")
        }
    }

    public func leaveBlock(blockType: BlockType, data: UInt32): Unit {
        match (blockType) {
            case BlockType.block_none => ()
            case BlockType.doc => ()
            case BlockType.`quote` => write("</blockquote>\n")
            case BlockType.ul => write("</ul>\n")
            case BlockType.ol => write("</ol>\n")
            case BlockType.li => write("</li>\n")
            case BlockType.hr => ()
            case BlockType.h =>
                if (heading_tracker.enabled && in_heading) {
                    let slugOpt = heading_tracker.leaveHeading()
                    if (let Some(slug) <- slugOpt) {
                        if (slug.size > 0) {
                            let openTag = match (data) {
                                case 1 => "<h1"
                                case 2 => "<h2"
                                case 3 => "<h3"
                                case 4 => "<h4"
                                case 5 => "<h5"
                                case _ => "<h6"
                            }
                            out.append(openTag)
                            out.append(" id=\"")
                            out.append(slug)
                            out.append("\">")
                            if (autolink_headings) {
                                out.append("<a href=\"#")
                                out.append(slug)
                                out.append("\">")
                            }
                            out.append(heading_buf.toString())
                            if (autolink_headings) {
                                out.append("</a>")
                            }
                            let closeTag = match (data) {
                                case 1 => "</h1>\n"
                                case 2 => "</h2>\n"
                                case 3 => "</h3>\n"
                                case 4 => "</h4>\n"
                                case 5 => "</h5>\n"
                                case _ => "</h6>\n"
                            }
                            out.append(closeTag)
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
    // Inline rendering
    // ========================================

    public func enterSpan(spanType: SpanType, detail: SpanDetail): Unit {
        if (image_nesting_level > 0) {
            match (spanType) {
                case SpanType.img =>
                    image_nesting_level += 1
                case _ => ()
            }
            return
        }

        match (spanType) {
            case SpanType.span_none => ()
            case SpanType.em => write("<em>")
            case SpanType.strong => write("<strong>")
            case SpanType.u => write("<u>")
            case SpanType.code => write("<code>")
            case SpanType.del => write("<del>")
            case SpanType.latexmath => write("<x-equation>")
            case SpanType.a =>
                write("<a href=\"")
                if (detail.permissive_autolink) {
                    if (detail.autolink_email) {
                        write("mailto:")
                    }
                    if (detail.autolink_www) {
                        write("http://")
                    }
                    writeHtmlEscaped(detail.href)
                } else if (detail.autolink) {
                    if (detail.autolink_email) {
                        write("mailto:")
                    }
                    writeUrlEscaped(detail.href)
                } else {
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
            case SpanType.img =>
                saved_img_title = detail.title
                write("<img src=\"")
                writeUrlWithEscapes(detail.href)
                write("\" alt=\"")
                image_nesting_level += 1
            case SpanType.wikilink =>
                write("<x-wikilink data-target=\"")
                writeHtmlEscaped(detail.href)
                write("\">")
            case SpanType.`default` => ()
            case SpanType.html => ()
        }
    }

    public func leaveSpan(spanType: SpanType): Unit {
        if (image_nesting_level > 0) {
            match (spanType) {
                case SpanType.img =>
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
                case _ => ()
            }
            return
        }

        match (spanType) {
            case SpanType.span_none => ()
            case SpanType.em => write("</em>")
            case SpanType.strong => write("</strong>")
            case SpanType.u => write("</u>")
            case SpanType.a => write("</a>")
            case SpanType.code => write("</code>")
            case SpanType.del => write("</del>")
            case SpanType.latexmath => write("</x-equation>")
            case SpanType.wikilink => write("</x-wikilink>")
            case SpanType.img => ()
            case SpanType.`default` => ()
            case SpanType.html => ()
        }
    }

    // ========================================
    // Text rendering
    // ========================================

    public func text(textType: TextType, content: String): Unit {
        let inImage = image_nesting_level > 0

        heading_tracker.trackText(textType, content)

        match (textType) {
            case TextType.text_none => write("")
            case TextType.html =>
                if (tag_filter) {
                    updateTagFilterRawDepth(content)
                    writeHtmlWithTagFilter(content)
                } else {
                    write(content)
                }
            case TextType.entity => writeEntity(content)
            case TextType.code =>
                var start: Int64 = 0
                for (j in 0..content.size) {
                    if (UInt8(content[j]) == UInt8(0x0A)) {
                        if (j > start) {
                            writeHtmlEscaped(content[start..j])
                        }
                        write(" ")
                        start = j + 1
                    }
                }
                if (start < content.size) {
                    writeHtmlEscaped(content[start..])
                }
            case _ =>
                if (tag_filter && tag_filter_raw_depth > 0) {
                    write(content)
                } else {
                    writeHtmlEscaped(content)
                }
        }
    }

    // ========================================
    // HTML write utilities
    // ========================================

    public func write(data: String): Unit {
        if (in_heading) {
            heading_buf.append(data)
        } else {
            out.append(data)
        }
    }

    func ensureNewline(): Unit {
        if (in_heading) {
            if (heading_buf.size > 0 && UInt8(heading_buf.toString()[heading_buf.size - 1]) != UInt8(0x0A)) {
                heading_buf.append('\n')
            }
        } else {
            let s = out.toString()
            if (s.size > 0 && UInt8(s[s.size - 1]) != UInt8(0x0A)) {
                out.append('\n')
            }
        }
    }

    public func writeHtmlEscaped(txt: String): Unit {
        var i: Int64 = 0
        while (i < txt.size) {
            let b = UInt8(txt[i])
            if (b == UInt8(0x26)) {
                write("&amp;")
                i += 1
            } else if (b == UInt8(0x3C)) {
                write("&lt;")
                i += 1
            } else if (b == UInt8(0x3E)) {
                write("&gt;")
                i += 1
            } else if (b == UInt8(0x22)) {
                write("&quot;")
                i += 1
            } else {
                let start = i
                while (i < txt.size) {
                    let cb = UInt8(txt[i])
                    if (cb == UInt8(0x26) || cb == UInt8(0x3C) || cb == UInt8(0x3E) || cb == UInt8(0x22)) {
                        break
                    }
                    i += 1
                }
                if (i > start) {
                    write(txt[start..i])
                }
            }
        }
    }

    func writeUrlEscaped(txt: String): Unit {
        for (i in 0..txt.size) {
            writeUrlByte(UInt8(txt[i]))
        }
    }

    func writeUrlByte(byte: UInt8): Unit {
        if (byte == UInt8(0x26)) {
            write("&amp;")
        } else if (byte == UInt8(0x27)) {
            write("&#x27;")
        } else if ((byte >= UInt8(0x41) && byte <= UInt8(0x5A)) ||
                   (byte >= UInt8(0x61) && byte <= UInt8(0x7A)) ||
                   (byte >= UInt8(0x30) && byte <= UInt8(0x39))) {
            write(byteToString(byte))
        } else if (byte == UInt8(0x2D) || byte == UInt8(0x2E) || byte == UInt8(0x5F) || byte == UInt8(0x7E) ||
                   byte == UInt8(0x3A) || byte == UInt8(0x2F) || byte == UInt8(0x3F) || byte == UInt8(0x23) || byte == UInt8(0x40) ||
                   byte == UInt8(0x21) || byte == UInt8(0x24) || byte == UInt8(0x28) || byte == UInt8(0x29) || byte == UInt8(0x2A) ||
                   byte == UInt8(0x2B) || byte == UInt8(0x2C) || byte == UInt8(0x3B) || byte == UInt8(0x3D) || byte == UInt8(0x25)) {
            write(byteToString(byte))
        } else {
            write("%")
            write(byteToString(hexDigit(UInt8(byte >> 4))))
            write(byteToString(hexDigit(byte & UInt8(0x0F))))
        }
    }

    func writeUrlWithEscapes(txt: String): Unit {
        var i: Int64 = 0
        while (i < txt.size) {
            if (UInt8(txt[i]) == UInt8(0x5C) && i + 1 < txt.size && isAsciiPunctuation(UInt8(txt[i + 1]))) {
                writeUrlByte(UInt8(txt[i + 1]))
                i += 2
            } else if (UInt8(txt[i]) == UInt8(0x26)) {
                if (let Some(endPos) <- findEntity(txt, i)) {
                    writeEntityToUrl(txt[i..endPos])
                    i = endPos
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

    func writeTitleWithEscapes(txt: String): Unit {
        var i: Int64 = 0
        while (i < txt.size) {
            if (UInt8(txt[i]) == UInt8(0x5C) && i + 1 < txt.size && isAsciiPunctuation(UInt8(txt[i + 1]))) {
                writeHtmlEscaped(txt[i + 1..i + 2])
                i += 2
            } else if (UInt8(txt[i]) == UInt8(0x26)) {
                if (let Some(endPos) <- findEntity(txt, i)) {
                    writeEntity(txt[i..endPos])
                    i = endPos
                } else {
                    write("&amp;")
                    i += 1
                }
            } else {
                writeHtmlEscaped(txt[i..i + 1])
                i += 1
            }
        }
    }

    func writeWithEntityDecoding(txt: String): Unit {
        var i: Int64 = 0
        while (i < txt.size) {
            if (UInt8(txt[i]) == UInt8(0x26)) {
                if (let Some(endPos) <- findEntity(txt, i)) {
                    writeEntity(txt[i..endPos])
                    i = endPos
                    continue
                }
            } else if (UInt8(txt[i]) == UInt8(0x5C) && i + 1 < txt.size && isAsciiPunctuation(UInt8(txt[i + 1]))) {
                writeHtmlEscaped(txt[i + 1..i + 2])
                i += 2
                continue
            }
            writeHtmlEscaped(txt[i..i + 1])
            i += 1
        }
    }

    func writeEntity(entityText: String): Unit {
        if (let Some(decoded) <- decodeEntityToUtf8(entityText)) {
            if (decoded.size > 0) {
                writeHtmlEscaped(decoded)
            } else {
                write(entityText)
            }
        } else {
            write(entityText)
        }
    }

    func writeEntityToUrl(entityText: String): Unit {
        if (let Some(decoded) <- decodeEntityToUtf8(entityText)) {
            if (decoded.size > 0) {
                for (i in 0..decoded.size) {
                    writeUrlByte(UInt8(decoded[i]))
                }
            } else {
                writeUrlEscaped(entityText)
            }
        } else {
            writeUrlEscaped(entityText)
        }
    }

    func writeDecimal(value: UInt32): Unit {
        if (value == 0) {
            write("0")
            return
        }
        var v = value
        var buf = ArrayList<UInt8>()
        while (v > 0) {
            buf.add(UInt8(0x30) + UInt8(v % UInt32(10)))
            v /= UInt32(10)
        }
        var i = buf.size - 1
        while (i >= 0) {
            write(byteToString(buf[Int64(i)]))
            i -= 1
        }
    }

    // ========================================
    // Tag filtering
    // ========================================

    func updateTagFilterRawDepth(content: String): Unit {
        if (content.size < 2 || UInt8(content[0]) != UInt8(0x3C)) {
            return
        }
        if (UInt8(content[1]) == UInt8(0x2F)) {
            if (isDisallowedTag(content) && tag_filter_raw_depth > 0) {
                tag_filter_raw_depth -= 1
            }
        } else {
            if (isDisallowedTag(content)) {
                if (content.size >= 2 && !(UInt8(content[content.size - 2]) == UInt8(0x2F) && UInt8(content[content.size - 1]) == UInt8(0x3E))) {
                    tag_filter_raw_depth += 1
                }
            }
        }
    }

    func writeHtmlWithTagFilter(content: String): Unit {
        var start: Int64 = 0
        var i: Int64 = 0
        while (i < content.size) {
            if (UInt8(content[i]) == UInt8(0x3C) && isDisallowedTag(content[i..])) {
                if (i > start) {
                    write(content[start..i])
                }
                write("&lt;")
                start = i + 1
            }
            i += 1
        }
        if (Int64(start) < content.size) {
            write(content[start..])
        }
    }

    func isDisallowedTag(content: String): Bool {
        if (content.size < 2 || UInt8(content[0]) != UInt8(0x3C)) {
            return false
        }
        let afterLt: Int64 = if (UInt8(content[1]) == UInt8(0x2F)) { 2 } else { 1 }
        if (afterLt >= content.size) {
            return false
        }

        let disallowed = ArrayList<String>()
        disallowed.add("title")
        disallowed.add("textarea")
        disallowed.add("style")
        disallowed.add("xmp")
        disallowed.add("iframe")
        disallowed.add("noembed")
        disallowed.add("noframes")
        disallowed.add("script")
        disallowed.add("plaintext")
        for (j in 0..disallowed.size) {
            if (matchTagNameCI(content, afterLt, disallowed[j])) {
                return true
            }
        }
        return false
    }

    func matchTagNameCI(content: String, pos: Int64, tag: String): Bool {
        if (pos + tag.size > content.size) {
            return false
        }
        if (!asciiCaseEql(content[pos..pos + tag.size], tag)) {
            return false
        }
        let end = pos + tag.size
        if (end >= content.size) {
            return true
        }
        let c = UInt8(content[end])
        return c == UInt8(0x3E) || c == UInt8(0x20) || c == UInt8(0x09) || c == UInt8(0x0A) || c == UInt8(0x2F)
    }

    // ========================================
    // Static helpers
    // ========================================

    func hexDigit(v: UInt8): UInt8 {
        return if (v < UInt8(10)) { UInt8(0x30) + v } else { UInt8(0x41) + v - UInt8(10) }
    }
}
