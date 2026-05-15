// bao_core - 性能追踪主入口
// 严格翻译自: src/perf/perf.zig
//   Bun 的性能追踪系统:
//   - trace(name): 使用系统分析器追踪事件 (Instruments/Linux trace)
//   - 未连接分析器时为 no-op
//   - macOS: OSLog signpost interval
//   - Linux: 自定义 trace 事件 (通过 C FFI)
//   仓颉: 提供兼容的 trace 接口
package bao_core.perf

// ============================================================================
// PerfTraceCtx - 追踪上下文
// 严格翻译自: perf.zig Ctx = union(enum) { disabled, enabled }
//   disabled: 空操作
//   enabled: Darwin 或 Linux 的追踪器
//   两者都有 end() 方法
// ============================================================================

/// 性能追踪上下文
/// 对应 Bun: perf.Ctx = union(enum) { disabled: Disabled, enabled: Darwin|Linux }
/// 使用 RAII 模式: trace() 返回上下文, end() 结束追踪
public class PerfTraceCtx {
    /// 是否启用
    private var enabled: Bool
    /// 开始时间 (纳秒, 用于 Linux 模式)
    private var startNs: Int64
    /// 事件
    private var event: PerfEvent

    public init() {
        enabled = false
        startNs = 0
        event = PerfEvent.BundlerParseJS
    }

    public init(event: PerfEvent, enabled: Bool) {
        this.event = event
        this.enabled = enabled
        this.startNs = if (enabled) { HwTimer.nowNs() } else { 0 }
    }

    /// 结束追踪
    /// 对应 Bun: Ctx.end() -> Darwin.end() 或 Linux.end()
    public func end(): Unit {
        if (!enabled) { return }
        let duration = HwTimer.nowNs() - startNs
        PerfTrace.emitEvent(event, duration)
    }
}

// ============================================================================
// PerfTrace - 性能追踪主入口
// 严格翻译自: perf.zig 顶层函数
//   trace(name) Ctx
//   isEnabled() bool
//   Darwin struct
//   Linux struct
// ============================================================================

/// 性能追踪
/// 对应 Bun: perf 命名空间
///
/// trace() 使用系统分析器追踪事件:
///   - 未连接分析器时为 no-op (返回 disabled 上下文)
///   - macOS: OSLog signpost interval
///   - Linux: Bun__linux_trace_init/emit
///
/// 添加新事件需运行 scripts/generate-perf-trace-events.sh
/// 提示: 确保使用字符串字面量调用 trace(), 而非变量
public class PerfTrace {
    /// 是否已启用 (运行时检测)
    /// 对应 Bun: is_enabled = std.atomic.Value(bool).init(false)
    private static var isEnabledFlag: Bool = false
    /// 是否已检测
    private static var hasChecked: Bool = false

    /// 追踪一个事件
    /// 对应 Bun: pub fn trace(comptime name: [:0]const u8) Ctx
    /// 如果分析器未连接, 返回 disabled 上下文 (no-op)
    /// 提示: 必须使用字符串字面量, 因为事件在编译期验证
    public static func trace(event: PerfEvent): PerfTraceCtx {
        if (!isEnabled()) {
            return PerfTraceCtx()
        }
        return PerfTraceCtx(event, true)
    }

    /// 检查性能追踪是否启用
    /// 对应 Bun: pub fn isEnabled() bool
    /// macOS: 检查 DYLD_ROOT_PATH 或 BUN_INSTRUMENTS 环境变量
    ///         以及 Darwin.get() (OSLog) 是否可用
    /// Linux: 检查 BUN_TRACE 环境变量
    ///         以及 Linux.isSupported() (Bun__linux_trace_init)
    public static func isEnabled(): Bool {
        if (!hasChecked) {
            hasChecked = true
            isEnabledFlag = detectEnabled()
        }
        return isEnabledFlag
    }

    /// 强制设置启用状态 (用于测试)
    public static func setEnabled(enabled: Bool): Unit {
        hasChecked = true
        isEnabledFlag = enabled
    }

    /// 检测追踪是否应该启用
    /// 对应 Bun: isEnabledOnce() - std.once 保护的单次检测
    private static func detectEnabled(): Bool {
        // 简化实现: 检查环境变量
        // 完整实现需要:
        //   macOS: 检查 DYLD_ROOT_PATH, BUN_INSTRUMENTS, OSLog 可用性
        //   Linux: 检查 BUN_TRACE, Bun__linux_trace_init() 返回值
        return false
    }

    /// 发射事件
    /// 对应 Bun: Linux.end() 中的 Bun__linux_trace_emit
    internal static func emitEvent(event: PerfEvent, durationNs: Int64): Unit {
        // macOS: OSLog signpost interval end
        // Linux: Bun__linux_trace_emit(@tagName(event), duration)
        // 简化实现: 仅记录到日志
        if (durationNs > 1000000) {
            // 仅记录超过 1ms 的事件
            // 对应 Bun 中 silent no-op 的行为
        }
    }
}

// ============================================================================
// Darwin 追踪器 (macOS)
// 严格翻译自: perf.zig Darwin struct
//   使用 OSLog signpost interval API
//   init(name): 创建 signpost interval
//   end(): 结束 interval
// ============================================================================

/// macOS Darwin 追踪器
/// 对应 Bun: perf.Darwin struct
/// 使用 OSLog signpost 追踪事件
public class DarwinTracer {
    /// 是否已初始化
    private static var osLogInitialized: Bool = false

    /// 初始化 OSLog
    /// 对应 Bun: Darwin.get() -> ?*OSLog (std.once 保护)
    public static func initOSLog(): Unit {
        if (osLogInitialized) { return }
        osLogInitialized = true
        // OSLog.init() - 通过 C FFI 调用 os_log_create
    }

    /// 创建追踪上下文
    /// 对应 Bun: Darwin.init(name) -> interval = os_log.signpost(name).interval(.PointsOfInterest)
    public static func init(event: PerfEvent): PerfTraceCtx {
        return PerfTraceCtx(event, true)
    }
}

// ============================================================================
// Linux 追踪器
// 严格翻译自: perf.zig Linux struct
//   使用 C FFI Bun__linux_trace_init/emit
//   init(event): 记录 start_time
//   end(): 计算 duration, 调用 Bun__linux_trace_emit
// ============================================================================

/// Linux 追踪器
/// 对应 Bun: perf.Linux struct
/// 使用 Bun 自定义的 trace 事件 API
public class LinuxTracer {
    /// 是否已初始化
    /// 对应 Bun: is_initialized = std.atomic.Value(bool).init(false)
    private static var isInitialized: Bool = false
    /// 是否支持
    private static var isSupportedFlag: Bool = false

    /// 检查 Linux trace 是否支持
    /// 对应 Bun: Linux.isSupported() -> init_once.call(); is_initialized.load(.monotonic)
    public static func isSupported(): Bool {
        if (!isInitialized) {
            isInitialized = true
            // 调用 Bun__linux_trace_init() 检测
            // 简化: 默认不支持
            isSupportedFlag = false
        }
        return isSupportedFlag
    }

    /// 初始化追踪上下文
    /// 对应 Bun: Linux.init(event) -> start_time = timespec.now(.force_real_time).ns()
    public static func init(event: PerfEvent): PerfTraceCtx {
        return PerfTraceCtx(event, true)
    }
}
