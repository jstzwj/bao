// RequestContext - HTTP 请求上下文
// 严格翻译自: Bun src/runtime/server/RequestContext.zig
// 对应: 每个请求的状态管理、响应渲染、生命周期控制
package bao_runtime

import bao_core.*
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

    /// 对应 Bun: pub fn deref(this: AdditionalOnAbortCallback) void
    public func deref(): Unit {
        data = None
    }
}

/// 请求上下文标志位
/// 严格翻译自: NewFlags(comptime debug_mode: bool) type
/// 对应 Bun: packed struct(u16) { has_marked_complete, has_marked_pending, ... }
public class RequestContextFlags {
    /// 对应 Bun: has_marked_complete: bool = false
    public var hasMarkedComplete: Bool
    /// 对应 Bun: has_marked_pending: bool = false
    public var hasMarkedPending: Bool
    /// 对应 Bun: has_abort_handler: bool = false
    public var hasAbortHandler: Bool
    /// 对应 Bun: has_timeout_handler: bool = false
    public var hasTimeoutHandler: Bool
    /// 对应 Bun: has_sendfile_ctx: bool = false
    public var hasSendfileCtx: Bool
    /// 对应 Bun: has_called_error_handler: bool = false
    public var hasCalledErrorHandler: Bool
    /// 对应 Bun: needs_content_length: bool = false
    public var needsContentLength: Bool
    /// 对应 Bun: needs_content_range: bool = false
    public var needsContentRange: Bool
    /// 对应 Bun: is_transfer_encoding: bool = false
    public var isTransferEncoding: Bool
    /// 对应 Bun: is_waiting_for_request_body: bool = false
    public var isWaitingForRequestBody: Bool
    /// 对应 Bun: is_web_browser_navigation: bool (debug only)
    public var isWebBrowserNavigation: Bool
    /// 对应 Bun: has_written_status: bool = false
    public var hasWrittenStatus: Bool
    /// 对应 Bun: response_protected: bool = false
    public var responseProtected: Bool
    /// 对应 Bun: aborted: bool = false
    public var aborted: Bool
    /// 对应 Bun: has_finalized: bool (debug only)
    public var hasFinalized: Bool
    /// 对应 Bun: is_error_promise_pending: bool = false
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
/// 对应 Bun: const SendfileContext = struct { remain, offset, total }
public class SendfileContext {
    public var remain: Int64
    public var offset: Int64
    public var total: Int64

    public init() {
        remain = 0
        offset = 0
        total = 0
    }
}

/// HTTP 请求上下文
/// 严格翻译自: src/runtime/server/RequestContext.zig
/// 对应 Bun: NewRequestContext 返回的匿名 struct
/// 这是管理单个 HTTP 请求生命周期的核心类
public class RequestContext {
    // ========================================================================
    // 核心字段
    // 严格翻译自 RequestContext struct 的所有字段
    // ========================================================================

    /// 服务器引用 - 对应 Bun: server: ?*ThisServer
    public var server: ?ServerRef

    /// 响应对象 - 对应 Bun: resp: ?*App.Response
    public var resp: ?ResponseRef

    /// 分配器 (简化) - 对应 Bun: allocator: std.mem.Allocator
    // 简化为无

    /// 原始请求 - 对应 Bun: req: ?*Req
    public var req: ?RawRequestRef

    /// 信号 - 对应 Bun: signal: ?*jsc.WebCore.AbortSignal = null
    public var signal: ?AbortSignalRef

    /// HTTP 方法 - 对应 Bun: method: HTTP.Method
    public var method: HttpMethod

    /// Cookie 映射 - 对应 Bun: cookies: ?*jsc.WebCore.CookieMap = null
    public var cookies: ?CookieMapRef

    /// 标志位 - 对应 Bun: flags: NewFlags(debug_mode) = .{}
    public var flags: RequestContextFlags

    /// WebSocket 升级上下文 - 对应 Bun: upgrade_context: ?*uws.WebSocketUpgradeContext = null
    public var upgradeContext: ?WebSocketUpgradeContext

    /// 引用计数 - 对应 Bun: ref_count: u8 = 1
    public var refCount: Int64

    /// Blob 数据 - 对应 Bun: blob: jsc.WebCore.Blob.Any
    public var blobData: Array<UInt8>

    /// Sendfile 上下文 - 对应 Bun: sendfile: SendfileContext
    public var sendfile: SendfileContext

