// node_api.cj - Node API 扩展函数声明
// 翻译自 Bun 源文件: src/runtime/napi/node_api.h + napi.zig 中的 Node 特有函数
// 包含 Buffer 操作、异步工作、线程安全函数、模块注册、
// 环境清理钩子等 Node.js 扩展的 N-API 函数。
// 对应 Bun napi.zig 中的 export/extern fn 实现。

package bao_runtime.napi

import bao_jsc.*
import bao_collections.ArrayList

// ============================================================================
// NodeApi - Node.js 扩展 N-API 函数集合
// 对应 Bun: napi.zig 中 Node.js 特有的 export/extern fn
// ============================================================================

/// Node API 扩展函数
/// 封装 node_api.h 和 napi.zig 中 Node.js 特有的函数
public class NodeApi {

    // ========================================================================
    // 模块注册
    // ========================================================================

    /// napi_module_register
    /// 对应 Bun: napi.zig - NAPI_EXTERN void napi_module_register(napi_module* mod)
    public static func moduleRegister(mod: NapiModule): Unit {
        // 简化实现：在实际运行时中会调用模块的注册函数
    }

    /// napi_fatal_error
    /// 对应 Bun: napi.zig - pub export fn napi_fatal_error
    /// 致命错误，不可返回（noreturn）
    public static func fatalError(location: ?String, message: ?String): Unit {
        let loc = location ?? ""
        let msg = message ?? "fatal error"
        // 对应 Bun: bun.Output.panic("NAPI FATAL ERROR: {s} {s}")
        throw NapiFatalError("${loc} ${msg}")
    }

    // ========================================================================
    // 异步操作管理
    // ========================================================================

    /// napi_async_init
    /// 对应 Bun: napi.zig - pub export fn napi_async_init
    /// Bun 不支持真正的异步上下文，直接返回 env 作为占位
    public static func asyncInit(env: NapiEnv, asyncResource: NapiValue,
        asyncResourceName: NapiValue): NapiAsyncContextHandle {
        // 对应 Bun: async_ctx.* = env;
        return NapiAsyncContextHandle()
    }

    /// napi_async_destroy
    /// 对应 Bun: napi.zig - pub export fn napi_async_destroy
    public static func asyncDestroy(env: NapiEnv, asyncContext: NapiAsyncContextHandle): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// napi_make_callback
    /// 对应 Bun: napi.zig - pub export fn napi_make_callback
    /// 在异步上下文中调用函数
    public static func makeCallback(env: NapiEnv, asyncContext: NapiAsyncContextHandle,
        recv: NapiValue, func_: NapiValue,
        args: ArrayList<NapiValue>): NapiValue {
        let funcVal = func_.get()
        if (!funcVal.isCallable()) {
            return NapiValue.create(env, JsValue.UNDEFINED)
        }
        let global = env.toJS()
        let jsArgs = Array<JsValue>(args.size, { i: Int64 => args[i].get() })
        let result = funcVal.call(global, recv.get(), jsArgs)
        return NapiValue.create(env, result)
    }

    // ========================================================================
    // Buffer 操作
    // ========================================================================

    /// napi_create_buffer
    /// 对应 Bun: napi.zig - pub extern fn napi_create_buffer
    public static func createBuffer(env: NapiEnv, length: Int64): NapiBufferInfo {
        let info = NapiBufferInfo()
        info.byteLength = length
        return info
    }

    /// napi_create_external_buffer
    /// 对应 Bun: napi.zig - pub extern fn napi_create_external_buffer
    public static func createExternalBuffer(env: NapiEnv, length: Int64, data: ?Any,
        finalizeCb: ?NapiFinalizeFn,
        finalizeHint: ?Any): NapiValue {
        return NapiValue.create(env, JsValue.UNDEFINED)
    }

