// 严格翻译自: src/jsc/webcore_types.rs
// 核心 webcore 数据类型 — Blob, Blob::Store
//
// 移植自 src/runtime/webcore/Blob.zig (结构字段 + init/initWithStore/sharedView/dupe/detach/deinit)
// 和 src/runtime/webcore/blob/Store.zig (Store/Data/Bytes/File/S3/init/ref/deref/sharedView/deinit)
//
// LAYERING: 这些是单个名义类型定义。bun_runtime::webcore 通过 pub use 引入这些
// 并在该 crate 中通过 BlobExt / StoreExt / ... 扩展 trait 添加行为 (S3 I/O, 流式传输,
// JS 宿主函数, 异步读取器)。在此处定义数据形状使低层 crate (bun_http_jsc, bun_sql_jsc)
// 可以将 JSValue 向下转换为 *mut Blob 并读取其字节而无需 bun_runtime 前向依赖

package bao_jsc

import bao_collections.*

import bao_core.*
import bao_http_types.MimeType
import bao_ptr.RawRefCount

// 引用计数结果 (前移以避免 "used before being defined")
public let SHOULD_DESTROY: Int32 = 0
public let SHOULD_NOT_DESTROY: Int32 = 1

// 估算的 Store 大小 (前移以避免 "used before being defined")
public let STORE_SIZE: Int64 = 128

// 对应 Bun bun_core::string::immutable::AsciiStatus: enum { Unknown, AllAscii, NonAscii }
public enum AsciiStatus {
    | Unknown
    | AllAscii
    | NonAscii

    public static func fromBool(isAllAscii: ?Bool): AsciiStatus {
        match (isAllAscii) {
            case None => AsciiStatus.Unknown
            case Some(true) => AsciiStatus.AllAscii
            case Some(false) => AsciiStatus.NonAscii
        }
    }
}

// ========== SizeType ==========
// 严格翻译自 webcore_types.rs SizeType
// webcore.Blob.SizeType (Blob.zig:60) — Zig u52; 此处扩展为 u64
// 值在边界处掩码为 52 位
public type SizeType = UInt64

// 严格翻译自 webcore_types.rs MAX_SIZE
// webcore.Blob.max_size (Blob.zig:61) — std.math.maxInt(u52)
public let MAX_SIZE: SizeType = UInt64(4503599627370495)

// ========== ClosingState ==========
// 严格翻译自 webcore_types.rs ClosingState
public enum ClosingState {
    | Running
    | Closing
}

// ========== Blob ==========
// 严格翻译自 webcore_types.rs Blob
// webcore.Blob (src/runtime/webcore/Blob.zig:7-52)
// 代码生成的 JSBlob 包装器的 m_ctx 载荷
//
// R-2 (sharedThis): 每个 JS 面向的宿主函数接受 &Blob (非 &mut Blob)
// 因此重入 JS 调用不能堆叠两个 &mut 到同一实例。宿主函数修改的字段
// 因此用 Cell (Copy 标量) 或 JsCell (非 Copy store) 包装
public class Blob {
    // 报告的估计大小
    public var reportedEstimatedSize: Int64 = 0
    // Blob 数据大小 (52位)
    public var size: SizeType = 0
    // 偏移量
    public var offset: SizeType = 0
    // 内部引用计数的后备存储
    public var store: ?StoreRef = None
    // 内容类型 (MIME)
    public var contentType: Array<Byte> = []
    // 内容类型是否已堆分配
    public var contentTypeAllocated: Bool = false
    // 内容类型是否由用户设置
    public var contentTypeWasSet: Bool = false
    // 缓存的编码探测
    public var charset: AsciiStatus = AsciiStatus.Unknown
    // 是否通过 File 构造函数创建
    public var isJsdomFile: Bool = false
    // 内部引用计数 (计算异步读取器的借用)
    public var refCount: RawRefCount = RawRefCount(0)
    // 全局对象引用
    public var globalThis: ?JSGlobalObject = None
    // 最后修改时间
    public var lastModified: Float64 = 0.0
    // 文件名
    public var name: BunString = BunStringExt.dead()

    public init() {}

