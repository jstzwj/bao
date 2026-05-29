// BAO_STUB: compile gate for src/runtime/api/bun/subprocess/StaticPipeWriter.zig.
// TODO(bao-runtime-api): restore the Bun one-to-one static pipe writer.
package bao_runtime.api

import bao_io.WriteStatus
import bao_sys.*

public enum StaticPipeWriterSource {
    | blob(BlobAny)
    | arrayBuffer(ArrayBufferStrong)

    public func slice(): String { "" }
    public func detach(): Unit {}
    public func memoryCost(): Int { 0 }
}

public class StaticPipeWriter {
    public var stdioResult: StdioResult = StdioResult.unavailable
    public var process: ?Subprocess = None
    public var eventLoop: EventLoop = EventLoop()
    public var buffer: String = ""

    public init() {}

    public static func create(eventLoop!: EventLoop, subprocess!: Subprocess, result!: StdioResult, source!: StaticPipeWriterSource): StaticPipeWriter {
        let writer = StaticPipeWriter()
        writer.eventLoop = eventLoop
        writer.process = Some(subprocess)
        writer.stdioResult = result
        writer.buffer = source.slice()
        writer
    }

    public func start(): Maybe<Unit> { SysMaybe<Unit>.Ok(()) }
    public func onWrite(amount!: Int, status!: WriteStatus): Unit {}
    public func onError(err!: SysError): Unit {}
    public func onClose(): Unit {
        match (process) {
            case Some(proc) => proc.onCloseIO(kind: ApiStdioKind.apiStdin)
            case None => ()
        }
    }
    public func getBuffer(): String { buffer }
    public func close(): Unit {}
    public func flush(): Unit {}
    public func watch(): Unit {}
    public func updateRef(add!: Bool): Unit {}
    public func memoryCost(): Int { 0 }
    public func deinit(): Unit {}
    public func ref(): Unit {}
    public func deref(): Unit {}
}
