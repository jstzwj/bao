// bao_event_loop - libuv 事件循环集成
// 严格翻译自: src/event_loop/libuv.zig + src/event_loop/MiniEventLoop.zig
//   Bun 使用 uSockets 事件循环 (基于 libuv 或自定义 epoll/kqueue)
//   仓颉直接包装 libuv 提供跨平台异步 I/O
//
// libuv 事件循环核心:
//   uv_loop_t - 事件循环句柄
//   uv_run(loop, mode) - 运行事件循环
//   UV_RUN_DEFAULT / UV_RUN_ONCE / UV_RUN_NOWAIT
//
// 定时器集成:
//   uv_timer_t - 定时器句柄
//   uv_timer_init(loop, timer) - 初始化
//   uv_timer_start(timer, cb, timeout, repeat) - 启动
//   uv_timer_stop(timer) - 停止
//
// TCP 集成:
//   uv_tcp_t - TCP 句柄
//   uv_tcp_init(loop, tcp) - 初始化
//   uv_tcp_bind(tcp, addr, flags) - 绑定地址
//   uv_listen(stream, backlog, cb) - 监听
//   uv_accept(server, client) - 接受连接
//
// 跨线程唤醒:
//   uv_async_t - 异步句柄
//   uv_async_init(loop, async, cb) - 初始化
//   uv_async_send(async) - 跨线程发送信号
//
// Prepare/Check/Idle 句柄:
//   uv_prepare_t / uv_check_t / uv_idle_t
//   在事件循环的特定阶段执行回调
package bao_event_loop

import bao_core.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// UvRunMode - libuv 运行模式
// 严格翻译自: uv_run_mode enum
//   UV_RUN_DEFAULT = 0 - 持续运行直到没有活跃句柄
//   UV_RUN_ONCE    = 1 - 阻塞等待至少一个事件
//   UV_RUN_NOWAIT  = 2 - 非阻塞，立即返回
// ============================================================================

/// libuv 运行模式 - 对应 uv_run_mode
public enum UvRunMode {
    | Default   // UV_RUN_DEFAULT - 持续运行直到没有活跃句柄
    | Once      // UV_RUN_ONCE - 阻塞等待一个事件
    | NoWait    // UV_RUN_NOWAIT - 非阻塞轮询
}

// ============================================================================
// UvLoop - libuv 事件循环封装
// 严格翻译自: MiniEventLoop + uSockets Loop
//   Bun: uws.Loop.get() 获取 uSockets 事件循环
//        uws.Loop.tick() 驱动一次事件循环迭代
//        MiniEventLoop.concurrent_tasks 存放跨线程任务
//
//   libuv uv_loop_t 结构:
//     void* data                    - 用户数据
//     unsigned int active_handles   - 活跃句柄数
//     unsigned int active_reqs      - 活跃请求数
//     ... (内部字段)
//
//   uv_run(loop, mode):
//     while (有活跃句柄) {
//       uv__io_poll(loop, timeout)   // 等待 I/O 事件
//       uv__run_timers(loop)         // 运行到期定时器
//       uv__run_pending(loop)        // 处理 pending 回调
//       uv__run_idle(loop)           // 空闲回调
//       uv__run_prepare(loop)        // 准备回调
//       uv__run_check(loop)          // 检查回调
//     }
// ============================================================================

/// libuv 事件循环封装 - 对应 Bun uws.Loop + MiniEventLoop
/// 提供跨平台异步 I/O 能力
public class UvLoop {
    /// libuv 循环句柄 (uv_loop_t*)
    /// Bun: loop: *uws.Loop
    private var loopPtr: CPointer<UInt8>
    /// 并发任务队列 - 对应 Bun concurrent_tasks
    /// Bun: ConcurrentTaskQueue = UnboundedQueue(AnyTaskWithExtraContext, .next)
    private var concurrentTasks: ConcurrentTaskQueue
    /// 本地任务队列 - 对应 Bun tasks: Queue
    /// Bun: tasks: LinearFifo(*AnyTaskWithExtraContext, .Dynamic)
    private var localTasks: ArrayList<() -> Unit>
    /// 定时器堆 - 对应 Bun timer heap
    private var timerHeap: TimerHeap
    /// 定时器 ID 生成器
    private var timerIds: TimerId
    /// 是否活跃
    private var running: Bool
    /// 活跃句柄数
    private var activeHandleCount: Int64
    /// 是否已初始化
    private var initialized: Bool

