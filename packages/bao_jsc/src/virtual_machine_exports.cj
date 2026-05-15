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
    public static func isShuttingDown(vm: BunVirtualMachine) -> Bool {
        vm.isShuttingDown()
    }

    /// 获取当前线程的虚拟机实例
    /// 对应 Bun: Bun__getVM
    public static func getVM() -> BunVirtualMachine {
        BunVirtualMachine.get()
    }

    /// 排空微任务队列
    /// 调用者必须检查终止异常
    /// 对应 Bun: Bun__drainMicrotasks
    public static func drainMicrotasks() {
        BunVirtualMachine.get().eventLoop().tick()
    }

    /// 读取原始计时器值
    /// 对应 Bun: Bun__readOriginTimer
    public static func readOriginTimer(vm: BunVirtualMachine) -> UInt64 {
        // 检查 performance.now() 是否被覆盖（用于伪造计时器）
        if (let overridden = vm.overriddenPerformanceNow) {
            return overridden
        }
        return vm.originTimer.read()
    }

    /// 读取原始计时器起始时间（timespec 转换为毫秒）
    /// 对应 Bun: Bun__readOriginTimerStart
    public static func readOriginTimerStart(vm: BunVirtualMachine) -> Float64 {
        // timespec 转换为毫秒
        (Float64(vm.originTimestamp) + BunVirtualMachine.originRelativeEpoch) / 1000000.0
    }

    /// 检查全局对象是否已连接 IPC
    /// 对应 Bun: Bun__GlobalObject__connectedIPC
    public static func globalObjectConnectedIPC(global: JsObject) -> Bool {
        let vm = global.bunVM()
        if (let ipc = vm.ipc) {
            if (ipc.isInitialized()) {
                return ipc.initializedData.isConnected()
            }
            return true
        }
        return false
    }

    /// 检查全局对象是否有 IPC
    /// 对应 Bun: Bun__GlobalObject__hasIPC
    public static func globalObjectHasIPC(global: JsObject) -> Bool {
        let vm = global.bunVM()
        return vm.ipc != None
    }

    /// 在未捕获异常期间退出
    /// 对应 Bun: Bun__VirtualMachine__exitDuringUncaughtException
    public static func exitDuringUncaughtException(vm: BunVirtualMachine) {
        vm.exitOnUncaughtException = true
    }

    /// Process.send 的 JS 绑定
    /// 对应 Bun: Bun__Process__send_
    public static func processSend(globalObject: JsObject, callFrame: CallFrame) -> JsValue {
        let vm = globalObject.bunVM()
        return IPC.doSend(vm.getIPCInstance(), globalObject, callFrame, IPCSource.process)
    }

    /// 检查字符串是否为 Bun 主文件
    /// 对应 Bun: Bun__isBunMain
    public static func isBunMain(globalObject: JsObject, str: BunString) -> Bool {
        str.eqlUTF8(globalObject.bunVM().main)
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
        global.bunVM().eventLoop().enqueueTask(TaskInit.init(task))
    }

    /// 报告未处理的错误
    /// 对应 Bun: Bun__reportUnhandledError
    public static func reportUnhandledError(globalObject: JsObject, value: JsValue) -> JsValue {
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
        global.bunVMConcurrently().eventLoop().enqueueTaskConcurrent(
            ConcurrentTaskObj.create(TaskInit.init(task))
        )
    }

    /// 处理被拒绝的 Promise
    /// 对应 Bun: Bun__handleRejectedPromise
    public static func handleRejectedPromise(global: JsObject, promise: JsPromise) {
        let result = promise.result(global.vm())
        let jscVm = global.bunVM()

        // 这似乎在某些情况下当 GC 运行时发生
        if (result == JsValue.zero) {
            return
        }

        jscVm.unhandledRejection(global, result, promise.toJS())
        jscVm.autoGarbageCollect()
    }

    /// 处理已处理的 Promise
    /// 对应 Bun: Bun__handleHandledPromise
    public static func handleHandledPromise(global: JsObject, promise: JsPromise) {
        let promiseJs = promise.toJS()
        promiseJs.protect()
        let context = HandledPromiseContext(globalThis: global, promise: promiseJs)
        global.bunVM().eventLoop().enqueueTask(
            ManagedTaskNew.init(context, HandledPromiseContext.callback)
        )
    }

    /// 当追加插件时调用
    /// 对应 Bun: Bun__onDidAppendPlugin
    public static func onDidAppendPlugin(jscVm: BunVirtualMachine, globalObject: JsObject) {
        if (jscVm.pluginRunner != None) {
            return
        }

        jscVm.pluginRunner = PluginRunner(
            globalObject: globalObject,
            allocator: jscVm.allocator
        )
        jscVm.transpiler.linker.pluginRunner = jscVm.pluginRunner
    }

    /// 获取 libuv 事件循环（仅 Windows）
    /// 对应 Bun: Bun__ZigGlobalObject__uvLoop
    public static func zigGlobalObjectUvLoop(jscVm: BunVirtualMachine) -> UVLoop {
        jscVm.uvLoop()
    }

    /// 设置 TLS 拒绝未授权值
    /// 对应 Bun: Bun__setTLSRejectUnauthorizedValue
    public static func setTLSRejectUnauthorizedValue(value: Int32) {
        BunVirtualMachine.get().defaultTlsRejectUnauthorized = value != 0
    }

    /// 获取 TLS 拒绝未授权值
    /// 对应 Bun: Bun__getTLSRejectUnauthorizedValue
    public static func getTLSRejectUnauthorizedValue() -> Int32 {
        if (BunVirtualMachine.get().getTLSRejectUnauthorized()) { 1 } else { 0 }
    }

    /// 检查是否为无代理主机
    /// 对应 Bun: Bun__isNoProxy
    public static func isNoProxy(hostnamePtr: Array<Byte>, hostnameLen: Int64, hostPtr: Array<Byte>, hostLen: Int64) -> Bool {
        let vm = BunVirtualMachine.get()
        let hostname: ?Array<Byte> = if (hostnameLen > 0) { hostnamePtr[0..hostnameLen] } else { None }
        let host: ?Array<Byte> = if (hostLen > 0) { hostPtr[0..hostLen] } else { None }
        return vm.transpiler.env.isNoProxy(hostname, host)
    }

    /// 设置详细 Fetch 值
    /// 对应 Bun: Bun__setVerboseFetchValue
    public static func setVerboseFetchValue(value: Int32) {
        BunVirtualMachine.get().defaultVerboseFetch = if (value == 1) {
            VerboseFetchMode.headers
        } else if (value == 2) {
            VerboseFetchMode.curl
        } else {
            VerboseFetchMode.none
        }
    }

    /// 获取详细 Fetch 值
    /// 对应 Bun: Bun__getVerboseFetchValue
    public static func getVerboseFetchValue() -> Int32 {
        match (BunVirtualMachine.get().getVerboseFetch()) {
            case .none => 0
            case .headers => 1
            case .curl => 2
        }
    }

    /// 添加 Bake 源映射提供者
    /// 对应 Bun: Bun__addBakeSourceProviderSourceMap
    public static func addBakeSourceProviderSourceMap(vm: BunVirtualMachine, opaqueSourceProvider: UInt64, specifier: BunString) {
        let slice = specifier.toUTF8()
        vm.sourceMappings.putBakeSourceProvider(opaqueSourceProvider, slice.slice())
        slice.deinit()
    }

    /// 添加开发服务器源映射提供者
    /// 对应 Bun: Bun__addDevServerSourceProvider
    public static func addDevServerSourceProvider(vm: BunVirtualMachine, opaqueSourceProvider: UInt64, specifier: BunString) {
        let slice = specifier.toUTF8()
        vm.sourceMappings.putDevServerSourceProvider(opaqueSourceProvider, slice.slice())
        slice.deinit()
    }

    /// 移除开发服务器源映射提供者
    /// 对应 Bun: Bun__removeDevServerSourceProvider
    public static func removeDevServerSourceProvider(vm: BunVirtualMachine, opaqueSourceProvider: UInt64, specifier: BunString) {
        let slice = specifier.toUTF8()
        vm.sourceMappings.removeDevServerSourceProvider(opaqueSourceProvider, slice.slice())
        slice.deinit()
    }

    /// 添加源映射提供者
    /// 对应 Bun: Bun__addSourceProviderSourceMap
    public static func addSourceProviderSourceMap(vm: BunVirtualMachine, opaqueSourceProvider: UInt64, specifier: BunString) {
        let slice = specifier.toUTF8()
        vm.sourceMappings.putZigSourceProvider(opaqueSourceProvider, slice.slice())
        slice.deinit()
    }

    /// 移除源映射提供者
    /// 对应 Bun: Bun__removeSourceProviderSourceMap
    public static func removeSourceProviderSourceMap(vm: BunVirtualMachine, opaqueSourceProvider: UInt64, specifier: BunString) {
        let slice = specifier.toUTF8()
        vm.sourceMappings.removeZigSourceProvider(opaqueSourceProvider, slice.slice())
        slice.deinit()
    }

    /// 设置合成分配限制（仅用于测试）
    /// 对应 Bun: Bun__setSyntheticAllocationLimitForTesting
    public static func setSyntheticAllocationLimitForTesting(globalObject: JsObject, callFrame: CallFrame) -> JsValue {
        let args = callFrame.argumentsOld(1).slice()
        if (args.length < 1) {
            return globalObject.throwNotEnoughArguments("setSyntheticAllocationLimitForTesting", 1, args.length)
        }

        if (!args[0].isNumber()) {
            return globalObject.throwInvalidArguments("setSyntheticAllocationLimitForTesting expects a number")
        }

        let limit: Int64 = Int64(Math.max(args[0].coerceToInt64(globalObject), 1024 * 1024))
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
        context.promise.unprotect()
    }
}

