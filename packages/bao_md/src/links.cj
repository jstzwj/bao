// Link processing (inline links, reference links, wiki links, autolinks)
// Translated from: src/md/links.zig
package bao_md

// ============================================================================
// Link processing
// ============================================================================

public func processLink(parser: Parser, content: String, start: Int64, baseOff: OFF, isImage: Bool): ?Int64 {
    var pos = start + 1
    var bracketDepth: UInt32 = 1
    var hasInnerBracket = false
    while (pos < content.size && bracketDepth > 0) {
        if (UInt8(content[pos]) == UInt8(0x5C) && pos + 1 < content.size) {
            pos += 2
            continue
        }
        if (UInt8(content[pos]) == UInt8(0x60)) {
            let count = countBackticks(content, pos)
            if (let Some(endPos) <- findCodeSpanEnd(parser, content, pos + count, count)) {
                pos = endPos + count
                continue
            }
        }
        if (UInt8(content[pos]) == UInt8(0x3C) && !parser.flags.no_html_spans) {
            if (let Some(tagEnd) <- findHtmlTag(parser, content, pos)) {
                pos = tagEnd
                continue
            }
            if (let Some(al) <- findAutolink(parser, content, pos)) {
                pos = al.end_pos
                continue
            }
        }
        if (UInt8(content[pos]) == UInt8(0x5B)) {
            bracketDepth += 1
            hasInnerBracket = true
        }
        if (UInt8(content[pos]) == UInt8(0x5D)) {
            bracketDepth -= 1
        }
        if (bracketDepth > 0) {
            pos += 1
        }
    }

    if (bracketDepth != 0) {
        return None
    }

    let labelEnd = pos
    let label = content[start + 1..labelEnd]
    pos += 1

    // inline link: [text](url "title")
    if (pos < content.size && UInt8(content[pos]) == UInt8(0x28)) {
        pos += 1
        while (pos < content.size && (isBlank(UInt8(content[pos])) || UInt8(content[pos]) == UInt8(0x0A) || UInt8(content[pos]) == UInt8(0x0D))) {
            pos += 1
        }

        var destStart = pos
        var destEnd = pos

        if (pos < content.size && UInt8(content[pos]) == UInt8(0x3C)) {
            destStart = pos + 1
            pos += 1
            var angleValid = true
            while (pos < content.size && UInt8(content[pos]) != UInt8(0x3E)) {
                if (UInt8(content[pos]) == UInt8(0x0A) || UInt8(content[pos]) == UInt8(0x0D)) {
                    angleValid = false
                    break
                }
                if (UInt8(content[pos]) == UInt8(0x5C) && pos + 1 < content.size) {
                    pos += 2
                } else {
                    pos += 1
                }
            }
            if (!angleValid) {
                return None
            }
            destEnd = pos
            if (pos < content.size) {
                pos += 1
            }
        } else {
            var parenDepth2: UInt32 = 0
            while (pos < content.size && !isWhitespace(UInt8(content[pos]))) {
                if (UInt8(content[pos]) == UInt8(0x28)) {
                    parenDepth2 += 1
                } else if (UInt8(content[pos]) == UInt8(0x29)) {
                    if (parenDepth2 == 0) {
                        break
                    }
                    parenDepth2 -= 1
                }
                if (UInt8(content[pos]) == UInt8(0x5C) && pos + 1 < content.size) {
                    pos += 2
                } else {
                    pos += 1
                }
            }
            destEnd = pos
        }

        while (pos < content.size && (isBlank(UInt8(content[pos])) || UInt8(content[pos]) == UInt8(0x0A) || UInt8(content[pos]) == UInt8(0x0D))) {
            pos += 1
        }

        var title = ""
        if (pos < content.size && (UInt8(content[pos]) == UInt8(0x22) || UInt8(content[pos]) == UInt8(0x27) || UInt8(content[pos]) == UInt8(0x28))) {
            let closeChar: UInt8 = if (UInt8(content[pos]) == UInt8(0x28)) { UInt8(0x29) } else { UInt8(content[pos]) }
            pos += 1
            let titleStart = pos
            while (pos < content.size && UInt8(content[pos]) != closeChar) {
                if (UInt8(content[pos]) == UInt8(0x5C) && pos + 1 < content.size) {
                    pos += 2
                } else {
                    pos += 1
                }
            }
            title = content[titleStart..pos]
            if (pos < content.size) {
                pos += 1
            }
        }

        while (pos < content.size && (isBlank(UInt8(content[pos])) || UInt8(content[pos]) == UInt8(0x0A) || UInt8(content[pos]) == UInt8(0x0D))) {
            pos += 1
        }

        if (pos < content.size && UInt8(content[pos]) == UInt8(0x29)) {
            pos += 1
            let dest = content[destStart..destEnd]

            if (!isImage && hasInnerBracket && labelContainsLink(parser, label)) {
                return None
            }

            if (parser.image_nesting_level > 0) {
                processInlineContent(parser, label, 0)
            } else if (isImage) {
                let detail = SpanDetail()
                detail.href = dest
                detail.title = title
                parser.renderer.enterSpan(SpanType.img, detail)
                parser.image_nesting_level += 1
                processInlineContent(parser, label, 0)
                parser.image_nesting_level -= 1
                parser.renderer.leaveSpan(SpanType.img)
            } else {
                let detail = SpanDetail()
                detail.href = dest
                detail.title = title
                parser.renderer.enterSpan(SpanType.a, detail)
                parser.link_nesting_level += 1
                processInlineContent(parser, label, 0)
                parser.link_nesting_level -= 1
                parser.renderer.leaveSpan(SpanType.a)
            }

            return pos
        }
    }

    // reference link: [text][ref] or [text][] or shortcut [text]
    if (pos < content.size && UInt8(content[pos]) == UInt8(0x5B)) {
        let bracketPos = pos
        pos += 1
        let refStart = pos
        while (pos < content.size && UInt8(content[pos]) != UInt8(0x5D)) {
            if (UInt8(content[pos]) == UInt8(0x5B)) {
                break
            }
            if (UInt8(content[pos]) == UInt8(0x5C) && pos + 1 < content.size) {
                pos += 2
            } else {
                pos += 1
            }
        }
        if (pos < content.size && UInt8(content[pos]) == UInt8(0x5D)) {
            let refLabel = if (pos > refStart) { content[refStart..pos] } else { label }
            pos += 1
            if (let Some(refDef) <- lookupRefDef(parser, refLabel)) {
                if (!isImage && hasInnerBracket && labelContainsLink(parser, label)) {
                    return None
                }
                renderRefLink(parser, label, refDef, isImage)
                return pos
            }
        } else {
            pos = bracketPos
        }
    }

    // shortcut reference link
    let charAfterLabel: UInt8 = if (labelEnd + 1 < content.size) { UInt8(content[labelEnd + 1]) } else { UInt8(0) }
    if (charAfterLabel != UInt8(0x5B)) {
        if (let Some(refDef) <- lookupRefDef(parser, label)) {
            if (!isImage && hasInnerBracket && labelContainsLink(parser, label)) {
                return None
            }
            renderRefLink(parser, label, refDef, isImage)
            return labelEnd + 1
        }
    }

    return None
}

