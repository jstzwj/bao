// 严格翻译自: src/runtime/webcore/s3/download_stream.zig
// S3HttpDownloadStreamingTask - S3 流式下载任务
// 通过 HTTP 流式下载 S3 对象，支持回调式数据报告
package bao_runtime.webcore.s3

import bao_core.*
import bao_collections.*
import bao_jsc.*

// ============================================================================
// S3DownloadState - 下载流状态
// 严格翻译自: S3HttpDownloadStreamingTask.State (packed struct(u64))
// Bun: pub const State = packed struct(u64) {
//   status_code: u32 = 0, request_error: u16 = 0,
//   has_more: bool = true, _reserved: u15 = 0
// }
// ============================================================================

/// 下载流状态
/// 对应 Bun: State packed struct(u64)
/// 使用原子操作进行线程安全的状态管理
public class S3DownloadState {
    /// HTTP 状态码
    /// 对应 Bun: status_code: u32 = 0
    public var statusCode: UInt32 = 0

    /// 请求错误码
    /// 对应 Bun: request_error: u16 = 0
    public var requestError: UInt16 = 0

    /// 是否还有更多数据
    /// 对应 Bun: has_more: bool = true
    public var hasMore: Bool = true

    public init() {}

    public init(statusCode: UInt32, requestError: UInt16, hasMore: Bool) {
        this.statusCode = statusCode
        this.requestError = requestError
        this.hasMore = hasMore
    }
}

// ============================================================================
// S3HttpDownloadStreamingTask - S3 流式下载任务
// 严格翻译自: S3HttpDownloadStreamingTask struct
// Bun: pub const S3HttpDownloadStreamingTask = struct { ... }
// ============================================================================

/// S3 HTTP 下载流式任务
/// 对应 Bun: S3HttpDownloadStreamingTask
/// 使用 HTTP 流式下载 S3 对象，通过回调函数逐步报告下载的数据
/// 支持线程安全的状态管理和互斥访问
public class S3HttpDownloadStreamingTask {
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

    /// 回调上下文 (不透明指针)
    /// 对应 Bun: callback_context: *anyopaque
    public var callbackContext: UIntNative = 0

    /// 数据回调函数
    /// 对应 Bun: callback: *const fn (chunk: bun.MutableString, has_more: bool, err: ?S3Error, *anyopaque) void
    public var callback: (MutableString, Bool, ?S3Error, UIntNative) -> Unit

    /// 是否已调度回调
    /// 对应 Bun: has_schedule_callback: std.atomic.Value(bool)
    public var hasScheduleCallback: Bool = false

    /// 信号存储
    /// 对应 Bun: signal_store: bun.http.Signals.Store
    public var signalStore: SignalStore

    /// 信号
    /// 对应 Bun: signals: bun.http.Signals
    public var signals: HttpSignals

    /// 轮询引用 (保持事件循环活跃)
    /// 对应 Bun: poll_ref: bun.Async.KeepAlive
    public var pollRef: KeepAlive

    /// 响应缓冲区
    /// 对应 Bun: response_buffer: bun.MutableString
    public var responseBuffer: MutableString

    /// 互斥锁 (保护并发访问)
    /// 对应 Bun: mutex: bun.Mutex
    public var mutex: Mutex

    /// 已报告的响应缓冲区
    /// 对应 Bun: reported_response_buffer: bun.MutableString
    public var reportedResponseBuffer: MutableString

    /// 状态 (原子)
    /// 对应 Bun: state: State.AtomicType
    public var state: S3DownloadState

    /// 并发任务
    /// 对应 Bun: concurrent_task: jsc.ConcurrentTask
    public var concurrentTask: ConcurrentTask

    /// HTTP Range 头
    /// 对应 Bun: range: ?[]const u8
    public var range: String

    /// 代理 URL
    /// 对应 Bun: proxy_url: []const u8
    public var proxyUrl: String

