// 严格翻译自: src/runtime/api/Archive.rs + Archive.zig
// Bun.Archive — tar/tgz pack + extract over libarchive.
// 使用 libarchive FFI 实现归档操作
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue, JsCallFrame, JsObject, ZigString, JsFunction}
import bao_collections.ArrayList
import bao_core.{Allocator, Output}
import bao_libarchive_sys.{StructArchive, StructArchiveEntry}
import bao_libarchive_sys.{LaInt64T, LaSsizeT, ModeT}
import bao_libarchive_sys.*

// ============================================================================
// C 内存分配函数声明
// ============================================================================

foreign func malloc(size: UIntNative): CPointer<Unit>
foreign func free(ptr: CPointer<Unit>): Unit

// ============================================================================
// POSIX 文件系统函数声明 (用于 extract/write)
// ============================================================================

foreign func open(path: CPointer<Int8>, flags: Int32, mode: UInt32): Int32
foreign func close(fd: Int32): Int32
foreign func write(fd: Int32, buf: CPointer<Unit>, count: UIntNative): UIntNative
foreign func mkdir(path: CPointer<Int8>, mode: UInt32): Int32
foreign func unlink(path: CPointer<Int8>): Int32
foreign func symlink(target: CPointer<Int8>, linkpath: CPointer<Int8>): Int32

// ============================================================================
// C 字符串辅助函数
// ============================================================================

/// 将仓颉 String 转为 C null-terminated 字符串 (CPointer<UInt8>)
/// 调用者负责调用 freeCString 释放
func archiveNewCString(s: String): CPointer<UInt8> {
    unsafe {
        let len = s.size
        let ptr = malloc(UIntNative(len + 1))
        let bytesPtr = CPointer<UInt8>(ptr)
        for (i in 0..len) {
            (bytesPtr + Int64(i)).write(UInt8(Int64(s[Int64(i)]) & 0xFF))
        }
        (bytesPtr + Int64(len)).write(UInt8(0))
        bytesPtr
    }
}

/// 将 Array<UInt8> 转为 C 指针 (通过 malloc 复制)
/// 调用者负责释放
func archiveBytesToCPtr(arr: Array<UInt8>): CPointer<Unit> {
    unsafe {
        let len = arr.size
        let ptr = malloc(UIntNative(len))
        for (i in 0..len) {
            (CPointer<UInt8>(ptr) + Int64(i)).write(arr[Int64(i)])
        }
        ptr
    }
}

/// 从 C 字符串指针读取为仓颉 String
func cStringToString(ptr: CPointer<UInt8>): String {
    if (ptr.isNull()) { return "" }
    unsafe {
        let sb = StringBuilder()
        var i = Int64(0)
        var ch = (ptr + i).read()
        while (ch != UInt8(0)) {
            sb.append(ch)
            i += 1
            ch = (ptr + i).read()
        }
        sb.toString()
    }
}

/// 释放 C 字符串
func freeCString(ptr: CPointer<UInt8>): Unit {
    unsafe { free(CPointer<Unit>(ptr)) }
}

/// 释放 C 内存
func freeCPtr(ptr: CPointer<Unit>): Unit {
    unsafe { free(ptr) }
}

/// S_IFREG — AE_IFREG (regular file type for libarchive)
/// 对应 Bun Archive.rs: const FILETYPE_REGULAR: u32 = 0o100000
let ARCHIVE_ENTRY_FILETYPE_REGULAR: UInt32 = UInt32(0o100000)

/// ARCHIVE_OK
let ARCHIVE_OK: Int32 = Int32(0)

/// ARCHIVE_EOF
let ARCHIVE_EOF: Int32 = Int32(1)

/// O_WRONLY | O_CREAT | O_TRUNC
let O_WRONLY_CREAT_TRUNC: Int32 = Int32(0x241)

/// O_WRONLY | O_CREAT (for write without trunc)
let O_WRONLY_CREAT: Int32 = Int32(0x41)

/// Default file permission 0o644
let DEFAULT_FILE_PERM: UInt32 = UInt32(0x1A4)

/// Default directory permission 0o755
let DEFAULT_DIR_PERM: UInt32 = UInt32(0x1ED)

/// Read buffer size: 64KB
let READ_BUFFER_SIZE: Int64 = Int64(65536)

// ============================================================================
// BlobStore — Blob 底层存储
// ============================================================================

/// BlobStore stub
public class BlobStore {
    public var data: Array<UInt8>

    public init() {
        data = Array<UInt8>()
    }

    public init(data!: Array<UInt8>) {
        this.data = data
    }

    /// 获取数据的共享视图
    public func sharedView(): Array<UInt8> {
        data
    }
}

// ============================================================================
// Compression enum
// ============================================================================

