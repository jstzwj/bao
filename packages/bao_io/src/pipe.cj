// bao_io - 管道 I/O
// 严格翻译自: src/io/PipeReader.zig, src/io/PipeWriter.zig
//   Bun 使用管道进行子进程 I/O 和流处理
//   PipeReader/PipeWriter 封装管道的读写端
package bao_io

import bao_core.*
import bao_sys.*

// ============================================================================
// PipeReader - 管道读取端
// 严格翻译自: src/io/PipeReader.zig
//   pub const PipeReader = struct {
//       fd: bun.FD,
//       buffer: BufferedReader,
//       state: ReadState,
//       ...
//   }
// ============================================================================

/// 管道读取器 - 对应 Bun PipeReader
/// 从管道/套接字读取数据到缓冲区
public class PipeReader {
    /// 文件描述符
    public var fd: Int64
    /// 内部缓冲读取器
    private var reader: BufferedReader
    /// 读取状态
    public var state: ReadState
    /// 缓冲区大小
    public var bufferSize: Int64

    public init(fd: Int64) {
        this.fd = fd
        this.bufferSize = PIPE_BUF_SIZE
        this.reader = BufferedReader(fd, PIPE_BUF_SIZE)
        this.state = ReadState.ReadyForData
    }

    public init(fd: Int64, bufferSize: Int64) {
        this.fd = fd
        this.bufferSize = bufferSize
        this.reader = BufferedReader(fd, bufferSize)
        this.state = ReadState.ReadyForData
    }

    /// 读取数据到缓冲区
    /// 对应 Bun: PipeReader.read()
    public func read(): SysMaybe<Array<UInt8>> {
        if (!state.isReadable()) {
            return SysMaybe<Array<UInt8>>.Ok([])
        }
        let result = reader.fillFromFd()
        match (result) {
            case Err(e) =>
                state = ReadState.Error
                return SysMaybe<Array<UInt8>>.Err(e)
            case Ok(bytesRead) =>
                if (bytesRead == 0 && reader.isEof()) {
                    state = ReadState.Eof
                }
                return SysMaybe<Array<UInt8>>.Ok(reader.readBytes(reader.available()).getOrElse { [] })
        }
    }

    /// 读取一行
    /// 对应 Bun: PipeReader 的行读取
    public func readLine(): ?String {
        if (!state.isReadable()) {
            return None
        }
        // 如果缓冲区为空，先填充
        if (reader.available() == 0) {
            let result = reader.fillFromFd()
            match (result) {
                case Err(_) => state = ReadState.Error; return None
                case Ok(n) =>
                    if (n == 0) {
                        state = ReadState.Eof
                        return None
                    }
            }
        }
        return reader.readLine()
    }

    /// 读取所有剩余数据
    /// 对应 Bun: PipeReader.readToEnd()
    public func readToEnd(): SysMaybe<Array<UInt8>> {
        var result = ArrayList<UInt8>()
        while (state.isReadable()) {
            // 先读缓冲区中已有的
            while (reader.available() > 0) {
                let chunk = reader.readBytes(MAX_BUF_SIZE)
                if (let Some(c) = chunk) {
                    for (b in c) { result.append(b) }
                }
            }
            // 填充更多数据
            let fillResult = reader.fillFromFd()
            match (fillResult) {
                case Err(e) =>
                    state = ReadState.Error
                    if (result.size > 0) {
                        return SysMaybe<Array<UInt8>>.Ok(result.toArray())
                    }
                    return SysMaybe<Array<UInt8>>.Err(e)
                case Ok(n) =>
                    if (n == 0) {
                        state = ReadState.Eof
                    }
            }
        }
        return SysMaybe<Array<UInt8>>.Ok(result.toArray())
    }

    /// 可用数据量
    public func available(): Int64 {
        return reader.available()
    }

    /// 是否到达 EOF
    public func isEof(): Bool {
        return state == ReadState.Eof
    }

    /// 关闭读取端
    /// 对应 Bun: PipeReader.close()
    public func close(): Unit {
        if (fd >= 0) {
            SysFs.close(fd)
            fd = INVALID_FD
        }
    }

