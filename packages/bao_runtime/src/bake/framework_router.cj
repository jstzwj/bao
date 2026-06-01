// 翻译自 Bun: src/runtime/bake/FrameworkRouter.zig
// 从文件系统发现路由，由框架配置指导。
// 与所有不同的范式无关。支持增量更新用于 DevServer，或序列化为二进制用于生产。

package bao_runtime.bake

import bao_bun_alloc.Allocator
import bao_core.ArenaAllocator
import bao_core.Output
import bao_bundler.Resolver
import bao_collections.ArrayList
import bao_jsc.JsValue
import bao_jsc.JSGlobalObject
import bao_jsc.Strong

/// 从文件系统发现路由，由框架配置指导。
/// 与所有不同的范式无关。支持增量更新用于 DevServer，或序列化为二进制用于生产。
public class FrameworkRouter {
    public var root: String = ""
    public var types: Array<FrameworkRouterType> = []
    public var routes: ArrayList<FrameworkRouterRoute> = ArrayList<FrameworkRouterRoute>()
    /// 键是完整 URL，带前导 /，无尾随 /
    /// 值是 Route Index
    public var static_routes: StaticRouteMap = StaticRouteMap()
    /// 所有动态模式的平面列表
    public var dynamic_routes: DynamicRouteMap = DynamicRouteMap()
    /// 模式字符串的 arena 分配器
    public var pattern_string_arena: ArenaAllocator = ArenaAllocator()

    public init() {}

    /// 初始化空路由器
    public static func initEmpty(root: String, types: Array<FrameworkRouterType>, allocator: Allocator): FrameworkRouter {
        assert(root.startsWith("/"))

        var routes = ArrayList<FrameworkRouterRoute>()
        var typeIndex: Int64 = 0
        for (ty in types) {
            ty.abs_root = StringsRef.withoutTrailingSlashWindowsPath(ty.abs_root)
            assert(StringsRef.hasPrefix(ty.abs_root, root))

            var route = FrameworkRouterRoute()
            route.part = FrameworkRouterPart.text("")
            route.`type` = FrameworkRouterTypeIndex(UInt8(typeIndex))
            routes.append(route)
            typeIndex += 1
        }
        var fr = FrameworkRouter()
        fr.root = StringsRef.withoutTrailingSlashWindowsPath(root)
        fr.types = types
        fr.routes = routes
        fr.dynamic_routes = DynamicRouteMap()
        fr.static_routes = StaticRouteMap()
        fr.pattern_string_arena = ArenaAllocator()
        return fr
    }

    public func deinit(allocator: Allocator): Unit {
        // ArrayList is GC managed in Cangjie, no manual deinit needed
        static_routes.deinit(allocator)
        dynamic_routes.deinit(allocator)
    }

    public func memoryCost(): UInt64 {
        var cost: UInt64 = 1024
        // cost += routes.capacity * 256
        // cost += StaticRouteMap.DataList.capacityInBytes(static_routes.entries.capacity)
        // cost += DynamicRouteMap.DataList.capacityInBytes(dynamic_routes.entries.capacity)
        return cost
    }

    /// 扫描所有路由类型
    public func scanAll(allocator: Allocator, r: Resolver, ctx: FrameworkRouterInsertionContext): Unit {
        var idx: Int64 = 0
        for (ty in types) {
            scan(allocator, FrameworkRouterTypeIndex(UInt8(idx)), r, ctx)
            idx += 1
        }
    }

    /// 获取路由指针
    public func routePtr(i: FrameworkRouterRouteIndex): FrameworkRouterRoute {
        return routes[Int64(i.value)]
    }

    /// 获取类型指针
    public func typePtr(i: FrameworkRouterTypeIndex): FrameworkRouterType {
        return types[Int64(i.value)]
    }

    func newRoute(alloc: Allocator, route_data: FrameworkRouterRoute): FrameworkRouterRouteIndex {
        let i = routes.size
        routes.append(route_data)
        var idx = FrameworkRouterRouteIndex()
        idx.value = UInt32(i)
        return idx
    }

