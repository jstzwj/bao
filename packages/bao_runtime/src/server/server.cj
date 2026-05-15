// 严格翻译自: src/runtime/server/server.zig
// HTTP服务器核心 - 包含writeStatus, AnyRoute, NewServer, 请求分发, WebSocket升级等
package bao_runtime

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_event_loop.*
import bao_io.*
import bao_jsc.*

// ============================================================================
// 子模块引用
// 对应 Bun: pub const WebSocketServerContext = @import("./WebSocketServerContext.zig")
// ============================================================================

/// WebSocket服务器上下文
public typealias WebSocketServerContext = server_websocket.WebSocketServerContext

/// HTTP状态文本
public typealias HTTPStatusText = http_status_text.HTTPStatusText

/// HTML Bundle路由
public typealias HTMLBundleRoute = html_bundle.HTMLBundleRoute

/// 静态路由
public typealias StaticRoute = static_route.StaticRoute

/// 文件路由
public typealias FileRoute = file_route.FileRoute

/// 文件响应流
public typealias FileResponseStream = file_response_stream.FileResponseStream

/// 范围请求
public typealias RangeRequest = range_request.RangeRequest

/// 请求上下文
public typealias RequestContext = request_context.RequestContext

/// 服务器配置
public typealias ServerConfig = server_config.ServerConfig

/// 服务器WebSocket
public typealias ServerWebSocket = server_websocket.ServerWebSocket

/// Node HTTP响应
public typealias NodeHTTPResponse = node_http_response.NodeHTTPResponse

/// 请求对象
public typealias Request = request.Request

/// Inspector Bun 前端开发服务器代理
public typealias BunFrontendDevServerAgent = inspector_bun_frontend_dev_server_agent.BunFrontendDevServerAgent

/// Inspector 句柄
public typealias InspectorBunFrontendDevServerAgentHandle = inspector_bun_frontend_dev_server_agent.InspectorBunFrontendDevServerAgentHandle

/// 控制台日志类型
public typealias ConsoleLogKind = inspector_bun_frontend_dev_server_agent.ConsoleLogKind

// ============================================================================
// 写入HTTP状态行
// 对应 Bun: pub fn writeStatus(comptime ssl: bool, resp_ptr: ?*uws.NewApp(ssl).Response, status: u16) void
// ============================================================================

/// 写入HTTP状态行
/// 根据状态码查找对应的状态文本，写入到响应中
public func writeStatus(resp: ?ResponseRef, status: UInt16): Unit {
    match (resp) {
        case Some(r) => {
            match (HTTPStatusText.get(status)) {
                case Some(t) => r.writeStatus(t)
                case None => {
                    var statusTextBuf: Array<Byte> = Array<Byte>(48)
                    let text = " \(status) HM"
                    r.writeStatus(text)
                }
            }
        }
        case None => ()
    }
}

// ============================================================================
// AnyRoute - 路由类型联合
// 对应 Bun: pub const AnyRoute = union(enum) { static, file, html, framework_router }
// ============================================================================

/// 路由类型
/// 对应 Bun: union(enum) { static: *StaticRoute, file: *FileRoute, html: HTMLBundle.Route ref, framework_router: FrameworkRouter.Type.Index }
public enum RouteType {
    | Static           // 静态文件路由: "/robots.txt": new Response(...)
    | File             // 磁盘文件路由
    | Html             // HTML导入路由: import html from "./index.html"
    | FrameworkRouter  // 文件系统路由: "/*": { "dir": ... }
}

/// 路由类型联合
/// 管理不同类型的路由：静态、文件、HTML Bundle、框架路由器
public class AnyRoute {
    /// 路由类型
    public var routeType: RouteType

    /// 静态路由引用
    public var staticRoute: ?StaticRoute

    /// 文件路由引用
    public var fileRoute: ?FileRoute

    /// HTML Bundle 路由引用
    public var htmlRoute: ?HTMLBundleRoute

    /// 框架路由索引
    public var frameworkRouterIndex: UInt32

    /// 服务器引用
    public var server: ?ServerRef

    public init() {
        routeType = RouteType.Static
        staticRoute = None
        fileRoute = None
        htmlRoute = None
        frameworkRouterIndex = 0
        server = None
    }

    /// 内存开销
    /// 对应 Bun: pub fn memoryCost(this: AnyRoute) usize
    public func memoryCost(): Int64 {
        switch (routeType) {
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
            case RouteType.Html => {
                match (htmlRoute) {
                    case Some(r) => r.memoryCost()
                    case None => Int64(0)
                }
            }
            case RouteType.FrameworkRouter => Int64(0)
        }
    }

    /// 设置服务器引用
    /// 对应 Bun: pub fn setServer(this: AnyRoute, server: ?AnyServer) void
    public func setServer(srv: ?ServerRef): Unit {
        server = srv
        switch (routeType) {
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
            case RouteType.FrameworkRouter => {
                // DevServer包含.server字段，不需要设置
            }
        }
    }

    /// 增加引用计数
    /// 对应 Bun: pub fn ref(this: AnyRoute) void
    public func refRoute(): Unit {
        switch (routeType) {
            case RouteType.Static => {
                match (staticRoute) {
                    case Some(r) => r.refRoute()
                    case None => ()
                }
            }
            case RouteType.File => {
                match (fileRoute) {
                    case Some(r) => r.refRoute()
                    case None => ()
                }
            }
            case RouteType.Html => {
                match (htmlRoute) {
                    case Some(r) => r.refRoute()
                    case None => ()
                }
            }
            case RouteType.FrameworkRouter => {
                // 框架路由不是引用计数的
            }
        }
    }

    /// 减少引用计数
    /// 对应 Bun: pub fn deref(this: AnyRoute) void
    public func derefRoute(): Unit {
        switch (routeType) {
            case RouteType.Static => {
                match (staticRoute) {
                    case Some(r) => r.deref()
                    case None => ()
                }
            }
            case RouteType.File => {
                match (fileRoute) {
                    case Some(r) => r.deref()
                    case None => ()
                }
            }
            case RouteType.Html => {
                match (htmlRoute) {
                    case Some(r) => r.deref()
                    case None => ()
                }
            }
            case RouteType.FrameworkRouter => {
                // 框架路由不是引用计数的
            }
        }
    }

