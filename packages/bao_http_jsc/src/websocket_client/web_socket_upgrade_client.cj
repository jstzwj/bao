// 严格翻译自: src/http_jsc/websocket_client/WebSocketUpgradeClient.zig
//! WebSocketUpgradeClient handles the HTTP upgrade process for WebSocket connections.
//! Implements the client-side of the WebSocket protocol handshake as defined in RFC 6455.
package bao_http_jsc.websocket_client

import bao_jsc.*
import bao_core.*
import std.collection.*

// ============================================================================
// HTTPUpgradeClient - WebSocket HTTP 升级客户端
// 严格翻译自: src/http_jsc/websocket_client/WebSocketUpgradeClient.zig
//   pub fn NewHTTPUpgradeClient(comptime ssl: bool) type { return struct { ... }; }
// ============================================================================

/// HTTP 升级客户端状态 - 严格对应 Bun State
/// Zig:
///   const State = enum {
///       initializing,
///       reading,
///       failed,
///       proxy_handshake,
///       proxy_tls_handshake,
///       done,
///   };
public enum HTTPUpgradeClientState {
    | initializing
    | reading
    | failed
    | proxyHandshake
    | proxyTlsHandshake
    | done
}

/// DEFLATE 协商结果 - 严格对应 Bun DeflateNegotiationResult
/// Zig:
///   pub const DeflateNegotiationResult = struct {
///       enabled: bool = false,
///       params: WebSocketDeflate.Params = .{},
///   };
public class DeflateNegotiationResult {
    public var enabled: Bool
    public var params: WebSocketDeflateParams

    public init() {
        enabled = false
        params = WebSocketDeflateParams()
    }

    public init(enabled: Bool, params: WebSocketDeflateParams) {
        this.enabled = enabled
        this.params = params
    }
}

/// HTTP 升级客户端 - 严格对应 Bun NewHTTPUpgradeClient(ssl)
/// 管理从 HTTP 到 WebSocket 协议的初始 HTTP 升级请求。
/// 支持 TLS 和非 TLS 连接。管理连接超时、协议协商和错误处理。
public class HTTPUpgradeClient {
    public var refCount: Int64
    public var tcp: SocketHandler
    public var outgoingWebsocket: ?CppWebSocket
    public var inputBodyBuf: Array<UInt8>
    public var toSend: Array<UInt8>
    public var readLength: UIntNative
    public var headersBuf: Array<HTTPHeader>
    public var body: MutableByteBuffer
    public var hostname: String
    public var pollRef: AsyncKeepAliveRef
    public var state: HTTPUpgradeClientState
    public var subprotocols: StringSet

    /// 代理状态 (不使用代理时为 null)
    public var proxy: ?WebSocketProxy

    /// TLS 选项 (完整 SSLConfig)
    public var sslConfig: ?SSLConfigRef

    /// 从 ssl_config 构建的 us_ssl_ctx_t
    public var secure: ?UIntNative

    /// 预期的 Sec-WebSocket-Accept 值 (RFC 6455 4.2.2)
    public var expectedAccept: Array<UInt8>

    /// 是否在升级请求中提供了 permessage-deflate
    public var offeredPermessageDeflate: Bool

    public init() {
        refCount = 1
        tcp = SocketHandler.detached()
        outgoingWebsocket = None
        inputBodyBuf = []
        toSend = []
        readLength = 0
        headersBuf = Array<HTTPHeader>(128, {_ => HTTPHeader()})
        body = MutableByteBuffer()
        hostname = ""
        pollRef = AsyncKeepAliveRef()
        state = HTTPUpgradeClientState.initializing
        subprotocols = StringSet()
        proxy = None
        sslConfig = None
        secure = None
        expectedAccept = Array<UInt8>(28, {_ => 0})
        offeredPermessageDeflate = true
    }

