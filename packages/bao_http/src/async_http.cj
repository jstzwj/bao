// bao_http AsyncHTTP - 异步 HTTP 请求
// 严格翻译自: bun/src/http/AsyncHTTP.zig
package bao_http

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_threading.*

// ============================================================================
// AsyncHTTP - 异步 HTTP 请求任务
// 严格翻译自: bun/src/http/AsyncHTTP.zig
//
// AsyncHTTP 是 Bun HTTP 客户端的核心异步任务:
//   1. 在线程池上调度 (ThreadPool.Task)
//   2. 管理 HTTP 请求/响应的完整生命周期
//   3. 支持同步和异步两种调用模式
//   4. 支持连接限制 (max_simultaneous_requests)
//   5. 支持请求信号 (abort, header_progress, response_body_streaming)
// ============================================================================

/// AsyncHTTP 请求状态
/// 严格翻译自: AsyncHTTP.State enum(u32)
public enum AsyncHTTPState {
    | pending    // 0 - 等待调度
    | scheduled  // 1 - 已调度到线程池
    | sending    // 2 - 正在发送
    | success    // 3 - 成功
    | fail       // 4 - 失败
}

/// Fetch 重定向策略
/// 严格翻译自: bun/src/http_types/FetchRedirect.zig
public enum FetchRedirect {
    | follow   // 自动跟随重定向
    | manual   // 手动处理重定向
    | error    // 重定向时报错
}

/// 请求信号 — 用于跨线程通信
/// 严格翻译自: bun/src/http/Signals.zig (简化)
public class AsyncHTTPSignals {
    /// 是否已中止
    public var aborted: Bool
    /// 是否有头部进度信号
    public var headerProgress: Bool
    /// 是否启用响应体流式传输
    public var responseBodyStreaming: Bool
    /// 是否有证书错误
    public var certErrors: Bool
    /// 是否已升级 (WebSocket)
    public var upgraded: Bool

    public init() {
        aborted = false
        headerProgress = false
        responseBodyStreaming = false
        certErrors = false
        upgraded = false
    }

    /// 获取信号状态
    public func get(signal: AsyncHTTPSignalType): Bool {
        match (signal) {
            case AsyncHTTPSignalType.aborted => aborted
            case AsyncHTTPSignalType.headerProgress => headerProgress
            case AsyncHTTPSignalType.responseBodyStreaming => responseBodyStreaming
            case AsyncHTTPSignalType.certErrors => certErrors
            case AsyncHTTPSignalType.upgraded => upgraded
        }
    }
}

/// 信号类型枚举
public enum AsyncHTTPSignalType {
    | aborted
    | headerProgress
    | responseBodyStreaming
    | certErrors
    | upgraded
}

/// AsyncHTTP 选项
/// 严格翻译自: AsyncHTTP.Options
public class AsyncHTTPOptions {
    /// HTTP 代理 URL
    public var httpProxy: ?ParsedUrl
    /// 代理头部
    public var proxyHeaders: ?HeaderEntryList
    /// 自定义 hostname
    public var hostname: ?String
    /// 请求信号
    public var signals: ?AsyncHTTPSignals
    /// Unix socket 路径
    public var unixSocketPath: ?String
    /// 是否禁用超时
    public var disableTimeout: ?Bool
    /// 详细程度
    public var verbose: ?HTTPVerboseLevel
    /// 是否禁用 keep-alive
    public var disableKeepalive: ?Bool
    /// 是否禁用解压
    public var disableDecompression: ?Bool
    /// 是否验证证书
    public var rejectUnauthorized: ?Bool
    /// TLS 配置
    public var tlsProps: ?TLSConfig

    public init() {
        httpProxy = None
        proxyHeaders = None
        hostname = None
        signals = None
        unixSocketPath = None
        disableTimeout = None
        verbose = None
        disableKeepalive = None
        disableDecompression = None
        rejectUnauthorized = None
        tlsProps = None
    }
}

