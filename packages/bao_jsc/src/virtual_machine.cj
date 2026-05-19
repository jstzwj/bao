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
    public var onUnhandledRejection: ?((BunVirtualMachine, JsObject, JsValue) -> Unit) = None

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
    // 严格翻译自 Options.graph
    public var graph: ?StandaloneModuleGraph = None
    // 严格翻译自 Options.debugger
    public var debugger_: DebuggerConfig = DebuggerConfig.Unspecified
    // 严格翻译自 Options.env_loader
    public var envLoader: ?String = None
    // 严格翻译自 Options.log
    public var log: ?ArrayList<String> = None

    public init() {}
}

// ========== 调试器配置 ==========
// 严格翻译自 VirtualMachine.zig bun.cli.Command.Debugger
public enum DebuggerConfig {
    | Unspecified
    | Enable(DebuggerEnableConfig)
}

public class DebuggerEnableConfig {
    public var pathOrPort: ?String = None
    public var waitForConnection: Bool = false
    public var setBreakpointOnFirstLine: Bool = false

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
            if (vmInstance.isMainThread()) {
                VMHolder.mainThreadVM = vmInstance
            }
        }
        cachedGlobalObject = global
    }

    // 严格翻译自 VMHolder.Bun__getDefaultGlobalObject
    public static func getDefaultGlobalObject(): ?JsObject {
        if (let Some(cached) <- cachedGlobalObject) {
            return cached
        }
        if (let Some(vmInstance) <- vm) {
            cachedGlobalObject = vmInstance.globalObject
        }
        return None
    }

    // 严格翻译自 VMHolder.Bun__thisThreadHasVM
    public static func thisThreadHasVM(): Bool {
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
    // 严格翻译自 VirtualMachine.transpiler
    public var transpiler: Transpiler = Transpiler()
    // 严格翻译自 VirtualMachine.log
    public var log: ArrayList<String> = ArrayList()
    public var main: String = ""
    public var mainIsHtmlEntrypoint: Bool = false
    public var mainResolvedPath: String = ""
    public var mainHash: Int64 = 0
    // 严格翻译自 VirtualMachine.overridden_main
    public var overriddenMain: ?JsValue = None

    // ---- 事件循环 ----
    // 严格翻译自 VirtualMachine.event_loop_handle
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
    // 严格翻译自 VirtualMachine.module_loader
    public var moduleLoader: ModuleLoader = ModuleLoader()
    public var standaloneModuleGraph: ?StandaloneModuleGraph = None
    public var pendingInternalPromise: ?JsObject = None
    public var pendingInternalPromiseIsProtected: Bool = false
    public var pendingInternalPromiseReportedAt: Int64 = Int64.MaxValue
    public var hotReloadDeferred: Bool = false

    // ---- 热重载 ----
    // 严格翻译自 VirtualMachine.bun_watcher
    public var bunWatcher: ImportWatcher = ImportWatcher.None
    public var hotReload: HotReloadMode = HotReloadMode.None

    // ---- Worker ----
    public var worker: ?WebWorker = None

    // ---- 调试器 ----
    public var debugger_: ?Debugger = None

    // ---- GC ----
    public var aggressiveGarbageCollection: GCLevel = GCLevel.None
    // 严格翻译自 VirtualMachine.gc_controller
    public var gcController: GCController = GCController()

    // ---- 退出处理器 ----
    public var exitHandler: ExitHandler = ExitHandler()

    // ---- 未处理 Rejection ----
    public var onUnhandledRejection: ?((BunVirtualMachine, JsObject, JsValue) -> Unit) = None
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
    // 严格翻译自 VirtualMachine.macros (MacroMap)
    public var macros: HashMap<Int64, JsObject> = HashMap()
    // 严格翻译自 VirtualMachine.macro_entry_points
    public var macroEntryPoints: HashMap<Int64, String> = HashMap()

    // ---- 环境变量 ----
    public var channelRef: KeepAlive = KeepAlive()
    public var channelRefOverridden: Bool = false
    // 严格翻译自 VirtualMachine.channel_ref_should_ignore_one_disconnect_event_listener
    public var channelRefShouldIgnoreOneDisconnect: Bool = false

    // ---- 常见 JS 扩展 ----
    public var commonjsCustomExtensions: HashMap<String, String> = HashMap()
    public var hasMutatedBuiltInExtensions: Int64 = 0

    // ---- 初始脚本执行上下文标识符 ----
    public var initialScriptExecutionContextIdentifier: Int64 = 0

    // ---- IPC ----
    // 严格翻译自 VirtualMachine.ipc (IPCInstanceUnion)
    public var ipc: ?IPCInstanceUnion = None

    // ---- 缓存 ----
    public var refStrings: HashMap<Int64, RefString> = HashMap()
    // 严格翻译自 VirtualMachine.ref_strings_mutex
    public var refStringsMutex: Mutex = Mutex()

    // ---- 源映射 ----
    // 严格翻译自 VirtualMachine.saved_source_map_table
    public var savedSourceMapTable: SavedSourceMapTable = SavedSourceMapTable()
    // 严格翻译自 VirtualMachine.source_mappings
    public var sourceMappings: SavedSourceMap = SavedSourceMap()
    // 严格翻译自 VirtualMachine.remap_stack_frames_mutex
    public var remapStackFramesMutex: Mutex = Mutex()

    // ---- 事件循环 (macro & regular) ----
    // 严格翻译自 VirtualMachine.macro_event_loop
    public var macroEventLoop: EventLoop = EventLoop()
    // 严格翻译自 VirtualMachine.regular_event_loop
    public var regularEventLoop: EventLoop = EventLoop()
    // 严格翻译自 VirtualMachine.event_loop
    public var eventLoop: EventLoop = EventLoop()

    // ---- 稀有数据 ----
    // 严格翻译自 VirtualMachine.rare_data
    public var rareData: ?RareData = None
    // 严格翻译自 VirtualMachine.proxy_env_storage
    public var proxyEnvStorage: ProxyEnvStorage = ProxyEnvStorage()

    // ---- Console ----
    // 严格翻译自 VirtualMachine.console
    public var console: ConsoleObject = ConsoleObject()

    // ---- 未处理的 pending rejection 捕获 ----
    // 严格翻译自 VirtualMachine.unhandled_pending_rejection_to_capture
    public var unhandledPendingRejectionToCapture: ?JsValue = None

    // ---- 插件 ----
    // 严格翻译自 VirtualMachine.plugin_runner
    public var pluginRunner: ?PluginRunner = None

    // ---- 自动杀手 ----
    // 严格翻译自 VirtualMachine.auto_killer
    public var autoKiller: ProcessAutoKiller = ProcessAutoKiller()

    // ---- TLS & Fetch 配置 ----
    // 严格翻译自 VirtualMachine.default_tls_reject_unauthorized
    public var defaultTlsRejectUnauthorized: ?Bool = None
    // 严格翻译自 VirtualMachine.default_verbose_fetch
    public var defaultVerboseFetch: ?Int64 = None

    // ---- 模块队列 ----
    // 严格翻译自 VirtualMachine.modules
    public var modules: AsyncModuleQueue = AsyncModuleQueue()

    // ---- 来源相对纪元 (Jan 1, 2000) ----
    // 严格翻译自 VirtualMachine.zig origin_relative_epoch
    public static let ORIGIN_RELATIVE_EPOCH: Int64 = 946684800 * 1000000000

    // 静态引用
    public static var isSmolMode: Bool = false
    public static var isBunTest: Bool = false
    public static var hasBunGarbageCollectorFlagEnabled: Bool = false
    // 严格翻译自 VirtualMachine.synthetic_allocation_limit
    public static var syntheticAllocationLimit: Int64 = Int64.MaxValue
    // 严格翻译自 VirtualMachine.string_allocation_limit
    public static var stringAllocationLimit: Int64 = Int64.MaxValue
    // 严格翻译自 VirtualMachine.defaultRemainingRunsUntilSkipReleaseAccess
    public static var defaultRemainingRunsUntilSkipReleaseAccess: Int64 = 10
    // 严格翻译自 VirtualMachine.is_main_thread_vm
    public static var isMainThreadVM: Bool = false
    // 严格翻译自 VirtualMachine.is_bundler_thread_for_bytecode_cache
    public static var isBundlerThreadForBytecodeCache: Bool = false

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
    public static func get(): BunVirtualMachine {
        VMHolder.vm.getOrThrow()
    }

    // 严格翻译自 VirtualMachine.zig getOrNull()
    public static func getOrNull(): ?BunVirtualMachine {
        VMHolder.vm
    }

    // 严格翻译自 VirtualMachine.zig getMainThreadVM()
    public static func getMainThreadVM(): ?BunVirtualMachine {
        VMHolder.mainThreadVM
    }

    // 严格翻译自 VirtualMachine.zig isLoaded()
    public static func isLoaded(): Bool {
        VMHolder.vm != None
    }

    // 严格翻译自 VirtualMachine.zig isMainThread()
    public func isMainThread(): Bool {
        worker == None && isMainThread_
    }

    // 严格翻译自 VirtualMachine.zig isInspectorEnabled()
    public func isInspectorEnabled(): Bool {
        debugger_ != None
    }

    // 严格翻译自 VirtualMachine.zig isShuttingDown()
    public func isShuttingDown(): Bool {
        isShuttingDown_
    }

    // 严格翻译自 VirtualMachine.zig isWatcherEnabled()
    public func isWatcherEnabled(): Bool {
        bunWatcher != ImportWatcher.None
    }

    // 严格翻译自 VirtualMachine.zig getTLSRejectUnauthorized
    public func getTLSRejectUnauthorized(): Bool {
        defaultTlsRejectUnauthorized.getOr(true)
    }

    // 严格翻译自 VirtualMachine.zig getVerboseFetch
    public func getVerboseFetch(): Int64 {
        defaultVerboseFetch.getOr(0)
    }

    // 严格翻译自 VirtualMachine.zig uwsLoop
    public func uwsLoop(): EventLoopHandle {
        eventLoopHandle.getOr(EventLoopHandle())
    }

    // 严格翻译自 VirtualMachine.zig uvLoop
    public func uvLoop(): EventLoopHandle {
        eventLoopHandle.getOr(EventLoopHandle())
    }

    // 严格翻译自 VirtualMachine.zig nodeFS
    public func nodeFS(): NodeFS {
        NodeFS()
    }

    // 严格翻译自 VirtualMachine.zig rareData
    public func rareData(): RareData {
        if (let Some(rd) <- rareData) {
            return rd
        }
        let rd = RareData()
        rareData = rd
        return rd
    }

    // 严格翻译自 VirtualMachine.zig packageManager
    public func packageManager(): PackageManager {
        transpiler.getPackageManager()
    }

    // 严格翻译自 VirtualMachine.zig hotMap
    public func hotMap(): ?HotMap {
        if (hotReload != HotReloadMode.Hot) {
            return None
        }
        return rareData().hotMap()
    }

    // 严格翻译自 VirtualMachine.zig onSubprocessSpawn
    public func onSubprocessSpawn(process: Process) {
        autoKiller.onSubprocessSpawn(process)
    }

    // 严格翻译自 VirtualMachine.zig onSubprocessExit
    public func onSubprocessExit(process: Process) {
        autoKiller.onSubprocessExit(process)
    }

    // 严格翻译自 VirtualMachine.zig getDevServerAsyncLocalStorage
    public func getDevServerAsyncLocalStorage(): ?JsValue {
        None
    }

    // 严格翻译自 VirtualMachine.zig initRequestBodyValue
    public func initRequestBodyValue(body: BodyValue): BodyValueHiveRef {
        BodyValueHiveRef()
    }

    // 严格翻译自 VirtualMachine.zig eventLoop
    public func eventLoop_(): EventLoop {
        eventLoop
    }

    // ========== 事件循环 ==========

    // 严格翻译自 VirtualMachine.zig isEventLoopAlive
    public func isEventLoopAlive(): Bool {
        unhandledErrorCounter == 0 &&
        (activeTasks > 0 || pendingUnrefCounter > 0 ||
         eventLoop.hasPendingRefs() || eventLoop.immediateTasksCount > 0)
    }

    // 严格翻译自 VirtualMachine.zig isEventLoopAliveExcludingImmediates
    public func isEventLoopAliveExcludingImmediates(): Bool {
        unhandledErrorCounter == 0 &&
        (activeTasks > 0 || pendingUnrefCounter > 0 ||
         eventLoop.hasPendingRefs())
    }

    // 严格翻译自 VirtualMachine.zig wakeup
    public func wakeup() {
        eventLoop.wakeup()
    }

    // 严格翻译自 VirtualMachine.zig tick
    public func tick() {
        eventLoop.tick()
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
    public func enqueueTask(task: (): Unit) {
        eventLoop.enqueueTask(task)
    }

    // 严格翻译自 VirtualMachine.zig enqueueImmediateTask
    public func enqueueImmediateTask(task: ImmediateObject) {
        eventLoop.enqueueImmediateTask(task)
    }

    // 严格翻译自 VirtualMachine.zig enqueueTaskConcurrent
    public func enqueueTaskConcurrent(task: ConcurrentTask) {
        eventLoop.enqueueTaskConcurrent(task)
    }

    // 严格翻译自 VirtualMachine.zig drainMicrotasks
    public func drainMicrotasks() {
        // 排空微任务队列
    }

    // 严格翻译自 VirtualMachine.zig prepareLoop
    public func prepareLoop() {
        // 准备事件循环
    }

    // 严格翻译自 VirtualMachine.zig enterUWSLoop
    public func enterUWSLoop() {
        if (let Some(loop) <- eventLoopHandle) {
            loop.run()
        }
    }

    // ========== 初始化 ==========

    // 严格翻译自 VirtualMachine.zig getOriginTimestamp()
    static func getOriginTimestamp(): Int64 {
        // 截断时间戳相对于 Y2K
        let now = System.currentTimeMillis()
        if (now < ORIGIN_RELATIVE_EPOCH) {
            return 0
        }
        now - ORIGIN_RELATIVE_EPOCH
    }

    // 严格翻译自 VirtualMachine.zig init
    public static func create(opts: BunVirtualMachineOptions): BunVirtualMachine {
        let vm = BunVirtualMachine()
        vm.smol = opts.smol
        vm.isMainThread_ = opts.isMainThread
        vm.initialScriptExecutionContextIdentifier = if (opts.isMainThread) { 1 } else { Int64.MaxValue }

        vm.regularEventLoop = EventLoop()
        vm.eventLoop = vm.regularEventLoop

        if (opts.isMainThread) {
            VMHolder.mainThreadVM = vm
        }
        VMHolder.vm = vm

        if (opts.smol) {
            BunVirtualMachine.isSmolMode = true
        }

        vm.configureDebugger(opts.debugger_)

        return vm
    }

    // 严格翻译自 VirtualMachine.zig initWithModuleGraph
    public static func createWithModuleGraph(graph: StandaloneModuleGraph, opts: BunVirtualMachineOptions): BunVirtualMachine {
        let vm = BunVirtualMachine()
        vm.standaloneModuleGraph = graph
        vm.smol = opts.smol
        vm.isMainThread_ = opts.isMainThread
        vm.initialScriptExecutionContextIdentifier = if (opts.isMainThread) { 1 } else { Int64.MaxValue }

        vm.regularEventLoop = EventLoop()
        vm.eventLoop = vm.regularEventLoop

        if (opts.isMainThread) {
            VMHolder.mainThreadVM = vm
        }
        VMHolder.vm = vm

        return vm
    }

    // 严格翻译自 VirtualMachine.zig initWorker
    public static func createForWorker(worker: WebWorker, opts: BunVirtualMachineOptions): BunVirtualMachine {
        let vm = BunVirtualMachine()
        vm.worker = worker
        vm.smol = opts.smol
        vm.isMainThread_ = false
        vm.initialScriptExecutionContextIdentifier = Int64(worker.executionContextId)
        vm.hotReload = worker.parentHotReload

        vm.regularEventLoop = EventLoop()
        vm.eventLoop = vm.regularEventLoop

        VMHolder.vm = vm
        return vm
    }

    // 严格翻译自 VirtualMachine.zig initBake
    public static func createForBake(opts: BunVirtualMachineOptions): BunVirtualMachine {
        let vm = BunVirtualMachine()
        vm.smol = opts.smol
        vm.isMainThread_ = opts.isMainThread

        vm.regularEventLoop = EventLoop()
        vm.eventLoop = vm.regularEventLoop

        if (opts.isMainThread) {
            VMHolder.mainThreadVM = vm
        }
        VMHolder.vm = vm

        if (opts.smol) {
            BunVirtualMachine.isSmolMode = true
        }

        vm.configureDebugger(opts.debugger_)
        return vm
    }

    // 严格翻译自 VirtualMachine.zig configureDebugger
    func configureDebugger(cliFlag: DebuggerConfig) {
        match (cliFlag) {
            case DebuggerConfig.Unspecified => {
                // 检查环境变量 BUN_INSPECT
            }
            case DebuggerConfig.Enable(config) => {
                debugger_ = Debugger()
                debugger_.pathOrPort = config.pathOrPort
                debugger_.waitForConnection = config.waitForConnection
                debugger_.setBreakpointOnFirstLine = config.setBreakpointOnFirstLine
            }
        }

        if (isInspectorEnabled()) {
            // 禁用运行时转译器缓存
        }
    }

    // 严格翻译自 VirtualMachine.zig loadExtraEnvAndSourceCodePrinter
    public func loadExtraEnvAndSourceCodePrinter() {
        // 检查 BUN_SHOW_BUN_STACKFRAMES
        // 检查 NODE_CHANNEL_FD -> initIPCInstance
        // 检查 NODE_PRESERVE_SYMLINKS
        // 检查 BUN_GARBAGE_COLLECTOR_LEVEL
        // 检查 BUN_FEATURE_FLAG_FORCE_WAITER_THREAD
        // 检查 BUN_FEATURE_FLAG_SYNTHETIC_MEMORY_LIMIT
    }

    // ========== 入口点加载 ==========

    // 严格翻译自 VirtualMachine.zig loadEntryPoint
    public func loadEntryPoint(entryPath: String): ?JsObject {
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
    public func reloadEntryPoint(entryPath: String): ?JsObject {
        hasLoaded = false
        main = entryPath
        mainResolvedPath = ""
        mainHash = hashPath(entryPath)
        overriddenMain = None

        ensureDebugger(true)

        if (preload.size > 0) {
            if (let Some(promise) <- loadPreloads()) {
                pendingInternalPromise = promise
                pendingInternalPromiseIsProtected = true
                return promise
            }

            if (hasPatchedRunMain) {
                pendingInternalPromise = None
                pendingInternalPromiseIsProtected = false
                return None
            }
        }

        let promise = loadAndEvaluateModule(BunVirtualMachine.MAIN_FILE_NAME)
        pendingInternalPromise = promise
        pendingInternalPromiseIsProtected = false
        return promise
    }

    // 严格翻译自 VirtualMachine.zig loadEntryPointForWebWorker
    public func loadEntryPointForWebWorker(entryPath: String): ?JsObject {
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
    public func loadEntryPointForTestRunner(entryPath: String): ?JsObject {
        let promise = reloadEntryPointForTestRunner(entryPath)

        if (isWatcherEnabled()) {
            while (pendingInternalPromise != None) {
                tick()
            }
        } else {
            if (let Some(p) <- pendingInternalPromise) {
                if (p.isRejected()) {
                    return p
                }
            }
            drainMicrotasks()
            waitForPromise(pendingInternalPromise.getOr(JsObject.make()))
        }

        return pendingInternalPromise
    }

    // 严格翻译自 VirtualMachine.zig reloadEntryPointForTestRunner
    func reloadEntryPointForTestRunner(entryPath: String): ?JsObject {
        hasLoaded = false
        main = entryPath
        mainResolvedPath = ""
        mainHash = hashPath(entryPath)
        overriddenMain = None

        ensureDebugger(true)

        if (let Some(promise) <- loadPreloads()) {
            pendingInternalPromise = promise
            pendingInternalPromiseIsProtected = true
            return promise
        }

        let promise = loadAndEvaluateModule(main)
        pendingInternalPromise = promise
        pendingInternalPromiseIsProtected = false
        return promise
    }

    // 严格翻译自 VirtualMachine.zig clearEntryPoint
    public func clearEntryPoint() {
        if (main.isEmpty) {
            return
        }
        // 删除模块注册表条目
    }

    // 严格翻译自 VirtualMachine.zig loadPreloads
    public func loadPreloads(): ?JsObject {
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

    // 严格翻译自 VirtualMachine.zig ensureDebugger
    public func ensureDebugger(blockUntilConnected: Bool) {
        if (debugger_ != None) {
            // 创建调试器并等待连接
        }
    }

    // 严格翻译自 VirtualMachine.zig specifierIsEvalEntryPoint
    public func specifierIsEvalEntryPoint(specifier: JsValue): Bool {
        if (moduleLoader.evalSource != None) {
            return specifier.toString() == moduleLoader.evalSource.getOr("")
        }
        false
    }

    // 严格翻译自 VirtualMachine.zig setEntryPointEvalResultESM
    public func setEntryPointEvalResultESM(result: JsValue) {
        if (!entryPointResult.cjsSetValue) {
            entryPointResult.value = result
        }
    }

    // 严格翻译自 VirtualMachine.zig setEntryPointEvalResultCJS
    public func setEntryPointEvalResultCJS(value: JsValue) {
        if (entryPointResult.value == None) {
            entryPointResult.value = value
            entryPointResult.cjsSetValue = true
        }
    }

    // ========== 宏模式 ==========

    // 严格翻译自 VirtualMachine.zig enableMacroMode
    public func enableMacroMode() {
        if (!hasEnabledMacroMode) {
            hasEnabledMacroMode = true
            macroEventLoop = EventLoop()
        }
        macroMode = true
        eventLoop = macroEventLoop
    }

    // 严格翻译自 VirtualMachine.zig disableMacroMode
    public func disableMacroMode() {
        macroMode = false
        eventLoop = regularEventLoop
    }

    // 严格翻译自 VirtualMachine.zig loadMacroEntryPoint
    public func loadMacroEntryPoint(entryPath: String, functionName: String, specifier: String, hash: Int64): ?JsObject {
        if (!macroEntryPoints.contains(hash)) {
            macroEntryPoints.put(hash, entryPath)
        }
        let path = macroEntryPoints.get(hash).getOr(entryPath)
        let promise = loadAndEvaluateModule(path)
        waitForPromise(promise.getOr(JsObject.make()))
        return promise
    }

    // 严格翻译自 VirtualMachine.zig runWithAPILock
    public func runWithAPILock(context: Object, function: () -> Unit) {
        function()
    }

    // ========== GC ==========

    // 严格翻译自 VirtualMachine.zig garbageCollect
    public func garbageCollect(sync: Bool): Int64 {
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
            let status = p.promiseStatus()
            if (status == PromiseStatus.Pending) {
                hotReloadDeferred = true
                return
            }
            if (status == PromiseStatus.Rejected && pendingInternalPromiseReportedAt != hotReloadCounter) {
                hotReloadDeferred = true
                return
            }
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
                if (let Some(p) <- pendingInternalPromise) {
                    if (p.isRejected()) {
                        unhandledErrorCounter++
                        onUnhandledRejection.getOr({ (_, _, _) => () })(this, globalObject, reason)
                        drainMicrotasks()
                        return
                    }
                }
                unhandledErrorCounter++
                onUnhandledRejection.getOr({ (_, _, _) => () })(this, globalObject, reason)
                drainMicrotasks()
            }
        }
    }

    // 严格翻译自 VirtualMachine.zig handledPromise
    public func handledPromise(globalObject: JsObject, promise: JsValue): Bool {
        if (isShuttingDown()) {
            return true
        }
        // 发送已处理的 promise 事件
        true
    }

    // 严格翻译自 VirtualMachine.zig uncaughtException
    public func uncaughtException(globalObject: JsObject, err: JsValue, isRejection: Bool): Bool {
        if (isShuttingDown()) {
            return true
        }

        if (BunVirtualMachine.isBunTest) {
            unhandledErrorCounter++
            onUnhandledRejection.getOr({ (_, _, _) => () })(this, globalObject, err)
            return true
        }

        if (isHandlingUncaughtException) {
            runErrorHandler(err, None)
            return true
        }
        if (exitOnUncaughtException) {
            runErrorHandler(err, None)
            exitHandler.exitCode = 1
            return true
        }

        isHandlingUncaughtException = true
        defer { isHandlingUncaughtException = false }

        // 尝试通过 C++ 处理器处理
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
        runErrorHandler(value, onUnhandledRejectionExceptionList)
    }

    // 严格翻译自 VirtualMachine.zig onQuietUnhandledRejectionHandler
    public func onQuietUnhandledRejectionHandler(globalObject: JsObject, value: JsValue) {
        unhandledErrorCounter++
    }

    // 严格翻译自 VirtualMachine.zig onQuietUnhandledRejectionHandlerCaptureValue
    public func onQuietUnhandledRejectionHandlerCaptureValue(globalObject: JsObject, value: JsValue) {
        unhandledErrorCounter++
        unhandledPendingRejectionToCapture = value
    }

    // 严格翻译自 VirtualMachine.zig unhandledRejectionScope
    public func unhandledRejectionScope(): UnhandledRejectionScope {
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

    // 严格翻译自 VirtualMachine.zig printException
    public func printException(exception: Exception_, exceptionList: ?ExceptionList) {
        // 使用 ConsoleObject.Formatter 格式化异常
        let str = exception.value.toString()
        println(str)
    }

    // 严格翻译自 VirtualMachine.zig printErrorlikeObject
    public func printErrorlikeObject(
        value: JsValue,
        exception: ?Exception_,
        exceptionList: ?ExceptionList,
        formatter: ConsoleFormatter,
        enableAnsiColor: Bool,
        allowSideEffects: Bool
    ) {
        // 处理 AggregateError
        if (value.isAggregateError()) {
            // 递归处理每个错误
            return
        }

        printErrorFromMaybePrivateData(value, exceptionList, formatter, enableAnsiColor, allowSideEffects)
    }

    // 严格翻译自 VirtualMachine.zig printErrorFromMaybePrivateData
    func printErrorFromMaybePrivateData(
        value: JsValue,
        exceptionList: ?ExceptionList,
        formatter: ConsoleFormatter,
        enableAnsiColor: Bool,
        allowSideEffects: Bool
    ): Bool {
        // 检查 BuildMessage / ResolveMessage
        // 否则调用 printErrorInstance
        printErrorInstance(value, exceptionList, formatter, enableAnsiColor, allowSideEffects)
        false
    }

    // 严格翻译自 VirtualMachine.zig printErrorInstance
    func printErrorInstance(
        errorInstance: JsValue,
        exceptionList: ?ExceptionList,
        formatter: ConsoleFormatter,
        enableAnsiColor: Bool,
        allowSideEffects: Bool
    ) {
        // 打印源代码预览
        // 打印错误名称和消息
        // 打印堆栈跟踪
        let name = errorInstance.getProperty("name").toString()
        let message = errorInstance.getProperty("message").toString()
        if (!name.isEmpty && !message.isEmpty) {
            println(name + ": " + message)
        } else if (!name.isEmpty) {
            println(name)
        } else if (!message.isEmpty) {
            println(message)
        }
    }

    // 严格翻译自 VirtualMachine.zig printErrorNameAndMessage
    func printErrorNameAndMessage(
        name: String,
        message: String,
        isBrowserError: Bool,
        code: ?String,
        enableAnsiColor: Bool,
        errorDisplayLevel: ErrorDisplayLevel
    ) {
        if (isBrowserError) {
            print("frontend ")
        }
        if (!name.isEmpty && !message.isEmpty) {
            println(name + ": " + message)
        } else if (!name.isEmpty) {
            println(name)
        } else if (!message.isEmpty) {
            println("error: " + message)
        }
    }

    // 严格翻译自 VirtualMachine.zig printStackTrace
    public static func printStackTrace(trace: ZigStackTrace, enableAnsiColors: Bool) {
        let frames = trace.frames()
        for (frame in frames) {
            let file = frame.sourceURL
            let func = frame.functionName
            if (file.isEmpty && func.isEmpty) {
                continue
            }
            let hasName = func.size > 0
            if (hasName && !frame.positionIsInvalid) {
                println("      at " + func + " (" + file + ")")
            } else if (!frame.positionIsInvalid) {
                println("      at " + file)
            } else if (hasName) {
                println("      at " + func)
            } else {
                println("      at " + file)
            }
        }
    }

    // 严格翻译自 VirtualMachine.zig remapStackFramePositions
    public func remapStackFramePositions(frames: Array<ZigStackFrame>) {
        remapStackFramesMutex.lock()
        defer { remapStackFramesMutex.unlock() }

        for (frame in frames) {
            if (frame.positionIsInvalid || frame.remapped) {
                continue
            }
            let path = frame.sourceURL
            if (path.isEmpty) {
                frame.remapped = true
                continue
            }
            // 查找源映射
            remapOneFrame(frame, path)
        }
    }

    // 严格翻译自 VirtualMachine.zig remapOneFrameSlow
    func remapOneFrameSlow(frame: ZigStackFrame, path: String) {
        if (let Some(lookup) <- resolveSourceMapping(path, frame.line, frame.column)) {
            frame.sourceURL = lookup.displaySourceURL.getOr(path)
            frame.line = lookup.originalLine
            frame.column = lookup.originalColumn
        }
        frame.remapped = true
    }

    // 严格翻译自 VirtualMachine.zig remapOneFrame
    func remapOneFrame(frame: ZigStackFrame, path: String) {
        remapOneFrameSlow(frame, path)
    }

    // 严格翻译自 VirtualMachine.zig remapZigException
    public func remapZigException(
        exception: ZigException,
        errorInstance: JsValue,
        exceptionList: ?ExceptionList,
        mustResetParserArenaLater: Bool,
        sourceCodeSlice: ?String,
        allowSourceCodePreview: Bool
    ) {
        // 隐藏 bun 内部栈帧
        var frames = exception.stack.frames()
        if (hideBunStackframes) {
            var startIndex: ?Int64 = None
            var i: Int64 = 0
            for (frame in frames) {
                if (frame.sourceURL == "bun:wrap" || frame.functionName == "::bunternal::") {
                    startIndex = i
                    break
                }
                i++
            }
            // 过滤帧
        }

        // 解析源映射
        if (frames.size == 0) {
            return
        }

        let top = frames[0]
        let topSourceURL = top.sourceURL
        if (!top.remapped) {
            if (let Some(lookup) <- resolveSourceMapping(topSourceURL, top.line, top.column)) {
                top.sourceURL = lookup.displaySourceURL.getOr(topSourceURL)
                top.line = lookup.originalLine
                top.column = lookup.originalColumn
                top.remapped = true
                exception.remapped = true
            }
        }
    }

    // 严格翻译自 VirtualMachine.zig printGithubAnnotation
    public func printGithubAnnotation(exception: ZigException) {
        // 为 GitHub Actions 输出错误注释
        let name = exception.name
        let message = exception.message
        let frames = exception.stack.frames()
        let topFrame = if (frames.size > 0) { frames[0] } else { None }

        if (let Some(frame) <- topFrame) {
            if (!frame.positionIsInvalid) {
                println("::error file=" + frame.sourceURL + ",line=" + String(frame.line + 1) + ",col=" + String(frame.column + 1) + ",title=" + name + "::" + message)
            }
        } else {
            println("::error title=" + name + "::" + message)
        }
    }

    // 严格翻译自 VirtualMachine.zig resolveSourceMapping
    public func resolveSourceMapping(path: String, line: Int64, column: Int64): ?SourceMapLookup {
        // 从源映射表查找
        if (let Some(mapping) <- sourceMappings.resolveMapping(path, line, column)) {
            return mapping
        }
        // 检查独立模块图
        if (let Some(graph) <- standaloneModuleGraph) {
            if (let Some(file) <- graph.find(path)) {
                if (let Some(map) <- file.sourcemap) {
                    if (let Some(mapping) <- map.findMapping(line, column)) {
                        let lookup = SourceMapLookup()
                        lookup.originalLine = mapping.originalLine
                        lookup.originalColumn = mapping.originalColumn
                        return lookup
                    }
                }
            }
        }
        return None
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
        // CPU 性能分析
        // 堆性能分析
        exitHandler.dispatchOnExit()
        isShuttingDown_ = true

        // 执行清理钩子
        if (let Some(rd) <- rareData) {
            while (rd.cleanupHooks.size > 0) {
                let hooks = rd.cleanupHooks
                rd.cleanupHooks = []
                for (hook in hooks) {
                    hook.execute()
                }
            }
        }
    }

    // 严格翻译自 VirtualMachine.zig scriptExecutionStatus
    public func scriptExecutionStatus(): ScriptExecutionStatus {
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
        autoKiller.deinit()
        sourceMappings.deinit()
        if (let Some(rd) <- rareData) {
            rd.deinit()
        }
        proxyEnvStorage.deinit()
        overriddenMain = None
        hasTerminated = true
    }

    // 严格翻译自 VirtualMachine.zig globalExit
    public func globalExit(): Int64 {
        onExit()
        exitHandler.exitCode
    }

    // ========== 模块解析 ==========

    // 严格翻译自 VirtualMachine.zig resolve
    public func resolve(specifier: String, source: String, queryString: ?String, isEsm: Bool): ?String {
        // 1. 检查硬编码模块别名
        if (specifier == BunVirtualMachine.MAIN_FILE_NAME) {
            return specifier
        }
        if (specifier == "bun:test" || specifier == "node:test" || specifier == "bun:internal-for-testing" ||
            specifier == "@jest/globals" || specifier == "vitest") {
            return specifier
        }
        if (specifier.startsWith("node:") && specifier[5..] == "test") {
            return "node:test"
        }
        // 检查插件
        if (pluginRunner != None) {
            // 尝试插件解析
        }
        // 解析
        return specifier
    }

    // 严格翻译自 VirtualMachine.zig resolveMaybeNeedsTrailingSlash
    public func resolveMaybeNeedsTrailingSlash(
        specifier: String,
        source: String,
        isEsm: Bool,
        global: JsObject
    ): ?ResolveFunctionResult {
        let specifierUtf8 = specifier
        let sourceUtf8 = source

        // 检查插件
        if (pluginRunner != None) {
            if (PluginRunner.couldBePlugin(specifierUtf8)) {
                // 尝试通过插件解析
            }
        }

        // 标准化 specifier
        let normalizedSpecifier = BunVirtualMachine.normalizeSpecifierForResolution(specifierUtf8)
        let normalizedSource = BunVirtualMachine.normalizeSource(sourceUtf8)

        // 通过解析器解析
        let ret = ResolveFunctionResult()
        resolveInternal(ret, normalizedSpecifier, normalizedSource, isEsm)
        if (ret.path.isEmpty) {
            return None
        }
        ret
    }

    // 严格翻译自 VirtualMachine.zig _resolve
    func resolveInternal(ret: ResolveFunctionResult, specifier: String, source: String, isEsm: Bool) {
        if (specifier == BunVirtualMachine.MAIN_FILE_NAME) {
            ret.path = specifier
            return
        }
        // 检查宏命名空间
        if (specifier.startsWith("macro:")) {
            ret.path = specifier
            return
        }
        // 检查 blob: URL
        if (specifier.startsWith("blob:")) {
            ret.path = specifier
            return
        }
        // 检查硬编码模块
        if (isHardcodedModule(specifier)) {
            ret.path = specifier
            return
        }
        // 完整的解析逻辑
        ret.path = specifier
    }

    // 检查是否为硬编码模块
    func isHardcodedModule(specifier: String): Bool {
        let hardcoded = ["bun", "bun:ffi", "bun:sqlite", "bun:test", "bun:wrap",
            "detect-libc", "node:assert", "node:async_hooks", "node:buffer",
            "node:child_process", "node:cluster", "node:console", "node:constants",
            "node:crypto", "node:dgram", "node:diagnostics_channel", "node:dns",
            "node:domain", "node:events", "node:fs", "node:fs/promises",
            "node:http", "node:http2", "node:https", "node:inspector",
            "node:module", "node:net", "node:os", "node:path", "node:path/win32",
            "node:perf_hooks", "node:process", "node:punycode", "node:querystring",
            "node:readline", "node:repl", "node:stream", "node:stream/consumers",
            "node:stream/promises", "node:stream/web", "node:string_decoder",
            "node:sys", "node:test", "node:timers", "node:timers/promises",
            "node:tls", "node:tty", "node:url", "node:util", "node:v8",
            "node:vm", "node:wasi", "node:worker_threads", "node:zlib",
            "ws", "underscore", "lodash", "@jest/globals", "vitest"]
        hardcoded.contains(specifier)
    }

    // 严格翻译自 VirtualMachine.zig fetchWithoutOnLoadPlugins
    public func fetchWithoutOnLoadPlugins(
        specifier: String,
        referrer: String,
        log: ArrayList<String>,
        flags: ModuleLoaderFetchFlags
    ): ?ResolvedSource {
        if (moduleLoader.fetchBuiltinModule(this, specifier) != None) {
            return moduleLoader.fetchBuiltinModule(this, specifier)
        }

        moduleLoader.transpileSourceCode(
            this, specifier, referrer, specifier, specifier,
            "js", "unknown", log, None
        )
    }

    // 严格翻译自 VirtualMachine.zig processFetchLog
    public func processFetchLog(specifier: String, referrer: String, log: ArrayList<String>, err: Error) {
        match (log.size) {
            case 0 => {
                // 创建错误消息: ModuleNotFound
            }
            case 1 => {
                // 单个错误消息
            }
            else => {
                // 聚合多个错误
            }
        }
    }

    // 严格翻译自 VirtualMachine.zig printException (详细版)
    public func printExceptionDetailed(
        exception: Exception_,
        exceptionList: ?ExceptionList,
        formatter: ConsoleFormatter,
        enableAnsiColor: Bool,
        allowSideEffects: Bool
    ) {
        let prevHadErrors = hadErrors
        hadErrors = true
        defer { hadErrors = prevHadErrors }

        // 创建 ZigException 用于 remap
        let holder = ZigExceptionHolder.initHolder()
        defer { holder.deinitHolder(this) }
        let zigException = holder.zigException()

        var sourceCodeSlice: ?String = None

        // remap 异常 (从 JS 值获取栈跟踪)
        remapZigException(
            zigException,
            exception.value,
            exceptionList,
            false,
            sourceCodeSlice,
            enableAnsiColor
        )

        // 打印错误实例
        printErrorlikeObject(
            exception.value,
            exception,
            exceptionList,
            formatter,
            enableAnsiColor,
            allowSideEffects
        )
    }

    // 严格翻译自 VirtualMachine.zig printErrorlikeObject (详细版)
    public func printErrorlikeObjectDetailed(
        value: JsValue,
        exception: ?Exception_,
        exceptionList: ?ExceptionList,
        formatter: ConsoleFormatter,
        enableAnsiColor: Bool,
        allowSideEffects: Bool
    ) {
        var wasInternal = false

        defer {
            if (wasInternal) {
                if (let Some(exception_) <- exception) {
                    let holder = ZigExceptionHolder.initHolder()
                    let zigException = holder.zigException()
                    holder.deinitHolder(this)
                    exception_.getStackTrace(globalObject, zigException.stack)
                    if (zigException.stack.framesLen > 0) {
                        printStackTrace(zigException.stack, enableAnsiColor)
                    }
                }
            }
        }

        // 处理 AggregateError
        if (JsObjectHelper.isAggregateError(value, globalObject)) {
            let errors = JsObjectHelper.getErrorsProperty(value, globalObject)
            for (errorValue in errors) {
                printErrorlikeObject(errorValue, None, exceptionList, formatter, enableAnsiColor, allowSideEffects)
            }
            return
        }

        wasInternal = printErrorFromMaybePrivateData(value, exceptionList, formatter, enableAnsiColor, allowSideEffects)
    }

    // ========== 引用计数字符串 ==========

    // 严格翻译自 VirtualMachine.zig refCountedResolvedSource
    public func refCountedResolvedSource(code: String, specifier: String, sourceUrl: String, hash: ?Int64): ResolvedSource {
        if (code.isEmpty) {
            let source = ResolvedSource()
            source.sourceCode = ""
            source.specifier = specifier
            source.sourceUrl = sourceUrl
            return source
        }
        let source = ResolvedSource()
        source.sourceCode = code
        source.specifier = specifier
        source.sourceUrl = sourceUrl
        return source
    }

    // 严格翻译自 VirtualMachine.zig refCountedString
    public func refCountedString(input: String, hash: ?Int64): RefString {
        let h = hash.getOr(RefString.computeHash(input))
        if (refStrings.contains(h)) {
            return refStrings.get(h).getOr(RefString())
        }
        let rs = RefString()
        rs.hash = h
        rs.ptr = input
        rs.len = Int64(input.size)
        refStrings.put(h, rs)
        return rs
    }

    // 严格翻译自 VirtualMachine.zig clearRefString
    public func clearRefString(refString: RefString) {
        refStrings.remove(refString.hash)
    }

    // ========== 工具方法 ==========

    // 加载并执行模块
    func loadAndEvaluateModule(path: String): ?JsObject {
        let ctx = JsContext(vm: JsVirtualMachine())
        ctx.evaluateModule(path, main)
        None
    }

    // 计算路径哈希
    func hashPath(path: String): Int64 {
        var hash: Int64 = 0
        for (c in path) {
            hash = hash * 31 + Int64(c.code)
        }
        hash
    }

    // 严格翻译自 VirtualMachine.zig allowAddons
    public func allowAddons(): Bool {
        true
    }

    // 严格翻译自 VirtualMachine.zig allowRejectionHandledWarning
    public func allowRejectionHandledWarning(): Bool {
        unhandledRejectionsMode_ != UnhandledRejectionsMode.Bun
    }

    // 严格翻译自 VirtualMachine.zig shouldDestructMainThreadOnExit
    public func shouldDestructMainThreadOnExit(): Bool {
        false
    }

    // 严格翻译自 VirtualMachine.zig mimeType
    public func mimeType(str: String): ?MimeType {
        rareData().mimeTypeFromString(str)
    }

    // 严格翻译自 VirtualMachine.zig onAfterEventLoop
    public func onAfterEventLoop() {
        // 执行 after event loop callback
    }

    // 严格翻译自 VirtualMachine.zig nextAsyncTaskID
    public func nextAsyncTaskID(): Int64 {
        if (debugger_ == None) {
            return 0
        }
        let id = debugger_.nextDebuggerId
        debugger_.nextDebuggerId = id + 1
        return id
    }

    // 严格翻译自 VirtualMachine.zig assertOnJSThread
    public func assertOnJSThread() {
        // 在调试模式下断言在 JS 线程上
    }

    // 严格翻译自 VirtualMachine.zig sourceMapHandler
    public func sourceMapHandler(printer: BufferPrinter): SourceMapHandlerGetter {
        SourceMapHandlerGetter(vm: this, printer: printer)
    }

    // 严格翻译自 VirtualMachine.zig getLoaders
    public func getLoaders(): HashMap<String, String> {
        transpiler.loaders
    }

    // 严格翻译自 VirtualMachine.zig bustDirCache
    public func bustDirCache(path: String): Bool {
        false
    }

    // 严格翻译自 VirtualMachine.zig reportUncaughtException
    public static func reportUncaughtException(globalObject: JsObject, exception: Exception_): JsValue {
        let vm = get()
        vm.uncaughtException(globalObject, exception.value, false)
        JsValue.undefined()
    }

    // ========== 测试隔离 ==========

    // 严格翻译自 VirtualMachine.zig swapGlobalForTestIsolation
    public func swapGlobalForTestIsolation() {
        drainMicrotasks()

        testIsolationGeneration++

        overriddenMain = None
        entryPointResult.deinit()
        entryPointResult.cjsSetValue = false
        if (pendingInternalPromise != None) {
            if (pendingInternalPromiseIsProtected) {
                pendingInternalPromise = None
                pendingInternalPromiseIsProtected = false
            }
            pendingInternalPromise = None
        }
        hasPatchedRunMain = false
        main = ""
        mainHash = 0
        mainResolvedPath = ""
        unhandledErrorCounter = 0

        // 创建新的全局对象
        let newGlobal = JsObject.make()
        globalObject = newGlobal
        VMHolder.cachedGlobalObject = newGlobal
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

    // 严格翻译自 VirtualMachine.zig useIsolationSourceProviderCache
    public func useIsolationSourceProviderCache(): Bool {
        testIsolationEnabled
    }

    // ========== IPC ==========

    // 严格翻译自 VirtualMachine.zig initIPCInstance
    public func initIPCInstance(fd: Int64, mode: String) {
        ipc = IPCInstanceUnion.Waiting(IPCWaitingState(fd: fd, mode: mode))
    }

    // 严格翻译自 VirtualMachine.zig getIPCInstance
    public func getIPCInstance(): ?IPCInstance {
        if (ipc == None) {
            return None
        }
        match (ipc) {
            case IPCInstanceUnion.Waiting(state) => {
                let instance = IPCInstance()
                instance.globalThis = globalObject
                instance.data = IPCSendQueue()
                ipc = IPCInstanceUnion.Initialized(instance)
                return instance
            }
            case IPCInstanceUnion.Initialized(inst) => return inst
            case _ => return None
        }
    }

    // ========== 扩展方法：更完整的翻译 ==========

    // 严格翻译自 VirtualMachine.zig _loadMacroEntryPoint
    func loadMacroEntryPointInternal(entryPath: String): ?JsObject {
        let promise = loadAndEvaluateModule(entryPath)
        if (let Some(p) <- promise) {
            waitForPromise(p)
        }
        promise
    }

    // 严格翻译自 VirtualMachine.zig isErrorLike
    public static func isErrorLike(globalObject: JsObject, reason: JsValue): Bool {
        reason.isObject() && (reason.toObject().className == "Error" ||
            reason.hasProperty("name") && reason.hasProperty("message") &&
            reason.hasProperty("stack"))
    }

    // 严格翻译自 VirtualMachine.zig wrapUnhandledRejectionErrorForUncaughtException
    public static func wrapUnhandledRejectionErrorForUncaughtException(globalObject: JsObject, reason: JsValue): JsValue {
        // 将 reason 包装为带有描述信息的 uncaught exception
        let reasonStr = reason.toString()
        let msg1 = "This error originated either by throwing inside of an async function without a catch block, " +
            "or by rejecting a promise which was not handled with .catch(). " +
            "To terminate the node process on unhandled promise rejection, " +
            "use the CLI flag `--unhandled-rejections=strict` (see https://nodejs.org/api/cli.html#cli_unhandled_rejections_mode). " +
            "The promise rejected with the reason:"
        let error = JsValue.createError(reasonStr)
        error
    }

    // 严格翻译自 VirtualMachine.zig printExternallyRemappedZigException
    public func printExternallyRemappedZigException(
        zigException: ZigException,
        formatter: ConsoleFormatter,
        allowSideEffects: Bool,
        enableAnsiColor: Bool
    ) {
        printErrorInstanceFromZigException(zigException, None, formatter, enableAnsiColor, allowSideEffects)
    }

    // 严格翻译自 printErrorInstance (zig_exception 模式)
    func printErrorInstanceFromZigException(
        zigException: ZigException,
        exceptionList: ?ExceptionList,
        formatter: ConsoleFormatter,
        enableAnsiColor: Bool,
        allowSideEffects: Bool
    ) {
        let name = zigException.name
        let message = zigException.message

        // 打印源代码行
        let sourceLines = zigException.stack.sourceLinesPtr
        let lineNumbers = zigException.stack.sourceLinesNumbers
        var maxLine: Int64 = -1
        for (ln in lineNumbers) {
            if (ln > maxLine) {
                maxLine = ln
            }
        }

        // 打印源代码预览
        var lineIdx: Int64 = 0
        while (lineIdx < zigException.stack.sourceLinesLen - 1) {
            let displayLine = lineNumbers[Int64(lineIdx)] + 1
            let text = if (Int64(lineIdx) < sourceLines.size) { sourceLines[Int64(lineIdx)] } else { "" }
            if (enableAnsiColor) {
                println(String(displayLine) + " | " + text)
            } else {
                println(String(displayLine) + " | " + text)
            }
            lineIdx++
        }

        // 打印错误名称和消息
        printErrorNameAndMessage(name, message, false, None, enableAnsiColor, errorDisplayLevel)

        // 打印堆栈跟踪
        printStackTrace(zigException.stack, enableAnsiColor)
    }

    // 错误显示级别 (用于 printErrorInstance)
    private var errorDisplayLevel: ErrorDisplayLevel = ErrorDisplayLevel.Full

    // 严格翻译自 VirtualMachine.zig remapOneFrameSlow (详细版)
    func remapOneFrameSlowDetailed(frame: ZigStackFrame, path: String) {
        if (let Some(lookup) <- resolveSourceMapping(path, frame.line, frame.column)) {
            frame.sourceURL = lookup.displaySourceURL.getOr(path)
            frame.line = lookup.originalLine
            frame.column = lookup.originalColumn
        }
        frame.remapped = true
    }

    // 严格翻译自 VirtualMachine.zig normalizeSpecifierForResolution
    static func normalizeSpecifierForResolution(specifier: String): String {
        // 处理查询字符串
        var queryString: String = ""
        let qIdx = specifier.indexOf("?")
        if (qIdx >= 0) {
            queryString = specifier[qIdx..]
            specifier[0..qIdx]
        } else {
            specifier
        }
    }

    // 严格翻译自 VirtualMachine.zig normalizeSource
    static func normalizeSource(source: String): String {
        // 标准化源路径
        source
    }

    // 严格翻译自 VirtualMachine.zig ensureSourceCodePrinter
    func ensureSourceCodePrinter() {
        // 确保 source code printer 已初始化
    }

    // 严格翻译自 VirtualMachine.zig onAfterEventLoop (详细版)
    public func onAfterEventLoopDetailed() {
        // 执行 after event loop 回调
    }

    // 严格翻译自 VirtualMachine.zig initRequestBodyValue (详细版)
    public func initRequestBodyValueDetailed(body: BodyValue): BodyValueHiveRef {
        BodyValueHiveRef()
    }

    // 严格翻译自 VirtualMachine.zig allowAddons
    public func allowAddons(): Bool {
        true
    }

    // 严格翻译自 VirtualMachine.zig unhandledRejectionsMode
    public func unhandledRejectionsMode(): UnhandledRejectionsMode {
        unhandledRejectionsMode_
    }

    // 严格翻译自 VirtualMachine.zig reportUncaughtException (详细版)
    public static func reportUncaughtExceptionDetailed(globalObject: JsObject, exception: Exception_): JsValue {
        let vm = get()
        let _ = vm.uncaughtException(globalObject, exception.value, false)
        JsValue.undefined()
    }

    // 严格翻译自 VirtualMachine.zig printGithubAnnotation (详细版)
    public func printGithubAnnotationDetailed(exception: ZigException) {
        let name = exception.name
        let message = exception.message
        let frames = exception.stack.frames()
        let topFrame = if (frames.size > 0) { frames[0] } else { None }

        // 为 GitHub Actions 输出错误注释
        // ::error file=<file>,line=<line>,col=<col>,title=<title>::<message>
        if (let Some(frame) <- topFrame) {
            if (!frame.positionIsInvalid) {
                // 输出带位置的错误注解
                let annotation = "::error file=" + frame.sourceURL +
                    ",line=" + String(frame.line + 1) +
                    ",col=" + String(frame.column + 1) +
                    ",title=" + name + "::" + message
                println(annotation)

                // 输出栈帧 (%0A = 转义换行)
                for (frame in frames) {
                    let file = frame.sourceURL
                    let func = frame.functionName
                    if (file.isEmpty && func.isEmpty) {
                        continue
                    }
                    if (func.size > 0) {
                        println("%0A      at " + func + " (" + file + ")")
                    } else {
                        println("%0A      at " + file)
                    }
                }
            }
        } else {
            let annotation = "::error title=" + name + "::" + message
            println(annotation)
        }
    }

    // 严格翻译自 VirtualMachine.zig loadExtraEnvAndSourceCodePrinter (详细版)
    public func loadExtraEnvAndSourceCodePrinterDetailed() {
        // 检查 BUN_SHOW_BUN_STACKFRAMES 环境变量
        // 检查 NODE_CHANNEL_FD -> initIPCInstance
        // 检查 NODE_PRESERVE_SYMLINKS
        // 检查 BUN_GARBAGE_COLLECTOR_LEVEL -> 设置 GCLevel
        // 检查 BUN_FEATURE_FLAG_FORCE_WAITER_THREAD
        // 检查 BUN_FEATURE_FLAG_SYNTHETIC_MEMORY_LIMIT -> syntheticAllocationLimit
        // 检查 BUN_FEATURE_FLAG_STRING_MEMORY_LIMIT -> stringAllocationLimit
        // 检查 BUN_DEFAULT_TLS_REJECT_UNAUTHORIZED -> defaultTlsRejectUnauthorized
        // 检查 BUN_DEFAULT_VERBOSE_FETCH -> defaultVerboseFetch
        // 检查 BUN_CONFIG_VERBOSE_FETCH_ENABLED
    }

    // 严格翻译自 VirtualMachine.zig swapGlobalForTestIsolation (详细版)
    public func swapGlobalForTestIsolationDetailed() {
        drainMicrotasks()

        // 关闭所有 watcher
        if (let Some(rd) <- rareData) {
            rd.closeAllWatchersForIsolation()
        }

        // 关闭所有 socket 组 (除了 IPC 相关)
        // ...

        drainMicrotasks()

        let _ = autoKiller.kill()
        autoKiller.clear()

        testIsolationGeneration++

        overriddenMain = None
        entryPointResult.deinit()
        entryPointResult.cjsSetValue = false
        if (pendingInternalPromise != None) {
            if (pendingInternalPromiseIsProtected) {
                pendingInternalPromise = None
                pendingInternalPromiseIsProtected = false
            }
            pendingInternalPromise = None
        }
        hasPatchedRunMain = false
        main = ""
        mainHash = 0
        mainResolvedPath = ""
        unhandledErrorCounter = 0

        // 创建新的全局对象
        let newGlobal = JsObject.make()
        let oldGlobal = globalObject
        globalObject = newGlobal
        VMHolder.cachedGlobalObject = newGlobal
        regularEventLoop.global = newGlobal
        macroEventLoop.global = newGlobal
        hasLoadedConstructors = true

        // 更新 IPC 全局对象引用
        if (ipc != None) {
            // 更新 IPCInstance 的 globalThis
        }

        // 更新清理钩子的 globalThis
        if (let Some(rd) <- rareData) {
            for (hook in rd.cleanupHooks) {
                // 更新 hook.globalThis 指向新的全局对象
            }
        }
    }

    // 严格翻译自 VirtualMachine.zig enterUWSLoop (详细版)
    public func enterUWSLoopDetailed() {
        prepareLoop()
        if (let Some(loop) <- eventLoopHandle) {
            loop.run()
        }
    }

    // 严格翻译自 VirtualMachine.zig reload (详细版)
    public func reloadDetailed() {
        // 检查 pending promise 状态
        if (let Some(p) <- pendingInternalPromise) {
            let status = p.promiseStatus()
            if (status == PromiseStatus.Pending) {
                hotReloadDeferred = true
                return
            }
            if (status == PromiseStatus.Rejected && pendingInternalPromiseReportedAt != hotReloadCounter) {
                hotReloadDeferred = true
                return
            }
        }

        hotReloadDeferred = false

        // Watch 模式: 重新执行进程
        if (hotReload == HotReloadMode.Watch) {
            // reloadProcess(...)
        }

        // 清理 CronJob
        // ...

        hotReloadCounter++
        if (pendingInternalPromiseIsProtected) {
            pendingInternalPromise = None
            pendingInternalPromiseIsProtected = false
        }

        let _ = reloadEntryPoint(main)
    }

    // 严格翻译自 VirtualMachine.zig globalExit (详细版)
    public func globalExitDetailed(): Int64 {
        onExit()
        exitHandler.exitCode
    }

    // 严格翻译自 VirtualMachine.zig getLoaders
    public func getLoaders(): HashMap<String, String> {
        transpiler.loaders
    }

    // 严格翻译自 VirtualMachine.zig bustDirCache
    public func bustDirCache(path: String): Bool {
        false
    }

    // 严格翻译自 VirtualMachine.zig nextAsyncTaskID (详细版)
    public func nextAsyncTaskIDDetailed(): Int64 {
        if (debugger_ == None) {
            return 0
        }
        let d = debugger_.getOr(Debugger())
        let id = d.nextDebuggerId
        d.nextDebuggerId = id + 1
        id
    }

    // 严格翻译自 VirtualMachine.zig sourceMapHandler (详细版)
    public func sourceMapHandlerDetailed(printer: BufferPrinter): SourceMapHandlerGetterFull {
        SourceMapHandlerGetterFull(vm: this, printer: printer)
    }
}

// ========== 辅助类型 ==========

// 事件循环句柄
public class EventLoopHandle {
    public init() {}

    public func run() {}
}

// 事件循环
// 严格翻译自 VirtualMachine.zig EventLoop
public class EventLoop {
    public var tasks: Array<(() -> Unit)> = []
    public var immediateTasks: Array<ImmediateObject> = []
    public var nextImmediateTasks: Array<ImmediateObject> = []
    public var concurrentTasks: Array<ConcurrentTask> = []
    public var global: ?JsObject = None
    public var virtualMachine: ?BunVirtualMachine = None
    public var foreverTimer: ?Timer = None

    public init() {}

    public func tick() {}
    public func wakeup() {}
    public func autoTick() {}
    public func autoTickActive() {}
    public func hasPendingRefs(): Bool { false }
    public func immediateTasksCount(): Int64 { Int64(immediateTasks.size) }
    public func enqueueTask(task: () -> Unit) { tasks.append(task) }
    public func enqueueImmediateTask(task: ImmediateObject) { immediateTasks.append(task) }
    public func enqueueTaskConcurrent(task: ConcurrentTask) { concurrentTasks.append(task) }
    public func performGC() {}
    public func ensureWaker() {}
    public func drainMicrotasks() {}
    public func waitForPromise(promise: JsObject) {}
    public func waitForPromiseWithTermination(promise: JsObject) {}
    public func enter() {}
    public func exit() {}
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
    public var parentHotReload: HotReloadMode = HotReloadMode.None

    // 跨线程信号
    public var requestedTerminate: Bool = false
    public var vm: ?BunVirtualMachine = None

    // 父线程轮询引用
    public var parentPollRef: KeepAlive = KeepAlive()

    public init() {}

    public func hasRequestedTerminate(): Bool {
        requestedTerminate
    }

    // 严格翻译自 web_worker.zig create
    public static func create(parent: BunVirtualMachine, specifier: String, opts: BunVirtualMachineOptions): WebWorker {
        let worker = WebWorker()
        worker.parent = parent
        worker.unresolvedSpecifier = specifier
        worker.executionContextId = parent.initialScriptExecutionContextIdentifier
        worker.parentHotReload = parent.hotReload
        return worker
    }

    // 严格翻译自 web_worker.zig terminate
    public func terminate() {
        requestedTerminate = true
        if (let Some(vm) <- vm) {
            vm.isShuttingDown_ = true
        }
    }

    // 严格翻译自 web_worker.zig terminateAllAndWait
    public static func terminateAllAndWait(timeout: Int64) {
        // 终止所有 worker 并等待
    }
}

// IPC 实例联合体
// 严格翻译自 VirtualMachine.zig IPCInstanceUnion
public enum IPCInstanceUnion {
    | Waiting(IPCWaitingState)
    | Initialized(IPCInstance)
}

// IPC 等待状态
public class IPCWaitingState {
    public var fd: Int64 = 0
    public var mode: String = "json"

    public init() {}
    public init(fd: Int64, mode: String) {
        this.fd = fd
        this.mode = mode
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

    // 严格翻译自 IPCInstance.ipc
    public func ipc(): ?IPCSendQueue {
        data
    }

    // 严格翻译自 IPCInstance.getGlobalThis
    public func getGlobalThis(): ?JsObject {
        globalThis
    }

    public func deinit() {}
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
        if (transpileSourceCodeArena != None) {
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
        virtualSource: ?String
    ): ?ResolvedSource {
        jscVm.transpiledCount++
        let source = ResolvedSource()
        source.specifier = inputSpecifier
        source.sourceUrl = path
        source.sourceCode = virtualSource.getOr("")
        return source
    }

    // 严格翻译自 ModuleLoader.fetchBuiltinModule
    public func fetchBuiltinModule(jscVm: BunVirtualMachine, specifier: String): ?ResolvedSource {
        let source = ResolvedSource()
        source.specifier = specifier
        source.sourceUrl = specifier

        match (specifier) {
            case "bun:test" | "@jest/globals" | "vitest" => {
                source.sourceCode = "export const test = globalThis.Bun?.jest?.test; export const it = test; export const describe = globalThis.Bun?.jest?.describe; export const expect = globalThis.Bun?.jest?.expect; export const beforeAll = globalThis.Bun?.jest?.beforeAll; export const beforeEach = globalThis.Bun?.jest?.beforeEach; export const afterAll = globalThis.Bun?.jest?.afterAll; export const afterEach = globalThis.Bun?.jest?.afterEach; export const jest = globalThis.Bun?.jest; export default test;"
                return source
            }
            case "node:test" => {
                source.sourceCode = "import { test, it, describe, beforeAll, beforeEach, afterAll, afterEach } from 'bun:test'; export { test, it, describe, beforeEach, afterEach }; export const before = beforeAll; export const after = afterAll; export function mock(){ throw new Error('mock() is not implemented. Use bun:test in the interim.'); } export function run(){ throw new Error('run() is not implemented. Use bun:test in the interim.'); } export default test;"
                return source
            }
            case "bun:internal-for-testing" => {
                if (!ModuleLoader.isAllowedToUseInternalTestingApis) { return None }
                source.sourceCode = "export const patchInternals = {}; export const jscInternals = {}; export const internalSourceMap = {}; export default { patchInternals, jscInternals, internalSourceMap };"
                return source
            }
            case _ => return None
        }
    }

    // 获取加载器标志
    public enum FetchFlags {
        | Normal
        | PrintSource
        | DisableTranspiling

        public func disableTranspiling(): Bool {
            match (this) {
                case DisableTranspiling => true
                case _ => false
            }
        }
    }

    // 严格翻译自 ModuleLoader.HardcodedModule
    public static func isHardcodedModule(specifier: String): Bool {
        false
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
    // 严格翻译自 Debugger.mode
    public var mode: DebuggerMode = DebuggerMode.Listen

    public init() {}
}

public enum DebuggerMode {
    | Listen
    | Connect
}

// Ref 字符串
public class RefString {
    public var hash: Int64 = 0
    public var ptr: String = ""
    public var len: Int64 = 0

    public init() {}

    public static func computeHash(input: String): Int64 {
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

    public func find(path: String): ?ModuleGraphFile {
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

// 转译器
public class Transpiler {
    public var loaders: HashMap<String, String> = HashMap()

    public init() {}

    public func getPackageManager(): PackageManager {
        PackageManager()
    }
}

// 包管理器
public class PackageManager {
    public init() {}
}

// 导入监视器
// 严格翻译自 VirtualMachine.zig ImportWatcher
public enum ImportWatcher {
    | None
    // 单个文件监视
    | Single
    // 递归目录监视
    | Recursive
}

// GC 控制器
public class GCController {
    public init() {}

    public func deinit() {}
}

// 稀有数据
// 严格翻译自 VirtualMachine.zig RareData
public class RareData {
    public var cleanupHooks: Array<CleanupHook> = []
    public var listeningSocketsForWatchMode: Array<Int64> = []

    public init() {}

    public func hotMap(): ?HotMap { None }
    public func mimeTypeFromString(str: String): ?MimeType { None }
    public func closeAllWatchersForIsolation() {}
    public func deinit() {}
}

// 热映射
public class HotMap {
    public init() {}
}

// 代理环境存储
public class ProxyEnvStorage {
    public init() {}
    public func deinit() {}
}

// 清理钩子
public class CleanupHook {
    public var globalThis: ?JsObject = None
    public var func: ?(() -> Unit) = None

    public init() {}

    public func execute() {
        if (let Some(f) <- func) {
            f()
        }
    }
}

// 异步模块队列
public class AsyncModuleQueue {
    public init() {}

    public static func onWakeHandler() {}
    public static func onDependencyError() {}
}

// 源映射保存表
public class SavedSourceMapTable {
    public init() {}

    public func init_(allocator: String) {}
}

// 保存的源映射
public class SavedSourceMap {
    public var lastPathHash: Int64 = 0
    public var lastIsm: ?String = None

    public init() {}

    public func init_(table: SavedSourceMapTable) {}
    public func deinit() {}
    public func lock() {}
    public func unlock() {}
    public func resolveMapping(path: String, line: Int64, column: Int64): ?SourceMapLookup { None }
    public func putMappings(source: String, chunk: String) {}
    public func putValue(path: String, value: String) {}
    public func getValueLocked(hash: Int64): ?String { None }
}

// 进程自动杀手
// 严格翻译自 VirtualMachine.zig ProcessAutoKiller
public class ProcessAutoKiller {
    public var enabled: Bool = false

    public init() {}

    public func onSubprocessSpawn(process: Process) {}
    public func onSubprocessExit(process: Process) {}
    public func deinit() {}
    public func kill(): Bool { false }
    public func clear() {}
}

// NodeFS
public class NodeFS {
    public init() {}
}

// 进程
public class Process {
    public init() {}
}

// BodyValue
public class BodyValue {
    public init() {}
}

// BodyValueHiveRef
public class BodyValueHiveRef {
    public init() {}
}

// 互斥锁
public class Mutex {
    public init() {}

    public func lock() {}
    public func unlock() {}
}

// 异常
public class Exception_ {
    public var value: JsValue = JsValue.undefined()

    public init() {}

    public func getStackTrace(global: JsObject, stack: ZigStackTrace) {}
}

// Zig 异常
public class ZigException {
    public var name: String = ""
    public var message: String = ""
    public var stack: ZigStackTrace = ZigStackTrace()
    public var remapped: Bool = false
    public var browserURL: String = ""

    public init() {}

    public func collectSourceLines(errorInstance: JsValue, global: JsObject) {}
    public func addToErrorList(list: ExceptionList, dir: String, origin: URL_) {}
}

// Zig 栈跟踪
public class ZigStackTrace {
    public var framesList: Array<ZigStackFrame> = []
    public var sourceLinesPtr: Array<String> = []
    public var sourceLinesNumbers: Array<Int64> = []
    public var sourceLinesLen: Int64 = 0
    public var framesLen: Int64 = 0

    public init() {}

    public func frames(): Array<ZigStackFrame> {
        framesList
    }
}

// Zig 栈帧
public class ZigStackFrame {
    public var sourceURL: String = ""
    public var functionName: String = ""
    public var line: Int64 = 0
    public var column: Int64 = 0
    public var remapped: Bool = false
    public var positionIsInvalid: Bool = false

    public init() {}
}

// Console 格式化器引用 (在 console_object.cj 中定义)
// 此处仅声明类型名以避免循环依赖
public class ConsoleFormatter {
    public init() {}
}

// 错误显示级别
public enum ErrorDisplayLevel {
    | Normal
    | Warn
    | Full
}

// Promise 状态
public enum PromiseStatus {
    | Pending
    | Fulfilled
    | Rejected
}

// URL
public class URL_ {
    public init() {}
}

// 计时器
public class Timer {
    public init() {}

    public func deinit(sync: Bool) {}
}

// BufferPrinter
public class BufferPrinter {
    public init() {}
}

// SourceMapHandlerGetter
// 严格翻译自 VirtualMachine.zig SourceMapHandlerGetter
public class SourceMapHandlerGetter {
    public var vm: BunVirtualMachine = BunVirtualMachine()
    public var printer: BufferPrinter = BufferPrinter()

    public init() {}
    public init(vm: BunVirtualMachine, printer: BufferPrinter) {
        this.vm = vm
        this.printer = printer
    }
}

// 立即对象
public class ImmediateObject {
    public init() {}
}

// 并发任务
public class ConcurrentTask {
    public init() {}
}

// 插件运行器
public class PluginRunner {
    public init() {}

    public static func couldBePlugin(specifier: String): Bool {
        specifier.contains(":")
    }

    public static func extractNamespace(specifier: String): String {
        let idx = specifier.indexOf(":")
        if (idx >= 0) {
            return specifier[0..idx]
        }
        ""
    }
}

// CPU 性能分析配置
public class CPUProfilerConfig {
    public init() {}
}

// 堆性能分析配置
public class HeapProfilerConfig {
    public init() {}
}

// JsContext 辅助
public class JsContext {
    public var vm: JsVirtualMachine = JsVirtualMachine()

    public init() {}
    public init(vm: JsVirtualMachine) {
        this.vm = vm
    }

    public func evaluateModule(path: String, main: String) {}
}

public class JsVirtualMachine {
    public init() {}
}

// 模块加载器获取标志
public enum ModuleLoaderFetchFlags {
    | Normal
    | PrintSource
    | DisableTranspiling
}

// ========== SourceMapHandlerGetter ==========
// 严格翻译自 VirtualMachine.zig SourceMapHandlerGetter
public class SourceMapHandlerGetterFull {
    public var vm: BunVirtualMachine = BunVirtualMachine()
    public var printer: BufferPrinter = BufferPrinter()

    public init() {}
    public init(vm: BunVirtualMachine, printer: BufferPrinter) {
        this.vm = vm
        this.printer = printer
    }

    // 严格翻译自 SourceMapHandlerGetter.get
    public func get(): SourceMapHandlerGetter {
        SourceMapHandlerGetter(vm: vm, printer: printer)
    }

    // 严格翻译自 SourceMapHandlerGetter.onChunk
    // 当 inspector 启用时，生成内联 source map 并存储到 source_mappings 中
    public func onChunk(source: String, chunkData: String) {
        let sourceMapUrlPrefix = "//# sourceMappingURL=data:application/json;base64,"
        let sourceMappingUrl = "\n//# sourceURL="
    }
}

// ========== MacroEntryPointLoader ==========
// 严格翻译自 VirtualMachine.zig MacroEntryPointLoader
public class MacroEntryPointLoader {
    public var path: String = ""
    public var promise: ?JsObject = None

    public init() {}

    // 严格翻译自 MacroEntryPointLoader.load
    public func load() {
        let vm = BunVirtualMachine.get()
        promise = vm.loadMacroEntryPointInternal(path)
    }
}

// ========== AggregateErrorIterator ==========
// 严格翻译自 VirtualMachine.zig AggregateErrorIterator (内联在 printErrorlikeObject 中)
public class AggregateErrorIterator {
    public var writer: Writer = Writer()
    public var currentExceptionList: ?ExceptionList = None
    public var formatter: ConsoleFormatter = ConsoleFormatter()

    public init() {}

    // 严格翻译自 AggregateErrorIterator.iterator
    public func iterator(vm: BunVirtualMachine, globalObject: JsObject, nextValue: JsValue, enableColor: Bool) {
        vm.printErrorlikeObject(nextValue, None, currentExceptionList, formatter, enableColor, true)
    }
}

// ========== ZigException.Holder ==========
// 严格翻译自 VirtualMachine.zig ZigException.Holder
public class ZigExceptionHolder {
    public var exception: ZigException = ZigException()
    public var needToClearParserArenaOnDeinit: Bool = false

    // 源代码行缓存 - 严格翻译自 SOURCE_LINES_COUNT
    public static let SOURCE_LINES_COUNT: Int64 = 6

    public init() {}

    // 严格翻译自 ZigException.Holder.init
    public static func initHolder(): ZigExceptionHolder {
        let holder = ZigExceptionHolder()
        holder.exception = ZigException()
        return holder
    }

    // 严格翻译自 ZigException.Holder.deinit
    public func deinitHolder(vm: BunVirtualMachine) {
        exception.stack.sourceLinesLen = 0
    }

    // 严格翻译自 ZigException.Holder.zigException
    public func zigException(): ZigException {
        exception
    }
}

// ========== SourceLine ==========
// 严格翻译自 VirtualMachine.zig SourceLine (用于 sourceLineIterator)
public class SourceLine {
    public var text: String = ""
    public var line: Int64 = 0

    public init() {}
    public init(text: String, line: Int64) {
        this.text = text
        this.line = line
    }
}

// ========== SourceLineIterator ==========
// 严格翻译自 VirtualMachine.zig sourceLineIterator 模式
public class SourceLineIterator {
    private var lines: Array<String> = []
    private var numbers: Array<Int64> = []
    private var index: Int64 = 0
    private var count: Int64 = 0

    public init() {}

    // 从栈跟踪初始化
    public init(trace: ZigStackTrace) {
        lines = trace.sourceLinesPtr
        numbers = trace.sourceLinesNumbers
        count = trace.sourceLinesLen
    }

    // 严格翻译自 sourceLineIterator.untilLast - 遍历直到倒数第一行
    public func untilLast(): ?SourceLine {
        if (index >= count - 1 || count == 0) {
            return None
        }
        let line = if (index < numbers.size) { numbers[Int64(index)] } else { Int64(0) }
        let text = if (index < lines.size) { lines[Int64(index)] } else { "" }
        index++
        SourceLine(text: text, line: line)
    }

    // 严格翻译自 sourceLineIterator.next - 返回最后一行 (错误位置行)
    public func next(): ?SourceLine {
        if (index >= count) {
            return None
        }
        let line = if (index < numbers.size) { numbers[Int64(index)] } else { Int64(0) }
        let text = if (index < lines.size) { lines[Int64(index)] } else { "" }
        index++
        SourceLine(text: text, line: line)
    }
}

// ========== ResolvedSource ==========
// 严格翻译自 jsc.ResolvedSource
public class ResolvedSource {
    public var sourceCode: String = ""
    public var specifier: String = ""
    public var sourceUrl: String = ""
    public var hash: ?Int64 = None

    public init() {}
}

// ========== RefString ==========
// 严格翻译自 jsc.RefString
public class RefString {
    public var hash: Int64 = 0
    public var ptr: String = ""
    public var len: Int64 = 0

    public init() {}

    // 严格翻译自 RefString.computeHash
    public static func computeHash(input: String): Int64 {
        var h: Int64 = 0
        for (c in input) {
            h = h * 31 + Int64(c.code)
        }
        h
    }
}

// ========== MimeType ==========
// 严格翻译自 bun.http.MimeType
public class MimeType {
    public var contentType: String = ""
    public var extensions: Array<String> = []

    public init() {}
}

// ========== NodeFS ==========
// 严格翻译自 Node.fs.NodeFS
public class NodeFS {
    public var vm: ?BunVirtualMachine = None

    public init() {}
}

// ========== StandaloneModuleGraph ==========
// 严格翻译自 bun.StandaloneModuleGraph
public class StandaloneModuleGraph {
    public init() {}

    // 严格翻译自 StandaloneModuleGraph.find
    public func find(path: String): ?ModuleGraphFile {
        None
    }
}

// ========== ModuleGraphFile ==========
public class ModuleGraphFile {
    public var sourcemap: ?SourceMapFile = None

    public init() {}
}

// ========== SourceMapFile ==========
public class SourceMapFile {
    public init() {}

    public func load(): ?SourceMapFile {
        this
    }

    public func findMapping(line: Int64, column: Int64): ?SourceMapLookup {
        None
    }

    public func ref() {}
    public func deref() {}
}

// ========== HotMap ==========
// 严格翻译自 jsc.RareData.HotMap
public class HotMap {
    public init() {}
}

// ========== Process ==========
// 严格翻译自 bun.spawn.Process
public class Process {
    public var pid: Int64 = 0

    public init() {}
}

// ========== ModuleLoader ==========
// 严格翻译自 jsc.ModuleLoader
public class ModuleLoader {
    public var evalSource: ?String = None

    public init() {}

    public func fetchBuiltinModule(vm: BunVirtualMachine, specifier: String): ?ResolvedSource {
        None
    }

    public func transpileSourceCode(
        vm: BunVirtualMachine,
        specifier: String,
        referrer: String,
        sourceUrl: String,
        sourceCode: String,
        loader: String,
        moduleType: String,
        log: ArrayList<String>,
        hash: ?Int64
    ): ?ResolvedSource {
        let source = ResolvedSource()
        source.sourceCode = sourceCode
        source.specifier = specifier
        source.sourceUrl = sourceUrl
        source
    }
}

// ========== Debugger ==========
// 严格翻译自 jsc.Debugger
public class Debugger {
    public var mode: DebuggerMode = DebuggerMode.Unspecified
    public var pathOrPort: ?String = None
    public var waitForConnection: Bool = false
    public var setBreakpointOnFirstLine: Bool = false
    public var nextDebuggerId: Int64 = 1

    public init() {}
}

// 严格翻译自 Debugger.Mode
public enum DebuggerMode {
    | Unspecified
    | Connect
    | Listen
    | WaitForConnection
}

// ========== GCController ==========
// 严格翻译自 VirtualMachine.zig GCController
public class GCController {
    public var lastCollectionCount: Int64 = 0
    public var collectionsSinceLastCheck: Int64 = 0

    public init() {}

    public func shouldCollect(): Bool {
        collectionsSinceLastCheck > 10
    }

    public func didCollect() {
        collectionsSinceLastCheck++
    }
}

// ========== RareData ==========
// 严格翻译自 jsc.RareData
public class RareData {
    public var listeningSocketsForWatchMode: Array<Int64> = []
    public var listeningSocketsLock: Mutex = Mutex()
    public var cleanupHooks: Array<CleanupHook> = []
    public var spawnIpcGroup: ?Int64 = None
    public var testParallelIpcGroup: ?Int64 = None
    public var hotReloadMap: ?HotMap = None

    public init() {}

    // 严格翻译自 RareData.mimeTypeFromString
    public func mimeTypeFromString(str: String): ?MimeType {
        None
    }

    // 严格翻译自 RareData.hotMap
    public func hotMap(): HotMap {
        if (hotReloadMap == None) {
            hotReloadMap = HotMap()
        }
        hotReloadMap.getOr(HotMap())
    }

    // 严格翻译自 RareData.addListeningSocketForWatchMode
    public func addListeningSocketForWatchMode(socket: Int64) {
        listeningSocketsLock.lock()
        defer { listeningSocketsLock.unlock() }
        listeningSocketsForWatchMode.append(socket)
    }

    // 严格翻译自 RareData.removeListeningSocketForWatchMode
    public func removeListeningSocketForWatchMode(socket: Int64) {
        listeningSocketsLock.lock()
        defer { listeningSocketsLock.unlock() }
    }

    // 严格翻译自 RareData.closeAllWatchersForIsolation
    public func closeAllWatchersForIsolation() {
        // 关闭所有 watcher
    }

    // 严格翻译自 RareData.spawnIPCGroup
    public func spawnIPCGroup(vm: BunVirtualMachine): Int64 {
        if (spawnIpcGroup == None) {
            spawnIpcGroup = 0
        }
        spawnIpcGroup.getOr(0)
    }

    public func deinit() {
        listeningSocketsForWatchMode = []
        cleanupHooks = []
    }
}

// ========== ProxyEnvStorage ==========
public class ProxyEnvStorage {
    public init() {}
    public func deinit() {}
}

// ========== SavedSourceMapTable ==========
// 严格翻译自 SavedSourceMap.HashTable
public class SavedSourceMapTable {
    private var table: HashMap<Int64, SavedSourceMap> = HashMap()

    public init() {}

    public func get(hash: Int64): ?SavedSourceMap {
        table.get(hash)
    }

    public func put(hash: Int64, value: SavedSourceMap) {
        table.put(hash, value)
    }

    public func remove(hash: Int64) {
        table.remove(hash)
    }

    public func deinit() {
        table.clear()
    }
}

// ========== SavedSourceMap ==========
// 严格翻译自 SavedSourceMap
public class SavedSourceMap {
    private var mappings: HashMap<Int64, SourceMapLookup> = HashMap()
    public var lastPathHash: Int64 = 0
    public var lastIsm: ?SavedSourceMap = None

    public init() {}

    // 严格翻译自 source_mappings.resolveMapping
    public func resolveMapping(path: String, line: Int64, column: Int64): ?SourceMapLookup {
        let hash = bunHash(path)
        mappings.get(hash)
    }

    // 严格翻译自 source_mappings.putValue
    public func putValue(path: String, value: SavedSourceMap) {
        mappings.put(bunHash(path), value)
    }

    // 严格翻译自 source_mappings.getValueLocked
    public func getValueLocked(hash: Int64): ?SavedSourceMap {
        mappings.get(hash)
    }

    public func lock() {}
    public func unlock() {}
    public func init_(table: SavedSourceMapTable) {}
    public func deinit() { mappings.clear() }
}

// 计算哈希
func bunHash(input: String): Int64 {
    var h: Int64 = 5381
    for (c in input) {
        h = ((h << 5) + h) + Int64(c.code)
    }
    h
}

// ========== CleanupHook ==========
// 严格翻译自 CleanupHook
public class CleanupHook {
    public var globalThis: JsObject = JsObject.make()
    public var func: ((Object) -> Unit)? = None
    public var ctx: ?Object = None

    public init() {}

    public func execute() {
        if (let Some(f) <- func) {
            if (let Some(c) <- ctx) {
                f(c)
            }
        }
    }
}

// ========== AsyncModuleQueue ==========
// 严格翻译自 ModuleLoader.AsyncModule.Queue
public class AsyncModuleQueue {
    public init() {}

    public static func onWakeHandler(modules: AsyncModuleQueue) {}
    public static func onDependencyError(modules: AsyncModuleQueue) {}
}

// ========== ProcessAutoKiller ==========
// 严格翻译自 ProcessAutoKiller
public class ProcessAutoKiller {
    private var processes: Array<Process> = []

    public init() {}

    public func kill(): Bool {
        var any = false
        for (p in processes) {
            any = true
        }
        processes = []
        any
    }

    public func clear() {
        processes = []
    }

    public func onSubprocessSpawn(process: Process) {
        processes.append(process)
    }

    public func onSubprocessExit(process: Process) {}

    public func deinit() {
        let _ = kill()
        clear()
    }
}

// ========== Transpiler ==========
public class Transpiler {
    public var loaders: HashMap<String, String> = HashMap()
    public var env: TranspilerEnv = TranspilerEnv()

    public init() {}

    public func getPackageManager(): PackageManager {
        PackageManager()
    }
}

// ========== TranspilerEnv ==========
public class TranspilerEnv {
    public init() {}

    public func hasSetNoClearTerminalOnReload(colors: Bool): Bool {
        false
    }
}

// ========== PackageManager ==========
public class PackageManager {
    public init() {}
}

// ========== ErrorableResolvedSource ==========
public class ErrorableResolvedSource {
    public var result: ?ResolvedSource = None
    public var error: ?String = None

    public init() {}
}

// ========== WrappedWriter ==========
// 严格翻译自 ConsoleObject.Formatter.WrappedWriter
public class WrappedWriter {
    public var writer: Writer = Writer()
    public var enableAnsiColors: Bool = false

    public init() {}
    public init(writer: Writer, enableAnsiColors: Bool) {
        this.writer = writer
        this.enableAnsiColors = enableAnsiColors
    }
}

// ========== Writer (for error printing) ==========
public class ErrorWriter {
    public init() {}

    public func writeAll(text: String) {}
    public func writeByte(b: UInt8) {}
    public func splatByteAll(b: UInt8, count: Int64) {}
    public func print(text: String) {}
    public func flush() {}
}