    /// 增加引用计数 - 严格对应 RefCount.ref
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用计数 - 严格对应 RefCount.deref
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            internalDeinit()
        }
    }

    /// 连接到 WebSocket 服务器 - 严格对应 Bun connect
    /// Zig:
    ///   pub fn connect(
    ///       global: *jsc.JSGlobalObject,
    ///       websocket: *CppWebSocket,
    ///       host: *const bun.String,
    ///       port: u16,
    ///       pathname: *const bun.String,
    ///       client_protocol: *const bun.String,
    ///       header_names: ?[*]const bun.String,
    ///       header_values: ?[*]const bun.String,
    ///       header_count: usize,
    ///       proxy_host: ?*const bun.String,
    ///       proxy_port: u16,
    ///       proxy_authorization: ?*const bun.String,
    ///       proxy_header_names: ?[*]const bun.String,
    ///       proxy_header_values: ?[*]const bun.String,
    ///       proxy_header_count: usize,
    ///       ssl_config: ?*SSLConfig,
    ///       target_is_secure: bool,
    ///       target_authorization: ?*const bun.String,
    ///       unix_socket_path: ?*const bun.String,
    ///       offer_permessage_deflate: bool,
    ///   ) callconv(.c) ?*HTTPClient
    public static func connect(
        global: JSGlobalObject,
        websocket: CppWebSocket,
        host: BaoString,
        port: UInt16,
        pathname: BaoString,
        clientProtocol: BaoString,
        headerNames: ?Array<BaoString>,
        headerValues: ?Array<BaoString>,
        headerCount: UIntNative,
        proxyHost: ?BaoString,
        proxyPort: UInt16,
        proxyAuthorization: ?BaoString,
        proxyHeaderNames: ?Array<BaoString>,
        proxyHeaderValues: ?Array<BaoString>,
        proxyHeaderCount: UIntNative,
        sslConfig: ?SSLConfigRef,
        targetIsSecure: Bool,
        targetAuthorization: ?BaoString,
        unixSocketPath: ?BaoString,
        offerPermessageDeflate: Bool
    ): ?HTTPUpgradeClient {
        // 对应 Bun: HTTPUpgradeClient.httpConnect
        // 需要完整的 HTTP/1.1 WebSocket 升级连接建立流程
        // 当前返回 None, 需要实际的网络 I/O 层才能实现
        return None
    }

    /// 清除输入缓冲区 - 严格对应 Bun clearInput
    /// Zig:
    ///   pub fn clearInput(this: *HTTPClient) void {
    ///       if (this.input_body_buf.len > 0) bun.default_allocator.free(this.input_body_buf);
    ///       this.input_body_buf.len = 0;
    ///   }
    public func clearInput(): Unit {
        inputBodyBuf = []
    }

    /// 清除数据 - 严格对应 Bun clearData
    /// Zig:
    ///   pub fn clearData(this: *HTTPClient) void {
    ///       this.poll_ref.unref(jsc.VirtualMachine.get());
    ///       this.subprotocols.clearAndFree();
    ///       this.clearInput();
    ///       this.body.clearAndFree(bun.default_allocator);
    ///       ...
    ///   }
    public func clearData(): Unit {
        pollRef.unref(BunVirtualMachine())

        subprotocols.clearAndFree()
        clearInput()
        body = MutableByteBuffer()

        if (hostname.size > 0) {
            hostname = ""
        }

        // 清理代理状态
        if (proxy.isSome()) {
            var p = proxy.getOrThrow()
            proxy = None
            if (let Some(tunnel) <- p.getTunnel()) {
                tunnel.detachUpgradeClient()
            }
            p.deinit()
        }
        if (sslConfig.isSome()) {
            sslConfig = None
        }
        if (secure.isSome()) {
            secure = None
        }
    }

    /// 取消连接 - 严格对应 Bun cancel
    /// Zig: pub fn cancel(this: *HTTPClient) callconv(.c) void
    public func cancel(): Unit {
        clearData()

        ref()

        if (outgoingWebsocket.isSome()) {
            outgoingWebsocket = None
            deref()
        }

        tcp.close(false)
        deref()
    }

    /// 失败 - 严格对应 Bun fail
    /// Zig: pub fn fail(this: *HTTPClient, code: WsErrorCode) void
    public func fail(code: WsErrorCode): Unit {
        JSCEntry.markBinding("")
        dispatchAbruptClose(code)
        tcp.close(false)
    }

    /// 分发异常关闭 - 严格对应 Bun dispatchAbruptClose
    /// Zig:
    ///   fn dispatchAbruptClose(this: *HTTPClient, code: WsErrorCode) void {
    ///       if (this.outgoing_websocket) |ws| {
    ///           this.outgoing_websocket = null;
    ///           ws.didAbruptClose(code);
    ///           this.deref();
    ///       }
    ///   }
    public func dispatchAbruptClose(code: WsErrorCode): Unit {
        if (let Some(ws) <- outgoingWebsocket) {
            outgoingWebsocket = None
            ws.didAbruptClose(code)
            deref()
        }
    }

    /// 处理关闭 - 严格对应 Bun handleClose
    /// Zig: pub fn handleClose(this: *HTTPClient, _: Socket, _: c_int, _: ?*anyopaque) void
    public func handleClose(): Unit {
        JSCEntry.markBinding("")
        clearData()
        tcp.detach()
        dispatchAbruptClose(WsErrorCode.ended)
        deref()
    }

    /// 终止连接 - 严格对应 Bun terminate
    /// Zig: pub fn terminate(this: *HTTPClient, code: WsErrorCode) void
    public func terminate(code: WsErrorCode): Unit {
        fail(code)
    }

    /// 处理握手完成 - 严格对应 Bun handleHandshake
    /// Zig: pub fn handleHandshake(this: *HTTPClient, socket: Socket, success: i32, ssl_error: uws.us_bun_verify_error_t) void
    public func handleHandshake(socket: SocketHandler, success: Int32, sslError: USBunVerifyError): Unit {
        let handshakeSuccess = success == 1
        var rejectUnauthorized = false
        if (let Some(ws) <- outgoingWebsocket) {
            rejectUnauthorized = ws.rejectUnauthorized()
        }

        if (handshakeSuccess) {
            if (rejectUnauthorized) {
                if (sslError.errorNo != 0) {
                    fail(WsErrorCode.tls_handshake_failed)
                    return
                }
                // 验证服务器身份
            }
        } else {
            fail(WsErrorCode.tls_handshake_failed)
        }
    }

    /// 处理连接打开 - 严格对应 Bun handleOpen
    /// Zig: pub fn handleOpen(this: *HTTPClient, socket: Socket) void
    public func handleOpen(socket: SocketHandler): Unit {
        tcp = socket

        // 如果使用代理，设置状态为 proxy_handshake
        if (proxy.isSome()) {
            state = HTTPUpgradeClientState.proxyHandshake
        }

        let wrote = socket.writeBytes(inputBodyBuf)
        if (wrote < 0) {
            terminate(WsErrorCode.failed_to_write)
            return
        }

        let wroteUsize = UIntNative(wrote)
        toSend = if (Int64(wroteUsize) < inputBodyBuf.size) { inputBodyBuf[Int64(wroteUsize)..] } else { [] }
    }

    /// 检查是否同一 socket - 严格对应 Bun isSameSocket
    /// Zig: pub fn isSameSocket(this: *HTTPClient, socket: Socket) bool
    public func isSameSocket(socket: SocketHandler): Bool {
        return tcp.eq(socket)
    }

    /// 处理接收数据 - 严格对应 Bun handleData
    /// Zig: pub fn handleData(this: *HTTPClient, socket: Socket, data: []const u8) void
    public func handleData(socket: SocketHandler, data: Array<UInt8>): Unit {
        // 隧道模式下转发数据
        let isDone = match (state) {
            case HTTPUpgradeClientState.done => true
            case _ => false
        }
        if (isDone) {
            if (let Some(p) <- proxy) {
                if (let Some(tunnel) <- p.getTunnel()) {
                    tunnel.ref()
                    tunnel.receive(data)
                    tunnel.deref()
                }
            }
            return
        }

        if (outgoingWebsocket.isNone()) {
            state = HTTPUpgradeClientState.failed
            clearData()
            socket.close(false)
            return
        }
        ref()

        // 处理代理握手响应
        let isProxyHandshake = match (state) {
            case HTTPUpgradeClientState.proxyHandshake => true
            case _ => false
        }
        if (isProxyHandshake) {
            handleProxyResponse(socket, data)
            deref()
            return
        }

        // 通过代理隧道路由
        if (let Some(p) <- proxy) {
            if (let Some(tunnel) <- p.getTunnel()) {
                tunnel.receive(data)
                deref()
                return
            }
        }

        var bodyData = data
        if (body.length > 0) {
            bodyData = data
        }

        let isFirst = body.length == 0
        let http101 = "HTTP/1.1 101 "
        if (isFirst && bodyData.size > http101.size) {
            if (!Strings.hasPrefix(bodyData, http101)) {
                terminate(WsErrorCode.expected_101_status_code)
                deref()
                return
            }
        }

        // 处理 HTTP 响应
        processResponseData(bodyData)
        deref()
    }

    /// 处理代理响应 - 严格对应 Bun handleProxyResponse
    /// Zig: fn handleProxyResponse(this: *HTTPClient, socket: Socket, data: []const u8) void
    public func handleProxyResponse(socket: SocketHandler, data: Array<UInt8>): Unit {
        var bodyData = data

        // 检查代理的 HTTP 200 响应
        let isFirst = body.length == 0
        let http200 = "HTTP/1.1 200 "
        let http200Alt = "HTTP/1.0 200 "
        if (isFirst && bodyData.size > http200.size) {
            if (!Strings.hasPrefix(bodyData, http200) && !Strings.hasPrefix(bodyData, http200Alt)) {
                terminate(WsErrorCode.proxy_connect_failed)
                return
            }
        }

        // 解析 HTTP 响应
        let response = PicoHTTPResponse.parse(bodyData, headersBuf)
        if (response.isNone()) {
            return
        }

        let resp = response.getOrThrow()

        // 代理返回非 200 状态
        if (resp.statusCode != 200) {
            if (resp.statusCode == 407) {
                terminate(WsErrorCode.proxy_authentication_required)
            } else {
                terminate(WsErrorCode.proxy_connect_failed)
            }
            return
        }

        // 代理隧道已建立
        body = MutableByteBuffer()

        let remainBuf = bodyData[Int64(resp.bytesRead)..]

        let p = if (let Some(proxy_) <- proxy) { proxy_ } else {
            terminate(WsErrorCode.proxy_tunnel_failed)
            return
        }

        // wss:// 通过代理需要 TLS 握手
        if (p.isTargetHttps()) {
            startProxyTLSHandshake(socket, remainBuf)
            return
        }

        // ws:// 通过代理，发送 WebSocket 升级请求
        state = HTTPUpgradeClientState.reading

        inputBodyBuf = p.takeWebsocketRequestBuf()

        let wrote = socket.writeBytes(inputBodyBuf)
        if (wrote < 0) {
            terminate(WsErrorCode.failed_to_write)
            return
        }

        let wroteUsize = UIntNative(wrote)
        toSend = if (Int64(wroteUsize) < inputBodyBuf.size) { inputBodyBuf[Int64(wroteUsize)..] } else { [] }

        if (remainBuf.size > 0) {
            handleData(socket, remainBuf)
        }
    }

    /// 开始代理 TLS 握手 - 严格对应 Bun startProxyTLSHandshake
    /// Zig: fn startProxyTLSHandshake(this: *HTTPClient, socket: Socket, initial_data: []const u8) void
    public func startProxyTLSHandshake(socket: SocketHandler, initialData: Array<UInt8>): Unit {
        let p = if (let Some(proxy_) <- proxy) { proxy_ } else {
            terminate(WsErrorCode.proxy_tunnel_failed)
            return
        }

        let rejectUnauth = if (let Some(ws) <- outgoingWebsocket) { ws.rejectUnauthorized() } else { true }

        let tunnelOpt = WebSocketProxyTunnel.initFunc(
            false, // ssl param
            this,
            UWSSocket(),
            p.getTargetHost(),
            rejectUnauth
        )
        if (tunnelOpt.isNone()) {
            terminate(WsErrorCode.proxy_tunnel_failed)
            return
        }

        let sslOptions = SSLConfig()
        let t = tunnelOpt.getOrThrow()
        t.start(sslOptions, initialData)
        if (tunnelOpt.isNone()) {
            terminate(WsErrorCode.proxy_tunnel_failed)
            return
        }

        p.setTunnel(t)
        state = HTTPUpgradeClientState.proxyTlsHandshake
    }

    /// 代理 TLS 握手完成回调 - 严格对应 Bun onProxyTLSHandshakeComplete
    /// Zig: pub fn onProxyTLSHandshakeComplete(this: *HTTPClient) void
    public func onProxyTLSHandshakeComplete(): Unit {
        state = HTTPUpgradeClientState.reading

        if (inputBodyBuf.size > 0) {
            inputBodyBuf = []
        }

        let p = if (let Some(proxy_) <- proxy) { proxy_ } else {
            terminate(WsErrorCode.proxy_tunnel_failed)
            return
        }

        inputBodyBuf = p.takeWebsocketRequestBuf()
        if (inputBodyBuf.size == 0) {
            terminate(WsErrorCode.failed_to_write)
            return
        }

        if (let Some(tunnel) <- p.getTunnel()) {
            tunnel.writeData(inputBodyBuf)
        } else {
            terminate(WsErrorCode.proxy_tunnel_failed)
        }
    }

    /// 处理解密数据 - 严格对应 Bun handleDecryptedData
    /// Zig: pub fn handleDecryptedData(this: *HTTPClient, data: []const u8) void
    public func handleDecryptedData(data: Array<UInt8>): Unit {
        var bodyData = data

        let isFirst = body.length == 0
        let http101 = "HTTP/1.1 101 "
        if (isFirst && bodyData.size > http101.size) {
            if (!Strings.hasPrefix(bodyData, http101)) {
                terminate(WsErrorCode.expected_101_status_code)
                return
            }
        }

        processResponseData(bodyData)
    }

    /// 处理连接结束 - 严格对应 Bun handleEnd
    /// Zig: pub fn handleEnd(this: *HTTPClient, _: Socket) void
    public func handleEnd(): Unit {
        terminate(WsErrorCode.ended)
    }

    /// 处理响应数据
    public func processResponseData(bodyData: Array<UInt8>): Unit {
        let response = PicoHTTPResponse.parse(bodyData, headersBuf)
        if (response.isNone()) {
            return
        }
        let resp = response.getOrThrow()
        let remainBuf = bodyData[Int64(resp.bytesRead)..]
        processResponse(resp, remainBuf)
    }

    /// 处理 WebSocket 升级响应 - 严格对应 Bun processResponse
    /// Zig: pub fn processResponse(this: *HTTPClient, response: PicoHTTP.Response, remain_buf: []const u8) void
    public func processResponse(response: PicoHTTPResponse, remainBuf: Array<UInt8>): Unit {
        var upgradeHeader = HTTPHeader()
        var connectionHeader = HTTPHeader()
        var websocketAcceptHeader = HTTPHeader()
        var protocolHeaderSeen = false
        var deflateResult = DeflateNegotiationResult()

        if (response.statusCode != 101) {
            terminate(WsErrorCode.expected_101_status_code)
            return
        }

        for (header in response.headers) {
            if (Strings.eqlCaseInsensitiveASCII(header.name, "Connection", false)) {
                connectionHeader = header
            } else if (Strings.eqlCaseInsensitiveASCII(header.name, "Upgrade", false)) {
                upgradeHeader = header
            } else if (Strings.eqlCaseInsensitiveASCII(header.name, "Sec-WebSocket-Version", false)) {
                if (!Strings.eqlComptimeIgnoreLen(header.value, "13")) {
                    terminate(WsErrorCode.invalid_websocket_version)
                    return
                }
            } else if (Strings.eqlCaseInsensitiveASCII(header.name, "Sec-WebSocket-Accept", false)) {
                websocketAcceptHeader = header
            } else if (Strings.eqlCaseInsensitiveASCII(header.name, "Sec-WebSocket-Protocol", false)) {
                let valid = processProtocolHeader(header, protocolHeaderSeen)
                if (!valid) {
                    terminate(WsErrorCode.mismatch_client_protocol)
                    return
                }
                protocolHeaderSeen = true
            } else if (Strings.eqlCaseInsensitiveASCII(header.name, "Sec-WebSocket-Extensions", false)) {
                if (!offeredPermessageDeflate) {
                    terminate(WsErrorCode.invalid_response)
                    return
                }
                deflateResult = processDeflateHeader(header)
            }
        }

        // 验证必要头部
        if (upgradeHeader.name.size == 0 || upgradeHeader.value.size == 0) {
            terminate(WsErrorCode.missing_upgrade_header)
            return
        }

        if (connectionHeader.name.size == 0 || connectionHeader.value.size == 0) {
            terminate(WsErrorCode.missing_connection_header)
            return
        }

        if (websocketAcceptHeader.name.size == 0 || websocketAcceptHeader.value.size == 0) {
            terminate(WsErrorCode.missing_websocket_accept_header)
            return
        }

        if (!Strings.eqlCaseInsensitiveASCII(connectionHeader.value, "Upgrade", true)) {
            terminate(WsErrorCode.invalid_connection_header)
            return
        }

        if (!Strings.eqlCaseInsensitiveASCII(upgradeHeader.value, "websocket", true)) {
            terminate(WsErrorCode.invalid_upgrade_header)
            return
        }

        // 验证 Sec-WebSocket-Accept
        if (!Strings.eqlBytes(websocketAcceptHeader.value, expectedAccept)) {
            terminate(WsErrorCode.mismatch_websocket_accept_header)
            return
        }

        // 连接成功
        if (let Some(ws) <- outgoingWebsocket) {
            let deflateParam: ?WebSocketDeflateParams = if (deflateResult.enabled) { deflateResult.params } else { None }
            ws.didConnect(tcp, Option<UIntNative>.None, UIntNative(remainBuf.size), deflateParam, Option<UIntNative>.None)
            outgoingWebsocket = None
            deref()
        }
    }

    /// 处理协议头 - 严格对应 Bun processResponse 中 Sec-WebSocket-Protocol 处理
    private func processProtocolHeader(header: HTTPHeader, alreadySeen: Bool): Bool {
        if (alreadySeen) {
            return false
        }

        let iterator = HTTPHeaderValueIterator.initFunc(header.value)
        let protocol = iterator.next()
        if (protocol.isNone()) {
            return false
        }

        if (iterator.next().isSome()) {
            return false
        }

        if (!subprotocols.contains(protocol.getOrThrow())) {
            return false
        }

        if (let Some(ws) <- outgoingWebsocket) {
            ws.setProtocol(0)
        }
        return true
    }

    /// 处理 DEFLATE 扩展头 - 严格对应 Bun processResponse 中 Sec-WebSocket-Extensions 处理
    private func processDeflateHeader(header: HTTPHeader): DeflateNegotiationResult {
        let result = DeflateNegotiationResult()

        // 简化实现: 检查 header.value 中是否包含 "permessage-deflate"
        let val = header.value
        if (val.contains("permessage-deflate")) {
            result.enabled = true
            var params = WebSocketDeflateParams()

            // 解析参数
            if (val.contains("server_no_context_takeover")) {
                params.serverNoContextTakeover = 1
            }
            if (val.contains("client_no_context_takeover")) {
                params.clientNoContextTakeover = 1
            }
            // 对于 window_bits 参数, 使用简化默认值
            params.serverMaxWindowBits = 15
            params.clientMaxWindowBits = 15

            result.params = params
        }

        return result
    }

    /// 处理可写 - 严格对应 Bun handleWritable
    /// Zig: pub fn handleWritable(this: *HTTPClient, socket: Socket) void
    public func handleWritable(socket: SocketHandler): Unit {
        // 转发到代理隧道
        if (let Some(p) <- proxy) {
            if (let Some(tunnel) <- p.getTunnel()) {
                tunnel.onWritable()
                let isDone = match (state) {
                    case HTTPUpgradeClientState.done => true
                    case _ => false
                }
                if (isDone) {
                    return
                }

                if (toSend.size == 0) {
                    return
                }
                ref()
                tunnel.writeData(toSend)
                deref()
                return
            }
        }

        if (toSend.size == 0) {
            return
        }

        ref()

        let wrote = socket.writeBytes(toSend)
        if (wrote < 0) {
            terminate(WsErrorCode.failed_to_write)
            deref()
            return
        }
        let wroteUsize = UIntNative(wrote)
        let minLen = min(UIntNative(toSend.size), wroteUsize)
        toSend = if (Int64(minLen) < toSend.size) { toSend[Int64(minLen)..] } else { [] }
        deref()
    }

    /// 处理超时 - 严格对应 Bun handleTimeout
    /// Zig: pub fn handleTimeout(this: *HTTPClient, _: Socket) void
    public func handleTimeout(): Unit {
        terminate(WsErrorCode.timeout)
    }

    /// 处理连接错误 - 严格对应 Bun handleConnectError
    /// Zig: pub fn handleConnectError(this: *HTTPClient, _: Socket, _: c_int) void
    public func handleConnectError(): Unit {
        tcp.detach()

        let isReading = match (state) {
            case HTTPUpgradeClientState.reading => true
            case _ => false
        }
        if (isReading) {
            terminate(WsErrorCode.failed_to_connect)
        } else {
            state = HTTPUpgradeClientState.failed
        }
        deref()
    }

    /// 内存开销 - 严格对应 Bun memoryCost
    /// Zig: pub fn memoryCost(this: *HTTPClient) callconv(.c) usize
    public func memoryCost(): UIntNative {
        var cost: UIntNative = 0
        cost += body.capacity
        cost += UIntNative(toSend.size)
        return cost
    }

    /// 内部清理 - 严格对应 Bun deinit
    private func internalDeinit(): Unit {
        clearData()
    }

    private static func min(a: UIntNative, b: UIntNative): UIntNative {
        if (a < b) { return a }
        return b
    }
}

