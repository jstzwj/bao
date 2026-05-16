// bao_core - 性能监控
// 严格翻译自: src/perf/
//   Bun 的性能监控:
//   - perf.zig: trace() 系统探针 (Instruments/Linux trace)
//   - hw_timer.zig: 无屏障硬件时间戳计数器 (rdtsc/CNTVCT_EL0)
//   - system_timer.zig: std.time.Timer 包装
//   此处提供:
//   - PerfTimer: 高分辨率定时器 (纳秒, clock_gettime CLOCK_MONOTONIC)
//   - Stopwatch: start/stop/elapsed/lap
//   - PerfCounter: increment/decrement/get/reset
//   - PerfHistogram: record, compute p50/p90/p99
//   - MemoryStats: current/peak RSS via /proc/self/status 或 C FFI
package bao_core
import std.collection.*
import std.convert.*
import std.sort.*

// ============================================================================
// C FFI 声明
// 严格翻译自: hw_timer.zig / system_timer.zig 中使用的系统调用
// ============================================================================

@C
foreign func clock_gettime(clockid: Int32, tp: CPointer<Unit>): Int32
@C
foreign func clock_getres(clockid: Int32, res: CPointer<Unit>): Int32
@C
foreign func gettimeofday(tv: CPointer<Unit>, tz: CPointer<Unit>): Int32
@C
foreign func open(path: CPointer<Int8>, flags: Int32, mode: UInt32): Int32
@C
foreign func read(fd: Int32, buf: CPointer<Unit>, count: UIntNative): UIntNative
@C
foreign func close(fd: Int32): Int32

/// CLOCK_MONOTONIC 常量
public let CLOCK_MONOTONIC: Int32 = 1
/// CLOCK_REALTIME 常量
public let CLOCK_REALTIME: Int32 = 0
/// CLOCK_MONOTONIC_RAW 常量
public let CLOCK_MONOTONIC_RAW: Int32 = 4
/// CLOCK_PROCESS_CPUTIME_ID
public let CLOCK_PROCESS_CPUTIME_ID: Int32 = 2
/// CLOCK_THREAD_CPUTIME_ID
public let CLOCK_THREAD_CPUTIME_ID: Int32 = 3

// ============================================================================
// PerfTimer - 高分辨率定时器
// 严格翻译自: hw_timer.zig nowNs() / system_timer.zig Timer
//   Bun 使用:
//   - aarch64: mrs CNTVCT_EL0 (硬件计数器)
//   - x86_64: rdtsc 或 vDSO clock_gettime
//   - 回退: clock_gettime(CLOCK_MONOTONIC)
//   仓颉: 统一使用 clock_gettime(CLOCK_MONOTONIC) 通过 C FFI
// ============================================================================

/// 高分辨率定时器
/// 对应 Bun: hw_timer.nowNs() / std.time.Timer
public class PerfTimer {
    /// 获取当前单调时间 (纳秒)
    /// 对应 Bun: hw_timer.nowNs() -> u64
    /// 使用 clock_gettime(CLOCK_MONOTONIC)
    public static func nowNs(): Int64 {
        unsafe {
            let tp = malloc(UIntNative(16))  // struct timespec: 8 + 8
            memset(tp, 0, UIntNative(16))
            let rc = clock_gettime(CLOCK_MONOTONIC, tp)
            if (rc == 0) {
                let secPtr = CPointer<Int64>(tp)
                let sec = secPtr.read()
                let nsecPtr = CPointer<Int64>(tp) + Int64(1)
                let nsec = nsecPtr.read()
                free(tp)
                return sec * 1000000000 + nsec
            }
            free(tp)
            return 0
        }
    }

    /// 获取当前单调时间 (微秒)
    public static func nowUs(): Int64 {
        return nowNs() / 1000
    }

    /// 获取当前单调时间 (毫秒)
    public static func nowMs(): Int64 {
        return nowNs() / 1000000
    }

    /// 获取实时时间 (纳秒, 对应 CLOCK_REALTIME)
    /// 对应 Bun: osMonotonicNs() 中的实时时间
    public static func realtimeNs(): Int64 {
        unsafe {
            let tp = malloc(UIntNative(16))
            memset(tp, 0, UIntNative(16))
            let rc = clock_gettime(CLOCK_REALTIME, tp)
            if (rc == 0) {
                let secPtr = CPointer<Int64>(tp)
                let sec = secPtr.read()
                let nsecPtr = CPointer<Int64>(tp) + Int64(1)
                let nsec = nsecPtr.read()
                free(tp)
                return sec * 1000000000 + nsec
            }
            free(tp)
            return 0
        }
    }

