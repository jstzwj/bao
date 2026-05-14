// bao_path - 路径处理
// 严格翻译自:
//   src/paths/Path.zig - PathBuffer, Options, Buf
//   src/paths/resolve_path.zig - resolve_path, relative_path
//   src/paths/lib.rs - 路径库导出
//   src/paths/string_paths.rs - 字符串路径工具
package bao_path

import bao_core.*

// ============================================================================
// 路径常量
// 严格翻译自: src/paths/paths.zig 和 bun_core
//   pub const MAX_PATH_BYTES = 4096
//   pub const SEP = std.fs.path.sep
//   pub const SEP_STR = std.fs.path.sep_str
// ============================================================================

/// 路径分隔符 (POSIX: '/') - 对应 Bun SEP
public let SEP: UInt8 = 47  // '/'
/// 路径分隔符字符串 - 对应 Bun SEP_STR
public let SEP_STR = "/"

/// Windows 路径分隔符 - 对应 Bun SEP_WINDOWS
public let SEP_WINDOWS: UInt8 = 92  // '\'
/// 路径列表分隔符 (POSIX: ':') - 对应 Bun DELIMITER
public let DELIMITER: UInt8 = 58  // ':'

/// 最大路径长度 - 对应 Bun MAX_PATH_BYTES
public let MAX_PATH_BYTES: Int64 = 4096
/// 最大宽路径长度 (Windows) - 对应 Bun PATH_MAX_WIDE
public let PATH_MAX_WIDE: Int64 = 32768

/// 路径格式 - 对应 Bun PathFormat
public enum PathFormat {
    | Posix
    | Windows
}

// ============================================================================
// PathBuffer - 路径缓冲区
// 严格翻译自: src/paths/Path.zig Buf
// Bun 使用线程本地缓冲区池来高效处理路径
// ============================================================================

/// 路径缓冲区 - 对应 Bun PathBuffer
/// Bun: PathBuffer = [MAX_PATH_BYTES]u8
/// 使用池化缓冲区避免频繁分配
public class PathBuffer {
    private var data: Array<UInt8>
    private var length: Int64

    public init() {
        data = Array<UInt8>(MAX_PATH_BYTES, item: UInt8(0))
        length = 0
    }

    public init(capacity: Int64) {
        let cap = if (capacity > MAX_PATH_BYTES) { MAX_PATH_BYTES } else { capacity }
        data = Array<UInt8>(cap, item: UInt8(0))
        length = 0
    }

    /// 获取缓冲区长度
    /// 对应 Bun Buf.len: usize
    public func len(): Int64 {
        return length
    }

    /// 设置长度
    /// 对应 Bun Buf.setLength(new_len)
    public func setLength(newLen: Int64): Unit {
        length = newLen
    }

    /// 追加字符 (带分隔符) - 对应 Bun Buf.append
    /// add_separator: 是否在追加前添加分隔符
    public func append(characters: String, addSeparator: Bool): Unit {
        if (addSeparator) {
            data[length] = SEP
            length += 1
        }
        for (i in 0..characters.size) {
            data[length] = UInt8(characters[Int64(i)].value)
            length += 1
        }
    }

    /// 追加字节数组
    public func appendBytes(bytes: Array<UInt8>, addSeparator: Bool): Unit {
        if (addSeparator) {
            data[length] = SEP
            length += 1
        }
        for (b in bytes) {
            data[length] = b
            length += 1
        }
    }

    /// 转为字符串
    public func toString(): String {
        var sb = StringBuilder()
        for (i in 0..length) {
            sb.append(Char(Int32(data[i])))
        }
        return sb.toString()
    }

    /// 清空缓冲区
    public func clear(): Unit {
        length = 0
    }

    /// 剩余容量
    public func remaining(): Int64 {
        return data.size - length
    }

    /// 获取底层字节数组
    public func bytes(): Array<UInt8> {
        var result = Array<UInt8>()
        for (i in 0..length) {
            result.append(data[i])
        }
        return result
    }

    /// 获取可变字节引用
    public func data(): Array<UInt8> {
        return data
    }
}

// ============================================================================
// ComponentIterator - 路径组件迭代器
// 严格翻译自: src/paths/resolve_path.rs ComponentIterator
//   pub struct ComponentIterator<'a, T> {
//       path: &'a [T],
//       root_end: usize,
//       start: usize,
//       end: usize,
//       fmt: PathFormat,
//   }
// ============================================================================

/// 路径组件 - 对应 Bun 的路径分割结果
public enum PathComponent {
    | Root         // 根目录 "/" 或 "C:\"
    | Dir(String)  // 目录名
    | Current      // "."
    | Parent       // ".."
}

/// 路径组件迭代器 - 对应 Bun ComponentIterator
/// 遍历路径的各个组成部分，跳过根前缀
public class ComponentIterator {
    private var path: String
    private var pos: Int64
    private var rootEnd: Int64
    private var fmt: PathFormat

