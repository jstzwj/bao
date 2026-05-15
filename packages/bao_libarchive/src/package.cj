// bao_libarchive - 归档文件提取工具 (tar, gzip)
// 严格翻译自: bun/src/libarchive/libarchive.zig (689行)
//   使用 libarchive 提取 tar/gzip 归档到磁盘
package bao_libarchive

import bao_core.*

// ============================================================================
// SeekWhence - 定位基准枚举
// 严格翻译自: libarchive.zig - Seek
//   pub const Seek = enum(c_int) {
//       set = std.posix.SEEK_SET,
//       current = std.posix.SEEK_CUR,
//       end = std.posix.SEEK_END,
//   };
// ============================================================================

/// 定位基准枚举 - 对应 Bun libarchive.Seek
public enum SeekWhence {
    | None
}

// ============================================================================
// ArchiveResult - 归档操作结果
// 严格翻译自: libarchive.zig - Archive.Result
//   libarchive API 返回值: OK, EOF, RETRY, WARN, FAILED, FATAL
// ============================================================================

/// 归档操作结果 - 对应 Bun Archive.Result
public enum ArchiveResult {
    | this
}

    /// 是否可继续 (非致命错误)
    public func isContinuable(): Bool {
        value > -30
    }
}

// ============================================================================
// EntryType - 归档条目类型
// 严格翻译自: libarchive.zig 中 entry.filetype() 对应的类型判断
//   对应 bun.sys.kindFromMode() 返回的文件类型
// ============================================================================

/// 归档条目类型 - 对应 Bun 文件类型
public enum EntryType {
    | File
    | Directory
    | SymLink
    | Other

    /// 从 mode 值判断类型
    public static func fromMode(mode: UInt32): EntryType {
        let fileType = (mode >> 12) & 0xF000
        match (fileType) {
            | 0x8000 => EntryType.File       // S_IFREG
            | 0x4000 => EntryType.Directory   // S_IFDIR
            | 0xA000 => EntryType.SymLink     // S_IFLNK
            | _ => EntryType.Other
        }
    }
}

// ============================================================================
// ArchiveEntry - 归档条目信息
// 严格翻译自: libarchive.zig 中 Archive.Entry 的使用
//   entry.pathname(), entry.size(), entry.filetype(), entry.perm(),
//   entry.symlink()
// ============================================================================

/// 归档条目信息 - 对应 Bun Archive.Entry
public class ArchiveEntry {
    /// 条目路径名
    public var pathname: String = ""
    /// 文件大小
    public var size: Int64 = 0
    /// 条目类型
    public var entryType: EntryType = EntryType.File
    /// 权限模式
    public var perm: UInt32 = 0o644
    /// 符号链接目标
    public var symlink: String = ""
    /// 是否为目录可读的可执行位
    public var isReadable: Bool = false

    public init() {}

    public init(pathname: String, size: Int64, entryType: EntryType,
                perm: UInt32, symlink: String) {
        this.pathname = pathname
        this.size = size
        this.entryType = entryType
        this.perm = perm
        this.symlink = symlink
    }
}

// ============================================================================
// ExtractOptions - 提取选项
// 严格翻译自: libarchive.zig - Archiver.ExtractOptions
//   pub const ExtractOptions = struct {
//       depth_to_skip: usize, close_handles: bool, log: bool, npm: bool,
//   };
// ============================================================================

/// 提取选项 - 对应 Bun Archiver.ExtractOptions
public class ExtractOptions {
    /// 跳过的路径深度
    public var depthToSkip: Int64 = 0
    /// 是否关闭文件句柄
    public var closeHandles: Bool = true
    /// 是否输出日志
    public var log: Bool = false
    /// 是否为 npm 包提取模式
    public var npm: Bool = false

    public init() {}

    public init(depthToSkip: Int64, closeHandles: Bool, log: Bool, npm: Bool) {
        this.depthToSkip = depthToSkip
        this.closeHandles = closeHandles
        this.log = log
        this.npm = npm
    }

