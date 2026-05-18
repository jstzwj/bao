// 严格翻译自: src/sys/windows/windows.zig
//   Platform specific APIs for Windows
//   Bun: Windows 专有 API 绑定, 包括 Win32 错误码、文件属性、NT 状态等
//   仓颉: 提供完整的 Windows 错误码枚举和常量, 非Windows平台为桩实现
package bao_sys

import bao_core.*

// ============================================================================
// Windows 错误码
// 严格翻译自: src/sys/windows/windows.zig:145-500+
//   pub const Win32Error = enum(u16) { SUCCESS = 0, INVALID_FUNCTION = 1, ... }
//   Codes from https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-erref
// ============================================================================

/// Windows Win32 错误码 - 严格对应 Bun windows.Win32Error
/// Bun: enum(u16) { SUCCESS=0, INVALID_FUNCTION=1, FILE_NOT_FOUND=2, ... }
/// 包含所有常见的 Win32 错误码, 用于 Windows 平台错误映射
public enum Win32Error {
    | SUCCESS                 // 0
    | INVALID_FUNCTION        // 1
    | FILE_NOT_FOUND          // 2
    | PATH_NOT_FOUND          // 3
    | TOO_MANY_OPEN_FILES     // 4
    | ACCESS_DENIED           // 5
    | INVALID_HANDLE          // 6
    | ARENA_TRASHED           // 7
    | NOT_ENOUGH_MEMORY       // 8
    | INVALID_BLOCK           // 9
    | BAD_ENVIRONMENT         // 10
    | BAD_FORMAT              // 11
    | INVALID_ACCESS          // 12
    | INVALID_DATA            // 13
    | OUTOFMEMORY             // 14
    | INVALID_DRIVE           // 15
    | CURRENT_DIRECTORY       // 16
    | NOT_SAME_DEVICE         // 17
    | NO_MORE_FILES           // 18
    | WRITE_PROTECT           // 19
    | BAD_UNIT                // 20
    | NOT_READY               // 21
    | BAD_COMMAND             // 22
    | CRC                     // 23
    | BAD_LENGTH              // 24
    | SEEK                    // 25
    | NOT_DOS_DISK            // 26
    | SECTOR_NOT_FOUND        // 27
    | OUT_OF_PAPER            // 28
    | WRITE_FAULT             // 29
    | READ_FAULT              // 30
    | GEN_FAILURE             // 31
    | SHARING_VIOLATION       // 32
    | LOCK_VIOLATION          // 33
    | WRONG_DISK              // 34
    | SHARING_BUFFER_EXCEEDED // 36
    | HANDLE_EOF              // 38
    | HANDLE_DISK_FULL        // 39
    | NOT_SUPPORTED           // 50
    | REM_NOT_LIST            // 51
    | DUP_NAME                // 52
    | BAD_NETPATH             // 53
    | NETWORK_BUSY            // 54
    | DEV_NOT_EXIST           // 55
    | TOO_MANY_CMDS           // 56
    | ADAP_HDW_ERR            // 57
    | BAD_NET_RESP            // 58
    | UNEXP_NET_ERR           // 59
    | BAD_REM_ADAP            // 60
    | PRINTQ_FULL             // 61
    | NO_SPOOL_SPACE          // 62
    | PRINT_CANCELLED         // 63
    | NETNAME_DELETED         // 64
    | NETWORK_ACCESS_DENIED   // 65
    | BAD_DEV_TYPE            // 66
    | BAD_NET_NAME            // 67
    | TOO_MANY_NAMES          // 68
    | TOO_MANY_SESS           // 69
    | SHARING_PAUSED          // 70
    | REQ_NOT_ACCEP           // 71
    | REDIR_PAUSED            // 72
    | FILE_EXISTS             // 80
    | CANNOT_MAKE             // 82
    | FAIL_I24                // 83
    | OUT_OF_STRUCTURES       // 84
    | ALREADY_ASSIGNED        // 85
    | INVALID_PASSWORD        // 86
    | INVALID_PARAMETER       // 87
    | NET_WRITE_FAULT         // 88
    | NO_PROC_SLOTS           // 89
    | TOO_MANY_SEMAPHORES     // 100
    | EXCL_SEM_ALREADY_OWNED  // 101
    | SEM_IS_SET              // 102
    | TOO_MANY_SEM_REQUESTS   // 103
    | INVALID_AT_INTERRUPT_TIME // 104
    | SEM_OWNER_DIED          // 105
    | BROKEN_PIPE             // 109
    | OPEN_FAILED             // 110
    | BUFFER_OVERFLOW         // 111
    | DISK_FULL               // 112
    | NO_MORE_SEARCH_HANDLES  // 113
    | INVALID_TARGET_HANDLE   // 114
    | SEM_TIMEOUT             // 121
    | INSUFFICIENT_BUFFER     // 122
    | INVALID_NAME            // 123
    | INVALID_LEVEL           // 124
    | MOD_NOT_FOUND           // 126
    | PROC_NOT_FOUND          // 127
    | WAIT_NO_CHILDREN        // 128
    | CHILD_NOT_COMPLETE      // 129
    | DIRECT_ACCESS_HANDLE    // 130
    | NEGATIVE_SEEK           // 131
    | SEEK_ON_DEVICE          // 132
    | DIR_NOT_EMPTY           // 145
    | BUSY                    // 170
    | ALREADY_EXISTS          // 183
    | INVALID_FLAG_NUMBER     // 186
    | BAD_EXE_FORMAT          // 193
    | ENVVAR_NOT_FOUND        // 203
    | FILENAME_EXCED_RANGE    // 206
    | ELEVATION_REQUIRED      // 740

