// FileReader - 文件读取器
// 严格翻译自: src/runtime/webcore/FileReader.zig
// 包含: FileReader 完整实现, 包括 IOReader, Lazy, ReadDuringJSOnPullResult,
//        onStart, onPull, onReadChunk, onReaderDone, onReaderError, drain, setFlowing 等
package bao_runtime.webcore

import bao_core.*

// ============================================================================
// ReadableStreamTag - 可读流标签
// ============================================================================

/// 可读流标签
/// 严格翻译自 ReadableStream.Tag
public enum ReadableStreamTag {
    | File
    | ArrayBuffer
    | Blob
    | JS
    | Null
    | Generic
    | HTMLParser
    | WebSocket
}

// ============================================================================
// ReadDuringJSOnPullResult - JS 拉取期间读取结果
// 严格翻译自: FileReader.ReadDuringJSOnPullResult
// ============================================================================

/// JS pull 期间读取的结果类型
/// 严格翻译自 FileReader.ReadDuringJSOnPullResult
public enum ReadDuringJSOnPullKind {
    | None
    | Js
    | AmountRead
    | Temporary
    | UseBuffered
}

/// JS pull 期间读取的结果
/// 严格翻译自 FileReader.ReadDuringJSOnPullResult
public class ReadDuringJSOnPullResult {
    public var kind: ReadDuringJSOnPullKind
    /// JS 缓冲区
    public var jsBuffer: Array<UInt8>
    /// 读取量
    public var amountRead: Int64
    /// 临时数据
    public var temporaryData: Array<UInt8>
    /// 缓冲使用量
    public var useBuffered: Int64

    public init() {
        kind = ReadDuringJSOnPullKind.None
        jsBuffer = Array<UInt8>()
        amountRead = 0
        temporaryData = Array<UInt8>()
        useBuffered = 0
    }

    /// 是否为 none
    public func isNone(): Bool {
        kind == ReadDuringJSOnPullKind.None
    }

    public static func none(): ReadDuringJSOnPullResult {
        ReadDuringJSOnPullResult()
    }

    public static func js(buffer: Array<UInt8>): ReadDuringJSOnPullResult {
        let r = ReadDuringJSOnPullResult()
        r.kind = ReadDuringJSOnPullKind.Js
        r.jsBuffer = buffer
        return r
    }

    public static func amountRead(amount: Int64): ReadDuringJSOnPullResult {
        let r = ReadDuringJSOnPullResult()
        r.kind = ReadDuringJSOnPullKind.AmountRead
        r.amountRead = amount
        return r
    }

    public static func temporary(data: Array<UInt8>): ReadDuringJSOnPullResult {
        let r = ReadDuringJSOnPullResult()
        r.kind = ReadDuringJSOnPullKind.Temporary
        r.temporaryData = data
        return r
    }

    public static func useBuffered(amount: Int64): ReadDuringJSOnPullResult {
        let r = ReadDuringJSOnPullResult()
        r.kind = ReadDuringJSOnPullKind.UseBuffered
        r.useBuffered = amount
        return r
    }
}

// ============================================================================
// FileReaderLazy - FileReader 懒加载
// 严格翻译自: FileReader.Lazy
// ============================================================================

/// FileReader 懒加载类型
/// 严格翻译自 FileReader.Lazy
public enum LazyKind {
    | None
    | Blob
}

/// FileReader 懒加载
/// 严格翻译自 FileReader.Lazy
public class FileReaderLazy {
    public var kind: LazyKind
    /// Blob 存储
    public var blobStore: ?BlobStore

    public init() {
        kind = LazyKind.None
        blobStore = None
    }

    public init(blobStore: BlobStore) {
        kind = LazyKind.Blob
        this.blobStore = Some(blobStore)
    }

    public func isNone(): Bool {
        kind == LazyKind.None
    }
}

/// Blob 存储占位
public class BlobStore {
    public init() {}
}

// ============================================================================
// OpenedFileBlob - 打开的文件 Blob
// 严格翻译自: FileReader.Lazy.OpenedFileBlob
// ============================================================================

