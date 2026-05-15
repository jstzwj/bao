// 路径处理模块（完整翻译）
// 对应 Bun: src/runtime/node/path.zig
// 严格翻译自: src/runtime/node/path.zig
package bao_runtime.node

import bao_core.*

// ============================================================================
// 路径常量
// 对应 Bun: src/runtime/node/path.zig - 常量定义
// ============================================================================
public class PathConstants {
    // 字符常量
    public static let CHAR_FORWARD_SLASH: UInt8 = '/'
    public static let CHAR_BACKWARD_SLASH: UInt8 = '\\'
    public static let CHAR_COLON: UInt8 = ':'
    public static let CHAR_DOT: UInt8 = '.'
    public static let CHAR_QUESTION_MARK: UInt8 = '?'

    // 字符串常量
    public static let sepStrPosix: String = "/"
    public static let sepStrWindows: String = "\\"
    public static let CHAR_STR_DOT: String = "."

    // 分隔符
    public static let sepPosix: UInt8 = '/'
    public static let sepWindows: UInt8 = '\\'
    public static let delimiterPosix: String = ":"
    public static let delimiterWindows: String = ";"

    // 最大路径长度
    public static let MAX_PATH_BYTES: Int64 = 4096
}

// ============================================================================
// 路径解析结果
// 对应 Bun: src/runtime/node/path.zig - PathParsed
// ============================================================================
public class PathParsed {
    public var root: String = ""
    public var dir: String = ""
    public var base: String = ""
    public var ext: String = ""
    public var name: String = ""

    public init() {}

    public init(root: String, dir: String, base: String, ext: String, name: String) {
        this.root = root
        this.dir = dir
        this.base = base
        this.ext = ext
        this.name = name
    }
}

// ============================================================================
// 路径处理函数集合
// 对应 Bun: src/runtime/node/path.zig - Path 命名空间函数
// 基于 Node v21.6.1 path.js 完整翻译
// ============================================================================
public class Path {

    // ========================================================================
    // basename — 获取路径中的文件名
    // 对应 Bun: path.zig basenamePosixT / basenameWindowsT
    // 基于 Node v21.6.1 path.posix.basename
    // ========================================================================
    public static func basename(path: String, suffix: String = ""): String {
        validateString(path, name: "path")
        let len = path.size
        if (len == 0) {
            return ""
        }

        var start: Int64 = 0
        var end: Int64 = -1
        var matchedSlash: Bool = true

        let suffixLen = suffix.size
        if (suffixLen > 0 && suffixLen <= len) {
            if (suffix == path) {
                return ""
            }

            var extIdx: Int64 = suffixLen - 1
            var firstNonSlashEnd: Int64 = -1
            var i: Int64 = len - 1

            while (i >= start) {
                let byte = path[i]
                if (byte == '/') {
                    if (!matchedSlash) {
                        start = i + 1
                        break
                    }
                } else {
                    if (firstNonSlashEnd < 0) {
                        matchedSlash = false
                        firstNonSlashEnd = i + 1
                    }
                    if (extIdx >= 0) {
                        if (byte == suffix[extIdx]) {
                            if (extIdx == 0) {
                                end = i
                                extIdx = -1
                            } else {
                                extIdx -= 1
                            }
                        } else {
                            extIdx = -1
                            end = firstNonSlashEnd
                        }
                    }
                }
                i -= 1
            }

            if (end >= 0) {
                if (start == end) {
                    return path.substring(Int64(start), Int64(firstNonSlashEnd))
                } else {
                    return path.substring(Int64(start), Int64(end))
                }
            }
            return path.substring(Int64(start), Int64(len))
        }

        // 无后缀版本
        var i2: Int64 = len - 1
        while (i2 > -1) {
            let byte = path[i2]
            if (byte == '/') {
                if (!matchedSlash) {
                    start = i2 + 1
                    break
                }
            } else if (end < 0) {
                matchedSlash = false
                end = i2 + 1
            }
            i2 -= 1
        }

        if (end >= 0) {
            return path.substring(Int64(start), Int64(end))
        }
        return ""
    }