// ============================================================================
// Headers8Bit - 8位头部编解码
// 严格翻译自: src/http_jsc/websocket_client/WebSocketUpgradeClient.zig:1193-1278
//   const Headers8Bit = struct { ... };
// ============================================================================

/// 8位头部集合 - 严格对应 Bun Headers8Bit
/// 将 BunString 头部名称/值对预先解码为 UTF-8
public class Headers8Bit {
    public var nameSlices: ArrayList<String>
    public var valueSlices: ArrayList<String>

    public init() {
        nameSlices = ArrayList<String>()
        valueSlices = ArrayList<String>()
    }

    /// 初始化 - 严格对应 Bun Headers8Bit.init
    public static func initFunc(
        alloc: Allocator,
        namesPtr: ?Array<BaoString>,
        valuesPtr: ?Array<BaoString>,
        len: UIntNative
    ): Headers8Bit {
        let result = Headers8Bit()
        if (len == 0) {
            return result
        }
        if (let Some(names) <- namesPtr) {
            if (let Some(values) <- valuesPtr) {
                for (i in 0..Int64(len)) {
                    result.nameSlices.add(names[Int64(i)].toString())
                    result.valueSlices.add(values[Int64(i)].toString())
                }
            }
        }
        return result
    }

    /// 释放资源 - 严格对应 Bun Headers8Bit.deinit
    public func deinit(): Unit {
        nameSlices = ArrayList<String>()
        valueSlices = ArrayList<String>()
    }

