// 严格翻译自: src/md/inlines.zig
// 行内元素处理
package bao_md

// ============================================================================
// 行内内容处理
// ============================================================================

/// 合并所有行并处理行内元素
public func processLeafBlock(parser: Parser, block_lines: Array<VerbatimLine>, trim_trailing: Bool): Unit {
    if (block_lines.isEmpty) {
        return
    }

    parser.buffer = StringBuilder()
    for (vline in block_lines) {
        if (vline.beg > vline.end || vline.end > parser.size) {
            continue
        }
        if (parser.buffer.length > 0) {
            parser.buffer.append('\n')
        }
        parser.buffer.append(parser.text.substring(Int64(vline.beg), Int64(vline.end)))
    }

    var merged = parser.buffer.toString()
    if (trim_trailing) {
        while (merged.length > 0 && (UInt8(merged[merged.length - 1]) == ' '.toUInt8() ||
               UInt8(merged[merged.length - 1]) == '\t'.toUInt8())) {
            merged = merged.substring(0, merged.length - 1)
        }
    }
    processInlineContent(parser, merged, block_lines[0].beg)
}

/// 处理行内内容
public func processInlineContent(parser: Parser, content: String, base_off: OFF): Unit {
    // 收集并解决强调分隔符
    collectEmphasisDelimiters(parser, content)
    resolveEmphasisDelimiters(parser)

    var i: Int64 = 0
    var text_start: Int64 = 0

    while (i < content.length) {
        let c = UInt8(content[i])

        // 换行符
        if (c == '\n'.toUInt8()) {
            var emit_end = i
            var is_hard = false
            if (emit_end > text_start && UInt8(content[emit_end - 1]) == '\\'.toUInt8()) {
                emit_end -= 1
                is_hard = true
            } else {
                var sp = emit_end
                while (sp > text_start && content[sp - 1] == ' ') {
                    sp -= 1
                }
                if (emit_end - sp >= 2) {
                    while (sp > text_start && (content[sp - 1] == ' ' || content[sp - 1] == '\t')) {
                        sp -= 1
                    }
                    emit_end = sp
                    is_hard = true
                }
            }
            if (emit_end > text_start) {
                emitText(parser, TextType.normal, content.substring(text_start, emit_end))
            }
            if (is_hard) {
                emitText(parser, TextType.br, "")
            } else {
                emitText(parser, TextType.softbr, "")
            }
            i += 1
            text_start = i
            continue
        }

        // 反斜杠转义
        if (c == '\\'.toUInt8() && i + 1 < content.length && isAsciiPunctuation(UInt8(content[i + 1]))) {
            if (i > text_start) {
                emitText(parser, TextType.normal, content.substring(text_start, i))
            }
            i += 1
            emitText(parser, TextType.normal, content.substring(i, i + 1))
            i += 1
            text_start = i
            continue
        }

        // 代码跨距
        if (c == '`'.toUInt8()) {
            if (i > text_start) {
                emitText(parser, TextType.normal, content.substring(text_start, i))
            }
            let count = countBackticks(content, i)
            if (let Some(end_pos) <- findCodeSpanEnd(parser, content, i + count, count)) {
                enterSpan(parser, SpanType.code)
                let code_content = normalizeCodeSpanContent(parser, content.substring(i + count, end_pos))
                emitText(parser, TextType.code, code_content)
                leaveSpan(parser, SpanType.code)
                i = end_pos + count
            } else {
                emitText(parser, TextType.normal, content.substring(i, i + count))
                i += count
            }
            text_start = i
            continue
        }

        // HTML 实体
        if (c == '&'.toUInt8()) {
            if (let Some(end_pos) <- findEntity(content, i)) {
                if (i > text_start) {
                    emitText(parser, TextType.normal, content.substring(text_start, i))
                }
                emitText(parser, TextType.entity, content.substring(i, end_pos))
                i = end_pos
                text_start = i
                continue
            }
        }

        // 强调/删除线: 使用已解析的分隔符
        if (c == '*'.toUInt8() || c == '_'.toUInt8() || (c == '~'.toUInt8() && parser.flags.strikethrough)) {
            // 查找对应的已解析分隔符
            var delim_cursor: Int64 = 0
            while (delim_cursor < parser.emph_delims.length && parser.emph_delims[Int64(delim_cursor)].pos < i) {
                delim_cursor += 1
            }

            if (delim_cursor < parser.emph_delims.length && parser.emph_delims[Int64(delim_cursor)].pos == i) {
                if (i > text_start) emitText(parser, TextType.normal, content.substring(text_start, i))

                let d = parser.emph_delims[Int64(delim_cursor)]
                let run_end = d.pos + d.count

                // 先发送关闭标签（从最内到最外）
                if (d.emph_char == '~'.toUInt8()) {
                    if (d.close_count > 0) leaveSpan(parser, SpanType.del)
                } else {
                    emitEmphCloseTags(parser, d.close_sizes, d.close_num)
                }

                // 将剩余的分隔符字符作为文本发送
                let text_chars = d.count - (d.open_count + d.close_count)
                if (text_chars > 0) {
                    emitText(parser, TextType.normal, content.substring(i, i + text_chars))
                }

                // 发送打开标签（从最外到最内）
                if (d.emph_char == '~'.toUInt8()) {
                    if (d.open_count > 0) enterSpan(parser, SpanType.del)
                } else {
                    emitEmphOpenTags(parser, d.open_sizes, d.open_num)
                }

                delim_cursor += 1
                i = run_end
                text_start = i
                continue
            }
            // 没有找到已解析的分隔符，继续前进
            i += 1
            continue
        }

        // HTML 标签
        if (c == '<'.toUInt8() && !parser.flags.no_html_spans) {
            if (let Some(tag_end) <- findHtmlTag(parser, content, i)) {
                if (i > text_start) {
                    emitText(parser, TextType.normal, content.substring(text_start, i))
                }
                emitText(parser, TextType.html, content.substring(i, tag_end))
                i = tag_end
                text_start = i
                continue
            }
            // 自动链接
            if (let Some(autolink) <- findAutolink(parser, content, i)) {
                if (i > text_start) {
                    emitText(parser, TextType.normal, content.substring(text_start, i))
                }
                renderAutolink(parser, content.substring(i + 1, autolink.end_pos - 1), autolink.is_email)
                i = autolink.end_pos
                text_start = i
                continue
            }
        }

        // Wiki 链接: [[destination]] 或 [[destination|label]]
        if (c == '['.toUInt8() && parser.flags.wiki_links && i + 1 < content.length && content[i + 1] == '[') {
            if (i > text_start) emitText(parser, TextType.normal, content.substring(text_start, i))
            if (let Some(end_pos) <- processWikiLink(parser, content, i)) {
                i = end_pos
                text_start = i
                continue
            }
            // Wiki 链接未匹配: 恢复 text_start
            text_start = i
        }

        // 链接: [text](url) 或 [text][ref]
        if (c == '['.toUInt8()) {
            if (i > text_start) emitText(parser, TextType.normal, content.substring(text_start, i))
            if (let Some(end_pos) <- processLink(parser, content, i, base_off, false)) {
                i = end_pos
            } else {
                emitText(parser, TextType.normal, "[")
                i += 1
            }
            text_start = i
            continue
        }

        // 图片: ![text](url)
        if (c == '!'.toUInt8() && i + 1 < content.length && content[i + 1] == '[') {
            if (i > text_start) emitText(parser, TextType.normal, content.substring(text_start, i))
            if (let Some(end_pos) <- processLink(parser, content, i + 1, base_off, true)) {
                i = end_pos
            } else {
                emitText(parser, TextType.normal, "!")
                i += 1
            }
            text_start = i
            continue
        }

        // 宽松自动链接
        if (parser.link_nesting_level == 0 &&
            ((c == ':'.toUInt8() && parser.flags.permissive_url_autolinks) ||
             (c == '@'.toUInt8() && parser.flags.permissive_email_autolinks) ||
             (c == '.'.toUInt8() && parser.flags.permissive_www_autolinks)))
        {
            var al = findPermissiveAutolink(content, i, false)
            if (al == None) {
                al = findPermissiveAutolink(content, i, true)
                if (al != None) {
                    // TODO: 检查强调边界
                }
            }
            if (al != None) {
                let a = al.get()
                if (a.beg > text_start) emitText(parser, TextType.normal, content.substring(text_start, a.beg))

                let link_text = content.substring(a.beg, a.end)
                if (c == '@'.toUInt8()) {
                    parser.renderer.enterSpan(SpanType.a, SpanDetail(href: link_text, title: "", autolink: false, permissive_autolink: true, autolink_email: true, autolink_www: false))
                    emitText(parser, TextType.normal, link_text)
                    parser.renderer.leaveSpan(SpanType.a)
                } else if (c == '.'.toUInt8()) {
                    parser.renderer.enterSpan(SpanType.a, SpanDetail(href: link_text, title: "", autolink: false, permissive_autolink: true, autolink_email: false, autolink_www: true))
                    emitText(parser, TextType.normal, link_text)
                    parser.renderer.leaveSpan(SpanType.a)
                } else {
                    parser.renderer.enterSpan(SpanType.a, SpanDetail(href: link_text, title: "", autolink: false, permissive_autolink: true, autolink_email: false, autolink_www: false))
                    emitText(parser, TextType.normal, link_text)
                    parser.renderer.leaveSpan(SpanType.a)
                }
                i = a.end
                text_start = i
                continue
            }
        }

        // Null 字符
        if (c == 0) {
            if (i > text_start) {
                emitText(parser, TextType.normal, content.substring(text_start, i))
            }
            emitText(parser, TextType.null_char, "")
            i += 1
            text_start = i
            continue
        }

        i += 1
    }

    if (text_start < content.length) {
        emitText(parser, TextType.normal, content.substring(text_start))
    }
}