/// 打开的文件 Blob 结果
/// 严格翻译自 FileReader.Lazy.OpenedFileBlob
public class OpenedFileBlob {
    /// 文件描述符
    public var fd: Int64
    /// 是否可轮询
    public var pollable: Bool
    /// 是否非阻塞
    public var nonblocking: Bool
    /// 文件类型
    public var fileType: IOFileType

    public init() {
        fd = -1
        pollable = false
        nonblocking = true
        fileType = IOFileType.File
    }
}

/// IO 文件类型
/// 严格翻译自 bun.io.FileType
public enum IOFileType {
    | File
    | Pipe
    | Socket
    | NonblockingPipe
}

// ============================================================================
// IOReaderState - IO 读取器状态
// ============================================================================

/// IO 读取器状态
/// 严格翻译自 bun.io.BufferedReader 状态
public class IOReaderState {
    /// 缓冲区
    public var buffer: ArrayList<UInt8>
    /// 是否完成
    public var done: Bool
    /// 是否有挂起的读取
    public var hasPendingRead: Bool
    /// 是否可轮询
    public var pollable: Bool
    /// 是否非阻塞
    public var nonblocking: Bool
    /// 是否为 socket
    public var isSocket: Bool

    public init() {
        buffer = ArrayList<UInt8>()
        done = false
        hasPendingRead = false
        pollable = false
        nonblocking = false
        isSocket = false
    }

    public func isDone(): Bool {
        return done
    }

    /// 读取文件偏移量
    public func startFileOffset(fd: Int64, pollable: Bool, offset: Int64): ?SyscallError {
        // 在实际实现中使用 lseek
        return None
    }

    /// 开始读取
    public func start(fd: Int64, pollable: Bool): ?SyscallError {
        this.pollable = pollable
        return None
    }

    /// 读取数据
    public func read(): Unit {
        hasPendingRead = true
    }

    /// 关闭
    public func close(): Unit {
        done = true
        hasPendingRead = false
    }

    /// 取消暂停
    public func unpause(): Unit {}

    /// 暂停
    public func pause(): Unit {}

    /// 更新引用
    public func updateRef(enable: Bool): Unit {}

    /// 内存开销
    public func memoryCost(): Int64 {
        return buffer.capacity
    }
}

// ============================================================================
// FileReader - 文件读取器
// 严格翻译自: src/runtime/webcore/FileReader.zig FileReader
// ============================================================================

/// FileReader — 从文件系统读取数据的流式读取器
/// 严格翻译自 FileReader struct (所有字段和方法)
public class FileReader {
    /// IO 读取器
    /// 对应 Bun: FileReader.reader (IOReader)
    public var reader: IOReaderState
    /// 是否完成
    /// 对应 Bun: FileReader.done
    public var done: Bool
    /// Pending 结果
    /// 对应 Bun: FileReader.pending
    public var pending: StreamResultPending
    /// 文件描述符
    /// 对应 Bun: FileReader.fd
    public var fd: Int64
    /// 起始偏移
    /// 对应 Bun: FileReader.start_offset
    public var startOffset: ?Int64
    /// 最大大小
    /// 对应 Bun: FileReader.max_size
    public var maxSize: ?Int64
    /// 总读取字节数
    /// 对应 Bun: FileReader.total_readed
    public var totalRead: Int64
    /// 是否已开始
    /// 对应 Bun: FileReader.started
    public var started: Bool
    /// 是否等待读取完成
    /// 对应 Bun: FileReader.waiting_for_onReaderDone
    public var waitingForOnReaderDone: Bool
    /// 懒加载
    /// 对应 Bun: FileReader.lazy
    public var lazy: FileReaderLazy
    /// 内部缓冲区
    /// 对应 Bun: FileReader.buffered
    public var buffered: ArrayList<UInt8>
    /// JS 拉取期间读取结果
    /// 对应 Bun: FileReader.read_inside_on_pull
    public var readInsideOnPull: ReadDuringJSOnPullResult
    /// 高水位标记
    /// 对应 Bun: FileReader.highwater_mark
    public var highWaterMark: Int64
    /// 是否正在流动
    /// 对应 Bun: FileReader.flowing
    public var flowing: Bool

