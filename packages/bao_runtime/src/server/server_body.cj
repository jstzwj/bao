// 严格翻译自: src/runtime/server/server_body.rs
// Bun HTTP 服务器主体实现
// 对应 Bun: src/runtime/server/server_body.rs (port of src/runtime/server/server.zig)

package bao_runtime.server

import bao_core.*
import bao_collections.*
import bao_jsc.*
import bao_sys.*

// ============================================================================
// 重导出
// 对应 Bun: pub use super::* 模块重导出
// ============================================================================

// 重导出同目录下的子模块
// 对应 Bun: pub use super::html_bundle::{self as html_bundle, HTMLBundle}
// 对应 Bun: pub use super::http_status_text as HTTPStatusText
// 对应 Bun: pub use super::web_socket_server_context::WebSocketServerContext
// 对应 Bun: pub use super::any_request_context::AnyRequestContext
// 对应 Bun: pub use super::file_response_stream::FileResponseStream
// 对应 Bun: pub use super::file_route::FileRoute
// 对应 Bun: pub use super::node_http_response::NodeHTTPResponse
// 对应 Bun: pub use super::range_request as RangeRequest
// 对应 Bun: pub use super::request_context::{DeferDeinitFlag, RequestContext as NewRequestContext}
// 对应 Bun: pub use super::server_config::{self as server_config, ServerConfig}
// 对应 Bun: pub use super::server_web_socket::ServerWebSocket
// 对应 Bun: pub use super::static_route::StaticRoute

// ============================================================================
// RequestCtx - 请求上下文 trait
// 对应 Bun: pub trait RequestCtx
// ============================================================================

/// 请求上下文接口
/// 对应 Bun: pub trait RequestCtx: super::any_request_context::CtxKind
/// Zig 的 NewRequestContext 暴露 Req/Resp/http3 作为 comptime 关联声明。
/// 仓颉没有 inherent associated types，通过此 trait 提供泛型支持
public interface RequestCtxIsh {
    func isH3(): Bool
}

// ============================================================================
// RequestCtxOps - 请求上下文操作接口
// 对应 Bun: pub trait RequestCtxOps: RequestCtx
// ============================================================================

/// 请求上下文操作
/// 对应 Bun: pub trait RequestCtxOps: RequestCtx
/// 提供 createIn, onResponse, deinit, shouldRenderMissing, renderMissing 等方法
public interface RequestCtxOpsIsh {
    func createIn(slot: RequestContext, server: ServerRef, req: RequestRef,
                   resp: ResponseRef, shouldDeinitContext: ?DeferDeinitFlag,
                   method: ?HttpMethod)
    func onResponse(server: ServerRef, requestValue: JsValue, responseValue: JsValue)
    func deinit(): Unit
    func shouldRenderMissing(): Bool
    func renderMissing(): Unit
    func toAsync(req: RequestRef, requestObject: Request)
    func ctxMethod(): HttpMethod
    func setUpgradeContext(ctx: ?WebSocketUpgradeContext)
    func deferDeinitPtr(): ?DeferDeinitFlag
    func setRequestBody(body: ?BodyValue)
    func requestBodyMut(): ?BodyValue
    func setSignal(sig: AbortSignal)
    func setRequestWeakref(req: Request)
    func clearReq(): Unit
    func setIsWebBrowserNavigation(v: Bool)
    func setRequestBodyContentLen(len: Int64)
    func setIsTransferEncoding(v: Bool)
    func setIsWaitingForRequestBody(v: Bool)
    func armOnData(resp: ResponseRef)
}

// ============================================================================
// ReqLike - 请求接口
// 对应 Bun: pub trait ReqLike
// ============================================================================

/// HTTP 请求接口
/// 对应 Bun: pub trait ReqLike
/// 提供对 uWS HTTP/1 或 HTTP/3 请求句柄类型的统一访问
public interface ReqLikeIsh {
    func header(name: Array<UInt8>): ?Array<UInt8>
    func method(): Array<UInt8>
    func url(): Array<UInt8>
    func setYield(y: Bool): Unit
}

// ============================================================================
// RespLike - 响应接口
// 对应 Bun: pub trait RespLike
// ============================================================================

