// 翻译自 Bun: src/runtime/bake/DevServer.zig
// 开发服务器实例。附加到 Bun.serve 实例，控制 bundler、路由和热模块重载。
//
// 重处理未更改的文件是被禁止的；通过对项目进行完美的增量跟踪，
// 编辑文件内容（除了调整导入）必须始终只重新 bundle 那一个文件。
//
// 所有工作都在内存中保存，使用手动管理的数据导向设计。

package bao_runtime

/// 开发服务器实例
public class DevServer {
    // 验证 DevServer 未被收集
    public var magic: Magic = Magic.valid
    /// 发布版本中无开销
    public var allocation_scope: AllocationScope
    /// 项目根目录的绝对路径。用于 HMR 运行时，其模块 ID 是相对于此的字符串。
    public var root: String
    /// DevServer 实例的唯一标识符
    public var inspector_server_id: DebuggerId
    /// 框架配置和 bun 修订版本哈希生成的十六进制字符串
    public var configuration_hash_key: Array<Byte>  // 16 bytes
    /// 虚拟机（全局对象）用于执行代码
    public var vm: VirtualMachine
    /// HTTP 服务器引用，可能为 null
    public var server: ?AnyServer = None
    /// 路由树
    public var router: FrameworkRouter
    /// 每个可导航路由都有捆绑状态
    public var route_bundles: ArrayListUnmanaged<RouteBundle>
    /// 访问 IncrementalGraph 由 ThreadLock 保护
    public var graph_safety_lock: ThreadLock
    public var client_graph: IncrementalGraph
    public var server_graph: IncrementalGraph
    /// 带有延迟（未使用）导入记录的桶文件
    public var barrel_files_with_deferrals: StringArrayHashMap<Unit> = StringArrayHashMap<Unit>()
    /// 跨所有构建累积的桶导出请求
    public var barrel_needed_exports: StringArrayHashMap<StringHashMap<Unit>> = StringArrayHashMap<StringHashMap<Unit>>()
    /// 在捆绑和热更新期间填充的状态
    public var incremental_result: IncrementalResult
    /// 框架路由的索引快速查找表
    public var route_lookup: AutoArrayHashMapUnmanaged<IncrementalGraphServerFileIndex, RouteIndexAndRecurseFlag>
    /// HTML 路由表
    public var html_router: HTMLRouter
    /// 资产存储，通过 /_bun/asset/<key> 访问
    public var assets: Assets
    /// SourceMap 存储
    public var source_maps: SourceMapStore
    /// 所有捆绑失败
    public var bundling_failures: ArrayHashMapUnmanaged<SerializedFailure, Unit> = ArrayHashMapUnmanaged<SerializedFailure, Unit>()
    /// 当设置时，从不为服务器端捆绑任何内容
    public var frontend_only: Bool
    /// Tailwind 插件 hack
    public var has_tailwind_plugin_hack: ?StringArrayHashMap<Unit> = None

    // 服务器运行时回调
    public var server_fetch_function_callback: Strong.Optional
    public var server_register_update_callback: Strong.Optional

    // 文件监控
    public var bun_watcher: Watcher
    public var directory_watchers: DirectoryWatchStore
    public var watcher_atomics: WatcherAtomics

    // 测试批处理事件
    public var testing_batch_events: TestingBatchEvents

    public var generation: UInt64 = 0
    public var bundles_since_last_error: UInt64 = 0

    public var framework: Framework
    public var bundler_options: SplitBundlerOptions
    public var server_transpiler: Transpiler
    public var client_transpiler: Transpiler
    public var ssr_transpiler: Transpiler
    public var log: Log
    public var plugin_state: PluginState = PluginState.unknown

    // 当前 bundle
    public var current_bundle: ?CurrentBundle = None
    // 下一个 bundle
    public var next_bundle: NextBundle

    public var deferred_request_pool: HiveArray<DeferredRequestNode>
    public var active_websocket_connections: AutoHashMapUnmanaged<HmrSocket, Unit>

    // 调试字段
    public var dump_dir: ?Dir = None
    public var emit_incremental_visualizer_events: UInt32 = 0
    public var emit_memory_visualizer_events: UInt32 = 0
    public var memory_visualizer_timer: EventLoopTimer
    public var has_pre_crash_handler: Bool = false
    public var assume_perfect_incremental_bundling: Bool = false
    public var broadcast_console_log_from_browser_to_server: Bool

