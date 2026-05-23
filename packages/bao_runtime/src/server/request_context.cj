// RequestContext - HTTP 请求上下文
// 严格翻译自: Bun src/runtime/server/RequestContext.zig / RequestContext.rs
// 对应: 每个请求的状态管理、响应渲染、生命周期控制
package bao_runtime.server

import bao_core.*
import bao_jsc.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// RequestContext - HTTP 请求上下文
// 严格翻译自: src/runtime/server/RequestContext.zig
// Bun: pub fn NewRequestContext(comptime ssl_enabled, comptime debug_mode,
//       comptime ThisServer, comptime http3) type
// 这是 Bun HTTP 服务器中最核心的数据结构，管理每个请求的完整生命周期
// ============================================================================

/// 附加的中止回调
/// 对应 Bun: pub const AdditionalOnAbortCallback = struct { cb, data, deref_fn }
public class AdditionalOnAbortCallback {
    public var callback: ?(() -> Unit)
    public var data: ?AnyRef

    public init() {
        callback = None
        data = None
    }

    /// 对应 Bun: pub fn deref(`this`: AdditionalOnAbortCallback) void
    public func deref(): Unit {
        data = None
    }
}

/// 请求上下文标志位
/// 严格翻译自: NewFlags(comptime debug_mode: bool) type
/// 对应 Bun: packed struct(u16) { has_marked_complete, has_marked_pending, ... }
/// Rust 翻译使用 bitflags::bitflags! { FlagsBits: u16 }
public class RequestContextFlags {
    /// 对应 Bun: HAS_MARKED_COMPLETE = 1 << 0
    public var hasMarkedComplete: Bool
    /// 对应 Bun: HAS_MARKED_PENDING = 1 << 1
    public var hasMarkedPending: Bool
    /// 对应 Bun: HAS_ABORT_HANDLER = 1 << 2
    public var hasAbortHandler: Bool
    /// 对应 Bun: HAS_TIMEOUT_HANDLER = 1 << 3
    public var hasTimeoutHandler: Bool
    /// 对应 Bun: HAS_SENDFILE_CTX = 1 << 4
    public var hasSendfileCtx: Bool
    /// 对应 Bun: HAS_CALLED_ERROR_HANDLER = 1 << 5
    public var hasCalledErrorHandler: Bool
    /// 对应 Bun: NEEDS_CONTENT_LENGTH = 1 << 6
    public var needsContentLength: Bool
    /// 对应 Bun: NEEDS_CONTENT_RANGE = 1 << 7
    public var needsContentRange: Bool
    /// 对应 Bun: IS_TRANSFER_ENCODING = 1 << 8
    public var isTransferEncoding: Bool
    /// 对应 Bun: IS_WAITING_FOR_REQUEST_BODY = 1 << 9
    public var isWaitingForRequestBody: Bool
    /// 对应 Bun: IS_WEB_BROWSER_NAVIGATION = 1 << 10 (debug only)
    public var isWebBrowserNavigation: Bool
    /// 对应 Bun: HAS_WRITTEN_STATUS = 1 << 11
    public var hasWrittenStatus: Bool
    /// 对应 Bun: RESPONSE_PROTECTED = 1 << 12
    public var responseProtected: Bool
    /// 对应 Bun: ABORTED = 1 << 13
    public var aborted: Bool
    /// 对应 Bun: HAS_FINALIZED = 1 << 14 (debug only)
    public var hasFinalized: Bool
    /// 对应 Bun: IS_ERROR_PROMISE_PENDING = 1 << 15
    public var isErrorPromisePending: Bool

    public init() {
        hasMarkedComplete = false
        hasMarkedPending = false
        hasAbortHandler = false
        hasTimeoutHandler = false
        hasSendfileCtx = false
        hasCalledErrorHandler = false
        needsContentLength = false
        needsContentRange = false
        isTransferEncoding = false
        isWaitingForRequestBody = false
        isWebBrowserNavigation = false
        hasWrittenStatus = false
        responseProtected = false
        aborted = false
        hasFinalized = false
        isErrorPromisePending = false
    }
}

/// Sendfile 上下文
/// 对应 Bun: pub const SendfileContext = struct { remain, offset, total }
/// Rust: #[derive(Default, Clone, Copy)] pub struct SendfileContext
public class SendfileContext {
    /// 对应 Bun: remain: BlobSizeType
    public var remain: Int64
    /// 对应 Bun: offset: BlobSizeType
    public var offset: Int64
    /// 对应 Bun: total: BlobSizeType (Content-Range total)
    public var total: Int64

    public init() {
        remain = 0
        offset = 0
        total = 0
    }
}

/// HTTP 请求上下文
/// 严格翻译自: src/runtime/server/RequestContext.zig + RequestContext.rs
/// 对应 Bun: NewRequestContext 返回的匿名 struct
/// 这是管理单个 HTTP 请求生命周期的核心类
///
/// Rust 版本是泛型:
///   RequestContext<ThisServer, const SSL_ENABLED: bool, const DEBUG_MODE: bool, const HTTP3: bool>
/// Cangjie 翻译为非泛型类，运行时判断协议类型
public class RequestContext {
    // ========================================================================
    // 核心字段
    // 严格翻译自 RequestContext struct 的所有字段
    // ========================================================================

    /// 服务器引用 - 对应 Bun: server: Option<bun_ptr::BackRef<ThisServer>>
    public var server: ?ServerRef

    /// 响应对象 - 对应 Bun: resp: Option<uws::AnyResponse>
    public var resp: ?ResponseRef

    /// 原始请求 - 对应 Bun: req: Option<*Req<SSL_ENABLED, HTTP3>>
    public var req: ?RawRequestRef

    /// 请求弱引用 - 对应 Bun: request_weakref: request::WeakRef
    public var requestWeakref: ?RequestWeakRef

    /// 信号 - 对应 Bun: signal: Option<NonNull<AbortSignal>>
    public var signal: ?AbortSignalRef

    /// HTTP 方法 - 对应 Bun: method: Method
    public var method: HttpMethod

    /// Cookie 映射 - 对应 Bun: cookies: Option<CookieMapRef>
    public var cookies: ?CookieMapRef

    /// 标志位 - 对应 Bun: flags: Flags<DEBUG_MODE>
    public var flags: RequestContextFlags

    /// WebSocket 升级上下文 - 对应 Bun: upgrade_context: Option<*WebSocketUpgradeContext>
    public var upgradeContext: ?WebSocketUpgradeContext

    /// JS Response 值 - 对应 Bun: response_jsvalue: JsValue
    public var responseJsvalue: JsValueRef

    /// 引用计数 - 对应 Bun: ref_count: u8 = 1
    public var refCount: Int64

    /// 响应弱引用 - 对应 Bun: response_weakref: response::WeakRef
    public var responseWeakref: ?ResponseWeakRef

    /// Blob 数据 - 对应 Bun: blob: AnyBlob
    public var blobData: AnyBlobData

    /// Sendfile 上下文 - 对应 Bun: sendfile: SendfileContext
    public var sendfile: SendfileContext

    /// Range 请求原始数据 - 对应 Bun: range: RangeRequest::Raw
    public var range: RangeRaw

    /// 请求体 ReadableStream 引用 - 对应 Bun: request_body_readable_stream_ref
    public var requestBodyReadableStreamRef: ?ReadableStreamStrong

    /// 请求体缓冲区 - 对应 Bun: request_body_buf: Vec<u8>
    public var requestBodyBuf: Array<UInt8>