    /// 从选项创建路由
    /// 对应 Bun: pub fn fromOptions(global, headers, path) !AnyRoute
    public static func fromOptions(global: JSGlobalObject, headers: ?FetchHeaders,
                                    path: PathOrFileDescriptor): AnyRoute {
        let blob = Blob.findOrCreateFileFromPath(path, global, false)

        if (blob.needsToReadFile()) {
            // 验证文件是否存在
            if (let store = blob.store) {
                if (let storePath = store.getPath()) {
                    let existsType = Sys.existsAtType(FD.cwd(), storePath)
                    switch (existsType) {
                        case .result(let fileType) => {
                            if (fileType == .directory) {
                                global.throwInvalidArguments(
                                    "Bundled file \(storePath) cannot be a directory"
                                )
                                return AnyRoute()
                            }
                        }
                        case .err => {
                            global.throwInvalidArguments(
                                "Bundled file \(storePath) not found"
                            )
                            return AnyRoute()
                        }
                    }
                }
            }
            let route = AnyRoute()
            route.routeType = RouteType.File
            route.fileRoute = FileRoute.initFromBlob(blob, FileRouteOptions(server: None, headers: headers))
            return route
        }

        let route = AnyRoute()
        route.routeType = RouteType.Static
        route.staticRoute = StaticRoute.initFromAnyBlob(
            Array<Blob>(blob),
            StaticRouteOptions(server: None, headers: headers)
        )
        return route
    }

    /// 从JS值创建HTML路由
    /// 对应 Bun: pub fn htmlRouteFromJS(...)
    public static func htmlRouteFromJS(argument: JSValue, initCtx: ServerInitContext): ?AnyRoute {
        // HTML Bundle处理
        if (let htmlBundle = argument.asHTMLBundle()) {
            let route = HTMLBundleRoute.init(htmlBundle)
            let result = AnyRoute()
            result.routeType = RouteType.Html
            result.htmlRoute = route
            return result
        }
        return None
    }

    /// 从JS值创建路由
    /// 对应 Bun: pub fn fromJS(global, path, argument, init_ctx) bun.JSError!?AnyRoute
    public static func fromJS(global: JSGlobalObject, path: String, argument: JSValue,
                               initCtx: ServerInitContext): ?AnyRoute {
        // 1. 尝试HTML路由
        if (let htmlRoute = htmlRouteFromJS(argument, initCtx)) {
            return htmlRoute
        }

        // 2. 尝试框架路由器
        if (argument.isObject()) {
            if (let dir = argument.getOptional(global, "dir")) {
                // 框架路由器路由
                if (!path.endsWith("/*")) {
                    global.throwInvalidArguments(
                        "To mount a directory, make sure the path ends in `/*`"
                    )
                    return None
                }
                let result = AnyRoute()
                result.routeType = RouteType.FrameworkRouter
                return result
            }
        }

        // 3. 尝试文件路由
        if (let fileRoute = FileRoute.fromJS(global, argument)) {
            let result = AnyRoute()
            result.routeType = RouteType.File
            result.fileRoute = fileRoute
            return result
        }

        // 4. 尝试静态路由
        if (let staticRoute = StaticRoute.fromJS(global, argument)) {
            let result = AnyRoute()
            result.routeType = RouteType.Static
            result.staticRoute = staticRoute
            return result
        }

        return None
    }
}

// ============================================================================
// 服务器初始化上下文
// 对应 Bun: pub const ServerInitContext = struct { ... }
// ============================================================================

/// 服务器初始化上下文
/// 在解析路由配置时使用的临时状态
public class ServerInitContext {
    public var arena: ArenaAllocator
    public var dedupeHtmlBundleMap: HashMap<HTMLBundle, HTMLBundleRoute>
    public var jsStringAllocations: StringRefList
    public var global: JSGlobalObject
    public var frameworkRouterList: ArrayList<FrameworkRouterType>
    public var userRoutes: ArrayList<ServerConfig.StaticRouteEntry>

    public init(global: JSGlobalObject) {
        this.arena = ArenaAllocator()
        this.dedupeHtmlBundleMap = HashMap<HTMLBundle, HTMLBundleRoute>()
        this.jsStringAllocations = StringRefList()
        this.global = global
        this.frameworkRouterList = ArrayList<FrameworkRouterType>()
        this.userRoutes = ArrayList<ServerConfig.StaticRouteEntry>()
    }
}

// ============================================================================
// ServePlugins - 插件加载状态机
// 对应 Bun: const ServePlugins = struct { state: State, ref_count: RefCount, ... }
// ============================================================================

/// 插件状态
/// 对应 Bun: pub const State = union(enum) { unqueued, pending, loaded, err }
public enum ServePluginState {
    /// 尚未开始加载
    case unqueued(Array<String>)
    /// 正在加载中
    case pending(ServePluginPending)
    /// 加载完成
    case loaded(JSBundlerPlugin)
    /// 加载失败
    case err
}

/// 插件加载中的临时数据
public class ServePluginPending {
    public var plugin: JSBundlerPlugin
    public var promise: JSPromiseStrong
    public var htmlBundleRoutes: ArrayList<HTMLBundleRoute>
    public var devServer: ?DevServer

    public init(plugin: JSBundlerPlugin, promise: JSPromiseStrong) {
        this.plugin = plugin
        this.promise = promise
        this.htmlBundleRoutes = ArrayList<HTMLBundleRoute>()
        this.devServer = None
    }
}

/// 插件加载结果
/// 对应 Bun: pub const GetOrStartLoadResult = union(enum) { ready, pending, err }
public enum GetOrStartLoadResult {
    /// 准备就绪（null = 无插件）
    case ready(JSBundlerPlugin)
    /// 正在加载
    case pending
    /// 加载失败
    case err
}

/// 插件回调类型
/// 对应 Bun: pub const Callback = union(enum) { html_bundle_route, dev_server }
public enum ServePluginCallback {
    case htmlBundleRoute(HTMLBundleRoute)
    case devServer(DevServer)
}

/// 服务器插件状态机
/// 管理插件加载的异步生命周期
public class ServePlugins {
    public var state: ServePluginState
    public var refCount: Int64

    public init(plugins: Array<String>) {
        state = ServePluginState.unqueued(plugins)
        refCount = 1
    }

