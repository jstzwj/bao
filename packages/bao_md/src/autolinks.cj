// 严格翻译自: src/md/autolinks.zig
// 自动链接和宽松自动链接检测
package bao_md

// ============================================================================
// 列表标记检测
// ============================================================================

/// 检查字符是否为列表项目符号
public func isListBullet(c: UInt8): Bool {
    return c == UInt8(0x2D) || c == UInt8(0x2B) || c == UInt8(0x2A)
}

/// 检查字符是否为列表项标记
public func isListItemMark(c: UInt8): Bool {
    return c == UInt8(0x2D) || c == UInt8(0x2B) || c == UInt8(0x2A) ||
           c == UInt8(0x2E) || c == UInt8(0x29)
}

// ============================================================================
// 自动链接结果
// ============================================================================

/// 自动链接查找结果
public class AutolinkResult {
    public var beg: Int64 = 0
    public var end: Int64 = 0
    public init() {}
    public init(beg: Int64, end: Int64) {
        this.beg = beg
        this.end = end
    }
}

/// 检查自动链接边界处的强调字符是否已解析
public func isEmphBoundaryResolved(content: String, al: AutolinkResult, resolved: Array<EmphDelim>): Bool {
    // 检查左边界
    if (al.beg > 0) {
        let prev = UInt8(content[al.beg - 1])
        if (prev == UInt8(0x2A) || prev == UInt8(0x5F) || prev == UInt8(0x7E)) {
            if (!checkLeftBoundary(content, al.beg, false)) {
                var found_resolved = false
                for (d in resolved) {
                    if (d.pos <= al.beg - 1 && al.beg - 1 < d.pos + d.count &&
                        (d.open_count + d.close_count > 0)) {
                        found_resolved = true
                        break
                    }
                }
                if (!found_resolved) {
                    return false
                }
            }
        }
    }
    // 检查右边界
    if (al.end < content.size) {
        let next = UInt8(content[al.end])
        if (next == UInt8(0x2A) || next == UInt8(0x5F) || next == UInt8(0x7E)) {
            if (!checkRightBoundary(content, al.end, false)) {
                var found_resolved = false
                for (d in resolved) {
                    if (d.pos <= al.end && al.end < d.pos + d.count &&
                        (d.open_count + d.close_count > 0)) {
                        found_resolved = true
                        break
                    }
                }
                if (!found_resolved) {
                    return false
                }
            }
        }
    }
    return true
}

// ============================================================================
// URL 组件扫描
// ============================================================================

/// URL 组件扫描结果
public class ScanResult {
    public var end: Int64 = 0
    public var ok: Bool = false
    public init() {}
    public init(end: Int64, ok: Bool) {
        this.end = end
        this.ok = ok
    }
}

/// 扫描 URL 组件
public func scanUrlComponent(content: String, start: Int64, start_char: UInt8,
                              delim_char: UInt8, allowed_nonalnum: String,
                              min_components: UInt32, optional_end_char: UInt8): ScanResult {
    var pos = start
    var n_components: UInt32 = 0

    if (start_char != 0) {
        if (pos >= content.size || UInt8(content[pos]) != start_char) {
            return ScanResult(pos, min_components == 0)
        }
        if (min_components > 0 && (pos + 1 >= content.size || !isAlphaNum(UInt8(content[pos + 1])))) {
            return ScanResult(pos, min_components == 0)
        }
        pos += 1
    }

    while (pos < content.size) {
        let c = UInt8(content[pos])
        if (isAlphaNum(c)) {
            if (n_components == 0) {
                n_components = 1
            }
            pos += 1
        } else if (isInSet(c, allowed_nonalnum) &&
                   ((pos > 0 && (isAlphaNum(UInt8(content[pos - 1])) ||
                                  UInt8(content[pos - 1]) == UInt8(0x29) ||
                                  isInSet(UInt8(content[pos - 1]), allowed_nonalnum))) ||
                                  c == UInt8(0x28)) &&
                   ((pos + 1 < content.size && (isAlphaNum(UInt8(content[pos + 1])) ||
                                                   UInt8(content[pos + 1]) == UInt8(0x28) ||
                                                   isInSet(UInt8(content[pos + 1]), allowed_nonalnum))) ||
                                   c == UInt8(0x29))) {
            if (c == delim_char) {
                n_components += 1
            }
            pos += 1
        } else {
            break
        }
    }

    if (pos < content.size && optional_end_char != 0 && UInt8(content[pos]) == optional_end_char) {
        pos += 1
    }

    if (n_components < min_components) {
        return ScanResult(pos, false)
    }

    return ScanResult(pos, true)
}