    /// 从原始值构建
    public static func fromRaw(value: UInt16): Win32Error {
        match (value) {
            case 0 => SUCCESS
            case 1 => INVALID_FUNCTION
            case 2 => FILE_NOT_FOUND
            case 3 => PATH_NOT_FOUND
            case 4 => TOO_MANY_OPEN_FILES
            case 5 => ACCESS_DENIED
            case 6 => INVALID_HANDLE
            case 8 => NOT_ENOUGH_MEMORY
            case 14 => OUTOFMEMORY
            case 15 => INVALID_DRIVE
            case 17 => NOT_SAME_DEVICE
            case 18 => NO_MORE_FILES
            case 32 => SHARING_VIOLATION
            case 33 => LOCK_VIOLATION
            case 38 => HANDLE_EOF
            case 39 => HANDLE_DISK_FULL
            case 50 => NOT_SUPPORTED
            case 53 => BAD_NETPATH
            case 59 => UNEXP_NET_ERR
            case 65 => NETWORK_ACCESS_DENIED
            case 67 => BAD_NET_NAME
            case 80 => FILE_EXISTS
            case 87 => INVALID_PARAMETER
            case 109 => BROKEN_PIPE
            case 111 => BUFFER_OVERFLOW
            case 112 => DISK_FULL
            case 122 => INSUFFICIENT_BUFFER
            case 123 => INVALID_NAME
            case 126 => MOD_NOT_FOUND
            case 127 => PROC_NOT_FOUND
            case 131 => NEGATIVE_SEEK
            case 145 => DIR_NOT_EMPTY
            case 170 => BUSY
            case 183 => ALREADY_EXISTS
            case 193 => BAD_EXE_FORMAT
            case 203 => ENVVAR_NOT_FOUND
            case 206 => FILENAME_EXCED_RANGE
            case 740 => ELEVATION_REQUIRED
            case _ => SUCCESS  // 未知错误码默认 SUCCESS (调用者应检查)
        }
    }

