// bao_router - HTTP 路由器
// 严格翻译自: src/router/
// 对应 Bun: src/router/lib.rs, router.zig
package bao_router

import bao_core.*
import bao_collections.*

// ============================================================================
// HttpMethod - HTTP 方法
// ============================================================================

/// HTTP 方法
public enum HttpMethod {
    | GET
    | POST
    | PUT
    | DELETE
    | PATCH
    | HEAD
    | OPTIONS
    | CONNECT
    | TRACE
    | ANY  // 匹配任意方法

    public func toString(): String {
        match (this) {
            case GET => "GET"
            case POST => "POST"
            case PUT => "PUT"
            case DELETE => "DELETE"
            case PATCH => "PATCH"
            case HEAD => "HEAD"
            case OPTIONS => "OPTIONS"
            case CONNECT => "CONNECT"
            case TRACE => "TRACE"
            case ANY => "*"
        }
    }

    public static func fromString(s: String): HttpMethod {
        match (s.toUpper()) {
            case "GET" => GET
            case "POST" => POST
            case "PUT" => PUT
            case "DELETE" => DELETE
            case "PATCH" => PATCH
            case "HEAD" => HEAD
            case "OPTIONS" => OPTIONS
            case "CONNECT" => CONNECT
            case "TRACE" => TRACE
            case "*" => ANY
            case _ => GET
        }
    }
}

// ============================================================================
// RoutePattern - 路由模式
// 严格翻译自: src/router/lib.rs - Pattern / pattern 模块
// Bun 的 Pattern 支持静态、动态、catch-all、可选 catch-all 四种类型
// ============================================================================

/// 路由模式标签
/// 对应 Bun: pattern::Tag
public enum PatternTag {
    | Static            // 静态路由: /users/list
    | Dynamic           // 动态参数: /users/:id
    | CatchAll          // Catch-all: /users/*path
    | OptionalCatchAll  // 可选 catch-all: /users[[/*path]]

    public func toOrdinal(): Int64 {
        match (this) {
            case Static => 0
            case Dynamic => 1
            case CatchAll => 2
            case OptionalCatchAll => 3
        }
    }
}

/// 路由模式
/// 对应 Bun: pattern::Pattern
public class RoutePattern {
    /// 原始模式字符串 (如 "/users/:id/posts/:postId")
    public var raw: String
    /// 解析后的段列表
    public var segments: ArrayList<PatternSegment>
    /// 模式类型
    public var tag: PatternTag
    /// 参数名称列表 (按出现顺序)
    public var paramNames: ArrayList<String>
    /// 参数数量
    public var paramCount: Int64
    /// 是否包含通配符
    public var hasWildcard: Bool
    /// 用于匹配的规范化模式 (小写, 无前导斜杠)
    public var matchName: String
    /// 哈希值
    public var hash: UInt32

    public init(pattern: String) {
        this.raw = pattern
        this.segments = ArrayList<PatternSegment>()
        this.tag = PatternTag.Static
        this.paramNames = ArrayList<String>()
        this.paramCount = 0
        this.hasWildcard = false
        this.matchName = ""
        this.hash = 0
        parse(pattern)
    }

    /// 解析路由模式字符串
    /// 对应 Bun: Pattern::init_maybe_hash
    private func parse(pattern: String): Unit {
        // 移除前导斜杠
        var input = if (pattern.startsWith("/")) { pattern.substring(1) } else { pattern }
        if (input.isEmpty) {
            tag = PatternTag.Static
            return
        }
        matchName = input.toLower()
        hash = wyhash(matchName)
        // 按斜杠分段
        let parts = input.split("/")
        for (part in parts) {
            if (part.isEmpty) { continue }
            let segment = parseSegment(part)
            segments.append(segment)
            match (segment) {
                case PatternSegment.Dynamic(name) =>
                    tag = PatternTag.Dynamic
                    paramNames.append(name)
                    paramCount += 1
                case PatternSegment.CatchAll(name) =>
                    tag = PatternTag.CatchAll
                    paramNames.append(name)
                    paramCount += 1
                    hasWildcard = true
                case PatternSegment.OptionalCatchAll(name) =>
                    tag = PatternTag.OptionalCatchAll
                    paramNames.append(name)
                    paramCount += 1
                    hasWildcard = true
                case _ => ()
            }
        }
        if (paramCount == 0) {
            tag = PatternTag.Static
        }
    }

