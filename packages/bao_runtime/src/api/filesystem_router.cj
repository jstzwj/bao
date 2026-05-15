// 严格翻译自: src/runtime/api/filesystem_router.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_sys.*
import bao_io.*
import bao_collections.*

// ============================================================================
// 默认文件扩展名
// ========================================================================

/// 文件系统路由器默认识别的文件扩展名
public let DEFAULT_EXTENSIONS = ["tsx", "jsx", "ts", "mjs", "cjs", "js"]

// ============================================================================
// FileSystemRouter - 文件系统路由器
// 对应 Bun: src/runtime/api/filesystem_router.zig
// ========================================================================

/// 文件系统路由器，基于文件结构自动生成路由
public class FileSystemRouter {
    var origin: RefString = null
    var baseDir: RefString = null
    var router: Router
    var arena: ArenaAllocator = uninitialized
    var allocator: Allocator = uninitialized
    var assetPrefix: RefString = null

    // ========================================================================
    // 构造函数
    // ========================================================================

    /// 从 JS 参数构造文件系统路由器
    public static func constructor(globalThis: JsGlobalObject, callframe: JsCallFrame): FileSystemRouter {
        let argument = callframe.argumentsOld(1)
        if (argument.len == 0) {
            return globalThis.throwInvalidArguments("Expected object")
        }

        let arg = argument.ptr[0]
        if (arg.isEmptyOrUndefinedOrNull() || !arg.isObject()) {
            return globalThis.throwInvalidArguments("Expected object")
        }
        var vm = globalThis.bunVM()

        var rootDirPath = ZigString.Slice.fromUTF8NeverFree(vm.transpiler.fs.top_level_dir)
        defer rootDirPath.deinit()
        var originStr = ZigString.Slice.empty
        var assetPrefixSlice = ZigString.Slice.empty

        var outBuf = PathBuffer()

        // style 参数
        if (let styleVal = try arg.get(globalThis, "style")) {
            let styleStr = try styleVal.getZigString(globalThis)
            if (!styleStr.eqlComptime("nextjs")) {
                return globalThis.throwInvalidArguments("Only 'nextjs' style is currently implemented")
            }
        } else {
            return globalThis.throwInvalidArguments("Expected 'style' option (ex: \"style\": \"nextjs\")")
        }

        // dir 参数
        if (let dir = try arg.get(globalThis, "dir")) {
            if (!dir.isString()) {
                return globalThis.throwInvalidArguments("Expected dir to be a string")
            }
            let rootDirPath_ = try dir.toSlice(globalThis, globalThis.allocator())
            if (!(rootDirPath_.len == 0 || Strings.eqlComptime(rootDirPath_.slice(), "."))) {
                let path = rootDirPath_.slice()
                if (Path.Platform.isAbsolute(.auto, path)) {
                    rootDirPath = rootDirPath_
                } else {
                    var parts = [path]
                    rootDirPath = ZigString.Slice.fromUTF8NeverFree(
                        Path.joinAbsStringBuf(Fs.FileSystem.instance.top_level_dir, outBuf, parts, .auto)
                    )
                }
            }
        } else {
            return globalThis.throwInvalidArguments("Expected dir to be a string")
        }

        // 创建 Arena 分配器
        var arena = globalThis.allocator().create(ArenaAllocator) catch { unreachable }
        arena = ArenaAllocator.init(globalThis.allocator())
        let allocator = arena.allocator()
        var extensions = ArrayList<String>.init(allocator)

        // fileExtensions 参数
        if (let fileExtensions = try arg.get(globalThis, "fileExtensions")) {
            if (!fileExtensions.jsType().isArray()) {
                originStr.deinit()
                arena.deinit()
                globalThis.allocator().destroy(arena)
                return globalThis.throwInvalidArguments("Expected fileExtensions to be an Array")
            }

            var iter = try fileExtensions.arrayIterator(globalThis)
            extensions.ensureTotalCapacityPrecise(iter.len) catch { unreachable }
            while (let val = try iter.next()) {
                if (!val.isString()) {
                    originStr.deinit()
                    arena.deinit()
                    globalThis.allocator().destroy(arena)
                    return globalThis.throwInvalidArguments("Expected fileExtensions to be an Array of strings")
                }
                if (try val.getLength(globalThis) == 0) { continue }
                extensions.appendAssumeCapacity((try val.toUTF8Bytes(globalThis, allocator))[1..])
            }
        }

        // assetPrefix 参数
        if (let assetPrefix = try arg.getTruthy(globalThis, "assetPrefix")) {
            if (!assetPrefix.isString()) {
                originStr.deinit()
                arena.deinit()
                globalThis.allocator().destroy(arena)
                return globalThis.throwInvalidArguments("Expected assetPrefix to be a string")
            }

            assetPrefixSlice = try (try assetPrefix.toSlice(globalThis, allocator)).cloneIfBorrowed(allocator)
        }

        let origLog = vm.transpiler.resolver.log
        var log = Logger.Log.init(allocator)
        vm.transpiler.resolver.log = log
        defer vm.transpiler.resolver.log = origLog

        let pathToUse = (rootDirPath.cloneWithTrailingSlash(allocator) catch { unreachable }).slice()

        let rootDirInfo = vm.transpiler.resolver.readDirInfo(pathToUse) catch {
            let errValue = log.toJS(globalThis, globalThis.allocator(), "reading root directory")
            originStr.deinit()
            arena.deinit()
            globalThis.allocator().destroy(arena)
            return globalThis.throwValue(try errValue)
        } ?? {
            originStr.deinit()
            arena.deinit()
            globalThis.allocator().destroy(arena)
            return globalThis.throw("Unable to find directory: \{rootDirPath.slice()}")
        }

        // 初始化路由器
        var router = Router.init(vm.transpiler.fs, allocator, RouterConfig{
            dir = pathToUse,
            extensions = if (extensions.items.len > 0) extensions.items else DEFAULT_EXTENSIONS,
            asset_prefix_path = assetPrefixSlice.slice(),
        }) catch { unreachable }

        router.loadRoutes(log, rootDirInfo, Resolver, vm.transpiler.resolver, router.config.dir) catch {
            let errValue = log.toJS(globalThis, globalThis.allocator(), "loading routes")
            originStr.deinit()
            arena.deinit()
            globalThis.allocator().destroy(arena)
            return globalThis.throwValue(try errValue)
        }

        // origin 参数
        if (let origin = try arg.get(globalThis, "origin")) {
            if (!origin.isString()) {
                arena.deinit()
                globalThis.allocator().destroy(arena)
                return globalThis.throwInvalidArguments("Expected origin to be a string")
            }
            originStr = try origin.toSlice(globalThis, globalThis.allocator())
        }

        // 检查错误
        if (log.errors + log.warnings > 0) {
            let errValue = log.toJS(globalThis, globalThis.allocator(), "loading routes")
            originStr.deinit()
            arena.deinit()
            globalThis.allocator().destroy(arena)
            return globalThis.throwValue(try errValue)
        }

        // 创建最终对象
        var fsRouter = globalThis.allocator().create(FileSystemRouter) catch { unreachable }
        fsRouter = FileSystemRouter{
            origin = if (originStr.len > 0) vm.refCountedString(originStr.slice(), null, true) else null,
            baseDir = vm.refCountedString(
                if (rootDirInfo.abs_real_path.len > 0) rootDirInfo.abs_real_path else rootDirInfo.abs_path,
                null,
                true,
            ),
            assetPrefix = if (assetPrefixSlice.len > 0) vm.refCountedString(assetPrefixSlice.slice(), null, true) else null,
            router = router,
            arena = arena,
            allocator = allocator,
        }

        router.config.dir = fsRouter.baseDir.slice()
        fsRouter.baseDir.ref()

        return fsRouter
    }

