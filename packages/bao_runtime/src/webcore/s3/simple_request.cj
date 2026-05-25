// 严格翻译自: src/runtime/webcore/s3/simple_request.zig
// S3 简单请求 - 包含所有 S3 操作的结果类型、S3HttpSimpleTask 和 executeSimpleS3Request
package bao_runtime.webcore.s3

import bao_core.*
import bao_collections.*
import bao_jsc.*

// ============================================================================
// S3StatResult - S3 Stat 操作结果
// 严格翻译自: S3StatResult union(enum)
// Bun: pub const S3StatResult = union(enum) {
//   success: struct { size, etag, lastModified, contentType },
//   not_found: S3Error,
//   failure: S3Error,
// }
// ============================================================================

/// S3 Stat 操作结果
/// 对应 Bun: S3StatResult union(enum)
public enum S3StatResultTag {
    | Success
    | NotFound
    | Failure

    public operator func ==(right: S3StatResultTag): Bool {
        match (this) {
            case Success => match (right) { case Success => true; case _ => false }
            case NotFound => match (right) { case NotFound => true; case _ => false }
            case Failure => match (right) { case Failure => true; case _ => false }
        }
    }
}

/// S3 Stat 操作结果
/// 对应 Bun: S3StatResult union(enum)
public class S3StatResult {
    /// 结果标签
    public var tag: S3StatResultTag

    // Success 字段
    /// 文件大小
    /// 对应 Bun: success.size: usize = 0
    public var size: Int64

    /// ETag (不拥有，回调后需复制)
    /// 对应 Bun: success.etag: []const u8 = ""
    public var etag: String

    /// 最后修改时间 (格式: Mon, 06 Jan 2025 22:40:57 GMT，不拥有)
    /// 对应 Bun: success.lastModified: []const u8 = ""
    public var lastModified: String

    /// 内容类型 (格式: text/plain，不拥有)
    /// 对应 Bun: success.contentType: []const u8 = ""
    public var contentType: String

    // Error 字段
    /// 错误 (不拥有)
    public var error: ?S3Error

    public static func success(size: Int64, etag: String, lastModified: String, contentType: String): S3StatResult {
        let r = S3StatResult()
        r.tag = S3StatResultTag.Success
        r.size = size
        r.etag = etag
        r.lastModified = lastModified
        r.contentType = contentType
        return r
    }

    public static func notFound(err: S3Error): S3StatResult {
        let r = S3StatResult()
        r.tag = S3StatResultTag.NotFound
        r.error = Some(err)
        return r
    }

    public static func failure(err: S3Error): S3StatResult {
        let r = S3StatResult()
        r.tag = S3StatResultTag.Failure
        r.error = Some(err)
        return r
    }

    private init() {
        tag = S3StatResultTag.Failure
        size = 0
        etag = ""
        lastModified = ""
        contentType = ""
        error = None
    }
}

// ============================================================================
// S3DownloadResult - S3 下载操作结果
// 严格翻译自: S3DownloadResult union(enum)
// Bun: pub const S3DownloadResult = union(enum) {
//   success: struct { etag, body },
//   not_found: S3Error,
//   failure: S3Error,
// }
// ============================================================================

/// S3 下载操作结果标签
public enum S3DownloadResultTag {
    | Success
    | NotFound
    | Failure
}

/// S3 下载操作结果
/// 对应 Bun: S3DownloadResult union(enum)
public class S3DownloadResult {
    /// 结果标签
    public var tag: S3DownloadResultTag

    /// ETag (不拥有)
    public var etag: String

    /// 下载体 (拥有，需释放)
    /// 对应 Bun: success.body: bun.MutableString
    public var body: MutableString

    /// 错误 (不拥有)
    public var error: ?S3Error

    public static func success(etag: String, body: MutableString): S3DownloadResult {
        let r = S3DownloadResult()
        r.tag = S3DownloadResultTag.Success
        r.etag = etag
        r.body = body
        return r
    }

    public static func notFound(err: S3Error): S3DownloadResult {
        let r = S3DownloadResult()
        r.tag = S3DownloadResultTag.NotFound
        r.error = Some(err)
        return r
    }

    public static func failure(err: S3Error): S3DownloadResult {
        let r = S3DownloadResult()
        r.tag = S3DownloadResultTag.Failure
        r.error = Some(err)
        return r
    }

    private init() {
        tag = S3DownloadResultTag.Failure
        etag = ""
        body = MutableString()
        error = None
    }
}

// ============================================================================
// S3UploadResult - S3 上传操作结果
// 严格翻译自: S3UploadResult union(enum)
// Bun: pub const S3UploadResult = union(enum) { success: void, failure: S3Error }
// ============================================================================

/// S3 上传操作结果标签
public enum S3UploadResultTag {
    | Success
    | Failure
}

/// S3 上传操作结果
/// 对应 Bun: S3UploadResult union(enum)
public class S3UploadResult {
    /// 结果标签
    public var tag: S3UploadResultTag

    /// 错误 (不拥有)
    public var error: ?S3Error

    public static func success(): S3UploadResult {
        let r = S3UploadResult()
        r.tag = S3UploadResultTag.Success
        return r
    }

    public static func failure(err: S3Error): S3UploadResult {
        let r = S3UploadResult()
        r.tag = S3UploadResultTag.Failure
        r.error = Some(err)
        return r
    }

    private init() {
        tag = S3UploadResultTag.Failure
        error = None
    }
}

// ============================================================================
// S3DeleteResult - S3 删除操作结果
// 严格翻译自: S3DeleteResult union(enum)
// Bun: pub const S3DeleteResult = union(enum) { success: void, not_found: S3Error, failure: S3Error }
// ============================================================================

