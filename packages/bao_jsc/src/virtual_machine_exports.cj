// 严格翻译自: src/jsc/virtual_machine_exports.zig
// 虚拟机导出函数 - 可从 C++ 代码调用的 VM 生命周期与任务管理函数

package bao_jsc

// ============================================================================
// VirtualMachineExports - 虚拟机导出函数
// 严格翻译自 virtual_machine_exports 命名空间
// 这些函数是从 C++ 调用的，用于管理 VM 的生命周期、IPC、任务调度等
// ============================================================================
public class VirtualMachineExports {

    /// 检查虚拟机是否正在关闭
    /// 对应 Bun: Bun__VirtualMachine__isShuttingDown
    public static func isShuttingDown(vm: BunVirtualMachine): Bool {
        vm.isShuttingDown()
    }

    /// 获取当前线程的虚拟机实例
    /// 对应 Bun: Bun__getVM
    public static func getVM(): BunVirtualMachine {
        BunVirtualMachine.get()
    }

    /// 排空微任务队列
    /// 调用者必须检查终止异常
    /// 对应 Bun: Bun__drainMicrotasks
    public static func drainMicrotasks() {
        BunVirtualMachine.get().eventLoop_().tick()
    }

    /// 读取原始计时器值
    /// 对应 Bun: Bun__readOriginTimer
    public static func readOriginTimer(vm: BunVirtualMachine): UInt64 {
        match (vm.overriddenPerformanceNow) {
            case Some(overridden) => return UInt64(overridden)
            case None => return UInt64(vm.originTimer)
        }
    }

    /// 读取原始计时器起始时间（timespec 转换为毫秒）
    /// 对应 Bun: Bun__readOriginTimerStart
    public static func readOriginTimerStart(vm: BunVirtualMachine): Float64 {
        // timespec 转换为毫秒
        Float64(vm.originTimestamp) / 1000000.0
    }

    /// 检查全局对象是否已连接 IPC
    /// 对应 Bun: Bun__GlobalObject__connectedIPC
    public static func globalObjectConnectedIPC(global: JsObject): Bool {
        let vm = global.bunVM()
        match (vm.ipc) {
            case Some(ipc) => return ipcIsConnected(ipc)
            case None => return false
        }
    }

    private static func ipcIsConnected(ipc: IPCInstanceUnion): Bool {
        match (ipc) {
            case IPCInstanceUnion.Initialized(inst) => return true
            case IPCInstanceUnion.Waiting(_) => return false
        }
    }

    /// 检查全局对象是否有 IPC
    /// 对应 Bun: Bun__GlobalObject__hasIPC
    public static func globalObjectHasIPC(global: JsObject): Bool {
        let vm = global.bunVM()
        return vm.ipc.isSome()
    }

    /// 在未捕获异常期间退出
    /// 对应 Bun: Bun__VirtualMachine__exitDuringUncaughtException
    public static func exitDuringUncaughtException(vm: BunVirtualMachine) {
        vm.exitOnUncaughtException = true
    }

    /// Process.send 的 JS 绑定
    /// 对应 Bun: Bun__Process__send_
    public static func processSend(globalObject: JsObject, callFrame: CallFrame): JsValue {
        let vm = globalObject.bunVM()
        return IPC.doSend(vm.getIPCInstance(), globalObject, callFrame, IPCSource.process)
    }

    /// 检查字符串是否为 Bun 主文件
    /// 对应 Bun: Bun__isBunMain
    public static func isBunMain(globalObject: JsObject, str: BunString): Bool {
        // BunString 尚未完整实现，暂时返回 false
        // 完整实现需要: str.toString() == globalObject.bunVM().main
        false
    }

    /// 确保进程 IPC 已初始化
    /// 当传递 IPC 环境变量时，socket 不会立即打开，
    /// 而是等待 process.on('message') 或 process.send() 被调用，然后再打开 socket。
    /// 这是为了避免在程序开始时丢失消息。
    /// 对应 Bun: Bun__ensureProcessIPCInitialized
    public static func ensureProcessIPCInitialized(globalObject: JsObject) {
        // getIPC() 将初始化一个 "waiting" IPC 实例，所以这就够了。
        // 如果 IPC 未启用，则什么都不做。
        let _ = globalObject.bunVM().getIPCInstance()
    }

    /// 在主线程上将任务入队
    /// 此函数在主线程上调用。bunVM() 调用会断言这一点。
    /// 对应 Bun: Bun__queueTask
    public static func queueTask(global: JsObject, task: CppTask) {
        global.bunVM().eventLoop_().enqueueTask(TaskInit.initFunc(task))
    }

    /// 报告未处理的错误
    /// 对应 Bun: Bun__reportUnhandledError
    public static func reportUnhandledError(globalObject: JsObject, value: JsValue): JsValue {
        if (!value.isTerminationException()) {
            let _ = globalObject.bunVM().uncaughtException(globalObject, value, false)
        }
        return JsValue.jsUndefined()
    }

