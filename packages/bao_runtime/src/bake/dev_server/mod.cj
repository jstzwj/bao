// 翻译自 Bun: src/runtime/bake/dev_server/mod.rs
// DevServer 子模块入口。
//
// [KEPT] reasons:
//   "no-pkg"       — no real package yet provides this type
//   "deferred"     — depends on another [KEPT] type, will resolve later
//   "forward-ref"  — forward reference to type defined in parent package
//   "wrapper"      — thin wrapper for API compat

package bao_runtime.bake.dev_server

import bao_bun_alloc.Allocator
import bao_collections.*
import bao_core.AllocationScope
import bao_core.DevAllocator
import bao_safety.ThreadLock
import bao_event_loop.EventLoopTimer
import bao_event_loop.TimerState

// ============================================================================
// 共享类型
// 仅包含未在其他专用文件中定义的类型
// ============================================================================

// ============================================================================
// 通信/WebSocket 类型
// ============================================================================

/// AnyWebSocket [KEPT: no-pkg]
public class AnyWebSocket {
    public init() {}
    public func send(data: Array<Byte>, opcode: Opcode, compress: Bool, fin: Bool): SendStatus { SendStatus.sent }
    public func close(): Unit {}
    public func getRemoteSocketInfo(): ?SocketInfo { None }
}

/// SocketInfo [KEPT: no-pkg]
public class SocketInfo {
    public var ip: String = ""
    public var is_ipv6: Bool = false
    public init() {}
}

/// Opcode [KEPT: no-pkg]
public enum Opcode {
    | text
    | binary
    | close
    | ping
    | pong
}

/// SendStatus [KEPT: no-pkg]
public enum SendStatus {
    | dropped
    | sent
}

// ============================================================================
// 基础设施工具
// ============================================================================

/// StringJoiner [KEPT: deferred - real type in bao_string.StringJoiner]
/// 保留此 [KEPT] 类型因为 API 表面不同
public class StringJoiner {
    public init(allocator: Allocator) {}
    public func pushStatic(s: String): Unit {}
    public func done(alloc: Allocator): Array<Byte> { Array<Byte>() }
    public func doneWithEnd(suffix: String): Array<Byte> { Array<Byte>() }
}

/// GenericIndex [KEPT: no-pkg]
public struct GenericIndex<T, P> {
    public var value: UInt32
    public init(value: UInt32) { this.value = value }
    public static func create(v: UInt32): GenericIndex<T, P> { GenericIndex<T, P>(v) }
}

/// BodyReaderMixin [KEPT: no-pkg]
public class BodyReaderMixin<T> {
    public init(alloc: Allocator) {}
    public func readBody(resp: AnyResponse): Unit {}
}

/// AnyResponse - HTTP 响应封装
/// 对应 Bun: uws.Response 或类似的 HTTP 响应
public class AnyResponse {
    public var status_code: Int32 = 200
    public var headers: HashMap<String, String> = HashMap<String, String>()
    public var body_data: String = ""
    public var ended: Bool = false
    public init() {}

    public func end(body: String, close: Bool): Unit {
        body_data = body
        ended = true
    }
    public func writeStatus(status: String): Unit {
        // 解析 "200 OK" 格式
        let spaceIdx = status.indexOf(' ')
        if (let Some(idx) <- spaceIdx) {
            status_code = 200 // TODO: parse status code from string
        }
    }
    public func writeHeader(name: String, value: String): Unit {
        headers.put(name, value)
    }
    public func corked(callback: (AnyResponse) -> Unit): Unit {
        callback(this)
    }
}

/// Timer [KEPT: no-pkg]
public class Timer {
    public init() {}
    public static func start(): Timer { Timer() }
}

/// TimerState - imported from bao_event_loop.TimerState
/// Previously had a local definition, now using the real type from import.

// ============================================================================
// IO 类型
// ============================================================================

/// FixedBufferStream [KEPT: no-pkg]
public class FixedBufferStream<T> {
    public init(data: T) {}
    public func reader(): Reader { Reader() }
}

/// Reader [KEPT: no-pkg]
public class Reader {
    public init() {}
    public func readInt<T>(): T { throw Exception("unimplemented") }
    public func readByte(): Byte { 0 }
    public func readAll(): Array<Byte> { Array<Byte>() }
}

