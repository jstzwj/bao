// 严格翻译自: src/sys/coreutils_error_map.rs
//   coreutils 错误码到消息的映射表
//   Bun: 派生自 coreutils 打印错误使用的字符串, 等价于 strerror
package bao_sys

import bao_core.*

// ============================================================================
// SystemErrno - 系统错误码枚举
// 严格翻译自: src/sys/sys.zig:34 / src/errno/linux_errno.zig
//   pub const SystemErrno = platform_defs.SystemErrno
//   POSIX errno 值的枚举, 用于 coreutils_error_map 和 libuv_error_map 的键
// ============================================================================

/// 系统错误码枚举 - 对应 Bun SystemErrno
/// Bun: enum { SUCCESS, EPERM, ENOENT, ESRCH, EINTR, ... }
/// 仓颉使用 enum 表示, 值对应 Linux errno 编号
public enum SystemErrno {
    | SUCCESS    // 0
    | EPERM      // 1: Operation not permitted
    | ENOENT     // 2: No such file or directory
    | ESRCH      // 3: No such process
    | EINTR      // 4: Interrupted system call
    | EIO        // 5: I/O error
    | ENXIO      // 6: No such device or address
    | E2BIG      // 7: Argument list too long
    | ENOEXEC    // 8: Exec format error
    | EBADF      // 9: Bad file descriptor
    | ECHILD     // 10: No child processes
    | EAGAIN     // 11: Resource temporarily unavailable
    | ENOMEM     // 12: Not enough memory
    | EACCES     // 13: Permission denied
    | EFAULT     // 14: Bad address
    | ENOTBLK    // 15: Block device required
    | EBUSY      // 16: Device or resource busy
    | EEXIST     // 17: File exists
    | EXDEV      // 18: Cross-device link
    | ENODEV     // 19: No such device
    | ENOTDIR    // 20: Not a directory
    | EISDIR     // 21: Is a directory
    | EINVAL     // 22: Invalid argument
    | ENFILE     // 23: File table overflow
    | EMFILE     // 24: Too many open files
    | ENOTTY     // 25: Not a typewriter
    | ETXTBSY    // 26: Text file busy
    | EFBIG      // 27: File too large
    | ENOSPC     // 28: No space left on device
    | ESPIPE     // 29: Illegal seek
    | EROFS      // 30: Read-only file system
    | EMLINK     // 31: Too many links
    | EPIPE      // 32: Broken pipe
    | EDOM       // 33: Math argument out of domain
    | ERANGE     // 34: Math result not representable
    | EDEADLK    // 35: Resource deadlock would occur
    | ENAMETOOLONG // 36: File name too long
    | ENOLCK     // 37: No record locks available
    | ENOSYS     // 38: Function not implemented
    | ENOTEMPTY  // 39: Directory not empty
    | ELOOP      // 40: Too many symbolic links encountered
    | EWOULDBLOCK // 11: Same as EAGAIN
    | ENOMSG     // 42: No message of desired type
    | EIDRM      // 43: Identifier removed
    | ECHRNG     // 44: Channel number out of range
    | EL2NSYNC   // 45: Level 2 not synchronized
    | EL3HLT     // 46: Level 3 halted
    | EL3RST     // 47: Level 3 reset
    | ELNRNG     // 48: Link number out of range
    | EUNATCH    // 49: Protocol driver not attached
    | ENOCSI     // 50: No CSI structure available
    | EL2HLT     // 51: Level 2 halted
    | EBADE      // 52: Invalid exchange
    | EBADR      // 53: Invalid request descriptor
    | EXFULL     // 54: Exchange full
    | ENOANO     // 55: No anode
    | EBADRQC    // 56: Invalid request code
    | EBADSLT    // 57: Invalid slot
    | EDEADLOCK  // 35: Same as EDEADLK
    | EBFONT     // 59: Bad font file format
    | ENOSTR     // 60: Device not a stream
    | ENODATA    // 61: No data available
    | ETIME      // 62: Timer expired
    | ENOSR      // 63: Out of streams resources
    | ENONET     // 64: Machine is not on the network
    | ENOPKG     // 65: Package not installed
    | EREMOTE    // 66: Object is remote
    | ENOLINK    // 67: Link has been severed
    | EADV       // 68: Advertise error
    | ESRMNT     // 69: Srmount error
    | ECOMM      // 70: Communication error on send
    | EPROTO     // 71: Protocol error
    | EMULTIHOP  // 72: Multihop attempted
    | EDOTDOT    // 73: RFS specific error
    | EBADMSG    // 74: Not a data message
    | EOVERFLOW  // 75: Value too large for defined data type
    | ENOTUNIQ   // 76: Name not unique on network
    | EBADFD     // 77: File descriptor in bad state
    | EREMCHG    // 78: Remote address changed
    | ELIBACC    // 79: Can not access a needed shared library
    | ELIBBAD    // 80: Accessing a corrupted shared library
    | ELIBSCN    // 81: .lib section in a.out corrupted
    | ELIBMAX    // 82: Attempting to link in too many shared libraries
    | ELIBEXEC   // 83: Cannot exec a shared library directly
    | EILSEQ     // 84: Illegal byte sequence
    | ERESTART   // 85: Interrupted system call should be restarted
    | ESTRPIPE   // 86: Streams pipe error
    | EUSERS     // 87: Too many users
    | ENOTSOCK   // 88: Socket operation on non-socket
    | EDESTADDRREQ // 89: Destination address required
    | EMSGSIZE   // 90: Message too long
    | EPROTOTYPE // 91: Protocol wrong type for socket
    | ENOPROTOOPT // 92: Protocol not available
    | EPROTONOSUPPORT // 93: Protocol not supported
    | ESOCKTNOSUPPORT // 94: Socket type not supported
    | EOPNOTSUPP // 95: Operation not supported on transport endpoint
    | EPFNOSUPPORT // 96: Protocol family not supported
    | EAFNOSUPPORT // 97: Address family not supported by protocol
    | EADDRINUSE // 98: Address already in use
    | EADDRNOTAVAIL // 99: Cannot assign requested address
    | ENETDOWN   // 100: Network is down
    | ENETUNREACH // 101: Network is unreachable
    | ENETRESET  // 102: Network dropped connection because of reset
    | ECONNABORTED // 103: Software caused connection abort
    | ECONNRESET // 104: Connection reset by peer
    | ENOBUFS    // 105: No buffer space available
    | EISCONN    // 106: Transport endpoint is already connected
    | ENOTCONN   // 107: Transport endpoint is not connected
    | ESHUTDOWN  // 108: Cannot send after transport endpoint shutdown
    | ETOOMANYREFS // 109: Too many references: cannot splice
    | ETIMEDOUT  // 110: Connection timed out
    | ECONNREFUSED // 111: Connection refused
    | EHOSTDOWN  // 112: Host is down
    | EHOSTUNREACH // 113: No route to host
    | EALREADY   // 114: Operation already in progress
    | EINPROGRESS // 115: Operation now in progress
    | ESTALE     // 116: Stale NFS file handle
    | EUCLEAN    // 117: Structure needs cleaning
    | ENOTNAM    // 118: Not a XENIX named type file
    | ENAVAIL    // 119: No XENIX semaphores available
    | EISNAM     // 120: Is a named type file
    | EREMOTEIO  // 121: Remote I/O error
    | EDQUOT     // 122: Quota exceeded
    | ENOMEDIUM  // 123: No medium found
    | EMEDIUMTYPE // 124: Wrong medium type
    | ECANCELED  // 125: Operation canceled
    | ENOKEY     // 126: Required key not available
    | EKEYEXPIRED // 127: Key has expired
    | EKEYREVOKED // 128: Key has been revoked
    | EKEYREJECTED // 129: Key was rejected by service
    | EOWNERDEAD // 130: Owner died
    | ENOTRECOVERABLE // 131: State not recoverable
    | ERFKILL    // 132: Operation not possible due to RF-kill
    | EHWPOISON  // 133: Memory page has hardware error
    | EUNKNOWN   // Unknown error

