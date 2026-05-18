// bao_io - PipeReader 管道读取器
// 严格翻译自: src/io/PipeReader.zig
//   Bun 的 PipeReader 实现了:
//     BufferedReaderVTable - 读取器虚表 (运行时类型分发)
//     PosixBufferedReader - POSIX 缓冲读取器
//     WindowsBufferedReaderVTable - Windows 读取器虚表
//     WindowsBufferedReader - Windows 缓冲读取器
//     BufferedReader - 平台选择别名
//     ReadState - 读取状态枚举
package bao_io

import bao_core.*
import bao_sys.*
import bao_collections.*

// ============================================================================
// BufferedReaderVTable - 缓冲读取器虚表
// 严格翻译自: src/io/PipeReader.zig BufferedReaderVTable
//   pub const BufferedReaderVTable = struct {
//       parent: *anyopaque = undefined,
//       fns: *const Fn = undefined,
//       pub fn init(comptime Type: type) BufferedReaderVTable
//       pub const Fn = struct {
//           onReadChunk: ?*const fn (*anyopaque, chunk: []const u8, hasMore: ReadState) bool,
//           onReaderDone: *const fn (*anyopaque) void,
//           onReaderError: *const fn (*anyopaque, bun.sys.Error) void,
//           loop: *const fn (*anyopaque) *Async.Loop,
//           eventLoop: *const fn (*anyopaque) jsc.EventLoopHandle,
//       }
//       pub fn eventLoop, loop, isStreamingEnabled, onReadChunk, onReaderDone, onReaderError
//   }
// ============================================================================

/// 缓冲读取器虚表 - 对应 Bun BufferedReaderVTable
/// 运行时类型分发 (Zig 用 comptime, Rust 用泛型, 仓颉用接口)
public class BufferedReaderVTable {
    /// 流式读取回调
    public var onReadChunk: ?(Array<UInt8>, ReadState) -> Bool
    /// 读取完成回调
    public var onReaderDone: () -> Unit
    /// 读取错误回调
    public var onReaderError: (SysError) -> Unit
    /// 获取事件循环
    public var getEventLoop: () -> EventLoopHandle
    /// 获取循环
    public var getLoop: () -> IoLoop

    public init(onReadChunk: ?(Array<UInt8>, ReadState) -> Bool,
                onReaderDone: () -> Unit,
                onReaderError: (SysError) -> Unit,
                getEventLoop: () -> EventLoopHandle,
                getLoop: () -> IoLoop) {
        this.onReadChunk = onReadChunk
        this.onReaderDone = onReaderDone
        this.onReaderError = onReaderError
        this.getEventLoop = getEventLoop
        this.getLoop = getLoop
    }

    /// 是否启用流式读取
    public func isStreamingEnabled(): Bool {
        return onReadChunk != None
    }

    /// 调用读取块回调
    public func callOnReadChunk(chunk: Array<UInt8>, hasMore: ReadState): Bool {
        if (let Some(cb) <- onReadChunk) {
            return cb(chunk, hasMore)
        }
        return false
    }

    /// 调用读取完成回调
    public func callOnReaderDone(): Unit {
        onReaderDone()
    }

    /// 调用读取错误回调
    public func callOnReaderError(err: SysError): Unit {
        onReaderError(err)
    }
}

/// 事件循环句柄 (简化)
public class EventLoopHandle {
    public var tag: EventLoopKind

    public init(tag: EventLoopKind) {
        this.tag = tag
    }
}

/// 事件循环类型
public enum EventLoopKind {
    | Js
    | Mini
}

/// IO 循环 (简化)
public class IoLoop {
    public var fd: Int64

    public init(fd: Int64) {
        this.fd = fd
    }
}

// ============================================================================
// ReaderFlags - 读取器标志位
// 严格翻译自: src/io/PipeReader.zig PosixBufferedReader.Flags
//   const Flags = packed struct(u16) {
//       is_done: bool = false,
//       pollable: bool = false,
//       nonblocking: bool = false,
//       socket: bool = false,
//       received_eof: bool = false,
//       closed_without_reporting: bool = false,
//       close_handle: bool = true,
//       memfd: bool = false,
//       use_pread: bool = false,
//       is_paused: bool = false,
//       _: u6 = 0,
//   }
// ============================================================================

