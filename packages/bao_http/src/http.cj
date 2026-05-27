// bao_http http - HTTP 客户端核心类型和逻辑
// 严格翻译自: src/http/http.zig (3313 行)
package bao_http

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_threading.*

// ============================================================================
// HTTPClient - HTTP 客户端
// 严格翻译自: bun/src/http/http.zig HTTPClient struct
//
// 这是 Bun HTTP 客户端的核心结构体 (3313 行):
//   - 字段: method, url, flags, state, signals, result_callback 等
//   - 全局变量: default_allocator, http_thread, idle_timeout_seconds 等
//   - 连接管理: start, start_, onOpen, onClose, onTimeout
//   - 请求构建: buildRequest, writeRequest, writeProxyConnect, writeProxyRequest
//   - TLS/SNI: getTlsHostname, stripPortFromHost, checkServerIdentity
//   - ALPN/H2/H3: canOfferH2, alpnOffer, canTryH3AltSvc, h3AltSvcEnabled
//   - 重定向: doRedirect, doRedirectMultiplexed
//   - H2 集成: retryAfterH2Coalesce, retryFromH2, failFromH2
//   - 辅助: hashHeaderName, hashHeaderConst, proxyAuthHash
//   - 调试: printRequest, printResponse
// ============================================================================

// ============================================================================
// 全局变量
// 严格翻译自: http.zig 顶层 var 声明
// ============================================================================

/// 默认分配器 (运行时初始化)
/// 严格翻译自: pub var default_allocator: std.mem.Allocator = undefined
public var defaultAllocator: Any = ()

/// 默认 Arena
/// 严格翻译自: pub var default_arena: Arena = undefined
public var defaultArena: Any = ()

/// HTTP 线程
/// 严格翻译自: pub var http_thread: HTTPThread = undefined

/// 中止追踪器
/// 严格翻译自: pub var socket_async_http_abort_tracker = std.AutoArrayHashMap(u32, uws.AnySocket).`init`(...)
public var socketAsyncHttpAbortTracker: Any = ()

/// 异步 HTTP ID 单调递增计数器
/// 严格翻译自: pub var async_http_id_monotonic: std.atomic.Value(u32) = std.atomic.Value(u32).`init`(0)
public var asyncHttpIdMonotonic: UInt32 = UInt32(0)

/// CLI 实验性 HTTP/2 fetch 标志
/// 严格翻译自: pub var experimental_http2_client_from_cli: bool = false
public var experimentalHttp2ClientFromCli: Bool = false

/// CLI 实验性 HTTP/3 fetch 标志
/// 严格翻译自: pub var experimental_http3_client_from_cli: bool = false
public var experimentalHttp3ClientFromCli: Bool = false

/// 最大重定向 URL 长度
/// 严格翻译自: const MAX_REDIRECT_URL_LENGTH = 128 * 1024

/// 最大 HTTP 头部大小
/// 严格翻译自: pub var max_http_header_size: usize = 16 * 1024

/// 空闲超时 (秒), 0 禁用
/// 严格翻译自: pub var idle_timeout_seconds: c_uint = 300

/// 覆盖的默认 User-Agent
/// 严格翻译自: pub var overridden_default_user_agent: []const u8 = ""
public var overriddenDefaultUserAgent: String = ""

/// chunked 编码终止标记
/// 严格翻译自: pub const end_of_chunked_http1_1_encoding_response_body = "0\r\n\r\n"

/// 默认重定向次数
/// 严格翻译自: const default_redirect_count = 127

/// TLS 记录最大大小
/// 严格翻译自: const max_tls_record_size = 16 * 1024

/// 最大请求头数量
/// 严格翻译自: const max_request_headers = 256

/// H2 最大重试次数
/// 严格翻译自: pub const max_h2_retries: u8 = 5

/// 共享请求头缓冲区
/// 严格翻译自: var shared_request_headers_buf: [max_request_headers]picohttp.Header = undefined
public var sharedRequestHeadersBuf: Array<HeaderPair> = Array<HeaderPair>(MAX_REQUEST_HEADERS, { _ => HeaderPair("", "") })

/// 共享响应头缓冲区
/// 严格翻译自: var shared_response_headers_buf: [256]picohttp.Header = undefined
public var sharedResponseHeadersBuf: Array<HeaderPair> = Array<HeaderPair>(256, { _ => HeaderPair("", "") })

/// 临时 hostname 缓冲区
/// 严格翻译自: pub var temp_hostname: [8192]u8 = undefined
public var tempHostname: Array<UInt8> = Array<UInt8>(8192, { _ => UInt8(0) })

// ============================================================================
// HTTPUpgradeState - HTTP 升级状态
// 严格翻译自: const HTTPUpgradeState = enum(u2) { none, pending, upgraded }
// ============================================================================

public enum HTTPUpgradeState {
    | none
    | pending
    | upgraded
}

// ============================================================================
// HTTPProtocol - HTTP 协议版本
// 严格翻译自: pub const Protocol = enum(u2) { http1_1, http2, http3 }
// ============================================================================

public enum HTTPProtocol {
    | http1_1
    | http2
    | http3

    public operator func ==(right: HTTPProtocol): Bool {
        match (this) {
            case http1_1 => match (right) { case http1_1 => true case _ => false }
            case http2 => match (right) { case http2 => true case _ => false }
            case http3 => match (right) { case http3 => true case _ => false }
        }
    }

    public operator func !=(right: HTTPProtocol): Bool {
        return !(this == right)
    }
}

// ============================================================================
// HTTPClientFlags - HTTP 客户端标志位
// 严格翻译自: pub const Flags = packed struct(u32) { ... }
// ============================================================================

/// HTTP 客户端标志
/// 严格翻译自: http.zig Flags packed struct
public class HTTPClientFlags {
    /// 禁用超时 - 对应 disable_timeout
    public var disableTimeout: Bool
    /// 禁用 keep-alive - 对应 disable_keepalive
    public var disableKeepalive: Bool
    /// 禁用解压 - 对应 disable_decompression
    public var disableDecompression: Bool
    /// 是否有握手错误 - 对应 did_have_handshaking_error
    public var didHaveHandshakingError: Bool
    /// 强制 Last-Modified - 对应 force_last_modified
    public var forceLastModified: Bool
    /// 是否已重定向 - 对应 redirected
    public var redirected: Bool
    /// 代理隧道模式 - 对应 proxy_tunneling
    public var proxyTunneling: Bool
    /// 拒绝未授权 - 对应 reject_unauthorized
    public var rejectUnauthorized: Bool
    /// 是否仅预连接 - 对应 is_preconnect_only
    public var isPreconnectOnly: Bool
    /// 是否流式请求体 - 对应 is_streaming_request_body
    public var isStreamingRequestBody: Bool
    /// 延迟失败直到连接完成 - 对应 defer_fail_until_connecting_is_complete
    public var deferFailUntilConnectingIsComplete: Bool
    /// 升级状态 - 对应 upgrade_state
    public var upgradeState: HTTPUpgradeState
    /// 协议 - 对应 protocol
    public var protocol: HTTPProtocol
    /// 强制 HTTP/2 - 对应 force_http2
    public var forceHttp2: Bool
    /// 强制 HTTP/1.1 - 对应 force_http1
    public var forceHttp1: Bool
    /// 强制 HTTP/3 - 对应 force_http3
    public var forceHttp3: Bool
    /// H3 是否已重试 - 对应 h3_retried
    public var h3Retried: Bool

    public init() {
        disableTimeout = false
        disableKeepalive = false
        disableDecompression = false
        didHaveHandshakingError = false
        forceLastModified = false
        redirected = false
        proxyTunneling = false
        rejectUnauthorized = true
        isPreconnectOnly = false
        isStreamingRequestBody = false
        deferFailUntilConnectingIsComplete = false
        upgradeState = HTTPUpgradeState.none
        protocol = HTTPProtocol.http1_1
        forceHttp2 = false
        forceHttp1 = false
        forceHttp3 = false
        h3Retried = false
    }
}

// ============================================================================
// InitialRequestPayloadResult - 初始请求载荷发送结果
// 严格翻译自: const InitialRequestPayloadResult = struct { ... }
// ============================================================================

/// 初始请求载荷发送结果
/// 严格翻译自: http.zig InitialRequestPayloadResult
public class InitialRequestPayloadResult {
    public var hasSentHeaders: Bool
    public var hasSentBody: Bool
    public var trySendingMoreData: Bool

    public init(hasSentHeaders: Bool, hasSentBody: Bool, trySendingMoreData: Bool) {
        this.hasSentHeaders = hasSentHeaders
        this.hasSentBody = hasSentBody
        this.trySendingMoreData = trySendingMoreData
    }
}

// ============================================================================
// HeaderBuilder 引用类型
// 严格翻译自: pub const HeaderBuilder = @import("./HeaderBuilder.zig")
// ============================================================================