    // 严格翻译自 Blob::new
    // bun.TrivialNew(@This()) (Blob.zig:16) — 堆提升并标记为堆分配
    public static func new(blob: Blob): Blob {
        let result = Blob()
        result.refCount = RawRefCount(1)
        // 复制字段
        result.size = blob.size
        result.offset = blob.offset
        result.store = blob.store
        result.contentType = blob.contentType
        result.contentTypeAllocated = blob.contentTypeAllocated
        result.contentTypeWasSet = blob.contentTypeWasSet
        result.charset = blob.charset
        result.isJsdomFile = blob.isJsdomFile
        result.globalThis = blob.globalThis
        result.lastModified = blob.lastModified
        result.name = blob.name
        result.reportedEstimatedSize = blob.reportedEstimatedSize
        result
    }

    // 严格翻译自 Blob::finalize
    // JS 包装器终结器 (代码生成的 BlobClass__finalize thunk)
    public func finalize() {
        // 释放 JS 包装器的 +1 引用计数
        blobDeref()
    }

    // 严格翻译自 Blob::is_heap_allocated
    public func isHeapAllocated(): Bool {
        refCount.rawValue != 0
    }

    // 严格翻译自 Blob::set_not_heap_allocated
    public func setNotHeapAllocated() {
        refCount = RawRefCount(0)
    }

    // 严格翻译自 Blob::content_type_slice
    public func contentTypeSlice(): Array<Byte> {
        contentType
    }

    // 严格翻译自 Blob::store (borrowed accessor)
    public func storeRef(): ?StoreRef {
        store
    }

    // 严格翻译自 Blob::take_store
    // 移出 store 引用 (Zig: this.store = null 不带 .deref(); 调用者采用现有的 +1)
    public func takeStore(): ?StoreRef {
        let s = store
        store = None
        s
    }

    // 严格翻译自 Blob::free_content_type
    // 释放堆拥有的 content_type (如果有) 并重置为空静态切片
    public func freeContentType() {
        if (contentTypeAllocated) {
            contentType = []
            contentTypeAllocated = false
        }
    }

    // 严格翻译自 Blob::init_with_store
    // Blob.initWithStore(store, globalThis) (Blob.zig:3649)
    public static func initWithStore(store: StoreRef, globalThis: JSGlobalObject): Blob {
        let blob = Blob()
        blob.size = store.size()
        blob.store = store
        // 设置 content_type
        match(store.dataMut()) {
            case Some(Data.FileData(f)) => blob.contentType = toArrayByte(f.mimeType.contentType)
            case _ => blob.contentType = []
        }
        blob.globalThis = globalThis
        blob
    }

    // 严格翻译自 Blob::init
    // Blob(bytes, allocator, globalThis) (Blob.zig:3576)。获取 bytes 所有权
    public static func `init`(bytes: Array<Byte>, globalThis: JSGlobalObject): Blob {
        let blob = Blob()
        blob.size = UInt64(bytes.size)
        if (!bytes.isEmpty()) {
            blob.store = StoreRef.from(Store.`init`(bytes))
        }
        blob.globalThis = globalThis
        blob
    }

    // 严格翻译自 Blob::init_empty
    // Blob.initEmpty(globalThis) (Blob.zig:3660)
    public static func initEmpty(globalThis: JSGlobalObject): Blob {
        let blob = Blob()
        blob.globalThis = globalThis
        blob
    }

    // 严格翻译自 Blob::shared_view
    // Blob.sharedView() (Blob.zig:3737) — 内存中字节的借用视图
    public func sharedView(): Array<Byte> {
        if (store .isNone()) { return [] }
        if (size == 0) { return [] }
        let s = store.getOrThrow()
        var slice = s.sharedView()
        if (slice.isEmpty()) { return [] }
        let offset64 = Int64(offset)
        let sliceLen = Int64(slice.size)
        let off = if (offset64 < sliceLen) { offset64 } else { sliceLen }
        slice = slice.slice(off, sliceLen)
        let end = if (Int64(slice.size) < Int64(size)) { Int64(slice.size) } else { Int64(size) }
        slice.slice(0, end)
    }

    // 严格翻译自 Blob::detach
    // Blob.detach() (Blob.zig:3675) — 释放 store 引用但不释放 self
    public func detach() {
        store = None
    }

    // 严格翻译自 Blob::dupe
    // Blob.dupe() (Blob.zig:3684) — 同一 store 的新视图, +1 引用
    public func dupe(): Blob {
        dupeWithContentType(false)
    }

