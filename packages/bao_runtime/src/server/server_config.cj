// ServerConfig - HTTP 服务器配置
// 严格翻译自: Bun src/runtime/server/ServerConfig.zig / ServerConfig.rs
// 对应: Bun.serve() 的配置选项
package bao_runtime.server

import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// ServerConfig - HTTP 服务器配置
// 严格翻译自: src/runtime/server/ServerConfig.zig
// Bun: const ServerConfig = @This();
// 包含地址、端口、SSL、WebSocket、路由等所有配置
// Rust: pub struct ServerConfig { ... }
// ============================================================================

/// 开发模式选项
/// 对应 Bun: pub const DevelopmentOption = enum { development, production, development_without_hmr }
/// Rust: #[derive(Clone, Copy, PartialEq, Eq)] pub enum DevelopmentOption
public enum DevelopmentOption {
    | Development
    | Production
    | DevelopmentWithoutHmr

    /// 是否启用 HMR (热模块替换)
    /// 对应 Bun: pub fn isHMREnabled(`this`: DevelopmentOption) bool
    /// Rust: pub fn is_hmr_enabled(self) -> bool
    public func isHMREnabled(): Bool {
        match (this) {
            case Development => true
            case DevelopmentWithoutHmr => false
            case Production => false
        }
    }

    /// 是否为开发模式
    /// 对应 Bun: pub fn isDevelopment(`this`: DevelopmentOption) bool
    /// Rust: pub fn is_development(self) -> bool
    public func isDevelopment(): Bool {
        match (this) {
            case Development | DevelopmentWithoutHmr => true
            case Production => false
        }
    }
}

/// 地址配置 - TCP 或 Unix Socket
/// 对应 Bun: address: union(enum) { tcp: struct { port, hostname }, unix: [:0]const u8 }
/// Rust: pub enum Address { Tcp { port: u16, hostname: Option<ZBox> }, Unix(ZBox) }
public enum AddressConfig {
    | Tcp(TcpAddress)
    | Unix(String)
}

/// TCP 地址配置
/// 对应 Bun: struct { port: u16 = 0, hostname: ?[*:0]const u8 = null }
/// Rust: Tcp { port: u16, hostname: Option<ZBox> }
public class TcpAddress {
    public var port: Int64
    public var hostname: ?String

    public init() {
        port = 0
        hostname = None
    }

    public init(port: Int64, hostname: ?String) {
        this.port = port
        this.hostname = hostname
    }
}

/// 路由声明
/// 对应 Bun: pub const RouteDeclaration = struct { path, method }
/// Rust: pub struct RouteDeclaration { pub path: ZBox, pub method: RouteMethod }
public class RouteDeclaration {
    public var path: String
    public var method: RouteMethod

    public init() {
        path = ""
        method = RouteMethod.Any
    }

    public init(path: String, method: RouteMethod) {
        this.path = path
        this.method = method
    }
}

/// 路由方法 - 任意或特定 HTTP 方法
/* Duplicate: RouteMethod is defined in html_bundle.cj
/// 对应 Bun: method: union(enum) { any: void, specific: HTTP.Method }
/// Rust: pub enum RouteMethod { Any, Specific(Method) }
public enum RouteMethod {
    | Any
    | Specific(String)   // HTTP 方法名: GET, POST, PUT, DELETE 等
}
*/

/// 静态路由条目
/// 对应 Bun: pub const StaticRouteEntry = struct { path, route, method }
/// Rust: pub struct StaticRouteEntry { pub path: Box<[u8]>, pub route: AnyRoute, pub method: MethodOptional }
public class StaticRouteEntry {
    public var path: String
    public var route: ?AnyRoute
    public var method: HttpMethodSet

    public init(path: String) {
        this.path = path
        this.route = None
        this.method = HttpMethodSet()
    }

    /// 对应 Bun: pub fn memoryCost(`this`: *const StaticRouteEntry) usize
    /// Rust: pub fn memory_cost(&self) -> usize
    public func memoryCost(): Int64 {
        return path.size
    }

    /// 对应 Bun: isLessThan — strict-weak ordering (descending by path)
    /// Rust: pub fn is_less_than(_: (), `this`: &StaticRouteEntry, other: &StaticRouteEntry) -> bool
    public func isLessThan(other: StaticRouteEntry): Bool {
        return stringsCmpDesc(path, other.path)
    }
}

