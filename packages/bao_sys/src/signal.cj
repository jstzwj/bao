// bao_sys - 信号处理
// 严格翻译自: src/sys/SignalCode.zig
//   Bun 定义了完整的 POSIX 信号码枚举
//   每个信号有名称、描述、退出码映射
//   提供 signal() / sigaction() C FFI 绑定
package bao_sys

import bao_core.*

// ============================================================================
// 信号 C FFI 声明
// ============================================================================

@C
foreign func signal(sig: Int32, handler: CPointer<Unit>): CPointer<Unit>
@C
foreign func sigaction(sig: Int32, act: CPointer<Unit>, oact: CPointer<Unit>): Int32
@C
foreign func sigprocmask(how: Int32, set: CPointer<Unit>, oset: CPointer<Unit>): Int32
@C
foreign func sigfillset(set: CPointer<Unit>): Int32
@C
foreign func sigemptyset(set: CPointer<Unit>): Int32
@C
foreign func sigaddset(set: CPointer<Unit>, signum: Int32): Int32
@C
foreign func sigdelset(set: CPointer<Unit>, signum: Int32): Int32
@C
foreign func sigismember(set: CPointer<Unit>, signum: Int32): Int32
@C
foreign func raise(sig: Int32): Int32
@C
foreign func pthread_sigmask(how: Int32, set: CPointer<Unit>, oset: CPointer<Unit>): Int32

// ============================================================================
// SignalCode - 信号码枚举
// 严格翻译自: src/sys/SignalCode.zig:1-33
//   pub const SignalCode = enum(u8) {
//       SIGHUP = 1, SIGINT = 2, SIGQUIT = 3, ...
//   }
// ============================================================================

/// POSIX 信号码 - 严格对应 Bun SignalCode
/// Bun: pub const SignalCode = enum(u8) { SIGHUP=1, SIGINT=2, ... }
/// 每个信号对应 Linux x86_64 上的信号编号
public enum SignalCode {
    | SIGHUP    // 1  - 终端挂断
    | SIGINT    // 2  - 中断 (Ctrl+C)
    | SIGQUIT   // 3  - 退出 (Ctrl+\)
    | SIGILL    // 4  - 非法指令
    | SIGTRAP   // 5  - 跟踪/断点陷阱
    | SIGABRT   // 6  - 进程异常终止
    | SIGBUS    // 7  - 总线错误 (未对齐访问)
    | SIGFPE    // 8  - 浮点异常
    | SIGKILL   // 9  - 强制终止 (不可捕获)
    | SIGUSR1   // 10 - 用户定义信号 1
    | SIGSEGV   // 11 - 段错误
    | SIGUSR2   // 12 - 用户定义信号 2
    | SIGPIPE   // 13 - 管道破裂
    | SIGALRM   // 14 - 定时器超时
    | SIGTERM   // 15 - 终止信号
    | SIGCHLD   // 17 - 子进程状态改变
    | SIGCONT   // 18 - 继续执行 (如果停止)
    | SIGSTOP   // 19 - 停止进程 (不可捕获)
    | SIGTSTP   // 20 - 终端停止 (Ctrl+Z)
    | SIGTTIN   // 21 - 后台进程读终端
    | SIGTTOU   // 22 - 后台进程写终端
    | SIGURG    // 23 - 紧急套接字条件
    | SIGXCPU   // 24 - CPU 时间超限
    | SIGXFSZ   // 25 - 文件大小超限
    | SIGVTALRM // 26 - 虚拟定时器超时
    | SIGPROF   // 27 - 性能分析定时器超时
    | SIGWINCH  // 28 - 终端窗口大小改变
    | SIGIO     // 29 - 异步 I/O 事件
    | SIGPWR    // 30 - 电源故障
    | SIGSYS    // 31 - 错误的系统调用

    /// 默认信号 - 对应 Bun SignalCode.default
    /// Bun: pub const default = SignalCode.SIGTERM
    /// subprocess.kill() 不指定信号时使用 SIGTERM
    public static func defaultSignal(): SignalCode {
        return SignalCode.SIGTERM
    }

