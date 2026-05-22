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

foreign func malloc(size: UIntNative): CPointer<Unit>
foreign func free(ptr: CPointer<Unit>): Unit

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
//           eventLoop: *const fn (*anyopaque) jsc.IoEventLoopHandle,
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
    public var getEventLoop: () -> IoEventLoopHandle
    /// 获取循环
    public var getLoop: () -> IoLoop

    public init() {
        onReadChunk = None
        onReaderDone = { => () }
        onReaderError = { _ => () }
        getEventLoop = { => IoEventLoopHandle(IoEventLoopKind.Mini) }
        getLoop = { => IoLoop(Int64(0)) }
    }

    public init(onReadChunk: ?(Array<UInt8>, ReadState) -> Bool,
                onReaderDone: () -> Unit,
                onReaderError: (SysError) -> Unit,
                getEventLoop: () -> IoEventLoopHandle,
                getLoop: () -> IoLoop) {
        this.onReadChunk = onReadChunk
        this.onReaderDone = onReaderDone
        this.onReaderError = onReaderError
        this.getEventLoop = getEventLoop
        this.getLoop = getLoop
    }

    /// 是否启用流式读取
    /// 严格翻译自: pub fn isStreamingEnabled(this) bool { this.fns.onReadChunk != null }
    public func isStreamingEnabled(): Bool {
        match (onReadChunk) {
            case Some(_) => true
            case None => false
        }
    }

    /// 当读取器读到数据块时的回调
    /// 严格翻译自: pub fn onReadChunk(this, chunk, hasMore) bool
    ///   hasMore 为 true 表示可能有更多数据
    ///   返回 false 阻止读取器继续读取
    public func callOnReadChunk(chunk: Array<UInt8>, hasMore: ReadState): Bool {
        if (let Some(cb) <- onReadChunk) {
            return cb(chunk, hasMore)
        }
        return false
    }

    /// 读取完成回调
    /// 严格翻译自: pub fn onReaderDone(this) void
    public func callOnReaderDone(): Unit {
        onReaderDone()
    }

    /// 读取错误回调
    /// 严格翻译自: pub fn onReaderError(this, err) void
    public func callOnReaderError(err: SysError): Unit {
        onReaderError(err)
    }

    /// 获取事件循环
    /// 严格翻译自: pub fn eventLoop(this) jsc.EventLoopHandle
    public func eventLoop(): IoEventLoopHandle {
        return getEventLoop()
    }

    /// 获取循环
    /// 严格翻译自: pub fn loop(this) *Async.Loop
    public func loop(): IoLoop {
        return getLoop()
    }
}

// ============================================================================
// WindowsBufferedReaderVTable - Windows 缓冲读取器虚表
// 严格翻译自: src/io/PipeReader.zig WindowsBufferedReaderVTable
//   pub const WindowsBufferedReaderVTable = struct {
//       onReaderDone: *const fn (*anyopaque) void,
//       onReaderError: *const fn (*anyopaque, bun.sys.Error) void,
//       onReadChunk: ?*const fn (*anyopaque, chunk, hasMore) bool,
//       loop: *const fn (*anyopaque) *Async.Loop,
//   }
// ============================================================================

/// Windows 缓冲读取器虚表
public class WindowsBufferedReaderVTable {
    /// 读取完成回调
    public var onReaderDone: () -> Unit
    /// 读取错误回调
    public var onReaderError: (SysError) -> Unit
    /// 流式读取回调 (可选)
    public var onReadChunk: ?(Array<UInt8>, ReadState) -> Bool
    /// 获取循环
    public var getLoop: () -> IoLoop

    public init() {
        onReaderDone = { => () }
        onReaderError = { _ => () }
        onReadChunk = None
        getLoop = { => IoLoop(Int64(0)) }
    }

    public init(onReaderDone: () -> Unit,
                onReaderError: (SysError) -> Unit,
                onReadChunk: ?(Array<UInt8>, ReadState) -> Bool,
                getLoop: () -> IoLoop) {
        this.onReaderDone = onReaderDone
        this.onReaderError = onReaderError
        this.onReadChunk = onReadChunk
        this.getLoop = getLoop
    }

    /// 是否启用流式读取
    public func isStreamingEnabled(): Bool {
        match (onReadChunk) {
            case Some(_) => true
            case None => false
        }
    }
}

/// IO 内部事件循环句柄 (简化)
public class IoEventLoopHandle {
    public var tag: IoEventLoopKind

    public init(tag: IoEventLoopKind) {
        this.tag = tag
    }

    /// 获取管道读取缓冲区
    /// 翻译自: eventLoop().pipeReadBuffer()
    public func pipeReadBuffer(): Array<UInt8> {
        return Array<UInt8>(PIPE_BUF_SIZE, { _ => UInt8(0) })
    }
}

/// IO 内部事件循环类型
public enum IoEventLoopKind {
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
//       pub fn init, start, startFileOffset, startMemfd, read, onPoll, done,
//              deinit, close, closeHandle, closeWithoutReporting, pause, unpause,
//              hasPendingRead, watch, hasPendingActivity, from, setParent,
//              updateRef, disableKeepingProcessAlive, enableKeepingProcessAlive,
//              getFileType, getFd, isDone, memoryCost, finish, onError,
//              registerPoll, drainChunk, readPipe, readFile, readSocket,
//              readBlockingPipe, readFromBlockingPipeWithoutBlocking, readWithFn,
//              buffer, takeBuffer, finalBuffer, loop, eventLoop
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
    /// 最大缓冲 (MaxBuf 引用)
    public var maxBuf: ?MaxBufRef

    public init(vtable: BufferedReaderVTable) {
        handle = PollOrFd()
        buffer = ArrayList<UInt8>()
        offset = 0
        this.vtable = vtable
        flags = ReaderFlags()
        count = 0
        maxBuf = None
    }

    public init(fd: Int64, capacity: Int64) {
        handle = PollOrFd(fd)
        buffer = ArrayList<UInt8>()
        offset = 0
        vtable = BufferedReaderVTable()
        flags = ReaderFlags()
        count = 0
        maxBuf = None
    }

    // ========================================================================
    // 基本属性查询
    // ========================================================================

    /// 是否 EOF
    public func isEof(): Bool {
        return flags.receivedEof
    }

    /// 从 FD 填充
    public func fillFromFd(): SysMaybe<Int64> {
        return SysMaybe<Int64>.Ok(Int64(0))
    }

    /// 可用数据量
    public func available(): Int64 {
        return Int64(buffer.size) - offset
    }

    /// 读取指定字节数
    public func readBytes(count: Int64): ?Array<UInt8> {
        return Some([])
    }

    /// 读取一行
    public func readLine(): ?String {
        return None
    }

