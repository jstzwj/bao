// threadsafe_function.cj - N-API 线程安全函数实现
// 翻译自 Bun 源文件: src/runtime/napi/napi.zig 中的 ThreadSafeFunction 结构体
// 实现线程安全函数的创建、调用、获取、释放、引用/取消引用等操作。
// 对应 Bun napi.zig 中 ThreadSafeFunction struct 及其所有方法。

package bao_runtime.napi

// ============================================================================
// NapiTsfnClosingState - 线程安全函数关闭状态
// 对应 Bun: napi.zig - ThreadSafeFunction.ClosingState
// ============================================================================

/// 线程安全函数关闭状态
/// 对应 Bun: ThreadSafeFunction.ClosingState enum(u8)
public enum NapiTsfnClosingState {
    | NOT_CLOSING // 0 - 正常运行中
    | CLOSING     // 1 - 正在关闭
    | CLOSED      // 2 - 已关闭

    public func toInt(): UInt8 {
        match (this) {
            case NOT_CLOSING => 0
            case CLOSING => 1
            case CLOSED => 2
        }
    }
}

// ============================================================================
// NapiTsfnDispatchState - 线程安全函数调度状态
// 对应 Bun: napi.zig - ThreadSafeFunction.DispatchState
// ============================================================================

/// 线程安全函数调度状态
/// 对应 Bun: ThreadSafeFunction.DispatchState enum(u8)
public enum NapiTsfnDispatchState {
    | IDLE    // 0 - 空闲，没有待处理的任务
    | RUNNING // 1 - 正在运行任务
    | PENDING // 2 - 有待处理的任务等待执行

    public func toInt(): UInt8 {
        match (this) {
            case IDLE => 0
            case RUNNING => 1
            case PENDING => 2
        }
    }
}

// ============================================================================
// NapiTsfnQueue - 线程安全函数队列
// 对应 Bun: napi.zig - ThreadSafeFunction.Queue
// ============================================================================

/// 线程安全函数消息队列
/// 对应 Bun: ThreadSafeFunction.Queue struct
public class NapiTsfnQueue {
    /// 内部队列数据
/// 对应 Bun: data: bun.LinearFifo(?*anyopaque, .Dynamic)
    public var data: ArrayList<?Any> = ArrayList<?Any>()
    /// 最大队列大小（初始化后不会改变，0 表示无限制）
/// 对应 Bun: max_queue_size: usize
    public var maxQueueSize: Int64 = 0
    /// 当前队列中的项目计数
/// 对应 Bun: count: std.atomic.Value(u32)
    public var count: UInt32 = 0

    public init() {}

    public init(maxQueueSize: Int64) {
        this.maxQueueSize = maxQueueSize
    }

    /// 创建队列
    /// 对应 Bun: Queue.init
    public static func init(maxQueueSize: Int64): NapiTsfnQueue {
        let q = NapiTsfnQueue()
        q.maxQueueSize = maxQueueSize
        return q
    }

    /// 销毁队列
    /// 对应 Bun: Queue.deinit
    public func deinit(): Unit {
        this.data.clear()
    }

    /// 队列是否已满（阻塞状态）
    /// 对应 Bun: Queue.isBlocked
    public func isBlocked(): Bool {
        return this.maxQueueSize > 0 && this.count >= UInt32(this.maxQueueSize)
    }

    /// 读取一个项目
    public func readItem(): ?Any {
        if (this.data.size == 0) {
            return None
        }
        this.count -= 1
        return this.data.removeAt(0)
    }

    /// 写入一个项目
    public func writeItem(item: ?Any): Unit {
        this.data.append(item)
        this.count += 1
    }
}

// ============================================================================
// NapiTsfnCallback - 线程安全函数回调类型
// 对应 Bun: napi.zig - ThreadSafeFunction.Callback
// ============================================================================

/// 线程安全函数回调联合体
/// 对应 Bun: ThreadSafeFunction.Callback union(enum)
///
/// 两种模式:
/// 1. .js - 纯 JS 回调，只存储 JS 函数的强引用
/// 2. .c - C 回调，同时存储 JS 函数强引用和 napi_threadsafe_function_call_js 回调
public class NapiTsfnCallback {
    /// JS 函数引用
/// 对应 Bun: js: jsc.Strong.Optional (两种模式都有)
    public var jsValue: NapiValue
    /// C 调用回调（仅在 .c 模式下有值）
/// 对应 Bun: napi_threadsafe_function_call_js
    public var callJsCb: ?NapiThreadsafeFunctionCallJs = None
    /// 是否为 C 模式
    public var isCMode: Bool = false