    /// 从原始 errno 值构建
    /// 对应 Bun: SystemErrno.init(errno)
    public static func fromRaw(value: UInt16): SystemErrno {
        match (value) {
            case 0 => SUCCESS
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
            case 35 => EDEADLK
            case 36 => ENAMETOOLONG
            case 37 => ENOLCK
            case 38 => ENOSYS
            case 39 => ENOTEMPTY
            case 40 => ELOOP
            case 49 => EUNATCH
            case 61 => ENODATA
            case 64 => ENONET
            case 71 => EPROTO
            case 75 => EOVERFLOW
            case 84 => EILSEQ
            case 88 => ENOTSOCK
            case 89 => EDESTADDRREQ
            case 90 => EMSGSIZE
            case 91 => EPROTOTYPE
            case 92 => ENOPROTOOPT
            case 93 => EPROTONOSUPPORT
            case 94 => ESOCKTNOSUPPORT
            case 95 => EOPNOTSUPP
            case 96 => EPFNOSUPPORT
            case 97 => EAFNOSUPPORT
            case 98 => EADDRINUSE
            case 99 => EADDRNOTAVAIL
            case 100 => ENETDOWN
            case 101 => ENETUNREACH
            case 102 => ENETRESET
            case 103 => ECONNABORTED
            case 104 => ECONNRESET
            case 105 => ENOBUFS
            case 106 => EISCONN
            case 107 => ENOTCONN
            case 108 => ESHUTDOWN
            case 110 => ETIMEDOUT
            case 111 => ECONNREFUSED
            case 112 => EHOSTDOWN
            case 113 => EHOSTUNREACH
            case 114 => EALREADY
            case 115 => EINPROGRESS
            case 121 => EREMOTEIO
            case 125 => ECANCELED
            case _ => EUNKNOWN
        }
    }