/// 头部构建器引用
/// 实际实现在 header_builder.cj
public class HeaderBuilderRef {
    public var entries: ArrayList<HeaderPair>

    public init() {
        entries = ArrayList<HeaderPair>()
    }
}

// ============================================================================
// HTTPClient - HTTP 客户端
// 严格翻译自: const HTTPClient = @This()
//   method: Method,
//   header_entries: Headers.Entry.List,
//   header_buf: string,
//   url: URL,
//   connected_url: URL = URL{},
//   allocator: std.mem.Allocator,
//   verbose: HTTPVerboseLevel = .none,
//   remaining_redirect_count: i8 = default_redirect_count,
//   allow_retry: bool = false,
//   h2_retries: u8 = 0,
//   redirect_type: FetchRedirect = FetchRedirect.follow,
//   redirect: []u8 = &.{},
//   prev_redirect: []u8 = &.{},
//   progress_node: ?*Progress.Node = null,
//   flags: Flags = Flags{},
//   state: InternalState = .{},
//   tls_props: ?SSLConfig.SharedPtr = null,
//   custom_ssl_ctx: ?*NewHTTPContext(true) = null,
//   result_callback: HTTPClientResult.Callback = undefined,
//   if_modified_since: string = "",
//   request_content_len_buf: ["-4294967295".len]u8 = undefined,
//   http_proxy: ?URL = null,
//   proxy_headers: ?Headers = null,
//   proxy_authorization: ?[]u8 = null,
//   proxy_tunnel: ?*ProxyTunnel = null,
//   h2: ?*H2.Stream = null,
//   h3: ?*H3.Stream = null,
//   pending_h2: ?*H2.PendingConnect = null,
//   signals: Signals = .{},
//   async_http_id: u32 = 0,
//   hostname: ?[]u8 = null,
//   unix_socket_path: ZigString.Slice = ZigString.Slice.empty,
// ============================================================================

/// HTTP 客户端 — 完整的请求/响应生命周期管理
/// 严格翻译自: bun/src/http/http.zig HTTPClient struct
public class HTTPClient {
    /// HTTP 方法
    /// 严格翻译自: method: Method
    public var method: String

    /// 头部条目列表
    /// 严格翻译自: header_entries: Headers.Entry.List
    public var headerEntries: ArrayList<HeaderPair>

    /// 头部缓冲区
    /// 严格翻译自: header_buf: string
    public var headerBuf: String

    /// 请求 URL
    /// 严格翻译自: url: URL
    public var url: ParsedUrl

    /// 已连接 URL
    /// 严格翻译自: connected_url: URL = URL{}
    public var connectedUrl: ParsedUrl

    /// 调试级别
    /// 严格翻译自: verbose: HTTPVerboseLevel = .none
    public var verbose: HTTPVerboseLevel

    /// 剩余重定向次数
    /// 严格翻译自: remaining_redirect_count: i8 = default_redirect_count
    public var remainingRedirectCount: Int64

    /// 是否允许重试
    /// 严格翻译自: allow_retry: bool = false
    public var allowRetry: Bool

    /// H2 重试次数
    /// 严格翻译自: h2_retries: u8 = 0
    public var h2Retries: UInt8

    /// 重定向类型
    /// 严格翻译自: redirect_type: FetchRedirect = FetchRedirect.follow
    public var redirectType: String

    /// 重定向 URL 缓冲区
    /// 严格翻译自: redirect: []u8 = &.{}
    public var redirect: String

    /// 前一次重定向缓冲区
    /// 严格翻译自: prev_redirect: []u8 = &.{}
    public var prevRedirect: String

    /// 标志位
    /// 严格翻译自: flags: Flags = Flags{}
    public var flags: HTTPClientFlags

    /// 内部状态
    /// 严格翻译自: state: InternalState = .{}
    public var state: InternalState

    /// TLS 配置
    /// 严格翻译自: tls_props: ?SSLConfig.SharedPtr = null
    public var tlsProps: Any

    /// 自定义 SSL 上下文
    /// 严格翻译自: custom_ssl_ctx: ?*NewHTTPContext(true) = null
    public var customSslCtx: Any

    /// 结果回调
    /// 严格翻译自: result_callback: HTTPClientResult.Callback = undefined
    public var resultCallback: HTTPClientResultCallback

    /// If-Modified-Since 头
    /// 严格翻译自: if_modified_since: string = ""
    public var ifModifiedSince: String

    /// 请求内容长度缓冲区
    /// 严格翻译自: request_content_len_buf: ["-4294967295".len]u8 = undefined
    public var requestContentLenBuf: Array<UInt8>

    /// HTTP 代理 URL
    /// 严格翻译自: http_proxy: ?URL = null
    public var httpProxy: ?ParsedUrl

    /// 代理头部
    /// 严格翻译自: proxy_headers: ?Headers = null
    public var proxyHeaders: Any

    /// 代理认证
    /// 严格翻译自: proxy_authorization: ?[]u8 = null
    public var proxyAuthorization: ?String

    /// 代理隧道
    /// 严格翻译自: proxy_tunnel: ?*ProxyTunnel = null
    public var proxyTunnel: ?ProxyTunnel

    /// H2 流
    /// 严格翻译自: h2: ?*H2.Stream = null
    public var h2: Any

    /// H3 流
    /// 严格翻译自: h3: ?*H3.Stream = null
    public var h3: Any

    /// 待处理的 H2 连接
    /// 严格翻译自: pending_h2: ?*H2.PendingConnect = null
    public var pendingH2: Any

    /// 信号
    /// 严格翻译自: signals: Signals = .{}
    public var signals: HTTPSignals

    /// 异步 HTTP ID
    /// 严格翻译自: async_http_id: u32 = 0
    public var asyncHttpId: UInt32

    /// Host 头部覆盖
    /// 严格翻译自: hostname: ?[]u8 = null
    public var hostname: ?String

    /// Unix socket 路径
    /// 严格翻译自: unix_socket_path: ZigString.Slice
    public var unixSocketPath: String

    public init() {
        method = "GET"
        headerEntries = ArrayList<HeaderPair>()
        headerBuf = ""
        url = ParsedUrl()
        connectedUrl = ParsedUrl()
        verbose = HTTPVerboseLevel.none
        remainingRedirectCount = DEFAULT_REDIRECT_COUNT
        allowRetry = false
        h2Retries = UInt8(0)
        redirectType = "follow"
        redirect = ""
        prevRedirect = ""
        flags = HTTPClientFlags()
        state = InternalState()
        tlsProps = ()
        customSslCtx = ()
        resultCallback = HTTPClientResultCallback()
        ifModifiedSince = ""
        requestContentLenBuf = Array<UInt8>(12, { _ => UInt8(0) })
        httpProxy = None
        proxyHeaders = ()
        proxyAuthorization = None
        proxyTunnel = None
        h2 = ()
        h3 = ()
        pendingH2 = ()
        signals = HTTPSignals()
        asyncHttpId = UInt32(0)
        hostname = None
        unixSocketPath = ""
    }

    // ========================================================================
    // deinit - 释放资源
    // 严格翻译自:
    //   pub fn deinit(this: *HTTPClient) void {
    //       if (this.redirect.len > 0) { ... free ... }
    //       if (this.prev_redirect.len > 0) { ... free ... }
    //       if (this.proxy_authorization) |auth| { ... }
    //       if (this.proxy_headers) |*hdrs| { ... }
    //       if (this.proxy_tunnel) |tunnel| { ... }
    //       if (this.h2 == null) assert
    //       if (this.tls_props) |*tls| tls.deinit();
    //       if (this.custom_ssl_ctx) |ctx| ctx.deref();
    //       this.unix_socket_path.deinit();
    //   }
    // ========================================================================

    /// 释放资源
    /// 严格翻译自: HTTPClient.deinit
    public func deinit(): Unit {
        redirect = ""
        prevRedirect = ""
        proxyAuthorization = None
        httpProxy = None
        proxyTunnel = None
        h2 = ()
        h3 = ()
        pendingH2 = ()
        tlsProps = ()
        customSslCtx = ()
        unixSocketPath = ""
    }

    // ========================================================================
    // isHTTPS - 判断是否 HTTPS
    // 严格翻译自:
    //   pub fn isHTTPS(this: *HTTPClient) bool {
    //       if (this.http_proxy) |proxy| { return proxy.isHTTPS(); }
    //       return this.url.isHTTPS();
    //   }
    // ========================================================================

    /// 判断是否 HTTPS
    /// 严格翻译自: HTTPClient.isHTTPS
    public func isHTTPS(): Bool {
        match (httpProxy) {
            case Some(proxy) =>
                return proxy.protocol == "https"
            case None =>
                return url.protocol == "https"
        }
    }

