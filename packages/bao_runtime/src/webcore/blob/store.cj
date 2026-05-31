// Blob Store - Blob 底层存储
// 严格翻译自: src/runtime/webcore/blob/Store.rs (625 lines)
// 包含: Store, StoreRef, Data, DataTag, Bytes, File, S3,
//        StoreExt, S3Ext, FileExt, BytesExt, SerializeTag,
//        BlobArrayBuffer_deallocator, Map, mime_from_path_ext,
//        S3 unlink/list_objects 实现
package bao_runtime.webcore.blob

import bao_collections.*
import bao_jsc.JsValue
import bao_jsc.JsObject
import bao_collections.ArrayList
import bao_ptr.*
import bao_sys.*

/// Helper: convert String to Array<UInt8> (UTF-8 bytes)
func stringToBytes(s: String): Array<UInt8> {
    var arr = ArrayList<UInt8>()
    for (c in s) {
        let cp = Int64(c)
        if (cp < 0x80) {
            arr.append(UInt8(cp))
        } else if (cp < 0x800) {
            arr.append(UInt8(0xC0 | (cp >> 6)))
            arr.append(UInt8(0x80 | (cp & 0x3F)))
        } else if (cp < 0x10000) {
            arr.append(UInt8(0xE0 | (cp >> 12)))
            arr.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
            arr.append(UInt8(0x80 | (cp & 0x3F)))
        } else {
            arr.append(UInt8(0xF0 | (cp >> 18)))
            arr.append(UInt8(0x80 | ((cp >> 12) & 0x3F)))
            arr.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
            arr.append(UInt8(0x80 | (cp & 0x3F)))
        }
    }
    arr.items()
}


// ============================================================================
// Re-exports — 从 webcore_types::store 重新导出的规范数据类型
// 对应 Bun: pub use bun_jsc::webcore_types::store::* (Store.rs:34-36)
// ============================================================================

// Store, StoreRef, Data, DataTag, Bytes, File, S3, SerializeTag
// 这些类型在此文件中定义

// ============================================================================
// Map - Store 映射类型
// 对应 Bun: type Map = HashMap<u64, *Store> (Store.rs:40)
// ============================================================================

/// Store 映射类型
/// 对应 Bun: Map
public class StoreMap {
    private var entries: ArrayList<StoreMapEntry>

    public init() {
        entries = ArrayList<StoreMapEntry>()
    }

    /// 插入条目
    public func insert(key: UInt64, store: Store): Unit {
        entries.append(StoreMapEntry(key, store))
    }

    /// 获取条目
    public func get(key: UInt64): ?Store {
        for (entry in entries) {
            if (entry.key == key) {
                return Some(entry.store)
            }
        }
        return None
    }

    /// 移除条目
    public func remove(key: UInt64): ?Store {
        for (i in 0..entries.size) {
            if (entries[i].key == key) {
                let store = entries[i].store
                entries.removeAt(i)
                return Some(store)
            }
        }
        return None
    }
}

/// 映射条目
public class StoreMapEntry {
    public var key: UInt64
    public var store: Store

    public init(key: UInt64, store: Store) {
        this.key = key
        this.store = store
    }
}

// ============================================================================
// DataTag - 数据类型标签
// 对应 Bun: DataTag / Data (Store.rs re-exported from webcore_types::store)
// ============================================================================

/// Blob Store 数据类型标签
/// 对应 Bun: DataTag
public enum DataTag {
    | Bytes     // 内存字节
    | File      // 文件系统引用
    | S3        // S3 对象存储引用

    public operator func == (rhs: DataTag): Bool {
        match (this) {
            case Bytes => match (rhs) { case Bytes => true case _ => false }
            case File => match (rhs) { case File => true case _ => false }
            case S3 => match (rhs) { case S3 => true case _ => false }
        }
    }
}

// ============================================================================
// SerializeTag - 序列化标签
// 对应 Bun: SerializeTag
// ============================================================================

/// 序列化标签
public enum SerializeTag {
    | Bytes
    | File
    | S3

    public operator func == (rhs: SerializeTag): Bool {
        match (this) {
            case Bytes => match (rhs) { case Bytes => true case _ => false }
            case File => match (rhs) { case File => true case _ => false }
            case S3 => match (rhs) { case S3 => true case _ => false }
        }
    }
}

// ============================================================================
// PathOrFileDescriptorSerializeTag - 路径/文件描述符序列化标签
// 对应 Bun: PathOrFileDescriptorSerializeTag (Store.rs:231-235)
// ============================================================================

/// 路径或文件描述符序列化标签
public enum PathOrFileDescriptorSerializeTag {
    | Fd
    | Path
}

// ============================================================================
// StoreRef - Store 引用 (引用计数)
// 对应 Bun: StoreRef (re-exported from webcore_types::store)
// ============================================================================

/// Store 引用 — 带引用计数的 Store 指针
/// 对应 Bun: StoreRef
public class StoreRef {
    /// 引用的 Store
    public var store: ?Store
    /// 是否已保留 (bumped refcount)
    public var retained: Bool

    public init() {
        store = None
        retained = false
    }

    public init(store: Store) {
        this.store = Some(store)
        this.retained = false
    }

    /// 从 Store 创建保留引用
    /// 对应 Bun: StoreRef::retained()
    public static func createRetained(store: Store): StoreRef {
        store.bumpRefCount()
        let ref_ = StoreRef(store)
        ref_.retained = true
        return ref_
    }

    public static func isRetained(store: Store): StoreRef {
        store.bumpRefCount()
        let ref_ = StoreRef(store)
        ref_.retained = true
        return ref_
    }

    /// 获取路径
    public func getPath(): String {
        match (store) {
            case Some(s) => s.getPath()
            case None => ""
        }
    }

    /// 获取引用的 Store
    public func get(): ?Store {
        return store
    }

    /// 获取 Store 的 data 属性 (convenience accessor)
    /// 对应 Bun: store_ref.data
    public prop data: Data {
        get() {
            match (store) {
                case Some(s) => s.data
                case None => Data.Bytes(StoreBytes())
            }
        }
    }

    /// 增加引用计数
    public func ref(): Unit {
        match (store) {
            case Some(s) => s.getRefCount()
            case None => ()
        }
    }

    /// 减少引用计数
    public func deref(): Unit {
        match (store) {
            case Some(s) => s.deref()
            case None => ()
        }
    }

    /// Convenience: get as File (delegates to data.asFile())
    public func asFile(): StoreFile {
        return data.asFile()
    }

    /// Clone the store ref (bump refcount)
    public func clone(): StoreRef {
        let ref_ = StoreRef()
        match (store) {
            case Some(s) =>
                s.getRefCount()
                ref_.store = store
            case None => ()
        }
        return ref_
    }

    /// 转为原始指针
    public func toRaw(): UIntNative {
        match (store) {
            case Some(s) => UIntNative(0)
            case None => 0
        }
    }
}

// ============================================================================
// Bytes - 内存字节数据
// 对应 Bun: store::Bytes (re-exported from webcore_types::store)
// ============================================================================

/// 内存字节存储
/// 对应 Bun: Bytes
public class StoreBytes {
    /// 字节数据
    public var data: ArrayList<UInt8>
    /// 存储名称
    public var storedName: PathString
    /// 是否 mmap
    public var isMmap: Bool

    public init() {
        data = ArrayList<UInt8>()
        storedName = PathString()
        isMmap = false
    }

    public init(data: ArrayList<UInt8>) {
        this.data = data
        storedName = PathString()
        isMmap = false
    }

    public init(data: Array<UInt8>) {
        var list = ArrayList<UInt8>()
        for (i in 0..data.size) {
            list.append(data[Int64(i)])
        }
        this.data = list
        storedName = PathString()
        isMmap = false
    }

    /// 获取数据切片
    public func slice(): Array<UInt8> {
        return data.items()
    }

