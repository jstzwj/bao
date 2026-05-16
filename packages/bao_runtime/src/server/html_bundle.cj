// HTMLBundle - HTML 打包导入
// 严格翻译自: Bun src/runtime/server/HTMLBundle.rs
// 对应: 通过 import 导入 HTML 文件作为路由
// 一个 HTMLBundle 可被多个 Server 实例共享使用
// 一个 HTMLBundle.Route 只能用于一个服务器，但也是引用计数的

package bao_runtime.server

import bao_core.*
import bao_collections.*

// ============================================================================
// HTMLBundle - HTML 打包描述
// 严格翻译自: src/runtime/server/HTMLBundle.rs
// Bun: pub struct HTMLBundle
// 描述一个 HTML 包，可以通过 import 从 HTML 文件创建
// 构建延迟执行 (state held in HTMLBundle.Route or DevServer.RouteBundle.HTML)
// ============================================================================

/// HTMLBundle - HTML 打包
/// 对应 Bun: pub struct HTMLBundle
/// 可被 JavaScript 持有，也可被任意数量的 Server 实例持有
/// 引用计数管理生命周期
public class HTMLBundle {
    // ========================================================================
    // 字段
    // ========================================================================

    /// 引用计数 - 对应 Bun: ref_count: RefCount<HTMLBundle>
    public var refCount: Int64

    /// 全局对象 - 对应 Bun: global: *const JSGlobalObject
    public var global: ?JsGlobalObject

    /// 文件路径 - 对应 Bun: path: Box<[u8]>
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
    /// 对应 Bun: pub fn init(global: &JSGlobalObject, path: &[u8]) -> IntrusiveRc<HTMLBundle>
    public static func initFunc(global: JsGlobalObject, path: String): HTMLBundle {
        let bundle = HTMLBundle(path)
        bundle.global = global
        return bundle
    }

    /// 转换为 JS 值
    /// 对应 Bun: pub fn to_js(this: *mut HTMLBundle, global: &JSGlobalObject) -> JSValue
    public func toJS(global: JsGlobalObject): JSValue {
        JSValue.createHTMLBundle(this, global)
    }

    /// 终结 (GC 回调)
    /// 对应 Bun: pub fn finalize(self: Box<Self>)
    public func finalize(): Unit {
        deref()
    }

    /// 获取路径索引
    /// 对应 Bun: pub fn get_index(this: &Self, global: &JSGlobalObject) -> JsResult<JSValue>
    public func getIndex(global: JsGlobalObject): JSValue {
        JSValue.createUTF8ForJS(global, path)
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

    /// 析构
    /// 对应 Bun: fn deinit (path auto-drops via Box)
    public func deinit(): Unit {
        path = ""
    }
}

// ============================================================================
// HTMLBundleRoute (别名 Route)
// 严格翻译自: HTMLBundle.rs Route
// 对应 Bun: pub struct Route
// 一个 HTMLBundle.Route 只能在一个服务器上使用
// 但也是引用计数的，因为一个服务器可以在多个端点上使用同一 HTML 文件
// ============================================================================

/// HTML Bundle 路由方法
/// 对应 Bun: pub enum RouteMethod
public enum RouteMethod {
    | Any
    | Specific(HttpMethodSet)

    /// 默认值
    public static func `default`(): RouteMethod {
        RouteMethod.Any
    }
}

/// HTML Bundle 路由状态
/// 对应 Bun: pub enum State
/// 管理 HTML Bundle 的构建状态
public enum HTMLBundleRouteState {
    /// 等待构建
    | Pending
    /// 正在构建 - 包含构建任务引用
    | Building(?JSBundleCompletionTask)
    /// 构建失败 - 包含错误日志
    | Err(BuildLog)
    /// 构建完成 - 包含静态路由
    | Html(?StaticRoute)

    /// 释放状态资源
    /// 对应 Bun: pub fn deinit(&mut self)
    public mutating func deinit(): Unit {
        switch (this) {
            case Pending => {}
            case Building(let task) =>
                match (task) {
                    case Some(t) =>
                        t.cancelled = true
                        t.deref()
                    case None => {}
                }
            case Err(_) => {}
            case Html(let html) =>
                match (html) {
                    case Some(h) => h.deref()
                    case None => {}
                }
        }
    }