/// S3 删除操作结果标签
public enum S3DeleteResultTag {
    | Success
    | NotFound
    | Failure
}

/// S3 删除操作结果
/// 对应 Bun: S3DeleteResult union(enum)
public class S3DeleteResult {
    /// 结果标签
    public var tag: S3DeleteResultTag

    /// 错误 (不拥有)
    public var error: ?S3Error

    public static func success(): S3DeleteResult {
        let r = S3DeleteResult()
        r.tag = S3DeleteResultTag.Success
        return r
    }

    public static func notFound(err: S3Error): S3DeleteResult {
        let r = S3DeleteResult()
        r.tag = S3DeleteResultTag.NotFound
        r.error = Some(err)
        return r
    }

    public static func failure(err: S3Error): S3DeleteResult {
        let r = S3DeleteResult()
        r.tag = S3DeleteResultTag.Failure
        r.error = Some(err)
        return r
    }

    private init() {
        tag = S3DeleteResultTag.Failure
        error = None
    }
}

// ============================================================================
// S3ListObjectsResult - S3 列出对象结果
// 严格翻译自: S3ListObjectsResult union(enum)
// ============================================================================

/// S3 列出对象结果标签
public enum S3ListObjectsResultTag {
    | Success
    | NotFound
    | Failure
}

/// S3 列出对象结果
/// 对应 Bun: S3ListObjectsResult union(enum)
public class S3ListObjectsResultEx {
    /// 结果标签
    public var tag: S3ListObjectsResultTag

    /// 成功时的结果
    public var listResult: ?S3ListObjectsV2Result

    /// 错误 (不拥有)
    public var error: ?S3Error

    public static func success(result: S3ListObjectsV2Result): S3ListObjectsResultEx {
        let r = S3ListObjectsResultEx()
        r.tag = S3ListObjectsResultTag.Success
        r.listResult = Some(result)
        return r
    }

    public static func notFound(err: S3Error): S3ListObjectsResultEx {
        let r = S3ListObjectsResultEx()
        r.tag = S3ListObjectsResultTag.NotFound
        r.error = Some(err)
        return r
    }

    public static func failure(err: S3Error): S3ListObjectsResultEx {
        let r = S3ListObjectsResultEx()
        r.tag = S3ListObjectsResultTag.Failure
        r.error = Some(err)
        return r
    }

    private init() {
        tag = S3ListObjectsResultTag.Failure
        listResult = None
        error = None
    }
}

// ============================================================================
// S3CommitResult - S3 Commit 操作结果
// 严格翻译自: S3CommitResult union(enum)
// Bun: commit result also fails if status 200 but with body containing an Error
// ============================================================================

/// S3 Commit 操作结果标签
public enum S3CommitResultTag {
    | Success
    | Failure
}

/// S3 Commit 操作结果
/// 对应 Bun: S3CommitResult union(enum)
/// 即使状态码为 200，如果 body 包含错误也会失败
public class S3CommitResult {
    /// 结果标签
    public var tag: S3CommitResultTag

    /// 错误 (不拥有)
    public var error: ?S3Error

    public static func success(): S3CommitResult {
        let r = S3CommitResult()
        r.tag = S3CommitResultTag.Success
        return r
    }

    public static func failure(err: S3Error): S3CommitResult {
        let r = S3CommitResult()
        r.tag = S3CommitResultTag.Failure
        r.error = Some(err)
        return r
    }

    private init() {
        tag = S3CommitResultTag.Failure
        error = None
    }
}

// ============================================================================
// S3PartResult - S3 分块上传结果
// 严格翻译自: S3PartResult union(enum)
// ============================================================================

/// S3 分块上传结果标签
public enum S3PartResultTag {
    | Etag
    | Failure
}

/// S3 分块上传结果
/// 对应 Bun: S3PartResult union(enum)
public class S3PartResult {
    /// 结果标签
    public var tag: S3PartResultTag

    /// ETag (不拥有)
    public var etag: String

    /// 错误 (不拥有)
    public var error: ?S3Error

    public static func etagResult(etag: String): S3PartResult {
        let r = S3PartResult()
        r.tag = S3PartResultTag.Etag
        r.etag = etag
        return r
    }

    public static func failure(err: S3Error): S3PartResult {
        let r = S3PartResult()
        r.tag = S3PartResultTag.Failure
        r.error = Some(err)
        return r
    }

    private init() {
        tag = S3PartResultTag.Failure
        etag = ""
        error = None
    }
}

// ============================================================================
// S3SimpleRequestOptions - S3 简单请求选项
// 严格翻译自: S3SimpleRequestOptions struct
// Bun: pub const S3SimpleRequestOptions = struct {
//   path, method, search_params, content_type, content_disposition,
//   content_encoding, body, proxy_url, range, acl, storage_class, request_payer
// }
// ============================================================================

/// S3 简单请求选项
/// 对应 Bun: S3SimpleRequestOptions struct
public class S3SimpleRequestOptions {
    /// S3 路径
    /// 对应 Bun: path: []const u8
    public var path: String

    /// HTTP 方法
    /// 对应 Bun: method: bun.http.Method
    public var method: HttpMethod

    /// 查询参数
    /// 对应 Bun: search_params: ?[]const u8 = null
    public var searchParams: String

    /// Content-Type
    /// 对应 Bun: content_type: ?[]const u8 = null
    public var contentType: String

    /// Content-Disposition
    /// 对应 Bun: content_disposition: ?[]const u8 = null
    public var contentDisposition: String

    /// Content-Encoding
    /// 对应 Bun: content_encoding: ?[]const u8 = null
    public var contentEncoding: String

