// 翻译自 Bun: src/runtime/bake/dev_server/mod.rs
// DevServer 子模块入口。

package bao_runtime.bake.dev_server

import bao_bun_alloc.Allocator
import bao_collections.*

// ============================================================================
// 共享类型别名和存根
// 仅包含未在其他专用文件中定义的类型
// ============================================================================

// ============================================================================
// 通信/WebSocket 类型
// ============================================================================

/// AnyWebSocket stub
public class AnyWebSocket {
    public init() {}
    public func send(data: Array<Byte>, opcode: Opcode, compress: Bool, fin: Bool): SendStatus { SendStatus.sent }
    public func close(): Unit {}
    public func getRemoteSocketInfo(): ?SocketInfo { None }
}

/// SocketInfo stub
public class SocketInfo {
    public var ip: String = ""
    public var is_ipv6: Bool = false
    public init() {}
}

/// Opcode stub
public enum Opcode {
    | text
    | binary
    | close
    | ping
    | pong
}

/// SendStatus stub
public enum SendStatus {
    | dropped
    | sent
}

// ============================================================================
// 基础设施工具
// ============================================================================

/// EventLoopTimer stub
public class EventLoopTimer {
    public init() {}
    public static func initPaused(tag: Int64): EventLoopTimer { EventLoopTimer() }
    public var state: TimerState
}

/// StringJoiner stub
public class StringJoiner {
    public init(allocator: Allocator) {}
    public func pushStatic(s: String): Unit {}
    public func done(alloc: Allocator): Array<Byte> { Array<Byte>() }
    public func doneWithEnd(suffix: String): Array<Byte> { Array<Byte>() }
}

/// GenericIndex stub
public struct GenericIndex<T, P> {
    public var value: UInt32
    public init(value: UInt32) { this.value = value }
    public static func create(value: UInt32): GenericIndex<T, P> { GenericIndex<T, P>(value: value) }
}

/// BodyReaderMixin stub
public class BodyReaderMixin<T> {
    public init(alloc: Allocator) {}
    public func readBody(resp: AnyResponse): Unit {}
}

/// AnyResponse stub
public class AnyResponse {
    public init() {}
    public func end(body: String, close: Bool): Unit {}
    public func writeStatus(status: String): Unit {}
    public func writeHeader(name: String, value: String): Unit {}
    public func corked(callback: (AnyResponse) -> Unit): Unit {}
}

/// Request stub
public class Request {
    public init() {}
    public func url(): String { "/" }
    public func method(): String { "GET" }
}

/// ConcurrentTask stub
public class ConcurrentTask {
    public init(task: Task) {}
    public init() {}
}

/// Task stub
public class Task {
    public init(ev: Any) {}
    public init() {}
}

/// Atomic stub
public struct Atomic<T> {
    public var value: T
    public init(value: T) { this.value = value }
    public func swap(new_value: T, ordering: AtomicOrdering): T { let old = value; value = new_value; return old }
    public func store(new_value: T, ordering: AtomicOrdering): Unit { value = new_value }
    public func cmpxchgWeak(expected: T, new_value: T, success_ordering: AtomicOrdering, failure_ordering: AtomicOrdering): ?T { None }
    public func load(ordering: AtomicOrdering): T { value }
}

/// AtomicOrdering stub
public enum AtomicOrdering {
    | monotonic
    | acqRel
    | release
    | acquire
    | seqCst
}

/// Mutex stub
public class Mutex {
    public init() {}
    public func lock(): Unit {}
    public func unlock(): Unit {}
    public func getOrThrow(): Mutex { this }
}

/// Timer stub
public class Timer {
    public init() {}
    public static func start(): Timer { Timer() }
}

/// TimerState stub
public enum TimerState {
    | ACTIVE
    | FIRED
    | CANCELLED
}

// ============================================================================
// IO 类型
// ============================================================================

/// FixedBufferStream stub
public class FixedBufferStream<T> {
    public init(data: T) {}
    public func reader(): Reader { Reader() }
}

/// Reader stub
public class Reader {
    public init() {}
    public func readInt<T>(): T { throw Exception("stub") }
    public func readByte(): Byte { 0 }
    public func readAll(): Array<Byte> { Array<Byte>() }
}

/// Writer stub
public class Writer {
    public init() {}
    public func writeInt<T>(value: T): Unit {}
    public func writeByte(value: Byte): Unit {}
    public func writeAll(data: String): Unit {}
}

/// StackFallback stub
public struct StackFallback<N> {
    public init(capacity: Int64, alloc: Allocator) {}
    public func get(): Allocator { Allocator() }
}

/// ArenaAllocator stub
public class ArenaAllocator {
    public init(alloc: Allocator) {}
    public func allocator(): Allocator { Allocator() }
    public func deinit(): Unit {}
}

