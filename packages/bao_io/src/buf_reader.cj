// bao_io - 增强 BufferedReader
// 严格翻译自: src/io/PipeReader.zig (PosixBufferedReader)
//   Bun 的 BufferedReader 使用动态缓冲区和流式回调
//   增强版支持: readLine 带自定义分隔符, readUntil, readString,
//   readExactly, 多种缓冲区重填策略
//   对应 PosixBufferedReader 的核心读取模式:
//     onReadChunk -> onReaderDone -> onReaderError
package bao_io

import bao_core.*
import bao_sys.*

// ============================================================================
// RefillStrategy - 缓冲区重填策略
// 严格翻译自: Bun BufferedReader 的数据拉取模式
//   Bun 根据文件类型 (file/pipe/socket) 选择不同读取策略
// ============================================================================

/// 缓冲区重填策略 - 对应 Bun BufferedReader 的读取模式
public enum RefillStrategy {
    | Greedy        // 贪婪: 尽可能填满缓冲区
    | OnDemand      // 按需: 缓冲区为空时才填充
    | Fixed         // 固定: 每次读取固定大小
    | Adaptive      // 自适应: 根据历史读取量调整

    public func description(): String {
        match (this) {
            case Greedy => "greedy"
            case OnDemand => "on-demand"
            case Fixed => "fixed"
            case Adaptive => "adaptive"
        }
    }
}

// ============================================================================
// ReadChunkResult - 读取块结果
// 严格翻译自: Bun BufferedReaderVTable.onReadChunk
//   Bun: onReadChunk(chunk: []const u8, hasMore: ReadState) bool
//   返回 false 阻止进一步读取
// ============================================================================

/// 读取块结果 - 对应 Bun onReadChunk 回调结果
public class ReadChunkResult {
    /// 读取的数据
    public var data: Array<UInt8>
    /// 读取状态
    public var state: ReadState
    /// 是否继续读取
    public var wantMore: Bool

    public init(data: Array<UInt8>, state: ReadState, wantMore: Bool) {
        this.data = data
        this.state = state
        this.wantMore = wantMore
    }

    public static func more(data: Array<UInt8>): ReadChunkResult {
        return ReadChunkResult(data, ReadState.ReadyForData, true)
    }

    public static func done(data: Array<UInt8>): ReadChunkResult {
        return ReadChunkResult(data, ReadState.Eof, false)
    }

    public static func error(e: SysError): ReadChunkResult {
        return ReadChunkResult([], ReadState.Error, false)
    }
}

// ============================================================================
// BufferedReaderFlags - 读取器标志
// 严格翻译自: src/io/PipeReader.zig PosixBufferedReader.Flags
//   Bun: const Flags = packed struct(u16) {
//       is_done: bool, pollable: bool, nonblocking: bool, socket: bool,
//       received_eof: bool, closed_without_reporting: bool,
//       close_handle: bool, memfd: bool, use_pread: bool, is_paused: bool
//   }
// ============================================================================

/// 读取器标志 - 对应 Bun PosixBufferedReader.Flags
public class BufferedReaderFlags {
    /// 是否完成 - 对应 Bun is_done
    public var isDone: Bool
    /// 是否可轮询 - 对应 Bun pollable
    public var pollable: Bool
    /// 是否非阻塞 - 对应 Bun nonblocking
    public var nonblocking: Bool
    /// 是否套接字 - 对应 Bun socket
    public var isSocket: Bool
    /// 是否收到 EOF - 对应 Bun received_eof
    public var receivedEof: Bool
    /// 是否关闭但未报告 - 对应 Bun closed_without_reporting
    public var closedWithoutReporting: Bool
    /// 是否关闭句柄 - 对应 Bun close_handle
    public var closeHandle: Bool
    /// 是否使用 pread - 对应 Bun use_pread
    public var usePread: Bool
    /// 是否暂停 - 对应 Bun is_paused
    public var isPaused: Bool

    public init() {
        isDone = false
        pollable = false
        nonblocking = false
        isSocket = false
        receivedEof = false
        closedWithoutReporting = false
        closeHandle = true
        usePread = false
        isPaused = false
    }
}

// ============================================================================
// EnhancedBufferedReader - 增强缓冲读取器
// 严格翻译自: src/io/PipeReader.zig PosixBufferedReader
//   Bun: const PosixBufferedReader = struct {
//       handle: PollOrFd, _buffer: ArrayList(u8), _offset: usize,
//       vtable: BufferedReaderVTable, flags: Flags, count: usize, maxbuf: ?*MaxBuf
//   }
// ============================================================================

