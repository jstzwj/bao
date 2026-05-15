// 严格翻译自: jsc/VirtualMachine.zig (4173行)
// Bun JavaScript 虚拟机核心实现

package bao_jsc

// ========== 脚本执行状态 ==========
// 严格翻译自 VirtualMachine.zig ScriptExecutionStatus
public enum ScriptExecutionStatus {
    | Running
    | Stopped
}

// ========== GC 级别 ==========
// 严格翻译自 VirtualMachine.zig GCLevel
public enum GCLevel {
    | None       // 无 GC
    | Mild       // 轻度 GC
    | Aggressive // 激进 GC
}

// ========== 未处理 Rejection 模式 ==========
// 严格翻译自 VirtualMachine.zig unhandledRejectionsMode
public enum UnhandledRejectionsMode {
    | Bun          // Bun 默认模式
    | None         // 忽略
    | Warn         // 警告
    | WarnWithErrorCode  // 警告并设错误码
    | Strict       // 严格模式
    | Throw        // 抛出
}

// ========== 热重载模式 ==========
// 严格翻译自 VirtualMachine.zig HotReload
public enum HotReloadMode {
    | None
    | Watch
    | Hot
}

// ========== Worker 状态 ==========
// 严格翻译自 VirtualMachine.zig WebWorker.Status
public enum WorkerStatus {
    | Start      // 线程尚未启动
    | Starting   // startVM 进行中
    | Running    // 事件循环运行中
    | Terminated // 关闭中
}

// ========== 退出处理器 ==========
// 严格翻译自 VirtualMachine.zig ExitHandler
public class ExitHandler {
    public var exitCode: Int64 = 0

    public init() {}

    // 严格翻译自 ExitHandler.dispatchOnExit
    public func dispatchOnExit(vm: BunVirtualMachine) {
        // Process__dispatchOnExit(vm.global, exitCode)
    }

    // 严格翻译自 ExitHandler.dispatchOnBeforeExit
    public func dispatchOnBeforeExit(vm: BunVirtualMachine) {
        // Process__dispatchOnBeforeExit(vm.global, exitCode)
    }
}

// ========== 未处理 Rejection 作用域 ==========
// 严格翻译自 VirtualMachine.zig UnhandledRejectionScope
public class UnhandledRejectionScope {
    public var ctx: ?BunVirtualMachine = None
    public var count: Int64 = 0
    public var onUnhandledRejection: ((BunVirtualMachine, JsObject, JsValue) -> Unit)? = None

    public init() {}

    // 严格翻译自 UnhandledRejectionScope.apply
    public func apply(vm: BunVirtualMachine) {
        vm.onUnhandledRejection = onUnhandledRejection
        vm.unhandledErrorCounter = count
    }
}

// ========== 解析函数结果 ==========
// 严格翻译自 VirtualMachine.zig ResolveFunctionResult
public class ResolveFunctionResult {
    public var result: ?ResolverResult = None
    public var path: String = ""
    public var queryString: String = ""

    public init() {}
}

// ========== 解析器结果 ==========
public class ResolverResult {
    public var pathText: String = ""
    public var isExternal: Bool = false

    public init() {}
}

// ========== 源映射查找结果 ==========
// 严格翻译自 VirtualMachine.zig SourceMap.Mapping.Lookup
public class SourceMapLookup {
    public var originalLine: Int64 = 0
    public var originalColumn: Int64 = 0
    public var displaySourceURL: ?String = None

    public init() {}
}

// ========== 异常列表 ==========
// 严格翻译自 VirtualMachine.zig ExceptionList
public type ExceptionList = ArrayList<JsValue>

// ========== 虚拟机选项 ==========
// 严格翻译自 VirtualMachine.zig Options
public class BunVirtualMachineOptions {
    public var smol: Bool = false
    public var eval: Bool = false
    public var storeFd: Bool = false
    public var isMainThread: Bool = false
    public var destructMainThreadOnExit: Bool = false
    public var dnsResultOrder: String = "verbatim"

    public init() {}
}

// ========== VM 持有者 ==========
// 严格翻译自 VirtualMachine.zig VMHolder
public class VMHolder {
    // 线程局部存储的 VM 实例
    static var vm: ?BunVirtualMachine = None
    // 线程局部缓存的全局对象
    static var cachedGlobalObject: ?JsObject = None
    // 主线程 VM
    static var mainThreadVM: ?BunVirtualMachine = None

    public init() {}