    /// napi_create_buffer_copy
    /// 对应 Bun: napi.zig - pub export fn napi_create_buffer_copy
    public static func createBufferCopy(env: NapiEnv, length: Int64, data: ?Array<Byte>): NapiBufferInfo {
        let info = NapiBufferInfo()
        info.byteLength = length
        return info
    }

    /// napi_is_buffer
    /// 对应 Bun: napi.zig - extern fn napi_is_buffer
    public static func isBuffer(env: NapiEnv, value: NapiValue): Bool {
        // Buffer 在 JS 中是 Uint8Array 的子类
        let v = value.get()
        return v.valueType == JsValueType.TypedArray
    }

    /// napi_get_buffer_info
    /// 对应 Bun: napi.zig - pub export fn napi_get_buffer_info
    /// 获取 Buffer 信息（data 指针和长度）
    public static func getBufferInfo(env: NapiEnv, value: NapiValue): NapiBufferInfo {
        let info = NapiBufferInfo()
        let v = value.get()
        // Buffer 是 Uint8Array 的子类
        if (v.valueType == JsValueType.TypedArray || v.valueType == JsValueType.ArrayBuffer) {
            let global = env.toJS()
            let lengthVal = v.get(global, "byteLength")
            if (let Some(lv) <- lengthVal) {
                if (lv.isNumber()) {
                    info.byteLength = Int64(lv.toNumber())
                } else {
                    info.byteLength = 0
                }
            } else {
                info.byteLength = 0
            }
        } else {
            info.byteLength = 0
        }
        return info
    }

    // ========================================================================
    // 异步工作 (Async Work)
    // ========================================================================

    /// napi_create_async_work
    /// 对应 Bun: napi.zig - pub export fn napi_create_async_work
    public static func createAsyncWork(env: NapiEnv, asyncResource: NapiValue,
        asyncResourceName: NapiValue,
        execute: ?NapiAsyncExecuteCallback,
        complete: ?NapiAsyncCompleteCallback,
        data: ?Any): ?NapiAsyncWorkImpl {
        if (execute.isNone()) {
            return None
        }
        let work = NapiAsyncWorkImpl(env)
        work.execute = execute
        work.complete = complete
        work.data = data
        work.status = NapiAsyncWorkStatus.PENDING
        return work
    }

    /// napi_delete_async_work
    /// 对应 Bun: napi.zig - pub export fn napi_delete_async_work
    public static func deleteAsyncWork(env: NapiEnv, work: NapiAsyncWorkImpl): UInt32 {
        // 对应 Bun: work.destroy()
        return NapiStatus.ok.toInt()
    }

    /// napi_queue_async_work
    /// 对应 Bun: napi.zig - pub export fn napi_queue_async_work
    public static func queueAsyncWork(env: NapiEnv, work: NapiAsyncWorkImpl): UInt32 {
        // 对应 Bun: work.schedule()
        work.status = NapiAsyncWorkStatus.STARTED
        // 在线程池上执行 execute 回调
        if (work.execute.isSome()) {
            work.execute.getOrThrow()(env, work.data)
            work.status = NapiAsyncWorkStatus.COMPLETED
        }
        return NapiStatus.ok.toInt()
    }

    /// napi_cancel_async_work
    /// 对应 Bun: napi.zig - pub export fn napi_cancel_async_work
    public static func cancelAsyncWork(env: NapiEnv, work: NapiAsyncWorkImpl): UInt32 {
        let isPending: Bool = match (work.status) {
            case NapiAsyncWorkStatus.PENDING => true
            case _ => false
        }
        if (isPending) {
            work.status = NapiAsyncWorkStatus.CANCELLED
            return NapiStatus.ok.toInt()
        }
        return NapiStatus.genericFailure.toInt()
    }

    // ========================================================================
    // 版本管理
    // ========================================================================

    /// napi_get_node_version
    /// 对应 Bun: napi.zig - pub export fn napi_get_node_version
    public static func getNodeVersion(env: NapiEnv): NapiNodeVersion {
        return NapiNodeVersion.globalVersion()
    }