/// 增强缓冲读取器 - 对应 Bun PosixBufferedReader
/// 支持逐行读取、精确读取、自定义分隔符、多种重填策略
public class EnhancedBufferedReader {
    /// 内部缓冲区 - 对应 Bun _buffer: ArrayList(u8)
    private var buffer: ArrayList<UInt8>
    /// 当前读取偏移 - 对应 Bun _offset: usize
    private var offset: Int64
    /// 缓冲区容量
    private var capacity: Int64
    /// 底层文件描述符
    private var fd: Int64
    /// 读取状态 - 对应 Bun ReadState
    private var state: ReadState
    /// 读取器标志 - 对应 Bun Flags
    public var flags: BufferedReaderFlags
    /// 重填策略
    public var refillStrategy: RefillStrategy
    /// 总读取字节数 - 对应 Bun count: usize
    public var totalRead: Int64
    /// 最大缓冲区限制 - 对应 Bun maxbuf: ?*MaxBuf
    public var maxBufSize: Int64
    /// 块读取回调 - 对应 Bun onReadChunk
    public var onReadChunk: ?(Array<UInt8>, ReadState) -> Bool
    /// 完成回调 - 对应 Bun onReaderDone
    public var onDone: ?() -> Unit
    /// 错误回调 - 对应 Bun onReaderError
    public var onError: ?(SysError) -> Unit
    /// 自适应读取大小 (用于 Adaptive 策略)
    private var adaptiveSize: Int64
    /// 读取次数 (用于自适应)
    private var readCount: Int64

    public init(fd: Int64, capacity: Int64) {
        this.fd = fd
        this.capacity = capacity
        this.buffer = ArrayList<UInt8>()
        this.offset = 0
        this.state = ReadState.ReadyForData
        this.flags = BufferedReaderFlags()
        this.refillStrategy = RefillStrategy.OnDemand
        this.totalRead = 0
        this.maxBufSize = Int64.MAX_VALUE / 2
        this.onReadChunk = None
        this.onDone = None
        this.onError = None
        this.adaptiveSize = MIN_READ_SIZE
        this.readCount = 0
    }

    public init(fd: Int64) {
        this.fd = fd
        this.capacity = PIPE_BUF_SIZE
        this.buffer = ArrayList<UInt8>()
        this.offset = 0
        this.state = ReadState.ReadyForData
        this.flags = BufferedReaderFlags()
        this.refillStrategy = RefillStrategy.OnDemand
        this.totalRead = 0
        this.maxBufSize = Int64.MAX_VALUE / 2
        this.onReadChunk = None
        this.onDone = None
        this.onError = None
        this.adaptiveSize = MIN_READ_SIZE
        this.readCount = 0
    }

    // ===== 核心读取方法 =====

    /// 填充缓冲区 - 从文件描述符读取
    /// 对应 Bun: PosixBufferedReader.read()
    /// 根据重填策略决定读取量
    public func fill(): SysMaybe<Int64> {
        if (!state.isReadable()) {
            return SysMaybe<Int64>.Ok(0)
        }
        if (flags.isDone || flags.isPaused) {
            return SysMaybe<Int64>.Ok(0)
        }

        // 先压缩缓冲区
        compact()
        let toRead = computeReadSize()
        if (toRead <= 0) {
            return SysMaybe<Int64>.Ok(0)
        }

        let chunk = Array<UInt8>(toRead, item: UInt8(0))
        match (SysFs.read(fd, chunk)) {
            case SysMaybe<Int64>.Err(err) =>
                state = ReadState.Error
                match (onError) {
                    case Some(cb) => cb(err)
                    case None => ()
                }
                return SysMaybe<Int64>.Err(err)
            case SysMaybe<Int64>.Ok(bytesRead) =>
                if (bytesRead == 0) {
                    state = ReadState.Eof
                    flags.receivedEof = true
                    match (onDone) {
                        case Some(cb) => cb()
                        case None => ()
                    }
                    return SysMaybe<Int64>.Ok(0)
                }
                // 追加到缓冲区
                for (i in 0..bytesRead) {
                    buffer.append(chunk[i])
                }
                totalRead += bytesRead
                readCount += 1

                // 更新自适应大小
                if (refillStrategy == RefillStrategy.Adaptive) {
                    updateAdaptiveSize(bytesRead)
                }

                // 调用流式回调 - 对应 Bun onReadChunk
                match (onReadChunk) {
                    case Some(cb) =>
                        let data = Array<UInt8>()
                        for (i in 0..bytesRead) {
                            data.append(chunk[i])
                        }
                        let wantMore = cb(data, state)
                        if (!wantMore) {
                            flags.isPaused = true
                        }
                    case None => ()
                }

                return SysMaybe<Int64>.Ok(bytesRead)
        }
    }

    /// 读取一行 (默认 \n 分隔符)
    /// 对应 Bun: PipeReader 中的行读取
    public func readLine(): ?String {
        return readUntil(UInt8('\n'))
    }