/// 读取器标志位 - 对应 Bun PosixBufferedReader.Flags
public class ReaderFlags {
    public var isDone: Bool
    public var pollable: Bool
    public var nonblocking: Bool
    public var socket: Bool
    public var receivedEof: Bool
    public var closedWithoutReporting: Bool
    public var closeHandle: Bool
    public var memfd: Bool
    public var usePread: Bool
    public var isPaused: Bool

    public init() {
        isDone = false
        pollable = false
        nonblocking = false
        socket = false
        receivedEof = false
        closedWithoutReporting = false
        closeHandle = true
        memfd = false
        usePread = false
        isPaused = false
    }
}

// ============================================================================
// PosixBufferedReader - POSIX 缓冲读取器
// 严格翻译自: src/io/PipeReader.zig PosixBufferedReader
//   const PosixBufferedReader = struct {
//       handle: PollOrFd,
//       _buffer: std.array_list.Managed(u8),
//       _offset: usize = 0,
//       vtable: BufferedReaderVTable,
//       flags: Flags = .{},
//       count: usize = 0,
//       maxbuf: ?*MaxBuf = null,
//       pub fn init, start, startFileOffset, read, onPoll, done,
//              deinit, close, pause, unpause, hasPendingRead, watch, hasPendingActivity
//   }
// ============================================================================

/// POSIX 缓冲读取器 - 对应 Bun PosixBufferedReader
public class PosixBufferedReader {
    /// 轮询/文件描述符
    public var handle: PollOrFd
    /// 内部缓冲区
    public var buffer: ArrayList<UInt8>
    /// 读取偏移
    public var offset: Int64
    /// 虚表
    public var vtable: BufferedReaderVTable
    /// 标志
    public var flags: ReaderFlags
    /// 读取计数
    public var count: Int64
    /// 最大缓冲
    public var maxBufSize: Int64

    public init(vtable: BufferedReaderVTable) {
        handle = PollOrFd()
        buffer = ArrayList<UInt8>()
        offset = 0
        this.vtable = vtable
        flags = ReaderFlags()
        count = 0
        maxBufSize = Int64.MAX_VALUE
    }

    /// 是否完成 - 对应 Bun PosixBufferedReader.isDone
    public func isDone(): Bool {
        return flags.isDone || flags.receivedEof || flags.closedWithoutReporting
    }

    /// 内存开销 - 对应 Bun PosixBufferedReader.memoryCost
    public func memoryCost(): Int64 {
        return Int64(1024) + Int64(buffer.capacity)
    }

    /// 获取文件描述符 - 对应 Bun PosixBufferedReader.getFd
    public func getFd(): Int64 {
        return handle.getFd()
    }

    /// 获取文件类型 - 对应 Bun PosixBufferedReader.getFileType
    public func getFileType(): FileType {
        if (flags.socket) {
            return FileType.Socket
        }
        if (flags.pollable) {
            if (flags.nonblocking) {
                return FileType.NonblockingPipe
            }
            return FileType.Pipe
        }
        return FileType.File
    }

    /// 开始 - 对应 Bun PosixBufferedReader.start
    public func start(fd: Int64, isPollable: Bool): SysMaybe<Unit> {
        if (!isPollable) {
            buffer.clear()
            flags.isDone = false
            handle = PollOrFd(fd)
            return SysMaybe<Unit>.Ok(())
        }
        flags.pollable = true
        handle = PollOrFd(fd)
        registerPoll()
        return SysMaybe<Unit>.Ok(())
    }

    /// 开始带偏移 - 对应 Bun PosixBufferedReader.startFileOffset
    public func startFileOffset(fd: Int64, isPollable: Bool, fileOffset: Int64): SysMaybe<Unit> {
        offset = fileOffset
        flags.usePread = true
        return start(fd, isPollable)
    }

    /// 读取 - 对应 Bun PosixBufferedReader.read
    public func read(): Unit {
        if (flags.isPaused) {
            return
        }
        let fd = getFd()
        match (getFileType()) {
            case NonblockingPipe => readPipe(fd)
            case File => readFile(fd)
            case Socket => readSocket(fd)
            case Pipe => readBlockingPipe(fd)
        }
    }

