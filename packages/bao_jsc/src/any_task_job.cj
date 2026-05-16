// 严格翻译自: src/jsc/any_task_job.rs
// AnyTaskJob<C> — 通用的 "WorkPool 卸载 -> AnyTask 重排队 -> JS线程完成" 样板代码
// 每个调用点只需提供一个实现了 AnyTaskJobCtx 的 Context; 堆分配、
// WorkPoolTask/AnyTask 连接、KeepAlive 引用/取消引用、is_shutting_down 守卫都在此处理

package bao_jsc

import bao_event_loop.AnyTask
import bao_io.KeepAlive
import bao_threading.WorkPoolTask
import bao_threading.WorkPool

// ========== AnyTaskJobCtx ==========
// 严格翻译自 any_task_job.rs AnyTaskJobCtx trait
// 每个任务的上下文 trait。实现者拥有线程外工作体和 JS 线程完成回调;
// 周围的堆/队列/keep-alive 管道由 AnyTaskJob 提供
public interface AnyTaskJobCtx<C> {
    // 可选的可失败 JS 线程设置, 在堆分配后、schedule 之前运行
    // 默认: 无操作
    func init(global: JSGlobalObject) -> Result<Unit>

    // 工作池体 — 在 JS 线程之外运行
    func run(global: CPointer<JSGlobalObject>)

    // JS 线程完成回调。在 run 重新排队到事件循环后调用一次
    func then(global: JSGlobalObject) -> Result<Unit>
}

// ========== AnyTaskJob ==========
// 严格翻译自 any_task_job.rs AnyTaskJob<C>
// 堆分配的 {WorkPoolTask, AnyTask, KeepAlive, ctx} 捆绑包
// 通过 create / createAndSchedule 创建; 在 runFromJS (或 init 失败时) 释放
public class AnyTaskJob<C> where C <: AnyTaskJobCtx<C> {
    public var vm: BunVirtualMachine = BunVirtualMachine()
    public var task: WorkPoolTask = WorkPoolTask()
    public var anyTask: AnyTask = AnyTask()
    public var poll: KeepAlive = KeepAlive()
    public var ctx: C

    public init(ctx: C) {
        this.ctx = ctx
    }

    // ========== create ==========
    // 严格翻译自 AnyTaskJob::create
    // 堆分配, 连接 WorkPoolTask/AnyTask, 并运行 ctx.init()
    // 在 init 错误时释放分配 (运行 Drop for C)
    public static func create(global: JSGlobalObject, ctx: C) -> Result<AnyTaskJob<C>> {
        let vm = global.bunVM()
        let job = AnyTaskJob<C>(ctx: ctx)
        job.vm = vm
        job.task = WorkPoolTask(callback: job.runTask)

        // 构建 AnyTask (类型擦除的回调)
        job.anyTask = AnyTask(
            ctx: job,
            callback: { (self_: AnyTaskJob<C>) => self_.runFromJS() }
        )

        // ctx.init 可能抛出; 在错误时回收 job
        match(ctx.init(global)) {
            case Err(e) => return Err(e)
            case Ok(_) => {}
        }
        Ok(job)
    }

    // ========== schedule ==========
    // 严格翻译自 AnyTaskJob::schedule
    // KeepAlive.ref JS 事件循环并将侵入式任务交给工作池
    public static func schedule(job: AnyTaskJob<C>) {
        job.poll.ref(job.vm)
        WorkPool.schedule(job.task)
    }

    // ========== createAndSchedule ==========
    // 严格翻译自 AnyTaskJob::createAndSchedule
    // create + schedule 组合。用于调度后不需要从 ctx 读回数据的调用者
    public static func createAndSchedule(global: JSGlobalObject, ctx: C) -> Result<Unit> {
        let job = try create(global, ctx)
        schedule(job)
        Ok(())
    }

    // ========== runTask ==========
    // 严格翻译自 AnyTaskJob::run_task
    // WorkPoolTask 回调 — 在 JS 线程之外运行
    fn runTask(task: WorkPoolTask) {
        // 从 task 指针恢复 job (侵入式容器)
        let global = vm.global()
        ctx.run(global)
        // 将结果通过 AnyTask 排队回 JS 线程
        vm.eventLoopShared().enqueueTaskConcurrent(anyTask.task())
    }

    // ========== runFromJS ==========
    // 严格翻译自 AnyTaskJob::run_from_js
    // AnyTask 回调 — 在 JS 线程运行。回收堆分配
    public func runFromJS() -> Result<Unit> {
        if (vm.isShuttingDown()) {
            return Ok(())
        }
        ctx.then(vm.global())
    }

    // ========== deinit ==========
    // 清理: 取消 KeepAlive 引用
    public func deinit() {
        poll.unref(vm)
    }
}