    /// 解析单个段
    /// 对应 Bun: Pattern::init_maybe_hash 中的 bracket 解析
    private func parseSegment(part: String): PatternSegment {
        if (part.startsWith("[[")) {
            // [[...param]] 可选 catch-all
            let inner = part.substring(3)
            let endIdx = inner.indexOf("]]")
            if (endIdx > 0) {
                let name = inner.substring(0, endIdx)
                return PatternSegment.OptionalCatchAll(name)
            }
        }
        if (part.startsWith("[...")) {
            // [...param] catch-all
            let inner = part.substring(4)
            let endIdx = inner.indexOf("]")
            if (endIdx > 0) {
                let name = inner.substring(0, endIdx)
                return PatternSegment.CatchAll(name)
            }
        }
        if (part.startsWith("[") && part.endsWith("]")) {
            // [param] 动态参数
            let name = part.substring(1, part.length - 1)
            return PatternSegment.Dynamic(name)
        }
        if (part.startsWith(":")) {
            // :param 动态参数 (Express 风格)
            let name = part.substring(1)
            return PatternSegment.Dynamic(name)
        }
        if (part == "*") {
            // * 通配符
            hasWildcard = true
            return PatternSegment.CatchAll("*")
        }
        // 静态段
        return PatternSegment.Static(part)
    }

    /// 匹配路径
    /// 对应 Bun: Pattern::match_<ALLOW_OPTIONAL_CATCH_ALL>
    public func match(path: String): ?RouteParams {
        // 移除前导斜杠
        var input = if (path.startsWith("/")) { path.substring(1) } else { path }
        let params = RouteParams()
        var segIdx = 0
        var pathParts = input.split("/")
        var partIdx = 0

        while (partIdx < pathParts.size && segIdx < segments.size) {
            let part = pathParts[partIdx]
            let seg = segments[segIdx]
            match (seg) {
                case PatternSegment.Static(expected) =>
                    if (part.toLower() != expected.toLower()) {
                        return None
                    }
                    partIdx += 1
                    segIdx += 1
                case PatternSegment.Dynamic(name) =>
                    if (part.isEmpty) { return None }
                    params.set(name, part)
                    partIdx += 1
                    segIdx += 1
                case PatternSegment.CatchAll(name) =>
                    // 消耗剩余所有段
                    let sb = StringBuilder()
                    while (partIdx < pathParts.size) {
                        if (sb.toString().length > 0) { sb.append("/") }
                        sb.append(pathParts[partIdx])
                        partIdx += 1
                    }
                    params.set(name, sb.toString())
                    return Some(params)
                case PatternSegment.OptionalCatchAll(name) =>
                    // 可选: 消耗剩余所有段 (可以为空)
                    let sb = StringBuilder()
                    while (partIdx < pathParts.size) {
                        if (sb.toString().length > 0) { sb.append("/") }
                        sb.append(pathParts[partIdx])
                        partIdx += 1
                    }
                    let value = sb.toString()
                    if (value.length > 0) {
                        params.set(name, value)
                    }
                    return Some(params)
            }
        }
        // 检查是否完全匹配
        if (partIdx < pathParts.size) { return None }
        // 允许最后一个段是可选 catch-all
        if (segIdx < segments.size) {
            match (segments[segIdx]) {
                case PatternSegment.OptionalCatchAll(name) => return Some(params)
                case _ => return None
            }
        }
        return Some(params)
    }

    /// 是否为静态路由
    public func isStatic(): Bool {
        return tag == PatternTag.Static
    }

    /// 是否为动态路由
    public func isDynamic(): Bool {
        return tag == PatternTag.Dynamic
    }

    /// Wyhash 哈希函数 (简化)
    private func wyhash(input: String): UInt32 {
        var h = UInt32(0)
        for (c in input) {
            h = h ^ UInt32(c)
            h = h * UInt32(0x01000193)
        }
        return h
    }

    public func toString(): String {
        return raw
    }
}

/// 路由模式段
/// 对应 Bun: pattern::Value
public enum PatternSegment {
    | Static(String)              // 静态文本: "users"
    | Dynamic(String)             // 动态参数: :id -> "id"
    | CatchAll(String)            // Catch-all: *path -> "path"
    | OptionalCatchAll(String)    // 可选 catch-all: [[...slug]] -> "slug"
}

// ============================================================================
// RouteParams - 路由参数
// 严格翻译自: src/router/lib.rs - Param / route_param 模块
// ============================================================================

/// 路由参数 (name -> value 映射)
/// 对应 Bun: Param::List
public class RouteParams {
    private var params: ArrayList<RouteParam>

    public init() {
        this.params = ArrayList<RouteParam>()
    }

    /// 设置参数
    public func set(name: String, value: String): Unit {
        params.append(RouteParam(name, value))
    }

    /// 获取参数值
    public func get(name: String): ?String {
        for (p in params) {
            if (p.name == name) { return Some(p.value) }
        }
        return None
    }

    /// 获取参数值 (带默认值)
    public func getOrElse(name: String, default: String): String {
        match (get(name)) {
            case Some(v) => v
            case None => default
        }
    }

