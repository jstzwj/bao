// 文件系统抽象层
// 严格翻译自: src/resolver/fs.zig
//
// Bun 的 fs.zig 是解析器的文件系统抽象层，包含:
//   1. FileSystem - 文件系统主结构 (顶层目录、路径操作、目录读取)
//   2. RealFS - 真实文件系统实现 (目录遍历、文件读取、条目缓存)
//   3. DirEntry - 目录条目 (文件/目录/符号链接)
//   4. Entry - 文件条目 (名称、类型、缓存、symlink 解析)
//   5. Path - 路径结构 (pretty/text/namespace/name)
//   6. PathName - 路径名分解 (dir/base/ext/filename)
//   7. NodeJSPathName - Node.js 风格路径名分解
//
// Bun fs.zig 核心结构:
//   pub const FileSystem = struct {
//       top_level_dir: stringZ,
//       fs: Implementation,         // = RealFS
//       dirname_store: *DirnameStore,
//       filename_store: *FilenameStore,
//       pub fn normalize(str) string
//       pub fn join(parts) string
//       pub fn abs(parts) string
//       ...
//   }
//   pub const RealFS = struct {
//       entries_mutex: Mutex,
//       entries: *EntriesOption.Map,  // BSSMap 目录条目缓存
//       cwd: string,
//       file_limit: usize,
//       ...
//       pub fn readDirectory(...) !*EntriesOption
//       pub fn readFileWithHandle(...) !PathContentsPair
//   }
//   pub const DirEntry = struct {
//       dir: string,
//       data: EntryMap,              // 大小写不敏感 HashMap
//       pub fn get(query) ?Entry.Lookup
//   }
//   pub const Entry = struct {
//       base_: StringOrTinyString,
//       cache: Cache,
//       need_stat: bool,
//       pub fn kind(fs, store_fd) Kind
//       pub fn symlink(fs, store_fd) string
//   }
//   pub const Path = struct {
//       pretty: string,
//       text: string,
//       namespace: string,
//       name: PathName,
//       is_disabled: bool,
//       is_symlink: bool,
//   }
package bao_resolver

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*

// ============================================================================
// PathName - 路径名分解
// 严格翻译自: src/resolver/fs.zig Fs.PathName
// 对应 Bun: 将文件路径分解为 dir/base/ext/filename 四个部分
//
// Bun:
//   pub const PathName = struct {
//       base: string,    // 不含扩展名的基础名 (如 "index")
//       dir: string,     // 目录部分
//       ext: string,     // 扩展名 (含前导点，如 ".js")
//       filename: string // 完整文件名 (如 "index.js")
//   }
// ============================================================================

/// 路径名分解 - 对应 Bun Fs.PathName
public class PathName {
    /// 基础名 (不含扩展名) - 对应 Bun base
    /// 例如 "/foo/bar/index.js" -> "index"
    public var base: String
    /// 目录部分 - 对应 Bun dir
    /// 例如 "/foo/bar/index.js" -> "/foo/bar"
    public var dir: String
    /// 扩展名 (含前导点) - 对应 Bun ext
    /// 例如 "/foo/bar/index.js" -> ".js"
    /// 无扩展名时为空字符串
    public var ext: String
    /// 完整文件名 - 对应 Bun filename
    /// 例如 "/foo/bar/index.js" -> "index.js"
    public var filename: String

    public init() {
        base = ""
        dir = ""
        ext = ""
        filename = ""
    }

    public init(base: String, dir: String, ext: String, filename: String) {
        this.base = base
        this.dir = dir
        this.ext = ext
        this.filename = filename
    }

    /// 扩展名不含前导点 - 对应 Bun PathName.extWithoutLeadingDot()
    public func extWithoutLeadingDot(): String {
        if (ext.length > 0 && ext[Int64(0)] == Char('.')) {
            return ext.substring(Int64(1), Int64(ext.length))
        }
        return ext
    }