    /// 获取错误码名称字符串
    /// 对应 Bun: @tagName(errno) -> "ENOENT" etc.
    public func name(): String {
        match (this) {
            case SUCCESS => "SUCCESS"
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
            case EDEADLK => "EDEADLK"
            case ENAMETOOLONG => "ENAMETOOLONG"
            case ENOLCK => "ENOLCK"
            case ENOSYS => "ENOSYS"
            case ENOTEMPTY => "ENOTEMPTY"
            case ELOOP => "ELOOP"
            case EWOULDBLOCK => "EWOULDBLOCK"
            case ENOMSG => "ENOMSG"
            case EIDRM => "EIDRM"
            case ECHRNG => "ECHRNG"
            case EL2NSYNC => "EL2NSYNC"
            case EL3HLT => "EL3HLT"
            case EL3RST => "EL3RST"
            case ELNRNG => "ELNRNG"
            case EUNATCH => "EUNATCH"
            case ENOCSI => "ENOCSI"
            case EL2HLT => "EL2HLT"
            case EBADE => "EBADE"
            case EBADR => "EBADR"
            case EXFULL => "EXFULL"
            case ENOANO => "ENOANO"
            case EBADRQC => "EBADRQC"
            case EBADSLT => "EBADSLT"
            case EDEADLOCK => "EDEADLOCK"
            case EBFONT => "EBFONT"
            case ENOSTR => "ENOSTR"
            case ENODATA => "ENODATA"
            case ETIME => "ETIME"
            case ENOSR => "ENOSR"
            case ENONET => "ENONET"
            case ENOPKG => "ENOPKG"
            case EREMOTE => "EREMOTE"
            case ENOLINK => "ENOLINK"
            case EADV => "EADV"
            case ESRMNT => "ESRMNT"
            case ECOMM => "ECOMM"
            case EPROTO => "EPROTO"
            case EMULTIHOP => "EMULTIHOP"
            case EDOTDOT => "EDOTDOT"
            case EBADMSG => "EBADMSG"
            case EOVERFLOW => "EOVERFLOW"
            case ENOTUNIQ => "ENOTUNIQ"
            case EBADFD => "EBADFD"
            case EREMCHG => "EREMCHG"
            case ELIBACC => "ELIBACC"
            case ELIBBAD => "ELIBBAD"
            case ELIBSCN => "ELIBSCN"
            case ELIBMAX => "ELIBMAX"
            case ELIBEXEC => "ELIBEXEC"
            case EILSEQ => "EILSEQ"
            case ERESTART => "ERESTART"
            case ESTRPIPE => "ESTRPIPE"
            case EUSERS => "EUSERS"
            case ENOTSOCK => "ENOTSOCK"
            case EDESTADDRREQ => "EDESTADDRREQ"
            case EMSGSIZE => "EMSGSIZE"
            case EPROTOTYPE => "EPROTOTYPE"
            case ENOPROTOOPT => "ENOPROTOOPT"
            case EPROTONOSUPPORT => "EPROTONOSUPPORT"
            case ESOCKTNOSUPPORT => "ESOCKTNOSUPPORT"
            case EOPNOTSUPP => "EOPNOTSUPP"
            case EPFNOSUPPORT => "EPFNOSUPPORT"
            case EAFNOSUPPORT => "EAFNOSUPPORT"
            case EADDRINUSE => "EADDRINUSE"
            case EADDRNOTAVAIL => "EADDRNOTAVAIL"
            case ENETDOWN => "ENETDOWN"
            case ENETUNREACH => "ENETUNREACH"
            case ENETRESET => "ENETRESET"
            case ECONNABORTED => "ECONNABORTED"
            case ECONNRESET => "ECONNRESET"
            case ENOBUFS => "ENOBUFS"
            case EISCONN => "EISCONN"
            case ENOTCONN => "ENOTCONN"
            case ESHUTDOWN => "ESHUTDOWN"
            case ETOOMANYREFS => "ETOOMANYREFS"
            case ETIMEDOUT => "ETIMEDOUT"
            case ECONNREFUSED => "ECONNREFUSED"
            case EHOSTDOWN => "EHOSTDOWN"
            case EHOSTUNREACH => "EHOSTUNREACH"
            case EALREADY => "EALREADY"
            case EINPROGRESS => "EINPROGRESS"
            case ESTALE => "ESTALE"
            case EUCLEAN => "EUCLEAN"
            case ENOTNAM => "ENOTNAM"
            case ENAVAIL => "ENAVAIL"
            case EISNAM => "EISNAM"
            case EREMOTEIO => "EREMOTEIO"
            case EDQUOT => "EDQUOT"
            case ENOMEDIUM => "ENOMEDIUM"
            case EMEDIUMTYPE => "EMEDIUMTYPE"
            case ECANCELED => "ECANCELED"
            case ENOKEY => "ENOKEY"
            case EKEYEXPIRED => "EKEYEXPIRED"
            case EKEYREVOKED => "EKEYREVOKED"
            case EKEYREJECTED => "EKEYREJECTED"
            case EOWNERDEAD => "EOWNERDEAD"
            case ENOTRECOVERABLE => "ENOTRECOVERABLE"
            case ERFKILL => "ERFKILL"
            case EHWPOISON => "EHWPOISON"
            case EUNKNOWN => "EUNKNOWN"
        }
    }
}

