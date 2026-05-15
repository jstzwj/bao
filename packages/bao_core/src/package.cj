// bao_core - 核心类型和原语
// 严格翻译自: src/bun_core/lib.rs, src/bun_core/result.rs, src/bun_core/env.rs
// 以及 src/bun.zig 中的 Environment, Global 等模块
// 以及 src/string/ 下的字符串类型
package bao_core

// ============================================================================
// Error - 错误码系统
// 严格翻译自: src/bun_core/result.rs - Error struct
// Bun 使用 NonZeroU16 表示全局唯一错误码，通过名称驻留(intern)
// 仓颉使用异常体系，此处提供兼容的 Error + ErrorName 映射
// ============================================================================

/// 全局错误码 - 对应 Bun Error(NonZeroU16)
/// Bun 通过进程级名称表实现错误码驻留，每个错误名称对应唯一 u16
/// 仓颉通过 enum + 名称映射实现等价语义
public enum ErrorCode {
    | Unexpected       // 1  - Zig catch-all, errno_map default
    | OutOfMemory      // 2
    | EndOfStream      // 3
    | StreamTooLong    // 4
    | NoSpaceLeft      // 5
    | WriteFailed      // 6
    | Overflow         // 7
    | InvalidArgument  // 8
    | Timeout          // 9
    | Aborted          // 10
    | WouldBlock       // 11

    // POSIX errno 标签 (对应 Bun SEED 表索引 12-45)
    | EPERM            // 12
    | ENOENT           // 13
    | ESRCH            // 14
    | EINTR            // 15
    | EIO              // 16
    | ENXIO            // 17
    | E2BIG            // 18
    | ENOEXEC          // 19
    | EBADF            // 20
    | ECHILD           // 21
    | EAGAIN           // 22
    | ENOMEM           // 23
    | EACCES           // 24
    | EFAULT           // 25
    | ENOTBLK          // 26
    | EBUSY            // 27
    | EEXIST           // 28
    | EXDEV            // 29
    | ENODEV           // 30
    | ENOTDIR          // 31
    | EISDIR           // 32
    | EINVAL           // 33
    | ENFILE           // 34
    | EMFILE           // 35
    | ENOTTY           // 36
    | ETXTBSY          // 37
    | EFBIG            // 38
    | ENOSPC           // 39
    | ESPIPE           // 40
    | EROFS            // 41
    | EMLINK           // 42
    | EPIPE            // 43
    | EDOM             // 44
    | ERANGE           // 45

    // 扩展错误码
    | ParseError
    | BundlerError
    | StackOverflow
    | Unknown

    /// 转为 u16 编码 (对应 Bun Error.as_u16)
    public func toU16(): UInt16 {
        match (this) {
            case Unexpected => UInt16(1)
            case OutOfMemory => UInt16(2)
            case EndOfStream => UInt16(3)
            case StreamTooLong => UInt16(4)
            case NoSpaceLeft => UInt16(5)
            case WriteFailed => UInt16(6)
            case Overflow => UInt16(7)
            case InvalidArgument => UInt16(8)
            case Timeout => UInt16(9)
            case Aborted => UInt16(10)
            case WouldBlock => UInt16(11)
            case EPERM => UInt16(12)
            case ENOENT => UInt16(13)
            case ESRCH => UInt16(14)
            case EINTR => UInt16(15)
            case EIO => UInt16(16)
            case ENXIO => UInt16(17)
            case E2BIG => UInt16(18)
            case ENOEXEC => UInt16(19)
            case EBADF => UInt16(20)
            case ECHILD => UInt16(21)
            case EAGAIN => UInt16(22)
            case ENOMEM => UInt16(23)
            case EACCES => UInt16(24)
            case EFAULT => UInt16(25)
            case ENOTBLK => UInt16(26)
            case EBUSY => UInt16(27)
            case EEXIST => UInt16(28)
            case EXDEV => UInt16(29)
            case ENODEV => UInt16(30)
            case ENOTDIR => UInt16(31)
            case EISDIR => UInt16(32)
            case EINVAL => UInt16(33)
            case ENFILE => UInt16(34)
            case EMFILE => UInt16(35)
            case ENOTTY => UInt16(36)
            case ETXTBSY => UInt16(37)
            case EFBIG => UInt16(38)
            case ENOSPC => UInt16(39)
            case ESPIPE => UInt16(40)
            case EROFS => UInt16(41)
            case EMLINK => UInt16(42)
            case EPIPE => UInt16(43)
            case EDOM => UInt16(44)
            case ERANGE => UInt16(45)
            case ParseError => UInt16(100)
            case BundlerError => UInt16(252)
            case StackOverflow => UInt16(253)
            case Unknown => UInt16(0)
        }
    }

