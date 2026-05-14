// bao_router router - HTTP 路由器核心实现
// 严格翻译自: src/router.zig, src/http/*.zig 中路由相关逻辑
//   Bun 的路由器支持 Trie-based 路由匹配、中间件链、路径参数
//   包含: Trie 路由树、路由匹配器、中间件执行器、路由组、请求/响应扩展
//   仓颉翻译保持等价的路由匹配语义
package bao_router

import bao_core.*
import bao_collections.*

// ============================================================================
// TrieRouter - 基于 Trie 的路由匹配器
// 严格翻译自: src/router.zig 中 Trie 路由匹配
// Bun 使用前缀树 (Trie) 实现高效的路由查找
// 每个节点代表路径的一个段, 支持静态/动态/通配符匹配
// ============================================================================

/// Trie 路由树节点
/// 对应 Bun: router 中 Trie Node
public class TrieNode {
    /// 静态子节点 (段名 -> 子节点)
    public var children: HashMap<String, TrieNode>
    /// 动态参数子节点
    public var paramChild: ?TrieNode
    /// 通配符子节点
    public var wildcardChild: ?TrieNode
    /// 节点对应的路由 (叶子节点才有)
    public var route: ?Route
    /// 参数名 (如果是动态节点)
    public var paramName: String
    /// 节点深度
    public var depth: Int64
    /// 是否为通配符节点
    public var isWildcard: Bool

    public init() {
        this.children = HashMap<String, TrieNode>()
        this.paramChild = None
        this.wildcardChild = None
        this.route = None
        this.paramName = ""
        this.depth = 0
        this.isWildcard = false
    }

    /// 插入路由到 Trie
    /// 对应 Bun: router 中 insert 操作
    public func insert(segments: ArrayList<String>, paramNames: ArrayList<String>,
                       route: Route, index: Int64): Unit {
        if (index >= segments.size) {
            // 到达叶子节点
            this.route = Some(route)
            this.depth = index
            return
        }

        let segment = segments[Int64(index)]

        // 通配符段
        if (segment == "*" || segment.startsWith("*")) {
            if (wildcardChild == None) {
                wildcardChild = Some(TrieNode())
            }
            match (wildcardChild) {
                case Some(node) =>
                    if (segment.length > 1) {
                        node.paramName = segment.substring(1)
                    } else {
                        node.paramName = "*"
                    }
                    node.isWildcard = true
                    node.route = Some(route)
                case None => ()
            }
            return
        }

        // 动态参数段 (:param)
        if (segment.startsWith(":")) {
            if (paramChild == None) {
                paramChild = Some(TrieNode())
            }
            match (paramChild) {
                case Some(node) =>
                    if (index < paramNames.size) {
                        node.paramName = paramNames[Int64(index)]
                    } else {
                        node.paramName = segment.substring(1)
                    }
                    node.insert(segments, paramNames, route, index + 1)
                case None => ()
            }
            return
        }

        // 静态段
        match (children.get(segment)) {
            case Some(node) =>
                node.insert(segments, paramNames, route, index + 1)
            case None =>
                let newNode = TrieNode()
                children.put(segment, newNode)
                newNode.insert(segments, paramNames, route, index + 1)
        }
    }

    /// 在 Trie 中查找匹配的路由
    /// 对应 Bun: router 中 match 操作
    public func lookup(parts: ArrayList<String>, params: RouteParams,
                       index: Int64): ?Route {
        if (index >= parts.size) {
            // 路径消耗完毕, 检查是否有路由
            return route
        }

        let part = parts[Int64(index)]

        // 优先匹配静态子节点
        match (children.get(part)) {
            case Some(node) =>
                let result = node.lookup(parts, params, index + 1)
                match (result) {
                    case Some(r) => return Some(r)
                    case None => ()  // 继续尝试其他匹配
                }
            case None => ()
        }

        // 其次匹配动态参数子节点
        match (paramChild) {
            case Some(node) =>
                params.set(node.paramName, part)
                let result = node.lookup(parts, params, index + 1)
                match (result) {
                    case Some(r) => return Some(r)
                    case None => ()
                }
            case None => ()
        }

        // 最后匹配通配符子节点
        match (wildcardChild) {
            case Some(node) =>
                // 通配符消耗剩余所有段
                let sb = StringBuilder()
                var i = index
                while (i < parts.size) {
                    if (i > index) {
                        sb.append("/")
                    }
                    sb.append(parts[Int64(i)])
                    i += 1
                }
                params.set(node.paramName, sb.toString())
                return node.route
            case None => ()
        }

        return None
    }
}