// ============================================================================
// 支撑类型
// ============================================================================

public class BunVirtualMachine {
    public static var syntheticAllocationLimit: Int64 = 0
    public static var stringAllocationLimit: Int64 = 0
    public static let originRelativeEpoch: Float64 = 0.0

    public var exitOnUncaughtException: Bool = false
    public var overriddenPerformanceNow: ?UInt64 = None
    public var originTimer: OriginTimer = OriginTimer()
    public var originTimestamp: Int64 = 0
    public var ipc: ?IPCInstance = None
    public var pluginRunner: ?PluginRunner = None
    public var defaultTlsRejectUnauthorized: Bool = true
    public var defaultVerboseFetch: VerboseFetchMode = VerboseFetchMode.none
    public var transpiler: Transpiler = Transpiler()
    public var allocator: BunAllocator = BunAllocator()
    public var sourceMappings: SourceMappings = SourceMappings()
    public var main: String = ""

    public init() {}

    /// 获取当前线程的虚拟机实例
    /// 对应 Bun: jsc.VirtualMachine.get()
    public static func get() -> BunVirtualMachine {
        BunVirtualMachine()
    }

    public func isShuttingDown() -> Bool { false }
    public func eventLoop() -> EventLoop { EventLoop() }
    public func bunVM() -> BunVirtualMachine { this }
    public func bunVMConcurrently() -> BunVirtualMachine { this }
    public func getIPCInstance() -> ?IPCInstance { ipc }
    public func uncaughtException(_ global: JsObject, _ value: JsValue, _ isUncaught: Bool) -> JsValue { JsValue.zero }
    public func unhandledRejection(_ global: JsObject, _ value: JsValue, _ promise: JsValue) {}
    public func handledPromise(_ global: JsObject, _ promise: JsValue) -> JsValue { JsValue.zero }
    public func autoGarbageCollect() {}
    public func uvLoop() -> UVLoop { UVLoop() }
    public func getTLSRejectUnauthorized() -> Bool { defaultTlsRejectUnauthorized }
    public func getVerboseFetch() -> VerboseFetchMode { defaultVerboseFetch }
}

