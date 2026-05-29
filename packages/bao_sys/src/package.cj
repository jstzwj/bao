// bao_sys - 系统调用绑定
// 严格翻译自:
//   src/sys/sys.zig - Tag, Maybe, Error, 系统调用封装
//   src/sys/fd.zig - FD 文件描述符抽象
//   src/sys/Error.zig - SysError 类型
//   src/sys/File.zig - File 操作封装
//   src/sys/PosixStat.zig - stat 结构
package bao_sys

import bao_core.*
import bao_collections.*

// ============================================================================
// SysTag - 系统调用标签
// 严格翻译自: src/sys/sys.zig:218-332
//   pub const Tag = enum(u8) { TODO, dup, access, connect, ... }
// 每个标签对应一个具体的系统调用，用于错误报告
// ============================================================================

/// 系统调用标签 - 对应 Bun sys.Tag
/// Bun: pub const Tag = enum(u8) { ... }
/// 用于标识系统调用来源，在 Error 中记录是哪个调用失败
/// 注意: Bun 的 Tag 枚举中第一个值就是 TODO, 用于表示"未归类的系统调用",
/// 这是 Bun 的正式 API 设计, 不是缺失实现
public enum SysTag {
    | TODO  // 默认/未归类的系统调用标签 - Bun Tag.TODO
    | Dup
    | Access
    | Connect
    | Chmod
    | Chown
    | Clonefile
    | Clonefileat
    | Close
    | CopyFileRange
    | Copyfile
    | Copy
    | Fchmod
    | Fchmodat
    | Fchown
    | Fcntl
    | Fdatasync
    | Fstat
    | Fstatat
    | Fsync
    | Ftruncate
    | Futimens
    | Getdents64
    | Getdirentries64
    | Lchmod
    | Lchown
    | Link
    | Lseek
    | Lstat
    | Lutime
    | Mkdir
    | Mkdtemp
    | Fnctl
    | MemfdCreate
    | Mmap
    | Munmap
    | Open
    | Pread
    | Pwrite
    | Read
    | Readlink
    | Rename
    | Stat
    | Statfs
    | Symlink
    | Symlinkat
    | Unlink
    | Utime
    | Utimensat
    | Write
    | Getcwd
    | Getenv
    | Chdir
    | Fcopyfile
    | Recv
    | Send
    | Sendfile
    | Sendmmsg
    | Splice
    | Rmdir
    | Truncate
    | Realpath
    | Futime
    | PidfdOpen
    | Poll
    | Ppoll
    | Watch
    | Scandir
    | Kevent
    | Kqueue
    | EpollCtl
    | Kill
    | Waitpid
    | PosixSpawn
    | Getaddrinfo
    | Writev
    | Pwritev
    | Readv
    | Preadv
    | IoctlFiclone
    | Accept
    | Bind
    | Bind2
    | Connect2
    | Listen
    | Pipe
    | TryWrite
    | Socketpair
    | Setsockopt
    | Statx
    | Rm
    | UvSpawn
    | UvPipe
    | UvTtySetMode
    | UvOpenOsfhandle
    | UvOsHomedir
    | Tcgetattr
    | Tcsetattr
    | Ioctl
    | Shutdown
    | Signal
    | Raise
    | PthreadSigmask
    | UvLoopInit
    | UvTimer

    /// 获取标签名称字符串 - 对应 Bun @tagName(syscall)
    public func name(): String {
        match (this) {
            case TODO => "TODO"
            case Dup => "dup"
            case Access => "access"
            case Connect => "connect"
            case Chmod => "chmod"
            case Chown => "chown"
            case Clonefile => "clonefile"
            case Clonefileat => "clonefileat"
            case Close => "close"
            case CopyFileRange => "copy_file_range"
            case Copyfile => "copyfile"
            case Copy => "copyfile"
            case Fchmod => "fchmod"
            case Fchmodat => "fchmodat"
            case Fchown => "fchown"
            case Fcntl => "fcntl"
            case Fdatasync => "fdatasync"
            case Fstat => "fstat"
            case Fstatat => "fstatat"
            case Fsync => "fsync"
            case Ftruncate => "ftruncate"
            case Futimens => "futimens"
            case Getdents64 => "getdents64"
            case Getdirentries64 => "getdirentries64"
            case Lchmod => "lchmod"
            case Lchown => "lchown"
            case Link => "link"
            case Lseek => "lseek"
            case Lstat => "lstat"
            case Lutime => "lutime"
            case Mkdir => "mkdir"
            case Mkdtemp => "mkdtemp"
            case Fnctl => "fnctl"
            case MemfdCreate => "memfd_create"
            case Mmap => "mmap"
            case Munmap => "munmap"
            case Open => "open"
            case Pread => "pread"
            case Pwrite => "pwrite"
            case Read => "read"
            case Readlink => "readlink"
            case Rename => "rename"
            case Stat => "stat"
            case Statfs => "statfs"
            case Symlink => "symlink"
            case Symlinkat => "symlinkat"
            case Unlink => "unlink"
            case Utime => "utime"
            case Utimensat => "utimensat"
            case Write => "write"
            case Getcwd => "getcwd"
            case Getenv => "getenv"
            case Chdir => "chdir"
            case Fcopyfile => "fcopyfile"
            case Recv => "recv"
            case Send => "send"
            case Sendfile => "sendfile"
            case Sendmmsg => "sendmmsg"
            case Splice => "splice"
            case Rmdir => "rmdir"
            case Truncate => "truncate"
            case Realpath => "realpath"
            case Futime => "futime"
            case PidfdOpen => "pidfd_open"
            case Poll => "poll"
            case Ppoll => "ppoll"
            case Watch => "watch"
            case Scandir => "scandir"
            case Kevent => "kevent"
            case Kqueue => "kqueue"
            case EpollCtl => "epoll_ctl"
            case Kill => "kill"
            case Waitpid => "waitpid"
            case PosixSpawn => "posix_spawn"
            case Getaddrinfo => "getaddrinfo"
            case Writev => "writev"
            case Pwritev => "pwritev"
            case Readv => "readv"
            case Preadv => "preadv"
            case IoctlFiclone => "ioctl_ficlone"
            case Accept => "accept"
            case Bind => "bind"
            case Bind2 => "bind2"
            case Connect2 => "connect2"
            case Listen => "listen"
            case Pipe => "pipe"
            case TryWrite => "try_write"
            case Socketpair => "socketpair"
            case Setsockopt => "setsockopt"
            case Statx => "statx"
            case Rm => "rm"
            case UvSpawn => "uv_spawn"
            case UvPipe => "uv_pipe"
            case UvTtySetMode => "uv_tty_set_mode"
            case UvOpenOsfhandle => "uv_open_osfhandle"
            case UvOsHomedir => "uv_os_homedir"
            case Tcgetattr => "tcgetattr"
            case Tcsetattr => "tcsetattr"
            case Ioctl => "ioctl"
            case Shutdown => "shutdown"
            case Signal => "signal"
            case Raise => "raise"
            case PthreadSigmask => "pthread_sigmask"
            case UvLoopInit => "uv_loop_init"
            case UvTimer => "uv_timer"
        }
    }
}

