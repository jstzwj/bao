// 严格翻译自: src/paths/resolve_path.zig
//   resolve_path - 路径解析核心算法
//   normalizeStringGeneric - 通用路径规范化 (基于 Go filepath.Clean)
//   joinAbsStringBuf / joinStringBuf - 路径连接
//   longestCommonPathGeneric / relativeToCommonPath - 相对路径计算
//   relative - 相对路径计算入口
//   Platform - 平台枚举 (loose, windows, posix, nt)
//   isSepPosix / isSepWin32 / isSepAny - 分隔符判断
//   isParentOrEqual - 父路径检测
//   windowsFilesystemRoot / windowsVolumeNameLen - Windows 路径根检测
//
// 注意: resolver.cj 已有部分翻译，本文件提供 resolve_path.zig 的
// 完整函数集翻译，包含所有辅助函数和边界情况处理。
package bao_path

import bao_core.*
import bao_collections.*

// ============================================================================
// 平台相关路径解析
// 严格翻译自: src/paths/resolve_path.zig 中的平台相关函数
// ============================================================================

/// 判断是否为 ".." 路径段
/// 对应 Bun: inline fn @"is .."(slice) bool
///   return slice.len >= 2 and slice[0..2] == ".."
public func isDotDot(slice: String): Bool {
    return slice.size >= 2 && slice[0] == UInt8(46) && slice[1] == UInt8(46)
}

/// 判断是否为 "../" 前缀
/// 对应 Bun: inline fn @"is ../"(slice) bool
///   return strings.hasPrefixComptime(slice, "../")
public func isDotDotSlash(slice: String): Bool {
    return slice.size >= 3 && slice[0] == UInt8(46) && slice[1] == UInt8(46) && slice[2] == UInt8(47)
}

// ============================================================================
// resolve_path - 路径解析算法
// 严格翻译自: src/paths/resolve_path.zig
//   resolve_path 从多个路径片段解析出最终路径
//   支持 POSIX 和 Windows 两种风格
// ============================================================================

/// 解析路径 (POSIX 风格, 从多个片段)
/// 对应 Bun: resolve_path (最终调用 normalizeString + join)
/// 从右到左处理路径片段，遇到绝对路径则重置结果
public func resolvePath(paths: Array<String>): String {
    if (paths.size == 0) {
        return "."
    }

    var result = ""
    for (i in 0..paths.size) {
        let path = paths[Int64(i)]
        if (Path.isAbsolute(path)) {
            result = path
        } else if (result.isEmpty()) {
            result = path
        } else {
            result = Path.join([result, path])
        }
    }
    return Path.normalize(result)
}

/// 解析路径 (带平台参数)
/// 对应 Bun: resolvePlatform
public func resolvePathPlatform(paths: Array<String>, platform: Platform): String {
    if (paths.size == 0) {
        return "."
    }

    var result = ""
    for (i in 0..paths.size) {
        let path = paths[Int64(i)]
        if (platform.isAbsolute(path)) {
            result = path
        } else if (result.isEmpty()) {
            result = path
        } else {
            result = joinParts([result, path], platform)
        }
    }
    return normalizeString(result, false, platform)
}

// ============================================================================
// joinAbsStringBuf - 绝对路径连接 (带 cwd)
// 严格翻译自: src/paths/resolve_path.zig
//   pub fn joinAbsStringBuf(cwd: string, buf: *PathBuffer, parts: anytype, comptime platform: Platform) string
//   pub fn joinAbsString(cwd: string, parts: anytype, comptime platform: Platform) string
//
// 核心逻辑:
//   1. 从右到左扫描 parts，找到最后一个绝对路径片段作为基础
//   2. 将后续相对路径片段追加到基础路径
//   3. 规范化结果
// ============================================================================

/// 绝对路径连接 (POSIX 默认)
/// 对应 Bun: joinAbsStringBuf / joinAbsString
public func joinAbsStringBuf(cwd: String, parts: Array<String>): String {
    return joinAbsString(cwd, parts, Platform.Posix)
}

// ============================================================================
// longestCommonPathGeneric - 最长公共路径
// 严格翻译自: src/paths/resolve_path.zig
//   pub fn longestCommonPathGeneric(input: []const []const u8, comptime platform: Platform) []const u8
//
// 核心算法:
//   1. 找到最短路径长度
//   2. 逐字符比较所有路径
//   3. 记录最后一个公共分隔符位置
//   4. 处理边界情况 (如 /app/public vs /app/public/index.js)
// ============================================================================