    // ========================================================================
    // Getter 方法
    // ========================================================================

    /// 获取 origin
    public func getOrigin(globalThis: JsGlobalObject): JsValue {
        if (let origin = this.origin) {
            return ZigString.init(origin.slice()).withEncoding().toJS(globalThis)
        }
        return JsValue.jsNull()
    }

    /// 获取路由表
    public func getRoutes(globalThis: JsGlobalObject): JsValue {
        let paths = this.router.getEntryPoints()
        let names = this.router.getNames()
        var nameStrings = try default_allocator.alloc(ZigString, names.len * 2)
        defer default_allocator.free(nameStrings)
        var pathsStrings = nameStrings[names.len..]
        for ((name, i) in names.enumerated()) {
            nameStrings[i] = ZigString.init(name).withEncoding()
            pathsStrings[i] = ZigString.init(paths[i]).withEncoding()
        }
        return JsValue.fromEntries(globalThis, nameStrings.ptr, pathsStrings.ptr, names.len, true)
    }

    /// 获取 style
    public func getStyle(globalThis: JsGlobalObject): JsValue {
        return BunString.static("nextjs").toJS(globalThis)
    }

    /// 获取 assetPrefix
    public func getAssetPrefix(globalThis: JsGlobalObject): JsValue {
        if (let assetPrefix = this.assetPrefix) {
            return ZigString.init(assetPrefix.slice()).withEncoding().toJS(globalThis)
        }
        return JsValue.jsNull()
    }