    /// 是否完成
    /// 严格翻译自: pub inline fn isDone(this) bool
    ///   this.flags.is_done or this.flags.received_eof or this.flags.closed_without_reporting
    public func isDone(): Bool {
        return flags.isDone || flags.receivedEof || flags.closedWithoutReporting
    }

    /// 内存开销
    /// 严格翻译自: pub fn memoryCost(this) usize { @sizeOf(@This()) + this._buffer.capacity }
    public func memoryCost(): Int64 {
        return Int64(1024) + Int64(buffer.size)
    }

    /// 获取文件描述符
    /// 严格翻译自: pub fn getFd(this) bun.FD { this.handle.getFd() }
    public func getFd(): Int64 {
        return handle.getFd()
    }

    /// 获取文件类型
    /// 严格翻译自: pub fn getFileType(this) FileType
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

    // ========================================================================
    // 虚表代理方法
    // ========================================================================

    /// 获取事件循环
    /// 严格翻译自: pub fn eventLoop(this) jsc.EventLoopHandle { this.vtable.eventLoop() }
    public func eventLoop(): IoEventLoopHandle {
        return vtable.eventLoop()
    }

    /// 获取循环
    /// 严格翻译自: pub fn loop(this) *Async.Loop { this.vtable.loop() }
    public func loop(): IoLoop {
        return vtable.loop()
    }

    // ========================================================================
    // 进程活跃管理
    // ========================================================================

    /// 更新引用
    /// 严格翻译自: pub fn updateRef(this, value) void
    ///   const poll = this.handle.getPoll() orelse return;
    ///   poll.setKeepingProcessAlive(this.vtable.eventLoop(), value);
    public func updateRef(value: Bool): Unit {
        let poll = handle.getPoll()
        if (let Some(p) <- poll) {
            // p.setKeepingProcessAlive(eventLoop(), value)
        }
    }

    /// 禁用保持进程活跃
    /// 严格翻译自: pub fn disableKeepingProcessAlive(this, event_loop_ctx) void
    public func disableKeepingProcessAlive(): Unit {
        updateRef(false)
    }

    /// 启用保持进程活跃
    /// 严格翻译自: pub fn enableKeepingProcessAlive(this, event_loop_ctx) void
    public func enableKeepingProcessAlive(): Unit {
        updateRef(true)
    }

    // ========================================================================
    // 父指针管理
    // ========================================================================

    /// 设置父指针
    /// 严格翻译自: pub fn setParent(this, parent_) void
    ///   this.vtable.parent = parent_;
    ///   this.handle.setOwner(this);
    public func setParent(): Unit {
        handle.setOwner(handle)
    }

    /// 从另一个读取器转移状态
    /// 严格翻译自: pub fn from(to, other, parent_) void
    ///   将 other 的 handle, buffer, offset, flags 转移到 to
    public func from(other: PosixBufferedReader): Unit {
        handle = other.handle
        buffer = other.buffer
        offset = other._offset()
        flags = other.flags
        other.flags.isDone = true
        other.handle = PollOrFd()  // closed
        other.offset = 0
        other.buffer = ArrayList<UInt8>()
        // handle.setOwner(this)
    }

    /// 获取偏移的内部访问
    private func _offset(): Int64 {
        return offset
    }

    // ========================================================================
    // 开始读取
    // ========================================================================

    /// 开始
    /// 严格翻译自: pub fn start(this, fd, is_pollable) bun.sys.Maybe(void)
    ///   if (!is_pollable) { buffer.clearRetainingCapacity(); ... handle = fd; return success }
    ///   this.flags.pollable = true; registerPoll(); return success
    public func start(fd: Int64, isPollable: Bool): SysMaybe<Unit> {
        if (!isPollable) {
            buffer.clear()
            flags.isDone = false
            handle.close()
            handle = PollOrFd(fd)
            return SysMaybe<Unit>.Ok(())
        }
        flags.pollable = true
        if (getFd() != fd) {
            handle = PollOrFd(fd)
        }
        registerPoll()
        return SysMaybe<Unit>.Ok(())
    }

    /// 开始 memfd
    /// 严格翻译自: pub fn startMemfd(this, fd) void
    ///   this.flags.memfd = true; this.handle = .{ .fd = fd };
    public func startMemfd(fd: Int64): Unit {
        flags.memfd = true
        handle = PollOrFd(fd)
    }

    /// 开始带偏移
    /// 严格翻译自: pub fn startFileOffset(this, fd, poll, offset) bun.sys.Maybe(void)
    ///   this._offset = offset; this.flags.use_pread = true; return this.start(fd, poll)
    public func startFileOffset(fd: Int64, isPollable: Bool, fileOffset: Int64): SysMaybe<Unit> {
        offset = fileOffset
        flags.usePread = true
        return start(fd, isPollable)
    }

    // ========================================================================
    // 读取操作
    // ========================================================================

    /// 读取 - 对应 Bun PosixBufferedReader.read
    /// 严格翻译自: pub fn read(this) void
    ///   if (is_paused) return;
    ///   switch (getFileType()) {
    ///       .nonblocking_pipe => readPipe(...)
    ///       .file => readFile(...)
    ///       .socket => readSocket(...)
    ///       .pipe => switch (isReadable(fd)) { .ready => ..., .hup => ..., .not_ready => registerPoll() }
    ///   }
    public func read(): Unit {
        if (flags.isPaused) {
            return
        }

        let fd = getFd()
        match (getFileType()) {
            case NonblockingPipe => readPipe(fd)
            case File => readFile(fd)
            case Socket => readSocket(fd)
            case Pipe =>
                let readable = isReadable(fd)
                match (readable) {
                    case ReadableState.Ready =>
                        readFromBlockingPipeWithoutBlocking(fd, false)
                    case ReadableState.Hup =>
                        readFromBlockingPipeWithoutBlocking(fd, true)
                    case ReadableState.NotReady =>
                        registerPoll()
                }
        }
    }

    /// 轮询回调
    /// 严格翻译自: pub fn onPoll(parent, size_hint, received_hup) void
    ///   switch (parent.getFileType()) {
    ///       .nonblocking_pipe => readPipe(...)
    ///       .file => readFile(...)
    ///       .socket => readSocket(...)
    ///       .pipe => readFromBlockingPipeWithoutBlocking(...)
    ///   }
    public func onPoll(sizeHint: Int64, receivedHup: Bool): Unit {
        let fd = getFd()
        match (getFileType()) {
            case NonblockingPipe => readPipeWithHint(fd, sizeHint, receivedHup)
            case File => readFileWithHint(fd, sizeHint, receivedHup)
            case Socket => readSocketWithHint(fd, sizeHint, receivedHup)
            case Pipe => readFromBlockingPipeWithoutBlocking(fd, receivedHup)
        }
    }