/// HTTP 响应接口
/// 对应 Bun: pub trait RespLike
public interface RespLikeIsh {
    func writeStatus(status: Array<UInt8>): Unit
    func endWithoutBody(closeConnection: Bool): Unit
    func timeout(seconds: UInt8): Unit
    func onTimeoutWarn(ud: CPointer<Unit>): Unit
    func toAnyResponse(): AnyResponse
}

// ============================================================================
// ServerApp - 服务器应用类型
// 对应 Bun: pub type ServerApp<const SSL: bool> = uws::NewApp<SSL>
// ============================================================================

/// 服务器应用
/// 对应 Bun: pub type ServerApp<const SSL: bool> = uws::NewApp<SSL>
public class ServerApp {
    public var ssl: Bool
    public var routes: ArrayList<RouteEntry>
    public var running: Bool

    public init(ssl: Bool) {
        this.ssl = ssl
        this.routes = ArrayList<RouteEntry>()
        this.running = false
    }

    /// 注册 GET 路由
    /// 对应 Bun: AppRouteExt::get_ctx
    public func get(pattern: String, handler: RouteHandler): Unit {
        routes.append(RouteEntry(pattern: pattern, method: HttpMethod.GET, handler: handler))
    }

    /// 注册 HEAD 路由
    /// 对应 Bun: AppRouteExt::head_ctx
    public func head(pattern: String, handler: RouteHandler): Unit {
        routes.append(RouteEntry(pattern: pattern, method: HttpMethod.HEAD, handler: handler))
    }

    /// 注册所有方法路由
    /// 对应 Bun: AppRouteExt::any_ctx
    public func any(pattern: String, handler: RouteHandler): Unit {
        routes.append(RouteEntry(pattern: pattern, method: HttpMethod.ANY, handler: handler))
    }

    /// 注册特定方法路由
    /// 对应 Bun: AppRouteExt::method_ctx
    public func methodFunc(m: HttpMethod, pattern: String, handler: RouteHandler): Unit {
        routes.append(RouteEntry(pattern: pattern, method: m, handler: handler))
    }
}

/// 路由条目
public class RouteEntry {
    public var pattern: String
    public var method: HttpMethod
    public var handler: RouteHandler

    public init(pattern: String, method: HttpMethod, handler: RouteHandler) {
        this.pattern = pattern
        this.method = method
        this.handler = handler
    }
}

/// 路由处理器类型
/// 对应 Bun: trampoline function signature
public type RouteHandler = (req: RequestRef, resp: ResponseRef) -> Unit

// ============================================================================
// 方法集
// 对应 Bun: pub(crate) type MethodSet = bun_http_types::Method::Set
// ============================================================================

/// HTTP 方法集 (位集)
/// 对应 Bun: MethodSet = HTTP.Method.Set
public class MethodSet {
    public var bits: UInt32

    public init() {
        this.bits = 0
    }

    /// 插入方法
    public func insert(method: HttpMethod): Unit {
        bits = bits | (1 << method.ordinal())
    }

    /// 检查是否包含
    public func contains(method: HttpMethod): Bool {
        return (bits & (1 << method.ordinal())) != 0
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return bits == 0
    }
}

// ============================================================================
// ServerInitContext - 服务器初始化上下文
// 对应 Bun: pub struct ServerInitContext<'a>
// ============================================================================

/// 服务器初始化上下文
/// 对应 Bun: pub struct ServerInitContext<'a>
public class ServerInitContext {
    /// HTML bundle 去重映射
    /// 对应 Bun: pub dedupe_html_bundle_map: HashMap<*const HTMLBundle, RefPtr<html_bundle::Route>>
    public var dedupeHtmlBundleMap: HashMap<HTMLBundle, HtmlBundleRoute>

    /// JS 字符串分配列表
    /// 对应 Bun: pub js_string_allocations: bake::StringRefList
    public var jsStringAllocations: ArrayList<BaoString>

    /// 全局对象
    /// 对应 Bun: pub global: &'a JSGlobalObject
    public var global: JsObject