    /// 在另一个线程上将任务入队
    /// 主要区别：我们需要分配任务并唤醒线程
    /// 如果从主线程运行则可以避免这些操作。
    /// 对应 Bun: Bun__queueTaskConcurrently
    public static func queueTaskConcurrently(global: JsObject, task: CppTask) {
        global.bunVMConcurrently().eventLoop_().enqueueTaskConcurrent(
            ConcurrentTaskObj.create(TaskInit.initFunc(task))
        )
    }

    /// 处理被拒绝的 Promise
    /// 对应 Bun: Bun__handleRejectedPromise
    public static func handleRejectedPromise(global: JsObject, promise: JsPromise) {
        let result = promise.result
        let jscVm = global.bunVM()

        // 这似乎在某些情况下当 GC 运行时发生
        if (result == JsValue()) {
            return
        }

        jscVm.unhandledRejection(global, result, JsValue.undefined())
        jscVm.autoGarbageCollect()
    }

    /// 处理已处理的 Promise
    /// 对应 Bun: Bun__handleHandledPromise
    public static func handleHandledPromise(global: JsObject, promise: JsPromise) {
        let promiseJs = JsValue.undefined() // TODO: wrap promise as JsValue
        // TODO: promiseJs.protect()
        let context = HandledPromiseContext(global, promiseJs)
        global.bunVM().eventLoop_().enqueueTask(
            ManagedTaskNew.initFunc(context, HandledPromiseContext.callback)
        )
    }

    /// 当追加插件时调用
    /// 对应 Bun: Bun__onDidAppendPlugin
    public static func onDidAppendPlugin(jscVm: BunVirtualMachine, globalObject: JsObject) {
        if (jscVm.pluginRunner .isSome()) {
            return
        }

        jscVm.pluginRunner = PluginRunner()
        // TODO: jscVm.transpiler.linker.pluginRunner = jscVm.pluginRunner.getOrThrow()
    }

    /// 获取 libuv 事件循环（仅 Windows）
    /// 对应 Bun: Bun__ZigGlobalObject__uvLoop
    public static func zigGlobalObjectUvLoop(jscVm: BunVirtualMachine): UVLoop {
        UVLoop() // TODO: jscVm.uvLoop() returns EventLoopHandle, not UVLoop
    }

    /// 设置 TLS 拒绝未授权值
    /// 对应 Bun: Bun__setTLSRejectUnauthorizedValue
    public static func setTLSRejectUnauthorizedValue(value: Int32) {
        BunVirtualMachine.get().defaultTlsRejectUnauthorized = if (value != 0) { true } else { false }
    }

    /// 获取 TLS 拒绝未授权值
    /// 对应 Bun: Bun__getTLSRejectUnauthorizedValue
    public static func getTLSRejectUnauthorizedValue(): Int32 {
        if (BunVirtualMachine.get().getTLSRejectUnauthorized()) { 1 } else { 0 }
    }

    /// 检查是否为无代理主机
    /// 对应 Bun: Bun__isNoProxy
    public static func isNoProxy(hostnamePtr: Array<Byte>, hostnameLen: Int64, hostPtr: Array<Byte>, hostLen: Int64): Bool {
        let vm = BunVirtualMachine.get()
        let hostname: ?Array<Byte> = if (hostnameLen > 0) { hostnamePtr[0..hostnameLen] } else { None }
        let host: ?Array<Byte> = if (hostLen > 0) { hostPtr[0..hostLen] } else { None }
        return false // TODO: vm.transpiler.env.isNoProxy(hostname, host)
    }

    /// 设置详细 Fetch 值
    /// 对应 Bun: Bun__setVerboseFetchValue
    public static func setVerboseFetchValue(value: Int32) {
        BunVirtualMachine.get().defaultVerboseFetch = if (value == 1) {
            1
        } else if (value == 2) {
            2
        } else {
            0
        }
    }

    /// 获取详细 Fetch 值
    /// 对应 Bun: Bun__getVerboseFetchValue
    public static func getVerboseFetchValue(): Int32 {
        Int32(BunVirtualMachine.get().getVerboseFetch())
    }

    /// 添加 Bake 源映射提供者
    /// 对应 Bun: Bun__addBakeSourceProviderSourceMap
    public static func addBakeSourceProviderSourceMap(vm: BunVirtualMachine, opaqueSourceProvider: UInt64, specifier: BunString) {
        vm.sourceMappings.putBakeSourceProvider(opaqueSourceProvider, "")
    }

    /// 添加开发服务器源映射提供者
    /// 对应 Bun: Bun__addDevServerSourceProvider
    public static func addDevServerSourceProvider(vm: BunVirtualMachine, opaqueSourceProvider: UInt64, specifier: BunString) {
        vm.sourceMappings.putDevServerSourceProvider(opaqueSourceProvider, "")
    }

    /// 移除开发服务器源映射提供者
    /// 对应 Bun: Bun__removeDevServerSourceProvider
    public static func removeDevServerSourceProvider(vm: BunVirtualMachine, opaqueSourceProvider: UInt64, specifier: BunString) {
        vm.sourceMappings.removeDevServerSourceProvider(opaqueSourceProvider, "")
    }