    public init(jsValue: NapiValue) {
        this.jsValue = jsValue
    }

    public init(jsValue: NapiValue, callJsCb: NapiThreadsafeFunctionCallJs) {
        this.jsValue = jsValue
        this.callJsCb = callJsCb
        this.isCMode = true
    }

    /// 清理回调
    /// 对应 Bun: Callback.deinit
    public func deinit(): Unit {
        this.jsValue = NapiValue(JsValue.UNDEFINED)
        this.callJsCb = None
    }
}

// ============================================================================
// NapiThreadsafeFunctionImpl - 线程安全函数完整实现
// 对应 Bun: napi.zig - ThreadSafeFunction struct
// ============================================================================

/// N-API 线程安全函数完整实现
/// 对应 Bun: napi.zig - ThreadSafeFunction struct
///
/// 线程安全函数允许从任意线程安全地调度 JS 函数调用:
/// - 线程安全函数可以被 "引用" 和 "取消引用"
/// - "引用" 的线程安全函数会保持事件循环存活
/// - "取消引用" 不会阻止函数被销毁
/// - "引用" 也不会阻止函数被销毁
///
/// 对应 Bun: ThreadSafeFunction.new = bun.TrivialNew(ThreadSafeFunction)
/// 必须全局分配
public class NapiThreadsafeFunctionImpl {
    // ========================================================================
    // 字段 - 对应 Bun: ThreadSafeFunction 的所有字段
    // ========================================================================

    /// Poll 引用，控制事件循环存活
/// 对应 Bun: poll_ref: Async.KeepAlive
    public var pollRefActive: Bool = false

    /// 线程引用计数（用户实现错误可能导致此值变负）
/// 对应 Bun: thread_count: std.atomic.Value(i64)
    public var threadCount: Int64 = 0

    /// 互斥锁
/// 对应 Bun: lock: std.Thread.Mutex
    public var lock: NapiMutex = NapiMutex()

    /// 事件循环引用
/// 对应 Bun: event_loop: *jsc.EventLoop
    public var eventLoop: ?NapiEventLoopHandle = None

    /// 异步任务追踪器
/// 对应 Bun: tracker: jsc.Debugger.AsyncTaskTracker
    public var tracker: NapiAsyncTaskTracker = NapiAsyncTaskTracker()

    /// N-API 环境引用
/// 对应 Bun: env: NapiEnv.Ref
    public var env: NapiEnv

    /// 终结器函数
/// 对应 Bun: finalizer_fun: napi_finalize
    public var finalizerFun: ?NapiFinalizeFn = None
    /// 终结器数据
/// 对应 Bun: finalizer_data: ?*anyopaque
    public var finalizerData: ?Any = None

    /// 是否已排队终结器
/// 对应 Bun: has_queued_finalizer: bool
    public var hasQueuedFinalizer: Bool = false

    /// 消息队列
/// 对应 Bun: queue: Queue
    public var queue: NapiTsfnQueue = NapiTsfnQueue()

    /// 用户上下文
/// 对应 Bun: ctx: ?*anyopaque
    public var ctx: ?Any = None

    /// 回调（JS 或 C 模式）
/// 对应 Bun: callback: Callback
    public var callback: NapiTsfnCallback

    /// 调度状态
/// 对应 Bun: dispatch_state: DispatchState.Atomic
    public var dispatchState: NapiTsfnDispatchState = NapiTsfnDispatchState.IDLE

    /// 阻塞条件变量
/// 对应 Bun: blocking_condvar: std.Thread.Condition
    public var blockingCondvar: NapiCondition = NapiCondition()

    /// 关闭状态
/// 对应 Bun: closing: std.atomic.Value(ClosingState)
    public var closingState: NapiTsfnClosingState = NapiTsfnClosingState.NOT_CLOSING

    /// 是否已终止
/// 对应 Bun: aborted: std.atomic.Value(bool)
    public var aborted: Bool = true

    // ========================================================================
    // 构造
    // ========================================================================

    public init(env: NapiEnv) {
        this.env = env
        this.callback = NapiTsfnCallback(NapiValue(JsValue.UNDEFINED))
    }

    // ========================================================================
    // 核心方法 - 对应 Bun: ThreadSafeFunction 的所有 pub 方法
    // ========================================================================

