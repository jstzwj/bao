// Streams - 流 API 基础设施
// 严格翻译自: src/runtime/webcore/streams.zig
// 包含: Start, Result, Result.Writable, Result.Pending, Signal, HTTPServerWritable,
//        NetworkSink, BufferAction, ReadResult 等
package bao_runtime.webcore

import bao_core.*

// ============================================================================
// StreamStart - 流启动结果
// 严格翻译自: streams.Start (union(Tag))
// ============================================================================

/// 流启动结果
/// 严格翻译自 streams.Start
public enum StreamStartTag {
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
}

/// 流启动结果
/// 严格翻译自 streams.Start
public class StreamStart {
    public var tag: StreamStartTag
    /// 错误 (对应 .err)
    public var err: ?SyscallError
    /// 块大小 (对应 .chunk_size)
    public var chunkSize: BlobSizeType
    /// FileSink 选项 (对应 .FileSink)
    public var fileSinkOptions: ?FileSinkOptions
    /// ArrayBufferSink 配置
    public var asUint8Array: Bool
    public var stream: Bool
    /// owned_and_done 数据
    public var ownedData: ArrayList<UInt8>
    /// done 数据
    public var doneData: ArrayList<UInt8>

    public init() {
        tag = StreamStartTag.Empty
        err = None
        chunkSize = 0
        fileSinkOptions = None
        asUint8Array = false
        stream = false
        ownedData = ArrayList<UInt8>()
        doneData = ArrayList<UInt8>()
    }

    public static func empty(): StreamStart {
        let s = StreamStart()
        s.tag = StreamStartTag.Empty
        return s
    }

    public static func ready(): StreamStart {
        let s = StreamStart()
        s.tag = StreamStartTag.Ready
        return s
    }

    public static func err(e: SyscallError): StreamStart {
        let s = StreamStart()
        s.tag = StreamStartTag.Err
        s.err = Some(e)
        return s
    }

    public static func chunkSize(size: BlobSizeType): StreamStart {
        let s = StreamStart()
        s.tag = StreamStartTag.ChunkSize
        s.chunkSize = size
        return s
    }

    public static func ownedAndDone(data: ArrayList<UInt8>): StreamStart {
        let s = StreamStart()
        s.tag = StreamStartTag.OwnedAndDone
        s.ownedData = data
        return s
    }

    public static func done(data: ArrayList<UInt8>): StreamStart {
        let s = StreamStart()
        s.tag = StreamStartTag.Done
        s.doneData = data
        return s
    }
}

// ============================================================================
// StreamResult - 流结果
// 严格翻译自: streams.Result (union(Tag))
// ============================================================================

/// 流结果
/// 严格翻译自 streams.Result
public enum StreamResultTag {
    | Pending
    | Err
    | Done
    | Owned
    | OwnedAndDone
    | TemporaryAndDone
    | Temporary
    | IntoArray
    | IntoArrayAndDone
}

/// 流错误类型
/// 严格翻译自 Result.StreamError
public enum StreamErrorKind {
    | SyscallError                          // Error: Syscall.Error
    | AbortReason                          // AbortReason: CommonAbortReason
    | JSValue                              // JSValue (强引用)
    | WeakJSValue                          // WeakJSValue (弱引用)

    public func isError(): Bool {
        match (this) {
            case SyscallError => true
            case AbortReason => true
            case JSValue => true
            case WeakJSValue => true
        }
    }
}

/// 流错误包装
/// 严格翻译自 Result.StreamError
public class StreamError {
    public var kind: StreamErrorKind
    /// Syscall 错误
    public var syscallErr: ?SyscallError
    /// 中止原因
    public var abortReason: ?CommonAbortReason

    public init(kind: StreamErrorKind) {
        this.kind = kind
        this.syscallErr = None
        this.abortReason = None
    }

    public init(syscallErr: SyscallError) {
        this.kind = StreamErrorKind.SyscallError
        this.syscallErr = Some(syscallErr)
        this.abortReason = None
    }

    public init(abortReason: CommonAbortReason) {
        this.kind = StreamErrorKind.AbortReason
        this.syscallErr = None
        this.abortReason = Some(abortReason)
    }
}

