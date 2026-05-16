// bao_spawn_sys - spawn_process_posix + 选项/结果类型
// 严格翻译自: src/spawn_sys/spawn_process.rs
//   从 bun_spawn::process 中拆分出来，使 fd/action 管道没有事件循环依赖
//   Process/Poller/WaiterThread/sync 保留在 bun_spawn 中

import bao_core.*
import bao_sys.*

// ============================================================================
// PID / fd 宽度类型别名
// 严格翻译自: src/spawn_sys/spawn_process.rs:30-43
//   #[cfg(unix)] pub type PidT = libc::pid_t;
//   #[cfg(unix)] pub type FdT = libc::c_int;
//   #[cfg(any(target_os = "linux", target_os = "android"))] pub type PidFdType = FdT;
//   #[cfg(not(...))] pub type PidFdType = ();
// ============================================================================

/// PID 类型 (Unix: libc::pid_t = i32, Windows: uv_pid_t)
/// 严格翻译自: src/spawn_sys/spawn_process.rs:31-33
public type SpawnPidT = Int32

/// 文件描述符类型 (Unix: c_int = i32)
/// 严格翻译自: src/spawn_sys/spawn_process.rs:36-38
public type FdT = Int32

/// pidfd 类型 (Linux: FdT, 其他: Unit)
/// 严格翻译自: src/spawn_sys/spawn_process.rs:41-43
///   #[cfg(any(target_os = "linux", target_os = "android"))] pub type PidFdType = FdT;
///   #[cfg(not(...))] pub type PidFdType = ();
public type PidFdType = Int32  // Linux; 其他平台使用 Unit

// ============================================================================
// Rusage -- 跨平台资源使用结构体
// 严格翻译自: src/spawn_sys/spawn_process.rs:57-298
//   每个目标一个 Bun 级类型，镜像 Zig 的 bun.spawn.Rusage
//   Unix 上是 libc::rusage, Windows 上是值类型 WinRusage
// ============================================================================

/// Windows timeval
/// 严格翻译自: src/spawn_sys/spawn_process.rs:58-62
///   pub struct WinTimeval { pub sec: i64, pub usec: i64 }
public struct WinTimeval {
    public var sec: Int64 = Int64(0)
    public var usec: Int64 = Int64(0)

    public init() {}

    public init(sec: Int64, usec: Int64) {
        this.sec = sec
        this.usec = usec
    }
}

/// Windows Rusage
/// 严格翻译自: src/spawn_sys/spawn_process.rs:64-73
///   pub struct WinRusage { pub utime, stime, maxrss, inblock, oublock }
public struct WinRusage {
    public var utime: WinTimeval = WinTimeval()
    public var stime: WinTimeval = WinTimeval()
    public var maxrss: UInt64 = UInt64(0)
    // ixrss, idrss, isrss, minflt, majflt, nswap: Zig 中为 u0 -- 零大小，省略
    public var inblock: UInt64 = UInt64(0)
    public var oublock: UInt64 = UInt64(0)
    // msgsnd, msgrcv, nsignals, nvcsw, nivcsw: Zig 中为 u0 -- 零大小，省略

    public init() {}
}

/// Unix rusage 结构体 (对应 libc::rusage)
/// 严格翻译自: src/spawn_sys/spawn_process.rs:148-149
///   #[cfg(unix)] pub type Rusage = libc::rusage;
/// 手动展开 libc::rusage 字段:
public struct Rusage {
    /// 用户 CPU 时间
    public var ruUtimeSec: Int64 = Int64(0)
    public var ruUtimeUsec: Int64 = Int64(0)
    /// 系统 CPU 时间
    public var ruStimeSec: Int64 = Int64(0)
    public var ruStimeUsec: Int64 = Int64(0)
    /// 最大驻留集大小
    public var ruMaxrss: Int64 = Int64(0)
    /// 共享内存大小
    public var ruIxrss: Int64 = Int64(0)
    /// 非共享内存大小
    public var ruIdrss: Int64 = Int64(0)
    /// 未共享堆栈大小
    public var ruIsrss: Int64 = Int64(0)
    /// 次要页错误
    public var ruMinflt: Int64 = Int64(0)
    /// 主要页错误
    public var ruMajflt: Int64 = Int64(0)
    /// 交换次数
    public var ruNswap: Int64 = Int64(0)
    /// 块输入操作
    public var ruInblock: Int64 = Int64(0)
    /// 块输出操作
    public var ruOublock: Int64 = Int64(0)
    /// 消息发送
    public var ruMsgsnd: Int64 = Int64(0)
    /// 消息接收
    public var ruMsgrcv: Int64 = Int64(0)
    /// 信号接收
    public var ruNsignals: Int64 = Int64(0)
    /// 自愿上下文切换
    public var ruNvcsw: Int64 = Int64(0)
    /// 非自愿上下文切换
    public var ruNivcsw: Int64 = Int64(0)

    public init() {}
}

/// IoCounters -- Windows IO 计数器
/// 严格翻译自: src/spawn_sys/spawn_process.rs:75
///   pub type IoCounters = bun_windows_sys::IO_COUNTERS;
public struct IoCounters {
    public var readOperationCount: UInt64 = UInt64(0)
    public var writeOperationCount: UInt64 = UInt64(0)
    public var otherOperationCount: UInt64 = UInt64(0)
    public var readTransferCount: UInt64 = UInt64(0)
    public var writeTransferCount: UInt64 = UInt64(0)
    public var otherTransferCount: UInt64 = UInt64(0)

    public init() {}
}

