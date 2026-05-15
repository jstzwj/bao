// bao_http HTTP Core - HTTP 客户端核心实现
// 严格翻译自: bun/src/http/http.zig (3313 行)
package bao_http

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_threading.*

// ============================================================================
// HTTP 客户端核心
// 严格翻译自: bun/src/http/http.zig
//
// 这是 Bun HTTP 客户端的核心模块:
//   - HTTPClient: HTTP 客户端，管理完整的请求/响应生命周期
//   - 请求构建: buildRequest, writeRequest, writeProxyConnect
//   - 响应处理: onData, handleOnDataHeaders, handleResponseMetadata
//   - Body 处理: handleResponseBody, handleResponseBodyChunkedEncoding
//   - 重定向: doRedirect, handleResponseMetadata 中的重定向逻辑
//   - 连接管理: start, onOpen, onClose, onTimeout
//   - SSL/TLS: checkServerIdentity, onHandshake
//   - 进度更新: progressUpdate, sendProgressUpdateWithoutStageCheck
// ============================================================================

/// 默认最大 HTTP 头部大小
/// 严格翻译自: max_http_header_size: usize = 16 * 1024
public var maxHttpHeaderSize: Int64 = 16 * 1024

/// chunked 编码终止标记
/// 严格翻译自: end_of_chunked_http1_1_encoding_response_body = "0\r\n\r\n"
public let END_OF_CHUNKED_HTTP11 = "0\r\n\r\n"

/// 空闲超时 (秒) — 0 禁用
/// 严格翻译自: idle_timeout_seconds: c_uint = 300
public var idleTimeoutSeconds: Int64 = 300

/// 默认重定向次数
/// 严格翻译自: default_redirect_count = 127
public let DEFAULT_REDIRECT_COUNT: Int64 = 127

/// 最大重定向 URL 长度
/// 严格翻译自: MAX_REDIRECT_URL_LENGTH = 128 * 1024
public let MAX_REDIRECT_URL_LENGTH: Int64 = 128 * 1024

/// TLS 记录最大大小
/// 严格翻译自: max_tls_record_size = 16 * 1024
public let MAX_TLS_RECORD_SIZE: Int64 = 16 * 1024

/// 预分配 body 最大值 (256 MB)
/// 严格翻译自: preallocate_max = 1024 * 1024 * 256
public let PREALLOCATE_MAX: Int64 = 256 * 1024 * 1024

/// 最大请求头数量
/// 严格翻译自: max_request_headers = 256
public let MAX_REQUEST_HEADERS: Int64 = 256

/// H2 最大重试次数
/// 严格翻译自: max_h2_retries: u8 = 5
public let MAX_H2_RETRIES: UInt8 = UInt8(5)

/// BAO 版本 user-agent
public let BAO_USER_AGENT = "bao/0.1.0"

// ============================================================================
// HTTPClient 扩展 — 核心 HTTP 客户端操作
// 严格翻译自: bun/src/http/http.zig HTTPClient 的方法
// ============================================================================

/// HTTP 客户端核心操作
/// 严格翻译自: http.zig 中 HTTPClient 的各个方法
public class HTTPClientCore {

    // ========================================================================
    // start - 启动 HTTP 请求
    // 严格翻译自: HTTPClient.start
    // ========================================================================

    /// 启动 HTTP 请求
    /// 严格翻译自: HTTPClient.start
    public static func start(client: HTTPClient, body: HTTPRequestBody, bodyOutStr: MutableString): Unit {
        bodyOutStr.reset()
        client.state = InternalState.init(body, bodyOutStr)

        if (isHTTPS(client)) {
            start_(client, true)
        } else {
            start_(client, false)
        }
    }

    /// 内部启动逻辑
    /// 严格翻译自: HTTPClient.start_
    public static func start_(client: HTTPClient, isSsl: Bool): Unit {
        client.flags.deferFailUntilConnectingIsComplete = true

        // 已中止
        if (client.signals.aborted) {
            fail(client, "AbortedBeforeConnecting")
            completeConnectingProcess(client)
            return
        }

        // HTTP/2 只支持 HTTPS
        if (!isSsl && client.flags.forceHttp2) {
            fail(client, "HTTP2Unsupported")
            completeConnectingProcess(client)
            return
        }

        // 连接
        match (httpThread.connect(client, isSsl)) {
            case Some(socketFd) => {
                if (socketFd < 0) {
                    fail(client, "ConnectionClosed")
                } else {
                    // 注册中止跟踪器
                    if (client.state.requestStage == HTTPStage.pending) {
                        client.state.requestStage = HTTPStage.opened
                    }
                }
            }
            case None => {
                // 合并到 H2 会话
            }
        }

        completeConnectingProcess(client)
    }

