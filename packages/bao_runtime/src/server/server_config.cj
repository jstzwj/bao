// ServerConfig - HTTP 服务器配置
// 严格翻译自: Bun src/runtime/server/ServerConfig.zig
// 对应: Bun.serve() 的配置选项
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_sys.*

// ============================================================================
// ServerConfig - HTTP 服务器配置
// 严格翻译自: src/runtime/server/ServerConfig.zig
// Bun: const ServerConfig = @This();
// 包含地址、端口、SSL、WebSocket、路由等所有配置
// ============================================================================

/// 开发模式选项
/// 对应 Bun: pub const DevelopmentOption = enum { development, production, development_without_hmr }
public enum DevelopmentOption {
    | Development
    | Production
    | DevelopmentWithoutHmr

    /// 是否启用 HMR (热模块替换)
    /// 对应 Bun: pub fn isHMREnabled(this: DevelopmentOption) bool
    public func isHMREnabled(): Bool {
        match (this) {
            case Development => true
            case DevelopmentWithoutHmr => false
            case Production => false
        }
    }

    /// 是否为开发模式
    /// 对应 Bun: pub fn isDevelopment(this: DevelopmentOption) bool
    public func isDevelopment(): Bool {
        match (this) {
            case Development | DevelopmentWithoutHmr => true
            case Production => false
        }
    }
}

/// 地址配置 - TCP 或 Unix Socket
/// 对应 Bun: address: union(enum) { tcp: struct { port, hostname }, unix: [:0]const u8 }
public enum AddressConfig {
    | Tcp(TcpAddress)
    | Unix(String)
}

/// TCP 地址配置
/// 对应 Bun: struct { port: u16 = 0, hostname: ?[*:0]const u8 = null }
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
/// 对应 Bun: method: union(enum) { any: void, specific: HTTP.Method }
public enum RouteMethod {
    | Any
    | Specific(String)   // HTTP 方法名: GET, POST, PUT, DELETE 等
}

/// 静态路由条目
/// 对应 Bun: pub const StaticRouteEntry = struct { path, route, method }
public class StaticRouteEntry {
    public var path: String
    public var route: ?AnyRoute
    public var method: HttpMethodSet

    public init(path: String) {
        this.path = path
        this.route = None
        this.method = HttpMethodSet()
    }

    /// 对应 Bun: pub fn memoryCost(this: *const StaticRouteEntry) usize
    public func memoryCost(): Int64 {
        return path.size
    }
}

/// HTTP 方法集合 - 用于标记路由支持的 HTTP 方法
/// 对应 Bun: HTTP.Method.Optional
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

/// AnyRoute 占位符 - 路由类型联合
/// 对应 Bun: pub const AnyRoute = union(enum) { static, file, html, framework_router }
public enum AnyRoute {
    | Static(StaticRouteRef)
    | File(FileRouteRef)
    | Html(HtmlBundleRouteRef)
}

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

/// 服务器引用占位
public class ServerRef {
    public var id: String

    public init() {
        id = ""
    }
}

/// HTTP 服务器配置
/// 严格翻译自: src/runtime/server/ServerConfig.zig
/// 对应 Bun: const ServerConfig = @This()
/// 这是 Bun.serve() 接受的完整配置对象
public class ServerConfig {
    // ========================================================================
    // 地址配置
    // 严格翻译自: address: union(enum) { tcp: ..., unix: ... }
    // ========================================================================

    /// 监听地址 - TCP 或 Unix Socket
    /// 对应 Bun: address: union(enum) { tcp, unix }
    public var address: AddressConfig

    // ========================================================================
    // 超时与大小限制
    // ========================================================================

    /// 空闲超时 (秒) - 对应 Bun: idleTimeout: u8 = 10
    public var idleTimeout: Int64

    /// 是否显式设置了 idleTimeout
    /// 对应 Bun: has_idleTimeout: bool = false
    public var hasIdleTimeout: Bool

    /// 最大请求体大小 - 对应 Bun: max_request_body_size: usize = 1024 * 1024 * 128
    public var maxRequestBodySize: Int64

    // ========================================================================
    // 开发与生产模式
    // ========================================================================

    /// 开发模式选项
    /// 对应 Bun: development: DevelopmentOption = .development
    public var development: DevelopmentOption

    /// 是否向服务器广播浏览器控制台日志
    /// 对应 Bun: broadcast_console_log_from_browser_to_server_for_bake: bool = false
    public var broadcastConsoleLogFromBrowser: Bool

    /// 是否启用 Chrome DevTools 自动工作区文件夹
    /// 对应 Bun: enable_chrome_devtools_automatic_workspace_folders: bool = true
    public var enableChromeDevtoolsAutoWorkspace: Bool

    // ========================================================================
    // 回调处理器
    // ========================================================================

    /// 错误处理回调 - 对应 Bun: onError: jsc.JSValue
    public var onError: ?ErrorHandler

    /// fetch 请求处理回调 - 对应 Bun: onRequest: jsc.JSValue
    public var onRequest: ?RequestHandler

    /// Node HTTP 请求处理回调 - 对应 Bun: onNodeHTTPRequest: jsc.JSValue
    public var onNodeHTTPRequest: ?RequestHandler

    // ========================================================================
    // WebSocket 配置
    // ========================================================================

    /// WebSocket 服务器上下文
    /// 对应 Bun: websocket: ?WebSocketServerContext = null
    public var websocket: ?WebSocketServerContext

    // ========================================================================
    // 网络选项
    // ========================================================================

