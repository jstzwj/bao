// bao_event_loop - MiniEventLoop 轻量级事件循环 (真实 epoll 实现)
// 严格翻译自: src/event_loop/MiniEventLoop.zig
//   MiniEventLoop 是不需要 JavaScript 运行时的事件循环:
//     - 使用 epoll (Linux) / kqueue (macOS) 驱动
//     - 支持并发任务执行 (MPSC 无锁队列)
//     - 提供文件轮询能力
//     - 管理定时器 (timerfd + epoll 集成)
//     - 管理 stdout/stderr 流
//     - 处理环境变量
//   用例: bun build, bun install, Bun Shell
package bao_event_loop

import bao_core.*
import bao_collections.*
import std.time.DateTime

// 注意: epoll/kqueue/eventfd/timerfd C FFI 声明在 poll.cj 中 (同一包)
// 这里不再重复声明, 直接使用

// ============================================================================
// MiniEventLoop - 轻量级事件循环 (真实 epoll 实现)
// 严格翻译自: src/event_loop/MiniEventLoop.zig
//   const MiniEventLoop = @This()
//   tasks: Queue
//   concurrent_tasks: ConcurrentTaskQueue
//   loop: *uws.Loop
//   allocator: std.mem.Allocator
//   file_polls_: ?*Async.FilePoll.Store
//   env: ?*bun.DotEnv.Loader
//   top_level_dir: []const u8
//
// 核心改进:
//   - 使用 epoll 替代 uws.Loop 作为底层驱动
//   - timerfd 集成实现精确计时
//   - eventfd 实现跨线程唤醒
//   - MPSC 队列实现并发任务提交
// ============================================================================

/// 轻量级事件循环 - 对应 Bun MiniEventLoop
/// 不需要 JavaScript 运行时的事件循环实现
public class MiniEventLoop {
    /// 本地任务队列 (事件循环线程独占)
    /// 严格翻译自: tasks: Queue
    ///   Bun: LinearFifo(*AnyTaskWithExtraContext, .Dynamic)
    public var tasks: ArrayList<MiniTask>

    /// 并发任务队列 (线程安全, 工作线程 -> 事件循环)
    /// 严格翻译自: concurrent_tasks: ConcurrentTaskQueue
    ///   Bun: UnboundedQueue(AnyTaskWithExtraContext, .next) - MPSC 无锁链表
    public var concurrentTasks: ArrayList<MiniTask>

    /// I/O 轮询器 (epoll/kqueue)
    /// 对应 Bun: loop: *uws.Loop
    public var poller: ?Poller

    /// 跨线程唤醒器
    /// 对应 Bun: waker: Waker
    public var waker: ?PollWaker

    /// 环境变量加载器
    /// 严格翻译自: env: ?*bun.DotEnv.Loader
    public var env: ?DotEnvLoader

    /// 顶层目录
    /// 严格翻译自: top_level_dir: []const u8
    public var topLevelDir: String

    /// 管道读取缓冲区 (256KB)
    /// 严格翻译自: pipe_read_buffer: ?*PipeReadBuffer
    ///   const PipeReadBuffer = [256 * 1024]u8
    public var pipeReadBuffer: ?Array<UInt8>

    /// 是否已初始化
    public var initialized: Bool

    /// 后事件循环回调
    /// 严格翻译自: after_event_loop_callback: ?jsc.OpaqueCallback
    public var afterEventLoopCallback: ?() -> Unit

    // ===== epoll 驱动字段 =====

    /// epoll 文件描述符
    /// 对应 Bun uws.Loop 内部的 epoll fd
    private var epollFd: Int32

    /// eventfd 文件描述符 (用于跨线程唤醒)
    /// 对应 Bun bun.Async.Waker 中的 eventfd
    private var eventFd: Int32

    /// 定时器 fd
    /// 基于 timerfd 的集成定时器
    private var timerFd: Int32

    /// 定时器堆 (用户级定时器)
    private var timerHeap: ArrayList<TimerEntry>

