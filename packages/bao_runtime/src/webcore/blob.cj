// 严格翻译自: src/runtime/webcore/Blob.zig
// The JS `Blob` class can be backed by different forms (in Blob.Store), which
// represent different sources of Blob. For example, `Bun.file()` returns Blob
// objects that reference the filesystem (Blob.Store.File). This is how
// operations like writing `Store.File` to another `Store.File` knows to use a
// basic file copy instead of a naive read write loop.
package bao_runtime.webcore

import bao_core.*
import bao_collections.*
import bao_jsc.*

// ============================================================================
// Blob.SizeType — Blob 大小类型
// 对应 Bun: Blob.SizeType (u52)
// ============================================================================
public type BlobSizeType = Int64

// ============================================================================
// Blob.ClosingState — 关闭状态
// 对应 Bun: Blob.ClosingState
// ============================================================================
public enum ClosingState {
    | running
    | closing
}

// ============================================================================
// Blob.Store — Blob 底层存储
// 对应 Bun: Blob.Store
// ============================================================================
public class BlobStore {
    /// 存储类型
    /// 对应 Bun: Blob.Store.data
    public var kind: BlobStoreKind
    /// 内存数据
    /// 对应 Bun: Blob.Store.Bytes.bytes
    public var bytes: Array<UInt8>
    /// 存储名称（File 对象的文件名）
    /// 对应 Bun: Blob.Store.Bytes.stored_name
    public var storedName: String
    /// 文件路径 (File 类型)
    /// 对应 Bun: Blob.Store.File.pathlike
    public var filePath: String
    /// 文件描述符 (File 类型)
    /// 对应 Bun: Blob.Store.File.pathlike (fd variant)
    public var fileFd: Int32
    /// 是否是文件描述符
    public var isFd: Bool
    /// MIME 类型
    /// 对应 Bun: Blob.Store.mime_type
    public var mimeType: String
    /// 文件模式（用于 existsSync 等判断）
    /// 对应 Bun: Blob.Store.File.mode
    public var fileMode: UInt64
    /// 最后修改时间戳
    /// 对应 Bun: Blob.Store.File.last_modified
    public var fileLastModified: Float64
    /// 引用计数
    /// 对应 Bun: Blob.Store.ref_count
    public var refCount: Int64
    /// 是否需要创建父目录（writeFile 时使用）
    /// 对应 Bun: Blob.Store.File.mkdirp_if_not_exists
    public var mkdirpIfNotExists: Bool

    public init() {
        kind = BlobStoreKind.Memory
        bytes = Array<UInt8>()
        storedName = ""
        filePath = ""
        fileFd = -1
        isFd = false
        mimeType = ""
        fileMode = 0
        fileLastModified = 0.0
        refCount = 1
        mkdirpIfNotExists = false
    }

    public init(bytes: Array<UInt8>) {
        kind = BlobStoreKind.Memory
        this.bytes = bytes
        storedName = ""
        filePath = ""
        fileFd = -1
        isFd = false
        mimeType = ""
        fileMode = 0
        fileLastModified = 0.0
        refCount = 1
        mkdirpIfNotExists = false
    }

    public init(bytes: Array<UInt8>, storedName: String) {
        kind = BlobStoreKind.Memory
        this.bytes = bytes
        this.storedName = storedName
        filePath = ""
        fileFd = -1
        isFd = false
        mimeType = ""
        fileMode = 0
        fileLastModified = 0.0
        refCount = 1
        mkdirpIfNotExists = false
    }

    public init(filePath: String, mimeType: String) {
        kind = BlobStoreKind.File
        bytes = Array<UInt8>()
        storedName = ""
        this.filePath = filePath
        fileFd = -1
        isFd = false
        this.mimeType = mimeType
        fileMode = 0
        fileLastModified = 0.0
        refCount = 1
        mkdirpIfNotExists = false
    }

    public init(fd: Int32, mimeType: String) {
        kind = BlobStoreKind.File
        bytes = Array<UInt8>()
        storedName = ""
        filePath = ""
        this.fileFd = fd
        isFd = true
        this.mimeType = mimeType
        fileMode = 0
        fileLastModified = 0.0
        refCount = 1
        mkdirpIfNotExists = false
    }

    /// 增加引用计数
    /// 对应 Bun: Blob.Store.ref()
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用计数，为 0 时释放
    /// 对应 Bun: Blob.Store.deref()
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            // 释放资源
            if (kind == BlobStoreKind.Memory) {
                bytes = Array<UInt8>()
            }
            storedName = ""
            filePath = ""
            mimeType = ""
        }
    }

    /// 获取共享视图（内存数据的只读引用）
    /// 对应 Bun: Blob.Store.sharedView()
    public func sharedView(): Array<UInt8> {
        return bytes
    }

    /// 获取存储大小
    /// 对应 Bun: Blob.Store.size()
    public func size(): Int64 {
        match (kind) {
            case BlobStoreKind.Memory => Int64(bytes.length)
            case BlobStoreKind.File => Blob.maxSize()  // 文件大小未知时返回 max
            case BlobStoreKind.S3 => Blob.maxSize()    // S3 大小未知时返回 max
        }
    }

    /// 获取路径（如果存在）
    /// 对应 Bun: Blob.Store.getPath()
    public func getPath(): ?String {
        if (kind == BlobStoreKind.File && !isFd) {
            return Some(filePath)
        }
        if (kind == BlobStoreKind.Memory && storedName.length > 0) {
            return Some(storedName)
        }
        return None
    }
}