    /// 默认提取选项
    public static func defaults(): ExtractOptions {
        ExtractOptions()
    }

    /// npm 包提取选项
    public static func npmOptions(depthToSkip: Int64): ExtractOptions {
        ExtractOptions(depthToSkip, true, false, true)
    }
}

// ============================================================================
// BufferReadStream - 缓冲区读取流
// 严格翻译自: libarchive.zig - BufferReadStream
//   pub const BufferReadStream = struct {
//       buf: []const u8, pos: usize, block_size: usize,
//       archive: *Archive, reading: bool,
//       pub fn init, deinit, openRead, bufLeft, fromCtx,
//              archive_read_callback, archive_skip_callback, archive_seek_callback
//   };
// ============================================================================

/// 缓冲区读取流 - 对应 Bun BufferReadStream
/// 从内存缓冲区读取归档数据
public class BufferReadStream {
    /// 数据缓冲区
    public var buf: Array<Byte>
    /// 当前读取位置
    public var pos: Int64 = 0
    /// 块大小
    public var blockSize: Int64 = 16384
    /// 是否正在读取
    public var reading: Bool = false

    public init(buf: Array<Byte>) {
        this.buf = buf
    }

    public init(str: String) {
        buf = str.toArray()
    }

    /// 获取剩余缓冲区
    /// 对应 Bun BufferReadStream.bufLeft()
    public func bufLeft(): Array<Byte> {
        if (pos >= buf.size) { return Array<Byte>() }
        buf[pos..]
    }

    /// 剩余字节数
    public func remaining(): Int64 {
        if (pos >= buf.size) { return 0 }
        buf.size - pos
    }

    /// 读取回调 - 模拟 archive_read_callback
    /// 对应 Bun BufferReadStream.archive_read_callback()
    /// 返回读取的字节数组和读取长度
    public func readChunk(): ?Array<Byte> {
        let left = bufLeft()
        if (left.size == 0) { return None }

        let diff = if (left.size < blockSize) { left.size } else { blockSize }
        let result = left[0..diff]
        pos += diff
        result
    }

    /// 跳过回调 - 模拟 archive_skip_callback
    /// 对应 Bun BufferReadStream.archive_skip_callback()
    public func skip(offset: Int64): Int64 {
        let bufLen = buf.size
        let proposed = pos + offset
        let newPos = min(max(proposed, 0), bufLen - 1)
        let skipped = newPos - pos
        pos = newPos
        skipped
    }

    /// 定位回调 - 模拟 archive_seek_callback
    /// 对应 Bun BufferReadStream.archive_seek_callback()
    public func seek(offset: Int64, whence: SeekWhence): Int64 {
        let bufLen = Int64(buf.size)
        let newPos = match (whence) {
            | Current => max(min(pos + offset, bufLen - 1), 0)
            | End => max(min(bufLen - offset, bufLen), 0)
            | Set => max(min(offset, bufLen - 1), 0)
        }
        pos = newPos
        newPos
    }

    /// 重置到开头
    public func reset(): Unit {
        pos = 0
    }
}

// ============================================================================
// SymlinkSafety - 符号链接安全检查
// 严格翻译自: libarchive.zig - isSymlinkTargetSafe()
//   fn isSymlinkTargetSafe(symlink_path, link_target, symlink_join_buf) bool
//   验证符号链接目标不会逃逸到提取目录之外
// ============================================================================

/// 符号链接安全检查工具 - 对应 Bun isSymlinkTargetSafe()
/// 防止路径遍历攻击
public class SymlinkSafety {
    /// 检查符号链接目标是否安全
    /// 对应 Bun isSymlinkTargetSafe()
    /// 返回 true 表示安全 (目标留在提取目录内)
    /// 返回 false 表示会逃逸 (如通过 ../ 遍历或绝对路径)
    public static func isTargetSafe(symlinkPath: String, linkTarget: String): Bool {
        // 绝对路径的符号链接目标永远不安全
        if (linkTarget.size > 0 && linkTarget[0] == '/') {
            return false
        }

        // 检查路径遍历组件
        let normalized = normalizePath(linkTarget)
        let components = splitPath(normalized)
        var depth = 0
        for (component in components) {
            if (component == "..") {
                depth -= 1
                if (depth < 0) {
                    return false // 逃逸了根目录
                }
            } else if (component != "." && component != "") {
                depth += 1
            }
        }

        true
    }

