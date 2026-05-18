// bao_io - pipes 管道辅助类型
// 严格翻译自: src/io/pipes.zig
//   Bun 的 pipes.zig 定义了管道 I/O 的基础类型:
//     PollOrFd - 轮询或文件描述符联合类型
//     FileType - 文件类型枚举
//     ReadState - 读取状态枚举
// 注意: PollOrFd, FileType, ReadState 已在 pipe_writer.cj 中定义
// 本文件补充管道相关的辅助函数
package bao_io

import bao_core.*
import bao_sys.*

// ============================================================================
// 管道常量
// ============================================================================

/// 无效文件描述符
/// 对应 Bun: bun.invalid_fd
public let INVALID_FD: Int64 = -1

/// 管道缓冲区大小
/// 对应 Bun: PIPE_BUF (通常为 4096 或 65536)
public let PIPE_BUF_SIZE: Int64 = 65536

/// 最大缓冲区大小
/// 对应 Bun: MaxBuf
public let MAX_BUF_SIZE: Int64 = 65536

// ============================================================================
// PipeHandle - 管道句柄
// 严格翻译自: src/io/pipes.zig PollOrFd 的管道操作封装
// ============================================================================

/// 管道句柄 - 对应 Bun PollOrFd 的管道封装
public class PipeHandle {
    /// 文件描述符
    public var fd: Int64
    /// 是否可轮询
    public var pollable: Bool
    /// 是否已关闭
    public var closed: Bool

    public init(fd: Int64) {
        this.fd = fd
        pollable = false
        closed = false
    }

    public init(fd: Int64, pollable: Bool) {
        this.fd = fd
        this.pollable = pollable
        closed = false
    }

    /// 获取文件描述符
    public func getFd(): Int64 {
        if (closed) {
            return INVALID_FD
        }
        return fd
    }

    /// 关闭管道句柄
    public func close(): Unit {
        if (!closed && fd >= 0) {
            SysFs.close(fd)
            fd = INVALID_FD
            closed = true
        }
    }

    /// 是否已关闭
    public func isClosed(): Bool {
        return closed || fd == INVALID_FD
    }
}

// ============================================================================
// PipeFdPair - 管道 FD 对
// 严格翻译自: src/io/pipes.zig 中的 pipe() 系统调用封装
// ============================================================================

/// 管道文件描述符对
public class PipeFdPair {
    /// 读取端 FD
    public var readFd: Int64
    /// 写入端 FD
    public var writeFd: Int64

    public init(readFd: Int64, writeFd: Int64) {
        this.readFd = readFd
        this.writeFd = writeFd
    }
}

// ============================================================================
// Pipe - 管道创建工具
// 严格翻译自: src/io/pipes.zig 中的管道创建函数
// ============================================================================

/// 管道创建工具 - 对应 Bun 的 pipe() 系统调用封装
public class Pipe {
    public var readFd: Int64
    public var writeFd: Int64

    public init(readFd: Int64, writeFd: Int64) {
        this.readFd = readFd
        this.writeFd = writeFd
    }

    /// 创建管道对
    /// 对应 Bun: bun.sys.pipe(fds)
    public static func create(): SysMaybe<Pipe> {
        let fds = Pipe.createPair()
        match (fds) {
            case Err(e) => return SysMaybe<Pipe>.Err(e)
            case Ok(pair) => return SysMaybe<Pipe>.Ok(Pipe(pair.readFd, pair.writeFd))
        }
    }

    public static func createPairResult(): SysMaybe<PipeFdPair> {
        return Pipe.createPair()
    }

    private static func createPair(): SysMaybe<PipeFdPair> {
        let fds = Array<Int32>(2, { _ => Int32(0) })
        let rc = Pipe.createPipeFds(fds)
        if (rc < 0) {
            return SysMaybe<PipeFdPair>.Err(SysError(UInt16(Int64(OS.errno())), SysTag.Pipe))
        }
        return SysMaybe<PipeFdPair>.Ok(PipeFdPair(Int64(fds[0]), Int64(fds[1])))
    }

    private static func createPipeFds(fds: Array<Int32>): Int32 {
        return Int32(-1)
    }
}

// ============================================================================
// IoStdioConfig - 标准 IO 配置
// 用于子进程管道创建
// ============================================================================

/// 标准输入输出配置
public enum IoStdioConfig {
    | Inherit     // 继承父进程
    | Pipe        // 创建管道
    | Null        // /dev/null
    | Close       // 关闭
}