/// TLS 配置 (占位)
/// 对应 Bun: SSLConfig.SharedPtr
public class TLSConfig {
    public var serverName: ?String
    public var rejectUnauthorized: Bool
    public var ca: ?String
    /// 是否需要自定义请求上下文 (mTLS 等场景)
    /// 严格翻译自: SSLConfig.requires_custom_request_ctx
    public var requiresCustomRequestCtx: Bool

    public init() {
        serverName = None
        rejectUnauthorized = true
        ca = None
        requiresCustomRequestCtx = false
    }

    /// 克隆 TLS 配置 (用于缓存条目持有强引用)
    /// 严格翻译自: SSLConfig.SharedPtr.clone
    public func clone(): TLSConfig {
        let c = TLSConfig()
        c.serverName = serverName
        c.rejectUnauthorized = rejectUnauthorized
        c.ca = ca
        c.requiresCustomRequestCtx = requiresCustomRequestCtx
        return c
    }
}

/// AsyncHTTP - 异步 HTTP 请求
/// 严格翻译自: bun/src/http/AsyncHTTP.zig AsyncHTTP struct
public class AsyncHTTP {
    // ========================================================================
    // 请求/响应数据
    // ========================================================================

    /// 解析后的请求 (picohttp.Request)
    /// 严格翻译自: request: ?picohttp.Request
    public var request: ?RawRequest
    /// 解析后的响应 (picohttp.Response)
    /// 严格翻译自: response: ?picohttp.Response
    public var response: ?RawResponse
    /// 请求头部
    /// 严格翻译自: request_headers: Headers.Entry.List
    public var requestHeaders: HeaderEntryList
    /// 响应头部
    /// 严格翻译自: response_headers: Headers.Entry.List
    public var responseHeaders: HeaderEntryList
    /// 响应缓冲区
    /// 严格翻译自: response_buffer: *MutableString
    public var responseBuffer: MutableString
    /// 请求体
    /// 严格翻译自: request_body: HTTPRequestBody
    public var requestBody: HTTPRequestBody
    /// 请求头部缓冲区
    /// 严格翻译自: request_header_buf: string
    public var requestHeaderBuf: String
    /// HTTP 方法
    /// 严格翻译自: method: Method
    public var method: HttpMethod
    /// 请求 URL
    /// 严格翻译自: url: URL
    public var url: ParsedUrl

    // ========================================================================
    // 代理
    // ========================================================================

    /// HTTP 代理 URL
    /// 严格翻译自: http_proxy: ?URL
    public var httpProxy: ?ParsedUrl
    /// 真实 AsyncHTTP (用于同步调用)
    /// 严格翻译自: real: ?*AsyncHTTP
    public var real: ?AsyncHTTP
    /// 链表下一个
    /// 严格翻译自: next: ?*AsyncHTTP
    public var next: ?AsyncHTTP

    // ========================================================================
    // 任务调度
    // ========================================================================

    /// 结果回调
    /// 严格翻译自: result_callback: HTTPClientResult.Callback
    public var resultCallback: HTTPClientResultCallback
    /// 是否已重定向
    /// 严格翻译自: redirected: bool
    public var redirected: Bool

    // ========================================================================
    // 状态
    // ========================================================================

    /// 响应编码
    /// 严格翻译自: response_encoding: Encoding
    public var responseEncoding: Encoding
    /// 详细程度
    /// 严格翻译自: verbose: HTTPVerboseLevel
    public var verbose: HTTPVerboseLevel
    /// HTTP 客户端
    /// 严格翻译自: client: HTTPClient
    public var client: HTTPClient
    /// 是否在等待延迟任务
    /// 严格翻译自: waitingDeffered: bool
    public var waitingDeferred: Bool
    /// 是否已终结
    /// 严格翻译自: finalized: bool
    public var finalized: Bool
    /// 失败错误
    /// 严格翻译自: err: ?anyerror
    public var err: ?String
    /// 异步 HTTP ID
    /// 严格翻译自: async_http_id: u32
    public var asyncHttpId: UInt32

    /// 原子状态
    /// 严格翻译自: state: AtomicState
    public var state: AsyncHTTPState
    /// 经过时间 (纳秒)
    /// 严格翻译自: elapsed: u64
    public var elapsed: UInt64
    /// gzip 解压时间
    /// 严格翻译自: gzip_elapsed: u64
    public var gzipElapsed: UInt64