/// DevAllocator stub
public class DevAllocator {
    public init() {}
    public func allocator(): Allocator { Allocator() }
}

// ============================================================================
// 核心服务器类型
// ============================================================================

/// DevServer stub (forward reference)
public class DevServer {
    public init() {}
    public func allocator(): Allocator { Allocator() }
    public func dev_allocator(): DevAllocator { DevAllocator() }
    public var vm: VirtualMachine
    public var server: ?AnyServer
    public var source_maps: SourceMapStore
    public var directory_watchers: DirectoryWatchStore
    public var client_graph: IncrementalGraph
    public var server_graph: IncrementalGraph
    public var watcher_atomics: WatcherAtomics
    public var assets: Assets
    public var active_websocket_connections: HashMap<HmrSocket, Unit>
    public var graph_safety_lock: ThreadLock
    public var configuration_hash_key: Array<Byte>
    public var bundling_failures: HashMap<SerializedFailure, Unit>
    public var route_bundles: Array<RouteBundle>
    public var current_bundle: ?CurrentBundle
    public var next_bundle: NextBundle
    public var testing_batch_events: TestingBatchEvents
    public var inspector_server_id: Int64
    public var broadcast_console_log_from_browser_to_server: Bool
    public var server_transpiler: Transpiler
    public var root: String
    public var magic: Magic
    public var bun_watcher: Watcher
    public func routeToBundleIndexSlow(pattern: String): ?UInt32 { None }
    public func routeBundlePtr(index: UInt32): RouteBundle { RouteBundle() }
    public func startAsyncBundle(entry_points: EntryPointList, had_reload_event: Bool, timer: Timer): Unit {}
    public func relativePath(buf: PathBuffer, abs_path: String): String { abs_path }
}

/// VirtualMachine stub
public class VirtualMachine {
    public init() {}
    public var event_loop: EventLoop
    public var global: JSGlobalObject
}

/// EventLoop stub
public class EventLoop {
    public init() {}
    public func enqueueTaskConcurrent(task: ConcurrentTask): Unit {}
}

/// JSGlobalObject stub
public class JSGlobalObject {
    public init() {}
}

/// AnyServer stub
public class AnyServer {
    public init() {}
}

/// CurrentBundle stub
public class CurrentBundle {
    public init() {}
    public var reload_event: ?HotReloadEvent
}

/// NextBundle stub
public class NextBundle {
    public init() {}
    public var reload_event: ?HotReloadEvent
}

// ============================================================================
// 路由与框架类型
// ============================================================================

/// FrameworkRouter stub
public class FrameworkRouter {
    public init() {}
    public func memoryCost(): UInt64 { 0 }
    public func scanAll(alloc: Allocator, resolver: Resolver, ctx: Any): Unit {}
}

/// HTMLBundleRoute stub
public class HTMLBundleRoute {
    public init() {}
}

/// IntPtr stub
public class IntPtr {
    public init() {}
    public func deref(): Unit {}
}

/// HTMLRouter stub
public class HTMLRouter {
    public init() {}
    public static let empty: HTMLRouter = HTMLRouter()
    public func deinit(alloc: Allocator): Unit {}
}

/// StrongOptional stub
public class StrongOptional {
    public static let empty: StrongOptional = StrongOptional()
    public init() {}
    public func deinit(): Unit {}
    public func clearWithoutDeallocation(): Unit {}
}

/// EntryPointList stub
public class EntryPointList {
    public static let empty: EntryPointList = EntryPointList()
    public init() {}
    public var set: HashSet<String>
    public func deinit(alloc: Allocator): Unit {}
}

/// TestingBatchEvents stub
public enum TestingBatchEvents {
    | disabled
    | enable_after_bundle
    | enabled(TestingBatch)
}

/// TestingBatch stub
public class TestingBatch {
    public init() {}
    public var entry_points: EntryPointList
}

/// IndexOptional stub
public class IndexOptional {
    public static let none: IndexOptional = IndexOptional()
    public init() {}
    public func unwrap(): ?UInt32 { None }
    public func toOptional(): IndexOptional { this }
}

// ============================================================================
// 监控与观察类型
// ============================================================================

/// Watcher stub
public class Watcher {
    public init() {}
    public func addDirectory(fd: Int64, dir: String, hash: UInt64, recursive: Bool): UInt16 { 0 }
    public func removeAtIndex(index: UInt16, extra: Int64, paths: Array<String>): Unit {}
    public func deinit(wait: Bool): Unit {}
    public static func getHash(s: String): UInt64 { 0 }
}

/// ThreadLock stub
public class ThreadLock {
    public init() {}
    public static func initUnlocked(): ThreadLock { ThreadLock() }
    public func lock(): Unit {}
    public func unlock(): Unit {}
    public func assertLocked(): Unit {}
}

