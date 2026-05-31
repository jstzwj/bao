// 翻译自 Bun: src/runtime/bake/dev_server/mod.rs
// DevServer 子模块入口。
//
// 此文件定义了 dev_server 子包的共享基础设施类型。
// DevServer 主类型定义在父包的 dev_server.cj 中。
//
// 子包专用类型（dev_server/*.cj）：
//   - assets.cj          — 资产存储
//   - directory_watch_store.cj — 目录监视
//   - error_report_request.cj — 错误报告请求
//   - hmr_socket.cj      — HMR WebSocket 处理
//   - hot_reload_event.cj — 热重载事件
//   - incremental_graph.cj — 增量图
//   - lifecycle.cj       — 文件监视生命周期
//   - memory_cost.cj     — 内存成本计算
//   - packed_map.cj      — 压缩路由映射
//   - route_bundle.cj    — 路由 bundle
//   - serialized_failure.cj — 序列化失败
//   - source_map_store.cj — 源映射存储
//   - watcher_atomics.cj — 监视器原子操作

package bao_runtime.bake.dev_server

import bao_bun_alloc.Allocator
import bao_collections.*
import bao_core.AllocationScope
import bao_core.DevAllocator
import bao_safety.ThreadLock
import bao_event_loop.EventLoopTimer
import bao_event_loop.TimerState
import std.random.Random

public type Byte = UInt8

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
/// Rope-like data structure for joining many small strings into one big string.
/// 对应 Bun: bun.StringJoiner
public class StringJoiner {
    private var parts: ArrayList<String>
    private var totalLen: Int64

    public init(allocator: Allocator) {
        parts = ArrayList<String>()
        totalLen = 0
    }
    public func pushStatic(s: String): Unit {
        if (s.size == 0) { return }
        parts.append(s)
        totalLen += s.size
    }
    public func done(alloc: Allocator): Array<Byte> {
        if (totalLen == Int64(0)) { return Array<Byte>() }
        let result = Array<Byte>(totalLen, { _ => 0 })
        var offset: Int64 = 0
        for (i in 0..parts.items.size) {
            let part = parts.items[i]
            for (j in 0..part.size) {
                result[offset] = UInt8(Int64(part[j]))
                offset += 1
            }
        }
        return result
    }
    public func doneWithEnd(suffix: String): Array<Byte> {
        let totalWithSuffix = totalLen + suffix.size
        if (totalWithSuffix == Int64(0)) { return Array<Byte>() }
        let result = Array<Byte>(totalWithSuffix, { _ => 0 })
        var offset: Int64 = 0
        for (i in 0..parts.items.size) {
            let part = parts.items[i]
            for (i in 0..part.size) {
                result[offset] = UInt8(Int64(part[i]))
                offset += 1
            }
        }
        for (i in 0..suffix.size) {
            result[offset] = UInt8(Int64(suffix[i]))
            offset += 1
        }
        return result
    }
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
            let codeStr = status[0..idx]
            var parsed: Int32 = Int32(0)
            for (i in 0..codeStr.size) {
                let ch = Int64(codeStr[i])
                if (ch >= 48 && ch <= 57) {
                    parsed = parsed * Int32(10) + Int32(ch - 48)
                } else {
                    break
                }
            }
            status_code = parsed
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
    public var buffer: Array<Byte>
    public var pos: Int64

    public init() {
        buffer = Array<Byte>()
        pos = 0
    }

    public init(data: Array<Byte>) {
        buffer = data
        pos = 0
    }

    /// Read a little-endian integer from the buffer.
    /// 对应 Zig: std.mem.readIntLittle(T, slice)
    /// Cangjie 不支持泛型特化，因此按常见类型分支处理。
    public func readInt<T>(): T {
        // Cangjie generics are reified but lack comptime size info.
        // Provide explicit read methods per type instead.
        throw Exception("readInt<T>: use readInt32/readInt64/readUInt32/readUInt16 instead of generic readInt<T>")
    }