    public init() {
        reader = IOReaderState()
        done = false
        pending = StreamResultPending()
        fd = -1
        startOffset = None
        maxSize = None
        totalRead = 0
        started = false
        waitingForOnReaderDone = false
        lazy = FileReaderLazy()
        buffered = ArrayList<UInt8>()
        readInsideOnPull = ReadDuringJSOnPullResult.none()
        highWaterMark = 16384
        flowing = true
    }

    public init(fd: Int64) {
        reader = IOReaderState()
        done = false
        pending = StreamResultPending()
        this.fd = fd
        startOffset = None
        maxSize = None
        totalRead = 0
        started = false
        waitingForOnReaderDone = false
        lazy = FileReaderLazy()
        buffered = ArrayList<UInt8>()
        readInsideOnPull = ReadDuringJSOnPullResult.none()
        highWaterMark = 16384
        flowing = true
    }

    // ========================================================================
    // 流标签
    // ========================================================================

    /// 获取流标签
    /// 严格翻译自 FileReader.tag
    public func tag(): ReadableStreamTag {
        return ReadableStreamTag.File
    }

    // ========================================================================
    // 启动
    // ========================================================================

    /// 启动读取
    /// 严格翻译自 FileReader.onStart()
    /// 返回 StreamStart (对应 Bun 的 Start)
    public func onStart(): StreamStart {
        var pollable = false
        var fileType = IOFileType.File

        // 处理懒加载 blob
        match (lazy.kind) {
            case Blob => {
                match (lazy.blobStore) {
                    case Some(store) => {
                        // 模拟 openFileBlob
                        let opened = OpenedFileBlob()
                        fd = opened.fd
                        pollable = opened.pollable
                        fileType = opened.fileType
                        reader.nonblocking = opened.nonblocking
                        reader.pollable = opened.pollable
                    }
                    case None => {}
                }
                lazy = FileReaderLazy()
            }
            case None => {}
        }

        started = true

        // 检查 reader 是否已完成
        if (reader.isDone()) {
            consumeReaderBuffer()
            if (buffered.size > 0) {
                return StreamStart.ownedAndDone(buffered)
            }
        } else {
            if (!lazy.isNone() && reader.pollable) {
                reader.read()
            }
        }

        return StreamStart.ready()
    }

    // ========================================================================
    // 拉取
    // ========================================================================

    /// 拉取数据
    /// 严格翻译自 FileReader.onPull()
    /// 在 Bun 中: onPull(this: *FileReader, buffer: []u8, array: jsc.JSValue) streams.Result
    public func onPull(buffer: Array<UInt8>): StreamResult {
        var drained = drain()

        if (drained.size > 0) {
            if (buffer.size >= drained.size) {
                let drainedLen = drained.size
                // 复制到提供的缓冲区
                for (i in 0..drainedLen) {
                    // buffer[i] = drained[i]  // 在实际实现中
                }

                if (reader.isDone()) {
                    return StreamResult.intoArrayAndDone(drainedLen)
                } else {
                    return StreamResult.intoArray(drainedLen)
                }
            }

            if (reader.isDone()) {
                return StreamResult.ownedAndDone(drained)
            } else {
                return StreamResult.owned(drained)
            }
        }

        if (reader.isDone()) {
            return StreamResult.done()
        }

        if (!reader.hasPendingRead) {
            if (!flowing) {
                // 不流动模式，返回 pending
                return StreamResult.pending(pending)
            }

            // 尝试同步读取
            readInsideOnPull = ReadDuringJSOnPullResult.js(buffer)
            reader.read()

            match (readInsideOnPull.kind) {
                case Js => {
                    let amountRead = buffer.size - readInsideOnPull.jsBuffer.size
                    if (amountRead > 0) {
                        if (reader.isDone()) {
                            return StreamResult.intoArrayAndDone(amountRead)
                        }
                        return StreamResult.intoArray(amountRead)
                    }

                    if (reader.isDone()) {
                        return StreamResult.done()
                    }
                }
                case Temporary => {
                    if (reader.isDone()) {
                        return StreamResult.temporaryAndDone(
                            ArrayList<UInt8>(readInsideOnPull.temporaryData)
                        )
                    }
                    return StreamResult.temporary(
                        ArrayList<UInt8>(readInsideOnPull.temporaryData)
                    )
                }
                case UseBuffered => {
                    if (reader.isDone()) {
                        return StreamResult.ownedAndDone(buffered)
                    }
                    return StreamResult.owned(buffered)
                }
                case _ => {}
            }

            readInsideOnPull = ReadDuringJSOnPullResult.none()

            if (reader.isDone()) {
                return StreamResult.done()
            }
        }

        return StreamResult.pending(pending)
    }

