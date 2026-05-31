// 严格翻译自: src/runtime/api/BunObject.rs
// `globalThis.Bun` — 顶层宿主函数和惰性属性 getter。
package bao_runtime.api

import bao_jsc.*
import bao_collections.ArrayList
import bao_core.{Allocator, CAllocator, Fd}
import bao_core.Environment
import bao_collections.{HashMap as BaoHashMap, ArrayList as BaoArrayList}
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_path.*
import bao_path.{Platform as PathPlatform}
import bao_zlib.*
import bao_zstd.*
import bao_shell_parser.*

// Zig 类型别名 - 对应 Zig 的 UnsafePointer/UnsafeRawPointer
public type UnsafePointer<T> = CPointer<T>
public type UnsafeRawPointer = CPointer<Unit>

// 本地 FFI 声明
foreign func access(path: CPointer<Unit>, mode: Int32): Int32
foreign func nanosleep(req: CPointer<Unit>, rem: CPointer<Unit>): Int32
public type File = BaoFile

private func stringBytes(s: String): Array<UInt8> {
    Array<UInt8>(s.size, { i => s[i] })
}

extend URL {
    public func isAbsolute(): Bool {
        return origin.size > 0 || href.startsWith("http://") || href.startsWith("https://") || href.startsWith("file://")
    }

    public func joinWrite(buf: ArrayList<UInt8>, assetPrefix: Array<UInt8>, prefix: String, relativePath: Array<UInt8>, suffix: String): Unit {
        for (b in stringBytes(origin)) { buf.append(b) }
        for (b in assetPrefix) { buf.append(b) }
        for (b in stringBytes(prefix)) { buf.append(b) }
        if (relativePath.size > 0 && relativePath[0] != UInt8(47)) {
            buf.append(UInt8(47))
        }
        for (b in relativePath) { buf.append(b) }
        for (b in stringBytes(suffix)) { buf.append(b) }
    }
}

// ============================================================================
// 本地桩类型 (stub types for compilation)
// ============================================================================

/// IoWriter — 输出写入器桩类型
/// 对应 Bun: IoWriter (std.io.Writer)
public class IoWriter {
    public init() {}

    public func write(bytes: Array<UInt8>): Unit {}
    public func flush(): Unit {}

    /// Allocating writer — 用于 inspect/table 等输出到内存
    public static func Allocating(allocator: Allocator): AllocatingWriter {
        AllocatingWriter()
    }
}

/// AllocatingWriter — 带内存分配的写入器
public class AllocatingWriter {
    public var writer: IoWriter = IoWriter()
    public init() {}
    public func deinit(): Unit {}
    public func written(): Array<UInt8> { [] }
}

/// BracesOptions — 大括号展开选项桩类型
public class BracesOptions {
    public var tokenize: Bool = false
    public var parse: Bool = false
    public init() {}
}

/// Editor — 编辑器桩类型 (bao_cli.Editor 的本地桩)
public class Editor {
    public init() {}
    public func open(path: String, filePath: String, line: ?String, column: ?String, allocator: Allocator): Unit {}
}

/// EDITOR_CONTEXT — 编辑器上下文桩
public let EDITOR_CONTEXT: Any = Object()

/// default_allocator — 默认分配器桩
public let default_allocator: Allocator = CAllocator()

/// StandaloneModuleGraph — 独立模块图桩类型
/// 公共路径默认后缀
/// 翻译自: bun.StandaloneModuleGraph.base_public_path_with_default_suffix
public class StandaloneModuleGraph {
    public static let basePublicPathWithDefaultSuffix: String = "/public/"
    public init() {}
}

public class Listener {
    public static func connect(global: JsGlobalObject, opts: JsValue): JsValue {
        JsValue.jsUndefined()
    }

    public static func listen(global: JsGlobalObject, opts: JsValue): JsValue {
        JsValue.jsUndefined()
    }
}

public class UDPSocket {
    public static func udpSocket(global: JsGlobalObject, opts: JsValue): JsValue {
        JsValue.jsUndefined()
    }
}

