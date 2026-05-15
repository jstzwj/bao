// bao_event_loop - Poll 集成和任务队列
// 严格翻译自: src/event_loop/poller.zig (epoll/kqueue C FFI 集成)
//   Bun 使用 epoll (Linux) / kqueue (macOS) 进行异步 I/O
//   仓颉通过 C FFI 直接调用 epoll/kqueue 系统调用
//
// 同时翻译自: src/event_loop/ConcurrentTask.rs (跨线程任务队列)
//   Bun 使用 ConcurrentTaskQueue 安全地从工作线程提交任务到事件循环
//   MPSC (Multi-Producer Single-Consumer) 无锁队列
package bao_event_loop

import bao_core.*
import bao_sys.*
import bao_threading.*

// ============================================================================
// Epoll 常量 - Linux epoll 系统调用参数
// 严格翻译自: Linux <sys/epoll.h>
//   EPOLLIN, EPOLLOUT, EPOLLERR, EPOLLHUP, EPOLLET, EPOLLONESHOT
//   EPOLL_CTL_ADD, EPOLL_CTL_MOD, EPOLL_CTL_DEL
// ============================================================================

/// epoll 事件常量 - 对应 Linux EPOLLIN 等
public class EpollEvents {
    /// 可读事件
    public static let EPOLLIN: UInt32 = 0x001
    /// 可写事件
    public static let EPOLLOUT: UInt32 = 0x004
    /// 错误事件
    public static let EPOLLERR: UInt32 = 0x008
    /// 挂起事件
    public static let EPOLLHUP: UInt32 = 0x010
    /// 边缘触发模式
    public static let EPOLLET: UInt32 = 1 << 31
    /// 一次性事件
    public static let EPOLLONESHOT: UInt32 = 1 << 30
    /// 优先级通知 (readable urgent)
    public static let EPOLLPRI: UInt32 = 0x002
    /// 对端关闭连接
    public static let EPOLLRDHUP: UInt32 = 0x2000
}

/// epoll 控制操作
public class EpollOp {
    public static let CTL_ADD: Int32 = 1
    public static let CTL_MOD: Int32 = 3
    public static let CTL_DEL: Int32 = 2
}

/// epoll_create1 标志
public let EPOLL_CLOEXEC: Int32 = 0x80000

// ============================================================================
// Kqueue 常量 - macOS/BSD kqueue 系统调用参数
// 严格翻译自: BSD <sys/event.h>
//   EVFILT_READ, EVFILT_WRITE, EV_ADD, EV_DELETE, EV_ENABLE, EV_DISABLE
//   EV_CLEAR, EV_ONESHOT, EV_EOF, EV_ERROR
// ============================================================================

/// kqueue 事件过滤器和标志
public class KqueueEvents {
    /// 读过滤器
    public static let EVFILT_READ: Int16 = -1
    /// 写过滤器
    public static let EVFILT_WRITE: Int16 = -2
    /// 添加事件
    public static let EV_ADD: UInt16 = 0x0001
    /// 删除事件
    public static let EV_DELETE: UInt16 = 0x0002
    /// 启用事件
    public static let EV_ENABLE: UInt16 = 0x0004
    /// 禁用事件
    public static let EV_DISABLE: UInt16 = 0x0008
    /// 一次性事件后清除
    public static let EV_ONESHOT: UInt16 = 0x0010
    /// 事件触发后清除状态
    public static let EV_CLEAR: UInt16 = 0x0020
    /// EOF 标志
    public static let EV_EOF: UInt16 = 0x8000
    /// 错误标志
    public static let EV_ERROR: UInt16 = 0x4000
}

// ============================================================================
// PollEvent - 轮询事件
// 严格翻译自: epoll_event / kevent 结构
//   epoll: struct epoll_event { uint32_t events; epoll_data_t data }
//   kqueue: struct kevent { uintptr_t ident; short filter; u_short flags; ... }
// ============================================================================