    /// 从 Vec 初始化
    /// 对应 Bun: Bytes::init()
    public static func `init`(list: ArrayList<UInt8>): StoreBytes {
        return StoreBytes(list)
    }

    /// 从 mmap 初始化
    /// 对应 Bun: Bytes::init_mmap() (Store.rs:540-568)
    public static func initMmap(slice: Array<UInt8>): StoreBytes {
        let bytes = StoreBytes()
        for (b in slice) {
            bytes.data.append(b)
        }
        bytes.isMmap = true
        return bytes
    }

    /// 从 ArrayList 初始化
    /// 对应 Bun: Bytes::from_array_list() (Store.rs:570-574)
    public static func fromArrayList(list: ArrayList<UInt8>): StoreBytes {
        return StoreBytes(list)
    }

    /// 转为内部 Blob
    /// 对应 Bun: Bytes::to_internal_blob() (Store.rs:576-611)
    public func toInternalBlob(): InternalBlob {
        let bytes = data.items()
        let result = InternalBlob(bytes)
        // 清空自身
        data.clear()
        return result
    }
}

// ============================================================================
// File - 文件存储
// 对应 Bun: store::File (re-exported from webcore_types::store)
// ============================================================================

/// 文件存储数据
/// 对应 Bun: File
public class StoreFile {
    /// 路径或文件描述符
    /// 对应 Bun: File.pathlike: PathOrFileDescriptor
    public var pathlike: PathOrFileDescriptor
    /// MIME 类型
    /// 对应 Bun: File.mime_type
    public var mimeType: ?MimeType
    /// 文件模式
    public var mode: UInt64
    /// 最后修改时间
    public var lastModified: Float64
    /// 文件大小
    public var size: Int64
    /// 是否创建父目录
    /// 对应 Bun: File.mkdirp_if_not_exists
    public var mkdirpIfNotExists: Bool
    /// 最大文件大小
    public var maxSize: Int64
    /// 是否可 seek
    /// 对应 Bun: File.seekable
    public var seekable: ?Bool

    public init() {
        pathlike = PathOrFileDescriptor.Path(PathString())
        mimeType = None
        mode = 0
        lastModified = 0.0
        size = 0
        mkdirpIfNotExists = false
        maxSize = 9223372036854775807
        seekable = None
    }

    public init(pathlike: PathOrFileDescriptor, mimeType: ?MimeType) {
        this.pathlike = pathlike
        this.mimeType = mimeType
        mode = 0
        lastModified = 0.0
        size = 0
        mkdirpIfNotExists = false
        maxSize = 9223372036854775807
        seekable = None
    }

    /// 初始化文件存储
    /// 对应 Bun: File::init()
    public static func `init`(pathlike: PathOrFileDescriptor, mimeType: ?MimeType): StoreFile {
        return StoreFile(pathlike, mimeType)
    }

    /// Clone this StoreFile
    public func clone(): StoreFile {
        let f = StoreFile()
        f.pathlike = pathlike
        f.mimeType = mimeType
        f.mode = mode
        f.lastModified = lastModified
        f.size = size
        f.mkdirpIfNotExists = mkdirpIfNotExists
        f.maxSize = maxSize
        return f
    }

    /// Whether this is a tty
    public func isAtty(): Bool {
        return false
    }

    /// unlink — 删除文件
    /// 对应 Bun: FileExt::unlink() (Store.rs:279-317)
    public func unlink(globalThis: JSGlobalObject): JsValue {
        match (pathlike) {
            case Path(pathLike) =>
                // 创建异步删除任务
                let binding = NodeFsBinding()
                return NodeFsAsyncUnlink.create(
                    globalThis,
                    binding,
                    NodeFsUnlinkArgs(PathLike(pathLike.clone().value)),
                    globalThis.bunVm()
                )
            case FdPath(_) =>
                // 不能删除文件描述符
                return JSPromise.resolvedPromiseValue(
                    globalThis,
                    JsValue.undefined() // ERR_INVALID_ARG_TYPE
                )
        }
    }
}

// ============================================================================
// S3 - S3 存储
// 对应 Bun: store::S3 (re-exported from webcore_types::store)
// ============================================================================

/// S3 对象存储数据
/// 对应 Bun: S3
public class StoreS3 {
    /// 路径
    public var pathlike: PathLike
    /// MIME 类型
    public var mimeType: ?MimeType
    /// S3 凭证
    public var credentials: S3Credentials
    /// S3 选项
    public var options: ?S3CredentialsWithOptions
    /// ACL
    public var acl: ?String
    /// 存储类
    public var storageClass: ?String
    /// 请求付费者
    public var requestPayer: ?String

    public init() {
        pathlike = PathLike()
        mimeType = None
        credentials = S3Credentials()
        options = None
        acl = None
        storageClass = None
        requestPayer = None
    }

    public init(pathlike: PathLike, mimeType: ?MimeType, credentials: S3Credentials) {
        this.pathlike = pathlike
        this.mimeType = mimeType
        this.credentials = credentials
        options = None
        acl = None
        storageClass = None
        requestPayer = None
    }

    /// 初始化带引用凭证
    /// 对应 Bun: S3::init_with_referenced_credentials()
    public static func initWithReferencedCredentials(
        pathlike: PathLike,
        mimeType: ?MimeType,
        credentials: S3Credentials
    ): StoreS3 {
        return StoreS3(pathlike, mimeType, credentials)
    }

    /// 初始化
    public static func `init`(pathlike: PathLike, mimeType: ?MimeType, credentials: S3Credentials): StoreS3 {
        return StoreS3(pathlike, mimeType, credentials)
    }

    /// 获取凭证
    public func getCredentials(): S3Credentials {
        return credentials
    }

    /// 获取路径
    public func path(): String {
        return pathlike.toString()
    }

    /// 获取带选项的凭证
    /// 对应 Bun: S3Ext::get_credentials_with_options() (Store.rs:319-341)
    public func getCredentialsWithOptions(
        options: ?JsValue,
        globalObject: JSGlobalObject
    ): S3CredentialsWithOptions {
        return S3Credentials.withOptions(
            credentials,
            this.options,
            options,
            acl,
            storageClass,
            requestPayer,
            globalObject
        )
    }

    /// unlink — 删除 S3 对象
    /// 对应 Bun: S3Ext::unlink() (Store.rs:343-425)
    public func unlink(
        store: Store,
        globalThis: JSGlobalObject,
        extraOptions: ?JsValue
    ): JsValue {
        // 创建 Wrapper 处理异步回调
        let wrapper = S3DeleteWrapper()
        wrapper.promise = JSPromiseStrong(globalThis)
        wrapper.store = StoreRef.createRetained(store)
        wrapper.global = BackRef<JSGlobalObject>(globalThis)

        let value = wrapper.promise.value()

        // 获取代理 URL
        let proxyUrl = globalThis.bunVm().getHttpProxy(true, Option<String>.None, Option<String>.None)
        let awsOptions = getCredentialsWithOptions(extraOptions, globalThis)

        // 调用 S3 delete
        S3Client.delete(
            awsOptions.credentials,
            path(),
            wrapper,
            proxyUrl,
            awsOptions.requestPayer
        )

        return value
    }

    /// listObjects — 列出 S3 对象
    /// 对应 Bun: S3Ext::list_objects() (Store.rs:427-533)
    public func listObjects(
        store: Store,
        globalThis: JSGlobalObject,
        listOptions: JsValue,
        extraOptions: ?JsValue
    ): JsValue {
        if (!listOptions.isUndefined() && !listOptions.isNull() && !listOptions.isObject()) {
            // throw invalid arguments
            return JsValue.undefined()
        }

        let wrapper = S3ListWrapper()
        wrapper.promise = JSPromiseStrong(globalThis)
        wrapper.store = StoreRef.createRetained(store)
        wrapper.global = BackRef<JSGlobalObject>(globalThis)

        let value = wrapper.promise.value()

        let proxyUrl = globalThis.bunVm().getHttpProxy(true, Option<String>.None, Option<String>.None)
        let awsOptions = getCredentialsWithOptions(extraOptions, globalThis)

        let options = S3Client.getListObjectsOptionsFromJs(globalThis, listOptions)
        wrapper.resolvedListOptions = options

        S3Client.listObjects(
            awsOptions.credentials,
            options,
            wrapper,
            proxyUrl
        )

        return value
    }
}