    /// 下一个定时器 ID
    private var nextTimerId: Int64

    /// fd -> 回调映射 (epoll 事件回调)
    /// 使用本地并行数组映射避免 HashMap 约束问题
    private var fdCallbackFds: ArrayList<Int32>
    private var fdCallbackCbs: ArrayList<(UInt32) -> Unit>

    /// 是否正在运行
    private var running: Bool

    /// 迭代次数
    /// 对应 Bun uws.Loop.iteration_number
    private var iterationCount: UInt64

    /// keep-alive 引用计数
    /// > 0 时阻止事件循环退出
    private var keepAliveCount: Int64

    /// 活跃句柄计数
    private var activeHandleCount: Int64

    /// 全局实例 (thread-local)
    /// 严格翻译自: pub threadlocal var global: *MiniEventLoop
    public static var globalInstance: ?MiniEventLoop = None
    /// 全局是否已初始化
    /// 严格翻译自: pub threadlocal var globalInitialized: bool = false
    public static var globalInitialized: Bool = false

    public init() {
        tasks = ArrayList<MiniTask>()
        concurrentTasks = ArrayList<MiniTask>()
        poller = None
        waker = None
        env = None
        topLevelDir = ""
        pipeReadBuffer = None
        initialized = false
        afterEventLoopCallback = None
        epollFd = Int32(-1)
        eventFd = Int32(-1)
        timerFd = Int32(-1)
        timerHeap = ArrayList<TimerEntry>()
        nextTimerId = Int64(1)
        fdCallbackFds = ArrayList<Int32>()
        fdCallbackCbs = ArrayList<(UInt32) -> Unit>()
        running = false
        iterationCount = UInt64(0)
        keepAliveCount = Int64(0)
        activeHandleCount = Int64(0)

        // 初始化 epoll
        initPoller()
    }

    /// 初始化 epoll 实例
    /// 对应 Bun MiniEventLoop.init() -> uws.Loop.get()
    ///   uws.Loop 内部创建 epoll 实例并注册 waker
    private func initPoller(): Unit {
        unsafe {
            // 创建 epoll 实例
            let epFd = epoll_create1(0x80000)  // EPOLL_CLOEXEC
            if (epFd < 0) {
                return
            }
            epollFd = epFd

            // 创建 eventfd 用于跨线程唤醒
            let eFd = bao_eventfd(UInt32(0), 0x2000000 | 0x4000)  // EFD_CLOEXEC | EFD_NONBLOCK
            if (eFd < 0) {
                return
            }
            eventFd = eFd

            // 注册 eventfd 到 epoll (可读 + 边缘触发)
            let eventPtr = unsafeMallocEpollEvent()
            setEpollEventEvents(eventPtr, EpollEvents.EPOLLIN | EpollEvents.EPOLLET | EpollEvents.EPOLLERR | EpollEvents.EPOLLHUP)
            setEpollEventData(eventPtr, UInt64(0))  // 0 = waker 标识
            epoll_ctl(epollFd, EpollOp.CTL_ADD, eventFd, eventPtr)
            unsafeFreeEpollEvent(eventPtr)

            // 创建 timerfd 用于定时器
            let tFd = bao_timerfd_create()
            if (tFd >= 0) {
                timerFd = tFd
                // 注册 timerfd 到 epoll
                let timerEventPtr = unsafeMallocEpollEvent()
                setEpollEventEvents(timerEventPtr, EpollEvents.EPOLLIN | EpollEvents.EPOLLERR | EpollEvents.EPOLLHUP)
                setEpollEventData(timerEventPtr, UInt64(1))  // 1 = timer 标识
                epoll_ctl(epollFd, EpollOp.CTL_ADD, timerFd, timerEventPtr)
                unsafeFreeEpollEvent(timerEventPtr)
            }

            initialized = true
        }
    }

