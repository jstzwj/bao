// bao_sys - libuv C FFI 绑定
// 严格翻译自: src/sys/sys_uv.zig
//   Bun 使用 libuv 在 Windows 上实现跨平台文件系统操作
//   仓颉通过 C FFI 绑定 libuv 核心数据结构和操作
//   包括: uv_loop_t, uv_tcp_t, uv_timer_t, uv_fs_t, uv_stream_t
package bao_sys

import bao_core.*

// ============================================================================
// libuv 类型定义 (Opaque pointers)
// 严格翻译自: libuv 头文件 uv.h
//   libuv 使用不透明指针 (opaque pointer) 表示句柄和请求
//   仓颉通过 CPointer<Unit> 表示不透明指针
// ============================================================================

/// libuv 句柄类型枚举 - 对应 uv_handle_type
/// uv.h: typedef enum { UV_UNKNOWN_HANDLE=0, UV_ASYNC, UV_CHECK, UV_FS_EVENT,
///   UV_FS_POLL, UV_HANDLE, UV_IDLE, UV_NAMED_PIPE, UV_POLL, UV_PREPARE,
///   UV_PROCESS, UV_STREAM, UV_TCP, UV_TIMER, UV_TTY, UV_UDP, UV_SIGNAL } uv_handle_type;
public enum UvHandleType {
    | Unknown       // UV_UNKNOWN_HANDLE
    | Async         // UV_ASYNC
    | Check         // UV_CHECK
    | FsEvent       // UV_FS_EVENT
    | FsPoll        // UV_FS_POLL
    | Idle          // UV_IDLE
    | NamedPipe     // UV_NAMED_PIPE
    | Poll          // UV_POLL
    | Prepare       // UV_PREPARE
    | Process       // UV_PROCESS
    | Stream        // UV_STREAM
    | Tcp           // UV_TCP
    | Timer         // UV_TIMER
    | Tty           // UV_TTY
    | Udp           // UV_UDP
    | Signal        // UV_SIGNAL

    /// 从整数值转换 - 对应 uv_handle_type 枚举值
    public static func fromInt(v: Int32): UvHandleType {
        match (v) {
            case 0 => Unknown
            case 1 => Async
            case 2 => Check
            case 3 => FsEvent
            case 4 => FsPoll
            case 6 => Idle
            case 7 => NamedPipe
            case 8 => Poll
            case 9 => Prepare
            case 10 => Process
            case 12 => Stream
            case 14 => Tcp
            case 15 => Timer
            case 16 => Tty
            case 17 => Udp
            case 18 => Signal
            case _ => Unknown
        }
    }
}

// ============================================================================
// libuv 运行模式 - 对应 uv_run_mode
// ============================================================================

/// 运行模式 - 对应 uv_run_mode
/// UV_RUN_DEFAULT = 0, UV_RUN_ONCE = 1, UV_RUN_NOWAIT = 2
public enum UvRunMode {
    | Default   // UV_RUN_DEFAULT - 运行直到没有活跃句柄
    | Once      // UV_RUN_ONCE - 最多处理一个事件
    | NoWait    // UV_RUN_NOWAIT - 非阻塞

    public func toInt(): Int32 {
        match (this) {
            case Default => 0
            case Once => 1
            case NoWait => 2
        }
    }
}

// ============================================================================
// libuv 错误码映射
// 严格翻译自: src/sys/libuv_error_map.zig
//   Bun 将 libuv 错误码映射为 POSIX errno
// ============================================================================

