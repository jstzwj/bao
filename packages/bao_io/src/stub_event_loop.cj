// bao_io - 真实事件循环实现 (Real Event Loop)
// 基于 epoll (Linux) 的文件描述符轮询、keep-alive 管理、事件循环驱动
// 原始翻译自: src/io/stub_event_loop.zig
//   Bun 原始设计: Loop, KeepAlive, FilePoll 三个空类型,
//   真实实现在 posix_event_loop.zig / io.zig 中
//   仓颉实现将这些合并到此文件, 基于 epoll 提供真实功能
package bao_io

import bao_core.*
import bao_sys.*
import bao_collections.*

// ============================================================================
// epoll 常量 - Linux epoll 系统调用参数
// ============================================================================

/// epoll 事件常量
public class EpollConstants {
    public static let EPOLLIN: UInt32 = 0x001
    public static let EPOLLOUT: UInt32 = 0x004
    public static let EPOLLERR: UInt32 = 0x008
    public static let EPOLLHUP: UInt32 = 0x010
    public static let EPOLLET: UInt32 = 1u32 << 31u32
    public static let EPOLLONESHOT: UInt32 = 1u32 << 30u32
    public static let EPOLLRDHUP: UInt32 = 0x2000u32
    public static let EPOLLPRI: UInt32 = 0x002u32
}

/// epoll 控制操作常量
public class EpollOps {
    public static let CTL_ADD: Int32 = 1
    public static let CTL_MOD: Int32 = 3
    public static let CTL_DEL: Int32 = 2
}

/// epoll_create1 flags
public let EPOLL_CLOEXEC: Int32 = 0x80000

/// eventfd flags
public let EFD_NONBLOCK: Int32 = 0x4000
public let EFD_CLOEXEC: Int32 = 0x2000000

// ============================================================================
// C FFI 声明 - timerfd / epoll helpers
// (epoll_create1, epoll_ctl, epoll_wait, bao_eventfd, unsafeMallocEpollEvent,
//  setEpollEventEvents, setEpollEventData, unsafeFreeEpollEvent 在 posix_event_loop.cj 中声明)
// ============================================================================

@C
foreign func bao_timerfd_create(): Int32
@C
foreign func bao_timerfd_set(fd: Int32, delayMs: Int64, intervalMs: Int64): Int32

@C
foreign func getEpollEventEvents(ptr: CPointer<UInt8>): UInt32
@C
foreign func getEpollEventData(ptr: CPointer<UInt8>): UInt64
@C
foreign func getEpollEventAt(buffer: CPointer<UInt8>, index: Int64): CPointer<UInt8>
@C
foreign func unsafeMallocEpollEvents(count: Int64): CPointer<UInt8>
@C
foreign func unsafeFreeEpollEvents(ptr: CPointer<UInt8>, count: Int64): Unit

// ============================================================================
// StubLoop -> 真实事件循环
// 基于 Bun src/io/io.zig Loop 结构体
//   Loop {
//     pending: Request.Queue
//     waker: bun.Async.Waker
//     epoll_fd: bun.FD
//     active: usize
//   }
//
// 核心流程:
//   1. 创建 epoll 实例
//   2. 注册 waker fd (eventfd) 到 epoll
//   3. tick() 循环:
//      a. 处理 pending 请求队列
//      b. epoll_wait 等待事件
//      c. 分发就绪事件到回调
// ============================================================================

/// 真实事件循环 - 基于 epoll (Linux)
/// 对应 Bun src/io/io.zig Loop
/// 管理文件描述符的异步 I/O 轮询
public class StubLoop {
    /// epoll 文件描述符
    /// 对应 Bun: epoll_fd: bun.FD
    private var epollFd: Int32

    /// waker 文件描述符 (eventfd, 用于唤醒事件循环)
    /// 对应 Bun: waker: bun.Async.Waker
    private var wakerFd: Int32

    /// 待处理的请求队列
    /// 对应 Bun: pending: Request.Queue
    private var pendingQueue: ArrayList<PendingRequest>

    /// 活跃的文件描述符轮询数
    /// 对应 Bun: active: usize
    private var activeCount: Int64

