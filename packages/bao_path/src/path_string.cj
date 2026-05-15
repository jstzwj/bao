// bao_path - 不可变路径字符串工具
// 严格翻译自:
//   src/paths/string_paths.zig - withoutTrailingSlash, basename, cloneNormalizingSeparators
//   src/paths/resolve_path.zig - withoutLeadingSlash, removeLeadingDotSlash, dirname
package bao_path

import bao_core.*

// ============================================================================
// 路径字符串操作
// 严格翻译自: src/paths/string_paths.zig 和 src/paths/resolve_path.zig
// 这些函数对不可变路径字符串进行操作, 返回新的字符串
// ============================================================================

/// 去除尾部分隔符
/// 对应 Bun: withoutTrailingSlash
///   pub fn withoutTrailingSlash(this: string) []const u8 {
///       var href = this;
///       while (href.len > 1 and (switch (href[href.len - 1]) {
///           '/', '\\' => true, else => false,
///       })) { href.len -= 1; }
///       return href;
///   }
public func withoutTrailingSlash(path: String): String {
    if (path.size <= 1) {
        return path
    }
    var end = path.size
    while (end > 1 && isSepAnyChar(path[Int64(end - 1)])) {
        end -= 1
    }
    return path.substring(0, Int64(end))
}

/// 去除前导斜杠
/// 对应 Bun: withoutLeadingSlash
///   pub fn withoutLeadingSlash(this: string) []const u8 {
///       return std.mem.trimLeft(u8, this, "/");
///   }
public func withoutLeadingSlash(path: String): String {
    var start: Int64 = 0
    while (start < path.size && path[start] == Char('/')) {
        start += 1
    }
    if (start > 0) {
        return path.substring(start)
    }
    return path
}

/// 去除前导路径分隔符
/// 对应 Bun: withoutLeadingPathSeparator
///   pub fn withoutLeadingPathSeparator(this: string) []const u8 {
///       return std.mem.trimLeft(u8, this, &.{std.fs.path.sep});
///   }
public func withoutLeadingPathSeparator(path: String): String {
    var start: Int64 = 0
    while (start < path.size && isSepAnyChar(path[start])) {
        start += 1
    }
    if (start > 0) {
        return path.substring(start)
    }
    return path
}

/// 去除前导 "./"
/// 对应 Bun: removeLeadingDotSlash
///   pub fn removeLeadingDotSlash(slice: []const u8) []const u8 {
///       if (slice.len >= 2) {
///           if (slice[0..2] == "./" or (Windows and slice[0..2] == ".\\")) {
///               return slice[2..];
///           }
///       }
///       return slice;
///   }
public func removeLeadingDotSlash(path: String): String {
    if (path.size >= 2 && path[0] == Char('.') &&
        (path[1] == Char('/') || path[1] == Char('\\'))) {
        return path.substring(2)
    }
    return path
}

/// 确保路径以尾部分隔符结束
/// 对应 Bun: ensureTrailingSlash (辅助函数)
public func ensureTrailingSlash(path: String): String {
    if (path.isEmpty) {
        return "/"
    }
    if (isSepAnyChar(path[Int64(path.size - 1)])) {
        return path
    }
    return path + "/"
}

/// 去除尾部分隔符但保留 Windows 根路径
/// 对应 Bun: withoutTrailingSlashWindowsPath
///   pub fn withoutTrailingSlashWindowsPath(input: string) []const u8 {
///       const root_len = bun.path.windowsFilesystemRoot(input).len + 1;
///       while (path.len > root_len and isSepAny(path[path.len - 1]))
///           path.len -= 1;
///       return path;
///   }
public func withoutTrailingSlashWindowsPath(input: String): String {
    // POSIX: 直接使用 withoutTrailingSlash
    return withoutTrailingSlash(input)
}

// ============================================================================
// 路径名提取
// 严格翻译自: src/paths/string_paths.zig basename 函数
//   pub fn basename(comptime T: type, input: []const T) []const T { ... }
// ============================================================================