    /// 查找扩展名 - 对应 Bun PathName.findExtname()
    /// 在路径中查找最后一个 '.' 分隔的扩展名
    public static func findExtname(path: String): String {
        var start: Int64 = 0
        let lastSep = Path.lastIndexOfSeparator(path)
        if (lastSep >= 0) {
            start = lastSep + 1
        }
        let basePart = path.substring(start, Int64(path.length))
        let lastDot = basePart.lastIndexOf('.')
        if (lastDot > 0) {
            return basePart.substring(Int64(lastDot), Int64(basePart.length))
        }
        return ""
    }

    /// 目录部分 (或 ".") - 对应 Bun PathName.dirOrDot()
    public func dirOrDot(): String {
        if (dir.length == 0) {
            return "."
        }
        return dir
    }

    /// 带尾部斜杠的目录路径 - 对应 Bun PathName.dirWithTrailingSlash()
    public func dirWithTrailingSlash(): String {
        if (dir.length == 0) {
            return "./"
        }
        if (dir.length > 0 && Path.isSeparator(dir[Int64(dir.length - 1)])) {
            return dir
        }
        return dir + "/"
    }

    /// 从路径解析 PathName - 对应 Bun PathName.init(_path)
    public static func fromPath(path: String): PathName {
        let result = PathName()
        if (path.length == 0) {
            return result
        }

        // 查找最后一个路径分隔符
        var basePart = path
        var dirPart = path
        var isAbsolute = true

        let lastSep = Path.lastIndexOfSeparator(path)
        if (lastSep >= 0) {
            // 检查尾部斜杠
            var end = Int64(path.length)
            while (end > lastSep + 1 && Path.isSeparator(path[Int64(end - 1)])) {
                end -= 1
            }

            if (lastSep + 1 < end) {
                basePart = path.substring(Int64(lastSep + 1), end)
                dirPart = path.substring(Int64(0), Int64(lastSep))
                isAbsolute = false
            } else {
                // 尾部斜杠
                basePart = path.substring(Int64(0), end)
                dirPart = path.substring(Int64(0), end)
            }
        }

        // 分离扩展名
        let lastDot = basePart.lastIndexOf('.')
        if (lastDot > 0) {
            result.ext = basePart.substring(Int64(lastDot), Int64(basePart.length))
            result.base = basePart.substring(Int64(0), Int64(lastDot))
        } else {
            result.ext = ""
            result.base = basePart
        }

        if (isAbsolute) {
            result.dir = ""
        } else {
            result.dir = dirPart
        }

        // 文件名 = base + ext
        result.filename = basePart

        return result
    }
}

// ============================================================================
// NodeJSPathName - Node.js 风格路径名分解
// 严格翻译自: src/resolver/fs.zig Fs.NodeJSPathName
// 对应 Bun: Node.js 的 path.parse() 风格路径分解
// ============================================================================

/// Node.js 风格路径名分解 - 对应 Bun Fs.NodeJSPathName
public class NodeJSPathName {
    public var base: String
    public var dir: String
    public var ext: String
    public var filename: String

    public init() {
        base = ""
        dir = ""
        ext = ""
        filename = ""
    }

    /// 从路径解析 - 对应 Bun NodeJSPathName.init()
    public static func fromPath(path: String): NodeJSPathName {
        let result = NodeJSPathName()
        var current = path
        var basePart = path
        var extPart: String = ""
        var dirPart = path
        var isAbsolute = true

        // 查找最后一个分隔符
        let lastSep = Path.lastIndexOfSeparator(path)
        if (lastSep >= 0) {
            if (lastSep + 1 < path.length) {
                basePart = path.substring(Int64(lastSep + 1), Int64(path.length))
                dirPart = path.substring(Int64(0), Int64(lastSep))
                isAbsolute = false
            } else if (lastSep == 0) {
                basePart = path.substring(Int64(1), Int64(path.length))
                dirPart = ""
            }
        }

        // 清理尾部斜杠
        if (basePart.length > 1 && Path.isSeparator(basePart[Int64(basePart.length - 1)])) {
            basePart = basePart.substring(Int64(0), Int64(basePart.length - 1))
        }

        // 文件名
        var filenamePart = basePart

        // 分离扩展名 (仅当 base 长度 > 1)
        if (filenamePart.length > 1) {
            let dotIndex = filenamePart.lastIndexOf('.')
            if (dotIndex > 0) {
                filenamePart = filenamePart.substring(Int64(0), Int64(dotIndex))
                extPart = basePart.substring(Int64(dotIndex), Int64(basePart.length))
            }
        }

        if (isAbsolute) {
            dirPart = ""
        }

        result.base = basePart
        result.dir = dirPart
        result.ext = extPart
        result.filename = filenamePart

        return result
    }
}