    /// 获取定时器分辨率 (纳秒)
    /// 对应 Bun: hw_timer.readFrequency() -> 分辨率
    public static func resolution(): Int64 {
        unsafe {
            let res = malloc(UIntNative(16))
            memset(res, 0, UIntNative(16))
            let rc = clock_getres(CLOCK_MONOTONIC, res)
            if (rc == 0) {
                let secPtr = CPointer<Int64>(res)
                let sec = secPtr.read()
                let nsecPtr = CPointer<Int64>(res) + Int64(1)
                let nsec = nsecPtr.read()
                free(res)
                return sec * 1000000000 + nsec
            }
            free(res)
            return 1  // 默认 1ns
        }
    }
}

// ============================================================================
// Stopwatch - 秒表
// 对应 Bun: std.time.Timer 的 start/stop/lap 接口
// ============================================================================

/// 秒表
/// 对应 Bun: system_timer.zig Timer
/// Bun: pub fn start() Error!Timer
/// Bun: pub fn read(self) u64 (ns since start)
/// Bun: pub fn lap(self) u64 (ns since last read)
/// Bun: pub fn reset(self) u64
public class Stopwatch {
    /// 起始时间 (纳秒)
    private var startNs: Int64
    /// 上一次 lap 时间 (纳秒)
    private var lastLapNs: Int64
    /// 是否正在运行
    private var running: Bool
    /// 累计时间 (纳秒, 用于暂停后继续)
    private var accumulatedNs: Int64
    /// lap 记录
    private var laps: ArrayList<Int64>

    public init() {
        startNs = 0
        lastLapNs = 0
        running = false
        accumulatedNs = 0
        laps = ArrayList<Int64>()
    }

    /// 启动秒表
    /// 对应 Bun: Timer.start()
    public func start(): Unit {
        if (!running) {
            startNs = PerfTimer.nowNs()
            lastLapNs = startNs
            running = true
        }
    }

    /// 停止秒表, 返回经过的总纳秒
    /// 对应 Bun: Timer.read() 在 stop 时的语义
    public func stop(): Int64 {
        if (running) {
            let now = PerfTimer.nowNs()
            accumulatedNs += now - startNs
            running = false
        }
        return accumulatedNs
    }

    /// 获取已经过的时间 (纳秒), 不停止秒表
    /// 对应 Bun: Timer.read()
    public func elapsed(): Int64 {
        if (running) {
            return accumulatedNs + PerfTimer.nowNs() - startNs
        }
        return accumulatedNs
    }

    /// 获取已经过的毫秒
    public func elapsedMs(): Int64 {
        return elapsed() / 1000000
    }

    /// 获取已经过的微秒
    public func elapsedUs(): Int64 {
        return elapsed() / 1000
    }

    /// 记录一个 lap, 返回距上次 lap 的时间 (纳秒)
    /// 对应 Bun: Timer.lap()
    public func lap(): Int64 {
        let now = PerfTimer.nowNs()
        let lapTime = if (running) { now - lastLapNs } else { 0 }
        lastLapNs = now
        if (running) { laps.add(lapTime) }
        return lapTime
    }

    /// 获取所有 lap 记录
    public func getLaps(): ArrayList<Int64> {
        return laps
    }

    /// 获取 lap 数量
    public func lapCount(): Int64 {
        return laps.size
    }

    /// 获取平均 lap 时间 (纳秒)
    public func averageLap(): Int64 {
        if (laps.size == 0) { return 0 }
        var total: Int64 = 0
        for (l in laps) { total += l }
        return total / laps.size
    }

    /// 重置秒表
    /// 对应 Bun: Timer.reset()
    public func reset(): Unit {
        startNs = 0
        lastLapNs = 0
        running = false
        accumulatedNs = 0
        laps = ArrayList<Int64>()
    }

    /// 是否正在运行
    public func isRunning(): Bool {
        return running
    }

