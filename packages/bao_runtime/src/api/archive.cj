// 严格翻译自: src/runtime/api/Archive.rs (1614行)
// Bun.Archive — tar/tgz pack + extract over libarchive.
package bao_runtime.api

import bao_jsc.*
import bao_collections.ArrayList
import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_libarchive.*
import bao_glob.*
// Local StringBuilder wrapper to avoid ambiguity
public class ArchiveStringBuilder {
    private var content: String = ""
    public func append(s: String): Unit { content = content + s }
    public func toString(): String { content }
}

// Local Result wrapper to avoid ambiguity between bao_core.Result<T,E> and bao_jsc.Result<T>
public enum ArchiveResult2<T, E> {
    | ok(T)
    | err(E)
}

// JsCallFrame stub — JSC 调用帧 (桩声明)
public class JsCallFrame {
    public init() {}
    public func argument(index: Int32): JsValue { JsValue.jsUndefined() }
    public func argumentsAsArray2(): (JsValue, JsValue) { (JsValue.jsUndefined(), JsValue.jsUndefined()) }
    public func argumentsAsArray3(): (JsValue, JsValue, JsValue) { (JsValue.jsUndefined(), JsValue.jsUndefined(), JsValue.jsUndefined()) }
}

// ============================================================================
// 常量
// ============================================================================

/// libarchive AE_IFREG (== S_IFREG). 常规文件类型标识
/// 对应 Bun: FILETYPE_REGULAR
public const FILETYPE_REGULAR: UInt32 = 0o100000

// ============================================================================
// Compression - 压缩选项
// 对应 Bun: Compression enum
// ============================================================================

/// 压缩选项
public enum Compression {
    | none
    | gzip(GzipOptions)

    /// 默认值
    public static func defaults(): Compression {
        Compression.none
    }
}

/// Gzip 压缩选项
/// 对应 Bun: GzipOptions
public class GzipOptions {
    /// 压缩级别: 1 (最快) 到 12 (最大压缩)。默认是 6。
    public var level: UInt8 = 6

    public init() {}

    public init(level: UInt8) {
        this.level = level
    }
}

// ============================================================================
// Archive - 归档文件类
// 对应 Bun: Archive struct
// ============================================================================

/// Archive 类 — 用于创建和提取归档文件
/// 使用 Blob.Store 实现线程安全的引用计数
public class Archive {
    /// 底层数据存储 — 使用 BlobStore 进行线程安全引用计数
    public var store: BlobStore
    /// 压缩设置
    public var compress: Compression = Compression.none

    public init() {
        store = BlobStore()
    }

    public init(store: BlobStore, compress: Compression) {
        this.store = store
        this.compress = compress
    }

    /// 借用 store 引用
    /// 对应 Bun: Archive::store_ref()
    public func storeRef(): BlobStore {
        store
    }

    // ========================================================================
    // 构造函数: new Archive(data, options?)
    // 对应 Bun: Archive::constructor()
    // ========================================================================

    /// 构造函数 - 从 JS 参数创建 Archive
    /// 可以从以下创建:
    /// - 对象 { [path: string]: Blob | string | ArrayBufferView | ArrayBufferLike }
    /// - Blob, ArrayBufferView, 或 ArrayBufferLike (假设是有效的归档)
    /// 选项:
    /// - compress: "gzip" - 启用 gzip 压缩
    /// - level: number (1-12) - 压缩级别 (默认 6)
    /// 未提供选项时不应用压缩
    public static func constructor(globalThis!: JsGlobalObject, callframe!: JsCallFrame): Archive {
        let (dataArg, optionsArg) = callframe.argumentsAsArray2()
        if (dataArg == JsValue.jsUndefined()) {
            globalThis.throwInvalidArguments("new Archive() requires an argument")
            return Archive()
        }

        // 解析压缩选项
        let compress = parseCompressionOptions(globalThis, optionsArg) 

        // 对于 Blob/Archive, 引用现有 store (零拷贝)
        if (let blobPtr <- dataArg.asBlob()) {
            if (let blobStore <- blobPtr.store) {
                blobStore.ref()
                return Archive(store: blobStore, compress: compress)
            }
        }

        // 对于 ArrayBuffer/TypedArray, 复制数据
        if (let arrayBuffer <- dataArg.asArrayBuffer(globalThis)) {
            let data = default_allocator.dupe(arrayBuffer.slice())
            return createArchive(data, compress)
        }

        // 对于普通对象, 构建 tarball
        if (dataArg.isObject()) {
            let data = buildTarballFromObject(globalThis, dataArg) 
            return createArchive(data, compress)
        }

        globalThis.throwInvalidArguments("Expected an object, Blob, TypedArray, or ArrayBuffer")
        return Archive()
    }

    // ========================================================================
    // 实例方法
    // ========================================================================

    /// extract - 提取归档到磁盘
    /// 对应 Bun: Archive::extract()
    /// 选项:
    ///   - glob: string | string[] - 只提取匹配 glob 模式的文件。支持 "!" 前缀的否定模式
    /// 返回 Promise<number> (提取的文件数)
    public func extract(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let (pathArg, optionsArg) = callframe.argumentsAsArray2()
        if (pathArg == JsValue.jsUndefined() || !pathArg.isString()) {
            globalThis.throwInvalidArguments("Archive.extract requires a path argument")
            return JsValue.jsUndefined()
        }

        let pathSlice = pathArg.toSlice(globalThis, default_allocator) 
        // 解析选项 (glob 过滤)
        var globPatterns: ?Array<String> = None

        if (!optionsArg.isUndefinedOrNull()) {
            if (!optionsArg.isObject()) {
                globalThis.throwInvalidArguments("Archive.extract: second argument must be an options object")
                return JsValue.jsUndefined()
            

            if (let globVal <- optionsArg.getTruthy(globalThis, "glob") ) {
                globPatterns = parsePatternArg(globalThis, globVal, "Archive.extract", "glob") 
            }
        }

        // 启动异步提取任务
        pathSlice.deinit()
        }
        return startExtractTask(globalThis, store, pathSlice.slice(), globPatterns)
    }

    /// blob - 返回归档数据的 Blob
    /// 对应 Bun: Archive::blob()
    /// 返回 Promise<Blob> (如果 gzip 则压缩后)
    public func blob(globalThis!: JsGlobalObject, frame!: JsCallFrame): JsValue {
        return startBlobTask(globalThis, store, compress, BlobOutputType.blob)
    }

    /// bytes - 返回归档数据的 Uint8Array
    /// 对应 Bun: Archive::bytes()
    /// 返回 Promise<Uint8Array> (如果 gzip 则压缩后)
    public func bytes(globalThis!: JsGlobalObject, frame!: JsCallFrame): JsValue {
        return startBlobTask(globalThis, store, compress, BlobOutputType.bytes)
    }

    /// files - 返回归档文件内容的 Map
    /// 对应 Bun: Archive::files()
    /// 返回 Promise<Map<string, File>>
    public func files(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let globArg = callframe.argument(0)

        var globPatterns: ?Array<String> = None
        if (!globArg.isUndefinedOrNull()) {
            globPatterns = parsePatternArg(globalThis, globArg, "Archive.files", "glob") 
        }

        return startFilesTask(globalThis, store, globPatterns)
    }

    /// write - 静态方法, 写入归档到磁盘
    /// 对应 Bun: Archive::write() (module-level write)
    /// Archive 实例使用归档的压缩设置，除非被选项覆盖
    public static func write(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return archiveWrite(globalThis, callframe)
    }

    /// Finalize - GC 回收时调用
    /// 对应 Bun: Archive::finalize()
    public func finalize(): Unit {
        store.deref()
    }

    /// Pretty-print for console.log
    /// 对应 Bun: Archive::write_format()
    public func writeFormat(formatter!: ConsoleFormatter, writer!: ArchiveStringBuilder, enableAnsiColors!: Bool): Unit {
        let data = store.sharedView()
        writer.append("Archive (")
        writer.append(fmtSize(data.size))
        writer.append(") {\n")

        var indented = formatter.indented()
        indented.writeIndent(writer)
        writer.append("<r>files<d>:<r> ")
        formatter.printAs(writer, JsValue.jsNumber(Float64(countFilesInArchive(data))), JSType.numberObject, enableAnsiColors)
        writer.append("\n")
        formatter.writeIndent(writer)
        writer.append("}")
        formatter.resetLine()
    }

    /// 从 JS 值获取 Archive 实例
    /// 对应 Bun: Archive::fromJS()
    public static func fromJS(value!: JsValue): ?Archive {
        return value.asClassRef<Archive>()
    }
}

// ============================================================================
// 压缩选项解析
// 对应 Bun: parse_compression_options()
// ============================================================================