    /// 轮询回调 - 对应 Bun PosixBufferedReader.onPoll
    public func onPoll(sizeHint: Int64, receivedHup: Bool): Unit {
        let fd = getFd()
        match (getFileType()) {
            case NonblockingPipe => readPipe(fd)
            case File => readFile(fd)
            case Socket => readSocket(fd)
            case Pipe => readBlockingPipe(fd)
        }
    }

    /// 完成回调 - 对应 Bun PosixBufferedReader.done
    public func done(): Unit {
        if (handle.kind != PollOrFdKind.Closed && flags.closeHandle) {
            closeHandle()
            return
        } else if (flags.closedWithoutReporting) {
            flags.closedWithoutReporting = false
        }
        finish()
        vtable.callOnReaderDone()
    }

    /// 完成 - 对应 Bun PosixBufferedReader.finish
    public func finish(): Unit {
        flags.isDone = true
    }

    /// 关闭 - 对应 Bun PosixBufferedReader.close
    public func close(): Unit {
        closeHandle()
    }

    /// 关闭句柄 - 对应 Bun PosixBufferedReader.closeHandle
    public func closeHandle(): Unit {
        if (flags.closedWithoutReporting) {
            flags.closedWithoutReporting = false
            done()
            return
        }
        if (flags.closeHandle) {
            handle.close(null, { => })
        }
    }

    /// 关闭不报告 - 对应 Bun PosixBufferedReader.closeWithoutReporting
    public func closeWithoutReporting(): Unit {
        if (getFd() != INVALID_FD) {
            flags.closedWithoutReporting = true
            if (flags.closeHandle) {
                handle.close(null, { => })
            }
        }
    }

    /// 暂停 - 对应 Bun PosixBufferedReader.pause
    public func pause(): Unit {
        if (flags.isPaused) {
            return
        }
        flags.isPaused = true
    }

    /// 恢复 - 对应 Bun PosixBufferedReader.unpause
    public func unpause(): Unit {
        if (!flags.isPaused) {
            return
        }
        flags.isPaused = false
    }

    /// 是否有待读取 - 对应 Bun PosixBufferedReader.hasPendingRead
    public func hasPendingRead(): Bool {
        return handle.kind == PollOrFdKind.Poll
    }

    /// 监视 - 对应 Bun PosixBufferedReader.watch
    public func watch(): Unit {
        if (flags.pollable) {
            registerPoll()
        }
    }

    /// 是否有活跃活动 - 对应 Bun PosixBufferedReader.hasPendingActivity
    public func hasPendingActivity(): Bool {
        match (handle.kind) {
            case PollOrFdKind.Poll => return true
            case PollOrFdKind.Fd => return true
            case PollOrFdKind.Closed => return false
        }
    }

    /// 清理 - 对应 Bun PosixBufferedReader.deinit
    public func deinit(): Unit {
        buffer.clear()
        closeWithoutReporting()
    }

    /// 错误处理 - 对应 Bun PosixBufferedReader.onError
    public func onError(err: SysError): Unit {
        vtable.callOnReaderError(err)
    }

    /// 注册轮询 - 对应 Bun PosixBufferedReader.registerPoll
    public func registerPoll(): Unit {
        // 简化: 注册可读轮询
    }

    /// 排空块 - 对应 Bun PosixBufferedReader.drainChunk
    public func drainChunk(chunk: Array<UInt8>, hasMore: ReadState): Bool {
        if (vtable.isStreamingEnabled()) {
            if (chunk.size > 0) {
                return vtable.callOnReadChunk(chunk, hasMore)
            }
        }
        return false
    }

    /// 读取管道 (非阻塞) - 对应 Bun PosixBufferedReader.readPipe
    private func readPipe(fd: Int64): Unit {
        readWithFn(fd, FileType.NonblockingPipe)
    }

    /// 读取文件 - 对应 Bun PosixBufferedReader.readFile
    private func readFile(fd: Int64): Unit {
        readWithFn(fd, FileType.File)
    }