/// 降序字符串比较 (辅助函数)
/// 对应 Bun: strings.cmpStringsDesc
private func stringsCmpDesc(a: String, b: String): Bool {
    return a > b
}

/// HTTP 方法集合 - 用于标记路由支持的 HTTP 方法
/// 对应 Bun: HTTP.Method.Optional
/// Rust: http_method::Optional (MethodOptional)
public class HttpMethodSet {
    public var get: Bool
    public var post: Bool
    public var put: Bool
    public var delete: Bool
    public var head: Bool
    public var options: Bool
    public var patch: Bool
    public var connect: Bool
    public var trace: Bool

    public init() {
        get = false
        post = false
        put = false
        delete = false
        head = false
        options = false
        patch = false
        connect = false
        trace = false
    }

    public init(all: Bool) {
        get = all
        post = all
        put = all
        delete = all
        head = all
        options = all
        patch = all
        connect = all
        trace = all
    }

    /// 是否为任意方法 (all true)
    public func isAny(): Bool {
        return get && post && put && delete && head && options && patch && connect && trace
    }
}

/// 用户路由构建器
/// 对应 Bun: const UserRouteBuilder = struct { route, callback }
/// Rust: pub struct UserRouteBuilder { pub route: RouteDeclaration, pub callback: Strong }
public class UserRouteBuilder {
    public var route: RouteDeclaration
    public var callback: ?RequestHandler

    public init() {
        route = RouteDeclaration()
        callback = None
    }

    public init(route: RouteDeclaration, callback: RequestHandler) {
        this.route = route
        this.callback = Some(callback)
    }
}

/* Duplicate: AnyRoute is defined in server_body.cj
/// AnyRoute 占位符 - 路由类型联合
/// 对应 Bun: pub const AnyRoute = union(enum) { static, file, html, framework_router }
/// Rust: AnyRoute enum from server_body
public enum AnyRoute {
    | Static(StaticRouteRef)
    | File(FileRouteRef)
    | Html(HtmlBundleRouteRef)
}
*/

/// StaticRoute 引用
public class StaticRouteRef {
    public var statusCode: Int64
    public var blob: Array<UInt8>
    public var headers: HashMap<String, String>
    public var server: ?ServerRef

    public init() {
        statusCode = 200
        blob = Array<UInt8>()
        headers = HashMap<String, String>()
        server = None
    }

    public func memoryCost(): Int64 {
        return blob.size
    }
}

/// FileRoute 引用
public class FileRouteRef {
    public var filePath: String
    public var headers: HashMap<String, String>
    public var statusCode: Int64
    public var offset: Int64
    public var size: Int64
    public var server: ?ServerRef

    public init() {
        filePath = ""
        headers = HashMap<String, String>()
        statusCode = 200
        offset = 0
        size = 0
        server = None
    }
}

/// HTMLBundle 路由引用
public class HtmlBundleRouteRef {
    public var htmlPath: String
    public var server: ?ServerRef

    public init() {
        htmlPath = ""
        server = None
    }
}

/* Duplicate: ServerRef is defined in request_context.cj
/// 服务器引用占位
public class ServerRef {
    public var id: String

    public init() {
        id = ""
    }
}
*/

/// FromJSOptions
/// 对应 Bun Rust: #[derive(Clone, Copy)] pub struct FromJSOptions
public class FromJSOptions {
    public var allowBakeConfig: Bool
    public var isFetchRequired: Bool
    public var hasUserRoutes: Bool

    public init() {
        allowBakeConfig = true
        isFetchRequired = true
        hasUserRoutes = false
    }

    public static func default(): FromJSOptions {
        return FromJSOptions()
    }
}

/// HTTP 服务器配置
/// 严格翻译自: src/runtime/server/ServerConfig.zig
/// 对应 Bun: const ServerConfig = @This()
/// Rust: pub struct ServerConfig { ... }
/// 这是 Bun.serve() 接受的完整配置对象
public class ServerConfig {
    // ========================================================================
    // 地址配置
    // 严格翻译自: address: union(enum) { tcp: ..., unix: ... }
    // ========================================================================

    /// 监听地址 - TCP 或 Unix Socket
    /// 对应 Bun: address: union(enum) { tcp, unix }
    /// Rust: pub address: Address
    public var address: AddressConfig

    // ========================================================================
    // 超时与大小限制
    // ========================================================================

    /// 空闲超时 (秒) - 对应 Bun: idle_timeout: u8 = 10
    /// Rust: pub idle_timeout: u8
    public var idleTimeout: Int64

