// Stub types for bao_runtime.bake
// Types imported from real packages where available.
// Remaining stubs marked [KEPT] with reason.
//
// [KEPT] reasons:
//   "no-pkg"       — no real package yet provides this type
//   "deferred"     — depends on another [KEPT] type, will resolve later
//   "wrapper"      — thin wrapper around String/Array for API compat

package bao_runtime.bake

import bao_bun_alloc.Allocator
import bao_bundler.Transpiler
import bao_bundler.Source
import bao_bundler.SourceMapOption
import bao_bundler.BundleV2
import bao_bundler.Arena
import bao_bundler.Resolver
import bao_bundler.Plugin
import bao_bundler.Define
import bao_bundler.DefineData
import bao_collections.*
import bao_core.Output
import bao_core.ArenaAllocator
import bao_core.AllocationScope
import bao_core.DevAllocator
import bao_jsc.JsValue
import bao_jsc.JSGlobalObject
import bao_jsc.JsObject
import bao_jsc.JsString
import bao_jsc.JsArray
import bao_jsc.JsFunction
import bao_jsc.JsError
import bao_jsc.Strong
import bao_jsc.ZigStringSlice
import bao_jsc.CallFrame
import bao_jsc.HostFunction
import bao_jsc.JSFunction
import bao_jsc.StrongOptional
import bao_safety.ThreadLock
import bao_event_loop.EventLoopTimer
import bao_watcher.Watcher
import bao_options.LoaderMap
import bao_options.DotEnvBehavior
import bao_options.SourceMapMode
import bao_path.*
import bao_runtime.bake.dev_server.SerializedFailure
import bao_runtime.bake.dev_server.HmrSocket

// ============================================================================
// Types imported from real packages (replaces previous local definitions):
//   ThreadLock        <- bao_safety.ThreadLock
//   EventLoopTimer    <- bao_event_loop.EventLoopTimer
//   Watcher           <- bao_watcher.Watcher
//   AllocationScope   <- bao_core.AllocationScope
//   DevAllocator      <- bao_core.DevAllocator
// ============================================================================

/// HTTP method enum
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
            case _ => Option<HTTPMethod>.None
        }
    }

    public static func which(code: Int64): ?HTTPMethod {
        match (code) {
            case 0 => HTTPMethod.GET
            case 1 => HTTPMethod.POST
            case 2 => HTTPMethod.PUT
            case 3 => HTTPMethod.DELETE
            case 4 => HTTPMethod.PATCH
            case 5 => HTTPMethod.HEAD
            case 6 => HTTPMethod.OPTIONS
            case _ => Option<HTTPMethod>.None
        }
    }
}

/// UWS request [KEPT: no-pkg]
/// 对应 Bun: uws.Request
/// uWebSockets HTTP 请求封装
public class UwsRequest {
    public var url_value: String = "/"
    public var method_value: Int64 = 0
    public var yield_value: Bool = true
    public var parameters: Array<String> = []
    public init() {}
    public func parameter(index: Int64): String {
        if (index >= 0 && index < parameters.size) { parameters[Int64(index)] } else { "" }
    }
    public func parameter(name: String): String { "" }
    public func method(): Int64 { method_value }
    public func url(): String { url_value }
    public func setYield(value: Bool): Unit { yield_value = value }
    public func fullPath(): String { url_value }
}

/// Any HTTP response [KEPT: no-pkg]
/// 对应 Bun: uws.Response
/// 注意: 此类型在 dev_server/mod.cj 中也有定义
public class AnyResponse {
    public init() {}
    public func end(body: String, close: Bool): Unit {}
    public func writeStatus(status: String): Unit {}
    public func writeHeader(name: String, value: String): Unit {}
    public func corked(callback: (AnyResponse) -> Unit): Unit { callback(this) }
    public func corked(callback: (AnyResponse) -> Unit, extra: AnyResponse): Unit { callback(extra) }
}