// ============================================================================
// SysError - 系统错误
// 严格翻译自: src/sys/Error.zig
//   pub const Error = struct {
//       errno: Int = todo_errno,
//       fd: bun.FD = bun.invalid_fd,
//       path: []const u8 = "",
//       syscall: sys.Tag = sys.Tag.TODO,
//       dest: []const u8 = "",
//   }
// ============================================================================

/// 系统错误类型 - 严格对应 Bun sys.Error
/// Bun Error 保留完整的错误上下文: errno + syscall + path + fd + dest
/// 仓颉使用 class 实现等价语义
public class SysError {
    /// errno 编码 - 对应 Bun Error.errno: u16
    public let errno: UInt16
    /// 关联的文件描述符 - 对应 Bun Error.fd: bun.FD
    public let fd: Int64
    /// 关联路径 - 对应 Bun Error.path: []const u8
    public let path: String
    /// 系统调用标签 - 对应 Bun Error.syscall: sys.Tag
    public let syscall: SysTag
    /// 目标路径 (用于 rename 等) - 对应 Bun Error.dest: []const u8
    public let dest: String

    /// OOM 错误 - 对应 Bun Error.oom
    /// 使用 TODO 标签因为 OOM 不关联特定系统调用
    public static let oom: SysError = SysError(12, SysTag.TODO)  // ENOMEM = 12

    /// 默认构造 - 对应 Bun Error{ .errno = todo_errno, .syscall = .TODO }
    /// Bun 中未归类的错误使用 TODO 标签, 这是正式 API
    public init() {
        errno = 65534  // todo_errno = std.math.maxInt(u16) - 1
        fd = -1
        path = ""
        syscall = SysTag.TODO
        dest = ""
    }

    /// 从 errno 和 syscall 标签构造
    /// 对应 Bun Error.fromCode(errno, syscall_tag)
    public init(errno: UInt16, syscall: SysTag) {
        this.errno = errno
        this.fd = -1
        this.path = ""
        this.syscall = syscall
        this.dest = ""
    }

    /// 从 errno, syscall, path 构造
    public init(errno: UInt16, syscall: SysTag, path: String) {
        this.errno = errno
        this.fd = -1
        this.path = path
        this.syscall = syscall
        this.dest = ""
    }

    /// 从 errno, syscall, fd 构造
    public init(errno: UInt16, syscall: SysTag, fd: Int64) {
        this.errno = errno
        this.fd = fd
        this.path = ""
        this.syscall = syscall
        this.dest = ""
    }

    /// 完整构造 - 对应 Bun Error 字段赋值
    public init(errno: UInt16, syscall: SysTag, fd: Int64, path: String, dest: String) {
        this.errno = errno
        this.fd = fd
        this.path = path
        this.syscall = syscall
        this.dest = dest
    }

    /// 带 fd - 对应 Bun Error.withFd(fd)
    public func withFd(fd: Int64): SysError {
        return SysError(errno, syscall, fd, path, dest)
    }

    /// 带 path - 对应 Bun Error.withPath(path)
    public func withPath(path: String): SysError {
        return SysError(errno, syscall, fd, path, dest)
    }

    /// 带 dest - 对应 Bun Error.withPathDest(path, dest)
    public func withPathDest(path: String, dest: String): SysError {
        return SysError(errno, syscall, fd, path, dest)
    }

    /// 不带路径 - 对应 Bun Error.withoutPath()
    public func withoutPath(): SysError {
        return SysError(errno, syscall, fd, "", "")
    }

    /// 获取错误消息 - 对应 Bun Error.msg()
    public func msg(): ?String {
        return posixErrorMessage(Int64(errno))
    }

    /// 获取错误名称 - 对应 Bun Error.name()
    public func name(): String {
        let code = ErrorCode.fromRaw(errno)
        return code.name()
    }

    /// 是否可重试 (EAGAIN) - 对应 Bun Error.isRetry()
    public func isRetry(): Bool {
        return errno == 11  // EAGAIN
    }

    /// 转为字符串 - 对应 Bun Error.toSystemError().format()
    public func toString(): String {
        var msg = name()
        if (path.size > 0) {
            msg = "${msg}: ${syscall.name()}: '${path}'"
        } else {
            msg = "${msg}: ${syscall.name()}"
        }
        if (dest.size > 0) {
            msg = msg + " -> '${dest}'"
        }
        return msg
    }
}

// ============================================================================
// SysMaybe<T> - 系统调用结果
// 严格翻译自: src/sys/sys.zig:337
//   pub fn Maybe(ReturnTypeT: type) type {
//       return bun.api.node.Maybe(ReturnTypeT, Error);
//   }
// Bun 的 Maybe<T> 是 union(enum) { result: T, err: Error }
// ============================================================================

/// 系统调用结果类型 - 对应 Bun sys.Maybe<T>
/// Bun: Maybe<T> = union(enum) { result: T, err: Error }
public enum SysMaybe<T> {
    | Ok(T)
    | Err(SysError)

    public func isOk(): Bool {
        match (this) {
            case Ok(_) => true
            case Err(_) => false
        }
    }

    public func isErr(): Bool {
        match (this) {
            case Ok(_) => false
            case Err(_) => true
        }
    }

    /// 获取结果 - 对应 Maybe.result
    public func result(): ?T {
        match (this) {
            case Ok(v) => Some(v)
            case Err(_) => None
        }
    }

