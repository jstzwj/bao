// bao_path - 路径解析工具
// 严格翻译自:
//   src/paths/resolve_path.zig - normalizeStringGeneric, joinAbsStringBuf, relative
//   src/paths/resolve_path.rs - Platform enum, longestCommonPath, relativeToCommonPath
package bao_path

import bao_core.*

// ============================================================================
// Platform - 平台枚举
// 严格翻译自: src/paths/resolve_path.zig
//   pub const Platform = enum {
//       loose, windows, posix, nt,
//       pub const auto: Platform = switch (bun.Environment.os) { ... };
//   };
// 仓颉目标平台为 POSIX (Linux/macOS)
// ============================================================================

/// 平台枚举 - 对应 Bun Platform
public enum Platform {
    | Loose     // 宽松模式, 同时接受 '/' 和 '\'
    | Windows   // Windows 风格
    | Posix     // POSIX 风格

    /// 获取平台分隔符
    /// 对应 Bun Platform.separator()
    ///   pub inline fn separator(comptime platform: Platform) u8 {
    ///       return switch (platform) {
    ///           .loose, .posix => std.fs.path.sep_posix,
    ///           .nt, .windows => std.fs.path.sep_windows,
    ///       };
    ///   }
    public func separator(): Char {
        match (this) {
            case Loose => Char('/')
            case Posix => Char('/')
            case Windows => Char('\\')
        }
    }

    /// 获取平台分隔符字节
    public func separatorByte(): UInt8 {
        match (this) {
            case Loose => SEP
            case Posix => SEP
            case Windows => SEP_WINDOWS
        }
    }

    /// 获取平台分隔符字符串
    /// 对应 Bun Platform.separatorString()
    public func separatorString(): String {
        match (this) {
            case Loose => "/"
            case Posix => "/"
            case Windows => "\\"
        }
    }

    /// 判断字符是否为分隔符
    /// 对应 Bun Platform.isSeparator()
    ///   pub inline fn isSeparator(comptime platform: Platform, char: u8) bool {
    ///       return switch (platform) {
    ///           .loose => isSepAnyT(T, char),
    ///           .posix => isSepPosixT(T, char),
    ///           .windows => isSepAnyT(T, char),
    ///       };
    ///   }
    public func isSeparator(c: Char): Bool {
        match (this) {
            case Loose => isSepAnyChar(c)
            case Posix => c == Char('/')
            case Windows => isSepAnyChar(c)
        }
    }

    /// 判断路径是否为绝对路径
    /// 对应 Bun Platform.isAbsolute()
    ///   pub fn isAbsolute(comptime platform: Platform, path: []const u8) bool {
    ///       return switch (platform) {
    ///           .posix => path.len > 0 and path[0] == '/',
    ///           .windows, .loose => std.fs.path.isAbsoluteWindows(path),
    ///       };
    ///   }
    public func isAbsolute(path: String): Bool {
        match (this) {
            case Posix => path.size > 0 && path[0] == Char('/')
            case Loose => path.size > 0 && (path[0] == Char('/') || path[0] == Char('\\'))
            case Windows =>
                if (path.size > 0 && (path[0] == Char('/') || path[0] == Char('\\'))) {
                    return true
                }
                if (path.size > 2 && isDriveLetterChar(path[0]) && path[1] == Char(':') &&
                    (path[2] == Char('/') || path[2] == Char('\\'))) {
                    return true
                }
                return false
        }
    }

    /// 获取尾部分隔符字符串
    /// 对应 Bun Platform.trailingSeparator()
    public func trailingSeparator(): String {
        match (this) {
            case Loose => "./"
            case Posix => "./"
            case Windows => ".\\"
        }
    }
}

/// 当前平台 - 对应 Bun Platform.auto
public let PLATFORM_AUTO: Platform = Platform.Posix

// ============================================================================
// 路径规范化
// 严格翻译自: src/paths/resolve_path.zig normalizeStringGeneric
//   基于 Go 的 filepath.Clean:
//   https://cs.opensource.google/go/go/+/refs/tags/go1.17.6:src/path/filepath/path.go;l=89
// ============================================================================