    /// 格式化输出
    public func toString(): String {
        let ns = elapsed()
        if (ns < 1000) { return "${ns}ns" }
        if (ns < 1000000) { return "${ns / 1000}us" }
        if (ns < 1000000000) { return "${ns / 1000000}ms" }
        return "${Float64(ns) / 1000000000.0}s"
    }
}

// ============================================================================
// PerfCounter - 性能计数器
// ============================================================================

/// 性能计数器
/// 用于统计事件次数 (请求计数, 缓存命中/未命中等)
public class PerfCounter <: ToString {
    private var value: Int64
    private var name: String

    public init(name: String) {
        this.name = name
        this.value = 0
    }

    /// 递增
    public func increment(): Unit {
        value += 1
    }

    /// 递增指定值
    public func incrementBy(delta: Int64): Unit {
        value += delta
    }

    /// 递减
    public func decrement(): Unit {
        value -= 1
    }

    /// 递减指定值
    public func decrementBy(delta: Int64): Unit {
        value -= delta
    }

    /// 获取当前值
    public func get(): Int64 {
        return value
    }

    /// 重置为 0
    public func reset(): Unit {
        value = 0
    }

    /// 获取名称
    public func getName(): String {
        return name
    }

    public func toString(): String {
        return "${name}=${value}"
    }
}

// ============================================================================
// PerfHistogram - 性能直方图
// 用于记录值分布并计算百分位数 (p50, p90, p99)
// ============================================================================

/// 性能直方图
/// 用于延迟分布统计: p50/p90/p99
public class PerfHistogram <: ToString {
    private var name: String
    /// 所有记录的值
    private var values: ArrayList<Int64>
    /// 最小值
    private var minVal: Int64
    /// 最大值
    private var maxVal: Int64
    /// 总和
    private var sum: Int64
    /// 计数
    private var count: Int64

    public init(name: String) {
        this.name = name
        this.values = ArrayList<Int64>()
        this.minVal = Int64.Max
        this.maxVal = Int64.Min
        this.sum = 0
        this.count = 0
    }

    /// 记录一个值
    public func record(value: Int64): Unit {
        values.add(value)
        if (value < minVal) { minVal = value }
        if (value > maxVal) { maxVal = value }
        sum += value
        count += 1
    }

    /// 获取第 p 百分位值
    /// 例如 percentile(50) 返回 p50
    public func percentile(p: Int64): Int64 {
        if (count == 0) { return 0 }
        if (count == 1) { return values[0] }

        // 排序
        let arr = values.toArray()
        sort(arr)

        // 计算百分位索引
        let idx = (p * count + 50) / 100
        let safeIdx = if (idx >= count) { count - 1 } else { idx }
        return arr[safeIdx]
    }

    /// 中位数 (p50)
    public func p50(): Int64 {
        return percentile(50)
    }

    /// 90th 百分位
    public func p90(): Int64 {
        return percentile(90)
    }

    /// 99th 百分位
    public func p99(): Int64 {
        return percentile(99)
    }

    /// 99.9th 百分位
    public func p999(): Int64 {
        return percentile(999)
    }

    /// 平均值
    public func avg(): Int64 {
        if (count == 0) { return 0 }
        return sum / count
    }

    /// 最小值
    public func min(): Int64 {
        return if (count == 0) { 0 } else { minVal }
    }

    /// 最大值
    public func max(): Int64 {
        return if (count == 0) { 0 } else { maxVal }
    }

    /// 记录数
    public func getCount(): Int64 {
        return count
    }

    /// 总和
    public func getSum(): Int64 {
        return sum
    }

    /// 重置
    public func reset(): Unit {
        values = ArrayList<Int64>()
        minVal = Int64.Max
        maxVal = Int64.Min
        sum = 0
        count = 0
    }

    /// 格式化输出
    public func toString(): String {
        return "${name}: count=${count} min=${min()} avg=${avg()} p50=${p50()} p90=${p90()} p99=${p99()} max=${max()}"
    }
}

// ============================================================================
// MemoryStats - 内存统计
// 严格翻译自: crash_handler.zig printMetadata() 中的 mi_process_info 调用
//   以及 Bun 使用 mimalloc 的 mi_process_info
// ============================================================================