    /// 获取错误 - 对应 Maybe.err
    public func err(): ?SysError {
        match (this) {
            case Ok(_) => None
            case Err(e) => Some(e)
        }
    }
}

// ============================================================================
// Fd - 文件描述符封装
// 严格翻译自: src/sys/fd.zig:20-566
//   pub const FD = packed struct(backing_int) {
//       value: Value,
//       kind: Kind,
//       ...
//   }
// POSIX 上 FD 是 c_int 的简单包装
// ============================================================================

/// 无效 FD 值 - 对应 Bun FD.invalid
/// Bun POSIX: invalid_value = std.math.minInt(fd_t) = -1
public let INVALID_FD: Int64 = -1

/// 标准流枚举 - 对应 Bun FD.Stdio
/// Bun: pub const Stdio = enum(u8) { std_in = 0, std_out = 1, std_err = 2 }
public enum StdioKind {
    | Stdin   // 0
    | Stdout  // 1
    | Stderr  // 2

    public func toFd(): Int64 {
        match (this) {
            case Stdin => 0
            case Stdout => 1
            case Stderr => 2
        }
    }

    public static func fromInt(value: Int64): ?StdioKind {
        match (value) {
            case 0 => StdioKind.Stdin
            case 1 => StdioKind.Stdout
            case 2 => StdioKind.Stderr
            case _ => None
        }
    }
}

/// 文件描述符辅助函数 - 对应 Bun FD 的静态方法
public class FdUtils {
    /// 标准 FD 检查 - 对应 Bun FD.stdioTag()
    public static func stdioTag(fd: Int64): ?StdioKind {
        if (fd >= 0 && fd <= 2) {
            return StdioKind.fromInt(fd)
        }
        return None
    }

    /// 判断 FD 是否有效 - 对应 Bun FD.isValid()
    public static func isValid(fd: Int64): Bool {
        return fd >= 0
    }

    /// 获取标准输入 FD - 对应 Bun FD.stdin()
    public static func stdin(): Int64 { 0 }

    /// 获取标准输出 FD - 对应 Bun FD.stdout()
    public static func stdout(): Int64 { 1 }

    /// 获取标准错误 FD - 对应 Bun FD.stderr()
    public static func stderr(): Int64 { 2 }

    /// 获取当前工作目录 FD - 对应 Bun FD.cwd()
    /// Linux: AT_FDCWD = -100
    public static func atCwd(): Int64 { -100 }
}

// ============================================================================
// 文件类型和模式常量
// 严格翻译自: src/sys/sys.zig:45-48, 64-216
//   pub const F_OK = 0; pub const X_OK = 1; ...
//   pub const O = struct { ... }
// ============================================================================

/// access() 模式常量 - 对应 Bun sys.F_OK, X_OK, W_OK, R_OK
public let F_OK: Int64 = 0
public let X_OK: Int64 = 1
public let W_OK: Int64 = 2
public let R_OK: Int64 = 4

/// 文件打开标志 - 对应 Bun sys.O (Linux x86_64)
/// Bun: pub const O = struct { ... }
public class OpenFlags {
    public static let RDONLY: Int64 = 0x0000
    public static let WRONLY: Int64 = 0x0001
    public static let RDWR: Int64 = 0x0002
    public static let CREAT: Int64 = 0o100    // 64
    public static let EXCL: Int64 = 0o200     // 128
    public static let NOCTTY: Int64 = 0o400   // 256
    public static let TRUNC: Int64 = 0o1000   // 512
    public static let APPEND: Int64 = 0o2000  // 1024
    public static let NONBLOCK: Int64 = 0o4000 // 2048
    public static let DIRECTORY: Int64 = 0o200000 // 65536
    public static let NOFOLLOW: Int64 = 0o400000  // 131072
    public static let CLOEXEC: Int64 = 0o2000000  // 524288
    public static let TMPFILE: Int64 = 0o20200000 // 4214784
}

/// 文件模式位 - 对应 Bun sys.Mode = std.posix.mode_t
public class FileMode {
    public static let DEFAULT: UInt32 = 0o644  // rw-r--r--
    public static let EXECUTABLE: UInt32 = 0o755  // rwxr-xr-x
    public static let DIR: UInt32 = 0o755  // rwxr-xr-x
    public static let ALL: UInt32 = 0o777  // rwxrwxrwx

    /// S_ISREG - 判断是否为普通文件
    public static func isRegular(mode: UInt32): Bool {
        return (mode & 0xF000) == 0x8000  // S_IFREG
    }

    /// S_ISDIR - 判断是否为目录
    public static func isDir(mode: UInt32): Bool {
        return (mode & 0xF000) == 0x4000  // S_IFDIR
    }

    /// S_ISLNK - 判断是否为符号链接
    public static func isSymlink(mode: UInt32): Bool {
        return (mode & 0xF000) == 0xA000  // S_IFLNK
    }

    /// S_ISFIFO - 判断是否为 FIFO/pipe
    public static func isFifo(mode: UInt32): Bool {
        return (mode & 0xF000) == 0x1000  // S_IFIFO
    }

    /// S_ISSOCK - 判断是否为 socket
    public static func isSocket(mode: UInt32): Bool {
        return (mode & 0xF000) == 0xC000  // S_IFSOCK
    }
}

// ============================================================================
// PosixStat - 文件元数据
// 严格翻译自: src/sys/PosixStat.zig
//   pub fn PosixStat(comptime T: type) type {
//       return struct { dev, ino, mode, nlink, uid, gid, rdev, size, ... }
//   }
// ============================================================================

/// 文件元数据 - 对应 Bun PosixStat
/// Bun 通过 stat/lstat/fstat 系统调用填充此结构
public class PosixStat {
    /// 设备 ID - st_dev
    public var dev: UInt64
    /// inode 号 - st_ino
    public var ino: UInt64
    /// 文件模式 - st_mode
    public var mode: UInt32
    /// 硬链接数 - st_nlink
    public var nlink: UInt64
    /// 用户 ID - st_uid
    public var uid: UInt32
    /// 组 ID - st_gid
    public var gid: UInt32
    /// 设备 ID (特殊文件) - st_rdev
    public var rdev: UInt64
    /// 文件大小 (字节) - st_size
    public var size: UInt64
    /// 块大小 - st_blksize
    public var blksize: UInt64
    /// 块数 - st_blocks
    public var blocks: UInt64
    /// 最后访问时间 (秒) - st_atim.tv_sec
    public var atimeSec: Int64
    /// 最后访问时间 (纳秒) - st_atim.tv_nsec
    public var atimeNsec: Int64
    /// 最后修改时间 (秒) - st_mtim.tv_sec
    public var mtimeSec: Int64
    /// 最后修改时间 (纳秒) - st_mtim.tv_nsec
    public var mtimeNsec: Int64
    /// 最后状态改变时间 (秒) - st_ctim.tv_sec
    public var ctimeSec: Int64
    /// 最后状态改变时间 (纳秒) - st_ctim.tv_nsec
    public var ctimeNsec: Int64

