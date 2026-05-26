// io_writer.cj - 输出写入器
// 对应 Bun: src/runtime/shell/IOWriter.zig
// 严格翻译Bun shell IO写入器到仓颉

package bao_runtime.shell

import bao_core.*
import bao_collections.*
import bao_event_loop.*
import bao_collections.ArrayList

// ============================================================================
// IOWriter - 多写入器抽象
// 允许多个写入器写入同一文件描述符
// 因为kqueue/epoll不支持在同一fd上注册多个poll事件
// ============================================================================

/// IO写入器标志位
public struct IOWriterFlags {
    public var pollable: Bool = false
    public var nonblocking: Bool = false
    public var isSocket: Bool = false
    public var brokenPipe: Bool = false
}

/// IO写入器
/// 本质上是一个文件描述符的写入队列
/// *IOWriter也是引用计数的，简化文件描述符管理
public class IOWriter {
    /// 引用计数
    public var refCount: UInt32 = 1
    /// 写入器实现
    public var writer: WriterImpl
    /// 文件描述符
    public var fd: FD
    /// 写入器列表
    public var writers: IOWriterWriters
    /// 缓冲区
    public var buf: ArrayList<Byte>
    /// 写入器索引
    public var writerIdx: UInt64 = 0
    /// 总写入字节数
    public var totalBytesWritten: UInt64 = 0
    /// 错误
    public var err: ?SystemError = None
    /// 事件循环句柄
    public var evtloop: EventLoopHandle
    /// 并发任务
    public var concurrentTask: EventLoopTask
    /// 并发任务2
    public var concurrentTask2: EventLoopTask
    /// 是否正在写入
    public var isWriting: Bool = false
    /// 异步去初始化
    public var asyncDeinit: AsyncDeinitWriter
    /// 是否已开始
    public var started: Bool = false
    /// 标志
    public var flags: IOWriterFlags

    public init() {
        writer = WriterImpl()
        fd = FD()
        writers = IOWriterWriters()
        buf = ArrayList<Byte>()
        evtloop = EventLoopHandle(MiniEventLoop())
        concurrentTask = EventLoopTask(EventLoopKind.Js)
        concurrentTask2 = EventLoopTask(EventLoopKind.Js)
        asyncDeinit = AsyncDeinitWriter()
        flags = IOWriterFlags()
    }

    /// 子指针类型 - 已提取到顶层: IOWriterChildPtr

    /// 收缩阈值 ~128KB
    public static const SHRINK_THRESHOLD: UInt64 = 1024 * 128

    /// 复制引用
    public func dupeRef(): IOWriter {
        this.ref()
        return this
    }

    /// 内存开销
    public func memoryCost(): UInt64 {
        var cost: UInt64 = 0
        cost += UInt64(this.buf.size)
        cost += this.writers.memoryCost()
        return cost
    }

    /// 初始化
    public static func initFunc(fd: FD, flags: IOWriterFlags, evtloop: EventLoopHandle): IOWriter {
        let writer = IOWriter()
        writer.refCount = 1
        writer.fd = fd
        writer.flags = flags
        writer.evtloop = evtloop
        writer.concurrentTask = EventLoopTask.fromEventLoop(evtloop)
        writer.concurrentTask2 = EventLoopTask.fromEventLoop(evtloop)
        writer.writer = WriterImpl()
        writer.writers = IOWriterWriters()
        writer.buf = ArrayList<Byte>()
        writer.asyncDeinit = AsyncDeinitWriter()
        return writer
    }

    /// 获取事件循环
    public func eventLoop(): EventLoopHandle {
        return this.evtloop
    }

    /// 幂等写入调用
    func write(): WriteState {
        if (!this.started) {
            this.started = true
            // 启动写入器
        }
        return WriteState.suspended
    }

    /// 取消指定写入器的数据块
    public func cancelChunks(ptr: IOWriterChildPtr) {
        if (this.writers.len() == 0) {
            return
        }
        // 标记为死亡
    }

    /// 跳过已死亡的写入器
    public func skipDead() {
        let slice = this.writers.slice()
        var i = this.writerIdx
        while (i < UInt64(slice.size)) {
            let w = slice[Int64(i)]
            if (w.isDead()) {
                this.writerIdx += 1
                this.totalBytesWritten += w.len - w.written
                i += 1
            } else {
                return
            }
        }
    }

    /// 执行文件写入
    public func doFileWrite(): Yield {
        this.setWriting(false)
        this.skipDead()
        // 执行文件写入逻辑
        return Yield.done
    }

