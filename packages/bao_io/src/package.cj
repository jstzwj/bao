// bao_io - IO 操作
// 严格翻译自:
//   src/io/io.zig - Loop, Poll, Source, Request, Action
//   src/io/MaxBuf.zig - 最大缓冲区
//   src/io/source.zig - IO Source
//   src/io/PipeReader.zig - BufferedReader
//   src/io/PipeWriter.zig - BufferedWriter
//   src/io/pipes.zig - ReadState, FileType
package bao_io

import bao_core.*
import bao_sys.*

// ============================================================================
// MaxBuf - 最大缓冲区大小
// 严格翻译自: src/io/MaxBuf.zig
// Bun 限制单次 IO 操作的最大缓冲区大小
// ============================================================================

/// 最大缓冲区大小
/// 对应 Bun MaxBuf 常量
public let MAX_BUF_SIZE: Int64 = 65536  // 64KB - Bun 默认缓冲区大小

/// 管道缓冲区大小
public let PIPE_BUF_SIZE: Int64 = 65536

/// 最小读取大小
public let MIN_READ_SIZE: Int64 = 4096

// ============================================================================
// ReadState - 读取状态机
// 严格翻译自: src/io/pipes.zig
//   pub const ReadState = enum {
//       ready_for_data,
//       eof,
//       error,
//   }
// ============================================================================

/// 读取状态 - 对应 Bun ReadState
public enum ReadState {
    | ReadyForData  // 准备接收数据
    | Eof           // 已到达末尾
    | Error         // 发生错误

    /// 是否可以继续读取
    public func isReadable(): Bool {
        match (this) {
            case ReadyForData => true
            case Eof => false
            case Error => false
        }
    }
}

// ============================================================================
// FileType - 文件类型
// 严格翻译自: src/io/pipes.zig
//   pub const FileType = enum { ... }
// ============================================================================

/// 文件类型 - 对应 Bun FileType
public enum FileType {
    | File           // 普通文件
    | Dir            // 目录
    | Symlink        // 符号链接
    | Fifo           // 管道
    | Socket         // 套接字
    | CharacterDev   // 字符设备
    | BlockDev       // 块设备
    | Unknown        // 未知
}

// ============================================================================
// WriteStatus - 写入结果
// 严格翻译自: src/io/PipeWriter.zig
//   pub const WriteStatus = union(enum) { ... }
// ============================================================================

/// 写入状态 - 对应 Bun WriteStatus
public enum WriteStatus {
    | Done                // 写入完成
    | Partial(Int64)      // 部分写入, 剩余字节数
    | Error(SysError)     // 写入错误

    public func isDone(): Bool {
        match (this) {
            case Done => true
            case _ => false
        }
    }
}

// ============================================================================
// WriteResult - 写入结果
// 严格翻译自: src/io/PipeWriter.zig
//   pub const WriteResult = struct { ... }
// ============================================================================

/// 写入结果 - 对应 Bun WriteResult
public class WriteResult {
    /// 写入的字节数
    public var bytesWritten: Int64
    /// 错误 (如果有)
    public var err: ?SysError

    public init() {
        bytesWritten = 0
        err = None
    }

    public init(bytesWritten: Int64) {
        this.bytesWritten = bytesWritten
        this.err = None
    }

    public init(err: SysError) {
        this.bytesWritten = 0
        this.err = Some(err)
    }

    public func isOk(): Bool {
        return err == None
    }
}

// ============================================================================
// IoEvent - IO 事件类型
// 对应 Bun Poll Flags
// ============================================================================

/// IO 事件类型 - 对应 Bun Poll.Flags
public enum IoEvent {
    | Readable     // EPOLL.IN / EVFILT.READ
    | Writable     // EPOLL.OUT / EVFILT.WRITE
    | Eof          // EPOLL.HUP
    | Error        // EPOLL.ERR
    | Process      // EVFILT.PROC (kqueue)
}

// ============================================================================
// IoSource - IO 源
// 严格翻译自: src/io/source.zig
//   pub const Source = struct { ... }
// ============================================================================

/// IO 源抽象 - 对应 Bun Source
/// 表示一个可轮询的 IO 源 (文件描述符)
public class IoSource {
    /// 文件描述符
    public var fd: Int64
    /// 关联的标签
    public var tag: IoSourceTag
    /// 是否活跃
    public var active: Bool

    public init(fd: Int64) {
        this.fd = fd
        this.tag = IoSourceTag.Empty
        this.active = true
    }