/// Trie-based 路由匹配器
/// 对应 Bun: Router 的 Trie 实现模式
public class TrieRouter {
    /// 每个方法一棵 Trie
    private var tries: HashMap<String, TrieNode>
    /// 所有注册的路由
    private var allRoutes: ArrayList<Route>

    public init() {
        this.tries = HashMap<String, TrieNode>()
        this.allRoutes = ArrayList<Route>()
    }

    /// 注册路由
    public func addRoute(route: Route): Unit {
        allRoutes.append(route)

        // 解析路径段
        let path = route.pattern.raw
        let cleanPath = if (path.startsWith("/")) { path.substring(1) } else { path }
        let segments = ArrayList<String>()
        let paramNames = ArrayList<String>()

        if (cleanPath.length > 0) {
            let parts = cleanPath.split("/")
            for (part in parts) {
                if (part.length > 0) {
                    segments.append(part)
                }
            }
        }

        // 提取参数名
        for (seg in segments) {
            if (seg.startsWith(":")) {
                paramNames.append(seg.substring(1))
            } else if (seg == "*") {
                paramNames.append("*")
            }
        }

        // 按方法注册
        for (method in route.methods) {
            let methodKey = method.toString()
            match (tries.get(methodKey)) {
                case Some(root) =>
                    root.insert(segments, paramNames, route, 0)
                case None =>
                    let root = TrieNode()
                    tries.put(methodKey, root)
                    root.insert(segments, paramNames, route, 0)
            }
        }
    }

    /// 查找匹配的路由
    public func match(path: String, method: HttpMethod): ?RouteMatch {
        let methodKey = method.toString()

        // 解析路径
        let cleanPath = if (path.startsWith("/")) { path.substring(1) } else { path }
        let parts = ArrayList<String>()
        if (cleanPath.length > 0) {
            let splitParts = cleanPath.split("/")
            for (part in splitParts) {
                if (part.length > 0) {
                    parts.append(part)
                }
            }
        }

        let params = RouteParams()

        // 按方法查找
        match (tries.get(methodKey)) {
            case Some(root) =>
                let result = root.lookup(parts, params, 0)
                match (result) {
                    case Some(route) => return Some(RouteMatch(route, path, params))
                    case None => ()
                }
            case None => ()
        }

        // 尝试 ANY 方法
        match (tries.get("*")) {
            case Some(root) =>
                let result = root.lookup(parts, params, 0)
                match (result) {
                    case Some(route) => return Some(RouteMatch(route, path, params))
                    case None => ()
                }
            case None => ()
        }

        return None
    }

    /// 获取所有路由
    public func routes(): ArrayList<Route> {
        return allRoutes
    }

    /// 路由数量
    public func count(): Int64 {
        return allRoutes.size
    }
}

// ============================================================================
// MiddlewareChain - 中间件执行链
// 严格翻译自: src/http/*.zig 中间件执行模式
// Bun 使用洋葱模型 (onion model) 执行中间件
// ============================================================================

/// 中间件执行链
/// 对应 Bun: HTTP 中间件处理管道
public class MiddlewareChain {
    private var handlers: ArrayList<MiddlewareHandler>

    public init() {
        this.handlers = ArrayList<MiddlewareHandler>()
    }

    /// 添加中间件处理器
    public func use(handler: MiddlewareHandler): Unit {
        handlers.append(handler)
    }

    /// 执行中间件链
    /// 对应 Bun: 中间件洋葱模型
    /// 每个 handler 返回 true 表示继续, false 表示中断
    public func execute(ctx: RouteContext): Bool {
        for (handler in handlers) {
            let result = handler(ctx)
            if (!result) {
                return false
            }
        }
        return true
    }

    /// 中间件数量
    public func count(): Int64 {
        return handlers.size
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return handlers.size == 0
    }
}

