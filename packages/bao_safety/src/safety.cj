// bao_safety - 安全上下文配置
// 严格翻译自: bun/src/safety/safety.zig
//   pub const alloc = @import("./alloc.zig");
//   pub const CheckedAllocator = alloc.CheckedAllocator;
//   pub const CriticalSection = @import("./CriticalSection.zig");
//   pub const ThreadLock = @import("./ThreadLock.zig");
//   pub const asan = @import("./asan.zig");
//   聚合所有安全模块的启停控制
package bao_safety

import bao_core.*

// ============================================================================
// SafetyContext - 安全上下文配置
// 聚合所有安全模块的启停控制
// 对应 Bun safety 模块的配置，将 Zig 的 comptime enabled 替换为运行时控制
// ============================================================================

/// 安全上下文 - 对应 Bun safety 模块的配置
/// 控制各种安全检查的启停
/// Zig 原始逻辑:
///   pub const enabled = bun.Environment.ci_assert  (CriticalSection, ThreadLock, alloc)
///   pub const traces_enabled = bun.Environment.isDebug  (stack trace on mismatch)
///   pub const enabled = bun.Environment.enable_asan  (ASan)
public class SafetyContext {
    /// 是否启用 CI 断言模式
    /// 对应: bun.Environment.ci_assert
    /// 控制 CriticalSection, ThreadLock, CheckedAllocator 的启停
    public var ciAssert: Bool

    /// 是否启用调试模式
    /// 对应: bun.Environment.isDebug
    /// 控制 traces_enabled (栈追踪)
    public var isDebug: Bool

    /// 是否启用 ASAN
    /// 对应: bun.Environment.enable_asan
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
    /// 对应: CriticalSection.enabled = bun.Environment.ci_assert
    public func createCriticalSection(): CriticalSection {
        CriticalSection(ciAssert)
    }

    /// 创建线程锁 (根据配置启用/禁用)
    /// 对应: ThreadLock.enabled = bun.Environment.ci_assert
    public func createThreadLock(): ThreadLock {
        ThreadLock(ciAssert)
    }

    /// 创建已检查的分配器 (根据配置启用/禁用)
    /// 对应: alloc.enabled = bun.Environment.ci_assert
    public func createCheckedAllocator(): CheckedAllocator {
        CheckedAllocator(ciAssert)
    }

    /// 是否启用追踪
    /// 对应: traces_enabled = bun.Environment.isDebug
    public func tracesEnabled(): Bool {
        isDebug
    }
}