    public init(fd: Int64, tag: IoSourceTag) {
        this.fd = fd
        this.tag = tag
        this.active = true
    }

    /// 关闭源
    public func close(): Unit {
        active = false
        SysFs.close(fd)
    }
}

/// IO 源标签 - 对应 Bun Pollable.Tag
public enum IoSourceTag {
    | Empty
    | ReadFile
    | WriteFile
}

// ============================================================================
// BaoFile - 文件操作封装
// 严格翻译自: src/sys/File.zig
//   pub const File = struct {
//       handle: bun.FD,
//       pub fn open(path, flags, mode) Maybe(File) { ... }
//       pub fn readAll(...) Maybe([]const u8) { ... }
//       pub fn writeAll(...) Maybe(void) { ... }
//   }
// ============================================================================

/// 文件打开模式 - 对应 POSIX open flags 组合
public enum OpenMode {
    | Read           // O_RDONLY
    | Write          // O_WRONLY | O_CREAT | O_TRUNC
    | ReadWrite      // O_RDWR
    | Append         // O_WRONLY | O_CREAT | O_APPEND
    | ReadAppend     // O_RDWR | O_CREAT | O_APPEND

    /// 转为 POSIX flags
    public func toFlags(): Int64 {
        match (this) {
            case Read => OpenFlags.RDONLY
            case Write => OpenFlags.WRONLY | OpenFlags.CREAT | OpenFlags.TRUNC
            case ReadWrite => OpenFlags.RDWR
            case Append => OpenFlags.WRONLY | OpenFlags.CREAT | OpenFlags.APPEND
            case ReadAppend => OpenFlags.RDWR | OpenFlags.CREAT | OpenFlags.APPEND
        }
    }
}

/// 文件类 - 严格对应 Bun sys.File
/// Bun: pub const File = struct { handle: bun.FD }
public class BaoFile {
    /// 文件描述符 - 对应 Bun File.handle: bun.FD
    public var fd: Int64
    /// 文件路径
    public var path: String
    /// 是否已打开
    public var isOpen: Bool

    public init(fd: Int64, path: String) {
        this.fd = fd
        this.path = path
        this.isOpen = true
    }

    /// 打开文件
    /// 对应 Bun: File.openat(AT_FDCWD, path, flags, mode) -> Maybe(File)
    public static func open(path: String, mode: OpenMode): SysMaybe<BaoFile> {
        let flags = mode.toFlags()
        match (SysFs.open(path, flags)) {
            case SysMaybe<Int64>.Ok(fd) =>
                return SysMaybe<BaoFile>.Ok(BaoFile(fd, path))
            case SysMaybe<Int64>.Err(err) =>
                return SysMaybe<BaoFile>.Err(err)
        }
    }

    /// 读取整个文件到字节数组
    /// 对应 Bun: File.readToEnd() 模式
    /// Bun 使用 read 循环读取直到 EOF
    public static func readAllBytes(path: String): SysMaybe<Array<UInt8>> {
        // 先获取文件大小
        match (SysFs.getFileSize(path)) {
            case SysMaybe<UInt64>.Err(err) =>
                return SysMaybe<Array<UInt8>>.Err(err)
            case SysMaybe<UInt64>.Ok(size) =>
                let fileSize = Int64(size)
                // 打开文件
                match (SysFs.openRead(path)) {
                    case SysMaybe<Int64>.Err(err) =>
                        return SysMaybe<Array<UInt8>>.Err(err)
                    case SysMaybe<Int64>.Ok(fd) =>
                        var result = Array<UInt8>(fileSize, item: UInt8(0))
                        var offset: Int64 = 0
                        while (offset < fileSize) {
                            let toRead = if (fileSize - offset > MAX_BUF_SIZE) {
                                MAX_BUF_SIZE
                            } else {
                                fileSize - offset
                            }
                            let chunk = Array<UInt8>(toRead, item: UInt8(0))
                            match (SysFs.read(fd, chunk)) {
                                case SysMaybe<Int64>.Err(err) =>
                                    SysFs.close(fd)
                                    return SysMaybe<Array<UInt8>>.Err(err)
                                case SysMaybe<Int64>.Ok(bytesRead) =>
                                    for (i in 0..bytesRead) {
                                        result[offset + i] = chunk[i]
                                    }
                                    offset += bytesRead
                                    if (bytesRead == 0) {
                                        break  // EOF
                                    }
                            }
                        }
                        SysFs.close(fd)
                        return SysMaybe<Array<UInt8>>.Ok(result)
                }
        }
    }

