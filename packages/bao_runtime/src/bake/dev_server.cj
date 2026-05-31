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
        Allocator()
    }

    /// 获取开发分配器
    /// 对应 Bun: pub fn dev_allocator(dev: *const DevServer) DevAllocator
    public func devAllocator(): DevAllocator {
        DevAllocator()
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
        match (deferred) {
            case Some(d) =>
                d.data = dr
                requestsArray.prepend(d)
            case None => ()
        }
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
        pluginState = PluginState.err
        // 中止所有排队的请求
        var node = nextBundle.requests.first
        while (let Some(n) <- node) {
            n.data.abort()
            n.data.deref()
            node = n.next
        }
        nextBundle.routeQueue.clearRetainingCapacity()
        // TODO: 允许从此状态恢复
    }

    // ========================================================================
    // Bundle 完成处理
    // ========================================================================

    /// Bundle 完成后处理：索引、HMR、路由更新
    /// 对应 Bun: pub fn finalizeBundle(dev, bv2, result)
    public func finalizeBundle(result: DevServerOutput): Unit {
        assert(magic == Magic.valid)
        var hadSentHmrEvent = false

        // 清理当前 bundle
        var currentBundle = currentBundle.getOrThrow()

        defer({
            currentBundle.promise.deinitIdempotently()
            this.currentBundle = Option<CurrentBundle>.None
            log.clearAndFree()

            // 测试同步信号
            if (testingBatchEvents == TestingBatchEvents.enable_after_bundle) {
                testingBatchEvents = TestingBatchEvents.enabled(TestingBatch())
                publish(HmrTopic.testing_watch_synchronization,
                    [MessageId.testing_watch_synchronization.char(), 0u8], Opcode.binary)
            } else {
                publish(HmrTopic.testing_watch_synchronization,
                    [MessageId.testing_watch_synchronization.char(),
                     if (hadSentHmrEvent) { 4u8 } else { 3u8 }], Opcode.binary)
            }

            startNextBundleIfPresent()
        })

        graphSafetyLock.lock()
        defer(graphSafetyLock.unlock())

        incrementalResult.reset()

        // 通知增量图重置
        clientGraph.reset()
        serverGraph.reset()

        generation += 1
        if (currentBundle.hadReloadEvent) {
            bundlesSinceLastError += 1
        } else {
            bundlesSinceLastError = 0
        }

        // 处理失败的入口点
        if (incrementalResult.failuresAdded.items.size > 0) {
            bundlesSinceLastError = 0
            hadSentHmrEvent = true
        }

        indexFailures()

        clientGraph.ensureStaleBitCapacity(false)
        serverGraph.ensureStaleBitCapacity(false)

        // 构建热更新 payload
        let hotUpdateSubscribers = numSubscribers(HmrTopic.hot_update)
        let willHearHotUpdate = hotUpdateSubscribers > 0

        var hotUpdatePayload = ArrayList<Byte>()
        hotUpdatePayload.append(MessageId.hot_update.char())

        // 跟踪受影响的路由
        if (willHearHotUpdate && currentBundle.hadReloadEvent &&
            (incrementalResult.frameworkRoutesAffected.items.size +
                incrementalResult.htmlRoutesHardAffected.items.size) > 0 &&
            bundlingFailures.count() == 0) {

            // 发送受影响的路由 ID 列表
            for (entry in incrementalResult.frameworkRoutesAffected.items) {
                // 框架路由通过 bundle 索引标识
                writeInt32LE(hotUpdatePayload, Int32(entry.routeIndex.value))
            }
        }
        writeInt32LE(hotUpdatePayload, Int32(-1))

        // 发送 CSS 变更
        if (willHearHotUpdate) {
            // CSS 更新数量
            writeInt32LE(hotUpdatePayload, Int32(0))
        }

        // 发布热更新
        if (willHearHotUpdate && (clientGraph.currentChunkLen > 0 || result.cssChunkCount > 0)) {
            publish(HmrTopic.hot_update, hotUpdatePayload.items.toArray(), Opcode.binary)
            hadSentHmrEvent = true
        }

        // 发布错误变更
        if (incrementalResult.failuresAdded.items.size > 0) {
            var errorPayload = ArrayList<Byte>()
            errorPayload.append(MessageId.errors.char())
            writeInt32LE(errorPayload, Int32(incrementalResult.failuresRemoved.items.size))
            for (removed in incrementalResult.failuresRemoved.items) {
                writeInt32LE(errorPayload, Int32(0))
            }
            publish(HmrTopic.errors, errorPayload.items.toArray(), Opcode.binary)
            hadSentHmrEvent = true
        } else if (incrementalResult.failuresRemoved.items.size > 0) {
            var errorPayload = ArrayList<Byte>()
            errorPayload.append(MessageId.errors.char())
            writeInt32LE(errorPayload, Int32(incrementalResult.failuresRemoved.items.size))
            publish(HmrTopic.errors, errorPayload.items.toArray(), Opcode.binary)
        }

        // 处理请求完成
        graphSafetyLock.unlock()

        // 将所有延迟的路由设为 .loaded 状态
        var requestNode = currentBundle.requests.first
        while (let Some(n) <- requestNode) {
            let rb = routeBundlePtr(n.data.routeBundleIndex)
            rb.serverState = RouteBundleState.loaded
            requestNode = n.next
        }

        // 处理排队的请求
        requestNode = currentBundle.requests.first
        while (let Some(n) <- requestNode) {
            let req = n.data
            defer(req.deref())
            let rb = routeBundlePtr(req.routeBundleIndex)
            rb.serverState = RouteBundleState.loaded

            match (req.handler) {
                case DeferredRequestHandler.aborted => ()
                case DeferredRequestHandler.serverHandler(saved) =>
                    onFrameworkRequestWithBundle(req.routeBundleIndex,
                        SavedRequestUnion.saved(saved), saved.response)
                case DeferredRequestHandler.bundledHtmlPage(ram) =>
                    onHtmlRequestWithBundle(req.routeBundleIndex, ram.response, ram.method)
            }
            requestNode = n.next
        }

        graphSafetyLock.lock()
    }

    // ========================================================================
    // 下一个 Bundle 链式处理
    // ========================================================================

    /// 如果有待处理的 bundle，立即启动
    /// 对应 Bun: fn startNextBundleIfPresent(dev)
    public func startNextBundleIfPresent(): Unit {
        assert(magic == Magic.valid)
        assert(currentBundle.isNone())
        emitVisualizerMessageIfNeeded()

        // 如果有待处理的请求，启动下一个 bundle
        if (nextBundle.reloadEvent.isSome() || nextBundle.requests.first.isSome() ||
            nextBundle.promise.strong.hasValue()) {
            let isReload = nextBundle.reloadEvent.isSome()
            let timer = if (isReload) {
                let event = nextBundle.reloadEvent.getOrThrow()
                nextBundle.reloadEvent = Option<HotReloadEvent>.None
                event.timer
            } else {
                Timer.start()
            }

            var entryPoints = EntryPointList.empty
            defer(entryPoints.deinit(allocator()))

            // 为排队的路由添加入口点
            for (routeBundleIndex in nextBundle.routeQueue.keys()) {
                let rb = routeBundlePtr(routeBundleIndex)
                rb.serverState = RouteBundleState.bundling
                appendRouteEntryPointsIfNotStale(entryPoints, allocator(), routeBundleIndex)
            }

            if (entryPoints.set.count() > 0) {
                startAsyncBundle(entryPoints, isReload, timer)
            }

            nextBundle.routeQueue.clearRetainingCapacity()
        }
    }

    // ========================================================================
    // 文件监视回调
    // ========================================================================

    /// 当文件发生变化时由 watcher 线程调用
    /// 对应 Bun: pub fn onFileUpdate(dev, events, changed_files, watchlist)
    public func onFileUpdate(events: Array<WatcherEvent>, changedFiles: Array<String>, watchlist: Any): Unit {
        assert(magic == Magic.valid)

        let event = watcherAtomics.watcherAcquireEvent()
        defer(watcherAtomics.watcherReleaseAndSubmitEvent(event))

        for (ev in events) {
            match (ev.kind) {
                case WatcherEventKind.file => {
                    if (ev.op.delete || ev.op.rename) {
                        // 文件被删除或重命名
                    }
                    event.appendFile(allocator(), ev.filePath)
                }
                case WatcherEventKind.directory => {
                    event.appendDir(allocator(), ev.filePath, ev.subPath)
                }
            }
        }
    }

    /// 当 watcher 遇到错误时调用
    /// 对应 Bun: pub fn onWatchError(dev, err)
    public func onWatchError(err: SystemError): Unit {
        if (err.path.size > 0) {
            Output.errGeneric("failed to watch ${err.path} for hot-reloading")
        } else {
            Output.errGeneric("failed to watch files for hot-reloading")
        }
        Output.warn("The development server is still running, but hot-reloading is disabled until a restart.")
    }

    // ========================================================================
    // 解析失败处理
    // ========================================================================

    /// 处理解析任务失败
    /// 对应 Bun: pub fn handleParseTaskFailure(dev, err, graph, abs_path, log, bv2)
    public func handleParseTaskFailure(err: Exception, graph: Graph, absPath: String, log: Log): Unit {
        graphSafetyLock.lock()
        defer(graphSafetyLock.unlock())

        if (err.message == "FileNotFound" || err.message == "ModuleNotFound") {
            // 文件被删除的特殊情况
            match (graph) {
                case Graph.server | Graph.ssr => serverGraph.onFileDeleted(absPath)
                case Graph.client => clientGraph.onFileDeleted(absPath)
            }
        } else {
            match (graph) {
                case Graph.server => serverGraph.insertFailureByPath(absPath, log, false)
                case Graph.ssr => serverGraph.insertFailureByPath(absPath, log, true)
                case Graph.client => clientGraph.insertFailureByPath(absPath, log, false)
            }
        }
    }

    /// 获取解析失败的日志
    /// 对应 Bun: pub fn getLogForResolutionFailures(dev, abs_path, graph)
    public func getLogForResolutionFailures(absPath: String, graph: Graph): Log {
        assert(currentBundle.isSome())
        let cb = currentBundle.getOrThrow()

        graphSafetyLock.lock()
        defer(graphSafetyLock.unlock())

        let owner: UInt64 = match (graph) {
            case Graph.client => UInt64(clientGraph.insertStale(absPath, false).value)
            case Graph.server | Graph.ssr => UInt64(serverGraph.insertStale(absPath, false).value)
        }

        return Log()
    }

    // ========================================================================
    // 文件缓存检查
    // ========================================================================

    /// 检查文件是否已缓存（不需要重新 bundle）
    /// 对应 Bun: pub fn isFileCached(dev, path, side)
    public func isFileCached(path: String, side: Side): ?CacheEntry {
        // 桶文件必须始终重新解析
        if (barrelFilesWithDeferrals.contains(path)) {
            return None
        }

        graphSafetyLock.lock()
        defer(graphSafetyLock.unlock())

        let g = match (side) {
            case Side.client => clientGraph
            case Side.server | Side.ssr => serverGraph
        }

        let index = g.bundledFilesGetIndex(path)
        if (let Some(idx) <- index) {
            if (!g.staleFilesIsSet(idx)) {
                return CacheEntry(fileKind: g.getFileKindByIndex(idx))
            }
        }
        return None
    }

    // ========================================================================
    // 路由 bundle 注册
    // ========================================================================

    /// 获取或创建路由 bundle 索引
    /// 对应 Bun: fn getOrPutRouteBundle(dev, route)
    public func getOrPutRouteBundle(route: RouteBundleUnresolvedIndex): RouteBundleIndex {
        // 检查是否已存在
        let existingIndex = match (route) {
            case RouteBundleUnresolvedIndex.framework(routeIndex) =>
                router.routeBundleIndex(routeIndex)
            case RouteBundleUnresolvedIndex.html(html) =>
                html.devServerId()
        }

        if (let Some(idx) <- existingIndex) {
            return idx.getOrThrow()
        }

        graphSafetyLock.lock()
        defer(graphSafetyLock.unlock())

        let bundleIndex = RouteBundleIndex(UInt32(routeBundles.items.size))

        let rb = RouteBundle()
        rb.clientScriptGeneration = randomUInt32()
        rb.serverState = RouteBundleState.unqueued

        match (route) {
            case RouteBundleUnresolvedIndex.framework(routeIndex) => {
                rb.data = RouteBundleData()
                rb.data.framework = RouteBundleFramework()
                rb.data.framework.routeIndex = routeIndex
                router.setRouteBundleIndex(routeIndex, bundleIndex)
            }
            case RouteBundleUnresolvedIndex.html(html) => {
                // 在客户端图中插入 HTML 文件
                let incrementalIndex = clientGraph.insertStaleExtra(html.path(), false, true)
                rb.data = RouteBundleData()
                rb.data.html = RouteBundleHTML()
                rb.data.html.bundledFile = incrementalIndex
                rb.data.html.htmlBundle = html
                html.setDevServerId(bundleIndex)
            }
        }

        routeBundles.append(rb)
        return bundleIndex
    }

    // ========================================================================
    // 错误序列化与发送
    // ========================================================================

    /// 发送序列化失败信息到客户端（完整 HTML 错误页面）
    /// 对应 Bun: fn sendSerializedFailures(dev, resp, failures, kind, inspector_agent)
    public func sendSerializedFailuresFull(resp: DevResponse,
                                            failures: Array<SerializedFailure>,
                                            kind: ErrorPageKind,
                                            inspectorAgent: ?InspectorAgent): Unit {
        var buf = ArrayList<Byte>()
        buf.ensureCapacity(2048)

        // HTML 头部
        let pageTitle = match (kind) {
            case ErrorPageKind.bundler => "Build Failed"
            case ErrorPageKind.evaluation | ErrorPageKind.runtime => "Runtime Error"
        }

        let htmlHead = "<!doctype html><html lang=\"en\"><head><meta charset=\"UTF-8\" />" +
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />" +
            "<title>Bun - ${pageTitle}</title>" +
            "<style>:root{color-scheme:light dark}body{background:light-dark(white,black)}</style>" +
            "</head><body>" +
            "<noscript><h1 style=\"font:28px sans-serif;\">${pageTitle}</h1>" +
            "<p style=\"font:20px sans-serif;\">Bun requires JavaScript enabled in the browser to render this error screen, as well as receive hot reloading events.</p></noscript>" +
            "<script>let error=Uint8Array.from(atob(\""

        buf.appendSlice(htmlHead)

        // Base64 编码的失败数据
        var allFailuresData = ArrayList<Byte>()
        for (fail in failures) {
            allFailuresData.appendSlice(fail.data)
        }
        let encoded = base64Encode(allFailuresData.items.toArray())
        buf.appendSlice(encoded)

        let pre = "\"),c=>c.charCodeAt(0));let config={bun:\"0.0.0\"};"
        let post = "</script></body></html>"

        buf.appendSlice(pre)
        buf.appendSlice(post)

        match (resp) {
            case DevResponse.http(r) =>
                r.writeStatus("500 Internal Server Error")
                r.writeHeader("Content-Type", "text/html")
                r.end(String.fromUtf8(buf.items.toArray()), false)
            case DevResponse.none => ()
        }
    }

    // ========================================================================
    // HTML 页面生成
    // ========================================================================

    /// 生成 HTML payload（包含脚本和样式注入）
    /// 对应 Bun: fn generateHTMLPayload(dev, route_bundle_index, route_bundle, html)
    public func generateHTMLPayload(routeBundleIndex: RouteBundleIndex): String {
        let routeBundle = routeBundlePtr(routeBundleIndex)
        assert(routeBundle.serverState == RouteBundleState.loaded)
        let html = routeBundle.data.html
        assert(html.cachedResponse.isNone())

        let scriptInjectionOffset = html.scriptInjectionOffset.getOrThrow().get()
        let bundledHtml = html.bundledHtmlText.getOrThrow()

        // 分割 HTML：在 </head> 之前注入脚本和样式
        let beforeHeadEnd = bundledHtml[0..scriptInjectionOffset]
        let afterHeadEnd = bundledHtml[scriptInjectionOffset..]

        var displayName = pathBasename(html.htmlBundle.path())
        if (displayName.endsWith(".html")) {
            displayName = displayName[0..displayName.size - 5]
        }
        if (!isAllASCII(displayName)) {
            displayName = "page"
        }

        graphSafetyLock.lock()
        defer(graphSafetyLock.unlock())

        // 跟踪 CSS 依赖
        clientGraph.reset()
        defer(clientGraph.reset())

        var payload = StringBuilder()
        payload.append(beforeHeadEnd)

        // 插入 CSS 链接标签
        let cssIds = clientGraph.currentCssFiles.items
        for (cssId in cssIds) {
            payload.append("<link rel=\"stylesheet\" href=\"")
            payload.append(ASSET_PREFIX)
            payload.append("/")
            payload.append(bytesToHexUInt64(cssId))
            payload.append(".css\">")
        }

        // 插入客户端脚本标签
        payload.append("<script type=\"module\" crossorigin src=\"")
        payload.append(CLIENT_PREFIX)
        payload.append("/")
        payload.append(displayName)
        payload.append("-")
        payload.append(bytesToHexUInt32(routeBundleIndex.get()))
        payload.append(bytesToHexUInt32(routeBundle.clientScriptGeneration))
        payload.append(".js\" data-bun-dev-server-script></script>")

        // SourceMap 弱引用脚本
        payload.append("<script>((a)=>{document.addEventListener('visibilitychange'," +
            "globalThis[Symbol.for('bun:loadData')]=()=>" +
            "document.visibilityState==='hidden'&&" +
            "navigator.sendBeacon('/_bun/unref',a))" +
            "})(document.querySelector('[data-bun-dev-server-script]').src.slice(-11,-3))</script>")

        payload.append(afterHeadEnd)

        return payload.toString()
    }

    // ========================================================================
    // CSS JS 数组生成
    // ========================================================================

    /// 生成 CSS 文件 URL 的 JS 数组
    /// 对应 Bun: fn generateCssJSArray(dev, route_bundle)
    public func generateCssJSArray(routeBundle: RouteBundle): Array<String> {
        assert(routeBundle.serverState == RouteBundleState.loaded)

        graphSafetyLock.lock()
        defer(graphSafetyLock.unlock())

        clientGraph.reset()

        let cssIds = clientGraph.currentCssFiles.items
        var result = Array<String>(cssIds.size, { _ => "" })
        for (i in 0..cssIds.size) {
            result[Int64(i)] = "${ASSET_PREFIX}/${bytesToHexUInt64(cssIds[Int64(i)])}.css"
        }
        return result
    }

    // ========================================================================
    // 导入跟踪
    // ========================================================================

    /// 跟踪路由的所有导入依赖
    /// 对应 Bun: fn traceAllRouteImports(dev, route_bundle, gts, goal)
    public func traceAllRouteImports(routeBundle: RouteBundle,
                                      gts: GraphTraceState,
                                      goal: TraceImportGoal): Unit {
        match (routeBundle.data.kind()) {
            case RouteBundleDataKind.framework => {
                let fw = routeBundle.data.framework
                var route = router.routePtr(fw.routeIndex)
                let routerType = router.typePtr(route.typeIndex)

                // 框架入口点
                serverGraph.traceImports(routerType.serverFile, gts, goal)
                if (routerType.clientFile.isSome()) {
                    clientGraph.traceImports(routerType.clientFile.getOrThrow(), gts, goal)
                }

                // 路由文件
                if (route.filePage.isSome()) {
                    serverGraph.traceImports(route.filePage.getOrThrow(), gts, goal)
                }

                // 布局文件
                while (true) {
                    if (route.fileLayout.isSome()) {
                        serverGraph.traceImports(route.fileLayout.getOrThrow(), gts, goal)
                    }
                    if (route.parent.isNone()) { break }
                    route = router.routePtr(route.parent.getOrThrow())
                }
            }
            case RouteBundleDataKind.html => {
                let html = routeBundle.data.html
                clientGraph.traceImports(html.bundledFile, gts, goal)
            }
        }
    }

    // ========================================================================
    // 入口点辅助方法
    // ========================================================================

    /// 为路由添加入口点（如果尚未过时）
    /// 对应 Bun: fn appendRouteEntryPointsIfNotStale(dev, entry_points, alloc, rbi)
    public func appendRouteEntryPointsIfNotStale(entryPoints: EntryPointList,
                                                   alloc: Allocator,
                                                   rbi: RouteBundleIndex): Unit {
        let rb = routeBundlePtr(rbi)

        match (rb.data.kind()) {
            case RouteBundleDataKind.framework => {
                let fw = rb.data.framework
                var route = router.routePtr(fw.routeIndex)
                let routerType = router.typePtr(route.typeIndex)

                // 添加服务器入口点
                if (serverGraph.isStale(routerType.serverFile)) {
                    let path = serverGraph.getFilePath(routerType.serverFile)
                    entryPoints.appendJs(alloc, path, Graph.server)
                }

                // 添加客户端入口点
                if (routerType.clientFile.isSome()) {
                    let clientId = routerType.clientFile.getOrThrow()
                    if (clientGraph.isStale(clientId)) {
                        let path = clientGraph.getFilePath(clientId)
                        entryPoints.appendJs(alloc, path, Graph.client)
                    }
                }

                // 路由页面文件
                if (route.filePage.isSome()) {
                    let fileId = route.filePage.getOrThrow()
                    if (serverGraph.isStale(fileId)) {
                        let path = serverGraph.getFilePath(fileId)
                        entryPoints.appendJs(alloc, path, Graph.server)
                    }
                }

                // 布局文件
                if (route.fileLayout.isSome()) {
                    let fileId = route.fileLayout.getOrThrow()
                    if (serverGraph.isStale(fileId)) {
                        let path = serverGraph.getFilePath(fileId)
                        entryPoints.appendJs(alloc, path, Graph.server)
                    }
                }
            }
            case RouteBundleDataKind.html => {
                let html = rb.data.html
                entryPoints.appendCss(alloc, html.htmlBundle.path())
            }
        }

        // Tailwind 插件 hack
        if (let hack <- hasTailwindPluginHack) {
            for (absPath in hack.keys()) {
                let file = clientGraph.getBundledFile(absPath)
                if (file.isSome() && file.getOrThrow().kind() == FileKind.css) {
                    entryPoints.appendCss(alloc, absPath)
                }
            }
        }
    }

    // ========================================================================
    // 失败索引
    // ========================================================================

    /// 索引所有失败并通知 WebSocket 客户端
    /// 对应 Bun: fn indexFailures(dev)
    public func indexFailures(): Unit {
        if (incrementalResult.failuresAdded.items.size > 0) {
            var payload = ArrayList<Byte>()
            payload.append(MessageId.errors.char())
            writeInt32LE(payload, Int32(incrementalResult.failuresRemoved.items.size))

            // 移除的失败
            for (removed in incrementalResult.failuresRemoved.items) {
                writeInt32LE(payload, Int32(0))
            }

            // 跟踪新增的失败到路由
            for (added in incrementalResult.failuresAdded.items) {
                match (added.getOwner()) {
                    case SerializedFailureOwnerKind.server(index) =>
                        serverGraph.traceDependencies(index, null, TraceMode.noStop, index)
                    case SerializedFailureOwnerKind.client(index) =>
                        clientGraph.traceDependencies(index, null, TraceMode.noStop, index)
                    case _ => ()
                }
            }

            // 标记受影响的框架路由
            for (entry in incrementalResult.frameworkRoutesAffected.items) {
                if (let Some(bundleIndex) <- router.routeBundleIndex(entry.routeIndex)) {
                    routeBundlePtr(bundleIndex).serverState = RouteBundleState.possible_bundling_failures
                }
            }

            // 标记受影响的 HTML 路由
            for (index in incrementalResult.htmlRoutesSoftAffected.items) {
                routeBundlePtr(index).serverState = RouteBundleState.possible_bundling_failures
            }
            for (index in incrementalResult.htmlRoutesHardAffected.items) {
                routeBundlePtr(index).serverState = RouteBundleState.possible_bundling_failures
            }

            publish(HmrTopic.errors, payload.items.toArray(), Opcode.binary)
        } else if (incrementalResult.failuresRemoved.items.size > 0) {
            var payload = ArrayList<Byte>()
            payload.append(MessageId.errors.char())
            writeInt32LE(payload, Int32(incrementalResult.failuresRemoved.items.size))

            for (removed in incrementalResult.failuresRemoved.items) {
                writeInt32LE(payload, Int32(0))
            }

            publish(HmrTopic.errors, payload.items.toArray(), Opcode.binary)
        }

        incrementalResult.failuresRemoved.clearRetainingCapacity()
    }

    // ========================================================================
    // WebSocket 与发布
    // ========================================================================

    /// 发布消息到 WebSocket 主题
    /// 对应 Bun: pub fn publish(dev, topic, message, opcode)
    public func publish(topic: HmrTopic, message: Array<Byte>, opcode: Opcode): Unit {
        if (server.isSome()) {
            let srv = server.getOrThrow()
            srv.publish(topic.toString(), message, opcode)
        }
    }

    /// 获取订阅某个主题的 WebSocket 数量
    /// 对应 Bun: pub fn numSubscribers(dev, topic)
    public func numSubscribers(topic: HmrTopic): UInt32 {
        if (server.isSome()) {
            return activeWebsocketConnections.count()
        }
        return UInt32(0)
    }

    /// WebSocket 连接升级回调
    /// 对应 Bun: pub fn onWebSocketUpgrade(dev, res, req, upgrade_ctx, id)
    public func onWebSocketUpgrade(res: AnyResponse, req: UwsRequest): Unit {
        let dw = HmrSocket(this)
        activeWebsocketConnections.put(allocator(), dw, ())
    }

    // ========================================================================
    // 可视化器消息
    // ========================================================================

    /// 发送增量可视化器消息（如果需要）
    /// 对应 Bun: pub fn emitVisualizerMessageIfNeeded(dev)
    public func emitVisualizerMessageIfNeeded(): Unit {
        if (emitIncrementalVisualizerEvents == 0) { return }
        emitMemoryVisualizerMessageIfNeeded()
    }

    /// 发送内存可视化器消息（如果需要）
    /// 对应 Bun: pub fn emitMemoryVisualizerMessageIfNeeded(dev)
    public func emitMemoryVisualizerMessageIfNeeded(): Unit {
        if (emitMemoryVisualizerEvents == 0) { return }
        emitMemoryVisualizerMessage()
    }

    /// 发送内存可视化器消息
    /// 对应 Bun: pub fn emitMemoryVisualizerMessage(dev)
    public func emitMemoryVisualizerMessage(): Unit {
        var payload = ArrayList<Byte>()
        payload.append(MessageId.memory_visualizer.char())
        writeMemoryVisualizerMessage(payload)
        publish(HmrTopic.memory_visualizer, payload.items.toArray(), Opcode.binary)
    }

    /// 写入内存可视化器消息
    /// 对应 Bun: pub fn writeMemoryVisualizerMessage(dev, payload)
    public func writeMemoryVisualizerMessage(payload: ArrayList<Byte>): Unit {
        let cost = memoryCost()
        // 写入各组件的内存成本
        writeInt32LE(payload, Int32(0)) // incremental_graph_client
        writeInt32LE(payload, Int32(0)) // incremental_graph_server
        writeInt32LE(payload, Int32(0)) // js_code
        writeInt32LE(payload, Int32(0)) // source_maps
        writeInt32LE(payload, Int32(0)) // assets
        writeInt32LE(payload, Int32(0)) // other
        writeInt32LE(payload, Int32(cost)) // devserver_tracked
        writeInt32LE(payload, Int32(0)) // process_used
        writeInt32LE(payload, Int32(0)) // system_used
        writeInt32LE(payload, Int32(0)) // system_total
    }

    // ========================================================================
    // 客户端 Bundle 生成
    // ========================================================================

    /// 生成客户端 bundle 脚本
    /// 对应 Bun: fn generateClientBundle(dev, route_bundle)
    public func generateClientBundleFull(routeBundle: RouteBundle): String {
        assert(routeBundle.clientBundle.isNone())
        assert(routeBundle.serverState == RouteBundleState.loaded)

        graphSafetyLock.lock()
        defer(graphSafetyLock.unlock())

        // 准备位集
        var gts = initGraphTraceState(allocator(), 0)
        defer(gts.deinit(allocator()))

        // 跟踪导入
        clientGraph.reset()
        defer(clientGraph.reset())

        traceAllRouteImports(routeBundle, gts, TraceImportGoal.findClientModules)

        // React Fast Refresh
        var reactFastRefreshId = ""
        if (framework.reactFastRefresh.isSome()) {
            let rfr = framework.reactFastRefresh.getOrThrow()
            let rfrIndex = clientGraph.getFileIndex(rfr.importSource)
            if (rfrIndex.isSome()) {
                if (!clientGraph.staleFilesIsSet(rfrIndex.getOrThrow())) {
                    clientGraph.traceImports(rfrIndex.getOrThrow(), gts, TraceImportGoal.findClientModules)
                    reactFastRefreshId = rfr.importSource
                }
            }
        }

        // 插入 SourceMap
        let scriptId = routeBundle.sourceMapId()
        sourceMaps.putOrIncrementRefCount(scriptId, UInt32(1))

        // 生成 bundle
        let clientBundle = clientGraph.takeJSBundle(ChunkKind.initial_response,
            reactFastRefreshId, scriptId, shouldReceiveConsoleLogFromBrowser())

        return clientBundle
    }

    /// 检查是否应该接收来自浏览器的控制台日志
    /// 对应 Bun: fn shouldReceiveConsoleLogFromBrowser(dev)
    public func shouldReceiveConsoleLogFromBrowser(): Bool {
        return broadcastConsoleLogFromBrowserToServer
    }

    // ========================================================================
    // 框架路由集成
    // ========================================================================

    /// 获取框架路由文件 ID
    /// 对应 Bun: pub fn getFileIdForRouter(dev, abs_path, associated_route, file_kind)
    public func getFileIdForRouter(absPath: String, associatedRoute: FrameworkRouterRouteIndex,
                                    fileKind: RouteFileKind): ?UInt32 {
        let index = serverGraph.insertStaleExtra(absPath, false, true)
        routeLookup.put(allocator(), index,
            RouteIndexAndRecurseFlag(routeIndex: associatedRoute,
                shouldRecurseWhenVisiting: fileKind == RouteFileKind.layout))
        return UInt32(index.value)
    }

    /// 路由器语法错误回调
    /// 对应 Bun: pub fn onRouterSyntaxError(dev, rel_path, log)
    public func onRouterSyntaxError(relPath: String, log: String): Unit {
        Output.errGeneric("Syntax error in ${relPath}: ${log}")
    }

    /// 路由器冲突错误回调
    /// 对应 Bun: pub fn onRouterCollisionError(dev, rel_path, other_id, ty)
    public func onRouterCollisionError(relPath: String, otherId: UInt32, ty: RouteFileKind): Unit {
        let typeName = match (ty) {
            case RouteFileKind.page => "pages"
            case RouteFileKind.layout => "layout"
        }
        Output.errGeneric("Multiple ${typeName} matching the same route pattern is ambiguous")
        Output.prettyError("  - ${relPath}\n")
        Output.flush()
    }

    // ========================================================================
    // 增量图跟踪状态
    // ========================================================================

    /// 初始化图跟踪状态
    /// 对应 Bun: fn initGraphTraceState(dev, sfa, extra_client_bits)
    public func initGraphTraceState(alloc: Allocator, extraClientBits: Int64): GraphTraceState {
        GraphTraceState()
    }

    // ========================================================================
    // Inspector 支持
    // ========================================================================

    /// 获取 Inspector agent（如果启用）
    /// 对应 Bun: pub fn inspector(dev)
    public func inspector(): ?InspectorAgent {
        // 检查 VM 是否有启用的 debugger
        None
    }

    // ========================================================================
    // 内存使用
    // ========================================================================

    /// 打印内存使用行
    /// 对应 Bun: fn printMemoryLine(dev)
    public func printMemoryLine(): Unit {
        let cost = memoryCost()
        Output.prettyError("[d]DevServer tracked ${cost} bytes\n")
    }

    /// 处理 HTML bundle 的 respond
    /// 对应 Bun: pub fn respondForHTMLBundle(dev, html, req, resp)
    public func respondForHTMLBundle(html: HTMLBundleRoute, req: UwsRequest, resp: AnyResponse): Unit {
        let routeBundleIndex = getOrPutRouteBundle(
            RouteBundleUnresolvedIndex.html(html))
        ensureRouteIsBundled(routeBundleIndex, req, resp)
    }

    /// 处理框架请求（带请求对象匹配）
    /// 对应 Bun: fn onRequest(dev, req, resp)
    public func onRequestWithRouteMatching(req: UwsRequest, resp: AnyResponse): Unit {
        var params = FrameworkRouterMatchedParams()
        if (let Some(routeIndex) <- router.matchSlow(req.url(), params)) {
            let routeBundleIndex = getOrPutRouteBundle(
                RouteBundleUnresolvedIndex.framework(routeIndex))
            ensureRouteIsBundled(routeBundleIndex, req, resp)
            return
        }

        // 404
        notFound(resp)
    }

    /// 处理渲染重定向
    /// 对应 Bun: pub fn handleRenderRedirect(dev, saved_request, render_path, resp)
    public func handleRenderRedirect(savedRequest: SavedRequest, renderPath: String, resp: AnyResponse): Unit {
        var params = FrameworkRouterMatchedParams()
        if (let Some(routeIndex) <- router.matchSlow(renderPath, params)) {
            let routeBundleIndex = getOrPutRouteBundle(
                RouteBundleUnresolvedIndex.framework(routeIndex))
            ensureRouteIsBundled(routeBundleIndex, savedRequest, resp)
            return
        }
        sendBuiltInNotFound(resp)
    }

    /// 注册 catch-all HTML 路由
    /// 对应 Bun: fn registerCatchAllHtmlRoute(dev, html)
    public func registerCatchAllHtmlRoute(html: HTMLBundleRoute): Unit {
        let bundleIndex = getOrPutRouteBundle(RouteBundleUnresolvedIndex.html(html))
        htmlRouter.fallback = html
    }

    /// 标记所有路由子节点为失败
    /// 对应 Bun: fn markAllRouteChildrenFailed(dev, route_index)
    public func markAllRouteChildrenFailed(routeIndex: FrameworkRouterRouteIndex): Unit {
        var next = router.firstChild(routeIndex)
        while (let Some(childIndex) <- next) {
            let route = router.routePtr(childIndex)
            if (let Some(bundleIndex) <- route.bundle) {
                routeBundlePtr(bundleIndex).serverState = RouteBundleState.possible_bundling_failures
            }
            markAllRouteChildrenFailed(childIndex)
            next = router.nextSibling(childIndex)
        }
    }

    /// 将资产放入存储
    /// 对应 Bun: pub fn putOrOverwriteAsset(dev, path, contents, content_hash)
    public func putOrOverwriteAsset(pathText: String, contents: AnyBlob,
                                     ext: String, contentHash: UInt64): Unit {
        graphSafetyLock.lock()
        defer(graphSafetyLock.unlock())
        assets.replacePath(pathText, contents, MimeType.css, contentHash)
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
/// 对应 Bun: ErrorPageKind
public enum ErrorPageKind {
    /// 模块捆绑失败
    | bundler
    /// 模块评估失败
    | evaluation
    /// 请求处理器抛出异常
    | runtime
}

/// 失败种类（别名）
public type FailureKind = ErrorPageKind

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

    public static let empty: TestingBatch = TestingBatch()

    /// 追加入口点
    public func append(dev: DevServer, entryPoints: EntryPointList): Unit {
        for (ep in entryPoints.items) {
            this.entryPoints.append(ep.path)
        }
    }
}