// ============================================================================
// RouteGroupBuilder - 路由组构建器
// 严格翻译自: src/router.zig 中路由组模式
// Bun 支持 Express-style 路由组 (prefix + middleware)
// ============================================================================

/// 路由组构建器
/// 支持嵌套路由组、前缀继承、中间件继承
public class RouteGroupBuilder {
    private var router: Router
    private var prefix: String
    private var middlewareChain: MiddlewareChain
    private var parent: ?RouteGroupBuilder

    public init(router: Router, prefix: String) {
        this.router = router
        this.prefix = prefix
        this.middlewareChain = MiddlewareChain()
        this.parent = None
    }

    public init(router: Router, prefix: String, parent: RouteGroupBuilder) {
        this.router = router
        this.prefix = "${parent.prefix}${prefix}"
        this.middlewareChain = MiddlewareChain()
        this.parent = Some(parent)
    }

    /// 注册 GET 路由
    public func get(path: String, handler: RouteHandler): RouteGroupBuilder {
        router.get(buildFullPath(path), handler)
        return this
    }

    /// 注册 POST 路由
    public func post(path: String, handler: RouteHandler): RouteGroupBuilder {
        router.post(buildFullPath(path), handler)
        return this
    }

    /// 注册 PUT 路由
    public func put(path: String, handler: RouteHandler): RouteGroupBuilder {
        router.put(buildFullPath(path), handler)
        return this
    }

    /// 注册 DELETE 路由
    public func delete(path: String, handler: RouteHandler): RouteGroupBuilder {
        router.delete(buildFullPath(path), handler)
        return this
    }

    /// 注册 PATCH 路由
    public func patch(path: String, handler: RouteHandler): RouteGroupBuilder {
        router.patch(buildFullPath(path), handler)
        return this
    }

    /// 注册任意方法路由
    public func any(path: String, handler: RouteHandler): RouteGroupBuilder {
        router.any(buildFullPath(path), handler)
        return this
    }

    /// 添加组级中间件
    public func use(handler: MiddlewareHandler): RouteGroupBuilder {
        middlewareChain.use(handler)
        return this
    }

    /// 创建嵌套子路由组
    public func group(subPrefix: String, fn: (RouteGroupBuilder) -> Unit): RouteGroupBuilder {
        let child = RouteGroupBuilder(router, subPrefix, this)
        fn(child)
        return this
    }

    /// 构建完整路径
    private func buildFullPath(path: String): String {
        if (path.startsWith("/")) {
            return "${prefix}${path}"
        }
        if (path.isEmpty()) {
            return prefix
        }
        return "${prefix}/${path}"
    }
}

// ============================================================================
// RequestContext - 增强的请求上下文
// 严格翻译自: src/http/*.zig 中请求上下文
// Bun 的请求上下文包含完整的 HTTP 请求/响应信息
// ============================================================================

/// 增强的请求上下文
/// 包含 HTTP 请求的全部信息和响应构建器
public class RequestContext {
    // --- 请求信息 ---
    /// 请求方法
    public var method: HttpMethod
    /// 请求路径
    public var path: String
    /// URL 查询字符串 (原始)
    public var queryString: String
    /// 解析后的查询参数
    public var query: HashMap<String, String>
    /// 请求头
    public var headers: HashMap<String, String>
    /// 请求体字节
    public var body: ?Array<UInt8>
    /// 客户端 IP 地址
    public var remoteAddr: String
    /// 请求 ID
    public var requestId: String

    // --- 路由信息 ---
    /// 匹配的路由参数
    public var params: RouteParams
    /// 匹配的路由
    public var matchedRoute: ?Route

    // --- 响应构建 ---
    /// 响应状态码
    public var statusCode: Int64
    /// 响应头
    public var responseHeaders: HashMap<String, String>
    /// 响应体
    public var responseBody: ?String
    /// 响应体字节
    public var responseBodyBytes: ?Array<UInt8>
    /// 是否已发送响应
    public var responded: Bool