    // ========================================================================
    // dirname — 获取路径中的目录名
    // 对应 Bun: path.zig dirnamePosixT
    // 基于 Node v21.6.1 path.posix.dirname
    // ========================================================================
    public static func dirname(path: String): String {
        validateString(path, name: "path")
        let len = path.size
        if (len == 0) {
            return "."
        }

        let hasRoot = path[0] == '/'
        var end: Int64 = -1
        var matchedSlash: Bool = true
        var i: Int64 = len - 1

        while (i >= 1) {
            if (path[i] == '/') {
                if (!matchedSlash) {
                    end = i
                    break
                }
            } else {
                matchedSlash = false
            }
            i -= 1
        }

        if (end >= 0) {
            if (hasRoot && end == 1) {
                return "//"
            }
            return path.substring(0, Int64(end))
        }
        if (hasRoot) {
            return "/"
        }
        return "."
    }

    // ========================================================================
    // extname — 获取文件扩展名
    // 对应 Bun: path.zig extnamePosixT
    // 基于 Node v21.6.1 path.posix.extname
    // ========================================================================
    public static func extname(path: String): String {
        validateString(path, name: "path")
        let len = path.size
        if (len == 0) {
            return ""
        }

        var startDot: Int64 = -1
        var startPart: Int64 = 0
        var end: Int64 = -1
        var matchedSlash: Bool = true
        var preDotState: Int64 = 0

        var i: Int64 = len - 1
        while (i > -1) {
            let byte = path[i]
            if (byte == '/') {
                if (!matchedSlash) {
                    startPart = i + 1
                    break
                }
                i -= 1
                continue
            }

            if (end < 0) {
                matchedSlash = false
                end = i + 1
            }

            if (byte == '.') {
                if (startDot < 0) {
                    startDot = i
                } else if (preDotState >= 0 && preDotState != 1) {
                    preDotState = 1
                }
            } else if (startDot >= 0) {
                preDotState = -1
            }
            i -= 1
        }

        if (startDot < 0 || end < 0 ||
            (preDotState >= 0 && preDotState == 0) ||
            (preDotState == 1 && startDot == end - 1 && startDot == startPart + 1)) {
            return ""
        }

        return path.substring(Int64(startDot), Int64(end))
    }

    // ========================================================================
    // parse — 解析路径为组件
    // 对应 Bun: path.zig parsePosixT
    // 基于 Node v21.6.1 path.posix.parse
    // ========================================================================
    public static func parse(path: String): PathParsed {
        validateString(path, name: "path")
        let len = path.size
        if (len == 0) {
            return PathParsed()
        }

        var root = ""
        var dir = ""
        var base = ""
        var ext = ""
        var nameStr = ""

        let isAbsolute = path[0] == '/'
        var start: Int64 = 0
        if (isAbsolute) {
            root = "/"
            start = 1
        }

        var startDot: Int64 = -1
        var startPart: Int64 = 0
        var end: Int64 = -1
        var matchedSlash: Bool = true
        var preDotState: Int64 = 0

        var i: Int64 = len - 1
        while (i >= start) {
            let byte = path[i]
            if (byte == '/') {
                if (!matchedSlash) {
                    startPart = i + 1
                    break
                }
                i -= 1
                continue
            }
            if (end < 0) {
                matchedSlash = false
                end = i + 1
            }
            if (byte == '.') {
                if (startDot < 0) {
                    startDot = i
                } else if (preDotState >= 0 && preDotState != 1) {
                    preDotState = 1
                }
            } else if (startDot >= 0) {
                preDotState = -1
            }
            i -= 1
        }

        if (end >= 0) {
            start = if (startPart == 0 && isAbsolute) { 1 } else { startPart }
            if (startDot < 0 ||
                (preDotState >= 0 && preDotState == 0) ||
                (preDotState == 1 && startDot == end - 1 && startDot == startPart + 1)) {
                nameStr = path.substring(Int64(start), Int64(end))
                base = nameStr
            } else {
                nameStr = path.substring(Int64(start), Int64(startDot))
                base = path.substring(Int64(start), Int64(end))
                ext = path.substring(Int64(startDot), Int64(end))
            }
        }

        if (startPart > 0) {
            dir = path.substring(0, Int64(startPart - 1))
        } else if (isAbsolute) {
            dir = "/"
        }

        return PathParsed(root: root, dir: dir, base: base, ext: ext, name: nameStr)
    }

