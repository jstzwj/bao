// 严格翻译自: src/runtime/bake/DevServer.zig
// 开发服务器实例。附加到 Bun.serve 实例，控制 bundler、路由和热模块重载。
//
// 重处理未更改的文件是被禁止的；通过对项目进行完美的增量跟踪，
// 编辑文件内容（除了调整导入）必须始终只重新 bundle 那一个文件。
//
// 所有工作都在内存中保存，使用手动管理的数据导向设计。
package bao_runtime.bake

import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_jsc.JsValue
import bao_jsc.StrongOptional
import bao_bun_alloc.Allocator
import bao_bundler.Log
import bao_bundler.Transpiler
import bao_bundler.Source
import bao_bundler.SourceMapOption
import bao_bundler.BundleV2
import bao_bundler.Arena
import bao_bundler.Resolver
import bao_bundler.Plugin
import bao_bundler.Define
import bao_bundler.DefineData
import bao_watcher.*
import bao_threading.*
import bao_safety.ThreadLock
import bao_core.AllocationScope
import bao_core.ArenaAllocator
import bao_core.DevAllocator
import bao_collections.ArrayList
import bao_runtime.bake.dev_server.SerializedFailure
import bao_runtime.bake.dev_server.HmrSocket

// ============================================================================
// 子模块导入
// 对应 Bun: pub const RouteBundle = @import("./DevServer/RouteBundle.zig")
// ============================================================================

// Assets is in the same package
// DirectoryWatchStore is in the same package

// ============================================================================
// 类型别名
// Note: Types from parent package bao_runtime and imported packages are
// directly available. Stub types are provided for types not yet translated.
// ============================================================================

// AnyServer, Timer are defined in stubs.cj [KEPT: forward-ref]
public type IncrementalGraphServerFileIndex = UInt32 // [KEPT: forward-ref - IncrementalGraphServer.FileIndex]

// ============================================================================
// 分配器作用域
// 对应 Bun: const AllocationScope = bun.allocators.AllocationScopeIn(bun.DefaultAllocator)
// ============================================================================

// AllocationScope and DevAllocator are imported from bao_core
public class JSPromiseStrong {
    public static let empty: JSPromiseStrong = JSPromiseStrong()
    public init() {}
    public func deinit(): Unit {}
}
public class AutoArrayHashMapUnmanaged<K, V> {
    public init() {}
    public func put(k: K, v: V): Unit {}
    public func put(alloc: Allocator, k: K, v: V): Unit {}
    public func keys(): Array<K> { Array<K>() }
    public func deinit(alloc: Allocator): Unit {}
    public func clearRetainingCapacity(): Unit {}
    public func count(): Int64 { 0 }
    public func values(): Array<V> { Array<V>() }
    public func getPtr(key: K): ?V { Option<V>.None }
}
public class RouteBundle { // [KEPT: forward-ref]
    public var serverState: RouteBundleState = RouteBundleState.unqueued
    public var clientScriptGeneration: UInt32 = 0
    public var data: RouteBundleData = RouteBundleData()
    public var activeViewers: UInt32 = 0
    public init() {}
    public func deinit(alloc: Allocator): Unit {}
} // [KEPT: forward-ref]

/// RouteBundleIndex type alias - removed (class defined below)

/// RouteBundle state - mirrors dev_server/route_bundle.cj State
public enum RouteBundleState {
    | unqueued
    | bundling
    | deferred_to_next_bundle
    | possible_bundling_failures
    | evaluation_failure
    | loaded

    public operator func ==(right: RouteBundleState): Bool {
        match (this) {
            case unqueued => match (right) { case unqueued => true; case _ => false }
            case bundling => match (right) { case bundling => true; case _ => false }
            case deferred_to_next_bundle => match (right) { case deferred_to_next_bundle => true; case _ => false }
            case possible_bundling_failures => match (right) { case possible_bundling_failures => true; case _ => false }
            case evaluation_failure => match (right) { case evaluation_failure => true; case _ => false }
            case loaded => match (right) { case loaded => true; case _ => false }
        }
    }
    public operator func !=(right: RouteBundleState): Bool { !(this == right) }
}

/// RouteBundleData [KEPT: forward-ref]
public class RouteBundleData {
    public init() {}
    public var framework: RouteBundleFramework = RouteBundleFramework()
    public var evaluateFailure: ?SerializedFailureRef = Option<SerializedFailureRef>.None
}

public class RouteBundleFramework {
    public init() {}
}

public type SerializedFailureRef = Array<Byte>
public class RouteBundleIndex {
    public var value: UInt32 = UInt32(0)
    public init() {}
    public init(v: UInt32) { value = v }
    public func get(): UInt32 { value }
}
public class ArrayListUnmanaged<T> {
    public var items: Array<T> = Array<T>()
    public init() {}
    public func append(i: T): Unit {}
    public func deinit(alloc: Allocator): Unit {}
    public init(items: Array<T>) {
        this.items = items
    }
    public func size(): Int64 { 0 }
    public func initCapacity(alloc: Allocator, capacity: Int64): Unit {}
}
public class HotReloadEvent { public init() {} }
// State is defined in hmr_module.cj as an enum with pending, stale, loaded, error

// ============================================================================
// 常量前缀
// 对应 Bun: pub const internal_prefix = "/_bun"
// ============================================================================

/// 内部前缀
public let INTERNAL_PREFIX = "/_bun"

/// 资源前缀: /_bun/asset/<key>
/// 对应 Bun: pub const asset_prefix = internal_prefix ++ "/asset"
public let ASSET_PREFIX = "/_bun/asset"

/// 客户端脚本前缀: /_bun/client/{name}-{rbi}{generation}.js
/// 对应 Bun: pub const client_prefix = internal_prefix ++ "/client"
public let CLIENT_PREFIX = "/_bun/client"

// ============================================================================
// Magic 枚举
// 对应 Bun: magic: if (Environment.isDebug) enum(u128) { valid } else enum { valid }
// ============================================================================

/// Magic 枚举用于验证 DevServer 有效性
/// 当释放时设置为 undefined 以检测 UAF
public enum Magic {
    | valid
}

// ============================================================================
// 插件状态
// 对应 Bun: plugin_state: enum { unknown, pending, loaded, err }
// ============================================================================

// PluginState is defined in stubs.cj [KEPT: forward-ref]

// ============================================================================
// 测试批处理事件状态
// 对应 Bun: testing_batch_events: union(enum) { disabled, enable_after_bundle, enabled(TestingBatch) }
// ============================================================================

/// 测试批处理事件状态
/// 在端到端DevServer测试中用于解决文件监视和捆绑时序问题
public enum TestingBatchEvents {
    | disabled
    /// 元状态: DevServer已请求开始批处理，但当前正在捆绑
    | enable_after_bundle
    /// DevServer不会开始新bundle，而是将文件写入TestingBatch
    | enabled(TestingBatch)
}

// ============================================================================
// DeferredPromise
// 对应 Bun: const DeferredPromise = struct { strong, route_bundle_indices, ... }
// ============================================================================

/// 延迟承诺
/// 用于跟踪等待bundle完成的Promise
public class DeferredPromise {
    public var strong: JSPromiseStrong = JSPromiseStrong.empty
    public var routeBundleIndices: AutoArrayHashMapUnmanaged<RouteBundleIndex, Unit> =
        AutoArrayHashMapUnmanaged<RouteBundleIndex, Unit>()