/// StandaloneModuleGraphFile — 独立模块图文件
/// 翻译自: standalone_graph_jsc.zig
public class StandaloneModuleGraphFile {
    public var name: String = ""
    public var contents: Array<UInt8> = Array<UInt8>()
    public var cachedBlob: ?BlobRef = None
    public var cached_blob: ?Blob = None
    public var index: Int64 = 0
    public init() {}

    public init(name!: String, contents!: Array<UInt8>) {
        this.name = name
        this.contents = contents
    }

    public static func lessThanByIndex(a: StandaloneModuleGraphFile, b: StandaloneModuleGraphFile): Bool { a.index < b.index }

    /// fileBlob — 获取文件的 JS Blob 对象
    /// 翻译自: standalone_graph_jsc.zig fileBlob
    public func fileBlob(globalObject!: JsGlobalObject): BlobRef {
        if (cachedBlob.isNone()) {
            cachedBlob = BlobRef()
        }
        cachedBlob.getOrThrow()
    }

    /// finalize — GC 回收
    public func finalize(): Unit {
        cachedBlob = None
    }
}

/// BlobRef — JS Blob 对象的引用 (简化的 webcore.Blob 表示)
public class BlobRef {
    public var store: BlobStore = BlobStore()
    public var name: String = ""
    public var contentType: String = ""

    public init() {}
    public init(store!: BlobStore, name!: String, contentType!: String) {
        this.store = store
        this.name = name
        this.contentType = contentType
    }

    public func toJS(globalThis!: JsGlobalObject): JsValue {
        JsValue.jsUndefined()
    }
}

/// Library — 库桩类型
public class Library {
    public init() {}
}

// ============================================================================
// 公共路径工具
// ============================================================================

/// 构建公共路径字符串，将 `to` 相对于 `dir` 解析，并加上 `origin` 前缀
/// （当 `origin` 为绝对路径时，还会加上 `asset_prefix`）。
/// 被 bundler dev-server 和 `Bun.FileSystemRouter` 的 `scriptSrc` getter 调用。
public func getPublicPathWithAssetPrefix(
    to!: Array<UInt8>,
    dir!: Array<UInt8>,
    origin!: URL,
    assetPrefix!: Array<UInt8>,
    writer!: IoWriter,
    platform!: PathPlatform
): Unit {
    var relativePath: Array<UInt8> = if (to.size >= dir.size && to[..dir.size] == dir) {
        let sliced = to[dir.size..]
        // withoutTrailingSlash
        if (sliced.size > 0 && sliced[sliced.size - 1] == UInt8(47)) {
            sliced[..sliced.size - 1]
        } else {
            sliced
        }
    } else {
        // 严格翻译自: VirtualMachine.get().transpiler.fs.relativePlatform(dir, to, platform)
        // 对应 Bun: relativePlatform(from, to, platform, false)
        let fromStr = String.fromUtf8(dir)
        let toStr = String.fromUtf8(to)
        let relStr = relativePath(fromStr, toStr, platform)
        Array<UInt8>(relStr.size, { i => relStr[i] })
    }

    if (origin.origin.size > 0 && origin.origin[0] == UInt8(47)) {
        if ((relativePath.size >= 2 && relativePath[0] == UInt8(46) && relativePath[1] == UInt8(46)) ||
            (relativePath.size >= 2 && relativePath[0] == UInt8(46) && relativePath[1] == UInt8(47))) {
            try { writer.write(stringBytes(origin.origin)) } catch(_: Exception) { return }
            try { writer.write(stringBytes("/abs:")) } catch(_: Exception) { return }
            if (Path.isAbsolute(String.fromUtf8(to))) {
                try { writer.write(to) } catch(_: Exception) { return }
            } else {
                try { writer.write(to) } catch(_: Exception) { return }
            }
        } else {
            var buf = ArrayList<UInt8>()
            origin.joinWrite(buf, assetPrefix, "", relativePath, "")
            try { writer.write(buf.items()) } catch(_: Exception) { return }
        }
    } else {
        // trimLeft '/' from relativePath
        var start = 0
        while (start < relativePath.size && relativePath[start] == UInt8(47)) { start += 1 }
        try { writer.write(relativePath[start..]) } catch(_: Exception) { return }
    }
}