/// Saved request [KEPT: no-pkg]
/// 对应 Bun: bake.SavedRequest
/// 保存 UWS 请求的快照，用于异步处理
public class SavedRequest {
    public var request: UwsRequest
    public var method: HTTPMethod
    public var url_value: String = "/"
    public var headers: HashMap<String, String> = HashMap<String, String>()
    public init() {
        request = UwsRequest()
        method = HTTPMethod.GET
    }
    public init(req: UwsRequest) {
        request = req
        method = HTTPMethod.which(req.method()) ?? HTTPMethod.GET
        url_value = req.url()
    }
    public func url(): String { url_value }
    public func header(name: String): ?String { headers.get(name) }
}

/// Any request context [KEPT: no-pkg]
public class AnyRequestContext {}

/// JS bundler plugin [KEPT: no-pkg]
/// 对应 Bun: bun.Plugin
/// JavaScript bundler 插件
public class JSBundlerPlugin {
    public var name: String = ""
    public var setup: Any? = None
    public init() {}
    public init(name: String) { this.name = name }
}

/// Request handler type
public type RequestHandler = Any

/// Debugger ID type
public type DebuggerId = Int64

/// Dir type [KEPT: no-pkg]
public class Dir {
    public init() {}
}

/// Opcode for WebSocket
public enum Opcode {
    | text
    | binary
    | close
    | ping
    | pong
}

/// Promise type [KEPT: no-pkg]
/// 仓颉 stdlib 提供 Promise，此类型为 Bun API 兼容层
public class Promise<T> {
    public init() {}
    public static func resolve(value: T): Promise<T> { Promise<T>() }
    public static func unit(): Promise<Unit> { Promise<Unit>() }
    public func then(callback: (T) -> Unit): Unit {}
    public func then<U>(callback: (T) -> U): Promise<U> { Promise<U>() }
    public func `catch`(callback: (Any) -> Unit): Promise<T> { this }
}

/// Incremental graph [KEPT: no-pkg]
/// 对应 Bun: bake.DevServer.IncrementalGraph
/// 增量构建图，跟踪文件间的依赖关系
public class IncrementalGraph {
    public static let empty: IncrementalGraph = IncrementalGraph()
    public init() {}
    public func deinit(): Unit {}
    public func ensureStaleBitCapacity(server: Bool): Unit {}
    /// 插入空文件条目，返回插入结果
    public func insertEmpty(path: String, kind: Any): InsertResult { InsertResult() }
    /// 使指定路径的文件失效
    public func invalidate(paths: Array<String>, entry_points: Any, alloc: Allocator): Unit {}
    /// 获取文件索引
    public func getFileIndex(path: String): ?UInt32 { None }
}

/// String hash map [KEPT: no-pkg]
public class StringHashMap<V> {
    public init() {}
    public func deinit(alloc: Allocator): Unit {}
}

/// Directory watch store [KEPT: deferred - real type in dev_server/directory_watch_store.cj]
/// 对应 Bun: bake.DevServer.DirectoryWatchStore
/// 跟踪目录监视器和解析失败的依赖
public class DirectoryWatchStore {
    public static let empty: DirectoryWatchStore = DirectoryWatchStore()
    public var watches: AutoArrayHashMapUnmanaged<String, Unit>
    public var dependencies: ArrayListUnmanaged<WatchDependency>
    public init() {
        watches = AutoArrayHashMapUnmanaged<String, Unit>()
        dependencies = ArrayListUnmanaged<WatchDependency>()
    }
    /// 跟踪解析失败
    public func trackResolutionFailure(import_source: String, specifier: String, renderer: Any, loader: Any): Unit {}
}

public class WatchDependency {
    public var specifier: String = ""
    public init() {}
}

/// Watcher atomics [KEPT: deferred - real type in dev_server/watcher_atomics.cj]
public class WatcherAtomics {
    public var events: Array<WatcherAtomicEvent>
    public init() {
        events = Array<WatcherAtomicEvent>()
    }
}

public class WatcherAtomicEvent {
    public var dirs: AutoArrayHashMapUnmanaged<String, Unit>
    public var files: AutoArrayHashMapUnmanaged<String, Unit>
    public var extraFiles: AutoArrayHashMapUnmanaged<String, Unit>
    public init() {
        dirs = AutoArrayHashMapUnmanaged<String, Unit>()
        files = AutoArrayHashMapUnmanaged<String, Unit>()
        extraFiles = AutoArrayHashMapUnmanaged<String, Unit>()
    }
    public func deinit(alloc: Allocator): Unit {}
}