    /// 端口复用 - 对应 Bun: reuse_port: bool = false
    public var reusePort: Bool

    /// 服务器 ID - 对应 Bun: id: []const u8 = ""
    public var id: String

    /// 允许热更新 - 对应 Bun: allow_hot: bool = true
    public var allowHot: Bool

    /// 仅 IPv6 - 对应 Bun: ipv6_only: bool = false
    public var ipv6Only: Bool

    /// HTTP/3 支持 - 对应 Bun: http3: bool = false
    public var http3: Bool

    /// HTTP/1 支持 - 对应 Bun: http1: bool = true
    public var http1: Bool

    // ========================================================================
    // Node.js 兼容
    // ========================================================================

    /// 是否为 Node HTTP 模式 - 对应 Bun: is_node_http: bool = false
    public var isNodeHttp: Bool

    /// 是否有路由对象 - 对应 Bun: had_routes_object: bool = false
    public var hadRoutesObject: Bool

    // ========================================================================
    // 路由配置
    // ========================================================================

    /// 静态路由列表
    /// 对应 Bun: static_routes: std.array_list.Managed(StaticRouteEntry)
    public var staticRoutes: ArrayList<StaticRouteEntry>

    /// 排除路由列表
    /// 对应 Bun: negative_routes: std.array_list.Managed([:0]const u8)
    public var negativeRoutes: ArrayList<String>

    /// 用户路由构建器列表
    /// 对应 Bun: user_routes_to_build: std.array_list.Managed(UserRouteBuilder)
    public var userRoutesToBuild: ArrayList<UserRouteBuilder>

    // ========================================================================
    // URL 配置
    // ========================================================================

    /// 基础 URL - 对应 Bun: base_url: URL = URL{}
    public var baseUrl: String

    /// 基础 URI - 对应 Bun: base_uri: string = ""
    public var baseUri: String

    /// SSL 配置 (占位)
    /// 对应 Bun: ssl_config: ?SSLConfig = null
    public var sslConfig: ?SslConfig

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
        baseUrl = ""
        baseUri = ""
        sslConfig = None
    }

    // ========================================================================
    // 方法
    // ========================================================================

    /// 是否为开发模式
    /// 对应 Bun: pub fn isDevelopment(this: *const ServerConfig) bool
    public func isDevelopment(): Bool {
        return development.isDevelopment()
    }

    /// 内存开销估算
    /// 对应 Bun: pub fn memoryCost(this: *const ServerConfig) usize
    public func memoryCost(): Int64 {
        var cost: Int64 = 0
        for (entry in staticRoutes) {
            cost += entry.memoryCost()
        }
        cost += id.size
        cost += baseUrl.size
        for (route in negativeRoutes) {
            cost += route.size
        }
        return cost
    }

    /// 添加静态路由
    /// 对应 Bun: pub fn appendStaticRoute(this: *ServerConfig, path, route, method)
    public func appendStaticRoute(path: String, route: ?AnyRoute, method: HttpMethodSet): Unit {
        let entry = StaticRouteEntry(path)
        entry.route = route
        entry.method = method
        staticRoutes.append(entry)
    }

    /// 生成服务器 ID
    /// 对应 Bun: pub fn computeID(this: *const ServerConfig, allocator) []const u8
    public func computeID(): String {
        let sb = StringBuilder()
        sb.append("[http]-")

        match (address) {
            case AddressConfig.Tcp(let tcp) => {
                match (tcp.hostname) {
                    case Some(host) => {
                        sb.append("tcp:${host}:${tcp.port}")
                    }
                    case None => {
                        sb.append("tcp:localhost:${tcp.port}")
                    }
                }
            }
            case AddressConfig.Unix(let path) => {
                sb.append("unix:${path}")
            }
        }

        return sb.toString()
    }

    /// 获取 socket 选项
    /// 对应 Bun: pub fn getUsocketsOptions(this: *const ServerConfig) i32
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
}

/// SSL 配置 (简化占位)
/// 对应 Bun: pub const SSLConfig = @import("../socket/SSLConfig.zig")
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

/// 错误处理回调类型
public type ErrorHandler = (error: BaoError) -> Response

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
            case Some(b) => {
                if (b.size == 0) {
                    return None
                }
                // 简化: 返回整个 body 作为一块
                return Some(b)
            }
            case None => None
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

    public static func fromString(s: String): HttpMethod {
        let upper = s.toUpper()
        if (upper == "GET") { return HttpMethod.GET }
        if (upper == "POST") { return HttpMethod.POST }
        if (upper == "PUT") { return HttpMethod.PUT }
        if (upper == "DELETE") { return HttpMethod.DELETE }
        if (upper == "HEAD") { return HttpMethod.HEAD }
        if (upper == "OPTIONS") { return HttpMethod.OPTIONS }
        if (upper == "PATCH") { return HttpMethod.PATCH }
        if (upper == "CONNECT") { return HttpMethod.CONNECT }
        if (upper == "TRACE") { return HttpMethod.TRACE }
        return HttpMethod.GET
    }

    /// 是否有 body
    /// 对应 Bun: pub fn hasBody(this: Method) bool
    public func hasBody(): Bool {
        match (this) {
            case HttpMethod.GET | HttpMethod.HEAD | HttpMethod.DELETE | HttpMethod.OPTIONS | HttpMethod.TRACE => false
            case _ => true
        }
    }
}

/// 请求处理回调类型
public type RequestHandler = (request: Request) -> Response
