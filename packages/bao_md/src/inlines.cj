// Inline element processing
// Translated from: src/md/inlines.zig
package bao_md

import std.collection.*

// ============================================================================
// Inline content processing
// ============================================================================

public func processLeafBlock(parser: Parser, block_lines: Array<VerbatimLine>, trim_trailing: Bool): Unit {
    if (block_lines.size == 0) {
        return
    }

    parser.buffer = StringBuilder()
    for (vline in block_lines) {
        if (vline.beg > vline.end || vline.end > parser.size) {
            continue
        }
        if (parser.buffer.size > 0) {
            parser.buffer.append('\n')
        }
        parser.buffer.append(parser.text[Int64(vline.beg)..Int64(vline.end)])
    }

    var merged = parser.buffer.toString()
    if (trim_trailing) {
        while (merged.size > 0 && (UInt8(merged[merged.size - 1]) == UInt8(0x20) ||
               UInt8(merged[merged.size - 1]) == UInt8(0x09))) {
            merged = merged[0..merged.size - 1]
        }
    }
    processInlineContent(parser, merged, block_lines[0].beg)
}

public func processInlineContent(parser: Parser, content: String, base_off: OFF): Unit {
    collectEmphasisDelimiters(parser, content)
    resolveEmphasisDelimiters(parser)

    var i: Int64 = 0
    var text_start: Int64 = 0

    while (i < content.size) {
        let c = UInt8(content[i])

        // newline
        if (c == UInt8(0x0A)) {
            var emit_end = i
            var is_hard = false
            if (emit_end > text_start && UInt8(content[emit_end - 1]) == UInt8(0x5C)) {
                emit_end -= 1
                is_hard = true
            } else {
                var sp = emit_end
                while (sp > text_start && UInt8(content[sp - 1]) == UInt8(0x20)) {
                    sp -= 1
                }
                if (emit_end - sp >= 2) {
                    while (sp > text_start && (UInt8(content[sp - 1]) == UInt8(0x20) || UInt8(content[sp - 1]) == UInt8(0x09))) {
                        sp -= 1
                    }
                    emit_end = sp
                    is_hard = true
                }
            }
            if (emit_end > text_start) {
                emitText(parser, TextType.normal, content[text_start..emit_end])
            }
            if (is_hard) {
                emitText(parser, TextType.normal, "<br />\n")
            } else {
                emitText(parser, TextType.normal, "\n")
            }
            i += 1
            text_start = i
            continue
        }

        // backslash escape
        if (c == UInt8(0x5C) && i + 1 < content.size && isAsciiPunctuation(UInt8(content[i + 1]))) {
            if (i > text_start) {
                emitText(parser, TextType.normal, content[text_start..i])
            }
            i += 1
            emitText(parser, TextType.normal, content[i..i + 1])
            i += 1
            text_start = i
            continue
        }

        // code span
        if (c == UInt8(0x60)) {
            if (i > text_start) {
                emitText(parser, TextType.normal, content[text_start..i])
            }
            let count = countBackticks(content, i)
            if (let Some(end_pos) <- findCodeSpanEnd(parser, content, i + count, count)) {
                enterSpan(parser, SpanType.code)
                let code_content = normalizeCodeSpanContent(parser, content[i + count..end_pos])
                emitText(parser, TextType.code, code_content)
                leaveSpan(parser, SpanType.code)
                i = end_pos + count
            } else {
                emitText(parser, TextType.normal, content[i..i + count])
                i += count
            }
            text_start = i
            continue
        }

        // HTML entity
        if (c == UInt8(0x26)) {
            if (let Some(end_pos) <- findEntity(content, i)) {
                if (i > text_start) {
                    emitText(parser, TextType.normal, content[text_start..i])
                }
                emitText(parser, TextType.entity, content[i..end_pos])
                i = end_pos
                text_start = i
                continue
            }
        }

        // emphasis/strikethrough
        if (c == UInt8(0x2A) || c == UInt8(0x5F) || (c == UInt8(0x7E) && parser.flags.strikethrough)) {
            var delim_cursor: Int64 = 0
            while (delim_cursor < parser.emph_delims.size && parser.emph_delims[delim_cursor].pos < i) {
                delim_cursor += 1
            }

            if (delim_cursor < parser.emph_delims.size && parser.emph_delims[delim_cursor].pos == i) {
                if (i > text_start) { emitText(parser, TextType.normal, content[text_start..i]) }

                let d = parser.emph_delims[delim_cursor]
                let run_end = d.pos + d.count

                if (d.emph_char == UInt8(0x7E)) {
                    if (d.close_count > 0) { leaveSpan(parser, SpanType.del) }
                } else {
                    emitEmphCloseTags(parser, d.close_sizes, d.close_num)
                }

                let text_chars = d.count - (d.open_count + d.close_count)
                if (text_chars > 0) {
                    emitText(parser, TextType.normal, content[i..i + text_chars])
                }

                if (d.emph_char == UInt8(0x7E)) {
                    if (d.open_count > 0) { enterSpan(parser, SpanType.del) }
                } else {
                    emitEmphOpenTags(parser, d.open_sizes, d.open_num)
                }

                delim_cursor += 1
                i = run_end
                text_start = i
                continue
            }
            i += 1
            continue
        }

        // HTML tags
        if (c == UInt8(0x3C) && !parser.flags.no_html_spans) {
            if (let Some(tag_end) <- findHtmlTag(parser, content, i)) {
                if (i > text_start) {
                    emitText(parser, TextType.normal, content[text_start..i])
                }
                emitText(parser, TextType.html, content[i..tag_end])
                i = tag_end
                text_start = i
                continue
            }
            if (let Some(autolink) <- findAutolink(parser, content, i)) {
                if (i > text_start) {
                    emitText(parser, TextType.normal, content[text_start..i])
                }
                renderAutolink(parser, content[i + 1..autolink.end_pos - 1], autolink.is_email)
                i = autolink.end_pos
                text_start = i
                continue
            }
        }

        // wiki links: [[destination]] or [[destination|label]]
        if (c == UInt8(0x5B) && parser.flags.wiki_links && i + 1 < content.size && UInt8(content[i + 1]) == UInt8(0x5B)) {
            if (i > text_start) { emitText(parser, TextType.normal, content[text_start..i]) }
            if (let Some(end_pos) <- processWikiLink(parser, content, i)) {
                i = end_pos
                text_start = i
                continue
            }
            text_start = i
        }

        // links: [text](url) or [text][ref]
        if (c == UInt8(0x5B)) {
            if (i > text_start) { emitText(parser, TextType.normal, content[text_start..i]) }
            if (let Some(end_pos) <- processLink(parser, content, i, base_off, false)) {
                i = end_pos
            } else {
                emitText(parser, TextType.normal, "[")
                i += 1
            }
            text_start = i
            continue
        }

        // images: ![text](url)
        if (c == UInt8(0x21) && i + 1 < content.size && UInt8(content[i + 1]) == UInt8(0x5B)) {
            if (i > text_start) { emitText(parser, TextType.normal, content[text_start..i]) }
            if (let Some(end_pos) <- processLink(parser, content, i + 1, base_off, true)) {
                i = end_pos
            } else {
                emitText(parser, TextType.normal, "!")
                i += 1
            }
            text_start = i
            continue
        }

        // permissive autolinks
        if (parser.link_nesting_level == 0 &&
            ((c == UInt8(0x3A) && parser.flags.permissive_url_autolinks) ||
             (c == UInt8(0x40) && parser.flags.permissive_email_autolinks) ||
             (c == UInt8(0x2E) && parser.flags.permissive_www_autolinks)))
        {
            if (let Some(al) <- findPermissiveAutolink(content, i, false)) {
                if (al.beg > text_start) { emitText(parser, TextType.normal, content[text_start..al.beg]) }
                let link_text = content[al.beg..al.end]
                let detail = SpanDetail()
                detail.href = link_text
                detail.permissive_autolink = true
                if (c == UInt8(0x40)) {
                    detail.autolink_email = true
                } else if (c == UInt8(0x2E)) {
                    detail.autolink_www = true
                }
                parser.renderer.enterSpan(SpanType.a, detail)
                emitText(parser, TextType.normal, link_text)
                parser.renderer.leaveSpan(SpanType.a)
                i = al.end
                text_start = i
                continue
            }
            if (let Some(al2) <- findPermissiveAutolink(content, i, true)) {
                if (al2.beg > text_start) { emitText(parser, TextType.normal, content[text_start..al2.beg]) }
                let link_text = content[al2.beg..al2.end]
                let detail = SpanDetail()
                detail.href = link_text
                detail.permissive_autolink = true
                if (c == UInt8(0x40)) {
                    detail.autolink_email = true
                } else if (c == UInt8(0x2E)) {
                    detail.autolink_www = true
                }
                parser.renderer.enterSpan(SpanType.a, detail)
                emitText(parser, TextType.normal, link_text)
                parser.renderer.leaveSpan(SpanType.a)
                i = al2.end
                text_start = i
                continue
            }
        }

        // null character
        if (c == 0) {
            if (i > text_start) {
                emitText(parser, TextType.normal, content[text_start..i])
            }
            emitText(parser, TextType.normal, "\u{EF}\u{BF}\u{BD}")
            i += 1
            text_start = i
            continue
        }

        i += 1
    }

    if (text_start < content.size) {
        emitText(parser, TextType.normal, content[text_start..])
    }
}