    // ========================================================================
    // 事件循环 (NAPI_VERSION >= 2)
    // ========================================================================

    /// napi_get_uv_event_loop
    /// 对应 Bun: napi.zig - pub export fn napi_get_uv_event_loop
    /// Bun 在 POSIX 上返回自己的事件循环，而非 libuv
    public static func getUvEventLoop(env: NapiEnv): NapiEventLoopHandle {
        return NapiEventLoopHandle()
    }

    // ========================================================================
    // 异常和清理 (NAPI_VERSION >= 3)
    // ========================================================================

    /// napi_fatal_exception
    /// 对应 Bun: napi.zig - pub extern fn napi_fatal_exception
    public static func fatalException(env: NapiEnv, err: NapiValue): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// napi_add_env_cleanup_hook
    /// 对应 Bun: napi.zig - pub extern fn napi_add_env_cleanup_hook
    public static func addEnvCleanupHook(env: NapiEnv, fun: NapiEnvCleanupHook, arg: ?Any): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// napi_remove_env_cleanup_hook
    /// 对应 Bun: napi.zig - pub extern fn napi_remove_env_cleanup_hook
    public static func removeEnvCleanupHook(env: NapiEnv, fun: NapiEnvCleanupHook, arg: ?Any): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// napi_open_callback_scope
    /// 对应 Bun: napi.zig - pub export fn napi_open_callback_scope
    /// Bun 直接返回 ok（不做任何操作）
    public static func openCallbackScope(env: NapiEnv, resourceObject: NapiValue,
        context: NapiAsyncContextHandle): UInt32 {
        return NapiStatus.ok.toInt()
    }

    /// napi_close_callback_scope
    /// 对应 Bun: napi.zig - pub export fn napi_close_callback_scope
    /// Bun 直接返回 ok（不做任何操作）
    public static func closeCallbackScope(env: NapiEnv, scope: NapiCallbackScopeHandle): UInt32 {
        return NapiStatus.ok.toInt()
    }

    // ========================================================================
    // 线程安全函数 (NAPI_VERSION >= 4)
    // ========================================================================

    /// napi_create_threadsafe_function
    /// 对应 Bun: napi.zig - pub export fn napi_create_threadsafe_function
    public static func createThreadsafeFunction(env: NapiEnv, func_: NapiValue,
        asyncResource: NapiValue, asyncResourceName: NapiValue,
        maxQueueSize: Int64, initialThreadCount: Int64,
        threadFinalizeData: ?Any,
        threadFinalizeCb: ?NapiFinalizeFn,
        context: ?Any,
        callJsCb: ?NapiThreadsafeFunctionCallJs): ?NapiThreadsafeFunction {
        let tsfn = NapiThreadsafeFunction()
        tsfn.env = env
        tsfn.ctx = context
        tsfn.maxQueueSize = maxQueueSize
        tsfn.threadCount = initialThreadCount
        tsfn.finalizerFun = threadFinalizeCb
        tsfn.finalizerData = threadFinalizeData
        tsfn.callJsCb = callJsCb
        tsfn.callback = func_
        return tsfn
    }

    /// napi_get_threadsafe_function_context
    /// 对应 Bun: napi.zig - pub export fn napi_get_threadsafe_function_context
    public static func getThreadsafeFunctionContext(fn__: NapiThreadsafeFunction): ?Any {
        return fn__.ctx
    }

    /// napi_call_threadsafe_function
    /// 对应 Bun: napi.zig - pub export fn napi_call_threadsafe_function
    public static func callThreadsafeFunction(fn__: NapiThreadsafeFunction, data: ?Any,
        isBlocking: NapiThreadsafeFunctionCallMode): UInt32 {
        // 对应 Bun: func.enqueue(data, is_blocking == napi_tsfn_blocking)
        let isBlockingMode: Bool = match (isBlocking) {
            case NapiThreadsafeFunctionCallMode.napiTsfnBlocking => true
            case _ => false
        }
        return fn__.enqueue(data, isBlockingMode)
    }