/// HTML bundle route [KEPT: no-pkg]
public class HTMLBundleRoute {
    public init() {}
}

/// Assets store [KEPT: deferred - real type in dev_server/assets.cj]
/// 对应 Bun: bake.DevServer.Assets
/// 哈希资产存储，通过 /_bun/asset/<hash>.ext 提供
public class Assets {
    public init() {}
    public func get(hash: UInt64): ?Asset { Option<Asset>.None }
    public func deinit(alloc: Allocator): Unit {}
    /// 替换路径
    public func replacePath(abs_path: String, contents: AnyBlob, mime_type: MimeType, content_hash: UInt64): Any { Object() }
    /// 取消引用
    public func unrefByHash(hash: UInt64, count: UInt32): Unit {}
    /// 内存成本
    public func memoryCost(): UInt64 { 0 }
}

public class Asset {
    public func on(resp: AnyResponse): Unit {}
}

/// Source map store [KEPT: deferred - real type in dev_server/source_map_store.cj]
/// 对应 Bun: bake.DevServer.SourceMapStore
/// 管理源映射的引用计数存储
public class SourceMapStore {
    public static let empty: SourceMapStore = SourceMapStore()
    public var entries: AutoArrayHashMapUnmanaged<UInt64, SourceMapEntry>
    public init() {
        entries = AutoArrayHashMapUnmanaged<UInt64, SourceMapEntry>()
    }
    public func unref(key: UInt64): Unit {}
    public func removeOrUpgradeWeakRef(key: UInt64, mode: WeakRefMode): Bool { false }
    /// 添加弱引用
    public func addWeakRef(key: UInt64): Unit {}
    /// 获取解析后的源映射
    public func getParsedSourceMap(key: UInt64, arena: Allocator, gpa: Allocator): ?Any { None }
}

public class SourceMapEntry {
    public init() {}
    public func renderJSON(dev: DevServer, alloc: Allocator, kind: UInt64, alloc2: Allocator, side: Side): Array<Byte> { Array<Byte>() }
    public func deinit(): Unit {}
}

public enum WeakRefMode {
    | upgrade
    | downgrade
}

/// Array hash map unmanaged [KEPT: no-pkg]
public class ArrayHashMapUnmanaged<K, V> {
    public init() {}
    public func keys(): Array<K> { Array<K>() }
    public func deinit(alloc: Allocator): Unit {}
    public func count(): Int64 { 0 }
}

/// Auto hash map unmanaged [KEPT: no-pkg]
public class AutoHashMapUnmanaged<K, V> {
    public init() {}
    public func deinit(alloc: Allocator): Unit {}
    public func keyIterator(): KeyIterator<K> { KeyIterator<K>() }
    public func count(): Int64 { 0 }
    public func put(alloc: Allocator, key: K, value: V): Unit {}
    public func remove(key: K): Bool { false }
    public func fetchRemove(key: K): ?KeyValue<K, V> { Option<KeyValue<K, V>>.None }
}

public class KeyValue<K, V> {
    public var key: K
    public var value: V
    public init(key: K, value: V) {
        this.key = key
        this.value = value
    }
}

public class KeyIterator<T> {
    public init() {}
    public func next(): ?T { Option<T>.None }
}

/// DevServer input [KEPT: no-pkg]
public class DevServerInput {
    public init() {}
}