    // ========================================================================
    // match - 路由匹配
    // ========================================================================

    /// 匹配请求路径到路由
    public func match(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let argument = callframe.argumentsOld(2)
        if (argument.len == 0) {
            return globalThis.throwInvalidArguments("Expected string, Request or Response")
        }

        let arg = argument.ptr[0]
        if (arg.isEmptyOrUndefinedOrNull() || !arg.isCell()) {
            return globalThis.throwInvalidArguments("Expected string, Request or Response")
        }

        var path = {
            if (arg.isString()) {
                return try (try arg.toSlice(globalThis, globalThis.allocator())).cloneIfBorrowed(globalThis.allocator())
            }

            if (arg.isCell()) {
                if (let req = arg.as(Request)) {
                    req.ensureURL() catch { unreachable }
                    return req.url.toUTF8(globalThis.allocator())
                }

                if (let resp = arg.as(Response)) {
                    return resp.getUTF8Url(globalThis.allocator())
                }
            }

            return globalThis.throwInvalidArguments("Expected string, Request or Response")
        }

        if (path.len == 0 || (path.len == 1 && path.ptr[0] == '/')) {
            path.deinit()
            path = ZigString.Slice.fromUTF8NeverFree("/")
        }

        if (Strings.hasPrefixComptime(path.slice(), "http://") ||
            Strings.hasPrefixComptime(path.slice(), "https://") ||
            Strings.hasPrefixComptime(path.slice(), "file://")) {
            let prevPath = path
            defer prevPath.deinit()
            path = try ZigString.Slice.initDupe(globalThis.allocator(), URL.parse(path.slice()).pathname)
        }

        let urlPath = URLPath.parse(path.slice()) catch { err =>
            return globalThis.throw("\{err} parsing path: \{path.slice()}")
        }

        var params = Router.Param.List{}
        defer params.deinit(globalThis.allocator())

        let route = this.router.routes.matchPageWithAllocator(
            "",
            urlPath,
            params,
            globalThis.allocator(),
        ) ?? {
            return JsValue.jsNull()
        }

        var result = MatchedRoute.init(
            globalThis.allocator(),
            route,
            this.origin,
            this.assetPrefix,
            this.baseDir,
        ) catch { unreachable }

        return result.toJS(globalThis)
    }

    // ========================================================================
    // reload / bustDirCache
    // ========================================================================

    /// 重新加载路由
    public func reload(globalThis: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let thisValue = callframe.this()

        var arena = globalThis.allocator().create(ArenaAllocator) catch { unreachable }
        arena = ArenaAllocator.init(globalThis.allocator())

        var allocator = arena.allocator()
        var vm = globalThis.bunVM()

        let origLog = vm.transpiler.resolver.log
        var log = Logger.Log.init(allocator)
        vm.transpiler.resolver.log = log
        defer vm.transpiler.resolver.log = origLog

        this.bustDirCache(globalThis)

        let rootDirInfo = vm.transpiler.resolver.readDirInfo(this.router.config.dir) catch {
            let errValue = log.toJS(globalThis, globalThis.allocator(), "reading root directory")
            arena.deinit()
            globalThis.allocator().destroy(arena)
            return globalThis.throwValue(try errValue)
        } ?? {
            arena.deinit()
            globalThis.allocator().destroy(arena)
            return globalThis.throw("Unable to find directory: \{this.router.config.dir}")
        }

        var router = Router.init(vm.transpiler.fs, allocator, RouterConfig{
            dir = allocator.dupe(UInt8, this.router.config.dir) catch { unreachable },
            extensions = allocator.dupe(String, this.router.config.extensions) catch { unreachable },
            asset_prefix_path = this.router.config.asset_prefix_path,
        }) catch { unreachable }

        router.loadRoutes(log, rootDirInfo, Resolver, vm.transpiler.resolver, router.config.dir) catch {
            let errValue = log.toJS(globalThis, globalThis.allocator(), "loading routes")
            arena.deinit()
            globalThis.allocator().destroy(arena)
            return globalThis.throwValue(try errValue)
        }

        this.router.deinit()
        this.arena.deinit()
        globalThis.allocator().destroy(this.arena)

        this.arena = arena
        this.js.routesSetCached(thisValue, globalThis, JsValue.zero)
        this.allocator = allocator
        this.router = router
        return thisValue
    }