// ============================================================================
// Emphasis delimiter collection and resolution
// ============================================================================

public func collectEmphasisDelimiters(parser: Parser, content: String): Unit {
    parser.emph_delims = ArrayList<EmphDelim>()
    var i: Int64 = 0
    while (i < content.size) {
        let c = UInt8(content[i])
        if (c == UInt8(0x5C) && i + 1 < content.size && isAsciiPunctuation(UInt8(content[i + 1]))) {
            i += 2
            continue
        }
        if (c == UInt8(0x60)) {
            let count = countBackticks(content, i)
            if (let Some(end_pos) <- findCodeSpanEnd(parser, content, i + count, count)) {
                i = end_pos + count
            } else {
                i += count
            }
            continue
        }
        if (c == UInt8(0x2A) || c == UInt8(0x5F)) {
            let run_start = i
            while (i < content.size && UInt8(content[i]) == c) {
                i += 1
            }
            let count = i - run_start
            let d = EmphDelim()
            d.pos = run_start
            d.count = count
            d.emph_char = c
            d.can_open = canOpenEmphasis(c, content, run_start, i)
            d.can_close = canCloseEmphasis(c, content, run_start, i)
            d.remaining = count
            parser.emph_delims.add(d)
            continue
        }
        if (c == UInt8(0x7E) && parser.flags.strikethrough) {
            let run_start = i
            while (i < content.size && UInt8(content[i]) == UInt8(0x7E)) {
                i += 1
            }
            let count = i - run_start
            if (count == 1 || count == 2) {
                let d = EmphDelim()
                d.pos = run_start
                d.count = count
                d.emph_char = c
                d.can_open = canOpenEmphasis(UInt8(0x7E), content, run_start, i)
                d.can_close = canCloseEmphasis(UInt8(0x7E), content, run_start, i)
                d.remaining = count
                parser.emph_delims.add(d)
            }
            continue
        }
        i += 1
    }
}

