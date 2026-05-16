// 严格翻译自: src/cli/test/parallel/runner.zig
package bao_cli.test.parallel

import bao_core.*

// ============================================================================
// Runner — 协调器和工作器入口点
// 严格翻译自: src/cli/test/parallel/runner.zig
//
// runAsCoordinator: 设置 Coordinator, 排序/分区文件, 驱动循环, 合并片段
// runAsWorker: --test-worker 端, 从 stdin 读取帧命令, 运行文件, 流式传输结果
// ============================================================================

/// 所有 worker 忙碌至少这么长时间后才生成新 worker
/// 对应 Bun: default_scale_up_after_ms
public let DEFAULT_SCALE_UP_AFTER_MS: Int64 = 5

/// 运行器
/// 对应 Bun: runner (runner.zig 中的顶层函数)
public class ParallelRunner {
    /// 当前 worker 帧缓冲区 (跨所有 worker->coordinator 发送复用)
    private static var workerFrame: Frame = Frame()

    /// worker 命令通道 (在 runAsWorker 中设置)
    private static var workerCmds: ?WorkerCommands = None

    /// 作为协调器运行
    /// 返回 true 如果文件确实通过 worker 池运行, false 如果回退到串行路径
    /// 对应 Bun: runAsCoordinator()
    public static func runAsCoordinator(
        reporter: CommandLineReporter,
        vm: VirtualMachine,
        files: Array<PathString>,
        ctx: CommandContext,
        coverageOpts: TestCommand.CodeCoverageOptions
    ): Bool {
        let N = files.size
        let K = Math.min(ctx.testOptions.parallel, N)
        if (K <= 1) {
            // 即使 --maxWorkers=1 也设置 JEST_WORKER_ID
            vm.transpiler.env.map.put("JEST_WORKER_ID", "1")
            vm.transpiler.env.map.put("BAO_TEST_WORKER_ID", "1")
            TestCommand.runAllTests(reporter, vm, files, ctx.allocator)
            return false
        }

        // Worker stderr 是管道; 为颜色终端启用 ANSI
        if (Output.enableAnsiColorsStderr) {
            vm.transpiler.env.map.put("FORCE_COLOR", "1")
        }

        var workerTmpdir: ?String = None
        if (ctx.testOptions.reporters.junit || coverageOpts.enabled) {
            let dir = "${FileSystem.RealFS.getDefaultTempDir()}/bao-test-worker-${Sys.getpid()}"
            BaoFile.mkdir(dir, true)
            workerTmpdir = dir
            vm.transpiler.env.map.put("BAO_TEST_WORKER_TMP", dir)
            if (reporter.reporters.junit != None) {
                vm.transpiler.env.map.put("BAO_TEST_WORKER_JUNIT", "1")
                reporter.reporters.junit = None
            }
        }

        // 每个 worker 获得唯一的 JEST_WORKER_ID / BAO_TEST_WORKER_ID (1-indexed)
        let envps = ArrayList<Array<String>>()
        for (i in 0..K) {
            let id = "${i + 1}"
            vm.transpiler.env.map.put("JEST_WORKER_ID", id)
            vm.transpiler.env.map.put("BAO_TEST_WORKER_ID", id)
            envps.append(vm.transpiler.env.map.toNullDelimitedEnvMap())
        }
        let argv = buildWorkerArgv(ctx)

        // 按字典序排序以共享父目录
        let sorted = ArrayList<PathString>()
        for (f in files) {
            sorted.append(f)
        }
        if (!ctx.testOptions.randomize) {
            sorted.sort({ a, b => a.slice().compareTo(b.slice()) })
        }

        let workers = ArrayList<Worker>(K)
        for (i in 0..K) {
            workers.append(Worker())
        }

        let coord = Coordinator()
        coord.vm = vm
        coord.reporter = reporter
        coord.files = sorted.toArray()
        coord.cwd = FileSystem.instance.topLevelDir
        coord.argv = argv
        coord.envps = envps.toArray()
        coord.workers = workers.toArray()
        coord.workerTmpdir = workerTmpdir
        coord.parallelLimit = K
        coord.scaleUpAfterMs = if (ctx.testOptions.parallelDelayMs != None) {
            ctx.testOptions.parallelDelayMs.getOrThrow()
        } else {
            let envMs = vm.transpiler.env.get("BAO_TEST_PARALLEL_SCALE_MS")
            if (envMs != None) {
                let parsedMs = Int64.parse(envMs.getOrThrow())
                Math.max(0, match (parsedMs) { case Some(v) => v case None => DEFAULT_SCALE_UP_AFTER_MS })
            } else {
                DEFAULT_SCALE_UP_AFTER_MS
            }
        }
        coord.bail = ctx.testOptions.bail
        coord.dots = ctx.testOptions.reporters.dots

        Coordinator.AbortHandler.install()

        for (i in 0..K) {
            let idx = i.toInt()
            let w = workers[idx]
            w.coord = coord
            w.idx = idx
            w.range = FileRange(idx * N / K, (idx + 1) * N / K)
        }

        vm.eventLoop().ensureWaker()
        coord.drive()

        // 合并 JUnit 和覆盖率片段
        if (ctx.testOptions.reporters.junit && ctx.testOptions.reporterOutfile != None) {
            Aggregate.mergeJUnitFragments(coord, ctx.testOptions.reporterOutfile.getOrThrow(), reporter.summary())
        }
        if (coverageOpts.enabled) {
            Aggregate.mergeCoverageFragments(coord.coverageFragments, coverageOpts, Output.enableAnsiColorsStderr)
        }

        Coordinator.AbortHandler.uninstall()
        return true
    }