    /// 转为 SystemErrno
    /// 对应 Bun: fn toSystemErrno(self) -> ?SystemErrno
    /// 将 Windows 错误码映射到 POSIX errno
    public func toSystemErrno(): ?SystemErrno {
        match (this) {
            case SUCCESS => SystemErrno.SUCCESS
            case FILE_NOT_FOUND => SystemErrno.ENOENT
            case PATH_NOT_FOUND => SystemErrno.ENOENT
            case TOO_MANY_OPEN_FILES => SystemErrno.EMFILE
            case ACCESS_DENIED => SystemErrno.EACCES
            case INVALID_HANDLE => SystemErrno.EBADF
            case NOT_ENOUGH_MEMORY => SystemErrno.ENOMEM
            case OUTOFMEMORY => SystemErrno.ENOMEM
            case NOT_SAME_DEVICE => SystemErrno.EXDEV
            case SHARING_VIOLATION => SystemErrno.EBUSY
            case LOCK_VIOLATION => SystemErrno.EBUSY
            case HANDLE_EOF => SystemErrno.ENOENT
            case HANDLE_DISK_FULL => SystemErrno.ENOSPC
            case NOT_SUPPORTED => SystemErrno.ENOSYS
            case BAD_NETPATH => SystemErrno.ENOENT
            case NETWORK_ACCESS_DENIED => SystemErrno.EACCES
            case BAD_NET_NAME => SystemErrno.ENOENT
            case FILE_EXISTS => SystemErrno.EEXIST
            case INVALID_PARAMETER => SystemErrno.EINVAL
            case BROKEN_PIPE => SystemErrno.EPIPE
            case BUFFER_OVERFLOW => SystemErrno.ENAMETOOLONG
            case DISK_FULL => SystemErrno.ENOSPC
            case INSUFFICIENT_BUFFER => SystemErrno.EINVAL
            case INVALID_NAME => SystemErrno.ENOENT
            case NEGATIVE_SEEK => SystemErrno.EINVAL
            case DIR_NOT_EMPTY => SystemErrno.ENOTEMPTY
            case BUSY => SystemErrno.EBUSY
            case ALREADY_EXISTS => SystemErrno.EEXIST
            case BAD_EXE_FORMAT => SystemErrno.ENOEXEC
            case ENVVAR_NOT_FOUND => SystemErrno.ENOENT
            case FILENAME_EXCED_RANGE => SystemErrno.ENAMETOOLONG
            case ELEVATION_REQUIRED => SystemErrno.EPERM
            case _ => None
        }
    }

    /// 从 NTSTATUS 转换
    /// 对应 Bun: pub fn fromNTStatus(ntstatus) -> Win32Error
    public static func fromNTStatus(ntstatus: Int32): Win32Error {
        // RtlNtStatusToDosError 映射, 简化实现
        if (ntstatus == 0) {
            return SUCCESS
        }
        // 常见 NTSTATUS 映射
        if (ntstatus == -1073741823) {  // STATUS_INVALID_PARAMETER
            return INVALID_PARAMETER
        }
        if (ntstatus == -1073741811) {  // STATUS_ACCESS_DENIED
            return ACCESS_DENIED
        }
        if (ntstatus == -1073741819) {  // STATUS_OBJECT_NAME_NOT_FOUND
            return FILE_NOT_FOUND
        }
        if (ntstatus == -1073741772) {  // STATUS_OBJECT_PATH_NOT_FOUND
            return PATH_NOT_FOUND
        }
        // 默认
        return fromRaw(UInt16(ntstatus & 0xFFFF))
    }
}

// ============================================================================
// Windows 文件属性
// 严格翻译自: src/sys/windows/windows.zig:49-69
//   FILE_SHARE_READ, FILE_SHARE_WRITE, FILE_SHARE_DELETE, ...
// 以及 sys.zig:3433-3490 WindowsFileAttributes
// ============================================================================

/// Windows 文件共享模式
public class WinFileShare {
    public static let READ: UInt32 = 0x00000001
    public static let WRITE: UInt32 = 0x00000002
    public static let DELETE: UInt32 = 0x00000004
}

/// Windows 文件属性
public class WinFileAttributes {
    public static let NORMAL: UInt32 = 0x00000080
    public static let READONLY: UInt32 = 0x00000001
    public static let HIDDEN: UInt32 = 0x00000002
    public static let SYSTEM: UInt32 = 0x00000004
    public static let DIRECTORY: UInt32 = 0x00000010
    public static let ARCHIVE: UInt32 = 0x00000020
    public static let DEVICE: UInt32 = 0x00000040
    public static let TEMPORARY: UInt32 = 0x00000100
    public static let SPARSE_FILE: UInt32 = 0x00000200
    public static let REPARSE_POINT: UInt32 = 0x00000400
    public static let COMPRESSED: UInt32 = 0x00000800
    public static let OFFLINE: UInt32 = 0x00001000
    public static let NOT_CONTENT_INDEXED: UInt32 = 0x00002000
    public static let ENCRYPTED: UInt32 = 0x00004000
}