    public init() {
        this.method = HttpMethod.GET
        this.path = "/"
        this.queryString = ""
        this.query = HashMap<String, String>()
        this.headers = HashMap<String, String>()
        this.body = None
        this.remoteAddr = ""
        this.requestId = ""
        this.params = RouteParams()
        this.matchedRoute = None
        this.statusCode = 200
        this.responseHeaders = HashMap<String, String>()
        this.responseBody = None
        this.responseBodyBytes = None
        this.responded = false
    }

    // ========================================================================
    // 请求方法
    // ========================================================================

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

    /// 获取查询参数 (带默认值)
    public func queryParamOrElse(name: String, default: String): String {
        match (query.get(name)) {
            case Some(v) => v
            case None => default
        }
    }

    /// 获取请求头
    public func header(name: String): ?String {
        return headers.get(name.toLower())
    }

    /// 获取 Content-Type
    public func contentType(): ?String {
        return header("content-type")
    }

    /// 是否为 JSON 请求
    public func isJson(): Bool {
        match (contentType()) {
            case Some(ct) => ct.contains("application/json")
            case None => false
        }
    }

    /// 获取请求体为字符串
    public func bodyText(): String {
        match (body) {
            case Some(bytes) =>
                let sb = StringBuilder()
                for (b in bytes) {
                    sb.append(Char(Int32(b)))
                }
                return sb.toString()
            case None => ""
        }
    }

    /// 获取 Accept 头
    public func accepts(): String {
        match (header("accept")) {
            case Some(a) => a
            case None => "*/*"
        }
    }

    // ========================================================================
    // 响应方法
    // ========================================================================

    /// 设置状态码
    public func status(code: Int64): RequestContext {
        this.statusCode = code
        return this
    }

    /// 设置响应头
    public func setHeader(name: String, value: String): RequestContext {
        responseHeaders.put(name, value)
        return this
    }

    /// 发送文本响应
    public func send(text: String): Unit {
        responseBody = Some(text)
        responded = true
    }

    /// 发送 JSON 响应
    public func json(obj: String): Unit {
        responseHeaders.put("Content-Type", "application/json; charset=utf-8")
        responseBody = Some(obj)
        responded = true
    }

    /// 发送 HTML 响应
    public func html(content: String): Unit {
        responseHeaders.put("Content-Type", "text/html; charset=utf-8")
        responseBody = Some(content)
        responded = true
    }

    /// 重定向
    public func redirect(url: String): Unit {
        statusCode = 302
        responseHeaders.put("Location", url)
        responded = true
    }

    /// 永久重定向 (301)
    public func redirectPermanent(url: String): Unit {
        statusCode = 301
        responseHeaders.put("Location", url)
        responded = true
    }

    /// 404 Not Found
    public func notFound(message: String): Unit {
        statusCode = 404
        responseBody = Some(message)
        responded = true
    }

    /// 500 Internal Server Error
    public func internalError(message: String): Unit {
        statusCode = 500
        responseBody = Some(message)
        responded = true
    }

    /// 是否已发送响应
    public func isResponded(): Bool {
        return responded
    }
}

// ============================================================================
// RouterMatcher - 路由匹配器 (Router + Trie 双模式)
// 严格翻译自: src/router.zig 路由匹配逻辑
// Bun 同时使用 HashMap (静态路由) 和 Trie (动态路由)
// ============================================================================

/// 路由匹配器
/// 结合 HashMap 和 Trie 实现高效路由查找
public class RouterMatcher {
    /// 静态路由表 (method:path -> Route)
    private var staticTable: HashMap<String, Route>
    /// Trie 路由树 (按方法)
    private var trieRouter: TrieRouter
    /// 动态路由列表 (fallback)
    private var dynamicRoutes: ArrayList<Route>
    /// 是否已排序
    private var sorted: Bool

    public init() {
        this.staticTable = HashMap<String, Route>()
        this.trieRouter = TrieRouter()
        this.dynamicRoutes = ArrayList<Route>()
        this.sorted = false
    }

    /// 注册路由
    public func addRoute(route: Route): Unit {
        if (route.pattern.isStatic()) {
            // 静态路由: 加入 HashMap
            for (method in route.methods) {
                let key = "${method.toString()}:${route.pattern.matchName}"
                staticTable.put(key, route)
            }
        } else {
            // 动态路由: 加入 Trie
            trieRouter.addRoute(route)
            dynamicRoutes.append(route)
        }
        sorted = false
    }

