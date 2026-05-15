// bao_errno - macOS/Darwin 系统错误码
// 严格翻译自: bun/src/errno/darwin_errno.zig
//   pub const SystemErrno = enum(u16) { SUCCESS = 0, EPERM = 1, ... };
//   pub const UV_E = struct { ... };
//   pub fn getErrno(rc: anytype) E;
//
//   Darwin 错误码与 Linux 有显著差异:
//   - 错误码编号不同 (如 EAGAIN=35 在 Darwin, EAGAIN=11 在 Linux)
//   - Darwin 有特有的错误码: EBADRPC, ERPCMISMATCH, EPROGUNAVAIL 等
//   - Darwin 没有 EWOULDBLOCK (使用 EAGAIN), 没有 Linux 特有的错误码
package bao_errno

// ============================================================================
// DarwinSystemErrno - macOS/Darwin 系统错误码
// 严格翻译自: darwin_errno.zig - SystemErrno
//
//   Zig 原始逻辑:
//     pub const SystemErrno = enum(u16) {
//         SUCCESS = 0, EPERM = 1, ENOENT = 2, ESRCH = 3, EINTR = 4,
//         EIO = 5, ENXIO = 6, E2BIG = 7, ENOEXEC = 8, EBADF = 9,
//         ECHILD = 10, EDEADLK = 11, ENOMEM = 12, EACCES = 13, EFAULT = 14,
//         ENOTBLK = 15, EBUSY = 16, EEXIST = 17, EXDEV = 18, ENODEV = 19,
//         ENOTDIR = 20, EISDIR = 21, EINVAL = 22, ENFILE = 23, EMFILE = 24,
//         ENOTTY = 25, ETXTBSY = 26, EFBIG = 27, ENOSPC = 28, ESPIPE = 29,
//         EROFS = 30, EMLINK = 31, EPIPE = 32, EDOM = 33, ERANGE = 34,
//         EAGAIN = 35, EINPROGRESS = 36, EALREADY = 37, ENOTSOCK = 38,
//         EDESTADDRREQ = 39, EMSGSIZE = 40, EPROTOTYPE = 41, ENOPROTOOPT = 42,
//         EPROTONOSUPPORT = 43, ESOCKTNOSUPPORT = 44, ENOTSUP = 45,
//         EPFNOSUPPORT = 46, EAFNOSUPPORT = 47, EADDRINUSE = 48,
//         EADDRNOTAVAIL = 49, ENETDOWN = 50, ENETUNREACH = 51, ENETRESET = 52,
//         ECONNABORTED = 53, ECONNRESET = 54, ENOBUFS = 55, EISCONN = 56,
//         ENOTCONN = 57, ESHUTDOWN = 58, ETOOMANYREFS = 59, ETIMEDOUT = 60,
//         ECONNREFUSED = 61, ELOOP = 62, ENAMETOOLONG = 63, EHOSTDOWN = 64,
//         EHOSTUNREACH = 65, ENOTEMPTY = 66, EPROCLIM = 67, EUSERS = 68,
//         EDQUOT = 69, ESTALE = 70, EREMOTE = 71, EBADRPC = 72,
//         ERPCMISMATCH = 73, EPROGUNAVAIL = 74, EPROGMISMATCH = 75,
//         EPROCUNAVAIL = 76, ENOLCK = 77, ENOSYS = 78, EFTYPE = 79,
//         EAUTH = 80, ENEEDAUTH = 81, EPWROFF = 82, EDEVERR = 83,
//         EOVERFLOW = 84, EBADEXEC = 85, EBADARCH = 86, ESHLIBVERS = 87,
//         EBADMACHO = 88, ECANCELED = 89, EIDRM = 90, ENOMSG = 91,
//         EILSEQ = 92, ENOATTR = 93, EBADMSG = 94, EMULTIHOP = 95,
//         ENODATA = 96, ENOLINK = 97, ENOSR = 98, ENOSTR = 99,
//         EPROTO = 100, ETIME = 101, EOPNOTSUPP = 102, ENOPOLICY = 103,
//         ENOTRECOVERABLE = 104, EOWNERDEAD = 105, EQFULL = 106,
//         pub const max = 107;
//     };
//
//   getErrno(rc):
//     if (rc == -1) return @enumFromInt(std.c._errno().*)
//     else return .SUCCESS
// ============================================================================

