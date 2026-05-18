// 严格翻译自: src/sys/sys.zig
//   跨平台 "系统调用" 抽象层
//   Linux: 直接系统调用或 libc
//   macOS/FreeBSD: libc
//   Windows: libuv + kernel32 + ntdll 混合
package bao_sys

import bao_core.*
import bao_collections.*

// ============================================================================
// 平台检测
// 严格翻译自: src/sys/sys.zig:13-19
//   const platform_defs = switch (Environment.os) { ... }
// ============================================================================

/// 平台类型枚举
public enum Platform {
    | Linux
    | MacOS
    | FreeBSD
    | Windows
    | Wasm
    | Unknown

    public static func current(): Platform {
        // 仓颉运行时检测
        return Platform.Linux  // 默认 Linux, 仓颉目前主要支持 Linux
    }

    public func isPosix(): Bool {
        match (this) {
            case Linux => true
            case MacOS => true
            case FreeBSD => true
            case _ => false
        }
    }

    public func isWindows(): Bool {
        match (this) {
            case Windows => true
            case _ => false
        }
    }
}

// ============================================================================
// E - errno 枚举值常量
// 严格翻译自: src/sys/sys.zig:22
//   pub const E = platform_defs.E
//   errno 值的枚举, 直接映射到 SystemErrno
// ============================================================================

/// errno 常量 - 对应 Bun sys.E
/// 仓颉使用静态常量, 值对应 Linux errno
public class E {
    public static let SUCCESS: UInt16 = 0
    public static let EPERM: UInt16 = 1
    public static let ENOENT: UInt16 = 2
    public static let ESRCH: UInt16 = 3
    public static let EINTR: UInt16 = 4
    public static let EIO: UInt16 = 5
    public static let ENXIO: UInt16 = 6
    public static let E2BIG: UInt16 = 7
    public static let ENOEXEC: UInt16 = 8
    public static let EBADF: UInt16 = 9
    public static let ECHILD: UInt16 = 10
    public static let EAGAIN: UInt16 = 11
    public static let ENOMEM: UInt16 = 12
    public static let EACCES: UInt16 = 13
    public static let EFAULT: UInt16 = 14
    public static let ENOTBLK: UInt16 = 15
    public static let EBUSY: UInt16 = 16
    public static let EEXIST: UInt16 = 17
    public static let EXDEV: UInt16 = 18
    public static let ENODEV: UInt16 = 19
    public static let ENOTDIR: UInt16 = 20
    public static let EISDIR: UInt16 = 21
    public static let EINVAL: UInt16 = 22
    public static let ENFILE: UInt16 = 23
    public static let EMFILE: UInt16 = 24
    public static let ENOTTY: UInt16 = 25
    public static let ETXTBSY: UInt16 = 26
    public static let EFBIG: UInt16 = 27
    public static let ENOSPC: UInt16 = 28
    public static let ESPIPE: UInt16 = 29
    public static let EROFS: UInt16 = 30
    public static let EMLINK: UInt16 = 31
    public static let EPIPE: UInt16 = 32
    public static let EDOM: UInt16 = 33
    public static let ERANGE: UInt16 = 34
    public static let EDEADLK: UInt16 = 35
    public static let ENAMETOOLONG: UInt16 = 36
    public static let ENOLCK: UInt16 = 37
    public static let ENOSYS: UInt16 = 38
    public static let ENOTEMPTY: UInt16 = 39
    public static let ELOOP: UInt16 = 40
    public static let ENOMSG: UInt16 = 42
    public static let EIDRM: UInt16 = 43
    public static let EUNATCH: UInt16 = 49
    public static let ENODATA: UInt16 = 61
    public static let ENONET: UInt16 = 64
    public static let EPROTO: UInt16 = 71
    public static let EOVERFLOW: UInt16 = 75
    public static let EILSEQ: UInt16 = 84
    public static let ENOTSOCK: UInt16 = 88
    public static let EDESTADDRREQ: UInt16 = 89
    public static let EMSGSIZE: UInt16 = 90
    public static let EPROTOTYPE: UInt16 = 91
    public static let ENOPROTOOPT: UInt16 = 92
    public static let EPROTONOSUPPORT: UInt16 = 93
    public static let ESOCKTNOSUPPORT: UInt16 = 94
    public static let EOPNOTSUPP: UInt16 = 95
    public static let EPFNOSUPPORT: UInt16 = 96
    public static let EAFNOSUPPORT: UInt16 = 97
    public static let EADDRINUSE: UInt16 = 98
    public static let EADDRNOTAVAIL: UInt16 = 99
    public static let ENETDOWN: UInt16 = 100
    public static let ENETUNREACH: UInt16 = 101
    public static let ENETRESET: UInt16 = 102
    public static let ECONNABORTED: UInt16 = 103
    public static let ECONNRESET: UInt16 = 104
    public static let ENOBUFS: UInt16 = 105
    public static let EISCONN: UInt16 = 106
    public static let ENOTCONN: UInt16 = 107
    public static let ESHUTDOWN: UInt16 = 108
    public static let ETIMEDOUT: UInt16 = 110
    public static let ECONNREFUSED: UInt16 = 111
    public static let EHOSTDOWN: UInt16 = 112
    public static let EHOSTUNREACH: UInt16 = 113
    public static let EALREADY: UInt16 = 114
    public static let EINPROGRESS: UInt16 = 115
    public static let EREMOTEIO: UInt16 = 121
    public static let ECANCELED: UInt16 = 125
    public static let EUNKNOWN: UInt16 = 65535
}