    /// 内存开销
    /// 对应 Bun: pub fn memory_cost(&self) -> usize
    public func memoryCost(): Int64 {
        switch (this) {
            case Pending => Int64(0)
            case Building(_) => Int64(0)
            case Err(let log) => log.memoryCost()
            case Html(let html) =>
                match (html) {
                    case Some(h) => h.memoryCost()
                    case None => Int64(0)
                }
        }
    }
}

/// HTMLBundle 路由 (Route)
/// 对应 Bun: pub struct Route
/// 完整的 HTML Bundle 路由，管理构建状态、待处理响应等
public class HTMLBundleRoute {
    // ========================================================================
    // 字段
    // ========================================================================

    /// Bundle 引用 - 对应 Bun: bundle: IntrusiveRc<HTMLBundle>
    public var bundle: ?HTMLBundle

    /// 引用计数 - 对应 Bun: ref_count: RefCount<Route>
    public var refCount: Int64

    /// 服务器引用 - 对应 Bun: server: Cell<Option<AnyServer>>
    public var server: ?ServerRef

    /// 路由状态 - 对应 Bun: state: JsCell<State>
    public var state: HTMLBundleRouteState

    /// 开发服务器 ID - 对应 Bun: dev_server_id: Cell<Option<route_bundle::Index>>
    public var devServerId: ?Int64

    /// 待处理响应列表 - 对应 Bun: pending_responses: JsCell<Vec<*mut PendingResponse>>
    public var pendingResponses: ArrayList<PendingResponse>

    /// 路由方法 - 对应 Bun: method: RouteMethod
    public var method: RouteMethod

    public init() {
        bundle = None
        refCount = 1
        server = None
        state = HTMLBundleRouteState.Pending
        devServerId = None
        pendingResponses = ArrayList<PendingResponse>()
        method = RouteMethod.Any
    }

    /// 初始化
    /// 对应 Bun: pub fn init(html_bundle: *mut HTMLBundle) -> IntrusiveRc<Route>
    public static func initFunc(htmlBundle: HTMLBundle): HTMLBundleRoute {
        let route = HTMLBundleRoute()
        route.bundle = htmlBundle
        htmlBundle.ref()
        return route
    }

    /// 内存开销
    /// 对应 Bun: pub fn memory_cost(&self) -> usize
    public func memoryCost(): Int64 {
        var cost: Int64 = Int64(sizeOf<HTMLBundleRoute>())
        cost += Int64(pendingResponses.size) * Int64(sizeOf<PendingResponse>())
        cost += state.memoryCost()
        return cost
    }

    // ========================================================================
    // 请求处理
    // ========================================================================

    /// 处理请求
    /// 对应 Bun: pub fn on_request(this: *mut Self, req: AnyRequest, resp: AnyResponse)
    public func onRequest(req: AnyRequest, resp: AnyResponse): Unit {
        onAnyRequest(req, resp, false)
    }

    /// 处理 HEAD 请求
    /// 对应 Bun: pub fn on_head_request(this: *mut Self, req: AnyRequest, resp: AnyResponse)
    public func onHeadRequest(req: AnyRequest, resp: AnyResponse): Unit {
        onAnyRequest(req, resp, true)
    }

    /// 处理任意请求
    /// 对应 Bun: fn on_any_request(this: *mut Self, req, resp, is_head: bool)
    public func onAnyRequest(req: AnyRequest, resp: AnyResponse, isHead: Bool): Unit {
        match (server) {
            case None =>
                resp.endWithoutBody(true)
                return
            case Some(_) => {}
        }

        // 开发模式下的 DevServer 处理
        match (server) {
            case Some(srv) =>
                if (srv.config.isDevelopment()) {
                    match (srv.devServer) {
                        case Some(dev) =>
                            dev.respondForHTMLBundle(this, req, resp)
                            return
                        case None => {}
                    }

                    // 开发模式：每次请求重新打包
                    switch (state) {
                        case HTMLBundleRouteState.Html(_) | HTMLBundleRouteState.Err(_) =>
                            state.deinit()
                            state = HTMLBundleRouteState.Pending
                        else => {}
                    }
                }
            case None => {}
        }

        // 根据状态分发
        var done = false
        while (!done) {
            switch (state) {
                case HTMLBundleRouteState.Pending => {
                    // 调度 bundle 构建
                    scheduleBundle()
                    // 重新检查状态
                }
                case HTMLBundleRouteState.Building(_) => {
                    // 创建待处理响应
                    let httpMethod = HttpMethod.which(req.method())
                    if (httpMethod == None) {
                        resp.writeStatus("405 Method Not Allowed")
                        resp.endWithoutBody(true)
                        return
                    }

                    let pending = PendingResponse()
                    pending.method = httpMethod.get()
                    pending.resp = resp
                    pending.server = server
                    pending.route = this
                    pending.isResponsePending = true

                    pendingResponses.append(pending)
                    ref()
                    resp.onAborted(PendingResponse.onAbortedCallback, pending)
                    req.setYield(false)
                    done = true
                }
                case HTMLBundleRouteState.Err(_) => {
                    resp.endWithoutBody(true)
                    done = true
                }
                case HTMLBundleRouteState.Html(let htmlRoute) => {
                    match (htmlRoute) {
                        case Some(html) =>
                            if (isHead) {
                                html.onHeadRequest(req, resp)
                            } else {
                                html.onRequest(req, resp)
                            }
                        case None => resp.endWithoutBody(true)
                    }
                    done = true
                }
            }
        }
    }