/// macOS/Darwin 系统错误码 - 对应 Bun SystemErrno (Darwin)
public enum DarwinSystemErrno {
    | SUCCESS        // 0
    | EPERM          // 1  操作不允许
    | ENOENT         // 2  文件或目录不存在
    | ESRCH          // 3  进程不存在
    | EINTR          // 4  系统调用被中断
    | EIO            // 5  I/O 错误
    | ENXIO          // 6  设备或地址不存在
    | E2BIG          // 7  参数列表过长
    | ENOEXEC        // 8  可执行文件格式错误
    | EBADF          // 9  文件描述符错误
    | ECHILD         // 10 子进程不存在
    | EDEADLK        // 11 资源死锁
    | ENOMEM         // 12 内存不足
    | EACCES         // 13 权限被拒绝
    | EFAULT         // 14 地址错误
    | ENOTBLK        // 15 需要块设备
    | EBUSY          // 16 设备或资源忙
    | EEXIST         // 17 文件已存在
    | EXDEV          // 18 跨设备链接
    | ENODEV         // 19 设备不存在
    | ENOTDIR        // 20 不是目录
    | EISDIR         // 21 是目录
    | EINVAL         // 22 无效参数
    | ENFILE         // 23 系统文件表溢出
    | EMFILE         // 24 打开文件过多
    | ENOTTY         // 25 不合适的 I/O 控制操作
    | ETXTBSY        // 26 文件正在使用
    | EFBIG          // 27 文件太大
    | ENOSPC         // 28 设备空间不足
    | ESPIPE         // 29 无效的定位操作
    | EROFS          // 30 只读文件系统
    | EMLINK         // 31 链接过多
    | EPIPE          // 32 管道破裂
    | EDOM           // 33 数学参数超出定义域
    | ERANGE         // 34 结果过大
    | EAGAIN         // 35 资源暂时不可用
    | EINPROGRESS    // 36 操作正在进行
    | EALREADY       // 37 操作已在进行
    | ENOTSOCK       // 38 在非套接字上执行套接字操作
    | EDESTADDRREQ   // 39 需要目标地址
    | EMSGSIZE       // 40 消息过长
    | EPROTOTYPE     // 41 协议类型错误
    | ENOPROTOOPT    // 42 协议不可用
    | EPROTONOSUPPORT // 43 不支持的协议
    | ESOCKTNOSUPPORT // 44 不支持的套接字类型
    | ENOTSUP        // 45 不支持的操作
    | EPFNOSUPPORT   // 46 不支持的协议族
    | EAFNOSUPPORT   // 47 不支持的地址族
    | EADDRINUSE     // 48 地址已在使用
    | EADDRNOTAVAIL  // 49 地址不可用
    | ENETDOWN       // 50 网络已断开
    | ENETUNREACH    // 51 网络不可达
    | ENETRESET      // 52 网络被对端重置
    | ECONNABORTED   // 53 连接被中止
    | ECONNRESET     // 54 连接被对端重置
    | ENOBUFS        // 55 缓冲区空间不足
    | EISCONN        // 56 传输端点已连接
    | ENOTCONN       // 57 传输端点未连接
    | ESHUTDOWN      // 58 传输端点已关闭
    | ETOOMANYREFS   // 59 引用过多
    | ETIMEDOUT      // 60 连接超时
    | ECONNREFUSED   // 61 连接被拒绝
    | ELOOP          // 62 符号链接过多
    | ENAMETOOLONG   // 63 文件名过长
    | EHOSTDOWN      // 64 主机已关闭
    | EHOSTUNREACH   // 65 主机不可达
    | ENOTEMPTY      // 66 目录非空
    | EPROCLIM       // 67 进程数限制 (Darwin 特有)
    | EUSERS         // 68 用户过多
    | EDQUOT         // 69 磁盘配额超出
    | ESTALE         // 70 过期的文件句柄
    | EREMOTE        // 71 对象是远程的
    | EBADRPC        // 72 RPC 结构错误 (Darwin 特有)
    | ERPCMISMATCH   // 73 RPC 版本不匹配 (Darwin 特有)
    | EPROGUNAVAIL   // 74 RPC 程序不可用 (Darwin 特有)
    | EPROGMISMATCH  // 75 RPC 程序版本不匹配 (Darwin 特有)
    | EPROCUNAVAIL   // 76 RPC 过程不可用 (Darwin 特有)
    | ENOLCK         // 77 记录锁不可用
    | ENOSYS         // 78 函数未实现
    | EFTYPE         // 79 不适当的文件类型或格式 (Darwin 特有)
    | EAUTH          // 80 认证错误 (Darwin 特有)
    | ENEEDAUTH      // 81 需要认证 (Darwin 特有)
    | EPWROFF        // 82 设备断电 (Darwin 特有)
    | EDEVERR        // 83 设备错误 (Darwin 特有)
    | EOVERFLOW      // 84 值过大
    | EBADEXEC       // 85 可执行文件格式错误 (Darwin 特有)
    | EBADARCH       // 86 架构不匹配 (Darwin 特有)
    | ESHLIBVERS     // 87 共享库版本错误 (Darwin 特有)
    | EBADMACHO      // 88 Mach-O 格式错误 (Darwin 特有)
    | ECANCELED      // 89 操作被取消
    | EIDRM          // 90 标识符被移除
    | ENOMSG         // 91 消息类型不匹配
    | EILSEQ         // 92 非法字节序列
    | ENOATTR        // 93 属性不存在 (Darwin 特有)
    | EBADMSG        // 94 不是数据消息
    | EMULTIHOP      // 95 多跳尝试
    | ENODATA        // 96 无可用数据
    | ENOLINK        // 97 链接已断开
    | ENOSR          // 98 流资源不足
    | ENOSTR         // 99 设备不是流
    | EPROTO         // 100 协议错误
    | ETIME          // 101 定时器超时
    | EOPNOTSUPP     // 102 不支持的操作 (套接字)
    | ENOPOLICY      // 103 策略未找到 (Darwin 特有)
    | ENOTRECOVERABLE // 104 状态不可恢复
    | EOWNERDEAD     // 105 拥有者已死亡
    | EQFULL         // 106 输出队列满 (Darwin 特有)

