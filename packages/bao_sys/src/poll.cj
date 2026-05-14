// bao_sys - Poll 抽象层
// 严格翻译自: src/sys/sys.zig + src/io/io.zig
//   Bun 使用 poll/epoll/kqueue 进行文件描述符事件通知
//   PollFd, PollEvents 封装 POSIX poll() 系统调用
//   支持 edge-triggered 和 level-triggered 模式
package bao_sys

import bao_core.*

// ============================================================================
// poll() C FFI 声明
// ============================================================================

/// struct pollfd 的 C 表示
/// pollfd { fd: int, events: short, revents: short }
@C
foreign func poll(fds: CPointer<Unit>, nfds: UIntNative, timeout: Int32): Int32

// ============================================================================
// PollEvents - 事件标志
// 严格翻译自: POSIX poll.h 事件常量
//   POLLIN  = 0x0001  有数据可读
//   POLLPRI = 0x0002  有紧急数据
//   POLLOUT = 0x0004  写入不会阻塞
//   POLLERR = 0x0008  错误条件
//   POLLHUP = 0x0010  挂断
//   POLLNVAL = 0x0020 无效请求
// ============================================================================

/// poll 事件标志 - 对应 POSIX poll.h 常量
public class PollEvents {
    /// 可读 - POLLIN = 0x0001
    public static let POLLIN: Int16 = 0x0001
    /// 紧急数据 - POLLPRI = 0x0002
    public static let POLLPRI: Int16 = 0x0002
    /// 可写 - POLLOUT = 0x0004
    public static let POLLOUT: Int16 = 0x0004
    /// 错误 - POLLERR = 0x0008 (仅 revents)
    public static let POLLERR: Int16 = 0x0008
    /// 挂断 - POLLHUP = 0x0010 (仅 revents)
    public static let POLLHUP: Int16 = 0x0010
    /// 无效请求 - POLLNVAL = 0x0020 (仅 revents)
    public static let POLLNVAL: Int16 = 0x0020
    /// 普通数据 - POLLRDNORM = 0x0040
    public static let POLLRDNORM: Int16 = 0x0040
    /// 优先数据 - POLLRDBAND = 0x0080
    public static let POLLRDBAND: Int16 = 0x0080
    /// 普通写 - POLLWRNORM = 0x0100
    public static let POLLWRNORM: Int16 = 0x0100
    /// 优先写 - POLLWRBAND = 0x0200
    public static let POLLWRBAND: Int16 = 0x0200

    /// 标准可读事件掩码: POLLIN | POLLRDNORM
    public static let READABLE: Int16 = POLLIN | POLLRDNORM
    /// 标准可写事件掩码: POLLOUT | POLLWRNORM
    public static let WRITABLE: Int16 = POLLOUT | POLLWRNORM
    /// 全部事件掩码: POLLIN | POLLPRI | POLLOUT
    public static let ALL: Int16 = POLLIN | POLLPRI | POLLOUT
}

// ============================================================================
// TriggerMode - 触发模式
// 严格翻译自: epoll ET vs LT 模式
//   Level-triggered (LT): 只要条件满足就持续通知
//   Edge-triggered (ET): 只在状态变化时通知一次
// ============================================================================

/// 触发模式 - 对应 epoll 边沿/水平触发
public enum TriggerMode {
    | LevelTriggered   // 水平触发 (默认): 有数据就持续通知
    | EdgeTriggered    // 边沿触发: 只通知一次状态变化

    /// 描述
    public func description(): String {
        match (this) {
            case LevelTriggered => "level-triggered"
            case EdgeTriggered => "edge-triggered"
        }
    }
}

// ============================================================================
// PollFd - poll 文件描述符
// 严格翻译自: struct pollfd { int fd; short events; short revents; }
//   对应 Bun: src/io/io.zig Poll.Flags
// ============================================================================

/// poll 文件描述符条目 - 对应 struct pollfd
/// 封装一个待轮询的文件描述符及其事件
public class PollFd {
    /// 文件描述符
    public var fd: Int64
    /// 感兴趣的事件 (输入)
    public var events: Int16
    /// 返回的事件 (输出)
    public var revents: Int16

    public init(fd: Int64, events: Int16) {
        this.fd = fd
        this.events = events
        this.revents = 0
    }

    /// 创建可读轮询
    public static func readable(fd: Int64): PollFd {
        return PollFd(fd, PollEvents.POLLIN)
    }

    /// 创建可写轮询
    public static func writable(fd: Int64): PollFd {
        return PollFd(fd, PollEvents.POLLOUT)
    }

    /// 创建读写轮询
    public static func readWritable(fd: Int64): PollFd {
        return PollFd(fd, PollEvents.POLLIN | PollEvents.POLLOUT)
    }

    /// 返回事件中是否有 POLLIN
    public func hasReadable(): Bool {
        return (revents & PollEvents.POLLIN) != 0
    }