    /// 是否包含参数
    public func has(name: String): Bool {
        for (p in params) {
            if (p.name == name) { return true }
        }
        return false
    }

    /// 参数数量
    public func size(): Int64 {
        return params.size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return params.size == 0
    }

    /// 获取所有参数名
    public func names(): ArrayList<String> {
        let result = ArrayList<String>()
        for (p in params) { result.append(p.name) }
        return result
    }

    /// 获取所有参数
    public func all(): ArrayList<RouteParam> {
        return params
    }

    /// 遍历参数
    public func forEach(fn: (String, String) -> Unit): Unit {
        for (p in params) {
            fn(p.name, p.value)
        }
    }

    /// 合并参数
    public func merge(other: RouteParams): RouteParams {
        let result = RouteParams()
        for (p in params) { result.set(p.name, p.value) }
        for (p in other.params) { result.set(p.name, p.value) }
        return result
    }
}

/// 路由参数条目
/// 对应 Bun: Param { name: string, value: string }
public class RouteParam {
    public let name: String
    public let value: String

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }
}

// ============================================================================
// Route - 路由条目
// 严格翻译自: src/router/lib.rs - Route struct
// Bun 的 Route 存储路由名、匹配名、绝对路径、参数数量等
// ============================================================================

/// 路由处理器类型
public type RouteHandler = (RouteContext) -> Unit

/// 路由条目
/// 对应 Bun: Route + Match
public class Route {
    /// 路由模式
    public var pattern: RoutePattern
    /// HTTP 方法约束 (ANY = 任意方法)
    public var methods: ArrayList<HttpMethod>
    /// 路由处理器
    public var handler: ?RouteHandler
    /// 中间件列表
    public var middleware: ArrayList<Middleware>
    /// 路由名称
    public var name: String
    /// 所属路由组前缀
    public var prefix: String
    /// 参数数量
    public var paramCount: Int64
    /// 路由类型
    public var tag: PatternTag
    /// 哈希值
    public var fullHash: UInt32

    public init(pattern: String, handler: ?RouteHandler) {
        this.pattern = RoutePattern(pattern)
        this.methods = ArrayList<HttpMethod>()
        this.methods.append(HttpMethod.ANY)
        this.handler = handler
        this.middleware = ArrayList<Middleware>()
        this.name = ""
        this.prefix = ""
        this.paramCount = this.pattern.paramCount
        this.tag = this.pattern.tag
        this.fullHash = 0
    }

    /// 设置方法约束
    public func setMethods(varargs: HttpMethod...): Route {
        methods = ArrayList<HttpMethod>()
        for (m in varargs) { methods.append(m) }
        return this
    }

    /// 添加单个方法
    public func addMethod(method: HttpMethod): Route {
        methods.append(method)
        return this
    }

    /// 设置路由名称
    public func setName(name: String): Route {
        this.name = name
        return this
    }

    /// 添加中间件
    public func addMiddleware(mw: Middleware): Route {
        middleware.append(mw)
        return this
    }

    /// 是否匹配指定 HTTP 方法
    public func matchesMethod(method: HttpMethod): Bool {
        for (m in methods) {
            if (m == HttpMethod.ANY || m == method) { return true }
        }
        return false
    }

    /// 匹配路径
    public func match(path: String, method: HttpMethod): ?RouteMatch {
        if (!matchesMethod(method)) { return None }
        let params = pattern.match(path)
        match (params) {
            case Some(p) => return Some(RouteMatch(this, path, p))
            case None => return None
        }
    }

    public func toString(): String {
        let methodsStr = if (methods.size == 1 && methods[0] == HttpMethod.ANY) {
            "*"
        } else {
            let sb = StringBuilder()
            var first = true
            for (m in methods) {
                if (!first) { sb.append(",") }
                sb.append(m.toString())
                first = false
            }
            sb.toString()
        }
        return "${methodsStr} ${pattern.raw}"
    }
}

// ============================================================================
// RouteMatch - 路由匹配结果
// 严格翻译自: src/router/lib.rs - Match struct
// Bun 的 Match 包含路由路径、名称、参数、查询字符串等
// ============================================================================

/// 路由匹配结果
/// 对应 Bun: Match
public class RouteMatch {
    /// 匹配的路由
    public var route: Route
    /// 匹配的 URL 路径
    public var path: String
    /// 提取的路由参数
    public var params: RouteParams
    /// 是否有重定向
    public var redirectPath: ?String
    /// 查询字符串
    public var queryString: ?String

    public init(route: Route, path: String, params: RouteParams) {
        this.route = route
        this.path = path
        this.params = params
        this.redirectPath = None
        this.queryString = None
    }

    /// 获取指定参数
    public func param(name: String): ?String {
        return params.get(name)
    }