/// Writer [KEPT: no-pkg]
public class Writer {
    public init() {}
    public func writeInt<T>(value: T): Unit {}
    public func writeByte(value: Byte): Unit {}
    public func writeAll(data: String): Unit {}
}

/// StackFallback [KEPT: no-pkg]
public struct StackFallback<N> {
    public init(capacity: Int64, alloc: Allocator) {}
    public func get(): Allocator { Allocator() }
}

/// ArenaAllocator imported from bao_core.ArenaAllocator
/// DevAllocator imported from bao_core.DevAllocator

/// Request - HTTP 请求
/// 对应 Bun: uws.Request 或 bun.Request
public class Request {
    public var url_value: String = "/"
    public var method_value: String = "GET"
    public var headers_value: HashMap<String, String> = HashMap<String, String>()
    public init() {}
    public init(url: String, method: String) {
        url_value = url
        method_value = method
    }
    public func url(): String { url_value }
    public func method(): String { method_value }
    public func header(name: String): ?String { headers_value.get(name) }
}

/// ConcurrentTask - 可跨线程调度的任务包装器
/// 对应 Bun: bun.JSC.ConcurrentTask
/// 包装一个 Task 以便通过事件循环安全地调度
public class ConcurrentTask {
    public var task: Task = Task()
    public init(task: Task) { this.task = task }
    public init() {}

    /// 在目标线程上执行任务
    public func run(): Unit {
        task.run()
    }
}

/// Task - 可调度任务单元
/// 对应 Bun: bun.JSC.Task
/// 在事件循环中执行的工作单元
public class Task {
    public var event: Any = Object()
    public init(ev: Any) { event = ev }
    public init() {}

    /// 执行任务
    public func run(): Unit {
        // 默认无操作; 子类型覆盖以提供具体行为
    }
}

/// Atomic<T> - 原子值封装
/// 对应 Bun: std.atomic.Atomic(T)
/// 在仓颉中使用简单的值封装，实际原子性由运行时保证
public struct Atomic<T> {
    public var value: T
    public init(value: T) { this.value = value }

    /// 原子交换
    public mut func swap(new_value: T, ordering: AtomicOrdering): T {
        let old = value
        value = new_value
        return old
    }
    /// 原子存储
    public mut func store(new_value: T, ordering: AtomicOrdering): Unit {
        value = new_value
    }
    /// 原子比较交换（弱版本）
    public mut func cmpxchgWeak(expected: T, new_value: T, success_ordering: AtomicOrdering, failure_ordering: AtomicOrdering): ?T {
        // 仓颉没有直接的对象相等比较，使用简化逻辑
        None
    }
    /// 原子加载
    public func load(ordering: AtomicOrdering): T { value }
}

/// AtomicOrdering - 内存排序
/// 对应 Zig: std.builtin.AtomicOrder
public enum AtomicOrdering {
    | monotonic
    | acqRel
    | release
    | acquire
    | seqCst
}

/// Mutex - 互斥锁
/// 对应 Bun: std.Thread.Mutex
/// 用于保护 IncrementalGraph 的并发访问
public class Mutex {
    public var locked: Bool = false
    public init() {}
    public func lock(): Unit {
        // 在单线程仓颉环境中，记录锁状态即可
    }
    public func unlock(): Unit {
        // 在单线程仓颉环境中，记录锁状态即可
    }
    public func getOrThrow(): Mutex { this }
    /// 断言已锁定（调试用）
    public func assertLocked(): Unit {}
}

// ============================================================================
// 核心服务器类型
// ============================================================================

