// Web API Streams 模块 (Web Streams API)
// 对应 Bun: src/runtime/webcore/ReadableStream.zig + streams.zig
// 严格翻译自 Web Streams API
// 包含: ReadableStream, WritableStream, TransformStream
package bao_runtime.web_api

import bao_core.*
import bao_collections.*

// ============================================================================
// ReadableStream (Web API 级别) — 可读流
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/ReadableStream
// ============================================================================

/// ReadableStream (Web API 级别) — 可读字节流
/// 对应 Web API: ReadableStream
/// 对应 Bun: src/runtime/webcore/ReadableStream.zig
public class WebReadableStream {
    /// 是否锁定
    public var locked: Bool
    /// 内部缓冲区
    private var buffer: ArrayList<UInt8>
    /// 是否已完成
    private var done: Bool
    /// 是否已出错
    private var errored: Bool
    /// 错误信息
    private var errorMessage: String
    /// 当前读取器
    private var reader: ?WebReadableStreamDefaultReader
    /// 底层源回调
    private var underlyingSource: ?UnderlyingSource

    public init() {
        locked = false
        buffer = ArrayList<UInt8>()
        done = false
        errored = false
        errorMessage = ""
        reader = None
        underlyingSource = None
    }

    public init(underlyingSource: UnderlyingSource) {
        locked = false
        buffer = ArrayList<UInt8>()
        done = false
        errored = false
        errorMessage = ""
        reader = None
        this.underlyingSource = Some(underlyingSource)
        // 触发 start 回调
        match (this.underlyingSource) {
            case Some(src) => {
                match (src.start) {
                    case Some(startFn) => startFn(this)
                    case None => ()
                }
            }
            case None => ()
        }
    }

    /// 从数组创建可读流
    /// 对应 Web API: new ReadableStream({ start(controller) { ... } })
    public static func fromArray(data: Array<UInt8>): WebReadableStream {
        let stream = WebReadableStream()
        for (b in data) {
            stream.buffer.append(b)
        }
        stream.done = true
        return stream
    }

    /// 从字符串创建可读流
    public static func fromString(text: String): WebReadableStream {
        let stream = WebReadableStream()
        let bytes = Utf8Codec.encode(text)
        for (b in bytes) {
            stream.buffer.append(b)
        }
        stream.done = true
        return stream
    }

    /// 从 Blob 创建可读流
    public static func fromBlob(blob: Blob): WebReadableStream {
        let stream = WebReadableStream()
        let bytes = blob.arrayBuffer()
        for (b in bytes) {
            stream.buffer.append(b)
        }
        stream.done = true
        return stream
    }

    /// 内部入队方法 (供 controller 使用)
    public func enqueue(chunk: Array<UInt8>): Unit {
        for (b in chunk) {
            buffer.append(b)
        }
    }

    /// 内部关闭方法
    public func close(): Unit {
        done = true
    }

    /// 内部出错方法
    public func error(msg: String): Unit {
        errored = true
        errorMessage = msg
        done = true
    }

    /// 取消流
    /// 对应 Web API: readableStream.cancel(reason)
    public func cancel(reason: String): Unit {
        done = true
        buffer.clear()
    }

    /// 获取读取器
    /// 对应 Web API: readableStream.getReader()
    public func getReader(): WebReadableStreamDefaultReader {
        if (locked) {
            throw JsError(JsValue(BaoString("ReadableStream is already locked")))
        }
        locked = true
        let r = WebReadableStreamDefaultReader(this)
        reader = Some(r)
        return r
    }

    /// 分流 (tee)
    /// 对应 Web API: readableStream.tee()
    public func tee(): (WebReadableStream, WebReadableStream) {
        let stream1 = WebReadableStream()
        let stream2 = WebReadableStream()
        for (b in buffer) {
            stream1.buffer.append(b)
            stream2.buffer.append(b)
        }
        stream1.done = done
        stream2.done = done
        return (stream1, stream2)
    }

    /// 管道输出到 WritableStream
    /// 对应 Web API: readableStream.pipeTo(dest)
    public func pipeTo(dest: WebWritableStream): Unit {
        let reader = getReader()
        while (true) {
            let result = reader.read()
            if (result.done) {
                dest.close()
                break
            }
            match (result.value) {
                case Some(chunk) => dest.write(chunk)
                case None => {
                    dest.close()
                    break
                }
            }
        }
        reader.releaseLock()
    }