    /// 读取整个文件到字符串
    /// 对应 Bun: Bun.file(path).text() / readFileSync(path, "utf8")
    public static func readAllText(path: String): SysMaybe<String> {
        match (readAllBytes(path)) {
            case SysMaybe<Array<UInt8>>.Ok(bytes) =>
                var sb = StringBuilder()
                for (b in bytes) {
                    sb.append(Char(Int32(b)))
                }
                return SysMaybe<String>.Ok(sb.toString())
            case SysMaybe<Array<UInt8>>.Err(err) =>
                return SysMaybe<String>.Err(err)
        }
    }

    /// 写入字节数组到文件
    /// 对应 Bun: File.writeAll(data) 模式
    public static func writeAllBytes(path: String, data: Array<UInt8>): SysMaybe<Unit> {
        match (SysFs.openWrite(path)) {
            case SysMaybe<Int64>.Err(err) =>
                return SysMaybe<Unit>.Err(err)
            case SysMaybe<Int64>.Ok(fd) =>
                var offset: Int64 = 0
                while (offset < data.size) {
                    let toWrite = if (data.size - offset > MAX_BUF_SIZE) {
                        MAX_BUF_SIZE
                    } else {
                        data.size - offset
                    }
                    var chunk = Array<UInt8>(toWrite, item: UInt8(0))
                    for (i in 0..toWrite) {
                        chunk[i] = data[offset + i]
                    }
                    match (SysFs.write(fd, chunk)) {
                        case SysMaybe<Int64>.Err(err) =>
                            SysFs.close(fd)
                            return SysMaybe<Unit>.Err(err)
                        case SysMaybe<Int64>.Ok(written) =>
                            offset += written
                    }
                }
                SysFs.close(fd)
                return SysMaybe<Unit>.Ok(())
        }
    }

    /// 写入字符串到文件
    public static func writeAllText(path: String, text: String): SysMaybe<Unit> {
        var bytes = Array<UInt8>()
        for (c in text) {
            bytes.append(UInt8(c.value))
        }
        return writeAllBytes(path, bytes)
    }

    /// 关闭文件
    /// 对应 Bun: FD.close()
    public func close(): Unit {
        if (isOpen) {
            SysFs.close(fd)
            isOpen = false
        }
    }

    /// 获取文件路径
    public func getPath(): String {
        return path
    }

    /// 获取文件描述符
    public func getFd(): Int64 {
        return fd
    }
}

// ============================================================================
// BufferedReader - 缓冲读取器
// 严格翻译自: src/io/PipeReader.zig BufferedReader
// Bun 的 BufferedReader 从管道/文件描述符读取并缓冲数据
// ============================================================================

/// 缓冲读取器 - 对应 Bun BufferedReader
/// Bun: BufferedReader 用于逐行或按块读取 IO 流
public class BufferedReader {
    /// 内部缓冲区
    private var buffer: Array<UInt8>
    /// 当前读取位置
    private var pos: Int64
    /// 缓冲区有效数据末尾
    private var limit: Int64
    /// 缓冲区容量
    private var capacity: Int64
    /// 底层文件描述符
    private var fd: Int64
    /// 读取状态 - 对应 Bun ReadState
    private var state: ReadState

    public init(fd: Int64, capacity: Int64) {
        this.fd = fd
        this.capacity = capacity
        this.buffer = Array<UInt8>(capacity, item: UInt8(0))
        this.pos = 0
        this.limit = 0
        this.state = ReadState.ReadyForData
    }

    public init(capacity: Int64) {
        this.fd = INVALID_FD
        this.capacity = capacity
        this.buffer = Array<UInt8>(capacity, item: UInt8(0))
        this.pos = 0
        this.limit = 0
        this.state = ReadState.ReadyForData
    }

    /// 填充缓冲区 - 从文件描述符读取
    /// 对应 Bun: PipeReader 中的 read 调用
    public func fillFromFd(): SysMaybe<Int64> {
        if (state != ReadState.ReadyForData) {
            return SysMaybe<Int64>.Ok(0)
        }

        // 如果缓冲区已满，先压缩
        if (pos > 0 && limit == capacity) {
            compact()
        }

        let toRead = capacity - limit
        if (toRead <= 0) {
            return SysMaybe<Int64>.Ok(0)
        }

        let chunk = Array<UInt8>(toRead, item: UInt8(0))
        match (SysFs.read(fd, chunk)) {
            case SysMaybe<Int64>.Err(err) =>
                state = ReadState.Error
                return SysMaybe<Int64>.Err(err)
            case SysMaybe<Int64>.Ok(bytesRead) =>
                if (bytesRead == 0) {
                    state = ReadState.Eof
                    return SysMaybe<Int64>.Ok(0)
                }
                for (i in 0..bytesRead) {
                    buffer[limit + i] = chunk[i]
                }
                limit += bytesRead
                return SysMaybe<Int64>.Ok(bytesRead)
        }
    }