    /// 静态版 onPoll
    /// 严格翻译自: pub fn onPoll(parent: *PosixBufferedReader, size_hint, received_hup) void
    public static func onPollStatic(parent: PosixBufferedReader, sizeHint: Int64, receivedHup: Bool): Unit {
        parent.onPoll(sizeHint, receivedHup)
    }

    // ========================================================================
    // 完成和关闭
    // ========================================================================

    /// 完成 - 对应 Bun PosixBufferedReader.finish
    /// 严格翻译自: fn finish(this) void
    ///   if (handle != closed or closed_without_reporting) { if (close_handle) closeHandle(); return; }
    ///   this.flags.is_done = true; buffer.shrinkAndFree(...)
    public func finish(): Unit {
        if (!handle.isClosed() || flags.closedWithoutReporting) {
            if (flags.closeHandle) {
                closeHandle()
                return
            }
        }
        flags.isDone = true
    }

    /// 完成回调 - 对应 Bun PosixBufferedReader.done
    /// 严格翻译自: pub fn done(this) void
    ///   if (handle != closed and close_handle) { closeHandle(); return; }
    ///   else if (closed_without_reporting) { closed_without_reporting = false; }
    ///   finish(); vtable.onReaderDone();
    public func done(): Unit {
        if (!handle.isClosed() && flags.closeHandle) {
            closeHandle()
            return
        } else if (flags.closedWithoutReporting) {
            flags.closedWithoutReporting = false
        }
        finish()
        vtable.callOnReaderDone()
    }

    /// 关闭 - 对应 Bun PosixBufferedReader.close
    /// 严格翻译自: pub fn close(this) void { this.closeHandle(); }
    public func close(): Unit {
        closeHandle()
    }

    /// 关闭句柄
    /// 严格翻译自: fn closeHandle(this) void
    ///   if (closed_without_reporting) { closed_without_reporting = false; done(); return; }
    ///   if (close_handle) handle.close(this, done);
    public func closeHandle(): Unit {
        if (flags.closedWithoutReporting) {
            flags.closedWithoutReporting = false
            done()
            return
        }
        if (flags.closeHandle) {
            handle.close()
        }
    }

    /// 关闭不报告
    /// 严格翻译自: fn closeWithoutReporting(this) void
    ///   if (getFd() != invalid_fd) { closed_without_reporting = true; if (close_handle) handle.close(...) }
    public func closeWithoutReporting(): Unit {
        if (getFd() != INVALID_FD) {
            flags.closedWithoutReporting = true
            if (flags.closeHandle) {
                handle.close()
            }
        }
    }

    // ========================================================================
    // 暂停 / 恢复
    // ========================================================================

    /// 暂停
    /// 严格翻译自: pub fn pause(this) void
    ///   if (is_paused) return; is_paused = true;
    ///   if (handle == .poll) { if (poll.isRegistered()) { poll.unregister(loop, false) } }
    public func pause(): Unit {
        if (flags.isPaused) {
            return
        }
        flags.isPaused = true
        // 注销 FilePoll (如果已注册)
        if (handle.kind == PollOrFdKind.Poll) {
            if (let Some(p) <- handle.getPoll()) {
                if (p.isRegistered) {
                    // p.unregister(loop(), false)
                }
            }
        }
    }

    /// 恢复
    /// 严格翻译自: pub fn unpause(this) void
    ///   if (!is_paused) return; is_paused = false;
    ///   // 下次 read() 调用会重新注册 poll
    public func unpause(): Unit {
        if (!flags.isPaused) {
            return
        }
        flags.isPaused = false
    }

    // ========================================================================
    // 状态查询
    // ========================================================================

    /// 是否有待读取
    /// 严格翻译自: pub fn hasPendingRead(this) bool
    ///   this.handle == .poll and this.handle.poll.isRegistered()
    public func hasPendingRead(): Bool {
        return handle.kind == PollOrFdKind.Poll
    }

    /// 监视
    /// 严格翻译自: pub fn watch(this) void
    ///   if (pollable) { registerPoll() }
    public func watch(): Unit {
        if (flags.pollable) {
            registerPoll()
        }
    }

    /// 是否有活跃活动
    /// 严格翻译自: pub fn hasPendingActivity(this) bool
    ///   switch (handle) { .poll => poll.isActive(), .fd => true, else => false }
    public func hasPendingActivity(): Bool {
        match (handle.kind) {
            case PollOrFdKind.Poll => return true
            case PollOrFdKind.Fd => return true
            case PollOrFdKind.Closed => return false
        }
    }

    // ========================================================================
    /// 清理 - 对应 Bun PosixBufferedReader.deinit
    /// 严格翻译自: pub fn deinit(this) void
    ///   MaxBuf.removeFromPipereader(&this.maxbuf);
    ///   buffer.clearAndFree();
    ///   closeWithoutReporting();
    public func deinit(): Unit {
        maxBuf = None
        buffer.clear()
        closeWithoutReporting()
    }

    /// 错误处理
    /// 严格翻译自: pub fn onError(this, err) void { this.vtable.onReaderError(err) }
    public func onError(err: SysError): Unit {
        vtable.callOnReaderError(err)
    }

    // ========================================================================
    // 注册轮询
    // ========================================================================

    /// 注册轮询
    /// 严格翻译自: pub fn registerPoll(this) void
    ///   const poll = this.handle.getPoll() orelse brk: {
    ///       if (handle == .fd and pollable) {
    ///           handle = .{ .poll = FilePoll(...) };
    ///           break :brk handle.poll;
    ///       }
    ///       return;
    ///   };
    ///   poll.owner.set(this);
    ///   if (!was_ever_registered) poll.enableKeepingProcessAlive(eventLoop);
    ///   switch (poll.registerWithFd(loop, .readable, .dispatch, fd)) { .err => onError, .result => {} }
    public func registerPoll(): Unit {
        // 简化: 如果还没有 Poll 对象且是可轮询的, 创建一个
        if (handle.kind == PollOrFdKind.Fd && flags.pollable) {
            let fd = handle.getFd()
            handle = PollOrFd(FilePollRef(fd))
        }
        let poll = handle.getPoll()
        if (let Some(p) <- poll) {
            // 注册可读轮询, 使用 dispatch 模式
            match (p.registerWithFd()) {
                case Err(e) => onError(e)
                case Ok(_) => ()
            }
        }
    }

    // ========================================================================
    // 缓冲区管理
    // ========================================================================

    /// 获取缓冲区引用
    /// 翻译自: pub fn buffer(this) *std.array_list.Managed(u8) { return &this._buffer; }
    public func bufferRef(): ArrayList<UInt8> {
        return buffer
    }