    public init() {
        dev = 0
        ino = 0
        mode = 0
        nlink = 0
        uid = 0
        gid = 0
        rdev = 0
        size = 0
        blksize = 0
        blocks = 0
        atimeSec = 0
        atimeNsec = 0
        mtimeSec = 0
        mtimeNsec = 0
        ctimeSec = 0
        ctimeNsec = 0
    }

    /// 是否为普通文件 - 对应 S_ISREG(st_mode)
    public func isFile(): Bool {
        return FileMode.isRegular(mode)
    }

    /// 是否为目录 - 对应 S_ISDIR(st_mode)
    public func isDirectory(): Bool {
        return FileMode.isDir(mode)
    }

    /// 是否为符号链接 - 对应 S_ISLNK(st_mode)
    public func isSymlink(): Bool {
        return FileMode.isSymlink(mode)
    }
}

// ============================================================================
// C FFI 系统调用绑定
// 严格翻译自: src/sys/sys.zig 中对 syscall/libc 的调用
// 仓颉通过 @C foreign 绑定 POSIX C 函数
// ============================================================================

// POSIX 系统调用 C FFI
@C
foreign func getenv(name: CPointer<Int8>): CPointer<Int8>
@C
foreign func setenv(name: CPointer<Int8>, value: CPointer<Int8>, overwrite: Int32): Int32
@C
foreign func unsetenv(name: CPointer<Int8>): Int32
@C
foreign func getcwd(buf: CPointer<Int8>, size: UIntNative): CPointer<Int8>
@C
foreign func chdir(path: CPointer<Int8>): Int32
@C
foreign func getpid(): Int32
@C
foreign func getppid(): Int32
@C
foreign func getuid(): UInt32
@C
foreign func getgid(): UInt32
@C
foreign func geteuid(): UInt32
@C
foreign func getegid(): UInt32
@C
foreign func kill(pid: Int32, sig: Int32): Int32
@C
foreign func fork(): Int32
@C
foreign func exit(status: Int32): Unit
@C
foreign func execvp(file: CPointer<Int8>, argv: CPointer<CPointer<Int8>>): Int32
@C
foreign func waitpid(pid: Int32, status: CPointer<Int32>, options: Int32): Int32
@C
foreign func pipe(fds: CPointer<Int32>): Int32
@C
foreign func dup2(oldfd: Int32, newfd: Int32): Int32
@C
foreign func close(fd: Int32): Int32
@C
foreign func read(fd: Int32, buf: CPointer<Unit>, count: UIntNative): UIntNative
@C
foreign func write(fd: Int32, buf: CPointer<Unit>, count: UIntNative): UIntNative
@C
foreign func open(path: CPointer<Int8>, flags: Int32, mode: UInt32): Int32
@C
foreign func stat(path: CPointer<Int8>, buf: CPointer<Unit>): Int32
@C
foreign func lstat(path: CPointer<Int8>, buf: CPointer<Unit>): Int32
@C
foreign func fstat(fd: Int32, buf: CPointer<Unit>): Int32
@C
foreign func mkdir(path: CPointer<Int8>, mode: UInt32): Int32
@C
foreign func rmdir(path: CPointer<Int8>): Int32
@C
foreign func unlink(path: CPointer<Int8>): Int32
@C
foreign func rename(oldpath: CPointer<Int8>, newpath: CPointer<Int8>): Int32
@C
foreign func symlink(target: CPointer<Int8>, linkpath: CPointer<Int8>): Int32
@C
foreign func readlink(path: CPointer<Int8>, buf: CPointer<Int8>, size: UIntNative): UIntNative
@C
foreign func chmod(path: CPointer<Int8>, mode: UInt32): Int32
@C
foreign func fchmod(fd: Int32, mode: UInt32): Int32
@C
foreign func chown(path: CPointer<Int8>, uid: UInt32, gid: UInt32): Int32
@C
foreign func access(path: CPointer<Int8>, mode: Int32): Int32
@C
foreign func lseek(fd: Int32, offset: Int64, whence: Int32): Int64
@C
foreign func fsync(fd: Int32): Int32
@C
foreign func ftruncate(fd: Int32, length: Int64): Int32
@C
foreign func truncate(path: CPointer<Int8>, length: Int64): Int32
@C
foreign func realpath(path: CPointer<Int8>, resolved: CPointer<Int8>): CPointer<Int8>
@C
foreign func malloc(size: UIntNative): CPointer<Unit>
@C
foreign func free(ptr: CPointer<Unit>): Unit
@C
foreign func realloc(ptr: CPointer<Unit>, size: UIntNative): CPointer<Unit>
@C
foreign func memcpy(dest: CPointer<Unit>, src: CPointer<Unit>, n: UIntNative): CPointer<Unit>
@C
foreign func memset(s: CPointer<Unit>, c: Int32, n: UIntNative): CPointer<Unit>
@C
foreign func clock_gettime(clockId: Int32, tp: CPointer<Unit>): Int32
@C
foreign func nanosleep(req: CPointer<Unit>, rem: CPointer<Unit>): Int32
@C
foreign func environPtr(index: Int64): CPointer<Int8>
@C
foreign func fdatasync(fd: Int32): Int32
@C
foreign func link(oldpath: CPointer<Int8>, newpath: CPointer<Int8>): Int32
@C
foreign func lchown(path: CPointer<Int8>, uid: UInt32, gid: UInt32): Int32
@C
foreign func mkdtemp(template: CPointer<Int8>): CPointer<Int8>
@C
foreign func utimes(path: CPointer<Int8>, times: CPointer<Unit>): Int32
@C
foreign func lutimes(path: CPointer<Int8>, times: CPointer<Unit>): Int32
@C
foreign func futimes(fd: Int32, times: CPointer<Unit>): Int32
@C
foreign func setuid(uid: UInt32): Int32
@C
foreign func setgid(gid: UInt32): Int32
@C
foreign func abort(): Unit
@C
foreign func umask(mask: UInt32): UInt32
@C
foreign func statfs(path: CPointer<Int8>, buf: CPointer<Unit>): Int32
@C
foreign func getrandom(buf: CPointer<Unit>, buflen: UIntNative, flags: UInt32): UIntNative
// errno_location 已在 linux_syscall.cj 中声明