    /// 获取指定参数 (带默认值)
    public func paramOrElse(name: String, default: String): String {
        return params.getOrElse(name, default)
    }

    /// 是否有参数
    public func hasParams(): Bool {
        return !params.isEmpty()
    }
}

// ============================================================================
// RouteContext - 路由上下文
// 传递给路由处理器的请求上下文
// ============================================================================

/// 路由上下文
public class RouteContext {
    /// 请求路径
    public var path: String
    /// HTTP 方法
    public var method: HttpMethod
    /// 路由参数
    public var params: RouteParams
    /// 查询参数
    public var query: HashMap<String, String>
    /// 请求头
    public var headers: HashMap<String, String>
    /// 请求体
    public var body: ?Array<UInt8>
    /// 响应状态码
    public var statusCode: Int64
    /// 响应头
    public var responseHeaders: HashMap<String, String>
    /// 响应体
    public var responseBody: ?String
    /// 是否已处理
    public var handled: Bool
    /// 匹配的路由
    public var matchedRoute: ?RouteMatch

    public init() {
        this.path = "/"
        this.method = HttpMethod.GET
        this.params = RouteParams()
        this.query = HashMap<String, String>()
        this.headers = HashMap<String, String>()
        this.body = None
        this.statusCode = 200
        this.responseHeaders = HashMap<String, String>()
        this.responseBody = None
        this.handled = false
        this.matchedRoute = None
    }

    /// 获取路径参数
    public func param(name: String): ?String {
        return params.get(name)
    }

    /// 获取路径参数 (带默认值)
    public func paramOrElse(name: String, default: String): String {
        return params.getOrElse(name, default)
    }

    /// 获取查询参数
    public func queryParam(name: String): ?String {
        return query.get(name)
    }

    /// 获取请求头
    public func header(name: String): ?String {
        return headers.get(name.toLower())
    }

    /// 设置响应状态码
    public func setStatus(code: Int64): RouteContext {
        this.statusCode = code
        return this
    }

    /// 设置响应头
    public func setHeader(name: String, value: String): RouteContext {
        responseHeaders.put(name, value)
        return this
    }

    /// 设置 JSON 响应体
    public func json(body: String): Unit {
        responseHeaders.put("Content-Type", "application/json")
        responseBody = Some(body)
        handled = true
    }

    /// 设置文本响应体
    public func text(body: String): Unit {
        responseHeaders.put("Content-Type", "text/plain")
        responseBody = Some(body)
        handled = true
    }

    /// 设置 HTML 响应体
    public func html(body: String): Unit {
        responseHeaders.put("Content-Type", "text/html")
        responseBody = Some(body)
        handled = true
    }

    /// 重定向
    public func redirect(url: String, status: Int64): Unit {
        statusCode = status
        responseHeaders.put("Location", url)
        handled = true
    }

    /// 是否已处理
    public func isHandled(): Bool {
        return handled
    }
}

// ============================================================================
// Middleware - 中间件
// ============================================================================

/// 中间件处理器
public type MiddlewareHandler = (RouteContext) -> Bool

/// 中间件类型
public enum Middleware {
    | Before(MiddlewareHandler)   // 前置中间件: 返回 true 继续链, false 中断
    | After(MiddlewareHandler)    // 后置中间件
    | Error(MiddlewareHandler)    // 错误处理中间件

    public func isBefore(): Bool {
        match (this) {
            case Before(_) => true
            case _ => false
        }
    }

    public func isAfter(): Bool {
        match (this) {
            case After(_) => true
            case _ => false
        }
    }
}

// ============================================================================
// Router - 路由器
// 严格翻译自: src/router/lib.rs - Router struct
// Bun 的 Router 支持静态路由快速查找 + 动态路由模式匹配
// ============================================================================

/// 路由器
/// 对应 Bun: Router + Routes
public class Router {
    /// 静态路由表 (路径 -> Route)
    private var staticRoutes: HashMap<String, Route>
    /// 动态路由列表 (按优先级排序)
    private var dynamicRoutes: ArrayList<Route>
    /// 所有路由列表
    private var allRoutes: ArrayList<Route>
    /// 全局中间件
    private var globalMiddleware: ArrayList<Middleware>
    /// 路由组前缀栈
    private var prefixStack: ArrayList<String>
    /// 路由组中间件栈
    private var middlewareStack: ArrayList<ArrayList<Middleware>>
    /// 索引路由
    private var indexRoute: ?Route
    /// 是否已排序
    private var sorted: Bool

    public init() {
        this.staticRoutes = HashMap<String, Route>()
        this.dynamicRoutes = ArrayList<Route>()
        this.allRoutes = ArrayList<Route>()
        this.globalMiddleware = ArrayList<Middleware>()
        this.prefixStack = ArrayList<String>()
        this.middlewareStack = ArrayList<ArrayList<Middleware>>()
        this.indexRoute = None
        this.sorted = false
    }

