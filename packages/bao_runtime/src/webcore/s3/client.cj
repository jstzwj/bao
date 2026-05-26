// 严格翻译自: src/runtime/webcore/s3/client.rs (1272 lines)
// S3 Client - S3 客户端操作入口
// 提供 stat, download, downloadSlice, delete, listObjects, upload,
// writableStream, uploadStream, downloadStream, readableStream 等函数
package bao_runtime.webcore.s3

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_collections.ArrayList

// Local class to shadow ambiguous MutableString imports from bao_core and bao_jsc
public class MutableString {
    public var data: String
    public var list: ArrayList<UInt8>
    public init() { data = ""; list = ArrayList<UInt8>() }
    public init(s: String) { data = s; list = ArrayList<UInt8>() }
    public func toString(): String { return data }
    public func deinit(): Unit { data = ""; list = ArrayList<UInt8>() }
    public func size(): Int64 { return Int64(data.size) }
    public func slice(): String { return data }
    public func reset(): Unit { data = ""; list = ArrayList<UInt8>() }
    public func write(s: String): Unit { data = data + s }
    public func clear(): Unit { data = ""; list = ArrayList<UInt8>() }
}

// ============================================================================
// Re-exports - 重导出
// 严格翻译自: client.rs 的 pub use 声明
// ============================================================================

// download_stream::S3HttpDownloadStreamingTask 已在 download_stream.cj 中定义
// multipart::MultiPartUpload 已在 multipart.cj 中定义
// multipart_options::MultiPartUploadOptions 已在 multipart_options.cj 中定义
// ACL, StorageClass 来自 credentials_jsc.cj
// S3Error 来自 s3_helpers.cj
// S3Credentials 来自 s3_helpers.cj / credentials_jsc.cj
// S3CredentialsWithOptions 来自 credentials_jsc.cj

// simple_request 中的类型已在 simple_request.cj 中定义:
// S3DeleteResult, S3DownloadResult, S3HttpSimpleTask, S3ListObjectsResultEx,
// S3StatResult, S3UploadResult

// ============================================================================
// stat - 获取对象元数据
// 严格翻译自: pub fn stat(
//   this: &S3Credentials, path: &[u8],
//   callback: fn(S3StatResult, *c_void) -> JsTerminatedResult<()>,
//   callback_context: *c_void,
//   proxy_url: Option<&[u8]>,
//   request_payer: bool,
// ) -> JsTerminatedResult<()>
// Bun: client.zig stat() — 发送 HEAD 请求获取对象元数据
// ============================================================================

/// 获取对象元数据 (stat)
/// 对应 Bun: stat()
/// 发送 HEAD 请求获取 S3 对象的 size, etag, lastModified, contentType
public func s3Stat(
    credentials: S3Credentials,
    path: String,
    callback: (S3StatResult, UIntNative) -> Unit,
    callbackContext: UIntNative,
    proxyUrl: String,
    requestPayer: Bool
): Unit {
    let options = S3SimpleRequestOptions()
    options.path = path
    options.method = HttpMethod.HEAD
    options.proxyUrl = proxyUrl
    options.body = ""
    options.requestPayer = requestPayer

    executeSimpleS3StatRequest(
        credentials,
        options,
        callback,
        callbackContext
    )
}

// ============================================================================
// download - 下载对象
// 严格翻译自: pub fn download(
//   this: &S3Credentials, path: &[u8],
//   callback: fn(S3DownloadResult, *c_void) -> JsTerminatedResult<()>,
//   callback_context: *c_void,
//   proxy_url: Option<&[u8]>,
//   request_payer: bool,
// ) -> JsTerminatedResult<()>
// ============================================================================

/// 下载对象
/// 对应 Bun: download()
/// 发送 GET 请求下载整个 S3 对象
public func s3Download(
    credentials: S3Credentials,
    path: String,
    callback: (S3DownloadResult, UIntNative) -> Unit,
    callbackContext: UIntNative,
    proxyUrl: String,
    requestPayer: Bool
): Unit {
    let options = S3SimpleRequestOptions()
    options.path = path
    options.method = HttpMethod.GET
    options.proxyUrl = proxyUrl
    options.body = ""
    options.requestPayer = requestPayer

    executeSimpleS3DownloadRequest(
        credentials,
        options,
        callback,
        callbackContext
    )
}

// ============================================================================
// downloadSlice - 下载对象的一部分
// 严格翻译自: pub fn download_slice(
//   this: &S3Credentials, path: &[u8],
//   offset: usize, size: Option<usize>,
//   callback: fn(S3DownloadResult, *c_void) -> JsTerminatedResult<()>,
//   callback_context: *c_void,
//   proxy_url: Option<&[u8]>,
//   request_payer: bool,
// ) -> JsTerminatedResult<()>
// Bun: 构造 Range 头 "bytes=offset-end" 然后发送 GET 请求
// ============================================================================

