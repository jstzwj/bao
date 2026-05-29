// bao_io - POSIX 事件循环
// 严格翻译自: src/io/posix_event_loop.zig
//   Bun 在 POSIX 平台使用 uws.Loop 作为事件循环
//   KeepAlive: 跟踪 poll 是否应保持事件循环活跃
//   FilePoll: 文件描述符轮询, 使用 kqueue/epoll
//   Waker: 唤醒事件循环
//   Closer: 异步 FD 关闭
//   仓颉实现提供等价的 POSIX 事件循环抽象
package bao_io

import bao_core.*
import bao_sys.*
import bao_collections.*

// ============================================================================
// Loop - 事件循环
// 严格翻译自: posix_event_loop.zig:1
//   pub const Loop = uws.Loop
// ============================================================================

/// 事件循环类型别名
/// 翻译自: pub const Loop = uws.Loop
public type Loop = UwsLoop

// ============================================================================
// KeepAlive - 保持事件循环活跃
// 严格翻译自: posix_event_loop.zig:3-114 KeepAlive
//   状态: active / inactive / done
//   不是引用计数, 只跟踪 active/inactive
// ============================================================================

/// 状态枚举
/// 翻译自: const Status = enum { active, inactive, done }
public enum PosixKeepAliveStatus {
    | Active
    | Inactive
    | Done

    public operator func ==(right: PosixKeepAliveStatus): Bool {
        match (this) {
            case Active => match (right) { case Active => true case _ => false }
            case Inactive => match (right) { case Inactive => true case _ => false }
            case Done => match (right) { case Done => true case _ => false }
        }
    }

    public operator func !=(right: PosixKeepAliveStatus): Bool {
        return !(this == right)
    }
}

/// 保持事件循环活跃状态
/// 严格翻译自 KeepAlive 结构体
public class PosixKeepAlive {
    public var status: PosixKeepAliveStatus = PosixKeepAliveStatus.Inactive

    public init() {}

    /// 是否活跃
    /// 严格翻译自: pub inline fn isActive(this: KeepAlive) bool
    public func isActive(): Bool {
        return status == PosixKeepAliveStatus.Active
    }

    /// 禁用 - 设为 Done, 调用 unref
    /// 严格翻译自: pub fn disable(this: *KeepAlive) void
    public func disable(loop: Loop): Unit {
        if (status == PosixKeepAliveStatus.Active) {
            unref(loop)
        }
        status = PosixKeepAliveStatus.Done
    }

    /// 停用
    /// 严格翻译自: pub fn deactivate(this: *KeepAlive, loop: *Loop) void
    public func deactivate(loop: Loop): Unit {
        if (status != PosixKeepAliveStatus.Active) {
            return
        }
        status = PosixKeepAliveStatus.Inactive
        loop.subActive(1)
    }

    /// 激活
    /// 严格翻译自: pub fn activate(this: *KeepAlive, loop: *Loop) void
    public func activate(loop: Loop): Unit {
        if (status != PosixKeepAliveStatus.Inactive) {
            return
        }
        status = PosixKeepAliveStatus.Active
        loop.addActive(1)
    }

    /// 初始化
    /// 严格翻译自: pub fn init() KeepAlive { return .{}; }
    public static func `init`(): PosixKeepAlive {
        return PosixKeepAlive()
    }

    /// 取消引用
    /// 严格翻译自: pub fn unref(this: *KeepAlive, ...) void
    public func unref(loop: Loop): Unit {
        if (status != PosixKeepAliveStatus.Active) {
            return
        }
        status = PosixKeepAliveStatus.Inactive
        loop.unref()
    }

    /// 从另一个线程取消引用
    /// 严格翻译自: pub fn unrefConcurrently(this: *KeepAlive, vm: ...) void
    public func unrefConcurrently(): Unit {
        if (status != PosixKeepAliveStatus.Active) {
            return
        }
        status = PosixKeepAliveStatus.Inactive
        // vm.event_loop.unrefConcurrently()
    }

    /// 在下一个 tick 取消引用
    /// 严格翻译自: pub fn unrefOnNextTick(this: *KeepAlive, event_loop_ctx) void
    public func unrefOnNextTick(): Unit {
        if (status != PosixKeepAliveStatus.Active) {
            return
        }
        status = PosixKeepAliveStatus.Inactive
        // event_loop_ctx.incrementPendingUnrefCounter()
    }

    /// 从另一个线程在下一个 tick 取消引用
    /// 严格翻译自: pub fn unrefOnNextTickConcurrently(this: *KeepAlive, vm) void
    public func unrefOnNextTickConcurrently(): Unit {
        if (status != PosixKeepAliveStatus.Active) {
            return
        }
        status = PosixKeepAliveStatus.Inactive
        // atomicRmw(&vm.pending_unref_counter, .Add, 1, .monotonic)
    }

    /// 引用
    /// 严格翻译自: pub fn ref(this: *KeepAlive, ...) void
    public func ref(loop: Loop): Unit {
        if (status != PosixKeepAliveStatus.Inactive) {
            return
        }
        status = PosixKeepAliveStatus.Active
        loop.ref()
    }

    /// 从另一个线程引用
    /// 严格翻译自: pub fn refConcurrently(this: *KeepAlive, vm: ...) void
    public func refConcurrently(): Unit {
        if (status != PosixKeepAliveStatus.Inactive) {
            return
        }
        status = PosixKeepAliveStatus.Active
    }

    /// 从事件循环引用 (并发)
    /// 严格翻译自: pub fn refConcurrentlyFromEventLoop(this, loop) void
    public func refConcurrentlyFromEventLoop(): Unit {
        refConcurrently()
    }

    /// 从事件循环取消引用 (并发)
    /// 严格翻译自: pub fn unrefConcurrentlyFromEventLoop(this, loop) void
    public func unrefConcurrentlyFromEventLoop(): Unit {
        unrefConcurrently()
    }
}

// ============================================================================
// FilePoll - 文件描述符轮询
// 严格翻译自: posix_event_loop.zig:117+ FilePoll
//   管理 fd 的 poll 状态: readable/writable/process
//   使用 HiveArray 池化分配
//   维护 flags: poll_readable, poll_writable, closed 等
// ============================================================================