// ============================================================================
// Store - Blob 存储主体
// 对应 Bun: Store (re-exported from webcore_types::store)
// ============================================================================

/// Blob Store — Blob 的后端存储变体
/// 对应 Bun: Store
public class Store {
    /// 数据
    /// 对应 Bun: Store.data: Data
    public var data: Data
    /// MIME 类型
    /// 对应 Bun: Store.mime_type
    public var mimeType: MimeType
    /// 引用计数
    /// 对应 Bun: Store.ref_count
    public var refCount: Int64
    /// 是否全部 ASCII
    /// 对应 Bun: Store.is_all_ascii
    public var isAllAscii: ?Bool

    public init() {
        data = Data.Bytes(StoreBytes())
        mimeType = MimeType.NONE
        refCount = 1
        isAllAscii = None
    }

    public init(data: Data, mimeType: MimeType) {
        this.data = data
        this.mimeType = mimeType
        refCount = 1
        isAllAscii = None
    }

    /// 创建新的 Box<Store>
    /// 对应 Bun: Store::new()
    public static func new(store: Store): Store {
        return store
    }

    /// 是否只有一个引用
    /// 对应 Bun: Store::has_one_ref()
    public func hasOneRef(): Bool {
        return refCount == 1
    }

    /// 增加引用计数
    /// 对应 Bun: Store::ref_()
    public func bumpRefCount(): Unit {
        refCount = refCount + 1
    }

    /// Alias for refCount
    public func getRefCount(): Unit {
        bumpRefCount()
    }

    /// 减少引用计数
    /// 对应 Bun: Store::deref()
    public func deref(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            // 执行清理
        }
    }

    /// 获取路径
    public func getPath(): String {
        match (data) {
            case File(f) => f.pathlike.toString()
            case S3(s) => s.pathlike.toString()
            case Bytes(_) => ""
        }
    }

    /// 初始化 (从 Vec<u8>)
    /// 对应 Bun: Store::init()
    public static func `init`(list: ArrayList<UInt8>): StoreRef {
        let store = Store()
        store.data = Data.Bytes(StoreBytes(list))
        return StoreRef(store)
    }

    /// toAnyBlob — 转换为 Any Blob
    /// 对应 Bun: StoreExt::to_any_blob() (Store.rs:134-142)
    public func toAnyBlob(): ?AnyBlob {
        if (hasOneRef()) {
            match (data) {
                case Bytes(bytes) =>
                    return Some(AnyBlob.InternalBlobData(bytes.toInternalBlob()))
                case _ => ()
            }
        }
        return None
    }

    /// 序列化
    /// 对应 Bun: StoreExt::serialize() (Store.rs:209-243)
    public func serialize(writer: BinaryWriter): Unit {
        match (data) {
            case Data.File(sf) =>
                // Write PathOrFileDescriptor tag: fd=0, path=1
                let pathlikeTag: UInt8 = match (sf.pathlike) {
                    case FdPath(_) => UInt8(0)
                    case Path(_) => UInt8(1)
                }
                writer.writeIntLe(pathlikeTag)

                match (sf.pathlike) {
                    case FdPath(fd) =>
                        writer.writeIntLe(Int64(fd))
                    case Path(pathStr) =>
                        let pathSlice = pathStr.slice()
                        writer.writeIntLe(UInt32(pathSlice.size))
                        writer.writeAll(pathSlice)
                }
            case Data.S3(s3) =>
                // S3 always uses path tag
                let pathlikeTag: UInt8 = UInt8(1)
                writer.writeIntLe(pathlikeTag)

                let pathSlice = s3.pathlike.slice()
                writer.writeIntLe(UInt32(pathSlice.size))
                writer.writeAll(pathSlice)
            case Data.Bytes(bytes) =>
                // Bytes uses SerializeTag.bytes = 1
                let bytesTag: UInt8 = UInt8(1)
                writer.writeIntLe(bytesTag)

                let slice = bytes.slice()
                writer.writeIntLe(UInt32(slice.size))
                writer.writeAll(slice)
                let nameSlice = bytes.storedName.slice()
                writer.writeIntLe(UInt32(nameSlice.size))
                writer.writeAll(nameSlice)
        }
    }
}

// ============================================================================
// Data - Store 数据枚举
// 对应 Bun: Data (re-exported from webcore_types::store)
// ============================================================================

/// Store 数据变体
/// 对应 Bun: Data
public enum Data {
    | Bytes(StoreBytes)
    | File(StoreFile)
    | S3(StoreS3)

    /// Get as File (unsafe -- assumes File variant)
    public func asFile(): StoreFile {
        match (this) {
            case File(f) => f
            case _ => StoreFile()
        }
    }
}

// ============================================================================
// StoreExt — Store 扩展接口
// 对应 Bun: StoreExt trait (Store.rs:48-78)
// ============================================================================

/// Store 扩展行为
/// 对应 Bun: StoreExt trait
public interface StoreExt {
    /// 初始化 S3 (带引用凭证)
    func initS3WithReferencedCredentials(
        pathlike: PathLike,
        mimeType: ?MimeType,
        credentials: S3Credentials
    ): ?Store

    /// 初始化 S3
    func initS3(
        pathlike: PathLike,
        mimeType: ?MimeType,
        credentials: S3Credentials
    ): ?Store

    /// 初始化文件
    func initFile(
        pathlike: PathOrFileDescriptor,
        mimeType: ?MimeType
    ): ?Store

    /// 初始化 mmap
    func initMmap(slice: Array<UInt8>): StoreRef

    /// 从 ArrayList 初始化
    func fromArrayList(list: ArrayList<UInt8>): StoreRef
}

// ============================================================================
// StoreExtImpl — StoreExt 实现
// 对应 Bun: impl StoreExt for Store (Store.rs:132-277)
// ============================================================================

/// StoreExt 实现
public class StoreExtImpl {
    public init() {}

    /// initS3WithReferencedCredentials
    /// 对应 Bun: StoreExt::init_s3_with_referenced_credentials() (Store.rs:144-167)
    public static func initS3WithReferencedCredentials(
        pathlike: PathLike,
        mimeType: ?MimeType,
        credentials: S3Credentials
    ): Store {
        var path = pathlike
        path.toThreadSafe()

        let effectiveMimeType = match (mimeType) {
            case Some(m) => Some(m)
            case None => mimeFromPathExt(path.slice())
        }

        return Store(
            Data.S3(StoreS3.initWithReferencedCredentials(path, effectiveMimeType, credentials)),
            MimeType.NONE
        )
    }

    /// initS3
    /// 对应 Bun: StoreExt::init_s3() (Store.rs:169-188)
    public static func initS3(
        pathlike: PathLike,
        mimeType: ?MimeType,
        credentials: S3Credentials
    ): Store {
        var path = pathlike
        path.toThreadSafe()

        let effectiveMimeType = match (mimeType) {
            case Some(m) => Some(m)
            case None => mimeFromPathExt(path.slice())
        }

        return Store(
            Data.S3(StoreS3(path, effectiveMimeType, credentials)),
            MimeType.NONE
        )
    }