    public init(path: String) {
        this.path = path
        this.fmt = PathFormat.Posix
        this.pos = 0
        this.rootEnd = 0

        // 检测根 - 对应 ComponentIterator::init 中的根检测
        if (path.size > 0 && path[0] == Char('/')) {
            // POSIX: 连续的 '/' 算作根
            this.rootEnd = 1
        }
        this.pos = this.rootEnd
    }

    public init(path: String, fmt: PathFormat) {
        this.path = path
        this.fmt = fmt
        this.pos = 0
        this.rootEnd = 0

        if (path.size > 0) {
            match (fmt) {
                case Posix =>
                    if (path[0] == Char('/')) {
                        this.rootEnd = 1
                    }
                case Windows =>
                    // Windows 根检测: "C:\" 或 "\\"
                    if (path.size >= 3 && path[1] == Char(':') && path[2] == Char('\\')) {
                        this.rootEnd = 3
                    } else if (path.size >= 2 && path[0] == Char('\\') && path[1] == Char('\\')) {
                        this.rootEnd = 2
                    }
            }
        }
        this.pos = this.rootEnd
    }

    /// 获取根组件
    /// 对应 ComponentIterator root 检查
    public func root(): ?PathComponent {
        if (rootEnd > 0) {
            return Some(PathComponent.Root)
        }
        return None
    }

    /// 获取下一个组件
    /// 对应 ComponentIterator::next()
    public func next(): ?PathComponent {
        if (pos >= path.size) {
            return None
        }

        // 跳过分隔符
        while (pos < path.size && isSep(path[Int64(pos)])) {
            pos += 1
        }
        if (pos >= path.size) {
            return None
        }

        // 提取组件
        let start = pos
        while (pos < path.size && !isSep(path[Int64(pos)])) {
            pos += 1
        }
        let component = path.substring(Int64(start), Int64(pos))

        // 分类组件
        if (component == ".") {
            return Some(PathComponent.Current)
        }
        if (component == "..") {
            return Some(PathComponent.Parent)
        }
        return Some(PathComponent.Dir(component))
    }

    /// 收集所有组件到数组
    public func collect(): ArrayList<PathComponent> {
        var result = ArrayList<PathComponent>()
        while (true) {
            let comp = next()
            if (comp == None) {
                break
            }
            result.append(comp.unwrap())
        }
        return result
    }

    private func isSep(c: Char): Bool {
        match (fmt) {
            case Posix => c == Char('/')
            case Windows => c == Char('/') || c == Char('\\')
        }
    }
}

// ============================================================================
// Path - 路径工具类
// 严格翻译自: src/paths/Path.zig 和 src/paths/resolve_path.zig
// 提供完整的路径操作函数集
// ============================================================================

/// 路径工具类 - 对应 Bun Path / std.fs.path
public class Path {
    /// 连接路径片段
    /// 对应 Bun: joinAbsStringBuf / std.fs.path.join
    /// 将多个路径片段用分隔符连接
    public static func join(parts: Array<String>): String {
        var result = StringBuilder()
        var i: Int64 = 0
        while (i < parts.size) {
            let part = parts[Int64(i)]
            if (part.isEmpty) {
                i += 1
                continue
            }
            if (i > 0 && result.length() > 0) {
                let last = result.toString()
                if (!last.endsWith("/")) {
                    result.append("/")
                }
            }
            // 去除前导分隔符 (除了第一个片段)
            if (i > 0 && part.startsWith("/")) {
                result.append(part.substring(1))
            } else {
                result.append(part)
            }
            i += 1
        }
        return result.toString()
    }

    /// 获取目录名
    /// 对应 Bun: std.fs.path.dirname
    /// src/paths/resolve_path.zig 中的 dirname 逻辑
    public static func dirname(path: String): String {
        if (path.isEmpty) {
            return "."
        }
        let normalized = normalize(path)
        // 去除尾部分隔符
        var end = normalized.size
        while (end > 1 && normalized[Int64(end - 1)] == Char('/')) {
            end -= 1
        }
        let trimmed = normalized.substring(0, Int64(end))
        let lastSlash = trimmed.lastIndexOf('/')
        if (lastSlash < 0) {
            return "."
        }
        if (lastSlash == 0) {
            return "/"
        }
        return trimmed.substring(0, Int64(lastSlash))
    }

    /// 获取文件名
    /// 对应 Bun: std.fs.path.basename
    public static func basename(path: String): String {
        if (path.isEmpty) {
            return ""
        }
        let normalized = normalize(path)
        // 去除尾部分隔符
        var end = normalized.size
        while (end > 1 && normalized[Int64(end - 1)] == Char('/')) {
            end -= 1
        }
        let trimmed = normalized.substring(0, Int64(end))
        let lastSlash = trimmed.lastIndexOf('/')
        if (lastSlash < 0) {
            return trimmed
        }
        return trimmed.substring(Int64(lastSlash + 1))
    }

    /// 获取扩展名
    /// 对应 Bun: std.fs.path.extension
    public static func extname(path: String): String {
        let name = basename(path)
        let lastDot = name.lastIndexOf('.')
        if (lastDot <= 0) {
            return ""
        }
        return name.substring(Int64(lastDot))
    }

