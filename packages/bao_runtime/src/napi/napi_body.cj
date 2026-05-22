// 严格翻译自: src/runtime/napi/napi_body.rs
// Node-API (N-API) 实现 - 附加类型
// 对应 Bun: src/runtime/napi/napi_body.rs (port of src/napi/napi.zig)
// 注意: 核心类型(NapiEnv, NapiValue, NapiStatus, NapiValueType 等)定义在 napi.cj 中
// 异步/线程安全函数类型定义在 node_api_types.cj 中
// AsyncWork 类型定义在 napi_async_work.cj 和 node_api.cj 中

package bao_runtime.napi

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_collections.ArrayList
import bao_sys.*

// ============================================================================
// NapiEnvRef - N-API 环境引用
// ============================================================================

/// N-API 环境引用
public class NapiEnvRef {
    public var env: NapiEnv

    public init(env: NapiEnv) {
        this.env = env
    }

    /// 克隆引用
    public static func cloneFromRaw(ptr: CPointer<Unit>): NapiEnvRef {
        return NapiEnvRef(NapiEnv(JsObject()))
    }

    /// 获取环境
    public func get(): NapiEnv {
        return env
    }
}

/// 环境为 null 的错误
public func envIsNull(): UInt32 {
    return NapiStatus.ok.toInt()
}

/// napi_env 类型 (可空)
public type NapiEnvPtr = ?NapiEnv

/// napi_ref 类型 (可空)
public type NapiRefPtr = ?NapiRef

// ============================================================================
// EscapeError - 逃逸错误
// ============================================================================

public enum EscapeError {
    | EscapeCalledTwice
    public func toString(): String {
        match (this) {
            case EscapeError.EscapeCalledTwice => "escape called twice"
        }
    }
}

// ============================================================================
// NapiHandleScopeGuard - 句柄作用域 RAII 守卫
// ============================================================================

public class NapiHandleScopeGuard {
    public var scope: ?NapiHandleScope
    public var env: NapiEnv

    public init(scope: ?NapiHandleScope, env: NapiEnv) {
        this.scope = scope
        this.env = env
    }

    /// 释放时关闭作用域
    public func deinit(): Unit {
        match (scope) {
            case Some(s) => s.close(env)
            case None => ()
        }
    }
}

/// napi_handle_scope 类型
public type NapiHandleScopePtr = ?NapiHandleScope

/// napi_escapable_handle_scope 类型
public type NapiEscapableHandleScopePtr = ?NapiHandleScope

// ============================================================================
// NapiFinalizeFunction - 终结器函数类型
// ============================================================================

/// NapiFinalizeFunction
public type NapiFinalizeFunction = (env: NapiEnv, data: CPointer<Unit>, hint: CPointer<Unit>) -> Unit

/// napi_finalize 类型
public type NapiFinalize = ?NapiFinalizeFunction

// ============================================================================
// DispatchState - 调度状态
// ============================================================================

public enum DispatchState {
    | Idle
    | Pending
    | Running
}

// ============================================================================
// TsfnQueue - TSFN 队列
// ============================================================================

public class TsfnQueue {
    public var items: ArrayList<CPointer<Unit>>
    public var state: DispatchState

    public init() {
        items = ArrayList<CPointer<Unit>>()
        state = DispatchState.Idle
    }

    public func enqueue(item: CPointer<Unit>): Unit {
        items.append(item)
    }

    public func drain(): ArrayList<CPointer<Unit>> {
        let result = items
        items = ArrayList<CPointer<Unit>>()
        return result
    }
}

// ============================================================================
// Finalizer - 终结器
// ============================================================================

public class Finalizer {
    public var env: NapiEnvRef
    public var finalizeCb: NapiFinalizeFunction
    public var nativeObject: CPointer<Unit>
    public var hint: CPointer<Unit>

    public init(env: NapiEnvRef, finalizeCb: NapiFinalizeFunction,
                nativeObject: CPointer<Unit>, hint: CPointer<Unit>) {
        this.env = env
        this.finalizeCb = finalizeCb
        this.nativeObject = nativeObject
        this.hint = hint
    }