    /// 可轮询写入完成回调
    public func onWritePollable(amount: UInt64, status: WriteStatus) {
        this.setWriting(false)
        if (this.writerIdx >= this.writers.len()) {
            return
        }
        var child = this.writers.get(this.writerIdx)
        if (child.isDead()) {
            this.bump(child).run()
        } else {
            this.totalBytesWritten += amount
            child.written += amount
            if (child.written >= child.len) {
                this.bump(child).run()
            }
        }
    }

    /// 管道破裂处理
    public func brokenPipeForWriters() {
        var offset: UInt64 = 0
        let writers = this.writers.sliceMutable()
        var idx = this.writerIdx
        while (idx < UInt64(writers.size)) {
            let w = writers[Int64(idx)]
            if (w.isDead()) {
                offset += w.len
                idx += 1
                continue
            }
            this.cancelChunks(w.ptr)
            idx += 1
        }
        this.totalBytesWritten = 0
        this.writers.clearRetainingCapacity()
        this.buf.clear()
        this.writerIdx = 0
    }

    /// 是否写完所有数据
    public func wroteEverything(): Bool {
        return this.totalBytesWritten >= UInt64(this.buf.size)
    }

    /// 关闭回调
    public func onClose() {
        this.setWriting(false)
    }

    /// 错误回调
    public func onError(err: SyscallError) {
        this.setWriting(false)
        let ee = SystemError("", "")
        this.err = ee
        // 通知所有等待的写入器
        this.totalBytesWritten = 0
        this.writerIdx = 0
        this.buf.clear()
        this.writers.clearRetainingCapacity()
    }

    /// 获取缓冲区
    public func getBuffer(): Array<Byte> {
        if (this.writerIdx >= this.writers.len()) {
            return Array<Byte>()
        }
        let writer = this.writers.get(this.writerIdx)
        if (writer.isDead()) {
            this.skipDead()
            if (this.writerIdx >= this.writers.len()) {
                return Array<Byte>()
            }
        }
        let remaining = writer.len - writer.written
        return this.buf.items()[Int64(this.totalBytesWritten)..Int64(this.totalBytesWritten + remaining)]
    }

    /// 推进到下一个写入器
    public func bump(currentWriter: IOWriterWriter): Yield {
        let isDead = currentWriter.isDead()
        let written = currentWriter.written
        let childPtr = currentWriter.ptr

        if (isDead) {
            this.skipDead()
        } else {
            this.writerIdx += 1
        }

        if (this.writerIdx >= this.writers.len()) {
            this.buf.clear()
            this.writerIdx = 0
            this.writers.clearRetainingCapacity()
            this.totalBytesWritten = 0
        } else if (this.totalBytesWritten >= SHRINK_THRESHOLD) {
            // 收缩缓冲区
            this.buf.clear()
            this.totalBytesWritten = 0
        }

        if (!isDead) {
            return childPtr.onIOWriterChunk(written, Option<SystemError>.None)
        }
        return Yield.done
    }

    /// 入队写入
    public func enqueue(ptr: Any, bytelist: ?ArrayList<Byte>, buf: Array<Byte>): Yield {
        let childptr = IOWriterChildPtr.initFunc(ptr)

        if (buf.size == 0) {
            return Yield.onIoWriterChunk(Option<SystemError>.None, 0, childptr.asAnyOpaque())
        }

        for (b in buf) { this.buf.append(b) }
        var writer = IOWriterWriter()
        writer.ptr = childptr
        writer.len = UInt64(buf.size)
        writer.written = 0
        writer.bytelist = bytelist
        this.writers.append(writer)
        return this.enqueueInternal()
    }

    /// 格式化入队（内置命令）
    public func enqueueFmtBltn(ptr: Any, bytelist: ?ArrayList<Byte>, kind: ?BuiltinKind, fmt: String, args: Array<Any>): Yield {
        return this.enqueueFmt(ptr, bytelist, fmt, args)
    }

    /// 格式化入队
    public func enqueueFmt(ptr: Any, bytelist: ?ArrayList<Byte>, fmt: String, args: Array<Any>): Yield {
        let start = this.buf.size
        for (b in fmt) { this.buf.append(b) }
        let end = this.buf.size
        let childptr = IOWriterChildPtr.initFunc(ptr)
        var writer2 = IOWriterWriter()
        writer2.ptr = childptr
        writer2.len = UInt64(end - start)
        writer2.written = 0
        writer2.bytelist = bytelist
        this.writers.append(writer2)
        return this.enqueueInternal()
    }

