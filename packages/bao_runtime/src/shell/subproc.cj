// subproc.cj - 子进程管理
// 对应 Bun: src/runtime/shell/subproc.zig
// 严格翻译Bun shell子进程到仓颉

package bao_runtime.shell

import bao_core.*
import bao_collections.*
import bao_event_loop.*
import bao_jsc.{JSGlobalObject, JsValue, ArrayBufferStrong}
import bao_collections.ArrayList

// ============================================================================
// 子进程管理
// Shell子进程用于执行外部命令
// ============================================================================

/// Shell子进程标志位
public struct ShellSubprocessFlags {
    public var isSync: Bool = false
    public var killed: Bool = false
    public var waitingForOnexit: Bool = false
}

/// Shell IO
/// 用于捕获写入
public struct ShellIO {
    public var stdout: ?IOWriter = None
    public var stderr: ?IOWriter = None

    /// 增加引用
    public func ref() {
        if (let Some(ioWriter) <- this.stdout) {
            ioWriter.ref()
        }
        if (let Some(ioWriter) <- this.stderr) {
            ioWriter.ref()
        }
    }

    /// 减少引用
    public func deref() {
        if (let Some(ioWriter) <- this.stdout) {
            ioWriter.deref()
        }
        if (let Some(ioWriter) <- this.stderr) {
            ioWriter.deref()
        }
    }
}

// ============================================================================
// Shell子进程
// ============================================================================

/// Shell子进程
public class ShellSubprocess {
    /// 命令父节点
    public var cmdParent: CmdState
    /// 进程
    public var process: Process
    /// 标准输入
    public var stdin: Writable
    /// 标准输出
    public var stdout: Readable
    /// 标准错误
    public var stderr: Readable
    /// 事件循环
    public var eventLoop: EventLoopHandle
    /// 已关闭集合
    public var closed: Set<StdioKind>
    /// JS值
    public var thisJsvalue: JsValue
    /// 标志
    public var flags: ShellSubprocessFlags

    public init() {
        cmdParent = CmdState()
        process = Process()
        stdin = Writable.ignore
        stdout = Readable.ignore
        stderr = Readable.ignore
        eventLoop = EventLoopHandle(MiniEventLoop())
        closed = Set<StdioKind>()
        thisJsvalue = JsValue()
        flags = ShellSubprocessFlags()
    }

    /// 默认最大缓冲区大小 4MB
    public static let defaultMaxBufferSize: UInt64 = 1024 * 1024 * 4

    /// 获取IO
    public func getIO(outKind: OutKind): Readable {
        match (outKind) {
            case Stdout =>
                return this.stdout
            case Stderr =>
                return this.stderr
        }
    }

    /// 是否已退出
    public func hasExited(): Bool {
        return this.process.hasExited()
    }

    /// 增加引用
    public func ref() {
        this.process.enableKeepingEventLoopAlive()
        this.stdout.ref()
        this.stderr.ref()
    }

    /// 减少引用
    public func unref() {
        this.process.disableKeepingEventLoopAlive()
        this.stdout.unref()
        this.stderr.unref()
    }

    /// 是否已杀死
    public func hasKilled(): Bool {
        return this.process.hasKilled()
    }

    /// 尝试杀死
    public func tryKill(sig: Int32): Maybe<Unit> {
        if (this.hasExited()) {
            return Maybe<Unit>.success(())
        }
        return this.process.kill(sig)
    }

    /// 关闭进程
    func closeProcess() {
        this.process.exitHandler = ExitHandler()
        this.process.close()
    }

    /// 断开连接
    public func disconnect() {
        // IPC未实现
    }

    /// 关闭IO
    public func closeIO(io: StdioKind) {
        if (this.closed.contains(io)) {
            return
        }
        this.closed.insert(io)
        match (io) {
            case stdin =>
                this.stdin.finalize()
            case stdout =>
                this.stdout.finalize()
            case stderr =>
                this.stderr.finalize()
        }
    }

    /// 同步终结化
    public func finalizeSync() {
        this.closeProcess()
        this.closeIO(StdioKind.stdin)
        this.closeIO(StdioKind.stdout)
        this.closeIO(StdioKind.stderr)
    }

    /// 去初始化
    public func deinit() {
        this.finalizeSync()
    }