    /// 慢速匹配，适用于开发模式
    public func matchSlow(path: String, params: FrameworkRouterMatchedParams): ?FrameworkRouterRouteIndex {
        params.params = BoundedArray<FrameworkRouterMatchedParamsEntry>(64)
        assert(path.startsWith("/"))
        // 静态路由匹配 — 精确匹配路径
        // 对应 Bun: if (static_routes.get(path)) |static_val| return static_val
        match (static_routes.get(path)) {
            case Some(staticVal) =>
                return Some(staticVal)
            case None => ()
        }
        // 动态路由匹配 — 按模式匹配
        // 对应 Bun: for (dynamic_routes.keys()) |pattern| { if (pattern.matches(path, params)) ... }
        let dynamicKeys = dynamic_routes.keys()
        let dynamicValues = dynamic_routes.values()
        var idx: Int64 = 0
        for (pattern in dynamicKeys) {
            if (pattern.matches(path, params)) {
                if (idx < dynamicValues.size) {
                    return Some(dynamicValues[idx])
                }
            }
            idx += 1
        }
        return Option<FrameworkRouterRouteIndex>.None
    }

    /// 扫描特定类型的路由
    public func scan(alloc: Allocator, ty: FrameworkRouterTypeIndex, r: Resolver, ctx: FrameworkRouterInsertionContext): Unit {
        let t = types[Int64(ty.value)]
        assert(!StringsRef.hasSuffixComptime(t.abs_root, "/"))
        assert(t.abs_root.startsWith("/"))
        // let root_info = r.readDirInfoIgnoreError(t.abs_root) ?? return
        let root_info = DirInfo()
        var arena_state = ArenaAllocator()
        try {
            scanInner(alloc, t, ty, r, root_info, arena_state, ctx)
        } finally {
            // arena_state cleanup - GC managed
        }
    }

    func scanInner(
        alloc: Allocator,
        t: FrameworkRouterType,
        t_index: FrameworkRouterTypeIndex,
        r: Resolver,
        dir_info: DirInfo,
        arena_state: ArenaAllocator,
        ctx: FrameworkRouterInsertionContext
    ): Unit {
        // 遍历目录树并发现路由文件
        // 完整实现需要递归文件系统遍历和路由模式解析
    }
}

/// 路由
public class FrameworkRouterRoute {
    public var part: FrameworkRouterPart = FrameworkRouterPart.text("")
    public var `type`: FrameworkRouterTypeIndex = FrameworkRouterTypeIndex(0)
    public var parent: ?FrameworkRouterRouteIndex = Option<FrameworkRouterRouteIndex>.None
    public var first_child: ?FrameworkRouterRouteIndex = Option<FrameworkRouterRouteIndex>.None
    public var prev_sibling: ?FrameworkRouterRouteIndex = Option<FrameworkRouterRouteIndex>.None
    public var next_sibling: ?FrameworkRouterRouteIndex = Option<FrameworkRouterRouteIndex>.None
    public var file_page: ?OpaqueFileId = Option<OpaqueFileId>.None
    public var file_layout: ?OpaqueFileId = Option<OpaqueFileId>.None
    /// 仅用于 DevServer
    public var bundle: ?Int32 = Option<Int32>.None

    public init() {}

    public func filePtr(file_kind: FrameworkRouterFileKind): ?OpaqueFileId {
        match (file_kind) {
            case FrameworkRouterFileKind.page => file_page
            case FrameworkRouterFileKind.layout => file_layout
        }
    }
}

/// 路由文件种类
public enum FrameworkRouterFileKind {
    | page
    | layout
}

/// 路由索引
public struct FrameworkRouterRouteIndex {
    public var value: UInt32 = UInt32(0)
    public init() {}
}

/// 路由索引 Optional
public struct FrameworkRouterRouteIndexOptional {
    public var value: ?UInt32 = Option<UInt32>.None
    public static let none: FrameworkRouterRouteIndexOptional = FrameworkRouterRouteIndexOptional()
    public func unwrap(): ?UInt32 { value }
}