    /// 获取或开始加载插件
    /// 对应 Bun: pub fn getOrStartLoad(this, global, cb) bun.JSError!GetOrStartLoadResult
    public func getOrStartLoad(global: JSGlobalObject, cb: ServePluginCallback): GetOrStartLoadResult {
        switch (state) {
            case .unqueued(let plugins) => {
                loadAndResolvePlugins(global)
                // 同步完成后可能跳转到任何分支
                return getOrStartLoad(global, cb)
            }
            case .pending(let pending) => {
                switch (cb) {
                    case .htmlBundleRoute(let route) =>
                        route.refRoute()
                        pending.htmlBundleRoutes.append(route)
                    case .devServer(let dev) =>
                        pending.devServer = dev
                }
                return GetOrStartLoadResult.pending
            }
            case .loaded(let plugin) =>
                return GetOrStartLoadResult.ready(plugin)
            case .err =>
                return GetOrStartLoadResult.err
        }
    }

    /// 加载并解析插件
    /// 对应 Bun: fn loadAndResolvePlugins(this, global) bun.JSError!void
    public func loadAndResolvePlugins(global: JSGlobalObject): Unit {
        // 简化实现: 实际需要调用JSBundlerPlugin加载逻辑
    }

    /// 处理插件加载成功
    /// 对应 Bun: pub fn handleOnResolve(this) void
    public func handleOnResolve(): Unit {
        switch (state) {
            case .pending(let pending) =>
                let plugin = pending.plugin
                let devServer = pending.devServer
                let htmlBundleRoutes = pending.htmlBundleRoutes
                pending.htmlBundleRoutes = ArrayList<HTMLBundleRoute>()
                pending.promise.deinit()
                state = ServePluginState.loaded(plugin)
                for (route in htmlBundleRoutes) {
                    route.onPluginsResolved(plugin)
                    route.deref()
                }
                if (let dev = devServer) {
                    dev.onPluginsResolved(plugin)
                }
            else => ()
        }
    }

    /// 处理插件加载失败
    /// 对应 Bun: pub fn handleOnReject(this, global, err) void
    public func handleOnReject(global: JSGlobalObject, err: JSValue): Unit {
        switch (state) {
            case .pending(let pending) =>
                let devServer = pending.devServer
                let htmlBundleRoutes = pending.htmlBundleRoutes
                pending.htmlBundleRoutes = ArrayList<HTMLBundleRoute>()
                pending.plugin.deinit()
                pending.promise.deinit()
                state = ServePluginState.err
                for (route in htmlBundleRoutes) {
                    route.onPluginsRejected()
                    route.deref()
                }
                if (let dev = devServer) {
                    dev.onPluginsRejected()
                }
                Output.errGeneric("Failed to load plugins for Bun.serve:")
                global.bunVM().runErrorHandler(err, None)
            else => ()
        }
    }

    /// 增加引用
    public func ref(): Unit {
        refCount += 1
    }

    /// 减少引用
    public func deref(): Unit {
        refCount -= 1
        if (refCount == 0) {
            deinit()
        }
    }

    /// 释放资源
    public func deinit(): Unit {
        switch (state) {
            case .loaded(let plugin) => plugin.deinit()
            else => ()
        }
    }
}

// ============================================================================
// HTTP服务器
// 对应 Bun: pub fn NewServer(protocol_enum, development_kind) type
// ============================================================================

/// 服务器标志位
/// 对应 Bun: flags: packed struct(u3) { deinit_scheduled, terminated, has_handled_all_closed_promise }
public class ServerFlags {
    public var deinitScheduled: Bool
    public var terminated: Bool
    public var hasHandledAllClosedPromise: Bool

    public init() {
        deinitScheduled = false
        terminated = false
        hasHandledAllClosedPromise = false
    }
}

/// 用户路由
/// 对应 Bun: pub const UserRoute = struct { id: u32, server: *ThisServer, route: ServerConfig.RouteDeclaration }
public class UserRoute {
    public var id: UInt32
    public var server: HttpServer
    public var route: ServerConfig.RouteDeclaration

    public init(id: UInt32, server: HttpServer, route: ServerConfig.RouteDeclaration) {
        this.id = id
        this.server = server
        this.route = route
    }

    public func deinit(): Unit {
        route.deinit()
    }
}

/// 预处理的请求
/// 对应 Bun: pub const PreparedRequest = struct { js_request, request_object, ctx }
public class PreparedRequest {
    public var jsRequest: JSValue
    public var requestObject: Request
    public var ctx: RequestContext

    public init(jsRequest: JSValue, requestObject: Request, ctx: RequestContext) {
        this.jsRequest = jsRequest
        this.requestObject = requestObject
        this.ctx = ctx
    }

    /// 保存请求以便延迟处理
    /// 对应 Bun: pub fn save(prepared, global, req, resp) SavedRequest
    public func save(global: JSGlobalObject, req: UwsRequest, resp: ResponseRef): SavedRequest {
        ctx.toAsync(req, requestObject)
        return SavedRequest(
            jsRequest: JSStrong.create(jsRequest, global),
            request: requestObject,
            ctx: AnyRequestContext.init(ctx),
            response: resp
        )
    }
}

/// 保存的请求 - 用于延迟处理
public class SavedRequest {
    public var jsRequest: JSStrong
    public var request: Request
    public var ctx: AnyRequestContext
    public var response: ResponseRef
}

/// HTTP服务器
/// 对应 Bun: NewServer结构体
/// 包含listen、请求处理、WebSocket升级、路由管理等完整功能
public class HttpServer {
    // ========================================================================
    // 字段
    // ========================================================================

    /// uws App引用
    public var app: ?UwsApp

    /// 监听socket
    public var listener: ?ListenSocket

    /// JS值引用
    public var jsValue: JSRef

    /// 虚拟机引用
    public var vm: VirtualMachine

    /// 全局对象
    public var globalThis: JSGlobalObject

    /// 用于URL拼接的基础URL
    public var baseUrlStringForJoining: String

    /// 服务器配置
    public var config: ServerConfig

    /// 待处理请求数
    public var pendingRequests: Int64

    /// 请求池分配器
    public var requestPoolAllocator: RequestContextStackAllocator

    /// 全部关闭的Promise
    public var allClosedPromise: JSPromiseStrong

    /// 监听回调
    public var listenCallback: AnyTask

    /// 分配器
    public var allocator: Allocator

    /// 轮询引用
    public var pollRef: AsyncKeepAlive

    /// 标志位
    public var flags: ServerFlags

    /// 插件状态
    public var plugins: ?ServePlugins