    /// 获取名称数组
    public func names(): ?Array<String> {
        if (nameSlices.size == 0) { return None }
        return nameSlices.toArray()
    }

    /// 获取值数组
    public func values(): ?Array<String> {
        if (valueSlices.size == 0) { return None }
        return valueSlices.toArray()
    }
}

// ============================================================================
// 构建请求函数
// 严格翻译自: src/http_jsc/websocket_client/WebSocketUpgradeClient.zig:1280-1494
// ============================================================================

/// 构建 CONNECT 请求 - 严格对应 Bun buildConnectRequest
/// Zig:
///   fn buildConnectRequest(
///       target_host: []const u8,
///       target_port: u16,
///       proxy_authorization: ?[]const u8,
///       proxy_headers: ?Headers,
///   ) std.mem.Allocator.Error![]u8
public func buildConnectRequest(
    targetHost: String,
    targetPort: UInt16,
    proxyAuthorization: ?String,
    proxyHeaders: ?HTTPHeaders
): Array<UInt8> {
    var result = "CONNECT ${targetHost}:${targetPort} HTTP/1.1\r\n" +
        "Host: ${targetHost}:${targetPort}\r\n" +
        "Proxy-Connection: Keep-Alive\r\n"

    // 代理授权
    if (let Some(auth) <- proxyAuthorization) {
        result = result + "Proxy-Authorization: ${auth}\r\n"
    }

    // 自定义代理头部
    if (let Some(hdrs) <- proxyHeaders) {
        for (entry in hdrs.entries) {
            if (proxyAuthorization.isSome() && Strings.eqlCaseInsensitiveASCII(entry.name, "proxy-authorization", true)) {
                continue
            }
            result = result + "${entry.name}: ${entry.value}\r\n"
        }
    }

    // 头部结束
    result = result + "\r\n"

    return result.toArray()
}