// ============================================================================
// BlobStoreKind — Blob 存储类型枚举
// 对应 Bun: Blob.Store.Data
// ============================================================================
public enum BlobStoreKind {
    | Memory    // 内存中的字节数据 — 对应 Bun: Blob.Store.Data.bytes
    | File      // 文件系统引用 — 对应 Bun: Blob.Store.Data.file
    | S3        // S3 对象存储引用 — 对应 Bun: Blob.Store.Data.s3
}

// ============================================================================
// Blob — 二进制大对象
// 对应 Bun: src/runtime/webcore/Blob.zig Blob
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/Blob
// ============================================================================
public class Blob {
    /// Blob 数据大小
    /// 对应 Bun: Blob.size (SizeType)
    public var size: BlobSizeType
    /// 偏移量
    /// 对应 Bun: Blob.offset
    public var offset: BlobSizeType
    /// 底层存储
    /// 对应 Bun: Blob.store
    public var store: ?BlobStore
    /// 内容类型 (MIME type)
    /// 对应 Bun: Blob.content_type
    public var contentType: String
    /// 内容类型是否通过分配获得
    /// 对应 Bun: Blob.content_type_allocated
    public var contentTypeAllocated: Bool
    /// 内容类型是否由用户显式设置
    /// 对应 Bun: Blob.content_type_was_set
    public var contentTypeWasSet: Bool
    /// 字符集编码状态
    /// 对应 Bun: Blob.charset
    public var charset: CharsetKind
    /// 是否为 File 构造函数创建
    /// 对应 Bun: Blob.is_jsdom_file
    public var isJsdomFile: Bool
    /// 引用计数
    /// 对应 Bun: Blob.#ref_count
    public var refCount: Int64
    /// 全局对象引用
    /// 对应 Bun: Blob.globalThis
    public var globalThis: ?JsGlobalObject
    /// 最后修改时间
    /// 对应 Bun: Blob.last_modified
    public var lastModified: Float64
    /// Blob 名称（懒初始化）
    /// 对应 Bun: Blob.name
    public var name: String
    /// 估算的内存大小
    /// 对应 Bun: Blob.reported_estimated_size
    public var reportedEstimatedSize: Int64

    public init() {
        size = 0
        offset = 0
        store = None
        contentType = ""
        contentTypeAllocated = false
        contentTypeWasSet = false
        charset = CharsetKind.unknown
        isJsdomFile = false
        refCount = 0
        globalThis = None
        lastModified = 0.0
        name = ""
        reportedEstimatedSize = 0
    }

    public init(bytes: Array<UInt8>, contentType: String) {
        let store = BlobStore(bytes)
        this.size = Int64(bytes.length)
        this.offset = 0
        this.store = Some(store)
        this.contentType = contentType
        this.contentTypeAllocated = false
        this.contentTypeWasSet = contentType.length > 0
        this.charset = CharsetKind.unknown
        this.isJsdomFile = false
        this.refCount = 0
        this.globalThis = None
        this.lastModified = 0.0
        this.name = ""
        this.reportedEstimatedSize = 0
    }

    public init(store: BlobStore, offset: BlobSizeType, size: BlobSizeType) {
        this.size = size
        this.offset = offset
        this.store = Some(store)
        this.contentType = store.mimeType
        this.contentTypeAllocated = false
        this.contentTypeWasSet = false
        this.charset = CharsetKind.unknown
        this.isJsdomFile = false
        this.refCount = 0
        this.globalThis = None
        this.lastModified = 0.0
        this.name = ""
        this.reportedEstimatedSize = 0
    }

    /// 最大大小 (约 4.5 PB)
    /// 对应 Bun: Blob.max_size = std.math.maxInt(u52)
    public static func maxSize(): BlobSizeType {
        return 4503599627370495  // 2^52 - 1
    }

    // ========================================================================
    // 构造与初始化
    // ========================================================================

    /// 堆分配一个新的 Blob
    /// 对应 Bun: Blob.new(blob)
    public static func newHeap(blob: Blob): Blob {
        blob.refCount = 1
        return blob
    }

    /// 创建空 Blob
    /// 对应 Bun: Blob.initEmpty()
    public static func initEmpty(global: JsGlobalObject): Blob {
        let blob = Blob()
        blob.globalThis = Some(global)
        return blob
    }

    /// 从字节数组创建 Blob
    /// 对应 Bun: Blob.init(bytes, allocator, global)
    public static func initFunc(bytes: Array<UInt8>, allocator: String, global: JsGlobalObject): Blob {
        let store = BlobStore(bytes)
        let blob = Blob(store, 0, Int64(bytes.length))
        blob.globalThis = Some(global)
        return blob
    }