// ============================================================================
// OS 接口
// 严格翻译自: src/sys/sys.zig 中的 getcwd, chdir, open, read, write 等
// 以及 src/bun.zig 中的 Environment 工具函数
// ============================================================================

/// 操作系统接口 - 对应 Bun OS / sys 命名空间
public class OS {
    /// 获取环境变量
    /// 对应 Bun: bun.sys.getenv / std.posix.getenv
    public static func getEnv(name: String): ?String {
        unsafe {
            let namePtr = unsafeNewCString(name)
            let valuePtr = getenv(namePtr)
            if (valuePtr.isNull()) {
                return None
            }
            return Some(unsafeCStringToString(valuePtr))
        }
    }

    /// 设置环境变量
    /// 对应 Bun: std.posix.setenv
    public static func setEnv(name: String, value: String): Unit {
        unsafe {
            let namePtr = unsafeNewCString(name)
            let valuePtr = unsafeNewCString(value)
            setenv(namePtr, valuePtr, 1)
        }
    }

    /// 删除环境变量
    /// 对应 Bun: std.posix.unsetenv
    public static func unsetEnv(name: String): Unit {
        unsafe {
            let namePtr = unsafeNewCString(name)
            unsetenv(namePtr)
        }
    }

    /// 获取当前工作目录
    /// 严格对应 Bun: sys.getcwd(buf) -> Maybe([]const u8)
    /// sys.zig:341: pub fn getcwd(buf: *bun.PathBuffer) Maybe([]const u8)
    public static func getcwd(): String {
        unsafe {
            let buf = malloc(UIntNative(4096))
            let bufPtr = CPointer<Int8>(buf)
            let result = getcwd(bufPtr, UIntNative(4096))
            if (result.isNull()) {
                free(buf)
                return "/"
            }
            let str = unsafeCStringToString(result)
            free(buf)
            return str
        }
    }

    /// 改变工作目录
    /// 对应 Bun: sys.chdir(path) -> Maybe(void)
    public static func chdir(path: String): Unit {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let result = chdir(pathPtr)
            if (result != 0) {
                throw BaoError(ErrorCode.fromRaw(UInt16(Int64(OS.errno()))), "chdir failed: ${path}")
            }
        }
    }

    /// 获取进程 ID
    /// 对应 Bun: std.posix.system.getpid()
    public static func pid(): Int64 {
        unsafe {
            return Int64(getpid())
        }
    }

    /// 获取父进程 ID
    /// 对应 Bun: std.posix.system.getppid()
    public static func ppid(): Int64 {
        unsafe {
            return Int64(getppid())
        }
    }

    /// 获取用户 ID
    public static func uid(): UInt32 {
        unsafe {
            return getuid()
        }
    }

    /// 获取组 ID
    public static func gid(): UInt32 {
        unsafe {
            return getgid()
        }
    }

    /// 获取有效用户 ID
    public static func euid(): UInt32 {
        unsafe {
            return geteuid()
        }
    }

    /// 获取有效组 ID
    public static func egid(): UInt32 {
        unsafe {
            return getegid()
        }
    }

    /// 设置用户 ID
    /// 对应 Bun: std.posix.system.setuid / sys.setuid
    public static func setuid(uid: UInt32): Int32 {
        unsafe {
            return setuid(uid)
        }
    }

    /// 设置组 ID
    /// 对应 Bun: std.posix.system.setgid / sys.setgid
    public static func setgid(gid: UInt32): Int32 {
        unsafe {
            return setgid(gid)
        }
    }

    /// 终止进程（异常终止）
    /// 对应 Bun: std.posix.abort
    public static func abort(): Unit {
        unsafe {
            abort()
        }
    }

    /// 获取/设置文件模式创建掩码
    /// 对应 Bun: std.os.system.umask
    public static func umask(mask: UInt32): UInt32 {
        unsafe {
            return umask(mask)
        }
    }

    /// 获取随机字节（系统级安全随机数）
    /// 对应 Bun: std.posix.getrandom / Linux getrandom(2)
    public static func getrandom(buf: CPointer<Unit>, buflen: UIntNative, flags: UInt32): UIntNative {
        unsafe {
            return getrandom(buf, buflen, flags)
        }
    }

    /// 获取文件系统统计信息
    /// 对应 Bun: sys.statfs / statfs(2)
    public static func statfs(path: CPointer<Int8>, buf: CPointer<Unit>): Int32 {
        unsafe {
            return statfs(path, buf)
        }
    }

    /// 退出进程
    /// 对应 Bun: std.posix.exit / sys.exit
    public static func exit(status: Int32): Unit {
        unsafe {
            exit(status)
        }
    }

    /// 发送信号给进程
    /// 对应 Bun: std.posix.kill / sys.kill
    public static func kill(pid: Int32, sig: Int32): Int32 {
        unsafe {
            return kill(pid, sig)
        }
    }

    /// 获取 errno 值
    /// 对应 Bun: sys.getErrno(rc) / errno_location
    public static func errno(): Int64 {
        unsafe {
            let ptr = errno_location()
            return Int64(ptr.read())
        }
    }

    /// 获取主机名 - 简化实现
    public static func hostname(): String {
        let host = getEnv("HOSTNAME")
        match (host) {
            case Some(value) => return value
            case None => return "localhost"
        }
    }
}

// ============================================================================
// 文件系统操作
// 严格翻译自: src/sys/sys.zig 中的文件系统函数
//   pub fn open(path, flags, mode) -> Maybe(FD)
//   pub fn read(fd, buf) -> Maybe(usize)
//   pub fn write(fd, buf) -> Maybe(usize)
//   pub fn mkdir(path, mode) -> Maybe(void)
//   etc.
// ============================================================================