    /// 获取信号编号 - 对应 @intFromEnum(SignalCode)
    public func toInt(): Int32 {
        match (this) {
            case SIGHUP => 1
            case SIGINT => 2
            case SIGQUIT => 3
            case SIGILL => 4
            case SIGTRAP => 5
            case SIGABRT => 6
            case SIGBUS => 7
            case SIGFPE => 8
            case SIGKILL => 9
            case SIGUSR1 => 10
            case SIGSEGV => 11
            case SIGUSR2 => 12
            case SIGPIPE => 13
            case SIGALRM => 14
            case SIGTERM => 15
            case SIGCHLD => 17
            case SIGCONT => 18
            case SIGSTOP => 19
            case SIGTSTP => 20
            case SIGTTIN => 21
            case SIGTTOU => 22
            case SIGURG => 23
            case SIGXCPU => 24
            case SIGXFSZ => 25
            case SIGVTALRM => 26
            case SIGPROF => 27
            case SIGWINCH => 28
            case SIGIO => 29
            case SIGPWR => 30
            case SIGSYS => 31
        }
    }

    /// 从整数值创建 - 对应 @enumFromInt(SignalCode)
    public static func fromInt(v: Int32): ?SignalCode {
        match (v) {
            case 1 => SIGHUP
            case 2 => SIGINT
            case 3 => SIGQUIT
            case 4 => SIGILL
            case 5 => SIGTRAP
            case 6 => SIGABRT
            case 7 => SIGBUS
            case 8 => SIGFPE
            case 9 => SIGKILL
            case 10 => SIGUSR1
            case 11 => SIGSEGV
            case 12 => SIGUSR2
            case 13 => SIGPIPE
            case 14 => SIGALRM
            case 15 => SIGTERM
            case 17 => SIGCHLD
            case 18 => SIGCONT
            case 19 => SIGSTOP
            case 20 => SIGTSTP
            case 21 => SIGTTIN
            case 22 => SIGTTOU
            case 23 => SIGURG
            case 24 => SIGXCPU
            case 25 => SIGXFSZ
            case 26 => SIGVTALRM
            case 27 => SIGPROF
            case 28 => SIGWINCH
            case 29 => SIGIO
            case 30 => SIGPWR
            case 31 => SIGSYS
            case _ => None
        }
    }

    /// 获取信号名称 - 对应 Bun SignalCode.name()
    /// Bun: pub fn name(value: SignalCode) ?[]const u8 { return @tagName(value) }
    public func name(): String {
        match (this) {
            case SIGHUP => "SIGHUP"
            case SIGINT => "SIGINT"
            case SIGQUIT => "SIGQUIT"
            case SIGILL => "SIGILL"
            case SIGTRAP => "SIGTRAP"
            case SIGABRT => "SIGABRT"
            case SIGBUS => "SIGBUS"
            case SIGFPE => "SIGFPE"
            case SIGKILL => "SIGKILL"
            case SIGUSR1 => "SIGUSR1"
            case SIGSEGV => "SIGSEGV"
            case SIGUSR2 => "SIGUSR2"
            case SIGPIPE => "SIGPIPE"
            case SIGALRM => "SIGALRM"
            case SIGTERM => "SIGTERM"
            case SIGCHLD => "SIGCHLD"
            case SIGCONT => "SIGCONT"
            case SIGSTOP => "SIGSTOP"
            case SIGTSTP => "SIGTSTP"
            case SIGTTIN => "SIGTTIN"
            case SIGTTOU => "SIGTTOU"
            case SIGURG => "SIGURG"
            case SIGXCPU => "SIGXCPU"
            case SIGXFSZ => "SIGXFSZ"
            case SIGVTALRM => "SIGVTALRM"
            case SIGPROF => "SIGPROF"
            case SIGWINCH => "SIGWINCH"
            case SIGIO => "SIGIO"
            case SIGPWR => "SIGPWR"
            case SIGSYS => "SIGSYS"
        }
    }