/// 轮询事件 - 对应 epoll_event / kevent
public class PollEvent {
    /// 文件描述符
    public var fd: Int64
    /// 事件位掩码
    public var events: UInt32
    /// 用户数据
    public var userData: Int64

    public init() {
        fd = -1
        events = 0
        userData = 0
    }

    public init(fd: Int64, events: UInt32) {
        this.fd = fd
        this.events = events
        userData = 0
    }

    /// 是否可读
    public func isReadable(): Bool {
        (events & EpollEvents.EPOLLIN) != 0
    }

    /// 是否可写
    public func isWritable(): Bool {
        (events & EpollEvents.EPOLLOUT) != 0
    }

    /// 是否有错误
    public func isError(): Bool {
        (events & EpollEvents.EPOLLERR) != 0
    }

    /// 是否挂起
    public func isHangup(): Bool {
        (events & EpollEvents.EPOLLHUP) != 0
    }

    /// 是否优先级数据 (urgent)
    public func isPriority(): Bool {
        (events & EpollEvents.EPOLLPRI) != 0
    }

    /// 是否对端关闭
    public func isRemoteHangup(): Bool {
        (events & EpollEvents.EPOLLRDHUP) != 0
    }
}

// ============================================================================
// EpollData - epoll_event.data 联合体
// 严格翻译自: union epoll_data { void *ptr; int fd; uint32_t u32; uint64_t u64 }
// ============================================================================

/// epoll 数据 - 对应 epoll_data_t
/// 使用 u64 存储所有变体
public class EpollData {
    public var value: UInt64

    public init() {
        value = 0
    }

    public init(fd: Int64) {
        value = UInt64(fd)
    }

    public init(ptr: UInt64) {
        value = ptr
    }

    public func getFd(): Int64 {
        Int64(value & 0xFFFFFFFF)
    }
}

// ============================================================================
// Poller - I/O 轮询器 (epoll/kqueue)
// 严格翻译自: src/event_loop/poller.zig
//   Bun 使用平台特定的 I/O 多路复用:
//   - Linux: epoll (epoll_create1, epoll_ctl, epoll_wait)
//   - macOS: kqueue (kqueue, kevent)
//
//   epoll C FFI 声明:
//     int epoll_create1(int flags);
//     int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event);
//     int epoll_wait(int epfd, struct epoll_event *events, int maxevents, int timeout);
//
//   kqueue C FFI 声明:
//     int kqueue(void);
//     int kevent(int kq, const struct kevent *changelist, int nchanges,
//                struct kevent *eventlist, int nevents, const struct timespec *timeout);
//
//   仓颉使用 CPointer<T> 和 unsafe 块进行 C FFI 调用
// ============================================================================

/// I/O 轮询器 - 对应 Bun Poller
/// 管理文件描述符的事件注册和等待
/// 使用 epoll (Linux) 或 kqueue (macOS) 进行 I/O 多路复用
public class Poller {
    /// epoll/kqueue 实例的文件描述符
    private var pollFd: Int64
    /// 注册的文件描述符映射 (fd -> PollEntry)
    private var registered: HashMap<Int64, PollEntry>
    /// 是否活跃
    private var active: Bool
    /// 平台: "epoll" 或 "kqueue"
    private var platform: String

    public init() {
        registered = HashMap<Int64, PollEntry>()
        active = false
        pollFd = -1
        platform = ""

        // 尝试创建 epoll 实例 (Linux)
        let epollResult = createEpoll()
        if (epollResult >= 0) {
            pollFd = epollResult
            active = true
            platform = "epoll"
            return
        }

        // 尝试创建 kqueue 实例 (macOS)
        let kqResult = createKqueue()
        if (kqResult >= 0) {
            pollFd = kqResult
            active = true
            platform = "kqueue"
            return
        }

        // 两个都不可用
        pollFd = -1
        active = false
    }

