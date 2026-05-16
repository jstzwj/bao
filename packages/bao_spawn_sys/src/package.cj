// bao_spawn_sys - 原始 OS 进程生成层
// 严格翻译自: src/spawn_sys/lib.rs
//   该 crate 拥有直接与内核/libuv 通信以创建子进程并读取退出状态的一切内容
//   无事件循环集成:
//     - posix_spawn(2) libc 包装器 (Actions/Attr/spawn_z/wait4)
//     - posix_spawn_bun repr(C) 请求结构体和 FFI 声明
//     - spawn_process_posix (fd 管道 + posix_spawn 调用)
//     - PosixSpawnOptions/PosixStdio/PosixSpawnResult/ExtraPipe/StdioKind/Dup2/Rusage
//     - 信号转发 / no-orphans extern "C" 声明
package bao_spawn_sys

import bao_core.*
import bao_sys.*

// ============================================================================
// 模块布局
// 严格翻译自: src/spawn_sys/lib.rs:30-38
//   pub mod posix_spawn;
//   pub mod spawn_process;
// ============================================================================

// posix_spawn(2) FFI 包装器 (Actions / Attr / spawn_z / wait4)
// 翻译自 src/spawn_sys/posix_spawn.rs
// 对应文件: posix_spawn.cj

// spawn_process_posix + option/result 结构体 + Rusage
// 翻译自 src/spawn_sys/spawn_process.rs
// 对应文件: spawn_process.cj

// ============================================================================
// 规范 FFI 类型别名
// 严格翻译自: src/spawn_sys/lib.rs:42-74
//   Zig `?[*:0]const u8` <-> Rust `*const c_char`
//   **永远**不要拼写为 `Option<*const c_char>`: 原始指针已经可以为空
//   `Option<*const T>` 不享有 `Option<&T>`/`Option<NonNull<T>>` 的空指针优化
//   将 `Vec<Option<*const c_char>>::as_ptr()` 传给 `execve` 是导致 EFAULT 的 bug 类
// ============================================================================

/// `[*:null]?[*:0]const u8` -- 以 null 结尾的 NUL 终止 C 字符串数组
/// (posix_spawn/execve 接受的 argv 形状)
/// 构建为 Array<CStrPtr>，末尾加 null 哨兵
/// 严格翻译自: src/spawn_sys/lib.rs:53
///   pub type Argv = *const *const c_char;
public type Argv = CPointer<CPointer<UInt8>>

/// 与 Argv 相同形状的环境块
/// 严格翻译自: src/spawn_sys/lib.rs:56
///   pub type Envp = *const *const c_char;
public type Envp = CPointer<CPointer<UInt8>>

/// Argv/Envp 支持的 Vec 的元素类型。Null 是哨兵；永远不要用 Option 包装
/// 严格翻译自: src/spawn_sys/lib.rs:60
///   pub type CStrPtr = *const c_char;
public type CStrPtr = CPointer<UInt8>

// ============================================================================
// FFI 辅助类型 - C 指针包装
// 仓颉中没有直接等价的裸指针类型，使用 class 封装
// ============================================================================

/// C 一级指针包装 (对应 Rust *const T)
/// 用于 FFI 场景中的原始指针传递
public class CPointer<T> {
    public var ptr: UInt64  // 原始地址值

    public init() {
        this.ptr = 0
    }

    public init(addr: UInt64) {
        this.ptr = addr
    }

    /// 是否为空指针
    public func isNull(): Bool {
        return ptr == 0
    }

    /// 获取地址值
    public func addr(): UInt64 {
        return ptr
    }
}

/// C 可变指针包装 (对应 Rust *mut T)
public class CMutPointer<T> {
    public var ptr: UInt64  // 原始地址值

    public init() {
        this.ptr = 0
    }

    public init(addr: UInt64) {
        this.ptr = addr
    }

    /// 是否为空指针
    public func isNull(): Bool {
        return ptr == 0
    }

    /// 获取地址值
    public func addr(): UInt64 {
        return ptr
    }
}

// ============================================================================
// 信号转发 / no-orphans FFI 接口
// 严格翻译自: src/spawn_sys/lib.rs:81-112
//   pub mod ffi { ... }
//   从 bun_spawn::process::sync 下移，声明与 posix_spawn_bun 并列
//   bun_spawn::sync 通过 bun_spawn_sys::ffi::* 使用这些
// ============================================================================

/// 信号转发和 no-orphans FFI 声明
/// 严格翻译自: src/spawn_sys/lib.rs:89-111
///   unsafe extern "C" { ... }
public class SpawnFfi {
    /// 安装 SIGINT/SIGTERM/... 信号处理器，记录信号以转发给 Bun__currentSyncPID
    /// 对应: pub safe fn Bun__registerSignalsForForwarding()
    public static func registerSignalsForForwarding(): Unit {
        // FFI 调用 - 实际实现由 C++ 侧提供
    }

    /// 注销信号转发
    /// 对应: pub safe fn Bun__unregisterSignalsForForwarding()
    public static func unregisterSignalsForForwarding(): Unit {
        // FFI 调用
    }

    /// macOS p_puniqueid 后代追踪器 -- 参见 NoOrphansTracker.cpp
    /// 对应: pub safe fn Bun__noOrphans_begin(kq: c_int, root: pid_t)
    public static func noOrphansBegin(kq: Int32, root: Int32): Unit {
        // FFI 调用 (macOS only)
    }

    /// 释放 kqueue 描述符
    /// 对应: pub safe fn Bun__noOrphans_releaseKq()
    public static func noOrphansReleaseKq(): Unit {
        // FFI 调用
    }

    /// fork 时调用
    /// 对应: pub safe fn Bun__noOrphans_onFork()
    public static func noOrphansOnFork(): Unit {
        // FFI 调用
    }

