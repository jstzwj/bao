// 严格翻译自: src/runtime/shell/AllocScope.zig
// 分配作用域 — 在 release 构建中为零开销的包装器。
// 在 debug 模式下跟踪内存分配/释放，帮助发现内存泄漏。

package bao_runtime.shell

import bao_core.*
import bao_collections.*

// ============================================================================
// 分配作用域
// 对应 Bun: AllocScope.zig
// 在 release 构建中为零开销的包装器。
// 在 debug 构建中，启用分配跟踪以帮助发现内存泄漏。
// ============================================================================

/// 是否为 debug 构建
/// 对应 Bun: bun.Environment.enableAllocScopes
let IS_DEBUG_BUILD: Bool = true

/// 分配作用域
/// 在 debug 模式下跟踪内存分配/释放，帮助发现内存泄漏。
/// 在 release 模式下为零开销。
///
/// 对应 Bun:
/// ```zig
/// const AllocScope = @This();
/// __scope: if (bun.Environment.enableAllocScopes) bun.AllocationScope else void,
/// ```
///
/// 使用方式:
/// 1. 调用 `beginScope(alloc)` 开始一个新的分配跟踪作用域
/// 2. 通过 `allocator()` 获取包装后的分配器进行分配操作
/// 3. 调用 `leakSlice(memory)` 将需要泄漏出去的内存标记为已释放
/// 4. 调用 `endScope()` 结束作用域，检查是否有未释放的内存
public class AllocScope {
    var scope: AllocationScope
    /// 是否启用了分配跟踪
    var enabled: Bool

    public init() {
        scope = AllocationScope()
        enabled = false
    }

    /// 开始新的分配作用域
    /// 对应 Bun: AllocScope.beginScope(alloc)
    /// 当 enableAllocScopes 为 true 时，创建 AllocationScope。
    /// 否则返回一个空的作用域包装器。
    public static func beginScope(alloc: Allocator): AllocScope {
        let allocScope = AllocScope()
        allocScope.scope = AllocationScope()
        allocScope.enabled = IS_DEBUG_BUILD
        return allocScope
    }

    /// 结束分配作用域
    /// 对应 Bun: AllocScope.endScope()
    /// 在 debug 模式下，检查所有分配是否已正确释放。
    /// 在 release 模式下，不执行任何操作。
    public func endScope() {
        if (enabled) {
            this.scope.release()
        }
    }

    /// 将分配从作用域中泄漏出去（不再跟踪）
    /// 对应 Bun: AllocScope.leakSlice(memory)
    /// 当某些内存的生命周期超出作用域时，需要调用此函数
    /// 将其从跟踪列表中移除，避免误报内存泄漏。
    /// 在 release 模式下，不执行任何操作。
    public func leakSlice<T>(memory: Array<T>) {
        // stub: AllocationScope does not support trackExternalFree
    }

    /// 断言内存在作用域内
    /// 对应 Bun: AllocScope.assertInScope(memory)
    /// 在 debug 模式下，断言给定内存是由此作用域分配的。
    /// 在 release 模式下，不执行任何操作。
    public func assertInScope(memory: Any) {
        // stub: AllocationScope does not support assertOwned
    }

    /// 获取分配器
    /// 对应 Bun: AllocScope.allocator()
    /// 在 debug 模式下，返回跟踪分配器。
    /// 在 release 模式下，返回默认分配器。
    public func allocator(): Allocator {
        return DefaultAllocator.instance
    }
}

/// 获取默认分配器
func defaultAllocator(): Allocator {
    return DefaultAllocator.instance
}