    // ========================================================================
    // 构建调度
    // ========================================================================

    /// 调度 bundle 构建
    /// 对应 Bun: fn schedule_bundle(&self, server: AnyServer) -> Result<(), bun_core::Error>
    public func scheduleBundle(): Unit {
        match (server) {
            case Some(srv) =>
                let loadResult = srv.getOrLoadPlugins(
                    ServePluginCallback.htmlBundleRoute(this)
                )
                switch (loadResult) {
                    case .err =>
                        state = HTMLBundleRouteState.Err(BuildLog())
                    case .ready(let plugins) =>
                        onPluginsResolved(plugins)
                    case .pending =>
                        state = HTMLBundleRouteState.Building(None)
                }
            case None =>
                state = HTMLBundleRouteState.Err(BuildLog())
        }
    }

    /// 插件解析完成
    /// 对应 Bun: pub fn on_plugins_resolved(&self, plugins: Option<NonNull<JSBundler::Plugin>>) -> Result<(), Error>
    public func onPluginsResolved(plugins: ?JSBundlerPlugin): Unit {
        let global = match (bundle) {
            case Some(b) => b.global
            case None => return
        }
        let srv = match (server) {
            case Some(s) => s
            case None => return
        }

        // 创建 bundler 配置并调度构建任务
        let completionTask = JSBundleCompletionTask.createAndSchedule(
            global, plugins, srv
        )

        state = HTMLBundleRouteState.Building(completionTask)
        ref() // 保持引用直到构建完成
    }

    /// 插件加载失败
    /// 对应 Bun: pub fn on_plugins_rejected(&self) -> Result<(), Error>
    public func onPluginsRejected(): Unit {
        state = HTMLBundleRouteState.Err(BuildLog())
        resumePendingResponses()
    }

    /// 构建完成
    /// 对应 Bun: pub fn on_complete(&self, completion_task: &mut JSBundleCompletionTask)
    public func onComplete(completionTask: JSBundleCompletionTask): Unit {
        deref() // 匹配 on_plugins_resolved 中的 ref()

        switch (completionTask.result) {
            case .err(let err) =>
                let log = BuildLog()
                state = HTMLBundleRouteState.Err(log)
            case .value(let bundle) =>
                // 为每个输出文件创建静态路由
                match (server) {
                    case Some(srv) =>
                        var thisHtmlRoute: ?StaticRoute = None
                        var thisHtmlRoutePath: String = ""

                        for (i in 0..bundle.outputFiles.size) {
                            let outputFile = bundle.outputFiles[i]
                            let blob = outputFile.toBlob(srv.global)
                            let headers = Headers.`default`()
                            headers.append("Content-Type", blob.contentType ?? "application/octet-stream")

                            // ETag
                            if (outputFile.loader != Loader.HTML && outputFile.isBuffer) {
                                let hashHex = outputFile.hash.toHexString()
                                headers.append("ETag", hashHex)
                                if (!srv.config.isDevelopment() && outputFile.outputKind == .chunk) {
                                    headers.append("Cache-Control", "public, max-age=31536000")
                                }
                            }

                            // SourceMap 头
                            if (srv.config.isDevelopment() && outputFile.sourceMapIndex != UInt32.max) {
                                let sourceMapPath = bundle.outputFiles[outputFile.sourceMapIndex].destPath
                                var routePath = sourceMapPath
                                if (routePath.startsWith("./") || routePath.startsWith(".\\")) {
                                    routePath = routePath[1..]
                                }
                                headers.append("SourceMap", routePath)
                            }

                            let staticRoute = StaticRoute(blob, headers)
                            var routePath = outputFile.destPath
                            if (routePath.startsWith("./") || routePath.startsWith(".\\")) {
                                routePath = routePath[1..]
                            }

                            // 检查是否是 HTML 入口点
                            if (thisHtmlRoute == None
                                && outputFile.outputKind == .entryPoint
                                && outputFile.loader == Loader.HTML) {
                                thisHtmlRoute = staticRoute
                                thisHtmlRoutePath = routePath
                            } else {
                                srv.appendStaticRoute(routePath, AnyRoute.static(staticRoute), .any)
                            }
                        }

                        // 注册 HTML 入口点路由
                        match (thisHtmlRoute) {
                            case Some(htmlRoute) =>
                                let htmlClone = htmlRoute.clone(srv.global)
                                srv.appendStaticRoute(thisHtmlRoutePath, AnyRoute.static(htmlRoute), .any)
                                state = HTMLBundleRouteState.Html(htmlClone)
                            case None =>
                                state = HTMLBundleRouteState.Err(BuildLog())
                        }

                        srv.reloadStaticRoutes()
                    case None => {}
                }
            case .pending =>
                // 不应该发生
                {}
        }

        resumePendingResponses()
    }

