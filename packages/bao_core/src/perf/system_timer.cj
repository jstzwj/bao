// bao_core - 系统定时器
// 严格翻译自: src/perf/system_timer.zig
//   Bun 的系统定时器:
//   - WASM: 编译期错误 (不支持追踪)
//   - 其他: std.time.Timer (操作系统高精度定时器)
//   接口: start(), read(), lap(), reset()
//   仓颉: 通过 HwTimer 实现等价的纳秒级定时器
package bao_core.perf

// ============================================================================
// SystemTimer - 系统高精度定时器
// 严格翻译自: system_timer.zig NewTimer() / Timer
//   Bun:
//     fn NewTimer() type {
//       if (Environment.isWasm) {
//         return struct { start()!, read(), lap(), reset() };
//       }
//       return std.time.Timer;  // start(), read() -> u64 (ns), lap(), reset()
//     }
//     pub const Timer = NewTimer();
//   仓颉: 封装 HwTimer 提供兼容的 start/read/lap/reset 接口
// ============================================================================

/// 系统定时器
/// 对应 Bun: system_timer.Timer = std.time.Timer
///
/// std.time.Timer 接口:
///   start() Error!Timer  - 创建并启动定时器
///   read(self) u64       - 返回自 start 以来的纳秒数
///   lap(self) u64        - 返回自上次 read 以来的纳秒数
///   reset(self) u64      - 重置并返回自 start 以来的纳秒数
public class SystemTimer {
    /// 启动时间戳 (纳秒)
    private var startNs: Int64
    /// 上次读取时间戳 (纳秒)
    private var lastNs: Int64

    public init() {
        startNs = 0
        lastNs = 0
    }

    /// 创建并启动定时器
    /// 对应 Bun: Timer.start() Error!Timer
    /// std.time.Timer.start() 可能失败 (系统不支持), 仓颉中不会失败
    public static func start(): SystemTimer {
        let timer = SystemTimer()
        timer.startNs = HwTimer.nowNs()
        timer.lastNs = timer.startNs
        return timer
    }

    /// 返回自 start 以来的纳秒数
    /// 对应 Bun: Timer.read(self) -> u64
    public func read(): Int64 {
        return HwTimer.nowNs() - startNs
    }

    /// 返回自上次操作以来的纳秒数
    /// 对应 Bun: Timer.lap(self) -> u64
    public func lap(): Int64 {
        let now = HwTimer.nowNs()
        let elapsed = now - lastNs
        lastNs = now
        return elapsed
    }

    /// 重置定时器并返回自 start 以来的纳秒数
    /// 对应 Bun: Timer.reset(self) -> u64
    public func reset(): Int64 {
        let now = HwTimer.nowNs()
        let elapsed = now - startNs
        startNs = now
        lastNs = now
        return elapsed
    }

    /// 获取已经过的毫秒
    public func readMs(): Int64 {
        return read() / 1000000
    }

    /// 获取已经过的微秒
    public func readUs(): Int64 {
        return read() / 1000
    }
}