/// 解析压缩选项
/// 无选项时返回 .none, 调用者需处理默认值
public func parseCompressionOptions(global!: JsGlobalObject, optionsArg!: JsValue): Compression {
    if (optionsArg.isUndefinedOrNull()) {
        return Compression.none
    }

    if (!optionsArg.isObject()) {
        global.throwInvalidArguments("Archive: options must be an object")
        return Compression.none
    }

    // 检查 compress 选项
    if (let compressVal <- optionsArg.getTruthy(global, "compress") ) {
        if (!compressVal.isString()) {
            global.throwInvalidArguments("Archive: compress option must be a string")
            return Compression.none
        }

        let compressStr = compressVal.toSlice(global, default_allocator) 
        if (compressStr.slice() != "gzip") {
            global.throwInvalidArguments("Archive: compress option must be \"gzip\"")
            return Compression.none
        

        // 解析 level 选项 (1-12, 默认 6)
        var level: UInt8 = 6
        if (let levelVal <- optionsArg.getTruthy(global, "level") ) {
            if (!levelVal.isNumber()) {
                global.throwInvalidArguments("Archive: level must be a number")
                return Compression.none
            }
            let levelNum = levelVal.toInt64()
            if (levelNum < 1 || levelNum > 12) {
                global.throwInvalidArguments("Archive: level must be between 1 and 12")
                return Compression.none
            }
            level = UInt8(levelNum)
        }

        compressStr.deinit()
        }
        return Compression.gzip(GzipOptions(level: level))
    }

    return Compression.none
}

/// 创建 Archive 实例
/// 对应 Bun: create_archive()
public func createArchive(data!: Array<UInt8>, compress!: Compression): Archive {
    let store = BlobStore(data, default_allocator)
    return Archive(store: store, compress: compress)
}

// ============================================================================
// Archive 读取配置
// 对应 Bun: configure_archive_reader()
// ============================================================================

/// 配置归档读取器以支持 tar/tar.gz
public func configureArchiveReader(archive!: LibArchive): Unit {
    archive.readSupportFormatTar()
    archive.readSupportFormatGnuTar()
    archive.readSupportFilterGzip()
    archive.readSetOptions("read_concatenated_archives")
}

// ============================================================================
// 文件计数
// 对应 Bun: count_files_in_archive()
// ============================================================================

/// 计算归档中的文件数量
public func countFilesInArchive(data!: Array<UInt8>): UInt32 {
    let archive = LibArchive.readArchiveNew()
    configureArchiveReader(archive)

    if (archive.readOpenMemory(data) != ArchiveResult.ok) {
        return 0
    }

    var count: UInt32 = 0
    var entry: LibArchiveEntry = LibArchiveEntry()
    while (archive.readNextHeader(entry) == ArchiveResult.ok) {
        if (entry.filetype() == FILETYPE_REGULAR) {
            count += 1
        }
    }

    return count
}

// ============================================================================
// tarball 构建
// 对应 Bun: build_tarball_from_object()
// ============================================================================

/// 从 JS 对象构建 tarball 字节
/// 共享辅助函数，遍历对象属性并写入归档
public func buildTarballFromObject(global!: JsGlobalObject, obj!: JsValue): Array<UInt8> {
    let jsObj = obj.getObject()
    if (jsObj == none) {
        global.throwInvalidArguments("Expected an object")
        return []
    }

    // 设置归档
    var growingBuffer = GrowingBuffer()

    let archive = LibArchive.writeArchiveNew()
    let archiveRef = archive.asRef()

    if (archiveRef.writeSetFormatPaxRestricted() != ArchiveResult.ok) {
        global.throwInvalidArguments("Failed to create tarball: ArchiveFormatError")
        return []
    }

    if (LibArchive.archiveWriteOpen2(
        archive.asPtr(),
        growingBuffer.asPtr(),
        GrowingBuffer.openCallback,
        GrowingBuffer.writeCallback,
        GrowingBuffer.closeCallback,
        null,
    ) != 0) {
        global.throwInvalidArguments("Failed to create tarball: ArchiveOpenError")
        return []
    }

    let entry = LibArchive.ownedEntryNew()
    let entryRef = entry.asRef()

    let nowSecs: Int64 = Int64(timeMilliTimestamp() / 1000)

    // 遍历对象属性并直接写入归档
    var iter = try { JSPropertyIterator(global, jsObj, PropertyIteratorOptions(
        true, true
    )) } catch(_: Exception) {
        return []
    }

    while (let key <- iter.next()) {
        let value = iter.value
        if (value == JsValue.jsUndefined()) {
            continue
        }

        // 获取键名为 null 终止字符串
        let keySlice = key.toUTF8()
        let keyStr = keySlice.slice()

        // 获取数据 — 对 Blob/ArrayBuffer 使用视图, 对字符串进行转换
                let dataSliceOpt = getEntryData(global, value)
        if (dataSliceOpt.isNone()) {
            continue
        }
        let dataSlice = dataSliceOpt.get()

        // 写入条目到归档
        let data = dataSlice.slice()
        entryRef.clear()
        entryRef.setPathnameUTF8(keyStr)
        entryRef.setSize(Int64(data.size))
        entryRef.setFiletype(FILETYPE_REGULAR)
        entryRef.setPerm(0o644)
        entryRef.setMTime(nowSecs, 0)

        if (archiveRef.writeHeader(entryRef) != ArchiveResult.ok) {
            global.throwInvalidArguments("Failed to create tarball: ArchiveHeaderError")
            return []
        }
        if (archiveRef.writeData(data) < 0) {
            global.throwInvalidArguments("Failed to create tarball: ArchiveWriteError")
            return []
        }
        if (archiveRef.writeFinishEntry() != ArchiveResult.ok) {
            global.throwInvalidArguments("Failed to create tarball: ArchiveFinishEntryError")
            return []
        }
    }

    if (archiveRef.writeClose() != ArchiveResult.ok) {
        global.throwInvalidArguments("Failed to create tarball: ArchiveCloseError")
        return []
    }

    return growingBuffer.toOwnedSlice() ?? []
}

/// 获取条目数据作为切片
/// 对应 Bun: get_entry_data()
/// 对于 Blob 使用 sharedView (无需拷贝)
/// 对于 ArrayBuffer/TypedArray 使用视图 (无需拷贝)
/// 对于字符串进行转换 (分配内存)
public func getEntryData(global!: JsGlobalObject, value!: JsValue): ?Array<UInt8> {
    // 对于 Blob, 使用 sharedView (无需拷贝)
    if (let blob <- value.asBlob()) {
        return blob.sharedView()
    }

    // 对于 ArrayBuffer/TypedArray, 使用视图 (无需拷贝)
    if (let arrayBuffer <- value.asArrayBuffer(global)) {
        return arrayBuffer.slice()
    }

    // 对于字符串，进行转换
    if (value.isString()) {
        return value.toSlice(global, default_allocator) .slice()
    }

    return None
}

// ============================================================================
// 模式参数解析
// 对应 Bun: parse_pattern_arg()
// ============================================================================

/// 解析字符串或字符串数组为模式列表
/// 空字符串或空数组返回 null（视为"无过滤"）
public func parsePatternArg(global!: JsGlobalObject, arg!: JsValue, apiName!: String, name!: String): ?Array<String> {
    // 单个字符串
    if (arg.isString()) {
        let strSlice = arg.toSlice(global, default_allocator) 
        if (strSlice.len == 0) {
            strSlice.deinit()
            return None
        }
        let result = [strSlice.slice()]
        strSlice.deinit()
        return result
    }

    // 字符串数组
    if (arg.jsType() == JSType.array) {
        let len = arg.getLength(global) 
        if (len == 0) {
            return None
        }

        var patterns = ArrayList<String>()
        var i: UInt32 = 0
        while (i < len) {
            let item = arg.getIndex(global, i) 
            if (!item.isString()) {
                global.throwInvalidArguments("${apiName}: ${name} array must contain only strings")
                return None
            }
            let strSlice = item.toSlice(global, default_allocator)
            if (strSlice.len == 0) {
                strSlice.deinit()
                i += 1
                continue
            }
            patterns.append(strSlice.slice())
            i += 1
            strSlice.deinit()
        }

        if (patterns.isEmpty()) {
            return None
        }
        return patterns.toArray()
    }

    global.throwInvalidArguments("${apiName}: ${name} must be a string or array of strings")
    return None
}

// ============================================================================
// 静态写入方法
// 对应 Bun: write() (module-level)
// ============================================================================

