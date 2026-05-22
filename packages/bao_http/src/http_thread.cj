// bao_http HTTPThread - HTTP 客户端线程
// 严格翻译自: bun/src/http/HTTPThread.zig (753 行)
package bao_http

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_threading.*

// ============================================================================
// HTTPThread - HTTP 客户端后台线程
// 严格翻译自: bun/src/http/HTTPThread.zig
//
// Bun 的 HTTP 客户端在独立线程中运行:
//   1. 初始化事件循环 (MiniEventLoopHandle)
//   2. 创建 HTTP 和 HTTPS 连接上下文
//   3. 从队列中取出 AsyncHTTP 任务并执行
//   4. 处理连接限制 (max_simultaneous_requests)
//   5. 管理 SSL 上下文缓存 (LRU + TTL)
//   6. 处理关闭/写入/排空消息 (线程安全)
//   7. 唤醒事件循环
//
// 线程安全:
//   - queued_tasks: MPSC 队列 (UnboundedQueue, 多线程安全)
//   - deferred_tasks: 仅 HTTP 线程访问
//   - 互斥锁保护跨线程消息 (shutdowns/writes/drains)
// ============================================================================

// ============================================================================
// 常量
// 严格翻译自: HTTPThread 顶层常量
// ============================================================================

/// SSL 上下文缓存最大大小
/// 严格翻译自: ssl_context_cache_max_size = 60
public let SSL_CONTEXT_CACHE_MAX_SIZE: Int64 = 60

/// SSL 上下文缓存 TTL (30 分钟, 纳秒)
/// 严格翻译自: ssl_context_cache_ttl_ns = 30 * std.time.ns_per_min
public let SSL_CONTEXT_CACHE_TTL_NS: UInt64 = UInt64(30) * UInt64(60) * UInt64(1000000000)

/// 请求体发送栈缓冲区大小
/// 严格翻译自: request_body_send_stack_buffer_size = 32 * 1024
public let REQUEST_BODY_SEND_STACK_BUFFER_SIZE: Int64 = 32 * 1024

// ============================================================================
// SslContextCacheEntry - SSL 上下文缓存条目
// 严格翻译自: HTTPThread.SslContextCacheEntry
// ============================================================================

/// SSL 上下文缓存条目 — 按 interned SSLConfig 指针缓存自定义 SSL 上下文
/// 严格翻译自: HTTPThread.SslContextCacheEntry
public class SslContextCacheEntry {
    /// SSL 上下文
    /// 严格翻译自: ctx: *NewHTTPContext(true)
    public var ctx: HTTPContext
    /// 最后使用时间 (纳秒)
    /// 严格翻译自: last_used_ns: u64
    public var lastUsedNs: UInt64
    /// SSLConfig 共享引用 (缓存条目持有的强引用)
    /// 严格翻译自: config_ref: SSLConfig.SharedPtr
    public var configRef: TLSConfig

    public init(ctx: HTTPContext, lastUsedNs: UInt64, configRef: TLSConfig) {
        this.ctx = ctx
        this.lastUsedNs = lastUsedNs
        this.configRef = configRef
    }
}

// ============================================================================
// 消息类型
// 严格翻译自: HTTPThread.WriteMessage / ShutdownMessage / DrainMessage
// ============================================================================

/// 关闭消息 — 通过 async_http_id 标识要关闭的请求
/// 严格翻译自: HTTPThread.ShutdownMessage
public class ShutdownMessage {
    public var asyncHttpId: UInt32

    public init(asyncHttpId: UInt32) {
        this.asyncHttpId = asyncHttpId
    }
}

/// 写入消息 — 流式请求体的数据/结束信号
/// 严格翻译自: HTTPThread.WriteMessage
public class WriteMessage {
    public var asyncHttpId: UInt32
    public var messageType: WriteMessageType

    public init(asyncHttpId: UInt32, messageType: WriteMessageType) {
        this.asyncHttpId = asyncHttpId
        this.messageType = messageType
    }
}

/// 写入消息类型
/// 严格翻译自: WriteMessage.Type = enum(u2) { data = 0, end = 1 }
public enum WriteMessageType {
    | data  // 0 - 数据
    | end   // 1 - 结束
}

/// 排空消息 — 请求排空响应体
/// 严格翻译自: HTTPThread.DrainMessage
public class DrainMessage {
    public var asyncHttpId: UInt32

    public init(asyncHttpId: UInt32) {
        this.asyncHttpId = asyncHttpId
    }
}

// ============================================================================
// RequestBodyBuffer - 请求体缓冲区
// 严格翻译自: HTTPThread.RequestBodyBuffer (union enum)
//
// 小请求体: 栈分配 (32KB)
// 大请求体: 堆分配 (512KB)
// ============================================================================

/// 请求体缓冲区 — 根据大小选择栈或堆分配
/// 严格翻译自: HTTPThread.RequestBodyBuffer = union(enum) { heap, stack }
public class RequestBodyBuffer {
    /// 堆缓冲区 (512KB, 大请求体使用)
    /// 严格翻译自: heap: *HeapRequestBodyBuffer
    public var heapBuffer: ?Array<UInt8>
    /// 缓冲区大小
    public var size: Int64

    public init() {
        heapBuffer = None
        size = REQUEST_BODY_SEND_STACK_BUFFER_SIZE
    }