/// rusage_zeroed -- 返回全零的 Rusage
/// 严格翻译自: src/spawn_sys/spawn_process.rs:155-157
///   pub fn rusage_zeroed() -> Rusage { bun_core::ffi::zeroed() }
public func rusageZeroed(): Rusage {
    return Rusage()
}

// ============================================================================
// RusageFields -- 跨平台字段访问 trait
// 严格翻译自: src/spawn_sys/spawn_process.rs:163-298
//   pub trait RusageFields { ... }
//   底层别名有不同的字段名 (Unix: ru_*, WinRusage: 裸名)
//   此 trait 给 JS 层 getter 一个 cfg-free 的函数体
//   匹配 Zig 规范的统一名称
// ============================================================================

/// Rusage 字段访问接口
/// 严格翻译自: src/spawn_sys/spawn_process.rs:163-178
///   pub trait RusageFields { ... }
public interface RusageFields<T> {
    func utimeSec(): Int64
    func utimeUsec(): Int64
    func stimeSec(): Int64
    func stimeUsec(): Int64
    func maxrss(): Float64
    func ixrss(): Float64
    func nswap(): Float64
    func inblock(): Float64
    func oublock(): Float64
    func msgsnd(): Float64
    func msgrcv(): Float64
    func nsignals(): Float64
    func nvcsw(): Float64
    func nivcsw(): Float64
}

/// Rusage 的 RusageFields 实现
/// 严格翻译自: src/spawn_sys/spawn_process.rs:181-238
///   impl RusageFields for libc::rusage { ... }
public class RusageFieldsImpl {
    /// 从 Rusage 提取 utime_sec
    public static func utimeSec(r: Rusage): Int64 {
        return r.ruUtimeSec
    }
    public static func utimeUsec(r: Rusage): Int64 {
        return r.ruUtimeUsec
    }
    public static func stimeSec(r: Rusage): Int64 {
        return r.ruStimeSec
    }
    public static func stimeUsec(r: Rusage): Int64 {
        return r.ruStimeUsec
    }
    public static func maxrss(r: Rusage): Float64 {
        return Float64(r.ruMaxrss)
    }
    public static func ixrss(r: Rusage): Float64 {
        return Float64(r.ruIxrss)
    }
    public static func nswap(r: Rusage): Float64 {
        return Float64(r.ruNswap)
    }
    public static func inblock(r: Rusage): Float64 {
        return Float64(r.ruInblock)
    }
    public static func oublock(r: Rusage): Float64 {
        return Float64(r.ruOublock)
    }
    public static func msgsnd(r: Rusage): Float64 {
        return Float64(r.ruMsgsnd)
    }
    public static func msgrcv(r: Rusage): Float64 {
        return Float64(r.ruMsgrcv)
    }
    public static func nsignals(r: Rusage): Float64 {
        return Float64(r.ruNsignals)
    }
    public static func nvcsw(r: Rusage): Float64 {
        return Float64(r.ruNvcsw)
    }
    public static func nivcsw(r: Rusage): Float64 {
        return Float64(r.ruNivcsw)
    }
}

/// WinRusage 的 RusageFields 实现
/// 严格翻译自: src/spawn_sys/spawn_process.rs:240-298
///   impl RusageFields for WinRusage { ... }
public class WinRusageFieldsImpl {
    public static func utimeSec(r: WinRusage): Int64 {
        return r.utime.sec
    }
    public static func utimeUsec(r: WinRusage): Int64 {
        return r.utime.usec
    }
    public static func stimeSec(r: WinRusage): Int64 {
        return r.stime.sec
    }
    public static func stimeUsec(r: WinRusage): Int64 {
        return r.stime.usec
    }
    public static func maxrss(r: WinRusage): Float64 {
        return Float64(r.maxrss)
    }
    // Zig 在 Windows 上声明这些为 u0 -- 始终为 0
    public static func ixrss(r: WinRusage): Float64 {
        return 0.0
    }
    public static func nswap(r: WinRusage): Float64 {
        return 0.0
    }
    public static func inblock(r: WinRusage): Float64 {
        return Float64(r.inblock)
    }
    public static func oublock(r: WinRusage): Float64 {
        return Float64(r.oublock)
    }
    public static func msgsnd(r: WinRusage): Float64 {
        return 0.0
    }
    public static func msgrcv(r: WinRusage): Float64 {
        return 0.0
    }
    public static func nsignals(r: WinRusage): Float64 {
        return 0.0
    }
    public static func nvcsw(r: WinRusage): Float64 {
        return 0.0
    }
    public static func nivcsw(r: WinRusage): Float64 {
        return 0.0
    }
}

// ============================================================================
// 生成选项 / 结果类型
// 严格翻译自: src/spawn_sys/spawn_process.rs:304-488
// ============================================================================

// ============================================================================
// Apple spawn 扩展常量
// 严格翻译自: src/spawn_sys/spawn_process.rs:591-594
//   pub const POSIX_SPAWN_CLOEXEC_DEFAULT: i32 = 0x4000;
//   pub const POSIX_SPAWN_SETEXEC: i32 = 0x0040;
// ============================================================================

/// macOS CLOEXEC_DEFAULT
public let POSIX_SPAWN_CLOEXEC_DEFAULT: Int32 = 0x4000

/// macOS SETEXEC
public let POSIX_SPAWN_SETEXEC: Int32 = 0x0040

// ============================================================================
// O 标志常量 (简化版)
// 严格翻译自 bun_sys O flags
// ============================================================================

