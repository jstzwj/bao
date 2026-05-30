// 翻译自: src/runtime/api/bun/spawn/stdio.zig
//   Stdio — 标准流配置枚举
//   负责解析 JS 层的 stdio 选项并转换为 spawn 选项
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}

// ============================================================================
// ByteList — 字节列表
// 翻译自: bun.ByteList
// ============================================================================

public class ByteList {
    private var data: Array<UInt8> = Array<UInt8>()
    public init() {}
    public func slice(): Array<UInt8> { data }
}

// ============================================================================
// Dup2Config — dup2 配置
// 翻译自: src/runtime/api/bun/spawn/stdio.zig:6-9
//   dup2: struct { out: StdioKind, to: StdioKind }
// ============================================================================

public class Dup2Config {
    public var out: FD = FD(1)
    public var to: FD = FD(1)
    public init() {}
    public init(out!: FD, to!: FD) {
        this.out = out
        this.to = to
    }
}

// ============================================================================
// PathLike — 路径
// 翻译自: jsc.Node.PathLike
// ============================================================================

public class PathLike {
    public var value: String = ""
    public init() {}
    public init(value: String) { this.value = value }
    public func slice(): String { value }
}

// ============================================================================
// BlobAny — Blob 类型擦除
// 翻译自: jsc.WebCore.Blob.Any
// ============================================================================

public class BlobAny {
    public init() {}
    public func needsToReadFile(): Bool { false }
    public func store(): ?BlobAnyStore { None }
    public func slice(): Array<UInt8> { Array<UInt8>() }
    public func detach(): Unit {}
    public func fastSize(): Int64 { 0 }
}

public class BlobAnyStore {
    public var data: BlobAnyStoreData = BlobAnyStoreData()
    public init() {}
}

public class BlobAnyStoreData {
    public var file: BlobAnyFile = BlobAnyFile()
    public init() {}
}

public class BlobAnyFile {
    public var pathlike: BlobAnyPathLike = BlobAnyPathLike()
    public init() {}
}

public class BlobAnyPathLike {
    public var fd: FD = FD(-1)
    public var path: PathLike = PathLike()
    public init() {}
}

// ============================================================================
// SpawnOptionsStdio — spawn 选项中的 stdio 枚举
// 翻译自: PosixSpawnOptions.Stdio (process.zig:1093-1102)
//   pub const Stdio = union(enum) { path, inherit, ignore, buffer, ipc, pipe, dup2 }
// ============================================================================

public enum SpawnOptionsStdio {
    | inherit
    | ignore
    | buffer
    | pipe(FD)
    | path(String)
    | ipc
    | dup2(FD, FD)
}

// ============================================================================
// StdioConversionResult — stdio 转换结果
// 翻译自: Stdio.Result (stdio.zig:21-23)
// ============================================================================

public class StdioConversionResult {
    public var value: SpawnOptionsStdio = SpawnOptionsStdio.ignore
    public var errMsg: ?String = None
    public init() {}
    public init(value: SpawnOptionsStdio) { this.value = value }
    public init(errMsg: String) { this.errMsg = Some(errMsg) }
    public static func result(value!: SpawnOptionsStdio): StdioConversionResult { StdioConversionResult(value) }
    public static func fromErr(errMsg!: String): StdioConversionResult { StdioConversionResult(errMsg) }
}

// ============================================================================
// Stdio — 标准流配置枚举
// 翻译自: src/runtime/api/bun/spawn/stdio.zig:1-489
//   pub const Stdio = union(enum) { inherit, capture, ignore, fd, dup2, path, blob, ... }
// ============================================================================

public enum Stdio {
    | inherit
    | capture(ByteList)
    | ignore
    | fd(FD)
    | dup2(Dup2Config)
    | path(PathLike)
    | blob(BlobAny)
    | array_buffer(ArrayBufferStrong)
    | memfd(FD)
    | pipe
    | ipc
    | readable_stream(ReadableStream)

    /// 获取字节切片
    /// 翻译自: src/runtime/api/bun/spawn/stdio.zig:52-59
    ///   pub fn byteSlice(this: *const Stdio) []const u8
    public func slice(): Array<UInt8> {
        match (this) {
            case capture(buf) => buf.slice()
            case array_buffer(ab) => ab.byteSlice()
            case blob(b) => b.slice()
            case _ => Array<UInt8>()
        }
    }

    /// 释放资源
    /// 翻译自: src/runtime/api/bun/spawn/stdio.zig:61-77
    ///   pub fn deinit(this: *Stdio) void
    public func detach(): Unit {
        match (this) {
            case array_buffer(ab) => ab.deinit()
            case blob(b) => b.detach()
            case memfd(f) => f.close()
            case _ => ()
        }
    }

    /// 是否可以使用 memfd (Linux)
    /// 翻译自: src/runtime/api/bun/spawn/stdio.zig:79-90
    ///   pub fn canUseMemfd(this, is_sync, has_max_buffer) -> bool
    public func canUseMemfd(isSync!: Bool, hasMaxBuffer!: Bool): Bool {
        match (this) {
            case blob(b) => !b.needsToReadFile()
            case memfd(_) | array_buffer(_) => true
            case pipe => isSync && !hasMaxBuffer
            case _ => false
        }
    }

    /// 尝试使用 memfd (Linux)
    /// 翻译自: src/runtime/api/bun/spawn/stdio.zig:92-145
    ///   pub fn useMemfd(this, index) -> bool
    public func useMemfdIfPossible(): Bool {
        // TODO(bao-runtime-api): 实现 memfd_create + write + 替换
        false
    }

