// 严格翻译自: src/runtime/webcore/s3/multipart.rs (1175 lines)
// S3 Multipart Upload - S3 分块上传
//
// 上传流程 (来自 Bun 源码注释):
// 1. 开始上传时缓冲数据，直到达到 partSize 或收到最后一个 chunk
// 2. 如果缓冲区小于 partSize，作为单个请求发送
// 3. 如果发送单个请求，会重试直到最大重试次数
// 4. 当发送分块上传时，如果有空间，分片入队并立即开始请求
// 5. 如果队列已满，等待排空后再开始新分片
// 6. 每个分片维护对 MultiPartUpload 的引用直到完成
// 7. 如果分片被取消或提前失败，释放分配的切片并移除引用
// 8. 如果分片成功完成，收到 etag，释放切片并将 etag 添加到数组
// 9. 如果所有分片成功，发送 commit 请求
// 10. 如果任何分片失败，发送 rollback 请求删除已上传的分片
package bao_runtime.webcore.s3

import bao_core.*
import bao_collections.*
import bao_jsc.*

// Extension for StreamBuffer compatibility
extend StreamBuffer {
    public func slice(): String { return String.fromUtf8(list) }
    public func sliceArray(): Array<UInt8> { return list }
    public func size(): Int64 { return Int64(list.size) }
    public func isEmpty(): Bool { return list.size == 0 }
    public func isNotEmpty(): Bool { return list.size > 0 }
    public func memoryCost(): Int64 { return Int64(list.size) }
    public func sliceRange(start: Int64, len: Int64): String {
        var result = ArrayList<UInt8>()
        let end = if (start + len > Int64(list.size)) { Int64(list.size) } else { start + len }
        var i = start
        while (i < end) {
            result.append(list[Int64(i)])
            i++
        }
        return String.fromUtf8(result.toOwnedSlice())
    }
    public func wrote(count: Int64): Unit {
        if (count > 0 && Int64(list.size) > count) {
            var newList = ArrayList<UInt8>()
            var i = count
            while (i < Int64(list.size)) {
                newList.append(list[i])
                i++
            }
            list = newList.toOwnedSlice()
        } else {
            list = []
        }
        cursor = 0
    }
    public func write(chunk: String): Unit {
        for (b in BaoString(chunk).utf8()) {
            list = list.concat([b])
        }
    }
    public func writeLatin1(chunk: String): Unit {
        write(chunk)
    }
    public func writeUtf16(chunk: String): Unit {
        write(chunk)
    }
}

private func optionalHeader(value: ?String): String {
    match (value) {
        case Some(v) => v
        case None => ""
    }
}

private func parseUploadId(body: String): ?String {
    let open = "<UploadId>"
    let close = "</UploadId>"
    match (body.indexOf(open)) {
        case Some(startIdx) =>
            let start = Int64(startIdx) + open.size
            match (body[start..].indexOf(close)) {
                case Some(endRel) =>
                    let end = start + Int64(endRel)
                    let uploadId = body[start..end]
                    if (uploadId.size == 0 || uploadId.size > 2000) { return None }
                    Some(uploadId)
                case None => None
            }
        case None => None
    }
}

// ============================================================================
// MultipartUploadState - 分块上传状态
// 严格翻译自: pub enum State (multipart.rs line 168-177)
// Bun: #[repr(u8)] pub enum State { WaitStreamCheck, NotStarted, MultipartStarted,
//   MultipartCompleted, SinglefileStarted, Finished }
// ============================================================================

/// 分块上传状态
/// 对应 Bun: State enum
public enum MultipartUploadState {
    | WAIT_STREAM_CHECK
    | NOT_STARTED
    | MULTIPART_STARTED
    | MULTIPART_COMPLETED
    | SINGLE_FILE_STARTED
    | FINISHED

    public operator func == (other: MultipartUploadState): Bool {
        match (this) {
            case WAIT_STREAM_CHECK => match (other) { case WAIT_STREAM_CHECK => true case _ => false }
            case NOT_STARTED => match (other) { case NOT_STARTED => true case _ => false }
            case MULTIPART_STARTED => match (other) { case MULTIPART_STARTED => true case _ => false }
            case MULTIPART_COMPLETED => match (other) { case MULTIPART_COMPLETED => true case _ => false }
            case SINGLE_FILE_STARTED => match (other) { case SINGLE_FILE_STARTED => true case _ => false }
            case FINISHED => match (other) { case FINISHED => true case _ => false }
        }
    }
    public operator func != (other: MultipartUploadState): Bool {
        !(this == other)
    }
}
// 严格翻译自: pub enum PartState (multipart.rs line 204-212)
// Bun: #[repr(u8)] pub enum PartState { NotAssigned, Pending, Started, Completed, Canceled }
// ============================================================================

/// 分片状态
/// 对应 Bun: PartState enum
public enum PartState {
    | NOT_ASSIGNED
    | PENDING
    | STARTED
    | COMPLETED
    | CANCELED

    public operator func == (other: PartState): Bool {
        match (this) {
            case NOT_ASSIGNED => match (other) { case NOT_ASSIGNED => true case _ => false }
            case PENDING => match (other) { case PENDING => true case _ => false }
            case STARTED => match (other) { case STARTED => true case _ => false }
            case COMPLETED => match (other) { case COMPLETED => true case _ => false }
            case CANCELED => match (other) { case CANCELED => true case _ => false }
        }
    }
    public operator func != (other: PartState): Bool {
        !(this == other)
    }
}

// ============================================================================
// WriteEncoding - 写入编码
// 严格翻译自: pub enum WriteEncoding (multipart.rs line 1168-1173)
// Bun: enum WriteEncoding { Bytes, Latin1, Utf16 }
// ============================================================================

/// 写入编码
/// 对应 Bun: WriteEncoding enum
public enum WriteEncoding {
    | BYTES
    | LATIN1
    | UTF16