    public init() {
        loopPtr = CPointer<UInt8>()
        concurrentTasks = ConcurrentTaskQueue()
        localTasks = ArrayList<() -> Unit>()
        timerHeap = TimerHeap()
        timerIds = TimerId()
        running = false
        activeHandleCount = 0
        initialized = false
    }

    /// 初始化 libuv 循环 - 对应 uv_loop_init
    /// Bun: MiniEventLoop.init(allocator) -> .{ .tasks = Queue.init(allocator), .loop = uws.Loop.get() }
    public func init(): Int64 {
        unsafe {
            let result = uv_loop_init(loopPtr)
            if (result < 0) {
                return Int64(result)
            }
            initialized = true
            return 0
        }
    }

    /// 使用默认循环 - 对应 uv_default_loop
    public func initDefault(): Int64 {
        unsafe {
            loopPtr = uv_default_loop()
            if (loopPtr == CPointer<UInt8>()) {
                return -1
            }
            initialized = true
            return 0
        }
    }

    // ========================================================================
    // run - 运行事件循环
    // 严格翻译自: uv_run(loop, mode)
    //   UV_RUN_DEFAULT: 持续运行直到没有活跃句柄
    //   UV_RUN_ONCE: 阻塞等待至少一个事件，然后处理回调
    //   UV_RUN_NOWAIT: 非阻塞，立即返回
    //
    // Bun MiniEventLoop.tick:
    //   pub fn tick(this, context) void {
    //       if (this.tickConcurrentWithCount() == 0 and this.tasks.count == 0) {
    //           defer this.onAfterEventLoop()
    //           this.loop.inc()
    //           this.loop.tick()
    //           this.loop.dec()
    //       }
    //       while (this.tasks.readItem()) |task| { task.run(context) }
    //   }
    // ========================================================================

    /// 运行事件循环 - 对应 uv_run(loop, mode)
    public func run(mode: UvRunMode): Int64 {
        if (!initialized) {
            return -1
        }
        running = true

        let uvMode = match (mode) {
            case Default => 0  // UV_RUN_DEFAULT
            case Once => 1     // UV_RUN_ONCE
            case NoWait => 2   // UV_RUN_NOWAIT
        }

        // 主循环
        var result: Int64 = 0
        if (mode == UvRunMode.Default) {
            while (running) {
                // 1. 处理并发任务 - 对应 Bun tickConcurrentWithCount
                tickConcurrent()
                // 2. 处理本地任务
                tickLocalTasks()
                // 3. 驱动 libuv 循环一次
                unsafe {
                    result = Int64(uv_run(loopPtr, uvMode))
                }
                // 4. 触发到期定时器
                let now = currentMillis()
                timerHeap.fireExpired(now)
                // 5. 如果没有活跃句柄和任务，退出
                if (result == 0 && localTasks.size == 0 && !concurrentTasks.hasPending()) {
                    break
                }
            }
        } else {
            // Once 或 NoWait 模式
            tickConcurrent()
            tickLocalTasks()
            unsafe {
                result = Int64(uv_run(loopPtr, uvMode))
            }
            let now = currentMillis()
            timerHeap.fireExpired(now)
        }

        running = false
        return result
    }

    /// 停止事件循环 - 对应 uv_stop(loop)
    public func stop(): Unit {
        running = false
        if (initialized) {
            unsafe {
                uv_stop(loopPtr)
            }
        }
    }

    /// 是否正在运行
    public func isRunning(): Bool {
        return running
    }

    /// 关闭并清理循环 - 对应 uv_loop_close
    public func close(): Unit {
        if (initialized) {
            unsafe {
                uv_loop_close(loopPtr)
            }
            initialized = false
        }
        localTasks.clear()
        timerHeap.clear()
    }