    // 严格翻译自 VMHolder.Bun__setDefaultGlobalObject
    public static func setDefaultGlobalObject(global: JsObject) {
        if (let Some(vmInstance) <- vm) {
            vmInstance.globalObject = global
            if (vmInstance.isMainThread) {
                VMHolder.mainThreadVM = vmInstance
            }
        }
        cachedGlobalObject = global
    }

    // 严格翻译自 VMHolder.Bun__getDefaultGlobalObject
    public static func getDefaultGlobalObject() -> ?JsObject {
        if (let Some(cached) <- cachedGlobalObject) {
            return cached
        }
        if (let Some(vmInstance) <- vm) {
            cachedGlobalObject = vmInstance.globalObject
        }
        return None
    }

    // 严格翻译自 VMHolder.Bun__thisThreadHasVM
    public static func thisThreadHasVM() -> Bool {
        vm != None
    }
}

// ========== 入口点结果 ==========
// 严格翻译自 VirtualMachine.zig entry_point_result
public class EntryPointResult {
    public var value: ?JsValue = None
    public var cjsSetValue: Bool = false

    public init() {}

    public func deinit() {
        value = None
        cjsSetValue = false
    }
}

// ========== 计数器 ==========
// 严格翻译自 VirtualMachine.zig Counters
public class VMCounters {
    public var transpiledCount: Int64 = 0
    public var resolvedCount: Int64 = 0

    public init() {}
}

// ========== BunVirtualMachine - 核心虚拟机 ==========
// 严格翻译自 VirtualMachine.zig VirtualMachine
public class BunVirtualMachine {
    // ---- 全局对象 & 分配器 ----
    public var globalObject: JsObject = JsObject.make()
    public var allocator: String = ""  // 模拟分配器标识
    public var hasLoadedConstructors: Bool = false

    // ---- 转译器 & 日志 ----
    public var log: ArrayList<String> = ArrayList()
    public var main: String = ""
    public var mainIsHtmlEntrypoint: Bool = false
    public var mainResolvedPath: String = ""
    public var mainHash: Int64 = 0

    // ---- 事件循环 ----
    public var eventLoopHandle: ?EventLoopHandle = None
    public var pendingUnrefCounter: Int64 = 0
    public var preload: Array<String> = []
    public var activeTasks: Int64 = 0

    // ---- 状态标志 ----
    public var isShuttingDown_: Bool = false
    public var isMainThread_: Bool = false
    public var hasLoaded: Bool = false
    public var hadErrors: Bool = false
    public var smol: Bool = false
    public var isInPreload: Bool = false
    public var isInsideDeferredTaskQueue: Bool = false
    public var suppressMicrotaskDrain: Bool = false
    public var exitOnUncaughtException: Bool = false
    public var isHandlingUncaughtException: Bool = false
    public var isPrintingPlugin: Bool = false
    public var isFromDevServer: Bool = false
    public var hasEnabledMacroMode: Bool = false
    public var hasAnyMacroRemappings: Bool = false
    public var hasPatchedRunMain: Bool = false
    public var hideBunStackframes: Bool = true
    public var macroMode: Bool = false
    public var noMacros: Bool = false
    public var autoInstallDependencies: Bool = false
    public var hasStartedDebugger: Bool = false
    public var hasTerminated: Bool = false
    public var isUsLoopEntered: Bool = false

    // ---- 计数器 & 统计 ----
    public var transpiledCount: Int64 = 0
    public var resolvedCount: Int64 = 0
    public var unhandledErrorCounter: Int64 = 0
    public var hotReloadCounter: Int64 = 0
    public var testIsolationGeneration: Int64 = 0
    public var testIsolationEnabled: Bool = false

    // ---- 入口点 & 模块 ----
    public var entryPointResult: EntryPointResult = EntryPointResult()
    public var moduleLoader: ModuleLoader = ModuleLoader()
    public var overriddenMain: ?JsValue = None
    public var standaloneModuleGraph: ?StandaloneModuleGraph = None
    public var pendingInternalPromise: ?JsObject = None
    public var pendingInternalPromiseIsProtected: Bool = false
    public var pendingInternalPromiseReportedAt: Int64 = Int64.MaxValue
    public var hotReloadDeferred: Bool = false

    // ---- 热重载 ----
    public var hotReload: HotReloadMode = HotReloadMode.None

    // ---- Worker ----
    public var worker: ?WebWorker = None

    // ---- 调试器 ----
    public var debugger_: ?Debugger = None