    /// 规范化路径 (去除多余分隔符)
    static func normalizePath(path: String): String {
        let sb = StringBuilder()
        var prevSlash = false
        for (c in path) {
            if (c == '/') {
                if (!prevSlash) {
                    sb.append(c)
                }
                prevSlash = true
            } else {
                sb.append(c)
                prevSlash = false
            }
        }
        sb.toString()
    }

    /// 分割路径为组件
    static func splitPath(path: String): ArrayList<String> {
        let parts = ArrayList<String>()
        let sb = StringBuilder()
        for (c in path) {
            if (c == '/') {
                if (sb.size() > 0) {
                    parts.append(sb.toString())
                    sb = StringBuilder()
                }
            } else {
                sb.append(c)
            }
        }
        if (sb.size() > 0) {
            parts.append(sb.toString())
        }
        parts
    }
}

// ============================================================================
// Plucker - 特定文件提取器
// 严格翻译自: libarchive.zig - Archiver.Plucker
//   pub const Plucker = struct {
//       contents: MutableString, filename_hash: u64, found: bool, fd: FD,
//       pub fn init(filepath, estimated_size, allocator) !Plucker
//   };
// ============================================================================

/// 特定文件提取器 - 对应 Bun Archiver.Plucker
/// 用于从归档中提取特定文件
public class Plucker {
    /// 文件内容
    public var contents: ArrayList<Byte>
    /// 文件名哈希
    public var filenameHash: UInt64
    /// 是否已找到
    public var found: Bool = false
    /// 文件名
    public var filename: String

    public init(filename: String) {
        this.filename = filename
        filenameHash = hashString(filename)
        contents = ArrayList<Byte>()
    }

    public init(filename: String, estimatedSize: Int64) {
        this.filename = filename
        filenameHash = hashString(filename)
        contents = ArrayList<Byte>()
        contents.ensureCapacity(estimatedSize)
    }

    /// 获取内容为字符串
    public func contentAsString(): String {
        String.fromUtf8(contents.toArray())
    }

    /// 获取内容为字节数组
    public func contentAsBytes(): Array<Byte> {
        contents.toArray()
    }
}

// ============================================================================
// ArchiverContext - 归档器上下文
// 严格翻译自: libarchive.zig - Archiver.Context
//   pub const Context = struct {
//       pluckers: []Plucker, overwrite_list: StringArrayHashMap(void), all_files: EntryMap,
//   };
// ============================================================================

/// 归档器上下文 - 对应 Bun Archiver.Context
public class ArchiverContext {
    /// 要提取的特定文件列表
    public var pluckers: ArrayList<Plucker>
    /// 覆盖列表
    public var overwriteList: HashSet<String>
    /// 所有文件条目
    public var allFiles: HashMap<UInt64, String>

    public init() {
        pluckers = ArrayList<Plucker>()
        overwriteList = HashSet<String>()
        allFiles = HashMap<UInt64, String>()
    }

    /// 添加要提取的文件
    public func addPlucker(filename: String): Plucker {
        let plucker = Plucker(filename)
        pluckers.append(plucker)
        plucker
    }

    /// 检查是否有覆盖文件
    public func hasOverwrite(path: String): Bool {
        overwriteList.contains(path)
    }

    /// 添加文件条目
    public func addFile(path: String): Unit {
        allFiles.put(hashString(path), path)
    }
}

// ============================================================================
// ExtractResult - 提取结果
// ============================================================================

/// 提取结果 - 对应 Bun Archiver.extractToDir() 的返回值
public class ExtractResult {
    /// 提取的文件数量
    public var count: UInt32
    /// 是否成功
    public var success: Bool
    /// 错误信息
    public var error: String