// ============================================================================
// CoreutilsErrorMap - coreutils 错误消息映射
// 严格翻译自: src/sys/coreutils_error_map.rs
//   pub static COREUTILS_ERROR_MAP: LazyLock<EnumMap<SystemErrno, &'static str>>
//   以及 src/sys/libuv_error_map.zig 中的 comptime 构建逻辑
//
//   Bun: 从 SystemErrno 枚举值到 coreutils 风格错误描述字符串的映射
//   这个映射派生自 coreutils 在打印错误时使用的字符串
//   等价于 strerror, 但具有常量生命周期
// ============================================================================

/// 未知错误的默认消息
/// 对应 Bun: "unknown error" (initFull 的默认值)
public let COREUTILS_UNKNOWN: String = "unknown error"

/// coreutils 错误消息映射类
/// 对应 Bun: EnumMap<SystemErrno, &str>
/// 仓颉使用静态方法提供 O(1) 查询
public class CoreutilsErrorMap {
    /// 获取错误码对应的 coreutils 错误消息
    /// 对应 Bun: COREUTILS_ERROR_MAP[errno] -> &str
    /// 返回 None 表示该 errno 没有对应的 coreutils 标签
    /// Bun: UNKNOWN 哨兵用于区分 "未映射" 和真实条目
    public static func get(errno: SystemErrno): ?String {
        let msg = getRaw(errno)
        if (msg == COREUTILS_UNKNOWN) {
            return None
        }
        return Some(msg)
    }