    /// 读取直到遇到指定分隔符
    /// 对应 Bun: BufferedReader 中的 delimiter 扫描
    /// 支持自定义分隔符 (如 \r\n, \0, 自定义协议分隔符)
    public func readUntil(delim: UInt8): ?String {
        // 确保缓冲区有数据
        if (available() == 0) {
            let result = fill()
            match (result) {
                case Err(_) => return None
                case Ok(n) =>
                    if (n == 0) {
                        return None
                    }
            }
        }

        // 扫描分隔符
        var sb = StringBuilder()
        var found = false
        while (offset < buffer.size) {
            let b = buffer[Int64(offset)]
            offset += 1
            if (b == delim) {
                found = true
                break
            }
            // 处理 \r\n: 如果 \r 后面跟着 \n, 跳过 \r
            if (b == UInt8('\r')) {
                if (offset < buffer.size && buffer[Int64(offset)] == UInt8('\n')) {
                    offset += 1
                    found = true
                    break
                }
            }
            sb.append(Char(Int32(b)))
        }

        if (!found && available() == 0 && state == ReadState.Eof) {
            // EOF 但没找到分隔符: 返回剩余数据
            if (sb.toString().size > 0) {
                return Some(sb.toString())
            }
            return None
        }

        // 如果没找到分隔符且还有数据, 递归继续读
        if (!found && state.isReadable()) {
            let more = fill()
            match (more) {
                case Ok(n) =>
                    if (n > 0) {
                        // 继续扫描
                        while (offset < buffer.size) {
                            let b = buffer[Int64(offset)]
                            offset += 1
                            if (b == delim) {
                                found = true
                                break
                            }
                            sb.append(Char(Int32(b)))
                        }
                    }
                case Err(_) => ()
            }
        }

        if (sb.toString().size == 0 && !found) {
            return None
        }
        return Some(sb.toString())
    }

    /// 读取多字节分隔符
    /// 支持如 "\r\n" (CRLF), "\n\n" (双换行) 等分隔符
    public func readUntilDelimiter(delim: Array<UInt8>): ?String {
        if (delim.size == 0) {
            return None
        }
        if (delim.size == 1) {
            return readUntil(delim[0])
        }

        var sb = StringBuilder()
        var matchPos: Int64 = 0

        while (true) {
            if (available() == 0) {
                let result = fill()
                match (result) {
                    case Err(_) => return None
                    case Ok(n) =>
                        if (n == 0) {
                            if (sb.toString().size > 0) {
                                return Some(sb.toString())
                            }
                            return None
                        }
                }
            }

            while (offset < buffer.size) {
                let b = buffer[Int64(offset)]
                offset += 1

                if (b == delim[Int64(matchPos)]) {
                    matchPos += 1
                    if (matchPos == delim.size) {
                        return Some(sb.toString())
                    }
                } else {
                    // 不匹配: 将之前部分匹配的字符也加入结果
                    if (matchPos > 0) {
                        for (i in 0..matchPos) {
                            sb.append(Char(Int32(delim[i])))
                        }
                        matchPos = 0
                    }
                    sb.append(Char(Int32(b)))
                }
            }
        }
    }

    /// 读取精确字节数
    /// 对应 Bun: readExactly(n) - 必须读取恰好 n 个字节
    /// 如果 EOF 前读取不足, 返回已读取的部分
    public func readExactly(count: Int64): ?Array<UInt8> {
        var result = Array<UInt8>()
        var remaining = count

        while (remaining > 0) {
            if (available() == 0) {
                let fillResult = fill()
                match (fillResult) {
                    case Err(_) =>
                        if (result.size > 0) {
                            return Some(result)
                        }
                        return None
                    case Ok(n) =>
                        if (n == 0) {
                            // EOF
                            if (result.size > 0) {
                                return Some(result)
                            }
                            return None
                        }
                }
            }

            let toRead = if (remaining < available()) { remaining } else { available() }
            for (i in 0..toRead) {
                result.append(buffer[Int64(offset)])
                offset += 1
            }
            remaining -= toRead
        }
        return Some(result)
    }

    /// 读取为字符串
    /// 从缓冲区读取指定数量的字节并转为字符串
    public func readString(count: Int64): ?String {
        match (readExactly(count)) {
            case Some(bytes) =>
                var sb = StringBuilder()
                for (b in bytes) {
                    sb.append(Char(Int32(b)))
                }
                return Some(sb.toString())
            case None => None
        }
    }