    // ========================================================================
    // epoll C FFI - Linux
    // 严格翻译自: <sys/epoll.h>
    //   int epoll_create1(int flags);
    //     创建 epoll 实例, flags: EPOLL_CLOEXEC
    //   int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event);
    //     控制 epoll 注册: ADD/MOD/DEL
    //   int epoll_wait(int epfd, struct epoll_event *events, int maxevents, int timeout);
    //     等待事件: timeout=-1 无限, 0 立即返回
    // ========================================================================

    /// 创建 epoll 实例 - 对应 epoll_create1(EPOLL_CLOEXEC)
    private static func createEpoll(): Int64 {
        unsafe {
            return epoll_create1(EPOLL_CLOEXEC)
        }
    }

    /// epoll 控制 - 对应 epoll_ctl(epfd, op, fd, event)
    private static func epollControl(epfd: Int64, op: Int32, fd: Int64, events: UInt32, userData: UInt64): Int64 {
        unsafe {
            // 构建 epoll_event 结构
            // struct epoll_event { uint32_t events; epoll_data_t data; }
            // epoll_data_t 是 union { void* ptr; int fd; uint32_t u32; uint64_t u64 }
            let eventPtr = unsafeMallocEpollEvent()
            setEpollEventEvents(eventPtr, events)
            setEpollEventData(eventPtr, userData)
            let result = epoll_ctl(Int32(epfd), op, Int32(fd), eventPtr)
            unsafeFreeEpollEvent(eventPtr)
            return Int64(result)
        }
    }

    /// epoll 等待 - 对应 epoll_wait(epfd, events, maxevents, timeout)
    private static func epollWait(epfd: Int64, maxEvents: Int32, timeoutMs: Int64): Array<PollEvent> {
        unsafe {
            let events = ArrayList<PollEvent>()
            // 分配事件数组
            let bufferPtr = unsafeMallocEpollEvents(Int64(maxEvents))
            let readyCount = epoll_wait(Int32(epfd), bufferPtr, maxEvents, Int32(timeoutMs))

            if (readyCount > 0) {
                for (i in 0..Int64(readyCount)) {
                    let eventPtr = getEpollEventAt(bufferPtr, i)
                    let evts = getEpollEventEvents(eventPtr)
                    let data = getEpollEventData(eventPtr)
                    let fd = Int64(data & 0xFFFFFFFF)
                    events.append(PollEvent(fd, evts))
                }
            }

            unsafeFreeEpollEvents(bufferPtr, Int64(maxEvents))
            return events.toArray()
        }
    }

    // ========================================================================
    // kqueue C FFI - macOS
    // 严格翻译自: <sys/event.h>
    //   int kqueue(void);
    //   int kevent(int kq, const struct kevent *changelist, int nchanges,
    //              struct kevent *eventlist, int nevents, const struct timespec *timeout);
    //   EV_SET(&kev, ident, filter, flags, fflags, data, udata)
    // ========================================================================

    /// 创建 kqueue 实例 - 对应 kqueue()
    private static func createKqueue(): Int64 {
        unsafe {
            return kqueue()
        }
    }

    /// kqueue 注册/修改事件
    /// 对应 kevent(kq, changelist, 1, NULL, 0, NULL)
    private static func kqueueControl(kq: Int64, fd: Int64, filter: Int16, flags: UInt16): Int64 {
        unsafe {
            // 分配一个 kevent 结构并设置
            let changePtr = unsafeMallocKevent()
            keventSet(changePtr, UInt64(fd), filter, flags, 0, 0, CPointer<Unit>())
            let result = kevent(Int32(kq), changePtr, 1, CPointer<Unit>(), 0, CPointer<Unit>())
            unsafeFreeKevent(changePtr)
            return Int64(result)
        }
    }