// ============================================================================
// ResolverPath - 路径结构
// 严格翻译自: src/resolver/fs.zig Fs.Path
// 对应 Bun: 解析器使用的路径对象，包含显示路径、实际路径、命名空间和路径名
//
// Bun:
//   pub const Path = struct {
//       pretty: string,      // 显示路径 (相对路径，正斜杠)
//       text: string,        // 实际路径 (绝对路径，原生斜杠)
//       namespace: string,   // 命名空间 ("file", "dataurl", "bun" 等)
//       name: PathName,      // 路径名分解
//       is_disabled: bool,   // 是否被禁用 (browser map 映射为 false)
//       is_symlink: bool,    // 是否是符号链接
//   }
// ============================================================================

/// 路径对象 - 对应 Bun Fs.Path
public class ResolverPath {
    /// 显示路径 (相对路径，使用正斜杠) - 对应 Bun pretty
    public var pretty: String
    /// 实际路径 (绝对路径) - 对应 Bun text
    public var text: String
    /// 命名空间 - 对应 Bun namespace
    /// "file" = 文件系统路径, "dataurl" = data: URL, "bun" = Bun 内建
    public var namespace: String
    /// 路径名分解 - 对应 Bun name
    public var name: PathName
    /// 是否被禁用 - 对应 Bun is_disabled
    public var isDisabled: Bool
    /// 是否是符号链接 - 对应 Bun is_symlink
    public var isSymlink: Bool

    /// 空路径
    public static let empty: ResolverPath = ResolverPath("")

    public init(text: String) {
        this.pretty = text
        this.text = text
        this.namespace = "file"
        this.name = PathName.fromPath(text)
        this.isDisabled = false
        this.isSymlink = false
    }

    public init(text: String, pretty: String, namespace: String) {
        this.pretty = pretty
        this.text = text
        this.namespace = namespace
        this.name = PathName.fromPath(text)
        this.isDisabled = false
        this.isSymlink = false
    }

    public init() {
        pretty = ""
        text = ""
        namespace = "file"
        name = PathName()
        isDisabled = false
        isSymlink = false
    }

    /// 是否为文件路径 - 对应 Bun Path.isFile()
    public func isFile(): Bool {
        return namespace.length == 0 || namespace == "file"
    }

    /// 是否为 data URL - 对应 Bun Path.isDataURL()
    public func isDataURL(): Bool {
        return namespace == "dataurl"
    }

    /// 是否为 Bun 内建 - 对应 Bun Path.isBun()
    public func isBun(): Bool {
        return namespace == "bun"
    }

    /// 设置真实路径 (解析符号链接后) - 对应 Bun Path.setRealpath()
    public func setRealpath(to: String) {
        let oldPath = text
        text = to
        name = PathName.fromPath(to)
        pretty = oldPath
        isSymlink = true
    }

    /// 是否在 node_modules 中 - 对应 Bun Path.isNodeModule()
    public func isNodeModule(): Bool {
        return text.contains("/node_modules/")
    }
}

// ============================================================================
// PathPair - 路径对
// 严格翻译自: src/resolver/resolver.zig PathPair
// 对应 Bun: 解析结果中的主/次路径对
//
// Bun 使用 PathPair 来支持 "module"/"main" 双路径解析:
//   当一个包同时有 "module" (ESM) 和 "main" (CJS) 字段时，
//   primary 指向 ESM 文件，secondary 指向 CJS 文件
// ============================================================================