    public init(vm: VirtualMachine, signResult: S3SignResult) {
        this.vm = vm
        this.signResult = signResult
        http = AsyncHttp()
        headers = HttpHeaders()
        responseBuffer = MutableString()
        reportedResponseBuffer = MutableString()
        state = S3DownloadState()
        concurrentTask = ConcurrentTask()
        range = ""
        proxyUrl = ""
        mutex = Mutex()
        pollRef = KeepAlive()
        signalStore = SignalStore()
        signals = HttpSignals()
        callback = { _: MutableString, _: Bool, _: ?S3Error, _: UIntNative => }
    }

    // ========================================================================
    // getState - 获取当前状态
    // 严格翻译自: pub fn getState(this: @This()) State
    // ========================================================================

    /// 获取当前状态
    /// 对应 Bun: pub fn getState(this: @This()) State
    public func getState(): S3DownloadState {
        return state
    }

    // ========================================================================
    // setState - 设置状态
    // 严格翻译自: pub fn setState(this: *@This(), state: State) void
    // ========================================================================

    /// 设置状态
    /// 对应 Bun: pub fn setState(this: *@This(), state: State) void
    public func setState(newState: S3DownloadState): Unit {
        state = newState
    }

    // ========================================================================
    // deinit - 释放资源
    // 严格翻译自: pub fn deinit(this: *@This()) void
    // ========================================================================

    /// 释放资源
    /// 对应 Bun: pub fn deinit(this: *@This()) void
    /// 释放 poll_ref、response_buffer、reported_response_buffer、headers、
    /// sign_result、http 数据、range、proxy_url
    public func deinit(): Unit {
        pollRef.unref(vm)
        responseBuffer.deinit()
        reportedResponseBuffer.deinit()
        headers.deinit()
        signResult.deinit()
        http.clearData()
        range = ""
        if (proxyUrl.length > 0) {
            proxyUrl = ""
        }
    }

    // ========================================================================
    // reportProgress - 报告下载进度
    // 严格翻译自: fn reportProgress(this: *@This(), state: State) void
    // ========================================================================

    /// 报告下载进度
    /// 对应 Bun: fn reportProgress(this: *@This(), state: State) void
    /// 根据 HTTP 状态码和请求错误判断是否失败：
    /// - 200/204/206: 正常，除非有 request_error
    /// - 其他: 失败
    /// 失败时从 XML 响应体中解析 <Code> 和 <Message>
    public func reportProgress(state: S3DownloadState): Unit {
        let hasMore = state.hasMore
        var err: ?S3Error = None
        var failed = false

        // 判断是否失败
        match (state.statusCode) {
            case 200 => failed = state.requestError != 0
            case 204 => failed = state.requestError != 0
            case 206 => failed = state.requestError != 0
            case _ => failed = true
        }

        if (failed) {
            if (!hasMore) {
                var code = "UnknownError"
                var message = "an unexpected error has occurred"
                var hasBodyCode = false
                var hasBodyMessage = false

                if (state.requestError != 0) {
                    code = "RequestError"
                    hasBodyCode = true
                } else {
                    let bytes = reportedResponseBuffer.slice()
                    if (bytes.length > 0) {
                        message = bytes

                        // 解析 XML <Code>...</Code>
                        let codeStart = bytes.indexOf("<Code>")
                        if (codeStart >= 0) {
                            let codeEnd = bytes.indexOf("</Code>")
                            if (codeEnd > codeStart) {
                                let startIdx = codeStart + "<Code>".length
                                code = bytes.substring(startIdx, codeEnd)
                                hasBodyCode = true
                            }
                        }

                        // 解析 XML <Message>...</Message>
                        let msgStart = bytes.indexOf("<Message>")
                        if (msgStart >= 0) {
                            let msgEnd = bytes.indexOf("</Message>")
                            if (msgEnd > msgStart) {
                                let startIdx = msgStart + "<Message>".length
                                message = bytes.substring(startIdx, msgEnd)
                                hasBodyMessage = true
                            }
                        }
                    }
                }

                err = Some(S3Error(code, message))
            }
            let emptyChunk = MutableString()
            if (!hasMore) {
                callback(emptyChunk, false, err, callbackContext)
            }
        } else {
            let chunk = reportedResponseBuffer
            // 不报告空块（除非这是最后一块）
            if (!hasMore || chunk.length() > 0) {
                callback(chunk, hasMore, None, callbackContext)
                reportedResponseBuffer.reset()
            }
        }
    }

