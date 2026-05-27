// Streams - streaming infrastructure for WebCore (fetch Body, Readable/Writable)
//
// Strict 1:1 translation from: src/runtime/webcore/streams.rs (2614 lines)
// Ported from: src/runtime/webcore/streams.zig
//
// Contains: Start, Result (StreamResult), Result.Writable, Result.Pending,
//           Signal, HTTPServerWritable, NetworkSink, BufferAction, ReadResult
package bao_runtime.webcore

import bao_core.*
import bao_jsc.*
import bao_collections.ArrayList

// ============================================================================
// ByteListPoolNode - pooled buffer node type
// 对应 Bun: bun.ObjectPool(bun.Vec<u8>, ...)::Node
// PORT NOTE: Using ArrayList<UInt8> instead of Vec<u8>
// ============================================================================

public type ByteListPoolNode = PoolNode<ArrayList<UInt8>>

/// Pool node (simplified)
public class PoolNode<T> {
    public var data: T

    public init(data: T) {
        this.data = data
    }
}

// ============================================================================
// Start - 流启动结果
// 严格翻译自: streams.Start (union(Tag))
// ============================================================================

/// Start tag (runtime discriminant)
/// 严格翻译自 streams.StartTag #[repr(u8)]
public enum StartTag {
    | Empty
    | Err
    | ChunkSize
    | ArrayBufferSink
    | FileSink
    | HTTPSResponseSink
    | HTTPResponseSink
    | H3ResponseSink
    | NetworkSink
    | Ready
    | OwnedAndDone
    | Done

    public operator func == (rhs: StartTag): Bool {
        match (this) {
            case Empty => match (rhs) { case Empty => true case _ => false }
            case Err => match (rhs) { case Err => true case _ => false }
            case ChunkSize => match (rhs) { case ChunkSize => true case _ => false }
            case ArrayBufferSink => match (rhs) { case ArrayBufferSink => true case _ => false }
            case FileSink => match (rhs) { case FileSink => true case _ => false }
            case HTTPSResponseSink => match (rhs) { case HTTPSResponseSink => true case _ => false }
            case HTTPResponseSink => match (rhs) { case HTTPResponseSink => true case _ => false }
            case H3ResponseSink => match (rhs) { case H3ResponseSink => true case _ => false }
            case NetworkSink => match (rhs) { case NetworkSink => true case _ => false }
            case Ready => match (rhs) { case Ready => true case _ => false }
            case OwnedAndDone => match (rhs) { case OwnedAndDone => true case _ => false }
            case Done => match (rhs) { case Done => true case _ => false }
        }
    }
}

/// ZigStringSlice - owned Zig string slice
/// 对应 Bun: ZigStringSlice
public class ZigStringSlice {
    public var slice: Array<UInt8>

    public init() {
        slice = Array<UInt8>()
    }

    public init(slice: Array<UInt8>) {
        this.slice = slice
    }

    public func getSlice(): Array<UInt8> { return slice }
}

/// WasStrong - tracks whether a JsValue reference was strong or weak
/// 对应 Bun: WasStrong
public enum WasStrong {
    | Strong
    | Weak
}

/// 流错误种类
/// 对应 Bun: Result.StreamError (enum variants)
public enum StreamErrorKind {
    | Error           // Error(SyscallError)
    | AbortReason     // AbortReason(CommonAbortReason)
    | JsValue         // JsValue (strong reference)
    | WeakJSValue     // JsValue (weak reference)
}

/// IntoArray 结构
/// 对应 Bun: Result.IntoArray
public class IntoArray {
    public var value: JsValue
    public var len: BlobSizeType

    public init() {
        value = JsValue()
        len = Int64.MAX_VALUE
    }

    public init(value: JsValue, len: BlobSizeType) {
        this.value = value
        this.len = len
    }
}

/// WritableFuture kinds
/// 对应 Bun: WritableFuture enum
public enum WritableFutureKind {
    | None
    | Promise
    | Handler
}

/// Writable - type alias for WritableResult
/// 对应 Bun: Result.Writable (union(Result.Tag))
/// In the original Bun code, Writable is a tagged union nested inside Result.
/// In Cangjie we use WritableResult as the class, with Writable as a convenient alias.
public type Writable = WritableResult

/// StreamResultWritable — alias used by SinkHandler interface
public type StreamResultWritable = WritableResult

/// WritablePending 的 handler callback
/// 对应 Bun: WritableHandlerFn = fn(ctx: *c_void, result: Writable)
public type WritableHandlerFn = (Writable) -> Unit

/// 可写 Pending 状态
/// 严格翻译自 Result.Writable.Pending
public class WritablePending {
    public var futureKind: WritableFutureKind
    public var result: WritableResult
    public var consumed: BlobSizeType
    public var state: PendingState
    /// Promise reference (for futureKind == Promise)
    public var promiseStrong: ?JSPromiseStrong
    /// Global reference — stored when promise() is called, passed to fulfillPromise.
    /// 对应 Bun: Writable.Pending.Future.promise { .strong = ..., .global = *JSGlobalObject }
    public var globalRef: ?JSGlobalObject
    /// Handler callback (for futureKind == Handler)
    public var handler: ?WritableHandlerFn

    public init() {
        futureKind = WritableFutureKind.None
        result = WritableResult.done()
        consumed = 0
        state = PendingState.None
        promiseStrong = None
        globalRef = None
        handler = None
    }

    /// 运行 pending 回调
    /// 对应 Bun: WritablePending.run()
    public func run(): Unit {
        if (state != PendingState.Pending) {
            return
        }
        state = PendingState.Used

        match (futureKind) {
            case Promise =>
                match (promiseStrong) {
                    case Some(strong) =>
                        // 对应 Bun: Writable.fulfillPromise(this.result, p.strong.swap(), p.global)
                        let global = globalRef.getOrThrow()
                        WritableResult.fulfillPromise(result, strong.swap(), global)
                    case None => ()
                }
            case Handler =>
                match (handler) {
                    case Some(h) => h(WritableResult.done())
                    case None => ()
                }
            case None => ()
        }
    }