    /// HTTP 请求体
    /// 对应 Bun: body: []const u8
    public var body: String

    /// 代理 URL
    /// 对应 Bun: proxy_url: ?[]const u8 = null
    public var proxyUrl: String

    /// HTTP Range 头
    /// 对应 Bun: range: ?[]const u8 = null
    public var range: String

    /// ACL
    /// 对应 Bun: acl: ?ACL = null
    public var acl: ?S3Acl

    /// 存储类别
    /// 对应 Bun: storage_class: ?StorageClass = null
    public var storageClass: ?S3StorageClass

    /// 是否请求付费
    /// 对应 Bun: request_payer: bool = false
    public var requestPayer: Bool

    public init() {
        path = ""
        method = HttpMethod.GET
        searchParams = ""
        contentType = ""
        contentDisposition = ""
        contentEncoding = ""
        body = ""
        proxyUrl = ""
        range = ""
        acl = None
        storageClass = None
        requestPayer = false
    }
}

// ============================================================================
// S3HttpSimpleTask - S3 简单 HTTP 任务
// 严格翻译自: S3HttpSimpleTask struct
// Bun: pub const S3HttpSimpleTask = struct { http, vm, sign_result, headers,
//   callback_context, callback, response_buffer, result, concurrent_task,
//   range, proxy_url, poll_ref, pub const Callback, deinit, errorWithBody,
//   failIfContainsError, onResponse, httpCallback }
// ============================================================================

/// S3 简单 HTTP 任务回调
/// 对应 Bun: S3HttpSimpleTask.Callback union(enum)
public enum S3CallbackKind {
    | Stat
    | Download
    | Upload
    | Delete
    | ListObjects
    | Commit
    | Part
}

/// S3 简单 HTTP 任务
/// 对应 Bun: S3HttpSimpleTask struct
/// 执行 S3 操作 (stat, download, upload, delete, listObjects, commit, part)
/// 的简单 HTTP 任务，使用 AsyncHTTP 进行异步请求
public class S3HttpSimpleTask {
    /// HTTP 异步请求
    /// 对应 Bun: http: bun.http.AsyncHTTP
    public var http: AsyncHttp

    /// 虚拟机引用
    /// 对应 Bun: vm: *jsc.VirtualMachine
    public var vm: VirtualMachine

    /// 签名结果
    /// 对应 Bun: sign_result: SignResult
    public var signResult: S3SignResult

    /// HTTP 头
    /// 对应 Bun: headers: bun.http.Headers
    public var headers: HttpHeaders

    /// 回调上下文
    /// 对应 Bun: callback_context: *anyopaque
    public var callbackContext: UIntNative = 0

    /// 回调类型
    /// 对应 Bun: callback: Callback
    public var callbackKind: S3CallbackKind

    /// 回调函数: stat
    public var statCallback: (S3StatResult, UIntNative) -> Unit
    /// 回调函数: download
    public var downloadCallback: (S3DownloadResult, UIntNative) -> Unit
    /// 回调函数: upload
    public var uploadCallback: (S3UploadResult, UIntNative) -> Unit
    /// 回调函数: delete
    public var deleteCallback: (S3DeleteResult, UIntNative) -> Unit
    /// 回调函数: listObjects
    public var listObjectsCallback: (S3ListObjectsResultEx, UIntNative) -> Unit
    /// 回调函数: commit
    public var commitCallback: (S3CommitResult, UIntNative) -> Unit
    /// 回调函数: part
    public var partCallback: (S3PartResult, UIntNative) -> Unit

    /// 响应缓冲区
    /// 对应 Bun: response_buffer: bun.MutableString
    public var responseBuffer: MutableString

    /// HTTP 客户端结果
    /// 对应 Bun: result: bun.http.HTTPClientResult
    public var result: HttpClientResult

    /// 并发任务
    /// 对应 Bun: concurrent_task: jsc.ConcurrentTask
    public var concurrentTask: ConcurrentTask

    /// HTTP Range 头
    /// 对应 Bun: range: ?[]const u8
    public var range: String

    /// 代理 URL (拥有的副本)
    /// 对应 Bun: proxy_url: []const u8 = ""
    public var proxyUrl: String

    /// 轮询引用
    /// 对应 Bun: poll_ref: bun.Async.KeepAlive
    public var pollRef: KeepAlive

    public init(vm: VirtualMachine) {
        this.vm = vm
        http = AsyncHttp()
        signResult = S3SignResult()
        headers = HttpHeaders()
        callbackKind = S3CallbackKind.Stat
        responseBuffer = MutableString()
        result = HttpClientResult()
        concurrentTask = ConcurrentTask()
        range = ""
        proxyUrl = ""
        pollRef = KeepAlive()
        statCallback = { _: S3StatResult, _: UIntNative => }
        downloadCallback = { _: S3DownloadResult, _: UIntNative => }
        uploadCallback = { _: S3UploadResult, _: UIntNative => }
        deleteCallback = { _: S3DeleteResult, _: UIntNative => }
        listObjectsCallback = { _: S3ListObjectsResultEx, _: UIntNative => }
        commitCallback = { _: S3CommitResult, _: UIntNative => }
        partCallback = { _: S3PartResult, _: UIntNative => }
    }

    // ========================================================================
    // deinit - 释放资源
    // 严格翻译自: pub fn deinit(`this`: *@This()) void
    // ========================================================================

    /// 释放资源
    /// 对应 Bun: pub fn deinit(`this`: *@This()) void
    public func deinit(): Unit {
        pollRef.unref(vm)
        responseBuffer.deinit()
        headers.deinit()
        signResult.deinit()
        http.clearData()
        range = ""
        if (proxyUrl.size > 0) {
            proxyUrl = ""
        }
    }