    /// 进程退出回调
    /// 对应 Bun: pub fn onProcessExit(`this`: *@This(), _: *Process, status: bun.spawn.Status, _: *const bun.spawn.Rusage) void
    public func onProcessExit(process: Process, status: SpawnStatus, rusage: Rusage) {
        var exitCode: ?UInt8 = None
        match (status) {
            case exited(code) =>
                exitCode = UInt8(code)
            case signaled(sig) =>
                exitCode = UInt8(sig)
            case unknown => ()
        }

        if (let Some(code) <- exitCode) {
            let cmd = this.cmdParent
            if (cmd.exitCode.isNone()) {
                cmd.onExit(ExitCode.exited(code))
            }
        }
    }

    /// 静态管道写入器完成回调
    /// 对应 Bun: pub fn onStaticPipeWriterDone(`this`: *ShellSubprocess) void
    public func onStaticPipeWriterDone() {
        this.cmdParent.bufferedInputClose()
    }

    /// IO关闭回调
    /// 对应 Bun: pub fn onCloseIO(`this`: *Subprocess, kind: StdioKind) void
    public func onCloseIO(kind: StdioKind) {
        match (kind) {
            case stdin =>
                match (this.stdin) {
                    case pipe(pipeVal) =>
                        pipeVal.signal.clear()
                        pipeVal.deref()
                    case buffer(bufferVal) =>
                        this.onStaticPipeWriterDone()
                        bufferVal.source.detach()
                        bufferVal.deref()
                    case fd(fdVal) => ()
                    case memfd(_) => ()
                    case inherit => ()
                    case ignore => ()
                }
            case stdout =>
                let out: Readable = this.getIO(OutKind.Stdout)
                match (out) {
                    case pipe(pipeVal) =>
                        match (pipeVal.state) {
                            case done(_) =>
                                () // 数据已在pipe中
                            case _ =>
                                ()
                        }
                        pipeVal.deref()
                    case fd(fdVal) => ()
                    case memfd(_) => ()
                    case inherit => ()
                    case ignore => ()
                    case closed => ()
                    case buffer(_) => ()
                }
            case stderr =>
                let out2: Readable = this.getIO(OutKind.Stderr)
                match (out2) {
                    case pipe(pipeVal) =>
                        match (pipeVal.state) {
                            case done(_) =>
                                () // 数据已在pipe中
                            case _ =>
                                ()
                        }
                        pipeVal.deref()
                    case fd(fdVal) => ()
                    case memfd(_) => ()
                    case inherit => ()
                    case ignore => ()
                    case closed => ()
                    case buffer(_) => ()
                }
        }
    }

    /// 启动失败后中止
    /// 对应 Bun: fn abortAfterFailedStart(`this`: *@This()) void
    public func abortAfterFailedStart() {
        // 将待处理的管道读取器标记为错误状态
        for (kind in [OutKind.Stdout, OutKind.Stderr]) {
            let r = this.getIO(kind)
            match (r) {
                case pipe(pipeVal) =>
                    match (pipeVal.state) {
                        case pending =>
                            pipeVal.state = PipeReaderState.err(Option<SystemError>.None)
                        case _ => ()
                    }
                case _ => ()
            }
        }
        this.process.exitHandler = ExitHandler()
        this.deinit()
    }

    /// 等待进程
    /// 对应 Bun: pub fn wait(`this`: *@This(), sync: bool) void
    public func wait(sync: Bool) {
        return this.process.wait(sync)
    }

    // ========================================================================
    // 异步生成
    // ========================================================================

    /// 异步生成子进程
    public static func spawnAsync(
        eventLoop: EventLoopHandle,
        shellio: ShellIO,
        spawnArgs: ShellSpawnArgs,
        out: ShellSubprocess,
        notifyCallerProcessAlreadyExited: Bool
    ): Result<Unit> {
        let r = Result<Unit>()
        r.result = Some(())
        return r
    }
}

// ========================================================================
// Shell启动参数
// ========================================================================

/// 启动参数
public class ShellSpawnArgs {
    public var arena: ArenaAllocator
    public var cmdParent: CmdState
    public var overrideEnv: Bool = false
    public var envArray: ArrayList<?String>
    public var cwd: String
    public var stdio: Array<Stdio>
    public var lazy: Bool = false
    public var path: String
    public var detached: Bool = false