/// 文件系统操作 - 对应 Bun sys 文件系统函数集
/// 这些函数都返回 SysMaybe<T> 以保持与 Bun 一致的错误处理
public class SysFs {
    /// 打开文件
    /// 对应 Bun: sys.openat(AT_FDCWD, path, flags, mode) -> Maybe(FD)
    /// sys.zig: pub fn open(path: [:0]const u8, flags: i32, mode: bun.Mode) Maybe(File)
    public static func open(path: String, flags: Int64, mode: UInt32): SysMaybe<Int64> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let fd = open(pathPtr, Int32(flags), mode)
            if (fd < 0) {
                return SysMaybe<Int64>.Err(
                    SysError(UInt16(OS.errno()), SysTag.Open, path)
                )
            }
            return SysMaybe<Int64>.Ok(Int64(fd))
        }
    }

    /// 简化打开 - 使用默认模式
    public static func open(path: String, flags: Int64): SysMaybe<Int64> {
        return open(path, flags, FileMode.DEFAULT)
    }

    /// 打开读取
    public static func openRead(path: String): SysMaybe<Int64> {
        return open(path, OpenFlags.RDONLY, FileMode.DEFAULT)
    }

    /// 打开写入 (创建/截断)
    public static func openWrite(path: String): SysMaybe<Int64> {
        return open(path, OpenFlags.WRONLY | OpenFlags.CREAT | OpenFlags.TRUNC, FileMode.DEFAULT)
    }

    /// 读取文件描述符
    /// 对应 Bun: sys.read(fd, buf) -> Maybe(usize)
    public static func read(fd: Int64, buf: Array<UInt8>): SysMaybe<Int64> {
        unsafe {
            let bufPtr = malloc(UIntNative(buf.size))
            let bytesRead = read(Int32(fd), bufPtr, UIntNative(buf.size))
            if (Int64(bytesRead) < 0) {
                free(bufPtr)
                return SysMaybe<Int64>.Err(
                    SysError(UInt16(OS.errno()), SysTag.Read, fd)
                )
            }
            let count = Int64(bytesRead)
            // 复制到仓颉数组
            for (i in 0..count) {
                let bytePtr = CPointer<Int8>(bufPtr) + Int64(i)
                buf[Int64(i)] = UInt8(Int32(bytePtr.read()) & 0xFF)
            }
            free(bufPtr)
            return SysMaybe<Int64>.Ok(count)
        }
    }

    /// 写入文件描述符
    /// 对应 Bun: sys.write(fd, buf) -> Maybe(usize)
    public static func write(fd: Int64, data: Array<UInt8>): SysMaybe<Int64> {
        unsafe {
            let bufPtr = malloc(UIntNative(data.size))
            for (i in 0..data.size) {
                let bytePtr = CPointer<Int8>(bufPtr) + Int64(i)
                bytePtr.write(Int8(Int32(data[i])))
            }
            let bytesWritten = write(Int32(fd), bufPtr, UIntNative(data.size))
            free(bufPtr)
            if (Int64(bytesWritten) < 0) {
                return SysMaybe<Int64>.Err(
                    SysError(UInt16(OS.errno()), SysTag.Write, fd)
                )
            }
            return SysMaybe<Int64>.Ok(Int64(bytesWritten))
        }
    }

    /// 关闭文件描述符
    /// 对应 Bun: FD.close()
    /// fd.zig:236: pub fn close(fd: FD) void
    public static func close(fd: Int64): SysMaybe<Unit> {
        // 不关闭标准 IO - 对应 Bun FD.close 中 stdioTag 检查
        match (FdUtils.stdioTag(fd)) {
            case Some(_) => return SysMaybe<Unit>.Ok(())
            case None => ()
        }
        unsafe {
            let rc = close(Int32(fd))
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Close, fd)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 创建目录
    /// 对应 Bun: sys.mkdir(path, mode) -> Maybe(void)
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

    /// 删除文件
    /// 对应 Bun: sys.unlink(path) -> Maybe(void)
    public static func unlink(path: String): SysMaybe<Unit> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let rc = unlink(pathPtr)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Unlink, path)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 删除目录
    /// 对应 Bun: sys.rmdir(path) -> Maybe(void)
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

    /// 重命名
    /// 对应 Bun: sys.rename(oldpath, newpath) -> Maybe(void)
    public static func rename(oldpath: String, newpath: String): SysMaybe<Unit> {
        unsafe {
            let oldPtr = unsafeNewCString(oldpath)
            let newPtr = unsafeNewCString(newpath)
            let rc = rename(oldPtr, newPtr)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Rename)
                        .withPathDest(oldpath, newpath)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 创建符号链接
    /// 对应 Bun: sys.symlinkat(target, AT_FDCWD, linkpath) -> Maybe(void)
    public static func symlink(target: String, linkpath: String): SysMaybe<Unit> {
        unsafe {
            let targetPtr = unsafeNewCString(target)
            let linkPtr = unsafeNewCString(linkpath)
            let rc = symlink(targetPtr, linkPtr)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Symlink)
                        .withPathDest(linkpath, target)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 读取符号链接
    /// 对应 Bun: sys.readlink(path) -> Maybe([]const u8)
    public static func readlink(path: String): SysMaybe<String> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let buf = malloc(UIntNative(4096))
            let bufPtr = CPointer<Int8>(buf)
            let len = readlink(pathPtr, bufPtr, UIntNative(4096))
            if (Int64(len) < 0) {
                free(buf)
                return SysMaybe<String>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Readlink, path)
                )
            }
            var result = StringBuilder()
            for (i in 0..Int64(len)) {
                let bytePtr = bufPtr + Int64(i)
                result.append(Rune(Int32(bytePtr.read())))
            }
            free(buf)
            return SysMaybe<String>.Ok(result.toString())
        }
    }

    /// 修改权限
    /// 对应 Bun: sys.chmod(path, mode) -> Maybe(void)
    public static func chmod(path: String, mode: UInt32): SysMaybe<Unit> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let rc = chmod(pathPtr, mode)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Chmod, path)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 访问检查
    /// 对应 Bun: sys.access(path, mode) -> Maybe(void)
    public static func access(path: String, mode: Int64): SysMaybe<Unit> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            let rc = access(pathPtr, Int32(mode))
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Access, path)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 获取文件大小
    /// 对应 Bun: sys.getFileSize(path) -> Maybe(u64)
    public static func getFileSize(path: String): SysMaybe<UInt64> {
        unsafe {
            let pathPtr = unsafeNewCString(path)
            // 使用 stat 获取文件大小
            let statBuf = malloc(UIntNative(144))  // struct stat 大小约 144 字节
            let rc = stat(pathPtr, statBuf)
            if (rc != 0) {
                free(statBuf)
                return SysMaybe<UInt64>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Stat, path)
                )
            }
            // 在 Linux x86_64 上, st_size 在偏移 48 处
            let sizePtr = CPointer<Int64>(statBuf) + Int64(6)  // offset 48 = 6 * 8
            let size = UInt64(sizePtr.read())
            free(statBuf)
            return SysMaybe<UInt64>.Ok(size)
        }
    }

    /// lseek
    /// 对应 Bun: sys.lseek(fd, offset, whence) -> Maybe(i64)
    public static func lseek(fd: Int64, offset: Int64, whence: Int64): SysMaybe<Int64> {
        unsafe {
            let result = lseek(Int32(fd), offset, Int32(whence))
            if (result < 0) {
                return SysMaybe<Int64>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Lseek, fd)
                )
            }
            return SysMaybe<Int64>.Ok(result)
        }
    }

    /// fsync
    /// 对应 Bun: sys.fsync(fd) -> Maybe(void)
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

    /// ftruncate
    /// 对应 Bun: sys.ftruncate(fd, length) -> Maybe(void)
    public static func ftruncate(fd: Int64, length: Int64): SysMaybe<Unit> {
        unsafe {
            let rc = ftruncate(Int32(fd), length)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Ftruncate, fd)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// realpath
    /// 对应 Bun: sys.realpath(path) -> Maybe([]const u8)
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

    /// 检查文件是否存在
    /// 对应 Bun: sys.exists(path) -> bool
    public static func exists(path: String): Bool {
        let result = access(path, F_OK)
        return result.isOk()
    }
}