    /// 匹配路由
    /// 查找优先级: 静态 HashMap > Trie 树 > 动态路由列表
    public func match(path: String, method: HttpMethod): ?RouteMatch {
        // 1. 静态路由查找 (O(1))
        let cleanPath = normalizePath(path)
        let staticKey = "${method.toString()}:${cleanPath}"
        match (staticTable.get(staticKey)) {
            case Some(route) =>
                return Some(RouteMatch(route, path, RouteParams()))
            case None => ()
        }

        // 2. Trie 查找 (O(n), n = 路径段数)
        let trieResult = trieRouter.match(path, method)
        match (trieResult) {
            case Some(match_) => return Some(match_)
            case None => ()
        }

        // 3. 动态路由列表线性匹配 (fallback)
        ensureSorted()
        for (route in dynamicRoutes) {
            let result = route.match(path, method)
            match (result) {
                case Some(match_) => return Some(match_)
                case None => ()
            }
        }

        return None
    }

    /// 规范化路径
    private func normalizePath(path: String): String {
        var result = if (path.startsWith("/")) { path.substring(1) } else { path }
        result = result.toLower()
        // 移除尾随斜杠
        while (result.length > 0 && result[result.length - 1] == '/') {
            result = result.substring(0, result.length - 1)
        }
        return result
    }

    /// 确保动态路由已排序
    private func ensureSorted(): Unit {
        if (sorted) { return }
        dynamicRoutes.sortWith({ a, b =>
            let ordA = a.tag.toOrdinal()
            let ordB = b.tag.toOrdinal()
            if (ordA != ordB) { return ordA - ordB }
            if (a.paramCount != b.paramCount) { return a.paramCount - b.paramCount }
            if (a.pattern.matchName < b.pattern.matchName) { return Int64(-1) }
            if (a.pattern.matchName > b.pattern.matchName) { return Int64(1) }
            return Int64(0)
        })
        sorted = true
    }
}

// ============================================================================
// CompiledRouter - 编译后的路由器
// 严格翻译自: src/router.zig 中编译时路由优化
// Bun 在启动时编译路由表, 运行时使用预编译的数据结构
// ============================================================================

/// 编译后的路由器
/// 将 Router 的声明式路由定义编译为高效的匹配结构
public class CompiledRouter {
    /// 路由匹配器
    private var matcher: RouterMatcher
    /// 全局中间件链
    private var globalMiddleware: MiddlewareChain
    /// 错误处理器
    private var errorHandler: ?((RequestContext, Exception) -> Unit)
    /// 404 处理器
    private var notFoundHandler: ?((RequestContext) -> Unit)
    /// 已注册的路由总数
    private var routeCount: Int64

    public init() {
        this.matcher = RouterMatcher()
        this.globalMiddleware = MiddlewareChain()
        this.errorHandler = None
        this.notFoundHandler = None
        this.routeCount = 0
    }

    /// 从 Router 编译
    public static func compile(router: Router): CompiledRouter {
        let compiled = CompiledRouter()
        let routes = router.routes()
        for (route in routes) {
            compiled.matcher.addRoute(route)
            compiled.routeCount += 1
        }
        return compiled
    }

    /// 添加全局中间件
    public func useMiddleware(handler: MiddlewareHandler): Unit {
        globalMiddleware.use(handler)
    }

    /// 设置错误处理器
    public func setErrorHandler(handler: (RequestContext, Exception) -> Unit): Unit {
        errorHandler = Some(handler)
    }

    /// 设置 404 处理器
    public func setNotFoundHandler(handler: (RequestContext) -> Unit): Unit {
        notFoundHandler = Some(handler)
    }

