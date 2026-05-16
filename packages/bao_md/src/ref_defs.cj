// Reference definition parsing
// Translated from: src/md/ref_defs.zig
package bao_md

import std.collection.*

// ============================================================================
// Label normalization
// ============================================================================

public func normalizeLabel(parser: Parser, raw: String): String {
    var result = StringBuilder()
    var in_ws = true
    var i: Int64 = 0

    while (i < raw.size) {
        let c = UInt8(raw[i])
        if (c == UInt8(0x20) || c == UInt8(0x09) || c == UInt8(0x0A) || c == UInt8(0x0D)) {
            if (!in_ws && result.size > 0) {
                result.append(' ')
                in_ws = true
            }
            i += 1
        } else if (c >= 0x80) {
            let decoded = decodeUtf8(raw, i)
            let fold = caseFold(decoded.codepoint)
            for (j in 0..Int64(fold.n_codepoints)) {
                result.append(encodeUtf8(fold.codepoints[Int64(j)]))
            }
            in_ws = false
            i += decoded.len
        } else {
            var tmp = ArrayList<UInt8>()
            tmp.add(toLower(c))
            result.append(String.fromUtf8(tmp.toArray()))
            in_ws = false
            i += 1
        }
    }

    var s = result.toString()
    while (s.size > 0 && UInt8(s[s.size - 1]) == UInt8(0x20)) {
        s = s[0..s.size - 1]
    }
    return s
}

// ============================================================================
// Reference definition lookup
// ============================================================================