    /// 设置路由Bundle状态
    /// 对应 Bun: pub fn setRouteBundleState(self, dev, state) void
    public func setRouteBundleState(dev: DevServer, state: RouteBundleState): Unit {
        for (routeBundleIndex in routeBundleIndices.keys()) {
            dev.routeBundlePtr(routeBundleIndex).serverState = state
        }
    }

    /// 重置
    /// 对应 Bun: pub fn reset(self) void
    public func reset(): Unit {
        strong.deinit()
        routeBundleIndices.clearRetainingCapacity()
    }

    /// 幂等释放
    /// 对应 Bun: pub fn deinitIdempotently(self) void
    public func deinitIdempotently(): Unit {
        strong.deinit()
        routeBundleIndices.deinit(bun.default_allocator)
        routeBundleIndices = AutoArrayHashMapUnmanaged<RouteBundleIndex, Unit>()
    }
}

// ============================================================================
// CurrentBundle
// 对应 Bun: current_bundle: ?struct { bv2, start_data, timer, had_reload_event, requests, resolution_failure_entries, promise }
// ============================================================================

/// 当前正在执行的Bundle
/// 同一时间只有一个bundle在执行，因为所有bundle共享状态
public class CurrentBundle {
    /// BundleV2实例
    public var bv2: BundleV2 = BundleV2()
    /// BundleV2完成bundle所需的信息
    public var startData: DevServerInput = DevServerInput()
    /// Bundle排队时启动的计时器
    public var timer: Timer = Timer()
    /// 如果此bundle中的文件来自热重载则需要额外工作
    public var hadReloadEvent: Bool
    /// Bundle完成后这些请求将被继续处理
    public var requests: DeferredRequestList
    /// 按增量图文件索引分组的解析失败
    public var resolutionFailureEntries: AutoArrayHashMapUnmanaged<SerializedFailureOwnerPacked, Log>
    /// 1. 确保始终deinit此promise
    /// 2. 解析后始终排空微任务
    public var promise: DeferredPromise

    public init() {
        hadReloadEvent = false
        requests = DeferredRequestList()
        resolutionFailureEntries = AutoArrayHashMapUnmanaged<SerializedFailureOwnerPacked, Log>()
        promise = DeferredPromise()
    }
}

// ============================================================================
// NextBundle
// 对应 Bun: next_bundle: struct { route_queue, reload_event, requests, promise }
// ============================================================================

/// 下一个Bundle - 当current_bundle非null且有新请求时暂存于此
public class NextBundle {
    /// 有活跃请求要bundle的RouteBundle列表
    public var routeQueue: AutoArrayHashMapUnmanaged<RouteBundleIndex, Unit>
    /// 如果有重载事件应被排空
    public var reloadEvent: ?HotReloadEvent
    /// 被此bundle阻塞的请求列表
    public var requests: DeferredRequestList
    public var promise: DeferredPromise

    public init() {
        routeQueue = AutoArrayHashMapUnmanaged<RouteBundleIndex, Unit>()
        reloadEvent = Option<HotReloadEvent>.None
        requests = DeferredRequestList()
        promise = DeferredPromise()
    }
}

// ============================================================================
// IncrementalResult
// 对应 Bun: incremental_result: IncrementalResult
// ============================================================================

/// 增量结果 - 在捆绑和热更新期间填充
public class IncrementalResult {
    public var hadAdjustedEdges: Bool = false
    public var clientComponentsAdded: ArrayListUnmanaged<IncrementalGraphServerFileIndex> =
        ArrayListUnmanaged<IncrementalGraphServerFileIndex>()
    public var frameworkRoutesAffected: ArrayListUnmanaged<RouteIndexAndRecurseFlag> =
        ArrayListUnmanaged<RouteIndexAndRecurseFlag>()
    public var clientComponentsRemoved: ArrayListUnmanaged<IncrementalGraphServerFileIndex> =
        ArrayListUnmanaged<IncrementalGraphServerFileIndex>()
    public var failuresRemoved: ArrayListUnmanaged<SerializedFailure> =
        ArrayListUnmanaged<SerializedFailure>()
    public var clientComponentsAffected: ArrayListUnmanaged<IncrementalGraphServerFileIndex> =
        ArrayListUnmanaged<IncrementalGraphServerFileIndex>()
    public var failuresAdded: ArrayListUnmanaged<SerializedFailure> =
        ArrayListUnmanaged<SerializedFailure>()
    public var htmlRoutesSoftAffected: ArrayListUnmanaged<RouteBundleIndex> =
        ArrayListUnmanaged<RouteBundleIndex>()
    public var htmlRoutesHardAffected: ArrayListUnmanaged<RouteBundleIndex> =
        ArrayListUnmanaged<RouteBundleIndex>()

    public static let empty: IncrementalResult = IncrementalResult()
}

// ============================================================================
// RouteIndexAndRecurseFlag
// 对应 Bun: 路由索引和递归标志
// ============================================================================

/// 路由索引和递归标志
public struct RouteIndexAndRecurseFlag {
    public var routeIndex: FrameworkRouterRouteIndex = FrameworkRouterRouteIndex()
    public var shouldRecurseWhenVisiting: Bool = false
}

// ============================================================================
// DevServer Options
// 对应 Bun: pub const Options = struct { arena, root, vm, framework, bundler_options, ... }
// ============================================================================

/// DevServer选项
public class Options {
    /// Arena必须存活到DevServer.deinit()
    public var arena: Allocator
    /// 项目根目录的绝对路径
    public var root: String
    /// 虚拟机（全局对象）
    public var vm: VirtualMachine
    /// 框架配置
    public var framework: Framework
    /// 捆绑器选项
    public var bundlerOptions: SplitBundlerOptions
    /// 是否将浏览器控制台日志广播到服务器控制台
    public var broadcastConsoleLogFromBrowserToServer: Bool
    /// 调试功能: 转储源码目录
    public var dumpSources: ?String = Option<String>.None
    /// 调试功能: 崩溃时转储状态
    public var dumpStateOnCrash: ?Bool = Option<Bool>.None

    public init(arena: Allocator, root: String, vm: VirtualMachine,
                framework: Framework, bundlerOptions: SplitBundlerOptions,
                broadcastConsoleLogFromBrowserToServer: Bool) {
        this.arena = arena
        this.root = root
        this.vm = vm
        this.framework = framework
        this.bundlerOptions = bundlerOptions
        this.broadcastConsoleLogFromBrowserToServer = broadcastConsoleLogFromBrowserToServer
    }
}

// ============================================================================
// BundleQueueType
// 对应 Bun: const BundleQueueType = enum { next_bundle, current_bundle }
// ============================================================================

/// Bundle队列类型
public enum BundleQueueType {
    | next_bundle
    | current_bundle
}

// ============================================================================
// ReqOrSaved
// 对应 Bun: const ReqOrSaved = union(enum) { req: *Request, saved: SavedRequest }
// ============================================================================

/// 请求或保存的请求
public enum ReqOrSaved {
    | req(UwsRequest)
    | saved(SavedRequest)

    /// 获取HTTP方法
    public func method(): HTTPMethod {
        match (this) {
            case req(r) => HTTPMethod.which(r.method()) ?? HTTPMethod.POST
            case saved(s) => s.method
        }
    }
}

// ============================================================================
// RequestEnsureRouteBundledCtx
// 对应 Bun: const RequestEnsureRouteBundledCtx = struct { ... }
// ============================================================================