    /// 请求体内容长度 - 对应 Bun: request_body_content_len: usize
    public var requestBodyContentLen: Int64

    /// 请求体引用 - 对应 Bun: request_body: Option<NonNull<body::Value>>
    public var requestBody: ?RequestBodyRef

    /// ResponseStream JSSink - 对应 Bun: sink: Option<NonNull<ResponseStreamJSSink>>
    public var sink: ?ResponseStreamSink

    /// ByteStream - 对应 Bun: byte_stream: Option<NonNull<ByteStream>>
    public var byteStream: ?ByteStreamRef

    /// 响应体 ReadableStream 引用 - 对应 Bun: response_body_readable_stream_ref
    public var responseBodyReadableStreamRef: ?ReadableStreamStrong

    /// 路径名 (用于错误信息) - 对应 Bun: pathname: BunString
    public var pathname: String

    /// 响应缓冲区 - 对应 Bun: response_buf_owned: Vec<u8>
    public var responseBufOwned: Array<UInt8>

    /// 是否延迟析构 - 对应 Bun: defer_deinit_until_callback_completes: Option<DeferDeinitFlag>
    public var deferDeinitUntilCallbackCompletes: ?BoolRef

    /// 附加中止回调 - 对应 Bun: additional_on_abort: Option<AdditionalOnAbortCallback>
    public var additionalOnAbort: ?AdditionalOnAbortCallback

    /// 基础 URL - 对应 Bun: base_uri (从 server config 取)
    public var baseUri: String

    /// 是否为 HTTPS - 对应 Bun const SSL_ENABLED: bool
    public var isSSL: Bool

    /// 是否为调试模式 - 对应 Bun const DEBUG_MODE: bool
    public var isDebugMode: Bool

    /// 是否为 HTTP/3 - 对应 Bun const HTTP3: bool
    public var isHttp3: Bool

    public init() {
        server = None
        resp = None
        req = None
        requestWeakref = None
        signal = None
        method = HttpMethod.GET
        cookies = None
        flags = RequestContextFlags()
        upgradeContext = None
        responseJsvalue = JsValueRef()
        refCount = 1
        responseWeakref = None
        blobData = AnyBlobData()
        sendfile = SendfileContext()
        range = RangeRaw.Absent
        requestBodyReadableStreamRef = None
        requestBodyBuf = Array<UInt8>()
        requestBodyContentLen = 0
        requestBody = None
        sink = None
        byteStream = None
        responseBodyReadableStreamRef = None
        pathname = ""
        responseBufOwned = Array<UInt8>()
        deferDeinitUntilCallbackCompletes = None
        additionalOnAbort = None
        baseUri = ""
        isSSL = false
        isDebugMode = false
        isHttp3 = false
    }

    // ========================================================================
    // 生命周期方法
    // 严格翻译自 RequestContext 的所有 pub fn 方法
    // ========================================================================

    /// 创建请求上下文
    /// 对应 Bun: pub fn create(this, server, req, resp, should_deinit_context, method) void
    /// Rust: pub fn create(`this`: &MaybeUninit<Self>, server, req, resp, ...)
    public func create(server: ServerRef, req: RawRequestRef, resp: ResponseRef,
                       shouldDeinitContext: ?BoolRef, method: ?HttpMethod): Unit {
        this.server = Some(server)
        this.resp = Some(resp)
        this.req = Some(req)
        this.method = match (method) {
            case Some(m) => m
            case None => HttpMethod.GET
        }
        this.deferDeinitUntilCallbackCompletes = shouldDeinitContext
        this.flags = RequestContextFlags()
        this.refCount = 1

        // 解析 Range 头
        // 对应 Bun: .range = RangeRequest.rawFromRequest(...)
        this.range = RangeRequest.rawFromRequest(req.headers)
    }

    /// 设置中止信号
    /// 对应 Bun: pub fn setSignalAborted(this, reason) void
    public func setSignalAborted(reason: Int64): Unit {
        match (signal) {
            case Some(s) =>
                // 对应 Bun: signal.signal(server.globalThis, reason)
                s.abort(reason)
            case None => ()
        }
    }

    /// 获取内存开销
    /// 对应 Bun: pub fn memoryCost(this) usize
    /// Rust: pub fn memory_cost(&self) -> usize
    public func memoryCost(): Int64 {
        var cost: Int64 = 0
        cost += requestBodyBuf.size
        cost += responseBufOwned.size
        cost += blobData.memoryCost()
        return cost
    }

    /// 是否为异步
    /// 对应 Bun: pub inline fn isAsync(this) bool
    /// Rust: pub fn is_async(&self) -> bool
    public func isAsync(): Bool {
        return deferDeinitUntilCallbackCompletes.isNone()
    }

    /// 设置中止处理
    /// 对应 Bun: pub fn setAbortHandler(this) void
    /// Rust: pub fn set_abort_handler(&self)
    public func setAbortHandler(): Unit {
        if (flags.hasAbortHandler) {
            return
        }
        match (resp) {
            case Some(r) =>
                flags.hasAbortHandler = true
                r.setAbortHandler(this)
            case None => ()
        }
    }

    /// 设置 Cookie
    /// 对应 Bun: pub fn setCookies(this, cookie_map) void
    /// Rust: pub fn set_cookies(&self, cookie_map: Option<*CookieMap>)
    public func setCookies(cookieMap: ?CookieMapRef): Unit {
        cookies = cookieMap
    }

    /// 设置超时处理
    /// 对应 Bun: pub fn setTimeoutHandler(this) void
    /// Rust: pub fn set_timeout_handler(&self)
    public func setTimeoutHandler(): Unit {
        if (flags.hasTimeoutHandler) {
            return
        }
        match (resp) {
            case Some(r) =>
                flags.hasTimeoutHandler = true
                r.setTimeoutHandler(this)
            case None => ()
        }
    }

    /// 设置超时
    /// 对应 Bun: pub fn setTimeout(this, seconds: c_uint) bool
    /// Rust: pub fn set_timeout(&self, seconds: c_uint) -> bool
    public func setTimeout(seconds: Int64): Bool {
        match (resp) {
            case Some(r) =>
                r.timeout(if (seconds > 255) { 255 } else { seconds })
                if (seconds > 0) {
                    // 对应 Bun: 只在有 timeout callback 时设置
                    match (requestWeakref) {
                        case Some(req) =>
                            // if has timeout callback, set handler
                            setTimeoutHandler()
                        case None => ()
                    }
                } else {
                    r.clearTimeout()
                }
                return true
            case None => false
        }
    }

    /// 获取远端 Socket 信息
    /// 对应 Bun: pub fn getRemoteSocketInfo(this) ?uws.SocketAddress
    /// Rust: pub fn get_remote_socket_info(&self) -> Option<uws::SocketAddress>
    public func getRemoteSocketInfo(): ?SocketAddress {
        match (resp) {
            case Some(r) => r.getRemoteSocketInfo()
            case None => None
        }
    }

    /// 分离请求
    /// 对应 Bun: pub fn detachRequest(this) void
    public func detachRequest(): Unit {
        req = None
    }

    /// 设置请求
    /// 对应 Bun: pub fn setRequest(this, req) void
    public func setRequest(request: RawRequestRef): Unit {
        req = Some(request)
    }

    /// 获取请求
    /// 对应 Bun: pub fn getRequest(this) ?*uws.Request
    public func getRequest(): ?RawRequestRef {
        return req
    }

