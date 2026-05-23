// Stub types for bao_runtime.bake
// These types are defined in other packages or sub-packages that are not yet imported.
// They provide minimal interfaces needed by the bake package to compile.

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
import bao_options.LoaderMap
import bao_options.DotEnvBehavior
import bao_options.SourceMapMode
import bao_path.*
import bao_watcher.Watcher
import bao_runtime.bake.dev_server.SerializedFailure
import bao_runtime.bake.dev_server.HmrSocket

// ============================================================================
// Types that are NOT defined anywhere else in bao_runtime.bake
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
            case _ => None
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
            case _ => None
        }
    }
}

/// UWS request stub
public class UwsRequest {
    public init() {}
    public func parameter(index: Int64): String { "" }
    public func parameter(name: String): String { "" }
    public func method(): Int64 { 0 }
    public func url(): String { "/" }
    public func setYield(value: Bool): Unit {}
    public func fullPath(): String { "/" }
}

/// Any HTTP response stub
public class AnyResponse {
    public init() {}
    public func end(body: String, close: Bool): Unit {}
    public func writeStatus(status: String): Unit {}
    public func writeHeader(name: String, value: String): Unit {}
    public func corked(callback: (AnyResponse) -> Unit): Unit {}
    public func corked(callback: (AnyResponse) -> Unit, extra: AnyResponse): Unit {}
}

/// Saved request stub
public class SavedRequest {
    public var request: UwsRequest
    public var method: HTTPMethod
    public init() {
        request = UwsRequest()
        method = HTTPMethod.GET
    }
    public func url(): String { request.url() }
}

/// Any request context stub
public class AnyRequestContext {}

/// JS bundler plugin stub
public class JSBundlerPlugin {
    public init() {}
}

/// Request handler type
public type RequestHandler = Any

/// Debugger ID type
public type DebuggerId = Int64

/// Dir type stub
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

/// Promise type stub
public class Promise<T> {
    public init() {}
}

/// Thread lock stub
public class ThreadLock {
    public init() {}
    public static func initUnlocked(): ThreadLock { ThreadLock() }
    public func lock(): Unit {}
    public func unlock(): Unit {}
}

/// Incremental graph stub
public class IncrementalGraph {
    public static let empty: IncrementalGraph = IncrementalGraph()
    public init() {}
    public func deinit(): Unit {}
    public func ensureStaleBitCapacity(server: Bool): Unit {}
}

/// String hash map stub
public class StringHashMap<V> {
    public init() {}
    public func deinit(alloc: Allocator): Unit {}
}

/// Directory watch store stub
public class DirectoryWatchStore {
    public static let empty: DirectoryWatchStore = DirectoryWatchStore()
    public var watches: AutoArrayHashMapUnmanaged<String, Unit>
    public var dependencies: ArrayListUnmanaged<WatchDependency>
    public init() {
        watches = AutoArrayHashMapUnmanaged<String, Unit>()
        dependencies = ArrayListUnmanaged<WatchDependency>()
    }
}

public class WatchDependency {
    public var specifier: String = ""
    public init() {}
}

/// Watcher atomics stub
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

/// HTML bundle route stub
public class HTMLBundleRoute {
    public init() {}
}

/// Assets store stub
public class Assets {
    public init() {}
    public func get(hash: UInt64): ?Asset { None }
    public func deinit(alloc: Allocator): Unit {}
}

public class Asset {
    public func on(resp: AnyResponse): Unit {}
}

