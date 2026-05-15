// bao_errno - 系统错误码
// 严格翻译自: bun/src/errno/linux_errno.zig
//   pub const SystemErrno = enum(u16) { ... };
//   pub const UV_E = struct { ... };
package bao.errno

// ============================================================================
// SystemErrno - Linux 系统错误码
// 严格翻译自: linux_errno.zig - SystemErrno
//   pub const SystemErrno = enum(u16) { SUCCESS = 0, EPERM = 1, ... };
// ============================================================================

/// Linux 系统错误码 - 对应 Bun SystemErrno
public enum SystemErrno {
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
    | EAGAIN         // 11 资源暂时不可用
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
    | EDEADLK        // 35 资源死锁
    | ENAMETOOLONG   // 36 文件名过长
    | ENOLCK         // 37 记录锁不可用
    | ENOSYS         // 38 函数未实现
    | ENOTEMPTY      // 39 目录非空
    | ELOOP          // 40 符号链接过多
    | EWOULDBLOCK    // 41 操作将阻塞
    | ENOMSG         // 42 消息类型不匹配
    | EIDRM          // 43 标识符被移除
    | ECHRNG         // 44 信道号超出范围
    | EL2NSYNC       // 45 层级2未同步
    | EL3HLT         // 46 层级3停止
    | EL3RST         // 47 层级3重置
    | ELNRNG         // 48 链接号超出范围
    | EUNATCH        // 49 协议驱动程序未附加
    | ENOCSI         // 50 无可用 CSI 结构
    | EL2HLT         // 51 层级2停止
    | EBADE          // 52 无效的交换
    | EBADR          // 53 无效的请求描述符
    | EXFULL         // 54 交换区满
    | ENOANO         // 55 无匿名页
    | EBADRQC        // 56 无效的请求码
    | EBADSLT        // 57 无效的槽位
    | EDEADLOCK      // 58 死锁 (与 EDEADLK 相同)
    | EBFONT         // 59 无效的字体文件格式
    | ENOSTR         // 60 设备不是流
    | ENODATA        // 61 无可用数据
    | ETIME          // 62 定时器超时
    | ENOSR          // 63 流资源不足
    | ENONET         // 64 机器不在网络上
    | ENOPKG         // 65 包未安装
    | EREMOTE        // 66 对象是远程的
    | ENOLINK        // 67 链接已断开
    | EADV           // 68 广告错误
    | ESRMNT         // 69 Srmount 错误
    | ECOMM          // 70 通信错误
    | EPROTO         // 71 协议错误
    | EMULTIHOP      // 72 多跳尝试
    | EDOTDOT        // 73 RFS 特定错误
    | EBADMSG        // 74 不是数据消息
    | EOVERFLOW      // 75 值过大
    | ENOTUNIQ       // 76 名称在网络上不唯一
    | EBADFD         // 77 文件描述符状态错误
    | EREMCHG        // 78 远程地址已更改
    | ELIBACC        // 79 无法访问所需的共享库
    | ELIBBAD        // 80 访问损坏的共享库
    | ELIBSCN        // 81 .lib 段损坏
    | ELIBMAX        // 82 链接了过多的共享库
    | ELIBEXEC       // 83 无法执行共享库
    | EILSEQ         // 84 非法字节序列
    | ERESTART       // 85 中断的系统调用应重启
    | ESTRPIPE       // 86 流管道错误
    | EUSERS         // 87 用户过多
    | ENOTSOCK       // 88 在非套接字上执行套接字操作
    | EDESTADDRREQ   // 89 需要目标地址
    | EMSGSIZE       // 90 消息过长
    | EPROTOTYPE     // 91 协议类型错误
    | ENOPROTOOPT    // 92 协议不可用
    | EPROTONOSUPPORT // 93 不支持的协议
    | ESOCKTNOSUPPORT // 94 不支持的套接字类型
    | ENOTSUP        // 95 不支持的操作
    | EPFNOSUPPORT   // 96 不支持的协议族
    | EAFNOSUPPORT   // 97 不支持的地址族
    | EADDRINUSE     // 98 地址已在使用
    | EADDRNOTAVAIL  // 99 地址不可用
    | ENETDOWN       // 100 网络已断开
    | ENETUNREACH    // 101 网络不可达
    | ENETRESET      // 102 网络被对端重置
    | ECONNABORTED   // 103 连接被中止
    | ECONNRESET     // 104 连接被对端重置
    | ENOBUFS        // 105 缓冲区空间不足
    | EISCONN        // 106 传输端点已连接
    | ENOTCONN       // 107 传输端点未连接
    | ESHUTDOWN      // 108 传输端点已关闭
    | ETOOMANYREFS   // 109 引用过多
    | ETIMEDOUT      // 110 连接超时
    | ECONNREFUSED   // 111 连接被拒绝
    | EHOSTDOWN      // 112 主机已关闭
    | EHOSTUNREACH   // 113 主机不可达
    | EALREADY       // 114 操作已在进行
    | EINPROGRESS    // 115 操作正在进行
    | ESTALE         // 116 过期的文件句柄
    | EUCLEAN        // 117 结构需要清理
    | ENOTNAM        // 118 不是 XENIX 命名类型文件
    | ENAVAIL        // 119 无可用的 XENIX 信号量
    | EISNAM         // 120 是命名类型文件
    | EREMOTEIO      // 121 远程 I/O 错误
    | EDQUOT         // 122 磁盘配额超出
    | ENOMEDIUM      // 123 无介质
    | EMEDIUMTYPE    // 124 错误的介质类型
    | ECANCELED      // 125 操作被取消
    | ENOKEY         // 126 所需的密钥不可用
    | EKEYEXPIRED    // 127 密钥已过期
    | EKEYREVOKED    // 128 密钥已被撤销
    | EKEYREJECTED   // 129 密钥被拒绝
    | EOWNERDEAD     // 130 拥有者已死亡
    | ENOTRECOVERABLE // 131 状态不可恢复
    | ERFKILL        // 132 操作因 rfkill 而阻塞
    | EHWPOISON      // 133 内存页有硬件错误