    /// napi_acquire_threadsafe_function
    /// 对应 Bun: napi.zig - pub export fn napi_acquire_threadsafe_function
    public static func acquireThreadsafeFunction(fn__: NapiThreadsafeFunction): UInt32 {
        return fn__.acquire()
    }

    /// napi_release_threadsafe_function
    /// 对应 Bun: napi.zig - pub export fn napi_release_threadsafe_function
    public static func releaseThreadsafeFunction(fn__: NapiThreadsafeFunction,
        mode: NapiThreadsafeFunctionReleaseMode): UInt32 {
        return fn__.release(mode, false)
    }

    /// napi_unref_threadsafe_function
    /// 对应 Bun: napi.zig - pub export fn napi_unref_threadsafe_function
    public static func unrefThreadsafeFunction(env: NapiEnv, fn__: NapiThreadsafeFunction): UInt32 {
        fn__.unref()
        return NapiStatus.ok.toInt()
    }

    /// napi_ref_threadsafe_function
    /// 对应 Bun: napi.zig - pub export fn napi_ref_threadsafe_function
    public static func refThreadsafeFunction(env: NapiEnv, fn__: NapiThreadsafeFunction): UInt32 {
        fn__.ref()
        return NapiStatus.ok.toInt()
    }

    // ========================================================================
    // 异步清理钩子 (NAPI_VERSION >= 8)
    // ========================================================================

    /// napi_add_async_cleanup_hook
    /// 对应 Bun: napi.zig - pub extern fn napi_add_async_cleanup_hook
    public static func addAsyncCleanupHook(env: NapiEnv, hook: NapiAsyncCleanupHook,
        arg: ?Any): NapiAsyncCleanupHookHandleHandle {
        return NapiAsyncCleanupHookHandleHandle()
    }

    /// napi_remove_async_cleanup_hook
    /// 对应 Bun: napi.zig - pub extern fn napi_remove_async_cleanup_hook
    public static func removeAsyncCleanupHook(handle: NapiAsyncCleanupHookHandleHandle): UInt32 {
        return NapiStatus.ok.toInt()
    }
}

// ============================================================================
// NapiFatalError - 致命错误异常
// ============================================================================

/// N-API 致命错误
/// 对应 Bun: napi.zig - pub export fn napi_fatal_error (noreturn)
public class NapiFatalError <: Exception {
    public init(message: String) {
        super(message)
    }
}

// ============================================================================
// NapiAsyncWork - 异步工作
// 对应 Bun: napi.zig - napi_async_work struct
// ============================================================================

/// NapiAsyncWorkStatus 定义在 napi_async_work.cj 中
/// NapiAsyncWork 定义在 napi_async_work.cj 中

// ============================================================================
// NapiThreadsafeFunction - 线程安全函数
// 对应 Bun: napi.zig - ThreadSafeFunction struct
// ============================================================================

/// NapiTsfnClosingState 定义在 threadsafe_function.cj 中
/// NapiTsfnDispatchState 定义在 threadsafe_function.cj 中

/// N-API 线程安全函数
/// 对应 Bun: napi.zig - ThreadSafeFunction struct
/// 允许从不同线程安全地调用 JS 函数
public class NapiThreadsafeFunction {
    /// N-API 环境
    public var env: NapiEnv
    /// 用户上下文
    public var ctx: ?Any = None
    /// 最大队列大小（0 = 无限制）
    public var maxQueueSize: Int64 = 0
    /// 线程引用计数
    public var threadCount: Int64 = 0
    /// 终结器函数
    public var finalizerFun: ?NapiFinalizeFn = None
    /// 终结器数据
    public var finalizerData: ?Any = None
    /// JS 调用回调
    public var callJsCb: ?NapiThreadsafeFunctionCallJs = None
    /// JS 函数引用
    public var callback: NapiValue
    /// 消息队列
    public var queue: ArrayList<?Any> = ArrayList<?Any>()
    /// 关闭状态
    public var closingState: NapiTsfnClosingState = NapiTsfnClosingState.NOT_CLOSING
    /// 是否已终止
    public var aborted: Bool = false
    /// 是否已排队终结器
    public var hasQueuedFinalizer: Bool = false
    /// 调度状态
    public var dispatchState: NapiTsfnDispatchState = NapiTsfnDispatchState.IDLE