    /// 获取信号描述 - 对应 Bun SignalCode.description()
    /// Bun: pub fn description(signal: SignalCode) ?[]const u8 { ... }
    /// 描述文本来自 fish shell: https://github.com/fish-shell/fish-shell
    public func description(): String {
        match (this) {
            case SIGHUP => "Terminal hung up"
            case SIGINT => "Quit request"
            case SIGQUIT => "Quit request"
            case SIGILL => "Illegal instruction"
            case SIGTRAP => "Trace or breakpoint trap"
            case SIGABRT => "Abort"
            case SIGBUS => "Misaligned address error"
            case SIGFPE => "Floating point exception"
            case SIGKILL => "Forced quit"
            case SIGUSR1 => "User defined signal 1"
            case SIGUSR2 => "User defined signal 2"
            case SIGSEGV => "Address boundary error"
            case SIGPIPE => "Broken pipe"
            case SIGALRM => "Timer expired"
            case SIGTERM => "Polite quit request"
            case SIGCHLD => "Child process status changed"
            case SIGCONT => "Continue previously stopped process"
            case SIGSTOP => "Forced stop"
            case SIGTSTP => "Stop request from job control (^Z)"
            case SIGTTIN => "Stop from terminal input"
            case SIGTTOU => "Stop from terminal output"
            case SIGURG => "Urgent socket condition"
            case SIGXCPU => "CPU time limit exceeded"
            case SIGXFSZ => "File size limit exceeded"
            case SIGVTALRM => "Virtual timer expired"
            case SIGPROF => "Profiling timer expired"
            case SIGWINCH => "Window size change"
            case SIGIO => "I/O on async file descriptor is possible"
            case SIGPWR => "Power failure"
            case SIGSYS => "Bad system call"
        }
    }

    /// 转换为退出码 - 对应 Bun SignalCode.toExitCode()
    /// Bun: pub fn toExitCode(value: SignalCode) ?u8 { return 128 +% @intFromEnum(value) }
    /// Shell 约定: 退出码 = 128 + 信号编号
    public func toExitCode(): Int32 {
        return 128 + toInt()
    }

    /// 是否有效 - 对应 Bun SignalCode.valid()
    /// Bun: pub fn valid(value) bool { return @intFromEnum(value) >= 1 and @intFromEnum(value) <= 31 }
    public func isValid(): Bool {
        let n = toInt()
        return n >= 1 && n <= 31
    }

    /// 是否可以捕获
    /// SIGKILL 和 SIGSTOP 不能被捕获、阻塞或忽略
    public func isCatchable(): Bool {
        match (this) {
            case SIGKILL => false
            case SIGSTOP => false
            case _ => true
        }
    }

    /// 是否是终止信号
    /// 这些信号默认行为是终止进程
    public func isTerminating(): Bool {
        match (this) {
            case SIGHUP => true
            case SIGINT => true
            case SIGQUIT => true
            case SIGILL => true
            case SIGABRT => true
            case SIGBUS => true
            case SIGFPE => true
            case SIGKILL => true
            case SIGSEGV => true
            case SIGPIPE => true
            case SIGALRM => true
            case SIGTERM => true
            case SIGUSR1 => true
            case SIGUSR2 => true
            case _ => false
        }
    }
}

// ============================================================================
// 信号处理常量
// ============================================================================

/// sigprocmask 操作常量
public class SigMaskHow {
    public static let SIG_BLOCK: Int32 = 0
    public static let SIG_UNBLOCK: Int32 = 1
    public static let SIG_SETMASK: Int32 = 2
}

/// SIG_DFL / SIG_IGN 常量
public class SigHandler {
    /// 默认处理
    public static let SIG_DFL: Int64 = 0
    /// 忽略信号
    public static let SIG_IGN: Int64 = 1
    /// 错误
    public static let SIG_ERR: Int64 = -1
}

// ============================================================================
// SignalHandler - 信号处理器
// 严格翻译自: Bun 对 signal/sigaction 的使用
// ============================================================================