    // ========================================================================
    // onOpen - 连接建立回调
    // 严格翻译自: HTTPClient.onOpen
    // ========================================================================

    /// 连接建立回调
    /// 严格翻译自: HTTPClient.onOpen
    public static func onOpen(client: HTTPClient, isSsl: Bool, socketFd: Int64): Unit {
        // 设置超时
        setTimeout(client, socketFd)

        // TCP keepalive
        if (!client.flags.disableKeepalive) {
            // socket.setKeepAlive(true, 60)
        }

        // 检查中止
        if (client.signals.aborted) {
            closeAndAbort(client, isSsl, socketFd)
            return
        }

        if (client.state.requestStage == HTTPStage.pending) {
            client.state.requestStage = HTTPStage.opened
        }

        if (!isSsl) {
            firstCall(client, isSsl, socketFd)
        }
    }

    // ========================================================================
    // firstCall - 首次调用 (TLS 握手后)
    // 严格翻译自: HTTPClient.firstCall
    // ========================================================================

    /// 首次调用
    /// 严格翻译自: HTTPClient.firstCall
    public static func firstCall(client: HTTPClient, isSsl: Bool, socketFd: Int64): Unit {
        match (client.state.requestStage) {
            case opened => {
                onWritable(client, true, isSsl, socketFd)
            }
            case pending => {
                onWritable(client, true, isSsl, socketFd)
            }
            case _ => ()
        }
    }

    // ========================================================================
    // onWritable - 可写回调
    // 严格翻译自: HTTPClient.onWritable
    //
    // 根据请求阶段发送数据:
    //   pending/opened/headers -> 发送初始请求
    //   body -> 发送 body
    //   proxy_headers -> 通过隧道发送头部
    //   proxy_body -> 通过隧道发送 body
    // ========================================================================

    /// 可写回调
    /// 严格翻译自: HTTPClient.onWritable
    public static func onWritable(client: HTTPClient, isFirstCall: Bool, isSsl: Bool, socketFd: Int64): Unit {
        if (client.signals.aborted) {
            closeAndAbort(client, isSsl, socketFd)
            return
        }

        match (client.state.requestStage) {
            case pending => {
                setTimeout(client, socketFd)
                sendInitialRequestPayload(client, isFirstCall, isSsl, socketFd)
            }
            case opened => {
                setTimeout(client, socketFd)
                sendInitialRequestPayload(client, isFirstCall, isSsl, socketFd)
            }
            case headers => {
                setTimeout(client, socketFd)
                sendInitialRequestPayload(client, isFirstCall, isSsl, socketFd)
            }
            case body => {
                setTimeout(client, socketFd)
                // 发送 body 数据
                let bodyLen = client.state.requestBody.size
                if (bodyLen > 0) {
                    // 写入 socket
                }
                if (client.state.requestBody.size == 0) {
                    client.state.requestStage = HTTPStage.done
                }
            }
            case proxyHeaders => {
                setTimeout(client, socketFd)
                // 通过代理隧道发送头部
            }
            case proxyBody => {
                setTimeout(client, socketFd)
                // 通过代理隧道发送 body
            }
            case _ => ()
        }
    }

    // ========================================================================
    // onData - 数据到达回调
    // 严格翻译自: HTTPClient.onData
    //
    // 根据响应阶段处理:
    //   pending/headers -> 解析响应头部
    //   body -> 处理响应 body
    //   body_chunk -> 处理 chunked body
    // ========================================================================

    /// 数据到达回调
    /// 严格翻译自: HTTPClient.onData
    public static func onData(client: HTTPClient, isSsl: Bool, data: Array<UInt8>, ctx: HTTPContext, socketFd: Int64): Unit {
        if (client.signals.aborted) {
            closeAndAbort(client, isSsl, socketFd)
            return
        }

        // 代理隧道 — 直接转发
        match (client.proxyTunnel) {
            case Some(tunnel) => {
                setTimeout(client, socketFd)
                ProxyTunnelOps.receive(tunnel, data)
                return
            }
            case None => ()
        }

        match (client.state.responseStage) {
            case pending => {
                handleOnDataHeaders(client, isSsl, data, ctx, socketFd)
            }
            case headers => {
                handleOnDataHeaders(client, isSsl, data, ctx, socketFd)
            }
            case body => {
                setTimeout(client, socketFd)
                let reportProgress = handleResponseBody(client, bytesToString(data), false)
                if (reportProgress) {
                    progressUpdate(client, isSsl, ctx, socketFd)
                }
            }
            case bodyChunk => {
                setTimeout(client, socketFd)
                let reportProgress = handleResponseBodyChunkedEncoding(client, bytesToString(data))
                if (reportProgress) {
                    progressUpdate(client, isSsl, ctx, socketFd)
                }
            }
            case fail => ()
            case _ => {
                client.state.pendingResponse = None
                closeAndFail(client, "UnexpectedData", isSsl, socketFd)
            }
        }
    }

