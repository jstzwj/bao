// bao_platform - 平台检测与系统特定 API
// 严格翻译自: bun/src/platform/ (linux.zig + darwin.zig, ~198行)
//   操作系统、架构、libc 检测以及平台特定的系统调用封装
package bao_platform

import bao_core.*

// ============================================================================
// OSType - 操作系统类型
// 严格翻译自: bun/src/bun.zig - Environment.os
//   Zig 编译时 comptime 检测，仓颉使用运行时检测
// ============================================================================

/// 操作系统类型 - 对应 Bun Environment.os
public enum OSType {
    | Linux
    | Darwin      // macOS / iOS
    | Windows
    | FreeBSD
    | OpenBSD
    | NetBSD
    | Unknown

    /// 当前操作系统
    public static func current(): OSType {
        let name = System.osName()
        if (name.startsWith("Linux")) { return OSType.Linux }
        if (name.startsWith("Darwin") || name.startsWith("Mac")) { return OSType.Darwin }
        if (name.startsWith("Windows")) { return OSType.Windows }
        if (name.startsWith("FreeBSD")) { return OSType.FreeBSD }
        if (name.startsWith("OpenBSD")) { return OSType.OpenBSD }
        if (name.startsWith("NetBSD")) { return OSType.NetBSD }
        OSType.Unknown
    }

    public func isPosix(): Bool {
        match (this) {
            case Linux | Darwin | FreeBSD | OpenBSD | NetBSD => true
            case _ => false
        }
    }

    public func isUnix(): Bool {
        isPosix()
    }
}

// ============================================================================
// ArchType - CPU 架构类型
// 严格翻译自: bun/src/bun.zig - Environment.arch
// ============================================================================

/// CPU 架构类型 - 对应 Bun Environment.arch
public enum ArchType {
    | X86_64      // x86_64 / amd64
    | AArch64     // arm64
    | ARM         // 32-bit ARM
    | RISCV64     // RISC-V 64
    | WASM32      // WebAssembly 32-bit
    | WASM64      // WebAssembly 64-bit
    | Unknown

    /// 当前架构
    public static func current(): ArchType {
        let arch = System.arch()
        if (arch == "x86_64" || arch == "amd64") { return ArchType.X86_64 }
        if (arch == "aarch64" || arch == "arm64") { return ArchType.AArch64 }
        if (arch.startsWith("arm")) { return ArchType.ARM }
        if (arch == "riscv64") { return ArchType.RISCV64 }
        if (arch == "wasm32") { return ArchType.WASM32 }
        if (arch == "wasm64") { return ArchType.WASM64 }
        ArchType.Unknown
    }

    /// 指针大小 (字节)
    public func pointerSize(): Int64 {
        match (this) {
            case X86_64 | AArch64 | RISCV64 | WASM64 => 8
            case ARM | WASM32 => 4
            case _ => 8 // 默认 64 位
        }
    }
}

// ============================================================================
// LibcType - C 标准库类型
// 严格翻译自: bun/src/bun.zig - Environment.libc
// ============================================================================

/// C 标准库类型 - 对应 Bun Environment.libc
public enum LibcType {
    | Glibc       // Linux GNU libc
    | Musl        // Linux musl libc
    | SystemLibc  // macOS / BSD 系统 libc
    | MSVCRT      // Windows MSVCRT
    | Unknown

    /// 检测当前 libc
    public static func current(): LibcType {
        let os = OSType.current()
        match (os) {
            case Linux => {
                // 尝试检测 musl vs glibc
                // musl 系统通常有 /etc/alpine-release 或 ld-musl 链接
                if (System.fileExists("/etc/alpine-release")) { return LibcType.Musl }
                if (System.fileExists("/lib/ld-musl-x86_64.so.1")) { return LibcType.Musl }
                if (System.fileExists("/lib/ld-musl-aarch64.so.1")) { return LibcType.Musl }
                LibcType.Glibc
            }
            case Darwin | FreeBSD | OpenBSD | NetBSD => LibcType.SystemLibc
            case Windows => LibcType.MSVCRT
            case _ => LibcType.Unknown
        }
    }
}

// ============================================================================
// PlatformInfo - 平台信息聚合
// 严格翻译自: bun/src/bun.zig - Environment
//   pub const os = ...
//   pub const arch = ...
//   pub const libc = ...
// ============================================================================

/// 平台信息 - 对应 Bun Environment
public class PlatformInfo {
    public var os: OSType
    public var arch: ArchType
    public var libc: LibcType

    public init() {
        os = OSType.current()
        arch = ArchType.current()
        libc = LibcType.current()
    }

    public init(os: OSType, arch: ArchType, libc: LibcType) {
        this.os = os
        this.arch = arch
        this.libc = libc
    }

    /// 是否为 Linux 平台
    public func isLinux(): Bool {
        os == OSType.Linux
    }

    /// 是否为 macOS/Darwin 平台
    public func isDarwin(): Bool {
        os == OSType.Darwin
    }

    /// 是否为 Windows 平台
    public func isWindows(): Bool {
        os == OSType.Windows
    }

    /// 是否为 POSIX 兼容系统
    public func isPosix(): Bool {
        os.isPosix()
    }

