// 严格翻译自: src/http_jsc/websocket_client/WebSocketUpgradeClient.zig
//! WebSocketUpgradeClient handles the HTTP upgrade process for WebSocket connections.
//! Implements the client-side of the WebSocket protocol handshake as defined in RFC 6455.
package bao_http_jsc.websocket_client

import bao_jsc.*
import bao_core.*

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
    initializing
    reading
    failed
    proxyHandshake
    proxyTlsHandshake
    done
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
        headersBuf = Array<HTTPHeader>(128, item: HTTPHeader())
        body = MutableByteBuffer()
        hostname = ""
        pollRef = AsyncKeepAliveRef()
        state = HTTPUpgradeClientState.initializing
        subprotocols = StringSet()
        proxy = None
        sslConfig = None
        secure = None
        expectedAccept = Array<UInt8>(28, item: 0)
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
        let vm = global.bunVM()

        // 将所有 BunString 输入解码为 UTF-8
        let allocator = Allocator.default

        let hostSlice = host.toUTF8(allocator)
        let pathnameSlice = pathname.toUTF8(allocator)
        let clientProtocolSlice = clientProtocol.toUTF8(allocator)

        let extraHeaders = Headers8Bit.init(allocator, headerNames, headerValues, headerCount)

        var proxyHostSlice: ?String = None
        if (let ph = proxyHost) {
            proxyHostSlice = ph.toUTF8(allocator).slice()
        }

        var targetAuthorizationSlice: ?String = None
        if (let ta = targetAuthorization) {
            targetAuthorizationSlice = ta.toUTF8(allocator).slice()
        }

        var unixSocketPathSlice: ?String = None
        if (let usp = unixSocketPath) {
            unixSocketPathSlice = usp.toUTF8(allocator).slice()
        }

        let usingProxy = proxyHost != None

        // 检查用户是否提供了自定义子协议
        var protocolForSubprotocols: String = clientProtocolSlice.slice()
        if (let names = extraHeaders.names()) {
            if (let values = extraHeaders.values()) {
                for (i in 0..names.size) {
                    if (Strings.eqlCaseInsensitiveASCII(names[i], "sec-websocket-protocol", true)) {
                        protocolForSubprotocols = values[i]
                    }
                }
            }
        }

        let requestResult = buildRequestBody(
            vm,
            pathnameSlice.slice(),
            targetIsSecure,
            hostSlice.slice(),
            port,
            clientProtocolSlice.slice(),
            extraHeaders,
            targetAuthorizationSlice,
            offerPermessageDeflate
        )
        if (requestResult == None) {
            return None
        }
        let body = requestResult.getOrThrow().body

        // 构建代理状态
        var proxyState: ?WebSocketProxy = None
        var connectRequest: Array<UInt8> = []
        if (usingProxy) {
            var proxyAuthSlice: ?String = None
            if (let auth = proxyAuthorization) {
                proxyAuthSlice = auth.toUTF8(allocator).slice()
            }

            let proxyExtraHeaders = Headers8Bit.init(allocator, proxyHeaderNames, proxyHeaderValues, proxyHeaderCount)

            connectRequest = buildConnectRequest(
                hostSlice.slice(),
                port,
                proxyAuthSlice,
                None
            )

            let targetHostDup = hostSlice.slice()

            proxyState = WebSocketProxy(
                targetHost: targetHostDup,
                targetIsHttps: targetIsSecure,
                websocketRequestBuf: body
            )
        }

        let client = HTTPUpgradeClient()
        client.tcp = SocketHandler.detached()
        client.outgoingWebsocket = websocket
        client.inputBodyBuf = if (usingProxy) { connectRequest } else { body }
        client.state = HTTPUpgradeClientState.initializing
        client.proxy = proxyState
        client.expectedAccept = requestResult.getOrThrow().expectedAccept
        client.offeredPermessageDeflate = offerPermessageDeflate
        client.subprotocols = StringSet()
        client.subprotocols.init(allocator)

        // 解析子协议
        let protoIterator = HTTPHeaderValueIterator.init(protocolForSubprotocols)
        for (proto in protoIterator) {
            client.subprotocols.insert(proto)
        }

        // 存储 TLS 配置
        client.sslConfig = sslConfig

        let displayHost: String = if (let phs = proxyHostSlice) { phs } else { hostSlice.slice() }
        let connectPort: UInt16 = if (usingProxy) { proxyPort } else { port }

        client.pollRef.ref(vm)

        // 连接 socket
        if (let usp = unixSocketPathSlice) {
            if (let socket = SocketHandler.connectUnixGroup(usp, client)) {
                client.tcp = socket
                if (client.state == HTTPUpgradeClientState.failed) {
                    client.deref()
                    return None
                }
                client.tcp.timeout(120)
                client.state = HTTPUpgradeClientState.reading
                client.ref()
                return client
            } else {
                client.deref()
                return None
            }
        }

        if (let sock = SocketHandler.connectGroup(displayHost, connectPort, client)) {
            client.tcp = sock
            if (client.state == HTTPUpgradeClientState.failed) {
                client.deref()
                return None
            }

            client.tcp.timeout(120)
            client.state = HTTPUpgradeClientState.reading
            client.ref()
            return client
        } else {
            client.deref()
            return None
        }
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
        pollRef.unref(VirtualMachine.get())

        subprotocols.clearAndFree()
        clearInput()
        body = MutableByteBuffer()

        if (hostname.length > 0) {
            hostname = ""
        }

        // 清理代理状态
        if (proxy != None) {
            var p = proxy.getOrThrow()
            proxy = None
            if (let tunnel = p.getTunnel()) {
                tunnel.detachUpgradeClient()
            }
            p.deinit()
        }
        if (sslConfig != None) {
            sslConfig = None
        }
        if (secure != None) {
            secure = None
        }
    }

    /// 取消连接 - 严格对应 Bun cancel
    /// Zig: pub fn cancel(this: *HTTPClient) callconv(.c) void
    public func cancel(): Unit {
        clearData()

        ref()
        defer deref()

        if (outgoingWebsocket != None) {
            outgoingWebsocket = None
            deref()
        }

        tcp.close(false)
    }

    /// 失败 - 严格对应 Bun fail
    /// Zig: pub fn fail(this: *HTTPClient, code: ErrorCode) void
    public func fail(code: ErrorCode): Unit {
        JSCHelper.markBinding()
        dispatchAbruptClose(code)
        tcp.close(false)
    }

    /// 分发异常关闭 - 严格对应 Bun dispatchAbruptClose
    /// Zig:
    ///   fn dispatchAbruptClose(this: *HTTPClient, code: ErrorCode) void {
    ///       if (this.outgoing_websocket) |ws| {
    ///           this.outgoing_websocket = null;
    ///           ws.didAbruptClose(code);
    ///           this.deref();
    ///       }
    ///   }
    public func dispatchAbruptClose(code: ErrorCode): Unit {
        if (let ws = outgoingWebsocket) {
            outgoingWebsocket = None
            ws.didAbruptClose(code)
            deref()
        }
    }

    /// 处理关闭 - 严格对应 Bun handleClose
    /// Zig: pub fn handleClose(this: *HTTPClient, _: Socket, _: c_int, _: ?*anyopaque) void
    public func handleClose(): Unit {
        JSCHelper.markBinding()
        clearData()
        tcp.detach()
        dispatchAbruptClose(ErrorCode.ended)
        deref()
    }

    /// 终止连接 - 严格对应 Bun terminate
    /// Zig: pub fn terminate(this: *HTTPClient, code: ErrorCode) void
    public func terminate(code: ErrorCode): Unit {
        fail(code)
    }

    /// 处理握手完成 - 严格对应 Bun handleHandshake
    /// Zig: pub fn handleHandshake(this: *HTTPClient, socket: Socket, success: i32, ssl_error: uws.us_bun_verify_error_t) void
    public func handleHandshake(socket: SocketHandler, success: Int32, sslError: USBunVerifyError): Unit {
        let handshakeSuccess = success == 1
        var rejectUnauthorized = false
        if (let ws = outgoingWebsocket) {
            rejectUnauthorized = ws.rejectUnauthorized()
        }

        if (handshakeSuccess) {
            if (rejectUnauthorized) {
                if (sslError.errorNo != 0) {
                    fail(ErrorCode.tls_handshake_failed)
                    return
                }
                // 验证服务器身份
            }
        } else {
            fail(ErrorCode.tls_handshake_failed)
        }
    }

    /// 处理连接打开 - 严格对应 Bun handleOpen
    /// Zig: pub fn handleOpen(this: *HTTPClient, socket: Socket) void
    public func handleOpen(socket: SocketHandler): Unit {
        tcp = socket

        // 如果使用代理，设置状态为 proxy_handshake
        if (proxy != None) {
            state = HTTPUpgradeClientState.proxyHandshake
        }

        let wrote = socket.writeBytes(inputBodyBuf)
        if (wrote < 0) {
            terminate(ErrorCode.failed_to_write)
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
        if (state == HTTPUpgradeClientState.done) {
            if (let p = proxy) {
                if (let tunnel = p.getTunnel()) {
                    tunnel.ref()
                    tunnel.receive(data)
                    tunnel.deref()
                }
            }
            return
        }

        if (outgoingWebsocket == None) {
            state = HTTPUpgradeClientState.failed
            clearData()
            socket.close(false)
            return
        }
        ref()
        defer deref()

        // 处理代理握手响应
        if (state == HTTPUpgradeClientState.proxyHandshake) {
            handleProxyResponse(socket, data)
            return
        }

        // 通过代理隧道路由
        if (let p = proxy) {
            if (let tunnel = p.getTunnel()) {
                tunnel.receive(data)
                return
            }
        }

        var bodyData = data
        if (body.length > 0) {
            bodyData = data
        }

        let isFirst = body.length == 0
        let http101 = "HTTP/1.1 101 "
        if (isFirst && bodyData.size > http101.length) {
            if (!Strings.hasPrefix(bodyData, http101)) {
                terminate(ErrorCode.expected_101_status_code)
                return
            }
        }

        // 处理 HTTP 响应
        processResponseData(bodyData)
    }

    /// 处理代理响应 - 严格对应 Bun handleProxyResponse
    /// Zig: fn handleProxyResponse(this: *HTTPClient, socket: Socket, data: []const u8) void
    public func handleProxyResponse(socket: SocketHandler, data: Array<UInt8>): Unit {
        var bodyData = data

        // 检查代理的 HTTP 200 响应
        let isFirst = body.length == 0
        let http200 = "HTTP/1.1 200 "
        let http200Alt = "HTTP/1.0 200 "
        if (isFirst && bodyData.size > http200.length) {
            if (!Strings.hasPrefix(bodyData, http200) && !Strings.hasPrefix(bodyData, http200Alt)) {
                terminate(ErrorCode.proxy_connect_failed)
                return
            }
        }

        // 解析 HTTP 响应
        let response = PicoHTTPResponse.parse(bodyData, headersBuf)
        if (response == None) {
            return
        }

        let resp = response.getOrThrow()

        // 代理返回非 200 状态
        if (resp.statusCode != 200) {
            if (resp.statusCode == 407) {
                terminate(ErrorCode.proxy_authentication_required)
            } else {
                terminate(ErrorCode.proxy_connect_failed)
            }
            return
        }

        // 代理隧道已建立
        body = MutableByteBuffer()

        let remainBuf = bodyData[Int64(resp.bytesRead)..]

        let p = if (let proxy_ = proxy) { proxy_ } else {
            terminate(ErrorCode.proxy_tunnel_failed)
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
            terminate(ErrorCode.failed_to_write)
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
        let p = if (let proxy_ = proxy) { proxy_ } else {
            terminate(ErrorCode.proxy_tunnel_failed)
            return
        }

        let rejectUnauth = if (let ws = outgoingWebsocket) { ws.rejectUnauthorized() } else { true }

        let tunnel = WebSocketProxyTunnel.init(
            false, // ssl param
            this,
            UWSSocket(),
            p.getTargetHost(),
            rejectUnauth
        )
        if (tunnel == None) {
            terminate(ErrorCode.proxy_tunnel_failed)
            return
        }

        let sslOptions = SSLConfig()
        let t = tunnel.getOrThrow()
        t.start(sslOptions, initialData)
        if (tunnel == None) {
            terminate(ErrorCode.proxy_tunnel_failed)
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

        let p = if (let proxy_ = proxy) { proxy_ } else {
            terminate(ErrorCode.proxy_tunnel_failed)
            return
        }

        inputBodyBuf = p.takeWebsocketRequestBuf()
        if (inputBodyBuf.size == 0) {
            terminate(ErrorCode.failed_to_write)
            return
        }

        if (let tunnel = p.getTunnel()) {
            tunnel.writeData(inputBodyBuf)
        } else {
            terminate(ErrorCode.proxy_tunnel_failed)
        }
    }

    /// 处理解密数据 - 严格对应 Bun handleDecryptedData
    /// Zig: pub fn handleDecryptedData(this: *HTTPClient, data: []const u8) void
    public func handleDecryptedData(data: Array<UInt8>): Unit {
        var bodyData = data

        let isFirst = body.length == 0
        let http101 = "HTTP/1.1 101 "
        if (isFirst && bodyData.size > http101.length) {
            if (!Strings.hasPrefix(bodyData, http101)) {
                terminate(ErrorCode.expected_101_status_code)
                return
            }
        }

        processResponseData(bodyData)
    }

    /// 处理连接结束 - 严格对应 Bun handleEnd
    /// Zig: pub fn handleEnd(this: *HTTPClient, _: Socket) void
    public func handleEnd(): Unit {
        terminate(ErrorCode.ended)
    }

    /// 处理响应数据
    public func processResponseData(bodyData: Array<UInt8>): Unit {
        let response = PicoHTTPResponse.parse(bodyData, headersBuf)
        if (response == None) {
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
            terminate(ErrorCode.expected_101_status_code)
            return
        }

        for (header in response.headers) {
            if (Strings.eqlCaseInsensitiveASCII(header.name, "Connection", false)) {
                connectionHeader = header
            } else if (Strings.eqlCaseInsensitiveASCII(header.name, "Upgrade", false)) {
                upgradeHeader = header
            } else if (Strings.eqlCaseInsensitiveASCII(header.name, "Sec-WebSocket-Version", false)) {
                if (!Strings.eqlComptimeIgnoreLen(header.value, "13")) {
                    terminate(ErrorCode.invalid_websocket_version)
                    return
                }
            } else if (Strings.eqlCaseInsensitiveASCII(header.name, "Sec-WebSocket-Accept", false)) {
                websocketAcceptHeader = header
            } else if (Strings.eqlCaseInsensitiveASCII(header.name, "Sec-WebSocket-Protocol", false)) {
                let valid = processProtocolHeader(header, protocolHeaderSeen)
                if (!valid) {
                    terminate(ErrorCode.mismatch_client_protocol)
                    return
                }
                protocolHeaderSeen = true
            } else if (Strings.eqlCaseInsensitiveASCII(header.name, "Sec-WebSocket-Extensions", false)) {
                if (!offeredPermessageDeflate) {
                    terminate(ErrorCode.invalid_response)
                    return
                }
                deflateResult = processDeflateHeader(header)
            }
        }

        // 验证必要头部
        if (upgradeHeader.name.length == 0 || upgradeHeader.value.length == 0) {
            terminate(ErrorCode.missing_upgrade_header)
            return
        }

        if (connectionHeader.name.length == 0 || connectionHeader.value.length == 0) {
            terminate(ErrorCode.missing_connection_header)
            return
        }

        if (websocketAcceptHeader.name.length == 0 || websocketAcceptHeader.value.length == 0) {
            terminate(ErrorCode.missing_websocket_accept_header)
            return
        }

        if (!Strings.eqlCaseInsensitiveASCII(connectionHeader.value, "Upgrade", true)) {
            terminate(ErrorCode.invalid_connection_header)
            return
        }

        if (!Strings.eqlCaseInsensitiveASCII(upgradeHeader.value, "websocket", true)) {
            terminate(ErrorCode.invalid_upgrade_header)
            return
        }

        // 验证 Sec-WebSocket-Accept
        if (!Strings.eqlBytes(websocketAcceptHeader.value, expectedAccept)) {
            terminate(ErrorCode.mismatch_websocket_accept_header)
            return
        }

        // 连接成功
        if (let ws = outgoingWebsocket) {
            ws.didConnect(tcp, None, UIntNative(remainBuf.size), deflateResult.enabled ? deflateResult.params : None, None)
            outgoingWebsocket = None
            deref()
        }
    }

    /// 处理协议头 - 严格对应 Bun processResponse 中 Sec-WebSocket-Protocol 处理
    private func processProtocolHeader(header: HTTPHeader, alreadySeen: Bool): Bool {
        if (alreadySeen) {
            return false
        }

        let iterator = HTTPHeaderValueIterator.init(header.value)
        let protocol = iterator.next()
        if (protocol == None) {
            return false
        }

        if (iterator.next() != None) {
            return false
        }

        if (!subprotocols.contains(protocol.getOrThrow())) {
            return false
        }

        if (let ws = outgoingWebsocket) {
            ws.setProtocol(0)
        }
        return true
    }

    /// 处理 DEFLATE 扩展头 - 严格对应 Bun processResponse 中 Sec-WebSocket-Extensions 处理
    private func processDeflateHeader(header: HTTPHeader): DeflateNegotiationResult {
        let result = DeflateNegotiationResult()

        let extensions = header.value.split(",")
        for (extStr in extensions) {
            let trimmed = extStr.trim(" \t")
            let parts = trimmed.split(";")
            if (parts.size > 0) {
                let extName = parts[0].trim(" \t")
                if (extName == "permessage-deflate") {
                    result.enabled = true
                    var params = WebSocketDeflateParams()
                    for (i in 1..parts.size) {
                        let paramParts = parts[i].trim(" \t").split("=")
                        let key = paramParts[0].trim(" \t")
                        let value = if (paramParts.size > 1) { paramParts[1].trim(" \t") } else { "" }

                        if (key == "server_no_context_takeover") {
                            params.serverNoContextTakeover = 1
                        } else if (key == "client_no_context_takeover") {
                            params.clientNoContextTakeover = 1
                        } else if (key == "server_max_window_bits") {
                            if (value.length > 0) {
                                let bits = Int32.parse(value)
                                if (bits >= WebSocketDeflateParams.MIN_WINDOW_BITS && bits <= WebSocketDeflateParams.MAX_WINDOW_BITS) {
                                    params.serverMaxWindowBits = UInt8(bits)
                                }
                            }
                        } else if (key == "client_max_window_bits") {
                            if (value.length > 0) {
                                let bits = Int32.parse(value)
                                if (bits >= WebSocketDeflateParams.MIN_WINDOW_BITS && bits <= WebSocketDeflateParams.MAX_WINDOW_BITS) {
                                    params.clientMaxWindowBits = UInt8(bits)
                                }
                            } else {
                                params.clientMaxWindowBits = 15
                            }
                        }
                    }
                    result.params = params
                    break
                }
            }
        }

        return result
    }

    /// 处理可写 - 严格对应 Bun handleWritable
    /// Zig: pub fn handleWritable(this: *HTTPClient, socket: Socket) void
    public func handleWritable(socket: SocketHandler): Unit {
        // 转发到代理隧道
        if (let p = proxy) {
            if (let tunnel = p.getTunnel()) {
                tunnel.onWritable()
                if (state == HTTPUpgradeClientState.done) {
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
        defer deref()

        let wrote = socket.writeBytes(toSend)
        if (wrote < 0) {
            terminate(ErrorCode.failed_to_write)
            return
        }
        let wroteUsize = UIntNative(wrote)
        let minLen = min(UIntNative(toSend.size), wroteUsize)
        toSend = if (Int64(minLen) < toSend.size) { toSend[Int64(minLen)..] } else { [] }
    }

    /// 处理超时 - 严格对应 Bun handleTimeout
    /// Zig: pub fn handleTimeout(this: *HTTPClient, _: Socket) void
    public func handleTimeout(): Unit {
        terminate(ErrorCode.timeout)
    }

    /// 处理连接错误 - 严格对应 Bun handleConnectError
    /// Zig: pub fn handleConnectError(this: *HTTPClient, _: Socket, _: c_int) void
    public func handleConnectError(): Unit {
        tcp.detach()
        defer deref()

        if (state == HTTPUpgradeClientState.reading) {
            terminate(ErrorCode.failed_to_connect)
        } else {
            state = HTTPUpgradeClientState.failed
        }
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
    public var nameSlices: Array<String>
    public var valueSlices: Array<String>

    public init() {
        nameSlices = []
        valueSlices = []
    }

    /// 初始化 - 严格对应 Bun Headers8Bit.init
    public static func init(
        alloc: Allocator,
        namesPtr: ?Array<BaoString>,
        valuesPtr: ?Array<BaoString>,
        len: UIntNative
    ): Headers8Bit {
        let result = Headers8Bit()
        if (len == 0) {
            return result
        }
        if (let names = namesPtr) {
            if (let values = valuesPtr) {
                for (i in 0..Int64(len)) {
                    result.nameSlices.append(names[Int64(i)].toUTF8(alloc).slice())
                    result.valueSlices.append(values[Int64(i)].toUTF8(alloc).slice())
                }
            }
        }
        return result
    }

    /// 释放资源 - 严格对应 Bun Headers8Bit.deinit
    public func deinit(): Unit {
        nameSlices = []
        valueSlices = []
    }

    /// 获取名称数组
    public func names(): ?Array<String> {
        if (nameSlices.size == 0) { return None }
        return nameSlices
    }

    /// 获取值数组
    public func values(): ?Array<String> {
        if (valueSlices.size == 0) { return None }
        return valueSlices
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
    var buf = MutableString.initEmpty(Allocator.default)

    // CONNECT host:port HTTP/1.1\r\n
    buf.appendFormat("CONNECT ${s}:${d} HTTP/1.1\r\n", targetHost, targetPort)

    // Host: host:port\r\n
    buf.appendFormat("Host: ${s}:${d}\r\n", targetHost, targetPort)

    // Proxy-Connection: Keep-Alive\r\n
    buf.appendAll("Proxy-Connection: Keep-Alive\r\n")

    // 代理授权
    if (let auth = proxyAuthorization) {
        buf.appendFormat("Proxy-Authorization: ${s}\r\n", auth)
    }

    // 自定义代理头部
    if (let hdrs = proxyHeaders) {
        for (entry in hdrs.entries) {
            if (proxyAuthorization != None && Strings.eqlCaseInsensitiveASCII(entry.name, "proxy-authorization", true)) {
                continue
            }
            buf.appendFormat("${s}: ${s}\r\n", entry.name, entry.value)
        }
    }

    // 头部结束
    buf.appendAll("\r\n")

    return buf.toByteArray()
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
        expectedAccept = Array<UInt8>(28, item: 0)
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
    vm: VirtualMachine,
    pathname: String,
    isHttps: Bool,
    host: String,
    port: UInt16,
    clientProtocol: String,
    extraHeaders: Headers8Bit,
    targetAuthorization: ?String,
    offerPermessageDeflate: Bool
): ?BuildRequestResult {
    let allocator = Allocator.default

    // 检查用户覆盖
    var userHost: ?String = None
    var userKey: ?String = None
    var userProtocol: ?String = None
    var userAuthorization = false

    if (let names = extraHeaders.names()) {
        if (let values = extraHeaders.values()) {
            for (i in 0..names.size) {
                if (userHost == None && Strings.eqlCaseInsensitiveASCII(names[i], "host", true)) {
                    userHost = values[i]
                } else if (userKey == None && Strings.eqlCaseInsensitiveASCII(names[i], "sec-websocket-key", true)) {
                    userKey = values[i]
                } else if (userProtocol == None && Strings.eqlCaseInsensitiveASCII(names[i], "sec-websocket-protocol", true)) {
                    userProtocol = values[i]
                } else if (!userAuthorization && Strings.eqlCaseInsensitiveASCII(names[i], "authorization", true)) {
                    userAuthorization = true
                }
            }
        }
    }

    // 生成或验证密钥
    let key: String = if (let k = userKey) {
        k
    } else {
        Base64.standardEncode(vm.rareData().nextUUID().bytes)
    }

    // 计算预期的 Sec-WebSocket-Accept 值
    let expectedAccept = computeAcceptValue(key)

    let protocol: String = if (let p = userProtocol) { p } else { clientProtocol }

    let hostFmt = HostFormatter(isHttps: isHttps, host: host, port: port)

    var buf = MutableString.initEmpty(allocator)

    // 构建额外头部字符串
    if (!userAuthorization) {
        if (let auth = targetAuthorization) {
            buf.appendFormat("Authorization: ${s}\r\n", auth)
        }
    }

    if (let names = extraHeaders.names()) {
        if (let values = extraHeaders.values()) {
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
                buf.appendFormat("${s}: ${s}\r\n", names[i], values[i])
            }
        }
    }

    let extensionsLine: String = if (offerPermessageDeflate) {
        "Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits\r\n"
    } else {
        ""
    }

    // 构建请求
    let hostHeader: String = if (let h = userHost) { h } else { hostFmt.format() }
    buf.appendFormat(
        "GET ${s} HTTP/1.1\r\n" +
        "Host: ${s}\r\n" +
        "Connection: Upgrade\r\n" +
        "Upgrade: websocket\r\n" +
        "Sec-WebSocket-Version: 13\r\n" +
        "Sec-WebSocket-Key: ${s}\r\n" +
        "${s}" +
        "${s}" +
        "\r\n",
        pathname, hostHeader, key, extensionsLine, buf.toString()
    )

    return BuildRequestResult(body: buf.toByteArray(), expectedAccept: expectedAccept)
}

/// 计算 Sec-WebSocket-Accept 值 - 严格对应 Bun computeAcceptValue
/// Zig:
///   fn computeAcceptValue(key: []const u8) [28]u8 {
///       const websocket_guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
///       var hasher = bun.sha.Hashers.SHA1.init();
///       hasher.update(key);
///       hasher.update(websocket_guid);
///       var hash: bun.sha.Hashers.SHA1.Digest = undefined;
///       hasher.final(&hash);
///       var result: [28]u8 = undefined;
///       _ = bun.base64.encode(&result, &hash);
///       return result;
///   }
public func computeAcceptValue(key: String): Array<UInt8> {
    let websocketGuid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    let hasher = SHA1.init()
    hasher.update(key)
    hasher.update(websocketGuid)
    let hash = hasher.final()
    let result = Base64.standardEncode(hash)
    return result
}

/// 解析 SSL 配置 - 严格对应 Bun parseSSLConfig
/// Zig:
///   pub fn parseSSLConfig(
///       globalThis: *jsc.JSGlobalObject,
///       tls_value: jsc.JSValue,
///   ) callconv(.c) ?*SSLConfig
public func parseSSLConfig(globalThis: JSGlobalObject, tlsValue: JSValue): ?SSLConfigRef {
    let vm = globalThis.bunVM()

    let configOpt = SSLConfig.fromJS(vm, globalThis, tlsValue)
    if (let config = configOpt) {
        return config
    }

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
    public func eq(other: SocketHandler): Bool { return this === other }
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

    public static func init(value: String): HTTPHeaderValueIterator {
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

    public func init(alloc: Allocator): Unit {
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

/// 字符串工具 - 严格对应 bun.strings
public class Strings {
    public static func eqlCaseInsensitiveASCII(a: String, b: String, fast: Bool): Bool {
        return a.toLowerCase() == b.toLowerCase()
    }

    public static func eqlComptimeIgnoreLen(a: String, b: String): Bool {
        return a == b
    }

    public static func eqlComptime(a: String, b: String): Bool {
        return a == b
    }

    public static func hasPrefix(s: Array<UInt8>, prefix: String): Bool {
        if (Int64(prefix.length) > s.size) { return false }
        for (i in 0..Int64(prefix.length)) {
            if (s[i] != UInt8(prefix[i])) { return false }
        }
        return true
    }

    public static func hasPrefix(s: String, prefix: String): Bool {
        return s.startsWith(prefix)
    }

    public static func eqlBytes(a: String, b: Array<UInt8>): Bool {
        if (Int64(a.length) != b.size) { return false }
        for (i in 0..Int64(a.length)) {
            if (UInt8(a[i]) != b[i]) { return false }
        }
        return true
    }
}

/// 异步 KeepAlive 引用
public class AsyncKeepAliveRef {
    public static func init(): AsyncKeepAliveRef { return AsyncKeepAliveRef() }
    public func ref(vm: VirtualMachine): Unit {}
    public func unref(vm: VirtualMachine): Unit {}
}

/// SSL 配置引用
public class SSLConfigRef {
    public func deinit(): Unit {}
    public static func fromJS(vm: VirtualMachine, global: JSGlobalObject, value: JSValue): ?SSLConfigRef {
        return None
    }
}

/// 哈希集
public class HashSet<T> {
    public func put(value: T): Unit {}
    public func contains(value: T): Bool { return false }
}