/// 内存统计
/// 对应 Bun: mimalloc.mi_process_info() 或 /proc/self/status
public class MemoryStats <: ToString {
    /// 当前 RSS (Resident Set Size, 字节)
    public var currentRss: Int64
    /// 峰值 RSS (字节)
    public var peakRss: Int64
    /// 当前虚拟内存提交大小 (字节)
    public var currentCommit: Int64
    /// 峰值提交大小 (字节)
    public var peakCommit: Int64
    /// 页面错误数
    public var pageFaults: Int64
    /// 已用毫秒
    public var elapsedMs: Int64
    /// 用户态毫秒
    public var userMs: Int64
    /// 内核态毫秒
    public var systemMs: Int64

    public init() {
        currentRss = 0
        peakRss = 0
        currentCommit = 0
        peakCommit = 0
        pageFaults = 0
        elapsedMs = 0
        userMs = 0
        systemMs = 0
    }

    /// 从 /proc/self/status 读取内存信息
    /// 对应 Bun: mi_process_info 或 /proc/self/status VmRSS/VmHWM
    /// Linux 专用, 从 /proc/self/status 读取 VmRSS 和 VmHWM
    public static func readFromProc(): MemoryStats {
        let stats = MemoryStats()
        unsafe {
            let pathPtr = unsafeNewCString("/proc/self/status")
            let fd = open(pathPtr, 0, UInt32(0))  // O_RDONLY = 0
            if (fd < 0) { return stats }

            let bufSize = 4096
            let buf = malloc(UIntNative(bufSize))
            let bytesRead = read(fd, buf, UIntNative(bufSize))
            close(fd)

            if (Int64(bytesRead) <= 0) { free(buf); return stats }

            // 解析 /proc/self/status 内容
            var content = StringBuilder()
            for (i in 0..Int64(bytesRead)) {
                let bytePtr = CPointer<Int8>(buf) + Int64(i)
                let b = bytePtr.read()
                if (b == Int8(0)) { break }
                content.append(Rune(Int32(b)))
            }
            free(buf)

            let lines = content.toString().split("\n")
            for (line in lines) {
                // VmRSS: current RSS in kB
                if (line.startsWith("VmRSS:")) {
                    let valStr = extractNumber(line)
                    try {
                        stats.currentRss = Int64.parse(valStr) * 1024  // kB -> bytes
                    } catch (_: Exception) {}
                }
                // VmHWM: peak RSS in kB
                if (line.startsWith("VmHWM:")) {
                    let valStr = extractNumber(line)
                    try {
                        stats.peakRss = Int64.parse(valStr) * 1024
                    } catch (_: Exception) {}
                }
                // VmSize: total virtual memory in kB
                if (line.startsWith("VmSize:")) {
                    let valStr = extractNumber(line)
                    try {
                        stats.currentCommit = Int64.parse(valStr) * 1024
                    } catch (_: Exception) {}
                }
                // VmPeak: peak virtual memory in kB
                if (line.startsWith("VmPeak:")) {
                    let valStr = extractNumber(line)
                    try {
                        stats.peakCommit = Int64.parse(valStr) * 1024
                    } catch (_: Exception) {}
                }
            }
        }
        return stats
    }

    /// 从行中提取数字字符串
    /// 例如 "VmRSS:    12345 kB" -> "12345"
    private static func extractNumber(line: String): String {
        let sb = StringBuilder()
        var foundDigit = false
        for (i in 0..line.size) {
            let c = line[i]
            if (c >= UInt8(48) && c <= UInt8(57)) { // '0' to '9'
                foundDigit = true
                sb.append(Rune(Int32(c)))
            } else if (foundDigit) {
                break
            }
        }
        return sb.toString()
    }

    /// 格式化为可读字符串
    /// 对应 Bun: printMetadata 中的内存输出
    public func format(): String {
        return "RSS: ${formatBytes(currentRss)} | Peak: ${formatBytes(peakRss)} | Commit: ${formatBytes(currentCommit)} | Faults: ${pageFaults}"
    }

    public func toString(): String {
        return format()
    }

    private static func formatBytes(bytes: Int64): String {
        if (bytes < 1024) { return "${bytes}B" }
        if (bytes < 1048576) { return "${bytes / 1024}KB" }
        if (bytes < 1073741824) { return "${bytes / 1048576}MB" }
        return "${bytes / 1073741824}GB"
    }
}