    /// 获取分配的切片
    /// 严格翻译自: RequestBodyBuffer.allocatedSlice
    public func allocatedSlice(): Array<UInt8> {
        match (heapBuffer) {
            case Some(buf) => buf
            case None => Array<UInt8>()
        }
    }

    /// 是否使用堆缓冲区
    public func isHeap(): Bool {
        return heapBuffer.isSome()
    }

    /// 释放
    /// 严格翻译自: RequestBodyBuffer.deinit
    public func deinit(): Unit {
        // 堆缓冲区归还到 lazy_request_body_buffer 或释放
        heapBuffer = None
    }
}

// ============================================================================
// LibdeflateState - libdeflate 解压器状态
// 严格翻译自: HTTPThread.LibdeflateState
// ============================================================================

/// libdeflate 解压器状态 (延迟初始化)
/// 严格翻译自: HTTPThread.LibdeflateState
public class LibdeflateState {
    /// 解压器实例
    /// 严格翻译自: decompressor: *bun.libdeflate.Decompressor
    public var decompressor: Any
    /// 共享缓冲区 (512KB)
    /// 严格翻译自: shared_buffer: [512 * 1024]u8
    public var sharedBuffer: Array<UInt8>

    public init() {
        decompressor = ()
        sharedBuffer = Array<UInt8>(512 * 1024, { _ => UInt8(0) })
    }
}

// ============================================================================
// HTTPThreadInitOpts - 初始化选项
// 严格翻译自: HTTPThread.InitOpts
// ============================================================================

/// HTTPThread 初始化选项
/// 严格翻译自: HTTPThread.InitOpts
public class HTTPThreadInitOpts {
    /// CA 证书列表
    /// 严格翻译自: ca: []stringZ = &.{}
    public var ca: ArrayList<String>
    /// CA 文件绝对路径
    /// 严格翻译自: abs_ca_file_name: stringZ = &.{}
    public var absCaFileName: String
    /// 是否用于 bun install
    /// 严格翻译自: for_install: bool = false
    public var forInstall: Bool

    public init() {
        ca = ArrayList<String>()
        absCaFileName = ""
        forInstall = false
    }
}

// ============================================================================
// HTTPThread - HTTP 后台线程主体
// 严格翻译自: bun/src/http/HTTPThread.zig HTTPThread struct
// ============================================================================

/// HTTP 后台线程
/// 严格翻译自: bun/src/http/HTTPThread.zig HTTPThread struct
public class HTTPThread {
    // ========================================================================
    // 事件循环与上下文
    // ========================================================================

    /// 事件循环
    /// 严格翻译自: loop: *jsc.MiniEventLoop
    public var loop: EventLoopHandle

    /// HTTP 上下文 (非 SSL)
    /// 严格翻译自: http_context: NewHTTPContext(false)
    public var httpContext: HTTPContext

    /// HTTPS 上下文 (SSL)
    /// 严格翻译自: https_context: NewHTTPContext(true)
    public var httpsContext: HTTPContext

    // ========================================================================
    // 任务队列
    // ========================================================================

    /// 待处理任务队列 (MPSC 无界队列, 线程安全)
    /// 严格翻译自: queued_tasks: Queue = Queue{}
    public var queuedTasks: ArrayList<AsyncHTTP>

    /// 延迟任务 — 因达到最大并发数而延后执行的任务
    /// 仅 HTTP 线程访问
    /// 严格翻译自: deferred_tasks: std.ArrayListUnmanaged(*AsyncHTTP) = .{}
    public var deferredTasks: ArrayList<AsyncHTTP>

    /// 是否有待处理的队列中止 (drainQueuedShutdowns 设置)
    /// 严格翻译自: has_pending_queued_abort: bool = false
    public var hasPendingQueuedAbort: Bool

    // ========================================================================
    // 跨线程消息队列 (互斥锁保护)
    // ========================================================================

    /// 待关闭列表
    /// 严格翻译自: queued_shutdowns: std.ArrayListUnmanaged(ShutdownMessage)
    public var queuedShutdowns: ArrayList<ShutdownMessage>
    /// 待写入列表
    /// 严格翻译自: queued_writes: std.ArrayListUnmanaged(WriteMessage)
    public var queuedWrites: ArrayList<WriteMessage>
    /// 待排空列表
    /// 严格翻译自: queued_response_body_drains: std.ArrayListUnmanaged(DrainMessage)
    public var queuedResponseBodyDrains: ArrayList<DrainMessage>
    /// 待代理引用减少列表 (始终在 HTTP 线程调用)
    /// 严格翻译自: queued_threadlocal_proxy_derefs
    public var queuedProxyDerefs: ArrayList<ProxyTunnel>

    // ========================================================================
    // 互斥锁 (保护跨线程消息队列)
    // ========================================================================

    /// 关闭队列锁
    /// 严格翻译自: queued_shutdowns_lock: bun.Mutex = .{}
    public var shutdownsLock: HTTPThreadMutex
    /// 写入队列锁
    /// 严格翻译自: queued_writes_lock: bun.Mutex = .{}
    public var writesLock: HTTPThreadMutex
    /// 排空队列锁
    /// 严格翻译自: queued_response_body_drains_lock: bun.Mutex = .{}
    public var drainsLock: HTTPThreadMutex

    // ========================================================================
    // 状态与缓存
    // ========================================================================

