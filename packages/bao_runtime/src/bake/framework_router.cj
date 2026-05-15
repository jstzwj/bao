// 翻译自 Bun: src/runtime/bake/FrameworkRouter.zig
// 从文件系统发现路由，由框架配置指导。
// 与所有不同的范式无关。支持增量更新用于 DevServer，或序列化为二进制用于生产。

package bao_runtime

/// 从文件系统发现路由，由框架配置指导。
/// 与所有不同的范式无关。支持增量更新用于 DevServer，或序列化为二进制用于生产。
public class FrameworkRouter {
    public var root: String
    public var types: Array<Type>
    public var routes: ArrayListUnmanaged<Route>
    /// 键是完整 URL，带前导 /，无尾随 /
    /// 值是 Route Index
    public var static_routes: StaticRouteMap
    /// 所有动态模式的平面列表
    public var dynamic_routes: DynamicRouteMap
    /// 模式字符串的 arena 分配器
    public var pattern_string_arena: ArenaAllocator

    /// 初始化空路由器
    public static func initEmpty(root: String, types: Array<Type>, allocator: Allocator): FrameworkRouter {
        assert(std.fs.path.isAbsolute(root))

        var routes = ArrayListUnmanaged<Route>.initCapacity(allocator, types.length)
        for ((ty, type_index) in types) {
            ty.abs_root = bun.strings.withoutTrailingSlashWindowsPath(ty.abs_root)
            assert(bun.strings.hasPrefix(ty.abs_root, root))

            routes.appendAssumeCapacity(Route(
                part: Route.Part.text(""),
                type: Type.Index.init(type_index),
                parent: Index.Optional.none,
                prev_sibling: Index.Optional.none,
                next_sibling: Index.Optional.none,
                first_child: Index.Optional.none,
                file_page: OpaqueFileId.Optional.none,
                file_layout: OpaqueFileId.Optional.none,
            ))
        }
        return FrameworkRouter(
            root: bun.strings.withoutTrailingSlashWindowsPath(root),
            types: types,
            routes: routes,
            dynamic_routes: DynamicRouteMap(),
            static_routes: StaticRouteMap(),
            pattern_string_arena: ArenaAllocator.init(allocator),
        )
    }

    public func deinit(allocator: Allocator): Unit {
        routes.deinit(allocator)
        static_routes.deinit(allocator)
        dynamic_routes.deinit(allocator)
        allocator.free(types)
        pattern_string_arena.deinit()
    }

    public func memoryCost(): UInt64 {
        var cost: UInt64 = sizeOf<FrameworkRouter>()
        cost += routes.capacity * sizeOf<Route>()
        cost += StaticRouteMap.DataList.capacityInBytes(static_routes.entries.capacity)
        cost += DynamicRouteMap.DataList.capacityInBytes(dynamic_routes.entries.capacity)
        return cost
    }

    /// 扫描所有路由类型
    public func scanAll(allocator: Allocator, r: Resolver, ctx: InsertionContext): Unit {
        for ((ty, i) in types) {
            scan(allocator, Type.Index.init(i), r, ctx)
        }
    }

    /// 路由
    public class Route {
        public var part: Part
        public var type: Type.Index
        public var parent: Index.Optional
        public var first_child: Index.Optional
        public var prev_sibling: Index.Optional
        public var next_sibling: Index.Optional
        public var file_page: OpaqueFileId.Optional = OpaqueFileId.Optional.none
        public var file_layout: OpaqueFileId.Optional = OpaqueFileId.Optional.none
        /// 仅用于 DevServer
        public var bundle: RouteBundle.Index.Optional = RouteBundle.Index.Optional.none

        public enum FileKind {
            | page
            | layout
        }

        public func filePtr(file_kind: FileKind): OpaqueFileId.Optional {
            match (file_kind) {
                case page => file_page
                case layout => file_layout
            }
        }