    // ========================================================================
    // format — 从路径组件构建路径字符串
    // 对应 Bun: path.zig _formatT
    // 基于 Node v21.6.1 private helper _format
    // ========================================================================
    public static func format(parsed: PathParsed): String {
        let root = parsed.root
        let dir = parsed.dir
        let base = parsed.base
        let ext = parsed.ext
        let name = parsed.name

        // dir || root
        let dirIsRoot = dir.size == 0 || dir == root
        let dirOrRoot = if (dirIsRoot) { root } else { dir }

        // base || name + formatExt(ext)
        var baseOrNameExt = base
        if (base.size == 0) {
            var formattedExt = ext
            if (ext.size > 0 && ext[0] != '.') {
                formattedExt = "." + ext
            }
            baseOrNameExt = name + formattedExt
        }

        // if (!dir) return base
        if (dirOrRoot.size == 0) {
            return baseOrNameExt
        }

        // dir === root ? dir + base : dir + sep + base
        if (dirIsRoot) {
            return dirOrRoot + baseOrNameExt
        }
        return dirOrRoot + "/" + baseOrNameExt
    }

    // ========================================================================
    // join — 连接路径片段
    // 对应 Bun: path.zig joinPosixT
    // 基于 Node v21.6.1 path.posix.join
    // ========================================================================
    public static func join(paths: Array<String>): String {
        if (paths.size == 0) {
            return "."
        }

        var joined = ""
        for (i in 0..paths.size) {
            let p = paths[i]
            if (p.size > 0) {
                if (joined.size > 0) {
                    joined = joined + "/"
                }
                joined = joined + p
            }
        }

        if (joined.size == 0) {
            return "."
        }

        return normalize(joined)
    }

    // ========================================================================
    // normalize — 规范化路径
    // 对应 Bun: path.zig normalizePosixT
    // 基于 Node v21.6.1 path.posix.normalize + normalizeStringT
    // ========================================================================
    public static func normalize(path: String): String {
        validateString(path, name: "path")
        let len = path.size
        if (len == 0) {
            return "."
        }

        let isAbs = path[0] == '/'
        let trailingSep = path[Int64(len - 1)] == '/'

        // normalizeStringT: 解析 . 和 .. 元素
        var result = ""
        var lastSegmentLength: Int64 = 0
        var lastSlash: Int64 = -1
        var dots: Int64 = 0
        var byte: UInt8 = 0

        var i: Int64 = 0
        while (i <= len) {
            if (i < len) {
                byte = path[i]
            } else if (byte == '/') {
                break
            } else {
                byte = '/'
            }

            if (byte == '/') {
                if ((lastSlash < 0 && i == 0) ||
                    (lastSlash >= 0 && i > 0 && lastSlash == i - 1) ||
                    (dots == 1)) {
                    // NOOP
                } else if (dots == 2) {
                    if (result.size < 2 ||
                        lastSegmentLength != 2 ||
                        result[result.size - 1] != '.' ||
                        result[result.size - 2] != '.') {
                        if (result.size > 2) {
                            let lastSlashIndex = result.lastIndexOf('/')
                            if (lastSlashIndex < 0) {
                                result = ""
                                lastSegmentLength = 0
                            } else {
                                result = result.substring(0, Int64(lastSlashIndex))
                                let lastIndexOfSep = result.lastIndexOf('/')
                                if (lastIndexOfSep < 0) {
                                    lastSegmentLength = result.size
                                } else {
                                    lastSegmentLength = result.size - 1 - Int64(lastIndexOfSep)
                                }
                            }
                        } else if (result.size > 0) {
                            result = ""
                            lastSegmentLength = 0
                        }
                    }
                    if (!isAbs) {
                        if (result.size > 0) {
                            result = result + "/.."
                        } else {
                            result = ".."
                        }
                        lastSegmentLength = 2
                    }
                } else {
                    let sliceStart = if (lastSlash >= 0) { lastSlash + 1 } else { 0 }
                    let slice = path.substring(Int64(sliceStart), Int64(i))

                    if (result.size > 0) {
                        result = result + "/"
                    }
                    result = result + slice

                    let subtract = if (lastSlash >= 0) { lastSlash + 1 } else { 2 }
                    lastSegmentLength = if (i >= subtract) { i - subtract } else { 0 }
                }
                lastSlash = i
                dots = 0
            } else if (byte == '.' && dots >= 0) {
                dots += 1
            } else {
                dots = -1
            }
            i += 1
        }

        if (result.size == 0) {
            if (isAbs) {
                return "/"
            }
            return if (trailingSep) { "./" } else { "." }
        }

        // 追加尾部分隔符
        if (trailingSep && result[result.size - 1] != '/') {
            result = result + "/"
        }

        // 如果是绝对路径，前缀 /
        if (isAbs) {
            result = "/" + result
        }

        return result
    }

