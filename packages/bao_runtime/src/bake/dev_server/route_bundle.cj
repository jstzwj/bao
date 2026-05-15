// 翻译自 Bun: src/runtime/bake/DevServer/RouteBundle.zig
// 路由 Bundle - 每个可导航路由的捆绑状态。

package bao_runtime

/// 路由 Bundle - 每个可导航路由的捆绑状态
public class RouteBundle {
    public struct Index <: UInt30 {}

    public var server_state: State
    /// 有两种不同类型的路由 bundle
    public var data: RouteBundleData
    /// 当客户端 JS 被请求时懒生成。
    /// 当下游客户端模块更新时失效。
    public var client_bundle: ?StaticRoute = None

    /// 如果客户端尝试加载错误 generation 的脚本，
    /// 它将收到一个立即重新加载页面的 bundle
    public var client_script_generation: UInt32

    /// 有多少 HmrSocket 说它们在此路由上的引用计数
    public var active_viewers: UInt32

    /// 框架路由数据
    public class Framework {
        public var route_index: Route.Index
        /// 缓存以避免每次请求重新创建数组
        public var cached_module_list: Strong.Optional
        /// 缓存的客户端 bundle URL
        public var cached_client_bundle_url: Strong.Optional
        /// 缓存的 CSS 文件数组
        public var cached_css_file_array: Strong.Optional
        /// 当 state == .evaluation_failure 时填充
        public var evaluate_failure: ?SerializedFailure = None
    }

    /// HTML 路由数据
    public class HTML {
        public var html_bundle: RefPtr<HTMLBundleRoute>
        public var bundled_file: IncrementalGraphClientFileIndex
        /// 当 HTML 文件被修改（非其导入）时失效
        public var script_injection_offset: ByteOffset.Optional
        /// bundler 输出的 HTML 文本
        public var bundled_html_text: ?String = None
        /// 从 bundled_html_text + client_script_generation 派生
        public var cached_response: ?StaticRoute = None

        public struct ByteOffset <: UInt32 {}
    }

    /// 路由 Bundle 状态
    public enum State {
        | unqueued                    // 从未构建
        | bundling                    // 正在捆绑
        | deferred_to_next_bundle     // 将在下一个 bundle 中发生
        | possible_bundling_failures  // 标记有捆绑失败
        | evaluation_failure          // 运行时加载失败
        | loaded                      // 已加载
    }

    /// 未解析的索引
    public enum UnresolvedIndex {
        | framework(Route.Index)      // FrameworkRouter 提供的路由
        | html(HTMLBundleRoute)       // HTMLBundle 提供的路由
    }

    /// 析构
    public func deinit(allocator: Allocator): Unit {
        if (let Some(blob) = client_bundle) {
            blob.deref()
        }
        match (data) {
            case framework(let fw) =>
                fw.cached_client_bundle_url.deinit()
                fw.cached_css_file_array.deinit()
                fw.cached_module_list.deinit()
            case html(let html) =>
                if (let Some(text) = html.bundled_html_text) {
                    allocator.free(text)
                }
                if (let Some(cached_response) = html.cached_response) {
                    cached_response.deref()
                }
                html.html_bundle.deref()
        }
    }

    /// 获取 source map ID
    public func sourceMapId(): SourceMapStore.Key {
        return SourceMapStore.Key.init(UInt64(client_script_generation) << 32)
    }

    /// 使客户端 bundle 失效
    public func invalidateClientBundle(dev: DevServer): Unit {
        if (let Some(bundle) = client_bundle) {
            dev.source_maps.unref(sourceMapId())
            bundle.deref()
            client_bundle = None
        }
        client_script_generation = random<UInt32>()
        match (data) {
            case framework(let fw) => fw.cached_client_bundle_url.clearWithoutDeallocation()
            case html(let html) =>
                if (let Some(cached_response) = html.cached_response) {
                    cached_response.deref()
                    html.cached_response = None
                }
        }
    }

    /// 内存成本
    public func memoryCost(): UInt64 {
        var cost: UInt64 = sizeOf<RouteBundle>()
        if (let Some(bundle) = client_bundle) {
            cost += bundle.memoryCost()
        }
        match (data) {
            case html(let html) =>
                if (let Some(text) = html.bundled_html_text) {
                    cost += text.length
                }
                if (let Some(cached_response) = html.cached_response) {
                    cost += cached_response.memoryCost()
                }
            case framework(_) => ()
        }
        return cost
    }
}

/// 路由 Bundle 数据联合类型
public enum RouteBundleData {
    | framework(RouteBundle.Framework)   // FrameworkRouter 路由
    | html(RouteBundle.HTML)             // HTMLBundle 路由
}

// 类型别名
public type Allocator = std.mem.Allocator
public type StaticRoute = bun.api.server.StaticRoute
public type Strong = jsc.Strong
public type RefPtr<T> = bun.ptr.RefPtr<T>
public type HTMLBundleRoute = jsc.API.HTMLBundle.HTMLBundleRoute
public type Route = framework_router.FrameworkRouter.Route
public type IncrementalGraphClientFileIndex = IncrementalGraph(.client).FileIndex
public type SourceMapStore = dev_server.SourceMapStore
public type SerializedFailure = dev_server.SerializedFailure