// ============================================================================
// Bundler/编译器类型
// ============================================================================

/// Transpiler stub
public class Transpiler {
    public init() {}
    public var resolver: Resolver
}

/// Resolver stub
public class Resolver {
    public init() {}
    public func bustDirCache(dir: String): Unit {}
    public func resolve(dir: String, specifier: String, kind: ImportKind): ?String { None }
}

/// ImportKind stub
public enum ImportKind {
    | stmt
    | `import`
    | dynamic
}

/// Side stub
public enum Side {
    | client
    | server
    | ssr
}

/// Graph stub
public enum Graph {
    | client
    | server
    | ssr
}

/// FileKind stub
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

/// ChunkKind stub
public enum ChunkKind {
    | initial_response
    | hmr_chunk
}

/// Magic stub
public enum Magic {
    | valid
}

// ============================================================================
// 源映射与调试器
// ============================================================================

/// SourceMapMappingList stub
public class SourceMapMappingList {
    public init() {}
    public func find(line: UInt32, column: UInt32): ?RemappedPosition { None }
    public func deinit(alloc: Allocator): Unit {}
}

/// RemappedPosition stub
public class RemappedPosition {
    public init() {}
    public func originalLine(): UInt32 { 0 }
    public func originalColumn(): UInt32 { 0 }
    public var source_index: UInt32
}

/// InspectorAgent stub
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

/// FileIndex stub
public struct FileIndex {
    public var value: UInt32
    public init(value: UInt32) { this.value = value }
    public func get(): UInt32 { value }
}

/// EdgeIndex is defined in incremental_graph.cj

/// AstIndex stub
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

/// MimeType stub
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

/// StaticRoute stub
public class StaticRoute {
    public init() {}
    public static func initFromAnyBlob(blob: AnyBlob, status: Int32, mime: ?MimeType, extra: Any): StaticRoute { StaticRoute() }
    public func deref(): Unit {}
    public func memoryCost(): UInt64 { 0 }
    public static func sendBlobThenDeinit(resp: AnyResponse, blob: AnyBlob, opts: Any): Unit {}
}

/// AnyBlob stub
public class AnyBlob {
    public init() {}
    public func sharedView(): AnyBlob { this }
    public func detach(): Unit {}
    public func memoryCost(): UInt64 { 0 }
}

/// StaticRouteOptions stub
public class StaticRouteOptions {
    public var mime_type: MimeType
    public var server: ?AnyServer
    public init(mime_type: MimeType, server: ?AnyServer) {
        this.mime_type = mime_type
        this.server = server
    }
}

/// Blob stub
public class Blob {
    public init() {}
    public static func fromArrayList(list: ArrayList<Byte>): Blob { Blob() }
}

// ============================================================================
// 集合类型
// ============================================================================

/// ArrayList stub
public class ArrayList<T> {
    public init() {}
    public static func initCapacity(alloc: Allocator, capacity: Int64): ArrayList<T> { ArrayList<T>() }
    public var items: Array<T>
    public func writer(): Writer { Writer() }
    public func append(item: T): Unit {}
    public func appendSlice(items: Array<T>): Unit {}
    public func appendSlice(items: String): Unit {}
    public func clear(): Unit {}
}

/// HashSet stub
public class HashSet<T> {
    public init() {}
    public func contains(item: T): Bool { false }
    public func append(item: T): Unit {}
    public func count(): Int64 { 0 }
    public func clear(): Unit {}
}

/// DynamicBitSetUnmanaged stub
public class DynamicBitSetUnmanaged {
    public init() {}
    public static let empty: DynamicBitSetUnmanaged = DynamicBitSetUnmanaged()
    public var bit_length: UInt32
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

/// JsPrinter stub
public class JsPrinter {
    public static func writePreQuotedString(input: String, writer: Writer, quoteChar: Byte, a: Bool, b: Bool, encoding: Encoding): Unit {}
}

/// URL stub
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
        let idx = path.lastIndexOf('/')
        if (idx <= 0) { return "/" }
        return path[0..idx]
    }
}

// ============================================================================
// HMR 消息与主题类型
// ============================================================================

/// HmrTopic stub
public class HmrTopic {
    public static let Bits: Int64 = 0
    public static let max_count: Int64 = 64
}

/// ConsoleLogKind stub
public enum ConsoleLogKind {
    | log
    | err
}

/// MessageId stub
public enum MessageId {
    | version
    | set_url_response
    | testing_watch_synchronization
    public func char(): Byte { 0 }
}

/// IncomingMessageId stub
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
    public static func invert(a: Int64, b: Int64): Int64 { a & b.bitwiseNot() }
}

// ============================================================================
// 输出与日志
// ============================================================================