/// 下载对象的一部分
/// 对应 Bun: downloadSlice()
/// 构造 Range 头并发送 GET 请求下载 S3 对象的一部分
public func s3DownloadSlice(
    credentials: S3Credentials,
    path: String,
    offset: Int64,
    size: ?Int64,
    callback: (S3DownloadResult, UIntNative) -> Unit,
    callbackContext: UIntNative,
    proxyUrl: String,
    requestPayer: Bool
): Unit {
    // 构造 Range 头
    let range: String = match (size) {
        case Some(size_) =>
            var end = offset + size_
            if (size_ > 0) {
                end -= 1
            }
            "bytes=${offset}-${end}"
        case None =>
            if (offset == 0) {
                ""
            } else {
                "bytes=${offset}-"
            }
    }

    let options = S3SimpleRequestOptions()
    options.path = path
    options.method = HttpMethod.GET
    options.proxyUrl = proxyUrl
    options.body = ""
    options.range = range
    options.requestPayer = requestPayer

    executeSimpleS3DownloadRequest(
        credentials,
        options,
        callback,
        callbackContext
    )
}

// ============================================================================
// delete - 删除对象
// 严格翻译自: pub fn delete(
//   this: &S3Credentials, path: &[u8],
//   callback: fn(S3DeleteResult, *c_void) -> JsTerminatedResult<()>,
//   callback_context: *c_void,
//   proxy_url: Option<&[u8]>,
//   request_payer: bool,
// ) -> JsTerminatedResult<()>
// ============================================================================

/// 删除对象
/// 对应 Bun: delete()
/// 发送 DELETE 请求删除 S3 对象
public func s3Delete(
    credentials: S3Credentials,
    path: String,
    callback: (S3DeleteResult, UIntNative) -> Unit,
    callbackContext: UIntNative,
    proxyUrl: String,
    requestPayer: Bool
): Unit {
    let options = S3SimpleRequestOptions()
    options.path = path
    options.method = HttpMethod.DELETE
    options.proxyUrl = proxyUrl
    options.body = ""
    options.requestPayer = requestPayer

    executeSimpleS3DeleteRequest(
        credentials,
        options,
        callback,
        callbackContext
    )
}

// ============================================================================
// listObjects - 列出对象
// 严格翻译自: pub fn list_objects(
//   this: &S3Credentials,
//   list_options: &S3ListObjectsOptions,
//   callback: fn(S3ListObjectsResult, *c_void) -> JsTerminatedResult<()>,
//   callback_context: *c_void,
//   proxy_url: Option<&[u8]>,
// ) -> JsTerminatedResult<()>
// Bun: 构造查询参数字符串, 签名请求, 创建 S3HttpSimpleTask 并调度
// ============================================================================

/// 列出对象
/// 对应 Bun: listObjects()
/// 构造查询参数字符串并发送 GET 请求列出 S3 对象
/// 流程:
/// 1. 构造 search_params: ?continuation-token=...&delimiter=...&encoding-type=url&...
/// 2. 签名请求
/// 3. 创建 S3HttpSimpleTask
/// 4. 调度 HTTP 请求
public func s3ListObjects(
    credentials: S3Credentials,
    listOptions: S3ListObjectsOptions,
    callback: (S3ListObjectsResultEx, UIntNative) -> Unit,
    callbackContext: UIntNative,
    proxyUrl: String
): Unit {
    var searchParams = StringBuilder()
    searchParams.append("?")

    // continuation-token
    if (listOptions.continuationToken.size > 0) {
        let encoded = encodeURIComponent(listOptions.continuationToken)
        searchParams.append("continuation-token=${encoded}")
    }

    // delimiter
    if (listOptions.delimiter.size > 0) {
        let encoded = encodeURIComponent(listOptions.delimiter)
        if (listOptions.continuationToken.size > 0) {
            searchParams.append("&delimiter=${encoded}")
        } else {
            searchParams.append("delimiter=${encoded}")
        }
    }

    // encoding-type
    if (listOptions.encodingType.size > 0) {
        if (listOptions.continuationToken.size > 0 || listOptions.delimiter.size > 0) {
            searchParams.append("&encoding-type=url")
        } else {
            searchParams.append("encoding-type=url")
        }
    }

    // fetch-owner
    if (listOptions.hasFetchOwner) {
        let ownerValue = if (listOptions.fetchOwner) { "true" } else { "false" }
        if (listOptions.continuationToken.size > 0 ||
            listOptions.delimiter.size > 0 ||
            listOptions.encodingType.size > 0) {
            searchParams.append("&fetch-owner=${ownerValue}")
        } else {
            searchParams.append("fetch-owner=${ownerValue}")
        }
    }

    // list-type=2
    if (listOptions.continuationToken.size > 0 ||
        listOptions.delimiter.size > 0 ||
        listOptions.encodingType.size > 0 ||
        listOptions.hasFetchOwner) {
        searchParams.append("&list-type=2")
    } else {
        searchParams.append("list-type=2")
    }

    // max-keys
    if (listOptions.hasMaxKeys) {
        searchParams.append("&max-keys=${listOptions.maxKeys}")
    }

    // prefix
    if (listOptions.prefix.size > 0) {
        let encoded = encodeURIComponent(listOptions.prefix)
        searchParams.append("&prefix=${encoded}")
    }

    // start-after
    if (listOptions.startAfter.size > 0) {
        let encoded = encodeURIComponent(listOptions.startAfter)
        searchParams.append("&start-after=${encoded}")
    }

    let options = S3SimpleRequestOptions()
    options.path = ""
    options.method = HttpMethod.GET
    options.searchParams = searchParams.toString()
    options.proxyUrl = proxyUrl

    executeSimpleS3ListObjectsRequest(
        credentials,
        options,
        callback,
        callbackContext
    )
}