/// 规范化路径字符串 (通用版本)
/// 对应 Bun: normalizeStringGeneric / normalizeStringGenericTZ
/// 核心规范化算法:
///   1. 按 '/' 分割组件
///   2. 跳过 "." 和空组件
///   3. ".." 回退 (非根路径则添加 "..")
///   4. 重新组装
public func normalizeStringGeneric(
    path: String,
    allowAboveRoot: Bool,
    separator: Char,
    preserveTrailingSlash: Bool
): String {
    if (path.isEmpty) {
        return "."
    }

    let isAbsolute = path.size > 0 && path[0] == separator
    var result = ArrayList<String>()
    var dotdot: Int64 = 0  // 可以回退到的位置

    var r: Int64 = 0
    let n = path.size

    // 如果是绝对路径, 跳过前导分隔符
    let bufStart: Int64 = if (isAbsolute) {
        result.append(separator.toString())
        dotdot = 1
        r = 1
        1
    } else {
        0
    }

    while (r < n) {
        let c = path[Int64(r)]

        // 空路径元素或分隔符 - 跳过
        if (c == separator) {
            r += 1
            continue
        }

        // "." 元素 - 跳过
        if (c == Char('.') && (r + 1 == n || path[Int64(r + 1)] == separator)) {
            r += 1
            continue
        }

        // ".." 元素 - 回退
        let remaining = path.substring(Int64(r))
        if (remaining.startsWith("..") &&
            (r + 2 == n || (r + 2 < n && path[Int64(r + 2)] == separator))) {
            r += 2
            if (result.size > dotdot) {
                // 回退到上一个组件
                result.removeAt(result.size - 1)
            } else if (allowAboveRoot) {
                // 不能回退则添加 ".."
                if (result.size > Int64(bufStart) && result[result.size - 1] != "..") {
                    result.append(separator.toString())
                    result.append("..")
                } else {
                    result.append("..")
                }
                dotdot = Int64(result.size)
            }
            continue
        }

        // 真实路径元素 - 添加分隔符(如果需要)然后复制
        if (result.size > Int64(bufStart) && result.size > 0 &&
            result[result.size - 1] != separator.toString()) {
            result.append(separator.toString())
        }

        let from = r
        while (r < n && path[Int64(r)] != separator) {
            r += 1
        }
        result.append(path.substring(Int64(from), Int64(r)))
    }

    // 处理尾部分隔符
    if (preserveTrailingSlash) {
        if (path[Int64(path.size - 1)] == separator) {
            let last = result[result.size - 1]
            if (last != separator.toString()) {
                result.append(separator.toString())
            }
        }
    }

    // 组装结果
    if (result.size == 0) {
        return "."
    }

    var sb = StringBuilder()
    for (part in result) {
        sb.append(part)
    }
    let normalized = sb.toString()

    if (normalized.isEmpty) {
        return if (isAbsolute) { separator.toString() } else { "." }
    }
    return normalized
}

/// 规范化路径字符串 (简化版本, 使用 POSIX 默认值)
/// 对应 Bun: normalizeString / normalizeStringBuf
public func normalizeString(
    path: String,
    allowAboveRoot: Bool,
    platform: Platform
): String {
    let isAbsolute = platform.isAbsolute(path)
    let hasTrailingSep = path.size > 0 &&
        platform.isSeparator(path[Int64(path.size - 1)])

    if (isAbsolute && hasTrailingSep) {
        return normalizeStringGeneric(path, allowAboveRoot, platform.separator(), true)
    }
    if (isAbsolute && !hasTrailingSep) {
        return normalizeStringGeneric(path, allowAboveRoot, platform.separator(), false)
    }
    if (!isAbsolute && !hasTrailingSep) {
        return normalizeStringGeneric(path, allowAboveRoot, platform.separator(), false)
    }
    return normalizeStringGeneric(path, allowAboveRoot, platform.separator(), true)
}

// ============================================================================
// 路径连接
// 严格翻译自: src/paths/resolve_path.zig
//   pub fn joinAbsStringBuf(cwd, buf, parts, platform) []const u8
//   pub fn joinStringBuf(buf, parts, platform) []const u8
// ============================================================================

/// 连接路径片段 (相对路径)
/// 对应 Bun: join / joinStringBuf
///   pub fn joinStringBuf(buf: []u8, parts: anytype, comptime platform: Platform) []const u8 {
///       var written: usize = 0;
///       for (parts) |part| {
///           if (part.len == 0) continue;
///           if (written > 0) { temp_buf[written] = platform.separator(); written += 1; }
///           copy(u8, temp_buf[written..], part);
///           written += part.len;
///       }
///       return normalizeStringNode(temp_buf[0..written], buf, platform);
///   }
public func joinParts(parts: Array<String>, platform: Platform): String {
    // 拼接所有部分
    var sb = StringBuilder()
    var first = true
    for (part in parts) {
        if (part.isEmpty) {
            continue
        }
        if (!first) {
            sb.append(platform.separator())
        }
        first = false
        sb.append(part)
    }

    let joined = sb.toString()
    if (joined.isEmpty) {
        return "."
    }

    // 使用 Node.js 风格规范化
    return normalizeStringNode(joined, platform)
}

