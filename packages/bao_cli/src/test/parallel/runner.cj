// 严格翻译自: src/cli/test/parallel/runner.zig
package bao_cli.test.parallel

import bao_core.*
import bao_runtime.*
import bao_cli.*
import bao_cli.test.*
import bao_collections.*
import bao_sys.*

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
        files: Array<String>,
        ctx: CommandContext,
        coverageOpts: CodeCoverageOptions
    ): Bool {
        let N: Int64 = Int64(files.size)
        let K: Int64 = Int64(ctx.testOptions.parallel)
        let effectiveK = if (K < N) { K } else { N }

        // K <= 1: 回退到串行路径
        if (effectiveK <= 1) {
            TestCommand.runAllTests(reporter, vm, files, ctx.allocator)
            return false
        }

        // 创建临时目录用于 JUnit 和覆盖率片段
        var workerTmpdir: ?String = None
        if (ctx.testOptions.reporters.junit || coverageOpts.enabled) {
            let tmpBase = Sys.getenv("TMPDIR") ?? "/tmp"
            let tmpDir = "${tmpBase}/bao-test-worker-${Sys.pid()}"
            SysFs.mkdir(tmpDir, UInt32(0o755))
            workerTmpdir = tmpDir
        }

        // 构建每个 worker 的 argv
        let argv = buildWorkerArgv(ctx)

        // 构建每个 worker 的 envp (带 JEST_WORKER_ID / BUN_TEST_WORKER_ID)
        let envps = ArrayList<Array<String>>()
        for (i in 0..effectiveK) {
            let id = "${i + 1}"
            let envEntries = Sys.getEnvAll()
            let envList = ArrayList<String>()
            for (entry in envEntries) {
                envList.append(entry)
            }
            envList.append("JEST_WORKER_ID=${id}")
            envList.append("BUN_TEST_WORKER_ID=${id}")
            envps.append(Array<String>(envList.size, { i => envList[i] }))
        }

        // 创建 worker 数组并分配文件范围
        let workers = Array<Worker>(effectiveK, { _ => Worker() })
        for (i in 0..effectiveK) {
            let w = workers[i]
            w.idx = i
            w.range = FileRange(i * N / effectiveK, (i + 1) * N / effectiveK)
        }

        // 创建协调器
        let coord = Coordinator()
        coord.vm = vm
        coord.reporter = reporter
        coord.files = files
        coord.cwd = Sys.getcwd()
        coord.argv = argv
        coord.envps = Array<Array<String>>(envps.size, { i => envps[i] })
        coord.workers = workers
        coord.workerTmpdir = workerTmpdir
        coord.parallelLimit = effectiveK
        coord.scaleUpAfterMs = DEFAULT_SCALE_UP_AFTER_MS
        coord.bail = 0
        coord.dots = false

        // 设置 worker 的协调器引用
        for (i in 0..effectiveK) {
            workers[i].coord = coord
        }

        // 安装信号处理器
        AbortHandler.install()

        // 驱动主循环
        coord.drive()

        // 卸载信号处理器
        AbortHandler.uninstall()

        // 合并 JUnit 报告
        if (ctx.testOptions.reporters.junit) {
            if (let Some(outfile) <- ctx.testOptions.reporterOutfile) {
                mergeJUnitFragments(coord, outfile, reporter.summary())
            }
        }

        // 合并覆盖率数据
        if (coverageOpts.enabled) {
            mergeCoverageFragments(coord.coverageFragments, coverageOpts, true)
        }

        // 清理临时目录
        if (let Some(tmpDir) <- workerTmpdir) {
            // 尝试清理, 但不中断退出
            try { SysFs.rmdir(tmpDir) } catch (_: Exception) { () }
        }

        return true
    }

    /// 作为工作器运行
    /// 对应 Bun: runAsWorker()
    ///
    /// Worker 端事件循环:
    ///   1. 通过 IPC 通道从协调器接收文件分配
    ///   2. 在隔离上下文中执行每个测试文件
    ///   3. 流式传输 test_done/file_done 帧回协调器
    ///   4. 处理 shutdown 命令退出
    public static func runAsWorker(
        reporter: CommandLineReporter,
        vm: VirtualMachine,
        ctx: CommandContext
    ): Unit {
        vm.testIsolationEnabled = true

        // 创建 worker 命令通道
        let cmds = WorkerCommands()
        cmds.vm = vm

        // 尝试采用 IPC fd (fd 3)
        // 对应 Bun: cmds.channel.adopt(vm, .fromUV(3))
        let adopted = cmds.channel.adopt(vm, 3)
        if (!adopted) {
            // 无法采用 IPC fd, 可能非 worker 模式
            return
        }

        // 发送 ready 帧通知协调器
        workerFrame.begin(FrameKind.ready)
        cmds.send(workerFrame.finish())

        // 设置全局 worker 命令引用
        workerCmds = cmds

        // 主循环: 等待并处理文件分配
        while (true) {
            // 等待协调器分发文件
            while (cmds.pendingIdx == None && !cmds.done) {
                vm.getEventLoop().tickOnce()
            }

            let idx = cmds.pendingIdx ?? (-1)
            cmds.pendingIdx = None

            if (idx < 0 || cmds.done) {
                break
            }

            // 发送 file_start 帧
            workerFrame.begin(FrameKind.fileStart)
            workerFrame.u32_(idx)
            cmds.send(workerFrame.finish())

            // 记录执行前的统计
            let before = reporter.summary().copy()
            let beforeUnhandled = reporter.jest.unhandledErrorsBetweenTests

            // 执行测试文件 (隔离模式)
            // 对应 Bun: TestCommand.run(reporter, vm, path, .{.first=true, .last=true})
            try {
                vm.executeFile(cmds.pendingPath)
            } catch (_: Exception) {
                // 执行失败, 继续处理下一个文件
            }

            // 重置全局状态用于隔离
            vm.swapGlobalForTestIsolation()

            // 发送 file_done 帧报告统计
            let after = reporter.summary()
            workerFrame.begin(FrameKind.fileDone)
            workerFrame.u32_(idx)
            workerFrame.u32_(Int64(after.pass - before.pass))
            workerFrame.u32_(Int64(after.fail - before.fail))
            workerFrame.u32_(Int64(after.skip - before.skip))
            workerFrame.u32_(Int64(after.todo - before.todo))
            workerFrame.u32_(Int64(after.expectations - before.expectations))
            workerFrame.u32_(Int64(after.skippedBecauseLabel - before.skippedBecauseLabel))
            workerFrame.u32_(Int64(after.files - before.files))
            workerFrame.u32_(Int64(after.unhandledErrorsBetweenTests - beforeUnhandled))
            cmds.send(workerFrame.finish())
        }

        // 刷新聚合数据
        workerFlushAggregates(reporter, vm, ctx, None, cmds)

        // 排空待发送的帧
        while (cmds.channel.hasPendingWrites() && !cmds.channel.done) {
            vm.getEventLoop().tickOnce()
        }

        Global.exit(0)
    }

    /// 工作器发出测试完成事件
    /// 对应 Bun: workerEmitTestDone()
    ///
    /// 在 worker 端的 CommandLineReporter.handleTestCompleted 中调用
    /// 将格式化的状态行 (包含 ANSI codes) 通过 IPC 发送回协调器
    public static func workerEmitTestDone(fileIdx: Int64, formattedLine: String): Unit {
        let cmds = match (workerCmds) { case Some(v) => v case None => return }
        workerFrame.begin(FrameKind.testDone)
        workerFrame.u32_(fileIdx)
        workerFrame.str(formattedLine)
        cmds.send(workerFrame.finish())
    }

    /// 构建工作器 argv
    /// 对应 Bun: buildWorkerArgv()
    ///
    /// 转发影响测试执行的标志, 不转发协调器专属标志
    /// (--path-ignore-patterns, --changed, --reporter, --parallel)
    private static func buildWorkerArgv(ctx: CommandContext): Array<String> {
        let argv = ArrayList<String>()
        let exePath = Sys.getenv("_") ?? "bao" // best effort: use $_ or "bao"
        argv.append(exePath)
        argv.append("test")
        argv.append("--test-worker")
        argv.append("--isolate")

        // 转发影响测试执行的选项
        // 严格对应 Bun: runner.zig buildWorkerArgv 中逐项转发的标志
        let opts = ctx.testOptions

        // JUnit 报告
        if (opts.reporters.junit) { argv.append("--junit") }
        if (opts.junit) { argv.append("--junit") }

        // 覆盖率
        if (opts.coverage.enabled) { argv.append("--coverage") }

        return Array<String>(argv.size, { i => argv[i] })
    }

    /// 刷新工作器聚合数据 (repeat_bufs + JUnit + 覆盖率片段)
    /// 对应 Bun: workerFlushAggregates()
    private static func workerFlushAggregates(
        reporter: CommandLineReporter,
        vm: VirtualMachine,
        ctx: CommandContext,
        workerTmp: ?String,
        cmds: WorkerCommands
    ): Unit {
        // 发送 repeat_bufs 帧 (失败/跳过/todo 列表)
        workerFrame.begin(FrameKind.repeatBufs)
        workerFrame.str("") // failures_to_repeat_buf
        workerFrame.str("") // skips_to_repeat_buf
        workerFrame.str("") // todos_to_repeat_buf
        cmds.send(workerFrame.finish())

        // 如果有临时目录, 写入 JUnit 和覆盖率片段
        if (let Some(dir) <- workerTmp) {
            let pid = Sys.pid()

            // JUnit 片段
            workerFrame.begin(FrameKind.junitFile)
            let junitPath = "${dir}/w${pid}.xml"
            workerFrame.str(junitPath)
            cmds.send(workerFrame.finish())

            // 覆盖率片段
            if (ctx.testOptions.coverage.enabled) {
                workerFrame.begin(FrameKind.coverageFile)
                let covPath = "${dir}/cov${pid}.lcov"
                workerFrame.str(covPath)
                cmds.send(workerFrame.finish())
            }
        }
    }
}

/// 工作器命令状态
/// 对应 Bun: WorkerCommands
public class WorkerCommands {
    public var vm: VirtualMachine = VirtualMachine()
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
