// Blob - 二进制大对象实现
// 对应 Bun: src/runtime/webcore/Blob.zig
// 严格翻译自: src/runtime/webcore/Blob.zig
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// Blob.SizeType - Blob 大小类型
// 对应 Bun: Blob.SizeType (u52)
// ============================================================================

/// Blob 大小类型
/// 对应 Bun: Blob.SizeType = u52
public type BlobSizeType = Int64

// ============================================================================
// Blob.Store - Blob 底层存储
// 对应 Bun: Blob.Store
// ============================================================================

/// Blob 存储类型枚举
/// 对应 Bun: Blob.Store.Data
public enum BlobStoreKind {
    | Memory    // 内存中的字节数据
    | File      // 文件系统引用
    | S3        // S3 对象存储引用
}

/// Blob 底层存储
/// 对应 Bun: Blob.Store
public class BlobStore {
    /// 存储类型
    public var kind: BlobStoreKind
    /// 内存数据
    public var bytes: Array<UInt8>
    /// 文件路径 (File 类型)
    public var filePath: String
    /// MIME 类型
    public var mimeType: String
    /// 引用计数
    public var refCount: Int64

    public init() {
        kind = BlobStoreKind.Memory
        bytes = Array<UInt8>()
        filePath = ""
        mimeType = ""
        refCount = 1
    }

    public init(bytes: Array<UInt8>) {
        kind = BlobStoreKind.Memory
        this.bytes = bytes
        filePath = ""
        mimeType = ""
        refCount = 1
    }

    public init(filePath: String, mimeType: String) {
        kind = BlobStoreKind.File
        bytes = Array<UInt8>()
        this.filePath = filePath
        this.mimeType = mimeType
        refCount = 1
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
        }
    }

    /// 获取共享视图（内存数据的只读引用）
    /// 对应 Bun: Blob.Store.sharedView()
    public func sharedView(): Array<UInt8> {
        return bytes
    }
}

// ============================================================================
// Blob - 二进制大对象
// 对应 Bun: src/runtime/webcore/Blob.zig Blob
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/Blob
// ============================================================================

/// Blob — 二进制大对象
/// 对应 Web API: Blob
/// 对应 Bun: src/runtime/webcore/Blob.zig Blob
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
    /// 最后修改时间
    /// 对应 Bun: Blob.last_modified
    public var lastModified: Float64
    /// Blob 名称
    /// 对应 Bun: Blob.name
    public var name: String

    public init() {
        size = 0
        offset = 0
        store = None
        contentType = ""
        contentTypeAllocated = false
        contentTypeWasSet = false
        lastModified = 0.0
        name = ""
    }

    public init(bytes: Array<UInt8>, contentType: String) {
        let store = BlobStore(bytes)
        this.size = bytes.size
        this.offset = 0
        this.store = Some(store)
        this.contentType = contentType
        this.contentTypeAllocated = false
        this.contentTypeWasSet = contentType.length > 0
        this.lastModified = 0.0
        this.name = ""
    }

    public init(store: BlobStore, offset: BlobSizeType, size: BlobSizeType) {
        this.size = size
        this.offset = offset
        this.store = Some(store)
        this.contentType = store.mimeType
        this.contentTypeAllocated = false
        this.contentTypeWasSet = false
        this.lastModified = 0.0
        this.name = ""
    }

    /// 最大大小 (约 4.5 PB)
    /// 对应 Bun: Blob.max_size
    public static let maxSize: BlobSizeType = 4503599627370495  // 2^52 - 1

    /// 获取共享视图
    /// 对应 Bun: Blob.sharedView()
    public func sharedView(): Array<UInt8> {
        match (store) {
            case Some(s) => {
                if (s.kind == BlobStoreKind.Memory) {
                    let view = s.sharedView()
                    if (offset > 0 || size < view.size) {
                        let start = offset
                        let end = if (size > 0) { offset + size } else { view.size }
                        // 返回子切片的拷贝
                        let result = ArrayList<UInt8>()
                        for (i in start..end) {
                            if (i < view.size) {
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

    /// 判断是否为 Bun.file() 创建的文件 Blob
    /// 对应 Bun: Blob.isBunFile()
    public func isBunFile(): Bool {
        match (store) {
            case Some(s) => s.kind == BlobStoreKind.File
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
        newBlob.lastModified = lastModified
        newBlob.name = name
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

    /// 解析大小（确保 size 已确定）
    /// 对应 Bun: Blob.resolveSize()
    public func resolveSize(): Unit {
        match (store) {
            case Some(s) => {
                if (s.kind == BlobStoreKind.Memory && size == 0) {
                    size = s.bytes.size
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
            // 提取 boundary
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

    /// 将 Blob 数据转为字符串
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
        contentType = ""
    }

    /// 创建空 Blob
    /// 对应 Bun: Blob.initEmpty()
    public static func initEmpty(): Blob {
        return Blob()
    }

    /// 从字节数组创建 Blob
    /// 对应 Bun: Blob.init()
    public static func init(bytes: Array<UInt8>, allocator: String, global: String): Blob {
        let store = BlobStore(bytes)
        let blob = Blob(store, 0, bytes.size)
        return blob
    }

    /// 从指定 Store 创建 Blob
    /// 对应 Bun: Blob.initWithStore()
    public static func initWithStore(store: BlobStore, global: String): Blob {
        store.ref()
        let blob = Blob(store, 0, store.bytes.size)
        return blob
    }

    /// 将 Blob 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("size", JsValue(Float64(self.getSizeForBindings())))
        obj.set("type", JsValue(BaoString(self.contentType)))

        obj.set("text", JsValue.nativeFunction(JsNativeFunction("text") { _ =>
            JsValue(BaoString(self.toString()))
        }))

        obj.set("arrayBuffer", JsValue.nativeFunction(JsNativeFunction("arrayBuffer") { _ =>
            let bytes = self.sharedView()
            let arr = ArrayList<JsValue>()
            for (b in bytes) {
                arr.append(JsValue(Float64(Int64(b))))
            }
            JsValue.array(arr)
        }))

        obj.set("json", JsValue.nativeFunction(JsNativeFunction("json") { _ =>
            self.toJSON()
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// FormDataEncoding - FormData 编码类型
// 对应 Bun: FormData.Encoding
// ============================================================================

/// FormData 编码类型
/// 对应 Bun: FormData.Encoding
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