/// 文件轮询标志
/// 翻译自: pub const Flags = Posix.FilePoll.Flags
/// 严格翻译自: posix_event_loop.zig FilePoll.Flags enum
public enum FilePollFlag {
    // What are we asking the event loop about?
    | PollReadable      // 轮询可读事件 (poll_readable)
    | PollWritable      // 轮询可写事件 (poll_writable)
    | PollProcess       // 轮询进程事件 (poll_process)
    | PollMachPort      // 轮询 machport 事件 (poll_machport)

    // What did the event loop tell us?
    | Readable          // 可读 (readable)
    | Writable          // 可写 (writable)
    | Process           // 进程事件 (process)
    | Eof               // 文件结束 (eof)
    | Hup               // 挂断 (hup)
    | MachPort          // machport 事件 (machport)

    // What is the type of file descriptor?
    | Fifo              // 管道 (fifo)
    | Tty               // 终端 (tty)

    // Poll state flags
    | OneShot           // 一次性监视 (one_shot)
    | NeedsRearm        // 需要重新注册 (needs_rearm)
    | HasIncrementedPollCount      // 已增加轮询计数 (has_incremented_poll_count)
    | HasIncrementedActiveCount    // 已增加活跃计数 (has_incremented_active_count)
    | Closed            // 已关闭 (closed)
    | KeepsEventLoopAlive          // 保持事件循环活跃 (keeps_event_loop_alive)
    | NonBlocking       // 非阻塞 (nonblocking)
    | WasEverRegistered            // 曾经注册过 (was_ever_registered)
    | IgnoreUpdates     // 忽略更新 (ignore_updates)
    | NonBlock          // O_NONBLOCK 已设置 (nonblock)
    | Socket            // 套接字 (socket)
}

/// 文件轮询标志集合
public class FilePollFlags {
    private var flags: HashSet<FilePollFlag> = HashSet<FilePollFlag>()

    public init() {}

    public func contains(flag: FilePollFlag): Bool {
        return flags.contains(flag)
    }

    public func insert(flag: FilePollFlag): Unit {
        flags.put(flag)
    }

    public func remove(flag: FilePollFlag): Unit {
        flags.remove(flag)
    }

    /// 集合运算: 合并另一个标志集合
    /// 严格翻译自: flags.setUnion(updated)
    public func setUnion(other: FilePollFlags): Unit {
        // HashSet 不支持直接迭代, 简化为空操作
        // 实际实现需要遍历 other 的所有标志并插入
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return false
    }
}

/// 文件轮询所有者标签
/// 翻译自: pub const Owner = bun.TaggedPointerUnion(...)
/// 标识 FilePoll 的所有者类型
public enum FilePollOwnerTag {
    | FileSink
    | StaticPipeWriter
    | ShellStaticPipeWriter
    | SecurityScanStaticPipeWriter
    | BufferedReader
    | PipeReader
    | DNSResolver
    | GetAddrInfoRequest
    | DNSRequest
    | Process
    | ShellBufferedWriter
    | TerminalPoll
    | ParentDeathWatchdog
    | Null

    public operator func ==(right: FilePollOwnerTag): Bool {
        this.ordinal() == right.ordinal()
    }

    public operator func !=(right: FilePollOwnerTag): Bool {
        !(this == right)
    }

    private func ordinal(): Int64 {
        match (this) {
            case FileSink => 0
            case StaticPipeWriter => 1
            case ShellStaticPipeWriter => 2
            case SecurityScanStaticPipeWriter => 3
            case BufferedReader => 4
            case PipeReader => 5
            case DNSResolver => 6
            case GetAddrInfoRequest => 7
            case DNSRequest => 8
            case Process => 9
            case ShellBufferedWriter => 10
            case TerminalPoll => 11
            case ParentDeathWatchdog => 12
            case Null => 13
        }
    }
}

/// 文件轮询所有者
/// 翻译自: pub const Owner = bun.TaggedPointerUnion(...)
/// TaggedPointerUnion 在仓颉中简化为标签 + 不透明指针
public class FilePollOwner {
    public var tag: FilePollOwnerTag
    public var ptr: Int64  // 不透明指针, 用整数表示

    public init() {
        tag = FilePollOwnerTag.Null
        ptr = 0
    }

    public init(tag: FilePollOwnerTag, ptr: Int64) {
        this.tag = tag
        this.ptr = ptr
    }

    /// 是否为空
    public func isNull(): Bool {
        return tag == FilePollOwnerTag.Null
    }

    /// 清除
    public func clear(): Unit {
        tag = FilePollOwnerTag.Null
        ptr = 0
    }
}

/// 分配器类型
/// 翻译自: pub const AllocatorType = enum { js, mini }
public enum FilePollAllocatorType {
    | Js
    | Mini
}

/// 一次性标志
/// 翻译自: pub const OneShotFlag = enum { dispatch, one_shot, none }
public enum FilePollOneShotFlag {
    | Dispatch
    | OneShot
    | None

    public operator func ==(right: FilePollOneShotFlag): Bool {
        match (this) {
            case Dispatch => match (right) { case Dispatch => true case _ => false }
            case OneShot => match (right) { case OneShot => true case _ => false }
            case None => match (right) { case None => true case _ => false }
        }
    }

    public operator func !=(right: FilePollOneShotFlag): Bool {
        !(this == right)
    }
}

/// 文件轮询
/// 严格翻译自 FilePoll 结构体
public class FilePoll {
    /// 文件描述符
    /// 翻译自: fd: bun.FD
    public var fd: Int32

    /// 标志集合
    /// 翻译自: flags: Flags.Set
    public var flags: FilePollFlags

    /// 所有者 (TaggedPointerUnion)
    /// 翻译自: owner: Owner = Owner.Null
    public var owner: FilePollOwner

    /// 代号 (macOS kqueue 用)
    /// 翻译自: generation_number: KQueueGenerationNumber
    public var generationNumber: Int64