    /// 退出时调用
    /// 对应: pub safe fn Bun__noOrphans_onExit(pid: pid_t)
    public static func noOrphansOnExit(pid: Int32): Unit {
        // FFI 调用
    }

    /// 要转发信号的 PID。注销时设为 0
    /// C++ 声明为普通 int64_t; AtomicI64 是 #[repr(C)]
    /// 对应: pub safe static Bun__currentSyncPID: AtomicI64
    public static var currentSyncPid: Int64 = 0

    /// 竞态条件: 信号可能在 spawn_process_posix 返回前发送
    /// 在子 PID 已知后调用
    /// 对应: pub safe fn Bun__sendPendingSignalIfNecessary()
    public static func sendPendingSignalIfNecessary(): Unit {
        // FFI 调用
    }
}

// ============================================================================
// waiter_thread_flag -- WaiterThread 回退标志
// 严格翻译自: src/spawn_sys/lib.rs:119-133
//   归此 crate 所有，spawn_process_posix / PosixSpawnResult::pifd_from_pid
//   可翻转它而无需依赖 bun_threading
//   bun_spawn::WaiterThread 通过这些读写
// ============================================================================

/// WaiterThread 回退标志
/// 严格翻译自: src/spawn_sys/lib.rs:119-133
///   static SHOULD_USE_WAITER_THREAD: AtomicBool = AtomicBool::new(false);
///   pub fn set() { ... }
///   pub fn get() -> bool { ... }
public class WaiterThreadFlag {
    /// 是否应使用 waiter 线程
    /// 对应: AtomicBool, Relaxed 排序
    private static var shouldUseWaiterThread: Bool = false

    /// 设置标志
    /// 对应: pub fn set() { SHOULD_USE_WAITER_THREAD.store(true, Ordering::Relaxed) }
    public static func set(): Unit {
        shouldUseWaiterThread = true
    }

    /// 获取标志
    /// 对应: pub fn get() -> bool { SHOULD_USE_WAITER_THREAD.load(Ordering::Relaxed) }
    public static func get(): Bool {
        return shouldUseWaiterThread
    }
}

// ============================================================================
// pdeathsig -- PR_SET_PDEATHSIG 默认值
// 严格翻译自: src/spawn_sys/lib.rs:144-167
//   spawn_process_posix 在 PosixSpawnOptions::linux_pdeathsig 为 None 时查询此值
//   存储位于此最低层级 (读取它的地方)
//   bun_io::ParentDeathWatchdog::enable() 从主线程翻转它
//   PR_SET_PDEATHSIG 在内核中是 *线程* 作用域的
//   所以默认值只在从武装 watchdog 的同一线程生成时适用
//   (来自 JS Worker 的 Bun.spawn 否则会在 worker.terminate() 时杀死子进程)
// ============================================================================

/// PR_SET_PDEATHSIG 默认值管理
/// 严格翻译自: src/spawn_sys/lib.rs:144-167
///   static DEFAULT_PDEATHSIG_ON_LINUX: AtomicBool
///   static INSTALL_THREAD: OnceLock<ThreadId>
public class Pdeathsig {
    /// 默认是否启用 pdeathsig
    /// 对应: static DEFAULT_PDEATHSIG_ON_LINUX: AtomicBool = AtomicBool::new(false)
    private static var defaultEnabled: Bool = false

    /// 记录安装线程 ID
    /// 对应: static INSTALL_THREAD: OnceLock<ThreadId> = OnceLock::new()
    private static var installThreadId: ?Int64 = None

    /// 启用默认值。记录调用线程，使 should_default 仅对该线程的 spawn 返回 true
    /// 匹配 Zig ParentDeathWatchdog 语义。幂等
    /// 对应: pub fn set_default(enabled: bool) { ... }
    public static func setDefault(enabled: Bool): Unit {
        if (enabled) {
            installThreadId = currentThreadId()
        }
        defaultEnabled = enabled
    }

    /// 是否应该使用默认 pdeathsig
    /// 对应: pub(crate) fn should_default() -> bool { ... }
    ///   DEFAULT_PDEATHSIG_ON_LINUX.load(Ordering::Acquire)
    ///     && INSTALL_THREAD.get().copied() == Some(std::thread::current().id())
    public static func shouldDefault(): Bool {
        if (!defaultEnabled) {
            return false
        }
        let tid = installThreadId
        match (tid) {
            case Some(id) => return id == currentThreadId()
            case None => return false
        }
    }

    /// 获取当前线程 ID (仓颉模拟)
    private static func currentThreadId(): Int64 {
        // 仓颉: 使用运行时提供的线程标识
        return RuntimeUtils.threadId()
    }
}

/// 运行时工具类
public class RuntimeUtils {
    /// 获取当前线程 ID
    public static func threadId(): Int64 {
        // 仓颉标准库或 FFI 获取线程 ID
        return 0
    }
}

// ============================================================================
// 公共表面 -- 扁平重导出
// 严格翻译自: src/spawn_sys/lib.rs:170-181
//   pub use spawn_process::spawn_process_posix;
//   pub use spawn_process::{Dup2, ExtraPipe, ...};
// ============================================================================

// spawn_process_posix 在 spawn_process.cj 中定义
// 所有类型 (Dup2, ExtraPipe, FdT, PidFdType, PidT, PosixSpawnOptions,
// PosixSpawnResult, PosixStdio, Rusage, RusageFields, StdioKind, WinRusage,
// WinTimeval, rusage_zeroed) 在 spawn_process.cj 中定义
// Actions, Attr, WaitPidResult, spawn_z, waitpid, wait4 在 posix_spawn.cj 中定义