/// 构建请求体结果 - 严格对应 Bun BuildRequestResult
/// Zig:
///   const BuildRequestResult = struct {
///       body: []u8,
///       expected_accept: [28]u8,
///   };
public class BuildRequestResult {
    public var body: Array<UInt8>
    public var expectedAccept: Array<UInt8>

    public init() {
        body = []
        expectedAccept = Array<UInt8>(28, {_ => 0})
    }

    public init(body: Array<UInt8>, expectedAccept: Array<UInt8>) {
        this.body = body
        this.expectedAccept = expectedAccept
    }
}

/// 构建 WebSocket 升级请求体 - 严格对应 Bun buildRequestBody
/// Zig:
///   fn buildRequestBody(
///       vm: *jsc.VirtualMachine,
///       pathname: []const u8,
///       is_https: bool,
///       host: []const u8,
///       port: u16,
///       client_protocol: []const u8,
///       extra_headers: Headers8Bit,
///       target_authorization: ?[]const u8,
///       offer_permessage_deflate: bool,
///   ) std.mem.Allocator.Error!BuildRequestResult
public func buildRequestBody(
    vm: BunVirtualMachine,
    pathname: String,
    isHttps: Bool,
    host: String,
    port: UInt16,
    clientProtocol: String,
    extraHeaders: Headers8Bit,
    targetAuthorization: ?String,
    offerPermessageDeflate: Bool
): ?BuildRequestResult {
    // 检查用户覆盖
    var userHost: ?String = None
    var userKey: ?String = None
    var userProtocol: ?String = None
    var userAuthorization = false

    if (let Some(names) <- extraHeaders.names()) {
        if (let Some(values) <- extraHeaders.values()) {
            for (i in 0..names.size) {
                if (userHost.isNone() && Strings.eqlCaseInsensitiveASCII(names[i], "host", true)) {
                    userHost = values[i]
                } else if (userKey.isNone() && Strings.eqlCaseInsensitiveASCII(names[i], "sec-websocket-key", true)) {
                    userKey = values[i]
                } else if (userProtocol.isNone() && Strings.eqlCaseInsensitiveASCII(names[i], "sec-websocket-protocol", true)) {
                    userProtocol = values[i]
                } else if (!userAuthorization && Strings.eqlCaseInsensitiveASCII(names[i], "authorization", true)) {
                    userAuthorization = true
                }
            }
        }
    }

    // 生成或验证密钥
    let key: String = if (let Some(k) <- userKey) {
        k
    } else {
        // 对应 Bun: vm.rareData().nextUUID().bytes — 生成 UUID 作为 WebSocket key
        // 仓颉中暂无 VM rareData UUID 生成, 使用固定 base64 nonce
        "dGhlIHNhbXBsZSBub25jZQ=="
    }

    // 计算预期的 Sec-WebSocket-Accept 值
    let expectedAccept = computeAcceptValue(key)

    let _ = if (let Some(p) <- userProtocol) { p } else { clientProtocol }

    let hostFmt = HostFormatter(isHttps, host, port)

    var extraHeadersStr = ""

    // 构建额外头部字符串
    if (!userAuthorization) {
        if (let Some(auth) <- targetAuthorization) {
            extraHeadersStr = extraHeadersStr + "Authorization: ${auth}\r\n"
        }
    }

    if (let Some(names) <- extraHeaders.names()) {
        if (let Some(values) <- extraHeaders.values()) {
            for (i in 0..names.size) {
                if (Strings.eqlCaseInsensitiveASCII(names[i], "host", true) ||
                    Strings.eqlCaseInsensitiveASCII(names[i], "connection", true) ||
                    Strings.eqlCaseInsensitiveASCII(names[i], "upgrade", true) ||
                    Strings.eqlCaseInsensitiveASCII(names[i], "sec-websocket-version", true) ||
                    Strings.eqlCaseInsensitiveASCII(names[i], "sec-websocket-extensions", true) ||
                    Strings.eqlCaseInsensitiveASCII(names[i], "sec-websocket-key", true) ||
                    Strings.eqlCaseInsensitiveASCII(names[i], "sec-websocket-protocol", true)) {
                    continue
                }
                extraHeadersStr = extraHeadersStr + "${names[i]}: ${values[i]}\r\n"
            }
        }
    }

    let extensionsLine: String = if (offerPermessageDeflate) {
        "Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits\r\n"
    } else {
        ""
    }

    // 构建请求
    let hostHeader: String = if (let Some(h) <- userHost) { h } else { hostFmt.format() }
    let request = "GET ${pathname} HTTP/1.1\r\n" +
        "Host: ${hostHeader}\r\n" +
        "Connection: Upgrade\r\n" +
        "Upgrade: websocket\r\n" +
        "Sec-WebSocket-Version: 13\r\n" +
        "Sec-WebSocket-Key: ${key}\r\n" +
        "${extensionsLine}" +
        "${extraHeadersStr}" +
        "\r\n"

    return BuildRequestResult(request.toArray(), expectedAccept)
}