    // 常量前缀
    public static let internal_prefix: String = "/_bun"
    public static let asset_prefix: String = "/_bun/asset"
    public static let client_prefix: String = "/_bun/client"

    /// Magic 枚举用于验证 DevServer 有效性
    public enum Magic {
        | valid
    }

    /// 插件状态
    public enum PluginState {
        | unknown    // 应向服务器请求插件
        | pending    // 已调用 getOrLoadPlugins
        | loaded     // 插件已加载
        | err        // 插件加载失败
    }

    /// 测试批处理事件状态
    public enum TestingBatchEvents {
        | disabled
        | enable_after_bundle
        | enabled(TestingBatch)
    }

    /// 当前 bundle 状态
    public class CurrentBundle {
        public var bv2: BundleV2
        public var start_data: DevServerInput
        public var timer: Timer
        public var had_reload_event: Bool
        public var requests: DeferredRequestList
        public var resolution_failure_entries: AutoArrayHashMapUnmanaged<SerializedFailureOwnerPacked, Log>
        public var promise: DeferredPromise
    }

    /// 下一个 bundle 状态
    public class NextBundle {
        public var route_queue: AutoArrayHashMapUnmanaged<RouteBundle.Index, Unit>
        public var reload_event: ?HotReloadEvent = None
        public var requests: DeferredRequestList
        public var promise: DeferredPromise
    }

    /// DevServer 选项
    public class Options {
        public var arena: Allocator
        public var root: String
        public var vm: VirtualMachine
        public var framework: Framework
        public var bundler_options: SplitBundlerOptions
        public var broadcast_console_log_from_browser_to_server: Bool
        public var dump_sources: ?String = None
        public var dump_state_on_crash: ?Bool = None
    }

    /// 延迟承诺
    public class DeferredPromise {
        public var strong: JSPromiseStrong = JSPromiseStrong.empty
        public var route_bundle_indices: AutoArrayHashMapUnmanaged<RouteBundle.Index, Unit> = AutoArrayHashMapUnmanaged<RouteBundle.Index, Unit>()

        public func setRouteBundleState(dev: DevServer, state: RouteBundle.State): Unit {
            for (route_bundle_index in route_bundle_indices.keys()) {
                dev.routeBundlePtr(route_bundle_index).server_state = state
            }
        }

        public func reset(): Unit {
            strong.deinit()
            route_bundle_indices.clearRetainingCapacity()
        }

        public func deinitIdempotently(): Unit {
            strong.deinit()
            route_bundle_indices.deinit(bun.default_allocator)
            route_bundle_indices = AutoArrayHashMapUnmanaged<RouteBundle.Index, Unit>()
        }
    }

    /// 初始化 DevServer
    public static func init(options: Options): ?DevServer {
        // 完整实现需要初始化所有字段
        let dev = DevServer()
        dev.root = options.root
        dev.vm = options.vm
        dev.framework = options.framework
        dev.bundler_options = options.bundler_options
        dev.broadcast_console_log_from_browser_to_server = options.broadcast_console_log_from_browser_to_server
        return dev
    }

    /// 析构
    public func deinit(): Unit {
        // 按顺序释放所有资源
        // WebSocket 连接首先关闭
        // 然后释放图、路由、bundle 等
        client_graph.deinit()
        server_graph.deinit()
        router.deinit(allocator())
        source_maps.entries.deinit(allocator())
        bun_watcher.deinit(true)
        log.deinit()
    }

    public func allocator(): Allocator {
        return allocation_scope.allocator()
    }

    /// 解析十六进制字符串为整数
    public static func parseHexToInt<T>(slice: String): ?T {
        // 将十六进制字符串解析为整数类型 T
        var out: Array<Byte> = Array<Byte>(sizeOf<T>())
        if (std.fmt.hexToBytes(out, slice) == null) {
            return None
        }
        return bitCast<T>(out)
    }

    /// 获取路由 bundle 指针
    public func routeBundlePtr(index: RouteBundle.Index): RouteBundle {
        return route_bundles.items[index.get()]
    }

    /// 慢速查找路由到 bundle 索引
    public func routeToBundleIndexSlow(pattern: String): ?RouteBundle.Index {
        // 遍历路由查找匹配的 bundle 索引
        return None
    }