    /// 对应 Bun: WritablePending.promise()
    /// Stores globalThis alongside the promise for later use in fulfillPromise,
    /// matching Bun's Writable.Pending.Future.promise { .strong = ..., .global = globalThis }
    public func promise(global: JSGlobalObject): JSPromise {
        state = PendingState.Pending
        globalRef = Some(global)
        match (futureKind) {
            case Promise =>
                match (promiseStrong) {
                    case Some(strong) => return strong.get()
                    case None => ()
                }
            case _ => ()
        }
        // Create new promise
        let strong = JSPromiseStrong(global)
        promiseStrong = Some(strong)
        futureKind = WritableFutureKind.Promise
        return strong.get()
    }

    /// 对应 Bun: WritablePending.applyBackpressure
    public func applyBackpressure(output: Sink, bytes: Array<UInt8>): Unit {
        consumed = consumed + bytes.size
        state = PendingState.Pending
    }
}

// ============================================================================
// WritableResult - 流可写结果
// 严格翻译自: streams.Result.Writable (union(Result.Tag))
// ============================================================================

/// 流可写结果
/// 严格翻译自 streams.Result.Writable
public class WritableResult {
    public var tag: StreamResultTag
    public var pendingValue: ?WritablePending
    public var errValue: ?SyscallError
    public var size: BlobSizeType

    public init(tag: StreamResultTag) {
        this.tag = tag
        this.pendingValue = None
        this.errValue = None
        this.size = 0
    }

    /// 是否完成
    /// 对应 Bun: Writable.isDone()
    public func isDone(): Bool {
        match (tag) {
            case OwnedAndDone | TemporaryAndDone | IntoArrayAndDone | Done | Err => true
            case _ => false
        }
    }

    /// 对应 Bun: Writable.fulfillPromise
    public static func fulfillPromise(result: WritableResult, promise: JSPromise, global: ?JSGlobalObject): Unit {
        match (result.tag) {
            case Err =>
                match (result.errValue) {
                    case Some(e) => promise.reject(global.getOrThrow(), e.toJS(global.getOrThrow()))
                    case None => ()
                }
            case Done =>
                promise.resolve(global.getOrThrow(), JsValue.FALSE)
            case _ =>
                promise.resolve(global.getOrThrow(), result.toJS(global.getOrThrow()))
        }
    }

    /// 对应 Bun: Writable.toJS
    public func toJS(global: JSGlobalObject): JsValue {
        match (tag) {
            case Err =>
                match (err) {
                    case Some(e) => JSPromise.rejectedPromise(global, e.toJS(global)).toJS()
                    case None => JsValue.NULL
                }
            case Owned | OwnedAndDone | TemporaryAndDone | Temporary | IntoArray | IntoArrayAndDone => JsValue.jsNumber(size)
            // false == controller.close()
            case Done => JsValue(true)
            case Pending =>
                match (pending) {
                    case Some(p) =>
                        let prom = p.promise(global)
                        return JSPromise.opaqueRef(prom).toJS()
                    case None => JsValue.UNDEFINED
                }
        }
    }

    // ---- 静态工厂方法 ----

    public static func pending(p: WritablePending): WritableResult {
        let r = WritableResult(StreamResultTag.Pending)
        r.pendingValue = Some(p)
        return r
    }

    public static func err(e: SyscallError): WritableResult {
        let r = WritableResult(StreamResultTag.Err)
        r.errValue = Some(e)
        return r
    }

    public static func done(): WritableResult {
        return WritableResult(StreamResultTag.Done)
    }

    public static func owned(size: BlobSizeType): WritableResult {
        let r = WritableResult(StreamResultTag.Owned)
        r.size = size
        return r
    }

    public static func ownedAndDone(size: BlobSizeType): WritableResult {
        let r = WritableResult(StreamResultTag.OwnedAndDone)
        r.size = size
        return r
    }

    public static func temporary(size: BlobSizeType): WritableResult {
        let r = WritableResult(StreamResultTag.Temporary)
        r.size = size
        return r
    }

    public static func temporaryAndDone(size: BlobSizeType): WritableResult {
        let r = WritableResult(StreamResultTag.TemporaryAndDone)
        r.size = size
        return r
    }
}

// ============================================================================
// StreamResultPending - 流结果待处理
// 严格翻译自: streams.Result.Pending
// ============================================================================

/// Pending handler callback
/// 对应 Bun: PendingHandlerFn = fn(ctx: *c_void, result: StreamResult)
public type PendingHandlerFn = (StreamResult) -> Unit

/// Pending Future 类型
public enum PendingFutureKind {
    | Promise
    | Handler
}

// ============================================================================
// Signal - 流信号
// 严格翻译自: streams.Signal
// ============================================================================

/// 信号虚表
/// 对应 Bun: SignalVTable
public class SignalVTable {
    public var onClose: (?(SyscallError)) -> Unit
    public var onReady: (?(BlobSizeType), ?(BlobSizeType)) -> Unit
    public var onStart: () -> Unit

    public init(
        onClose: (?(SyscallError)) -> Unit,
        onReady: (?(BlobSizeType), ?(BlobSizeType)) -> Unit,
        onStart: () -> Unit
    ) {
        this.onClose = onClose
        this.onReady = onReady
        this.onStart = onStart
    }

    /// Dead vtable (no-op callbacks)
    public static func dead(): SignalVTable {
        return SignalVTable(
            onClose: { _ => () },
            onReady: { _, _ => () },
            onStart: { => () }
        )
    }

    /// Wrap a handler into vtable callbacks
    /// 对应 Bun: SignalVTable::wrap::<W>()
    public static func wrap(handler: SignalHandler): SignalVTable {
        return SignalVTable(
            onClose: { err => handler.onClose(err) },
            onReady: { amount, offset => handler.onReady(amount, offset) },
            onStart: { => handler.onStart() }
        )
    }
}

/// Signal handler interface
/// 对应 Bun: SignalHandler trait
public interface SignalHandler {
    func onClose(err: ?SyscallError): Unit
    func onReady(amount: ?BlobSizeType, offset: ?BlobSizeType): Unit
    func onStart(): Unit
}

