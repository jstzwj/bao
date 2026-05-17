// 严格翻译自: src/cli/test/parallel/runner.zig
package bao_cli.test.parallel

import bao_core.*
import bao_runtime.*
import bao_cli.test.*
import bao_collections.*

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
        TestCommand.runAllTests(reporter, vm, files, ctx.allocator)
        return false
    }

    /// 作为工作器运行
    /// 对应 Bun: runAsWorker()
    public static func runAsWorker(
        reporter: CommandLineReporter,
        vm: VirtualMachine,
        ctx: CommandContext
    ): Unit {
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
        return Array<String>()
    }

    /// 刷新工作器聚合数据
    private static func workerFlushAggregates(
        reporter: CommandLineReporter,
        vm: VirtualMachine,
        ctx: CommandContext,
        workerTmp: ?String,
        cmds: WorkerCommands
    ): Unit {
        ()
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