    // ========================================================================
    // errorWithBody - 从响应体解析错误
    // 严格翻译自: fn errorWithBody(`this`: @This(), comptime error_type: ErrorType) bun.JSTerminated!void
    // ========================================================================

    /// 从响应体解析错误
    /// 对应 Bun: errorWithBody
    /// 从 HTTP 响应体 (可能为 XML) 中提取 <Code> 和 <Message> 标签
    /// 根据错误类型 (not_found / failure) 调用对应的回调
    public func errorWithBody(isNotFound: Bool): Unit {
        var code = "UnknownError"
        var message = "an unexpected error has occurred"
        var hasErrorCode = false

        if (result.fail) {
            code = "RequestError"
            hasErrorCode = true
        } else if (result.body.isSome()) {
            let bytes = result.body.getOrThrow().toString()
            if (bytes.size > 0) {
                message = bytes
                // 解析 XML <Code> — indexOf returns Option<Int64>
                let codeStartOpt = bytes.indexOf("<Code>")
                if (codeStartOpt.isSome()) {
                    let codeStart = codeStartOpt.getOrThrow()
                    let codeEndOpt = bytes.indexOf("</Code>")
                    if (codeEndOpt.isSome()) {
                        let codeEnd = codeEndOpt.getOrThrow()
                        if (codeEnd > codeStart) {
                            let start = codeStart + Int64("<Code>".size)
                            // manual substring: build from byte array
                            let arr = bytes.toArray()
                            var sub = ArrayList<UInt8>()
                            for (i in start..codeEnd) {
                                sub.append(arr[i])
                            }
                            code = String.fromUtf8(sub.toOwnedSlice())
                            hasErrorCode = true
                        }
                    }
                }
                // 解析 XML <Message>
                let msgStartOpt = bytes.indexOf("<Message>")
                if (msgStartOpt.isSome()) {
                    let msgStart = msgStartOpt.getOrThrow()
                    let msgEndOpt = bytes.indexOf("</Message>")
                    if (msgEndOpt.isSome()) {
                        let msgEnd = msgEndOpt.getOrThrow()
                        if (msgEnd > msgStart) {
                            let start = msgStart + Int64("<Message>".size)
                            let arr = bytes.toArray()
                            var sub = ArrayList<UInt8>()
                            for (i in start..msgEnd) {
                                sub.append(arr[i])
                            }
                            message = String.fromUtf8(sub.toOwnedSlice())
                        }
                    }
                }
            }
        }

        let err = S3Error(code, message)
        if (isNotFound) {
            if (!hasErrorCode) {
                code = "NoSuchKey"
                message = "The specified key does not exist."
            }
            failNotFound(code, message)
        } else {
            fail(code, message)
        }
    }

    // ========================================================================
    // failIfContainsError - 检查 200 响应中是否包含错误
    // 严格翻译自: fn failIfContainsError(`this`: *@This(), status: u32) bun.JSTerminated!bool
    // ========================================================================

    /// 检查 HTTP 200 响应中是否包含 S3 错误
    /// 对应 Bun: failIfContainsError
    /// 某些 S3 操作 (如 commit multipart) 即使状态码为 200 也可能包含错误
    public func failIfContainsError(status: UInt32): Bool {
        var code = "UnknownError"
        var message = "an unexpected error has occurred"

        if (result.fail) {
            code = "RequestError"
        } else if (result.body.isSome()) {
            let bytes = result.body.getOrThrow().toString()
            var hasError = false
            if (bytes.size > 0) {
                message = bytes
                let errTagOpt = bytes.indexOf("<Error>")
                if (errTagOpt.isSome()) {
                    hasError = true
                    let codeStartOpt = bytes.indexOf("<Code>")
                    if (codeStartOpt.isSome()) {
                        let codeStart = codeStartOpt.getOrThrow()
                        let codeEndOpt = bytes.indexOf("</Code>")
                        if (codeEndOpt.isSome()) {
                            let codeEnd = codeEndOpt.getOrThrow()
                            if (codeEnd > codeStart) {
                                let start = codeStart + Int64("<Code>".size)
                                let arr = bytes.toArray()
                                var sub = ArrayList<UInt8>()
                                for (i in start..codeEnd) {
                                    sub.append(arr[i])
                                }
                                code = String.fromUtf8(sub.toOwnedSlice())
                            }
                        }
                    }
                    let msgStartOpt = bytes.indexOf("<Message>")
                    if (msgStartOpt.isSome()) {
                        let msgStart = msgStartOpt.getOrThrow()
                        let msgEndOpt = bytes.indexOf("</Message>")
                        if (msgEndOpt.isSome()) {
                            let msgEnd = msgEndOpt.getOrThrow()
                            if (msgEnd > msgStart) {
                                let start = msgStart + Int64("<Message>".size)
                                let arr = bytes.toArray()
                                var sub = ArrayList<UInt8>()
                                for (i in start..msgEnd) {
                                    sub.append(arr[i])
                                }
                                message = String.fromUtf8(sub.toOwnedSlice())
                            }
                        }
                    }
                }
            }
            if (!hasError && (status == 200 || status == 206)) {
                return false
            }
        } else if (status == 200 || status == 206) {
            return false
        }
        fail(code, message)
        return true
    }

    // ========================================================================
    // Callback helper methods
    // 对应 Bun: Callback.fail, Callback.notFound
    // ========================================================================

