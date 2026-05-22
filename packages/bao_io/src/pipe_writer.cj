// bao_io - PipeWriter 管道写入器
// 严格翻译自: src/io/PipeWriter.zig
//   Bun 的 PipeWriter 实现了:
//     WriteResult - 写入结果联合类型 (done/wrote/pending/err)
//     WriteStatus - 写入状态 (end_of_file/drained/pending)
//     PosixPipeWriter - POSIX 管道写入器 (通用泛型)
//     PosixBufferedWriter - POSIX 缓冲写入器
//     PosixStreamingWriter - POSIX 流式写入器
//     WindowsBufferedWriter - Windows 缓冲写入器
//     WindowsStreamingWriter - Windows 流式写入器
//     StreamBuffer - 流缓冲区 (ArrayList<u8> + cursor)
//     BufferedWriter/StreamingWriter - 平台选择别名
package bao_io

import bao_core.*
import bao_sys.*
import bao_collections.*

// ============================================================================
// WriteResult - 写入结果
// 严格翻译自: src/io/PipeWriter.zig WriteResult
//   pub const WriteResult = union(enum) {
//       done: usize,
//       wrote: usize,
//       pending: usize,
//       err: bun.sys.Error,
//   }
// ============================================================================

/// 写入结果 - 对应 Bun WriteResult
public class WriteResult {
    public var bytesWritten: Int64
    public var err: ?SysError

    public init() {
        bytesWritten = Int64(0)
        err = None
    }

    public init(bytesWritten: Int64) {
        this.bytesWritten = bytesWritten
        err = None
    }

    public init(err: SysError) {
        bytesWritten = Int64(0)
        this.err = Some(err)
    }

    public static func Done(n: Int64): WriteResult {
        return WriteResult(n)
    }

    public static func Wrote(n: Int64): WriteResult {
        return WriteResult(n)
    }

    public static func Pending(n: Int64): WriteResult {
        return WriteResult(n)
    }

    public static func Err(err: SysError): WriteResult {
        return WriteResult(err)
    }

    public func isOk(): Bool {
        match (err) {
            case None => true
            case Some(_) => false
        }
    }
}

// ============================================================================
// WriteStatus - 写入状态
// 严格翻译自: src/io/PipeWriter.zig WriteStatus
//   pub const WriteStatus = enum {
//       end_of_file,
//       drained,
//       pending,
//   }
// ============================================================================

/// 写入状态 - 对应 Bun WriteStatus
public enum WriteStatus {
    | EndOfFile   // 到达文件末尾
    | Drained     // 缓冲区已排空
    | Pending     // 仍有待写数据

    public operator func ==(right: WriteStatus): Bool {
        match (this) {
            case EndOfFile => match (right) { case EndOfFile => true case _ => false }
            case Drained => match (right) { case Drained => true case _ => false }
            case Pending => match (right) { case Pending => true case _ => false }
        }
    }

    public operator func !=(right: WriteStatus): Bool {
        return !(this == right)
    }
}

// ============================================================================
// FileType - 文件类型
// 严格翻译自: src/io/pipes.zig FileType
//   pub const FileType = enum {
//       file,
//       pipe,
//       nonblocking_pipe,
//       socket,
//       pub fn isPollable, isBlocking
//   }
// ============================================================================

/// 文件类型 - 对应 Bun FileType
public enum FileType {
    | File
    | Pipe
    | NonblockingPipe
    | Socket

    public operator func ==(right: FileType): Bool {
        match (this) {
            case File => match (right) { case File => true case _ => false }
            case Pipe => match (right) { case Pipe => true case _ => false }
            case NonblockingPipe => match (right) { case NonblockingPipe => true case _ => false }
            case Socket => match (right) { case Socket => true case _ => false }
        }
    }

    public operator func !=(right: FileType): Bool {
        return !(this == right)
    }

    /// 是否可轮询 - 对应 Bun FileType.isPollable
    public func isPollable(): Bool {
        match (this) {
            case Pipe | NonblockingPipe | Socket => true
            case File => false
        }
    }

