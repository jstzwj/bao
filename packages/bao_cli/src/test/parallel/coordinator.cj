// 严格翻译自: src/cli/test/parallel/Coordinator.zig
package bao_cli.test.parallel

import bao_core.*
import bao_runtime.*
import bao_cli.*
import bao_cli.test.*
import bao_collections.*

public enum ProcessStatus {
    | exited(Int64)
    | signaled(String)
    | err(String)
    | running

    public func signalCode(): ?String {
        match (this) {
            case signaled(sig) => Some(sig)
            case _ => None
        }
    }
}

// ============================================================================
// Coordinator — 进程池协调器
// 严格翻译自: src/cli/test/parallel/Coordinator.zig
//
// 拥有 worker 切片, 驱动事件循环, 将 IPC 帧路由到每个测试输出,
// 处理崩溃计数 / panic-abort / bail / 延迟扩容
// ============================================================================

/// 进程池协调器
/// 对应 Bun: Coordinator
public class Coordinator {
    /// VM 引用
    public var vm: VirtualMachine

    /// 报告器引用
    public var reporter: CommandLineReporter

    /// 文件列表 (已排序)
    public var files: Array<String>

    /// 工作目录
    public var cwd: String

    /// 每个 worker 的 argv
    public var argv: Array<String>

    /// 每个 worker 的 envp
    public var envps: Array<Array<String>>

    /// Worker 数组
    public var workers: Array<Worker>

    /// Worker 临时目录
    public var workerTmpdir: ?String

    /// JUnit 片段路径列表
    public var junitFragments: ArrayList<String>

    /// 覆盖率片段路径列表
    public var coverageFragments: ArrayList<String>

    /// 最近写入 path: 头部的文件索引
    public var lastHeaderIdx: ?Int64

    /// 帧缓冲区
    public var frame: Frame

    /// 并行限制
    public var parallelLimit: Int64

    /// 扩容等待时间 (毫秒)
    public var scaleUpAfterMs: Int64

    /// bail 限制
    public var bail: Int64

    /// 是否使用点模式
    public var dots: Bool

    /// 已完成文件数
    public var filesDone: Int64

    /// 已生成 worker 数
    public var spawnedCount: Int64

    /// 存活 worker 数
    public var liveWorkers: Int64

    /// 崩溃文件列表
    public var crashedFiles: ArrayList<Int64>

    /// 是否已 bail
    public var bailed: Bool

    /// 最近是否打印了点
    public var lastPrintedDot: Bool

    public init() {
        vm = VirtualMachine()
        reporter = CommandLineReporter()
        files = Array<String>()
        cwd = ""
        argv = Array<String>()
        envps = Array<Array<String>>()
        workers = Array<Worker>()
        workerTmpdir = None
        junitFragments = ArrayList<String>()
        coverageFragments = ArrayList<String>()
        lastHeaderIdx = None
        frame = Frame()
        parallelLimit = 0
        scaleUpAfterMs = DEFAULT_SCALE_UP_AFTER_MS
        bail = 0
        dots = false
        filesDone = 0
        spawnedCount = 0
        liveWorkers = 0
        crashedFiles = ArrayList<Int64>()
        bailed = false
        lastPrintedDot = false
    }

    /// 是否所有工作完成
    public func isDone(): Bool {
        return (filesDone >= files.size || bailed) && liveWorkers == 0
    }

    /// 是否有未分发的文件
    public func hasUndispatchedFiles(): Bool {
        for (w in workers) {
            if (!w.range.isEmpty()) {
                return true
            }
        }
        return false
    }

    /// 查找拥有最多文件数的 worker (偷取目标)
    public func findStealVictim(): ?Worker {
        var victim: ?Worker = None
        var most: Int64 = 0
        for (w in workers) {
            if (w.range.len() > most) {
                most = w.range.len()
                victim = w
            }
        }
        return victim
    }

    /// 驱动主循环
    /// 对应 Bun: Coordinator.drive()
    ///
    /// 核心事件循环:
    ///   1. 启动第一个 worker
    ///   2. 循环直到所有文件完成或 bail
    ///   3. 每轮 tick 处理 IPC 事件
    ///   4. 延迟扩容检查
    ///   5. 处理信号中断
    public func drive(): Unit {
        // 启动第一个 worker
        spawnWorker()

        while (!isDone()) {
            // 检查中止信号
            if (AbortHandler.shouldAbort) {
                abortAll()
                return
            }

            // 处理事件循环 tick
            // 对应 Bun: vm.eventLoop().tick() + autoTick()
            vm.getEventLoop().tickOnce()

            // 检查延迟扩容
            maybeScaleUp()

            if (isDone()) {
                break
            }

            // 如果有未分发的文件且未达到并行限制, 等待事件
            // 对应 Bun: tickWithTimeout(scaleUpAfterMs)
            if (spawnedCount < parallelLimit && hasUndispatchedFiles() && !bailed) {
                vm.getEventLoop().tickOnce()
            }
        }
    }