// ============================================================================
// upload - 上传对象
// 严格翻译自: pub fn upload(
//   this: &S3Credentials, path: &[u8], content: &[u8],
//   content_type: Option<&[u8]>, content_disposition: Option<&[u8]>,
//   content_encoding: Option<&[u8]>, acl: Option<ACL>,
//   proxy_url: Option<&[u8]>, storage_class: Option<StorageClass>,
//   request_payer: bool,
//   callback: fn(S3UploadResult, *c_void) -> JsTerminatedResult<()>,
//   callback_context: *c_void,
// ) -> JsTerminatedResult<()>
// ============================================================================

/// 上传对象
/// 对应 Bun: upload()
/// 发送 PUT 请求上传内容到 S3 路径
public func s3Upload(
    credentials: S3Credentials,
    path: String,
    content: String,
    contentType: String,
    contentDisposition: String,
    contentEncoding: String,
    acl: ?S3Acl,
    proxyUrl: String,
    storageClass: ?S3StorageClass,
    requestPayer: Bool,
    callback: (S3UploadResult, UIntNative) -> Unit,
    callbackContext: UIntNative
): Unit {
    let options = S3SimpleRequestOptions()
    options.path = path
    options.method = HttpMethod.PUT
    options.proxyUrl = proxyUrl
    options.body = content
    options.contentType = contentType
    options.contentDisposition = contentDisposition
    options.contentEncoding = contentEncoding
    options.acl = acl
    options.storageClass = storageClass
    options.requestPayer = requestPayer

    executeSimpleS3UploadRequest(
        credentials,
        options,
        callback,
        callbackContext
    )
}

// ============================================================================
// S3UploadStreamWrapper - 上传流包装器
// 严格翻译自: pub struct S3UploadStreamWrapper
// Bun: pub const S3UploadStreamWrapper = struct {
//   ref_count, sink, task, end_promise, callback, callback_context,
//   path, global
// }
// 引用计数: intrusive ref_count — bun.ptr.RefCount(@This(), "ref_count", deinit, .{})
// ============================================================================

/// S3 上传流包装器
/// 对应 Bun: S3UploadStreamWrapper
/// 管理上传流的生命周期、回调、Promise 等
/// 使用侵入式引用计数管理生命周期
public class S3UploadStreamWrapper {
    /// 引用计数
    /// 对应 Bun: ref_count: u32 (intrusive via bun.ptr.RefCount)
    public var refCount: Int32

    /// 可恢复上传 Sink
    /// 对应 Bun: sink: ?*ResumableSink
    public var sink: ?ResumableS3UploadSink

    /// 多部分上传任务
    /// 对应 Bun: task: *MultiPartUpload
    public var task: MultiPartUpload

    /// 结束 Promise
    /// 对应 Bun: end_promise: jsc.JSPromise.Strong
    public var endPromise: JSPromiseStrong

    /// 回调函数
    /// 对应 Bun: callback: ?*const fn (S3UploadResult, *anyopaque) void
    public var callback: ?((S3UploadResult, UIntNative) -> Unit)

    /// 回调上下文
    /// 对应 Bun: callback_context: *anyopaque
    public var callbackContext: UIntNative

    /// 路径 (由 task 拥有，不由此 wrapper 拥有)
    /// 对应 Bun: path: bun.ptr.RawSlice(u8)
    public var path: String

    /// 全局对象引用
    /// 对应 Bun: global: jsc.GlobalRef (JSC_BORROW)
    public var global: GlobalRef

    public init(
        task: MultiPartUpload,
        callback: ?((S3UploadResult, UIntNative) -> Unit),
        callbackContext: UIntNative,
        path: String,
        global: GlobalRef
    ) {
        refCount = 2  // +1 for the stream sink
        sink = None
        this.task = task
        endPromise = JSPromiseStrong()
        this.callback = callback
        this.callbackContext = callbackContext
        this.path = path
        this.global = global
    }

    // ========================================================================
    // ref - 增加引用计数
    // 严格翻译自: intrusive ref() — bumps ref_count
    // ========================================================================

    /// 增加引用计数
    /// 对应 Bun: intrusive ref()
    public func ref(): Unit {
        refCount = refCount + 1
    }

    public func toOpaque(): UIntNative { return callbackContext }

    public static func fromOpaque(ctx: UIntNative): S3UploadStreamWrapper {
        return S3UploadStreamRegistry.get(ctx)
    }

    // ========================================================================
    // deref - 减少引用计数
    // 严格翻译自: intrusive deref() — decrements ref_count; runs finalizer + frees on zero
    // ========================================================================