public func resolveEmphasisDelimiters(parser: Parser): Unit {
    let delims = parser.emph_delims
    if (delims.size == 0) {
        return
    }

    var closer_idx: Int64 = 0
    while (closer_idx < delims.size) {
        if (!delims[closer_idx].can_close || delims[closer_idx].remaining == 0) {
            closer_idx += 1
            continue
        }

        var found_match = false
        if (closer_idx > 0) {
            var oi = closer_idx
            while (oi > 0) {
                oi -= 1
                let opener = delims[oi]
                if (opener.emph_char != delims[closer_idx].emph_char) {
                    continue
                }
                if (!opener.can_open || opener.remaining == 0 || !opener.active) {
                    continue
                }

                if (opener.emph_char == UInt8(0x7E)) {
                    if (opener.count != delims[closer_idx].count) {
                        continue
                    }
                }

                if (opener.emph_char != UInt8(0x7E) &&
                    (opener.can_close || delims[closer_idx].can_open) &&
                    (opener.count + delims[closer_idx].count) % 3 == 0 &&
                    opener.count % 3 != 0 && delims[closer_idx].count % 3 != 0) {
                    continue
                }

                let use: Int64 = if (opener.emph_char == UInt8(0x7E)) {
                    opener.remaining
                } else if (opener.remaining >= 2 && delims[closer_idx].remaining >= 2) {
                    2
                } else {
                    1
                }

                delims[oi].remaining -= use
                delims[oi].open_count += use
                if (delims[oi].open_num < UInt8(MAX_EMPH_MATCHES)) {
                    delims[oi].open_sizes[Int64(delims[oi].open_num)] = UInt8(use)
                    delims[oi].open_num += 1
                }
                delims[closer_idx].remaining -= use
                delims[closer_idx].close_count += use
                if (delims[closer_idx].close_num < UInt8(MAX_EMPH_MATCHES)) {
                    delims[closer_idx].close_sizes[Int64(delims[closer_idx].close_num)] = UInt8(use)
                    delims[closer_idx].close_num += 1
                }

                var k = oi + 1
                while (k < closer_idx) {
                    delims[k].active = false
                    k += 1
                }

                found_match = true

                if (delims[closer_idx].remaining > 0 && delims[closer_idx].can_close) {
                    closer_idx -= 1
                }
                break
            }
        }

        if (!found_match && !delims[closer_idx].can_open) {
            delims[closer_idx].active = false
        }
        closer_idx += 1
    }
}