    /// 直接获取错误消息 (可能返回 "unknown error")
    /// 对应 Bun: EnumMap 是 total 的, get 永远不返回 null
    public static func getRaw(errno: SystemErrno): String {
        match (errno) {
            case SystemErrno.EPERM => "Operation not permitted"
            case SystemErrno.ENOENT => "No such file or directory"
            case SystemErrno.ESRCH => "No such process"
            case SystemErrno.EINTR => "Interrupted system call"
            case SystemErrno.EIO => "Input/output error"
            case SystemErrno.ENXIO => "No such device or address"
            case SystemErrno.E2BIG => "Argument list too long"
            case SystemErrno.ENOEXEC => "Exec format error"
            case SystemErrno.EBADF => "Bad file descriptor"
            case SystemErrno.ECHILD => "No child processes"
            case SystemErrno.EAGAIN => "Resource temporarily unavailable"
            case SystemErrno.ENOMEM => "Cannot allocate memory"
            case SystemErrno.EACCES => "Permission denied"
            case SystemErrno.EFAULT => "Bad address"
            case SystemErrno.ENOTBLK => "Block device required"
            case SystemErrno.EBUSY => "Device or resource busy"
            case SystemErrno.EEXIST => "File exists"
            case SystemErrno.EXDEV => "Invalid cross-device link"
            case SystemErrno.ENODEV => "No such device"
            case SystemErrno.ENOTDIR => "Not a directory"
            case SystemErrno.EISDIR => "Is a directory"
            case SystemErrno.EINVAL => "Invalid argument"
            case SystemErrno.ENFILE => "Too many open files in system"
            case SystemErrno.EMFILE => "Too many open files"
            case SystemErrno.ENOTTY => "Inappropriate ioctl for device"
            case SystemErrno.ETXTBSY => "Text file busy"
            case SystemErrno.EFBIG => "File too large"
            case SystemErrno.ENOSPC => "No space left on device"
            case SystemErrno.ESPIPE => "Illegal seek"
            case SystemErrno.EROFS => "Read-only file system"
            case SystemErrno.EMLINK => "Too many links"
            case SystemErrno.EPIPE => "Broken pipe"
            case SystemErrno.EDOM => "Numerical argument out of domain"
            case SystemErrno.ERANGE => "Numerical result out of range"
            case SystemErrno.EDEADLK => "Resource deadlock avoided"
            case SystemErrno.ENAMETOOLONG => "File name too long"
            case SystemErrno.ENOLCK => "No locks available"
            case SystemErrno.ENOSYS => "Function not implemented"
            case SystemErrno.ENOTEMPTY => "Directory not empty"
            case SystemErrno.ELOOP => "Too many levels of symbolic links"
            case SystemErrno.EWOULDBLOCK => "Resource temporarily unavailable"
            case SystemErrno.ENOMSG => "No message of desired type"
            case SystemErrno.EIDRM => "Identifier removed"
            case SystemErrno.ECHRNG => "Channel number out of range"
            case SystemErrno.EL2NSYNC => "Level 2 not synchronized"
            case SystemErrno.EL3HLT => "Level 3 halted"
            case SystemErrno.EL3RST => "Level 3 reset"
            case SystemErrno.ELNRNG => "Link number out of range"
            case SystemErrno.EUNATCH => "Protocol driver not attached"
            case SystemErrno.ENOCSI => "No CSI structure available"
            case SystemErrno.EL2HLT => "Level 2 halted"
            case SystemErrno.EBADE => "Invalid exchange"
            case SystemErrno.EBADR => "Invalid request descriptor"
            case SystemErrno.EXFULL => "Exchange full"
            case SystemErrno.ENOANO => "No anode"
            case SystemErrno.EBADRQC => "Invalid request code"
            case SystemErrno.EBADSLT => "Invalid slot"
            case SystemErrno.EDEADLOCK => "Resource deadlock avoided"
            case SystemErrno.EBFONT => "Bad font file format"
            case SystemErrno.ENOSTR => "Device not a stream"
            case SystemErrno.ENODATA => "No data available"
            case SystemErrno.ETIME => "Timer expired"
            case SystemErrno.ENOSR => "Out of streams resources"
            case SystemErrno.ENONET => "Machine is not on the network"
            case SystemErrno.ENOPKG => "Package not installed"
            case SystemErrno.EREMOTE => "Object is remote"
            case SystemErrno.ENOLINK => "Link has been severed"
            case SystemErrno.EADV => "Advertise error"
            case SystemErrno.ESRMNT => "Srmount error"
            case SystemErrno.ECOMM => "Communication error on send"
            case SystemErrno.EPROTO => "Protocol error"
            case SystemErrno.EMULTIHOP => "Multihop attempted"
            case SystemErrno.EDOTDOT => "RFS specific error"
            case SystemErrno.EBADMSG => "Bad message"
            case SystemErrno.EOVERFLOW => "Value too large for defined data type"
            case SystemErrno.ENOTUNIQ => "Name not unique on network"
            case SystemErrno.EBADFD => "File descriptor in bad state"
            case SystemErrno.EREMCHG => "Remote address changed"
            case SystemErrno.ELIBACC => "Can not access a needed shared library"
            case SystemErrno.ELIBBAD => "Accessing a corrupted shared library"
            case SystemErrno.ELIBSCN => ".lib section in a.out corrupted"
            case SystemErrno.ELIBMAX => "Attempting to link in too many shared libraries"
            case SystemErrno.ELIBEXEC => "Cannot exec a shared library directly"
            case SystemErrno.EILSEQ => "Invalid or incomplete multibyte or wide character"
            case SystemErrno.ERESTART => "Interrupted system call should be restarted"
            case SystemErrno.ESTRPIPE => "Streams pipe error"
            case SystemErrno.EUSERS => "Too many users"
            case SystemErrno.ENOTSOCK => "Socket operation on non-socket"
            case SystemErrno.EDESTADDRREQ => "Destination address required"
            case SystemErrno.EMSGSIZE => "Message too long"
            case SystemErrno.EPROTOTYPE => "Protocol wrong type for socket"
            case SystemErrno.ENOPROTOOPT => "Protocol not available"
            case SystemErrno.EPROTONOSUPPORT => "Protocol not supported"
            case SystemErrno.ESOCKTNOSUPPORT => "Socket type not supported"
            case SystemErrno.EOPNOTSUPP => "Operation not supported"
            case SystemErrno.EPFNOSUPPORT => "Protocol family not supported"
            case SystemErrno.EAFNOSUPPORT => "Address family not supported by protocol"
            case SystemErrno.EADDRINUSE => "Address already in use"
            case SystemErrno.EADDRNOTAVAIL => "Cannot assign requested address"
            case SystemErrno.ENETDOWN => "Network is down"
            case SystemErrno.ENETUNREACH => "Network is unreachable"
            case SystemErrno.ENETRESET => "Network dropped connection on reset"
            case SystemErrno.ECONNABORTED => "Software caused connection abort"
            case SystemErrno.ECONNRESET => "Connection reset by peer"
            case SystemErrno.ENOBUFS => "No buffer space available"
            case SystemErrno.EISCONN => "Transport endpoint is already connected"
            case SystemErrno.ENOTCONN => "Transport endpoint is not connected"
            case SystemErrno.ESHUTDOWN => "Cannot send after transport endpoint shutdown"
            case SystemErrno.ETOOMANYREFS => "Too many references: cannot splice"
            case SystemErrno.ETIMEDOUT => "Connection timed out"
            case SystemErrno.ECONNREFUSED => "Connection refused"
            case SystemErrno.EHOSTDOWN => "Host is down"
            case SystemErrno.EHOSTUNREACH => "No route to host"
            case SystemErrno.EALREADY => "Operation already in progress"
            case SystemErrno.EINPROGRESS => "Operation now in progress"
            case SystemErrno.ESTALE => "Stale file handle"
            case SystemErrno.EUCLEAN => "Structure needs cleaning"
            case SystemErrno.ENOTNAM => "Not a XENIX named type file"
            case SystemErrno.ENAVAIL => "No XENIX semaphores available"
            case SystemErrno.EISNAM => "Is a named type file"
            case SystemErrno.EREMOTEIO => "Remote I/O error"
            case SystemErrno.EDQUOT => "Disk quota exceeded"
            case SystemErrno.ENOMEDIUM => "No medium found"
            case SystemErrno.EMEDIUMTYPE => "Wrong medium type"
            case SystemErrno.ECANCELED => "Operation canceled"
            case SystemErrno.ENOKEY => "Required key not available"
            case SystemErrno.EKEYEXPIRED => "Key has expired"
            case SystemErrno.EKEYREVOKED => "Key has been revoked"
            case SystemErrno.EKEYREJECTED => "Key was rejected by service"
            case SystemErrno.EOWNERDEAD => "Owner died"
            case SystemErrno.ENOTRECOVERABLE => "State not recoverable"
            case SystemErrno.EHWPOISON => "Memory page has hardware error"
            case _ => COREUTILS_UNKNOWN
        }
    }
}

// ============================================================================
// posixErrorMessage - 从 errno 编号获取错误消息
// 严格翻译自: Bun 中的 strerror 等价函数
// ============================================================================

/// 从 errno 值获取 POSIX 错误消息
/// 对应 Bun: Error.msg() -> posixErrorMessage
public func posixErrorMessage(errno: Int64): ?String {
    let sysErrno = SystemErrno.fromRaw(UInt16(errno))
    return CoreutilsErrorMap.get(sysErrno)
}

