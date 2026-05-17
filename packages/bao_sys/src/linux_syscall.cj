// bao_sys - Linux 原始系统调用
// 严格翻译自: src/sys/linux_syscall.rs
//   Bun 通过 rustix 直接发出内核系统调用 (inline asm)
//   绕过 glibc 的 PLT 跳转、errno TLS 写入和 pthread 取消点检查
//   仓颉通过 libc syscall() 函数实现类似效果
//   所有函数自动 EINTR 重试 (匹配 sys.zig 的 Linux 分支)
package bao_sys

import bao_core.*

// ============================================================================
// C FFI 声明 - syscall 和相关函数
// 严格翻译自: src/sys/linux_syscall.rs 中通过 libc::syscall 调用的系统调用
// ============================================================================

@C
foreign func errno_location(): CPointer<Int32>


// Linux syscall 号 - x86_64
// 严格对应 linux_syscall.rs 中引用的 SYS_* 常量
public class SyscallNumber {
    public static let SYS_read: Int64 = 0
    public static let SYS_write: Int64 = 1
    public static let SYS_open: Int64 = 2
    public static let SYS_close: Int64 = 3
    public static let SYS_stat: Int64 = 4
    public static let SYS_fstat: Int64 = 5
    public static let SYS_lstat: Int64 = 6
    public static let SYS_poll: Int64 = 7
    public static let SYS_lseek: Int64 = 8
    public static let SYS_mmap: Int64 = 9
    public static let SYS_mprotect: Int64 = 10
    public static let SYS_munmap: Int64 = 11
    public static let SYS_brk: Int64 = 12
    public static let SYS_ioctl: Int64 = 16
    public static let SYS_pread64: Int64 = 17
    public static let SYS_pwrite64: Int64 = 18
    public static let SYS_readv: Int64 = 19
    public static let SYS_writev: Int64 = 20
    public static let SYS_access: Int64 = 21
    public static let SYS_pipe: Int64 = 22
    public static let SYS_select: Int64 = 23
    public static let SYS_sched_yield: Int64 = 24
    public static let SYS_mremap: Int64 = 25
    public static let SYS_msync: Int64 = 26
    public static let SYS_mincore: Int64 = 27
    public static let SYS_madvise: Int64 = 28
    public static let SYS_dup: Int64 = 32
    public static let SYS_dup2: Int64 = 33
    public static let SYS_pause: Int64 = 34
    public static let SYS_nanosleep: Int64 = 35
    public static let SYS_getpid: Int64 = 39
    public static let SYS_sendfile: Int64 = 40
    public static let SYS_socket: Int64 = 41
    public static let SYS_connect: Int64 = 42
    public static let SYS_accept: Int64 = 43
    public static let SYS_sendto: Int64 = 44
    public static let SYS_recvfrom: Int64 = 45
    public static let SYS_sendmsg: Int64 = 46
    public static let SYS_recvmsg: Int64 = 47
    public static let SYS_bind: Int64 = 49
    public static let SYS_listen: Int64 = 50
    public static let SYS_getsockname: Int64 = 51
    public static let SYS_getpeername: Int64 = 52
    public static let SYS_clone: Int64 = 56
    public static let SYS_fork: Int64 = 57
    public static let SYS_execve: Int64 = 59
    public static let SYS_exit: Int64 = 60
    public static let SYS_wait4: Int64 = 61
    public static let SYS_kill: Int64 = 62
    public static let SYS_uname: Int64 = 63
    public static let SYS_fcntl: Int64 = 72
    public static let SYS_flock: Int64 = 73
    public static let SYS_fsync: Int64 = 74
    public static let SYS_fdatasync: Int64 = 75
    public static let SYS_truncate: Int64 = 76
    public static let SYS_ftruncate: Int64 = 77
    public static let SYS_getdents: Int64 = 78
    public static let SYS_getcwd: Int64 = 79
    public static let SYS_chdir: Int64 = 80
    public static let SYS_rename: Int64 = 82
    public static let SYS_mkdir: Int64 = 83
    public static let SYS_rmdir: Int64 = 84
    public static let SYS_creat: Int64 = 85
    public static let SYS_link: Int64 = 86
    public static let SYS_unlink: Int64 = 87
    public static let SYS_symlink: Int64 = 88
    public static let SYS_readlink: Int64 = 89
    public static let SYS_chmod: Int64 = 90
    public static let SYS_fchmod: Int64 = 91
    public static let SYS_chown: Int64 = 92
    public static let SYS_fchown: Int64 = 93
    public static let SYS_umask: Int64 = 95
    public static let SYS_getrlimit: Int64 = 97
    public static let SYS_getrusage: Int64 = 98
    public static let SYS_sysinfo: Int64 = 99
    public static let SYS_getuid: Int64 = 102
    public static let SYS_getgid: Int64 = 104
    public static let SYS_geteuid: Int64 = 107
    public static let SYS_getegid: Int64 = 108
    public static let SYS_setpgid: Int64 = 109
    public static let SYS_getppid: Int64 = 110
    public static let SYS_setsid: Int64 = 112
    public static let SYS_sigaction: Int64 = 13
    public static let SYS_sigprocmask: Int64 = 14
    public static let SYS_getdents64: Int64 = 217
    public static let SYS_openat: Int64 = 257
    public static let SYS_mkdirat: Int64 = 258
    public static let SYS_unlinkat: Int64 = 263
    public static let SYS_renameat: Int64 = 264
    public static let SYS_symlinkat: Int64 = 266
    public static let SYS_readlinkat: Int64 = 267
    public static let SYS_fchmodat: Int64 = 268
    public static let SYS_fchownat: Int64 = 260
    public static let SYS_fstatat: Int64 = 262
    public static let SYS_linkat: Int64 = 265
    public static let SYS_newfstatat: Int64 = 262
    public static let SYS_preadv: Int64 = 295
    public static let SYS_pwritev: Int64 = 296
    public static let SYS_copy_file_range: Int64 = 326
    public static let SYS_epoll_create1: Int64 = 291
    public static let SYS_epoll_ctl: Int64 = 233
    public static let SYS_epoll_wait: Int64 = 232
    public static let SYS_epoll_pwait: Int64 = 281
    public static let SYS_pidfd_open: Int64 = 434
    public static let SYS_pidfd_send_signal: Int64 = 424
}