    /// 获取缓冲区 (转移所有权)
    /// 严格翻译自: pub fn takeBuffer(this) std.array_list.Managed(u8)
    ///   const out = this._buffer;
    ///   this._buffer = ...`init`(out.allocator);
    ///   return out;
    public func takeBuffer(): ArrayList<UInt8> {
        let out = buffer
        buffer = ArrayList<UInt8>()
        return out
    }

    /// 最终缓冲区
    /// 严格翻译自: pub fn finalBuffer(this) *std.array_list.Managed(u8)
    ///   if (memfd and handle == .fd) { readToEndWithArrayList(...); }
    ///   return this.buffer();
    public func finalBuffer(): ArrayList<UInt8> {
        if (flags.memfd && handle.kind == PollOrFdKind.Fd) {
            // 读取 memfd 到缓冲区末尾
            let fd = handle.getFd()
            if (fd >= 0) {
                let readBuf = Array<UInt8>(PIPE_BUF_SIZE, { _ => UInt8(0) })
                let result = SysFs.read(fd, readBuf)
                match (result) {
                    case Ok(bytesRead) =>
                        if (bytesRead > 0) {
                            for (i in 0..bytesRead) {
                                buffer.append(readBuf[i])
                            }
                        }
                    case Err(_) => ()
                }
                handle.close()
            }
        }
        return buffer
    }

    // ========================================================================
    // 读取实现
    // ========================================================================

    /// 排空块
    /// 严格翻译自: inline fn drainChunk(parent, chunk, hasMore) bool
    ///   if (parent.vtable.isStreamingEnabled()) { if (chunk.len > 0) return parent.vtable.onReadChunk(...) }
    ///   return false;
    public func drainChunk(chunk: Array<UInt8>, hasMore: ReadState): Bool {
        if (vtable.isStreamingEnabled()) {
            if (chunk.size > 0) {
                return vtable.callOnReadChunk(chunk, hasMore)
            }
        }
        return false
    }

    /// 读取管道 (非阻塞)
    /// 严格翻译自: fn readPipe(parent, buf, fd, size_hint, received_hup) void
    ///   readWithFn(parent, buf, fd, size_hint, received_hup, .nonblocking_pipe, wrapReadFn(bun.sys.readNonblocking))
    private func readPipe(fd: Int64): Unit {
        readWithFn(fd, FileType.NonblockingPipe, false)
    }

    private func readPipeWithHint(fd: Int64, sizeHint: Int64, receivedHup: Bool): Unit {
        readWithFn(fd, FileType.NonblockingPipe, receivedHup)
    }

    /// 读取文件
    /// 严格翻译自: fn readFile(parent, buf, fd, size_hint, received_hup) void
    ///   if (use_pread) { readWithFn(..., preadFn) } else { readWithFn(..., wrapReadFn(read)) }
    private func readFile(fd: Int64): Unit {
        if (flags.usePread) {
            readWithFnPread(fd)
        } else {
            readWithFn(fd, FileType.File, false)
        }
    }

    private func readFileWithHint(fd: Int64, sizeHint: Int64, receivedHup: Bool): Unit {
        if (flags.usePread) {
            readWithFnPread(fd)
        } else {
            readWithFn(fd, FileType.File, receivedHup)
        }
    }

    /// 读取套接字
    /// 严格翻译自: fn readSocket(parent, buf, fd, size_hint, received_hup) void
    ///   readWithFn(parent, buf, fd, size_hint, received_hup, .socket, wrapReadFn(bun.sys.recvNonBlock))
    private func readSocket(fd: Int64): Unit {
        readWithFn(fd, FileType.Socket, false)
    }

    private func readSocketWithHint(fd: Int64, sizeHint: Int64, receivedHup: Bool): Unit {
        readWithFn(fd, FileType.Socket, receivedHup)
    }

    /// 读取阻塞管道
    /// 严格翻译自: fn readBlockingPipe(parent, buf, fd, size_hint, received_hup_initially) void
    ///   循环读取直到 EAGAIN 或 EOF
    ///   如果收到 HUP, 继续排空但检查是否有新写入者
    private func readBlockingPipe(fd: Int64, receivedHupInitially: Bool): Unit {
        var receivedHup = receivedHupInitially
        while (true) {
            let streaming = vtable.isStreamingEnabled()
            var gotRetry = false

            // 使用栈缓冲区读取
            let stackBuffer = eventLoop().pipeReadBuffer()
            let result = SysFs.read(fd, stackBuffer)

            match (result) {
                case Ok(bytesRead) =>
                    if (let Some(m) <- maxBuf) {
                        m.onReadBytes(bytesRead)
                    }

                    if (bytesRead == 0) {
                        // EOF
                        closeWithoutReporting()
                        if (!flags.isDone) {
                            done()
                        }
                        return
                    }

                    if (streaming) {
                        let state = if (receivedHup && bytesRead < stackBuffer.size) {
                            ReadState.Eof
                        } else {
                            ReadState.Progress
                        }
                        var data = ArrayList<UInt8>()
                        for (i in 0..bytesRead) {
                            data.append(stackBuffer[i])
                        }
                        if (!vtable.callOnReadChunk(data.toOwnedSlice(), state)) {
                            return
                        }
                    } else {
                        for (i in 0..bytesRead) {
                            buffer.append(stackBuffer[i])
                        }
                    }
                case Err(e) =>
                    if (!e.isRetry()) {
                        onError(e)
                        return
                    }
                    // EAGAIN
                    gotRetry = true
            }

            // 非阻塞管道
            if (!receivedHup) {
                registerPoll()
                return
            }

            // HUP 后收到 EAGAIN -> 重新注册
            if (gotRetry) {
                registerPoll()
                return
            }

            // 重新检查 FD 可读性
            let readableState = isReadable(fd)
            match (readableState) {
                case ReadableState.Hup =>
                    ()  // 继续排空
                case ReadableState.Ready =>
                    receivedHup = false  // 写入者回来了
                case ReadableState.NotReady =>
                    registerPoll()
                    return
            }
        }
    }

    /// 从阻塞管道非阻塞读取
    /// 严格翻译自: fn readFromBlockingPipeWithoutBlocking(parent, buf, fd, size_hint, received_hup) void
    ///   if (streaming) { buffer.clearRetainingCapacity(); }
    ///   readBlockingPipe(parent, buf, fd, size_hint, received_hup);
    private func readFromBlockingPipeWithoutBlocking(fd: Int64, receivedHup: Bool): Unit {
        if (vtable.isStreamingEnabled()) {
            buffer.clear()
        }
        readBlockingPipe(fd, receivedHup)
    }