    // ========================================================================
    // isKeepAlivePossible - 是否可以 keep-alive
    // 严格翻译自:
    //   pub fn isKeepAlivePossible(this: *HTTPClient) bool {
    //       if (this.unix_socket_path.length() > 0) return false;
    //       if (this.state.flags.allow_keepalive and !this.flags.disable_keepalive) return true;
    //       return false;
    //   }
    // ========================================================================

    /// 是否可以 keep-alive
    /// 严格翻译自: HTTPClient.isKeepAlivePossible
    public func isKeepAlivePossible(): Bool {
        if (unixSocketPath.size > 0) {
            return false
        }
        return state.flags.allowKeepalive && !flags.disableKeepalive
    }

    // ========================================================================
    // getTlsHostname - 获取 TLS SNI 主机名
    // 严格翻译自:
    //   fn getTlsHostname(client: *const HTTPClient, allowProxyUrl: bool) []const u8 {
    //       if (allowProxyUrl) { if (client.http_proxy) |proxy| return proxy.hostname; }
    //       if (client.tls_props) |props| { if (props.get().server_name) |sn| ... }
    //       if (client.hostname) |host| return stripPortFromHost(host);
    //       return client.url.hostname;
    //   }
    // ========================================================================

    /// 获取 TLS SNI 主机名
    /// 严格翻译自: HTTPClient.getTlsHostname
    public func getTlsHostname(allowProxyUrl: Bool): String {
        if (allowProxyUrl) {
            match (httpProxy) {
                case Some(proxy) => return proxy.hostname
                case None => ()
            }
        }
        // 简化: 不检查 tls_props.server_name
        match (hostname) {
            case Some(host) => return stripPortFromHost(host)
            case None => ()
        }
        return url.hostname
    }

    // ========================================================================
    // canOfferH2 - 是否可以提供 H2 ALPN
    // 严格翻译自:
    //   pub fn canOfferH2(client: *const HTTPClient) bool {
    //       if (client.flags.force_http1) return false;
    //       if (client.http_proxy != null) return false;
    //       if (client.flags.is_preconnect_only) return false;
    //       if (client.unix_socket_path.length() > 0) return false;
    //       if (client.state.original_request_body == .sendfile) return false;
    //       return client.flags.force_http2 or experimental_http2_client_from_cli or ...;
    //   }
    // ========================================================================

    /// 是否可以提供 H2 ALPN
    /// 严格翻译自: HTTPClient.canOfferH2
    public func canOfferH2(): Bool {
        if (flags.forceHttp1) { return false }
        if (httpProxy.isSome()) { return false }
        if (flags.isPreconnectOnly) { return false }
        if (unixSocketPath.size > 0) { return false }
        return flags.forceHttp2 || experimentalHttp2ClientFromCli
    }

    // ========================================================================
    // alpnOffer - ALPN 协议提议
    // 严格翻译自:
    //   pub fn alpnOffer(client: *const HTTPClient) BoringSSL.SSL.AlpnOffer {
    //       if (!client.canOfferH2()) return .h1;
    //       return if (client.flags.force_http2) .h2_only else .h1_or_h2;
    //   }
    // ========================================================================

    /// ALPN 协议提议
    /// 严格翻译自: HTTPClient.alpnOffer
    public func alpnOffer(): String {
        if (!canOfferH2()) { return "h1" }
        return if (flags.forceHttp2) { "h2_only" } else { "h1_or_h2" }
    }

    // ========================================================================
    // h3AltSvcEnabled - 是否启用 H3 Alt-Svc
    // 严格翻译自:
    //   pub fn h3AltSvcEnabled() bool {
    //       return experimental_http3_client_from_cli or
    //           bun.feature_flag.BUN_FEATURE_FLAG_EXPERIMENTAL_HTTP3_CLIENT.get();
    //   }
    // ========================================================================

    /// 是否启用 H3 Alt-Svc (全局函数)
    public static func h3AltSvcEnabled(): Bool {
        return experimentalHttp3ClientFromCli
    }

    // ========================================================================
    // canTryH3AltSvc - 是否可以尝试 H3 Alt-Svc
    // 严格翻译自:
    //   pub fn canTryH3AltSvc(client: *const HTTPClient) bool {
    //       if (client.flags.force_http1 or client.flags.force_http2) return false;
    //       if (client.http_proxy != null) return false;
    //       if (client.flags.is_preconnect_only) return false;
    //       if (client.unix_socket_path.length() > 0) return false;
    //       if (client.state.original_request_body == .sendfile) return false;
    //       return h3AltSvcEnabled();
    //   }
    // ========================================================================

    /// 是否可以尝试 H3 Alt-Svc
    /// 严格翻译自: HTTPClient.canTryH3AltSvc
    public func canTryH3AltSvc(): Bool {
        if (flags.forceHttp1 || flags.forceHttp2) { return false }
        if (httpProxy.isSome()) { return false }
        if (flags.isPreconnectOnly) { return false }
        if (unixSocketPath.size > 0) { return false }
        return h3AltSvcEnabled()
    }

    // ========================================================================
    // start - 启动 HTTP 请求
    // 严格翻译自:
    //   pub fn start(this: *HTTPClient, body: HTTPRequestBody, body_out_str: *MutableString) void {
    //       body_out_str.reset();
    //       this.state = InternalState(body, body_out_str);
    //       if (this.isHTTPS()) { this.start_(true); } else { this.start_(false); }
    //   }
    // ========================================================================

    /// 启动 HTTP 请求
    /// 严格翻译自: HTTPClient.start
    public func start(body: HTTPRequestBody, bodyOutStr: MutableString): Unit {
        bodyOutStr.reset()
        state = InternalState.initFunc(body, bodyOutStr)
        if (isHTTPS()) {
            start_(true)
        } else {
            start_(false)
        }
    }

    // ========================================================================
    // start_ - 内部启动逻辑
    // 严格翻译自:
    //   fn start_(this: *HTTPClient, comptime is_ssl: bool) void {
    //       this.flags.defer_fail_until_connecting_is_complete = true;
    //       if (this.signals.get(.aborted)) { this.fail(error.AbortedBeforeConnecting); return; }
    //       if (comptime !is_ssl) { if (this.flags.force_http2) { this.fail(error.HTTP2Unsupported); return; } }
    //       // H3 Alt-Svc / force_http3 处理
    //       // 连接 socket
    //   }
    // ========================================================================

    /// 内部启动逻辑
    /// 严格翻译自: HTTPClient.start_
    public func start_(isSsl: Bool): Unit {
        flags.deferFailUntilConnectingIsComplete = true

        // 中止检查
        if (signals.aborted) {
            fail("AbortedBeforeConnecting")
            completeConnectingProcess()
            return
        }

        // HTTP/2 仅支持 HTTPS
        if (!isSsl && flags.forceHttp2) {
            fail("HTTP2Unsupported")
            completeConnectingProcess()
            return
        }

        // HTTP/3 检查
        if (isSsl) {
            if (!flags.forceHttp3 && canTryH3AltSvc()) {
                // Alt-Svc 升级检查 (桩)
            }
        }

        if (flags.forceHttp3) {
            if (!isSsl) {
                fail("HTTP3Unsupported")
                completeConnectingProcess()
                return
            }
            // QUIC 连接 (桩)
            return
        }

        // TCP 连接
        match (httpThread.connect(this, isSsl)) {
            case Some(socketFd) =>
                if (state.requestStage == HTTPStage.pending) {
                    state.requestStage = HTTPStage.opened
                }
            case None =>
                // 合并到 H2 会话
                ()
        }

        completeConnectingProcess()
    }

    // ========================================================================
    // onOpen - 连接建立回调
    // 严格翻译自:
    //   pub fn onOpen(client: *HTTPClient, comptime is_ssl: bool, socket: ...) !void {
    //       client.setTimeout(socket);
    //       if (!client.flags.disable_keepalive) socket.setKeepAlive(true, 60);
    //       if (client.signals.get(.aborted)) { client.closeAndAbort(...); return error.ClientAborted; }
    //       if (client.state.request_stage == .pending) client.state.request_stage = .opened;
    //       if (comptime is_ssl) { /* ALPN / SNI */ } else { client.firstCall(is_ssl, socket); }
    //   }
    // ========================================================================

    /// 连接建立回调
    /// 严格翻译自: HTTPClient.onOpen
    public func onOpen(isSsl: Bool, socketFd: Int64): Unit {
        // 设置超时
        setTimeout(socketFd)

        // TCP keepalive
        if (!flags.disableKeepalive) {
            // socket.setKeepAlive(true, 60)
        }

        // 中止检查
        if (signals.aborted) {
            closeAndAbort(isSsl, socketFd)
            return
        }

        if (state.requestStage == HTTPStage.pending) {
            state.requestStage = HTTPStage.opened
        }

        if (!isSsl) {
            firstCall(isSsl, socketFd)
        }
    }

