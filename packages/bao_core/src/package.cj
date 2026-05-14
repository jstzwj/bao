// bao_core - 核心类型和原语
// 对应 Bun: src/bun_core/, src/bun.zig, src/bun.rs
package bao_core

// ============================================================================
// 基础类型别名
// 对应 Bun: src/bun_core/types.zig
// ============================================================================

/// 文件描述符类型
public type Fd = Int64

/// 文件偏移量
public type FileOffset = Int64

/// 文件大小
public type FileSize = UInt64

/// 端口号
public type Port = UInt16

/// 平台路径字符类型 (Linux: UInt8, Windows: UInt16)
public type OSPathChar = UInt8

/// 最大路径长度
public let MAX_PATH_BYTES: Int64 = 4096

/// 版本号字符串
public let BAO_VERSION = "0.1.0"

/// User-Agent 字符串
public let USER_AGENT = "Bao/${BAO_VERSION}"

// ============================================================================
// 架构和平台常量
// 对应 Bun: src/bun.zig - Environment
// ============================================================================

/// 操作系统类型
public enum Platform {
    | Linux
    | MacOS
    | Windows
    | Unknown
}

/// CPU 架构
public enum Arch {
    | X86_64
    | ARM64
    | X86
    | Unknown
}

/// 获取当前平台
public func currentPlatform(): Platform {
    // 仓颉通过条件编译或运行时检测
    return Platform.Linux
}

/// 获取当前架构
public func currentArch(): Arch {
    return Arch.X86_64
}

// ============================================================================
// 全局错误码
// 对应 Bun: src/bun_core/result.zig - Error
// ============================================================================

/// 基础错误类型
public open class BaoError <: Exception {
    public let code: Int64
    public let message: String

    public init(code: Int64, message: String) {
        super(message)
        this.code = code
        this.message = message
    }

    public init(message: String) {
        super(message)
        this.code = -1
        this.message = message
    }
}

/// 内存不足错误
public class OutOfMemoryError <: BaoError {
    public init() {
        super(1, "Out of memory")
    }
}

/// IO 错误
public class IoError <: BaoError {
    public let errno: Int64

    public init(errno: Int64, message: String) {
        this.errno = errno
        super(2, message)
    }
}

/// 文件未找到错误
public class FileNotFoundError <: IoError {
    public init(path: String) {
        super(2, "No such file or directory: ${path}")
    }
}

/// 权限错误
public class PermissionError <: IoError {
    public init(path: String) {
        super(13, "Permission denied: ${path}")
    }
}

/// 解析错误
public class ParseError <: BaoError {
    public let line: Int64
    public let column: Int64

    public init(line: Int64, column: Int64, message: String) {
        this.line = line
        this.column = column
        super(100, "Parse error at ${line}:${column}: ${message}")
    }
}

// ============================================================================
// POSIX 错误码映射
// 对应 Bun: src/bun_core/result.zig - POSIX errors
// ============================================================================

public class PosixError {
    public static let EPERM: Int64 = 1
    public static let ENOENT: Int64 = 2
    public static let ESRCH: Int64 = 3
    public static let EINTR: Int64 = 4
    public static let EIO: Int64 = 5
    public static let ENXIO: Int64 = 6
    public static let E2BIG: Int64 = 7
    public static let ENOEXEC: Int64 = 8
    public static let EBADF: Int64 = 9
    public static let ECHILD: Int64 = 10
    public static let EAGAIN: Int64 = 11
    public static let ENOMEM: Int64 = 12
    public static let EACCES: Int64 = 13
    public static let EFAULT: Int64 = 14
    public static let ENOTEMPTY: Int64 = 39
    public static let EINVAL: Int64 = 22
    public static let EMFILE: Int64 = 24
    public static let ENOSPC: Int64 = 28
    public static let EROFS: Int64 = 30
    public static let EEXIST: Int64 = 17
    public static let ENOTDIR: Int64 = 20
    public static let EISDIR: Int64 = 21

    public static func fromCode(code: Int64): String {
        match (code) {
            case 1 => "Operation not permitted"
            case 2 => "No such file or directory"
            case 3 => "No such process"
            case 4 => "Interrupted system call"
            case 5 => "Input/output error"
            case 12 => "Cannot allocate memory"
            case 13 => "Permission denied"
            case 17 => "File exists"
            case 20 => "Not a directory"
            case 21 => "Is a directory"
            case 22 => "Invalid argument"
            case 24 => "Too many open files"
            case 28 => "No space left on device"
            case 30 => "Read-only file system"
            case 39 => "Directory not empty"
            case _ => "Unknown error (${code})"
        }
    }
}

// ============================================================================
// 通用工具函数
// ============================================================================

/// 优雅退出
public func exit(code: Int64): Nothing {
    std.process.exit(Int32(code))
}