    /// 请求信号
    /// 严格翻译自: signals: AsyncHTTPSignals
    public var signals: AsyncHTTPSignals

    public init() {
        request = None
        response = None
        requestHeaders = HeaderEntryList()
        responseHeaders = HeaderEntryList()
        responseBuffer = MutableString()
        requestBody = HTTPRequestBody.bytes("")
        requestHeaderBuf = ""
        method = HttpMethod.GET
        url = ParsedUrl()
        httpProxy = None
        real = None
        next = None
        resultCallback = HTTPClientResultCallback()
        redirected = false
        responseEncoding = Encoding.identity
        verbose = HTTPVerboseLevel.none
        client = HTTPClient()
        waitingDeferred = false
        finalized = false
        err = None
        asyncHttpId = UInt32(0)
        state = AsyncHTTPState.pending
        elapsed = UInt64(0)
        gzipElapsed = UInt64(0)
        signals = AsyncHTTPSignals()
    }

    /// 初始化 AsyncHTTP
    /// 严格翻译自: AsyncHTTP.init
    public static func initFunc(
        method: HttpMethod,
        url: ParsedUrl,
        headers: HeaderEntryList,
        headersBuf: String,
        responseBuffer: MutableString,
        requestBodyStr: String,
        callback: HTTPClientResultCallback,
        redirectType: FetchRedirect,
        options: AsyncHTTPOptions
    ): AsyncHTTP {
        let http = AsyncHTTP()
        http.url = url
        http.method = method
        http.requestHeaders = headers
        http.requestHeaderBuf = headersBuf
        http.requestBody = HTTPRequestBody.bytes(requestBodyStr)
        http.responseBuffer = responseBuffer
        http.resultCallback = callback
        http.httpProxy = options.httpProxy
        http.signals = match (options.signals) {
            case Some(s) => s
            case None => AsyncHTTPSignals()
        }

        // 初始化 HTTPClient
        http.client.method = method.toString()
        http.client.url = url
        http.client.headerEntries = ArrayList<HeaderPair>()
        for (entry in headers.items()) {
            http.client.headerEntries.append(HeaderPair(entry.name, entry.value))
        }
        http.client.headerBuf = headersBuf
        http.client.httpProxy = options.httpProxy
        http.client.resultCallback.fn_ = Some({ _: HTTPClient, result: HTTPClientResult =>
            http.onCallback(http, result)
        })
        http.client.flags.rejectUnauthorized = match (options.rejectUnauthorized) {
            case Some(v) => v
            case None => true
        }
        http.client.flags.disableTimeout = match (options.disableTimeout) {
            case Some(v) => v
            case None => false
        }
        http.client.flags.disableKeepalive = match (options.disableKeepalive) {
            case Some(v) => v
            case None => false
        }
        http.client.flags.disableDecompression = match (options.disableDecompression) {
            case Some(v) => v
            case None => false
        }
        match (options.verbose) {
            case Some(v) =>
                http.verbose = v
                http.client.verbose = v
            case None => ()
        }
        http.client.redirectType = match (redirectType) {
            case FetchRedirect.follow => "follow"
            case FetchRedirect.manual => "manual"
            case FetchRedirect.error => "error"
        }
        http.client.signals.aborted = http.signals.aborted
        http.client.signals.headerProgress = http.signals.headerProgress
        match (options.hostname) {
            case Some(h) => http.client.hostname = Some(h)
            case None => ()
        }
        match (options.unixSocketPath) {
            case Some(path) => http.client.unixSocketPath = path
            case None => ()
        }
        match (options.proxyHeaders) {
            case Some(h) => http.client.proxyHeaders = h
            case None => ()
        }
        match (options.tlsProps) {
            case Some(tls) => http.client.tlsProps = tls.clone()
            case None => ()
        }

        return http
    }