    /// 返回事件中是否有 POLLOUT
    public func hasWritable(): Bool {
        return (revents & PollEvents.POLLOUT) != 0
    }

    /// 返回事件中是否有 POLLERR
    public func hasError(): Bool {
        return (revents & PollEvents.POLLERR) != 0
    }

    /// 返回事件中是否有 POLLHUP
    public func hasHangup(): Bool {
        return (revents & PollEvents.POLLHUP) != 0
    }

    /// 返回事件中是否有 POLLNVAL
    public func hasInvalid(): Bool {
        return (revents & PollEvents.POLLNVAL) != 0
    }

    /// 是否有任何返回事件
    public func hasEvents(): Bool {
        return revents != 0
    }

    /// 重置返回事件
    public func reset(): Unit {
        revents = 0
    }
}

// ============================================================================
// PollResult - poll 结果
// ============================================================================

/// poll 操作结果
public class PollResult {
    /// 就绪的文件描述符数量
    public var readyCount: Int64
    /// 是否被信号中断
    public var interrupted: Bool
    /// 是否超时
    public var timedOut: Bool
    /// 错误 (如果有)
    public var error: ?SysError

    public init(readyCount: Int64) {
        this.readyCount = readyCount
        this.interrupted = false
        this.timedOut = false
        this.error = None
    }

    public static func interrupted(): PollResult {
        let r = PollResult(0)
        r.interrupted = true
        return r
    }

    public static func timedOut(): PollResult {
        let r = PollResult(0)
        r.timedOut = true
        return r
    }

    public static func error(err: SysError): PollResult {
        let r = PollResult(0)
        r.error = Some(err)
        return r
    }

    /// 是否成功
    public func isOk(): Bool {
        return error == None
    }
}

// ============================================================================
// SysPoll - poll 系统调用封装
// 严格翻译自: POSIX poll() + Bun io.Loop 中的 poll 逻辑
//   src/io/io.zig 使用 epoll/kqueue 替代 poll
//   仓颉提供 poll() 作为跨平台后备方案
// ============================================================================

/// poll 系统调用封装 - 对应 POSIX poll()
/// 提供简单的文件描述符事件等待
public class SysPoll {
    /// 轮询一组文件描述符
    /// 对应: poll(fds, nfds, timeout)
    /// timeoutMs: -1 = 无限等待, 0 = 立即返回, >0 = 超时毫秒数
    /// 返回就绪的 FD 数量
    public static func poll(fds: Array<PollFd>, timeoutMs: Int64): PollResult {
        if (fds.size == 0) {
            return PollResult(0)
        }
        // 计算 struct pollfd 数组大小: 每个元素 8 字节 (int + short + short + padding)
        let pollfdSize = 8
        unsafe {
            let bufSize = UIntNative(fds.size * pollfdSize)
            let buf = malloc(bufSize)
            // 构造 pollfd 数组
            for (i in 0..fds.size) {
                let base = CPointer<Int32>(buf) + IntNative(i * 2)  // 每个元素 2 个 int32
                // fd 字段
                base.write(Int32(fds[Int64(i)].fd))
                // events 字段 (offset 4)
                (base + IntNative(1)).write(Int32(fds[Int64(i)].events))
            }

            let rc = poll(buf, UIntNative(fds.size), Int32(timeoutMs))

            if (rc < 0) {
                free(buf)
                let errNum = OS.errno()
                if (errNum == 4) {
                    // EINTR - 被信号中断
                    return PollResult.interrupted()
                }
                return PollResult.error(SysError(UInt16(errNum), SysTag.Poll))
            }

            // 解析结果
            var readyCount: Int64 = 0
            for (i in 0..fds.size) {
                let base = CPointer<Int32>(buf) + IntNative(i * 2)
                // revents 字段 (offset 6, 但读取 offset 4+2 = 需要 short)
                // 简化: 读取第二对 int32 的低 16 位
                let reventsRaw = (base + IntNative(1)).read()
                fds[Int64(i)].revents = Int16(reventsRaw >> 16)
                if (fds[Int64(i)].hasEvents()) {
                    readyCount += 1
                }
            }

            free(buf)
            let result = PollResult(readyCount)
            if (rc == 0 && readyCount == 0) {
                result.timedOut = true
            }
            return result
        }
    }

    /// 轮询单个文件描述符 (等待可读)
    /// 对应 Bun: 等待 fd 变为可读状态
    public static func pollReadable(fd: Int64, timeoutMs: Int64): PollResult {
        let fds = [PollFd.readable(fd)]
        return poll(fds, timeoutMs)
    }

    /// 轮询单个文件描述符 (等待可写)
    /// 对应 Bun: 等待 fd 变为可写状态
    public static func pollWritable(fd: Int64, timeoutMs: Int64): PollResult {
        let fds = [PollFd.writable(fd)]
        return poll(fds, timeoutMs)
    }