/// Compression enum
public enum Compression {
    | compressionNone
    | gzip
    | brotli
    | zstd
}

// ============================================================================
// BlobOutputType enum
// ============================================================================

/// BlobOutputType enum
public enum BlobOutputType {
    | blob
    | bytes
}

// ============================================================================
// Archive — tar/tgz 归档操作
// 对应 Bun: src/runtime/api/Archive.rs + Archive.zig
// ============================================================================

/// Archive — tar/tgz 归档操作
/// 对应 Bun: src/runtime/api/Archive.rs
public class Archive {
    private var store: BlobStore = BlobStore()
    private var compress: Compression = Compression.compressionNone

    public init() {}
    public init(store!: BlobStore, compress!: Compression) {
        this.store = store
        this.compress = compress
    }

    /// 构造函数
    public static func constructor(globalThis!: JsGlobalObject, callframe!: JsCallFrame): Archive {
        let args = callframe.args(2)
        let dataArg = args[0]
        let optionsArg = args[1]

        // 解析压缩选项
        let compress = parseCompressionOptions(globalThis, optionsArg)

        // 尝试从 ArrayBuffer/TypedArray 获取数据
        if (!dataArg.isUndefinedOrNull() && dataArg.isObject()) {
            let obj = dataArg.toObject()
            if (obj.has("byteLength") || obj.has("buffer")) {
                // ArrayBuffer 或 TypedArray — 提取字节数据
                let bytes = dataArg.toByteArray()
                let store = BlobStore(bytes)
                return Archive(store, compress)
            }
        }

        // 默认空 Archive
        Archive()
    }

    // ========================================================================
    // extract - 提取归档到磁盘
    // 对应 Bun Archive.zig extract() -> Promise<number>
    // 使用 libarchive 的 archive_read_* API
    // ========================================================================

    /// extract - 提取归档到磁盘
    /// 返回 Promise<number> — 提取的文件数
    public func extract(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.args(2)
        let pathArg = args[0]
        let optionsArg = args[1]

        if (pathArg.isUndefinedOrNull() || !pathArg.isString()) {
            return globalThis.throwError("Archive.extract requires a path argument")
        }

        let path = pathArg.toSlice(globalThis.globalThis)

        // 解析 glob patterns
        var globPatterns: ?Array<String> = None
        if (!optionsArg.isUndefinedOrNull() && optionsArg.isObject()) {
            let obj = optionsArg.toObject()
            if (let Some(globVal) <- obj.get("glob")) {
                globPatterns = parsePatternArg(globalThis, globVal, "Archive.extract", "glob")
            }
        }

        // 获取归档数据
        let archiveData = store.sharedView()
        if (archiveData.size == 0) {
            return globalThis.throwError("Archive.extract: archive data is empty")
        }

        // 执行提取
        let result = extractToDisk(archiveData, path, globPatterns)
        match (result) {
            case Some(count) => JsValue.jsNumber(Int64(count))
            case None => globalThis.throwError("Archive.extract: failed to extract archive")
        }
    }

    // ========================================================================
    // blob - 返回归档数据的 Blob
    // 对应 Bun Archive.zig blob() -> Promise<Blob>
    // ========================================================================

    /// blob - 返回归档数据的 Blob
    public func blob(globalThis!: JsGlobalObject, frame!: JsCallFrame): JsValue {
        let data = store.sharedView()

        // 创建 Blob JS 对象
        let blobObj = JsObject()
        blobObj.className = "Blob"
        blobObj.set("size", JsValue(Float64(data.size)))
        blobObj.set("type", JsValue("application/octet-stream"))
        JsValue(blobObj)
    }

    // ========================================================================
    // bytes - 返回归档数据的 Uint8Array
    // 对应 Bun Archive.zig bytes() -> Promise<Uint8Array>
    // ========================================================================

    /// bytes - 返回归档数据的 Uint8Array
    public func bytes(globalThis!: JsGlobalObject, frame!: JsCallFrame): JsValue {
        let data = store.sharedView()

        // 创建 Uint8Array/Buffer JS 对象
        JsValue.createBuffer(globalThis.globalThis, data)
    }

    // ========================================================================
    // files - 返回归档文件内容的 Map
    // 对应 Bun Archive.zig files() -> Promise<Map<string, File>>
    // 使用 libarchive 遍历归档中的文件条目
    // ========================================================================