    /// 手动填充数据
    public func fill(data: Array<UInt8>): Int64 {
        let toRead = if (data.size < (capacity - limit)) {
            data.size
        } else {
            capacity - limit
        }
        for (i in 0..toRead) {
            buffer[limit + i] = data[i]
        }
        limit += toRead
        return toRead
    }

    /// 读取一行
    /// 对应 Bun: PipeReader 中的行读取逻辑
    public func readLine(): ?String {
        if (pos >= limit) {
            return None
        }
        var sb = StringBuilder()
        while (pos < limit) {
            let b = buffer[pos]
            pos += 1
            if (b == UInt8('\n')) {
                break
            }
            if (b == UInt8('\r')) {
                // 处理 \r\n - 对应 Bun 的换行处理
                if (pos < limit && buffer[pos] == UInt8('\n')) {
                    pos += 1
                }
                break
            }
            sb.append(Char(Int32(b)))
        }
        return Some(sb.toString())
    }

    /// 读取指定大小的数据
    public func readBytes(count: Int64): ?Array<UInt8> {
        let available = limit - pos
        if (available <= 0) {
            return None
        }
        let toRead = if (count < available) { count } else { available }
        var result = Array<UInt8>()
        for (i in 0..toRead) {
            result.append(buffer[pos + i])
        }
        pos += toRead
        return Some(result)
    }

    /// 可用字节数
    public func available(): Int64 {
        return limit - pos
    }

    /// 是否到达 EOF
    public func isEof(): Bool {
        return state == ReadState.Eof && pos >= limit
    }

    /// 压缩缓冲区 (移动未读数据到开头)
    private func compact(): Unit {
        if (pos <= 0) {
            return
        }
        let remaining = limit - pos
        for (i in 0..remaining) {
            buffer[i] = buffer[pos + i]
        }
        pos = 0
        limit = remaining
    }
}

// ============================================================================
// BufferedWriter - 缓冲写入器
// 严格翻译自: src/io/PipeWriter.zig BufferedWriter
// Bun 的 BufferedWriter 缓冲写入并定期 flush
// ============================================================================

/// 缓冲写入器 - 对应 Bun BufferedWriter
/// Bun: BufferedWriter 用于高效写入 IO 流
public class BufferedWriter {
    /// 内部缓冲区
    private var buffer: ArrayBuffer
    /// 底层文件描述符
    private var fd: Int64

    public init(fd: Int64) {
        this.buffer = ArrayBuffer()
        this.fd = fd
    }

    public init(fd: Int64, capacity: Int64) {
        this.buffer = ArrayBuffer(capacity)
        this.fd = fd
    }

    /// 写入单个字节
    public func write(b: UInt8): Unit {
        buffer.append(b)
        if (buffer.len() >= PIPE_BUF_SIZE) {
            flush()
        }
    }

    /// 写入字节数组
    /// 对应 Bun: PipeWriter.write(data)
    public func writeBytes(data: Array<UInt8>): Unit {
        buffer.appendBytes(data)
        if (buffer.len() >= PIPE_BUF_SIZE) {
            flush()
        }
    }

    /// 写入字符串
    public func writeString(s: String): Unit {
        buffer.appendString(s)
        if (buffer.len() >= PIPE_BUF_SIZE) {
            flush()
        }
    }

    /// 刷新缓冲区到文件描述符
    /// 对应 Bun: PipeWriter.flush()
    public func flush(): Unit {
        if (buffer.len() == 0) {
            return
        }
        let data = buffer.slice()
        match (SysFs.write(fd, data)) {
            case SysMaybe<Int64>.Err(_) =>
                // 写入失败 - 对应 Bun 中 PipeWriter 的错误处理
                buffer.clear()
            case SysMaybe<Int64>.Ok(_) =>
                buffer.clear()
        }
    }

    /// 获取缓冲区中未写入的大小
    public func bufferSize(): Int64 {
        return buffer.len()
    }