/// Archive.write(path, data, options?) 静态方法
/// 一步完成归档创建和写入磁盘
/// 对应 Bun: write()
/// 对于 Archive 实例，使用归档的压缩设置，除非被选项覆盖
/// 选项:
///   - gzip: { level?: number } - 覆盖压缩设置
public func archiveWrite(global!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
    let (pathArg, dataArg, optionsArg) = callframe.argumentsAsArray3()
    if (dataArg == JsValue.jsUndefined()) {
        global.throwInvalidArguments("Archive.write requires 2 arguments (path, data)")
        return JsValue.jsUndefined()
    }

    // 获取路径
    if (!pathArg.isString()) {
        global.throwInvalidArguments("Archive.write: first argument must be a string path")
        return JsValue.jsUndefined()
    }

    let pathSlice = pathArg.toSlice(global, default_allocator) 
    // 解析压缩覆盖选项
    let optionsCompress = parseCompressionOptions(global, optionsArg) 

    // 对于 Archive 实例，使用选项覆盖或归档的压缩设置
    if (let archive <- Archive.fromJS(dataArg)) {
        let compress = if (optionsCompress != Compression.none) {
            optionsCompress
        } else {
            archive.compress
        }
        return startWriteTask(global, WriteContextData.store(archive.store), pathSlice.slice(), compress)
    }

    // 对于 Blob, 使用 store 引用和选项压缩
    if (let blobPtr <- dataArg.asBlob()) {
        if (let blobStore <- blobPtr.store) {
            return startWriteTask(global, WriteContextData.store(blobStore), pathSlice.slice(), optionsCompress)
        }
    }

    // 对于 ArrayBuffer/TypedArray, 复制数据
    if (let arrayBuffer <- dataArg.asArrayBuffer(global)) {
        let data = default_allocator.dupe(arrayBuffer.slice())
        return startWriteTask(global, WriteContextData.owned(data), pathSlice.slice(), optionsCompress)
    }

    // 对于普通对象, 构建 tarball
    if (dataArg.isObject()) {
        let data = buildTarballFromObject(global, dataArg) 
        return startWriteTask(global, WriteContextData.owned(data), pathSlice.slice(), optionsCompress)
    }

    global.throwInvalidArguments("Expected an object, Blob, TypedArray, ArrayBuffer, or Archive")
    pathSlice.deinit()
    return JsValue.jsUndefined()
}

// ============================================================================
// 通用异步任务基础设施
// 对应 Bun: PromiseResult, TaskContext, AsyncTask
// ============================================================================

/// Promise 结果
/// 对应 Bun: PromiseResult
public enum PromiseResult {
    | resolve(JsValue)
    | reject(JsValue)

    /// 履行 Promise
    /// 对应 Bun: PromiseResult::fulfill()
    public func fulfill(global!: JsGlobalObject, promise!: JsPromise): Unit {
        match (this) {
            case resolve(v) => promise.resolve(global, v)
            case reject(v) => promise.rejectWithAsyncStack(global, v)
        }
    }
}

/// 异步任务上下文特征
/// 对应 Bun: TaskContext trait
/// 从 Zig 的结构化鸭子类型提取
/// Context 必须提供:
///   - run — 在线程池上运行，将结果存储在 self 中
///   - runFromJS — 返回要 resolve/reject 的值
///   - Drop — 清理
public interface TaskContext {
    /// 在线程池上运行。将结果存储在 self 中。
    func run(): Unit

    /// 在 JS 线程上运行，返回 Promise 结果
    func runFromJS(global!: JsGlobalObject): PromiseResult
}

// ============================================================================
// Blob 输出类型
// 对应 Bun: BlobOutputType
// ========================================================================

public enum BlobOutputType {
    | blob
    | bytes
}

// ============================================================================
// 写入上下文数据
// 对应 Bun: WriteData
// ============================================================================

/// 写入任务的数据来源
public enum WriteContextData {
    | owned(Array<UInt8>)
    | store(BlobStore)
}

// ============================================================================
// 提取任务
// 对应 Bun: ExtractContext, ExtractResult, ExtractTask
// ============================================================================

/// 提取错误
/// 对应 Bun: ExtractError
public enum ExtractError {
    | readError
}

/// 提取结果
/// 对应 Bun: ExtractResult
public enum ExtractResult {
    | success(UInt32)
    | err(ExtractError)
}

/// 提取任务上下文
/// 对应 Bun: ExtractContext
public class ExtractContext {
    public var store: BlobStore
    public var path: Array<UInt8>
    public var globPatterns: ?Array<String>
    public var result: ExtractResult

    public init(store: BlobStore, path: Array<UInt8>, globPatterns: ?Array<String>) {
        this.store = store
        this.path = path
        this.globPatterns = globPatterns
        this.result = ExtractArchiveResult2.err(ExtractError.readError)
    }

    /// 在线程池上运行提取
    /// 对应 Bun: ExtractContext::do_run()
    public func doRun(): ExtractResult {
        // 如果有 glob 模式，使用过滤提取
        if (globPatterns.isSome()) {
            let count = extractToDiskFiltered(store.sharedView(), path, globPatterns)
            if (let Some(c) <- count) {
                return ExtractResult.success(c)
            } else {
                return ExtractArchiveResult2.err(ExtractError.readError)
            }
        }

        // 否则使用不带过滤的快速路径
        let count = Archiver.extractToDisk(
            store.sharedView(),
            path,
            None,
            ExtractOptions.defaults(),
        )
        if (let Some(c) <- count) {
            return ExtractResult.success(c)
        } else {
            return ExtractArchiveResult2.err(ExtractError.readError)
        }
    }
}

/// 启动异步提取任务
/// 对应 Bun: start_extract_task()
public func startExtractTask(global!: JsGlobalObject, store!: BlobStore, path!: Array<UInt8>,
                              globPatterns!: ?Array<String>): JsValue {
    let pathCopy = default_allocator.dupe(path)
    store.ref()

    let taskOpt = ExtractTask.create(global, ExtractContext(store, pathCopy, globPatterns))
    if (taskOpt.isNone()) {
        return JsValue.jsUndefined()
    }
    let task = taskOpt.getOrThrow()

    let promiseJs = task.promiseValue()
    task.schedule()
    return promiseJs
}

// ============================================================================
// Blob 任务
// 对应 Bun: BlobContext, BlobResult, BlobTask
// ============================================================================

/// Blob 错误
/// 对应 Bun: BlobError
public enum BlobError {
    | outOfMemory
    | gzipInitFailed
    | gzipCompressFailed
}

/// Blob 结果
/// 对应 Bun: BlobResult
public enum BlobResult {
    | compressed(Array<UInt8>)
    | uncompressed
    | err(BlobError)
}

/// Blob 任务上下文
/// 对应 Bun: BlobContext
public class BlobContext {
    public var store: BlobStore
    public var compress: Compression
    public var outputType: BlobOutputType
    public var result: BlobResult

    public init(store: BlobStore, compress: Compression, outputType: BlobOutputType) {
        this.store = store
        this.compress = compress
        this.outputType = outputType
        this.result = BlobResult.uncompressed
    }

    /// 在线程池上运行
    /// 对应 Bun: BlobContext::run()
    public func doRun(): Unit {
        match (compress) {
            case Compression.gzip(opts) =>
                if (let Some(data) <- compressGzip(store.sharedView(), opts.level)) {
                    result = BlobResult.compressed(data)
                } else {
                    result = BlobArchiveResult2.err(BlobError.gzipCompressFailed)
                }
            case Compression.none => result = BlobResult.uncompressed
            case _ => result = BlobResult.uncompressed
        }
    }

    /// 在 JS 线程上处理结果
    /// 对应 Bun: BlobContext::run_from_js()
    public func runFromJS(global!: JsGlobalObject): PromiseResult {
        match (result) {
            case BlobArchiveResult2.err(e) =>
                return PromiseResult.reject(global.createErrorInstance(blobErrorToString(e)))
            case BlobResult.compressed(data) =>
                match (outputType) {
                    case BlobOutputType.blob =>
                        let blobPtr = Blob.new(Blob.createWithBytesAndAllocator(data, global, false))
                        return PromiseResult.resolve(blobPtr.toJS(global))
                    case BlobOutputType.bytes =>
                        // 所有权转移到 JSC 的 MarkedArrayBuffer_deallocator
                        return PromiseResult.resolve(JsValue.createBufferFromBox(global, data))
                }
            case BlobResult.uncompressed =>
                match (outputType) {
                    case BlobOutputType.blob =>
                        // store.ref() — clone 增加引用计数
                        let storeRef = store.clone()
                        let blobPtr = Blob.new(Blob.initWithStore(storeRef, global))
                        return PromiseResult.resolve(blobPtr.toJS(global))
                    case BlobOutputType.bytes =>
                        let dup = store.sharedView()
                        return PromiseResult.resolve(JsValue.createBufferFromBox(global, dup))
                }
        }
    }
}