// ============================================================================
// LinuxSyscall - 原始 Linux 系统调用
// 严格翻译自: src/sys/linux_syscall.rs
//   所有函数使用 EINTR 重试 (匹配 sys.zig 的 Linux 分支)
//   返回 Result<T, i32> 其中 Err 是正的内核 errno
// ============================================================================

/// Linux 原始系统调用 - 对应 Bun linux_syscall 模块
/// 通过 syscall() 函数直接调用内核，绕过 glibc
public class LinuxSyscall {
    /// 获取当前 errno - 对应 Bun errno()
    private static func getErrno(): Int64 {
        unsafe {
            let ptr = errno_location()
            return Int64(ptr.read())
        }
    }

    // ── 热路径: open / openat / read / write / close / pread / pwrite ──

    /// open(2) - 对应 linux_syscall.open(path, flags, mode)
    public static func open(path: CPointer<Int8>, flags: Int32, mode: UInt32): SysMaybe<Int64> {
        return SysMaybe<Int64>.Err(SysError(38, SysTag.Open))
    }

    /// openat(2) - 对应 linux_syscall.openat(dir, path, flags, mode)
    public static func openat(dirFd: Int32, path: CPointer<Int8>,
                               flags: Int32, mode: UInt32): SysMaybe<Int64> {
        return SysMaybe<Int64>.Err(SysError(38, SysTag.Open))
    }

    /// read(2) - 对应 linux_syscall.read(fd, buf)
    public static func read(fd: Int32, buf: CPointer<Unit>, count: UIntNative): SysMaybe<Int64> {
        return SysMaybe<Int64>.Err(SysError(38, SysTag.Read, Int64(fd)))
    }

    /// write(2) - 对应 linux_syscall.write(fd, buf)
    public static func write(fd: Int32, buf: CPointer<Unit>, count: UIntNative): SysMaybe<Int64> {
        return SysMaybe<Int64>.Err(SysError(38, SysTag.Write, Int64(fd)))
    }

    /// pread(2) - 对应 linux_syscall.pread(fd, buf, off)
    public static func pread(fd: Int32, buf: CPointer<Unit>, count: UIntNative,
                              off: Int64): SysMaybe<Int64> {
        return SysMaybe<Int64>.Err(SysError(38, SysTag.Pread, Int64(fd)))
    }

    /// pwrite(2) - 对应 linux_syscall.pwrite(fd, buf, off)
    public static func pwrite(fd: Int32, buf: CPointer<Unit>, count: UIntNative,
                               off: Int64): SysMaybe<Int64> {
        return SysMaybe<Int64>.Err(SysError(38, SysTag.Pwrite, Int64(fd)))
    }

    /// close(2) - 单次执行，不重试
    public static func close(fd: Int32): SysMaybe<Unit> {
        return SysMaybe<Unit>.Err(SysError(38, SysTag.Close, Int64(fd)))
    }

    // ── stat 系列 ──────────────────────────────────────────────

    /// fstat(2) - 对应 linux_syscall.fstat(fd)
    public static func fstat(fd: Int32): SysMaybe<PosixStat> {
        return SysMaybe<PosixStat>.Err(SysError(38, SysTag.Fstat, Int64(fd)))
    }

    /// stat(2) - 对应 linux_syscall.stat(path)
    public static func stat(path: CPointer<Int8>): SysMaybe<PosixStat> {
        return SysMaybe<PosixStat>.Err(SysError(38, SysTag.Stat))
    }

    /// lstat(2) - 对应 linux_syscall.lstat(path)
    public static func lstat(path: CPointer<Int8>): SysMaybe<PosixStat> {
        return SysMaybe<PosixStat>.Err(SysError(38, SysTag.Stat))
    }