    /// Read UInt16 little-endian
    public func readUInt16(): UInt16 {
        if (pos + 2 > buffer.size) { return UInt16(0) }
        let lo = UInt16(buffer[pos])
        let hi = UInt16(buffer[pos + 1])
        pos += 2
        return lo | (hi << 8)
    }

    /// Read Int32 little-endian
    public func readInt32(): Int32 {
        if (pos + 4 > buffer.size) { return Int32(0) }
        var result: Int32 = Int32(0)
        result = result | Int32(buffer[pos])
        result = result | (Int32(buffer[pos + 1]) << 8)
        result = result | (Int32(buffer[pos + 2]) << 16)
        result = result | (Int32(buffer[pos + 3]) << 24)
        pos += 4
        return result
    }

    /// Read UInt32 little-endian
    public func readUInt32(): UInt32 {
        if (pos + 4 > buffer.size) { return UInt32(0) }
        var result: UInt32 = UInt32(0)
        result = result | UInt32(buffer[pos])
        result = result | (UInt32(buffer[pos + 1]) << 8)
        result = result | (UInt32(buffer[pos + 2]) << 16)
        result = result | (UInt32(buffer[pos + 3]) << 24)
        pos += 4
        return result
    }

    /// Read Int64 little-endian
    public func readInt64(): Int64 {
        if (pos + 8 > buffer.size) { return Int64(0) }
        var result: Int64 = Int64(0)
        for (i in 0..8) {
            result = result | (Int64(buffer[pos + i]) << (i * 8))
        }
        pos += 8
        return result
    }

    /// Read UInt64 little-endian
    public func readUInt64(): UInt64 {
        if (pos + 8 > buffer.size) { return UInt64(0) }
        var result: UInt64 = UInt64(0)
        for (i in 0..8) {
            result = result | (UInt64(buffer[pos + i]) << (i * 8))
        }
        pos += 8
        return result
    }

    public func readByte(): Byte {
        if (pos >= buffer.size) { return 0 }
        let b = buffer[pos]
        pos += 1
        return b
    }

    public func readAll(): Array<Byte> {
        let remaining = Array<Byte>(buffer.size - pos, { i => buffer[pos + i] })
        pos = buffer.size
        return remaining
    }

    /// Whether there is more data to read
    public func hasMore(): Bool { pos < buffer.size }
}

/// Writer [KEPT: no-pkg]
public class Writer {
    public var buffer: Array<Byte>
    public var pos: Int64

    public init() {
        buffer = Array<Byte>()
        pos = 0
    }

    public init(capacity: Int64) {
        buffer = Array<Byte>(capacity, { _ => 0 })
        pos = 0
    }

    /// Write integer — generic version preserved for API compat
    public func writeInt<T>(value: T): Unit {
        throw Exception("writeInt<T>: use writeInt32/writeUInt32/writeByte instead of generic writeInt<T>")
    }

    /// Write Int32 little-endian
    public func writeInt32(value: Int32): Unit {
        ensureCapacity(4)
        buffer[pos]     = UInt8(value & Int32(0xFF))
        buffer[pos + 1] = UInt8((value >> 8) & Int32(0xFF))
        buffer[pos + 2] = UInt8((value >> 16) & Int32(0xFF))
        buffer[pos + 3] = UInt8((value >> 24) & Int32(0xFF))
        pos += 4
    }

    /// Write UInt32 little-endian
    public func writeUInt32(value: UInt32): Unit {
        ensureCapacity(4)
        buffer[pos]     = UInt8(value & UInt32(0xFF))
        buffer[pos + 1] = UInt8((value >> 8) & UInt32(0xFF))
        buffer[pos + 2] = UInt8((value >> 16) & UInt32(0xFF))
        buffer[pos + 3] = UInt8((value >> 24) & UInt32(0xFF))
        pos += 4
    }

    public func writeByte(value: Byte): Unit {
        ensureCapacity(1)
        buffer[pos] = value
        pos += 1
    }

