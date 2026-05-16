// 严格翻译自: src/bun_core/output.rs:1188-1306
//   pub struct ElapsedFormatter { colors, duration_ns }
//   pub struct DebugTimer { timer }
//   pub fn print_elapsed(elapsed: f64) { ... }
//   pub fn print_elapsed_stdout(elapsed: f64) { ... }
//   pub fn print_start_end(start: end) { ... }
//
// 也翻译自: src/bun_core/output.zig:615-711
//   pub const ElapsedFormatter = struct { colors, duration_ns, pub fn format(...) ... }
//   pub const DebugTimer = struct { timer, pub fn start() ... pub fn format(...) ... }
//   pub fn printElapsed(elapsed: f64) { ... }
//   pub fn printElapsedStdout(elapsed: f64) { ... }
package bao_output

import bao_core.*
import bao_core.Output

import std.time.*

// ============================================================================
// BaoElapsedFormatter - 耗时格式化器
// 严格翻译自: src/bun_core/output.zig:615-643 + src/bun_core/output.rs:1192-1245
//   pub const ElapsedFormatter = struct {
//       colors: bool,
//       duration_ns: u64 = 0,
//       pub fn format(self: ElapsedFormatter, writer_: *std.Io.Writer) !void {
//           switch (self.duration_ns) {
//               0...std.time.ns_per_ms * 10 => { ... "[{d:>.2}ms]" ... }
//               std.time.ns_per_ms * 8_000...std.math.maxInt(u64) => { ... "[<r><yellow>{d:>.2}ms]" ... }
//               else => { ... "[<b>{d:>.2}ms]" ... }
//           }
//       }
//   };
// ============================================================================

/// 耗时格式化器 - 对应 Bun ElapsedFormatter
/// pub const ElapsedFormatter = struct { colors: bool, duration_ns: u64 = 0 }
public class BaoElapsedFormatter {
    /// 是否启用颜色 - 对应 Bun colors: bool
    public let colors: Bool
    /// 持续时间 (纳秒) - 对应 Bun duration_ns: u64 = 0
    public var durationNs: UInt64

    public init(colors: Bool) {
        this.colors = colors
        this.durationNs = UInt64(0)
    }

    public init(colors: Bool, durationNs: UInt64) {
        this.colors = colors
        this.durationNs = durationNs
    }

    /// 格式化 - 对应 Bun ElapsedFormatter.format()
    /// pub fn format(self: ElapsedFormatter, writer_: *std.Io.Writer) !void
    public func format(): String {
        let NS_PER_MS: UInt64 = 1_000_000
        let FAST: UInt64 = NS_PER_MS * UInt64(10)   // < 10ms
        let SLOW: UInt64 = NS_PER_MS * UInt64(8000) // > 8s
        let ms = Float64(durationNs) / Float64(NS_PER_MS)

        if (durationNs <= FAST) {
            // 快速: [<d>0.12ms<d>]
            return if (colors) {
                "\u{1b}[0m\u{1b}[2m[${ms.toString()}ms\u{1b}[0m\u{1b}[2m]\u{1b}[0m"
            } else {
                "[${ms.toString()}ms]"
            }
        } else if (durationNs >= SLOW) {
            // 慢速: [<r><yellow>1234.56ms<r><d>]
            return if (colors) {
                "\u{1b}[0m\u{1b}[2m[\u{1b}[0m\u{1b}[33m${ms.toString()}ms\u{1b}[0m\u{1b}[2m]\u{1b}[0m"
            } else {
                "[${ms.toString()}ms]"
            }
        } else {
            // 中等: [<b>123.45ms<r><d>]
            return if (colors) {
                "\u{1b}[0m\u{1b}[2m[\u{1b}[1m${ms.toString()}ms\u{1b}[0m\u{1b}[2m]\u{1b}[0m"
            } else {
                "[${ms.toString()}ms]"
            }
        }
    }
}

// ============================================================================
// BaoDebugTimer - 调试计时器
// 严格翻译自: src/bun_core/output.zig:1155-1176 + src/bun_core/output.rs:2491-2524
//   pub const DebugTimer = struct {
//       timer: bun.DebugOnly(std.time.Timer) = undefined,
//       pub inline fn start() DebugTimer { ... }
//       pub fn format(self: DebugTimer, w: *std.Io.Writer) !void { ... }
//   };
// ============================================================================

/// 调试计时器 - 对应 Bun DebugTimer
/// pub const DebugTimer = struct { timer: std.time.Timer }
public class BaoDebugTimer {
    /// 开始时间
    private var startTime: MonoTime

    public init() {
        this.startTime = MonoTime.now()
    }

    /// 开始计时 - 对应 Bun DebugTimer.start()
    /// pub inline fn start() DebugTimer {
    ///     return DebugTimer{ .timer = std.time.Timer.start() catch unreachable };
    /// }
    public static func start(): BaoDebugTimer {
        return BaoDebugTimer()
    }

    /// 格式化 - 对应 Bun DebugTimer.format()
    /// pub fn format(self: DebugTimer, w: *std.Io.Writer) !void {
    ///     var timer = self.timer;
    ///     try w.print("{d:.3}ms", .{@as(f64, @floatFromInt(timer.read())) / std.time.ns_per_ms});
    /// }
    public func format(): String {
        let elapsed = MonoTime.now() - startTime
        let ms = Float64(elapsed.toNanoseconds()) / 1_000_000.0
        return "${ms.toString()}ms"
    }

    /// 读取已用时间 (毫秒)
    public func readMs(): Float64 {
        let elapsed = MonoTime.now() - startTime
        return Float64(elapsed.toNanoseconds()) / 1_000_000.0
    }
}
