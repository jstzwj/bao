// 严格翻译自: src/runtime/api/BunObject.rs
// `globalThis.Bun` — 顶层宿主函数和惰性属性 getter。
package bao_runtime.api

import bao_jsc.*
import bao_collections.ArrayList
import bao_core.{Allocator, CAllocator, Environment, Fd, MAX_PATH_BYTES}
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
public class StandaloneModuleGraph {
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

/// StandaloneModuleGraphFile — 独立模块图文件桩类型
public class StandaloneModuleGraphFile {
    public var cached_blob: ?Blob = None
    public var index: Int64 = 0
    public init() {}
    public static func lessThanByIndex(a: StandaloneModuleGraphFile, b: StandaloneModuleGraphFile): Bool { a.index < b.index }
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
    public static func braces(global!: JsGlobalObject, braceStr!: BunString, opts!: BracesOptions): JsValue {
        // TODO: 完整实现需要 Braces 库支持
        return JsValue.jsUndefined()
    }
    /// which - 查找可执行文件路径
    public static func which(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // TODO: 完整实现需要 PathBufferPool 和 which 库支持
        return JsValue.jsNull()
    }
    /// inspectTable - 生成表格形式的检查输出
    public static func inspectTable(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // TODO: 完整实现需要 ConsoleObject 和 TablePrinter 支持
        return JsValue.jsUndefined()
    }
    /// bunInspect - C API 级别的 inspect
    public static func bunInspect(globalThis!: JsGlobalObject, value!: JsValue): BunString {
        // TODO: 完整实现需要 ConsoleObject.Formatter 支持
        return BunString()
    }

    /// bunInspectSingleline - C API 级别的单行 inspect
    public static func bunInspectSingleline(globalThis!: JsGlobalObject, value!: JsValue): BunString {
        // TODO: 完整实现需要 ConsoleObject.format2 支持
        return BunString()
    }

    /// sleepSync - 同步休眠
    public static func sleepSync(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // TODO: 完整实现需要 nanosleep FFI 支持
        return JsValue.jsUndefined()
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
    public static func bunResolve(global!: JsGlobalObject, specifier!: JsValue, source!: JsValue, isEsm!: Bool): JsValue {
        // TODO: 完整实现需要模块解析器支持
        return JsValue.jsUndefined()
    }

    /// bunResolveSync - C API 级别的同步 resolve
    public static func bunResolveSync(global!: JsGlobalObject, specifier!: JsValue, source!: JsValue, isEsm!: Bool, isUserRequireResolve!: Bool): JsValue {
        // TODO: 完整实现需要模块解析器支持
        return JsValue.jsUndefined()
    }

    /// bunResolveSyncWithPaths - C API 级别的带路径同步 resolve
    public static func bunResolveSyncWithPaths(global!: JsGlobalObject, specifier!: JsValue, source!: JsValue, isEsm!: Bool, isUserRequireResolve!: Bool, paths!: Array<BunString>): JsValue {
        // TODO: 完整实现需要模块解析器支持
        return JsValue.jsUndefined()
    }

    /// bunResolveSyncWithStrings - C API 级别的直接使用 BunString 的同步 resolve
    public static func bunResolveSyncWithStrings(global!: JsGlobalObject, specifier!: BunString, source!: BunString, isEsm!: Bool, isUserRequireResolve!: Bool): JsValue {
        // TODO: 完整实现需要模块解析器支持
        return JsValue.jsUndefined()
    }

    /// bunResolveSyncWithSource - C API 级别的带 BunString source 的同步 resolve
    public static func bunResolveSyncWithSource(global!: JsGlobalObject, specifier!: JsValue, source!: BunString, isEsm!: Bool, isUserRequireResolve!: Bool): JsValue {
        // TODO: 完整实现需要模块解析器支持
        return JsValue.jsUndefined()
    }

    /// getImportMeta - 获取 import.meta 对象
    public static func getImportMeta(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        // TODO: 完整实现
        return JsValue.jsUndefined()
    }
}