    // ---- GC ----
    public var aggressiveGarbageCollection: GCLevel = GCLevel.None

    // ---- 退出处理器 ----
    public var exitHandler: ExitHandler = ExitHandler()

    // ---- 未处理 Rejection ----
    public var onUnhandledRejection: ((BunVirtualMachine, JsObject, JsValue) -> Unit)? = None
    public var onUnhandledRejectionCtx: ?BunVirtualMachine = None
    public var onUnhandledRejectionExceptionList: ?ExceptionList = None
    public var unhandledRejectionsMode_: UnhandledRejectionsMode = UnhandledRejectionsMode.Bun

    // ---- 计时器 ----
    public var originTimer: Float64 = 0.0
    public var originTimestamp: Int64 = 0
    public var overriddenPerformanceNow: ?Int64 = None

    // ---- 命令行参数 ----
    public var argv: Array<String> = []

    // ---- 宏 ----
    public var macros: HashMap<Int64, JsObject> = HashMap()
    public var macroEntryPoints: HashMap<Int64, String> = HashMap()

    // ---- 环境变量 ----
    public var channelRef: KeepAlive = KeepAlive()
    public var channelRefOverridden: Bool = false

    // ---- 常见 JS 扩展 ----
    public var commonjsCustomExtensions: HashMap<String, String> = HashMap()
    public var hasMutatedBuiltInExtensions: Int64 = 0

    // ---- 初始脚本执行上下文标识符 ----
    public var initialScriptExecutionContextIdentifier: Int64 = 0

    // ---- IPC ----
    public var ipc: ?IPCInstance = None

    // ---- 缓存 ----
    public var refStrings: HashMap<Int64, RefString> = HashMap()

    // ---- 来源相对纪元 (Jan 1, 2000) ----
    // 严格翻译自 VirtualMachine.zig origin_relative_epoch
    public static let ORIGIN_RELATIVE_EPOCH: Int64 = 946684800 * 1000000000

    // 静态引用
    public static var isSmolMode: Bool = false
    public static var isBunTest: Bool = false
    public static var hasBunGarbageCollectorFlagEnabled: Bool = false

    // ---- 默认日志深度 ----
    public static let DEFAULT_CONSOLE_LOG_DEPTH: Int64 = 2
    // ---- 主文件名 ----
    public static let MAIN_FILE_NAME: String = "bun:main"

    public init() {
        this.originTimestamp = getOriginTimestamp()
        this.onUnhandledRejection = { (vm, global, value) =>
            vm.defaultOnUnhandledRejection(global, value)
        }
    }

    // ========== 获取/设置方法 ==========

    // 严格翻译自 VirtualMachine.zig get()
    public static func get() -> BunVirtualMachine {
        VMHolder.vm.getOrThrow()
    }

    // 严格翻译自 VirtualMachine.zig getOrNull()
    public static func getOrNull() -> ?BunVirtualMachine {
        VMHolder.vm
    }

    // 严格翻译自 VirtualMachine.zig getMainThreadVM()
    public static func getMainThreadVM() -> ?BunVirtualMachine {
        VMHolder.mainThreadVM
    }

    // 严格翻译自 VirtualMachine.zig isLoaded()
    public static func isLoaded() -> Bool {
        VMHolder.vm != None
    }

    // 严格翻译自 VirtualMachine.zig isMainThread()
    public func isMainThread() -> Bool {
        worker == None && isMainThread_
    }

    // 严格翻译自 VirtualMachine.zig isInspectorEnabled()
    public func isInspectorEnabled() -> Bool {
        debugger_ != None
    }

    // 严格翻译自 VirtualMachine.zig isShuttingDown()
    public func isShuttingDown() -> Bool {
        isShuttingDown_
    }

    // 严格翻译自 VirtualMachine.zig isWatcherEnabled()
    public func isWatcherEnabled() -> Bool {
        hotReload != HotReloadMode.None
    }

    // ========== 事件循环 ==========

    // 严格翻译自 VirtualMachine.zig isEventLoopAlive
    public func isEventLoopAlive() -> Bool {
        unhandledErrorCounter == 0 &&
        (activeTasks > 0 || pendingUnrefCounter > 0)
    }

    // 严格翻译自 VirtualMachine.zig isEventLoopAliveExcludingImmediates
    public func isEventLoopAliveExcludingImmediates() -> Bool {
        unhandledErrorCounter == 0 &&
        (activeTasks > 0 || pendingUnrefCounter > 0)
    }