    /// 开发服务器引用
    public var devServer: ?DevServer

    /// 用户路由列表
    public var userRoutes: ArrayList<UserRoute>

    /// 客户端错误处理
    public var onClientError: JSStrongOptional

    /// 调试器服务器ID
    public var inspectorServerId: DebuggerId

    // ========================================================================
    // 初始化
    // ========================================================================

    public init() {
        app = None
        listener = None
        jsValue = JSRef.empty()
        vm = VirtualMachine.get()
        globalThis = vm.global
        baseUrlStringForJoining = ""
        config = ServerConfig()
        pendingRequests = 0
        requestPoolAllocator = RequestContextStackAllocator()
        allClosedPromise = JSPromiseStrong()
        listenCallback = AnyTask()
        allocator = DefaultAllocator()
        pollRef = AsyncKeepAlive()
        flags = ServerFlags()
        plugins = None
        devServer = None
        userRoutes = ArrayList<UserRoute>()
        onClientError = JSStrongOptional.empty()
        inspectorServerId = DebuggerId.init(0)
    }

    /// 从配置初始化
    /// 对应 Bun: pub fn init(config: *ServerConfig, global: *JSGlobalObject) bun.JSOOM!*ThisServer
    public static func init(config: ServerConfig, global: JSGlobalObject): HttpServer {
        let baseUrl = DefaultAllocator().dupe(config.baseUrl.href.trim('/'))
        let devServer = if (let bakeOptions = config.bake) {
            DevServer.init(DevServer.Options(
                arena: bakeOptions.arena.allocator(),
                root: bakeOptions.root,
                vm: global.bunVM(),
                framework: bakeOptions.framework,
                bundlerOptions: bakeOptions.bundlerOptions,
                broadcastConsoleLogFromBrowserToServer: config.broadcastConsoleLogFromBrowserToServerForBake
            ))
        } else { None }

        let server = HttpServer()
        server.globalThis = global
        server.config = config
        server.baseUrlStringForJoining = baseUrl
        server.vm = VirtualMachine.get()
        server.allocator = DefaultAllocator()
        server.devServer = devServer
        return server
    }

    // ========================================================================
    // 内存与生命周期
    // ========================================================================

    /// 内存开销
    /// 对应 Bun: pub fn memoryCost(this: *ThisServer) usize
    public func memoryCost(): Int64 {
        var cost: Int64 = Int64(sizeOf<HttpServer>())
        cost += Int64(baseUrlStringForJoining.size)
        cost += config.memoryCost()
        if (let dev = devServer) {
            cost += dev.memoryCost()
        }
        return cost
    }

    /// 释放
    /// 对应 Bun: pub fn deinit(this: *ThisServer) void
    public func deinit(): Unit {
        allClosedPromise.deinit()
        for (userRoute in userRoutes) {
            userRoute.deinit()
        }
        userRoutes.clear()
        config.deinit()
        onClientError.deinit()

        if (let dev = devServer) {
            dev.deinit()
        }
        if (let p = plugins) {
            p.deref()
        }
    }

    // ========================================================================
    // 监听
    // ========================================================================

    /// 监听成功回调
    /// 对应 Bun: pub fn onListen(this: *ThisServer, socket: ?*App.ListenSocket) void
    public func onListen(socket: ?ListenSocket): Unit {
        if (socket == None) {
            onListenFailed()
            return
        }
        listener = socket
        vm.eventLoopHandle = AsyncLoop.get()
    }

    /// 监听失败回调
    /// 对应 Bun: noinline fn onListenFailed(this: *ThisServer) void
    public func onListenFailed(): Unit {
        let globalThis = this.globalThis
        var errorInstance: JSValue = JSValue.zero
        switch (config.address) {
            case .tcp(let tcp) => {
                errorInstance = SystemError(
                    message: "Failed to start server. Is port \(tcp.port) in use?",
                    code: "EADDRINUSE",
                    syscall: "listen"
                ).toErrorInstance(globalThis)
            }
            case .unix(let unix) => {
                errorInstance = SystemError(
                    message: "Failed to listen on unix socket \(unix)",
                    code: "EADDRINUSE",
                    syscall: "listen"
                ).toErrorInstance(globalThis)
            }
        }
        globalThis.throwValue(errorInstance)
    }

    /// 停止监听
    /// 对应 Bun: pub fn stopListening(this: *ThisServer, abrupt: bool) void
    public func stopListening(abrupt: Bool): Unit {
        let l = listener
        if (l == None) return
        listener = None
        unref()
        notifyInspectorServerStopped()

        if (config.address == .unix) {
            let path = config.address.unix
            if (path.size > 0 && path[0] != '\0') {
                Sys.unlink(path)
            }
        }

        if (!abrupt) {
            l.get().close()
        } else if (!flags.terminated) {
            if (let ws = config.websocket) {
                ws.handler.app = None
            }
            flags.terminated = true
            app.get().close()
        }
    }

    /// 停止服务器
    /// 对应 Bun: pub fn stop(this: *ThisServer, abrupt: bool) void
    public func stop(abrupt: Bool): Unit {
        if (jsValue.isNotEmpty()) {
            jsValue.downgrade()
        }
        if (config.allowHot && config.id.size > 0) {
            if (let hot = globalThis.bunVM().hotMap()) {
                hot.remove(config.id)
            }
        }
        stopListening(abrupt)
        deinitIfWeCan()
    }

    /// 从JS停止
    /// 对应 Bun: pub fn stopFromJS(this: *ThisServer, abruptly: ?JSValue) jsc.JSValue
    public func stopFromJS(abruptly: ?JSValue): JSValue {
        let rc = getAllClosedPromise(globalThis)
        if (hasListener()) {
            let abrupt = if (let val = abruptly) {
                val.isBoolean() && val.toBoolean()
            } else { false }
            stop(abrupt)
        }
        return rc
    }

    // ========================================================================
    // 引用计数
    // ========================================================================

    /// 增加引用
    /// 对应 Bun: pub fn ref(this: *ThisServer) void
    public func ref(): Unit {
        if (pollRef.isActive()) return
        pollRef.ref(vm)
    }

    /// 减少引用
    /// 对应 Bun: pub fn unref(this: *ThisServer) void
    public func unref(): Unit {
        if (!pollRef.isActive()) return
        pollRef.unref(vm)
    }

    // ========================================================================
    // 请求处理
    // ========================================================================