    /// kqueue 等待事件
    /// 对应 kevent(kq, NULL, 0, eventlist, nevents, timeout)
    private static func kqueueWait(kq: Int64, maxEvents: Int32, timeoutMs: Int64): Array<PollEvent> {
        unsafe {
            let events = ArrayList<PollEvent>()
            let bufferPtr = unsafeMallocKevents(Int64(maxEvents))

            // 构建 timeout
            let tsPtr = unsafeMallocTimespec()
            if (timeoutMs >= 0) {
                setTimespec(tsPtr, timeoutMs / 1000, (timeoutMs % 1000) * 1000000)
            }

            let readyCount = kevent(Int32(kq), CPointer<Unit>(), 0, bufferPtr, maxEvents,
                if (timeoutMs >= 0) { tsPtr } else { CPointer<Unit>() })

            if (readyCount > 0) {
                for (i in 0..Int64(readyCount)) {
                    let evPtr = getKeventAt(bufferPtr, i)
                    let ident = getKeventIdent(evPtr)
                    let filter = getKeventFilter(evPtr)
                    let flags = getKeventFlags(evPtr)

                    var evtFlags: UInt32 = 0
                    if (filter == KqueueEvents.EVFILT_READ) {
                        evtFlags = evtFlags | EpollEvents.EPOLLIN
                    }
                    if (filter == KqueueEvents.EVFILT_WRITE) {
                        evtFlags = evtFlags | EpollEvents.EPOLLOUT
                    }
                    if ((flags & KqueueEvents.EV_EOF) != 0) {
                        evtFlags = evtFlags | EpollEvents.EPOLLHUP
                    }
                    if ((flags & KqueueEvents.EV_ERROR) != 0) {
                        evtFlags = evtFlags | EpollEvents.EPOLLERR
                    }

                    events.append(PollEvent(Int64(ident), evtFlags))
                }
            }

            unsafeFreeTimespec(tsPtr)
            unsafeFreeKevents(bufferPtr, Int64(maxEvents))
            return events.toArray()
        }
    }

    // ========================================================================
    // 公共 API - 跨平台轮询接口
    // ========================================================================

    /// 注册文件描述符的可读/可写兴趣
    /// 对应 Bun: poll.register(fd, events)
    /// epoll: epoll_ctl(EPOLL_CTL_ADD)
    /// kqueue: kevent(EV_ADD)
    public func register(fd: Int64, events: UInt32, callback: (PollEvent) -> Unit): Int64 {
        if (!active) {
            return -1
        }

        if (platform == "epoll") {
            let result = epollControl(pollFd, EpollOp.CTL_ADD, fd, events, UInt64(fd))
            if (result < 0) {
                return result
            }
        } else if (platform == "kqueue") {
            // kqueue: 为每个关注的 filter 添加事件
            if ((events & EpollEvents.EPOLLIN) != 0) {
                kqueueControl(pollFd, fd, KqueueEvents.EVFILT_READ,
                    KqueueEvents.EV_ADD | KqueueEvents.EV_CLEAR)
            }
            if ((events & EpollEvents.EPOLLOUT) != 0) {
                kqueueControl(pollFd, fd, KqueueEvents.EVFILT_WRITE,
                    KqueueEvents.EV_ADD | KqueueEvents.EV_CLEAR)
            }
        }

        registered.put(fd, PollEntry(fd, events, callback))
        return 0
    }