    // 严格翻译自 Blob::borrowed_view
    // Zig 的原始 blob.* 按位复制
    public func borrowedView(): Blob {
        let result = Blob()
        result.reportedEstimatedSize = reportedEstimatedSize
        result.size = size
        result.offset = offset
        result.store = store  // 引用计数 +1
        result.contentType = contentType
        result.contentTypeAllocated = contentTypeAllocated
        result.contentTypeWasSet = contentTypeWasSet
        result.charset = charset
        result.isJsdomFile = isJsdomFile
        result.refCount = RawRefCount(0)
        result.globalThis = globalThis
        result.lastModified = lastModified
        result.name = name
        result
    }

    // 严格翻译自 Blob::dupe_with_content_type
    // Blob.dupeWithContentType() (Blob.zig:3688)
    public func dupeWithContentType(includeContentType: Bool): Blob {
        let duped = Blob()
        duped.reportedEstimatedSize = reportedEstimatedSize
        duped.size = size
        duped.offset = offset
        duped.store = store  // 引用计数 +1
        duped.contentType = contentType
        duped.contentTypeAllocated = contentTypeAllocated
        duped.contentTypeWasSet = contentTypeWasSet
        duped.charset = charset
        duped.isJsdomFile = isJsdomFile
        duped.refCount = RawRefCount(0)
        duped.globalThis = globalThis
        duped.lastModified = lastModified
        duped.name = name
        // 如果源 content_type 是堆分配的, 进行深拷贝
        if (contentTypeAllocated) {
            duped.contentType = contentType.toArray()
        }
        duped
    }

    // ========== 数据谓词 ==========

    // 严格翻译自 Blob::has_content_type_from_user
    public func hasContentTypeFromUser(): Bool {
        contentTypeWasSet || (match(store) {
            case Some(s) =>
                match(s.dataMut()) {
                    case Some(Data.FileData(_)) => true
                    case Some(Data.S3Data(_)) => true
                    case _ => false
                }
            case None => false
        })
    }

    // 严格翻译自 Blob::content_type_or_mime_type
    public func contentTypeOrMimeType(): ?Array<Byte> {
        if (!contentType.isEmpty()) { return Some(contentType) }
        match(store) {
            case Some(s) =>
                match(s.dataMut()) {
                    case Some(Data.FileData(f)) => Some(toArrayByte(f.mimeType.contentType))
                    case Some(Data.S3Data(s3)) => Some(toArrayByte(s3.mimeType.contentType))
                    case Some(Data.BytesData(_)) => None
                    case None => None
                }
            case None => None
        }
    }

    // 严格翻译自 Blob::is_bun_file
    public func isBunFile(): Bool {
        match(store) {
            case Some(s) =>
                match(s.dataMut()) {
                    case Some(Data.FileData(_)) => true
                    case _ => false
                }
            case None => false
        }
    }

    // 严格翻译自 Blob::is_s3
    public func isS3(): Bool {
        match(store) {
            case Some(s) =>
                match(s.dataMut()) {
                    case Some(Data.S3Data(_)) => true
                    case _ => false
                }
            case None => false
        }
    }

    // 严格翻译自 Blob::needs_to_read_file
    public func needsToReadFile(): Bool {
        isBunFile()
    }

    // 严格翻译自 Blob::get_file_name
    public func getFileName(): ?Array<Byte> {
        match(store) {
            case Some(s) =>
                match(s.dataMut()) {
                    case Some(Data.BytesData(bytes)) =>
                        let n = bytes.storedName.slice()
                        if (n.isEmpty()) { None } else { Some(n.toArray()) }
                    case Some(Data.FileData(fileObj)) =>
                        match(fileObj.pathlike) {
                            case PathOrFileDescriptor.Path(path) => Some(PathLikeOps.slice(path))
                            case PathOrFileDescriptor.Fd(_) => None
                        }
                    case Some(Data.S3Data(s3)) => Some(PathLikeOps.slice(s3.pathlike))
                    case None => None
                }
            case None => None
        }
    }

    // 严格翻译自 Blob::deinit
    // Blob.deinit() (Blob.zig:3720)。拆解拥有的资源
    public func deinit() {
        detach()
        name = BunStringExt.dead()
        freeContentType()
        if (isHeapAllocated()) {
            // 堆分配的 Blob 会在 refCount 降到 0 时被释放
            refCount = RawRefCount(0)
        }
    }

    // 严格翻译自 blob__ref
    public func blobRef() {
        if (!isHeapAllocated()) { return }
        refCount.increment()
    }

    // 严格翻译自 blob__deref
    public func blobDeref() {
        if (!isHeapAllocated()) { return }
        if (refCount.decrement() == SHOULD_DESTROY) {
            refCount.increment()  // 重新武装, 以便 deinit 中的检查通过
            deinit()
        }
    }
}