    /// 获取错误名称 (对应 Bun Error.name → @errorName)
    public func name(): String {
        match (this) {
            case Unexpected => "Unexpected"
            case OutOfMemory => "OutOfMemory"
            case EndOfStream => "EndOfStream"
            case StreamTooLong => "StreamTooLong"
            case NoSpaceLeft => "NoSpaceLeft"
            case WriteFailed => "WriteFailed"
            case Overflow => "Overflow"
            case InvalidArgument => "InvalidArgument"
            case Timeout => "Timeout"
            case Aborted => "Aborted"
            case WouldBlock => "WouldBlock"
            case EPERM => "EPERM"
            case ENOENT => "ENOENT"
            case ESRCH => "ESRCH"
            case EINTR => "EINTR"
            case EIO => "EIO"
            case ENXIO => "ENXIO"
            case E2BIG => "E2BIG"
            case ENOEXEC => "ENOEXEC"
            case EBADF => "EBADF"
            case ECHILD => "ECHILD"
            case EAGAIN => "EAGAIN"
            case ENOMEM => "ENOMEM"
            case EACCES => "EACCES"
            case EFAULT => "EFAULT"
            case ENOTBLK => "ENOTBLK"
            case EBUSY => "EBUSY"
            case EEXIST => "EEXIST"
            case EXDEV => "EXDEV"
            case ENODEV => "ENODEV"
            case ENOTDIR => "ENOTDIR"
            case EISDIR => "EISDIR"
            case EINVAL => "EINVAL"
            case ENFILE => "ENFILE"
            case EMFILE => "EMFILE"
            case ENOTTY => "ENOTTY"
            case ETXTBSY => "ETXTBSY"
            case EFBIG => "EFBIG"
            case ENOSPC => "ENOSPC"
            case ESPIPE => "ESPIPE"
            case EROFS => "EROFS"
            case EMLINK => "EMLINK"
            case EPIPE => "EPIPE"
            case EDOM => "EDOM"
            case ERANGE => "ERANGE"
            case ParseError => "ParseError"
            case BundlerError => "BundlerError"
            case StackOverflow => "StackOverflow"
            case Unknown => "Unknown"
        }
    }

    /// 从 u16 构建 (对应 Bun Error.from_raw)
    public static func fromRaw(code: UInt16): ErrorCode {
        match (code) {
            case UInt16(1) => Unexpected
            case UInt16(2) => OutOfMemory
            case UInt16(3) => EndOfStream
            case UInt16(4) => StreamTooLong
            case UInt16(5) => NoSpaceLeft
            case UInt16(6) => WriteFailed
            case UInt16(7) => Overflow
            case UInt16(8) => InvalidArgument
            case UInt16(9) => Timeout
            case UInt16(10) => Aborted
            case UInt16(11) => WouldBlock
            case UInt16(12) => EPERM
            case UInt16(13) => ENOENT
            case UInt16(14) => ESRCH
            case UInt16(15) => EINTR
            case UInt16(16) => EIO
            case UInt16(17) => ENXIO
            case UInt16(18) => E2BIG
            case UInt16(19) => ENOEXEC
            case UInt16(20) => EBADF
            case UInt16(21) => ECHILD
            case UInt16(22) => EAGAIN
            case UInt16(23) => ENOMEM
            case UInt16(24) => EACCES
            case UInt16(25) => EFAULT
            case UInt16(26) => ENOTBLK
            case UInt16(27) => EBUSY
            case UInt16(28) => EEXIST
            case UInt16(29) => EXDEV
            case UInt16(30) => ENODEV
            case UInt16(31) => ENOTDIR
            case UInt16(32) => EISDIR
            case UInt16(33) => EINVAL
            case UInt16(34) => ENFILE
            case UInt16(35) => EMFILE
            case UInt16(36) => ENOTTY
            case UInt16(37) => ETXTBSY
            case UInt16(38) => EFBIG
            case UInt16(39) => ENOSPC
            case UInt16(40) => ESPIPE
            case UInt16(41) => EROFS
            case UInt16(42) => EMLINK
            case UInt16(43) => EPIPE
            case UInt16(44) => EDOM
            case UInt16(45) => ERANGE
            case UInt16(100) => ParseError
            case UInt16(252) => BundlerError
            case UInt16(253) => StackOverflow
            case _ => Unexpected  // 0 → Unexpected, 与 Bun 一致
        }
    }