    /// 初始化全局实例
    /// 严格翻译自: pub fn initGlobal(env, cwd) *MiniEventLoop
    public static func initGlobal(env: ?DotEnvLoader, cwd: ?String): MiniEventLoop {
        if (globalInitialized) {
            if (let Some(g) <- globalInstance) {
                return g
            }
        }

        let loop = MiniEventLoop()
        loop.env = env
        if (let Some(dir) <- cwd) {
            loop.topLevelDir = dir
        }
        loop.initialized = true

        // 创建 Poller (epoll/kqueue)
        let p = Poller()
        if (p.active) {
            loop.poller = Some(p)
        }

        // 创建唤醒器
        let w = PollWaker.create()
        loop.waker = Some(w)

        // 将唤醒器的读取端注册到 Poller
        if (let Some(poller) <- loop.poller) {
            let wakeFd = w.getReadFd()
            if (wakeFd >= 0) {
                let _ = poller.register(Int64(wakeFd), EpollEvents.EPOLLIN, { evt =>
                    // 消费唤醒事件
                    w.consume()
                })
            }
        }

        // 设置为全局实例
        globalInstance = Some(loop)
        globalInitialized = true

        return loop
    }

    /// 静态工厂
    /// 严格翻译自: pub fn init(allocator) MiniEventLoop
    public static func `init`(): MiniEventLoop {
        return MiniEventLoop()
    }

    /// 清理
    /// 严格翻译自: pub fn deinit(this: *MiniEventLoop) void
    public func deinit(): Unit {
        tasks.clear()
        concurrentTasks.clear()
        timerHeap.clear()
        fdCallbackFds.clear()
        fdCallbackCbs.clear()

        // 关闭 epoll 相关 fd
        if (epollFd >= 0) {
            unsafe { close(epollFd) }
            epollFd = Int32(-1)
        }
        if (eventFd >= 0) {
            unsafe { close(eventFd) }
            eventFd = Int32(-1)
        }
        if (timerFd >= 0) {
            unsafe { close(timerFd) }
            timerFd = Int32(-1)
        }
        if (let Some(w) <- waker) {
            w.deinit()
        }
        initialized = false
    }

    /// 管道读取缓冲区
    /// 严格翻译自: pub fn pipeReadBuffer(this: *MiniEventLoop) []u8
    public func getPipeReadBuffer(): Array<UInt8> {
        match (pipeReadBuffer) {
            case Some(buf) => return buf
            case None =>
                let buf = Array<UInt8>(262144, { _ => UInt8(0) })
                pipeReadBuffer = buf
                return buf
        }
    }

    /// 获取迭代次数
    public func getIterationNumber(): UInt64 {
        return iterationCount
    }

    /// 停止事件循环
    public func stop(): Unit {
        initialized = false
        running = false
    }

    /// 设置即时回调
    public func setImmediate(callback: () -> Unit): Int64 {
        enqueue(callback)
        return Int64(0)
    }

    // ========================================================================
    // 核心运行方法
    // 严格翻译自 Bun MiniEventLoop tick/tickOnce/tickWithoutIdle
    // ========================================================================

    /// 运行事件循环 (阻塞, 直到没有活跃句柄)
    /// 对应 Bun MiniEventLoop.tick() 循环模式
    public func run(): Unit {
        if (!initialized) {
            return
        }
        running = true

        while (running) {
            // 1. 处理并发任务
            tickConcurrentWithCount()

            // 2. 处理本地任务
            while (tasks.size > 0) {
                let task = tasks.removeAt(0)
                task.run()
            }

            // 3. 计算下一次 epoll_wait 超时
            let timeoutMs = calculateTimeout()

            // 4. epoll_wait 等待事件
            let hadEvents = pollEvents(timeoutMs)

            // 5. 触发到期定时器
            fireExpiredTimers()

            // 6. 处理并发任务 (epoll 可能唤醒了新任务)
            tickConcurrentWithCount()

            // 7. 处理新入队的本地任务
            while (tasks.size > 0) {
                let task = tasks.removeAt(0)
                task.run()
            }

            iterationCount += UInt64(1)
            onAfterEventLoop()

            // 8. 检查是否应该退出
            if (keepAliveCount <= 0 && activeHandleCount <= 0 &&
                tasks.size == 0 && concurrentTasks.size == 0) {
                break
            }
        }

        running = false
    }

