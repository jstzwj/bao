// 严格翻译自: src/md/links.zig
// 链接处理（行内链接、引用链接、Wiki链接、自动链接）
package bao_md

// ============================================================================
// 链接处理
// ============================================================================

/// 处理链接: 行内链接、引用链接、快捷引用链接
/// 返回消耗的内容结束位置，如果未匹配到链接则返回 None
public func processLink(parser: Parser, content: String, start: Int64, baseOff: OFF, isImage: Bool): ?Int64 {
    // start 指向 '['
    // 找到匹配的 ']'，跳过代码跨度和 HTML 标签（它们优先级更高）
    var pos = start + 1
    var bracketDepth: UInt32 = 1
    var hasInnerBracket = false
    while (pos < content.length && bracketDepth > 0) {
        if (content[Int64(pos)] == '\\' && pos + 1 < content.length) {
            pos += 2
            continue
        }
        // 跳过代码跨度 — 优先级高于括号 (CommonMark §6.3)
        if (content[Int64(pos)] == '`') {
            let count = countBackticks(content, pos)
            let endOpt = findCodeSpanEnd(parser, content, pos + count, count)
            if (endOpt != None) {
                let endPos = endOpt.get()
                pos = endPos + count
                continue
            }
        }
        // 跳过 HTML 标签和自动链接 — 优先级高于括号
        if (content[Int64(pos)] == '<' && !parser.flags.no_html_spans) {
            let tagEnd = findHtmlTag(parser, content, pos)
            if (tagEnd != None) {
                pos = tagEnd.get()
                continue
            }
            let al = findAutolink(parser, content, pos)
            if (al != None) {
                pos = al.get().end_pos
                continue
            }
        }
        if (content[Int64(pos)] == '[') {
            bracketDepth += 1
            hasInnerBracket = true
        }
        if (content[Int64(pos)] == ']') {
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
    let label = content.substring(start + 1, labelEnd)
    pos += 1 // 跳过 ']'

    // 行内链接: [text](url "title")
    if (pos < content.length && content[Int64(pos)] == '(') {
        pos += 1
        // 跳过空白（包括合并段落行产生的换行符）
        while (pos < content.length && (isBlank(UInt8(content[Int64(pos)])) || content[Int64(pos)] == '\n' || content[Int64(pos)] == '\r')) {
            pos += 1
        }

        // 解析目标
        var destStart = pos
        var destEnd = pos

        if (pos < content.length && content[Int64(pos)] == '<') {
            // 尖括号目标（不允许换行）
            destStart = pos + 1
            pos += 1
            var angleValid = true
            while (pos < content.length && content[Int64(pos)] != '>') {
                if (content[Int64(pos)] == '\n' || content[Int64(pos)] == '\r') {
                    angleValid = false
                    break
                }
                if (content[Int64(pos)] == '\\' && pos + 1 < content.length) {
                    pos += 2
                } else {
                    pos += 1
                }
            }
            if (!angleValid) {
                return None
            }
            destEnd = pos
            if (pos < content.length) {
                pos += 1 // 跳过 >
            }
        } else {
            // 裸目标 — 平衡括号
            var parenDepth2: UInt32 = 0
            while (pos < content.length && !isWhitespace(UInt8(content[Int64(pos)]))) {
                if (content[Int64(pos)] == '(') {
                    parenDepth2 += 1
                } else if (content[Int64(pos)] == ')') {
                    if (parenDepth2 == 0) {
                        break
                    }
                    parenDepth2 -= 1
                }
                if (content[Int64(pos)] == '\\' && pos + 1 < content.length) {
                    pos += 2
                } else {
                    pos += 1
                }
            }
            destEnd = pos
        }

        // 跳过空白（包括换行符）
        while (pos < content.length && (isBlank(UInt8(content[Int64(pos)])) || content[Int64(pos)] == '\n' || content[Int64(pos)] == '\r')) {
            pos += 1
        }

        // 可选标题
        var title = ""
        if (pos < content.length && (content[Int64(pos)] == '"' || content[Int64(pos)] == '\'' || content[Int64(pos)] == '(')) {
            let closeChar: UInt8 = if (content[Int64(pos)] == '(') ')'.toUInt8() else UInt8(content[Int64(pos)])
            pos += 1
            let titleStart = pos
            while (pos < content.length && UInt8(content[Int64(pos)]) != closeChar) {
                if (content[Int64(pos)] == '\\' && pos + 1 < content.length) {
                    pos += 2
                } else {
                    pos += 1
                }
            }
            title = content.substring(titleStart, pos)
            if (pos < content.length) {
                pos += 1 // 跳过关闭引号
            }
        }

        // 跳过空白（包括换行符）
        while (pos < content.length && (isBlank(UInt8(content[Int64(pos)])) || content[Int64(pos)] == '\n' || content[Int64(pos)] == '\r')) {
            pos += 1
        }

        // 必须以 ')' 结束
        if (pos < content.length && content[Int64(pos)] == ')') {
            pos += 1
            let dest = content.substring(destStart, destEnd)

            // 链接嵌套禁止: 链接不能包含其他链接 (CommonMark §6.7)
            if (!isImage && hasInnerBracket && labelContainsLink(parser, label)) {
                return None
            }

            if (parser.image_nesting_level > 0) {
                // 在图片 alt 文本内 — 仅发出文本，不发出 HTML 标签
                processInlineContent(parser, label, 0)
            } else if (isImage) {
                parser.renderer.enterSpan(SpanType.img, SpanDetail().also {
                    it.href = dest; it.title = title
                })
                parser.image_nesting_level += 1
                processInlineContent(parser, label, 0)
                parser.image_nesting_level -= 1
                parser.renderer.leaveSpan(SpanType.img)
            } else {
                parser.renderer.enterSpan(SpanType.a, SpanDetail().also {
                    it.href = dest; it.title = title
                })
                parser.link_nesting_level += 1
                processInlineContent(parser, label, 0)
                parser.link_nesting_level -= 1
                parser.renderer.leaveSpan(SpanType.a)
            }

            return pos
        }
    }

    // 引用链接: [text][ref] 或 [text][] 或快捷 [text]
    if (pos < content.length && content[Int64(pos)] == '[') {
        let bracketPos = pos
        pos += 1
        let refStart = pos
        while (pos < content.length && content[Int64(pos)] != ']') {
            if (content[Int64(pos)] == '[') {
                break // 嵌套 [ 不允许出现在 ref 中
            }
            if (content[Int64(pos)] == '\\' && pos + 1 < content.length) {
                pos += 2
            } else {
                pos += 1
            }
        }
        if (pos < content.length && content[Int64(pos)] == ']') {
            let refLabel = if (pos > refStart) content.substring(refStart, pos) else label
            pos += 1
            let refDefOpt = lookupRefDef(parser, refLabel)
            if (refDefOpt != None) {
                let refDef = refDefOpt.get()
                // 链接嵌套禁止
                if (!isImage && hasInnerBracket && labelContainsLink(parser, label)) {
                    return None
                }
                renderRefLink(parser, label, refDef, isImage)
                return pos
            }
        } else {
            // 如果没找到有效的 ]，重置 pos
            pos = bracketPos
        }
    }

    // 快捷引用链接: [text] (后面没有跟着 [)
    let charAfterLabel: UInt8 = if (labelEnd + 1 < content.length) UInt8(content[Int64(labelEnd + 1)]) else 0.toUInt8()
    if (charAfterLabel != '['.toUInt8()) {
        let refDefOpt = lookupRefDef(parser, label)
        if (refDefOpt != None) {
            let refDef = refDefOpt.get()
            // 链接嵌套禁止
            if (!isImage && hasInnerBracket && labelContainsLink(parser, label)) {
                return None
            }
            renderRefLink(parser, label, refDef, isImage)
            return labelEnd + 1
        }
    }

    return None
}

/// 括号匹配链接结果
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

/// 尝试匹配括号对并检查是否构成链接
public func tryMatchBracketLink(parser: Parser, content: String, start: Int64): BracketLinkResult {
    var pos = start + 1
    var depth: UInt32 = 1
    while (pos < content.length && depth > 0) {
        if (content[Int64(pos)] == '\\' && pos + 1 < content.length) {
            pos += 2
            continue
        }
        if (content[Int64(pos)] == '`') {
            let count = countBackticks(content, pos)
            let endOpt = findCodeSpanEnd(parser, content, pos + count, count)
            if (endOpt != None) {
                pos = endOpt.get() + count
                continue
            }
        }
        if (content[Int64(pos)] == '<' && !parser.flags.no_html_spans) {
            let tagEnd = findHtmlTag(parser, content, pos)
            if (tagEnd != None) {
                pos = tagEnd.get()
                continue
            }
            let al = findAutolink(parser, content, pos)
            if (al != None) {
                pos = al.get().end_pos
                continue
            }
        }
        if (content[Int64(pos)] == '[') {
            depth += 1
        }
        if (content[Int64(pos)] == ']') {
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
    pos += 1 // 跳过 ]

    if (pos >= content.length) {
        // 快捷引用检查
        let innerLabel = content.substring(start + 1, labelEnd)
        let isRef = lookupRefDef(parser, innerLabel) != None
        return BracketLinkResult(isRef, labelEnd, labelEnd + 1)
    }

    // 行内链接: ](...)
    if (content[Int64(pos)] == '(') {
        var p = pos + 1
        // 跳过空白
        while (p < content.length && (isBlank(UInt8(content[Int64(p)])) || content[Int64(p)] == '\n' || content[Int64(p)] == '\r')) {
            p += 1
        }
        // 解析目标
        if (p < content.length && content[Int64(p)] == '<') {
            p += 1
            while (p < content.length && content[Int64(p)] != '>' && content[Int64(p)] != '\n') {
                if (content[Int64(p)] == '\\' && p + 1 < content.length) {
                    p += 2
                } else {
                    p += 1
                }
            }
            if (p < content.length && content[Int64(p)] == '>') {
                p += 1
            } else {
                return BracketLinkResult(false, labelEnd, labelEnd + 1)
            }
        } else {
            var parenDepth3: UInt32 = 0
            while (p < content.length && !isWhitespace(UInt8(content[Int64(p)]))) {
                if (content[Int64(p)] == '(') {
                    parenDepth3 += 1
                } else if (content[Int64(p)] == ')') {
                    if (parenDepth3 == 0) {
                        break
                    }
                    parenDepth3 -= 1
                }
                if (content[Int64(p)] == '\\' && p + 1 < content.length) {
                    p += 2
                } else {
                    p += 1
                }
            }
        }
        // 跳过空白
        while (p < content.length && (isBlank(UInt8(content[Int64(p)])) || content[Int64(p)] == '\n' || content[Int64(p)] == '\r')) {
            p += 1
        }
        // 可选标题
        if (p < content.length && (content[Int64(p)] == '"' || content[Int64(p)] == '\'' || content[Int64(p)] == '(')) {
            let closeCh: UInt8 = if (content[Int64(p)] == '(') ')'.toUInt8() else UInt8(content[Int64(p)])
            p += 1
            while (p < content.length && UInt8(content[Int64(p)]) != closeCh) {
                if (content[Int64(p)] == '\\' && p + 1 < content.length) {
                    p += 2
                } else {
                    p += 1
                }
            }
            if (p < content.length) {
                p += 1
            }
        }
        // 跳过空白
        while (p < content.length && (isBlank(UInt8(content[Int64(p)])) || content[Int64(p)] == '\n' || content[Int64(p)] == '\r')) {
            p += 1
        }
        if (p < content.length && content[Int64(p)] == ')') {
            return BracketLinkResult(true, labelEnd, p + 1)
        }
    }

    // 引用链接: ][...]
    if (content[Int64(pos)] == '[') {
        var p = pos + 1
        while (p < content.length && content[Int64(p)] != ']') {
            if (content[Int64(p)] == '[') {
                break
            }
            if (content[Int64(p)] == '\\' && p + 1 < content.length) {
                p += 2
            } else {
                p += 1
            }
        }
        if (p < content.length && content[Int64(p)] == ']') {
            let refLabel = if (p > pos + 1) content.substring(pos + 1, p) else content.substring(start + 1, labelEnd)
            if (lookupRefDef(parser, refLabel) != None) {
                return BracketLinkResult(true, labelEnd, p + 1)
            }
        }
    }

    // 快捷引用
    let innerLabel = content.substring(start + 1, labelEnd)
    if (lookupRefDef(parser, innerLabel) != None) {
        return BracketLinkResult(true, labelEnd, labelEnd + 1)
    }

    return BracketLinkResult(false, labelEnd, labelEnd + 1)
}

/// 检查链接标签是否包含内部链接结构
/// 用于执行 "链接不能包含其他链接" 规则 (CommonMark §6.7)
public func labelContainsLink(parser: Parser, label: String): Bool {
    var pos: Int64 = 0
    while (pos < label.length) {
        if (label[pos] == '\\' && pos + 1 < label.length) {
            pos += 2
            continue
        }
        // 跳过代码跨度
        if (label[pos] == '`') {
            let count = countBackticks(label, pos)
            let endOpt = findCodeSpanEnd(parser, label, pos + count, count)
            if (endOpt != None) {
                pos = endOpt.get() + count
                continue
            }
        }
        // 跳过 HTML 标签和自动链接
        if (label[pos] == '<' && !parser.flags.no_html_spans) {
            let tagEnd = findHtmlTag(parser, label, pos)
            if (tagEnd != None) {
                pos = tagEnd.get()
                continue
            }
            let al = findAutolink(parser, label, pos)
            if (al != None) {
                pos = al.get().end_pos
                continue
            }
        }
        if (label[pos] == '[') {
            // 跳过图片 (![]...) — 图片允许在链接内
            let isInnerImage = pos > 0 && label[pos - 1] == '!'
            // 尝试找到匹配的 ] 并检查链接语法
            let inner = tryMatchBracketLink(parser, label, pos)
            if (inner.is_link && !isInnerImage) {
                return true
            }
            if (inner.link_end > pos) {
                // 跳过整个结构（包括图片的 (url) 或 [ref]）
                pos = inner.link_end
                continue
            }
        }
        pos += 1
    }
    return false
}

/// 处理 Wiki 链接: [[destination]] 或 [[destination|label]]
public func processWikiLink(parser: Parser, content: String, start: Int64): ?Int64 {
    // start 指向第一个 '['，下一个字符也是 '['
    var pos = start + 2

    // 找到关闭的 ']]'，检查约束
    let innerStart = pos
    var pipePos: ?Int64 = None
    var bracketDepth: UInt32 = 0

    while (pos < content.length) {
        if (content[pos] == '\n' || content[pos] == '\r') {
            return None
        }
        if (content[pos] == '[') {
            bracketDepth += 1
        } else if (content[pos] == ']') {
            if (bracketDepth > 0) {
                bracketDepth -= 1
            } else if (pos + 1 < content.length && content[pos + 1] == ']') {
                break
            } else {
                // 单独的 ] 没有匹配的 [，不是有效关闭
                return None
            }
        } else if (content[pos] == '|' && pipePos == None && bracketDepth == 0) {
            pipePos = pos
        }
        pos += 1
    }

    // 必须以 ]] 结束
    if (pos >= content.length || content[pos] != ']') {
        return None
    }

    let innerEnd = pos

    // 确定目标和标签
    let target = if (pipePos != None) content.substring(innerStart, pipePos.get()) else content.substring(innerStart, innerEnd)
    let wlabel = if (pipePos != None) content.substring(pipePos.get() + 1, innerEnd) else content.substring(innerStart, innerEnd)

    // 目标不得超过 100 个字符
    if (target.length > 100) {
        return None
    }

    // 渲染 Wiki 链接
    parser.renderer.enterSpan(SpanType.wikilink, SpanDetail().also { it.href = target })
    processInlineContent(parser, wlabel, 0)
    parser.renderer.leaveSpan(SpanType.wikilink)

    return pos + 2 // 跳过两个 ']'
}

/// 渲染引用链接/图片，给定已解析的引用定义
public func renderRefLink(parser: Parser, labelContent: String, ref: RefDef, isImage: Bool): Unit {
    if (parser.image_nesting_level > 0) {
        // 在图片 alt 文本内 — 仅发出文本，不发出 HTML 标签
        processInlineContent(parser, labelContent, 0)
    } else if (isImage) {
        parser.renderer.enterSpan(SpanType.img, SpanDetail().also {
            it.href = ref.dest; it.title = ref.title
        })
        parser.image_nesting_level += 1
        processInlineContent(parser, labelContent, 0)
        parser.image_nesting_level -= 1
        parser.renderer.leaveSpan(SpanType.img)
    } else {
        parser.renderer.enterSpan(SpanType.a, SpanDetail().also {
            it.href = ref.dest; it.title = ref.title
        })
        parser.link_nesting_level += 1
        processInlineContent(parser, labelContent, 0)
        parser.link_nesting_level -= 1
        parser.renderer.leaveSpan(SpanType.a)
    }
}

/// 自动链接查找结果
public class AutolinkFindResult {
    public var end_pos: Int64 = 0
    public var is_email: Bool = false
    public init() {}
    public init(end_pos: Int64, is_email: Bool) {
        this.end_pos = end_pos
        this.is_email = is_email
    }
}

/// 查找自动链接（尖括号形式）
public func findAutolink(parser: Parser, content: String, start: Int64): ?AutolinkFindResult {
    if (start + 1 >= content.length) {
        return None
    }

    let pos = start + 1

    // 检查 URI 自动链接: scheme://...
    if (isAlpha(UInt8(content[pos]))) {
        var schemeEnd = pos
        while (schemeEnd < content.length && (isAlphaNum(UInt8(content[Int64(schemeEnd)])) ||
               content[Int64(schemeEnd)] == '+' || content[Int64(schemeEnd)] == '-' || content[Int64(schemeEnd)] == '.')) {
            schemeEnd += 1
        }
        let schemeLen = schemeEnd - pos
        if (schemeLen >= 2 && schemeLen <= 32 && schemeEnd < content.length && content[Int64(schemeEnd)] == ':') {
            // URI 自动链接
            var uriEnd = schemeEnd + 1
            while (uriEnd < content.length && content[Int64(uriEnd)] != '>' && !isWhitespace(UInt8(content[Int64(uriEnd)]))) {
                uriEnd += 1
            }
            if (uriEnd < content.length && content[Int64(uriEnd)] == '>') {
                return AutolinkFindResult(uriEnd + 1, false)
            }
        }

        // 检查电子邮件自动链接
        var emailPos = pos
        // 用户名部分
        while (emailPos < content.length && (isAlphaNum(UInt8(content[Int64(emailPos)])) ||
               content[Int64(emailPos)] == '.' || content[Int64(emailPos)] == '-' ||
               content[Int64(emailPos)] == '_' || content[Int64(emailPos)] == '+')) {
            emailPos += 1
        }
        if (emailPos < content.length && content[Int64(emailPos)] == '@' && emailPos > pos) {
            emailPos += 1
            // 域名部分: 由 '.' 分隔的标签，每个 1-63 字符，字母数字或连字符
            let domainStart = emailPos
            var labelLen: UInt32 = 0
            var dotCount: UInt32 = 0
            var validDomain = true
            while (emailPos < content.length && (isAlphaNum(UInt8(content[Int64(emailPos)])) ||
                   content[Int64(emailPos)] == '.' || content[Int64(emailPos)] == '-')) {
                if (content[Int64(emailPos)] == '.') {
                    if (labelLen == 0) {
                        validDomain = false
                        break
                    }
                    labelLen = 0
                    dotCount += 1
                } else {
                    labelLen += 1
                    if (labelLen > 63) {
                        validDomain = false
                        break
                    }
                }
                emailPos += 1
            }
            if (validDomain && emailPos < content.length && content[Int64(emailPos)] == '>' &&
                emailPos > domainStart && labelLen > 0 && dotCount > 0 &&
                isAlphaNum(UInt8(content[Int64(emailPos - 1)]))) {
                return AutolinkFindResult(emailPos + 1, true)
            }
        }
    }

    return None
}

/// 渲染自动链接
public func renderAutolink(parser: Parser, url: String, isEmail: Bool): Unit {
    parser.renderer.enterSpan(SpanType.a, SpanDetail().also {
        it.href = url; it.autolink = true; it.autolink_email = isEmail
    })
    emitText(parser, TextType.normal, url)
    parser.renderer.leaveSpan(SpanType.a)
}