    // ========================================================================
    // 定时器集成 - 对应 uv_timer_t
    // 严格翻译自: uv_timer_start / uv_timer_stop
    //
    // Bun 的定时器管理:
    //   setTimeout(callback, delay) -> TimerObject
    //   setInterval(callback, delay) -> TimerObject
    //   setImmediate(callback) -> ImmediateObject
    //   clearTimeout/clearInterval/clearImmediate -> 取消
    //
    // libuv 定时器:
    //   uv_timer_init(loop, timer) -> 初始化
    //   uv_timer_start(timer, cb, timeout, repeat) -> 启动
    //   uv_timer_stop(timer) -> 停止
    //   uv_timer_again(timer) -> 重启 repeat 定时器
    //   uv_timer_set_repeat(timer, repeat) -> 设置重复间隔
    // ========================================================================

    /// 启动定时器 (一次性) - 对应 setTimeout
    /// Bun: setTimeout(callback, delay)
    /// libuv: uv_timer_start(timer, cb, timeout, 0)
    public func setTimeout(callback: () -> Unit, delayMs: Int64): Int64 {
        let id = timerIds.next()
        let deadline = currentMillis() + delayMs
        let timer = EventLoopTimer(
            TimerTag.Timeout, callback, deadline, 0, id
        )
        timerHeap.insert(timer)
        return id
    }

    /// 启动间隔定时器 - 对应 setInterval
    /// Bun: setInterval(callback, interval)
    /// libuv: uv_timer_start(timer, cb, timeout, repeat)
    public func setInterval(callback: () -> Unit, intervalMs: Int64): Int64 {
        let id = timerIds.next()
        let deadline = currentMillis() + intervalMs
        let timer = EventLoopTimer(
            TimerTag.Interval, callback, deadline, intervalMs, id
        )
        timerHeap.insert(timer)
        return id
    }

    /// 启动即时回调 - 对应 setImmediate
    /// Bun: setImmediate(callback)
    /// 在下一次事件循环迭代中执行
    public func setImmediate(callback: () -> Unit): Int64 {
        let id = timerIds.next()
        // Immediate 使用当前时间作为 deadline (立即到期)
        let timer = EventLoopTimer(
            TimerTag.Immediate, callback, currentMillis(), 0, id
        )
        timerHeap.insert(timer)
        return id
    }

    /// 取消定时器 - 对应 clearTimeout/clearInterval
    /// 通过 ID 取消定时器
    public func clearTimer(id: Int64): Unit {
        let timer = timerHeap.remove(id)
        if (timer != None) {
            timer.getOrThrow().cancel()
        }
    }

    // ========================================================================
    // TCP - 对应 uv_tcp_t
    // 严格翻译自: libuv TCP 操作
    //   uv_tcp_init(loop, tcp) -> 初始化 TCP 句柄
    //   uv_tcp_bind(tcp, addr, flags) -> 绑定地址
    //   uv_listen(stream, backlog, cb) -> 开始监听
    //   uv_accept(server, client) -> 接受连接
    //   uv_tcp_connect(req, tcp, addr, cb) -> 发起连接
    //   uv_read_start(stream, alloc_cb, read_cb) -> 开始读取
    //   uv_write(req, stream, bufs, nbufs, cb) -> 写入数据
    // ========================================================================

    /// TCP 连接回调类型
    public typealias TcpConnectionCallback = (Int64) -> Unit  // fd

    /// TCP 数据回调类型
    public typealias TcpDataCallback = (Array<UInt8>) -> Unit

    /// TCP 服务端
    public class TcpServer {
        /// TCP 句柄 (uv_tcp_t*)
        public var handlePtr: CPointer<UInt8>
        /// 连接回调
        public var connectionCallback: ?TcpConnectionCallback
        /// 数据回调
        public var dataCallback: ?TcpDataCallback

        public init() {
            handlePtr = CPointer<UInt8>()
            connectionCallback = None
            dataCallback = None
        }
    }

    /// 初始化 TCP 句柄 - 对应 uv_tcp_init(loop, tcp)
    public func tcpInit(server: TcpServer): Int64 {
        unsafe {
            return Int64(uv_tcp_init(loopPtr, server.handlePtr))
        }
    }