    /// 作为工作器运行
    /// 对应 Bun: runAsWorker()
    public static func runAsWorker(
        reporter: CommandLineReporter,
        vm: VirtualMachine,
        ctx: CommandContext
    ): Unit {
        vm.testIsolationEnabled = true
        vm.autoKiller.enabled = true

        vm.eventLoop().ensureWaker()

        let workerTmp = vm.transpiler.env.get("BAO_TEST_WORKER_TMP")
        if (vm.transpiler.env.get("BAO_TEST_WORKER_JUNIT") != None && reporter.reporters.junit == None) {
            reporter.reporters.junit = TestCommand.JunitReporter.init()
        }

        let cmds = WorkerCommands()
        cmds.vm = vm

        // 发送 ready 帧
        workerFrame.begin(FrameKind.ready)
        cmds.send(workerFrame.finish())

        // 主循环
        while (true) {
            // 等待命令
            while (cmds.pendingIdx == None && !cmds.done) {
                vm.eventLoop().tick()
            }

            let idx = match (cmds.pendingIdx) { case Some(v) => v case None => break }
            cmds.pendingIdx = None

            // 发送 file_start
            reporter.workerIpcFileIdx = idx
            workerFrame.begin(FrameKind.fileStart)
            workerFrame.u32_(idx)
            cmds.send(workerFrame.finish())

            // 运行测试文件
            let before = reporter.summary().copy()
            let beforeUnhandled = reporter.jest.unhandledErrorsBetweenTests

            TestCommand.run(reporter, vm, cmds.pendingPath, true, true)
            vm.swapGlobalForTestIsolation()

            // 发送 file_done
            let after = reporter.summary()
            workerFrame.begin(FrameKind.fileDone)
            workerFrame.u32_(idx)
            workerFrame.u32_(after.pass - before.pass)
            workerFrame.u32_(after.fail - before.fail)
            workerFrame.u32_(after.skip - before.skip)
            workerFrame.u32_(after.todo - before.todo)
            workerFrame.u32_(after.expectations - before.expectations)
            workerFrame.u32_(after.skippedBecauseLabel - before.skippedBecauseLabel)
            workerFrame.u32_(after.files - before.files)
            workerFrame.u32_(reporter.jest.unhandledErrorsBetweenTests - beforeUnhandled)
            cmds.send(workerFrame.finish())
        }

        // 刷新聚合数据
        workerFlushAggregates(reporter, vm, ctx, workerTmp, cmds)
        Global.exit(0)
    }