    /// 中止所有 worker
    /// 对应 Bun: Coordinator.abortAll()
    public func abortAll(): Unit {
        AbortHandler.uninstall()
        for (i in 0..spawnedCount) {
            let w = workers[i]
            match (w.process) {
                case Some(process) => process.kill(15)
                case None => ()
            }
        }
        Global.exit(130)
    }

    /// 生成 worker
    /// 对应 Bun: Coordinator.spawnWorker()
    ///
    /// 1. 从 workers 数组中获取下一个 slot
    /// 2. 重置 IPC 通道和管道
    /// 3. 启动子进程 (bao test --test-worker --isolate)
    /// 4. 采用 IPC 管道 (fd 3)
    /// 5. 设置退出处理器
    public func spawnWorker(): Bool {
        if (spawnedCount >= parallelLimit) {
            return false
        }
        let w = workers[spawnedCount]

        // 重置 IPC 通道
        w.ipc = Channel()
        w.captured = ArrayList<Byte>()
        w.alive = false
        w.inflight = None

        // 启动 worker 子进程
        // 对应 Bun: Worker.start() 中的 spawnProcess
        let envp = if (Int64(envps.size) > spawnedCount) { envps[Int64(spawnedCount)] } else { Array<String>() }
        let started = w.startWithArgs(argv, envp, cwd)
        if (!started) {
            // 启动失败, 如果没有存活 worker 则退出
            if (liveWorkers == 0) {
                Output.prettyError("error: failed to spawn test worker\n")
                Global.exit(1)
            }
            return false
        }

        spawnedCount += 1
        return true
    }

    /// 延迟扩容
    /// 对应 Bun: Coordinator.maybeScaleUp()
    ///
    /// 当所有活跃 worker 都忙碌超过 scaleUpAfterMs 时,
    /// 生成新的 worker 直到达到 parallelLimit
    public func maybeScaleUp(): Unit {
        if (spawnedCount >= parallelLimit) {
            return
        }
        if (bailed || !hasUndispatchedFiles()) {
            return
        }

        let now = Sys.currentTimeMillis()
        for (i in 0..spawnedCount) {
            let w = workers[i]
            if (!w.alive) {
                continue
            }
            match (w.inflight) {
                case None => return
                case Some(_) =>
                    // 检查是否忙碌超过阈值
                    if (now - w.dispatchedAt < scaleUpAfterMs) {
                        return
                    }
            }
        }

        // 所有活跃 worker 都忙碌超过阈值, 扩容
        let remaining = Int64(files.size) - filesDone
        let want = if (parallelLimit < remaining) { parallelLimit } else { remaining }
        while (spawnedCount < want) {
            if (!spawnWorker()) {
                break
            }
        }
    }

    /// 分配工作给 worker
    /// 对应 Bun: Coordinator.assignWork()
    ///
    /// 1. 从 worker 自己的范围取文件 (保持目录局部性)
    /// 2. 如果为空, 从最忙的 worker 偷取后半部分
    /// 3. 如果没有可偷取的, 关闭 worker
    public func assignWork(w: Worker): Unit {
        if (bailed) {
            w.shutdown()
            return
        }

        // 从自己的范围取
        match (w.range.popFront()) {
            case Some(idx) =>
                w.dispatch(idx, files[idx])
                return
            case None => ()
        }

        // 偷取后半部分 (远离所有者热区, 保持局部性)
        match (findStealVictim()) {
            case Some(v) =>
                match (v.range.stealBackHalf()) {
                    case Some(stolen) =>
                        w.range = stolen
                        match (w.range.popFront()) {
                            case Some(pr2) =>
                                w.dispatch(pr2, files[pr2])
                                return
                            case None => ()
                        }
                    case None => ()
                }
            case None => ()
        }

        w.shutdown()
    }