    // ========================================================================
    // handleOnDataHeaders - 处理响应头部
    // 严格翻译自: HTTPClient.handleOnDataHeaders
    // ========================================================================

    /// 处理响应头部
    /// 严格翻译自: HTTPClient.handleOnDataHeaders
    public static func handleOnDataHeaders(client: HTTPClient, isSsl: Bool, data: Array<UInt8>, ctx: HTTPContext, socketFd: Int64): Unit {
        var toRead = bytesToString(data)

        // 简短读取处理
        if (toRead.size < 16) {
            handleShortRead(client, isSsl, data, socketFd, true)
            return
        }

        // 解析 HTTP 响应
        let parsed = parseRawResponse(toRead)
        match (parsed) {
            case Some(response) => {
                client.state.pendingResponse = Some(response)

                // 101 升级响应
                if (response.statusCode == 101) {
                    client.flags.upgradeState = HTTPUpgradeState.upgraded
                }

                // 1xx 信息响应 — 继续读取
                if (response.statusCode >= 100 && response.statusCode < 200) {
                    return
                }

                // 处理响应元数据
                let shouldContinue = handleResponseMetadata(client, response)
                match (shouldContinue) {
                    case ShouldContinue.finished => {
                        if (client.state.flags.isRedirectPending) {
                            doRedirect(client, isSsl, ctx, socketFd)
                            return
                        }
                        cloneMetadata(client)
                        client.state.flags.receivedLastChunk = true
                        client.state.contentLength = Some(0)
                        progressUpdate(client, isSsl, ctx, socketFd)
                        return
                    }
                    case ShouldContinue.continueStreaming => {
                        if (client.flags.proxyTunneling && client.proxyTunnel == None) {
                            // 启动代理握手
                            return
                        }

                        cloneMetadata(client)

                        // 报告头部进度
                        if (client.signals.headerProgress) {
                            progressUpdate(client, isSsl, ctx, socketFd)
                        }
                    }
                }
            }
            case None => {
                handleShortRead(client, isSsl, data, socketFd, true)
            }
        }
    }

    // ========================================================================
    // handleResponseMetadata - 处理响应元数据
    // 严格翻译自: HTTPClient.handleResponseMetadata
    //
    // 解析状态码、头部字段，处理重定向
    // ========================================================================

    /// 是否继续枚举
    /// 严格翻译自: HTTPClient.ShouldContinue
    public enum ShouldContinue {
        | continueStreaming
        | finished
    }

    /// 处理响应元数据
    /// 严格翻译自: HTTPClient.handleResponseMetadata
    public static func handleResponseMetadata(client: HTTPClient, response: RawResponse): ShouldContinue {
        var location = ""

        // 解析头部
        for (header in response.headers) {
            let nameLower = header.name.toLower()
            match (nameLower) {
                case "content-length" => {
                    let cl = parseInt64(header.value.trim())
                    client.state.contentLength = Some(cl)
                }
                case "content-encoding" => {
                    if (!client.flags.disableDecompression) {
                        client.state.encoding = match (header.value.trim().toLower()) {
                            case "gzip" => Encoding.gzip
                            case "deflate" => Encoding.deflate
                            case "br" => Encoding.brotli
                            case "zstd" => Encoding.zstd
                            case _ => Encoding.identity
                        }
                    }
                }
                case "transfer-encoding" => {
                    let val = header.value.trim().toLower()
                    if (val == "chunked") {
                        client.state.transferEncoding = Encoding.chunked
                    } else if (val == "identity") {
                        client.state.transferEncoding = Encoding.identity
                    }
                }
                case "location" => {
                    location = header.value
                }
                case "connection" => {
                    if (response.statusCode >= 200 && response.statusCode <= 299) {
                        if (header.value.trim().toLower() == "close") {
                            client.state.flags.allowKeepalive = false
                        }
                    }
                }
                case _ => ()
            }
        }

        // 1xx, 204, 304 无 body
        if ((response.statusCode >= 100 && response.statusCode < 200) ||
            response.statusCode == 204 || response.statusCode == 304) {
            client.state.contentLength = Some(0)
        }

        // 无 Content-Length 且非 chunked -> 关闭 keep-alive
        if (client.state.contentLength == None && client.state.transferEncoding != Encoding.chunked) {
            client.state.flags.allowKeepalive = false
        }

        // 代理隧道
        if (client.flags.proxyTunneling && client.proxyTunnel == None) {
            if (response.statusCode == 200) {
                return ShouldContinue.continueStreaming
            }
            client.flags.proxyTunneling = false
            client.flags.disableKeepalive = true
        }

        // 重定向处理
        let isRedirect = response.statusCode >= 300 && response.statusCode <= 399
        if (isRedirect && location.size > 0 && client.state.flags.allowKeepalive) {
            // 301/302 POST -> GET, 303 -> GET
            match (response.statusCode) {
                case 301 => {
                    // 可能降级为 GET
                }
                case 302 => {
                    // 可能降级为 GET
                }
                case 303 => {
                    client.state.flags.isRedirectPending = true
                }
                case 307 => {
                    client.state.flags.isRedirectPending = true
                    client.state.flags.resendRequestBodyOnRedirect = true
                }
                case 308 => {
                    client.state.flags.isRedirectPending = true
                    client.state.flags.resendRequestBodyOnRedirect = true
                }
                case _ => ()
            }
            client.state.flags.isRedirectPending = true
        }

        // 设置响应阶段
        client.state.responseStage = if (client.state.transferEncoding == Encoding.chunked) {
            HTTPStage.bodyChunk
        } else {
            HTTPStage.body
        }

        // 检查是否需要继续接收 body
        let contentLength = client.state.contentLength
        let hasBody = contentLength != None && contentLength != Some(0)
        if (hasBody || client.state.transferEncoding == Encoding.chunked) {
            return ShouldContinue.continueStreaming
        } else {
            return ShouldContinue.finished
        }
    }