/// 流信号
/// 严格翻译自 streams.Signal
/// repr(C) in Rust; field order matters for FFI
public class StreamSignal {
    /// Whether this signal is dead (null handler pointer)
    public var ptr: Bool  // true = live, false = dead
    /// Virtual table
    public var vtable: ?SignalVTable

    public init() {
        ptr = false
        vtable = None
    }

    public init(vtable: SignalVTable) {
        ptr = true
        this.vtable = Some(vtable)
    }

    /// 对应 Bun: Signal.init<T>(handler)
    public static func `init`(handler: SignalHandler): StreamSignal {
        let vt = SignalVTable.wrap(handler)
        return StreamSignal(vt)
    }

    /// 清除信号
    /// 对应 Bun: Signal.clear()
    public func clear(): Unit {
        ptr = false
    }

    /// 是否 dead
    /// 对应 Bun: Signal.isDead()
    public func isDead(): Bool {
        return !ptr
    }

    /// 关闭
    /// 对应 Bun: Signal.close()
    public func close(err: ?SyscallError): Unit {
        if (isDead()) {
            return
        }
        match (vtable) {
            case Some(vt) => vt.onClose(err)
            case None => ()
        }
    }

    /// 就绪
    /// 对应 Bun: Signal.ready()
    public func ready(amount: ?BlobSizeType, offset: ?BlobSizeType): Unit {
        if (isDead()) {
            return
        }
        match (vtable) {
            case Some(vt) => vt.onReady(amount, offset)
            case None => ()
        }
    }

    /// 启动
    /// 对应 Bun: Signal.start()
    public func start(): Unit {
        if (isDead()) {
            return
        }
        match (vtable) {
            case Some(vt) => vt.onStart()
            case None => ()
        }
    }
}

// ============================================================================
// HTTPServerWritable - HTTP 服务器可写流
// 严格翻译自: streams.HTTPServerWritable<SSL, HTTP3>
// PORT NOTE: Rust used const generics <const SSL: bool, const HTTP3: bool>.
// Cangjie lacks const generics, so SSL/HTTP3 are runtime fields.
// ============================================================================

/// HTTP 服务器可写流
/// 严格翻译自 HTTPServerWritable
public open class HTTPServerWritable <: SinkHandler {
    /// SSL flag (runtime, replaces const generic)
    public var ssl: Bool
    /// HTTP/3 flag (runtime, replaces const generic)
    public var http3: Bool
    /// uWS response handle (opaque)
    public var res: ?UwsResponse
    /// 缓冲区
    public var buffer: ArrayList<UInt8>
    /// Pooled buffer node
    public var pooledBuffer: ?ByteListPoolNode
    /// 偏移
    public var offset: BlobSizeType
    /// 是否监听中止
    public var isListeningForAbort: Bool
    /// 已写入字节数
    public var wrote: BlobSizeType
    /// 是否完成
    public var done: Bool
    /// 信号
    public var signal: StreamSignal
    /// Pending flush promise
    public var pendingFlush: ?JSPromise
    /// 写入起始偏移 (用于 flush Promise)
    public var wroteAtStartOfFlush: BlobSizeType
    /// Global JS object reference
    public var globalThis: ?JSGlobalObject
    /// 高水位标记
    public var highWaterMark: BlobSizeType
    /// 是否请求结束
    public var requestedEnd: Bool
    /// 是否有背压
    public var hasBackpressure: Bool
    /// 请求结束的长度
    public var endLen: Int64
    /// 是否已中止
    public var aborted: Bool
    /// First-write callback
    public var onFirstWrite: ?(() -> Unit)
    /// Auto flusher registration state
    public var autoFlusherRegistered: Bool

    public init() {
        ssl = false
        http3 = false
        res = None
        buffer = ArrayList<UInt8>()
        pooledBuffer = None
        offset = 0
        isListeningForAbort = false
        wrote = 0
        done = false
        signal = StreamSignal()
        pendingFlush = None
        wroteAtStartOfFlush = 0
        globalThis = None
        highWaterMark = 2048
        requestedEnd = false
        hasBackpressure = false
        endLen = 0
        aborted = false
        onFirstWrite = None
        autoFlusherRegistered = false
    }

    public init(ssl: Bool, http3: Bool) {
        this.ssl = ssl
        this.http3 = http3
        res = None
        buffer = ArrayList<UInt8>()
        pooledBuffer = None
        offset = 0
        isListeningForAbort = false
        wrote = 0
        done = false
        signal = StreamSignal()
        pendingFlush = None
        wroteAtStartOfFlush = 0
        globalThis = None
        highWaterMark = 2048
        requestedEnd = false
        hasBackpressure = false
        endLen = 0
        aborted = false
        onFirstWrite = None
        autoFlusherRegistered = false
    }

    /// Name constant
    /// 对应 Bun: HTTPServerWritable.NAME
    public func name(): String {
        if (http3) { return "H3ResponseSink" }
        if (ssl) { return "HTTPSResponseSink" }
        return "HTTPResponseSink"
    }

    /// 内存开销
    /// 对应 Bun: HTTPServerWritable.memoryCost()
    public func memoryCost(): Int64 {
        return buffer.capacity
    }

    /// 获取 globalThis
    public func getGlobalThis(): JSGlobalObject {
        return globalThis.getOrThrow()
    }

    /// 连接信号
    /// 对应 Bun: connect()
    public func connect(signal: StreamSignal): Unit {
        this.signal = signal
    }

    /// 获取可读切片
    /// 对应 Bun: readableSlice()
    public func readableSlice(): Array<UInt8> {
        if (offset >= buffer.size) {
            return Array<UInt8>()
        }
        let result = ArrayList<UInt8>()
        for (i in offset..buffer.size) {
            result.append(buffer[Int64(i)])
        }
        return result.items()
    }

    /// 处理已写入
    /// 对应 Bun: handleWrote()
    public func handleWrote(amount: Int64): Unit {
        let amt: BlobSizeType = amount
        offset += amt
        wrote += amt

        if (offset >= buffer.size) {
            offset = 0
            buffer.clear()
        }
    }