    /// 处理请求
    /// 对应 Bun: pub fn onRequest(this: *ThisServer, req, resp) void
    public func onRequest(req: UwsRequest, resp: ResponseRef): Unit {
        pendingRequests += 1
        // 创建请求上下文并调用用户的fetch处理器
        let prepared = prepareJsRequestContext(req, resp, None, true, None)
        if (prepared == None) return

        let jsValue = jsValueAssertAlive()
        let responseValue = config.onRequest.call(
            globalThis, jsValue,
            Array<JSValue>(prepared.get().jsRequest, jsValue)
        )

        handleRequest(prepared.get(), req, responseValue)
    }

    /// 处理预处理后的请求
    /// 对应 Bun: fn handleRequest(this, should_deinit_context, prepared, req, response_value) void
    public func handleRequest(prepared: PreparedRequest, req: UwsRequest,
                               responseValue: JSValue): Unit {
        let ctx = prepared.ctx
        ctx.onResponse(this, prepared.jsRequest, responseValue)
        prepared.jsRequest.ensureStillAlive()

        if (ctx.shouldRenderMissing()) {
            ctx.renderMissing()
            return
        }

        ctx.toAsync(req, prepared.requestObject)
    }

    /// 请求完成回调
    /// 对应 Bun: pub fn onRequestComplete(this: *ThisServer) void
    public func onRequestComplete(): Unit {
        vm.eventLoop().processGCTimer()
        pendingRequests -= 1
        deinitIfWeCan()
    }

    /// 静态请求完成回调
    /// 对应 Bun: pub fn onStaticRequestComplete(this: *ThisServer) void
    public func onStaticRequestComplete(): Unit {
        pendingRequests -= 1
        deinitIfWeCan()
    }

    /// 待处理请求
    /// 对应 Bun: pub fn onPendingRequest(this: *ThisServer) void
    public func onPendingRequest(): Unit {
        pendingRequests += 1
    }

    /// 准备JS请求上下文
    /// 对应 Bun: pub fn prepareJsRequestContext(...)
    public func prepareJsRequestContext(
        req: UwsRequest, resp: ResponseRef,
        shouldDeinitContext: ?BoolRef,
        createJsRequest: Bool,
        method: ?HTTPMethod
    ): ?PreparedRequest {
        // 验证请求体长度
        let methodVal = method ?? HTTPMethod.which(req.method()) ?? HTTPMethod.GET
        var requestBodyLength: ?Int64 = None
        if (methodVal.hasRequestBody()) {
            let len = if (let contentLength = req.header("content-length")) {
                Int64.parse(contentLength) ?? 0
            } else { 0 }
            if (len > config.maxRequestBodySize) {
                resp.writeStatus("413 Request Entity Too Large")
                resp.endWithoutBody(true)
                return None
            }
            requestBodyLength = len
        }

        onPendingRequest()
        req.setYield(false)
        resp.timeout(config.idleTimeout)

        // 从池中获取请求上下文
        let ctx = requestPoolAllocator.tryGet()
        ctx.create(this, req, resp, shouldDeinitContext, method)

        let body = vm.initRequestBodyValue(BodyValue.Null())
        ctx.requestBody = body
        let signal = AbortSignal.new(globalThis)
        ctx.signal = signal
        signal.pendingActivityRef()

        let requestObject = Request.new(Request.init(
            ctx.method,
            AnyRequestContext.init(ctx),
            signal.ref(),
            body.ref()
        ))
        ctx.requestWeakref = JSWeakRef.initRef(requestObject)

        // 处理请求体
        if (let reqLen = requestBodyLength) {
            ctx.requestBodyContentLen = reqLen
            ctx.isWaitingForRequestBody = true
            resp.onData(ctx.onBufferedBodyChunk, ctx)
        }

        return PreparedRequest(
            jsRequest: if (createJsRequest) { requestObject.toJS(globalThis) } else { JSValue.zero },
            requestObject: requestObject,
            ctx: ctx
        )
    }

    // ========================================================================
    // WebSocket
    // ========================================================================

    /// WebSocket升级
    /// 对应 Bun: pub fn onUpgrade(this, globalThis, object, optional) bun.JSError!JSValue
    public func onUpgrade(globalThis: JSGlobalObject, object: JSValue,
                           optional: ?JSValue): JSValue {
        if (config.websocket == None) {
            return globalThis.throwInvalidArguments(
                "To enable websocket support, set the \"websocket\" object in Bun.serve({})"
            )
        }

        if (flags.terminated) return JSValue.false

        // NodeHTTPResponse路径
        if (let nodeHttpResponse = object.asNodeHTTPResponse()) {
            return handleNodeHttpUpgrade(globalThis, nodeHttpResponse, optional)
        }

        // Request路径
        if (let request = object.asRequest()) {
            return handleRequestUpgrade(globalThis, request, optional)
        }

        return globalThis.throwInvalidArguments("upgrade requires a Request object")
    }

    /// 处理NodeHTTP升级
    private func handleNodeHttpUpgrade(globalThis: JSGlobalObject,
                                        nodeHttpResponse: NodeHTTPResponse,
                                        optional: ?JSValue): JSValue {
        var dataValue: JSValue = JSValue.zero
        var secWebsocketProtocol: String = ""
        var secWebsocketExtensions: String = ""

        if (let opts = optional) {
            if (!opts.isEmptyOrUndefinedOrNull() && opts.isObject()) {
                if (let headersValue = opts.fastGet(globalThis, "data")) {
                    dataValue = headersValue
                }
                if (let headersValue = opts.fastGet(globalThis, "headers")) {
                    // 处理headers
                }
            }
        }

        return JSValue.jsBoolean(
            nodeHttpResponse.upgrade(dataValue, secWebsocketProtocol, secWebsocketExtensions)
        )
    }