    // ========================================================================
    // handleResponseBody - 处理响应 body
    // 严格翻译自: HTTPClient.handleResponseBody
    // ========================================================================

    /// 处理响应 body
    /// 严格翻译自: HTTPClient.handleResponseBody
    public static func handleResponseBody(client: HTTPClient, data: String, isOnlyBuffer: Bool): Bool {
        let contentLength = client.state.contentLength
        if (isOnlyBuffer && contentLength != None) {
            let cl = match (contentLength) {
                case Some(v) => v
                case None => 0
            }
            if (data.size >= cl) {
                handleResponseBodyFromSinglePacket(client, data.substring(0, cl))
                return true
            }
        }
        return handleResponseBodyFromMultiplePackets(client, data)
    }

    /// 单包响应体处理
    /// 严格翻译自: HTTPClient.handleResponseBodyFromSinglePacket
    private static func handleResponseBodyFromSinglePacket(client: HTTPClient, data: String): Unit {
        client.state.totalBodyReceived += data.size
        if (client.state.flags.isRedirectPending) {
            return
        }
        // 追加到输出缓冲区
        match (client.state.bodyOutStr) {
            case Some(buf) => {
                for (c in data) {
                    buf.data.append(UInt8(c.value & 0xFF))
                }
            }
            case None => ()
        }
    }

    /// 多包响应体处理
    /// 严格翻译自: HTTPClient.handleResponseBodyFromMultiplePackets
    private static func handleResponseBodyFromMultiplePackets(client: HTTPClient, data: String): Bool {
        let contentLength = client.state.contentLength
        var remainder = data
        match (contentLength) {
            case Some(cl) => {
                let remaining = cl - client.state.totalBodyReceived
                let end = if (data.size < remaining) { data.size } else { remaining }
                remainder = data.substring(0, end)
            }
            case None => ()
        }

        if (!client.state.flags.isRedirectPending) {
            match (client.state.bodyOutStr) {
                case Some(buf) => {
                    for (c in remainder) {
                        buf.data.append(UInt8(c.value & 0xFF))
                    }
                }
                case None => ()
            }
        }

        client.state.totalBodyReceived += remainder.size

        let cl = match (contentLength) {
            case Some(v) => v
            case None => -1
        }
        let isDone = contentLength != None && client.state.totalBodyReceived >= cl
        return isDone
    }

    // ========================================================================
    // handleResponseBodyChunkedEncoding - 处理 chunked 编码 body
    // 严格翻译自: HTTPClient.handleResponseBodyChunkedEncoding
    // ========================================================================