/// libuv 错误码映射 - 对应 Bun libuv_error_map
/// libuv 错误码为负值，映射到对应的 POSIX errno
public class UvErrno {
    /// UV_EPERM = -4048
    public static let EPERM: Int32 = -4048
    /// UV_ENOENT = -4058
    public static let ENOENT: Int32 = -4058
    /// UV_ESRCH = -4060
    public static let ESRCH: Int32 = -4060
    /// UV_EINTR = -4027
    public static let EINTR: Int32 = -4027
    /// UV_EIO = -4027
    public static let EIO: Int32 = -4027
    /// UV_EACCES = -4029
    public static let EACCES: Int32 = -4029
    /// UV_EEXIST = -4030
    public static let EEXIST: Int32 = -4030
    /// UV_ENOTDIR = -4036
    public static let ENOTDIR: Int32 = -4036
    /// UV_EISDIR = -4031
    public static let EISDIR: Int32 = -4031
    /// UV_ENFILE = -4033
    public static let ENFILE: Int32 = -4033
    /// UV_EMFILE = -4034
    public static let EMFILE: Int32 = -4034
    /// UV_ENOSPC = -4037
    public static let ENOSPC: Int32 = -4037
    /// UV_ESPIPE = -4039
    public static let ESPIPE: Int32 = -4039
    /// UV_EROFS = -4040
    public static let EROFS: Int32 = -4040
    /// UV_ENOTEMPTY = -4035
    public static let ENOTEMPTY: Int32 = -4035
    /// UV_EBUSY = -4026
    public static let EBUSY: Int32 = -4026
    /// UV_EAGAIN = -4025
    public static let EAGAIN: Int32 = -4025
    /// UV_EWOULDBLOCK = -4025
    public static let EWOULDBLOCK: Int32 = -4025
    /// UV_ENOMEM = -4032
    public static let ENOMEM: Int32 = -4032
    /// UV_ECONNREFUSED = -4061
    public static let ECONNREFUSED: Int32 = -4061
    /// UV_ECONNRESET = -4057
    public static let ECONNRESET: Int32 = -4057
    /// UV_ETIMEDOUT = -4059
    public static let ETIMEDOUT: Int32 = -4059
    /// UV_EPIPE = -4038
    public static let EPIPE: Int32 = -4038
    /// UV_EOF = -4095
    public static let EOF: Int32 = -4095

    /// 将 libuv 错误码映射为 POSIX errno
    /// 严格对应 Bun libuv_error_map
    public static func toErrno(uvErr: Int32): UInt16 {
        match (uvErr) {
            case -4048 => 1    // EPERM
            case -4058 => 2    // ENOENT
            case -4060 => 3    // ESRCH
            case -4027 => 4    // EINTR (also EIO)
            case -4029 => 13   // EACCES
            case -4030 => 17   // EEXIST
            case -4036 => 20   // ENOTDIR
            case -4031 => 21   // EISDIR
            case -4033 => 23   // ENFILE
            case -4034 => 24   // EMFILE
            case -4037 => 28   // ENOSPC
            case -4039 => 29   // ESPIPE
            case -4040 => 30   // EROFS
            case -4035 => 39   // ENOTEMPTY
            case -4026 => 16   // EBUSY
            case -4025 => 11   // EAGAIN
            case -4032 => 12   // ENOMEM
            case -4061 => 111  // ECONNREFUSED
            case -4057 => 104  // ECONNRESET
            case -4059 => 110  // ETIMEDOUT
            case -4038 => 32   // EPIPE
            case _ => UInt16(Int64(-uvErr) & 0xFFFF)
        }
    }
}

// ============================================================================
// libuv C FFI 函数声明
// 严格翻译自: libuv uv.h 函数签名
// ============================================================================

// --- Loop 操作 ---
// uv_loop_t 的创建和销毁
@C
foreign func uv_loop_new(): CPointer<Unit>
@C
foreign func uv_loop_init(loop: CPointer<Unit>): Int32
@C
foreign func uv_loop_close(loop: CPointer<Unit>): Int32
@C
foreign func uv_loop_delete(loop: CPointer<Unit>): Unit
@C
foreign func uv_run(loop: CPointer<Unit>, mode: Int32): Int32
@C
foreign func uv_loop_alive(loop: CPointer<Unit>): Int32
@C
foreign func uv_stop(loop: CPointer<Unit>): Unit
@C
foreign func uv_loop_size(): UIntNative
@C
foreign func uv_backend_fd(loop: CPointer<Unit>): Int32
@C
foreign func uv_backend_timeout(loop: CPointer<Unit>): Int32
@C
foreign func uv_update_time(loop: CPointer<Unit>): Unit
@C
foreign func uv_now(loop: CPointer<Unit>): UInt64
@C
foreign func uv_walk(loop: CPointer<Unit>, walk_cb: CPointer<Unit>, arg: CPointer<Unit>): Unit