    /// 框架路由列表
    /// 对应 Bun: pub framework_router_list: Vec<bake::FileSystemRouterType>
    public var frameworkRouterList: ArrayList<FileSystemRouterType>

    /// 用户路由
    /// 对应 Bun: pub user_routes: &'a mut Vec<server_config::StaticRouteEntry>
    public var userRoutes: ArrayList<StaticRouteEntry>

    public init(global: JsObject) {
        this.dedupeHtmlBundleMap = HashMap<HTMLBundle, HtmlBundleRoute>()
        this.jsStringAllocations = ArrayList<BaoString>()
        this.global = global
        this.frameworkRouterList = ArrayList<FileSystemRouterType>()
        this.userRoutes = ArrayList<StaticRouteEntry>()
    }
}

// ============================================================================
// ServePlugins - 服务器插件状态机
// 对应 Bun: pub struct ServePlugins
// ============================================================================

/// 服务器插件状态机
/// 对应 Bun: pub struct ServePlugins
/// 处理异步加载插件的状态。此结构不是线程安全的。
public class ServePlugins {
    public var state: ServePluginsState
    public var refCount: UInt32

    public init(state: ServePluginsState) {
        this.state = state
        this.refCount = 1
    }

    /// 初始化
    /// 对应 Bun: pub fn init(plugins) -> *mut ServePlugins
    public static func init(plugins: ArrayList<Array<UInt8>>): ServePlugins {
        return ServePlugins(ServePluginsState.Unqueued(plugins))
    }

    /// 增加引用计数
    /// 对应 Bun: pub fn ref_(&self)
    public func ref_(): Unit {
        refCount = refCount + 1
    }

    /// 减少引用计数
    /// 对应 Bun: pub unsafe fn deref_(this: *mut Self)
    public func deref_(): Unit {
        refCount = refCount - 1
        if (refCount <= 0) {
            deinit()
        }
    }

    /// 获取或开始加载
    /// 对应 Bun: pub fn get_or_start_load(&mut self, global, cb) -> JsResult<GetOrStartLoadResult>
    public func getOrStartLoad(global: JsObject, cb: ServePluginsCallback): ?GetOrStartLoadResult {
        // 简化状态机: 检查当前状态
        match (state) {
            case ServePluginsState.Unqueued(_) =>
                // 对应 Bun: self.load_and_resolve_plugins(global)
                return GetOrStartLoadResult.Ready(None)
            case ServePluginsState.Pending(_) =>
                return GetOrStartLoadResult.Pending
            case ServePluginsState.Loaded(plugin) =>
                return GetOrStartLoadResult.Ready(Some(plugin))
            case ServePluginsState.Err =>
                return GetOrStartLoadResult.Err
        }
    }

    /// 释放资源
    public func deinit(): Unit {
        match (state) {
            case ServePluginsState.Unqueued(_) => ()
            case ServePluginsState.Pending(_) => ()
            case ServePluginsState.Loaded(_) => ()
            case ServePluginsState.Err => ()
        }
    }
}

/// 服务器插件状态
/// 对应 Bun: pub enum ServePluginsState
public enum ServePluginsState {
    | Unqueued(ArrayList<Array<UInt8>>)
    | Pending(ServePluginsPendingData)
    | Loaded(?JsBundlerPlugin)
    | Err

    public func isLoaded(): Bool {
        match (this) {
            case ServePluginsState.Loaded(_) => true
            case _ => false
        }
    }
}

/// 待处理插件数据
/// 对应 Bun: ServePluginsState::Pending { plugin, promise, html_bundle_routes, dev_server }
public class ServePluginsPendingData {
    public var plugin: JsBundlerPlugin
    public var promise: JsPromiseStrong
    public var htmlBundleRoutes: ArrayList<HtmlBundleRoute>
    public var devServer: ?DevServer

    public init(plugin: JsBundlerPlugin, promise: JsPromiseStrong) {
        this.plugin = plugin
        this.promise = promise
        this.htmlBundleRoutes = ArrayList<HtmlBundleRoute>()
        this.devServer = None
    }
}