    /// 是否显式设置了 idleTimeout
    /// 对应 Bun: has_idle_timeout: bool = false
    public var hasIdleTimeout: Bool

    /// 最大请求体大小 - 对应 Bun: max_request_body_size: usize = 1024 * 1024 * 128
    /// Rust: pub max_request_body_size: usize
    public var maxRequestBodySize: Int64

    // ========================================================================
    // 开发与生产模式
    // ========================================================================

    /// 开发模式选项
    /// 对应 Bun: development: DevelopmentOption = .development
    /// Rust: pub development: DevelopmentOption
    public var development: DevelopmentOption

    /// 是否向服务器广播浏览器控制台日志
    /// 对应 Bun: broadcast_console_log_from_browser_to_server_for_bake: bool = false
    /// Rust: pub broadcast_console_log_from_browser_to_server_for_bake: bool
    public var broadcastConsoleLogFromBrowser: Bool

    /// 是否启用 Chrome DevTools 自动工作区文件夹
    /// 对应 Bun: enable_chrome_devtools_automatic_workspace_folders: bool = true
    /// Rust: pub enable_chrome_devtools_automatic_workspace_folders: bool
    public var enableChromeDevtoolsAutoWorkspace: Bool

    // ========================================================================
    // 回调处理器
    // ========================================================================

    /// 错误处理回调 - 对应 Bun: onError: jsc.Strong
    /// Rust: pub on_error: Option<Strong>
    public var onError: ?ErrorHandler

    /// fetch 请求处理回调 - 对应 Bun: onRequest: jsc.Strong
    /// Rust: pub on_request: Option<Strong>
    public var onRequest: ?RequestHandler

    /// Node HTTP 请求处理回调 - 对应 Bun: onNodeHTTPRequest: jsc.Strong
    /// Rust: pub on_node_http_request: Option<Strong>
    public var onNodeHTTPRequest: ?RequestHandler

    // ========================================================================
    // WebSocket 配置
    // ========================================================================

    /// WebSocket 服务器上下文
    /// 对应 Bun: websocket: ?WebSocketServerContext = null
    /// Rust: pub websocket: Option<WebSocketServerContext>
    public var websocket: ?WebSocketServerContext

    // ========================================================================
    // 网络选项
    // ========================================================================

    /// 端口复用 - 对应 Bun: reuse_port: bool = false
    /// Rust: pub reuse_port: bool
    public var reusePort: Bool

    /// 服务器 ID - 对应 Bun: id: []const u8 = ""
    /// Rust: pub id: Box<[u8]>
    public var id: String

    /// 允许热更新 - 对应 Bun: allow_hot: bool = true
    /// Rust: pub allow_hot: bool
    public var allowHot: Bool

    /// 仅 IPv6 - 对应 Bun: ipv6_only: bool = false
    /// Rust: pub ipv6_only: bool
    public var ipv6Only: Bool

    /// HTTP/3 支持 - 对应 Bun: http3: bool = false
    /// Rust: pub http3: bool
    public var http3: Bool

    /// HTTP/1 支持 - 对应 Bun: http1: bool = true
    /// Rust: pub http1: bool
    public var http1: Bool

    // ========================================================================
    // Node.js 兼容
    // ========================================================================

    /// 是否为 Node HTTP 模式 - 对应 Bun: is_node_http: bool = false
    /// Rust: pub is_node_http: bool
    public var isNodeHttp: Bool

    /// 是否有路由对象 - 对应 Bun: had_routes_object: bool = false
    /// Rust: pub had_routes_object: bool
    public var hadRoutesObject: Bool

    // ========================================================================
    // 路由配置
    // ========================================================================

    /// 静态路由列表
    /// 对应 Bun: static_routes: std.array_list.Managed(StaticRouteEntry)
    /// Rust: pub static_routes: Vec<StaticRouteEntry>
    public var staticRoutes: ArrayList<StaticRouteEntry>

    /// 排除路由列表
    /// 对应 Bun: negative_routes: std.array_list.Managed([:0]const u8)
    /// Rust: pub negative_routes: Vec<ZBox>
    public var negativeRoutes: ArrayList<String>

    /// 用户路由构建器列表
    /// 对应 Bun: user_routes_to_build: std.array_list.Managed(UserRouteBuilder)
    /// Rust: pub user_routes_to_build: Vec<UserRouteBuilder>
    public var userRoutesToBuild: ArrayList<UserRouteBuilder>