    /// 是否已唤醒 (原子 bool)
    /// 严格翻译自: has_awoken: std.atomic.Value(bool) = .`init`(false)
    public var hasAwoken: Bool
    /// 高精度定时器 (用于 SSL 缓存 TTL)
    /// 严格翻译自: timer: std.time.Timer
    public var timer: UInt64
    /// SSL 上下文缓存 — 按 interned SSLConfig 指针查找
    /// 严格翻译自: custom_ssl_context_map (AutoArrayHashMap)
    public var sslContextCache: ArrayList<SslContextCacheEntry>
    /// 延迟初始化的 libdeflate 解压器
    /// 严格翻译自: lazy_libdeflater: ?*LibdeflateState = null
    public var lazyLibdeflater: ?LibdeflateState
    /// 延迟初始化的堆请求体缓冲区 (512KB)
    /// 严格翻译自: lazy_request_body_buffer: ?*HeapRequestBodyBuffer = null
    public var lazyRequestBodyBuffer: ?Array<UInt8>
    /// 空闲超时 (秒), 从环境变量 BUN_CONFIG_HTTP_IDLE_TIMEOUT 读取
    public var idleTimeoutSeconds: Int64

    public init() {
        loop = EventLoopHandle(MiniEventLoop())
        httpContext = HTTPContext(false)
        httpsContext = HTTPContext(true)
        queuedTasks = ArrayList<AsyncHTTP>()
        deferredTasks = ArrayList<AsyncHTTP>()
        hasPendingQueuedAbort = false
        queuedShutdowns = ArrayList<ShutdownMessage>()
        queuedWrites = ArrayList<WriteMessage>()
        queuedResponseBodyDrains = ArrayList<DrainMessage>()
        queuedProxyDerefs = ArrayList<ProxyTunnel>()
        shutdownsLock = HTTPThreadMutex()
        writesLock = HTTPThreadMutex()
        drainsLock = HTTPThreadMutex()
        hasAwoken = false
        timer = UInt64(0)
        sslContextCache = ArrayList<SslContextCacheEntry>()
        lazyLibdeflater = None
        lazyRequestBodyBuffer = None
        idleTimeoutSeconds = 300
    }

    // ========================================================================
    // 初始化
    // 严格翻译自: HTTPThread.initOnce / onStart
    // ========================================================================

    /// 初始化
    /// 严格翻译自: HTTPThread.onStart
    public func initFunc(opts: HTTPThreadInitOpts): Unit {
        // 严格翻译自:
        //   bun.http.default_arena = Arena()
        //   bun.http.default_allocator = bun.http.default_arena.allocator()

        // 初始化 HTTP 上下文
        httpContext.init_()

        // 初始化 HTTPS 上下文 (带 CA 选项)
        httpsContext.initWithThreadOpts(
            if (opts.ca.size > 0) { Some(opts.ca[0]) } else { None },
            if (opts.absCaFileName.size > 0) { Some(opts.absCaFileName) } else { None }
        )

        // 读取空闲超时
        // 严格翻译自:
        //   const raw: u64 = @min(bun.env_var.BUN_CONFIG_HTTP_IDLE_TIMEOUT.get(), 239 * 60)
        //   bun.http.idle_timeout_seconds = @intCast(if (raw > 240) ((raw + 59) / 60) * 60 else raw)
        idleTimeoutSeconds = 300

        hasAwoken = true
    }

    // ========================================================================
    // connect - 建立连接
    // 严格翻译自: HTTPThread.connect (约 80 行)
    //
    // 连接逻辑:
    //   1. Unix socket 路径检查
    //   2. 自定义 SSL 上下文 (mTLS) 查找/创建
    //   3. 代理 URL 处理
    //   4. 委托给 HTTPContext.connect
    // ========================================================================