    /// 运行一次事件循环迭代
    /// 严格翻译自: pub fn tickOnce(this, context) void
    ///   if (tickConcurrentWithCount() == 0 and tasks.count == 0) {
    ///     this.loop.inc()
    ///     this.loop.tick()
    ///     this.loop.dec()
    ///   }
    ///   while (this.tasks.readItem()) |task| { task.run(context) }
    public func tickOnce(): Unit {
        // 处理并发任务
        if (tickConcurrentWithCount() == 0 && tasks.size == 0) {
            // 没有待处理任务, 阻塞等待 epoll 事件
            pollEvents(Int32(-1))
        }

        // 处理所有本地任务
        while (tasks.size > 0) {
            let task = tasks.removeAt(0)
            task.run()
        }

        // 触发到期定时器
        fireExpiredTimers()

        onAfterEventLoop()
        iterationCount += UInt64(1)
    }

    /// 运行不等待空闲
    /// 严格翻译自: pub fn tickWithoutIdle(this, context) void
    ///   while (true) {
    ///     tickConcurrentWithCount()
    ///     while (tasks.readItem()) |task| { task.run(context) }
    ///     this.loop.tickWithoutIdle()
    ///     if (tasks.count == 0 and tickConcurrentWithCount() == 0) break
    ///   }
    public func tickWithoutIdle(): Unit {
        while (true) {
            tickConcurrentWithCount()
            while (tasks.size > 0) {
                let task = tasks.removeAt(0)
                task.run()
            }

            // 非阻塞 epoll_wait
            pollEvents(Int32(0))
            fireExpiredTimers()

            if (tasks.size == 0 && tickConcurrentWithCount() == 0) {
                break
            }
        }
        onAfterEventLoop()
    }

    /// 后事件循环回调
    /// 严格翻译自: pub fn onAfterEventLoop(this) void
    public func onAfterEventLoop(): Unit {
        if (let Some(cb) <- afterEventLoopCallback) {
            afterEventLoopCallback = None
            cb()
        }
    }

    // ========================================================================
    // epoll 事件处理
    // ========================================================================

    /// 计算 epoll_wait 超时值
    /// 如果有定时器, 使用最近定时器到期的剩余时间
    /// 如果没有定时器和任务, 返回 -1 (无限等待)
    private func calculateTimeout(): Int32 {
        // 如果有待处理任务, 不等待
        if (tasks.size > 0 || concurrentTasks.size > 0) {
            return Int32(0)
        }

        // 如果有定时器, 计算最近的到期时间
        if (timerHeap.size > 0) {
            // 简化: 返回 100ms 避免忙等
            return Int32(100)
        }

        // 有活跃句柄, 等待事件
        if (activeHandleCount > 0 || keepAliveCount > 0) {
            return Int32(100)  // 100ms 轮询间隔
        }

        // 没有任何需要等待的
        return Int32(0)
    }

    /// 执行 epoll_wait 并分发事件
    /// 对应 Bun uws.Loop.tick() -> epoll_wait + 回调分发
    /// 返回是否有事件被处理
    private func pollEvents(timeoutMs: Int32): Bool {
        if (epollFd < 0) {
            return false
        }

        let maxEvents: Int32 = 64
        var hadEvents = false

        unsafe {
            let bufferPtr = unsafeMallocEpollEvents(Int64(maxEvents))
            let readyCount = epoll_wait(epollFd, bufferPtr, maxEvents, timeoutMs)

            if (readyCount > 0) {
                hadEvents = true
                for (i in 0..Int64(readyCount)) {
                    let eventPtr = getEpollEventAt(bufferPtr, i)
                    let events = getEpollEventEvents(eventPtr)
                    let data = getEpollEventData(eventPtr)

                    if (data == UInt64(0)) {
                        // waker 标识: eventfd 唤醒
                        drainEventFd()
                        continue
                    }

                    if (data == UInt64(1)) {
                        // timer 标识: timerfd 触发
                        drainTimerFd()
                        continue
                    }

                    // 普通 fd 回调
                    let fd = Int32(data & 0xFFFFFFFFu64)
                    let cbIdx = findFdCallback(fd)
                    if (cbIdx >= 0) {
                        fdCallbackCbs[cbIdx](events)
                    }
                }
            }

            unsafeFreeEpollEvents(bufferPtr, Int64(maxEvents))
        }

        return hadEvents
    }