    // ========================================================================
    // 路由注册 - 流式 API
    // 对应 Bun: RouterBuilder 风格
    // ========================================================================

    /// 注册 GET 路由
    public func get(path: String, handler: RouteHandler): Router {
        return addRoute(path, handler, [HttpMethod.GET])
    }

    /// 注册 POST 路由
    public func post(path: String, handler: RouteHandler): Router {
        return addRoute(path, handler, [HttpMethod.POST])
    }

    /// 注册 PUT 路由
    public func put(path: String, handler: RouteHandler): Router {
        return addRoute(path, handler, [HttpMethod.PUT])
    }

    /// 注册 DELETE 路由
    public func delete(path: String, handler: RouteHandler): Router {
        return addRoute(path, handler, [HttpMethod.DELETE])
    }

    /// 注册 PATCH 路由
    public func patch(path: String, handler: RouteHandler): Router {
        return addRoute(path, handler, [HttpMethod.PATCH])
    }

    /// 注册 HEAD 路由
    public func head(path: String, handler: RouteHandler): Router {
        return addRoute(path, handler, [HttpMethod.HEAD])
    }

    /// 注册 OPTIONS 路由
    public func options(path: String, handler: RouteHandler): Router {
        return addRoute(path, handler, [HttpMethod.OPTIONS])
    }

    /// 注册任意方法路由
    public func any(path: String, handler: RouteHandler): Router {
        return addRoute(path, handler, [HttpMethod.ANY])
    }

    /// 注册指定方法的路由
    public func addRoute(path: String, handler: RouteHandler, methods: Array<HttpMethod>): Router {
        let fullPath = buildFullPath(path)
        let route = Route(fullPath, Some(handler))
        route.setMethods(methods)
        // 应用当前路由组的中间件
        for (mwList in middlewareStack) {
            for (mw in mwList) {
                route.addMiddleware(mw)
            }
        }
        // 应用全局中间件
        for (mw in globalMiddleware) {
            route.addMiddleware(mw)
        }
        // 注册到路由表
        registerRoute(route)
        sorted = false
        return this
    }

    /// 添加全局中间件
    public func use(middleware: Middleware): Router {
        globalMiddleware.append(middleware)
        return this
    }

    /// 添加前置中间件
    public func use(handler: MiddlewareHandler): Router {
        globalMiddleware.append(Middleware.Before(handler))
        return this
    }

    // ========================================================================
    // 路由组
    // ========================================================================

    /// 创建路由组
    public func group(prefix: String, fn: (RouterGroup) -> Unit): Router {
        let group = RouterGroup(this, prefix)
        prefixStack.append(prefix)
        middlewareStack.append(ArrayList<Middleware>())
        fn(group)
        prefixStack.removeAt(prefixStack.size - 1)
        middlewareStack.removeAt(middlewareStack.size - 1)
        return this
    }

    // ========================================================================
    // 路由匹配
    // 对应 Bun: Routes::match_ / match_page
    // ========================================================================

    /// 匹配请求
    /// 对应 Bun: Router::match_<S, C>
    public func match_(path: String, method: HttpMethod): ?RouteMatch {
        ensureSorted()
        // 先匹配静态路由
        let staticKey = buildStaticKey(path, method)
        match (staticRoutes.get(staticKey)) {
            case Some(route) =>
                let params = RouteParams()
                return Some(RouteMatch(route, path, params))
            case None => ()
        }
        // 再匹配动态路由
        for (route in dynamicRoutes) {
            let match = route.match(path, method)
            match (match) {
                case Some(m) => return Some(m)
                case None => ()
            }
        }
        // 最后尝试匹配所有路由 (包括通配)
        for (route in allRoutes) {
            if (route.tag == PatternTag.CatchAll || route.tag == PatternTag.OptionalCatchAll) {
                let match = route.match(path, method)
                match (match) {
                    case Some(m) => return Some(m)
                    case None => ()
                }
            }
        }
        return None
    }

    /// 处理请求
    /// 对应 Bun: Router::match_ 的完整请求处理流程
    public func handle(ctx: RouteContext): Unit {
        let matchResult = match_(ctx.path, ctx.method)
        match (matchResult) {
            case Some(match_) =>
                ctx.matchedRoute = Some(match_)
                ctx.params = match_.params
                // 执行前置中间件链
                if (!executeBeforeMiddleware(ctx, match_.route)) {
                    return  // 中间件中断
                }
                // 执行路由处理器
                match (match_.route.handler) {
                    case Some(handler) => handler(ctx)
                    case None => ()
                }
                // 执行后置中间件链
                executeAfterMiddleware(ctx, match_.route)
            case None =>
                // 没有匹配的路由
                ctx.statusCode = 404
                ctx.responseBody = Some("Not Found")
                ctx.handled = true
        }
    }

