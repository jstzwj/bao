// system_timer - 系统计时器抽象
// 严格翻译自: bun/src/perf/system_timer.zig (28行)
//   在非 WASM 平台使用 std.time.Timer
//   在 WASM 平台编译时错误 (FeatureFlags.tracing 应被禁用)
//
//   Zig: fn NewTimer() type { ... return std.time.Timer; }
//        pub const Timer = NewTimer();
//   仓颉: 提供等价的 Timer class
package bao_perf

import bao_core.*

// ============================================================================
// SystemTimer - 系统计时器
// 严格翻译自: system_timer.zig
//   fn NewTimer() type {
//       if (Environment.isWasm) {
//           return struct {
//               pub fn start() anyerror!@This() { return @This(){}; }
//               pub fn read() u64 { @compileError("..."); }
//               pub fn lap() u64 { @compileError("..."); }
//               pub fn reset() u64 { @compileError("..."); }
//           };
//       }
//       return std.time.Timer;
//   }
//   pub const Timer = NewTimer();
//
//   Zig 的 std.time.Timer 提供:
//     - start(): 初始化计时器
//     - read(): 读取经过的纳秒数
//     - lap(): 读取并重置经过的纳秒数
//     - reset(): 重置计时器
// ============================================================================

/// 系统计时器 - 对应 Bun system_timer.Timer (即 std.time.Timer)
/// 在非 WASM 平台使用 OS 高精度单调时钟
/// 对应 Zig std.time.Timer 语义
public class SystemTimer {
    /// 计时器起始时间戳 (纳秒)
    private var startTimestamp: UInt64

    /// 上次读取的时间戳 (用于 lap)
    private var lastTimestamp: UInt64

    public init() {
        let now = HwTimer.osMonotonicNs()
        this.startTimestamp = now
        this.lastTimestamp = now
    }

    // ========================================================================
    // start - 初始化计时器
    // 严格翻译自: std.time.Timer.start()
    //   pub fn start() Timer.Error!Timer {
    //       var self = Timer{};
    //       const resolution = try Timer.resolution;
    //       self.previous = resolution;
    //       return self;
    //   }
    // ========================================================================

    /// 启动计时器
    /// 对应 Zig std.time.Timer.start()
    public static func start(): SystemTimer {
        return SystemTimer()
    }

    // ========================================================================
    // read - 读取经过的时间
    // 严格翻译自: std.time.Timer.read()
    //   pub fn read(self: Timer) u64 { ... }
    //   返回从 start/lap 到现在的纳秒数
    // ========================================================================

    /// 读取从 start/lap 到现在的纳秒数
    /// 对应 Zig std.time.Timer.read()
    public func read(): UInt64 {
        let now = HwTimer.osMonotonicNs()
        return now - startTimestamp
    }

    // ========================================================================
    // lap - 读取并重置经过的时间
    // 严格翻译自: std.time.Timer.lap()
    //   pub fn lap(self: *Timer) u64 { ... }
    //   返回从上次 lap/start 到现在的纳秒数，并重置
    // ========================================================================

    /// 读取从上次 lap/start 到现在的纳秒数，并重置基准
    /// 对应 Zig std.time.Timer.lap()
    public func lap(): UInt64 {
        let now = HwTimer.osMonotonicNs()
        let elapsed = now - lastTimestamp
        lastTimestamp = now
        return elapsed
    }

    // ========================================================================
    // reset - 重置计时器
    // 严格翻译自: std.time.Timer.reset()
    //   pub fn reset(self: *Timer) void { ... }
    // ========================================================================

    /// 重置计时器基准
    /// 对应 Zig std.time.Timer.reset()
    public func reset(): Unit {
        let now = HwTimer.osMonotonicNs()
        startTimestamp = now
        lastTimestamp = now
    }

    // ========================================================================
    // 辅助方法 - 毫秒/秒级读取
    // ========================================================================

    /// 读取经过的毫秒数
    public func readMs(): Float64 {
        return Float64(read()) / 1_000_000.0
    }

    /// 读取经过的秒数
    public func readSec(): Float64 {
        return Float64(read()) / 1_000_000_000.0
    }
}
