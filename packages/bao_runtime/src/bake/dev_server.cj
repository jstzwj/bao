// 严格翻译自: src/runtime/bake/DevServer.zig
// 开发服务器实例。附加到 Bun.serve 实例，控制 bundler、路由和热模块重载。
//
// 重处理未更改的文件是被禁止的；通过对项目进行完美的增量跟踪，
// 编辑文件内容（除了调整导入）必须始终只重新 bundle 那一个文件。
//
// 所有工作都在内存中保存，使用手动管理的数据导向设计。
package bao_runtime.bake

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_jsc.*

// ============================================================================
// 子模块导入
// 对应 Bun: pub const RouteBundle = @import("./DevServer/RouteBundle.zig")
// ============================================================================

// Assets is in the same package
// DirectoryWatchStore is in the same package

// ============================================================================
// 类型别名
// ============================================================================

public type VirtualMachine = jsc.VirtualMachine
public type Transpiler = bun.transpiler.Transpiler
public type AnyServer = bun.jsc.API.AnyServer
public type FrameworkRouter = framework_router.FrameworkRouter
public type Log = bun.logger.Log
public type Watcher = bun.Watcher
public type ThreadLock = bun.safety.ThreadLock
public type Strong = jsc.Strong
public type BundleV2 = bun.bundle_v2.BundleV2
public type EventLoopTimer = bun.api.Timer.EventLoopTimer
public type Timer = std.time.Timer
public type ArrayListUnmanaged<T> = std.ArrayListUnmanaged<T>
public type AutoArrayHashMapUnmanaged<K, V> = std.AutoArrayHashMapUnmanaged<K, V>
public type AutoHashMapUnmanaged<K, V> = std.AutoHashMapUnmanaged<K, V>
public type ArrayHashMapUnmanaged<K, V> = std.ArrayHashMapUnmanaged<K, V>
public type StringArrayHashMap<V> = std.StringArrayHashMap<V>
public type StringHashMap<V> = std.StringHashMap<V>
public type HiveArray<T> = bun.HiveArray<T>
public type DebuggerId = bun.bake.DebuggerId
public type PathBuffer = bun.PathBuffer
public type JSPromiseStrong = jsc.JSPromise.Strong
public type IncrementalGraphServerFileIndex = IncrementalGraph(.server).FileIndex
public type FrameworkRouterRouteIndex = FrameworkRouter.Route.Index

// ============================================================================
// 分配器作用域
// 对应 Bun: const AllocationScope = bun.allocators.AllocationScopeIn(bun.DefaultAllocator)
// ============================================================================

/// 分配器作用域
public type AllocationScope = bun.allocators.AllocationScopeIn<bun.DefaultAllocator>
public type DevAllocator = AllocationScope.Borrowed

// ============================================================================
// 常量前缀
// 对应 Bun: pub const internal_prefix = "/_bun"
// ============================================================================

/// 内部前缀
public static let INTERNAL_PREFIX = "/_bun"

/// 资源前缀: /_bun/asset/<key>
/// 对应 Bun: pub const asset_prefix = internal_prefix ++ "/asset"
public static let ASSET_PREFIX = "/_bun/asset"

/// 客户端脚本前缀: /_bun/client/{name}-{rbi}{generation}.js
/// 对应 Bun: pub const client_prefix = internal_prefix ++ "/client"
public static let CLIENT_PREFIX = "/_bun/client"

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