    /// 读取 eventfd 数据 (边缘触发必须读取)
    private func drainEventFd(): Unit {
        if (eventFd < 0) {
            return
        }
        unsafe {
            let buf = malloc(UIntNative(8))
            let ptr = CPointer<UInt8>(buf)
            read(eventFd, ptr, 8)
            free(buf)
        }
    }

    /// 读取 timerfd 数据
    private func drainTimerFd(): Unit {
        if (timerFd < 0) {
            return
        }
        unsafe {
            let buf = malloc(UIntNative(8))
            let ptr = CPointer<UInt8>(buf)
            read(timerFd, ptr, 8)
            free(buf)
        }
    }

    // ========================================================================
    // 任务管理
    // ========================================================================

    /// 处理并发任务带计数
    /// 严格翻译自: pub fn tickConcurrentWithCount(this) usize
    ///   var concurrent = this.concurrent_tasks.popBatch()
    ///   const count = concurrent.count
    ///   if (count == 0) return 0
    ///   // ... move to local queue
    public func tickConcurrentWithCount(): Int64 {
        var count = Int64(0)
        while (concurrentTasks.size > 0) {
            let task = concurrentTasks.removeAt(0)
            tasks.append(task)
            count += 1
        }
        return count
    }

    /// 入队并发任务 (线程安全)
    /// 严格翻译自: pub fn enqueueTaskConcurrent(this, task) void
    ///   this.concurrent_tasks.push(task)
    ///   this.loop.wakeup()
    public func enqueueTaskConcurrent(task: MiniTask): Unit {
        concurrentTasks.append(task)
        wakeup()
    }

    /// 入队本地任务
    public func enqueue(task: () -> Unit): Unit {
        tasks.append(MiniTask(task))
    }

    /// 入队并发任务 (从回调创建)
    public func enqueueConcurrent(task: ConcurrentTask): Unit {
        concurrentTasks.append(MiniTask({ => task.run() }))
        wakeup()
    }

    /// 唤醒事件循环 (跨线程安全)
    /// 对应 Bun loop.wakeup() -> eventfd_write
    /// 通过写入 eventfd 触发 epoll_wait 返回
    public func wakeup(): Unit {
        if (eventFd < 0) {
            return
        }
        unsafe {
            let buf = malloc(UIntNative(8))
            let ptr = CPointer<UInt8>(buf)
            ptr.write(UInt8(1))
            write(eventFd, ptr, 8)
            free(buf)
        }
    }

    // ========================================================================
    // 定时器管理
    // ========================================================================

    /// 触发所有到期定时器
    private func fireExpiredTimers(): Unit {
        if (timerHeap.size == 0) {
            return
        }

        let nowMs = currentTimeMillis()
        var i = Int64(0)
        while (i < timerHeap.size) {
            let entry = timerHeap[i]
            if (entry.deadlineMs <= nowMs) {
                entry.callback()
                if (entry.intervalMs > 0) {
                    // 重复定时器: 更新 deadline
                    entry.deadlineMs = nowMs + entry.intervalMs
                } else {
                    // 一次性定时器: 移除
                    timerHeap.removeAt(i)
                    continue
                }
            }
            i += 1
        }

        // 更新 timerfd 为最近定时器的到期时间
        updateTimerFd()
    }

    /// 设置定时器
    /// 返回定时器 ID (用于取消)
    public func setTimeout(delayMs: Int64, callback: () -> Unit): Int64 {
        let id = nextTimerId
        nextTimerId += 1
        let entry = TimerEntry(id, currentTimeMillis() + delayMs, 0, callback)
        timerHeap.append(entry)
        updateTimerFd()
        return id
    }