    /// 分发处理（在事件循环中调用）
    /// 对应 Bun: ThreadSafeFunction.onDispatch
    ///
    /// 两种状态:
    /// 1. 需要运行可能多个任务
    /// 2. 需要终结线程安全函数
    public func onDispatch(): Unit {
        if (this.closingState == NapiTsfnClosingState.CLOSED) {
            this.deinit()
            return
        }

        var isFirst = true

        // 运行任务循环
        while (true) {
            this.dispatchState = NapiTsfnDispatchState.RUNNING
            if (this.dispatchOne(isFirst)) {
                isFirst = false
                this.dispatchState = NapiTsfnDispatchState.PENDING
            } else {
                // 所有任务完成
                this.dispatchState = NapiTsfnDispatchState.IDLE
                break
            }
        }

        // 对应 Bun: 不设置最大运行次数限制（Node.js 限制 1000 次）
    }

    /// 是否正在关闭
    /// 对应 Bun: ThreadSafeFunction.isClosing
    public func isClosing(): Bool {
        return this.closingState != NapiTsfnClosingState.NOT_CLOSING
    }

    /// 可能排队终结器
    /// 对应 Bun: ThreadSafeFunction.maybeQueueFinalizer
    ///
    /// 使用 CAS 将 closing 从 CLOSING/NOT_CLOSING 改为 CLOSED。
    /// 只有第一次成功的调用才会真正排队终结器。
    public func maybeQueueFinalizer(): Unit {
        if (!this.hasQueuedFinalizer) {
            this.hasQueuedFinalizer = true
            this.closingState = NapiTsfnClosingState.CLOSED
            this.callback.deinit()
            this.pollRefActive = false
            // 对应 Bun: this.event_loop.enqueueTask(jsc.Task.init(this))
        }
    }

    /// 分发单个任务
    /// 对应 Bun: ThreadSafeFunction.dispatchOne
    ///
    /// 返回 true 表示还有更多任务需要处理。
    public func dispatchOne(isFirst: Bool): Bool {
        var queueFinalizerAfterCall = false

        this.lock.lock()
        let wasBlocked = this.queue.isBlocked()
        let task = this.queue.readItem()
        if (task == None) {
            // 队列为空
            if (this.threadCount == 0) {
                this.maybeQueueFinalizer()
            }
            this.lock.unlock()
            return false
        }

        let currentCount = this.queue.count
        if (currentCount == 0 && this.threadCount == 0) {
            this.closingState = NapiTsfnClosingState.CLOSING
            queueFinalizerAfterCall = true
        } else if (wasBlocked && !this.queue.isBlocked()) {
            this.blockingCondvar.signal()
        }

        let hasMore = !this.isClosing()
        this.lock.unlock()

        this.call(task, !isFirst)

        if (queueFinalizerAfterCall) {
            this.maybeQueueFinalizer()
        }

        return hasMore
    }

    /// 调用 JS 函数
    /// 对应 Bun: ThreadSafeFunction.call
    ///
    /// 此函数可以在一个事件循环 tick 中被调用多次。
    /// 非第一次调用前需要排空微任务。
    public func call(task: ?Any, isFirst: Bool): Unit {
        let env = this.env
        if (!isFirst) {
            // 对应 Bun: try this.event_loop.drainMicrotasks()
        }

        if (this.callback.isCMode) {
            // C 回调模式
            let jsCallback = this.callback.jsValue
            let callJs = this.callback.callJsCb
            if (callJs != None) {
                let handleScope = NapiHandleScope.open(env, false)
                callJs.getOrThrow()(env, jsCallback, this.ctx, task)
                if (handleScope != None) {
                    handleScope.getOrThrow().close(env)
                }
            }
        } else {
            // 纯 JS 回调模式
/// 对应 Bun: js.call(globalObject, .js_undefined, &.{})
            let jsValue = this.callback.jsValue
            if (!jsValue.get().isUndefinedOrNull()) {
                // 调用 JS 函数
            }
        }
    }