    /// 修改注册事件
    /// 对应 Bun: poll.modify(fd, events)
    /// epoll: epoll_ctl(EPOLL_CTL_MOD)
    /// kqueue: EV_DELETE old + EV_ADD new
    public func modify(fd: Int64, events: UInt32): Int64 {
        if (!active) {
            return -1
        }

        if (platform == "epoll") {
            let result = epollControl(pollFd, EpollOp.CTL_MOD, fd, events, UInt64(fd))
            if (result < 0) {
                return result
            }
        } else if (platform == "kqueue") {
            // kqueue: 先删除旧的 filter，再添加新的
            let entry = registered.get(fd)
            if (let Some(e) = entry) {
                if ((e.events & EpollEvents.EPOLLIN) != 0 && (events & EpollEvents.EPOLLIN) == 0) {
                    kqueueControl(pollFd, fd, KqueueEvents.EVFILT_READ, KqueueEvents.EV_DELETE)
                }
                if ((e.events & EpollEvents.EPOLLOUT) != 0 && (events & EpollEvents.EPOLLOUT) == 0) {
                    kqueueControl(pollFd, fd, KqueueEvents.EVFILT_WRITE, KqueueEvents.EV_DELETE)
                }
            }
            if ((events & EpollEvents.EPOLLIN) != 0) {
                kqueueControl(pollFd, fd, KqueueEvents.EVFILT_READ,
                    KqueueEvents.EV_ADD | KqueueEvents.EV_CLEAR)
            }
            if ((events & EpollEvents.EPOLLOUT) != 0) {
                kqueueControl(pollFd, fd, KqueueEvents.EVFILT_WRITE,
                    KqueueEvents.EV_ADD | KqueueEvents.EV_CLEAR)
            }
        }

        let entry = registered.get(fd)
        if (let Some(e) = entry) {
            e.events = events
        }
        return 0
    }

    /// 取消注册文件描述符
    /// 对应 Bun: poll.unregister(fd)
    /// epoll: epoll_ctl(EPOLL_CTL_DEL)
    /// kqueue: EV_DELETE
    public func unregister(fd: Int64): Int64 {
        if (!active) {
            return -1
        }

        if (platform == "epoll") {
            // epoll_ctl 删除时 event 参数不能为 NULL (Linux < 2.6.9)
            epollControl(pollFd, EpollOp.CTL_DEL, fd, 0, 0)
        } else if (platform == "kqueue") {
            kqueueControl(pollFd, fd, KqueueEvents.EVFILT_READ, KqueueEvents.EV_DELETE)
            kqueueControl(pollFd, fd, KqueueEvents.EVFILT_WRITE, KqueueEvents.EV_DELETE)
        }

        registered.remove(fd)
        return 0
    }

    /// 等待事件 (阻塞)
    /// 对应 Bun: poll.poll(timeout)
    /// timeoutMs: -1 = 无限等待, 0 = 立即返回, >0 = 等待毫秒数
    /// epoll: epoll_wait(epfd, events, maxevents, timeout)
    /// kqueue: kevent(kq, NULL, 0, events, nevents, timeout)
    public func poll(timeoutMs: Int64): ArrayList<PollEvent> {
        var events = ArrayList<PollEvent>()
        if (!active) {
            return events
        }

        let maxEvents: Int32 = 64
        var rawEvents: Array<PollEvent> = Array<PollEvent>()

        if (platform == "epoll") {
            rawEvents = epollWait(pollFd, maxEvents, timeoutMs)
        } else if (platform == "kqueue") {
            rawEvents = kqueueWait(pollFd, maxEvents, timeoutMs)
        }

        // 分发回调
        for (i in 0..rawEvents.size) {
            let ev = rawEvents[i]
            events.append(ev)
            let entry = registered.get(ev.fd)
            if (let Some(e) = entry) {
                e.callback(ev)
            }
        }

        return events
    }

    /// 关闭轮询器
    public func close(): Unit {
        if (active) {
            if (pollFd >= 0) {
                unsafe {
                    Int64(close(Int32(pollFd)))
                }
            }
            registered.clear()
            active = false
            pollFd = -1
        }
    }

    /// 轮询指定 fd (一次性)
    /// 对应 Bun: pollFd(fd, events, timeout)
    /// 便捷方法: 注册 -> 等待 -> 取消注册
    public func pollFd(fd: Int64, events: UInt32, timeoutMs: Int64): ?PollEvent {
        let result = ArrayList<PollEvent>()
        // 临时注册
        let registerResult = register(fd, events, { (ev: PollEvent) => result.append(ev) })
        if (registerResult < 0) {
            return None
        }
        // 等待
        poll(timeoutMs)
        // 取消注册
        unregister(fd)
        if (result.size > 0) {
            return Some(result[0])
        }
        return None
    }