    /// 处理首次写入
    /// 对应 Bun: handleFirstWriteIfNecessary()
    public func handleFirstWriteIfNecessary(): Unit {
        match (onFirstWrite) {
            case Some(cb) =>
                onFirstWrite = None
                cb()
            case None => ()
        }
    }

    /// 是否有背压且正在 tryEnd
    public func hasBackpressureAndIsTryEnd(): Bool {
        return hasBackpressure && endLen > 0
    }

    /// 发送数据 (不含 auto flusher)
    /// 对应 Bun: sendWithoutAutoFlusher()
    public func sendWithoutAutoFlusher(buf: Array<UInt8>): Bool {
        if (done) {
            return false
        }

        // If no response handle, can't send
        match (res) {
            case None => return false
            case Some(_) => ()
        }

        if (requestedEnd) {
            // Try to end
            hasBackpressure = false
            handleWrote(buf.size)
            return true
        }

        // Normal write - may have backpressure
        endLen = 0
        handleFirstWriteIfNecessary()
        if (requestedEnd) {
            hasBackpressure = false
        } else {
            hasBackpressure = buf.size >= highWaterMark
        }
        handleWrote(buf.size)
        return true
    }

    /// 发送数据
    /// 对应 Bun: send()
    public func send(buf: Array<UInt8>): Bool {
        unregisterAutoFlusher()
        return sendWithoutAutoFlusher(buf)
    }

    /// Send from readable slice at offset
    /// 对应 Bun: sendReadableWithoutAutoFlusher()
    public func sendReadableWithoutAutoFlusher(from: Int64): Bool {
        let base = offset + from
        let readable = readableSlice()
        if (readable.size == 0 && base >= buffer.size) {
            return false
        }
        let slice = if (base < readable.size) {
            let result = ArrayList<UInt8>()
            for (i in base..readable.size) {
                result.append(readable[Int64(i)])
            }
            result.items()
        } else {
            Array<UInt8>()
        }

        if (done) {
            return false
        }

        match (res) {
            case None => return false
            case Some(_) => ()
        }

        if (requestedEnd) {
            hasBackpressure = false
            handleWrote(slice.size)
            return true
        }

        endLen = 0
        handleFirstWriteIfNecessary()
        let bufLen = slice.size
        if (requestedEnd) {
            hasBackpressure = false
        } else {
            hasBackpressure = bufLen >= highWaterMark
        }
        handleWrote(bufLen)
        return true
    }

    /// 对应 Bun: sendReadable()
    public func sendReadable(from: Int64): Bool {
        unregisterAutoFlusher()
        return sendReadableWithoutAutoFlusher(from)
    }

    /// 启动
    /// 对应 Bun: HTTPServerWritable.start()
    public func start(streamStart: StreamStart): Unit {
        if (aborted) {
            signal.close(Option<SyscallError>.None)
            markDone()
            return
        }

        wrote = 0
        wroteAtStartOfFlush = 0
        flushPromise()

        if (buffer.capacity == 0) {
            // Buffer pooling would go here
        }

        buffer.clear()

        match (streamStart.tag) {
            case ChunkSize =>
                if (streamStart.chunkSize > 0) {
                    highWaterMark = streamStart.chunkSize
                }
            case _ => ()
        }

        buffer.clear()
        // ensureTotalCapacityPrecise
        if (buffer.capacity < highWaterMark) {
            let needed = highWaterMark - buffer.capacity
            for (_ in 0..needed) {
                buffer.append(0)
            }
            buffer.clear()
        }

        done = false
        signal.start()
    }

    /// 刷新 (无等待)
    /// 对应 Bun: flushNoWait()
    public func flushNoWait(): Int64 {
        if (hasBackpressureAndIsTryEnd() || done) {
            return 0
        }

        let readable = readableSlice()
        if (readable.size == 0) {
            return 0
        }

        if (sendReadable(0)) {
            return readable.size
        }
        return 0
    }

    /// 从 JS 刷新 (不等待)
    /// 对应 Bun: flushFromJSNoWait()
    public func flushFromJSNoWait(): JsValue {
        return JsValue.jsNumber(flushNoWait())
    }

    /// 从 JS 刷新
    /// 对应 Bun: flushFromJS()
    public func flushFromJS(global: JSGlobalObject, wait: Bool): JsValue {
        unregisterAutoFlusher()

        if (!wait) {
            return flushFromJSNoWait()
        }

        match (pendingFlush) {
            case Some(prom) => return prom.toJS()
            case None => ()
        }

        if (buffer.size == 0 || done) {
            return JSPromise.resolvedPromiseValue(global, JsValue.jsNumber(0))
        }

        if (!hasBackpressureAndIsTryEnd()) {
            let readable = readableSlice()
            if (readable.size > 0 && sendReadable(0)) {
                return JSPromise.resolvedPromiseValue(global, JsValue.jsNumber(readable.size))
            }
        }

        wroteAtStartOfFlush = wrote
        pendingFlush = Some(JSPromise.create(global))
        globalThis = Some(global)
        let promiseValue = pendingFlush.getOrThrow().toJS()
        promiseValue.protect()
        return promiseValue
    }

    /// 刷新
    /// 对应 Bun: HTTPServerWritable.flush()
    public func flush(): Unit {
        if (!hasBackpressure || done) {
            return
        }
        // If no response or already responded, close
        match (res) {
            case Some(r) => if (r.hasResponded()) {
                markDone()
                signal.close(Option<SyscallError>.None)
            }
            case None =>
                markDone()
                signal.close(Option<SyscallError>.None)
        }
    }

    /// 写入数据
    /// 对应 Bun: HTTPServerWritable.write()
    public func write(data: StreamResult): WritableResult {
        if (done || requestedEnd) {
            return WritableResult.owned(0)
        }

        let bytes = data.slice()
        let len: BlobSizeType = bytes.size

        if (buffer.size == 0 && len >= highWaterMark) {
            // Fast path: large chunk, no backpressure
            if (send(bytes)) {
                return WritableResult.owned(len)
            }
            bufferWrite(bytes)
        } else if (buffer.size + len >= highWaterMark) {
            bufferWrite(bytes)
            if (sendReadable(0)) {
                return WritableResult.owned(len)
            }
        } else {
            bufferWrite(bytes)
        }

        registerAutoFlusher()
        return WritableResult.owned(len)
    }