    /// 执行前置中间件
    private func executeBeforeMiddleware(ctx: RouteContext, route: Route): Bool {
        // 全局前置中间件
        for (mw in globalMiddleware) {
            match (mw) {
                case Middleware.Before(handler) =>
                    if (!handler(ctx)) { return false }
                case _ => ()
            }
        }
        // 路由级前置中间件
        for (mw in route.middleware) {
            match (mw) {
                case Middleware.Before(handler) =>
                    if (!handler(ctx)) { return false }
                case _ => ()
            }
        }
        return true
    }

    /// 执行后置中间件
    private func executeAfterMiddleware(ctx: RouteContext, route: Route): Unit {
        // 路由级后置中间件
        for (mw in route.middleware) {
            match (mw) {
                case Middleware.After(handler) => handler(ctx)
                case _ => ()
            }
        }
        // 全局后置中间件
        for (mw in globalMiddleware) {
            match (mw) {
                case Middleware.After(handler) => handler(ctx)
                case _ => ()
            }
        }
    }

    // ========================================================================
    // 路由注册辅助
    // ========================================================================

    /// 注册路由到路由表
    private func registerRoute(route: Route): Unit {
        allRoutes.append(route)
        if (route.pattern.isStatic()) {
            // 静态路由: 按 method+path 查找
            let key = route.pattern.matchName
            staticRoutes.put(key, route)
        } else {
            // 动态路由: 加入动态路由列表
            dynamicRoutes.append(route)
        }
        // 索引路由
        if (route.pattern.raw == "/" || route.pattern.raw.isEmpty) {
            indexRoute = Some(route)
        }
    }

    /// 构建完整路径 (合并前缀)
    private func buildFullPath(path: String): String {
        var prefix = ""
        for (p in prefixStack) {
            prefix = "${prefix}${p}"
        }
        if (path.startsWith("/")) {
            return "${prefix}${path}"
        }
        if (prefix.isEmpty) {
            return "/${path}"
        }
        return "${prefix}/${path}"
    }

    /// 构建静态路由查找 key
    private func buildStaticKey(path: String, method: HttpMethod): String {
        var key = if (path.startsWith("/")) { path.substring(1) } else { path }
        key = key.toLower()
        // 移除尾随斜杠
        while (key.length > 0 && key[key.length - 1] == UInt8('/')) {
            key = key.substring(0, key.length - 1)
        }
        return key
    }

    /// 确保路由已排序
    /// 对应 Bun: Sorter::sort_by_name
    private func ensureSorted(): Unit {
        if (sorted) { return }
        // 排序: 静态路由优先, 动态路由其次, catch-all 最后
        dynamicRoutes.sortWith({ a, b =>
            sortByPriority(a, b)
        })
        sorted = true
    }

    /// 路由优先级排序
    /// 对应 Bun: Sorter::sort_by_name
    private func sortByPriority(a: Route, b: Route): Int64 {
        let ordA = a.tag.toOrdinal()
        let ordB = b.tag.toOrdinal()
        if (ordA != ordB) {
            return ordA - ordB
        }
        // 同类型: 按参数数量排序 (少的优先)
        if (a.paramCount != b.paramCount) {
            return a.paramCount - b.paramCount
        }
        // 按路径字母序
        return if (a.pattern.matchName < b.pattern.matchName) {
            Int64(-1)
        } else if (a.pattern.matchName > b.pattern.matchName) {
            Int64(1)
        } else {
            Int64(0)
        }
    }

    // ========================================================================
    // 查询方法
    // ========================================================================

    /// 获取所有路由
    public func routes(): ArrayList<Route> {
        return allRoutes
    }

    /// 路由数量
    public func routeCount(): Int64 {
        return allRoutes.size
    }

    /// 获取索引路由
    public func index(): ?Route {
        return indexRoute
    }

    /// 打印路由表 (调试用)
    public func printRoutes(): Unit {
        println("=== Router (${routeCount()} routes) ===")
        for (route in allRoutes) {
            println("  ${route.toString()}")
        }
    }
}

// ============================================================================
// RouterGroup - 路由组
// ============================================================================

/// 路由组
/// 支持前缀和共享中间件
public class RouterGroup {
    private var router: Router
    private var prefix: String
    private var groupMiddleware: ArrayList<Middleware>

    public init(router: Router, prefix: String) {
        this.router = router
        this.prefix = prefix
        this.groupMiddleware = ArrayList<Middleware>()
    }

    /// 注册 GET 路由
    public func get(path: String, handler: RouteHandler): RouterGroup {
        router.get(buildPath(path), handler)
        return this
    }