    /// 从 POSIX errno 映射 (对应 Bun Error.from_errno)
    public static func fromErrno(errno: Int64): ErrorCode {
        match (errno) {
            case 1 => EPERM
            case 2 => ENOENT
            case 3 => ESRCH
            case 4 => EINTR
            case 5 => EIO
            case 6 => ENXIO
            case 7 => E2BIG
            case 8 => ENOEXEC
            case 9 => EBADF
            case 10 => ECHILD
            case 11 => EAGAIN
            case 12 => ENOMEM
            case 13 => EACCES
            case 14 => EFAULT
            case 15 => ENOTBLK
            case 16 => EBUSY
            case 17 => EEXIST
            case 18 => EXDEV
            case 19 => ENODEV
            case 20 => ENOTDIR
            case 21 => EISDIR
            case 22 => EINVAL
            case 23 => ENFILE
            case 24 => EMFILE
            case 25 => ENOTTY
            case 26 => ETXTBSY
            case 27 => EFBIG
            case 28 => ENOSPC
            case 29 => ESPIPE
            case 30 => EROFS
            case 31 => EMLINK
            case 32 => EPIPE
            case 33 => EDOM
            case 34 => ERANGE
            case _ => Unexpected
        }
    }
}

/// POSIX 错误消息表 (对应 Bun coreutils_error_map::BASE)
/// 严格翻译自 src/bun_core/result.rs 中的 phf::phf_map!
public func posixErrorMessage(errno: Int64): String {
    match (errno) {
        case 1 => "Operation not permitted"
        case 2 => "No such file or directory"
        case 3 => "No such process"
        case 4 => "Interrupted system call"
        case 5 => "Input/output error"
        case 6 => "No such device or address"
        case 7 => "Argument list too long"
        case 8 => "Exec format error"
        case 9 => "Bad file descriptor"
        case 10 => "No child processes"
        case 11 => "Resource temporarily unavailable"
        case 12 => "Cannot allocate memory"
        case 13 => "Permission denied"
        case 14 => "Bad address"
        case 15 => "Block device required"
        case 16 => "Device or resource busy"
        case 17 => "File exists"
        case 18 => "Invalid cross-device link"
        case 19 => "No such device"
        case 20 => "Not a directory"
        case 21 => "Is a directory"
        case 22 => "Invalid argument"
        case 23 => "Too many open files in system"
        case 24 => "Too many open files"
        case 25 => "Inappropriate ioctl for device"
        case 26 => "Text file busy"
        case 27 => "File too large"
        case 28 => "No space left on device"
        case 29 => "Illegal seek"
        case 30 => "Read-only file system"
        case 31 => "Too many links"
        case 32 => "Broken pipe"
        case 33 => "Numerical argument out of domain"
        case 34 => "Numerical result out of range"
        case 35 => "Resource deadlock avoided"
        case 36 => "File name too long"
        case 37 => "No locks available"
        case 38 => "Function not implemented"
        case 39 => "Directory not empty"
        case 40 => "Too many levels of symbolic links"
        case _ => "Unknown error (${errno})"
    }
}

// ============================================================================
// BaoError - 异常基类
// 对应 Bun Error + std.io.Error 的组合
// ============================================================================

/// 核心错误异常
public open class BaoError <: Exception {
    public let code: ErrorCode
    public let errnoValue: Int64

    public init(code: ErrorCode) {
        this.code = code
        this.errnoValue = 0
        super(code.name())
    }

    public init(code: ErrorCode, message: String) {
        this.code = code
        this.errnoValue = 0
        super(message)
    }

    public init(errno: Int64) {
        this.code = ErrorCode.fromErrno(errno)
        this.errnoValue = errno
        super(posixErrorMessage(errno))
    }

    public init(errno: Int64, message: String) {
        this.code = ErrorCode.fromErrno(errno)
        this.errnoValue = errno
        super(message)
    }
}

// ============================================================================
// 基础类型别名
// 对应 Bun: src/paths/paths.zig, src/bun.zig 类型导出
// ============================================================================

/// 文件描述符 - 对应 Bun bun_sys::fd::FD
public type Fd = Int64

/// 文件偏移量
public type FileOffset = Int64

/// 文件大小
public type FileSize = UInt64

/// 端口号
public type Port = UInt16

/// 平台路径字符类型 (Linux: UInt8, Windows: UInt16)
/// 对应 Bun: OSPathChar = if (Environment.isWindows) u16 else u8
public type OSPathChar = UInt8

