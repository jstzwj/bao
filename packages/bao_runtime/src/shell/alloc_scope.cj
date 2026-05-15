// alloc_scope.cj - 分配作用域
// 对应 Bun: src/runtime/shell/AllocScope.zig
// 严格翻译Bun shell分配作用域到仓颉

package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// 分配作用域
// 在release构建中为零开销的包装器
// ============================================================================

/// 分配作用域
/// 在debug模式下跟踪内存分配/释放，帮助发现内存泄漏
/// 在release模式下为零开销
public class AllocScope {
    var scope: AllocationScope

    /// 开始新的分配作用域
    public static func beginScope(alloc: Allocator): AllocScope {
        AllocScope(scope: AllocationScope.init(alloc))
    }

    /// 结束分配作用域
    public func endScope() {
        this.scope.deinit()
    }

    /// 将分配从作用域中泄漏出去（不再跟踪）
    public func leakSlice<T>(memory: Array<T>) {
        this.scope.trackExternalFree(memory, null)
    }

    /// 断言内存在作用域内
    public func assertInScope(memory: Any) {
        this.scope.assertOwned(memory)
    }

    /// 获取分配器
    public func allocator(): Allocator {
        this.scope.allocator()
    }
}