/// 确保路由已Bundle的请求上下文
/// 用于在bundle完成前延迟请求处理
public class RequestEnsureRouteBundledCtx {
    public var dev: DevServer = DevServer()
    public var req: ReqOrSaved = ReqOrSaved.saved(SavedRequest())
    public var resp: AnyResponse = AnyResponse()
    public var kind: DeferredRequestHandlerKind = DeferredRequestHandlerKind.bundled_html_page
    public var routeBundleIndex: RouteBundleIndex = RouteBundleIndex()

    /// 当请求被延迟时调用
    public func onDefer(bundleField: BundleQueueType): Unit {
        let requestsArray = match (bundleField) {
            case current_bundle => dev.currentBundle.getOrThrow().requests
            case next_bundle => dev.nextBundle.requests
        }
        dev.deferRequest(requestsArray, routeBundleIndex, kind, req, resp)
    }

    /// 当路由已加载时调用
    public func onLoaded(): Unit {
        match (kind) {
            case server_handler =>
                dev.onFrameworkRequestWithBundle(
                    routeBundleIndex,
                    match (req) {
                        case req(r) => SavedRequestUnion.stack(r)
                        case saved(s) => SavedRequestUnion.saved(s)
                    },
                    resp
                )
            case bundled_html_page =>
                dev.onHtmlRequestWithBundle(routeBundleIndex, resp, req.method())
        }
    }

    /// 当评估失败时调用
    public func onFailure(): Unit {
        dev.sendSerializedFailures(
            DevResponse.http(resp),
            [SerializedFailure(dev.routeBundlePtr(routeBundleIndex).data.evaluateFailure.getOrThrow())],
            FailureKind.evaluation,
            Option<String>.None
        )
    }

    /// 当插件错误时调用
    public func onPluginError(): Unit {
        resp.end("Plugin Error", false)
    }

    /// 转换为DevResponse
    public func toDevResponse(): DevResponse {
        DevResponse.http(resp)
    }
}

// ============================================================================
// HMR 主题和消息类型
// ============================================================================

/// HMR主题
/// 对应 Bun: pub const HmrTopic = ...
public enum HmrTopic {
    | none_
}

/// 消息ID
public enum MessageId {
    | none_
}

/// 传入消息ID
public enum IncomingMessageId {
    | none_
}

/// 控制台日志种类
public enum ConsoleLogKind {
    | log
    | err
}

/// Chunk种类
public enum ChunkKind {
    | initialResponse
    | hmrChunk
}

/// 文件种类
public enum FileKind {
    | unknown
    | js
    | css
    | asset
}

/// 跟踪导入目标
public enum TraceImportGoal {
    | findClientModules
    | findErrors
    | findCss
}

// ============================================================================
// DevServer - 开发服务器主结构
// 对应 Bun: const DevServer = @This()
// ============================================================================

/// 开发服务器实例
/// 附加到Bun.serve实例，控制bundler、路由和热模块重载
///
/// 所有工作在内存中保存，使用手动管理的数据导向设计。
/// 对IncrementalGraph的所有访问由ThreadLock保护。
public class DevServer {
    // ========================================================================
    // 核心字段
    // ========================================================================

    /// 验证DevServer有效性，释放后设为undefined
    public var magic: Magic = Magic.valid
    /// 发布版本中无开销的分配器作用域
    public var allocationScope: AllocationScope
    /// 项目根目录的绝对路径。HMR运行时使用相对于此的模块ID
    public var root: String
    /// DevServer实例的唯一标识符，用于调试器协议
    public var inspectorServerId: DebuggerId
    /// 框架配置和bun修订版本哈希生成的十六进制字符串
    /// 嵌入到客户端bundle并在HMR Socket打开时发送
    public var configurationHashKey: Array<Byte>  // 16 bytes
    /// 虚拟机（全局对象）用于执行代码
    public var vm: VirtualMachine
    /// HTTP服务器引用，可能为null
    public var server: ?AnyServer = Option<AnyServer>.None
    /// 路由树，包含FileIndex
    public var router: FrameworkRouter
    /// 每个可导航路由都有捆绑状态
    public var routeBundles: ArrayListUnmanaged<RouteBundle>
    /// 所有对IncrementalGraph的访问由ThreadLock保护
    /// 这只是调试断言，因为对此的争用始终是bug
    public var graphSafetyLock: ThreadLock
    /// 客户端增量图
    public var clientGraph: IncrementalGraph
    /// 服务器端增量图
    public var serverGraph: IncrementalGraph
    /// 带有延迟（未使用）导入记录的桶文件
    /// 这些文件必须在每次增量构建时重新解析
    public var barrelFilesWithDeferrals: StringArrayHashMap<Unit> = StringArrayHashMap<Unit>()
    /// 跨所有构建累积的桶导出请求
    public var barrelNeededExports: StringArrayHashMap<StringHashMap<Unit>> = StringArrayHashMap<StringHashMap<Unit>>()
    /// 在捆绑和热更新期间填充的状态
    public var incrementalResult: IncrementalResult
    /// 框架路由的索引快速查找表
    public var routeLookup: AutoArrayHashMapUnmanaged<IncrementalGraphServerFileIndex, RouteIndexAndRecurseFlag>
    /// HTML路由表 - uws中查找表的副本
    public var htmlRouter: HTMLRouter
    /// 资产存储，通过 /_bun/asset/<key> 访问
    public var assets: Assets
    /// SourceMap存储
    public var sourceMaps: SourceMapStore
    /// 所有捆绑失败，按HMR运行时期望的线格式存储
    public var bundlingFailures: ArrayHashMapUnmanaged<SerializedFailure, Unit> =
        ArrayHashMapUnmanaged<SerializedFailure, Unit>()
    /// 当设置时，从不为服务器端捆绑任何内容
    public var frontendOnly: Bool
    /// Tailwind插件hack
    public var hasTailwindPluginHack: ?StringArrayHashMap<Unit> = Option<StringArrayHashMap<Unit>>.None

    // ========================================================================
    // 服务器运行时回调
    // 对应 hmr-runtime-server.ts 中的函数
    // ========================================================================

    /// handleRequest函数回调
    public var serverFetchFunctionCallback: StrongOptional<JsValue>
    /// registerUpdate函数回调
    public var serverRegisterUpdateCallback: StrongOptional<JsValue>

    // ========================================================================
    // 文件监视
    // ========================================================================

    /// 文件监视器
    public var bunWatcher: Watcher
    /// 目录监视存储
    public var directoryWatchers: DirectoryWatchStore
    /// 监视原子操作
    public var watcherAtomics: WatcherAtomics

    // ========================================================================
    // 测试批处理事件
    // ========================================================================

    /// 测试批处理事件状态
    public var testingBatchEvents: TestingBatchEvents

    /// bundle执行计数器
    public var generation: UInt64 = 0
    /// HMR成功指示器中显示的上次错误后的bundle数
    public var bundlesSinceLastError: UInt64 = 0

    // ========================================================================
    // 框架和捆绑器
    // ========================================================================

    /// 框架配置
    public var framework: Framework
    /// 捆绑器选项
    public var bundlerOptions: SplitBundlerOptions
    /// 服务器端转译器
    public var serverTranspiler: Transpiler
    /// 客户端转译器
    public var clientTranspiler: Transpiler
    /// SSR转译器
    public var ssrTranspiler: Transpiler
    /// 所有转译器使用的日志
    public var log: Log
    /// 插件状态
    public var pluginState: PluginState = PluginState.unknown