    /// 从指定 Store 创建 Blob
    /// 对应 Bun: Blob.initWithStore()
    public static func initWithStore(store: BlobStore, global: JsGlobalObject): Blob {
        store.ref()
        let blob = Blob(store, 0, store.size())
        blob.globalThis = Some(global)
        return blob
    }

    /// 从文件路径创建 Blob（Bun.file()）
    /// 对应 Bun: Blob.findOrCreateFileFromPath()
    public static func findOrCreateFileFromPath(pathOrFd: PathOrFileDescriptor, global: JsGlobalObject, checkS3: Bool): Blob {
        let allocator = "default"
        if (pathOrFd.isFd) {
            let store = BlobStore(fd: pathOrFd.fd, mimeType: "")
            return initWithStore(store, global: global)
        }
        let pathStr = pathOrFd.path
        if (checkS3 && pathStr.startsWith("s3://")) {
            // S3 路径处理
            let store = BlobStore()
            store.kind = BlobStoreKind.S3
            store.filePath = pathStr
            return initWithStore(store, global: global)
        }
        let store = BlobStore(filePath: pathStr, mimeType: "")
        return initWithStore(store, global: global)
    }

    // ========================================================================
    // 属性访问
    // ========================================================================

    /// 获取共享视图
    /// 对应 Bun: Blob.sharedView()
    public func sharedView(): Array<UInt8> {
        match (store) {
            case Some(s) => {
                if (s.kind == BlobStoreKind.Memory) {
                    let view = s.sharedView()
                    if (offset > 0 || size < Int64(view.length)) {
                        let start = offset
                        let end = if (size > 0) { offset + size } else { Int64(view.length) }
                        let result = ArrayList<UInt8>()
                        for (i in start..end) {
                            if (i < Int64(view.length)) {
                                result.append(view[Int64(i)])
                            }
                        }
                        return result.toArray()
                    }
                    return view
                }
                return Array<UInt8>()
            }
            case None => return Array<UInt8>()
        }
    }

    /// 获取内容类型
    /// 对应 Bun: Blob.getContentType()
    public func getContentType(): ?String {
        if (contentType.length > 0) {
            return Some(contentType)
        }
        match (store) {
            case Some(s) => {
                if (s.mimeType.length > 0) {
                    return Some(s.mimeType)
                }
            }
            case None => ()
        }
        return None
    }

    /// 获取内容类型或 MIME 类型
    /// 对应 Bun: Blob.contentTypeOrMimeType()
    public func contentTypeOrMimeType(): ?String {
        if (contentType.length > 0) {
            return contentType
        }
        match (store) {
            case Some(s) => {
                match (s.kind) {
                    case BlobStoreKind.File => {
                        if (s.mimeType.length > 0) {
                            return s.mimeType
                        }
                    }
                    case BlobStoreKind.S3 => {
                        if (s.mimeType.length > 0) {
                            return s.mimeType
                        }
                    }
                    case BlobStoreKind.Memory => ()
                }
            }
            case None => ()
        }
        return None
    }

    /// 返回裸内容类型字符串
    /// 对应 Bun: Blob.contentType()
    public func contentTypeStr(): String {
        return contentType
    }

    /// 判断是否为 Bun.file() 创建的文件 Blob
    /// 对应 Bun: Blob.isBunFile()
    public func isBunFile(): Bool {
        match (store) {
            case Some(s) => s.kind == BlobStoreKind.File
            case None => false
        }
    }

    /// 判断是否为 S3 Blob
    /// 对应 Bun: Blob.isS3()
    public func isS3(): Bool {
        match (store) {
            case Some(s) => s.kind == BlobStoreKind.S3
            case None => false
        }
    }

    /// 判断是否需要读取文件
    /// 对应 Bun: Blob.needsToReadFile()
    public func needsToReadFile(): Bool {
        match (store) {
            case Some(s) => s.kind == BlobStoreKind.File || s.kind == BlobStoreKind.S3
            case None => false
        }
    }

    /// 判断 Blob 是否已分离
    /// 对应 Bun: Blob.isDetached()
    public func isDetached(): Bool {
        return store == None
    }

    /// 检查内容类型是否由用户设置
    /// 对应 Bun: Blob.hasContentTypeFromUser()
    public func hasContentTypeFromUser(): Bool {
        if (contentTypeWasSet) {
            return true
        }
        match (store) {
            case Some(s) => s.kind == BlobStoreKind.File || s.kind == BlobStoreKind.S3
            case None => false
        }
    }

    /// 分离 Blob（释放存储引用）
    /// 对应 Bun: Blob.detach()
    public func detach(): Unit {
        match (store) {
            case Some(s) => s.deref()
            case None => ()
        }
        store = None
        size = 0
        offset = 0
    }

    // ========================================================================
    // 复制操作
    // ========================================================================

    /// 复制 Blob
    /// 对应 Bun: Blob.dupe()
    public func dupe(): Blob {
        let newBlob = Blob()
        newBlob.size = size
        newBlob.offset = offset
        newBlob.store = store
        newBlob.contentType = contentType
        newBlob.contentTypeAllocated = contentTypeAllocated
        newBlob.contentTypeWasSet = contentTypeWasSet
        newBlob.charset = charset
        newBlob.isJsdomFile = isJsdomFile
        newBlob.lastModified = lastModified
        newBlob.name = name
        newBlob.globalThis = globalThis
        newBlob.reportedEstimatedSize = reportedEstimatedSize
        match (store) {
            case Some(s) => s.ref()
            case None => ()
        }
        return newBlob
    }