/// VirtualMachine [KEPT: deferred]
/// 对应 Bun: bun.JSC.VirtualMachine
/// 注意: 真实类型在 bao_jsc.BunVirtualMachine 中。
/// 此类型保留是因为 bake 包使用的 API 子集与 BunVirtualMachine 不同，
/// 待 bao_jsc 完善后替换为 import。
public class VirtualMachine {
    public static func get(): VirtualMachine { VirtualMachine() }
    public var global: JSGlobalObject
    public var eventLoop: Any
    public var arena: ArenaAllocator
    public var jscVm: Any
    public var allocator: Allocator
    public var argv: Array<String>
    public init() {
        global = JSGlobalObject()
        eventLoop = Object()
        arena = ArenaAllocator()
        jscVm = Object()
        allocator = Allocator()
        argv = Array<String>()
    }
    public func deinit(): Unit {}
    public func preload(): Unit {}
    public func isMainThread(): Bool { true }
    public func isMainThreadVm(): Bool { true }
    public func globalExit(): Unit {}
    public func onExit(callback: () -> Unit): Unit {}
    public func printErrorLikeObjectToConsole(err: JsValue): Unit {}
    public func waitForPromise(promise: JsValue): JsValue { JsValue() }
    public func loadExtraEnvAndSourceCodePrinter(): Unit {}
    public func initBake(): Unit {}
    public func configureDefines(defines: DefineData): Unit {}
    public func transpiler(): Transpiler { Transpiler() }
    public func regularEventLoop(): Any { Object() }
    public func log(level: Int64, msg: String): Unit {}
}

/// BunString [KEPT: wrapper]
/// 对应 Bun: bun.String
/// 在仓颉中直接使用 String，此类型用于 API 兼容
public class BunString {
    public var value: String = ""
    public init() {}
    public init(s: String) { value = s }
    public static func `static`(s: String): BunString { BunString(s) }
    public static func createFormat(fmt: String): BunString { BunString(fmt) }
    public func toJS(global: JSGlobalObject): JsValue { JsValue() }
    public func toUTF8(alloc: Allocator): String { value }
    public func toString(): String { value }
    public func slice(): String { value }
    public func isEmpty(): Bool { value.isEmpty() }
}

/// HiveArray [KEPT: no-pkg]
public class HiveArray<T> {
    public init() {}
    public func get(): T { throw Exception("unimplemented") }
}

/// Memory cost [KEPT: deferred - real type in dev_server/memory_cost.cj]
public class MemoryCost {
    public static func memoryCost(dev: DevServer): Int64 { 0 }
}

/// Static route [KEPT: no-pkg]
/// 对应 Bun: bake.DevServer.StaticRoute
/// 静态文件路由，用于服务预构建的文件
public class StaticRoute {
    public var blob: AnyBlob = AnyBlob()
    public var mime_type: MimeType = MimeType.text
    public var status_code: Int32 = 200
    public init() {}
    public static func initFromAnyBlob(blobs: Array<Blob>, opts: StaticRouteOptions): StaticRoute {
        let route = StaticRoute()
        if (blobs.size > 0) { route.blob = AnyBlob() }
        route.mime_type = opts.mimeType
        return route
    }
    public func onRequest(resp: AnyResponse): Unit {
        resp.writeStatus("${status_code} OK")
        resp.end("", false)
    }
    public func deref(): Unit {}
    public func memoryCost(): UInt64 { 0 }
}

public class StaticRouteOptions {
    public var server: ?AnyServer
    public var mimeType: MimeType
    public init(server: ?AnyServer, mimeType: MimeType) {
        this.server = server
        this.mimeType = mimeType
    }
}

public enum MimeType {
    | json
    | html
    | javascript
    | css
    | text
}

/// Blob [KEPT: deferred - real type in bao_runtime.webcore]
public class Blob {
    public init() {}
}

/// SendStatus enum
public enum SendStatus {
    | dropped
    | sent
}

/// PluginTarget [KEPT: no-pkg]
public class PluginTarget {
    public init(dev: DevServer) {}
}

/// DirInfo [KEPT: no-pkg]
public class DirInfo {
    public init() {}
}

/// BoundedArray [KEPT: no-pkg]
/// 对应 Bun: std.BoundedArray
/// 有容量限制的数组
public class BoundedArray<T> {
    public var slice: Array<T>
    public var capacity: Int64
    public init(capacity: Int64) {
        slice = Array<T>()
        this.capacity = capacity
    }
    public init() {
        slice = Array<T>()
        capacity = 0
    }
    public func append(item: T): Bool {
        if (slice.size >= capacity) { return false }
        slice = Array<T>(slice.size + 1, { i => if (i < slice.size) { slice[i] } else { item } })
        return true
    }
    public func len(): Int64 { slice.size }
    public func get(index: Int64): ?T {
        if (index >= 0 && index < slice.size) { slice[index] } else { None }
    }
}