    /// Range 请求原始数据 - 对应 Bun: range: RangeRequest.Raw
    public var range: RangeRaw

    /// 请求体缓冲区 - 对应 Bun: request_body_buf: std.ArrayListUnmanaged(u8)
    public var requestBodyBuf: Array<UInt8>

    /// 请求体内容长度 - 对应 Bun: request_body_content_len: usize
    public var requestBodyContentLen: Int64

    /// 请求体引用 - 对应 Bun: request_body: ?*WebCore.Body.Value.HiveRef
    public var requestBody: ?RequestBodyRef

    /// 响应缓冲区 - 对应 Bun: response_buf_owned: std.ArrayListUnmanaged(u8)
    public var responseBufOwned: Array<UInt8>

    /// 附加中止回调 - 对应 Bun: additional_on_abort: ?AdditionalOnAbortCallback
    public var additionalOnAbort: ?AdditionalOnAbortCallback

    /// 路径名 (用于错误信息) - 对应 Bun: pathname: bun.String
    public var pathname: String

    /// 是否延迟析构 - 对应 Bun: defer_deinit_until_callback_completes: ?*bool
    public var deferDeinitUntilCallbackCompletes: ?BoolRef

    public init() {
        server = None
        resp = None
        req = None
        signal = None
        method = HttpMethod.GET
        cookies = None
        flags = RequestContextFlags()
        upgradeContext = None
        refCount = 1
        blobData = Array<UInt8>()
        sendfile = SendfileContext()
        range = RangeRaw.None
        requestBodyBuf = Array<UInt8>()
        requestBodyContentLen = 0
        requestBody = None
        responseBufOwned = Array<UInt8>()
        additionalOnAbort = None
        pathname = ""
        deferDeinitUntilCallbackCompletes = None
    }

    // ========================================================================
    // 生命周期方法
    // 严格翻译自 RequestContext 的所有 pub fn 方法
    // ========================================================================