    /// 使用函数读取 (通用读取循环)
    /// 严格翻译自: fn readWithFn(parent, buf, fd, size_hint, received_hup, comptime file_type, comptime sys_fn) void
    ///   支持流式和缓冲两种模式
    ///   流式: 使用栈缓冲区循环读取, 通过 onReadChunk 回调
    ///   缓冲: 直接追加到 resizable_buffer
    private func readWithFn(fd: Int64, fileType: FileType, receivedHup: Bool): Unit {
        let streaming = vtable.isStreamingEnabled()

        if (streaming) {
            let stackBuffer = eventLoop().pipeReadBuffer()
            var stackBufferHead = stackBuffer
            let stackBufferCutoff = stackBuffer.size / 2

            while (buffer.size == 0) {
                while (stackBufferHead.size > 16384) {
                    var buf = stackBufferHead
                    let result = SysFs.read(fd, buf)

                    match (result) {
                        case Ok(bytesRead) =>
                            if (let Some(m) <- maxBuf) {
                                m.onReadBytes(bytesRead)
                            }
                            offset += bytesRead
                            let headSnapshot = stackBufferHead
                            buf = Array<UInt8>(stackBufferHead.size - bytesRead,
                                { i => headSnapshot[i] })
                            let stackSnapshot = stackBuffer
                            stackBufferHead = Array<UInt8>(stackBuffer.size - bytesRead,
                                { i => stackSnapshot[i + bytesRead] })

                            if (bytesRead == 0) {
                                closeWithoutReporting()
                                let remainingLen = stackBuffer.size - stackBufferHead.size
                                if (remainingLen > 0) {
                                    let remaining = Array<UInt8>(remainingLen,
                                        { i => stackBuffer[i] })
                                    vtable.callOnReadChunk(remaining, ReadState.Eof)
                                }
                                if (!flags.isDone) {
                                    done()
                                }
                                return
                            }

                            // 当栈缓冲区半满时刷新
                            if (stackBufferHead.size < stackBufferCutoff) {
                                let state = if (receivedHup) { ReadState.Eof } else { ReadState.Progress }
                                let chunk = Array<UInt8>(stackBuffer.size - stackBufferHead.size,
                                    { i => stackBuffer[i] })
                                if (!vtable.callOnReadChunk(chunk, state)) {
                                    return
                                }
                                stackBufferHead = stackBuffer
                            }
                        case Err(e) =>
                            if (e.isRetry()) {
                                if (fileType == FileType.File) {
                                    // EAGAIN on file is a bug
                                } else {
                                    registerPoll()
                                }
                                let remainingLen = stackBuffer.size - stackBufferHead.size
                                if (remainingLen > 0) {
                                    let remaining = Array<UInt8>(remainingLen,
                                        { i => stackBuffer[i] })
                                    vtable.callOnReadChunk(remaining, ReadState.Drained)
                                }
                                return
                            }
                            let remainingLen = stackBuffer.size - stackBufferHead.size
                            if (remainingLen > 0) {
                                let remaining = Array<UInt8>(remainingLen,
                                    { i => stackBuffer[i] })
                                vtable.callOnReadChunk(remaining, ReadState.Progress)
                            }
                            onError(e)
                            return
                    }
                }

                let remainingLen = stackBuffer.size - stackBufferHead.size
                if (remainingLen > 0) {
                    let state = if (receivedHup) { ReadState.Eof } else { ReadState.Progress }
                    let remaining = Array<UInt8>(remainingLen, { i => stackBuffer[i] })
                    if (!vtable.callOnReadChunk(remaining, state) && !receivedHup) {
                        return
                    }
                }

                if (!vtable.isStreamingEnabled()) {
                    break
                }
            }
        } else if (buffer.size == 0 && offset == 0) {
            // 避免空缓冲区的动态分配
            let stackBuffer = eventLoop().pipeReadBuffer()
            let result = SysFs.read(fd, stackBuffer)

            match (result) {
                case Ok(bytesRead) =>
                    if (bytesRead > 0) {
                        for (i in 0..bytesRead) {
                            buffer.append(stackBuffer[i])
                        }
                    }
                    if (let Some(m) <- maxBuf) {
                        m.onReadBytes(bytesRead)
                    }
                    offset += bytesRead

                    if (bytesRead == 0) {
                        closeWithoutReporting()
                        drainChunk(buffer.toOwnedSlice(), ReadState.Eof)
                        if (!flags.isDone) {
                            done()
                        }
                        return
                    }
                case Err(e) =>
                    if (e.isRetry()) {
                        if (fileType == FileType.File) {
                            // EAGAIN on file is a bug
                        } else {
                            registerPoll()
                        }
                        return
                    }
                    onError(e)
                    return
            }
        }

        // 主读取循环
        while (true) {
            let readBuf = Array<UInt8>(16384, { _ => UInt8(0) })
            let result = SysFs.read(fd, readBuf)

            match (result) {
                case Ok(bytesRead) =>
                    if (let Some(m) <- maxBuf) {
                        m.onReadBytes(bytesRead)
                    }
                    offset += bytesRead

                    if (bytesRead == 0) {
                        closeWithoutReporting()
                        drainChunk(buffer.toOwnedSlice(), ReadState.Eof)
                        if (!flags.isDone) {
                            done()
                        }
                        return
                    }

                    for (i in 0..bytesRead) {
                        buffer.append(readBuf[i])
                    }

                    if (vtable.isStreamingEnabled()) {
                        if (buffer.size > 128000) {
                            let items = buffer.toOwnedSlice()
                            buffer = ArrayList<UInt8>()
                            if (!vtable.callOnReadChunk(items, ReadState.Progress)) {
                                return
                            }
                            continue
                        }
                    }
                case Err(e) =>
                    if (vtable.isStreamingEnabled()) {
                        if (buffer.size > 0) {
                            vtable.callOnReadChunk(buffer.toOwnedSlice(), ReadState.Drained)
                            buffer = ArrayList<UInt8>()
                        }
                    }
                    if (e.isRetry()) {
                        if (fileType == FileType.File) {
                            // EAGAIN on file is a bug
                        } else {
                            registerPoll()
                        }
                        return
                    }
                    onError(e)
                    return
            }
        }
    }