    public init(env: NapiEnv) {
        this.env = env
        this.callback = NapiValue(JsValue.UNDEFINED)
    }

    public init() {
        this.env = NapiEnv(JsObject())
        this.callback = NapiValue(JsValue.UNDEFINED)
    }

    /// 是否正在关闭
    /// 对应 Bun: ThreadSafeFunction.isClosing
    public func isClosing(): Bool {
        match (this.closingState) {
            case NapiTsfnClosingState.NOT_CLOSING => return false
            case _ => return true
        }
    }

    /// 队列是否已满
    /// 对应 Bun: ThreadSafeFunction.Queue.isBlocked
    public func isQueueBlocked(): Bool {
        return this.maxQueueSize > 0 && this.queue.size >= this.maxQueueSize
    }

    /// 将数据入队
    /// 对应 Bun: ThreadSafeFunction.enqueue
    public func enqueue(data: ?Any, block: Bool): UInt32 {
        if (block) {
            // 阻塞等待直到队列有空间
            while (this.isQueueBlocked()) {
                // 等待
            }
        } else {
            if (this.isQueueBlocked()) {
                // 对应 Bun: 不设置 env 的错误（从其他线程调用）
                return NapiStatus.queueFull.toInt()
            }
        }

        if (this.isClosing()) {
            if (this.threadCount <= 0) {
                return NapiStatus.invalidArg.toInt()
            }
            this.release(NapiThreadsafeFunctionReleaseMode.napiTsfnRelease, true)
            return NapiStatus.closing.toInt()
        }

        this.queue.append(data)
        this.scheduleDispatch()
        return NapiStatus.ok.toInt()
    }

    /// 调度分发
    /// 对应 Bun: ThreadSafeFunction.scheduleDispatch
    public func scheduleDispatch(): Unit {
        match (this.dispatchState) {
            case IDLE =>
                this.dispatchState = NapiTsfnDispatchState.PENDING
                // 对应 Bun: this.event_loop.enqueueTaskConcurrent(...)
            case RUNNING =>
                // 会检查是否有更多工作
                ()
            case PENDING =>
                // 已经调度过了
                ()
        }
    }

    /// 分发处理
    /// 对应 Bun: ThreadSafeFunction.onDispatch
    public func onDispatch(): Unit {
        let isClosed: Bool = match (this.closingState) {
            case NapiTsfnClosingState.CLOSED => true
            case _ => false
        }
        if (isClosed) {
            this.deinit()
            return
        }

        var isFirst = true
        while (true) {
            this.dispatchState = NapiTsfnDispatchState.RUNNING
            if (this.dispatchOne(isFirst)) {
                isFirst = false
                this.dispatchState = NapiTsfnDispatchState.PENDING
            } else {
                this.dispatchState = NapiTsfnDispatchState.IDLE
                break
            }
        }
    }

    /// 分发单个任务
    /// 对应 Bun: ThreadSafeFunction.dispatchOne
    public func dispatchOne(isFirst: Bool): Bool {
        if (this.queue.size == 0) {
            if (this.threadCount == 0) {
                this.maybeQueueFinalizer()
            }
            return false
        }

        let task = this.queue.removeAt(0)

        this.call(task, !isFirst)

        return !this.isClosing()
    }

    /// 调用 JS 函数
    /// 对应 Bun: ThreadSafeFunction.call
    public func call(task: ?Any, isFirst: Bool): Unit {
        let env = this.env
        if (this.callJsCb.isSome()) {
            let jsCallback = this.callback
            this.callJsCb.getOrThrow()(env, jsCallback, this.ctx, task)
        } else {
            // 简化实现：直接调用 JS 函数
        }
    }