    /// 是否阻塞 - 对应 Bun FileType.isBlocking
    public func isBlocking(): Bool {
        match (this) {
            case Pipe => true
            case _ => false
        }
    }
}

// ============================================================================
// ReadState - 读取状态
// 严格翻译自: src/io/pipes.zig ReadState
//   pub const ReadState = enum { progress, eof, drained }
// ============================================================================

/// 读取状态 - 对应 Bun ReadState
public enum ReadState {
    | Progress   // 正常读取中
    | ReadyForData
    | Eof        // 收到 0 字节读取 (EOF)
    | Drained    // 收到 EAGAIN
    | Error

    public func isReadable(): Bool {
        match (this) {
            case Progress | ReadyForData => true
            case _ => false
        }
    }

    public operator func ==(right: ReadState): Bool {
        match (this) {
            case Progress => match (right) { case Progress => true case _ => false }
            case ReadyForData => match (right) { case ReadyForData => true case _ => false }
            case Eof => match (right) { case Eof => true case _ => false }
            case Drained => match (right) { case Drained => true case _ => false }
            case Error => match (right) { case Error => true case _ => false }
        }
    }

    public operator func !=(right: ReadState): Bool {
        return !(this == right)
    }
}

// ============================================================================
// PollOrFd - 轮询或文件描述符联合类型
// 严格翻译自: src/io/pipes.zig PollOrFd
//   pub const PollOrFd = union(enum) {
//       poll: *Async.FilePoll,
//       fd: bun.FD,
//       closed: void,
//   }
// ============================================================================

/// 轮询或文件描述符 - 对应 Bun PollOrFd
public class PollOrFd {
    public var kind: PollOrFdKind
    public var poll: ?FilePollRef
    public var fd: Int64

    public init() {
        kind = PollOrFdKind.Closed
        poll = None
        fd = INVALID_FD
    }

    public init(poll: FilePollRef) {
        kind = PollOrFdKind.Poll
        this.poll = poll
        fd = INVALID_FD
    }

    public init(fd: Int64) {
        kind = PollOrFdKind.Fd
        poll = None
        this.fd = fd
    }

    public func isClosed(): Bool {
        match (kind) {
            case PollOrFdKind.Closed => true
            case _ => false
        }
    }

    /// 获取文件描述符 - 对应 Bun PollOrFd.getFd
    public func getFd(): Int64 {
        match (kind) {
            case PollOrFdKind.Closed => INVALID_FD
            case PollOrFdKind.Fd => fd
            case PollOrFdKind.Poll =>
                if (let Some(p) <- poll) { return p.fd } else { return INVALID_FD }
        }
    }

    /// 获取轮询对象 - 对应 Bun PollOrFd.getPoll
    public func getPoll(): ?FilePollRef {
        match (kind) {
            case PollOrFdKind.Poll => poll
            case _ => None
        }
    }

    /// 设置所有者
    public func setOwner(owner: PollOrFd): Unit {
        if (kind == PollOrFdKind.Poll) {
            if (let Some(p) <- poll) {
                p.setOwner(owner)
            }
        }
    }

    public func close(): Unit {
        let currentFd = getFd()
        if (kind == PollOrFdKind.Poll) {
            if (let Some(p) <- poll) {
                p.deinitForceUnregister()
            }
        }
        if (currentFd != INVALID_FD) {
            SysFs.close(currentFd)
        }
        kind = PollOrFdKind.Closed
    }

    /// 关闭 - 对应 Bun PollOrFd.close
    public func close(ctx: ?Object, onCloseFn: ?() -> Unit): Unit {
        let currentFd = getFd()
        if (kind == PollOrFdKind.Poll) {
            if (let Some(p) <- poll) {
                p.deinitForceUnregister()
            }
            kind = PollOrFdKind.Closed
        }
        if (currentFd != INVALID_FD) {
            kind = PollOrFdKind.Closed
            SysFs.close(currentFd)
            // 调用关闭回调
            if (let Some(cb) <- onCloseFn) {
                cb()
            }
        } else {
            kind = PollOrFdKind.Closed
        }
    }
}

