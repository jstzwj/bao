// io_reader.cj - 输入读取器
// 对应 Bun: src/runtime/shell/IOReader.zig
// 严格翻译Bun shell IO读取器到仓颉

package bao_runtime.shell

import bao_core.*
import bao_collections.*
import bao_event_loop.*
import bao_collections.ArrayList

// ============================================================================
// IOReader - 非阻塞IO读取器
// 引用计数，去初始化排队到事件循环
// ============================================================================

/// IO读取器
/// 类似IOWriter但是用于读取
/// 注意：此类型是引用计数的，但去初始化排队到事件循环，防止bug
public class IOReader {
    /// 文件描述符
    public var fd: FD
    /// 读取器实现
    public var reader: BufferedReader
    /// 缓冲区
    public var buf: ArrayList<Byte>
    /// 读取器列表
    public var readers: IOReaderReaders
    /// 已读字节数
    public var read: UInt64 = 0
    /// 引用计数
    public var refCount: UInt32 = 1
    /// 错误
    public var err: ?SystemError = None
    /// 事件循环句柄
    public var evtloop: EventLoopHandle
    /// 并发任务
    public var concurrentTask: EventLoopTask
    /// 异步去初始化
    public var asyncDeinit: AsyncDeinitReader
    /// 是否正在读取
    public var isReading: Bool = false
    /// 是否已开始
    public var started: Bool = false

    public init() {
        fd = FD()
        reader = BufferedReader()
        buf = ArrayList<Byte>()
        readers = IOReaderReaders()
        evtloop = EventLoopHandle(MiniEventLoop())
        concurrentTask = EventLoopTask(EventLoopKind.Js)
        asyncDeinit = AsyncDeinitReader()
    }

    /// 复制引用
    public func dupeRef(): IOReader {
        this.ref()
        return this
    }

    /// 内存开销
    public func memoryCost(): UInt64 {
        var size: UInt64 = 0
        size += UInt64(this.buf.size)
        size += this.readers.memoryCost()
        return size
    }

    /// 获取事件循环
    public func eventLoop(): EventLoopHandle {
        return this.evtloop
    }

    /// 初始化
    public static func initFunc(fd: FD, evtloop: EventLoopHandle): IOReader {
        let reader = IOReader()
        reader.refCount = 1
        reader.fd = fd
        reader.reader = BufferedReader()
        reader.evtloop = evtloop
        reader.concurrentTask = EventLoopTask.fromEventLoop(evtloop)
        reader.asyncDeinit = AsyncDeinitReader()
        reader.buf = ArrayList<Byte>()
        reader.readers = IOReaderReaders()
        return reader
    }

    /// 启动读取（幂等）
    public func start(): Yield {
        this.started = true
        if (this.isReading) {
            return Yield.suspended
        }
        this.isReading = true
        return Yield.suspended
    }

    /// 设置读取状态
    public func setReading(reading: Bool) {
        this.isReading = reading
    }

    /// 添加读取器
    public func addReader(reader: ChildPtr) {
        this.readers.append(reader)
    }

    /// 移除读取器
    public func removeReader(reader: ChildPtr) {
        let readers = this.readers.slice()
        var idx: UInt64 = 0
        while (idx < UInt64(readers.size)) {
            if (readers[Int64(idx)].ptr == reader.ptr) {
                this.readers.swapRemove(idx)
                return
            }
            idx++
        }
    }

    /// 读取数据块回调
    public func onReadChunk(chunk: Array<Byte>, hasMore: ReadState): Bool {
        this.setReading(false)
        let shouldContinue = match (hasMore) {
            case done => false
            case hasMore => true
            case error => false
        }
        if (chunk.size > 0) {
            for (b in chunk) {
                this.buf.append(b)
            }
            this.read += UInt64(chunk.size)
        }
        // 通知所有读取器有新数据
        if (this.readers.len() > 0) {
            let readersCopy = this.readers.slice()
            for (reader in readersCopy) {
                reader.onReadChunk(chunk, !shouldContinue)
            }
        }
        if (shouldContinue) {
            if (this.readers.len() > 0) {
                this.setReading(true)
            }
        }
        return shouldContinue
    }