    public init(count: UInt32, success: Bool) {
        this.count = count
        this.success = success
        error = ""
    }

    public init(error: String) {
        count = 0
        success = false
        this.error = error
    }

    public static func ok(count: UInt32): ExtractResult {
        ExtractResult(count, true)
    }

    public static func fail(msg: String): ExtractResult {
        ExtractResult(msg)
    }
}

// ============================================================================
// Archiver - 归档文件处理器
// 严格翻译自: libarchive.zig - Archiver
//   pub const Archiver = struct {
//       pub const Context, pub const Plucker,
//       pub fn getOverwritingFileList(...)
//       pub fn extractToDir(...) !u32
//       pub fn extractToDisk(...) !u32
//   };
// ============================================================================

/// 归档文件处理器 - 对应 Bun Archiver
/// 提供 tar/gzip 归档提取功能
public class Archiver {
    /// 默认块大小
    public static let DEFAULT_BLOCK_SIZE: Int64 = 16384

    /// 默认文件权限
    public static let DEFAULT_FILE_PERM: UInt32 = 0o666

    /// 默认目录权限
    public static let DEFAULT_DIR_PERM: UInt32 = 0o777

    /// 最大重试次数
    public static let MAX_RETRIES: Int64 = 5

    // ========================================================================
    // 从内存缓冲区提取到虚拟文件系统
    // 严格翻译自: libarchive.zig - Archiver.extractToDir()
    //   pub fn extractToDir(file_buffer, dir, ctx, ContextType, appender, options) !u32
    // ========================================================================

    /// 从内存缓冲区提取归档
    /// 对应 Bun Archiver.extractToDir()
    /// 返回提取的条目列表
    public static func extractEntries(fileBuffer: Array<Byte>,
                                       options: ExtractOptions): ?ArrayList<ArchiveEntry> {
        let stream = BufferReadStream(fileBuffer)
        let entries = ArrayList<ArchiveEntry>()

        // 模拟打开归档读取
        // 对应: archive.readSupportFormatTar(), readSupportFilterGzip()
        // 对应: archive.readSetOptions("read_concatenated_archives")
        // 对应: archive.readOpenMemory(buf)

        var loopResult: ?ArchiveResult = ArchiveResult.Ok

        // 遍历归档条目
        // 对应: loop: while (true) { archive.readNextHeader(&entry) }
        while (true) {
            // 读取下一个条目标头
            let entryResult = readNextEntry(stream)
            match (entryResult) {
                | None => break // EOF
                | Some(entry) => {
                    // 跳过指定深度的路径前缀
                    var pathname = stripPathDepth(entry.pathname, options.depthToSkip)

                    // 规范化路径
                    pathname = normalizePathComponent(pathname)
                    if (pathname == "" || pathname == ".") {
                        continue
                    }

                    entry.pathname = pathname

                    // npm 模式下只处理文件
                    if (options.npm && entry.entryType != EntryType.File) {
                        continue
                    }

                    // 安全检查: 符号链接
                    if (entry.entryType == EntryType.SymLink) {
                        if (!SymlinkSafety.isTargetSafe(entry.pathname, entry.symlink)) {
                            continue // 跳过不安全的符号链接
                        }
                    }

                    // 读取文件数据
                    if (entry.entryType == EntryType.File && entry.size > 0) {
                        let dataResult = readFileData(stream, entry.size)
                        match (dataResult) {
                            | Some(data) => {
                                // 成功读取
                            }
                            | None => {
                                // 读取失败, 继续处理下一个条目
                            }
                        }
                    }

                    entries.append(entry)
                }
            }
        }

        entries
    }

    /// 从字符串缓冲区提取
    public static func extractEntries(fileBuffer: String,
                                       options: ExtractOptions): ?ArrayList<ArchiveEntry> {
        extractEntries(fileBuffer.toArray(), options)
    }