    /// 读取全部剩余数据
    /// 对应 Bun: PipeReader.readToEnd()
    public func readAll(): SysMaybe<Array<UInt8>> {
        var result = ArrayList<UInt8>()

        // 先读缓冲区中已有的
        while (offset < buffer.size) {
            result.append(buffer[Int64(offset)])
            offset += 1
        }

        // 继续从 FD 读取
        while (state.isReadable()) {
            let fillResult = fill()
            match (fillResult) {
                case Err(e) =>
                    if (result.size > 0) {
                        return SysMaybe<Array<UInt8>>.Ok(result.toArray())
                    }
                    return SysMaybe<Array<UInt8>>.Err(e)
                case Ok(n) =>
                    if (n == 0) {
                        break
                    }
                    while (offset < buffer.size) {
                        result.append(buffer[Int64(offset)])
                        offset += 1
                    }
            }
        }
        return SysMaybe<Array<UInt8>>.Ok(result.toArray())
    }

    /// 读取单个字节
    public func readByte(): ?UInt8 {
        if (available() == 0) {
            let result = fill()
            match (result) {
                case Err(_) => return None
                case Ok(n) =>
                    if (n == 0) { return None }
            }
        }
        if (offset < buffer.size) {
            let b = buffer[Int64(offset)]
            offset += 1
            return Some(b)
        }
        return None
    }

    /// 预览下一个字节 (不移动偏移)
    public func peek(): ?UInt8 {
        if (available() == 0) {
            let result = fill()
            match (result) {
                case Err(_) => return None
                case Ok(n) =>
                    if (n == 0) { return None }
            }
        }
        if (offset < buffer.size) {
            return Some(buffer[Int64(offset)])
        }
        return None
    }

    /// 预览多个字节
    public func peek(count: Int64): ?Array<UInt8> {
        var result = Array<UInt8>()
        for (i in 0..count) {
            let idx = offset + i
            if (idx < buffer.size) {
                result.append(buffer[Int64(idx)])
            } else {
                return None
            }
        }
        return Some(result)
    }

    /// 跳过指定字节数
    public func skip(count: Int64): Int64 {
        var skipped: Int64 = 0
        while (skipped < count) {
            if (available() == 0) {
                let result = fill()
                match (result) {
                    case Err(_) => return skipped
                    case Ok(n) =>
                        if (n == 0) { return skipped }
                }
            }
            let toSkip = if (count - skipped < available()) { count - skipped } else { available() }
            offset += toSkip
            skipped += toSkip
        }
        return skipped
    }

    // ===== 状态查询 =====

    /// 可用字节数
    public func available(): Int64 {
        return buffer.size - offset
    }

    /// 是否到达 EOF
    /// 对应 Bun: PosixBufferedReader.isDone()
    public func isEof(): Bool {
        return (state == ReadState.Eof || flags.isDone || flags.receivedEof) && available() == 0
    }

    /// 是否完成 - 对应 Bun isDone()
    public func isDone(): Bool {
        return flags.isDone || flags.receivedEof || flags.closedWithoutReporting
    }

    /// 是否有错误
    public func hasError(): Bool {
        return state == ReadState.Error
    }

    /// 内存开销 - 对应 Bun memoryCost()
    public func memoryCost(): Int64 {
        return capacity + 64  // 结构体 + 缓冲区
    }

    // ===== 控制方法 =====

    /// 暂停读取 - 对应 Bun is_paused
    public func pause(): Unit {
        flags.isPaused = true
    }

    /// 恢复读取
    public func resume(): Unit {
        flags.isPaused = false
    }

    /// 关闭读取器
    public func close(): Unit {
        if (fd >= 0) {
            SysFs.close(fd)
            fd = INVALID_FD
        }
        flags.isDone = true
        buffer.clear()
    }

    /// 压缩缓冲区 (移动未读数据到开头)
    /// 对应 Bun _buffer 中 offset 前的数据丢弃
    private func compact(): Unit {
        if (offset <= 0) {
            return
        }
        var newBuffer = ArrayList<UInt8>()
        while (offset < buffer.size) {
            newBuffer.append(buffer[Int64(offset)])
            offset += 1
        }
        buffer = newBuffer
        offset = 0
    }

    /// 计算本次读取大小
    private func computeReadSize(): Int64 {
        let availableSpace = capacity - (buffer.size - offset)
        match (refillStrategy) {
            case RefillStrategy.Greedy =>
                return if (availableSpace < MIN_READ_SIZE) { MIN_READ_SIZE } else { availableSpace }
            case RefillStrategy.OnDemand =>
                return if (availableSpace < MIN_READ_SIZE) { capacity } else { availableSpace }
            case RefillStrategy.Fixed =>
                return MIN_READ_SIZE
            case RefillStrategy.Adaptive =>
                return adaptiveSize
        }
    }

    /// 更新自适应读取大小
    private func updateAdaptiveSize(lastRead: Int64): Unit {
        // 简单的指数移动平均
        adaptiveSize = (adaptiveSize * 3 + lastRead) / 4
        if (adaptiveSize < MIN_READ_SIZE) {
            adaptiveSize = MIN_READ_SIZE
        }
        if (adaptiveSize > MAX_BUF_SIZE) {
            adaptiveSize = MAX_BUF_SIZE
        }
    }
}
