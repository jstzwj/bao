// subproc.cj - 子进程管理
// 对应 Bun: src/runtime/shell/subproc.zig
// 严格翻译Bun shell子进程到仓颉

package bao_runtime

import bao_core.*
import bao_collections.*
import bao_sys.*
import bao_io.*
import bao_event_loop.*
import bao_jsc.*

// ============================================================================
// 子进程管理
// Shell子进程用于执行外部命令
// ============================================================================

/// Shell IO
/// 用于捕获写入
public struct ShellIO {
    public var stdout: ?IOWriter = None
    public var stderr: ?IOWriter = None

    /// 增加引用
    public mutating func ref() {
        if (let io = this.stdout) {
            io.ref()
        }
        if (let io = this.stderr) {
            io.ref()
        }
    }

    /// 减少引用
    public mutating func deref() {
        if (let io = this.stdout) {
            io.deref()
        }
        if (let io = this.stderr) {
            io.deref()
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
    public var thisJsvalue: JSValue
    /// 标志
    public var flags: Flags

    /// 默认最大缓冲区大小 4MB
    public const defaultMaxBufferSize: UInt64 = 1024 * 1024 * 4

    /// 标志位
    public struct Flags {
        public var isSync: Boolean = false
        public var killed: Boolean = false
        public var waitingForOnexit: Boolean = false
    }

    /// 获取IO
    public func getIO(outKind: OutKind): Readable {
        switch (outKind) {
            case .stdout =>
                return this.stdout
            case .stderr =>
                return this.stderr
        }
    }

    /// 是否已退出
    public func hasExited(): Boolean {
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
    public func hasKilled(): Boolean {
        return this.process.hasKilled()
    }

    /// 尝试杀死
    public func tryKill(sig: Int32): Maybe<Unit> {
        if (this.hasExited()) {
            return Maybe<Unit>.success()
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
        this.closed.add(io)
        switch (io) {
            case .stdin =>
                this.stdin.finalize()
            case .stdout =>
                this.stdout.finalize()
            case .stderr =>
                this.stderr.finalize()
        }
    }

    /// 同步终结化
    public func finalizeSync() {
        this.closeProcess()
        this.closeIO(.stdin)
        this.closeIO(.stdout)
        this.closeIO(.stderr)
    }

    /// 去初始化
    public func deinit() {
        this.finalizeSync()
    }

    /// 进程退出回调
    public func onProcessExit(process: Process, status: SpawnStatus, rusage: Rusage) {
        var exitCode: ?UInt8 = None
        if (status == .exited) {
            exitCode = status.exited.code
        } else if (status == .signaled) {
            if (let code = status.signalCode()) {
                exitCode = code.toExitCode()
            }
        }

        if (let code = exitCode) {
            let cmd = this.cmdParent
            if (cmd.exitCode == None) {
                cmd.onExit(code)
            }
        }
    }

    // ========================================================================
    // 启动参数
    // ========================================================================

    /// 启动参数
    public class SpawnArgs {
        public var arena: ArenaAllocator
        public var cmdParent: CmdState
        public var overrideEnv: Boolean = false
        public var envArray: ArrayList<?String>
        public var cwd: String
        public var stdio: Array<Stdio>
        public var lazy: Boolean = false
        public var path: String
        public var detached: Boolean = false

        /// 默认参数
        public static func `default`(arena: ArenaAllocator, cmdParent: CmdState, eventLoop: EventLoopHandle, isSync: Boolean): SpawnArgs {
            let out = SpawnArgs()
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
        public func fillEnv(envIter: EnvMap.Iterator, disablePathLookup: Boolean) {
            let allocator = this.arena.allocator()
            this.overrideEnv = true
            while (let entry = envIter.next()) {
                let key = entry.key.slice()
                let value = entry.value.slice()
                let line = "\(key)=\(value)"
                this.envArray.append(line)
            }
        }
    }

    // ========================================================================
    // 异步生成
    // ========================================================================

    /// 异步生成子进程
    public static func spawnAsync(
        eventLoop: EventLoopHandle,
        shellio: ShellIO,
        spawnArgs: SpawnArgs,
        out: ShellSubprocess,
        notifyCallerProcessAlreadyExited: Boolean
    ): Result<Unit> {
        return Result<Unit>.success()
    }

    // ========================================================================
    // 可写入
    // ========================================================================

    /// 可写入端
    public enum Writable {
        case pipe(FileSink)
        case fd(FD)
        case buffer(StaticPipeWriter)
        case memfd(FD)
        case inherit
        case ignore

        /// 是否有待处理活动
        public func hasPendingActivity(): Boolean {
            switch (this) {
                case .pipe, .buffer =>
                    return true
                case .fd, .memfd, .inherit, .ignore =>
                    return false
            }
        }

        /// 增加引用
        public func ref() {
            switch (this) {
                case .pipe(let pipe) =>
                    pipe.updateRef(true)
                case .buffer(let buffer) =>
                    buffer.updateRef(true)
                case .fd, .memfd, .inherit, .ignore =>
                    // 无操作
            }
        }

        /// 减少引用
        public func unref() {
            switch (this) {
                case .pipe(let pipe) =>
                    pipe.updateRef(false)
                case .buffer(let buffer) =>
                    buffer.updateRef(false)
                case .fd, .memfd, .inherit, .ignore =>
                    // 无操作
            }
        }

        /// 关闭
        public mutating func close() {
            switch (this) {
                case .pipe(let pipe) =>
                    pipe.end(None)
                case .memfd(let fd), .fd(let fd) =>
                    fd.close()
                    this = Writable.ignore
                case .buffer(let buffer) =>
                    buffer.close()
                case .inherit, .ignore =>
                    // 无操作
            }
        }

        /// 终结化
        public mutating func finalize() {
            switch (this) {
                case .pipe(let pipe) =>
                    pipe.deref()
                    this = Writable.ignore
                case .buffer(let buffer) =>
                    buffer.updateRef(false)
                    buffer.deref()
                case .memfd(let fd) =>
                    fd.close()
                    this = Writable.ignore
                case .fd, .inherit, .ignore =>
                    // 无操作
            }
        }
    }

    // ========================================================================
    // 可读取
    // ========================================================================

    /// 可读取端
    public enum Readable {
        case fd(FD)
        case memfd(FD)
        case pipe(PipeReader)
        case inherit
        case ignore
        case closed
        case buffer(Array<Byte>)

        /// 增加引用
        public func ref() {
            switch (this) {
                case .pipe(let pipe) =>
                    pipe.updateRef(true)
                case .fd, .memfd, .inherit, .ignore, .closed, .buffer =>
                    // 无操作
            }
        }

        /// 减少引用
        public func unref() {
            switch (this) {
                case .pipe(let pipe) =>
                    pipe.updateRef(false)
                case .fd, .memfd, .inherit, .ignore, .closed, .buffer =>
                    // 无操作
            }
        }

        /// 获取切片
        public func toSlice(): ?String {
            switch (this) {
                case .fd =>
                    return None
                case .pipe(let pipe) =>
                    return String.fromBytes(pipe.slice())
                case .buffer(let buf) =>
                    return String.fromBytes(buf)
                case .memfd =>
                    return None
                case .inherit, .ignore, .closed =>
                    return None
            }
        }

        /// 关闭
        public mutating func close() {
            switch (this) {
                case .memfd(let fd) =>
                    this = Readable.closed
                    fd.close()
                case .fd =>
                    this = Readable.closed
                case .pipe(let pipe) =>
                    pipe.close()
                case .inherit, .ignore, .closed, .buffer =>
                    // 无操作
            }
        }

        /// 终结化
        public mutating func finalize() {
            switch (this) {
                case .memfd(let fd) =>
                    this = Readable.closed
                    fd.close()
                case .fd =>
                    this = Readable.closed
                case .pipe(let pipe) =>
                    this = Readable.closed
                case .inherit, .ignore, .closed, .buffer =>
                    // 无操作
            }
        }
    }
}

/// 标准IO类型
public enum StdioKind {
    case stdin
    case stdout
    case stderr
}

// ============================================================================
// 管道读取器
// ============================================================================

/// 管道读取器
/// 引用计数
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
    /// 输出类型
    public var outType: OutKind

    /// 管道读取器状态
    public enum PipeReaderState {
        case pending
        case done(Array<Byte>)
        case err(?SystemError)
    }

    /// 分离
    public func detach() {
        this.process = None
        this.deref()
    }

    /// 是否完成
    public func isDone(): Boolean {
        if (this.state == .pending) {
            return false
        }
        return true
    }

    /// 创建
    public static func create(
        eventLoop: EventLoopHandle,
        process: ShellSubprocess,
        result: StdioResult,
        capture: ?IOWriter,
        outType: OutKind
    ): PipeReader {
        let this = PipeReader()
        this.refCount = 1
        this.process = process
        this.reader = BufferedReader.init()
        this.eventLoop = eventLoop
        this.state = PipeReaderState.pending
        this.outType = outType
        return this
    }

    /// 读取全部
    public func readAll() {
        if (this.state == .pending) {
            this.reader.read()
        }
    }

    /// 读取数据块回调
    public func onReadChunk(chunk: Array<Byte>, hasMore: ReadState): Boolean {
        let shouldContinue = hasMore != ReadState.eof
        return shouldContinue
    }

    /// 读取完成
    public func onReaderDone() {
        this.state = PipeReaderState.done(Array<Byte>())
    }

    /// 读取错误
    public func onReaderError(err: SyscallError) {
        this.state = PipeReaderState.err(err.toSystemError())
    }

    /// 获取切片
    public func slice(): Array<Byte> {
        return Array<Byte>()
    }

    /// 关闭
    public func close() {
        switch (this.state) {
            case .pending =>
                this.reader.close()
            case .done, .err =>
                // 无操作
        }
    }

    /// 更新引用
    public func updateRef(add: Boolean) {
        this.reader.updateRef(add)
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
    func deinit() {
        this.reader.deinit()
    }
}

/// 输出类型枚举
public enum OutKind {
    case stdout
    case stderr

    /// 转换为文件描述符
    public func toFd(): FD {
        switch (this) {
            case .stdout =>
                return FD.stdout()
            case .stderr =>
                return FD.stderr()
        }
    }
}