// --- Handle 操作 ---
@C
foreign func uv_is_active(handle: CPointer<Unit>): Int32
@C
foreign func uv_is_closing(handle: CPointer<Unit>): Int32
@C
foreign func uv_close(handle: CPointer<Unit>, close_cb: CPointer<Unit>): Unit
@C
foreign func uv_handle_size(type_: Int32): UIntNative
@C
foreign func uv_send_buffer_size(handle: CPointer<Unit>, value: CPointer<Int32>): Int32
@C
foreign func uv_recv_buffer_size(handle: CPointer<Unit>, value: CPointer<Int32>): Int32
@C
foreign func uv_fileno(handle: CPointer<Unit>, fd: CPointer<Unit>): Int32

// --- Stream 操作 ---
// uv_stream_t 继承自 uv_handle_t
@C
foreign func uv_shutdown(req: CPointer<Unit>, stream: CPointer<Unit>, cb: CPointer<Unit>): Int32
@C
foreign func uv_listen(stream: CPointer<Unit>, backlog: Int32, connection_cb: CPointer<Unit>): Int32
@C
foreign func uv_accept(server: CPointer<Unit>, client: CPointer<Unit>): Int32
@C
foreign func uv_read_start(stream: CPointer<Unit>, alloc_cb: CPointer<Unit>, read_cb: CPointer<Unit>): Int32
@C
foreign func uv_read_stop(stream: CPointer<Unit>): Int32
@C
foreign func uv_write(req: CPointer<Unit>, stream: CPointer<Unit>, bufs: CPointer<Unit>, nbufs: UInt32, cb: CPointer<Unit>): Int32
@C
foreign func uv_write2(req: CPointer<Unit>, stream: CPointer<Unit>, bufs: CPointer<Unit>, nbufs: UInt32, send_stream: CPointer<Unit>, cb: CPointer<Unit>): Int32
@C
foreign func uv_try_write(stream: CPointer<Unit>, bufs: CPointer<Unit>, nbufs: UInt32): Int32
@C
foreign func uv_is_readable(stream: CPointer<Unit>): Int32
@C
foreign func uv_is_writable(stream: CPointer<Unit>): Int32
@C
foreign func uv_stream_set_blocking(stream: CPointer<Unit>, blocking: Int32): Int32
@C
foreign func uv_stream_size(): UIntNative

// --- TCP 操作 ---
@C
foreign func uv_tcp_init(loop: CPointer<Unit>, handle: CPointer<Unit>): Int32
@C
foreign func uv_tcp_init_ex(loop: CPointer<Unit>, handle: CPointer<Unit>, flags: UInt32): Int32
@C
foreign func uv_tcp_open(handle: CPointer<Unit>, sock: Int32): Int32
@C
foreign func uv_tcp_nodelay(handle: CPointer<Unit>, enable: Int32): Int32
@C
foreign func uv_tcp_keepalive(handle: CPointer<Unit>, enable: Int32, delay: UInt32): Int32
@C
foreign func uv_tcp_simultaneous_accepts(handle: CPointer<Unit>, enable: Int32): Int32
@C
foreign func uv_tcp_bind(handle: CPointer<Unit>, addr: CPointer<Unit>, flags: UInt32): Int32
@C
foreign func uv_tcp_getsockname(handle: CPointer<Unit>, name: CPointer<Unit>, namelen: CPointer<Int32>): Int32
@C
foreign func uv_tcp_getpeername(handle: CPointer<Unit>, name: CPointer<Unit>, namelen: CPointer<Int32>): Int32
@C
foreign func uv_tcp_connect(req: CPointer<Unit>, handle: CPointer<Unit>, addr: CPointer<Unit>, cb: CPointer<Unit>): Int32
@C
foreign func uv_tcp_close_reset(handle: CPointer<Unit>, close_cb: CPointer<Unit>): Int32