    /// 同步初始化
    /// 严格翻译自: AsyncHTTP.initSync
    public static func initSync(
        method: HttpMethod,
        url: ParsedUrl,
        headers: HeaderEntryList,
        headersBuf: String,
        responseBuffer: MutableString,
        requestBodyStr: String,
        httpProxy: ?ParsedUrl,
        hostname: ?String,
        redirectType: FetchRedirect
    ): AsyncHTTP {
        let options = AsyncHTTPOptions()
        options.httpProxy = httpProxy
        options.hostname = hostname
        return AsyncHTTP.initFunc(
            method, url, headers, headersBuf, responseBuffer,
            requestBodyStr, HTTPClientResultCallback(), redirectType, options
        )
    }

    /// 调度到线程池
    /// 严格翻译自: AsyncHTTP.schedule
    public func schedule(batch: ThreadPoolBatch): Unit {
        state = AsyncHTTPState.scheduled
        batch.push(this)
    }

    /// 开始执行
    /// 严格翻译自: AsyncHTTP.startAsyncHTTP / AsyncHTTP.onStart
    public func onStart(): Unit {
        state = AsyncHTTPState.sending
        err = None

        // 启动 HTTPClient
        client.start(requestBody, responseBuffer)
    }

    /// AsyncHTTP 完成回调
    /// 严格翻译自: AsyncHTTP.onAsyncHTTPCallback
    public func onCallback(asyncHttp: AsyncHTTP, result: HTTPClientResult): Unit {
        redirected = client.flags.redirected

        if (result.isSuccess()) {
            err = None
            match (result.metadata) {
                case Some(meta) => response = meta.response
                case None => ()
            }
            state = AsyncHTTPState.success
        } else {
            err = result.fail
            response = None
            state = AsyncHTTPState.fail
        }

        match (real) {
            case Some(original) =>
                original.redirected = redirected
                original.err = err
                original.response = response
                original.state = state
            case None => ()
        }

        // 调用用户回调
        resultCallback.run(Some(client), result)
    }

    /// 清理数据
    /// 严格翻译自: AsyncHTTP.clearData
    public func clearData(): Unit {
        responseHeaders = HeaderEntryList()
        request = None
        response = None
    }
}

/// HTTP 频道 — 异步回调对
/// 严格翻译自: AsyncHTTP.HTTPChannel / SingleHTTPChannel
public class HTTPChannel {
    private var buffer: ArrayList<HTTPCallbackPair>
    private var capacity: Int64

    public init(capacity: Int64) {
        this.capacity = capacity
        buffer = ArrayList<HTTPCallbackPair>()
    }

    public func writeItem(pair: HTTPCallbackPair): Unit {
        buffer.append(pair)
    }

    public func readItem(): ?HTTPCallbackPair {
        if (buffer.size > 0) {
            return buffer.removeAt(0)
        }
        return None
    }
}

/// HTTP 回调对
/// 严格翻译自: AsyncHTTP.HTTPCallbackPair
public class HTTPCallbackPair {
    public var http: AsyncHTTP
    public var result: HTTPClientResult

    public init(http: AsyncHTTP, result: HTTPClientResult) {
        this.http = http
        this.result = result
    }
}

/// HTTP 频道上下文
/// 严格翻译自: AsyncHTTP.HTTPChannelContext
public class HTTPChannelContext {
    public var http: AsyncHTTP
    public var channel: HTTPChannel

    public init(http: AsyncHTTP, channel: HTTPChannel) {
        this.http = http
        this.channel = channel
    }

    public func callback(data: HTTPCallbackPair): Unit {
        channel.writeItem(data)
    }
}

/// Preconnect 结构
/// 严格翻译自: AsyncHTTP.Preconnect
public class Preconnect {
    public var asyncHttp: AsyncHTTP
    public var responseBuffer: MutableString
    public var url: ParsedUrl

    public init(asyncHttp: AsyncHTTP, responseBuffer: MutableString, url: ParsedUrl) {
        this.asyncHttp = asyncHttp
        this.responseBuffer = responseBuffer
        this.url = url
    }

    /// 预连接结果回调
    /// 严格翻译自: Preconnect.onResult
    public func onResult(asyncHttp: AsyncHTTP, result: HTTPClientResult): Unit {
        responseBuffer.reset()
        asyncHttp.clearData()
    }
}