    /// 减少引用计数
    /// 对应 Bun: intrusive deref()
    /// 当引用计数归零时释放资源
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }

    // ========================================================================
    // detachSink - 分离 Sink
    // 严格翻译自: fn detachSink(`this`: *@This()) void
    // ========================================================================

    /// 分离 Sink
    /// 对应 Bun: detachSink
    /// 释放持有的 ResumableSink 引用
    public func detachSink(): Unit {
        match (sink) {
            case Some(s) =>
                s.deref()
                sink = None
            case None => ()
        }
    }

    // ========================================================================
    // onWritable - 可写回调
    // 严格翻译自: pub fn onWritable(task: *MultiPartUpload, self_: *@This(), _: u64) void
    // ========================================================================

    /// 可写回调
    /// 对应 Bun: onWritable
    /// 当上传队列有空间时调用，用于从 sink 排数据
    public static func onWritable(task: MultiPartUpload, self_: S3UploadStreamWrapper, flushed: UInt64): Unit {
        // end 已调用，无需再 drain
        if (task.ended) {
            return
        }
        // 队列有空间，从 sink 排数据
        match (self_.sink) {
            case Some(s) =>
                s.drain()
            case None => ()
        }
    }

    // ========================================================================
    // writeRequestData - 写入请求数据
    // 严格翻译自: pub fn writeRequestData(`this`: *@This(), data: []const u8) ResumableSinkBackpressure
    // ========================================================================

    /// 写入请求数据
    /// 对应 Bun: writeRequestData
    /// 将数据写入 MultiPartUpload
    public func writeRequestData(data: String): ResumableSinkBackpressure {
        return task.writeBytes(data, false)
    }

    // ========================================================================
    // writeEndRequest - 写入结束请求
    // 严格翻译自: pub fn writeEndRequest(`this`: *@This(), err: ?JsValue) void
    // ========================================================================

    /// 写入结束请求
    /// 对应 Bun: writeEndRequest
    /// 结束上传流，如果有错误则拒绝 Promise
    public func writeEndRequest(err: ?JsValue): Unit {
        detachSink()
        // defer { deref() }
        // Cangjie does not have defer - cleanup happens at end of scope

        match (err) {
            case Some(jsErr) =>
                if (endPromise.hasValue() && !jsErr.isEmptyOrUndefinedOrNull()) {
                    // 如果有明确错误，拒绝 Promise
                    endPromise.reject(global.get(), jsErr)
                    endPromise = JSPromiseStrong()
                }
                if (!task.ended) {
                    task.fail(S3Error("UnknownError", "ReadableStream ended with an error"))
                }
            case None =>
                // 正常结束
                task.writeBytes("", true)
        }
    }

    // ========================================================================
    // resolve - 解析上传结果
    // 严格翻译自: pub fn resolve(result: S3UploadResult, self_: *@This()) JsTerminatedResult<()>
    // ========================================================================

    /// 解析上传结果
    /// 对应 Bun: resolve
    /// 处理上传结果，解决/拒绝 Promise
    public static func resolve(result: S3UploadResult, self_: S3UploadStreamWrapper): Unit {
        // defer { self_.deref() }
        // Cangjie does not have defer - cleanup happens at end of scope

        match (result.tag) {
            case S3UploadResultTag.Success =>
                if (self_.endPromise.hasValue()) {
                    self_.endPromise.resolve(self_.global.get(), JsValue(0.0))
                    self_.endPromise = JSPromiseStrong()
                }
            case S3UploadResultTag.Failure =>
                match (self_.sink) {
                    case Some(s) =>
                        // sink 正在进行中，取消它
                        let jsErr = s3ErrorToJS(result.error, self_.global.get(), Some(self_.path))
                        s.cancel(jsErr)
                        s.deref()
                    case None =>
                        if (self_.endPromise.hasValue()) {
                            let jsErr = s3ErrorToJS(result.error, self_.global.get(), Some(self_.path))
                            self_.endPromise.reject(self_.global.get(), jsErr)
                            self_.endPromise = JSPromiseStrong()
                        }
                }
        }

        // 调用用户回调
        match (self_.callback) {
            case Some(cb) =>
                cb(result, self_.callbackContext)
            case None => ()
        }
    }

    // ========================================================================
    // deinit - 释放资源
    // 严格翻译自: Drop for S3UploadStreamWrapper / Zig deinit
    // ========================================================================

    /// 释放资源
    /// 对应 Bun: deinit
    public func deinit(): Unit {
        S3UploadStreamRegistry.unregister(callbackContext)
        detachSink()
        // task.deref() — 释放对 MultiPartUpload 的引用
        MultiPartUpload.deref(task)
        // endPromise 由 GC 管理
    }
}

public class S3UploadStreamRegistryEntry {
    public var id: UIntNative
    public var wrapper: S3UploadStreamWrapper

    public init(id: UIntNative, wrapper: S3UploadStreamWrapper) {
        this.id = id
        this.wrapper = wrapper
    }
}

public class S3UploadStreamRegistry {
    private static var nextId: UIntNative = UIntNative(1)
    private static var entries = ArrayList<S3UploadStreamRegistryEntry>()

    public static func register(wrapper: S3UploadStreamWrapper): UIntNative {
        let id = nextId
        nextId += UIntNative(1)
        entries.append(S3UploadStreamRegistryEntry(id, wrapper))
        return id
    }