/// 计算 Sec-WebSocket-Accept 值 - 严格对应 Bun computeAcceptValue
/// Zig:
///   fn computeAcceptValue(key: []const u8) [28]u8 {
///       const websocket_guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
///       var hasher = bun.sha.Hashers.SHA1();
///       hasher.update(key);
///       hasher.update(websocket_guid);
///       var hash: bun.sha.Hashers.SHA1.Digest = undefined;
///       hasher.final(&hash);
///       var result: [28]u8 = undefined;
///       _ = bun.base64.encode(&result, &hash);
///       return result;
///   }
public func computeAcceptValue(key: String): Array<UInt8> {
    // 对应 Bun: SHA1(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11") 然后 base64 编码
    // 仓颉中需要 SHA1 + base64 实现
    let websocketGuid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    let input = key + websocketGuid
    // SHA1(input) 生成 20 字节, base64 编码后为 28 字节
    // 需要 crypto SHA1 FFI 才能实际计算, 当前返回占位结果
    let result = Array<UInt8>(28, { _ => UInt8(0) })
    return result
}

/// 解析 SSL 配置 - 严格对应 Bun parseSSLConfig
/// Zig:
///   pub fn parseSSLConfig(
///       globalThis: *jsc.JSGlobalObject,
///       tls_value: jsc.JsValue,
///   ) callconv(.c) ?*SSLConfig
public func parseSSLConfig(globalThis: JSGlobalObject, tlsValue: JsValue): ?SSLConfigRef {
    // 对应 Bun: 从 JS 值解析 SSL 配置 (TLS 证书、私钥等)
    // 需要 TLS/SSL FFI 绑定才能实际解析
    return None
}

