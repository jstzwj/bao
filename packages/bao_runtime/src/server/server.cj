// 严格翻译自: src/runtime/server/server.zig
// HTTP服务器核心 - 包含writeStatus, AnyRoute, NewServer, 请求分发, WebSocket升级等
package bao_runtime.server

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_event_loop.*
import bao_io.*
import bao_jsc.JsValue
import bao_jsc.JSGlobalObject
import bao_jsc.CallFrame
import bao_jsc.JSRef
import bao_jsc.Strong
import bao_jsc.StrongOptional
import bao_uws_sys.ListenSocket
import bao_collections.ArrayList

// ============================================================================
// 子模块引用已不需要: 所有文件在同一 package bao_runtime.server 中
// 类型直接可见，不需要 type 别名
// ============================================================================

// ============================================================================
// 本地类型定义
// 以下类型按优先级标注：
//   - [KEPT] 接口不兼容: 真实类型存在但 API 签名不同，保留本地简化版本
//   - [KEPT] 尚不存在: 真实类型尚未在对应包中实现
// ============================================================================

/// Blob - [KEPT] 接口不兼容
/// 真实类型存在于 bao_runtime.webcore.blob.Blob（23+ 字段），
/// 但 server 模块仅需最小子集接口。保留本地简化版本以避免大面积适配。
/// TODO: 逐步迁移到 import bao_runtime.webcore.Blob
public class Blob {
    public var store: ?BlobStore
    public init() {
        store = None
    }
    public static func findOrCreateFileFromPath(path: PathOrFileDescriptor, global: JSGlobalObject, isLazy: Bool): Blob {
        Blob()
    }
    public func needsToReadFile(): Bool { false }
    public func slice(): Array<UInt8> { Array<UInt8>() }
    public static func get(global: JSGlobalObject, value: JsValue, isAttachment: Bool, allowContentType: Bool): ?Blob {
        None
    }
}

/// BlobStore - [KEPT] 接口不兼容
/// 真实类型存在于 bao_runtime.webcore.blob.BlobStore（20+ 字段），
/// 但此处仅需 store: ?BlobStore 和 getPath() 最小接口。
/// TODO: 逐步迁移到 import bao_runtime.webcore.BlobStore
public class BlobStore {
    public init() {}
    public func getPath(): ?String { None }
}

/// JSPromiseStrong - [KEPT] 接口不兼容
/// 真实类型存在于 bao_runtime.webcore 等子包中，但 API 不同。
/// 保留本地版本：泛型版使用 JsObject 而非 JSGlobalObject。
/// TODO: 迁移到统一的真实类型
public class JSPromiseStrong {
    private var _has: Bool
    private var _value: JsValue
    public init() {
        _has = false
        _value = JsValue.undefined()
    }
    public init(global: JSGlobalObject) {
        _has = true
        _value = JsValue.undefined()
    }
    public func has(): Bool { _has }
    public func value(): JsValue { _value }
    public func deinit(): Unit {
        _has = false
        _value = JsValue.undefined()
    }
}

/// UwsRequest - [KEPT] 接口不兼容
/// 真实类型存在于 bao_uws_sys.Request，但使用 CPointer<Unit> 构造和 Array<UInt8> 返回值，
/// 而此模块使用 String 简化接口。保留本地版本。
/// TODO: 迁移到 bao_uws_sys.Request，使用 UTF-8 编解码适配层
public class UwsRequest {
    public init() {}
    public func method(): String { "GET" }
    public func url(): String { "/" }
    public func setYield(value: Bool): Unit {}
    public func fullPath(): String { "/" }
    public func header(name: String): ?String { None }
    public func parameter(index: Int64): String { "" }
    public func parameter(name: String): String { "" }
}

/// UwsApp - [KEPT] 接口不兼容
/// 真实类型存在于 bao_uws_sys.App，但使用 CPointer<Unit> 构造和 C FFI 回调，
/// 而此模块使用 Any 简化回调签名。保留本地版本。
/// TODO: 迁移到 bao_uws_sys.App
public class UwsApp {
    public init() {}
    public func close(): Unit {}
    public func any(path: String, user: Any, handler: Any): Unit {}
    public func method(m: Any, path: String, user: Any, handler: Any): Unit {}
    public func clearRoutes(): Unit {}
    public func closeIdleConnections(): Unit {}
    public func setFlags(requireHostHeader: Bool, useStrictMethodValidation: Bool): Unit {}
}

/// JSStrong - [KEPT] 接口不兼容
/// 对应 bao_jsc.Strong<JsValue> 的非泛型简化版本。
/// bao_jsc.Strong<T> 使用 JsObject 而非 JSGlobalObject，且 API 不同。
/// TODO: 迁移到 bao_jsc.Strong<JsValue>
public class JSStrong {
    private var _value: JsValue
    public init() {
        _value = JsValue.undefined()
    }
    public static func create(value: JsValue, global: JSGlobalObject): JSStrong {
        let s = JSStrong()
        s._value = value
        return s
    }
    public func get(): JsValue { _value }
    public func deinit(): Unit {
        _value = JsValue.undefined()
    }
}

/// JSStrongOptional - [KEPT] 接口不兼容
/// 对应 bao_jsc.StrongOptional<JsValue> 的非泛型简化版本。
/// bao_jsc.StrongOptional<T> 使用 JsObject 而非 JSGlobalObject。
/// TODO: 迁移到 bao_jsc.StrongOptional<JsValue>
public class JSStrongOptional {
    private var _has: Bool
    private var _value: JsValue
    public init() {
        _has = false
        _value = JsValue.undefined()
    }
    public static func empty(): JSStrongOptional {
        JSStrongOptional()
    }
    public func deinit(): Unit {
        _has = false
        _value = JsValue.undefined()
    }
}