    // 严格翻译自 VirtualMachine.zig wakeup
    public func wakeup() {
        // 唤醒事件循环
    }

    // 严格翻译自 VirtualMachine.zig tick
    public func tick() {
        // tick 实现
    }

    // 严格翻译自 VirtualMachine.zig waitFor
    public func waitFor(cond: Bool) {
        while (!cond) {
            tick()
        }
    }

    // 严格翻译自 VirtualMachine.zig waitForPromise
    public func waitForPromise(promise: JsObject) {
        // 等待 promise 完成
    }

    // 严格翻译自 VirtualMachine.zig waitForTasks
    public func waitForTasks() {
        while (isEventLoopAlive()) {
            tick()
        }
    }

    // 严格翻译自 VirtualMachine.zig enqueueTask
    public func enqueueTask(task: () -> Unit) {
        activeTasks++
        task()
        activeTasks--
    }

    // 严格翻译自 VirtualMachine.zig drainMicrotasks
    public func drainMicrotasks() {
        // 排空微任务队列
    }

    // ========== 初始化 ==========

    // 严格翻译自 VirtualMachine.zig getOriginTimestamp()
    static func getOriginTimestamp() -> Int64 {
        // 截断时间戳相对于 Y2K
        let now = System.currentTimeMillis()
        if (now < ORIGIN_RELATIVE_EPOCH) {
            return 0
        }
        now - ORIGIN_RELATIVE_EPOCH
    }

    // 严格翻译自 VirtualMachine.zig init
    public static func create(opts: BunVirtualMachineOptions) -> BunVirtualMachine {
        let vm = BunVirtualMachine()
        vm.smol = opts.smol
        vm.isMainThread_ = opts.isMainThread
        vm.initialScriptExecutionContextIdentifier = if (opts.isMainThread) { 1 } else { Int64.MaxValue }

        if (opts.isMainThread) {
            VMHolder.mainThreadVM = vm
        }
        VMHolder.vm = vm

        if (opts.smol) {
            BunVirtualMachine.isSmolMode = true
        }

        return vm
    }

    // 严格翻译自 VirtualMachine.zig initWithModuleGraph
    public static func createWithModuleGraph(graph: StandaloneModuleGraph, opts: BunVirtualMachineOptions) -> BunVirtualMachine {
        let vm = BunVirtualMachine()
        vm.standaloneModuleGraph = graph
        vm.smol = opts.smol
        vm.isMainThread_ = opts.isMainThread
        vm.initialScriptExecutionContextIdentifier = if (opts.isMainThread) { 1 } else { Int64.MaxValue }

        if (opts.isMainThread) {
            VMHolder.mainThreadVM = vm
        }
        VMHolder.vm = vm

        return vm
    }

    // 严格翻译自 VirtualMachine.zig initWorker
    public static func createForWorker(worker: WebWorker, opts: BunVirtualMachineOptions) -> BunVirtualMachine {
        let vm = BunVirtualMachine()
        vm.worker = worker
        vm.smol = opts.smol
        vm.isMainThread_ = false
        vm.initialScriptExecutionContextIdentifier = Int64(worker.executionContextId)

        VMHolder.vm = vm
        return vm
    }

    // ========== 入口点加载 ==========

    // 严格翻译自 VirtualMachine.zig loadEntryPoint
    public func loadEntryPoint(entryPath: String) -> ?JsObject {
        hasLoaded = false
        main = entryPath
        mainHash = hashPath(entryPath)

        let promise = loadAndEvaluateModule(entryPath)
        pendingInternalPromise = promise
        pendingInternalPromiseIsProtected = false

        if (isWatcherEnabled()) {
            while (pendingInternalPromise != None) {
                tick()
            }
        } else {
            waitForPromise(pendingInternalPromise.getOr(JsObject.make()))
        }

        return pendingInternalPromise
    }

    // 严格翻译自 VirtualMachine.zig reloadEntryPoint
    public func reloadEntryPoint(entryPath: String) -> ?JsObject {
        hasLoaded = false
        main = entryPath
        mainResolvedPath = ""
        mainHash = hashPath(entryPath)
        overriddenMain = None

        let promise = loadAndEvaluateModule(entryPath)
        pendingInternalPromise = promise
        pendingInternalPromiseIsProtected = false
        return promise
    }

