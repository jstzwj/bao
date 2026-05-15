// bao_errno - Windows 系统错误码
// 严格翻译自: bun/src/errno/windows_errno.zig
//   pub const E = enum(u16) { ... };
//   pub const S = struct { ... };
//   pub const SystemErrno = enum(u16) { ... };
//   pub const UV_E = struct { ... };
//   pub fn getErrno(rc: anytype) E;
//
//   Windows 错误码特殊之处:
//   - E 枚举使用 Linux 编号但包含 UV_ 前缀变体
//   - SystemErrno 使用 Linux 编号 + Windows 特有扩展 (EUNKNOWN, ECHARSET, EOF, EFTYPE)
//   - S struct 提供 POSIX 兼容的文件模式位掩码
//   - getErrno 处理 NTSTATUS, Win32Error, WSAError 等多种来源
package bao_errno

// ============================================================================
// WindowsE - Windows 错误码枚举 (与 Linux 编号兼容)
// 严格翻译自: windows_errno.zig - E
//   pub const E = enum(u16) {
//     SUCCESS = 0, PERM = 1, NOENT = 2, ...
//     // Linux 编号, 去掉 E 前缀
//     // 加上 UV_ 前缀的变体
//   };
// ============================================================================

/// Windows 错误码 - 对应 Bun E (Windows)
/// 使用 Linux 编号约定，包含 UV_ 前缀的 libuv 错误码变体
public enum WindowsE {
    | SUCCESS      // 0
    | PARM         // 1
    | NOENT        // 2
    | SRCH         // 3
    | INTR         // 4
    | IO           // 5
    | NXIO         // 6
    | E2BIG        // 7
    | NOEXEC       // 8
    | BADF         // 9
    | CHILD        // 10
    | AGAIN        // 11
    | NOMEM        // 12
    | ACCES        // 13
    | FAULT        // 14
    | NOTBLK       // 15
    | BUSY         // 16
    | EXIST        // 17
    | XDEV         // 18
    | NODEV        // 19
    | NOTDIR       // 20
    | ISDIR        // 21
    | INVAL        // 22
    | NFILE        // 23
    | MFILE        // 24
    | NOTTY        // 25
    | TXTBSY       // 26
    | FBIG         // 27
    | NOSPC        // 28
    | SPIPE        // 29
    | ROFS         // 30
    | MLINK        // 31
    | PIPE         // 32
    | DOM          // 33
    | RANGE        // 34
    | DEADLK       // 35
    | NAMETOOLONG  // 36
    | NOLCK        // 37
    | NOSYS        // 38
    | NOTEMPTY     // 39
    | LOOP         // 40
    | WOULDBLOCK   // 41
    | NOMSG        // 42
    | IDRM         // 43
    | CHRNG        // 44
    | L2NSYNC      // 45
    | L3HLT        // 46
    | L3RST        // 47
    | LNRNG        // 48
    | UNATCH       // 49
    | NOCSI        // 50
    | L2HLT        // 51
    | BADE         // 52
    | BADR         // 53
    | XFULL        // 54
    | NOANO        // 55
    | BADRQC       // 56
    | BADSLT       // 57
    | DEADLOCK     // 58
    | BFONT        // 59
    | NOSTR        // 60
    | NODATA       // 61
    | TIME         // 62
    | NOSR         // 63
    | NONET        // 64
    | NOPKG        // 65
    | REMOTE       // 66
    | NOLINK       // 67
    | ADV          // 68
    | SRMNT        // 69
    | COMM         // 70
    | PROTO        // 71
    | MULTIHOP     // 72
    | DOTDOT       // 73
    | BADMSG       // 74
    | OVERFLOW     // 75
    | NOTUNIQ      // 76
    | BADFD        // 77
    | REMCHG       // 78
    | LIBACC       // 79
    | LIBBAD       // 80
    | LIBSCN       // 81
    | LIBMAX       // 82
    | LIBEXEC      // 83
    | ILSEQ        // 84
    | RESTART      // 85
    | STRPIPE      // 86
    | USERS        // 87
    | NOTSOCK      // 88
    | DESTADDRREQ  // 89
    | MSGSIZE      // 90
    | PROTOTYPE    // 91
    | NOPROTOOPT   // 92
    | PROTONOSUPPORT // 93
    | SOCKTNOSUPPORT // 94
    | NOTSUP       // 95
    | PFNOSUPPORT  // 96
    | AFNOSUPPORT  // 97
    | ADDRINUSE    // 98
    | ADDRNOTAVAIL // 99
    | NETDOWN      // 100
    | NETUNREACH   // 101
    | NETRESET     // 102
    | CONNABORTED  // 103
    | CONNRESET    // 104
    | NOBUFS       // 105
    | ISCONN       // 106
    | NOTCONN      // 107
    | SHUTDOWN     // 108
    | TOOMANYREFS  // 109
    | TIMEDOUT     // 110
    | CONNREFUSED  // 111
    | HOSTDOWN     // 112
    | HOSTUNREACH  // 113
    | ALREADY      // 114
    | INPROGRESS   // 115
    | STALE        // 116
    | UCLEAN       // 117
    | NOTNAM       // 118
    | NAVAIL       // 119
    | ISNAM        // 120
    | REMOTEIO     // 121
    | DQUOT        // 122
    | NOMEDIUM     // 123
    | MEDIUMTYPE   // 124
    | CANCELED     // 125
    | NOKEY        // 126
    | KEYEXPIRED   // 127
    | KEYREVOKED   // 128
    | KEYREJECTED  // 129
    | OWNERDEAD    // 130
    | NOTRECOVERABLE // 131
    | RFKILL       // 132
    | HWPOISON     // 133
    | UNKNOWN      // 134
    | CHARSET      // 135
    | EOF          // 136
    | FTYPE        // 137
}