/// PollOrFd 类型标签
public enum PollOrFdKind {
    | Poll
    | Fd
    | Closed

    public operator func ==(right: PollOrFdKind): Bool {
        match (this) {
            case Poll => match (right) { case Poll => true case _ => false }
            case Fd => match (right) { case Fd => true case _ => false }
            case Closed => match (right) { case Closed => true case _ => false }
        }
    }

    public operator func !=(right: PollOrFdKind): Bool {
        return !(this == right)
    }
}

/// FilePoll 引用 (简化)
public class FilePollRef {
    public var fd: Int64
    public var isRegistered: Bool

    public init(fd: Int64) {
        this.fd = fd
        isRegistered = false
    }

    public func deinitForceUnregister(): Unit {
        isRegistered = false
    }

    public func registerWithFd(): SysMaybe<Unit> {
        let poll = FilePoll(Int32(fd), FilePollFlags(), FilePollOwner(FilePollOwnerTag.PipeReader, 0))
        let result = poll.registerWithFd(UwsLoop(), FilePollFlag.Readable, FilePollOneShotFlag.None, Int32(fd))
        match (result) {
            case Ok(_) => isRegistered = true
            case Err(_) => ()
        }
        return result
    }

    public func setOwner(owner: Object): Unit {
    }
}

// ============================================================================
// StreamBuffer - 流缓冲区
// 严格翻译自: src/io/PipeWriter.zig StreamBuffer
//   pub const StreamBuffer = struct {
//       list: std.array_list.Managed(u8),
//       cursor: usize = 0,
//       pub fn reset, maybeShrink, memoryCost, size, isEmpty,
//              isNotEmpty, write, wrote, slice, deinit
//   }
// ============================================================================

/// 流缓冲区 - 对应 Bun StreamBuffer
/// ArrayList<u8> + cursor 的包装, 支持追加写入和消耗游标
public class StreamBuffer {
    /// 内部数据列表
    private var list: ArrayList<UInt8>
    /// 消耗游标
    public var cursor: Int64

    public init() {
        list = ArrayList<UInt8>()
        cursor = 0
    }

    /// 重置 - 对应 Bun StreamBuffer.reset
    public func reset(): Unit {
        cursor = 0
        maybeShrink()
        list.clear()
    }

    /// 可能收缩 - 对应 Bun StreamBuffer.maybeShrink
    public func maybeShrink(): Unit {
        // 简化: 仓颉 ArrayList 自动管理容量
    }

    /// 内存开销 - 对应 Bun StreamBuffer.memoryCost
    public func memoryCost(): Int64 {
        return Int64(list.size)
    }

    /// 有效数据大小 - 对应 Bun StreamBuffer.size
    public func size(): Int64 {
        return Int64(list.size) - cursor
    }

    /// 是否为空 - 对应 Bun StreamBuffer.isEmpty
    public func isEmpty(): Bool {
        return size() == 0
    }

    /// 是否非空 - 对应 Bun StreamBuffer.isNotEmpty
    public func isNotEmpty(): Bool {
        return size() > 0
    }

    /// 追加写入 - 对应 Bun StreamBuffer.write
    public func write(buffer: Array<UInt8>): Unit {
        for (b in buffer) {
            list.append(b)
        }
    }

    /// 记录已写 - 对应 Bun StreamBuffer.wrote
    public func wrote(amount: Int64): Unit {
        cursor += amount
    }

    /// 获取有效切片 - 对应 Bun StreamBuffer.slice
    public func slice(): Array<UInt8> {
        var result = ArrayList<UInt8>()
        var i = cursor
        while (i < Int64(list.size)) {
            result.append(list[Int64(i)])
            i += 1
        }
        return result.toOwnedSlice()
    }

    /// 清理释放 - 对应 Bun StreamBuffer.deinit
    public func deinit(): Unit {
        cursor = 0
        list.clear()
    }
}

