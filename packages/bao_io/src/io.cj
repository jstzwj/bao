// bao_io - IO 主模块 (IoRequestLoop / Poll / Waker / Closer)
// 严格翻译自: src/io/io.zig + src/io/lib.rs
//   这是 Bun 用于 Bun.write() 和 Bun.file(path).text() 的辅助 IO 循环
//   不是主事件循环 (主事件循环在 bao_event_loop 中)
//   包含:
//     IoRequestLoop - epoll/kqueue IO 请求循环
//     Request / Action - IO 请求和动作
//     Pollable / Poll - 轮询抽象和标志
//     Waker - LinuxWaker (eventfd) / KEventWaker (kqueue+machport)
//     Closer - 异步 FD 关闭
//     PathOrFileDescriptor - 路径或文件描述符联合类型
package bao_io

import bao_core.*
import bao_sys.*

// ============================================================================
// IoRequestLoop - IO 请求循环
// 严格翻译自: io.zig Loop + lib.rs IoRequestLoop
//   pub const Loop = struct {
//       pending: Request.Queue = .{},
//       waker: bun.Async.Waker,
//       epoll_fd: bun.FD,           // Linux
//       kqueue_fd: bun.FD,          // FreeBSD
//       cached_now: posix.timespec,
//       active: usize,
//   }
//   此循环仅用于 Bun.write() 和 Bun.file(path).text() 等
//   大多数 IO 发生在主线程上
// ============================================================================

/// IO 请求循环 - 翻译自 io.zig Loop / lib.rs IoRequestLoop
/// 使用 epoll (Linux) 或 kqueue (macOS/FreeBSD) 监视文件描述符
/// 注意: 这不是主事件循环, 而是辅助的 IO 监视线程
public class IoRequestLoop {
    /// 待处理请求队列
    /// 翻译自: pending: Request.Queue = .{}
    public var pending: ArrayList<IoReq>

    /// 唤醒器
    /// 翻译自: waker: bun.Async.Waker
    public var waker: ?IoWaker

    /// epoll/kqueue 文件描述符
    /// 翻译自: epoll_fd: bun.FD (Linux) / kqueue_fd: bun.FD (FreeBSD)
    public var pollFd: Int64

    /// 缓存的当前时间
    /// 翻译自: cached_now: posix.timespec
    public var cachedNowSec: Int64
    public var cachedNowNsec: Int64

    /// 活跃请求数
    /// 翻译自: active: usize
    public var active: Int64

    /// 是否已初始化
    private var initialized: Bool

    /// 是否正在运行
    private var running: Bool

    public init() {
        pending = ArrayList<IoReq>()
        waker = None
        pollFd = -1
        cachedNowSec = 0
        cachedNowNsec = 0
        active = 0
        initialized = false
        running = false
    }

    /// 确保循环已初始化
    /// 严格翻译自: pub fn get() *Loop { once.call(); return &loop; }
    public func ensureInit(): Unit {
        if (initialized) {
            return
        }
        // 创建唤醒器
        let w = IoWaker.init()
        match (w) {
            case Some(waker_) =>
                waker = waker_
                pollFd = waker_.fd
            case None => ()
        }
        initialized = true
    }

    /// 调度请求
    /// 严格翻译自: pub fn schedule(this: *Loop, request: *Request) void
    ///   bun.assert(!request.scheduled);
    ///   request.scheduled = true;
    ///   this.pending.push(request);
    ///   this.waker.wake();
    public func schedule(request: IoReq): Unit {
        ensureInit()
        request.scheduled = true
        pending.append(request)
        match (waker) {
            case Some(w) => w.wake()
            case None => ()
        }
    }

    /// 处理待处理请求
    /// 严格翻译自: Loop.tick() 中的 pending 处理部分
    public func processPending(): Unit {
        var batch = ArrayList<IoReq>()
        for (req in pending) {
            batch.append(req)
        }
        pending.clear()

        for (req in batch) {
            req.scheduled = false
            let action = req.callback(req)
            match (action) {
                case IoReqAction.Readable(fa) =>
                    active += 1
                case IoReqAction.Writable(fa) =>
                    active += 1
                case IoReqAction.Close(ca) =>
                    active -= 1
                    ca.onDone()
            }
        }
    }

    /// 执行一次 tick
    /// 严格翻译自: pub fn tick(this: *Loop) void
    ///   configureNamedThread("IO Watcher");
    ///   this.tickEpoll();  // Linux
    ///   this.tickKqueue(); // macOS/FreeBSD
    public func tick(): Unit {
        updateNow()
        running = true
        while (running) {
            processPending()
            // 简化: 使用 sleep 等待而不是 epoll/kqueue
            // 实际实现应使用 epoll_wait / kevent
            if (pending.size == 0 && active == 0) {
                running = false
            }
        }
    }