    /// 带内容类型复制
    /// 对应 Bun: Blob.dupeWithContentType()
    public func dupeWithContentType(keepContentType: Bool): Blob {
        let newBlob = dupe()
        if (keepContentType) {
            newBlob.contentType = contentType
            newBlob.contentTypeWasSet = contentTypeWasSet
        }
        return newBlob
    }

    // ========================================================================
    // 大小管理
    // ========================================================================

    /// 解析大小（确保 size 已确定）
    /// 对应 Bun: Blob.resolveSize()
    public func resolveSize(): Unit {
        match (store) {
            case Some(s) => {
                if (s.kind == BlobStoreKind.Memory && size == 0) {
                    size = Int64(s.bytes.length)
                }
            }
            case None => ()
        }
    }

    /// 获取绑定层大小
    /// 对应 Bun: Blob.getSizeForBindings()
    public func getSizeForBindings(): BlobSizeType {
        resolveSize()
        return size
    }

    /// 计算估算内存大小
    /// 对应 Bun: Blob.calculateEstimatedByteSize()
    public func calculateEstimatedByteSize(): Unit {
        var sz: Int64 = 0
        match (store) {
            case Some(s) => {
                match (s.kind) {
                    case BlobStoreKind.Memory => {
                        sz += Int64(s.storedName.length)
                        if (size != Blob.maxSize()) {
                            sz += size
                        } else {
                            sz += Int64(s.bytes.length)
                        }
                    }
                    case BlobStoreKind.File => {
                        sz += Int64(s.filePath.length)
                    }
                    case BlobStoreKind.S3 => {
                        sz += Int64(s.filePath.length)
                    }
                }
            }
            case None => ()
        }
        reportedEstimatedSize = sz + Int64(if (contentTypeAllocated) { contentType.length } else { 0 }) + Int64(name.length)
    }

    /// 获取估算大小
    /// 对应 Bun: Blob.estimatedSize()
    public func estimatedSize(): Int64 {
        return reportedEstimatedSize
    }

    // ========================================================================
    // FormData 编码
    // ========================================================================

    /// 获取 FormData 编码
    /// 对应 Bun: Blob.getFormDataEncoding()
    public func getFormDataEncoding(): ?FormDataEncoding {
        let ct = getContentType() ?? ""
        if (ct.length == 0) {
            return None
        }
        if (ct.contains("application/x-www-form-urlencoded")) {
            return Some(FormDataEncoding.URLEncoded)
        }
        if (ct.contains("multipart/form-data")) {
            let boundaryIdx = ct.indexOf("boundary=")
            if (boundaryIdx >= 0) {
                let start = boundaryIdx + 9
                if (start < ct.length) {
                    let boundary = ct.substring(start)
                    return Some(FormDataEncoding.Multipart(boundary))
                }
            }
        }
        return None
    }

    // ========================================================================
    // 数据转换 API
    // ========================================================================

    /// 将 Blob 数据转为字符串 (text())
    /// 对应 Bun: Blob.toString()
    public func toString(): String {
        let bytes = sharedView()
        return Utf8Codec.decode(bytes)
    }

    /// 将 Blob 转为 JSON 字符串 (JsValue)
    /// 对应 Bun: Blob.toJSON()
    public func toJSON(): JsValue {
        let text = toString()
        return JsValue(BaoString(text))
    }

    /// 将 Blob 数据转为 ArrayBuffer (字节数组)
    /// 对应 Bun: Blob.toArrayBuffer()
    public func toArrayBuffer(): Array<UInt8> {
        return sharedView()
    }

    /// 将 Blob 转为 Uint8Array
    /// 对应 Bun: Blob.toUint8Array()
    public func toUint8Array(): Array<UInt8> {
        return sharedView()
    }

    /// 将 Blob 转为 FormData
    /// 对应 Bun: Blob.toFormData()
    public func toFormData(): JsValue {
        // FormData 解析需要完整的 multipart/URL-encoded 解码器
        // 这里返回基本实现
        let encoding = getFormDataEncoding()
        if (encoding == None) {
            return JsValue()
        }
        // TODO: 实现 FormData 解析
        return JsValue()
    }

    // ========================================================================
    // slice — 创建 Blob 的子视图
    // 对应 Bun: Blob.slice (via JS binding)
    // ========================================================================

    /// slice — 创建 Blob 的子范围副本
    /// 对应 Web API: Blob.slice(start, end, contentType)
    public func slice(start: Int64, end: Int64, contentType: String): Blob {
        resolveSize()
        let s = if (start < 0) { max(size + start, 0) } else { start }
        let e = if (end < 0) { max(size + end, 0) } else if (end > size) { size } else { end }
        let newOffset = offset + s
        let newSize = if (e > s) { e - s } else { 0 }
        let newBlob = Blob()
        newBlob.size = newSize
        newBlob.offset = newOffset
        newBlob.store = store
        newBlob.contentType = contentType
        newBlob.contentTypeWasSet = contentType.length > 0
        newBlob.globalThis = globalThis
        match (store) {
            case Some(st) => st.ref()
            case None => ()
        }
        return newBlob
    }