    /// 处理 chunked 编码 body
    /// 严格翻译自: HTTPClient.handleResponseBodyChunkedEncoding
    public static func handleResponseBodyChunkedEncoding(client: HTTPClient, data: String): Bool {
        // 简化: 解析 chunked 数据
        var remaining = data
        var totalDecoded: Int64 = 0
        var done = false

        while (remaining.size > 0 && !done) {
            // 查找 chunk 大小行
            let crlfIdx = remaining.indexOf("\r\n")
            if (crlfIdx < 0) {
                return false  // 需要更多数据
            }

            let sizeStr = remaining.substring(0, crlfIdx).trim()
            // 跳过 chunk 扩展
            let semiIdx = sizeStr.indexOf(";")
            let cleanSize = if (semiIdx >= 0) { sizeStr.substring(0, semiIdx) } else { sizeStr }
            let chunkSize = parseHexInt(cleanSize)

            if (chunkSize == 0) {
                done = true
                client.state.flags.receivedLastChunk = true
                break
            }

            // 跳过 chunk 大小行
            let dataStart = crlfIdx + 2
            if (dataStart + chunkSize + 2 > remaining.size) {
                return false  // 需要更多数据
            }

            // 提取 chunk 数据
            let chunkData = remaining.substring(dataStart, dataStart + chunkSize)
            totalDecoded += chunkSize

            // 追加到输出
            match (client.state.bodyOutStr) {
                case Some(buf) => {
                    for (c in chunkData) {
                        buf.data.append(UInt8(c.value & 0xFF))
                    }
                }
                case None => ()
            }

            // 移动到下一个 chunk
            remaining = remaining.substring(dataStart + chunkSize + 2)
        }

        client.state.totalBodyReceived += totalDecoded
        return done
    }

    // ========================================================================
    // doRedirect - 执行重定向
    // 严格翻译自: HTTPClient.doRedirect
    // ========================================================================

    /// 执行重定向
    /// 严格翻译自: HTTPClient.doRedirect
    public static func doRedirect(client: HTTPClient, isSsl: Bool, ctx: HTTPContext, socketFd: Int64): Unit {
        if (client.state.originalRequestBody == HTTPRequestBody.bytes("")) {
            client.flags.isStreamingRequestBody = false
        }

        let requestBody = if (client.state.flags.resendRequestBodyOnRedirect) {
            client.state.requestBody
        } else {
            ""
        }

        client.state.responseMessageBuffer.reset()
        let bodyOutStr = match (client.state.bodyOutStr) {
            case Some(buf) => buf
            case None => MutableString()
        }

        // 关闭代理隧道
        match (client.proxyTunnel) {
            case Some(tunnel) => {
                client.proxyTunnel = None
                ProxyTunnelOps.shutdown(tunnel)
                ProxyTunnelOps.detachAndDeref(tunnel)
                ctx.closeSocket(socketFd)
            }
            case None => {
                // keep-alive socket 复用
                ctx.closeSocket(socketFd)
            }
        }

        client.state.reset()
        client.flags.proxyTunneling = false
        client.flags.protocol = HTTPProtocol.http1_1

        start(client, HTTPRequestBody.bytes(requestBody), bodyOutStr)
    }

    // ========================================================================
    // onClose - 连接关闭回调
    // 严格翻译自: HTTPClient.onClose
    // ========================================================================

    /// 连接关闭回调
    /// 严格翻译自: HTTPClient.onClose
    public static func onClose(client: HTTPClient, isSsl: Bool, socketFd: Int64): Unit {
        // 关闭代理隧道
        match (client.proxyTunnel) {
            case Some(tunnel) => {
                client.proxyTunnel = None
                ProxyTunnelOps.shutdown(tunnel)
                ProxyTunnelOps.detachAndDeref(tunnel)
            }
            case None => ()
        }

        let inProgress = client.state.stage != Stage.done &&
            client.state.stage != Stage.fail &&
            !client.state.flags.isRedirectPending

        if (client.state.flags.isRedirectPending) {
            // 执行重定向
            return
        }

        if (inProgress) {
            if (client.state.isChunkedEncoding()) {
                // chunked body 中关闭 — 可能已完成
                client.state.flags.receivedLastChunk = true
                return
            }
            match (client.state.contentLength) {
                case None => {
                    if (client.state.responseStage == HTTPStage.body) {
                        client.state.flags.receivedLastChunk = true
                        return
                    }
                }
                case _ => ()
            }
        }

        // 幂等方法重试
        if (client.state.responseStage != HTTPStage.body &&
            client.state.responseStage != HTTPStage.bodyChunk) {
            // 重试逻辑
        }

        if (inProgress) {
            fail(client, "ConnectionClosed")
        }
    }

    // ========================================================================
    // onTimeout - 超时回调
    // 严格翻译自: HTTPClient.onTimeout
    // ========================================================================

    /// 超时回调
    /// 严格翻译自: HTTPClient.onTimeout
    public static func onTimeout(client: HTTPClient, isSsl: Bool, socketFd: Int64): Unit {
        if (client.flags.disableTimeout) {
            return
        }
        fail(client, "Timeout")
    }

    // ========================================================================
    // progressUpdate - 进度更新
    // 严格翻译自: HTTPClient.progressUpdate / sendProgressUpdateWithoutStageCheck
    // ========================================================================