    /// 注册兴趣 (可读/可写) - 对应 Bun registerInterest
    public func registerInterest(fd: Int64, readable: Bool, writable: Bool, callback: (PollEvent) -> Unit): Int64 {
        var events: UInt32 = 0
        if (readable) { events = events | EpollEvents.EPOLLIN }
        if (writable) { events = events | EpollEvents.EPOLLOUT }
        return register(fd, events, callback)
    }

    // ========================================================================
    // C FFI 外部函数声明
    // 仓颉通过 foreign func 声明 C 函数
    // ========================================================================

    // epoll C FFI
    @Foreign
    private static func epoll_create1(flags: Int32): Int32
    @Foreign
    private static func epoll_ctl(epfd: Int32, op: Int32, fd: Int32, event: CPointer<UInt8>): Int32
    @Foreign
    private static func epoll_wait(epfd: Int32, events: CPointer<UInt8>, maxevents: Int32, timeout: Int32): Int32

    // kqueue C FFI
    @Foreign
    private static func kqueue(): Int32
    @Foreign
    private static func kevent(kq: Int32, changelist: CPointer<UInt8>, nchanges: Int32,
        eventlist: CPointer<UInt8>, nevents: Int32, timeout: CPointer<UInt8>): Int32

    // 通用 C FFI
    @Foreign
    private static func close(fd: Int32): Int32

    // epoll_event 辅助 (opaque 指针操作)
    @Foreign
    private static func unsafeMallocEpollEvent(): CPointer<UInt8>
    @Foreign
    private static func setEpollEventEvents(ptr: CPointer<UInt8>, events: UInt32): Unit
    @Foreign
    private static func setEpollEventData(ptr: CPointer<UInt8>, data: UInt64): Unit
    @Foreign
    private static func getEpollEventEvents(ptr: CPointer<UInt8>): UInt32
    @Foreign
    private static func getEpollEventData(ptr: CPointer<UInt8>): UInt64
    @Foreign
    private static func getEpollEventAt(buffer: CPointer<UInt8>, index: Int64): CPointer<UInt8>
    @Foreign
    private static func unsafeMallocEpollEvents(count: Int64): CPointer<UInt8>
    @Foreign
    private static func unsafeFreeEpollEvent(ptr: CPointer<UInt8>): Unit
    @Foreign
    private static func unsafeFreeEpollEvents(ptr: CPointer<UInt8>, count: Int64): Unit

    // kevent 辅助
    @Foreign
    private static func unsafeMallocKevent(): CPointer<UInt8>
    @Foreign
    private static func unsafeMallocKevents(count: Int64): CPointer<UInt8>
    @Foreign
    private static func unsafeFreeKevent(ptr: CPointer<UInt8>): Unit
    @Foreign
    private static func unsafeFreeKevents(ptr: CPointer<UInt8>, count: Int64): Unit
    @Foreign
    private static func keventSet(ptr: CPointer<UInt8>, ident: UInt64, filter: Int16,
        flags: UInt16, fflags: UInt32, data: Int64, udata: CPointer<Unit>): Unit
    @Foreign
    private static func getKeventIdent(ptr: CPointer<UInt8>): UInt64
    @Foreign
    private static func getKeventFilter(ptr: CPointer<UInt8>): Int16
    @Foreign
    private static func getKeventFlags(ptr: CPointer<UInt8>): UInt16
    @Foreign
    private static func getKeventAt(buffer: CPointer<UInt8>, index: Int64): CPointer<UInt8>

    // timespec 辅助
    @Foreign
    private static func unsafeMallocTimespec(): CPointer<UInt8>
    @Foreign
    private static func setTimespec(ptr: CPointer<UInt8>, sec: Int64, nsec: Int64): Unit
    @Foreign
    private static func unsafeFreeTimespec(ptr: CPointer<UInt8>): Unit
}