    /// 非阻塞检查 fd 是否可读
    public static func isReadable(fd: Int64): Bool {
        let result = pollReadable(fd, 0)
        return result.isOk() && result.readyCount > 0
    }

    /// 非阻塞检查 fd 是否可写
    public static func isWritable(fd: Int64): Bool {
        let result = pollWritable(fd, 0)
        return result.isOk() && result.readyCount > 0
    }
}

// ============================================================================
// PollerBuilder - Poller 构建器
// 严格翻译自: Bun io.Loop 的配置逻辑
// ============================================================================

/// Poller 构建器 - 配置 poll 行为
/// 支持选择触发模式和缓冲区大小
public class PollerBuilder {
    /// 触发模式 - 默认水平触发
    public var triggerMode: TriggerMode
    /// 是否使用 one-shot 模式
    public var oneShot: Bool
    /// 最大事件数
    public var maxEvents: Int64

    public init() {
        triggerMode = TriggerMode.LevelTriggered
        oneShot = false
        maxEvents = 64
    }

    /// 设置边沿触发模式
    /// 对应 epoll: EPOLLET
    public func edgeTriggered(): PollerBuilder {
        triggerMode = TriggerMode.EdgeTriggered
        return this
    }

    /// 设置水平触发模式
    public func levelTriggered(): PollerBuilder {
        triggerMode = TriggerMode.LevelTriggered
        return this
    }

    /// 设置 one-shot 模式
    /// 对应 epoll: EPOLLONESHOT - 事件触发后需重新注册
    public func withOneShot(): PollerBuilder {
        oneShot = true
        return this
    }

    /// 设置最大事件数
    public func withMaxEvents(max: Int64): PollerBuilder {
        maxEvents = max
        return this
    }

    /// 构建 epoll 事件标志
    /// 对应 Bun: Poll.Flags.registerForEpoll 中的标志组合
    public func buildEpollEvents(base: UInt32): UInt32 {
        var events = base
        if (triggerMode == TriggerMode.EdgeTriggered) {
            events = events | UInt32(Int32(EpollEvents.EPOLLET))
        }
        if (oneShot) {
            events = events | UInt32(Int32(EpollEvents.EPOLLONESHOT))
        }
        return events
    }
}

// ============================================================================
// Edge-triggered vs Level-triggered 辅助说明
// 严格翻译自: Bun io.Loop 中对 ET/LT 模式的使用
//
// Level-triggered (LT, 默认):
//   - 只要有数据可读/可写，每次 poll/epoll_wait 都会返回
//   - 不需要一次性读完所有数据，部分读取安全
//   - 适合大多数场景，编程模型简单
//
// Edge-triggered (ET):
//   - 只在状态从"无数据"变为"有数据"时通知一次
//   - 必须在回调中循环读取直到 EAGAIN
//   - 更高效但编程更复杂
//   - Bun 中 waker FD 使用 ET 模式:
//     io.zig:41: epoll.events = EPOLL.IN | EPOLL.ET | EPOLL.ERR | EPOLL.HUP
//
// One-shot:
//   - 事件触发一次后自动禁用，需手动重新注册
//   - Bun 的 io.Loop 使用 one-shot 防止重复触发:
//     io.zig:572: const one_shot_flag = EV.ONESHOT
// ============================================================================

/// 触发模式辅助 - 对应 Bun io.Loop 中的 ET/LT 处理
public class TriggerModeHelper {
    /// 边沿触发模式下的完整读取
    /// 在 ET 模式中必须循环读取直到 EAGAIN
    /// 对应 Bun: ReadFile.onReady() 中的循环读取
    public static func readAllEt(fd: Int64, buf: Array<UInt8>): SysMaybe<Int64> {
        var totalRead: Int64 = 0
        var remaining = buf
        while (true) {
            let chunk = Array<UInt8>(8192, item: UInt8(0))
            match (SysFs.read(fd, chunk)) {
                case Err(e) =>
                    // EAGAIN 表示暂无更多数据 - ET 模式下这是正常的
                    if (e.isRetry()) {
                        return SysMaybe<Int64>.Ok(totalRead)
                    }
                    return SysMaybe<Int64>.Err(e)
                case Ok(n) =>
                    if (n == 0) {
                        // EOF
                        return SysMaybe<Int64>.Ok(totalRead)
                    }
                    // 复制到输出缓冲区
                    for (i in 0..n) {
                        if (totalRead + i < buf.size) {
                            buf[totalRead + i] = chunk[i]
                        }
                    }
                    totalRead += n
                    if (totalRead >= buf.size) {
                        return SysMaybe<Int64>.Ok(totalRead)
                    }
            }
        }
    }

    /// 水平触发模式下的单次读取
    /// LT 模式中读取一次即可，下次 poll 会再次通知
    public static func readOnceLt(fd: Int64, buf: Array<UInt8>): SysMaybe<Int64> {
        return SysFs.read(fd, buf)
    }
}