public class BracketLinkResult {
    public var is_link: Bool = false
    public var label_end: Int64 = 0
    public var link_end: Int64 = 0
    public init() {}
    public init(is_link: Bool, label_end: Int64, link_end: Int64) {
        this.is_link = is_link
        this.label_end = label_end
        this.link_end = link_end
    }
}

public func tryMatchBracketLink(parser: Parser, content: String, start: Int64): BracketLinkResult {
    var pos = start + 1
    var depth: UInt32 = 1
    while (pos < content.size && depth > 0) {
        if (UInt8(content[pos]) == UInt8(0x5C) && pos + 1 < content.size) {
            pos += 2
            continue
        }
        if (UInt8(content[pos]) == UInt8(0x60)) {
            let count = countBackticks(content, pos)
            if (let Some(endPos) <- findCodeSpanEnd(parser, content, pos + count, count)) {
                pos = endPos + count
                continue
            }
        }
        if (UInt8(content[pos]) == UInt8(0x3C) && !parser.flags.no_html_spans) {
            if (let Some(tagEnd) <- findHtmlTag(parser, content, pos)) {
                pos = tagEnd
                continue
            }
            if (let Some(al) <- findAutolink(parser, content, pos)) {
                pos = al.end_pos
                continue
            }
        }
        if (UInt8(content[pos]) == UInt8(0x5B)) {
            depth += 1
        }
        if (UInt8(content[pos]) == UInt8(0x5D)) {
            depth -= 1
        }
        if (depth > 0) {
            pos += 1
        }
    }
    if (depth != 0) {
        return BracketLinkResult(false, 0, 0)
    }

    let labelEnd = pos
    pos += 1

    if (pos >= content.size) {
        let innerLabel = content[start + 1..labelEnd]
        let isRef = (match (lookupRefDef(parser, innerLabel)) { case Some(_) => true case None => false })
        return BracketLinkResult(isRef, labelEnd, labelEnd + 1)
    }

    if (UInt8(content[pos]) == UInt8(0x28)) {
        var p = pos + 1
        while (p < content.size && (isBlank(UInt8(content[p])) || UInt8(content[p]) == UInt8(0x0A) || UInt8(content[p]) == UInt8(0x0D))) {
            p += 1
        }
        if (p < content.size && UInt8(content[p]) == UInt8(0x3C)) {
            p += 1
            while (p < content.size && UInt8(content[p]) != UInt8(0x3E) && UInt8(content[p]) != UInt8(0x0A)) {
                if (UInt8(content[p]) == UInt8(0x5C) && p + 1 < content.size) {
                    p += 2
                } else {
                    p += 1
                }
            }
            if (p < content.size && UInt8(content[p]) == UInt8(0x3E)) {
                p += 1
            } else {
                return BracketLinkResult(false, labelEnd, labelEnd + 1)
            }
        } else {
            var parenDepth3: UInt32 = 0
            while (p < content.size && !isWhitespace(UInt8(content[p]))) {
                if (UInt8(content[p]) == UInt8(0x28)) {
                    parenDepth3 += 1
                } else if (UInt8(content[p]) == UInt8(0x29)) {
                    if (parenDepth3 == 0) {
                        break
                    }
                    parenDepth3 -= 1
                }
                if (UInt8(content[p]) == UInt8(0x5C) && p + 1 < content.size) {
                    p += 2
                } else {
                    p += 1
                }
            }
        }
        while (p < content.size && (isBlank(UInt8(content[p])) || UInt8(content[p]) == UInt8(0x0A) || UInt8(content[p]) == UInt8(0x0D))) {
            p += 1
        }
        if (p < content.size && (UInt8(content[p]) == UInt8(0x22) || UInt8(content[p]) == UInt8(0x27) || UInt8(content[p]) == UInt8(0x28))) {
            let closeCh: UInt8 = if (UInt8(content[p]) == UInt8(0x28)) { UInt8(0x29) } else { UInt8(content[p]) }
            p += 1
            while (p < content.size && UInt8(content[p]) != closeCh) {
                if (UInt8(content[p]) == UInt8(0x5C) && p + 1 < content.size) {
                    p += 2
                } else {
                    p += 1
                }
            }
            if (p < content.size) {
                p += 1
            }
        }
        while (p < content.size && (isBlank(UInt8(content[p])) || UInt8(content[p]) == UInt8(0x0A) || UInt8(content[p]) == UInt8(0x0D))) {
            p += 1
        }
        if (p < content.size && UInt8(content[p]) == UInt8(0x29)) {
            return BracketLinkResult(true, labelEnd, p + 1)
        }
    }

    if (UInt8(content[pos]) == UInt8(0x5B)) {
        var p = pos + 1
        while (p < content.size && UInt8(content[p]) != UInt8(0x5D)) {
            if (UInt8(content[p]) == UInt8(0x5B)) {
                break
            }
            if (UInt8(content[p]) == UInt8(0x5C) && p + 1 < content.size) {
                p += 2
            } else {
                p += 1
            }
        }
        if (p < content.size && UInt8(content[p]) == UInt8(0x5D)) {
            let refLabel = if (p > pos + 1) { content[pos + 1..p] } else { content[start + 1..labelEnd] }
            if (let Some(_) <- lookupRefDef(parser, refLabel)) {
                return BracketLinkResult(true, labelEnd, p + 1)
            }
        }
    }

    let innerLabel = content[start + 1..labelEnd]
    if (let Some(_) <- lookupRefDef(parser, innerLabel)) {
        return BracketLinkResult(true, labelEnd, labelEnd + 1)
    }

    return BracketLinkResult(false, labelEnd, labelEnd + 1)
}