    /// 规范化路径
    /// 严格对应 Bun: normalizeStringGeneric
    /// src/paths/resolve_path.zig 中的核心规范化算法:
    /// 1. 检测根前缀
    /// 2. 按 '/' 分割组件
    /// 3. 跳过 "." 和空组件
    /// 4. ".." 回退 (非根路径则添加 "..")
    /// 5. 重新组装
    public static func normalize(path: String): String {
        if (path.isEmpty) {
            return "."
        }

        let isAbsolute = path.startsWith("/")
        var parts = splitPath(path)
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
    /// 对应 Bun: std.fs.path.isAbsolute
    public static func isAbsolute(path: String): Bool {
        return path.startsWith("/")
    }

    /// 解析为绝对路径
    /// 严格对应 Bun: resolve_path / std.fs.path.resolve
    /// 从右到左处理路径片段，遇到绝对路径则重置结果
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
    /// 严格对应 Bun: relative / relativeToCommonPath
    /// src/paths/resolve_path.zig relative 函数:
    /// 1. 将两个路径都规范化为绝对路径
    /// 2. 找到最长公共前缀
    /// 3. 从 from 到公共路径用 ".." 回退
    /// 4. 追加 to 的剩余部分
    public static func relative(from: String, to: String): String {
        let fromResolved = normalize(isAbsolute(from) ? from : "/" + from)
        let toResolved = normalize(isAbsolute(to) ? to : "/" + to)
        if (fromResolved == toResolved) {
            return ""
        }

        let fromParts = splitPath(fromResolved)
        let toParts = splitPath(toResolved)

        // 找到最长公共前缀 - 对应 longestCommonPathGeneric
        var commonLen = 0
        let minLen = if (fromParts.size < toParts.size) { fromParts.size } else { toParts.size }
        while (commonLen < minLen && fromParts[commonLen] == toParts[commonLen]) {
            commonLen += 1
        }

        // 从 from 到公共路径用 ".." 回退
        var result = ArrayList<String>()
        for (_ in commonLen..fromParts.size) {
            result.append("..")
        }
        // 追加 to 的剩余部分
        for (i in commonLen..toParts.size) {
            result.append(toParts[i])
        }

        if (result.size == 0) {
            return "."
        }
        return String.join("/", result.toArray())
    }

    /// 获取不带扩展名的文件名
    /// 对应 Bun: 无直接对应，但常见需求
    public static func basenameWithoutExtension(path: String): String {
        let name = basename(path)
        let ext = extname(path)
        if (ext.isEmpty) {
            return name
        }
        return name.substring(0, Int64(name.size - ext.size))
    }

    /// 将路径按分隔符分割为组件
    private static func splitPath(path: String): Array<String> {
        var result = ArrayList<String>()
        var current = StringBuilder()
        for (i in 0..path.size) {
            let c = path[Int64(i)]
            if (c == Char('/')) {
                if (current.length() > 0) {
                    result.append(current.toString())
                    current = StringBuilder()
                }
            } else {
                current.append(c)
            }
        }
        if (current.length() > 0) {
            result.append(current.toString())
        }
        return result.toArray()
    }
}

// ============================================================================
// PathString - 路径字符串包装
// 严格翻译自: src/paths/PathString.zig
//   pub const PathString = struct {
//       data: []const u8 = &.{},
//       ...
//   }
// ============================================================================

/// 路径字符串 - 对应 Bun PathString
/// Bun: PathString 是带缓冲区池优化的路径包装器
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

    /// 获取目录名 - 对应 Bun PathString.dirname
    public func dirname(): PathString {
        return PathString(Path.dirname(toString()))
    }

    /// 获取文件名 - 对应 Bun PathString.basename
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

    /// 获取字节长度 - 对应 Bun PathString.len
    public func len(): Int64 {
        return data.len()
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return data.len() == 0
    }
}

// ============================================================================
// PathBufferPool - 路径缓冲区池
// 严格翻译自: src/paths/Path.zig 中 Buf 的 buf_type: .pool
// Bun 使用线程本地缓冲区池来避免频繁的堆分配
// ============================================================================

/// 路径缓冲区池 - 对应 Bun 的 thread-local PathBuffer pool
public class PathBufferPool {
    private var pool: ArrayList<PathBuffer>
    private var index: Int64

    public init() {
        pool = ArrayList<PathBuffer>()
        index = 0
    }

    /// 获取一个缓冲区 - 对应 Bun path_buffer_pool.get()
    public func get(): PathBuffer {
        if (index < pool.size) {
            let buf = pool[Int64(index)]
            buf.clear()
            index += 1
            return buf
        }
        let buf = PathBuffer()
        pool.append(buf)
        index += 1
        return buf
    }

    /// 归还缓冲区 - 对应 Bun path_buffer_pool.put(buf)
    public func put(buf: PathBuffer): Unit {
        if (index > 0) {
            index -= 1
        }
    }
}

/// 全局路径缓冲区池 - 对应 Bun 的 thread_local path_buffer_pool
public let pathBufferPool = PathBufferPool()