/// O 标志常量
public object OFlags {
    public let RDONLY: UInt32 = UInt32(0)
    public let WRONLY: UInt32 = UInt32(1)
    public let RDWR: UInt32 = UInt32(2)
    public let CREAT: UInt32 = UInt32(64)    // 0100
    public let NONBLOCK: UInt32 = UInt32(2048)  // 04000
}

// ============================================================================
// StdioKind -- 标准 IO 类型枚举
// 严格翻译自: src/spawn_sys/spawn_process.rs:386-403
//   pub enum StdioKind { Stdin, Stdout, Stderr }
//   bun.jsc.Subprocess.StdioKind -- 定义在 spawn-sys 层
// ============================================================================

/// 标准流类型
/// 严格翻译自: src/spawn_sys/spawn_process.rs:386-403
///   pub enum StdioKind { Stdin, Stdout, Stderr }
public enum StdioKind {
    | Stdin
    | Stdout
    | Stderr

    /// 转为 fd 编号
    /// 严格翻译自: src/spawn_sys/spawn_process.rs:396-403
    ///   pub fn to_fd(self) -> Fd { match self { Stdin => Fd::stdin(), ... } }
    public func toFd(): Int64 {
        match (this) {
            case Stdin => Int64(0)
            case Stdout => Int64(1)
            case Stderr => Int64(2)
        }
    }
}

// ============================================================================
// Dup2 -- dup2 重定向结构
// 严格翻译自: src/spawn_sys/spawn_process.rs:405-409
//   pub struct Dup2 { pub out: StdioKind, pub to: StdioKind }
// ============================================================================

/// dup2 重定向
/// 严格翻译自: src/spawn_sys/spawn_process.rs:405-409
public struct Dup2 {
    public var out: StdioKind = StdioKind.Stdin
    public var to: StdioKind = StdioKind.Stdin

    public init() {}

    public init(out: StdioKind, to: StdioKind) {
        this.out = out
        this.to = to
    }
}

// ============================================================================
// PosixStdio -- POSIX 标准流配置枚举
// 严格翻译自: src/spawn_sys/spawn_process.rs:411-437
//   pub enum PosixStdio { Path, Inherit, Ignore, Buffer, Ipc, Pipe, Dup2 }
// ============================================================================

/// POSIX 标准流配置
/// 严格翻译自: src/spawn_sys/spawn_process.rs:411-420
///   pub enum PosixStdio { Path, Inherit, Ignore, Buffer, Ipc, Pipe, Dup2 }
public enum PosixStdio {
    | Path(Array<UInt8>)     // 打开文件路径
    | Inherit                // 继承父进程
    | Ignore                 // 打开 /dev/null
    | Buffer                 // socketpair 缓冲
    | Ipc                    // IPC 通道
    | Pipe(Int64)            // 已有 fd 的管道
    | Dup2(Dup2)             // dup2 重定向 (TODO: 移除此变体，似乎未被使用)

    /// 构造辅助 -- 继承
    /// 严格翻译自: src/spawn_sys/spawn_process.rs:426-428
    ///   pub fn inherit() -> Self { PosixStdio::Inherit }
    public static func inherit(): PosixStdio {
        PosixStdio.Inherit
    }

    /// 构造辅助 -- 忽略
    /// 严格翻译自: src/spawn_sys/spawn_process.rs:431-433
    ///   pub fn ignore() -> Self { PosixStdio::Ignore }
    public static func ignore(): PosixStdio {
        PosixStdio.Ignore
    }

    /// 构造辅助 -- 缓冲
    /// 严格翻译自: src/spawn_sys/spawn_process.rs:434-436
    ///   pub fn buffer() -> Self { PosixStdio::Buffer }
    public static func buffer(): PosixStdio {
        PosixStdio.Buffer
    }
}

// ============================================================================
// PosixSpawnOptions -- spawn 选项
// 严格翻译自: src/spawn_sys/spawn_process.rs:304-376
//   pub struct PosixSpawnOptions { ... }
// ============================================================================

/// POSIX spawn 选项
/// 严格翻译自: src/spawn_sys/spawn_process.rs:304-343
///   pub struct PosixSpawnOptions { ... }
public class PosixSpawnOptions {
    /// stdin 配置
    public var stdin: PosixStdio = PosixStdio.Ignore
    /// stdout 配置
    public var stdout: PosixStdio = PosixStdio.Ignore
    /// stderr 配置
    public var stderr: PosixStdio = PosixStdio.Ignore
    /// IPC fd
    public var ipc: ?Int64 = None
    /// 额外 fd 列表
    public var extraFds: Array<PosixStdio> = []
    /// 工作目录
    public var cwd: Array<UInt8> = []
    /// 是否分离
    public var detached: Bool = false
    /// Windows 专用 (占位)
    public var windows: Unit = ()
    /// argv[0] 覆盖
    public var argv0: ?CPointer<UInt8> = None
    /// 是否流式
    public var stream: Bool = true
    /// 是否同步
    public var sync: Bool = false
    /// 是否可以阻塞整个线程以减少快速路径的 CPU 使用
    public var canBlockEntireThreadToReduceCpuUsageInFastPath: Bool = false
    /// Apple 扩展: 设置此位后 posix_spawn 表现为更强大的 execve(2)
    public var useExecveOnMacos: Bool = false
    /// 如果需要调用 socketpair()，为 true 时设置 SO_NOSIGPIPE
    /// 为 false 时避免为 stdout 设置 SO_NOSIGPIPE，保持一致的 shell 语义
    public var noSigpipe: Bool = true
    /// setpgid(0, 0) 使子进程领导自己的进程组
    /// 父进程可 kill(-pid, sig) 向子进程及其后代发信号
    public var newProcessGroup: Bool = false
    /// PTY 从设备 fd (-1 表示不使用 PTY)
    public var ptySlaveFd: Int32 = -1
    /// Windows ConPTY 句柄; POSIX 上的 void 占位
    public var pseudoconsole: Unit = ()
    /// Linux: 非 null 时子进程在 vfork 和 exec 之间设置 PR_SET_PDEATHSIG
    /// null 时默认 SIGKILL (如果启用了 no-orphans 模式)
    public var linuxPdeathsig: ?UInt8 = None