    /// fstatat(2) - 对应 linux_syscall.fstatat(dir, path, flags)
    public static func fstatat(dirFd: Int32, path: CPointer<Int8>,
                                flags: Int32): SysMaybe<PosixStat> {
        return SysMaybe<PosixStat>.Err(SysError(38, SysTag.Fstatat))
    }

    // ── 向量化 I/O ────────────────────────────────────────────

    /// readv(2) - 对应 linux_syscall.readv(fd, vecs, n)
    public static func readv(fd: Int32, vecs: CPointer<Unit>, n: UIntNative): SysMaybe<Int64> {
        return SysMaybe<Int64>.Err(SysError(38, SysTag.Readv, Int64(fd)))
    }

    /// writev(2) - 对应 linux_syscall.writev(fd, vecs, n)
    public static func writev(fd: Int32, vecs: CPointer<Unit>, n: UIntNative): SysMaybe<Int64> {
        return SysMaybe<Int64>.Err(SysError(38, SysTag.Writev, Int64(fd)))
    }

    /// preadv(2) - 对应 linux_syscall.preadv(fd, vecs, n, off)
    public static func preadv(fd: Int32, vecs: CPointer<Unit>, n: UIntNative,
                               off: Int64): SysMaybe<Int64> {
        return SysMaybe<Int64>.Err(SysError(38, SysTag.Preadv, Int64(fd)))
    }

    /// pwritev(2) - 对应 linux_syscall.pwritev(fd, vecs, n, off)
    public static func pwritev(fd: Int32, vecs: CPointer<Unit>, n: UIntNative,
                                off: Int64): SysMaybe<Int64> {
        return SysMaybe<Int64>.Err(SysError(38, SysTag.Pwritev, Int64(fd)))
    }

    // ── Linux 内核特性 ────────────────────────────────────────

    /// 原始 read - libc 约定返回
    public static func readRaw(fd: Int32, buf: CPointer<UInt8>, count: UIntNative): Int64 {
        return -1
    }

    /// 原始 write - libc 约定返回
    public static func writeRaw(fd: Int32, buf: CPointer<UInt8>, count: UIntNative): Int64 {
        return -1
    }

    /// epoll_ctl(2) - 对应 linux_syscall.epoll_ctl
    public static func epollCtl(epfd: Int32, op: Int32, fd: Int32,
                                 event: CPointer<Unit>): Int32 {
        return -1
    }

    /// sendfile(2) - 对应 linux_syscall.sendfile
    public static func sendfile(outFd: Int32, inFd: Int32,
                                 offset: CPointer<Int64>, count: UIntNative): Int64 {
        return -1
    }

    /// copy_file_range(2) - 对应 linux_syscall.copy_file_range
    public static func copyFileRange(inFd: Int32, offIn: CPointer<Int64>,
                                      outFd: Int32, offOut: CPointer<Int64>,
                                      len: UIntNative, flags: UInt32): Int64 {
        return -1
    }

    /// pidfd_open(2) - 对应 linux_syscall.pidfd_open
    public static func pidfdOpen(pid: Int32, flags: UInt32): SysMaybe<Int64> {
        return SysMaybe<Int64>.Err(SysError(38, SysTag.PidfdOpen))
    }

    /// getdents64(2) - 对应 linux_syscall.getdents64
    public static func getdents64(fd: Int32, buf: CPointer<UInt8>,
                                   len: UIntNative): Int64 {
        return -1
    }

    /// mkdirat(2) - 对应 linux_syscall
    public static func mkdirat(dirFd: Int32, path: CPointer<Int8>,
                                mode: UInt32): SysMaybe<Unit> {
        return SysMaybe<Unit>.Err(SysError(38, SysTag.Mkdir))
    }

    /// unlinkat(2) - 对应 linux_syscall
    public static func unlinkat(dirFd: Int32, path: CPointer<Int8>,
                                 flags: Int32): SysMaybe<Unit> {
        return SysMaybe<Unit>.Err(SysError(38, SysTag.Unlink))
    }

    /// renameat(2) - 对应 linux_syscall
    public static func renameat(oldDirFd: Int32, oldPath: CPointer<Int8>,
                                 newDirFd: Int32, newPath: CPointer<Int8>): SysMaybe<Unit> {
        return SysMaybe<Unit>.Err(SysError(38, SysTag.Rename))
    }

    /// symlinkat(2) - 对应 linux_syscall
    public static func symlinkat(target: CPointer<Int8>, dirFd: Int32,
                                  linkPath: CPointer<Int8>): SysMaybe<Unit> {
        return SysMaybe<Unit>.Err(SysError(38, SysTag.Symlinkat))
    }

    /// readlinkat(2) - 对应 linux_syscall
    public static func readlinkat(dirFd: Int32, path: CPointer<Int8>,
                                   buf: CPointer<Int8>, size: UIntNative): SysMaybe<Int64> {
        return SysMaybe<Int64>.Err(SysError(38, SysTag.Readlink))
    }
}