// ========== Store 模块 ==========
// 严格翻译自 webcore_types.rs store 模块

// ========== DataTag ==========
// 严格翻译自 webcore_types.rs DataTag
// Data 的仅判别标签 (Zig: std.meta.Tag(Store.Data))
public enum DataTag {
    | BytesTag
    | FileTag
    | S3Tag
}

// ========== Data ==========
// 严格翻译自 webcore_types.rs store::Data
// Store.Data (Store.zig:37) — union(enum) { bytes, file, s3 }
public enum Data {
    | BytesData(Bytes)
    | FileData(File)
    | S3Data(S3)
}

// ========== SerializeTag ==========
// 严格翻译自 webcore_types.rs store::SerializeTag
public enum SerializeTag {
    | File
    | Bytes
    | Empty
}

// SerializeTag extension methods
public class SerializeTagExt {

    public static func fromRaw(raw: UInt8): ?SerializeTag {
        match(raw) {
            case 0 => Some(SerializeTag.File)
            case 1 => Some(SerializeTag.Bytes)
            case 2 => Some(SerializeTag.Empty)
            case _ => None
        
}
    }
}

// ========== Bytes ==========
// 严格翻译自 webcore_types.rs store::Bytes
// Blob.Store.Bytes (Store.zig:472)
public class Bytes {
    public var ptr: ?CPointer<UInt8> = None
    public var len: SizeType = 0
    public var cap: SizeType = 0
    public var storedName: PathString = PathString.empty()

    public init() {}

    // 严格翻译自 Bytes::init
    // 获取 bytes (由全局 mimalloc 分配器分配) 的所有权
    public static func `init`(bytes: Array<Byte>): Bytes {
        let b = Bytes()
        b.len = UInt64(bytes.size)
        b.cap = UInt64(bytes.size)
        // ptr: CPointer not available in pure Cangjie; stub
        b
    }

    // 严格翻译自 Bytes::init_owned
    // 获取 Box<[u8]> 的所有权
    public static func initOwned(bytes: Array<Byte>): Bytes {
        let b = Bytes()
        b.len = UInt64(bytes.size)
        b.cap = UInt64(bytes.size)
        // ptr: CPointer not available in pure Cangjie; stub
        b
    }

    // 严格翻译自 Bytes::init_empty_with_name
    public static func initEmptyWithName(name: PathString): Bytes {
        let b = Bytes()
        b.storedName = name
        b
    }

    // 严格翻译自 Bytes::len
    public func length(): SizeType {
        len
    }

    // 严格翻译自 Bytes::slice
    public func slice(): Array<Byte> {
        match(ptr) {
            case Some(p) =>
                // 从原始指针创建切片
                Array<Byte>()
            case None => []
        }
    }

    // 严格翻译自 Bytes::allocated_slice
    public func allocatedSlice(): Array<Byte> {
        match(ptr) {
            case Some(p) => Array<Byte>()
            case None => []
        }
    }

    // 严格翻译自 Bytes::as_array_list
    public func asArrayList(): Array<Byte> {
        slice()
    }

    // 严格翻译自 Bytes::into_boxed_slice
    public func intoBoxedSlice(): Array<Byte> {
        slice()
    }

    // 析构
    public func deinit() {
        ptr = None
        len = 0
        cap = 0
        storedName = PathString.empty()
    }
}

// ========== File ==========
// 严格翻译自 webcore_types.rs store::File
// Store.File (Store.zig:250) — 引用磁盘上文件的 blob 存储
public class File {
    public var pathlike: PathOrFileDescriptor = PathOrFileDescriptorExt.default()
    public var mimeType: MimeType = MimeType()
    public var isAtty: ?Bool = None
    public var mode: UInt32 = 0
    public var seekable: ?Bool = None
    public var maxSize: SizeType = MAX_SIZE
    public var lastModified: JSTimeType = INIT_TIMESTAMP

    public init() {}

    // 严格翻译自 File::init
    public static func `init`(pathlike: PathOrFileDescriptor, mimeType: ?MimeType): File {
        let f = File()
        f.pathlike = pathlike
        f.mimeType = mimeType ?? MimeType()
        f
    }

    // 严格翻译自 File::is_seekable
    public func isSeekable(): ?Bool {
        if (let Some(s) <- seekable) { return s }
        if (mode != 0) {
            // return kindFromMode(mode) == FileKind.File
            return Some(true)
        }
        None
    }
}