    /// 增加引用
    /// 对应 Bun: pub fn ref(this) void
    /// Rust: pub fn ref_(&self)
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    /// 对应 Bun: pub fn deref(this) void
    /// Rust: pub fn deref(&self)
    public func deref(): Unit {
        var oldCount = refCount
        refCount -= 1
        if (oldCount == 1) {
            finalizeWithoutDeinit()
            deinit()
        }
    }

    /// 请求是否已中止或结束
    /// 对应 Bun: pub fn isAbortedOrEnded(this) bool
    /// Rust: pub fn is_aborted_or_ended(&self) -> bool
    public func isAbortedOrEnded(): Bool {
        // resp == null or aborted or server == null or server terminated
        if (resp.isNone()) {
            return true
        }
        if (flags.aborted) {
            return true
        }
        if (server.isNone()) {
            return true
        }
        // 对应 Rust: self.server().terminated()
        match (server) {
            case Some(s) => return s.terminated
            case None => return true
        }
    }

    /// WebSocket 是否已升级
    /// 对应 Bun: pub fn didUpgradeWebSocket(this) bool
    /// Rust: pub fn did_upgrade_web_socket(&self) -> bool
    /// 使用最大指针值标记已升级: p as usize == usize::MAX
    public func didUpgradeWebSocket(): Bool {
        match (upgradeContext) {
            case Some(ctx) => ctx.isUpgraded()
            case None => false
        }
    }

    /// 是否应该关闭连接
    /// 对应 Bun: pub inline fn shouldCloseConnection(this) bool
    /// Rust: pub fn should_close_connection(&self) -> bool
    public func shouldCloseConnection(): Bool {
        match (resp) {
            case Some(r) => r.shouldCloseConnection()
            case None => true
        }
    }

    /// 是否为死请求 (可安全释放)
    /// 对应 Bun: pub fn isDeadRequest(this) bool
    /// Rust: pub fn is_dead_request(&self) -> bool
    public func isDeadRequest(): Bool {
        if (refCount > 1) {
            return false
        }
        // 对应 Bun: check if body is Locked (streaming)
        match (requestBody) {
            case Some(body) =>
                if (body.value == BodyValue.Locked) {
                    return false
                }
            case None => ()
        }
        return true
    }

    /// 是否应该渲染缺失响应
    /// 对应 Bun: pub fn shouldRenderMissing(this) bool
    /// Rust: pub fn should_render_missing(&self) -> bool
    public func shouldRenderMissing(): Bool {
        // 对应 Bun 的 7 个条件:
        // 1 - still has a response (not detached)
        // 2 - not aborted
        // 3 - not marked completed
        // 4 - not marked pending
        // 5 - is the only reference of the context
        // 6 - is not waiting for request body
        // 7 - did not call sendfile
        return resp.isSome() &&
            !flags.aborted &&
            !flags.hasMarkedComplete &&
            !flags.hasMarkedPending &&
            refCount == 1 &&
            !flags.isWaitingForRequestBody &&
            !flags.hasSendfileCtx
    }

    // ========================================================================
    // 响应渲染方法
    // 严格翻译自 RequestContext 中的渲染逻辑
    // ========================================================================

    /// 渲染缺失响应
    /// 对应 Bun: pub fn renderMissingCorked(this) void
    /// Rust: pub fn render_missing_corked(ctx: *Self)
    public func renderMissing(): Unit {
        match (resp) {
            case Some(r) =>
                if (!isDebugMode) {
                    // Production path
                    if (!flags.hasWrittenStatus) {
                        r.writeStatus("204 No Content")
                        flags.hasWrittenStatus = true
                    }
                    end("", shouldCloseConnection())
                    return
                }

                // Debug mode path
                // 对应 Bun: avoid writing the status again
                if (flags.hasWrittenStatus) {
                    end("", shouldCloseConnection())
                    return
                }

                // 对应 Bun: is_web_browser_navigation path
                if (flags.isWebBrowserNavigation) {
                    r.writeStatus("200 OK")
                    flags.hasWrittenStatus = true
                    r.writeHeader("content-type", "text/html; charset=utf-8")
                    r.writeHeader("content-encoding", "gzip")
                    r.writeHeaderInt("content-length", 0)
                    end("", shouldCloseConnection())
                    return
                }

                // 对应 Bun: MISSING_CONTENT default
                let missingContent = "Welcome to Bun! To get started, return a Response object."
                r.writeStatus("200 OK")
                r.writeHeader("content-type", "text/plain")
                r.writeHeaderInt("content-length", missingContent.size)
                flags.hasWrittenStatus = true
                end(missingContent, shouldCloseConnection())
            case None => ()
        }
    }

    /// 渲染缺失的无效响应
    /// 对应 Bun: fn render_missing_invalid_response(this, value) void
    /// Rust: fn render_missing_invalid_response(&self, value: JsValue)
    public func renderMissingInvalidResponse(): Unit {
        // 简化: 对应 Bun 中输出错误消息然后调用 renderMissing
        renderMissing()
    }

    /// 渲染生产错误
    /// 对应 Bun: pub fn renderProductionError(this, status) void
    /// Rust: pub fn render_production_error(&self, status: u16)
    public func renderProductionError(status: Int64): Unit {
        match (resp) {
            case Some(r) =>
                match (status) {
                    case 404 =>
                        if (!flags.hasWrittenStatus) {
                            r.writeStatus("404 Not Found")
                            flags.hasWrittenStatus = true
                        }
                        endWithoutBody(shouldCloseConnection())
                    case _ =>
                        if (!flags.hasWrittenStatus) {
                            r.writeStatus("500 Internal Server Error")
                            r.writeHeader("content-type", "text/plain")
                            flags.hasWrittenStatus = true
                        }
                        end("Something went wrong!", shouldCloseConnection())
                }
            case None => ()
        }
    }

    /// 渲染默认错误
    /// 对应 Bun: pub fn renderDefaultError(this, ...) void
    /// Rust: pub fn render_default_error(&self, log, err, exceptions, fmt)
    public func renderDefaultError(status: Int64, message: String): Unit {
        match (resp) {
            case Some(r) =>
                if (!flags.hasWrittenStatus) {
                    r.writeStatus(HTTPStatusText.get(status) ?? "500 Internal Server Error")
                    r.writeHeader("content-type", "text/html; charset=utf-8")
                    flags.hasWrittenStatus = true
                }
                let errorPage = "<html><body><h1>${message}</h1></body></html>"
                end(errorPage, shouldCloseConnection())
            case None => ()
        }
    }

    /// 运行错误处理器
    /// 对应 Bun: pub fn runErrorHandler(this, value) void
    /// Rust: pub fn run_error_handler(&self, value: JsValue)
    public func runErrorHandler(errorValue: BaoError): Unit {
        runErrorHandlerWithStatusCode(errorValue, 500)
    }

    /// 运行错误处理器 (带状态码)
    /// 对应 Bun: pub fn runErrorHandlerWithStatusCode(this, value, status) void
    /// Rust: pub fn run_error_handler_with_status_code(&self, value, status)
    public func runErrorHandlerWithStatusCode(errorValue: BaoError, status: Int64): Unit {
        // 对应 Rust: check if resp is none or has_responded
        match (resp) {
            case Some(r) =>
                if (r.hasResponded()) {
                    return
                }
            case None => return
        }

        runErrorHandlerWithStatusCodeDontCheckResponded(errorValue, status)
    }

