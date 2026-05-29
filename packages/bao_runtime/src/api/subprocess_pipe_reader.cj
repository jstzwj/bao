// BAO_STUB: compile gate for src/runtime/api/bun/subprocess/SubprocessPipeReader.zig.
// TODO(bao-runtime-api): restore the Bun one-to-one subprocess pipe reader.
package bao_runtime.api

import bao_jsc.{JsGlobalObject, JsValue}
import bao_sys.*

public class JsNode { public init() {} }

public class PipeReader {
    public var process: ?Subprocess = None
    public var eventLoop: EventLoop = EventLoop()
    public var state: PipeReaderState = PipeReaderState.pending
    public var stdioResult: StdioResult = StdioResult.unavailable
    public var buffer: Array<UInt8> = Array<UInt8>()

    public init() {}

    public static func create(eventLoop!: EventLoop, process!: Subprocess, result!: StdioResult, limit!: ?MaxBuf): PipeReader {
        let reader = PipeReader()
        reader.eventLoop = eventLoop
        reader.process = Some(process)
        reader.stdioResult = result
        MaxBuf.addToPipeReader(limit: limit, readerMaxbuf: reader)
        reader
    }

    public func start(process!: Subprocess, eventLoop!: EventLoop): Maybe<Unit> {
        this.process = Some(process)
        this.eventLoop = eventLoop
        SysMaybe<Unit>.Ok(())
    }

    public func readAll(): Unit {}
    public func toOwnedSlice(): Array<UInt8> { buffer }
    public func toReadableStream(jsGlobalObject!: JsGlobalObject): JsValue { JsValue.jsUndefined() }
    public func toBuffer(globalThis!: JsGlobalObject): JsValue { JsValue.jsUndefined() }
    public func onReaderDone(): Unit { state = PipeReaderState.done(buffer) }
    public func onReaderError(err!: SysError): Unit { state = PipeReaderState.pipeErr(err) }
    public func kind(process!: Subprocess): ApiStdioKind { ApiStdioKind.apiStdout }
    public func detach(): Unit { process = None }
    public func close(): Unit { state = PipeReaderState.done(buffer) }
    public func updateRef(add!: Bool): Unit {}
    public func watch(): Unit {}
    public func hasPendingActivity(): Bool { state.isPending() }
    public func memoryCost(): Int { 0 }
    public func deinit(): Unit {}
}

public type SubprocessPipeReader = PipeReader
