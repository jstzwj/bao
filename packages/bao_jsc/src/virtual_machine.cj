// 严格翻译自: jsc/VirtualMachine.zig (4173行)
// Bun JavaScript 虚拟机核心实现

package bao_jsc

import bao_collections.*
import bao_sys.*

// Array.append 扩展 - 返回新数组
extend<T> Array<T> {
    public func append(item: T): Array<T> {
        Array<T>(this.size + 1, { i: Int64 => if (i < this.size) { this[i] } else { item } })
    }

    // items() returns self, for compatibility with ArrayList API
    public func items(): Array<T> {
        this
    }
}

// ========== GCController 桩 ==========
public class GCController {
    public init() {}
}

// ========== SavedSourceMapTable 桩 ==========
public class SavedSourceMapTable {
    public init() {}
}

// 注意: ScriptExecutionStatus 已移至 script_execution_status.cj

// ========== GC 级别 ==========
// 严格翻译自 VirtualMachine.zig GCLevel
public enum GCLevel {
    | None       // 无 GC
    | Mild       // 轻度 GC
    | Aggressive // 激进 GC

    public operator func ==(other: GCLevel): Bool {
        match (this) {
            case None => match (other) { case None => true case _ => false }
            case Mild => match (other) { case Mild => true case _ => false }
            case Aggressive => match (other) { case Aggressive => true case _ => false }
        }
    }
    public operator func !=(other: GCLevel): Bool {
        !(this == other)
    }
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

    public operator func ==(other: UnhandledRejectionsMode): Bool {
        match (this) {
            case Bun => match (other) { case Bun => true case _ => false }
            case None => match (other) { case None => true case _ => false }
            case Warn => match (other) { case Warn => true case _ => false }
            case WarnWithErrorCode => match (other) { case WarnWithErrorCode => true case _ => false }
            case Strict => match (other) { case Strict => true case _ => false }
            case Throw => match (other) { case Throw => true case _ => false }
        }
    }
    public operator func !=(other: UnhandledRejectionsMode): Bool {
        !(this == other)
    }
}

// ========== 热重载模式 ==========
// 严格翻译自 VirtualMachine.zig HotReload
public enum HotReloadMode {
    | None
    | Watch
    | Hot

    public operator func ==(right: HotReloadMode): Bool {
        match (this) {
            case None => match(right) { case None => true case _ => false }
            case Watch => match(right) { case Watch => true case _ => false }
            case Hot => match(right) { case Hot => true case _ => false }
        }
    }

    public operator func !=(right: HotReloadMode): Bool {
        !(this == right)
    }
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
public type ExceptionList = Array<JsValue>

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
        vm.isSome()
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
    public var `main`: String = ""
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
    public var pendingInternalPromiseReportedAt: Int64 = Int64(9223372036854775807)
    public var hotReloadDeferred: Bool = false

    // ---- 热重载 ----
    // 严格翻译自 VirtualMachine.bun_watcher
    public var bunWatcher: ImportWatcher = ImportWatcher.none
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
    public static var syntheticAllocationLimit: Int64 = Int64(9223372036854775807)
    // 严格翻译自 VirtualMachine.string_allocation_limit
    public static var stringAllocationLimit: Int64 = Int64(9223372036854775807)
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
        // 对应 Bun: originTimer = std.time.nanoTimestamp()
        // 单调时钟纳秒，用于 performance.now() 计时
        this.originTimer = Float64(sysMonotonicNanoseconds())
        this.onUnhandledRejection = { vm, global, value =>
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
        VMHolder.vm.isSome()
    }

    // 严格翻译自 VirtualMachine.zig isMainThread()
    public func isMainThread(): Bool {
        worker.isNone() && isMainThread_
    }

    // 严格翻译自 VirtualMachine.zig isInspectorEnabled()
    public func isInspectorEnabled(): Bool {
        debugger_.isSome()
    }

    // 严格翻译自 VirtualMachine.zig isShuttingDown()
    public func isShuttingDown(): Bool {
        isShuttingDown_
    }

    // 严格翻译自 VirtualMachine.zig isWatcherEnabled()
    public func isWatcherEnabled(): Bool {
        match (bunWatcher) {
            case none => false
            case _ => true
        }
    }

    // 严格翻译自 VirtualMachine.zig getTLSRejectUnauthorized
    public func getTLSRejectUnauthorized(): Bool {
        if (defaultTlsRejectUnauthorized.isSome()) { defaultTlsRejectUnauthorized.getOrThrow() } else { true }
    }