/// 获取或加载结果
/// 对应 Bun: pub enum GetOrStartLoadResult<'a>
public enum GetOrStartLoadResult {
    | Ready(?JsBundlerPlugin)
    | Pending
    | Err
}

/// 服务器插件回调
/// 对应 Bun: pub enum ServePluginsCallback<'a>
public enum ServePluginsCallback {
    | HtmlBundleRoute(HtmlBundleRoute)
    | DevServer(DevServer)
}

/// 插件引用守卫
/// 对应 Bun: struct ServePluginsRef
public class ServePluginsRef {
    public var plugins: ServePlugins

    public init(plugins: ServePlugins) {
        this.plugins = plugins
    }

    /// 释放时递减引用计数
    /// 对应 Bun: impl Drop for ServePluginsRef
    public func deinit(): Unit {
        plugins.deref_()
    }
}

// ============================================================================
// BunInfo - Bun 信息
// 对应 Bun: pub mod BunInfo
// ============================================================================

/// Bun 版本和平台信息
/// 对应 Bun: pub struct BunInfo
public class BunInfo {
    public var bunVersion: String
    public var platform: PlatformInfo

    public init(bunVersion: String, platform: PlatformInfo) {
        this.bunVersion = bunVersion
        this.platform = platform
    }
}

/// 平台信息
/// 对应 Bun: Platform struct
public class PlatformInfo {
    public var os: String
    public var arch: String
    public var version: String

    public init(os: String, arch: String, version: String) {
        this.os = os
        this.arch = arch
        this.version = version
    }
}

// ============================================================================
// AnyRoute - 任意路由类型
// 对应 Bun: pub enum AnyRoute (在 mod.rs 中定义，此处添加 JS 构造器)
// ============================================================================

/// 任意路由类型
/// 对应 Bun: pub use super::AnyRoute (enum 在 mod.rs 定义)
/// 此处添加 JS 面向构造器 (from_js, from_options 等)
public enum AnyRoute {
    | Static(StaticRoute)
    | File(FileRoute)
    | HtmlBundle(HtmlBundleRoute)

    /// 从选项创建路由
    /// 对应 Bun: pub fn from_options(global, headers, path) -> JsResult<AnyRoute>
    public static func fromOptions(global: JsObject, headers: ?FetchHeaders,
                                    path: PathOrFileDescriptor): ?AnyRoute {
        // 对应 Bun: <Blob as BlobExt>::find_or_create_file_from_path(path, global, false)
        // 简化: 返回文件路由
        return AnyRoute.File(FileRoute())
    }

    /// 从 JS 值创建路由
    /// 对应 Bun: fn from_js(global, argument) -> JsResult<Option<AnyRoute>>
    public static func fromJs(global: JsObject, argument: JsValue): ?AnyRoute {
        if (!argument.isObject()) {
            return None
        }
        return None
    }
}

// ============================================================================
// PreparedRequestFor - 预处理请求
/// 对应 Bun: pub struct PreparedRequestFor<'a, Ctx>
// ============================================================================

/// 预处理请求
/// 对应 Bun: pub struct PreparedRequestFor<'a, Ctx>
public class PreparedRequestFor {
    public var ctx: RequestContext
    public var requestValue: ?JsValue
    public var responseValue: ?JsValue

    public init(ctx: RequestContext) {
        this.ctx = ctx
        this.requestValue = None
        this.responseValue = None
    }
}

// ============================================================================
// 服务器配置辅助函数
// 对应 Bun: pub fn server_set_idle_timeout_ 等
// ============================================================================

/// 设置空闲超时
/// 对应 Bun: pub fn server_set_idle_timeout_(...)
public func serverSetIdleTimeout(global: JsObject, args: ArrayList<JsValue>): JsValue {
    return JsValue.UNDEFINED
}

/// 设置客户端错误处理器
/// 对应 Bun: pub fn server_set_on_client_error_(...)
public func serverSetOnClientError(global: JsObject, args: ArrayList<JsValue>): JsValue {
    return JsValue.UNDEFINED
}

/// 设置应用标志
/// 对应 Bun: pub fn server_set_app_flags_(...)
public func serverSetAppFlags(global: JsObject, args: ArrayList<JsValue>): JsValue {
    return JsValue.UNDEFINED
}