public func labelContainsLink(parser: Parser, label: String): Bool {
    var pos: Int64 = 0
    while (pos < label.size) {
        if (UInt8(label[pos]) == UInt8(0x5C) && pos + 1 < label.size) {
            pos += 2
            continue
        }
        if (UInt8(label[pos]) == UInt8(0x60)) {
            let count = countBackticks(label, pos)
            if (let Some(endPos) <- findCodeSpanEnd(parser, label, pos + count, count)) {
                pos = endPos + count
                continue
            }
        }
        if (UInt8(label[pos]) == UInt8(0x3C) && !parser.flags.no_html_spans) {
            if (let Some(tagEnd) <- findHtmlTag(parser, label, pos)) {
                pos = tagEnd
                continue
            }
            if (let Some(al) <- findAutolink(parser, label, pos)) {
                pos = al.end_pos
                continue
            }
        }
        if (UInt8(label[pos]) == UInt8(0x5B)) {
            let isInnerImage = pos > 0 && UInt8(label[pos - 1]) == UInt8(0x21)
            let inner = tryMatchBracketLink(parser, label, pos)
            if (inner.is_link && !isInnerImage) {
                return true
            }
            if (inner.link_end > pos) {
                pos = inner.link_end
                continue
            }
        }
        pos += 1
    }
    return false
}