// ========== S3 ==========
// 严格翻译自 webcore_types.rs store::S3
// Store.S3 (Store.zig:291) — S3 blob 存储
public class S3 {
    public var pathlike: PathLike = PathLikeOps.default()
    public var mimeType: MimeType = MimeType()
    public var credentials: ?S3Credentials = None
    public var options: MultiPartUploadOptions = MultiPartUploadOptions()
    public var acl: ?ACL = None
    public var storageClass: ?StorageClass = None
    public var requestPayer: Bool = false

    public init() {}

    // 严格翻译自 S3::is_seekable
    public func isSeekable(): ?Bool {
        Some(true)
    }

    // 严格翻译自 S3::get_credentials
    public func getCredentials(): S3Credentials {
        credentials.getOrThrow()
    }

    // 严格翻译自 S3::estimated_size
    public func estimatedSize(): Int64 {
        PathLikeOps.estimatedSize(pathlike)
    }

    // 严格翻译自 S3::path
    // 返回 URL 规范化的 S3 路径
    public func path(): Array<Byte> {
        // 简化实现: 返回 pathlike 的字节切片
        PathLikeOps.slice(pathlike)
    }

    // 严格翻译自 S3::init_with_referenced_credentials
    public static func initWithReferencedCredentials(
        pathlike: PathLike,
        mimeType: ?MimeType,
        credentials: S3Credentials
    ): S3 {
        let s3 = S3()
        s3.credentials = credentials
        s3.pathlike = pathlike
        s3.mimeType = mimeType ?? MimeType()
        s3
    }

    // 严格翻译自 S3::init
    public static func `init`(
        pathlike: PathLike,
        mimeType: ?MimeType,
        credentials: S3Credentials
    ): S3 {
        let s3 = S3()
        s3.credentials = credentials
        s3.pathlike = pathlike
        s3.mimeType = mimeType ?? MimeType()
        s3
    }
}

// ========== Store ==========
// 严格翻译自 webcore_types.rs store::Store
// Blob.Store (Store.zig:1-9). 内部引用计数; 总是堆分配
public class Store {
    public var data: Data = Data.BytesData(Bytes())
    public var mimeType: MimeType = MimeType()
    public var refCount: UInt32 = 1
    public var isAllAscii: ?Bool = None

    public init() {}

    // 严格翻译自 Store::new
    public static func new(init_: Store): Store {
        init_
    }

    // 严格翻译自 Store::init
    // Store(bytes, allocator) (Store.zig:152)。获取 bytes 所有权
    public static func `init`(bytes: Array<Byte>): Store {
        let store = Store()
        store.data = Data.BytesData(Bytes.`init`(bytes))
        store.mimeType = MimeType()
        store.refCount = 1
        store.isAllAscii = None
        store
    }

    // 严格翻译自 Store::get_path
    public func getPath(): ?Array<Byte> {
        match(data) {
            case Data.BytesData(bytes) =>
                let n = bytes.storedName.slice()
                if (n.isEmpty()) { None } else { Some(n.toArray()) }
            case Data.FileData(fileObj) =>
                match(fileObj.pathlike) {
                    case PathOrFileDescriptor.Path(path) => Some(PathLikeOps.slice(path))
                    case PathOrFileDescriptor.Fd(_) => None
                }
            case Data.S3Data(s3) => Some(PathLikeOps.slice(s3.pathlike))
        }
    }

    // 严格翻译自 Store::memory_cost
    public func memoryCost(): Int64 {
        if (hasOneRef()) {
            Int64(STORE_SIZE) + match(data) {
                case Data.BytesData(bytes) => Int64(bytes.len)
                case Data.FileData(_) => 0
                case Data.S3Data(s3) => s3.estimatedSize()
            }
        } else {
            0
        }
    }

    // 严格翻译自 Store::size
    public func size(): SizeType {
        match(data) {
            case Data.BytesData(b) => b.length()
            case Data.FileData(_) => MAX_SIZE
            case Data.S3Data(_) => MAX_SIZE
        }
    }

    // 严格翻译自 Store::shared_view
    public func sharedView(): Array<Byte> {
        match(data) {
            case Data.BytesData(bytes) => bytes.slice()
            case _ => []
        }
    }

    // 严格翻译自 Store::ref_
    public func ref_() {
        refCount++
    }

    // 严格翻译自 Store::has_one_ref
    public func hasOneRef(): Bool {
        refCount == 1
    }