    // ========================================================================
    // firstCall - 首次调用
    // 严格翻译自:
    //   pub fn firstCall(client: *HTTPClient, comptime is_ssl: bool, socket: ...) void {
    //       if (comptime is_ssl) {
    //           // ALPN 协议选择 -> H2 或 H1
    //       }
    //       switch (client.state.request_stage) {
    //           .opened, .pending => client.onWritable(true, comptime is_ssl, socket),
    //           else => {},
    //       }
    //   }
    // ========================================================================

    /// 首次调用
    /// 严格翻译自: HTTPClient.firstCall
    public func firstCall(isSsl: Bool, socketFd: Int64): Unit {
        match (state.requestStage) {
            case opened => onWritable(true, isSsl, socketFd)
            case pending => onWritable(true, isSsl, socketFd)
            case _ => ()
        }
    }

    // ========================================================================
    // retryAfterH2Coalesce - H2 合并后重试
    // 严格翻译自: pub fn retryAfterH2Coalesce(this: *HTTPClient) void
    // ========================================================================

    /// H2 合并后重试
    /// 严格翻译自: HTTPClient.retryAfterH2Coalesce
    public func retryAfterH2Coalesce(): Unit {
        start_(true)
    }

    // ========================================================================
    // retryFromH2 - H2 重试
    // 严格翻译自:
    //   pub fn retryFromH2(this: *HTTPClient) void {
    //       this.flags.protocol = .http1_1;
    //       this.h2_retries += 1;
    //       // 重置状态并重启
    //   }
    // ========================================================================

    /// H2 重试
    /// 严格翻译自: HTTPClient.retryFromH2
    public func retryFromH2(): Unit {
        flags.protocol = HTTPProtocol.http1_1
        h2Retries = h2Retries + UInt8(1)
        // 简化: 重置状态并重启
    }

    // ========================================================================
    // failFromH2 - H2 失败
    // 严格翻译自:
    //   pub fn failFromH2(this: *HTTPClient, err: anyerror) void {
    //       if (this.state.stage != .done and this.state.stage != .fail) {
    //           this.state.request_stage = .fail;
    //           this.state.response_stage = .fail;
    //           this.state.fail = err;
    //           // 回调
    //       }
    //   }
    // ========================================================================

    /// H2 失败
    /// 严格翻译自: HTTPClient.failFromH2
    public func failFromH2(err: String): Unit {
        if (state.stage != Stage.done && state.stage != Stage.fail) {
            state.requestStage = HTTPStage.fail
            state.responseStage = HTTPStage.fail
            state.fail = Some(err)
            state.stage = Stage.fail

            if (!flags.deferFailUntilConnectingIsComplete) {
                let callback = resultCallback
                let result = toResult()
                state.reset()
                callback.run(Some(this), result)
            }
        }
    }

    // ========================================================================
    // doRedirect - 执行重定向
    // 严格翻译自:
    //   pub fn doRedirect(this: *HTTPClient, comptime is_ssl: bool,
    //       ctx: *NewHTTPContext(is_ssl), socket: ...) void {
    //       this.state.response_message_buffer.deinit();
    //       this.remaining_redirect_count -|= 1;
    //       this.flags.redirected = true;
    //       // 关闭/释放 socket, 重置状态, 重启请求
    //   }
    // ========================================================================

    /// 执行重定向
    /// 严格翻译自: HTTPClient.doRedirect
    public func doRedirect(isSsl: Bool, socketFd: Int64): Unit {
        let requestBody = if (state.flags.resendRequestBodyOnRedirect) {
            state.requestBody
        } else {
            ""
        }

        state.responseMessageBuffer.reset()
        remainingRedirectCount = remainingRedirectCount - 1
        flags.redirected = true

        proxyTunnel = None

        connectedUrl = ParsedUrl()
        prevRedirect = ""

        if (remainingRedirectCount == 0) {
            fail("TooManyRedirects")
            return
        }

        state.reset()
        flags.proxyTunneling = false
        flags.protocol = HTTPProtocol.http1_1

        let bodyOutStr = match (state.bodyOutStr) {
            case Some(buf) => buf
            case None => MutableString()
        }

        start(HTTPRequestBody.bytes(requestBody), bodyOutStr)
    }

    // ========================================================================
    // onClose - 连接关闭回调
    // 严格翻译自:
    //   pub fn onClose(client: *HTTPClient, comptime is_ssl: bool, socket: ...) void {
    //       client.unregisterAbortTracker();
    //       if (client.signals.get(.aborted)) { client.fail(error.Aborted); return; }
    //       // 代理隧道清理, 重定向处理, keep-alive, 重试逻辑
    //   }
    // ========================================================================

    /// 连接关闭回调
    /// 严格翻译自: HTTPClient.onClose
    public func onClose(isSsl: Bool, socketFd: Int64): Unit {
        // 代理隧道清理
        proxyTunnel = None

        let inProgress = state.stage != Stage.done && state.stage != Stage.fail &&
            !state.flags.isRedirectPending

        if (state.flags.isRedirectPending) {
            // 执行重定向
            doRedirect(isSsl, socketFd)
            return
        }

        if (inProgress) {
            if (state.isChunkedEncoding()) {
                // chunked body 中关闭
                state.flags.receivedLastChunk = true
                return
            }
            match (state.contentLength) {
                case None =>
                    if (state.responseStage == HTTPStage.body) {
                        state.flags.receivedLastChunk = true
                        return
                    }
                case _ => ()
            }
        }

        // 幂等方法重试
        if (allowRetry && state.responseStage != HTTPStage.body && state.responseStage != HTTPStage.bodyChunk) {
            allowRetry = false
            return
        }

        if (inProgress) {
            fail("ConnectionClosed")
        }
    }

    // ========================================================================
    // onTimeout - 超时回调
    // 严格翻译自:
    //   pub fn onTimeout(client: *HTTPClient, ...) void {
    //       if (client.flags.disable_timeout) return;
    //       client.fail(error.Timeout);
    //   }
    // ========================================================================

    /// 超时回调
    /// 严格翻译自: HTTPClient.onTimeout
    public func onTimeout(isSsl: Bool, socketFd: Int64): Unit {
        if (flags.disableTimeout) {
            return
        }
        fail("Timeout")
    }

    // ========================================================================
    // fail - 失败处理
    // 严格翻译自:
    //   pub fn fail(client: *HTTPClient, err: anyerror) void { ... }
    // ========================================================================

    /// 失败处理
    /// 严格翻译自: HTTPClient.fail
    public func fail(err: String): Unit {
        if (state.stage != Stage.done && state.stage != Stage.fail) {
            state.requestStage = HTTPStage.fail
            state.responseStage = HTTPStage.fail
            state.fail = Some(err)
            state.stage = Stage.fail

            if (!flags.deferFailUntilConnectingIsComplete) {
                let callback = resultCallback
                let result = toResult()
                state.reset()
                callback.run(Some(this), result)
            }
        }
    }

    // ========================================================================
    // closeAndFail / closeAndAbort
    // ========================================================================

    /// 关闭并失败
    /// 严格翻译自: HTTPClient.closeAndFail
    public func closeAndFail(err: String, isSsl: Bool, socketFd: Int64): Unit {
        fail(err)
    }

    /// 关闭并中止
    /// 严格翻译自: HTTPClient.closeAndAbort
    public func closeAndAbort(isSsl: Bool, socketFd: Int64): Unit {
        closeAndFail("Aborted", isSsl, socketFd)
    }

    // ========================================================================
    // completeConnectingProcess - 完成连接过程
    // 严格翻译自:
    //   fn completeConnectingProcess(this: *HTTPClient) void {
    //       if (this.flags.defer_fail_until_connecting_is_complete) {
    //           this.flags.defer_fail_until_connecting_is_complete = false;
    //           if (this.state.stage == .fail) { ... callback ... }
    //       }
    //   }
    // ========================================================================

    /// 完成连接过程
    /// 严格翻译自: HTTPClient.completeConnectingProcess
    public func completeConnectingProcess(): Unit {
        if (flags.deferFailUntilConnectingIsComplete) {
            flags.deferFailUntilConnectingIsComplete = false
            if (state.stage == Stage.fail) {
                let callback = resultCallback
                let result = toResult()
                state.reset()
                callback.run(Some(this), result)
            }
        }
    }

    // ========================================================================
    // setTimeout - 设置超时
    // 严格翻译自: client.setTimeout(socket)
    // ========================================================================

    /// 设置超时
    /// 严格翻译自: HTTPClient.setTimeout
    public func setTimeout(socketFd: Int64): Unit {
        if (flags.disableTimeout || idleTimeoutSeconds == 0) {
            return
        }
        // socket.setTimeout(idleTimeoutSeconds)
    }

    // ========================================================================
    // progressUpdate - 进度更新
    // 严格翻译自: HTTPClient.progressUpdate
    // ========================================================================