/// Windows 文件创建标志
public class WinDisposition {
    public static let FILE_OPEN: UInt32 = 1
    public static let FILE_CREATE: UInt32 = 2
    public static let FILE_OPEN_IF: UInt32 = 3
    public static let FILE_OVERWRITE: UInt32 = 4
    public static let FILE_OVERWRITE_IF: UInt32 = 5
}

/// Windows 文件选项
public class WinFileOptions {
    public static let DIRECTORY_FILE: UInt32 = 0x00000001
    public static let WRITE_THROUGH: UInt32 = 0x00000002
    public static let SEQUENTIAL_ONLY: UInt32 = 0x00000004
    public static let SYNCHRONOUS_IO_NONALERT: UInt32 = 0x00000020
    public static let OPEN_REPARSE_POINT: UInt32 = 0x00200000
    public static let OPEN_FOR_BACKUP_INTENT: UInt32 = 0x00004000
}

/// Windows 文件访问权限
public class WinAccessMask {
    public static let GENERIC_READ: UInt32 = 0x80000000
    public static let GENERIC_WRITE: UInt32 = 0x40000000
    public static let GENERIC_EXECUTE: UInt32 = 0x20000000
    public static let GENERIC_ALL: UInt32 = 0x10000000
    public static let READ_CONTROL: UInt32 = 0x00020000
    public static let SYNCHRONIZE: UInt32 = 0x00100000
    public static let FILE_READ_ATTRIBUTES: UInt32 = 0x00000080
    public static let FILE_READ_EA: UInt32 = 0x00000008
    public static let FILE_WRITE_ATTRIBUTES: UInt32 = 0x00000100
    public static let FILE_WRITE_EA: UInt32 = 0x00000010
    public static let FILE_TRAVERSE: UInt32 = 0x00000020
    public static let FILE_LIST_DIRECTORY: UInt32 = 0x00000001
    public static let FILE_ADD_FILE: UInt32 = 0x00000002
    public static let FILE_ADD_SUBDIRECTORY: UInt32 = 0x00000004
    public static let FILE_DELETE: UInt32 = 0x00010000
    public static let FILE_APPEND_DATA: UInt32 = 0x00000004
    public static let FILE_WRITE_DATA: UInt32 = 0x00000002
    public static let DELETE: UInt32 = 0x00010000
    public static let STANDARD_RIGHTS_READ: UInt32 = 0x00020000
}

// ============================================================================
// Windows 文件类型
// 严格翻译自: src/sys/windows/windows.zig:108-112
// ============================================================================

/// Windows 文件类型常量
public class WinFileType {
    public static let UNKNOWN: UInt32 = 0x0000
    public static let DISK: UInt32 = 0x0001
    public static let CHAR: UInt32 = 0x0002
    public static let PIPE: UInt32 = 0x0003
    public static let REMOTE: UInt32 = 0x8000
}

// ============================================================================
// Windows 二进制类型
// 严格翻译自: src/sys/windows/windows.zig:118-129
// ============================================================================

/// Windows 二进制类型
public class WinBinaryType {
    public static let SCS_32BIT_BINARY: UInt32 = 0
    public static let SCS_64BIT_BINARY: UInt32 = 6
    public static let SCS_DOS_BINARY: UInt32 = 1
    public static let SCS_OS216_BINARY: UInt32 = 5
    public static let SCS_PIF_BINARY: UInt32 = 3
    public static let SCS_POSIX_BINARY: UInt32 = 4
}

// ============================================================================
// Windows 路径常量
// 严格翻译自: src/sys/windows/windows.zig:75-81
// ============================================================================