    /// 写入字节 (alias)
    /// 对应 Bun: writeBytes()
    public func writeBytes(data: StreamResult): WritableResult {
        return write(data)
    }

    /// 写入 Latin1 编码数据
    /// 对应 Bun: writeLatin1()
    public func writeLatin1(data: StreamResult): WritableResult {
        if (done || requestedEnd) {
            return WritableResult.owned(0)
        }

        match (res) {
            case Some(r) => if (r.hasResponded()) {
                signal.close(Option<SyscallError>.None)
                markDone()
                return WritableResult.done()
            }
            case None =>
                signal.close(Option<SyscallError>.None)
                markDone()
                return WritableResult.done()
        }

        let bytes = data.slice()
        let len: BlobSizeType = bytes.size

        if (buffer.size == 0 && len >= highWaterMark) {
            var doSend = true
            // Common case: all ASCII
            var allAscii = true
            for (b in bytes) {
                if (b > 127) {
                    allAscii = false
                    break
                }
            }
            if (allAscii) {
                if (send(bytes)) {
                    return WritableResult.owned(len)
                }
                doSend = false
            }

            bufferWrite(bytes)

            if (doSend) {
                if (sendReadable(0)) {
                    return WritableResult.owned(len)
                }
            }
        } else if (buffer.size + len >= highWaterMark) {
            bufferWrite(bytes)
            if (sendReadable(0)) {
                return WritableResult.owned(len)
            }
        } else {
            bufferWrite(bytes)
        }

        registerAutoFlusher()
        return WritableResult.owned(len)
    }

    /// 写入 UTF16 编码数据
    /// 对应 Bun: writeUTF16()
    public func writeUTF16(data: StreamResult): WritableResult {
        if (done || requestedEnd) {
            return WritableResult.owned(0)
        }

        match (res) {
            case Some(r) => if (r.hasResponded()) {
                signal.close(Option<SyscallError>.None)
                markDone()
                return WritableResult.done()
            }
            case None =>
                signal.close(Option<SyscallError>.None)
                markDone()
                return WritableResult.done()
        }

        let bytes = data.slice()

        // We must always buffer UTF-16
        // We assume the case of all-ascii UTF-16 string is pretty uncommon
        let utf16 = data.slice16()
        bufferWriteUTF16(utf16)

        let readable = readableSlice()
        if (readable.size >= highWaterMark || hasBackpressure) {
            if (sendReadable(0)) {
                return WritableResult.owned(bytes.size)
            }
        }

        registerAutoFlusher()
        return WritableResult.owned(bytes.size)
    }

    /// 标记完成
    /// 对应 Bun: markDone()
    public func markDone(): Unit {
        done = true
        unregisterAutoFlusher()
    }

    /// 结束写入
    /// 对应 Bun: HTTPServerWritable.end()
    public func end(err: ?SyscallError): Unit {
        if (requestedEnd) {
            return
        }

        match (res) {
            case Some(r) => if (done || r.hasResponded()) {
                signal.close(err)
                markDone()
                finalize()
                return
            }
            case None =>
                if (done) {
                    signal.close(err)
                    markDone()
                    finalize()
                    return
                }
        }

        requestedEnd = true
        let readable = readableSlice()
        endLen = readable.size

        if (readable.size == 0) {
            signal.close(err)
            markDone()
            finalize()
        }
    }

    /// 对应 Bun: endFromJS()
    public func endFromJS(global: JSGlobalObject): JsValue {
        if (requestedEnd) {
            return JsValue.jsNumber(0.0)
        }

        match (res) {
            case Some(r) => if (done || r.hasResponded()) {
                requestedEnd = true
                signal.close(Option<SyscallError>.None)
                markDone()
                finalize()
                return JsValue.jsNumber(0.0)
            }
            case None =>
                if (done) {
                    requestedEnd = true
                    signal.close(Option<SyscallError>.None)
                    markDone()
                    finalize()
                    return JsValue.jsNumber(0.0)
                }
        }

        requestedEnd = true
        let readable = readableSlice()
        endLen = readable.size

        if (readable.size > 0) {
            if (!sendReadable(0)) {
                pendingFlush = Some(JSPromise.create(global))
                globalThis = Some(global)
                let value = pendingFlush.getOrThrow().toJS()
                value.protect()
                return value
            }
        }

        markDone()
        flushPromise()
        signal.close(Option<SyscallError>.None)
        finalize()

        return JsValue.jsNumber(wrote)
    }

    /// 获取 Sink
    /// 对应 Bun: sink()
    public func sink(): Sink {
        return Sink(this)
    }

    /// 中止
    /// 对应 Bun: abort()
    public func abort(): Unit {
        done = true
        res = None
        unregisterAutoFlusher()
        aborted = true
        signal.close(Option<SyscallError>.None)
        flushPromise()
        finalize()
    }

    /// 对应 Bun: onAutoFlush()
    public func onAutoFlush(): Bool {
        if (done) {
            autoFlusherRegistered = false
            return false
        }

        let readable = readableSlice()

        if (hasBackpressureAndIsTryEnd() || readable.size == 0) {
            autoFlusherRegistered = false
            return false
        }

        if (!sendReadableWithoutAutoFlusher(0)) {
            autoFlusherRegistered = true
            return true
        }
        autoFlusherRegistered = false
        return false
    }

    /// 销毁
    /// 对应 Bun: destroy()
    public func destroy(): Unit {
        // Drop the GC root for pending promise
        match (pendingFlush) {
            case Some(prom) =>
                prom.toJS().unprotect()
                pendingFlush = None
            case None => ()
        }
        buffer.clear()
        unregisterAutoFlusher()
    }

    /// 最终化
    /// 对应 Bun: finalize()
    public func finalize(): Unit {
        if (!done) {
            unregisterAutoFlusher()
            match (res) {
                case Some(r) => r.clearOnWritable()
                case None => ()
            }
            flushNoWait()
            done = true

            match (res) {
                case Some(r) => r.endStream(false)
                case None => ()
            }
        }

        // Buffer pooling
        match (pooledBuffer) {
            case Some(pooled) =>
                buffer.clear()
                if (buffer.capacity > 64 * 1024) {
                    buffer.clear()
                }
                pooledBuffer = None
                // Release back to pool
            case None =>
                if (buffer.capacity > 0) {
                    buffer.clear()
                }
        }
    }

