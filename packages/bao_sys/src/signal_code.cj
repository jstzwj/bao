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
        match (value) {
            case PosixSignalCode.SIGHUP.value => "Terminal hung up"
            case PosixSignalCode.SIGINT.value => "Quit request"
            case PosixSignalCode.SIGQUIT.value => "Quit request"
            case PosixSignalCode.SIGILL.value => "Illegal instruction"
            case PosixSignalCode.SIGTRAP.value => "Trace or breakpoint trap"
            case PosixSignalCode.SIGABRT.value => "Abort"
            case PosixSignalCode.SIGBUS.value => "Misaligned address error"
            case PosixSignalCode.SIGFPE.value => "Floating point exception"
            case PosixSignalCode.SIGKILL.value => "Forced quit"
            case PosixSignalCode.SIGUSR1.value => "User defined signal 1"
            case PosixSignalCode.SIGUSR2.value => "User defined signal 2"
            case PosixSignalCode.SIGSEGV.value => "Address boundary error"
            case PosixSignalCode.SIGPIPE.value => "Broken pipe"
            case PosixSignalCode.SIGALRM.value => "Timer expired"
            case PosixSignalCode.SIGTERM.value => "Polite quit request"
            case PosixSignalCode.SIGCHLD.value => "Child process status changed"
            case PosixSignalCode.SIGCONT.value => "Continue previously stopped process"
            case PosixSignalCode.SIGSTOP.value => "Forced stop"
            case PosixSignalCode.SIGTSTP.value => "Stop request from job control (^Z)"
            case PosixSignalCode.SIGTTIN.value => "Stop from terminal input"
            case PosixSignalCode.SIGTTOU.value => "Stop from terminal output"
            case PosixSignalCode.SIGURG.value => "Urgent socket condition"
            case PosixSignalCode.SIGXCPU.value => "CPU time limit exceeded"
            case PosixSignalCode.SIGXFSZ.value => "File size limit exceeded"
            case PosixSignalCode.SIGVTALRM.value => "Virtual timer expired"
            case PosixSignalCode.SIGPROF.value => "Profiling timer expired"
            case PosixSignalCode.SIGWINCH.value => "Window size change"
            case PosixSignalCode.SIGIO.value => "I/O on asynchronous file descriptor is possible"
            case PosixSignalCode.SIGSYS.value => "Bad system call"
            case PosixSignalCode.SIGPWR.value => "Power failure"
            case _ => None
        }
    }

    /// 从任意值构造
    public static func fromInt(value: Int32): PosixSignalCode {
        return PosixSignalCode(UInt8(value & 0xFF))
    }

    /// 从信号名称解析
    public static func fromName(name: String): ?PosixSignalCode {
        var searchName = name
        if (searchName.startsWith("SIG")) {
            searchName = searchName.substring(3)
        }
        match (searchName) {
            case "HUP" => PosixSignalCode.SIGHUP
            case "INT" => PosixSignalCode.SIGINT
            case "QUIT" => PosixSignalCode.SIGQUIT
            case "ILL" => PosixSignalCode.SIGILL
            case "TRAP" => PosixSignalCode.SIGTRAP
            case "ABRT" => PosixSignalCode.SIGABRT
            case "BUS" => PosixSignalCode.SIGBUS
            case "FPE" => PosixSignalCode.SIGFPE
            case "KILL" => PosixSignalCode.SIGKILL
            case "USR1" => PosixSignalCode.SIGUSR1
            case "SEGV" => PosixSignalCode.SIGSEGV
            case "USR2" => PosixSignalCode.SIGUSR2
            case "PIPE" => PosixSignalCode.SIGPIPE
            case "ALRM" => PosixSignalCode.SIGALRM
            case "TERM" => PosixSignalCode.SIGTERM
            case "CHLD" => PosixSignalCode.SIGCHLD
            case "CONT" => PosixSignalCode.SIGCONT
            case "STOP" => PosixSignalCode.SIGSTOP
            case "TSTP" => PosixSignalCode.SIGTSTP
            case "TTIN" => PosixSignalCode.SIGTTIN
            case "TTOU" => PosixSignalCode.SIGTTOU
            case "URG" => PosixSignalCode.SIGURG
            case "XCPU" => PosixSignalCode.SIGXCPU
            case "XFSZ" => PosixSignalCode.SIGXFSZ
            case "VTALRM" => PosixSignalCode.SIGVTALRM
            case "PROF" => PosixSignalCode.SIGPROF
            case "WINCH" => PosixSignalCode.SIGWINCH
            case "IO" => PosixSignalCode.SIGIO
            case "PWR" => PosixSignalCode.SIGPWR
            case "SYS" => PosixSignalCode.SIGSYS
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