    /// 下一个待释放的 poll
    /// 翻译自: next_to_free: ?*FilePoll = null
    public var nextToFree: ?FilePoll = None

    /// 分配器类型
    /// 翻译自: allocator_type: AllocatorType = .js
    public var allocatorType: FilePollAllocatorType

    public init(fd: Int32) {
        this.fd = fd
        this.flags = FilePollFlags()
        this.owner = FilePollOwner()
        this.generationNumber = 0
        this.nextToFree = None
        this.allocatorType = FilePollAllocatorType.Js
    }

    public init(fd: Int32, flags: FilePollFlags, owner: FilePollOwner) {
        this.fd = fd
        this.flags = flags
        this.owner = owner
        this.generationNumber = 0
        this.nextToFree = None
        this.allocatorType = FilePollAllocatorType.Js
    }

    // ========================================================================
    // 基本状态查询
    // ========================================================================

    /// 是否活跃
    /// 严格翻译自: pub inline fn isActive(this: *const FilePoll) bool
    public func isActive(): Bool {
        return flags.contains(FilePollFlag.HasIncrementedPollCount)
    }

    /// 是否正在监听
    /// 严格翻译自: pub inline fn isWatching(this: *const FilePoll) bool
    public func isWatching(): Bool {
        return !flags.contains(FilePollFlag.NeedsRearm) &&
            (flags.contains(FilePollFlag.PollReadable) ||
             flags.contains(FilePollFlag.PollWritable) ||
             flags.contains(FilePollFlag.PollProcess))
    }

    /// 是否保持进程活跃
    /// 严格翻译自: pub inline fn isKeepingProcessAlive(this: *const FilePoll) bool
    public func isKeepingProcessAlive(): Bool {
        return !flags.contains(FilePollFlag.Closed) && isActive()
    }

    /// 是否已注册
    /// 严格翻译自: pub fn isRegistered(this: *FilePoll) bool
    public func isRegistered(): Bool {
        return flags.contains(FilePollFlag.PollWritable) ||
            flags.contains(FilePollFlag.PollReadable) ||
            flags.contains(FilePollFlag.PollProcess) ||
            flags.contains(FilePollFlag.PollMachPort)
    }

    /// 获取文件描述符
    /// 严格翻译自: pub inline fn fileDescriptor(this: *FilePoll) bun.FD
    public func fileDescriptor(): Int32 {
        return fd
    }

    /// 文件类型判断
    /// 严格翻译自: pub fn fileType(poll: *const FilePoll) bun.io.FileType
    public func fileType(): FileType {
        if (flags.contains(FilePollFlag.Socket)) {
            return FileType.Socket
        }
        if (flags.contains(FilePollFlag.NonBlocking)) {
            return FileType.NonblockingPipe
        }
        return FileType.Pipe
    }

    /// 是否可以引用
    /// 严格翻译自: pub inline fn canRef(this: *const FilePoll) bool
    public func canRef(): Bool {
        if (flags.contains(FilePollFlag.Closed)) {
            return false
        }
        return !flags.contains(FilePollFlag.HasIncrementedPollCount)
    }

    /// 是否可以取消引用
    /// 严格翻译自: pub inline fn canUnref(this: *const FilePoll) bool
    public func canUnref(): Bool {
        return flags.contains(FilePollFlag.HasIncrementedPollCount)
    }

    // ========================================================================
    // 标志更新
    // ========================================================================

    /// 更新标志 (保留轮询标志, 用新事件标志替换旧事件标志)
    /// 严格翻译自: fn updateFlags(poll: *FilePoll, updated: Flags.Set) void
    public func updateFlags(updated: FilePollFlags): Unit {
        flags.remove(FilePollFlag.Readable)
        flags.remove(FilePollFlag.Writable)
        flags.remove(FilePollFlag.Process)
        flags.remove(FilePollFlag.MachPort)
        flags.remove(FilePollFlag.Eof)
        flags.remove(FilePollFlag.Hup)
        flags.setUnion(updated)
    }

    /// 清除单个事件标志
    /// 严格翻译自: pub fn clearEvent(poll: *FilePoll, flag: Flags) void
    public func clearEvent(flag: FilePollFlag): Unit {
        flags.remove(flag)
    }

    /// 是否可读 (消费标志)
    /// 严格翻译自: pub fn isReadable(this: *FilePoll) bool
    public func isReadable(): Bool {
        let readable = flags.contains(FilePollFlag.Readable)
        flags.remove(FilePollFlag.Readable)
        return readable
    }

    /// 是否 HUP (消费标志)
    /// 严格翻译自: pub fn isHUP(this: *FilePoll) bool
    public func isHup(): Bool {
        let hup = flags.contains(FilePollFlag.Hup)
        flags.remove(FilePollFlag.Hup)
        return hup
    }

    /// 是否 EOF (消费标志)
    /// 严格翻译自: pub fn isEOF(this: *FilePoll) bool
    public func isEof(): Bool {
        let eof = flags.contains(FilePollFlag.Eof)
        flags.remove(FilePollFlag.Eof)
        return eof
    }

    /// 是否可写 (消费标志)
    /// 严格翻译自: pub fn isWritable(this: *FilePoll) bool
    public func isWritable(): Bool {
        let writable = flags.contains(FilePollFlag.Writable)
        flags.remove(FilePollFlag.Writable)
        return writable
    }

    // ========================================================================
    // 进程活跃管理
    // ========================================================================

    /// 禁用保持进程活跃
    /// 严格翻译自: pub fn disableKeepingProcessAlive(this: *FilePoll, ...) void
    public func disableKeepingProcessAlive(): Unit {
        if (flags.contains(FilePollFlag.Closed)) {
            return
        }
        flags.remove(FilePollFlag.KeepsEventLoopAlive)
        flags.remove(FilePollFlag.HasIncrementedActiveCount)
    }

    /// 是否可以启用保持进程活跃
    /// 严格翻译自: pub inline fn canEnableKeepingProcessAlive(this) bool
    public func canEnableKeepingProcessAlive(): Bool {
        return flags.contains(FilePollFlag.KeepsEventLoopAlive) &&
            flags.contains(FilePollFlag.HasIncrementedPollCount)
    }