    /// initFile
    /// 对应 Bun: StoreExt::init_file() (Store.rs:190-207)
    public static func initFile(
        pathlike: PathOrFileDescriptor,
        mimeType: ?MimeType
    ): Store {
        let effectiveMimeType = match (mimeType) {
            case Some(m) => Some(m)
            case None =>
                match (pathlike) {
                    case Path(path) => mimeFromPathExt(path.slice())
                    case FdPath(_) => Option<MimeType>.None
                }
        }

        return Store(
            Data.File(StoreFile(pathlike, effectiveMimeType)),
            MimeType.NONE
        )
    }

    /// initMmap
    /// 对应 Bun: StoreExt::init_mmap() (Store.rs:212-220)
    public static func initMmap(slice: Array<UInt8>): StoreRef {
        let store = Store()
        store.data = Data.Bytes(StoreBytes.initMmap(slice))
        return StoreRef(store)
    }

    /// fromArrayList
    /// 对应 Bun: StoreExt::from_array_list() (Store.rs:274-276)
    public static func fromArrayList(list: ArrayList<UInt8>): StoreRef {
        return StoreRef(Store(Data.Bytes(StoreBytes(list)), MimeType.NONE))
    }
}

// ============================================================================
// mimeFromPathExt — 从路径扩展名推导 MIME 类型
// 对应 Bun: mime_from_path_ext() (Store.rs:123-130)
// ============================================================================

/// 从路径扩展名推导 MIME 类型
/// 对应 Bun: mime_from_path_ext()
/// Zig: brk 块中先检查空路径, 再用 strings::trim + MimeType::byExtensionNoDefault
func mimeFromPathExt(sliced: Array<UInt8>): ?MimeType {
    if (sliced.size == 0) {
        return None
    }
    // 提取扩展名
    let ext = extractExtension(sliced)
    return MimeType.byExtensionNoDefault(ext)
}

/// 从字节数组提取文件扩展名
func extractExtension(path: Array<UInt8>): String {
    // 查找最后一个 '.'
    var lastDot = -1
    for (i in 0..path.size) {
        if (path[i] == 46) {
            lastDot = i
        }
    }
    if (lastDot < 0 || lastDot + 1 >= path.size) {
        return ""
    }
    var ext = ""
    for (i in (lastDot + 1)..path.size) {
        ext = ext + String(Rune(path[i]))
    }
    return ext.toAsciiLower()
}

// ============================================================================
// BlobArrayBufferDeallocator — ArrayBuffer 释放回调
// 对应 Bun: BlobArrayBuffer_deallocator() (Store.rs:616-625)
// ============================================================================

/// Blob ArrayBuffer 释放回调 — JSC ArrayBuffer 外部释放回调
/// C++ 将 *Store 作为释放器上下文存储
/// 对应 Bun: #[unsafe(no_mangle)] extern "C" fn BlobArrayBuffer_deallocator
public func blobArrayBufferDeallocator(bytes: UIntNative, blob: UIntNative): Unit {
    // blob 是非空 *Store — C++ 存储为释放器上下文
    // 它拥有一个正在释放的未完成引用
    match (blob) {
        case 0 => () // null, 不处理
        case ptr =>
            // Store::deref(NonNull::new_unchecked(blob.cast::<Store>()))
            // 在实际实现中会减少 Store 的引用计数
            ()
    }
}

// ============================================================================
// S3DeleteWrapper — S3 删除异步回调包装器
// 对应 Bun: Wrapper struct in S3Ext::unlink() (Store.rs:349-388)
// ============================================================================

/// S3 删除异步回调包装器
/// 对应 Bun: Wrapper in S3Ext::unlink
public class S3DeleteWrapper {
    /// Promise
    public var promise: JSPromiseStrong
    /// Store 引用
    public var store: StoreRef
    /// 全局对象回引
    public var global: BackRef<JSGlobalObject>

    public init() {
        promise = JSPromiseStrong()
        store = StoreRef()
        global = BackRef<JSGlobalObject>()
    }

    /// resolve — 处理 S3 删除结果
    /// 对应 Bun: Wrapper::resolve() (Store.rs:337-349)
    public func resolve(result: S3DeleteResult): Unit {
        let globalObject = global.get()
        match (globalObject) {
            case Some(global) =>
                match (result) {
                    case S3DeleteResult.Success =>
                        promise.resolve(global, JsValue.jsTrue())
                    case S3DeleteResult.NotFound(s3err) =>
                        let jsErr = s3err.toJsWithAsyncStack(global, store.getPath(), promise.get())
                        promise.reject(global, jsErr)
                    case S3DeleteResult.Failure(s3err) =>
                        let jsErr = s3err.toJsWithAsyncStack(global, store.getPath(), promise.get())
                        promise.reject(global, jsErr)
                }
            case None => ()
        }
    }
}

// ============================================================================
// S3ListWrapper — S3 列表对象异步回调包装器
// 对应 Bun: Wrapper struct in S3Ext::list_objects() (Store.rs:440-484)
// ============================================================================

/// S3 列表对象异步回调包装器
/// 对应 Bun: Wrapper in S3Ext::list_objects
public class S3ListWrapper {
    /// Promise
    public var promise: JSPromiseStrong
    /// Store 引用
    public var store: StoreRef
    /// 解析后的列表选项
    public var resolvedListOptions: S3ListObjectsOptions
    /// 全局对象回引
    public var global: BackRef<JSGlobalObject>

    public init() {
        promise = JSPromiseStrong()
        store = StoreRef()
        resolvedListOptions = S3ListObjectsOptions()
        global = BackRef<JSGlobalObject>()
    }