    /// files - 返回归档文件内容的 Map<string, File>
    public func files(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let globArg = callframe.args(1)[0]

        // 解析 glob patterns
        var globPatterns: ?Array<String> = None
        if (!globArg.isUndefinedOrNull()) {
            globPatterns = parsePatternArg(globalThis, globArg, "Archive.files", "glob")
        }

        // 获取归档数据
        let archiveData = store.sharedView()
        if (archiveData.size == 0) {
            return globalThis.throwError("Archive.files: archive data is empty")
        }

        // 遍历归档中的文件
        let entries = readArchiveFiles(archiveData, globPatterns)
        match (entries) {
            case None => globalThis.throwError("Archive.files: failed to read archive")
            case Some(fileList) =>
                // 创建 JS Map
                let mapObj = JsObject()
                mapObj.className = "Map"
                for (entry in fileList) {
                    let fileObj = JsObject()
                    fileObj.className = "File"
                    fileObj.set("name", JsValue(entry.pathname))
                    fileObj.set("size", JsValue(Float64(entry.data.size)))
                    fileObj.set("lastModified", JsValue(Float64(entry.mtime * 1000)))
                    mapObj.set(entry.pathname, JsValue(fileObj))
                }
                JsValue(mapObj)
        }
    }

    // ========================================================================
    // write - 静态方法, 写入归档到磁盘
    // 对应 Bun Archive.zig write() -> Promise<void>
    // ========================================================================

    /// write - 静态方法, 写入归档到磁盘
    public static func write(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.args(3)
        let pathArg = args[0]
        let dataArg = args[1]
        let optionsArg = args[2]

        if (pathArg.isUndefinedOrNull() || !pathArg.isString()) {
            return globalThis.throwError("Archive.write requires a path argument")
        }

        let path = pathArg.toSlice(globalThis.globalThis)

        // 获取数据
        var dataToWrite: Array<UInt8> = Array<UInt8>()
        if (!dataArg.isUndefinedOrNull() && dataArg.isObject()) {
            let obj = dataArg.toObject()
            // 尝试作为 ArrayBuffer/TypedArray
            if (obj.has("byteLength") || obj.has("buffer")) {
                dataToWrite = dataArg.toByteArray()
            } else {
                // 尝试作为普通对象构建 tarball
                let tarball = buildTarballFromObject(globalThis, dataArg)
                match (tarball) {
                    case Some(bytes) => dataToWrite = bytes
                    case None => return globalThis.throwError("Archive.write: failed to build tarball")
                }
            }
        }

        if (dataToWrite.size == 0) {
            return globalThis.throwError("Archive.write: no data to write")
        }

        // 写入文件
        let cPath = archiveNewCString(path)
        defer { freeCString(cPath) }

        let fd = unsafe { open(CPointer<Int8>(CPointer<Unit>(cPath)), O_WRONLY_CREAT_TRUNC, DEFAULT_FILE_PERM) }
        if (fd < 0) {
            return globalThis.throwError("Archive.write: failed to open file '${path}'")
        }

        let cData = archiveBytesToCPtr(dataToWrite)
        defer { freeCPtr(cData) }

        let written = unsafe { write(fd, cData, UIntNative(dataToWrite.size)) }
        unsafe { close(fd) }

        if (Int64(written) < 0) {
            return globalThis.throwError("Archive.write: failed to write data")
        }

        JsValue.jsUndefined()
    }

    /// Finalize - GC 回收时调用
    public func finalize(): Unit {}

    /// Pretty-print for console.log
    public func writeFormat(formatter!: Any, writer!: Any, enableAnsiColors!: Bool): Unit {}

    /// 从 JS 值获取 Archive 实例
    public static func fromJS(value!: JsValue): ?Archive { None }

    /// store_ref
    public func storeRef(): BlobStore { store }
}

// ============================================================================
// 归档操作的核心 libarchive FFI 封装
// ============================================================================

/// ArchiveFileEntry - 归档文件条目 (内部使用)
class ArchiveFileEntry {
    var pathname: String = ""
    var data: Array<UInt8> = Array<UInt8>()
    var mtime: Int64 = 0

    init() {}
    init(pathname!: String, data!: Array<UInt8>, mtime!: Int64) {
        this.pathname = pathname
        this.data = data
        this.mtime = mtime
    }
}

/// 文件类型 (内部使用)
enum FileKind {
    | File
    | Directory
    | SymLink
    | Other
}

/// 配置归档读取器 (支持 tar, gnutar, gzip)
/// 对应 Bun Archive.zig configureArchiveReader()
func configureArchiveReader(archive: CPointer<StructArchive>): Unit {
    unsafe {
        archive_read_support_format_tar(archive)
        archive_read_support_format_gnutar(archive)
        archive_read_support_filter_gzip(archive)
        // 支持级联归档 (多个 tar 连接在一起)
        let opts = archiveNewCString("read_concatenated_archives")
        archive_read_set_options(archive, opts)
        freeCString(opts)
    }
}