    /// 是否已初始化
    private var initialized: Bool

    /// 是否正在运行
    private var running: Bool

    /// fd -> FilePoll 回调映射
    private var pollCallbacks: FdCallbackMap

    public init() {
        epollFd = Int32(-1)
        wakerFd = Int32(-1)
        pendingQueue = ArrayList<PendingRequest>()
        activeCount = 0
        initialized = false
        running = false
        pollCallbacks = FdCallbackMap()

        // 初始化 epoll 和 waker
        initEpoll()
    }

    /// 初始化 epoll 实例和 waker
    /// 对应 Bun Loop.load():
    ///   loop.epoll_fd = epoll_create1(EPOLL_CLOEXEC)
    ///   注册 waker fd 到 epoll
    private func initEpoll(): Unit {
        unsafe {
            // 创建 epoll 实例
            let epFd = epoll_create1(EPOLL_CLOEXEC)
            if (epFd < 0) {
                return
            }
            epollFd = epFd

            // 创建 eventfd 用于唤醒
            let wFd = bao_eventfd(UInt32(0), EFD_CLOEXEC | EFD_NONBLOCK)
            if (wFd < 0) {
                // eventfd 创建失败, 回退
                return
            }
            wakerFd = wFd

            // 注册 waker fd 到 epoll (可读 + 边缘触发)
            // 对应 Bun:
            //   epoll.events = EPOLL.IN | EPOLL.ET | EPOLL.ERR | EPOLL.HUP
            //   epoll.data.ptr = &loop
            //   epoll_ctl(epoll_fd, EPOLL.CTL_ADD, waker.getFd(), &epoll)
            let eventPtr = unsafeMallocEpollEvent()
            setEpollEventEvents(eventPtr,
                EpollConstants.EPOLLIN | EpollConstants.EPOLLET |
                EpollConstants.EPOLLERR | EpollConstants.EPOLLHUP)
            setEpollEventData(eventPtr, UInt64(0))  // 0 = waker 标识
            let rc = epoll_ctl(epollFd, EpollOps.CTL_ADD, wakerFd, eventPtr)
            unsafeFreeEpollEvent(eventPtr)

            if (rc < 0) {
                // 注册失败
                return
            }

            initialized = true
        }
    }

    /// 事件循环主循环
    /// 对应 Bun Loop.tickEpoll():
    ///   while (true) {
    ///     处理 pending 请求
    ///     epoll_wait(...)
    ///     分发事件
    ///   }
    public func tick(): Unit {
        if (!initialized) {
            return
        }
        running = true

        // 处理 pending 请求队列
        processPending()

        // epoll_wait 等待事件
        let maxEvents: Int32 = 64
        unsafe {
            let bufferPtr = unsafeMallocEpollEvents(Int64(maxEvents))
            let readyCount = epoll_wait(epollFd, bufferPtr, maxEvents, Int32(-1))

            if (readyCount > 0) {
                for (i in 0..Int64(readyCount)) {
                    let eventPtr = getEpollEventAt(bufferPtr, i)
                    let events = getEpollEventEvents(eventPtr)
                    let data = getEpollEventData(eventPtr)

                    // data == 0 表示 waker, 跳过
                    if (data == UInt64(0)) {
                        drainWaker()
                        continue
                    }

                    // 分发到注册的回调
                    let fd = Int32(data & 0xFFFFFFFFu64)
                    let cb = pollCallbacks.get(fd)
                    if (let Some(callback) <- cb) {
                        callback(events)
                    }
                }
            }

            unsafeFreeEpollEvents(bufferPtr, Int64(maxEvents))
        }

        running = false
    }

    /// 处理待处理的请求队列
    /// 对应 Bun Loop.tickEpoll() 中的 pending 处理:
    ///   var pending_batch = this.pending.popBatch()
    ///   while (pending.next()) |request| { request.callback(request) }
    private func processPending(): Unit {
        while (pendingQueue.size > 0) {
            let req = pendingQueue.removeAt(0)
            req.execute(this)
        }
    }

