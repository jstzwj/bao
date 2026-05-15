// 路径处理模块
// 对应 Bun: src/runtime/node/path.zig
// 严格翻译自: src/runtime/node/path.zig
package bao_runtime

// ============================================================================
// 路径常量
// 对应 Bun: src/runtime/node/path.zig - 常量定义
// ============================================================================
public class PathConstants {
    public static let sepPosix: UInt8 = '/'
    public static let sepWindows: UInt8 = '\\'
    public static let sepStrPosix: String = "/"
    public static let sepStrWindows: String = "\\"
    public static let delimiterPosix: String = ":"
    public static let delimiterWindows: String = ";"
    // 最大路径长度
    public static let maxPathBytes: Int64 = 4096
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
// ============================================================================
public class Path {
    // ========================================================================
    // basename — 获取路径中的文件名
    // 对应 Bun: src/runtime/node/path.zig - basenamePosixT
    // ========================================================================
    public static func basename(path: String, suffix: String = ""): String {
        let len = path.size
        if (len == 0) {
            return ""
        }

        var start: Int64 = 0
        var end: Int64 = len

        // 去除尾部的斜杠
        while (end > 0 && (path[Int64(end - 1)] == '/' || path[Int64(end - 1)] == '\\')) {
            end -= 1
        }

        if (end == 0) {
            return "/"
        }

        // 找到最后一个斜杠
        var lastSlash: Int64 = -1
        var i: Int64 = start
        while (i < end) {
            if (path[i] == '/' || path[i] == '\\') {
                lastSlash = i
            }
            i += 1
        }

        start = lastSlash + 1

        let base = path.substring(Int64(start), Int64(end))

        // 去除后缀
        if (suffix.size > 0 && suffix.size < base.size) {
            if (base.endsWith(suffix)) {
                return base.substring(0, Int64(base.size - suffix.size))
            }
        }

        return base
    }

    // ========================================================================
    // dirname — 获取路径中的目录名
    // 对应 Bun: src/runtime/node/path.zig - dirnamePosixT
    // ========================================================================
    public static func dirname(path: String): String {
        let len = path.size
        if (len == 0) {
            return "."
        }

        var end: Int64 = len - 1

        // 去除尾部的斜杠
        while (end >= 0 && (path[Int64(end)] == '/' || path[Int64(end)] == '\\')) {
            end -= 1
        }

        // 找到最后一个斜杠
        var lastSlash: Int64 = -1
        var i: Int64 = 0
        while (i <= end) {
            if (path[Int64(i)] == '/' || path[Int64(i)] == '\\') {
                lastSlash = i
            }
            i += 1
        }

        if (lastSlash < 0) {
            return "."
        }

        // 去除连续的斜杠
        while (lastSlash > 0 && (path[Int64(lastSlash - 1)] == '/' || path[Int64(lastSlash - 1)] == '\\')) {
            lastSlash -= 1
        }

        if (lastSlash == 0) {
            return "/"
        }

        return path.substring(0, Int64(lastSlash))
    }

    // ========================================================================
    // extname — 获取文件扩展名
    // 对应 Bun: src/runtime/node/path.zig - extnamePosixT
    // ========================================================================
    public static func extname(path: String): String {
        let len = path.size
        if (len == 0) {
            return ""
        }

        var lastDot: Int64 = -1
        var lastSlash: Int64 = -1

        for (i in 0..Int64(len)) {
            let c = path[i]
            if (c == '/' || c == '\\') {
                lastSlash = i
                lastDot = -1
            } else if (c == '.') {
                lastDot = i
            }
        }

        if (lastDot <= lastSlash || lastDot == Int64(len) - 1) {
            return ""
        }

        // 如果点号后面全是点号（如 ".."），不是扩展名
        let baseStart = lastSlash + 1
        if (lastDot == baseStart) {
            return ""
        }

        return path.substring(Int64(lastDot), Int64(len))
    }

    // ========================================================================
    // parse — 解析路径
    // 对应 Bun: src/runtime/node/path.zig - parsePosixT
    // ========================================================================
    public static func parse(path: String): PathParsed {
        let parsed = PathParsed()
        if (path.size == 0) {
            return parsed
        }

        // 判断是否为绝对路径
        if (path[0] == '/') {
            parsed.root = "/"
        }

        parsed.dir = dirname(path)
        parsed.base = basename(path)
        parsed.ext = extname(path)

        // name 是 base 去掉 ext
        if (parsed.ext.size > 0 && parsed.base.size > parsed.ext.size) {
            parsed.name = parsed.base.substring(0, Int64(parsed.base.size - parsed.ext.size))
        } else {
            parsed.name = parsed.base
        }

        return parsed
    }