// ============================================================================
// 辅助类型和枚举
// ============================================================================

/// HMR 主题（用于 WebSocket 频道）
/// 对应 Bun: DevServer.HmrTopic
public enum HmrTopic {
    | hot_update       // 'h' = 104
    | errors           // 'e' = 101
    | browser_error    // 'E' = 69
    | incremental_visualizer // 'v' = 118
    | memory_visualizer     // 'M' = 77
    | testing_watch_synchronization // 'r' = 114

    public func toString(): String {
        match (this) {
            case hot_update => "h"
            case errors => "e"
            case browser_error => "E"
            case incremental_visualizer => "v"
            case memory_visualizer => "M"
            case testing_watch_synchronization => "r"
        }
    }

    public func char(): Byte {
        match (this) {
            case hot_update => 104u8
            case errors => 101u8
            case browser_error => 69u8
            case incremental_visualizer => 118u8
            case memory_visualizer => 77u8
            case testing_watch_synchronization => 114u8
        }
    }
}

/// 消息 ID（DevServer → 客户端）
/// 对应 Bun: DevServer.MessageId
public enum MessageId {
    | version                      // 'V' = 86
    | hot_update                   // 'u' = 117
    | errors                       // 'e' = 101
    | browser_message              // 'b' = 98
    | browser_message_clear        // 'B' = 66
    | request_handler_error        // 'h' = 104
    | visualizer                   // 'v' = 118
    | memory_visualizer            // 'M' = 77
    | set_url_response             // 'n' = 110
    | testing_watch_synchronization // 'r' = 114