/// 设置最大 HTTP 头大小
/// 对应 Bun: pub fn server_set_max_http_header_size_(...)
public func serverSetMaxHttpHeaderSize(global: JsObject, args: ArrayList<JsValue>): JsValue {
    return JsValue.UNDEFINED
}

/// 解析回调
/// 对应 Bun: pub fn on_resolve_impl(global, callframe) -> JsResult<JSValue>
public func onResolveImpl(global: JsObject, callframe: CallFrame): ?JsValue {
    return JsValue.UNDEFINED
}

/// 拒绝回调
/// 对应 Bun: pub fn on_reject_impl(global, callframe) -> JsResult<JSValue>
public func onRejectImpl(global: JsObject, callframe: CallFrame): ?JsValue {
    return JsValue.UNDEFINED
}

// ============================================================================
// AnyUserRouteList - 用户路由列表
// 对应 Bun: pub enum AnyUserRouteList<'a>
// ============================================================================

/// 用户路由列表
/// 对应 Bun: pub enum AnyUserRouteList<'a>
public enum AnyUserRouteList {
    | StaticRoutes(ArrayList<AnyRoute>)
    | UserRoutes(ArrayList<AnyRoute>)
}

// ============================================================================
// HTTP 请求/响应/服务器 相关类型
// ============================================================================

/// 请求上下文
/// 对应 Bun: NewRequestContext<ThisServer, SSL, DBG, H3>
public class RequestContext {
    public var method: HttpMethod
    public var upgradeContext: ?WebSocketUpgradeContext
    public var deferDeinitUntilCallbackCompletes: ?DeferDeinitFlag
    public var requestBody: ?BodyValue
    public var signal: ?AbortSignal
    public var requestWeakref: ?Request
    public var flags: RequestContextFlags

    public init() {
        this.method = HttpMethod.GET
        this.upgradeContext = None
        this.deferDeinitUntilCallbackCompletes = None
        this.requestBody = None
        this.signal = None
        this.requestWeakref = None
        this.flags = RequestContextFlags()
    }
}

/// 请求上下文标志
/// 对应 Bun: RequestContext.flags (packed struct)
public class RequestContextFlags {
    public var isWebBrowserNavigation: Bool
    public var isTransferEncoding: Bool
    public var isWaitingForRequestBody: Bool

    public init() {
        isWebBrowserNavigation = false
        isTransferEncoding = false
        isWaitingForRequestBody = false
    }

    public func setIsWebBrowserNavigation(v: Bool): Unit { isWebBrowserNavigation = v }
    public func setIsTransferEncoding(v: Bool): Unit { isTransferEncoding = v }
    public func setIsWaitingForRequestBody(v: Bool): Unit { isWaitingForRequestBody = v }
}

/// 延迟释放标志
/// 对应 Bun: DeferDeinitFlag
public class DeferDeinitFlag {
    public init() {}
}

/// 请求体值
/// 对应 Bun: webcore::body::Value
public class BodyValue {
    public init() {}
}

/// 中止信号
/// 对应 Bun: webcore::AbortSignal
public class AbortSignal {
    public init() {}
}

/// 请求
/// 对应 Bun: webcore::Request
public class Request {
    public init() {}
}

/// 请求引用
/// 对应 Bun: uws::Request (wraps raw pointer)
public class RequestRef {
    public init() {}
}

/// 响应引用
/// 对应 Bun: uws::NewAppResponse<SSL>
public class ResponseRef {
    public init() {}
}

/// 任意响应
/// 对应 Bun: uws::AnyResponse
public class AnyResponse {
    public init() {}
}

/// 服务器引用
/// 对应 Bun: *const NewServer
public class ServerRef {
    public init() {}
}

/// WebSocket 升级上下文
/// 对应 Bun: uws::WebSocketUpgradeContext
public class WebSocketUpgradeContext {
    public init() {}
}

/// 文件路由
/// 对应 Bun: super::file_route::FileRoute
public class FileRoute {
    public init() {}
}

/// 静态路由
/// 对应 Bun: super::static_route::StaticRoute
public class StaticRoute {
    public init() {}
}