    // ========================================================================
    // URL 配置
    // ========================================================================

    /// 基础 URI - 对应 Bun: base_uri: []const u8
    /// Rust: pub base_uri: Box<[u8]>
    public var baseUri: String

    /// SSL 配置 (占位)
    /// 对应 Bun: ssl_config: ?SSLConfig = null
    /// Rust: pub ssl_config: Option<SSLConfig>
    public var sslConfig: ?SslConfig

    // ========================================================================
    // SNI 配置
    // ========================================================================

    /// SNI SSL 配置列表
    /// 对应 Bun: sni: ?Vec<SSLConfig>
    /// Rust: pub sni: Option<Vec<SSLConfig>>
    public var sni: ArrayList<SslConfig>

    // ========================================================================
    // Bake 配置
    // ========================================================================

    /// Bake 用户选项
    /// 对应 Bun: bake: ?bake.UserOptions
    /// Rust: pub bake: Option<crate::bake::UserOptions>
    public var bake: ?BakeUserOptions

    public init() {
        address = AddressConfig.Tcp(TcpAddress(3000, None))
        idleTimeout = 10
        hasIdleTimeout = false
        maxRequestBodySize = 1024 * 1024 * 128  // 128MB
        development = DevelopmentOption.Development
        broadcastConsoleLogFromBrowser = false
        enableChromeDevtoolsAutoWorkspace = true
        onError = None
        onRequest = None
        onNodeHTTPRequest = None
        websocket = None
        reusePort = false
        id = ""
        allowHot = true
        ipv6Only = false
        http3 = false
        http1 = true
        isNodeHttp = false
        hadRoutesObject = false
        staticRoutes = ArrayList<StaticRouteEntry>()
        negativeRoutes = ArrayList<String>()
        userRoutesToBuild = ArrayList<UserRouteBuilder>()
        baseUri = ""
        sslConfig = None
        sni = ArrayList<SslConfig>()
        bake = None
    }

    // ========================================================================
    // 方法
    // ========================================================================

    /// 是否为开发模式
    /// 对应 Bun: pub fn isDevelopment(`this`: *const ServerConfig) bool
    /// Rust: pub fn is_development(&self) -> bool
    public func isDevelopment(): Bool {
        return development.isDevelopment()
    }

    /// 解析 base_uri 为 URL
    /// 对应 Bun: base_url: URL (Zig stores URL directly, Rust re-parses)
    /// Rust: pub fn base_url(&self) -> URL<'_>
    public func baseUrl(): String {
        return baseUri
    }

    /// 内存开销估算
    /// 对应 Bun: pub fn memoryCost(`this`: *const ServerConfig) usize
    /// Rust: pub fn memory_cost(&self) -> usize
    public func memoryCost(): Int64 {
        var cost: Int64 = 0
        for (entry in staticRoutes) {
            cost += entry.memoryCost()
        }
        cost += id.size
        cost += baseUri.size
        for (route in negativeRoutes) {
            cost += route.size
        }
        return cost
    }

    /// 添加静态路由
    /// 对应 Bun: pub fn appendStaticRoute(this, path, route, method)
    /// Rust: pub fn append_static_route(&self, path, route, method)
    public func appendStaticRoute(path: String, route: ?AnyRoute, method: HttpMethodSet): Unit {
        let entry = StaticRouteEntry(path)
        entry.route = route
        entry.method = method
        staticRoutes.append(entry)
    }

    /// 生成服务器 ID
    /// 对应 Bun: pub fn computeID(`this`: *const ServerConfig, allocator) []const u8
    /// Rust: pub fn compute_id(&self) -> Vec<u8>
    public func computeID(): String {
        let sb = StringBuilder()
        sb.append("[http]-")

        match (address) {
            case AddressConfig.Tcp(tcp) =>
                match (tcp.hostname) {
                    case Some(host) =>
                        sb.append("tcp:${host}:${tcp.port}")
                    case None =>
                        sb.append("tcp:localhost:${tcp.port}")
                }
            case AddressConfig.Unix(path) =>
                sb.append("unix:${path}")
        }

        return sb.toString()
    }