    /// 格式化为字符串 (如 "linux-x86_64-gnu")
    public func toString(): String {
        let osStr = match (os) {
            case Linux => "linux"
            case Darwin => "darwin"
            case Windows => "win32"
            case FreeBSD => "freebsd"
            case OpenBSD => "openbsd"
            case NetBSD => "netbsd"
            case _ => "unknown"
        }
        let archStr = match (arch) {
            case X86_64 => "x64"
            case AArch64 => "arm64"
            case ARM => "arm"
            case RISCV64 => "riscv64"
            case _ => "unknown"
        }
        let libcStr = match (libc) {
            case Glibc => "gnu"
            case Musl => "musl"
            case MSVCRT => "msvc"
            case _ => ""
        }
        if (libcStr.isEmpty) {
            "${osStr}-${archStr}"
        } else {
            "${osStr}-${archStr}-${libcStr}"
        }
    }
}

// ============================================================================
// SpliceResult - splice 系统调用结果 (Linux)
// 严格翻译自: bun/src/platform/linux.zig - splice()
//   pub fn splice(fd_in, off_in, fd_out, off_out, len, flags) usize
// ============================================================================

/// splice 结果 - 对应 Bun splice 返回值
public class SpliceResult {
    /// 传输的字节数
    public var bytesTransferred: Int64
    /// 是否成功
    public var success: Bool
    /// 错误码 (失败时)
    public var errorCode: Int64

    public init(bytesTransferred: Int64) {
        this.bytesTransferred = bytesTransferred
        this.success = true
        this.errorCode = 0
    }

    public init(errorCode: Int64) {
        this.bytesTransferred = 0
        this.success = false
        this.errorCode = errorCode
    }
}

// ============================================================================
// RWFFlagSupport - RWF_* 标志支持检测 (Linux)
// 严格翻译自: bun/src/platform/linux.zig - RWFFlagSupport
//   pub const RWFFlagSupport = enum(u8) { unknown, unsupported, supported }
// ============================================================================

/// RWF 标志支持状态 - 对应 Bun RWFFlagSupport
public enum RWFFlagSupport {
    | Unknown
    | Unsupported
    | Supported
    | major
}
}

// ============================================================================
// OSLogCategory - macOS OSLog 类别
// 严格翻译自: bun/src/platform/darwin.zig - OSLog.Category
//   pub const Category = enum(u8) {
//       PointsOfInterest, Dynamicity, SizeAndThroughput, TimeProfile, SystemReporting, UserCustom
//   };
// ============================================================================

/// macOS OSLog 类别 - 对应 Bun OSLog.Category
public enum OSLogCategory {
    | PointsOfInterest  // 0
    | Dynamicity        // 1
    | SizeAndThroughput // 2
    | TimeProfile       // 3
    | SystemReporting   // 4
    | UserCustom        // 5
}

// ============================================================================
// OSLogSubsystem - macOS OSLog 子系统
// 严格翻译自: bun/src/platform/darwin.zig - OSLog.Subsystem
//   pub const Subsystem = struct {
//       pub const Network = "com.apple.network";
//       pub const FileIO = "com.apple.disk_io";
//       ...
//   };
// ============================================================================

/// macOS OSLog 子系统常量 - 对应 Bun OSLog.Subsystem
public class OSLogSubsystem {
    public static let NETWORK: String = "com.apple.network"
    public static let FILE_IO: String = "com.apple.disk_io"
    public static let GRAPHICS: String = "com.apple.graphics"
    public static let MEMORY: String = "com.apple.memory"
    public static let PERFORMANCE: String = "com.apple.performance"
}

// ============================================================================
// SignpostType - macOS Instruments Signpost 类型
// 严格翻译自: bun/src/platform/darwin.zig - OSLog.SignpostType
//   pub const SignpostType = enum(u8) { Event, IntervalBegin, IntervalEnd };
// ============================================================================

/// Signpost 类型 - 对应 Bun OSLog.SignpostType
public enum SignpostType {
    | Event          // 0
    | IntervalBegin  // 1
    | IntervalEnd    // 2
}

// ============================================================================
// LinuxKernelVersion - Linux 内核版本
// 严格翻译自: bun/src/bun.zig - linuxKernelVersion()
//   用于检测内核特性支持
// ============================================================================

/// Linux 内核版本 - 对应 Bun linuxKernelVersion()
public class LinuxKernelVersion {
    public var major: Int64
    public var minor: Int64
    public var patch: Int64

    public init(major: Int64, minor: Int64, patch: Int64) {
        this.major = major
        this.minor = minor
        this.patch = patch
    }

    /// 从版本字符串解析 (如 "5.15.0-47-generic")
    public static func parse(version: String): ?LinuxKernelVersion {
        // 移除后缀
        var ver = version
        let dashIdx = ver.indexOf('-')
        if (dashIdx.isSome()) {
            ver = ver.subString(0, dashIdx.getOrThrow())
        }

        let parts = ver.split('.')
        if (parts.size < 2) { return None }

        let maj = Int64.parse(parts[0])
        let min = Int64.parse(parts[1])
        let pat = if (parts.size >= 3) Int64.parse(parts[2]) else 0

        if (maj.isNone() || min.isNone()) { return None }

        LinuxKernelVersion(maj.getOrThrow(), min.getOrThrow(), pat.getOrElse(0))
    }

    /// 格式化为字符串
    public func toString(): String {
        "${major}.${minor}.${patch}"
    }
}