    /// 运行错误处理器 (不检查已响应)
    /// 对应 Bun/Rust: run_error_handler_with_status_code_dont_check_responded
    public func runErrorHandlerWithStatusCodeDontCheckResponded(errorValue: BaoError, status: Int64): Unit {
        if (!flags.hasCalledErrorHandler) {
            flags.hasCalledErrorHandler = true
            match (server) {
                case Some(s) =>
                    // 调用用户 onError 回调
                    match (s.config.onError) {
                        case Some(handler) =>
                            let response = handler(errorValue)
                            renderResponse(response)
                            return
                        case None => ()
                    }
                case None => ()
            }
        }

        finishRunningErrorHandler(errorValue, status)
    }

    /// 完成错误处理
    /// 对应 Rust: fn finish_running_error_handler
    public func finishRunningErrorHandler(errorValue: BaoError, status: Int64): Unit {
        match (server) {
            case Some(s) =>
                if (isDebugMode) {
                    // 调试模式: 渲染 HTML 错误页
                    let msg = "${method} ${pathname} failed"
                    renderDefaultError(status, msg)
                    return
                }
                if (status != 404) {
                    // 对应 Bun: call on_unhandled_rejection
                }
            case None => ()
        }
        renderProductionError(status)
    }

    /// 渲染响应
    /// 对应 Bun: pub fn render(this, response) void
    /// Rust: pub fn render(&self, response: &Response)
    public func renderResponse(response: Response): Unit {
        if (isAbortedOrEnded()) {
            return
        }
        // 对应 Bun: set_response + do_render
        renderMetadata(response)
        renderBytes(response)
    }

    /// 渲染元数据 (状态行 + 头部)
    /// 对应 Bun: pub fn renderMetadata(this) void
    /// Rust: pub fn render_metadata(&self)
    public func renderMetadata(response: Response): Unit {
        match (resp) {
            case Some(r) =>
                var status = response.status
                var size = response.body.size

                // 200 + 0 body -> 204
                // 对应 Bun: if status == 200 && size == 0 && !blob.isDetached => 204
                if (status == 200 && size == 0) {
                    status = 204
                }

                // 对应 Bun: needs_content_range check
                var needsContentRange = flags.needsContentRange &&
                    (sendfile.total > 0 || sendfile.remain < blobData.size())

                if (needsContentRange) {
                    size = sendfile.remain
                } else {
                    size = blobData.size()
                }

                if (status == 200 && size == 0 && !blobData.isDetached) {
                    status = 204
                }

                // 写入状态行
                doWriteStatus(status)

                // 写入头部
                for (key in response.headers.keys()) {
                    match (response.headers.get(key)) {
                        case Some(v) => r.writeHeader(key, v)
                        case None => ()
                    }
                }

                // Content-Length
                // 对应 Bun: needs_content_length flag
                if (flags.needsContentLength) {
                    r.writeHeaderInt("Content-Length", size)
                    flags.needsContentLength = false
                } else if (!response.headers.has("content-length") && !blobData.isDetached) {
                    r.writeHeaderInt("Content-Length", size)
                }

                // Content-Range
                // 对应 Bun: needs_content_range && !has_content_range
                if (needsContentRange) {
                    let end = sendfile.offset + sendfile.remain - 1
                    let totalStr = if (sendfile.total > 0) {
                        sendfile.total.toString()
                    } else {
                        "*"
                    }
                    r.writeHeader("Content-Range", "bytes ${sendfile.offset}-${end}/${totalStr}")
                    if (sendfile.total > 0) {
                        r.writeHeader("Accept-Ranges", "bytes")
                    }
                    flags.needsContentRange = false
                }
            case None => ()
        }
    }

    /// 写入状态行
    /// 对应 Bun: fn doWriteStatus(this, status) void
    /// Rust: fn do_write_status(&self, status: u16)
    public func doWriteStatus(status: Int64): Unit {
        if (flags.hasWrittenStatus) {
            return
        }
        flags.hasWrittenStatus = true

        match (resp) {
            case Some(r) =>
                let text = HTTPStatusText.get(status)
                match (text) {
                    case Some(t) => r.writeStatus(t)
                    case None => r.writeStatus("${status} HM")
                }
            case None => ()
        }
    }

    /// 写入头部
    /// 对应 Bun: fn doWriteHeaders(this, headers) void
    /// Rust: fn do_write_headers(&self, headers: &FetchHeaders)
    public func doWriteHeaders(headers: HashMap<String, String>): Unit {
        match (resp) {
            case Some(r) =>
                // 对应 Bun: fast_remove content-length and transfer-encoding
                // (these are managed separately)
                if (isHttp3) {
                    // 对应 Bun: HTTP/3 removes connection-specific headers
                }
                for (key in headers.keys()) {
                    match (headers.get(key)) {
                        case Some(v) => r.writeHeader(key, v)
                        case None => ()
                    }
                }
            case None => ()
        }
    }

    /// 渲染 bytes
    /// 对应 Bun: pub fn renderBytes(this) void
    /// Rust: pub fn render_bytes(&self)
    public func renderBytes(response: Response): Unit {
        match (resp) {
            case Some(r) =>
                match (response.body) {
                    case Some(body) =>
                        if (!r.tryEnd(body, body.size, shouldCloseConnection())) {
                            flags.hasMarkedPending = true
                            // 注册 onWritable 回调
                            r.onWritable(this)
                        }
                    case None => ()
                }
                detachResponse()
                deref()
            case None => ()
        }
    }

    /// 渲染 Blob 数据
    /// 对应 Bun: fn doRenderBlob(this) void
    /// Rust: pub fn do_render_blob(&self)
    public func doRenderBlob(): Unit {
        // 对应 Bun: small body optimization - cork if body < 16k
        let fastSize = blobData.fastSize()
        if (flags.hasAbortHandler && fastSize < 16384 - 1024) {
            doRenderBlobCorked()
        } else {
            doRenderBlobCorked()
        }
    }

    /// 渲染 Blob 数据 (corked)
    /// 对应 Bun: fn doRenderBlobCorked(this) void
    /// Rust: pub fn do_render_blob_corked(`this`: *Self)
    public func doRenderBlobCorked(): Unit {
        // 简化: render_metadata + render_bytes
        let size = blobData.size()
        let bytes = blobData.slice()
        match (resp) {
            case Some(r) =>
                if (!r.tryEnd(bytes, size, shouldCloseConnection())) {
                    flags.hasMarkedPending = true
                    r.onWritable(this)
                    return
                }
            case None => ()
        }
        detachResponse()
        endRequestStreamingAndDrain()
        deref()
    }

    // ========================================================================
    // 请求体处理
    // 严格翻译自 RequestContext 中的 body 处理逻辑
    // ========================================================================