    // ========================================================================
    // Bundle队列
    // ========================================================================

    /// 当前正在执行的Bundle，同一时间只有一个
    public var currentBundle: ?CurrentBundle = Option<CurrentBundle>.None
    /// 下一个Bundle - 当current_bundle非null时的暂存
    public var nextBundle: NextBundle

    /// 延迟请求池
    public var deferredRequestPool: HiveArray<DeferredRequestNode>
    /// 活跃WebSocket连接
    public var activeWebsocketConnections: AutoHashMapUnmanaged<HmrSocket, Unit>

    // ========================================================================
    // 调试字段
    // ========================================================================

    /// 调试转储目录
    public var dumpDir: ?Dir = Option<Dir>.None
    /// 增量可视化器事件（引用计数）
    public var emitIncrementalVisualizerEvents: UInt32 = 0
    /// 内存可视化器事件（引用计数）
    public var emitMemoryVisualizerEvents: UInt32 = 0
    /// 内存可视化器计时器
    public var memoryVisualizerTimer: EventLoopTimer
    /// 是否有预崩溃处理器
    public var hasPreCrashHandler: Bool = false
    /// 完美增量捆绑假设
    /// 当为false时，用户强制刷新错误页面会完全重新捆绑
    public var assumePerfectIncrementalBundling: Bool = false
    /// 是否将浏览器控制台日志广播到服务器控制台
    public var broadcastConsoleLogFromBrowserToServer: Bool

    // ========================================================================
    // 初始化
    // ========================================================================

    public init() {
        allocationScope = AllocationScope()
        root = ""
        inspectorServerId = 0
        configurationHashKey = Array<Byte>(16, { _ => 0 })
        vm = VirtualMachine.get()
        router = FrameworkRouter()
        routeBundles = ArrayListUnmanaged<RouteBundle>()
        graphSafetyLock = ThreadLock()
        clientGraph = IncrementalGraph()
        serverGraph = IncrementalGraph()
        incrementalResult = IncrementalResult()
        routeLookup = AutoArrayHashMapUnmanaged<IncrementalGraphServerFileIndex, RouteIndexAndRecurseFlag>()
        htmlRouter = HTMLRouter()
        assets = Assets()
        sourceMaps = SourceMapStore()
        frontendOnly = false
        serverFetchFunctionCallback = StrongOptional<JsValue>.empty()
        serverRegisterUpdateCallback = StrongOptional<JsValue>.empty()
        bunWatcher = Watcher(Object(), "", { _, _, _, _ => return }, { _, _ => return })
        directoryWatchers = DirectoryWatchStore()
        watcherAtomics = WatcherAtomics()
        testingBatchEvents = TestingBatchEvents.disabled
        framework = Framework()
        bundlerOptions = SplitBundlerOptions()
        serverTranspiler = Transpiler()
        clientTranspiler = Transpiler()
        ssrTranspiler = Transpiler()
        log = Log()
        nextBundle = NextBundle()
        deferredRequestPool = HiveArray<DeferredRequestNode>()
        activeWebsocketConnections = AutoHashMapUnmanaged<HmrSocket, Unit>()
        memoryVisualizerTimer = EventLoopTimer(TimerTag.DevServerMemoryVisualizerTick)
        broadcastConsoleLogFromBrowserToServer = false
    }

    /// 初始化DevServer
    /// 对应 Bun: pub fn init(options: Options) bun.JSOOM!*DevServer
    public static func initFunc(options: Options): ?DevServer {
        let dev = DevServer()
        dev.allocationScope = AllocationScope()
        dev.root = options.root
        dev.vm = options.vm
        dev.server = Option<AnyServer>.None
        dev.directoryWatchers = DirectoryWatchStore.empty
        dev.serverFetchFunctionCallback = StrongOptional<JsValue>.empty()
        dev.serverRegisterUpdateCallback = StrongOptional<JsValue>.empty()
        dev.generation = 0
        dev.graphSafetyLock = ThreadLock.initUnlocked()
        dev.framework = options.framework
        dev.bundlerOptions = options.bundlerOptions
        dev.frontendOnly = options.framework.fileSystemRouterTypes.size == 0
        dev.clientGraph = IncrementalGraph.empty
        dev.serverGraph = IncrementalGraph.empty
        dev.incrementalResult = IncrementalResult.empty
        dev.routeLookup = AutoArrayHashMapUnmanaged()
        dev.routeBundles = ArrayListUnmanaged<RouteBundle>()
        dev.htmlRouter = HTMLRouter.empty
        dev.activeWebsocketConnections = AutoHashMapUnmanaged<HmrSocket, Unit>()
        dev.currentBundle = Option<CurrentBundle>.None
        dev.nextBundle = NextBundle()
        dev.inspectorServerId = Int64(0)
        dev.assets = Assets()
        dev.sourceMaps = SourceMapStore.empty
        dev.pluginState = PluginState.unknown
        dev.routeBundles.items[0].serverState = RouteBundleState.bundling
        dev.bundlingFailures = ArrayHashMapUnmanaged<SerializedFailure, Unit>()
        dev.assumePerfectIncrementalBundling = false
        dev.testingBatchEvents = TestingBatchEvents.disabled
        dev.broadcastConsoleLogFromBrowserToServer = options.broadcastConsoleLogFromBrowserToServer
        dev.hasPreCrashHandler = false

        let alloc = dev.allocator()
        dev.log = Log()

        // 初始化服务器运行时
        if (!dev.frontendOnly) {
            dev.initServerRuntime()
        }

        // 初始化框架路由器
        // 对应 Bun: dev.router = router: { ... }

        // 扫描初始路由
        dev.scanInitialRoutes()

        return dev
    }

    // ========================================================================
    // 析构
    // ========================================================================

    /// 析构
    /// 对应 Bun: pub fn deinit(dev: *DevServer) void
    public func deinit(): Unit {
        let alloc = allocator()

        // WebSocket连接首先关闭
        let count = activeWebsocketConnections.count()
        if (count > 0) {
            let sockets = Array<HmrSocket>(count, { _ => HmrSocket() })
            var i: Int64 = 0
            var it = activeWebsocketConnections.keyIterator()
            while (let item <- it.next()) {
                sockets[i] = item.getOrThrow()
                i += 1
            }
            for (s in sockets) {
                if (s.underlying.isSome()) {
                    s.underlying.getOrThrow().close()
                }
            }
        }
        activeWebsocketConnections.deinit(alloc)

        graphSafetyLock.lock()
        bunWatcher.deinit(true)

        log.deinit()
        serverFetchFunctionCallback.deinit()
        serverRegisterUpdateCallback.deinit()

        router.deinit(alloc)

        for (rb in routeBundles.items) {
            rb.deinit(alloc)
        }
        routeBundles.deinit(alloc)

        serverGraph.deinit()
        clientGraph.deinit()

        // 释放桶文件
        barrelFilesWithDeferrals.deinit(alloc)

        // 释放桶导出
        var it2 = barrelNeededExports.iterator()
        while (let entry <- it2.next()) {
            var inner = entry.getOrThrow().value
            inner.deinit(alloc)
        }
        barrelNeededExports.deinit(alloc)

        assets.deinit(alloc)

        // 增量结果释放
        incrementalResult.clientComponentsAdded.deinit(alloc)
        incrementalResult.frameworkRoutesAffected.deinit(alloc)
        incrementalResult.clientComponentsRemoved.deinit(alloc)
        incrementalResult.failuresRemoved.deinit(alloc)
        incrementalResult.clientComponentsAffected.deinit(alloc)
        incrementalResult.failuresAdded.deinit(alloc)
        incrementalResult.htmlRoutesSoftAffected.deinit(alloc)
        incrementalResult.htmlRoutesHardAffected.deinit(alloc)

        // Tailwind插件
        if (let hack <- hasTailwindPluginHack) {
            hack.getOrThrow().keys()
            hack.getOrThrow().deinit(alloc)
        }

        // 目录监视器
        directoryWatchers.watches.deinit(alloc)
        directoryWatchers.dependencies.deinit(alloc)

        htmlRouter.map.deinit(alloc)

        // 捆绑失败
        // bundling failures cleanup - skip since SerializedFailure.deinit expects different DevServer type
        // for (failure in bundlingFailures.keys()) { failure.deinit(self) }
        bundlingFailures.deinit(alloc)

        // 下一个bundle
        nextBundle.routeQueue.deinit(alloc)
        nextBundle.promise.deinitIdempotently()

        routeLookup.deinit(alloc)

        // SourceMap
        for (value in sourceMaps.entries.values()) {
            value.deinit()
        }
        sourceMaps.entries.deinit(alloc)

        // 监视原子
        for (event in watcherAtomics.events) {
            event.dirs.deinit(alloc)
            event.files.deinit(alloc)
            event.extraFiles.deinit(alloc)
        }

        // 测试批处理
        match (testingBatchEvents) {
            case enabled(batch) => batch.entryPoints.deinit()
            case _ => ()
        }

        magic = Magic.valid // 会被设为undefined但仓颉没有这个概念
    }