    public operator func == (other: WriteEncoding): Bool {
        match (this) {
            case BYTES => match (other) { case BYTES => true case _ => false }
            case LATIN1 => match (other) { case LATIN1 => true case _ => false }
            case UTF16 => match (other) { case UTF16 => true case _ => false }
        }
    }
}

// ============================================================================
// UploadPartResult - 分片上传结果
// 严格翻译自: pub struct UploadPartResult (multipart.rs line 226-229)
// Bun: pub struct UploadPartResult { pub number: u16, pub etag: Box<[u8]> }
// ============================================================================

/// 分片上传结果
/// 对应 Bun: UploadPartResult
/// 记录已成功上传的分片编号和 ETag
public class UploadPartResult {
    /// 分片编号
    /// 对应 Bun: number: u16
    public var number: UInt16

    /// ETag (拥有的)
    /// 对应 Bun: etag: Box<[u8]>
    public var etag: String

    public init() {
        number = 0
        etag = ""
    }

    public init(number: UInt16, etag: String) {
        this.number = number
        this.etag = etag
    }
}

/// ArrayList<UploadPartResult> 扩展: 按分片编号排序
public func sortUploadPartResults(list: ArrayList<UploadPartResult>): Unit {
    // 简单冒泡排序 (分片数量通常很小, 最大 10000)
    for (i in 0..list.size) {
        for (j in (i + 1)..list.size) {
            if (list[j].number < list[i].number) {
                let tmp = list[i]
                list[i] = list[j]
                list[j] = tmp
            }
        }
    }
}

// ============================================================================
// UploadPart - 上传分片
// 严格翻译自: pub struct UploadPart (multipart.rs line 214-224)
// Bun: pub struct UploadPart {
//   data: *const [u8], ctx: S3BackRef<MultiPartUpload>,
//   allocated_size: usize, state: PartState, part_number: u16,
//   retry: u8, index: u8
// }
// ============================================================================

/// 上传分片
/// 对应 Bun: UploadPart
/// 表示一个正在上传的分片，包含数据、状态、重试计数等
public class UploadPart {
    /// 数据 (拥有的切片)
    /// 对应 Bun: data: *const [u8]
    public var data: String

    /// 是否拥有数据
    public var ownsData: Bool

    /// 所属的 MultiPartUpload 引用
    /// 对应 Bun: ctx: S3BackRef<MultiPartUpload>
    public var ctx: MultiPartUpload

    /// 已分配大小
    /// 对应 Bun: allocated_size: usize
    public var allocatedSize: Int64

    /// 分片状态
    /// 对应 Bun: state: PartState
    public var state: PartState

    /// 分片编号 (最大 10000)
    /// 对应 Bun: part_number: u16
    public var partNumber: UInt16

    /// 重试次数 (递减直到 0 后失败)
    /// 对应 Bun: retry: u8
    public var retry: UInt8

    /// 队列索引
    /// 对应 Bun: index: u8
    public var index: UInt8

    public init() {
        data = ""
        ownsData = false
        allocatedSize = 0
        state = PartState.NOT_ASSIGNED
        partNumber = 0
        retry = 0
        index = 0
        ctx = MultiPartUpload()
    }

    public init(ctx: MultiPartUpload, index: UInt8) {
        data = ""
        ownsData = false
        allocatedSize = 0
        state = PartState.NOT_ASSIGNED
        partNumber = 0
        retry = 0
        this.index = index
        this.ctx = ctx
    }

    // ========================================================================
    // freeAllocatedSlice - 释放分配的切片
    // 严格翻译自: fn free_allocated_slice(&self) (multipart.rs line 236-252)
    // ========================================================================

    /// 释放分配的切片
    /// 对应 Bun: freeAllocatedSlice
    /// 释放分片拥有的数据切片
    public func freeAllocatedSlice(): Unit {
        if (allocatedSize > 0 && ownsData) {
            // 仓颉 GC 管理内存
            data = ""
            allocatedSize = 0
            ownsData = false
        }
        data = ""
        allocatedSize = 0
    }

    // ========================================================================
    // data - 获取数据
    // 严格翻译自: fn data(&self) -> &[u8] (multipart.rs line 254-258)
    // ========================================================================

    /// 获取分片数据
    /// 对应 Bun: data()
    public func getData(): String {
        return data
    }

    // ========================================================================
    // onPartResponse - 分片上传响应回调
    // 严格翻译自: pub fn on_part_response(result: S3PartResult, `this`: *c_void)
    //   -> JsTerminatedResult<()> (multipart.rs line 260-335)
    // ========================================================================

    /// 分片上传响应回调
    /// 对应 Bun: onPartResponse
    /// 处理分片上传的响应：成功时记录 etag，失败时重试或报告错误
    public static func onPartResponse(result: S3PartResult, self: UploadPart): Unit {
        let ctx = self.ctx

        if (self.state == PartState.CANCELED || ctx.state == MultipartUploadState.FINISHED) {
            self.freeAllocatedSlice()
            MultiPartUpload.deref(ctx)
            return
        }

        self.state = PartState.COMPLETED

        match (result.tag) {
            case S3PartResultTag.Failure =>
                if (result.error.isSome()) {
                    let err = result.error.getOrThrow()
                    if (self.retry > 0) {
                        self.retry -= 1
                        self.perform()
                    } else {
                        self.state = PartState.NOT_ASSIGNED
                        self.freeAllocatedSlice()
                        ctx.fail(err)
                        MultiPartUpload.deref(ctx)
                    }
                } else {
                    if (self.retry > 0) {
                        self.retry -= 1
                        self.perform()
                        } else {
                            self.state = PartState.NOT_ASSIGNED
                            self.freeAllocatedSlice()
                            MultiPartUpload.deref(ctx)
                        }
                }
            case S3PartResultTag.Etag =>
                let sent = self.getData().size
                self.freeAllocatedSlice()

                // 将 etag 添加到结果数组
                ctx.multipartEtags.append(UploadPartResult(self.partNumber, result.etag))
                self.state = PartState.NOT_ASSIGNED

                // 标记为可用
                ctx.available.set(Int64(self.index))

                // 继续排空队列
                ctx.drainEnqueuedParts(UInt64(sent))
                MultiPartUpload.deref(ctx)
        }
    }