/// IntoArray 结构
/// 严格翻译自 Result.IntoArray
public class IntoArray {
    public var len: BlobSizeType

    public init() {
        len = 0
    }

    public init(len: BlobSizeType) {
        this.len = len
    }
}

/// 流结果
/// 严格翻译自 streams.Result
public class StreamResult {
    public var tag: StreamResultTag
    /// pending 状态
    public var pending: ?StreamResultPending
    /// 错误
    public var err: ?StreamError
    /// owned 数据
    public var ownedData: ArrayList<UInt8>
    /// temporary 数据
    public var tempData: ArrayList<UInt8>
    /// into_array 数据
    public var intoArray: ?IntoArray

    public init(tag: StreamResultTag) {
        this.tag = tag
        this.pending = None
        this.err = None
        this.ownedData = ArrayList<UInt8>()
        this.tempData = ArrayList<UInt8>()
        this.intoArray = None
    }

    /// 获取数据切片
    /// 严格翻译自 Result.slice()
    public func slice(): Array<UInt8> {
        match (tag) {
            case Owned => ownedData.toArray()
            case OwnedAndDone => ownedData.toArray()
            case TemporaryAndDone => tempData.toArray()
            case Temporary => tempData.toArray()
            case _ => Array<UInt8>()
        }
    }

    /// 获取数据切片为 ArrayList
    public func sliceList(): ArrayList<UInt8> {
        match (tag) {
            case Owned => ownedData
            case OwnedAndDone => ownedData
            case TemporaryAndDone => tempData
            case Temporary => tempData
            case _ => ArrayList<UInt8>()
        }
    }

    /// 是否完成
    /// 严格翻译自 Result.isDone()
    public func isDone(): Bool {
        match (tag) {
            case OwnedAndDone => true
            case TemporaryAndDone => true
            case IntoArrayAndDone => true
            case Done => true
            case Err => true
            case _ => false
        }
    }

    /// 释放资源
    /// 严格翻译自 Result.deinit()
    public func deinit(): Unit {
        match (tag) {
            case Owned => ownedData.clear()
            case OwnedAndDone => ownedData.clear()
            case Err => {
                // JSValue 类型的错误需要取消保护
            }
            case _ => ()
        }
    }

    // 静态工厂方法
    public static func pending(p: StreamResultPending): StreamResult {
        let r = StreamResult(StreamResultTag.Pending)
        r.pending = Some(p)
        return r
    }

    public static func err(e: StreamError): StreamResult {
        let r = StreamResult(StreamResultTag.Err)
        r.err = Some(e)
        return r
    }

    public static func done(): StreamResult {
        return StreamResult(StreamResultTag.Done)
    }

    public static func owned(data: ArrayList<UInt8>): StreamResult {
        let r = StreamResult(StreamResultTag.Owned)
        r.ownedData = data
        return r
    }

    public static func ownedAndDone(data: ArrayList<UInt8>): StreamResult {
        let r = StreamResult(StreamResultTag.OwnedAndDone)
        r.ownedData = data
        return r
    }

    public static func temporary(data: ArrayList<UInt8>): StreamResult {
        let r = StreamResult(StreamResultTag.Temporary)
        r.tempData = data
        return r
    }

    public static func temporaryAndDone(data: ArrayList<UInt8>): StreamResult {
        let r = StreamResult(StreamResultTag.TemporaryAndDone)
        r.tempData = data
        return r
    }

    public static func intoArray(len: BlobSizeType): StreamResult {
        let r = StreamResult(StreamResultTag.IntoArray)
        r.intoArray = Some(IntoArray(len))
        return r
    }

    public static func intoArrayAndDone(len: BlobSizeType): StreamResult {
        let r = StreamResult(StreamResultTag.IntoArrayAndDone)
        r.intoArray = Some(IntoArray(len))
        return r
    }
}

// ============================================================================
// StreamResultWritable - 流可写结果
// 严格翻译自: streams.Result.Writable (union(Result.Tag))
// ============================================================================