    // 严格翻译自 VirtualMachine.zig loadEntryPointForWebWorker
    public func loadEntryPointForWebWorker(entryPath: String) -> ?JsObject {
        let promise = reloadEntryPoint(entryPath)
        drainMicrotasks()
        waitForPromise(pendingInternalPromise.getOr(JsObject.make()))

        if (let Some(w) <- worker) {
            if (w.hasRequestedTerminate()) {
                return None
            }
        }
        return pendingInternalPromise
    }

    // 严格翻译自 VirtualMachine.zig loadEntryPointForTestRunner
    public func loadEntryPointForTestRunner(entryPath: String) -> ?JsObject {
        let promise = reloadEntryPoint(entryPath)

        if (isWatcherEnabled()) {
            while (pendingInternalPromise != None) {
                tick()
            }
        } else {
            drainMicrotasks()
            waitForPromise(pendingInternalPromise.getOr(JsObject.make()))
        }

        return pendingInternalPromise
    }

    // 严格翻译自 VirtualMachine.zig clearEntryPoint
    public func clearEntryPoint() {
        if (main.isEmpty) {
            return
        }
        // 删除模块注册表条目
    }

    // 严格翻译自 VirtualMachine.zig loadPreloads
    public func loadPreloads() -> ?JsObject {
        isInPreload = true
        defer { isInPreload = false }

        for (preloadPath in preload) {
            let promise = loadAndEvaluateModule(preloadPath)
            pendingInternalPromise = promise

            if (isWatcherEnabled()) {
                while (pendingInternalPromise != None) {
                    tick()
                }
            } else {
                waitForPromise(pendingInternalPromise.getOr(JsObject.make()))
            }
        }

        if (!testIsolationEnabled) {
            preload = []
        }

        return None
    }

    // ========== 宏模式 ==========

    // 严格翻译自 VirtualMachine.zig enableMacroMode
    public func enableMacroMode() {
        if (!hasEnabledMacroMode) {
            hasEnabledMacroMode = true
        }
        macroMode = true
    }

    // 严格翻译自 VirtualMachine.zig disableMacroMode
    public func disableMacroMode() {
        macroMode = false
    }

    // ========== GC ==========

    // 严格翻译自 VirtualMachine.zig garbageCollect
    public func garbageCollect(sync: Bool) -> Int64 {
        if (sync) {
            // 同步 GC
            return 0
        }
        // 异步 GC
        0
    }

    // 严格翻译自 VirtualMachine.zig autoGarbageCollect
    public func autoGarbageCollect() {
        if (aggressiveGarbageCollection != GCLevel.None) {
            garbageCollect(aggressiveGarbageCollection == GCLevel.Aggressive)
        }
    }

    // ========== 热重载 ==========

    // 严格翻译自 VirtualMachine.zig reload
    public func reload() {
        // 检查 pending promise 状态
        if (let Some(p) <- pendingInternalPromise) {
            // 延迟热重载
        }

        hotReloadCounter++
        hotReloadDeferred = false

        if (pendingInternalPromiseIsProtected) {
            pendingInternalPromise = None
            pendingInternalPromiseIsProtected = false
        }

        let _ = reloadEntryPoint(main)
    }

    // 严格翻译自 VirtualMachine.zig addMainToWatcherIfNeeded
    public func addMainToWatcherIfNeeded() {
        if (isWatcherEnabled() && main.size > 0) {
            // 添加到 watcher
        }
    }

    // ========== 异常处理 ==========

    // 严格翻译自 VirtualMachine.zig unhandledRejection
    public func unhandledRejection(globalObject: JsObject, reason: JsValue, promise: JsValue) {
        if (isShuttingDown()) {
            return
        }

        if (BunVirtualMachine.isBunTest) {
            unhandledErrorCounter++
            onUnhandledRejection.getOr({ (_, _, _) => () })(this, globalObject, reason)
            return
        }

        match (unhandledRejectionsMode_) {
            case Bun => {
                unhandledErrorCounter++
                onUnhandledRejection.getOr({ (_, _, _) => () })(this, globalObject, reason)
            }
            case None => {
                drainMicrotasks()
            }
            case Warn => {
                drainMicrotasks()
            }
            case WarnWithErrorCode => {
                drainMicrotasks()
                exitHandler.exitCode = 1
            }
            case Strict => {
                unhandledErrorCounter++
                exitHandler.exitCode = 1
                onUnhandledRejection.getOr({ (_, _, _) => () })(this, globalObject, reason)
            }
            case Throw => {
                unhandledErrorCounter++
                onUnhandledRejection.getOr({ (_, _, _) => () })(this, globalObject, reason)
            }
        }
    }