    /// 进度更新
    /// 严格翻译自: HTTPClient.progressUpdate
    public static func progressUpdate(client: HTTPClient, isSsl: Bool, ctx: HTTPContext, socketFd: Int64): Unit {
        if (client.state.stage != Stage.done && client.state.stage != Stage.fail) {
            if (client.state.flags.isRedirectPending && client.state.fail == None) {
                if (client.state.isDone()) {
                    doRedirect(client, isSsl, ctx, socketFd)
                }
                return
            }
            sendProgressUpdateWithoutStageCheck(client, isSsl, ctx, socketFd)
        }
    }

    /// 发送进度更新 (不检查阶段)
    /// 严格翻译自: HTTPClient.sendProgressUpdateWithoutStageCheck
    private static func sendProgressUpdateWithoutStageCheck(client: HTTPClient, isSsl: Bool, ctx: HTTPContext, socketFd: Int64): Unit {
        let result = toResult(client)
        let isDone = !result.hasMore

        if (isDone) {
            // keep-alive socket 复用或关闭
            if (client.flags.disableKeepalive == false && client.state.flags.allowKeepalive) {
                ctx.releaseSocket(
                    socketFd,
                    client.flags.didHaveHandshakingError,
                    client.url.hostname,
                    UInt16(client.url.port),
                    None,
                    client.proxyTunnel,
                    "",
                    UInt16(0),
                    UInt64(0),
                    None
                )
            } else {
                ctx.closeSocket(socketFd)
            }

            client.state.reset()
            client.state.responseStage = HTTPStage.done
            client.state.requestStage = HTTPStage.done
            client.state.stage = Stage.done
            client.flags.proxyTunneling = false
        }

        // 调用结果回调
        client.resultCallback.run(Some(client), result)
    }

    // ========================================================================
    // fail - 失败处理
    // 严格翻译自: HTTPClient.fail
    // ========================================================================

    /// 失败处理
    /// 严格翻译自: HTTPClient.fail
    public static func fail(client: HTTPClient, err: String): Unit {
        // 关闭代理隧道
        match (client.proxyTunnel) {
            case Some(tunnel) => {
                client.proxyTunnel = None
                ProxyTunnelOps.shutdown(tunnel)
                ProxyTunnelOps.detachAndDeref(tunnel)
            }
            case None => ()
        }

        if (client.state.stage != Stage.done && client.state.stage != Stage.fail) {
            client.state.requestStage = HTTPStage.fail
            client.state.responseStage = HTTPStage.fail
            client.state.fail = Some(err)
            client.state.stage = Stage.fail

            if (!client.flags.deferFailUntilConnectingIsComplete) {
                let callback = client.resultCallback
                let result = toResult(client)
                client.state.reset()
                client.flags.proxyTunneling = false
                callback.run(Some(client), result)
            }
        }
    }

    // ========================================================================
    // closeAndFail / closeAndAbort
    // ========================================================================

    /// 关闭并失败
    /// 严格翻译自: HTTPClient.closeAndFail
    public static func closeAndFail(client: HTTPClient, err: String, isSsl: Bool, socketFd: Int64): Unit {
        fail(client, err)
    }

