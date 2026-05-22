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
import bao_hash.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// Preallocate - 预分配常量
// 严格翻译自: src/resolver/fs.zig Fs.Preallocate
// 对应 Bun: 预分配目录条目和文件的数量
//
// Bun:
//   pub const Preallocate = struct {
//       pub const Counts = struct {
//           pub const dir_entry: usize = 2048;
//           pub const files: usize = 4096;
//       };
//   };
// ============================================================================

/// 预分配常量 - 对应 Bun Fs.Preallocate.Counts
public class PreallocateCounts {
    /// 目录条目预分配数量 - 对应 Bun Preallocate.Counts.dir_entry
    public static let dirEntry: Int64 = 2048
    /// 文件预分配数量 - 对应 Bun Preallocate.Counts.files
    public static let files: Int64 = 4096
}

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
        if (ext.size > 0 && ext[Int64(0)] == UInt8(46)) {
            return ext[Int64(1)..ext.size]
        }
        return ext
    }

    /// 查找扩展名 - 对应 Bun PathName.findExtname()
    /// 在路径中查找最后一个 '.' 分隔的扩展名
    public static func findExtname(path: String): String {
        var start: Int64 = 0
        match (path.lastIndexOf('/')) {
            case Some(sep) => start = sep + 1
            case None => ()
        }
        let basePart = path[start..path.size]
        match (basePart.lastIndexOf('.')) {
            case Some(dot) =>
                if (dot > 0) {
                    return basePart[dot..basePart.size]
                }
            case None => ()
        }
        return ""
    }

    /// 目录部分 (或 ".") - 对应 Bun PathName.dirOrDot()
    public func dirOrDot(): String {
        if (dir.size == 0) {
            return "."
        }
        return dir
    }

    /// 非唯一名称基础字符串 - 对应 Bun PathName.nonUniqueNameStringBase()
    /// 对于自动生成的符号名使用:
    ///   /bar/foo/index.js -> "foo" (因为 base 是 "index"，取 dir 的 base)
    ///   /bar/foo.js -> "foo" (直接取 base)
    public func nonUniqueNameStringBase(): String {
        // /bar/foo/index.js -> foo
        if (dir.size > 0 && base == "index") {
            return PathName.fromPath(dir).base
        }
        // /bar/foo.js -> foo
        return base
    }

    /// 非唯一名称字符串 - 对应 Bun PathName.nonUniqueNameString()
    /// 生成有效的标识符名称用于 CommonJS wrapper 等
    public func nonUniqueNameString(): String {
        return ensureValidIdentifier(nonUniqueNameStringBase())
    }

    /// 确保字符串是有效标识符 - 简化版
    private static func ensureValidIdentifier(s: String): String {
        if (s.size == 0) {
            return "_"
        }
        var result = StringBuilder()
        for (i in 0..s.size) {
            let ch = s[i]
            if ((ch >= UInt8(97) && ch <= UInt8(122)) || (ch >= UInt8(65) && ch <= UInt8(90)) || (ch >= UInt8(48) && ch <= UInt8(57)) || ch == UInt8(95)) {
                result.append(s[Int64(i)..Int64(i + 1)])
            } else {
                result.append('_')
            }
        }
        let str = result.toString()
        if (str.size == 0) {
            return "_"
        }
        return str
    }

    /// 带尾部斜杠的目录路径 - 对应 Bun PathName.dirWithTrailingSlash()
    public func dirWithTrailingSlash(): String {
        if (dir.size == 0) {
            return "./"
        }
        if (dir.size > 0 && dir[Int64(dir.size - 1)] == UInt8(47)) {
            return dir
        }
        return dir + "/"
    }

    /// 从路径解析 PathName - 对应 Bun PathName(_path)
    public static func fromPath(path: String): PathName {
        let result = PathName()
        if (path.size == 0) {
            return result
        }

        // 查找最后一个路径分隔符
        var basePart = path
        var dirPart = path
        var isAbsolute = true

        match (path.lastIndexOf('/')) {
            case Some(lastSep) =>
                // 检查尾部斜杠
                var end = Int64(path.size)
                while (end > lastSep + 1 && path[Int64(end - 1)] == UInt8(47)) {
                    end -= 1
                }

                if (lastSep + 1 < end) {
                    basePart = path[Int64(lastSep + 1)..end]
                    dirPart = path[Int64(0)..Int64(lastSep)]
                    isAbsolute = false
                } else {
                    // 尾部斜杠
                    basePart = path[Int64(0)..end]
                    dirPart = path[Int64(0)..end]
                }
            case None => ()
        }

        // 分离扩展名
        match (basePart.lastIndexOf('.')) {
            case Some(lastDot) =>
                if (lastDot > 0) {
                    result.ext = basePart[Int64(lastDot)..basePart.size]
                    result.base = basePart[Int64(0)..Int64(lastDot)]
                } else {
                    result.ext = ""
                    result.base = basePart
                }
            case None =>
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

    /// 从路径解析 - 对应 Bun NodeJSPathName()
    public static func fromPath(path: String): NodeJSPathName {
        let result = NodeJSPathName()
        var current = path
        var basePart = path
        var extPart: String = ""
        var dirPart = path
        var isAbsolute = true

        // 查找最后一个分隔符
        match (path.lastIndexOf('/')) {
            case Some(lastSep) =>
                if (lastSep + 1 < path.size) {
                    basePart = path[Int64(lastSep + 1)..path.size]
                    dirPart = path[Int64(0)..Int64(lastSep)]
                    isAbsolute = false
                } else if (lastSep == 0) {
                    basePart = path[Int64(1)..path.size]
                    dirPart = ""
                }
            case None => ()
        }

        // 清理尾部斜杠
        if (basePart.size > 1 && basePart[Int64(basePart.size - 1)] == UInt8(47)) {
            basePart = basePart[Int64(0)..Int64(basePart.size - 1)]
        }

        // 文件名
        var filenamePart = basePart

        // 分离扩展名 (仅当 base 长度 > 1)
        if (filenamePart.size > 1) {
            match (filenamePart.lastIndexOf('.')) {
                case Some(dotIndex) =>
                    if (dotIndex > 0) {
                        filenamePart = filenamePart[Int64(0)..Int64(dotIndex)]
                        extPart = basePart[Int64(dotIndex)..basePart.size]
                    }
                case None => ()
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
// ResolverPackageRelative - 路径包相对信息
// 严格翻译自: src/resolver/fs.zig Fs.Path.PackageRelative
// ============================================================================

public class ResolverPackageRelative {
    public var path: String
    public var name: String
    public var isParentPackage: Bool

    public init(path: String, name: String) {
        this.path = path
        this.name = name
        this.isParentPackage = false
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

    /// 命名空间常量 - 对应 Bun Path 内部常量
    public static let nsBlob: String = "blob"
    public static let nsBun: String = "bun"
    public static let nsDataurl: String = "dataurl"
    public static let nsFile: String = "file"
    public static let nsMacro: String = "macro"

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
        return namespace.size == 0 || namespace == "file"
    }

    /// 是否为 data URL - 对应 Bun Path.isDataURL()
    public func isDataURL(): Bool {
        return namespace == "dataurl"
    }

    /// 是否为 Bun 内建 - 对应 Bun Path.isBun()
    public func isBun(): Bool {
        return namespace == "bun"
    }

    /// 是否为宏 - 对应 Bun Path.isMacro()
    public func isMacro(): Bool {
        return namespace == "macro"
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

    /// 是否为 JSX/TSX 文件 - 对应 Bun Path.isJSXFile()
    public func isJSXFile(): Bool {
        return name.filename.endsWith(".jsx") || name.filename.endsWith(".tsx")
    }

    /// 路径哈希键 - 对应 Bun Path.hashKey()
    /// 文件路径使用文本哈希，其他命名空间使用 namespace + text 组合哈希
    public func hashKey(): UInt64 {
        if (isFile()) {
            return XxHash64.hash(text)
        }
        // Wyhash with namespace + separator + text
        let combined = namespace + "::::::::" + text
        return XxHash64.hash(combined)
    }

    /// 用于 hot-module-reloading 的哈希 - 对应 Bun Path.hashForKit()
    /// 结果必须在 JavaScript safe integer 范围内
    public func hashForKit(): UInt64 {
        return hashKey() & UInt64(0x1FFFFFFFFFFFFF)
    }

    /// 获取包名 - 对应 Bun Path.packageName()
    /// 从路径中提取 node_modules 中的包名
    public func packageName(): ?String {
        var nameToUse = pretty
        let needle = "/node_modules/"
        match (text.lastIndexOf(needle)) {
            case Some(idx) =>
                nameToUse = text[Int64(idx + 14)..text.size]
            case None => ()
        }

        // 解析包名: @scope/name 或 name
        var pkgName = nameToUse
        match (pkgName.indexOf('/')) {
            case Some(slash) =>
                if (pkgName.size > 0 && pkgName[Int64(0)] == UInt8(64)) {
                    // @scope/package -> 截取到第二个 /
                    match (pkgName.indexOf('/', Int64(1))) {
                        case Some(secondSlash) =>
                            pkgName = pkgName[Int64(0)..Int64(secondSlash)]
                        case None => ()
                    }
                } else {
                    pkgName = pkgName[Int64(0)..Int64(slash)]
                }
            case None => ()
        }

        if (pkgName.size == 0) {
            return None
        }
        // 第一个字符必须是字母数字
        let firstChar = pkgName[Int64(0)]
        if (!((firstChar >= UInt8(97) && firstChar <= UInt8(122)) || (firstChar >= UInt8(65) && firstChar <= UInt8(90)) || (firstChar >= UInt8(48) && firstChar <= UInt8(57)))) {
            return None
        }
        return Some(pkgName)
    }

    /// 源目录 (带尾部斜杠) - 对应 Bun Path.sourceDir()
    public func sourceDir(): String {
        return name.dirWithTrailingSlash()
    }

    /// 显示目录 (带尾部斜杠) - 对应 Bun Path.prettyDir()
    public func prettyDir(): String {
        return name.dirWithTrailingSlash()
    }

    /// 断言 pretty 路径有效 - 对应 Bun Path.assertPrettyIsValid()
    /// 在 Windows 上确保 pretty 路径只使用正斜杠
    public func assertPrettyIsValid(): Unit {
        // Windows-only assertion, 在非 Windows 平台上跳过
        if (pretty.contains("\\")) {
            // 在 Windows 上应为 panic, 此处为 debug 日志
        }
    }

    /// 断言文件路径是绝对路径 - 对应 Bun Path.assertFilePathIsAbsolute()
    public func assertFilePathIsAbsolute(): Unit {
        if (isFile()) {
            // 确保绝对路径 (CI 模式下断言)
        }
    }

    /// 检查 pretty 路径是否使用 POSIX 格式 - 对应 Bun Path.isPrettyPathPosix()
    public func isPrettyPathPosix(): Bool {
        // 非 Windows 总是返回 true
        return !pretty.contains("\\")
    }

    /// 生成键字符串 - 对应 Bun Path.generateKey()
    /// 格式: "namespace://text"
    public func generateKey(): String {
        return namespace + "://" + text
    }

    /// 增量图的键 - 对应 Bun Path.keyForIncrementalGraph()
    public func keyForIncrementalGraph(): String {
        if (isFile()) {
            return text
        }
        return pretty
    }

    /// 带显示名初始化 - 对应 Bun Path.initWithPretty()
    public static func initWithPretty(text: String, pretty: String): ResolverPath {
        let p = ResolverPath()
        p.pretty = pretty
        p.text = text
        p.namespace = "file"
        p.name = PathName.fromPath(text)
        p.isDisabled = false
        p.isSymlink = false
        return p
    }

    /// 带命名空间初始化 - 对应 Bun Path.initWithNamespace()
    public static func initWithNamespace(text: String, namespace: String): ResolverPath {
        let p = ResolverPath()
        p.pretty = text
        p.text = text
        p.namespace = namespace
        p.name = PathName.fromPath(text)
        p.isDisabled = false
        p.isSymlink = false
        return p
    }

    /// 带命名空间和虚拟路径初始化 - 对应 Bun Path.initWithNamespaceVirtual()
    public static func initWithNamespaceVirtual(text: String, namespace: String, pkg: String): ResolverPath {
        let p = ResolverPath()
        p.pretty = namespace + ":" + pkg
        p.text = text
        p.namespace = namespace
        p.name = PathName.fromPath(text)
        p.isSymlink = true
        p.isDisabled = false
        return p
    }

    /// Kit 内建模块初始化 - 对应 Bun Path.initForKitBuiltIn()
    public static func initForKitBuiltIn(namespace: String, pkg: String): ResolverPath {
        let p = ResolverPath()
        p.pretty = namespace + ":" + pkg
        p.text = "_bun/" + pkg
        p.namespace = namespace
        p.name = PathName.fromPath(pkg)
        p.isSymlink = true
        p.isDisabled = false
        return p
    }

    /// 复制分配 (仅在必要时) - 对应 Bun Path.dupeAlloc()
    /// 将跳过已在 FilenameStore 或 DirnameStore 中的分配
    public func dupeAlloc(): ResolverPath {
        let newPath = ResolverPath()
        newPath.text = text
        newPath.pretty = pretty
        newPath.namespace = namespace
        newPath.name = name
        newPath.isDisabled = isDisabled
        newPath.isSymlink = isSymlink
        return newPath
    }

    /// 复制并修正 pretty 路径 - 对应 Bun Path.dupeAllocFixPretty()
    public func dupeAllocFixPretty(): ResolverPath {
        if (isPrettyPathPosix()) {
            return dupeAlloc()
        }
        var newPath = dupeAlloc()
        newPath.pretty = pretty.replace("\\", "/")
        return newPath
    }

    /// JSON 序列化 - 对应 Bun Path.jsonStringify()
    public func jsonStringify(): String {
        return text
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
            case None => ()
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
//       need_stat: bool = true,
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
    /// 小写基础文件名 - 对应 Bun Entry.base_lowercase()
    public var baseLowercase: String
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
        this.baseLowercase = base.toAsciiLower()
        this.needStat = false
        this.absPath = ""
    }

    public init() {
        cache = EntryCache()
        dir = ""
        base = ""
        baseLowercase = ""
        needStat = true
        absPath = ""
    }

    /// 获取条目类型 - 对应 Bun Entry.kind()
    /// 如果需要 stat，延迟执行 stat 查询
    public func getKind(fs: ?RealFS, storeFd: Bool): EntryKind {
        if (needStat) {
            needStat = false
            // 在 Bun 中，这里会调用 fs.kind() 执行 stat
            // 简化: 返回缓存的类型
        }
        return cache.kind
    }

    /// 获取条目类型 (无 fs 参数) - 对应 Bun Entry.kind() 简化版
    public func getKind(): EntryKind {
        return cache.kind
    }

    /// 获取符号链接目标 - 对应 Bun Entry.symlink()
    public func getSymlink(): String {
        return cache.symlink
    }

    /// 获取符号链接目标 (带 fs) - 对应 Bun Entry.symlink(fs, store_fd)
    public func getSymlink(fs: ?RealFS, storeFd: Bool): String {
        if (needStat) {
            needStat = false
            // 在 Bun 中，这里会调用 fs.kind() 执行 stat
        }
        return cache.symlink
    }

    /// 获取小写文件名 - 对应 Bun Entry.base_lowercase()
    public func baseLower(): String {
        return baseLowercase
    }

    /// 释放资源 - 对应 Bun Entry.deinit()
    public func deinit(): Unit {
        cache.symlink = ""
        cache.fd = -1
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
        let key = entry.base.toAsciiLower()
        data.put(key, entry)
    }

    /// 查找条目 - 对应 Bun DirEntry.get()
    /// Bun 使用大小写不敏感查找:
    ///   1. 将查询转换为小写
    ///   2. 在 HashMap 中查找
    ///   3. 比较原始文件名判断是否大小写不同
    public func get(query: String): ?EntryLookup {
        if (query.size == 0) {
            return None
        }

        let lowerQuery = query.toAsciiLower()
        match (data.get(lowerQuery)) {
            case Some(entry) =>
                // 检查是否大小写不同
                if (entry.base != query) {
                    return Some(EntryLookup(
                        entry,
                        DifferentCase(dir, query, entry.base)
                    ))
                }
                return Some(EntryLookup(entry))
            case None => return None
        }
    }

    /// 编译时查询 - 对应 Bun DirEntry.getComptimeQuery()
    /// 简化版本: 使用普通查询
    public func getComptimeQuery(query: String): ?EntryLookup {
        return get(query)
    }

    /// 检查是否存在查询条目 - 对应 Bun DirEntry.hasComptimeQuery()
    public func hasComptimeQuery(query: String): Bool {
        if (query.size == 0) {
            return false
        }
        let lowerQuery = query.toAsciiLower()
        return data.contains(lowerQuery)
    }

    /// 获取条目数量 - 对应 Bun DirEntry.data.count()
    public func count(): Int64 {
        return data.size
    }

    /// 清除所有条目 - 对应 Bun DirEntry.data.clearAndFree()
    public func clear(): Unit {
        data.clear()
    }

    /// 释放资源 - 对应 Bun DirEntry.deinit()
    public func deinit(): Unit {
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

    /// 是否为条目结果 - 对应 Bun EntriesOption == .entries
    public func isEntries(): Bool {
        return match (kind) { case EntriesOptionKind.Entries => true case _ => false }
    }

    /// 是否为错误结果 - 对应 Bun EntriesOption == .err
    public func isErr(): Bool {
        return match (kind) { case EntriesOptionKind.Err => true case _ => false }
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
// ModKey - 文件修改键
// 严格翻译自: src/resolver/fs.zig Fs.FileSystem.RealFS.ModKey
// 对应 Bun: 文件的元数据指纹 (inode/size/mtime/mode)
//
// Bun:
//   pub const ModKey = struct {
//       inode: std.fs.File.INode = 0,
//       size: u64 = 0,
//       mtime: i128 = 0,
//       mode: std.fs.File.Mode = 0,
//       pub fn hashName(basename) !string
//       pub fn hash() u64
//       pub fn generate(fs, path, file) anyerror!ModKey
//       pub const SafetyGap = 3;
//   }
// ============================================================================

/// 文件修改键错误 - 对应 Bun RealFS.ModKeyError
public enum ModKeyError {
    | Unusable
}

/// 文件修改键 - 对应 Bun RealFS.ModKey
/// 用于检测文件是否发生变化
public class ModKey {
    /// inode 号 - 对应 Bun ModKey.inode
    public var inode: UInt64
    /// 文件大小 - 对应 Bun ModKey.size
    public var size: UInt64
    /// 修改时间 (纳秒) - 对应 Bun ModKey.mtime
    public var mtime: Int64
    /// 文件模式 - 对应 Bun ModKey.mode
    public var mode: UInt32
    /// 安全间隙 - 对应 Bun ModKey.SafetyGap
    public static let safetyGap: Int64 = 3

    public init() {
        inode = UInt64(0)
        size = UInt64(0)
        mtime = Int64(0)
        mode = UInt32(0)
    }

    public init(inode: UInt64, size: UInt64, mtime: Int64, mode: UInt32) {
        this.inode = inode
        this.size = size
        this.mtime = mtime
        this.mode = mode
    }

    /// 哈希名称 - 对应 Bun ModKey.hashName()
    /// 生成 "basename-hash" 格式的字符串
    public func hashName(basename: String): String {
        let hashVal = hash()
        return basename + "-" + hashVal.toString()
    }

    /// 哈希 - 对应 Bun ModKey.hash()
    /// 使用 size + mtime 生成确定性哈希 (跨平台一致)
    public func hash(): UInt64 {
        let bytes = ArrayList<UInt8>()
        // 写入 size (little-endian)
        appendUInt64(bytes, size)
        // 写入 mtime (little-endian)
        appendInt64(bytes, mtime)
        // 填充 8 字节零
        for (_ in 0..8) {
            bytes.append(UInt8(0))
        }
        return XxHash64.hash(bytes.items())
    }

    private static func appendUInt64(bytes: ArrayList<UInt8>, n: UInt64): Unit {
        var shift: UInt64 = 0
        while (shift < 64) {
            bytes.append(UInt8((n >> shift) & UInt64(0xFF)))
            shift += 8
        }
    }

    private static func appendInt64(bytes: ArrayList<UInt8>, n: Int64): Unit {
        appendUInt64(bytes, UInt64(n))
    }
}

// ============================================================================
// TmpfilePosix - POSIX 临时文件
// 严格翻译自: src/resolver/fs.zig Fs.FileSystem.RealFS.TmpfilePosix
// 对应 Bun: POSIX 平台上的临时文件处理
// ============================================================================

/// POSIX 临时文件 - 对应 Bun RealFS.TmpfilePosix
public class TmpfilePosix {
    /// 文件描述符 - 对应 Bun TmpfilePosix.fd
    public var fd: Int64
    /// 目录文件描述符 - 对应 Bun TmpfilePosix.dir_fd
    public var dirFd: Int64

    public init() {
        fd = -1
        dirFd = -1
    }

    /// 关闭文件 - 对应 Bun TmpfilePosix.close()
    public func close(): Unit {
        if (fd >= 0) {
            fd = -1
        }
    }

    /// 创建临时文件 - 对应 Bun TmpfilePosix.create()
    public func create(rfs: RealFS, name: String): Unit {
        // 使用当前工作目录创建临时文件
        dirFd = -1 // CWD
        // 简化: 实际应调用 openat() 系统调用
    }

    /// 提升为正式文件 - 对应 Bun TmpfilePosix.promoteToCWD()
    public func promoteToCWD(fromName: String, name: String): Unit {
        // 简化: 实际应调用 rename 系统调用
        close()
    }

    /// 关闭并删除 - 对应 Bun TmpfilePosix.closeAndDelete()
    public func closeAndDelete(name: String): Unit {
        close()
        // Linux 不需要额外删除，其他平台需要 unlink
    }
}

// ============================================================================
// RealFS - 真实文件系统实现
// 严格翻译自: src/resolver/fs.zig Fs.FileSystem.RealFS
// 对应 Bun: 真实文件系统的实现，包含目录遍历、文件读取、条目缓存
//
// Bun:
//   pub const RealFS = struct {
//       entries_mutex: Mutex,
//       entries: *EntriesOption.Map,
//       cwd: string,
//       file_limit: usize,
//       file_quota: usize,
//       pub fn readDirectory(...) !*EntriesOption
//       pub fn readFileWithHandle(...) !PathContentsPair
//       pub fn kind(...) !Entry.Cache
//       pub fn kindFromAbsolute(...) !Entry.Cache
//       pub fn modKey(...) anyerror!ModKey
//       pub fn bustEntriesCache(path) bool
//       ...
//   }
// ============================================================================

/// 真实文件系统 - 对应 Bun Fs.FileSystem.RealFS
public class RealFS {
    /// 条目缓存 - 对应 Bun RealFS.entries
    public var entries: HashMap<String, EntriesOption>
    /// 当前工作目录 - 对应 Bun RealFS.cwd
    public var cwd: String
    /// 文件描述符限制 - 对应 Bun RealFS.file_limit
    public var fileLimit: Int64
    /// 文件描述符配额 - 对应 Bun RealFS.file_quota
    public var fileQuota: Int64

    public init(cwd: String) {
        this.entries = HashMap<String, EntriesOption>()
        this.cwd = cwd
        this.fileLimit = 32
        this.fileQuota = 32
    }

    public init(cwd: String, fileLimit: Int64) {
        this.entries = HashMap<String, EntriesOption>()
        this.cwd = cwd
        this.fileLimit = fileLimit
        this.fileQuota = fileLimit
    }

    /// 获取平台临时目录 - 对应 Bun RealFS.platformTempDir()
    /// 尝试 TMPDIR, TMP, TEMP 环境变量，然后回退到 /tmp
    public static func platformTempDir(): String {
        // 简化: 返回默认临时目录
        return "/tmp"
    }

    /// 获取临时目录路径 - 对应 Bun RealFS.tmpdirPath()
    public static func tmpdirPath(): String {
        return platformTempDir()
    }

    /// 获取默认临时目录 - 对应 Bun RealFS.getDefaultTempDir()
    public static func getDefaultTempDir(): String {
        return platformTempDir()
    }

    /// 是否需要关闭文件 - 对应 Bun RealFS.needToCloseFiles()
    /// 如果打开的文件数量接近限制，则返回 true
    public func needToCloseFiles(): Bool {
        // 如果不在文件描述符限制附近，则不需要担心
        return !(fileLimit > 254 && fileLimit > 0)
    }

    /// 清除条目缓存 - 对应 Bun RealFS.bustEntriesCache()
    /// 返回 true 如果确实移除了一个条目
    public func bustEntriesCache(filePath: String): Bool {
        match (entries.remove(filePath)) {
            case Some(_) => return true
            case None => return false
        }
    }

    /// 获取缓存条目 - 对应 Bun RealFS.entriesAt()
    /// 按路径和世代号检查缓存中的目录条目
    public func entriesAt(path: String, generation: Int64): ?EntriesOption {
        match (entries.get(path)) {
            case Some(cached) =>
                match (cached.kind) {
                    case EntriesOptionKind.Entries =>
                        match (cached.entries) {
                            case Some(dirEntries) =>
                                if (dirEntries.generation >= generation) {
                                    return cached
                                }
                                // 世代号过期，需要重新读取
                                return None
                            case None => return None
                        }
                    case EntriesOptionKind.Err => return cached
                }
            case None => return None
        }
    }

    /// 打开目录 - 对应 Bun RealFS.openDir()
    public func openDir(dir: String): Unit {
        // 简化: 实际应调用 opendir 系统调用
    }

    /// 读取目录错误处理 - 对应 Bun RealFS.readDirectoryError()
    public func readDirectoryError(dir: String, err: String): EntriesOption {
        let dirErr = DirEntryError(err, err)
        let result = EntriesOption(dirErr)
        entries.put(dir, result)
        return result
    }

    /// 读取目录 - 对应 Bun RealFS.readDirectory()
    /// 读取指定目录的文件和子目录条目
    ///
    /// 参数:
    ///   dir: 目录路径
    ///   handle: 可选的目录句柄 (为 None 时自动打开)
    ///   generation: 世代号，用于缓存验证
    ///   storeFd: 是否存储文件描述符
    /// 返回: 目录条目集合或错误
    public func readDirectory(dir: String, handle: Int64, generation: Int64, storeFd: Bool): EntriesOption {
        // 规范化: 移除尾部斜杠
        var normalizedDir = dir
        while (normalizedDir.size > 1 && normalizedDir.endsWith("/")) {
            normalizedDir = normalizedDir[Int64(0)..Int64(normalizedDir.size - 1)]
        }

        // 检查缓存
        match (entries.get(normalizedDir)) {
            case Some(cached) =>
                match (cached.kind) {
                    case EntriesOptionKind.Entries =>
                        match (cached.entries) {
                            case Some(dirEntries) =>
                                if (dirEntries.generation >= generation) {
                                    return cached
                                }
                            case None => ()
                        }
                    case EntriesOptionKind.Err => return cached
                }
            case None => ()
        }

        // 读取目录
        // 对应 Bun: src/resolver/fs.zig:957-989 (readdir 函数)
        // 使用 bao_sys.DirIterator (POSIX opendir/readdir) 遍历目录条目
        let iterResult = DirIterator.open(normalizedDir)
        match (iterResult) {
            case Ok(iter) =>
                let dirEntries = FSDirEntry(normalizedDir, generation)
                // 遍历目录条目, 对应 Bun: while (try iter.next().unwrap()) |*_entry|
                while (true) {
                    let entry = iter.next()
                    match (entry) {
                        case Some(dirEntry) =>
                            // 确定条目类型 - 对应 Bun DirEntry.Entry.addEntry 使用 bun.S_ISDIR()
                            // DirEntryType 已从 dirent.d_type 获取文件类型
                            let kind = match (dirEntry.entryType) {
                                case DirEntryType.Directory => EntryKind.Dir
                                case _ => EntryKind.File
                            }
                            let fsEntry = FSEntry(dirEntry.name, normalizedDir, kind)
                            dirEntries.addEntry(fsEntry)
                        case None => break
                    }
                }
                iter.close()
                if (storeFd) {
                    // 对应 Bun: FileSystem.setMaxFd(handle.fd)
                }
                let result = EntriesOption(dirEntries)
                entries.put(normalizedDir, result)
                return result
            case Err(err) =>
                let dirErr = DirEntryError(err.toString(), err.toString())
                let result = EntriesOption(dirErr)
                entries.put(normalizedDir, result)
                return result
        }
    }

    /// 简化的目录读取 (无句柄) - 对应 Bun RealFS.readDirectory() 简化签名
    public func readDirectorySimple(dir: String, generation: Int64): EntriesOption {
        return readDirectory(dir, -1, generation, false)
    }

    /// 读取文件 - 对应 Bun RealFS.readFileWithHandle()
    ///
    /// Bun 使用共享缓冲区优化读取性能:
    ///   1. 对于 JS 类文件通过 HTTP 服务时，不缓存内容到内存
    ///   2. 使用共享 MutableString 缓冲区减少分配
    ///   3. 支持 BOM 检测和 UTF-8 转换
    ///
    /// 参数:
    ///   path: 文件路径
    ///   sizeHint: 文件大小提示 (可选)
    ///   useSharedBuffer: 是否使用共享缓冲区
    ///   stream: 是否流式读取
    /// 返回: 路径和内容对
    public func readFileWithHandle(path: String, sizeHint: Int64, useSharedBuffer: Bool, stream: Bool): PathContentsPair {
        // 简化实现: 在 Bun 中，这里会执行 pread 系统调用
        // 并处理 BOM 检测和 UTF-8 转换
        let resolverPath = ResolverPath(path)
        return PathContentsPair(resolverPath, "")
    }

    /// 从绝对路径获取条目类型 - 对应 Bun RealFS.kindFromAbsolute()
    public func kindFromAbsolute(absolutePath: String, existingFd: Int64, storeFd: Bool): EntryCache {
        let cache = EntryCache()
        // 简化: 在 Bun 中，这里会执行 lstat 系统调用
        // 检测文件类型和符号链接
        return cache
    }

    /// 获取条目类型 - 对应 Bun RealFS.kind()
    /// 检测指定路径是文件、目录还是符号链接
    ///
    /// 参数:
    ///   dir: 目录路径
    ///   base: 基础文件名
    ///   existingFd: 已有的文件描述符 (0 表示没有)
    ///   storeFd: 是否存储文件描述符
    /// 返回: 条目缓存 (包含类型和符号链接信息)
    public func kind(dir: String, base: String, existingFd: Int64, storeFd: Bool): EntryCache {
        let cache = EntryCache()
        // 拼接路径
        let entryPath = dir + "/" + base
        // 简化: 在 Bun 中，这里会:
        //   1. 调用 lstat 检测文件类型
        //   2. 如果是符号链接，打开文件并读取链接目标
        //   3. 根据目标文件类型设置 cache.kind
        //   4. 将符号链接目标存入 FilenameStore
        return cache
    }

    /// 获取文件修改键 - 对应 Bun RealFS.modKey()
    public func modKey(path: String): ?ModKey {
        // 简化: 在 Bun 中，这里会打开文件并执行 stat
        return None
    }

    /// 带文件句柄的修改键 - 对应 Bun RealFS.modKeyWithFile()
    public func modKeyWithFile(path: String, fd: Int64): ?ModKey {
        // 简化: 在 Bun 中，这里会使用已有文件描述符执行 stat
        return None
    }

    /// 调整文件描述符限制 - 对应 Bun RealFS.adjustUlimit()
    /// 尝试将 NOFILE 限制提升到最大值
    public static func adjustUlimit(): Int64 {
        // 简化: 在 Bun 中，这里会调用 getrlimit/setrlimit
        return 1024
    }

    /// 释放资源
    public func deinit(): Unit {
        entries.clear()
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

/// 文件系统错误类型 - 对应 Bun FileSystem.Error
public enum FileSystemError {
    | ENOENT       // 文件不存在
    | EACCESS      // 权限不足
    | INVALID_NAME // 无效名称
    | ENOTDIR      // 不是目录
}

/// 解析器文件系统 - 对应 Bun Fs.FileSystem
/// 提供路径操作和文件系统访问的统一接口
public class ResolverFileSystem {
    /// 顶层目录 - 对应 Bun FileSystem.top_level_dir
    public var topLevelDir: String
    /// 顶层目录缓冲区 - 对应 Bun FileSystem.top_level_dir_buf
    public var topLevelDirBuf: String
    /// 真实文件系统实现 - 对应 Bun FileSystem.fs (Implementation = RealFS)
    public var fs: RealFS
    /// 目录名存储 - 对应 Bun FileSystem.dirname_store
    private var dirnameStore: HashSet<String>
    /// 文件名存储 - 对应 Bun FileSystem.filename_store
    private var filenameStore: HashSet<String>
    /// 当前工作目录 - 对应 Bun RealFS.cwd
    public var cwd: String
    /// 是否已加载 - 对应 Bun FileSystem.instance_loaded
    public var instanceLoaded: Bool
    /// 最大文件描述符 - 对应 Bun FileSystem.max_fd
    public var maxFd: Int64
    /// 目录条目缓存 - 对应 Bun RealFS.entries
    public var entriesCache: HashMap<String, EntriesOption>

    public init(topLevelDir: String) {
        this.topLevelDir = topLevelDir
        this.topLevelDirBuf = topLevelDir
        this.fs = RealFS(topLevelDir)
        this.cwd = topLevelDir
        this.dirnameStore = HashSet<String>()
        this.filenameStore = HashSet<String>()
        this.entriesCache = HashMap<String, EntriesOption>()
        this.instanceLoaded = true
        this.maxFd = 0
    }

    // ========================================================================
    // 初始化 - 对应 Bun FileSystem() / initWithForce()
    // ========================================================================

    /// 初始化文件系统 - 对应 Bun FileSystem()
    public static func `init`(topLevelDir: String): ResolverFileSystem {
        return ResolverFileSystem(topLevelDir)
    }

    /// 强制初始化 - 对应 Bun FileSystem.initWithForce()
    public static func initWithForce(topLevelDir: String, force: Bool): ResolverFileSystem {
        return ResolverFileSystem(topLevelDir)
    }

    // ========================================================================
    // 文件描述符管理 - 对应 Bun FileSystem.setMaxFd()
    // ========================================================================

    /// 设置最大文件描述符 - 对应 Bun FileSystem.setMaxFd()
    public func setMaxFd(fd: Int64): Unit {
        if (fd > maxFd) {
            maxFd = fd
        }
    }

    // ========================================================================
    // 临时目录和文件 - 对应 Bun FileSystem.tmpdir() / tmpname()
    // ========================================================================

    /// 获取临时目录 - 对应 Bun FileSystem.tmpdir()
    public func tmpdir(): String {
        return RealFS.tmpdirPath()
    }

    /// 通过文件描述符获取路径 - 对应 Bun FileSystem.getFdPath()
    public func getFdPath(fd: Int64): String {
        // 简化: 在 Bun 中，这里会调用 bun.getFdPath()
        return ""
    }

    /// 生成临时文件名 - 对应 Bun FileSystem.tmpname()
    /// 格式: ".{hex}-{counter}.{extname}"
    public func tmpname(extname: String, hash: UInt64): String {
        let id = ".tmp-" + hash.toString() + extname
        return id
    }

    // ========================================================================
    // 路径操作 - 对应 Bun FileSystem 中的路径方法
    // ========================================================================

    /// 规范化路径 - 对应 Bun FileSystem.normalize()
    /// 移除多余的 '.' '..' 和重复的分隔符
    public func normalize(str: String): String {
        return Path.normalize(str)
    }

    /// 规范化路径到缓冲区 - 对应 Bun FileSystem.normalizeBuf()
    public func normalizeBuf(str: String): String {
        return Path.normalize(str)
    }

    /// 路径拼接 - 对应 Bun FileSystem.join()
    public func join(parts: Array<String>): String {
        return Path.join(parts)
    }

    /// 路径拼接到缓冲区 - 对应 Bun FileSystem.joinBuf()
    public func joinBuf(parts: Array<String>): String {
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

    /// 绝对路径拼接到缓冲区 - 对应 Bun FileSystem.absBuf()
    public func absBuf(parts: Array<String>): String {
        return abs(parts)
    }

    /// 检查路径拼接是否在缓冲区内 - 对应 Bun FileSystem.absBufChecked()
    /// 用于防止用户输入的过长路径导致缓冲区溢出
    public func absBufChecked(parts: Array<String>): ?String {
        let result = abs(parts)
        // 简化: 始终返回结果 (Bun 中检查缓冲区长度)
        return Some(result)
    }

    /// 绝对路径拼接 (零终止) - 对应 Bun FileSystem.absBufZ()
    public func absBufZ(parts: Array<String>): String {
        return abs(parts)
    }

    /// 绝对路径分配 - 对应 Bun FileSystem.absAlloc()
    public func absAlloc(parts: Array<String>): String {
        return abs(parts)
    }

    /// 绝对路径分配 (零终止) - 对应 Bun FileSystem.absAllocZ()
    public func absAllocZ(parts: Array<String>): String {
        return abs(parts)
    }

    /// 路径拼接分配 - 对应 Bun FileSystem.joinAlloc()
    public func joinAlloc(parts: Array<String>): String {
        return join(parts)
    }

    /// 相对路径计算 - 对应 Bun FileSystem.relative()
    public func relative(from: String, to: String): String {
        // 简化实现: 如果 to 以 from 开头则返回相对部分
        if (to.startsWith(from)) {
            let rel = to[Int64(from.size)..to.size]
            if (rel.startsWith("/")) {
                return rel[Int64(1)..rel.size]
            }
            return rel
        }
        return to
    }

    /// 平台相对路径计算 - 对应 Bun FileSystem.relativePlatform()
    public func relativePlatform(from: String, to: String): String {
        return relative(from, to)
    }

    /// 相对于顶层目录的路径 - 对应 Bun FileSystem.relativeTo()
    public func relativeTo(to: String): String {
        relative(topLevelDir, to)
    }

    /// 从指定路径相对到顶层目录 - 对应 Bun FileSystem.relativeFrom()
    public func relativeFrom(from: String): String {
        relative(from, topLevelDir)
    }

    /// 获取不带尾部斜杠的顶层目录 - 对应 Bun FileSystem.topLevelDirWithoutTrailingSlash()
    public func topLevelDirWithoutTrailingSlash(): String {
        if (topLevelDir.size > 1 && topLevelDir.endsWith("/")) {
            return topLevelDir[Int64(0)..Int64(topLevelDir.size - 1)]
        }
        return topLevelDir
    }

    /// 打印资源限制 - 对应 Bun FileSystem.printLimits()
    public func printLimits(): Unit {
        // 简化: 在 Bun 中，这里会打印 stack 和 files 的 rlimit
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
            case Some(cached) =>
                match (cached.kind) {
                    case EntriesOptionKind.Entries =>
                        match (cached.entries) {
                            case Some(entries) =>
                                if (entries.generation >= generation) {
                                    return cached
                                }
                            case None => ()
                        }
                    case EntriesOptionKind.Err => return cached
                }
            case None => ()
        }

        // 读取目录
        // 对应 Bun: src/resolver/fs.zig:957-989 (readdir 函数)
        // 使用 bao_sys.DirIterator (POSIX opendir/readdir) 遍历目录条目
        let iterResult = DirIterator.open(dir)
        match (iterResult) {
            case Ok(iter) =>
                let dirEntries = FSDirEntry(dir, generation)
                while (true) {
                    let entry = iter.next()
                    match (entry) {
                        case Some(dirEntry) =>
                            // 确定条目类型 - 对应 Bun DirEntry.Entry.addEntry 使用 bun.S_ISDIR()
                            // DirEntryType 已从 dirent.d_type 获取文件类型
                            let kind = match (dirEntry.entryType) {
                                case DirEntryType.Directory => EntryKind.Dir
                                case _ => EntryKind.File
                            }
                            let fsEntry = FSEntry(dirEntry.name, dir, kind)
                            dirEntries.addEntry(fsEntry)
                        case None => break
                    }
                }
                iter.close()
                let result = EntriesOption(dirEntries)
                entriesCache.put(dir, result)
                return result
            case Err(err) =>
                let dirErr = DirEntryError(err.toString(), err.toString())
                let result = EntriesOption(dirErr)
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

    /// 检查目录名是否存在 - 对应 Bun DirnameStore.instance.exists()
    public func dirnameExists(dir: String): Bool {
        return dirnameStore.contains(dir)
    }

    /// 检查文件名是否存在 - 对应 Bun FilenameStore.instance.exists()
    public func filenameExists(name: String): Bool {
        return filenameStore.contains(name)
    }

    /// 清除目录条目缓存 - 对应 Bun RealFS.bustEntriesCache()
    public func bustEntriesCache(path: String): Bool {
        match (entriesCache.remove(path)) {
            case Some(_) => true
            case None => false
        }
    }

    /// 释放资源 - 对应 Bun FileSystem.deinit()
    public func deinit(): Unit {
        entriesCache.clear()
        dirnameStore.clear()
        filenameStore.clear()
        fs.deinit()
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
    let firstSlash = match (path.indexOf('/')) { case Some(i) => i case None => match (path.indexOf('\\')) { case Some(i) => i case None => Int64(-1) } }
    if (firstSlash < 0) {
        return None
    }

    var remaining = path[Int64(firstSlash + 1)..path.size]

    while (remaining.size > 0) {
        var segment = remaining
        let nextSlash = match (remaining.indexOf('/')) { case Some(i) => i case None => match (remaining.indexOf('\\')) { case Some(i) => i case None => Int64(-1) } }
        if (nextSlash >= 0) {
            segment = remaining[Int64(0)..Int64(nextSlash)]
            remaining = remaining[Int64(nextSlash + 1)..remaining.size]
        } else {
            remaining = ""
        }

        match (segment.size) {
            case 1 =>
                if (segment == ".") {
                    return Some(segment)
                }
            case 2 =>
                if (segment == "..") {
                    return Some(segment)
                }
            case 13 =>  // "node_modules".size
                if (segment == "node_modules") {
                    return Some(segment)
                }
            case _ => ()
        }
    }

    return None
}

// ============================================================================
// printHandle - 打印文件句柄
// 严格翻译自: src/resolver/fs.zig printHandle()
// 对应 Bun: 用于调试输出文件句柄信息
// ============================================================================

/// 打印文件句柄 - 对应 Bun printHandle()
/// 根据句柄类型生成调试字符串
public func printHandle(handle: Int64): String {
    return handle.toString()
}
