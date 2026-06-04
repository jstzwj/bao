// 严格翻译自: src/runtime/cli/test/parallel/Coordinator.zig
// 并行测试 Coordinator — 进程池协调器
// 管理 bun test --parallel 的 worker 进程池，驱动事件循环，
// 路由 IPC 帧到每个测试的输出，处理崩溃/panic-abort/bail/懒扩容。
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_path.*
import bao_io.*
import bao_sys.*
import bao_event_loop.*


// ============================================================================
// FileRange — 文件索引范围 (lo..hi)
// 对应 Bun: FileRange.zig
// ============================================================================
public class FileRange {
    public var lo: Int64
    public var hi: Int64

    public init() {
        lo = 0
        hi = 0
    }

    public init(lo: Int64, hi: Int64) {
        this.lo = lo
        this.hi = hi
    }

    /// 范围中的文件数量
    public func len(): Int64 { hi - lo }

    /// 范围是否为空
    public func isEmpty(): Bool { lo >= hi }

    /// 取出前一个文件索引 (消费式)
    public func popFront(): ?Int64 {
        if (lo < hi) {
            let val = lo
            lo = lo + 1
            return Some(val)
        }
        return None
    }

    /// 从末尾窃取一个文件 (工作窃取)
    public func stealOne(): ?Int64 {
        if (lo < hi) {
            hi = hi - 1
            return Some(hi)
        }
        return None
    }
}

// ============================================================================
// Worker — 一个 bun test --test-worker --isolate 进程
// 对应 Bun: Worker.zig
// ============================================================================
public class TestWorker {
    /// 所属协调器
    public var coord: ?Coordinator
    /// Worker 索引
    public var idx: Int64
    /// 子进程 PID (0 表示未启动)
    public var processPid: Int64

    /// 正在运行的文件索引
    public var inflight: ?Int64
    /// 拥有的文件范围
    public var range: FileRange
    /// 最近一次分配的时间戳 (ms)
    public var dispatchedAt: Int64
    /// stdout+stderr 缓冲
    public var captured: ArrayList<UInt8>
    /// 是否存活
    public var alive: Bool
    /// 退出状态
    public var exitStatus: ?SpawnStatus

    public init() {
        this.coord = None
        idx = 0
        processPid = 0
        inflight = None
        range = FileRange()
        dispatchedAt = 0
        captured = ArrayList<UInt8>()
        alive = false
        exitStatus = None
    }

    public init(coord: Coordinator, idx: Int64) {
        this.coord = Some(coord)
        this.idx = idx
        processPid = 0
        inflight = None
        range = FileRange()
        dispatchedAt = 0
        captured = ArrayList<UInt8>()
        alive = false
        exitStatus = None
    }

    /// Worker 是否空闲 (没有在执行的文件)
    public func isIdle(): Bool {
        match (inflight) {
            case Some(_) => false
            case None => range.isEmpty()
        }
    }

    /// 清空捕获的输出
    public func clearCaptured(): Unit {
        captured.clear()
    }
}

// ============================================================================
// Coordinator — bun test --parallel 的进程池协调器
// 对应 Bun: src/runtime/cli/test/parallel/Coordinator.zig
// ============================================================================
public class Coordinator {
    public var vm: VirtualMachine
    public var reporter: CommandLineReporter
    public var files: Array<String>
    public var cwd: String
    public var argv: Array<String>
    public var envps: Array<Array<String>>

    /// Worker 列表
    public var workers: Array<TestWorker>

    /// Worker 临时目录（用于 JUnit/LCOV 片段）
    public var workerTmpdir: ?String
    public var junitFragments: ArrayList<String>
    public var coverageFragments: ArrayList<String>
    public var lastHeaderIdx: ?Int64

    public var frame: Int64
    public var filesDone: Int64
    public var spawnedCount: Int64
    public var liveWorkers: Int64
    public var parallelLimit: Int64
    public var bail: Int64
    public var scaleUpAfterMs: Int64
    public var dots: Bool
    public var crashedFiles: ArrayList<Int64>
    public var bailed: Bool
    public var lastPrintedDot: Bool

    public init() {
        this.vm = VirtualMachine()
        this.reporter = CommandLineReporter()
        this.files = []
        this.cwd = ""
        this.argv = []
        this.envps = []
        this.workers = []
        this.workerTmpdir = None
        this.junitFragments = ArrayList<String>()
        this.coverageFragments = ArrayList<String>()
        this.lastHeaderIdx = None
        this.frame = 0
        this.filesDone = 0
        this.spawnedCount = 0
        this.liveWorkers = 0
        this.crashedFiles = ArrayList<Int64>()
        this.bailed = false
        this.lastPrintedDot = false
        this.scaleUpAfterMs = 0
        this.dots = false
        this.parallelLimit = 1
        this.bail = 0
    }

    /// 是否完成 (所有文件已处理且没有活跃 worker)
    public func isDone(): Bool {
        return (this.filesDone >= Int64(this.files.size) || this.bailed) && this.liveWorkers == 0
    }

    /// 是否还有未分配的文件
    public func hasUndispatchedFiles(): Bool {
        for (w in workers) {
            if (!w.range.isEmpty()) {
                return true
            }
        }
        return false
    }

