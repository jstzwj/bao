// 严格翻译自: src/sys/PosixSignalCode.rs
//   POSIX signal codes - 信号代码
//   Bun: #[repr(transparent)] pub struct PosixSignalCode(pub u8)
//   Zig: enum(u8) { SIGHUP=1, SIGINT=2, ..., SIGSYS=31, _ }
package bao_sys

import bao_core.*

/// POSIX 信号代码 - 严格对应 Bun PosixSignalCode
/// Bun: transparent newtype wrapping u8, 非穷尽枚举
/// 所有信号编号对应 POSIX 标准值
public class PosixSignalCode {
    public let value: UInt8

    public init(value: UInt8) {
        this.value = value
    }

    // POSIX 信号常量
    public static let SIGHUP: PosixSignalCode = PosixSignalCode(1)
    public static let SIGINT: PosixSignalCode = PosixSignalCode(2)
    public static let SIGQUIT: PosixSignalCode = PosixSignalCode(3)
    public static let SIGILL: PosixSignalCode = PosixSignalCode(4)
    public static let SIGTRAP: PosixSignalCode = PosixSignalCode(5)
    public static let SIGABRT: PosixSignalCode = PosixSignalCode(6)
    public static let SIGBUS: PosixSignalCode = PosixSignalCode(7)
    public static let SIGFPE: PosixSignalCode = PosixSignalCode(8)
    public static let SIGKILL: PosixSignalCode = PosixSignalCode(9)
    public static let SIGUSR1: PosixSignalCode = PosixSignalCode(10)
    public static let SIGSEGV: PosixSignalCode = PosixSignalCode(11)
    public static let SIGUSR2: PosixSignalCode = PosixSignalCode(12)
    public static let SIGPIPE: PosixSignalCode = PosixSignalCode(13)
    public static let SIGALRM: PosixSignalCode = PosixSignalCode(14)
    public static let SIGTERM: PosixSignalCode = PosixSignalCode(15)
    public static let SIGCHLD: PosixSignalCode = PosixSignalCode(17)
    public static let SIGCONT: PosixSignalCode = PosixSignalCode(18)
    public static let SIGSTOP: PosixSignalCode = PosixSignalCode(19)
    public static let SIGTSTP: PosixSignalCode = PosixSignalCode(20)
    public static let SIGTTIN: PosixSignalCode = PosixSignalCode(21)
    public static let SIGTTOU: PosixSignalCode = PosixSignalCode(22)
    public static let SIGURG: PosixSignalCode = PosixSignalCode(23)
    public static let SIGXCPU: PosixSignalCode = PosixSignalCode(24)
    public static let SIGXFSZ: PosixSignalCode = PosixSignalCode(25)
    public static let SIGVTALRM: PosixSignalCode = PosixSignalCode(26)
    public static let SIGPROF: PosixSignalCode = PosixSignalCode(27)
    public static let SIGWINCH: PosixSignalCode = PosixSignalCode(28)
    public static let SIGIO: PosixSignalCode = PosixSignalCode(29)
    public static let SIGPWR: PosixSignalCode = PosixSignalCode(30)
    public static let SIGSYS: PosixSignalCode = PosixSignalCode(31)

    /// 默认信号 - subprocess.kill() 无参数时发送此信号
    public static let DEFAULT: PosixSignalCode = PosixSignalCode.SIGTERM

    /// 信号名称数组 - 索引即为信号编号
    public static let SIGNAL_NAMES: Array<String> = [
        "SIGNONE", "SIGHUP", "SIGINT", "SIGQUIT", "SIGILL",
        "SIGTRAP", "SIGABRT", "SIGBUS", "SIGFPE", "SIGKILL",
        "SIGUSR1", "SIGSEGV", "SIGUSR2", "SIGPIPE", "SIGALRM",
        "SIGTERM", "SIGSTKFLT", "SIGCHLD", "SIGCONT", "SIGSTOP",
        "SIGTSTP", "SIGTTIN", "SIGTTOU", "SIGURG", "SIGXCPU",
        "SIGXFSZ", "SIGVTALRM", "SIGPROF", "SIGWINCH", "SIGIO",
        "SIGPWR", "SIGSYS"
    ]

    /// 获取信号名称
    /// PosixSignalCode.rs:26-30
    public func name(): ?String {
        let v = Int64(value)
        if (v >= 1 && v <= 31) {
            return PosixSignalCode.SIGNAL_NAMES[v]
        }
        return None
    }

    /// 是否为有效信号
    public func valid(): Bool {
        return Int64(value) <= Int64(PosixSignalCode.SIGSYS.value) &&
               Int64(value) >= Int64(PosixSignalCode.SIGHUP.value)
    }

    /// 转为退出码 (shell 脚本使用 128 + signal number)
    public func toExitCode(): ?UInt8 {
        let v = Int64(value)
        if (v >= 1 && v <= 31) {
            return UInt8((128 + v) & 0xFF)
        }
        return None
    }