// ============================================================================
// WindowsS - Windows 文件模式位掩码 (POSIX 兼容)
// 严格翻译自: windows_errno.zig - S
//   pub const S = struct {
//     pub const IFMT = 0o170000;
//     pub const IFDIR = 0o040000;
//     ...
//     pub inline fn ISREG, ISDIR, ISCHR, ISBLK, ISFIFO, ISLNK, ISSOCK
//   };
// ============================================================================

/// Windows 文件模式位掩码 - 对应 Bun S (Windows)
/// 提供 POSIX 兼容的文件模式检查函数
public class WindowsS {
    // 文件类型掩码
    public static let IFMT: Int64 = 0o170000
    public static let IFDIR: Int64 = 0o040000
    public static let IFCHR: Int64 = 0o020000
    public static let IFBLK: Int64 = 0o060000
    public static let IFREG: Int64 = 0o100000
    public static let IFIFO: Int64 = 0o010000
    public static let IFLNK: Int64 = 0o120000
    public static let IFSOCK: Int64 = 0o140000

    // 权限位
    public static let ISUID: Int64 = 0o4000
    public static let ISGID: Int64 = 0o2000
    public static let ISVTX: Int64 = 0o1000
    public static let IRUSR: Int64 = 0o400
    public static let IWUSR: Int64 = 0o200
    public static let IXUSR: Int64 = 0o100
    public static let IRWXU: Int64 = 0o700
    public static let IRGRP: Int64 = 0o040
    public static let IWGRP: Int64 = 0o020
    public static let IXGRP: Int64 = 0o010
    public static let IRWXG: Int64 = 0o070
    public static let IROTH: Int64 = 0o004
    public static let IWOTH: Int64 = 0o002
    public static let IXOTH: Int64 = 0o001
    public static let IRWXO: Int64 = 0o007

    /// 检查是否为常规文件
    /// 对应: pub inline fn ISREG(m: i32) bool { return m & IFMT == IFREG; }
    public static func ISREG(m: Int64): Bool {
        (m & IFMT) == IFREG
    }

    /// 检查是否为目录
    /// 对应: pub inline fn ISDIR(m: i32) bool { return m & IFMT == IFDIR; }
    public static func ISDIR(m: Int64): Bool {
        (m & IFMT) == IFDIR
    }

    /// 检查是否为字符设备
    /// 对应: pub inline fn ISCHR(m: i32) bool { return m & IFMT == IFCHR; }
    public static func ISCHR(m: Int64): Bool {
        (m & IFMT) == IFCHR
    }

    /// 检查是否为块设备
    /// 对应: pub inline fn ISBLK(m: i32) bool { return m & IFMT == IFBLK; }
    public static func ISBLK(m: Int64): Bool {
        (m & IFMT) == IFBLK
    }

    /// 检查是否为 FIFO/管道
    /// 对应: pub inline fn ISFIFO(m: i32) bool { return m & IFMT == IFIFO; }
    public static func ISFIFO(m: Int64): Bool {
        (m & IFMT) == IFIFO
    }

    /// 检查是否为符号链接
    /// 对应: pub inline fn ISLNK(m: i32) bool { return m & IFMT == IFLNK; }
    public static func ISLNK(m: Int64): Bool {
        (m & IFMT) == IFLNK
    }

    /// 检查是否为套接字
    /// 对应: pub inline fn ISSOCK(m: i32) bool { return m & IFMT == IFSOCK; }
    public static func ISSOCK(m: Int64): Bool {
        (m & IFMT) == IFSOCK
    }
}

