// 严格翻译自: src/md/ref_defs.cj
// 引用定义解析
package bao_md

// ============================================================================
// 标签规范化
// ============================================================================

/// 规范化链接标签：折叠空白运行到单个空格，去除首尾空白，大小写折叠
public func normalizeLabel(parser: Parser, raw: String): String {
    var result = StringBuilder()
    var in_ws = true
    var i: Int64 = 0

    while (i < raw.size) {
        let c = UInt8(raw[i])
        if (c == ' '.toUInt8() || c == '\t'.toUInt8() || c == '\n'.toUInt8() || c == '\r'.toUInt8()) {
            if (!in_ws && result.size > 0) {
                result.append(' ')
                in_ws = true
            }
            i += 1
        } else if (c >= 0x80) {
            // 多字节 UTF-8: 解码，大小写折叠，重新编码
            let decoded = decodeUtf8(raw, i)
            let fold = caseFold(decoded.codepoint)
            for (j in 0..Int64(fold.n_codepoints)) {
                result.append(encodeUtf8(fold.codepoints[Int64(j)]))
            }
            in_ws = false
            i += decoded.len
        } else {
            result.append(Char(toLower(c)))
            in_ws = false
            i += 1
        }
    }

    // 修剪尾部空格
    var s = result.toString()
    while (s.size > 0 && s[s.size - 1] == ' ') {
        s = s.substring(0, s.size - 1)
    }
    return s
}

// ============================================================================
// 引用定义查找
// ============================================================================

/// 通过标签查找引用定义（不区分大小写，空白规范化）
public func lookupRefDef(parser: Parser, raw_label: String): ?RefDef {
    if (raw_label.isEmpty) {
        return None
    }
    let normalized = normalizeLabel(parser, raw_label)
    if (normalized.isEmpty) {
        return None
    }
    for (rd in parser.ref_defs) {
        if (rd.label == normalized) {
            return rd
        }
    }
    return None
}

// ============================================================================
// 引用定义解析
// ============================================================================

/// 引用定义解析结果
public class RefDefResult {
    public var end_pos: Int64 = 0
    public var label: String = ""
    public var dest: String = ""
    public var title: String = ""
    public init() {}
}

/// 尝试从合并的段落文本的位置 `pos` 解析链接引用定义
public func parseRefDef(parser: Parser, text: String, pos: Int64): ?RefDefResult {
    var p = pos

    // 必须以 [ 开头
    if (p >= text.size || text[p] != '[') {
        return None
    }
    p += 1

    // 解析标签
    let label_start = p
    var label_len: Int64 = 0
    while (p < text.size && text[p] != ']') {
        if (text[p] == '[') {
            return None
        }
        if (text[p] == '\\' && p + 1 < text.size) {
            p += 2
            label_len += 2
        } else {
            p += 1
            label_len += 1
        }
        if (label_len > 999) {
            return None
        }
    }
    if (p >= text.size) {
        return None
    }
    let label = text.substring(label_start, p)
    if (label.isEmpty) {
        return None
    }
    p += 1

    // 必须后跟 :
    if (p >= text.size || text[p] != ':') {
        return None
    }
    p += 1

    p = skipRefDefWhitespace(text, p)

    // 解析目标
    let dest_result = parseRefDefDest(text, p) ?: return None
    p = dest_result.end_pos

    let pos_after_dest = p
    let p_before_title_ws = p
    p = skipRefDefWhitespace(text, p)
    let had_newline_before_title = text.substring(p_before_title_ws, p).contains('\n')

    // 解析可选标题
    var title = ""
    var had_whitespace_before_title = false
    if (p < text.size && (text[p] == '"' || text[p] == '\'' || text[p] == '(')) {
        had_whitespace_before_title = (p > pos_after_dest)
        if (had_whitespace_before_title) {
            if (let Some(title_result) <- parseRefDefTitle(text, p)) {
                var after_title = title_result.end_pos
                while (after_title < text.size && (text[after_title] == ' ' || text[after_title] == '\t')) {
                    after_title += 1
                }
                if (after_title >= text.size || text[after_title] == '\n') {
                    title = title_result.title
                    p = after_title
                    if (p < text.size && text[p] == '\n') {
                        p += 1
                    }
                    return RefDefResult().also {
                        it.end_pos = p
                        it.label = label
                        it.dest = dest_result.dest
                        it.title = title
                    }
                }
                if (!had_newline_before_title) {
                    return None
                }
            } else {
                if (!had_newline_before_title) {
                    return None
                }
            }
        }
    }

    // 无标题: 回退到目标之后
    p = pos_after_dest
    while (p < text.size && (text[p] == ' ' || text[p] == '\t')) {
        p += 1
    }
    if (p < text.size && text[p] != '\n') {
        return None
    }
    if (p < text.size && text[p] == '\n') {
        p += 1
    }

    return RefDefResult().also {
        it.end_pos = p
        it.label = label
        it.dest = dest_result.dest
        it.title = title
    }
}