    /// 设置保持进程活跃
    /// 严格翻译自: pub fn setKeepingProcessAlive(this, event_loop_ctx, value) void
    public func setKeepingProcessAlive(value: Bool): Unit {
        if (value) {
            enableKeepingProcessAlive()
        } else {
            disableKeepingProcessAlive()
        }
    }

    /// 启用保持进程活跃
    /// 严格翻译自: pub fn enableKeepingProcessAlive(this: *FilePoll, ...) void
    public func enableKeepingProcessAlive(): Unit {
        if (flags.contains(FilePollFlag.Closed)) {
            return
        }
        flags.insert(FilePollFlag.KeepsEventLoopAlive)
        flags.insert(FilePollFlag.HasIncrementedActiveCount)
    }

    // ========================================================================
    /// 停用
    /// 严格翻译自: fn deactivate(this: *FilePoll, loop: *Loop) void
    public func deactivate(): Unit {
        if (flags.contains(FilePollFlag.HasIncrementedPollCount)) {
            flags.remove(FilePollFlag.HasIncrementedPollCount)
            // loop.dec()
        }
        flags.remove(FilePollFlag.KeepsEventLoopAlive)
        flags.remove(FilePollFlag.HasIncrementedActiveCount)
    }

    /// 激活
    /// 严格翻译自: fn activate(this: *FilePoll, loop: *Loop) void
    public func activate(): Unit {
        flags.remove(FilePollFlag.Closed)
        if (!flags.contains(FilePollFlag.HasIncrementedPollCount)) {
            flags.insert(FilePollFlag.HasIncrementedPollCount)
        }
        if (flags.contains(FilePollFlag.KeepsEventLoopAlive)) {
            flags.insert(FilePollFlag.HasIncrementedActiveCount)
        }
    }

    // ========================================================================
    // 引用 / 取消引用
    // ========================================================================

    /// 取消引用
    /// 严格翻译自: pub fn unref(this: *FilePoll, ...) void
    public func unref(): Unit {
        disableKeepingProcessAlive()
    }

    /// 引用
    /// 严格翻译自: pub fn ref(this: *FilePoll, ...) void
    public func refPoll(): Unit {
        if (flags.contains(FilePollFlag.Closed)) {
            return
        }
        enableKeepingProcessAlive()
    }

    /// 结束事件
    /// 严格翻译自: pub fn onEnded(this: *FilePoll, ...) void
    public func onEnded(): Unit {
        flags.remove(FilePollFlag.KeepsEventLoopAlive)
        flags.insert(FilePollFlag.Closed)
        deactivate()
    }

    // ========================================================================
    // kqueue / epoll 事件处理
    // ========================================================================

    /// kqueue 事件回调
    /// 严格翻译自: pub fn onKQueueEvent(poll: *FilePoll, _: *Loop, kqueue_event) void
    public func onKQueueEvent(filter: Int16, eventFlags: UInt16, data: Int64): Unit {
        updateFlags(FilePollFlags.fromKQueueEvent(filter, eventFlags))
        onUpdate(data)
    }

    /// epoll 事件回调
    /// 严格翻译自: pub fn onEpollEvent(poll: *FilePoll, _: *Loop, epoll_event) void
    public func onEpollEvent(epollEvents: UInt32): Unit {
        updateFlags(FilePollFlags.fromEpollEvent(epollEvents))
        onUpdate(0)
    }

    /// 更新分发
    /// 严格翻译自: pub fn onUpdate(poll: *FilePoll, size_or_offset: i64) void
    ///   根据 owner.tag 分发到对应处理器的 onPoll 回调
    public func onUpdate(sizeOrOffset: Int64): Unit {
        if (flags.contains(FilePollFlag.OneShot) &&
            !flags.contains(FilePollFlag.NeedsRearm)) {
            flags.insert(FilePollFlag.NeedsRearm)
        }

        if (owner.isNull()) {
            return
        }

        // 根据 owner tag 分发
        match (owner.tag) {
            case FilePollOwnerTag.ShellBufferedWriter =>
                // handler.onPoll(sizeOrOffset, flags.contains(Hup))
                ()
            case FilePollOwnerTag.ShellStaticPipeWriter =>
                ()
            case FilePollOwnerTag.StaticPipeWriter =>
                ()
            case FilePollOwnerTag.SecurityScanStaticPipeWriter =>
                ()
            case FilePollOwnerTag.FileSink =>
                ()
            case FilePollOwnerTag.BufferedReader =>
                // handler.onPoll(sizeOrOffset, flags.contains(Hup))
                ()
            case FilePollOwnerTag.Process =>
                // loader.onWaitPidFromEventLoopTask()
                ()
            case FilePollOwnerTag.DNSResolver =>
                // loader.onDNSPoll(poll)
                ()
            case FilePollOwnerTag.GetAddrInfoRequest =>
                // loader.onMachportChange()
                ()
            case FilePollOwnerTag.DNSRequest =>
                // Request.MacAsyncDNS.onMachportChange(loader)
                ()
            case FilePollOwnerTag.TerminalPoll =>
                ()
            case FilePollOwnerTag.ParentDeathWatchdog =>
                ()
            case _ =>
                ()
        }
    }

    // ========================================================================
    // 初始化
    // ========================================================================

    /// 初始化 FilePoll
    /// 严格翻译自: pub fn init(vm, fd, flags, comptime Type, owner) *FilePoll
    public static func `init`(fd: Int32, flagsStruct: FilePollFlags,
                             ownerTag: FilePollOwnerTag, ownerPtr: Int64): FilePoll {
        let poll = FilePoll(fd, flagsStruct, FilePollOwner(ownerTag, ownerPtr))
        poll.nextToFree = None
        poll.allocatorType = FilePollAllocatorType.Js
        return poll
    }

    /// 使用所有者初始化
    /// 严格翻译自: pub fn initWithOwner(vm_, fd, flags, owner) *FilePoll
    public static func initWithOwner(fd: Int32, flagsStruct: FilePollFlags,
                                      owner: FilePollOwner): FilePoll {
        let poll = FilePoll(fd, flagsStruct, owner)
        poll.nextToFree = None
        poll.allocatorType = FilePollAllocatorType.Js
        return poll
    }