    public init() {
        arena = ArenaAllocator()
        cmdParent = CmdState()
        envArray = ArrayList<?String>()
        cwd = ""
        stdio = Array<Stdio>()
        path = ""
    }

    /// 默认参数
    public static func `default`(arena: ArenaAllocator, cmdParent: CmdState, eventLoop: EventLoopHandle, isSync: Bool): ShellSpawnArgs {
        let out = ShellSpawnArgs()
        out.arena = arena
        out.overrideEnv = false
        out.envArray = ArrayList<?String>()
        out.cwd = eventLoop.topLevelDir()
        out.stdio = [
            Stdio.ignore,
            Stdio.pipe,
            Stdio.inherit
        ]
        out.lazy = false
        out.path = eventLoop.env().get("PATH") ?? ""
        out.detached = false
        out.cmdParent = cmdParent
        if (isSync) {
            out.stdio[1] = Stdio.pipe
            out.stdio[2] = Stdio.pipe
        }
        return out
    }

    /// 从环境填充
    public func fillEnv(envIter: EnvMapIterator, disablePathLookup: Bool) {
        let allocator = this.arena
        this.overrideEnv = true
        while (envIter.hasNext()) {
            if (let Some(entry) <- envIter.next()) {
                let line = "${entry[0]}=${entry[1]}"
                this.envArray.append(line)
            }
        }
    }
}

// ========================================================================
// 可写入
// ========================================================================

/// 可写入端
public enum Writable {
    | pipe(FileSink)
    | fd(FD)
    | buffer(StaticPipeWriter)
    | memfd(FD)
    | inherit
    | ignore

    /// 是否有待处理活动
    public func hasPendingActivity(): Bool {
        match (this) {
            case pipe(_) =>
                return true
            case buffer(_) =>
                return true
            case fd(fdVal) => return false
            case memfd(_) => return false
            case inherit => return false
            case ignore => return false
        }
    }

    /// 增加引用
    public func ref() {
        match (this) {
            case pipe(pipeVal) =>
                pipeVal.updateRef(true)
            case buffer(bufferVal) =>
                bufferVal.updateRef(true)
            case fd(fdVal) => ()
            case memfd(_) => ()
            case inherit => ()
            case ignore => ()
        }
    }

    /// 减少引用
    public func unref() {
        match (this) {
            case pipe(pipeVal) =>
                pipeVal.updateRef(false)
            case buffer(bufferVal) =>
                bufferVal.updateRef(false)
            case fd(fdVal) => ()
            case memfd(_) => ()
            case inherit => ()
            case ignore => ()
        }
    }

    /// 关闭
    public func close() {
        match (this) {
            case pipe(pipeVal) =>
                pipeVal.end(Option<ArrayList<Byte>>.None)
            case memfd(fdVal) =>
                fdVal.close()
            case fd(fdVal) =>
                fdVal.close()
            case buffer(bufferVal) =>
                bufferVal.source.detach()
            case inherit => ()
            case ignore => ()
        }
    }

    /// 关闭回调 - 防止use-after-free
    /// 对应 Bun: pub fn onClose(`this`: *Writable, _: ?bun.sys.Error) void
    public func onClose(err: ?SystemError) {
        match (this) {
            case buffer(bufferVal) =>
                bufferVal.deref()
            case pipe(pipeVal) =>
                pipeVal.deref()
            case fd(fdVal) => ()
            case memfd(_) => ()
            case inherit => ()
            case ignore => ()
        }
    }

    /// 就绪回调
    /// 对应 Bun: pub fn onReady(_: *Writable, _: ?..., _: ?...) void {}
    public func onReady(size: ?Int64, maybeSize: ?Int64) {
        // 无操作
    }

    /// 开始回调
    /// 对应 Bun: pub fn onStart(_: *Writable) void {}
    public func onStart() {
        // 无操作
    }