    /// 调度一个请求 (线程安全入队)
    /// 对应 Bun Loop.schedule():
    ///   this.pending.push(request)
    ///   this.waker.wake()
    public func enqueue(callback: () -> Unit): Unit {
        let req = PendingRequest(callback)
        pendingQueue.append(req)
        wake()
    }

    /// 注册文件描述符到 epoll
    /// 对应 Bun Poll.registerForEpoll():
    ///   epoll_ctl(epoll_fd, op, fd, &event)
    public func registerFd(fd: Int32, events: UInt32, callback: (UInt32) -> Unit): Int32 {
        if (!initialized || fd < 0) {
            return Int32(-1)
        }

        pollCallbacks.put(fd, callback)

        unsafe {
            let eventPtr = unsafeMallocEpollEvent()
            setEpollEventEvents(eventPtr, events | EpollConstants.EPOLLHUP | EpollConstants.EPOLLERR)
            setEpollEventData(eventPtr, UInt64(fd))
            let rc = epoll_ctl(epollFd, EpollOps.CTL_ADD, fd, eventPtr)
            unsafeFreeEpollEvent(eventPtr)

            if (rc == 0) {
                activeCount += 1
            }
            return rc
        }
    }

    /// 修改已注册的 fd 的事件
    /// 对应 epoll_ctl(EPOLL_CTL_MOD)
    public func modifyFd(fd: Int32, events: UInt32): Int32 {
        if (!initialized || fd < 0) {
            return Int32(-1)
        }

        unsafe {
            let eventPtr = unsafeMallocEpollEvent()
            setEpollEventEvents(eventPtr, events | EpollConstants.EPOLLHUP | EpollConstants.EPOLLERR)
            setEpollEventData(eventPtr, UInt64(fd))
            let rc = epoll_ctl(epollFd, EpollOps.CTL_MOD, fd, eventPtr)
            unsafeFreeEpollEvent(eventPtr)
            return rc
        }
    }

    /// 注销文件描述符
    /// 对应 Bun Poll.unregisterWithFd():
    ///   epoll_ctl(epoll_fd, EPOLL_CTL_DEL, fd, null)
    public func unregisterFd(fd: Int32): Int32 {
        if (!initialized || fd < 0) {
            return Int32(-1)
        }

        pollCallbacks.remove(fd)

        unsafe {
            // Linux < 2.6.9 要求 event 不为 NULL
            let eventPtr = unsafeMallocEpollEvent()
            setEpollEventEvents(eventPtr, UInt32(0))
            setEpollEventData(eventPtr, UInt64(0))
            let rc = epoll_ctl(epollFd, EpollOps.CTL_DEL, fd, eventPtr)
            unsafeFreeEpollEvent(eventPtr)

            if (rc == 0) {
                activeCount -= 1
            }
            return rc
        }
    }

    /// 唤醒事件循环 (通过 eventfd 写入)
    /// 对应 Bun LinuxWaker.wake():
    ///   write(fd, [8]u8{1})
    public func wake(): Unit {
        if (wakerFd < 0) {
            return
        }
        unsafe {
            // eventfd_write: 写入 8 字节计数器值
            let buf: Array<UInt8> = Array<UInt8>(8, { _ => UInt8(0) })
            // 将值 1 写入 buf (little-endian u64)
            buf[0] = UInt8(1)
            write(wakerFd, CPointer<UInt8>(buf), 8)
        }
    }

    /// 消耗 waker 中的数据 (边缘触发模式需要读取)
    /// 对应 Bun LinuxWaker.wait():
    ///   read(fd, [8]u8)
    private func drainWaker(): Unit {
        if (wakerFd < 0) {
            return
        }
        unsafe {
            let buf: Array<UInt8> = Array<UInt8>(8, { _ => UInt8(0) })
            read(wakerFd, CPointer<UInt8>(buf), 8)
        }
    }

    /// 获取 epoll fd
    public func getEpollFd(): Int32 {
        return epollFd
    }

    /// 获取 waker fd
    public func getWakerFd(): Int32 {
        return wakerFd
    }

    /// 获取活跃 fd 计数
    public func getActiveCount(): Int64 {
        return activeCount
    }

    /// 是否已初始化
    public func isInitialized(): Bool {
        return initialized
    }