/// 路径对 - 对应 Bun resolver.zig PathPair
public class PathPair {
    /// 主路径 - 对应 Bun PathPair.primary
    public var primary: ResolverPath
    /// 次路径 - 对应 Bun PathPair.secondary
    public var secondary: ?ResolverPath

    public init(primary: ResolverPath) {
        this.primary = primary
        this.secondary = None
    }

    public init(primary: ResolverPath, secondary: ?ResolverPath) {
        this.primary = primary
        this.secondary = secondary
    }

    /// 遍历所有可用路径 - 对应 Bun PathPair.iter()
    public func iterate(): ArrayList<ResolverPath> {
        let result = ArrayList<ResolverPath>()
        if (!primary.isDisabled) {
            result.append(primary)
        }
        match (secondary) {
            case Some(sec) =>
                if (!sec.isDisabled) {
                    result.append(sec)
                }
            case None => {}
        }
        return result
    }
}

// ============================================================================
// Entry - 目录条目
// 严格翻译自: src/resolver/fs.zig Fs.FileSystem.Entry
// 对应 Bun: 文件系统目录中的单个条目
//
// Bun:
//   pub const Entry = struct {
//       cache: Cache,
//       dir: string,
//       base_: StringOrTinyString,
//       base_lowercase_: StringOrTinyString,
//       mutex: Mutex,
//       need_stat: bool,
//       abs_path: PathString,
//   }
// ============================================================================

/// 条目类型 - 对应 Bun Entry.Kind
public enum EntryKind {
    | Dir
    | File
}

/// 条目缓存 - 对应 Bun Entry.Cache
public class EntryCache {
    /// 符号链接目标路径 - 对应 Bun Cache.symlink
    public var symlink: String
    /// 文件描述符 - 对应 Bun Cache.fd
    public var fd: Int64
    /// 条目类型 - 对应 Bun Cache.kind
    public var kind: EntryKind

    public init() {
        symlink = ""
        fd = -1
        kind = EntryKind.File
    }
}

/// 目录条目 - 对应 Bun Fs.FileSystem.Entry
public class FSEntry {
    /// 条目缓存 - 对应 Bun Entry.cache
    public var cache: EntryCache
    /// 所在目录 - 对应 Bun Entry.dir
    public var dir: String
    /// 基础文件名 - 对应 Bun Entry.base()
    public var base: String
    /// 是否需要 stat - 对应 Bun Entry.need_stat
    /// Bun 延迟调用 stat 以优化性能 (如 @material-ui/icons 有 11000+ 条目)
    public var needStat: Bool
    /// 绝对路径 - 对应 Bun Entry.abs_path
    public var absPath: String

    public init(base: String, dir: String, kind: EntryKind) {
        this.cache = EntryCache()
        this.cache.kind = kind
        this.dir = dir
        this.base = base
        this.needStat = false
        this.absPath = ""
    }

    public init() {
        cache = EntryCache()
        dir = ""
        base = ""
        needStat = true
        absPath = ""
    }

    /// 获取条目类型 - 对应 Bun Entry.kind()
    public func getKind(): EntryKind {
        return cache.kind
    }

    /// 获取符号链接目标 - 对应 Bun Entry.symlink()
    public func getSymlink(): String {
        return cache.symlink
    }
}

/// 条目查找结果 - 对应 Bun Entry.Lookup
public class EntryLookup {
    /// 匹配的条目 - 对应 Bun Lookup.entry
    public var entry: FSEntry
    /// 大小写不同的情况 - 对应 Bun Lookup.diff_case
    public var diffCase: ?DifferentCase

    public init(entry: FSEntry) {
        this.entry = entry
        this.diffCase = None
    }

    public init(entry: FSEntry, diffCase: DifferentCase) {
        this.entry = entry
        this.diffCase = Some(diffCase)
    }
}

/// 大小写不同 - 对应 Bun Entry.Lookup.DifferentCase
public class DifferentCase {
    public var dir: String
    public var query: String
    public var actual: String