/// 连接路径片段 (POSIX 默认)
public func joinParts(parts: Array<String>): String {
    return joinParts(parts, Platform.Posix)
}

/// 绝对路径连接 - 对应 Bun joinAbsStringBuf / joinAbsString
///   pub fn joinAbsStringBuf(cwd, buf, parts, platform) []const u8
/// 从右到左处理路径片段, 遇到绝对路径则重置结果
public func joinAbsString(cwd: String, parts: Array<String>, platform: Platform): String {
    if (parts.size == 0) {
        return cwd
    }
    // 单独 "/" 的特殊处理
    if (parts.size == 1 && parts[0] == "/") {
        return "/"
    }

    // 找到最后一个绝对路径
    var effectiveCwd = cwd
    var startIdx: Int64 = 0
    for (i in 0..parts.size) {
        if (platform.isAbsolute(parts[Int64(i)])) {
            effectiveCwd = parts[Int64(i)]
            startIdx = Int64(i) + 1
        }
    }

    // 拼接
    var sb = StringBuilder()
    sb.append(effectiveCwd)
    for (i in startIdx..parts.size) {
        let part = parts[Int64(i)]
        if (part.isEmpty) {
            continue
        }
        let current = sb.toString()
        if (current.size > 0 && !platform.isSeparator(current[Int64(current.size - 1)])) {
            sb.append(platform.separator())
        }
        sb.append(part)
    }

    // 规范化结果
    let joined = sb.toString()
    return normalizeString(joined, false, platform)
}

// ============================================================================
// Node.js 风格路径规范化
// 严格翻译自: src/paths/resolve_path.zig
//   pub fn normalizeStringNode(str, buf, platform) []const T
// 这是 Node.js path.normalize 的核心实现
// ============================================================================

/// Node.js 风格路径规范化
/// 对应 Bun: normalizeStringNode / normalizeStringNodeT
///   pub fn normalizeStringNode(str, buf, platform) []const T {
///       if (str.len == 0) { buf[0] = '.'; return buf[0..1]; }
///       const is_absolute = platform.isAbsoluteT(T, str);
///       const trailing_separator = platform.isSeparatorT(T, str[str.len - 1]);
///       var out = if (!is_absolute) normalizeStringGeneric(str, true, ...)
///                 else normalizeStringGeneric(str, false, ...);
///       if (out.len == 0) { ... }
///       if (trailing_separator) { ... }
///       if (is_absolute) { buf[0] = separator; ... }
///       return out;
///   }
public func normalizeStringNode(path: String, platform: Platform): String {
    if (path.isEmpty) {
        return "."
    }

    let isAbsolute = platform.isAbsolute(path)
    let hasTrailingSep = platform.isSeparator(path[Int64(path.size - 1)])

    // 规范化 (绝对路径不允许回退到根之上)
    var result = normalizeStringGeneric(
        path,
        !isAbsolute,  // allowAboveRoot 仅在相对路径时为 true
        platform.separator(),
        false
    )

    if (result == ".") {
        if (isAbsolute) {
            return platform.separator().toString()
        }
        if (hasTrailingSep) {
            return platform.trailingSeparator()
        }
        return "."
    }

    // 处理尾部分隔符
    if (hasTrailingSep && !platform.isSeparator(result[Int64(result.size - 1)])) {
        result = result + platform.separator().toString()
    }

    // 处理绝对路径前缀
    if (isAbsolute && !result.startsWith(platform.separator().toString())) {
        result = platform.separator().toString() + result
    }

    return result
}

// ============================================================================
// 相对路径计算
// 严格翻译自: src/paths/resolve_path.zig
//   pub fn longestCommonPathGeneric(input, platform) []const u8
//   pub fn relativeToCommonPath(common_path, normalized_from, normalized_to, buf, ...)
//   pub fn relative(from, to) []const u8
// ============================================================================