// ============================================================================
// 强调分隔符收集与解决
// ============================================================================

/// 收集强调分隔符
public func collectEmphasisDelimiters(parser: Parser, content: String): Unit {
    parser.emph_delims = []
    var i: Int64 = 0
    while (i < content.length) {
        let c = UInt8(content[i])
        // 跳过反斜杠转义
        if (c == '\\'.toUInt8() && i + 1 < content.length && isAsciiPunctuation(UInt8(content[i + 1]))) {
            i += 2
            continue
        }
        // 跳过代码跨距
        if (c == '`'.toUInt8()) {
            let count = countBackticks(content, i)
            if (let Some(end_pos) <- findCodeSpanEnd(parser, content, i + count, count)) {
                i = end_pos + count
            } else {
                i += count
            }
            continue
        }
        // 强调分隔符
        if (c == '*'.toUInt8() || c == '_'.toUInt8()) {
            let run_start = i
            while (i < content.length && UInt8(content[i]) == c) {
                i += 1
            }
            let count = i - run_start
            parser.emph_delims.append(EmphDelim().also {
                it.pos = run_start
                it.count = count
                it.emph_char = c
                it.can_open = canOpenEmphasis(c, content, run_start, i)
                it.can_close = canCloseEmphasis(c, content, run_start, i)
                it.remaining = count
            })
            continue
        }
        // 删除线分隔符
        if (c == '~'.toUInt8() && parser.flags.strikethrough) {
            let run_start = i
            while (i < content.length && UInt8(content[i]) == '~') {
                i += 1
            }
            let count = i - run_start
            if (count == 1 || count == 2) {
                parser.emph_delims.append(EmphDelim().also {
                    it.pos = run_start
                    it.count = count
                    it.emph_char = c
                    it.can_open = canOpenEmphasis('~'.toUInt8(), content, run_start, i)
                    it.can_close = canCloseEmphasis('~'.toUInt8(), content, run_start, i)
                    it.remaining = count
                })
            }
            continue
        }
        i += 1
    }
}