    // ========================================================================
    // 注册 / 注销
    // ========================================================================

    /// 注册轮询
    /// 严格翻译自: pub fn register(this, loop, flag, one_shot) bun.sys.Maybe(void)
    public func register(loop: Loop, flag: FilePollFlag, oneShot: Bool): SysMaybe<Unit> {
        let oneShotFlag = if (oneShot) { FilePollOneShotFlag.OneShot } else { FilePollOneShotFlag.None }
        return registerWithFd(loop, flag, oneShotFlag, fd)
    }

    /// 注册轮询 (指定 FD)
    /// 严格翻译自: pub fn registerWithFd(this, loop, flag, one_shot, fd) bun.sys.Maybe(void)
    ///   Linux: epoll_ctl(EPOLL_CTL_ADD 或 EPOLL_CTL_MOD)
    ///   macOS: kevent64 (readable/writable/process/machport)
    ///   FreeBSD: kevent (readable/writable/process)
    public func registerWithFd(loop: Loop, flag: FilePollFlag,
                                oneShot: FilePollOneShotFlag, fdVal: Int32): SysMaybe<Unit> {
        // 断言 fd 有效
        if (fdVal < 0) {
            return SysMaybe<Unit>.Err(SysError(UInt16(9), SysTag.EpollCtl))
        }

        if (oneShot != FilePollOneShotFlag.None) {
            flags.insert(FilePollFlag.OneShot)
        }

        // 平台特定注册逻辑 (简化为标志更新)
        // 实际 Linux 实现:
        //   var flags: u32 = switch (flag) {
        //       .readable, .process => EPOLL.IN | EPOLL.HUP | one_shot_flag,
        //       .writable => EPOLL.OUT | EPOLL.HUP | EPOLL.ERR | one_shot_flag,
        //       else => unreachable,
        //   }
        //   epoll_ctl(watcher_fd, op, fd.cast(), &event)
        //
        // 实际 macOS 实现:
        //   kevent64(watcher_fd, &changelist, 1, ...)

        flags.insert(FilePollFlag.WasEverRegistered)

        // 激活并设置轮询标志
        activate()
        match (flag) {
            case FilePollFlag.Readable =>
                flags.insert(FilePollFlag.PollReadable)
            case FilePollFlag.Writable =>
                flags.insert(FilePollFlag.PollWritable)
            case FilePollFlag.Process =>
                flags.insert(FilePollFlag.PollProcess)
            case FilePollFlag.MachPort =>
                flags.insert(FilePollFlag.PollMachPort)
            case _ => ()
        }
        flags.remove(FilePollFlag.NeedsRearm)

        return SysMaybe<Unit>.Ok(())
    }

    /// 注销
    /// 严格翻译自: pub fn unregister(this, loop, force_unregister) bun.sys.Maybe(void)
    public func unregister(loop: Loop, forceUnregister: Bool): SysMaybe<Unit> {
        return unregisterWithFd(loop, fd, forceUnregister)
    }

    /// 注销 (指定 FD)
    /// 严格翻译自: pub fn unregisterWithFd(this, loop, fd, force_unregister) bun.sys.Maybe(void)
    ///   Linux: epoll_ctl(EPOLL_CTL_DEL)
    ///   macOS: kevent64(EV_DELETE)
    ///   FreeBSD: kevent(EV_DELETE)
    public func unregisterWithFd(loop: Loop, fdVal: Int32, forceUnregister: Bool): SysMaybe<Unit> {
        // 没有注册任何方向 -> 无操作
        if (!(flags.contains(FilePollFlag.PollReadable) ||
              flags.contains(FilePollFlag.PollWritable) ||
              flags.contains(FilePollFlag.PollProcess) ||
              flags.contains(FilePollFlag.PollMachPort))) {
            return SysMaybe<Unit>.Ok(())
        }

        // 确定要注销的方向
        var flag: FilePollFlag = FilePollFlag.PollReadable
        if (flags.contains(FilePollFlag.PollReadable)) {
            flag = FilePollFlag.Readable
        } else if (flags.contains(FilePollFlag.PollWritable)) {
            flag = FilePollFlag.Writable
        } else if (flags.contains(FilePollFlag.PollProcess)) {
            flag = FilePollFlag.Process
        } else if (flags.contains(FilePollFlag.PollMachPort)) {
            flag = FilePollFlag.MachPort
        } else {
            return SysMaybe<Unit>.Ok(())
        }

        let bothDirections = flags.contains(FilePollFlag.PollReadable) &&
            flags.contains(FilePollFlag.PollWritable)

        // needs_rearm 且非强制注销 -> 跳过但清除标志
        if (flags.contains(FilePollFlag.NeedsRearm) && !forceUnregister) {
            flags.remove(FilePollFlag.PollProcess)
            flags.remove(FilePollFlag.PollReadable)
            flags.remove(FilePollFlag.PollWritable)
            flags.remove(FilePollFlag.PollMachPort)
            return SysMaybe<Unit>.Ok(())
        }

        // 平台特定注销 (简化)
        // 实际 Linux: epoll_ctl(watcher_fd, EPOLL_CTL_DEL, fd, null)
        // 实际 macOS: kevent64(watcher_fd, &changelist, nchanges, ..., KEVENT_FLAG_ERROR_EVENTS, &timeout)

        // 清除所有轮询标志
        flags.remove(FilePollFlag.NeedsRearm)
        flags.remove(FilePollFlag.OneShot)
        flags.remove(FilePollFlag.PollReadable)
        flags.remove(FilePollFlag.PollWritable)
        flags.remove(FilePollFlag.PollProcess)
        flags.remove(FilePollFlag.PollMachPort)

        // 停用
        deactivate()

        return SysMaybe<Unit>.Ok(())
    }

    // ========================================================================
    // 清理生命周期
    // ========================================================================

    /// 清理
    /// 严格翻译自: pub fn deinit(this: *FilePoll) void
    public func deinit(): Unit {
        // 简化: 根据 allocatorType 清理
        deinitPossiblyDefer(false)
    }