    // ========================================================================
    // 释放 Blob 资源
    // ========================================================================

    /// 释放 Blob 资源
    /// 对应 Bun: Blob.deinit()
    public func deinit(): Unit {
        match (store) {
            case Some(s) => s.deref()
            case None => ()
        }
        store = None
        size = 0
        offset = 0
        if (contentTypeAllocated) {
            contentType = ""
            contentTypeAllocated = false
        }
        contentType = ""
        name = ""
    }

    // ========================================================================
    // 存在性检查
    // ========================================================================

    /// 同步检查文件是否存在
    /// 对应 Bun: Blob.getExistsSync()
    public func getExistsSync(): Bool {
        if (size == Blob.maxSize()) {
            resolveSize()
        }
        match (store) {
            case None => return true  // 空 Blob 存在
            case Some(s) => {
                match (s.kind) {
                    case BlobStoreKind.Memory => return true
                    case BlobStoreKind.File => {
                        // 检查是否为常规文件或管道
                        return (s.fileMode & 0xF000) == 0x8000 || (s.fileMode & 0xF000) == 0x1000
                    }
                    case BlobStoreKind.S3 => return true
                }
            }
        }
    }

    // ========================================================================
    // 从 URLSearchParams 创建
    // 对应 Bun: Blob.fromURLSearchParams
    // ========================================================================

    public static func fromURLSearchParams(global: JsGlobalObject, searchParams: String): Blob {
        let store = BlobStore(bytes: Utf8Codec.encode(searchParams))
        store.mimeType = "application/x-www-form-urlencoded"
        let blob = initWithStore(store, global: global)
        blob.contentType = store.mimeType
        blob.contentTypeWasSet = true
        return blob
    }

    // ========================================================================
    // 从 DOMFormData 创建
    // 对应 Bun: Blob.fromDOMFormData
    // ========================================================================

    public static func fromDOMFormData(global: JsGlobalObject, formData: String, boundary: String): Blob {
        let store = BlobStore(bytes: Utf8Codec.encode(formData))
        let blob = initWithStore(store, global: global)
        blob.contentType = "multipart/form-data; boundary=${boundary}"
        blob.contentTypeAllocated = true
        blob.contentTypeWasSet = true
        return blob
    }

    // ========================================================================
    // getStream — 获取 ReadableStream
    // 对应 Bun: Blob.getStream
    // ========================================================================

    public func getStream(global: JsGlobalObject, chunkSize: Int64): JsValue {
        // 创建一个从 Blob 数据读取的 ReadableStream
        let stream = ReadableStream.fromBlob(global, blob: this, chunkSize: chunkSize)
        return stream.toJsValue()
    }

    // ========================================================================
    // JS Promise 包装的数据获取方法
    // 对应 Bun: Blob.getText, Blob.getJSON, Blob.getArrayBuffer, etc.
    // ========================================================================

    /// getText — 异步获取文本
    /// 对应 Bun: Blob.getText()
    public func getText(global: JsGlobalObject): JsValue {
        let s = store
        if (s != None) {
            s.getOrThrow().ref()
        }
        let self = this
        return JsPromise.wrap(global) { =>
            let bytes = self.sharedView()
            let text = Utf8Codec.decode(bytes)
            if (s != None) {
                s.getOrThrow().deref()
            }
            JsValue(BaoString(text))
        }
    }

    /// getJSON — 异步获取 JSON
    /// 对应 Bun: Blob.getJSON()
    public func getJSON(global: JsGlobalObject): JsValue {
        let s = store
        if (s != None) {
            s.getOrThrow().ref()
        }
        let self = this
        return JsPromise.wrap(global) { =>
            let text = self.toString()
            if (s != None) {
                s.getOrThrow().deref()
            }
            JsValue(BaoString(text))
        }
    }

    /// getArrayBuffer — 异步获取 ArrayBuffer
    /// 对应 Bun: Blob.getArrayBuffer()
    public func getArrayBuffer(global: JsGlobalObject): JsValue {
        let s = store
        if (s != None) {
            s.getOrThrow().ref()
        }
        let self = this
        return JsPromise.wrap(global) { =>
            let bytes = self.sharedView()
            if (s != None) {
                s.getOrThrow().deref()
            }
            JsValue.fromArrayBuffer(global, bytes)
        }
    }

    /// getBytes — 异步获取 Uint8Array
    /// 对应 Bun: Blob.getBytes()
    public func getBytes(global: JsGlobalObject): JsValue {
        let s = store
        if (s != None) {
            s.getOrThrow().ref()
        }
        let self = this
        return JsPromise.wrap(global) { =>
            let bytes = self.sharedView()
            if (s != None) {
                s.getOrThrow().deref()
            }
            JsValue.fromUint8Array(global, bytes)
        }
    }

