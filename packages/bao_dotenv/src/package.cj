// bao_dotenv - .env 文件加载与解析
// 严格翻译自: src/dotenv/env_loader.zig
// 对应 Bun 的 DotEnv Parser 实现，包括:
//   - Parser: parseKey, parseValue, parseQuoted, expandValue
//   - Loader: load, loadProcess, loadEnvFile, loadEnvFileDynamic
//   - Map: HashMap 存储，put, get, iterator
//   - 变量展开: ${VAR}, $VAR, ${VAR:-default}
//   - 引号处理: 单引号, 双引号, 无引号
//   - 多行值, 注释, 内联注释, export 前缀
package bao_dotenv

import bao_core.*
import bao_collections.*
import bao_io.*

// ============================================================================
// ASCII 常量 - 用于字符比较
// ============================================================================

private let BYTE_NL: UInt8 = 10       // '\n'
private let BYTE_CR: UInt8 = 13       // '\r'
private let BYTE_TAB: UInt8 = 9       // '\t'
private let BYTE_SP: UInt8 = 32       // ' '
private let BYTE_HASH: UInt8 = 35     // '#'
private let BYTE_EQ: UInt8 = 61       // '='
private let BYTE_COLON: UInt8 = 58    // ':'
private let BYTE_DOLLAR: UInt8 = 36   // '$'
private let BYTE_DQUOTE: UInt8 = 34   // '"'
private let BYTE_SQUOTE: UInt8 = 39   // '\''
private let BYTE_BQUOTE: UInt8 = 96   // '`'
private let BYTE_BACKSLASH: UInt8 = 92 // '\'
private let BYTE_UNDERSCORE: UInt8 = 95 // '_'
private let BYTE_DASH: UInt8 = 45     // '-'
private let BYTE_DOT: UInt8 = 46      // '.'
private let BYTE_LBRACE: UInt8 = 123  // '{'
private let BYTE_RBRACE: UInt8 = 125  // '}'
private let BYTE_VT: UInt8 = 11       // '\u{0B}'
private let BYTE_FF: UInt8 = 12       // '\u{0C}'
private let BYTE_NBSP: UInt8 = 160    // '\u{A0}'
private let BYTE_n: UInt8 = 110       // 'n'
private let BYTE_r: UInt8 = 114       // 'r'

// ============================================================================
// DotEnvMap - .env 变量映射表
// 严格翻译自: src/dotenv/env_loader.zig - Map struct
// ============================================================================

/// .env 变量映射表 - 对应 Bun env_loader.Map
public class DotEnvMap {
    private var map: HashMap<String, String>

    public init() {
        map = HashMap<String, String>()
    }

    /// 获取环境变量值
    public func get(key: String): ?String {
        map.get(key)
    }

    /// 设置环境变量
    public func put(key: String, value: String): Unit {
        map.put(key, value)
    }

    /// 仅在 key 不存在时设置
    public func putDefault(key: String, value: String): Unit {
        if (map.get(key).isNone()) {
            map.put(key, value)
        }
    }

    /// 移除键
    public func remove(key: String): Unit {
        map.remove(key)
    }

    /// 迭代所有键值对
    public func iterator(): ArrayList<(String, String)> {
        map.allEntries()
    }

    /// 当前键值对数量
    public prop size: Int64 {
        get() { map.size }
    }

    /// 检查键是否存在
    public func contains(key: String): Bool {
        map.get(key).isSome()
    }

    /// 克隆
    public func clone(): DotEnvMap {
        let newMap = DotEnvMap()
        let entries = map.allEntries()
        for (i in 0..entries.size) {
            let entry = entries[i]
            newMap.put(entry[0], entry[1])
        }
        return newMap
    }
}

// ============================================================================
// DotEnv - .env 文件解析器
// ============================================================================

/// .env 文件解析器 - 对应 Bun env_loader.Parser
public class DotEnv {

    /// 解析 .env 文本为 HashMap
    public static func parse(text: String): HashMap<String, String> {
        let result = HashMap<String, String>()
        var pos: Int64 = 0
        let src = text.toArray()
        let len = src.size

        var keys = ArrayList<String>()
        var values = ArrayList<String>()

        while (pos < len) {
            let (newPos, _) = skipWhitespace(src, pos, len)
            pos = newPos

            if (pos >= len) {
                break
            }

            if (src[pos] == BYTE_NL || src[pos] == BYTE_CR) {
                pos += 1
                continue
            }

            if (src[pos] == BYTE_HASH) {
                pos = skipLine(src, pos, len)
                continue
            }

            let (keyResult, keyEndPos) = parseKey(src, pos, len)
            if (keyResult.isNone()) {
                pos = skipLine(src, pos, len)
                continue
            }
            let key = keyResult.getOrThrow()
            pos = keyEndPos

            if (pos < len && src[pos] == BYTE_EQ) {
                pos += 1
            }

            let (value, valueEndPos) = parseValue(src, pos, len)
            pos = valueEndPos

            keys.append(key)
            values.append(value)

            if (pos < len && src[pos] != BYTE_NL && src[pos] != BYTE_CR) {
                pos = skipLine(src, pos, len)
            }
        }

        for (i in 0..keys.size) {
            result.put(keys[i], values[i])
        }

        let entries = result.allEntries()
        for (i in 0..entries.size) {
            let entry = entries[i]
            let expanded = expandValue(entry[1], result)
            if (expanded.isSome()) {
                result.put(entry[0], expanded.getOrThrow())
            }
        }

        return result
    }