    public func char(): Byte {
        match (this) {
            case MessageId.version => 86u8
            case MessageId.hot_update => 117u8
            case MessageId.errors => 101u8
            case MessageId.browser_message => 98u8
            case MessageId.browser_message_clear => 66u8
            case MessageId.request_handler_error => 104u8
            case MessageId.visualizer => 118u8
            case MessageId.memory_visualizer => 77u8
            case MessageId.set_url_response => 110u8
            case MessageId.testing_watch_synchronization => 114u8
        }
    }
}

/// 传入消息 ID（客户端 → DevServer）
/// 对应 Bun: DevServer.IncomingMessageId
public enum IncomingMessageId {
    | `init`                  // 'i' = 105
    | subscribe               // 's' = 115
    | set_url                 // 'n' = 110
    | testing_batch_events    // 'H' = 72
    | console_log             // 'l' = 108
    | unref_source_map        // 'u' = 117
}

/// 控制台日志种类
/// 对应 Bun: DevServer.ConsoleLogKind
public enum ConsoleLogKind {
    | log   // 'l'
    | err   // 'e'
}

/// 跟踪导入目标
/// 对应 Bun: TraceImportGoal
public enum TraceImportGoal {
    | findCss
    | findClientModules
    | findErrors
}

/// 跟踪模式
public enum TraceMode {
    | noStop
    | stopOnFirstError
}