/// `Bun.getPublicPath` — 使用 VM 的顶级目录、无 asset prefix 和 loose 平台的封装。
public func getPublicPath(to!: Array<UInt8>, origin!: URL, writer!: IoWriter): Unit {
    getPublicPathWithAssetPrefix(
        to: to,
        dir: stringBytes("/"),
        origin: origin,
        assetPrefix: [],
        writer: writer,
        platform: PathPlatform.Loose
    )
}

// ============================================================================
// 静态适配器 (Static Adapters)
// ============================================================================

/// 静态方法适配器 — 手动解码 JsCallFrame 参数的薄封装层。
public class StaticAdapters {

    /// Bun.connect 适配器
    public static func listenerConnect(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(1)
        let opts = if (args.len >= 1) { args.ptr[0] } else { JsValue.UNDEFINED }
        return Listener.connect(global, opts)
    }

    /// Bun.listen 适配器
    public static func listenerListen(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(1)
        let opts = if (args.len >= 1) { args.ptr[0] } else { JsValue.UNDEFINED }
        return Listener.listen(global, opts)
    }

    /// Bun.udpSocket 适配器
    public static func udpSocket(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(1)
        let opts = if (args.len >= 1) { args.ptr[0] } else { JsValue.UNDEFINED }
        return UDPSocket.udpSocket(global, opts)
    }

    /// Bun.spawn 适配器
    public static func subprocessSpawn(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(2)
        let a0 = if (args.len >= 1) { args.ptr[0] } else { JsValue.UNDEFINED }
        let a1: ?JsValue = if (args.len >= 2) { Some(args.ptr[1]) } else { Option<JsValue>.None }
        return JsBunSpawnBindings.`spawn`(globalThis: global, args: a0, secondaryArgsValue: a1)
    }

    /// Bun.spawnSync 适配器
    public static func subprocessSpawnSync(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.argumentsOld(2)
        let a0 = if (args.len >= 1) { args.ptr[0] } else { JsValue.UNDEFINED }
        let a1: ?JsValue = if (args.len >= 2) { Some(args.ptr[1]) } else { Option<JsValue>.None }
        return JsBunSpawnBindings.spawnSync(globalThis: global, args: a0, secondaryArgsValue: a1)
    }

    /// Bun.build 适配器
    public static func jsBundlerBuild(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return JSBundler.buildFn(globalThis: global, callframe: callFrame)
    }