// --- Timer 操作 ---
@C
foreign func uv_timer_init(loop: CPointer<Unit>, handle: CPointer<Unit>): Int32
@C
foreign func uv_timer_start(handle: CPointer<Unit>, cb: CPointer<Unit>, timeout: UInt64, repeat_: UInt64): Int32
@C
foreign func uv_timer_stop(handle: CPointer<Unit>): Int32
@C
foreign func uv_timer_again(handle: CPointer<Unit>): Int32
@C
foreign func uv_timer_set_repeat(handle: CPointer<Unit>, repeat_: UInt64): Unit
@C
foreign func uv_timer_get_repeat(handle: CPointer<Unit>): UInt64
@C
foreign func uv_timer_get_due_in(handle: CPointer<Unit>): UInt64

// --- 文件系统操作 (同步) ---
// 严格翻译自: src/sys/sys_uv.zig 中的 uv_fs_* 调用
@C
foreign func uv_fs_open(loop: CPointer<Unit>, req: CPointer<Unit>, path: CPointer<Int8>, flags: Int32, mode: UInt32, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_close(loop: CPointer<Unit>, req: CPointer<Unit>, fd: Int32, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_read(loop: CPointer<Unit>, req: CPointer<Unit>, fd: Int32, bufs: CPointer<Unit>, nbufs: UInt32, offset: Int64, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_write(loop: CPointer<Unit>, req: CPointer<Unit>, fd: Int32, bufs: CPointer<Unit>, nbufs: UInt32, offset: Int64, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_unlink(loop: CPointer<Unit>, req: CPointer<Unit>, path: CPointer<Int8>, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_mkdir(loop: CPointer<Unit>, req: CPointer<Unit>, path: CPointer<Int8>, mode: Int32, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_rmdir(loop: CPointer<Unit>, req: CPointer<Unit>, path: CPointer<Int8>, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_stat(loop: CPointer<Unit>, req: CPointer<Unit>, path: CPointer<Int8>, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_lstat(loop: CPointer<Unit>, req: CPointer<Unit>, path: CPointer<Int8>, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_fstat(loop: CPointer<Unit>, req: CPointer<Unit>, fd: Int32, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_rename(loop: CPointer<Unit>, req: CPointer<Unit>, from: CPointer<Int8>, to: CPointer<Int8>, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_chmod(loop: CPointer<Unit>, req: CPointer<Unit>, path: CPointer<Int8>, mode: Int32, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_fchmod(loop: CPointer<Unit>, req: CPointer<Unit>, fd: Int32, mode: Int32, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_chown(loop: CPointer<Unit>, req: CPointer<Unit>, path: CPointer<Int8>, uid: UInt32, gid: UInt32, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_fchown(loop: CPointer<Unit>, req: CPointer<Unit>, fd: Int32, uid: UInt32, gid: UInt32, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_ftruncate(loop: CPointer<Unit>, req: CPointer<Unit>, fd: Int32, offset: Int64, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_fsync(loop: CPointer<Unit>, req: CPointer<Unit>, fd: Int32, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_fdatasync(loop: CPointer<Unit>, req: CPointer<Unit>, fd: Int32, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_readlink(loop: CPointer<Unit>, req: CPointer<Unit>, path: CPointer<Int8>, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_realpath(loop: CPointer<Unit>, req: CPointer<Unit>, path: CPointer<Int8>, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_statfs(loop: CPointer<Unit>, req: CPointer<Unit>, path: CPointer<Int8>, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_link(loop: CPointer<Unit>, req: CPointer<Unit>, from: CPointer<Int8>, to: CPointer<Int8>, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_symlink(loop: CPointer<Unit>, req: CPointer<Unit>, target: CPointer<Int8>, new_path: CPointer<Int8>, flags: Int32, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_copyfile(loop: CPointer<Unit>, req: CPointer<Unit>, from: CPointer<Int8>, to: CPointer<Int8>, flags: Int32, cb: CPointer<Unit>): Int32
@C
foreign func uv_fs_req_cleanup(req: CPointer<Unit>): Unit
@C
foreign func uv_fs_get_system_error(req: CPointer<Unit>): Int32

// --- DNS / 网络 ---
@C
foreign func uv_getaddrinfo(loop: CPointer<Unit>, req: CPointer<Unit>, cb: CPointer<Unit>, node: CPointer<Int8>, service: CPointer<Int8>, hints: CPointer<Unit>): Int32
@C
foreign func uv_freeaddrinfo(addrinfo: CPointer<Unit>): Unit
@C
foreign func uv_ip4_addr(ip: CPointer<Int8>, port: Int32, addr: CPointer<Unit>): Int32
@C
foreign func uv_ip6_addr(ip: CPointer<Int8>, port: Int32, addr: CPointer<Unit>): Int32
@C
foreign func uv_inet_ntop(family: Int32, src: CPointer<Unit>, dst: CPointer<Int8>, size: UIntNative): CPointer<Int8>
@C
foreign func uv_inet_pton(family: Int32, src: CPointer<Int8>, dst: CPointer<Unit>): Int32

// --- 工具函数 ---
@C
foreign func uv_strerror(err: Int32): CPointer<Int8>
@C
foreign func uv_err_name(err: Int32): CPointer<Int8>
@C
foreign func uv_version(): UInt32
@C
foreign func uv_version_string(): CPointer<Int8>
@C
foreign func uv_guess_handle(fd: Int32): Int32
@C
foreign func uv_buf_init(base: CPointer<Int8>, len: UIntNative): CPointer<Unit>

// ============================================================================
// UvLoop - libuv 事件循环封装
// 严格翻译自: src/sys/sys_uv.zig 中对 uv_loop_t 的使用
//   Bun 在 Windows 上使用 libuv 事件循环
//   sys_uv.zig: const rc = uv.uv_fs_open(uv.Loop.get(), &req, ...)
// ============================================================================

/// libuv 事件循环封装 - 对应 Bun uv.Loop
/// 管理所有 libuv 句柄和 I/O 操作
public class UvLoop {
    /// 底层 uv_loop_t 指针
    private var loop: CPointer<Unit>
    /// 是否已初始化
    private var initialized: Bool

    public init() {
        loop = CPointer<Unit>()
        initialized = false
    }

    /// 初始化事件循环
    /// 对应: uv_loop_init(&loop) 或 uv_loop_new()
    public func init(): SysMaybe<Unit> {
        unsafe {
            let ptr = uv_loop_new()
            if (ptr.isNull()) {
                return SysMaybe<Unit>.Err(SysError(12, SysTag.TODO))  // ENOMEM
            }
            let rc = uv_loop_init(ptr)
            if (rc != 0) {
                uv_loop_delete(ptr)
                return SysMaybe<Unit>.Err(
                    SysError(UvErrno.toErrno(rc), SysTag.TODO)
                )
            }
            loop = ptr
            initialized = true
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 获取底层指针
    public func ptr(): CPointer<Unit> {
        return loop
    }

    /// 运行事件循环
    /// 对应: uv_run(loop, UV_RUN_DEFAULT)
    public func run(mode: UvRunMode): Int32 {
        if (!initialized) {
            return -1
        }
        return uv_run(loop, mode.toInt())
    }

    /// 运行直到没有活跃句柄
    /// 对应 Bun: uv_run(loop, UV_RUN_DEFAULT)
    public func runDefault(): Int32 {
        return run(UvRunMode.Default)
    }

    /// 单次运行
    public func runOnce(): Int32 {
        return run(UvRunMode.Once)
    }

    /// 非阻塞运行
    public func runNoWait(): Int32 {
        return run(UvRunMode.NoWait)
    }

    /// 是否活跃
    /// 对应: uv_loop_alive(loop)
    public func isAlive(): Bool {
        if (!initialized) {
            return false
        }
        return uv_loop_alive(loop) != 0
    }

    /// 停止循环
    /// 对应: uv_stop(loop)
    public func stop(): Unit {
        if (initialized) {
            uv_stop(loop)
        }
    }

    /// 获取后端 FD (epoll/kqueue/IOCP)
    /// 对应: uv_backend_fd(loop)
    public func backendFd(): Int32 {
        if (!initialized) {
            return -1
        }
        return uv_backend_fd(loop)
    }

    /// 获取后端超时
    public func backendTimeout(): Int32 {
        if (!initialized) {
            return 0
        }
        return uv_backend_timeout(loop)
    }

    /// 更新时间
    /// 对应: uv_update_time(loop)
    public func updateTime(): Unit {
        if (initialized) {
            uv_update_time(loop)
        }
    }

    /// 获取当前时间
    /// 对应: uv_now(loop)
    public func now(): UInt64 {
        if (!initialized) {
            return 0
        }
        return uv_now(loop)
    }

    /// 销毁循环
    /// 对应: uv_loop_close(loop) + uv_loop_delete(loop)
    public func destroy(): Unit {
        if (initialized) {
            uv_loop_close(loop)
            uv_loop_delete(loop)
            loop = CPointer<Unit>()
            initialized = false
        }
    }
}

// ============================================================================
// UvFsReq - 文件系统请求封装
// 严格翻译自: src/sys/sys_uv.zig
//   Bun: var req: uv.fs_t = uv.fs_t.uninitialized; defer req.deinit();
//   RAII 模式: 请求初始化后必须在所有路径上清理
// ============================================================================

/// libuv 文件系统请求 - 对应 uv_fs_t
/// 使用 RAII 模式确保请求总是被清理
public class UvFsReq {
    /// 底层 uv_fs_t 指针
    private var req: CPointer<Unit>
    /// 是否已初始化
    private var valid: Bool

    public init() {
        // 分配 uv_fs_t 大小的内存
        unsafe {
            // uv_fs_t 大小因平台不同，取一个安全值
            let size = UIntNative(512)
            req = malloc(size)
            valid = true
        }
    }

    /// 获取底层指针
    public func ptr(): CPointer<Unit> {
        return req
    }

    /// 清理请求
    /// 对应 Bun: req.deinit() / uv_fs_req_cleanup(&req)
    /// sys_uv.zig 中每个函数都有 `defer req.deinit()`
    public func deinit(): Unit {
        if (valid) {
            uv_fs_req_cleanup(req)
            valid = false
        }
    }

    /// 析构时自动清理 - 确保安全
    protected func finalize(): Unit {
        deinit()
        unsafe {
            free(req)
        }
    }
}

// ============================================================================
// UvTcp - TCP 句柄封装
// 严格翻译自: libuv uv_tcp_t 操作
// ============================================================================

/// TCP 句柄 - 对应 uv_tcp_t
/// 用于 TCP 连接的创建、绑定、连接和传输
public class UvTcp {
    /// 底层句柄指针
    private var handle: CPointer<Unit>
    /// 关联的事件循环
    private var loop: UvLoop

    public init(loop: UvLoop) {
        this.loop = loop
        // 分配 uv_tcp_t 大小的内存
        unsafe {
            let size = uv_handle_size(14)  // UV_TCP = 14
            handle = malloc(size)
        }
    }

    /// 初始化 TCP 句柄
    /// 对应: uv_tcp_init(loop, &handle)
    public func init(): SysMaybe<Unit> {
        let rc = uv_tcp_init(loop.ptr(), handle)
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UvErrno.toErrno(rc), SysTag.Connect)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 初始化 (带扩展标志)
    /// 对应: uv_tcp_init_ex(loop, &handle, flags)
    public func initEx(flags: UInt32): SysMaybe<Unit> {
        let rc = uv_tcp_init_ex(loop.ptr(), handle, flags)
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UvErrno.toErrno(rc), SysTag.Connect)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 设置 TCP_NODELAY (禁用 Nagle 算法)
    /// 对应: uv_tcp_nodelay(&handle, 1)
    public func setNoDelay(enable: Bool): SysMaybe<Unit> {
        let rc = uv_tcp_nodelay(handle, if (enable) 1 else 0)
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UvErrno.toErrno(rc), SysTag.Connect)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 设置 keepalive
    /// 对应: uv_tcp_keepalive(&handle, 1, delay)
    public func setKeepalive(enable: Bool, delay: UInt32): SysMaybe<Unit> {
        let rc = uv_tcp_keepalive(handle, if (enable) 1 else 0, delay)
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UvErrno.toErrno(rc), SysTag.Connect)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 关闭句柄
    public func close(): Unit {
        uv_close(handle, CPointer<Unit>())
    }

    /// 获取底层指针
    public func ptr(): CPointer<Unit> {
        return handle
    }
}

// ============================================================================
// UvTimer - 定时器句柄封装
// 严格翻译自: libuv uv_timer_t 操作
// ============================================================================

/// 定时器句柄 - 对应 uv_timer_t
/// 用于创建和管理 libuv 定时器
public class UvTimer {
    /// 底层句柄指针
    private var handle: CPointer<Unit>
    /// 关联的事件循环
    private var loop: UvLoop
    /// 定时器回调
    public var onTimer: () -> Unit

    public init(loop: UvLoop) {
        this.loop = loop
        this.onTimer = { }
        // 分配 uv_timer_t 大小的内存
        unsafe {
            let size = uv_handle_size(15)  // UV_TIMER = 15
            handle = malloc(size)
        }
    }

    /// 初始化定时器
    /// 对应: uv_timer_init(loop, &handle)
    public func init(): SysMaybe<Unit> {
        let rc = uv_timer_init(loop.ptr(), handle)
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UvErrno.toErrno(rc), SysTag.TODO)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 启动定时器
    /// 对应: uv_timer_start(&handle, cb, timeout, repeat)
    /// timeout: 首次触发延迟 (毫秒)
    /// repeat: 重复间隔 (毫秒), 0 = 一次性
    public func start(timeout: UInt64, repeat: UInt64): SysMaybe<Unit> {
        let rc = uv_timer_start(handle, CPointer<Unit>(), timeout, repeat)
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UvErrno.toErrno(rc), SysTag.TODO)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 停止定时器
    /// 对应: uv_timer_stop(&handle)
    public func stop(): SysMaybe<Unit> {
        let rc = uv_timer_stop(handle)
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UvErrno.toErrno(rc), SysTag.TODO)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 重启定时器 (使用上次参数)
    /// 对应: uv_timer_again(&handle)
    public func again(): SysMaybe<Unit> {
        let rc = uv_timer_again(handle)
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UvErrno.toErrno(rc), SysTag.TODO)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 设置重复间隔
    /// 对应: uv_timer_set_repeat(&handle, repeat)
    public func setRepeat(repeat: UInt64): Unit {
        uv_timer_set_repeat(handle, repeat)
    }

    /// 获取重复间隔
    /// 对应: uv_timer_get_repeat(&handle)
    public func getRepeat(): UInt64 {
        return uv_timer_get_repeat(handle)
    }

    /// 获取距离下次触发的毫秒数
    /// 对应: uv_timer_get_due_in(&handle)
    public func getDueIn(): UInt64 {
        return uv_timer_get_due_in(handle)
    }

    /// 关闭定时器
    public func close(): Unit {
        uv_close(handle, CPointer<Unit>())
    }

    /// 获取底层指针
    public func ptr(): CPointer<Unit> {
        return handle
    }
}

// ============================================================================
// UvStream - 流句柄封装
// 严格翻译自: libuv uv_stream_t 操作
// ============================================================================

/// 流句柄 - 对应 uv_stream_t
/// TCP、命名管道、TTY 都继承自 uv_stream_t
public class UvStream {
    /// 底层句柄指针
    private var handle: CPointer<Unit>

    public init(handle: CPointer<Unit>) {
        this.handle = handle
    }

    /// 开始读取
    /// 对应: uv_read_start(stream, alloc_cb, read_cb)
    public func readStart(): SysMaybe<Unit> {
        let rc = uv_read_start(handle, CPointer<Unit>(), CPointer<Unit>())
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UvErrno.toErrno(rc), SysTag.Read)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 停止读取
    /// 对应: uv_read_stop(stream)
    public func readStop(): SysMaybe<Unit> {
        let rc = uv_read_stop(handle)
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UvErrno.toErrno(rc), SysTag.Read)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 尝试写入 (非阻塞)
    /// 对应: uv_try_write(stream, bufs, nbufs)
    public func tryWrite(data: Array<UInt8>): Int32 {
        unsafe {
            let bufPtr = malloc(UIntNative(data.size))
            for (i in 0..data.size) {
                let bytePtr = CPointer<Int8>(bufPtr) + IntNative(i)
                bytePtr.write(Int8(Int32(data[i])))
            }
            let buf = uv_buf_init(CPointer<Int8>(bufPtr), UIntNative(data.size))
            let rc = uv_try_write(handle, buf, 1)
            free(bufPtr)
            return rc
        }
    }

    /// 是否可读
    public func isReadable(): Bool {
        return uv_is_readable(handle) != 0
    }

    /// 是否可写
    public func isWritable(): Bool {
        return uv_is_writable(handle) != 0
    }

    /// 设置阻塞模式
    public func setBlocking(blocking: Bool): SysMaybe<Unit> {
        let rc = uv_stream_set_blocking(handle, if (blocking) 1 else 0)
        if (rc != 0) {
            return SysMaybe<Unit>.Err(
                SysError(UvErrno.toErrno(rc), SysTag.Write)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 关闭流
    public func close(): Unit {
        uv_close(handle, CPointer<Unit>())
    }

    /// 获取底层指针
    public func ptr(): CPointer<Unit> {
        return handle
    }
}

// ============================================================================
// UvHelpers - libuv 辅助函数
// ============================================================================

/// libuv 辅助函数
public class UvHelpers {
    /// 获取错误描述
    /// 对应: uv_strerror(err)
    public static func strerror(err: Int32): String {
        unsafe {
            let ptr = uv_strerror(err)
            return unsafeCStringToString(ptr)
        }
    }

    /// 获取错误名称
    /// 对应: uv_err_name(err)
    public static func errName(err: Int32): String {
        unsafe {
            let ptr = uv_err_name(err)
            return unsafeCStringToString(ptr)
        }
    }

    /// 获取 libuv 版本号
    /// 对应: uv_version()
    public static func version(): UInt32 {
        return uv_version()
    }

    /// 获取 libuv 版本字符串
    /// 对应: uv_version_string()
    public static func versionString(): String {
        unsafe {
            let ptr = uv_version_string()
            return unsafeCStringToString(ptr)
        }
    }

    /// 根据 FD 猜测句柄类型
    /// 对应: uv_guess_handle(fd)
    public static func guessHandle(fd: Int32): UvHandleType {
        let t = uv_guess_handle(fd)
        return UvHandleType.fromInt(t)
    }

    /// 检查返回码是否为错误
    /// 对应 Bun: if (rc.errno()) |errno| ...
    public static func isErr(rc: Int32): Bool {
        return rc < 0
    }

    /// 从 libuv 返回码提取 errno
    /// 对应 Bun sys_uv.zig 中的错误提取模式
    public static func getErrno(rc: Int32): UInt16 {
        if (rc >= 0) {
            return 0
        }
        return UvErrno.toErrno(rc)
    }
}