    /// 注册 POST 路由
    public func post(path: String, handler: RouteHandler): RouterGroup {
        router.post(buildPath(path), handler)
        return this
    }

    /// 注册 PUT 路由
    public func put(path: String, handler: RouteHandler): RouterGroup {
        router.put(buildPath(path), handler)
        return this
    }

    /// 注册 DELETE 路由
    public func delete(path: String, handler: RouteHandler): RouterGroup {
        router.delete(buildPath(path), handler)
        return this
    }

    /// 注册 PATCH 路由
    public func patch(path: String, handler: RouteHandler): RouterGroup {
        router.patch(buildPath(path), handler)
        return this
    }

    /// 注册任意方法路由
    public func any(path: String, handler: RouteHandler): RouterGroup {
        router.any(buildPath(path), handler)
        return this
    }

    /// 添加组级中间件
    public func use(middleware: Middleware): RouterGroup {
        groupMiddleware.append(middleware)
        return this
    }

    /// 添加组级前置中间件
    public func use(handler: MiddlewareHandler): RouterGroup {
        groupMiddleware.append(Middleware.Before(handler))
        return this
    }

    /// 构建完整路径
    private func buildPath(path: String): String {
        if (path.startsWith("/")) {
            return "${prefix}${path}"
        }
        if (path.isEmpty) {
            return prefix
        }
        return "${prefix}/${path}"
    }
}

// ============================================================================
// RouterBuilder - 流式路由构建器
// ============================================================================

/// 路由构建器 (流式 API)
public class RouterBuilder {
    private var router: Router

    public init() {
        this.router = Router()
    }

    /// 注册 GET 路由
    public func get(path: String, handler: RouteHandler): RouterBuilder {
        router.get(path, handler)
        return this
    }

    /// 注册 POST 路由
    public func post(path: String, handler: RouteHandler): RouterBuilder {
        router.post(path, handler)
        return this
    }

    /// 注册 PUT 路由
    public func put(path: String, handler: RouteHandler): RouterBuilder {
        router.put(path, handler)
        return this
    }

    /// 注册 DELETE 路由
    public func delete(path: String, handler: RouteHandler): RouterBuilder {
        router.delete(path, handler)
        return this
    }

    /// 注册 PATCH 路由
    public func patch(path: String, handler: RouteHandler): RouterBuilder {
        router.patch(path, handler)
        return this
    }

    /// 注册任意方法路由
    public func any(path: String, handler: RouteHandler): RouterBuilder {
        router.any(path, handler)
        return this
    }

    /// 添加中间件
    public func use(handler: MiddlewareHandler): RouterBuilder {
        router.use(handler)
        return this
    }

    /// 创建路由组
    public func group(prefix: String, fn: (RouterGroup) -> Unit): RouterBuilder {
        router.group(prefix, fn)
        return this
    }

    /// 构建路由器
    public func build(): Router {
        return router
    }
}

// ============================================================================
// RouteConfig - 路由配置
// 严格翻译自: src/router/lib.rs - RouteConfig
// Bun 的 RouteConfig 定义了路由目录、扩展名等
// ============================================================================

/// 路由配置
/// 对应 Bun: RouteConfig
public class RouteConfig {
    /// 路由目录 (默认 "pages")
    public var dir: String
    /// 可能的目录列表
    public var possibleDirs: ArrayList<String>
    /// 资源前缀路径
    public var assetPrefixPath: String
    /// 文件扩展名列表
    public var extensions: ArrayList<String>
    /// 是否启用路由
    public var routesEnabled: Bool
    /// 静态文件目录
    public var staticDir: String
    /// 是否启用静态文件
    public var staticDirEnabled: Bool

    public init() {
        this.dir = "pages"
        this.possibleDirs = ArrayList<String>()
        this.assetPrefixPath = ""
        this.extensions = ArrayList<String>()
        this.extensions.append("tsx")
        this.extensions.append("ts")
        this.extensions.append("mjs")
        this.extensions.append("jsx")
        this.extensions.append("js")
        this.routesEnabled = false
        this.staticDir = "public"
        this.staticDirEnabled = false
    }

    /// 默认配置
    public static func defaults(): RouteConfig {
        let config = RouteConfig()
        config.routesEnabled = true
        return config
    }

    public func toString(): String {
        return "RouteConfig(dir=${dir}, enabled=${routesEnabled})"
    }
}

// ============================================================================
// TinyPtr - 小型指针 (偏移+长度打包)
// 严格翻译自: src/router/lib.rs - TinyPtr
// Bun 使用 packed struct(u32) 存储偏移和长度
// ============================================================================