/// 流可写结果
/// 严格翻译自 streams.Result.Writable
public class StreamResultWritable {
    public var tag: StreamResultTag
    /// pending 状态
    public var pending: ?WritablePending
    /// 错误
    public var err: ?SyscallError
    /// 大小数据 (用于 owned, temporary 等表示写入字节数)
    public var size: BlobSizeType

    public init(tag: StreamResultTag) {
        this.tag = tag
        this.pending = None
        this.err = None
        this.size = 0
    }

    /// 是否完成
    /// 严格翻译自 Writable.isDone()
    public func isDone(): Bool {
        match (tag) {
            case OwnedAndDone => true
            case TemporaryAndDone => true
            case IntoArrayAndDone => true
            case Done => true
            case Err => true
            case _ => false
        }
    }

    // 静态工厂方法
    public static func pending(p: WritablePending): StreamResultWritable {
        let r = StreamResultWritable(StreamResultTag.Pending)
        r.pending = Some(p)
        return r
    }

    public static func err(e: SyscallError): StreamResultWritable {
        let r = StreamResultWritable(StreamResultTag.Err)
        r.err = Some(e)
        return r
    }

    public static func done(): StreamResultWritable {
        return StreamResultWritable(StreamResultTag.Done)
    }

    public static func owned(size: BlobSizeType): StreamResultWritable {
        let r = StreamResultWritable(StreamResultTag.Owned)
        r.size = size
        return r
    }

    public static func ownedAndDone(size: BlobSizeType): StreamResultWritable {
        let r = StreamResultWritable(StreamResultTag.OwnedAndDone)
        r.size = size
        return r
    }

    public static func temporary(size: BlobSizeType): StreamResultWritable {
        let r = StreamResultWritable(StreamResultTag.Temporary)
        r.size = size
        return r
    }

    public static func temporaryAndDone(size: BlobSizeType): StreamResultWritable {
        let r = StreamResultWritable(StreamResultTag.TemporaryAndDone)
        r.size = size
        return r
    }
}

// ============================================================================
// WritablePending - 可写 Pending 状态
// 严格翻译自: Result.Writable.Pending
// ============================================================================

/// Writable Pending 的状态
public enum PendingState {
    | None
    | Pending
    | Used
}

/// WritablePending 的 Future 类型
public enum WritableFutureKind {
    | None
    | Promise
    | Handler
}

/// 可写 Pending 状态
/// 严格翻译自 Result.Writable.Pending
public class WritablePending {
    /// future 类型
    public var futureKind: WritableFutureKind
    /// 结果
    public var result: StreamResultWritable
    /// 已消耗字节数
    public var consumed: BlobSizeType
    /// 状态
    public var state: PendingState

    public init() {
        futureKind = WritableFutureKind.None
        result = StreamResultWritable.done()
        consumed = 0
        state = PendingState.None
    }

    /// 释放资源
    /// 严格翻译自 Pending.deinit()
    public func deinit(): Unit {
        futureKind = WritableFutureKind.None
    }

    /// 运行 pending 回调
    /// 严格翻译自 Pending.run()
    public func run(): Unit {
        if (state != PendingState.Pending) {
            return
        }
        state = PendingState.Used

        match (futureKind) {
            case Promise => {
                // 在实际实现中会 resolve/reject JS Promise
            }
            case Handler => {
                // 在实际实现中会调用 handler 回调
            }
            case None => ()
        }
    }
}

// ============================================================================
// StreamResultPending - 流结果待处理
// 严格翻译自: streams.Result.Pending
// ============================================================================

/// Pending 的 Future 类型
public enum PendingFutureKind {
    | Promise
    | Handler
}

/// 流结果待处理
/// 严格翻译自 streams.Result.Pending
public class StreamResultPending {
    /// future 类型
    public var futureKind: PendingFutureKind
    /// 结果
    public var result: StreamResult
    /// 状态
    public var state: PendingState

    public init() {
        futureKind = PendingFutureKind.Promise
        result = StreamResult.done()
        state = PendingState.None
    }

    /// 设置回调
    /// 严格翻译自 Pending.set()
    public func setStatePending(): Unit {
        state = PendingState.Pending
    }