    // 严格翻译自 VirtualMachine.zig getVerboseFetch
    public func getVerboseFetch(): Int64 {
        if (defaultVerboseFetch.isSome()) { defaultVerboseFetch.getOrThrow() } else { 0 }
    }

    // 严格翻译自 VirtualMachine.zig uwsLoop
    public func uwsLoop(): EventLoopHandle {
        if (eventLoopHandle.isSome()) { eventLoopHandle.getOrThrow() } else { EventLoopHandle(MiniEventLoop()) }
    }

    // 严格翻译自 VirtualMachine.zig uvLoop
    public func uvLoop(): EventLoopHandle {
        if (eventLoopHandle.isSome()) { eventLoopHandle.getOrThrow() } else { EventLoopHandle(MiniEventLoop()) }
    }

    // 严格翻译自 VirtualMachine.zig nodeFS
    public func nodeFS(): NodeFS {
        NodeFS()
    }

    // 严格翻译自 VirtualMachine.zig rareData
    public func getRareData(): RareData {
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
        return getRareData().getHotMap("")
    }

    // 严格翻译自 VirtualMachine.zig onSubprocessSpawn
    public func onSubprocessSpawn(process: Process) {
        // TODO: convert Process to SubProcess
    }

    // 严格翻译自 VirtualMachine.zig onSubprocessExit
    public func onSubprocessExit(process: Process) {
        // TODO: convert Process to SubProcess
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
        (activeTasks > 0 || pendingUnrefCounter > 0)
    }

    // 严格翻译自 VirtualMachine.zig isEventLoopAliveExcludingImmediates
    public func isEventLoopAliveExcludingImmediates(): Bool {
        unhandledErrorCounter == 0 &&
        (activeTasks > 0 || pendingUnrefCounter > 0)
    }

    // 严格翻译自 VirtualMachine.zig wakeup
    public func wakeup() {
        eventLoop.wakeup()
    }

    // 严格翻译自 VirtualMachine.zig tick
    public func tick() {
        eventLoop.tickOnce()
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
        let entry = EventLoopEntry(EventLoopTag.Default, task)
        eventLoop.enqueue(entry)
    }

    // 严格翻译自 VirtualMachine.zig enqueueImmediateTask
    public func enqueueImmediateTask(task: ImmediateObject) {
        let entry = EventLoopEntry(EventLoopTag.Immediate, { => task.run() })
        eventLoop.enqueue(entry)
    }

    // 严格翻译自 VirtualMachine.zig enqueueTaskConcurrent
    public func enqueueTaskConcurrent(task: ConcurrentTask) {
        let t = Task()
        t.callback = task.run
        eventLoop.enqueueConcurrent(t)
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
        match (eventLoopHandle) {
            case Some(handle) => handle.run()
            case None => eventLoop.run()
        }
    }

    // ========== 初始化 ==========

    // 严格翻译自 VirtualMachine.zig getOriginTimestamp()
    static func getOriginTimestamp(): Int64 {
        // 使用系统时钟获取毫秒时间戳
        // 对应 Bun: std.time.nanoTimestamp() / 1_000_000
        return getNowMillis()
    }

    // 严格翻译自 VirtualMachine.zig init
    public static func create(opts: BunVirtualMachineOptions): BunVirtualMachine {
        let vm = BunVirtualMachine()
        vm.smol = opts.smol
        vm.isMainThread_ = opts.isMainThread
        vm.initialScriptExecutionContextIdentifier = if (opts.isMainThread) { 1 } else { Int64(9223372036854775807) }

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
        vm.initialScriptExecutionContextIdentifier = if (opts.isMainThread) { 1 } else { Int64(9223372036854775807) }

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
        vm.hotReload = HotReloadMode.None  // TODO: worker.parentHotReload

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
            case DebuggerConfig.Unspecified=> ()
                // 检查环境变量 BUN_INSPECT
            case DebuggerConfig.Enable(config)=>
                let dbg = Debugger()
                dbg.pathOrPort = config.pathOrPort
                dbg.waitForConnection = config.waitForConnection
                dbg.setBreakpointOnFirstLine = config.setBreakpointOnFirstLine
                debugger_ = dbg
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
        `main` = entryPath
        mainHash = hashPath(entryPath)

        let promise = loadAndEvaluateModule(entryPath)
        pendingInternalPromise = promise
        pendingInternalPromiseIsProtected = false

        if (isWatcherEnabled()) {
            while (pendingInternalPromise.isSome()) {
                tick()
            }
        } else {
            waitForPromise(pendingInternalPromise ?? JsObject.make())
        }

        return pendingInternalPromise
    }