    // ========================================================================
    // 待处理响应管理
    // ========================================================================

    /// 恢复所有待处理响应
    /// 对应 Bun: pub fn resume_pending_responses(&self)
    public func resumePendingResponses(): Unit {
        let pending = pendingResponses.toArray()
        pendingResponses.clear()

        for (pendingResponse in pending) {
            let resp = pendingResponse.resp
            let method = pendingResponse.method

            if (!pendingResponse.isResponsePending) {
                continue
            }
            pendingResponse.isResponsePending = false
            resp.clearAborted()

            switch (state) {
                case HTMLBundleRouteState.Html(let htmlRoute) =>
                    match (htmlRoute) {
                        case Some(html) =>
                            if (method == HttpMethod.HEAD) {
                                html.onHead(resp)
                            } else {
                                html.on(resp)
                            }
                        case None => resp.endWithoutBody(false)
                    }
                case HTMLBundleRouteState.Err(_) =>
                    match (server) {
                        case Some(srv) =>
                            if (srv.config.isDevelopment()) {
                                // 开发模式下显示错误
                            }
                        case None => {}
                    }
                    resp.writeStatus("500 Build Failed")
                    resp.endWithoutBody(false)
                else =>
                    resp.endWithoutBody(false)
            }
        }
    }

    // ========================================================================
    // 生命周期
    // ========================================================================

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

    /// 析构
    /// 对应 Bun: impl Drop for Route
    public func deinit(): Unit {
        pendingResponses.clear()

        match (bundle) {
            case Some(b) => b.deref()
            case None => {}
        }

        state.deinit()
    }
}

// ============================================================================
// PendingResponse - 构建期间的待处理响应
// 严格翻译自: HTMLBundle.rs PendingResponse
// 对应 Bun: pub struct PendingResponse
// ============================================================================

/// 待处理响应
/// 表示 bundle 构建期间正在等待的 HTTP 响应
public class PendingResponse {
    /// HTTP 方法
    public var method: HttpMethod
    /// 响应对象
    public var resp: AnyResponse
    /// 响应是否仍在等待
    public var isResponsePending: Bool
    /// 服务器引用
    public var server: ?ServerRef
    /// 路由引用
    public var route: ?HTMLBundleRoute

    public init() {
        method = HttpMethod.GET
        resp = AnyResponse()
        isResponsePending = true
        server = None
        route = None
    }

    /// 中止回调
    /// 对应 Bun: pub fn on_aborted(this: *mut PendingResponse, _resp: AnyResponse)
    public static func onAbortedCallback(pending: PendingResponse, resp: AnyResponse): Unit {
        pending.isResponsePending = false

        match (pending.route) {
            case Some(route) =>
                // 从路由的待处理列表中移除
                route.pendingResponses.remove(pending)
                route.deref()
            case None => {}
        }
    }
}

// ============================================================================
// 辅助类型
// ============================================================================

/// 构建日志
/// 对应 Bun: bun_ast::Log
public class BuildLog {
    public var messages: ArrayList<String>