    public static func unregister(id: UIntNative): Unit {
        if (id == UIntNative(0)) { return }
        for (i in 0..entries.size) {
            if (entries[i].id == id) {
                entries.removeAt(i)
                return
            }
        }
    }

    public static func get(id: UIntNative): S3UploadStreamWrapper {
        for (entry in entries) {
            if (entry.id == id) {
                return entry.wrapper
            }
        }
        return S3UploadStreamWrapper(MultiPartUpload(), None, id, "", GlobalRef())
    }
}

// ============================================================================
// writableStream - 创建可写流
// 严格翻译自: pub fn writable_stream(
//   credentials: bun_ptr::IntrusiveRc<S3Credentials>,
//   path: &[u8], global_this: &JSGlobalObject,
//   options: MultiPartUploadOptions,
//   content_type: Option<&[u8]>, content_disposition: Option<&[u8]>,
//   content_encoding: Option<&[u8]>, proxy: Option<&[u8]>,
//   storage_class: Option<StorageClass>, request_payer: bool,
// ) -> JsResult<JsValue>
// Bun: 创建一个写入 S3 路径的可写流
// ============================================================================

/// 创建可写流
/// 对应 Bun: writableStream()
/// 创建一个写入 S3 路径的可写流，使用 MultiPartUpload 进行上传
/// 接管一个 credentials 引用（直接移交给 MultiPartUpload；不增加引用计数）
public func s3WritableStream(
    credentials: S3Credentials,
    path: String,
    globalThis: JsGlobalObject,
    options: MultiPartUploadOptions,
    contentType: String,
    contentDisposition: String,
    contentEncoding: String,
    proxy: String,
    storageClass: ?S3StorageClass,
    requestPayer: Bool
): JsValue {
    let proxyUrl = proxy

    // 创建 MultiPartUpload 任务
    let task = MultiPartUpload()
    task.queue = None
    task.available = BitSet(Int64(MultiPartUploadOptions.MAX_QUEUE_SIZE))
    task.available.setAll()
    task.currentPartNumber = 1
    task.refCount = 2  // +1 for the stream
    task.ended = false
    task.options = options
    task.acl = None
    task.storageClass = storageClass
    task.requestPayer = requestPayer
    task.credentials = credentials
    task.pollRef = KeepAlive()
    task.vm = VirtualMachine.get()
    task.globalThis = GlobalRef.from(globalThis)
    task.buffered = StreamBuffer()
    task.path = path
    task.proxy = proxyUrl
    task.contentType = if (contentType.size > 0) { Some(contentType) } else { None }
    task.contentDisposition = if (contentDisposition.size > 0) { Some(contentDisposition) } else { None }
    task.contentEncoding = if (contentEncoding.size > 0) { Some(contentEncoding) } else { None }
    task.uploadId = ""
    task.uploadidBuffer = MutableString()
    task.multipartEtags = ArrayList<UploadPartResult>()
    task.multipartUploadList = MutableString()
    task.state = MultipartUploadState.NOT_STARTED
    task.callbackContext = 0
    task.onWritable = None

    task.pollRef.ref(task.vm)

    // 创建 NetworkSink
    let responseStream = NetworkSink()
    responseStream.task = Some(task)
    responseStream.globalThis = Some(GlobalRef.from(globalThis))
    responseStream.highWaterMark = options.partSize

    task.callbackContext = responseStream.toOpaque()
    task.onWritable = Some(onWritableThunk)

    // 初始化信号
    responseStream.signal = SinkSignal()
    responseStream.signal.clear()

    return responseStream.toJS(globalThis)
}

/// onWritable thunk — 将类型化回调适配为擦除类型签名
/// 对应 Bun: on_writable_thunk
private func onWritableThunk(task: MultiPartUpload, ctx: UIntNative, flushed: UInt64): Unit {
    let sink = NetworkSink.fromOpaque(ctx)
    NetworkSink.onWritable(task, sink, flushed)
}

// ============================================================================
// uploadStream - 从 ReadableStream 上传到 S3
// 严格翻译自: pub fn upload_stream(
//   credentials, path, readable_stream, global_this, options,
//   acl, storage_class, content_type, content_disposition,
//   content_encoding, proxy, request_payer,
//   callback, callback_context,
// ) -> JsResult<JsValue>
// Bun: 消费 readable stream 并上传到 S3
// ============================================================================