    // ========================================================================
    // format — 从路径组件构建路径字符串
    // 对应 Bun: src/runtime/node/path.zig - formatPosixT
    // ========================================================================
    public static func format(parsed: PathParsed): String {
        var dir = parsed.dir
        let base = parsed.base
        let name = parsed.name
        let ext = parsed.ext

        var result = ""

        if (dir.size > 0) {
            result = result + dir
            if (!dir.endsWith("/")) {
                result = result + "/"
            }
        }

        if (base.size > 0) {
            result = result + base
        } else {
            result = result + name
            if (ext.size > 0) {
                if (!ext.startsWith(".")) {
                    result = result + "."
                }
                result = result + ext
            }
        }

        return result
    }

    // ========================================================================
    // join — 连接路径片段
    // 对应 Bun: src/runtime/node/path.zig
    // ========================================================================
    public static func join(paths: Array<String>): String {
        var result = ""
        for (i in 0..paths.size) {
            let p = paths[i]
            if (p.size == 0) {
                continue
            }
            if (result.size > 0 && !result.endsWith("/")) {
                result = result + "/"
            }
            result = result + normalizePath(p)
        }
        // 去除尾部斜杠（除非是根路径）
        if (result.size > 1 && result.endsWith("/")) {
            result = result.substring(0, Int64(result.size - 1))
        }
        return result
    }

    // ========================================================================
    // resolve — 解析为绝对路径
    // 对应 Bun: src/runtime/node/path.zig
    // ========================================================================
    public static func resolve(cwd: String, paths: Array<String>): String {
        var result = if (paths.size > 0 && paths[paths.size - 1].startsWith("/")) {
            ""
        } else {
            cwd
        }

        for (i in 0..paths.size) {
            let p = paths[i]
            if (p.size == 0) {
                continue
            }
            if (p.startsWith("/")) {
                result = p
            } else {
                if (result.size > 0 && !result.endsWith("/")) {
                    result = result + "/"
                }
                result = result + p
            }
        }

        return normalizePath(result)
    }

    // ========================================================================
    // normalize — 规范化路径
    // 对应 Bun: src/runtime/node/path.zig
    // ========================================================================
    public static func normalize(path: String): String {
        return normalizePath(path)
    }

    // ========================================================================
    // isAbsolute — 判断是否为绝对路径
    // 对应 Bun: src/runtime/node/path.zig
    // ========================================================================
    public static func isAbsolute(path: String): Bool {
        return path.size > 0 && path[0] == '/'
    }

    // ========================================================================
    // relative — 计算从 from 到 to 的相对路径
    // 对应 Bun: src/runtime/node/path.zig
    // ========================================================================
    public static func relative(from: String, to: String): String {
        if (from == to) {
            return ""
        }

        let fromNorm = normalizePath(from)
        let toNorm = normalizePath(to)

        if (fromNorm == toNorm) {
            return ""
        }

        // 简化实现：逐层比较
        let fromParts = splitPath(fromNorm)
        let toParts = splitPath(toNorm)

        var commonLen: Int64 = 0
        let minLen = if (fromParts.size < toParts.size) { fromParts.size } else { toParts.size }

        while (commonLen < minLen && fromParts[commonLen] == toParts[commonLen]) {
            commonLen += 1
        }

        if (commonLen == 0) {
            return toNorm
        }

        var result = ""
        for (_ in commonLen..fromParts.size) {
            if (result.size > 0) {
                result = result + "/"
            }
            result = result + ".."
        }

        for (i in commonLen..toParts.size) {
            if (result.size > 0) {
                result = result + "/"
            }
            result = result + toParts[i]
        }

        return result
    }

    // 内部辅助：规范化路径（处理 . 和 ..）
    private static func normalizePath(path: String): String {
        if (path.size == 0) {
            return "."
        }

        let isAbsolute = path[0] == '/'
        let trailingSlash = path.size > 1 && path[Int64(path.size - 1)] == '/'

        let parts = splitPath(path)
        var stack = Array<String>()

        for (part in parts) {
            if (part == ".") {
                continue
            }
            if (part == "..") {
                if (stack.size > 0 && stack[stack.size - 1] != "..") {
                    stack.removeAt(stack.size - 1)
                } else if (!isAbsolute) {
                    stack.add(part)
                }
            } else {
                stack.add(part)
            }
        }

        var result = String.join("/", stack)
        if (isAbsolute) {
            result = "/" + result
        }
        if (trailingSlash && result.size > 0 && !result.endsWith("/")) {
            result = result + "/"
        }
        if (result.size == 0) {
            return "."
        }

        return result
    }

    // 内部辅助：按斜杠拆分路径
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