    public init() {
        messages = ArrayList<String>()
    }

    /// 内存开销
    public func memoryCost(): Int64 {
        var cost: Int64 = Int64(sizeOf<BuildLog>())
        for (msg in messages) {
            cost += Int64(msg.size)
        }
        return cost
    }
}

/// JS Bundle 完成任务
/// 对应 Bun: JSBundleCompletionTask
public class JSBundleCompletionTask {
    /// 是否已取消
    public var cancelled: Bool
    /// 构建结果
    public var result: BundleV2Result
    /// 日志
    public var log: BuildLog
    /// 开始时间 (纳秒)
    public var startedAtNs: Int64

    public init() {
        cancelled = false
        result = BundleV2Result.pending()
        log = BuildLog()
        startedAtNs = 0
    }

    /// 创建并调度
    public static func createAndSchedule(global: JsGlobalObject, plugins: ?JSBundlerPlugin,
                                          server: ServerRef): ?JSBundleCompletionTask {
        let task = JSBundleCompletionTask()
        task.startedAtNs = Timespec.nowAllowMockedTime().ns
        return task
    }

    /// 减少引用
    public func deref(): Unit {}
}

/// Bundle V2 结果
/// 对应 Bun: bun_bundler::bundle_v2::BundleV2Result
public enum BundleV2Result {
    | Value(BundleOutput)
    | Err(String)
    | Pending

    public static func pending(): BundleV2Result {
        BundleV2Result.Pending
    }
}

/// Bundle 输出
/// 对应 Bun: BundleV2 输出文件集合
public class BundleOutput {
    /// 输出文件列表
    public var outputFiles: ArrayList<OutputFile>

    public init() {
        outputFiles = ArrayList<OutputFile>()
    }
}

/// 输出文件
/// 对应 Bun: OutputFile
public class OutputFile {
    /// 目标路径
    public var destPath: String
    /// 加载器类型
    public var loader: Loader
    /// 输出种类
    public var outputKind: OutputKind
    /// 哈希值
    public var hash: UInt64
    /// 大小 (不含 sourcemap)
    public var sizeWithoutSourcemap: Int64
    /// SourceMap 索引
    public var sourceMapIndex: UInt32
    /// 是否为缓冲区
    public var isBuffer: Bool

    public init() {
        destPath = ""
        loader = Loader.HTML
        outputKind = OutputKind.EntryPoint
        hash = 0
        sizeWithoutSourcemap = 0
        sourceMapIndex = UInt32.max
        isBuffer = false
    }

    /// 转换为 Blob
    public func toBlob(global: JsGlobalObject): AnyBlob {
        AnyBlob()
    }
}

/// 加载器类型
/// 对应 Bun: bun_ast::Loader
public enum Loader {
    | HTML
    | JS
    | TS
    | CSS
    | JSON
    | Text
    | Other
}

/// 输出种类
/// 对应 Bun: bundler_options::OutputKind
public enum OutputKind {
    | EntryPoint
    | Chunk
    | Asset
    | SourceMap
}

/// JS Bundler 插件
public class JSBundlerPlugin {
    public func deinit(): Unit {}
}

/// 插件回调类型
/// 对应 Bun: pub const ServePluginsCallback
public enum ServePluginCallback {
    | HtmlBundleRoute(HTMLBundleRoute)
    | DevServer(DevServerRef)
}

/// 插件加载结果
/// 对应 Bun: pub const GetOrStartLoadResult
public enum GetOrStartLoadResult {
    | Ready(?JSBundlerPlugin)
    | Pending
    | Err
}

/// HTTP 方法
public class HttpMethod {
    public static let GET = HttpMethod("GET")
    public static let HEAD = HttpMethod("HEAD")
    public static let POST = HttpMethod("POST")
    public static let PUT = HttpMethod("PUT")
    public static let DELETE = HttpMethod("DELETE")
    public static let PATCH = HttpMethod("PATCH")

    public var name: String

    public init(name: String) {
        this.name = name
    }