/// 信号处理器注册 - 对应 Bun 的信号注册模式
/// Bun 在主进程中注册 SIGINT/SIGTERM 处理器实现优雅关闭
public class SignalHandler {
    /// 注册信号处理回调
    /// 对应: signal(sig, handler)
    public static func register(sig: SignalCode, handler: (SignalCode) -> Unit): SysMaybe<Unit> {
        if (!sig.isCatchable()) {
            return SysMaybe<Unit>.Err(
                SysError(22, SysTag.Signal, "Cannot catch ${sig.name()}")
            )
        }
        // 注意: 仓颉无法直接将闭包传递给 C signal handler
        // 实际实现需要通过全局注册表 + C 桥接函数
        // 这里简化为记录回调
        SignalRegistry.register(sig, handler)
        return SysMaybe<Unit>.Ok(())
    }

    /// 忽略信号
    /// 对应: signal(sig, SIG_IGN)
    public static func ignore(sig: SignalCode): SysMaybe<Unit> {
        if (!sig.isCatchable()) {
            return SysMaybe<Unit>.Err(
                SysError(22, SysTag.Signal, "Cannot ignore ${sig.name()}")
            )
        }
        unsafe {
            let result = signal(sig.toInt(), CPointer<Unit>(Int64(SigHandler.SIG_IGN)))
            if (result == CPointer<Unit>(Int64(SigHandler.SIG_ERR))) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Signal)
                )
            }
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 恢复默认处理
    /// 对应: signal(sig, SIG_DFL)
    public static func restoreDefault(sig: SignalCode): SysMaybe<Unit> {
        unsafe {
            let result = signal(sig.toInt(), CPointer<Unit>(Int64(SigHandler.SIG_DFL)))
            if (result == CPointer<Unit>(Int64(SigHandler.SIG_ERR))) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Signal)
                )
            }
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 向当前进程发送信号
    /// 对应: raise(sig)
    public static func raise(sig: SignalCode): SysMaybe<Unit> {
        let rc = raise(sig.toInt())
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UInt16(Int64(OS.errno())), SysTag.Signal)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 屏蔽信号
    /// 对应: pthread_sigmask(SIG_BLOCK, &set, NULL)
    public static func block(signals: Array<SignalCode>): SysMaybe<Unit> {
        unsafe {
            let set = malloc(UIntNative(128))  // sigset_t 大小足够
            sigemptyset(set)
            for (sig in signals) {
                sigaddset(set, sig.toInt())
            }
            let rc = pthread_sigmask(SigMaskHow.SIG_BLOCK, set, CPointer<Unit>())
            free(set)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Signal)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 解除屏蔽
    /// 对应: pthread_sigmask(SIG_UNBLOCK, &set, NULL)
    public static func unblock(signals: Array<SignalCode>): SysMaybe<Unit> {
        unsafe {
            let set = malloc(UIntNative(128))
            sigemptyset(set)
            for (sig in signals) {
                sigaddset(set, sig.toInt())
            }
            let rc = pthread_sigmask(SigMaskHow.SIG_UNBLOCK, set, CPointer<Unit>())
            free(set)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Signal)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }
}

// ============================================================================
// SignalRegistry - 信号回调注册表
// 全局注册表用于将 C 信号处理桥接到仓颉回调
// ============================================================================

/// 信号回调注册表 - 全局单例
/// 将信号编号映射到仓颉回调函数
public class SignalRegistry {
    /// 全局信号回调表
    private static var handlers: HashMap<Int32, (SignalCode) -> Unit> = HashMap<Int32, (SignalCode) -> Unit>()

    /// 注册回调
    public static func register(sig: SignalCode, handler: (SignalCode) -> Unit): Unit {
        handlers.put(sig.toInt(), handler)
    }

    /// 取消注册
    public static func unregister(sig: SignalCode): Unit {
        handlers.remove(sig.toInt())
    }

    /// 分发信号 (由 C 桥接调用)
    public static func dispatch(sigNum: Int32): Unit {
        let handler = handlers.get(sigNum)
        if (let Some(h) = handler) {
            let sig = SignalCode.fromInt(sigNum)
            if (let Some(s) = sig) {
                h(s)
            }
        }
    }

    /// 清除所有回调
    public static func clear(): Unit {
        handlers.clear()
    }
}