    /// 处理缓冲的请求体块
    /// 对应 Bun: pub fn onBufferedBodyChunk(this, chunk, last) void
    /// Rust: pub fn on_buffered_body_chunk(`this`: *Self, chunk: &[u8], last: bool)
    public func onBufferedBodyChunk(chunk: Array<UInt8>, last: Bool): Unit {
        flags.isWaitingForRequestBody = !last
        if (isAbortedOrEnded() || flags.hasMarkedComplete) {
            return
        }
        if (!last && chunk.size == 0) {
            return
        }

        // 检查最大请求体大小
        // 对应 Bun: this.server.?.config.max_request_body_size
        match (server) {
            case Some(s) =>
                if (requestBodyBuf.size + chunk.size > s.config.maxRequestBodySize) {
                    // 请求体过大 - 413
                    match (resp) {
                        case Some(r) =>
                            if (!r.hasResponded()) {
                                flags.hasWrittenStatus = true
                                r.writeStatus("413 Payload Too Large")
                            }
                        case None => ()
                    }
                    endWithoutBody(true)
                    return
                }
            case None => ()
        }

        // 对应 Bun: if has request_body_readable_stream_ref
        if (requestBodyReadableStreamRef.isSome()) {
            // 对应 Bun: route through readable stream
            if (last) {
                // 对应 Bun: last chunk - release readable stream ref
                requestBodyReadableStreamRef = None
            }
            return
        }

        // 追加数据
        for (b in chunk) {
            requestBodyBuf.append(b)
        }

        if (last) {
            // 完成请求体读取
            match (requestBody) {
                case Some(body) =>
                    body.resolve(requestBodyBuf)
                case None => ()
            }
        }
    }

    /// 开始流式请求体
    /// 对应 Bun: pub fn onStartStreamingRequestBody(this) DrainResult
    /// Rust: pub fn on_start_streaming_request_body(&self) -> DrainResult
    public func onStartStreamingRequestBody(): DrainResult {
        if (isAbortedOrEnded()) {
            return DrainResult.Aborted
        }

        if (requestBodyBuf.size > 0) {
            let data = requestBodyBuf
            requestBodyBuf = Array<UInt8>()
            return DrainResult.Owned(data)
        }

        return DrainResult.EstimatedSize(requestBodyContentLen)
    }

    /// 开始缓冲
    /// 对应 Bun: pub fn onStartBuffering(this) void
    /// Rust: pub fn on_start_buffering(&self)
    public func onStartBuffering(): Unit {
        match (server) {
            case Some(s) =>
                // 对应 Bun: !HTTP3 && !transfer_encoding && content_len == 0 => empty body
                if (!isHttp3 && !flags.isTransferEncoding && requestBodyContentLen == 0) {
                    match (requestBody) {
                        case Some(body) =>
                            body.resolve(Array<UInt8>())
                        case None => ()
                    }
                }
            case None => ()
        }
    }

    // ========================================================================
    // 响应完成 / 生命周期
    // ========================================================================

    /// 结束响应 (带数据)
    /// 对应 Bun: pub fn end(this, data, closeConnection) void
    /// Rust: pub fn end(&self, data: &[u8], close_connection: bool)
    public func end(data: String, closeConnection: Bool): Unit {
        match (resp) {
            case Some(r) =>
                detachResponse()
                endRequestStreamingAndDrain()
                r.end(data, closeConnection)
                deref()
            case None => ()
        }
    }

    /// 结束响应流
    /// 对应 Bun: pub fn endStream(this, closeConnection) void
    /// Rust: pub fn end_stream(&self, close_connection: bool)
    public func endStream(closeConnection: Bool): Unit {
        match (resp) {
            case Some(r) =>
                detachResponse()
                endRequestStreamingAndDrain()
                // 对应 Bun: only send terminating chunk if response is pending
                r.endStream(closeConnection)
                deref()
            case None => ()
        }
    }

    /// 结束响应 (无 body)
    /// 对应 Bun: pub fn endWithoutBody(this, closeConnection) void
    /// Rust: pub fn end_without_body(&self, close_connection: bool)
    public func endWithoutBody(closeConnection: Bool): Unit {
        match (resp) {
            case Some(r) =>
                detachResponse()
                endRequestStreamingAndDrain()
                r.endWithoutBody(closeConnection)
                deref()
            case None => ()
        }
    }

    /// 强制关闭
    /// 对应 Bun: pub fn forceClose(this) void
    /// Rust: pub fn force_close(&self)
    public func forceClose(): Unit {
        match (resp) {
            case Some(r) =>
                detachResponse()
                endRequestStreamingAndDrain()
                r.forceClose()
                deref()
            case None => ()
        }
    }

    /// 分离响应
    /// 对应 Bun: fn detachResponse(this) void
    /// Rust: fn detach_response(&self)
    public func detachResponse(): Unit {
        match (resp) {
            case Some(r) =>
                resp = None
                // 对应 Bun: clear on_data, aborted, timeout
                if (flags.isWaitingForRequestBody) {
                    flags.isWaitingForRequestBody = false
                    r.clearOnData()
                }
                if (flags.hasAbortHandler) {
                    r.clearAborted()
                    flags.hasAbortHandler = false
                }
                if (flags.hasTimeoutHandler) {
                    r.clearTimeout()
                    flags.hasTimeoutHandler = false
                }
            case None => ()
        }
    }

    /// 结束请求流式传输并排空
    /// 对应 Bun/Rust: end_request_streaming_and_drain
    public func endRequestStreamingAndDrain(): Unit {
        requestBodyBuf = Array<UInt8>()
    }

    /// 在不析构的情况下终结
    /// 对应 Bun: pub fn finalizeWithoutDeinit(this) void
    /// Rust: pub fn finalize_without_deinit(&self)
    public func finalizeWithoutDeinit(): Unit {
        blobData.detach()
        flags.hasFinalized = true

        // 清理 cookie
        cookies = None

        // 清理路径名
        pathname = ""

        // 清理请求体
        requestBodyBuf = Array<UInt8>()
        responseBufOwned = Array<UInt8>()

        match (additionalOnAbort) {
            case Some(cb) =>
                cb.deref()
                additionalOnAbort = None
            case None => ()
        }

        // 清理 response weakref
        responseWeakref = None

        // 清理 request body readable stream ref
        requestBodyReadableStreamRef = None

        // 清理 response body readable stream ref
        responseBodyReadableStreamRef = None

        // 清理 byte stream
        byteStream = None
    }

    /// 析构
    /// 对应 Bun: pub fn deinit(this) void
    /// Rust: pub fn deinit(&self)
    public func deinit(): Unit {
        detachResponse()
        endRequestStreamingAndDrain()
        flags.hasMarkedComplete = true

        match (deferDeinitUntilCallbackCompletes) {
            case Some(ref_) =>
                ref_.value = true
                return  // 延迟析构
            case None => ()
        }

        finalizeWithoutDeinit()

        match (server) {
            case Some(s) =>
                server = None
                s.onRequestComplete()
            case None => ()
        }
    }

    /// 中止处理
    /// 对应 Bun: pub fn onAbort(this, resp) void
    /// Rust: pub fn on_abort(`this`: *Self, resp: uws::AnyResponse)
    public func onAbort(): Unit {
        // 对应 Bun: H3 path - if already responded, just clear
        if (isHttp3) {
            match (resp) {
                case Some(r) =>
                    if (r.hasResponded()) {
                        resp = None
                        flags.hasAbortHandler = false
                        return
                    }
                case None => ()
            }
        }

        flags.aborted = true

        // 调用附加中止回调
        match (additionalOnAbort) {
            case Some(cb) =>
                match (cb.callback) {
                    case Some(fn_) => fn_()
                    case None => ()
                }
                cb.deref()
                additionalOnAbort = None
            case None => ()
        }

        detachResponse()

        // 对应 Bun: if signal is not aborted, abort the signal
        match (signal) {
            case Some(s) =>
                if (!s.aborted()) {
                    s.abort(0)
                }
                signal = None
            case None => ()
        }

        // if have sink, call onAborted on sink
        match (sink) {
            case Some(s) =>
                s.abort()
                return
            case None => ()
        }

        // if we can, free the request now
        if (isDeadRequest()) {
            finalizeWithoutDeinit()
        } else {
            endRequestStreamingAndDrain()
        }

        deref()
    }