    // ========================================================================
    // perform - 执行分片上传
    // 严格翻译自: fn perform(&self) -> JsTerminatedResult<()> (multipart.rs line 337-371)
    // ========================================================================

    /// 执行分片上传
    /// 对应 Bun: perform
    /// 构造查询参数并发送分片上传请求
    public func perform(): Unit {
        let ctx = this.ctx
        let searchParams = "?partNumber=${partNumber}&uploadId=${ctx.uploadId}&x-id=UploadPart"

        let options = S3SimpleRequestOptions()
        options.path = ctx.path
        options.method = HttpMethod.PUT
        options.proxyUrl = ctx.proxyUrl()
        options.body = getData()
        options.searchParams = searchParams
        options.requestPayer = ctx.requestPayer

        executeSimpleS3PartRequest(
            ctx.credentials,
            options,
            { result: S3PartResult, _: UIntNative =>
                UploadPart.onPartResponse(result, this)
            },
            UIntNative(0)
        )
    }

    // ========================================================================
    // start - 启动分片上传
    // 严格翻译自: pub fn start(&self) -> JsTerminatedResult<()> (multipart.rs line 373-381)
    // ========================================================================

    /// 启动分片上传
    /// 对应 Bun: start
    /// 如果分片处于 Pending 状态且上传已完成初始化，则启动上传
    public func start(): Unit {
        let ctx = this.ctx
        if (state != PartState.PENDING || ctx.state != MultipartUploadState.MULTIPART_COMPLETED) {
            return
        }
        ctx.ref()
        state = PartState.STARTED
        perform()
    }

    // ========================================================================
    // cancel - 取消分片
    // 严格翻译自: pub fn cancel(&self) (multipart.rs line 383-395)
    // ========================================================================

    /// 取消分片
    /// 对应 Bun: cancel
    /// 将分片标记为已取消，如果是 Pending 状态则释放数据
    public func cancel(): Unit {
        let prevState = state
        state = PartState.CANCELED

        match (prevState) {
            case PartState.PENDING =>
                freeAllocatedSlice()
            case _ => ()
        }
    }
}

// ============================================================================
// MultiPartUpload - 分块上传
// 严格翻译自: pub struct MultiPartUpload (multipart.rs line 126-166)
// Bun: pub struct MultiPartUpload {
//   queue: Option<Box<[UploadPart]>>,
//   available: IntegerBitSet<{ MAX_QUEUE_SIZE }>,
//   current_part_number: u16, ref_count: Cell<u32>,
//   ended: bool, options: MultiPartUploadOptions,
//   acl: Option<ACL>, storage_class: Option<StorageClass>,
//   request_payer: bool, credentials: IntrusiveRc<S3Credentials>,
//   poll_ref: KeepAlive, vm: &'static S3VirtualMachine,
//   global_this: GlobalRef, buffered: StreamBuffer,
//   path: Box<[u8]>, proxy: Box<[u8]>,
//   content_type: Option<Box<[u8]>>,
//   content_disposition: Option<Box<[u8]>>,
//   content_encoding: Option<Box<[u8]>>,
//   upload_id: Box<[u8]>, uploadid_buffer: S3MutableString,
//   multipart_etags: Vec<UploadPartResult>,
//   multipart_upload_list: Vec<u8>,
//   state: State,
//   callback, on_writable, callback_context
// }
// ============================================================================

/// S3 分块上传管理器
/// 对应 Bun: MultiPartUpload
/// 管理 S3 分块上传的完整生命周期
public class MultiPartUpload {
    /// 上传分片队列
    /// 对应 Bun: queue: Option<Box<[UploadPart]>>
    public var queue: ?ArrayList<UploadPart>

    /// 可用分片位图
    /// 对应 Bun: available: IntegerBitSet<{ MAX_QUEUE_SIZE }>
    public var available: BitSet

    /// 当前分片编号
    /// 对应 Bun: current_part_number: u16
    public var currentPartNumber: UInt16

    /// 引用计数 (侵入式)
    /// 对应 Bun: ref_count: Cell<u32>
    public var refCount: Int32

    /// 是否已结束
    /// 对应 Bun: ended: bool
    public var ended: Bool

    /// 上传选项
    /// 对应 Bun: options: MultiPartUploadOptions
    public var options: MultiPartUploadOptions

    /// ACL
    /// 对应 Bun: acl: Option<ACL>
    public var acl: ?S3Acl

    /// 存储类别
    /// 对应 Bun: storage_class: Option<StorageClass>
    public var storageClass: ?S3StorageClass

    /// 是否请求付费
    /// 对应 Bun: request_payer: bool
    public var requestPayer: Bool

    /// S3 凭证
    /// 对应 Bun: credentials: IntrusiveRc<S3Credentials>
    public var credentials: S3Credentials

    /// 轮询引用
    /// 对应 Bun: poll_ref: KeepAlive
    public var pollRef: KeepAlive

    /// 虚拟机引用
    /// 对应 Bun: vm: &'static S3VirtualMachine
    public var vm: S3VirtualMachine

    /// 全局对象引用
    /// 对应 Bun: global_this: GlobalRef
    public var globalThis: GlobalRef

    /// 缓冲区
    /// 对应 Bun: buffered: StreamBuffer
    public var buffered: StreamBuffer

    /// S3 路径
    /// 对应 Bun: path: Box<[u8]>
    public var path: String

    /// 代理 URL
    /// 对应 Bun: proxy: Box<[u8]>
    public var proxy: String

    /// Content-Type
    /// 对应 Bun: content_type: Option<Box<[u8]>>
    public var contentType: ?String

    /// Content-Disposition
    /// 对应 Bun: content_disposition: Option<Box<[u8]>>
    public var contentDisposition: ?String

    /// Content-Encoding
    /// 对应 Bun: content_encoding: Option<Box<[u8]>>
    public var contentEncoding: ?String