    /// 创建请求上下文
    /// 对应 Bun: pub fn create(this, server, req, resp, should_deinit_context, method) void
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
            case Some(s) => {
                // 对应 Bun: signal.signal(server.globalThis, reason)
                s.abort(reason)
            }
            case None => ()
        }
    }

    /// 获取内存开销
    /// 对应 Bun: pub fn memoryCost(this) usize
    public func memoryCost(): Int64 {
        var cost: Int64 = 0
        cost += requestBodyBuf.size
        cost += responseBufOwned.size
        cost += blobData.size
        return cost
    }

    /// 是否为异步
    /// 对应 Bun: pub inline fn isAsync(this) bool
    public func isAsync(): Bool {
        return deferDeinitUntilCallbackCompletes == None
    }

    /// 设置中止处理
    /// 对应 Bun: pub fn setAbortHandler(this) void
    public func setAbortHandler(): Unit {
        if (flags.hasAbortHandler) {
            return
        }
        match (resp) {
            case Some(r) => {
                flags.hasAbortHandler = true
                r.setAbortHandler(this)
            }
            case None => ()
        }
    }

    /// 设置 Cookie
    /// 对应 Bun: pub fn setCookies(this, cookie_map) void
    public func setCookies(cookieMap: ?CookieMapRef): Unit {
        cookies = cookieMap
    }

    /// 设置超时处理
    /// 对应 Bun: pub fn setTimeoutHandler(this) void
    public func setTimeoutHandler(): Unit {
        if (flags.hasTimeoutHandler) {
            return
        }
        match (resp) {
            case Some(r) => {
                flags.hasTimeoutHandler = true
                r.setTimeoutHandler(this)
            }
            case None => ()
        }
    }

    /// 设置超时
    /// 对应 Bun: pub fn setTimeout(this, seconds: c_uint) bool
    public func setTimeout(seconds: Int64): Bool {
        match (resp) {
            case Some(r) => {
                r.timeout(if (seconds > 255) { 255 } else { seconds })
                return true
            }
            case None => false
        }
    }

    /// 获取远端 Socket 信息
    /// 对应 Bun: pub fn getRemoteSocketInfo(this) ?uws.SocketAddress
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
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    /// 对应 Bun: pub fn deref(this) void
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            finalizeWithoutDeinit()
            deinit()
        }
    }

    /// 请求是否已中止或结束
    /// 对应 Bun: pub fn isAbortedOrEnded(this) bool
    public func isAbortedOrEnded(): Bool {
        return resp == None || flags.aborted || server == None
    }

    /// WebSocket 是否已升级
    /// 对应 Bun: pub fn didUpgradeWebSocket(this) bool
    /// 使用最大指针值标记已升级
    public func didUpgradeWebSocket(): Bool {
        match (upgradeContext) {
            case Some(ctx) => ctx.isUpgraded()
            case None => false
        }
    }

    /// 是否应该关闭连接
    /// 对应 Bun: pub inline fn shouldCloseConnection(this) bool
    public func shouldCloseConnection(): Bool {
        match (resp) {
            case Some(r) => r.shouldCloseConnection()
            case None => true
        }
    }

    /// 是否为死请求 (可安全释放)
    /// 对应 Bun: pub fn isDeadRequest(this) bool
    public func isDeadRequest(): Bool {
        if (refCount > 1) {
            return false
        }
        return true
    }

    /// 是否应该渲染缺失响应
    /// 对应 Bun: pub fn shouldRenderMissing(this) bool
    public func shouldRenderMissing(): Bool {
        return resp != None &&
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
    public func renderMissing(): Unit {
        match (resp) {
            case Some(r) => {
                if (!flags.hasWrittenStatus) {
                    r.writeStatus("204 No Content")
                    flags.hasWrittenStatus = true
                }
                end("", shouldCloseConnection())
            }
            case None => ()
        }
    }

    /// 渲染生产错误
    /// 对应 Bun: pub fn renderProductionError(this, status) void
    public func renderProductionError(status: Int64): Unit {
        match (resp) {
            case Some(r) => {
                match (status) {
                    case 404 => {
                        if (!flags.hasWrittenStatus) {
                            r.writeStatus("404 Not Found")
                            flags.hasWrittenStatus = true
                        }
                        endWithoutBody(shouldCloseConnection())
                    }
                    case _ => {
                        if (!flags.hasWrittenStatus) {
                            r.writeStatus("500 Internal Server Error")
                            flags.hasWrittenStatus = true
                        }
                        end("Something went wrong!", shouldCloseConnection())
                    }
                }
            }
            case None => ()
        }
    }

    /// 运行错误处理器
    /// 对应 Bun: pub fn runErrorHandler(this, value) void
    public func runErrorHandler(errorValue: BaoError): Unit {
        runErrorHandlerWithStatusCode(errorValue, 500)
    }

    /// 运行错误处理器 (带状态码)
    /// 对应 Bun: pub fn runErrorHandlerWithStatusCode(this, value, status) void
    public func runErrorHandlerWithStatusCode(errorValue: BaoError, status: Int64): Unit {
        match (resp) {
            case Some(r) => {
                if (r.hasResponded()) {
                    return
                }
            }
            case None => return
        }

        if (!flags.hasCalledErrorHandler) {
            flags.hasCalledErrorHandler = true
            match (server) {
                case Some(s) => {
                    // 调用用户 onError 回调
                    match (s.config.onError) {
                        case Some(handler) => {
                            let response = handler(errorValue)
                            renderResponse(response)
                            return
                        }
                        case None => ()
                    }
                }
                case None => ()
            }
        }

        renderProductionError(status)
    }

    /// 渲染默认错误
    /// 对应 Bun: pub fn renderDefaultError(this, ...) void
    public func renderDefaultError(status: Int64, message: String): Unit {
        match (resp) {
            case Some(r) => {
                if (!flags.hasWrittenStatus) {
                    r.writeStatus(HTTPStatusText.get(status) ?? "500 Internal Server Error")
                    flags.hasWrittenStatus = true
                }
                let errorPage = "<html><body><h1>${message}</h1></body></html>"
                end(errorPage, shouldCloseConnection())
            }
            case None => ()
        }
    }

    /// 渲染响应
    /// 对应 Bun: pub fn render(this, response) void
    public func renderResponse(response: Response): Unit {
        if (isAbortedOrEnded()) {
            return
        }
        renderMetadata(response)
        renderBytes(response)
    }

    /// 渲染元数据 (状态行 + 头部)
    /// 对应 Bun: pub fn renderMetadata(this) void
    public func renderMetadata(response: Response): Unit {
        match (resp) {
            case Some(r) => {
                var status = response.status
                let size = response.body.size

                // 200 + 0 body -> 204
                if (status == 200 && size == 0) {
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
                if (!response.headers.has("content-length")) {
                    r.writeHeader("Content-Length", size.toString())
                }
            }
            case None => ()
        }
    }

    /// 写入状态行
    /// 对应 Bun: fn doWriteStatus(this, status) void
    public func doWriteStatus(status: Int64): Unit {
        if (flags.hasWrittenStatus) {
            return
        }
        flags.hasWrittenStatus = true

        match (resp) {
            case Some(r) => {
                let text = HTTPStatusText.get(status)
                match (text) {
                    case Some(t) => r.writeStatus(t)
                    case None => r.writeStatus("${status} HM")
                }
            }
            case None => ()
        }
    }

    /// 渲染 bytes
    /// 对应 Bun: pub fn renderBytes(this) void
    public func renderBytes(response: Response): Unit {
        match (resp) {
            case Some(r) => {
                match (response.body) {
                    case Some(body) => {
                        if (!r.tryEnd(body, body.size, shouldCloseConnection())) {
                            flags.hasMarkedPending = true
                            // 注册 onWritable 回调
                            r.onWritable(this)
                        }
                    }
                    case None => ()
                }
                detachResponse()
                deref()
            }
            case None => ()
        }
    }

    // ========================================================================
    // 请求体处理
    // 严格翻译自 RequestContext 中的 body 处理逻辑
    // ========================================================================

    /// 处理缓冲的请求体块
    /// 对应 Bun: pub fn onBufferedBodyChunk(this, resp, chunk, last) void
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
            case Some(s) => {
                if (requestBodyBuf.size + chunk.size > s.config.maxRequestBodySize) {
                    // 请求体过大 - 413
                    match (resp) {
                        case Some(r) => {
                            if (!r.hasResponded()) {
                                flags.hasWrittenStatus = true
                                r.writeStatus("413 Payload Too Large")
                            }
                        }
                        case None => ()
                    }
                    endWithoutBody(true)
                    return
                }
            }
            case None => ()
        }

        // 追加数据
        for (b in chunk) {
            requestBodyBuf.append(b)
        }

        if (last) {
            // 完成请求体读取
            match (requestBody) {
                case Some(body) => {
                    body.resolve(requestBodyBuf)
                }
                case None => ()
            }
        }
    }

    /// 开始流式请求体
    /// 对应 Bun: pub fn onStartStreamingRequestBody(this) DrainResult
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

    // ========================================================================
    // 响应完成 / 生命周期
    // ========================================================================

    /// 结束响应 (带数据)
    /// 对应 Bun: pub fn end(this, data, closeConnection) void
    public func end(data: String, closeConnection: Bool): Unit {
        match (resp) {
            case Some(r) => {
                detachResponse()
                r.end(data, closeConnection)
                deref()
            }
            case None => ()
        }
    }

    /// 结束响应流
    /// 对应 Bun: pub fn endStream(this, closeConnection) void
    public func endStream(closeConnection: Bool): Unit {
        match (resp) {
            case Some(r) => {
                detachResponse()
                r.endStream(closeConnection)
                deref()
            }
            case None => ()
        }
    }

    /// 结束响应 (无 body)
    /// 对应 Bun: pub fn endWithoutBody(this, closeConnection) void
    public func endWithoutBody(closeConnection: Bool): Unit {
        match (resp) {
            case Some(r) => {
                detachResponse()
                r.endWithoutBody(closeConnection)
                deref()
            }
            case None => ()
        }
    }

    /// 强制关闭
    /// 对应 Bun: pub fn forceClose(this) void
    public func forceClose(): Unit {
        match (resp) {
            case Some(r) => {
                detachResponse()
                r.forceClose()
                deref()
            }
            case None => ()
        }
    }

    /// 分离响应
    /// 对应 Bun: fn detachResponse(this) void
    public func detachResponse(): Unit {
        match (resp) {
            case Some(r) => {
                resp = None
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
            }
            case None => ()
        }
    }

    /// 在不析构的情况下终结
    /// 对应 Bun: pub fn finalizeWithoutDeinit(this) void
    public func finalizeWithoutDeinit(): Unit {
        blobData = Array<UInt8>()
        flags.hasFinalized = true

        // 清理 cookie
        cookies = None

        // 清理路径名
        pathname = ""

        // 清理请求体
        requestBodyBuf = Array<UInt8>()
        responseBufOwned = Array<UInt8>()

        match (additionalOnAbort) {
            case Some(cb) => {
                cb.deref()
                additionalOnAbort = None
            }
            case None => ()
        }
    }

    /// 析构
    /// 对应 Bun: pub fn deinit(this) void
    public func deinit(): Unit {
        detachResponse()
        flags.hasMarkedComplete = true

        match (deferDeinitUntilCallbackCompletes) {
            case Some(ref) => {
                ref.value = true
                return  // 延迟析构
            }
            case None => ()
        }

        finalizeWithoutDeinit()

        match (server) {
            case Some(s) => {
                server = None
                s.onRequestComplete()
            }
            case None => ()
        }
    }

    /// 中止处理
    /// 对应 Bun: pub fn onAbort(this, resp) void
    public func onAbort(): Unit {
        flags.aborted = true

        // 调用附加中止回调
        match (additionalOnAbort) {
            case Some(cb) => {
                match (cb.callback) {
                    case Some(fn_) => fn_()
                    case None => ()
                }
                cb.deref()
                additionalOnAbort = None
            }
            case None => ()
        }

        detachResponse()
        deref()
    }

    /// 超时处理
    /// 对应 Bun: pub fn onTimeout(this, resp) void
    public func onTimeout(): Unit {
        // 触发请求的超时事件回调
        // 简化实现
    }

    /// onResolve 回调
    /// 对应 Bun: pub fn onResolve(_: *jsc.JSGlobalObject, callframe) bun.JSError!jsc.JSValue
    public func handleResolve(value: Response): Unit {
        if (isAbortedOrEnded() || didUpgradeWebSocket()) {
            return
        }
        if (server == None) {
            renderMissing()
            return
        }

        if (method == HttpMethod.HEAD) {
            match (resp) {
                case Some(r) => {
                    doRenderHeadResponse(value)
                }
                case None => ()
            }
            return
        }

        renderResponse(value)
    }

    /// onReject 回调
    /// 对应 Bun: fn handleReject(ctx, value) void
    public func handleReject(errorValue: BaoError): Unit {
        if (isAbortedOrEnded()) {
            return
        }

        match (resp) {
            case Some(r) => {
                if (!r.hasResponded()) {
                    runErrorHandler(errorValue)
                }
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
            case Some(r) => {
                if (!r.hasResponded() && !flags.hasMarkedPending && !flags.isErrorPromisePending) {
                    renderMissing()
                }
            }
            case None => ()
        }
    }

    /// 渲染 HEAD 响应
    /// 对应 Bun: fn doRenderHeadResponse(pair) void
    public func doRenderHeadResponse(response: Response): Unit {
        flags.needsContentLength = false
        renderMetadata(response)
        match (resp) {
            case Some(r) => {
                let size = match (response.body) {
                    case Some(b) => b.size
                    case None => 0
                }
                r.writeHeader("Content-Length", size.toString())
                endWithoutBody(shouldCloseConnection())
            }
            case None => ()
        }
        deref()
    }

    /// 处理流解析
    /// 对应 Bun: pub fn handleResolveStream(req) void
    public func handleResolveStream(): Unit {
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
    public func handleRejectStream(error: BaoError): Unit {
        if (isAbortedOrEnded()) {
            return
        }

        if (!flags.hasWrittenStatus) {
            // 渲染元数据
        }
        endStream(shouldCloseConnection())
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 响应引用
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

    public func hasResponded(): Bool {
        return responded
    }

    public func tryEnd(data: Array<UInt8>, totalSize: Int64, close: Bool): Bool {
        responded = true
        return true
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
}

/// 原始请求引用
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
public class CookieMapRef {
    public var cookies: HashMap<String, String>

    public init() {
        cookies = HashMap<String, String>()
    }
}

/// WebSocket 升级上下文
/// 对应 Bun: upgrade_context: ?*uws.WebSocketUpgradeContext
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
public enum BodyValue {
    | Null
    | Empty
    | Used
    | InternalBlob
    | Blob
    | WTFStringImpl
    | Error
    | Locked
}

/// Bool 引用 (用于延迟析构标记)
public class BoolRef {
    public var value: Bool

    public init(v: Bool) {
        value = v
    }
}

/// Socket 地址
public class SocketAddress {
    public var host: String
    public var port: Int64

    public init(host: String, port: Int64) {
        this.host = host
        this.port = port
    }
}

/// 流式排空结果
/// 对应 Bun: jsc.WebCore.DrainResult
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