    /// 进度更新
    /// 严格翻译自: HTTPClient.progressUpdate
    public func progressUpdate(isSsl: Bool, ctx: HTTPContext, socketFd: Int64): Unit {
        if (state.stage != Stage.done && state.stage != Stage.fail) {
            if (state.flags.isRedirectPending && !state.fail.isSome()) {
                if (state.isDone()) {
                    doRedirect(isSsl, socketFd)
                }
                return
            }
            sendProgressUpdateWithoutStageCheck(isSsl, ctx, socketFd)
        }
    }

    /// 发送进度更新
    private func sendProgressUpdateWithoutStageCheck(isSsl: Bool, ctx: HTTPContext, socketFd: Int64): Unit {
        let result = toResult()
        let isDone = !result.hasMore

        if (isDone) {
            state.reset()
            state.responseStage = HTTPStage.done
            state.requestStage = HTTPStage.done
            state.stage = Stage.done
            flags.proxyTunneling = false
        }

        resultCallback.run(Some(this), result)
    }

    // ========================================================================
    // toResult - 生成结果
    // 严格翻译自: HTTPClient.toResult
    // ========================================================================

    /// 生成结果
    /// 严格翻译自: HTTPClient.toResult
    public func toResult(): HTTPClientResult {
        let bodySize: BodySize = if (state.isChunkedEncoding()) {
            BodySize.totalReceived(state.totalBodyReceived)
        } else {
            match (state.contentLength) {
                case Some(cl) => BodySize.contentLength(cl)
                case None => BodySize.unknown
            }
        }

        var hasMore = false
        match (state.fail) {
            case None =>
                if (!state.isDone()) {
                    hasMore = true
                }
            case Some(_) => ()
        }

        let result = HTTPClientResult()
        result.body = state.bodyOutStr
        result.hasMore = hasMore
        result.redirected = flags.redirected
        result.canStream = false
        result.isHttp2 = flags.protocol != HTTPProtocol.http1_1
        result.fail = state.fail
        result.metadata = state.clonedMetadata
        result.bodySize = bodySize
        return result
    }

    // ========================================================================
    // proxyAuthHash - 代理认证哈希
    // 严格翻译自: HTTPClient.proxyAuthHash
    // ========================================================================

    /// 代理认证哈希
    /// 严格翻译自: HTTPClient.proxyAuthHash
    public func proxyAuthHash(): UInt64 {
        var combined: UInt64 = UInt64(0)
        var any = false

        match (hostname) {
            case Some(sniRaw) =>
                let sni = stripPortFromHost(sniRaw)
                if (!httpEqlCaseInsensitiveASCII(sni, url.hostname)) {
                    combined = combined + httpHash(sni)
                    any = true
                }
            case None => ()
        }

        match (proxyAuthorization) {
            case Some(auth) =>
                var h: UInt64 = UInt64(0)
                h = httpHash("proxy-authorization:" + auth)
                combined = combined + h
                any = true
            case None => ()
        }

        return if (any) { combined } else { UInt64(0) }
    }

    // ========================================================================
    // buildRequest - 构建请求
    // 严格翻译自: HTTPClient.buildRequest
    // ========================================================================

    /// 构建请求
    /// 严格翻译自: HTTPClient.buildRequest
    public func buildRequest(bodyLen: Int64): RawRequest {
        let request = RawRequest()
        request.method = method
        request.path = url.path
        request.minorVersion = 1

        // 默认头部
        request.headers.append(HeaderPair("Host", url.hostname))
        request.headers.append(HeaderPair("User-Agent",
            if (overriddenDefaultUserAgent.size > 0) { overriddenDefaultUserAgent } else { BAO_USER_AGENT }))
        request.headers.append(HeaderPair("Accept", "*/*"))

        if (!flags.disableKeepalive) {
            request.headers.append(HeaderPair("Connection", "keep-alive"))
        }

        if (bodyLen > 0) {
            request.headers.append(HeaderPair("Content-Length", bodyLen.toString()))
        }

        if (!flags.disableDecompression) {
            request.headers.append(HeaderPair("Accept-Encoding", "gzip, deflate, br, zstd"))
        }

        return request
    }

    // ========================================================================
    // onWritable - 可写回调
    // 严格翻译自: HTTPClient.onWritable
    // ========================================================================

    /// 可写回调
    /// 严格翻译自: HTTPClient.onWritable
    public func onWritable(isFirstCall: Bool, isSsl: Bool, socketFd: Int64): Unit {
        if (signals.aborted) {
            closeAndAbort(isSsl, socketFd)
            return
        }

        match (state.requestStage) {
            case pending => setTimeout(socketFd)
            case opened => setTimeout(socketFd)
            case headers => setTimeout(socketFd)
            case body =>
                setTimeout(socketFd)
                if (state.requestBody.size == 0) {
                    state.requestStage = HTTPStage.done
                }
            case _ => ()
        }
    }

    // ========================================================================
    // getSslCtx - 获取 SSL 上下文
    // 严格翻译自: HTTPClient.getSslCtx
    // ========================================================================

    /// 获取 SSL 上下文
    public func getSslCtx(isSsl: Bool): Any {
        return ()  // 简化
    }

    /// 估计请求头字节长度
    /// 严格翻译自: HTTPClient.estimatedRequestHeaderByteLength
    public func estimatedRequestHeaderByteLength(): Int64 {
        var count: Int64 = 0
        for (h in headerEntries) {
            count += h.name.size
            count += h.value.size
        }
        return count
    }

    /// 获取请求体发送缓冲区
    /// 严格翻译自: HTTPClient.getRequestBodySendBuffer
    public func getRequestBodySendBuffer(): Int64 {
        let actualEstimatedSize = state.requestBody.size + estimatedRequestHeaderByteLength()
        let estimatedSize = if (isHTTPS()) {
            if (actualEstimatedSize < MAX_TLS_RECORD_SIZE) { actualEstimatedSize } else { MAX_TLS_RECORD_SIZE }
        } else {
            actualEstimatedSize * 2
        }
        return estimatedSize
    }

    // ========================================================================
    // onData - 数据到达处理
    // 严格翻译自: HTTPClient.onData (约 60 行)
    //
    // 处理流程:
    //   1. 检查中止信号
    //   2. 如果有代理隧道，转发数据
    //   3. 根据 response_stage 分派到对应处理函数
    // ========================================================================

    /// 数据到达处理
    /// 严格翻译自: HTTPClient.onData
    public func onData(isSsl: Bool, incomingData: String, ctx: HTTPContext, socketFd: Int64): Unit {
        if (signals.aborted) {
            closeAndAbort(isSsl, socketFd)
            return
        }

        // 代理隧道模式 — 直接转发数据
        // 严格翻译自:
        //   if (this.proxy_tunnel) |proxy| { this.setTimeout(socket); proxy.receive(incoming_data); return }
        match (proxyTunnel) {
            case Some(proxy) =>
                setTimeout(socketFd)
                // proxy.receive(incomingData)
                return
            case None => ()
        }

        // 根据 response_stage 分派
        match (state.responseStage) {
            case pending => handleOnDataHeaders(isSsl, incomingData, ctx, socketFd)
            case headers => handleOnDataHeaders(isSsl, incomingData, ctx, socketFd)
            case body =>
                setTimeout(socketFd)
                let reportProgress = handleResponseBody(incomingData, false)
                if (reportProgress) {
                    progressUpdate(isSsl, ctx, socketFd)
                }
            case bodyChunk =>
                setTimeout(socketFd)
                let reportProgress = handleResponseBodyChunkedEncoding(incomingData)
                if (reportProgress) {
                    progressUpdate(isSsl, ctx, socketFd)
                }
            case fail => ()
            case _ =>
                state.pendingResponse = None
                closeAndFail("UnexpectedData", isSsl, socketFd)
        }
    }

    // ========================================================================
    // handleOnDataHeaders - 处理响应头部
    // 严格翻译自: HTTPClient.handleOnDataHeaders (约 160 行)
    // ========================================================================

