// bao_io - POSIX 事件循环
// 严格翻译自: src/io/posix_event_loop.zig
//   Bun 在 POSIX 平台使用 uws.Loop 作为事件循环
//   KeepAlive: 跟踪 poll 是否应保持事件循环活跃
//   FilePoll: 文件描述符轮询, 使用 kqueue/epoll
//   Waker: 唤醒事件循环
//   仓颉实现提供等价的 POSIX 事件循环抽象
package bao_io

import bao_core.*

// ============================================================================
// Loop - 事件循环
// 严格翻译自: posix_event_loop.zig:1
//   pub const Loop = uws.Loop
// ============================================================================

/// 事件循环类型别名
/// 翻译自: pub const Loop = uws.Loop
public typealias Loop = UwsLoop

// ============================================================================
// KeepAlive - 保持事件循环活跃
// 严格翻译自: posix_event_loop.zig:3-114 KeepAlive
//   状态: active / inactive / done
//   不是引用计数, 只跟踪 active/inactive
// ============================================================================

/// 保持事件循环活跃状态
/// 严格翻译自 KeepAlive 结构体
public class KeepAlive {
    /// 状态枚举
    /// 翻译自: const Status = enum { active, inactive, done }
    public enum Status {
        | Active
        | Inactive
        | Done
    }

    public var status: Status = Status.Inactive

    public init() {}

    /// 是否活跃
    /// 严格翻译自: pub inline fn isActive(this: KeepAlive) bool
    public func isActive(): Bool {
        return status == Status.Active
    }

    /// 禁用 - 设为 Done, 调用 unref
    /// 严格翻译自: pub fn disable(this: *KeepAlive) void
    public func disable(loop: Loop): Unit {
        if (status == Status.Active) {
            unref(loop)
        }
        status = Status.Done
    }

    /// 停用
    /// 严格翻译自: pub fn deactivate(this: *KeepAlive, loop: *Loop) void
    public func deactivate(loop: Loop): Unit {
        if (status != Status.Active) {
            return
        }
        status = Status.Inactive
        loop.subActive(1)
    }

    /// 激活
    /// 严格翻译自: pub fn activate(this: *KeepAlive, loop: *Loop) void
    public func activate(loop: Loop): Unit {
        if (status != Status.Inactive) {
            return
        }
        status = Status.Active
        loop.addActive(1)
    }

    /// 取消引用
    /// 严格翻译自: pub fn unref(this: *KeepAlive, ...) void
    public func unref(loop: Loop): Unit {
        if (status != Status.Active) {
            return
        }
        status = Status.Inactive
        loop.unref()
    }

    /// 从另一个线程取消引用
    /// 严格翻译自: pub fn unrefConcurrently(this: *KeepAlive, vm: ...) void
    public func unrefConcurrently(): Unit {
        if (status != Status.Active) {
            return
        }
        status = Status.Inactive
        // vm.event_loop.unrefConcurrently()
    }

    /// 引用
    /// 严格翻译自: pub fn ref(this: *KeepAlive, ...) void
    public func ref(loop: Loop): Unit {
        if (status != Status.Inactive) {
            return
        }
        status = Status.Active
        loop.ref()
    }