    /// 报告失败
    /// 对应 Bun: Callback.fail(code, message, context)
    public func fail(code: String, message: String): Unit {
        let err = S3Error(code, message)
        match (callbackKind) {
            case S3CallbackKind.Stat =>
                statCallback(S3StatResult.failure(err), callbackContext)
            case S3CallbackKind.Download =>
                downloadCallback(S3DownloadResult.failure(err), callbackContext)
            case S3CallbackKind.Upload =>
                uploadCallback(S3UploadResult.failure(err), callbackContext)
            case S3CallbackKind.Delete =>
                deleteCallback(S3DeleteResult.failure(err), callbackContext)
            case S3CallbackKind.ListObjects =>
                listObjectsCallback(S3ListObjectsResultEx.failure(err), callbackContext)
            case S3CallbackKind.Commit =>
                commitCallback(S3CommitResult.failure(err), callbackContext)
            case S3CallbackKind.Part =>
                partCallback(S3PartResult.failure(err), callbackContext)
        }
    }

    /// 报告未找到
    /// 对应 Bun: Callback.notFound(code, message, context)
    public func failNotFound(code: String, message: String): Unit {
        let err = S3Error(code, message)
        match (callbackKind) {
            case S3CallbackKind.Stat =>
                statCallback(S3StatResult.notFound(err), callbackContext)
            case S3CallbackKind.Download =>
                downloadCallback(S3DownloadResult.notFound(err), callbackContext)
            case S3CallbackKind.Delete =>
                deleteCallback(S3DeleteResult.notFound(err), callbackContext)
            case S3CallbackKind.ListObjects =>
                listObjectsCallback(S3ListObjectsResultEx.notFound(err), callbackContext)
            case _ =>
                fail(code, message)
        }
    }

    // ========================================================================
    // onResponse - 主线程上的响应回调
    // 严格翻译自: pub fn onResponse(`this`: *@This()) bun.JSTerminated!void
    // ========================================================================

    /// 主线程上的响应回调
    /// 对应 Bun: pub fn onResponse(`this`: *@This()) bun.JSTerminated!void
    /// 根据回调类型和 HTTP 状态码分发结果
    public func onResponse(): Unit {
        // Cangjie has no defer; call deinit at every return point
        if (result.fail) {
            errorWithBody(false)
            deinit()
            return
        }

        let metadataOpt = result.metadata
        if (metadataOpt.isNone()) {
            fail("MissingResponseMetadata", "S3 response did not include HTTP metadata.")
            deinit()
            return
        }
        let metadata = metadataOpt.getOrThrow()
        let httpResponse = metadata.response

        match (callbackKind) {
            // ----------------------------------------------------------------
            // Stat
            // 对应 Bun: .stat => |callback| { ... }
            // 200: 返回 success 带 etag, lastModified, contentType, size
            // 404: not_found
            // 其他: failure
            // ----------------------------------------------------------------
            case S3CallbackKind.Stat =>
                match (httpResponse.statusCode) {
                    case 200 =>
                        let contentLength = metadata.get("content-length")
                        let size = match (contentLength) {
                            case Some(value) => Int64.parse(value) ?? 0
                            case None => 0
                        }
                        statCallback(S3StatResult.success(
                            size,
                            metadata.get("etag") ?? "",
                            metadata.get("last-modified") ?? "",
                            metadata.get("content-type") ?? ""
                        ), callbackContext)
                    case 404 => errorWithBody(true)
                    case _ => errorWithBody(false)
                }
            // ----------------------------------------------------------------
            // Delete
            // 对应 Bun: .delete => |callback| { ... }
            // 200/204: success
            // 404: not_found
            // 其他: failure
            // ----------------------------------------------------------------
            case S3CallbackKind.Delete =>
                match (httpResponse.statusCode) {
                    case 200 => deleteCallback(S3DeleteResult.success(), callbackContext)
                    case 204 => deleteCallback(S3DeleteResult.success(), callbackContext)
                    case 404 => errorWithBody(true)
                    case _ => errorWithBody(false)
                }
            // ----------------------------------------------------------------
            // ListObjects
            // 对应 Bun: .listObjects => |callback| { ... }
            // 200: 解析 XML 响应体
            // 404: not_found
            // 其他: failure
            // ----------------------------------------------------------------
            case S3CallbackKind.ListObjects =>
                match (httpResponse.statusCode) {
                    case 200 =>
                        if (result.body.isSome()) {
                            let success = parseS3ListObjectsResult(result.body.getOrThrow().toString())
                            listObjectsCallback(S3ListObjectsResultEx.success(success), callbackContext)
                        } else {
                            errorWithBody(false)
                        }
                    case 404 => errorWithBody(true)
                    case _ => errorWithBody(false)
                }
            // ----------------------------------------------------------------
            // Upload
            // 对应 Bun: .upload => |callback| { ... }
            // 200: success
            // 其他: failure
            // ----------------------------------------------------------------
            case S3CallbackKind.Upload =>
                match (httpResponse.statusCode) {
                    case 200 => uploadCallback(S3UploadResult.success(), callbackContext)
                    case _ => errorWithBody(false)
                }
            // ----------------------------------------------------------------
            // Download
            // 对应 Bun: .download => |callback| { ... }
            // 200/204/206: 返回 success 带 etag 和 body
            // 404: not_found
            // 其他: failure
            // ----------------------------------------------------------------
            case S3CallbackKind.Download =>
                match (httpResponse.statusCode) {
                    case 200 =>
                        let body = responseBuffer
                        responseBuffer = MutableString()
                        downloadCallback(S3DownloadResult.success(
                            metadata.get("etag") ?? "",
                            body
                        ), callbackContext)
                    case 204 =>
                        let body = responseBuffer
                        responseBuffer = MutableString()
                        downloadCallback(S3DownloadResult.success(
                            metadata.get("etag") ?? "",
                            body
                        ), callbackContext)
                    case 206 =>
                        let body = responseBuffer
                        responseBuffer = MutableString()
                        downloadCallback(S3DownloadResult.success(
                            metadata.get("etag") ?? "",
                            body
                        ), callbackContext)
                    case 404 => errorWithBody(true)
                    case _ => errorWithBody(false)
                }
            // ----------------------------------------------------------------
            // Commit
            // 对应 Bun: .commit => |callback| { ... }
            // commit multipart 可能 200 但 body 包含错误
            // ----------------------------------------------------------------
            case S3CallbackKind.Commit =>
                if (!failIfContainsError(httpResponse.statusCode)) {
                    commitCallback(S3CommitResult.success(), callbackContext)
                }
            // ----------------------------------------------------------------
            // Part
            // 对应 Bun: .part => |callback| { ... }
            // 从 ETag header 获取分块的 etag
            // ----------------------------------------------------------------
            case S3CallbackKind.Part =>
                if (!failIfContainsError(httpResponse.statusCode)) {
                    let etag = metadata.get("etag") ?? ""
                    if (etag.size > 0) {
                        partCallback(S3PartResult.etagResult(etag), callbackContext)
                    } else {
                        errorWithBody(false)
                    }
                }
        }
        deinit()
    }