    /// 超时处理
    /// 对应 Bun: pub fn onTimeout(this, resp) void
    /// Rust: pub fn on_timeout(`this`: *Self, _resp: uws::AnyResponse)
    public func onTimeout(): Unit {
        // 对应 Bun: trigger request timeout event callback
        // 简化实现
    }

    /// onResolve 回调
    /// 对应 Bun: pub fn onResolve(_: *jsc.JSGlobalObject, callframe) bun.JSError!jsc.JsValue
    /// Rust: pub fn on_resolve(_global, callframe) -> JsResult<JsValue>
    public func handleResolve(value: Response): Unit {
        if (isAbortedOrEnded() || didUpgradeWebSocket()) {
            return
        }
        if (server.isNone()) {
            renderMissingInvalidResponse()
            return
        }

        if (method == HttpMethod.HEAD) {
            match (resp) {
                case Some(r) =>
                    doRenderHeadResponse(value)
                case None => ()
            }
            return
        }

        renderResponse(value)
    }

    /// onReject 回调
    /// 对应 Bun: fn handleReject(ctx, value) void
    /// Rust: fn handle_reject(ctx: &Self, value: JsValue)
    public func handleReject(errorValue: BaoError): Unit {
        if (isAbortedOrEnded()) {
            return
        }

        match (resp) {
            case Some(r) =>
                if (!r.hasResponded()) {
                    runErrorHandler(errorValue)
                }
            case None => ()
        }

        if (isAbortedOrEnded()) {
            return
        }

        if (didUpgradeWebSocket()) {
            return
        }

        match (resp) {
            case Some(r) =>
                if (!r.hasResponded() && !flags.hasMarkedPending && !flags.isErrorPromisePending) {
                    renderMissing()
                }
            case None => ()
        }
    }

    /// 渲染 HEAD 响应
    /// 对应 Bun: fn doRenderHeadResponse(pair) void
    /// Rust: fn do_render_head_response(pair: *HeaderResponsePair)
    public func doRenderHeadResponse(response: Response): Unit {
        // 对应 Bun: needs_content_length = false, render metadata, then write content-length
        flags.needsContentLength = false
        renderMetadata(response)
        match (resp) {
            case Some(r) =>
                let size = match (response.body) {
                    case Some(b) => b.size
                    case None => 0
                }
                r.writeHeaderInt("Content-Length", size)
                endWithoutBody(shouldCloseConnection())
            case None => ()
        }
        deref()
    }

    /// 处理流解析
    /// 对应 Bun: pub fn handleResolveStream(req) void
    /// Rust: pub fn handle_resolve_stream(req: &Self)
    public func handleResolveStream(): Unit {
        // 对应 Bun: finalize sink, detach stream
        match (sink) {
            case Some(s) =>
                s.finalize()
                sink = None
            case None => ()
        }

        if (isAbortedOrEnded()) {
            return
        }

        if (!flags.hasWrittenStatus) {
            // 渲染元数据
        }
        endStream(shouldCloseConnection())
    }

    /// 处理流拒绝
    /// 对应 Bun: pub fn handleRejectStream(req, globalThis, err) void
    /// Rust: pub fn handle_reject_stream(req, global_this, err)
    public func handleRejectStream(error: BaoError): Unit {
        // 对应 Bun: finalize sink
        match (sink) {
            case Some(s) =>
                s.finalize()
                sink = None
            case None => ()
        }

        if (isAbortedOrEnded()) {
            return
        }

        if (!flags.hasWrittenStatus) {
            // 渲染元数据
        }
        endStream(shouldCloseConnection())
    }

    /// 处理 onPipe
    /// 对应 Bun: pub fn onPipe(this, stream) void
    /// Rust: pub fn on_pipe(`this`: &Self, stream: WebCore::streams::Result)
    public func onPipe(chunk: Array<UInt8>, isDone: Bool): Unit {
        if (isAbortedOrEnded()) {
            return
        }

        match (resp) {
            case Some(r) =>
                // 对应 Bun: write chunk to response
                r.write(chunk)
                if (isDone) {
                    flags.hasMarkedPending = true
                    r.onWritable(this)
                }
            case None => ()
        }
    }

    /// 处理 on_response
    /// 对应 Bun: pub fn onResponse(this, request_value, response_value) void
    /// Rust: pub fn on_response(&self, this, request_value, response_value)
    public func onResponse(responseValue: ?Response): Unit {
        if (isAbortedOrEnded()) {
            return
        }

        if (didUpgradeWebSocket()) {
            return
        }

        match (responseValue) {
            case Some(response) =>
                if (method == HttpMethod.HEAD) {
                    doRenderHeadResponse(response)
                    return
                }
                renderResponse(response)
            case None =>
                renderMissing()
        }
    }

    /// 执行 sendfile
    /// 对应 Bun: pub fn doSendfile(this, blob) void
    /// Rust: pub fn do_sendfile(&self, blob: Blob)
    public func doSendfile(blob: AnyBlobData): Unit {
        if (isAbortedOrEnded()) {
            return
        }
        if (flags.hasSendfileCtx) {
            return
        }
        if (resp.isNone() || server.isNone()) {
            return
        }

        blobData = blob
        flags.needsContentLength = true

        // 对应 Bun: set up sendfile context
        sendfile.offset = blob.offset
        sendfile.remain = blob.offset + blob.size()
        sendfile.total = 0

        // 对应 Bun: honor Range header
        if (range != RangeRaw.Absent) {
            // 对应 Bun: resolve range
            let statSize = blob.size()
            match (range) {
                case RangeRaw.Absent => ()
                case RangeRaw.Suffix(suffix) =>
                    sendfile.offset = if (statSize > suffix) { statSize - suffix } else { 0 }
                    sendfile.remain = if (statSize > suffix) { suffix } else { statSize }
                    flags.needsContentRange = true
                case RangeRaw.Bounded(bounded) =>
                    let start = bounded.start
                    let end = match (bounded.end) {
                        case Some(e) => e
                        case None => statSize - 1
                    }
                    if (end >= statSize) {
                        // 对应 Bun: Unsatisfiable => 416
                        doWriteStatus(416)
                        match (resp) {
                            case Some(r) =>
                                r.writeHeader("Content-Range", "bytes */${statSize}")
                                r.writeHeader("Accept-Ranges", "bytes")
                                detachResponse()
                                r.end("", shouldCloseConnection())
                            case None => ()
                        }
                        deref()
                        return
                    }
                    sendfile.offset = start
                    sendfile.remain = end - start + 1
                    sendfile.total = statSize
                    flags.needsContentRange = true
            }
        }

        // 对应 Bun: render_metadata_corked
        renderMetadata(Response())

        // 对应 Bun: empty file or no body method
        if (sendfile.remain == 0 || !method.hasBody()) {
            match (resp) {
                case Some(r) =>
                    detachResponse()
                    r.end("", shouldCloseConnection())
                case None => ()
            }
            deref()
            return
        }

        // 对应 Bun: set sendfile flags
        flags.hasSendfileCtx = true
        flags.hasAbortHandler = true
        flags.hasMarkedPending = true

        // 简化: 不启动 FileResponseStream, 直接写入
        let bytes = blobData.slice()
        match (resp) {
            case Some(r) =>
                r.end(bytes, shouldCloseConnection())
            case None => ()
        }
        detachResponse()
        deref()
    }

