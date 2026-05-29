// 严格翻译自: src/runtime/api/filesystem_router.zig
package bao_runtime.api

import bao_jsc.*
import bao_collections.ArrayList
import bao_core.Allocator
import bao_sys.*
import bao_io.*
import bao_collections.*
import bao_router.Router

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
    var origin: RefString = none
    var baseDir: RefString = none
    var router: Router
    var arena: ArenaAllocator = ArenaAllocator()
    var allocator: Allocator = ArenaAllocator()
    var assetPrefix: RefString = none

    // ========================================================================
    // 构造函数
    // ========================================================================

    /// 从 JS 参数构造文件系统路由器
    public static func constructor(globalThis!: JsGlobalObject, callframe!: JsCallFrame): FileSystemRouter {
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
        var originStr = ZigString.Slice.empty
        var assetPrefixSlice = ZigString.Slice.empty

        var outBuf = PathBuffer()

        // style 参数
        if (let styleVal <- arg.get(globalThis, "style")) {
            let styleStr = styleVal.getZigString(globalThis) 
            if (!styleStr.eqlComptime("nextjs")) {
                return globalThis.throwInvalidArguments("Only 'nextjs' style is currently implemented")
            }
        } else {
            return globalThis.throwInvalidArguments("Expected 'style' option (ex: \"style\": \"nextjs\")")
        }

        // dir 参数
        if (let dir <- arg.get(globalThis, "dir") ) {
            if (!dir.isString()) {
                return globalThis.throwInvalidArguments("Expected dir to be a string")
            }
            let rootDirPath_ = dir.toSlice(globalThis, globalThis.allocator() )
            if (!(rootDirPath_.len == 0 || Strings.eqlComptime(rootDirPath_.slice(), "."))) {
                let path = rootDirPath_.slice()
                if (Path.Platform.isAbsolute(Path.Platform.auto, path)) {
                    rootDirPath = rootDirPath_
                } else {
                    var parts = [path]
                    rootDirPath = ZigString.Slice.fromUTF8NeverFree(
                        Path.joinAbsStringBuf(Fs.FileSystem.instance.top_level_dir, outBuf, parts, Path.Platform.Posix)
                    )
                }
            }
        } else {
            return globalThis.throwInvalidArguments("Expected dir to be a string")
        }

        // 创建 Arena 分配器
        var arena = ArenaAllocator(globalThis.allocator())
        let allocator = arena.allocator()
        var extensions = ArrayList<String>.`init`(allocator)

        // fileExtensions 参数
        if (let fileExtensions <- arg.get(globalThis, "fileExtensions") ) {
            if (!fileExtensions.jsType().isArray()) {
                originStr.deinit()
                arena.deinit()
                globalThis.allocator().destroy(arena)
                return globalThis.throwInvalidArguments("Expected fileExtensions to be an Array")
            }

            var iter = fileExtensions.arrayIterator(globalThis) 
            extensions.ensureTotalCapacityPrecise(iter.len)
            while (let val <- iter.next() ) {
                if (!val.isString()) {
                    originStr.deinit()
                    arena.deinit()
                    globalThis.allocator().destroy(arena)
                    return globalThis.throwInvalidArguments("Expected fileExtensions to be an Array of strings")
                }
                if (val.getLength(globalThis) == 0) { continue }
                extensions.appendAssumeCapacity((val.toUTF8Bytes(globalThis, allocator) )[1..])
            }
        }

        // assetPrefix 参数
        if (let assetPrefix <- arg.getTruthy(globalThis, "assetPrefix") ) {
            if (!assetPrefix.isString()) {
                originStr.deinit()
                arena.deinit()
                globalThis.allocator().destroy(arena)
                return globalThis.throwInvalidArguments("Expected assetPrefix to be a string")
            }

            let sliceResult = assetPrefix.toSlice(globalThis, allocator)
            assetPrefixSlice = sliceResult.cloneIfBorrowed(allocator)
        }

        let origLog = vm.transpiler.resolver.log
        var log = Logger.Log(allocator)
        vm.transpiler.resolver.log = log
        let pathToUseResult = rootDirPath.cloneWithTrailingSlash(allocator)
        let pathToUseSlice = try { pathToUseResult } catch(_: Exception) { unreachable() }
        let pathToUse = pathToUseSlice.slice()

        let rootDirInfoOptResult = vm.transpiler.resolver.readDirInfo(pathToUse)
        let rootDirInfoOpt = try { rootDirInfoOptResult } catch(_: Exception) {
            let errValue = log.toJS(globalThis, globalThis.allocator(), "reading root directory")
            originStr.deinit()
            arena.deinit()
            globalThis.allocator().destroy(arena)
            return globalThis.throwValue(errValue )
        }
        if (rootDirInfoOpt.isNone()) {
            originStr.deinit()
            arena.deinit()
            globalThis.allocator().destroy(arena)
            return globalThis.`throw`("Unable to find directory: ${rootDirPath.slice()}")
        }
        let rootDirInfo = rootDirInfoOpt.get()

        // 初始化路由器
        let extItems = if (extensions.items.len > 0) { extensions.items } else { DEFAULT_EXTENSIONS }
        var router = Router(vm.transpiler.fs, allocator, RouterConfig{
            dir = pathToUse
            extensions = extItems
            asset_prefix_path = assetPrefixSlice.slice()
        })
        try {
            router.loadRoutes(log, rootDirInfo, Resolver, vm.transpiler.resolver, router.config.dir)
        } catch(_: Exception) {
            let errValue = log.toJS(globalThis, globalThis.allocator(), "loading routes")
            originStr.deinit()
            arena.deinit()
            globalThis.allocator().destroy(arena)
            return globalThis.throwValue(errValue )
        }

        // origin 参数
        if (let origin <- arg.get(globalThis, "origin") ) {
            if (!origin.isString()) {
                arena.deinit()
                globalThis.allocator().destroy(arena)
                return globalThis.throwInvalidArguments("Expected origin to be a string")
            }
            originStr = origin.toSlice(globalThis, globalThis.allocator() )
        }

        // 检查错误
        if (log.errors + log.warnings > 0) {
            let errValue = log.toJS(globalThis, globalThis.allocator(), "loading routes")
            originStr.deinit()
            arena.deinit()
            globalThis.allocator().destroy(arena)
            return globalThis.throwValue(errValue )
        }

        // 创建最终对象
        let originVal = if (originStr.len > 0) { vm.refCountedString(originStr.slice(), none, true) } else { null }
        let basePath = if (rootDirInfo.abs_real_path.len > 0) { rootDirInfo.abs_real_path } else { rootDirInfo.abs_path }
        let baseDirVal = vm.refCountedString(basePath, none, true)
        let assetPrefixVal = if (assetPrefixSlice.len > 0) { vm.refCountedString(assetPrefixSlice.slice(), none, true) } else { null }
        var fsRouter = globalThis.allocator().create(FileSystemRouter)
        fsRouter = FileSystemRouter{
            origin = originVal
            baseDir = baseDirVal
            assetPrefix = assetPrefixVal
            router = router
            arena = arena
            allocator = allocator
        }

        router.config.dir = fsRouter.baseDir.slice()
        fsRouter.baseDir.ref()

        return fsRouter
        vm.transpiler.resolver.log = origLog
        rootDirPath.deinit()
    }

    // ========================================================================
    // Getter 方法
    // ========================================================================

    /// 获取 origin
    public func getOrigin(globalThis!: JsGlobalObject): JsValue {
        if (let origin <- this.origin) {
            return ZigString(origin.slice()).withEncoding().toJS(globalThis)
        }
        return JsValue.jsNull()
    }

    /// 获取路由表
    public func getRoutes(globalThis!: JsGlobalObject): JsValue {
        let paths = this.router.getEntryPoints()
        let names = this.router.getNames()
        var nameStrings = default_allocator.alloc(ZigString, names.len * 2) 
        var pathsStrings = nameStrings[names.len..]
        for ((name, i) in names.enumerated()) {
            nameStrings[i] = ZigString(name).withEncoding()
            pathsStrings[i] = ZigString(paths[i]).withEncoding()
        }
        let result = JsValue.fromEntries(globalThis, nameStrings.ptr, pathsStrings.ptr, names.len, true)
        default_allocator.free(nameStrings)
        return result
    }

    /// 获取 style
    public func getStyle(globalThis!: JsGlobalObject): JsValue {
        return BunString.`static`("nextjs").toJS(globalThis)
    }

    /// 获取 assetPrefix
    public func getAssetPrefix(globalThis!: JsGlobalObject): JsValue {
        if (let assetPrefix <- this.assetPrefix) {
            return ZigString(assetPrefix.slice()).withEncoding().toJS(globalThis)
        }
        return JsValue.jsNull()
    }

    // ========================================================================
    // match - 路由匹配
    // ========================================================================

    /// 匹配请求路径到路由
    public func `match`(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let argument = callframe.argumentsOld(2)
        if (argument.len == 0) {
            return globalThis.throwInvalidArguments("Expected string, Request or Response")
        }

        let arg = argument.ptr[0]
        if (arg.isEmptyOrUndefinedOrNull() || !arg.isCell()) {
            return globalThis.throwInvalidArguments("Expected string, Request or Response")
        }

        var path: String = ""
        if (arg.isString()) {
            let slice1 = try { arg.toSlice(globalThis, globalThis.allocator()) } catch(e: Exception) { throw e }
            path = try { slice1.cloneIfBorrowed(globalThis.allocator()) } catch(e: Exception) { throw e }
        } else if (arg.isCell()) {
            if (let req <- arg.`as`(Request)) {
                req.ensureURL()
                path = req.url.toUTF8(globalThis.allocator())
            } else if (let resp <- arg.`as`(Response)) {
                path = resp.getUTF8Url(globalThis.allocator())
            }
        } else {
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
            try {
                path = ZigString.Slice.initDupe(globalThis.allocator(), URL.parse(path.slice()).pathname)
                prevPath.deinit()
            } catch(e: Exception) {
                prevPath.deinit()
                throw e
            }
        }

        let urlPath = try { URLPath.parse(path.slice()) } catch(err: Exception) {
            return globalThis.`throw`("${err} parsing path: ${path.slice()}")
        }

        var params = RouterParamList{}
        let routeOpt = this.router.routes.matchPageWithAllocator(
            "",
            urlPath,
            params,
            globalThis.allocator(),
        )
        if (routeOpt.isNone()) {
            return JsValue.jsNull()
        }
        let route = routeOpt.get()

        var result = MatchedRoute(
            globalThis.allocator(),
            route,
            this.origin,
            this.assetPrefix,
            this.baseDir,
        )
        params.deinit(globalThis.allocator())
        return result.toJS(globalThis)
    }

    // ========================================================================
    // reload / bustDirCache
    // ========================================================================

    /// 重新加载路由
    public func reload(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let thisValue = callframe.`this`()

        var arena = ArenaAllocator(globalThis.allocator())

        var allocator = arena.allocator()
        var vm = globalThis.bunVM()

        let origLog = vm.transpiler.resolver.log
        var log = Logger.Log(allocator)
        vm.transpiler.resolver.log = log
        this.bustDirCache(globalThis)

        let rootDirInfoOpt = try { vm.transpiler.resolver.readDirInfo(this.router.config.dir) } catch(_: Exception) {
            let errValue = log.toJS(globalThis, globalThis.allocator(), "reading root directory")
            arena.deinit()
            globalThis.allocator().destroy(arena)
            return globalThis.throwValue(errValue )
        }
        if (rootDirInfoOpt.isNone()) {
            arena.deinit()
            globalThis.allocator().destroy(arena)
            return globalThis.`throw`("Unable to find directory: ${this.router.config.dir}")
        }
        let rootDirInfo = rootDirInfoOpt.get()

        var router = Router(vm.transpiler.fs, allocator, RouterConfig{
            dir = try { allocator.dupe<UInt8>(this.router.config.dir) } catch(_: Exception) { unreachable() }
            extensions = try { allocator.dupe<String>(this.router.config.extensions) } catch(_: Exception) { unreachable() }
            asset_prefix_path = this.router.config.asset_prefix_path
        })
        try { router.loadRoutes(log, rootDirInfo, Resolver, vm.transpiler.resolver, router.config.dir) } catch(_: Exception) {
            let errValue = log.toJS(globalThis, globalThis.allocator(), "loading routes")
            arena.deinit()
            globalThis.allocator().destroy(arena)
            return globalThis.throwValue(errValue )
        }

        this.router.deinit()
        this.arena.deinit()
        globalThis.allocator().destroy(this.arena)

        this.arena = arena
        this.js.routesSetCached(thisValue, globalThis, JsValue.jsUndefined())
        this.allocator = allocator
        this.router = router
        return thisValue
        vm.transpiler.resolver.log = origLog
    }

    /// 清除目录缓存
    public func bustDirCache(globalThis!: JsGlobalObject) {
        this.bustDirCacheRecursive(globalThis, Strings.withoutTrailingSlashWindowsPath(this.router.config.dir))
    }

    /// 递归清除目录缓存
    func bustDirCacheRecursive(globalThis!: JsGlobalObject, inputPath!: String) {
        var vm = globalThis.bunVM()
        var path = inputPath

        let rootDirInfo = try { vm.transpiler.resolver.readDirInfo(path) } catch(_: Exception) { return }

        if (let dir <- rootDirInfo) {
            if (let entries <- dir.getEntriesConst()) {
                var iter = entries.data.iterator()
                while (let entryPtr <- iter.next()) {
                    let entry = entryPtr.value_ptr
                    if (entry.base()[0] == '.') { continue }
                    if (entry.kind(vm.transpiler.fs.fs, false) == dir) {
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
        if (let prefix <- this.assetPrefix) { prefix.deref() }
        if (let prefix <- this.origin) { prefix.deref() }
        if (let dir <- this.baseDir) { dir.deref() }

        this.router.deinit()
        this.arena.deinit()
    }
}

// ============================================================================
// RouterMatch / RouterParamList - 路由匹配结果与参数列表
// Cangjie 不支持嵌套类型，因此从 RouterMatch / RouterParamList 提升为顶层类型
// ============================================================================

/// 路由参数列表（对应原 Zig RouterParamList）
/// Query string map stub - placeholder for URL query parameter map
public class QueryStringMap {
    public init() {}
}

public class RouterParamList {
    public var len: Int64 = 0

    public init() {}

    public func deinit(alloc!: Allocator): Unit {}
    public func clone(alloc!: Allocator): RouterParamList { RouterParamList() }
}

/// 路由匹配结果（对应原 Zig RouterMatch）
public class RouterMatch {
    public var pathname: String = ""
    public var file_path: String = ""
    public var name: String = ""
    public var query_string: String = ""
    public var params: RouterParamList = RouterParamList()

    public init() {}

    public func pathnameWithoutLeadingSlash(): String { pathname }
}

// ============================================================================
// MatchedRoute - 匹配到的路由
// ============================================================================

/// 匹配到的路由信息
public class MatchedRoute {
    var route: RouterMatch
    var routeHolder: RouterMatch = ArenaAllocator()
    var queryStringMap: QueryStringMap = none
    var paramMap: QueryStringMap = none
    var paramsListHolder: RouterParamList = RouterParamList{}
    var origin: RefString = none
    var assetPrefix: RefString = none
    var needsDeinit: Bool = true
    var baseDir: RefString = none

    // ========================================================================
    // 初始化
    // ========================================================================

    /// 创建 MatchedRoute
    public static func initFunc(
        allocator!: Allocator,
        `match`!: RouterMatch,
        origin!: RefString,
        assetPrefix!: RefString,
        baseDir!: RefString
    ): MatchedRoute {
        let paramsList = `match`.params.clone(allocator)

        var route = allocator.create(MatchedRoute) 

        route = MatchedRoute{
            routeHolder = `match`
            route = ArenaAllocator()
            assetPrefix = assetPrefix
            origin = origin
            baseDir = baseDir
        }
        baseDir.ref()
        route.paramsListHolder = paramsList
        route.route = route.routeHolder
        route.routeHolder.params = route.paramsListHolder
        if (let o <- origin) { o.ref() }
        if (let prefix <- assetPrefix) { prefix.ref() }

        return route
    }

    /// 释放资源
    public func deinit() {
        if (let map <- this.queryStringMap) { map.deinit() }
        if (let map <- this.paramMap) { map.deinit() }
        if (this.needsDeinit) {
            if (this.route.pathname.len > 0 && Mimalloc.mi_is_in_heap_region(this.route.pathname.ptr)) {
                Mimalloc.mi_free(this.route.pathname.ptr)
            }
            this.paramsListHolder.deinit(default_allocator)
            this.paramsListHolder = RouterParamList{}
        }

        if (let o <- this.origin) { o.deref() }
        if (let prefix <- this.assetPrefix) { prefix.deref() }
        if (let base <- this.baseDir) { base.deref() }

        default_allocator.destroy(this)
    }

    // ========================================================================
    // Getter 方法
    // ========================================================================

    /// 获取文件路径
    public func getFilePath(globalThis!: JsGlobalObject): JsValue {
        return ZigString(this.route.file_path).withEncoding().toJS(globalThis)
    }

    /// 获取路径名
    public func getPathname(globalThis!: JsGlobalObject): JsValue {
        return ZigString(this.route.pathname).withEncoding().toJS(globalThis)
    }

    /// 获取路由名
    public func getRoute(globalThis!: JsGlobalObject): JsValue {
        return ZigString(this.route.name).withEncoding().toJS(globalThis)
    }

    /// 获取名称
    public func getName(globalThis!: JsGlobalObject): JsValue {
        return ZigString(this.route.name).withEncoding().toJS(globalThis)
    }

    // ========================================================================
    // KindEnum - 路由类型
    // ========================================================================

//    public class KindEnum {
//        public static let EXACT = "exact"
//        public static let CATCH_ALL = "catch-all"
//        public static let OPTIONAL_CATCH_ALL = "optional-catch-all"
//        public static let DYNAMIC = "dynamic"

//        public static func initFunc(name!: String): ZigString {
//            if (Strings.contains(name, "[[")) {
//                return ZigString(OPTIONAL_CATCH_ALL)
//            } else if (Strings.contains(name, "[...")) {
//                return ZigString(CATCH_ALL)
//            } else if (Strings.contains(name, "[")) {
//                return ZigString(DYNAMIC)
//            } else {
//                return ZigString(EXACT)
//            }
//        }
//    }

    /// 获取路由类型
    public func getKind(globalThis!: JsGlobalObject): JsValue {
        return KindEnum(this.route.name).toJS(globalThis)
    }

    /// 获取参数
    public func getParams(globalThis!: JsGlobalObject): JsValue {
        if (this.route.params.len == 0) {
            return JsValue.createEmptyObject(globalThis, 0)
        }

        if (this.paramMap == none) {
            this.paramMap = QueryStringMap.initWithScanner (
                globalThis.allocator(),
                CombinedScanner(
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
    public func getQuery(globalThis!: JsGlobalObject): JsValue {
        if (this.route.query_string.len == 0 && this.route.params.len == 0) {
            return JsValue.createEmptyObject(globalThis, 0)
        } else if (this.route.query_string.len == 0) {
            return this.getParams(globalThis)
        }

        if (this.queryStringMap == none) {
            if (this.route.params.len > 0) {
                this.queryStringMap = QueryStringMap.initWithScanner(globalThis.allocator() , CombinedScanner(
                    this.route.query_string,
                    this.route.pathnameWithoutLeadingSlash(),
                    this.route.name,
                    this.route.params,
                ))
            } else {
                this.queryStringMap = QueryStringMap(globalThis.allocator() , this.route.query_string)
            }
        }

        if (let map <- this.queryStringMap) {
            return createQueryObject(globalThis, map)
        }

        return JsValue.createEmptyObject(globalThis, 0)
    }

    /// 获取脚本源路径
    public func getScriptSrc(globalThis!: JsGlobalObject): JsValue {
        var buf = PathBuffer()
        var stream = FixedBufferStream(buf)
        var writer = stream.writer()

        let baseDirVal = if (this.baseDir.isSome()) { this.baseDir.getOrThrow().slice() } else { VirtualMachine.get().transpiler.fs.top_level_dir }
        let originVal = if (this.origin.isSome()) { URL.parse(this.origin.getOrThrow().slice()) } else { URL() }
        let prefixVal = if (this.assetPrefix.isSome()) { this.assetPrefix.getOrThrow().slice() } else { "" }
        BunObject.getPublicPathWithAssetPrefix(
            this.route.file_path,
            baseDirVal,
            originVal,
            prefixVal,
            writer,
            Platform.Posix,
        )
        return ZigString(buf[0..writer.context.pos]).withEncoding().toJS(globalThis)
    }

    /// 终结化
    public func finalize() {
        this.deinit()
    }
}

/// 创建查询对象
func createQueryObject(ctx!: JsGlobalObject, map!: QueryStringMap): JsValue {
    let value = JsObject.createWithInitializer(QueryObjectCreator, map, ctx, map.getNameCount())
    return value
}

/// 查询对象创建器
class QueryObjectCreator {
    var query: QueryStringMap

    public func create(obj!: JsObject, global!: JsGlobalObject) {
        var iter = this.query.iter()
        while (let entry <- iter.next()) {
            let entryName = entry.name
            var str = ZigString(entryName).withEncoding()

            if (entry.values.len > 1) {
                var values = entry.values.map { v => ZigString(v).withEncoding() }
                obj.putRecord(global, str, values) 
            } else {
                let value = ZigString(entry.values[0]).withEncoding()
                obj.putRecord(global, str, [value]) 
            }
        }
    }
}

// ============================================================================
// 类型别名
// ========================================================================

// default_allocator 已通过 import 导入，无需重复定义