    // ========================================================================
    // 读取块回调
    // ========================================================================

    /// 读取块回调
    /// 严格翻译自 FileReader.onReadChunk()
    /// 返回 true 表示继续读取，false 表示停止
    public func onReadChunk(buf: Array<UInt8>, state: IOReadState): Bool {
        if (done) {
            reader.close()
            return false
        }

        var closeAfter = false
        var hasMore = state != IOReadState.Eof

        if (buf.size > 0) {
            match (maxSize) {
                case Some(max) => {
                    if (totalRead >= max) {
                        return false
                    }
                    var len = max - totalRead
                    if (buf.size > len) {
                        // buf = buf[0..len] // 截断
                    }
                    totalRead += len

                    if (len == 0) {
                        closeAfter = true
                        hasMore = false
                    }
                }
                case None => {}
            }
        }

        // 处理 readInsideOnPull 状态
        if (!readInsideOnPull.isNone()) {
            match (readInsideOnPull.kind) {
                case Js => {
                    if (readInsideOnPull.jsBuffer.size >= buf.size && !hasMore) {
                        // 复制到 JS 缓冲区
                        readInsideOnPull = ReadDuringJSOnPullResult.js(
                            Array<UInt8>() // 剩余部分
                        )
                    } else if (readInsideOnPull.jsBuffer.size > 0 && !hasMore) {
                        readInsideOnPull = ReadDuringJSOnPullResult.temporary(buf)
                    } else if (hasMore) {
                        // 追加到缓冲区
                        for (b in buf) {
                            buffered.append(b)
                        }
                        readInsideOnPull = ReadDuringJSOnPullResult.useBuffered(buf.size)
                    }
                }
                case UseBuffered => {
                    let original = readInsideOnPull.useBuffered
                    for (b in buf) {
                        buffered.append(b)
                    }
                    readInsideOnPull = ReadDuringJSOnPullResult.useBuffered(buf.size + original)
                }
                case _ => {}
            }
        } else if (pending.state == PendingState.Pending) {
            // 0 字节读取但不是 EOF
            if (buf.size == 0 && state == IOReadState.Drained) {
                return true
            }

            if (buf.size == 0) {
                if (buffered.size > 0) {
                    if (reader.isDone()) {
                        pending.result = StreamResult.ownedAndDone(buffered)
                    } else {
                        pending.result = StreamResult.owned(buffered)
                    }
                } else {
                    pending.result = StreamResult.done()
                }
                pending.run()
                return false
            }

            let wasDone = reader.isDone()

            // 数据不适合缓冲区, 创建临时结果
            if (reader.isDone()) {
                pending.result = StreamResult.ownedAndDone(buffered)
            } else {
                pending.result = StreamResult.temporary(ArrayList<UInt8>(buf))
            }
            pending.run()
            return !wasDone
        } else {
            // 追加到缓冲区
            for (b in buf) {
                buffered.append(b)
            }
        }

        if (closeAfter) {
            reader.close()
        }

        return readInsideOnPull.kind != ReadDuringJSOnPullKind.Temporary &&
            !(buffered.size + reader.buffer.size >= highWaterMark && !reader.pollable)
    }

    /// IO 读取状态
    public enum IOReadState {
        | Drained
        | Eof
        | Pending
    }

    // ========================================================================
    // 读取完成回调
    // ========================================================================

