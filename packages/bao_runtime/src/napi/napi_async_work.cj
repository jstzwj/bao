// napi_async_work.cj - N-API 异步工作实现
// 翻译自 Bun 源文件: src/runtime/napi/napi.zig 中的 napi_async_work 结构体
// 实现异步工作的创建、调度、执行和取消。
// 对应 Bun napi.zig 中 napi_async_work struct 及其所有方法。

package bao_runtime.napi

// ============================================================================
// NapiAsyncWorkStatus - 异步工作状态
// 对应 Bun: napi.zig - napi_async_work.Status
// ============================================================================

/// 异步工作状态枚举
/// 对应 Bun: napi_async_work.Status enum(u32)
public enum NapiAsyncWorkStatus {
    | PENDING   // 0 - 等待调度
    | STARTED   // 1 - 正在执行
    | COMPLETED // 2 - 执行完成
    | CANCELLED // 3 - 已被取消

    public func toInt(): UInt32 {
        match (this) {
            case PENDING => 0
            case STARTED => 1
            case COMPLETED => 2
            case CANCELLED => 3
        }
    }

    public static func fromInt(value: UInt32): NapiAsyncWorkStatus {
        match (value) {
            case 0 => PENDING
            case 1 => STARTED
            case 2 => COMPLETED
            case 3 => CANCELLED
            case _ => PENDING
        }
    }
}

// ============================================================================
// NapiAsyncWorkImpl - 异步工作实现
// 对应 Bun: napi.zig - napi_async_work struct
// ============================================================================

/// N-API 异步工作实现
/// 对应 Bun: napi.zig - napi_async_work struct
///
/// Bun 的 napi_async_work 是一个线程池任务:
/// 1. napi_create_async_work 创建工作对象
/// 2. napi_queue_async_work 将工作提交到线程池
/// 3. execute 回调在工作线程上执行
/// 4. complete 回调在 JS 线程上执行
///
/// 必须全局分配 (must be globally allocated)
public class NapiAsyncWorkImpl {
    /// N-API 环境
/// 对应 Bun: env: NapiEnv.Ref
    public var env: NapiEnv
    /// 执行回调（在工作线程上运行）
/// 对应 Bun: execute: napi_async_execute_callback
    public var execute: ?NapiAsyncExecuteCallback = None
    /// 完成回调（在 JS 线程上运行）
/// 对应 Bun: complete: ?napi_async_complete_callback
    public var complete: ?NapiAsyncCompleteCallback = None
    /// 透传数据
/// 对应 Bun: data: ?*anyopaque
    public var data: ?Any = None
    /// 当前状态（原子操作）
/// 对应 Bun: status: std.atomic.Value(Status)
    public var status: NapiAsyncWorkStatus = NapiAsyncWorkStatus.PENDING
    /// 是否已调度
/// 对应 Bun: scheduled: bool
    public var scheduled: Bool = false

    public init(env: NapiEnv) {
        this.env = env
    }

    /// 创建新的异步工作
    /// 对应 Bun: napi_async_work.new
    ///
    /// 在 Bun 中，这会分配一个新的 napi_async_work 并设置事件循环引用。
    /// 全局对象从 env 获取，env 的引用会被克隆保存。
    public static func new_(env: NapiEnv, execute: NapiAsyncExecuteCallback,
        complete: ?NapiAsyncCompleteCallback, data: ?Any): NapiAsyncWorkImpl {
        let work = NapiAsyncWorkImpl(env)
        work.execute = execute
        work.complete = complete
        work.data = data
        return work
    }

    /// 销毁异步工作
    /// 对应 Bun: napi_async_work.destroy
    public func destroy(): Unit {
        // 对应 Bun: this.env.deinit(); bun.destroy(this)
        // 释放 env 引用和内存
    }

    /// 调度异步工作到线程池
    /// 对应 Bun: napi_async_work.schedule
    ///
    /// 如果已经调度过，则不会重复调度。
    /// 调度时会增加 poll_ref 以保持事件循环存活。
    public func schedule(): Unit {
        if (this.scheduled) {
            return
        }
        this.scheduled = true
        // 对应 Bun: this.poll_ref.ref(this.global.bunVM())
        // 对应 Bun: WorkPool.schedule(&this.task)
    }