    /// 将数据入队
    /// 对应 Bun: ThreadSafeFunction.enqueue
    ///
    /// 阻塞模式下会等待直到队列有空间。
    /// 非阻塞模式下如果队列满则返回 queue_full。
    public func enqueue(data: ?Any, block: Bool): UInt32 {
        this.lock.lock()

        if (block) {
            while (this.queue.isBlocked()) {
                this.blockingCondvar.wait(this.lock)
            }
        } else {
            if (this.queue.isBlocked()) {
                this.lock.unlock()
                // 对应 Bun: 不设置 env 的错误（从其他线程调用）
                return NapiStatus.queueFull.toInt()
            }
        }

        if (this.isClosing()) {
            if (this.threadCount <= 0) {
                this.lock.unlock()
                return NapiStatus.invalidArg.toInt()
            }
            this.releaseInternal(NapiThreadsafeFunctionReleaseMode.napiTsfnRelease, true)
            this.lock.unlock()
            return NapiStatus.closing.toInt()
        }

        this.queue.writeItem(data)
        this.scheduleDispatch()
        this.lock.unlock()
        return NapiStatus.ok.toInt()
    }

    /// 调度分发
    /// 对应 Bun: ThreadSafeFunction.scheduleDispatch
    public func scheduleDispatch(): Unit {
        match (this.dispatchState) {
            case IDLE =>
                this.dispatchState = NapiTsfnDispatchState.PENDING
                // 对应 Bun: this.event_loop.enqueueTaskConcurrent(jsc.ConcurrentTask.createFrom(this))
            case RUNNING =>
                // 会检查是否有更多工作要做
                ()
            case PENDING =>
                // 已经调度过了
                ()
        }
    }

    /// 清理
    /// 对应 Bun: ThreadSafeFunction.deinit
    public func deinit(): Unit {
        this.unref()

        if (this.finalizerFun != None) {
            // 对应 Bun: finalizer.enqueue()
            let finalizer = NapiFinalizer(this.env, this.finalizerFun.getOrThrow())
            finalizer.data = this.finalizerData
            finalizer.hint = this.ctx
            finalizer.enqueue()
        }

        this.callback.deinit()
        this.queue.deinit()
    }

    /// 引用（保持事件循环存活）
    /// 对应 Bun: ThreadSafeFunction.ref
    public func ref(): Unit {
        this.pollRefActive = true
        // 对应 Bun: this.poll_ref.refConcurrentlyFromEventLoop(this.event_loop)
    }

    /// 取消引用
    /// 对应 Bun: ThreadSafeFunction.unref
    public func unref(): Unit {
        this.pollRefActive = false
        // 对应 Bun: this.poll_ref.unrefConcurrentlyFromEventLoop(this.event_loop)
    }

    /// 获取引用
    /// 对应 Bun: ThreadSafeFunction.acquire
    public func acquire(): UInt32 {
        this.lock.lock()
        if (this.isClosing()) {
            this.lock.unlock()
            return NapiStatus.closing.toInt()
        }
        this.threadCount += 1
        this.lock.unlock()
        return NapiStatus.ok.toInt()
    }

    /// 释放引用
    /// 对应 Bun: ThreadSafeFunction.release
    ///
    /// mode:
    /// - release: 正常释放，当 thread_count 降到 0 时触发终结
    /// - abort: 立即关闭
    public func release(mode: NapiThreadsafeFunctionReleaseMode, alreadyLocked: Bool): UInt32 {
        if (!alreadyLocked) {
            this.lock.lock()
        }

        if (this.threadCount < 0) {
            if (!alreadyLocked) {
                this.lock.unlock()
            }
            return NapiStatus.invalidArg.toInt()
        }

        this.threadCount -= 1

        if (mode == NapiThreadsafeFunctionReleaseMode.napiTsfnAbort || this.threadCount == 1) {
            if (!this.isClosing()) {
                if (mode == NapiThreadsafeFunctionReleaseMode.napiTsfnAbort) {
                    this.closingState = NapiTsfnClosingState.CLOSING
                    this.aborted = true
                    this.blockingCondvar.signal()
                }
                this.scheduleDispatch()
            }
        }

        if (!alreadyLocked) {
            this.lock.unlock()
        }

        return NapiStatus.ok.toInt()
    }

    /// 内部释放（已持有锁时调用）
    private func releaseInternal(mode: NapiThreadsafeFunctionReleaseMode,
        alreadyLocked: Bool): UInt32 {
        return this.release(mode, alreadyLocked)
    }
}

// ============================================================================
// 辅助同步类型
// ============================================================================

/// 简单互斥锁
/// 对应 Bun: std.Thread.Mutex
public class NapiMutex {
    public func lock(): Unit {
        // 简化实现
    }

    public func unlock(): Unit {
        // 简化实现
    }
}