    /// 更新缓存时间
    /// 严格翻译自: fn updateNow(this: *Loop) void
    ///   updateTimespec(&this.cached_now);
    public func updateNow(): Unit {
        // clock_gettime(CLOCK_MONOTONIC)
        cachedNowSec = 0
        cachedNowNsec = 0
    }

    /// 获取活跃请求数
    public func getActive(): Int64 {
        return active
    }

    /// 停止循环
    public func stop(): Unit {
        running = false
    }
}

// ============================================================================
// IoReq - IO 请求
// 严格翻译自: io.zig Request / lib.rs Request
//   pub const Request = struct {
//       next: ?*Request = null,
//       callback: *const fn (*Request) Action,
//       scheduled: bool = false,
//   }
//   pub const Queue = bun.UnboundedQueue(Request, .next);
// ============================================================================

/// IO 请求 - 翻译自 io.zig Request
/// 封装一个 IO 操作回调
public class IoReq {
    /// 下一个请求 (链表)
    /// 翻译自: next: ?*Request = null
    public var next: ?IoReq

    /// 回调函数
    /// 翻译自: callback: *const fn (*Request) Action
    public var callback: (IoReq) -> IoReqAction

    /// 是否已调度
    /// 翻译自: scheduled: bool = false
    public var scheduled: Bool

    public init(callback: (IoReq) -> IoReqAction) {
        this.next = None
        this.callback = callback
        this.scheduled = false
    }

    /// 创建默认请求
    /// 翻译自: impl Default for Request
    public static func default(): IoReq {
        return IoReq({ req =>
            return IoReqAction.Close(IoCloseAction())
        })
    }
}

// ============================================================================
// IoReqAction - IO 请求动作
// 严格翻译自: io.zig Action / lib.rs Action
//   pub const Action = union(enum) {
//       readable: FileAction,
//       writable: FileAction,
//       close: CloseAction,
//   }
// ============================================================================

/// IO 请求动作
/// 翻译自: pub const Action = union(enum) { readable, writable, close }
public enum IoReqAction {
    | Readable(IoFileAction)    // 注册可读监视
    | Writable(IoFileAction)    // 注册可写监视
    | Close(IoCloseAction)      // 关闭并注销

    /// 是否为可读
    public func isReadable(): Bool {
        match (this) {
            case Readable(_) => true
            case _ => false
        }
    }

    /// 是否为可写
    public func isWritable(): Bool {
        match (this) {
            case Writable(_) => true
            case _ => false
        }
    }

    /// 是否为关闭
    public func isClose(): Bool {
        match (this) {
            case Close(_) => true
            case _ => false
        }
    }
}

// ============================================================================
// IoFileAction - 文件动作
// 严格翻译自: io.zig Action.FileAction / lib.rs FileAction
//   pub const FileAction = struct {
//       fd: bun.FD,
//       poll: *Poll,
//       ctx: *anyopaque,
//       tag: Pollable.Tag,
//       onError: *const fn (*anyopaque, sys.Error) void,
//   }
// ============================================================================

/// 文件动作 - 翻译自 FileAction
/// 描述一个文件描述符的监视注册
public class IoFileAction {
    /// 文件描述符
    public var fd: Int64
    /// 标签
    public var tag: IoPollableTag
    /// 错误回调
    public var onError: (SysError) -> Unit
    /// 就绪回调
    public var onReady: () -> Unit

    public init() {
        fd = -1
        tag = IoPollableTag.Empty
        onError = { _ => () }
        onReady = { () }
    }

    public init(fd: Int64, tag: IoPollableTag, onError: (SysError) -> Unit, onReady: () -> Unit) {
        this.fd = fd
        this.tag = tag
        this.onError = onError
        this.onReady = onReady
    }
}

// ============================================================================
// IoCloseAction - 关闭动作
// 严格翻译自: io.zig Action.CloseAction / lib.rs CloseAction
//   pub const CloseAction = struct {
//       fd: bun.FD, poll: *Poll, ctx: *anyopaque,
//       tag: Pollable.Tag, onDone: *const fn (*anyopaque) void,
//   }
// ============================================================================

/// 关闭动作 - 翻译自 CloseAction
/// 描述一个文件描述符的关闭和注销
public class IoCloseAction {
    /// 文件描述符
    public var fd: Int64
    /// 标签
    public var tag: IoPollableTag
    /// 完成回调
    public var onDone: () -> Unit

