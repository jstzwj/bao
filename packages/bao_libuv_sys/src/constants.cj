// 严格翻译自: src/libuv_sys/libuv.zig
package bao_libuv_sys

// ============================================================================
// libuv 常量 - 错误码
// 严格翻译自: libuv.zig UV_E2BIG 等
// ============================================================================
public let UV_E2BIG: Int32 = -4093
public let UV_EACCES: Int32 = -4092
public let UV_EADDRINUSE: Int32 = -4091
public let UV_EADDRNOTAVAIL: Int32 = -4090
public let UV_EAFNOSUPPORT: Int32 = -4089
public let UV_EAGAIN: Int32 = -4088
public let UV_EAI_ADDRFAMILY: Int32 = -3000
public let UV_EAI_AGAIN: Int32 = -3001
public let UV_EAI_BADFLAGS: Int32 = -3002
public let UV_EAI_BADHINTS: Int32 = -3013
public let UV_EAI_CANCELED: Int32 = -3003
public let UV_EAI_FAIL: Int32 = -3004
public let UV_EAI_FAMILY: Int32 = -3005
public let UV_EAI_MEMORY: Int32 = -3006
public let UV_EAI_NODATA: Int32 = -3007
public let UV_EAI_NONAME: Int32 = -3008
public let UV_EAI_OVERFLOW: Int32 = -3009
public let UV_EAI_PROTOCOL: Int32 = -3014
public let UV_EAI_SERVICE: Int32 = -3010
public let UV_EAI_SOCKTYPE: Int32 = -3011
public let UV_EALREADY: Int32 = -4084
public let UV_EBADF: Int32 = -4083
public let UV_EBUSY: Int32 = -4082
public let UV_ECANCELED: Int32 = -4081
public let UV_ECHARSET: Int32 = -4080
public let UV_ECONNABORTED: Int32 = -4079
public let UV_ECONNREFUSED: Int32 = -4078
public let UV_ECONNRESET: Int32 = -4077
public let UV_EDESTADDRREQ: Int32 = -4076
public let UV_EEXIST: Int32 = -4075
public let UV_EFAULT: Int32 = -4074
public let UV_EFBIG: Int32 = -4036
public let UV_EHOSTUNREACH: Int32 = -4073
public let UV_EINTR: Int32 = -4072
public let UV_EINVAL: Int32 = -4071
public let UV_EIO: Int32 = -4070
public let UV_EISCONN: Int32 = -4069
public let UV_EISDIR: Int32 = -4068
public let UV_ELOOP: Int32 = -4067
public let UV_EMFILE: Int32 = -4066
public let UV_EMSGSIZE: Int32 = -4065
public let UV_ENAMETOOLONG: Int32 = -4064
public let UV_ENETDOWN: Int32 = -4063
public let UV_ENETUNREACH: Int32 = -4062
public let UV_ENFILE: Int32 = -4061
public let UV_ENOBUFS: Int32 = -4060
public let UV_ENODEV: Int32 = -4059
public let UV_ENOENT: Int32 = -4058
public let UV_ENOMEM: Int32 = -4057
public let UV_ENONET: Int32 = -4056
public let UV_ENOPROTOOPT: Int32 = -4035
public let UV_ENOSPC: Int32 = -4055
public let UV_ENOSYS: Int32 = -4054
public let UV_ENOTCONN: Int32 = -4053
public let UV_ENOTDIR: Int32 = -4052
public let UV_ENOTEMPTY: Int32 = -4051
public let UV_ENOTSOCK: Int32 = -4050
public let UV_ENOTSUP: Int32 = -4049
public let UV_EOVERFLOW: Int32 = -4026
public let UV_EPERM: Int32 = -4048
public let UV_EPIPE: Int32 = -4047
public let UV_EPROTO: Int32 = -4046
public let UV_EPROTONOSUPPORT: Int32 = -4045
public let UV_EPROTOTYPE: Int32 = -4044
public let UV_ERANGE: Int32 = -4034
public let UV_EROFS: Int32 = -4043
public let UV_ESHUTDOWN: Int32 = -4042
public let UV_ESPIPE: Int32 = -4041
public let UV_ESRCH: Int32 = -4040
public let UV_ETIMEDOUT: Int32 = -4039
public let UV_ETXTBSY: Int32 = -4038
public let UV_EXDEV: Int32 = -4037
public let UV_UNKNOWN: Int32 = -4094
public let UV_EOF: Int32 = -4095
public let UV_ENXIO: Int32 = -4033
public let UV_EMLINK: Int32 = -4032
public let UV_EHOSTDOWN: Int32 = -4031
public let UV_EREMOTEIO: Int32 = -4030
public let UV_ENOTTY: Int32 = -4029
public let UV_EFTYPE: Int32 = -4028
public let UV_EILSEQ: Int32 = -4027
public let UV_ESOCKTNOSUPPORT: Int32 = -4025
public let UV_ENODATA: Int32 = -4024
public let UV_EUNATCH: Int32 = -4023
public let UV_ENOEXEC: Int32 = -4022
public let UV_ERRNO_MAX: Int32 = -4096