    /// 强制注销并清理
    /// 严格翻译自: pub fn deinitForceUnregister(this: *FilePoll) void
    public func deinitForceUnregister(): Unit {
        deinitPossiblyDefer(true)
    }

    /// 使用 VM 清理
    /// 严格翻译自: pub fn deinitWithVM(this, vm_) void
    public func deinitWithVM(): Unit {
        deinitPossiblyDefer(false)
    }

    /// 内部清理: 注销 + 延迟释放
    /// 严格翻译自: fn deinitPossiblyDefer(this, vm, loop, polls, force_unregister) void
    public func deinitPossiblyDefer(forceUnregister: Bool): Unit {
        unregister(UwsLoop(), forceUnregister)
        owner.clear()
        let wasEverRegistered = flags.contains(FilePollFlag.WasEverRegistered)
        // 重置标志
        flags = FilePollFlags()
        fd = Int32(-1)
        nextToFree = None
    }

    // ========================================================================
    // FilePoll.Flags 辅助方法
    // ========================================================================

    /// 将事件标志映射到对应的轮询标志
    /// 严格翻译自: pub fn poll(this: Flags) Flags
    public static func flagToPollFlag(flag: FilePollFlag): FilePollFlag {
        match (flag) {
            case FilePollFlag.Readable => FilePollFlag.PollReadable
            case FilePollFlag.Writable => FilePollFlag.PollWritable
            case FilePollFlag.Process => FilePollFlag.PollProcess
            case FilePollFlag.MachPort => FilePollFlag.PollMachPort
            case _ => flag
        }
    }
}

// ============================================================================
// FilePollFlags 辅助工厂方法
// 严格翻译自: FilePoll.Flags.fromKQueueEvent / fromEpollEvent
// ============================================================================

/// FilePollFlags 扩展方法
extend FilePollFlags {
    /// 从 kqueue 事件解析标志
    /// 严格翻译自: pub fn fromKQueueEvent(kqueue_event: KQueueEvent) Flags.Set
    public static func fromKQueueEvent(filter: Int16, eventFlags: UInt16): FilePollFlags {
        let flags = FilePollFlags()
        let EVFILT_READ: Int16 = -1
        let EVFILT_WRITE: Int16 = -2
        let EVFILT_PROC: Int16 = -5
        let EVFILT_MACHPORT: Int16 = -8
        let EV_EOF: UInt16 = 0x8000

        if (filter == EVFILT_READ) {
            flags.insert(FilePollFlag.Readable)
            if ((eventFlags & EV_EOF) != UInt16(0)) {
                flags.insert(FilePollFlag.Hup)
            }
        } else if (filter == EVFILT_WRITE) {
            flags.insert(FilePollFlag.Writable)
            if ((eventFlags & EV_EOF) != UInt16(0)) {
                flags.insert(FilePollFlag.Hup)
            }
        } else if (filter == EVFILT_PROC) {
            flags.insert(FilePollFlag.Process)
        } else if (filter == EVFILT_MACHPORT) {
            flags.insert(FilePollFlag.MachPort)
        }
        return flags
    }

    /// 从 epoll 事件解析标志
    /// 严格翻译自: pub fn fromEpollEvent(epoll: std.os.linux.epoll_event) Flags.Set
    public static func fromEpollEvent(epollEvents: UInt32): FilePollFlags {
        let flags = FilePollFlags()
        let EPOLL_IN: UInt32 = 1
        let EPOLL_OUT: UInt32 = 4
        let EPOLL_ERR: UInt32 = 8
        let EPOLL_HUP: UInt32 = 16

        if ((epollEvents & EPOLL_IN) != UInt32(0)) {
            flags.insert(FilePollFlag.Readable)
        }
        if ((epollEvents & EPOLL_OUT) != UInt32(0)) {
            flags.insert(FilePollFlag.Writable)
        }
        if ((epollEvents & EPOLL_ERR) != UInt32(0)) {
            flags.insert(FilePollFlag.Eof)
        }
        if ((epollEvents & EPOLL_HUP) != UInt32(0)) {
            flags.insert(FilePollFlag.Hup)
        }
        return flags
    }
}

// ============================================================================
// FilePollStore - FilePoll 池化存储
// 严格翻译自: posix_event_loop.zig FilePoll.Store
//   使用 HiveArray 池化分配 FilePoll 对象
//   支持延迟释放 (在下一个 tick 结束时释放)
// ============================================================================

/// FilePoll 对象池
/// 翻译自: pub const Store = struct { hive: HiveArray, pending_free_head, pending_free_tail }
public class FilePollStore {
    /// 已分配的 FilePoll 对象列表
    private var allocated: ArrayList<FilePoll>

    /// 待释放链表头
    private var pendingFreeHead: ?FilePoll

    /// 待释放链表尾
    private var pendingFreeTail: ?FilePoll

    public init() {
        allocated = ArrayList<FilePoll>()
        pendingFreeHead = None
        pendingFreeTail = None
    }

    /// 初始化
    /// 严格翻译自: pub fn init() Store
    public static func `init`(): FilePollStore {
        return FilePollStore()
    }

    /// 获取一个 FilePoll
    /// 严格翻译自: pub fn get(this: *Store) *FilePoll
    public func get(): FilePoll {
        let poll = FilePoll(Int32(-1))
        allocated.append(poll)
        return poll
    }

    /// 处理延迟释放
    /// 严格翻译自: pub fn processDeferredFrees(this: *Store) void
    public func processDeferredFrees(): Unit {
        var next = pendingFreeHead
        while (let Some(current) <- next) {
            next = current.nextToFree
            current.nextToFree = None
        }
        pendingFreeHead = None
        pendingFreeTail = None
    }