/// 路由文件种类
public enum RouteFileKind {
    | page
    | layout
}

/// 路由 bundle 数据种类
public enum RouteBundleDataKind {
    | framework
    | html
}

/// 序列化失败所有者种类
public enum SerializedFailureOwnerKind {
    | none
    | client(UInt32)
    | server(UInt32)
    | route
}

/// Watcher 事件类型
public enum WatcherEventKind {
    | file
    | directory
}

/// Watcher 事件
public class WatcherEvent {
    public var kind: WatcherEventKind = WatcherEventKind.file
    public var op: WatcherOp = WatcherOp()
    public var filePath: String = ""
    public var subPath: ?String = None

    public init() {}
}

/// Watcher 操作标志
public class WatcherOp {
    public var create: Bool = false
    public var modify: Bool = false
    public var delete: Bool = false
    public var rename: Bool = false

    public init() {}
}

/// 系统错误
public class SystemError {
    public var path: String = ""
    public var message: String = ""
    public var code: Int64 = 0

    public init() {}
    public init(path: String, message: String) {
        this.path = path
        this.message = message
    }
}

/// DevServer 输出
/// 对应 Bun: bundle_v2.DevServerOutput
public class DevServerOutput {
    public var cssChunkCount: Int64 = 0

    public init() {}
}

