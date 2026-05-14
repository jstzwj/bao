// bao_path - 路径处理
// 对应 Bun: src/paths/
package bao_path

import bao_core.*

// ============================================================================
// 路径工具
// 对应 Bun: src/paths/paths.zig
// ============================================================================

/// 路径分隔符
public let SEP: UInt8 = 47    // '/'
public let SEP_STR = "/"

/// 路径工具类
public class Path {
    /// 连接路径片段
    public static func join(parts: Array<String>): String {
        var result = StringBuilder()
        for (i in 0..parts.size) {
            let part = parts[i]
            if (i > 0 && !part.startsWith("/")) {
                result.append("/")
            }
            if (part.startsWith("/") && i > 0) {
                result.append(part.substring(1))
            } else {
                result.append(part)
            }
        }
        return result.toString()
    }

    /// 获取目录名
    public static func dirname(path: String): String {
        let normalized = normalize(path)
        let lastSlash = normalized.lastIndexOf('/')
        if (lastSlash < 0) {
            return "."
        }
        if (lastSlash == 0) {
            return "/"
        }
        return normalized.substring(0, lastSlash)
    }

    /// 获取文件名
    public static func basename(path: String): String {
        let normalized = normalize(path)
        let lastSlash = normalized.lastIndexOf('/')
        if (lastSlash < 0) {
            return normalized
        }
        return normalized.substring(lastSlash + 1)
    }

    /// 获取扩展名
    public static func extname(path: String): String {
        let name = basename(path)
        let lastDot = name.lastIndexOf('.')
        if (lastDot <= 0) {
            return ""
        }
        return name.substring(lastDot)
    }

    /// 规范化路径 (去除多余的分隔符和 . ..)
    public static func normalize(path: String): String {
        if (path.isEmpty) {
            return "."
        }

        let isAbsolute = path.startsWith("/")
        var parts = path.split("/")
        var result = ArrayList<String>()

        for (part in parts) {
            if (part.isEmpty || part == ".") {
                continue
            }
            if (part == "..") {
                if (result.size > 0 && result[result.size - 1] != "..") {
                    result.removeAt(result.size - 1)
                } else if (!isAbsolute) {
                    result.append("..")
                }
            } else {
                result.append(part)
            }
        }

        var normalized = String.join("/", result.toArray())
        if (isAbsolute) {
            normalized = "/" + normalized
        }
        if (normalized.isEmpty) {
            return if (isAbsolute) { "/" } else { "." }
        }
        return normalized
    }

    /// 判断是否为绝对路径
    public static func isAbsolute(path: String): Bool {
        return path.startsWith("/")
    }

    /// 解析为绝对路径
    public static func resolve(paths: Array<String>): String {
        var result = ""
        for (path in paths) {
            if (isAbsolute(path)) {
                result = path
            } else if (result.isEmpty) {
                result = path
            } else {
                result = join([result, path])
            }
        }
        return normalize(result)
    }

    /// 获取相对路径
    public static func relative(from: String, to: String): String {
        let fromResolved = resolve([from])
        let toResolved = resolve([to])
        if (fromResolved == toResolved) {
            return ""
        }

        let fromParts = fromResolved.split("/")
        let toParts = toResolved.split("/")

        var commonLen = 0
        let minLen = if (fromParts.size < toParts.size) { fromParts.size } else { toParts.size }
        while (commonLen < minLen && fromParts[commonLen] == toParts[commonLen]) {
            commonLen += 1
        }

        var result = ArrayList<String>()
        for (_ in commonLen..fromParts.size) {
            result.append("..")
        }
        for (i in commonLen..toParts.size) {
            result.append(toParts[i])
        }

        return String.join("/", result.toArray())
    }
}

/// PathString - 路径字符串包装
/// 对应 Bun: src/paths/PathString.zig
public class PathString {
    private var data: BaoString

    public init() {
        data = BaoString("")
    }

    public init(path: String) {
        data = BaoString(path)
    }

    public init(data: BaoString) {
        this.data = data
    }

    /// 获取路径字符串
    public func toString(): String {
        return data.toString()
    }

    /// 获取目录名
    public func dirname(): PathString {
        return PathString(Path.dirname(toString()))
    }

    /// 获取文件名
    public func basename(): PathString {
        return PathString(Path.basename(toString()))
    }

    /// 获取扩展名
    public func extname(): String {
        return Path.extname(toString())
    }

    /// 是否为绝对路径
    public func isAbsolute(): Bool {
        return Path.isAbsolute(toString())
    }

    /// 拼接子路径
    public func join(other: String): PathString {
        return PathString(Path.join([toString(), other]))
    }

    /// 获取底层 BaoString
    public func raw(): BaoString {
        return data
    }
}