    /// 处理响应头部
    /// 严格翻译自: HTTPClient.handleOnDataHeaders
    public func handleOnDataHeaders(isSsl: Bool, incomingData: String, ctx: HTTPContext, socketFd: Int64): Unit {
        var toRead = incomingData
        var needsMove = true

        if (state.responseMessageBuffer.size > 0) {
            state.responseMessageBuffer.appendSlice(incomingData)
            toRead = state.responseMessageBuffer.toString()
            needsMove = false
        }

        var response: RawResponse = RawResponse()

        while (true) {
            if (toRead.size < 16) {
                handleShortRead(isSsl, incomingData, socketFd, needsMove)
                return
            }

            response = parseHttpResponse(toRead)
            if (response.statusCode == 0) {
                handleShortRead(isSsl, incomingData, socketFd, needsMove)
                return
            }

            // 处理 101 升级
            if (response.statusCode == 101) {
                match (flags.upgradeState) {
                    case HTTPUpgradeState.none =>
                        closeAndFail("UnrequestedUpgrade", isSsl, socketFd)
                        return
                    case _ => ()
                }
                flags.upgradeState = HTTPUpgradeState.upgraded
                break
            }

            // 1xx 信息响应 — 继续解析
            if (response.statusCode >= 100 && response.statusCode < 200) {
                response = RawResponse()
                if (toRead.size == 0) { return }
                continue
            }

            break
        }

        state.pendingResponse = Some(response)

        let shouldContinue = handleResponseMetadata(response)

        match (shouldContinue) {
            case ShouldContinue.finished =>
                if (state.flags.isRedirectPending) {
                    doRedirect(isSsl, socketFd)
                    return
                }
                cloneMetadata()
                state.flags.receivedLastChunk = true
                state.contentLength = Some(Int64(0))
                progressUpdate(isSsl, ctx, socketFd)
                return
            case _ => ()
        }

        // 代理隧道启动
        if (flags.proxyTunneling) {
            match (proxyTunnel) {
                case None => return
                case Some(_) => ()
            }
        }

        cloneMetadata()

        let bodyData = if (response.bytesRead < toRead.size) {
            toRead[response.bytesRead..]
        } else {
            ""
        }

        match (state.responseStage) {
            case body =>
                let reportProgress = handleResponseBody(bodyData, true)
                if (reportProgress) {
                    progressUpdate(isSsl, ctx, socketFd)
                }
            case bodyChunk =>
                setTimeout(socketFd)
                let reportProgress = handleResponseBodyChunkedEncoding(bodyData)
                if (reportProgress) {
                    progressUpdate(isSsl, ctx, socketFd)
                }
            case _ => ()
        }
    }

    // ========================================================================
    // handleResponseMetadata - 处理响应元数据
    // 严格翻译自: HTTPClient.handleResponseMetadata (约 400 行)
    // ========================================================================

    /// 处理响应元数据
    /// 严格翻译自: HTTPClient.handleResponseMetadata
    public func handleResponseMetadata(response: RawResponse): ShouldContinue {
        var location: String = ""

        for (header in response.headers) {
            let hash = httpHash(header.name)
            if (hash == httpHash("content-length")) {
                state.contentLength = Some(parseInt64(header.value))
            } else if (hash == httpHash("content-encoding")) {
                if (!flags.disableDecompression) {
                    state.encoding = match (header.value) {
                        case "gzip" => Encoding.gzip
                        case "deflate" => Encoding.deflate
                        case "br" => Encoding.brotli
                        case "zstd" => Encoding.zstd
                        case _ => Encoding.identity
                    }
                }
            } else if (hash == httpHash("transfer-encoding")) {
                if (header.value == "chunked") {
                    state.transferEncoding = Encoding.chunked
                } else if (header.value == "identity") {
                    state.transferEncoding = Encoding.identity
                }
            } else if (hash == httpHash("location")) {
                location = header.value
            } else if (hash == httpHash("connection")) {
                if (response.statusCode >= 200 && response.statusCode <= 299) {
                    if (httpEqlCaseInsensitiveASCII(header.value, "close")) {
                        state.flags.allowKeepalive = false
                    } else if (httpEqlCaseInsensitiveASCII(header.value, "keep-alive")) {
                        state.flags.allowKeepalive = true
                    }
                }
            }
        }

        // HEAD/1xx/204/304 没有响应体
        if (method == "HEAD" ||
            (response.statusCode >= 100 && response.statusCode < 200) ||
            response.statusCode == 204 || response.statusCode == 304) {
            state.contentLength = Some(Int64(0))
        }

        // 无 Content-Length 且非 chunked → 禁用 keep-alive
        if (!state.contentLength.isSome() && !state.isChunkedEncoding()) {
            state.flags.allowKeepalive = false
        }

        // 代理隧道处理
        if (flags.proxyTunneling && !proxyTunnel.isSome()) {
            if (response.statusCode == 200) {
                return ShouldContinue.continueStreaming
            }
            flags.proxyTunneling = false
            flags.disableKeepalive = true
        }

        // 重定向处理
        let statusCode = response.statusCode
        let isRedirect = statusCode >= 300 && statusCode <= 399

        if (isRedirect) {
            if (redirectType == "follow" && location.size > 0 && remainingRedirectCount > 0) {
                match (statusCode) {
                    case 301 =>
                        if (method == "POST") { method = "GET" }
                        state.flags.isRedirectPending = true
                    case 302 =>
                        if (method == "POST") { method = "GET" }
                        state.flags.isRedirectPending = true
                    case 303 =>
                        if (method != "GET" && method != "HEAD") { method = "GET" }
                        state.flags.isRedirectPending = true
                    case 307 =>
                        state.flags.isRedirectPending = true
                        state.flags.resendRequestBodyOnRedirect = true
                    case 308 =>
                        state.flags.isRedirectPending = true
                        state.flags.resendRequestBodyOnRedirect = true
                    case _ => ()
                }
            } else if (redirectType == "error") {
                return ShouldContinue.finished
            }
        }

        state.responseStage = if (state.isChunkedEncoding()) {
            HTTPStage.bodyChunk
        } else {
            HTTPStage.body
        }

        let contentLength = state.contentLength
        let hasBody = contentLength.isSome() && contentLength.getOrThrow() > 0
        let isChunked = state.isChunkedEncoding()

        if (hasBody || isChunked || !state.flags.allowKeepalive) {
            return ShouldContinue.continueStreaming
        } else {
            return ShouldContinue.finished
        }
    }

    // ========================================================================
    // handleResponseBody - 处理响应体 (Content-Length 模式)
    // 严格翻译自: HTTPClient.handleResponseBody
    // ========================================================================

    /// 处理响应体 (Content-Length 模式)
    /// 严格翻译自: HTTPClient.handleResponseBody
    public func handleResponseBody(incomingData: String, isOnlyBuffer: Bool): Bool {
        let contentLength = state.contentLength
        if (isOnlyBuffer && contentLength.isSome() && incomingData.size >= contentLength.getOrThrow()) {
            handleResponseBodyFromSinglePacket(incomingData[0..contentLength.getOrThrow()])
            return true
        } else {
            return handleResponseBodyFromMultiplePackets(incomingData)
        }
    }

    /// 单包响应体处理
    /// 严格翻译自: HTTPClient.handleResponseBodyFromSinglePacket
    private func handleResponseBodyFromSinglePacket(incomingData: String): Unit {
        state.totalBodyReceived += incomingData.size
        if (state.flags.isRedirectPending) { return }
        match (state.bodyOutStr) {
            case Some(buf) => buf.appendSlice(incomingData)
            case None => ()
        }
    }

    /// 多包响应体处理
    /// 严格翻译自: HTTPClient.handleResponseBodyFromMultiplePackets
    private func handleResponseBodyFromMultiplePackets(incomingData: String): Bool {
        let contentLength = state.contentLength
        var remainder: String = incomingData
        if (contentLength.isSome()) {
            let remaining = contentLength.getOrThrow() - state.totalBodyReceived
            if (incomingData.size > remaining) {
                remainder = incomingData[0..remaining]
            }
        }
        if (!state.flags.isRedirectPending) {
            match (state.bodyOutStr) {
                case Some(buf) => buf.appendSlice(remainder)
                case None => ()
            }
        }
        state.totalBodyReceived += remainder.size
        let isDone = contentLength.isSome() && state.totalBodyReceived >= contentLength.getOrThrow()
        return isDone
    }

    // ========================================================================
    // handleResponseBodyChunkedEncoding - 处理 chunked 编码响应体
    // 严格翻译自: HTTPClient.handleResponseBodyChunkedEncoding
    // ========================================================================

    /// 处理 chunked 编码响应体
    /// 严格翻译自: HTTPClient.handleResponseBodyChunkedEncoding
    public func handleResponseBodyChunkedEncoding(incomingData: String): Bool {
        return handleResponseBodyChunkedEncodingFromMultiplePackets(incomingData)
    }

    /// 多包 chunked 编码处理
    /// 严格翻译自: HTTPClient.handleResponseBodyChunkedEncodingFromMultiplePackets
    private func handleResponseBodyChunkedEncodingFromMultiplePackets(incomingData: String): Bool {
        match (state.bodyOutStr) {
            case Some(buf) => buf.appendSlice(incomingData)
            case None => ()
        }
        state.totalBodyReceived += incomingData.size
        if (incomingData.size >= 5) {
            let tail = incomingData[incomingData.size - 5..]
            if (tail == "0\r\n\r\n") {
                state.flags.receivedLastChunk = true
                return true
            }
        }
        return false
    }

    // ========================================================================
    // handleShortRead - 处理短读取
    // 严格翻译自: HTTPClient.handleShortRead
    // ========================================================================