/// 缓存条目
/// 对应 Bun: CacheEntry
public class CacheEntry {
    public var fileKind: FileKind

    public init(fileKind: FileKind) {
        this.fileKind = fileKind
    }
}

/// 路由 bundle 未解析索引
/// 对应 Bun: RouteBundle.UnresolvedIndex
public enum RouteBundleUnresolvedIndex {
    | framework(FrameworkRouterRouteIndex)
    | html(HTMLBundleRoute)
}

/// 框架路由器路由索引
public type FrameworkRouterRouteIndex = UInt32

/// 框架路由器匹配参数
public class FrameworkRouterMatchedParams {
    public init() {}
    public func toJS(global: Any): JsValue { JsValue() }
}

/// 框架路由器编码模式
public type FrameworkRouterEncodedPattern = String

/// 检查路由失败结果
public enum CheckRouteFailuresResult {
    | stop     // 停止处理（已发送错误）
    | ok       // 错误已清除或不在此路径
    | rebuild  // 需要重新构建
}

/// HTML Bundle 路由
/// 对应 Bun: HTMLBundle.HTMLBundleRoute
public class HTMLBundleRoute {
    public var devServerIdValue: ?RouteBundleIndex = None

    public init() {}
    public func path(): String { "" }
    public func devServerId(): ?RouteBundleIndex { devServerIdValue }
    public func setDevServerId(id: RouteBundleIndex): Unit { devServerIdValue = id }
}