/// 启动 Blob 获取任务
/// 对应 Bun: start_blob_task()
public func startBlobTask(global!: JsGlobalObject, store!: BlobStore, compress!: Compression,
                           outputType!: BlobOutputType): JsValue {
    store.ref()

    let taskOpt = BlobTask.create(global, BlobContext(
        store: store,
        compress: compress,
        outputType: outputType,
    ))
    if (taskOpt.isNone()) {
        return JsValue.jsUndefined()
    }
    let task = taskOpt.getOrThrow()

    let promiseJs = task.promiseValue()
    task.schedule()
    return promiseJs
}

/// BlobError 转字符串
public func blobErrorToString(e!: BlobError): String {
    match (e) {
        case outOfMemory => "OutOfMemory"
        case gzipInitFailed => "GzipInitFailed"
        case gzipCompressFailed => "GzipCompressFailed"
    }
}

// ============================================================================
// 写入任务
// 对应 Bun: WriteContext, WriteResult, WriteTask
// ============================================================================

/// 写入错误
/// 对应 Bun: WriteError
public enum WriteError {
    | outOfMemory
    | gzipInitFailed
    | gzipCompressFailed
}

/// 写入结果
/// 对应 Bun: WriteResult
public enum WriteResult {
    | success
    | err(WriteError)
    | sysErr(SysError)
}

/// 写入任务上下文
/// 对应 Bun: WriteContext
public class WriteContext {
    public var data: WriteContextData
    public var path: Array<UInt8>
    public var compress: Compression
    public var result: WriteResult

    public init(data: WriteContextData, path: Array<UInt8>, compress: Compression) {
        this.data = data
        this.path = path
        this.compress = compress
        this.result = WriteResult.success
    }

    /// 在线程池上运行写入
    /// 对应 Bun: WriteContext::do_run()
    public func doRun(): WriteResult {
        // 获取源数据
        let sourceData: Array<UInt8> = match (data) {
            case WriteContextData.owned(d) => d
            case WriteContextData.store(s) => s.sharedView()
        }

        var dataToWrite: Array<UInt8> = sourceData
        match (compress) {
            case Compression.gzip(opts) =>
                if (let Some(compressed) <- compressGzip(sourceData, opts.level)) {
                    dataToWrite = compressed
                } else {
                    return WriteArchiveResult2.err(WriteError.gzipCompressFailed)
                }
            case _ => ()
        }

        // 打开文件并写入
        let file = SysFile.openat(
            Fd.cwd(),
            path,
            SysOpenFlags.CREAT | SysOpenFlags.WRONLY | SysOpenFlags.TRUNC,
            0o644,
        )

        match (file) {
            case err(e) => return WriteResult.sysErr(e)
            case ok(f) =>
                let res = match (f.writeAll(dataToWrite)) {
                    case ok(_) => WriteResult.success
                    case err(e) => WriteResult.sysErr(e)
                }
                f.close()
                return res
        }
    }

    /// 在 JS 线程上处理结果
    /// 对应 Bun: WriteContext::run_from_js()
    public func runFromJS(global!: JsGlobalObject): PromiseResult {
        match (result) {
            case WriteResult.success => PromiseResult.resolve(JsValue.jsUndefined())
            case WriteArchiveResult2.err(e) =>
                PromiseResult.reject(global.createErrorInstance(writeErrorToString(e)))
            case WriteResult.sysErr(sysErr) =>
                PromiseResult.reject(sysErr.toJS(global))
        }
    }
}

/// 启动写入任务
/// 对应 Bun: start_write_task()
public func startWriteTask(global!: JsGlobalObject, data!: WriteContextData, path!: Array<UInt8>,
                            compress!: Compression): JsValue {
    let pathZ = default_allocator.dupeZ(path)

    // 如果使用 store 引用，增加引用计数
    match (data) {
        case WriteContextData.store(s) => s.ref()
        case _ => ()
    }

    let taskOpt = WriteTask.create(global, WriteContext(data, pathZ, compress))
    if (taskOpt.isNone()) {
        return JsValue.jsUndefined()
    }
    let task = taskOpt.getOrThrow()

    let promiseJs = task.promiseValue()
    task.schedule()
    return promiseJs
}

/// WriteError 转字符串
public func writeErrorToString(e!: WriteError): String {
    match (e) {
        case outOfMemory => "OutOfMemory"
        case gzipInitFailed => "GzipInitFailed"
        case gzipCompressFailed => "GzipCompressFailed"
    }
}

// ============================================================================
// 文件列表任务
// 对应 Bun: FileEntry, FilesContext, FilesTask
// ============================================================================

/// 文件条目
/// 对应 Bun: FileEntry
public class FileEntry {
    public var path: Array<UInt8>
    public var data: Array<UInt8>
    public var mtime: Int64

    public init(path: Array<UInt8>, data: Array<UInt8>, mtime: Int64) {
        this.path = path
        this.data = data
        this.mtime = mtime
    }
}

/// 文件列表错误
/// 对应 Bun: FilesError
public enum FilesError {
    | outOfMemory
    | readError
}

/// 文件列表结果
/// 对应 Bun: FilesResult
public enum FilesResult {
    | success(ArrayList<FileEntry>)
    | libarchiveErr(String)
    | err(FilesError)
}

/// 文件列表任务上下文
/// 对应 Bun: FilesContext
public class FilesContext {
    public var store: BlobStore
    public var globPatterns: ?Array<String>
    public var result: FilesResult

    public init(store: BlobStore, globPatterns: ?Array<String>) {
        this.store = store
        this.globPatterns = globPatterns
        this.result = FilesArchiveResult2.err(FilesError.readError)
    }

    /// 克隆归档错误字符串
    /// 对应 Bun: FilesContext::clone_error_string()
    public static func cloneErrorString(archive!: LibArchive): ?String {
        let errStr = archive.errorString()
        if (errStr.isEmpty()) {
            return None
        }
        return errStr
    }

    /// 在线程池上运行文件提取
    /// 对应 Bun: FilesContext::do_run()
    public func doRun(): FilesResult {
        let archive = LibArchive.readArchiveNew()
        configureArchiveReader(archive)

        if (archive.readOpenMemory(store.sharedView()) != ArchiveResult.ok) {
            if (let err <- cloneErrorString(archive)) {
                return FilesResult.libarchiveErr(err)
            }
            return FilesArchiveResult2.err(FilesError.readError)
        }

        var entries = ArrayList<FileEntry>()

        var entry = LibArchiveEntry()
        while (archive.readNextHeader(entry) == ArchiveResult.ok) {
            if (entry.filetype() != FILETYPE_REGULAR) {
                continue
            }

            let pathname = entry.pathnameUTF8()

            // 应用 glob 模式过滤（支持正负模式）
            if (let Some(patterns) <- globPatterns) {
                if (!matchGlobPatterns(patterns, pathname)) {
                    continue
                }
            }

            let size: Int64 = entry.size().max(0)
            let mtime: Int64 = entry.mTime()

            // 增量读取数据，避免不受信任的条目大小驱动分配
            var data = ArrayList<UInt8>()
            if (size > 0) {
                var totalRead: Int64 = 0
                let buf = Array<UInt8>(65536, { _ => UInt8(0) })
                while (totalRead < size) {
                    let toRead = min(size - totalRead, Int64(buf.size))
                    let read = archive.readData(buf, Int64(0), toRead)
                    if (read < 0) {
                        // 读取错误
                        if (let err <- cloneErrorString(archive)) {
                            return FilesResult.libarchiveErr(err)
                        }
                        return FilesArchiveResult2.err(FilesError.readError)
                    }
                    if (read == 0) {
                        break
                    }
                    for (i in 0..read) {
                        data.append(buf[i])
                    }
                    totalRead += read
                }
            }

            let pathCopy = pathname.toArray()
            entries.append(FileEntry(path: pathCopy, data: data.toArray(), mtime: mtime))
        }

        return FilesResult.success(entries)
    }