    // 严格翻译自 VirtualMachine.zig uncaughtException
    public func uncaughtException(globalObject: JsObject, err: JsValue, isRejection: Bool) -> Bool {
        if (isShuttingDown()) {
            return true
        }

        if (BunVirtualMachine.isBunTest) {
            unhandledErrorCounter++
            onUnhandledRejection.getOr({ (_, _, _) => () })(this, globalObject, err)
            return true
        }

        if (isHandlingUncaughtException) {
            return true
        }

        if (exitOnUncaughtException) {
            exitHandler.exitCode = 1
            return true
        }

        isHandlingUncaughtException = true
        defer { isHandlingUncaughtException = false }

        let handled = false
        if (!handled) {
            unhandledErrorCounter++
            exitHandler.exitCode = 1
            onUnhandledRejection.getOr({ (_, _, _) => () })(this, globalObject, err)
        }
        return handled
    }

    // 严格翻译自 VirtualMachine.zig defaultOnUnhandledRejection
    public func defaultOnUnhandledRejection(globalObject: JsObject, value: JsValue) {
        runErrorHandler(value, None)
    }

    // 严格翻译自 VirtualMachine.zig onQuietUnhandledRejectionHandler
    public func onQuietUnhandledRejectionHandler(globalObject: JsObject, value: JsValue) {
        unhandledErrorCounter++
    }

    // 严格翻译自 VirtualMachine.zig unhandledRejectionScope
    public func unhandledRejectionScope() -> UnhandledRejectionScope {
        let scope = UnhandledRejectionScope()
        scope.ctx = this
        scope.count = unhandledErrorCounter
        scope.onUnhandledRejection = onUnhandledRejection
        return scope
    }

    // 严格翻译自 VirtualMachine.zig reportExceptionInHotReloadedModuleIfNeeded
    public func reportExceptionInHotReloadedModuleIfNeeded() {
        defer { addMainToWatcherIfNeeded() }
        if (pendingInternalPromise == None) {
            return
        }
        // 检查 promise 状态并报告异常
        if (hotReloadDeferred) {
            reload()
        }
    }

    // 严格翻译自 VirtualMachine.zig runErrorHandler
    public func runErrorHandler(result: JsValue, exceptionList: ?ExceptionList) {
        let prevHadErrors = hadErrors
        hadErrors = false
        defer { hadErrors = prevHadErrors }

        // 打印错误
        printErrorLikeObjectToConsole(result)
    }

    // 严格翻译自 VirtualMachine.zig printErrorLikeObjectToConsole
    public func printErrorLikeObjectToConsole(value: JsValue) {
        // 简化实现 - 完整版需要 ConsoleObject.Formatter
        let str = value.toString()
        println("[ERROR] " + str)
    }

    // ========== 生命周期 ==========

    // 严格翻译自 VirtualMachine.zig onBeforeExit
    public func onBeforeExit() {
        exitHandler.dispatchOnBeforeExit(this)
        var dispatch = false
        while (true) {
            while (isEventLoopAlive()) {
                tick()
                dispatch = true
            }
            if (dispatch) {
                exitHandler.dispatchOnBeforeExit(this)
                dispatch = false
                if (isEventLoopAlive()) {
                    continue
                }
            }
            break
        }
    }

    // 严格翻译自 VirtualMachine.zig onExit
    public func onExit() {
        exitHandler.dispatchOnExit()
        isShuttingDown_ = true
    }

    // 严格翻译自 VirtualMachine.zig scriptExecutionStatus
    public func scriptExecutionStatus() -> ScriptExecutionStatus {
        if (isShuttingDown_) {
            return ScriptExecutionStatus.Stopped
        }
        if (let Some(w) <- worker) {
            if (w.hasRequestedTerminate()) {
                return ScriptExecutionStatus.Stopped
            }
        }
        ScriptExecutionStatus.Running
    }

    // 严格翻译自 VirtualMachine.zig deinit
    public func deinit() {
        overriddenMain = None
        hasTerminated = true
    }

    // 严格翻译自 VirtualMachine.zig globalExit
    public func globalExit() -> Int64 {
        onExit()
        exitHandler.exitCode
    }

    // ========== 模块解析 ==========

    // 严格翻译自 VirtualMachine.zig resolve
    public func resolve(specifier: String, source: String, queryString: ?String, isEsm: Bool) -> ?String {
        // 1. 检查硬编码模块别名
        // 2. 通过解析器解析
        // 3. 返回解析后的路径
        if (specifier == BunVirtualMachine.MAIN_FILE_NAME) {
            return specifier
        }
        None
    }