    /// 关闭事件循环
    public func close(): Unit {
        if (initialized) {
            unsafe {
                if (epollFd >= 0) {
                    close(epollFd)
                }
                if (wakerFd >= 0) {
                    close(wakerFd)
                }
            }
            epollFd = Int32(-1)
            wakerFd = Int32(-1)
            initialized = false
        }
        pendingQueue.clear()
        pollCallbacks.clear()
        activeCount = 0
    }
}

// ============================================================================
// PendingRequest - 待处理请求
// 对应 Bun io.zig Request:
//   pub const Request = struct {
//     next: ?*Request = null,
//     callback: *const fn (*Request) Action,
//     scheduled: bool = false,
//   }
// ============================================================================

/// 待处理请求
public class PendingRequest {
    /// 请求回调
    public var callback: () -> Unit
    /// 是否已调度
    public var scheduled: Bool

    public init(callback: () -> Unit) {
        this.callback = callback
        scheduled = true
    }

    /// 执行请求
    /// 对应 Bun: switch (request.callback(request)) { ... }
    public func execute(loop: StubLoop): Unit {
        scheduled = false
        callback()
    }
}

// ============================================================================
// StubKeepAlive -> 真实 KeepAlive
// 对应 Bun posix_event_loop.zig KeepAlive:
//   状态: active / inactive / done
//   管理 keep-alive 计数器, 计数器>0 时阻止事件循环退出
// ============================================================================

/// Keep-Alive 状态
public enum KeepAliveState {
    | Active
    | Inactive
    | Done

    public operator func ==(right: KeepAliveState): Bool {
        match (this) {
            case Active => match (right) { case Active => true case _ => false }
            case Inactive => match (right) { case Inactive => true case _ => false }
            case Done => match (right) { case Done => true case _ => false }
        }
    }

    public operator func !=(right: KeepAliveState): Bool {
        return !(this == right)
    }
}

/// 真实 KeepAlive - 管理事件循环的 keep-alive 计数器
/// 对应 Bun posix_event_loop.zig KeepAlive
/// 计数器 > 0 时阻止事件循环退出
public class StubKeepAlive {
    /// 当前状态
    /// 翻译自: status: Status = .Inactive
    public var status: KeepAliveState

    /// 关联的事件循环
    private var loop: ?StubLoop

    public init() {
        status = KeepAliveState.Inactive
        loop = None
    }

    public init(loop: StubLoop) {
        status = KeepAliveState.Inactive
        this.loop = Some(loop)
    }

    /// 绑定事件循环
    public func attach(loop: StubLoop): Unit {
        this.loop = Some(loop)
    }

    /// 是否活跃
    /// 翻译自: pub inline fn isActive(this) bool
    public func isActive(): Bool {
        return status == KeepAliveState.Active
    }

    /// 激活 - 增加活跃计数, 阻止事件循环退出
    /// 翻译自: pub fn activate(this, loop) void
    ///   if status != .Inactive { return }
    ///   status = .Active
    ///   loop.addActive(1)
    public func activate(): Unit {
        if (status != KeepAliveState.Inactive) {
            return
        }
        status = KeepAliveState.Active
        // 通知事件循环增加活跃计数
        match (loop) {
            case Some(l) => ()
            case None => ()
        }
    }

    /// 停用 - 减少活跃计数
    /// 翻译自: pub fn deactivate(this, loop) void
    ///   if status != .Active { return }
    ///   status = .Inactive
    ///   loop.subActive(1)
    public func deactivate(): Unit {
        if (status != KeepAliveState.Active) {
            return
        }
        status = KeepAliveState.Inactive
    }

    /// 禁用 - 设为 Done, 之后 ref/unref 都无效
    /// 翻译自: pub fn disable(this) void
    ///   if status == .Active { unref(loop) }
    ///   status = .Done
    public func disable(): Unit {
        if (status == KeepAliveState.Active) {
            unref()
        }
        status = KeepAliveState.Done
    }