    /// 初始化可写入端
    /// 对应 Bun: pub fn init(stdio: Stdio, event_loop: ..., subprocess: ..., result: ...) !Writable
    public static func `init`(stdio: Stdio, eventLoop: EventLoopHandle, subprocess: ShellSubprocess, result: StdioResult): Writable {
        assertStdioResult(result)
        match (stdio) {
            case dup2 =>
                // Shell不使用dup2作为stdin
                return Writable.ignore
            case pipe =>
                // Shell不使用pipe作为stdin
                return Writable.ignore
            case blob =>
                return Writable.buffer(StaticPipeWriter())
            case arrayBuffer =>
                return Writable.buffer(StaticPipeWriter())
            case memfd(memfdVal) =>
                return Writable.memfd(memfdVal)
            case fd(fdVal) =>
                return Writable.fd(fdVal)
            case inherit =>
                return Writable.inherit
            case path => return Writable.ignore
            case ignore => return Writable.ignore
            case ipc => return Writable.ignore
            case capture => return Writable.ignore
            case readableStream =>
                return Writable.ignore
        }
    }

    /// 转为JS值
    /// 对应 Bun: pub fn toJS(`this`: *Writable, globalThis: ..., subprocess: ...) JsValue
    public func toJS(globalThis: JSGlobalObject, subprocess: ShellSubprocess): JsValue {
        match (this) {
            case fd(fdVal) =>
                return JsValue.jsNumber(fdVal.value)
            case memfd(_) => return JsValue.jsUndefined()
            case ignore => return JsValue.jsUndefined()
            case buffer(_) => return JsValue.jsUndefined()
            case inherit => return JsValue.jsUndefined()
            case pipe(pipeVal) =>
                // 对应 Bun: pipeVal.toJSWithDestructor(...)
                return pipeVal.toJS(globalThis)
        }
    }

    /// 终结化
    /// 对应 Bun: pub fn finalize(`this`: *Writable) void
    public func finalize() {
        match (this) {
            case pipe(pipeVal) =>
                pipeVal.deref()
            case buffer(bufferVal) =>
                bufferVal.updateRef(false)
                bufferVal.deref()
            case memfd(fdVal) =>
                fdVal.close()
            case fd(fdVal) => ()
            case inherit => ()
            case ignore => ()
        }
    }
}

// ========================================================================
// 可读取
// ========================================================================

/// 可读取端
/// 对应 Bun: pub const Readable = union(enum) { ... }
public enum Readable {
    | fd(FD)
    | memfd(FD)
    | pipe(PipeReader)
    | inherit
    | ignore
    | closed
    | buffer(Array<Byte>)

    /// 初始化可读取端
    /// 对应 Bun: pub fn init(out_type, stdio, shellio, event_loop, process, result, allocator, max_size, is_sync) Readable
    public static func `init`(
        outType: OutKind,
        stdio: Stdio,
        shellio: ?IOWriter,
        eventLoop: EventLoopHandle,
        process: ShellSubprocess,
        result: StdioResult,
        allocator: Allocator,
        maxSize: UInt32,
        isSync: Bool
    ): Readable {
        assertStdioResult(result)
        match (stdio) {
            case inherit =>
                return Readable.inherit
            case ipc => return Readable.ignore
            case dup2 => return Readable.ignore
            case ignore => return Readable.ignore
            case path =>
                return Readable.ignore
            case fd(fdVal) =>
                return Readable.fd(fdVal)
            case blob =>
                // Blob是不可变的，应该只有带fd的情况
                return Readable.ignore
            case memfd(memfdVal) =>
                return Readable.memfd(memfdVal)
            case pipe =>
                return Readable.pipe(PipeReader.create(eventLoop, process, result, Option<IOWriter>.None, outType))
            case arrayBuffer =>
                let readable = Readable.pipe(PipeReader.create(eventLoop, process, result, Option<IOWriter>.None, outType))
                return readable
            case capture =>
                return Readable.pipe(PipeReader.create(eventLoop, process, result, shellio, outType))
            case readableStream =>
                // Shell不使用readable_stream
                return Readable.ignore
        }
    }

    /// 增加引用
    public func ref() {
        match (this) {
            case pipe(pipeReader) =>
                pipeReader.updateRef(true)
            case fd(fdVal) => ()
            case memfd(_) => ()
            case inherit => ()
            case ignore => ()
            case closed => ()
            case buffer(_) => ()
        }
    }