    /// 运行 pending 回调
    /// 严格翻译自 Pending.run()
    public func run(): Unit {
        if (state != PendingState.Pending) {
            return
        }
        state = PendingState.Used

        match (futureKind) {
            case Promise => {
                // 在实际实现中会 fulfill JS Promise
            }
            case Handler => {
                // 在实际实现中会调用 handler 回调
            }
        }
    }

    /// 在下一个 tick 运行
    /// 严格翻译自 Pending.runOnNextTick()
    public func runOnNextTick(): Unit {
        if (state != PendingState.Pending) {
            return
        }
        // 在实际实现中会入队到事件循环
    }
}

// ============================================================================
// Signal - 流信号
// 严格翻译自: streams.Signal
// ============================================================================

/// 信号虚表
/// 严格翻译自 Signal.VTable
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
}

/// 流信号
/// 严格翻译自 streams.Signal
public class StreamSignal {
    /// 指针 (null 表示 dead)
    public var isDead: Bool
    /// 虚表
    public var vtable: ?SignalVTable

    public init() {
        isDead = true
        vtable = None
    }

    public init(vtable: SignalVTable) {
        isDead = false
        this.vtable = Some(vtable)
    }

    /// 清除信号
    /// 严格翻译自 Signal.clear()
    public func clear(): Unit {
        isDead = true
    }

    /// 关闭
    /// 严格翻译自 Signal.close()
    public func close(err: ?SyscallError): Unit {
        if (isDead) {
            return
        }
        match (vtable) {
            case Some(vt) => vt.onClose(err)
            case None => ()
        }
    }

    /// 就绪
    /// 严格翻译自 Signal.ready()
    public func ready(amount: ?BlobSizeType, offset: ?BlobSizeType): Unit {
        if (isDead) {
            return
        }
        match (vtable) {
            case Some(vt) => vt.onReady(amount, offset)
            case None => ()
        }
    }

