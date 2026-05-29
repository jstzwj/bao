// 翻译自 Bun: src/runtime/bake/DevServer/RouteBundle.zig
// 路由 Bundle - 每个可导航路由的捆绑状态。

package bao_runtime.bake.dev_server

import bao_bun_alloc.Allocator

/// 路由 Bundle Index
public struct RouteBundleIndex {
    public var value: UInt32
    public init(value: UInt32) { this.value = value }
    public func get(): UInt32 { value }
    public static let Optional: IndexOptional = IndexOptional.none
}

/// Framework 路由数据
public class Framework {
    public var route_index: UInt32
    /// 缓存以避免每次请求重新创建数组
    public var cached_module_list: StrongOptional
    /// 缓存的客户端 bundle URL
    public var cached_client_bundle_url: StrongOptional
    /// 缓存的 CSS 文件数组
    public var cached_css_file_array: StrongOptional
    /// 当 state == evaluation_failure 时填充
    public var evaluate_failure: ?SerializedFailure

    public init() {
        route_index = 0
        cached_module_list = StrongOptional.empty
        cached_client_bundle_url = StrongOptional.empty
        cached_css_file_array = StrongOptional.empty
        evaluate_failure = None
    }
}

/// HTML 路由数据
public class HTML {
    public var html_bundle: IntPtr
    public var bundled_file: FileIndex
    /// 当 HTML 文件被修改时失效
    public var script_injection_offset: ByteOffset
    /// bundler 输出的 HTML 文本
    public var bundled_html_text: ?String
    /// 从 bundled_html_text 派生
    public var cached_response: ?StaticRoute

    public init() {
        html_bundle = IntPtr()
        bundled_file = FileIndex(0)
        script_injection_offset = ByteOffset(0)
        bundled_html_text = None
        cached_response = None
    }
}

/// 字节偏移量
public struct ByteOffset {
    public var value: UInt32
    public init(value: UInt32) { this.value = value }
}

/// 路由 Bundle 状态
public enum State {
    | unqueued
    | bundling
    | deferred_to_next_bundle
    | possible_bundling_failures
    | evaluation_failure
    | loaded
}

/// 未解析的索引
public enum UnresolvedIndex {
    | framework(UInt32)
    | html(IntPtr)
}

/// 路由 Bundle
public class RouteBundle {
    public var server_state: State
    /// 有两种不同类型的路由 bundle
    public var data: RouteBundleData
    /// 当客户端 JS 被请求时懒生成。
    public var client_bundle: ?StaticRoute
    /// 客户端脚本生成版本
    public var client_script_generation: UInt32
    /// 活跃查看者数量
    public var active_viewers: UInt32

    public init() {
        server_state = State.unqueued
        data = RouteBundleData.framework(Framework())
        client_bundle = None
        client_script_generation = 0
        active_viewers = 0
    }

    /// 析构
    public func deinit(allocator: Allocator): Unit {
        if (let Some(blob) <- client_bundle) {
            // blob.deref()
        }
        match (data) {
            case RouteBundleData.framework(fw) =>
                fw.cached_client_bundle_url.deinit()
                fw.cached_css_file_array.deinit()
                fw.cached_module_list.deinit()
            case RouteBundleData.html(_) =>
                ()
        }
    }

    /// 获取 source map ID
    public func sourceMapId(): UInt64 {
        return UInt64(client_script_generation) << 32
    }

    /// 使客户端 bundle 失效
    public func invalidateClientBundle(dev: DevServer): Unit {
        if (let Some(bundle) <- client_bundle) {
            // dev.source_maps.unref(sourceMapId())
            // bundle.deref()
            client_bundle = None
        }
        client_script_generation = 0 /* [KEPT: simplified] */
        match (data) {
            case RouteBundleData.framework(fw) => fw.cached_client_bundle_url.clearWithoutDeallocation()
            case RouteBundleData.html(h) =>
                if (let Some(cached) <- h.cached_response) {
                    h.cached_response = None
                }
        }
    }

    /// 内存成本
    public func memoryCost(): UInt64 {
        var cost: UInt64 = sizeOf<RouteBundle>()
        if (let Some(bundle) <- client_bundle) {
            cost += bundle.memoryCost()
        }
        return cost
    }
}

/// 路由 Bundle 数据联合类型
public enum RouteBundleData {
    | framework(Framework)
    | html(HTML)
}