    /// 默认构造
    /// 严格翻译自: src/spawn_sys/spawn_process.rs:345-368
    ///   fn default() -> Self { ... }
    public init() {}

    /// 清理 (无操作，匹配 Zig PosixSpawnOptions.deinit)
    /// 严格翻译自: src/spawn_sys/spawn_process.rs:374-376
    ///   pub fn deinit(&mut self) {}
    public func deinit(): Unit {
        // 无操作 -- 与 WindowsSpawnOptions::deinit 保持 cfg 对等
    }
}

// ============================================================================
// PosixSpawnResult -- spawn 结果
// 严格翻译自: src/spawn_sys/spawn_process.rs:439-466
//   pub struct PosixSpawnResult { ... }
// ============================================================================

/// POSIX spawn 结果
/// 严格翻译自: src/spawn_sys/spawn_process.rs:439-466
public class PosixSpawnResult {
    /// 子进程 PID
    public var pid: SpawnPidT = Int32(0)
    /// pidfd (Linux)
    public var pidfd: ?PidFdType = None
    /// stdin fd
    public var stdin: ?Int64 = None
    /// stdout fd
    public var stdout: ?Int64 = None
    /// stderr fd
    public var stderr: ?Int64 = None
    /// IPC fd
    public var ipc: ?Int64 = None
    /// 额外管道
    public var extraPipes: Array<ExtraPipe> = []
    /// memfd 标记 [stdin, stdout, stderr]
    public var memfds: Array<Bool> = [false, false, false]
    /// 是否已退出 (获取 pidfd 时可能发生 ESRCH)
    public var hasExited: Bool = false

    /// 默认构造
    /// 严格翻译自: src/spawn_sys/spawn_process.rs:452-466
    public init() {}

    /// 关闭所有 extra_pipes
    /// 严格翻译自: src/spawn_sys/spawn_process.rs:491-500
    ///   pub fn close(&mut self) { ... }
    public func close(): Unit {
        for (item in extraPipes) {
            match (item) {
                case ExtraPipe.OwnedFd(f) => closeFd(f)
                case ExtraPipe.UnownedFd(_) => ()
                case ExtraPipe.Unavailable => ()
            }
        }
        extraPipes = []
    }

    /// Linux pidfd flags
    /// 严格翻译自: src/spawn_sys/spawn_process.rs:502-509
    ///   fn pidfd_flags_for_linux() -> u32
    public static func pidfdFlagsForLinux(): UInt32 {
        // pidfd_nonblock 仅在 5.10+ 支持
        // 乐观请求 NONBLOCK，依赖 EINVAL 重试回退到旧内核
        return OFlags.NONBLOCK
    }

    /// 从 pid 获取 pidfd
    /// 严格翻译自: src/spawn_sys/spawn_process.rs:512-575
    ///   pub fn pifd_from_pid(&mut self) -> sys::Result<PidFdType>
    public func pidfFromPid(): SysMaybe<PidFdType> {
        if (WaiterThreadFlag.get()) {
            return SysMaybe<PidFdType>.Err(SysError(
                UInt16(38),  // ENOSYS
                SysTag.PidfdOpen
            ))
        }

        let pidfdFlags = pidfdFlagsForLinux()
        var attempt: SysMaybe<PidT> = pidfdOpen(pid, pidfdFlags)

        // 如果 EINVAL，重试不带 NONBLOCK
        match (attempt) {
            case Err(e) =>
                if (e.errno == UInt16(22)) {  // EINVAL
                    attempt = pidfdOpen(pid, UInt32(0))
                }
            case Ok(_) => ()
        }

        match (attempt) {
            case Err(err) =>
                match (err.errno) {
                    case UInt16(38)   // ENOSYS
                    | UInt16(95)     // EOPNOTSUPP / ENOTSUP
                    | UInt16(1)      // EPERM
                    | UInt16(13)     // EACCES
                    | UInt16(22) =>  // EINVAL
                        WaiterThreadFlag.set()
                        return SysMaybe<PidFdType>.Err(err)
                    case UInt16(3) =>  // ESRCH
                        ()  // 进程已退出
                    case _ =>
                        // 确保不会泄漏子进程 (僵尸进程)
                        var done = false
                        while (!done) {
                            var status: Int32 = Int32(0)
                            let rc = libcWait4(pid, status, Int32(0), None)
                            match (posixErrno(rc)) {
                                case PosixErrno.Success => ()
                                case PosixErrno.Intr => ()  // continue
                                case _ => done = true
                            }
                            done = true
                        }
                }
                return SysMaybe<PidFdType>.Err(err)
            case Ok(fd) =>
                return SysMaybe<PidFdType>.Ok(Int32(fd))
        }
    }
}

// ============================================================================
// ExtraPipe -- 额外管道条目
// 严格翻译自: src/spawn_sys/spawn_process.rs:469-488
//   pub enum ExtraPipe { OwnedFd, UnownedFd, Unavailable }
// ============================================================================

