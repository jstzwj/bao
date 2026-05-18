// bao_core - 分支预测提示
// 严格翻译自: src/bun_core/hint.rs
//   pub const fn cold() {}
// Bun: Zig 的 @branchHint(.unlikely) / @branchHint(.cold) 的 Rust 移植
//   调用 #[cold] 函数会使 LLVM 将调用点的基本块视为冷路径
// 仓颉: 仓颉没有等价的分支提示机制, 提供空操作兼容接口
package bao_core

/// 分支预测提示 - 对应 Bun hint 模块
/// Bun: Branch-prediction hints — Rust port of Zig's @branchHint.
/// 仓颉: 没有等价机制, 提供空操作兼容
public class Hint {
    /// 标记周围分支为冷路径/不可能路径
    /// 对应 Bun hint::cold() / Zig @branchHint(.unlikely)
    ///
    /// Bun:
    ///   #[cold]
    ///   #[inline(never)]
    ///   pub const fn cold() {}
    ///
    /// 使用方式:
    ///   if rare_condition {
    ///       Hint.cold()
    ///       return Err(e)
    ///   }
    public static func cold(): Unit {
        // 仓颉没有等价的分支提示, 空操作
    }

    /// 标记为不可达 (调试用)
    /// 对应 Bun 的 unreachableUnchecked 相关提示
    public static func unreachable(): Unit {
        // 空操作
    }

    /// 标记为可能路径 (noop)
    public static func likely(): Unit {
        // 空操作
    }
}
