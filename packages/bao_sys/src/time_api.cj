// 时间工具 API
// 严格翻译自: Bun 中分散的时间函数
//   - std.time.milliTimestamp (millis)
//   - std.time.nanoTimestamp (nanos)
//   - Bun__readOriginTimer / originTimerStart
//   - jsc/BunCPUProfiler.zig 中的 epochMicroseconds
//
// 提供统一的时间获取接口，替代各处硬编码为 0 的占位实现
//
// FFI 依赖: clock_gettime, malloc, free 已在 package.cj 中声明
//
// 命名约定: 包级函数以 sys 前缀命名 (sysCurrentTimeMillis 等),
//           避免与 SysModule.currentTimeMillis() 等类静态方法冲突
package bao_sys

// ============================================================================
// 常量
// ============================================================================

/// CLOCK_REALTIME — 对应 Linux clockid_t = 0
public const CLOCK_REALTIME: Int32 = 0

/// CLOCK_MONOTONIC — 对应 Linux clockid_t = 1
public const CLOCK_MONOTONIC: Int32 = 1

// ============================================================================
// 公开函数 — 包级 (sys 前缀，供外部包和本包其他文件使用)
// ============================================================================

/// 获取当前时间戳（毫秒）
/// 对应 Bun: std.time.milliTimestamp / clock_gettime(CLOCK_REALTIME)
/// 返回自 Unix epoch 以来的毫秒数
public func sysCurrentTimeMillis(): Int64 {
    unsafe {
        // struct timespec: tv_sec (8 bytes) + tv_nsec (8 bytes) = 16 bytes
        let ts = malloc(UIntNative(16))
        let rc = clock_gettime(CLOCK_REALTIME, ts)
        if (rc == 0) {
            let secPtr = CPointer<Int64>(ts)
            let nsecPtr = CPointer<Int64>(ts) + Int64(1)
            let sec = secPtr.read()
            let nsec = nsecPtr.read()
            free(ts)
            return sec * Int64(1000) + nsec / Int64(1000000)
        }
        free(ts)
        return Int64(0)
    }
}

/// 获取当前时间戳（微秒）
/// 对应 Bun: bun.timespec.microseconds / epochMicroseconds
/// 返回自 Unix epoch 以来的微秒数
public func sysCurrentEpochMicroseconds(): UInt64 {
    unsafe {
        let ts = malloc(UIntNative(16))
        let rc = clock_gettime(CLOCK_REALTIME, ts)
        if (rc == 0) {
            let secPtr = CPointer<Int64>(ts)
            let nsecPtr = CPointer<Int64>(ts) + Int64(1)
            let sec = secPtr.read()
            let nsec = nsecPtr.read()
            free(ts)
            return UInt64(sec) * UInt64(1000000) + UInt64(nsec / 1000)
        }
        free(ts)
        return UInt64(0)
    }
}

/// 获取单调时钟纳秒
/// 对应 Bun: std.time.nanoTimestamp / clock_gettime(CLOCK_MONOTONIC)
/// 返回自某个未指定起点以来的纳秒数（单调递增，不受系统时间调整影响）
public func sysMonotonicNanoseconds(): UInt64 {
    unsafe {
        let ts = malloc(UIntNative(16))
        let rc = clock_gettime(CLOCK_MONOTONIC, ts)
        if (rc == 0) {
            let secPtr = CPointer<Int64>(ts)
            let nsecPtr = CPointer<Int64>(ts) + Int64(1)
            let sec = secPtr.read()
            let nsec = nsecPtr.read()
            free(ts)
            return UInt64(sec) * UInt64(1000000000) + UInt64(nsec)
        }
        free(ts)
        return UInt64(0)
    }
}

/// 获取单调时钟微秒
/// 对应 Bun: performance.now() 底层使用的单调时钟微秒
public func sysMonotonicMicroseconds(): UInt64 {
    unsafe {
        let ts = malloc(UIntNative(16))
        let rc = clock_gettime(CLOCK_MONOTONIC, ts)
        if (rc == 0) {
            let secPtr = CPointer<Int64>(ts)
            let nsecPtr = CPointer<Int64>(ts) + Int64(1)
            let sec = secPtr.read()
            let nsec = nsecPtr.read()
            free(ts)
            return UInt64(sec) * UInt64(1000000) + UInt64(nsec / 1000)
        }
        free(ts)
        return UInt64(0)
    }
}

/// 获取当前 Float64 秒数（用于性能计时）
/// 对应 Bun: std.time.nanoTimestamp 转为秒
/// 返回自 Unix epoch 以来的浮点秒数
public func sysCurrentTimeSeconds(): Float64 {
    unsafe {
        let ts = malloc(UIntNative(16))
        let rc = clock_gettime(CLOCK_REALTIME, ts)
        if (rc == 0) {
            let secPtr = CPointer<Int64>(ts)
            let nsecPtr = CPointer<Int64>(ts) + Int64(1)
            let sec = secPtr.read()
            let nsec = nsecPtr.read()
            free(ts)
            return Float64(sec) + Float64(nsec) / 1000000000.0
        }
        free(ts)
        return Float64(0)
    }
}

/// 获取单调时钟浮点秒数（用于 setTimeout 等内部计时）
/// 返回自某个未指定起点以来的浮点秒数（单调递增）
public func sysMonotonicSeconds(): Float64 {
    unsafe {
        let ts = malloc(UIntNative(16))
        let rc = clock_gettime(CLOCK_MONOTONIC, ts)
        if (rc == 0) {
            let secPtr = CPointer<Int64>(ts)
            let nsecPtr = CPointer<Int64>(ts) + Int64(1)
            let sec = secPtr.read()
            let nsec = nsecPtr.read()
            free(ts)
            return Float64(sec) + Float64(nsec) / 1000000000.0
        }
        free(ts)
        return Float64(0)
    }
}
