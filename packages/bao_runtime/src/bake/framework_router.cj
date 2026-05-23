// 翻译自 Bun: src/runtime/bake/FrameworkRouter.zig
// 从文件系统发现路由，由框架配置指导。
// 与所有不同的范式无关。支持增量更新用于 DevServer，或序列化为二进制用于生产。

package bao_runtime.bake

import bao_bun_alloc.Allocator
import bao_core.Output

/// 从文件系统发现路由，由框架配置指导。
/// 与所有不同的范式无关。支持增量更新用于 DevServer，或序列化为二进制用于生产。
public class FrameworkRouter {
    public var root: String
    public var types: Array<FrameworkRouterType>
    public var routes: ArrayListUnmanaged<FrameworkRouterRoute>
    /// 键是完整 URL，带前导 /，无尾随 /
    /// 值是 Route Index
    public var static_routes: StaticRouteMap
    /// 所有动态模式的平面列表
    public var dynamic_routes: DynamicRouteMap
    /// 模式字符串的 arena 分配器
    public var pattern_string_arena: ArenaAllocator

    /// 初始化空路由器
    public static func initEmpty(root: String, types: Array<FrameworkRouterType>, allocator: Allocator): FrameworkRouter {
        assert(std.fs.path.isAbsolute(root))

        var routes = ArrayListUnmanaged<FrameworkRouterRoute>.initCapacity(allocator, types.size)
        for ((ty, type_index) in types) {
            ty.abs_root = bun.strings.withoutTrailingSlashWindowsPath(ty.abs_root)
            assert(bun.strings.hasPrefix(ty.abs_root, root))

            routes.appendAssumeCapacity(FrameworkRouterRoute(
                FrameworkRouterPart.text(""),
                FrameworkRouterType.Index(type_index),
                FrameworkRouterRouteIndex.Optional.none,
                FrameworkRouterRouteIndex.Optional.none,
                FrameworkRouterRouteIndex.Optional.none,
                FrameworkRouterRouteIndex.Optional.none,
                OpaqueFileId.Optional.none,
                OpaqueFileId.Optional.none,
            ))
        }
        return FrameworkRouter(
            bun.strings.withoutTrailingSlashWindowsPath(root),
            types,
            routes,
            DynamicRouteMap(),
            StaticRouteMap(),
            ArenaAllocator(allocator),
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
        cost += routes.capacity * sizeOf<FrameworkRouterRoute>()
        cost += StaticRouteMap.DataList.capacityInBytes(static_routes.entries.capacity)
        cost += DynamicRouteMap.DataList.capacityInBytes(dynamic_routes.entries.capacity)
        return cost
    }

    /// 扫描所有路由类型
    public func scanAll(allocator: Allocator, r: Resolver, ctx: FrameworkRouterInsertionContext): Unit {
        for ((ty, i) in types) {
            scan(allocator, FrameworkRouterType.Index(i), r, ctx)
        }
    }

    /// 获取路由指针
    public func routePtr(i: FrameworkRouterRouteIndex): FrameworkRouterRoute {
        return routes.items[i.getOrThrow()]
    }

    /// 获取类型指针
    public func typePtr(i: FrameworkRouterType.Index): FrameworkRouterType {
        return types[i.getOrThrow()]
    }

    func newRoute(alloc: Allocator, route_data: FrameworkRouterRoute): FrameworkRouterRouteIndex {
        let i = routes.items.size
        routes.append(alloc, route_data)
        return FrameworkRouterRouteIndex(i)
    }

    /// 慢速匹配，适用于开发模式
    public func matchSlow(path: String, params: FrameworkRouterMatchedParams): ?FrameworkRouterRouteIndex {
        params.params = BoundedArray<FrameworkRouterMatchedParamsEntry, FrameworkRouterMatchedParams.max_count>()
        assert(path[0] == '/')
        if (let Some(static_val) <- static_routes.get(path)) {
            return static_val
        }
        for ((pattern, i) in dynamic_routes.keys()) {
            if (pattern.matches(path, params)) {
                return dynamic_routes.values()[i]
            }
        }
        return None
    }

    /// 扫描特定类型的路由
    public func scan(alloc: Allocator, ty: FrameworkRouterType.Index, r: Resolver, ctx: FrameworkRouterInsertionContext): Unit {
        let t = types[ty.getOrThrow()]
        assert(!bun.strings.hasSuffixComptime(t.abs_root, "/"))
        assert(std.fs.path.isAbsolute(t.abs_root))
        let root_info = r.readDirInfoIgnoreError(t.abs_root) ?? return
        var arena_state = ArenaAllocator(alloc)
        defer { arena_state.deinit() }
        scanInner(alloc, t, ty, r, root_info, arena_state, ctx)
    }

    func scanInner(
        alloc: Allocator,
        t: FrameworkRouterType,
        t_index: FrameworkRouterType.Index,
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
    public var part: FrameworkRouterPart
    public var `type`: FrameworkRouterType.Index
    public var parent: FrameworkRouterRouteIndex.Optional
    public var first_child: FrameworkRouterRouteIndex.Optional
    public var prev_sibling: FrameworkRouterRouteIndex.Optional
    public var next_sibling: FrameworkRouterRouteIndex.Optional
    public var file_page: OpaqueFileId.Optional = OpaqueFileId.Optional.none
    public var file_layout: OpaqueFileId.Optional = OpaqueFileId.Optional.none
    /// 仅用于 DevServer
    public var bundle: RouteBundle.Index.Optional = RouteBundle.Index.Optional.none

    public func filePtr(file_kind: FrameworkRouterFileKind): OpaqueFileId.Optional {
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
    public init(v: UInt32) { value = v }
    public init() {}
}

/// 路由索引 Optional
public struct FrameworkRouterRouteIndexOptional {
    public var value: ?UInt32 = None
    public static let none: FrameworkRouterRouteIndexOptional = FrameworkRouterRouteIndexOptional(value: None)
    public func unwrap(): ?UInt32 { value }
}

/// 路由类型
public class FrameworkRouterType {
    public var abs_root: String
    public var prefix: String = "/"
    public var ignore_underscores: Bool = false
    public var ignore_dirs: Array<String> = [ ".git", "node_modules" ]
    public var extensions: Array<String>
    public var style: FrameworkRouterStyle
    public var allow_layouts: Bool
    public var client_file: OpaqueFileId.Optional
    public var server_file: OpaqueFileId
    public var server_file_string: Strong.Optional

    public static func rootRouteIndex(type_index: FrameworkRouterTypeIndex): FrameworkRouterRouteIndex {
        return FrameworkRouterRouteIndex(type_index.getOrThrow())
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
            case text(a) => match (other) { case text(b) => bun.strings.eql(a, b) case _ => false }
            case param(a) => match (other) { case param(b) => bun.strings.eql(a, b) case _ => false }
            case catch_all(a) => match (other) { case catch_all(b) => bun.strings.eql(a, b) case _ => false }
            case catch_all_optional(a) => match (other) { case catch_all_optional(b) => bun.strings.eql(a, b) case _ => false }
            case group(a) => match (other) { case group(b) => bun.strings.eql(a, b) case _ => false }
        }
    }
}

/// EncodedPattern - 路由模式的序列化格式
public class FrameworkRouterEncodedPattern {
    public var data: Array<Byte>

    public static let root: FrameworkRouterEncodedPattern = FrameworkRouterEncodedPattern([])

    public func iterate(): FrameworkRouterEncodedPatternIterator {
        return FrameworkRouterEncodedPatternIterator(this, 0)
    }

    public func partAt(byte_offset: UInt64): ?FrameworkRouterPart {
        return FrameworkRouterEncodedPatternIterator(this, byte_offset).peek()
    }

    public func effectiveURLHash(): UInt64 {
        var stack_space: Array<Byte> = Array<Byte>(std.fs.max_path_bytes * 2, { _ => UInt8(0) })
        var pos: UInt64 = 0
        var it = iterate()
        while (let Some(item) <- it.next()) {
            match (item) {
                case text(text_val) =>
                    stack_space[pos] = '/'.toByte()
                    pos += 1
                    stack_space.write(pos, text_val)
                    pos += text_val.size
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

    public func matches(path: String, params: FrameworkRouterMatchedParams): Bool {
        var param_num: UInt64 = 0
        var it = iterate()
        var i: UInt64 = 1
        while (let Some(part) <- it.next()) {
            match (part) {
                case text(expect) =>
                    if (path.size < i + expect.size ||
                        !(path.size == i + expect.size || path[i + expect.size] == '/')) {
                        return false
                    }
                    if (!bun.strings.eql(path.slice(i, i + expect.size), expect)) {
                        return false
                    }
                    i += 1 + expect.size
                case param(name) =>
                    let end = bun.strings.indexOfCharPos(path, '/', i) ?? path.size
                    params.params.buffer[param_num] = FrameworkRouterMatchedParamsEntry(name, path.slice(i, end))
                    params.params.size = param_num + 1
                    param_num += 1
                    i = if (end == path.size) { end } else { end + 1 }
                case catch_all(name) =>
                    if (i < path.size) {
                        var segment_start = i
                        while (segment_start < path.size) {
                            let segment_end = bun.strings.indexOfCharPos(path, '/', segment_start) ?? path.size
                            if (segment_start < segment_end) {
                                params.params.buffer[param_num] = FrameworkRouterMatchedParamsEntry(name, path.slice(segment_start, segment_end))
                                params.params.size = param_num + 1
                                param_num += 1
                            }
                            segment_start = if (segment_end == path.size) { segment_end } else { segment_end + 1 }
                        }
                    }
                    return true
                case catch_all_optional(name) =>
                    if (i < path.size) {
                        var segment_start = i
                        while (segment_start < path.size) {
                            let segment_end = bun.strings.indexOfCharPos(path, '/', segment_start) ?? path.size
                            if (segment_start < segment_end) {
                                params.params.buffer[param_num] = FrameworkRouterMatchedParamsEntry(name, path.slice(segment_start, segment_end))
                                params.params.size = param_num + 1
                                param_num += 1
                            }
                            segment_start = if (segment_end == path.size) { segment_end } else { segment_end + 1 }
                        }
                    }
                    return true
                case group(_) => continue
            }
        }
        return i == path.size
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
        if (offset >= pattern.data.size) {
            return None
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
    public var params: BoundedArray<FrameworkRouterMatchedParamsEntry, max_count>

    public func toJS(global: JSGlobalObject): JsValue {
        let params_array = params.slice()
        if (params_array.size == 0) {
            return JsValue.null
        }
        let obj = JsValue.createEmptyObject(global, params_array.size)
        for (param in params_array) {
            obj.put(global, param.key, JsValue.fromString(global, param.value))
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
    | javascript_defined(Strong.Optional)

    public func deinit(): Unit {
        match (this) {
            case javascript_defined(strong) => strong.deinit()
            case _ => ()
        }
    }

    /// 解析路由样式
    public func parse(file_path: String, ext: String, log: FrameworkRouterTinyLog, allow_layouts: Bool, arena: Allocator): ?FrameworkRouterParsedPattern {
        assert(file_path[0] == '/')
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
    public var parts: Array<FrameworkRouterPart>
    public var kind: FrameworkRouterParsedPatternKind
}

/// ParsedPattern 种类
public enum FrameworkRouterParsedPatternKind {
    | page      // 可导航到
    | layout    // 不参与导航解析
    | extra     // 路由的其他相关文件
}

/// TinyLog - 非分配单消息日志，专门用于路由模式解析器的消息
public class FrameworkRouterTinyLog {
    public var msg: Array<Byte>
    public var cursor_at: UInt32
    public var cursor_len: UInt32

    public static let empty: FrameworkRouterTinyLog = FrameworkRouterTinyLog()

    public func fail(fmt: String, cursor_at_val: UInt64, cursor_len_val: UInt64): Error {
        write(fmt)
        this.cursor_at = UInt32(cursor_at_val)
        this.cursor_len = UInt32(cursor_len_val)
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
public class FrameworkRouterInsertionContext {
    public var opaque_ctx: Any
    public var vtable: FrameworkRouterVTable

    public static func wrap<T>(ctx: T): FrameworkRouterInsertionContext {
        // 类型擦除包装器
        return FrameworkRouterInsertionContext(ctx, FrameworkRouterVTable())
    }
}

/// InsertionContext VTable
public class FrameworkRouterVTable {
    public var getFileIdForRouter: (Any, String, FrameworkRouterRouteIndex, FrameworkRouterFileKind) -> OpaqueFileId
    public var onRouterSyntaxError: (Any, String, FrameworkRouterTinyLog) -> Unit
    public var onRouterCollisionError: (Any, String, OpaqueFileId, FrameworkRouterFileKind) -> Unit
}

/// JS 绑定，用于测试
public class JSFrameworkRouter {
    public var files: ArrayList<bun.String>
    public var router: FrameworkRouter
    public var stored_parse_errors: ArrayList<JSFrameworkRouterParseError>
}

/// JS 解析错误
public class JSFrameworkRouterParseError {
    public var rel_path: String
    public var log: FrameworkRouterTinyLog
}

// 错误类型
public enum PatternParseError {
    | InvalidRoutePattern
}

// 类型别名

// Stubs for referenced functions
func parseNextJsPages(file_path: String, ext: String, log: FrameworkRouterTinyLog, allow_layouts: Bool, arena: Allocator): ?FrameworkRouterParsedPattern { None }
func parseNextJsApp(file_path: String, ext: String, log: FrameworkRouterTinyLog, allow_layouts: Bool, arena: Allocator, kind: FrameworkRouterParsedPatternKind): ?FrameworkRouterParsedPattern { None }

/// EffectiveURLContext stub
public class FrameworkRouterEncodedPatternEffectiveURLContext {
    public static func hash(pattern: FrameworkRouterEncodedPattern): UInt64 {
        pattern.effectiveURLHash()
    }
    public static func eql(lhs: FrameworkRouterEncodedPattern, rhs: FrameworkRouterEncodedPattern): Bool {
        true
    }
}