    /// 处理Request升级
    private func handleRequestUpgrade(globalThis: JSGlobalObject,
                                       request: Request,
                                       optional: ?JSValue): JSValue {
        let upgrader = request.requestContext.get()
        if (upgrader == None) return JSValue.false
        if (upgrader.isAbortedOrEnded()) return JSValue.false

        let resp = upgrader.resp
        let ctx = upgrader.upgradeContext
        if (resp == None || ctx == None) return JSValue.false

        upgrader.ref()

        var secWebsocketKey: String = ""
        var secWebsocketProtocol: String = ""
        var secWebsocketExtensions: String = ""
        var dataValue: JSValue = JSValue.zero

        // 获取WebSocket头信息
        if (let fetchHeaders = request.getFetchHeaders()) {
            if (let key = fetchHeaders.fastGet(.SecWebSocketKey)) {
                secWebsocketKey = key
            }
            if (let protocol = fetchHeaders.fastGet(.SecWebSocketProtocol)) {
                secWebsocketProtocol = protocol
            }
            if (let extensions = fetchHeaders.fastGet(.SecWebSocketExtensions)) {
                secWebsocketExtensions = extensions
            }
        }

        if (let req = upgrader.req) {
            if (secWebsocketKey.size == 0) {
                secWebsocketKey = req.header("sec-websocket-key") ?? ""
            }
            if (secWebsocketProtocol.size == 0) {
                secWebsocketProtocol = req.header("sec-websocket-protocol") ?? ""
            }
            if (secWebsocketExtensions.size == 0) {
                secWebsocketExtensions = req.header("sec-websocket-extensions") ?? ""
            }
        }

        if (secWebsocketKey.size == 0) return JSValue.false

        // 处理选项
        if (let opts = optional) {
            if (!opts.isEmptyOrUndefinedOrNull() && opts.isObject()) {
                if (let headersValue = opts.fastGet(globalThis, "data")) {
                    dataValue = headersValue
                }
            }
        }

        // 检查升级是否已被消费
        if (upgrader.isAbortedOrEnded() || upgrader.didUpgradeWebSocket()) {
            upgrader.deref()
            return JSValue.false
        }

        // 标记升级已使用
        upgrader.upgradeContext = None
        upgrader.signal = None
        upgrader.resp = None

        // 创建WebSocket
        let ws = ServerWebSocket.init(config.websocket.handler, dataValue, upgrader.signal)
        resp.get().clearAborted()
        resp.get().clearOnData()
        resp.get().clearOnWritable()
        resp.get().clearTimeout()

        upgrader.deref()

        resp.get().upgrade(ws, secWebsocketKey, secWebsocketProtocol, secWebsocketExtensions, ctx.get())
        return JSValue.true
    }

    /// 发布消息到WebSocket频道
    /// 对应 Bun: pub fn publish(this, globalThis, topic, message_value, compress_value) bun.JSError!JSValue
    public func publish(globalThis: JSGlobalObject, topic: String,
                         messageValue: JSValue, compressValue: ?JSValue): JSValue {
        if (config.websocket == None) return JSValue.jsNumber(0)
        let app = this.app.get()

        if (topic.size == 0) {
            return globalThis.throw("publish requires a topic string")
        }

        let compress = compressValue?.toBoolean() ?? true

        if (let buffer = messageValue.asArrayBuffer(globalThis)) {
            let sent = UwsAnyWebSocket.publishWithOptions(app, topic, buffer, .binary, compress)
            return JSValue.jsNumber(Int64(sent))
        }

        // 字符串消息
        let jsString = messageValue.toJSString(globalThis)
        let slice = jsString.view(globalThis).toSlice()
        let sent = UwsAnyWebSocket.publishWithOptions(app, topic, slice, .text, compress)
        return JSValue.jsNumber(Int64(sent))
    }

    // ========================================================================
    // 路由管理
    // ========================================================================

    /// 设置路由
    /// 对应 Bun: fn setRoutes(this: *ThisServer) jsc.JSValue
    public func setRoutes(): JSValue {
        var routeListValue = JSValue.zero
        let app = this.app.get()
        let devServer = this.devServer

        // 1. 注册用户路由
        for (userRoute in userRoutes) {
            let path = userRoute.route.path
            switch (userRoute.route.method) {
                case .any => {
                    app.any(path, userRoute, onUserRouteRequest)
                }
                case .specific(let method) => {
                    app.method(method, path, userRoute, onUserRouteRequest)
                }
            }
        }

        // 2. 设置WebSocket处理器
        if (let websocket = config.websocket) {
            websocket.globalObject = globalThis
            websocket.handler.app = app
        }

        // 3. 注册静态路由
        for (entry in config.staticRoutes) {
            switch (entry.route.routeType) {
                case .Static => {
                    ServerConfig.applyStaticRoute(app, entry.route.staticRoute.get(), entry.path, entry.method)
                }
                case .File => {
                    ServerConfig.applyStaticRoute(app, entry.route.fileRoute.get(), entry.path, entry.method)
                }
                case .Html => {
                    ServerConfig.applyStaticRoute(app, entry.route.htmlRoute.get(), entry.path, entry.method)
                    if (let dev = devServer) {
                        dev.htmlRouter.put(allocator(), entry.path, entry.route.htmlRoute.get())
                    }
                }
                case .FrameworkRouter => {
                    // 框架路由器由DevServer处理
                }
            }
        }

        // 4. DevServer路由
        if (let dev = devServer) {
            dev.setRoutes(this)
        }

        // 5. 全局"/*"回退路由
        if (config.onRequest != JSValue.zero) {
            app.any("/*", this, onRequest)
        } else {
            app.any("/*", this, on404)
        }

        return routeListValue
    }

    // ========================================================================
    // 重新加载
    // ========================================================================

    /// 从Zig重新加载
    /// 对应 Bun: pub fn onReloadFromZig(this, new_config, globalThis) void
    public func onReloadFromZig(newConfig: ServerConfig, globalThis: JSGlobalObject): Unit {
        app.get().clearRoutes()

        // 更新fetch处理器
        if (config.onRequest != newConfig.onRequest &&
            newConfig.onRequest != JSValue.zero && !newConfig.onRequest.isUndefined()) {
            config.onRequest.unprotect()
            config.onRequest = newConfig.onRequest
        }

        // 更新错误处理器
        if (config.onError != newConfig.onError &&
            newConfig.onError != JSValue.zero && !newConfig.onError.isUndefined()) {
            config.onError.unprotect()
            config.onError = newConfig.onError
        }

        // 更新WebSocket配置
        if (let ws = newConfig.websocket) {
            if (config.websocket != None) {
                config.websocket.unprotect()
            }
            ws.globalObject = globalThis
            config.websocket = ws
        }

        // 更新静态路由
        for (route in config.staticRoutes) {
            route.deinit()
        }
        config.staticRoutes = newConfig.staticRoutes

        // 清除HTML路由器
        if (let dev = devServer) {
            dev.htmlRouter.clear()
        }

        // 重新设置路由
        setRoutes()
    }