public class OriginTimer {
    public func read() -> UInt64 { 0 }
}

public class IPCInstance {
    public func isInitialized() -> Bool { false }
    public var initializedData: IPCData = IPCData()
}

public class IPCData {
    public func isConnected() -> Bool { false }
}

public class IPC {
    public static func doSend(_ ipc: ?IPCInstance, _ globalObject: JsObject, _ callFrame: CallFrame, _ source: IPCSource) -> JsValue { JsValue.zero }
}

public enum IPCSource {
    case process
}

public class BunString {
    public func eqlUTF8(_ other: String) -> Bool { false }
    public func toUTF8() -> UTF8Slice { UTF8Slice() }
}

public class UTF8Slice {
    public func slice() -> String { "" }
    public func deinit() {}
}

public class CppTask {}

public class TaskInit {
    public static func initFunc(_ task: CppTask) -> Task { Task() }
}

public class Task {}

public class ConcurrentTaskObj {
    public static func create(_ task: Task) -> ConcurrentTaskObj { ConcurrentTaskObj() }
}

public class JsPromise {
    public func result(_ vm: JsVM) -> JsValue { JsValue.zero }
    public func toJS() -> JsValue { JsValue.zero }
}

public class JsVM {}

public class PluginRunner {
    public var globalObject: JsObject
    public var allocator: BunAllocator

    public init(globalObject: JsObject, allocator: BunAllocator) {
        this.globalObject = globalObject
        this.allocator = allocator
    }
}

public class Transpiler {
    public var linker: Linker = Linker()
    public var env: TranspilerEnv = TranspilerEnv()
    public var fs: FileSystem = FileSystem()
}

public class Linker {
    public var pluginRunner: ?PluginRunner = None
}

public class TranspilerEnv {
    public func isNoProxy(_ hostname: ?Array<Byte>, _ host: ?Array<Byte>) -> Bool { false }
}

public class FileSystem {}

public class BunAllocator {}

public class SourceMappings {
    public func putBakeSourceProvider(_ provider: UInt64, _ slice: String) {}
    public func putDevServerSourceProvider(_ provider: UInt64, _ slice: String) {}
    public func removeDevServerSourceProvider(_ provider: UInt64, _ slice: String) {}
    public func putZigSourceProvider(_ provider: UInt64, _ slice: String) {}
    public func removeZigSourceProvider(_ provider: UInt64, _ slice: String) {}
}

public class UVLoop {}

public enum VerboseFetchMode {
    case none
    case headers
    case curl
}

public class ManagedTaskNew {
    public static func initFunc(_ context: HandledPromiseContext, _ callback: (HandledPromiseContext) -> Void) -> Task { Task() }
}

public class Math {
    public static func max(_ a: Int64, _ b: Int64) -> Int64 { if (a > b) { a } else { b } }
}

public class EventLoop {
    public func tick() {}
    public func enqueueTask(_ task: Task) {}
    public func enqueueTaskConcurrent(_ task: ConcurrentTaskObj) {}
}