    /// 上传 ID (拥有的副本)
    /// 对应 Bun: upload_id: Box<[u8]>
    /// PORT NOTE: Zig 中是 uploadid_buffer 的自引用切片，此处改为拥有的副本
    public var uploadId: String

    /// 上传 ID 缓冲区
    /// 对应 Bun: uploadid_buffer: S3MutableString
    public var uploadidBuffer: S3MutableString

    /// 已上传分片的 ETag 列表
    /// 对应 Bun: multipart_etags: Vec<UploadPartResult>
    public var multipartEtags: ArrayList<UploadPartResult>

    /// 多部分上传列表 (XML body)
    /// 对应 Bun: multipart_upload_list: Vec<u8>
    public var multipartUploadList: S3MutableString

    /// 上传状态
    /// 对应 Bun: state: State
    public var state: MultipartUploadState

    /// 完成回调
    /// 对应 Bun: callback: fn(S3UploadResult, *c_void) -> JsTerminatedResult<()>
    public var callback: (S3UploadResult, UIntNative) -> Unit

    /// 可写回调
    /// 对应 Bun: on_writable: Option<fn(*MultiPartUpload, *c_void, u64)>
    public var onWritable: ?((MultiPartUpload, UIntNative, UInt64) -> Unit)

    /// 回调上下文
    /// 对应 Bun: callback_context: *c_void
    public var callbackContext: UIntNative

    public init() {
        queue = None
        available = BitSet(Int64(MultiPartUploadOptions.MAX_QUEUE_SIZE))
        available.setAll()
        currentPartNumber = 1
        refCount = 1
        ended = false
        options = MultiPartUploadOptions()
        acl = None
        storageClass = None
        requestPayer = false
        credentials = S3Credentials()
        pollRef = KeepAlive()
        vm = S3VirtualMachine()
        globalThis = GlobalRef()
        buffered = StreamBuffer()
        path = ""
        proxy = ""
        contentType = None
        contentDisposition = None
        contentEncoding = None
        uploadId = ""
        uploadidBuffer = S3MutableString()
        multipartEtags = ArrayList<UploadPartResult>()
        multipartUploadList = S3MutableString()
        state = MultipartUploadState.WAIT_STREAM_CHECK
        callback = { _: S3UploadResult, _: UIntNative => }
        onWritable = None
        callbackContext = 0
    }

    // ========================================================================
    // Constants - 常量
    // 严格翻译自: MultiPartUpload 的 const 定义 (multipart.rs line 179-186)
    // ========================================================================

    /// 1 MiB 字节数
    /// 对应 Bun: ONE_MIB = MultiPartUploadOptions::ONE_MIB
    public static let ONE_MIB: Int64 = MultiPartUploadOptions.ONE_MIB

    /// 最大单次上传大小 (5 GiB)
    /// 对应 Bun: MAX_SINGLE_UPLOAD_SIZE
    public static let MAX_SINGLE_UPLOAD_SIZE: Int64 = MultiPartUploadOptions.MAX_SINGLE_UPLOAD_SIZE

    /// 最小单次上传大小 (5 MiB)
    /// 对应 Bun: MIN_SINGLE_UPLOAD_SIZE
    public static let MIN_SINGLE_UPLOAD_SIZE: Int64 = MultiPartUploadOptions.MIN_SINGLE_UPLOAD_SIZE

    /// 默认分块大小
    /// 对应 Bun: DEFAULT_PART_SIZE
    public static let DEFAULT_PART_SIZE: Int64 = MultiPartUploadOptions.DEFAULT_PART_SIZE

    /// 最大队列大小
    /// 对应 Bun: MAX_QUEUE_SIZE
    public static let MAX_QUEUE_SIZE: Int64 = Int64(MultiPartUploadOptions.MAX_QUEUE_SIZE)

    /// 最大 Upload ID 长度
    /// 对应 Bun: MAX_UPLOAD_ID_LEN = 2000
    public static let MAX_UPLOAD_ID_LEN: Int64 = 2000

    // ========================================================================
    // ref / deref - 引用计数管理
    // 严格翻译自: bun.ptr.RefCount(Self, "ref_count", deinit, .{})
    // ========================================================================

    /// 增加引用计数
    /// 对应 Bun: intrusive ref()
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用计数
    /// 对应 Bun: intrusive deref_(`this`: *Self)
    /// 当引用计数归零时释放资源
    public static func deref(self: MultiPartUpload): Unit {
        self.refCount -= 1
        if (self.refCount <= 0) {
            self.deinit()
        }
    }

    // ========================================================================
    // deinit - 释放资源
    // 严格翻译自: Drop for MultiPartUpload (multipart.rs line 397-415)
    // ========================================================================

    /// 释放资源
    /// 对应 Bun: deinit
    public func deinit(): Unit {
        pollRef.unref(vm)
        // path, proxy, content_type, content_disposition, content_encoding — GC 管理
        // credentials — GC 管理
        // uploadid_buffer: S3MutableString — GC 管理
        // multipart_etags: Vec<UploadPartResult> — GC 管理
        // multipart_upload_list: Vec<u8> — GC 管理
    }

    // ========================================================================
    // singleSendUploadResponse - 单次上传响应回调
    // 严格翻译自: pub fn single_send_upload_response(
    //   result: S3UploadResult, `this`: *c_void) -> JsTerminatedResult<()>
    // (multipart.rs line 418-472)
    // ========================================================================

    /// 单次上传响应回调
    /// 对应 Bun: singleSendUploadResponse
    /// 处理单次上传的响应：失败时重试或报告错误，成功时通知完成
    public static func singleSendUploadResponse(result: S3UploadResult, self: MultiPartUpload): Unit {
        if (self.state == MultipartUploadState.FINISHED) {
            return
        }

        match (result.tag) {
            case S3UploadResultTag.Failure =>
                if (result.error.isSome()) {
                    let err = result.error.getOrThrow()
                    if (self.options.retry > 0) {
                        self.options.retry -= 1
                        self.fail(S3Error("RetryNotAvailable", "Cannot retry S3 single upload because request body ownership is not retained after dispatch"))
                    } else {
                        self.fail(err)
                    }
                } else {
                    self.fail(S3Error("UnknownError", "Upload failed"))
                }
            case S3UploadResultTag.Success =>
                // 通知可写回调
                match (self.onWritable) {
                    case Some(cb) => cb(self, self.callbackContext, UInt64(self.buffered.size()))
                    case None => ()
                }
                self.done()
        }
    }