    /// 绑定 TCP 地址 - 对应 uv_tcp_bind(tcp, addr, flags)
    public func tcpBind(server: TcpServer, host: String, port: Int64): Int64 {
        unsafe {
            let addrPtr = unsafeMallocSockaddrIn()
            parseAddress(host, port, addrPtr)
            let result = uv_tcp_bind(server.handlePtr, addrPtr, 0)
            unsafeFreeSockaddrIn(addrPtr)
            return Int64(result)
        }
    }

    /// 开始监听 - 对应 uv_listen(stream, backlog, cb)
    public func tcpListen(server: TcpServer, backlog: Int32): Int64 {
        unsafe {
            return Int64(uv_listen(server.handlePtr, backlog))
        }
    }

    /// 接受连接 - 对应 uv_accept(server, client)
    public func tcpAccept(server: TcpServer, client: TcpServer): Int64 {
        unsafe {
            return Int64(uv_accept(server.handlePtr, client.handlePtr))
        }
    }

    // ========================================================================
    // Async - 跨线程唤醒
    // 严格翻译自: uv_async_t
    //   uv_async_init(loop, async, cb) - 初始化异步句柄
    //   uv_async_send(async) - 从任意线程发送信号
    //
    // Bun: loop.wakeup() 通过 eventfd 或 uv_async_send 唤醒事件循环
    //   MiniEventLoop.enqueueTaskConcurrent:
    //     this.concurrent_tasks.push(task)
    //     this.loop.wakeup()
    // ========================================================================

    /// 跨线程异步句柄 - 对应 uv_async_t
    public class AsyncHandle {
        /// uv_async_t 指针
        public var handlePtr: CPointer<UInt8>
        /// 回调函数
        public var callback: ?() -> Unit

        public init() {
            handlePtr = CPointer<UInt8>()
            callback = None
        }
    }

    /// 初始化异步句柄 - 对应 uv_async_init(loop, async, cb)
    public func asyncInit(handle: AsyncHandle, callback: () -> Unit): Int64 {
        handle.callback = callback
        unsafe {
            return Int64(uv_async_init(loopPtr, handle.handlePtr))
        }
    }

    /// 跨线程发送信号 - 对应 uv_async_send(async)
    /// 可以从任意线程调用，唤醒事件循环
    /// Bun: this.loop.wakeup()
    public func asyncSend(handle: AsyncHandle): Int64 {
        unsafe {
            return Int64(uv_async_send(handle.handlePtr))
        }
    }

    // ========================================================================
    // Prepare/Check/Idle 句柄
    // 严格翻译自: uv_prepare_t / uv_check_t / uv_idle_t
    //
    // libuv 事件循环阶段:
    //   1. uv__io_poll(loop, timeout) - I/O 轮询
    //   2. uv__run_timers(loop)       - 定时器回调
    //   3. uv__run_pending(loop)      - pending 回调 (如 uv_async_send)
    //   4. uv__run_idle(loop)         - idle 回调 (每次迭代)
    //   5. uv__run_prepare(loop)      - prepare 回调 (I/O 轮询前)
    //   6. uv__run_check(loop)        - check 回调 (I/O 轮询后)
    //
    //   uv_prepare_init(loop, prepare) -> 初始化
    //   uv_prepare_start(prepare, cb)  -> 启动
    //   uv_prepare_stop(prepare)       -> 停止
    //
    //   uv_check_init(loop, check) -> 初始化
    //   uv_check_start(check, cb)  -> 启动
    //   uv_check_stop(check)       -> 停止
    //
    //   uv_idle_init(loop, idle) -> 初始化
    //   uv_idle_start(idle, cb)  -> 启动
    //   uv_idle_stop(idle)       -> 停止
    // ========================================================================

    /// Prepare 回调句柄 - 对应 uv_prepare_t
    /// 在 I/O 轮询前执行
    public class PrepareHandle {
        public var handlePtr: CPointer<UInt8>
        public var callback: ?() -> Unit

        public init() {
            handlePtr = CPointer<UInt8>()
            callback = None
        }
    }