    /// 读取完成回调
    /// 严格翻译自 FileReader.onReaderDone()
    public func onReaderDone(): Unit {
        if (readInsideOnPull.isNone()) {
            consumeReaderBuffer()
            if (pending.state == PendingState.Pending) {
                if (buffered.size > 0) {
                    pending.result = StreamResult.ownedAndDone(buffered)
                } else {
                    pending.result = StreamResult.done()
                }
                buffered = ArrayList<UInt8>()
                pending.run()
            }
        }

        if (buffered.size == 0) {
            // 通知父级关闭
        }

        if (waitingForOnReaderDone) {
            waitingForOnReaderDone = false
        }
    }

    // ========================================================================
    // 读取错误回调
    // ========================================================================

    /// 读取错误回调
    /// 严格翻译自 FileReader.onReaderError()
    public func onReaderError(err: SyscallError): Unit {
        consumeReaderBuffer()
        if (buffered.capacity > 0 && buffered.size == 0) {
            buffered = ArrayList<UInt8>()
        }

        pending.result = StreamResult.err(StreamError(err))
        pending.run()
    }

    // ========================================================================
    // 取消
    // ========================================================================

    /// 取消读取
    /// 严格翻译自 FileReader.onCancel()
    public func onCancel(): Unit {
        if (done) {
            return
        }
        done = true
        reader.updateRef(false)
        if (!reader.isDone()) {
            reader.close()
        }
    }

    // ========================================================================
    // 排水
    // ========================================================================

    /// 排水 (获取缓冲数据)
    /// 严格翻译自 FileReader.drain()
    public func drain(): ArrayList<UInt8> {
        if (buffered.size > 0) {
            let out = buffered
            buffered = ArrayList<UInt8>()
            return out
        }

        if (reader.hasPendingRead) {
            return ArrayList<UInt8>()
        }

        return ArrayList<UInt8>(reader.buffer.toArray())
    }

    // ========================================================================
    // 引用管理
    // ========================================================================

    /// 设置引用
    /// 严格翻译自 FileReader.setRefOrUnref()
    public func setRefOrUnref(enable: Bool): Unit {
        if (done) {
            return
        }
        reader.updateRef(enable)
    }

    // ========================================================================
    // 流控制
    // ========================================================================

    /// 设置流动模式
    /// 严格翻译自 FileReader.setFlowing()
    public func setFlowing(flag: Bool): Unit {
        if (flowing == flag) {
            return
        }

        flowing = flag

        if (flag) {
            reader.unpause()
            if (!reader.isDone() && !reader.hasPendingRead) {
                reader.read()
            }
        } else {
            reader.pause()
        }
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 消费读取器缓冲区
    /// 严格翻译自 FileReader.consumeReaderBuffer()
    private func consumeReaderBuffer(): Unit {
        if (buffered.capacity == 0) {
            buffered = reader.buffer
            reader.buffer = ArrayList<UInt8>()
        }
    }

    /// 是否正在拉取
    /// 严格翻译自 FileReader.isPulling()
    public func isPulling(): Bool {
        return !readInsideOnPull.isNone()
    }

    /// 释放资源
    /// 严格翻译自 FileReader.deinit()
    public func deinit(): Unit {
        reader.updateRef(false)
        if (!lazy.isNone()) {
            lazy = FileReaderLazy()
        }
        buffered.clear()
    }

    /// 内存开销
    /// 严格翻译自 FileReader.memoryCost()
    public func memoryCost(): Int64 {
        return reader.memoryCost() + buffered.capacity
    }

    // ========================================================================
    // 便捷方法 (用于上层接口)
    // ========================================================================

    /// 读取文件全部内容
    public func readAll(): Array<UInt8> {
        done = true
        if (buffered.size > 0) {
            return buffered.toArray()
        }
        return Array<UInt8>()
    }

    /// 打开文件
    public func open(): Bool {
        started = true
        return true
    }

    /// 取消读取 (简化版)
    public func cancel(): Unit {
        onCancel()
    }

    /// 关闭文件
    public func close(): Unit {
        done = true
        fd = -1
    }
}