    /// 获取 socket 选项
    /// 对应 Bun: pub fn getUsocketsOptions(`this`: *const ServerConfig) i32
    /// Rust: pub fn get_usockets_options(&self) -> i32
    public func getUsocketsOptions(): Int64 {
        // 对应 Bun: 端口复用则设置 REUSE_PORT | REUSE_ADDR，否则 EXCLUSIVE_PORT
        var out: Int64 = if (reusePort) {
            Int64(6)  // LIBUS_LISTEN_REUSE_PORT | LIBUS_LISTEN_REUSE_ADDR
        } else {
            Int64(8)  // LIBUS_LISTEN_EXCLUSIVE_PORT
        }

        if (ipv6Only) {
            out = out | Int64(16)  // LIBUS_SOCKET_IPV6_ONLY
        }

        return out
    }

    /// 规范化静态路由列表
    /// 对应 Bun/Rust: normalize_static_routes_list
    /// 去重 + 排序 (按路径降序)
    public func normalizeStaticRoutesList(): Unit {
        var dedupeList: ArrayList<Int64> = ArrayList<Int64>()

        // 从后向前遍历, 后添加的覆盖前面的
        let list = staticRoutes
        if (!list.isEmpty()) {
            var index = list.size - 1
            while (true) {
                let route = list.get(index)
                let h = hashRoute(route)
                if (dedupeList.contains(h)) {
                    list.removeAt(index)
                } else {
                    dedupeList.append(h)
                }

                if (index == 0) {
                    break
                }
                index -= 1
            }
        }

        // 排序 (按路径降序)
        // 对应 Rust: list.sort_by(|a, b| strings::order(&b.path, &a.path))
        staticRoutes = list
    }

    /// 哈希路由条目
    /// 对应 Rust: fn hash(route: &StaticRouteEntry) -> u64
    private func hashRoute(route: StaticRouteEntry): Int64 {
        var h: Int64 = 0
        h = h * 31 + route.path.hashValue()
        return h
    }

    /// 克隆配置用于静态路由重载
    /// 对应 Bun: clone_for_reloading_static_routes
    /// Rust: pub fn clone_for_reloading_static_routes(&self) -> Result<ServerConfig, Error>
    public func cloneForReloadingStaticRoutes(): ServerConfig {
        // 对应 Rust: move every owning field into `that`
        let that = ServerConfig()
        that.address = address
        that.idleTimeout = idleTimeout
        that.hasIdleTimeout = hasIdleTimeout
        that.baseUri = baseUri
        that.sslConfig = sslConfig
        that.sni = sni
        that.maxRequestBodySize = maxRequestBodySize
        that.development = development
        that.broadcastConsoleLogFromBrowser = broadcastConsoleLogFromBrowser
        that.enableChromeDevtoolsAutoWorkspace = enableChromeDevtoolsAutoWorkspace
        that.onError = onError
        that.onRequest = onRequest
        that.onNodeHTTPRequest = onNodeHTTPRequest
        that.websocket = websocket
        that.reusePort = reusePort
        that.id = id
        that.allowHot = allowHot
        that.ipv6Only = ipv6Only
        that.http3 = http3
        that.http1 = http1
        that.isNodeHttp = isNodeHttp
        that.hadRoutesObject = hadRoutesObject
        that.staticRoutes = staticRoutes
        that.negativeRoutes = negativeRoutes
        that.userRoutesToBuild = userRoutesToBuild
        that.bake = bake

        that.normalizeStaticRoutesList()

        // 清空当前对象的拥有字段 (匹配 Zig 的 null 行为)
        address = AddressConfig.Tcp(TcpAddress(0, None))
        baseUri = ""
        sslConfig = None
        sni = ArrayList<SslConfig>()
        onError = None
        onRequest = None
        onNodeHTTPRequest = None
        websocket = None
        id = ""
        staticRoutes = ArrayList<StaticRouteEntry>()
        negativeRoutes = ArrayList<String>()
        userRoutesToBuild = ArrayList<UserRouteBuilder>()
        bake = None

        return that
    }
}

/// SSL 配置 (简化占位)
/// 对应 Bun: pub const SSLConfig = @import("../socket/SSLConfig.zig")
/// Rust: pub use crate::socket::ssl_config::SSLConfig
public class SslConfig {
    public var certPath: String
    public var keyPath: String
    public var serverName: String

    public init() {
        certPath = ""
        keyPath = ""
        serverName = ""
    }
}

/* Duplicate: WebSocketServerContext is defined in websocket_server_context.cj
/// WebSocket 服务器上下文 (占位)
/// 对应 Bun: ?WebSocketServerContext
/// Rust: Option<WebSocketServerContext>
public class WebSocketServerContext {
    public init() {}
}
*/