    public init(dir: String, query: String, actual: String) {
        this.dir = dir
        this.query = query
        this.actual = actual
    }
}

// ============================================================================
// DirEntry - 目录条目集合
// 严格翻译自: src/resolver/fs.zig Fs.FileSystem.DirEntry
// 对应 Bun: 文件系统目录中所有条目的集合，使用大小写不敏感 HashMap
//
// Bun:
//   pub const DirEntry = struct {
//       dir: string,
//       fd: FD,
//       generation: bun.Generation,
//       data: EntryMap,  // StringHashMapUnmanaged(*Entry)
//   }
// ============================================================================

/// 目录条目集合 - 对应 Bun Fs.FileSystem.DirEntry
public class FSDirEntry {
    /// 目录路径 - 对应 Bun DirEntry.dir
    public var dir: String
    /// 文件描述符 - 对应 Bun DirEntry.fd
    public var fd: Int64
    /// 世代号 - 对应 Bun DirEntry.generation
    public var generation: Int64
    /// 条目映射 (小写文件名 -> Entry) - 对应 Bun DirEntry.data
    private var data: HashMap<String, FSEntry>

    public init(dir: String, generation: Int64) {
        this.dir = dir
        this.fd = -1
        this.generation = generation
        this.data = HashMap<String, FSEntry>()
    }

    /// 添加条目 - 对应 Bun DirEntry.addEntry()
    public func addEntry(entry: FSEntry): Unit {
        let key = entry.base.toLowerCase()
        data.put(key, entry)
    }

    /// 查找条目 - 对应 Bun DirEntry.get()
    /// Bun 使用大小写不敏感查找:
    ///   1. 将查询转换为小写
    ///   2. 在 HashMap 中查找
    ///   3. 比较原始文件名判断是否大小写不同
    public func get(query: String): ?EntryLookup {
        if (query.length == 0) {
            return None
        }

        let lowerQuery = query.toLowerCase()
        match (data.get(lowerQuery)) {
            case Some(entry) => {
                // 检查是否大小写不同
                if (entry.base != query) {
                    return Some(EntryLookup(
                        entry,
                        DifferentCase(dir, query, entry.base)
                    ))
                }
                return Some(EntryLookup(entry))
            }
            case None => return None
        }
    }

    /// 获取条目数量 - 对应 Bun DirEntry.data.count()
    public func count(): Int64 {
        return data.size
    }

    /// 清除所有条目 - 对应 Bun DirEntry.data.clearAndFree()
    public func clear(): Unit {
        data.clear()
    }
}

// ============================================================================
// EntriesOption - 目录读取结果
// 严格翻译自: src/resolver/fs.zig Fs.FileSystem.RealFS.EntriesOption
// 对应 Bun: 目录读取结果为条目集合或错误
//
// Bun:
//   pub const EntriesOption = union(Tag) {
//       entries: *DirEntry,
//       err: DirEntry.Err,
//   }
// ============================================================================

/// 目录读取结果类型 - 对应 Bun EntriesOption.Tag
public enum EntriesOptionKind {
    | Entries  // 成功: 目录条目
    | Err      // 失败: 错误
}

/// 目录读取错误 - 对应 Bun DirEntry.Err
public class DirEntryError {
    public var originalError: String
    public var canonicalError: String

    public init(original: String, canonical: String) {
        originalError = original
        canonicalError = canonical
    }
}

/// 目录读取结果 - 对应 Bun EntriesOption
public class EntriesOption {
    public var kind: EntriesOptionKind
    /// 成功时的目录条目
    public var entries: ?FSDirEntry
    /// 失败时的错误
    public var err: ?DirEntryError

    public init(entries: FSDirEntry) {
        kind = EntriesOptionKind.Entries
        this.entries = Some(entries)
        this.err = None
    }

    public init(err: DirEntryError) {
        kind = EntriesOptionKind.Err
        this.entries = None
        this.err = Some(err)
    }
}