// ============================================================================
// Helper functions
// ============================================================================

public func countBackticks(content: String, start: Int64): Int64 {
    var pos = start
    while (pos < content.size && UInt8(content[pos]) == UInt8(0x60)) {
        pos += 1
    }
    return pos - start
}

public func findCodeSpanEnd(parser: Parser, content: String, start: Int64, count: Int64): ?Int64 {
    var pos = start
    while (pos < content.size) {
        if (UInt8(content[pos]) == UInt8(0x60)) {
            let backtick_pos = pos
            pos += 1
            while (pos < content.size && UInt8(content[pos]) == UInt8(0x60)) {
                pos += 1
            }
            if (pos - backtick_pos == count) {
                return backtick_pos
            }
        } else {
            pos += 1
        }
    }
    return None
}

public func normalizeCodeSpanContent(parser: Parser, content: String): String {
    if (content.size >= 2) {
        let first_is_space = UInt8(content[0]) == UInt8(0x20) || UInt8(content[0]) == UInt8(0x0A)
        let last_is_space = UInt8(content[content.size - 1]) == UInt8(0x20) || UInt8(content[content.size - 1]) == UInt8(0x0A)
        if (first_is_space && last_is_space) {
            var has_non_space = false
            for (idx in 0..content.size) {
                let ch = UInt8(content[idx])
                if (ch != UInt8(0x20) && ch != UInt8(0x0A)) {
                    has_non_space = true
                    break
                }
            }
            if (has_non_space) {
                return content[1..content.size - 1]
            }
        }
    }
    return content
}

public func isLeftFlanking(content: String, run_start: Int64, run_end: Int64): Bool {
    if (run_end >= content.size) {
        return false
    }
    let after_cp = decodeUtf8(content, run_end).codepoint
    if (isUnicodeWhitespace(after_cp)) {
        return false
    }
    if (isUnicodePunctuation(after_cp)) {
        if (run_start == 0) {
            return true
        }
        let before_cp = decodeUtf8Backward(content, run_start).codepoint
        return isUnicodeWhitespace(before_cp) || isUnicodePunctuation(before_cp)
    }
    return true
}

public func isRightFlanking(content: String, run_start: Int64, run_end: Int64): Bool {
    if (run_start == 0) {
        return false
    }
    let before_cp = decodeUtf8Backward(content, run_start).codepoint
    if (isUnicodeWhitespace(before_cp)) {
        return false
    }
    if (isUnicodePunctuation(before_cp)) {
        if (run_end >= content.size) {
            return true
        }
        let after_cp = decodeUtf8(content, run_end).codepoint
        return isUnicodeWhitespace(after_cp) || isUnicodePunctuation(after_cp)
    }
    return true
}

public func canOpenEmphasis(emph_char: UInt8, content: String, run_start: Int64, run_end: Int64): Bool {
    let lf = isLeftFlanking(content, run_start, run_end)
    if (!lf) {
        return false
    }
    if (emph_char == UInt8(0x2A)) {
        return true
    }
    let rf = isRightFlanking(content, run_start, run_end)
    return !rf || (run_start > 0 && isUnicodePunctuation(decodeUtf8Backward(content, run_start).codepoint))
}

public func canCloseEmphasis(emph_char: UInt8, content: String, run_start: Int64, run_end: Int64): Bool {
    let rf = isRightFlanking(content, run_start, run_end)
    if (!rf) {
        return false
    }
    if (emph_char == UInt8(0x2A)) {
        return true
    }
    let lf = isLeftFlanking(content, run_start, run_end)
    return !lf || (run_end < content.size && isUnicodePunctuation(decodeUtf8(content, run_end).codepoint))
}

public func enterSpan(parser: Parser, span_type: SpanType): Unit {
    if (parser.image_nesting_level > 0) {
        return
    }
    parser.renderer.enterSpan(span_type, SpanDetail())
}