/// 轮询条目 - 内部使用
class PollEntry {
    var fd: Int64
    var events: UInt32
    var callback: (PollEvent) -> Unit

    init(fd: Int64, events: UInt32, callback: (PollEvent) -> Unit) {
        this.fd = fd
        this.events = events
        this.callback = callback
    }
}

// ============================================================================
// ConcurrentTaskQueue - 跨线程任务提交队列
// 严格翻译自: src/event_loop/ConcurrentTask.rs
//   Bun 使用 ConcurrentTaskQueue 安全地从工作线程提交任务到事件循环
//
// ConcurrentTask.rs 核心结构:
//   pub struct ConcurrentTask {
//       pub task: Task,               // tag + ptr
//       pub next: Link<ConcurrentTask>, // intrusive MPSC link (AtomicPtr)
//       pub auto_delete: bool,         // auto-free after dispatch
//   }
//   pub type Queue = UnboundedQueue<ConcurrentTask>;
//
//   pub unsafe impl Linked for ConcurrentTask {
//       unsafe fn link(item: *mut Self) -> *const Link<Self> {
//           unsafe { core::ptr::addr_of!((*item).next) }
//       }
//   }
//
// MPSC 语义:
//   push: 原子 store next (release), 不需要 RMW
//   popBatch: 从 head 取一批任务
//   drain: 在事件循环线程中执行所有任务
// ============================================================================

/// 跨线程任务提交队列 - 对应 Bun ConcurrentTaskQueue
/// 线程安全的 MPSC 队列，工作线程提交，事件循环消费
public class ConcurrentTaskQueue {
    /// 无界 MPSC 任务队列
    /// Bun: UnboundedQueue<ConcurrentTask> (lock-free, intrusive linked list)
    private var queue: ConcurrentLinkedQueue<ConcurrentTask>
    /// 事件循环引用 (用于唤醒)
    private var eventLoop: ?MiniEventLoop
    /// 事件 FD (用于唤醒事件循环, Linux eventfd)
    private var eventFd: Int64

    public init() {
        queue = ConcurrentLinkedQueue<ConcurrentTask>()
        eventLoop = None
        eventFd = -1
    }

    /// 绑定事件循环
    public func attach(loop: MiniEventLoop): Unit {
        eventLoop = loop
    }

    /// 设置唤醒 FD (Linux eventfd 或 pipe)
    /// Bun: loop.wakeup() 通过 eventfd 写入通知事件循环
    public func setEventFd(fd: Int64): Unit {
        eventFd = fd
    }

    /// 从工作线程提交任务 (MPSC push)
    /// 对应 Bun:
    ///   pub fn enqueueTaskConcurrent(this, task) void {
    ///       this.concurrent_tasks.push(task)
    ///       this.loop.wakeup()
    ///   }
    /// push 是原子 store next (release store), 无 RMW
    public func push(task: ConcurrentTask): Unit {
        queue.put(task)
        // 通知事件循环有新任务
        wakeupLoop()
    }

    /// 批量推送任务
    public func pushBatch(tasks: Array<ConcurrentTask>): Unit {
        for (i in 0..tasks.size) {
            queue.put(tasks[i])
        }
        wakeupLoop()
    }

    /// 从事件循环线程取出所有任务 (drain)
    /// 对应 Bun: tickConcurrentWithCount
    ///   pub fn tickConcurrentWithCount(this) usize {
    ///       var concurrent = this.concurrent_tasks.popBatch()
    ///       const count = concurrent.count
    ///       // ... move to local queue
    ///   }
    public func drain(): ArrayList<ConcurrentTask> {
        var tasks = ArrayList<ConcurrentTask>()
        while (true) {
            let task = queue.remove()
            if (task == None) { break }
            tasks.append(task.unwrap())
        }
        return tasks
    }