    /// Check 回调句柄 - 对应 uv_check_t
    /// 在 I/O 轮询后执行
    public class CheckHandle {
        public var handlePtr: CPointer<UInt8>
        public var callback: ?() -> Unit

        public init() {
            handlePtr = CPointer<UInt8>()
            callback = None
        }
    }

    /// Idle 回调句柄 - 对应 uv_idle_t
    /// 每次迭代都执行 (如果没有 I/O 活动)
    public class IdleHandle {
        public var handlePtr: CPointer<UInt8>
        public var callback: ?() -> Unit

        public init() {
            handlePtr = CPointer<UInt8>()
            callback = None
        }
    }

    /// 初始化 Prepare 句柄
    public func prepareInit(handle: PrepareHandle, callback: () -> Unit): Int64 {
        handle.callback = callback
        unsafe {
            return Int64(uv_prepare_init(loopPtr, handle.handlePtr))
        }
    }

    /// 启动 Prepare 句柄
    public func prepareStart(handle: PrepareHandle): Int64 {
        unsafe {
            return Int64(uv_prepare_start(handle.handlePtr))
        }
    }

    /// 停止 Prepare 句柄
    public func prepareStop(handle: PrepareHandle): Int64 {
        unsafe {
            return Int64(uv_prepare_stop(handle.handlePtr))
        }
    }

    /// 初始化 Check 句柄
    public func checkInit(handle: CheckHandle, callback: () -> Unit): Int64 {
        handle.callback = callback
        unsafe {
            return Int64(uv_check_init(loopPtr, handle.handlePtr))
        }
    }

    /// 启动 Check 句柄
    public func checkStart(handle: CheckHandle): Int64 {
        unsafe {
            return Int64(uv_check_start(handle.handlePtr))
        }
    }

    /// 停止 Check 句柄
    public func checkStop(handle: CheckHandle): Int64 {
        unsafe {
            return Int64(uv_check_stop(handle.handlePtr))
        }
    }

    /// 初始化 Idle 句柄
    public func idleInit(handle: IdleHandle, callback: () -> Unit): Int64 {
        handle.callback = callback
        unsafe {
            return Int64(uv_idle_init(loopPtr, handle.handlePtr))
        }
    }

    /// 启动 Idle 句柄
    public func idleStart(handle: IdleHandle): Int64 {
        unsafe {
            return Int64(uv_idle_start(handle.handlePtr))
        }
    }

    /// 停止 Idle 句柄
    public func idleStop(handle: IdleHandle): Int64 {
        unsafe {
            return Int64(uv_idle_stop(handle.handlePtr))
        }
    }

    // ========================================================================
    // 任务提交 - 对应 MiniEventLoop 的 enqueue
    // ========================================================================

    /// 排队本地任务 - 对应 Bun MiniEventLoop.enqueueTask
    /// Bun:
    ///   pub fn enqueueTask(this, comptime Context, ctx, comptime Callback, comptime field) void {
    ///       const TaskType = MiniEventLoop.Task.New(Context, Callback)
    ///       @field(ctx, @tagName(field)) = TaskType.init(ctx)
    ///       this.enqueueJSCTask(&@field(ctx, @tagName(field)))
    ///   }
    public func enqueue(task: () -> Unit): Unit {
        localTasks.append(task)
    }

    /// 排队并发任务 - 对应 Bun enqueueTaskConcurrent
    /// Bun:
    ///   pub fn enqueueTaskConcurrent(this, task) void {
    ///       this.concurrent_tasks.push(task)
    ///       this.loop.wakeup()
    ///   }
    public func enqueueConcurrent(task: ConcurrentTask): Unit {
        concurrentTasks.push(task)
    }

    /// 处理并发任务 - 对应 Bun tickConcurrentWithCount
    /// Bun:
    ///   pub fn tickConcurrentWithCount(this) usize {
    ///       var concurrent = this.concurrent_tasks.popBatch()
    ///       const count = concurrent.count
    ///       if (count == 0) return 0
    ///       ... move to local queue
    ///   }
    private func tickConcurrent(): Unit {
        let tasks = concurrentTasks.drain()
        for (i in 0..tasks.size) {
            tasks[i].run()
        }
    }