// ============================================================================
// PerfRegistry - 全局性能指标注册表
// ============================================================================

/// 性能指标注册表
/// 集中管理所有计数器、直方图和秒表
public class PerfRegistry {
    private static var counters: HashMap<String, PerfCounter> = HashMap<String, PerfCounter>()
    private static var histograms: HashMap<String, PerfHistogram> = HashMap<String, PerfHistogram>()
    private static var stopwatches: HashMap<String, Stopwatch> = HashMap<String, Stopwatch>()

    /// 获取或创建计数器
    public static func counter(name: String): PerfCounter {
        if (counters.contains(name)) {
            return counters.get(name).getOrThrow()
        }
        let c = PerfCounter(name)
        counters[name] = c
        return c
    }

    /// 获取或创建直方图
    public static func histogram(name: String): PerfHistogram {
        if (histograms.contains(name)) {
            return histograms.get(name).getOrThrow()
        }
        let h = PerfHistogram(name)
        histograms.add(name, h)
        return h
    }

    /// 获取或创建秒表
    public static func stopwatch(name: String): Stopwatch {
        if (stopwatches.contains(name)) {
            return stopwatches.get(name).getOrThrow()
        }
        let s = Stopwatch()
        stopwatches.add(name, s)
        return s
    }

    /// 获取所有计数器的快照
    public static func snapshot(): PerfSnapshot {
        let snap = PerfSnapshot()
        for (key in counters.keys()) {
            match (counters.get(key)) {
                case Some(c) => snap.counters.add("${c}")
                case None => ()
            }
        }
        for (key in histograms.keys()) {
            match (histograms.get(key)) {
                case Some(h) => snap.histograms.add("${h}")
                case None => ()
            }
        }
        return snap
    }

    /// 重置所有指标
    public static func resetAll(): Unit {
        for (key in counters.keys()) {
            match (counters.get(key)) {
                case Some(c) => c.reset()
                case None => ()
            }
        }
        for (key in histograms.keys()) {
            match (histograms.get(key)) {
                case Some(h) => h.reset()
                case None => ()
            }
        }
    }
}

/// 性能快照
public class PerfSnapshot {
    public var counters: ArrayList<String>
    public var histograms: ArrayList<String>
    public var memoryStats: ?MemoryStats

    public init() {
        counters = ArrayList<String>()
        histograms = ArrayList<String>()
        memoryStats = None
    }

    public func toString(): String {
        let sb = StringBuilder()
        sb.append("=== Performance Snapshot ===\n")
        for (c in counters) { sb.append("  ${c}\n") }
        for (h in histograms) { sb.append("  ${h}\n") }
        match (memoryStats) {
            case Some(ms) => sb.append("  ${ms}\n")
            case None => ()
        }
        sb.append("============================\n")
        return sb.toString()
    }
}

// ============================================================================
// 简便计时宏/函数
// ============================================================================

/// 测量代码块执行时间
/// 用法:
///   val elapsed = PerfMeasure.measure {
///     // 执行一些代码
///   }
///   print("耗时: ${elapsed}ns")
public class PerfMeasure {
    /// 测量函数执行时间 (纳秒)
    public static func measure(fn: () -> Unit): Int64 {
        let start = PerfTimer.nowNs()
        fn()
        let end = PerfTimer.nowNs()
        return end - start
    }

    /// 测量函数执行时间并记录到直方图
    public static func measureAndRecord(histogram: PerfHistogram, fn: () -> Unit): Int64 {
        let elapsed = measure(fn)
        histogram.record(elapsed)
        return elapsed
    }

    /// 测量函数执行时间 (毫秒)
    public static func measureMs(fn: () -> Unit): Int64 {
        return measure(fn) / 1000000
    }
}

// ============================================================================
// 内部工具
// ============================================================================

@C
foreign func memset(s: CPointer<Unit>, c: Int32, n: UIntNative): CPointer<Unit>

/// 创建 C 字符串
private func unsafeNewCString(s: String): CPointer<Int8> {
    unsafe {
        let len = s.size
        let ptr = malloc(UIntNative(len + 1))
        let bytesPtr = CPointer<Int8>(ptr)
        for (i in 0..len) {
            (bytesPtr + i).write(Int8(Int32(s[i])))
        }
        (bytesPtr + len).write(Int8(0))
        return bytesPtr
    }
}