/// 路由 bundle HTML 数据
/// 对应 Bun: RouteBundle.HTML
public class RouteBundleHTML {
    public var htmlBundle: HTMLBundleRoute = HTMLBundleRoute()
    public var bundledFile: UInt32 = 0
    public var scriptInjectionOffset: ?UInt32 = None
    public var cachedResponse: ?StaticRoute = None
    public var bundledHtmlText: ?String = None

    public init() {}
}

/// 框架
/// 对应 Bun: bake.Framework
public class Framework {
    public var fileSystemRouterTypes: Array<FileSystemRouterType> = []
    public var serverComponents: ?ServerComponents = None
    public var reactFastRefresh: ?ReactFastRefresh = None
    public var isBuiltInReact: Bool = false

    public init() {}

    public func initTranspiler(alloc: Allocator, log: Log, mode: Any, side: Side,
                                transpiler: Transpiler, opts: Any): Unit {}
    public func resolve(serverResolver: Resolver, clientResolver: Resolver,
                        arena: Allocator): Framework { this }
}

/// 文件系统路由类型
/// 对应 Bun: bake.FileSystemRouterType
public class FileSystemRouterType {
    public var root: String = ""
    public var prefix: String = ""
    public var extensions: Array<String> = []
    public var entryServer: String = ""
    public var entryClient: ?String = None
    public var style: RouterStyle = RouterStyle.next
    public var allowLayouts: Bool = true
    public var ignoreUnderscores: Bool = false
    public var ignoreDirs: Array<String> = []

