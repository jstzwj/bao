// 严格翻译自: src/bun_core/output.zig:1345-1367 + src/bun_core/output.rs:2962-2990
//   pub const synchronized_start = "\x1b[?2026h";
//   pub const synchronized_end = "\x1b[?2026l";
//   pub fn synchronized() Synchronized { return Synchronized.begin(); }
//   pub const Synchronized = struct {
//       pub fn begin() Synchronized { print(synchronized_start, .{}); return .{}; }
//       pub fn end() void { print(synchronized_end, .{}); }
//   };
package bao_output

import bao_core.Output

// ============================================================================
// BaoSynchronized - 同步输出范围
// 严格翻译自: src/bun_core/output.zig:1354-1367 + src/bun_core/output.rs:2973-2990
//   pub const Synchronized = struct {
//       pub fn begin() Synchronized {
//           if (Environment.isPosix) print(synchronized_start, .{});
//           return .{};
//       }
//       pub fn end(_: @This()) void {
//           if (Environment.isPosix) print(synchronized_end, .{});
//       }
//   };
// ============================================================================

/// 同步输出范围 - 对应 Bun Synchronized
/// pub const Synchronized = struct { pub fn begin() ... pub fn end() ... }
///
/// 用于将多个输出操作原子化, 避免输出与其他进程交错的序列:
///   let sync = BaoSynchronized.begin()
///   ... 多个 Output.print 调用 ...
///   sync.end()
public class BaoSynchronized {
    /// 同步开始序列 - 对应 Bun synchronized_start
    /// pub const synchronized_start = "\x1b[?2026h";
    public static let SYNCHRONIZED_START: String = "\u{1b}[?2026h"

    /// 同步结束序列 - 对应 Bun synchronized_end
    /// pub const synchronized_end = "\x1b[?2026l";
    public static let SYNCHRONIZED_END: String = "\u{1b}[?2026l"

    /// 开始同步输出 - 对应 Bun Synchronized.begin()
    /// pub fn begin() Synchronized {
    ///     if (Environment.isPosix) print(synchronized_start, .{});
    ///     return .{};
    /// }
    public static func begin(): BaoSynchronized {
        Output.print(SYNCHRONIZED_START)
        return BaoSynchronized()
    }

    /// 结束同步输出 - 对应 Bun Synchronized.end()
    /// pub fn end(_: @This()) void {
    ///     if (Environment.isPosix) print(synchronized_end, .{});
    /// }
    public func end(): Unit {
        Output.print(SYNCHRONIZED_END)
    }
}