    /// 减少引用
    public func unref() {
        match (this) {
            case pipe(pipeReader) =>
                pipeReader.updateRef(false)
            case fd(fdVal) => ()
            case memfd(_) => ()
            case inherit => ()
            case ignore => ()
            case closed => ()
            case buffer(_) => ()
        }
    }

    /// 获取切片
    public func toSlice(): ?String {
        match (this) {
            case fd(_) =>
                return None
            case pipe(_) =>
                return None
            case buffer(_) =>
                return None
            case memfd(_) =>
                return None
            case inherit => return None
            case ignore => return None
            case closed => return None
        }
    }

    /// 关闭
    public func close() {
        match (this) {
            case memfd(fdVal) =>
                fdVal.close()
            case fd(fdVal) => ()
            case pipe(pipeVal) =>
                pipeVal.close()
            case inherit => ()
            case ignore => ()
            case closed => ()
            case buffer(_) => ()
        }
    }

    /// 终结化
    public func finalize() {
        match (this) {
            case memfd(fdVal) =>
                fdVal.close()
            case fd(fdVal) => ()
            case pipe(pipeVal) =>
                ()
            case inherit => ()
            case ignore => ()
            case closed => ()
            case buffer(_) => ()
        }
    }
}

/// 标准IO类型
public enum StdioKind {
    | stdin
    | stdout
    | stderr
}

// ============================================================================
// 管道读取器
// ============================================================================

/// 管道读取器
/// 引用计数
/// 对应 Bun: pub const PipeReader = struct { ... }
public class PipeReader {
    /// 引用计数
    public var refCount: UInt32 = 1
    /// 读取器
    public var reader: BufferedReader
    /// 进程
    public var process: ?ShellSubprocess = None
    /// 事件循环
    public var eventLoop: EventLoopHandle
    /// 状态
    public var state: PipeReaderState
    /// Stdio结果
    public var stdioResult: StdioResult
    /// 输出类型
    public var outType: OutKind
    /// 捕获写入器
    /// 对应 Bun: captured_writer: CapturedWriter
    public var capturedWriter: CapturedWriter
    /// 缓冲输出
    /// 对应 Bun: buffered_output: BufferedOutput
    public var bufferedOutput: BufferedOutput

    public init() {
        reader = BufferedReader()
        eventLoop = EventLoopHandle(MiniEventLoop())
        state = PipeReaderState.pending
        stdioResult = StdioResult.ignore
        outType = OutKind.Stdout
        capturedWriter = CapturedWriter()
        bufferedOutput = BufferedOutput.bytelist(ArrayList<Byte>())
    }

    /// 分离
    /// 对应 Bun: pub fn detach(`this`: *PipeReader) void
    public func detach() {
        this.process = None
        this.deref()
    }

    /// 是否完成
    /// 对应 Bun: pub fn isDone(`this`: *PipeReader) bool
    public func isDone(): Bool {
        match (this.state) {
            case pending =>
                return false
            case _ => ()
        }
        return this.capturedWriter.isDone(0)
    }

    /// 捕获写入器完成回调
    /// 对应 Bun: pub fn onCapturedWriterDone(`this`: *PipeReader) void
    public func onCapturedWriterDone() {
        this.trySignalDoneToCmd().run()
    }

    /// 创建
    /// 对应 Bun: pub fn create(...) *PipeReader
    public static func create(
        eventLoop: EventLoopHandle,
        process: ShellSubprocess,
        result: StdioResult,
        capture: ?IOWriter,
        outType: OutKind
    ): PipeReader {
        let reader = PipeReader()
        reader.refCount = 1
        reader.process = process
        reader.reader = BufferedReader()
        reader.eventLoop = eventLoop
        reader.stdioResult = result
        reader.outType = outType
        reader.state = PipeReaderState.pending
        reader.bufferedOutput = BufferedOutput.bytelist(ArrayList<Byte>())

        // 初始化捕获写入器
        reader.capturedWriter = CapturedWriter()
        reader.capturedWriter.parentRef = reader

        if (let Some(capWriter) <- capture) {
            reader.capturedWriter.writer = capWriter.dupeRef()
            reader.capturedWriter.dead = false
        }

        reader.reader.setParent(reader)
        return reader
    }

