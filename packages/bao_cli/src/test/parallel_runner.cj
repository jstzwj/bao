// 严格翻译自: src/cli/test/ParallelRunner.zig
package bao_cli.test

import bao_core.*
import bao_runtime.*
import bao_collections.*

// ============================================================================
// ParallelRunner — 并行测试运行器门面
// 严格翻译自: src/cli/test/ParallelRunner.zig
//
// 薄门面, 重新导出 parallel/ 中的入口点
//
// bun test --parallel: 进程池协调器和工作器
// 协调器延迟启动最多 N 个 bao test --test-worker --isolate 进程
// (从一个开始, 当每个活跃 worker 都忙碌 >= scale_up_after_ms 时增加),
// 通过 stdin 一次分发一个文件, 通过 fd 3 读回每个测试的事件
// ============================================================================

/// 作为协调器运行
/// 对应 Bun: ParallelRunner.runAsCoordinator
///
/// 当 K > 1 时:
///   1. 排序文件 (保持目录局部性)
///   2. 分配文件范围给 worker
///   3. 驱动事件循环分发/收集
///   4. 合并 JUnit + 覆盖率片段
/// 当 K <= 1 时回退到串行路径
public func runAsCoordinator(
    reporter: CommandLineReporter,
    vm: VirtualMachine,
    files: Array<PathString>,
    ctx: CommandContext,
    coverageOpts: CodeCoverageOptions
): Bool {
    let N = files.size
    let K = if (Int64(ctx.testOptions.parallel) < N) { Int64(ctx.testOptions.parallel) } else { Int64(N) }

    if (K <= 1) {
        // 单 worker 或无文件, 使用串行路径
        TestCommand.runAllTests(reporter, vm, files, ctx.allocator)
        return false
    }

    // 委托给 parallel/ 中的完整实现
    return bao_cli.test.parallel.ParallelRunner.runAsCoordinator(
        reporter, vm, files, ctx, coverageOpts
    )
}

/// 作为工作器运行
/// 对应 Bun: ParallelRunner.runAsWorker
///
/// Worker 端事件循环:
///   1. 通过 IPC 接收文件分配
///   2. 在隔离上下文中执行测试文件
///   3. 流式传输结果回协调器
public func runAsWorker(
    reporter: CommandLineReporter,
    vm: VirtualMachine,
    ctx: CommandContext
): Unit {
    bao_cli.test.parallel.ParallelRunner.runAsWorker(reporter, vm, ctx)
}

/// 工作器发出测试完成事件
/// 对应 Bun: ParallelRunner.workerEmitTestDone
///
/// 在 worker 端的 CommandLineReporter.handleTestCompleted 中调用
public func workerEmitTestDone(fileIdx: Int64, formattedLine: String): Unit {
    bao_cli.test.parallel.ParallelRunner.workerEmitTestDone(fileIdx, formattedLine)
}