public func lookupRefDef(parser: Parser, raw_label: String): ?RefDef {
    if (raw_label.size == 0) {
        return None
    }
    let normalized = normalizeLabel(parser, raw_label)
    if (normalized.size == 0) {
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
// Reference definition parsing
// ============================================================================

public class RefDefResult {
    public var end_pos: Int64 = 0
    public var label: String = ""
    public var dest: String = ""
    public var title: String = ""
    public init() {}
}

public func parseRefDef(parser: Parser, text: String, pos: Int64): ?RefDefResult {
    var p = pos

    if (p >= text.size || UInt8(text[p]) != UInt8(0x5B)) {
        return None
    }
    p += 1

    let label_start = p
    var label_len: Int64 = 0
    while (p < text.size && UInt8(text[p]) != UInt8(0x5D)) {
        if (UInt8(text[p]) == UInt8(0x5B)) {
            return None
        }
        if (UInt8(text[p]) == UInt8(0x5C) && p + 1 < text.size) {
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
    let label = text[label_start..p]
    if (label.size == 0) {
        return None
    }
    p += 1

    if (p >= text.size || UInt8(text[p]) != UInt8(0x3A)) {
        return None
    }
    p += 1

    p = skipRefDefWhitespace(text, p)

    if (let Some(dest_result) <- parseRefDefDest(text, p)) {
        p = dest_result.end_pos

        let pos_after_dest = p
        let p_before_title_ws = p
        p = skipRefDefWhitespace(text, p)
        let had_newline_before_title = text[p_before_title_ws..p].contains("\n")

        var title = ""
        var had_whitespace_before_title = false
        if (p < text.size && (UInt8(text[p]) == UInt8(0x22) || UInt8(text[p]) == UInt8(0x27) || UInt8(text[p]) == UInt8(0x28))) {
            had_whitespace_before_title = (p > pos_after_dest)
            if (had_whitespace_before_title) {
                if (let Some(title_result) <- parseRefDefTitle(text, p)) {
                    var after_title = title_result.end_pos
                    while (after_title < text.size && (UInt8(text[after_title]) == UInt8(0x20) || UInt8(text[after_title]) == UInt8(0x09))) {
                        after_title += 1
                    }
                    if (after_title >= text.size || UInt8(text[after_title]) == UInt8(0x0A)) {
                        title = title_result.title
                        p = after_title
                        if (p < text.size && UInt8(text[p]) == UInt8(0x0A)) {
                            p += 1
                        }
                        let result = RefDefResult()
                        result.end_pos = p
                        result.label = label
                        result.dest = dest_result.dest
                        result.title = title
                        return result
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

        p = pos_after_dest
        while (p < text.size && (UInt8(text[p]) == UInt8(0x20) || UInt8(text[p]) == UInt8(0x09))) {
            p += 1
        }
        if (p < text.size && UInt8(text[p]) != UInt8(0x0A)) {
            return None
        }
        if (p < text.size && UInt8(text[p]) == UInt8(0x0A)) {
            p += 1
        }

        let result = RefDefResult()
        result.end_pos = p
        result.label = label
        result.dest = dest_result.dest
        result.title = title
        return result
    }

    return None
}

public func skipRefDefWhitespace(text: String, start: Int64): Int64 {
    var p = start
    while (p < text.size && (UInt8(text[p]) == UInt8(0x20) || UInt8(text[p]) == UInt8(0x09))) {
        p += 1
    }
    if (p < text.size && UInt8(text[p]) == UInt8(0x0A)) {
        p += 1
        while (p < text.size && (UInt8(text[p]) == UInt8(0x20) || UInt8(text[p]) == UInt8(0x09))) {
            p += 1
        }
    }
    return p
}

public class DestResult {
    public var dest: String = ""
    public var end_pos: Int64 = 0
    public init() {}
}

public func parseRefDefDest(text: String, start: Int64): ?DestResult {
    var p = start
    if (p >= text.size) {
        return None
    }

    if (UInt8(text[p]) == UInt8(0x3C)) {
        p += 1
        let dest_start = p
        while (p < text.size && UInt8(text[p]) != UInt8(0x3E) && UInt8(text[p]) != UInt8(0x0A)) {
            if (UInt8(text[p]) == UInt8(0x5C) && p + 1 < text.size) {
                p += 2
            } else {
                p += 1
            }
        }
        if (p >= text.size || UInt8(text[p]) != UInt8(0x3E)) {
            return None
        }
        let dest = text[dest_start..p]
        p += 1
        let result = DestResult()
        result.dest = dest
        result.end_pos = p
        return result
    } else {
        let dest_start = p
        var paren_depth: UInt32 = 0
        while (p < text.size && !isWhitespace(UInt8(text[p]))) {
            if (UInt8(text[p]) == UInt8(0x28)) {
                paren_depth += 1
            } else if (UInt8(text[p]) == UInt8(0x29)) {
                if (paren_depth == 0) {
                    break
                }
                paren_depth -= 1
            }
            if (UInt8(text[p]) == UInt8(0x5C) && p + 1 < text.size) {
                p += 2
            } else {
                p += 1
            }
        }
        if (p == dest_start) {
            return None
        }
        let result = DestResult()
        result.dest = text[dest_start..p]
        result.end_pos = p
        return result
    }
}

public class TitleResult {
    public var title: String = ""
    public var end_pos: Int64 = 0
    public init() {}
}

public func parseRefDefTitle(text: String, start: Int64): ?TitleResult {
    var p = start
    if (p >= text.size) {
        return None
    }

    let open_char = UInt8(text[p])
    let close_char: UInt8 = if (open_char == UInt8(0x22)) {
        open_char
    } else if (open_char == UInt8(0x27)) {
        open_char
    } else if (open_char == UInt8(0x28)) {
        UInt8(0x29)
    } else {
        return None
    }
    p += 1
    let title_start = p

    while (p < text.size && UInt8(text[p]) != close_char) {
        if (UInt8(text[p]) == UInt8(0x5C) && p + 1 < text.size) {
            p += 2
        } else {
            if (open_char == UInt8(0x28) && UInt8(text[p]) == UInt8(0x28)) {
                return None
            }
            p += 1
        }
    }
    if (p >= text.size) {
        return None
    }
    let title = text[title_start..p]
    p += 1
    let result = TitleResult()
    result.title = title
    result.end_pos = p
    return result
}