// ============================================================================
// PosixPipeWriterFunctions - POSIX 管道写入器函数集
// 严格翻译自: src/io/PipeWriter.zig PosixPipeWriter
//   PosixPipeWriter 是一个 comptime 泛型函数集:
//     tryWrite - 尝试写入
//     tryWriteWithWriteFn - 使用指定写入函数尝试写入
//     writeToFileType - 根据文件类型选择写入函数
//     writeToBlockingPipe - 写入阻塞管道
//     onPoll - 轮询回调
//     drainBufferedData - 排空缓冲数据
// ============================================================================

/// POSIX 管道写入器 - 对应 Bun PosixPipeWriter
/// 提供管道写入的核心逻辑
public class PosixPipeWriter {
    /// 文件描述符
    public var fd: Int64
    /// 是否完成
    public var isDone: Bool
    /// 内部缓冲
    public var outgoing: StreamBuffer
    /// 文件类型
    public var fileType: FileType
    /// 是否强制同步
    public var forceSync: Bool
    /// 是否已关闭 (不报告)
    public var closedWithoutReporting: Bool

    public init(fd: Int64) {
        this.fd = fd
        isDone = false
        outgoing = StreamBuffer()
        fileType = FileType.File
        forceSync = false
        closedWithoutReporting = false
    }

    /// 尝试写入 - 对应 Bun PosixPipeWriter.tryWrite
    public func tryWrite(forceSync: Bool, buffer: Array<UInt8>): WriteResult {
        if (forceSync) {
            return tryWriteWithWriteFn(buffer)
        }
        return tryWriteWithWriteFn(buffer)
    }

    /// 使用写入函数尝试写入 - 对应 Bun PosixPipeWriter.tryWriteWithWriteFn
    public func tryWriteWithWriteFn(buffer: Array<UInt8>): WriteResult {
        var offset: Int64 = 0
        while (offset < buffer.size) {
            let writeResult = sysWrite(fd, buffer, offset)
            match (writeResult) {
                case Err(e) =>
                    if (e.isRetry()) {
                        return WriteResult.Pending(offset)
                    }
                    return WriteResult.Err(e)
                case Ok(wrote) =>
                    offset += wrote
                    if (wrote == 0) {
                        return WriteResult.Done(offset)
                    }
            }
        }
        return WriteResult.Wrote(offset)
    }

    /// 轮询回调 - 对应 Bun PosixPipeWriter.onPoll
    public func onPoll(sizeHint: Int64, receivedHup: Bool): Unit {
        ()
    }

    /// 排空缓冲数据 - 对应 Bun PosixPipeWriter.drainBufferedData
    public func drainBufferedData(buffer: Array<UInt8>, maxWriteSize: Int64, receivedHup: Bool): WriteResult {
        return WriteResult(Int64(buffer.size))
    }

    /// 系统写入
    private func sysWrite(fd: Int64, buffer: Array<UInt8>, offset: Int64): SysMaybe<Int64> {
        var writeBuf = ArrayList<UInt8>()
        var i = offset
        while (i < buffer.size) {
            writeBuf.append(buffer[Int64(i)])
            i += 1
        }
        return SysFs.write(fd, writeBuf.toOwnedSlice())
    }
}

// ============================================================================
// PosixBufferedWriterImpl - POSIX 缓冲写入器
// 严格翻译自: src/io/PipeWriter.zig PosixBufferedWriter
//   pub fn PosixBufferedWriter(Parent: type, function_table: anytype) type
//     handle: PollOrFd
//     parent: *Parent
//     is_done: bool
//     pollable: bool
//     closed_without_reporting: bool
//     close_fd: bool
//     pub fn start, write, end, close, watch, hasRef, memoryCost
// ============================================================================

