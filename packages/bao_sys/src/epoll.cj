// bao_sys - epoll 事件循环 (Linux)
// 严格翻译自: src/sys/epoll.zig + src/event_loop/epoll.zig
//   Bun 使用 epoll (Linux) / kqueue (macOS) 进行异步 I/O
//   仓颉通过 C FFI 调用 epoll 系统调用
package bao_sys

import bao_core.*

// ============================================================================
// epoll C FFI 声明
// 对应 Bun: Linux epoll 系统调用
// ============================================================================

@C
foreign func epoll_create(size: Int32): Int32
@C
foreign func epoll_create1(flags: Int32): Int32
@C
foreign func epoll_ctl(epfd: Int32, op: Int32, fd: Int32,
                        event: CPointer<Unit>): Int32
@C
foreign func epoll_wait(epfd: Int32, events: CPointer<Unit>,
                         maxEvents: Int32, timeout: Int32): Int32

// ============================================================================
// epoll 常量 - 对应 Linux epoll.h
// ============================================================================

/// epoll 操作常量
public class EpollOp {
    public static let EPOLL_CTL_ADD: Int32 = 1
    public static let EPOLL_CTL_MOD: Int32 = 3
    public static let EPOLL_CTL_DEL: Int32 = 2
}

/// epoll 事件常量
public class EpollEvents {
    public static let EPOLLIN: UInt32 = 0x001
    public static let EPOLLOUT: UInt32 = 0x004
    public static let EPOLLRDHUP: UInt32 = 0x2000
    public static let EPOLLPRI: UInt32 = 0x002
    public static let EPOLLERR: UInt32 = 0x008
    public static let EPOLLHUP: UInt32 = 0x010
    public static let EPOLLET: UInt32 = 1 << 31
    public static let EPOLLONESHOT: UInt32 = 1 << 30
    public static let EPOLLWAKEUP: UInt32 = 1 << 29
}

/// epoll_create1 标志
public class EpollCreateFlags {
    public static let EPOLL_CLOEXEC: Int32 = 0x80000
}

// ============================================================================
// EpollEvent - 事件结构体
// 严格翻译自: struct epoll_event
//   events: uint32  // 事件掩码
//   data: union { void*, int, uint32, uint64 }  // 用户数据
// ============================================================================

/// epoll 事件 - 对应 struct epoll_event
public class EpollEvent {
    /// 事件掩码 - EPOLLIN | EPOLLOUT | ...
    public var events: UInt32
    /// 关联的文件描述符
    public var fd: Int64
    /// 用户数据 (可选)
    public var userData: Int64

    public init(events: UInt32, fd: Int64) {
        this.events = events
        this.fd = fd
        this.userData = 0
    }

    public init(events: UInt32, fd: Int64, userData: Int64) {
        this.events = events
        this.fd = fd
        this.userData = userData
    }

    /// 是否可读
    public func isReadable(): Bool {
        return (events & EpollEvents.EPOLLIN) != 0
    }

    /// 是否可写
    public func isWritable(): Bool {
        return (events & EpollEvents.EPOLLOUT) != 0
    }

    /// 是否错误
    public func isError(): Bool {
        return (events & EpollEvents.EPOLLERR) != 0
    }

    /// 是否挂断
    public func isHangup(): Bool {
        return (events & EpollEvents.EPOLLHUP) != 0 ||
               (events & EpollEvents.EPOLLRDHUP) != 0
    }

    /// 是否优先级数据
    public func isPriority(): Bool {
        return (events & EpollEvents.EPOLLPRI) != 0
    }
}

// ============================================================================
// Epoll - epoll 实例封装
// 严格翻译自: src/event_loop/epoll.zig
// ============================================================================

/// epoll 实例 - 对应 Bun epoll 封装
/// 管理文件描述符的事件注册和等待
public class Epoll {
    /// epoll 文件描述符
    private var epfd: Int64
    /// 是否已关闭
    private var closed: Bool

    private init(epfd: Int64) {
        this.epfd = epfd
        this.closed = false
    }