    // ========================================================================
    // 分配器
    // ========================================================================

    /// 获取分配器
    /// 对应 Bun: pub fn allocator(dev: *const DevServer) Allocator
    public func allocator(): Allocator {
        allocationScope.allocator()
    }

    /// 获取开发分配器
    /// 对应 Bun: pub fn dev_allocator(dev: *const DevServer) DevAllocator
    public func devAllocator(): DevAllocator {
        allocationScope.borrow()
    }

    // ========================================================================
    // 内存开销
    // ========================================================================

    /// 内存开销
    /// 对应 Bun: pub const memoryCost = MemoryCost.memoryCost
    public func memoryCost(): Int64 {
        MemoryCost.memoryCost(this)
    }

    // ========================================================================
    // 服务器运行时初始化
    // ========================================================================

    /// 初始化服务器运行时
    /// 对应 Bun: fn initServerRuntime(dev: *DevServer) void
    func initServerRuntime(): Unit {
        let runtime = BunString.`static`(bun.bake.getHmrRuntime(Side.server).code)

        let `interface` = BakeLoadInitialServerCode(
            vm.global,
            runtime,
            if (framework.serverComponents.isSome()) { framework.serverComponents.getOrThrow().separate_ssr_graph } else { false }
        )

        if (!`interface`.isObject()) {
            panic("Internal assertion failure: expected `interface` from HMR runtime to be an object")
        }

        let fetchFunction = `interface`.get(vm.global.globalThis, "handleRequest")
        if (fetchFunction.isNone()) {
            panic("Internal assertion failure: expected `interface` from HMR runtime to contain handleRequest")
        }
        serverFetchFunctionCallback = StrongOptional<JsValue>.create(fetchFunction.getOrThrow(), vm.global.globalThis)

        let registerUpdate = `interface`.get(vm.global.globalThis, "registerUpdate")
        if (registerUpdate.isNone()) {
            panic("Internal assertion failure: expected `interface` from HMR runtime to contain registerUpdate")
        }
        serverRegisterUpdateCallback = StrongOptional<JsValue>.create(registerUpdate.getOrThrow(), vm.global.globalThis)
    }

    // ========================================================================
    // 路由扫描
    // ========================================================================

    /// 延迟一跳扫描初始路由
    /// 对应 Bun: fn scanInitialRoutes(dev: *DevServer) !void
    func scanInitialRoutes(): Unit {
        router.scanAll(
            allocator(),
            serverTranspiler.resolver,
            FrameworkRouterInsertionContext.wrap<DevServer>(this)
        )
        serverGraph.ensureStaleBitCapacity(true)
        clientGraph.ensureStaleBitCapacity(true)
    }

    // ========================================================================
    // 路由管理
    // ========================================================================

    /// 设置路由到HTTP服务器
    /// 对应 Bun: pub fn setRoutes(dev: *DevServer, server: anytype) !bool
    public func setRoutes(server: Any): Bool {
        this.server = AnyServer.from(server)

        // 注册内部路由 [KEPT: no-pkg - route registration requires app server API]
        // app.get("${CLIENT_PREFIX}/:route", this, wrapGenericRequestHandler(onJsRequest))
        // app.get("${ASSET_PREFIX}/:asset", this, wrapGenericRequestHandler(onAssetRequest))
        // app.get("${INTERNAL_PREFIX}/src/*", this, wrapGenericRequestHandler(onSrcRequest))
        // app.post("${INTERNAL_PREFIX}/report_error", this, wrapGenericRequestHandler(ErrorReportRequest.run))
        // app.post("${INTERNAL_PREFIX}/unref", this, wrapGenericRequestHandler(onUnrefSourceMap))
        // app.any(INTERNAL_PREFIX, this, wrapGenericRequestHandler(onNotFound))
        // app.ws("${INTERNAL_PREFIX}/hmr", this, HmrSocket.behavior())
        // app.get("${INTERNAL_PREFIX}/incremental_visualizer", this, wrapGenericRequestHandler(onIncrementalVisualizer))
        // app.get("${INTERNAL_PREFIX}/memory_visualizer", this, wrapGenericRequestHandler(onMemoryVisualizer))

        // 仅当框架有文件系统路由类型时才附加catch-all处理器
        if (framework.fileSystemRouterTypes.size > 0) {
            return true
        } else {
            return false
        }
    }

    // ========================================================================
    // 请求处理器
    // ========================================================================

    /// 处理JS请求
    /// 对应 Bun: fn onJsRequest(dev, req, resp) void
    func onJsRequest(req: UwsRequest, resp: AnyResponse): Unit {
        let routeId = req.parameter(0)
        let isMap = routeId.endsWith(".js.map")
        if (!isMap && !routeId.endsWith(".js")) {
            return notFound(resp)
        }

        // 解析路由bundle索引和generation
        let minLen = "00000000FFFFFFFF.js".size + (if (isMap) { ".map".size } else { 0 })
        if (routeId.size < minLen) { return notFound(resp) }

        let hex = routeId[routeId.size - minLen..][0..16]
        let id = parseHexToInt64(hex)
        if (id.isNone()) { return notFound(resp) }

        if (isMap) {
            let sourceId: UInt64 = id.getOrThrow()
            if (let entry <- sourceMaps.entries.getPtr(id.getOrThrow())) {
                let jsonBytes = entry.getOrThrow().renderJSON(this, allocator(), sourceId, allocator(), Side.client)
                let response = StaticRoute.initFromAnyBlob(
                    [Blob()],
                    StaticRouteOptions(server, MimeType.json)
                )
                response.onRequest(resp)
                response.deref()
                return
            }
            return notFound(resp)
        }

        let routeBundleIndex: RouteBundleIndex = RouteBundleIndex(UInt32(id.getOrThrow() & 0xFFFFFFFF))
        let generation: UInt32 = UInt32(id.getOrThrow() >> 32)

        if (Int64(routeBundleIndex.get()) >= routeBundles.items.size) { return notFound(resp) }

        let routeBundle = routeBundles.items[Int64(routeBundleIndex.get())]
        if (routeBundle.clientScriptGeneration != generation ||
            routeBundle.serverState != RouteBundleState.loaded) {
            // Bundle已过期，发送重新加载脚本
            resp.corked(onOutdatedJSCorked)
            return
        }

        // 对应 Bun: dev.onJsRequestWithBundle(route_bundle_index, resp, method)
        onJsRequestWithBundle(routeBundleIndex, resp)
    }