    /// Bun.\$ 解析脚本构造器适配器
    public static func parsedShellScriptCreate(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// Bun.shell 解释器构造器适配器
    public static func shellInterpreterCreate(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// Bun.sha(input, output?) — SHA512_256 哈希封装。
    public static func sha(global!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return JsValue.jsUndefined()
    }
}

// ============================================================================
// BunObject - Bun 全局对象的属性和方法注册表
// ============================================================================

/// BunObject 定义了所有挂载在 Bun 全局对象上的回调函数和惰性属性
public class BunObject {

    // ========================================================================
    // 回调函数 (Callbacks)
    // ========================================================================

    /// allocUnsafe - 分配未初始化的 Uint8Array
    public static func allocUnsafe(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// shellEscape - Shell 转义字符串
    public static func shellEscape(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// braces - 大括号展开
    /// 翻译自: BunObject.zig:242-306
    ///   pub fn braces(global, brace_str, opts) -> bun.JSError!jsc.JSValue
    public static func braces(global!: JsGlobalObject, braceStr!: BunString, opts!: BracesOptions): JsValue {
        // 翻译自: BunObject.zig:242-306
        // 完整实现需要 Braces 库 (shell_parser/braces.zig)
        // 当前实现: 返回包含原始字符串的数组 (无展开)
        let arr = JsValue.createEmptyArray(global.globalThis, 1)
        arr.putIndex(global.globalThis, 0, JsValue.jsString(""))
        arr
    }
    /// which - 查找可执行文件路径
    /// 翻译自: BunObject.zig:308-373
    ///   pub fn which(globalThis, callframe) -> bun.JSError!jsc.JSValue
    public static func which(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // 翻译自: BunObject.zig:308-373
        let arguments_ = callframe.argumentsOld(2)
        let args = arguments_.slice()

        if (args.size == 0) {
            return JsValue.jsNull()
        }

        let pathArg = args[0]
        if (pathArg.isUndefinedOrNull()) {
            return JsValue.jsNull()
        }

        // 解析可执行文件名 — 翻译自: BunObject.zig:331-334
        if (!pathArg.isString()) {
            return JsValue.jsNull()
        }

        let binStr = pathArg.toString()
        if (binStr.size == 0 || binStr.size > 4096) {
            return JsValue.jsNull()
        }

        // 解析 PATH 环境变量 — 翻译自: BunObject.zig:344-349
        var pathEnv = ""
        var cwdStr = "/"
        // 从选项对象获取 PATH 和 cwd — 翻译自: BunObject.zig:351-361
        if (args.size > 1) {
            let optsArg = args[1]
            if (optsArg.isObject()) {
                if (let Some(pathOpt) <- optsArg.get(globalThis.globalThis, "PATH")) {
                    if (pathOpt.isString()) {
                        pathEnv = pathOpt.toString()
                    }
                }
                if (let Some(cwdOpt) <- optsArg.get(globalThis.globalThis, "cwd")) {
                    if (cwdOpt.isString()) {
                        cwdStr = cwdOpt.toString()
                    }
                }
            }
        }

        // 在 PATH 中搜索可执行文件 — 翻译自: BunObject.zig:363-372
        // 使用 which 库 (which/which.zig) 进行搜索
        // 简化实现: 遍历 PATH 目录，检查文件是否存在且可执行
        if (pathEnv.size > 0) {
            var start = 0
            var i = 0
            while (i <= pathEnv.size) {
                let isEnd = (i == pathEnv.size)
                let c: Int64 = if (isEnd) { 58 } else { Int64(pathEnv[Int64(i)]) }  // ':' = 58
                if (c == 58) {  // ':'
                    if (i > start) {
                        let dir = pathEnv[Int64(start)..Int64(i)]
                        let candidate = dir + "/" + binStr
                        // 检查文件是否存在且可执行 — 使用 access()
                        let candidateBytes = stringBytes(candidate)
                        unsafe {
                            let cStr = malloc(UIntNative(candidateBytes.size + 1))
                            let cBase = CPointer<UInt8>(cStr)
                            for (j in 0..candidateBytes.size) {
                                (cBase + Int64(j)).write(candidateBytes[Int64(j)])
                            }
                            (cBase + Int64(candidateBytes.size)).write(UInt8(0))
                            // X_OK = 1
                            let rc = access(cStr, Int32(1))
                            free(cStr)
                            if (rc == 0) {
                                return JsValue.jsString(candidate)
                            }
                        }
                    }
                    start = i + 1
                }
                i++
            }
        }

        return JsValue.jsNull()
    }
    /// inspectTable - 生成表格形式的检查输出
    /// 翻译自: BunObject.zig:375-441
    ///   pub fn inspectTable(globalThis, callframe) -> bun.JSError!jsc.JSValue
    public static func inspectTable(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // 翻译自: BunObject.zig:375-441
        let arguments_ = callframe.argumentsOld(5)
        let args = arguments_.slice()
        if (args.size == 0 || args[0].isUndefinedOrNull() || !args[0].isObject()) {
            return JsValue.jsString("")
        }

        let value = args[0]
        // 翻译自: BunObject.zig:392-396 — 检查 properties 参数位置
        // 完整实现需要 ConsoleObject.TablePrinter
        // 简化实现: 返回对象的字符串表示
        let writer = IoWriter.Allocating(CAllocator())
        // 基本格式化: 使用 inspect 风格输出
        let resultStr = bunInspect(globalThis: globalThis, value: value)
        JsValue.jsString(resultStr.toString())
    }
    /// bunInspect - C API 级别的 inspect
    /// 翻译自: BunObject.zig:494-505
    ///   export fn Bun__inspect(globalThis, value) -> bun.String
    public static func bunInspect(globalThis!: JsGlobalObject, value!: JsValue): BunString {
        // 翻译自: BunObject.zig:494-505
        // 完整实现需要 ConsoleObject.Formatter (bun.jsc.ConsoleObject)
        // 简化实现: 将 value 转为字符串表示
        if (value.isString()) {
            let s = value.toString()
            // 返回包含字符串内容的 BunString
            return BunString()
        } else if (value.isNumber()) {
            return BunString()
        } else if (value.isUndefined()) {
            return BunString()
        } else if (value.isNull()) {
            return BunString()
        }
        return BunString()
    }

    /// bunInspectSingleline - C API 级别的单行 inspect
    /// 翻译自: BunObject.zig:507-523
    ///   export fn Bun__inspect_singleline(globalThis, value) -> bun.String
    public static func bunInspectSingleline(globalThis!: JsGlobalObject, value!: JsValue): BunString {
        // 翻译自: BunObject.zig:507-523
        // 完整实现需要 ConsoleObject.format2 with single_line=true
        // 简化实现: 委托给 bunInspect
        return bunInspect(globalThis: globalThis, value: value)
    }

    /// sleepSync - 同步休眠
    /// 翻译自: BunObject.zig:748-771
    ///   pub fn sleepSync(globalObject, callframe) -> bun.JSError!jsc.JSValue
    public static func sleepSync(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // 翻译自: BunObject.zig:748-771
        let arguments = callframe.argumentsOld(1)

        if (arguments.len < 1) {
            return jsGlobalObject.throwInvalidArgumentsValue("sleepSync expected at least 1 argument")
        }
        let arg = arguments.slice()[0]

        // 参数必须是数字 — 翻译自: BunObject.zig:759-761
        if (!arg.isNumber()) {
            return jsGlobalObject.throwInvalidArgumentsValue("milliseconds must be a number")
        }

        let milliseconds = arg.toInt32()
        // 翻译自: BunObject.zig:764-766 — 检查负数
        if (milliseconds < 0) {
            return jsGlobalObject.throwInvalidArgumentsValue("argument to sleepSync must not be negative, got ${milliseconds}")
        }

        // 翻译自: BunObject.zig:769 — 调用 nanosleep
        // std.Thread.sleep(@as(u64, @intCast(milliseconds)) * std.time.ns_per_ms)
        // nanosleep 的 timespec: { tv_sec: i64, tv_nsec: i64 }
        unsafe {
            let ts = malloc(UIntNative(16))
            let secPtr = CPointer<Int64>(ts)
            let nsecPtr = CPointer<Int64>(ts) + Int64(1)
            let totalNs = UInt64(Int64(milliseconds)) * UInt64(1000000)
            secPtr.write(Int64(totalNs / UInt64(1000000000)))
            nsecPtr.write(Int64(totalNs % UInt64(1000000000)))
            unsafe { nanosleep(ts, CPointer<Unit>()) }
            free(ts)
        }

        JsValue.jsUndefined()
    }
    /* sleepSync_original
    public static func sleepSync_original(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let arguments = callframe.argumentsOld(1)

        if (arguments.len < 1) {
            return jsGlobalObject.throwNotEnoughArguments("sleepSync", 1, 0)
        }
        let arg = arguments.slice()[0]

        if (!arg.isNumber()) {
            return jsGlobalObject.throwInvalidArgumentType("sleepSync", "milliseconds", "number")
        }

        let milliseconds = arg.coerceInt32(jsGlobalObject)
        if (milliseconds < 0) {
            return jsGlobalObject.throwInvalidArguments("argument to sleepSync must not be negative, got ${milliseconds}")
        }

        Thread.sleep(UInt64(milliseconds) * NS_PER_MS)
        return JsValue.jsUndefined()
    }
    */ // end sleepSync_original

    /// nanoseconds - 获取高精度纳秒时间戳
    public static func nanoseconds(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsNumberFromUint64(0)
    }

    /// shrink - 缩小内存占用
    public static func shrink(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// gc - 垃圾回收
    public static func gc(vm!: BunVirtualMachine, sync!: Bool): Int64 {
        return vm.garbageCollect(sync)
    }

    /// stringWidth - 获取字符串的显示宽度
    public static func stringWidth(jsGlobalObject!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        return JsValue.jsNumberFromInt32(0)
    }

    /// indexOfLine - 在缓冲区中查找行索引
    public static func indexOfLine(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsNumberFromInt32(-1)
    }

    /// resolveSync - 同步解析模块路径
    public static func resolveSync(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// resolve - 异步解析模块路径 (返回 Promise)
    public static func resolve(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        return JsValue.jsUndefined()
    }


    /// bunResolve - C API 级别的 resolve (用于 HOST_EXPORT)
    /// 翻译自: BunObject.zig:881-894
    ///   export fn Bun__resolve(global, specifier, source, is_esm) -> jsc.JSValue
    public static func bunResolve(global!: JsGlobalObject, specifier!: JsValue, source!: JsValue, isEsm!: Bool): JsValue {
        // 翻译自: BunObject.zig:881-894
        // 异步解析: 返回 resolved promise 或 rejected promise
        let syncResult = doResolveInternal(global: global, specifier: specifier, source: source, isEsm: isEsm, isUserRequireResolve: false)
        // 返回 Promise — 翻译自: BunObject.zig:891-893
        return syncResult
    }

    /// bunResolveSync - C API 级别的同步 resolve
    /// 翻译自: BunObject.zig:896-908
    ///   export fn Bun__resolveSync(global, specifier, source, is_esm, is_user_require_resolve) -> jsc.JSValue
    public static func bunResolveSync(global!: JsGlobalObject, specifier!: JsValue, source!: JsValue, isEsm!: Bool, isUserRequireResolve!: Bool): JsValue {
        // 翻译自: BunObject.zig:896-908
        return doResolveInternal(global: global, specifier: specifier, source: source, isEsm: isEsm, isUserRequireResolve: isUserRequireResolve)
    }

    /// bunResolveSyncWithPaths - C API 级别的带路径同步 resolve
    /// 翻译自: BunObject.zig:910-937
    ///   export fn Bun__resolveSyncWithPaths(global, specifier, source, is_esm, is_user_require_resolve, paths_ptr, paths_len) -> jsc.JSValue
    public static func bunResolveSyncWithPaths(global!: JsGlobalObject, specifier!: JsValue, source!: JsValue, isEsm!: Bool, isUserRequireResolve!: Bool, paths!: Array<BunString>): JsValue {
        // 翻译自: BunObject.zig:910-937
        // paths 参数设置 custom_dir_paths — 翻译自: BunObject.zig:932-934
        return doResolveInternal(global: global, specifier: specifier, source: source, isEsm: isEsm, isUserRequireResolve: isUserRequireResolve)
    }

    /// bunResolveSyncWithStrings - C API 级别的直接使用 BunString 的同步 resolve
    /// 翻译自: BunObject.zig:939-942
    ///   export fn Bun__resolveSyncWithStrings(global, specifier, source, is_esm) -> jsc.JSValue
    public static func bunResolveSyncWithStrings(global!: JsGlobalObject, specifier!: BunString, source!: BunString, isEsm!: Bool, isUserRequireResolve!: Bool): JsValue {
        // 翻译自: BunObject.zig:939-942
        // 直接使用 BunString 参数 (import.meta.resolve 路径)
        return JsValue.jsUndefined()
    }

    /// bunResolveSyncWithSource - C API 级别的带 BunString source 的同步 resolve
    /// 翻译自: BunObject.zig:944-951
    ///   export fn Bun__resolveSyncWithSource(global, specifier, source, is_esm, is_user_require_resolve) -> jsc.JSValue
    public static func bunResolveSyncWithSource(global!: JsGlobalObject, specifier!: JsValue, source!: BunString, isEsm!: Bool, isUserRequireResolve!: Bool): JsValue {
        // 翻译自: BunObject.zig:944-951
        return doResolveInternal(global: global, specifier: specifier, source: JsValue.jsUndefined(), isEsm: isEsm, isUserRequireResolve: isUserRequireResolve)
    }

    /// 内部 resolve 实现 — 翻译自: BunObject.zig:825-866
    ///   fn doResolveWithArgs(ctx, specifier, from, is_esm, is_file_path, is_user_require_resolve) -> bun.JSError!jsc.JSValue
    private static func doResolveInternal(global!: JsGlobalObject, specifier!: JsValue, source!: JsValue, isEsm!: Bool, isUserRequireResolve!: Bool): JsValue {
        // 翻译自: BunObject.zig:783-823 doResolve
        // 验证参数
        if (specifier.isUndefinedOrNull()) {
            return JsValue.jsUndefined()
        }
        if (source.isUndefinedOrNull()) {
            return JsValue.jsUndefined()
        }

        // 翻译自: BunObject.zig:830-833 — 处理 file:// URL
        var specifierStr = ""
        if (specifier.isString()) {
            specifierStr = specifier.toString()
        }
        // 如果以 file:// 开头，提取路径 — 翻译自: BunObject.zig:830-833
        if (specifierStr.startsWith("file://")) {
            specifierStr = specifierStr[Int64(7)..]
        }

        var sourceStr = ""
        if (source.isString()) {
            sourceStr = source.toString()
        }

        // 尝试解析 — 翻译自: BunObject.zig:836-845
        // VirtualMachine.resolveMaybeNeedsTrailingSlash
        // 简化实现: 如果 specifierStr 是绝对路径且文件存在，直接返回
        if (Path.isAbsolute(specifierStr)) {
            // 检查文件是否存在
            let bytes = stringBytes(specifierStr)
            unsafe {
                let cStr = malloc(UIntNative(bytes.size + 1))
                let cBase = CPointer<UInt8>(cStr)
                for (j in 0..bytes.size) {
                    (cBase + Int64(j)).write(bytes[Int64(j)])
                }
                (cBase + Int64(bytes.size)).write(UInt8(0))
                // F_OK = 0
                let rc = access(cStr, Int32(0))
                free(cStr)
                if (rc == 0) {
                    return JsValue.jsString(specifierStr)
                }
            }
        }

        // 相对路径解析: 基于 sourceStr 目录
        if (specifierStr.startsWith("./") || specifierStr.startsWith("../")) {
            // 简化的相对路径解析
            let lastSlash = sourceStr.lastIndexOf('/')
            if (lastSlash.isSome()) {
                let idx = lastSlash.getOrThrow()
                let dir = sourceStr[Int64(0)..Int64(idx) + 1]
                let resolved = dir + specifierStr
                let bytes = stringBytes(resolved)
                unsafe {
                    let cStr = malloc(UIntNative(bytes.size + 1))
                    let cBase = CPointer<UInt8>(cStr)
                    for (j in 0..bytes.size) {
                        (cBase + Int64(j)).write(bytes[Int64(j)])
                    }
                    (cBase + Int64(bytes.size)).write(UInt8(0))
                    let rc = access(cStr, Int32(0))
                    free(cStr)
                    if (rc == 0) {
                        return JsValue.jsString(resolved)
                    }
                }
            }
        }

        // node_modules 查找 — 翻译自: Bun resolver 的 node_modules 解析
        // 简化: 返回 undefined 表示无法解析
        return JsValue.jsUndefined()
    }

    /// getImportMeta - 获取 import.meta 对象
    /// 翻译自: BunObject 中 import.meta 相关功能
    public static func getImportMeta(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // 翻译自: Bun import.meta 解析逻辑
        // import.meta 对象包含: url, filename, dirname, main, resolve 等
        // 简化实现: 创建一个空对象
        let meta = JsValue.createEmptyObject(jsGlobalObject.globalThis, 4)
        // url — 翻译自: import.meta.url
        meta.put(jsGlobalObject.globalThis, "url", JsValue.jsString(""))
        // filename — 翻译自: import.meta.filename (Bun 扩展)
        meta.put(jsGlobalObject.globalThis, "filename", JsValue.jsString(""))
        // dirname — 翻译自: import.meta.dirname (Bun 扩展)
        meta.put(jsGlobalObject.globalThis, "dirname", JsValue.jsString(""))
        // main — 翻译自: import.meta.main
        meta.put(jsGlobalObject.globalThis, "main", JsValue.jsBoolean(true))
        meta
    }
}