public func processWikiLink(parser: Parser, content: String, start: Int64): ?Int64 {
    var pos = start + 2
    let innerStart = pos
    var pipePos: ?Int64 = None
    var bracketDepth: UInt32 = 0

    while (pos < content.size) {
        if (UInt8(content[pos]) == UInt8(0x0A) || UInt8(content[pos]) == UInt8(0x0D)) {
            return None
        }
        if (UInt8(content[pos]) == UInt8(0x5B)) {
            bracketDepth += 1
        } else if (UInt8(content[pos]) == UInt8(0x5D)) {
            if (bracketDepth > 0) {
                bracketDepth -= 1
            } else if (pos + 1 < content.size && UInt8(content[pos + 1]) == UInt8(0x5D)) {
                break
            } else {
                return None
            }
        } else if (UInt8(content[pos]) == UInt8(0x7C) && (match (pipePos) { case None => true case _ => false }) && bracketDepth == 0) {
            pipePos = pos
        }
        pos += 1
    }

    if (pos >= content.size || UInt8(content[pos]) != UInt8(0x5D)) {
        return None
    }

    let innerEnd = pos
    let target = if (let Some(pp) <- pipePos) { content[innerStart..pp] } else { content[innerStart..innerEnd] }
    let wlabel = if (let Some(pp) <- pipePos) { content[pp + 1..innerEnd] } else { content[innerStart..innerEnd] }

    if (target.size > 100) {
        return None
    }

    let detail = SpanDetail()
    detail.href = target
    parser.renderer.enterSpan(SpanType.wikilink, detail)
    processInlineContent(parser, wlabel, 0)
    parser.renderer.leaveSpan(SpanType.wikilink)

    return pos + 2
}

public func renderRefLink(parser: Parser, labelContent: String, ref: RefDef, isImage: Bool): Unit {
    if (parser.image_nesting_level > 0) {
        processInlineContent(parser, labelContent, 0)
    } else if (isImage) {
        let detail = SpanDetail()
        detail.href = ref.dest
        detail.title = ref.title
        parser.renderer.enterSpan(SpanType.img, detail)
        parser.image_nesting_level += 1
        processInlineContent(parser, labelContent, 0)
        parser.image_nesting_level -= 1
        parser.renderer.leaveSpan(SpanType.img)
    } else {
        let detail = SpanDetail()
        detail.href = ref.dest
        detail.title = ref.title
        parser.renderer.enterSpan(SpanType.a, detail)
        parser.link_nesting_level += 1
        processInlineContent(parser, labelContent, 0)
        parser.link_nesting_level -= 1
        parser.renderer.leaveSpan(SpanType.a)
    }
}

public class AutolinkFindResult {
    public var end_pos: Int64 = 0
    public var is_email: Bool = false
    public init() {}
    public init(end_pos: Int64, is_email: Bool) {
        this.end_pos = end_pos
        this.is_email = is_email
    }
}

public func renderAutolink(parser: Parser, url: String, isEmail: Bool): Unit {
    let detail = SpanDetail()
    detail.href = url
    detail.autolink = true
    detail.autolink_email = isEmail
    parser.renderer.enterSpan(SpanType.a, detail)
    emitText(parser, TextType.normal, url)
    parser.renderer.leaveSpan(SpanType.a)
}