    /// bail out
    public func bailOut(): Unit {
        if (bailed) {
            return
        }
        bailed = true
        breakDots()
        let suffix = if (bail == 1) { "" } else { "s" }
        Output.prettyError("\nBailed out after ${bail} failure${suffix}\n")
        Output.flush()

        for (i in 0..spawnedCount) {
            let other = workers[i]
            if (other.alive) {
                match (other.inflight) {
                    case None => other.shutdown()
                    case Some(_) => ()
                }
            }
        }
    }

    /// 获取相对路径
    public func relPath(fileIdx: Int64): String {
        if (fileIdx < 0 || fileIdx >= Int64(files.size)) {
            return "<invalid>"
        }
        return files[fileIdx]
    }

    /// 确保文件头部已打印
    public func ensureHeader(fileIdx: Int64): Unit {
        if (dots) {
            return
        }
        if (lastHeaderIdx == fileIdx) {
            return
        }
        lastHeaderIdx = fileIdx
        Output.printErrorln("\n${relPath(fileIdx)}:")
    }

    /// 打断点模式
    public func breakDots(): Unit {
        if (lastPrintedDot) {
            Output.printError("\n")
            lastPrintedDot = false
        }
    }

    /// 刷新捕获的输出
    public func flushCaptured(w: Worker): Unit {
        if (w.captured.size == 0) {
            return
        }
        breakDots()
        match (w.inflight) {
            case Some(idx) => ensureHeader(idx)
            case None => ()
        }
        // 将捕获的 stdout/stderr 输出到 stderr
        let capturedStr = String.fromUtf8(Array<Byte>(w.captured.size, { i => w.captured[i] }))
        Output.printError(capturedStr)
        w.captured.clear()
    }

    /// 处理 IPC 帧
    /// 对应 Bun: Coordinator.onFrame()
    public func onFrame(w: Worker, kind: FrameKind, rd: FrameReader): Unit {
        match (kind) {
            case FrameKind.ready => assignWork(w)
            case FrameKind.fileStart => rd.u32_()
            case FrameKind.testDone =>
                let idx = rd.u32_()
                let formatted = rd.str()
                if (w.inflight != idx) {
                    return
                }
                flushCaptured(w)
                if (formatted.size == 0) {
                    return
                }
                let isDot = dots && !formatted.endsWith('\n')
                if (!isDot) {
                    breakDots()
                    ensureHeader(idx)
                }
                Output.printError(formatted)
                lastPrintedDot = isDot
                Output.flush()
            case FrameKind.fileDone =>
                let idx = rd.u32_()
                let pass = rd.u32_()
                let fail = rd.u32_()
                let skip = rd.u32_()
                let todo = rd.u32_()
                let expectations = rd.u32_()
                let skippedLabel = rd.u32_()
                let fileCount = rd.u32_()
                let unhandled = rd.u32_()

                flushCaptured(w)

                if (w.inflight != idx) {
                    return
                }

                let summary = reporter.summary()
                summary.pass += UInt32(pass)
                summary.fail += UInt32(fail)
                summary.skip += UInt32(skip)
                summary.todo += UInt32(todo)
                summary.expectations += UInt32(expectations)
                summary.skippedBecauseLabel += UInt32(skippedLabel)
                summary.files += UInt32(fileCount)
                reporter.jest.unhandledErrorsBetweenTests += UInt32(unhandled)

                w.inflight = None
                filesDone += 1
                if (bail > 0 && Int64(summary.fail) >= bail) {
                    bailOut()
                }
                if (w.alive) {
                    assignWork(w)
                }
            case FrameKind.repeatBufs =>
                rd.str()
                rd.str()
                rd.str()
            case FrameKind.junitFile =>
                let path = rd.str()
                if (path.size == 0) {
                    return
                }
                junitFragments.append(path)
            case FrameKind.coverageFile =>
                let path = rd.str()
                if (path.size == 0) {
                    return
                }
                coverageFragments.append(path)
            case FrameKind.run | FrameKind.shutdown => ()
        }
    }

    /// Worker 退出回调
    public func onWorkerExit(w: Worker, status: ProcessStatus): Unit {
        w.exitStatus = status
        w.alive = false
        tryReap(w)
    }

    /// 尝试收割 worker
    public func tryReap(w: Worker): Unit {
        let status = match (w.exitStatus) { case Some(v) => v case None => return }
        if (!w.ipc.done) {
            return
        }
        w.exitStatus = None
        reapWorker(w, status)
    }