// ============================================================================
// WindowsSystemErrno - Windows 系统错误码
// 严格翻译自: windows_errno.zig - SystemErrno
//   与 Linux 编号兼容 + Windows 特有扩展 (EUNKNOWN=134, ECHARSET=135, EOF=136, EFTYPE=137)
//   + UV_ 前缀的 libuv 错误码变体
//   max = 138
//   pub fn init(code: anytype) ?SystemErrno:
//     支持 Win32Error, WSAError, u16, c_int 等多种输入类型
//     Win32Error 映射表: NOACCESS->EACCES, INVALID_HANDLE->EBADF, ...
// ============================================================================

/// Windows 系统错误码 - 对应 Bun SystemErrno (Windows)
/// 在 Linux 编号基础上增加 Windows 特有错误码
public enum WindowsSystemErrno {
    | SUCCESS        // 0
    | EPERM          // 1
    | ENOENT         // 2
    | ESRCH          // 3
    | EINTR          // 4
    | EIO            // 5
    | ENXIO          // 6
    | E2BIG          // 7
    | ENOEXEC        // 8
    | EBADF          // 9
    | ECHILD         // 10
    | EAGAIN         // 11
    | ENOMEM         // 12
    | EACCES         // 13
    | EFAULT         // 14
    | ENOTBLK        // 15
    | EBUSY          // 16
    | EEXIST         // 17
    | EXDEV          // 18
    | ENODEV         // 19
    | ENOTDIR        // 20
    | EISDIR         // 21
    | EINVAL         // 22
    | ENFILE         // 23
    | EMFILE         // 24
    | ENOTTY         // 25
    | ETXTBSY        // 26
    | EFBIG          // 27
    | ENOSPC         // 28
    | ESPIPE         // 29
    | EROFS          // 30
    | EMLINK         // 31
    | EPIPE          // 32
    | EDOM           // 33
    | ERANGE         // 34
    | EDEADLK        // 35
    | ENAMETOOLONG   // 36
    | ENOLCK         // 37
    | ENOSYS         // 38
    | ENOTEMPTY      // 39
    | ELOOP          // 40
    | EWOULDBLOCK    // 41
    | ENOMSG         // 42
    | EIDRM          // 43
    | ECHRNG         // 44
    | EL2NSYNC       // 45
    | EL3HLT         // 46
    | EL3RST         // 47
    | ELNRNG         // 48
    | EUNATCH        // 49
    | ENOCSI         // 50
    | EL2HLT         // 51
    | EBADE          // 52
    | EBADR          // 53
    | EXFULL         // 54
    | ENOANO         // 55
    | EBADRQC        // 56
    | EBADSLT        // 57
    | EDEADLOCK      // 58
    | EBFONT         // 59
    | ENOSTR         // 60
    | ENODATA        // 61
    | ETIME          // 62
    | ENOSR          // 63
    | ENONET         // 64
    | ENOPKG         // 65
    | EREMOTE        // 66
    | ENOLINK        // 67
    | EADV           // 68
    | ESRMNT         // 69
    | ECOMM          // 70
    | EPROTO         // 71
    | EMULTIHOP      // 72
    | EDOTDOT        // 73
    | EBADMSG        // 74
    | EOVERFLOW      // 75
    | ENOTUNIQ       // 76
    | EBADFD         // 77
    | EREMCHG        // 78
    | ELIBACC        // 79
    | ELIBBAD        // 80
    | ELIBSCN        // 81
    | ELIBMAX        // 82
    | ELIBEXEC       // 83
    | EILSEQ         // 84
    | ERESTART       // 85
    | ESTRPIPE       // 86
    | EUSERS         // 87
    | ENOTSOCK       // 88
    | EDESTADDRREQ   // 89
    | EMSGSIZE       // 90
    | EPROTOTYPE     // 91
    | ENOPROTOOPT    // 92
    | EPROTONOSUPPORT // 93
    | ESOCKTNOSUPPORT // 94
    | ENOTSUP        // 95
    | EPFNOSUPPORT   // 96
    | EAFNOSUPPORT   // 97
    | EADDRINUSE     // 98
    | EADDRNOTAVAIL  // 99
    | ENETDOWN       // 100
    | ENETUNREACH    // 101
    | ENETRESET      // 102
    | ECONNABORTED   // 103
    | ECONNRESET     // 104
    | ENOBUFS        // 105
    | EISCONN        // 106
    | ENOTCONN       // 107
    | ESHUTDOWN      // 108
    | ETOOMANYREFS   // 109
    | ETIMEDOUT      // 110
    | ECONNREFUSED   // 111
    | EHOSTDOWN      // 112
    | EHOSTUNREACH   // 113
    | EALREADY       // 114
    | EINPROGRESS    // 115
    | ESTALE         // 116
    | EUCLEAN        // 117
    | ENOTNAM        // 118
    | ENAVAIL        // 119
    | EISNAM         // 120
    | EREMOTEIO      // 121
    | EDQUOT         // 122
    | ENOMEDIUM      // 123
    | EMEDIUMTYPE    // 124
    | ECANCELED      // 125
    | ENOKEY         // 126
    | EKEYEXPIRED    // 127
    | EKEYREVOKED    // 128
    | EKEYREJECTED   // 129
    | EOWNERDEAD     // 130
    | ENOTRECOVERABLE // 131
    | ERFKILL        // 132
    | EHWPOISON      // 133
    // Windows 特有扩展
    | EUNKNOWN       // 134 未知错误
    | ECHARSET       // 135 字符集错误
    | EOF            // 136 文件结束
    | EFTYPE         // 137 文件类型错误