    // ========================================================================
    // getCreatePart - 获取/创建分片
    // 严格翻译自: fn get_create_part(
    //   &self, chunk: &[u8], allocated_size: usize, needs_clone: bool
    // ) -> Option<*UploadPart> (multipart.rs line 475-535)
    // ========================================================================

    /// 获取/创建分片
    /// 对应 Bun: getCreatePart
    /// 从可用位图中分配一个分片槽位并初始化
    /// 返回 None 表示队列已满
    public func getCreatePart(chunk: String, allocatedSize: Int64, needsClone: Bool): ?UploadPart {
        let optIndex = available.findFirstSet()
        match (optIndex) {
            case None => return None
            case Some(_) => ()
        }
        let index = optIndex.getOrThrow()
        let queueSize = options.queueSize

        if (index >= Int64(queueSize)) {
            return None
        }

        available.unset(index)

        // 初始化队列（如果尚未创建）
        match (queue) {
            case None =>
                let newQueue = ArrayList<UploadPart>()
                var i: Int64 = 0
                while (i < Int64(queueSize)) {
                    newQueue.append(UploadPart(this, UInt8(i)))
                    i += 1
                }
                queue = Some(newQueue)
            case Some(_) => ()
        }

        // 准备数据
        let partData: String
        let partAllocatedSize: Int64
        let ownsData: Bool
        if (needsClone) {
            partData = chunk
            partAllocatedSize = chunk.size
            ownsData = true
        } else {
            partData = chunk
            partAllocatedSize = allocatedSize
            ownsData = true
        }

        let partNumber = currentPartNumber
        currentPartNumber += 1

        // 获取队列中的分片并设置字段
        match (queue) {
            case Some(q) =>
                if (index < q.size) {
                    let queueItem = q[index]
                    queueItem.data = partData
                    queueItem.allocatedSize = partAllocatedSize
                    queueItem.ownsData = ownsData
                    queueItem.partNumber = partNumber
                    queueItem.ctx = this
                    queueItem.index = UInt8(index)
                    queueItem.retry = options.retry
                    queueItem.state = PartState.PENDING
                    return Some(queueItem)
                }
            case None => ()
        }
        return None
    }

    // ========================================================================
    // drainEnqueuedParts - 排空已入队的分片
    // 严格翻译自: fn drain_enqueued_parts(&self, flushed: u64)
    //   -> JsTerminatedResult<()> (multipart.rs line 538-574)
    // ========================================================================

    /// 排空已入队的分片
    /// 对应 Bun: drainEnqueuedParts
    /// 启动待上传的分片，处理缓冲数据
    public func drainEnqueuedParts(flushed: UInt64): Unit {
        if (state == MultipartUploadState.FINISHED || state == MultipartUploadState.SINGLE_FILE_STARTED) {
            return
        }

        // 启动待上传的分片
        if (state == MultipartUploadState.MULTIPART_COMPLETED) {
            match (queue) {
                case Some(q) =>
                    for (i in 0..q.size) {
                        let part = q[i]
                        if (part.state == PartState.PENDING) {
                            part.start()
                        }
                    }
                case None => ()
            }
        }

        let partSize = partSizeInBytes()
        if (ended || buffered.size() >= partSize) {
            processMultiPart(partSize)
        }

        // 检查队列是否为空
        if (isQueueEmpty()) {
            match (onWritable) {
                case Some(cb) => cb(this, callbackContext, flushed)
                case None => ()
            }
            if (ended) {
                done()
            }
        } else if (!hasBackpressure() && flushed > 0) {
            // 队列有空间，继续排数据
            match (onWritable) {
                case Some(cb) => cb(this, callbackContext, flushed)
                case None => ()
            }
        }
    }

    // ========================================================================
    // fail - 失败
    // 严格翻译自: pub fn fail(&self, err: S3Error) -> JsTerminatedResult<()>
    // (multipart.rs line 577-619)
    // ========================================================================

    /// 失败
    /// 对应 Bun: fail
    /// 终止上传并报告错误
    public func fail(err: S3Error): Unit {
        ended = true

        // 取消所有进行中的分片
        match (queue) {
            case Some(q) =>
                for (i in 0..q.size) {
                    let part = q[i]
                    if (part.state != PartState.NOT_ASSIGNED) {
                        part.cancel()
                    }
                }
            case None => ()
        }

        if (state != MultipartUploadState.FINISHED) {
            let oldState = state
            state = MultipartUploadState.FINISHED
            callback(S3UploadResult.failure(err), callbackContext)

            if (oldState == MultipartUploadState.MULTIPART_COMPLETED) {
                // 多部分上传需要回滚
                rollbackMultiPartRequest()
            } else {
                // 单文件上传无需回滚
                MultiPartUpload.deref(this)
            }
        }
    }

    // ========================================================================
    // done - 完成
    // 严格翻译自: fn done(&self) -> JsTerminatedResult<()> (multipart.rs line 622-657)
    // ========================================================================