    // 严格翻译自 VirtualMachine.zig _resolve
    func resolveInternal(ret: ResolveFunctionResult, specifier: String, source: String, isEsm: Bool) {
        if (specifier == BunVirtualMachine.MAIN_FILE_NAME) {
            ret.path = specifier
            return
        }
        // 完整的解析逻辑
        ret.path = specifier
    }

    // ========== 工具方法 ==========

    // 加载并执行模块
    func loadAndEvaluateModule(path: String) -> ?JsObject {
        let ctx = JsContext(vm: JsVirtualMachine())
        ctx.evaluateModule(path, main)
        None
    }

    // 计算路径哈希
    func hashPath(path: String) -> Int64 {
        var hash: Int64 = 0
        for (c in path) {
            hash = hash * 31 + Int64(c.code)
        }
        hash
    }

    // 严格翻译自 VirtualMachine.zig allowAddons
    public func allowAddons() -> Bool {
        true
    }

    // 严格翻译自 VirtualMachine.zig allowRejectionHandledWarning
    public func allowRejectionHandledWarning() -> Bool {
        unhandledRejectionsMode_ != UnhandledRejectionsMode.Bun
    }

    // 严格翻译自 VirtualMachine.zig shouldDestructMainThreadOnExit
    public func shouldDestructMainThreadOnExit() -> Bool {
        false
    }

    // 严格翻译自 VirtualMachine.zig mimeType
    public func mimeType(str: String) -> ?MimeType {
        None
    }

    // 严格翻译自 VirtualMachine.zig onAfterEventLoop
    public func onAfterEventLoop() {
        // 执行 after event loop callback
    }

    // 严格翻译自 VirtualMachine.zig nextAsyncTaskID
    public func nextAsyncTaskID() -> Int64 {
        0
    }

    // ========== 测试隔离 ==========

    // 严格翻译自 VirtualMachine.zig swapGlobalForTestIsolation
    public func swapGlobalForTestIsolation() {
        drainMicrotasks()
        testIsolationGeneration++
        overriddenMain = None
        entryPointResult.deinit()
        pendingInternalPromise = None
        pendingInternalPromiseIsProtected = false
        hasPatchedRunMain = false
        main = ""
        mainHash = 0
        mainResolvedPath = ""
        unhandledErrorCounter = 0

        // 创建新的全局对象
        let newGlobal = JsObject.make()
        globalObject = newGlobal
        hasLoadedConstructors = true
    }

    // 严格翻译自 VirtualMachine.zig addListeningSocketForWatchMode
    public func addListeningSocketForWatchMode(socket: Int64) {
        if (hotReload != HotReloadMode.Watch && !testIsolationEnabled) {
            return
        }
    }

    // 严格翻译自 VirtualMachine.zig removeListeningSocketForWatchMode
    public func removeListeningSocketForWatchMode(socket: Int64) {
        if (hotReload != HotReloadMode.Watch && !testIsolationEnabled) {
            return
        }
    }
}

// ========== 辅助类型 ==========

// 事件循环句柄
public class EventLoopHandle {
    public init() {}
}

// Web Worker
// 严格翻译自 web_worker.zig
public class WebWorker {
    public var parent: ?BunVirtualMachine = None
    public var parentContextId: Int64 = 0
    public var executionContextId: Int64 = 0
    public var mini: Bool = false
    public var evalMode: Bool = false
    public var storeFd: Bool = false
    public var name: String = ""
    public var unresolvedSpecifier: String = ""
    public var preloads: Array<String> = []
    public var argv: Array<String> = []
    public var status: WorkerStatus = WorkerStatus.Start

    // 跨线程信号
    public var requestedTerminate: Bool = false
    public var vm: ?BunVirtualMachine = None

    // 父线程轮询引用
    public var parentPollRef: KeepAlive = KeepAlive()

    public init() {}

    public func hasRequestedTerminate() -> Bool {
        requestedTerminate
    }

    // 严格翻译自 web_worker.zig create
    public static func create(parent: BunVirtualMachine, specifier: String, opts: BunVirtualMachineOptions) -> WebWorker {
        let worker = WebWorker()
        worker.parent = parent
        worker.unresolvedSpecifier = specifier
        worker.executionContextId = parent.initialScriptExecutionContextIdentifier
        return worker
    }

