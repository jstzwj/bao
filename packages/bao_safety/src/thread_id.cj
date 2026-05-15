// bao_safety - Thread ID utilities
// 严格翻译自: bun/src/safety/thread_id.zig
//   pub const invalid = std.math.maxInt(std.Thread.Id);
package bao_safety

import bao_core.*

// ============================================================================
// ThreadId - 线程 ID 工具
// 严格翻译自: bun/src/safety/thread_id.zig
//   pub const invalid = std.math.maxInt(std.Thread.Id);
// ============================================================================

/// 无效线程 ID 常量 - 对应 Bun thread_id.invalid
/// 使用 Int64 最大值表示无效线程 ID
public let INVALID_THREAD_ID: Int64 = Int64.MAX_VALUE

/// 线程 ID 工具 - 对应 Bun thread_id 模块
public class ThreadId {
    /// 获取当前线程 ID
    /// 对应: std.Thread.getCurrentId()
    public static func current(): Int64 {
        Thread.currentThread().id
    }

    /// 检查是否为无效线程 ID
    public static func isValid(id: Int64): Bool {
        id != INVALID_THREAD_ID
    }
}