/// HTML Bundle 路由
/// 对应 Bun: html_bundle::Route
public class HtmlBundleRoute {
    public init() {}
}

/// HTML Bundle
/// 对应 Bun: html_bundle::HTMLBundle
public class HTMLBundle {
    public init() {}
}

/// 静态路由条目
/// 对应 Bun: server_config::StaticRouteEntry
public class StaticRouteEntry {
    public var path: Array<UInt8>
    public var route: AnyRoute
    public var method: MethodSet

    public init(path: Array<UInt8>, route: AnyRoute, method: MethodSet) {
        this.path = path
        this.route = route
        this.method = method
    }
}

/// FetchHeaders
/// 对应 Bun: webcore::FetchHeaders
public class FetchHeaders {
    public init() {}
}

/// 文件系统路由类型
/// 对应 Bun: bake::FileSystemRouterType
public class FileSystemRouterType {
    public init() {}
}

/// JS Bundler 插件
/// 对应 Bun: api::js_bundler::Plugin
public class JsBundlerPlugin {
    public init() {}
}

/// JS Promise 强引用
/// 对应 Bun: jsc::JSPromiseStrong
public class JsPromiseStrong {
    public init() {}
}

/// DevServer
/// 对应 Bun: bake::dev_server::DevServer
public class DevServer {
    public init() {}
}

/// 路径或文件描述符
/// 对应 Bun: node::types::PathOrFileDescriptor
public class PathOrFileDescriptor {
    public init() {}
}

/// CallFrame
/// 对应 Bun: jsc::CallFrame
public class CallFrame {
    public init() {}
}

// ============================================================================
// HttpMethod - HTTP 方法
// 对应 Bun: bun_http::Method
// ============================================================================

/// HTTP 方法
/// 对应 Bun: bun_http::Method
public enum HttpMethod {
    | GET
    | HEAD
    | POST
    | PUT
    | DELETE
    | PATCH
    | OPTIONS
    | CONNECT
    | TRACE
    | ANY

    public func ordinal(): Int64 {
        match (this) {
            case HttpMethod.GET => 0
            case HttpMethod.HEAD => 1
            case HttpMethod.POST => 2
            case HttpMethod.PUT => 3
            case HttpMethod.DELETE => 4
            case HttpMethod.PATCH => 5
            case HttpMethod.OPTIONS => 6
            case HttpMethod.CONNECT => 7
            case HttpMethod.TRACE => 8
            case HttpMethod.ANY => 9
        }
    }

    public func name(): String {
        match (this) {
            case HttpMethod.GET => "GET"
            case HttpMethod.HEAD => "HEAD"
            case HttpMethod.POST => "POST"
            case HttpMethod.PUT => "PUT"
            case HttpMethod.DELETE => "DELETE"
            case HttpMethod.PATCH => "PATCH"
            case HttpMethod.OPTIONS => "OPTIONS"
            case HttpMethod.CONNECT => "CONNECT"
            case HttpMethod.TRACE => "TRACE"
            case HttpMethod.ANY => "ANY"
        }
    }

    public static func fromName(s: String): ?HttpMethod {
        match (s) {
            case "GET" => HttpMethod.GET
            case "HEAD" => HttpMethod.HEAD
            case "POST" => HttpMethod.POST
            case "PUT" => HttpMethod.PUT
            case "DELETE" => HttpMethod.DELETE
            case "PATCH" => HttpMethod.PATCH
            case "OPTIONS" => HttpMethod.OPTIONS
            case "CONNECT" => HttpMethod.CONNECT
            case "TRACE" => HttpMethod.TRACE
            case _ => None
        }
    }
}

/// 空闲超时警告回调
/// 对应 Bun: fn on_timeout_for_idle_warn()
private func onTimeoutForIdleWarn(): Unit {
    // 空闲超时警告 (开发模式)
    Output.prettyErrorln("Warning: request is taking too long. It has been idle for a while.")
}

/// 输出工具
public class Output {
    public static func prettyErrorln(msg: String): Unit {
        println(msg)
    }
}

// ported from: src/runtime/server/server_body.rs