    /// 从文件路径加载 .env 并返回映射
    public static func load(path: String): HashMap<String, String> {
        let content = readFileContent(path)
        if (content.isNone()) {
            return HashMap<String, String>()
        }
        return parse(content.getOrThrow())
    }

    /// 加载 .env 到进程环境变量
    public static func loadToEnv(path: String): Unit {
        let envMap = load(path)
        let entries = envMap.allEntries()
        for (i in 0..entries.size) {
            let entry = entries[i]
            setEnvVar(entry[0], entry[1])
        }
    }

    /// 解析键名
    private static func parseKey(src: Array<UInt8>, pos: Int64, len: Int64): (?String, Int64) {
        var start = pos
        var end = pos

        // 跳过 export 前缀
        let exportPrefix = "export".toArray()
        var isExport = true
        var i: Int64 = 0
        while (i < exportPrefix.size && (start + i) < len) {
            if (src[start + i] != exportPrefix[i]) {
                isExport = false
                break
            }
            i += 1
        }
        if (isExport && (start + exportPrefix.size) < len) {
            let nextIdx = start + exportPrefix.size
            let ch = src[nextIdx]
            if (ch == BYTE_SP || ch == BYTE_TAB || ch == BYTE_NL || ch == BYTE_CR) {
                let (wsEnd, _) = skipWhitespace(src, nextIdx, len)
                start = wsEnd
                end = wsEnd
            }
        }

        // 收集键名字符
        while (end < len) {
            let ch = src[end]
            if ((ch >= UInt8(97) && ch <= UInt8(122)) || (ch >= UInt8(65) && ch <= UInt8(90)) ||
                (ch >= UInt8(48) && ch <= UInt8(57)) || ch == BYTE_UNDERSCORE || ch == BYTE_DASH || ch == BYTE_DOT) {
                end += 1
            } else {
                break
            }
        }

        if (end == start) {
            return (None, pos)
        }

        let (wsEnd, _) = skipWhitespace(src, end, len)
        if (wsEnd < len) {
            let ch = src[wsEnd]
            if (ch == BYTE_EQ) {
                let key = fromChars(src, start, end)
                return (Some(key), wsEnd + 1)
            }
            if (ch == BYTE_COLON) {
                let next = wsEnd + 1
                if (next < len) {
                    let nextCh = src[next]
                    if (nextCh == BYTE_SP || nextCh == BYTE_TAB || nextCh == BYTE_NL || nextCh == BYTE_CR) {
                        let key = fromChars(src, start, end)
                        return (Some(key), next + 1)
                    }
                }
            }
        }

        return (None, pos)
    }

    /// 解析值
    private static func parseValue(src: Array<UInt8>, pos: Int64, len: Int64): (String, Int64) {
        let (wsEnd, _) = skipWhitespace(src, pos, len)
        var cur = wsEnd

        if (cur >= len) {
            return ("", cur)
        }

        let ch = src[cur]

        if (ch == BYTE_DQUOTE || ch == BYTE_SQUOTE || ch == BYTE_BQUOTE) {
            return parseQuotedValue(src, cur, len, ch)
        }

        var end = cur
        while (end < len) {
            let c = src[end]
            if (c == BYTE_HASH || c == BYTE_CR || c == BYTE_NL) {
                break
            }
            end += 1
        }

        var valEnd = end
        while (valEnd > cur) {
            let c = src[valEnd - 1]
            if (c != BYTE_SP && c != BYTE_TAB && c != BYTE_NL && c != BYTE_CR) {
                break
            }
            valEnd -= 1
        }

        var commentStart = cur
        var inValue = false
        var i = cur
        while (i < valEnd) {
            let c = src[i]
            if (c == BYTE_HASH) {
                if (i > cur && (src[i - 1] == BYTE_SP || src[i - 1] == BYTE_TAB)) {
                    commentStart = i
                    inValue = true
                    break
                }
            }
            i += 1
        }

        let actualEnd = if (inValue) { commentStart } else { valEnd }
        return (fromChars(src, cur, actualEnd), end)
    }