    /// 完成
    /// 对应 Bun: done
    /// 成功完成上传或提交多部分上传
    public func done(): Unit {
        if (state == MultipartUploadState.MULTIPART_COMPLETED) {
            // 多部分上传需要发送 etags 并提交
            state = MultipartUploadState.FINISHED

            // 排序 etags (按 number 升序)
            sortUploadPartResults(multipartEtags)

            // 构造 XML body
            multipartUploadList.clear()
            multipartUploadList.write(
                "<?xml version=\"1.0\" encoding=\"UTF-8\"?><CompleteMultipartUpload xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">"
            )
            for (i in 0..multipartEtags.size) {
                let tag = multipartEtags[i]
                multipartUploadList.write(
                    "<Part><PartNumber>${tag.number}</PartNumber><ETag>${tag.etag}</ETag></Part>"
                )
            }
            multipartEtags.clear()
            multipartUploadList.write("</CompleteMultipartUpload>")

            // 提交
            commitMultiPartRequest()
        } else if (state == MultipartUploadState.SINGLE_FILE_STARTED) {
            state = MultipartUploadState.FINISHED
            callback(S3UploadResult.success(), callbackContext)
            MultiPartUpload.deref(this)
        }
    }

    // ========================================================================
    // startMultiPartRequestResult - 启动多部分请求结果
    // 严格翻译自: pub fn start_multi_part_request_result(
    //   result: S3DownloadResult, `this`: *c_void) -> JsTerminatedResult<()>
    // (multipart.rs line 660-723)
    // ========================================================================

    /// 启动多部分请求结果
    /// 对应 Bun: startMultiPartRequestResult
    /// 处理 CreateMultipartUpload 请求的响应
    public static func startMultiPartRequestResult(result: S3DownloadResult, self: MultiPartUpload): Unit {
        if (self.state == MultipartUploadState.FINISHED) {
            return
        }

        match (result.tag) {
            case S3DownloadResultTag.Failure =>
                if (result.error.isSome()) {
                    self.fail(result.error.getOrThrow())
                } else {
                    self.fail(S3Error("UnknownError", "Failed to initiate multipart upload"))
                }
            case S3DownloadResultTag.Success =>
                self.uploadidBuffer = result.body
                match (parseUploadId(result.body.toString())) {
                    case Some(uploadId) => self.uploadId = uploadId
                    case None =>
                        self.fail(S3Error("InvalidMultipartResponse", "S3 CreateMultipartUpload response did not include a valid UploadId"))
                        return
                }

                self.state = MultipartUploadState.MULTIPART_COMPLETED
                // 开始排空分片
                self.drainEnqueuedParts(UInt64(0))
            case S3DownloadResultTag.NotFound =>
                self.fail(S3Error("UnknownError", "Failed to initiate multipart upload"))
        }
    }

    // ========================================================================
    // onCommitMultiPartRequest - 提交多部分请求回调
    // 严格翻译自: pub fn on_commit_multi_part_request(
    //   result: S3CommitResult, `this`: *c_void) -> JsTerminatedResult<()>
    // (multipart.rs line 726-762)
    // ========================================================================

    /// 提交多部分请求回调
    /// 对应 Bun: onCommitMultiPartRequest
    /// 尽力提交多部分上传，失败时重试
    public static func onCommitMultiPartRequest(result: S3CommitResult, self: MultiPartUpload): Unit {
        match (result.tag) {
            case S3CommitResultTag.Failure =>
                if (result.error.isSome()) {
                    let err = result.error.getOrThrow()
                    if (self.options.retry > 0) {
                        self.options.retry -= 1
                        self.commitMultiPartRequest()
                        return
                    }
                    self.state = MultipartUploadState.FINISHED
                    self.callback(S3UploadResult.failure(err), self.callbackContext)
                    MultiPartUpload.deref(self)
                } else {
                    self.state = MultipartUploadState.FINISHED
                    MultiPartUpload.deref(self)
                }
            case S3CommitResultTag.Success =>
                self.state = MultipartUploadState.FINISHED
                self.callback(S3UploadResult.success(), self.callbackContext)
                MultiPartUpload.deref(self)
        }
    }

    // ========================================================================
    // onRollbackMultiPartRequest - 回滚多部分请求回调
    // 严格翻译自: pub fn on_rollback_multi_part_request(
    //   result: S3UploadResult, `this`: *c_void) -> JsTerminatedResult<()>
    // (multipart.rs line 765-793)
    // ========================================================================

    /// 回滚多部分请求回调
    /// 对应 Bun: onRollbackMultiPartRequest
    /// 尽力回滚，失败时重试，最终释放引用
    public static func onRollbackMultiPartRequest(result: S3UploadResult, self: MultiPartUpload): Unit {
        match (result.tag) {
            case S3UploadResultTag.Failure =>
                if (self.options.retry > 0) {
                    self.options.retry -= 1
                    self.rollbackMultiPartRequest()
                    return
                }
                MultiPartUpload.deref(self)
            case S3UploadResultTag.Success =>
                MultiPartUpload.deref(self)
        }
    }

    // ========================================================================
    // commitMultiPartRequest - 提交多部分上传
    // 严格翻译自: fn commit_multi_part_request(&self) -> JsTerminatedResult<()>
    // (multipart.rs line 795-824)
    // ========================================================================

    /// 提交多部分上传
    /// 对应 Bun: commitMultiPartRequest
    /// 发送 CompleteMultipartUpload 请求
    public func commitMultiPartRequest(): Unit {
        let searchParams = "?uploadId=${uploadId}"

        let options = S3SimpleRequestOptions()
        options.path = path
        options.method = HttpMethod.POST
        options.proxyUrl = proxyUrl()
        options.body = multipartUploadListToString()
        options.searchParams = searchParams
        options.requestPayer = requestPayer

        executeSimpleS3CommitRequest(
            credentials,
            options,
            { result: S3CommitResult, _: UIntNative =>
                MultiPartUpload.onCommitMultiPartRequest(result, this)
            },
            UIntNative(0)
        )
    }

    // ========================================================================
    // rollbackMultiPartRequest - 回滚多部分上传
    // 严格翻译自: fn rollback_multi_part_request(&self) -> JsTerminatedResult<()>
    // (multipart.rs line 826-855)
    // ========================================================================

