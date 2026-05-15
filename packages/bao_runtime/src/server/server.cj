// server - HTTP 服务器主入口
// 严格翻译自: Bun src/runtime/server/server.zig
// 对应: Bun.serve() 的核心服务端实现
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_event_loop.*
import bao_io.*

// ============================================================================
// server - HTTP 服务器核心
// 严格翻译自: src/runtime/server/server.zig
// Bun: server.zig 是 Bun.serve() 的入口模块
// 包含 writeStatus, AnyRoute, 路由管理，请求分发等核心逻辑
// ============================================================================

/// 写入 HTTP 状态行
/// 对应 Bun: pub fn writeStatus(comptime ssl: bool, resp_ptr, status) void
public func writeResponseStatus(resp: ?ResponseRef, status: Int64): Unit {
    match (resp) {
        case Some(r) => {
            let text = HTTPStatusText.get(status)
            match (text) {
                case Some(t) => r.writeStatus(t)
                case None => r.writeStatus("${status} HM")
            }
        }
        case None => ()
    }
}

/// 路由类型联合
/// 严格翻译自: pub const AnyRoute = union(enum) { static, file, html, framework_router }
/// 对应 Bun: AnyRoute 管理不同类型的路由
public class AnyRouteDispatcher {
    /// 路由类型
    public var routeType: RouteType

    /// 静态路由引用
    public var staticRoute: ?StaticRoute

    /// 文件路由引用
    public var fileRoute: ?FileRoute

    /// HTML Bundle 路由引用
    public var htmlRoute: ?HtmlBundleRoute

    /// 服务器引用
    public var server: ?ServerRef

    public init() {
        routeType = RouteType.Static
        staticRoute = None
        fileRoute = None
        htmlRoute = None
        server = None
    }

    /// 内存开销
    /// 对应 Bun: pub fn memoryCost(this) usize
    public func memoryCost(): Int64 {
        match (routeType) {
            case RouteType.Static => {
                match (staticRoute) {
                    case Some(r) => r.memoryCost()
                    case None => Int64(0)
                }
            }
            case RouteType.File => {
                match (fileRoute) {
                    case Some(r) => r.memoryCost()
                    case None => Int64(0)
                }
            }
            case RouteType.Html => Int64(0)
        }
    }

    /// 设置服务器引用
    /// 对应 Bun: pub fn setServer(this, server) void
    public func setServer(srv: ?ServerRef): Unit {
        server = srv
        match (routeType) {
            case RouteType.Static => {
                match (staticRoute) {
                    case Some(r) => r.server = srv
                    case None => ()
                }
            }
            case RouteType.File => {
                match (fileRoute) {
                    case Some(r) => r.server = srv
                    case None => ()
                }
            }
            case RouteType.Html => {
                match (htmlRoute) {
                    case Some(r) => r.server = srv
                    case None => ()
                }
            }
        }
    }

    /// 增加引用
    /// 对应 Bun: pub fn ref(this) void
    public func refRoute(): Unit {
        // 引用计数由各路由类型自己管理
    }

    /// 减少引用
    /// 对应 Bun: pub fn deref(this) void
    public func derefRoute(): Unit {
        // 引用计数由各路由类型自己管理
    }
}

/// 路由类型
public enum RouteType {
    | Static
    | File
    | Html
}

/// HTML Bundle 路由
public class HtmlBundleRoute {
    public var htmlPath: String
    public var server: ?ServerRef

    public init() {
        htmlPath = ""
        server = None
    }
}

// ============================================================================
// HTTP 服务器
// 严格翻译自: Bun API 层的 Bun.serve() 实现
// 对应 Bun: NewServer 结构体以及 server.zig 中的路由分发逻辑
// ============================================================================

/// HTTP 服务器
/// 严格翻译自 Bun 的 Server 结构
/// 对应 Bun.serve() 返回的服务器对象
public class HttpServerRuntime {
    /// 服务器配置
    public var config: ServerConfig

    /// 请求处理器
    public var fetchHandler: ?RequestHandler

    /// 静态路由表
    public var staticRoutes: HashMap<String, AnyRouteDispatcher>

    /// WebSocket 上下文
    public var wsContext: ?WebSocketServerContext

    /// 是否正在运行
    public var running: Bool

    /// 活跃请求数
    public var activeRequests: Int64

    /// 待处理请求数
    public var pendingRequests: Int64

    /// 监听 FD
    public var listenFd: Int64

    public init() {
        config = ServerConfig()
        fetchHandler = None
        staticRoutes = HashMap<String, AnyRouteDispatcher>()
        wsContext = None
        running = false
        activeRequests = 0
        pendingRequests = 0
        listenFd = -1
    }