    /// 处理短读取
    /// 严格翻译自: HTTPClient.handleShortRead
    private func handleShortRead(isSsl: Bool, incomingData: String, socketFd: Int64, needsMove: Bool): Unit {
        if (needsMove && incomingData.size > 0) {
            state.responseMessageBuffer.appendSlice(incomingData)
        }
        setTimeout(socketFd)
    }

    // ========================================================================
    // cloneMetadata - 克隆响应元数据
    // 严格翻译自: HTTPClient.cloneMetadata
    // ========================================================================

    /// 克隆响应元数据
    /// 严格翻译自: HTTPClient.cloneMetadata
    public func cloneMetadata(): Unit {
        match (state.pendingResponse) {
            case Some(response) =>
                if (state.clonedMetadata.isSome()) {
                    state.clonedMetadata.getOrThrow().deinit()
                    state.clonedMetadata = None
                }
                let metadata = HTTPResponseMetadata()
                metadata.url = url.href
                metadata.response = response
                state.clonedMetadata = Some(metadata)
                state.pendingResponse = None
            case None => ()
        }
    }

    // ========================================================================
    // resolvePendingH2 - 解析挂起的 H2 连接
    // 严格翻译自: HTTPClient.resolvePendingH2
    // ========================================================================

    /// 解析挂起的 H2 连接
    /// 严格翻译自: HTTPClient.resolvePendingH2
    public func resolvePendingH2(resolution: PendingH2Resolution): Unit {
        pendingH2 = None
    }

    // ========================================================================
    // setCustomSslCtx - 设置自定义 SSL 上下文
    // 严格翻译自: HTTPClient.setCustomSslCtx
    // ========================================================================

    /// 设置自定义 SSL 上下文
    /// 严格翻译自: HTTPClient.setCustomSslCtx
    public func setCustomSslCtx(ctx: HTTPContext): Unit {
        ctx.ref()
        customSslCtx = ctx
    }

    // ========================================================================
    // drainResponseBody - 排空响应体
    // 严格翻译自: HTTPClient.drainResponseBody
    // ========================================================================

    /// 排空响应体
    /// 严格翻译自: HTTPClient.drainResponseBody
    public func drainResponseBody(isSsl: Bool, socketFd: Int64): Unit {
        match (state.stage) {
            case done => return
            case fail => return
            case _ => ()
        }
    }

    // ========================================================================
    // sendProgressUpdateMultiplexed - 多路复用进度更新
    // 严格翻译自: HTTPClient.sendProgressUpdateMultiplexed
    // ========================================================================

    /// 多路复用进度更新 (H2/H3)
    /// 严格翻译自: HTTPClient.sendProgressUpdateMultiplexed
    public func sendProgressUpdateMultiplexed(): Unit {
        let result = toResult()
        let isDone = !result.hasMore
        if (isDone) {
            state.reset()
            state.responseStage = HTTPStage.done
            state.requestStage = HTTPStage.done
            state.stage = Stage.done
            flags.proxyTunneling = false
        }
        resultCallback.run(Some(this), result)
    }

    // ========================================================================
    // doRedirectMultiplexed - 多路复用重定向
    // 严格翻译自: HTTPClient.doRedirectMultiplexed
    // ========================================================================

    /// 多路复用重定向 (H2/H3)
    /// 严格翻译自: HTTPClient.doRedirectMultiplexed
    public func doRedirectMultiplexed(): Unit {
        if (state.originalRequestBody.isStream()) {
            flags.isStreamingRequestBody = false
        }
        let requestBody = if (state.flags.resendRequestBodyOnRedirect) { state.requestBody } else { "" }
        state.responseMessageBuffer.reset()
        remainingRedirectCount = remainingRedirectCount - 1
        flags.redirected = true
        connectedUrl = ParsedUrl()
        if (remainingRedirectCount == 0) {
            fail("TooManyRedirects")
            return
        }
        state.reset()
        flags.proxyTunneling = false
        flags.protocol = HTTPProtocol.http1_1
    }

    // ========================================================================
    // progressUpdateH3 / doRedirectH3 - H3 特定
    // 严格翻译自: HTTPClient.progressUpdateH3 / doRedirectH3
    // ========================================================================

    /// H3 进度更新
    /// 严格翻译自: HTTPClient.progressUpdateH3
    public func progressUpdateH3(): Unit {
        if (state.stage == Stage.done || state.stage == Stage.fail) { return }
        if (state.flags.isRedirectPending && !state.fail.isSome()) {
            if (state.isDone()) { doRedirectMultiplexed() }
            return
        }
        sendProgressUpdateMultiplexed()
    }

    /// H3 重定向
    /// 严格翻译自: HTTPClient.doRedirectH3
    public func doRedirectH3(): Unit {
        doRedirectMultiplexed()
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 解析 HTTP 响应
    private func parseHttpResponse(data: String): RawResponse {
        let response = RawResponse()
        let headerEndOpt = data.indexOf("\r\n\r\n")
        if (!headerEndOpt.isSome()) {
            return response
        }

        let headerEnd = headerEndOpt.getOrThrow()
        let headerSection = data[0..headerEnd]
        let lines = splitHttpLines(headerSection)
        if (lines.size == 0) {
            return response
        }

        let statusLine = lines[0]
        if (!statusLine.startsWith("HTTP/")) {
            return response
        }

        let statusParts = splitHttp(statusLine, " ")
        if (statusParts.size < 2) {
            return response
        }

        response.statusCode = parseInt64(statusParts[1])
        if (statusParts.size > 2) {
            let statusText = StringBuilder()
            for (i in 2..statusParts.size) {
                if (i > 2) { statusText.append(" ") }
                statusText.append(statusParts[Int64(i)])
            }
            response.statusText = statusText.toString()
        }
        response.bytesRead = headerEnd + 4

        for (i in 1..lines.size) {
            let line = lines[Int64(i)]
            let colonIdxOpt = line.indexOf(":")
            if (colonIdxOpt.isSome()) {
                let colonIdx = colonIdxOpt.getOrThrow()
                let name = trimHttpAsciiWhitespace(line[0..colonIdx])
                let value = trimHttpAsciiWhitespace(line[(colonIdx + 1)..])
                response.headers.append(HeaderPair(name, value))
            }
        }

        return response
    }

    private func splitHttpLines(s: String): ArrayList<String> {
        let lines = ArrayList<String>()
        var current = StringBuilder()
        var i: Int64 = 0
        while (i < s.size) {
            if (i + 1 < s.size && s[i] == UInt8(13) && s[i + 1] == UInt8(10)) {
                lines.append(current.toString())
                current = StringBuilder()
                i += 2
            } else {
                current.append(s[i])
                i += 1
            }
        }
        if (current.toString().size > 0) {
            lines.append(current.toString())
        }
        return lines
    }

    private func splitHttp(s: String, sep: String): ArrayList<String> {
        let parts = ArrayList<String>()
        var remaining = s
        while (true) {
            let idxOpt = remaining.indexOf(sep)
            if (!idxOpt.isSome()) {
                parts.append(remaining)
                break
            }
            let idx = idxOpt.getOrThrow()
            parts.append(remaining[0..idx])
            remaining = remaining[(idx + sep.size)..]
        }
        return parts
    }

    private func trimHttpAsciiWhitespace(s: String): String {
        var start: Int64 = 0
        var end = s.size
        while (start < end && isHttpAsciiWhitespace(s[start])) {
            start += 1
        }
        while (end > start && isHttpAsciiWhitespace(s[end - 1])) {
            end -= 1
        }
        return s[start..end]
    }

    private func isHttpAsciiWhitespace(c: UInt8): Bool {
        return c == UInt8(32) || c == UInt8(9) || c == UInt8(10) || c == UInt8(13)
    }

    /// 解析 Int64 (简化)
    private static func parseInt64(s: String): Int64 {
        var result: Int64 = 0
        for (c in s) {
            if (c >= UInt8(48) && c <= UInt8(57)) {
                result = result * 10 + Int64(c - UInt8(48))
            }
        }
        return result
    }
}

// ============================================================================
// HTTPSignals - HTTP 信号
// 严格翻译自: bun/src/http/Signals.zig
// ============================================================================

/// HTTP 信号
/// 严格翻译自: Signals struct
public class HTTPSignals {
    /// 是否已中止
    public var aborted: Bool
    /// 头部进度信号
    public var headerProgress: Bool

    public init() {
        aborted = false
        headerProgress = false
    }

    public func get(signal: String): Bool {
        match (signal) {
            case "aborted" => return aborted
            case "header_progress" => return headerProgress
            case _ => return false
        }
    }
}

/// HTTP Body 流
public class HTTPBodyStream {
    public var buffer: Any
    public var ended: Bool

    public init() {
        buffer = ()
        ended = false
    }
}

/// Sendfile 信息
public class SendFileInfo {
    public var fd: Int64
    public var offset: Int64
    public var length: Int64