    /// 回滚多部分上传
    /// 对应 Bun: rollbackMultiPartRequest
    /// 发送 AbortMultipartUpload 请求删除已上传的分片
    public func rollbackMultiPartRequest(): Unit {
        let searchParams = "?uploadId=${uploadId}"

        let options = S3SimpleRequestOptions()
        options.path = path
        options.method = HttpMethod.DELETE
        options.proxyUrl = proxyUrl()
        options.body = ""
        options.searchParams = searchParams
        options.requestPayer = requestPayer

        executeSimpleS3UploadRequest(
            credentials,
            options,
            { result: S3UploadResult, _: UIntNative =>
                MultiPartUpload.onRollbackMultiPartRequest(result, this)
            },
            UIntNative(0)
        )
    }

    // ========================================================================
    // enqueuePart - 入队分片
    // 严格翻译自: fn enqueue_part(&self, chunk: &[u8], allocated_size: usize,
    //   needs_clone: bool) -> JsTerminatedResult<bool> (multipart.rs line 857-896)
    // ========================================================================

    /// 入队分片
    /// 对应 Bun: enqueuePart
    /// 将数据分片入队，如果尚未启动多部分上传则先发起初始化请求
    public func enqueuePart(chunk: String, allocatedSize: Int64, needsClone: Bool): Bool {
        let optPart = getCreatePart(chunk, allocatedSize, needsClone)
        match (optPart) {
            case None => return false
            case Some(_) => ()
        }
        let part = optPart.getOrThrow()

        if (state == MultipartUploadState.NOT_STARTED) {
            // 将自动启动多部分上传
            state = MultipartUploadState.MULTIPART_STARTED
            ref()

            let options = S3SimpleRequestOptions()
            options.path = path
            options.method = HttpMethod.POST
            options.proxyUrl = proxyUrl()
            options.body = ""
            options.searchParams = "?uploads="
            options.contentType = optionalHeader(contentType)
            options.contentDisposition = optionalHeader(contentDisposition)
            options.contentEncoding = optionalHeader(contentEncoding)
            options.acl = acl
            options.storageClass = storageClass
            options.requestPayer = requestPayer

            executeSimpleS3MultipartStartRequest(
                credentials,
                options,
                { result: S3DownloadResult, _: UIntNative =>
                    MultiPartUpload.startMultiPartRequestResult(result, this)
                },
                UIntNative(0)
            )
        } else if (state == MultipartUploadState.MULTIPART_COMPLETED) {
            part.start()
        }
        return true
    }

    // ========================================================================
    // processMultiPart - 处理多部分上传
    // 严格翻译自: fn process_multi_part(&self, part_size: usize)
    //   -> JsTerminatedResult<()> (multipart.rs line 898-997)
    // ========================================================================

    /// 处理多部分上传
    /// 对应 Bun: processMultiPart
    /// 将缓冲数据分割为分片并上传
    public func processMultiPart(partSize: Int64): Unit {
        if (buffered.isEmpty() && isQueueEmpty() && ended) {
            // 没有更多数据要发送
            done()
            return
        }

        while (buffered.isNotEmpty()) {
            let len = partSize
            if (len > buffered.size()) {
                if (!ended) {
                    // 切片太小，等待更多数据
                    break
                }
            }
            let actualLen = if (len > buffered.size()) { buffered.size() } else { len }

            if (actualLen < partSize && !ended) {
                break
            }

            // 如果是完整的一个缓冲块，直接传递所有权
            if (buffered.cursor == 0 && buffered.size() == actualLen) {
                let allocatedSize = buffered.memoryCost()
                let slice = buffered.slice()

                if (enqueuePart(slice, allocatedSize, false)) {
                    // 队列未满，清空缓冲区
                    buffered = StreamBuffer()
                    return
                }
                // 队列已满
                return
            }

            // 需要切片
            let slice = buffered.sliceRange(0, actualLen)
            if (enqueuePart(slice, actualLen, true)) {
                // 队列未满，移动偏移
                buffered.wrote(actualLen)
            } else {
                // 队列已满
                break
            }
        }

        if (buffered.isEmpty()) {
            buffered.reset()
        }
    }

    // ========================================================================
    // proxyUrl - 获取代理 URL
    // 严格翻译自: pub fn proxy_url(&self) -> Option<&[u8]> (multipart.rs line 999-1001)
    // ========================================================================

    /// 获取代理 URL
    /// 对应 Bun: proxyUrl
    public func proxyUrl(): String {
        return proxy
    }

    // ========================================================================
    // processBuffered - 处理缓冲数据
    // 严格翻译自: fn process_buffered(&self, part_size: usize) (multipart.rs line 1003-1038)
    // ========================================================================

    /// 处理缓冲数据
    /// 对应 Bun: processBuffered
    /// 决定是发送单个请求还是多部分上传
    public func processBuffered(partSize: Int64): Unit {
        if (ended && buffered.size() < partSizeInBytes() && state == MultipartUploadState.NOT_STARTED) {
            // 单次上传
            state = MultipartUploadState.SINGLE_FILE_STARTED

            let options = S3SimpleRequestOptions()
            options.path = path
            options.method = HttpMethod.PUT
            options.proxyUrl = proxyUrl()
            options.body = buffered.slice()
            options.contentType = optionalHeader(contentType)
            options.contentDisposition = optionalHeader(contentDisposition)
            options.contentEncoding = optionalHeader(contentEncoding)
            options.acl = acl
            options.storageClass = storageClass
            options.requestPayer = requestPayer

            executeSimpleS3UploadRequest(
                credentials,
                options,
                { result: S3UploadResult, _: UIntNative =>
                    MultiPartUpload.singleSendUploadResponse(result, this)
                },
                UIntNative(0)
            )
        } else {
            // 需要分割为多个分片
            processMultiPart(partSize)
        }
    }

    // ========================================================================
    // partSizeInBytes - 获取分块大小（字节）
    // 严格翻译自: pub fn part_size_in_bytes(&self) -> usize (multipart.rs line 1040-1042)
    // ========================================================================

    /// 获取分块大小（字节）
    /// 对应 Bun: partSizeInBytes
    public func partSizeInBytes(): Int64 {
        return options.partSize
    }

    // ========================================================================
    // continueStream - 继续流处理
    // 严格翻译自: pub fn continue_stream(&self) (multipart.rs line 1044-1051)
    // ========================================================================