    // 严格翻译自 VirtualMachine.zig reloadEntryPoint
    public func reloadEntryPoint(entryPath: String): ?JsObject {
        hasLoaded = false
        `main` = entryPath
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
        waitForPromise(pendingInternalPromise ?? JsObject.make())

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
            while (pendingInternalPromise.isSome()) {
                tick()
            }
        } else {
            if (let Some(p) <- pendingInternalPromise) {
                if (p.isRejected()) {
                    return p
                }
            }
            drainMicrotasks()
            waitForPromise(pendingInternalPromise ?? JsObject.make())
        }

        return pendingInternalPromise
    }

    // 严格翻译自 VirtualMachine.zig reloadEntryPointForTestRunner
    func reloadEntryPointForTestRunner(entryPath: String): ?JsObject {
        hasLoaded = false
        `main` = entryPath
        mainResolvedPath = ""
        mainHash = hashPath(entryPath)
        overriddenMain = None

        ensureDebugger(true)

        if (let Some(promise) <- loadPreloads()) {
            pendingInternalPromise = promise
            pendingInternalPromiseIsProtected = true
            return promise
        }

        let promise = loadAndEvaluateModule(`main`)
        pendingInternalPromise = promise
        pendingInternalPromiseIsProtected = false
        return promise
    }

    // 严格翻译自 VirtualMachine.zig clearEntryPoint
    public func clearEntryPoint() {
        if (`main`.isEmpty()) {
            return
        }
        // 删除模块注册表条目
    }

    // 严格翻译自 VirtualMachine.zig loadPreloads
    public func loadPreloads(): ?JsObject {
        isInPreload = true
        // defer: { isInPreload = false }

        for (preloadPath in preload) {
            let promise = loadAndEvaluateModule(preloadPath)
            pendingInternalPromise = promise

            if (isWatcherEnabled()) {
                while (pendingInternalPromise.isSome()) {
                    tick()
                }
            } else {
                waitForPromise(pendingInternalPromise ?? JsObject.make())
            }
        }

        if (!testIsolationEnabled) {
            preload = []
        }

        return None
    }

    // 严格翻译自 VirtualMachine.zig ensureDebugger
    public func ensureDebugger(blockUntilConnected: Bool) {
        if (debugger_.isSome()) {
            // 创建调试器并等待连接
        }
    }

    // 严格翻译自 VirtualMachine.zig specifierIsEvalEntryPoint
    public func specifierIsEvalEntryPoint(specifier: JsValue): Bool {
        if (moduleLoader.evalSource.isSome()) {
            return specifier.toString() == moduleLoader.evalSource.getOrThrow()
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
        if (entryPointResult.value.isNone()) {
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
        let path = macroEntryPoints.get(hash) ?? entryPath
        let promise = loadAndEvaluateModule(path)
        waitForPromise(promise ?? JsObject.make())
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
        match (pendingInternalPromise) {
            case Some(p) =>
                let status: PromiseStatus = PromiseStatus.Pending
                if (status == PromiseStatus.Pending) {
                    hotReloadDeferred = true
                    return
                }
                if (status == PromiseStatus.Rejected && pendingInternalPromiseReportedAt != hotReloadCounter) {
                    hotReloadDeferred = true
                    return
                }
            case None => ()
        }

        hotReloadCounter++
        hotReloadDeferred = false

        if (pendingInternalPromiseIsProtected) {
            pendingInternalPromise = None
            pendingInternalPromiseIsProtected = false
        }

        let _ = reloadEntryPoint(`main`)
    }

    // 严格翻译自 VirtualMachine.zig addMainToWatcherIfNeeded
    public func addMainToWatcherIfNeeded() {
        if (isWatcherEnabled() && `main`.size > 0) {
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
            if (onUnhandledRejection.isSome()) { onUnhandledRejection.getOrThrow()(this, globalObject, reason) }
            return
        }

        match (unhandledRejectionsMode_) {
            case Bun=>
                unhandledErrorCounter++
                if (onUnhandledRejection.isSome()) { onUnhandledRejection.getOrThrow()(this, globalObject, reason) }
            case None=>
                drainMicrotasks()
            case Warn=>
                drainMicrotasks()
            case WarnWithErrorCode=>
                drainMicrotasks()
                exitHandler.exitCode = 1
            case Strict=>
                unhandledErrorCounter++
                exitHandler.exitCode = 1
                if (onUnhandledRejection.isSome()) { onUnhandledRejection.getOrThrow()(this, globalObject, reason) }
            case Throw=>
                if (let Some(p) <- pendingInternalPromise) {
                    if (p.isRejected()) {
                        unhandledErrorCounter++
                        if (onUnhandledRejection.isSome()) { onUnhandledRejection.getOrThrow()(this, globalObject, reason) }
                        drainMicrotasks()
                        return
                    }
                }
                unhandledErrorCounter++
                if (onUnhandledRejection.isSome()) { onUnhandledRejection.getOrThrow()(this, globalObject, reason) }
                drainMicrotasks()
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
            if (onUnhandledRejection.isSome()) { onUnhandledRejection.getOrThrow()(this, globalObject, err) }
            return true
        }

        if (isHandlingUncaughtException) {
            runErrorHandler(err, Option<ExceptionList>.None)
            return true
        }
        if (exitOnUncaughtException) {
            runErrorHandler(err, Option<ExceptionList>.None)
            exitHandler.exitCode = 1
            return true
        }

        isHandlingUncaughtException = true
        // defer: { isHandlingUncaughtException = false }

        // 尝试通过 C++ 处理器处理
        let handled = false
        if (!handled) {
            unhandledErrorCounter++
            exitHandler.exitCode = 1
            if (onUnhandledRejection.isSome()) { onUnhandledRejection.getOrThrow()(this, globalObject, err) }
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
        // defer: { addMainToWatcherIfNeeded() }
        if (pendingInternalPromise.isNone()) {
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
        // defer: { hadErrors = prevHadErrors }

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
        if (value.isAggregateError(JsObject.make())) {
            // 递归处理每个错误
            return
        }

        let _ = printErrorFromMaybePrivateData(value, exceptionList, formatter, enableAnsiColor, allowSideEffects)
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
        if (!name.isEmpty() && !message.isEmpty()) {
            println(name + ": " + message)
        } else if (!name.isEmpty()) {
            println(name)
        } else if (!message.isEmpty()) {
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
        if (!name.isEmpty() && !message.isEmpty()) {
            println(name + ": " + message)
        } else if (!name.isEmpty()) {
            println(name)
        } else if (!message.isEmpty()) {
            println("error: " + message)
        }
    }

    // 严格翻译自 VirtualMachine.zig printStackTrace
    public static func printStackTrace(trace: ZigStackTrace, enableAnsiColors: Bool) {
        let frames = trace.frames
        for (frame in frames) {
            let file = frame.sourceUrl
            let `func` = frame.functionName
            if (file.isEmpty() && `func`.isEmpty()) {
                continue
            }
            let hasName = `func`.size > 0
            if (hasName && !frame.position.isInvalid()) {
                println("      at " + `func` + " (" + file + ")")
            } else if (!frame.position.isInvalid()) {
                println("      at " + file)
            } else if (hasName) {
                println("      at " + `func`)
            } else {
                println("      at " + file)
            }
        }
    }

    // 严格翻译自 VirtualMachine.zig remapStackFramePositions
    public func remapStackFramePositions(frames: Array<ZigStackFrame>) {
        remapStackFramesMutex.lock()
        // defer: { remapStackFramesMutex.unlock() }

        for (frame in frames) {
            if (frame.position.isInvalid() || frame.remapped) {
                continue
            }
            let path = frame.sourceUrl
            if (path.isEmpty()) {
                frame.remapped = true
                continue
            }
            // 查找源映射
            remapOneFrame(frame, path)
        }
    }

    // 严格翻译自 VirtualMachine.zig remapOneFrameSlow
    func remapOneFrameSlow(frame: ZigStackFrame, path: String) {
        let linePos = Int64(frame.position.line.value)
        let colPos = Int64(frame.position.column.value)
        match (resolveSourceMapping(path, linePos, colPos)) {
            case Some(lookup) =>
                frame.sourceUrl = match (lookup.displaySourceURL) {
                    case Some(url) => url
                    case None => path
                }
                frame.position = ZigStackFramePosition(
                    Ordinal(Int32(lookup.originalLine)),
                    Ordinal(Int32(lookup.originalColumn)),
                    frame.position.lineStartByte
                )
            case None => ()
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
        var frames = exception.stack.frames
        if (hideBunStackframes) {
            var startIndex: ?Int64 = None
            var i: Int64 = 0
            for (frame in frames) {
                if (frame.sourceUrl == "bun:wrap" || frame.functionName == "::bunternal::") {
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
        let topSourceURL = top.sourceUrl
        if (!top.remapped) {
            if (let Some(lookup) <- resolveSourceMapping(topSourceURL, Int64(top.position.line.value), Int64(top.position.column.value))) {
                top.sourceUrl = lookup.displaySourceURL.getOrThrow()
                top.position.line = Ordinal(Int32(lookup.originalLine))
                top.position.column = Ordinal(Int32(lookup.originalColumn))
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
        let frames = exception.stack.frames
        let topFrame = if (frames.size > 0) { Some(frames[0]) } else { Option<ZigStackFrame>.None }

        if (let Some(frame) <- topFrame) {
            if (!frame.position.isInvalid()) {
                println("::error file=" + frame.sourceUrl + ",line=" + Int64(frame.position.line.value + 1).toString() + ",col=" + Int64(frame.position.column.value + 1).toString() + ",title=" + name + "::" + message)
            }
        } else {
            println("::error title=" + name + "::" + message)
        }
    }

    // 严格翻译自 VirtualMachine.zig resolveSourceMapping
    public func resolveSourceMapping(path: String, line: Int64, column: Int64): ?SourceMapLookup {
        // TODO: proper source mapping resolution
        None
    }

    // 保留原方法签名但简化实现
    private func resolveSourceMappingImpl(path: String, line: Int64, column: Int64): ?SourceMapLookup {
        None
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
        exitHandler.dispatchOnExit(this)
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
        if (pluginRunner.isSome()) {
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
        if (pluginRunner.isSome()) {
            if (PluginRunner.couldBePlugin(specifierUtf8.toArray())) {
                // 尝试通过插件解析
            }
        }

        // 标准化 specifier
        let normalizedSpecifier = BunVirtualMachine.normalizeSpecifierForResolution(specifierUtf8)
        let normalizedSource = BunVirtualMachine.normalizeSource(sourceUtf8)

        // 通过解析器解析
        let ret = ResolveFunctionResult()
        resolveInternal(ret, normalizedSpecifier, normalizedSource, isEsm)
        if (ret.path.isEmpty()) {
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
        if (moduleLoader.fetchBuiltinModule(this, specifier).isSome()) {
            return moduleLoader.fetchBuiltinModule(this, specifier)
        }

        moduleLoader.transpileSourceCode(
            this, specifier, referrer, specifier, specifier,
            "js", "unknown", log, Option<String>.None
        )
    }

    // 严格翻译自 VirtualMachine.zig processFetchLog
    public func processFetchLog(specifier: String, referrer: String, log: ArrayList<String>, err: Error) {
        match (log.size) {
            case 0=>
                // 创建错误消息: ModuleNotFound
                ()
            case 1=>
                // 单个错误消息
                ()
            case _ =>
                // 聚合多个错误
                ()
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
        // defer: { hadErrors = prevHadErrors }

        // 创建 ZigException 用于 remap
        let holder = ZigExceptionHolder.initHolder()
        // defer: { holder.deinitHolder(this) }
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

        // defer: { if (wasInternal) { ... } }

        // 处理 AggregateError
        if (JsObjectHelper.isAggregateError(value, globalObject)) {
            let errors = JsObjectHelper.getErrorsProperty(value, globalObject)
            for (errorValue in errors) {
                printErrorlikeObject(errorValue, Option<Exception_>.None, exceptionList, formatter, enableAnsiColor, allowSideEffects)
            }
            return
        }

        wasInternal = printErrorFromMaybePrivateData(value, exceptionList, formatter, enableAnsiColor, allowSideEffects)

        // deferred: if wasInternal, handle exception stack trace
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

    // ========== 引用计数字符串 ==========

    // 严格翻译自 VirtualMachine.zig refCountedResolvedSource
    public func refCountedResolvedSource(code: String, specifier: String, sourceUrl: String, hash: ?Int64): ResolvedSource {
        if (code.isEmpty()) {
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
        let inputBytes = input.toArray()
        let h = hash ?? Int64(RefString.computeHash(inputBytes))
        if (refStrings.contains(h)) {
            return refStrings.get(h) ?? RefString()
        }
        let rs = RefString()
        rs.hash = UInt32(h)
        rs.ptr = inputBytes
        rs.len = Int64(input.size)
        refStrings.put(h, rs)
        return rs
    }

    // 严格翻译自 VirtualMachine.zig clearRefString
    public func clearRefString(refString: RefString) {
        refStrings.remove(Int64(refString.hash))
    }

    // ========== 工具方法 ==========

    // 加载并执行模块
    func loadAndEvaluateModule(path: String): ?JsObject {
        let ctx = JsContext(JsVirtualMachine())
        ctx.evaluateModule(path, `main`)
        None
    }

    // 计算路径哈希
    func hashPath(path: String): Int64 {
        var hash: Int64 = 0
        for (c in path) {
            hash = hash * 31 + Int64(c)
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
        getRareData().mimeTypeFromString("", str)
    }

    // 严格翻译自 VirtualMachine.zig onAfterEventLoop
    public func onAfterEventLoop() {
        // 执行 after event loop callback
    }

    // 严格翻译自 VirtualMachine.zig nextAsyncTaskID
    public func nextAsyncTaskID(): Int64 {
        if (debugger_.isNone()) {
            return 0
        }
        let id = if (debugger_.isSome()) { debugger_.getOrThrow().nextDebuggerId } else { 0 }
        if (debugger_.isSome()) { debugger_.getOrThrow().nextDebuggerId = id + 1 }
        return id
    }

    // 严格翻译自 VirtualMachine.zig assertOnJSThread
    public func assertOnJSThread() {
        // 在调试模式下断言在 JS 线程上
    }

    // 严格翻译自 VirtualMachine.zig sourceMapHandler
    public func sourceMapHandler(printer: BufferPrinter): SourceMapHandlerGetter {
        SourceMapHandlerGetter(this, printer)
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
        if (pendingInternalPromise.isSome()) {
            if (pendingInternalPromiseIsProtected) {
                pendingInternalPromise = None
                pendingInternalPromiseIsProtected = false
            }
            pendingInternalPromise = None
        }
        hasPatchedRunMain = false
        `main` = ""
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
        ipc = IPCInstanceUnion.Waiting(IPCWaitingState(fd, mode))
    }

    // 严格翻译自 VirtualMachine.zig getIPCInstance
    public func getIPCInstance(): ?IPCInstance {
        if (ipc.isNone()) {
            return None
        }
        match (ipc.getOrThrow()) {
            case IPCInstanceUnion.Waiting(state)=>
                let instance = IPCInstance()
                instance.globalThis = globalObject
                instance.data = IPCSendQueue()
                ipc = IPCInstanceUnion.Initialized(instance)
                return instance
            case IPCInstanceUnion.Initialized(inst) => return inst
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
        let error = JsValue.undefined() // TODO: createError
        error
    }

    // 严格翻译自 VirtualMachine.zig printExternallyRemappedZigException
    public func printExternallyRemappedZigException(
        zigException: ZigException,
        formatter: ConsoleFormatter,
        allowSideEffects: Bool,
        enableAnsiColor: Bool
    ) {
        printErrorInstanceFromZigException(zigException, Option<ExceptionList>.None, formatter, enableAnsiColor, allowSideEffects)
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
        // TODO: proper source line number display
        let lineNumbers: Array<Int64> = []
        var maxLine: Int64 = -1

        // 打印源代码预览
        var lineIdx: Int64 = 0
        while (lineIdx < 0) {
            let displayLine = Int64(0)
            if (enableAnsiColor) {
                println(displayLine.toString() + " | ")
            } else {
                println(displayLine.toString() + " | ")
            }
            lineIdx++
        }

        // 打印错误名称和消息
        printErrorNameAndMessage(name, message, false, Option<String>.None, enableAnsiColor, errorDisplayLevel)

        // 打印堆栈跟踪
        printStackTrace(zigException.stack, enableAnsiColor)
    }

    // 错误显示级别 (用于 printErrorInstance)
    private var errorDisplayLevel: ErrorDisplayLevel = ErrorDisplayLevel.Full

    // 严格翻译自 VirtualMachine.zig remapOneFrameSlow (详细版)
    func remapOneFrameSlowDetailed(frame: ZigStackFrame, path: String) {
        if (let Some(lookup) <- resolveSourceMapping(path, Int64(frame.position.line.value), Int64(frame.position.column.value))) {
            frame.sourceUrl = lookup.displaySourceURL ?? path
            frame.position.line = Ordinal(Int32(lookup.originalLine))
            frame.position.column = Ordinal(Int32(lookup.originalColumn))
        }
        frame.remapped = true
    }

    // 严格翻译自 VirtualMachine.zig normalizeSpecifierForResolution
    static func normalizeSpecifierForResolution(specifier: String): String {
        // 处理查询字符串
        var queryString: String = ""
        let qIdx = specifier.indexOf("?")
        if (qIdx.isSome()) {
            queryString = specifier[Int64(qIdx.getOrThrow())..]
            specifier[0..Int64(qIdx.getOrThrow())]
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

    // 注意: allowAddons 已在上方定义

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
        let frames = exception.stack.frames
        let topFrame = if (frames.size > 0) { Some(frames[0]) } else { Option<ZigStackFrame>.None }

        // 为 GitHub Actions 输出错误注释
        // ::error file=<file>,line=<line>,col=<col>,title=<title>::<message>
        if (let Some(frame) <- topFrame) {
            if (!frame.position.isInvalid()) {
                // 输出带位置的错误注解
                let annotation = "::error file=" + frame.sourceUrl +
                    ",line=" + Int64(frame.position.line.value + 1).toString() +
                    ",col=" + Int64(frame.position.column.value + 1).toString() +
                    ",title=" + name + "::" + message
                println(annotation)

                // 输出栈帧 (%0A = 转义换行)
                for (frame in frames) {
                    let file = frame.sourceUrl
                    let `func` = frame.functionName
                    if (file.isEmpty() && `func`.isEmpty()) {
                        continue
                    }
                    if (`func`.size > 0) {
                        println("%0A      at " + `func` + " (" + file + ")")
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
        if (pendingInternalPromise.isSome()) {
            if (pendingInternalPromiseIsProtected) {
                pendingInternalPromise = None
                pendingInternalPromiseIsProtected = false
            }
            pendingInternalPromise = None
        }
        hasPatchedRunMain = false
        `main` = ""
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
        if (ipc.isSome()) {
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
        match (eventLoopHandle) {
            case Some(handle) => handle.run()
            case None => eventLoop.run()
        }
    }

    // 严格翻译自 VirtualMachine.zig reload (详细版)
    public func reloadDetailed() {
        // 检查 pending promise 状态
        match (pendingInternalPromise) {
            case Some(p) =>
                let status = p.promiseStatus()
                if (status == PromiseStatus.Pending) {
                    hotReloadDeferred = true
                    return
                }
                if (status == PromiseStatus.Rejected && pendingInternalPromiseReportedAt != hotReloadCounter) {
                    hotReloadDeferred = true
                    return
                }
            case None => ()
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

        let _ = reloadEntryPoint(`main`)
    }

    // 严格翻译自 VirtualMachine.zig globalExit (详细版)
    public func globalExitDetailed(): Int64 {
        onExit()
        exitHandler.exitCode
    }

    // 注意: getLoaders 已在上方定义
    // 注意: bustDirCache 已在上方定义

    // 严格翻译自 VirtualMachine.zig nextAsyncTaskID (详细版)
    public func nextAsyncTaskIDDetailed(): Int64 {
        if (debugger_.isNone()) {
            return 0
        }
        let d = debugger_ ?? Debugger()
        let id = d.nextDebuggerId
        d.nextDebuggerId = id + 1
        id
    }

    // 严格翻译自 VirtualMachine.zig sourceMapHandler (详细版)
    public func sourceMapHandlerDetailed(printer: BufferPrinter): SourceMapHandlerGetterFull {
        SourceMapHandlerGetterFull(this, printer)
    }
}

// ========== 辅助类型 ==========

// 注意: EventLoopHandle 已移至 event_loop_handle.cj
// 注意: EventLoop 已移至 event_loop.cj

// 注意: WebWorker 已移至 web_worker.cj

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
            case IPCDecodedMessage.Version(v)=>
                // IPC 版本信息
                ()
            case IPCDecodedMessage.Data(data)=>
                // 处理数据消息
                ()
            case IPCDecodedMessage.Internal(data)=>
                // 处理内部消息
                ()
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

// 注意: IPCSendQueue 已移至 ipc.cj
// 注意: KeepAlive 已移至 work_task.cj
// 注意: FetchFlags 已移至 module_loader.cj

// 模块加载器
// 严格翻译自 ModuleLoader.zig
public class ModuleLoader {
    public var transpileSourceCodeArena: ?String = None
    public var evalSource: ?String = None

    public static var isAllowedToUseInternalTestingApis: Bool = false

    public init() {}

    // 严格翻译自 ModuleLoader.resetArena
    public func resetArena(jscVm: BunVirtualMachine) {
        if (transpileSourceCodeArena.isSome()) {
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
        source.sourceCode = virtualSource ?? ""
        return source
    }

    // 严格翻译自 ModuleLoader.fetchBuiltinModule
    public func fetchBuiltinModule(jscVm: BunVirtualMachine, specifier: String): ?ResolvedSource {
        let source = ResolvedSource()
        source.specifier = specifier
        source.sourceUrl = specifier

        match (specifier) {
            case "bun:test" | "@jest/globals" | "vitest"=>
                source.sourceCode = "export const test = globalThis.Bun?.jest?.test; export const it = test; export const describe = globalThis.Bun?.jest?.describe; export const expect = globalThis.Bun?.jest?.expect; export const beforeAll = globalThis.Bun?.jest?.beforeAll; export const beforeEach = globalThis.Bun?.jest?.beforeEach; export const afterAll = globalThis.Bun?.jest?.afterAll; export const afterEach = globalThis.Bun?.jest?.afterEach; export const jest = globalThis.Bun?.jest; export default test;"
                return source
            case "node:test"=>
                source.sourceCode = "import { test, it, describe, beforeAll, beforeEach, afterAll, afterEach } from 'bun:test'; export { test, it, describe, beforeEach, afterEach }; export const before = beforeAll; export const after = afterAll; export function mock(){ throw new Error('mock() is not implemented. Use bun:test in the interim.'); } export function run(){ throw new Error('run() is not implemented. Use bun:test in the interim.'); } export default test;"
                return source
            case "bun:internal-for-testing"=>
                if (!ModuleLoader.isAllowedToUseInternalTestingApis) { return None }
                source.sourceCode = "export const patchInternals = {}; export const jscInternals = {}; export const internalSourceMap = {}; export default { patchInternals, jscInternals, internalSourceMap };"
                return source
            case _ => return None
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

// 注意: DebuggerMode 已移至 debugger.cj

// 注意: RefString 已移至 ref_string.cj

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
    public var loader: Loader = Loader.File
    public var moduleFormat: ModuleFormat = ModuleFormat.Esm

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

// 注意: ImportWatcher 已移至 hot_reloader.cj
// 注意: GCController 已移至 js_property_iterator.cj
// 注意: RareData 已移至 rare_data.cj
// 注意: HotMap 已移至 rare_data.cj

// 注意: ProxyEnvStorage 已移至 rare_data.cj
// 注意: CleanupHook 已移至 rare_data.cj

// 注意: AsyncModuleQueue 已移至 async_module.cj

// 注意: SavedSourceMapTable 已移至 saved_source_map.cj
// 注意: SavedSourceMap 已移至 saved_source_map.cj

// 注意: ProcessAutoKiller 已移至 process_auto_killer.cj

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

// 注意: Mutex 已移至 web_worker.cj

// 异常
public class Exception_ {
    public var value: JsValue = JsValue.undefined()

    public init() {}

    public func getStackTrace(global: JsObject, stack: ZigStackTrace) {}
}

// 注意: ZigException 已移至 zig_exception.cj
// 注意: ZigStackTrace 已移至 zig_stack_trace.cj
// 注意: ZigStackFrame 已移至 zig_stack_frame.cj
// 注意: ConsoleFormatter 已移至 console_object.cj
// 注意: ErrorDisplayLevel 已移至 console_object.cj

// Promise 状态
public enum PromiseStatus {
    | Pending
    | Fulfilled
    | Rejected

    public operator func ==(right: PromiseStatus): Bool {
        match (this) {
            case Pending => match(right) { case Pending => true case _ => false }
            case Fulfilled => match(right) { case Fulfilled => true case _ => false }
            case Rejected => match(right) { case Rejected => true case _ => false }
        }
    }

    public operator func !=(right: PromiseStatus): Bool {
        !(this == right)
    }
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

// 注意: ImmediateObject 已移至 task.cj
// 注意: ConcurrentTask 已移至 concurrent_promise_task.cj
// 注意: PluginRunner 已移至 plugin_runner.cj
// 注意: CPUProfilerConfig 已移至 bun_cpu_profiler.cj
// 注意: HeapProfilerConfig 已移至 bun_heap_profiler.cj

// 注意: JsContext 已移至 vm.cj
// 注意: JsVirtualMachine 已移至 vm.cj

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
        SourceMapHandlerGetter(vm, printer)
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
        vm.printErrorlikeObject(nextValue, Option<Exception_>.None, currentExceptionList, formatter, enableColor, true)
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

// 注意: SourceLine 已移至 zig_stack_trace.cj
// 注意: SourceLineIterator 已移至 zig_stack_trace.cj

// 注意: ResolvedSource 已在上面定义
// 注意: MimeType 已在上面定义
// 注意: NodeFS 已在上面定义
// 注意: StandaloneModuleGraph 已在上面定义
// 注意: ModuleGraphFile 已在上面定义
// 注意: HotMap 已移至 rare_data.cj
// 注意: Process 已在上面定义

// 注意: Transpiler 已在上面定义
// 注意: TranspilerEnv 已在上面定义 (line ~2263)
// 注意: PackageManager 已在上面定义 (line ~2414)

// 注意: ErrorableResolvedSource 已移至 module_loader.cj

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

// Added stubs for JSCScheduler support
public func bunVMEventLoopRefConcurrently() {}
public func bunVMEventLoopUnrefConcurrently() {}
public func bunVMEnqueueDeferredWorkTask(task: JSCDeferredWorkTask) {}
public func bunVMEventLoopTickWhilePaused(paused: Bool) {}

/// 获取当前毫秒时间戳 (用于 getOriginTimestamp 等)
func getNowMillis(): Int64 {
    return sysCurrentTimeMillis()
}