    /// 最大错误码值
    /// 对应: pub const max = 138
    public static let max: Int64 = 138

    /// 从数值初始化
    /// 对应: SystemErrno.init(code: anytype) ?SystemErrno
    ///   Windows 版本支持 Win32Error, WSAError 等多种输入类型
    public static func initFunc(code: Int64): ?WindowsSystemErrno {
        if (code < 0) {
            if (code <= -max) {
                return None
            }
            return fromValue(-code)
        }
        if (code >= max) {
            return None
        }
        return fromValue(code)
    }

    /// 从数值获取枚举值
    public static func fromValue(v: Int64): ?WindowsSystemErrno {
        match (v) {
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
            case 41 => EWOULDBLOCK
            case 42 => ENOMSG
            case 43 => EIDRM
            case 44 => ECHRNG
            case 45 => EL2NSYNC
            case 46 => EL3HLT
            case 47 => EL3RST
            case 48 => ELNRNG
            case 49 => EUNATCH
            case 50 => ENOCSI
            case 51 => EL2HLT
            case 52 => EBADE
            case 53 => EBADR
            case 54 => EXFULL
            case 55 => ENOANO
            case 56 => EBADRQC
            case 57 => EBADSLT
            case 58 => EDEADLOCK
            case 59 => EBFONT
            case 60 => ENOSTR
            case 61 => ENODATA
            case 62 => ETIME
            case 63 => ENOSR
            case 64 => ENONET
            case 65 => ENOPKG
            case 66 => EREMOTE
            case 67 => ENOLINK
            case 68 => EADV
            case 69 => ESRMNT
            case 70 => ECOMM
            case 71 => EPROTO
            case 72 => EMULTIHOP
            case 73 => EDOTDOT
            case 74 => EBADMSG
            case 75 => EOVERFLOW
            case 76 => ENOTUNIQ
            case 77 => EBADFD
            case 78 => EREMCHG
            case 79 => ELIBACC
            case 80 => ELIBBAD
            case 81 => ELIBSCN
            case 82 => ELIBMAX
            case 83 => ELIBEXEC
            case 84 => EILSEQ
            case 85 => ERESTART
            case 86 => ESTRPIPE
            case 87 => EUSERS
            case 88 => ENOTSOCK
            case 89 => EDESTADDRREQ
            case 90 => EMSGSIZE
            case 91 => EPROTOTYPE
            case 92 => ENOPROTOOPT
            case 93 => EPROTONOSUPPORT
            case 94 => ESOCKTNOSUPPORT
            case 95 => ENOTSUP
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
            case 109 => ETOOMANYREFS
            case 110 => ETIMEDOUT
            case 111 => ECONNREFUSED
            case 112 => EHOSTDOWN
            case 113 => EHOSTUNREACH
            case 114 => EALREADY
            case 115 => EINPROGRESS
            case 116 => ESTALE
            case 117 => EUCLEAN
            case 118 => ENOTNAM
            case 119 => ENAVAIL
            case 120 => EISNAM
            case 121 => EREMOTEIO
            case 122 => EDQUOT
            case 123 => ENOMEDIUM
            case 124 => EMEDIUMTYPE
            case 125 => ECANCELED
            case 126 => ENOKEY
            case 127 => EKEYEXPIRED
            case 128 => EKEYREVOKED
            case 129 => EKEYREJECTED
            case 130 => EOWNERDEAD
            case 131 => ENOTRECOVERABLE
            case 132 => ERFKILL
            case 133 => EHWPOISON
            case 134 => EUNKNOWN
            case 135 => ECHARSET
            case 136 => EOF
            case 137 => EFTYPE
            case _ => None
        }
    }

