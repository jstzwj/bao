// 严格翻译自: src/sys/libuv_error_map.zig
//   libuv 错误码到消息的映射表
//   Bun: 派生自 uv.h 定义, Node.js 打印错误时使用
//   Zig 使用 comptime EnumMap 构建, 仓颉使用静态映射方法
package bao_sys

import bao_core.*

// ============================================================================
// LibuvErrorMap - libuv 错误消息映射
// 严格翻译自: src/sys/libuv_error_map.zig:1-101
//   pub const libuv_error_map = brk: {
//       const entries = &.{ .{ "E2BIG", "argument list too long" }, ... }
//       var map = std.EnumMap(SystemErrno, [:0]const u8).initFull("unknown error")
//       for (entries) |entry| { if (@hasField(SystemErrno, key)) map.put(...) }
//       break :brk map
//   };
//
//   Bun 在编译时 (comptime) 使用 @hasField 检查每个错误码是否存在,
//   然后映射到对应的 libuv 错误描述字符串。
//   仓颉使用 match 表达式实现等价的 O(1) 查询。
// ============================================================================

/// libuv 错误消息映射类
/// 对应 Bun: EnumMap<SystemErrno, [:0]const u8>
/// 所有条目都来自 libuv 的 uv.h 定义
/// 不在列表中的 SystemErrno 值返回 "unknown error"
public class LibuvErrorMap {
    /// 未知错误默认消息 - 对应 Bun: initFull("unknown error")
    public static let UNKNOWN: String = "unknown error"

    /// 获取错误码对应的 libuv 错误消息
    /// 对应 Bun: libuv_error_map.get(errno) -> ?[]const u8
    /// 严格对应 libuv_error_map.zig 中的条目表
    public static func get(errno: SystemErrno): ?String {
        let msg = getRaw(errno)
        if (msg == UNKNOWN) {
            return None
        }
        return Some(msg)
    }

    /// 直接获取消息, 不区分映射/未映射
    /// 对应 Bun: EnumMap 是 total 的, get 永远返回值
    public static func getRaw(errno: SystemErrno): String {
        match (errno) {
            // 严格翻译自 libuv_error_map.zig:4-88 的 entries 数组
            case SystemErrno.E2BIG => "argument list too long"
            case SystemErrno.EACCES => "permission denied"
            case SystemErrno.EADDRINUSE => "address already in use"
            case SystemErrno.EADDRNOTAVAIL => "address not available"
            case SystemErrno.EAFNOSUPPORT => "address family not supported"
            case SystemErrno.EAGAIN => "resource temporarily unavailable"
            // EAI_* 系列不是 SystemErrno, 跳过 (libuv 的 DNS 错误码)
            case SystemErrno.EALREADY => "connection already in progress"
            case SystemErrno.EBADF => "bad file descriptor"
            case SystemErrno.EBUSY => "resource busy or locked"
            case SystemErrno.ECANCELED => "operation canceled"
            // ECHARSET (libuv 专有) 不在 SystemErrno 中
            case SystemErrno.ECONNABORTED => "software caused connection abort"
            case SystemErrno.ECONNREFUSED => "connection refused"
            case SystemErrno.ECONNRESET => "connection reset by peer"
            case SystemErrno.EDESTADDRREQ => "destination address required"
            case SystemErrno.EEXIST => "file already exists"
            case SystemErrno.EFAULT => "bad address in system call argument"
            case SystemErrno.EFBIG => "file too large"
            case SystemErrno.EHOSTUNREACH => "host is unreachable"
            case SystemErrno.EINTR => "interrupted system call"
            case SystemErrno.EINVAL => "invalid argument"
            case SystemErrno.EIO => "i/o error"
            case SystemErrno.EISCONN => "socket is already connected"
            case SystemErrno.EISDIR => "illegal operation on a directory"
            case SystemErrno.ELOOP => "too many symbolic links encountered"
            case SystemErrno.EMFILE => "too many open files"
            case SystemErrno.EMSGSIZE => "message too long"
            case SystemErrno.ENAMETOOLONG => "name too long"
            case SystemErrno.ENETDOWN => "network is down"
            case SystemErrno.ENETUNREACH => "network is unreachable"
            case SystemErrno.ENFILE => "file table overflow"
            case SystemErrno.ENOBUFS => "no buffer space available"
            case SystemErrno.ENODEV => "no such device"
            case SystemErrno.ENOENT => "no such file or directory"
            case SystemErrno.ENOMEM => "not enough memory"
            case SystemErrno.ENONET => "machine is not on the network"
            case SystemErrno.ENOPROTOOPT => "protocol not available"
            case SystemErrno.ENOSPC => "no space left on device"
            case SystemErrno.ENOSYS => "function not implemented"
            case SystemErrno.ENOTCONN => "socket is not connected"
            case SystemErrno.ENOTDIR => "not a directory"
            case SystemErrno.ENOTEMPTY => "directory not empty"
            case SystemErrno.ENOTSOCK => "socket operation on non-socket"
            // ENOTSUP (值 95 on Linux, 对应 EOPNOTSUPP)
            case SystemErrno.EOPNOTSUPP => "operation not supported on socket"
            case SystemErrno.EOVERFLOW => "value too large for defined data type"
            case SystemErrno.EPERM => "operation not permitted"
            case SystemErrno.EPIPE => "broken pipe"
            case SystemErrno.EPROTO => "protocol error"
            case SystemErrno.EPROTONOSUPPORT => "protocol not supported"
            case SystemErrno.EPROTOTYPE => "protocol wrong type for socket"
            case SystemErrno.ERANGE => "result too large"
            case SystemErrno.EROFS => "read-only file system"
            case SystemErrno.ESHUTDOWN => "cannot send after transport endpoint shutdown"
            case SystemErrno.ESPIPE => "invalid seek"
            case SystemErrno.ESRCH => "no such process"
            case SystemErrno.ETIMEDOUT => "connection timed out"
            case SystemErrno.ETXTBSY => "text file is busy"
            case SystemErrno.EXDEV => "cross-device link not permitted"
            // UNKNOWN 和 EOF (libuv 专有) 特殊处理
            case SystemErrno.ENXIO => "no such device or address"
            case SystemErrno.EMLINK => "too many links"
            case SystemErrno.EHOSTDOWN => "host is down"
            case SystemErrno.EREMOTEIO => "remote I/O error"
            case SystemErrno.ENOTTY => "inappropriate ioctl for device"
            // EFTYPE (某些平台专有) 可能不在枚举中
            case SystemErrno.EILSEQ => "illegal byte sequence"
            case SystemErrno.ESOCKTNOSUPPORT => "socket type not supported"
            case SystemErrno.ENODATA => "no data available"
            case SystemErrno.EUNATCH => "protocol driver not attached"
            case _ => UNKNOWN
        }
    }
}