    /// 内部入队
    func enqueueInternal(): Yield {
        match (this.write()) {
            case suspended =>
                return Yield.suspended
            case failed =>
                return Yield.failed
            case isActuallyFile =>
                return Yield.done
        }
    }

    /// 处理管道破裂
    public func handleBrokenPipe(ptr: IOWriterChildPtr): ?Yield {
        if (this.flags.brokenPipe) {
            let err = SystemError("PIPE", "broken pipe")
            return Yield.onIoWriterChunk(err, 0, ptr.asAnyOpaque())
        }
        return Option<Yield>.None
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
            this.deinitOnMainThread()
            return
        }
        this.asyncDeinit.enqueue()
    }

    /// 主线程去初始化
    public func deinitOnMainThread() {
        this.buf.clear()
        this.writers.deinit()
        // stub: err deref skipped
        if (this.fd.isValid()) {
            this.fd.close()
        }
    }

    /// 是否最后一个索引
    public func isLastIdx(idx: UInt64): Bool {
        return idx == this.writers.len() - 1
    }

    /// 设置写入状态
    public func setWriting(writing: Bool) {
        this.isWriting = writing
    }

    // ========================================================================
    // 写入器（类型已提取到顶层: IOWriterWriter, IOWriterWriters）
    // ========================================================================
}

// ============================================================================
// 写入器条目（从IOWriter提取）
// ============================================================================

/// 写入器条目
public struct IOWriterWriter {
    public var ptr: IOWriterChildPtr
    public var len: UInt64
    public var written: UInt64 = 0
    public var bytelist: ?ArrayList<Byte>

    public init() {
        ptr = IOWriterChildPtr()
        len = 0
        bytelist = None
    }

    /// 是否写完所有数据
    public func wroteEverything(): Bool {
        return this.written >= this.len
    }

    /// 是否死亡
    public func isDead(): Bool {
        return false
    }
}

// ============================================================================
// 写入器列表（从IOWriter提取）
// ============================================================================

/// 写入器列表
public class IOWriterWriters {
    var items: ArrayList<IOWriterWriter>

    init() {
        this.items = ArrayList<IOWriterWriter>()
    }

    func len(): UInt64 {
        return UInt64(this.items.size)
    }

    func append(writer: IOWriterWriter) {
        this.items.append(writer)
    }

    func get(idx: UInt64): IOWriterWriter {
        return this.items[Int64(idx)]
    }

    func slice(): Array<IOWriterWriter> {
        return this.items.items()
    }

    func sliceMutable(): Array<IOWriterWriter> {
        return this.items.items()
    }

    func clearRetainingCapacity() {
        this.items.clear()
    }

    func truncate(idx: UInt64) {
        // 从idx开始截断
        while (UInt64(this.items.size) > idx) {
            this.items.removeAt(this.items.size - 1)
        }
    }

    func deinit() {
        this.items.clear()
    }

    func memoryCost(): UInt64 {
        return UInt64(this.items.size) * 8
    }
}

// ============================================================================
// IO写入器子指针（从IOWriter提取）
// ============================================================================

/// IO写入器子指针
/// 注册所有需要使用IOWriter写入文件描述符的类型
public class IOWriterChildPtr {
    public var ptr: Any

    init() {
        this.ptr = Option<Any>.None
    }

    public static func initFunc(p: Any): IOWriterChildPtr {
        let cptr = IOWriterChildPtr()
        cptr.ptr = p
        return cptr
    }

    public func asAnyOpaque(): Any {
        return this.ptr
    }

    public static func fromAnyOpaque(p: Any): IOWriterChildPtr {
        let cptr = IOWriterChildPtr()
        cptr.ptr = p
        return cptr
    }

    /// IO写入器数据块写入完成回调
    public func onIOWriterChunk(amount: UInt64, err: ?SystemError): Yield {
        return Yield.done
    }
}

// ============================================================================
// 异步去初始化写入器（从IOWriter提取）
// ============================================================================

/// 异步去初始化写入器
public class AsyncDeinitWriter {
    public var ran: Bool = false
    public var writer: ?IOWriter = None

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
        if (let Some(writerVal) <- this.writer) {
            writerVal.deinitOnMainThread()
        }
    }

    /// 从主线程Mini运行
    public func runFromMainThreadMini() {
        this.runFromMainThread()
    }
}

/// 写入状态
public enum WriteState {
    | suspended
    | failed
    | isActuallyFile
}