        public struct Index <: UInt31 {}
        public struct Index.Optional {
            public var value: ?UInt31 = None
            public static let none: Index.Optional = Index.Optional(value: None)
            public func unwrap(): ?UInt31 { value }
        }
    }

    /// 路由类型
    public class Type {
        public var abs_root: String
        public var prefix: String = "/"
        public var ignore_underscores: Bool = false
        public var ignore_dirs: Array<String> = [ ".git", "node_modules" ]
        public var extensions: Array<String>
        public var style: Style
        public var allow_layouts: Bool
        public var client_file: OpaqueFileId.Optional
        public var server_file: OpaqueFileId
        public var server_file_string: Strong.Optional

        public static func rootRouteIndex(type_index: Index): Route.Index {
            return Route.Index.init(type_index.get())
        }

        public struct Index <: UInt8 {}
    }

    /// 获取路由指针
    public func routePtr(i: Route.Index): Route {
        return routes.items[i.get()]
    }

    /// 获取类型指针
    public func typePtr(i: Type.Index): Type {
        return types[i.get()]
    }

    func newRoute(alloc: Allocator, route_data: Route): Route.Index {
        let i = routes.items.length
        routes.append(alloc, route_data)
        return Route.Index.init(i)
    }

    /// Part - URL 模式的一部分
    public enum Part {
        | text(String)           // 不包含斜杠。每个斜杠对应一个。
        | param(String)          // 参数名
        | catch_all_optional(String)  // 必须是模式的最后一部分
        | catch_all(String)      // 必须是模式的最后一部分
        | group(String)          // 不影响 URL 匹配，但影响层次结构

        public func eql(other: Part): Bool {
            match (this) {
                case text(a) => match (other) { case text(b) => bun.strings.eql(a, b) case _ => false }
                case param(a) => match (other) { case param(b) => bun.strings.eql(a, b) case _ => false }
                case catch_all(a) => match (other) { case catch_all(b) => bun.strings.eql(a, b) case _ => false }
                case catch_all_optional(a) => match (other) { case catch_all_optional(b) => bun.strings.eql(a, b) case _ => false }
                case group(a) => match (other) { case group(b) => bun.strings.eql(a, b) case _ => false }
            }
        }
    }

    /// EncodedPattern - 路由模式的序列化格式
    public class EncodedPattern {
        public var data: Array<Byte>

        public static let root: EncodedPattern = EncodedPattern(data: [])

        public func iterate(): Iterator {
            return Iterator(pattern: this, offset: 0)
        }

        public func partAt(byte_offset: UInt64): ?Part {
            return Iterator(pattern: this, offset: byte_offset).peek()
        }

        public func effectiveURLHash(): UInt64 {
            var stack_space: Array<Byte> = Array<Byte>(std.fs.max_path_bytes * 2)
            var pos: UInt64 = 0
            var it = iterate()
            while (let Some(item) = it.next()) {
                match (item) {
                    case text(let text) =>
                        stack_space[pos] = '/'.toByte()
                        pos += 1
                        stack_space.write(pos, text)
                        pos += text.length
                    case param(_) =>
                        stack_space[pos] = ':'.toByte()
                        pos += 1
                    case catch_all(_) =>
                        stack_space[pos] = ':'.toByte()
                        pos += 1
                        stack_space[pos] = '.'.toByte()
                        pos += 1
                    case catch_all_optional(_) =>
                        stack_space[pos] = ':'.toByte()
                        pos += 1
                        stack_space[pos] = '?'.toByte()
                        pos += 1
                    case group(_) => continue
                }
            }
            return bun.hash(stack_space.slice(0, pos))
        }

