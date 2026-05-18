// 严格翻译自: src/paths/string_paths.rs
//   字符串路径工具函数
//   charIsAnySlash, startsWithWindowsDriveLetter, withoutTrailingSlash
//   basenamePosix, basenameLoose, dirnamePosix, nextDirname
//   removeLeadingDotSlash, withoutLeadingSlash, withoutLeadingPathSeparator
//   cloneNormalizingSeparators, pathContainsNodeModulesFolder
//   isParentOrEqual, ParentEqual
//
// 注意: path_string.cj 和 path_chars.cj 已有部分翻译
// 本文件提供 string_paths.rs 的完整函数集翻译
package bao_path

import bao_core.*
import bao_collections.*

// ============================================================================
// 字符串路径操作 - string_paths.rs 的完整翻译
// ============================================================================

/// 去除路径的尾部分隔符 (任意类型)
/// 严格翻译自: src/paths/string_paths.zig withoutTrailingSlash
///   pub fn withoutTrailingSlash(this: string) []const u8 {
///       var href = this;
///       while (href.len > 1 and (switch (href[href.len - 1]) {
///           '/', '\\' => true, else => false,
///       })) { href.len -= 1; }
///       return href;
///   }
public func stringWithoutTrailingSlash(path: String): String {
    if (path.size <= 1) {
        return path
    }
    var end = path.size
    while (end > 1 && isSepAnyChar(path[Int64(end - 1)])) {
        end -= 1
    }
    return path[0..end]
}

/// 去除前导斜杠
/// 严格翻译自: src/paths/resolve_path.zig withoutLeadingSlash
///   pub fn withoutLeadingSlash(this: string) []const u8 {
///       return std.mem.trimLeft(u8, this, "/");
///   }
public func stringWithoutLeadingSlash(path: String): String {
    var start: Int64 = 0
    while (start < path.size && path[start] == UInt8(47)) {
        start += 1
    }
    if (start > 0) {
        return path[start..]
    }
    return path
}

/// 去除前导路径分隔符
/// 严格翻译自: src/paths/string_paths.zig withoutLeadingPathSeparator
///   pub fn withoutLeadingPathSeparator(this: string) []const u8 {
///       return std.mem.trimLeft(u8, this, &.{std.fs.path.sep});
///   }
public func stringWithoutLeadingPathSeparator(path: String): String {
    var start: Int64 = 0
    while (start < path.size && isSepAnyChar(path[start])) {
        start += 1
    }
    if (start > 0) {
        return path[start..]
    }
    return path
}

/// 去除前导 "./"
/// 严格翻译自: src/paths/string_paths.zig removeLeadingDotSlash
///   pub fn removeLeadingDotSlash(slice: []const u8) []const u8 {
///       if (slice.len >= 2) {
///           if (slice[0..2] == "./" or (Windows and slice[0..2] == ".\\")) {
///               return slice[2..];
///           }
///       }
///       return slice;
///   }
public func stringRemoveLeadingDotSlash(path: String): String {
    if (path.size >= 2 && path[0] == UInt8(46) &&
        (path[1] == UInt8(47) || path[1] == UInt8(92))) {
        return path[2..]
    }
    return path
}

/// 确保路径以尾部分隔符结束
public func stringEnsureTrailingSlash(path: String): String {
    if (path.isEmpty()) {
        return "/"
    }
    if (isSepAnyChar(path[Int64(path.size - 1)])) {
        return path
    }
    return path + "/"
}

/// 提取 basename (POSIX 版本)
/// 严格翻译自: src/paths/string_paths.zig basenamePosix
///   fn basenamePosix(comptime T: type, input: []const T) []const T {
///       if (input.len == 0) return &[_]u8{};
///       var end_index = input.len - 1;
///       while (input[end_index] == '/') { if (end_index == 0) return &.{}; end_index -= 1; }
///       var start_index = end_index;
///       end_index += 1;
///       while (input[start_index] != '/') { if (start_index == 0) return input[0..end_index]; start_index -= 1; }
///       return input[start_index + 1 .. end_index];
///   }
public func stringBasenamePosix(path: String): String {
    if (path.isEmpty()) {
        return ""
    }
    var endIndex: Int64 = path.size - 1
    while (endIndex > 0 && path[Int64(endIndex)] == UInt8(47)) {
        endIndex -= 1
    }
    if (endIndex == 0 && path[0] == UInt8(47)) {
        return ""
    }
    var begin: Int64 = endIndex
    while (begin > 0 && path[Int64(begin)] != UInt8(47)) {
        begin -= 1
    }
    if (path[Int64(begin)] == UInt8(47)) {
        return path[begin + 1..endIndex + 1]
    }
    return path[0..endIndex + 1]
}

/// 提取 basename (任意分隔符版本)
/// 严格翻译自: src/paths/string_paths.zig basename (loose 版本)
public func stringBasenameLoose(path: String): String {
    if (path.isEmpty()) {
        return ""
    }
    var endIndex: Int64 = path.size - 1
    while (endIndex > 0 && isSepAnyChar(path[Int64(endIndex)])) {
        endIndex -= 1
    }
    if (endIndex == 0 && isSepAnyChar(path[0])) {
        return "/"
    }
    var begin: Int64 = endIndex
    while (begin > 0 && !isSepAnyChar(path[Int64(begin)])) {
        begin -= 1
    }
    if (isSepAnyChar(path[Int64(begin)])) {
        return path[begin + 1..endIndex + 1]
    }
    return path[0..endIndex + 1]
}