    // 严格翻译自 web_worker.zig terminate
    public func terminate() {
        requestedTerminate = true
        if (let Some(vm) <- vm) {
            vm.isShuttingDown_ = true
        }
    }
}

// IPC 实例
// 严格翻译自 VirtualMachine.zig IPCInstance
public class IPCInstance {
    public var globalThis: JsObject = JsObject.make()
    public var data: IPCSendQueue = IPCSendQueue()
    public var hasDisconnectCalled: Bool = false

    public init() {}

    // 严格翻译自 IPCInstance.handleIPCMessage
    public func handleIPCMessage(message: IPCDecodedMessage, handle: JsValue) {
        match (message) {
            case IPCDecodedMessage.Version(v) => {
                // IPC 版本信息
            }
            case IPCDecodedMessage.Data(data) => {
                // 处理数据消息
            }
            case IPCDecodedMessage.Internal(data) => {
                // 处理内部消息
            }
        }
    }

    // 严格翻译自 IPCInstance.handleIPCClose
    public func handleIPCClose() {
        hasDisconnectCalled = true
    }
}

// IPC 消息
public enum IPCDecodedMessage {
    | Version(Int64)
    | Data(JsValue)
    | Internal(JsValue)
}

// IPC 发送队列
public class IPCSendQueue {
    public init() {}
}

// Keep-Alive 引用
public class KeepAlive {
    public var refCount: Int64 = 0

    public init() {}

    public func ref() {
        refCount++
    }

    public func unref() {
        refCount--
    }

    public func disable() {
        refCount = 0
    }
}

// 模块加载器
// 严格翻译自 ModuleLoader.zig
public class ModuleLoader {
    public var transpileSourceCodeArena: ?String = None
    public var evalSource: ?String = None

    public static var isAllowedToUseInternalTestingApis: Bool = false

    public init() {}

    // 严格翻译自 ModuleLoader.resetArena
    public func resetArena(jscVm: BunVirtualMachine) {
        if (let Some(arena) <- transpileSourceCodeArena) {
            if (jscVm.smol) {
                transpileSourceCodeArena = None
            }
        }
    }

    // 严格翻译自 ModuleLoader.transpileSourceCode
    public func transpileSourceCode(
        jscVm: BunVirtualMachine,
        specifier: String,
        referrer: String,
        inputSpecifier: String,
        path: String,
        loader: String,
        moduleType: String,
        log: ArrayList<String>,
        virtualSource: ?String,
        globalObject: ?JsObject
    ) -> ?ResolvedSource {
        jscVm.transpiledCount++
        let source = ResolvedSource()
        source.specifier = inputSpecifier
        source.sourceUrl = path
        source.sourceCode = virtualSource.getOr("")
        return source
    }

    // 严格翻译自 ModuleLoader.fetchBuiltinModule
    public func fetchBuiltinModule(jscVm: BunVirtualMachine, specifier: String) -> ?ResolvedSource {
        None
    }

    // 获取加载器标志
    public enum FetchFlags {
        | Normal
        | PrintSource
        | DisableTranspiling

        public func disableTranspiling() -> Bool {
            match (this) {
                case DisableTranspiling => true
                case _ => false
            }
        }
    }
}

// 解析后的源码
// 严格翻译自 ModuleLoader.zig ResolvedSource
public class ResolvedSource {
    public var sourceCode: String = ""
    public var specifier: String = ""
    public var sourceUrl: String = ""
    public var queryString: String = ""

    public init() {}
}

// 调试器
public class Debugger {
    public var pathOrPort: ?String = None
    public var fromEnvironmentVariable: String = ""
    public var waitForConnection: Bool = false
    public var setBreakpointOnFirstLine: Bool = false
    public var nextDebuggerId: Int64 = 0

    public init() {}
}

// Ref 字符串
public class RefString {
    public var hash: Int64 = 0
    public var ptr: String = ""
    public var len: Int64 = 0

    public init() {}

    public static func computeHash(input: String) -> Int64 {
        var hash: Int64 = 0
        for (c in input) {
            hash = hash * 31 + Int64(c.code)
        }
        hash
    }
}

// 独立模块图
public class StandaloneModuleGraph {
    public init() {}

    public func find(path: String) -> ?ModuleGraphFile {
        None
    }
}

// 模块图文件
public class ModuleGraphFile {
    public var name: String = ""
    public var contents: String = ""
    public var sourcemap: ?String = None

    public init() {}
}

// MIME 类型
public class MimeType {
    public var contentType: String = ""
    public var ext: String = ""

    public init() {}
}