/// 路由类型
public class FrameworkRouterType {
    public var abs_root: String = ""
    public var prefix: String = "/"
    public var ignore_underscores: Bool = false
    public var ignore_dirs: Array<String> = [ ".git", "node_modules" ]
    public var extensions: Array<String> = []
    public var style: FrameworkRouterStyle = FrameworkRouterStyle.nextjs_pages
    public var allow_layouts: Bool = false
    public var client_file: ?OpaqueFileId = Option<OpaqueFileId>.None
    public var server_file: OpaqueFileId = OpaqueFileId()
    public var server_file_string: ?Strong<JsValue> = Option<Strong<JsValue>>.None

    public init() {}

    public static func rootRouteIndex(type_index: FrameworkRouterTypeIndex): FrameworkRouterRouteIndex {
        var idx = FrameworkRouterRouteIndex()
        idx.value = UInt32(type_index.value)
        return idx
    }
}

/// 路由类型索引
public struct FrameworkRouterTypeIndex {
    public var value: UInt8
    public init(value: UInt8) {
        this.value = value
    }
    public func get(): UInt8 {
        return value
    }
}

/// Part - URL 模式的一部分
public enum FrameworkRouterPart {
    | text(String)           // 不包含斜杠。每个斜杠对应一个。
    | param(String)          // 参数名
    | catch_all_optional(String)  // 必须是模式的最后一部分
    | catch_all(String)      // 必须是模式的最后一部分
    | group(String)          // 不影响 URL 匹配，但影响层次结构

    public func eql(other: FrameworkRouterPart): Bool {
        match (this) {
            case text(a) => match (other) { case text(b) => StringsRef.eql(a, b) case _ => false }
            case param(a) => match (other) { case param(b) => StringsRef.eql(a, b) case _ => false }
            case catch_all(a) => match (other) { case catch_all(b) => StringsRef.eql(a, b) case _ => false }
            case catch_all_optional(a) => match (other) { case catch_all_optional(b) => StringsRef.eql(a, b) case _ => false }
            case group(a) => match (other) { case group(b) => StringsRef.eql(a, b) case _ => false }
        }
    }
}

/// EncodedPattern - 路由模式的序列化格式
public class FrameworkRouterEncodedPattern {
    public var data: Array<Byte> = []
    public init() {}
    public init(data: Array<Byte>) { this.data = data }

    public static let root: FrameworkRouterEncodedPattern = FrameworkRouterEncodedPattern()

    public func iterate(): FrameworkRouterEncodedPatternIterator {
        return FrameworkRouterEncodedPatternIterator(this, 0)
    }

    public func partAt(byte_offset: UInt64): ?FrameworkRouterPart {
        return FrameworkRouterEncodedPatternIterator(this, byte_offset).peek()
    }

    public func effectiveURLHash(): UInt64 {
        var stack_space = ArrayList<Byte>()
        var it = iterate()
        while (let Some(item) <- it.next()) {
            match (item) {
                case text(text_val) =>
                    stack_space.append(UInt8(47))
                    for (ch in text_val.toArray()) {
                        stack_space.append(UInt8(ch))
                    }
                case param(_) =>
                    stack_space.append(UInt8(58))
                case catch_all(_) =>
                    stack_space.append(UInt8(58))
                    stack_space.append(UInt8(46))
                case catch_all_optional(_) =>
                    stack_space.append(UInt8(58))
                    stack_space.append(UInt8(46))
                case group(_) => continue
            }
        }
        let stackFrozen = stack_space
        return bun.hash.apply(Array<Byte>(stackFrozen.size, { i => stackFrozen[Int64(i)] }))
    }