/// DevServer [KEPT: forward-ref - main type defined in parent package dev_server.cj]
public class DevServer {
    public init() {}
    public func allocator(): Allocator { Allocator() }
    public func dev_allocator(): DevAllocator { DevAllocator() }
    public var vm: VirtualMachine = VirtualMachine()
    public var server: ?AnyServer = None
    public var source_maps: SourceMapStore = SourceMapStore()
    public var directory_watchers: DirectoryWatchStore = DirectoryWatchStore()
    public var client_graph: IncrementalGraph = IncrementalGraph()
    public var server_graph: IncrementalGraph = IncrementalGraph()
    public var watcher_atomics: WatcherAtomics = WatcherAtomics()
    public var assets: Assets = Assets()
    public var active_websocket_connections: HashMap<HmrSocket, Unit> = HashMap<HmrSocket, Unit>()
    public var graph_safety_lock: ThreadLock = ThreadLock()
    public var configuration_hash_key: Array<Byte> = []
    public var bundling_failures: HashMap<SerializedFailure, Unit> = HashMap<SerializedFailure, Unit>()
    public var route_bundles: Array<RouteBundle> = []
    public var current_bundle: ?CurrentBundle = None
    public var next_bundle: NextBundle = NextBundle()
    public var testing_batch_events: TestingBatchEvents = TestingBatchEvents.disabled
    public var inspector_server_id: Int64 = 0
    public var broadcast_console_log_from_browser_to_server: Bool = false
    public var server_transpiler: Transpiler = Transpiler()
    public var root: String = ""
    public var magic: Magic = Magic.valid
    public var bun_watcher: Any = Object()
    public func routeToBundleIndexSlow(pattern: String): ?UInt32 { None }
    public func routeBundlePtr(index: UInt32): RouteBundle { RouteBundle() }
    public func startAsyncBundle(entry_points: EntryPointList, had_reload_event: Bool, timer: EventLoopTimer): Unit {}
    public func relativePath(buf: PathBuffer, abs_path: String): String { abs_path }

    /// 解析十六进制字符串为整数
    /// 对应 Bun: pub fn parseHexToInt(comptime T: type, slice: []const u8) ?T
    public static func parseHexToInt64(slice: String): ?UInt64 {
        if (slice.size < 2) { return Option<UInt64>.None }
        var result: UInt64 = UInt64(0)
        for (i in 0..slice.size) {
            let byteVal = Int64(slice[Int64(i)])
            let digit: UInt64 = if (byteVal >= 48 && byteVal <= 57) {
                UInt64(byteVal - 48)
            } else if (byteVal >= 97 && byteVal <= 102) {
                UInt64(byteVal - 97 + 10)
            } else if (byteVal >= 65 && byteVal <= 70) {
                UInt64(byteVal - 65 + 10)
            } else {
                return Option<UInt64>.None
            }
            result = result * UInt64(16) + digit
        }
        return result
    }
}

/// VirtualMachine [KEPT: deferred - real type in bao_jsc.BunVirtualMachine]
/// 对应 Bun: bun.JSC.VirtualMachine
/// 保留是因为 bake 包使用 API 子集不同
public class VirtualMachine {
    public var event_loop: EventLoop = EventLoop()
    public var global: JSGlobalObject = JSGlobalObject()
    public var allocator_val: Allocator = Allocator()
    public var is_main_thread: Bool = true

    public init() {}

    /// 获取单例虚拟机
    public static func get(): VirtualMachine { VirtualMachine() }

    /// 判断是否为主线程
    public func isMainThread(): Bool { is_main_thread }
}

/// EventLoop - JS 事件循环
/// 对应 Bun: bun.JSC.EventLoop
/// 管理异步任务调度
public class EventLoop {
    public var tasks: ArrayList<ConcurrentTask> = ArrayList<ConcurrentTask>()

    public init() {}

    /// 将任务入队到事件循环
    public func enqueueTaskConcurrent(task: ConcurrentTask): Unit {
        tasks.append(task)
    }

    /// 排空所有待处理任务
    public func drain(): Unit {
        for (task in tasks.items) {
            task.run()
        }
        tasks.clear()
    }
}

/// JSGlobalObject [KEPT: deferred - real type in bao_jsc.JSGlobalObject]
/// 对应 Bun: bun.JSC.JSGlobalObject
public class JSGlobalObject {
    public var globalThis: Any = Object()
    public init() {}
}

/// AnyServer - HTTP 服务器封装
/// 对应 Bun: *bun.api.server.Server
/// 封装不同类型的服务器（HTTP/HTTPS）
public class AnyServer {
    public var app: Any = Object()
    public init() {}
    public static func from(server: Any): AnyServer {
        let s = AnyServer()
        s.app = server
        return s
    }
    public init(app: Any) { this.app = app }

    /// 加载或获取插件
    public func getOrLoadPlugins(target: PluginTarget): PluginState { PluginState.loaded }