func isInSet(c: UInt8, set: String): Bool {
    for (s in set) {
        if (c == UInt8(s)) {
            return true
        }
    }
    return false
}

// ============================================================================
// 边界检查
// ============================================================================

/// 检查宽松自动链接的左边界
public func checkLeftBoundary(content: String, pos: Int64, allow_emph: Bool): Bool {
    if (pos == 0) {
        return true
    }
    return match (UInt8(content[pos - 1])) {
        case ' ' => true
        case '\t' => true
        case '\n' => true
        case '\r' => true
        case 0x0B => true
        case 0x0C => true
        case '(' => true
        case '{' => true
        case '[' => true
        case '*' => allow_emph
        case '_' => allow_emph
        case '~' => allow_emph
        case _ => false
    }
}

/// 检查宽松自动链接的右边界
public func checkRightBoundary(content: String, pos: Int64, allow_emph: Bool): Bool {
    if (pos >= content.size) {
        return true
    }
    return match (UInt8(content[pos])) {
        case ' ' => true
        case '\t' => true
        case '\n' => true
        case '\r' => true
        case 0x0B => true
        case 0x0C => true
        case ')' => true
        case '}' => true
        case ']' => true
        case '<' => true
        case '.' => true
        case '!' => true
        case '?' => true
        case ',' => true
        case ';' => true
        case '&' => true
        case '*' => allow_emph
        case '_' => allow_emph
        case '~' => allow_emph
        case _ => false
    }
}

// ============================================================================
// 宽松自动链接检测
// ============================================================================

