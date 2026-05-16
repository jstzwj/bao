// bao_core - 正则表达式转义工具
// 严格翻译自: src/string/escapeRegExp.zig
//   pub fn escapeRegExp(input: []const u8, writer: *std.Io.Writer) !void
//   pub fn escapeRegExpForPackageNameMatching(input: []const u8, writer: *std.Io.Writer) !void
// Bun: 将字符串中的正则特殊字符转义
// 仓颉: 提供相同的转义功能
package bao_core

/// 正则表达式转义工具 - 严格对应 Bun escapeRegExp
/// 对应 Bun escapeRegExp.zig 中的特殊字符表:
///   const special_characters = "|\\{}()[]^$+*?.-";
public class RegexEscape {
    /// 正则表达式特殊字符 - 对应 Bun special_characters
    /// const special_characters = "|\\{}()[]^$+*?.-";
    private static let SPECIAL_CHARS: String = "|\\{}()[]^$+*?.-"

    /// 转义正则表达式特殊字符 - 对应 Bun escapeRegExp
    /// pub fn escapeRegExp(input: []const u8, writer: *std.Io.Writer) !void {
    ///     var remain = input;
    ///     while (strings.indexOfAny(remain, special_characters)) |i| {
    ///         try writer.writeAll(remain[0..i]);
    ///         switch (remain[i]) {
    ///             '|', '\\', '{', '}', '(', ')', '[', ']', '^', '$', '+', '*', '?', '.',
    ///             => |c| try writer.writeAll(&.{ '\\', c }),
    ///             '-' => try writer.writeAll("\u{2d}"),
    ///             else => ...
    ///         }
    ///         remain = remain[i + 1 ..];
    ///     }
    ///     try writer.writeAll(remain);
    /// }
    public static func escape(input: String): String {
        var sb = StringBuilder()
        var i = 0
        let chars = input.toRuneArray()
        while (i < chars.size) {
            let c = chars[Int64(i)]
            if (isSpecialRune(c)) {
                if (c == r'-') {
                    // 对应 Bun: '-' => try writer.writeAll("\u{2d}")
                    sb.append("\u{2d}")
                } else {
                    // 对应 Bun: => |c| try writer.writeAll(&.{ '\\', c })
                    sb.append('\\')
                    sb.append(c)
                }
            } else {
                sb.append(c)
            }
            i += 1
        }
        return sb.toString()
    }

    /// 包名匹配转义 - 对应 Bun escapeRegExpForPackageNameMatching
    /// '*' 变为 '.*' 而不是 '\\*'
    /// pub fn escapeRegExpForPackageNameMatching(input: []const u8, writer: *std.Io.Writer) !void {
    ///     ...
    ///     switch (remain[i]) {
    ///         ..., '*', ...
    ///         => |c| try writer.writeAll(&.{ '\\', c }),
    ///         '*' => try writer.writeAll(".*"),
    ///         ...
    ///     }
    /// }
    public static func escapeForPackageNameMatching(input: String): String {
        var sb = StringBuilder()
        var i = 0
        let chars = input.toRuneArray()
        while (i < chars.size) {
            let c = chars[Int64(i)]
            if (c == r'*') {
                // '*' 变为 '.*' - 通配符匹配
                sb.append(".*")
            } else if (c == r'-') {
                sb.append("\u{2d}")
            } else if (isSpecialRune(c)) {
                sb.append('\\')
                sb.append(c)
            } else {
                sb.append(c)
            }
            i += 1
        }
        return sb.toString()
    }

    /// 检查字符是否为正则特殊字符
    private static func isSpecialRune(c: Rune): Bool {
        // 对应 Bun special_characters = "|\\{}()[]^$+*?.-"
        return c == r'|' || c == r'\\' || c == r'{' || c == r'}' ||
               c == r'(' || c == r')' || c == r'[' || c == r']' ||
               c == r'^' || c == r'$' || c == r'+' || c == r'*' ||
               c == r'?' || c == r'.' || c == r'-'
    }

    /// 检查字节是否为正则特殊字符
    private static func isSpecialByte(b: UInt8): Bool {
        return isSpecialRune(Rune(Int32(b)))
    }

    /// 检查字符串是否包含正则特殊字符
    public static func containsSpecialRunes(input: String): Bool {
        for (c in input) {
            if (isSpecialByte(c)) {
                return true
            }
        }
        return false
    }
}