    /// 最大错误码值
    /// 对应: pub const max = 107
    public static let max: Int64 = 107

    /// 从数值初始化
    /// 对应: SystemErrno.init(code: anytype) ?SystemErrno
    public static func initFunc(code: Int64): ?DarwinSystemErrno {
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
    public static func fromValue(v: Int64): ?DarwinSystemErrno {
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
            case 11 => EDEADLK
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
            case 35 => EAGAIN
            case 36 => EINPROGRESS
            case 37 => EALREADY
            case 38 => ENOTSOCK
            case 39 => EDESTADDRREQ
            case 40 => EMSGSIZE
            case 41 => EPROTOTYPE
            case 42 => ENOPROTOOPT
            case 43 => EPROTONOSUPPORT
            case 44 => ESOCKTNOSUPPORT
            case 45 => ENOTSUP
            case 46 => EPFNOSUPPORT
            case 47 => EAFNOSUPPORT
            case 48 => EADDRINUSE
            case 49 => EADDRNOTAVAIL
            case 50 => ENETDOWN
            case 51 => ENETUNREACH
            case 52 => ENETRESET
            case 53 => ECONNABORTED
            case 54 => ECONNRESET
            case 55 => ENOBUFS
            case 56 => EISCONN
            case 57 => ENOTCONN
            case 58 => ESHUTDOWN
            case 59 => ETOOMANYREFS
            case 60 => ETIMEDOUT
            case 61 => ECONNREFUSED
            case 62 => ELOOP
            case 63 => ENAMETOOLONG
            case 64 => EHOSTDOWN
            case 65 => EHOSTUNREACH
            case 66 => ENOTEMPTY
            case 67 => EPROCLIM
            case 68 => EUSERS
            case 69 => EDQUOT
            case 70 => ESTALE
            case 71 => EREMOTE
            case 72 => EBADRPC
            case 73 => ERPCMISMATCH
            case 74 => EPROGUNAVAIL
            case 75 => EPROGMISMATCH
            case 76 => EPROCUNAVAIL
            case 77 => ENOLCK
            case 78 => ENOSYS
            case 79 => EFTYPE
            case 80 => EAUTH
            case 81 => ENEEDAUTH
            case 82 => EPWROFF
            case 83 => EDEVERR
            case 84 => EOVERFLOW
            case 85 => EBADEXEC
            case 86 => EBADARCH
            case 87 => ESHLIBVERS
            case 88 => EBADMACHO
            case 89 => ECANCELED
            case 90 => EIDRM
            case 91 => ENOMSG
            case 92 => EILSEQ
            case 93 => ENOATTR
            case 94 => EBADMSG
            case 95 => EMULTIHOP
            case 96 => ENODATA
            case 97 => ENOLINK
            case 98 => ENOSR
            case 99 => ENOSTR
            case 100 => EPROTO
            case 101 => ETIME
            case 102 => EOPNOTSUPP
            case 103 => ENOPOLICY
            case 104 => ENOTRECOVERABLE
            case 105 => EOWNERDEAD
            case 106 => EQFULL
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
            case EDEADLK => 11
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
            case EAGAIN => 35
            case EINPROGRESS => 36
            case EALREADY => 37
            case ENOTSOCK => 38
            case EDESTADDRREQ => 39
            case EMSGSIZE => 40
            case EPROTOTYPE => 41
            case ENOPROTOOPT => 42
            case EPROTONOSUPPORT => 43
            case ESOCKTNOSUPPORT => 44
            case ENOTSUP => 45
            case EPFNOSUPPORT => 46
            case EAFNOSUPPORT => 47
            case EADDRINUSE => 48
            case EADDRNOTAVAIL => 49
            case ENETDOWN => 50
            case ENETUNREACH => 51
            case ENETRESET => 52
            case ECONNABORTED => 53
            case ECONNRESET => 54
            case ENOBUFS => 55
            case EISCONN => 56
            case ENOTCONN => 57
            case ESHUTDOWN => 58
            case ETOOMANYREFS => 59
            case ETIMEDOUT => 60
            case ECONNREFUSED => 61
            case ELOOP => 62
            case ENAMETOOLONG => 63
            case EHOSTDOWN => 64
            case EHOSTUNREACH => 65
            case ENOTEMPTY => 66
            case EPROCLIM => 67
            case EUSERS => 68
            case EDQUOT => 69
            case ESTALE => 70
            case EREMOTE => 71
            case EBADRPC => 72
            case ERPCMISMATCH => 73
            case EPROGUNAVAIL => 74
            case EPROGMISMATCH => 75
            case EPROCUNAVAIL => 76
            case ENOLCK => 77
            case ENOSYS => 78
            case EFTYPE => 79
            case EAUTH => 80
            case ENEEDAUTH => 81
            case EPWROFF => 82
            case EDEVERR => 83
            case EOVERFLOW => 84
            case EBADEXEC => 85
            case EBADARCH => 86
            case ESHLIBVERS => 87
            case EBADMACHO => 88
            case ECANCELED => 89
            case EIDRM => 90
            case ENOMSG => 91
            case EILSEQ => 92
            case ENOATTR => 93
            case EBADMSG => 94
            case EMULTIHOP => 95
            case ENODATA => 96
            case ENOLINK => 97
            case ENOSR => 98
            case ENOSTR => 99
            case EPROTO => 100
            case ETIME => 101
            case EOPNOTSUPP => 102
            case ENOPOLICY => 103
            case ENOTRECOVERABLE => 104
            case EOWNERDEAD => 105
            case EQFULL => 106
        }
    }
}