/// 提取路径最后一段 (basename) - POSIX 版本
/// 对应 Bun: basenamePosix
///   fn basenamePosix(comptime T: type, input: []const T) []const T {
///       if (input.len == 0) return &[_]u8{};
///       var end_index = input.len - 1;
///       while (input[end_index] == '/') { if (end_index == 0) return &.{}; end_index -= 1; }
///       var start_index = end_index;
///       end_index += 1;
///       while (input[start_index] != '/') { if (start_index == 0) return input[0..end_index]; start_index -= 1; }
///       return input[start_index + 1 .. end_index];
///   }
public func basenamePosix(path: String): String {
    if (path.isEmpty) {
        return ""
    }
    // 去除尾部分隔符
    var endIndex: Int64 = path.size - 1
    while (endIndex > 0 && path[Int64(endIndex)] == Char('/')) {
        endIndex -= 1
    }
    if (endIndex == 0 && path[0] == Char('/')) {
        return ""
    }
    let startIndex: Int64 = endIndex
    endIndex += 1
    // 查找起始分隔符
    var begin: Int64 = startIndex
    while (begin > 0 && path[Int64(begin)] != Char('/')) {
        begin -= 1
    }
    if (path[Int64(begin)] == Char('/')) {
        return path.substring(Int64(begin + 1), Int64(endIndex))
    }
    return path.substring(0, Int64(endIndex))
}

/// 提取路径最后一段 (basename) - 使用任意分隔符
/// 对应 Bun: basename (loose 版本, 使用 isSepAny)
public func basenameLoose(path: String): String {
    if (path.isEmpty) {
        return ""
    }
    // 去除尾部分隔符
    var endIndex: Int64 = path.size - 1
    while (endIndex > 0 && isSepAnyChar(path[Int64(endIndex)])) {
        endIndex -= 1
    }
    if (endIndex == 0 && isSepAnyChar(path[0])) {
        return "/"
    }
    let startIndex: Int64 = endIndex
    endIndex += 1
    // 查找起始分隔符
    var begin: Int64 = startIndex
    while (begin > 0 && !isSepAnyChar(path[Int64(begin)])) {
        begin -= 1
    }
    if (isSepAnyChar(path[Int64(begin)])) {
        return path.substring(Int64(begin + 1), Int64(endIndex))
    }
    return path.substring(0, Int64(endIndex))
}

/// 提取目录名 - POSIX 版本
/// 对应 Bun: dirname(.posix, str)
///   pub fn dirname(str: []const u8, comptime platform: Platform) []const u8 {
///       const separator = lastIndexOfSeparatorPosix(str) orelse return "";
///       if (separator == 0) return "/";
///       if (separator == str.len - 1) return dirname(str[0..str.len - 1], platform);
///       return str[0..separator];
///   }
public func dirnamePosix(path: String): String {
    if (path.isEmpty) {
        return ""
    }
    // 去除尾部分隔符
    var p = withoutTrailingSlash(path)
    if (p.isEmpty) {
        return "/"
    }
    let lastSlash = p.lastIndexOf('/')
    if (lastSlash < 0) {
        return ""
    }
    if (lastSlash == 0) {
        return "/"
    }
    return p.substring(0, Int64(lastSlash))
}

/// 提取下一个目录名 (逐步回退)
/// 对应 Bun: nextDirname
///   pub fn nextDirname(path_: []const u8) ?[]const u8 {
///       // 去除尾部分隔符和最后一段
///   }
public func nextDirname(path: String): ?String {
    if (path.isEmpty) {
        return None
    }
    // 去除尾部分隔符
    var end: Int64 = path.size
    while (end > 0 && isSepAnyChar(path[Int64(end - 1)])) {
        end -= 1
    }
    if (end == 0) {
        return None
    }
    // 去除最后的非分隔符段
    while (end > 0 && !isSepAnyChar(path[Int64(end - 1)])) {
        end -= 1
    }
    if (end == 0) {
        return None
    }
    // 去除尾部分隔符
    while (end > 0 && isSepAnyChar(path[Int64(end - 1)])) {
        end -= 1
    }
    if (end == 0) {
        return None
    }
    return path.substring(0, Int64(end))
}

// ============================================================================
// 路径分隔符查找
// 严格翻译自: src/paths/resolve_path.zig
//   pub fn lastIndexOfSeparatorPosix(slice: []const u8) ?usize
//   pub fn lastIndexOfSeparatorLoose(slice: []const u8) ?usize
// ============================================================================

/// 查找最后一个 POSIX 分隔符
/// 对应 Bun: lastIndexOfSeparatorPosix / lastIndexOfSeparatorPosixT
public func lastIndexOfSeparatorPosix(path: String): ?Int64 {
    var i: Int64 = path.size
    while (i > 0) {
        i -= 1
        if (path[i] == Char('/')) {
            return i
        }
    }
    return None
}