/// Bake 用户选项 (占位)
/// 对应 Bun: ?bake.UserOptions
/// Rust: Option<crate::bake::UserOptions>
public class BakeUserOptions {
    public init() {}
}

/* Duplicate: ErrorHandler is defined in request_context.cj
/// 错误处理回调类型
public type ErrorHandler = (error: BaoError) -> Response
*/

// ========================================================================
// Response / Request 类型定义 (引用 bao_http)
// ========================================================================

/// HTTP 响应
/// 在运行时上下文中使用，实际实现在 bao_http 中
public class Response {
    public var status: Int64
    public var statusText: String
    public var headers: HashMap<String, String>
    public var body: ?Array<UInt8>
    public var isStreamBody: Bool

    public init() {
        status = 200
        statusText = "OK"
        headers = HashMap<String, String>()
        body = None
        isStreamBody = false
    }

    public init(status: Int64, statusText: String) {
        this.status = status
        this.statusText = statusText
        this.headers = HashMap<String, String>()
        this.body = None
        this.isStreamBody = false
    }

    public func readBodyChunk(size: Int64): ?Array<UInt8> {
        match (body) {
            case Some(b) =>
                if (b.size == 0) {
                    return None
                }
                return Some(b)
            case None => None
        }
    }

    public func size(): Int64 {
        match (body) {
            case Some(b) => b.size
            case None => 0
        }
    }
}

/// HTTP 请求
public class Request {
    public var method: HttpMethod
    public var path: String
    public var headers: HashMap<String, String>
    public var body: ?Array<UInt8>

    public init(method: HttpMethod, path: String) {
        this.method = method
        this.path = path
        this.headers = HashMap<String, String>()
        this.body = None
    }
}

/// HTTP 方法
/// 对应 Bun: HTTP.Method
/// Rust: bun_http_types::Method::Method
public enum HttpMethod {
    | GET
    | POST
    | PUT
    | DELETE
    | HEAD
    | OPTIONS
    | PATCH
    | CONNECT
    | TRACE
    | ANY

    public static func fromString(s: String): HttpMethod {
        let upper = s.toRuneArray().map({ r => r.toAsciiUpperCase() })
        if (upper == "GET") { return HttpMethod.GET }
        if (upper == "POST") { return HttpMethod.POST }
        if (upper == "PUT") { return HttpMethod.PUT }
        if (upper == "DELETE") { return HttpMethod.DELETE }
        if (upper == "HEAD") { return HttpMethod.HEAD }
        if (upper == "OPTIONS") { return HttpMethod.OPTIONS }
        if (upper == "PATCH") { return HttpMethod.PATCH }
        if (upper == "CONNECT") { return HttpMethod.CONNECT }
        if (upper == "TRACE") { return HttpMethod.TRACE }
        if (upper == "ANY") { return HttpMethod.ANY }
        return HttpMethod.GET
    }

    /// 是否有 body
    /// 对应 Bun: pub fn hasBody(`this`: Method) bool
    /// Rust: impl Method { pub fn has_body(self) -> bool }
    public func hasBody(): Bool {
        match (this) {
            case HttpMethod.GET => false
            case HttpMethod.HEAD => false
            case HttpMethod.DELETE => false
            case HttpMethod.OPTIONS => false
            case HttpMethod.TRACE => false
            case _ => true
        }
    }

    /// 获取方法名字符串
    public func asStr(): String {
        match (this) {
            case GET => "GET"
            case POST => "POST"
            case PUT => "PUT"
            case DELETE => "DELETE"
            case HEAD => "HEAD"
            case OPTIONS => "OPTIONS"
            case PATCH => "PATCH"
            case CONNECT => "CONNECT"
            case TRACE => "TRACE"
            case ANY => "ANY"
        }
    }

    public func name(): String { asStr() }

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
            case "ANY" => HttpMethod.ANY
            case _ => None
        }
    }
}

/// 请求处理回调类型
public type RequestHandler = (request: Request) -> Response

/* Duplicate: BaoError is defined in request_context.cj
/// BaoError 类型 (server_config 中也需要定义)
public class BaoError {
    public var message: String
    public var code: Int64

    public init() {
        message = ""
        code = 0
    }

    public init(message: String) {
        this.message = message
        this.code = 0
    }
}
*/