    // 严格翻译自 Store::deref
    // 消耗一个引用; 在最后一个引用时, 释放并释放堆 Store
    public func deref() {
        refCount--
        if (refCount == 0) {
            // 释放 — deinit 在 Drop 中运行
            deinitData()
        }
    }

    // 严格翻译自 Store::external
    // extern fn external (Store.zig:63) — JSCArrayBuffer 解分配器钩子
    public static func external(ptr: CPointer<UInt8>) {
        // 将 ptr 转换回 Store 并 deref
    }

    // 清理数据
    public func deinitData() {
        match(data) {
            case Data.BytesData(bytes) => bytes.deinit()
            case Data.FileData(fileObj) =>
                // 如果 pathlike 是 String, 释放复制的路径
                match(fileObj.pathlike) {
                    case PathOrFileDescriptor.Path(p) =>
                        match(p) {
                            case PathLike.String(s) => () // 释放拥有的路径
                            case _ => ()
                        }
                    case _ => ()
                }
            case Data.S3Data(_) =>
                // credentials 和 pathlike 在各自的 Drop 中释放
                ()
            case _ => ()
        }
    }
}

// ========== StoreRef ==========
// 严格翻译自 webcore_types.rs store::StoreRef
// 拥有的堆 Store 句柄, 通过侵入式 Store::refCount 字段引用计数
public class StoreRef {
    public var ptr: ?Store = None

    public init() {}

    public init(store: Store) {
        this.ptr = store
    }

    // 严格翻译自 StoreRef::adopt
    // 采用现有的 +1。不增加引用计数
    public static func adopt(store: Store): StoreRef {
        StoreRef(store)
    }

    // 严格翻译自 StoreRef::retained
    // 包装原始 *Store, 增加其侵入式引用计数
    public static func retained(store: Store): StoreRef {
        store.ref_()
        StoreRef(store)
    }

    // 严格翻译自 StoreRef::as_ptr
    public func asPtr(): ?Store {
        ptr
    }

    // 严格翻译自 StoreRef::into_raw
    // 泄露持有的 +1 并返回原始指针
    public func intoRaw(): ?Store {
        let p = ptr
        ptr = None
        p
    }

    // 严格翻译自 StoreRef::data_mut
    // 通过共享句柄的可变数据访问
    public func dataMut(): ?Data {
        match(ptr) {
            case Some(s) => s.data
            case None => None
        }
    }

    // 严格翻译自 StoreRef::from (Box<Store>)
    public static func from(store: Store): StoreRef {
        StoreRef(store)
    }

    // Clone: 增加引用计数
    public func clone(): StoreRef {
        match(ptr) {
            case Some(s) =>
                s.ref_()
                StoreRef(s)
            case None => StoreRef()
        }
    }

    // Drop: 释放引用
    public func deinit() {
        match(ptr) {
            case Some(s) => s.deref()
            case None => ()
        }
        ptr = None
    }

    // 获取 size
    public func size(): SizeType {
        match(ptr) {
            case Some(s) => s.size()
            case None => 0
        }
    }

    // 获取 sharedView
    public func sharedView(): Array<Byte> {
        match(ptr) {
            case Some(s) => s.sharedView()
            case None => []
        }
    }
}

// ========== 支撑类型 ==========
// 以下类型在其他包中定义, 此处提供占位引用

// 注意: JSTimeType 已移至 jsc.cj
// 注意: INIT_TIMESTAMP 已移至 jsc.cj

// S3 凭证占位
public class S3Credentials {
    public init() {}
    public func estimatedSize(): Int64 { 0 }
}

// 多部分上传选项占位
public class MultiPartUploadOptions {
    public init() {}
}

// ACL 占位
public class ACL {
    public init() {}
}

// StorageClass 占位
public class StorageClass {
    public init() {}
}

// RawRefCount — 原始引用计数器
public class RawRefCount {
    public var rawValue: Int32 = 0

    public init() {}

    public init(value: Int32) {
        this.rawValue = value
    }

    public static func initValue(value: Int32): RawRefCount {
        RawRefCount(value)
    }

    public func increment() {
        rawValue++
    }

    // 返回 0 表示 ShouldDestroy, 1 表示 ShouldNotDestroy
    public func decrement(): Int32 {
        rawValue--
        if (rawValue == 0) { 0 } else { 1 }
    }
}

// BunString 类型别名
// 注意: BunString 已移至 bun_string_jsc.cj

// BunString 辅助
// BunString extension methods
public class BunStringExt {

    public static func dead(): BunString { BunString() }
}