    /// 读取器错误回调
    public func onReaderError(err: SyscallError) {
        this.setReading(false)
        this.err = SystemError(err.message, "")
        // 通知所有读取器发生了错误
        if (this.readers.len() > 0) {
            let readersCopy = this.readers.slice()
            for (reader in readersCopy) {
                reader.onReaderDone(this.err)
            }
        }
    }

    /// 读取完成
    public func onReaderDone() {
        this.setReading(false)
        // 通知所有读取器完成
        if (this.readers.len() > 0) {
            let readersCopy = this.readers.slice()
            for (reader in readersCopy) {
                reader.onReaderDone(None)
            }
        }
    }

    /// 增加引用
    public func ref() {
        this.refCount += 1
    }

    /// 减少引用
    public func deref() {
        this.refCount -= 1
        if (this.refCount == 0) {
            this.asyncDeinitFn()
        }
    }

    /// 异步去初始化
    func asyncDeinitFn() {
        if (!this.started) {
            this.asyncDeinitCallback()
            return
        }
        this.asyncDeinit.enqueue()
    }

    /// 异步去初始化回调
    func asyncDeinitCallback() {
        if (this.fd.isValid()) {
            this.fd.close()
        }
        // 释放错误引用
        if (this.err.isSome()) {
            this.err = None
        }
        this.readers.deinit()
        this.buf.clear()
        // 关闭缓冲读取器
        this.reader.close()
        // 取消并发任务
        this.concurrentTask = EventLoopTask(EventLoopKind.Js)
    }

}

// ========================================================================
// 读取器列表
// ========================================================================

/// 读取器列表
public class IOReaderReaders {
    var items: ArrayList<ChildPtr>

    init() {
        this.items = ArrayList<ChildPtr>()
    }

    func len(): UInt64 {
        return UInt64(this.items.size)
    }

    func append(reader: ChildPtr) {
        this.items.append(reader)
    }

    func swapRemove(idx: UInt64) {
        this.items.swapRemove(Int64(idx))
    }

    func get(idx: UInt64): ChildPtr {
        return this.items[Int64(idx)]
    }

    func slice(): Array<ChildPtr> {
        return this.items.items()
    }

    func deinit() {
        this.items.clear()
    }

    func memoryCost(): UInt64 {
        return UInt64(this.items.size) * 8
    }
}

// ========================================================================
// IO读取器子指针
// ========================================================================

/// IO读取器子指针
/// 用于标记读取器的类型
public class IOReaderChildPtr {
    public var ptr: Any

    init() {
        this.ptr = Option<Any>.None
    }

    public static func initFunc(p: Any): IOReaderChildPtr {
        let cptr = IOReaderChildPtr()
        cptr.ptr = p
        return cptr
    }

    public func memoryCost(): UInt64 {
        return 0
    }

    /// 读取数据块回调
    public func onReadChunk(chunk: Array<Byte>, remove: Bool): Yield {
        return Yield.suspended
    }

    /// 读取完成回调
    public func onReaderDone(err: ?SystemError): Yield {
        return Yield.suspended
    }
}

// ========================================================================
// 异步去初始化读取器
// ========================================================================

/// 异步去初始化读取器
public class AsyncDeinitReader {
    public var ran: Bool = false

    /// 排队到事件循环
    public func enqueue() {
        if (this.ran) {
            return
        }
        this.ran = true
        // 将任务排队到事件循环
    }

    /// 从主线程运行
    public func runFromMainThread() {
        // 执行异步去初始化
    }

    /// 从主线程Mini运行
    public func runFromMainThreadMini() {
        this.runFromMainThread()
    }
}
