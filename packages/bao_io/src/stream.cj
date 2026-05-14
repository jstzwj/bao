// bao_io - 通用 Stream 抽象
// 严格翻译自: src/io/ (Bun 的流抽象)
//   Bun 使用 ReadableStream / WritableStream 处理流式数据
//   仓颉提供等价的流抽象
package bao_io

import bao_core.*
import bao_sys.*

// ============================================================================
// Stream - 通用流抽象
// 严格翻译自: Web Streams API + Bun 流扩展
// ============================================================================

/// 流状态
public enum StreamState {
    | Readable    // 可读
    | Writable    // 可写
    | Closed      // 已关闭
    | Errored     // 出错
}

/// 读取结果 - 对应 Web ReadableStream read() 结果
public class ReadResult {
    /// 读取的数据
    public var data: Array<UInt8>
    /// 是否完成
    public var done: Bool

    public init(data: Array<UInt8>, done: Bool) {
        this.data = data
        this.done = done
    }

    public static func done(): ReadResult {
        return ReadResult([], true)
    }

    public static func data(d: Array<UInt8>): ReadResult {
        return ReadResult(d, false)
    }
}

// ============================================================================
// ReadableStream - 可读流
// 严格翻译自: Web ReadableStream + Bun 扩展
// ============================================================================

/// 可读流底层源 - 对应 Bun UnderlyingSource
public interface UnderlyingSource {
    func start(controller: ReadableStreamController): Unit
    func pull(controller: ReadableStreamController): Unit
    func cancel(): Unit
}

/// 可读流控制器 - 对应 ReadableStreamDefaultController
public class ReadableStreamController {
    private var stream: ReadableStream

    public init(stream: ReadableStream) {
        this.stream = stream
    }

    /// 入队数据块
    public func enqueue(data: Array<UInt8>): Unit {
        stream.enqueueChunk(data)
    }

    /// 关闭流
    public func close(): Unit {
        stream.close()
    }

    /// 报告错误
    public func error(e: SysError): Unit {
        stream.error(e)
    }
}

/// 可读流 - 对应 Bun ReadableStream
public class ReadableStream {
    /// 流状态
    public var state: StreamState
    /// 缓冲区
    private var buffer: ArrayList<Array<UInt8>>
    /// 底层源
    private var source: ?UnderlyingSource
    /// 控制器
    private var controller: ReadableStreamController
    /// 错误
    public var lastError: ?SysError

    public init() {
        state = StreamState.Readable
        buffer = ArrayList<Array<UInt8>>()
        source = None
        controller = ReadableStreamController(this)
        lastError = None
    }

    public init(source: UnderlyingSource) {
        state = StreamState.Readable
        buffer = ArrayList<Array<UInt8>>()
        this.source = Some(source)
        controller = ReadableStreamController(this)
        lastError = None
        source.start(controller)
    }

    /// 从文件描述符创建可读流
    /// 对应 Bun: new Response(ReadableStream.from(fd))
    public static func fromFd(fd: Int64, bufferSize: Int64): ReadableStream {
        let stream = ReadableStream()
        stream.source = Some(FdSource(fd, bufferSize))
        match (stream.source) {
            case Some(s) => s.start(stream.controller)
            case None => ()
        }
        return stream
    }

    /// 读取数据块
    /// 对应 Bun: reader.read()
    public func read(): ReadResult {
        if (buffer.size > 0) {
            return ReadResult.data(buffer.removeAt(0))
        }
        if (state == StreamState.Closed) {
            return ReadResult.done()
        }
        if (state == StreamState.Errored) {
            return ReadResult.done()
        }
        // 尝试拉取更多数据
        match (source) {
            case Some(s) => s.pull(controller)
            case None => ()
        }
        if (buffer.size > 0) {
            return ReadResult.data(buffer.removeAt(0))
        }
        return ReadResult.done()
    }

    /// 入队数据块 (内部使用)
    public func enqueueChunk(data: Array<UInt8>): Unit {
        buffer.append(data)
    }

    /// 关闭流
    public func close(): Unit {
        state = StreamState.Closed
    }

    /// 报告错误
    public func error(e: SysError): Unit {
        state = StreamState.Errored
        lastError = Some(e)
    }

    /// 取消流
    public func cancel(): Unit {
        match (source) {
            case Some(s) => s.cancel()
            case None => ()
        }
        state = StreamState.Closed
    }

    /// 是否可读
    public func isReadable(): Bool {
        return state == StreamState.Readable
    }
}

/// 文件描述符源
class FdSource <: UnderlyingSource {
    private var fd: Int64
    private var bufferSize: Int64
    private var eof: Bool