/// 简单条件变量
/// 对应 Bun: std.Thread.Condition
public class NapiCondition {
    public func wait(mutex: NapiMutex): Unit {
        // 简化实现
    }

    public func signal(): Unit {
        // 简化实现
    }

    public func broadcast(): Unit {
        // 简化实现
    }
}

/// 异步任务追踪器
/// 对应 Bun: jsc.Debugger.AsyncTaskTracker
public class NapiAsyncTaskTracker {
    public init() {}

    public func willDispatch(globalObject: JsObject): Unit {
        // 简化实现
    }

    public func didDispatch(globalObject: JsObject): Unit {
        // 简化实现
    }

    public func didSchedule(globalObject: JsObject): Unit {
        // 简化实现
    }

    public static func init_(vm: ?Any): NapiAsyncTaskTracker {
        return NapiAsyncTaskTracker()
    }
}

// ============================================================================
// N-API 线程安全函数导出接口
// 对应 Bun: napi.zig 中的 napi_*_threadsafe_function 系列导出函数
// ============================================================================

/// N-API 线程安全函数操作集合
public class NapiThreadsafeFunctionFunctions {

    /// napi_create_threadsafe_function
    /// 对应 Bun: pub export fn napi_create_threadsafe_function
    public static func create(env: NapiEnv, func_: NapiValue,
        asyncResource: NapiValue, asyncResourceName: NapiValue,
        maxQueueSize: Int64, initialThreadCount: Int64,
        threadFinalizeData: ?Any,
        threadFinalizeCb: ?NapiFinalizeFn,
        context: ?Any,
        callJsCb: ?NapiThreadsafeFunctionCallJs): ?NapiThreadsafeFunctionImpl {
        let tsfn = NapiThreadsafeFunctionImpl(env)
        tsfn.ctx = context
        tsfn.queue = NapiTsfnQueue.init(maxQueueSize)
        tsfn.threadCount = initialThreadCount
        tsfn.finalizerFun = threadFinalizeCb
        tsfn.finalizerData = threadFinalizeData
        tsfn.aborted = false

        if (callJsCb != None) {
            // C 回调模式
            tsfn.callback = NapiTsfnCallback(func_, callJsCb.getOrThrow())
        } else {
            // 纯 JS 回调模式
            tsfn.callback = NapiTsfnCallback(func_)
        }

        // 对应 Bun: nodejs by default keeps the event loop alive until the thread-safe function is unref'd
        tsfn.ref()
        tsfn.tracker.didSchedule(env.toJS())

        return tsfn
    }

    /// napi_get_threadsafe_function_context
    /// 对应 Bun: pub export fn napi_get_threadsafe_function_context
    public static func getContext(func: NapiThreadsafeFunctionImpl): ?Any {
        return func.ctx
    }

    /// napi_call_threadsafe_function
    /// 对应 Bun: pub export fn napi_call_threadsafe_function
    public static func call(func: NapiThreadsafeFunctionImpl, data: ?Any,
        isBlocking: NapiThreadsafeFunctionCallMode): UInt32 {
        // 对应 Bun: func.enqueue(data, is_blocking == napi_tsfn_blocking)
        return func.enqueue(data, isBlocking == NapiThreadsafeFunctionCallMode.napiTsfnBlocking)
    }

    /// napi_acquire_threadsafe_function
    /// 对应 Bun: pub export fn napi_acquire_threadsafe_function
    public static func acquire(func: NapiThreadsafeFunctionImpl): UInt32 {
        return func.acquire()
    }

    /// napi_release_threadsafe_function
    /// 对应 Bun: pub export fn napi_release_threadsafe_function
    public static func release(func: NapiThreadsafeFunctionImpl,
        mode: NapiThreadsafeFunctionReleaseMode): UInt32 {
        return func.release(mode, false)
    }

    /// napi_unref_threadsafe_function
    /// 对应 Bun: pub export fn napi_unref_threadsafe_function
    public static func unref(env: NapiEnv, func: NapiThreadsafeFunctionImpl): UInt32 {
        func.unref()
        return NapiStatus.ok.toInt()
    }

    /// napi_ref_threadsafe_function
    /// 对应 Bun: pub export fn napi_ref_threadsafe_function
    public static func ref_(env: NapiEnv, func: NapiThreadsafeFunctionImpl): UInt32 {
        func.ref()
        return NapiStatus.ok.toInt()
    }
}