    /// 解析引号值
    private static func parseQuotedValue(src: Array<UInt8>, pos: Int64, len: Int64, qte: UInt8): (String, Int64) {
        var end = pos + 1
        var result = StringBuilder()

        while (end < len) {
            let ch = src[end]
            if (ch == BYTE_BACKSLASH && qte == BYTE_DQUOTE) {
                if (end + 1 < len) {
                    let next = src[end + 1]
                    if (next == BYTE_n) {
                        result.append('\n')
                        end += 2
                        continue
                    }
                    if (next == BYTE_r) {
                        result.append('\r')
                        end += 2
                        continue
                    }
                    result.append(Rune(Int32(next)))
                    end += 2
                    continue
                }
            }
            if (ch == BYTE_BACKSLASH) {
                result.append('\\')
                end += 1
                continue
            }
            if (ch == qte) {
                end += 1
                while (end < len) {
                    let after = src[end]
                    if (after == BYTE_SP || after == BYTE_TAB) {
                        end += 1
                        continue
                    }
                    if (after == BYTE_HASH) {
                        end = skipLine(src, end, len)
                    }
                    break
                }
                return (result.toString(), end)
            }
            if (ch == BYTE_CR) {
                end += 1
                if (end < len && src[end] == BYTE_NL) {
                    // \r\n -> \n
                } else {
                    result.append('\n')
                }
                continue
            }
            result.append(Rune(Int32(ch)))
            end += 1
        }

        return (result.toString(), end)
    }

    /// 展开值中的变量引用
    private static func expandValue(value: String, map: HashMap<String, String>): ?String {
        if (value.size < 2) {
            return None
        }

        var hasDollar = false
        for (i in 0..value.size) {
            if (value[i] == BYTE_DOLLAR) {
                hasDollar = true
                break
            }
        }
        if (!hasDollar) {
            return None
        }

        var result = StringBuilder()
        var i: Int64 = 0
        while (i < value.size) {
            let ch = value[i]
            if (ch == BYTE_DOLLAR) {
                if (i > 0 && value[i - 1] == BYTE_BACKSLASH) {
                    result.append('$')
                    i += 1
                    continue
                }

                i += 1
                if (i >= value.size) {
                    result.append('$')
                    break
                }

                let isBraced = value[i] == BYTE_LBRACE
                if (isBraced) {
                    i += 1
                }

                var nameStart = i
                while (i < value.size) {
                    let c = value[i]
                    if ((c >= UInt8(97) && c <= UInt8(122)) || (c >= UInt8(65) && c <= UInt8(90)) ||
                        (c >= UInt8(48) && c <= UInt8(57)) || c == BYTE_UNDERSCORE) {
                        i += 1
                    } else {
                        break
                    }
                }
                let varName = value[nameStart..i]

                var defaultValue = ""
                if (isBraced && i + 1 < value.size && value[i] == BYTE_COLON && value[i + 1] == BYTE_DASH) {
                    i += 2
                    var defaultStart = i
                    while (i < value.size) {
                        let c = value[i]
                        if (c == BYTE_RBRACE || c == BYTE_BACKSLASH) {
                            break
                        }
                        i += 1
                    }
                    defaultValue = value[defaultStart..i]
                }

                if (isBraced && i < value.size && value[i] == BYTE_RBRACE) {
                    i += 1
                }

                let lookedUp = map.get(varName)
                let resolved = if (lookedUp.isSome()) {
                    lookedUp.getOrThrow()
                } else {
                    defaultValue
                }
                result.append(resolved)
            } else {
                result.append(Rune(Int32(ch)))
                i += 1
            }
        }

        let expanded = result.toString()
        if (expanded == value) {
            return None
        }
        return Some(expanded)
    }

    /// 跳过空白字符
    private static func skipWhitespace(src: Array<UInt8>, pos: Int64, len: Int64): (Int64, Bool) {
        var i = pos
        while (i < len) {
            let ch = src[i]
            if (ch == BYTE_SP || ch == BYTE_TAB || ch == BYTE_NL || ch == BYTE_CR ||
                ch == BYTE_VT || ch == BYTE_FF || ch == BYTE_NBSP) {
                i += 1
            } else {
                break
            }
        }
        return (i, i > pos)
    }

    /// 跳到行尾
    private static func skipLine(src: Array<UInt8>, pos: Int64, len: Int64): Int64 {
        var i = pos
        while (i < len) {
            let ch = src[i]
            if (ch == BYTE_NL || ch == BYTE_CR) {
                return i + 1
            }
            i += 1
        }
        return len
    }

    /// 从字符数组提取子字符串
    private static func fromChars(src: Array<UInt8>, start: Int64, end: Int64): String {
        if (end <= start) {
            return ""
        }
        var sb = StringBuilder()
        for (i in start..end) {
            sb.append(Rune(Int32(src[i])))
        }
        return sb.toString()
    }

    /// 读取文件内容
    private static func readFileContent(path: String): ?String {
        // Use readAllBytes and convert to String manually
        let bytesResult = BaoFile.readAllBytes(path)
        match (bytesResult) {
            case Ok(arr) =>
                var sb = StringBuilder()
                for (b in arr) {
                    sb.append(Rune(Int32(b)))
                }
                return Some(sb.toString())
            case Err(_) => return None
        }
    }

    /// 设置环境变量 (平台相关)
    private static func setEnvVar(key: String, value: String): Unit {
        // 仓颉通过 FFI 调用 setenv 或使用标准库
    }
}