    /// 工作器发出测试完成事件
    /// 对应 Bun: workerEmitTestDone()
    public static func workerEmitTestDone(fileIdx: Int64, formattedLine: String): Unit {
        let cmds = match (workerCmds) { case Some(v) => v case None => return }
        workerFrame.begin(FrameKind.testDone)
        workerFrame.u32_(fileIdx)
        workerFrame.str(formattedLine)
        cmds.send(workerFrame.finish())
    }

    /// 构建工作器 argv
    /// 对应 Bun: buildWorkerArgv()
    private static func buildWorkerArgv(ctx: CommandContext): Array<String> {
        let argv = ArrayList<String>()
        let opts = ctx.testOptions

        argv.append(match (Sys.selfExePath()) { case Some(v) => v case None => "bao" })
        argv.append("test")
        argv.append("--test-worker")
        argv.append("--isolate")
        argv.append("--timeout=${opts.defaultTimeoutMs}")

        if (opts.runTodo) argv.append("--todo")
        if (opts.only) argv.append("--only")
        if (opts.reporters.dots) argv.append("--dots")
        if (opts.reporters.onlyFailures) argv.append("--only-failures")
        if (opts.updateSnapshots) argv.append("--update-snapshots")
        if (opts.concurrent) argv.append("--concurrent")
        if (opts.randomize) argv.append("--randomize")
        if (opts.seed != None) argv.append("--seed=${opts.seed.getOrThrow()}")
        if (opts.repeatCount > 0) argv.append("--rerun-each=${opts.repeatCount}")
        if (opts.retry > 0) argv.append("--retry=${opts.retry}")
        argv.append("--max-concurrency=${opts.maxConcurrency}")
        if (opts.testFilterPattern != None) {
            argv.append("-t")
            argv.append(opts.testFilterPattern.getOrThrow())
        }
        if (opts.coverage.enabled) {
            argv.append("--coverage")
        }

        return argv.toArray()
    }

    /// 刷新工作器聚合数据
    private static func workerFlushAggregates(
        reporter: CommandLineReporter,
        vm: VirtualMachine,
        ctx: CommandContext,
        workerTmp: ?String,
        cmds: WorkerCommands
    ): Unit {
        // 快照刷新
        workerFrame.begin(FrameKind.repeatBufs)
        workerFrame.str(reporter.failuresToRepeatBuf)
        workerFrame.str(reporter.skipsToRepeatBuf)
        workerFrame.str(reporter.todosToRepeatBuf)
        cmds.send(workerFrame.finish())

        // JUnit 和覆盖率片段
        if (workerTmp != None) {
            let pid = Sys.getpid()
            if (reporter.reporters.junit != None) {
                let path = "${workerTmp.getOrThrow()}/w${pid}.xml"
                if (reporter.reporters.junit.getOrThrow().writeToFile(path)) {
                    workerFrame.begin(FrameKind.junitFile)
                    workerFrame.str(path)
                    cmds.send(workerFrame.finish())
                }
            }
            if (ctx.testOptions.coverage.enabled) {
                let path = "${workerTmp.getOrThrow()}/cov${pid}.lcov"
                if (reporter.writeLcovOnly(vm, ctx.testOptions.coverage, path)) {
                    workerFrame.begin(FrameKind.coverageFile)
                    workerFrame.str(path)
                    cmds.send(workerFrame.finish())
                }
            }
        }
    }
}

/// 工作器命令状态
/// 对应 Bun: WorkerCommands
public class WorkerCommands {
    public var vm: VirtualMachine
    public var channel: Channel = Channel()
    public var pendingIdx: ?Int64 = None
    public var pendingPath: String = ""
    public var done: Bool = false

    /// 发送帧字节
    public func send(frameBytes: Array<Byte>): Unit {
        channel.send(frameBytes)
    }

    /// 通道帧回调
    public func onChannelFrame(kind: FrameKind, rd: FrameReader): Unit {
        match (kind) {
            case FrameKind.run =>
                pendingIdx = rd.u32_()
                pendingPath = rd.str()
            case FrameKind.shutdown => done = true
            case _ => ()
        }
    }

    /// 通道完成回调
    public func onChannelDone(): Unit {
        done = true
    }
}