/// 解决强调分隔符
public func resolveEmphasisDelimiters(parser: Parser): Unit {
    let delims = parser.emph_delims
    if (delims.isEmpty) {
        return
    }

    var closer_idx: Int64 = 0
    while (closer_idx < delims.length) {
        if (!delims[Int64(closer_idx)].can_close || delims[Int64(closer_idx)].remaining == 0) {
            closer_idx += 1
            continue
        }

        var found_match = false
        if (closer_idx > 0) {
            var oi = closer_idx
            while (oi > 0) {
                oi -= 1
                let opener = delims[Int64(oi)]
                if (opener.emph_char != delims[Int64(closer_idx)].emph_char) {
                    continue
                }
                if (!opener.can_open || opener.remaining == 0 || !opener.active) {
                    continue
                }

                // 删除线: 需要精确计数匹配
                if (opener.emph_char == '~'.toUInt8()) {
                    if (opener.count != delims[Int64(closer_idx)].count) {
                        continue
                    }
                }

                // 三规则
                if (opener.emph_char != '~'.toUInt8() &&
                    (opener.can_close || delims[Int64(closer_idx)].can_open) &&
                    (opener.count + delims[Int64(closer_idx)].count) % 3 == 0 &&
                    opener.count % 3 != 0 && delims[Int64(closer_idx)].count % 3 != 0) {
                    continue
                }

                // 匹配找到
                let use: Int64 = if (opener.emph_char == '~'.toUInt8()) {
                    opener.remaining
                } else if (opener.remaining >= 2 && delims[Int64(closer_idx)].remaining >= 2) {
                    2
                } else {
                    1
                }

                delims[Int64(oi)].remaining -= use
                delims[Int64(oi)].open_count += use
                if (delims[Int64(oi)].open_num < UInt8(MAX_EMPH_MATCHES)) {
                    delims[Int64(oi)].open_sizes[Int64(delims[Int64(oi)].open_num)] = UInt8(use)
                    delims[Int64(oi)].open_num += 1
                }
                delims[Int64(closer_idx)].remaining -= use
                delims[Int64(closer_idx)].close_count += use
                if (delims[Int64(closer_idx)].close_num < UInt8(MAX_EMPH_MATCHES)) {
                    delims[Int64(closer_idx)].close_sizes[Int64(delims[Int64(closer_idx)].close_num)] = UInt8(use)
                    delims[Int64(closer_idx)].close_num += 1
                }

                // 停用之间的所有分隔符
                var k = oi + 1
                while (k < closer_idx) {
                    delims[Int64(k)].active = false
                    k += 1
                }

                found_match = true

                if (delims[Int64(closer_idx)].remaining > 0 && delims[Int64(closer_idx)].can_close) {
                    closer_idx -= 1
                }
                break
            }
        }

        if (!found_match && !delims[Int64(closer_idx)].can_open) {
            delims[Int64(closer_idx)].active = false
        }
        closer_idx += 1
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 计算连续反引号
public func countBackticks(content: String, start: Int64): Int64 {
    var pos = start
    while (pos < content.length && content[pos] == '`') {
        pos += 1
    }
    return pos - start
}

/// 查找匹配的关闭反引号运行
public func findCodeSpanEnd(parser: Parser, content: String, start: Int64, count: Int64): ?Int64 {
    var pos = start
    while (pos < content.length) {
        if (content[pos] == '`') {
            let backtick_pos = pos
            pos += 1
            while (pos < content.length && content[pos] == '`') {
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

/// 规范化代码跨距内容
public func normalizeCodeSpanContent(parser: Parser, content: String): String {
    if (content.length >= 2) {
        let first_is_space = content[0] == ' ' || content[0] == '\n'
        let last_is_space = content[content.length - 1] == ' ' || content[content.length - 1] == '\n'
        if (first_is_space && last_is_space) {
            // 检查是否不全为空格
            var has_non_space = false
            for (c in content) {
                if (c != ' ' && c != '\n') {
                    has_non_space = true
                    break
                }
            }
            if (has_non_space) {
                return content.substring(1, content.length - 1)
            }
        }
    }
    return content
}

/// 检查是否为左翼
public func isLeftFlanking(content: String, run_start: Int64, run_end: Int64): Bool {
    if (run_end >= content.length) {
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

/// 检查是否为右翼
public func isRightFlanking(content: String, run_start: Int64, run_end: Int64): Bool {
    if (run_start == 0) {
        return false
    }
    let before_cp = decodeUtf8Backward(content, run_start).codepoint
    if (isUnicodeWhitespace(before_cp)) {
        return false
    }
    if (isUnicodePunctuation(before_cp)) {
        if (run_end >= content.length) {
            return true
        }
        let after_cp = decodeUtf8(content, run_end).codepoint
        return isUnicodeWhitespace(after_cp) || isUnicodePunctuation(after_cp)
    }
    return true
}

/// 检查是否可以开强调
public func canOpenEmphasis(emph_char: UInt8, content: String, run_start: Int64, run_end: Int64): Bool {
    let lf = isLeftFlanking(content, run_start, run_end)
    if (!lf) {
        return false
    }
    if (emph_char == '*'.toUInt8()) {
        return true
    }
    let rf = isRightFlanking(content, run_start, run_end)
    return !rf || (run_start > 0 && isUnicodePunctuation(decodeUtf8Backward(content, run_start).codepoint))
}

/// 检查是否可以闭强调
public func canCloseEmphasis(emph_char: UInt8, content: String, run_start: Int64, run_end: Int64): Bool {
    let rf = isRightFlanking(content, run_start, run_end)
    if (!rf) {
        return false
    }
    if (emph_char == '*'.toUInt8()) {
        return true
    }
    let lf = isLeftFlanking(content, run_start, run_end)
    return !lf || (run_end < content.length && isUnicodePunctuation(decodeUtf8(content, run_end).codepoint))
}

/// 进入 span
public func enterSpan(parser: Parser, span_type: SpanType): Unit {
    if (parser.image_nesting_level > 0) {
        return
    }
    parser.renderer.enterSpan(span_type, SpanDetail())
}

/// 离开 span
public func leaveSpan(parser: Parser, span_type: SpanType): Unit {
    if (parser.image_nesting_level > 0) {
        return
    }
    parser.renderer.leaveSpan(span_type)
}

/// 发送文本
public func emitText(parser: Parser, text_type: TextType, content: String): Unit {
    parser.renderer.text(text_type, content)
}

/// 查找 HTML 实体
public func findEntity(parser: Parser, content: String, start: Int64): ?Int64 {
    return findEntity(content, start)
}

/// 查找 HTML 标签
public func findHtmlTag(parser: Parser, content: String, start: Int64): ?Int64 {
    if (start + 1 >= content.length) {
        return None
    }
    var pos = start + 1
    let c = UInt8(content[pos])

    // 关闭标签
    if (c == '/'.toUInt8()) {
        pos += 1
        if (pos >= content.length || !isAlpha(UInt8(content[pos]))) {
            return None
        }
        while (pos < content.length && (isAlphaNum(UInt8(content[pos])) || content[pos] == '-')) {
            pos += 1
        }
        while (pos < content.length && isWhitespace(UInt8(content[pos]))) {
            pos += 1
        }
        if (pos < content.length && content[pos] == '>') {
            return pos + 1
        }
        return None
    }

    // 注释
    if (c == '!'.toUInt8() && pos + 1 < content.length && content[pos + 1] == '-' && pos + 2 < content.length && content[pos + 2] == '-') {
        pos += 3
        if (pos < content.length && content[pos] == '>') {
            return pos + 1
        }
        if (pos + 1 < content.length && content[pos] == '-' && content[pos + 1] == '>') {
            return pos + 2
        }
        while (pos + 2 < content.length) {
            if (content[pos] == '-' && content[pos + 1] == '-' && content[pos + 2] == '>') {
                return pos + 3
            }
            pos += 1
        }
        return None
    }

    // 开放标签
    if (isAlpha(c)) {
        while (pos < content.length && (isAlphaNum(UInt8(content[pos])) || content[pos] == '-')) {
            pos += 1
        }
        while (pos < content.length) {
            var had_ws = false
            while (pos < content.length && isWhitespace(UInt8(content[pos]))) {
                had_ws = true
                pos += 1
            }
            if (pos >= content.length) {
                break
            }
            if (content[pos] == '>') {
                return pos + 1
            }
            if (content[pos] == '/' && pos + 1 < content.length && content[pos + 1] == '>') {
                return pos + 2
            }
            if (!had_ws) {
                return None
            }
            // 属性名
            if (!isAlpha(UInt8(content[pos])) && content[pos] != '_' && content[pos] != ':') {
                return None
            }
            pos += 1
            while (pos < content.length && (isAlphaNum(UInt8(content[pos])) ||
                   content[pos] == '_' || content[pos] == ':' ||
                   content[pos] == '.' || content[pos] == '-')) {
                pos += 1
            }
            // 可选属性值
            let before_eq_ws = pos
            while (pos < content.length && isWhitespace(UInt8(content[pos]))) {
                pos += 1
            }
            if (pos < content.length && content[pos] == '=') {
                pos += 1
                while (pos < content.length && isWhitespace(UInt8(content[pos]))) {
                    pos += 1
                }
                if (pos >= content.length) {
                    return None
                }
                if (content[pos] == '"') {
                    pos += 1
                    while (pos < content.length && content[pos] != '"') {
                        pos += 1
                    }
                    if (pos >= content.length) {
                        return None
                    }
                    pos += 1
                } else if (content[pos] == '\'') {
                    pos += 1
                    while (pos < content.length && content[pos] != '\'') {
                        pos += 1
                    }
                    if (pos >= content.length) {
                        return None
                    }
                    pos += 1
                } else {
                    while (pos < content.length && !isWhitespace(UInt8(content[pos])) &&
                           content[pos] != '"' && content[pos] != '\'' &&
                           content[pos] != '=' && content[pos] != '<' &&
                           content[pos] != '>' && content[pos] != '`') {
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

/// 查找自动链接
public func findAutolink(parser: Parser, content: String, start: Int64): ?AutolinkEndResult {
    if (start + 1 >= content.length) {
        return None
    }
    let pos = start + 1

    // URI 自动链接: scheme://...
    if (isAlpha(UInt8(content[pos]))) {
        var scheme_end = pos
        while (scheme_end < content.length && (isAlphaNum(UInt8(content[scheme_end])) ||
               content[scheme_end] == '+' || content[scheme_end] == '-' || content[scheme_end] == '.')) {
            scheme_end += 1
        }
        let scheme_len = scheme_end - pos
        if (scheme_len >= 2 && scheme_len <= 32 && scheme_end < content.length && content[scheme_end] == ':') {
            var uri_end = scheme_end + 1
            while (uri_end < content.length && content[uri_end] != '>' && !isWhitespace(UInt8(content[uri_end]))) {
                uri_end += 1
            }
            if (uri_end < content.length && content[uri_end] == '>') {
                return AutolinkEndResult(uri_end + 1, false)
            }
        }

        // 电子邮件自动链接
        var email_pos = pos
        while (email_pos < content.length && (isAlphaNum(UInt8(content[email_pos])) ||
               content[email_pos] == '.' || content[email_pos] == '-' ||
               content[email_pos] == '_' || content[email_pos] == '+')) {
            email_pos += 1
        }
        if (email_pos < content.length && content[email_pos] == '@' && email_pos > pos) {
            email_pos += 1
            let domain_start = email_pos
            var label_len: UInt32 = 0
            var dot_count: UInt32 = 0
            var valid_domain = true
            while (email_pos < content.length && (isAlphaNum(UInt8(content[email_pos])) ||
                   content[email_pos] == '.' || content[email_pos] == '-')) {
                if (content[email_pos] == '.') {
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
            if (valid_domain && email_pos < content.length && content[email_pos] == '>' &&
                email_pos > domain_start && label_len > 0 && dot_count > 0 &&
                isAlphaNum(UInt8(content[email_pos - 1]))) {
                return AutolinkEndResult(email_pos + 1, true)
            }
        }
    }

    return None
}

/// 自动链接结束结果
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
// 强调标签发射
// ============================================================================

/// 发送强调打开标签（从最外到最内）
/// sizes 中第一个匹配是最内层的，所以逆序发送（HTML 中最外层先）
public func emitEmphOpenTags(parser: Parser, sizes: Array<UInt8>, num: UInt8): Unit {
    for (idx in 0..Int64(num)) {
        let j = Int64(num) - 1 - idx
        if (sizes[Int64(j)] == 2) {
            enterSpan(parser, SpanType.strong)
        } else {
            enterSpan(parser, SpanType.em)
        }
    }
}

/// 发送强调关闭标签（从最内到最外）
/// sizes 中第一个匹配是第一个关闭的（最内层），正序发送
public func emitEmphCloseTags(parser: Parser, sizes: Array<UInt8>, num: UInt8): Unit {
    for (idx in 0..Int64(num)) {
        if (sizes[Int64(idx)] == 2) {
            leaveSpan(parser, SpanType.strong)
        } else {
            leaveSpan(parser, SpanType.em)
        }
    }
}