    /// 继续流处理
    /// 对应 Bun: continueStream
    /// 从 WaitStreamCheck 状态转换到 NotStarted 并处理缓冲数据
    public func continueStream(): Unit {
        if (state == MultipartUploadState.WAIT_STREAM_CHECK) {
            state = MultipartUploadState.NOT_STARTED
            if (ended) {
                processBuffered(partSizeInBytes())
            }
        }
    }

    // ========================================================================
    // hasBackpressure - 是否有背压
    // 严格翻译自: pub fn has_backpressure(&self) -> bool (multipart.rs line 1053-1060)
    // ========================================================================

    /// 是否有背压
    /// 对应 Bun: hasBackpressure
    /// 如果队列已满（没有可用槽位），返回 true
    public func hasBackpressure(): Bool {
        let optIndex = available.findFirstSet()
        match (optIndex) {
            case None => return true
            case Some(_) => ()
        }
        let index = optIndex.getOrThrow()
        return index >= Int64(options.queueSize)
    }

    // ========================================================================
    // isQueueEmpty - 队列是否为空
    // 严格翻译自: pub fn is_queue_empty(&self) -> bool (multipart.rs line 1062-1064)
    // ========================================================================

    /// 队列是否为空
    /// 对应 Bun: isQueueEmpty
    /// 所有分片槽位都可用时返回 true
    public func isQueueEmpty(): Bool {
        // 当所有位都设置了，表示所有槽位都可用
        let optIndex = available.findFirstUnset()
        match (optIndex) {
            case None => return true
            case Some(idx) => return idx >= Int64(options.queueSize)
        }
    }

    // ========================================================================
    // write - 写入数据
    // 严格翻译自: fn write(&self, encoding: WriteEncoding, chunk: &[u8],
    //   is_last: bool) -> Result<ResumableSinkBackpressure, AllocError>
    // (multipart.rs line 1070-1141)
    // ========================================================================

    /// 写入数据
    /// 对应 Bun: write
    /// 将数据写入缓冲区，根据状态决定是否触发上传
    public func write(encoding: WriteEncoding, chunk: String, isLast: Bool): ResumableSinkBackpressure {
        if (ended) {
            return ResumableSinkBackpressure.DONE
        }

        // 保持引用直到处理完成
        ref()

        if (state == MultipartUploadState.WAIT_STREAM_CHECK && chunk.size == 0 && isLast) {
            // 流关闭但文件可能不存在，不发送空分片
            ended = true
            if (buffered.size() > 0) {
                processBuffered(partSizeInBytes())
            }
            deref(this)
            return if (hasBackpressure()) {
                ResumableSinkBackpressure.BACKPRESSURE
            } else {
                ResumableSinkBackpressure.WANT_MORE
            }
        }

        if (isLast) {
            ended = true
            if (chunk.size > 0) {
                match (encoding) {
                    case WriteEncoding.BYTES => buffered.write(chunk)
                    case WriteEncoding.LATIN1 => buffered.writeLatin1(chunk)
                    case WriteEncoding.UTF16 => buffered.writeUtf16(chunk)
                }
            }
            processBuffered(partSizeInBytes())
        } else {
            // 仍有更多数据，收到空 chunk 无需处理
            if (chunk.size == 0) {
                deref(this)
                return if (hasBackpressure()) {
                    ResumableSinkBackpressure.BACKPRESSURE
                } else {
                    ResumableSinkBackpressure.WANT_MORE
                }
            }
            match (encoding) {
                case WriteEncoding.BYTES => buffered.write(chunk)
                case WriteEncoding.LATIN1 => buffered.writeLatin1(chunk)
                case WriteEncoding.UTF16 => buffered.writeUtf16(chunk)
            }
            let partSize = partSizeInBytes()
            if (buffered.size() >= partSize) {
                // 有足够数据，发送分片
                processBuffered(partSize)
            }
        }

        deref(this)
        return if (hasBackpressure()) {
            ResumableSinkBackpressure.BACKPRESSURE
        } else {
            ResumableSinkBackpressure.WANT_MORE
        }
    }

    // ========================================================================
    // writeLatin1 / writeUtf16 / writeBytes - 编码特定的写入方法
    // 严格翻译自: pub fn write_latin1/write_utf16/write_bytes (multipart.rs line 1143-1165)
    // ========================================================================

    /// 写入 Latin1 编码数据
    /// 对应 Bun: writeLatin1
    public func writeLatin1(chunk: String, isLast: Bool): ResumableSinkBackpressure {
        return write(WriteEncoding.LATIN1, chunk, isLast)
    }

    /// 写入 UTF-16 编码数据
    /// 对应 Bun: writeUtf16
    public func writeUtf16(chunk: String, isLast: Bool): ResumableSinkBackpressure {
        return write(WriteEncoding.UTF16, chunk, isLast)
    }

    /// 写入字节
    /// 对应 Bun: writeBytes
    public func writeBytes(chunk: String, isLast: Bool): ResumableSinkBackpressure {
        return write(WriteEncoding.BYTES, chunk, isLast)
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 将 multipartUploadList 转为字符串
    private func multipartUploadListToString(): String {
        return multipartUploadList.toString()
    }
}

// ============================================================================
// ResumableSinkBackpressure - 可恢复 Sink 背压
// 对应 Bun: ResumableSinkBackpressure enum
// ============================================================================

/// 可恢复 Sink 背压
/// 对应 Bun: ResumableSinkBackpressure
public enum ResumableSinkBackpressure {
    | DONE
    | BACKPRESSURE
    | WANT_MORE

    public operator func == (other: ResumableSinkBackpressure): Bool {
        match (this) {
            case DONE => match (other) { case DONE => true case _ => false }
            case BACKPRESSURE => match (other) { case BACKPRESSURE => true case _ => false }
            case WANT_MORE => match (other) { case WANT_MORE => true case _ => false }
        }
    }
}

// ported from: src/runtime/webcore/s3/multipart.rs