    /// 在 JS 线程上处理结果
    /// 对应 Bun: FilesContext::run_from_js()
    public func runFromJS(global!: JsGlobalObject): PromiseResult {
        match (result) {
            case FilesResult.success(entries) =>
                let map = JsMap.create(global)
                if (let Some(mapPtr) <- JsMap.fromJS(map)) {
                    for (entry in entries) {
                        let data = entry.data
                        let blobPtr = Blob.new(Blob.createWithBytesAndAllocator(data, global, false))
                        let blob = blobPtr
                        blob.isJsdomFile = true
                        blob.name = BunString.cloneUTF8(entry.path)
                        blob.lastModified = Float64(entry.mtime * 1000)

                        let nameJs = blob.name.toJS(global)
                        let blobJs = blob.toJS(global)
                        mapPtr.set(global, nameJs, blobJs)
                    }
                    return PromiseResult.resolve(map)
                }
                return PromiseResult.reject(global.createErrorInstance("Failed to create Map"))
            case FilesResult.libarchiveErr(errMsg) =>
                return PromiseResult.reject(global.createErrorInstance(errMsg))
            case FilesArchiveResult2.err(e) =>
                return PromiseResult.reject(global.createErrorInstance(filesErrorToString(e)))
        }
    }
}

/// 启动文件列表任务
/// 对应 Bun: start_files_task()
public func startFilesTask(global!: JsGlobalObject, store!: BlobStore,
                            globPatterns!: ?Array<String>): JsValue {
    store.ref()

    let taskOpt = FilesTask.create(global, FilesContext(
        store: store,
        globPatterns: globPatterns,
    ))
    if (taskOpt.isNone()) {
        return JsValue.jsUndefined()
    }
    let task = taskOpt.getOrThrow()

    let promiseJs = task.promiseValue()
    task.schedule()
    return promiseJs
}

/// FilesError 转字符串
public func filesErrorToString(e!: FilesError): String {
    match (e) {
        case outOfMemory => "OutOfMemory"
        case readError => "ReadError"
    }
}

// ============================================================================
// Gzip 压缩
// 对应 Bun: compress_gzip()
// ============================================================================

/// 压缩错误
/// 对应 Bun: CompressError
public enum CompressError {
    | gzipInitFailed
    | gzipCompressFailed
    | outOfMemory
}

/// 使用 gzip 压缩数据
/// 对应 Bun: compress_gzip()
/// 使用 libdeflate 进行 gzip 压缩
public func compressGzip(data!: Array<UInt8>, level!: UInt8): ?Array<UInt8> {
    Libdeflate.load()

    let compressorPtr = Libdeflate.Compressor.alloc(Int32(level))
    if (compressorPtr == none) {
        return None
    }

    let compressor = compressorPtr

    let maxSize = compressor.maxBytesNeeded(data, Libdeflate.Encoding.gzip)

    var output = ArrayList<UInt8>(maxSize, { _ => UInt8(0) })
    let result = compressor.compressToVec(data, output, Libdeflate.Encoding.gzip)
    if (result.status != Libdeflate.Status.success) {
        compressor.destroy()
        return None
    }

    compressor.destroy()
    return output.toArray()
}

// ============================================================================
// 辅助函数
// 对应 Bun: is_safe_path, match_glob_patterns, extract_to_disk_filtered
// ============================================================================

/// 检查路径是否安全（无绝对路径或路径遍历）
/// 对应 Bun: is_safe_path()
public func isSafePath(pathname!: Array<UInt8>): Bool {
    if (pathname.size == 0) {
        return false
    }

    // 拒绝绝对路径
    if (pathname[0] == UInt8('/'.value) || pathname[0] == UInt8('\\'.value)) {
        return false
    }

    // 检查 Windows 驱动器号 (如 "C:")
    if (pathname.size >= 2 && pathname[1] == UInt8(':'.value)) {
        return false
    }

    // 拒绝包含 ".." 组件的路径
    for (component in pathname.split(UInt8('/'.value))) {
        if (component == "..".toArray()) {
            return false
        }
        // 也检查 Windows 风格的分隔符
        for (winComponent in component.split(UInt8('\\'.value))) {
            if (winComponent == "..".toArray()) {
                return false
            }
        }
    }

    return true
}

/// 检查路径是否安全（字符串版本）
public func isSafePathStr(pathname!: String): Bool {
    if (pathname.size == 0) {
        return false
    }

    if (pathname[0] == '/' || pathname[0] == '\\') {
        return false
    }

    if (pathname.size >= 2 && pathname[1] == ':') {
        return false
    }

    for (component in pathname.split('/')) {
        if (component == "..") {
            return false
        }
        for (winComponent in component.split('\\')) {
            if (winComponent == "..") {
                return false
            }
        }
    }

    return true
}

/// 匹配多个 glob 模式，支持否定模式
/// 对应 Bun: match_glob_patterns()
/// 正模式: 至少一个必须匹配才能包含
/// 否定模式 (以 "!" 开头): 如果匹配则排除
/// 返回 true 表示应包含，false 表示排除
public func matchGlobPatterns(patterns!: Array<String>, pathname!: String): Bool {
    var hasPositivePatterns = false
    var matchesPositive = false

    for (pattern in patterns) {
        if (pattern.size > 0 && pattern[0] == '!') {
            // 否定模式 — 如果匹配则排除
            let negPattern = pattern.substring(1)
            if (negPattern.size > 0 && Glob.`match`(negPattern, pathname).matches()) {
                return false
            }
        } else {
            // 正模式 — 至少一个必须匹配
            hasPositivePatterns = true
            if (Glob.`match`(pattern, pathname).matches()) {
                matchesPositive = true
            }
        }
    }

    // 如果没有正模式，包含所有（未被排除的）
    // 如果有正模式，至少一个必须匹配
    return !hasPositivePatterns || matchesPositive
}

/// 使用 glob 模式过滤提取归档到磁盘
/// 对应 Bun: extract_to_disk_filtered()
/// 支持 "!" 前缀的否定模式 (如 "!node_modules/**")
public func extractToDiskFiltered(fileBuffer!: Array<UInt8>, root!: Array<UInt8>,
                                   globPatterns!: ?Array<String>): ?UInt32 {
    let archive = LibArchive.readArchiveNew()
    configureArchiveReader(archive)

    if (archive.readOpenMemory(fileBuffer) != ArchiveResult.ok) {
        return None
    }

    // 打开/创建目标目录
    let cwd = Fd.cwd()
    cwd.makePath(root)
    let dirFd: Fd = match (isAbsolutePath(root)) {
        case true =>
            match (SysFile.openA(root, SysOpenFlags.RDONLY | SysOpenFlags.DIRECTORY, 0)) {
                case ok(fd) => fd
                case err(_) => return None
            }
        case false =>
            match (SysFile.openatA(cwd, root, SysOpenFlags.RDONLY | SysOpenFlags.DIRECTORY, 0)) {
                case ok(fd) => fd
                case err(_) => return None
            }
    }

    var count: UInt32 = 0
    var entry = LibArchiveEntry()

    while (archive.readNextHeader(entry) == ArchiveResult.ok) {
        let pathname = entry.pathnameUTF8()

        // 验证路径安全（拒绝绝对路径、路径遍历）
        if (!isSafePathStr(pathname)) {
            continue
        }

        // 应用 glob 模式过滤
        if (let Some(patterns) <- globPatterns) {
            if (!matchGlobPatterns(patterns, pathname)) {
                continue
            }
        }

        let filetype = entry.filetype()
        let kind = kindFromMode(filetype)

        match (kind) {
            case FileKind.directory =>
                let mkResult = dirFd.makePath(pathname)
                match (mkResult) {
                    case err(e) =>
                        // PathAlreadyExists or other error - continue
                        continue
                    case ok(_) => ()
                }
                count += 1
            case FileKind.file =>
                let size: Int64 = entry.size().max(0)
                // 净化权限: 使用条目权限掩码到 0o777, 或默认 0o644
                let entryPerm = entry.perm()
                let mode: UInt32 = if (entryPerm != 0) {
                    entryPerm & 0o777
                } else {
                    0o644
                }

                // 如需要创建父目录
                if (let Some(parentDir) <- dirname(pathname)) {
                    match (dirFd.makePath(parentDir)) {
                        case err("PathAlreadyExists") => ()
                        case err("AccessDenied") => ()
                        case err(_) => ()
                        case ok(_) => ()
                    }
                }

                // 创建并写入文件
                let fileFd = match (SysFile.openat(dirFd, pathname,
                    SysOpenFlags.WRONLY | SysOpenFlags.CREAT | SysOpenFlags.TRUNC, mode)) {
                    case ok(fd) => fd
                    case err(_) => continue
                }

                var writeSuccess = true
                if (size > 0) {
                    var remaining = size
                    let buf = Array<UInt8>(65536, { _ => UInt8(0) })
                    while (remaining > 0) {
                        let toRead = min(remaining, Int64(buf.size))
                        let read = archive.readData(buf, Int64(0), toRead)
                        if (read <= 0) {
                            writeSuccess = false
                            break
                        }
                        // 写入所有字节，处理部分写入
                        var written: Int64 = 0
                        while (written < read) {
                            let w = match (SysFile.write(fileFd, buf, written, read)) {
                                case ok(n) => n
                                case err(_) =>
                                    writeSuccess = false
                                    break
                            }
                            if (w == 0) {
                                writeSuccess = false
                                break
                            }
                            written += w
                        }
                        if (!writeSuccess) {
                            break
                        }
                        remaining -= read
                    }
                }
                fileFd.close()

                if (writeSuccess) {
                    count += 1
                } else {
                    // 失败时删除部分文件
                    SysFile.unlinkat(dirFd, pathname)
                }
            case FileKind.symLink =>
                let linkTarget = entry.symlink()
                // 验证符号链接目标也是安全的
                if (!isSafePathStr(linkTarget)) {
                    continue
                }
                // 符号链接提取 — POSIX 系统支持
                match (SysFile.symlinkat(linkTarget, dirFd, pathname)) {
                    case err(e) =>
                        if (e == "EPERM" || e == "ENOENT") {
                            if (let Some(parent) <- dirname(pathname)) {
                                dirFd.makePath(parent)
                            }
                            match (SysFile.symlinkat(linkTarget, dirFd, pathname)) {
                                case err(_) => continue
                                case ok(_) => ()
                            }
                        } else {
                            continue
                        }
                    case ok(_) => ()
                }
                count += 1
            case _ => ()
        }
    }

    return count
}