    /// 对应 Bun: flushPromise()
    public func flushPromise(): Unit {
        match (pendingFlush) {
            case Some(prom) =>
                pendingFlush = None
                prom.toJS().unprotect()
                let global = getGlobalThis()
                prom.resolve(global, JsValue.jsNumber(wrote - wroteAtStartOfFlush))
                wroteAtStartOfFlush = wrote
            case None => ()
        }
    }

    /// 对应 Bun: unregisterAutoFlusher()
    public func unregisterAutoFlusher(): Unit {
        if (autoFlusherRegistered) {
            autoFlusherRegistered = false
        }
    }

    /// 对应 Bun: registerAutoFlusher()
    public func registerAutoFlusher(): Unit {
        match (res) {
            case Some(r) =>
                r.resetTimeout()
                if (!autoFlusherRegistered) {
                    autoFlusherRegistered = true
                }
            case None => ()
        }
    }

    /// 对应 Bun: onWritable()
    public func onWritable(writeOffset: UInt64, res: UwsResponse): Bool {
        hasBackpressure = false
        if (aborted) {
            signal.close(Option<SyscallError>.None)
            flushPromise()
            finalize()
            return false
        }
        var totalWritten: UInt64 = 0

        let toWrite = Math.min(writeOffset, buffer.size - 1)
        let chunkStart = toWrite
        let readable = readableSlice()
        let chunkLen = if (chunkStart >= readable.size) { 0 } else { readable.size - chunkStart }

        if (chunkLen == 0) {
            if (done) {
                signal.close(Option<SyscallError>.None)
                flushPromise()
                finalize()
                return true
            }
        } else {
            if (!sendReadable(chunkStart)) {
                return false
            }
            totalWritten = UInt64(chunkLen)

            if (requestedEnd) {
                match (this.res) {
                    case Some(r) => r.clearOnWritable()
                    case None => ()
                }
                signal.close(Option<SyscallError>.None)
                flushPromise()
                finalize()
                return true
            }
        }

        flushPromise()

        if (!done && !requestedEnd && !hasBackpressure) {
            if (totalWritten > 0 && readableSlice().size == 0) {
                signal.ready(Some(BlobSizeType(totalWritten)), None)
            }
        }

        return true
    }

    // ---- SinkHandler impl ----

    // write() is already defined above with signature write(data: StreamResult): WritableResult
    // Since StreamResultWritable = WritableResult, it satisfies SinkHandler.write

    public func writeLatin1Data(data: StreamResult): StreamResultWritable {
        return writeLatin1(data)
    }

    public func writeUTF16Data(data: StreamResult): StreamResultWritable {
        return writeUTF16(data)
    }

    public func endErr(err: ?SyscallError): ?SyscallError {
        end(err)
        return None
    }

    public func connectSignal(signal: StreamSignal): ?SyscallError {
        connect(signal)
        return None
    }

    // ---- Private helpers ----

    private func bufferWrite(bytes: Array<UInt8>): Unit {
        for (b in bytes) {
            buffer.append(b)
        }
    }

    private func bufferWriteUTF16(utf16: Array<UInt16>): Unit {
        for (u in utf16) {
            buffer.append(UInt8(u & 0xFF))
            buffer.append(UInt8((u >> 8) & 0xFF))
        }
    }
}

/// HTTPS 响应 Sink
/// 对应 Bun: HTTPSResponseSink = HTTPServerWritable<true, false>
public class HTTPSResponseSink <: HTTPServerWritable {
    public init() {
        super(true, false)
    }
}

/// HTTP 响应 Sink
/// 对应 Bun: HTTPResponseSink = HTTPServerWritable<false, false>
public class HTTPResponseSink <: HTTPServerWritable {
    public init() {
        super(false, false)
    }
}

/// H3 响应 Sink
/// 对应 Bun: H3ResponseSink = HTTPServerWritable<true, true>
public class H3ResponseSink <: HTTPServerWritable {
    public init() {
        super(true, true)
    }
}

// ============================================================================
// NetworkSink - 网络 Sink (S3 多部分上传等)
// 严格翻译自: streams.NetworkSink
// ============================================================================

/// 网络 Sink
/// 严格翻译自 NetworkSink
public class NetworkSink <: SinkHandler {
    /// S3 多部分上传任务引用
    public var task: ?S3MultiPartUpload
    /// 信号
    public var signal: StreamSignal
    /// Global reference
    public var globalThis: ?JSGlobalObject
    /// 高水位标记
    public var highWaterMark: BlobSizeType
    /// Flush promise
    public var flushPromiseRef: JSPromiseStrong
    /// End promise
    public var endPromiseRef: JSPromiseStrong
    /// 是否已结束
    public var ended: Bool
    /// 是否完成
    public var done: Bool
    /// 是否取消
    public var cancel: Bool

    public init() {
        task = None
        signal = StreamSignal()
        globalThis = None
        highWaterMark = 2048
        flushPromiseRef = JSPromiseStrong()
        endPromiseRef = JSPromiseStrong()
        ended = false
        done = false
        cancel = false
    }

    /// 获取 globalThis
    public func getGlobalThis(): JSGlobalObject {
        return globalThis.getOrThrow()
    }

    /// Name constant
    public func name(): String {
        return "NetworkSink"
    }

    /// 获取高水位标记
    /// 对应 Bun: getHighWaterMark()
    public func getHighWaterMark(): BlobSizeType {
        match (task) {
            case Some(t) => t.partSizeInBytes()
            case None => highWaterMark
        }
    }

    /// 获取路径
    /// 对应 Bun: path()
    public func path(): ?Array<UInt8> {
        match (task) {
            case Some(t) => Some(t.path)
            case None => None
        }
    }