    init(fd: Int64, bufferSize: Int64) {
        this.fd = fd
        this.bufferSize = bufferSize
        this.eof = false
    }

    func start(controller: ReadableStreamController): Unit {
        // 初始读取
        pull(controller)
    }

    func pull(controller: ReadableStreamController): Unit {
        if (eof) {
            controller.close()
            return
        }
        let chunk = Array<UInt8>(bufferSize, item: UInt8(0))
        match (SysFs.read(fd, chunk)) {
            case Err(e) => controller.error(e)
            case Ok(bytesRead) =>
                if (bytesRead == 0) {
                    eof = true
                    controller.close()
                } else {
                    var data = Array<UInt8>()
                    for (i in 0..bytesRead) {
                        data.append(chunk[i])
                    }
                    controller.enqueue(data)
                }
        }
    }

    func cancel(): Unit {
        SysFs.close(fd)
    }
}

// ============================================================================
// WritableStream - 可写流
// 严格翻译自: Web WritableStream + Bun 扩展
// ============================================================================

/// 可写流底层汇 - 对应 Bun UnderlyingSink
public interface UnderlyingSink {
    func write(data: Array<UInt8>): Unit
    func close(): Unit
    func abort(): Unit
}

/// 可写流 - 对应 Bun WritableStream
public class WritableStream {
    /// 流状态
    public var state: StreamState
    /// 底层汇
    private var sink: ?UnderlyingSink
    /// 缓冲区
    private var buffer: ArrayList<Array<UInt8>>
    /// 错误
    public var lastError: ?SysError

    public init() {
        state = StreamState.Writable
        sink = None
        buffer = ArrayList<Array<UInt8>>()
        lastError = None
    }

    public init(sink: UnderlyingSink) {
        state = StreamState.Writable
        this.sink = Some(sink)
        buffer = ArrayList<Array<UInt8>>()
        lastError = None
    }

    /// 从文件描述符创建可写流
    public static func fromFd(fd: Int64): WritableStream {
        return WritableStream(FdSink(fd))
    }

    /// 写入数据
    /// 对应 Bun: writer.write(data)
    public func write(data: Array<UInt8>): Unit {
        match (sink) {
            case Some(s) => s.write(data)
            case None => buffer.append(data)
        }
    }

    /// 写入字符串
    public func writeString(text: String): Unit {
        var bytes = Array<UInt8>()
        for (c in text) {
            bytes.append(UInt8(c.value))
        }
        write(bytes)
    }

    /// 关闭流
    public func close(): Unit {
        // 刷新缓冲区
        match (sink) {
            case Some(s) =>
                for (chunk in buffer) {
                    s.write(chunk)
                }
                s.close()
            case None => ()
        }
        buffer.clear()
        state = StreamState.Closed
    }

    /// 中止流
    public func abort(): Unit {
        match (sink) {
            case Some(s) => s.abort()
            case None => ()
        }
        buffer.clear()
        state = StreamState.Errored
    }

    /// 是否可写
    public func isWritable(): Bool {
        return state == StreamState.Writable
    }
}

/// 文件描述符汇
class FdSink <: UnderlyingSink {
    private var fd: Int64

    init(fd: Int64) {
        this.fd = fd
    }

    func write(data: Array<UInt8>): Unit {
        SysFs.write(fd, data)
    }

    func close(): Unit {
        SysFs.close(fd)
    }

    func abort(): Unit {
        SysFs.close(fd)
    }
}

// ============================================================================
// TransformStream - 转换流
// 严格翻译自: Web TransformStream
// ============================================================================

/// 转换流 - 对应 Bun TransformStream
/// 接收输入数据，转换后输出
public class TransformStream {
    /// 可读端
    public var readable: ReadableStream
    /// 可写端
    public var writable: WritableStream
    /// 转换函数
    private var transformFn: (Array<UInt8>) -> Array<UInt8>

    public init(transformFn: (Array<UInt8>) -> Array<UInt8>) {
        this.readable = ReadableStream()
        this.writable = WritableStream(TransformSink(readable, transformFn))
        this.transformFn = transformFn
    }
}

/// 转换汇
class TransformSink <: UnderlyingSink {
    private var readable: ReadableStream
    private var transformFn: (Array<UInt8>) -> Array<UInt8>

    init(readable: ReadableStream, transformFn: (Array<UInt8>) -> Array<UInt8>) {
        this.readable = readable
        this.transformFn = transformFn
    }

    func write(data: Array<UInt8>): Unit {
        let transformed = transformFn(data)
        readable.enqueueChunk(transformed)
    }

    func close(): Unit {
        readable.close()
    }

    func abort(): Unit {
        readable.cancel()
    }
}