/// 提取 dirname (POSIX 版本)
/// 严格翻译自: src/paths/resolve_path.zig dirname
public func stringDirnamePosix(path: String): String {
    if (path.isEmpty()) {
        return ""
    }
    var p = stringWithoutTrailingSlash(path)
    if (p.isEmpty()) {
        return "/"
    }
    match (p.lastIndexOf('/')) {
        case Some(lastSlash) =>
            if (lastSlash == 0) {
                return "/"
            }
            return p[0..lastSlash]
        case None => return ""
    }
}

/// 提取下一个目录名 (逐步回退)
/// 严格翻译自: src/paths/string_paths.zig nextDirname
///   pub fn nextDirname(path_: []const u8) ?[]const u8
///   用于逐步获取父目录路径
public func stringNextDirname(path: String): ?String {
    if (path.isEmpty()) {
        return None
    }
    var end: Int64 = path.size
    // 去除尾部分隔符
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
    // 去除尾部分隔符
    while (end > 0 && isSepAnyChar(path[Int64(end - 1)])) {
        end -= 1
    }
    if (end == 0) {
        return None
    }
    return path[0..end]
}

/// 克隆并规范化路径分隔符 (去除重复分隔符)
/// 严格翻译自: src/paths/string_paths.zig cloneNormalizingSeparators
///   pub fn cloneNormalizingSeparators(allocator, input: []const u8) ![]u8 {
///       const base = withoutTrailingSlash(input);
///       var tokenized = std.mem.tokenizeScalar(u8, base, std.fs.path.sep);
///       ...
///   }
public func stringCloneNormalizingSeparators(path: String): String {
    if (path.isEmpty()) {
        return path
    }
    let base = stringWithoutTrailingSlash(path)
    if (base.isEmpty()) {
        return "/"
    }
    var sb = StringBuilder()
    var i: Int64 = 0
    let leadingSlash = base[0] == UInt8(47)
    if (leadingSlash) {
        sb.append(UInt8(47))
        i = 1
    }
    var first = true
    while (i < base.size) {
        if (isSepAnyChar(base[i])) {
            i += 1
            continue
        }
        if (!first) {
            sb.append(UInt8(47))
        }
        first = false
        while (i < base.size && !isSepAnyChar(base[i])) {
            sb.append(base[i])
            i += 1
        }
    }
    let result = sb.toString()
    if (result.isEmpty()) {
        return if (leadingSlash) { "/" } else { "." }
    }
    return result
}

/// 检测路径是否包含 node_modules 文件夹
/// 严格翻译自: src/paths/string_paths.zig pathContainsNodeModulesFolder
///   pub fn pathContainsNodeModulesFolder(path: []const u8) bool {
///       return strings.contains(path, std.fs.path.sep_str ++ "node_modules" ++ std.fs.path.sep_str);
///   }
public func stringPathContainsNodeModulesFolder(path: String): Bool {
    return path.contains("/node_modules/")
}

/// 查找最后一个 POSIX 分隔符
/// 严格翻译自: src/paths/resolve_path.zig lastIndexOfSeparatorPosix
public func stringLastIndexOfSeparatorPosix(path: String): ?Int64 {
    var i: Int64 = path.size
    while (i > 0) {
        i -= 1
        if (path[i] == UInt8(47)) {
            return i
        }
    }
    return None
}

/// 查找最后一个任意分隔符
/// 严格翻译自: src/paths/resolve_path.zig lastIndexOfSeparatorLoose
public func stringLastIndexOfSeparatorLoose(path: String): ?Int64 {
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
/// 严格翻译自: src/paths/resolve_path.zig lastIndexOfNonSeparatorPosix
public func stringLastIndexOfNonSeparatorPosix(path: String): ?Int64 {
    var i: Int64 = path.size
    while (i > 0) {
        i -= 1
        if (path[i] != UInt8(47)) {
            return i
        }
    }
    return None
}

// ============================================================================
// 父子路径关系
// 严格翻译自: src/paths/resolve_path.zig
//   pub fn isParentOrEqual(parent_: []const u8, child: []const u8) ParentEqual
//   const ParentEqual = enum { parent, equal, unrelated };
// ============================================================================

/// 父子路径关系枚举
/// 对应 Bun: const ParentEqual = enum { parent, equal, unrelated }
public enum StringParentRelation {
    | Parent     // parent 是 child 的父目录
    | Equal      // 两个路径相等
    | Unrelated  // 无关
}

/// 判断 parent 是否是 child 的父路径或相等
/// 严格翻译自: src/paths/resolve_path.zig isParentOrEqual
///   pub fn isParentOrEqual(parent_: []const u8, child: []const u8) ParentEqual {
///       var parent = parent_;
///       while (parent.len > 0 and isSepAny(parent[parent.len - 1]))
///           parent = parent[0 .. parent.len - 1];
///       if (!contains(child, parent)) return .unrelated;
///       if (child.len == parent.len) return .equal;
///       if (child.len > parent.len and isSepAny(child[parent.len])) return .parent;
///       return .unrelated;
///   }
public func stringIsParentOrEqual(parent: String, child: String): StringParentRelation {
    var p = stringWithoutTrailingSlash(parent)
    if (!child.contains(p)) {
        return StringParentRelation.Unrelated
    }
    if (child.size == p.size) {
        return StringParentRelation.Equal
    }
    if (child.size > p.size && isSepAnyChar(child[Int64(p.size)])) {
        return StringParentRelation.Parent
    }
    return StringParentRelation.Unrelated
}