    public static func which(method: String): ?HttpMethod {
        if (method == "GET") return GET
        if (method == "HEAD") return HEAD
        if (method == "POST") return POST
        if (method == "PUT") return PUT
        if (method == "DELETE") return DELETE
        if (method == "PATCH") return PATCH
        if (method == "OPTIONS") return HttpMethod("OPTIONS")
        return None
    }
}

/// HTTP 方法集合
public enum HttpMethodSet {
    | All
    | Specific(HttpMethod)
}

/// 静态路由 (前向声明)
/// 完整实现在 static_route.cj
public class StaticRoute {
    public var blob: AnyBlob
    public var headers: Headers

    public init() {
        blob = AnyBlob()
        headers = Headers.`default`()
    }

    public init(blob: AnyBlob, headers: Headers) {
        this.blob = blob
        this.headers = headers
    }

    public func memoryCost(): Int64 { Int64(0) }
    public func deref(): Unit {}
    public func clone(global: JsGlobalObject): StaticRoute { StaticRoute() }
    public func onRequest(req: AnyRequest, resp: AnyResponse): Unit {}
    public func onHeadRequest(req: AnyRequest, resp: AnyResponse): Unit {}
    public func onHead(resp: AnyResponse): Unit {}
    public func on(resp: AnyResponse): Unit {}
}

/// AnyRequest (前向声明)
public class AnyRequest {
    public func method(): String { "GET" }
    public func url(): String { "" }
    public func setYield(y: Bool): Unit {}
}

/// AnyResponse (前向声明)
public class AnyResponse {
    public func writeStatus(status: String): Unit {}
    public func `end`(body: String, close: Bool): Unit {}
    public func `end`(body: Array<Byte>, close: Bool): Unit {}
    public func endWithoutBody(close: Bool): Unit {}
    public func clearAborted(): Unit {}
    public func clearOnWritable(): Unit {}
    public func onAborted(cb: (PendingResponse, AnyResponse) -> Unit, ctx: PendingResponse): Unit {}
}

/// AnyBlob (前向声明)
public class AnyBlob {
    public var contentType: ?String

    public init() {
        contentType = None
    }

    public func size(): Int64 { 0 }
}

/// Headers (前向声明)
public class Headers {
    public var entries: ArrayList<Pair<String, String>>

    public init() {
        entries = ArrayList<Pair<String, String>>()
    }

    public static func `default`(): Headers { Headers() }
    public func append(key: String, value: String): Unit {
        entries.append(Pair<String, String>(key, value))
    }
}

/// ServerRef 扩展
public class ServerRef {
    public var id: String
    public var config: ServerConfig
    public var devServer: ?DevServerRef
    public var global: JsGlobalObject

    public init() {
        id = ""
        config = ServerConfig()
        devServer = None
        global = JsGlobalObject()
    }

    public func getOrLoadPlugins(cb: ServePluginCallback): GetOrStartLoadResult {
        GetOrStartLoadResult.Ready(None)
    }

    public func appendStaticRoute(path: String, route: AnyRoute, method: MethodOptional): Unit {}
    public func reloadStaticRoutes(): Bool { true }
    public func onRequestComplete(): Unit {}
}

/// AnyRoute (前向声明)
public enum AnyRoute {
    | Static(?StaticRoute)
    | File(?AnyRef)
    | Html(?AnyRef)
    | FrameworkRouter(Int32)

    public static func static(route: StaticRoute): AnyRoute {
        AnyRoute.Static(route)
    }
}

/// MethodOptional
public enum MethodOptional {
    | Any
    | Specific(HttpMethod)
}

/// DevServer 引用
public class DevServerRef {
    public func respondForHTMLBundle(route: HTMLBundleRoute, req: AnyRequest, resp: AnyResponse): Unit {}
}

/// JsGlobalObject (前向声明)
public class JsGlobalObject {}

/// JSValue (前向声明)
public class JSValue {
    public static func createHTMLBundle(bundle: HTMLBundle, global: JsGlobalObject): JSValue { JSValue() }
    public static func createUTF8ForJS(global: JsGlobalObject, str: String): JSValue { JSValue() }
}

/// ServerConfig (前向声明)
public class ServerConfig {
    public func isDevelopment(): Bool { false }
}

/// Timespec
public class Timespec {
    public var ns: Int64

    public init() {
        ns = 0
    }

    public static func nowAllowMockedTime(): Timespec { Timespec() }
}

/// AnyRef
public class AnyRef {}

/// Pair
public class Pair<K, V> {
    public var first: K
    public var second: V

    public init(first: K, second: V) {
        this.first = first
        this.second = second
    }
}