    /// 处理本地任务 - 对应 Bun tasks.readItem loop
    /// Bun:
    ///   while (this.tasks.readItem()) |task| { task.run(context) }
    private func tickLocalTasks(): Unit {
        for (i in 0..localTasks.size) {
            localTasks[i]()
        }
        localTasks.clear()
    }

    /// 获取 libuv 循环指针
    public func getLoopPtr(): CPointer<UInt8> {
        return loopPtr
    }

    /// 获取当前活跃句柄数
    public func activeHandleCount(): Int64 {
        return activeHandleCount
    }

    /// 增加活跃句柄计数
    public func ref(): Unit {
        activeHandleCount += 1
    }

    /// 减少活跃句柄计数
    public func unref(): Unit {
        activeHandleCount -= 1
    }

    /// 获取当前时间 (毫秒)
    private func currentMillis(): Int64 {
        if (initialized) {
            unsafe {
                return Int64(uv_now(loopPtr))
            }
        }
        return 0
    }

    // ========================================================================
    // C FFI 外部函数声明 - libuv
    // ========================================================================

    // 循环管理
    @Foreign
    private static func uv_loop_init(loop: CPointer<UInt8>): Int32
    @Foreign
    private static func uv_default_loop(): CPointer<UInt8>
    @Foreign
    private static func uv_run(loop: CPointer<UInt8>, mode: Int32): Int32
    @Foreign
    private static func uv_stop(loop: CPointer<UInt8>): Unit
    @Foreign
    private static func uv_loop_close(loop: CPointer<UInt8>): Int32
    @Foreign
    private static func uv_loop_size(): UInt64
    @Foreign
    private static func uv_now(loop: CPointer<UInt8>): UInt64
    @Foreign
    private static func uv_update_time(loop: CPointer<UInt8>): Unit
    @Foreign
    private static func uv_backend_fd(loop: CPointer<UInt8>): Int32
    @Foreign
    private static func uv_backend_timeout(loop: CPointer<UInt8>): Int32

    // TCP
    @Foreign
    private static func uv_tcp_init(loop: CPointer<UInt8>, tcp: CPointer<UInt8>): Int32
    @Foreign
    private static func uv_tcp_bind(tcp: CPointer<UInt8>, addr: CPointer<UInt8>, flags: UInt32): Int32
    @Foreign
    private static func uv_listen(stream: CPointer<UInt8>, backlog: Int32): Int32
    @Foreign
    private static func uv_accept(server: CPointer<UInt8>, client: CPointer<UInt8>): Int32

    // Async
    @Foreign
    private static func uv_async_init(loop: CPointer<UInt8>, async: CPointer<UInt8>): Int32
    @Foreign
    private static func uv_async_send(async: CPointer<UInt8>): Int32

    // Prepare/Check/Idle
    @Foreign
    private static func uv_prepare_init(loop: CPointer<UInt8>, prepare: CPointer<UInt8>): Int32
    @Foreign
    private static func uv_prepare_start(prepare: CPointer<UInt8>): Int32
    @Foreign
    private static func uv_prepare_stop(prepare: CPointer<UInt8>): Int32
    @Foreign
    private static func uv_check_init(loop: CPointer<UInt8>, check: CPointer<UInt8>): Int32
    @Foreign
    private static func uv_check_start(check: CPointer<UInt8>): Int32
    @Foreign
    private static func uv_check_stop(check: CPointer<UInt8>): Int32
    @Foreign
    private static func uv_idle_init(loop: CPointer<UInt8>, idle: CPointer<UInt8>): Int32
    @Foreign
    private static func uv_idle_start(idle: CPointer<UInt8>): Int32
    @Foreign
    private static func uv_idle_stop(idle: CPointer<UInt8>): Int32

    // 辅助
    @Foreign
    private static func unsafeMallocSockaddrIn(): CPointer<UInt8>
    @Foreign
    private static func unsafeFreeSockaddrIn(ptr: CPointer<UInt8>): Unit
    @Foreign
    private static func parseAddress(host: String, port: Int64, addr: CPointer<UInt8>): Int32
}