// ============================================================================
// DarwinUVE - Darwin libuv 错误码常量
// 严格翻译自: darwin_errno.zig - UV_E
//   pub const UV_E = struct { ... };
//   值 = @intFromEnum(SystemErrno.XXX) 即使用 Darwin 的枚举整数值
// ============================================================================

/// Darwin libuv 错误码常量 - 对应 Bun UV_E (Darwin)
public class DarwinUVE {
    public static let E2BIG: Int64 = 7
    public static let ACCES: Int64 = 13
    public static let ADDRINUSE: Int64 = 48
    public static let ADDRNOTAVAIL: Int64 = 49
    public static let AFNOSUPPORT: Int64 = 47
    public static let AGAIN: Int64 = 35
    public static let ALREADY: Int64 = 37
    public static let BADF: Int64 = 9
    public static let BUSY: Int64 = 16
    public static let CANCELED: Int64 = 89
    public static let CONNABORTED: Int64 = 53
    public static let CONNREFUSED: Int64 = 61
    public static let CONNRESET: Int64 = 54
    public static let DESTADDRREQ: Int64 = 39
    public static let EXIST: Int64 = 17
    public static let FAULT: Int64 = 14
    public static let HOSTUNREACH: Int64 = 65
    public static let INTR: Int64 = 4
    public static let INVAL: Int64 = 22
    public static let IO: Int64 = 5
    public static let ISCONN: Int64 = 56
    public static let ISDIR: Int64 = 21
    public static let LOOP: Int64 = 62
    public static let MFILE: Int64 = 24
    public static let MSGSIZE: Int64 = 40
    public static let NAMETOOLONG: Int64 = 63
    public static let NETDOWN: Int64 = 50
    public static let NETUNREACH: Int64 = 51
    public static let NFILE: Int64 = 23
    public static let NOBUFS: Int64 = 55
    public static let NODEV: Int64 = 19
    public static let NOENT: Int64 = 2
    public static let NOMEM: Int64 = 12
    public static let NOSPC: Int64 = 28
    public static let NOSYS: Int64 = 78
    public static let NOTCONN: Int64 = 57
    public static let NOTDIR: Int64 = 20
    public static let NOTEMPTY: Int64 = 66
    public static let NOTSOCK: Int64 = 38
    public static let NOTSUP: Int64 = 45
    public static let PERM: Int64 = 1
    public static let PIPE: Int64 = 32
    public static let PROTO: Int64 = 100
    public static let PROTONOSUPPORT: Int64 = 43
    public static let PROTOTYPE: Int64 = 41
    public static let ROFS: Int64 = 30
    public static let SHUTDOWN: Int64 = 58
    public static let SPIPE: Int64 = 29
    public static let SRCH: Int64 = 3
    public static let TIMEDOUT: Int64 = 60
    public static let TXTBSY: Int64 = 26
    public static let XDEV: Int64 = 18
    public static let FBIG: Int64 = 27
    public static let NOPROTOOPT: Int64 = 42
    public static let RANGE: Int64 = 34
    public static let NXIO: Int64 = 6
    public static let MLINK: Int64 = 31
    public static let HOSTDOWN: Int64 = 64
    public static let NOTTY: Int64 = 25
    public static let ILSEQ: Int64 = 92
    public static let OVERFLOW: Int64 = 84
    public static let SOCKTNOSUPPORT: Int64 = 44
    public static let NOEXEC: Int64 = 8
}