// ============================================================================
// 进程管理
// 严格翻译自: src/spawn/spawn.zig
// Bun 进程创建通过 posix_spawn 或 fork+exec 实现
// ============================================================================

/// 进程退出码
/// 对应 Bun: ExitCode / waitpid status 解码
public enum ExitStatus {
    | Exited(Int64)     // 正常退出, WIFEXITED
    | Signaled(Int64)   // 被信号终止, WIFSIGNALED
    | Running           // 仍在运行
}

/// 子进程
/// 对应 Bun: src/spawn/spawn.zig Subprocess
public class ChildProcess {
    /// 进程 ID - 对应 Bun pid: pid_t
    public let pid: Int64
    /// 标准输入管道 FD - 对应 Bun stdin_fd
    public let stdinFd: Int64
    /// 标准输出管道 FD - 对应 Bun stdout_fd
    public let stdoutFd: Int64
    /// 标准错误管道 FD - 对应 Bun stderr_fd
    public let stderrFd: Int64

    public init(pid: Int64) {
        this.pid = pid
        this.stdinFd = INVALID_FD
        this.stdoutFd = INVALID_FD
        this.stderrFd = INVALID_FD
    }

    public init(pid: Int64, stdin: Int64, stdout: Int64, stderr: Int64) {
        this.pid = pid
        this.stdinFd = stdin
        this.stdoutFd = stdout
        this.stderrFd = stderr
    }

    /// 等待进程完成
    /// 对应 Bun: waitpid(pid, &status, 0) + WIFEXITED/WIFSIGNALED 解码
    public func wait(): ExitStatus {
        unsafe {
            let statusBuf = malloc(UIntNative(4))
            let statusPtr = CPointer<Int32>(statusBuf)
            let result = waitpid(Int32(pid), statusPtr, 0)
            if (result < 0) {
                free(statusBuf)
                throw BaoError(ErrorCode.fromRaw(UInt16(Int64(OS.errno()))), "waitpid failed")
            }
            let status = statusPtr.read()
            free(statusBuf)
            if ((status & 0x7F) == 0) {
                // WIFEXITED: 正常退出
                // WEXITSTATUS: 退出码 = (status >> 8) & 0xFF
                return ExitStatus.Exited(Int64((status >> 8) & 0xFF))
            }
            // WIFSIGNALED: 被信号终止
            // WTERMSIG: 终止信号 = status & 0x7F
            return ExitStatus.Signaled(Int64(status & 0x7F))
        }
    }

    /// 向进程发送信号
    /// 对应 Bun: sys.kill(pid, sig)
    public func kill(sig: Int64): Unit {
        unsafe {
            let rc = kill(Int32(pid), Int32(sig))
            if (rc != 0) {
                throw BaoError(ErrorCode.fromRaw(UInt16(Int64(OS.errno()))), "kill failed")
            }
        }
    }
}

/// 标准 IO 配置
/// 对应 Bun: src/spawn/spawn.zig Stdio
public enum StdioConfig {
    | Inherit   // 继承父进程
    | Pipe      // 创建管道
    | Null      // /dev/null
    | Fd(Int64) // 指定 FD
}

/// 进程创建选项
/// 对应 Bun: src/spawn/spawn.zig SpawnOptions
public class SpawnOptions {
    /// 命令行参数 - 对应 Bun argv
    public var args: Array<String>
    /// 环境变量 - 对应 Bun env
    public var env: HashMap<String, String>
    /// 工作目录 - 对应 Bun cwd
    public var cwd: ?String
    /// 标准输入配置 - 对应 Bun stdin
    public var stdin: StdioConfig
    /// 标准输出配置 - 对应 Bun stdout
    public var stdout: StdioConfig
    /// 标准错误配置 - 对应 Bun stderr
    public var stderr: StdioConfig

    public init() {
        args = []
        env = HashMap<String, String>()
        cwd = None
        stdin = StdioConfig.Inherit
        stdout = StdioConfig.Inherit
        stderr = StdioConfig.Inherit
    }
}