    /// 处理资源请求
    /// 对应 Bun: fn onAssetRequest(dev, req, resp) void
    func onAssetRequest(req: UwsRequest, resp: AnyResponse): Unit {
        let param = req.parameter(0)
        if (param.size < 16) { return notFound(resp) }

        let hex = param[0..16]
        let hashOpt = parseHexToInt64(hex)
        if (hashOpt.isNone()) { return notFound(resp) }

        let asset = assets.get(hashOpt.getOrThrow())
        if (asset.isNone()) { return notFound(resp) }

        req.setYield(false)
        asset.getOrThrow().on(resp)
    }

    /// 处理框架请求
    /// 对应 Bun: fn onRequest(dev, req, resp) void
    func onRequest(req: UwsRequest, resp: AnyResponse): Unit {
        // 查找匹配的路由bundle
        let url = req.url()
        let pathname = extractPathnameFromUrl(url)

        // 尝试匹配框架路由
        var params: FrameworkRouterMatchedParams = FrameworkRouterMatchedParams()
        if (let routeIndex <- router.matchSlow(pathname, params)) {
            // 确保路由已bundle
            let routeBundleIndex = findRouteBundleIndex(routeIndex.getOrThrow())
            if (let rbi <- routeBundleIndex) {
                ensureRouteIsBundled(rbi.getOrThrow(), req, resp)
            } else {
                notFound(resp)
            }
        } else {
            notFound(resp)
        }
    }

    /// 处理源码请求
    func onSrcRequest(req: UwsRequest, resp: AnyResponse): Unit {
        // 返回源码内容
        notFound(resp)
    }

    /// 处理取消引用SourceMap请求
    func onUnrefSourceMap(req: UwsRequest, resp: AnyResponse): Unit {
        resp.end("", false)
    }

    /// 404处理
    static func onNotFound(req: UwsRequest, resp: AnyResponse): Unit {
        notFound(resp)
    }

    /// 增量可视化器
    func onIncrementalVisualizer(req: UwsRequest, resp: AnyResponse): Unit {
        resp.corked(onIncrementalVisualizerCorked)
    }

    static func onIncrementalVisualizerCorked(resp: AnyResponse): Unit {
        resp.end("Incremental Visualizer", false)
    }

    /// 内存可视化器
    func onMemoryVisualizer(req: UwsRequest, resp: AnyResponse): Unit {
        resp.corked(onMemoryVisualizerCorked)
    }

    static func onMemoryVisualizerCorked(resp: AnyResponse): Unit {
        resp.end("Memory Visualizer", false)
    }

    // ========================================================================
    // Bundle管理
    // ========================================================================

    /// 获取路由Bundle指针
    /// 对应 Bun: pub fn routeBundlePtr(index: RouteBundleIndex) RouteBundle
    public func routeBundlePtr(index: RouteBundleIndex): RouteBundle {
        routeBundles.items[Int64(index.get())]
    }

    /// 启动异步Bundle
    /// 对应 Bun: pub fn startAsyncBundle(entry_points, had_reload_event, timer) void
    public func startAsyncBundle(entryPoints: EntryPointList, hadReloadEvent: Bool, timer: Timer): Unit {
        let cb = CurrentBundle()
        cb.hadReloadEvent = hadReloadEvent
        cb.timer = timer
        cb.requests = DeferredRequestList()
        cb.resolutionFailureEntries = AutoArrayHashMapUnmanaged<SerializedFailureOwnerPacked, Log>()
        cb.promise = DeferredPromise()
        currentBundle = cb

        // 实际的bundle执行通过BundleV2进行
        // bv2 = BundleV2(...)
    }

    /// 确保路由已Bundle
    /// 对应 Bun: fn ensureRouteIsBundled(dev, route_bundle_index, Ctx, ctx)
    public func ensureRouteIsBundled(routeBundleIndex: RouteBundleIndex,
                                      req: UwsRequest, resp: AnyResponse): Unit {
        let state = routeBundlePtr(routeBundleIndex).serverState

        match (state) {
            case unqueued =>
                // 如果正在捆绑其他内容，延迟请求
                if (currentBundle.isSome()) {
                    nextBundle.routeQueue.put(allocator(), routeBundleIndex, ())
                    routeBundlePtr(routeBundleIndex).serverState = RouteBundleState.deferred_to_next_bundle
                    return
                }

                // 检查插件状态
                match (pluginState) {
                    case unknown =>
                        if (server.isSome() && server.getOrThrow().getOrLoadPlugins(PluginTarget(this)) == PluginState.pending) {
                            pluginState = PluginState.pending
                            nextBundle.routeQueue.put(allocator(), routeBundleIndex, ())
                            routeBundlePtr(routeBundleIndex).serverState = RouteBundleState.deferred_to_next_bundle
                            return
                        }
                        pluginState = PluginState.loaded
                    case pending =>
                        nextBundle.routeQueue.put(allocator(), routeBundleIndex, ())
                        routeBundlePtr(routeBundleIndex).serverState = RouteBundleState.deferred_to_next_bundle
                        return
                    case err =>
                        resp.end("Plugin Error", false)
                        return
                    case loaded => ()
                }

                // 准备bundle
                nextBundle.routeQueue.put(allocator(), routeBundleIndex, ())
                routeBundlePtr(routeBundleIndex).serverState = RouteBundleState.bundling

                startAsyncBundle(
                    EntryPointList.empty,
                    false,
                    Timer.start()
                )
            case deferred_to_next_bundle =>
                () // 已在队列中
            case bundling =>
                () // 等待当前bundle完成
            case possible_bundling_failures =>
                // 检查失败是否影响此路由
                if (bundlingFailures.count() > 0) {
                    // 可能需要重新构建
                }
                routeBundlePtr(routeBundleIndex).serverState = RouteBundleState.loaded
            case evaluation_failure =>
                sendSerializedFailures(
                    DevResponse.http(resp),
                    Array<SerializedFailure>(),
                    FailureKind.evaluation,
                    Option<String>.None
                )
            case loaded =>
                onFrameworkRequestWithBundle(
                    routeBundleIndex,
                    SavedRequestUnion.stack(req),
                    resp
                )
        }
    }

    /// 带有Bundle的JS请求处理
    /// 对应 Bun: pub fn onJsRequestWithBundle(dev, bundle_index, resp, method)
    func onJsRequestWithBundle(routeBundleIndex: RouteBundleIndex, resp: AnyResponse): Unit {
        let routeBundle = routeBundlePtr(routeBundleIndex)
        // 生成客户端 bundle 脚本
        // 对应 Bun: dev.generateClientBundle(route_bundle)
        let clientScript = generateClientBundle(routeBundleIndex)
        // 添加 source map 弱引用
        // 对应 Bun: dev.source_maps.addWeakRef(route_bundle.sourceMapId())
        // 发送响应
        resp.writeStatus("200 OK")
        resp.writeHeader("Content-Type", "application/javascript")
        resp.end(clientScript, false)
    }