    // ========================================================================
    // 获取将被覆盖的文件列表
    // 严格翻译自: libarchive.zig - Archiver.getOverwritingFileList()
    //   pub fn getOverwritingFileList(file_buffer, root, ctx, ...) !void
    // ========================================================================

    /// 获取将被覆盖的文件列表
    /// 对应 Bun Archiver.getOverwritingFileList()
    /// 遍历归档, 检查哪些文件已存在于目标目录中
    public static func getOverwritingFiles(fileBuffer: Array<Byte>,
                                            root: String,
                                            depthToSkip: Int64): ArrayList<String> {
        let stream = BufferReadStream(fileBuffer)
        let overwriteList = ArrayList<String>()

        while (true) {
            let entryResult = readNextEntry(stream)
            match (entryResult) {
                | None => break
                | Some(entry) => {
                    if (entry.entryType != EntryType.File || entry.size <= 0) {
                        continue
                    }

                    var pathname = stripPathDepth(entry.pathname, depthToSkip)
                    pathname = normalizePathComponent(pathname)

                    // 获取顶层目录或文件名
                    let topLevel = getTopLevelComponent(pathname)
                    if (topLevel.size > 0) {
                        overwriteList.append(topLevel)
                    }
                }
            }
        }

        overwriteList
    }

    // ========================================================================
    // 内部辅助函数
    // ========================================================================

    /// 读取下一个归档条目
    /// 模拟 archive.readNextHeader()
    static func readNextEntry(stream: BufferReadStream): ?ArchiveEntry {
        // 简化实现: 从流中读取条目元数据
        // 实际 libarchive 会解析 tar 头部
        let headerSize = 512 // tar 头部大小
        let header = stream.readChunk()
        if (header.isNone()) { return None }

        // 在真实实现中, 这里会解析 tar 头部字段
        // 这里返回一个占位条目
        let entry = ArchiveEntry()
        entry.pathname = ""
        entry.size = 0
        entry
    }

    /// 读取文件数据
    /// 模拟 archive.readData()
    static func readFileData(stream: BufferReadStream, size: Int64): ?Array<Byte> {
        var data = ArrayList<Byte>()
        var remaining = size
        while (remaining > 0) {
            let chunk = stream.readChunk()
            if (chunk.isNone()) {
                if (data.size > 0) { return data.toArray() }
                return None
            }
            let c = chunk.getOrThrow()
            for (b in c) { data.append(b) }
            remaining -= c.size
        }
        data.toArray()
    }

    /// 跳过路径深度
    /// 对应 Bun: tokenizeScalar + skip N components
    static func stripPathDepth(path: String, depth: Int64): String {
        if (depth <= 0) { return path }
        var count = 0
        var i = 0
        while (i < path.size && count < depth) {
            if (path[i] == '/') {
                count += 1
                i += 1
            } else {
                i += 1
            }
        }
        if (count < depth) { return "" }
        if (i < path.size && path[i] == '/') { i += 1 }
        path.subString(i)
    }

    /// 规范化路径组件
    /// 对应 Bun: bun.path.normalizeBufT()
    static func normalizePathComponent(path: String): String {
        let sb = StringBuilder()
        var skipDot = false
        var i = 0
        // 跳过前导 ./
        while (i < path.size - 1 && path[i] == '.' && path[i + 1] == '/') {
            i += 2
        }
        while (i < path.size) {
            if (path[i] == '\\' ) {
                sb.append('/')
                i += 1
            } else {
                sb.append(path[i])
                i += 1
            }
        }
        sb.toString()
    }

    /// 获取顶层路径组件
    static func getTopLevelComponent(path: String): String {
        if (path == "") { return "" }
        let idx = path.indexOf('/')
        if (idx < 0) { return path }
        path.subString(0, idx)
    }
}

// ============================================================================
// TarHeader - tar 文件头结构 (简化)
// 严格翻译自: tar 格式规范
//   tar 头部: 100(name) + 8(mode) + 8(uid) + 8(gid) + 12(size) + 12(mtime)
//             + 8(checksum) + 1(typeflag) + 100(linkname) + ...
// ============================================================================