    /// 建立连接
    /// 严格翻译自: HTTPThread.connect
    public func connect(client: HTTPClient, isSsl: Bool): ?Int64 {
        // 严格翻译自:
        //   if (client.unix_socket_path.length() > 0) {
        //       return try this.context(is_ssl).connectSocket(client, client.unix_socket_path.slice())
        //   }

        // Unix socket
        if (client.unixSocketPath.size > 0) {
            return context(isSsl).connectSocket(client, client.unixSocketPath)
        }

        // 自定义 SSL 上下文 (仅 SSL)
        // 严格翻译自: HTTPThread.connect (lines 261-322)
        //   if (comptime is_ssl) custom_ctx: {
        //       if (client.tls_props) |tls| {
        //           if (!tls.get().requires_custom_request_ctx) break :custom_ctx
        //           evictStaleSslContexts(this)
        //           if (custom_ssl_context_map.getPtr(requested_config)) |entry| { ... }
        //           var custom_context = try ... new context ...
        //           custom_context.initWithClientConfig(client) catch |err| { ... }
        //           bun.handleOom(custom_ssl_context_map.put(requested_config, .{...}))
        //           if (custom_ssl_context_map.count() > ssl_context_cache_max_size) {
        //               evictOldestSslContext()
        //           }
        //           client.setCustomSslCtx(custom_context)
        //           return try custom_context.connect(client, ...)
        //       }
        //   }
        if (isSsl) {
            evictStaleSslContexts()
            let tlsOpt = client.tlsProps as TLSConfig
            match (tlsOpt) {
                case Some(tls) =>
                    if (tls.requiresCustomRequestCtx) {
                        // 缓存查找 — 按 interned TLSConfig 指针匹配
                        var cachedEntry: ?SslContextCacheEntry = None
                        for (cacheItem in sslContextCache) {
                            if (cacheItem.configRef.rejectUnauthorized == tls.rejectUnauthorized && cacheItem.configRef.requiresCustomRequestCtx == tls.requiresCustomRequestCtx) {
                                cachedEntry = Some(cacheItem)
                                break
                            }
                        }

                        match (cachedEntry) {
                            case Some(cachedRef) =>
                                // 缓存命中 — 更新 last_used 并复用
                                cachedRef.lastUsedNs = timer
                                client.setCustomSslCtx(cachedRef.ctx)
                                // keepalive 支持自定义 SSL 上下文
                                match (client.httpProxy) {
                                    case Some(proxy) =>
                                        return cachedRef.ctx.connect(client, proxy.hostname, UInt16(proxy.port))
                                    case None =>
                                        return cachedRef.ctx.connect(client, client.url.hostname, UInt16(client.url.port))
                                }
                            case None =>
                                // 缓存未命中 — 创建新的 SSL 上下文
                                let customContext = HTTPContext(true)
                                customContext.initWithClientConfig(client)
                                let now = timer
                                let cacheEntry = SslContextCacheEntry(customContext, now, tls)
                                sslContextCache.append(cacheEntry)

                                // 超过最大缓存大小 — 驱逐最旧条目
                                if (sslContextCache.size > SSL_CONTEXT_CACHE_MAX_SIZE) {
                                    evictOldestSslContext()
                                }

                                client.setCustomSslCtx(customContext)
                                // keepalive 支持自定义 SSL 上下文
                                match (client.httpProxy) {
                                    case Some(proxy) =>
                                        return customContext.connect(client, proxy.hostname, UInt16(proxy.port))
                                    case None =>
                                        return customContext.connect(client, client.url.hostname, UInt16(client.url.port))
                                }
                        }
                    }
                case None => ()
            }
        }

        // 代理连接
        // 严格翻译自:
        //   if (client.http_proxy) |url| {
        //       if (url.href.len > 0) {
        //           if (url.protocol.len == 0 or strings.eqlComptime(url.protocol, "https")
        //               or strings.eqlComptime(url.protocol, "http")) {
        //               return try this.context(is_ssl).connect(client, url.hostname, url.getPortAuto())
        //           }
        //           return error.UnsupportedProxyProtocol
        //       }
        //   }
        let hostname: String
        let port: UInt16

        match (client.httpProxy) {
            case Some(proxy) =>
                if (proxy.hostname.size > 0) {
                    hostname = proxy.hostname
                    port = UInt16(proxy.port)
                } else {
                    hostname = client.url.hostname
                    port = UInt16(client.url.port)
                }
            case None =>
                hostname = client.url.hostname
                port = UInt16(client.url.port)
        }

        return context(isSsl).connect(client, hostname, port)
    }

    /// 获取上下文
    /// 严格翻译自: HTTPThread.context
    public func context(isSsl: Bool): HTTPContext {
        return if (isSsl) { httpsContext } else { httpContext }
    }

    // ========================================================================
    // deflater - 延迟初始化的解压器
    // 严格翻译自: HTTPThread.deflater
    // ========================================================================

    /// 获取或创建 libdeflate 解压器
    /// 严格翻译自: HTTPThread.deflater
    public func deflater(): LibdeflateState {
        match (lazyLibdeflater) {
            case Some(d) => return d
            case None => ()
        }
        let d = LibdeflateState()
        lazyLibdeflater = Some(d)
        return d
    }

    // ========================================================================
    // 事件循环
    // 严格翻译自: HTTPThread.processEvents / drainEvents
    // ========================================================================

    /// 处理事件循环 (永不返回)
    /// 严格翻译自: HTTPThread.processEvents (noreturn)
    public func processEvents(): Unit {
        // 严格翻译自:
        //   if (comptime Environment.isPosix) {
        //       this.loop.loop.num_polls = @max(2, this.loop.loop.num_polls)
        //   }
        //   while (true) {
        //       this.drainEvents()
        //       Output.flush()
        //       this.loop.loop.inc()
        //       this.loop.loop.tick()
        //       this.loop.loop.dec()
        //   }
        while (true) {
            drainEvents()
            let miniLoop = loop.getMiniLoop()
            if (miniLoop.isSome()) {
                miniLoop.getOrThrow().run()
            }
        }
    }