    // ========================================================================
    // httpCallback - HTTP 线程回调
    // 严格翻译自: pub fn httpCallback(`this`: *@This(), async_http, result) void
    // ========================================================================

    /// HTTP 线程回调
    /// 对应 Bun: pub fn httpCallback(`this`: *@This(), async_http: *bun.http.AsyncHTTP, result: bun.http.HTTPClientResult) void
    public func httpCallback(asyncHttp: AsyncHttp, httpResult: HttpClientResult): Unit {
        let isDone = !httpResult.hasMore
        result = httpResult
        http = asyncHttp
        // stub: AsyncHttp has no responseBuffer field; keep existing buffer
        if (isDone) {
            vm.eventLoop().enqueueTaskConcurrent(concurrentTask.from(this))
        }
    }
}

// ============================================================================
// executeSimpleS3Request - 执行简单 S3 请求
// 严格翻译自: pub fn executeSimpleS3Request(
//   this: *const S3Credentials, options: S3SimpleRequestOptions,
//   callback: S3HttpSimpleTask.Callback, callback_context: *anyopaque
// ) bun.JSTerminated!void
// ============================================================================

/// 执行简单 S3 请求
/// 对应 Bun: executeSimpleS3Request
/// 签名请求、创建 HTTP 任务、调度执行
/// 流程:
/// 1. 使用 S3Credentials.signRequest 签名请求
/// 2. 构造 HTTP 头 (可能包含 Range 或 Content-Type)
/// 3. 创建 S3HttpSimpleTask
/// 4. 配置 AsyncHTTP (方法、URL、头、body、代理等)
/// 5. 调度 HTTP 请求
public func executeSimpleS3Request(
    credentials: S3Credentials,
    options: S3SimpleRequestOptions,
    callbackKind: S3CallbackKind,
    callbackContext: UIntNative
): Unit {
    let task = prepareSimpleS3Task(credentials, options, callbackKind, callbackContext)
    match (task) {
        case Some(t) =>
            if (!isSupportedSimpleRequestCallback(callbackKind)) {
                t.fail(
                    "NotImplemented",
                    simpleRequestNotImplementedMessage(callbackKind)
                )
                t.deinit()
                return
            }
            if (!isValidSimpleRequestMethod(callbackKind, options.method)) {
                t.fail(
                    "InvalidMethod",
                    simpleRequestInvalidMethodMessage(callbackKind)
                )
                t.deinit()
                return
            }
            scheduleSimpleS3Task(t, options.method, options.body)
        case None => ()
    }
}

public func executeSimpleS3StatRequest(
    credentials: S3Credentials,
    options: S3SimpleRequestOptions,
    callback: (S3StatResult, UIntNative) -> Unit,
    callbackContext: UIntNative
): Unit {
    let task = prepareSimpleS3StatTask(credentials, options, callback, callbackContext)
    match (task) {
        case Some(t) =>
            if (options.method != HttpMethod.HEAD) {
                t.fail("InvalidMethod", "S3 stat requests must use HEAD.")
                t.deinit()
                return
            }
            scheduleSimpleS3Task(t, HttpMethod.HEAD, "")
        case None => ()
    }
}

private func scheduleSimpleS3Task(t: S3HttpSimpleTask, method: HttpMethod, requestBody: String): Unit {
    let callback = BaoHTTPClientResultCallback()
    callback.fn_ = Some({ _: BaoHTTPClient, result: BaoHTTPClientResult =>
        t.result = HttpClientResult.fromBaoHttp(result)
        if (!t.result.hasMore) {
            t.onResponse()
        }
    })
    let httpOptions = BaoAsyncHTTPOptions()
    let realHttp = BaoAsyncHTTP.initFunc(
        method.toBaoHttpMethod(),
        BaoParsedUrl.parse(t.signResult.url),
        t.headers.toBaoHeaderEntryList(),
        "",
        t.responseBuffer,
        requestBody,
        callback,
        BaoFetchRedirect.follow,
        httpOptions
    )
    t.pollRef.ref(t.vm)
    let batch = BaoThreadPoolBatch()
    realHttp.schedule(batch)
    baoHttpThread.schedule(batch)
}