    /// 处理保存的请求
    public func onSavedRequest(req: Any, resp: AnyResponse, callback: Any, count: Int64, args: Array<JsValue>): Unit {}
}

/// CurrentBundle [KEPT: forward-ref]
public class CurrentBundle {
    public init() {}
    public var reload_event: ?HotReloadEvent = None
}

/// NextBundle [KEPT: forward-ref]
public class NextBundle {
    public init() {}
    public var reload_event: ?HotReloadEvent = None
}

// ============================================================================
// 路由与框架类型
// ============================================================================

/// FrameworkRouter [KEPT: forward-ref - real type in parent package framework_router.cj]
public class FrameworkRouter {
    public init() {}
    public func memoryCost(): UInt64 { 0 }
    public func scanAll(alloc: Allocator, resolver: Resolver, ctx: Any): Unit {}
}

/// HTMLBundleRoute [KEPT: no-pkg]
public class HTMLBundleRoute {
    public init() {}
}

/// IntPtr [KEPT: no-pkg]
public class IntPtr {
    public init() {}
    public func deref(): Unit {}
}

/// HTMLRouter [KEPT: forward-ref - real type in parent package dev_server.cj]
public class HTMLRouter {
    public init() {}
    public static let empty: HTMLRouter = HTMLRouter()
    public func deinit(alloc: Allocator): Unit {}
}

/// StrongOptional [KEPT: deferred - imported from bao_jsc.StrongOptional]
public class StrongOptional {
    public static let empty: StrongOptional = StrongOptional()
    public init() {}
    public func deinit(): Unit {}
    public func clearWithoutDeallocation(): Unit {}
}

/// EntryPointList [KEPT: forward-ref - real type in parent package dev_server.cj]
public class EntryPointList {
    public static let empty: EntryPointList = EntryPointList()
    public init() {}
    public var set: HashSet<String> = HashSet<String>()
    public func deinit(alloc: Allocator): Unit {}
}

/// TestingBatchEvents [KEPT: forward-ref - real type in parent package dev_server.cj]
public enum TestingBatchEvents {
    | disabled
    | enable_after_bundle
    | enabled(TestingBatch)
}

/// TestingBatch [KEPT: forward-ref - real type in parent package dev_server.cj]
public class TestingBatch {
    public init() {}
    public var entry_points: EntryPointList = EntryPointList()
}

/// IndexOptional [KEPT: no-pkg]
public class IndexOptional {
    public static let none: IndexOptional = IndexOptional()
    public init() {}
    public func unwrap(): ?UInt32 { None }
    public func toOptional(): IndexOptional { this }
}

// ============================================================================
// 监控与观察类型
// ============================================================================

/// Watcher imported from bao_watcher.Watcher
/// ThreadLock imported from bao_safety.ThreadLock

// ============================================================================
// Bundler/编译器类型
// ============================================================================

/// Transpiler [KEPT: forward-ref - imported via parent package]
public class Transpiler {
    public init() {}
    public var resolver: Resolver = Resolver()
}

/// Resolver [KEPT: forward-ref - imported via parent package]
public class Resolver {
    public init() {}
    public func bustDirCache(dir: String): Unit {}
    public func resolve(dir: String, specifier: String, kind: ImportKind): ?String { None }
}

/// ImportKind [KEPT: forward-ref]
public enum ImportKind {
    | stmt
    | `import`
    | dynamic
}

/// Side [KEPT: forward-ref]
public enum Side {
    | client
    | server
    | ssr
}

/// Graph [KEPT: no-pkg]
public enum Graph {
    | client
    | server
    | ssr
}

/// FileKind [KEPT: no-pkg]
public enum FileKind {
    | unknown
    | js
    | css
    | asset
    | json
    | jsonc
    | toml
    | yaml
    | json5
    | wasm
    | napi
    | base64
    | dataurl
    | text
    | bunsh
    | sqlite
    | sqlite_embedded
    | md
    | tsx
    | ts
    | jsx
    | html
    | file
}

/// Loader type alias
public type Loader = FileKind

/// ChunkKind [KEPT: no-pkg]
public enum ChunkKind {
    | initial_response
    | hmr_chunk
}

/// Magic [KEPT: forward-ref]
public enum Magic {
    | valid
}