// ============================================================================
// 版本常量
// 严格翻译自: libuv.zig UV_VERSION_*
// ============================================================================
public let UV_VERSION_MAJOR: Int32 = 1
public let UV_VERSION_MINOR: Int32 = 51
public let UV_VERSION_PATCH: Int32 = 0
public let UV_VERSION_IS_RELEASE: Int32 = 1

// ============================================================================
// Handle/Req 类型常量
// 严格翻译自: libuv.zig UV_ASYNC 等
// ============================================================================
public let UV_UNKNOWN_HANDLE: Int32 = 0
public let UV_ASYNC: Int32 = 1
public let UV_CHECK: Int32 = 2
public let UV_FS_EVENT: Int32 = 3
public let UV_FS_POLL: Int32 = 4
public let UV_HANDLE: Int32 = 5
public let UV_IDLE: Int32 = 6
public let UV_NAMED_PIPE: Int32 = 7
public let UV_POLL: Int32 = 8
public let UV_PREPARE: Int32 = 9
public let UV_PROCESS: Int32 = 10
public let UV_STREAM: Int32 = 11
public let UV_TCP: Int32 = 12
public let UV_TIMER: Int32 = 13
public let UV_TTY: Int32 = 14
public let UV_UDP: Int32 = 15
public let UV_SIGNAL: Int32 = 16
public let UV_FILE: Int32 = 17
public let UV_HANDLE_TYPE_MAX: Int32 = 18

public let UV_UNKNOWN_REQ: Int32 = 0
public let UV_REQ: Int32 = 1
public let UV_CONNECT: Int32 = 2
public let UV_WRITE: Int32 = 3
public let UV_SHUTDOWN: Int32 = 4
public let UV_UDP_SEND: Int32 = 5
public let UV_FS: Int32 = 6
public let UV_WORK: Int32 = 7
public let UV_GETADDRINFO: Int32 = 8
public let UV_GETNAMEINFO: Int32 = 9
public let UV_RANDOM: Int32 = 10
public let UV_ACCEPT: Int32 = 11
public let UV_FS_EVENT_REQ: Int32 = 12
public let UV_POLL_REQ: Int32 = 13
public let UV_PROCESS_EXIT: Int32 = 14
public let UV_READ: Int32 = 15
public let UV_UDP_RECV: Int32 = 16
public let UV_WAKEUP: Int32 = 17
public let UV_SIGNAL_REQ: Int32 = 18
public let UV_REQ_TYPE_MAX: Int32 = 19

// ============================================================================
// Loop 选项
// 严格翻译自: libuv.zig UV_LOOP_BLOCK_SIGNAL 等
// ============================================================================
public let UV_LOOP_BLOCK_SIGNAL: Int32 = 0
public let UV_METRICS_IDLE_TIME: Int32 = 1