/// 查找最长公共路径
/// 对应 Bun: longestCommonPathGeneric
///   pub fn longestCommonPathGeneric(input: []const []const u8, comptime platform: Platform) []const u8 {
///       var index: usize = 0;
///       var last_common_separator: usize = 0;
///       while (index < min_length) {
///           if (nqlAtIndexFn(N, index, input)) break;
///           if (isPathSeparator(input[0][index])) last_common_separator = index;
///           index += 1;
///       }
///       ...
///       return input[0][0..last_common_separator + 1];
///   }
public func longestCommonPath(paths: Array<String>, platform: Platform): String {
    if (paths.size == 0) {
        return ""
    }
    if (paths.size == 1) {
        return paths[0]
    }

    // 找到最短路径长度
    var minLen: Int64 = Int64.MAX_VALUE
    for (p in paths) {
        if (p.size < minLen) {
            minLen = p.size
        }
    }

    let separator = platform.separator()
    var index: Int64 = 0
    var lastCommonSep: Int64 = 0

    // 逐字符比较所有路径
    while (index < minLen) {
        let c = paths[0][Int64(index)]
        var allEqual = true
        for (i in 1..paths.size) {
            if (paths[Int64(i)][Int64(index)] != c) {
                allEqual = false
                break
            }
        }
        if (!allEqual) {
            break
        }
        if (c == separator) {
            lastCommonSep = index
        }
        index += 1
    }

    if (index == 0) {
        return separator.toString()
    }

    // 检查是否有路径在 index 位置刚好是分隔符
    // 对应 Bun: "do one of you have a path separator after what we thought was the end?"
    for (p in paths) {
        if (p.size > index && platform.isSeparator(p[Int64(index)])) {
            return p.substring(0, Int64(index + 1))
        }
    }

    return paths[0].substring(0, Int64(lastCommonSep + 1))
}

/// 计算相对路径 (核心算法)
/// 对应 Bun: relativeToCommonPath
///   pub fn relativeToCommonPath(common_path_, normalized_from_, normalized_to_, buf, always_copy, platform) []const u8 {
///       // 1. 找到最后一个公共分隔符
///       // 2. 从 from 到公共路径用 ".." 回退
///       // 3. 追加 to 的剩余部分
///   }
public func relativeToCommonPath(
    commonPath: String,
    normalizedFrom: String,
    normalizedTo: String,
    platform: Platform
): String {
    let separator = platform.separator()

    // 去除绝对路径前导 '/'
    var from = normalizedFrom
    var to = normalizedTo
    let common = if (commonPath.startsWith(separator.toString())) {
        commonPath.substring(1)
    } else {
        commonPath
    }

    // 找到最后一个公共分隔符
    let lastCommonSep = common.lastIndexOf(separator)
    let lastCommonIdx: Int64 = if (lastCommonSep >= 0) { Int64(lastCommonSep) } else { 0 }

    var sb = StringBuilder()

    // 从 from 到公共路径用 ".." 回退
    if (from.size > 0) {
        let fromRemaining = from.substring(Int64(lastCommonIdx))
        var i: Int64 = 0
        while (i <= fromRemaining.size) {
            if (i == fromRemaining.size ||
                (fromRemaining[Int64(i)] == separator && i + 1 < fromRemaining.size)) {
                if (sb.length() == 0) {
                    sb.append("..")
                } else {
                    sb.append(separator)
                    sb.append("..")
                }
            }
            i += 1
        }
    }

    // 追加 to 的剩余部分
    if (to.size > lastCommonIdx + 1) {
        var tail = to.substring(Int64(lastCommonIdx))
        // 去除前导分隔符 (如果需要)
        if (tail.size > 0 && platform.isSeparator(tail[0])) {
            tail = tail.substring(1)
        }

        // 避免使非绝对路径变成绝对路径
        if (tail.size > 0 && !platform.isSeparator(tail[0]) &&
            sb.length() > 0 && !platform.isSeparator(sb.toString()[Int64(sb.length() - 1)])) {
            sb.append(separator)
        }

        sb.append(tail)
    }

    // 去除尾部分隔符
    var result = sb.toString()
    if (result.size > 3 && result[Int64(result.size - 1)] == separator) {
        result = result.substring(0, Int64(result.size - 1))
    }

    return result
}

/// 计算两个路径之间的相对路径
/// 对应 Bun: relative / relativePlatform
///   pub fn relative(from: []const u8, to: []const u8) []const u8 {
///       return relativePlatform(from, to, .auto, false);
///   }
public func relativePath(from: String, to: String, platform: Platform): String {
    // 先规范化两个路径
    let normalizedFrom = normalizeStringNode(
        if (platform.isAbsolute(from)) { from } else { "/" + from },
        platform
    )
    let normalizedTo = normalizeStringNode(
        if (platform.isAbsolute(to)) { to } else { "/" + to },
        platform
    )

    // 如果相同则返回空
    if (normalizedFrom == normalizedTo) {
        return ""
    }

    // 找最长公共路径
    let paths = Array<String>([normalizedFrom, normalizedTo])
    let commonPath = longestCommonPath(paths, platform)

    return relativeToCommonPath(commonPath, normalizedFrom, normalizedTo, platform)
}

