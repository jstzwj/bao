// Compile-gating API surface for Readable.zig.
package bao_runtime.api

import bao_core.Allocator
import bao_jsc.{JsGlobalObject, JsValue}
import bao_sys.*

public type BlobSizeType = Int64

public enum Readable {
    | fd(FD)
    | memfd(FD)
    | pipe(PipeReader)
    | inherit
    | ignore
    | closed
    | buffer(Array<UInt8>)

    public func hasPendingActivity(): Bool {
        match (this) {
            case pipe(reader) => reader.hasPendingActivity()
            case _ => false
        }
    }

    public func ref(): Unit {}
    public func unref(): Unit {}

    public static func initFunc(
        stdio!: Stdio,
        eventLoop!: EventLoop,
        process!: Subprocess,
        result!: StdioResult,
        allocator!: Allocator,
        maxSize!: MaxBuf,
        isSync!: Bool
    ): Readable {
        match (stdio) {
            case inherit => Readable.inherit
            case fd(fdValue) => Readable.fd(fdValue)
            case memfd(fdValue) => Readable.memfd(fdValue)
            case pipe => Readable.pipe(PipeReader.create(eventLoop: eventLoop, process: process, result: result, limit: Some(maxSize)))
            case capture(_) => Readable.buffer(Array<UInt8>())
            case _ => Readable.ignore
        }
    }

    public func close(): Unit {}
    public func toJS(globalThis!: JsGlobalObject, exited!: Bool): JsValue { JsValue.jsUndefined() }
    public func finalize(): Unit {}
    public func updateRef(add!: Bool): Unit {}
    public func memoryCost(): Int { 0 }
}
