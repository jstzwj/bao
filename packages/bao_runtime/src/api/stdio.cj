// BAO_STUB: compile gate for src/runtime/api/bun/spawn/stdio.zig.
// TODO(bao-runtime-api): restore Bun's exact stdio parsing and spawn option conversion.
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}

public class ByteList {
    public init() {}
    public func slice(): Array<UInt8> { Array<UInt8>() }
}

public class Dup2Config {
    public var out: FD = FD(1)
    public var to: FD = FD(1)
    public init() {}
}

public class PathLike {
    public var value: String = ""
    public init() {}
    public init(value: String) { this.value = value }
    public func slice(): String { value }
}

public class BlobAny {
    public init() {}
    public func needsToReadFile(): Bool { false }
    public func store(): ?BlobAnyStore { None }
    public func slice(): Array<UInt8> { Array<UInt8>() }
    public func detach(): Unit {}
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

public enum SpawnOptionsStdio {
    | inherit
    | ignore
    | buffer
    | pipe(FD)
    | path(String)
    | ipc
    | dup2(FD, FD)
}

public class StdioConversionResult {
    public var value: SpawnOptionsStdio = SpawnOptionsStdio.ignore
    public var error: ?String = None
    public init() {}
    public init(value: SpawnOptionsStdio) { this.value = value }
    public init(error: String) { this.error = Some(error) }
    public static func result(value!: SpawnOptionsStdio): StdioConversionResult { StdioConversionResult(value) }
    public static func err(error!: String): StdioConversionResult { StdioConversionResult(error) }
}

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

    public func slice(): Array<UInt8> {
        match (this) {
            case capture(buf) => buf.slice()
            case array_buffer(ab) => ab.byteSlice()
            case _ => Array<UInt8>()
        }
    }

    public func detach(): Unit {}
    public func canUseMemfd(isSync!: Bool, hasMaxBuffer!: Bool): Bool { false }
    public func useMemfdIfPossible(): Bool { false }
    public func toPosix(i!: Int32): StdioConversionResult { StdioConversionResult.result(value: SpawnOptionsStdio.ignore) }
    public func toWindows(i!: Int32): StdioConversionResult { StdioConversionResult.result(value: SpawnOptionsStdio.ignore) }
    public func toSpawnOptions(i!: Int32): StdioConversionResult { toPosix(i: i) }
    public func isPiped(): Bool {
        match (this) {
            case pipe => true
            case capture(_) => true
            case array_buffer(_) => true
            case readable_stream(_) => true
            case ipc => true
            case _ => false
        }
    }

    public static func extract(outStdio!: Stdio, globalThis!: JsGlobalObject, i!: Int32, value!: JsValue, isSync!: Bool): Unit {}
    public static func extractBlob(stdio!: Stdio, globalThis!: JsGlobalObject, blob!: BlobAny, i!: Int32): Unit {}
    public static func extractBodyValue(outStdio!: Stdio, globalThis!: JsGlobalObject, i!: Int32, body!: Any, isSync!: Bool): Unit {}
}

public func createZeroedPipe(): UvPipe { UvPipe() }