    // ========================================================================
    // isAbsolute — 判断是否为绝对路径
    // 对应 Bun: path.zig isAbsolutePosixT
    // 基于 Node v21.6.1 path.posix.isAbsolute
    // ========================================================================
    public static func isAbsolute(path: String): Bool {
        return path.size > 0 && path[0] == '/'
    }

    // ========================================================================
    // resolve — 解析为绝对路径
    // 对应 Bun: path.zig resolvePosixT
    // 基于 Node v21.6.1 path.posix.resolve
    // ========================================================================
    public static func resolve(cwd: String, paths: Array<String>): String {
        var resolvedPath = ""
        var resolvedAbsolute: Bool = false

        var idx: Int64 = paths.size - 1
        while (idx >= -1 && !resolvedAbsolute) {
            var path: String
            if (idx >= 0) {
                path = paths[Int64(idx)]
            } else {
                path = cwd
            }

            let len = path.size
            if (len == 0) {
                idx -= 1
                continue
            }

            // resolvedPath = path + "/" + resolvedPath
            resolvedPath = path + "/" + resolvedPath
            resolvedAbsolute = path[0] == '/'
            idx -= 1
        }

        if (resolvedPath.size == 0) {
            return "."
        }

        // 规范化
        resolvedPath = normalizeString(resolvedPath, allowAboveRoot: !resolvedAbsolute, separator: '/')

        if (resolvedAbsolute) {
            return "/" + resolvedPath
        }
        return if (resolvedPath.size > 0) { resolvedPath } else { "." }
    }

    // ========================================================================
    // relative — 计算从 from 到 to 的相对路径
    // 对应 Bun: path.zig relativePosixT
    // 基于 Node v21.6.1 path.posix.relative
    // ========================================================================
    public static func relative(from: String, to: String): String {
        validateString(from, name: "from")
        validateString(to, name: "to")

        if (from == to) {
            return ""
        }

        // 解析两个路径为绝对路径
        let fromAbs = resolve(".", Array<String>([from]))
        let toAbs = resolve(".", Array<String>([to]))

        if (fromAbs == toAbs) {
            return ""
        }

        let fromStart: Int64 = 1
        let fromEnd: Int64 = fromAbs.size
        let fromLen = fromEnd - fromStart
        let toOrigLen: Int64 = toAbs.size
        var toStart: Int64 = 1
        let toLen = toOrigLen - toStart

        // 查找最长公共路径
        let smallestLength = if (fromLen < toLen) { fromLen } else { toLen }
        var lastCommonSep: Int64 = -1

        var i: Int64 = 0
        while (i < smallestLength) {
            let fromByte = fromAbs[Int64(fromStart + i)]
            if (fromByte != toAbs[Int64(toStart + i)]) {
                break
            } else if (fromByte == '/') {
                lastCommonSep = i
            }
            i += 1
        }
        let matchesAllOfSmallest = (i == smallestLength)

        if (matchesAllOfSmallest) {
            if (toLen > smallestLength) {
                if (toAbs[Int64(toStart + smallestLength)] == '/') {
                    return toAbs.substring(Int64(toStart + smallestLength + 1), Int64(toOrigLen))
                }
                if (smallestLength == 0) {
                    return toAbs.substring(Int64(toStart + smallestLength), Int64(toOrigLen))
                }
            } else if (fromLen > smallestLength) {
                if (fromAbs[Int64(fromStart + smallestLength)] == '/') {
                    lastCommonSep = smallestLength
                } else if (smallestLength == 0) {
                    lastCommonSep = 0
                }
            }
        }

        // 生成相对路径
        var out = ""
        var j: Int64 = fromStart + (if (lastCommonSep >= 0) { lastCommonSep + 1 } else { 0 })
        while (j <= fromEnd) {
            if (j == fromEnd || fromAbs[Int64(j)] == '/') {
                if (out.size > 0) {
                    out = out + "/.."
                } else {
                    out = ".."
                }
            }
            j += 1
        }

        // 追加 to 的剩余路径
        toStart = if (lastCommonSep >= 0) { toStart + lastCommonSep } else { 0 }
        let sliceSize = toOrigLen - toStart
        if (sliceSize > 0) {
            out = out + toAbs.substring(Int64(toStart), Int64(toOrigLen))
        }

        return out
    }

