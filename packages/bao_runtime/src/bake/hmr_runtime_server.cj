// 翻译自 Bun: src/runtime/bake/hmr-runtime-server.ts
// HMR 服务器端运行时入口点。
// 在服务器端，通过 server_exports 通信。

package bao_runtime.bake

import bao_collections.*

// ============================================================================
// RequestContext — 请求上下文
// 对应 Bun: hmr-runtime-server.ts RequestContext
// ============================================================================

/// 请求上下文
public class RequestContext {
    /// 响应选项
    public var responseOptions: ResponseInit
    /// 是否为流式传输
    public var streaming: Bool
    /// 流式传输是否已开始
    public var streamingStarted: Bool
    /// 渲染中止函数
    public var renderAbort: ?((String, ?HashMap<String, Any>) -> Unit) = None

    public init(responseOptions: ResponseInit, streaming: Bool) {
        this.responseOptions = responseOptions
        this.streaming = streaming
        this.streamingStarted = false
    }
}

/// ResponseInit — 响应初始化选项
public class ResponseInit {
    public var status: Int64 = 200
    public var statusText: String = ""
    public var headers: HashMap<String, String> = HashMap<String, String>()

    public init() {}
}

// ============================================================================
// ServerExports — 服务器端导出
// 对应 Bun: hmr-runtime-server.ts Exports
// ============================================================================

/// 服务器端导出接口
public class ServerExports {
    /// 处理请求
    public var handleRequest: (
        Any, // Request
        String, // routerTypeMain (Id)
        Array<String>, // routeModules (Id[])
        String, // clientEntryUrl
        Array<String>, // styles
        ?HashMap<String, String>, // params
        (Any) -> Unit, // setAsyncLocalStorage
        (Any, String) -> Tuple<Int64, ?Promise<Unit>>, // bundleNewRoute
        (Any, Int64, String) -> NewRouteParams, // newRouteParams
    ) -> Promise<Any>

    /// 注册更新
    public var registerUpdate: (
        HashMap<String, Any>, // modules
        ?Array<String>, // componentManifestAdd
        ?Array<String>, // componentManifestDelete
    ) -> Unit

    public init(
        handleRequest: (
            Any, String, Array<String>, String, Array<String>,
            ?HashMap<String, String>, (Any) -> Unit,
            (Any, String) -> Tuple<Int64, ?Promise<Unit>>,
            (Any, Int64, String) -> NewRouteParams,
        ) -> Promise<Any>,
        registerUpdate: (HashMap<String, Any>, ?Array<String>, ?Array<String>) -> Unit,
    ) {
        this.handleRequest = handleRequest
        this.registerUpdate = registerUpdate
    }
}

/// 新路由参数
public class NewRouteParams {
    public var routerTypeMain: String
    public var routeModules: Array<String>
    public var clientEntryUrl: String
    public var styles: Array<String>
    public var params: ?HashMap<String, String>

    public init(routerTypeMain: String, routeModules: Array<String>, clientEntryUrl: String, styles: Array<String>, params: ?HashMap<String, String>) {
        this.routerTypeMain = routerTypeMain
        this.routeModules = routeModules
        this.clientEntryUrl = clientEntryUrl
        this.styles = styles
        this.params = params
    }
}

// ============================================================================
// 默认服务器端导出实现
// 对应 Bun: hmr-runtime-server.ts server_exports
// ============================================================================

/// 创建默认的服务器端导出
public func createServerExports(): ServerExports {
    return ServerExports(
        handleRequest: { (req, routerTypeMain, routeModules, clientEntryUrl, styles, params, setAsyncLocalStorage, bundleNewRoute, newRouteParams) =>
            // 加载服务器入口点并执行渲染
            serverHandleRequest(
                req, routerTypeMain, routeModules, clientEntryUrl, styles, params,
                setAsyncLocalStorage, bundleNewRoute, newRouteParams,
            )
        },
        registerUpdate: { (modules, componentManifestAdd, componentManifestDelete) =>
            // 调用 replaceModules 并更新 manifest
            serverRegisterUpdate(modules, componentManifestAdd, componentManifestDelete)
        },
    )
}

/// 服务器端请求处理实现
func serverHandleRequest(
    req: Any,
    routerTypeMain: String,
    routeModules: Array<String>,
    clientEntryUrl: String,
    styles: Array<String>,
    params: ?HashMap<String, String>,
    setAsyncLocalStorage: (Any) -> Unit,
    bundleNewRoute: (Any, String) -> Tuple<Int64, ?Promise<Unit>>,
    newRouteParams: (Any, Int64, String) -> NewRouteParams,
): Promise<Any> {
    // 加载入口点导出
    let exportsPromise = loadExports<Any>(routerTypeMain)

    return exportsPromise.then({ (exports) =>
        // 查找 render 函数
        let serverRenderer = exports // 简化：假设 exports 就是 render 函数

        // 加载路由模块
        var pageModulePromises: Array<Promise<Any>> = []
        for (moduleId in routeModules) {
            pageModulePromises.append(loadExports<Any>(moduleId))
        }

        Promise.all(pageModulePromises).then({ (pageModules) =>
            // 构建渲染上下文
            // 调用 render 函数
            // 返回 Response
            Any()
        })
    })
}

/// 服务器端注册更新实现
func serverRegisterUpdate(
    modules: HashMap<String, Any>,
    componentManifestAdd: ?Array<String>,
    componentManifestDelete: ?Array<String>,
): Unit {
    // 构建模块映射并调用 replaceModules
    var moduleMap: HashMap<Id, UnloadedModule> = HashMap<Id, UnloadedModule>()
    // 简化实现
    // replaceModules(moduleMap)

    if (componentManifestAdd != None) {
        for (uid in componentManifestAdd.get()) {
            // 更新 server manifest
        }
    }

    if (componentManifestDelete != None) {
        for (fileName in componentManifestDelete.get()) {
            // 从 manifest 中删除
        }
    }
}

// 类型别名
public type Id = String
public type Promise<T> = std.Promise<T>
public type HashMap<K, V> = std.HashMap<K, V>
public type Tuple<A, B> = std.Tuple<A, B>