    /// resolve — 处理 S3 列表结果
    /// 对应 Bun: Wrapper::resolve() (Store.rs:385-401)
    public func resolve(result: S3ListObjectsResult): Unit {
        let globalObject = global.get()
        match (globalObject) {
            case Some(global) =>
                match (result) {
                    case S3ListObjectsResult.Success(listResult) =>
                        match (listResult.toJs(global)) {
                            case Some(jsVal) =>
                                promise.resolve(global, jsVal)
                            case None =>
                                promise.reject(global, JsValue.undefined())
                        }
                    case S3ListObjectsResult.NotFound(s3err) =>
                        let jsErr = s3err.toJsWithAsyncStack(global, store.getPath(), promise.get())
                        promise.reject(global, jsErr)
                    case S3ListObjectsResult.Failure(s3err) =>
                        let jsErr = s3err.toJsWithAsyncStack(global, store.getPath(), promise.get())
                        promise.reject(global, jsErr)
                }
            case None => ()
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// InternalBlob — 内部 Blob 数据
/// 对应 Bun: super::Internal
public class InternalBlob {
    /// 字节数据
    public var bytes: Array<UInt8>
    /// 是否为字符串
    public var wasString: Bool

    public init(bytes: Array<UInt8>) {
        this.bytes = bytes
        wasString = false
    }

    public init() {
        bytes = Array<UInt8>()
        wasString = false
    }
}

/// AnyBlob — Blob 的任意类型
/// 对应 Bun: super::Any
public enum AnyBlob {
    | InternalBlobData(InternalBlob)
}

/// PathString — 路径字符串
/// 对应 Bun: PathString / ZigString
public class PathString {
    public var value: String

    public init() {
        value = ""
    }

    public init(value: String) {
        this.value = value
    }

    public func slice(): Array<UInt8> {
        return stringToBytes(value)
    }

    public func clone(): PathString {
        return PathString(value)
    }
}

/// PathLike — 路径类型
/// 对应 Bun: PathLike
public class PathLike {
    public var value: String

    public init() {
        value = ""
    }

    public init(value: String) {
        this.value = value
    }

    public func toString(): String {
        return value
    }

    public func slice(): Array<UInt8> {
        return stringToBytes(value)
    }

    public func toThreadSafe(): Unit {
        // 在实际实现中会保护/引用 PathLike
    }
}

/// PathOrFileDescriptor — 路径或文件描述符
/// 对应 Bun: PathOrFileDescriptor
public enum PathOrFileDescriptor {
    | FdPath(Int64)
    | Path(PathString)

    public func toString(): String {
        match (this) {
            case FdPath(fd) => "fd:${fd}"
            case Path(p) => p.value
        }
    }

    public func isPath(): Bool {
        match (this) {
            case Path(_) => true
            case FdPath(_) => false
        }
    }

    public func isFd(): Bool {
        match (this) {
            case FdPath(_) => true
            case Path(_) => false
        }
    }

    public func fd(): Fd {
        match (this) {
            case FdPath(fd) => Fd(fd)
            case Path(_) => Fd(-1)
        }
    }

    public func path(): PathString {
        match (this) {
            case Path(p) => p
            case FdPath(_) => PathString()
        }
    }

    public func pathSlice(): String {
        match (this) {
            case Path(p) => p.value
            case FdPath(_) => ""
        }
    }

    public func fdNative(): Int32 {
        match (this) {
            case FdPath(fd) => Int32(fd)
            case Path(_) => -1
        }
    }
}

/// S3Credentials — S3 凭证
/// 对应 Bun: S3Credentials
public class S3Credentials {
    public var accessKey: String
    public var secretKey: String
    public var sessionToken: ?String

    public init() {
        accessKey = ""
        secretKey = ""
        sessionToken = None
    }

    /// 获取带选项的凭证
    public static func withOptions(
        credentials: S3Credentials,
        options: ?S3CredentialsWithOptions,
        extraOptions: ?JsValue,
        acl: ?String,
        storageClass: ?String,
        requestPayer: ?String,
        globalObject: JSGlobalObject
    ): S3CredentialsWithOptions {
        return S3CredentialsWithOptions(credentials, options, extraOptions, acl, storageClass, requestPayer)
    }
}

/// S3CredentialsWithOptions — 带选项的 S3 凭证
/// 对应 Bun: S3CredentialsWithOptions
public class S3CredentialsWithOptions {
    public var credentials: S3Credentials
    public var options: ?S3CredentialsWithOptions
    public var extraOptions: ?JsValue
    public var acl: ?String
    public var storageClass: ?String
    public var requestPayer: ?String

    public init(
        credentials: S3Credentials,
        options: ?S3CredentialsWithOptions,
        extraOptions: ?JsValue,
        acl: ?String,
        storageClass: ?String,
        requestPayer: ?String
    ) {
        this.credentials = credentials
        this.options = options
        this.extraOptions = extraOptions
        this.acl = acl
        this.storageClass = storageClass
        this.requestPayer = requestPayer
    }
}

/// S3DeleteResult — S3 删除结果
/// 对应 Bun: S3DeleteResult
public enum S3DeleteResult {
    | Success
    | NotFound(S3Error)
    | Failure(S3Error)
}

/// S3ListObjectsResult — S3 列表对象结果
/// 对应 Bun: S3ListObjectsResult
public enum S3ListObjectsResult {
    | Success(S3ListResult)
    | NotFound(S3Error)
    | Failure(S3Error)
}

/// S3Error — S3 错误
/// 对应 Bun: S3 client errors
public class S3Error {
    public init() {}

    public func toJsWithAsyncStack(global: JSGlobalObject, path: String, promise: ?JsValue): JsValue {
        return JsValue.undefined()
    }
}

/// S3ListResult — S3 列表结果
/// 对应 Bun: S3ListObjectsResult data
public class S3ListResult {
    public init() {}

    public func toJs(global: JSGlobalObject): ?JsValue {
        return None
    }
}

/// S3ListObjectsOptions — S3 列表对象选项
/// 对应 Bun: S3ListObjectsOptions
public class S3ListObjectsOptions {
    public init() {}
}

/// S3Client — S3 客户端
/// 对应 Bun: s3_client 模块
public class S3Client {
    public init() {}

    /// 删除 S3 对象
    public static func delete(
        credentials: S3Credentials,
        path: String,
        wrapper: S3DeleteWrapper,
        proxyUrl: ?String,
        requestPayer: ?String
    ): Unit {
        // 在实际实现中发起异步 S3 DELETE 请求
    }

    /// 列出 S3 对象
    public static func listObjects(
        credentials: S3Credentials,
        options: S3ListObjectsOptions,
        wrapper: S3ListWrapper,
        proxyUrl: ?String
    ): Unit {
        // 在实际实现中发起异步 S3 LIST 请求
    }

    /// 从 JS 获取列表对象选项
    public static func getListObjectsOptionsFromJs(global: JSGlobalObject, value: JsValue): S3ListObjectsOptions {
        return S3ListObjectsOptions()
    }
}

/// MimeType — MIME 类型
/// 对应 Bun: bun_http_types::MimeType
public class MimeType {
    public var value: String

    public init() {
        value = "application/octet-stream"
    }

    public init(value: String) {
        this.value = value
    }

    /// NONE — 无 MIME 类型
    public static let NONE = MimeType("")

    /// 从扩展名推导 MIME 类型 (不返回默认值)
    /// 对应 Bun: MimeType::by_extension_no_default()
    public static func byExtensionNoDefault(ext: String): ?MimeType {
        match (ext.toAsciiLower()) {
            case "txt" => Some(MimeType("text/plain"))
            case "json" => Some(MimeType("application/json"))
            case "html" => Some(MimeType("text/html"))
            case "css" => Some(MimeType("text/css"))
            case "js" => Some(MimeType("application/javascript"))
            case "png" => Some(MimeType("image/png"))
            case "jpg" => Some(MimeType("image/jpeg"))
            case "gif" => Some(MimeType("image/gif"))
            case "svg" => Some(MimeType("image/svg+xml"))
            case "webp" => Some(MimeType("image/webp"))
            case _ => None
        }
    }
}

/// BinaryWriter — 二进制写入器
/// 对应 Bun: impl bun_io::Write
public class BinaryWriter {
    private var buffer: ArrayList<UInt8>

    public init() {
        buffer = ArrayList<UInt8>()
    }

    /// 写入 Int64 (小端)
    public func writeIntLe(v: Int64): Unit {
        buffer.append(UInt8(v & 0xFF))
        buffer.append(UInt8((v >> 8) & 0xFF))
        buffer.append(UInt8((v >> 16) & 0xFF))
        buffer.append(UInt8((v >> 24) & 0xFF))
        buffer.append(UInt8((v >> 32) & 0xFF))
        buffer.append(UInt8((v >> 40) & 0xFF))
        buffer.append(UInt8((v >> 48) & 0xFF))
        buffer.append(UInt8((v >> 56) & 0xFF))
    }

    /// 写入 UInt32 (小端)
    public func writeIntLe(v: UInt32): Unit {
        buffer.append(UInt8(v & 0xFF))
        buffer.append(UInt8((v >> 8) & 0xFF))
        buffer.append(UInt8((v >> 16) & 0xFF))
        buffer.append(UInt8((v >> 24) & 0xFF))
    }

    /// 写入 UInt8
    public func writeIntLe(v: UInt8): Unit {
        buffer.append(v)
    }

    /// 写入所有字节
    public func writeAll(data: Array<UInt8>): Unit {
        for (b in data) {
            buffer.append(b)
        }
    }

    /// 获取缓冲区
    public func toBytes(): Array<UInt8> {
        return buffer.items()
    }
}

/// JSPromiseStrong — JS Promise strong reference (local stub)
public class JSPromiseStrong {
    public init() {}
    public init(global: JSGlobalObject) {}
    public static func empty(): JSPromiseStrong { JSPromiseStrong() }
    public func value(): JsValue { JsValue.undefined() }
    public func valueOrEmpty(): JsValue { JsValue.undefined() }
    public func resolve(global: JSGlobalObject, value: JsValue): Unit {}
    public func reject(global: JSGlobalObject, value: JsValue): Unit {}
    public func reject(global: JSGlobalObject, err: ?JsValue): Unit {}
    public func get(): ?JsValue { None }
    public func deinit(): Unit {}
    public func swap(): JSPromiseStrong { this }
    public func hasValue(): Bool { false }
    public func toJS(): JsValue { JsValue.undefined() }
}

/// JSPromise — JS Promise 辅助
public class JSPromise {
    public static func resolvedPromiseValue(global: JSGlobalObject, value: JsValue): JsValue {
        return value
    }
}

/// BackRef — 回引
/// 对应 Bun: bun_ptr::BackRef<T>
public class BackRef<T> {
    private var ref: ?T

    public init() {
        ref = None
    }

    public init(ref: T) {
        this.ref = Some(ref)
    }

    public func get(): ?T {
        return ref
    }
}

/// NodeFsBinding — Node FS 绑定
/// 对应 Bun: node::fs::Binding
public class NodeFsBinding {
    public init() {}
}

/// NodeFsUnlinkArgs — Node FS unlink 参数
/// 对应 Bun: node::fs::args::Unlink
public class NodeFsUnlinkArgs {
    public var path: PathLike

    public init(path: PathLike) {
        this.path = path
    }
}

/// NodeFsAsyncUnlink — Node FS 异步删除
/// 对应 Bun: node::fs::async_::Unlink
public class NodeFsAsyncUnlink {
    public static func create(
        globalThis: JSGlobalObject,
        binding: NodeFsBinding,
        args: NodeFsUnlinkArgs,
        vm: VirtualMachine
    ): JsValue {
        return JsValue.undefined()
    }
}

/// VirtualMachine — 虚拟机
public class VirtualMachine {
    public init() {}

    public func getHttpProxy(isHttps: Bool, host: ?String, port: ?String): ?String {
        return None
    }
}

/// JSGlobalObject — JS 全局对象 (Store.rs 使用)
public class JSGlobalObject {
    public init() {}

    public func bunVm(): VirtualMachine {
        return VirtualMachine()
    }
}

/// SizeType — Blob 大小类型
public type BlobSizeType = Int64

// ============================================================================
// Disambiguation aliases and stubs for types used across blob files
// ============================================================================

/// Mode — file permission mode (disambiguated stub)
/// In Bun this is a platform-specific file mode type alias
public type Mode = UInt32

/// Stat — file stat result (stub)
/// Corresponds to Bun: std.posix.Stat or similar
public class Stat {
    public var stMode: UInt64
    public var stSize: Int64
    /// Last modification time - seconds since epoch
    /// Corresponds to: Bun: stat.mtime().sec
    public var mtimSec: Int64
    /// Last modification time - nanoseconds component
    /// Corresponds to: Bun: stat.mtime().nsec
    public var mtimNsec: Int64

    public init() {
        stMode = 0
        stSize = 0
        mtimSec = 0
        mtimNsec = 0
    }

    /// Convert mtime to JavaScript timestamp (milliseconds since ECMAScript epoch)
    /// Corresponds to: Bun: jsc.toJSTime(stat.mtime().sec, stat.mtime().nsec)
    /// JavaScript Date uses milliseconds since 1970-01-01 00:00:00 UTC
    public func mtimeMs(): Float64 {
        return Float64(mtimSec) * 1000.0 + Float64(mtimNsec) / 1000000.0
    }
}

/// SyscallTag — identifies which syscall produced an error
/// Corresponds to: Bun: copy_file.rs / read_file.rs / write_file.rs SyscallTag
public enum SyscallTag {
    | open
    | read
    | write
    | fstat
    | sendfile
    | copyFileRange
    | splice
    | copyfile
    | chmod
    | mkdir
}

/// SyscallErrno — syscall error numbers
/// Corresponds to: Bun: errno constants
public enum SyscallErrno {
    | SUCCESS
    | EINVAL
    | EISDIR
    | ENOSYS
    | EXDEV
    | ENOTSUP
    | ENOENT
    | ECONNREFUSED
    | ENOMEM
    | EAGAIN

    public func toInt(): Int32 {
        match (this) {
            case SUCCESS => 0
            case EINVAL => 22
            case EISDIR => 21
            case ENOSYS => 38
            case EXDEV => 18
            case ENOTSUP => 95
            case ENOENT => 2
            case ECONNREFUSED => 111
            case ENOMEM => 12
            case EAGAIN => 11
        }
    }
}

/// SyscallError — syscall error with tag context
/// Corresponds to: Bun: SyscallError used in copy/read/write_file
public class SyscallError {
    public var errno: Int32
    public var syscall: SyscallTag
    public var message: String
    public var path: String

    public init() {
        errno = 0
        syscall = SyscallTag.read
        message = ""
        path = ""
    }

    public init(errno: Int32, syscall: SyscallTag) {
        this.errno = errno
        this.syscall = syscall
        message = ""
        path = ""
    }

    public static func fromErrno(errno: Int32, syscall: SyscallTag): SyscallError {
        return SyscallError(errno, syscall)
    }

    public static func fromCode(errno: SyscallErrno, syscall: SyscallTag): SyscallError {
        return SyscallError(errno.toInt(), syscall)
    }

    public func toSystemError(): SystemError {
        return SystemError()
    }

    public func clone(): SyscallError {
        return SyscallError(errno, syscall)
    }

    public func withPath(path: String): SyscallError {
        return SyscallError(errno, syscall)
    }

    public func withFd(fd: Int64): SyscallError {
        return SyscallError(errno, syscall)
    }

    public func isNoent(): Bool {
        return errno == SyscallErrno.ENOENT.toInt()
    }

    public func toJsWithAsyncStack(global: JsGlobalObject, path: String, promise: ?JsValue): JsValue {
        return JsValue.undefined()
    }

    public func toJsWithAsyncStack(global: JsGlobalObject, promise: JSPromiseStrong): JsValue {
        return JsValue.undefined()
    }

    public func getErrno(): SyscallErrno {
        match (errno) {
            case 22 => SyscallErrno.EINVAL
            case 21 => SyscallErrno.EISDIR
            case 38 => SyscallErrno.ENOSYS
            case 18 => SyscallErrno.EXDEV
            case 95 => SyscallErrno.ENOTSUP
            case 2 => SyscallErrno.ENOENT
            case 111 => SyscallErrno.ECONNREFUSED
            case 12 => SyscallErrno.ENOMEM
            case 11 => SyscallErrno.EAGAIN
            case _ => SyscallErrno.SUCCESS
        }
    }
}

/// ErrorCase — error handling strategy for file ops
public enum ErrorCase {
    | CloseOnFail
    | None_
}

/// Retry — result of mkdirp retry logic
public enum Retry {
    | Continue
    | Fail
    | No
}

/// ClosingState — file operation state
public enum ClosingState {
    | running
    | closing
    | closed

    public func toUInt8(): UInt8 {
        match (this) {
            case running => 0
            case closing => 1
            case closed => 2
        }
    }
}

public let CLOSING_STATE_RUNNING: UInt8 = 0
public let CLOSING_STATE_CLOSING: UInt8 = 1
public let CLOSING_STATE_CLOSED: UInt8 = 2

/// SyscallResult — result of a syscall
public enum SyscallResult<T> {
    | Ok(T)
    | Err(SyscallError)
}

/// Blob — Blob stub (defined in webcore but used locally in blob package)
public class Blob {
    public var store: ?StoreRef
    public var size: Int64

    public init() {
        store = None
        size = 0
    }

    public init(data: Array<UInt8>, mime: String) {
        store = None
        size = Int64(data.size)
    }

    public static func writeFileWithSourceDestination(
        global: JsGlobalObject,
        src: Blob,
        dest: Blob,
        opts: WriteFileOptions
    ): ?JsValue {
        return None
    }

    public func sharedView(): Array<UInt8> {
        return []
    }

    public func detach(): Unit {
        store = None
    }

    public func refStore(): Unit {}
    public func derefStore(): Unit {}

    public func storePathlike(): PathOrFileDescriptor {
        match (store) {
            case Some(s) =>
                match (s.store) {
                    case Some(st) =>
                        match (st.data) {
                            case Data.File(f) => f.pathlike
                            case _ => PathOrFileDescriptor.Path(PathString())
                        }
                    case None => PathOrFileDescriptor.Path(PathString())
                }
            case None => PathOrFileDescriptor.Path(PathString())
        }
    }

    public static func mkdirIfNotExists(
        target: Any,
        err: SyscallError,
        path: String,
        pathBytes: Array<UInt8>
    ): Retry {
        return Retry.No
    }
}

/// WriteFileOptions — options for file writing
public class WriteFileOptions {
    public var mkdirpIfExists: ?Bool

    public init() {
        mkdirpIfExists = None
    }

    public init(mkdirpIfExists: ?Bool) {
        this.mkdirpIfExists = mkdirpIfExists
    }
}

/// SystemError — system error with extended context
/// Corresponds to: Bun: jsc.SystemError
public class SystemError {
    public var errno: Int32
    public var code: String
    public var message: String
    public var path: String
    public var syscall: String
    public var hostname: String
    public var fd: Int64
    public var dest: String

    public init() {
        errno = 0
        code = ""
        message = ""
        path = ""
        syscall = ""
        hostname = ""
        fd = -1
        dest = ""
    }

    public init(errno: Int32, code: String, message: String, path: String, syscall: String,
                hostname: String, fd: Int64, dest: String) {
        this.errno = errno
        this.code = code
        this.message = message
        this.path = path
        this.syscall = syscall
        this.hostname = hostname
        this.fd = fd
        this.dest = dest
    }

    public init(code: String, message: String, path: String, syscall: String) {
        errno = 0
        this.code = code
        this.message = message
        this.path = path
        this.syscall = syscall
        hostname = ""
        fd = -1
        dest = ""
    }

    public init(code: String, path: String, message: String, syscall: String, errno: Int32) {
        this.errno = errno
        this.code = code
        this.message = message
        this.path = path
        this.syscall = syscall
        hostname = ""
        fd = -1
        dest = ""
    }

    public init(errnoVal: Int32, message: String, syscall: String, path: String, code: String) {
        errno = errnoVal
        this.code = code
        this.message = message
        this.path = path
        this.syscall = syscall
        hostname = ""
        fd = -1
        dest = ""
    }

    public func isEmpty(): Bool {
        return message.isEmpty() && code.isEmpty()
    }

    public func toErrorInstanceWithAsyncStack(global: JsGlobalObject, promise: JSPromiseStrong): JsValue {
        return JsValue.undefined()
    }

    public func toJs(global: JsGlobalObject): JsValue {
        return JsValue.undefined()
    }
}

/// SystemError stub — re-exported here for blob package use
/// (The store.cj already has SystemError references from JscSystemError)
public class SystemError2 {
    public var errno: Int32
    public var code: String
    public var message: String
    public var path: String
    public var syscall: String
    public var hostname: String
    public var fd: Int64
    public var dest: String

    public init() {
        errno = 0
        code = ""
        message = ""
        path = ""
        syscall = ""
        hostname = ""
        fd = -1
        dest = ""
    }

    public init(errno: Int32, code: String, message: String, path: String, syscall: String,
                hostname: String, fd: Int64, dest: String) {
        this.errno = errno
        this.code = code
        this.message = message
        this.path = path
        this.syscall = syscall
        this.hostname = hostname
        this.fd = fd
        this.dest = dest
    }
}

/// BunSys stub — system calls used by blob operations
/// These provide a layer over bao_sys functions
public class BunSys {
    public static let PREALLOCATE_SUPPORTED: Bool = true
    public static let O_CLOEXEC: Int32 = 0x80000
    public static let O_RDONLY: Int32 = 0
    public static let O_WRONLY: Int32 = 1
    public static let O_CREAT: Int32 = 64
    public static let O_TRUNC: Int32 = 512
    public static let O_NONBLOCK: Int32 = 2048
    public static let O_APPEND: Int32 = 1024

    public static func fstat(fd: Fd): BunSysResult<Stat> { BunSysResult<Stat>.Ok(Stat()) }
    public static func open(path: String, flags: Int32, mode: Int32): BunSysResult<Fd> { BunSysResult<Fd>.Ok(Fd.INVALID) }
    public static func fchmod(fd: Fd, mode: UInt32): BunSysResult<Unit> { BunSysResult<Unit>.Ok(()) }
    public static func preallocateFile(fd: Int32, off: Int64, len: Int64): Int32 { 0 }
    public static func copyFileRange(fdIn: Int32, offIn: UIntNative, fdOut: Int32, offOut: UIntNative, len: Int64, flags: Int32): Int64 { -1 }
    public static func sendfile(outFd: Int32, inFd: Int32, off: UIntNative, len: Int64): Int64 { -1 }
    public static func splice(fdIn: Int32, offIn: UIntNative, fdOut: Int32, offOut: UIntNative, len: Int64, flags: Int32): Int64 { -1 }
    public static func getErrno(result: Int64): SyscallErrno { SyscallErrno.SUCCESS }
    public static func canUseCopyFileRangeSyscall(): Bool { false }
    public static func isDir(mode: UInt64): Bool { (mode & 0o170000) == 0o040000 }
    public static func isRegularFile(mode: UInt64): Bool { (mode & 0o170000) == 0o100000 }
    public static func isFifo(mode: UInt64): Bool { (mode & 0o170000) == 0o010000 }
    public static func isChr(mode: UInt64): Bool { (mode & 0o170000) == 0o020000 }
    public static func isSock(mode: UInt64): Bool { (mode & 0o170000) == 0o140000 }
    public static func close(fd: Fd): Unit {}
    public static func truncatePath(path: String, size: Int64): Unit {}
    public static func setFileOffset(fd: Fd, offset: Int64): Unit {}
    public static func ftruncate(fd: Int32, size: Int64): Int32 { 0 }
    public static func fcntlGetFl(fd: Int32): Int32 { 0 }
    public static func fcntlSetFl(fd: Int32, flags: Int32): Int32 { 0 }
    public static func mkdirRecursive(path: String): Int32 { 0 }
    public static func openPath(path: String, flags: Int64, mode: Int32): Result<Fd, SyscallError> { Result.Err(SyscallError()) }
    public static func recvNonBlock(fd: Fd, buf: Array<UInt8>): SyscallResult<Int64> { SyscallResult.Ok(0) }
    public static func read(fd: Fd, buf: Array<UInt8>): SyscallResult<Int64> { SyscallResult.Ok(0) }
    public static func write(fd: Fd, buf: Array<UInt8>): SyscallResult<Int64> { SyscallResult.Ok(0) }
}

/// BunSysResult — result of a BunSys call
public enum BunSysResult<T> {
    | Ok(T)
    | Err(SyscallError)
}

/// BunCore — core utilities stub
public class BunCore {
    public static func errnoToZigErr(errno: Int32): BaoError { BaoError() }
    public static func errnoToZigErr(errno: SyscallErrno): BaoError { BaoError() }
    public static func errOutOfMemory(): BaoError { BaoError() }
    public static func errEisDir(): BaoError { BaoError() }
    public static func isReadable(fd: Fd): Pollable { Pollable.Ready }
    public static func isWritable(fd: Fd): Pollable { Pollable.Ready }
}

/// BaoError — generic error stub
public class BaoError {
    public init() {}
    public static func fromErrno(errno: Int32): BaoError { BaoError() }
    public static let EISDIR: BaoError = BaoError()
}

/// NodeFs — node fs operations stub
public class NodeFs {
    public static let DEFAULT_PERMISSION: UInt32 = 0o644

    public static func copyFileUsingReadWriteLoop(
        src: String, dest: String,
        srcFd: Fd, destFd: Fd,
        remain: Int64, written: UInt64
    ): BunSysResult<Unit> { BunSysResult<Unit>.Ok(()) }
}

/// JscSystemError — JS system error
public class JscSystemError {
    public var errno: Int32
    public var code: String
    public var message: String
    public var path: String
    public var syscall: String
    public var hostname: String
    public var fd: Int64
    public var dest: String

    public init() {
        errno = 0
        code = ""
        message = ""
        path = ""
        syscall = ""
        hostname = ""
        fd = -1
        dest = ""
    }

    public init(errno: Int32, code: String, message: String, path: String, syscall: String,
                hostname: String, fd: Int64, dest: String) {
        this.errno = errno
        this.code = code
        this.message = message
        this.path = path
        this.syscall = syscall
        this.hostname = hostname
        this.fd = fd
        this.dest = dest
    }

    public func toErrorInstanceWithAsyncStack(global: JsGlobalObject, promise: JSPromiseStrong): JsValue {
        return JsValue.undefined()
    }

    public func toErrorInstance(global: JsGlobalObject): JsValue {
        return JsValue.undefined()
    }
}

/// ZStr — zero-terminated string
public class ZStr {
    public static let EMPTY: String = ""
}

/// UvBufT — libuv buffer type
public class UvBufT {
    public var len: UInt32
    public var base: CPointer<UInt8>

    public init(len: UInt32, base: CPointer<UInt8>) {
        this.len = len
        this.base = base
    }
}

/// UvStatT — libuv stat type
public class UvStatT {
    public var size: Int64
    public var mode: UInt64

    public init() {
        size = 0
        mode = 0
    }

    public static func fromCPointer(ptr: CPointer<Unit>): UvStatT {
        return UvStatT()
    }
}

/// PosixUtil — POSIX utility functions
public class PosixUtil {
    public static func isDir(mode: UInt64): Bool { (mode & 0o170000) == 0o040000 }
    public static func isRegularFile(mode: UInt64): Bool { (mode & 0o170000) == 0o100000 }
}

/// MathUtil — math utility functions
public class MathUtil {
    public static func clamp(v: Int64, min: Int64, max: Int64): Int64 {
        if (v < min) { return min }
        if (v > max) { return max }
        return v
    }
    public static func min(a: Int64, b: Int64): Int64 {
        if (a < b) { return a }
        return b
    }
    public static let MAX_UINT32: Int64 = 4294967295
}

/// PathUtil — path utility functions
public class PathUtil {
    public static func dirname(path: String): String {
        let optIdx = path.lastIndexOf('/')
        if (optIdx.isNone()) { return "." }
        let idx = optIdx.getOrThrow()
        if (idx == 0) { return "/" }
        return path[0..idx]
    }
}

/// AsyncMkdirp — async mkdirp scheduler
public class AsyncMkdirp {
    public static func schedule(dirPath: String, onComplete: CPointer<Unit>, context: CPointer<Unit>): Unit {}
}

/// UV constants
public let UV_ENOENT: Int32 = -2
public let UV_EPERM: Int32 = -1
public let UV_EINVAL: Int32 = -22

/// UV FS O_ constants
public class UV_FS_O {
    public static let CREAT: Int32 = 64
    public static let WRONLY: Int32 = 1
    public static let TRUNC: Int32 = 512
}

/// StoreRef extension methods — ref/deref helpers
public func StoreRefRef(s: StoreRef): Unit {
    match (s.store) {
        case Some(st) => st.getRefCount()
        case None => ()
    }
}

/// StoreRef deref helper
public func StoreRefDeref(s: StoreRef): Unit {
    match (s.store) {
        case Some(st) => st.deref()
        case None => ()
    }
}

/// libuv FFI declarations for blob package
/// Note: String path params use CPointer<Unit> for stubs since CString requires CType
@C
foreign func uv_fs_copyfile(
    loop: CPointer<Unit>,
    req: CPointer<Unit>,
    newPath: CPointer<Unit>,
    oldPath: CPointer<Unit>,
    flags: Int32,
    cb: CPointer<Unit>
): Int32

@C
foreign func uv_fs_chmod(
    loop: CPointer<Unit>,
    req: CPointer<Unit>,
    path: CPointer<Unit>,
    mode: Int32,
    cb: CPointer<Unit>
): Int32

@C
foreign func uv_fs_open(
    loop: CPointer<Unit>,
    req: CPointer<Unit>,
    path: CPointer<Unit>,
    flags: Int32,
    mode: Int32,
    cb: CPointer<Unit>
): Int32

@C
foreign func uv_fs_write(
    loop: CPointer<Unit>,
    req: CPointer<Unit>,
    file: Int32,
    bufs: CPointer<Unit>,
    nbufs: UInt32,
    offset: Int64,
    cb: CPointer<Unit>
): Int32

@C
foreign func uv_fs_read(
    loop: CPointer<Unit>,
    req: CPointer<Unit>,
    file: Int32,
    bufs: CPointer<Unit>,
    nbufs: UInt32,
    offset: Int64,
    cb: CPointer<Unit>
): Int32

@C
foreign func uv_fs_fstat(
    loop: CPointer<Unit>,
    req: CPointer<Unit>,
    file: Int32,
    cb: CPointer<Unit>
): Int32

@C
foreign func uv_fs_req_cleanup(req: CPointer<Unit>): Unit

@C
foreign func uv_fs_get_result(req: CPointer<Unit>): Int64

@C
foreign func uv_fs_get_statbuf(req: CPointer<Unit>): CPointer<Unit>

@C
foreign func uv_req_get_data(req: CPointer<Unit>): CPointer<Unit>

@C
foreign func uv_req_set_data(req: CPointer<Unit>, data: CPointer<Unit>): Unit

// ported from: src/runtime/webcore/blob/Store.rs

/// BLOB_MAX_SIZE — maximum blob size constant
/// Corresponds to: Bun: std.math.maxInt(i64) ≈ 9223372036854775807
public let BLOB_MAX_SIZE: BlobSizeType = 9223372036854775807

/// min — return minimum of two Int64 values
public func min(a: Int64, b: Int64): Int64 {
    if (a < b) { return a } else { return b }
}

/// max — return maximum of two Int64 values
public func max(a: Int64, b: Int64): Int64 {
    if (a > b) { return a } else { return b }
}

/// BlobLifetime — blob data lifetime hint
/// Corresponds to: Bun: blob lifetime enum
public enum BlobLifetime {
    | Temporary   // caller must take ownership
    | Borrowed    // borrowed reference, valid for the call
}

/// JsGlobalObject — alias for JSGlobalObject (local stub in this package)
public type JsGlobalObject = JSGlobalObject

/// JsPromise — local stub for JS Promise
public class JsPromise {
    public init() {}
    public func resolve(global: JsGlobalObject, value: JsValue): Unit {}
    public func reject(global: JsGlobalObject, value: JsValue): Unit {}
    public func swap(): JsPromise { return this }
}

/// BaoString — string stub (simplified from bao_core.BaoString)
/// Used where Bun code expects BaoString-specific methods
public class BaoString {
    public var value: String

    public init() {
        value = ""
    }

    public init(s: String) {
        value = s
    }

    public static func static_(s: String): String {
        return s
    }

    public static func cloneUtf8(s: String): String {
        return s
    }

    public static let EMPTY: String = ""

    public func isEmpty(): Bool {
        return value.isEmpty()
    }

    public func toErrorInstance(global: JsGlobalObject): JsValue {
        return JsValue(value)
    }

    public func slice(): String {
        return value
    }

    public func asBytes(): Array<UInt8> {
        return stringToBytes(value)
    }
}