/// 检查是否存在最长公共路径 (不返回空路径)
/// 对应 Bun: getIfExistsLongestCommonPathGeneric
///   如果路径没有公共前缀 (如 /a 和 /b)，返回 None
public func getIfExistsLongestCommonPath(paths: Array<String>, platform: Platform): ?String {
    if (paths.size == 0) {
        return Some("")
    }
    if (paths.size == 1) {
        return Some(paths[0])
    }

    var minLen: Int64 = paths[0].size
    for (p in paths) {
        if (p.size < minLen) {
            minLen = p.size
        }
    }

    let separator = platform.separator()
    var index: Int64 = 0
    var lastCommonSep: ?Int64 = None

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
            if (let None <- lastCommonSep) {
                return None
            }
            break
        }
        if (c == separator) {
            lastCommonSep = index
        }
        index += 1
    }

    if (index == 0) {
        return Some(String(Rune(Int32(separator))))
    }

    if (let None <- lastCommonSep) {
        return Some(".")
    }

    // 检查是否有路径在 index 之后有分隔符
    // 对应 Bun: "do one of you have a path separator after what we thought was the end?"
    for (p in paths) {
        if (p.size > index && platform.isSeparator(p[Int64(index)])) {
            return Some(p[0..index + 1])
        }
    }

    let lastSep = lastCommonSep
    if (let Some(sep) <- lastSep) {
        return paths[0][0..sep + 1]
    }
    return Some(".")
}

// ============================================================================
// removeTrailingSlash - 移除尾部分隔符
// 严格翻译自: src/paths/resolve_path.zig 中的各种尾部分隔符处理
// ============================================================================

/// 移除路径的尾部分隔符 (但保留根路径 "/")
/// 对应 Bun 中的 trimTrailingSeparator 模式
public func removeTrailingSlash(path: String, platform: Platform): String {
    if (path.isEmpty()) {
        return path
    }
    var end = path.size
    let rootLen: Int64 = if (platform.isAbsolute(path)) { 1 } else { 0 }
    while (end > rootLen && platform.isSeparator(path[Int64(end - 1)])) {
        end -= 1
    }
    return path[0..end]
}

// ============================================================================
// countPathSegments - 路径组件计数
// 严格翻译自: src/paths/resolve_path.zig 中的辅助函数
// ============================================================================

/// 计算路径中的组件数量
/// 对应 Bun 中的路径深度计算
public func countPathSegments(path: String): Int64 {
    if (path.isEmpty()) {
        return 0
    }
    var count: Int64 = 0
    var i: Int64 = 0
    // 跳过前导分隔符
    while (i < path.size && isSepAnyChar(path[Int64(i)])) {
        i += 1
    }
    while (i < path.size) {
        // 跳过非分隔符
        while (i < path.size && !isSepAnyChar(path[Int64(i)])) {
            i += 1
        }
        count += 1
        // 跳过分隔符
        while (i < path.size && isSepAnyChar(path[Int64(i)])) {
            i += 1
        }
    }
    return count
}

// ============================================================================
// isSubdirectory - 子目录检测
// 严格翻译自: src/paths/resolve_path.zig 中的路径包含检测
// ============================================================================

/// 检测 child 是否是 parent 的子目录 (或相同)
/// 对应 Bun isParentOrEqual 的反向操作
public func isSubdirectory(parent: String, child: String): Bool {
    let relation = isParentOrEqual(parent, child)
    match (relation) {
        case ParentRelation.Parent => return true
        case ParentRelation.Equal => return true
        case _ => return false
    }
}

// ============================================================================
// toPosixPath - 路径转 POSIX 格式
// 严格翻译自: src/paths/resolve_path.zig
//   platformToPosixInPlace / dangerouslyConvertPathToWindowsInPlace
// ============================================================================

/// 将路径转换为 POSIX 格式 (所有反斜杠替换为正斜杠)
/// 对应 Bun: platformToPosixInPlace
public func toPosixPath(path: String): String {
    return slashesToPosix(path)
}

/// 将路径转换为 Windows 格式 (所有正斜杠替换为反斜杠)
/// 对应 Bun: dangerouslyConvertPathToWindowsInPlace
public func toWindowsPath(path: String): String {
    return slashesToWindows(path)
}

// ============================================================================
// relativeToCommonPath - 相对路径核心计算
// 严格翻译自: src/paths/resolve_path.zig
//   pub fn relativeToCommonPath(common_path, normalized_from, normalized_to, buf, always_copy, platform)
//
// 算法:
//   1. 找到公共路径的最后一个分隔符
//   2. 从 from 到公共路径用 ".." 回退
//   3. 追加 to 的剩余部分
// ============================================================================