/// 查找最后一个任意分隔符 (POSIX 或 Windows)
/// 对应 Bun: lastIndexOfSeparatorLoose / lastIndexOfSeparatorLooseT
public func lastIndexOfSeparatorLoose(path: String): ?Int64 {
    var i: Int64 = path.size
    while (i > 0) {
        i -= 1
        if (isSepAnyChar(path[i])) {
            return i
        }
    }
    return None
}

/// 查找最后一个非分隔符位置
/// 对应 Bun: lastIndexOfNonSeparatorPosix
///   pub fn lastIndexOfNonSeparatorPosix(slice: []const u8) ?u32 {
///       var i: usize = slice.len;
///       while (i != 0) : (i -= 1) { if (slice[i] != '/') return @intCast(i); }
///       return null;
///   }
public func lastIndexOfNonSeparatorPosix(path: String): ?Int64 {
    var i: Int64 = path.size
    while (i > 0) {
        i -= 1
        if (path[i] != Char('/')) {
            return i
        }
    }
    return None
}

// ============================================================================
// 路径规范化
// 严格翻译自: src/paths/string_paths.zig cloneNormalizingSeparators
//   pub fn cloneNormalizingSeparators(allocator, input: []const u8) ![]u8 {
//       const base = withoutTrailingSlash(input);
//       var tokenized = std.mem.tokenizeScalar(u8, base, std.fs.path.sep);
//       ...
//   }
// ============================================================================

/// 克隆并规范化路径分隔符 (去除重复分隔符)
/// 对应 Bun: cloneNormalizingSeparators
/// 去除重复的斜杠, 保留前导斜杠
public func cloneNormalizingSeparators(path: String): String {
    if (path.isEmpty) {
        return path
    }
    let base = withoutTrailingSlash(path)
    if (base.isEmpty) {
        return "/"
    }
    var sb = StringBuilder()
    var i: Int64 = 0
    let leadingSlash = base[0] == Char('/')
    if (leadingSlash) {
        sb.append(Char('/'))
        i = 1
    }
    var first = true
    while (i < base.size) {
        // 跳过连续分隔符
        if (isSepAnyChar(base[i])) {
            i += 1
            continue
        }
        // 提取非分隔符段
        if (!first) {
            sb.append(Char('/'))
        }
        first = false
        while (i < base.size && !isSepAnyChar(base[i])) {
            sb.append(base[i])
            i += 1
        }
    }
    let result = sb.toString()
    if (result.isEmpty) {
        return if (leadingSlash) { "/" } else { "." }
    }
    return result
}

/// 检测路径是否包含 node_modules 文件夹
/// 对应 Bun: pathContainsNodeModulesFolder
///   pub fn pathContainsNodeModulesFolder(path: []const u8) bool {
///       return strings.contains(path, std.fs.path.sep_str ++ "node_modules" ++ std.fs.path.sep_str);
///   }
public func pathContainsNodeModulesFolder(path: String): Bool {
    return path.contains("/node_modules/")
}

// ============================================================================
// 父子路径关系判断
// 严格翻译自: src/paths/resolve_path.zig
//   pub fn isParentOrEqual(parent_: []const u8, child: []const u8) ParentEqual
// ============================================================================

/// 父子路径关系枚举
/// 对应 Bun: ParentEqual
///   const ParentEqual = enum { parent, equal, unrelated };
public enum ParentRelation {
    | Parent     // parent 是 child 的父目录
    | Equal      // 两个路径相等
    | Unrelated  // 无关
}

/// 判断 parent 是否是 child 的父路径或相等
/// 对应 Bun: isParentOrEqual
///   pub fn isParentOrEqual(parent_: []const u8, child: []const u8) ParentEqual {
///       var parent = parent_;
///       while (parent.len > 0 and isSepAny(parent[parent.len - 1]))
///           parent = parent[0 .. parent.len - 1];
///       if (!contains(child, parent)) return .unrelated;
///       if (child.len == parent.len) return .equal;
///       if (child.len > parent.len and isSepAny(child[parent.len])) return .parent;
///       return .unrelated;
///   }
public func isParentOrEqual(parent: String, child: String): ParentRelation {
    var p = withoutTrailingSlash(parent)
    if (!child.contains(p)) {
        return ParentRelation.Unrelated
    }
    if (child.size == p.size) {
        return ParentRelation.Equal
    }
    if (child.size > p.size && isSepAnyChar(child[Int64(p.size)])) {
        return ParentRelation.Parent
    }
    return ParentRelation.Unrelated
}