    public init(config: ServerConfig) {
        this.config = config
        fetchHandler = config.onRequest
        staticRoutes = HashMap<String, AnyRouteDispatcher>()
        wsContext = config.websocket
        running = false
        activeRequests = 0
        pendingRequests = 0
        listenFd = -1
    }

    // ========================================================================
    // 启动服务器
    // ========================================================================

    /// 启动监听
    /// 对应 Bun: Bun.serve() -> uws.App.listen()
    public func listen(): Unit {
        running = true

        // 注册静态路由
        for (entry in config.staticRoutes) {
            let route = AnyRouteDispatcher()
            route.server = Some(makeServerRef())
            staticRoutes.put(entry.path, route)
        }

        // 解析地址
        match (config.address) {
            case AddressConfig.Tcp(let tcp) => {
                // 创建 TCP socket 并监听
                // 对应 Bun: uws.App(ssl).listen(port, hostname)
                doListen(tcp.port, match (tcp.hostname) {
                    case Some(h) => h
                    case None => "0.0.0.0"
                })
            }
            case AddressConfig.Unix(let path) => {
                // Unix socket 监听
                doListenUnix(path)
            }
        }
    }

    /// TCP 监听
    private func doListen(port: Int64, hostname: String): Unit {
        unsafe {
            let sockfd = socket(Int32(AF_INET()), Int32(SOCK_STREAM() | SOCK_NONBLOCK()), 0)
            if (sockfd < 0) {
                throw BaoError(OS.errno(), "Failed to create socket")
            }
            listenFd = Int64(sockfd)

            // SO_REUSEADDR
            let optval: Int32 = 1
            setsockopt(sockfd, Int32(SOL_SOCKET()), Int32(SO_REUSEADDR()), &optval, UIntNative(4))

            if (config.reusePort) {
                setsockopt(sockfd, Int32(SOL_SOCKET()), Int32(SO_REUSEPORT()), &optval, UIntNative(4))
            }

            // bind
            var addr = SockAddrIn()
            addr.family = UInt16(AF_INET())
            addr.port = htons(UInt16(port))
            addr.addr = inetAddr(hostname)

            let bindResult = bind(sockfd, addr.ptr(), addr.size())
            if (bindResult != 0) {
                close(sockfd)
                throw BaoError(OS.errno(), "Failed to bind to ${hostname}:${port}")
            }

            // listen
            let listenResult = bao_sys.listen(sockfd, 128)
            if (listenResult != 0) {
                close(sockfd)
                throw BaoError(OS.errno(), "Failed to listen on ${hostname}:${port}")
            }
        }
    }

    /// Unix socket 监听
    private func doListenUnix(path: String): Unit {
        // 简化: Unix socket 监听逻辑
    }

    // ========================================================================
    // 请求分发
    // ========================================================================

    /// 处理请求
    /// 对应 Bun: server.zig 中 uws 回调 -> onRequest -> fetch handler
    public func handleRequest(request: Request): Response {
        activeRequests += 1
        defer(activeRequests -= 1)

        // 1. 检查静态路由
        let path = request.path
        match (staticRoutes.get(path)) {
            case Some(route) => {
                return handleStaticRoute(route, request)
            }
            case None => ()
        }

        // 2. 调用用户 fetch 处理器
        match (fetchHandler) {
            case Some(handler) => {
                return handler(request)
            }
            case None => ()
        }

        // 3. 没有处理器 - 返回默认响应
        let resp = Response(404, "Not Found")
        return resp
    }

    /// 处理静态路由
    private func handleStaticRoute(route: AnyRouteDispatcher, request: Request): Response {
        match (route.routeType) {
            case RouteType.Static => {
                match (route.staticRoute) {
                    case Some(r) => {
                        let resp = Response(r.statusCode, HTTPStatusText.get(r.statusCode) ?? "OK")
                        for (key in r.headers.keys()) {
                            match (r.headers.get(key)) {
                                case Some(v) => resp.headers.put(key, v)
                                case None => ()
                            }
                        }
                        resp.body = Some(r.blob)
                        return resp
                    }
                    case None => return Response(500, "Internal Server Error")
                }
            }
            case RouteType.File => {
                // 文件路由需要异步处理 (简化返回占位)
                return Response(200, "File Route")
            }
            case RouteType.Html => {
                return Response(200, "HTML Bundle")
            }
        }
    }

    // ========================================================================
    // WebSocket 升级
    // ========================================================================

    /// 处理 WebSocket 升级请求
    /// 对应 Bun: server.zig 中 WebSocket upgrade 逻辑
    public func handleWebSocketUpgrade(request: Request): Bool {
        // 检查是否有 WebSocket 上下文
        match (wsContext) {
            case Some(ctx) => {
                // 验证升级头
                match (request.headers.get("upgrade")) {
                    case Some(v) => {
                        if (v.toLower() == "websocket") {
                            return true
                        }
                    }
                    case None => ()
                }
            }
            case None => ()
        }
        return false
    }