// ============================================================================
// 源映射与调试器
// ============================================================================

/// SourceMapMappingList [KEPT: no-pkg]
public class SourceMapMappingList {
    public init() {}
    public func find(line: UInt32, column: UInt32): ?RemappedPosition { None }
    public func deinit(alloc: Allocator): Unit {}
}

/// RemappedPosition [KEPT: no-pkg]
public class RemappedPosition {
    public init() {}
    public func originalLine(): UInt32 { 0 }
    public func originalColumn(): UInt32 { 0 }
    public var source_index: UInt32 = 0
}

/// InspectorAgent [KEPT: no-pkg]
public class InspectorAgent {
    public init() {}
    public func nextConnectionID(): Int32 { 0 }
    public func notifyClientConnected(id: Int64, connId: Int32): Unit {}
    public func notifyClientDisconnected(id: Int64, connId: Int32): Unit {}
    public func notifyClientNavigated(id: Int64, connId: Int32, pattern: String, rbi: ?UInt32): Unit {}
}

// ============================================================================
// Index 类型
// ============================================================================

/// FileIndex [KEPT: no-pkg]
public struct FileIndex {
    public var value: UInt32
    public init(value: UInt32) { this.value = value }
    public func get(): UInt32 { value }
}

/// EdgeIndex is defined in incremental_graph.cj

/// AstIndex [KEPT: no-pkg]
public struct AstIndex {
    public var value: UInt32
    public init(value: UInt32) { this.value = value }
    public func get(): UInt32 { value }
}

/// ByteOffset is defined in route_bundle.cj
/// WeakRefMode is defined in source_map_store.cj
/// ErrorKind is defined in serialized_failure.cj

// ============================================================================
// HTTP/MIME/路由类型
// ============================================================================

/// MimeType [KEPT: no-pkg]
public enum MimeType {
    | json
    | html
    | javascript
    | css
    | text
    | other
}

public class MimeTypeHelper {
    public static func getValue(mime: MimeType): String {
        match (mime) {
            case MimeType.json => "application/json"
            case MimeType.html => "text/html"
            case MimeType.javascript => "application/javascript"
            case MimeType.css => "text/css"
            case MimeType.text => "text/plain"
            case MimeType.other => "application/octet-stream"
        }
    }
}

/// StaticRoute [KEPT: forward-ref]
public class StaticRoute {
    public init() {}
    public static func initFromAnyBlob(blob: AnyBlob, status: Int32, mime: ?MimeType, extra: Any): StaticRoute { StaticRoute() }
    public func deref(): Unit {}
    public func memoryCost(): UInt64 { 0 }
    public static func sendBlobThenDeinit(resp: AnyResponse, blob: AnyBlob, opts: Any): Unit {}
}

/// AnyBlob [KEPT: no-pkg]
public class AnyBlob {
    public init() {}
    public func sharedView(): AnyBlob { this }
    public func detach(): Unit {}
    public func memoryCost(): UInt64 { 0 }
}

/// StaticRouteOptions [KEPT: no-pkg]
public class StaticRouteOptions {
    public var mime_type: MimeType
    public var server: ?AnyServer
    public init(mime_type: MimeType, server: ?AnyServer) {
        this.mime_type = mime_type
        this.server = server
    }
}

/// Blob [KEPT: no-pkg]
public class Blob {
    public init() {}
    public static func fromArrayList(list: ArrayList<Byte>): Blob { Blob() }
}

// ============================================================================
// 集合类型
// ============================================================================

/// ArrayList [KEPT: no-pkg - thin wrapper around bao_collections.ArrayList]
public class ArrayList<T> {
    public init() {}
    public static func initCapacity(alloc: Allocator, capacity: Int64): ArrayList<T> { ArrayList<T>() }
    public var items: Array<T> = []
    public func writer(): Writer { Writer() }
    public func append(item: T): Unit {}
    public func appendSlice(items: Array<T>): Unit {}
    public func appendSlice(items: String): Unit {}
    public func clear(): Unit {}
}

/// HashSet [KEPT: no-pkg - thin wrapper around bao_collections.HashSet]
public class HashSet<T> {
    public init() {}
    public func contains(item: T): Bool { false }
    public func append(item: T): Unit {}
    public func count(): Int64 { 0 }
    public func clear(): Unit {}
}