// ============================================================================
// Run 模式常量
// 严格翻译自: libuv.zig UV_RUN_DEFAULT 等
// ============================================================================
public let UV_RUN_DEFAULT: Int32 = 0
public let UV_RUN_ONCE: Int32 = 1
public let UV_RUN_NOWAIT: Int32 = 2

// ============================================================================
// 文件系统标志
// 严格翻译自: libuv.zig UV_FS_O_* 等
// ============================================================================
public let UV_FS_O_APPEND: UInt32 = 0x0008
public let UV_FS_O_CREAT: UInt32 = 0x0100
public let UV_FS_O_EXCL: UInt32 = 0x0400
public let UV_FS_O_FILEMAP: UInt32 = 0x20000000
public let UV_FS_O_RANDOM: UInt32 = 0x0010
public let UV_FS_O_RDONLY: UInt32 = 0x0000
public let UV_FS_O_RDWR: UInt32 = 0x0002
public let UV_FS_O_SEQUENTIAL: UInt32 = 0x0020
public let UV_FS_O_SHORT_LIVED: UInt32 = 0x1000
public let UV_FS_O_TEMPORARY: UInt32 = 0x0040
public let UV_FS_O_TRUNC: UInt32 = 0x0200
public let UV_FS_O_WRONLY: UInt32 = 0x0001
public let UV_FS_O_DIRECT: UInt32 = 0x02000000
public let UV_FS_O_DSYNC: UInt32 = 0x04000000
public let UV_FS_O_EXLOCK: UInt32 = 0x10000000
public let UV_FS_O_SYNC: UInt32 = 0x08000000

// ============================================================================
// CopyFile 标志
// 严格翻译自: libuv.zig UV_FS_COPYFILE_*
// ============================================================================
public let UV_FS_COPYFILE_EXCL: Int32 = 0x0001
public let UV_FS_COPYFILE_FICLONE: Int32 = 0x0002
public let UV_FS_COPYFILE_FICLONE_FORCE: Int32 = 0x0004

// ============================================================================
// Symlink 标志
// 严格翻译自: libuv.zig UV_FS_SYMLINK_*
// ============================================================================
public let UV_FS_SYMLINK_DIR: Int32 = 0x0001
public let UV_FS_SYMLINK_JUNCTION: Int32 = 0x0002

// ============================================================================
// Pipe 标志
// 严格翻译自: libuv.zig 中 pipe 相关
// ============================================================================
public let UV_PIPE_NO_TRUNCATE: UInt32 = 1

// ============================================================================
// Priority 常量
// 严格翻译自: libuv.zig UV_PRIORITY_*
// ============================================================================
public let UV_PRIORITY_LOW: Int32 = 19
public let UV_PRIORITY_BELOW_NORMAL: Int32 = 10
public let UV_PRIORITY_NORMAL: Int32 = 0
public let UV_PRIORITY_ABOVE_NORMAL: Int32 = -7
public let UV_PRIORITY_HIGH: Int32 = -14
public let UV_PRIORITY_HIGHEST: Int32 = -20

// ============================================================================
// Membership 常量
// 严格翻译自: libuv.zig UV_LEAVE_GROUP 等
// ============================================================================
public let UV_LEAVE_GROUP: Int32 = 0
public let UV_JOIN_GROUP: Int32 = 1

// ============================================================================
// Clock 常量
// 严格翻译自: libuv.zig UV_CLOCK_*
// ============================================================================
public let UV_CLOCK_MONOTONIC: Int32 = 0
public let UV_CLOCK_REALTIME: Int32 = 1

// ============================================================================
// 其他常量
// 严格翻译自: libuv.zig
// ============================================================================
public let MAX_PIPENAME_LEN: Int32 = 256
public let UV_IF_NAMESIZE: Int32 = 17
public let UV_MAXHOSTNAMESIZE: Int32 = 256