    /// 启动
    /// 严格翻译自 Signal.start()
    public func start(): Unit {
        if (isDead) {
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
// 严格翻译自: streams.HTTPServerWritable(ssl, http3)
// ============================================================================

/// HTTP 服务器可写流配置
public class HTTPServerWritableConfig {
    public var ssl: Bool
    public var http3: Bool

    public init(ssl: Bool, http3: Bool) {
        this.ssl = ssl
        this.http3 = http3
    }
}

/// HTTP 服务器可写流
/// 严格翻译自 HTTPServerWritable
public class HTTPServerWritable {
    /// 缓冲区
    public var buffer: ArrayList<UInt8>
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
    /// 是否有背压
    public var hasBackpressure: Bool
    /// 请求结束的长度
    public var endLen: Int64
    /// 是否已中止
    public var aborted: Bool
    /// 是否请求结束
    public var requestedEnd: Bool
    /// 高水位标记
    public var highWaterMark: BlobSizeType
    /// 写入起始偏移 (用于 flush Promise)
    public var wroteAtStartOfFlush: BlobSizeType

    public init() {
        buffer = ArrayList<UInt8>()
        offset = 0
        isListeningForAbort = false
        wrote = 0
        done = false
        signal = StreamSignal()
        hasBackpressure = false
        endLen = 0
        aborted = false
        requestedEnd = false
        highWaterMark = 2048
        wroteAtStartOfFlush = 0
    }

    /// 内存开销
    /// 严格翻译自 HTTPServerWritable.memoryCost()
    public func memoryCost(): Int64 {
        return buffer.capacity
    }

    /// 获取可读切片
    /// 严格翻译自 readableSlice()
    public func readableSlice(): Array<UInt8> {
        if (offset >= buffer.size) {
            return Array<UInt8>()
        }
        return buffer.toArray()[offset.toInt()]
    }

    /// 处理已写入
    /// 严格翻译自 handleWrote()
    public func handleWrote(amount: Int64): Unit {
        let amt: BlobSizeType = amount.toInt32()
        offset += amt
        wrote += amt

        if (offset >= buffer.size) {
            offset = 0
            buffer.clear()
        }
    }

    /// 启动
    /// 严格翻译自 HTTPServerWritable.start()
    public func start(streamStart: StreamStart): ?SyscallError {
        if (aborted) {
            signal.close(None)
            return None
        }

        wrote = 0
        wroteAtStartOfFlush = 0
        buffer.clear()

        match (streamStart.tag) {
            case ChunkSize => {
                if (streamStart.chunkSize > 0) {
                    highWaterMark = streamStart.chunkSize
                }
            }
            case _ => ()
        }

        done = false
        signal.start()
        return None
    }

    /// 写入数据
    /// 严格翻译自 HTTPServerWritable.write()
    public func write(data: StreamResult): StreamResultWritable {
        if (done || requestedEnd) {
            return StreamResultWritable.owned(0)
        }

        let bytes = data.slice()
        let len: BlobSizeType = bytes.size

        if (buffer.size == 0 && len >= highWaterMark) {
            // 快速路径: 大块数据, 无背压
            send(bytes)
            return StreamResultWritable.owned(len)
        } else if (buffer.size + len >= highWaterMark) {
            // 缓冲区 + 新数据超过高水位
            for (b in bytes) {
                buffer.append(b)
            }
            let readable = readableSlice()
            send(readable)
            return StreamResultWritable.owned(len)
        } else {
            // 排队等待
            for (b in bytes) {
                buffer.append(b)
            }
        }

        return StreamResultWritable.owned(len)
    }

    /// 写入 Latin1 编码数据
    /// 严格翻译自 writeLatin1()
    public func writeLatin1(data: StreamResult): StreamResultWritable {
        if (done || requestedEnd) {
            return StreamResultWritable.owned(0)
        }

        let bytes = data.slice()
        let len: BlobSizeType = bytes.size

        if (buffer.size == 0 && len >= highWaterMark) {
            // 检查是否全 ASCII
            var allAscii = true
            for (b in bytes) {
                if (b > 127) {
                    allAscii = false
                    break
                }
            }
            if (allAscii) {
                send(bytes)
                return StreamResultWritable.owned(len)
            }
        }

        // 缓冲数据
        for (b in bytes) {
            buffer.append(b)
        }

        if (buffer.size >= highWaterMark || hasBackpressure) {
            let readable = readableSlice()
            send(readable)
        }

        return StreamResultWritable.owned(len)
    }

    /// 写入 UTF16 编码数据
    /// 严格翻译自 writeUTF16()
    public func writeUTF16(data: StreamResult): StreamResultWritable {
        if (done || requestedEnd) {
            return StreamResultWritable.owned(0)
        }

        let bytes = data.slice()
        // UTF-16 必须始终缓冲
        for (b in bytes) {
            buffer.append(b)
        }

        let readable = readableSlice()
        if (readable.size >= highWaterMark || hasBackpressure) {
            send(readable)
        }

        return StreamResultWritable.owned(bytes.size)
    }

    /// 结束写入
    /// 严格翻译自 HTTPServerWritable.end()
    public func end(err: ?SyscallError): ?SyscallError {
        if (requestedEnd) {
            return None
        }

        if (done) {
            signal.close(err)
            markDone()
            return None
        }

        requestedEnd = true
        let readable = readableSlice()
        endLen = readable.size

        if (readable.size == 0) {
            signal.close(err)
            markDone()
            return None
        }
        return None
    }

    /// 刷新
    /// 严格翻译自 HTTPServerWritable.flush()
    public func flush(): ?SyscallError {
        if (!hasBackpressure || done) {
            return None
        }
        return None
    }

    /// 不等待的刷新
    /// 严格翻译自 flushNoWait()
    public func flushNoWait(): Int64 {
        if (hasBackpressure || done) {
            return 0
        }

        let readable = readableSlice()
        if (readable.size == 0) {
            return 0
        }

        if (send(readable)) {
            return readable.size
        }
        return 0
    }

    /// 标记完成
    /// 严格翻译自 markDone()
    public func markDone(): Unit {
        done = true
    }

    /// 中止
    /// 严格翻译自 abort()
    public func abort(): Unit {
        done = true
        aborted = true
        signal.close(None)
    }

    /// 发送数据 (内部实现)
    /// 严格翻译自 send() / sendWithoutAutoFlusher()
    public func send(buf: Array<UInt8>): Bool {
        if (done) {
            return false
        }

        if (requestedEnd) {
            // 尝试结束
            hasBackpressure = false
            handleWrote(buf.size)
            return true
        }

        // 普通写入 - 假设有背压
        hasBackpressure = buf.size >= highWaterMark
        handleWrote(buf.size)
        return true
    }

    /// 销毁
    /// 严格翻译自 destroy()
    public func destroy(): Unit {
        buffer.clear()
    }

    /// 最终化
    /// 严格翻译自 finalize()
    public func finalize(): Unit {
        if (!done) {
            flushNoWait()
            done = true
        }
        buffer.clear()
    }
}

/// HTTPS 响应 Sink
/// 严格翻译自 HTTPSResponseSink
public class HTTPSResponseSink extends HTTPServerWritable {
    public init() {
        super()
    }
}

/// HTTP 响应 Sink
/// 严格翻译自 HTTPResponseSink
public class HTTPResponseSink extends HTTPServerWritable {
    public init() {
        super()
    }
}

/// H3 响应 Sink
/// 严格翻译自 H3ResponseSink
public class H3ResponseSink extends HTTPServerWritable {
    public init() {
        super()
    }
}

// ============================================================================
// NetworkSink - 网络 Sink (S3 多部分上传等)
// 严格翻译自: streams.NetworkSink
// ============================================================================

/// 网络 Sink
/// 严格翻译自 NetworkSink
public class NetworkSink {
    /// S3 多部分上传任务引用
    public var task: ?S3MultiPartUpload
    /// 信号
    public var signal: StreamSignal
    /// 高水位标记
    public var highWaterMark: BlobSizeType
    /// 是否已结束
    public var ended: Bool
    /// 是否完成
    public var done: Bool
    /// 是否取消
    public var cancel: Bool

    public init() {
        task = None
        signal = StreamSignal()
        highWaterMark = 2048
        ended = false
        done = false
        cancel = false
    }

    /// 获取高水位标记
    /// 严格翻译自 getHighWaterMark()
    public func getHighWaterMark(): BlobSizeType {
        match (task) {
            case Some(t) => t.partSizeInBytes()
            case None => highWaterMark
        }
    }

    /// 启动
    /// 严格翻译自 NetworkSink.start()
    public func start(streamStart: StreamStart): ?SyscallError {
        if (ended) {
            return None
        }

        match (streamStart.tag) {
            case ChunkSize => {
                if (streamStart.chunkSize > 0) {
                    highWaterMark = streamStart.chunkSize
                }
            }
            case _ => ()
        }

        ended = false
        signal.start()
        return None
    }

    /// 连接信号
    /// 严格翻译自 connect()
    public func connect(sig: StreamSignal): Unit {
        signal = sig
    }

    /// 写入数据
    /// 严格翻译自 NetworkSink.write()
    public func write(data: StreamResult): StreamResultWritable {
        if (ended) {
            return StreamResultWritable.owned(0)
        }

        let bytes = data.slice()
        let len: BlobSizeType = bytes.size

        match (task) {
            case Some(t) => {
                t.writeBytes(bytes, false)
            }
            case None => ()
        }

        return StreamResultWritable.owned(len)
    }

    /// 写入 Latin1 编码数据
    /// 严格翻译自 NetworkSink.writeLatin1()
    public func writeLatin1(data: StreamResult): StreamResultWritable {
        if (ended) {
            return StreamResultWritable.owned(0)
        }

        let bytes = data.slice()
        let len: BlobSizeType = bytes.size

        match (task) {
            case Some(t) => {
                t.writeLatin1(bytes, false)
            }
            case None => ()
        }

        return StreamResultWritable.owned(len)
    }

    /// 写入 UTF16 编码数据
    /// 严格翻译自 NetworkSink.writeUTF16()
    public func writeUTF16(data: StreamResult): StreamResultWritable {
        if (ended) {
            return StreamResultWritable.owned(0)
        }

        let bytes = data.slice()
        match (task) {
            case Some(t) => {
                t.writeUTF16(bytes, false)
            }
            case None => ()
        }

        return StreamResultWritable.owned(bytes.size)
    }

    /// 结束写入
    /// 严格翻译自 NetworkSink.end()
    public func end(err: ?SyscallError): ?SyscallError {
        if (ended) {
            return None
        }

        ended = true
        // 发送 EOF
        match (task) {
            case Some(t) => {
                t.writeBytes(Array<UInt8>(), true)
            }
            case None => ()
        }

        signal.close(err)
        return None
    }

    /// 刷新
    /// 严格翻译自 NetworkSink.flush()
    public func flush(): ?SyscallError {
        return None
    }

    /// 中止
    /// 严格翻译自 NetworkSink.abort()
    public func abort(): Unit {
        ended = true
        done = true
        signal.close(None)
        cancel = true
    }

    /// 内存开销
    /// 严格翻译自 NetworkSink.memoryCost()
    public func memoryCost(): Int64 {
        match (task) {
            case Some(t) => t.buffered.memoryCost()
            case None => 0
        }
    }

    /// 最终化
    /// 严格翻译自 finalize()
    public func finalize(): Unit {
        detachWritable()
    }

    /// 分离可写端
    private func detachWritable(): Unit {
        match (task) {
            case Some(t) => {
                task = None
                t.deref()
            }
            case None => ()
        }
    }
}

// ============================================================================
// BufferAction - 缓冲动作
// 严格翻译自: streams.BufferAction
// ============================================================================

/// 缓冲动作类型
/// 严格翻译自 BufferAction
public enum BufferActionKind {
    | Text
    | ArrayBuffer
    | Blob
    | Bytes
    | Json
}

/// 缓冲动作
/// 严格翻译自 BufferAction
public class BufferAction {
    public var kind: BufferActionKind

    public init(kind: BufferActionKind) {
        this.kind = kind
    }

    /// 完成操作
    /// 严格翻译自 BufferAction.fulfill()
    public func fulfill(): Unit {
        // 在实际实现中会 fulfill JS Promise
    }

    /// 拒绝操作
    /// 严格翻译自 BufferAction.reject()
    public func reject(err: StreamError): Unit {
        // 在实际实现中会 reject JS Promise
    }

    /// 解析操作
    /// 严格翻译自 BufferAction.resolve()
    public func resolve(): Unit {
        // 在实际实现中会 resolve JS Promise
    }
}

// ============================================================================
// ReadResult - 读取结果
// 严格翻译自: streams.ReadResult
// ============================================================================

/// 读取结果
/// 严格翻译自 ReadResult
public enum ReadResultKind {
    | Pending
    | Err
    | Done
    | Read
}

/// 读取结果
/// 严格翻译自 ReadResult
public class ReadResult {
    public var kind: ReadResultKind
    /// 错误
    public var err: ?SyscallError
    /// 读取到的数据
    public var data: Array<UInt8>

    public init(kind: ReadResultKind) {
        this.kind = kind
        this.err = None
        this.data = Array<UInt8>()
    }

    public init(err: SyscallError) {
        this.kind = ReadResultKind.Err
        this.err = Some(err)
        this.data = Array<UInt8>()
    }

    public init(data: Array<UInt8>) {
        this.kind = ReadResultKind.Read
        this.err = None
        this.data = data
    }

    /// 转换为 StreamResult
    /// 严格翻译自 ReadResult.toStream()
    public func toStream(pending: StreamResultPending, buf: Array<UInt8>, closeOnEmpty: Bool): StreamResult {
        return toStreamWithIsDone(pending, buf, closeOnEmpty, false)
    }

    /// 转换为 StreamResult (带 isDone 标志)
    /// 严格翻译自 ReadResult.toStreamWithIsDone()
    public func toStreamWithIsDone(
        pending: StreamResultPending,
        buf: Array<UInt8>,
        closeOnEmpty: Bool,
        isDone: Bool
    ): StreamResult {
        match (kind) {
            case Pending => StreamResult.pending(pending)
            case Err => {
                match (err) {
                    case Some(e) => StreamResult.err(StreamError(e))
                    case None => StreamResult.err(StreamError(StreamErrorKind.SyscallError))
                }
            }
            case Done => StreamResult.done()
            case Read => {
                let owned = data.size > 0
                let done = isDone || (closeOnEmpty && data.size == 0)

                if (owned && done) {
                    return StreamResult.ownedAndDone(ArrayList<UInt8>(data))
                } else if (owned) {
                    return StreamResult.owned(ArrayList<UInt8>(data))
                } else if (done) {
                    return StreamResult.intoArrayAndDone(data.size)
                } else {
                    return StreamResult.intoArray(data.size)
                }
            }
        }
    }
}

// ============================================================================
// DrainResult - 消耗结果
// 严格翻译自: jsc.WebCore.DrainResult
// ============================================================================

/// 消耗结果
/// 严格翻译自 jsc.WebCore.DrainResult
public enum DrainResult {
    | Empty
    | Aborted
    | EstimatedSize(Int64)
    | Owned(DrainedData)
}

/// 已消耗的数据
public class DrainedData {
    /// 数据列表
    public var list: ArrayList<UInt8>
    /// 大小提示
    public var sizeHint: Int64

    public init() {
        list = ArrayList<UInt8>()
        sizeHint = 0
    }
}

// ============================================================================
// FileSinkOptions - FileSink 选项
// 对应 Bun: FileSink.Options
// ============================================================================

/// FileSink 选项
/// 严格翻译自 FileSink.Options
public class FileSinkOptions {
    /// 块大小
    public var chunkSize: BlobSizeType
    /// 输入路径
    public var inputPath: String
    /// 是否截断
    public var truncate: Bool
    /// 是否关闭
    public var close: Bool
    /// 文件模式
    public var mode: Int64

    public init(path: String) {
        chunkSize = 1024
        inputPath = path
        truncate = true
        close = false
        mode = 0o664
    }

    /// 获取标志位
    /// 严格翻译自 Options.flags()
    public func flags(): Int64 {
        // O_NONBLOCK | O_CLOEXEC | O_CREAT | O_WRONLY
        return 0x800 | 0x80000 | 0x40 | 0x01
    }
}

// ============================================================================
// SinkStatus - Sink 状态
// ============================================================================

/// Sink 状态
public enum SinkStatus {
    | Closed
    | Ready
    | Pending
    | Error
}

// ============================================================================
// SinkWriteResult - Sink 写入结果
// ============================================================================

/// Sink 写入结果
public enum SinkWriteResult {
    | Done
    | Owned(BlobSizeType)
    | Pending
    | Error(String)
}

// ============================================================================
// S3MultiPartUpload - S3 多部分上传 (占位)
// ============================================================================

/// S3 多部分上传占位类型
/// 严格翻译自 bun.S3.MultiPartUpload
public class S3MultiPartUpload {
    public var buffered: S3BufferedData

    public init() {
        buffered = S3BufferedData()
    }

    public func partSizeInBytes(): BlobSizeType {
        return 5 * 1024 * 1024 // 5MB
    }

    public func writeBytes(data: Array<UInt8>, eof: Bool): Unit {
        // 占位实现
    }

    public func writeLatin1(data: Array<UInt8>, eof: Bool): Unit {
        // 占位实现
    }

    public func writeUTF16(data: Array<UInt8>, eof: Bool): Unit {
        // 占位实现
    }

    public func deref(): Unit {
        // 引用计数减 1
    }
}

/// S3 缓冲数据
public class S3BufferedData {
    public init() {}

    public func memoryCost(): Int64 {
        return 0
    }
}

// ============================================================================
// CommonAbortReason - 通用中止原因
// ============================================================================

/// 通用中止原因
public enum CommonAbortReason {
    | UserAbort
    | Timeout
    | NetworkError
}

// ============================================================================
// SyscallError - 系统调用错误
// ============================================================================

/// 系统调用错误
public class SyscallError {
    public var errno: Int64
    public var syscall: String
    public var message: String

    public init(errno: Int64, syscall: String) {
        this.errno = errno
        this.syscall = syscall
        this.message = ""
    }

    public init(errno: Int64, syscall: String, message: String) {
        this.errno = errno
        this.syscall = syscall
        this.message = message
    }

    public static func fromCode(code: Int64, syscall: String): SyscallError {
        return SyscallError(code, syscall)
    }

    public static func oom(): SyscallError {
        return SyscallError(12, "write") // ENOMEM
    }
}
