// bao_safety - 安全上下文配置
// 严格翻译自: bun/src/safety/lib.rs + safety.zig
//
//   Rust (lib.rs):
//     pub(crate) const ENABLED: bool = cfg!(feature = "ci_assert")
//     (compile-time gate for CriticalSection, ThreadLock, CheckedAllocator)
//
//   Zig (safety.zig):
//     pub const alloc = @import("./alloc.zig");
//     pub const CheckedAllocator = alloc.CheckedAllocator;
//     pub const CriticalSection = @import("./CriticalSection.zig");
//     pub const ThreadLock = @import("./ThreadLock.zig");
//     pub const asan = @import("./asan.zig");
//
//   Zig enabled 常量:
//     CriticalSection.enabled = bun.Environment.ci_assert
//     ThreadLock.enabled = bun.Environment.ci_assert
//     alloc.enabled = bun.Environment.ci_assert
//     alloc.traces_enabled = bun.Environment.isDebug
//     asan.enabled = bun.Environment.enable_asan
package bao_safety

import bao_threading.*
import bao_crash_handler.*

// ============================================================================
// SafetyContext - 安全上下文配置
// 聚合所有安全模块的启停控制
// 对应 Bun safety 模块的配置，将 Zig 的 comptime enabled / Rust 的 cfg(feature)
// 替换为运行时控制
// ============================================================================

/// 安全上下文 - 对应 Bun safety 模块的配置
/// 控制各种安全检查的启停
/// Zig 原始逻辑:
///   pub const enabled = bun.Environment.ci_assert  (CriticalSection, ThreadLock, alloc)
///   pub const traces_enabled = bun.Environment.isDebug  (stack trace on mismatch)
///   pub const enabled = bun.Environment.enable_asan  (ASan)
/// Rust 原始逻辑:
///   pub(crate) const ENABLED: bool = cfg!(feature = "ci_assert")
///   const TRACES_ENABLED: bool = cfg!(debug_assertions)
///   pub const ENABLED: bool = cfg!(bun_asan)
public class SafetyContext {
    /// 是否启用 CI 断言模式
    /// 对应: bun.Environment.ci_assert / cfg!(feature = "ci_assert")
    /// 控制 CriticalSection, ThreadLock, CheckedAllocator 的启停
    public var ciAssert: Bool

    /// 是否启用调试模式
    /// 对应: bun.Environment.isDebug / cfg!(debug_assertions)
    /// 控制 traces_enabled (栈追踪)
    public var isDebug: Bool

    /// 是否启用 ASAN
    /// 对应: bun.Environment.enable_asan / cfg!(bun_asan)
    /// 控制 ASan 内存检测
    public var enableASan: Bool

    public init() {
        ciAssert = false
        isDebug = false
        enableASan = false
    }

    public init(ciAssert: Bool, isDebug: Bool, enableASan: Bool) {
        this.ciAssert = ciAssert
        this.isDebug = isDebug
        this.enableASan = enableASan
    }

    /// 创建临界区 (根据配置启用/禁用)
    /// 对应: CriticalSection::ENABLED = cfg!(feature = "ci_assert")
    ///   Zig: pub const enabled = bun.Environment.ci_assert
    public func createCriticalSection(): CriticalSection {
        CriticalSection(ciAssert, isDebug)
    }

    /// 创建线程锁 (根据配置启用/禁用)
    /// 对应: ThreadLock::ENABLED = cfg!(feature = "ci_assert")
    ///   Zig: pub const enabled = bun.Environment.ci_assert
    public func createThreadLock(): ThreadLock {
        ThreadLock(ciAssert, isDebug)
    }

    /// 创建线程锁守卫
    /// 对应: ThreadLockGuard::new(lock)
    public func createThreadLockGuard(lock: ThreadLock): ThreadLockGuard {
        ThreadLockGuard(lock)
    }

    /// 创建已检查的分配器 (根据配置启用/禁用)
    /// 对应: alloc::ENABLED = cfg!(feature = "ci_assert")
    ///   Zig: pub const enabled = bun.Environment.ci_assert
    public func createCheckedAllocator(): CheckedAllocator {
        CheckedAllocator(ciAssert, isDebug)
    }

    /// 是否启用追踪
    /// 对应: traces_enabled = bun.Environment.isDebug
    ///   Rust: const TRACES_ENABLED: bool = cfg!(debug_assertions)
    public func tracesEnabled(): Bool {
        isDebug
    }

    /// 是否启用安全检查
    /// 对应: pub(crate) const ENABLED: bool = cfg!(feature = "ci_assert")
    public func enabled(): Bool {
        ciAssert
    }

    /// 设置 ASan 启用状态
    /// 对应: asan::ENABLED = cfg!(bun_asan)
    public func setASanEnabled(enabled: Bool): Unit {
        this.enableASan = enabled
        ASan.enabled = enabled
    }
}