    /// 获取信号描述
    /// 描述名称复制自 fish shell
    public func description(): ?String {
        if (value == PosixSignalCode.SIGHUP.value) { return "Terminal hung up" }
        if (value == PosixSignalCode.SIGINT.value) { return "Quit request" }
        if (value == PosixSignalCode.SIGQUIT.value) { return "Quit request" }
        if (value == PosixSignalCode.SIGILL.value) { return "Illegal instruction" }
        if (value == PosixSignalCode.SIGTRAP.value) { return "Trace or breakpoint trap" }
        if (value == PosixSignalCode.SIGABRT.value) { return "Abort" }
        if (value == PosixSignalCode.SIGBUS.value) { return "Misaligned address error" }
        if (value == PosixSignalCode.SIGFPE.value) { return "Floating point exception" }
        if (value == PosixSignalCode.SIGKILL.value) { return "Forced quit" }
        if (value == PosixSignalCode.SIGUSR1.value) { return "User defined signal 1" }
        if (value == PosixSignalCode.SIGUSR2.value) { return "User defined signal 2" }
        if (value == PosixSignalCode.SIGSEGV.value) { return "Address boundary error" }
        if (value == PosixSignalCode.SIGPIPE.value) { return "Broken pipe" }
        if (value == PosixSignalCode.SIGALRM.value) { return "Timer expired" }
        if (value == PosixSignalCode.SIGTERM.value) { return "Polite quit request" }
        if (value == PosixSignalCode.SIGCHLD.value) { return "Child process status changed" }
        if (value == PosixSignalCode.SIGCONT.value) { return "Continue previously stopped process" }
        if (value == PosixSignalCode.SIGSTOP.value) { return "Forced stop" }
        if (value == PosixSignalCode.SIGTSTP.value) { return "Stop request from job control (^Z)" }
        if (value == PosixSignalCode.SIGTTIN.value) { return "Stop from terminal input" }
        if (value == PosixSignalCode.SIGTTOU.value) { return "Stop from terminal output" }
        if (value == PosixSignalCode.SIGURG.value) { return "Urgent socket condition" }
        if (value == PosixSignalCode.SIGXCPU.value) { return "CPU time limit exceeded" }
        if (value == PosixSignalCode.SIGXFSZ.value) { return "File size limit exceeded" }
        if (value == PosixSignalCode.SIGVTALRM.value) { return "Virtual timer expired" }
        if (value == PosixSignalCode.SIGPROF.value) { return "Profiling timer expired" }
        if (value == PosixSignalCode.SIGWINCH.value) { return "Window size change" }
        if (value == PosixSignalCode.SIGIO.value) { return "I/O on asynchronous file descriptor is possible" }
        if (value == PosixSignalCode.SIGSYS.value) { return "Bad system call" }
        if (value == PosixSignalCode.SIGPWR.value) { return "Power failure" }
        return None
    }

    /// 从任意值构造
    public static func fromInt(value: Int32): PosixSignalCode {
        return PosixSignalCode(UInt8(value & 0xFF))
    }

    /// 从信号名称解析
    public static func fromName(name: String): ?PosixSignalCode {
        match (name) {
            case "HUP" | "SIGHUP" => PosixSignalCode.SIGHUP
            case "INT" | "SIGINT" => PosixSignalCode.SIGINT
            case "QUIT" | "SIGQUIT" => PosixSignalCode.SIGQUIT
            case "ILL" | "SIGILL" => PosixSignalCode.SIGILL
            case "TRAP" | "SIGTRAP" => PosixSignalCode.SIGTRAP
            case "ABRT" | "SIGABRT" => PosixSignalCode.SIGABRT
            case "BUS" | "SIGBUS" => PosixSignalCode.SIGBUS
            case "FPE" | "SIGFPE" => PosixSignalCode.SIGFPE
            case "KILL" | "SIGKILL" => PosixSignalCode.SIGKILL
            case "USR1" | "SIGUSR1" => PosixSignalCode.SIGUSR1
            case "SEGV" | "SIGSEGV" => PosixSignalCode.SIGSEGV
            case "USR2" | "SIGUSR2" => PosixSignalCode.SIGUSR2
            case "PIPE" | "SIGPIPE" => PosixSignalCode.SIGPIPE
            case "ALRM" | "SIGALRM" => PosixSignalCode.SIGALRM
            case "TERM" | "SIGTERM" => PosixSignalCode.SIGTERM
            case "CHLD" | "SIGCHLD" => PosixSignalCode.SIGCHLD
            case "CONT" | "SIGCONT" => PosixSignalCode.SIGCONT
            case "STOP" | "SIGSTOP" => PosixSignalCode.SIGSTOP
            case "TSTP" | "SIGTSTP" => PosixSignalCode.SIGTSTP
            case "TTIN" | "SIGTTIN" => PosixSignalCode.SIGTTIN
            case "TTOU" | "SIGTTOU" => PosixSignalCode.SIGTTOU
            case "URG" | "SIGURG" => PosixSignalCode.SIGURG
            case "XCPU" | "SIGXCPU" => PosixSignalCode.SIGXCPU
            case "XFSZ" | "SIGXFSZ" => PosixSignalCode.SIGXFSZ
            case "VTALRM" | "SIGVTALRM" => PosixSignalCode.SIGVTALRM
            case "PROF" | "SIGPROF" => PosixSignalCode.SIGPROF
            case "WINCH" | "SIGWINCH" => PosixSignalCode.SIGWINCH
            case "IO" | "SIGIO" => PosixSignalCode.SIGIO
            case "PWR" | "SIGPWR" => PosixSignalCode.SIGPWR
            case "SYS" | "SIGSYS" => PosixSignalCode.SIGSYS
            case _ => None
        }
    }

    /// 格式化输出 (带可选 ANSI 颜色)
    public func format(enableAnsiColors: Bool): String {
        match (name()) {
            case Some(sigName) =>
                match (description()) {
                    case Some(desc) =>
                        if (enableAnsiColors) {
                            "${sigName} [2m(${desc})[0m"
                        } else {
                            "${sigName} (${desc})"
                        }
                    case None => sigName
                }
            case None => "code ${Int64(value)}"
        }
    }

    public func toString(): String {
        return format(false)
    }
}