    /// getFormData — 异步获取 FormData
    /// 对应 Bun: Blob.getFormData()
    public func getFormData(global: JsGlobalObject): JsValue {
        let s = store
        if (s != None) {
            s.getOrThrow().ref()
        }
        let self = this
        return JsPromise.wrap(global) { =>
            if (s != None) {
                s.getOrThrow().deref()
            }
            self.toFormData()
        }
    }

    // ========================================================================
    // 写入操作
    // ========================================================================

    /// doWrite — Blob 实例的 write 方法
    /// 对应 Bun: Blob.doWrite()
    public func doWrite(global: JsGlobalObject, data: JsValue, options: JsValue): JsValue {
        // 验证 Blob 可写
        let s = store
        if (s == None) {
            return JsPromise.reject(global, JsValue(BaoString("Cannot write to a detached Blob")))
        }
        if (s.getOrThrow().kind == BlobStoreKind.Memory) {
            return JsPromise.reject(global, JsValue(BaoString("Cannot write to a Blob backed by bytes, which are always read-only")))
        }
        // 使用 writeFileInternal 实现
        return Blob.writeFile(global, data: data, destination: this, options: options)
    }

    /// writeFile — 静态写入方法（Bun.write）
    /// 对应 Bun: Blob.writeFile()
    public static func writeFile(global: JsGlobalObject, data: JsValue, destination: Blob, options: JsValue): JsValue {
        // 简化实现：同步写入
        let bytes = data.toArrayBuffer()
        if (bytes == None) {
            return JsPromise.reject(global, JsValue(BaoString("Bun.write(pathOrFdOrBlob, blob) expects a Blob-y thing to write")))
        }
        match (destination.store) {
            case Some(s) => {
                match (s.kind) {
                    case BlobStoreKind.File => {
                        if (s.isFd) {
                            System.writeFd(s.fileFd, buffer: bytes!, offset: 0, length: Int64(bytes.getOrThrow().length), position: -1)
                        } else {
                            System.writeFile(s.filePath, data: bytes.getOrThrow())
                        }
                        return JsPromise.resolve(global, JsValue(Int64(bytes.getOrThrow().length)))
                    }
                    case BlobStoreKind.S3 => {
                        // S3 写入需要异步上传
                        return JsPromise.resolve(global, JsValue(Int64(bytes.getOrThrow().length)))
                    }
                    case BlobStoreKind.Memory => {
                        return JsPromise.reject(global, JsValue(BaoString("Cannot write to a Blob backed by bytes")))
                    }
                }
            }
            case None => {
                return JsPromise.reject(global, JsValue(BaoString("Blob is detached")))
            }
        }
    }

    // ========================================================================
    // File 构造函数
    // 对应 Bun: JSDOMFile__construct
    // ========================================================================

    /// constructFile — File 构造函数
    /// 对应 Bun: Blob.JSDOMFile__construct_
    public static func constructFile(global: JsGlobalObject, bits: Array<UInt8>, fileName: String, fileType: String, lastModified: Float64): Blob {
        let store = BlobStore(bytes: bits, storedName: fileName)
        let blob = Blob(store: store, offset: 0, Int64(bits.length))
        blob.isJsdomFile = true
        blob.globalThis = Some(global)
        if (fileType.length > 0) {
            blob.contentType = fileType
            blob.contentTypeWasSet = true
        }
        if (lastModified != 0.0) {
            blob.lastModified = lastModified
        } else {
            blob.lastModified = Float64(System.currentTimeMillis())
        }
        return newHeap(blob)
    }

    /// constructBunFile — Bun.file() 构造函数
    /// 对应 Bun: Blob.constructBunFile
    public static func constructBunFile(global: JsGlobalObject, path: PathOrFileDescriptor, options: JsValue): JsValue {
        let blob = findOrCreateFileFromPath(path, global: global, checkS3: true)

        // 解析选项
        if (!options.isNull() && !options.isUndefined()) {
            let typeVal = options.get("type")
            if (typeVal != None && typeVal.getOrThrow().isString()) {
                let typeStr = typeVal.getOrThrow().toString()
                if (isAllAscii(typeStr)) {
                    blob.contentType = typeStr.toLowerAscii()
                    blob.contentTypeWasSet = true
                }
            }
            let lmVal = options.get("lastModified")
            if (lmVal != None && lmVal.getOrThrow().isNumber()) {
                blob.lastModified = lmVal.getOrThrow().toFloat64()
            }
        }

        let ptr = newHeap(blob)
        return ptr.toJsValue()
    }

    // ========================================================================
    // 格式化输出
    // ========================================================================

    /// 写格式化输出
    /// 对应 Bun: Blob.writeFormat
    public func writeFormat(isFile: Bool, size: Int64): String {
        let typeName = if (isFile) { "File" } else { "Blob" }
        let sizeStr = formatSize(size)
        return "${typeName} (${sizeStr})"
    }

    // ========================================================================
    // JS 绑定
    // ========================================================================

    /// 将 Blob 转为 JsValue
    public func toJsValue(): JsValue {
        let global = globalThis
        if (global == None) {
            return JsValue()
        }
        return toJsValue(global.getOrThrow())
    }