public func leaveSpan(parser: Parser, span_type: SpanType): Unit {
    if (parser.image_nesting_level > 0) {
        return
    }
    parser.renderer.leaveSpan(span_type)
}

public func emitText(parser: Parser, text_type: TextType, content: String): Unit {
    parser.renderer.text(text_type, content)
}

public func findEntity(parser: Parser, content: String, start: Int64): ?Int64 {
    return findEntity(content, start)
}

public func findHtmlTag(parser: Parser, content: String, start: Int64): ?Int64 {
    if (start + 1 >= content.size) {
        return None
    }
    var pos = start + 1
    let c = UInt8(content[pos])

    // closing tag
    if (c == UInt8(0x2F)) {
        pos += 1
        if (pos >= content.size || !isAlpha(UInt8(content[pos]))) {
            return None
        }
        while (pos < content.size && (isAlphaNum(UInt8(content[pos])) || UInt8(content[pos]) == UInt8(0x2D))) {
            pos += 1
        }
        while (pos < content.size && isWhitespace(UInt8(content[pos]))) {
            pos += 1
        }
        if (pos < content.size && UInt8(content[pos]) == UInt8(0x3E)) {
            return pos + 1
        }
        return None
    }

    // comment
    if (c == UInt8(0x21) && pos + 1 < content.size && UInt8(content[pos + 1]) == UInt8(0x2D) && pos + 2 < content.size && UInt8(content[pos + 2]) == UInt8(0x2D)) {
        pos += 3
        if (pos < content.size && UInt8(content[pos]) == UInt8(0x3E)) {
            return pos + 1
        }
        if (pos + 1 < content.size && UInt8(content[pos]) == UInt8(0x2D) && UInt8(content[pos + 1]) == UInt8(0x3E)) {
            return pos + 2
        }
        while (pos + 2 < content.size) {
            if (UInt8(content[pos]) == UInt8(0x2D) && UInt8(content[pos + 1]) == UInt8(0x2D) && UInt8(content[pos + 2]) == UInt8(0x3E)) {
                return pos + 3
            }
            pos += 1
        }
        return None
    }

    // open tag
    if (isAlpha(c)) {
        while (pos < content.size && (isAlphaNum(UInt8(content[pos])) || UInt8(content[pos]) == UInt8(0x2D))) {
            pos += 1
        }
        while (pos < content.size) {
            var had_ws = false
            while (pos < content.size && isWhitespace(UInt8(content[pos]))) {
                had_ws = true
                pos += 1
            }
            if (pos >= content.size) {
                break
            }
            if (UInt8(content[pos]) == UInt8(0x3E)) {
                return pos + 1
            }
            if (UInt8(content[pos]) == UInt8(0x2F) && pos + 1 < content.size && UInt8(content[pos + 1]) == UInt8(0x3E)) {
                return pos + 2
            }
            if (!had_ws) {
                return None
            }
            // attribute name
            if (!isAlpha(UInt8(content[pos])) && UInt8(content[pos]) != UInt8(0x5F) && UInt8(content[pos]) != UInt8(0x3A)) {
                return None
            }
            pos += 1
            while (pos < content.size && (isAlphaNum(UInt8(content[pos])) ||
                   UInt8(content[pos]) == UInt8(0x5F) || UInt8(content[pos]) == UInt8(0x3A) ||
                   UInt8(content[pos]) == UInt8(0x2E) || UInt8(content[pos]) == UInt8(0x2D))) {
                pos += 1
            }
            // optional attribute value
            let before_eq_ws = pos
            while (pos < content.size && isWhitespace(UInt8(content[pos]))) {
                pos += 1
            }
            if (pos < content.size && UInt8(content[pos]) == UInt8(0x3D)) {
                pos += 1
                while (pos < content.size && isWhitespace(UInt8(content[pos]))) {
                    pos += 1
                }
                if (pos >= content.size) {
                    return None
                }
                if (UInt8(content[pos]) == UInt8(0x22)) {
                    pos += 1
                    while (pos < content.size && UInt8(content[pos]) != UInt8(0x22)) {
                        pos += 1
                    }
                    if (pos >= content.size) {
                        return None
                    }
                    pos += 1
                } else if (UInt8(content[pos]) == UInt8(0x27)) {
                    pos += 1
                    while (pos < content.size && UInt8(content[pos]) != UInt8(0x27)) {
                        pos += 1
                    }
                    if (pos >= content.size) {
                        return None
                    }
                    pos += 1
                } else {
                    while (pos < content.size && !isWhitespace(UInt8(content[pos])) &&
                           UInt8(content[pos]) != UInt8(0x22) && UInt8(content[pos]) != UInt8(0x27) &&
                           UInt8(content[pos]) != UInt8(0x3D) && UInt8(content[pos]) != UInt8(0x3C) &&
                           UInt8(content[pos]) != UInt8(0x3E) && UInt8(content[pos]) != UInt8(0x60)) {
                        pos += 1
                    }
                }
            } else {
                pos = before_eq_ws
            }
        }
    }

    return None
}