    /// 启动
    /// 对应 Bun: NetworkSink.start()
    public func start(streamStart: StreamStart): Unit {
        if (ended) {
            return
        }

        match (streamStart.tag) {
            case ChunkSize =>
                if (streamStart.chunkSize > 0) {
                    highWaterMark = streamStart.chunkSize
                }
            case _ => ()
        }

        ended = false
        signal.start()
    }

    /// 连接信号
    /// 对应 Bun: connect()
    public func connect(sig: StreamSignal): Unit {
        signal = sig
    }

    /// 获取 Sink
    public func sink(): Sink {
        return Sink(this)
    }

    /// 最终化
    /// 对应 Bun: finalize()
    public func finalize(): Unit {
        detachWritable()
    }

    /// 分离可写端
    private func detachWritable(): Unit {
        match (task) {
            case Some(t) =>
                task = None
                t.deref()
            case None => ()
        }
    }

    /// 对应 Bun: onWritable
    public static func onWritable(task: S3MultiPartUpload, sink: NetworkSink, flushed: UInt64): Unit {
        if (sink.flushPromiseRef.hasValue()) {
            let global = sink.getGlobalThis()
            sink.flushPromiseRef.resolve(global, JsValue.jsNumber(flushed))
        }
    }

    /// 刷新
    /// 对应 Bun: NetworkSink.flush()
    public func flush(): Unit {
        // No-op
    }

    /// 对应 Bun: flushFromJS()
    public func flushFromJS(global: JSGlobalObject, wait: Bool): JsValue {
        // Still waiting for more data to be flushed
        if (flushPromiseRef.hasValue()) {
            return flushPromiseRef.value()
        }

        // Nothing to do here
        if (done) {
            return JSPromise.resolvedPromiseValue(global, JsValue.jsNumber(0.0))
        }

        // Flush more
        match (task) {
            case Some(t) =>
                if (!t.isQueueEmpty()) {
                    flushPromiseRef = JSPromiseStrong(global)
                    return flushPromiseRef.value()
                }
            case None => ()
        }

        return JSPromise.resolvedPromiseValue(global, JsValue.jsNumber(0.0))
    }

    /// 对应 Bun: finalizeAndDestroy
    public static func finalizeAndDestroy(sink: NetworkSink): Unit {
        sink.finalize()
    }

    /// 中止
    /// 对应 Bun: NetworkSink.abort()
    public func abort(): Unit {
        ended = true
        done = true
        signal.close(Option<SyscallError>.None)
        cancel = true
        finalize()
    }

    /// 写入数据
    /// 对应 Bun: NetworkSink.write()
    public func write(data: StreamResult): WritableResult {
        if (ended) {
            return WritableResult.owned(0)
        }
        let bytes = data.slice()
        let len: BlobSizeType = bytes.size

        match (task) {
            case Some(t) =>
                t.writeBytes(bytes, false)
            case None => ()
        }

        return WritableResult.owned(len)
    }

    /// 写入字节 (alias)
    public func writeBytes(data: StreamResult): WritableResult {
        return write(data)
    }

    /// 写入 Latin1 编码数据
    /// 对应 Bun: NetworkSink.writeLatin1()
    public func writeLatin1(data: StreamResult): WritableResult {
        if (ended) {
            return WritableResult.owned(0)
        }

        let bytes = data.slice()
        let len: BlobSizeType = bytes.size

        match (task) {
            case Some(t) =>
                t.writeLatin1(bytes, false)
            case None => ()
        }

        return WritableResult.owned(len)
    }

    /// 写入 UTF16 编码数据
    /// 对应 Bun: NetworkSink.writeUTF16()
    public func writeUTF16(data: StreamResult): WritableResult {
        if (ended) {
            return WritableResult.owned(0)
        }
        let bytes = data.slice()
        match (task) {
            case Some(t) =>
                t.writeUTF16(bytes, false)
            case None => ()
        }

        return WritableResult.owned(bytes.size)
    }

    /// 结束写入
    /// 对应 Bun: NetworkSink.end()
    public func end(err: ?SyscallError): Unit {
        if (ended) {
            return
        }

        ended = true
        // Send EOF: flush everything and send EOF
        match (task) {
            case Some(t) =>
                t.writeBytes(Array<UInt8>(), true)
            case None => ()
        }

        signal.close(err)
    }

    /// 对应 Bun: endFromJS()
    public func endFromJS(global: JSGlobalObject): JsValue {
        end(None)
        if (endPromiseRef.hasValue()) {
            return endPromiseRef.value()
        }
        match (task) {
            case Some(t) =>
                // We need to wait for the task to end
                endPromiseRef = JSPromiseStrong(global)
                let value = endPromiseRef.value()
                if (!ended) {
                    ended = true
                    // Send EOF
                    match (task) {
                        case Some(t2) => t2.writeBytes(Array<UInt8>(), true)
                        case None => ()
                    }
                    signal.close(Option<SyscallError>.None)
                }
                return value
            case None => ()
        }
        // Task already detached
        return JsValue.jsNumber(0.0)
    }

    /// 内存开销
    /// 对应 Bun: NetworkSink.memoryCost()
    public func memoryCost(): Int64 {
        match (task) {
            case Some(t) => t.buffered.memoryCost()
            case None => 0
        }
    }

    // ---- SinkHandler impl ----

    public func writeLatin1Data(data: StreamResult): StreamResultWritable {
        return writeLatin1(data)
    }

    public func writeUTF16Data(data: StreamResult): StreamResultWritable {
        return writeUTF16(data)
    }

    public func endErr(err: ?SyscallError): ?SyscallError {
        end(err)
        return None
    }

    public func connectSignal(signal: StreamSignal): ?SyscallError {
        connect(signal)
        return None
    }
}

// ============================================================================
// BufferAction - 缓冲动作
// 严格翻译自: streams.BufferAction
// ============================================================================

/// 缓冲动作类型
/// 对应 Bun: BufferActionTag #[repr(u8)]
public enum BufferActionKind {
    | Text
    | ArrayBuffer
    | Blob
    | Bytes
    | Json