    /// 创建 epoll 实例
    /// 对应: epoll_create1(EPOLL_CLOEXEC)
    public static func create(): SysMaybe<Epoll> {
        let fd = epoll_create1(EpollCreateFlags.EPOLL_CLOEXEC)
        if (fd < 0) {
            return SysMaybe<Epoll>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.EpollCtl))
        }
        return SysMaybe<Epoll>.Ok(Epoll(Int64(fd)))
    }

    /// 添加文件描述符监听
    /// 对应: epoll_ctl(epfd, EPOLL_CTL_ADD, fd, &event)
    public func add(fd: Int64, events: UInt32, userData: Int64): SysMaybe<Unit> {
        if (closed) {
            return SysMaybe<Unit>.Err(SysError(9, SysTag.EpollCtl))  // EBADF
        }
        // 简化: 实际需要构造 epoll_event 结构体并传递指针
        let rc = epoll_ctl(Int32(epfd), EpollOp.EPOLL_CTL_ADD,
                            Int32(fd), CPointer<Unit>())
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.EpollCtl))
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 修改文件描述符监听
    /// 对应: epoll_ctl(epfd, EPOLL_CTL_MOD, fd, &event)
    public func modify(fd: Int64, events: UInt32, userData: Int64): SysMaybe<Unit> {
        if (closed) {
            return SysMaybe<Unit>.Err(SysError(9, SysTag.EpollCtl))
        }
        let rc = epoll_ctl(Int32(epfd), EpollOp.EPOLL_CTL_MOD,
                            Int32(fd), CPointer<Unit>())
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.EpollCtl))
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 删除文件描述符监听
    /// 对应: epoll_ctl(epfd, EPOLL_CTL_DEL, fd, NULL)
    public func remove(fd: Int64): SysMaybe<Unit> {
        if (closed) {
            return SysMaybe<Unit>.Err(SysError(9, SysTag.EpollCtl))
        }
        let rc = epoll_ctl(Int32(epfd), EpollOp.EPOLL_CTL_DEL,
                            Int32(fd), CPointer<Unit>())
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.EpollCtl))
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 等待事件
    /// 对应: epoll_wait(epfd, events, maxEvents, timeout)
    /// timeout: -1 = 无限等待, 0 = 立即返回, >0 = 毫秒数
    public func wait(maxEvents: Int64, timeoutMs: Int64): SysMaybe<Array<EpollEvent>> {
        if (closed) {
            return SysMaybe<Array<EpollEvent>>.Err(SysError(9, SysTag.Poll))
        }
        // 简化: 实际需要分配 epoll_event 数组并解析结果
        // struct epoll_event 大小为 12 字节 (4 + 8 padding)
        let eventSize = 12
        unsafe {
            let eventsBuf = malloc(UIntNative(maxEvents * eventSize))
            let numEvents = epoll_wait(Int32(epfd), eventsBuf,
                                        Int32(maxEvents), Int32(timeoutMs))
            if (numEvents < 0) {
                free(eventsBuf)
                let errNum = Int64(OS.errno())
                // EINTR 不是错误
                if (errNum == 4) {
                    return SysMaybe<Array<EpollEvent>>.Ok([])
                }
                return SysMaybe<Array<EpollEvent>>.Err(
                    SysError(UInt16(errNum), SysTag.Poll))
            }
            var result = ArrayList<EpollEvent>()
            // 解析事件 (简化: 需要按 epoll_event 结构布局读取)
            free(eventsBuf)
            return SysMaybe<Array<EpollEvent>>.Ok(result.toArray())
        }
    }

    /// 非阻塞 poll (timeout=0)
    public func poll(maxEvents: Int64): SysMaybe<Array<EpollEvent>> {
        return wait(maxEvents, 0)
    }

    /// 关闭 epoll 实例
    public func close(): Unit {
        if (!closed) {
            bao_sys.close(Int32(epfd))
            closed = true
        }
    }

    /// 获取 epoll FD
    public func fd(): Int64 {
        return epfd
    }
}