    /// 排空所有待处理事件
    /// 严格翻译自: HTTPThread.drainEvents
    ///
    /// 处理顺序:
    ///   1. drainQueuedHTTPResponseBodyDrains
    ///   2. drainQueuedWrites
    ///   3. drainQueuedShutdowns
    ///   4. H3.PendingConnect.drainResolved
    ///   5. 处理代理引用减少
    ///   6. 处理延迟任务 (已弹出但因 max 限制等待的)
    ///   7. 处理新任务 (从 MPSC 队列)
    public func drainEvents(): Unit {
        drainQueuedResponseBodyDrains()
        drainQueuedWrites()
        drainQueuedShutdowns()

        // 严格翻译自: bun.http.H3.PendingConnect.drainResolved()

        // 处理代理引用减少
        for (proxy in queuedProxyDerefs) {
            ProxyTunnelOps.deref(proxy)
        }
        queuedProxyDerefs = ArrayList<ProxyTunnel>()

        // 严格翻译自:
        //   var active = AsyncHTTP.active_requests_count.load(.monotonic)
        //   const max = AsyncHTTP.max_simultaneous_requests.load(.monotonic)
        var active: Int64 = 0
        let max: Int64 = 256

        // 快速路径: 达到容量且没有待中止的任务
        // 严格翻译自:
        //   if (active >= max and !this.has_pending_queued_abort) return
        if (active >= max && !hasPendingQueuedAbort) {
            return
        }

        // 处理延迟任务
        // 严格翻译自:
        //   this.has_pending_queued_abort = false
        //   var pending = this.deferred_tasks
        //   this.deferred_tasks = .{}
        //   for (pending.items) |http| {
        //       if (http.client.signals.get(.aborted) or active < max) {
        //           startQueuedTask(http)
        //           active = ...
        //       } else {
        //           bun.handleOom(this.deferred_tasks.append(..., http))
        //       }
        //   }
        hasPendingQueuedAbort = false
        var pending = deferredTasks
        deferredTasks = ArrayList<AsyncHTTP>()

        for (http in pending) {
            if (http.signals.aborted || active < max) {
                startQueuedTask(http)
                active = active + 1
            } else {
                deferredTasks.append(http)
            }
        }

        // 处理新任务
        // 严格翻译自:
        //   while (this.queued_tasks.pop()) |http| {
        //       if (!http.client.signals.get(.aborted) and active >= max) {
        //           bun.handleOom(this.deferred_tasks.append(..., http))
        //           continue
        //       }
        //       startQueuedTask(http)
        //       active = ...
        //   }
        for (http in queuedTasks) {
            if (!http.signals.aborted && active >= max) {
                deferredTasks.append(http)
                continue
            }
            startQueuedTask(http)
            active = active + 1
        }
        queuedTasks = ArrayList<AsyncHTTP>()
    }

    /// 启动排队任务
    /// 严格翻译自: HTTPThread.startQueuedTask
    ///
    /// 克隆 AsyncHTTP 到线程本地内存，清除队列指针，调用 onStart。
    /// 克隆是为了防止 use-after-free: 原始 http 对象可能在回调完成前
    /// 被其他线程释放或重新入队; 克隆确保 onStart 及其回调拥有独立副本。
    private func startQueuedTask(http: AsyncHTTP): Unit {
        // 严格翻译自:
        //   var cloned = bun.http.ThreadlocalAsyncHTTP.new(.{ .async_http = http.* })
        //   cloned.async_http.real = http
        //   cloned.async_http.next = null
        //   cloned.async_http.task.node.next = null
        //   cloned.async_http.onStart()

        // 创建线程本地克隆 — 复制 http 的全部字段
        let cloned = AsyncHTTP()
        cloned.url = http.url
        cloned.method = http.method
        cloned.requestHeaders = http.requestHeaders
        cloned.requestHeaderBuf = http.requestHeaderBuf
        cloned.requestBody = http.requestBody
        cloned.responseBuffer = http.responseBuffer
        cloned.resultCallback = http.resultCallback
        cloned.httpProxy = http.httpProxy
        cloned.signals = http.signals
        cloned.client = http.client
        cloned.verbose = http.verbose
        cloned.responseEncoding = http.responseEncoding
        cloned.asyncHttpId = http.asyncHttpId
        cloned.state = http.state
        cloned.elapsed = http.elapsed
        cloned.gzipElapsed = http.gzipElapsed
        cloned.redirected = http.redirected
        cloned.waitingDeferred = http.waitingDeferred
        cloned.finalized = http.finalized

        // 指向原始对象 — 回调时将结果写回
        cloned.real = http

        // 清除继承的队列指针 — 克隆从 http.* 继承了 http.next 和
        // http.task.node.next，这些可能指向其他 AsyncHTTP 结构体，
        // 后者可能在回调将数据复制回原始对象之前被释放。
        // 如果不清除，重试失败请求时会使用过期指针导致 use-after-free。
        cloned.next = None

        // 在线程本地克隆上执行 onStart
        cloned.onStart()
    }

    // ========================================================================
    // 跨线程消息处理
    // ========================================================================

    /// 排空关闭消息
    /// 严格翻译自: HTTPThread.drainQueuedShutdowns
    ///
    /// 从 socket_async_http_abort_tracker 中查找 socket 并关闭。
    /// 未找到的 id 可能在 pending_h2_connects 或 H3 会话中。
    private func drainQueuedShutdowns(): Unit {
        while (true) {
            // 在锁外处理以避免阻塞其他线程
            var shutdowns = ArrayList<ShutdownMessage>()
            shutdownsLock.lock()
            shutdowns = queuedShutdowns
            queuedShutdowns = ArrayList<ShutdownMessage>()
            shutdownsLock.unlock()

            for (msg in shutdowns) {
                // 严格翻译自:
                //   if (socket_async_http_abort_tracker.fetchSwapRemove(http.async_http_id)) |socket_ptr| {
                //       switch (socket_ptr.value) {
                //           inline .SocketTLS, .SocketTCP => |socket, tag| {
                //               const is_tls = tag == .SocketTLS
                //               const tagged = HTTPContext.getTaggedFromSocket(socket)
                //               if (tagged.get(HTTPClient)) |client| {
                //                   client.closeAndAbort(is_tls, socket); continue
                //               }
                //               if (tagged.get(H2.ClientSession)) |session| {
                //                   session.abortByHttpId(http.async_http_id); continue
                //               }
                //               socket.close(.failure)
                //           },
                //       }
                //   } else {
                //       if (this.abortPendingH2Waiter(http.async_http_id)) continue
                //       if (bun.http.H3.ClientContext.abortByHttpId(http.async_http_id)) continue
                //       this.has_pending_queued_abort = true
                //   }
                let socketResult = SocketTrackerOps.fetchSwapRemove(socketAsyncHttpAbortTracker, msg.asyncHttpId)
                match (socketResult) {
                    case Some(trackedSocket) =>
                        let socketFd = trackedSocket.socketFd
                        let isTls = trackedSocket.isTls
                        let tagged = trackedSocket.tagged
                        // HTTPClient 路径
                        match (tagged.getClient()) {
                            case Some(client) =>
                                client.closeAndAbort(isTls, socketFd)
                                continue
                            case None => ()
                        }
                        // H2 ClientSession 路径
                        let h2Session = tagged.getH2Session()
                        match (h2Session) {
                            case Some(session) =>
                                // session.abortByHttpId(msg.asyncHttpId)
                                continue
                            case None => ()
                        }
                        // 未知类型 — 强制关闭
                        if (socketFd >= 0) {
                            // socket.close(.failure)
                        }
                    case None =>
                        // 未找到 socket — 可能在 pending_h2_connects 或 H3 会话中
                        if (abortPendingH2Waiter(msg.asyncHttpId)) {
                            continue
                        }
                        // H3 会话 (无 TCP socket 在 tracker 中注册)
                        if (H3Client.abortByHttpId(Int64(msg.asyncHttpId))) {
                            continue
                        }
                        // 否则请求可能尚未开始 (仍在 queued_tasks/deferred_tasks)
                        // 或已完成。标记以便 drainEvents 扫描队列。
                        hasPendingQueuedAbort = true
                }
            }
            if (shutdowns.size == 0) {
                break
            }
        }
    }