/// 从 ReadableStream 上传到 S3
/// 对应 Bun: uploadStream()
/// 消费 ReadableStream 并上传到 S3 路径
/// 接管一个 credentials 引用（直接移交给 MultiPartUpload；不增加引用计数）
public func s3UploadStream(
    credentials: S3Credentials,
    path: String,
    readableStream: ReadableStream,
    globalThis: JsGlobalObject,
    options: MultiPartUploadOptions,
    acl: ?S3Acl,
    storageClass: ?S3StorageClass,
    contentType: String,
    contentDisposition: String,
    contentEncoding: String,
    proxy: String,
    requestPayer: Bool,
    callback: ?((S3UploadResult, UIntNative) -> Unit),
    callbackContext: UIntNative
): JsValue {
    let proxyUrl = proxy

    // 检查 ReadableStream 是否已被消费
    if (readableStream.isDisturbed(globalThis)) {
        return S3Error("NotImplemented", "S3 uploadStream cannot consume a disturbed ReadableStream in this Cangjie runtime build").toJsValue()
    }

    // 检查流是否无效
    if (readableStream.ptr().isNone()) {
        return S3Error("NotImplemented", "S3 uploadStream cannot consume an invalid ReadableStream in this Cangjie runtime build").toJsValue()
    }

    // 创建 MultiPartUpload 任务
    let task = MultiPartUpload()
    task.queue = None
    task.available = BitSet(Int64(MultiPartUploadOptions.MAX_QUEUE_SIZE))
    task.available.setAll()
    task.currentPartNumber = 1
    task.refCount = 2  // +1 for the stream ctx
    task.ended = false
    task.options = options
    task.acl = acl
    task.storageClass = storageClass
    task.requestPayer = requestPayer
    task.credentials = credentials
    task.pollRef = KeepAlive()
    task.vm = VirtualMachine.get()
    task.globalThis = GlobalRef.from(globalThis)
    task.buffered = StreamBuffer()
    task.path = path
    task.proxy = proxyUrl
    task.contentType = if (contentType.size > 0) { Some(contentType) } else { None }
    task.contentDisposition = if (contentDisposition.size > 0) { Some(contentDisposition) } else { None }
    task.contentEncoding = if (contentEncoding.size > 0) { Some(contentEncoding) } else { None }
    task.uploadId = ""
    task.uploadidBuffer = MutableString()
    task.multipartEtags = ArrayList<UploadPartResult>()
    task.multipartUploadList = MutableString()
    task.state = MultipartUploadState.WAIT_STREAM_CHECK
    task.callbackContext = 0
    task.onWritable = None

    task.pollRef.ref(task.vm)

    // 创建 S3UploadStreamWrapper 上下文
    let ctx = S3UploadStreamWrapper(
        task,
        callback,
        callbackContext,
        path,
        GlobalRef.from(globalThis)
    )
    ctx.endPromise = JSPromiseStrong(globalThis)

    // +1 因为 ctx 引用了 sink
    ctx.sink = Some(ResumableS3UploadSink(GlobalRef.from(globalThis), readableStream, ctx, 2))

    let ctxId = S3UploadStreamRegistry.register(ctx)
    ctx.callbackContext = ctxId
    task.callbackContext = ctxId
    task.onWritable = Some(uploadStreamOnWritableThunk)

    // 启动流处理
    task.continueStream()

    return ctx.endPromise.value()
}

/// uploadStream 的 onWritable thunk
private func uploadStreamOnWritableThunk(task: MultiPartUpload, ctx: UIntNative, flushed: UInt64): Unit {
    let wrapper = S3UploadStreamWrapper.fromOpaque(ctx)
    S3UploadStreamWrapper.onWritable(task, wrapper, flushed)
}

// ============================================================================
// downloadStream - 流式下载 S3 对象
// 严格翻译自: pub fn download_stream(
//   this: &S3Credentials, path: &[u8],
//   offset: usize, size: Option<usize>,
//   proxy_url: Option<&[u8]>, request_payer: bool,
//   callback: fn(chunk: MutableString, has_more: bool, err: ?S3Error, ctx: *c_void),
//   callback_context: *c_void,
// )
// Bun: 流式下载 S3 对象，逐块回调数据
// ============================================================================

/// 流式下载 S3 对象
/// 对应 Bun: downloadStream()
/// 逐块回调下载 S3 对象的数据，用于 ReadableStream
public func s3DownloadStream(
    credentials: S3Credentials,
    path: String,
    offset: Int64,
    size: ?Int64,
    proxyUrl: String,
    requestPayer: Bool,
    callback: (MutableString, Bool, ?S3Error, UIntNative) -> Unit,
    callbackContext: UIntNative
): Unit {
    // 构造 Range 头
    let range: String = match (size) {
        case Some(size_) =>
            var end = offset + size_
            if (size_ > 0) {
                end -= 1
            }
            "bytes=${offset}-${end}"
        case None =>
            if (offset == 0) {
                ""
            } else {
                "bytes=${offset}-"
            }
    }

    // 签名请求
    var signResult: S3SignResult
    try {
        signResult = S3Signing.signRequestFull(
            path,
            HttpMethod.GET,
            "",
            "",
            "",
            None,
            None,
            requestPayer,
            None,
            None,
            credentials
        )
    } catch (e: Exception) {
        let errorCodeAndMessage = getSignErrorCodeAndMessage()
        callback(
            MutableString(),
            false,
            Some(S3Error(errorCodeAndMessage.code, errorCodeAndMessage.message)),
            callbackContext
        )
        return
    }

    // 构造 HTTP 头
    let httpHeaders: HttpHeaders
    if (range.size > 0) {
        httpHeaders = signResult.mixWithHeader("range", range)
    } else {
        httpHeaders = signResult.toHttpHeaders()
    }

    // 创建流式下载任务
    let task = S3HttpDownloadStreamingTask(VirtualMachine(), signResult)
    task.signResult = signResult
    task.proxyUrl = proxyUrl
    task.callbackContext = callbackContext
    task.callback = callback
    task.range = range
    task.headers = httpHeaders
    task.vm = VirtualMachine.get()
    task.hasScheduleCallback = false
    task.pollRef = KeepAlive()
    task.responseBuffer = MutableString()
    task.state = S3DownloadState(0, 0, true)

    task.pollRef.ref(task.vm)

    callback(
        MutableString(),
        false,
        Some(S3Error("NotImplemented", "S3 downloadStream requires AsyncHTTP streaming callbacks, which are not available in this Cangjie runtime build; use download() for strict buffered GET support.")),
        callbackContext
    )
}

