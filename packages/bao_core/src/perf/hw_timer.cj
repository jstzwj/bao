// bao_core - 无屏障硬件定时器
// 严格翻译自: src/perf/hw_timer.zig
//   Bun 的硬件定时器实现:
//   - aarch64: CNTVCT_EL0 寄存器直接读取 (~0.4ns/调用)
//   - x86_64: rdtsc 指令直接读取
//   - 回退: clock_gettime(CLOCK_MONOTONIC) 通过 vDSO (~20ns)
//   - nowNs(): 校准到与 OS 单调时钟相同的纪元
//   仓颉: 通过 C FFI 调用 clock_gettime 实现等价功能
package bao_core

// ============================================================================
// C FFI 声明
// 严格翻译自: hw_timer.zig 中使用的系统调用
// ============================================================================

@C
foreign func clock_gettime(clockid: Int32, tp: CPointer<Unit>): Int32
@C
foreign func malloc(size: UIntNative): CPointer<Unit>
@C
foreign func free(ptr: CPointer<Unit>): Unit
@C
foreign func memset(s: CPointer<Unit>, c: Int32, n: UIntNative): CPointer<Unit>

/// CLOCK_MONOTONIC 常量
/// 对应 Bun: std.os.linux.clock_gettime 使用 .MONOTONIC
private let CLOCK_MONOTONIC: Int32 = 1

// ============================================================================
// HwTimer - 无屏障硬件定时器
// 严格翻译自: hw_timer.zig
//   Bun:
//   - readCounter(): 原始计数器读取 (无屏障)
//     - aarch64: mrs CNTVCT_EL0
//     - x86_64: rdtsc
//   - nowNs(): 校准后的单调纳秒
//   - nowMs(): nowNs() / ns_per_ms
//   - osMonotonicNs(): OS 高精度单调时钟 (vDSO/QPC)
//   仓颉: 统一使用 clock_gettime(CLOCK_MONOTONIC)
// ============================================================================

/// 硬件定时器
/// 对应 Bun: hw_timer 命名空间
///
/// 无屏障硬件时间戳计数器:
///   直接读取 CPU 时间戳计数器, 无指令屏障
///   在 Apple Silicon 上约 0.4ns/调用 (vs mach_approximate_time ~1.4ns, mach_absolute_time ~8.7ns)
///   在 Windows 上取代 GetTickCount64 的 ~15.6ms 粒度
///
/// nowNs() 针对操作系统单调时钟校准一次, 与 bun.getRoughTickCount() 共享纪元
/// 对于纯粹的 A->B 差值 (纪元无关), readCounter() 是最廉价的读取方式
public class HwTimer {
    /// 是否支持硬件定时器
    /// 对应 Bun: hw_timer.is_supported = Environment.isAarch64 or Environment.isX64
    /// 仓颉: 始终通过 clock_gettime 支持
    public static let isSupported: Bool = true

    /// 校准数据
    /// 对应 Bun: Calibration struct { start_counter, start_ns, mult }
    private static var calibrationStartNs: Int64 = 0
    private static var calibrationMult: Int64 = 0
    private static var calibrated: Bool = false

    /// 初始化校准
    /// 对应 Bun: calibrate() - 单次校准, 将硬件计数器与 OS 时钟对齐
    /// 在 aarch64 上: mult = (ns_per_s << 32 + freq/2) / freq
    /// 仓颉: 使用 clock_gettime 校准
    public static func calibrate(): Unit {
        if (calibrated) { return }
        calibrated = true
        calibrationStartNs = osMonotonicNs()
        calibrationMult = 1  // 简化: 直接使用 OS 时钟
    }

    /// 原始计数器读取 (无屏障)
    /// 对应 Bun: readCounter() -> u64
    ///   - aarch64: mrs CNTVCT_EL0
    ///   - x86_64: rdtsc (hi:edx, lo:eax)
    /// 仓颉: 回退到 clock_gettime
    public static func readCounter(): Int64 {
        return osMonotonicNs()
    }

    /// 单调纳秒, 校准到与 bun.getRoughTickCount() 相同的纪元
    /// 对应 Bun: nowNs() -> u64
    ///   如果 mult != 0: (ticks * mult) >> 32 + start_ns
    ///   否则回退到 osMonotonicNs()
    /// 仓颉: 直接使用 clock_gettime(CLOCK_MONOTONIC)
    public static func nowNs(): Int64 {
        calibrate()
        return osMonotonicNs()
    }

    /// nowNs() 的毫秒版本
    /// 对应 Bun: nowMs() -> u64 = nowNs() / ns_per_ms
    /// 常数除法会优化为倒数乘法
    public static func nowMs(): Int64 {
        return nowNs() / 1000000
    }

    /// OS 高精度单调时钟 (纳秒)
    /// 对应 Bun: osMonotonicNs() -> u64
    ///   - Linux: clock_gettime(CLOCK_MONOTONIC), 走 vDSO (无系统调用)
    ///   - macOS: clock_gettime(CLOCK_MONOTONIC_RAW)
    ///   - Windows: QueryPerformanceCounter / QueryPerformanceFrequency
    /// 仓颉: 使用 C FFI clock_gettime(CLOCK_MONOTONIC)
    public static func osMonotonicNs(): Int64 {
        unsafe {
            let tp = malloc(UIntNative(16))  // struct timespec: 8 + 8
            memset(tp, 0, UIntNative(16))
            let rc = clock_gettime(CLOCK_MONOTONIC, tp)
            if (rc == 0) {
                let secPtr = CPointer<Int64>(tp)
                let sec = secPtr.read()
                let nsecPtr = CPointer<Int64>(tp) + IntNative(1)
                let nsec = nsecPtr.read()
                free(tp)
                return sec * 1000000000 + nsec
            }
            free(tp)
            return 0
        }
    }

    /// 读取计数器频率 (Hz)
    /// 对应 Bun: readFrequency() -> u64
    ///   - aarch64: mrs CNTFRQ_EL0 (架构寄存器, 始终有值)
    ///   - x86_64/macOS: sysctlbyname("machdep.tsc.frequency")
    ///   - x86_64/Linux: CPUID 0x15 (如果可用)
    /// 仓颉: 返回 0 表示无法直接获取, 回退到 OS 时钟
    public static func readFrequency(): Int64 {
        // 仓颉无法直接访问 CPUID 或 MSR
        // 返回 0 表示使用 OS 时钟回退路径
        return 0
    }
}