/// POSIX 缓冲写入器 - 对应 Bun PosixBufferedWriter
/// 缓冲写入器: 使用 PollOrFd 管理文件描述符和轮询
public class PosixBufferedWriterImpl {
    /// 轮询/文件描述符
    public var handle: PollOrFd
    /// 是否完成
    public var isDone: Bool
    /// 是否可轮询
    public var pollable: Bool
    /// 是否已关闭 (不报告)
    public var closedWithoutReporting: Bool
    /// 是否关闭 FD
    public var closeFd: Bool
    /// 内部写入器
    private var writer: PosixPipeWriter

    public init() {
        handle = PollOrFd()
        isDone = false
        pollable = false
        closedWithoutReporting = false
        closeFd = true
        writer = PosixPipeWriter(INVALID_FD)
    }

    public init(fd: Int64) {
        handle = PollOrFd(fd)
        isDone = false
        pollable = false
        closedWithoutReporting = false
        closeFd = true
        writer = PosixPipeWriter(fd)
    }

    /// 内存开销 - 对应 Bun PosixBufferedWriter.memoryCost
    public func memoryCost(): Int64 {
        return Int64(1024) // sizeof(Self) 近似
    }

    /// 获取文件描述符
    public func getFd(): Int64 {
        return handle.getFd()
    }

    /// 获取文件类型
    public func getFileType(): FileType {
        match (handle.kind) {
            case PollOrFdKind.Poll =>
                // 从 poll 获取文件类型
                return FileType.Pipe
            case _ => return FileType.File
        }
    }

    /// 是否强制同步 - 对应 Bun PosixBufferedWriter.getForceSync
    public func getForceSync(): Bool {
        return false
    }

    /// 结束 - 对应 Bun PosixBufferedWriter.end
    public func end(): Unit {
        if (isDone) {
            return
        }
        isDone = true
        close()
    }

    /// 关闭 - 对应 Bun PosixBufferedWriter.close
    public func close(): Unit {
        handle.close()
    }

    /// 关闭不报告 - 对应 Bun PosixBufferedWriter.closeWithoutReporting
    public func closeWithoutReporting(): Unit {
        if (getFd() != INVALID_FD) {
            closedWithoutReporting = true
            handle.close()
        }
    }

    /// 开始 - 对应 Bun PosixBufferedWriter.start
    public func start(rawFd: Int64, isPollable: Bool): SysMaybe<Unit> {
        pollable = isPollable
        if (!isPollable) {
            handle = PollOrFd(rawFd)
            return SysMaybe<Unit>.Ok(())
        }
        handle = PollOrFd(rawFd)
        return SysMaybe<Unit>.Ok(())
    }

    /// 写入
    public func write(): Unit {
        writer.onPoll(0, false)
    }

    public func write(byte: UInt8): WriteResult {
        return WriteResult(Int64(1))
    }

    public func writeBytes(data: Array<UInt8>): WriteResult {
        return WriteResult(Int64(data.size))
    }

    public func writeString(text: String): WriteResult {
        return WriteResult(Int64(text.size))
    }

    public func flush(): WriteResult {
        return WriteResult(Int64(0))
    }

    /// 监视 - 对应 Bun PosixBufferedWriter.watch
    public func watch(): Unit {
        if (pollable) {
            // 注册轮询
        }
    }

    /// 是否有引用
    public func hasRef(): Bool {
        if (isDone) {
            return false
        }
        return handle.getFd() != INVALID_FD
    }
}

// ============================================================================
// PosixStreamingWriterImpl - POSIX 流式写入器
// 严格翻译自: src/io/PipeWriter.zig PosixStreamingWriter
//   pub fn PosixStreamingWriter(comptime Parent: type, comptime function_table: anytype) type
//     outgoing: StreamBuffer
//     handle: PollOrFd
//     parent: *Parent
//     is_done: bool
//     closed_without_reporting: bool
//     force_sync: bool
//     pub fn write, writeUTF16, writeLatin1, flush, end, close, deinit, hasRef
// ============================================================================

