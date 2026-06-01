// 严格翻译自: src/platform/linux.zig
// Linux 平台特定 API

package bao_platform

// ============================================================================
// splice - 零拷贝数据传输
// 严格翻译自: linux.zig:8-23
//   pub fn splice(fd_in, off_in, fd_out, off_out, len, flags) usize { ... }
// ============================================================================

/// splice() 在两个文件描述符之间移动数据而无需在内核和用户空间之间拷贝
// 严格翻译自: linux.zig:8-23
public func splice(fdIn: Int32, offIn: ?CPointer<Int64>, fdOut: Int32, offOut: ?CPointer<Int64>, len: UInt64, flags: UInt32): UInt64 {
    // PORT NOTE: 需要通过 FFI 调用 Linux syscall splice(2)
    // 返回传输的字节数, 或错误码
    return 0
}

// ============================================================================
// RWFFlagSupport - RWF_NONBLOCK 标志支持检测
// 严格翻译自: linux.zig:25-66
//   pub const RWFFlagSupport = enum(u8) { unknown, unsupported, supported ... }
// ============================================================================

/// RWF 标志支持状态
public enum RWFFlagSupport {
    | Unknown     // 0
    | Supported   // 1
    | Unsupported // 2

    public operator func == (rhs: RWFFlagSupport): Bool {
        match (this) {
            case Unknown => match (rhs) { case Unknown => true; case _ => false }
            case Supported => match (rhs) { case Supported => true; case _ => false }
            case Unsupported => match (rhs) { case Unsupported => true; case _ => false }
        }
    }
    public operator func != (rhs: RWFFlagSupport): Bool {
        !(this == rhs)
    }
}

/// RWF 标志支持检测
/// 对应 Bun linux.zig RWFFlagSupport 的所有方法
public class RWFFlags {
    static var rwfState: RWFFlagSupport = RWFFlagSupport.Unknown

    /// 检查内核版本是否有 RWF_NONBLOCK bug
    // 严格翻译自: linux.zig:32-37
    //   pub fn isLinuxKernelVersionWithBuggyRWF_NONBLOCK() bool {
    //       return bun.linuxKernelVersion().major == 5 and switch (...) {
    //           9, 10 => true, else => false
    //       };
    //   }
    public static func isLinuxKernelVersionWithBuggyRWFNonblock(): Bool {
        // PORT NOTE: 需要访问 linux kernel version
        // Linux 5.9 和 5.10 有 RWF_NONBLOCK bug
        return false
    }

    /// 禁用 RWF_NONBLOCK
    // 严格翻译自: linux.zig:39-41
    //   pub fn disable() void { rwf_bool.store(.unsupported, .monotonic); }
    public static func disable(): Unit {
        rwfState = RWFFlagSupport.Unsupported
    }

    /// 检查 RWF_NONBLOCK 是否可能支持
    // 严格翻译自: linux.zig:44-65
    //   pub fn isMaybeSupported() bool { ... }
    public static func isMaybeSupported(): Bool {
        match (rwfState) {
            case RWFFlagSupport.Unknown =>
                if (isLinuxKernelVersionWithBuggyRWFNonblock()) {
                    rwfState = RWFFlagSupport.Unsupported
                    return false
                }
                rwfState = RWFFlagSupport.Supported
                return true
            case RWFFlagSupport.Supported => true
            case RWFFlagSupport.Unsupported => false
        }
    }
}

// ============================================================================
// ioctl_ficlone - 文件系统 CoW 支持
// 严格翻译自: linux.zig:69-73
//   pub fn ioctl_ficlone(dest_fd, srcfd) usize { ... }
// ============================================================================

/// FICLONE ioctl - 文件系统层 reflink/Copy-on-Write 支持
// 严格翻译自: linux.zig:69-73
public func ioctlFiClone(destFd: Int32, srcFd: Int32): UInt64 {
    // PORT NOTE: 需要通过 FFI 调用 ioctl(fd, FICLONE, srcfd)
    return 0
}

// ============================================================================
// sys_epoll_pwait2 - epoll_pwait2 系统调用
// 严格翻译自: linux.zig:75-90
//   export fn sys_epoll_pwait2(epfd, events, maxevents, timeout, sigmask) isize { ... }
// ============================================================================

/// epoll_pwait2 系统调用包装
// 严格翻译自: linux.zig:75-90
// PORT NOTE: 此函数通过 @export 导出给 C 代码使用
public func sysEpollPwait2(epfd: Int32, events: CPointer<Unit>, maxevents: Int32, timeout: CPointer<Unit>, sigmask: CPointer<Unit>): Int64 {
    // PORT NOTE: 需要通过 FFI 调用 epoll_pwait2 syscall
    // sigset_t size = 8 (kernel expects 8, not sizeof(sigset_t)=128)
    return 0
}