    /// 清除目录缓存
    public func bustDirCache(globalThis: JsGlobalObject) {
        this.bustDirCacheRecursive(globalThis, Strings.withoutTrailingSlashWindowsPath(this.router.config.dir))
    }

    /// 递归清除目录缓存
    func bustDirCacheRecursive(globalThis: JsGlobalObject, inputPath: String) {
        var vm = globalThis.bunVM()
        var path = inputPath

        let rootDirInfo = vm.transpiler.resolver.readDirInfo(path) catch { return }

        if (let dir = rootDirInfo) {
            if (let entries = dir.getEntriesConst()) {
                var iter = entries.data.iterator()
                while (let entryPtr = iter.next()) {
                    let entry = entryPtr.value_ptr
                    if (entry.base()[0] == '.') { continue }
                    if (entry.kind(vm.transpiler.fs.fs, false) == .dir) {
                        for (bannedDir in Router.banned_dirs) {
                            if (Strings.eqlComptime(entry.base(), bannedDir)) { continue }
                        }

                        let absParts = [entry.dir, entry.base()]
                        let fullPath = vm.transpiler.fs.abs(absParts)

                        _ = vm.transpiler.resolver.bustDirCache(Strings.withoutTrailingSlashWindowsPath(fullPath))
                        this.bustDirCacheRecursive(globalThis, fullPath)
                    }
                }
            }
        }

        _ = vm.transpiler.resolver.bustDirCache(path)
    }

    /// 终结化
    public func finalize() {
        if (let prefix = this.assetPrefix) { prefix.deref() }
        if (let prefix = this.origin) { prefix.deref() }
        if (let dir = this.baseDir) { dir.deref() }

        this.router.deinit()
        this.arena.deinit()
    }
}

// ============================================================================
// MatchedRoute - 匹配到的路由
// ========================================================================

/// 匹配到的路由信息
public class MatchedRoute {
    var route: Router.Match
    var routeHolder: Router.Match = uninitialized
    var queryStringMap: QueryStringMap = null
    var paramMap: QueryStringMap = null
    var paramsListHolder: Router.Param.List = Router.Param.List{}
    var origin: RefString = null
    var assetPrefix: RefString = null
    var needsDeinit: Bool = true
    var baseDir: RefString = null

    // ========================================================================
    // 初始化
    // ========================================================================

    /// 创建 MatchedRoute
    public static func init(
        allocator: Allocator,
        match: Router.Match,
        origin: RefString,
        assetPrefix: RefString,
        baseDir: RefString,
    ): MatchedRoute {
        let paramsList = try match.params.clone(allocator)

        var route = try allocator.create(MatchedRoute)

        route = MatchedRoute{
            routeHolder = match,
            route = uninitialized,
            assetPrefix = assetPrefix,
            origin = origin,
            baseDir = baseDir,
        }
        baseDir.ref()
        route.paramsListHolder = paramsList
        route.route = route.routeHolder
        route.routeHolder.params = route.paramsListHolder
        if (let o = origin) { o.ref() }
        if (let prefix = assetPrefix) { prefix.ref() }

        return route
    }

    /// 释放资源
    public func deinit() {
        if (let map = this.queryStringMap) { map.deinit() }
        if (let map = this.paramMap) { map.deinit() }
        if (this.needsDeinit) {
            if (this.route.pathname.len > 0 && Mimalloc.mi_is_in_heap_region(this.route.pathname.ptr)) {
                Mimalloc.mi_free(this.route.pathname.ptr)
            }
            this.paramsListHolder.deinit(default_allocator)
            this.paramsListHolder = Router.Param.List{}
        }

        if (let o = this.origin) { o.deref() }
        if (let prefix = this.assetPrefix) { prefix.deref() }
        if (let base = this.baseDir) { base.deref() }

        default_allocator.destroy(this)
    }

    // ========================================================================
    // Getter 方法
    // ========================================================================

    /// 获取文件路径
    public func getFilePath(globalThis: JsGlobalObject): JsValue {
        return ZigString.init(this.route.file_path).withEncoding().toJS(globalThis)
    }

    /// 获取路径名
    public func getPathname(globalThis: JsGlobalObject): JsValue {
        return ZigString.init(this.route.pathname).withEncoding().toJS(globalThis)
    }