/// Source map store stub
public class SourceMapStore {
    public static let empty: SourceMapStore = SourceMapStore()
    public var entries: AutoArrayHashMapUnmanaged<UInt64, SourceMapEntry>
    public init() {
        entries = AutoArrayHashMapUnmanaged<UInt64, SourceMapEntry>()
    }
    public func unref(key: UInt64): Unit {}
    public func removeOrUpgradeWeakRef(key: UInt64, mode: WeakRefMode): Bool { false }
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

/// Array hash map unmanaged stub
public class ArrayHashMapUnmanaged<K, V> {
    public init() {}
    public func keys(): Array<K> { Array<K>() }
    public func deinit(alloc: Allocator): Unit {}
    public func count(): Int64 { 0 }
}

/// Auto hash map unmanaged stub
public class AutoHashMapUnmanaged<K, V> {
    public init() {}
    public func deinit(alloc: Allocator): Unit {}
    public func keyIterator(): KeyIterator<K> { KeyIterator<K>() }
    public func count(): Int64 { 0 }
    public func put(alloc: Allocator, key: K, value: V): Unit {}
    public func remove(key: K): Bool { false }
    public func fetchRemove(key: K): ?KeyValue<K, V> { None }
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
    public func next(): ?T { None }
}

/// DevServer input stub
public class DevServerInput {
    public init() {}
}

/// VirtualMachine stub
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
}

/// BunString stub
public class BunString {
    public init() {}
    public static func `static`(s: String): BunString { BunString() }
    public static func createFormat(fmt: String): BunString { BunString() }
    public func toJS(global: JSGlobalObject): JsValue { JsValue() }
}

/// Event loop timer stub
public class EventLoopTimer {
    public init() {}
}

/// HiveArray stub
public class HiveArray<T> {
    public init() {}
    public func get(): T { throw Exception("unimplemented") }
}

/// Memory cost stub
public class MemoryCost {
    public static func memoryCost(dev: DevServer): Int64 { 0 }
}

/// Static route stub
public class StaticRoute {
    public init() {}
    public static func initFromAnyBlob(blobs: Array<Blob>, opts: StaticRouteOptions): StaticRoute { StaticRoute() }
    public func onRequest(resp: AnyResponse): Unit {}
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

/// Blob stub
public class Blob {
    public init() {}
}

/// SendStatus enum
public enum SendStatus {
    | dropped
    | sent
}

/// PluginTarget stub
public class PluginTarget {
    public init(dev: DevServer) {}
}

/// DirInfo stub
public class DirInfo {
    public init() {}
}

/// BoundedArray stub
public class BoundedArray<T> {
    public var slice: Array<T>
    public init(capacity: Int64) {
        slice = Array<T>()
    }
    public init() {
        slice = Array<T>()
    }
}

/// Object helper class
public class Object {
    public init() {}
}

/// MapIterator stub
public class MapIterator<K, V> {
    public init() {}
    public func next(): ?MapEntry<K, V> { None }
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

/// DynamicRouteMap stub
public class DynamicRouteMap {
    public init() {}
}

/// StaticRouteMap stub
public class StaticRouteMap {
    public init() {}
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
    public init() {
        bake = BakeRef()
        path = PathRef()
        strings = StringsRef()
        default_allocator = Allocator()
        jsc = JscRef()
        api = ApiRef()
    }
}

public class BakeRef {
    public init() {}
    public func getHmrRuntime(side: Side): HmrRuntime { HmrRuntime() }
}

public class PathRef {
    public init() {}
    public func relative(base: String, path: String): String { path }
}

public class StringsRef {
    public init() {}
    public static func eqlComptime(a: String, b: String): Bool { a == b }
    public static func eql(a: String, b: String): Bool { a == b }
    public static func hasSuffix(s: String, suffix: String): Bool { s.endsWith(suffix) }
    public static func hasPrefix(s: String, prefix: String): Bool { s.startsWith(prefix) }
    public static func hasSuffixComptime(s: String, suffix: String): Bool { s.endsWith(suffix) }
    public static func withoutTrailingSlashWindowsPath(s: String): String {
        if (s.endsWith("/") || s.endsWith("\\")) { s[0..s.size - 1] } else { s }
    }
}

public class JscRef {
    public init() {}
}

public class ApiRef {
    public init() {}
}

/// Bun global reference
public let bun = BunRef()

/// toBytes utility
public func toBytes(value: UInt32): Array<Byte> {
    var result = Array<Byte>(4)
    result[0] = UInt8(value & UInt32(0xFF))
    result[1] = UInt8((value >> 8) & UInt32(0xFF))
    result[2] = UInt8((value >> 16) & UInt32(0xFF))
    result[3] = UInt8((value >> 24) & UInt32(0xFF))
    return result
}