/// 最大路径长度 - 对应 Bun MAX_PATH_BYTES
public let MAX_PATH_BYTES: Int64 = 4096

/// 版本号字符串 - 对应 Bun package_json_version
public let BAO_VERSION = "0.1.0"

/// User-Agent 字符串 - 对应 Bun Global.user_agent
public let USER_AGENT = "Bao/${BAO_VERSION}"

// ============================================================================
// 压缩流状态机
// 对应 Bun: bun_core::compress::State
// ============================================================================

/// 压缩流状态 - 严格翻译自 bun_core/compress
public enum CompressState {
    | Uninitialized
    | Inflating
    | End
    | Error
}

// ============================================================================
// 平台和架构
// 对应 Bun: src/bun_core/env.zig - Environment
// ============================================================================

/// 操作系统类型 - 对应 Bun Environment.os
public enum Platform {
    | Linux
    | MacOS
    | Windows
    | Unknown
}

/// CPU 架构 - 对应 Bun Environment.arch
public enum Arch {
    | X86_64
    | ARM64
    | X86
    | Unknown
}

/// 获取当前平台
public func currentPlatform(): Platform {
    return Platform.Linux
}

/// 获取当前架构
public func currentArch(): Arch {
    return Arch.X86_64
}

// ============================================================================
// Global - 全局工具
// 对应 Bun: src/bun_core/Global.zig
// ============================================================================

/// 全局工具类
public class Global {
    public static let package_json_version = BAO_VERSION
    public static let user_agent = USER_AGENT

    /// 包含检查 - 对应 Bun bun::contains
    public static func contains<T>(item: T, list: Array<T>): Bool where T <: Equatable<T> {
        for (elem in list) {
            if (elem == item) {
                return true
            }
        }
        return false
    }
}

// ============================================================================
// 工具函数
// ============================================================================

/// 安全退出 - 对应 Bun Global.exit
public func exit(code: Int64): Nothing {
    std.process.exit(Int32(code))
}

/// 栈溢出检查 - 对应 Bun throw_stack_overflow
public func throwStackOverflow(): Result<Unit> {
    return Result<Unit>.Err(BaoError(ErrorCode.StackOverflow))
}

// ============================================================================
// 字符串类型导出
// 严格翻译自: src/string/string.zig (模块导出)
//   pub const HashedString = @import("./HashedString.zig");
//   pub const MutableString = @import("./MutableString.zig");
//   pub const PathString = @import("./PathString.zig").PathString;
//   pub const SmolStr = @import("./SmolStr.zig").SmolStr;
//   pub const StringBuilder = @import("./StringBuilder.zig");
//   pub const StringJoiner = @import("./StringJoiner.zig");
// ============================================================================

// 重导出字符串类型 (这些类型在各 .cj 文件中定义)

/// 带哈希字符串视图 - 对应 Bun HashedString
/// 严格翻译自: src/string/HashedString.zig
/// 用于需要频繁比较的字符串 (标识符查找、属性名匹配)
// HashedStringView 在 hashed_string.cj 中定义

/// 小字符串优化 - 对应 Bun SmolStr
/// 严格翻译自: src/string/SmolStr.zig
/// <=22 字节内联存储, >22 字节自动降级为堆存储
// SmolStr 在 smol_str.cj 中定义

/// 路径字符串视图 - 对应 Bun PathString
/// 严格翻译自: src/string/PathString.zig
/// 轻量级路径视图, 零拷贝借用
// PathStringView 在 path_string.cj 中定义

/// 可变字符串 - 对应 Bun MutableString
/// 严格翻译自: src/string/MutableString.zig
/// 动态增长的可变字节缓冲区
// MutableString 在 mutable_string.cj 中定义

/// 字符串拼接构建器 - 对应 Bun StringJoiner
/// 严格翻译自: src/string/StringJoiner.zig
/// Rope-like 数据结构, 链表拼接多个字符串片段
// StringJoiner 在 string_builder.cj 中定义

/// 正则转义工具 - 对应 Bun escapeRegExp
/// 严格翻译自: src/string/escapeRegExp.zig
// RegexEscape 在 escape_regex.cj 中定义

/// 环境变量工具 - 对应 Bun env_var
/// 严格翻译自: src/bun_core/env_var.zig
/// 类型安全的环境变量访问器 (string/boolean/unsigned)
// EnvVar, Env 在 env.cj 中定义

/// 终端进度条 - 对应 Bun Progress
/// 严格翻译自: src/bun_core/Progress.zig
/// 非分配、非失败、线程安全的进度指示器
// Progress 在 progress.cj 中定义