    /// 收割 worker
    /// 对应 Bun: Coordinator.reapWorker()
    ///
    /// 1. 减少存活 worker 计数
    /// 2. 刷新缓冲输出
    /// 3. 如果有正在运行的文件, 记录崩溃
    /// 4. 如果有未分发文件, 尝试重启 worker
    /// 5. 否则清理资源
    public func reapWorker(w: Worker, status: ProcessStatus): Unit {
        liveWorkers -= 1
        flushCaptured(w)

        match (w.inflight) {
            case Some(idx) =>
                breakDots()
                ensureHeader(idx)
                let panicked = isPanicStatus(status)
                accountCrash(idx, status)
                Output.flush()
                w.inflight = None
                if (panicked) {
                    abortOnWorkerPanic(idx, status)
                }
            case None => ()
        }

        var respawned = false
        if (!bailed && hasUndispatchedFiles()) {
            w.ipc.deinit()
            w.captured.clear()
            w.ipc = Channel()
            w.process = None

            // 尝试重启 worker
            let envp = if (Int64(envps.size) > w.idx) { envps[Int64(w.idx)] } else { Array<String>() }
            let restarted = w.startWithArgs(argv, envp, cwd)
            if (restarted) {
                respawned = true
            } else {
                Output.prettyError("error: failed to respawn test worker\n")
            }
        }

        if (!respawned) {
            if (!bailed && liveWorkers == 0) {
                abortQueuedFiles("no live workers")
            }
            w.ipc.deinit()
            w.captured.clear()
        }
    }

    /// 记录崩溃
    public func accountCrash(fileIdx: Int64, status: ProcessStatus): Unit {
        breakDots()
        Output.printErrorln("X ${relPath(fileIdx)} (worker crashed: ${describeStatus(status)})")
        reporter.summary().fail += 1
        reporter.summary().files += 1
        crashedFiles.append(fileIdx)
        filesDone += 1
        if (bail > 0 && Int64(reporter.summary().fail) >= bail) {
            bailOut()
        }
    }

    /// 判断是否为 panic 状态
    public static func isPanicStatus(status: ProcessStatus): Bool {
        let sig = match (status.signalCode()) { case Some(v) => v case None => return false }
        return match (sig) {
            case "SIGILL" | "SIGTRAP" | "SIGABRT" | "SIGBUS" | "SIGFPE" | "SIGSEGV" | "SIGSYS" => true
            case _ => false
        }
    }

    /// 描述进程状态
    public static func describeStatus(status: ProcessStatus): String {
        match (status) {
            case ProcessStatus.exited(code) => "exit code ${code}"
            case ProcessStatus.signaled(sig) => sig
            case ProcessStatus.err(e) => e
            case ProcessStatus.running => "running"
        }
    }

    /// Worker panic 时中止
    public func abortOnWorkerPanic(fileIdx: Int64, status: ProcessStatus): Unit {
        breakDots()
        Output.prettyError("\nerror: a test worker process crashed with ${describeStatus(status)} while running ${relPath(fileIdx)}.\n")
        Output.prettyError("This indicates a bug in Bao or in a native addon, not in the test itself. Aborting.\n")
        Output.flush()

        for (i in 0..spawnedCount) {
            let other = workers[i]
            if (!other.alive) {
                continue
            }
            match (other.process) {
                case Some(process) => process.kill(15)
                case None => ()
            }
        }

        if (bailed) {
            return
        }
        bailed = true
        abortQueuedFiles("aborted: worker panicked")
    }

    /// 中止所有排队的文件
    public func abortQueuedFiles(reason: String): Unit {
        for (w in workers) {
            match (w.range.popFront()) {
                case Some(idx) =>
                    Output.printErrorln("X ${relPath(idx)} (${reason})")
                    reporter.summary().fail += 1
                    reporter.summary().files += 1
                    crashedFiles.append(idx)
                    filesDone += 1
                case None => ()
            }
        }
        Output.flush()
    }

    /// 分配工作或重试
    public func assignWorkOrRetry(w: Worker): Unit {
        assignWork(w)
    }
}

/// 中止信号处理器
/// 对应 Bun: Coordinator.AbortHandler
public class AbortHandler {
    public static var shouldAbort: Bool = false

    public static func install(): Unit {
        shouldAbort = false
        // TODO(bao-parallel): 注册 SIGINT/SIGTERM 处理器
        // 完整实现需要调用 sigaction 设置信号处理器
    }

    public static func uninstall(): Unit {
        // TODO(bao-parallel): 恢复原始信号处理器
        ()
    }
}
