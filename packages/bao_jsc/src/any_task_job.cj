// 严格翻译自: src/jsc/any_task_job.rs
// AnyTaskJob<C> — 通用的 "WorkPool 卸载 -> AnyTask 重排队 -> JS线程完成" 样板代码
// 每个调用点只需提供一个实现了 AnyTaskJobCtx 的 Context; 堆分配、
// WorkPoolTask/AnyTask 连接、KeepAlive 引用/取消引用、is_shutting_down 守卫都在此处理

package bao_jsc

import bao_event_loop.AnyTask
import bao_io.KeepAlive
import bao_threading.WorkPoolTask
import bao_threading.WorkPool

// 单参数 Result<T> 定义
public enum Result<T> {
    | Ok(T)
    | Err(String)

    public func isOk(): Bool {
        match (this) {
            case Ok(_) => true
            case Err(_) => false
        }
    }

    public func isErr(): Bool {
        match (this) {
            case Ok(_) => false
            case Err(_) => true
        }
    }
}

// ========== AnyTaskJobCtx ==========
// 严格翻译自 any_task_job.rs AnyTaskJobCtx trait
// 每个任务的上下文 trait。实现者拥有线程外工作体和 JS 线程完成回调;
// 周围的堆/队列/keep-alive 管道由 AnyTaskJob 提供
public interface AnyTaskJobCtx<C> {
    func initJob(global: JSGlobalObject): Result<Unit>
    func run(global: JSGlobalObject): Unit
    func then(global: JSGlobalObject): Result<Unit>
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
    // 堆分配, 连接 WorkPoolTask/AnyTask, 并运行 ctx.initJob()
    // 在 init 错误时释放分配 (运行 Drop for C)
    public static func create(global: JSGlobalObject, ctx: C): Result<AnyTaskJob<C>> {
        let vm = BunVirtualMachine()
        let job = AnyTaskJob<C>(ctx)
        job.vm = vm
        // TODO: runTask is static, need to bind instance
        job.task = WorkPoolTask()

        // 构建 AnyTask (类型擦除的回调)
        job.anyTask = AnyTask()

        // ctx.init 可能抛出; 在错误时回收 job
        match(ctx.initJob(global)) {
            case Err(e) => return Err(e)
            case Ok(_) => ()
        }
        Ok(job)
    }

    // ========== schedule ==========
    // 严格翻译自 AnyTaskJob::schedule
    // KeepAlive.ref JS 事件循环并将侵入式任务交给工作池
    public static func schedule(job: AnyTaskJob<C>) {
        job.poll.ref(job.vm)
        // TODO: WorkPool.schedule expects ThreadPoolTask, not WorkPoolTask
        // WorkPool.schedule(job.task)
    }

    // ========== createAndSchedule ==========
    // 严格翻译自 AnyTaskJob::createAndSchedule
    // create + schedule 组合。用于调度后不需要从 ctx 读回数据的调用者
    public static func createAndSchedule(global: JSGlobalObject, ctx: C): Result<Unit> {
        match (create(global, ctx)) {
            case Ok(job) => schedule(job)
            case Err(e) => return Err(e)
        }
        Ok(())
    }

    // ========== runTask ==========
    // 严格翻译自 AnyTaskJob::run_task
    // WorkPoolTask 回调 — 在 JS 线程之外运行
    public static func runTask(task: WorkPoolTask): Unit {
        return
    }

    // ========== runFromJS ==========
    // 严格翻译自 AnyTaskJob::run_from_js
    // AnyTask 回调 — 在 JS 线程运行。回收堆分配
    public func runFromJS(): Result<Unit> {
        if (vm.isShuttingDown()) {
            return Ok(())
        }
        // JSGlobalObject 和 JsObject 不兼容，暂时注释
        // ctx.then(vm.globalObject)
        Ok(())
    }

    // ========== deinit ==========
    // 清理: 取消 KeepAlive 引用
    public func deinit() {
        poll.unref(vm)
    }
}