    /// 添加源映射提供者
    /// 对应 Bun: Bun__addSourceProviderSourceMap
    public static func addSourceProviderSourceMap(vm: BunVirtualMachine, opaqueSourceProvider: UInt64, specifier: BunString) {
        vm.sourceMappings.putZigSourceProvider(opaqueSourceProvider, "")
    }

    /// 移除源映射提供者
    /// 对应 Bun: Bun__removeSourceProviderSourceMap
    public static func removeSourceProviderSourceMap(vm: BunVirtualMachine, opaqueSourceProvider: UInt64, specifier: BunString) {
        vm.sourceMappings.removeZigSourceProvider(opaqueSourceProvider, "")
    }

    /// 设置合成分配限制（仅用于测试）
    /// 对应 Bun: Bun__setSyntheticAllocationLimitForTesting
    public static func setSyntheticAllocationLimitForTesting(globalObject: JsObject, callFrame: CallFrame): JsValue {
        let args = callFrame.argumentsOld(1).slice()
        if (args.size < 1) {
            return globalObject.throwNotEnoughArguments("setSyntheticAllocationLimitForTesting", 1, Int64(args.size))
        }

        if (!args[0].isNumber()) {
            return globalObject.throwInvalidArguments("setSyntheticAllocationLimitForTesting expects a number")
        }

        let limit: Int64 = Int64(Math.max(args[0].toInt64(), 1024 * 1024))
        let prev = BunVirtualMachine.syntheticAllocationLimit
        BunVirtualMachine.syntheticAllocationLimit = limit
        BunVirtualMachine.stringAllocationLimit = limit
        return JsValue.jsNumber(prev)
    }
}

// ============================================================================
// HandledPromiseContext - 已处理 Promise 的上下文
// 严格翻译自 Bun__handleHandledPromise 中的 Context struct
// ============================================================================
public class HandledPromiseContext {
    public var globalThis: JsObject
    public var promise: JsValue

    public init(globalThis: JsObject, promise: JsValue) {
        this.globalThis = globalThis
        this.promise = promise
    }

    /// 回调函数
    /// 对应 Bun: Context.callback
    public static func callback(context: HandledPromiseContext) {
        let _ = context.globalThis.bunVM().handledPromise(context.globalThis, context.promise)
        // 通过 JSC C API 取消保护 promise 值
        context.promise.unprotect()
    }
}

// ============================================================================
// 支撑类型
// ============================================================================

// 注意: BunVirtualMachine 已移至 virtual_machine.cj

public class OriginTimer {
    public func read(): UInt64 { 0 }
}

// 注意: IPCInstance 已移至 virtual_machine.cj

public class IPCData {
    public func isConnected(): Bool { false }
}

public class IPC {
    public static func doSend(ipc: ?IPCInstance, globalObject: JsObject, callFrame: CallFrame, source: IPCSource): JsValue { JsValue() }
}

public enum IPCSource {
    | process
}

// 注意: BunString 已移至 bun_string_jsc.cj

public class UTF8Slice {
    public func slice(): String { "" }
    public func deinit() {}
}

// 注意: CppTask 已移至 cpp_task.cj

public class TaskInit {
    public static func initFunc(task: CppTask): Task { Task() }
}

// 注意: Task 已移至 task.cj

public class ConcurrentTaskObj {
    public static func create(task: Task): ConcurrentTaskObj { ConcurrentTaskObj() }
}

// 注意: JsPromise 已移至 js_promise.cj

public class JsVM {}

// 注意: PluginRunner 已移至 plugin_runner.cj
// 注意: Transpiler 已移至 virtual_machine.cj
// 注意: TranspilerEnv 已移至 virtual_machine.cj
// 注意: FileSystem 已移至 hot_reloader.cj

public class BunAllocator {}

public class SourceMappings {
    public func putBakeSourceProvider(provider: UInt64, slice: String) {}
    public func putDevServerSourceProvider(provider: UInt64, slice: String) {}
    public func removeDevServerSourceProvider(provider: UInt64, slice: String) {}
    public func putZigSourceProvider(provider: UInt64, slice: String) {}
    public func removeZigSourceProvider(provider: UInt64, slice: String) {}
}

public class UVLoop {}

public enum VerboseFetchMode {
    | none
    | headers
    | curl
}

public class ManagedTaskNew {
    public static func initFunc(context: HandledPromiseContext, callback: (HandledPromiseContext) -> Unit): Task { Task() }
}

public class Math {
    public static func max(a: Int64, b: Int64): Int64 { if (a > b) { a } else { b } }
    public static func min(a: Int64, b: Int64): Int64 { if (a < b) { a } else { b } }
    public static func floor(v: Float64): Int64 { Int64(v) }
    public static func ceil(v: Float64): Int64 { Int64(v + 1.0) }
}

// 注意: EventLoop 已移至 event_loop.cj