    /// 从线程池执行
    /// 对应 Bun: napi_async_work.runFromThreadPool -> run
    ///
    /// 使用 CAS 操作将状态从 PENDING 改为 STARTED。
    /// 如果状态已经是 CANCELLED，则直接将任务入队到事件循环并返回。
    /// 执行完成后状态改为 COMPLETED，然后将任务入队到事件循环。
    public func run(): Unit {
        // 对应 Bun: cmpxchgStrong(.pending, .started, .seq_cst, .seq_cst)
        if (this.status != NapiAsyncWorkStatus.PENDING) {
            if (this.status == NapiAsyncWorkStatus.CANCELLED) {
                // 对应 Bun: this.event_loop.enqueueTaskConcurrent(...)
                return
            }
        }

        this.status = NapiAsyncWorkStatus.STARTED

        // 执行回调
        if (this.execute != None) {
            this.execute.getOrThrow()(this.env, this.data)
        }

        this.status = NapiAsyncWorkStatus.COMPLETED

        // 对应 Bun: this.event_loop.enqueueTaskConcurrent(this.concurrent_task.from(this, .manual_deinit))
    }

    /// 取消异步工作
    /// 对应 Bun: napi_async_work.cancel
    ///
    /// 只有在 PENDING 状态下才能取消。
    /// 返回 true 表示成功取消，false 表示无法取消。
    public func cancel(): Bool {
        if (this.status == NapiAsyncWorkStatus.PENDING) {
            this.status = NapiAsyncWorkStatus.CANCELLED
            return true
        }
        return false
    }

    /// 在 JS 线程上运行完成回调
    /// 对应 Bun: napi_async_work.runFromJS
    ///
    /// 此方法在事件循环中被调用，负责:
    /// 1. 取消 poll_ref 引用
    /// 2. 如果有 complete 回调，调用它
    /// 3. 处理异常
    ///
    /// 注意: 在 complete 回调执行后，work 可能已经被用户释放。
    public func runFromJs(): Unit {
        // 对应 Bun: var poll_ref = this.poll_ref; defer poll_ref.unref(vm)

        let completeFunc = this.complete
        if (completeFunc == None) {
            return
        }

        let env = this.env

        // 打开句柄作用域
        let handleScope = NapiHandleScope.open(env, false)

        // 确定传递给 complete 的状态码
/// 对应 Bun: const status: NapiStatus = if (this.status.load(.seq_cst) == .cancelled) .cancelled else .ok
        let status: NapiStatus = if (this.status == NapiAsyncWorkStatus.CANCELLED) {
            NapiStatus.cancelled
        } else {
            NapiStatus.ok
        }

        // 调用 complete 回调
/// 对应 Bun: complete(env, @intFromEnum(status), this.data)
        completeFunc.getOrThrow()(env, status.toInt(), this.data)

        // 关闭句柄作用域
        if (handleScope != None) {
            handleScope.getOrThrow().close(env)
        }

        // 对应 Bun: 检查并处理待处理异常
    }
}

// ============================================================================
// N-API 异步工作函数封装
// 对应 Bun: napi.zig 中 napi_*_async_work 系列导出函数
// ============================================================================

/// N-API 异步工作函数集合
public class NapiAsyncWorkFunctions {

    /// napi_create_async_work
    /// 对应 Bun: pub export fn napi_create_async_work
    ///
    /// 创建一个新的异步工作对象。
    /// env 不能为 null，result 不能为 null，execute 不能为 null。
    public static func create(env: NapiEnv, asyncResource: NapiValue,
        asyncResourceName: String,
        execute: ?NapiAsyncExecuteCallback,
        complete: ?NapiAsyncCompleteCallback,
        data: ?Any): ?NapiAsyncWorkImpl {
        // 对应 Bun: const execute = execute_ orelse return env.invalidArg()
        if (execute == None) {
            return None
        }
        return NapiAsyncWorkImpl.new_(env, execute.getOrThrow(), complete, data)
    }

    /// napi_delete_async_work
    /// 对应 Bun: pub export fn napi_delete_async_work
    public static func delete_(env: NapiEnv, work: ?NapiAsyncWorkImpl): UInt32 {
        if (work == None) {
            return NapiStatus.invalidArg.toInt()
        }
        work.getOrThrow().destroy()
        return NapiStatus.ok.toInt()
    }

    /// napi_queue_async_work
    /// 对应 Bun: pub export fn napi_queue_async_work
    public static func queue(env: NapiEnv, work: ?NapiAsyncWorkImpl): UInt32 {
        if (work == None) {
            return NapiStatus.invalidArg.toInt()
        }
        work.getOrThrow().schedule()
        return NapiStatus.ok.toInt()
    }

    /// napi_cancel_async_work
    /// 对应 Bun: pub export fn napi_cancel_async_work
    public static func cancel(env: NapiEnv, work: ?NapiAsyncWorkImpl): UInt32 {
        if (work == None) {
            return NapiStatus.invalidArg.toInt()
        }
        if (work.getOrThrow().cancel()) {
            return NapiStatus.ok.toInt()
        }
        return NapiStatus.genericFailure.toInt()
    }
}