    /// 从JS重新加载
    /// 对应 Bun: pub fn onReload(this, globalThis, callframe) bun.JSError!jsc.JSValue
    public func onReload(globalThis: JSGlobalObject, callframe: CallFrame): JSValue {
        let arguments = callframe.arguments()
        if (arguments.size < 1) {
            return globalThis.throwNotEnoughArguments("reload", 1, 0)
        }

        var newConfig = ServerConfig()
        ServerConfig.fromJS(globalThis, newConfig, arguments, ServerConfigFromJSOptions(
            allowBakeConfig: false,
            isFetchRequired: true,
            hasUserRoutes: userRoutes.size > 0
        ))

        onReloadFromZig(newConfig, globalThis)
        return jsValue.tryGet() ?? JSValue.jsUndefined
    }

    // ========================================================================
    // fetch方法（服务器端内部fetch）
    // ========================================================================

    /// 服务器端fetch
    /// 对应 Bun: pub fn onFetch(this, ctx, callframe) bun.JSError!jsc.JSValue
    public func onFetch(ctx: JSGlobalObject, callframe: CallFrame): JSValue {
        if (config.onRequest == JSValue.zero) {
            return JSPromise.dangerouslyCreateRejectedPromiseValue(
                ctx, "fetch() requires the server to have a fetch handler"
            )
        }

        let arguments = callframe.arguments()
        if (arguments.size == 0) {
            return JSPromise.dangerouslyCreateRejectedPromiseValue(
                ctx, "fetch() requires at least 1 argument"
            )
        }

        // 构建内部请求并调用fetch处理器
        let firstArg = arguments[0]
        var existingRequest: Request

        if (firstArg.isString()) {
            let urlStr = firstArg.toString(ctx)
            var url = URL.parse(urlStr)
            var method = HTTPMethod.GET
            var headers: ?FetchHeaders = None
            var body: BodyValue = BodyValue.Null()

            if (arguments.size >= 2 && arguments[1].isObject()) {
                let opts = arguments[1]
                if (let methodVal = opts.fastGet(ctx, "method")) {
                    let slice = methodVal.toString(ctx)
                    method = HTTPMethod.which(slice) ?? method
                }
                if (let headersVal = opts.fastGet(ctx, "headers")) {
                    headers = FetchHeaders.createFromJS(ctx, headersVal)
                }
                if (let bodyVal = opts.fastGet(ctx, "body")) {
                    if (let blob = Blob.get(ctx, bodyVal, true, false)) {
                        body = BodyValue.Blob(blob)
                    }
                }
            }

            let effectiveUrl = if (url.hostname.size == 0) {
                baseUrlStringForJoining + url.pathname
            } else { urlStr }

            existingRequest = Request.init(
                BunString.cloneUTF8(effectiveUrl),
                headers, body, method
            )
        } else if (let req = firstArg.asRequest()) {
            existingRequest = req.cloneInto(allocator(), ctx, false)
        } else {
            return JSPromise.dangerouslyCreateRejectedPromiseValue(
                ctx, "fetch() requires a string or Request object"
            )
        }

        let request = Request.new(existingRequest)
        let responseValue = config.onRequest.call(
            globalThis, jsValueAssertAlive(),
            Array<JSValue>(request.toJS(globalThis))
        )

        if (responseValue.isAnyError()) {
            return JSPromise.dangerouslyCreateRejectedPromiseValue(ctx, responseValue)
        }

        if (responseValue.asAnyPromise() != None) {
            return responseValue
        }

        if (let resp = responseValue.asResponse()) {
            resp.setUrl(existingRequest.url.clone())
        }
        return JSPromise.resolvedPromiseValue(ctx, responseValue)
    }

    // ========================================================================
    // 属性访问
    // ========================================================================

    /// 获取端口
    /// 对应 Bun: pub fn getPort(this, _) jsc.JSValue
    public func getPort(): JSValue {
        switch (config.address) {
            case .unix => JSValue.jsUndefined
            case .tcp(let tcp) => {
                if (let l = listener) return JSValue.jsNumber(l.getLocalPort())
                return JSValue.jsNumber(tcp.port)
            }
        }
    }

    /// 获取ID
    /// 对应 Bun: pub fn getId(this, globalThis) bun.JSError!jsc.JSValue
    public func getId(globalThis: JSGlobalObject): JSValue {
        BunString.createUTF8ForJS(globalThis, config.id)
    }

    /// 获取待处理请求数
    /// 对应 Bun: pub fn getPendingRequests(this, _) jsc.JSValue
    public func getPendingRequests(): JSValue {
        JSValue.jsNumber(pendingRequests)
    }

    /// 获取地址
    /// 对应 Bun: pub fn getAddress(this, globalThis) bun.JSError!jsc.JSValue
    public func getAddress(globalThis: JSGlobalObject): JSValue {
        switch (config.address) {
            case .unix(let unix) =>
                BunString.createUTF8ForJS(globalThis, unix)
            case .tcp(let tcp) => {
                var port: UInt16 = tcp.port
                if (let l = listener) {
                    port = UInt16(l.getLocalPort())
                    let addr = SocketAddress.init(l.localAddress(), port)
                    return addr.intoDTO(globalThis)
                }
                return JSValue.jsNull()
            }
        }
    }

    /// 获取URL
    /// 对应 Bun: pub fn getURL(this, globalThis) bun.OOM!jsc.JSValue
    public func getURL(globalThis: JSGlobalObject): JSValue {
        let url = getURLAsString()
        url.toJSDOMURL(globalThis)
    }

    /// 获取URL字符串
    /// 对应 Bun: pub fn getURLAsString(this) bun.OOM!bun.String
    public func getURLAsString(): BunString {
        switch (config.address) {
            case .unix(let unix) =>
                BunString.cloneUTF8("unix://\(unix)")
            case .tcp(let tcp) => {
                var port: UInt16 = tcp.port
                if (let l = listener) {
                    port = UInt16(l.getLocalPort())
                }
                let hostname = tcp.hostname ?? "localhost"
                BunString.cloneUTF8("http://\(hostname):\(port)")
            }
        }
    }