    public func matches(path: String, params: FrameworkRouterMatchedParams): Bool {
        // 匹配 URL 路径与编码模式
        // 对应 Bun: EncodedPattern.matches
        var paramNum: Int64 = 0
        var it = iterate()
        var i: Int64 = 1
        while (let Some(part) <- it.next()) {
            match (part) {
                case text(expect) =>
                    if (path.size < i + expect.size) { return false }
                    // 验证文本部分匹配
                    var j: Int64 = 0
                    while (j < expect.size) {
                        if (path[i + j] != expect[Int64(j)]) { return false }
                        j += 1
                    }
                    i += 1 + expect.size
                case param(name) =>
                    paramNum += 1
                    // 参数匹配到下一个 / 或路径结尾
                    let slashPos = path.indexOf('/', i)
                    let endPos = if (slashPos.isSome()) { slashPos.getOrThrow() } else { path.size }
                    let paramValue = path[i..endPos]
                    params.params.append(FrameworkRouterMatchedParamsEntry(name, paramValue))
                    i = endPos
                case catch_all(name) =>
                    // catch-all 匹配剩余所有路径
                    let remaining = path[i..]
                    params.params.append(FrameworkRouterMatchedParamsEntry(name, remaining))
                    return true
                case catch_all_optional(name) =>
                    // catch-all optional 匹配剩余所有路径（可为空）
                    let remaining = if (i < path.size) { path[i..] } else { "" }
                    params.params.append(FrameworkRouterMatchedParamsEntry(name, remaining))
                    return true
                case group(_) => continue
            }
        }
        return i >= path.size
    }
}

/// EncodedPattern 迭代器
public class FrameworkRouterEncodedPatternIterator {
    public var pattern: FrameworkRouterEncodedPattern
    public var offset: UInt64

    public init(pattern: FrameworkRouterEncodedPattern, offset: UInt64) {
        this.pattern = pattern
        this.offset = offset
    }

    public func peek(): FrameworkRouterPart {
        let (part, _) = readWithSize()
        return part
    }

    public func next(): ?FrameworkRouterPart {
        if (Int64(offset) >= pattern.data.size) {
            return Option<FrameworkRouterPart>.None
        }
        let (part, len) = readWithSize()
        offset += len
        return part
    }

    public func readWithSize(): (FrameworkRouterPart, UInt64) {
        // 读取序列化头部并解码为 Part
        // 简化实现
        return (FrameworkRouterPart.text(""), 0)
    }
}

/// MatchedParams - 匹配到的参数
/// 强制上限为 64 个唯一模式，使路由无需堆分配
public class FrameworkRouterMatchedParams {
    public static let max_count: UInt64 = 64
    public var params: BoundedArray<FrameworkRouterMatchedParamsEntry>

    public init() {
        params = BoundedArray<FrameworkRouterMatchedParamsEntry>(64)
    }

    public func toJS(global: JSGlobalObject): JsValue {
        if (params.slice.size == 0) {
            return JsValue.null()
        }
        let obj = JsValue.createEmptyObject(global.globalThis, Int64(params.slice.size))
        for (param in params.slice) {
            obj.put(global.globalThis, param.key, JsValue(param.value))
        }
        return obj
    }
}

/// MatchedParams 条目
public class FrameworkRouterMatchedParamsEntry {
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        this.key = key
        this.value = value
    }
}

/// 路由样式
public enum FrameworkRouterStyle {
    | nextjs_pages
    | nextjs_app_ui
    | nextjs_app_routes
    | javascript_defined(?Strong<JsValue>)

    public static func fromJs(value: JsValue, global: JSGlobalObject): ?FrameworkRouterStyle {
        if (value.isUndefinedOrNull()) {
            return None
        }
        if (value.isString()) {
            let str = value.toSlice(global.globalThis)
            if (str == "nextjs-pages") {
                return FrameworkRouterStyle.nextjs_pages
            }
            if (str == "nextjs-app-ui") {
                return FrameworkRouterStyle.nextjs_app_ui
            }
            if (str == "nextjs-app-routes") {
                return FrameworkRouterStyle.nextjs_app_routes
            }
        }
        return None
    }

    public func deinit(): Unit {
        match (this) {
            case javascript_defined(strong) => if (strong.isSome()) { strong.getOrThrow().deinit() }
            case _ => ()
        }
    }

    /// 解析路由样式
    public func parse(file_path: String, ext: String, log: FrameworkRouterTinyLog, allow_layouts: Bool, arena: Allocator): ?FrameworkRouterParsedPattern {
        assert(file_path.startsWith("/"))
        match (this) {
            case nextjs_pages => parseNextJsPages(file_path, ext, log, allow_layouts, arena)
            case nextjs_app_ui => parseNextJsApp(file_path, ext, log, allow_layouts, arena, FrameworkRouterParsedPatternKind.page)
            case nextjs_app_routes => parseNextJsApp(file_path, ext, log, allow_layouts, arena, FrameworkRouterParsedPatternKind.layout)
            case javascript_defined(_) => panic("customizable framework router Style is unsupported upstream in Bun")
        }
    }
}

