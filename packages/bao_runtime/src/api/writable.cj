// Compile-gating API surface for Writable.zig.
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}
import bao_sys.*

public enum Writable {
    | pipe(FileSink)
    | buffer(StaticPipeWriter)
    | fd(FD)
    | memfd(FD)
    | ignore
    | inherit
    | other

    public func hasPendingActivity(): Bool {
        match (this) {
            case buffer(_) => true
            case _ => false
        }
    }

    public func ref(): Unit {}
    public func unref(): Unit {}
    public func onClose(err!: SysError): Unit {}
    public func onReady(size!: BlobSizeType, totalSize!: BlobSizeType): Unit {}
    public func onStart(): Unit {}

    public static func initFunc(
        stdio!: Stdio,
        eventLoop!: EventLoop,
        subprocess!: Subprocess,
        result!: StdioResult,
        promiseForStream!: JsValue
    ): Writable {
        match (stdio) {
            case inherit => Writable.inherit
            case fd(fdValue) => Writable.fd(fdValue)
            case memfd(fdValue) => Writable.memfd(fdValue)
            case pipe => Writable.pipe(FileSink())
            case blob(blobValue) => Writable.buffer(StaticPipeWriter.create(
                eventLoop: eventLoop,
                subprocess: subprocess,
                result: result,
                source: StaticPipeWriterSource.blob(blobValue)
            ))
            case array_buffer(arrayBufferValue) => Writable.buffer(StaticPipeWriter.create(
                eventLoop: eventLoop,
                subprocess: subprocess,
                result: result,
                source: StaticPipeWriterSource.arrayBuffer(arrayBufferValue)
            ))
            case _ => Writable.ignore
        }
    }

    public func toJS(globalThis!: JsGlobalObject, subprocess!: Subprocess): JsValue { JsValue.jsUndefined() }
    public func finalize(): Unit {}
    public func close(): Unit {}
}