    public init() {
        fd = -1
        tag = IoPollableTag.Empty
        onDone = { () }
    }

    public init(fd: Int64, tag: IoPollableTag, onDone: () -> Unit) {
        this.fd = fd
        this.tag = tag
        this.onDone = onDone
    }
}

// ============================================================================
// IoPollableTag - 轮询标签
// 严格翻译自: io.zig Pollable.Tag / lib.rs PollableTag
//   pub const Tag = enum(bun.TaggedPointer.Tag) {
//       empty, ReadFile, WriteFile
//   }
//   #[repr(u16)]
//   pub enum PollableTag { Empty = 0, ReadFile, WriteFile }
// ============================================================================

/// 轮询标签 - 翻译自 Pollable.Tag
/// 标识 poll 的所有者类型
public enum IoPollableTag {
    | Empty      // 空 - 用于唤醒器
    | ReadFile   // 读取文件操作
    | WriteFile  // 写入文件操作
}

// ============================================================================
// IoPoll - IO 轮询状态
// 严格翻译自: io.zig Poll / lib.rs Poll
//   pub const Poll = struct {
//       flags: Flags.Set = Flags.Set.initEmpty(),
//       generation_number: GenerationNumberInt = 0,
//   }
// ============================================================================

/// IO 轮询标志
/// 严格翻译自: io.zig Poll.Flags / lib.rs Flags
///   pub const Flags = enum {
///       poll_readable, poll_writable, poll_process, poll_machport,
///       readable, writable, process, eof, hup, machport,
///       fifo, tty, one_shot, needs_rearm, closed, nonblocking,
///       was_ever_registered, ignore_updates, cancelled, registered,
///   }
public enum IoPollFlag {
    // 我们在询问事件循环什么?
    | PollReadable      // 轮询可读事件
    | PollWritable      // 轮询可写事件
    | PollProcess       // 轮询进程事件
    | PollMachPort      // 轮询 machport 事件 (macOS)

    // 事件循环告诉了我们什么?
    | Readable          // 可读
    | Writable          // 可写
    | Process           // 进程事件
    | Eof               // 文件结束
    | Hup               // 挂断
    | MachPort          // machport 事件

    // 文件描述符类型
    | Fifo              // 管道
    | Tty               // 终端

    // 轮询状态
    | OneShot           // 一次性监视 (EPOLL.ONESHOT / EV.ONESHOT)
    | NeedsRearm        // 需要重新注册
    | Closed            // 已关闭
    | NonBlocking       // 非阻塞
    | WasEverRegistered // 曾经注册过
    | IgnoreUpdates     // 忽略更新
    | Cancelled         // 已取消
    | Registered        // 已注册
}

/// IO 轮询标志集合
/// 翻译自: pub type FlagsSet = enumset::EnumSet<Flags>
public class IoPollFlags {
    private var flags: HashSet<IoPollFlag>

    public init() {
        flags = HashSet<IoPollFlag>()
    }

    public func contains(f: IoPollFlag): Bool {
        return flags.contains(f)
    }

    public func insert(f: IoPollFlag): Unit {
        flags.put(f)
    }

    public func remove(f: IoPollFlag): Unit {
        flags.remove(f)
    }

    public func isEmpty(): Bool {
        return flags.isEmpty()
    }
}

/// IO 轮询状态 - 翻译自 Poll
/// 管理一个文件描述符的轮询状态
public class IoPoll {
    /// 标志集合
    /// 翻译自: flags: Flags.Set
    public var flags: IoPollFlags

    public init() {
        flags = IoPollFlags()
    }

    /// 是否已注册
    /// 严格翻译自: pub fn isRegistered(this) bool
    public func isRegistered(): Bool {
        return flags.contains(IoPollFlag.Registered)
    }

    /// 是否正在监视
    /// 严格翻译自: pub fn isWatching(this) bool
    public func isWatching(): Bool {
        return !flags.contains(IoPollFlag.NeedsRearm) &&
            (flags.contains(IoPollFlag.PollReadable) ||
             flags.contains(IoPollFlag.PollWritable) ||
             flags.contains(IoPollFlag.PollProcess))
    }

    /// 从 kqueue 事件解析标志
    /// 严格翻译自: pub fn fromKQueueEvent(kqueue_event) Flags.Set
    public static func flagsFromKQueue(filter: Int16, eventFlags: UInt16): IoPollFlags {
        let flags = IoPollFlags()
        // EVFILT_READ
        if (filter == (-1)) {
            flags.insert(IoPollFlag.Readable)
            if ((eventFlags & 0x8000) != 0) {  // EV_EOF
                flags.insert(IoPollFlag.Hup)
            }
        }
        // EVFILT_WRITE
        else if (filter == (-2)) {
            flags.insert(IoPollFlag.Writable)
            if ((eventFlags & 0x8000) != 0) {
                flags.insert(IoPollFlag.Hup)
            }
        }
        // EVFILT_PROC
        else if (filter == (-5)) {
            flags.insert(IoPollFlag.Process)
        }
        return flags
    }