    /// 转为 POSIX spawn 选项
    /// 翻译自: src/runtime/api/bun/spawn/stdio.zig:147-198
    ///   fn toPosix(stdio, i) -> Result
    public func toPosix(i!: Int32): StdioConversionResult {
        match (this) {
            case blob(b) =>
                if (b.needsToReadFile()) {
                    match (b.store()) {
                        case Some(store) =>
                            let fd = store.data.file.pathlike.fd
                            if (fd.value >= 0) {
                                return StdioConversionResult.result(value: SpawnOptionsStdio.pipe(fd))
                            }
                            let path = store.data.file.pathlike.path.slice()
                            return StdioConversionResult.result(value: SpawnOptionsStdio.path(path))
                        case None =>
                            // stdin: buffer; stdout/stderr: 错误
                            if (i == 1 || i == 2) {
                                return StdioConversionResult.fromErr(errMsg: "Blobs are immutable, and cannot be used for stdout/stderr")
                            }
                            return StdioConversionResult.result(value: SpawnOptionsStdio.buffer)
                    }
                }
                if (i == 1 || i == 2) {
                    return StdioConversionResult.fromErr(errMsg: "Blobs are immutable, and cannot be used for stdout/stderr")
                }
                return StdioConversionResult.result(value: SpawnOptionsStdio.buffer)

            case dup2(config) =>
                return StdioConversionResult.result(value: SpawnOptionsStdio.dup2(config.out, config.to))

            case capture(_) | pipe | array_buffer(_) | readable_stream(_) =>
                return StdioConversionResult.result(value: SpawnOptionsStdio.buffer)

            case ipc =>
                return StdioConversionResult.result(value: SpawnOptionsStdio.ipc)

            case fd(f) =>
                return StdioConversionResult.result(value: SpawnOptionsStdio.pipe(f))

            case memfd(f) =>
                return StdioConversionResult.result(value: SpawnOptionsStdio.pipe(f))

            case path(p) =>
                return StdioConversionResult.result(value: SpawnOptionsStdio.path(p.slice()))

            case inherit =>
                return StdioConversionResult.result(value: SpawnOptionsStdio.inherit)

            case ignore =>
                return StdioConversionResult.result(value: SpawnOptionsStdio.ignore)
        }
    }

    /// 转为 Windows spawn 选项
    /// 翻译自: src/runtime/api/bun/spawn/stdio.zig:200-252
    ///   fn toWindows(stdio, i) -> Result
    public func toWindows(i!: Int32): StdioConversionResult {
        // Windows 路径: 类似 POSIX，但 buffer 使用 uv.Pipe
        return toPosix(i: i)
    }

    /// 转为 spawn 选项 (根据平台选择)
    /// 翻译自: src/runtime/api/bun/spawn/stdio.zig:262-271
    ///   pub fn asSpawnOption(stdio, i) -> Stdio.Result
    public func toSpawnOptions(i!: Int32): StdioConversionResult {
        // Linux/macOS: 使用 POSIX 路径
        return toPosix(i: i)
    }

    /// 是否为管道模式
    /// 翻译自: src/runtime/api/bun/spawn/stdio.zig:273-279
    ///   pub fn isPiped(self: Stdio) -> bool
    public func isPiped(): Bool {
        match (this) {
            case pipe | capture(_) | array_buffer(_) | readable_stream(_) | ipc => true
            case _ => false
        }
    }

    /// 从 JS 值提取 stdio 配置
    /// 翻译自: src/runtime/api/bun/spawn/stdio.zig:332-441
    ///   pub fn extract(out_stdio, globalThis, i, value, is_sync) -> bun.JSError!void
    public static func extract(outStdio!: Stdio, globalThis!: JsGlobalObject, i!: Int32, value!: JsValue, isSync!: Bool): Unit {
        // TODO(bao-runtime-api): 实现 JS 值解析
        //   - null/undefined -> ignore
        //   - "inherit" -> inherit
        //   - "pipe" -> pipe
        //   - "ignore" -> ignore
        //   - "ipc" -> ipc
        //   - number -> fd
        //   - Blob -> blob
        //   - Request/Response -> body
        //   - ReadableStream -> readable_stream
        //   - ArrayBuffer -> array_buffer
    }

    /// 从 Blob 提取 stdio 配置
    /// 翻译自: src/runtime/api/bun/spawn/stdio.zig:443-488
    ///   pub fn extractBlob(stdio, globalThis, blob, i) -> bun.JSError!void
    public static func extractBlob(stdio!: Stdio, globalThis!: JsGlobalObject, blob!: BlobAny, i!: Int32): Unit {
        // TODO(bao-runtime-api): 实现 Blob 提取
    }

    /// 从 Body.Value 提取 stdio 配置
    /// 翻译自: src/runtime/api/bun/spawn/stdio.zig:281-330
    ///   fn extractBodyValue(out_stdio, globalThis, i, body, is_sync) -> bun.JSError!void
    public static func extractBodyValue(outStdio!: Stdio, globalThis!: JsGlobalObject, i!: Int32, body!: Any, isSync!: Bool): Unit {
        // TODO(bao-runtime-api): 实现 Body.Value 提取
    }
}

/// 创建零初始化的 uv.Pipe
/// 翻译自: src/runtime/api/bun/spawn/stdio.zig:494-496
///   fn createZeroedPipe() -> *uv.Pipe
public func createZeroedPipe(): UvPipe { UvPipe() }