/// 统计归档中的文件数量
/// 对应 Bun Archive.zig countFilesInArchive()
func countFilesInArchiveImpl(data: Array<UInt8>): UInt32 {
    let archive = unsafe { archive_read_new() }
    if (archive.isNull()) { return UInt32(0) }

    configureArchiveReader(archive)

    let cData = archiveBytesToCPtr(data)
    defer { freeCPtr(cData) }

    let openRc = unsafe { archive_read_open_memory(archive, cData, UInt64(data.size)) }
    if (openRc != ARCHIVE_OK) {
        unsafe {
            archive_read_close(archive)
            archive_read_free(archive)
        }
        return UInt32(0)
    }

    var count: UInt32 = UInt32(0)

    // 为 archive_read_next_header 分配输出指针
    let entryPtrStorage = unsafe { malloc(UIntNative(8)) }
    defer { freeCPtr(entryPtrStorage) }

    while (true) {
        unsafe { (CPointer<CPointer<StructArchiveEntry>>(entryPtrStorage)).write(CPointer<StructArchiveEntry>()) }

        let rc = unsafe { archive_read_next_header(archive, CPointer<CPointer<StructArchiveEntry>>(entryPtrStorage)) }
        if (rc == ARCHIVE_EOF) { break }
        if (rc < ARCHIVE_OK) { break }

        let entryPtr = unsafe { (CPointer<CPointer<StructArchiveEntry>>(entryPtrStorage)).read() }
        if (entryPtr.isNull()) { continue }

        let filetype = unsafe { archive_entry_filetype(entryPtr) }
        if (filetype == ARCHIVE_ENTRY_FILETYPE_REGULAR) {
            count += UInt32(1)
        }
    }

    unsafe {
        archive_read_close(archive)
        archive_read_free(archive)
    }
    count
}

/// 从归档中读取所有文件条目
/// 对应 Bun Archive.rs FilesContext.do_run()
func readArchiveFiles(data: Array<UInt8>, globPatterns: ?Array<String>): ?ArrayList<ArchiveFileEntry> {
    let archive = unsafe { archive_read_new() }
    if (archive.isNull()) { return None }

    configureArchiveReader(archive)

    let cData = archiveBytesToCPtr(data)
    defer { freeCPtr(cData) }

    let openRc = unsafe { archive_read_open_memory(archive, cData, UInt64(data.size)) }
    if (openRc != ARCHIVE_OK) {
        unsafe {
            archive_read_close(archive)
            archive_read_free(archive)
        }
        return None
    }

    let entries = ArrayList<ArchiveFileEntry>()

    let entryPtrStorage = unsafe { malloc(UIntNative(8)) }
    defer { freeCPtr(entryPtrStorage) }

    while (true) {
        unsafe { (CPointer<CPointer<StructArchiveEntry>>(entryPtrStorage)).write(CPointer<StructArchiveEntry>()) }

        let rc = unsafe { archive_read_next_header(archive, CPointer<CPointer<StructArchiveEntry>>(entryPtrStorage)) }
        if (rc == ARCHIVE_EOF) { break }
        if (rc < ARCHIVE_OK) { break }

        let entryPtr = unsafe { (CPointer<CPointer<StructArchiveEntry>>(entryPtrStorage)).read() }
        if (entryPtr.isNull()) { continue }

        // 只处理常规文件
        let filetype = unsafe { archive_entry_filetype(entryPtr) }
        if (filetype != ARCHIVE_ENTRY_FILETYPE_REGULAR) { continue }

        // 获取路径名
        let pathnamePtr = unsafe { archive_entry_pathname_utf8(entryPtr) }
        let pathname = cStringToString(pathnamePtr)
        if (pathname.size == 0) { continue }

        // 应用 glob 过滤
        match (globPatterns) {
            case Some(patterns) =>
                if (!matchGlobPatterns(patterns, pathname)) { continue }
            case None => ()
        }

        // 获取文件大小
        let entrySize = unsafe { archive_entry_size(entryPtr) }

        // 读取文件数据
        var fileData = Array<UInt8>()
        if (entrySize > 0) {
            let buf = unsafe { malloc(UIntNative(READ_BUFFER_SIZE)) }
            defer { freeCPtr(buf) }

            var remaining = entrySize
            let dataList = ArrayList<UInt8>()
            while (remaining > 0) {
                let toRead = if (remaining < READ_BUFFER_SIZE) { remaining } else { READ_BUFFER_SIZE }
                let bytesRead = unsafe { archive_read_data(archive, buf, UInt64(toRead)) }
                if (bytesRead <= 0) { break }
                for (i in 0..bytesRead) {
                    dataList.add(unsafe { (CPointer<UInt8>(buf) + i).read() })
                }
                remaining -= bytesRead
            }
            fileData = dataList.toArray()
        }

        // 获取修改时间
        let mtime = unsafe { archive_entry_mtime(entryPtr) }

        entries.add(ArchiveFileEntry(pathname, fileData, mtime))
    }

    unsafe {
        archive_read_close(archive)
        archive_read_free(archive)
    }

    entries
}