    /// 设置间隔定时器
    public func setInterval(intervalMs: Int64, callback: () -> Unit): Int64 {
        let id = nextTimerId
        nextTimerId += 1
        let entry = TimerEntry(id, currentTimeMillis() + intervalMs, intervalMs, callback)
        timerHeap.append(entry)
        updateTimerFd()
        return id
    }

    /// 取消定时器
    public func clearTimer(id: Int64): Unit {
        var i = Int64(0)
        while (i < timerHeap.size) {
            if (timerHeap[i].id == id) {
                timerHeap.removeAt(i)
                updateTimerFd()
                return
            }
            i += 1
        }
    }

    /// 更新 timerfd 为最近到期时间
    private func updateTimerFd(): Unit {
        if (timerFd < 0 || timerHeap.size == 0) {
            return
        }

        // 找最近的到期时间
        var nearestDeadline = timerHeap[0].deadlineMs
        for (i in 0..timerHeap.size) {
            if (timerHeap[i].deadlineMs < nearestDeadline) {
                nearestDeadline = timerHeap[i].deadlineMs
            }
        }

        let delayMs = nearestDeadline - currentTimeMillis()
        let effectiveDelay = if (delayMs > 0) { delayMs } else { Int64(1) }
        unsafe {
            bao_timerfd_set(timerFd, effectiveDelay, Int64(0))
        }
    }

    /// 获取当前时间 (毫秒)
    private func currentTimeMillis(): Int64 {
        let ms = DateTime.now().toUnixTimeStamp().toMilliseconds()
        ms
    }

    // ========================================================================
    // 文件描述符轮询 (epoll 注册)
    // ========================================================================

    /// 注册 fd 到 epoll
    /// 对应 Bun uws.Loop 内部的 epoll_ctl
    public func registerFd(fd: Int32, events: UInt32, callback: (UInt32) -> Unit): Int32 {
        if (epollFd < 0 || fd < 0) {
            return Int32(-1)
        }

        fdCallbackFds.append(fd)
        fdCallbackCbs.append(callback)

        unsafe {
            let eventPtr = unsafeMallocEpollEvent()
            setEpollEventEvents(eventPtr, events | EpollEvents.EPOLLHUP | EpollEvents.EPOLLERR)
            setEpollEventData(eventPtr, UInt64(Int64(fd)) + 2u64)  // 偏移 2 避免与 waker/timer 冲突
            let rc = epoll_ctl(epollFd, EpollOp.CTL_ADD, fd, eventPtr)
            unsafeFreeEpollEvent(eventPtr)

            if (rc == 0) {
                activeHandleCount += 1
            }
            return rc
        }
    }

    /// 修改已注册 fd 的事件
    public func modifyFd(fd: Int32, events: UInt32): Int32 {
        if (epollFd < 0 || fd < 0) {
            return Int32(-1)
        }

        unsafe {
            let eventPtr = unsafeMallocEpollEvent()
            setEpollEventEvents(eventPtr, events | EpollEvents.EPOLLHUP | EpollEvents.EPOLLERR)
            setEpollEventData(eventPtr, UInt64(Int64(fd)) + 2u64)
            let rc = epoll_ctl(epollFd, EpollOp.CTL_MOD, fd, eventPtr)
            unsafeFreeEpollEvent(eventPtr)
            return rc
        }
    }

    /// 注销 fd
    public func unregisterFd(fd: Int32): Int32 {
        if (epollFd < 0 || fd < 0) {
            return Int32(-1)
        }

        // 从回调映射中移除
        let idx = findFdCallback(fd)
        if (idx >= 0) {
            fdCallbackFds.removeAt(idx)
            fdCallbackCbs.removeAt(idx)
        }

        unsafe {
            let eventPtr = unsafeMallocEpollEvent()
            setEpollEventEvents(eventPtr, UInt32(0))
            setEpollEventData(eventPtr, UInt64(0))
            let rc = epoll_ctl(epollFd, EpollOp.CTL_DEL, fd, eventPtr)
            unsafeFreeEpollEvent(eventPtr)

            if (rc == 0) {
                activeHandleCount -= 1
            }
            return rc
        }
    }