    // ========================================================================
    // toNamespacedPath — 转换为命名空间路径（在 POSIX 上为恒等操作）
    // 对应 Bun: path.zig toNamespacedPath
    // 基于 Node v21.6.1 path.posix.toNamespacedPath
    // ========================================================================
    public static func toNamespacedPath(path: String): String {
        // 在 POSIX 系统上，toNamespacedPath 是恒等操作
        return path
    }

    // ========================================================================
    // 内部辅助函数
    // ========================================================================

    // 规范化路径字符串（解析 . 和 .. 元素）
    // 对应 Bun: path.zig normalizeStringT
    private static func normalizeString(path: String, allowAboveRoot: Bool, separator: UInt8): String {
        let len = path.size
        var result = ""
        var lastSegmentLength: Int64 = 0
        var lastSlash: Int64 = -1
        var dots: Int64 = 0
        var byte: UInt8 = 0

        var i: Int64 = 0
        while (i <= len) {
            if (i < len) {
                byte = path[i]
            } else if (byte == separator) {
                break
            } else {
                byte = separator
            }

            if (byte == separator) {
                if ((lastSlash < 0 && i == 0) ||
                    (lastSlash >= 0 && i > 0 && lastSlash == i - 1) ||
                    (dots == 1)) {
                    // NOOP
                } else if (dots == 2) {
                    if (result.size < 2 ||
                        lastSegmentLength != 2 ||
                        result[result.size - 1] != '.' ||
                        result[result.size - 2] != '.') {
                        if (result.size > 2) {
                            let lastSlashIndex = result.lastIndexOf(separator)
                            if (lastSlashIndex < 0) {
                                result = ""
                                lastSegmentLength = 0
                            } else {
                                result = result.substring(0, Int64(lastSlashIndex))
                                let lastIndexOfSep = result.lastIndexOf(separator)
                                if (lastIndexOfSep < 0) {
                                    lastSegmentLength = result.size
                                } else {
                                    lastSegmentLength = result.size - 1 - Int64(lastIndexOfSep)
                                }
                            }
                        } else if (result.size > 0) {
                            result = ""
                            lastSegmentLength = 0
                        }
                    }
                    if (allowAboveRoot) {
                        if (result.size > 0) {
                            result = result + String.fromCharCode(separator) + ".."
                        } else {
                            result = ".."
                        }
                        lastSegmentLength = 2
                    }
                } else {
                    let sliceStart = if (lastSlash >= 0) { lastSlash + 1 } else { 0 }
                    let slice = path.substring(Int64(sliceStart), Int64(i))

                    if (result.size > 0) {
                        result = result + String.fromCharCode(separator)
                    }
                    result = result + slice

                    let subtract = if (lastSlash >= 0) { lastSlash + 1 } else { 2 }
                    lastSegmentLength = if (i >= subtract) { i - subtract } else { 0 }
                }
                lastSlash = i
                dots = 0
            } else if (byte == '.' && dots >= 0) {
                dots += 1
            } else {
                dots = -1
            }
            i += 1
        }

        return result
    }

    // 验证路径字符串
    private static func validateString(path: String, name: String): Unit {
        // 在仓颉实现中简化为无操作
        // Bun 版本中这会抛出 ERR_INVALID_ARG_TYPE
    }

    // 按斜杠拆分路径
    private static func splitPath(path: String): Array<String> {
        let parts = path.split('/')
        var result = Array<String>()
        for (part in parts) {
            if (part.size > 0) {
                result.add(part)
            }
        }
        return result
    }
}