    /// 获取路由名
    public func getRoute(globalThis: JsGlobalObject): JsValue {
        return ZigString.init(this.route.name).withEncoding().toJS(globalThis)
    }

    /// 获取名称
    public func getName(globalThis: JsGlobalObject): JsValue {
        return ZigString.init(this.route.name).withEncoding().toJS(globalThis)
    }

    // ========================================================================
    // KindEnum - 路由类型
    // ========================================================================

    public class KindEnum {
        public static let EXACT = "exact"
        public static let CATCH_ALL = "catch-all"
        public static let OPTIONAL_CATCH_ALL = "optional-catch-all"
        public static let DYNAMIC = "dynamic"

        public static func init(name: String): ZigString {
            if (Strings.contains(name, "[[")) {
                return ZigString.init(OPTIONAL_CATCH_ALL)
            } else if (Strings.contains(name, "[...")) {
                return ZigString.init(CATCH_ALL)
            } else if (Strings.contains(name, "[")) {
                return ZigString.init(DYNAMIC)
            } else {
                return ZigString.init(EXACT)
            }
        }
    }

    /// 获取路由类型
    public func getKind(globalThis: JsGlobalObject): JsValue {
        return KindEnum.init(this.route.name).toJS(globalThis)
    }

    /// 获取参数
    public func getParams(globalThis: JsGlobalObject): JsValue {
        if (this.route.params.len == 0) {
            return JsValue.createEmptyObject(globalThis, 0)
        }

        if (this.paramMap == null) {
            this.paramMap = try QueryStringMap.initWithScanner(
                globalThis.allocator(),
                CombinedScanner.init(
                    "",
                    this.route.pathnameWithoutLeadingSlash(),
                    this.route.name,
                    this.route.params,
                ),
            )
        }

        return createQueryObject(globalThis, this.paramMap)
    }

    /// 获取查询字符串
    public func getQuery(globalThis: JsGlobalObject): JsValue {
        if (this.route.query_string.len == 0 && this.route.params.len == 0) {
            return JsValue.createEmptyObject(globalThis, 0)
        } else if (this.route.query_string.len == 0) {
            return this.getParams(globalThis)
        }

        if (this.queryStringMap == null) {
            if (this.route.params.len > 0) {
                this.queryStringMap = try QueryStringMap.initWithScanner(globalThis.allocator(), CombinedScanner.init(
                    this.route.query_string,
                    this.route.pathnameWithoutLeadingSlash(),
                    this.route.name,
                    this.route.params,
                ))
            } else {
                this.queryStringMap = try QueryStringMap.init(globalThis.allocator(), this.route.query_string)
            }
        }

        if (let map = this.queryStringMap) {
            return createQueryObject(globalThis, map)
        }

        return JsValue.createEmptyObject(globalThis, 0)
    }

    /// 获取脚本源路径
    public func getScriptSrc(globalThis: JsGlobalObject): JsValue {
        var buf = PathBuffer()
        var stream = FixedBufferStream(buf)
        var writer = stream.writer()

        BunObject.getPublicPathWithAssetPrefix(
            this.route.file_path,
            if (let baseDir = this.baseDir) baseDir.slice() else VirtualMachine.get().transpiler.fs.top_level_dir,
            if (let origin = this.origin) URL.parse(origin.slice()) else URL{},
            if (let prefix = this.assetPrefix) prefix.slice() else "",
            writer,
            .posix,
        )
        return ZigString.init(buf[0..writer.context.pos]).withEncoding().toJS(globalThis)
    }

    /// 终结化
    public func finalize() {
        this.deinit()
    }
}

/// 创建查询对象
func createQueryObject(ctx: JsGlobalObject, map: QueryStringMap): JsValue {
    let value = JsObject.createWithInitializer(QueryObjectCreator, map, ctx, map.getNameCount())
    return value
}

/// 查询对象创建器
class QueryObjectCreator {
    var query: QueryStringMap

    public func create(obj: JsObject, global: JsGlobalObject) {
        var iter = this.query.iter()
        while (let entry = iter.next()) {
            let entryName = entry.name
            var str = ZigString.init(entryName).withEncoding()

            if (entry.values.len > 1) {
                var values = entry.values.map { v => ZigString.init(v).withEncoding() }
                try obj.putRecord(global, str, values)
            } else {
                let value = ZigString.init(entry.values[0]).withEncoding()
                try obj.putRecord(global, str, [value])
            }
        }
    }
}

// ============================================================================
// 类型别名
// ========================================================================

public let default_allocator = default_allocator