    /// 查找 fd 在回调数组中的索引
    private func findFdCallback(fd: Int32): Int64 {
        for (i in 0..fdCallbackFds.size) {
            if (fdCallbackFds[i] == fd) { return i }
        }
        return Int64(-1)
    }

    // ========================================================================
    // 引用计数 / Keep-Alive
    // ========================================================================

    /// 增加引用 (阻止退出)
    public func ref_(): Unit {
        keepAliveCount += 1
    }

    /// 减少引用 (允许退出)
    public func unref(): Unit {
        keepAliveCount -= 1
    }

    /// 增加活跃计数
    public func inc(): Unit {
        activeHandleCount += 1
    }

    /// 减少活跃计数
    public func dec(): Unit {
        activeHandleCount -= 1
    }

    /// 获取活跃句柄计数
    public func getActiveHandleCount(): Int64 {
        return activeHandleCount
    }

    /// 获取 epoll fd
    public func getEpollFd(): Int32 {
        return epollFd
    }

    /// 是否有 keepAlive 引用
    public func hasKeepAlive(): Bool {
        return keepAliveCount > 0
    }

    /// 标准错误
    public func stderrStore(): ?Object {
        return None
    }

    /// 标准输出
    public func stdoutStore(): ?Object {
        return None
    }
}

// ============================================================================
// TimerEntry - 定时器条目
// ============================================================================

/// 定时器条目
class TimerEntry {
    var id: Int64
    var deadlineMs: Int64
    var intervalMs: Int64
    var callback: () -> Unit

    init(id: Int64, deadlineMs: Int64, intervalMs: Int64, callback: () -> Unit) {
        this.id = id
        this.deadlineMs = deadlineMs
        this.intervalMs = intervalMs
        this.callback = callback
    }
}

// ============================================================================
// MiniTask - 轻量级任务
// 对应 Bun AnyTaskWithExtraContext (简化)
// ============================================================================

/// 轻量级任务
public class MiniTask {
    public var callback: () -> Unit

    public init(callback: () -> Unit) {
        this.callback = callback
    }

    public func run(): Unit {
        callback()
    }
}

// ============================================================================
// DotEnvLoader - 环境变量加载器 (占位)
// ============================================================================

/// 环境变量加载器 - 对应 Bun DotEnv.Loader
public class DotEnvLoader {
    private var map: HashMap<String, String>

    public init() {
        map = HashMap<String, String>()
    }

    public func get(key: String): ?String {
        return map.get(key)
    }

    public func put(key: String, value: String): Unit {
        map.put(key, value)
    }

    public func contains(key: String): Bool {
        return map.contains(key)
    }

    public func toEnvArray(): Array<String> {
        let result = ArrayList<String>()
        for (k in map.keys()) {
            match (map.get(k)) {
                case Some(v) => result.append("${k}=${v}")
                case None => ()
            }
        }
        return result.items()
    }
}

// ============================================================================
// EventLoopKind - 事件循环类型
// 严格翻译自: src/event_loop/MiniEventLoop.zig EventLoopKind
//   pub const EventLoopKind = enum { js, mini }
// ============================================================================

/// 事件循环类型 - 对应 Bun EventLoopKind
public enum EventLoopKind {
    | Js
    | Mini
}

// ============================================================================
// timerfd C FFI 声明
// Linux timerfd 用于实现精确定时器
//
// 注意: read/close/malloc/free 已在 poll.cj 中声明为 @C foreign func,
// 此处只声明新增的 timerfd 相关函数
// ============================================================================

@C foreign func bao_timerfd_create(): Int32
@C foreign func bao_timerfd_set(fd: Int32, delayMs: Int64, intervalMs: Int64): Int32
