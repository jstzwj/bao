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

        if (char == '-') {
            result.append("\u{2d}")
        } else if (char == '|' || char == '\\' || char == '{' || char == '}' ||
                   char == '(' || char == ')' || char == '[' || char == ']' ||
                   char == '^' || char == '$' || char == '+' || char == '*' ||
                   char == '?' || char == '.')
        {
            result.append("\\")
            result.append(String.fromByte(char))
        } else {
            result.append(String.fromByte(char))
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

        if (char == '-') {
            result.append("\u{2d}")
        } else if (char == '*') {
            result.append(".*")
        } else if (char == '|' || char == '\\' || char == '{' || char == '}' ||
                   char == '(' || char == ')' || char == '[' || char == ']' ||
                   char == '^' || char == '$' || char == '+' || char == '?' ||
                   char == '.')
        {
            result.append("\\")
            result.append(String.fromByte(char))
        } else {
            result.append(String.fromByte(char))
        }

        remain = remain[i + 1..remain.size]
    }

    result.append(remain)
    return result.toString()
}
