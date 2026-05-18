// 严格翻译自: src/sys/SignalCode.rs
//   POSIX signal codes - 信号代码
//   Bun: #[repr(transparent)] pub struct SignalCode(pub u8)
//   Zig: enum(u8) { SIGHUP=1, SIGINT=2, ..., SIGSYS=31, _ }
package bao_sys

import bao_core.*

/// POSIX 信号代码 - 严格对应 Bun SignalCode
/// Bun: transparent newtype wrapping u8, 非穷尽枚举
/// 所有信号编号对应 POSIX 标准值
public class SignalCode {
    public let value: UInt8

    public init(value: UInt8) {
        this.value = value
    }

    // POSIX 信号常量
    public static let SIGHUP: SignalCode = SignalCode(1)
    public static let SIGINT: SignalCode = SignalCode(2)
    public static let SIGQUIT: SignalCode = SignalCode(3)
    public static let SIGILL: SignalCode = SignalCode(4)
    public static let SIGTRAP: SignalCode = SignalCode(5)
    public static let SIGABRT: SignalCode = SignalCode(6)
    public static let SIGBUS: SignalCode = SignalCode(7)
    public static let SIGFPE: SignalCode = SignalCode(8)
    public static let SIGKILL: SignalCode = SignalCode(9)
    public static let SIGUSR1: SignalCode = SignalCode(10)
    public static let SIGSEGV: SignalCode = SignalCode(11)
    public static let SIGUSR2: SignalCode = SignalCode(12)
    public static let SIGPIPE: SignalCode = SignalCode(13)
    public static let SIGALRM: SignalCode = SignalCode(14)
    public static let SIGTERM: SignalCode = SignalCode(15)
    public static let SIGCHLD: SignalCode = SignalCode(17)
    public static let SIGCONT: SignalCode = SignalCode(18)
    public static let SIGSTOP: SignalCode = SignalCode(19)
    public static let SIGTSTP: SignalCode = SignalCode(20)
    public static let SIGTTIN: SignalCode = SignalCode(21)
    public static let SIGTTOU: SignalCode = SignalCode(22)
    public static let SIGURG: SignalCode = SignalCode(23)
    public static let SIGXCPU: SignalCode = SignalCode(24)
    public static let SIGXFSZ: SignalCode = SignalCode(25)
    public static let SIGVTALRM: SignalCode = SignalCode(26)
    public static let SIGPROF: SignalCode = SignalCode(27)
    public static let SIGWINCH: SignalCode = SignalCode(28)
    public static let SIGIO: SignalCode = SignalCode(29)
    public static let SIGPWR: SignalCode = SignalCode(30)
    public static let SIGSYS: SignalCode = SignalCode(31)

    /// 默认信号 - subprocess.kill() 无参数时发送此信号
    public static let DEFAULT: SignalCode = SignalCode.SIGTERM

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
    /// SignalCode.rs:26-30
    public func name(): ?String {
        let v = Int64(value)
        if (v >= 1 && v <= 31) {
            return SignalCode.SIGNAL_NAMES[v]
        }
        return None
    }

    /// 是否为有效信号
    public func valid(): Bool {
        return Int64(value) <= Int64(SignalCode.SIGSYS.value) &&
               Int64(value) >= Int64(SignalCode.SIGHUP.value)
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
        match (value) {
            case SignalCode.SIGHUP.value => "Terminal hung up"
            case SignalCode.SIGINT.value => "Quit request"
            case SignalCode.SIGQUIT.value => "Quit request"
            case SignalCode.SIGILL.value => "Illegal instruction"
            case SignalCode.SIGTRAP.value => "Trace or breakpoint trap"
            case SignalCode.SIGABRT.value => "Abort"
            case SignalCode.SIGBUS.value => "Misaligned address error"
            case SignalCode.SIGFPE.value => "Floating point exception"
            case SignalCode.SIGKILL.value => "Forced quit"
            case SignalCode.SIGUSR1.value => "User defined signal 1"
            case SignalCode.SIGUSR2.value => "User defined signal 2"
            case SignalCode.SIGSEGV.value => "Address boundary error"
            case SignalCode.SIGPIPE.value => "Broken pipe"
            case SignalCode.SIGALRM.value => "Timer expired"
            case SignalCode.SIGTERM.value => "Polite quit request"
            case SignalCode.SIGCHLD.value => "Child process status changed"
            case SignalCode.SIGCONT.value => "Continue previously stopped process"
            case SignalCode.SIGSTOP.value => "Forced stop"
            case SignalCode.SIGTSTP.value => "Stop request from job control (^Z)"
            case SignalCode.SIGTTIN.value => "Stop from terminal input"
            case SignalCode.SIGTTOU.value => "Stop from terminal output"
            case SignalCode.SIGURG.value => "Urgent socket condition"
            case SignalCode.SIGXCPU.value => "CPU time limit exceeded"
            case SignalCode.SIGXFSZ.value => "File size limit exceeded"
            case SignalCode.SIGVTALRM.value => "Virtual timer expired"
            case SignalCode.SIGPROF.value => "Profiling timer expired"
            case SignalCode.SIGWINCH.value => "Window size change"
            case SignalCode.SIGIO.value => "I/O on asynchronous file descriptor is possible"
            case SignalCode.SIGSYS.value => "Bad system call"
            case SignalCode.SIGPWR.value => "Power failure"
            case _ => None
        }
    }

    /// 从任意值构造
    public static func fromInt(value: Int32): SignalCode {
        return SignalCode(UInt8(value & 0xFF))
    }

    /// 从信号名称解析
    public static func fromName(name: String): ?SignalCode {
        var searchName = name
        if (searchName.startsWith("SIG")) {
            searchName = searchName.substring(3)
        }
        match (searchName) {
            case "HUP" => SignalCode.SIGHUP
            case "INT" => SignalCode.SIGINT
            case "QUIT" => SignalCode.SIGQUIT
            case "ILL" => SignalCode.SIGILL
            case "TRAP" => SignalCode.SIGTRAP
            case "ABRT" => SignalCode.SIGABRT
            case "BUS" => SignalCode.SIGBUS
            case "FPE" => SignalCode.SIGFPE
            case "KILL" => SignalCode.SIGKILL
            case "USR1" => SignalCode.SIGUSR1
            case "SEGV" => SignalCode.SIGSEGV
            case "USR2" => SignalCode.SIGUSR2
            case "PIPE" => SignalCode.SIGPIPE
            case "ALRM" => SignalCode.SIGALRM
            case "TERM" => SignalCode.SIGTERM
            case "CHLD" => SignalCode.SIGCHLD
            case "CONT" => SignalCode.SIGCONT
            case "STOP" => SignalCode.SIGSTOP
            case "TSTP" => SignalCode.SIGTSTP
            case "TTIN" => SignalCode.SIGTTIN
            case "TTOU" => SignalCode.SIGTTOU
            case "URG" => SignalCode.SIGURG
            case "XCPU" => SignalCode.SIGXCPU
            case "XFSZ" => SignalCode.SIGXFSZ
            case "VTALRM" => SignalCode.SIGVTALRM
            case "PROF" => SignalCode.SIGPROF
            case "WINCH" => SignalCode.SIGWINCH
            case "IO" => SignalCode.SIGIO
            case "PWR" => SignalCode.SIGPWR
            case "SYS" => SignalCode.SIGSYS
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