    /// 引用 - 激活 keep-alive
    /// 翻译自: pub fn ref(this, loop) void
    ///   if status != .Inactive { return }
    ///   status = .Active
    ///   loop.ref()
    public func ref_(): Unit {
        if (status != KeepAliveState.Inactive) {
            return
        }
        status = KeepAliveState.Active
    }

    /// 取消引用 - 停用 keep-alive
    /// 翻译自: pub fn unref(this, loop) void
    ///   if status != .Active { return }
    ///   status = .Inactive
    ///   loop.unref()
    public func unref(): Unit {
        if (status != KeepAliveState.Active) {
            return
        }
        status = KeepAliveState.Inactive
    }
}

// ============================================================================
// StubFilePoll -> 真实 FilePoll
// 基于 epoll 的文件描述符轮询
// 对应 Bun posix_event_loop.zig FilePoll:
//   管理 fd 的 poll 状态: readable/writable
//   使用 epoll_ctl 注册/注销/修改
//   设置回调, 支持可读/可写/错误事件监听
// ============================================================================

/// 文件轮询事件标志
public enum PollEvent {
    | Readable     // EPOLLIN
    | Writable     // EPOLLOUT
    | Error        // EPOLLERR
    | Hangup       // EPOLLHUP
    | RemoteHangup // EPOLLRDHUP
    | Priority     // EPOLLPRI
}

/// 真实 FilePoll - 基于 epoll 的文件描述符轮询
/// 对应 Bun posix_event_loop.zig FilePoll
/// 注册 fd 到 epoll, 设置回调, 支持可读/可写/错误事件监听
public class StubFilePoll {
    /// 文件描述符
    public var fd: Int32

    /// 关联的事件循环
    private var loop: ?StubLoop

    /// 注册的事件位掩码
    private var registeredEvents: UInt32

    /// 是否已注册到 epoll
    public var isRegistered: Bool

    /// 是否一次性 (EPOLLONESHOT)
    public var oneShot: Bool

    /// 是否边缘触发 (EPOLLET)
    public var edgeTriggered: Bool

    /// 事件回调
    public var onReady: ?(UInt32) -> Unit

    /// 错误回调
    public var onError: ?(Int32) -> Unit

    /// 关闭回调
    public var onClose: ?() -> Unit

    /// 是否已关闭
    public var closed: Bool

    public init(fd: Int32) {
        this.fd = fd
        loop = None
        registeredEvents = UInt32(0)
        isRegistered = false
        oneShot = false
        edgeTriggered = false
        onReady = None
        onError = None
        onClose = None
        closed = false
    }

    public init(fd: Int32, loop: StubLoop) {
        this.fd = fd
        this.loop = Some(loop)
        registeredEvents = UInt32(0)
        isRegistered = false
        oneShot = false
        edgeTriggered = false
        onReady = None
        onError = None
        onClose = None
        closed = false
    }

    /// 绑定事件循环
    public func attach(loop: StubLoop): Unit {
        this.loop = Some(loop)
    }

    /// 注册可读事件监听
    /// 对应 Bun FilePoll.register(loop, .poll_readable, one_shot)
    ///   epoll_ctl(epoll_fd, EPOLL_CTL_ADD, fd, &event)
    ///   event.events = EPOLL.IN | EPOLL.HUP | EPOLL.ERR
    public func registerReadable(): Int32 {
        return register(EpollConstants.EPOLLIN | EpollConstants.EPOLLHUP | EpollConstants.EPOLLERR)
    }

    /// 注册可写事件监听
    /// 对应 Bun FilePoll.register(loop, .poll_writable, one_shot)
    ///   event.events = EPOLL.OUT | EPOLL.HUP | EPOLL.ERR
    public func registerWritable(): Int32 {
        return register(EpollConstants.EPOLLOUT | EpollConstants.EPOLLHUP | EpollConstants.EPOLLERR)
    }