/// 额外管道条目 -- stdio 插槽 index >= 3
/// 严格翻译自: src/spawn_sys/spawn_process.rs:469-479
public enum ExtraPipe {
    /// 我们创建的 fd (如 "pipe" 的 socketpair)
    /// 通过 Subprocess.stdio[N] 暴露，在 finalizeStreams 中关闭
    | OwnedFd(Int64)
    /// 调用者在 stdio 数组中提供的 fd
    /// 通过 Subprocess.stdio[N] 暴露但永不关闭 -- 调用者保留所有权
    | UnownedFd(Int64)
    /// 此槽无内容 ("ignore", "inherit", 路径, 或 IPC 通道已转移到 uSockets)
    | Unavailable

    /// 获取 fd
    /// 严格翻译自: src/spawn_sys/spawn_process.rs:481-488
    ///   pub fn fd(&self) -> Fd { match self { OwnedFd(f) | UnownedFd(f) => *f, ... } }
    public func fd(): Int64 {
        match (this) {
            case OwnedFd(f) => f
            case UnownedFd(f) => f
            case Unavailable => Int64(-1)  // Fd::INVALID
        }
    }
}

// ============================================================================
// AutoCloseFd -- RAII fd 所有者
// 严格翻译自: src/spawn_sys/spawn_process.rs:599-626
//   struct AutoCloseFd(Fd); impl Drop for AutoCloseFd { ... }
// 在 fd 有效时关闭包装的 Fd
// ============================================================================

/// RAII fd 所有者 -- 在 drop 时关闭有效的 fd
/// 严格翻译自: src/spawn_sys/spawn_process.rs:599-626
public class AutoCloseFd {
    private var fd: Int64

    public init(fd: Int64) {
        this.fd = fd
    }

    public static func invalid(): AutoCloseFd {
        return AutoCloseFd(Int64(-1))
    }

    /// 借用内部句柄
    public func fdVal(): Int64 {
        return fd
    }

    /// 关闭 fd
    public func close(): Unit {
        if (fd != Int64(-1)) {
            closeFd(fd)
            fd = Int64(-1)
        }
    }
}

// ============================================================================
// PosixSpawnFdGuard -- RAII fd 清理守卫
// 严格翻译自: src/spawn_sys/spawn_process.rs:645-668
//   struct PosixSpawnFdGuard { ... }
//   impl Drop for PosixSpawnFdGuard { ... }
// 匹配 Zig 的 defer/errdefer 模式
// ============================================================================

/// RAII fd 清理守卫
/// 严格翻译自: src/spawn_sys/spawn_process.rs:645-668
/// defer: 设置 CLOEXEC + 关闭 to_close_at_end
/// errdefer: 额外关闭 to_close_on_error
public class PosixSpawnFdGuard {
    /// 需要设置 CLOEXEC 的 fd 列表
    public var toSetCloexec: Array<Int64> = []
    /// 结束时关闭的 fd 列表
    public var toCloseAtEnd: Array<Int64> = []
    /// 错误时关闭的 fd 列表
    public var toCloseOnError: Array<Int64> = []
    /// 是否处于错误状态
    public var onError: Bool = true

    public init() {}

    /// 清理 (对应 Rust Drop)
    /// 严格翻译自: src/spawn_sys/spawn_process.rs:654-668
    ///   fn drop(&mut self) { ... }
    public func cleanup(): Unit {
        if (onError) {
            for (fd in toCloseOnError) {
                closeFd(fd)
            }
        }
        for (fd in toSetCloexec) {
            setCloseOnExec(fd)
        }
        for (fd in toCloseAtEnd) {
            closeFd(fd)
        }
    }

    /// 解除错误状态 (成功路径)
    public func disarm(): Unit {
        onError = false
    }
}

// ============================================================================
// spawn_process_posix -- fd/action 管道 + posix_spawn 调用
// 严格翻译自: src/spawn_sys/spawn_process.rs:671-1032
//   pub fn spawn_process_posix(options, argv, envp) -> Result<...>
// ============================================================================