/// Object helper class
public class Object {
    public init() {}
}

/// MapIterator [KEPT: no-pkg]
public class MapIterator<K, V> {
    public init() {}
    public func next(): ?MapEntry<K, V> { Option<MapEntry<K, V>>.None }
}

public class MapEntry<K, V> {
    public var key: K
    public var value: V
    public init(key: K, value: V) {
        this.key = key
        this.value = value
    }
}

/// WatchKind enum
public enum WatchKind {
    | create
    | modify
    | delete
    | rename
}

/// DynamicRouteMap [KEPT: deferred - real type in dev_server/packed_map.cj]
public class DynamicRouteMap {
    public init() {}
    public func deinit(alloc: Allocator): Unit {}
    public func keys(): Array<FrameworkRouterEncodedPattern> { Array<FrameworkRouterEncodedPattern>() }
    public func values(): Array<FrameworkRouterRouteIndex> { Array<FrameworkRouterRouteIndex>() }
    public func get(key: String): ?FrameworkRouterEncodedPattern { Option<FrameworkRouterEncodedPattern>.None }
    public static func DataList(): DataListHelper { DataListHelper() }
}

/// StaticRouteMap [KEPT: deferred - real type in dev_server/packed_map.cj]
public class StaticRouteMap {
    public init() {}
    public func deinit(alloc: Allocator): Unit {}
    public func get(key: String): ?FrameworkRouterRouteIndex { Option<FrameworkRouterRouteIndex>.None }
    public static func DataList(): DataListHelper { DataListHelper() }
}

public class DataListHelper {
    public init() {}
    public static func capacityInBytes(cap: Int64): UInt64 { 0 }
}

/// AnyServer [KEPT: no-pkg]
/// 对应 Bun: bake.AnyServer
/// 封装 HTTP 服务器实例
public class AnyServer {
    public var app: Any = Object()
    public init() {}
    public static func from(server: Any): AnyServer {
        let s = AnyServer()
        s.app = server
        return s
    }
    public init(app: Any) { this.app = app }
    public func getOrLoadPlugins(target: PluginTarget): PluginState { PluginState.loaded }
    public func onSavedRequest(req: Any, resp: AnyResponse, callback: Any, count: Int64, args: Array<JsValue>): Unit {}
    /// 发布消息到所有 WebSocket 连接
    public func publish(topic: String, data: Array<Byte>, opcode: Any): Unit {}
}

/// PluginState [KEPT: no-pkg]
public enum PluginState {
    | unknown
    | pending
    | loaded
    | err

    public operator func ==(right: PluginState): Bool {
        match (this) {
            case unknown => match (right) { case unknown => true; case _ => false }
            case pending => match (right) { case pending => true; case _ => false }
            case loaded => match (right) { case loaded => true; case _ => false }
            case err => match (right) { case err => true; case _ => false }
        }
    }
    public operator func !=(right: PluginState): Bool { !(this == right) }
}

/// panic function
public func panic(msg: String): Nothing {
    throw Exception(msg)
}

/// assert functions
public func assert(condition: Bool): Unit {
    if (!condition) {
        panic("assertion failed")
    }
}

public func assert(condition: Bool, message: String): Unit {
    if (!condition) {
        panic("assertion failed: " + message)
    }
}

/// AllocationScope extension methods via top-level functions
public func initDefaultAllocationScope(): AllocationScope { AllocationScope() }
public func allocatorOfAllocationScope(scope: AllocationScope): Allocator { Allocator() }
public func borrowAllocationScope(scope: AllocationScope): DevAllocator { DevAllocator() }

/// BakeLoadInitialServerCode function
public func BakeLoadInitialServerCode(global: JSGlobalObject, runtime: BunString, separateSsrGraph: Bool): JsValue {
    JsValue()
}