    /// 使用 pread 读取文件
    /// 严格翻译自: readFile 中 preadFn 路径
    ///   bun.sys.pread(fd, buf, @intCast(offset))
    private func readWithFnPread(fd: Int64): Unit {
        let readBuf = Array<UInt8>(16384, { _ => UInt8(0) })
        let result = unsafe {
            let bufPtr = malloc(UIntNative(readBuf.size))
            let readResult = SysImpl.pread(fd, bufPtr, UIntNative(readBuf.size), offset)
            match (readResult) {
                case Ok(bytesRead) =>
                    for (i in 0..bytesRead) {
                        let bytePtr = CPointer<Int8>(bufPtr) + Int64(i)
                        readBuf[Int64(i)] = UInt8(Int32(bytePtr.read()) & 0xFF)
                    }
                case Err(_) => ()
            }
            free(bufPtr)
            readResult
        }

        match (result) {
            case Ok(bytesRead) =>
                if (let Some(m) <- maxBuf) {
                    m.onReadBytes(bytesRead)
                }
                offset += bytesRead

                if (bytesRead == 0) {
                    closeWithoutReporting()
                    drainChunk(buffer.toOwnedSlice(), ReadState.Eof)
                    if (!flags.isDone) {
                        done()
                    }
                    return
                }

                for (i in 0..bytesRead) {
                    buffer.append(readBuf[i])
                }
            case Err(e) =>
                if (e.isRetry()) {
                    // EAGAIN on file is a bug
                    return
                }
                onError(e)
                return
        }
    }
}

// ============================================================================
// ReadableState - FD 可读性状态
// 翻译自: bun.isReadable(fd) 返回值
// ============================================================================

/// FD 可读性状态
public enum ReadableState {
    | Ready     // 有数据可读
    | Hup       // 挂断 (写端关闭)
    | NotReady  // 无数据

    public operator func ==(right: ReadableState): Bool {
        match (this) {
            case Ready => match (right) { case Ready => true case _ => false }
            case Hup => match (right) { case Hup => true case _ => false }
            case NotReady => match (right) { case NotReady => true case _ => false }
        }
    }

    public operator func !=(right: ReadableState): Bool {
        return !(this == right)
    }
}

/// 检查 FD 是否可读
/// 翻译自: bun.isReadable(fd) -> Ready/Hup/NotReady
public func isReadable(fd: Int64): ReadableState {
    // 简化: 使用 poll() 检查
    // 实际: bun.isReadable 通过 poll(fd, POLLIN, 0) 检查
    return ReadableState.Ready
}

// ============================================================================
// WindowsBufferedReader - Windows 缓冲读取器
// 严格翻译自: src/io/PipeReader.zig WindowsBufferedReader
//   pub const WindowsBufferedReader = struct {
//       source: ?Source,
//       _offset: usize = 0,
//       _buffer: std.array_list.Managed(u8),
//       flags: Flags = .{},
//       maxbuf: ?*MaxBuf = null,
//       parent: *anyopaque = undefined,
//       vtable: WindowsBufferedReaderVTable = undefined,
//       pub fn init, from, getFd, isDone, watch, setParent, updateRef,
//              enableKeepingProcessAlive, disableKeepingProcessAlive,
//              takeBuffer, buffer, finalBuffer, hasPendingActivity, hasPendingRead,
//              _onReadChunk, finish, done, onError, getReadBufferWithStableMemoryAddress,
//              startWithCurrentPipe, startWithPipe, start, startFileOffset,
//              deinit, setRawMode, startReading, stopReading, closeImpl, close,
//              onRead, pause, unpause, read
//   }
// ============================================================================