/// 提取归档到磁盘
/// 对应 Bun Archive.zig extractToDisk() / extractToDir()
/// 使用 libarchive 的 archive_read API 配合 POSIX 文件系统操作
func extractToDisk(data: Array<UInt8>, rootPath: String, globPatterns: ?Array<String>): ?UInt32 {
    let archive = unsafe { archive_read_new() }
    if (archive.isNull()) { return None }

    configureArchiveReader(archive)

    let cData = archiveBytesToCPtr(data)
    defer { freeCPtr(cData) }

    let openRc = unsafe { archive_read_open_memory(archive, cData, UInt64(data.size)) }
    if (openRc != ARCHIVE_OK) {
        unsafe {
            archive_read_close(archive)
            archive_read_free(archive)
        }
        return None
    }

    // 创建目标目录 (如果不存在)
    let rootCStr = archiveNewCString(rootPath)
    defer { freeCString(rootCStr) }
    unsafe { mkdir(CPointer<Int8>(CPointer<Unit>(rootCStr)), DEFAULT_DIR_PERM) }

    let entryPtrStorage = unsafe { malloc(UIntNative(8)) }
    defer { freeCPtr(entryPtrStorage) }

    let buf = unsafe { malloc(UIntNative(READ_BUFFER_SIZE)) }
    defer { freeCPtr(buf) }

    var count: UInt32 = UInt32(0)

    while (true) {
        unsafe { (CPointer<CPointer<StructArchiveEntry>>(entryPtrStorage)).write(CPointer<StructArchiveEntry>()) }

        let rc = unsafe { archive_read_next_header(archive, CPointer<CPointer<StructArchiveEntry>>(entryPtrStorage)) }
        if (rc == ARCHIVE_EOF) { break }
        if (rc < ARCHIVE_OK) { break }

        let entryPtr = unsafe { (CPointer<CPointer<StructArchiveEntry>>(entryPtrStorage)).read() }
        if (entryPtr.isNull()) { continue }

        // 获取路径名
        let pathnamePtr = unsafe { archive_entry_pathname_utf8(entryPtr) }
        let pathname = cStringToString(pathnamePtr)
        if (pathname.size == 0) { continue }

        // 验证路径安全 (拒绝绝对路径和路径遍历)
        if (!isSafePath(pathname)) { continue }

        // 应用 glob 过滤
        match (globPatterns) {
            case Some(patterns) =>
                if (!matchGlobPatterns(patterns, pathname)) { continue }
            case None => ()
        }

        let filetype = unsafe { archive_entry_filetype(entryPtr) }
        let kind = kindFromMode(filetype)

        // 构建完整目标路径
        let fullPath = if (rootPath.size > 0) { "${rootPath}/${pathname}" } else { pathname }

        match (kind) {
            case FileKind.Directory =>
                let pathCStr = archiveNewCString(fullPath)
                unsafe { mkdir(CPointer<Int8>(CPointer<Unit>(pathCStr)), DEFAULT_DIR_PERM) }
                freeCString(pathCStr)
                count += UInt32(1)
            case FileKind.File =>
                let entrySize = unsafe { archive_entry_size(entryPtr) }
                // 获取权限
                let entryPerm = unsafe { archive_entry_perm(entryPtr) }
                let mode = if (entryPerm != UInt32(0)) { entryPerm & UInt32(0x1FF) } else { DEFAULT_FILE_PERM }

                // 创建父目录 (如果需要)
                let parentDir = getParentDir(fullPath)
                if (parentDir.size > 0) {
                    let parentCStr = archiveNewCString(parentDir)
                    unsafe { mkdir(CPointer<Int8>(CPointer<Unit>(parentCStr)), DEFAULT_DIR_PERM) }
                    freeCString(parentCStr)
                }

                // 打开/创建文件
                let fileCStr = archiveNewCString(fullPath)
                let fd = unsafe { open(CPointer<Int8>(CPointer<Unit>(fileCStr)), O_WRONLY_CREAT_TRUNC, mode) }
                freeCString(fileCStr)

                if (fd < 0) { continue }

                // 写入文件数据
                var writeSuccess = true
                if (entrySize > 0) {
                    var remaining = entrySize
                    while (remaining > 0) {
                        let toRead = if (remaining < READ_BUFFER_SIZE) { remaining } else { READ_BUFFER_SIZE }
                        let bytesRead = unsafe { archive_read_data(archive, buf, UInt64(toRead)) }
                        if (bytesRead <= 0) {
                            writeSuccess = false
                            break
                        }
                        let written = unsafe { write(fd, buf, UIntNative(bytesRead)) }
                        if (Int64(written) < 0) {
                            writeSuccess = false
                            break
                        }
                        remaining -= bytesRead
                    }
                }
                unsafe { close(fd) }

                if (writeSuccess) {
                    count += UInt32(1)
                } else {
                    // 删除失败的文件
                    let unlinkCStr = archiveNewCString(fullPath)
                    unsafe { unlink(CPointer<Int8>(CPointer<Unit>(unlinkCStr))) }
                    freeCString(unlinkCStr)
                }
            case FileKind.SymLink =>
                let linkTargetPtr = unsafe { archive_entry_symlink(entryPtr) }
                let linkTarget = cStringToString(linkTargetPtr)
                if (!isSafePath(linkTarget)) { continue }

                let linkCStr = archiveNewCString(fullPath)
                let targetCStr = archiveNewCString(linkTarget)
                let symlinkRc = unsafe { symlink(CPointer<Int8>(CPointer<Unit>(targetCStr)), CPointer<Int8>(CPointer<Unit>(linkCStr))) }
                freeCString(linkCStr)
                freeCString(targetCStr)

                if (symlinkRc == Int32(0)) {
                    count += UInt32(1)
                }
            case _ => ()
        }
    }

    unsafe {
        archive_read_close(archive)
        archive_read_free(archive)
    }

    count
}

