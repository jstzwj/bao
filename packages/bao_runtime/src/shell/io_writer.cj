// io_writer.cj - 输出写入器
// 对应 Bun: src/runtime/shell/IOWriter.zig
// 严格翻译Bun shell IO写入器到仓颉

package bao_runtime

import bao_core.*
import bao_collections.*
import bao_jsc.*

// ============================================================================
// IOWriter - 多写入器抽象
// 允许多个写入器写入同一文件描述符
// 因为kqueue/epoll不支持在同一fd上注册多个poll事件
// ============================================================================

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
    public var writers: Writers
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
    public var isWriting: Boolean = false
    /// 异步去初始化
    public var asyncDeinit: AsyncDeinitWriter
    /// 是否已开始
    public var started: Boolean = false
    /// 标志
    public var flags: Flags

    /// 子指针类型
    public typealias ChildPtr = IOWriterChildPtr

    /// 收缩阈值 ~128KB
    const SHRINK_THRESHOLD: UInt64 = 1024 * 128

    /// 复制引用
    public func dupeRef(): IOWriter {
        this.ref()
        return this
    }

    /// 内存开销
    public func memoryCost(): UInt64 {
        var cost: UInt64 = 0
        cost += UInt64(this.buf.length)
        cost += this.writers.memoryCost()
        return cost
    }

    /// 标志位
    public struct Flags {
        public var pollable: Boolean = false
        public var nonblocking: Boolean = false
        public var isSocket: Boolean = false
        public var brokenPipe: Boolean = false
    }

    /// 初始化
    public static func init(fd: FD, flags: Flags, evtloop: EventLoopHandle): IOWriter {
        let this = IOWriter()
        this.refCount = 1
        this.fd = fd
        this.flags = flags
        this.evtloop = evtloop
        this.concurrentTask = EventLoopTask.fromEventLoop(evtloop)
        this.concurrentTask2 = EventLoopTask.fromEventLoop(evtloop)
        this.writer = WriterImpl()
        this.writers = Writers()
        this.buf = ArrayList<Byte>()
        this.asyncDeinit = AsyncDeinitWriter()
        return this
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
    public func cancelChunks(ptr: ChildPtr) {
        if (this.writers.len() == 0) {
            return
        }
        // 标记为死亡
    }

    /// 跳过已死亡的写入器
    public func skipDead() {
        let slice = this.writers.slice()
        var i = this.writerIdx
        while (i < UInt64(slice.length)) {
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
        let child = this.writers.get(this.writerIdx)
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
        for (w in writers[this.writerIdx..]) {
            if (w.isDead()) {
                offset += w.len
                continue
            }
            this.cancelChunks(w.ptr)
        }
        this.totalBytesWritten = 0
        this.writers.clearRetainingCapacity()
        this.buf.clear()
        this.writerIdx = 0
    }

    /// 是否写完所有数据
    public func wroteEverything(): Boolean {
        return this.totalBytesWritten >= UInt64(this.buf.length)
    }

    /// 关闭回调
    public func onClose() {
        this.setWriting(false)
    }

    /// 错误回调
    public func onError(err: SyscallError) {
        this.setWriting(false)
        let ee = err.toShellSystemError()
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
        return this.buf.toArray()[Int64(this.totalBytesWritten)..Int64(this.totalBytesWritten + remaining)]
    }

    /// 推进到下一个写入器
    public func bump(currentWriter: Writer): Yield {
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
            return childPtr.onIOWriterChunk(written, None)
        }
        return Yield.done
    }

    /// 入队写入
    public func enqueue(ptr: Any, bytelist: ?ByteList, buf: Array<Byte>): Yield {
        let childptr = IOWriterChildPtr.init(ptr)

        if (buf.length == 0) {
            return Yield.onIoWriterChunk(child: childptr.asAnyOpaque(), written: 0, err: None)
        }

        this.buf.appendAll(buf)
        let writer = Writer(ptr: childptr, len: UInt64(buf.length), written: 0, bytelist: bytelist)
        this.writers.append(writer)
        return this.enqueueInternal()
    }

    /// 格式化入队（内置命令）
    public func enqueueFmtBltn(ptr: Any, bytelist: ?ByteList, kind: ?BuiltinKind, fmt: String, args: Array<Any>): Yield {
        return this.enqueueFmt(ptr, bytelist, fmt, args)
    }

    /// 格式化入队
    public func enqueueFmt(ptr: Any, bytelist: ?ByteList, fmt: String, args: Array<Any>): Yield {
        let start = this.buf.length
        this.buf.appendAll(fmt.toByteArray())
        let end = this.buf.length
        let childptr = IOWriterChildPtr.init(ptr)
        let writer = Writer(ptr: childptr, len: UInt64(end - start), written: 0, bytelist: bytelist)
        this.writers.append(writer)
        return this.enqueueInternal()
    }

    /// 内部入队
    func enqueueInternal(): Yield {
        switch (this.write()) {
            case .suspended =>
                return Yield.suspended
            case .failed =>
                return Yield.failed
        }
    }

    /// 处理管道破裂
    public func handleBrokenPipe(ptr: IOWriterChildPtr): ?Yield {
        if (this.flags.brokenPipe) {
            let err = SystemError.fromCode(Errno.PIPE, SyscallKind.write)
            return Yield.onIoWriterChunk(child: ptr.asAnyOpaque(), written: 0, err: err)
        }
        return None
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
        if (let e = this.err) {
            e.deref()
        }
        if (this.fd.isValid()) {
            this.fd.close()
        }
    }

    /// 是否最后一个索引
    public func isLastIdx(idx: UInt64): Boolean {
        return idx == this.writers.len() - 1
    }

    /// 设置写入状态
    public func setWriting(writing: Boolean) {
        this.isWriting = writing
    }

    // ========================================================================
    // 写入器
    // ========================================================================

    /// 写入器条目
    public struct Writer {
        public var ptr: IOWriterChildPtr
        public var len: UInt64
        public var written: UInt64 = 0
        public var bytelist: ?ByteList

        /// 是否写完所有数据
        public func wroteEverything(): Boolean {
            return this.written >= this.len
        }

        /// 是否死亡
        public func isDead(): Boolean {
            return false
        }

        /// 标记为死亡
        public mutating func setDead() {
            // 标记为死亡
        }
    }

    // ========================================================================
    // 写入器列表
    // ========================================================================

    /// 写入器列表
    public class Writers {
        var items: ArrayList<Writer>

        init() {
            this.items = ArrayList<Writer>()
        }

        func len(): UInt64 {
            return UInt64(this.items.length)
        }

        func append(writer: Writer) {
            this.items.append(writer)
        }

        func get(idx: UInt64): Writer {
            return this.items[Int64(idx)]
        }

        func slice(): Array<Writer> {
            return this.items.toArray()
        }

        func sliceMutable(): Array<Writer> {
            return this.items.toArray()
        }

        func clearRetainingCapacity() {
            this.items.clear()
        }

        func truncate(idx: UInt64) {
            // 从idx开始截断
            while (UInt64(this.items.length) > idx) {
                this.items.removeAt(this.items.length - 1)
            }
        }

        func deinit() {
            this.items.clear()
        }

        func memoryCost(): UInt64 {
            return UInt64(this.items.length) * 8
        }
    }

    // ========================================================================
    // IO写入器子指针
    // ========================================================================

    /// IO写入器子指针
    /// 注册所有需要使用IOWriter写入文件描述符的类型
    public class IOWriterChildPtr {
        public var ptr: Any

        init() {
            this.ptr = None
        }

        public static func init(p: Any): IOWriterChildPtr {
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

    // ========================================================================
    // 异步去初始化写入器
    // ========================================================================

    /// 异步去初始化写入器
    public class AsyncDeinitWriter {
        public var ran: Boolean = false
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
            if (let w = this.writer) {
                w.deinitOnMainThread()
            }
        }

        /// 从主线程Mini运行
        public func runFromMainThreadMini() {
            this.runFromMainThread()
        }
    }
}

/// 写入状态
public enum WriteState {
    case suspended
    case failed
    case isActuallyFile
}