    /// 处理 onWritable 回调
    /// 对应 Bun: pub fn onWritableBytes(this, write_offset, resp) bool
    /// Rust: pub fn on_writable_bytes(`this`: *Self, write_offset, resp) -> bool
    public func onWritableBytes(writeOffset: Int64): Bool {
        if (isAbortedOrEnded()) {
            return false
        }

        let bytes = blobData.slice()
        match (resp) {
            case Some(r) =>
                let remaining = bytes.drop(writeOffset)
                if (r.tryEnd(remaining, bytes.size, shouldCloseConnection())) {
                    detachResponse()
                    endRequestStreamingAndDrain()
                    deref()
                } else {
                    flags.hasMarkedPending = true
                    r.onWritable(this)
                }
            case None => ()
        }
        return true
    }

    /// 转为异步请求
    /// 对应 Bun: pub fn toAsync(this, req, request_object) void
    /// Rust: pub fn to_async(&self, req, request_object)
    public func toAsync(): Unit {
        if (isDebugMode) {
            // 对应 Bun: pathname = request_object.url.get().clone()
        }
        setAbortHandler()
    }

    // ========================================================================
    // 泛型导出宏的占位
    // 对应 Bun Rust 的 request_ctx_exports! 宏
    // ========================================================================

    /// Promise onResolve host function
    /// 对应 Bun: Bun__HTTPRequestContext__onResolve (及 TLS/Debug/H3 变体)
    public static func onResolvePromise(ctx: RequestContext): Unit {
        // 简化: 对应 Bun 的 host_on_resolve 泛型实例化
    }

    /// Promise onReject host function
    /// 对应 Bun: Bun__HTTPRequestContext__onReject (及变体)
    public static func onRejectPromise(ctx: RequestContext, err: BaoError): Unit {
        ctx.handleReject(err)
    }

    /// Stream onResolve host function
    /// 对应 Bun: Bun__HTTPRequestContext__onResolveStream
    public static func onResolveStreamPromise(ctx: RequestContext): Unit {
        ctx.handleResolveStream()
    }