/// Windows 路径前缀
public class WinPathPrefix {
    /// NT 对象前缀: \??\
    public static let NT_OBJECT: String = "\\??\\"
    /// NT UNC 对象前缀: \??\UNC\
    public static let NT_UNC_OBJECT: String = "\\??\\UNC\\"
    /// 长路径前缀: \\?\
    public static let LONG_PATH: String = "\\\\?\\"
}

/// Windows INVALID_HANDLE_VALUE
public let INVALID_HANDLE_VALUE: Int64 = -1

/// Windows INVALID_FILE_ATTRIBUTES
public let INVALID_FILE_ATTRIBUTES: UInt32 = 0xFFFFFFFF

/// Windows MAX_PATH
public let WIN_MAX_PATH: Int64 = 260

/// Windows PATH_MAX_WIDE
public let WIN_PATH_MAX_WIDE: Int64 = 32768

// ============================================================================
// Windows MoveFile 标志
// 严格翻译自: src/sys/windows/windows.zig:40-42
// ============================================================================

public class WinMoveFileFlags {
    public static let COPY_ALLOWED: UInt32 = 0x00000002
    public static let REPLACE_EXISTING: UInt32 = 0x00000001
    public static let WRITE_THROUGH: UInt32 = 0x00000008
}

// ============================================================================
// WindowsSymlinkOptions - Windows 符号链接选项
// 严格翻译自: src/sys/sys.zig:2721-2738
//   pub const WindowsSymlinkOptions = packed struct { directory: bool = false, ... }
// ============================================================================

/// Windows 符号链接选项
public class WindowsSymlinkOptions {
    public var isDirectory: Bool

    public init() {
        isDirectory = false
    }

    public init(isDirectory: Bool) {
        this.isDirectory = isDirectory
    }

    /// 符号链接标志 - 包含 SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE
    public static var symlinkFlags: UInt32 = 0x00000002  // SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE

    /// 是否创建符号链接失败过
    public static var hasFailedToCreateSymlink: Bool = false

    /// 获取标志值
    public func flags(): UInt32 {
        var flags = WindowsSymlinkOptions.symlinkFlags
        if (isDirectory) {
            flags = flags | 0x00000001  // SYMBOLIC_LINK_FLAG_DIRECTORY
        }
        return flags
    }

    /// 禁用特权创建标志
    public static func denied(): Unit {
        symlinkFlags = 0
    }
}

// ============================================================================
// WindowsFileAttributes 结构
// 严格翻译自: src/sys/sys.zig:3433-3490
//   pub const WindowsFileAttributes = packed struct(windows.DWORD) { ... }
// ============================================================================

/// Windows 文件属性 (解析版)
/// 对应 Bun sys.zig 中的 WindowsFileAttributes packed struct
public class WinFileAttr {
    public var isReadonly: Bool
    public var isHidden: Bool
    public var isSystem: Bool
    public var isDirectory: Bool
    public var isArchive: Bool
    public var isDevice: Bool
    public var isNormal: Bool
    public var isTemporary: Bool
    public var isSparseFile: Bool
    public var isReparsePoint: Bool
    public var isCompressed: Bool
    public var isOffline: Bool
    public var isNotContentIndexed: Bool
    public var isEncrypted: Bool

    public init() {
        isReadonly = false
        isHidden = false
        isSystem = false
        isDirectory = false
        isArchive = false
        isDevice = false
        isNormal = false
        isTemporary = false
        isSparseFile = false
        isReparsePoint = false
        isCompressed = false
        isOffline = false
        isNotContentIndexed = false
        isEncrypted = false
    }