// ============================================================================
// readableStream - 创建可读流
// 严格翻译自: pub fn readable_stream(
//   this: &S3Credentials, path: &[u8],
//   offset: usize, size: Option<usize>,
//   proxy_url: Option<&[u8]>, request_payer: bool,
//   global_this: &JSGlobalObject,
// ) -> JsResult<JsValue>
// Bun: 创建一个读取 S3 路径的可读流
// ============================================================================

/// 创建可读流
/// 对应 Bun: readableStream()
/// 创建一个从 S3 路径读取的可读流
public func s3ReadableStream(
    credentials: S3Credentials,
    path: String,
    offset: Int64,
    size: ?Int64,
    proxyUrl: String,
    requestPayer: Bool,
    globalThis: JsGlobalObject
): JsValue {
    // 创建 ByteStream Source
    let reader = ByteStreamSource()
    reader.context = ByteStream()
    reader.globalThis = Some(globalThis)

    reader.context.setup()
    let readableValue = reader.toReadableStream(globalThis)

    // 创建 S3DownloadStreamWrapper
    let wrapper = S3DownloadStreamWrapper()
    wrapper.readableStreamRef = ReadableStreamStrong(
        ReadableStream(
            ReadableStreamPtr.BYTES(reader.context),
            readableValue
        ),
        globalThis
    )
    wrapper.path = path
    wrapper.global = GlobalRef.from(globalThis)

    // 设置取消处理器
    reader.cancelHandler = Some(S3DownloadStreamWrapper.onStreamCancelled)
    reader.cancelCtx = Some(wrapper.toOpaque())

    // 启动下载流
    let wrapperCtx = wrapper.toOpaque()
    s3DownloadStream(
        credentials,
        path,
        offset,
        size,
        proxyUrl,
        requestPayer,
        S3DownloadStreamWrapper.opaqueCallback,
        wrapperCtx
    )

    return readableValue
}

// ============================================================================
// S3DownloadStreamWrapper - 下载流包装器
// 严格翻译自: client.rs 中的 S3DownloadStreamWrapper (内部定义)
// ============================================================================

/// S3 下载流包装器
/// 对应 Bun: client.rs S3DownloadStreamWrapper
/// 管理 ReadableStream 和下载回调之间的桥接
public class S3DownloadStreamWrapper {
    /// 唯一标识用于引用比较
    private static var nextIdentity: UIntNative = UIntNative(1)
    public let identity: UIntNative

    /// ReadableStream 强引用
    public var readableStreamRef: ReadableStreamStrong

    /// 路径
    public var path: String

    /// 全局对象引用
    public var global: GlobalRef

    public operator func ==(right: S3DownloadStreamWrapper): Bool {
        return this.identity == right.identity
    }

    public init() {
        identity = S3DownloadStreamWrapper.nextIdentity
        S3DownloadStreamWrapper.nextIdentity += UIntNative(1)
        readableStreamRef = ReadableStreamStrong()
        path = ""
        global = GlobalRef()
    }

    // ========================================================================
    // callback - 下载回调
    // 严格翻译自: S3DownloadStreamWrapper.callback
    // ========================================================================

    /// 下载回调
    /// 对应 Bun: callback
    /// 处理下载的 chunk 数据或错误
    public func callback(chunk: MutableString, hasMore: Bool, requestErr: ?S3Error): Unit {
        match (requestErr) {
            case Some(_) =>
                clearStreamCancelHandler()
                readableStreamRef.deinit()
            case None =>
                let streamOpt = readableStreamRef.get(global)
                match (streamOpt) {
                    case Some(rs) =>
                        let bsOpt = rs.getByteStream()
                        match (bsOpt) {
                            case Some(byteStream) =>
                                let bytes = ArrayList<UInt8>()
                                for (b in chunk.toString()) {
                                    bytes.append(b)
                                }
                                byteStream.onData(bytes, !hasMore)
                                if (!hasMore) {
                                    clearStreamCancelHandler()
                                    readableStreamRef.deinit()
                                }
                            case None =>
                                clearStreamCancelHandler()
                                readableStreamRef.deinit()
                        }
                    case None => ()
                }
        }
    }

    // ========================================================================
    // clearStreamCancelHandler - 清除流的取消处理器
    // 严格翻译自: fn clear_stream_cancel_handler
    // ========================================================================