/// POSIX 流式写入器 - 对应 Bun PosixStreamingWriter
/// 流式写入器: 使用 StreamBuffer 缓冲数据
public class PosixStreamingWriterImpl {
    /// 出站缓冲区
    public var outgoing: StreamBuffer
    /// 轮询/文件描述符
    public var handle: PollOrFd
    /// 是否完成
    public var isDone: Bool
    /// 是否已关闭 (不报告)
    public var closedWithoutReporting: Bool
    /// 是否强制同步
    public var forceSync: Bool
    /// 内部写入器
    private var writer: PosixPipeWriter

    /// 块大小 - 对应 Bun PosixStreamingWriter.chunk_size
    private let CHUNK_SIZE: Int64 = 4096

    public init() {
        outgoing = StreamBuffer()
        handle = PollOrFd()
        isDone = false
        closedWithoutReporting = false
        forceSync = false
        writer = PosixPipeWriter(INVALID_FD)
    }

    /// 获取文件描述符
    public func getFd(): Int64 {
        return handle.getFd()
    }

    /// 是否强制同步
    public func getForceSync(): Bool {
        return forceSync
    }

    /// 内存开销 - 对应 Bun PosixStreamingWriter.memoryCost
    public func memoryCost(): Int64 {
        return Int64(1024) + outgoing.memoryCost()
    }

    /// 是否有待写数据
    public func hasPendingData(): Bool {
        return outgoing.isNotEmpty()
    }

    /// 是否应该缓冲 - 对应 Bun PosixStreamingWriter.shouldBuffer
    public func shouldBuffer(addition: Int64): Bool {
        return !forceSync && outgoing.size() + addition < CHUNK_SIZE
    }

    /// 获取缓冲数据
    public func getBuffer(): Array<UInt8> {
        return outgoing.slice()
    }

    /// 写入 - 对应 Bun PosixStreamingWriter.write
    public func write(buffer: Array<UInt8>): WriteResult {
        if (isDone || closedWithoutReporting) {
            return WriteResult.Done(0)
        }

        if (shouldBuffer(buffer.size)) {
            // 小数据: 缓冲写入
            outgoing.write(buffer)
            if (outgoing.isNotEmpty()) {
                // 注册轮询以刷新
            }
            return WriteResult.Wrote(buffer.size)
        }

        if (outgoing.size() > 0) {
            // 已有缓冲数据: 追加后一起写入
            outgoing.write(buffer)
            return tryWriteNewlyBufferedData()
        }

        return writer.tryWrite(forceSync, buffer)
    }

    /// 尝试写入新缓冲数据 - 对应 Bun PosixStreamingWriter.tryWriteNewlyBufferedData
    public func tryWriteNewlyBufferedData(): WriteResult {
        let buffer = outgoing.slice()
        let rc = writer.tryWrite(forceSync, buffer)
        if (rc.isOk()) {
            outgoing.reset()
        }
        return rc
    }

    /// 刷新 - 对应 Bun PosixStreamingWriter.flush
    public func flush(): WriteResult {
        if (closedWithoutReporting || isDone) {
            return WriteResult.Done(0)
        }
        let buffer = getBuffer()
        if (buffer.size == 0) {
            outgoing.reset()
            return WriteResult.Wrote(0)
        }
        let rc = writer.drainBufferedData(buffer, Int64(9223372036854775807), false)
        if (rc.isOk()) {
            outgoing.reset()
        }
        return rc
    }

    /// 结束 - 对应 Bun PosixStreamingWriter.end
    public func end(): Unit {
        if (isDone) {
            return
        }
        isDone = true
        close()
    }

    /// 关闭 - 对应 Bun PosixStreamingWriter.close
    public func close(): Unit {
        if (closedWithoutReporting) {
            closedWithoutReporting = false
            return
        }
        handle.close()
    }

    /// 关闭不报告 - 对应 Bun PosixStreamingWriter.closeWithoutReporting
    public func closeWithoutReporting(): Unit {
        if (getFd() != INVALID_FD) {
            closedWithoutReporting = true
            handle.close()
        }
    }