public func findAutolink(parser: Parser, content: String, start: Int64): ?AutolinkEndResult {
    if (start + 1 >= content.size) {
        return None
    }
    let pos = start + 1

    if (isAlpha(UInt8(content[pos]))) {
        var scheme_end = pos
        while (scheme_end < content.size && (isAlphaNum(UInt8(content[scheme_end])) ||
               UInt8(content[scheme_end]) == UInt8(0x2B) || UInt8(content[scheme_end]) == UInt8(0x2D) || UInt8(content[scheme_end]) == UInt8(0x2E))) {
            scheme_end += 1
        }
        let scheme_len = scheme_end - pos
        if (scheme_len >= 2 && scheme_len <= 32 && scheme_end < content.size && UInt8(content[scheme_end]) == UInt8(0x3A)) {
            var uri_end = scheme_end + 1
            while (uri_end < content.size && UInt8(content[uri_end]) != UInt8(0x3E) && !isWhitespace(UInt8(content[uri_end]))) {
                uri_end += 1
            }
            if (uri_end < content.size && UInt8(content[uri_end]) == UInt8(0x3E)) {
                return AutolinkEndResult(uri_end + 1, false)
            }
        }

        // email autolink
        var email_pos = pos
        while (email_pos < content.size && (isAlphaNum(UInt8(content[email_pos])) ||
               UInt8(content[email_pos]) == UInt8(0x2E) || UInt8(content[email_pos]) == UInt8(0x2D) ||
               UInt8(content[email_pos]) == UInt8(0x5F) || UInt8(content[email_pos]) == UInt8(0x2B))) {
            email_pos += 1
        }
        if (email_pos < content.size && UInt8(content[email_pos]) == UInt8(0x40) && email_pos > pos) {
            email_pos += 1
            let domain_start = email_pos
            var label_len: UInt32 = 0
            var dot_count: UInt32 = 0
            var valid_domain = true
            while (email_pos < content.size && (isAlphaNum(UInt8(content[email_pos])) ||
                   UInt8(content[email_pos]) == UInt8(0x2E) || UInt8(content[email_pos]) == UInt8(0x2D))) {
                if (UInt8(content[email_pos]) == UInt8(0x2E)) {
                    if (label_len == 0) {
                        valid_domain = false
                        break
                    }
                    label_len = 0
                    dot_count += 1
                } else {
                    label_len += 1
                    if (label_len > 63) {
                        valid_domain = false
                        break
                    }
                }
                email_pos += 1
            }
            if (valid_domain && email_pos < content.size && UInt8(content[email_pos]) == UInt8(0x3E) &&
                email_pos > domain_start && label_len > 0 && dot_count > 0 &&
                isAlphaNum(UInt8(content[email_pos - 1]))) {
                return AutolinkEndResult(email_pos + 1, true)
            }
        }
    }

    return None
}

public class AutolinkEndResult {
    public var end_pos: Int64 = 0
    public var is_email: Bool = false
    public init() {}
    public init(end_pos: Int64, is_email: Bool) {
        this.end_pos = end_pos
        this.is_email = is_email
    }
}

// ============================================================================
// Emphasis tag emission
// ============================================================================

public func emitEmphOpenTags(parser: Parser, sizes: Array<UInt8>, num: UInt8): Unit {
    for (idx in 0..Int64(num)) {
        let j = Int64(num) - 1 - idx
        if (sizes[j] == 2) {
            enterSpan(parser, SpanType.strong)
        } else {
            enterSpan(parser, SpanType.em)
        }
    }
}

public func emitEmphCloseTags(parser: Parser, sizes: Array<UInt8>, num: UInt8): Unit {
    for (idx in 0..Int64(num)) {
        if (sizes[Int64(idx)] == 2) {
            leaveSpan(parser, SpanType.strong)
        } else {
            leaveSpan(parser, SpanType.em)
        }
    }
}