public func executeSimpleS3ListObjectsRequest(
    credentials: S3Credentials,
    options: S3SimpleRequestOptions,
    callback: (S3ListObjectsResultEx, UIntNative) -> Unit,
    callbackContext: UIntNative
): Unit {
    let task = S3HttpSimpleTask(VirtualMachine.get())
    task.callbackKind = S3CallbackKind.ListObjects
    task.callbackContext = callbackContext
    task.listObjectsCallback = callback
    match (prepareSimpleS3TaskWithTask(task, credentials, options)) {
        case Some(t) => scheduleSimpleS3Task(t, options.method, options.body)
        case None => ()
    }
}

public func executeSimpleS3DownloadRequest(
    credentials: S3Credentials,
    options: S3SimpleRequestOptions,
    callback: (S3DownloadResult, UIntNative) -> Unit,
    callbackContext: UIntNative
): Unit {
    let task = S3HttpSimpleTask(VirtualMachine.get())
    task.callbackKind = S3CallbackKind.Download
    task.callbackContext = callbackContext
    task.downloadCallback = callback
    match (prepareSimpleS3TaskWithTask(task, credentials, options)) {
        case Some(t) =>
            if (options.method != HttpMethod.GET) {
                t.fail("InvalidMethod", "S3 download requests must use GET.")
                t.deinit()
                return
            }
            scheduleSimpleS3Task(t, HttpMethod.GET, options.body)
        case None => ()
    }
}

public func executeSimpleS3DeleteRequest(
    credentials: S3Credentials,
    options: S3SimpleRequestOptions,
    callback: (S3DeleteResult, UIntNative) -> Unit,
    callbackContext: UIntNative
): Unit {
    let task = S3HttpSimpleTask(VirtualMachine.get())
    task.callbackKind = S3CallbackKind.Delete
    task.callbackContext = callbackContext
    task.deleteCallback = callback
    match (prepareSimpleS3TaskWithTask(task, credentials, options)) {
        case Some(t) =>
            if (options.method != HttpMethod.DELETE) {
                t.fail("InvalidMethod", "S3 delete requests must use DELETE.")
                t.deinit()
                return
            }
            scheduleSimpleS3Task(t, HttpMethod.DELETE, options.body)
        case None => ()
    }
}

public func executeSimpleS3UploadRequest(
    credentials: S3Credentials,
    options: S3SimpleRequestOptions,
    callback: (S3UploadResult, UIntNative) -> Unit,
    callbackContext: UIntNative
): Unit {
    let task = S3HttpSimpleTask(VirtualMachine.get())
    task.callbackKind = S3CallbackKind.Upload
    task.callbackContext = callbackContext
    task.uploadCallback = callback
    match (prepareSimpleS3TaskWithTask(task, credentials, options)) {
        case Some(t) =>
            if (options.method != HttpMethod.PUT && options.method != HttpMethod.DELETE) {
                t.fail("InvalidMethod", "S3 upload requests must use PUT or DELETE.")
                t.deinit()
                return
            }
            scheduleSimpleS3Task(t, options.method, options.body)
        case None => ()
    }
}

public func executeSimpleS3MultipartStartRequest(
    credentials: S3Credentials,
    options: S3SimpleRequestOptions,
    callback: (S3DownloadResult, UIntNative) -> Unit,
    callbackContext: UIntNative
): Unit {
    let task = S3HttpSimpleTask(VirtualMachine.get())
    task.callbackKind = S3CallbackKind.Download
    task.callbackContext = callbackContext
    task.downloadCallback = callback
    match (prepareSimpleS3TaskWithTask(task, credentials, options)) {
        case Some(t) =>
            if (options.method != HttpMethod.POST) {
                t.fail("InvalidMethod", "S3 multipart start requests must use POST.")
                t.deinit()
                return
            }
            scheduleSimpleS3Task(t, HttpMethod.POST, options.body)
        case None => ()
    }
}

public func executeSimpleS3CommitRequest(
    credentials: S3Credentials,
    options: S3SimpleRequestOptions,
    callback: (S3CommitResult, UIntNative) -> Unit,
    callbackContext: UIntNative
): Unit {
    let task = S3HttpSimpleTask(VirtualMachine.get())
    task.callbackKind = S3CallbackKind.Commit
    task.callbackContext = callbackContext
    task.commitCallback = callback
    match (prepareSimpleS3TaskWithTask(task, credentials, options)) {
        case Some(t) =>
            if (options.method != HttpMethod.POST) {
                t.fail("InvalidMethod", "S3 multipart commit requests must use POST.")
                t.deinit()
                return
            }
            scheduleSimpleS3Task(t, HttpMethod.POST, options.body)
        case None => ()
    }
}

public func executeSimpleS3PartRequest(
    credentials: S3Credentials,
    options: S3SimpleRequestOptions,
    callback: (S3PartResult, UIntNative) -> Unit,
    callbackContext: UIntNative
): Unit {
    let task = S3HttpSimpleTask(VirtualMachine.get())
    task.callbackKind = S3CallbackKind.Part
    task.callbackContext = callbackContext
    task.partCallback = callback
    match (prepareSimpleS3TaskWithTask(task, credentials, options)) {
        case Some(t) =>
            if (options.method != HttpMethod.PUT) {
                t.fail("InvalidMethod", "S3 multipart part requests must use PUT.")
                t.deinit()
                return
            }
            scheduleSimpleS3Task(t, HttpMethod.PUT, options.body)
        case None => ()
    }
}

private func prepareSimpleS3StatTask(
    credentials: S3Credentials,
    options: S3SimpleRequestOptions,
    callback: (S3StatResult, UIntNative) -> Unit,
    callbackContext: UIntNative
): ?S3HttpSimpleTask {
    let task = S3HttpSimpleTask(VirtualMachine.get())
    task.callbackKind = S3CallbackKind.Stat
    task.callbackContext = callbackContext
    task.statCallback = callback
    return prepareSimpleS3TaskWithTask(task, credentials, options)
}