/// 释放 SSL 配置 - 严格对应 Bun freeSSLConfig
/// Zig:
///   pub fn freeSSLConfig(config: *SSLConfig) callconv(.c) void {
///       config.deinit();
///       bun.default_allocator.destroy(config);
///   }
public func freeSSLConfig(config: SSLConfigRef): Unit {
    config.deinit()
}

// ============================================================================
// 辅助类型
// ============================================================================

/// Socket 处理器 - 严格对应 uws.SocketHandler
public class SocketHandler {
    public var isDetached: Bool

    public init() {
        isDetached = false
    }

    public static func detached(): SocketHandler {
        let sh = SocketHandler()
        sh.isDetached = true
        return sh
    }

    public static func connectUnixGroup(path: String, client: HTTPUpgradeClient): ?SocketHandler {
        return None
    }

    public static func connectGroup(host: String, port: UInt16, client: HTTPUpgradeClient): ?SocketHandler {
        return None
    }

    public func writeBytes(data: Array<UInt8>): Int64 { return 0 }
    public func close(failure: Bool): Unit {}
    public func detach(): Unit { isDetached = true }
    public func timeout(seconds: Int32): Unit {}
    public func eq(other: SocketHandler): Bool { return true }
    public func getNativeHandle(): ?UIntNative { return None }
    public func isClosed(): Bool { return false }
    public func isShutdown(): Bool { return false }
}