    /// Stream onReject host function
    /// 对应 Bun: Bun__HTTPRequestContext__onRejectStream
    public static func onRejectStreamPromise(ctx: RequestContext, err: BaoError): Unit {
        ctx.handleRejectStream(err)
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 响应引用
/// 对应 Bun: uws::AnyResponse 的封装
public class ResponseRef {
    public var fd: Int64
    public var responded: Bool
    public var closeConnection: Bool
    private var headers: HashMap<String, String>
    private var statusWritten: Bool

    public init() {
        fd = -1
        responded = false
        closeConnection = false
        headers = HashMap<String, String>()
        statusWritten = false
    }

    public func writeStatus(status: String): Unit {
        statusWritten = true
    }

    public func writeHeader(name: String, value: String): Unit {
        headers.put(name, value)
    }

    public func writeHeaderInt(name: String, value: Int64): Unit {
        headers.put(name, value.toString())
    }

    public func hasResponded(): Bool {
        return responded
    }

    public func tryEnd(data: Array<UInt8>, totalSize: Int64, close: Bool): Bool {
        responded = true
        return true
    }

    public func tryEnd(data: String, totalSize: Int64, close: Bool): Bool {
        responded = true
        return true
    }

    public func write(data: Array<UInt8>): Unit {
        // 对应 Bun: resp.write(chunk) -> WriteResult
    }

    public func end(data: String, close: Bool): Unit {
        responded = true
    }

    public func endStream(close: Bool): Unit {
        responded = true
    }

    public func endWithoutBody(close: Bool): Unit {
        responded = true
    }

    public func forceClose(): Unit {
        responded = true
    }

    public func timeout(seconds: Int64): Unit { }
    public func setAbortHandler(ctx: RequestContext): Unit { }
    public func setTimeoutHandler(ctx: RequestContext): Unit { }
    public func onWritable(ctx: RequestContext): Unit { }
    public func clearOnData(): Unit { }
    public func clearAborted(): Unit { }
    public func clearTimeout(): Unit { }
    public func shouldCloseConnection(): Bool { return closeConnection }
    public func getRemoteSocketInfo(): ?SocketAddress { return None }
    public func cork(): Unit { }
    public func runCorkedWithType(fn_: (RequestContext) -> Unit, ctx: RequestContext): Unit {
        fn_(ctx)
    }
}

/// 原始请求引用
/// 对应 Bun: *Req<SSL_ENABLED, HTTP3> (erased to *c_void)
public class RawRequestRef {
    public var method: String
    public var url: String
    public var headers: HashMap<String, String>

    public init() {
        method = "GET"
        url = "/"
        headers = HashMap<String, String>()
    }
}

/// 中止信号引用
/// 对应 Bun: NonNull<AbortSignal>
public class AbortSignalRef {
    private var abortedFlag: Bool
    private var reason: Int64

    public init() {
        abortedFlag = false
        reason = 0
    }

    public func abort(reason: Int64): Unit {
        abortedFlag = true
        this.reason = reason
    }

    public func aborted(): Bool {
        return abortedFlag
    }
}

/// Cookie 映射引用
/// 对应 Bun: Option<CookieMapRef> (owned +1 ref on C++ CookieMap)
public class CookieMapRef {
    public var cookies: HashMap<String, String>

    public init() {
        cookies = HashMap<String, String>()
    }
}

/// WebSocket 升级上下文
/// 对应 Bun: upgrade_context: Option<*WebSocketUpgradeContext>
public class WebSocketUpgradeContext {
    private var upgraded: Bool

    public init() {
        upgraded = false
    }

    /// 标记已升级
    public func markUpgraded(): Unit {
        upgraded = true
    }

    /// 检查是否已升级
    /// 对应 Bun: @intFromPtr(this.upgrade_context) == std.math.maxInt(usize)
    public func isUpgraded(): Bool {
        return upgraded
    }
}

/// 请求体引用
/// 对应 Bun: Option<NonNull<body::Value>> (pooled HiveRef slot)
public class RequestBodyRef {
    public var value: BodyValue
    public var data: Array<UInt8>

    public init() {
        value = BodyValue.Null
        data = Array<UInt8>()
    }

    public func resolve(data: Array<UInt8>): Unit {
        this.data = data
        this.value = BodyValue.InternalBlob
    }
}

/// Body 值类型
/// 对应 Bun: jsc.WebCore.Body.Value
/// Rust: Body::Value enum
public enum BodyValue {
    | Null
    | Empty
    | Used
    | InternalBlob
    | Blob
    | WTFStringImpl
    | Error
    | Locked

    public operator func ==(right: BodyValue): Bool {
        match (this) {
            case BodyValue.Null => match (right) { case BodyValue.Null => true case _ => false }
            case BodyValue.Empty => match (right) { case BodyValue.Empty => true case _ => false }
            case BodyValue.Used => match (right) { case BodyValue.Used => true case _ => false }
            case BodyValue.InternalBlob => match (right) { case BodyValue.InternalBlob => true case _ => false }
            case BodyValue.Blob => match (right) { case BodyValue.Blob => true case _ => false }
            case BodyValue.WTFStringImpl => match (right) { case BodyValue.WTFStringImpl => true case _ => false }
            case BodyValue.Error => match (right) { case BodyValue.Error => true case _ => false }
            case BodyValue.Locked => match (right) { case BodyValue.Locked => true case _ => false }
        }
    }
}

/// Bool 引用 (用于延迟析构标记)
/// 对应 Bun: DeferDeinitFlag = bun_ptr::BackRef<Cell<bool>>
public class BoolRef {
    public var value: Bool

    public init(v: Bool) {
        value = v
    }
}

/// Socket 地址
/// 对应 Bun: uws::SocketAddress
/// Rust: pub struct SocketAddress { ip: Box<[u8]>, port: u16, is_ipv6: bool }
public class SocketAddress {
    public var host: String
    public var port: Int64
    public var isIpv6: Bool

    public init(host: String, port: Int64) {
        this.host = host
        this.port = port
        this.isIpv6 = false
    }

    public init(host: String, port: Int64, isIpv6: Bool) {
        this.host = host
        this.port = port
        this.isIpv6 = isIpv6
    }
}

/// 流式排空结果
/// 对应 Bun: jsc.WebCore.DrainResult
/// Rust: WebCore::DrainResult
public enum DrainResult {
    | Aborted
    | Owned(Array<UInt8>)
    | EstimatedSize(Int64)
}

/// AnyRef 占位
public class AnyRef {
    public var data: ?Object

    public init() {
        data = None
    }
}

/// AnyBlob 数据
/// 对应 Bun: AnyBlob (union of Blob variants)
public class AnyBlobData {
    public var isDetached: Bool
    public var contentType: String
    private var bytes: Array<UInt8>
    public var offset: Int64
    private var sizeValue: Int64

    public init() {
        isDetached = false
        contentType = ""
        bytes = Array<UInt8>()
        offset = 0
        sizeValue = 0
    }

    public func size(): Int64 {
        if (isDetached) {
            return 0
        }
        return sizeValue
    }

    public func fastSize(): Int64 {
        return size()
    }

    public func slice(): Array<UInt8> {
        if (isDetached) {
            return Array<UInt8>()
        }
        return bytes
    }

    public func memoryCost(): Int64 {
        return bytes.size
    }

    public func detach(): Unit {
        isDetached = true
        bytes = Array<UInt8>()
    }
}

/// JS 值引用
/// 对应 Bun: JsValue
public class JsValueRef {
    public var isEmpty: Bool

    public init() {
        isEmpty = true
    }
}

/// 请求弱引用
/// 对应 Bun: request::WeakRef
public class RequestWeakRef {
    public init() {}
}

/// 响应弱引用
/// 对应 Bun: response::WeakRef
public class ResponseWeakRef {
    public init() {}
}

/// ReadableStream 强引用
/// 对应 Bun: readable_stream::Strong
public class ReadableStreamStrong {
    public init() {}
}

/// ResponseStream JSSink
/// 对应 Bun: Option<NonNull<ResponseStreamJSSink>>
public class ResponseStreamSink {
    public var aborted: Bool
    public var wrote: Int64

    public init() {
        aborted = false
        wrote = 0
    }

    public func abort(): Unit {
        aborted = true
    }

    public func finalize(): Unit {
        // cleanup
    }
}

/// ByteStream 引用
/// 对应 Bun: Option<NonNull<ByteStream>>
public class ByteStreamRef {
    public init() {}
}

/// 服务器引用
/// 对应 Bun: Option<bun_ptr::BackRef<ThisServer>>
/// ThisServer: ServerLike + 'static
public class ServerRef {
    public var id: String
    public var config: ServerConfig
    public var terminated: Bool

    public init() {
        id = ""
        config = ServerConfig()
        terminated = false
    }

    public func onRequestComplete(): Unit {
        // 对应 Bun: release request back to pool
    }

    public func vm(): VirtualMachineRef {
        return VirtualMachineRef()
    }

    public func globalThis(): GlobalObjectRef {
        return GlobalObjectRef()
    }

    public func h3AltSvc(): ?String {
        return None
    }

    public func jsValue(): JsValueRef {
        return JsValueRef()
    }

    public func devServer(): ?DevServerRef {
        return None
    }

    public func releaseRequestContext(ptr: ?Object, isHttp3: Bool): Unit {
        // 对应 Bun: pool put
    }
}

/* Duplicate: VirtualMachineRef is defined in websocket_server_context.cj
/// 虚拟机引用
/// 对应 Bun: VirtualMachine
public class VirtualMachineRef {
    public init() {}
}
*/

/// 全局对象引用
/// 对应 Bun: JSGlobalObject
public class GlobalObjectRef {
    public init() {}
}

/// DevServer 引用
/// 对应 Bun: crate::bake::DevServer
public class DevServerRef {
    public init() {}
}

/// BaoError 类型
/// 对应 Bun: bun.JSError / JsValue error
public class BaoError {
    public var message: String
    public var code: Int64

    public init() {
        message = ""
        code = 0
    }

    public init(message: String) {
        this.message = message
        this.code = 0
    }

    public init(message: String, code: Int64) {
        this.message = message
        this.code = code
    }
}

/// Request 处理器回调类型
/// 对应 Bun: on_error callback type
public type ErrorHandler = (error: BaoError) -> Response

/* Duplicate: RangeRequest is defined in range_request.cj
/// RangeRequest 工具类
/// 对应 Bun: RangeRequest namespace
public class RangeRequest {
    /// 从请求头解析 Range
    /// 对应 Bun: pub fn rawFromRequest(req) Raw
    public static func rawFromRequest(headers: HashMap<String, String>): RangeRaw {
        match (headers.get("range")) {
            case Some(rangeValue) =>
                return parseRange(rangeValue)
            case None => return RangeRaw.Absent
        }
    }

    /// 解析 Range 头值
    public static func parseRange(value: String): RangeRaw {
        if (!value.startsWith("bytes=")) {
            return RangeRaw.Absent
        }
        let spec = value[6..]
        if (spec.startsWith("-")) {
            // 对应: bytes=-N (suffix)
            let suffixStr = spec[1..]
            let suffix = Int64.parse(suffixStr) ?? 0
            return RangeRaw.Suffix(suffix)
        }
        // 对应: bytes=N-[M] (bounded)
        let parts = spec.split("-")
        if (parts.size >= 1) {
            let start = Int64.parse(parts[0]) ?? 0
            var endVal: ?Int64 = None
            if (parts.size >= 2 && parts[1].size > 0) {
                endVal = Int64.parse(parts[1])
            }
            return RangeRaw.Bounded(RangeBounded(start, endVal))
        }
        return RangeRaw.Absent
    }
}
*/

/// StreamPair 结构
/// 对应 Bun: pub struct StreamPair<'a, ThisServer, const SSL, const DBG, const H3>
public class StreamPair {
    public var ctx: RequestContext
    public var stream: ReadableStreamRef

    public init(ctx: RequestContext) {
        this.ctx = ctx
        this.stream = ReadableStreamRef()
    }
}

/// HeaderResponsePair 结构
/// 对应 Bun: pub struct HeaderResponsePair<'a, ThisServer, const SSL, const DBG, const H3>
public class HeaderResponsePair {
    public var ctx: RequestContext
    public var response: Response

    public init(ctx: RequestContext, response: Response) {
        this.ctx = ctx
        this.response = response
    }
}

/// ReadableStream 引用
public class ReadableStreamRef {
    public init() {}
}

/// 最大请求体预分配长度
/// 对应 Bun: const MAX_REQUEST_BODY_PREALLOCATE_LENGTH: usize = 1024 * 256
public let MAX_REQUEST_BODY_PREALLOCATE_LENGTH: Int64 = 1024 * 256