// ============================================================================
// 异步任务封装
// 对应 Bun: AsyncTask<C>
// ============================================================================

/// 通用异步任务 — 处理线程池任务的所有样板代码
/// 对应 Bun: AsyncTask<C>
public class AsyncTask<C> {
    public var ctx: C
    public var promise: JsPromiseStrong
    public var vm: VirtualMachine
    public var concurrentTask: ConcurrentTask
    public var keepAlive: KeepAlive

    public init(ctx: C, promise: JsPromiseStrong, vm: VirtualMachine) {
        this.ctx = ctx
        this.promise = promise
        this.vm = vm
        this.concurrentTask = ConcurrentTask()
        this.keepAlive = KeepAlive()
    }

    /// 创建任务
    /// 对应 Bun: AsyncTask::create()
    public static func create(global!: JsGlobalObject, ctx!: C): ?AsyncTask<C> {
        let vm = global.bunVmPtr()
        let promise = JsPromiseStrong(global)
        let task = AsyncTask<C>(ctx: ctx, promise: promise, vm: vm)
        task.keepAlive.ref(global.jsVmCtx())
        return task
    }

    /// 调度任务
    /// 对应 Bun: AsyncTask::schedule()
    public func schedule(): Unit {
        WorkPool.schedule(this)
    }

    /// 获取 Promise 的 JS 值
    /// 对应 Bun: AsyncTask::promise_value()
    public func promiseValue(): JsValue {
        return promise.getValue()
    }

    /// 线程池回调
    /// 对应 Bun: AsyncTask::run_callback()
    public func runCallback(): Unit {
        ctx.run()
        vm.enqueueTaskConcurrent(concurrentTask)
    }

    /// 在 JS 线程上运行
    /// 对应 Bun: AsyncTask::run_from_js()
    public func runFromJS(): Unit {
        keepAlive.unref(vm.jsVmCtx())

        if (vm.isShuttingDown()) {
            return
        }

        let global = vm.global()
        let promiseVal = promise.swap()
        let result = ctx.runFromJS(global)
        result.fulfill(global, promiseVal)
    }
}

// ============================================================================
// 具体任务类型别名
// ============================================================================

/// 提取任务
/// 对应 Bun: ExtractTask = AsyncTask<ExtractContext>
public class ExtractTask {
    public var ctx: ExtractContext
    public var promise: JsPromiseStrong
    public var vm: VirtualMachine
    public var concurrentTask: ConcurrentTask
    public var keepAlive: KeepAlive

    public init(ctx: ExtractContext, promise: JsPromiseStrong, vm: VirtualMachine) {
        this.ctx = ctx
        this.promise = promise
        this.vm = vm
        this.concurrentTask = ConcurrentTask()
        this.keepAlive = KeepAlive()
    }

    public static func create(global!: JsGlobalObject, ctx!: ExtractContext): ?ExtractTask {
        let vm = global.bunVmPtr()
        let promise = JsPromiseStrong(global)
        let task = ExtractTask(ctx: ctx, promise: promise, vm: vm)
        task.keepAlive.ref(global.jsVmCtx())
        return task
    }

    public func schedule(): Unit {
        WorkPool.schedule(this)
    }

    public func promiseValue(): JsValue {
        return promise.getValue()
    }

    public func runCallback(): Unit {
        ctx.doRun()
        vm.enqueueTaskConcurrent(concurrentTask)
    }

    public func runFromJS(): Unit {
        keepAlive.unref(vm.jsVmCtx())
        if (vm.isShuttingDown()) {
            return
        }
        let global = vm.global()
        let promiseVal = promise.swap()
        match (ctx.result) {
            case ExtractResult.success(count) =>
                promiseVal.resolve(global, JsValue.jsNumber(Float64(count)))
            case ExtractArchiveResult2.err(e) =>
                promiseVal.rejectWithAsyncStack(global, global.createErrorInstance("ReadError"))
        }
    }
}

/// Blob 任务
/// 对应 Bun: BlobTask = AsyncTask<BlobContext>
public class BlobTask {
    public var ctx: BlobContext
    public var promise: JsPromiseStrong
    public var vm: VirtualMachine
    public var concurrentTask: ConcurrentTask
    public var keepAlive: KeepAlive

    public init(ctx: BlobContext, promise: JsPromiseStrong, vm: VirtualMachine) {
        this.ctx = ctx
        this.promise = promise
        this.vm = vm
        this.concurrentTask = ConcurrentTask()
        this.keepAlive = KeepAlive()
    }

    public static func create(global!: JsGlobalObject, ctx!: BlobContext): ?BlobTask {
        let vm = global.bunVmPtr()
        let promise = JsPromiseStrong(global)
        let task = BlobTask(ctx: ctx, promise: promise, vm: vm)
        task.keepAlive.ref(global.jsVmCtx())
        return task
    }

    public func schedule(): Unit {
        WorkPool.schedule(this)
    }

    public func promiseValue(): JsValue {
        return promise.getValue()
    }

    public func runCallback(): Unit {
        ctx.doRun()
        vm.enqueueTaskConcurrent(concurrentTask)
    }

    public func runFromJS(): Unit {
        keepAlive.unref(vm.jsVmCtx())
        if (vm.isShuttingDown()) {
            return
        }
        let global = vm.global()
        let promiseVal = promise.swap()
        ctx.runFromJS(global).fulfill(global, promiseVal)
    }
}

/// 写入任务
/// 对应 Bun: WriteTask = AsyncTask<WriteContext>
public class WriteTask {
    public var ctx: WriteContext
    public var promise: JsPromiseStrong
    public var vm: VirtualMachine
    public var concurrentTask: ConcurrentTask
    public var keepAlive: KeepAlive

    public init(ctx: WriteContext, promise: JsPromiseStrong, vm: VirtualMachine) {
        this.ctx = ctx
        this.promise = promise
        this.vm = vm
        this.concurrentTask = ConcurrentTask()
        this.keepAlive = KeepAlive()
    }

    public static func create(global!: JsGlobalObject, ctx!: WriteContext): ?WriteTask {
        let vm = global.bunVmPtr()
        let promise = JsPromiseStrong(global)
        let task = WriteTask(ctx: ctx, promise: promise, vm: vm)
        task.keepAlive.ref(global.jsVmCtx())
        return task
    }

    public func schedule(): Unit {
        WorkPool.schedule(this)
    }

    public func promiseValue(): JsValue {
        return promise.getValue()
    }

    public func runCallback(): Unit {
        ctx.doRun()
        vm.enqueueTaskConcurrent(concurrentTask)
    }

    public func runFromJS(): Unit {
        keepAlive.unref(vm.jsVmCtx())
        if (vm.isShuttingDown()) {
            return
        }
        let global = vm.global()
        let promiseVal = promise.swap()
        ctx.runFromJS(global).fulfill(global, promiseVal)
    }
}

/// 文件列表任务
/// 对应 Bun: FilesTask = AsyncTask<FilesContext>
public class FilesTask {
    public var ctx: FilesContext
    public var promise: JsPromiseStrong
    public var vm: VirtualMachine
    public var concurrentTask: ConcurrentTask
    public var keepAlive: KeepAlive

    public init(ctx: FilesContext, promise: JsPromiseStrong, vm: VirtualMachine) {
        this.ctx = ctx
        this.promise = promise
        this.vm = vm
        this.concurrentTask = ConcurrentTask()
        this.keepAlive = KeepAlive()
    }