    /// 取出一批任务 (最多 maxCount 个)
    /// 对应 Bun: popBatch
    public func drainBatch(maxCount: Int64): ArrayList<ConcurrentTask> {
        var tasks = ArrayList<ConcurrentTask>()
        var count: Int64 = 0
        while (count < maxCount) {
            let task = queue.remove()
            if (task == None) { break }
            tasks.append(task.unwrap())
            count += 1
        }
        return tasks
    }

    /// 是否有待处理任务
    public func hasPending(): Bool {
        !queue.isEmpty()
    }

    /// 唤醒事件循环
    /// 对应 Bun: loop.wakeup()
    /// 通过 eventfd 写入通知事件循环从 poll 中返回
    private func wakeupLoop(): Unit {
        if (eventFd >= 0) {
            unsafe {
                // eventfd_write(eventFd, 1)
                let buf: UInt64 = 1
                write(Int32(eventFd), CPointer<UInt8>(), 8)
            }
        }
        match (eventLoop) {
            case Some(loop) =>
                loop.enqueue({ })
            case None => ()
        }
    }

    @Foreign
    private static func write(fd: Int32, buf: CPointer<UInt8>, count: Int64): Int64
}

// ============================================================================
// FilePollStore - 文件变化监视存储
// 严格翻译自: src/event_loop/ + src/watcher/
//   Bun 使用 FilePollStore 管理文件监视器
//   对应 MiniEventLoop.filePolls() 和 Async.FilePoll.Store
// ============================================================================

/// 文件变化监视存储 - 对应 Bun FilePollStore
/// 管理多个文件监视器，将事件分发到事件循环
public class FilePollStore {
    /// 文件监视器映射 (路径 -> 回调)
    private var watchers: HashMap<String, (FileWatchEvent) -> Unit>
    /// 底层 inotify 监视器
    private var fileWatcher: ?FileWatcher
    /// 关联的轮询器
    private var poller: ?Poller

    public init() {
        watchers = HashMap<String, (FileWatchEvent) -> Unit>()
        fileWatcher = None
        poller = None
    }

    /// 添加文件监视
    /// 对应 Bun: FilePollStore.watch(path, callback)
    public func watch(path: String, callback: (FileWatchEvent) -> Unit): Int64 {
        watchers.put(path, callback)
        match (fileWatcher) {
            case Some(fw) =>
                return fw.watch(path)
            case None =>
                let result = FileWatcher.create()
                match (result) {
                    case Ok(fw) =>
                        fileWatcher = fw
                        fw.watch(path)
                        match (poller) {
                            case Some(p) =>
                                p.register(fw.fd(), EpollEvents.EPOLLIN,
                                    { (ev: PollEvent) => handleEvents() })
                            case None => ()
                        }
                        return 0
                    case Err(e) => return -1
                }
        }
    }

    /// 取消文件监视
    public func unwatch(path: String): Unit {
        watchers.remove(path)
        match (fileWatcher) {
            case Some(fw) => fw.unwatch(path)
            case None => ()
        }
    }

    /// 处理事件 (内部)
    private func handleEvents(): Unit {
        match (fileWatcher) {
            case Some(fw) =>
                let events = fw.readEvents()
                for (event in events) {
                    let callback = watchers.get(event.fileName)
                    if (let Some(cb) = callback) {
                        cb(event)
                    }
                    // 也尝试匹配目录前缀
                    for (path in watchers.keys()) {
                        if (event.fileName.startsWith(path)) {
                            let cb = watchers.get(path)
                            if (let Some(c) = cb) {
                                c(event)
                            }
                        }
                    }
                }
            case None => ()
        }
    }

    /// 关闭所有监视
    public func close(): Unit {
        match (fileWatcher) {
            case Some(fw) => fw.close()
            case None => ()
        }
        watchers.clear()
    }

    /// 设置轮询器
    public func setPoller(poller: Poller): Unit {
        this.poller = poller
    }
}