/// DynamicBitSetUnmanaged [KEPT: no-pkg]
public class DynamicBitSetUnmanaged {
    public var bit_length: UInt32 = 0
    public init() {}
    public static let empty: DynamicBitSetUnmanaged = DynamicBitSetUnmanaged()
    public func resize(alloc: Allocator, new_len: UInt32, fill: Bool): Unit {}
    public func bytes(): Array<Byte> { Array<Byte>() }
    public func deinit(alloc: Allocator): Unit {}
}

// ============================================================================
// 字符串与路径工具
// ============================================================================

/// StringsHelper
public class StringsHelper {
    public static func eqlComptime(a: String, b: String): Bool { a == b }
    public static func startsWith(s: String, prefix: String): Bool { s.startsWith(prefix) }
    public static func hasPrefixComptime(s: String, prefix: String): Bool { s.startsWith(prefix) }
    public static func hasSuffixComptime(s: String, suffix: String): Bool { s.endsWith(suffix) }
    public static func withoutTrailingSlash(s: String): String {
        if (s.endsWith("/")) { s[0..s.size - 1] } else { s }
    }
    public static func withoutTrailingSlashWindowsPath(s: String): String {
        if (s.endsWith("/") || s.endsWith("\\")) { s[0..s.size - 1] } else { s }
    }
    public static func percentEncodeWrite(input: String, output: ArrayList<Byte>): Unit {}
    public static func indexOfChar(s: String, ch: Int64): ?Int64 {
        var i: Int64 = 0
        while (i < s.size) {
            if (Int64(s[i]) == ch) { return i }
            i += 1
        }
        return None
    }
}

/// JsPrinter [KEPT: no-pkg]
public class JsPrinter {
    public static func writePreQuotedString(input: String, writer: Writer, quoteChar: Byte, a: Bool, b: Bool, encoding: Encoding): Unit {}
}

/// URL [KEPT: no-pkg]
public class URL {
    public static func originFromSlice(url: String): ?String { None }
}

/// PathHelper
public class PathHelper {
    public static func join(parts: Array<String>): String {
        var result = ""
        for (part in parts) {
            if (result.size > 0 && !result.endsWith("/")) { result += "/" }
            result += part
        }
        return result
    }
    public static func dirname(path: String): String {
        if (let Some(idx) <- path.lastIndexOf('/')) {
            if (idx <= 0) { return "/" }
            return path[0..idx]
        }
        return "/"
    }
}

// ============================================================================
// HMR 消息与主题类型
// ============================================================================

/// HmrTopic [KEPT: forward-ref]
public class HmrTopic {
    public static let Bits: Int64 = 0
    public static let max_count: Int64 = 64
}

/// ConsoleLogKind [KEPT: forward-ref]
public enum ConsoleLogKind {
    | log
    | err
}

/// MessageId [KEPT: forward-ref]
public enum MessageId {
    | version
    | set_url_response
    | testing_watch_synchronization
    public func char(): Byte { 0 }
}

/// IncomingMessageId [KEPT: forward-ref]
public enum IncomingMessageId {
    | `init`
    | subscribe
    | set_url
    | testing_batch_events
    | console_log
    | unref_source_map
}

/// BitsHelper
public class BitsHelper {
    public static func and(a: Int64, b: Int64, c: Int64): Int64 { a & b & c }
    public static func invert(a: Int64, b: Int64): Int64 { a & (!b) }
}

// ============================================================================
// 输出与日志
// ============================================================================

/// Output - 控制台输出工具
/// 对应 Bun: bun.Output
public class Output {
    public init() {}
    public static func pretty(msg: String): Unit { print(msg) }
    public static func prettyError(msg: String): Unit { print(msg) }
    public static func flush(): Unit {}
    public static func warn(msg: String): Unit { print("[warn] ${msg}\n") }
    public static func errGeneric(msg: String): Unit { print("[error] ${msg}\n") }
}

/// LoggerMsg - bundler 日志消息
/// 对应 Bun: bun.logger.Msg
public class LoggerMsg {
    public var kind: LoggerKind = LoggerKind.err
    public var data: LoggerData = LoggerData()
    public var notes: Array<LoggerData> = []
    public init() {}
    public init(kind: LoggerKind, data: LoggerData) {
        this.kind = kind
        this.data = data
    }
}