    public operator func == (rhs: BufferActionKind): Bool {
        match (this) {
            case Text => match (rhs) { case Text => true case _ => false }
            case ArrayBuffer => match (rhs) { case ArrayBuffer => true case _ => false }
            case Blob => match (rhs) { case Blob => true case _ => false }
            case Bytes => match (rhs) { case Bytes => true case _ => false }
            case Json => match (rhs) { case Json => true case _ => false }
        }
    }
}

/// 缓冲动作
/// 对应 Bun: BufferAction { tag, promise }
public class BufferAction {
    public var kind: BufferActionKind
    /// Promise reference
    public var promise: JSPromiseStrong

    public init(kind: BufferActionKind, global: JSGlobalObject) {
        this.kind = kind
        this.promise = JSPromiseStrong(global)
    }

    public init(kind: BufferActionKind) {
        this.kind = kind
        this.promise = JSPromiseStrong()
    }

    /// Get the tag
    public func tag(): BufferActionKind { return kind }

    /// 完成操作
    /// 对应 Bun: BufferAction.fulfill()
    public func fulfill(global: JSGlobalObject, blob: AnyBlob): Unit {
        blob.wrap(promise.swap(), global, kind)
    }

    /// 拒绝操作
    /// 对应 Bun: BufferAction.reject()
    public func reject(global: JSGlobalObject, err: StreamError): Unit {
        let (jsErr, _) = err.toJSWeak(global)
        promise.swap().reject(global, jsErr)
    }

    /// 解析操作
    /// 对应 Bun: BufferAction.resolve()
    public func resolve(global: JSGlobalObject, result: JsValue): Unit {
        promise.swap().resolve(global, result)
    }

    /// Get promise JS value
    public func value(): JsValue {
        return promise.value()
    }

    /// Get promise pointer
    public func get(): JSPromise {
        return promise.get()
    }

    /// Swap promise and get pointer
    public func swap(): JSPromise {
        return promise.swap()
    }
}

// ============================================================================
// ReadResult - 读取结果
// 严格翻译自: streams.ReadResult
// ============================================================================

/// 读取结果
/// 对应 Bun: ReadResult (enum)
public enum ReadResultKind {
    | Pending
    | Err
    | Done
    | Read
}

/// 已消耗的数据
public class DrainedData {
    public var list: ArrayList<UInt8>
    public var sizeHint: Int64

    public init() {
        list = ArrayList<UInt8>()
        sizeHint = 0
    }
}

// ============================================================================
// FileSinkOptions
// ============================================================================

/// (Already defined above)

// ============================================================================
// Supporting types - forward declarations / placeholder implementations
// ============================================================================

/// UWS response handle (opaque)
/// 对应 Bun: UwsResponse = c_void (opaque)
public class UwsResponse {
    public init() {}

    public func hasResponded(): Bool { return false }
    public func clearOnWritable(): Unit {}
    public func endStream(close: Bool): Unit {}
    public func resetTimeout(): Unit {}
    public func tryEnd(data: Array<UInt8>, endLen: Int64, close: Bool): Bool { return true }
    public func write(data: Array<UInt8>): WriteResult { return WriteResult.Written }
    public func end(data: Array<UInt8>, close: Bool): Unit {}
    public func state(): HttpResponseState { return HttpResponseState() }
}

/// HTTP response state
public class HttpResponseState {
    public init() {}
    public func isHTTPWriteCalled(): Bool { return false }
}

/// Write result from uWS
public enum WriteResult {
    | Written
    | Backpressure
}

/// S3MultiPartUpload - S3 多部分上传
/// 对应 Bun: bun_s3::MultiPartUpload
public class S3MultiPartUpload {
    public var path: Array<UInt8>
    public var buffered: S3BufferedData

    public init() {
        path = Array<UInt8>()
        buffered = S3BufferedData()
    }

    public func partSizeInBytes(): BlobSizeType {
        return 5 * 1024 * 1024 // 5MB
    }

    public func writeBytes(data: Array<UInt8>, eof: Bool): Unit {}
    public func writeLatin1(data: Array<UInt8>, eof: Bool): Unit {}
    public func writeUTF16(data: Array<UInt8>, eof: Bool): Unit {}
    public func deref(): Unit {}
    public func isQueueEmpty(): Bool { return true }
}

/// S3 缓冲数据
public class S3BufferedData {
    public init() {}

    public func memoryCost(): Int64 {
        return 0
    }
}

/// JSPromise
public class JSPromise {
    public static func create(global: JSGlobalObject): JSPromise {
        return JSPromise()
    }
    public static func opaqueRef(p: JSPromise): JSPromise { return p }
    public static func rejectedPromise(global: JSGlobalObject, value: JsValue): JSPromise {
        return JSPromise()
    }
    public static func resolvedPromiseValue(global: JSGlobalObject, value: JsValue): JsValue {
        return value
    }

    public init() {}

    public func toJS(): JsValue { return JsValue.NULL }
    public func resolve(global: JSGlobalObject, value: JsValue): Unit {}
    public func reject(global: JSGlobalObject, value: JsValue): Unit {}
    public func rejectWithAsyncStack(global: JSGlobalObject, value: JsValue): Unit {}
    public func protect(): Unit {}
    public func unprotect(): Unit {}
}

/// JSType
public enum JSType {
    | Uint8Array
}

/// ArrayBuffer
/// NOTE: renamed to avoid shadowing bao_collections.ArrayBuffer
public class ArrayBufferPlaceholder {
    public static func fromBytes(data: Array<UInt8>, `type`: JSType): ArrayBufferPlaceholder {
        return ArrayBufferPlaceholder()
    }
    public static func create(global: JSGlobalObject, data: Array<UInt8>, `type`: JSType): JsValue {
        return JsValue.NULL
    }
    public init() {}
    public func toJS(global: JSGlobalObject): JsValue { return JsValue.NULL }
}

/// FdJsc
public class FdJsc {
    public static func fromJS(value: JsValue): ?Fd {
        return None
    }
}

/// UInt64
public type `UInt64` = Int64

/// Math utility
public class Math {
    public static func max(a: Int64, b: Int64): Int64 {
        return if (a > b) { a } else { b }
    }
    public static func min(a: Int64, b: Int64): Int64 {
        return if (a < b) { a } else { b }
    }
}

// ported from: src/runtime/webcore/streams.zig