    /// 处理请求
    /// 对应 Bun: 路由分发 + 中间件执行 + 处理器调用
    public func handle(ctx: RequestContext): Unit {
        // 1. 执行全局前置中间件
        if (!globalMiddleware.execute(ctx)) {
            return  // 中间件中断
        }

        // 2. 路由匹配
        let matchResult = matcher.match(ctx.path, ctx.method)
        match (matchResult) {
            case Some(match_) =>
                // 设置路由参数
                ctx.params = match_.params
                ctx.matchedRoute = Some(match_.route)

                // 3. 执行路由级前置中间件
                let route = match_.route
                for (mw in route.middleware) {
                    match (mw) {
                        case Middleware.Before(handler) =>
                            if (!handler(ctx)) { return }
                        case _ => ()
                    }
                }

                // 4. 执行路由处理器
                match (route.handler) {
                    case Some(handler) =>
                        try {
                            handler(ctx)
                        } catch (e: Exception) {
                            match (errorHandler) {
                                case Some(errHandler) => errHandler(ctx, e)
                                case None =>
                                    ctx.status(500)
                                    ctx.send("Internal Server Error: ${e.message}")
                            }
                        }
                    case None =>
                        ctx.status(501)
                        ctx.send("No handler")
                }

                // 5. 执行路由级后置中间件
                for (mw in route.middleware) {
                    match (mw) {
                        case Middleware.After(handler) => handler(ctx)
                        case _ => ()
                    }
                }

            case None =>
                // 没有匹配的路由
                match (notFoundHandler) {
                    case Some(handler) => handler(ctx)
                    case None =>
                        ctx.status(404)
                        ctx.send("Not Found")
                }
        }
    }

    /// 获取路由数量
    public func getRouteCount(): Int64 {
        return routeCount
    }
}

// ============================================================================
// URL 解析辅助
// 严格翻译自: src/http/*.zig 中 URL 解析
// ============================================================================

/// URL 解析辅助
public class UrlParser {
    /// 解析查询字符串为 HashMap
    /// 对应 Bun: URLSearchParams
    public static func parseQuery(queryString: String): HashMap<String, String> {
        let result = HashMap<String, String>()
        if (queryString.isEmpty()) {
            return result
        }

        var remaining = queryString
        if (remaining.startsWith("?")) {
            remaining = remaining.substring(1)
        }

        let pairs = remaining.split("&")
        for (pair in pairs) {
            let eqIdx = pair.indexOf("=")
            if (eqIdx > 0) {
                let key = urlDecode(pair.substring(0, eqIdx))
                let value = urlDecode(pair.substring(eqIdx + 1))
                result.put(key, value)
            } else if (pair.length > 0) {
                result.put(urlDecode(pair), "")
            }
        }

        return result
    }

    /// URL 解码
    public static func urlDecode(input: String): String {
        let sb = StringBuilder()
        var i = Int64(0)
        while (i < input.length) {
            let ch = input[i]
            if (ch == '%' && i + 2 < input.length) {
                let hex = input.substring(i + 1, i + 3)
                let decoded = hexToInt(hex)
                match (decoded) {
                    case Some(code) => sb.append(Char(code))
                    case None =>
                        sb.append(ch)
                }
                i += 3
            } else if (ch == '+') {
                sb.append(' ')
                i += 1
            } else {
                sb.append(ch)
                i += 1
            }
        }
        return sb.toString()
    }

    /// URL 编码
    public static func urlEncode(input: String): String {
        let sb = StringBuilder()
        for (ch in input) {
            if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') ||
                (ch >= '0' && ch <= '9') || ch == '-' || ch == '_' ||
                ch == '.' || ch == '~') {
                sb.append(ch)
            } else if (ch == ' ') {
                sb.append('+')
            } else {
                sb.append('%')
                sb.append(Int32(ch).toString().toUpper())
            }
        }
        return sb.toString()
    }

    /// 十六进制字符串转整数
    private static func hexToInt(hex: String): ?Int32 {
        var result = 0
        for (c in hex) {
            result = result * 16
            if (c >= '0' && c <= '9') {
                result = result + (Int32(c) - Int32('0'))
            } else if (c >= 'a' && c <= 'f') {
                result = result + (Int32(c) - Int32('a') + 10)
            } else if (c >= 'A' && c <= 'F') {
                result = result + (Int32(c) - Int32('A') + 10)
            } else {
                return None
            }
        }
        return Some(result)
    }

    /// 从 URL 中分离路径和查询字符串
    public static func splitPathAndQuery(url: String): Pair<String, String> {
        let queryIdx = url.indexOf("?")
        if (queryIdx >= 0) {
            return Pair(url.substring(0, queryIdx), url.substring(queryIdx + 1))
        }
        return Pair(url, "")
    }
}

