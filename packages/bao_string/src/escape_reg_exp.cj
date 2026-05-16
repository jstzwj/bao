// 严格翻译自: src/string/escapeRegExp.zig
// 正则表达式转义工具
//   提供两个核心函数:
//   - escapeRegExp: 转义正则特殊字符
//   - escapeRegExpForPackageNameMatching: '*' 变成 '.*' 而非 '\\*'
package bao_string


// ============================================================================
// 常量
// ============================================================================

/// 正则表达式特殊字符集合
/// 严格翻译自 escapeRegExp.zig special_characters
public const SPECIAL_CHARACTERS = "|\\{}()[]^$+*?.-"

// ============================================================================
// 正则转义函数
// ============================================================================

/// 转义正则表达式特殊字符
/// 严格翻译自 escapeRegExp.zig escapeRegExp
/// 将输入字符串中的正则特殊字符转义,添加反斜杠前缀
/// '-' 被转义为 "\u{2d}"
///
/// @param input  输入字符串
/// @return       转义后的字符串
public func escapeRegExp(input: String): String {
    var result = StringBuilder()
    var remain = input

    while (true) {
        let idx = indexOfAny(remain, SPECIAL_CHARACTERS)
        if (idx < 0) {
            break
        }
        let i = Int64(idx)

        result.append(remain[0..i])

        let char = remain[i]

        if (char == UInt8(0x2d)) {
            result.append("\\u{2d}")
        } else if (char == UInt8(0x7c) || char == UInt8(0x5c) || char == UInt8(0x7b) || char == UInt8(0x7d) ||
                   char == UInt8(0x28) || char == UInt8(0x29) || char == UInt8(0x5b) || char == UInt8(0x5d) ||
                   char == UInt8(0x5e) || char == UInt8(0x24) || char == UInt8(0x2b) || char == UInt8(0x2a) ||
                   char == UInt8(0x3f) || char == UInt8(0x2e))
        {
            result.append("\\")
            result.append(String(Rune(char)))
        } else {
            result.append(String(Rune(char)))
        }

        remain = remain[i + 1..remain.size]
    }

    result.append(remain)
    return result.toString()
}

/// 转义正则表达式特殊字符 (用于包名匹配)
/// 严格翻译自 escapeRegExp.zig escapeRegExpForPackageNameMatching
/// 与 escapeRegExp 类似,但 '*' 变成 '.*' 而非 '\\*'
///
/// @param input  输入字符串
/// @return       转义后的字符串
public func escapeRegExpForPackageNameMatching(input: String): String {
    var result = StringBuilder()
    var remain = input

    while (true) {
        let idx = indexOfAny(remain, SPECIAL_CHARACTERS)
        if (idx < 0) {
            break
        }
        let i = Int64(idx)

        result.append(remain[0..i])

        let char = remain[i]

        if (char == UInt8(0x2d)) {
            result.append("\\u{2d}")
        } else if (char == UInt8(0x2a)) {
            result.append(".*")
        } else if (char == UInt8(0x7c) || char == UInt8(0x5c) || char == UInt8(0x7b) || char == UInt8(0x7d) ||
                   char == UInt8(0x28) || char == UInt8(0x29) || char == UInt8(0x5b) || char == UInt8(0x5d) ||
                   char == UInt8(0x5e) || char == UInt8(0x24) || char == UInt8(0x2b) || char == UInt8(0x3f) ||
                   char == UInt8(0x2e))
        {
            result.append("\\")
            result.append(String(Rune(char)))
        } else {
            result.append(String(Rune(char)))
        }

        remain = remain[i + 1..remain.size]
    }

    result.append(remain)
    return result.toString()
}