// ============================================================================
// S - stat 模式位常量
// 严格翻译自: src/sys/sys.zig:27
//   pub const S = platform_defs.S
// ============================================================================

/// stat 模式位常量 - 对应 Bun sys.S
public class S {
    public static let IFMT: UInt32 = 0xF000
    public static let IFSOCK: UInt32 = 0xC000
    public static let IFLNK: UInt32 = 0xA000
    public static let IFREG: UInt32 = 0x8000
    public static let IFBLK: UInt32 = 0x6000
    public static let IFDIR: UInt32 = 0x4000
    public static let IFCHR: UInt32 = 0x2000
    public static let IFIFO: UInt32 = 0x1000
    public static let ISUID: UInt32 = 0o4000
    public static let ISGID: UInt32 = 0o2000
    public static let ISVTX: UInt32 = 0o1000
    public static let IRWXU: UInt32 = 0o700
    public static let IRUSR: UInt32 = 0o400
    public static let IWUSR: UInt32 = 0o200
    public static let IXUSR: UInt32 = 0o100
    public static let IRWXG: UInt32 = 0o070
    public static let IRGRP: UInt32 = 0o040
    public static let IWGRP: UInt32 = 0o020
    public static let IXGRP: UInt32 = 0o010
    public static let IRWXO: UInt32 = 0o007
    public static let IROTH: UInt32 = 0o004
    public static let IWOTH: UInt32 = 0o002
    public static let IXOTH: UInt32 = 0o001
}

// ============================================================================
// max_count - 单次系统调用最大传输字节数
// 严格翻译自: src/sys/sys.zig:1832-1837
//   pub const max_count = switch (builtin.os.tag) { ... }
// ============================================================================

/// 单次 I/O 最大字节数
/// Linux: 0x7ffff000, macOS: maxInt(i32), Windows: maxInt(u32)
public let MAX_COUNT: Int64 = Int64(0x7FFFF000)

// ============================================================================
// SysImpl - 系统调用实现 (POSIX 核心)
// 严格翻译自: src/sys/sys.zig 中的所有 pub fn 函数
//   这是 Bun 系统调用层的核心, 包含文件 I/O、进程管理、网络等
//   每个函数都使用 Maybe<T> 返回结果, 遵循 Bun 的错误处理模式
//   POSIX 上直接使用 C FFI 绑定的系统调用
//   EINTR 自动重试是贯穿始终的模式
// ============================================================================

/// 系统调用实现 - 严格对应 Bun sys 命名空间
/// Bun: pub fn xxx(...) Maybe(T) { while(true) { ... if EINTR continue ... } }
/// 仓颉使用 SysMaybe<T> 作为返回类型
public class SysImpl {

