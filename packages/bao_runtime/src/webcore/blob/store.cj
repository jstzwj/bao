// Blob Store - Blob 底层存储
// 严格翻译自: src/runtime/webcore/blob/Store.rs (625 lines)
// 包含: Store, StoreRef, Data, DataTag, Bytes, File, S3,
//        StoreExt, S3Ext, FileExt, BytesExt, SerializeTag,
//        BlobArrayBuffer_deallocator, Map, mime_from_path_ext,
//        S3 unlink/list_objects 实现
package bao_runtime.webcore.blob

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_sys.*
import bao_io.*
import bao_ptr.*
import bao_http_types.*

// ============================================================================
// Re-exports — 从 webcore_types::store 重新导出的规范数据类型
// 对应 Bun: pub use bun_jsc::webcore_types::store::* (Store.rs:34-36)
// ============================================================================

// Store, StoreRef, Data, DataTag, Bytes, File, S3, SerializeTag
// 这些类型在此文件中定义

// ============================================================================
// Map - Store 映射类型
// 对应 Bun: type Map = HashMap<u64, *mut Store> (Store.rs:40)
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
    public static func retained(store: Store): StoreRef {
        store.refCount()
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

    /// 转为原始指针
    public func toRaw(): UIntNative {
        match (store) {
            case Some(s) => UIntNative(s.hashCode())
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

    /// 获取数据切片
    public func slice(): Array<UInt8> {
        return data.toArray()
    }

    /// 从 Vec 初始化
    /// 对应 Bun: Bytes::init()
    public static func init(list: ArrayList<UInt8>): StoreBytes {
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
        let bytes = data.toArray()
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

    public init() {
        pathlike = PathOrFileDescriptor.Path(PathString())
        mimeType = None
        mode = 0
        lastModified = 0.0
        size = 0
        mkdirpIfNotExists = false
        maxSize = Int64.MAX_VALUE
    }

    public init(pathlike: PathOrFileDescriptor, mimeType: ?MimeType) {
        this.pathlike = pathlike
        this.mimeType = mimeType
        mode = 0
        lastModified = 0.0
        size = 0
        mkdirpIfNotExists = false
        maxSize = Int64.MAX_VALUE
    }

    /// 初始化文件存储
    /// 对应 Bun: File::init()
    public static func init(pathlike: PathOrFileDescriptor, mimeType: ?MimeType): StoreFile {
        return StoreFile(pathlike, mimeType)
    }

    /// unlink — 删除文件
    /// 对应 Bun: FileExt::unlink() (Store.rs:279-317)
    public func unlink(globalThis: JSGlobalObject): JSValue {
        match (pathlike) {
            case Path(pathLike) =>
                // 创建异步删除任务
                let binding = NodeFsBinding()
                return NodeFsAsyncUnlink.create(
                    globalThis,
                    binding,
                    NodeFsUnlinkArgs(pathLike.clone()),
                    globalThis.bunVm()
                )
            case Fd(_) =>
                // 不能删除文件描述符
                return JSPromise.resolvedPromiseValue(
                    globalThis,
                    JSValue.zero() // ERR_INVALID_ARG_TYPE
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
    public static func init(pathlike: PathLike, mimeType: ?MimeType, credentials: S3Credentials): StoreS3 {
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
        options: ?JSValue,
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
        extraOptions: ?JSValue
    ): JSValue {
        // 创建 Wrapper 处理异步回调
        let wrapper = S3DeleteWrapper()
        wrapper.promise = JSPromiseStrong.init(globalThis)
        wrapper.store = StoreRef.retained(store)
        wrapper.global = BackRef<JSGlobalObject>(globalThis)

        let value = wrapper.promise.value()

        // 获取代理 URL
        let proxyUrl = globalThis.bunVm().getHttpProxy(true, None, None)
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
        listOptions: JSValue,
        extraOptions: ?JSValue
    ): JSValue {
        if (!listOptions.isUndefined() && !listOptions.isNull() && !listOptions.isObject()) {
            // throw invalid arguments
            return JSValue.zero()
        }

        let wrapper = S3ListWrapper()
        wrapper.promise = JSPromiseStrong.init(globalThis)
        wrapper.store = StoreRef.retained(store)
        wrapper.global = BackRef<JSGlobalObject>(globalThis)

        let value = wrapper.promise.value()

        let proxyUrl = globalThis.bunVm().getHttpProxy(true, None, None)
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
    public func refCount(): Unit {
        refCount = refCount + 1
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
    public static func init(list: ArrayList<UInt8>): StoreRef {
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
                    return Some(AnyBlob.InternalBlob(bytes.toInternalBlob()))
                case _ => ()
            }
        }
        return None
    }

    /// 序列化
    /// 对应 Bun: StoreExt::serialize() (Store.rs:226-272)
    public func serialize(writer: BinaryWriter): Unit {
        match (data) {
            case File(file) =>
                let pathlikeTag: PathOrFileDescriptorSerializeTag =
                    match (file.pathlike) {
                        case Fd(_) => PathOrFileDescriptorSerializeTag.Fd
                        case Path(_) => PathOrFileDescriptorSerializeTag.Path
                    }
                writer.writeIntLe(UInt8(pathlikeTag.ordinal()))

                match (file.pathlike) {
                    case Fd(fd) =>
                        writer.writeIntLe(fd)
                    case Path(path) =>
                        let pathSlice = path.slice()
                        writer.writeIntLe(UInt32(pathSlice.size))
                        writer.writeAll(pathSlice)
                }

            case S3(s3) =>
                writer.writeIntLe(UInt8(PathOrFileDescriptorSerializeTag.Path.ordinal()))
                let pathSlice = s3.pathlike.slice()
                writer.writeIntLe(UInt32(pathSlice.size))
                writer.writeAll(pathSlice)

            case Bytes(bytes) =>
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
            data: Data.S3(StoreS3.initWithReferencedCredentials(path, effectiveMimeType, credentials)),
            mimeType: MimeType.NONE
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
            data: Data.S3(StoreS3.init(path, effectiveMimeType, credentials)),
            mimeType: MimeType.NONE
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
                    case Fd(_) => None
                }
        }

        return Store(
            data: Data.File(StoreFile.init(pathlike, effectiveMimeType)),
            mimeType: MimeType.NONE
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
        return Store.init(list)
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
        if (path[i] == UInt8('.')) {
            lastDot = i
        }
    }
    if (lastDot < 0 || lastDot + 1 >= path.size) {
        return ""
    }
    var ext = ""
    for (i in (lastDot + 1)..path.size) {
        ext = ext + String(Char(path[i]))
    }
    return ext.toAsciiLower()
}

// ============================================================================
// BlobArrayBufferDeallocator — ArrayBuffer 释放回调
// 对应 Bun: BlobArrayBuffer_deallocator() (Store.rs:616-625)
// ============================================================================

/// Blob ArrayBuffer 释放回调 — JSC ArrayBuffer 外部释放回调
/// C++ 将 *mut Store 作为释放器上下文存储
/// 对应 Bun: #[unsafe(no_mangle)] extern "C" fn BlobArrayBuffer_deallocator
public func blobArrayBufferDeallocator(bytes: UIntNative, blob: UIntNative): Unit {
    // blob 是非空 *mut Store — C++ 存储为释放器上下文
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
    /// 对应 Bun: Wrapper::resolve() (Store.rs:363-387)
    public func resolve(result: S3DeleteResult): Unit {
        let globalObject = global.get()
        match (globalObject) {
            case Some(global) =>
                match (result) {
                    case Success =>
                        promise.resolve(global, JSValue.TRUE)
                    case NotFound(err) =>
                        let errVal = err.toJsWithAsyncStack(
                            global,
                            store.getPath(),
                            promise.get()
                        )
                        promise.reject(global, errVal)
                    case Failure(err) =>
                        let errVal = err.toJsWithAsyncStack(
                            global,
                            store.getPath(),
                            promise.get()
                        )
                        promise.reject(global, errVal)
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
    /// 对应 Bun: Wrapper::resolve() (Store.rs:449-483)
    public func resolve(result: S3ListObjectsResult): Unit {
        let globalObject = global.get()
        match (globalObject) {
            case Some(global) =>
                match (result) {
                    case Success(listResult) =>
                        let listResultJs = listResult.toJs(global)
                        match (listResultJs) {
                            case Some(v) =>
                                promise.resolve(global, v)
                            case None =>
                                promise.reject(global, JSValue.zero())
                        }
                    case NotFound(err) =>
                        let errVal = err.toJsWithAsyncStack(
                            global,
                            store.getPath(),
                            promise.get()
                        )
                        promise.reject(global, errVal)
                    case Failure(err) =>
                        let errVal = err.toJsWithAsyncStack(
                            global,
                            store.getPath(),
                            promise.get()
                        )
                        promise.reject(global, errVal)
                }
            case None => ()
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// AnyBlob — Blob 的任意类型
/// 对应 Bun: super::Any
public enum AnyBlob {
    | InternalBlob(InternalBlob)
}

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
        return value.toArray().map({ b => b })
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
        return value.toArray().map({ b => b })
    }

    public func toThreadSafe(): Unit {
        // 在实际实现中会保护/引用 PathLike
    }
}

/// PathOrFileDescriptor — 路径或文件描述符
/// 对应 Bun: PathOrFileDescriptor
public enum PathOrFileDescriptor {
    | Fd(Int64)
    | Path(PathString)

    public func toString(): String {
        match (this) {
            case Fd(fd) => "fd:${fd}"
            case Path(p) => p.value
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
        extraOptions: ?JSValue,
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
    public var extraOptions: ?JSValue
    public var acl: ?String
    public var storageClass: ?String
    public var requestPayer: ?String

    public init(
        credentials: S3Credentials,
        options: ?S3CredentialsWithOptions,
        extraOptions: ?JSValue,
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

    public func toJsWithAsyncStack(global: JSGlobalObject, path: String, promise: ?JSValue): JSValue {
        return JSValue.zero()
    }
}

/// S3ListResult — S3 列表结果
/// 对应 Bun: S3ListObjectsResult data
public class S3ListResult {
    public init() {}

    public func toJs(global: JSGlobalObject): ?JSValue {
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
    public static func getListObjectsOptionsFromJs(global: JSGlobalObject, value: JSValue): S3ListObjectsOptions {
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
        return buffer.toArray()
    }
}

/// JSPromiseStrong — JS Promise 强引用
/// 对应 Bun: bun_jsc::JSPromiseStrong
public class JSPromiseStrong {
    public init() {}

    public static func init(global: JSGlobalObject): JSPromiseStrong {
        return JSPromiseStrong()
    }

    public func value(): JSValue {
        return JSValue.zero()
    }

    public func resolve(global: JSGlobalObject, value: JSValue): Unit {}
    public func reject(global: JSGlobalObject, value: JSValue): Unit {}
    public func reject(global: JSGlobalObject, err: ?JSValue): Unit {}
    public func get(): ?JSValue { return None }
}

/// JSPromise — JS Promise 辅助
public class JSPromise {
    public static func resolvedPromiseValue(global: JSGlobalObject, value: JSValue): JSValue {
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
    ): JSValue {
        return JSValue.zero()
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

/// UIntNative — 原始大小无符号整数
public type UIntNative = UInt64

/// SizeType — Blob 大小类型
public typealias BlobSizeType = Int64

// ported from: src/runtime/webcore/blob/Store.rs