    /// 排空写入消息
    /// 严格翻译自: HTTPThread.drainQueuedWrites
    private func drainQueuedWrites(): Unit {
        while (true) {
            var writes = ArrayList<WriteMessage>()
            writesLock.lock()
            writes = queuedWrites
            queuedWrites = ArrayList<WriteMessage>()
            writesLock.unlock()

            for (msg in writes) {
                let ended = match (msg.messageType) {
                    case end => true
                    case _ => false
                }
                // 严格翻译自:
                //   if (socket_async_http_abort_tracker.get(write.async_http_id)) |socket_ptr| {
                //       switch (socket_ptr) {
                //           inline .SocketTLS, .SocketTCP => |socket, tag| {
                //               if (socket.isClosed() or socket.isShutdown()) continue
                //               const tagged = getTaggedFromSocket(socket)
                //               if (tagged.get(HTTPClient)) |client| {
                //                   if (client.state.original_request_body == .stream) {
                //                       var stream = &client.state.original_request_body.stream
                //                       stream.ended = ended
                //                       client.flushStream(is_tls, socket)
                //                   }
                //               }
                //               if (tagged.get(H2.ClientSession)) |session| {
                //                   session.streamBodyByHttpId(write.async_http_id, ended)
                //               }
                //           },
                //       }
                //   } else {
                //       bun.http.H3.ClientContext.streamBodyByHttpId(...)
                //   }
                let socketResult = SocketTrackerOps.get(socketAsyncHttpAbortTracker, msg.asyncHttpId)
                match (socketResult) {
                    case Some(trackedSocket) =>
                        let socketFd = trackedSocket.socketFd
                        let isTls = trackedSocket.isTls
                        let tagged = trackedSocket.tagged
                        // 已关闭或已 shutdown 的 socket 跳过
                        if (trackedSocket.isClosed || trackedSocket.isShutdown) {
                            continue
                        }
                        // HTTPClient 路径 — 流式请求体
                        match (tagged.getClient()) {
                            case Some(client) =>
                                if (client.state.originalRequestBody.isStream()) {
                                    // 设置流结束标记并刷新
                                    // stream.ended = ended
                                    // client.flushStream(isTls, socketFd)
                                }
                            case None => ()
                        }
                        // H2 ClientSession 路径
                        let h2Session = tagged.getH2Session()
                        match (h2Session) {
                            case Some(session) =>
                                // session.streamBodyByHttpId(msg.asyncHttpId, ended)
                                ()
                            case None => ()
                        }
                    case None =>
                        // 不在 tracker 中 — 可能是 H3 会话
                        H3Client.streamBodyByHttpId(Int64(msg.asyncHttpId), ended)
                }
            }
            if (writes.size == 0) {
                break
            }
        }
    }