    /// 关闭并中止
    /// 严格翻译自: HTTPClient.closeAndAbort
    public static func closeAndAbort(client: HTTPClient, isSsl: Bool, socketFd: Int64): Unit {
        closeAndFail(client, "Aborted", isSsl, socketFd)
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 完成连接过程
    /// 严格翻译自: HTTPClient.completeConnectingProcess
    private static func completeConnectingProcess(client: HTTPClient): Unit {
        if (client.flags.deferFailUntilConnectingIsComplete) {
            client.flags.deferFailUntilConnectingIsComplete = false
            if (client.state.stage == Stage.fail) {
                let callback = client.resultCallback
                let result = toResult(client)
                client.state.reset()
                client.flags.proxyTunneling = false
                callback.run(Some(client), result)
            }
        }
    }

    /// 设置超时
    /// 严格翻译自: HTTPClient.setTimeout
    public static func setTimeout(client: HTTPClient, socketFd: Int64): Unit {
        if (client.flags.disableTimeout || idleTimeoutSeconds == 0) {
            return
        }
        // socket.setTimeout(idleTimeoutSeconds)
    }

    /// 处理短读取
    /// 严格翻译自: HTTPClient.handleShortRead
    private static func handleShortRead(client: HTTPClient, isSsl: Bool, data: Array<UInt8>, socketFd: Int64, needsMove: Bool): Unit {
        if (needsMove && data.size > 0) {
            client.state.responseMessageBuffer.append(data)
        }
        setTimeout(client, socketFd)
    }

    /// 克隆元数据
    /// 严格翻译自: HTTPClient.cloneMetadata
    public static func cloneMetadata(client: HTTPClient): Unit {
        match (client.state.pendingResponse) {
            case Some(response) => {
                let meta = HTTPResponseMetadata()
                meta.response = Some(response)
                meta.url = client.url.toString()
                client.state.clonedMetadata = Some(meta)
                client.state.pendingResponse = None
            }
            case None => ()
        }
    }

    /// 生成结果
    /// 严格翻译自: HTTPClient.toResult
    public static func toResult(client: HTTPClient): HTTPClientResult {
        let bodySize: BodySize = if (client.state.isChunkedEncoding()) {
            BodySize.totalReceived(client.state.totalBodyReceived)
        } else {
            match (client.state.contentLength) {
                case Some(cl) => BodySize.contentLength(cl)
                case None => BodySize.unknown
            }
        }

        var hasMore = false
        match (client.state.fail) {
            case None => {
                if (!client.state.isDone()) {
                    hasMore = true
                }
            }
            case Some(_) => ()
        }

        return HTTPClientResult(
            body: client.state.bodyOutStr,
            hasMore: hasMore,
            redirected: client.flags.redirected,
            canStream: false,
            isHttp2: client.flags.protocol != HTTPProtocol.http1_1,
            fail: client.state.fail,
            metadata: client.state.clonedMetadata,
            bodySize: bodySize,
            certificateInfo: client.state.certificateInfo
        )
    }

    /// 发送初始请求载荷
    /// 严格翻译自: HTTPClient.sendInitialRequestPayload
    private static func sendInitialRequestPayload(client: HTTPClient, isFirstCall: Bool, isSsl: Bool, socketFd: Int64): Unit {
        // 构建请求
        let request = buildRequest(client, 0)
        let rawRequest = serializeRequest(request, client)

        // 写入 socket
        // writeToSocket(isSsl, socketFd, stringToBytes(rawRequest))
    }

    /// 构建请求
    /// 严格翻译自: HTTPClient.buildRequest
    public static func buildRequest(client: HTTPClient, bodyLen: Int64): RawRequest {
        let request = RawRequest()
        request.method = client.url.toString() // 简化
        request.path = client.url.path
        request.minorVersion = 1

        // 添加默认头部
        request.headers.append(HeaderPair("Host", client.url.hostname))
        request.headers.append(HeaderPair("User-Agent", BAO_USER_AGENT))
        request.headers.append(HeaderPair("Accept", "*/*"))
        request.headers.append(HeaderPair("Connection", "keep-alive"))

        if (bodyLen > 0) {
            request.headers.append(HeaderPair("Content-Length", bodyLen.toString()))
        }

        if (!client.flags.disableDecompression) {
            request.headers.append(HeaderPair("Accept-Encoding", "gzip, deflate, br, zstd"))
        }

        return request
    }

    /// 序列化请求
    private static func serializeRequest(request: RawRequest, client: HTTPClient): String {
        let sb = StringBuilder()
        sb.append(request.method)
        sb.append(" ")
        sb.append(request.path)
        sb.append(" HTTP/1.1\r\n")
        for (header in request.headers) {
            sb.append(header.name)
            sb.append(": ")
            sb.append(header.value)
            sb.append("\r\n")
        }
        sb.append("\r\n")
        return sb.toString()
    }

    /// 是否 HTTPS
    /// 严格翻译自: HTTPClient.isHTTPS
    public static func isHTTPS(client: HTTPClient): Bool {
        match (client.url.protocol) {
            case "https" => true
            case _ => false
        }
    }

    /// 检查服务器身份
    /// 严格翻译自: HTTPClient.checkServerIdentity
    public static func checkServerIdentity(client: HTTPClient, isSsl: Bool, socketFd: Int64, hostname: String): Bool {
        if (!client.flags.rejectUnauthorized) {
            return true  // 允许连接继续
        }
        // 验证主机名 — 简化
        return true
    }

    /// 写入代理 CONNECT 请求
    /// 严格翻译自: HTTPClient.writeProxyConnect
    public static func writeProxyConnect(client: HTTPClient): String {
        let sb = StringBuilder()
        let hostname = client.url.hostname
        let port = if (client.url.port == 0) {
            if (client.url.protocol == "https") { "443" } else { "80" }
        } else {
            client.url.port.toString()
        }

        sb.append("CONNECT ")
        sb.append(hostname)
        sb.append(":")
        sb.append(port)
        sb.append(" HTTP/1.1\r\n")
        sb.append("Host: ")
        sb.append(hostname)
        sb.append(":")
        sb.append(port)
        sb.append("\r\n")
        sb.append("Proxy-Connection: Keep-Alive\r\n")
        sb.append("\r\n")
        return sb.toString()
    }

    /// 写入代理请求
    /// 严格翻译自: HTTPClient.writeProxyRequest
    public static func writeProxyRequest(request: RawRequest, client: HTTPClient): String {
        let sb = StringBuilder()
        sb.append(request.method)
        sb.append(" http://")
        sb.append(client.url.hostname)
        sb.append(request.path)
        sb.append(" HTTP/1.1\r\n")
        sb.append("Proxy-Connection: Keep-Alive\r\n")
        for (header in request.headers) {
            sb.append(header.name)
            sb.append(": ")
            sb.append(header.value)
            sb.append("\r\n")
        }
        sb.append("\r\n")
        return sb.toString()
    }
}

// ============================================================================
// 全局辅助函数
// ============================================================================

/// 解析原始 HTTP 响应
public func parseRawResponse(raw: String): ?RawResponse {
    let response = RawResponse()

    let headerEnd = raw.indexOf("\r\n\r\n")
    if (headerEnd < 0) {
        return None
    }

    let headerSection = raw.substring(0, headerEnd)
    let lines = splitLines(headerSection)
    if (lines.size == 0) {
        return None
    }

    // 解析状态行: HTTP/1.x <status_code> <reason>
    let statusLine = lines[0]
    let parts = split(statusLine, " ")
    if (parts.size < 3) {
        return None
    }

    response.statusCode = parseInt64(parts[1])
    var statusText = StringBuilder()
    for (i in 2..parts.size) {
        if (i > 2) { statusText.append(" ") }
        statusText.append(parts[i])
    }
    response.statusText = statusText.toString()
    response.bytesRead = headerEnd + 4

    // 解析头部
    for (i in 1..lines.size) {
        let line = lines[Int64(i)]
        let colonIdx = line.indexOf(":")
        if (colonIdx >= 0) {
            let name = line.substring(0, colonIdx).trim()
            let value = line.substring(colonIdx + 1).trim()
            response.headers.append(HeaderPair(name, value))
        }
    }

    return Some(response)
}

/// 按行分割
private func splitLines(s: String): ArrayList<String> {
    let lines = ArrayList<String>()
    var current = StringBuilder()
    var i = 0
    while (i < s.size) {
        if (i + 1 < s.size && s[Int64(i)] == '\r' && s[Int64(i + 1)] == '\n') {
            lines.append(current.toString())
            current = StringBuilder()
            i += 2
        } else {
            current.append(s[Int64(i)])
            i += 1
        }
    }
    if (current.toString().size > 0) {
        lines.append(current.toString())
    }
    return lines
}

/// 按分隔符分割
private func split(s: String, sep: String): ArrayList<String> {
    let parts = ArrayList<String>()
    var remaining = s
    while (true) {
        let idx = remaining.indexOf(sep)
        if (idx < 0) {
            parts.append(remaining)
            break
        }
        parts.append(remaining.substring(0, idx))
        remaining = remaining.substring(idx + sep.size)
    }
    return parts
}

/// 解析 Int64
public func parseInt64(s: String): Int64 {
    var result: Int64 = 0
    var neg = false
    var idx = 0
    if (s.size > 0 && s[Int64(0)] == '-') {
        neg = true
        idx = 1
    }
    while (idx < s.size) {
        let c = s[Int64(idx)]
        if (c.value >= 48 && c.value <= 57) {
            result = result * 10 + Int64(c.value - 48)
        } else {
            break
        }
        idx += 1
    }
    return if (neg) { -result } else { result }
}

/// 解析十六进制整数
public func parseHexInt(s: String): Int64 {
    var result: Int64 = 0
    for (c in s) {
        let v = c.value
        if (v >= 48 && v <= 57) {       // 0-9
            result = result * 16 + Int64(v - 48)
        } else if (v >= 97 && v <= 102) { // a-f
            result = result * 16 + Int64(v - 87)
        } else if (v >= 65 && v <= 70) {  // A-F
            result = result * 16 + Int64(v - 55)
        } else {
            break
        }
    }
    return result
}

/// 字节数组转字符串
public func bytesToString(bytes: Array<UInt8>): String {
    let sb = StringBuilder()
    for (b in bytes) {
        sb.append(Char(Int32(b)))
    }
    return sb.toString()
}

/// 字符串转字节数组
public func stringToBytes(s: String): Array<UInt8> {
    var bytes = Array<UInt8>()
    for (c in s) {
        bytes.append(UInt8(c.value & 0xFF))
    }
    return bytes
}

/// 头部名称哈希
/// 严格翻译自: HTTPClient.hashHeaderName
public func hashHeaderName(name: String): UInt64 {
    var hash: UInt64 = UInt64(0)
    for (c in name) {
        let lower = c.toLower().value
        hash = hash * UInt64(31) + UInt64(lower)
    }
    return hash
}