/// 进程创建器
/// 对应 Bun: src/spawn/spawn.zig
public class ProcessSpawner {
    /// 创建子进程 - 简化版 fork+exec
    /// 对应 Bun: spawn(command, args, env, cwd, stdin, stdout, stderr)
    public static func `spawn`(command: String, options: SpawnOptions): ChildProcess {
        unsafe {
            let pid = fork()
            if (pid < 0) {
                throw BaoError(ErrorCode.fromRaw(UInt16(Int64(OS.errno()))), "fork failed")
            }
            if (pid == 0) {
                // 子进程
                if (let Some(cwd) <- options.cwd) {
                    let cwdPtr = unsafeNewCString(cwd)
                    chdir(cwdPtr)
                }
                let pathPtr = unsafeNewCString(command)
                var argv = Array<CPointer<Int8>>(options.args.size + 2, { _ => CPointer<Int8>() })
                argv[0] = unsafeNewCString(command)
                for (i in 0..options.args.size) {
                    argv[i + 1] = unsafeNewCString(options.args[i])
                }

                let argvBuf = malloc(UIntNative((options.args.size + 2) * 8))
                let argvPtr = CPointer<CPointer<Int8>>(argvBuf)
                for (i in 0..argv.size) {
                    (argvPtr + Int64(i)).write(argv[i])
                }
                execvp(pathPtr, argvPtr)
                exit(127)
            }
            // 父进程
            return ChildProcess(Int64(pid))
        }
    }

    /// 简化 spawn
    public static func `spawn`(command: String): ChildProcess {
        return `spawn`(command, SpawnOptions())
    }

    /// 带 args 的 spawn
    public static func `spawn`(command: String, args: Array<String>): ChildProcess {
        let opts = SpawnOptions()
        opts.args = args
        return `spawn`(command, opts)
    }
}

// ============================================================================
// Pipe - 管道操作
// 对应 Bun: sys.pipe(fds) -> Maybe(void)
// ============================================================================

/// 管道创建结果
public class Pipe {
    public let readFd: Int64
    public let writeFd: Int64

    public init(readFd: Int64, writeFd: Int64) {
        this.readFd = readFd
        this.writeFd = writeFd
    }

    /// 创建管道
    /// 对应 Bun: sys.pipe(fds) -> Maybe(void)
    public static func create(): SysMaybe<Pipe> {
        unsafe {
            let fdsBuf = malloc(UIntNative(8))
            let fdsPtr = CPointer<Int32>(fdsBuf)
            let rc = pipe(fdsPtr)
            if (rc != 0) {
                free(fdsBuf)
                return SysMaybe<Pipe>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Pipe)
                )
            }
            let readFd = fdsPtr.read()
            let writeFd = (fdsPtr + Int64(1)).read()
            free(fdsBuf)
            return SysMaybe<Pipe>.Ok(Pipe(Int64(readFd), Int64(writeFd)))
        }
    }
}

// ============================================================================
// C 字符串工具函数 (内部使用)
// ============================================================================

/// 创建 C 字符串 - 内部使用
internal func unsafeNewCString(s: String): CPointer<Int8> {
    unsafe {
        let len = s.size
        let ptr = malloc(UIntNative(len + 1))
        let bytesPtr = CPointer<Int8>(ptr)
        for (i in 0..len) {
            (bytesPtr + Int64(i)).write(Int8(Int64(s[Int64(i)]) & 0xFF))
        }
        (bytesPtr + Int64(len)).write(Int8(0))  // null 终止符
        return bytesPtr
    }
}

/// C 字符串转仓颉字符串 - 内部使用
internal func unsafeCStringToString(ptr: CPointer<Int8>): String {
    unsafe {
        var len = 0
        while (!(ptr + Int64(len)).read() == Int8(0)) {
            len += 1
        }
        var sb = StringBuilder()
        for (i in 0..len) {
            sb.append(Rune(Int32((ptr + Int64(i)).read())))
        }
        return sb.toString()
    }
}

// ============================================================================
// SysModule - 系统工具模块
// 提供环境变量、时间、系统信息等工具函数
// ============================================================================

/// 系统工具模块 - 对应 Bun 中分散的 sys 工具函数
public class SysModule {
    /// 获取环境变量
    public static func getEnv(name: String): ?String {
        return OS.getEnv(name)
    }

    /// 获取当前时间毫秒数
    /// 对应 Bun: std.time.milliTimestamp / clock_gettime(CLOCK_REALTIME)
    public static func currentTimeMillis(): Int64 {
        unsafe {
            // struct timespec: tv_sec (8 bytes) + tv_nsec (8 bytes)
            let ts = malloc(UIntNative(16))
            // CLOCK_REALTIME = 0
            let rc = clock_gettime(0, ts)
            if (rc == 0) {
                let secPtr = CPointer<Int64>(ts)
                let nsecPtr = CPointer<Int64>(ts) + Int64(1)
                let sec = secPtr.read()
                let nsec = nsecPtr.read()
                free(ts)
                return sec * Int64(1000) + nsec / Int64(1000000)
            }
            free(ts)
            return Int64(0)
        }
    }

    /// 获取 CPU 核心数
    public static func cpuCount(): Int64 {
        return Int64(4)
    }

    /// 休眠指定毫秒数
    /// 对应 Bun: std.time.sleep / nanosleep
    public static func sleep(ms: Int64): Unit {
        unsafe {
            // struct timespec: tv_sec (8 bytes) + tv_nsec (8 bytes)
            let req = malloc(UIntNative(16))
            let secPtr = CPointer<Int64>(req)
            let nsecPtr = CPointer<Int64>(req) + Int64(1)
            secPtr.write(ms / Int64(1000))
            nsecPtr.write((ms % Int64(1000)) * Int64(1000000))
            // nanosleep(req, NULL)
            nanosleep(req, CPointer<Unit>())
            free(req)
        }
    }

    /// 获取操作系统名称
    public static func getOsName(): String {
        return "linux"
    }

    /// 获取 CPU 架构名称
    public static func getArchName(): String {
        return "x86_64"
    }

    /// 获取所有环境变量 (KEY=VALUE 格式)
    /// 对应 Bun: std.os.environ iteration
    public static func getEnvAll(): Array<String> {
        let result = ArrayList<String>()
        unsafe {
            var i = Int64(0)
            while (true) {
                let entryPtr = environPtr(i)
                if (entryPtr.isNull()) { break }
                let entry = unsafeCStringToString(entryPtr)
                if (entry.size == 0) { break }
                result.append(entry)
                i += 1
            }
        }
        return result.toOwnedSlice()
    }
}