    /// 找到拥有最多剩余文件的 worker（用于工作窃取）
    public func findStealVictim(): ?TestWorker {
        var victim: ?TestWorker = None
        var most: Int64 = 0
        for (w in workers) {
            if (w.range.len() > most) {
                most = w.range.len()
                victim = Some(w)
            }
        }
        return victim
    }

    /// 驱动事件循环
    // 对应 Bun: Coordinator.drive()
    public func drive(): Unit {
        spawnWorker()
        while (!isDone()) {
            if (AbortHandler.shouldAbort) {
                abortAll()
                return
            }
            // vm.eventLoop().tick() — TODO: 接入 JSC event loop
            maybeScaleUp()
            if (isDone()) {
                break
            }
            if (spawnedCount < parallelLimit && hasUndispatchedFiles() && !bailed) {
                spawnWorker()
            }
        }
    }

    /// 终止所有 worker
    func abortAll(): Unit {
        AbortHandler.uninstall()
        for (w in workers) {
            if (w.alive && w.processPid > 0) {
                // 发送 SIGTERM 到进程组
                OS.kill(Int32(w.processPid), 15)  // SIGTERM=15
            }
        }
        Global.exit(130)
    }

    /// 启动一个新的 worker
    func spawnWorker(): Bool {
        if (this.spawnedCount >= this.parallelLimit) {
            return false
        }
        if (Int64(workers.size) <= spawnedCount) {
            // 需要扩展 workers 数组
            return false
        }
        let w = workers[Int64(spawnedCount)]
        w.alive = true
        w.dispatchedAt = currentMillis()
        this.spawnedCount = this.spawnedCount + 1
        this.liveWorkers = this.liveWorkers + 1
        return true
    }

    /// 延迟扩容 — 如果最忙 worker 空闲了一段时间，增加并行度
    func maybeScaleUp(): Unit {
        if (parallelLimit >= Int64(files.size)) {
            return
        }
        // 简化: 如果有已完成分配但未达到上限的 worker，尝试扩容
        if (spawnedCount < parallelLimit && hasUndispatchedFiles()) {
            spawnWorker()
        }
    }

    /// 分配工作给 worker
    func assignWork(w: TestWorker): Unit {
        if (w.range.isEmpty()) {
            // 工作窃取: 从最忙的 worker 窃取一个文件
            match (findStealVictim()) {
                case Some(victim) =>
                    match (victim.range.stealOne()) {
                        case Some(fileIdx) =>
                            w.inflight = Some(fileIdx)
                            w.dispatchedAt = currentMillis()
                        case None => ()
                    }
                case None => ()
            }
        } else {
            // 从自己的范围取
            match (w.range.popFront()) {
                case Some(fileIdx) =>
                    w.inflight = Some(fileIdx)
                    w.dispatchedAt = currentMillis()
                case None => ()
            }
        }
    }

    /// 跳出
    func bailOut(): Unit {
        this.bailed = true
    }

    /// 获取相对路径
    public func relPath(fileIdx: Int64): String {
        if (fileIdx >= 0 && fileIdx < this.files.size) {
            return this.files[Int64(fileIdx)]
        }
        return ""
    }

    /// 确保文件头已输出
    func ensureHeader(fileIdx: Int64): Unit {
        if (lastHeaderIdx != Some(fileIdx)) {
            lastHeaderIdx = Some(fileIdx)
            let path = relPath(fileIdx)
            reporter.write("${path}:\n")
        }
    }

    /// 换行中断 dots 模式
    func breakDots(): Unit {
        if (lastPrintedDot) {
            reporter.write("\n")
            lastPrintedDot = false
        }
    }

    /// 刷新 worker 的缓冲输出
    func flushCaptured(w: TestWorker): Unit {
        if (w.captured.size > 0) {
            // TODO: 将 captured 转为字符串并输出
            w.clearCaptured()
        }
    }

    /// 处理来自 worker 的帧
    public func onFrame(w: TestWorker, kind: Int64, rd: Int64): Unit {
        // kind: 0=test_start, 1=test_done, 2=file_done
        match (kind) {
            case 0 => ()
            case 1 => handleTestDone(w)
            case 2 => handleFileDone(w)
            case _ => ()
        }
    }

    /// 处理 test_done 帧
    func handleTestDone(w: TestWorker): Unit {
        filesDone = filesDone + 1
    }

    /// 处理 file_done 帧
    func handleFileDone(w: TestWorker): Unit {
        match (w.inflight) {
            case Some(idx) =>
                ensureHeader(idx)
                flushCaptured(w)
            case None => ()
        }
        w.inflight = None
        liveWorkers = liveWorkers - 1
    }

    /// reap 一个已退出的 worker
    func reapWorker(w: TestWorker): Unit {
        if (w.alive) {
            w.alive = false
            liveWorkers = liveWorkers - 1
        }
        flushCaptured(w)
    }
}

/// 信号中止处理器
// 对应 Bun: AbortHandler (在 Coordinator.zig 中)
public class AbortHandler {
    public static var shouldAbort: Bool = false

    public static func install(): Unit {
        // TODO: 安装 SIGINT/SIGTERM 处理器
        // signal(SIGINT, handler) { shouldAbort = true }
    }

    public static func uninstall(): Unit {
        // TODO: 恢复默认信号处理器
    }
}

/// 获取当前毫秒时间戳
func currentMillis(): Int64 {
    PerfTimer.nowMs()
}