/// Bun framework reference
public class BunRef {
    public var bake: BakeRef
    public var path: PathRef
    public var strings: StringsRef
    public var default_allocator: Allocator
    public var jsc: JscRef
    public var api: ApiRef
    public var resolver: ResolverRef
    public var http: HttpRef
    public var hash: HashRef
    public init() {
        bake = BakeRef()
        path = PathRef()
        strings = StringsRef()
        default_allocator = Allocator()
        jsc = JscRef()
        api = ApiRef()
        resolver = ResolverRef()
        http = HttpRef()
        hash = HashRef()
    }
}

public class BakeRef {
    public init() {}
    public func getHmrRuntime(side: Side): HmrRuntime { HmrRuntime("") }
}

public class PathRef {
    public init() {}
    public func relative(base: String, path: String): String { path }
    public static func joinAbsStringZ(base: String, rel: String): String { base + "/" + rel }
}

public class StringsRef {
    public init() {}
    public static func eqlComptime(a: String, b: String): Bool { a == b }
    public static func eql(a: String, b: String): Bool { a == b }
    public static func hasSuffix(s: String, suffix: String): Bool { s.endsWith(suffix) }
    public static func hasPrefix(s: String, prefix: String): Bool { s.startsWith(prefix) }
    public static func hasSuffixComptime(s: String, suffix: String): Bool { s.endsWith(suffix) }
    public static func hasPrefixComptime(s: String, prefix: String): Bool { s.startsWith(prefix) }
    public static func withoutTrailingSlashWindowsPath(s: String): String {
        if (s.endsWith("/") || s.endsWith("\\")) { s[0..s.size - 1] } else { s }
    }
    public static func indexOfCharPos(s: String, ch: UInt8, from: UInt64): ?UInt64 {
        var i = from
        while (i < UInt64(s.size)) {
            if (UInt8(s[Int64(i)]) == ch) { return i }
            i += 1
        }
        return Option<UInt64>.None
    }
}

public class ResolverRef {
    public init() {}
    public func isPackagePath(path: String): Bool { path.startsWith("@") || !path.startsWith("/") && !path.startsWith(".") }
}

public class HttpRef {
    public init() {}
}

public class HashRef {
    public init() {}
    public func apply(data: Array<Byte>): UInt64 { 0 }
}

public class JscRef {
    public init() {}
    public func initialize(b: Bool): Unit {}
}

public class ApiRef {
    public init() {}
}

/// Bun global reference
public let bun = BunRef()

/// toBytes utility
public func toBytes(value: UInt32): Array<Byte> {
    var result = Array<Byte>(4, { _ => 0 })
    result[0] = UInt8(value & UInt32(0xFF))
    result[1] = UInt8((value >> 8) & UInt32(0xFF))
    result[2] = UInt8((value >> 16) & UInt32(0xFF))
    result[3] = UInt8((value >> 24) & UInt32(0xFF))
    return result
}

/// FileSystem [KEPT: no-pkg]
/// 对应 Bun: bun.FS
/// 提供文件系统操作接口
public class FileSystem {
    public static func get(): FileSystem { FileSystem() }
    public var topLevelDir: String = "/"
    public init() {}
    public func exists(path: String): Bool { true }
    public func readFile(path: String): ?String { None }
    public func readDir(path: String): Array<String> { Array<String>() }
    public func isAbsolute(path: String): Bool { path.startsWith("/") }
    public func normalize(path: String): String { path }
}

/// DeferredRequest list [KEPT: no-pkg]
public class DeferredRequestList {
    public init() {}
    public func prepend(item: Any): Unit {}
}

/// Timer [KEPT: no-pkg]
public class Timer {
    public init() {}
    public static func start(): Timer { Timer() }
}

/// Global [KEPT: no-pkg]
public class Global {
    public static func crash(): Nothing { throw Exception("crash") }
}

/// Format enum [KEPT: no-pkg]
public enum Format {
    | esm
    | cjs
    | iife
    | internalBakeDev
}

/// ImportKind [KEPT: no-pkg]
public enum ImportKind {
    | stmt
    | `import`
    | require
    | dynamic
    | stylesheet
    | at
}

/// CWD helper
public func getCwd(): String { "/" }

/// String.joinAbs helper
public func joinAbsStringZ(base: String, rel: String): String {
    if (base.endsWith("/")) { base + rel } else { base + "/" + rel }
}