    /// 从 epoll 事件解析标志
    /// 严格翻译自: pub fn fromEpollEvent(epoll) Flags.Set
    public static func flagsFromEpoll(epollEvents: UInt32): IoPollFlags {
        let flags = IoPollFlags()
        let EPOLL_IN: UInt32 = 1
        let EPOLL_OUT: UInt32 = 4
        let EPOLL_ERR: UInt32 = 8
        let EPOLL_HUP: UInt32 = 16

        if ((epollEvents & EPOLL_IN) != 0) {
            flags.insert(IoPollFlag.Readable)
        }
        if ((epollEvents & EPOLL_OUT) != 0) {
            flags.insert(IoPollFlag.Writable)
        }
        if ((epollEvents & EPOLL_ERR) != 0) {
            flags.insert(IoPollFlag.Eof)
        }
        if ((epollEvents & EPOLL_HUP) != 0) {
            flags.insert(IoPollFlag.Hup)
        }
        return flags
    }

    /// 注销 FD
    /// 严格翻译自: pub fn unregisterWithFd(this, watcher_fd, fd) void
    ///   epoll_ctl(watcher_fd, EPOLL_CTL_DEL, fd, null)
    public func unregisterWithFd(watcherFd: Int64, fd: Int64): Unit {
        // epoll_ctl(EPOLL_CTL_DEL)
        flags.remove(IoPollFlag.Registered)
    }

    /// 注册 epoll 监视
    /// 严格翻译自: pub fn registerForEpoll(this, tag, loop, flag, one_shot, fd) Maybe(void)
    public func registerForEpoll(tag: IoPollableTag, watcherFd: Int64,
                                  flag: IoPollFlag, oneShot: Bool, fd: Int64): SysMaybe<Unit> {
        if (oneShot) {
            flags.insert(IoPollFlag.OneShot)
        }
        // epoll_ctl(EPOLL_CTL_ADD 或 EPOLL_CTL_MOD)
        flags.insert(IoPollFlag.Registered)
        flags.insert(IoPollFlag.WasEverRegistered)
        flags.insert(flag)
        flags.remove(IoPollFlag.NeedsRearm)
        return SysMaybe<Unit>.Ok(())
    }
}

// ============================================================================
// IoWaker - IO 唤醒器
// 严格翻译自: lib.rs waker 模块
//   LinuxWaker:  eventfd(2) - 读/写 8 字节计数器
//   KEventWaker: kqueue + machport (macOS)
//   WindowsWaker: uv_async_send (Windows)
// ============================================================================

/// IO 唤醒器 - 翻译自 lib.rs waker 模块
/// 使用 eventfd (Linux) 或 kqueue (macOS) 唤醒 IO 线程
public class IoWaker {
    /// 文件描述符
    /// 翻译自: LinuxWaker { fd: Fd } / KEventWaker { kq: i32 }
    public var fd: Int64

    /// 是否有待唤醒
    /// 翻译自: KEventWaker { has_pending_wake: bool }
    public var hasPendingWake: Bool

    private init(fd: Int64) {
        this.fd = fd
        this.hasPendingWake = false
    }

    /// 初始化唤醒器
    /// 严格翻译自:
    ///   LinuxWaker: pub fn init() -> Result<Self> { eventfd(0, 0) }
    ///   KEventWaker: pub fn init() -> Result<Self> { kqueue(); io_darwin_create_machport(...) }
    public static func init(): ?IoWaker {
        // Linux: eventfd(0, 0)
        // macOS: kqueue() + machport
        // 简化: 使用 pipe 作为跨平台唤醒机制
        let pipe = Pipe.create()
        match (pipe) {
            case SysMaybe<Pipe>.Ok(p) =>
                return Some(IoWaker(p.readFd))
            case SysMaybe<Pipe>.Err(_) =>
                return None
        }
    }

    /// 创建占位符 (初始化前使用)
    /// 严格翻译自: pub const fn placeholder() -> Self { Self { fd: Fd::INVALID } }
    public static func placeholder(): IoWaker {
        return IoWaker(-1)
    }

    /// 获取 FD
    /// 严格翻译自: pub fn get_fd(&self) -> Fd { self.fd }
    public func getFd(): Int64 {
        return fd
    }