    /// 关闭写入器
    public func close(): Unit {
        flush()
        SysFs.close(fd)
    }
}

// ============================================================================
// StreamBuffer - 流缓冲区
// 对应 Bun: src/io/PipeWriter.zig StreamBuffer
// ============================================================================

/// 流缓冲区 - 对应 Bun StreamBuffer
/// 用于在写入流时管理缓冲区的分配和释放
public class StreamBuffer {
    private var data: Array<UInt8>
    private var pos: Int64
    private var len: Int64

    public init(capacity: Int64) {
        data = Array<UInt8>(capacity, item: UInt8(0))
        pos = 0
        len = capacity
    }

    /// 获取缓冲区
    public func slice(): Array<UInt8> {
        var result = Array<UInt8>()
        for (i in 0..len) {
            result.append(data[i])
        }
        return result
    }

    /// 获取可写切片
    public func writableSlice(): Array<UInt8> {
        var result = Array<UInt8>()
        for (i in pos..len) {
            result.append(data[i])
        }
        return result
    }

    /// 标记已写入
    public func advance(count: Int64): Unit {
        pos += count
    }

    /// 剩余容量
    public func remaining(): Int64 {
        return len - pos
    }

    /// 已写入大小
    public func written(): Int64 {
        return pos
    }
}

// ============================================================================
// IoLoop - IO 事件循环
// 严格翻译自: src/io/io.zig Loop
//   pub const Loop = struct {
//       pending: Request.Queue,
//       waker: bun.Async.Waker,
//       epoll_fd: bun.FD,
//       active: usize,
//       ...
//   }
// 注意: 这是 Bun 用于 Bun.write() 和 Bun.file() 的辅助 IO 循环
// 不是主事件循环 (主事件循环在 bao_event_loop 中)
// ============================================================================

/// IO 轮询动作 - 对应 Bun io.Action
public enum IoAction {
    | Readable(IoFileAction)
    | Writable(IoFileAction)
    | Close(IoCloseAction)
}

/// 文件动作 - 对应 Bun io.Action.FileAction
public class IoFileAction {
    public var fd: Int64
    public var tag: IoSourceTag
    public var onError: (SysError) -> Unit
    public var onReady: () -> Unit

    public init(fd: Int64, tag: IoSourceTag, onError: (SysError) -> Unit, onReady: () -> Unit) {
        this.fd = fd
        this.tag = tag
        this.onError = onError
        this.onReady = onReady
    }
}

/// 关闭动作 - 对应 Bun io.Action.CloseAction
public class IoCloseAction {
    public var fd: Int64
    public var tag: IoSourceTag
    public var onDone: () -> Unit

    public init(fd: Int64, tag: IoSourceTag, onDone: () -> Unit) {
        this.fd = fd
        this.tag = tag
        this.onDone = onDone
    }
}

/// IO 请求 - 对应 Bun io.Request
/// Bun: pub const Request = struct { next: ?*Request, callback, scheduled: bool }
public class IoRequest {
    public var callback: () -> IoAction
    public var scheduled: Bool

    public init(callback: () -> IoAction) {
        this.callback = callback
        this.scheduled = false
    }
}

/// IO 事件循环 - 对应 Bun io.Loop (辅助循环)
/// 仓颉简化实现: 使用线程轮询
public class IoLoop {
    /// 待处理请求队列
    private var pending: ArrayList<IoRequest>
    /// 活跃请求数
    private var active: Int64
    /// 是否运行中
    private var running: Bool

    public init() {
        pending = ArrayList<IoRequest>()
        active = 0
        running = false
    }

    /// 调度请求 - 对应 Bun Loop.schedule(request)
    public func schedule(request: IoRequest): Unit {
        request.scheduled = true
        pending.append(request)
    }

    /// 处理待处理请求 - 对应 Bun Loop.tick 中的 pending 处理
    public func processPending(): Unit {
        var batch = ArrayList<IoRequest>()
        for (req in pending) {
            batch.append(req)
        }
        pending.clear()

        for (req in batch) {
            req.scheduled = false
            // 简化: 直接调用回调
            // Bun 中回调返回 Action，根据类型注册 epoll/kqueue
            let action = req.callback()
            match (action) {
                case IoAction.Readable(fa) =>
                    active += 1
                case IoAction.Writable(fa) =>
                    active += 1
                case IoAction.Close(ca) =>
                    active -= 1
                    ca.onDone()
            }
        }
    }

    /// 获取活跃数
    public func getActive(): Int64 {
        return active
    }
}