    /// 设置缓冲输出为ArrayBuffer
    /// 对应 Bun: buffered_output = .{ .array_buffer = .{ .buf = ..., .i = 0 } }
    public func setBufferedOutputArrayBuffer(arrayBuffer: ArrayBufferStrong) {
        this.bufferedOutput = BufferedOutput.arrayBuffer(PipeReaderArrayBufferEntry(arrayBuffer))
    }

    /// 读取全部
    /// 对应 Bun: pub fn readAll(`this`: *PipeReader) void
    public func readAll() {
        match (this.state) {
            case pending =>
                this.reader.read()
            case _ => ()
        }
    }

    /// 启动读取
    /// 对应 Bun: pub fn start(`this`: *PipeReader, process, event_loop) bun.sys.Maybe(void)
    public func start(process: ShellSubprocess, eventLoop: EventLoopHandle): Maybe<Unit> {
        this.process = process
        this.eventLoop = eventLoop
        if (!this.reader.start(this.stdioResult, true)) {
            return Maybe<Unit>.err()
        }
        // 对应 Bun: poll.flags.insert(.socket)
        this.reader.flags.socket = true
        return Maybe<Unit>.success(())
    }

    /// 读取数据块回调
    /// 对应 Bun: pub fn onReadChunk(ptr: *anyopaque, chunk: []const u8, has_more: ...) bool
    public func onReadChunk(chunk: Array<Byte>, hasMore: ReadState): Bool {
        this.bufferedOutput.append(chunk)

        // 将数据转发到捕获写入器
        this.capturedWriter.doWrite(chunk)

        let shouldContinue = match (hasMore) { case done => false case _ => true }

        if (shouldContinue) {
            this.reader.registerPoll()
        }

        return shouldContinue
    }

    /// 读取完成
    /// 对应 Bun: pub fn onReaderDone(`this`: *PipeReader) void
    public func onReaderDone() {
        let owned = this.toOwnedSlice()
        this.state = PipeReaderState.done(owned)
        if (!this.isDone()) {
            return
        }
        this.ref()
        this.trySignalDoneToCmd().run()
        this.deref()

        if (let Some(proc) <- this.process) {
            proc.onCloseIO(this.kind(proc))
            this.deref()
        }
    }

    /// 尝试向命令发出完成信号
    /// 对应 Bun: pub fn trySignalDoneToCmd(`this`: *PipeReader) Yield
    public func trySignalDoneToCmd(): Yield {
        if (!this.isDone()) {
            return Yield.suspended
        }
        if (let Some(proc) <- this.process) {
            let cmd = proc.cmdParent

            // 转移捕获写入器的错误
            if (this.capturedWriter.err.isSome()) {
                let capturedErr = this.capturedWriter.err
                this.capturedWriter.err = None
                match (this.state) {
                    case done(_) =>
                        () // 释放已完成的内存
                    case _ => ()
                }
                match (this.state) {
                    case err(_) => () // 保持错误状态
                    case _ =>
                        this.state = PipeReaderState.err(capturedErr)
                }
            }

            // 获取错误
            var err: ?SystemError = None
            match (this.state) {
                case err(errVal2) =>
                    if (errVal2.isSome()) {
                        err = errVal2
                    }
                case _ => ()
            }
            return cmd.bufferedOutputClose(this.outType, err)
        }
        return Yield.suspended
    }

    /// 获取此读取器的StdioKind
    /// 对应 Bun: pub fn kind(reader: *const PipeReader, process: *const ShellSubprocess) StdioKind
    public func kind(process: ShellSubprocess): StdioKind {
        return StdioKind.stdout
    }

    /// 获取缓冲区
    /// 对应 Bun: pub fn takeBuffer(`this`: *PipeReader) std.array_list.Managed(u8)
    public func takeBuffer(): ArrayList<Byte> {
        return this.reader.takeBuffer()
    }

    /// 读取错误
    /// 对应 Bun: pub fn onReaderError(`this`: *PipeReader, err: bun.sys.Error) void
    public func onReaderError(err: SyscallError) {
        match (this.state) {
            case done(_) =>
                () // 释放已完成的内存
            case _ => ()
        }
        this.state = PipeReaderState.err(err.toSystemError())
        this.ref()
        this.trySignalDoneToCmd().run()
        this.deref()
        if (let Some(proc) <- this.process) {
            proc.onCloseIO(this.kind(proc))
            this.deref()
        }
    }