/// Output stub
public class Output {
    public init() {}
    public static func pretty(msg: String): Unit {}
    public static func prettyError(msg: String): Unit {}
    public static func flush(): Unit {}
}

/// LoggerMsg stub
public class LoggerMsg {
    public init() {}
    public var kind: LoggerKind
    public var data: LoggerData
    public var notes: Array<LoggerData>
}

/// LoggerData stub
public class LoggerData {
    public init() {}
    public var text: String
    public var location: ?LoggerLocation
}

/// LoggerLocation stub
public class LoggerLocation {
    public init() {}
    public var line: Int64
    public var column: UInt32
    public var size: UInt32
    public var line_text: ?String
}

/// LoggerKind stub
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

/// ZigStackFrame stub
public class ZigStackFrame {
    public init() {}
    public var source_url: ZigString
    public var function_name: ZigString
    public var position: ZigStackFramePosition
    public var remapped: Bool
}

/// ZigString stub
public class ZigString {
    public init() {}
    public init(s: String) {}
    public func slice(): String { "" }
    public var value: ZigStringInner
}

/// ZigStringInner stub
public class ZigStringInner {
    public init() {}
    public func slice(): String { "" }
}

/// ZigStackFramePosition stub
public class ZigStackFramePosition {
    public init() {}
    public var line: Line
    public var column: Column
    public var line_start_byte: UInt32
}

/// Line stub
public struct Line {
    public var value: UInt32
    public init(value: UInt32) { this.value = value }
    public static func fromZeroBased(v: UInt32): Line { Line(value: v) }
    public func oneBased(): UInt32 { value + 1 }
}

/// Column stub
public struct Column {
    public var value: UInt32
    public init(value: UInt32) { this.value = value }
    public static func fromZeroBased(v: UInt32): Column { Column(value: v) }
    public func oneBased(): UInt32 { value + 1 }
}

/// ZigException stub
public class ZigException {
    public init() {}
    public var name: String
    public var message: String
    public var stack: ZigStackTrace
    public var remapped: Bool
    public var browserUrl: String
}

/// ZigStackTrace stub
public class ZigStackTrace {
    public init() {}
    public static func fromFrames(frames: Array<ZigStackFrame>): ZigStackTrace { ZigStackTrace() }
    public var frames_len: UInt32
    public func frames(): Array<ZigStackFrame> { Array<ZigStackFrame>() }
}

/// SourceMapState stub
public class SourceMapState {
    public init(generated_line: UInt32, generated_column: UInt32, source_index: UInt32, original_line: UInt32, original_column: UInt32) {}
}

/// HmrRuntime stub
public class HmrRuntime {
    public init(code: String) {}
    public var code: String
    public var line_count: UInt32
}

/// Encoding stub
public enum Encoding {
    | utf8
}

// ============================================================================
// Graph/跟踪类型
// ============================================================================

/// GraphTraceState stub
public class GraphTraceState {
    public init() {}
    public func bits(side: Side): BitSet { BitSet() }
    public func deinit(alloc: Allocator): Unit {}
}

/// BitSet stub
public class BitSet {
    public init() {}
    public func isSet(index: UInt32): Bool { false }
    public func set(index: UInt32): Unit {}
    public func unset(index: UInt32): Unit {}
}

/// InsertResult stub
public class InsertResult {
    public init() {}
    public var key: String = ""
    public var index: UInt32 = 0
}

/// ChunkContent stub
public enum ChunkContent {
    | js(ChunkJsContent)
    | css(UInt64)
}

/// ChunkJsContent stub
public class ChunkJsContent {
    public init() {}
    public var code: String
    public var source_map: ?ChunkSourceMap
}

/// ChunkSourceMap stub
public class ChunkSourceMap {
    public init() {}
}

// ============================================================================
// 类型别名
// ============================================================================

public type UInt30 = UInt32
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

/// Strong stub
public class Strong {
    public init() {}
    public var Optional: StrongOptional
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

/// random helper
public func random<T>(): T { throw Exception("stub") }

/// bitCast helper
public func bitCast<T>(value: Any): T { throw Exception("stub") }

/// isAbsolutePath helper
public func isAbsolutePath(path: String): Bool { path.startsWith("/") }

/// timespec stub
public struct timespec {
    public var sec: Int64
    public var nsec: Int64
    public init(sec: Int64, nsec: Int64) { this.sec = sec; this.nsec = nsec }
}

/// TimeMode stub
public enum TimeMode {
    | allow_mocked_time
}

/// StackFallbackInit helper
public func StackFallback<N>(capacity: Int64, alloc: Allocator): StackFallback<N> { StackFallback<N>() }

/// FieldParentPtr helper
public func fieldParentPtr<T>(ptr: Any): T { throw Exception("stub") }