    /// 读取套接字 - 对应 Bun PosixBufferedReader.readSocket
    private func readSocket(fd: Int64): Unit {
        readWithFn(fd, FileType.Socket)
    }

    /// 读取阻塞管道 - 对应 Bun PosixBufferedReader.readBlockingPipe
    private func readBlockingPipe(fd: Int64): Unit {
        readWithFn(fd, FileType.Pipe)
    }

    /// 使用函数读取 - 对应 Bun PosixBufferedReader.readWithFn
    private func readWithFn(fd: Int64, fileType: FileType): Unit {
        let streaming = vtable.isStreamingEnabled()
        // 简化: 使用 sys_read
        var readBuf = Array<UInt8>(PIPE_BUF_SIZE, { _ => UInt8(0) })
        let result = SysFs.read(fd, readBuf)
        match (result) {
            case Err(e) =>
                if (!e.isRetry()) {
                    onError(e)
                } else {
                    registerPoll()
                }
            case Ok(bytesRead) =>
                if (bytesRead == 0) {
                    closeWithoutReporting()
                    if (!flags.isDone) {
                        done()
                    }
                } else {
                    count += bytesRead
                    offset += bytesRead
                    if (streaming) {
                        var data = ArrayList<UInt8>()
                        for (i in 0..bytesRead) {
                            data.append(readBuf[i])
                        }
                        drainChunk(data.toOwnedSlice(), ReadState.Progress)
                    } else {
                        for (i in 0..bytesRead) {
                            buffer.append(readBuf[i])
                        }
                    }
                }
        }
    }

    /// 获取缓冲区
    public func takeBuffer(): ArrayList<UInt8> {
        let out = buffer
        buffer = ArrayList<UInt8>()
        return out
    }

    /// 最终缓冲区 - 对应 Bun PosixBufferedReader.finalBuffer
    public func finalBuffer(): ArrayList<UInt8> {
        return buffer
    }
}

// ============================================================================
// WindowsBufferedReader - Windows 缓冲读取器
// 严格翻译自: src/io/PipeReader.zig WindowsBufferedReader
//   pub const WindowsBufferedReader = struct {
//       source: ?Source,
//       _offset: usize = 0,
//       _buffer: std.array_list.Managed(u8),
//       flags: Flags = .{},
//       parent: *anyopaque,
//       vtable: WindowsBufferedReaderVTable,
//       pub fn init, start, startWithPipe, startWithCurrentPipe,
//              startReading, stopReading, close, deinit, pause, unpause, read
//   }
// ============================================================================

/// Windows 缓冲读取器标志
public class WindowsReaderFlags {
    public var isDone: Bool
    public var pollable: Bool
    public var nonblocking: Bool
    public var receivedEof: Bool
    public var closedWithoutReporting: Bool
    public var closeHandle: Bool
    public var isPaused: Bool
    public var hasInflightRead: Bool
    public var usePread: Bool
    public var deferDoneCallback: Bool

    public init() {
        isDone = false
        pollable = false
        nonblocking = false
        receivedEof = false
        closedWithoutReporting = false
        closeHandle = true
        isPaused = true
        hasInflightRead = false
        usePread = false
        deferDoneCallback = false
    }
}

/// Windows 缓冲读取器 - 对应 Bun WindowsBufferedReader
public class WindowsBufferedReader {
    /// I/O 来源
    public var source: ?Source
    /// 读取偏移
    public var offset: Int64
    /// 内部缓冲区
    public var buffer: ArrayList<UInt8>
    /// 标志
    public var flags: WindowsReaderFlags
    /// 虚表
    public var vtable: BufferedReaderVTable
    /// 最大缓冲
    public var maxBufSize: Int64

    public init(vtable: BufferedReaderVTable) {
        source = None
        offset = 0
        buffer = ArrayList<UInt8>()
        flags = WindowsReaderFlags()
        this.vtable = vtable
        maxBufSize = Int64.MAX_VALUE
    }

    /// 内存开销
    public func memoryCost(): Int64 {
        return Int64(1024) + Int64(buffer.capacity)
    }

    /// 是否完成
    public func isDone(): Bool {
        return flags.isDone || flags.receivedEof || flags.closedWithoutReporting
    }