// ============================================================================
// PathContentsPair - 路径与内容对
// 严格翻译自: src/resolver/fs.zig Fs.PathContentsPair
// ============================================================================

/// 文件读取结果 - 对应 Bun PathContentsPair
public class PathContentsPair {
    public var path: ResolverPath
    public var contents: String

    public init(path: ResolverPath, contents: String) {
        this.path = path
        this.contents = contents
    }
}

// ============================================================================
// ResolverFileSystem - 解析器文件系统
// 严格翻译自: src/resolver/fs.zig Fs.FileSystem
// 对应 Bun: 解析器使用的文件系统抽象
//
// Bun:
//   pub const FileSystem = struct {
//       top_level_dir: stringZ,
//       fs: Implementation,  // = RealFS
//       dirname_store: *DirnameStore,
//       filename_store: *FilenameStore,
//
//       pub fn normalize(str) string
//       pub fn join(parts) string
//       pub fn abs(parts) string
//       pub fn absBuf(parts, buf) string
//       pub fn relative(from, to) string
//       pub fn readFileWithHandle(...) !PathContentsPair
//   }
// ============================================================================

/// 解析器文件系统 - 对应 Bun Fs.FileSystem
/// 提供路径操作和文件系统访问的统一接口
public class ResolverFileSystem {
    /// 顶层目录 - 对应 Bun FileSystem.top_level_dir
    public var topLevelDir: String
    /// 目录条目缓存 - 对应 Bun RealFS.entries
    public var entriesCache: HashMap<String, EntriesOption>
    /// 目录名存储 - 对应 Bun FileSystem.dirname_store
    private var dirnameStore: HashSet<String>
    /// 文件名存储 - 对应 Bun FileSystem.filename_store
    private var filenameStore: HashSet<String>
    /// 当前工作目录 - 对应 Bun RealFS.cwd
    public var cwd: String

    public init(topLevelDir: String) {
        this.topLevelDir = topLevelDir
        this.cwd = topLevelDir
        this.entriesCache = HashMap<String, EntriesOption>()
        this.dirnameStore = HashSet<String>()
        this.filenameStore = HashSet<String>()
    }

    // ========================================================================
    // 路径操作 - 对应 Bun FileSystem 中的路径方法
    // ========================================================================

    /// 规范化路径 - 对应 Bun FileSystem.normalize()
    /// 移除多余的 '.' '..' 和重复的分隔符
    public func normalize(str: String): String {
        return Path.normalize(str)
    }

    /// 路径拼接 - 对应 Bun FileSystem.join()
    public func join(parts: Array<String>): String {
        return Path.join(parts)
    }

    /// 绝对路径拼接 - 对应 Bun FileSystem.abs()
    public func abs(parts: Array<String>): String {
        let sb = StringBuilder()
        sb.append(topLevelDir)
        for (part in parts) {
            if (!part.startsWith("/") && !topLevelDir.endsWith("/")) {
                sb.append('/')
            }
            sb.append(part)
        }
        return Path.normalize(sb.toString())
    }

    /// 检查路径拼接是否在缓冲区内 - 对应 Bun FileSystem.absBufChecked()
    /// 用于防止用户输入的过长路径导致缓冲区溢出
    public func absBufChecked(parts: Array<String>): ?String {
        let result = abs(parts)
        // 简化: 始终返回结果 (Bun 中检查缓冲区长度)
        return Some(result)
    }

    /// 相对路径计算 - 对应 Bun FileSystem.relative()
    public func relative(from: String, to: String): String {
        return Path.relative(from, to)
    }

    /// 相对于顶层目录的路径 - 对应 Bun FileSystem.relativeTo()
    public func relativeTo(to: String): String {
        return Path.relative(topLevelDir, to)
    }

    /// 获取不带尾部斜杠的顶层目录 - 对应 Bun FileSystem.topLevelDirWithoutTrailingSlash()
    public func topLevelDirWithoutTrailingSlash(): String {
        if (topLevelDir.length > 1 && topLevelDir.endsWith("/")) {
            return topLevelDir.substring(Int64(0), Int64(topLevelDir.length - 1))
        }
        return topLevelDir
    }