    public static func create(global!: JsGlobalObject, ctx!: FilesContext): ?FilesTask {
        let vm = global.bunVmPtr()
        let promise = JsPromiseStrong(global)
        let task = FilesTask(ctx: ctx, promise: promise, vm: vm)
        task.keepAlive.ref(global.jsVmCtx())
        return task
    }

    public func schedule(): Unit {
        WorkPool.schedule(this)
    }

    public func promiseValue(): JsValue {
        return promise.getValue()
    }

    public func runCallback(): Unit {
        ctx.doRun()
        vm.enqueueTaskConcurrent(concurrentTask)
    }

    public func runFromJS(): Unit {
        keepAlive.unref(vm.jsVmCtx())
        if (vm.isShuttingDown()) {
            return
        }
        let global = vm.global()
        let promiseVal = promise.swap()
        ctx.runFromJS(global).fulfill(global, promiseVal)
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 格式化文件大小
public func fmtSize(size!: Int64): String {
    if (size < 1024) {
        return "${size} B"
    } else if (size < 1024 * 1024) {
        return "${size / 1024} KB"
    } else if (size < 1024 * 1024 * 1024) {
        return "${size / (1024 * 1024)} MB"
    } else {
        return "${size / (1024 * 1024 * 1024)} GB"
    }
}

/// 检查是否为绝对路径
public func isAbsolutePath(path!: Array<UInt8>): Bool {
    if (path.size == 0) {
        return false
    }
    return path[0] == UInt8('/'.value)
}

/// 获取路径的目录名部分
public func dirname(path!: String): ?String {
    let idx = path.lastIndexOf('/')
    if (idx < 0) {
        return None
    }
    if (idx == 0) {
        return "/"
    }
    return path.substring(0, idx)
}

/// Int64 最小值
public func min(a!: Int64, b!: Int64): Int64 {
    if (a < b) { a } else { b }
}

/// Int64 最大值
public func max(a!: Int64, b!: Int64): Int64 {
    if (a > b) { a } else { b }
}

/// 获取当前时间戳（毫秒）
public func timeMilliTimestamp(): Int64 {
    System.currentTimeMillis
}

/// 从文件模式获取文件类型
public func kindFromMode(mode!: UInt32): FileKind {
    let fileType = mode & 0xF000
    match (fileType) {
        case 0x8000 => FileKind.file       // S_IFREG
        case 0x4000 => FileKind.directory   // S_IFDIR
        case 0xA000 => FileKind.symLink     // S_IFLNK
        case _ => FileKind.other
    }
}

// ============================================================================
// 文件类型枚举
// ============================================================================

/// 文件类型
public enum FileKind {
    | file
    | directory
    | symLink
    | other
}

/// 系统错误
public class SysError {
    public var code: String = ""
    public var message: String = ""

    public init() {}

    public init(code: String, message: String) {
        this.code = code
        this.message = message
    }

    public func toJS(global!: JsGlobalObject): JsValue {
        global.createErrorInstance("${code}: ${message}")
    }
}

// ============================================================================
// 系统文件操作封装
// 对应 Bun: bun_sys FFI 绑定
// ============================================================================

/// 系统文件描述符
public class Fd {
    public var fd: Int32 = -1
    public static func cwd(): Fd {
        Fd(fd: Sys.getCwdFd())
    }

    public init() {}
    public init(fd: Int32) {
        this.fd = fd
    }

    public func makePath(path!: Array<UInt8>): Unit {
        Sys.mkdirRecursive(fd, path)
    }

    public func makePath(path!: String): Unit {
        Sys.mkdirRecursive(fd, path)
    }

    public func close(): Unit {
        if (fd >= 0) {
            Sys.close(fd)
            fd = -1
        }
    }
}

/// 系统文件操作
public class SysFile {
    public static func openat(dirFd!: Fd, path!: String, flags!: Int32, mode!: UInt32): ArchiveResult2<Fd, SysError> {
        let fd = Sys.openat(dirFd.fd, path, flags, mode)
        if (fd < 0) {
            return ArchiveResult2.err(SysError(code: "OpenError", message: "Failed to open ${path}"))
        }
        return ArchiveResult2.ok(Fd(fd: fd))
    }

    public static func openat(dirFd!: Fd, path!: Array<UInt8>, flags!: Int32, mode!: UInt32): ArchiveResult2<Fd, SysError> {
        let pathStr = String.fromUtf8(path)
        return openat(dirFd, pathStr, flags, mode)
    }

    public static func openA(path!: Array<UInt8>, flags!: Int32, mode!: UInt32): ArchiveResult2<Fd, SysError> {
        let pathStr = String.fromUtf8(path)
        let fd = Sys.open(pathStr, flags, mode)
        if (fd < 0) {
            return ArchiveResult2.err(SysError(code: "OpenError", message: "Failed to open file"))
        }
        return ArchiveResult2.ok(Fd(fd: fd))
    }

    public static func openatA(dirFd!: Fd, path!: Array<UInt8>, flags!: Int32, mode!: UInt32): ArchiveResult2<Fd, SysError> {
        let pathStr = String.fromUtf8(path)
        return openat(dirFd, pathStr, flags, mode)
    }

    public static func write(fd!: Fd, buf!: Array<UInt8>, offset!: Int64, length!: Int64): ArchiveResult2<Int64, SysError> {
        let n = Sys.writeFd(fd.fd, buf, offset, length)
        if (n < 0) {
            return ArchiveResult2.err(SysError(code: "WriteError", message: "Failed to write"))
        }
        return ArchiveResult2.ok(n)
    }

    public static func writeAll(fd!: Fd, data!: Array<UInt8>): ArchiveResult2<Unit, SysError> {
        var written: Int64 = 0
        while (written < data.size) {
            match (write(fd, data, written, data.size - written)) {
                case ok(n) =>
                    if (n == 0) {
                        return ArchiveResult2.err(SysError(code: "WriteError", message: "Write returned 0"))
                    }
                    written += n
                case err(e) => return ArchiveResult2.err(e)
            }
        }
        return ArchiveResult2.ok(())
    }

    public static func symlinkat(target!: String, dirFd!: Fd, path!: String): ArchiveResult2<Unit, SysError> {
        let rc = Sys.symlinkat(target, dirFd.fd, path)
        if (rc < 0) {
            return ArchiveResult2.err(SysError(code: "SymlinkError", message: "Failed to create symlink"))
        }
        return ArchiveResult2.ok(())
    }

    public static func unlinkat(dirFd!: Fd, path!: String): Unit {
        Sys.unlinkat(dirFd.fd, path)
    }
}

/// 系统打开标志
public class SysOpenFlags {
    public static let RDONLY: Int32 = 0
    public static let WRONLY: Int32 = 1
    public static let RDWR: Int32 = 2
    public static let CREAT: Int32 = 64      // O_CREAT
    public static let TRUNC: Int32 = 512     // O_TRUNC
    public static let DIRECTORY: Int32 = 65536 // O_DIRECTORY
}

// ============================================================================
// KeepAlive - 事件循环活跃引用
// 对应 Bun: KeepAlive
// ============================================================================

/// 事件循环活跃引用
public class KeepAlive {
    private var refCount: Int32 = 0

    public init() {}

    public func ref(ctx!: JsVmCtx): Unit {
        refCount += 1
        ctx.ref()
    }

    public func unref(ctx!: JsVmCtx): Unit {
        if (refCount > 0) {
            refCount -= 1
            ctx.unref()
        }
    }
}

// ============================================================================
// 虚拟机接口
// 对应 Bun: VirtualMachine
// ============================================================================

/// 虚拟机封装
public class VirtualMachine {
    public var globalObj: JsGlobalObject

    public init(global: JsGlobalObject) {
        this.globalObj = global
    }

    public func global(): JsGlobalObject {
        globalObj
    }

    public func isShuttingDown(): Bool {
        false // 简化实现
    }

    public func enqueueTaskConcurrent(task!: ConcurrentTask): Unit {
        EventLoop.enqueueConcurrent(task)
    }

    public func jsVmCtx(): JsVmCtx {
        JsVmCtx.current()
    }
}

/// JS 虚拟机上下文
public class JsVmCtx {
    public func ref(): Unit {}
    public func unref(): Unit {}
    public static func current(): JsVmCtx {
        JsVmCtx()
    }
}

/// 并发任务
public class ConcurrentTask {
    public init() {}
}

/// 工作池
public class WorkPool {
    public static func schedule(task!: Object): Unit {
        EventLoop.scheduleWorkPool(task)
    }
}

/// JS Promise 强引用
public class JsPromiseStrong {
    public var value: JsValue

    public init() {
        value = JsValue.jsUndefined()
    }

    public static func `init`(global!: JsGlobalObject): JsPromiseStrong {
        let p = JsPromiseStrong()
        p.value = JsPromise.create(global)
        return p
    }

    public func getValue(): JsValue {
        value
    }

    public func swap(): JsPromise {
        JsPromise.fromValue(value)
    }
}

/// JS Map 封装
public class JsMap {
    public var jsValue: JsValue

    public init(jsValue: JsValue) {
        this.jsValue = jsValue
    }

    public static func create(global!: JsGlobalObject): JsValue {
        JsValue.createMap(global)
    }

    public static func fromJS(value!: JsValue): ?JsMap {
        if (value.isObject()) {
            return JsMap(jsValue: value)
        }
        return None
    }

    public func `set`(global!: JsGlobalObject, key!: JsValue, val!: JsValue): Unit {
        jsValue.mapSet(global, key, val)
    }
}

/// Console 格式化器接口
public interface ConsoleFormatter {
    func indented(): ConsoleFormatter
    func writeIndent(writer!: ArchiveStringBuilder): Unit
    func printAs(writer!: ArchiveStringBuilder, value!: JsValue, `type`!: JSType, enableAnsiColors!: Bool): Unit
    func resetLine(): Unit
}

/// 属性迭代器选项
public class PropertyIteratorOptions {
    public var skipEmptyName: Bool
    public var includeValue: Bool

    public init(skipEmptyName: Bool, includeValue: Bool) {
        this.skipEmptyName = skipEmptyName
        this.includeValue = includeValue
    }
}

/// JS 属性迭代器
public class JSPropertyIterator {
    public var jsObj: JsValue
    public var options: PropertyIteratorOptions
    public var index: Int64 = 0
    public var keys: Array<String>
    public var values: Array<JsValue>
    public var value: JsValue = JsValue.jsUndefined()

    public init(jsObj: JsValue, options: PropertyIteratorOptions) {
        this.jsObj = jsObj
        this.options = options
        this.keys = []
        this.values = []
    }

    public static func `init`(global!: JsGlobalObject, jsObj!: JsValue, options!: PropertyIteratorOptions): ?JSPropertyIterator {
        let iter = JSPropertyIterator(jsObj, options)
        // 提取所有键和值
        iter.keys = jsObj.getOwnProperties(global)  ?? []
        return iter
    }

    public func next(): ?String {
        if (index >= keys.size) {
            return None
        }
        let key = keys[index]
        index += 1
        return key
    }
}

/// Libdeflate 压缩接口
/// 对应 Bun: bun_libdeflate_sys::libdeflate
public class Libdeflate {
    public static func load(): Unit {
        // 加载 libdeflate 库
    }

//    public class Compressor {
//        public static func alloc(level!: Int32): ?Compressor {
//            // 分配压缩器
//            let c = Compressor()
//            c.level = level
//            return c
//        }

//        public var level: Int32 = 6

//        public func maxBytesNeeded(data!: Array<UInt8>, encoding!: Encoding): Int64 {
//            // 计算 gzip 压缩最大输出大小
//            Int64(data.size + data.size / 10 + 64)
//        }

//        public func compressToVec(data!: Array<UInt8>, output!: ArrayList<UInt8>, encoding!: Encoding): CompressResult {
//            // 执行 gzip 压缩
//            // 简化实现 — 实际通过 FFI 调用 libdeflate
//            CompressResult(status: Status.success)
//        }

//        public func destroy(): Unit {
//            // 释放压缩器
//        }
//    }

//    public enum Encoding {
//        | gzip
//        | raw
//        | zlib
//    }

//    public class Status {
//        public static let success: Int32 = 0
//    }

//    public class CompressResult {
//        public var status: Int32
//        public init(status: Int32) {
//            this.status = status
//        }
//    }
}

/// GrowingBuffer — tarball 构建期间使用
/// 对应 Bun: libarchive::GrowingBuffer
public class GrowingBuffer {
    public var buffer: ArrayList<UInt8>

    public init() {
        buffer = ArrayList<UInt8>()
    }

    public static func `init`(): GrowingBuffer {
        GrowingBuffer()
    }

    public func asPtr(): UIntNative {
        UIntNative(buffer.hashCode())
    }

    public static func openCallback(archive!: UIntNative, context!: UIntNative): Int32 {
        0 // ARCHIVE_OK
    }

    public static func writeCallback(archive!: UIntNative, context!: UIntNative, data!: UIntNative, length!: Int64): Int64 {
        length
    }

    public static func closeCallback(archive!: UIntNative, context!: UIntNative): Int32 {
        0 // ARCHIVE_OK
    }

    public func toOwnedSlice(): ?Array<UInt8> {
        if (buffer.isEmpty()) {
            return None
        }
        return buffer.toArray()
    }
}

/// LibArchive 封装
/// 对应 Bun: bun_libarchive
public class LibArchive {
    public static func writeArchiveNew(): LibArchive {
        LibArchive()
    }

    public static func readArchiveNew(): LibArchive {
        LibArchive()
    }

    public static func ownedEntryNew(): LibArchiveEntry {
        LibArchiveEntry()
    }

    public static func archiveWriteOpen2(archive!: UIntNative, context!: UIntNative,
                                          openCb!: (UIntNative, UIntNative) -> Int32,
                                          writeCb!: (UIntNative, UIntNative, UIntNative, Int64) -> Int64,
                                          closeCb!: (UIntNative, UIntNative) -> Int32,
                                          none!: ?Object): Int32 {
        0 // ARCHIVE_OK
    }

    public var data: ArrayList<UInt8>

    public init() {
        data = ArrayList<UInt8>()
    }

    public func asPtr(): UIntNative {
        UIntNative(data.hashCode())
    }

    public func asRef(): LibArchive {
        this
    }

    public func writeSetFormatPaxRestricted(): ArchiveResult {
        ArchiveResult.ok
    }

    public func readSupportFormatTar(): Unit {}
    public func readSupportFormatGnuTar(): Unit {}
    public func readSupportFilterGzip(): Unit {}
    public func readSetOptions(opts!: String): Unit {}

    public func readOpenMemory(data!: Array<UInt8>): ArchiveResult {
        this.data = ArrayList<UInt8>()
        for (b in data) {
            this.data.append(b)
        }
        return ArchiveResult.ok
    }

    public func readNextHeader(entry!: LibArchiveEntry): ArchiveResult {
        // 简化实现 — 实际通过 FFI 调用 libarchive
        ArchiveResult.eof
    }

    public func readData(buf!: Array<UInt8>, offset!: Int64, length!: Int64): Int64 {
        0
    }

    public func writeHeader(entry!: LibArchiveEntry): ArchiveResult {
        ArchiveResult.ok
    }

    public func writeData(data!: Array<UInt8>): Int64 {
        Int64(data.size)
    }

    public func writeFinishEntry(): ArchiveResult {
        ArchiveResult.ok
    }

    public func writeClose(): ArchiveResult {
        ArchiveResult.ok
    }

    public func errorString(): String {
        ""
    }
}

/// 归档结果枚举
public enum ArchiveResult {
    | ok
    | eof
    | retry
    | warn
    | failed
    | fatal
}

/// 归档条目
public class LibArchiveEntry {
    public var pathnameStr: String = ""
    public var sizeVal: Int64 = 0
    public var filetypeVal: UInt32 = 0
    public var permVal: UInt32 = 0o644
    public var mtimeVal: Int64 = 0
    public var symlinkStr: String = ""

    public init() {
    }

    public func asRef(): LibArchiveEntry { this }
    

    public func clear(): Unit {
        pathnameStr = ""
        sizeVal = 0
        filetypeVal = 0
        permVal = 0o644
        mtimeVal = 0
        symlinkStr = ""
    }

    public func setPathnameUTF8(path!: String): Unit {
        pathnameStr = path
    }

    public func setSize(size!: Int64): Unit {
        sizeVal = size
    }

    public func setFiletype(ft!: UInt32): Unit {
        filetypeVal = ft
    }

    public func setPerm(perm!: UInt32): Unit {
        permVal = perm
    }

    public func setMTime(sec!: Int64, nsec!: Int64): Unit {
        mtimeVal = sec
    }

    public func filetype(): UInt32 {
        filetypeVal
    }

    public func pathnameUTF8(): String {
        pathnameStr
    }

    public func size(): Int64 {
        sizeVal
    }

    public func perm(): UInt32 {
        permVal
    }

    public func mTime(): Int64 {
        mtimeVal
    }

    public func symlink(): String {
        symlinkStr
    }
}