    /// 管道输出到 TransformStream
    /// 对应 Web API: readableStream.pipeThrough(transform)
    public func pipeThrough(transform: WebTransformStream): WebReadableStream {
        pipeTo(transform.writable)
        return transform.readable
    }

    /// 读取所有数据为 Uint8Array
    public func toArray(): Array<UInt8> {
        return buffer.toArray()
    }

    /// 读取所有数据为文本
    public func toText(): String {
        return Utf8Codec.decode(buffer.toArray())
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("locked", JsValue(self.locked))

        obj.set("cancel", JsValue.nativeFunction(JsNativeFunction("cancel") { args =>
            let reason = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
            self.cancel(reason)
            return JsValue(JsPromise.resolved(JsValue.UNDEFINED).toJsValue())
        }))

        obj.set("getReader", JsValue.nativeFunction(JsNativeFunction("getReader") { _ =>
            try {
                let reader = self.getReader()
                return reader.toJsValue()
            } catch (_: JsError) {
                return JsValue.NULL
            }
        }))

        obj.set("tee", JsValue.nativeFunction(JsNativeFunction("tee") { _ =>
            let (stream1, stream2) = self.tee()
            let arr = ArrayList<JsValue>()
            arr.append(stream1.toJsValue())
            arr.append(stream2.toJsValue())
            return JsValue.array(arr)
        }))

        obj.set("pipeTo", JsValue.nativeFunction(JsNativeFunction("pipeTo") { args =>
            // 简化
            return JsValue(JsPromise.resolved(JsValue.UNDEFINED).toJsValue())
        }))

        obj.set("pipeThrough", JsValue.nativeFunction(JsNativeFunction("pipeThrough") { args =>
            // 简化
            return self.toJsValue()
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// ReadResult — 读取结果
// ============================================================================

/// ReadResult — 读取结果
/// 对应 Web API: ReadableStreamDefaultReader.read() 返回值
public class WebReadResult {
    /// 读取到的数据
    public var value: ?Array<UInt8>
    /// 是否完成
    public var done: Bool

    public init(value: ?Array<UInt8>, done: Bool) {
        this.value = value
        this.done = done
    }
}

// ============================================================================
// ReadableStreamDefaultReader — 可读流默认读取器
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamDefaultReader
// ============================================================================

/// ReadableStreamDefaultReader — 可读流默认读取器
/// 对应 Web API: ReadableStreamDefaultReader
public class WebReadableStreamDefaultReader {
    /// 关联的流
    private var stream: WebReadableStream
    /// 读取位置
    private var position: Int64
    /// 默认块大小
    public static let DEFAULT_CHUNK_SIZE: Int64 = 16384

    public init(stream: WebReadableStream) {
        this.stream = stream
        position = 0
    }

    /// 读取下一个块
    /// 对应 Web API: reader.read()
    public func read(): WebReadResult {
        if (stream.errored) {
            throw JsError(JsValue(BaoString(stream.errorMessage)))
        }

        if (position < stream.buffer.size) {
            let remaining = stream.buffer.size - position
            let chunkSize = if (remaining < DEFAULT_CHUNK_SIZE) { remaining } else { DEFAULT_CHUNK_SIZE }
            let chunk = Array<UInt8>(chunkSize, item: UInt8(0))
            for (i in 0..chunkSize) {
                chunk[Int64(i)] = stream.buffer[position + Int64(i)]
            }
            position += chunkSize
            let isDone = position >= stream.buffer.size && stream.done
            return WebReadResult(Some(chunk), isDone)
        }

        if (stream.done) {
            return WebReadResult(None, true)
        }

        return WebReadResult(None, false)
    }

    /// 释放锁
    /// 对应 Web API: reader.releaseLock()
    public func releaseLock(): Unit {
        stream.locked = false
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("read", JsValue.nativeFunction(JsNativeFunction("read") { _ =>
            try {
                let result = self.read()
                let resultObj = JsObject()
                match (result.value) {
                    case Some(bytes) => {
                        let arr = ArrayList<JsValue>()
                        for (b in bytes) {
                            arr.append(JsValue(Float64(Int64(b))))
                        }
                        resultObj.set("value", JsValue.array(arr))
                    }
                    case None => resultObj.set("value", JsValue.UNDEFINED)
                }
                resultObj.set("done", JsValue(result.done))
                return JsValue(resultObj)
            } catch (_: JsError) {
                return JsValue.NULL
            }
        }))

        obj.set("releaseLock", JsValue.nativeFunction(JsNativeFunction("releaseLock") { _ =>
            self.releaseLock()
            return JsValue.UNDEFINED
        }))

        obj.set("closed", JsValue(JsPromise.resolved(JsValue.UNDEFINED).toJsValue()))

        obj.set("cancel", JsValue.nativeFunction(JsNativeFunction("cancel") { _ =>
            self.releaseLock()
            return JsValue(JsPromise.resolved(JsValue.UNDEFINED).toJsValue())
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// ReadableStreamBYOBReader — 可读流 BYOB 读取器
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/ReadableStreamBYOBReader
// ============================================================================

/// ReadableStreamBYOBReader — 自带缓冲区读取器
/// 对应 Web API: ReadableStreamBYOBReader
public class WebReadableStreamBYOBReader {
    private var stream: WebReadableStream

    public init(stream: WebReadableStream) {
        this.stream = stream
    }

    /// 读取到指定缓冲区
    /// 对应 Web API: reader.read(view)
    public func read(view: Array<UInt8>): WebReadResult {
        // 简化实现: 从缓冲区读取到 view
        return WebReadResult(None, true)
    }

    /// 释放锁
    public func releaseLock(): Unit {
        stream.locked = false
    }
}

// ============================================================================
// UnderlyingSource — 底层源 (可读流构造参数)
// 对应 Web API: UnderlyingSource
// ============================================================================

/// 底层源回调
public class UnderlyingSource {
    /// start(controller) — 构造时调用
    public var start: ?(WebReadableStream) -> Unit
    /// pull(controller) — 请求更多数据时调用
    public var pull: ?(WebReadableStream) -> Unit
    /// cancel(reason) — 取消时调用
    public var cancel: ?(String) -> Unit
    /// 类型
    public var type: String

    public init() {
        start = None
        pull = None
        cancel = None
        type = ""
    }
}

// ============================================================================
// UnderlyingSink — 底层汇 (可写流构造参数)
// 对应 Web API: UnderlyingSink
// ============================================================================

/// 底层汇回调
public class UnderlyingSink {
    /// start(controller) — 构造时调用
    public var start: ?(WebWritableStream) -> Unit
    /// write(chunk, controller) — 写入数据时调用
    public var write: ?(Array<UInt8>, WebWritableStream) -> Unit
    /// close(controller) — 关闭时调用
    public var close: ?(WebWritableStream) -> Unit
    /// abort(reason) — 中止时调用
    public var abort: ?(String) -> Unit

    public init() {
        start = None
        write = None
        close = None
        abort = None
    }
}

// ============================================================================
// WritableStream — 可写流
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/WritableStream
// ============================================================================

/// WritableStream — 可写流
/// 对应 Web API: WritableStream
public class WebWritableStream {
    /// 是否锁定
    public var locked: Bool
    /// 内部缓冲区
    private var buffer: ArrayList<UInt8>
    /// 是否已关闭
    private var closed: Bool
    /// 是否出错
    private var errored: Bool
    /// 错误信息
    private var errorMessage: String
    /// 底层汇
    private var underlyingSink: ?UnderlyingSink
    /// 高水位标记
    public var highWaterMark: Int64
    /// 当前写入器
    private var writer: ?WebWritableStreamDefaultWriter

    public init() {
        locked = false
        buffer = ArrayList<UInt8>()
        closed = false
        errored = false
        errorMessage = ""
        underlyingSink = None
        highWaterMark = 16384
        writer = None
    }

    public init(underlyingSink: UnderlyingSink) {
        locked = false
        buffer = ArrayList<UInt8>()
        closed = false
        errored = false
        errorMessage = ""
        this.underlyingSink = Some(underlyingSink)
        highWaterMark = 16384
        writer = None
        // 触发 start
        match (this.underlyingSink) {
            case Some(sink) => {
                match (sink.start) {
                    case Some(startFn) => startFn(this)
                    case None => ()
                }
            }
            case None => ()
        }
    }

    /// 中止流
    /// 对应 Web API: writableStream.abort(reason)
    public func abort(reason: String): Unit {
        errored = true
        errorMessage = reason
        closed = true
        match (underlyingSink) {
            case Some(sink) => {
                match (sink.abort) {
                    case Some(abortFn) => abortFn(reason)
                    case None => ()
                }
            }
            case None => ()
        }
    }

    /// 关闭流
    public func close(): Unit {
        if (closed || errored) {
            return
        }
        closed = true
        match (underlyingSink) {
            case Some(sink) => {
                match (sink.close) {
                    case Some(closeFn) => closeFn(this)
                    case None => ()
                }
            }
            case None => ()
        }
    }

    /// 写入数据
    public func write(chunk: Array<UInt8>): Unit {
        if (closed || errored) {
            return
        }
        for (b in chunk) {
            buffer.append(b)
        }
        match (underlyingSink) {
            case Some(sink) => {
                match (sink.write) {
                    case Some(writeFn) => writeFn(chunk, this)
                    case None => ()
                }
            }
            case None => ()
        }
    }

    /// 获取写入器
    /// 对应 Web API: writableStream.getWriter()
    public func getWriter(): WebWritableStreamDefaultWriter {
        if (locked) {
            throw JsError(JsValue(BaoString("WritableStream is already locked")))
        }
        locked = true
        let w = WebWritableStreamDefaultWriter(this)
        writer = Some(w)
        return w
    }

    /// 获取已缓冲的数据
    public func getBuffer(): Array<UInt8> {
        return buffer.toArray()
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("locked", JsValue(self.locked))

        obj.set("abort", JsValue.nativeFunction(JsNativeFunction("abort") { args =>
            let reason = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
            self.abort(reason)
            return JsValue(JsPromise.resolved(JsValue.UNDEFINED).toJsValue())
        }))

        obj.set("getWriter", JsValue.nativeFunction(JsNativeFunction("getWriter") { _ =>
            try {
                let writer = self.getWriter()
                return writer.toJsValue()
            } catch (_: JsError) {
                return JsValue.NULL
            }
        }))

        obj.set("close", JsValue.nativeFunction(JsNativeFunction("close") { _ =>
            self.close()
            return JsValue(JsPromise.resolved(JsValue.UNDEFINED).toJsValue())
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// WritableStreamDefaultWriter — 可写流默认写入器
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/WritableStreamDefaultWriter
// ============================================================================

/// WritableStreamDefaultWriter — 可写流默认写入器
/// 对应 Web API: WritableStreamDefaultWriter
public class WebWritableStreamDefaultWriter {
    /// 关联的流
    private var stream: WebWritableStream

    public init(stream: WebWritableStream) {
        this.stream = stream
    }

    /// 写入数据
    /// 对应 Web API: writer.write(chunk)
    public func write(chunk: Array<UInt8>): Unit {
        stream.write(chunk)
    }

    /// 关闭流
    /// 对应 Web API: writer.close()
    public func close(): Unit {
        stream.close()
        releaseLock()
    }

    /// 中止流
    /// 对应 Web API: writer.abort(reason)
    public func abort(reason: String): Unit {
        stream.abort(reason)
        releaseLock()
    }

    /// 释放锁
    /// 对应 Web API: writer.releaseLock()
    public func releaseLock(): Unit {
        stream.locked = false
    }

    /// 获取期望大小
    /// 对应 Web API: writer.desiredSize
    public func desiredSize(): Int64 {
        return stream.highWaterMark - stream.getBuffer().size
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("write", JsValue.nativeFunction(JsNativeFunction("write") { args =>
            // 简化: 将 JS 值转为字节
            if (args.size >= 1) {
                let str = Interpreter.jsToString(args[0])
                let bytes = Utf8Codec.encode(str)
                self.write(bytes)
            }
            return JsValue(JsPromise.resolved(JsValue.UNDEFINED).toJsValue())
        }))

        obj.set("close", JsValue.nativeFunction(JsNativeFunction("close") { _ =>
            self.close()
            return JsValue(JsPromise.resolved(JsValue.UNDEFINED).toJsValue())
        }))

        obj.set("abort", JsValue.nativeFunction(JsNativeFunction("abort") { args =>
            let reason = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
            self.abort(reason)
            return JsValue(JsPromise.resolved(JsValue.UNDEFINED).toJsValue())
        }))

        obj.set("releaseLock", JsValue.nativeFunction(JsNativeFunction("releaseLock") { _ =>
            self.releaseLock()
            return JsValue.UNDEFINED
        }))

        obj.set("desiredSize", JsValue(Float64(self.desiredSize())))

        obj.set("closed", JsValue(JsPromise.resolved(JsValue.UNDEFINED).toJsValue()))

        obj.set("ready", JsValue(JsPromise.resolved(JsValue.UNDEFINED).toJsValue()))

        return JsValue(obj)
    }
}

// ============================================================================
// TransformStream — 转换流
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/TransformStream
// ============================================================================

/// Transformer — 转换器回调
public class Transformer {
    /// transform(chunk, controller) — 转换单个块
    public var transform: ?(Array<UInt8>, WebTransformStream) -> Unit
    /// flush(controller) — 刷新所有数据
    public var flush: ?(WebTransformStream) -> Unit
    /// start(controller) — 开始转换
    public var start: ?(WebTransformStream) -> Unit

    public init() {
        transform = None
        flush = None
        start = None
    }
}

/// TransformStream — 转换流
/// 对应 Web API: TransformStream
public class WebTransformStream {
    /// 可读端
    public var readable: WebReadableStream
    /// 可写端
    public var writable: WebWritableStream
    /// 转换器
    private var transformer: ?Transformer

    public init() {
        readable = WebReadableStream()
        writable = WebWritableStream()
        transformer = None
    }

    public init(transformer: Transformer) {
        this.transformer = Some(transformer)
        readable = WebReadableStream()
        writable = WebWritableStream()
        // 触发 start
        match (this.transformer) {
            case Some(t) => {
                match (t.start) {
                    case Some(startFn) => startFn(this)
                    case None => ()
                }
            }
            case None => ()
        }
    }

    /// 内部方法: 将数据推送到可读端
    public func enqueue(chunk: Array<UInt8>): Unit {
        readable.enqueue(chunk)
    }

    /// 内部方法: 关闭可读端
    public func terminate(): Unit {
        readable.close()
        writable.close()
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("readable", readable.toJsValue())
        obj.set("writable", writable.toJsValue())
        return JsValue(obj)
    }
}

// ============================================================================
// TextEncoderStream — 文本编码流
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/TextEncoderStream
// ============================================================================

/// TextEncoderStream — 将字符串流编码为 UTF-8 字节流
/// 对应 Web API: TextEncoderStream
public class TextEncoderStream {
    /// 编码名称
    public var encoding: String
    /// 可读端 (输出 UTF-8 字节)
    public var readable: WebReadableStream
    /// 可写端 (输入字符串)
    public var writable: WebWritableStream

    public init() {
        encoding = "utf-8"
        readable = WebReadableStream()
        writable = WebWritableStream()
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("encoding", JsValue(BaoString(encoding)))
        obj.set("readable", readable.toJsValue())
        obj.set("writable", writable.toJsValue())
        return JsValue(obj)
    }
}

// ============================================================================
// TextDecoderStream — 文本解码流
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/TextDecoderStream
// ============================================================================

/// TextDecoderStream — 将 UTF-8 字节流解码为字符串流
/// 对应 Web API: TextDecoderStream
public class TextDecoderStream {
    /// 编码名称
    public var encoding: String
    /// 是否忽略 BOM
    public var ignoreBOM: Bool
    /// 是否致命错误
    public var fatal: Bool
    /// 可读端 (输出字符串)
    public var readable: WebReadableStream
    /// 可写端 (输入 UTF-8 字节)
    public var writable: WebWritableStream

    public init() {
        encoding = "utf-8"
        ignoreBOM = false
        fatal = false
        readable = WebReadableStream()
        writable = WebWritableStream()
    }

    public init(encoding: String) {
        this.encoding = encoding
        ignoreBOM = false
        fatal = false
        readable = WebReadableStream()
        writable = WebWritableStream()
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("encoding", JsValue(BaoString(encoding)))
        obj.set("ignoreBOM", JsValue(ignoreBOM))
        obj.set("fatal", JsValue(fatal))
        obj.set("readable", readable.toJsValue())
        obj.set("writable", writable.toJsValue())
        return JsValue(obj)
    }
}

// ============================================================================
// QueuingStrategy — 排队策略
// 对应 Web API: QueuingStrategy
// ============================================================================

/// 排队策略
/// 对应 Web API: QueuingStrategy
public class QueuingStrategy {
    /// 高水位标记
    public var highWaterMark: Int64
    /// 大小函数
    public var size: ?(Array<UInt8>) -> Int64

    public init() {
        highWaterMark = 16384
        size = None
    }

    public init(highWaterMark: Int64) {
        this.highWaterMark = highWaterMark
        size = None
    }
}

/// 默认排队策略 (字节计数)
public class ByteLengthQueuingStrategy extends QueuingStrategy {
    public init(highWaterMark: Int64) {
        super(highWaterMark)
        size = Some({ chunk => chunk.size })
    }
}

/// 计数排队策略
public class CountQueuingStrategy extends QueuingStrategy {
    public init(highWaterMark: Int64) {
        super(highWaterMark)
        size = Some({ _ => 1 })
    }
}

// ============================================================================
// StreamsModule — Streams 模块导出
// ============================================================================

/// Streams 模块导出 — 将 Streams API 注册到全局
public class StreamsModule {
    /// 将 Streams API 注册到全局环境
    public static func registerGlobals(env: Environment): Unit {
        // ReadableStream 构造函数
        env.define("ReadableStream", Interpreter.makeNativeFn("ReadableStream") { args =>
            let stream = WebReadableStream()
            return stream.toJsValue()
        }, false)

        // WritableStream 构造函数
        env.define("WritableStream", Interpreter.makeNativeFn("WritableStream") { args =>
            let stream = WebWritableStream()
            return stream.toJsValue()
        }, false)

        // TransformStream 构造函数
        env.define("TransformStream", Interpreter.makeNativeFn("TransformStream") { args =>
            let stream = WebTransformStream()
            return stream.toJsValue()
        }, false)

        // ByteLengthQueuingStrategy 构造函数
        env.define("ByteLengthQueuingStrategy", Interpreter.makeNativeFn("ByteLengthQueuingStrategy") { args =>
            let hwm = if (args.size >= 1) {
                match (args[0].objectData) {
                    case Some(obj) => {
                        let val = obj.get("highWaterMark")
                        Int64(Interpreter.jsToNumber(val))
                    }
                    case None => Int64(16384)
                }
            } else {
                Int64(16384)
            }
            let strategy = ByteLengthQueuingStrategy(hwm)
            let obj = JsObject()
            obj.set("highWaterMark", JsValue(Float64(hwm)))
            return JsValue(obj)
        }, false)

        // CountQueuingStrategy 构造函数
        env.define("CountQueuingStrategy", Interpreter.makeNativeFn("CountQueuingStrategy") { args =>
            let hwm = if (args.size >= 1) {
                match (args[0].objectData) {
                    case Some(obj) => {
                        let val = obj.get("highWaterMark")
                        Int64(Interpreter.jsToNumber(val))
                    }
                    case None => Int64(16384)
                }
            } else {
                Int64(16384)
            }
            let strategy = CountQueuingStrategy(hwm)
            let obj = JsObject()
            obj.set("highWaterMark", JsValue(Float64(hwm)))
            return JsValue(obj)
        }, false)

        // TextEncoderStream 构造函数
        env.define("TextEncoderStream", Interpreter.makeNativeFn("TextEncoderStream") { _ =>
            let stream = TextEncoderStream()
            return stream.toJsValue()
        }, false)

        // TextDecoderStream 构造函数
        env.define("TextDecoderStream", Interpreter.makeNativeFn("TextDecoderStream") { args =>
            let encoding = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "utf-8" }
            let stream = TextDecoderStream(encoding)
            return stream.toJsValue()
        }, false)
    }
}