    /// 最大错误码值
    public static let max: Int64 = 134

    /// 从数值初始化
    /// 对应 Bun SystemErrno.init()
    public static func init(code: Int64): ?SystemErrno {
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
    public static func fromValue(v: Int64): ?SystemErrno {
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
        }
    }
}

// ============================================================================
// UVE - libuv 错误码常量
// 严格翻译自: linux_errno.zig - UV_E
//   pub const UV_E = struct { ... };
// ============================================================================

/// libuv 错误码常量 - 对应 Bun UV_E
public class UVE {
    public static let E2BIG: Int64 = 7
    public static let ACCES: Int64 = 13
    public static let ADDRINUSE: Int64 = 98
    public static let ADDRNOTAVAIL: Int64 = 99
    public static let AFNOSUPPORT: Int64 = 97
    public static let AGAIN: Int64 = 11
    public static let ALREADY: Int64 = 114
    public static let BADF: Int64 = 9
    public static let BUSY: Int64 = 16
    public static let CANCELED: Int64 = 125
    public static let CONNABORTED: Int64 = 103
    public static let CONNREFUSED: Int64 = 111
    public static let CONNRESET: Int64 = 104
    public static let DESTADDRREQ: Int64 = 89
    public static let EXIST: Int64 = 17
    public static let FAULT: Int64 = 14
    public static let HOSTUNREACH: Int64 = 113
    public static let INTR: Int64 = 4
    public static let INVAL: Int64 = 22
    public static let IO: Int64 = 5
    public static let ISCONN: Int64 = 106
    public static let ISDIR: Int64 = 21
    public static let LOOP: Int64 = 40
    public static let MFILE: Int64 = 24
    public static let MSGSIZE: Int64 = 90
    public static let NAMETOOLONG: Int64 = 36
    public static let NETDOWN: Int64 = 100
    public static let NETUNREACH: Int64 = 101
    public static let NFILE: Int64 = 23
    public static let NOBUFS: Int64 = 105
    public static let NODEV: Int64 = 19
    public static let NOENT: Int64 = 2
    public static let NOMEM: Int64 = 12
    public static let NONET: Int64 = 64
    public static let NOSPC: Int64 = 28
    public static let NOSYS: Int64 = 38
    public static let NOTCONN: Int64 = 107
    public static let NOTDIR: Int64 = 20
    public static let NOTEMPTY: Int64 = 39
    public static let NOTSOCK: Int64 = 88
    public static let NOTSUP: Int64 = 95
    public static let PERM: Int64 = 1
    public static let PIPE: Int64 = 32
    public static let PROTO: Int64 = 71
    public static let PROTONOSUPPORT: Int64 = 93
    public static let PROTOTYPE: Int64 = 91
    public static let ROFS: Int64 = 30
    public static let SHUTDOWN: Int64 = 108
    public static let SPIPE: Int64 = 29
    public static let SRCH: Int64 = 3
    public static let TIMEDOUT: Int64 = 110
    public static let TXTBSY: Int64 = 26
    public static let XDEV: Int64 = 18
    public static let FBIG: Int64 = 27
    public static let NOPROTOOPT: Int64 = 92
    public static let RANGE: Int64 = 34
    public static let NXIO: Int64 = 6
    public static let MLINK: Int64 = 31
    public static let HOSTDOWN: Int64 = 112
    public static let REMOTEIO: Int64 = 121
    public static let NOTTY: Int64 = 25
    public static let ILSEQ: Int64 = 84
    public static let OVERFLOW: Int64 = 75
    public static let SOCKTNOSUPPORT: Int64 = 94
    public static let NODATA: Int64 = 61
    public static let UNATCH: Int64 = 49
    public static let NOEXEC: Int64 = 8
}