        public func matches(path: String, params: MatchedParams): Bool {
            var param_num: UInt64 = 0
            var it = iterate()
            var i: UInt64 = 1
            while (let Some(part) = it.next()) {
                match (part) {
                    case text(let expect) =>
                        if (path.length < i + expect.length ||
                            !(path.length == i + expect.length || path[i + expect.length] == '/')) {
                            return false
                        }
                        if (!bun.strings.eql(path.slice(i, i + expect.length), expect)) {
                            return false
                        }
                        i += 1 + expect.length
                    case param(let name) =>
                        let end = bun.strings.indexOfCharPos(path, '/', i) ?? path.length
                        params.params.buffer[param_num] = MatchedParams.Entry(key: name, value: path.slice(i, end))
                        params.params.length = param_num + 1
                        param_num += 1
                        i = if (end == path.length) end else end + 1
                    case catch_all(let name) | catch_all_optional(let name) =>
                        if (i < path.length) {
                            var segment_start = i
                            while (segment_start < path.length) {
                                let segment_end = bun.strings.indexOfCharPos(path, '/', segment_start) ?? path.length
                                if (segment_start < segment_end) {
                                    params.params.buffer[param_num] = MatchedParams.Entry(key: name, value: path.slice(segment_start, segment_end))
                                    params.params.length = param_num + 1
                                    param_num += 1
                                }
                                segment_start = if (segment_end == path.length) segment_end else segment_end + 1
                            }
                        }
                        return true
                    case group(_) => continue
                }
            }
            return i == path.length
        }

        public class Iterator {
            public var pattern: EncodedPattern
            public var offset: UInt64

            public func peek(): Part {
                let result = readWithSize()
                return result.0
            }

            public func next(): ?Part {
                if (offset >= pattern.data.length) {
                    return None
                }
                let (part, len) = readWithSize()
                offset += len
                return part
            }

            public func readWithSize(): (Part, UInt64) {
                // 读取序列化头部并解码为 Part
                // 简化实现
                return (Part.text(""), 0)
            }
        }
    }

    /// MatchedParams - 匹配到的参数
    /// 强制上限为 64 个唯一模式，使路由无需堆分配
    public class MatchedParams {
        public static let max_count: UInt64 = 64
        public var params: BoundedArray<Entry, max_count>

        public class Entry {
            public var key: String
            public var value: String
        }

        public func toJS(global: JSGlobalObject): JSValue {
            let params_array = params.slice()
            if (params_array.length == 0) {
                return JSValue.null
            }
            let obj = JSValue.createEmptyObject(global, params_array.length)
            for (param in params_array) {
                obj.put(global, param.key, JSValue.fromString(global, param.value))
            }
            return obj
        }
    }

    /// 慢速匹配，适用于开发模式
    public func matchSlow(path: String, params: MatchedParams): ?Route.Index {
        params.params = BoundedArray<Entry, max_count>()
        assert(path[0] == '/')
        if (let Some(static) = static_routes.get(path)) {
            return static
        }
        for ((pattern, i) in dynamic_routes.keys()) {
            if (pattern.matches(path, params)) {
                return dynamic_routes.values()[i]
            }
        }
        return None
    }

    /// 路由样式
    public enum Style {
        | nextjs_pages
        | nextjs_app_ui
        | nextjs_app_routes
        | javascript_defined(Strong.Optional)

        public func deinit(): Unit {
            match (this) {
                case javascript_defined(let strong) => strong.deinit()
                case _ => ()
            }
        }

        /// 解析路由样式
        public func parse(file_path: String, ext: String, log: TinyLog, allow_layouts: Bool, arena: Allocator): ?ParsedPattern {
            assert(file_path[0] == '/')
            match (this) {
                case nextjs_pages => parseNextJsPages(file_path, ext, log, allow_layouts, arena)
                case nextjs_app_ui => parseNextJsApp(file_path, ext, log, allow_layouts, arena, .ui)
                case nextjs_app_routes => parseNextJsApp(file_path, ext, log, allow_layouts, arena, .routes)
                case javascript_defined(_) => panic("TODO: customizable Style")
            }
        }
    }

    /// ParsedPattern - 解析后的模式
    public class ParsedPattern {
        public var parts: Array<Part>
        public var kind: Kind

        public enum Kind {
            | page      // 可导航到
            | layout    // 不参与导航解析
            | extra     // 路由的其他相关文件
        }
    }