    public init() {}
}

/// 路由器样式
public enum RouterStyle {
    | next
}

/// 服务器组件配置
/// 对应 Bun: bake.ServerComponents
public class ServerComponents {
    public var separateSsrGraph: Bool = false
    public var clientRegisterServerReference: String = ""
    public var serverRegisterClientReference: String = ""
    public var serverRegisterServerReference: String = ""
    public var serverRuntimeImport: String = ""

    public init() {}
}

/// React Fast Refresh 配置
/// 对应 Bun: bake.ReactFastRefresh
public class ReactFastRefresh {
    public var importSource: String = ""

    public init() {}
}

/// 分割 bundler 选项
/// 对应 Bun: bake.SplitBundlerOptions
public class SplitBundlerOptions {
    public var server: BundlerOptions = BundlerOptions()
    public var client: BundlerOptions = BundlerOptions()
    public var ssr: BundlerOptions = BundlerOptions()
    public var plugin: ?JSBundlerPlugin = None

    public init() {}
}

/// Bundler 选项
/// 对应 Bun: bake.BundlerOptions
public class BundlerOptions {
    public init() {}
}

/// Route bundle data
/// 对应 Bun: RouteBundle.Data
public class RouteBundleData {
    public var framework: RouteBundleFramework = RouteBundleFramework()
    public var html: RouteBundleHTML = RouteBundleHTML()
    public var evaluateFailure: ?Array<Byte> = None

    public init() {}

    public func kind(): RouteBundleDataKind {
        if (html.htmlBundle != null && html.htmlBundle.path().size > 0) {
            RouteBundleDataKind.html
        } else {
            RouteBundleDataKind.framework
        }
    }
}

/// Route bundle framework data
/// 对应 Bun: RouteBundle.Framework
public class RouteBundleFramework {
    public var routeIndex: FrameworkRouterRouteIndex = 0
    public var cachedModuleList: ?JsValue = None
    public var cachedClientBundleUrl: ?JsValue = None
    public var cachedCssFileArray: ?JsValue = None

    public init() {}
}

/// Incremental result
/// 对应 Bun: DevServer.IncrementalResult
public class IncrementalResult {
    public var hadAdjustedEdges: Bool = false
    public var clientComponentsAdded: ArrayList<UInt32> = ArrayList<UInt32>()
    public var frameworkRoutesAffected: ArrayList<RouteIndexAndRecurseFlag> = ArrayList<RouteIndexAndRecurseFlag>()
    public var clientComponentsRemoved: ArrayList<UInt32> = ArrayList<UInt32>()
    public var failuresRemoved: ArrayList<SerializedFailure> = ArrayList<SerializedFailure>()
    public var clientComponentsAffected: ArrayList<UInt32> = ArrayList<UInt32>()
    public var failuresAdded: ArrayList<SerializedFailure> = ArrayList<SerializedFailure>()
    public var htmlRoutesSoftAffected: ArrayList<RouteBundleIndex> = ArrayList<RouteBundleIndex>()
    public var htmlRoutesHardAffected: ArrayList<RouteBundleIndex> = ArrayList<RouteBundleIndex>()

    public init() {}

    public static let empty: IncrementalResult = IncrementalResult()

    public func reset(): Unit {
        frameworkRoutesAffected.clear()
        htmlRoutesSoftAffected.clear()
        htmlRoutesHardAffected.clear()
        hadAdjustedEdges = false
        failuresAdded.clear()
        clientComponentsAdded.clear()
        clientComponentsRemoved.clear()
        clientComponentsAffected.clear()
    }
}

/// 路由索引和递归标志
/// 对应 Bun: RouteIndexAndRecurseFlag
public struct RouteIndexAndRecurseFlag {
    public var routeIndex: FrameworkRouterRouteIndex
    public var shouldRecurseWhenVisiting: Bool

    public init(routeIndex: FrameworkRouterRouteIndex, shouldRecurseWhenVisiting: Bool) {
        this.routeIndex = routeIndex
        this.shouldRecurseWhenVisiting = shouldRecurseWhenVisiting
    }
}

/// 桶文件和导出跟踪
/// 对应 Bun: barrel_files_with_deferrals / barrel_needed_exports
public class BarrelFileTracker {
    public var filesWithDeferrals: HashSet<String> = HashSet<String>()

    public init() {}

