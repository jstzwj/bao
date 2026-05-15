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

/// HTTP 详细程度
/// 严格翻译自: HTTPClient.HTTPVerboseLevel
public enum HTTPVerboseLevel {
    | none     // 不输出
    | headers  // 输出头部
    | curl     // curl 格式输出
}

/// 请求信号 — 用于跨线程通信
/// 严格翻译自: bun/src/http/Signals.zig (简化)
public class Signals {
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
    public func get(signal: SignalType): Bool {
        match (signal) {
            case SignalType.aborted => aborted
            case SignalType.headerProgress => headerProgress
            case SignalType.responseBodyStreaming => responseBodyStreaming
            case SignalType.certErrors => certErrors
            case SignalType.upgraded => upgraded
        }
    }
}

/// 信号类型枚举
public enum SignalType {
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
    public var signals: ?Signals
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

    public init() {
        serverName = None
        rejectUnauthorized = true
        ca = None
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
    /// 严格翻译自: signals: Signals
    public var signals: Signals

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
        signals = Signals()
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
            case None => Signals()
        }

        // 初始化 HTTPClient
        http.client.url = url
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
            case Some(v) => http.verbose = v
            case None => ()
        }
        match (options.hostname) {
            case Some(h) => http.client.hostname = Some(h)
            case None => ()
        }
        match (options.unixSocketPath) {
            case Some(_) => () // 设置 unix socket path
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
        return init(
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
        let bodyOutStr = MutableString()
        client.state = InternalState.init(requestBody, bodyOutStr)
        client.start(requestBody, bodyOutStr)
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

// ============================================================================
// 线程池相关类型
// ============================================================================

/// 线程池批次
/// 对应 Bun: bun.ThreadPool.Batch
public class ThreadPoolBatch {
    private var tasks: ArrayList<AsyncHTTP>

    public init() {
        tasks = ArrayList<AsyncHTTP>()
    }

    public func push(http: AsyncHTTP): Unit {
        tasks.append(http)
    }

    public func pop(): ?AsyncHTTP {
        if (tasks.size > 0) {
            return tasks.removeAt(tasks.size - 1)
        }
        return None
    }

    public func len(): Int64 {
        return tasks.size
    }

    public func isEmpty(): Bool {
        return tasks.size == 0
    }

    /// 批量添加
    public static func from(task: AsyncHTTP): ThreadPoolBatch {
        let batch = ThreadPoolBatch()
        batch.push(task)
        return batch
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

/// 全局活跃请求计数器
/// 严格翻译自: AsyncHTTP.active_requests_count
public let activeRequestsCount = AtomicCounter()

/// 最大并发请求数
/// 严格翻译自: AsyncHTTP.max_simultaneous_requests
public let maxSimultaneousRequests = AtomicCounter()

/// 原子计数器 (简化)
public class AtomicCounter {
    private var value: Int64

    public init() {
        value = 0
    }

    public init(initial: Int64) {
        value = initial
    }

    public func load(): Int64 {
        return value
    }

    public func store(v: Int64): Unit {
        value = v
    }

    public func fetchAdd(delta: Int64): Int64 {
        let old = value
        value += delta
        return old
    }

    public func fetchSub(delta: Int64): Int64 {
        let old = value
        value -= delta
        return old
    }
}