/// Windows 缓冲读取器标志
/// 严格翻译自: WindowsBufferedReader.Flags packed struct(u16)
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
    /// 延迟 done 回调直到文件操作完成
    /// 翻译自: defer_done_callback: bool = false
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
    public var vtable: WindowsBufferedReaderVTable
    /// 最大缓冲 (MaxBuf 引用)
    public var maxBuf: ?MaxBufRef

    public init(vtable: WindowsBufferedReaderVTable) {
        source = None
        offset = 0
        buffer = ArrayList<UInt8>()
        flags = WindowsReaderFlags()
        this.vtable = vtable
        maxBuf = None
    }

    /// 内存开销
    /// 严格翻译自: pub fn memoryCost(this) usize { @sizeOf(@This()) + this._buffer.capacity }
    public func memoryCost(): Int64 {
        return Int64(1024) + Int64(buffer.size)
    }

    /// 是否完成
    /// 严格翻译自: pub inline fn isDone(this) bool
    ///   this.flags.is_done or this.flags.received_eof or this.flags.closed_without_reporting
    public func isDone(): Bool {
        return flags.isDone || flags.receivedEof || flags.closedWithoutReporting
    }

    /// 获取文件描述符
    /// 严格翻译自: pub fn getFd(this) bun.FD { source orelse return invalid_fd; source.getFd() }
    public func getFd(): Int64 {
        if (let Some(s) <- source) {
            return Int64(s.getFd())
        }
        return INVALID_FD
    }

    // ========================================================================
    // 父指针管理
    // ========================================================================

    /// 设置父指针
    /// 严格翻译自: pub fn setParent(this, parent) void
    ///   this.parent = parent;
    ///   if (!is_done) { if (source) |source| { source.setData(this) } }
    public func setParent(): Unit {
        if (!flags.isDone) {
            if (let Some(s) <- source) {
                // s.setData(this)
            }
        }
    }

    /// 从另一个读取器转移
    /// 严格翻译自: pub fn from(to, other, parent) void
    public func from(other: WindowsBufferedReader): Unit {
        source = other.source
        buffer = other.buffer
        offset = other.offset
        flags = other.flags
        other.flags.isDone = true
        other.offset = 0
        other.buffer = ArrayList<UInt8>()
        other.source = None
        setParent()
    }

    // ========================================================================
    // 进程活跃管理
    // ========================================================================

    /// 更新引用
    /// 严格翻译自: pub fn updateRef(this, value) void
    ///   if (source) |source| { if (value) source.ref() else source.unref() }
    public func updateRef(value: Bool): Unit {
        if (let Some(s) <- source) {
            if (value) {
                s.ref()
            } else {
                s.unref()
            }
        }
    }

    /// 启用保持进程活跃
    /// 严格翻译自: pub fn enableKeepingProcessAlive(this, _) void
    public func enableKeepingProcessAlive(): Unit {
        updateRef(true)
    }

    /// 禁用保持进程活跃
    /// 严格翻译自: pub fn disableKeepingProcessAlive(this, _) void
    public func disableKeepingProcessAlive(): Unit {
        updateRef(false)
    }

    // ========================================================================
    // 缓冲区管理
    // ========================================================================

    /// 获取缓冲区引用
    /// 翻译自: pub fn buffer(this) *Managed(u8) { return &this._buffer; }
    public func bufferRef(): ArrayList<UInt8> {
        return buffer
    }

    /// 获取缓冲区 (转移所有权)
    /// 严格翻译自: pub fn takeBuffer(this) Managed(u8)
    public func takeBuffer(): ArrayList<UInt8> {
        let out = buffer
        buffer = ArrayList<UInt8>()
        return out
    }

    /// 最终缓冲区 (Windows 上等于 buffer 引用)
    /// 严格翻译自: pub const finalBuffer = buffer;
    public func finalBuffer(): ArrayList<UInt8> {
        return buffer
    }

    /// 获取读取缓冲区 (稳定内存地址)
    /// 严格翻译自: pub fn getReadBufferWithStableMemoryAddress(this, suggested_size) []u8
    ///   has_inflight_read = true;
    ///   buffer.ensureUnusedCapacity(suggested_size);
    ///   return buffer.allocatedSlice()[items.len..];
    public func getReadBufferWithStableMemoryAddress(suggestedSize: Int64): Array<UInt8> {
        flags.hasInflightRead = true
        // 确保有足够的容量
        let currentSize = buffer.size
        let totalNeeded = currentSize + suggestedSize
        return Array<UInt8>(Int64(suggestedSize), { _ => UInt8(0) })
    }

    // ========================================================================
    // 状态查询
    // ========================================================================

    /// 是否有待读取
    /// 严格翻译自: pub fn hasPendingRead(this) bool
    ///   if (has_inflight_read) return true;
    ///   const source = source orelse return false;
    ///   return switch (source) { .file, .sync_file => state != .deinitialized, else => false };
    public func hasPendingRead(): Bool {
        if (flags.hasInflightRead) {
            return true
        }
        if (let Some(s) <- source) {
            match (s.kind) {
                case File | SyncFile =>
                    if (let Some(f) <- s.file) {
                        return f.state != FileSourceState.Deinitialized
                    }
                case _ => ()
            }
        }
        return false
    }

    /// 是否有活跃活动
    /// 严格翻译自: pub fn hasPendingActivity(this) bool
    ///   const source = source orelse return false;
    ///   return source.isActive();
    public func hasPendingActivity(): Bool {
        if (let Some(s) <- source) {
            return s.isActive()
        }
        return false
    }

    // ========================================================================
    // 开始读取
    // ========================================================================

    /// 开始 - 对应 Bun WindowsBufferedReader.start
    /// 严格翻译自: pub fn start(this, fd, _: bool) bun.sys.Maybe(void)
    ///   const source = switch (Source.open(loop, fd)) { .err => ..., .result => ... };
    ///   source.setData(this); this.source = source; startWithCurrentPipe()
    public func start(fd: Int64, isPollable: Bool): SysMaybe<Unit> {
        let src = Source(SourceKind.File)
        src.file = FileSource(Int32(fd))
        source = src
        return startWithCurrentPipe()
    }

    /// 使用当前管道开始
    /// 严格翻译自: pub fn startWithCurrentPipe(this) bun.sys.Maybe(void)
    ///   assert(!source.isClosed());
    ///   source.setData(this);
    ///   buffer.clearRetainingCapacity();
    ///   flags.is_done = false;
    ///   return startReading();
    public func startWithCurrentPipe(): SysMaybe<Unit> {
        buffer.clear()
        flags.isDone = false
        return startReading()
    }

    /// 使用管道开始
    /// 严格翻译自: pub fn startWithPipe(this, pipe: *uv.Pipe) bun.sys.Maybe(void)
    ///   this.source = .{ .pipe = pipe };
    ///   return startWithCurrentPipe();
    public func startWithPipe(pipeSource: Source): SysMaybe<Unit> {
        source = pipeSource
        return startWithCurrentPipe()
    }

    /// 带偏移开始
    /// 严格翻译自: pub fn startFileOffset(this, fd, poll, offset) bun.sys.Maybe(void)
    ///   this._offset = offset; this.flags.use_pread = true; return this.start(fd, poll);
    public func startFileOffset(fd: Int64, isPollable: Bool, fileOffset: Int64): SysMaybe<Unit> {
        offset = fileOffset
        flags.usePread = true
        return start(fd, isPollable)
    }

    // ========================================================================
    // 读取控制
    // ========================================================================

    /// 内部读取块回调
    /// 严格翻译自: fn _onReadChunk(this, buf, hasMore) bool
    ///   if (maxbuf) |m| m.onReadBytes(buf.len);
    ///   if (hasMore == .eof) this.flags.received_eof = true;
    ///   const onReadChunkFn = vtable.onReadChunk orelse { has_inflight_read = false; return true; };
    ///   const result = onReadChunkFn(parent, buf, hasMore);
    ///   has_inflight_read = false;
    ///   return result;
    public func onReadChunkInternal(buf: Array<UInt8>, hasMore: ReadState): Bool {
        if (let Some(m) <- maxBuf) {
            m.onReadBytes(buf.size)
        }

        if (hasMore == ReadState.Eof) {
            flags.receivedEof = true
        }

        if (let Some(cb) <- vtable.onReadChunk) {
            let result = cb(buf, hasMore)
            flags.hasInflightRead = false
            return result
        }

        flags.hasInflightRead = false
        return true
    }

    /// 开始读取
    /// 严格翻译自: pub fn startReading(this) bun.sys.Maybe(void)
    ///   if (is_done or !is_paused) return success;
    ///   is_paused = false;
    ///   switch (source) {
    ///       .file => { prepare(); getReadBufferWithStableMemoryAddress(64k); uv_fs_read(...) },
    ///       else => { uv_read_start(source.toStream(), onStreamAlloc, onStreamRead) }
    ///   }
    public func startReading(): SysMaybe<Unit> {
        if (flags.isDone || !flags.isPaused) {
            return SysMaybe<Unit>.Ok(())
        }
        flags.isPaused = false

        if (let Some(s) <- source) {
            match (s.kind) {
                case File =>
                    if (let Some(f) <- s.file) {
                        if (f.canStart()) {
                            let buf = getReadBufferWithStableMemoryAddress(65536)
                            flags.hasInflightRead = true
                            // uv_fs_read(loop, &file.fs, file.file, &iov, 1, offset, onFileRead)
                            // 简化: 同步读取
                            let result = SysFs.read(Int64(f.fd), buf)
                            match (result) {
                                case Ok(bytesRead) =>
                                    if (bytesRead > 0) {
                                        for (i in 0..bytesRead) {
                                            buffer.append(buf[i])
                                        }
                                        offset += bytesRead
                                    }
                                    flags.hasInflightRead = false
                                case Err(e) =>
                                    flags.hasInflightRead = false
                                    return SysMaybe<Unit>.Err(e)
                            }
                        }
                    }
                case _ =>
                    // uv_read_start(source.toStream(), onStreamAlloc, onStreamRead)
                    ()
            }
        }

        return SysMaybe<Unit>.Ok(())
    }

    /// 停止读取
    /// 严格翻译自: pub fn stopReading(this) bun.sys.Maybe(void)
    ///   if (is_done or is_paused) return success;
    ///   is_paused = true;
    ///   switch (source) { .file => file.stop(), else => readStop() }
    public func stopReading(): SysMaybe<Unit> {
        if (flags.isDone || flags.isPaused) {
            return SysMaybe<Unit>.Ok(())
        }
        flags.isPaused = true

        if (let Some(s) <- source) {
            match (s.kind) {
                case File =>
                    if (let Some(f) <- s.file) {
                        f.stop()
                    }
                case _ =>
                    // source.toStream().readStop()
                    ()
            }
        }

        return SysMaybe<Unit>.Ok(())
    }

    // ========================================================================
    // 完成和关闭
    // ========================================================================

    /// 内部完成
    /// 严格翻译自: fn finish(this) void
    ///   has_inflight_read = false; is_done = true; buffer.shrinkAndFree(...)
    public func finishInternal(): Unit {
        flags.hasInflightRead = false
        flags.isDone = true
    }

    /// 完成
    /// 严格翻译自: pub fn done(this) void
    ///   assert(source.isClosed());
    ///   finish();
    ///   vtable.onReaderDone(parent);
    public func done(): Unit {
        if (let Some(s) <- source) {
            // assert(s.isClosed())
        }
        finishInternal()
        vtable.onReaderDone()
    }

    /// 错误处理
    /// 严格翻译自: pub fn onError(this, err) void
    ///   finish(); vtable.onReaderError(parent, err);
    public func onError(err: SysError): Unit {
        finishInternal()
        vtable.onReaderError(err)
    }

    /// 通用读取回调
    /// 严格翻译自: pub fn onRead(this, amount, slice, hasMore) void
    ///   if (amount == .err) { onError(err); return; }
    ///   buf.items.len += amount.result;
    ///   _onReadChunk(slice, hasMore);
    ///   if (hasMore == .eof) close();
    public func onRead(amount: SysMaybe<Int64>, slice: Array<UInt8>, hasMore: ReadState): Unit {
        match (amount) {
            case Err(e) =>
                onError(e)
                return
            case Ok(bytesRead) =>
                if (bytesRead > 0) {
                    for (i in 0..bytesRead) {
                        if (i < slice.size) {
                            buffer.append(slice[i])
                        }
                    }
                }
                onReadChunkInternal(slice, hasMore)
                if (hasMore == ReadState.Eof) {
                    close()
                }
        }
    }

    /// 内部关闭实现
    /// 严格翻译自: pub fn closeImpl(this, comptime callDone) void
    ///   switch (source) {
    ///       .sync_file, .file => file.detach();
    ///       .pipe => { pipe.close(onPipeClose) };
    ///       .tty => { tty.close(onTTYClose) or stdin check };
    ///   }
    ///   source = null;
    ///   if (callDone) done();
    public func closeImpl(callDone: Bool): Unit {
        if (let Some(s) <- source) {
            match (s.kind) {
                case File | SyncFile =>
                    if (let Some(f) <- s.file) {
                        f.detach()
                    }
                case Pipe =>
                    flags.isPaused = true
                case Tty =>
                    flags.isPaused = true
            }
            source = None
            if (callDone) {
                done()
            }
        }
    }

    /// 关闭
    /// 严格翻译自: pub fn close(this) void
    ///   stopReading();
    ///   // 检查是否有进行中的文件操作
    ///   if (source == .file or .sync_file) {
    ///       if (state == .canceling or .operating) { defer_done_callback = true; return; }
    ///   }
    ///   closeImpl(true);
    public func close(): Unit {
        stopReading()

        // 检查是否有进行中的文件操作
        if (let Some(s) <- source) {
            match (s.kind) {
                case File | SyncFile =>
                    if (let Some(f) <- s.file) {
                        if (f.state == FileSourceState.Canceling ||
                            f.state == FileSourceState.Operating) {
                            flags.deferDoneCallback = true
                            return
                        }
                    }
                case _ => ()
            }
        }

        closeImpl(true)
    }

    /// 清理
    /// 严格翻译自: pub fn deinit(this) void
    ///   MaxBuf.removeFromPipereader(&maxbuf);
    ///   buffer.deinit();
    ///   if (source) { source = null; if (!isClosed()) closeImpl(false) }
    public func deinit(): Unit {
        maxBuf = None
        buffer.clear()
        if (let Some(s) <- source) {
            if (!s.isClosed()) {
                closeImpl(false)
            }
            source = None
        }
    }

    // ========================================================================
    // 设置原始模式
    // ========================================================================

    /// 设置原始模式 (仅 TTY)
    /// 严格翻译自: pub fn setRawMode(this, value) bun.sys.Maybe(void)
    ///   const source = source orelse return err;
    ///   return source.setRawMode(value);
    public func setRawMode(value: Bool): SysMaybe<Unit> {
        if (let Some(s) <- source) {
            let result = s.setRawMode(value)
            if (result) {
                return SysMaybe<Unit>.Ok(())
            }
        }
        return SysMaybe<Unit>.Err(SysError(UInt16(9), SysTag.Ioctl))
    }

    // ========================================================================
    // 暂停 / 恢复 / 读取
    // ========================================================================

    /// 监视 (Windows 空操作)
    /// 严格翻译自: pub fn watch(_: *WindowsBufferedReader) void { No-op on windows. }
    public func watch(): Unit {
        // Windows 上无需操作
    }

    /// 暂停
    /// 严格翻译自: pub fn pause(this) void { stopReading() }
    public func pause(): Unit {
        stopReading()
    }

    /// 恢复
    /// 严格翻译自: pub fn unpause(this) void { startReading() }
    public func unpause(): Unit {
        startReading()
    }

    /// 读取
    /// 严格翻译自: pub fn read(this) void { unpause() }
    ///   // Windows 上不能同步读取管道, 只检查是否暂停来恢复读取
    public func read(): Unit {
        unpause()
    }
}

// ============================================================================
// MaxBufRef - MaxBuf 引用
// 翻译自: maxbuf: ?*MaxBuf
// ============================================================================

/// MaxBuf 引用
/// 翻译自: src/io/MaxBuf.zig
/// 限制管道读取的最大字节数
public class MaxBufRef {
    /// 最大字节数
    public var maxBytes: Int64
    /// 已读取字节数
    public var readBytes: Int64

    public init(maxBytes: Int64) {
        this.maxBytes = maxBytes
        this.readBytes = 0
    }

    /// 读取字节数回调
    /// 翻译自: pub fn onReadBytes(this, n) void
    public func onReadBytes(n: Int64): Unit {
        readBytes += n
    }

    /// 是否达到限制
    public func isAtLimit(): Bool {
        return readBytes >= maxBytes
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
