// 严格翻译自: src/cli/test/ParallelRunner.zig
package bao_cli.test

// ============================================================================
// ParallelRunner — 并行测试运行器门面
// 严格翻译自: src/cli/test/ParallelRunner.zig
//
// 薄门面, 重新导出 parallel/ 中的入口点
//
// bun test --parallel: 进程池协调器和工作器
// 协调器延迟启动最多 N 个 bun test --test-worker --isolate 进程
// (从一个开始, 当每个活跃 worker 都忙碌 >= scale_up_after_ms 时增加),
// 通过 stdin 一次分发一个文件, 通过 fd 3 读回每个测试的事件
// ============================================================================

/// 作为协调器运行
/// 对应 Bun: runner.runAsCoordinator
public func runAsCoordinator(
    reporter: CommandLineReporter,
    vm: VirtualMachine,
    files: Array<PathString>,
    ctx: CommandContext,
    coverageOpts: TestCommand.CodeCoverageOptions
): Bool {
    return ParallelRunner.runAsCoordinator(reporter, vm, files, ctx, coverageOpts)
}

/// 作为工作器运行
/// 对应 Bun: runner.runAsWorker
public func runAsWorker(
    reporter: CommandLineReporter,
    vm: VirtualMachine,
    ctx: CommandContext
): Unit {
    ParallelRunner.runAsWorker(reporter, vm, ctx)
}

/// 工作器发出测试完成事件
/// 对应 Bun: runner.workerEmitTestDone
public func workerEmitTestDone(fileIdx: Int64, formattedLine: String): Unit {
    ParallelRunner.workerEmitTestDone(fileIdx, formattedLine)
}