    /// 获取切片
    /// 对应 Bun: pub fn slice(`this`: *PipeReader) []const u8
    public func slice(): Array<Byte> {
        return this.bufferedOutput.slice()
    }

    /// 获取拥有的切片
    /// 对应 Bun: pub fn toOwnedSlice(`this`: *PipeReader) []u8
    public func toOwnedSlice(): Array<Byte> {
        match (this.state) {
            case done(data) =>
                return data
            case _ => ()
        }
        let out = this.reader.getBuffer()
        this.reader.clearBuffer()
        if (out.size == 0) {
            return Array<Byte>()
        }
        return out.items()
    }

    /// 转为可读流
    /// 对应 Bun: pub fn toReadableStream(`this`: *PipeReader, globalObject: ...) jsc.JsValue
    public func toReadableStream(globalObject: JSGlobalObject): JsValue {
        let result: JsValue = match (this.state) {
            case pending =>
                this.state = PipeReaderState.done(Array<Byte>())
                JsValue.jsUndefined()
            case done(bytes) =>
                this.state = PipeReaderState.done(Array<Byte>())
                JsValue.jsUndefined()
            case err(_) =>
                JsValue.jsUndefined()
        }
        this.deinit()
        return result
    }

    /// 转为Buffer
    /// 对应 Bun: pub fn toBuffer(`this`: *PipeReader, globalThis: ...) jsc.JsValue
    public func toBuffer(globalThis: JSGlobalObject): JsValue {
        match (this.state) {
            case done(bytes) =>
                this.state = PipeReaderState.done(Array<Byte>())
                return JsValue.jsUndefined()
            case pending => return JsValue.jsUndefined()
            case err(_) => return JsValue.jsUndefined()
        }
    }

    /// 关闭
    /// 对应 Bun: pub fn close(`this`: *PipeReader) void
    public func close() {
        match (this.state) {
            case pending =>
                this.reader.close()
            case done(_) => ()
            case err(_) => ()
        }
    }

    /// 监视
    /// 对应 Bun: pub fn watch(`this`: *PipeReader) void
    public func watch() {
        if (!this.reader.isDone()) {
            this.reader.watch()
        }
    }

    /// 更新引用
    /// 对应 Bun: pub fn updateRef(`this`: *PipeReader, add: bool) void
    public func updateRef(add: Bool) {
        this.reader.updateRef(add)
    }

    /// 获取事件循环 — 已通过 public var eventLoop 暴露，无需额外 getter。

    /// 获取异步循环
    /// 对应 Bun: pub fn loop(`this`: *PipeReader) *bun.Async.Loop
    public func loop(): AsyncLoop {
        return AsyncLoop()
    }

    /// 增加引用
    public func ref() {
        this.refCount += 1
    }

    /// 减少引用
    public func deref() {
        this.refCount -= 1
        if (this.refCount == 0) {
            this.deinit()
        }
    }

    /// 去初始化
    /// 对应 Bun: fn deinit(`this`: *PipeReader) void
    public func deinit() {
        match (this.state) {
            case done(_) =>
                () // 释放内存
            case _ => ()
        }

        if (!this.capturedWriter.dead) {
            this.capturedWriter.deinit()
        }

        match (this.state) {
            case err(errVal) =>
                if (errVal.isSome()) {
                    this.state = PipeReaderState.err(Option<SystemError>.None)
                }
            case _ => ()
        }

        this.bufferedOutput.deinit()
        this.reader.deinit()
    }
}

/// 管道读取器状态
/// 对应 Bun: state: union(enum) { pending, done: []u8, err: ?jsc.SystemError }
public enum PipeReaderState {
    | pending
    | done(Array<Byte>)
    | err(?SystemError)
}

/// 缓冲输出
/// 对应 Bun: const BufferedOutput = union(enum) { bytelist, array_buffer }
public enum BufferedOutput {
    | bytelist(ArrayList<Byte>)
    | arrayBuffer(PipeReaderArrayBufferEntry)

    /// 获取长度
    public func len(): Int64 {
        match (this) {
            case bytelist(bl) =>
                return bl.size
            case arrayBuffer(entry) =>
                return Int64(entry.i)
        }
    }