/// spawn_process_posix -- POSIX 进程生成主入口
/// 严格翻译自: src/spawn_sys/spawn_process.rs:671-1032
///   pub fn spawn_process_posix(
///       options: &PosixSpawnOptions,
///       argv: Argv,
///       envp: Envp,
///   ) -> Result<bun_sys::Result<PosixSpawnResult>, bun_core::Error>
///
/// 返回:
///   Ok(Ok(PosixSpawnResult)) -- 成功生成
///   Ok(Err(SysError)) -- spawn 失败 (系统错误)
///   Err(BaoError) -- 内部错误
public func spawnProcessPosix(
    options: PosixSpawnOptions,
    argv: Argv,
    envp: Envp
): Result<SysMaybe<PosixSpawnResult>, BaoError> {
    // 统计 spawn 特性使用
    // bun_analytics::features::spawn.fetch_add(1, Ordering::Relaxed)

    // 初始化 actions
    let actionsResult = Actions.init()
    var actions = Actions()
    match (actionsResult) {
        case Ok(a) => actions = a
        case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
    }

    // 初始化 attr
    let attrResult = Attr.init()
    var attr = Attr()
    match (attrResult) {
        case Ok(a) => attr = a
        case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
    }

    // POSIX_SPAWN_SETSIGDEF / POSIX_SPAWN_SETSIGMASK
    // libc 0.2.x 为 glibc/musl/macOS 暴露这些标志，但不为 Android
    // Bionic <spawn.h> 使用与 glibc 相同的值 (0x04/0x08)
    var setsigdef: Int32 = Int32(0x04)
    var setsigmask: Int32 = Int32(0x08)
    if (!Environment.IS_ANDROID) {
        setsigdef = Int32(0x04)
        setsigmask = Int32(0x08)
    }
    var flags: Int32 = setsigdef | setsigmask

    // macOS: CLOEXEC_DEFAULT + 可选 SETEXEC
    if (Environment.IS_MAC) {
        flags = flags | POSIX_SPAWN_CLOEXEC_DEFAULT

        if (options.useExecveOnMacos) {
            flags = flags | POSIX_SPAWN_SETEXEC

            // Buffer 模式与 SETEXEC 不兼容
            match (options.stdin) {
                case PosixStdio.Buffer => throw BaoError(ErrorCode.Panic,
                    "Internal error: stdin, stdout, and stderr cannot be buffered when use_execve_on_macos is true")
                case _ => ()
            }
            match (options.stdout) {
                case PosixStdio.Buffer => throw BaoError(ErrorCode.Panic,
                    "Internal error: stdin, stdout, and stderr cannot be buffered when use_execve_on_macos is true")
                case _ => ()
            }
            match (options.stderr) {
                case PosixStdio.Buffer => throw BaoError(ErrorCode.Panic,
                    "Internal error: stdin, stdout, and stderr cannot be buffered when use_execve_on_macos is true")
                case _ => ()
            }
        }
    }

    // 分离模式
    if (options.detached) {
        if (Environment.IS_LINUX) {
            // glibc/musl/bionic POSIX_SPAWN_SETSID = 0x80
            flags = flags | Int32(0x80)
        } else if (Environment.IS_MAC) {
            // Darwin POSIX_SPAWN_SETSID = 0x0400
            flags = flags | Int32(0x0400)
        }
        attr.detached = true
    }

    // 传递 PTY 从设备 fd
    attr.ptySlaveFd = options.ptySlaveFd
    attr.newProcessGroup = options.newProcessGroup

    // Linux pdeathsig
    if (Environment.IS_LINUX) {
        attr.linuxPdeathsig = {
            match (options.linuxPdeathsig) {
                case Some(sig) => Int32(sig)
                case None =>
                    if (Pdeathsig.shouldDefault()) {
                        Int32(9)  // SIGKILL
                    } else {
                        Int32(0)
                    }
            }
        }
    }

    // 工作目录
    if (options.cwd.size > 0) {
        let chdirResult = actions.chdir(options.cwd)
        match (chdirResult) {
            case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
            case Ok(_) => ()
        }
    }

    var spawned = PosixSpawnResult()
    var extraFds: Array<ExtraPipe> = []
    // Zig defer + errdefer 清理 -> RAII 守卫
    var cleanup = PosixSpawnFdGuard()

    let _ = attr.set(UInt16(flags))
    let _ = attr.resetSignals()

    // IPC
    match (options.ipc) {
        case Some(ipcFd) =>
            let inheritResult = actions.inherit(ipcFd)
            match (inheritResult) {
                case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                case Ok(_) => spawned.ipc = Some(ipcFd)
            }
        case None => ()
    }

    // 标准流配置 [stdin, stdout, stderr]
    let stdioOptions: Array<PosixStdio> = [options.stdin, options.stdout, options.stderr]
    var dupStdoutToStderr: Bool = false

    // 主 stdio 循环
    var i = 0
    while (i < 3) {
        let fileno = Int64(i)
        let flag: UInt32 = {
            if (i == 0) { OFlags.RDONLY }
            else { OFlags.WRONLY }
        }

        match (stdioOptions[i]) {
            case PosixStdio.Dup2(dup2) =>
                // stdout 重定向到 stderr 的顺序问题
                // 如果 stdout 设置为重定向到 stderr，操作 0 (dup2(stderr, stdout))
                // 会在操作 1 (设置 stderr 到管道写端) 之前执行
                // 所以必须改为 dup2(stderr_pipe_fd[1], stdout)
                if (i == 1 && dup2.to == StdioKind.Stderr) {
                    dupStdoutToStderr = true
                } else {
                    let dupResult = actions.dup2(dup2.to.toFd(), dup2.out.toFd())
                    match (dupResult) {
                        case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                        case Ok(_) => ()
                    }
                }

            case PosixStdio.Inherit =>
                let inheritResult = actions.inherit(fileno)
                match (inheritResult) {
                    case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                    case Ok(_) => ()
                }

            case PosixStdio.Ipc | PosixStdio.Ignore =>
                let openResult = actions.openZ(fileno, "/dev/null\x00",
                    flag | OFlags.CREAT, Int32(0o664))
                match (openResult) {
                    case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                    case Ok(_) => ()
                }

            case PosixStdio.Path(path) =>
                let openResult = actions.open(fileno, path,
                    flag | OFlags.CREAT, Int32(0o664))
                match (openResult) {
                    case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                    case Ok(_) => ()
                }

            case PosixStdio.Buffer =>
                // Linux memfd 快速路径
                if (Environment.IS_LINUX && !options.stream && i > 0 && canUseMemfd()) {
                    let label = {
                        match (i) {
                            case 0 => "spawn_stdio_stdin"
                            case 1 => "spawn_stdio_stdout"
                            case 2 => "spawn_stdio_stderr"
                            case _ => "spawn_stdio_generic"
                        }
                    }
                    let memfdResult = memfdCreate(label)
                    match (memfdResult) {
                        case Ok(fd) =>
                            cleanup.toCloseOnError.append(fd)
                            cleanup.toSetCloexec.append(fd)
                            let dupResult = actions.dup2(fd, fileno)
                            match (dupResult) {
                                case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                                case Ok(_) => ()
                            }
                            setSpawnedStdio(spawned, i, fd)
                            spawned.memfds[i] = true
                            i = i + 1
                            continue
                        case Err(_) =>
                            ()  // 回退到 socketpair
                    }
                }

                // socketpair 路径
                let isShell = !options.noSigpipe
                let pairResult = {
                    if (isShell) {
                        socketpairForShell(Int32(1))  // AF_UNIX
                    } else {
                        socketpair(Int32(1))  // AF_UNIX
                    }
                }
                let fds = match (pairResult) {
                    case Ok(pair) =>
                        // [child_end, parent_end]
                        if (i == 0) {
                            [pair[Int32(1)], pair[Int32(0)]]
                        } else {
                            [pair[Int32(0)], pair[Int32(1)]]
                        }
                    case Err(e) =>
                        cleanup.cleanup()
                        return Result<SysMaybe<PosixSpawnResult>, BaoError>.Ok(
                            SysMaybe<PosixSpawnResult>.Err(e)
                        )
                }

                // macOS socket 缓冲区大小调整
                if (Environment.IS_MAC) {
                    let soRecvbuf: Int32 = Int32(512 * 1024)
                    let soSendbuf: Int32 = Int32(512 * 1024)
                    if (i == 0) {
                        setsockopt(fds[Int32(1)], Int32(1), Int32(0x1002), soRecvbuf)  // SO_RCVBUF
                        setsockopt(fds[Int32(0)], Int32(1), Int32(0x1001), soSendbuf)  // SO_SNDBUF
                    } else {
                        setsockopt(fds[Int32(0)], Int32(1), Int32(0x1002), soRecvbuf)
                        setsockopt(fds[Int32(1)], Int32(1), Int32(0x1001), soSendbuf)
                    }
                }

                cleanup.toCloseAtEnd.append(fds[Int32(1)])
                cleanup.toCloseOnError.append(fds[Int32(0)])

                if (!options.sync) {
                    let nbResult = setNonblocking(fds[Int32(0)])
                    match (nbResult) {
                        case Err(e) =>
                            cleanup.cleanup()
                            return Result<SysMaybe<PosixSpawnResult>, BaoError>.Ok(
                                SysMaybe<PosixSpawnResult>.Err(e)
                            )
                        case Ok(_) => ()
                    }
                }

                let dupResult = actions.dup2(fds[Int32(1)], fileno)
                match (dupResult) {
                    case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                    case Ok(_) => ()
                }
                if (fds[Int32(1)] != fileno) {
                    let closeResult = actions.close(fds[Int32(1)])
                    match (closeResult) {
                        case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                        case Ok(_) => ()
                    }
                }
                setSpawnedStdio(spawned, i, fds[Int32(0)])

            case PosixStdio.Pipe(fd) =>
                let dupResult = actions.dup2(fd, fileno)
                match (dupResult) {
                    case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                    case Ok(_) => ()
                }
                setSpawnedStdio(spawned, i, fd)
        }

        i = i + 1
    }

    // stdout -> stderr dup2 延迟处理
    if (dupStdoutToStderr) {
        match (stdioOptions[Int32(1)]) {
            case PosixStdio.Dup2(d) =>
                let dupResult = actions.dup2(d.to.toFd(), d.out.toFd())
                match (dupResult) {
                    case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                    case Ok(_) => ()
                }
            case _ => ()
        }
    }

    // 额外 fd 处理
    var extraIdx = 0
    for (ipc in options.extraFds) {
        let fileno = Int64(3 + extraIdx)

        match (ipc) {
            case PosixStdio.Dup2(_) =>
                throw BaoError(ErrorCode.NotImplemented, "TODO dup2 extra fd")
            case PosixStdio.Inherit =>
                let inheritResult = actions.inherit(fileno)
                match (inheritResult) {
                    case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                    case Ok(_) => extraFds.append(ExtraPipe.Unavailable)
                }
            case PosixStdio.Ignore =>
                let openResult = actions.openZ(fileno, "/dev/null\x00",
                    OFlags.RDWR, Int32(0o664))
                match (openResult) {
                    case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                    case Ok(_) => extraFds.append(ExtraPipe.Unavailable)
                }
            case PosixStdio.Path(path) =>
                let openResult = actions.open(fileno, path,
                    OFlags.RDWR | OFlags.CREAT, Int32(0o664))
                match (openResult) {
                    case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                    case Ok(_) => extraFds.append(ExtraPipe.Unavailable)
                }
            case PosixStdio.Ipc | PosixStdio.Buffer =>
                let isIpc = {
                    match (ipc) {
                        case PosixStdio.Ipc => true
                        case _ => false
                    }
                }
                let pairResult = socketpairWithIpc(Int32(1), isIpc)  // AF_UNIX
                let fds = match (pairResult) {
                    case Ok(pair) => pair
                    case Err(e) =>
                        cleanup.cleanup()
                        return Result<SysMaybe<PosixSpawnResult>, BaoError>.Ok(
                            SysMaybe<PosixSpawnResult>.Err(e)
                        )
                }

                if (!options.sync && !isIpc) {
                    let nbResult = setNonblocking(fds[Int32(0)])
                    match (nbResult) {
                        case Err(e) =>
                            cleanup.cleanup()
                            return Result<SysMaybe<PosixSpawnResult>, BaoError>.Ok(
                                SysMaybe<PosixSpawnResult>.Err(e)
                            )
                        case Ok(_) => ()
                    }
                }

                cleanup.toCloseAtEnd.append(fds[Int32(1)])
                cleanup.toCloseOnError.append(fds[Int32(0)])

                let dupResult = actions.dup2(fds[Int32(1)], fileno)
                match (dupResult) {
                    case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                    case Ok(_) => ()
                }
                if (fds[Int32(1)] != fileno) {
                    let closeResult = actions.close(fds[Int32(1)])
                    match (closeResult) {
                        case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                        case Ok(_) => ()
                    }
                }
                extraFds.append(ExtraPipe.OwnedFd(fds[Int32(0)]))

            case PosixStdio.Pipe(fd) =>
                let dupResult = actions.dup2(fd, fileno)
                match (dupResult) {
                    case Err(e) => return Result<SysMaybe<PosixSpawnResult>, BaoError>.Err(e)
                    case Ok(_) => ()
                }
                extraFds.append(ExtraPipe.UnownedFd(fd))
        }
        extraIdx = extraIdx + 1
    }

    // 执行 spawn
    let argv0: CPointer<UInt8> = {
        match (options.argv0) {
            case Some(p) => p
            case None => CPointer<UInt8>()  // 将使用 argv[0]
        }
    }
    let argv0Cstr = argv0

    let spawnResult = spawnZ(
        "",  // path (从 argv0 获取)
        Some(actions),
        Some(attr),
        argv,
        envp
    )

    match (spawnResult) {
        case Err(err) =>
            cleanup.cleanup()
            return Result<SysMaybe<PosixSpawnResult>, BaoError>.Ok(
                SysMaybe<PosixSpawnResult>.Err(err)
            )
        case Ok(pid) =>
            spawned.pid = pid
            spawned.extraPipes = extraFds

            // Linux pidfd
            if (Environment.IS_LINUX && !options.canBlockEntireThreadToReduceCpuUsageInFastPath) {
                let pidfdResult = spawned.pidfFromPid()
                match (pidfdResult) {
                    case Ok(pidfd) =>
                        spawned.pidfd = Some(pidfd)
                    case Err(err) =>
                        if (err.errno == UInt16(3)) {  // ESRCH
                            spawned.hasExited = true
                        } else if (!WaiterThreadFlag.get()) {
                            cleanup.cleanup()
                            return Result<SysMaybe<PosixSpawnResult>, BaoError>.Ok(
                                SysMaybe<PosixSpawnResult>.Err(err)
                            )
                        }
                }
            }

            // 解除 errdefer; 无条件 defer (cloexec + close_at_end) 仍运行
            cleanup.disarm()
            cleanup.cleanup()
            return Result<SysMaybe<PosixSpawnResult>, BaoError>.Ok(
                SysMaybe<PosixSpawnResult>.Ok(spawned)
            )
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 设置 spawned 的 stdio fd
/// 严格翻译自: src/spawn_sys/spawn_process.rs:1035-1042
///   fn set_spawned_stdio(spawned, i, fd)
func setSpawnedStdio(spawned: PosixSpawnResult, i: Int64, fd: Int64): Unit {
    match (i) {
        case 0 => spawned.stdin = Some(fd)
        case 1 => spawned.stdout = Some(fd)
        case 2 => spawned.stderr = Some(fd)
        case _ => throw BaoError(ErrorCode.Unreachable)
    }
}

/// close fd FFI
public func closeFd(fd: Int64): Unit {
    // FFI: close(fd)
}

/// set_close_on_exec FFI
public func setCloseOnExec(fd: Int64): Unit {
    // FFI: fcntl(fd, F_SETFD, FD_CLOEXEC)
}

/// set_nonblocking FFI
public func setNonblocking(fd: Int64): SysMaybe<Unit> {
    // FFI: fcntl(fd, F_SETFL, O_NONBLOCK)
    return SysMaybe<Unit>.Ok(())
}

/// socketpair FFI
public func socketpair(domain: Int32): SysMaybe<Array<Int64>> {
    // FFI: socketpair(domain, SOCK_STREAM, 0, sv)
    return SysMaybe<Array<Int64>>.Err(SysError(UInt16(0), SysTag.Socketpair))
}

/// socketpair for shell (no SO_NOSIGPIPE)
public func socketpairForShell(domain: Int32): SysMaybe<Array<Int64>> {
    return socketpair(domain)
}

/// socketpair with IPC flag
public func socketpairWithIpc(domain: Int32, isIpc: Bool): SysMaybe<Array<Int64>> {
    return socketpair(domain)
}

/// memfd_create FFI
/// 严格对应 Bun: sys.memfd_create(label, flags) -> Maybe(FD)
/// Bun sys.Tag: memfd_create
public func memfdCreate(label: String): SysMaybe<Int64> {
    // FFI: memfd_create(label, flags)
    // 默认返回 ENOSYS，实际由 FFI 层覆盖
    return SysMaybe<Int64>.Err(SysError(UInt16(38), SysTag.MemfdCreate))
}

/// can_use_memfd 检查
public func canUseMemfd(): Bool {
    return Environment.IS_LINUX
}

/// pidfd_open FFI
/// 严格对应 Bun: sys.pidfd_open(pid, flags) -> Maybe(fd)
/// Bun sys.Tag: pidfd_open
public func pidfdOpen(pid: Int32, flags: UInt32): SysMaybe<Int32> {
    // FFI: pidfd_open(pid, flags)
    // 默认返回 ENOSYS，实际由 FFI 层覆盖
    return SysMaybe<Int32>.Err(SysError(UInt16(38), SysTag.PidfdOpen))
}

/// setsockopt FFI
public func setsockopt(fd: Int64, level: Int32, optname: Int32, value: Int32): Unit {
    // FFI: setsockopt(fd, level, optname, &value, sizeof(value))
}