    /// 将 Blob 转为 JsValue（带全局对象）
    public func toJsValue(global: JsGlobalObject): JsValue {
        let obj = JsObject(global)
        let self = this

        obj.set("size", JsValue(Float64(self.getSizeForBindings())))
        obj.set("type", JsValue(BaoString(self.contentType)))

        // slice 方法
        obj.set("slice", JsValue.nativeFunction(JsNativeFunction("slice") { args =>
            let start = if (args.length > 0) { args[0].toInt64() } else { 0 }
            let end = if (args.length > 1) { args[1].toInt64() } else { self.size }
            let ct = if (args.length > 2) { args[2].toString() } else { "" }
            let sliced = self.slice(start, end: end, contentType: ct)
            sliced.globalThis = self.globalThis
            sliced.toJsValue(global)
        }))

        // text 方法
        obj.set("text", JsValue.nativeFunction(JsNativeFunction("text") { _ =>
            self.getText(global)
        }))

        // arrayBuffer 方法
        obj.set("arrayBuffer", JsValue.nativeFunction(JsNativeFunction("arrayBuffer") { _ =>
            self.getArrayBuffer(global)
        }))

        // json 方法
        obj.set("json", JsValue.nativeFunction(JsNativeFunction("json") { _ =>
            self.getJSON(global)
        }))

        // bytes 方法
        obj.set("bytes", JsValue.nativeFunction(JsNativeFunction("bytes") { _ =>
            self.getBytes(global)
        }))

        // stream 方法
        obj.set("stream", JsValue.nativeFunction(JsNativeFunction("stream") { args =>
            let chunkSize = if (args.length > 0) { args[0].toInt64() } else { 0 }
            self.getStream(global, chunkSize: chunkSize)
        }))

        // formData 方法
        obj.set("formData", JsValue.nativeFunction(JsNativeFunction("formData") { _ =>
            self.getFormData(global)
        }))

        // exists (getter for BunFile)
        if (self.isBunFile()) {
            obj.set("exists", JsValue.nativeFunction(JsNativeFunction("exists") { _ =>
                JsValue(self.getExistsSync())
            }))
        }

        // write 方法 (BunFile)
        if (self.isBunFile()) {
            obj.set("write", JsValue.nativeFunction(JsNativeFunction("write") { args =>
                if (args.length < 1) {
                    return JsPromise.reject(global, JsValue(BaoString("blob.write(data) expects data")))
                }
                let options = if (args.length > 1) { args[1] } else { JsValue() }
                self.doWrite(global, data: args[0], options: options)
            }))
        }

        // File 属性
        if (self.isJsdomFile) {
            obj.set("name", JsValue(BaoString(self.name)))
            obj.set("lastModified", JsValue(self.lastModified))
        }

        return JsValue(obj)
    }

    /// 从 JS 值构造 Blob
    /// 对应 Bun: Blob.get() — 从 JS 参数构造
    public static func get(global: JsGlobalObject, value: JsValue, isBlob: Bool, isFile: Bool): Blob {
        // 处理不同类型的输入
        if (value.isArray()) {
            // Array of BlobParts
            let parts = value.toArray()
            let allBytes = ArrayList<UInt8>()
            for (part in parts) {
                if (part.isString()) {
                    let encoded = Utf8Codec.encode(part.toString())
                    for (b in encoded) {
                        allBytes.append(b)
                    }
                } else if (part.isArrayBuffer()) {
                    let bytes = part.toArrayBuffer()
                    for (b in bytes) {
                        allBytes.append(b)
                    }
                }
            }
            let blob = Blob(bytes: allBytes.toArray(), contentType: "")
            blob.globalThis = Some(global)
            return blob
        }
        if (value.isString()) {
            let encoded = Utf8Codec.encode(value.toString())
            let blob = Blob(bytes: encoded, contentType: "")
            blob.globalThis = Some(global)
            return blob
        }
        if (value.isArrayBuffer()) {
            let bytes = value.toArrayBuffer()
            let blob = Blob(bytes: bytes, contentType: "")
            blob.globalThis = Some(global)
            return blob
        }
        // 空默认
        let blob = Blob()
        blob.globalThis = Some(global)
        return blob
    }
}

// ============================================================================
// CharsetKind — 字符集状态
// 对应 Bun: strings.AsciiStatus
// ============================================================================
public enum CharsetKind {
    | unknown
    | ascii
    | utf16
}

// ============================================================================
// FormDataEncoding — FormData 编码类型
// 对应 Bun: FormData.Encoding
// ============================================================================
public enum FormDataEncoding {
    | URLEncoded                     // application/x-www-form-urlencoded
    | Multipart(String)              // multipart/form-data; boundary=...

    /// 从 Content-Type 字符串解析编码
    /// 对应 Bun: FormData.Encoding.get()
    public static func fromContentType(contentType: String): ?FormDataEncoding {
        if (contentType.contains("application/x-www-form-urlencoded")) {
            return Some(FormDataEncoding.URLEncoded)
        }
        if (contentType.contains("multipart/form-data")) {
            let boundaryIdx = contentType.indexOf("boundary=")
            if (boundaryIdx >= 0) {
                let start = boundaryIdx + 9
                if (start < contentType.length) {
                    let rest = contentType.substring(start)
                    let endIdx = rest.indexOf(";")
                    let boundary = if (endIdx >= 0) { rest.substring(0, endIdx) } else { rest }
                    if (boundary.length > 0) {
                        return Some(FormDataEncoding.Multipart(boundary))
                    }
                }
            }
        }
        return None
    }
}