    /// 可能排队终结器
    /// 对应 Bun: ThreadSafeFunction.maybeQueueFinalizer
    public func maybeQueueFinalizer(): Unit {
        if (!this.hasQueuedFinalizer) {
            this.hasQueuedFinalizer = true
            this.closingState = NapiTsfnClosingState.CLOSED
        }
    }

    /// 释放
    /// 对应 Bun: ThreadSafeFunction.release
    public func release(mode: NapiThreadsafeFunctionReleaseMode, alreadyLocked: Bool): UInt32 {
        if (this.threadCount < 0) {
            return NapiStatus.invalidArg.toInt()
        }

        this.threadCount -= 1

        let isAbort: Bool = match (mode) {
            case NapiThreadsafeFunctionReleaseMode.napiTsfnAbort => true
            case _ => false
        }
        if (isAbort || this.threadCount == 1) {
            if (!this.isClosing()) {
                if (isAbort) {
                    this.closingState = NapiTsfnClosingState.CLOSING
                    this.aborted = true
                }
                this.scheduleDispatch()
            }
        }

        return NapiStatus.ok.toInt()
    }

    /// 获取
    /// 对应 Bun: ThreadSafeFunction.acquire
    public func acquire(): UInt32 {
        if (this.isClosing()) {
            return NapiStatus.closing.toInt()
        }
        this.threadCount += 1
        return NapiStatus.ok.toInt()
    }

    /// 引用（保持事件循环存活）
    /// 对应 Bun: ThreadSafeFunction.ref
    public func ref(): Unit {
        // 对应 Bun: this.poll_ref.refConcurrentlyFromEventLoop(...)
    }

    /// 取消引用
    /// 对应 Bun: ThreadSafeFunction.unref
    public func unref(): Unit {
        // 对应 Bun: this.poll_ref.unrefConcurrentlyFromEventLoop(...)
    }

    /// 清理
    /// 对应 Bun: ThreadSafeFunction.deinit
    public func deinit(): Unit {
        this.unref()
        if (this.finalizerFun.isSome()) {
            // 对应 Bun: finalizer.enqueue()
        }
    }
}

// ============================================================================
// Finalizer - 终结器
// 对应 Bun: napi.zig - Finalizer struct
// ============================================================================

/// N-API 终结器
/// 对应 Bun: napi.zig - Finalizer struct
/// 管理对象的终结回调
public class NapiFinalizer {
    /// N-API 环境
    public var env: NapiEnv
    /// 终结函数
    public var fun: NapiFinalizeFn
    /// 透传数据
    public var data: ?Any = None
    /// 提示
    public var hint: ?Any = None

    public init(env: NapiEnv, fun: NapiFinalizeFn) {
        this.env = env
        this.fun = fun
    }

    /// 运行终结器
    /// 对应 Bun: Finalizer.run
    public func run(): Unit {
        this.fun(this.env, this.data, this.hint)
    }

    /// 排队终结器
    /// 对应 Bun: Finalizer.enqueue
    public func enqueue(): Unit {
        // 对应 Bun: NapiFinalizerTask(this.*).schedule()
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// Buffer 信息
public class NapiBufferInfo {
    public var data: ?Array<Byte> = None
    public var byteLength: Int64 = 0

    public init() {}
}

/// 事件循环句柄（占位）
/// 对应 Bun: napi_event_loop (在 POSIX 上是 *jsc.EventLoop)
public class NapiEventLoopHandle {}

/// 内部注册函数
/// 对应 Bun: napi.zig - napi_internal_register_cleanup_zig
/// 注册环境清理回调
public func napiInternalRegisterCleanup(env: NapiEnv): Unit {
    // 对应 Bun: env.toJS().bunVM().rareData().pushCleanupHook(...)
}