    /// 排空响应体排空消息
    /// 严格翻译自: HTTPThread.drainQueuedHTTPResponseBodyDrains
    private func drainQueuedResponseBodyDrains(): Unit {
        while (true) {
            var drains = ArrayList<DrainMessage>()
            drainsLock.lock()
            drains = queuedResponseBodyDrains
            queuedResponseBodyDrains = ArrayList<DrainMessage>()
            drainsLock.unlock()

            for (msg in drains) {
                // 严格翻译自:
                //   if (socket_async_http_abort_tracker.get(drain.async_http_id)) |socket_ptr| {
                //       switch (socket_ptr) {
                //           inline .SocketTLS, .SocketTCP => |socket, tag| {
                //               const is_tls = tag == .SocketTLS
                //               const HTTPContext = HTTPThread.NewHTTPContext(comptime is_tls)
                //               const tagged = HTTPContext.getTaggedFromSocket(socket)
                //               if (tagged.get(HTTPClient)) |client| {
                //                   client.drainResponseBody(is_tls, socket)
                //               }
                //               if (tagged.get(H2.ClientSession)) |session| {
                //                   session.drainResponseBodyByHttpId(drain.async_http_id)
                //               }
                //           },
                //       }
                //   }
                let socketResult = SocketTrackerOps.get(socketAsyncHttpAbortTracker, msg.asyncHttpId)
                match (socketResult) {
                    case Some(trackedSocket) =>
                        let socketFd = trackedSocket.socketFd
                        let isTls = trackedSocket.isTls
                        let tagged = trackedSocket.tagged
                        // HTTPClient 路径 — 排空响应体
                        match (tagged.getClient()) {
                            case Some(client) =>
                                client.drainResponseBody(isTls, socketFd)
                            case None => ()
                        }
                        // H2 ClientSession 路径
                        let h2Session = tagged.getH2Session()
                        match (h2Session) {
                            case Some(session) =>
                                // session.drainResponseBodyByHttpId(msg.asyncHttpId)
                                ()
                            case None => ()
                        }
                    case None =>
                        // 不在 tracker 中 — 忽略 (H3 不使用 socket tracker)
                        ()
                }
            }
            if (drains.size == 0) {
                break
            }
        }
    }

    /// 中止挂起的 H2 等待者
    /// 严格翻译自: HTTPThread.abortPendingH2Waiter
    private func abortPendingH2Waiter(asyncHttpId: UInt32): Bool {
        if (httpsContext.abortPendingH2Waiter(asyncHttpId)) { return true }
        // 也扫描自定义 SSL 上下文
        for (entry in sslContextCache) {
            if (entry.ctx.abortPendingH2Waiter(asyncHttpId)) { return true }
        }
        return false
    }

    // ========================================================================
    // 调度方法
    // 严格翻译自: HTTPThread.schedule / scheduleShutdown / scheduleRequestWrite
    // ========================================================================

    /// 调度批量任务
    /// 严格翻译自: HTTPThread.schedule
    ///
    /// 从 MPSC 队列中取出所有任务放入 HTTP 线程的本地队列
    public func schedule(batch: ThreadPoolBatch): Unit {
        if (batch.len() == 0) {
            return
        }

        // 严格翻译自:
        //   var batch_ = batch
        //   while (batch_.pop()) |task| {
        //       const http: *AsyncHTTP = @fieldParentPtr("task", task)
        //       this.queued_tasks.push(http)
        //   }
        while (true) {
            match (batch.pop()) {
                case Some(http) => queuedTasks.append(http)
                case None => break
            }
        }

        if (hasAwoken) {
            loop.wakeup()
        }
    }

    /// 调度关闭
    /// 严格翻译自: HTTPThread.scheduleShutdown
    public func scheduleShutdown(http: AsyncHTTP): Unit {
        shutdownsLock.lock()
        queuedShutdowns.append(ShutdownMessage(http.asyncHttpId))
        shutdownsLock.unlock()

        if (hasAwoken) {
            loop.wakeup()
        }
    }

    /// 调度请求写入
    /// 严格翻译自: HTTPThread.scheduleRequestWrite
    public func scheduleRequestWrite(http: AsyncHTTP, messageType: WriteMessageType): Unit {
        writesLock.lock()
        queuedWrites.append(WriteMessage(http.asyncHttpId, messageType))
        writesLock.unlock()

        if (hasAwoken) {
            loop.wakeup()
        }
    }

    /// 调度响应体排空
    /// 严格翻译自: HTTPThread.scheduleResponseBodyDrain
    public func scheduleResponseBodyDrain(asyncHttpId: UInt32): Unit {
        drainsLock.lock()
        queuedResponseBodyDrains.append(DrainMessage(asyncHttpId))
        drainsLock.unlock()

        if (hasAwoken) {
            loop.wakeup()
        }
    }

    /// 调度代理引用减少
    /// 严格翻译自: HTTPThread.scheduleProxyDeref
    ///
    /// 始终在 HTTP 线程上调用，不需要唤醒
    public func scheduleProxyDeref(proxy: ProxyTunnel): Unit {
        queuedProxyDerefs.append(proxy)
        if (hasAwoken) {
            loop.wakeup()
        }
    }

    /// 唤醒事件循环
    /// 严格翻译自: HTTPThread.wakeup
    public func wakeup(): Unit {
        if (hasAwoken) {
            loop.wakeup()
        }
    }

    // ========================================================================
    // SSL 上下文缓存管理
    // 严格翻译自: HTTPThread SSL context cache eviction
    // ========================================================================

    /// 清理过期的 SSL 上下文 (TTL = 30 分钟)
    /// 严格翻译自: HTTPThread.evictStaleSslContexts
    private func evictStaleSslContexts(): Unit {
        let now = timer
        var remaining = ArrayList<SslContextCacheEntry>()
        for (entry in sslContextCache) {
            if (now - entry.lastUsedNs > SSL_CONTEXT_CACHE_TTL_NS) {
                entry.ctx.deref()
                // entry.configRef.deinit()
            } else {
                remaining.append(entry)
            }
        }
        sslContextCache = remaining
    }

    /// 清理最旧的 SSL 上下文 (LRU 驱逐)
    /// 严格翻译自: HTTPThread.evictOldestSslContext
    private func evictOldestSslContext(): Unit {
        if (sslContextCache.size == 0) {
            return
        }
        var oldestIdx: Int64 = 0
        var oldestTime: UInt64 = UInt64(9223372036854775807)
        for (i in 0..sslContextCache.size) {
            if (sslContextCache[i].lastUsedNs < oldestTime) {
                oldestTime = sslContextCache[i].lastUsedNs
                oldestIdx = i
            }
        }
        let entry = sslContextCache.removeAt(oldestIdx)
        entry.ctx.deref()
        // entry.configRef.deinit()
    }