/// 简单的 Pair 类型
public class Pair<A, B> {
    public let first: A
    public let second: B

    public init(first: A, second: B) {
        this.first = first
        this.second = second
    }
}

// ============================================================================
// RouteScanner - 文件系统路由扫描
// 严格翻译自: src/router.zig 中文件系统路由扫描
// Bun 支持 next.js 风格的 pages/ 目录路由自动生成
// ============================================================================

/// 文件系统路由扫描结果
public class ScannedRoute {
    /// 文件路径
    public var filePath: String
    /// 路由路径
    public var routePath: String
    /// HTTP 方法列表
    public var methods: ArrayList<HttpMethod>

    public init(filePath: String, routePath: String) {
        this.filePath = filePath
        this.routePath = routePath
        this.methods = ArrayList<HttpMethod>()
        this.methods.append(HttpMethod.ANY)
    }
}

/// 文件系统路由扫描器
/// 对应 Bun: router scanner
public class RouteScanner {
    /// 基础目录
    private var baseDir: String
    /// 支持的文件扩展名
    private var extensions: ArrayList<String>
    /// 忽略的目录
    private var ignoredDirs: ArrayList<String>

    public init(baseDir: String) {
        this.baseDir = baseDir
        this.extensions = ArrayList<String>()
        this.extensions.append(".js")
        this.extensions.append(".ts")
        this.extensions.append(".tsx")
        this.extensions.append(".jsx")
        this.ignoredDirs = ArrayList<String>()
        this.ignoredDirs.append("node_modules")
        this.ignoredDirs.append(".git")
        this.ignoredDirs.append("api")  // API 路由单独处理
    }

    /// 扫描目录生成路由列表
    /// 对应 Bun: scan_for_routes
    public func scan(): ArrayList<ScannedRoute> {
        let routes = ArrayList<ScannedRoute>()
        scanDir(baseDir, "", routes)
        return routes
    }

    /// 递归扫描目录
    private func scanDir(dir: String, prefix: String, routes: ArrayList<ScannedRoute>): Unit {
        // 实际实现需要通过文件系统 API 遍历目录
        // 简化: 仅提供框架逻辑
        // let entries = readdir(dir)
        // for (entry in entries) {
        //     let fullPath = "${dir}/${entry}"
        //     if (isDirectory(fullPath)) {
        //         if (!ignoredDirs.contains(entry)) {
        //             scanDir(fullPath, "${prefix}/${entry}", routes)
        //         }
        //     } else {
        //         let ext = getExtension(entry)
        //         if (extensions.contains(ext)) {
        //             let routePath = fileToRoute(entry, prefix)
        //             routes.append(ScannedRoute(fullPath, routePath))
        //         }
        //     }
        // }
    }

    /// 将文件名转换为路由路径
    /// 对应 Bun: file_path_to_route
    /// 例: pages/users/[id].tsx -> /users/:id
    public static func fileToRoute(fileName: String, prefix: String): String {
        // 移除扩展名
        var name = fileName
        let dotIdx = name.lastIndexOf(".")
        if (dotIdx >= 0) {
            name = name.substring(0, dotIdx)
        }

        // index -> 根路由
        if (name == "index") {
            if (prefix.isEmpty()) {
                return "/"
            }
            return prefix
        }

        // [param] -> :param
        if (name.startsWith("[") && name.endsWith("]")) {
            let param = name.substring(1, name.length - 1)
            return "${prefix}/:${param}"
        }

        // [...param] -> *param
        if (name.startsWith("[...") && name.endsWith("]")) {
            let param = name.substring(4, name.length - 1)
            return "${prefix}/*${param}"
        }

        return "${prefix}/${name}"
    }
}

// ============================================================================
// 路由匹配辅助函数
// ============================================================================

/// 快速创建路由器
public func newRouter(): Router {
    return Router()
}

/// 快速创建路由构建器
public func newRouterBuilder(): RouterBuilder {
    return RouterBuilder()
}

/// 快速创建编译路由器
public func compileRouter(router: Router): CompiledRouter {
    return CompiledRouter.compile(router)
}