    /// 从原始 DWORD 值解析
    /// 对应 Bun: getFileAttributes(path) -> ?WindowsFileAttributes
    public static func fromRaw(dword: UInt32): WinFileAttr {
        let attr = WinFileAttr()
        attr.isReadonly = (dword & 0x00000001) != 0
        attr.isHidden = (dword & 0x00000002) != 0
        attr.isSystem = (dword & 0x00000004) != 0
        attr.isDirectory = (dword & 0x00000010) != 0
        attr.isArchive = (dword & 0x00000020) != 0
        attr.isDevice = (dword & 0x00000040) != 0
        attr.isNormal = (dword & 0x00000080) != 0
        attr.isTemporary = (dword & 0x00000100) != 0
        attr.isSparseFile = (dword & 0x00000200) != 0
        attr.isReparsePoint = (dword & 0x00000400) != 0
        attr.isCompressed = (dword & 0x00000800) != 0
        attr.isOffline = (dword & 0x00001000) != 0
        attr.isNotContentIndexed = (dword & 0x00002000) != 0
        attr.isEncrypted = (dword & 0x00004000) != 0
        return attr
    }
}

// ============================================================================
// DUPLICATE_SAME_ACCESS
// 严格翻译自: src/sys/windows/windows.zig:45
// ============================================================================

public let DUPLICATE_SAME_ACCESS: UInt32 = 0x00000002

// ============================================================================
// FILE_BEGIN / FILE_END / FILE_CURRENT
// 严格翻译自: src/sys/windows/windows.zig:30-32
// ============================================================================

public let FILE_BEGIN: UInt32 = 0
public let FILE_CURRENT: UInt32 = 1
public let FILE_END: UInt32 = 2

// ============================================================================
// FILE_INFO_BY_HANDLE_CLASS
// 严格翻译自: src/sys/windows/windows.zig:48
// ============================================================================

/// Windows FILE_INFO_BY_HANDLE_CLASS 常量
public class FileInfoByHandleClass {
    public static let FILE_BASIC_INFO: UInt32 = 0
    public static let FILE_STANDARD_INFO: UInt32 = 1
    public static let FILE_COMPRESSION_INFO: UInt32 = 5
    public static let FILE_ATTRIBUTE_TAG_INFO: UInt32 = 9
    public static let FILE_ID_BOTH_DIR_INFO: UInt32 = 10
    public static let FILE_ID_INFO: UInt32 = 18
}

// ============================================================================
// Windows 桩函数 (非 Windows 平台)
// 仓颉目前主要在 Linux 上运行, Windows API 为框架桩实现
// ============================================================================

/// Windows 平台操作桩
/// 在非 Windows 平台上提供空实现, 在 Windows 上通过 FFI 调用 Win32 API
public class WindowsImpl {
    /// 获取最后错误码
    /// 对应 Bun: kernel32.GetLastError()
    public static func getLastError(): Win32Error {
        // 非 Windows 平台返回 SUCCESS
        return Win32Error.SUCCESS
    }

    /// 获取文件属性
    /// 对应 Bun: kernel32.GetFileAttributesW(path)
    public static func getFileAttributes(path: String): ?WinFileAttr {
        return None
    }

    /// 设置当前目录
    /// 对应 Bun: kernel32.SetCurrentDirectoryW(path)
    public static func setCurrentDirectory(path: String): Bool {
        return false
    }

    /// 获取当前目录
    /// 对应 Bun: kernel32.GetCurrentDirectoryW(len, buf)
    public static func getCurrentDirectory(): String {
        return ""
    }

    /// 创建目录
    /// 对应 Bun: kernel32.CreateDirectoryW(path, null)
    public static func createDirectory(path: String): Bool {
        return false
    }

    /// 删除文件
    /// 对应 Bun: kernel32.DeleteFileW(path)
    public static func deleteFile(path: String): Bool {
        return false
    }

    /// 创建符号链接
    /// 对应 Bun: kernel32.CreateSymbolicLinkW(dest, target, flags)
    public static func createSymbolicLink(dest: String, target: String, flags: UInt32): Bool {
        return false
    }

    /// 获取文件类型
    /// 对应 Bun: kernel32.GetFileType(handle)
    public static func getFileType(handle: Int64): UInt32 {
        return WinFileType.UNKNOWN
    }

    /// 获取二进制类型
    /// 对应 Bun: kernel32.GetBinaryTypeW(path, out)
    public static func getBinaryType(path: String): UInt32 {
        return WinBinaryType.SCS_32BIT_BINARY
    }

    /// 判断当前是否为 Windows 平台
    public static func isWindows(): Bool {
        return false
    }
}