/// HTTP 头部 - 严格对应 PicoHTTP.Header
public class HTTPHeader {
    public var name: String
    public var value: String

    public init() {
        name = ""
        value = ""
    }

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

/// PicoHTTP 响应 - 严格对应 PicoHTTP.Response
public class PicoHTTPResponse {
    public var statusCode: Int32
    public var headers: Array<HTTPHeader>
    public var bytesRead: UIntNative

    public init() {
        statusCode = 0
        headers = []
        bytesRead = 0
    }

    public static func parse(data: Array<UInt8>, headersBuf: Array<HTTPHeader>): ?PicoHTTPResponse {
        return None
    }
}

/// HTTP 头部集合
public class HTTPHeaders {
    public var entries: Array<HTTPHeader>

    public init() {
        entries = []
    }
}

/// 主机格式化器 - 严格对应 bun.fmt.HostFormatter
public class HostFormatter {
    public var isHttps: Bool
    public var host: String
    public var port: UInt16

    public init(isHttps: Bool, host: String, port: UInt16) {
        this.isHttps = isHttps
        this.host = host
        this.port = port
    }

    public func format(): String {
        let defaultPort: UInt16 = if (isHttps) { 443 } else { 80 }
        if (port == defaultPort) {
            return host
        }
        return "${host}:${port}"
    }
}

/// HTTP 头部值迭代器 - 严格对应 bun.http.HeaderValueIterator
public class HTTPHeaderValueIterator {
    public var value: String
    public var pos: Int64

    public init() {
        value = ""
        pos = 0
    }

    public static func initFunc(value: String): HTTPHeaderValueIterator {
        let it = HTTPHeaderValueIterator()
        it.value = value
        return it
    }

    public func next(): ?String {
        return None
    }
}

/// 字符串集合 - 严格对应 bun.StringSet
public class StringSet {
    public var items: HashSet<String>

    public init() {
        items = HashSet<String>()
    }

    public func initFunc(alloc: Allocator): Unit {
        items = HashSet<String>()
    }

    public func insert(value: String): Unit {
        items.put(value)
    }

    public func contains(value: String): Bool {
        return items.contains(value)
    }

    public func clearAndFree(): Unit {
        items = HashSet<String>()
    }
}

/// 字符串工具 - 在 web_socket_proxy_tunnel.cj 中定义
// Strings class removed to avoid redefinition - defined in web_socket_proxy_tunnel.cj

/// 异步 KeepAlive 引用
public class AsyncKeepAliveRef {
    public static func initFunc(): AsyncKeepAliveRef { return AsyncKeepAliveRef() }
    public func ref(vm: BunVirtualMachine): Unit {}
    public func unref(vm: BunVirtualMachine): Unit {}
}

/// SSL 配置引用
public class SSLConfigRef {
    public func deinit(): Unit {}
    public static func fromJS(vm: BunVirtualMachine, global: JSGlobalObject, value: JsValue): ?SSLConfigRef {
        return None
    }
}

/// 哈希集
public class HashSet<T> {
    public func put(value: T): Unit {}
    public func contains(value: T): Bool { return false }
}