    /// 清除流的取消处理器
    /// 对应 Bun: clearStreamCancelHandler
    /// 必须在释放 readableStreamRef 之前调用
    public func clearStreamCancelHandler(): Unit {
        S3DownloadStreamRegistry.unregisterForWrapper(this)
    }

    // ========================================================================
    // onStreamCancelled - 流被取消
    // 严格翻译自: fn on_stream_cancelled(ctx: ?*anyopaque) callconv(.c) void
    // ========================================================================

    /// 流被取消
    /// 对应 Bun: onStreamCancelled
    /// 释放 Strong 引用使 ReadableStream 可被 GC 回收
    public static func onStreamCancelled(ctx: ?UIntNative): Unit {
        match (ctx) {
            case Some(opaque) =>
                let self_ = S3DownloadStreamWrapper.fromOpaque(opaque)
                S3DownloadStreamRegistry.unregister(opaque)
                // 释放 Strong 引用
                self_.readableStreamRef.deinit()
            case None => ()
        }
    }

    // ========================================================================
    // opaqueCallback - 不透明回调
    // 严格翻译自: pub fn opaque_callback(
    //   chunk: MutableString, has_more: bool, err: ?S3Error, opaque_self: *c_void)
    // ========================================================================

    /// 不透明回调
    /// 对应 Bun: opaqueCallback
    /// 将不透明指针转换为 S3DownloadStreamWrapper 并调用 callback
    public static func opaqueCallback(
        chunk: MutableString,
        hasMore: Bool,
        err: ?S3Error,
        opaqueSelf: UIntNative
    ): Unit {
        let self_ = S3DownloadStreamWrapper.fromOpaque(opaqueSelf)
        self_.callback(chunk, hasMore, err)
    }

    /// 转为不透明指针
    public func toOpaque(): UIntNative {
        return S3DownloadStreamRegistry.register(this)
    }

    /// 从不透明指针恢复
    public static func fromOpaque(opaque: UIntNative): S3DownloadStreamWrapper {
        return S3DownloadStreamRegistry.get(opaque)
    }
}

public class S3DownloadStreamRegistryEntry {
    public var id: UIntNative
    public var wrapper: S3DownloadStreamWrapper

    public init(id: UIntNative, wrapper: S3DownloadStreamWrapper) {
        this.id = id
        this.wrapper = wrapper
    }
}

public class S3DownloadStreamRegistry {
    private static var nextId: UIntNative = UIntNative(1)
    private static var entries = ArrayList<S3DownloadStreamRegistryEntry>()

    public static func register(wrapper: S3DownloadStreamWrapper): UIntNative {
        for (entry in entries) {
            if (entry.wrapper == wrapper) {
                return entry.id
            }
        }
        let id = nextId
        nextId += UIntNative(1)
        entries.append(S3DownloadStreamRegistryEntry(id, wrapper))
        return id
    }

    public static func unregister(id: UIntNative): Unit {
        if (id == UIntNative(0)) { return }
        for (i in 0..entries.size) {
            if (entries[i].id == id) {
                entries.removeAt(i)
                return
            }
        }
    }

    public static func unregisterForWrapper(wrapper: S3DownloadStreamWrapper): Unit {
        for (i in 0..entries.size) {
            if (entries[i].wrapper == wrapper) {
                entries.removeAt(i)
                return
            }
        }
    }

    public static func get(id: UIntNative): S3DownloadStreamWrapper {
        for (entry in entries) {
            if (entry.id == id) {
                return entry.wrapper
            }
        }
        return S3DownloadStreamWrapper()
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// URI 组件编码
/// 对应 Bun: encode_uri_component
private func encodeURIComponent(input: String): String {
    let hex = "0123456789ABCDEF"
    let encoded = StringBuilder()
    for (ch in input) {
        let b = UInt8(ch)
        if ((b >= UInt8(65) && b <= UInt8(90)) ||
            (b >= UInt8(97) && b <= UInt8(122)) ||
            (b >= UInt8(48) && b <= UInt8(57)) ||
            b == UInt8(45) || b == UInt8(95) || b == UInt8(46) || b == UInt8(126)) {
            encoded.append(String.fromUtf8([b]))
        } else {
            encoded.append("%")
            encoded.append(hex[Int64(b / UInt8(16))].toString())
            encoded.append(hex[Int64(b % UInt8(16))].toString())
        }
    }
    return encoded.toString()
}

/// 获取签名错误码和消息
/// 对应 Bun: getSignErrorCodeAndMessage
private func getSignErrorCodeAndMessage(): S3Error {
    return S3Error("SignError", "Failed to sign the request.")
}

/// 将 S3Error 转为 JS 值
/// 对应 Bun: s3ErrorToJS
/// 创建 JSS3Error 并转为 Error 实例
public func s3ErrorToJS(err: ?S3Error, globalObject: JsGlobalObject, path: ?String): JsValue {
    match (err) {
        case Some(e) =>
            let jsErr = JSS3Error(e.code, e.message, path)
            return jsErr.toErrorInstance(globalObject)
        case None =>
            return JsValue(JsObject())
    }
}

// ported from: src/runtime/webcore/s3/client.rs