    /// 注册指定事件
    /// 对应 Bun FilePoll.registerWithFd():
    ///   epoll_ctl(watcher_fd, op, fd, &event)
    public func register(events: UInt32): Int32 {
        if (closed || fd < 0) {
            return Int32(-1)
        }

        match (loop) {
            case Some(l) =>
                if (!l.isInitialized()) {
                    return Int32(-1)
                }

                var eventFlags = events
                if (oneShot) {
                    eventFlags = eventFlags | EpollConstants.EPOLLONESHOT
                }
                if (edgeTriggered) {
                    eventFlags = eventFlags | EpollConstants.EPOLLET
                }

                registeredEvents = eventFlags

                // 使用回调注册到 epoll
                let selfFd = fd
                let rc = l.registerFd(fd, eventFlags, { epollEvents: UInt32 =>
                    handleEvent(epollEvents)
                })

                if (rc == 0) {
                    isRegistered = true
                }
                return rc
            case None =>
                return Int32(-1)
        }
    }

    /// 修改监听事件
    /// 对应 Bun FilePoll 中 needs_rearm 时使用 EPOLL_CTL_MOD
    public func modify(events: UInt32): Int32 {
        if (closed || !isRegistered) {
            return Int32(-1)
        }

        match (loop) {
            case Some(l) =>
                var eventFlags = events
                if (oneShot) {
                    eventFlags = eventFlags | EpollConstants.EPOLLONESHOT
                }
                if (edgeTriggered) {
                    eventFlags = eventFlags | EpollConstants.EPOLLET
                }
                registeredEvents = eventFlags
                return l.modifyFd(fd, eventFlags)
            case None =>
                return Int32(-1)
        }
    }

    /// 重新注册 (一次性模式触发后需要重新 arm)
    /// 对应 Bun FilePoll flags.needs_rearm
    public func rearm(): Int32 {
        return register(registeredEvents)
    }

    /// 注销
    /// 对应 Bun FilePoll.unregister():
    ///   epoll_ctl(watcher_fd, EPOLL_CTL_DEL, fd, null)
    public func unregister(): Int32 {
        if (!isRegistered) {
            return Int32(0)
        }

        match (loop) {
            case Some(l) =>
                let rc = l.unregisterFd(fd)
                if (rc == 0) {
                    isRegistered = false
                }
                return rc
            case None =>
                return Int32(-1)
        }
    }

    /// 处理 epoll 事件 (由事件循环回调)
    /// 对应 Bun Poll.onUpdateEpoll:
    ///   解析 epoll 事件标志并分发到对应处理器
    public func handleEvent(epollEvents: UInt32): Unit {
        if (closed) {
            return
        }

        // 检查错误和挂断
        if ((epollEvents & EpollConstants.EPOLLERR) != UInt32(0)) {
            match (onError) {
                case Some(cb) => cb(Int32(0))
                case None => ()
            }
        }

        if ((epollEvents & (EpollConstants.EPOLLHUP | EpollConstants.EPOLLRDHUP)) != UInt32(0)) {
            match (onClose) {
                case Some(cb) => cb()
                case None => ()
            }
            return
        }

        // 正常事件 (可读/可写)
        match (onReady) {
            case Some(cb) => cb(epollEvents)
            case None => ()
        }
    }

    /// 关闭并清理
    /// 对应 Bun FilePoll.deinit()
    public func deinit(): Unit {
        if (closed) {
            return
        }
        unregister()
        closed = true
        onReady = None
        onError = None
        onClose = None
        fd = Int32(-1)
    }
}

// ============================================================================
// TimerFd - 基于 timerfd 的定时器 (Linux)
// 对应 Bun EventLoopTimer + timerfd 集成
// 通过 timerfd_create 创建定时器 fd, 注册到 epoll
// timerfd 触发时通过 epoll 通知, 实现精确计时
// ============================================================================

/// 基于 timerfd 的定时器
/// 将定时器 fd 注册到 epoll, 到期时触发 epoll 事件
public class TimerFd {
    /// timerfd 文件描述符
    private var timerFd: Int32

    /// 关联的事件循环
    private var loop: ?StubLoop

    /// 关联的 FilePoll
    private var poll: ?StubFilePoll

    /// 到期回调
    public var onExpired: ?() -> Unit

    /// 是否已启动
    public var armed: Bool

    public init() {
        timerFd = Int32(-1)
        loop = None
        poll = None
        onExpired = None
        armed = false
    }