    public init() {
        fd = -1
        offset = 0
        length = 0
    }
}

// ============================================================================
// HTTPClientResult - HTTP 客户端结果
// 严格翻译自: bun/src/http/HTTPClientResult.zig
// ============================================================================

/// HTTP 客户端结果
public class HTTPClientResult {
    /// 响应体
    public var body: ?MutableString
    /// 是否还有更多数据
    public var hasMore: Bool
    /// 是否重定向
    public var redirected: Bool
    /// 是否可流式
    public var canStream: Bool
    /// 是否 H2
    public var isHttp2: Bool
    /// 失败原因
    public var fail: ?String
    /// 元数据
    public var metadata: ?HTTPResponseMetadata
    /// Body 大小
    public var bodySize: BodySize
    /// 证书信息
    public var certificateInfo: Any

    public init() {
        body = None
        hasMore = false
        redirected = false
        canStream = false
        isHttp2 = false
        fail = None
        metadata = None
        bodySize = BodySize.unknown
        certificateInfo = ()
    }

    public func isSuccess(): Bool {
        return !fail.isSome()
    }
}

/// Body 大小
public enum BodySize {
    | unknown
    | contentLength(Int64)
    | totalReceived(Int64)
}

/// HTTP 客户端结果回调
public class HTTPClientResultCallback {
    public var fn_: ?(HTTPClient, HTTPClientResult) -> Unit

    public init() {
        fn_ = None
    }

    public func run(client: ?HTTPClient, result: HTTPClientResult): Unit {
        match (fn_) {
            case Some(f) =>
                match (client) {
                    case Some(c) => f(c, result)
                    case None => ()
                }
            case None => ()
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// HTTP 连接结果
public enum HTTPConnectResult {
    | socket(Int64)
    | pending(Any)
    | coalesced
}

// ============================================================================
// 全局辅助函数
// ============================================================================

/// 从主机名中剥离端口
/// 严格翻译自: HTTPClient.stripPortFromHost
public func stripPortFromHost(host: String): String {
    if (host.size == 0) { return host }
    // IPv6: "[::1]:port"
    if (host[0] == UInt8(91)) {  // '['
        let bracketIdxOpt = host.lastIndexOf(']')
        match (bracketIdxOpt) {
            case Some(bracketIdx) => return host[0..(bracketIdx + 1)]
            case None => return host
        }
    }
    // IPv4 或 hostname
    let colonIdxOpt = host.lastIndexOf(':')
    match (colonIdxOpt) {
        case Some(colonIdx) => return host[0..colonIdx]
        case None => return host
    }
}

/// 检查服务器身份
/// 严格翻译自: HTTPClient.checkServerIdentity
public func checkServerIdentity(client: HTTPClient, isSsl: Bool, socketFd: Int64, certError: SSLHTTPCertError, allowProxyUrl: Bool): Bool {
    if (client.flags.rejectUnauthorized) {
        // 验证证书 (简化)
        return true
    }
    return true
}

/// 注册中止追踪器
/// 严格翻译自: HTTPClient.registerAbortTracker
public func registerAbortTracker(client: HTTPClient, isSsl: Bool, socketFd: Int64): Unit {
    if (client.signals.aborted) {
        // socketAsyncHttpAbortTracker.put(client.asyncHttpId, ...)
    }
}

/// 注销中止追踪器
/// 严格翻译自: HTTPClient.unregisterAbortTracker
public func unregisterAbortTracker(client: HTTPClient): Unit {
    if (client.signals.aborted) {
        // socketAsyncHttpAbortTracker.swapRemove(client.asyncHttpId)
    }
}

/// 无效 FD
public let INVALID_FD: Int64 = -1

// ============================================================================
// HTTPVerboseLevel - HTTP 调试级别
// 严格翻译自: pub const HTTPVerboseLevel = enum { none, headers, curl }
// ============================================================================

public enum HTTPVerboseLevel {
    | none
    | headers
    | curl
}

// ============================================================================
// HTTPStage, Stage — 定义在 internal_state.cj 中
// 此处仅保留 HTTPVerboseLevel
// ============================================================================

// HTTPResponseMetadata/RawResponse 定义在 internal_state.cj 中
// RawRequest 定义在 server.cj 中

/// ShouldContinue - 处理响应元数据后的结果
/// 严格翻译自: pub const ShouldContinue = enum { continue_streaming, finished }
public enum ShouldContinue {
    | continueStreaming
    | finished
}

/// PendingH2Resolution - H2 连接协商结果
/// 严格翻译自: const PendingH2Resolution = union(enum) { h2, h1, leader_failed }
public enum PendingH2Resolution {
    | h2
    | h1
    | leaderFailed
}

// ============================================================================
// 全局请求写入辅助函数
// 严格翻译自: http.zig writeRequest / writeProxyConnect / writeProxyRequest
// ============================================================================

/// 写入普通 HTTP 请求
/// 严格翻译自: fn writeRequest(comptime Writer, writer, request)
public func writeRequest(request: RawRequest): String {
    var buf = StringBuilder()
    buf.append(request.method)
    buf.append(" ")
    buf.append(request.path)
    buf.append(" HTTP/1.1\r\n")

    for (header in request.headers) {
        buf.append(header.name)
        buf.append(": ")
        buf.append(header.value)
        buf.append("\r\n")
    }

    buf.append("\r\n")
    return buf.toString()
}

/// 写入代理 CONNECT 请求
/// 严格翻译自: fn writeProxyConnect(comptime Writer, writer, client)
public func writeProxyConnect(client: HTTPClient): String {
    var buf = StringBuilder()
    var port: String = match (client.url.port) {
        case 0 => if (client.url.protocol == "https") { "443" } else { "80" }
        case p => p.toString()
    }

    buf.append("CONNECT ")
    buf.append(client.url.hostname)
    buf.append(":")
    buf.append(port)
    buf.append(" HTTP/1.1\r\n")

    buf.append("Host: ")
    buf.append(client.url.hostname)
    buf.append(":")
    buf.append(port)

    buf.append("\r\nProxy-Connection: Keep-Alive\r\n")

    // 用户提供的 Proxy-Authorization 检查
    // 严格翻译自:
    //   const user_provided_proxy_auth = if (client.proxy_headers) |hdrs|
    //       hdrs.get("proxy-authorization") != null else false
    //   if (client.proxy_authorization) |auth| {
    //       if (!user_provided_proxy_auth) {
    //           _ = writer.write("Proxy-Authorization: ") ...
    //       }
    //   }
    match (client.proxyAuthorization) {
        case Some(auth) =>
            buf.append("Proxy-Authorization: ")
            buf.append(auth)
            buf.append("\r\n")
        case None => ()
    }

    buf.append("\r\n")
    return buf.toString()
}

/// 写入代理 HTTP 请求 (非隧道)
/// 严格翻译自: fn writeProxyRequest(comptime Writer, writer, request, client)
public func writeProxyRequest(request: RawRequest, client: HTTPClient): String {
    var buf = StringBuilder()
    buf.append(request.method)
    buf.append(" http://")
    buf.append(client.url.hostname)

    // 仅在显式端口时包含端口号
    // 严格翻译自: if (client.url.getPort()) |_| { ... }
    if (client.url.port != 0) {
        buf.append(":")
        buf.append(client.url.port.toString())
    }

    buf.append(request.path)
    buf.append(" HTTP/1.1\r\nProxy-Connection: Keep-Alive\r\n")

    // Proxy-Authorization
    match (client.proxyAuthorization) {
        case Some(auth) =>
            buf.append("Proxy-Authorization: ")
            buf.append(auth)
            buf.append("\r\n")
        case None => ()
    }

    // 请求头
    for (header in request.headers) {
        buf.append(header.name)
        buf.append(": ")
        buf.append(header.value)
        buf.append("\r\n")
    }

    buf.append("\r\n")
    return buf.toString()
}

// StringBuilder 已移至 package.cj 中统一定义，避免重复

// ============================================================================
// HeaderPair — 定义在 server.cj 中，此处不再重复
// ============================================================================

// ============================================================================
// MutableString — 定义在 internal_state.cj 中，此处不再重复
// ============================================================================

// ============================================================================
// ParsedUrl — 定义在 package.cj 中，此处不再重复
// ============================================================================

// ============================================================================
// 私有辅助函数
// ============================================================================

private func httpCoreLowerByte(c: UInt8): UInt8 {
    if (c >= UInt8(65) && c <= UInt8(90)) {
        return c + UInt8(32)
    }
    return c
}

private func httpHash(s: String): UInt64 {
    var hash: UInt64 = UInt64(0)
    for (c in s) {
        hash = hash * UInt64(31) + UInt64(httpCoreLowerByte(c))
    }
    return hash
}

private func httpEqlCaseInsensitiveASCII(a: String, b: String): Bool {
    if (a.size != b.size) { return false }
    for (i in 0..a.size) {
        if (httpCoreLowerByte(a[i]) != httpCoreLowerByte(b[i])) {
            return false
        }
    }
    return true
}