/// ParsedPattern - 解析后的模式
public class FrameworkRouterParsedPattern {
    public var parts: Array<FrameworkRouterPart> = []
    public var kind: FrameworkRouterParsedPatternKind = FrameworkRouterParsedPatternKind.page
    public init() {}
}

/// ParsedPattern 种类
public enum FrameworkRouterParsedPatternKind {
    | page      // 可导航到
    | layout    // 不参与导航解析
    | extra     // 路由的其他相关文件
}

/// TinyLog - 非分配单消息日志，专门用于路由模式解析器的消息
public class FrameworkRouterTinyLog {
    public var msg: Array<Byte> = []
    public var cursor_at: UInt32 = 0
    public var cursor_len: UInt32 = 0

    public init() {}

    public static let empty: FrameworkRouterTinyLog = FrameworkRouterTinyLog()

    public func fail(fmt: String, cursor_at_val: UInt64, cursor_len_val: UInt64): Error {
        write(fmt)
        this.cursor_at = UInt32(cursor_at_val)
        this.cursor_len = UInt32(cursor_len_val)
        return Exception("InvalidRoutePattern: " + fmt)
    }

    public func write(fmt: String): Unit {
        msg = fmt.toArray()
    }

    public func print(rel_path: String): Unit {
        Output.errGeneric("'${rel_path}' is not a valid route")
        Output.flush()
    }
}

/// InsertionContext - 连接 FrameworkRouter 与其他代码库的接口
public class FrameworkRouterInsertionContext {
    public var opaque_ctx: Any = Object()
    public var vtable: FrameworkRouterVTable = FrameworkRouterVTable()

    public init() {}

    public static func wrap<T>(ctx: T): FrameworkRouterInsertionContext {
        // 类型擦除包装器
        var result = FrameworkRouterInsertionContext()
        result.opaque_ctx = ctx
        return result
    }
}

/// InsertionContext VTable
public class FrameworkRouterVTable {
    public var getFileIdForRouter: (Any, String, FrameworkRouterRouteIndex, FrameworkRouterFileKind) -> OpaqueFileId = { _, _, _, _ => OpaqueFileId() }
    public var onRouterSyntaxError: (Any, String, FrameworkRouterTinyLog) -> Unit = { _, _, _ => () }
    public var onRouterCollisionError: (Any, String, OpaqueFileId, FrameworkRouterFileKind) -> Unit = { _, _, _, _ => () }
    public init() {}
}

/// JS 绑定，用于测试
public class JSFrameworkRouter {
    public var files: ArrayList<String> = ArrayList<String>()
    public var router: FrameworkRouter = FrameworkRouter()
    public var stored_parse_errors: ArrayList<JSFrameworkRouterParseError> = ArrayList<JSFrameworkRouterParseError>()
    public init() {}
}

/// JS 解析错误
public class JSFrameworkRouterParseError {
    public var rel_path: String = ""
    public var log: FrameworkRouterTinyLog = FrameworkRouterTinyLog()
    public init() {}
}

// 错误类型
public enum PatternParseError {
    | InvalidRoutePattern
}

// 类型别名

// 引用函数的默认实现 (Next.js 路由解析)
func parseNextJsPages(file_path: String, ext: String, log: FrameworkRouterTinyLog, allow_layouts: Bool, arena: Allocator): ?FrameworkRouterParsedPattern { None }
func parseNextJsApp(file_path: String, ext: String, log: FrameworkRouterTinyLog, allow_layouts: Bool, arena: Allocator, kind: FrameworkRouterParsedPatternKind): ?FrameworkRouterParsedPattern { None }

/// EffectiveURLContext [KEPT: no-pkg]
public class FrameworkRouterEncodedPatternEffectiveURLContext {
    public static func hash(pattern: FrameworkRouterEncodedPattern): UInt64 {
        pattern.effectiveURLHash()
    }
    public static func eql(lhs: FrameworkRouterEncodedPattern, rhs: FrameworkRouterEncodedPattern): Bool {
        true
    }
}