// ============================================================================
// PathOrBlob — Bun.write() 参数联合类型
// 对应 Bun: PathOrBlob
// ============================================================================
public class PathOrBlob {
    public var isPath: Bool = true
    public var path: PathOrFileDescriptor
    public var blob: Blob

    public init(path: PathOrFileDescriptor) {
        this.isPath = true
        this.path = path
        this.blob = Blob()
    }

    public init(blob: Blob) {
        this.isPath = false
        this.path = PathOrFileDescriptor(fd: -1)
        this.blob = blob
    }
}

// ============================================================================
// ReadableStream — 简化的 ReadableStream
// 对应 Bun: jsc.WebCore.ReadableStream
// ============================================================================
public class ReadableStream {
    public static func fromBlob(global: JsGlobalObject, blob: Blob, chunkSize: Int64): ReadableStream {
        return ReadableStream(global: global, blob: blob, chunkSize: chunkSize)
    }

    public static func fromBlobCopyRef(global: JsGlobalObject, blob: Blob, chunkSize: Int64): ?ReadableStream {
        return ReadableStream(global: global, blob: blob.dupe(), chunkSize: chunkSize)
    }

    public static func fromFileBlobWithOffset(global: JsGlobalObject, blob: Blob, offset: Int64): ReadableStream {
        let stream = ReadableStream(global: global, blob: blob.dupe(), chunkSize: 0)
        stream.offset = offset
        return stream
    }

    public var global: JsGlobalObject
    public var blob: Blob
    public var chunkSize: Int64
    public var offset: Int64 = 0

    public init(global: JsGlobalObject, blob: Blob, chunkSize: Int64) {
        this.global = global
        this.blob = blob
        this.chunkSize = chunkSize
    }

    public func toJsValue(): JsValue {
        let obj = JsObject(global)
        let self = this
        obj.set("getReader", JsValue.nativeFunction(JsNativeFunction("getReader") { _ =>
            self.toReaderJsValue()
        }))
        return JsValue(obj)
    }

    public func toReaderJsValue(): JsValue {
        let obj = JsObject(global)
        let self = this
        obj.set("read", JsValue.nativeFunction(JsNativeFunction("read") { _ =>
            // 简化实现：一次读取全部
            let bytes = self.blob.sharedView()
            let result = JsObject(self.global)
            result.set("value", JsValue.fromUint8Array(self.global, bytes))
            result.set("done", JsValue(false))
            JsValue(result)
        }))
        return JsValue(obj)
    }
}

// ============================================================================
// JsPromise — Promise 辅助
// 对应 Bun: jsc.JSPromise
// ============================================================================
public class JsPromise {
    public static func wrap(global: JsGlobalObject, work: () -> JsValue): JsValue {
        // 简化实现：立即执行
        let result = work()
        return resolve(global, result)
    }

    public static func resolve(global: JsGlobalObject, value: JsValue): JsValue {
        let obj = JsObject(global)
        obj.set("then", JsValue.nativeFunction(JsNativeFunction("then") { args =>
            if (args.length > 0 && args[0].isFunction()) {
                args[0].call(Array<JsValue>([value]))
            }
            JsValue(obj)
        }))
        return JsValue(obj)
    }

    public static func reject(global: JsGlobalObject, error: JsValue): JsValue {
        let obj = JsObject(global)
        obj.set("then", JsValue.nativeFunction(JsNativeFunction("then") { _ =>
            JsValue(obj)
        }))
        obj.set("catch", JsValue.nativeFunction(JsNativeFunction("catch") { args =>
            if (args.length > 0 && args[0].isFunction()) {
                args[0].call(Array<JsValue>([error]))
            }
            JsValue(obj)
        }))
        return JsValue(obj)
    }
}

// ============================================================================
// 工具函数
// ============================================================================

/// 检查字符串是否全为 ASCII
public func isAllAscii(s: String): Bool {
    for (c in s) {
        if (Int32(c) > 127) {
            return false
        }
    }
    return true
}

/// 格式化文件大小
public func formatSize(bytes: Int64): String {
    if (bytes < 1024) {
        return "${bytes} B"
    }
    if (bytes < 1024 * 1024) {
        let kb = Float64(bytes) / 1024.0
        return "${kb.toFixed(1)} KB"
    }
    if (bytes < 1024 * 1024 * 1024) {
        let mb = Float64(bytes) / (1024.0 * 1024.0)
        return "${mb.toFixed(1)} MB"
    }
    if (bytes < 1024LL * 1024LL * 1024LL * 1024LL) {
        let gb = Float64(bytes) / (1024.0 * 1024.0 * 1024.0)
        return "${gb.toFixed(1)} GB"
    }
    let tb = Float64(bytes) / (1024.0 * 1024.0 * 1024.0 * 1024.0)
    return "${tb.toFixed(1)} TB"
}