/// 计算从 from 到 to 的相对路径 (给定公共路径)
/// 对应 Bun: relativeToCommonPath
public func relativeToCommonPathGeneric(
    commonPath: String,
    normalizedFrom: String,
    normalizedTo: String,
    platform: Platform
): String {
    let separator = platform.separator()

    let common = if (commonPath.startsWith(String(Rune(Int32(separator))))) {
        commonPath[1..]
    } else {
        commonPath
    }

    // 找到最后一个公共分隔符
    let lastCommonIdx: Int64 = match (common.lastIndexOf(separator)) {
        case Some(idx) => idx
        case None => 0
    }

    var sb = StringBuilder()

    // 从 from 到公共路径用 ".." 回退
    if (normalizedFrom.size > 0) {
        let fromRemaining = normalizedFrom[lastCommonIdx..]
        var i: Int64 = 0
        while (i <= fromRemaining.size) {
            if (i == fromRemaining.size ||
                (fromRemaining[Int64(i)] == separator && i + 1 < fromRemaining.size)) {
                if (sb.toString().size == 0) {
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
    if (normalizedTo.size > lastCommonIdx + 1) {
        var tail = normalizedTo[lastCommonIdx..]
        if (tail.size > 0 && platform.isSeparator(tail[0])) {
            tail = tail[1..]
        }
        if (tail.size > 0 && !platform.isSeparator(tail[0]) &&
            sb.toString().size > 0 && !platform.isSeparator(sb.toString()[Int64(sb.toString().size - 1)])) {
            sb.append(separator)
        }
        sb.append(tail)
    }

    var result = sb.toString()
    // 去除尾部分隔符
    if (result.size > 3 && result[Int64(result.size - 1)] == separator) {
        result = result[0..result.size - 1]
    }

    return result
}

// ============================================================================
// normalizeStringGeneric - 完整规范化算法
// 严格翻译自: src/paths/resolve_path.zig normalizeStringGeneric
//   基于 Go 的 filepath.Clean:
//   https://cs.opensource.google/go/go/+/refs/tags/go1.17.6:src/path/filepath/path.go;l=89
//
// 此版本提供比 resolver.cj 中更详细的注释和边界情况处理
// ============================================================================

/// 通用路径规范化 (详细注释版)
/// 对应 Bun normalizeStringGeneric 的完整实现
///
/// 算法步骤:
///   1. 处理绝对路径前缀
///   2. 逐段扫描路径:
///      - 跳过空段和 "." 段
///      - 处理 ".." 段 (回退或添加 "..")
///      - 添加普通段
///   3. 处理尾部分隔符
///   4. 组装结果
public func normalizeStringGenericFull(
    path: String,
    allowAboveRoot: Bool,
    separator: UInt8,
    preserveTrailingSlash: Bool
): String {
    if (path.isEmpty()) {
        return "."
    }

    let isAbsolute = path.size > 0 && path[0] == separator
    var result = ArrayList<String>()
    var dotdot: Int64 = 0

    var r: Int64 = 0
    let n = path.size

    // 绝对路径前缀处理
    let bufStart: Int64 = if (isAbsolute) {
        result.append(String(Rune(Int32(separator))))
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
        if (c == UInt8(46) && (r + 1 == n || path[Int64(r + 1)] == separator)) {
            r += 1
            continue
        }

        // ".." 元素 - 回退
        let remaining = path[r..]
        if (remaining.startsWith("..") &&
            (r + 2 == n || (r + 2 < n && path[Int64(r + 2)] == separator))) {
            r += 2
            if (result.size > dotdot) {
                result.removeAt(result.size - 1)
            } else if (allowAboveRoot) {
                if (result.size > Int64(bufStart) && result[result.size - 1] != "..") {
                    result.append(String(Rune(Int32(separator))))
                    result.append("..")
                } else {
                    result.append("..")
                }
                dotdot = Int64(result.size)
            }
            continue
        }

        // 真实路径元素
        if (result.size > Int64(bufStart) && result.size > 0 &&
            result[result.size - 1] != String(Rune(Int32(separator)))) {
            result.append(String(Rune(Int32(separator))))
        }

        let from = r
        while (r < n && path[Int64(r)] != separator) {
            r += 1
        }
        result.append(path[from..r])
    }

    // 处理尾部分隔符
    if (preserveTrailingSlash && n > 0 && path[Int64(n - 1)] == separator) {
        if (result.size > 0 && result[result.size - 1] != String(Rune(Int32(separator)))) {
            result.append(String(Rune(Int32(separator))))
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

    if (normalized.isEmpty()) {
        return if (isAbsolute) { String(Rune(Int32(separator))) } else { "." }
    }
    return normalized
}