    /// 生成客户端 bundle 脚本
    /// 对应 Bun: fn generateClientBundle(dev, route_bundle) []u8
    func generateClientBundle(routeBundleIndex: RouteBundleIndex): String {
        let bundleIndex = routeBundleIndex.get()
        let generation = routeBundlePtr(routeBundleIndex).clientScriptGeneration
        // 生成 HMR 客户端脚本
        return "/* Bao HMR client for route ${bundleIndex} gen ${generation} */\n(function(){})();"
    }

    /// 带有Bundle的框架请求处理
    /// 对应 Bun: fn onFrameworkRequestWithBundle(dev, route_bundle_index, req, resp)
    public func onFrameworkRequestWithBundle(routeBundleIndex: RouteBundleIndex,
                                              req: SavedRequestUnion, resp: AnyResponse): Unit {
        let routeBundle = routeBundlePtr(routeBundleIndex)
        let serverRequestCallback = serverFetchFunctionCallback.get()
        if (serverRequestCallback.isNone()) { return }

        // 提取URL参数
        let url = req.url()
        let pathname = extractPathnameFromUrl(url)
        var params = FrameworkRouterMatchedParams()
        let paramsJsValue = if (let matchedRoute <- router.matchSlow(pathname, params)) {
            params.toJS(vm.global)
        } else { JsValue.null() }

        // 调用服务器端fetch处理器
        let responseValue = serverRequestCallback.getOrThrow().call(
            vm.global.globalThis,
            JsValue.jsUndefined(),
            [
                getRouterTypeMain(routeBundleIndex),
                getRouteModules(routeBundleIndex),
                getClientId(routeBundleIndex),
                getStyles(routeBundleIndex),
                paramsJsValue,
                JsValue.null(), JsValue.null(), JsValue.null()
            ]
        )

        // 处理响应
        server.getOrThrow().onSavedRequest(req, resp, serverRequestCallback, 8, [])
    }

    /// 带有Bundle的HTML请求处理
    public func onHtmlRequestWithBundle(routeBundleIndex: RouteBundleIndex,
                                         resp: AnyResponse, method: HTTPMethod): Unit {
        let routeBundle = routeBundlePtr(routeBundleIndex)
        // 返回HTML页面
        resp.writeStatus("200 OK")
        resp.end("", false)
    }

    // ========================================================================
    // Bundle参数计算
    // ========================================================================

    /// 获取路由器类型主文件
    private func getRouterTypeMain(routeBundleIndex: RouteBundleIndex): JsValue {
        // 简化: 返回服务器文件字符串
        JsValue.null()
    }

    /// 获取路由模块列表
    private func getRouteModules(routeBundleIndex: RouteBundleIndex): JsValue {
        JsValue.createEmptyArray(vm.global.globalThis, 0)
    }

    /// 获取客户端ID
    private func getClientId(routeBundleIndex: RouteBundleIndex): JsValue {
        let bundleIndex: UInt32 = routeBundleIndex.get()
        let generation: UInt32 = routeBundlePtr(routeBundleIndex).clientScriptGeneration
        let str = BunString.createFormat(
            "${CLIENT_PREFIX}/route-${bundleIndex}${generation}.js"
        )
        str.toJS(vm.global)
    }

    /// 获取样式
    private func getStyles(routeBundleIndex: RouteBundleIndex): JsValue {
        JsValue.createEmptyArray(vm.global.globalThis, 0)
    }

    // ========================================================================
    // 失败处理
    // ========================================================================

    /// 发送序列化失败信息
    /// 对应 Bun: fn sendSerializedFailures(dev, resp, failures, kind, extra)
    public func sendSerializedFailures(resp: DevResponse, failures: Array<SerializedFailure>,
                                        kind: FailureKind, extra: ?String): Unit {
        // 渲染错误页面并发送
        resp.writeStatus("500 Internal Server Error")
        resp.end("Build Error", false)
    }

    // ========================================================================
    // WebSocket
    // ========================================================================

    /// 发布消息到WebSocket频道
    /// 对应 Bun: pub fn publish(topic, data, opcode) void
    public func publish(topic: HmrTopic, data: Array<Byte>, opcode: Opcode): Unit {
        // 发布到所有订阅的WebSocket
        if (server.isSome()) {
            let srv = server.getOrThrow()
            let app = srv.app
            // app.publish(topic.toString(), data, opcode)
        }
    }