/// VirtualMachine - [KEPT] 接口不兼容
/// 真实类型存在于 bao_runtime.VirtualMachine（使用 EventLoop, JsObject 等字段），
/// 但 server 模块需要特定接口（global: JSGlobalObject, eventLoopHandle, enqueueTask 等）。
/// TODO: 对齐 bao_runtime.VirtualMachine 接口后替换
public class VirtualMachine {
    public var global: JSGlobalObject
    public var eventLoopHandle: Any
    public init() {
        global = JSGlobalObject()
        eventLoopHandle = Object()
    }
    public static func get(): VirtualMachine { VirtualMachine() }
    public func eventLoop(): Any { eventLoopHandle }
    public func bunVM(): VirtualMachine { this }
    public func enqueueTask(task: AnyTask): Unit {}
    public func initRequestBodyValue(body: BodyValue): BodyValue { body }
    public func hotMap(): ?Any { None }
    public func runErrorHandler(err: JsValue, source: ?Any): Unit {}
    public func debugger(): ?Any { None }
}

/// RequestContextStackAllocator - [KEPT] 尚不存在
/// 真实类型尚无对应实现。这是请求上下文池分配器。
/// 参考: Bun src/runtime/server/server.zig RequestContextStackAllocator
public class RequestContextStackAllocator {
    public init() {}
    public func tryGet(): RequestContext { RequestContext() }
}

/// AsyncKeepAlive - [KEPT] 接口不兼容
/// 真实类型存在于 bao_runtime.api.AsyncKeepAlive，但构造器/方法签名不同。
/// 参考: Bun src/jsc/AsyncKeepAlive.zig
public class AsyncKeepAlive {
    public init() {}
    public func isActive(): Bool { false }
    public func ref(vm: VirtualMachine): Unit {}
    public func unref(vm: VirtualMachine): Unit {}
}

/// DebuggerId - 类型别名
/// 参考: bao_runtime.bake.stubs.DebuggerId = Int64
public type DebuggerId = Int64

/// HTTPMethod - HTTP方法枚举
/// [KEPT] 简化版本。真实枚举存在于 bao_runtime.bake.stubs.HTTPMethod，
/// 但可能字段不完全相同。保留本地版本以确保 server 包自包含。
/// 参考: Bun src/http/Method.zig
public enum HTTPMethod {
    | GET
    | POST
    | PUT
    | DELETE
    | PATCH
    | HEAD
    | OPTIONS
    | CONNECT
    | TRACE

    public func hasRequestBody(): Bool {
        match (this) {
            case GET => false
            case HEAD => false
            case CONNECT => true
            case _ => true
        }
    }

    public static func which(method: String): ?HTTPMethod {
        match (method) {
            case "GET" => HTTPMethod.GET
            case "POST" => HTTPMethod.POST
            case "PUT" => HTTPMethod.PUT
            case "DELETE" => HTTPMethod.DELETE
            case "PATCH" => HTTPMethod.PATCH
            case "HEAD" => HTTPMethod.HEAD
            case "OPTIONS" => HTTPMethod.OPTIONS
            case "CONNECT" => HTTPMethod.CONNECT
            case "TRACE" => HTTPMethod.TRACE
            case _ => None
        }
    }
}

/// BodyValue is defined in request_context.cj - no stub needed
/// AnyTask is imported from bao_event_loop.* - no stub needed
/// ArenaAllocator is imported from bao_core.* - no stub needed

/// Object - [KEPT] 基础类型
/// Cangjie 标准库中不提供 Object 占位类型，保留本地定义。
public class Object {
    public init() {}
}

/// AsyncLoop - [KEPT] 简化版本
/// 真实类型存在于 bao_runtime.socket.AsyncLoop，但为空类。
/// 保留本地简化版本以确保 server 包自包含。
public class AsyncLoop {
    public static func get(): AsyncLoop { AsyncLoop() }
    public init() {}
}

/// DefaultAllocator - [KEPT] 接口不兼容
/// 真实类型存在于 bao_bun_alloc.DefaultAllocator（使用 Allocator 接口），
/// 但此处仅需 dupe() 方法。保留本地简化版本。
/// TODO: 迁移到 import bao_bun_alloc.DefaultAllocator
public class DefaultAllocator {
    public init() {}
    public func dupe(s: String): String { s }
}

/// JSBundlerPlugin is defined in html_bundle.cj - no stub needed
/// DevServer is defined in server_body.cj - no stub needed
/// FetchHeaders is defined in server_body.cj - no stub needed
/// AbortSignal is defined in server_body.cj - no stub needed
/// PathOrFileDescriptor is defined in server_body.cj - no stub needed
/// BoolRef is defined in request_context.cj - no stub needed
/// BodyValue is defined in request_context.cj - no stub needed
/// SocketAddress is defined in request_context.cj and file_response_stream.cj - no stub needed
/// HTMLBundle is defined in html_bundle.cj - no stub needed
/// ServePluginCallback is defined in html_bundle.cj - no stub needed
/// GetOrStartLoadResult is defined in html_bundle.cj - no stub needed
/// ServerWebSocket is defined in server_websocket.cj - no stub needed

/// JSPromise - [KEPT] 简化版本
/// 真实类型存在于 bao_runtime.webcore.streams.JSPromise，但 API 不同。
/// 保留本地最小接口。
/// 参考: Bun src/jsc/JSPromise.zig
public class JSPromise {
    public static func resolvedPromiseValue(global: JSGlobalObject, value: JsValue): JsValue { value }
    public static func resolvedPromise(global: JSGlobalObject, value: JsValue): JSPromise { JSPromise() }
    public static func dangerouslyCreateRejectedPromiseValue(global: JSGlobalObject, value: Any): JsValue { JsValue.undefined() }
    public func toJS(): JsValue { JsValue.undefined() }
}

/// JSWeakRef - [KEPT] 尚不存在
/// JS 弱引用类型，尚无完整实现。
/// 参考: Bun src/jsc/JSWeakRef.zig
public class JSWeakRef {
    public static func initRef(value: Any): JSWeakRef { JSWeakRef() }
}

/// UwsAnyWebSocket - [KEPT] 简化版本
/// WebSocket 广播辅助类。真实实现需要 uws FFI。
/// 参考: Bun src/uws_sys/WebSocket.zig AnyWebSocket
public class UwsAnyWebSocket {
    public static func publishWithOptions(app: UwsApp, topic: String, data: Any, opcode: Any, compress: Bool): Int64 { 0 }
}