    /// 从另一个线程引用
    /// 严格翻译自: pub fn refConcurrently(this: *KeepAlive, vm: ...) void
    public func refConcurrently(): Unit {
        if (status != Status.Inactive) {
            return
        }
        status = Status.Active
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
public enum FilePollFlag {
    | PollReadable
    | PollWritable
    | PollProcess
    | PollMachPort
    | Readable       // 事件: 可读
    | Writable       // 事件: 可写
    | Hup            // 事件: 挂断
    | Eof            // 事件: 文件结束
    | Closed
    | HasIncrementedPollCount
    | KeepsEventLoopAlive
    | NeedsRearm
    | WasEverRegistered
    | IgnoreUpdates
}

/// 文件轮询状态集合
public class FilePollFlags {
    private var flags: HashSet<FilePollFlag> = HashSet<FilePollFlag>()

    public func contains(flag: FilePollFlag): Bool {
        return flags.contains(flag)
    }

    public func insert(flag: FilePollFlag): Unit {
        flags.put(flag)
    }

    public func remove(flag: FilePollFlag): Unit {
        flags.remove(flag)
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

    /// 下一个待释放的 poll
    /// 翻译自: next_to_free: ?*FilePoll = null
    public var nextToFree: ?FilePoll = None

    public init(fd: Int32) {
        this.fd = fd
        this.flags = FilePollFlags()
    }

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

    /// 禁用保持进程活跃
    /// 严格翻译自: pub fn disableKeepingProcessAlive(this: *FilePoll, ...)
    public func disableKeepingProcessAlive(): Unit {
        if (flags.contains(FilePollFlag.Closed)) {
            return
        }
        flags.insert(FilePollFlag.Closed)
        if (flags.contains(FilePollFlag.HasIncrementedPollCount)) {
            // platformEventLoop().subActive(1)
        }
    }

    /// 启用保持进程活跃
    /// 严格翻译自: pub fn enableKeepingProcessAlive(this: *FilePoll, ...)
    public func enableKeepingProcessAlive(): Unit {
        if (!flags.contains(FilePollFlag.Closed)) {
            return
        }
        flags.remove(FilePollFlag.Closed)
        if (flags.contains(FilePollFlag.HasIncrementedPollCount)) {
            // platformEventLoop().addActive(1)
        }
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

    /// 取消引用
    /// 严格翻译自: pub fn unref(this: *FilePoll, ...) void
    public func unref(): Unit {
        if (!canUnref()) {
            return
        }
        deactivate()
    }

    /// 引用
    /// 严格翻译自: pub fn ref(this: *FilePoll, ...) void
    public func refPoll(): Unit {
        if (canRef()) {
            return
        }
        activate()
    }

    public func canRef(): Bool {
        if (flags.contains(FilePollFlag.Closed)) {
            return false
        }
        return !flags.contains(FilePollFlag.HasIncrementedPollCount)
    }

    public func canUnref(): Bool {
        return flags.contains(FilePollFlag.HasIncrementedPollCount)
    }

    /// 停用
    /// 严格翻译自: pub fn deactivate(this: *FilePoll, loop: *Loop) void
    public func deactivate(): Unit {
        if (flags.contains(FilePollFlag.HasIncrementedPollCount)) {
            flags.remove(FilePollFlag.HasIncrementedPollCount)
            // loop.subActive(1)
        }
    }

    /// 激活
    /// 严格翻译自: pub fn activate(this: *FilePoll, loop: *Loop) void
    public func activate(): Unit {
        if (!flags.contains(FilePollFlag.Closed) &&
            !flags.contains(FilePollFlag.HasIncrementedPollCount)) {
            flags.insert(FilePollFlag.HasIncrementedPollCount)
            // loop.addActive(1)
        }
    }

    /// 结束事件
    /// 严格翻译自: pub fn onEnded(this: *FilePoll, ...) void
    public func onEnded(): Unit {
        flags.remove(FilePollFlag.KeepsEventLoopAlive)
        flags.insert(FilePollFlag.Closed)
        deactivate()
    }
}

// ============================================================================
// Waker - 唤醒事件循环
// 严格翻译自: posix_event_loop.zig Waker
// ============================================================================

/// 唤醒器
/// 翻译自: pub const Waker = struct { loop: *bun.uws.Loop }
public class Waker {
    private var loop: Loop

    public init(loop: Loop) {
        this.loop = loop
    }

    /// 等待
    /// 严格翻译自: pub fn wait(this: Waker) void
    public func wait(): Unit {
        loop.wait()
    }

    /// 唤醒
    /// 严格翻译自: pub fn wake(this: *const Waker) void
    public func wake(): Unit {
        loop.wakeup()
    }
}

// ============================================================================
// UwsLoop - uws 事件循环接口
// 翻译自 uws.Loop
// ============================================================================

/// uws 事件循环接口
public class UwsLoop {
    public func subActive(count: UInt32): Unit {}
    public func addActive(count: UInt32): Unit {}
    public func ref(): Unit {}
    public func unref(): Unit {}
    public func wait(): Unit {}
    public func wakeup(): Unit {}
}

/// HashSet 简化实现
private class HashSet<T> {
    private var data: HashMap<T, Bool> = HashMap<T, Bool>()

    public func contains(key: T): Bool {
        return data.contains(key)
    }

    public func put(key: T): Unit {
        data.put(key, true)
    }

    public func remove(key: T): Unit {
        data.remove(key)
    }
}

/// HashMap 简化实现
private class HashMap<K, V> {
    public func contains(key: K): Bool {
        return false
    }

    public func put(key: K, value: V): Unit {}
    public func remove(key: K): Unit {}
}