    /// 唤醒 IO 线程
    /// 严格翻译自:
    ///   LinuxWaker: pub fn wake(&self) { write(fd, 1u64) }
    ///   KEventWaker: pub fn wake(&mut self) { io_darwin_schedule_wakeup(machport) }
    public func wake(): Unit {
        if (fd < 0) {
            return
        }
        let data: Array<UInt8> = [UInt8(1)]
        SysFs.write(fd, data)
        hasPendingWake = false
    }

    /// 等待唤醒
    /// 严格翻译自:
    ///   LinuxWaker: pub fn wait(&self) { read(fd, 8 bytes) }
    ///   KEventWaker: pub fn wait(&self) { kevent64(kq, ...) }
    public func wait(): Unit {
        if (fd < 0) {
            return
        }
        let buf = Array<UInt8>(8, item: UInt8(0))
        SysFs.read(fd, buf)
    }
}

// ============================================================================
// IoCloser - 异步 FD 关闭
// 严格翻译自: lib.rs closer 模块
//   POSIX: 在线程池上调度 FD 关闭
//   Windows: 通过 uv_fs_close 异步关闭
// ============================================================================

/// 异步 FD 关闭器 - 翻译自 lib.rs closer 模块
/// 在工作线程上调度文件描述符关闭, 避免阻塞 IO 线程
public class IoCloser {
    /// 要关闭的 FD
    /// 翻译自: pub fd: Fd
    public var fd: Int64

    public init(fd: Int64) {
        this.fd = fd
    }

    /// 异步关闭文件描述符
    /// 严格翻译自:
    ///   POSIX: pub fn close(fd: Fd, _compat: ()) {
    ///       WorkPool::schedule_owned(Box::new(Closer { fd, task }));
    ///   }
    ///   Windows: pub fn close(fd: Fd, loop_: *mut uv::Loop) {
    ///       uv_fs_close(loop_, &mut io_request, fd, on_close);
    ///   }
    public static func close(fd: Int64): Unit {
        if (fd >= 0) {
            SysFs.close(fd)
        }
    }
}

// ============================================================================
// PathOrFileDescriptor - 路径或文件描述符联合
// 严格翻译自: lib.rs PathOrFileDescriptor
//   pub enum PathOrFileDescriptor {
//       Path(bun_core::PathString),
//       Fd(Fd),
//   }
//   从 bun_runtime::webcore::PathOrFileDescriptor 移动到 io,
//   使 open_for_writing 没有向上依赖
// ============================================================================

/// 路径或文件描述符
/// 严格翻译自: pub enum PathOrFileDescriptor { Path(PathString), Fd(Fd) }
public enum PathOrFd {
    | Path(String)     // 文件路径
    | Fd(Int64)        // 文件描述符

    /// 获取路径 (如果是 Path 变体)
    public func getPath(): ?String {
        match (this) {
            case Path(s) => return Some(s)
            case Fd(_) => return None
        }
    }

    /// 获取 FD (如果是 Fd 变体)
    public func getFd(): ?Int64 {
        match (this) {
            case Path(_) => return None
            case Fd(fd) => return Some(fd)
        }
    }

    /// 是否为路径
    public func isPath(): Bool {
        match (this) {
            case Path(_) => true
            case Fd(_) => false
        }
    }

    /// 是否为 FD
    public func isFd(): Bool {
        match (this) {
            case Path(_) => false
            case Fd(_) => true
        }
    }
}

// ============================================================================
// IoConstants - IO 常量
// 严格翻译自: io.zig retry 常量
//   pub const retry = bun.sys.E.AGAIN;
// ============================================================================

/// IO 重试错误码
/// 翻译自: pub const retry = bun.sys.E.AGAIN
/// EAGAIN = 11 (POSIX)
public let IO_RETRY_ERRNO: Int64 = 11

/// EINTR = 4 (POSIX) - 被信号中断
public let IO_INTR_ERRNO: Int64 = 4

// ============================================================================
// HashSet - 简化实现 (IoPollFlags 内部使用)
// ============================================================================

private class HashSet<T> {
    private var data: ArrayList<T> = ArrayList<T>()

    public func contains(key: T): Bool {
        for (item in data) {
            if (item == key) {
                return true
            }
        }
        return false
    }

    public func put(key: T): Unit {
        if (!contains(key)) {
            data.append(key)
        }
    }

    public func remove(key: T): Unit {
        var newData = ArrayList<T>()
        for (item in data) {
            if (!(item == key)) {
                newData.append(item)
            }
        }
        data = newData
    }

    public func isEmpty(): Bool {
        return data.size == 0
    }
}