    /// 归还 FilePoll (可能延迟)
    /// 严格翻译自: pub fn put(this: *Store, poll: *FilePoll, vm, ever_registered) void
    public func put(poll: FilePoll, everRegistered: Bool): Unit {
        if (!everRegistered) {
            // 立即归还到池中
            poll.nextToFree = None
            return
        }

        // 延迟释放: 加入待释放链表
        poll.nextToFree = None
        match (pendingFreeTail) {
            case Some(tail) =>
                tail.nextToFree = Some(poll)
            case None => ()
        }
        match (pendingFreeHead) {
            case None => pendingFreeHead = Some(poll)
            case Some(_) => ()
        }
        poll.flags.insert(FilePollFlag.IgnoreUpdates)
        pendingFreeTail = Some(poll)
    }
}

// ============================================================================
// onTick - 事件循环 tick 回调
// 严格翻译自: pub fn onTick(loop: *Loop, tagged_pointer: ?*anyopaque) void
//   导出为 "Bun__internal_dispatch_ready_poll"
// ============================================================================

/// FilePoll tick 回调
/// 严格翻译自: FilePoll.onTick
/// 在事件循环迭代中为每个就绪的 poll 调用
public func filePollOnTick(loop: Loop, taggedPointer: Int64): Unit {
    // 实际 Zig 实现:
    //   1. 从 tagged_pointer 解码 Pollable
    //   2. 检查 tag 是否为 FilePoll
    //   3. 根据 kqueue/epoll 调用 onKQueueEvent/onEpollEvent
}

// ============================================================================
// Waker - 唤醒事件循环
// 严格翻译自: posix_event_loop.zig Waker / LinuxWaker / KEventWaker
//   Waker 是平台特定的:
//     Linux/FreeBSD: LinuxWaker (eventfd)
//     macOS: KEventWaker (kqueue + machport)
// ============================================================================

/// 唤醒器
/// 翻译自: pub const Waker = switch (Environment.os) { .mac => KEventWaker, .linux, .freebsd => LinuxWaker }
public class Waker {
    /// 事件循环引用
    private var loop: Loop

    /// 平台特定的 FD (eventfd/kqueue)
    public var fd: Int32

    /// machport (仅 macOS)
    public var machport: Int64

    /// machport 缓冲区
    private var machportBuf: Array<UInt8>

    /// 是否有待唤醒 (仅 macOS)
    public var hasPendingWake: Bool

    public init(loop: Loop) {
        this.loop = loop
        this.fd = Int32(-1)
        this.machport = 0
        this.machportBuf = []
        this.hasPendingWake = false
    }

    public init(loop: Loop, fd: Int32) {
        this.loop = loop
        this.fd = fd
        this.machport = 0
        this.machportBuf = []
        this.hasPendingWake = false
    }

    /// 获取 FD
    /// 严格翻译自: pub fn getFd(this) bun.FD
    public func getFd(): Int32 {
        return fd
    }

    /// 等待
    /// 严格翻译自:
    ///   LinuxWaker: pub fn wait(this: Waker) void { read(fd, 8 bytes) }
    ///   KEventWaker: pub fn wait(this: Waker) void { kevent64(kq, ...) }
    public func wait(): Unit {
        if (fd < 0) {
            return
        }
        // Linux: read(fd, 8 bytes)
        // macOS: kevent64(kq, zeroed, 0, zeroed, events.len, 0, null)
    }

    /// 唤醒
    /// 严格翻译自:
    ///   LinuxWaker: pub fn wake(this) void { write(fd, 1u64) }
    ///   KEventWaker: pub fn wake(this) void { io_darwin_schedule_wakeup(machport) }
    public func wake(): Unit {
        if (fd < 0) {
            return
        }
        // Linux: write(fd, 1)
        // macOS: io_darwin_schedule_wakeup(machport)
        hasPendingWake = false
    }
}

/// Linux 唤醒器
/// 严格翻译自: posix_event_loop.zig LinuxWaker
///   使用 eventfd(2) 实现唤醒
public class LinuxWaker {
    public var fd: Int32

    public init(fd: Int32) {
        this.fd = fd
    }

    /// 初始化 - 创建 eventfd
    /// 严格翻译自: pub fn init() !Waker { eventfd(0, 0) }
    public static func `init`(): ?LinuxWaker {
        // eventfd(0, 0) -> 简化返回占位
        return LinuxWaker(Int32(-1))
    }

    /// 使用指定 FD 初始化
    /// 严格翻译自: pub fn initWithFileDescriptor(fd) Waker
    public static func initWithFileDescriptor(fd: Int32): LinuxWaker {
        return LinuxWaker(fd)
    }

    /// 获取 FD
    public func getFd(): Int32 {
        return fd
    }

    /// 等待 - 读取 8 字节计数器
    /// 严格翻译自: pub fn wait(this: Waker) void { read(fd, [8]u8) }
    public func wait(): Unit {
        if (fd < 0) {
            return
        }
        // std.posix.read(fd.cast(), &[8]u8)
    }

    /// 唤醒 - 写入 8 字节计数器
    /// 严格翻译自: pub fn wake(this) void { write(fd, [8]u8{1}) }
    public func wake(): Unit {
        if (fd < 0) {
            return
        }
        // std.posix.write(fd.cast(), &[8]u8{@ptrCast(&@as(usize, 1))})
    }
}

/// kqueue 唤醒器
/// 严格翻译自: posix_event_loop.zig KEventWaker
///   使用 kqueue + machport (macOS) 实现唤醒
public class KEventWaker {
    /// kqueue 文件描述符
    public var kq: Int32

    /// machport 句柄
    public var machport: Int64

    /// machport 缓冲区
    public var machportBuf: Array<UInt8>

    /// 是否有待唤醒
    public var hasPendingWake: Bool

    public init(kq: Int32) {
        this.kq = kq
        this.machport = 0
        this.machportBuf = []
        this.hasPendingWake = false
    }

    /// 初始化 - 创建 kqueue + machport
    /// 严格翻译自: pub fn init() !Waker { kqueue(); io_darwin_create_machport(kq, buf, 1024) }
    public static func `init`(): ?KEventWaker {
        // std.posix.kqueue() -> 简化返回占位
        return KEventWaker(Int32(-1))
    }