/// 跳过引用定义空白
public func skipRefDefWhitespace(text: String, start: Int64): Int64 {
    var p = start
    while (p < text.size && (text[p] == ' ' || text[p] == '\t')) {
        p += 1
    }
    if (p < text.size && text[p] == '\n') {
        p += 1
        while (p < text.size && (text[p] == ' ' || text[p] == '\t')) {
            p += 1
        }
    }
    return p
}

/// 目标解析结果
public class DestResult {
    public var dest: String = ""
    public var end_pos: Int64 = 0
    public init() {}
}

/// 解析引用定义目标
public func parseRefDefDest(text: String, start: Int64): ?DestResult {
    var p = start
    if (p >= text.size) {
        return None
    }

    if (text[p] == '<') {
        // 尖括号目标
        p += 1
        let dest_start = p
        while (p < text.size && text[p] != '>' && text[p] != '\n') {
            if (text[p] == '\\' && p + 1 < text.size) {
                p += 2
            } else {
                p += 1
            }
        }
        if (p >= text.size || text[p] != '>') {
            return None
        }
        let dest = text.substring(dest_start, p)
        p += 1
        return DestResult().also { it.dest = dest; it.end_pos = p }
    } else {
        // 裸目标 — 平衡括号
        let dest_start = p
        var paren_depth: UInt32 = 0
        while (p < text.size && !isWhitespace(UInt8(text[p]))) {
            if (text[p] == '(') {
                paren_depth += 1
            } else if (text[p] == ')') {
                if (paren_depth == 0) {
                    break
                }
                paren_depth -= 1
            }
            if (text[p] == '\\' && p + 1 < text.size) {
                p += 2
            } else {
                p += 1
            }
        }
        if (p == dest_start) {
            return None
        }
        return DestResult().also { it.dest = text.substring(dest_start, p); it.end_pos = p }
    }
}

/// 标题解析结果
public class TitleResult {
    public var title: String = ""
    public var end_pos: Int64 = 0
    public init() {}
}

/// 解析引用定义标题
public func parseRefDefTitle(text: String, start: Int64): ?TitleResult {
    var p = start
    if (p >= text.size) {
        return None
    }

    let open_char = UInt8(text[p])
    let close_char: UInt8 = match (open_char) {
        case '"', '\'' => open_char
        case '(' => ')'.toUInt8()
        case _ => return None
    }
    p += 1
    let title_start = p

    while (p < text.size && UInt8(text[p]) != close_char) {
        if (text[p] == '\\' && p + 1 < text.size) {
            p += 2
        } else {
            if (open_char == '('.toUInt8() && text[p] == '(') {
                return None
            }
            p += 1
        }
    }
    if (p >= text.size) {
        return None
    }
    let title = text.substring(title_start, p)
    p += 1
    return TitleResult().also { it.title = title; it.end_pos = p }
}