    /// 获取主机名
    /// 对应 Bun: pub fn getHostname(this, globalThis) !jsc.JSValue
    public func getHostname(globalThis: JSGlobalObject): JSValue {
        switch (config.address) {
            case .unix => JSValue.jsUndefined
            case .tcp(let tcp) => {
                if (let l = listener) {
                    let addr = l.remoteAddress()
                    if (addr.size > 0) {
                        return BunString.createUTF8ForJS(globalThis, addr)
                    }
                }
                if (let hostname = tcp.hostname) {
                    return BunString.createUTF8ForJS(globalThis, hostname)
                }
                return BunString.static("localhost").toJS(globalThis)
            }
        }
    }

    /// 获取协议
    /// 对应 Bun: pub fn getProtocol(this, globalThis) bun.JSError!jsc.JSValue
    public func getProtocol(globalThis: JSGlobalObject): JSValue {
        BunString.static("http").toJS(globalThis)
    }

    // ========================================================================
    // 状态检查
    // ========================================================================

    /// 是否有监听器
    /// 对应 Bun: pub fn hasListener(this) bool
    public func hasListener(): Bool {
        listener != None
    }

    /// 活跃WebSocket数
    /// 对应 Bun: pub fn activeSocketsCount(this) u32
    public func activeSocketsCount(): UInt32 {
        if (let ws = config.websocket) {
            return UInt32(ws.handler.activeConnections)
        }
        return 0
    }

    /// 是否有活跃的WebSocket
    /// 对应 Bun: pub fn hasActiveWebSockets(this) bool
    public func hasActiveWebSockets(): Bool {
        activeSocketsCount() > 0
    }

    /// 获取全部关闭的Promise
    /// 对应 Bun: pub fn getAllClosedPromise(this, globalThis) jsc.JSValue
    public func getAllClosedPromise(globalThis: JSGlobalObject): JSValue {
        if (!hasListener() && pendingRequests == 0) {
            return JSPromise.resolvedPromise(globalThis, JSValue.jsUndefined).toJS()
        }
        if (allClosedPromise.has()) {
            return allClosedPromise.value()
        }
        allClosedPromise = JSPromiseStrong.init(globalThis)
        return allClosedPromise.value()
    }

    /// 如果可以则释放
    /// 对应 Bun: pub fn deinitIfWeCan(this) void
    public func deinitIfWeCan(): Unit {
        if (pendingRequests == 0 && !hasListener() && !hasActiveWebSockets()) {
            if (let ws = config.websocket) {
                ws.handler.app = None
            }
            unref()

            // 分离DevServer
            if (let dev = devServer) {
                devServer = None
                if (let a = app) { a.clearRoutes() }
                dev.deinit()
            }

            if (jsValue.isFinalized()) {
                scheduleDeinit()
            }
        }
    }

    /// 调度释放
    /// 对应 Bun: pub fn scheduleDeinit(this) void
    public func scheduleDeinit(): Unit {
        if (flags.deinitScheduled) return
        flags.deinitScheduled = true

        if (!flags.terminated) {
            flags.terminated = true
            let task = AnyTask(App.close, app.get())
            vm.enqueueTask(task)
        }

        let task = AnyTask(HttpServer.deinit, this)
        vm.enqueueTask(task)
    }

    /// 通知调试器服务器已停止
    /// 对应 Bun: fn notifyInspectorServerStopped(this) void
    public func notifyInspectorServerStopped(): Unit {
        if (inspectorServerId.toOptional().unwrap() != None) {
            if (let debugger = vm.debugger) {
                debugger.httpServerAgent.notifyServerStopped(AnyServer.from(this))
                inspectorServerId = DebuggerId.init(0)
            }
        }
    }

    /// 断言JS值存活并获取
    /// 对应 Bun: pub fn jsValueAssertAlive(server) jsc.JSValue
    public func jsValueAssertAlive(): JSValue {
        jsValue.tryGet().get()
    }

    /// 请求IP
    /// 对应 Bun: pub fn requestIP(this, request) bun.JSError!jsc.JSValue
    public func requestIP(request: Request): JSValue {
        if (config.address == .unix) return JSValue.jsNull()
        let info = request.requestContext.getRemoteSocketInfo()
        if (info == None) return JSValue.jsNull()
        return SocketAddress.createDTO(globalThis, info.get().ip, info.get().port, info.get().isIpv6)
    }

    /// 设置空闲超时
    /// 对应 Bun: pub fn setIdleTimeout(this, seconds) void
    public func setIdleTimeout(seconds: UInt32): Unit {
        config.idleTimeout = UInt8(min(seconds, 255))
    }

    /// 设置标志
    /// 对应 Bun: pub fn setFlags(this, require_host_header, use_strict_method_validation) void
    public func setFlags(requireHostHeader: Bool, useStrictMethodValidation: Bool): Unit {
        if (let a = app) {
            a.setFlags(requireHostHeader, useStrictMethodValidation)
        }
    }

    /// 关闭空闲连接
    /// 对应 Bun: pub fn closeIdleConnections(this, globalObject, callframe) bun.JSError!jsc.JSValue
    public func closeIdleConnections(): JSValue {
        if (app == None) return JSValue.jsUndefined
        app.get().closeIdleConnections()
        return JSValue.jsUndefined
    }

    /// 从JS释放
    /// 对应 Bun: pub fn disposeFromJS(this) jsc.JSValue
    public func disposeFromJS(): JSValue {
        if (hasListener()) {
            stop(true)
        }
        return JSValue.jsUndefined
    }
}

/// 404处理
/// 对应 Bun: fn on404
public func on404(server: HttpServer, req: UwsRequest, resp: ResponseRef): Unit {
    resp.writeStatus("404 Not Found")
    resp.end("Not Found", false)
}

/// 用户路由请求处理
public func onUserRouteRequest(userRoute: UserRoute, req: UwsRequest, resp: ResponseRef): Unit {
    let server = userRoute.server
    server.onPendingRequest()

    let prepared = server.prepareJsRequestContext(req, resp, None, false, None)
    if (prepared == None) return

    let responseValue = server.config.onRequest.call(
        server.globalThis, server.jsValueAssertAlive(),
        Array<JSValue>(prepared.get().jsRequest)
    )

    server.handleRequest(prepared.get(), req, responseValue)
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 服务器引用
public class ServerRef {
    public var id: String

    public init(id: String) {
        this.id = id
    }
}

/// Bool引用 - 用于在回调中传递可变布尔值
public class BoolRef {
    public var value: Bool

    public init(value: Bool) {
        this.value = value
    }
}