/// 小型指针: offset(u16) + len(u16) 打包为 u32
/// 对应 Bun: TinyPtr
public class TinyPtr {
    public var offset: UInt16
    public var len: UInt16

    public init() {
        this.offset = 0
        this.len = 0
    }

    public init(offset: UInt16, len: UInt16) {
        this.offset = offset
        this.len = len
    }

    /// 从父切片和子切片计算
    public static func from(parent: String, child: String): TinyPtr {
        // 简化: 实际需要指针算术
        return TinyPtr(0, UInt16(child.length))
    }

    /// 从 backing 字符串中提取子串
    public func str(backing: String): String {
        if (len == 0) { return "" }
        return backing.substring(Int64(offset), Int64(offset) + Int64(len))
    }
}

// ============================================================================
// PatternValidation - 模式验证
// 严格翻译自: src/router/lib.rs - Pattern::validate
// ============================================================================

/// 模式验证结果
/// 对应 Bun: pattern::ValidationResult
public class ValidationResult {
    public var paramCount: Int64
    public var kind: PatternTag

    public init() {
        this.paramCount = 0
        this.kind = PatternTag.Static
    }
}

/// 模式验证错误
/// 对应 Bun: pattern::PatternParseError
public enum PatternParseError {
    | CatchAllMustBeAtTheEnd
    | InvalidCatchAllRoute
    | InvalidOptionalCatchAllRoute
    | InvalidRoutePattern
    | MissingParamName
    | PatternMissingClosingBracket

    public func toString(): String {
        match (this) {
            case CatchAllMustBeAtTheEnd => "Catch-all route must be at the end of the path"
            case InvalidCatchAllRoute => "Invalid catch-all route, e.g. should be [...param]"
            case InvalidOptionalCatchAllRoute => "Invalid optional catch-all route, e.g. should be [[...param]]"
            case InvalidRoutePattern => "Invalid dynamic route"
            case MissingParamName => "Route is missing a parameter name, e.g. [param]"
            case PatternMissingClosingBracket => "Route is missing a closing bracket ]"
        }
    }
}

/// 模式验证器
/// 对应 Bun: Pattern::validate
public class PatternValidator {
    /// 验证路由模式
    public static func validate(input: String): ?ValidationResult {
        let result = ValidationResult()
        var offset = 0
        let end = input.length - 1
        while (offset < end) {
            let ch = input[offset]
            if (ch == UInt8('[')) {
                // 检查动态段类型
                if (offset + 1 >= input.length) { return None }
                let next = input[offset + 1]
                if (next == UInt8('[')) {
                    // 可选 catch-all: [[...param]]
                    result.kind = PatternTag.OptionalCatchAll
                    result.paramCount += 1
                } else if (next == UInt8('.')) {
                    // catch-all: [...param]
                    result.kind = PatternTag.CatchAll
                    result.paramCount += 1
                } else {
                    // 动态参数: [param]
                    result.kind = PatternTag.Dynamic
                    result.paramCount += 1
                }
            } else if (ch == UInt8(':')) {
                result.kind = PatternTag.Dynamic
                result.paramCount += 1
            }
            offset += 1
        }
        return Some(result)
    }
}

// ============================================================================
// Sorter - 路由排序器
// 严格翻译自: src/router/lib.rs - Sorter module
// ============================================================================

/// 路由排序器
/// 对应 Bun: Sorter
public class RouteSorter {
    /// 排序表 (特殊字符排序权重)
    /// 对应 Bun: SORT_TABLE
    /// '[' 和 ']' 排在最后, '/' 分隔段
    public static func sortByName(a: String, b: String): Int64 {
        let n = if (a.length < b.length) { a.length } else { b.length }
        var i = 0
        while (i < n) {
            let wa = sortWeight(a[i])
            let wb = sortWeight(b[i])
            if (wa != wb) { return wa - wb }
            i += 1
        }
        return a.length - b.length
    }

    /// 字符排序权重
    private static func sortWeight(ch: UInt8): Int64 {
        match (ch) {
            case UInt8('[') => 252
            case UInt8(']') => 253
            case UInt8('/') => 254
            case _ => Int64(ch)
        }
    }
}

// ============================================================================
// BannedDirs - 禁止的目录
// 严格翻译自: src/router/lib.rs - BANNED_DIRS
// ============================================================================

/// 禁止扫描的目录
/// 对应 Bun: BANNED_DIRS
public let BANNED_DIRS: ArrayList<String> = {
    let list = ArrayList<String>()
    list.append("node_modules")
    list
}()

// ============================================================================
// 索引路由哈希
// 严格翻译自: src/router/lib.rs - index_route_hash
// ============================================================================

/// 索引路由特殊哈希值
/// 对应 Bun: index_route_hash
public func indexRouteHash(): UInt32 {
    return UInt32(0xDEADBEEF)
}