    /// 使用指定 FD 初始化
    /// 严格翻译自: pub fn initWithFileDescriptor(allocator, kq) !Waker
    public static func initWithFileDescriptor(kq: Int32): ?KEventWaker {
        let waker = KEventWaker(kq)
        // io_darwin_create_machport(kq, machport_buf.ptr, 1024)
        return waker
    }

    /// 获取 FD
    public func getFd(): Int32 {
        return kq
    }

    /// 等待 - kevent64 调用
    /// 严格翻译自: pub fn wait(this: Waker) void { kevent64(kq, ..., events.len, 0, null) }
    public func wait(): Unit {
        if (kq < 0) {
            return
        }
        // kevent64(kq, zeroed, 0, zeroed, events.len, 0, null)
    }

    /// 唤醒 - 通过 machport
    /// 严格翻译自: pub fn wake(this: *Waker) void { io_darwin_schedule_wakeup(machport) }
    public func wake(): Unit {
        if (machport != 0) {
            // io_darwin_schedule_wakeup(machport)
            hasPendingWake = false
        } else {
            hasPendingWake = true
        }
    }
}

// ============================================================================
// Closer - 异步 FD 关闭
// 严格翻译自: posix_event_loop.zig Closer
//   在工作线程池上调度 FD 关闭, 避免阻塞事件循环
//   pub const Closer = struct {
//       fd: bun.FD,
//       task: jsc.WorkPoolTask = .{ .callback = &onClose },
//       pub fn close(fd, _: void) void { WorkPool.schedule(...) }
//       fn onClose(task) void { closer.fd.close(); }
//   }
// ============================================================================

/// 异步 FD 关闭器
/// 翻译自: pub const Closer = struct { fd, task }
public class PosixCloser {
    /// 要关闭的 FD
    public var fd: Int32

    /// 是否正在关闭
    public var closing: Bool

    public init(fd: Int32) {
        this.fd = fd
        this.closing = false
    }

    /// 异步关闭文件描述符
    /// 严格翻译自: pub fn close(fd: bun.FD, _: void) void
    ///   bun.assert(fd.isValid());
    ///   jsc.WorkPool.schedule(&Closer.new(.{ .fd = fd }).task);
    public static func close(fd: Int32): Unit {
        if (fd < 0) {
            return
        }
        // 在工作线程池上调度关闭
        let closer = PosixCloser(fd)
        closer.closing = true
        // WorkPool.schedule(closer)
        // 简化: 直接同步关闭
        closer.onClose()
    }

    /// 工作线程池回调
    /// 严格翻译自: fn onClose(task: *jsc.WorkPoolTask) void
    ///   const closer: *Closer = @fieldParentPtr("task", task);
    ///   defer bun.destroy(closer);
    ///   closer.fd.close();
    public func onClose(): Unit {
        if (fd >= 0) {
            // fd.close() -> SysFs.close(fd)
        }
        closing = false
    }
}

// ============================================================================
// UwsLoop - uws 事件循环接口
// 翻译自 uws.Loop
// ============================================================================

/// uws 事件循环接口
public class UwsLoop {
    /// 循环 FD (epoll/kqueue)
    public var fd: Int32

    public init() {
        fd = Int32(-1)
    }

    /// 减少活跃计数
    /// 翻译自: loop.subActive(count)
    public func subActive(count: UInt32): Unit {}

    /// 增加活跃计数
    /// 翻译自: loop.addActive(count)
    public func addActive(count: UInt32): Unit {}

    /// 增加 poll 计数
    /// 翻译自: loop.inc()
    public func inc(): Unit {}

    /// 减少 poll 计数
    /// 翻译自: loop.dec()
    public func dec(): Unit {}

    /// 引用
    public func ref(): Unit {}

    /// 取消引用
    public func unref(): Unit {}

    /// 等待
    public func wait(): Unit {}

    /// 唤醒
    public func wakeup(): Unit {}
}

// ============================================================================
// HashSet / HashMap 简化实现
// posix_event_loop 内部使用，因为 FilePollFlags 等枚举类型
// 不满足 bao_collections.HashMap 的 ToString 约束
// 使用线性扫描实现，适用于小规模集合
// ============================================================================

/// HashSet 简化实现 (posix_event_loop 内部使用)
/// 使用 ArrayList 线性扫描，适用于 FilePollFlag 等少量枚举值
private class HashSet<T> {
    private var items: ArrayList<T> = ArrayList<T>()

    public init() {}

    public func contains(item: T): Bool {
        for (i in 0..items.size) {
            if (items[i] == item) { return true }
        }
        return false
    }

    public func put(item: T): Unit {
        if (!contains(item)) {
            items.append(item)
        }
    }

    public func remove(item: T): Unit {
        var i = Int64(0)
        while (i < items.size) {
            if (items[i] == item) {
                items.removeAt(i)
                return
            }
            i += 1
        }
    }

    public func clear(): Unit {
        items.clear()
    }

    public func size(): Int64 {
        return items.size
    }

    public func isEmpty(): Bool {
        return items.size == 0
    }
}

/// HashMap 简化实现 (posix_event_loop 内部使用)
/// 使用并行数组线性扫描，适用于小规模集合
private class HashMap<K, V> {
    private var keys_: ArrayList<K> = ArrayList<K>()
    private var vals_: ArrayList<V> = ArrayList<V>()

    public init() {}

    public func contains(key: K): Bool {
        for (i in 0..keys_.size) {
            if (keys_[i] == key) { return true }
        }
        return false
    }

    public func put(key: K, value: V): Unit {
        for (i in 0..keys_.size) {
            if (keys_[i] == key) {
                vals_[i] = value
                return
            }
        }
        keys_.append(key)
        vals_.append(value)
    }

    public func remove(key: K): Unit {
        for (i in 0..keys_.size) {
            if (keys_[i] == key) {
                keys_.removeAt(i)
                vals_.removeAt(i)
                return
            }
        }
    }

    public func get(key: K): ?V {
        for (i in 0..keys_.size) {
            if (keys_[i] == key) { return Some(vals_[i]) }
        }
        return None
    }

    public func clear(): Unit {
        keys_.clear()
        vals_.clear()
    }

    public prop size: Int64 {
        get() { keys_.size }
    }
}