private func prepareSimpleS3Task(
    credentials: S3Credentials,
    options: S3SimpleRequestOptions,
    callbackKind: S3CallbackKind,
    callbackContext: UIntNative
): ?S3HttpSimpleTask {
    let task = S3HttpSimpleTask(VirtualMachine.get())
    task.callbackKind = callbackKind
    task.callbackContext = callbackContext
    return prepareSimpleS3TaskWithTask(task, credentials, options)
}

private func prepareSimpleS3TaskWithTask(
    task: S3HttpSimpleTask,
    credentials: S3Credentials,
    options: S3SimpleRequestOptions
): ?S3HttpSimpleTask {
    var signResult: S3SignResult
    try {
        signResult = buildSimpleS3SignResult(credentials, options)
    } catch (e: Exception) {
        let signErr = getSignErrorCodeAndMessage()
        task.fail(signErr.code, signErr.message)
        task.deinit()
        return None
    }

    task.signResult = signResult
    task.headers = buildSimpleS3Headers(signResult, options)
    task.range = options.range
    task.proxyUrl = options.proxyUrl
    return Some(task)
}

private func buildSimpleS3SignResult(credentials: S3Credentials, options: S3SimpleRequestOptions): S3SignResult {
    let contentType = if (options.contentType.size > 0) { options.contentType } else { "" }
    let contentDisposition = if (options.contentDisposition.size > 0) { options.contentDisposition } else { "" }

    return S3Signing.signRequestFull(
        options.path,
        options.method,
        options.searchParams,
        contentDisposition,
        contentType,
        None,
        None,
        options.requestPayer,
        options.acl,
        options.storageClass,
        credentials
    )
}

private func buildSimpleS3Headers(signResult: S3SignResult, options: S3SimpleRequestOptions): HttpHeaders {
    var headers = signResult.toHttpHeaders()
    if (options.range.size > 0) {
        headers.set("range", options.range)
    }
    if (options.contentType.size > 0) {
        headers.set("content-type", options.contentType)
    }
    if (options.contentDisposition.size > 0) {
        headers.set("content-disposition", options.contentDisposition)
    }
    if (options.contentEncoding.size > 0) {
        headers.set("content-encoding", options.contentEncoding)
    }
    return headers
}

private func isSupportedSimpleRequestCallback(callbackKind: S3CallbackKind): Bool {
    match (callbackKind) {
        case S3CallbackKind.Stat => true
        case S3CallbackKind.Download => true
        case S3CallbackKind.Upload => true
        case S3CallbackKind.Delete => true
        case S3CallbackKind.ListObjects => true
        case S3CallbackKind.Commit => true
        case S3CallbackKind.Part => true
    }
}

private func isValidSimpleRequestMethod(callbackKind: S3CallbackKind, method: HttpMethod): Bool {
    match (callbackKind) {
        case S3CallbackKind.Stat => match (method) { case HttpMethod.HEAD => true case _ => false }
        case S3CallbackKind.Download => match (method) { case HttpMethod.GET => true case _ => false }
        case S3CallbackKind.Upload => match (method) {
            case HttpMethod.PUT => true
            case HttpMethod.POST => true
            case HttpMethod.DELETE => true
            case _ => false
        }
        case S3CallbackKind.Delete => match (method) { case HttpMethod.DELETE => true case _ => false }
        case S3CallbackKind.ListObjects => match (method) { case HttpMethod.GET => true case _ => false }
        case S3CallbackKind.Commit => match (method) { case HttpMethod.POST => true case _ => false }
        case S3CallbackKind.Part => match (method) { case HttpMethod.PUT => true case _ => false }
    }
}

private func simpleRequestInvalidMethodMessage(callbackKind: S3CallbackKind): String {
    match (callbackKind) {
        case S3CallbackKind.Stat => "S3 stat requests must use HEAD."
        case S3CallbackKind.Download => "S3 download requests must use GET."
        case S3CallbackKind.Upload => "S3 upload requests must use PUT, POST, or DELETE."
        case S3CallbackKind.Delete => "S3 delete requests must use DELETE."
        case S3CallbackKind.ListObjects => "S3 listObjects requests must use GET."
        case S3CallbackKind.Commit => "S3 multipart commit requests must use POST."
        case S3CallbackKind.Part => "S3 multipart part requests must use PUT."
    }
}

private func simpleRequestNotImplementedMessage(callbackKind: S3CallbackKind): String {
    match (callbackKind) {
        case S3CallbackKind.Stat => "S3 stat request scheduling is not implemented in this Cangjie runtime build."
        case S3CallbackKind.Download => "S3 download request scheduling is not implemented in this Cangjie runtime build."
        case S3CallbackKind.Upload => "S3 upload request scheduling is not implemented in this Cangjie runtime build."
        case S3CallbackKind.Delete => "S3 delete request scheduling is not implemented in this Cangjie runtime build."
        case S3CallbackKind.ListObjects => "S3 listObjects request scheduling is not implemented in this Cangjie runtime build."
        case S3CallbackKind.Commit => "S3 multipart commit request scheduling is not implemented in this Cangjie runtime build."
        case S3CallbackKind.Part => "S3 multipart part request scheduling is not implemented in this Cangjie runtime build."
    }
}

/// 获取签名错误码和消息
/// 对应 Bun: getSignErrorCodeAndMessage
private func getSignErrorCodeAndMessage(): S3Error {
    return S3Error("SignError", "Failed to sign the request.")
}