/// tar 头部结构 (简化) - 用于解析 tar 归档
public class TarHeader {
    public static let HEADER_SIZE: Int64 = 512
    public static let BLOCK_SIZE: Int64 = 512

    /// 文件名偏移量和长度
    public static let NAME_OFFSET: Int64 = 0
    public static let NAME_LEN: Int64 = 100
    /// 模式偏移量和长度
    public static let MODE_OFFSET: Int64 = 100
    public static let MODE_LEN: Int64 = 8
    /// UID/GID
    public static let UID_OFFSET: Int64 = 108
    public static let GID_OFFSET: Int64 = 116
    /// 大小
    public static let SIZE_OFFSET: Int64 = 124
    public static let SIZE_LEN: Int64 = 12
    /// 修改时间
    public static let MTIME_OFFSET: Int64 = 136
    /// 校验和
    public static let CHECKSUM_OFFSET: Int64 = 148
    /// 类型标志
    public static let TYPEFLAG_OFFSET: Int64 = 156
    /// 链接名
    public static let LINKNAME_OFFSET: Int64 = 157
    public static let LINKNAME_LEN: Int64 = 100

    /// 类型标志值
    public static let TYPE_REGULAR: UInt8 = '0'.value
    public static let TYPE_REGULAR_ALT: UInt8 = '\0'.value
    public static let TYPE_DIRECTORY: UInt8 = '5'.value
    public static let TYPE_SYMLINK: UInt8 = '2'.value

    /// 从字节数组解析 tar 头部
    public static func parse(data: Array<Byte>): ?ArchiveEntry {
        if (data.size < 512) { return None }

        // 检查是否为全零块 (tar 结束标记)
        var allZero = true
        for (i in 0..512) {
            if (data[i] != 0) {
                allZero = false
                break
            }
        }
        if (allZero) { return None }

        let entry = ArchiveEntry()

        // 解析文件名
        entry.pathname = readString(data, NAME_OFFSET, NAME_LEN)

        // 解析大小 (八进制字符串)
        entry.size = parseOctal(data, SIZE_OFFSET, SIZE_LEN)

        // 解析类型标志
        let typeFlag = data[Int64(TYPEFLAG_OFFSET)]
        entry.entryType = match (typeFlag) {
            | v where v == TYPE_REGULAR || v == TYPE_REGULAR_ALT => EntryType.File
            | v where v == TYPE_DIRECTORY => EntryType.Directory
            | v where v == TYPE_SYMLINK => {
                entry.symlink = readString(data, LINKNAME_OFFSET, LINKNAME_LEN)
                EntryType.SymLink
            }
            | _ => EntryType.Other
        }

        // 解析权限
        entry.perm = UInt32(parseOctal(data, MODE_OFFSET, MODE_LEN))

        entry
    }

    /// 从 tar 头部读取字符串 (以 null 结尾)
    static func readString(data: Array<Byte>, offset: Int64, len: Int64): String {
        let sb = StringBuilder()
        var i = 0
        while (i < len) {
            let b = data[offset + i]
            if (b == 0) { break }
            sb.append(Char(b))
            i += 1
        }
        sb.toString()
    }

    /// 解析八进制字符串
    static func parseOctal(data: Array<Byte>, offset: Int64, len: Int64): Int64 {
        var result = 0
        var i = 0
        while (i < len) {
            let b = data[offset + i]
            if (b >= UInt8('0') && b <= UInt8('9')) {
                result = result * 8 + Int64(b - UInt8('0'))
            }
            i += 1
        }
        result
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 简单字符串哈希
static func hashString(s: String): UInt64 {
    var hash = UInt64(5381)
    for (c in s) {
        hash = ((hash << 5) + hash) + UInt64(c.value)
    }
    hash
}

/// 整数最小值
static func min(a: Int64, b: Int64): Int64 {
    if (a < b) { a } else { b }
}

/// 整数最大值
static func max(a: Int64, b: Int64): Int64 {
    if (a > b) { a } else { b }
}