/// LoggerData - 日志消息数据
/// 对应 Bun: bun.logger.MsgData
public class LoggerData {
    public var text: String = ""
    public var location: ?LoggerLocation = None
    public init() {}
    public init(text: String) { this.text = text }
    public init(text: String, location: LoggerLocation) {
        this.text = text
        this.location = location
    }
}

/// LoggerLocation - 日志位置信息
/// 对应 Bun: bun.logger.Location
public class LoggerLocation {
    public var line: Int64 = 0
    public var column: UInt32 = 0
    public var size: UInt32 = 0
    public var line_text: ?String = None
    public var file: String = ""
    public var namespace: String = ""
    public init() {}
    public init(line: Int64, column: UInt32, file: String) {
        this.line = line
        this.column = column
        this.file = file
    }
}

/// LoggerKind [KEPT: no-pkg]
public enum LoggerKind {
    | err
    | warn
    | note
    | debug
    | verbose
}

// ============================================================================
// JS 类型
// ============================================================================

/// ZigStackFrame [KEPT: no-pkg]
public class ZigStackFrame {
    public var source_url: ZigString = ZigString()
    public var function_name: ZigString = ZigString()
    public var position: ZigStackFramePosition = ZigStackFramePosition()
    public var remapped: Bool = false
    public init() {}
}

/// ZigString [KEPT: no-pkg]
public class ZigString {
    public var value: ZigStringInner = ZigStringInner()
    public init() {}
    public init(s: String) {}
    public func slice(): String { "" }
}

/// ZigStringInner [KEPT: no-pkg]
public class ZigStringInner {
    public init() {}
    public func slice(): String { "" }
}

/// ZigStackFramePosition [KEPT: no-pkg]
public class ZigStackFramePosition {
    public var line: Line = Line(0)
    public var column: Column = Column(0)
    public var line_start_byte: UInt32 = 0
    public init() {}
}

/// Line [KEPT: no-pkg]
public struct Line {
    public var value: UInt32
    public init(value: UInt32) { this.value = value }
    public static func fromZeroBased(v: UInt32): Line { Line(v) }
    public func oneBased(): UInt32 { value + 1 }
}

/// Column [KEPT: no-pkg]
public struct Column {
    public var value: UInt32
    public init(value: UInt32) { this.value = value }
    public static func fromZeroBased(v: UInt32): Column { Column(v) }
    public func oneBased(): UInt32 { value + 1 }
}

/// ZigException [KEPT: no-pkg]
public class ZigException {
    public var name: String = ""
    public var message: String = ""
    public var stack: ZigStackTrace = ZigStackTrace()
    public var remapped: Bool = false
    public var browserUrl: String = ""
    public init() {}
}

/// ZigStackTrace [KEPT: no-pkg]
public class ZigStackTrace {
    public var frames_len: UInt32 = 0
    public init() {}
    public static func fromFrames(frames: Array<ZigStackFrame>): ZigStackTrace { ZigStackTrace() }
    public func frames(): Array<ZigStackFrame> { Array<ZigStackFrame>() }
}

/// SourceMapState [KEPT: no-pkg]
public class SourceMapState {
    public init(generated_line: UInt32, generated_column: UInt32, source_index: UInt32, original_line: UInt32, original_column: UInt32) {}
}

/// HmrRuntime [KEPT: no-pkg]
public class HmrRuntime {
    public var code: String = ""
    public var line_count: UInt32 = 0
    public init(code: String) { this.code = code }
}

/// Encoding [KEPT: no-pkg]
public enum Encoding {
    | utf8
}

// ============================================================================
// Graph/跟踪类型
// ============================================================================

/// GraphTraceState [KEPT: no-pkg]
public class GraphTraceState {
    public init() {}
    public func bits(side: Side): BitSet { BitSet() }
    public func deinit(alloc: Allocator): Unit {}
}

/// BitSet [KEPT: no-pkg]
public class BitSet {
    public init() {}
    public func isSet(index: UInt32): Bool { false }
    public func set(index: UInt32): Unit {}
    public func unset(index: UInt32): Unit {}
}