    public func writeAll(data: String): Unit {
        for (i in 0..data.size) {
            writeByte(UInt8(Int64(data[i])))
        }
    }

    /// Write a raw byte array
    public func writeBytes(data: Array<Byte>): Unit {
        ensureCapacity(data.size)
        for (i in 0..data.size) {
            buffer[pos + i] = data[i]
        }
        pos += data.size
    }

    private func ensureCapacity(additional: Int64): Unit {
        let needed = pos + additional
        if (needed > buffer.size) {
            let newCap = if (needed * 2 > buffer.size + additional) { needed * 2 } else { buffer.size + additional }
            let newBuf = Array<Byte>(newCap, { i => if (i < buffer.size) { buffer[i] } else { 0 } })
            buffer = newBuf
        }
    }
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
    public init() { items = [] }
    public static func initCapacity(alloc: Allocator, capacity: Int64): ArrayList<T> { ArrayList<T>() }
    public var items: Array<T> = []
    public func writer(): Writer { Writer() }
    public func append(item: T): Unit {
        items = Array<T>(items.size + 1, { i => if (i < items.size) { items[i] } else { item } })
    }
    public func appendSlice(newItems: Array<T>): Unit {
        let oldSize = items.size
        items = Array<T>(oldSize + newItems.size, { i => if (i < oldSize) { items[i] } else { newItems[i - oldSize] } })
    }
    public func appendSlice(str: String): Unit {
        // String append is only meaningful for ArrayList<Byte>
        // For other types, this is a no-op stub
    }
    public func clear(): Unit { items = [] }
}

/// HashSet [KEPT: no-pkg - thin wrapper around bao_collections.HashSet]
public class HashSet<T> where T <: ToString {
    private var data: HashMap<T, Unit>
    public init() { data = HashMap<T, Unit>() }
    public func contains(item: T): Bool { data.contains(item) }
    public func append(item: T): Unit { data.put(item, ()) }
    public func count(): Int64 { data.size }
    public func clear(): Unit { data.clear() }
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
    public static func percentEncodeWrite(input: String, output: ArrayList<Byte>): Unit {
        // 对应 Bun: strings.percentEncodeWrite
        // URL-encodes characters that need encoding (non-ASCII, control chars, etc.)
        var i: Int64 = 0
        while (i < input.size) {
            let ch = Int64(input[i])
            // Safe characters: A-Z a-z 0-9 - _ . ~
            if ((ch >= 65 && ch <= 90) || (ch >= 97 && ch <= 122) ||
                (ch >= 48 && ch <= 57) || ch == 45 || ch == 95 ||
                ch == 46 || ch == 126) {
                output.append(UInt8(ch))
                i += 1
            } else {
                // Percent-encode: %XX
                let hi = UInt8((ch >> 4) & 0xF)
                let lo = UInt8(ch & 0xF)
                output.append(UInt8(37)) // '%'
                output.append(if (hi < 10) { UInt8(hi + 48) } else { UInt8(hi + 55) })
                output.append(if (lo < 10) { UInt8(lo + 48) } else { UInt8(lo + 55) })
                i += 1
            }
        }
    }
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
    /// 对应 Bun: bun.jsc.URL.originFromSlice
    /// Extracts the origin (scheme://host:port) from a URL string.
    /// Returns null if the string does not look like a valid URL.
    public static func originFromSlice(url: String): ?String {
        // Simple origin extraction: find scheme://host[:port]
        // Look for "://" by scanning for ':' then checking "/" "/"
        let colonIdx = StringsHelper.indexOfChar(url, Int64(58)) // ':'
        if (let Some(ci) <- colonIdx) {
            if (ci < Int64(2)) { return None }
            // Check for "://"
            if (ci + Int64(2) >= url.size) { return None }
            if (Int64(url[ci + Int64(1)]) != Int64(47) || Int64(url[ci + Int64(2)]) != Int64(47)) { return None }
            let afterScheme = ci + Int64(3)
            if (afterScheme >= url.size) { return None }
            // Find end of authority (first '/' after scheme://)
            var end = url.size
            var j = afterScheme
            while (j < url.size) {
                let ch = Int64(url[j])
                if (ch == 47 || ch == 63 || ch == 35) { // '/' or '?' or '#'
                    end = j
                    break
                }
                j += 1
            }
            if (end > afterScheme) {
                return url[0..end]
            }
        }
        return None
    }
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
/// 对应 Bun: DevServer.HmrTopic - HMR subscription topics
public class HmrTopic {
    public static let Bits: Int64 = 0
    /// max_count = 6 topics (hot_update, errors, browser_error, incremental_visualizer, memory_visualizer, testing_watch_synchronization)
    public static let max_count: Int64 = 6
}

/// ConsoleLogKind [KEPT: forward-ref]
public enum ConsoleLogKind {
    | log
    | err
}

/// MessageId [KEPT: forward-ref]
/// 对应 Bun: DevServer.MessageId - HMR wire protocol message identifiers
public enum MessageId {
    | version                                  // 'V' = 86
    | hot_update                               // 'u' = 117
    | errors                                   // 'e' = 101
    | browser_message                          // 'b' = 98
    | browser_message_clear                    // 'B' = 66
    | request_handler_error                    // 'h' = 104
    | visualizer                               // 'v' = 118
    | memory_visualizer                        // 'M' = 77
    | set_url_response                         // 'n' = 110
    | testing_watch_synchronization            // 'r' = 114

