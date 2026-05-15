// bao_path - 路径字符判断工具
// 严格翻译自:
//   src/paths/resolve_path.zig - isSepPosix, isSepAny, isSepWin32, isDriveLetter
//   src/paths/string_paths.zig - charIsAnySlash, startsWithWindowsDriveLetter
//   src/paths/path_char.rs - PathChar trait
package bao_path

import bao_core.*

// ============================================================================
// 路径字符判断
// 严格翻译自: src/paths/resolve_path.zig 中的分隔符判断函数
//   pub fn isSepPosix(char: u8) bool { return char == std.fs.path.sep_posix; }
//   pub fn isSepWin32(char: u8) bool { return char == std.fs.path.sep_windows; }
//   pub fn isSepAny(char: u8) bool { return isSepPosix(char) or isSepWin32(char); }
// ============================================================================

/// 判断字符是否为 POSIX 路径分隔符 '/'
/// 对应 Bun: isSepPosix / isSepPosixT(u8, char)
public func isSepPosix(c: UInt8): Bool {
    return c == SEP
}

/// 判断字符是否为 Windows 路径分隔符 '\'
/// 对应 Bun: isSepWin32 / isSepWin32T(u8, char)
public func isSepWin32(c: UInt8): Bool {
    return c == SEP_WINDOWS
}

/// 判断字符是否为任意路径分隔符 (POSIX 或 Windows)
/// 对应 Bun: isSepAny / isSepAnyT(u8, char)
///   pub fn isSepAny(char: u8) bool {
///       return isSepPosixT(u8, char) or isSepWin32T(u8, char);
///   }
public func isSepAny(c: UInt8): Bool {
    return isSepPosix(c) || isSepWin32(c)
}

/// Char 版本 - 判断字符是否为路径分隔符
public func isSepAnyChar(c: Char): Bool {
    return c == Char('/') || c == Char('\\')
}

/// 判断是否为驱动器号字符 (A-Z, a-z)
/// 对应 Bun: isDriveLetter / isDriveLetterT
///   pub fn isDriveLetter(c: u8) bool {
///       return 'a' <= c and c <= 'z' or 'A' <= c and c <= 'Z';
///   }
public func isDriveLetter(c: UInt8): Bool {
    return (c >= UInt8(97) && c <= UInt8(122)) ||
           (c >= UInt8(65) && c <= UInt8(90))  // 'A'-'Z'
}

/// Char 版本 - 判断是否为驱动器号
public func isDriveLetterChar(c: Char): Bool {
    return (c >= Char('a') && c <= Char('z')) ||
           (c >= Char('A') && c <= Char('Z'))
}

/// 判断字符是否为任意斜杠 - 对应 Bun charIsAnySlash
///   pub fn charIsAnySlash(char: u8) callconv(bun.callconv_inline) bool {
///       return char == '/' or char == '\\';
///   }
public func charIsAnySlash(c: UInt8): Bool {
    return isSepAny(c)
}

// ============================================================================
// 路径前缀检测
// 严格翻译自: src/paths/string_paths.zig
//   pub fn startsWithWindowsDriveLetter(s: []const u8) bool
// ============================================================================

/// 检测字符串是否以 Windows 驱动器号开头 (如 "C:\")
/// 对应 Bun: startsWithWindowsDriveLetter
///   pub fn startsWithWindowsDriveLetter(s: []const u8) bool {
///       return s.len > 2 and s[1] == ':' and switch (s[0]) {
///           'a'...'z', 'A'...'Z' => true,
///           else => false,
///       };
///   }
public func startsWithWindowsDriveLetter(s: String): Bool {
    if (s.size < 3) {
        return false
    }
    return isDriveLetterChar(s[0]) && s[1] == Char(':')
}

/// 检测路径是否包含平台路径分隔符
/// 对应 Bun: hasPlatformPathSeparators
/// POSIX: 包含 '/'
public func hasPlatformPathSeparators(path: String): Bool {
    return path.contains("/")
}

// ============================================================================
// 路径分隔符转换 (就地)
// 严格翻译自: src/paths/resolve_path.zig
//   pub fn platformToPosixInPlace / dangerouslyConvertPathToWindowsInPlace
// ============================================================================

/// 将字符串中的所有反斜杠替换为正斜杠 (POSIX)
/// 对应 Bun: slashesToPosixInPlace / platformToPosixInPlace
///   for (path.iter_mut()) |*c| {
///       if (c.* == T::from_u8(b'\\')) c.* = T::from_u8(b'/');
///   }
public func slashesToPosix(path: String): String {
    var sb = StringBuilder()
    for (i in 0..path.size) {
        let c = path[Int64(i)]
        if (c == Char('\\')) {
            sb.append(Char('/'))
        } else {
            sb.append(c)
        }
    }
    return sb.toString()
}

/// 将字符串中的所有正斜杠替换为反斜杠 (Windows)
/// 对应 Bun: slashesToWindowsInPlace / dangerouslyConvertPathToWindowsInPlace
///   for (path.iter_mut()) |*c| {
///       if (c.* == T::from_u8(b'/')) c.* = T::from_u8(b'\\');
///   }
public func slashesToWindows(path: String): String {
    var sb = StringBuilder()
    for (i in 0..path.size) {
        let c = path[Int64(i)]
        if (c == Char('/')) {
            sb.append(Char('\\'))
        } else {
            sb.append(c)
        }
    }
    return sb.toString()
}

/// 规范化斜杠 - 将所有反斜杠替换为目标斜杠
/// 对应 Bun: normalizeSlashesOnly
///   pub fn normalizeSlashesOnly(buf: []u8, utf8: []const u8, comptime desired_slash: u8) []const u8
public func normalizeSlashesOnly(path: String, desiredSlash: Char): String {
    if (desiredSlash == Char('/')) {
        return slashesToPosix(path)
    }
    return slashesToWindows(path)
}