    /// 获取文件描述符
    public func getFd(): Int64 {
        if (let Some(s) <- source) {
            return s.getFd()
        }
        return INVALID_FD
    }

    /// 开始 - 对应 Bun WindowsBufferedReader.start
    public func start(fd: Int64, isPollable: Bool): SysMaybe<Unit> {
        let src = Source(SourceKind.File)
        src.file = FileSource(fd)
        source = src
        return startWithCurrentPipe()
    }

    /// 使用当前管道开始 - 对应 Bun WindowsBufferedReader.startWithCurrentPipe
    public func startWithCurrentPipe(): SysMaybe<Unit> {
        buffer.clear()
        flags.isDone = false
        return startReading()
    }

    /// 使用管道开始 - 对应 Bun WindowsBufferedReader.startWithPipe
    public func startWithPipe(pipeSource: Source): SysMaybe<Unit> {
        source = pipeSource
        return startWithCurrentPipe()
    }

    /// 开始读取 - 对应 Bun WindowsBufferedReader.startReading
    public func startReading(): SysMaybe<Unit> {
        if (flags.isDone || !flags.isPaused) {
            return SysMaybe<Unit>.Ok(())
        }
        flags.isPaused = false
        // 简化: 读取数据
        if (let Some(s) <- source) {
            let fd = s.getFd()
            var readBuf = Array<UInt8>(PIPE_BUF_SIZE, { _ => UInt8(0) })
            let result = SysFs.read(Int64(fd), readBuf)
            match (result) {
                case Err(e) =>
                    flags.isPaused = true
                    return SysMaybe<Unit>.Err(e)
                case Ok(bytesRead) =>
                    for (i in 0..bytesRead) {
                        buffer.append(readBuf[i])
                    }
            }
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 停止读取 - 对应 Bun WindowsBufferedReader.stopReading
    public func stopReading(): SysMaybe<Unit> {
        if (flags.isDone || flags.isPaused) {
            return SysMaybe<Unit>.Ok(())
        }
        flags.isPaused = true
        return SysMaybe<Unit>.Ok(())
    }

    /// 关闭 - 对应 Bun WindowsBufferedReader.close
    public func close(): Unit {
        stopReading()
        if (let Some(s) <- source) {
            source = None
        }
        finish()
    }

    /// 完成
    public func finish(): Unit {
        flags.hasInflightRead = false
        flags.isDone = true
    }

    /// 暂停 - 对应 Bun WindowsBufferedReader.pause
    public func pause(): Unit {
        stopReading()
    }

    /// 恢复 - 对应 Bun WindowsBufferedReader.unpause
    public func unpause(): Unit {
        startReading()
    }

    /// 读取 - 对应 Bun WindowsBufferedReader.read
    public func read(): Unit {
        unpause()
    }

    /// 是否有待读取
    public func hasPendingRead(): Bool {
        if (flags.hasInflightRead) {
            return true
        }
        return false
    }

    /// 是否有活跃活动
    public func hasPendingActivity(): Bool {
        if (let Some(s) <- source) {
            return !s.isClosed()
        }
        return false
    }

    /// 清理 - 对应 Bun WindowsBufferedReader.deinit
    public func deinit(): Unit {
        buffer.clear()
        if (let Some(s) <- source) {
            source = None
        }
    }

    /// 获取缓冲区
    public func takeBuffer(): ArrayList<UInt8> {
        let out = buffer
        buffer = ArrayList<UInt8>()
        return out
    }

    /// 最终缓冲区
    public func finalBuffer(): ArrayList<UInt8> {
        return buffer
    }

    /// 监视 (Windows 空操作)
    public func watch(): Unit {
        // Windows 上无需操作
    }
}

// ============================================================================
// 平台选择别名
// 严格翻译自: src/io/PipeReader.zig
//   pub const BufferedReader = if (bun.Environment.isPosix) PosixBufferedReader
//     else if (bun.Environment.isWindows) WindowsBufferedReader
// ============================================================================

/// 缓冲读取器类型别名 (当前平台为 POSIX)
public type BufferedReader = PosixBufferedReader