    /// 启动异步 bundle
    public func startAsyncBundle(entry_points: EntryPointList, had_reload_event: Bool, timer: Timer): Unit {
        // 创建新的 bundle 并启动
    }

    /// 初始化服务器运行时
    func initServerRuntime(): Unit {
        let runtime = bun.String.static(bake.getHmrRuntime(.server).code)
        // 加载服务器端 HMR 运行时代码
    }

    /// 延迟一跳扫描初始路由
    func scanInitialRoutes(): Unit {
        router.scanAll(allocator(), server_transpiler.resolver, FrameworkRouter.InsertionContext.wrap<DevServer>(this))
        server_graph.ensureStaleBitCapacity(true)
        client_graph.ensureStaleBitCapacity(true)
    }

    /// 设置路由到 HTTP 服务器
    public func setRoutes(server: Any): Bool {
        // 注册路由处理器
        return false
    }

    /// 发布消息到 WebSocket 频道
    public func publish(topic: HmrTopic, data: Array<Byte>, opcode: Opcode): Unit {
        // 发布到所有订阅的 WebSocket
    }

    /// 获取相对路径
    public func relativePath(buf: PathBuffer, abs_path: String): String {
        return bun.path.relative(root, abs_path)
    }
}

/// 增量结果 - 在捆绑和热更新期间填充
public class IncrementalResult {
    public var had_adjusted_edges: Bool = false
    public var client_components_added: ArrayListUnmanaged<IncrementalGraphServerFileIndex> = ArrayListUnmanaged<IncrementalGraphServerFileIndex>()
    public var framework_routes_affected: ArrayListUnmanaged<RouteIndexAndRecurseFlag> = ArrayListUnmanaged<RouteIndexAndRecurseFlag>()
    public var client_components_removed: ArrayListUnmanaged<IncrementalGraphServerFileIndex> = ArrayListUnmanaged<IncrementalGraphServerFileIndex>()
    public var failures_removed: ArrayListUnmanaged<SerializedFailure> = ArrayListUnmanaged<SerializedFailure>()
    public var client_components_affected: ArrayListUnmanaged<IncrementalGraphServerFileIndex> = ArrayListUnmanaged<IncrementalGraphServerFileIndex>()
    public var failures_added: ArrayListUnmanaged<SerializedFailure> = ArrayListUnmanaged<SerializedFailure>()
    public var html_routes_soft_affected: ArrayListUnmanaged<RouteBundle.Index> = ArrayListUnmanaged<RouteBundle.Index>()
    public var html_routes_hard_affected: ArrayListUnmanaged<RouteBundle.Index> = ArrayListUnmanaged<RouteBundle.Index>()

    public static let empty: IncrementalResult = IncrementalResult()
}

/// 路由索引和递归标志
public struct RouteIndexAndRecurseFlag {
    public var route_index: FrameworkRouterRouteIndex
    public var should_recurse_when_visiting: Bool
}

/// HMR 主题
public enum HmrTopic <: UInt8 {
    | hot_update
    | testing_watch_synchronization
    | incremental_visualizer
    | memory_visualizer
    | console_log_topic
}

/// 消息 ID
public enum MessageId <: UInt8 {
    | version
    | set_url_response
    | testing_watch_synchronization
}

/// 传入消息 ID
public enum IncomingMessageId <: UInt8 {
    | init
    | subscribe
    | set_url
    | testing_batch_events
    | console_log
    | unref_source_map
}

/// 控制台日志种类
public enum ConsoleLogKind {
    | log
    | err
}

/// Chunk 种类
public enum ChunkKind {
    | initial_response
    | hmr_chunk
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
    | find_client_modules
    | find_errors
    | find_css
}

/// 分配器范围
public type AllocationScope = bun.allocators.AllocationScopeIn<bun.DefaultAllocator>
public type DevAllocator = AllocationScope.Borrowed

/// 导入子模块
public import assets.Assets
public import directory_watch_store.DirectoryWatchStore
public import error_report_request.ErrorReportRequest
public import hmr_socket.HmrSocket
public import hot_reload_event.HotReloadEvent
public import incremental_graph.IncrementalGraph
public import packed_map.PackedMap
public import route_bundle.RouteBundle
public import serialized_failure.SerializedFailure
public import source_map_store.SourceMapStore
public import watcher_atomics.WatcherAtomics
public import memory_cost.MemoryCost

// 类型别名
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