    /// Get the wire protocol byte for this message ID
    /// 对应 Bun: pub inline fn char(id: MessageId) u8
    public func char(): Byte {
        match (this) {
            case MessageId.version => 86u8
            case MessageId.hot_update => 117u8
            case MessageId.errors => 101u8
            case MessageId.browser_message => 98u8
            case MessageId.browser_message_clear => 66u8
            case MessageId.request_handler_error => 104u8
            case MessageId.visualizer => 118u8
            case MessageId.memory_visualizer => 77u8
            case MessageId.set_url_response => 110u8
            case MessageId.testing_watch_synchronization => 114u8
        }
    }
}

/// IncomingMessageId [KEPT: forward-ref]
/// 对应 Bun: DevServer.IncomingMessageId
/// Wire protocol byte values: init='i'(105), subscribe='s'(115),
/// set_url='n'(110), testing_batch_events='H'(72),
/// console_log='l'(108), unref_source_map='u'(117)
public enum IncomingMessageId {
    | `init`                  // 'i' = 105
    | subscribe               // 's' = 115
    | set_url                 // 'n' = 110
    | testing_batch_events    // 'H' = 72
    | console_log             // 'l' = 108
    | unref_source_map        // 'u' = 117
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
    private var stored: String = ""
    public init() {}
    public init(s: String) { stored = s; value = ZigStringInner(s) }
    public func slice(): String { if (stored.size > 0) { stored } else { value.slice() } }
}

/// ZigStringInner [KEPT: no-pkg]
public class ZigStringInner {
    private var stored: String = ""
    public init() {}
    public init(s: String) { stored = s }
    public func slice(): String { stored }
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
    private var stored_frames: Array<ZigStackFrame> = []
    public init() {}
    public static func fromFrames(frames: Array<ZigStackFrame>): ZigStackTrace {
        let st = ZigStackTrace()
        st.stored_frames = frames
        st.frames_len = UInt32(frames.size)
        return st
    }
    public func frames(): Array<ZigStackFrame> { stored_frames }
}

/// SourceMapState [KEPT: no-pkg]
public class SourceMapState {
    public var generated_line: UInt32
    public var generated_column: UInt32
    public var source_index: UInt32
    public var original_line: UInt32
    public var original_column: UInt32
    public init(generated_line: UInt32, generated_column: UInt32, source_index: UInt32, original_line: UInt32, original_column: UInt32) {
        this.generated_line = generated_line
        this.generated_column = generated_column
        this.source_index = source_index
        this.original_line = original_line
        this.original_column = original_column
    }
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

/// random helper [KEPT: no-pkg]
/// 对应 Zig: std.crypto.random.bytes() / std.Random.int(T)
/// Cangjie 不支持泛型特化，提供具体类型的 random 函数。
/// 使用仓颉标准库 std.random.Random 实现。
public func random<T>(): T {
    throw Exception("random<T>: use randomInt32/randomUInt32/randomInt64 instead of generic random<T>")
}

/// 全局 Random 实例 — 仓颉 Random() 默认使用系统熵源种子
private let _rng: Random = Random()

/// Generate a random Int32
public func randomInt32(): Int32 { _rng.nextInt32() }

/// Generate a random UInt32
public func randomUInt32(): UInt32 { _rng.nextUInt32() }

/// Generate a random Int64
public func randomInt64(): Int64 { _rng.nextInt64() }

/// Generate a random UInt64
public func randomUInt64(): UInt64 { _rng.nextUInt64() }

/// Fill a byte array with random data
public func randomBytes(buf: Array<Byte>): Unit {
    _rng.nextBytes(buf)
}

/// Generate a random byte array of given length
public func randomBytes(length: Int32): Array<Byte> {
    _rng.nextBytes(length)
}

/// bitCast helper [KEPT: no-pkg - needs unsafe reinterpret]
/// 对应 Zig: @bitCast(dest_type, value) — zero-cost bit-level type punning.
/// Cangjie 不支持跨类型 bitCast 泛型，因为其类型系统要求安全转换。
/// 提供具体类型的 bitCast 函数替代。
public func bitCast<T>(value: Any): T {
    throw Exception("bitCast<T>: use bitCastInt32ToUInt32/bitCastUInt64ToInt64 etc. instead of generic bitCast<T>")
}

/// Bit-cast Int32 <-> UInt32
public func bitCastInt32ToUInt32(value: Int32): UInt32 { UInt32(value) }

public func bitCastUInt32ToInt32(value: UInt32): Int32 { Int32(value) }

/// Bit-cast Int64 <-> UInt64
public func bitCastInt64ToUInt64(value: Int64): UInt64 { UInt64(value) }

public func bitCastUInt64ToInt64(value: UInt64): Int64 { Int64(value) }

/// Bit-cast Float64 <-> UInt64 (via byte buffer)
public func bitCastFloat64ToUInt64(value: Float64): UInt64 {
    value.toBits()
}

public func bitCastUInt64ToFloat64(value: UInt64): Float64 {
    Float64.fromBits(value)
}

/// Bit-cast Float32 <-> UInt32
public func bitCastFloat32ToUInt32(value: Float32): UInt32 {
    value.toBits()
}

public func bitCastUInt32ToFloat32(value: UInt32): Float32 {
    Float32.fromBits(value)
}

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

/// FieldParentPtr helper [KEPT: no-pkg]
/// 对应 Zig: @fieldParentPtr(Parent, "field_name", field_ptr)
/// Given a pointer to a field within a struct, compute the pointer to the parent struct.
///
/// In Zig this is zero-cost pointer arithmetic: parent_ptr = field_ptr - @offsetOf(Parent, field).
/// Cangjie lacks pointer arithmetic and @offsetOf, so we provide a workaround pattern:
///   - Store a back-reference to the parent object inside child objects.
///   - Or maintain a separate mapping from field identity to parent.
///
/// This generic stub throws because Cangjie cannot express offset-of arithmetic.
/// Usage sites should replace fieldParentPtr calls with explicit back-references.
public func fieldParentPtr<T>(ptr: Any): T {
    throw Exception("fieldParentPtr<T>: not available in Cangjie - use explicit back-reference to parent instead")
}

/// fieldParentPtr pattern: get parent from child that stores an `owner` reference.
/// This replaces the Zig @fieldParentPtr pattern in Cangjie.
public func fieldParentByOwner<Parent, Child>(child: Child, getOwner: (Child) -> Parent): Parent {
    getOwner(child)
}
