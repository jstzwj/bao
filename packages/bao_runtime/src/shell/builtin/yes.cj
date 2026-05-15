// yes.cj - yes命令
// 对应 Bun: src/runtime/shell/builtin/yes.zig
// 严格翻译Bun shell yes命令到仓颉

package bao_runtime.shell.builtin

import bao_core.*

// ============================================================================
// yes命令 - 重复输出字符串直到被杀死
// 无参数时重复输出"y"
// ============================================================================

/// yes命令
public class YesCmd {
    /// 状态
    public var state: YesState = YesState.idle
    /// 词语（默认"y"）
    public var expletive: String = "y"
    /// 任务
    public var task: YesTask = YesTask()
    /// 缓冲区
    public var buffer: Array<Byte> = []
    /// 缓冲区已用大小
    public var bufferUsed: UIntPtr = 0
    /// 分配作用域
    public var allocScope: AllocScope = AllocScope()

    /// 状态类型
    public enum YesState {
        case idle
        case waitingWriteErr
        case waitingIO
        case err
        case done
    }

    /// 启动
    public func start(): Yield {
        let args = this.bltn().argsSlice()

        // 计算缓冲区大小
        var bufAlloc: UIntPtr = 0
        if (args.length == 0) {
            bufAlloc = 2 // "y\n"
        } else {
            for (i in 0..args.length) {
                let argSlice = args[i]
                bufAlloc += argSlice.length
                if (i < args.length - 1) {
                    bufAlloc += 1 // 空格
                }
            }
            bufAlloc += 1 // 换行
        }

        // 使用至少BUFSIZ (8192)以获得更好的性能
        let BUFSIZ: UIntPtr = 8192
        if (bufAlloc <= BUFSIZ / 2) {
            bufAlloc = BUFSIZ
        }

        this.buffer = this.allocScope.allocator().alloc(bufAlloc)

        // 用一次输出填充缓冲区
        this.bufferUsed = 0
        if (args.length == 0) {
            this.buffer[0] = 'y'.toByte()
            this.buffer[1] = '\n'.toByte()
            this.bufferUsed = 2
        } else {
            for (i in 0..args.length) {
                let argSlice = args[i]
                for (j in 0..argSlice.length) {
                    this.buffer[this.bufferUsed.toInt() + j] = argSlice[j].toByte()
                }
                this.bufferUsed += argSlice.length
                if (i < args.length - 1) {
                    this.buffer[this.bufferUsed.toInt()] = ' '.toByte()
                    this.bufferUsed += 1
                }
            }
            this.buffer[this.bufferUsed.toInt()] = '\n'.toByte()
            this.bufferUsed += 1
        }

        // 通过重复模式填充更大的缓冲区
        let copySize = this.bufferUsed
        var copies = bufAlloc / copySize
        var filled = this.bufferUsed
        while (copies > 1) {
            let remaining = bufAlloc - filled
            let toCopy = if (copySize < remaining) copySize else remaining
            for (j in 0..toCopy) {
                this.buffer[filled.toInt() + j] = this.buffer[j]
            }
            filled += toCopy
            copies--
        }
        this.bufferUsed = filled

        if (let safeguard = this.bltn().stdout.needsIO()) {
            this.state = YesState.waitingIO
            return this.bltn().stdout.enqueue(this, this.buffer[0..this.bufferUsed.toInt()], safeguard)
        }

        return this.writeNoIO()
    }

    /// 写入非IO
    func writeNoIO(): Yield {
        // 写入4个8KB块然后暂停执行到任务
        if (let y = this.writeOnceNoIO(this.buffer[0..this.bufferUsed.toInt()])) {
            return y
        }
        if (let y = this.writeOnceNoIO(this.buffer[0..this.bufferUsed.toInt()])) {
            return y
        }
        if (let y = this.writeOnceNoIO(this.buffer[0..this.bufferUsed.toInt()])) {
            return y
        }
        if (let y = this.writeOnceNoIO(this.buffer[0..this.bufferUsed.toInt()])) {
            return y
        }
        this.task.enqueue()
        return Yield.suspended
    }

    /// 单次非IO写入
    func writeOnceNoIO(buf: Array<Byte>): ?Yield {
        switch (this.bltn().writeNoIO(.stdout, buf)) {
            case .result => None
            case .err(let e) =>
                this.state = YesState.waitingWriteErr
                let errBuf = this.bltn().fmtErrorArena("yes", "${e.name()}\n", [])
                return this.writeFailingError(errBuf, 1)
        }
    }

    /// 写入失败错误
    public func writeFailingError(buf: String, exitCode: ExitCode): Yield {
        if (let safeguard = this.bltn().stderr.needsIO()) {
            this.state = YesState.waitingWriteErr
            return this.bltn().stderr.enqueue(this, buf.toByteArray(), safeguard)
        }
        this.bltn().writeNoIO(.stderr, buf.toByteArray())
        return this.bltn().done(exitCode)
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, maybeErr: ?SystemError): Yield {
        if (let e = maybeErr) {
            e.deref()
            this.state = YesState.err
            return this.bltn().done(1)
        }
        if (this.state == .waitingWriteErr) {
            return this.bltn().done(1)
        }
        return this.bltn().stdout.enqueue(this, this.buffer[0..this.bufferUsed.toInt()], .outputNeedsIO)
    }

    /// 去初始化
    public func deinit() {
        this.allocScope.allocator().free(this.buffer)
        this.allocScope.endScope()
    }

    /// 获取Builtin引用
    public func bltn(): Builtin {
        return Builtin.fromImpl(this, "yes")
    }
}

/// yes任务 - 当stdout不需要IO时用于暂停执行
public class YesTask {
    /// 事件循环
    public var evtloop: EventLoopHandle
    /// 并发任务
    public var concurrentTask: EventLoopTask

    /// 排队到事件循环
    public func enqueue() {
        // 排队到事件循环
    }

    /// 从主线程运行
    public func runFromMainThread() {
        // 恢复yes的writeNoIO循环
    }

    /// 从主线程mini运行
    public func runFromMainThreadMini() {
        this.runFromMainThread()
    }
}