/// InsertResult [KEPT: no-pkg]
public class InsertResult {
    public init() {}
    public var key: String = ""
    public var index: UInt32 = 0
}

/// ChunkContent [KEPT: no-pkg]
public enum ChunkContent {
    | js(ChunkJsContent)
    | css(UInt64)
}

/// ChunkJsContent [KEPT: no-pkg]
public class ChunkJsContent {
    public var code: String = ""
    public var source_map: ?ChunkSourceMap = None
    public init() {}
}

/// ChunkSourceMap [KEPT: no-pkg]
public class ChunkSourceMap {
    public init() {}
}

// ============================================================================
// 类型别名
// ============================================================================

public type UInt31 = UInt32
public type UInt63 = UInt64
public type Array5<T> = Array<T>
public type Owned<T> = T
public type PathBuffer = Array<Byte>
public type SourceMapChunkRef = SourceMapChunk

// ============================================================================
// 常量
// ============================================================================

/// Invalid FD constant
public let invalid_fd: Int64 = -1

/// DevServer constants
public let CLIENT_PREFIX: String = "/_bun/client"
public let INTERNAL_PREFIX: String = "/_bun"

/// EventLoopTimerTag
public class EventLoopTimerTag {
    public static let DevServerSweepSourceMaps: Int64 = 0
}

/// PluginTarget - 插件加载目标
/// 对应 Bun: bake.PluginTarget
public class PluginTarget {
    public var dev: DevServer = DevServer()
    public init(dev: DevServer) { this.dev = dev }
    public init() {}
}

/// PluginState - 插件加载状态
/// 对应 Bun: bake.PluginState
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

/// JsValue [KEPT: forward-ref - imported from bao_jsc in parent package]
/// 此处保留是因为 dev_server 子包需要独立编译
public class JsValue {
    public init() {}
    public static func jsUndefined(): JsValue { JsValue() }
    public static func jsNumberFromInt32(v: Int32): JsValue { JsValue() }
    public static func createEmptyObject(global: Any, count: Int64): JsValue { JsValue() }
    public static func createEmptyArray(global: Any, count: Int64): JsValue { JsValue() }
    public static func jsTrue(): JsValue { JsValue() }
    public static func jsFalse(): JsValue { JsValue() }
    public static func null(): JsValue { JsValue() }
    public func isObject(): Bool { false }
    public func isUndefinedOrNull(): Bool { true }
    public func isCallable(): Bool { false }
    public func get(global: Any, `prop`: String): ?JsValue { None }
}

/// Strong [KEPT: no-pkg]
public class Strong {
    public var Optional: StrongOptional = StrongOptional.empty
    public init() {}
    public static func create(value: Any, global: JSGlobalObject): Strong { Strong() }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// Panic helper
public func panic(msg: String): Nothing {
    throw Exception(msg)
}

/// Unreachable helper
public func unreachable(): Nothing {
    throw Exception("unreachable")
}

/// Assert helper
public func assert(condition: Bool): Unit {
    if (!condition) {
        panic("assertion failed")
    }
}

/// Assert helper with message
public func assert(condition: Bool, message: String): Unit {
    if (!condition) {
        panic("assertion failed: " + message)
    }
}

/// sizeOf helper
public func sizeOf<T>(): UInt64 { 0 }

/// random helper [KEPT: no-pkg - uses system RNG when available]
public func random<T>(): T { throw Exception("unimplemented: random") }

/// bitCast helper [KEPT: no-pkg - needs unsafe reinterpret]
public func bitCast<T>(value: Any): T { throw Exception("unimplemented: bitCast") }

/// isAbsolutePath helper
public func isAbsolutePath(path: String): Bool { path.startsWith("/") }

/// timespec [KEPT: no-pkg]
public struct timespec {
    public var sec: Int64
    public var nsec: Int64
    public init(sec: Int64, nsec: Int64) { this.sec = sec; this.nsec = nsec }
}

/// TimeMode [KEPT: no-pkg]
public enum TimeMode {
    | allow_mocked_time
}

/// StackFallbackInit helper

/// FieldParentPtr helper [KEPT: no-pkg - needs unsafe pointer arithmetic]
public func fieldParentPtr<T>(ptr: Any): T { throw Exception("unimplemented: fieldParentPtr") }