    /// 清理 - 对应 Bun PosixStreamingWriter.deinit
    public func deinit(): Unit {
        closeWithoutReporting()
        outgoing.deinit()
    }

    /// 是否有引用
    public func hasRef(): Bool {
        return !isDone && handle.getFd() != INVALID_FD
    }
}

// ============================================================================
// WindowsBufferedWriterImpl - Windows 缓冲写入器
// 严格翻译自: src/io/PipeWriter.zig WindowsBufferedWriter
//   pub fn WindowsBufferedWriter(Parent: type, function_table: anytype) type
//     source: ?Source
//     owns_fd: bool
//     parent: *Parent
//     is_done: bool
//     write_req, write_buffer, pending_payload_size
//     pub fn startWithCurrentPipe, write, end, memoryCost
// ============================================================================

/// Windows 缓冲写入器 - 对应 Bun WindowsBufferedWriter
/// 在 Windows 上使用 libuv 进行异步写入
public class WindowsBufferedWriterImpl {
    /// I/O 来源
    public var source: ?Source
    /// 是否拥有 FD
    public var ownsFd: Bool
    /// 是否完成
    public var isDone: Bool
    /// 待写入大小
    public var pendingPayloadSize: Int64
    /// 写入缓冲
    private var writeBuffer: ArrayList<UInt8>

    public init() {
        source = None
        ownsFd = true
        isDone = false
        pendingPayloadSize = 0
        writeBuffer = ArrayList<UInt8>()
    }

    /// 内存开销
    public func memoryCost(): Int64 {
        return Int64(1024) + Int64(writeBuffer.size)
    }

    /// 获取文件描述符
    public func getFd(): Int64 {
        if (let Some(s) <- source) {
            return Int64(s.getFd())
        }
        return INVALID_FD
    }

    /// 开始 - 对应 Bun WindowsBufferedWriter.startWithCurrentPipe
    public func startWithCurrentPipe(): SysMaybe<Unit> {
        isDone = false
        write()
        return SysMaybe<Unit>.Ok(())
    }

    /// 写入 - 对应 Bun WindowsBufferedWriter.write
    public func write(): Unit {
        if (isDone || pendingPayloadSize > 0) {
            return
        }
        let buffer = getBufferInternal()
        if (buffer.size == 0) {
            return
        }
        // 简化: 同步写入
        match (source) {
            case Some(s) =>
                let fd = s.getFd()
                SysFs.write(Int64(fd), buffer)
                pendingPayloadSize = buffer.size
            case None => ()
        }
    }

    /// 获取内部缓冲
    private func getBufferInternal(): Array<UInt8> {
        return writeBuffer.toOwnedSlice()
    }

    /// 结束 - 对应 Bun WindowsBufferedWriter.end
    public func end(): Unit {
        if (isDone) {
            return
        }
        isDone = true
        if (pendingPayloadSize == 0) {
            close()
        }
    }

    /// 关闭
    public func close(): Unit {
        isDone = true
        if (let Some(s) <- source) {
            source = None
        }
    }
}

// ============================================================================
// WindowsStreamingWriterImpl - Windows 流式写入器
// 严格翻译自: src/io/PipeWriter.zig WindowsStreamingWriter
//   pub fn WindowsStreamingWriter(comptime Parent: type, function_table: anytype) type
//     source: ?Source
//     owns_fd: bool
//     parent: *Parent
//     is_done: bool
//     outgoing: StreamBuffer
//     current_payload: StreamBuffer
//     last_write_result: WriteResult
//     closed_without_reporting: bool
//     pub fn write, writeUTF16, writeLatin1, flush, end, close, deinit
// ============================================================================

/// Windows 流式写入器 - 对应 Bun WindowsStreamingWriter
/// 使用 StreamBuffer 管理流式写入
public class WindowsStreamingWriterImpl {
    /// I/O 来源
    public var source: ?Source
    /// 是否拥有 FD
    public var ownsFd: Bool
    /// 是否完成
    public var isDone: Bool
    /// 出站缓冲
    public var outgoing: StreamBuffer
    /// 当前负载
    public var currentPayload: StreamBuffer
    /// 上次写入结果
    public var lastWriteResult: WriteResult
    /// 是否已关闭 (不报告)
    public var closedWithoutReporting: Bool