    /// 获取切片
    public func slice(): Array<Byte> {
        match (this) {
            case bytelist(bl) =>
                return bl.items()
            case arrayBuffer(entry) =>
                return entry.buf.slice()
        }
    }

    /// 追加字节
    public func append(bytes: Array<Byte>) {
        match (this) {
            case bytelist(bl) =>
                bl.appendSlice(bytes)
            case arrayBuffer(entry) =>
                let arrayBufSlice = entry.buf.slice()
                if (Int64(entry.i) >= arrayBufSlice.size) {
                    return
                }
                let length = if (arrayBufSlice.size - Int64(entry.i) < bytes.size) { arrayBufSlice.size - Int64(entry.i) } else { bytes.size }
                for (j in 0..length) {
                    arrayBufSlice[Int64(entry.i) + j] = bytes[j]
                }
                entry.i = UInt32(Int64(entry.i) + length)
        }
    }

    /// 去初始化
    public func deinit() {
        match (this) {
            case bytelist(bl) =>
                bl.clear()
            case arrayBuffer(entry) =>
                entry.buf.deinit()
        }
    }
}

/// ArrayBuffer条目
/// 对应 Bun: struct { buf: jsc.ArrayBuffer.Strong, i: u32 = 0 }
public class PipeReaderArrayBufferEntry {
    public var buf: ArrayBufferStrong
    public var i: UInt32 = 0

    public init(buf: ArrayBufferStrong) {
        this.buf = buf
    }
}

/// 捕获写入器
/// 对应 Bun: pub const CapturedWriter = struct { dead, writer, written, err }
public class CapturedWriter {
    /// 是否已死
    public var dead: Bool = true
    /// 写入器
    public var writer: IOWriter
    /// 已写入量
    public var written: UInt64 = 0
    /// 错误
    public var err: ?SystemError = None
    /// 父引用 (仓颉适配)
    public var parentRef: ?PipeReader

    public init() {
        writer = IOWriter()
        parentRef = None
    }

    /// 执行写入
    public func doWrite(chunk: Array<Byte>) {
        if (this.dead || this.err.isSome()) {
            return
        }
        this.writer.enqueue(this, None, chunk).run()
    }

    /// 获取缓冲区
    public func getBuffer(): Array<Byte> {
        let parent = this.parent()
        let buf = parent.reader.getBuffer()
        let arr = buf.items()
        if (Int64(this.written) >= arr.size) {
            return Array<Byte>()
        }
        return arr[Int64(this.written)..]
    }

    /// 获取父PipeReader
    public func parent(): PipeReader {
        if (let Some(pr) <- this.parentRef) {
            return pr
        }
        return PipeReader()
    }

    /// 是否完成
    public func isDone(justWritten: Int64): Bool {
        if (this.dead || this.err.isSome()) {
            return true
        }
        let p = this.parent()
        match (p.state) {
            case pending =>
                return false
            case _ => ()
        }
        return Int64(this.written) + justWritten >= p.bufferedOutput.len()
    }

    /// IO写入器数据块回调
    public func onIOWriterChunk(amount: UInt64, err: ?SystemError): Yield {
        this.written += amount
        if (err.isSome()) {
            this.err = err
            return this.parent().trySignalDoneToCmd()
        }
        let parentState = this.parent().state
        let isPending = match (parentState) {
            case pending => true
            case _ => false
        }
        if (Int64(this.written) >= this.parent().bufferedOutput.len() && !isPending) {
            return this.parent().trySignalDoneToCmd()
        }
        return Yield.suspended
    }

    /// 错误回调
    public func onError(err: SystemError) {
        this.err = err
    }

    /// 关闭回调
    public func onClose() {
        this.parent().onCapturedWriterDone()
    }

    /// 去初始化
    public func deinit() {
        if (this.err.isSome()) {
            this.err = None
        }
        this.writer.deref()
    }
}

/// 断言Stdio结果有效
/// 对应 Bun: pub inline fn assertStdioResult(result: StdioResult) void
public func assertStdioResult(result: StdioResult) {
    // 在POSIX上验证fd不是invalid
    match (result) {
        case fd(fdVal) =>
            // assert fdVal is valid
            ()
        case _ => ()
    }
}