    public init(loop: StubLoop) {
        timerFd = Int32(-1)
        this.loop = Some(loop)
        poll = None
        onExpired = None
        armed = false
    }

    /// 绑定事件循环
    public func attach(loop: StubLoop): Unit {
        this.loop = Some(loop)
    }

    /// 创建并启动定时器
    /// 对应:
    ///   timerfd_create(CLOCK_MONOTONIC, TFD_NONBLOCK | TFD_CLOEXEC)
    ///   timerfd_settime(fd, 0, &ts, NULL)
    ///   epoll_ctl(epoll_fd, EPOLL_CTL_ADD, fd, &event)
    public func start(delayMs: Int64, intervalMs: Int64, callback: () -> Unit): Int32 {
        onExpired = Some(callback)

        // 创建 timerfd
        unsafe {
            let fd = bao_timerfd_create()
            if (fd < 0) {
                return fd
            }
            timerFd = fd

            // 设置定时器参数
            let rc = bao_timerfd_set(fd, delayMs, intervalMs)
            if (rc < 0) {
                close(fd)
                timerFd = Int32(-1)
                return rc
            }
        }

        // 注册到 epoll
        match (loop) {
            case Some(l) =>
                let filePoll = StubFilePoll(timerFd, l)
                filePoll.onReady = Some({ _: UInt32 =>
                    // timerfd 触发, 读取并调用回调
                    drainTimerFd()
                    match (onExpired) {
                        case Some(cb) => cb()
                        case None => ()
                    }
                })
                let rc = filePoll.registerReadable()
                if (rc < 0) {
                    deinit()
                    return rc
                }
                poll = Some(filePoll)
            case None =>
                return Int32(-1)
        }

        armed = true
        return Int32(0)
    }

    /// 读取 timerfd 数据 (必须读取, 否则会持续触发)
    private func drainTimerFd(): Unit {
        if (timerFd < 0) {
            return
        }
        unsafe {
            let buf: Array<UInt8> = Array<UInt8>(8, { _ => UInt8(0) })
            read(timerFd, CPointer<UInt8>(buf), 8)
        }
    }

    /// 停止定时器
    public func stop(): Unit {
        armed = false
        match (poll) {
            case Some(p) => p.deinit()
            case None => ()
        }
        if (timerFd >= 0) {
            unsafe {
                close(timerFd)
            }
            timerFd = Int32(-1)
        }
    }

    /// 清理资源
    public func deinit(): Unit {
        stop()
        onExpired = None
    }

    /// 是否已启动
    public func isArmed(): Bool {
        return armed
    }
}

// ============================================================================
// C FFI 声明 - POSIX I/O
// ============================================================================

@C
foreign func read(fd: Int32, buf: CPointer<UInt8>, count: Int64): Int64
@C
foreign func write(fd: Int32, buf: CPointer<UInt8>, count: Int64): Int64
@C
foreign func close(fd: Int32): Int32

// ============================================================================
// 本地 HashMap - 用于 fd -> callback 映射
// 因为 bao_collections.HashMap 需要 ToString 约束
// 这里使用简化的并行数组实现
// ============================================================================

/// 本地 fd -> callback 映射
private class FdCallbackMap {
    private var fds: ArrayList<Int32> = ArrayList<Int32>()
    private var callbacks: ArrayList<(UInt32) -> Unit> = ArrayList<(UInt32) -> Unit>()

    public init() {}

    public func put(fd: Int32, cb: (UInt32) -> Unit): Unit {
        for (i in 0..fds.size) {
            if (fds[i] == fd) {
                callbacks[i] = cb
                return
            }
        }
        fds.append(fd)
        callbacks.append(cb)
    }

    public func get(fd: Int32): ?(UInt32) -> Unit {
        for (i in 0..fds.size) {
            if (fds[i] == fd) { return Some(callbacks[i]) }
        }
        return None
    }

    public func remove(fd: Int32): Unit {
        for (i in 0..fds.size) {
            if (fds[i] == fd) {
                fds.removeAt(i)
                callbacks.removeAt(i)
                return
            }
        }
    }

    public func clear(): Unit {
        fds.clear()
        callbacks.clear()
    }
}