/// POSIX 默认的相对路径
public func relativePath(from: String, to: String): String {
    return relativePath(from, to, Platform.Posix)
}

// ============================================================================
// Windows 文件系统根检测
// 严格翻译自: src/paths/resolve_path.zig
//   pub fn windowsFilesystemRoot(path: []const u8) []const u8
//   pub fn windowsVolumeNameLen(path: []const u8) struct { usize, usize }
//   pub fn isDriveLetter(c: u8) bool
// ============================================================================

/// 获取 Windows 文件系统根
/// 对应 Bun: windowsFilesystemRoot / windowsFilesystemRootT
///   pub fn windowsFilesystemRootT(comptime T: type, path: []const T) []const T {
///       if (path.len < 2) return if (isSepAnyT(T, path[0])) path[0..1] else path[0..0];
///       // drive letter: C: or C:\
///       if (path[1] == ':') {
///           if (isDriveLetterT(T, path[0])) {
///               if (path.len > 2 && isSepAnyT(T, path[2])) return path[0..3];
///               else return path[0..2];
///           }
///       }
///       // UNC and device paths ...
///       if (isSepAnyT(T, path[0])) return path[0..1];
///       return path[0..0];
///   }
public func windowsFilesystemRoot(path: String): String {
    if (path.isEmpty) {
        return ""
    }
    if (path.size < 2) {
        return if (isSepAnyChar(path[0])) { path.substring(0, 1) } else { "" }
    }
    // 驱动器号: "C:" 或 "C:\"
    if (path[1] == Char(':') && isDriveLetterChar(path[0])) {
        if (path.size > 2 && isSepAnyChar(path[2])) {
            return path.substring(0, 3)
        }
        return path.substring(0, 2)
    }
    // UNC 路径: "\\server\share\"
    if (path.size >= 5 && isSepAnyChar(path[0]) && isSepAnyChar(path[1]) &&
        !isSepAnyChar(path[2])) {
        // 设备路径: "\\."
        if (path[2] == Char('.') && isSepAnyChar(path[3])) {
            return path.substring(0, 4)
        }
        // UNC: 查找第二和第三个分隔符
        var idx1 = path.indexOf('/', 3)
        if (idx1 < 0) {
            idx1 = path.indexOf('\\', 3)
        }
        if (idx1 >= 0) {
            let remaining = path.substring(Int64(idx1 + 1))
            var idx2 = remaining.indexOf('/')
            if (idx2 < 0) {
                idx2 = remaining.indexOf('\\')
            }
            if (idx2 >= 0) {
                return path.substring(0, Int64(idx1 + 1 + idx2 + 1 + 1))
            }
        }
        return path
    }
    // 单个分隔符
    if (isSepAnyChar(path[0])) {
        return path.substring(0, 1)
    }
    return ""
}

/// 获取 Windows 卷名长度
/// 对应 Bun: windowsVolumeNameLen
///   pub fn windowsVolumeNameLen(path: []const u8) struct { usize, usize }
/// 返回 (卷名长度, 第三个UNC斜杠位置)
public func windowsVolumeNameLen(path: String): Tuple<Int64, Int64> {
    if (path.size < 2) {
        return Tuple<Int64, Int64>(0, 0)
    }
    // 驱动器号
    if (path[1] == Char(':') && isDriveLetterChar(path[0])) {
        return Tuple<Int64, Int64>(2, 0)
    }
    // UNC 路径
    if (path.size >= 5 && isSepAnyChar(path[0]) && isSepAnyChar(path[1]) &&
        !isSepAnyChar(path[2]) && path[2] != Char('.')) {
        var idx = path.indexOfAny("/\\", 3)
        if (idx >= 0) {
            let idx2 = path.indexOfAny("/\\", idx + 1)
            if (idx2 >= 0) {
                return Tuple<Int64, Int64>(Int64(idx2 + 1), Int64(idx + 1))
            }
            return Tuple<Int64, Int64>(Int64(path.size), Int64(idx + 1))
        }
        return Tuple<Int64, Int64>(Int64(path.size), 0)
    }
    return Tuple<Int64, Int64>(0, 0)
}

/// 获取 Windows 卷名
/// 对应 Bun: windowsVolumeName
public func windowsVolumeName(path: String): String {
    let (len, _) = windowsVolumeNameLen(path)
    return path.substring(0, Int64(len))
}