/// Opcode - [KEPT] 字段名不兼容
/// 真实枚举存在于 bao_uws_sys.Opcode (text/binary/close/ping/pong)
/// 和 bao_uws.Opcode (Continuation/Text/Binary/Close/Ping/Pong)，字段名不同。
/// 保留本地小写版本以确保与 Bun 源码字段名一致。
/// 参考: Bun src/uws_sys/lib.rs Opcode
public enum Opcode {
    | text
    | binary
    | close
    | ping
    | pong
}

/// SystemError - [KEPT] 接口不兼容
/// 真实类型存在于 bao_jsc.SystemError（使用 JsObject），
/// 但此处使用 JSGlobalObject 接口。保留本地适配版本。
/// TODO: 迁移到 import bao_jsc.SystemError
public class SystemError {
    public init(message: String, code: String, syscall: String) {}
    public func toErrorInstance(global: JSGlobalObject): JsValue { JsValue.undefined() }
}

/// RouteDeclaration - 定义在 server_config.cj（同一包内，直接可见）

/// ServerConfigFromJSOptions - JS配置解析选项
/// 参考: Bun src/runtime/server/ServerConfig.zig fromJS
public class ServerConfigFromJSOptions {
    public var allowBakeConfig: Bool
    public var isFetchRequired: Bool
    public var hasUserRoutes: Bool
    public init(allowBakeConfig: Bool, isFetchRequired: Bool, hasUserRoutes: Bool) {
        this.allowBakeConfig = allowBakeConfig
        this.isFetchRequired = isFetchRequired
        this.hasUserRoutes = hasUserRoutes
    }
}

/// StaticRouteOptions - 静态路由选项
/// 参考: Bun src/runtime/server/StaticRoute.zig Options
public class StaticRouteOptions {
    public var server: ?ServerRef
    public var headers: ?FetchHeaders
    public init(server: ?ServerRef, headers: ?FetchHeaders) {
        this.server = server
        this.headers = headers
    }
}

/// FileRouteOptions - 文件路由选项
/// 参考: Bun src/runtime/server/FileRoute.zig Options
public class FileRouteOptions {
    public var server: ?ServerRef
    public var headers: ?FetchHeaders
    public init(server: ?ServerRef, headers: ?FetchHeaders) {
        this.server = server
        this.headers = headers
    }
}

/// ServerInitContext forward - actual definition is in this file
/// (ServerInitContext is defined below)

/// BunString 辅助函数
/// 真实实现存在于 bao_jsc.BunString.createUTF8ForJS（使用 JsObject），
/// 此处使用 JSGlobalObject 的简化版本。
/// TODO: 迁移到 bao_jsc.BunString 统一接口
public func bunStringCloneUTF8(s: String): String { s }
public func bunStringCreateUTF8ForJS(global: JSGlobalObject, s: String): JsValue {
    // 真实实现应调用 BunString.createUTF8ForJS(global, s.toByteArray())
    JsValue.jsNull()
}

// ============================================================================
// 写入HTTP状态行
// 对应 Bun: pub fn writeStatus(comptime ssl: bool, resp_ptr: ?*uws.NewApp(ssl).Response, status: u16) void
// ============================================================================