    /// 设置非阻塞
    /// 对应 Bun: PipeReader.setNonblocking()
    public func setNonblocking(nonblocking: Bool): Unit {
        // TODO: fcntl F_SETFL O_NONBLOCK
    }
}

// ============================================================================
// PipeWriter - 管道写入端
// 严格翻译自: src/io/PipeWriter.zig
//   pub const PipeWriter = struct {
//       fd: bun.FD,
//       buffer: ?*StreamBuffer,
//       ...
//   }
// ============================================================================

/// 管道写入器 - 对应 Bun PipeWriter
/// 向管道/套接字写入数据
public class PipeWriter {
    /// 文件描述符
    public var fd: Int64
    /// 内部缓冲写入器
    private var writer: BufferedWriter
    /// 是否自动刷新
    public var autoFlush: Bool

    public init(fd: Int64) {
        this.fd = fd
        this.writer = BufferedWriter(fd)
        this.autoFlush = true
    }

    public init(fd: Int64, autoFlush: Bool) {
        this.fd = fd
        this.writer = BufferedWriter(fd)
        this.autoFlush = autoFlush
    }

    /// 写入字节数组
    /// 对应 Bun: PipeWriter.write(data)
    public func write(data: Array<UInt8>): WriteResult {
        writer.writeBytes(data)
        if (autoFlush) {
            writer.flush()
        }
        return WriteResult(data.size)
    }

    /// 写入字符串
    /// 对应 Bun: PipeWriter.write(text)
    public func writeString(text: String): WriteResult {
        writer.writeString(text)
        if (autoFlush) {
            writer.flush()
        }
        return WriteResult(text.size)
    }

    /// 写入行 (自动追加换行)
    /// 对应 Bun: PipeWriter.writeLine()
    public func writeLine(line: String): WriteResult {
        writer.writeString(line)
        writer.write(UInt8('\n'))
        if (autoFlush) {
            writer.flush()
        }
        return WriteResult(line.size + 1)
    }

    /// 刷新缓冲区
    /// 对应 Bun: PipeWriter.flush()
    public func flush(): Unit {
        writer.flush()
    }

    /// 关闭写入端
    /// 对应 Bun: PipeWriter.close()
    public func close(): Unit {
        writer.close()
        fd = INVALID_FD
    }

    /// 关闭写入端 (不刷新)
    /// 对应 Bun: PipeWriter.end()
    public func end(): Unit {
        if (fd >= 0) {
            SysFs.close(fd)
            fd = INVALID_FD
        }
    }
}

// ============================================================================
// Pipe - 管道创建
// 严格翻译自: src/io/pipes.zig
// ============================================================================

/// 管道创建工具 - 对应 Bun 管道创建
public class PipeIo {
    /// 创建管道对
    /// 对应 Bun: sys.pipe(fds) -> (PipeReader, PipeWriter)
    public static func create(): SysMaybe<(PipeReader, PipeWriter)> {
        let pipe = Pipe.create()
        match (pipe) {
            case Err(e) => return SysMaybe<(PipeReader, PipeWriter)>.Err(e)
            case Ok(p) =>
                let reader = PipeReader(p.readFd)
                let writer = PipeWriter(p.writeFd)
                return SysMaybe<(PipeReader, PipeWriter)>.Ok((reader, writer))
        }
    }

    /// 创建子进程管道配置
    /// 对应 Bun: spawn 中的管道创建
    public static func createChildPipes(config: StdioConfig): ?ChildPipe {
        match (config) {
            case StdioConfig.Pipe =>
                let result = create()
                match (result) {
                    case Ok((reader, writer)) =>
                        return Some(ChildPipe(reader, writer))
                    case Err(_) => return None
                }
            case _ => return None
        }
    }
}

/// 子进程管道对
public class ChildPipe {
    public var reader: PipeReader
    public var writer: PipeWriter

    public init(reader: PipeReader, writer: PipeWriter) {
        this.reader = reader
        this.writer = writer
    }

    /// 关闭两端
    public func closeAll(): Unit {
        reader.close()
        writer.close()
    }
}
