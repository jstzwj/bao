// HTMLBundle - HTML 打包导入
// 严格翻译自: Bun src/runtime/server/HTMLBundle.zig
// 对应: 通过 import 导入 HTML 文件作为路由
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// HTMLBundle - HTML 打包描述
// 严格翻译自: src/runtime/server/HTMLBundle.zig
// Bun: pub const HTMLBundle = @This()
// 描述一个 HTML 包，可以通过 import 从 HTML 文件创建
// 构建延迟执行 (state held in HTMLBundle.Route or DevServer.RouteBundle.HTML)
// ============================================================================

/// HTMLBundle - HTML 打包
/// 对应 Bun: pub const HTMLBundle = @This()
/// 可被 JavaScript 持有，也可被任意数量的 Server 实例持有
public class HTMLBundle {
    // ========================================================================
    // 字段
    // ========================================================================

    /// 引用计数 - 对应 Bun: ref_count: RefCount
    public var refCount: Int64

    /// 全局对象 - 对应 Bun: global: *JSGlobalObject
    public var global: ?JsGlobalObject

    /// 文件路径 - 对应 Bun: path: []const u8
    public var path: String

    public init() {
        refCount = 1
        global = None
        path = ""
    }

    public init(path: String) {
        refCount = 1
        global = None
        this.path = path
    }

    // ========================================================================
    // 方法
    // ========================================================================

    /// 初始化
    /// 对应 Bun: pub fn init(global, path) !*HTMLBundle
    public static func init(path: String): HTMLBundle {
        return HTMLBundle(path)
    }

    /// 析构
    /// 对应 Bun: fn deinit(this) void
    public func deinit(): Unit {
        path = ""
    }

    /// 终结 (GC 回调)
    /// 对应 Bun: pub fn finalize(this) void
    public func finalize(): Unit {
        deref()
    }

    /// 获取路径索引
    /// 对应 Bun: pub fn getIndex(this, globalObject) bun.JSError!JSValue
    public func getIndex(): String {
        return path
    }

    /// 增加引用
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }
}

/// HTMLBundle.Route - 路由级别的 HTML Bundle
/// 对应 Bun: pub const Route = struct { ... }
/// 一个 HTMLBundle.Route 只能在一个服务器上使用
/// 但也是引用计数的，因为一个服务器可以在多个端点上使用同一 HTML 文件
public class HTMLBundleRoute {
    // ========================================================================
    // 字段
    // ========================================================================

    /// Bundle 引用 - 对应 Bun: bundle: RefPtr(HTMLBundle)
    public var bundle: ?HTMLBundle

    /// 引用计数 - 对应 Bun: ref_count: Route.RefCount
    public var refCount: Int64

    /// 服务器引用 - 对应 Bun: server: ?AnyServer = null
    public var server: ?ServerRef

    /// 路由状态 - 对应 Bun: state: State
    public var state: HTMLBundleRouteState

    /// 方法 - 对应 Bun: method: union(enum) { any, method }
    public var method: HTMLBundleMethod

    /// 待处理响应列表 - 对应 Bun: pending_responses: std.ArrayListUnmanaged(*PendingResponse)
    public var pendingResponses: ArrayList<PendingResponse>

    public init() {
        bundle = None
        refCount = 1
        server = None
        state = HTMLBundleRouteState.Pending
        method = HTMLBundleMethod.Any
        pendingResponses = ArrayList<PendingResponse>()
    }

    /// 初始化
    /// 对应 Bun: pub fn init(html_bundle) RefPtr(Route)
    public static func init(htmlBundle: HTMLBundle): HTMLBundleRoute {
        let route = HTMLBundleRoute()
        route.bundle = Some(htmlBundle)
        htmlBundle.ref()
        return route
    }

    /// 内存开销
    /// 对应 Bun: pub fn memoryCost(this) usize
    public func memoryCost(): Int64 {
        var cost: Int64 = 0
        cost += pendingResponses.size
        return cost
    }

    /// 析构
    /// 对应 Bun: fn deinit(this) void
    public func deinit(): Unit {
        // 清理待处理响应
        pendingResponses.clear()

        // 释放 bundle 引用
        match (bundle) {
            case Some(b) => b.deref()
            case None => ()
        }

        // 清理状态
        match (state) {
            case HTMLBundleRouteState.Pending => ()
            case HTMLBundleRouteState.Ready(_) => ()
            case HTMLBundleRouteState.Error(_) => ()
        }
    }

    /// 增加引用
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    public func deref(): Unit {
        refCount -= 1
        if (refCount <= 0) {
            deinit()
        }
    }
}

/// HTML Bundle 路由状态
/// 对应 Bun: pub const State = union(enum) { pending, building, ready, error }
public enum HTMLBundleRouteState {
    | Pending
    | Building(?)    // 构建任务引用
    | Ready(Array<UInt8>)  // 构建完成的 HTML 内容
    | Error(String)  // 构建错误信息
}

/// HTML Bundle 方法
/// 对应 Bun: method: union(enum) { any: void, method: bun.http.Method.Set }
public enum HTMLBundleMethod {
    | Any
    | Specific(HttpMethodSet)
}

/// 待处理响应
/// 对应 Bun: PendingResponse (HTMLBundle.Route 中的 pending 响应)
public class PendingResponse {
    public var response: ?ResponseRef
    public var timestamp: Int64

    public init() {
        response = None
        timestamp = 0
    }
}