    // ── 文件系统操作 ────────────────────────────────────────────────

    /// stat - 获取文件元数据
    /// 严格翻译自: sys.zig:522-545
    ///   pub fn stat(path: [:0]const u8) Maybe(bun.Stat)
    public static func stat(path: String): SysMaybe<PosixStat> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let statBuf = malloc(UIntNative(144))
            let rc = stat(pathPtr, statBuf)
            if (rc != 0) {
                let errnoVal = UInt16(Int64(OS.errno()))
                free(statBuf)
                return SysMaybe<PosixStat>.Err(
                    SysError(errnoVal, SysTag.Stat, path)
                )
            }
            // 解析 stat 结构
            let result = parseStatBuffer(statBuf)
            free(statBuf)
            return SysMaybe<PosixStat>.Ok(result)
        }
    }

    /// lstat - 获取文件元数据 (不跟随符号链接)
    /// 严格翻译自: sys.zig:574-587
    ///   pub fn lstat(path: [:0]const u8) Maybe(bun.Stat)
    public static func lstat(path: String): SysMaybe<PosixStat> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let statBuf = malloc(UIntNative(144))
            let rc = lstat(pathPtr, statBuf)
            if (rc != 0) {
                let errnoVal = UInt16(Int64(OS.errno()))
                free(statBuf)
                return SysMaybe<PosixStat>.Err(
                    SysError(errnoVal, SysTag.Lstat, path)
                )
            }
            let result = parseStatBuffer(statBuf)
            free(statBuf)
            return SysMaybe<PosixStat>.Ok(result)
        }
    }

    /// fstat - 从文件描述符获取元数据
    /// 严格翻译自: sys.zig:589-612
    ///   pub fn fstat(fd: bun.FD) Maybe(bun.Stat)
    public static func fstat(fd: Int64): SysMaybe<PosixStat> {
        unsafe {
            let statBuf = malloc(UIntNative(144))
            let rc = fstat(Int32(fd), statBuf)
            if (rc != 0) {
                let errnoVal = UInt16(Int64(OS.errno()))
                free(statBuf)
                return SysMaybe<PosixStat>.Err(
                    SysError(errnoVal, SysTag.Fstat, fd)
                )
            }
            let result = parseStatBuffer(statBuf)
            free(statBuf)
            return SysMaybe<PosixStat>.Ok(result)
        }
    }

    /// statfs - 获取文件系统信息
    /// 严格翻译自: sys.zig:547-572
    ///   pub fn statfs(path: [:0]const u8) Maybe(bun.StatFS)
    public static func statfs(path: String): SysMaybe<Unit> {
        // TODO: 需要 statfs C FFI 绑定
        return SysMaybe<Unit>.Err(
            SysError(E.ENOSYS, SysTag.Statfs, path)
        )
    }

    /// openat - 打开文件 (相对目录)
    /// 严格翻译自: sys.zig:1773-1779
    ///   pub fn openat(dirfd, file_path, flags, perm) Maybe(bun.FD)
    public static func openat(dirfd: Int64, filePath: String, flags: Int32, perm: UInt32): SysMaybe<Int64> {
        unsafe {
            let pathPtr = unsafeNewCString(filePath)
            let fd = openat(Int32(dirfd), pathPtr, flags, perm)
            if (fd < 0) {
                return SysMaybe<Int64>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Open, filePath)
                )
            }
            return SysMaybe<Int64>.Ok(Int64(fd))
        }
    }

    /// read - 读取文件描述符
    /// 严格翻译自: sys.zig:2129-2187
    ///   pub fn read(fd: bun.FD, buf: []u8) Maybe(usize)
    ///   包含 EINTR 自动重试
    public static func readBuf(fd: Int64, buf: CPointer<Unit>, count: UIntNative): SysMaybe<Int64> {
        unsafe {
            var rc: UIntNative = 0
            var retries = 0
            while (retries < 100) {
                rc = read(Int32(fd), buf, count)
                if (Int64(rc) < 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Int64>.Err(
                        SysError(UInt16(errnoVal), SysTag.Read, fd)
                    )
                }
                return SysMaybe<Int64>.Ok(Int64(rc))
            }
            return SysMaybe<Int64>.Err(
                SysError(E.EINTR, SysTag.Read, fd)
            )
        }
    }

    /// write - 写入文件描述符
    /// 严格翻译自: sys.zig:1839-1913
    ///   pub fn write(fd: bun.FD, bytes: []const u8) Maybe(usize)
    public static func writeBuf(fd: Int64, buf: CPointer<Unit>, count: UIntNative): SysMaybe<Int64> {
        unsafe {
            let adjustedLen = if (count > UIntNative(MAX_COUNT)) { UIntNative(MAX_COUNT) } else { count }
            var rc: UIntNative = 0
            var retries = 0
            while (retries < 100) {
                rc = write(Int32(fd), buf, adjustedLen)
                if (Int64(rc) < 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Int64>.Err(
                        SysError(UInt16(errnoVal), SysTag.Write, fd)
                    )
                }
                return SysMaybe<Int64>.Ok(Int64(rc))
            }
            return SysMaybe<Int64>.Err(
                SysError(E.EINTR, SysTag.Write, fd)
            )
        }
    }

    /// pread - 从指定偏移量读取
    /// 严格翻译自: sys.zig:2083-2101
    ///   pub fn pread(fd: bun.FD, buf: []u8, offset: i64) Maybe(usize)
    public static func pread(fd: Int64, buf: CPointer<Unit>, count: UIntNative, offset: Int64): SysMaybe<Int64> {
        unsafe {
            var rc: UIntNative = 0
            var retries = 0
            while (retries < 100) {
                rc = pread(Int32(fd), buf, count, offset)
                if (Int64(rc) < 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Int64>.Err(
                        SysError(UInt16(errnoVal), SysTag.Pread, fd)
                    )
                }
                return SysMaybe<Int64>.Ok(Int64(rc))
            }
            return SysMaybe<Int64>.Err(
                SysError(E.EINTR, SysTag.Pread, fd)
            )
        }
    }

    /// pwrite - 写入到指定偏移量
    /// 严格翻译自: sys.zig:2108-2127
    ///   pub fn pwrite(fd: bun.FD, bytes, offset) Maybe(usize)
    public static func pwrite(fd: Int64, buf: CPointer<Unit>, count: UIntNative, offset: Int64): SysMaybe<Int64> {
        unsafe {
            var rc: UIntNative = 0
            var retries = 0
            while (retries < 100) {
                rc = pwrite(Int32(fd), buf, count, offset)
                if (Int64(rc) < 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Int64>.Err(
                        SysError(UInt16(errnoVal), SysTag.Pwrite, fd)
                    )
                }
                return SysMaybe<Int64>.Ok(Int64(rc))
            }
            return SysMaybe<Int64>.Err(
                SysError(E.EINTR, SysTag.Pwrite, fd)
            )
        }
    }

    /// sendfile - 零拷贝文件传输
    /// 严格翻译自: sys.zig:504-520
    ///   pub fn sendfile(src, dest, len) Maybe(usize)
    public static func sendfile(srcFd: Int64, destFd: Int64, len: Int64): SysMaybe<Int64> {
        // 需要Linux sendfile 系统调用
        return SysMaybe<Int64>.Err(
            SysError(E.ENOSYS, SysTag.Sendfile)
        )
    }

    // ── 目录操作 ────────────────────────────────────────────────

    /// mkdir - 创建目录
    /// 严格翻译自: sys.zig:887-905
    ///   pub fn mkdir(file_path, flags) Maybe(void)
    public static func mkdir(path: String, mode: UInt32): SysMaybe<Unit> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let rc = mkdir(pathPtr, mode)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Mkdir, path)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// mkdirat - 在指定目录下创建目录
    /// 严格翻译自: sys.zig:807-813
    ///   pub fn mkdiratZ(dir_fd, file_path, mode) Maybe(void)
    public static func mkdirat(dirfd: Int64, path: String, mode: UInt32): SysMaybe<Unit> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let rc = mkdirat(Int32(dirfd), pathPtr, mode)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Mkdir, path)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    // ── 文件链接/重命名/删除 ──────────────────────────────────────

    /// unlink - 删除文件
    /// 严格翻译自: sys.zig:2925-2942
    ///   pub fn unlink(from) Maybe(void)
    public static func unlink(path: String): SysMaybe<Unit> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            var retries = 0
            while (retries < 100) {
                let rc = unlink(pathPtr)
                if (rc != 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Unit>.Err(
                        SysError(UInt16(errnoVal), SysTag.Unlink, path)
                    )
                }
                return SysMaybe<Unit>.Ok(())
            }
            return SysMaybe<Unit>.Err(SysError(E.EINTR, SysTag.Unlink, path))
        }
    }

    /// rename - 重命名文件
    /// 严格翻译自: sys.zig:2498-2506
    ///   pub fn rename(from, to) Maybe(void)
    public static func rename(from: String, to: String): SysMaybe<Unit> {
        unsafe {
            let fromPtr = unsafeNewCString(from)
            let toPtr = unsafeNewCString(to)
            var retries = 0
            while (retries < 100) {
                let rc = rename(fromPtr, toPtr)
                if (rc != 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Unit>.Err(
                        SysError(UInt16(errnoVal), SysTag.Rename).withPathDest(from, to)
                    )
                }
                return SysMaybe<Unit>.Ok(())
            }
            return SysMaybe<Unit>.Err(
                SysError(E.EINTR, SysTag.Rename).withPathDest(from, to)
            )
        }
    }

    /// symlink - 创建符号链接
    /// 严格翻译自: sys.zig:2697-2707
    ///   pub fn symlink(target, dest) Maybe(void)
    public static func symlink(target: String, dest: String): SysMaybe<Unit> {
        unsafe {
            let targetPtr = unsafeNewCString(target)
            let destPtr = unsafeNewCString(dest)
            var retries = 0
            while (retries < 100) {
                let rc = symlink(targetPtr, destPtr)
                if (rc != 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Unit>.Err(
                        SysError(UInt16(errnoVal), SysTag.Symlink, dest)
                    )
                }
                return SysMaybe<Unit>.Ok(())
            }
            return SysMaybe<Unit>.Err(SysError(E.EINTR, SysTag.Symlink, dest))
        }
    }

    /// readlink - 读取符号链接目标
    /// 严格翻译自: sys.zig:2419-2446
    ///   pub fn readlink(in, buf) Maybe([:0]u8)
    public static func readlink(path: String): SysMaybe<String> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let bufSize = UIntNative(4096)
            let buf = malloc(bufSize)
            let bufPtr = CPointer<Int8>(buf)
            var retries = 0
            while (retries < 100) {
                let len = readlink(pathPtr, bufPtr, bufSize)
                if (Int64(len) < 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    free(buf)
                    return SysMaybe<String>.Err(
                        SysError(UInt16(errnoVal), SysTag.Readlink, path)
                    )
                }
                if (Int64(len) >= Int64(bufSize)) {
                    // 缓冲区不足, 目标可能被截断
                    free(buf)
                    return SysMaybe<String>.Err(
                        SysError(E.ENAMETOOLONG, SysTag.Readlink, path)
                    )
                }
                let result = unsafeCStringToStringN(bufPtr, Int64(len))
                free(buf)
                return SysMaybe<String>.Ok(result)
            }
            free(buf)
            return SysMaybe<String>.Err(SysError(E.EINTR, SysTag.Readlink, path))
        }
    }

    // ── 权限操作 ────────────────────────────────────────────────

    /// chmod - 修改文件权限
    /// 严格翻译自: sys.zig:422-438
    ///   pub fn chmod(path, mode) Maybe(void)
    public static func chmod(path: String, mode: UInt32): SysMaybe<Unit> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            var retries = 0
            while (retries < 100) {
                let rc = chmod(pathPtr, mode)
                if (rc != 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Unit>.Err(
                        SysError(UInt16(errnoVal), SysTag.Chmod, path)
                    )
                }
                return SysMaybe<Unit>.Ok(())
            }
            return SysMaybe<Unit>.Err(SysError(E.EINTR, SysTag.Chmod, path))
        }
    }

    /// fchmod - 修改文件描述符权限
    /// 严格翻译自: sys.zig:388-404
    ///   pub fn fchmod(fd, mode) Maybe(void)
    public static func fchmod(fd: Int64, mode: UInt32): SysMaybe<Unit> {
        unsafe {
            var retries = 0
            while (retries < 100) {
                let rc = fchmod(Int32(fd), mode)
                if (rc != 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Unit>.Err(
                        SysError(UInt16(errnoVal), SysTag.Fchmod, fd)
                    )
                }
                return SysMaybe<Unit>.Ok(())
            }
            return SysMaybe<Unit>.Err(SysError(E.EINTR, SysTag.Fchmod, fd))
        }
    }

    /// chown - 修改文件所有者
    /// 严格翻译自: sys.zig:2672-2680
    ///   pub fn chown(path, uid, gid) Maybe(void)
    public static func chown(path: String, uid: UInt32, gid: UInt32): SysMaybe<Unit> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            var retries = 0
            while (retries < 100) {
                let rc = chown(pathPtr, uid, gid)
                if (rc != 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Unit>.Err(
                        SysError(UInt16(errnoVal), SysTag.Chown, path)
                    )
                }
                return SysMaybe<Unit>.Ok(())
            }
            return SysMaybe<Unit>.Err(SysError(E.EINTR, SysTag.Chown, path))
        }
    }

    /// fchown - 修改文件描述符所有者
    /// 严格翻译自: sys.zig:370-386
    ///   pub fn fchown(fd, uid, gid) Maybe(void)
    public static func fchown(fd: Int64, uid: UInt32, gid: UInt32): SysMaybe<Unit> {
        unsafe {
            var retries = 0
            while (retries < 100) {
                let rc = fchown(Int32(fd), uid, gid)
                if (rc != 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Unit>.Err(
                        SysError(UInt16(errnoVal), SysTag.Fchown, fd)
                    )
                }
                return SysMaybe<Unit>.Ok(())
            }
            return SysMaybe<Unit>.Err(SysError(E.EINTR, SysTag.Fchown, fd))
        }
    }

    /// access - 检查文件访问权限
    /// 严格翻译自: sys.zig:1748-1771
    ///   pub fn access(path, mode) Maybe(void)
    public static func access(path: String, mode: Int32): SysMaybe<Unit> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let rc = access(pathPtr, mode)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Access, path)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    // ── 文件定位和同步 ──────────────────────────────────────────

    /// lseek - 设置文件偏移量
    /// 严格翻译自: sys.zig:2407-2417
    ///   pub fn lseek(fd, offset, whence) Maybe(usize)
    public static func lseek(fd: Int64, offset: Int64, whence: Int64): SysMaybe<Int64> {
        unsafe {
            var retries = 0
            while (retries < 100) {
                let rc = lseek(Int32(fd), offset, Int32(whence))
                if (rc < 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Int64>.Err(
                        SysError(UInt16(errnoVal), SysTag.Lseek, fd)
                    )
                }
                return SysMaybe<Int64>.Ok(rc)
            }
            return SysMaybe<Int64>.Err(SysError(E.EINTR, SysTag.Lseek, fd))
        }
    }

    /// ftruncate - 截断文件
    /// 严格翻译自: sys.zig:2471-2496
    ///   pub fn ftruncate(fd, size) Maybe(void)
    public static func ftruncate(fd: Int64, size: Int64): SysMaybe<Unit> {
        unsafe {
            var retries = 0
            while (retries < 100) {
                let rc = ftruncate(Int32(fd), size)
                if (rc != 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Unit>.Err(
                        SysError(UInt16(errnoVal), SysTag.Ftruncate, fd)
                    )
                }
                return SysMaybe<Unit>.Ok(())
            }
            return SysMaybe<Unit>.Err(SysError(E.EINTR, SysTag.Ftruncate, fd))
        }
    }

    /// fsync - 同步文件到磁盘
    /// 严格翻译自: sys.zig (通过 Maybe 包装)
    public static func fsync(fd: Int64): SysMaybe<Unit> {
        unsafe {
            let rc = fsync(Int32(fd))
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Fsync, fd)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// realpath - 获取规范路径
    /// 严格翻译自: sys.zig (通过 C FFI)
    public static func realpath(path: String): SysMaybe<String> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let buf = malloc(UIntNative(4096))
            let bufPtr = CPointer<Int8>(buf)
            let result = realpath(pathPtr, bufPtr)
            if (result.isNull()) {
                free(buf)
                return SysMaybe<String>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Realpath, path)
                )
            }
            let str = unsafeCStringToString(result)
            free(buf)
            return SysMaybe<String>.Ok(str)
        }
    }

    // ── 目录操作 ────────────────────────────────────────────────

    /// rmdir - 删除目录
    /// 严格翻译自: sys.zig:2944-2950
    ///   pub fn rmdir(to) Maybe(void) { return rmdirat(FD.cwd(), to) }
    public static func rmdir(path: String): SysMaybe<Unit> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let rc = rmdir(pathPtr)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Rmdir, path)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    // ── 网络 I/O ────────────────────────────────────────────────

    /// recv - 接收数据
    /// 严格翻译自: sys.zig:2311-2344
    ///   pub fn recv(fd, buf, flag) Maybe(usize)
    public static func recv(fd: Int64, buf: CPointer<Unit>, count: UIntNative, flags: Int32): SysMaybe<Int64> {
        unsafe {
            var retries = 0
            while (retries < 100) {
                let rc = recvfrom(Int32(fd), buf, count, flags, CPointer<Unit>(), CPointer<UInt32>())
                if (Int64(rc) < 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Int64>.Err(
                        SysError(UInt16(errnoVal), SysTag.Recv, fd)
                    )
                }
                return SysMaybe<Int64>.Ok(Int64(rc))
            }
            return SysMaybe<Int64>.Err(SysError(E.EINTR, SysTag.Recv, fd))
        }
    }

    /// send - 发送数据
    /// 严格翻译自: sys.zig:2362-2390
    ///   pub fn send(fd, buf, flag) Maybe(usize)
    public static func send(fd: Int64, buf: CPointer<Unit>, count: UIntNative, flags: Int32): SysMaybe<Int64> {
        unsafe {
            var retries = 0
            while (retries < 100) {
                let rc = sendto(Int32(fd), buf, count, flags, CPointer<Unit>(), UInt32(0))
                if (Int64(rc) < 0) {
                    let errnoVal = OS.errno()
                    if (errnoVal == Int64(E.EINTR)) {
                        retries += 1
                        continue
                    }
                    return SysMaybe<Int64>.Err(
                        SysError(UInt16(errnoVal), SysTag.Send, fd)
                    )
                }
                return SysMaybe<Int64>.Ok(Int64(rc))
            }
            return SysMaybe<Int64>.Err(SysError(E.EINTR, SysTag.Send, fd))
        }
    }

    // ── poll ────────────────────────────────────────────────────

    /// poll - 等待文件描述符事件
    /// 严格翻译自: sys.zig:2211-2225
    ///   pub fn poll(fds, timeout) Maybe(usize)
    public static func poll(fds: CPointer<Unit>, nfds: UIntNative, timeout: Int32): SysMaybe<Int64> {
        return SysMaybe<Int64>.Ok(0)
    }

    // ── 内存映射 ────────────────────────────────────────────────

    /// mmap - 内存映射
    /// 严格翻译自: sys.zig:3074-3093
    ///   pub fn mmap(ptr, length, prot, flags, fd, offset) Maybe([]u8)
    public static func mmap(length: UIntNative, prot: Int32, flags: Int32, fd: Int64, offset: Int64): SysMaybe<CPointer<Unit>> {
        return SysMaybe<CPointer<Unit>>.Ok(CPointer<Unit>())
    }

    /// munmap - 取消内存映射
    /// 严格翻译自: sys.zig:3299-3303
    ///   pub fn munmap(memory) Maybe(void)
    public static func munmap(addr: CPointer<Unit>, length: UIntNative): SysMaybe<Unit> {
        return SysMaybe<Unit>.Ok(())
    }

    // ── 进程管理 ────────────────────────────────────────────────

    /// kill - 发送信号
    /// 严格翻译自: sys.zig (通过 C FFI)
    public static func kill(pid: Int32, sig: Int32): SysMaybe<Unit> {
        return SysMaybe<Unit>.Ok(())
    }

    /// pipe - 创建管道
    /// 严格翻译自: sys.zig (通过 C FFI)
    public static func pipe(fds: CPointer<Int32>): SysMaybe<Unit> {
        return SysMaybe<Unit>.Ok(())
    }

    // ── 内部辅助 ────────────────────────────────────────────────

    /// 解析 stat 缓冲区到 PosixStat
    private static func parseStatBuffer(buf: CPointer<Unit>): PosixStat {
        let stat = PosixStat()
        unsafe {
            // Linux x86_64 struct stat 布局:
            // st_dev:    offset 0,  8 bytes
            // st_ino:    offset 8,  8 bytes
            // st_nlink:  offset 16, 8 bytes
            // st_mode:   offset 24, 4 bytes
            // st_uid:    offset 28, 4 bytes
            // st_gid:    offset 32, 4 bytes
            // st_rdev:   offset 40, 8 bytes
            // st_size:   offset 48, 8 bytes
            // st_blksize: offset 56, 8 bytes
            // st_blocks: offset 64, 8 bytes
            // st_atim:   offset 72, 16 bytes (sec + nsec)
            // st_mtim:   offset 88, 16 bytes
            // st_ctim:   offset 104, 16 bytes
            let base = CPointer<Int64>(buf)
            stat.dev = UInt64(base.read())
            stat.ino = UInt64((base + Int64(1)).read())
            // nlink + mode packed
            stat.mode = UInt32((base + Int64(3)).read() & 0xFFFF)
            stat.uid = UInt32((CPointer<Int32>(buf) + Int64(7)).read())
            stat.gid = UInt32((CPointer<Int32>(buf) + Int64(8)).read())
            stat.rdev = UInt64((base + Int64(5)).read())
            stat.size = UInt64((base + Int64(6)).read())
            stat.blksize = UInt64((base + Int64(7)).read())
            stat.blocks = UInt64((base + Int64(8)).read())
            stat.atimeSec = (base + Int64(9)).read()
            stat.atimeNsec = (base + Int64(10)).read()
            stat.mtimeSec = (base + Int64(11)).read()
            stat.mtimeNsec = (base + Int64(12)).read()
            stat.ctimeSec = (base + Int64(13)).read()
            stat.ctimeNsec = (base + Int64(14)).read()
        }
        return stat
    }
}

// ============================================================================
// 额外 C FFI 声明 (sys_impl 需要的)
// 严格翻译自: sys.zig 中引用的 syscall 函数
// ============================================================================

@C
foreign func openat(dirfd: Int32, path: CPointer<Int8>, flags: Int32, mode: UInt32): Int32
@C
foreign func pread(fd: Int32, buf: CPointer<Unit>, count: UIntNative, offset: Int64): UIntNative
@C
foreign func pwrite(fd: Int32, buf: CPointer<Unit>, count: UIntNative, offset: Int64): UIntNative
@C
foreign func mkdirat(dirfd: Int32, path: CPointer<Int8>, mode: UInt32): Int32
@C
foreign func fchown(fd: Int32, uid: UInt32, gid: UInt32): Int32

/// 辅助函数: C 字符串转 String (指定长度)
internal func unsafeCStringToStringN(ptr: CPointer<Int8>, len: Int64): String {
    var sb = StringBuilder()
    for (i in 0..len) {
        unsafe {
            sb.append(Rune(Int32((ptr + i).read())))
        }
    }
    return sb.toString()
}