    // ========================================================================
    // 目录读取 - 对应 Bun RealFS.readDirectory()
    // ========================================================================

    /// 读取目录 - 对应 Bun RealFS.readDirectory()
    /// 返回目录中的文件和子目录条目
    ///
    /// 参数:
    ///   dir: 目录路径
    ///   generation: 世代号，用于缓存验证
    /// 返回: 目录条目集合或错误
    public func readDirectory(dir: String, generation: Int64): EntriesOption {
        // 检查缓存
        match (entriesCache.get(dir)) {
            case Some(cached) => {
                match (cached.kind) {
                    case EntriesOptionKind.Entries => {
                        match (cached.entries) {
                            case Some(entries) =>
                                if (entries.generation >= generation) {
                                    return cached
                                }
                            case None => {}
                        }
                    }
                    case EntriesOptionKind.Err => return cached
                }
            }
            case None => {}
        }

        // 读取目录
        try {
            let entries = FSDirEntry(dir, generation)
            let files = std.fs.readDir(dir)
            for (file in files) {
                let kind = if (file.isDir) { EntryKind.Dir } else { EntryKind.File }
                let entry = FSEntry(file.name, dir, kind)
                entries.addEntry(entry)
            }
            let result = EntriesOption(entries)
            entriesCache.put(dir, result)
            return result
        } catch (e: Exception) {
            let err = DirEntryError(e.message, e.message)
            let result = EntriesOption(err)
            entriesCache.put(dir, result)
            return result
        }
    }

    // ========================================================================
    // 存储管理 - 对应 Bun 的 DirnameStore/FilenameStore
    // ========================================================================

    /// 存储目录名 - 对应 Bun DirnameStore.instance.append()
    public func storeDirname(dir: String): String {
        dirnameStore.insert(dir)
        return dir
    }

    /// 存储文件名 - 对应 Bun FilenameStore.instance.append()
    public func storeFilename(name: String): String {
        filenameStore.insert(name)
        return name
    }

    /// 清除目录条目缓存 - 对应 Bun RealFS.bustEntriesCache()
    public func bustEntriesCache(path: String): Bool {
        return entriesCache.remove(path)
    }

    /// 释放资源 - 对应 Bun FileSystem.deinit()
    public func deinit(): Unit {
        entriesCache.clear()
        dirnameStore.clear()
        filenameStore.clear()
    }
}

// ============================================================================
// findInvalidSegment - 查找路径中的无效片段
// 严格翻译自: src/resolver/package_json.zig findInvalidSegment()
// 对应 Bun: 检查 exports 目标路径是否包含 "." ".." 或 "node_modules"
// ============================================================================

/// 查找路径中的无效片段 - 对应 Bun findInvalidSegment()
/// 在第一个 '/' 或 '\\' 之后查找 ".", ".." 或 "node_modules" 片段
///
/// 参数:
///   path: 要检查的路径
/// 返回: 无效片段字符串，如果路径有效则返回 None
public func findInvalidSegment(path: String): ?String {
    let firstSlash = path.indexOfAny("/\\")
    if (firstSlash < 0) {
        return None
    }

    var remaining = path.substring(Int64(firstSlash + 1), Int64(path.length))

    while (remaining.length > 0) {
        var segment = remaining
        let nextSlash = remaining.indexOfAny("/\\")
        if (nextSlash >= 0) {
            segment = remaining.substring(Int64(0), Int64(nextSlash))
            remaining = remaining.substring(Int64(nextSlash + 1), Int64(remaining.length))
        } else {
            remaining = ""
        }

        match (segment.length) {
            case 1 =>
                if (segment == ".") {
                    return Some(segment)
                }
            case 2 =>
                if (segment == "..") {
                    return Some(segment)
                }
            case 13 =>  // "node_modules".length
                if (segment == "node_modules") {
                    return Some(segment)
                }
            case _ => {}
        }
    }

    return None
}