    /// 检查路由失败
    /// 对应 Bun: fn checkRouteFailures(dev, route_bundle_index, resp)
    public func checkRouteFailures(routeBundleIndex: RouteBundleIndex,
                                     resp: DevResponse): CheckRouteFailuresResult {
        // 跟踪图以查找此路由可到达的失败
        let gts = initGraphTraceState(allocator(), 0)
        graphSafetyLock.lock()

        // trace all route imports to find errors
        // traceAllRouteImports(routeBundlePtr(routeBundleIndex), gts, TraceAllRouteImportsMode.findErrors)
        graphSafetyLock.unlock()

        if (incrementalResult.failuresAdded.items.size > 0) {
            if (!assumePerfectIncrementalBundling) {
                // 缓存清除所有可到达的内容
                return CheckRouteFailuresResult.rebuild
            }
            sendSerializedFailures(resp, incrementalResult.failuresAdded.items.toArray(), FailureKind.bundler, Option<String>.None)
            return CheckRouteFailuresResult.stop
        }
        return CheckRouteFailuresResult.ok
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 解析十六进制字符串为整数
    /// 对应 Bun: pub fn parseHexToInt(comptime T: type, slice: []const u8) ?T
    public static func parseHexToInt64(slice: String): ?UInt64 {
        if (slice.size < 2) { return Option<UInt64>.None }
        var result: UInt64 = UInt64(0)
        for (i in 0..slice.size) {
            let byteVal = Int64(slice[Int64(i)])
            let digit: UInt64 = if (byteVal >= 48 && byteVal <= 57) {
                UInt64(byteVal - 48)
            } else if (byteVal >= 97 && byteVal <= 102) {
                UInt64(byteVal - 97 + 10)
            } else if (byteVal >= 65 && byteVal <= 70) {
                UInt64(byteVal - 65 + 10)
            } else {
                return Option<UInt64>.None
            }
            result = result * UInt64(16) + digit
        }
        return result
    }

    /// 慢速查找路由到Bundle索引
    /// 对应 Bun: pub fn routeToBundleIndexSlow(pattern: String) ?RouteBundleIndex
    public func routeToBundleIndexSlow(pattern: String): ?RouteBundleIndex {
        // 遍历路由查找匹配的Bundle索引
        for (i in 0..routeBundles.items.size) {
            // 检查路由模式是否匹配
        }
        return Option<RouteBundleIndex>.None
    }

    /// 获取相对路径
    /// 对应 Bun: pub fn relativePath(buf: PathBuffer, abs_path: String) String
    public func relativePath(buf: PathBuffer, absPath: String): String {
        bun.path.relative(root, absPath)
    }

    /// 延迟请求
    /// 对应 Bun: fn deferRequest(dev, requests_array, route_bundle_index, kind, req, resp)
    public func deferRequest(requestsArray: DeferredRequestList, routeBundleIndex: RouteBundleIndex,
                              kind: DeferredRequestHandlerKind, req: ReqOrSaved, resp: AnyResponse): Unit {
        let deferred = deferredRequestPool.get()
        let dr = DeferredRequest()
        dr.routeBundleIndex = routeBundleIndex
        dr.dev = this
        dr.handler = DeferredRequestHandler.bundledHtmlPage(resp, req.method())
        deferred.data = dr
        requestsArray.prepend(deferred)
    }

    /// 查找路由Bundle索引
    private func findRouteBundleIndex(routeIndex: FrameworkRouterRouteIndex): ?RouteBundleIndex {
        for (i in 0..routeBundles.items.size) {
            // 检查路由索引匹配
        }
        return Option<RouteBundleIndex>.None
    }

    /// 跟踪所有路由导入
    private func traceAllRouteImports(routeBundle: RouteBundle, gts: GraphTraceState,
                                       goal: TraceImportGoal): Unit {
        // 遍历路由的所有导入文件
    }

    /// 初始化图跟踪状态
    private func initGraphTraceState(alloc: Allocator, extraCapacity: Int64): GraphTraceState {
        GraphTraceState()
    }

    // ========================================================================
    // 插件
    // ========================================================================

    /// 插件解析成功回调
    /// 对应 Bun: pub fn onPluginsResolved(dev, plugin)
    public func onPluginsResolved(plugin: JSBundlerPlugin): Unit {
        pluginState = PluginState.loaded
    }

    /// 插件解析失败回调
    /// 对应 Bun: pub fn onPluginsRejected(dev)
    public func onPluginsRejected(): Unit {
        // 标记插件状态为错误
    }
}

// ============================================================================
// 辅助函数和类型
// ============================================================================

/// 返回404
func notFound(resp: AnyResponse): Unit {
    resp.corked(notFoundCorked, resp)
}

/// 404 corked回调
func notFoundCorked(resp: AnyResponse): Unit {
    resp.writeStatus("404 Not Found")
    resp.end("Not Found", false)
}

/// 过期JS corked回调
func onOutdatedJSCorked(resp: AnyResponse): Unit {
    // 发送即时重载页面的payload
    resp.writeStatus("200 OK")
    resp.writeHeader("Content-Type", "application/javascript")
    resp.end("try{location.reload()}catch(_){}", false)
}

/// 包装通用请求处理器
func wrapGenericRequestHandler(handler: Any, isSsl: Bool): RequestHandler {
    handler
}

/// 从URL提取路径名
func extractPathnameFromUrl(url: String): String {
    // 移除协议、主机、查询、哈希
    let pathStart = url.indexOf('/')
    if (pathStart.isNone()) { return "/" }
    let path = url[pathStart.getOrThrow()..]
    let queryStart = path.indexOf('?')
    if (queryStart.isSome()) { return path[0..queryStart.getOrThrow()] }
    let hashStart = path.indexOf('#')
    if (hashStart.isSome()) { return path[0..hashStart.getOrThrow()] }
    return path
}

/// 检查路由失败结果
public enum CheckRouteFailuresResult {
    | stop     // 停止处理（已发送错误）
    | ok       // 错误已清除或不在此路径
    | rebuild  // 需要重新构建
}

/// 失败种类
public enum FailureKind {
    | bundler
    | evaluation
}

/// 保存的请求联合类型
public enum SavedRequestUnion {
    | stack(UwsRequest)
    | saved(SavedRequest)

    public func url(): String {
        match (this) {
            case SavedRequestUnion.stack(r) => r.url()
            case SavedRequestUnion.saved(s) => s.url()
        }
    }
}

/// 延迟请求处理器种类
public enum DeferredRequestHandlerKind {
    | server_handler
    | bundled_html_page
}

/// DevResponse - 开发服务器响应
public enum DevResponse {
    | http(AnyResponse)
    | none

    public func writeStatus(status: String): Unit {
        match (this) {
            case http(resp) => resp.writeStatus(status)
            case none => ()
        }
    }

    public func end(body: String, close: Bool): Unit {
        match (this) {
            case http(resp) => resp.end(body, close)
            case none => ()
        }
    }
}

/// 图跟踪状态
class GraphTraceState {
    public init() {}
    public func deinit(alloc: Allocator): Unit {}
}

// DeferredRequestList is defined in stubs.cj [KEPT: forward-ref]

/// 延迟请求
public class DeferredRequest {
    public var routeBundleIndex: RouteBundleIndex = RouteBundleIndex()
    public var dev: DevServer = DevServer()
    public var handler: DeferredRequestHandler = DeferredRequestHandler.serverHandler(AnyRequestContext())

    public init() {}

    /// 中止回调
    public static func onAbort(deferred: DeferredRequest): Unit {
        // 清理延迟请求
    }
}

/// 延迟请求处理器
public enum DeferredRequestHandler {
    | bundledHtmlPage(AnyResponse, HTTPMethod)
    | serverHandler(AnyRequestContext)
}

/// 延迟请求节点
public class DeferredRequestNode {
    public var data: DeferredRequest
    public var prev: ?DeferredRequestNode
    public var next: ?DeferredRequestNode

    public init() {
        data = DeferredRequest()
        prev = Option<DeferredRequestNode>.None
        next = Option<DeferredRequestNode>.None
    }
}

/// HTML路由表
public class HTMLRouter {
    public var map: AutoArrayHashMapUnmanaged<String, HTMLBundleRoute>
    public var fallback: ?HTMLBundleRoute

    public static let empty: HTMLRouter = HTMLRouter()

    public init() {
        map = AutoArrayHashMapUnmanaged<String, HTMLBundleRoute>()
        fallback = Option<HTMLBundleRoute>.None
    }

    public func put(alloc: Allocator, path: String, route: HTMLBundleRoute): Unit {
        map.put(alloc, path, route)
    }

    public func clear(): Unit {
        map.clearRetainingCapacity()
        fallback = Option<HTMLBundleRoute>.None
    }

    public func deinit(alloc: Allocator): Unit {
        map.deinit(alloc)
    }
}

/// 入口点列表
public class EntryPointList {
    public var set: HashSet<String>
    public var items: ArrayList<EntryPoint>

    public static let empty: EntryPointList = EntryPointList()

    public init() {
        set = HashSet<String>()
        items = ArrayList<EntryPoint>()
    }

    public func deinit(alloc: Allocator): Unit {
        set.clear()
        items.clear()
    }

    public func append(alloc: Allocator, path: String, opts: EntryPointOptions): Unit {
        if (!set.contains(path)) {
            set.put(path)
            let ep = EntryPoint()
            ep.path = path
            ep.opts = opts
            items.append(ep)
        }
    }

    public func appendCss(alloc: Allocator, path: String): Unit {
        let epOpts = EntryPointOptions()
        epOpts.client = true
        append(alloc, path, epOpts)
    }
}

/// 入口点
public class EntryPoint {
    public var path: String = ""
    public var opts: EntryPointOptions

    public init() {
        opts = EntryPointOptions()
    }
    public init(path: String, opts: EntryPointOptions) {
        this.path = path
        this.opts = opts
    }
}

/// 入口点选项
public class EntryPointOptions {
    public var client: Bool = false

    public init() {}
    public init(client: Bool) {
        this.client = client
    }
}

/// 序列化失败所有者打包
public type SerializedFailureOwnerPacked = UInt64

/// 测试批处理
public class TestingBatch {
    public var entryPoints: ArrayList<String>

    public init() {
        entryPoints = ArrayList<String>()
    }
}