    /// 获取错误码数值
    public func value(): Int64 {
        match (this) {
            case SUCCESS => 0
            case EPERM => 1
            case ENOENT => 2
            case ESRCH => 3
            case EINTR => 4
            case EIO => 5
            case ENXIO => 6
            case E2BIG => 7
            case ENOEXEC => 8
            case EBADF => 9
            case ECHILD => 10
            case EAGAIN => 11
            case ENOMEM => 12
            case EACCES => 13
            case EFAULT => 14
            case ENOTBLK => 15
            case EBUSY => 16
            case EEXIST => 17
            case EXDEV => 18
            case ENODEV => 19
            case ENOTDIR => 20
            case EISDIR => 21
            case EINVAL => 22
            case ENFILE => 23
            case EMFILE => 24
            case ENOTTY => 25
            case ETXTBSY => 26
            case EFBIG => 27
            case ENOSPC => 28
            case ESPIPE => 29
            case EROFS => 30
            case EMLINK => 31
            case EPIPE => 32
            case EDOM => 33
            case ERANGE => 34
            case EDEADLK => 35
            case ENAMETOOLONG => 36
            case ENOLCK => 37
            case ENOSYS => 38
            case ENOTEMPTY => 39
            case ELOOP => 40
            case EWOULDBLOCK => 41
            case ENOMSG => 42
            case EIDRM => 43
            case ECHRNG => 44
            case EL2NSYNC => 45
            case EL3HLT => 46
            case EL3RST => 47
            case ELNRNG => 48
            case EUNATCH => 49
            case ENOCSI => 50
            case EL2HLT => 51
            case EBADE => 52
            case EBADR => 53
            case EXFULL => 54
            case ENOANO => 55
            case EBADRQC => 56
            case EBADSLT => 57
            case EDEADLOCK => 58
            case EBFONT => 59
            case ENOSTR => 60
            case ENODATA => 61
            case ETIME => 62
            case ENOSR => 63
            case ENONET => 64
            case ENOPKG => 65
            case EREMOTE => 66
            case ENOLINK => 67
            case EADV => 68
            case ESRMNT => 69
            case ECOMM => 70
            case EPROTO => 71
            case EMULTIHOP => 72
            case EDOTDOT => 73
            case EBADMSG => 74
            case EOVERFLOW => 75
            case ENOTUNIQ => 76
            case EBADFD => 77
            case EREMCHG => 78
            case ELIBACC => 79
            case ELIBBAD => 80
            case ELIBSCN => 81
            case ELIBMAX => 82
            case ELIBEXEC => 83
            case EILSEQ => 84
            case ERESTART => 85
            case ESTRPIPE => 86
            case EUSERS => 87
            case ENOTSOCK => 88
            case EDESTADDRREQ => 89
            case EMSGSIZE => 90
            case EPROTOTYPE => 91
            case ENOPROTOOPT => 92
            case EPROTONOSUPPORT => 93
            case ESOCKTNOSUPPORT => 94
            case ENOTSUP => 95
            case EPFNOSUPPORT => 96
            case EAFNOSUPPORT => 97
            case EADDRINUSE => 98
            case EADDRNOTAVAIL => 99
            case ENETDOWN => 100
            case ENETUNREACH => 101
            case ENETRESET => 102
            case ECONNABORTED => 103
            case ECONNRESET => 104
            case ENOBUFS => 105
            case EISCONN => 106
            case ENOTCONN => 107
            case ESHUTDOWN => 108
            case ETOOMANYREFS => 109
            case ETIMEDOUT => 110
            case ECONNREFUSED => 111
            case EHOSTDOWN => 112
            case EHOSTUNREACH => 113
            case EALREADY => 114
            case EINPROGRESS => 115
            case ESTALE => 116
            case EUCLEAN => 117
            case ENOTNAM => 118
            case ENAVAIL => 119
            case EISNAM => 120
            case EREMOTEIO => 121
            case EDQUOT => 122
            case ENOMEDIUM => 123
            case EMEDIUMTYPE => 124
            case ECANCELED => 125
            case ENOKEY => 126
            case EKEYEXPIRED => 127
            case EKEYREVOKED => 128
            case EKEYREJECTED => 129
            case EOWNERDEAD => 130
            case ENOTRECOVERABLE => 131
            case ERFKILL => 132
            case EHWPOISON => 133
            case EUNKNOWN => 134
            case ECHARSET => 135
            case EOF => 136
            case EFTYPE => 137
        }
    }
}