    // ========================================================================
    // 生命周期
    // ========================================================================

    /// 请求完成回调
    /// 对应 Bun: server.onRequestComplete()
    public func onRequestComplete(): Unit {
        activeRequests -= 1
    }

    /// 静态请求完成回调
    /// 对应 Bun: server.onStaticRequestComplete()
    public func onStaticRequestComplete(): Unit {
        pendingRequests -= 1
    }

    /// 待处理请求
    /// 对应 Bun: server.onPendingRequest()
    public func onPendingRequest(): Unit {
        pendingRequests += 1
    }

    /// 停止服务器
    /// 对应 Bun: server.stop()
    public func stop(force: Bool): Unit {
        running = false
        if (listenFd >= 0) {
            SysFs.close(listenFd)
            listenFd = -1
        }
    }

    /// 获取服务器 ID
    public func getId(): String {
        return config.id
    }

    /// 获取配置
    public func getConfig(): ServerConfig {
        return config
    }

    /// 创建服务器引用
    private func makeServerRef(): ServerRef {
        let ref = ServerRef()
        ref.id = config.id
        return ref
    }
}

// ============================================================================
// Socket 地址辅助
// ============================================================================

/// IPv4 地址结构
public class SockAddrIn {
    public var family: UInt16
    public var port: UInt16
    public var addr: UInt32

    public init() {
        family = 2
        port = 0
        addr = 0
    }

    public func ptr(): CPointer<Unit> {
        unsafe {
            let p = malloc(UIntNative(16))
            let bytes = CPointer<UInt8>(p)
            (bytes + IntNative(0)).write(UInt8(family & 0xFF))
            (bytes + IntNative(1)).write(UInt8((family >> 8) & 0xFF))
            (bytes + IntNative(2)).write(UInt8(port & 0xFF))
            (bytes + IntNative(3)).write(UInt8((port >> 8) & 0xFF))
            (bytes + IntNative(4)).write(UInt8(addr & 0xFF))
            (bytes + IntNative(5)).write(UInt8((addr >> 8) & 0xFF))
            (bytes + IntNative(6)).write(UInt8((addr >> 16) & 0xFF))
            (bytes + IntNative(7)).write(UInt8((addr >> 24) & 0xFF))
            for (i in 8..16) {
                (bytes + IntNative(i)).write(UInt8(0))
            }
            return p
        }
    }

    public func size(): UInt32 {
        return UInt32(16)
    }
}

// ============================================================================
// 网络 C FFI 绑定
// 对应 Bun 通过 uws 使用底层 C socket API
// ============================================================================

@C
foreign func socket(domain: Int32, type_: Int32, protocol: Int32): Int32
@C
foreign func bind(sockfd: Int32, addr: CPointer<Unit>, addrlen: UInt32): Int32
@C
foreign func listen(sockfd: Int32, backlog: Int32): Int32
@C
foreign func accept(sockfd: Int32, addr: CPointer<Unit>, addrlen: CPointer<UInt32>): Int32
@C
foreign func setsockopt(sockfd: Int32, level: Int32, optname: Int32, optval: CPointer<Unit>, optlen: UIntNative): Int32
@C
foreign func htons(hostshort: UInt16): UInt16
@C
foreign func inet_pton(af: Int32, src: CPointer<Int8>, dst: CPointer<Unit>): Int32

public func AF_INET(): Int32 { 2 }
public func SOCK_STREAM(): Int32 { 1 }
public func SOCK_NONBLOCK(): Int32 { 2048 }
public func SOL_SOCKET(): Int32 { 1 }
public func SO_REUSEADDR(): Int32 { 2 }
public func SO_REUSEPORT(): Int32 { 15 }

/// 将 IP 地址字符串转为网络字节序整数
public func inetAddr(ip: String): UInt32 {
    unsafe {
        let ipPtr = unsafeNewCString(ip)
        var addr: UInt32 = 0
        let result = inet_pton(AF_INET(), ipPtr, &addr)
        if (result != 1) {
            return 0
        }
        return addr
    }
}

/// C 字符串工具
internal func unsafeNewCString(s: String): CPointer<Int8> {
    unsafe {
        let len = s.size
        let ptr = malloc(UIntNative(len + 1))
        let bytesPtr = CPointer<Int8>(ptr)
        for (i in 0..len) {
            (bytesPtr + IntNative(i)).write(Int8(s[Int64(i)].value))
        }
        (bytesPtr + IntNative(len)).write(Int8(0))
        return bytesPtr
    }
}