/// 在给定位置检测宽松自动链接
public func findPermissiveAutolink(content: String, pos: Int64, allow_emph: Bool): ?AutolinkResult {
    if (pos >= content.size) {
        return None
    }
    let c = UInt8(content[pos])

    if (c == UInt8(0x3A)) {
        // URL 自动链接: http://, https://, ftp://
        let schemes: Array<String> = ["http", "https", "ftp"]
        let suffixes: Array<String> = ["//", "//", "//"]

        for (i in 0..schemes.size) {
            let slen = schemes[Int64(i)].size
            let suflen = suffixes[Int64(i)].size
            if (pos >= slen && pos + 1 + suflen < content.size) {
                if (asciiCaseEql(content[pos - slen..pos], schemes[Int64(i)]) &&
                    content[pos + 1..pos + 1 + suflen] == suffixes[Int64(i)]) {
                    let beg = pos - slen
                    if (!checkLeftBoundary(content, beg, allow_emph)) {
                        continue
                    }
                    var end = pos + 1 + suflen
                    let host = scanUrlComponent(content, end, 0, UInt8(0x2E), ".-_", 2, 0)
                    if (!host.ok) {
                        continue
                    }
                    end = host.end
                    let path = scanUrlComponent(content, end, UInt8(0x2F), UInt8(0x2F), "/.-_~*+%", 0, UInt8(0x2F))
                    end = path.end
                    let query = scanUrlComponent(content, end, UInt8(0x3F), UInt8(0x26), "&.-+_=()~*%", 1, 0)
                    end = query.end
                    let frag = scanUrlComponent(content, end, UInt8(0x23), 0, ".-+_~*%", 1, 0)
                    end = frag.end
                    end = postProcessAutolinkEnd(content, beg, end)
                    if (!checkRightBoundary(content, end, allow_emph)) {
                        continue
                    }
                    return AutolinkResult(beg, end)
                }
            }
        }
    } else if (c == UInt8(0x40)) {
        // 电子邮件自动链接
        if (pos == 0 || pos + 3 >= content.size) {
            return None
        }
        if (!isAlphaNum(UInt8(content[pos - 1])) || !isAlphaNum(UInt8(content[pos + 1]))) {
            return None
        }

        var beg = pos
        while (beg > 0) {
            if (isAlphaNum(UInt8(content[beg - 1]))) {
                beg -= 1
            } else if (beg >= 2 && isAlphaNum(UInt8(content[beg - 2])) &&
                       isInSet(UInt8(content[beg - 1]), ".-_+") &&
                       isAlphaNum(UInt8(content[beg]))) {
                beg -= 1
            } else {
                break
            }
        }
        if (beg == pos) {
            return None
        }
        if (!checkLeftBoundary(content, beg, allow_emph)) {
            return None
        }

        let host = scanUrlComponent(content, pos + 1, 0, UInt8(0x2E), ".-_", 2, 0)
        if (!host.ok) {
            return None
        }
        let end = host.end
        if (!checkRightBoundary(content, end, allow_emph)) {
            return None
        }
        return AutolinkResult(beg, end)
    } else if (c == UInt8(0x2E)) {
        // WWW 自动链接
        if (pos < 3) {
            return None
        }
        if (!asciiCaseEql(content[pos - 3..pos], "www")) {
            return None
        }

        let beg = pos - 3
        if (!checkLeftBoundary(content, beg, allow_emph)) {
            return None
        }

        var end = pos + 1
        let host = scanUrlComponent(content, end, 0, UInt8(0x2E), ".-_", 1, 0)
        if (!host.ok) {
            return None
        }
        end = host.end
        let path = scanUrlComponent(content, end, UInt8(0x2F), UInt8(0x2F), "/.-_~*+%", 0, UInt8(0x2F))
        end = path.end
        let query = scanUrlComponent(content, end, UInt8(0x3F), UInt8(0x26), "&.-+_=()~*%", 1, 0)
        end = query.end
        let frag = scanUrlComponent(content, end, UInt8(0x23), 0, ".-+_~*%", 1, 0)
        end = frag.end
        end = postProcessAutolinkEnd(content, beg, end)
        if (!checkRightBoundary(content, end, allow_emph)) {
            return None
        }
        return AutolinkResult(beg, end)
    }

    return None
}

/// GFM 后处理：修剪尾部不平衡的 `)` 和类实体后缀
func postProcessAutolinkEnd(content: String, beg: Int64, end_in: Int64): Int64 {
    var end = end_in

    // 修剪尾部类实体后缀
    if (end > beg && UInt8(content[end - 1]) == UInt8(0x3B)) {
        var j = end - 2
        while (j > beg && isAlphaNum(UInt8(content[j]))) {
            j -= 1
        }
        if (j >= beg && UInt8(content[j]) == UInt8(0x26)) {
            end = j
        }
    }
    if (end < content.size && UInt8(content[end]) == UInt8(0x3B) && end > beg) {
        var j = end - 1
        while (j > beg && isAlphaNum(UInt8(content[j]))) {
            j -= 1
        }
        if (j >= beg && UInt8(content[j]) == UInt8(0x26)) {
            end = j
        }
    }

    // 修剪尾部不平衡的 `)`
    while (end > beg && UInt8(content[end - 1]) == UInt8(0x29)) {
        var open_count: Int32 = 0
        var close_count: Int32 = 0
        for (i in beg..end) {
            if (UInt8(content[i]) == UInt8(0x28)) {
                open_count += 1
            }
            if (UInt8(content[i]) == UInt8(0x29)) {
                close_count += 1
            }
        }
        if (close_count > open_count) {
            end -= 1
        } else {
            break
        }
    }

    return end
}