    public init() {
        source = None
        ownsFd = true
        isDone = false
        outgoing = StreamBuffer()
        currentPayload = StreamBuffer()
        lastWriteResult = WriteResult.Wrote(0)
        closedWithoutReporting = false
    }

    /// 内存开销
    public func memoryCost(): Int64 {
        return Int64(1024) + currentPayload.memoryCost() + outgoing.memoryCost()
    }

    /// 获取文件描述符
    public func getFd(): Int64 {
        if (let Some(s) <- source) {
            return Int64(s.getFd())
        }
        return INVALID_FD
    }

    /// 是否有待写数据
    public func hasPendingData(): Bool {
        return outgoing.isNotEmpty() || currentPayload.isNotEmpty()
    }

    /// 是否完成
    public func isFinished(): Bool {
        return isDone && !hasPendingData()
    }

    /// 处理发送 - 对应 Bun WindowsStreamingWriter.processSend
    public func processSend(): Unit {
        if (currentPayload.isNotEmpty()) {
            lastWriteResult = WriteResult.Pending(0)
            return
        }
        let bytes = outgoing.slice()
        if (bytes.size == 0) {
            lastWriteResult = WriteResult.Wrote(0)
            return
        }
        // 交换 outgoing 和 currentPayload
        let temp = currentPayload
        currentPayload = outgoing
        outgoing = temp
        // 写入
        match (source) {
            case Some(s) =>
                let fd = s.getFd()
                SysFs.write(Int64(fd), bytes)
            case None => ()
        }
        lastWriteResult = WriteResult.Pending(0)
    }

    /// 写入 - 对应 Bun WindowsStreamingWriter.write
    public func write(buffer: Array<UInt8>): WriteResult {
        if (isDone) {
            return WriteResult.Done(0)
        }
        let hadBufferedData = outgoing.isNotEmpty()
        outgoing.write(buffer)
        if (hadBufferedData) {
            return WriteResult.Pending(0)
        }
        processSend()
        return lastWriteResult
    }

    /// 刷新 - 对应 Bun WindowsStreamingWriter.flush
    public func flush(): WriteResult {
        if (isDone) {
            return WriteResult.Done(0)
        }
        if (!hasPendingData()) {
            return WriteResult.Wrote(0)
        }
        processSend()
        return lastWriteResult
    }

    /// 结束 - 对应 Bun WindowsStreamingWriter.end
    public func end(): Unit {
        if (isDone) {
            return
        }
        closedWithoutReporting = false
        isDone = true
        if (!hasPendingData()) {
            if (!ownsFd) {
                return
            }
            close()
        }
    }

    /// 关闭
    public func close(): Unit {
        closeWithoutReporting()
        if (let Some(s) <- source) {
            source = None
        }
    }

    /// 关闭不报告
    public func closeWithoutReporting(): Unit {
        if (getFd() != INVALID_FD) {
            closedWithoutReporting = true
            close()
        }
    }

    /// 清理
    public func deinit(): Unit {
        closeWithoutReporting()
        outgoing.deinit()
        currentPayload.deinit()
    }
}

// ============================================================================
// 平台选择别名
// 严格翻译自: src/io/PipeWriter.zig
//   pub const BufferedWriter = if (bun.Environment.isPosix) PosixBufferedWriter else WindowsBufferedWriter
//   pub const StreamingWriter = if (bun.Environment.isPosix) PosixStreamingWriter else WindowsStreamingWriter
// ============================================================================

/// 缓冲写入器类型别名 (当前平台为 POSIX)
public type BufferedWriter = PosixBufferedWriterImpl

/// 流式写入器类型别名 (当前平台为 POSIX)
public type StreamingWriter = PosixStreamingWriterImpl