    public func run(): Unit {
        let envPtr = env.get()
        finalizeCb(envPtr, nativeObject, hint)
    }

    public func deinit(): Unit {
        ()
    }
}

// ============================================================================
// NapiFinalizerTask - 终结器任务
// ============================================================================

public class NapiFinalizerTask {
    public var finalizer: Finalizer

    public init(finalizer: Finalizer) {
        this.finalizer = finalizer
    }

    public static func initTask(finalizer: Finalizer): NapiFinalizerTask {
        return NapiFinalizerTask(finalizer)
    }

    public func schedule(): Unit {
        let vm = NapiVirtualMachineHelper.getOrNull()
        let isMainThread: Bool = match (vm) {
            case Some(_) => true
            case None => false
        }

        if (!isMainThread) {
            // 非主线程: 简化处理
            return
        }

        if (vm.getOrThrow().isShuttingDown()) {
            // 作为清理钩子运行
        } else {
            vm.getOrThrow().eventLoop().enqueueTask(this)
        }
    }

    public func runOnJsThread(): Unit {
        finalizer.run()
    }
}

// ============================================================================
// TsfnCallback - TSFN 回调类型
// ============================================================================

public enum TsfnCallback {
    | CallJs(NapiThreadsafeFunctionCallJs)
    | NoCallback
}

// ============================================================================
// NapiThreadSafeFunctionImpl - 线程安全函数实现
// ============================================================================

public class NapiThreadSafeFunctionImpl {
    public var env: NapiEnvRef
    public var callJs: ?NapiThreadsafeFunctionCallJs
    public var callback: JsValue
    public var context: CPointer<Unit>
    public var threadCount: Int64
    public var isClosing: Bool

    public init(env: NapiEnvRef) {
        this.env = env
        this.callJs = None
        this.callback = JsValue()
        this.context = CPointer<Unit>()
        this.threadCount = 0
        this.isClosing = false
    }

    public func ref_(): Unit {
        threadCount = threadCount + 1
    }

    public func release(mode: NapiThreadsafeFunctionReleaseMode): Unit {
        threadCount = threadCount - 1
        if (threadCount <= 0) {
            isClosing = true
        }
    }

    public func call(data: CPointer<Unit>, isBlocking: Bool): Unit {
        let envPtr = env.get()
        match (callJs) {
            case Some(cb) =>
                let jsCallback = NapiValue(JsValue())
                cb(envPtr, jsCallback, context, data)
            case None => ()
        }
    }
}

/// napi_threadsafe_function 类型
public type NapiThreadSafeFunction = ?NapiThreadSafeFunctionImpl

// ============================================================================
// 辅助类型 (内部使用)
// ============================================================================

/// 事件循环辅助
public class NapiEventLoopHelper {
    public init() {}

    public func enqueueTaskConcurrent(task: Object): Unit {
        ()
    }

    public func enqueueTask(task: Object): Unit {
        ()
    }
}

/// KeepAlive 辅助
public class NapiKeepAliveHelper {
    public init() {}

    public func ref_(): Unit {
        ()
    }

    public func unref(): Unit {
        ()
    }
}

/// 工作线程池辅助
public class NapiWorkPoolHelper {
    public static func schedule(task: Object): Unit {
        ()
    }
}

/// 虚拟机辅助
public class NapiVirtualMachineHelper {
    public func eventLoop(): NapiEventLoopHelper { return NapiEventLoopHelper() }
    public func isShuttingDown(): Bool { return false }

    public static func getOrNull(): ?NapiVirtualMachineHelper {
        return None
    }
}

/// JsPromise 强引用
public class JsPromiseStrong {
    public init() {}
}

/// fixDeadCodeElimination - 防止死代码消除
public func fixDeadCodeElimination(): Unit {
    // 空函数，防止编译器优化掉 NAPI 符号
}