    // ========================================================================
    // onResponse - 主线程上的任务回调
    // 严格翻译自: pub fn onResponse(this: *@This()) void
    // ========================================================================

    /// 响应回调 (在主线程上执行)
    /// 对应 Bun: pub fn onResponse(this: *@This()) void
    /// 加锁后加载状态，报告进度，如果没有更多数据则释放资源
    public func onResponse(): Unit {
        mutex.lock()
        let currentState = getState()
        let hasMore = currentState.hasMore

        // 如果有更多数据，重置调度标志
        if (hasMore) {
            hasScheduleCallback = false
        }
        reportProgress(currentState)

        mutex.unlock()
        // 没有更多数据时释放资源
        if (!hasMore) {
            deinit()
        }
    }

    // ========================================================================
    // updateState - 更新状态 (在 HTTP 线程上调用)
    // 严格翻译自: fn updateState(this, async_http, result, state) bool
    // ========================================================================

    /// 更新状态
    /// 对应 Bun: fn updateState(this: *@This(), async_http: *bun.http.AsyncHTTP, result: bun.http.HTTPClientResult, state: *State) bool
    /// 返回 true 表示应等到缓冲完成再报告
    public func updateState(asyncHttp: AsyncHttp, result: HttpClientResult, state: S3DownloadState): Bool {
        let isDone = !result.hasMore
        var waitUntilDone = false

        state.hasMore = !isDone
        state.requestError = if (result.fail) 1 else 0

        if (state.statusCode == 0) {
            if (result.metadata != None) {
                state.statusCode = result.metadata.response.statusCode
            }
        }

        match (state.statusCode) {
            case 200 => waitUntilDone = state.requestError != 0
            case 204 => waitUntilDone = state.requestError != 0
            case 206 => waitUntilDone = state.requestError != 0
            case _ => waitUntilDone = true
        }

        setState(state)
        http = asyncHttp
        return waitUntilDone
    }

    // ========================================================================
    // processHttpCallback - 处理 HTTP 回调 (在 HTTP 线程上调用)
    // 严格翻译自: fn processHttpCallback(this, async_http, result) bool
    // ========================================================================

    /// 处理 HTTP 回调
    /// 对应 Bun: fn processHttpCallback(this: *@This(), async_http: *bun.http.AsyncHTTP, result: bun.http.HTTPClientResult) bool
    /// 返回 true 表示应入队另一个任务
    public func processHttpCallback(asyncHttp: AsyncHttp, result: HttpClientResult): Bool {
        mutex.lock()

        var currentState = getState()
        let isDone = !result.hasMore
        let waitUntilDone = updateState(asyncHttp, result, currentState)
        let shouldEnqueue = !waitUntilDone || isDone

        if (shouldEnqueue) {
            if (result.body != None) {
                let body = result.body
                responseBuffer = body
                if (body.length() > 0) {
                    reportedResponseBuffer.write(body.slice())
                }
                responseBuffer.reset()
                if (reportedResponseBuffer.length() == 0 && !isDone) {
                    mutex.unlock()
                    return false
                }
            } else if (!isDone) {
                mutex.unlock()
                return false
            }
            if (hasScheduleCallback) {
                mutex.unlock()
                return false
            }
            hasScheduleCallback = true
            mutex.unlock()
            return true
        }

        mutex.unlock()
        return false
    }

    // ========================================================================
    // httpCallback - HTTP 线程回调
    // 严格翻译自: pub fn httpCallback(this, async_http, result) void
    // ========================================================================

    /// HTTP 回调 (从 HTTP 线程调用)
    /// 对应 Bun: pub fn httpCallback(this: *@This(), async_http: *bun.http.AsyncHTTP, result: bun.http.HTTPClientResult) void
    public func httpCallback(asyncHttp: AsyncHttp, result: HttpClientResult): Unit {
        if (processHttpCallback(asyncHttp, result)) {
            vm.eventLoop().enqueueTaskConcurrent(concurrentTask.from(this))
        }
    }
}