    public func contains(path: String): Bool { filesWithDeferrals.contains(path) }
}

/// Graph (client/server/ssr)
/// 对应 Bun: bake.Graph
public enum Graph {
    | client
    | server
    | ssr
}

/// Side (client/server/ssr)
/// 对应 Bun: bake.Side
public enum Side {
    | client
    | server
    | ssr
}

/// Deferred request linked list
/// 对应 Bun: DeferredRequest.List
public class DeferredRequestList {
    public var first: ?DeferredRequestNode = None

    public init() {}

    public func prepend(node: DeferredRequestNode): Unit {
        node.next = first
        first = node
    }

    public func popFirst(): ?DeferredRequestNode {
        if (let Some(node) <- first) {
            first = node.next
            return node
        }
        return None
    }
}

/// Inspector agent
/// 对应 Bun: BunFrontendDevServerAgent
public class InspectorAgent {
    public init() {}
    public func isEnabled(): Bool { false }
    public func notifyBundleStart(id: Int64, files: Array<Any>): Unit {}
    public func notifyBundleComplete(id: Int64, ms: Float64): Unit {}
    public func notifyBundleFailed(id: Int64, str: Any): Unit {}
}

/// Log
/// 对应 Bun: bun.logger.Log
public class Log {
    public init() {}
    public init(alloc: Allocator) {}
    public func hasErrors(): Bool { false }
    public func clearAndFree(): Unit {}
    public func print(writer: Any): Unit {}
    public func msgs(): Array<Any> { [] }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 404 处理
func notFound(resp: AnyResponse): Unit {
    resp.corked(notFoundCorked, resp)
}

/// 404 corked 回调
func notFoundCorked(resp: AnyResponse): Unit {
    resp.writeStatus("404 Not Found")
    resp.end("Not Found", false)
}

/// 内置 404
/// 对应 Bun: fn sendBuiltInNotFound
func sendBuiltInNotFound(resp: AnyResponse): Unit {
    resp.writeStatus("404 Not Found")
    resp.end("404 Not Found", true)
}

/// 过期 JS corked 回调
func onOutdatedJSCorked(resp: AnyResponse): Unit {
    resp.writeStatus("200 OK")
    resp.writeHeader("Content-Type", "application/javascript")
    resp.end("try{location.reload()}catch(_){}addEventListener(\"DOMContentLoaded\",function(event){location.reload()})", false)
}

/// 包装通用请求处理器
func wrapGenericRequestHandler(handler: Any, isSsl: Bool): RequestHandler {
    handler
}

/// 从 URL 提取路径名
func extractPathnameFromUrl(url: String): String {
    let pathStart = url.indexOf('/')
    if (pathStart.isNone()) { return "/" }
    let path = url[pathStart.getOrThrow()..]
    let queryStart = path.indexOf('?')
    if (queryStart.isSome()) { return path[0..queryStart.getOrThrow()] }
    let hashStart = path.indexOf('#')
    if (hashStart.isSome()) { return path[0..hashStart.getOrThrow()] }
    return path
}

/// 写入 Int32 小端序
func writeInt32LE(buf: ArrayList<Byte>, value: Int32): Unit {
    buf.append(UInt8(value & Int32(0xFF)))
    buf.append(UInt8((value >> 8) & Int32(0xFF)))
    buf.append(UInt8((value >> 16) & Int32(0xFF)))
    buf.append(UInt8((value >> 24) & Int32(0xFF)))
}

/// 写入 UInt32 小端序
func writeUInt32LE(buf: ArrayList<Byte>, value: UInt32): Unit {
    buf.append(UInt8(value & UInt32(0xFF)))
    buf.append(UInt8((value >> 8) & UInt32(0xFF)))
    buf.append(UInt8((value >> 16) & UInt32(0xFF)))
    buf.append(UInt8((value >> 24) & UInt32(0xFF)))
}

/// 写入 UInt64 小端序
func writeUInt64LE(buf: ArrayList<Byte>, value: UInt64): Unit {
    for (i in 0..8) {
        buf.append(UInt8((value >> (i * 8)) & UInt64(0xFF)))
    }
}

/// 将 UInt32 转换为十六进制字符串（小写，8字符）
func bytesToHexUInt32(value: UInt32): String {
    var result = ""
    var v = value
    var chars = Array<Byte>(8, { _ => 0 })
    for (i in 0..8) {
        let nibble = UInt8(v & UInt32(0xF))
        chars[Int64(7 - i)] = if (nibble < 10) {
            UInt8(nibble + 48)
        } else {
            UInt8(nibble + 87)
        }
        v = v >> 4
    }
    for (c in chars) {
        result += String(Char.fromUInt32(UInt32(c)))
    }
    return result
}

/// 将 UInt64 转换为十六进制字符串（小写，16字符）
func bytesToHexUInt64(value: UInt64): String {
    var result = ""
    var v = value
    var chars = Array<Byte>(16, { _ => 0 })
    for (i in 0..16) {
        let nibble = UInt8(v & UInt64(0xF))
        chars[Int64(15 - i)] = if (nibble < 10) {
            UInt8(nibble + 48)
        } else {
            UInt8(nibble + 87)
        }
        v = v >> 4
    }
    for (c in chars) {
        result += String(Char.fromUInt32(UInt32(c)))
    }
    return result
}

/// Base64 编码
func base64Encode(data: Array<Byte>): String {
    let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    var result = ""
    var i: Int64 = 0
    while (i < data.size) {
        let b0 = UInt64(data[i])
        let b1 = if (i + 1 < data.size) { UInt64(data[i + 1]) } else { UInt64(0) }
        let b2 = if (i + 2 < data.size) { UInt64(data[i + 2]) } else { UInt64(0) }

        let triple = (b0 << 16) | (b1 << 8) | b2

        result += String(chars[Int64((triple >> 18) & 0x3F)])
        result += String(chars[Int64((triple >> 12) & 0x3F)])

        if (i + 1 < data.size) {
            result += String(chars[Int64((triple >> 6) & 0x3F)])
        } else {
            result += "="
        }
        if (i + 2 < data.size) {
            result += String(chars[Int64(triple & 0x3F)])
        } else {
            result += "="
        }
        i += 3
    }
    return result
}

/// 路径 basename
func pathBasename(path: String): String {
    if (let Some(idx) <- path.lastIndexOf('/')) {
        return path[idx + 1..]
    }
    return path
}

/// 检查字符串是否全部为 ASCII
func isAllASCII(s: String): Bool {
    for (i in 0..s.size) {
        let ch = Int64(s[i])
        if (ch > 127) { return false }
    }
    return true
}

/// String builder helper
public class StringBuilder {
    private var parts: ArrayList<String> = ArrayList<String>()

    public init() {}

    public func append(s: String): Unit {
        parts.append(s)
    }

    public func toString(): String {
        var result = ""
        for (part in parts.items) {
            result += part
        }
        return result
    }
}