/// 从 JS 对象构建 tarball
/// 对应 Bun Archive.zig buildTarballFromObject()
/// 使用 libarchive 的 archive_write API 创建 tarball
func buildTarballFromObject(global: JsGlobalObject, obj: JsValue): ?Array<UInt8> {
    if (!obj.isObject()) { return None }

    let jsObj = obj.toObject()
    if (jsObj.isNull()) { return None }

    // 使用 libarchive 的 archive_write API 创建 tarball
    let archive = unsafe { archive_write_new() }
    if (archive.isNull()) { return None }

    defer {
        unsafe {
            archive_write_close(archive)
            archive_write_free(archive)
        }
    }

    // 设置 tar 格式 (PAX restricted)
    unsafe { archive_write_set_format_pax_restricted(archive) }

    // 使用内存缓冲区写入
    let initialBufferSize = UInt64(65536)
    let memBuffer = unsafe { malloc(UIntNative(initialBufferSize)) }
    if (memBuffer.isNull()) { return None }

    var usedSize: UInt64 = UInt64(0)
    let usedPtr = unsafe { malloc(UIntNative(8)) }
    defer { freeCPtr(usedPtr) }
    unsafe { (CPointer<UInt64>(usedPtr)).write(UInt64(0)) }

    let openRc = unsafe {
        archive_write_open_memory(archive, memBuffer, initialBufferSize, CPointer<UInt64>(usedPtr))
    }
    if (openRc != ARCHIVE_OK) {
        freeCPtr(memBuffer)
        return None
    }

    // 创建 entry 模板
    let entry = unsafe { archive_entry_new() }
    defer { unsafe { archive_entry_free(entry) } }

    // 遍历对象属性
    let keys = jsObj.keys()
    for (key in keys) {
        let value = jsObj.get(key)
        if (value.isUndefinedOrNull()) { continue }

        // 获取属性值的数据
        var entryData: Array<UInt8> = Array<UInt8>()
        if (value.isObject()) {
            entryData = value.toByteArray()
        } else if (value.isString()) {
            let s = value.toSlice(global.globalThis)
            for (c in s) {
                entryData.append(UInt8(Int64(c) & 0xFF))
            }
        }

        // 设置 entry
        unsafe { archive_entry_clear(entry) }
        let keyCStr = archiveNewCString(key)
        unsafe { archive_entry_set_pathname(entry, keyCStr) }
        freeCString(keyCStr)

        unsafe { archive_entry_set_size(entry, Int64(entryData.size)) }
        unsafe { archive_entry_set_filetype(entry, ARCHIVE_ENTRY_FILETYPE_REGULAR) }
        unsafe { archive_entry_set_perm(entry, DEFAULT_FILE_PERM) }

        // 写入 header
        let headerRc = unsafe { archive_write_header(archive, entry) }
        if (headerRc != ARCHIVE_OK) { continue }

        // 写入数据
        if (entryData.size > 0) {
            let cEntryData = archiveBytesToCPtr(entryData)
            defer { freeCPtr(cEntryData) }
            unsafe { archive_write_data(archive, cEntryData, UInt64(entryData.size)) }
        }

        unsafe { archive_write_finish_entry(archive) }
    }

    unsafe { archive_write_close(archive) }

    // 从内存缓冲区读取数据
    let finalUsed = unsafe { (CPointer<UInt64>(usedPtr)).read() }
    var result = Array<UInt8>()
    for (i in 0..Int64(finalUsed)) {
        result.add(unsafe { (CPointer<UInt8>(memBuffer) + i).read() })
    }
    freeCPtr(memBuffer)

    result
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 从 libarchive filetype mode 判断文件类型
/// 对应 Bun bun.sys.kindFromMode()
func kindFromMode(mode: UInt32): FileKind {
    let fileType = mode & UInt32(0xF000)
    match (fileType) {
        case UInt32(0x8000) => FileKind.File       // S_IFREG / AE_IFREG
        case UInt32(0x4000) => FileKind.Directory   // S_IFDIR / AE_IFDIR
        case UInt32(0xA000) => FileKind.SymLink     // S_IFLNK / AE_IFLNK
        case _ => FileKind.Other
    }
}

/// 检查路径是否安全 (无绝对路径或路径遍历)
/// 对应 Bun Archive.zig isSafePath()
func isSafePath(pathname: String): Bool {
    if (pathname.size == 0) { return false }

    // 拒绝绝对路径
    if (pathname[Int64(0)] == UInt8(47) || pathname[Int64(0)] == UInt8(92)) { return false }

    // 检查 Windows 驱动器号 (如 "C:")
    if (pathname.size >= 2 && pathname[Int64(1)] == UInt8(58)) { return false }

    // 拒绝包含 ".." 组件的路径
    var i = Int64(0)
    while (i < pathname.size) {
        if (i + 1 < pathname.size && pathname[i] == UInt8(46) && pathname[i + 1] == UInt8(46)) {
            // 检查 ".." 是独立组件 (前后是 / 或边界)
            let prevOk = (i == 0) || (pathname[i - 1] == UInt8(47)) || (pathname[i - 1] == UInt8(92))
            let nextIdx = i + 2
            let nextOk = (nextIdx >= pathname.size) || (pathname[nextIdx] == UInt8(47)) || (pathname[nextIdx] == UInt8(92))
            if (prevOk && nextOk) { return false }
        }
        i += 1
    }

    true
}

/// 获取路径的父目录
func getParentDir(path: String): String {
    var lastSlash = Int64(-1)
    var i = Int64(0)
    while (i < path.size) {
        if (path[i] == UInt8(47)) { lastSlash = i }
        i += 1
    }
    if (lastSlash <= 0) { return "" }
    path[0..lastSlash]
}

/// 匹配 glob 模式 (简化实现)
/// 支持负模式 (以 "!" 开头)
/// 对应 Bun Archive.zig matchGlobPatterns()
func matchGlobPatterns(patterns: Array<String>, pathname: String): Bool {
    var hasPositivePatterns = false
    var matchesPositive = false

    for (pattern in patterns) {
        if (pattern.size > 0 && pattern[Int64(0)] == UInt8(33)) { // '!'
            // 负模式 — 匹配则排除
            if (pattern.size > 1) {
                let negPattern = pattern[1..]
                if (simpleGlobMatch(negPattern, pathname)) { return false }
            }
        } else {
            hasPositivePatterns = true
            if (simpleGlobMatch(pattern, pathname)) { matchesPositive = true }
        }
    }

    !hasPositivePatterns || matchesPositive
}

/// 简单 glob 匹配 (支持 * 通配符)
func simpleGlobMatch(pattern: String, text: String): Bool {
    if (pattern == "*" || pattern == "**") { return true }
    if (pattern == text) { return true }

    // 简单前缀/后缀匹配
    if (pattern.size > 0 && pattern[Int64(0)] == UInt8(42)) { // starts with *
        let suffix = pattern[1..]
        if (text.size >= suffix.size) {
            let textSuffix = text[(text.size - suffix.size)..]
            return textSuffix == suffix
        }
    }
    if (pattern.size > 0 && pattern[Int64(pattern.size - 1)] == UInt8(42)) { // ends with *
        let prefix = pattern[0..(pattern.size - 1)]
        if (text.size >= prefix.size) {
            let textPrefix = text[0..prefix.size]
            return textPrefix == prefix
        }
    }

    false
}

// ============================================================================
// 公共 API 函数
// ============================================================================

/// 解析压缩选项
public func parseCompressionOptions(global!: JsGlobalObject, optionsArg!: JsValue): Compression {
    if (optionsArg.isUndefinedOrNull()) {
        return Compression.compressionNone
    }
    if (optionsArg.isObject()) {
        let jsObj: JsObject = global.globalThis
        if (let Some(compressVal) <- optionsArg.getTruthy(jsObj, "compress")) {
            if (compressVal.isString()) {
                let s = compressVal.toSlice(global.globalThis)
                if (s == "gzip") { return Compression.gzip }
                if (s == "brotli") { return Compression.brotli }
                if (s == "zstd") { return Compression.zstd }
            }
        }
    }
    Compression.compressionNone
}

/// createArchive - 从数据创建归档
public func createArchive(data!: Array<UInt8>, compress!: Compression): Archive {
    let store = BlobStore(data)
    Archive(store, compress)
}

/// buildTarballFromObject - 从对象构建 tarball (公共接口)
public func buildTarballFromObject(global!: JsGlobalObject, obj!: JsValue): Array<UInt8> {
    match (buildTarballFromObject(global, obj)) {
        case Some(bytes) => bytes
        case None => Array<UInt8>()
    }
}

/// parsePatternArg - 解析 glob 模式参数
/// 对应 Bun Archive.zig parsePatternArg()
public func parsePatternArg(global: JsGlobalObject, arg: JsValue, apiName: String, name: String): ?Array<String> {
    // 单个字符串
    if (arg.isString()) {
        let s = arg.toSlice(global.globalThis)
        if (s.size == 0) { return None }
        return Some([s])
    }

    // 字符串数组
    if (arg.isObject()) {
        let obj = arg.toObject()
        if (obj.has("length")) {
            let len = obj.get("length").toNumber()
            if (len <= 0) { return None }
            var patterns = Array<String>()
            for (i in 0..Int64(len)) {
                let item = obj.get(Int64(i))
                if (item.isString()) {
                    let s = item.toSlice(global.globalThis)
                    if (s.size > 0) {
                        patterns.append(s)
                    }
                }
            }
            if (patterns.size == 0) { return None }
            return Some(patterns)
        }
    }

    None
}

/// startExtractTask - 启动异步提取任务
public func startExtractTask(global!: JsGlobalObject, store!: BlobStore, path!: Array<UInt8>, globPatterns!: ?Array<String>): JsValue {
    let pathStr = String(path)
    let data = store.sharedView()
    let result = extractToDisk(data, pathStr, globPatterns)
    match (result) {
        case Some(count) => JsValue.jsNumber(Int64(count))
        case None => global.throwError("Archive.extract: failed to extract archive")
    }
}

/// startBlobTask - 启动异步 blob 任务
public func startBlobTask(global: JsGlobalObject, store: BlobStore, compress: Compression, outputType: BlobOutputType): JsValue {
    let data = store.sharedView()
    match (outputType) {
        case BlobOutputType.blob =>
            let blobObj = JsObject()
            blobObj.className = "Blob"
            blobObj.set("size", JsValue(Float64(data.size)))
            blobObj.set("type", JsValue("application/octet-stream"))
            JsValue(blobObj)
        case BlobOutputType.bytes =>
            JsValue.createBuffer(global.globalThis, data)
    }
}

/// startFilesTask - 启动异步 files 任务
public func startFilesTask(global: JsGlobalObject, store: BlobStore, globPatterns: ?Array<String>): JsValue {
    let data = store.sharedView()
    let entries = readArchiveFiles(data, globPatterns)
    match (entries) {
        case None => global.throwError("Archive.files: failed to read archive")
        case Some(fileList) =>
            let mapObj = JsObject()
            mapObj.className = "Map"
            for (entry in fileList) {
                let fileObj = JsObject()
                fileObj.className = "File"
                fileObj.set("name", JsValue(entry.pathname))
                fileObj.set("size", JsValue(Float64(entry.data.size)))
                fileObj.set("lastModified", JsValue(Float64(entry.mtime * 1000)))
                mapObj.set(entry.pathname, JsValue(fileObj))
            }
            JsValue(mapObj)
    }
}

/// archiveWrite - 写入归档
public func archiveWrite(global: JsGlobalObject, callframe: JsCallFrame): JsValue {
    Archive.write(global, callframe)
}

/// countFilesInArchive - 计算归档中的文件数
public func countFilesInArchive(data: Array<UInt8>): Int64 {
    Int64(countFilesInArchiveImpl(data))
}

/// fmtSize - 格式化文件大小
public func fmtSize(size: Int64): String {
    if (size < 1024) { return "${size} bytes" }
    if (size < 1048576) { return "${size / 1024}.${(size % 1024) * 10 / 1024} KB" }
    if (size < 1073741824) { return "${size / 1048576}.${(size % 1048576) * 10 / 1048576} MB" }
    "${size / 1073741824}.${(size % 1073741824) * 10 / 1073741824} GB"
}

/// ConsoleFormatter stub
public class ConsoleFormatter {
    public init() {}
    public func indented(): ConsoleFormatter { this }
    public func writeIndent(writer: Any): Unit {}
    public func printAs(writer: Any, value: Any, jsType: Any, ansi: Bool): Unit {}
    public func resetLine(): Unit {}
}