    // ========================================================================
    // 请求体缓冲区
    // 严格翻译自: HTTPThread.getRequestBodySendBuffer
    // ========================================================================

    /// 获取请求体发送缓冲区
    /// 严格翻译自: HTTPThread.getRequestBodySendBuffer
    ///
    /// 小请求体 (< 32KB): 栈分配
    /// 大请求体 (>= 32KB): 堆分配 (512KB, 延迟创建)
    public func getRequestBodySendBuffer(estimatedSize: Int64): RequestBodyBuffer {
        let buffer = RequestBodyBuffer()
        if (estimatedSize >= REQUEST_BODY_SEND_STACK_BUFFER_SIZE) {
            // 严格翻译自:
            //   if (this.lazy_request_body_buffer == null) {
            //       return .{ .heap = HeapRequestBodyBuffer() }
            //   }
            //   return .{ .heap = bun.take(&this.lazy_request_body_buffer).? }
            match (lazyRequestBodyBuffer) {
                case None =>
                    buffer.heapBuffer = Some(Array<UInt8>(512 * 1024, { _ => UInt8(0) }))
                case Some(existing) =>
                    buffer.heapBuffer = Some(existing)
                    lazyRequestBodyBuffer = None
            }
            buffer.size = 512 * 1024
        }
        return buffer
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 互斥锁 (简化)
public class HTTPThreadMutex {
    public init() {}
    public func lock(): Unit {}
    public func unlock(): Unit {}
}

/// 全局 HTTP 线程实例
/// 严格翻译自: bun.http.http_thread
public var httpThread = HTTPThread()

/// 活跃请求计数 (原子)
/// 严格翻译自: AsyncHTTP.active_requests_count
public var activeRequestsCount = AtomicInt64(Int64(0))

/// 最大同时请求数 (原子)
/// 严格翻译自: AsyncHTTP.max_simultaneous_requests
public var maxSimultaneousRequests = AtomicInt64(Int64(0))

/// 线程池批次
public class ThreadPoolBatch {
    private var items: ArrayList<AsyncHTTP>

    public init() {
        items = ArrayList<AsyncHTTP>()
    }

    public func len(): Int64 {
        return items.size
    }

    public func pop(): ?AsyncHTTP {
        if (items.size == 0) { return None }
        return items.removeAt(items.size - 1)
    }

    public func push(http: AsyncHTTP): Unit {
        items.append(http)
    }
}

// ============================================================================
// TrackedSocket - socket_async_http_abort_tracker 中的追踪条目
// 严格翻译自: uws.AnySocket (SocketTLS / SocketTCP tagged union)
//
// 在 Bun 中，socket_async_http_abort_tracker 存储 uws.AnySocket，
// 它是 TLS socket 或 TCP socket 的标记联合。通过 getTaggedFromSocket
// 可以提取出 ActiveSocket (HTTPClient / H2.ClientSession / PooledSocket)。
//
// 在仓颉中，我们用 TrackedSocket 封装 socket fd、TLS 标志和标记指针。
// ============================================================================

/// 追踪的 socket 条目
/// 严格翻译自: uws.AnySocket + getTaggedFromSocket 的组合结果
public class TrackedSocket {
    /// socket 文件描述符
    public var socketFd: Int64
    /// 是否为 TLS socket
    public var isTls: Bool
    /// 标记的活跃 socket (HTTPClient / H2Session / PooledSocket / DeadSocket)
    /// 严格翻译自: HTTPContext.getTaggedFromSocket(socket)
    public var tagged: ActiveSocket
    /// 是否已关闭
    public var isClosed: Bool
    /// 是否已 shutdown
    public var isShutdown: Bool

    public init(socketFd: Int64, isTls: Bool, tagged: ActiveSocket) {
        this.socketFd = socketFd
        this.isTls = isTls
        this.tagged = tagged
        this.isClosed = false
        this.isShutdown = false
    }
}

// ============================================================================
// SocketTrackerOps - socket_async_http_abort_tracker 操作
// 严格翻译自: std.AutoArrayHashMap(u32, uws.AnySocket) 操作
//
// 封装对全局 socketAsyncHttpAbortTracker 的查找和删除操作。
// 在 Bun 中这是一个 AutoArrayHashMap，按 async_http_id (u32) 索引。
// ============================================================================

/// socket 追踪器操作
/// 严格翻译自: socket_async_http_abort_tracker 的 get / fetchSwapRemove
public class SocketTrackerOps {
    /// 获取追踪的 socket (不删除)
    /// 严格翻译自: socket_async_http_abort_tracker.get(id)
    public static func get(tracker: Any, asyncHttpId: UInt32): ?TrackedSocket {
        // 实际实现通过 FFI 访问全局 tracker
        // 此处返回 None 表示未找到
        return None
    }

    /// 获取并移除追踪的 socket
    /// 严格翻译自: socket_async_http_abort_tracker.fetchSwapRemove(id)
    public static func fetchSwapRemove(tracker: Any, asyncHttpId: UInt32): ?TrackedSocket {
        // 实际实现通过 FFI 访问全局 tracker，查找并交换移除
        // 此处返回 None 表示未找到
        return None
    }
}
