// 严格翻译自: src/cli/test/parallel/Coordinator.zig
package bao_cli.test.parallel

import bao_core.*
import bao_runtime.*
import std.collection.*

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
    public var files: Array<PathString>

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
    public func drive(): Unit {
        spawnWorker()
        while (!isDone()) {
            if (AbortHandler.shouldAbort) {
                abortAll()
                return
            }
            vm.eventLoop().tick()
            maybeScaleUp()
            if (isDone()) {
                break
            }
            if (spawnedCount < parallelLimit && hasUndispatchedFiles() && !bailed) {
                vm.eventLoop().tickWithTimeout(scaleUpAfterMs)
            } else {
                vm.eventLoop().autoTick()
            }
        }
    }

    /// 中止所有 worker
    /// 对应 Bun: Coordinator.abortAll()
    public func abortAll(): Unit {
        AbortHandler.uninstall()
        for (i in 0..spawnedCount) {
            let w = workers[i.toInt()]
            if (w.process != None) {
                w.process.getOrThrow().kill()
            }
        }
        Global.exit(130)
    }

    /// 生成 worker
    /// 对应 Bun: Coordinator.spawnWorker()
    public func spawnWorker(): Bool {
        let w = workers[spawnedCount.toInt()]
        w.ipc = Channel()
        w.start()
        spawnedCount += 1
        return true
    }

    /// 延迟扩容
    /// 对应 Bun: Coordinator.maybeScaleUp()
    public func maybeScaleUp(): Unit {
        if (spawnedCount >= parallelLimit) {
            return
        }
        if (bailed || !hasUndispatchedFiles()) {
            return
        }
        let now = Sys.milliTimestamp()
        for (i in 0..spawnedCount) {
            let w = workers[i.toInt()]
            if (!w.alive) {
                continue
            }
            if (w.inflight == None) {
                return
            }
            if (now - w.dispatchedAt < scaleUpAfterMs) {
                return
            }
        }
        let want = Math.min(parallelLimit, files.size - filesDone)
        while (spawnedCount < want) {
            if (!spawnWorker()) {
                break
            }
        }
    }

    /// 分配工作给 worker
    /// 对应 Bun: Coordinator.assignWork()
    public func assignWork(w: Worker): Unit {
        if (bailed) {
            w.shutdown()
            return
        }

        // 从自己的范围取
        let popResult = w.range.popFront()
        if (popResult != None) {
            let idx = popResult.getOrThrow()
            w.dispatch(idx, files[idx.toInt()].slice())
            return
        }

        // 偷取
        let victim = findStealVictim()
        if (victim != None) {
            let stolen = victim.getOrThrow().range.stealBackHalf()
            if (stolen != None) {
                w.range = stolen.getOrThrow()
                let popResult2 = w.range.popFront()
                if (popResult2 != None) {
                    let pr2 = popResult2.getOrThrow()
                    w.dispatch(pr2, files[pr2.toInt()].slice())
                    return
                }
            }
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
            let other = workers[i.toInt()]
            if (other.alive && other.inflight == None) {
                other.shutdown()
            }
        }
    }

    /// 获取相对路径
    public func relPath(fileIdx: Int64): String {
        return Path.relative(FileSystem.instance.topLevelDir, files[fileIdx.toInt()].slice())
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
        Output.errorWriter().println("\n${relPath(fileIdx)}:")
    }

    /// 打断点模式
    public func breakDots(): Unit {
        if (lastPrintedDot) {
            Output.errorWriter().write('\n')
            lastPrintedDot = false
        }
    }

    /// 刷新捕获的输出
    public func flushCaptured(w: Worker): Unit {
        if (w.captured.size == 0) {
            return
        }
        breakDots()
        if (w.inflight != None) {
            ensureHeader(w.inflight.getOrThrow())
        }
        Output.errorWriter().writeAll(w.captured)
        if (!w.captured.endsWith('\n')) {
            Output.errorWriter().write('\n')
        }
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
                Output.errorWriter().writeAll(formatted)
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
                let files = rd.u32_()
                let unhandled = rd.u32_()

                flushCaptured(w)

                if (w.inflight != idx) {
                    return
                }

                let summary = reporter.summary()
                summary.pass += pass
                summary.fail += fail
                summary.skip += skip
                summary.todo += todo
                summary.expectations += expectations
                summary.skippedBecauseLabel += skippedLabel
                summary.files += files
                reporter.jest.unhandledErrorsBetweenTests += unhandled

                w.inflight = None
                filesDone += 1
                if (bail > 0 && summary.fail >= bail) {
                    bailOut()
                }
                if (w.alive) {
                    assignWork(w)
                }
            case FrameKind.repeatBufs =>
                let failures = rd.str()
                let skips = rd.str()
                let todos = rd.str()
                reporter.failuresToRepeatBuf += failures
                reporter.skipsToRepeatBuf += skips
                reporter.todosToRepeatBuf += todos
            case FrameKind.junitFile | FrameKind.coverageFile =>
                let path = rd.str()
                if (path.size == 0) {
                    return
                }
                let list = if (kind == FrameKind.junitFile) { junitFragments } else { coverageFragments }
                list.append(path)
            case FrameKind.run | FrameKind.shutdown => ()
        }
    }

    /// Worker 退出回调
    public func onWorkerExit(w: Worker, status: ProcessStatus): Unit {
        w.exitStatus = status
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
    public func reapWorker(w: Worker, status: ProcessStatus): Unit {
        liveWorkers -= 1
        flushCaptured(w)

        if (w.inflight != None) {
            let idx = w.inflight.getOrThrow()
            breakDots()
            ensureHeader(idx)
            let panicked = isPanicStatus(status)
            accountCrash(idx, status)
            Output.flush()
            w.inflight = None
            if (panicked) {
                abortOnWorkerPanic(idx, status)
            }
        }

        var respawned = false
        if (!bailed && hasUndispatchedFiles()) {
            w.ipc.deinit()
            w.captured.clear()
            w.ipc = Channel()
            w.process = None
            w.start()
            respawned = true
        }

        if (!respawned) {
            w.ipc.deinit()
            w.captured.clear()
        }
    }

    /// 记录崩溃
    public func accountCrash(fileIdx: Int64, status: ProcessStatus): Unit {
        breakDots()
        Output.prettyErrorLn("✗ ${relPath(fileIdx)} (worker crashed: ${describeStatus(status)})")
        reporter.summary().fail += 1
        reporter.summary().files += 1
        crashedFiles.append(fileIdx)
        filesDone += 1
        if (bail > 0 && reporter.summary().fail >= bail) {
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
            let other = workers[i.toInt()]
            if (!other.alive) {
                continue
            }
            if (other.process != None) {
                other.process.getOrThrow().kill()
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
            let pop = w.range.popFront()
            if (pop != None) {
                let idx = pop.getOrThrow()
                Output.prettyErrorLn("✗ ${relPath(idx)} (${reason})")
                reporter.summary().fail += 1
                reporter.summary().files += 1
                crashedFiles.append(idx)
                filesDone += 1
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
        SignalHandler.install(SIGINT, { => shouldAbort = true })
        SignalHandler.install(SIGTERM, { => shouldAbort = true })
    }

    public static func uninstall(): Unit {
        SignalHandler.uninstall()
    }
}