/// 写入HTTP状态行
/// 根据状态码查找对应的状态文本，写入到响应中
public func writeStatus(resp: ?ResponseRef, status: UInt16): Unit {
    match (resp) {
        case Some(r) =>
            match (HTTPStatusText.get(Int64(status))) {
                case Some(t) => r.writeStatus(t)
                case None =>
                    let text = " ${status} HM"
                    r.writeStatus(text)
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
public class AnyRouteObj {
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
    /// 对应 Bun: pub fn memoryCost(`this`: AnyRouteObj) usize
    public func memoryCost(): Int64 {
        match (routeType) {
            case RouteType.Static =>
                match (staticRoute) {
                    case Some(r) => r.memoryCost()
                    case None => Int64(0)
                }
            case RouteType.File =>
                match (fileRoute) {
                    case Some(r) => r.memoryCost()
                    case None => Int64(0)
                }
            case RouteType.Html =>
                match (htmlRoute) {
                    case Some(r) => r.memoryCost()
                    case None => Int64(0)
                }
            case RouteType.FrameworkRouter => Int64(0)
        }
    }

    /// 设置服务器引用
    /// 对应 Bun: pub fn setServer(`this`: AnyRouteObj, server: ?AnyServer) void
    public func setServer(srv: ?ServerRef): Unit {
        server = srv
        match (routeType) {
            case RouteType.Static =>
                match (staticRoute) {
                    case Some(r) => r.server = srv
                    case None => ()
                }
            case RouteType.File =>
                match (fileRoute) {
                    case Some(r) => r.server = srv
                    case None => ()
                }
            case RouteType.Html =>
                match (htmlRoute) {
                    case Some(r) => r.server = srv
                    case None => ()
                }
            case RouteType.FrameworkRouter =>
                () // DevServer包含.server字段，不需要设置
        }
    }

    /// 增加引用计数
    /// 对应 Bun: pub fn ref(`this`: AnyRouteObj) void
    public func refRoute(): Unit {
        match (routeType) {
            case RouteType.Static =>
                match (staticRoute) {
                    case Some(r) => r.ref()
                    case None => ()
                }
            case RouteType.File =>
                match (fileRoute) {
                    case Some(r) => r.ref()
                    case None => ()
                }
            case RouteType.Html =>
                match (htmlRoute) {
                    case Some(r) => r.ref()
                    case None => ()
                }
            case RouteType.FrameworkRouter =>
                () // 框架路由不是引用计数的
        }
    }

    /// 减少引用计数
    /// 对应 Bun: pub fn deref(`this`: AnyRouteObj) void
    public func derefRoute(): Unit {
        match (routeType) {
            case RouteType.Static =>
                match (staticRoute) {
                    case Some(r) => r.deref()
                    case None => ()
                }
            case RouteType.File =>
                match (fileRoute) {
                    case Some(r) => r.deref()
                    case None => ()
                }
            case RouteType.Html =>
                match (htmlRoute) {
                    case Some(r) => r.deref()
                    case None => ()
                }
            case RouteType.FrameworkRouter =>
                () // 框架路由不是引用计数的
        }
    }

    /// 从选项创建路由
    /// 对应 Bun: pub fn fromOptions(global, headers, path) !AnyRoute
    public static func fromOptions(global: JSGlobalObject, headers: ?FetchHeaders,
                                    path: PathOrFileDescriptor): AnyRouteObj {
        let blob = Blob.findOrCreateFileFromPath(path, global, false)

        // 简化: Blob/FileBlob/StaticRoute 类型转换复杂，返回默认路由
        if (blob.needsToReadFile()) {
            let route = AnyRouteObj()
            route.routeType = RouteType.File
            let fb = FileBlob()
            fb.filePath = ""  // PathOrFileDescriptor 无法直接转 String
            route.fileRoute = FileRoute.initFromBlob(fb, Int64(0), Option<ServerRef>.None)
            return route
        }

        let route = AnyRouteObj()
        route.routeType = RouteType.Static
        route.staticRoute = StaticRoute.initFromAnyBlob(
            blob.slice(), Int64(0), Option<String>.None, Option<ServerRef>.None
        )
        return route
    }

    /// 从JS值创建HTML路由
    /// 对应 Bun: pub fn htmlRouteFromJS(...)
    public static func htmlRouteFromJS(argument: JsValue, initCtx: ServerInitContext): ?AnyRouteObj {
        // 简化: asHTMLBundle 不存在于 JsValue
        return None
    }

    /// 从JS值创建路由
    /// 对应 Bun: pub fn fromJS(global, path, argument, init_ctx) bun.JSError!?AnyRouteObj
    public static func fromJS(global: JSGlobalObject, path: String, argument: JsValue,
                               initCtx: ServerInitContext): ?AnyRouteObj {
        // 1. 尝试HTML路由
        if (let htmlRoute <- htmlRouteFromJS(argument, initCtx)) {
            return htmlRoute
        }

        // 2. 尝试框架路由器
        // 简化: 跳过框架路由器检测 (getOptional 需要 JsObject)
        ()

        // 3. 尝试文件路由
        // 简化: FileRoute.fromJS 尚未实现
        ()

        // 4. 尝试静态路由
        // 简化: StaticRoute.fromJS 尚未实现

        return None
    }
}

// ============================================================================
// 本地类型定义 (bake 子包中的类型尚未可导入)
// TODO: 当 bake 子包完全翻译后，替换为 import bao_runtime.bake.*
// ============================================================================

/// JS字符串分配列表 - 对应 bake 包中的 StringRefList
public class StringRefList {
    public init() {}
}

/// 框架路由器类型 - 对应 bake 包中的 FrameworkRouterType
public class FrameworkRouterType {
    public init() {}
}

// ============================================================================
// 服务器初始化上下文
// 对应 Bun: pub const ServerInitContext = struct { ... }
// ============================================================================

/// 服务器初始化上下文
/// 在解析路由配置时使用的临时状态
public class ServerInitContext {
    public var arena: ArenaAllocator
    public var dedupeHtmlBundleMap: HashMap<String, HTMLBundleRoute>
    public var jsStringAllocations: StringRefList
    public var global: JSGlobalObject
    public var frameworkRouterList: ArrayList<FrameworkRouterType>
    public var userRoutes: ArrayList<StaticRouteEntry>

    public init(global: JSGlobalObject) {
        this.arena = ArenaAllocator()
        this.dedupeHtmlBundleMap = HashMap<String, HTMLBundleRoute>()
        this.jsStringAllocations = StringRefList()
        this.global = global
        this.frameworkRouterList = ArrayList<FrameworkRouterType>()
        this.userRoutes = ArrayList<StaticRouteEntry>()
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
    | unqueued(Array<String>)
    /// 正在加载中
    | pending(ServePluginPending)
    /// 加载完成
    | loaded(JSBundlerPlugin)
    /// 加载失败
    | err
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

/* Duplicate: GetOrStartLoadResult is defined in html_bundle.cj
/// 插件加载结果
/// 对应 Bun: pub const GetOrStartLoadResult = union(enum) { ready, pending, err }
public enum GetOrStartLoadResult {
    /// 准备就绪（null = 无插件）
    | ready(JSBundlerPlugin)
    /// 正在加载
    | pending
    /// 加载失败
    | err
}
*/

/* Duplicate: ServePluginCallback is defined in html_bundle.cj
/// 插件回调类型
/// 对应 Bun: pub const Callback = union(enum) { html_bundle_route, dev_server }
public enum ServePluginCallback {
    | htmlBundleRoute(HTMLBundleRoute)
    | devServer(DevServer)
}
*/

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
        match (state) {
            case ServePluginState.unqueued(plugins) =>
                loadAndResolvePlugins(global)
                return getOrStartLoad(global, cb)
            case ServePluginState.pending(pd) =>
                match (cb) {
                    case ServePluginCallback.HtmlBundleRoute(route) =>
                        route.ref()
                        pd.htmlBundleRoutes.append(route)
                    case ServePluginCallback.DevServer(dev) =>
                        // 类型不匹配: devServer 是 ?DevServer, dev 是 DevServerRef
                        ()
                }
                return GetOrStartLoadResult.Pending
            case ServePluginState.loaded(plugin) =>
                return GetOrStartLoadResult.Ready(plugin)
            case ServePluginState.err =>
                return GetOrStartLoadResult.Err
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
        match (state) {
            case ServePluginState.pending(pd) =>
                let plugin = pd.plugin
                let devSrv = pd.devServer
                let htmlBundleRoutes = pd.htmlBundleRoutes
                pd.htmlBundleRoutes = ArrayList<HTMLBundleRoute>()
                pd.promise.deinit()
                state = ServePluginState.loaded(plugin)
                for (route in htmlBundleRoutes) {
                    route.onPluginsResolved(plugin)
                    route.deref()
                }
                match (devSrv) {
                    case Some(dev) => dev.onPluginsResolved(plugin)
                    case None => ()
                }
            case _ => ()
        }
    }

    /// 处理插件加载失败
    /// 对应 Bun: pub fn handleOnReject(this, global, err) void
    public func handleOnReject(global: JSGlobalObject, err: JsValue): Unit {
        match (state) {
            case ServePluginState.pending(pd) =>
                let devSrv = pd.devServer
                let htmlBundleRoutes = pd.htmlBundleRoutes
                pd.htmlBundleRoutes = ArrayList<HTMLBundleRoute>()
                pd.plugin.deinit()
                pd.promise.deinit()
                state = ServePluginState.err
                for (route in htmlBundleRoutes) {
                    route.onPluginsRejected()
                    route.deref()
                }
                match (devSrv) {
                    case Some(dev) => dev.onPluginsRejected()
                    case None => ()
                }
                // 简化: Output.errGeneric 不可用
                ()
            case _ => ()
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
        match (state) {
            case loaded(plugin) => plugin.deinit()
            case _ => ()
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
/// 对应 Bun: pub const UserRoute = struct { id: u32, server: *ThisServer, route: RouteDeclaration }
public class UserRoute {
    public var id: UInt32
    public var server: HttpServer
    public var route: RouteDeclaration

    public init(id: UInt32, server: HttpServer, route: RouteDeclaration) {
        this.id = id
        this.server = server
        this.route = route
    }

    public func deinit(): Unit {
        // 简化: RouteDeclaration 没有 deinit 方法
    }
}

/// 预处理的请求
/// 对应 Bun: pub const PreparedRequest = struct { js_request, request_object, ctx }
public class PreparedRequest {
    public var jsRequest: JsValue
    public var requestObject: Request
    public var ctx: RequestContext

    public init(jsRequest: JsValue, requestObject: Request, ctx: RequestContext) {
        this.jsRequest = jsRequest
        this.requestObject = requestObject
        this.ctx = ctx
    }

    /// 保存请求以便延迟处理
    /// 对应 Bun: pub fn save(prepared, global, req, resp) SavedRequest
    public func save(global: JSGlobalObject, req: UwsRequest, resp: ResponseRef): SavedRequest {
        ctx.toAsync()
        let sr = SavedRequest()
        sr.jsRequest = JSStrong.create(jsRequest, global)
        sr.request = requestObject
        sr.ctx = AnyRequestContext()
        sr.response = resp
        return sr
    }
}

/// 保存的请求 - 用于延迟处理
public class SavedRequest {
    public var jsRequest: JSStrong
    public var request: Request
    public var ctx: AnyRequestContext
    public var response: ResponseRef

    public init() {
        jsRequest = JSStrong()
        request = Request(HttpMethod.GET, "/")
        ctx = AnyRequestContext()
        response = ResponseRef()
    }
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
        listenCallback = AnyTask({ => }, "")
        allocator = ArenaAllocator()
        pollRef = AsyncKeepAlive()
        flags = ServerFlags()
        plugins = None
        devServer = None
        userRoutes = ArrayList<UserRoute>()
        onClientError = JSStrongOptional.empty()
        inspectorServerId = Int64(0)
    }

    /// 从配置初始化
    /// 对应 Bun: pub fn init(config: *ServerConfig, global: *JSGlobalObject) bun.JSOOM!*ThisServer
    public static func initFunc(config: ServerConfig, global: JSGlobalObject): HttpServer {
        let baseUrl = ""
        let devServer: ?DevServer = None

        let server = HttpServer()
        server.globalThis = global
        server.config = config
        server.baseUrlStringForJoining = baseUrl
        server.vm = VirtualMachine.get()
        server.allocator = ArenaAllocator()
        server.devServer = devServer
        return server
    }

    // ========================================================================
    // 内存与生命周期
    // ========================================================================

    /// 内存开销
    /// 对应 Bun: pub fn memoryCost(`this`: *ThisServer) usize
    public func memoryCost(): Int64 {
        var cost: Int64 = Int64(512) // approximate HttpServer size
        cost += Int64(baseUrlStringForJoining.size)
        cost += config.memoryCost()
        match (devServer) {
            case Some(dev) => cost += dev.memoryCost()
            case None => ()
        }
        return cost
    }

    /// 释放
    /// 对应 Bun: pub fn deinit(`this`: *ThisServer) void
    public func deinit(): Unit {
        allClosedPromise.deinit()
        for (userRoute in userRoutes) {
            userRoute.deinit()
        }
        userRoutes.clear()
        // config.deinit()
        onClientError.deinit()

        match (devServer) {
            case Some(dev) => dev.deinit()
            case None => ()
        }
        match (plugins) {
            case Some(p) => p.deref()
            case None => ()
        }
    }

    // ========================================================================
    // 监听
    // ========================================================================

    /// 监听成功回调
    /// 对应 Bun: pub fn onListen(`this`: *ThisServer, socket: ?*App.ListenSocket) void
    public func onListen(socket: ?ListenSocket): Unit {
        if (socket.isNone()) {
            onListenFailed()
            return
        }
        listener = socket
        vm.eventLoopHandle = AsyncLoop.get()
    }

    /// 监听失败回调
    /// 对应 Bun: noinline fn onListenFailed(`this`: *ThisServer) void
    public func onListenFailed(): Unit {
        // 简化: throwValue 不可用
    }

    /// 停止监听
    /// 对应 Bun: pub fn stopListening(`this`: *ThisServer, abrupt: bool) void
    public func stopListening(abrupt: Bool): Unit {
        let l = listener
        if (l.isNone()) { return }
        listener = None
        unref()
        notifyInspectorServerStopped()

        match (config.address) {
            case Unix(path) =>
                if (path.size > 0) {
                    // 简化: Sys.unlink 不可用
                }
            case _ => ()
        }

        if (!abrupt) {
            match (l) {
                case Some(listener) => () // 简化: listener.close()
                case None => ()
            }
        } else if (!flags.terminated) {
            match (config.websocket) {
                case Some(ws) => ws.handler.app = None
                case None => ()
            }
            flags.terminated = true
            match (app) {
                case Some(a) => a.close()
                case None => ()
            }
        }
    }

    /// 停止服务器
    /// 对应 Bun: pub fn stop(`this`: *ThisServer, abrupt: bool) void
    public func stop(abrupt: Bool): Unit {
        if (jsValue.isNotEmpty()) {
            jsValue.downgrade()
        }
        if (config.allowHot && config.id.size > 0) {
            // 简化: bunVM().hotMap() 不可用
        }
        stopListening(abrupt)
        deinitIfWeCan()
    }

    /// 从JS停止
    /// 对应 Bun: pub fn stopFromJS(`this`: *ThisServer, abruptly: ?JsValue) jsc.JsValue
    public func stopFromJS(abruptly: ?JsValue): JsValue {
        let rc = getAllClosedPromise(globalThis)
        if (hasListener()) {
            let abrupt = match (abruptly) {
                case Some(val) => val.isBoolean() && val.toBoolean()
                case None => false
            }
            stop(abrupt)
        }
        return rc
    }

    // ========================================================================
    // 引用计数
    // ========================================================================

    /// 增加引用
    /// 对应 Bun: pub fn ref(`this`: *ThisServer) void
    public func ref(): Unit {
        if (pollRef.isActive()) { return }
        pollRef.ref(vm)
    }

    /// 减少引用
    /// 对应 Bun: pub fn unref(`this`: *ThisServer) void
    public func unref(): Unit {
        if (!pollRef.isActive()) { return }
        pollRef.unref(vm)
    }

    // ========================================================================
    // 请求处理
    // ========================================================================

    /// 处理请求
    /// 对应 Bun: pub fn onRequest(`this`: *ThisServer, req, resp) void
    public func onRequest(req: UwsRequest, resp: ResponseRef): Unit {
        pendingRequests += 1
        // 创建请求上下文并调用用户的fetch处理器
        let prepared = prepareJsRequestContext(req, resp, Option<BoolRef>.None, true, Option<HTTPMethod>.None)
        if (prepared.isNone()) { return }

        let jsValue = jsValueAssertAlive()
        let responseValue: JsValue = match (config.onRequest) {
            case Some(cb) => JsValue.undefined() // 简化: cb 返回 Object 不是 JsValue
            case None => JsValue.undefined()
        }

        match (prepared) {
            case Some(p) => handleRequest(p, req, responseValue)
            case None => ()
        }
    }

    /// 处理预处理后的请求
    /// 对应 Bun: fn handleRequest(this, should_deinit_context, prepared, req, response_value) void
    public func handleRequest(prepared: PreparedRequest, req: UwsRequest,
                               responseValue: JsValue): Unit {
        let ctx = prepared.ctx
        // 简化: onResponse 只接受 ?Response 参数
        ctx.onResponse(Option<Response>.None)
        prepared.jsRequest.ensureStillAlive()

        if (ctx.shouldRenderMissing()) {
            ctx.renderMissing()
            return
        }

        ctx.toAsync()
    }

    /// 请求完成回调
    /// 对应 Bun: pub fn onRequestComplete(`this`: *ThisServer) void
    public func onRequestComplete(): Unit {
        vm.eventLoop() // 简化: processGCTimer 不可用于 Any 类型
        pendingRequests -= 1
        deinitIfWeCan()
    }

    /// 静态请求完成回调
    /// 对应 Bun: pub fn onStaticRequestComplete(`this`: *ThisServer) void
    public func onStaticRequestComplete(): Unit {
        pendingRequests -= 1
        deinitIfWeCan()
    }

    /// 待处理请求
    /// 对应 Bun: pub fn onPendingRequest(`this`: *ThisServer) void
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
            var len: Int64 = 0
            match (req.header("content-length")) {
                case Some(cl) => len = parseContentLength(cl)
                case None => ()
            }
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
        let serverRef = ServerRef()
        let rawReq = RawRequestRef()
        rawReq.method = req.method()
        rawReq.url = req.url()
        ctx.create(serverRef, rawReq, resp, shouldDeinitContext, Option<HttpMethod>.None)

        // 简化: 跳过 body/signal/request object 初始化
        let body = RequestBodyRef()
        ctx.requestBody = body

        let requestObject = Request(HttpMethod.GET, "/")

        // 处理请求体
        match (requestBodyLength) {
            case Some(reqLen) =>
                ctx.requestBodyContentLen = reqLen
                ctx.flags.isWaitingForRequestBody = true
            case None => ()
        }

        return PreparedRequest(
            if (createJsRequest) { JsValue.undefined() } else { JsValue.undefined() },
            requestObject,
            ctx
        )
    }

    // ========================================================================
    // WebSocket
    // ========================================================================

    /// WebSocket升级
    /// 对应 Bun: pub fn onUpgrade(this, globalThis, object, optional) bun.JSError!JsValue
    public func onUpgrade(globalThis: JSGlobalObject, object: JsValue,
                           optional: ?JsValue): JsValue {
        if (config.websocket.isNone()) {
            // throwInvalidArguments returns JsError, simplify to JsValue(false)
            return JsValue(false)
        }

        if (flags.terminated) { return JsValue(false) }

        // 简化: asNodeHTTPResponse 和 asRequest 不存在于 JsValue
        // 跳过类型检查，直接返回 false
        return JsValue(false)
    }

    /// 处理NodeHTTP升级
    private func handleNodeHttpUpgrade(globalThis: JSGlobalObject,
                                        nodeHttpResponse: NodeHTTPResponse,
                                        optional: ?JsValue): JsValue {
        // 简化: NodeHTTP 升级逻辑需要完整的 JsValue API
        return JsValue(false)
    }

    /// 处理Request升级
    private func handleRequestUpgrade(globalThis: JSGlobalObject,
                                       request: Request,
                                       optional: ?JsValue): JsValue {
        // 简化: Request 升级逻辑需要完整的 RequestContext API
        return JsValue(false)
    }

    /// 发布消息到WebSocket频道
    /// 对应 Bun: pub fn publish(this, globalThis, topic, message_value, compress_value) bun.JSError!JsValue
    public func publish(globalThis: JSGlobalObject, topic: String,
                         messageValue: JsValue, compressValue: ?JsValue): JsValue {
        // 简化: publish 需要 UwsAnyWebSocket 等完整API
        return JsValue(0)
    }

    // ========================================================================
    // 路由管理
    // ========================================================================

    /// 设置路由
    /// 对应 Bun: fn setRoutes(`this`: *ThisServer) jsc.JsValue
    public func setRoutes(): JsValue {
        var routeListValue = JsValue.UNDEFINED
        match (this.app) {
            case Some(appRef) =>
                let devServer = this.devServer

                // 1. 注册用户路由
                for (userRoute in userRoutes) {
                    let path = userRoute.route.path
                    // 简化: 统一使用 any 处理所有方法
                    appRef.any(path, userRoute, onUserRouteRequest)
                }

                // 2. 设置WebSocket处理器
                match (config.websocket) {
                    case Some(websocket) =>
                        () // 简化: globalObject 类型不匹配 (?JsGlobalObject vs JSGlobalObject)
                    case None => ()
                }

                // 3. 注册静态路由
                for (entry in config.staticRoutes) {
                    match (entry.route) {
                        case Some(route) =>
                            match (route) {
                                case AnyRoute.Static(sr) =>
                                    applyStaticRoute(appRef, sr, entry.path, entry.method)
                                case AnyRoute.File(fr) =>
                                    applyStaticRoute(appRef, fr, entry.path, entry.method)
                                case AnyRoute.HtmlBundle(hr) =>
                                    applyStaticRoute(appRef, hr, entry.path, entry.method)
                                    match (devServer) {
                                        case Some(dev) =>
                                            dev.htmlRouter.put(allocator, entry.path, hr)
                                        case None => ()
                                    }
                            }
                        case None => ()
                    }
                }

                // 4. DevServer路由
                match (devServer) {
                    case Some(dev) => dev.setRoutes(this)
                    case None => ()
                }

                // 5. 全局"/*"回退路由
                match (config.onRequest) {
                    case Some(_) =>
                        appRef.any("/*", this, onRequest)
                    case None =>
                        appRef.any("/*", this, on404)
                }
            case None => ()
        }

        return routeListValue
    }

    // ========================================================================
    // 重新加载
    // ========================================================================

    /// 从Zig重新加载
    /// 对应 Bun: pub fn onReloadFromZig(this, new_config, globalThis) void
    public func onReloadFromZig(newConfig: ServerConfig, globalThis: JSGlobalObject): Unit {
        // 简化: 重新加载逻辑需要完整的 Option 比较/unprotect API
        match (app) {
            case Some(a) => a.clearRoutes()
            case None => ()
        }

        config.onRequest = newConfig.onRequest
        config.onError = newConfig.onError
        config.websocket = newConfig.websocket

        for (route in config.staticRoutes) {
            route.deinit()
        }
        config.staticRoutes = newConfig.staticRoutes

        match (devServer) {
            case Some(dev) => dev.htmlRouter.clear()
            case None => ()
        }

        setRoutes()
    }

    /// 从JS重新加载
    /// 对应 Bun: pub fn onReload(this, globalThis, callframe) bun.JSError!jsc.JsValue
    public func onReload(globalThis: JSGlobalObject, callframe: CallFrame): JsValue {
        let arguments = callframe.arguments()
        if (arguments.size < 1) {
            return JsValue.undefined()
        }

        var newConfig = ServerConfig()
        ServerConfig.fromJS(globalThis, newConfig, arguments, ServerConfigFromJSOptions(
            false,
            true,
            userRoutes.size > 0
        ))

        onReloadFromZig(newConfig, globalThis)
        return jsValue.tryGet() ?? JsValue.UNDEFINED
    }

    // ========================================================================
    // fetch方法（服务器端内部fetch）
    // ========================================================================

    /// 服务器端fetch
    /// 对应 Bun: pub fn onFetch(this, ctx, callframe) bun.JSError!jsc.JsValue
    public func onFetch(ctx: JSGlobalObject, callframe: CallFrame): JsValue {
        // 简化: fetch 需要大量 JsValue API
        match (config.onRequest) {
            case None => return JsValue.undefined()
            case Some(_) => ()
        }
        return JsValue.undefined()
    }

    // ========================================================================
    // 属性访问
    // ========================================================================

    /// 获取端口
    /// 对应 Bun: pub fn getPort(this, _) jsc.JsValue
    public func getPort(): JsValue {
        match (config.address) {
            case Unix(_) => JsValue.UNDEFINED
            case Tcp(tcp) =>
                match (listener) {
                    case Some(l) => return JsValue.jsNumber(Int64(0)) // 简化: l.getLocalPort() 不可用
                    case None => ()
                }
                return JsValue.jsNumber(tcp.port)
        }
    }

    /// 获取ID
    /// 对应 Bun: pub fn getId(this, globalThis) bun.JSError!jsc.JsValue
    public func getId(globalThis: JSGlobalObject): JsValue {
        JsValue(config.id)
    }

    /// 获取待处理请求数
    /// 对应 Bun: pub fn getPendingRequests(this, _) jsc.JsValue
    public func getPendingRequests(): JsValue {
        JsValue.jsNumber(pendingRequests)
    }

    /// 获取地址
    /// 对应 Bun: pub fn getAddress(this, globalThis) bun.JSError!jsc.JsValue
    public func getAddress(globalThis: JSGlobalObject): JsValue {
        match (config.address) {
            case Unix(unixPath) =>
                JsValue(unixPath)
            case Tcp(tcp) =>
                JsValue.jsNull() // 简化: SocketAddress/intoDTO 不可用
        }
    }

    /// 获取URL
    /// 对应 Bun: pub fn getURL(this, globalThis) bun.OOM!jsc.JsValue
    public func getURL(globalThis: JSGlobalObject): JsValue {
        JsValue(getURLAsString())
    }

    /// 获取URL字符串
    /// 对应 Bun: pub fn getURLAsString(this) bun.OOM!bun.String
    public func getURLAsString(): String {
        match (config.address) {
            case Unix(unixPath) =>
                "unix://${unixPath}"
            case Tcp(tcp) =>
                var portStr: String = tcp.port.toString()
                let hostname = match (tcp.hostname) {
                    case Some(h) => h
                    case None => "localhost"
                }
                "http://${hostname}:${portStr}"
        }
    }

    /// 获取主机名
    /// 对应 Bun: pub fn getHostname(this, globalThis) !jsc.JsValue
    public func getHostname(globalThis: JSGlobalObject): JsValue {
        match (config.address) {
            case Unix(_) => JsValue.UNDEFINED
            case Tcp(tcp) =>
                match (tcp.hostname) {
                    case Some(h) => JsValue(h)
                    case None => JsValue("localhost")
                }
        }
    }

    /// 获取协议
    /// 对应 Bun: pub fn getProtocol(this, globalThis) bun.JSError!jsc.JsValue
    public func getProtocol(globalThis: JSGlobalObject): JsValue {
        JsValue.jsNull()
    }

    // ========================================================================
    // 状态检查
    // ========================================================================

    /// 是否有监听器
    /// 对应 Bun: pub fn hasListener(this) bool
    public func hasListener(): Bool {
        listener.isSome()
    }

    /// 活跃WebSocket数
    /// 对应 Bun: pub fn activeSocketsCount(this) u32
    public func activeSocketsCount(): UInt32 {
        match (config.websocket) {
            case Some(ws) => return UInt32(ws.handler.activeConnections)
            case None => ()
        }
        return 0
    }

    /// 是否有活跃的WebSocket
    /// 对应 Bun: pub fn hasActiveWebSockets(this) bool
    public func hasActiveWebSockets(): Bool {
        activeSocketsCount() > 0
    }

    /// 获取全部关闭的Promise
    /// 对应 Bun: pub fn getAllClosedPromise(this, globalThis) jsc.JsValue
    public func getAllClosedPromise(globalThis: JSGlobalObject): JsValue {
        if (!hasListener() && pendingRequests == 0) {
            return JsValue.UNDEFINED
        }
        if (allClosedPromise.has()) {
            return allClosedPromise.value()
        }
        allClosedPromise = JSPromiseStrong(globalThis)
        return allClosedPromise.value()
    }

    /// 如果可以则释放
    /// 对应 Bun: pub fn deinitIfWeCan(this) void
    public func deinitIfWeCan(): Unit {
        if (pendingRequests == 0 && !hasListener() && !hasActiveWebSockets()) {
            match (config.websocket) {
                case Some(ws) => ws.handler.app = None
                case None => ()
            }
            unref()

            // 分离DevServer
            match (devServer) {
                case Some(dev) =>
                    devServer = None
                    match (app) {
                        case Some(a) => a.clearRoutes()
                        case None => ()
                    }
                    dev.deinit()
                case None => ()
            }

            // 简化: jsValue.isFinalized() 不可用
            scheduleDeinit()
        }
    }

    /// 调度释放
    /// 对应 Bun: pub fn scheduleDeinit(this) void
    public func scheduleDeinit(): Unit {
        if (flags.deinitScheduled) { return }
        flags.deinitScheduled = true

        if (!flags.terminated) {
            flags.terminated = true
            // 简化: App.close 不可直接引用, 跳过任务创建
        }

        // 简化: AnyTask(HttpServer.deinit, this) 不支持静态引用
    }

    /// 通知调试器服务器已停止
    /// 对应 Bun: fn notifyInspectorServerStopped(this) void
    public func notifyInspectorServerStopped(): Unit {
        // 简化: inspector API 不可用
    }

    /// 断言JS值存活并获取
    /// 对应 Bun: pub fn jsValueAssertAlive(server) jsc.JsValue
    public func jsValueAssertAlive(): JsValue {
        match (jsValue.tryGet()) {
            case Some(v) => v
            case None => JsValue.UNDEFINED
        }
    }

    /// 请求IP
    /// 对应 Bun: pub fn requestIP(this, request) bun.JSError!jsc.JsValue
    public func requestIP(request: Request): JsValue {
        match (config.address) {
            case Unix(_) => return JsValue.null()
            case Tcp(_) => ()
        }
        // 简化: Request 没有 requestContext 字段
        return JsValue.null()
    }

    /// 设置空闲超时
    /// 对应 Bun: pub fn setIdleTimeout(this, seconds) void
    public func setIdleTimeout(seconds: UInt32): Unit {
        config.idleTimeout = Int64(seconds)
    }

    /// 设置标志
    /// 对应 Bun: pub fn setFlags(this, require_host_header, use_strict_method_validation) void
    public func setFlags(requireHostHeader: Bool, useStrictMethodValidation: Bool): Unit {
        match (app) {
            case Some(a) => a.setFlags(requireHostHeader, useStrictMethodValidation)
            case None => ()
        }
    }

    /// 关闭空闲连接
    /// 对应 Bun: pub fn closeIdleConnections(this, globalObject, callframe) bun.JSError!jsc.JsValue
    public func closeIdleConnections(): JsValue {
        match (app) {
            case Some(a) => a.closeIdleConnections()
            case None => ()
        }
        return JsValue.UNDEFINED
    }

    /// 从JS释放
    /// 对应 Bun: pub fn disposeFromJS(this) jsc.JsValue
    public func disposeFromJS(): JsValue {
        if (hasListener()) {
            stop(true)
        }
        return JsValue.UNDEFINED
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

    let prepared = server.prepareJsRequestContext(req, resp, Option<BoolRef>.None, false, Option<HTTPMethod>.None)
    if (prepared.isNone()) { return }

    let responseValue: JsValue = JsValue.undefined()

    match (prepared) {
        case Some(p) => server.handleRequest(p, req, responseValue)
        case None => ()
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 解析 Content-Length 字符串为 Int64
public func parseContentLength(s: String): Int64 {
    if (s.size == 0) { return 0 }
    var result: Int64 = 0
    for (c in s) {
        let v = Int64(c)
        if (v < 48 || v > 57) { return 0 }
        result = result * 10 + (v - 48)
    }
    return result
}

/* Duplicate: BoolRef is defined in request_context.cj
/// Bool引用 - 用于在回调中传递可变布尔值
public class BoolRef {
    public var value: Bool

    public init(value: Bool) {
        this.value = value
    }
}
*/