/// 插件状态
public enum PluginState {
    | unknown    // 应向服务器请求插件
    | pending    // 已调用 getOrLoadPlugins
    | loaded     // 插件已加载
    | err        // 插件加载失败
}

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
    public var routeBundleIndices: AutoArrayHashMapUnmanaged<RouteBundle.Index, Unit> =
        AutoArrayHashMapUnmanaged<RouteBundle.Index, Unit>()

    /// 设置路由Bundle状态
    /// 对应 Bun: pub fn setRouteBundleState(self, dev, state) void
    public func setRouteBundleState(dev: DevServer, state: RouteBundle.State): Unit {
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
        routeBundleIndices = AutoArrayHashMapUnmanaged<RouteBundle.Index, Unit>()
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
    public var bv2: BundleV2
    /// BundleV2完成bundle所需的信息
    public var startData: DevServerInput
    /// Bundle排队时启动的计时器
    public var timer: Timer
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
    public var routeQueue: AutoArrayHashMapUnmanaged<RouteBundle.Index, Unit>
    /// 如果有重载事件应被排空
    public var reloadEvent: ?HotReloadEvent
    /// 被此bundle阻塞的请求列表
    public var requests: DeferredRequestList
    public var promise: DeferredPromise

    public init() {
        routeQueue = AutoArrayHashMapUnmanaged<RouteBundle.Index, Unit>()
        reloadEvent = None
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
    public var htmlRoutesSoftAffected: ArrayListUnmanaged<RouteBundle.Index> =
        ArrayListUnmanaged<RouteBundle.Index>()
    public var htmlRoutesHardAffected: ArrayListUnmanaged<RouteBundle.Index> =
        ArrayListUnmanaged<RouteBundle.Index>()

    public static let empty: IncrementalResult = IncrementalResult()
}

// ============================================================================
// RouteIndexAndRecurseFlag
// 对应 Bun: 路由索引和递归标志
// ============================================================================

/// 路由索引和递归标志
public struct RouteIndexAndRecurseFlag {
    public var routeIndex: FrameworkRouterRouteIndex
    public var shouldRecurseWhenVisiting: Bool
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
    public var dumpSources: ?String = None
    /// 调试功能: 崩溃时转储状态
    public var dumpStateOnCrash: ?Bool = None

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
        switch (this) {
            case .req(let r) => HTTPMethod.which(r.method()) ?? .POST
            case .saved(let s) => s.request.method
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
    public var dev: DevServer
    public var req: ReqOrSaved
    public var resp: AnyResponse
    public var kind: DeferredRequestHandlerKind
    public var routeBundleIndex: RouteBundle.Index

    /// 当请求被延迟时调用
    public func onDefer(bundleField: BundleQueueType): Unit {
        let requestsArray = switch (bundleField) {
            case .current_bundle => dev.currentBundle.get().requests
            case .next_bundle => dev.nextBundle.requests
        }
        dev.deferRequest(requestsArray, routeBundleIndex, kind, req, resp)
    }

    /// 当路由已加载时调用
    public func onLoaded(): Unit {
        switch (kind) {
            case .server_handler =>
                dev.onFrameworkRequestWithBundle(
                    routeBundleIndex,
                    switch (req) {
                        case .req(let r) => SavedRequestUnion.stack(r)
                        case .saved(let s) => SavedRequestUnion.saved(s)
                    },
                    resp
                )
            case .bundled_html_page =>
                dev.onHtmlRequestWithBundle(routeBundleIndex, resp, req.method())
        }
    }

    /// 当评估失败时调用
    public func onFailure(): Unit {
        dev.sendSerializedFailures(
            DevResponse.http(resp),
            Array<SerializedFailure>(
                dev.routeBundlePtr(routeBundleIndex).data.framework.evaluateFailure.get()
            ),
            FailureKind.evaluation,
            None
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
}

/// 消息ID
public enum MessageId {
}

/// 传入消息ID
public enum IncomingMessageId {
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
    public var server: ?AnyServer = None
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
    public var hasTailwindPluginHack: ?StringArrayHashMap<Unit> = None

    // ========================================================================
    // 服务器运行时回调
    // 对应 hmr-runtime-server.ts 中的函数
    // ========================================================================

    /// handleRequest函数回调
    public var serverFetchFunctionCallback: Strong.Optional
    /// registerUpdate函数回调
    public var serverRegisterUpdateCallback: Strong.Optional

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
    public var currentBundle: ?CurrentBundle = None
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
    public var dumpDir: ?Dir = None
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
        inspectorServerId = DebuggerId.init(0)
        configurationHashKey = Array<Byte>(16)
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
        serverFetchFunctionCallback = Strong.Optional.empty
        serverRegisterUpdateCallback = Strong.Optional.empty
        bunWatcher = Watcher()
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
        memoryVisualizerTimer = EventLoopTimer()
        broadcastConsoleLogFromBrowserToServer = false
    }

    /// 初始化DevServer
    /// 对应 Bun: pub fn init(options: Options) bun.JSOOM!*DevServer
    public static func init(options: Options): ?DevServer {
        let dev = DevServer()
        dev.allocationScope = AllocationScope.initDefault()
        dev.root = options.root
        dev.vm = options.vm
        dev.server = null
        dev.directoryWatchers = DirectoryWatchStore.empty
        dev.serverFetchFunctionCallback = Strong.Optional.empty
        dev.serverRegisterUpdateCallback = Strong.Optional.empty
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
        dev.currentBundle = None
        dev.nextBundle = NextBundle()
        dev.inspectorServerId = DebuggerId.init(0)
        dev.assets = Assets()
        dev.sourceMaps = SourceMapStore.empty
        dev.pluginState = PluginState.unknown
        dev.bundlingFailures = ArrayHashMapUnmanaged<SerializedFailure, Unit>()
        dev.assumePerfectIncrementalBundling = false
        dev.testingBatchEvents = TestingBatchEvents.disabled
        dev.broadcastConsoleLogFromBrowserToServer = options.broadcastConsoleLogFromBrowserToServer
        dev.hasPreCrashHandler = false

        let alloc = dev.allocator()
        dev.log = Log.init(alloc)

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
            let sockets = alloc.alloc<HmrSocket>(count)
            var i: Int64 = 0
            var it = activeWebsocketConnections.keyIterator()
            while (let item = it.next()) {
                sockets[i] = item.get()
                i += 1
            }
            for (s in sockets) {
                if (let websocket = s.underlying) {
                    websocket.close()
                }
            }
            alloc.free(sockets)
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
        for (key in barrelFilesWithDeferrals.keys()) {
            alloc.free(key)
        }
        barrelFilesWithDeferrals.deinit(alloc)

        // 释放桶导出
        var it2 = barrelNeededExports.iterator()
        while (let entry = it2.next()) {
            var inner = entry.value
            var innerIt = inner.keyIterator()
            while (let k = innerIt.next()) { alloc.free(k.get()) }
            inner.deinit(alloc)
            alloc.free(entry.key)
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
        if (let hack = hasTailwindPluginHack) {
            for (key in hack.keys()) { alloc.free(key) }
            hack.deinit(alloc)
        }

        // 目录监视器
        for (dirName in directoryWatchers.watches.keys()) { alloc.free(dirName) }
        for (watcher in directoryWatchers.dependencies.items) { alloc.free(watcher.specifier) }
        directoryWatchers.watches.deinit(alloc)
        directoryWatchers.dependencies.deinit(alloc)

        htmlRouter.map.deinit(alloc)

        // 捆绑失败
        for (failure in bundlingFailures.keys()) { failure.deinit(this) }
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
        switch (testingBatchEvents) {
            case .enabled(let batch) => batch.entryPoints.deinit(alloc)
            else => {}
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
        let runtime = BunString.static(bun.bake.getHmrRuntime(.server).code)

        let interface = BakeLoadInitialServerCode(
            vm.global,
            runtime,
            if (let sc = framework.serverComponents) { sc.separateSsrGraph } else { false }
        )

        if (!interface.isObject()) {
            panic("Internal assertion failure: expected interface from HMR runtime to be an object")
        }

        let fetchFunction = interface.get(vm.global, "handleRequest")
        if (fetchFunction == None) {
            panic("Internal assertion failure: expected interface from HMR runtime to contain handleRequest")
        }
        serverFetchFunctionCallback = Strong.create(fetchFunction.get(), vm.global)

        let registerUpdate = interface.get(vm.global, "registerUpdate")
        if (registerUpdate == None) {
            panic("Internal assertion failure: expected interface from HMR runtime to contain registerUpdate")
        }
        serverRegisterUpdateCallback = Strong.create(registerUpdate.get(), vm.global)
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
            FrameworkRouter.InsertionContext.wrap<DevServer>(this)
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
        let app = server.app.get()

        // 注册内部路由
        app.get("\(CLIENT_PREFIX)/:route", this, wrapGenericRequestHandler(onJsRequest))
        app.get("\(ASSET_PREFIX)/:asset", this, wrapGenericRequestHandler(onAssetRequest))
        app.get("\(INTERNAL_PREFIX)/src/*", this, wrapGenericRequestHandler(onSrcRequest))
        app.post("\(INTERNAL_PREFIX)/report_error", this, wrapGenericRequestHandler(ErrorReportRequest.run))
        app.post("\(INTERNAL_PREFIX)/unref", this, wrapGenericRequestHandler(onUnrefSourceMap))

        app.any(INTERNAL_PREFIX, this, wrapGenericRequestHandler(onNotFound))

        // HMR WebSocket
        app.ws("\(INTERNAL_PREFIX)/hmr", this, HmrSocket.behavior())

        // 调试路由
        app.get("\(INTERNAL_PREFIX)/incremental_visualizer", this,
                wrapGenericRequestHandler(onIncrementalVisualizer))
        app.get("\(INTERNAL_PREFIX)/memory_visualizer", this,
                wrapGenericRequestHandler(onMemoryVisualizer))

        // 仅当框架有文件系统路由类型时才附加catch-all处理器
        if (framework.fileSystemRouterTypes.size > 0) {
            app.any("/*", this, wrapGenericRequestHandler(onRequest))
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
        let isMap = routeId.hasSuffix(".js.map")
        if (!isMap && !routeId.hasSuffix(".js")) {
            return notFound(resp)
        }

        // 解析路由bundle索引和generation
        let minLen = "00000000FFFFFFFF.js".size + (if (isMap) ".map".size else 0)
        if (routeId.size < minLen) return notFound(resp)

        let hex = routeId[routeId.size - minLen..][0..16]
        let id = parseHexToInt<UInt64>(hex)
        if (id == None) return notFound(resp)

        if (isMap) {
            let sourceId: SourceMapStore.SourceId = id.get()
            if (let entry = sourceMaps.entries.getPtr(id.get())) {
                let jsonBytes = entry.renderJSON(this, allocator(), sourceId.kind, allocator(), .client)
                let response = StaticRoute.initFromAnyBlob(
                    Array<Blob>.fromOwnedSlice(allocator(), jsonBytes),
                    StaticRouteOptions(server: server, mimeType: MimeType.json)
                )
                response.onRequest(resp)
                response.deref()
                return
            }
            return notFound(resp)
        }

        let routeBundleIndex: RouteBundle.Index = RouteBundle.Index.init(id.get() & 0xFFFFFFFF)
        let generation: UInt32 = UInt32(id.get() >> 32)

        if (routeBundleIndex.get() >= routeBundles.items.size) return notFound(resp)

        let routeBundle = routeBundles.items[routeBundleIndex.get()]
        if (routeBundle.clientScriptGeneration != generation ||
            routeBundle.serverState != .loaded) {
            // Bundle已过期，发送重新加载脚本
            resp.corked(onOutdatedJSCorked)
            return
        }

        onJsRequestWithBundle(routeBundleIndex, resp, HTTPMethod.which(req.method()) ?? .POST)
    }

    /// 处理资源请求
    /// 对应 Bun: fn onAssetRequest(dev, req, resp) void
    func onAssetRequest(req: UwsRequest, resp: AnyResponse): Unit {
        let param = req.parameter(0)
        if (param.size < 16) return notFound(resp)

        let hex = param[0..16]
        let hashOpt = parseHexToInt<UInt64>(hex)
        if (hashOpt == None) return notFound(resp)

        let asset = assets.get(hashOpt.get())
        if (asset == None) return notFound(resp)

        req.setYield(false)
        asset.get().on(resp)
    }

    /// 处理框架请求
    /// 对应 Bun: fn onRequest(dev, req, resp) void
    func onRequest(req: UwsRequest, resp: AnyResponse): Unit {
        // 查找匹配的路由bundle
        let url = req.url()
        let pathname = extractPathnameFromUrl(url)

        // 尝试匹配框架路由
        var params: FrameworkRouter.MatchedParams
        if (let routeIndex = router.match(pathname, params)) {
            // 确保路由已bundle
            let routeBundleIndex = findRouteBundleIndex(routeIndex.get())
            if (let rbi = routeBundleIndex) {
                ensureRouteIsBundled(rbi.get(), req, resp)
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
    /// 对应 Bun: pub fn routeBundlePtr(index: RouteBundle.Index) RouteBundle
    public func routeBundlePtr(index: RouteBundle.Index): RouteBundle {
        routeBundles.items[index.get()]
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
        // bv2 = BundleV2.init(...)
    }

    /// 确保路由已Bundle
    /// 对应 Bun: fn ensureRouteIsBundled(dev, route_bundle_index, Ctx, ctx)
    public func ensureRouteIsBundled(routeBundleIndex: RouteBundle.Index,
                                      req: UwsRequest, resp: AnyResponse): Unit {
        let state = routeBundlePtr(routeBundleIndex).serverState

        switch (state) {
            case .unqueued => {
                // 如果正在捆绑其他内容，延迟请求
                if (currentBundle != None) {
                    nextBundle.routeQueue.put(allocator(), routeBundleIndex, Unit())
                    routeBundlePtr(routeBundleIndex).serverState = .deferred_to_next_bundle
                    return
                }

                // 检查插件状态
                switch (pluginState) {
                    case .unknown => {
                        if (server.getOrLoadPlugins(.dev_server(this)) == .pending) {
                            pluginState = .pending
                            nextBundle.routeQueue.put(allocator(), routeBundleIndex, Unit())
                            routeBundlePtr(routeBundleIndex).serverState = .deferred_to_next_bundle
                            return
                        }
                        pluginState = .loaded
                    }
                    case .pending => {
                        nextBundle.routeQueue.put(allocator(), routeBundleIndex, Unit())
                        routeBundlePtr(routeBundleIndex).serverState = .deferred_to_next_bundle
                        return
                    }
                    case .err => {
                        resp.end("Plugin Error", false)
                        return
                    }
                    case .loaded => {}
                }

                // 准备bundle
                nextBundle.routeQueue.put(allocator(), routeBundleIndex, Unit())
                routeBundlePtr(routeBundleIndex).serverState = .bundling

                startAsyncBundle(
                    EntryPointList.empty,
                    false,
                    Timer.start()
                )
            }
            case .deferred_to_next_bundle => {
                // 已在队列中
            }
            case .bundling => {
                // 等待当前bundle完成
            }
            case .possible_bundling_failures => {
                // 检查失败是否影响此路由
                if (bundlingFailures.count() > 0) {
                    // 可能需要重新构建
                }
                routeBundlePtr(routeBundleIndex).serverState = .loaded
            }
            case .evaluation_failure => {
                sendSerializedFailures(
                    DevResponse.http(resp),
                    Array<SerializedFailure>(),
                    FailureKind.evaluation,
                    None
                )
            }
            case .loaded => {
                onFrameworkRequestWithBundle(
                    routeBundleIndex,
                    SavedRequestUnion.stack(req),
                    resp
                )
            }
        }
    }

    /// 带有Bundle的框架请求处理
    /// 对应 Bun: fn onFrameworkRequestWithBundle(dev, route_bundle_index, req, resp)
    public func onFrameworkRequestWithBundle(routeBundleIndex: RouteBundle.Index,
                                              req: SavedRequestUnion, resp: AnyResponse): Unit {
        let routeBundle = routeBundlePtr(routeBundleIndex)
        let serverRequestCallback = serverFetchFunctionCallback.get()
        if (serverRequestCallback == None) return

        // 提取URL参数
        let url = req.url()
        let pathname = extractPathnameFromUrl(url)
        var params = FrameworkRouter.MatchedParams()
        let paramsJsValue = if (let match = router.matchSlow(pathname, params)) {
            params.toJS(vm.global)
        } else { JSValue.null }

        // 调用服务器端fetch处理器
        let responseValue = serverRequestCallback.get().call(
            vm.global, JSValue.jsUndefined,
            Array<JSValue>(
                getRouterTypeMain(routeBundleIndex),
                getRouteModules(routeBundleIndex),
                getClientId(routeBundleIndex),
                getStyles(routeBundleIndex),
                paramsJsValue,
                JSValue.null, JSValue.null, JSValue.null
            )
        )

        // 处理响应
        server.get().onSavedRequest(req, resp, serverRequestCallback, 8, Array<JSValue>())
    }

    /// 带有Bundle的HTML请求处理
    public func onHtmlRequestWithBundle(routeBundleIndex: RouteBundle.Index,
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
    private func getRouterTypeMain(routeBundleIndex: RouteBundle.Index): JSValue {
        // 简化: 返回服务器文件字符串
        JSValue.null
    }

    /// 获取路由模块列表
    private func getRouteModules(routeBundleIndex: RouteBundle.Index): JSValue {
        JSValue.createEmptyArray(vm.global, 0)
    }

    /// 获取客户端ID
    private func getClientId(routeBundleIndex: RouteBundle.Index): JSValue {
        let bundleIndex: UInt32 = routeBundleIndex.get()
        let generation: UInt32 = routeBundlePtr(routeBundleIndex).clientScriptGeneration
        let str = BunString.createFormat(
            "\(CLIENT_PREFIX)/route-\(bundleIndex)\(generation).js"
        )
        str.toJS(vm.global)
    }

    /// 获取样式
    private func getStyles(routeBundleIndex: RouteBundle.Index): JSValue {
        JSValue.createEmptyArray(vm.global, 0)
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
        if (let srv = server) {
            let app = srv.app.get()
            app.publish(topic.toString(), data, opcode)
        }
    }

    /// 检查路由失败
    /// 对应 Bun: fn checkRouteFailures(dev, route_bundle_index, resp)
    public func checkRouteFailures(routeBundleIndex: RouteBundle.Index,
                                     resp: DevResponse): CheckRouteFailuresResult {
        // 跟踪图以查找此路由可到达的失败
        let gts = initGraphTraceState(allocator(), 0)
        graphSafetyLock.lock()
        defer(graphSafetyLock.unlock())

        traceAllRouteImports(routeBundlePtr(routeBundleIndex), gts, .findErrors)

        if (incrementalResult.failuresAdded.items.size > 0) {
            if (!assumePerfectIncrementalBundling) {
                // 缓存清除所有可到达的内容
                return CheckRouteFailuresResult.rebuild
            }
            sendSerializedFailures(resp, incrementalResult.failuresAdded.items.toArray(), FailureKind.bundler, None)
            return CheckRouteFailuresResult.stop
        }
        return CheckRouteFailuresResult.ok
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 解析十六进制字符串为整数
    /// 对应 Bun: pub fn parseHexToInt(comptime T: type, slice: []const u8) ?T
    public static func parseHexToInt<T>(slice: String): ?T {
        if (slice.size < 2) return None
        var result: T = Zeroes.zeroes<T>()
        for (i in 0..slice.size) {
            let c = slice[Int64(i)]
            let digit: T = if (c >= '0' && c <= '9') {
                T(c - '0')
            } else if (c >= 'a' && c <= 'f') {
                T(c - 'a' + 10)
            } else if (c >= 'A' && c <= 'F') {
                T(c - 'A' + 10)
            } else {
                return None
            }
            result = result * 16 + digit
        }
        return result
    }

    /// 慢速查找路由到Bundle索引
    /// 对应 Bun: pub fn routeToBundleIndexSlow(pattern: String) ?RouteBundle.Index
    public func routeToBundleIndexSlow(pattern: String): ?RouteBundle.Index {
        // 遍历路由查找匹配的Bundle索引
        for (i in 0..routeBundles.items.size) {
            // 检查路由模式是否匹配
        }
        return None
    }

    /// 获取相对路径
    /// 对应 Bun: pub fn relativePath(buf: PathBuffer, abs_path: String) String
    public func relativePath(buf: PathBuffer, absPath: String): String {
        bun.path.relative(root, absPath)
    }

    /// 延迟请求
    /// 对应 Bun: fn deferRequest(dev, requests_array, route_bundle_index, kind, req, resp)
    public func deferRequest(requestsArray: DeferredRequestList, routeBundleIndex: RouteBundle.Index,
                              kind: DeferredRequestHandlerKind, req: ReqOrSaved, resp: AnyResponse): Unit {
        let deferred = deferredRequestPool.get()
        deferred.data = DeferredRequest(
            routeBundleIndex: routeBundleIndex,
            dev: this,
            handler: switch (kind) {
                case .bundled_html_page => DeferredRequestHandler.bundledHtmlPage(
                    response: resp,
                    method: req.method()
                )
                case .server_handler => DeferredRequestHandler.serverHandler(
                    // 保存请求上下文
                )
            }
        )
        requestsArray.prepend(deferred)
    }

    /// 查找路由Bundle索引
    private func findRouteBundleIndex(routeIndex: FrameworkRouterRouteIndex): ?RouteBundle.Index {
        for (i in 0..routeBundles.items.size) {
            // 检查路由索引匹配
        }
        return None
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
        bundlerOptions.plugin = plugin
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
static func notFoundCorked(resp: AnyResponse): Unit {
    resp.writeStatus("404 Not Found")
    resp.end("Not Found", false)
}

/// 过期JS corked回调
static func onOutdatedJSCorked(resp: AnyResponse): Unit {
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
    if (pathStart == None) return "/"
    let path = url[pathStart.get()..]
    let queryStart = path.indexOf('?')
    if (queryStart != None) return path[0..queryStart.get()]
    let hashStart = path.indexOf('#')
    if (hashStart != None) return path[0..hashStart.get()]
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
        switch (this) {
            case .http(let resp) => resp.writeStatus(status)
            case .none => {}
        }
    }

    public func end(body: String, close: Bool): Unit {
        switch (this) {
            case .http(let resp) => resp.end(body, close)
            case .none => {}
        }
    }
}

/// 图跟踪状态
class GraphTraceState {
    public init() {}
    public func deinit(alloc: Allocator): Unit {}
}

/// 延迟请求列表
public typealias DeferredRequestList = ArrayList<DeferredRequest>

/// 延迟请求
public class DeferredRequest {
    public var routeBundleIndex: RouteBundle.Index
    public var dev: DevServer
    public var handler: DeferredRequestHandler

    public init() {}

    /// 中止回调
    public static func onAbort(deferred: DeferredRequest): Unit {
        // 清理延迟请求
    }
}

/// 延迟请求处理器
public enum DeferredRequestHandler {
    | bundledHtmlPage(response: AnyResponse, method: HTTPMethod)
    | serverHandler(context: AnyRequestContext)
}

/// 延迟请求节点
public class DeferredRequestNode {
    public var data: DeferredRequest
    public var prev: ?DeferredRequestNode
    public var next: ?DeferredRequestNode

    public init() {
        data = DeferredRequest()
        prev = None
        next = None
    }
}

/// HTML路由表
public class HTMLRouter {
    public var map: AutoArrayHashMapUnmanaged<String, HTMLBundleRoute>
    public var fallback: ?HTMLBundleRoute

    public static let empty: HTMLRouter = HTMLRouter()

    public init() {
        map = AutoArrayHashMapUnmanaged<String, HTMLBundleRoute>()
        fallback = None
    }

    public func put(alloc: Allocator, path: String, route: HTMLBundleRoute): Unit {
        map.put(alloc, path, route)
    }

    public func clear(): Unit {
        map.clearRetainingCapacity()
        fallback = None
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
            set.add(path)
            items.append(EntryPoint(path: path, opts: opts))
        }
    }

    public func appendCss(alloc: Allocator, path: String): Unit {
        append(alloc, path, EntryPointOptions(client: true))
    }
}

/// 入口点
public class EntryPoint {
    public var path: String
    public var opts: EntryPointOptions

    public init(path: String, opts: EntryPointOptions) {
        this.path = path
        this.opts = opts
    }
}

/// 入口点选项
public class EntryPointOptions {
    public var client: Bool

    public init(client: Bool) {
        this.client = client
    }
}

/// 序列化失败所有者打包
public typealias SerializedFailureOwnerPacked = UInt64

/// 测试批处理
public class TestingBatch {
    public var entryPoints: ArrayList<String>

    public init() {
        entryPoints = ArrayList<String>()
    }
}