    /// TinyLog - 非分配单消息日志，专门用于路由模式解析器的消息
    public class TinyLog {
        public var msg: BoundedArray<Byte, 512 + 4096>
        public var cursor_at: UInt32
        public var cursor_len: UInt32

        public static let empty: TinyLog = TinyLog(
            cursor_at: UInt32.max,
            cursor_len: 0,
            msg: BoundedArray<Byte, 512 + 4096>(),
        )

        public func fail(fmt: String, cursor_at: UInt64, cursor_len: UInt64): Error {
            write(fmt)
            this.cursor_at = UInt32(cursor_at)
            this.cursor_len = UInt32(cursor_len)
            return PatternParseError.InvalidRoutePattern
        }

        public func write(fmt: String): Unit {
            msg.write(fmt)
        }

        public func print(rel_path: String): Unit {
            Output.errGeneric("'${rel_path}' is not a valid route")
            Output.flush()
        }
    }

    /// InsertionContext - 连接 FrameworkRouter 与其他代码库的接口
    public class InsertionContext {
        public var opaque_ctx: Any
        public var vtable: VTable

        public class VTable {
            public var getFileIdForRouter: (Any, String, Route.Index, Route.FileKind) -> OpaqueFileId
            public var onRouterSyntaxError: (Any, String, TinyLog) -> Unit
            public var onRouterCollisionError: (Any, String, OpaqueFileId, Route.FileKind) -> Unit
        }

        public static func wrap<T>(ctx: T): InsertionContext {
            // 类型擦除包装器
            return InsertionContext(opaque_ctx: ctx, vtable: VTable())
        }
    }

    /// 扫描特定类型的路由
    public func scan(alloc: Allocator, ty: Type.Index, r: Resolver, ctx: InsertionContext): Unit {
        let t = types[ty.get()]
        assert(!bun.strings.hasSuffixComptime(t.abs_root, "/"))
        assert(std.fs.path.isAbsolute(t.abs_root))
        let root_info = r.readDirInfoIgnoreError(t.abs_root) ?? return
        var arena_state = ArenaAllocator.init(alloc)
        defer arena_state.deinit()
        scanInner(alloc, t, ty, r, root_info, arena_state, ctx)
    }

    func scanInner(
        alloc: Allocator,
        t: Type,
        t_index: Type.Index,
        r: Resolver,
        dir_info: DirInfo,
        arena_state: ArenaAllocator,
        ctx: InsertionContext,
    ): Unit {
        // 遍历目录树并发现路由文件
        // 完整实现需要递归文件系统遍历和路由模式解析
    }

    /// JS 绑定，用于测试
    public class JSFrameworkRouter {
        public var files: ArrayList<bun.String>
        public var router: FrameworkRouter
        public var stored_parse_errors: ArrayList<ParseError>

        public class ParseError {
            public var rel_path: String
            public var log: TinyLog
        }
    }
}

// 错误类型
public enum PatternParseError {
    | InvalidRoutePattern
}

// 类型别名
public type OpaqueFileId = bun.GenericIndex<UInt32, Any>
public type StaticRouteMap = bun.StringArrayHashMapUnmanaged<Route.Index>
public type DynamicRouteMap = std.ArrayHashMapUnmanaged<EncodedPattern, Route.Index, EncodedPattern.EffectiveURLContext, true>
public type ArrayListUnmanaged<T> = std.ArrayListUnmanaged<T>
public type ArenaAllocator = std.heap.ArenaAllocator
public type Allocator = std.mem.Allocator
public type Resolver = bun.resolver.Resolver
public type DirInfo = bun.resolver.DirInfo
public type BoundedArray<T, N> = bun.BoundedArray<T, N>
public type RouteBundle = dev_server.RouteBundle
public type Strong = jsc.Strong
public type JSValue = jsc.JSValue
public type JSGlobalObject = jsc.JSGlobalObject
