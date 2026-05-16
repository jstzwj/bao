// bao_io - 流拷贝工具
// 严格翻译自: src/io/ + src/sys/copy_file.zig
//   Bun 提供多种文件/流拷贝机制:
//   copy_file_range - Linux 零拷贝系统调用
//   sendfile - 内核空间零拷贝
//   splice - 管道零拷贝
//   用户空间缓冲拷贝 - 跨平台后备
//   用于: Bun.write(), 文件复制, 响应代理
package bao_io

import bao_core.*
import bao_sys.*

// ============================================================================
// 零拷贝 C FFI 声明
// 严格翻译自: src/sys/copy_file.zig, src/sys/sys.zig
// ============================================================================

/// copy_file_range - Linux 文件间零拷贝
/// Linux 4.5+: 在两个文件描述符之间复制数据，不经过用户空间
/// 对应 Bun: src/sys/copy_file.zig 中的 copy_file_range 调用
@C
foreign func copy_file_range(fd_in: Int32, off_in: CPointer<Int64>,
                              fd_out: Int32, off_out: CPointer<Int64>,
                              len: UIntNative, flags: UInt32): Int64

/// sendfile - 内核空间零拷贝
/// 将数据从文件描述符传输到套接字 (或其他 FD)
/// 对应 Bun: src/sys/sys.zig 中的 sendfile 调用
@C
foreign func sendfile(out_fd: Int32, in_fd: Int32, offset: CPointer<Int64>,
                       count: UIntNative): Int64

/// splice - 管道零拷贝
/// 在管道和文件描述符之间移动数据
/// 对应 Bun: 零拷贝代理时的 splice 使用
@C
foreign func splice(fd_in: Int32, off_in: CPointer<Int64>,
                     fd_out: Int32, off_out: CPointer<Int64>,
                     len: UIntNative, flags: UInt32): Int64

// ============================================================================
// CopyMethod - 拷贝方法
// 严格翻译自: Bun 使用的不同拷贝策略
//   Bun 根据源/目标 FD 类型自动选择最佳拷贝方法
// ============================================================================

/// 拷贝方法 - 对应 Bun 的不同拷贝策略
public enum CopyMethod {
    | CopyFileRange    // Linux copy_file_range (文件到文件)
    | Sendfile         // sendfile (文件到套接字)
    | Splice           // splice (管道到管道/套接字)
    | Userspace        // 用户空间缓冲拷贝 (通用后备)
    | Auto             // 自动选择最佳方法

    public func description(): String {
        match (this) {
            case CopyFileRange => "copy_file_range"
            case Sendfile => "sendfile"
            case Splice => "splice"
            case Userspace => "userspace"
            case Auto => "auto"
        }
    }
}

// ============================================================================
// CopyResult - 拷贝结果
// ============================================================================

/// 拷贝操作结果
public class CopyResult {
    /// 拷贝的总字节数
    public var bytesCopied: Int64
    /// 使用的方法
    public var method: CopyMethod
    /// 耗时 (毫秒)
    public var durationMs: Int64
    /// 错误 (如果有)
    public var error: ?SysError

    public init(bytesCopied: Int64, method: CopyMethod) {
        this.bytesCopied = bytesCopied
        this.method = method
        this.durationMs = 0
        this.error = None
    }

    public static func error(err: SysError, method: CopyMethod): CopyResult {
        let r = CopyResult(0, method)
        r.error = Some(err)
        return r
    }

    /// 是否成功
    public func isOk(): Bool {
        return error == None
    }

    /// 吞吐量 (字节/秒)
    public func throughput(): Float64 {
        if (durationMs == 0) {
            return 0.0
        }
        return Float64(bytesCopied) / (Float64(durationMs) / 1000.0)
    }
}

// ============================================================================
// CopyOptions - 拷贝选项
// ============================================================================

/// 拷贝选项
public class CopyOptions {
    /// 缓冲区大小 (用于用户空间拷贝)
    public var bufferSize: Int64
    /// 拷贝方法
    public var method: CopyMethod
    /// 源偏移 (用于 seek + copy)
    public var srcOffset: Int64
    /// 目标偏移
    public var dstOffset: Int64
    /// 最大拷贝字节数 (-1 = 全部)
    public var maxBytes: Int64

    public init() {
        bufferSize = MAX_BUF_SIZE
        method = CopyMethod.Auto
        srcOffset = -1
        dstOffset = -1
        maxBytes = -1
    }

    public static func defaults(): CopyOptions {
        return CopyOptions()
    }
}

// ============================================================================
// StreamCopy - 流拷贝工具
// 严格翻译自: src/sys/copy_file.zig + Bun.write() 逻辑
//   Bun 使用以下策略进行数据拷贝:
//   1. 优先尝试 copy_file_range (Linux, 文件到文件)
//   2. 退而使用 sendfile (文件到套接字)
//   3. 退而使用 splice (管道间)
//   4. 最后使用用户空间缓冲拷贝
// ============================================================================

/// 流拷贝工具 - 对应 Bun 的数据拷贝逻辑
public class StreamCopy {
    /// 在两个文件描述符之间拷贝数据
    /// 对应 Bun: Bun.write(src, dst) 的核心逻辑
    /// 自动选择最佳拷贝方法
    public static func copy(srcFd: Int64, dstFd: Int64): CopyResult {
        return copy(srcFd, dstFd, CopyOptions.defaults())
    }

    /// 带选项拷贝
    public static func copy(srcFd: Int64, dstFd: Int64, options: CopyOptions): CopyResult {
        match (options.method) {
            case CopyMethod.CopyFileRange =>
                return copyFileRange(srcFd, dstFd, options)
            case CopyMethod.Sendfile =>
                return sendfileCopy(srcFd, dstFd, options)
            case CopyMethod.Splice =>
                return spliceCopy(srcFd, dstFd, options)
            case CopyMethod.Userspace =>
                return copyBuffered(srcFd, dstFd, options)
            case CopyMethod.Auto =>
                return copyAuto(srcFd, dstFd, options)
        }
    }

    /// 自动选择最佳拷贝方法
    /// 严格对应 Bun 的拷贝策略选择:
    /// 1. copy_file_range (文件->文件)
    /// 2. sendfile (文件->套接字)
    /// 3. splice (管道->任意)
    /// 4. 用户空间缓冲拷贝
    private static func copyAuto(srcFd: Int64, dstFd: Int64, options: CopyOptions): CopyResult {
        // 尝试 copy_file_range
        let cfrResult = copyFileRange(srcFd, dstFd, options)
        if (cfrResult.isOk() && cfrResult.bytesCopied > 0) {
            cfrResult.method = CopyMethod.CopyFileRange
            return cfrResult
        }

        // 尝试 sendfile
        let sfResult = sendfileCopy(srcFd, dstFd, options)
        if (sfResult.isOk() && sfResult.bytesCopied > 0) {
            sfResult.method = CopyMethod.Sendfile
            return sfResult
        }

        // 退而使用用户空间拷贝
        let result = copyBuffered(srcFd, dstFd, options)
        result.method = CopyMethod.Userspace
        return result
    }

    /// copy_file_range 零拷贝
    /// 严格翻译自: src/sys/copy_file.zig
    /// Linux 4.5+ 系统调用, 文件间零拷贝
    /// 数据在内核空间移动, 不经过用户空间
    /// copy_file.zig:
    ///   fn copy_file_range(src_fd, dst_fd, src_offset, dst_offset, len) Maybe(usize)
    public static func copyFileRange(srcFd: Int64, dstFd: Int64, options: CopyOptions): CopyResult {
        var totalCopied: Int64 = 0
        let maxCopy = if (options.maxBytes < 0) { Int64.MAX_VALUE } else { options.maxBytes }

        while (totalCopied < maxCopy) {
            let remaining = maxCopy - totalCopied
            let chunkSize = if (remaining > MAX_BUF_SIZE) { UIntNative(MAX_BUF_SIZE) } else { UIntNative(remaining) }

            let copied = copy_file_range(
                Int32(srcFd), CPointer<Int64>(),
                Int32(dstFd), CPointer<Int64>(),
                chunkSize, UInt32(0)
            )

            if (copied < 0) {
                let errno = OS.errno()
                // EINVAL / ENOSYS / EOPNOTSUPP 表示不支持, 应该退回用户空间拷贝
                if (errno == 22 || errno == 38 || errno == 95) {
                    break
                }
                // EAGAIN: 稍后重试
                if (errno == 11) {
                    continue
                }
                return CopyResult.error(
                    SysError(UInt16(errno), SysTag.CopyFileRange),
                    CopyMethod.CopyFileRange
                )
            }
            if (copied == 0) {
                break  // EOF
            }
            totalCopied += copied
        }

        let result = CopyResult(totalCopied, CopyMethod.CopyFileRange)
        return result
    }

    /// sendfile 零拷贝
    /// 严格翻译自: src/sys/sys.zig sendfile
    /// 将文件数据直接发送到套接字
    /// 数据在内核空间从文件传输到网络, 不经过用户空间
    /// sys.zig: pub fn sendfile(out_fd, in_fd, offset, count) Maybe(usize)
    public static func sendfileCopy(srcFd: Int64, dstFd: Int64, options: CopyOptions): CopyResult {
        var totalCopied: Int64 = 0
        let maxCopy = if (options.maxBytes < 0) { Int64.MAX_VALUE } else { options.maxBytes }

        while (totalCopied < maxCopy) {
            let remaining = maxCopy - totalCopied
            let chunkSize = if (remaining > MAX_BUF_SIZE) { UIntNative(MAX_BUF_SIZE) } else { UIntNative(remaining) }

            let copied = sendfile(
                Int32(dstFd), Int32(srcFd),
                CPointer<Int64>(),
                chunkSize
            )

            if (copied < 0) {
                let errno = OS.errno()
                if (errno == 22 || errno == 38) {
                    break  // 不支持
                }
                if (errno == 11) {
                    continue  // EAGAIN
                }
                return CopyResult.error(
                    SysError(UInt16(errno), SysTag.Sendfile),
                    CopyMethod.Sendfile
                )
            }
            if (copied == 0) {
                break  // EOF
            }
            totalCopied += copied
        }

        return CopyResult(totalCopied, CopyMethod.Sendfile)
    }

    /// splice 零拷贝
    /// 严格翻译自: Linux splice 系统调用
    /// 在管道和其他 FD 之间零拷贝移动数据
    /// splice 的 SPLICE_F_MOVE 标志可以避免数据复制到用户空间
    public static func spliceCopy(srcFd: Int64, dstFd: Int64, options: CopyOptions): CopyResult {
        let SPLICE_F_MOVE: UInt32 = 1
        let SPLICE_F_NONBLOCK: UInt32 = 2
        let SPLICE_F_MORE: UInt32 = 4

        var totalCopied: Int64 = 0
        let maxCopy = if (options.maxBytes < 0) { Int64.MAX_VALUE } else { options.maxBytes }

        while (totalCopied < maxCopy) {
            let remaining = maxCopy - totalCopied
            let chunkSize = if (remaining > MAX_BUF_SIZE) { UIntNative(MAX_BUF_SIZE) } else { UIntNative(remaining) }

            let copied = splice(
                Int32(srcFd), CPointer<Int64>(),
                Int32(dstFd), CPointer<Int64>(),
                chunkSize,
                SPLICE_F_MOVE | SPLICE_F_MORE
            )

            if (copied < 0) {
                let errno = OS.errno()
                if (errno == 22 || errno == 38) {
                    break
                }
                if (errno == 11) {
                    continue
                }
                return CopyResult.error(
                    SysError(UInt16(errno), SysTag.Splice),
                    CopyMethod.Splice
                )
            }
            if (copied == 0) {
                break
            }
            totalCopied += copied
        }

        return CopyResult(totalCopied, CopyMethod.Splice)
    }

    /// 用户空间缓冲拷贝
    /// 严格翻译自: Bun 的通用拷贝后备方案
    /// 使用 read/write 系统调用在用户空间缓冲区中拷贝数据
    /// 这是跨平台的通用实现, 当零拷贝不可用时使用
    /// 对应 Bun.write() 的回退路径
    public static func copyBuffered(srcFd: Int64, dstFd: Int64, options: CopyOptions): CopyResult {
        var totalCopied: Int64 = 0
        let bufSize = options.bufferSize
        let maxCopy = if (options.maxBytes < 0) { Int64.MAX_VALUE } else { options.maxBytes }
        let buf = Array<UInt8>(bufSize, item: UInt8(0))

        while (totalCopied < maxCopy) {
            let remaining = maxCopy - totalCopied
            let toRead = if (remaining < bufSize) { remaining } else { bufSize }

            // 读取源
            var readBuf = Array<UInt8>(toRead, item: UInt8(0))
            match (SysFs.read(srcFd, readBuf)) {
                case SysMaybe<Int64>.Err(err) =>
                    if (totalCopied > 0) {
                        return CopyResult(totalCopied, CopyMethod.Userspace)
                    }
                    return CopyResult.error(err, CopyMethod.Userspace)
                case SysMaybe<Int64>.Ok(bytesRead) =>
                    if (bytesRead == 0) {
                        break  // EOF
                    }
                    // 写入目标
                    var writeBuf = Array<UInt8>()
                    for (i in 0..bytesRead) {
                        writeBuf.append(readBuf[i])
                    }
                    match (SysFs.write(dstFd, writeBuf)) {
                        case SysMaybe<Int64>.Err(err) =>
                            if (totalCopied > 0) {
                                return CopyResult(totalCopied, CopyMethod.Userspace)
                            }
                            return CopyResult.error(err, CopyMethod.Userspace)
                        case SysMaybe<Int64>.Ok(bytesWritten) =>
                            totalCopied += bytesWritten
                            if (bytesWritten < bytesRead) {
                                break  // 目标无法接收更多
                            }
                    }
            }
        }

        return CopyResult(totalCopied, CopyMethod.Userspace)
    }

    /// 文件到文件拷贝 (路径)
    /// 打开源文件, 创建目标文件, 拷贝数据, 关闭两个文件
    /// 对应 Bun: Bun.write(dst, src) 的文件路径版本
    public static func copyFile(srcPath: String, dstPath: String): CopyResult {
        return copyFile(srcPath, dstPath, CopyOptions.defaults())
    }

    /// 带选项的文件到文件拷贝
    public static func copyFile(srcPath: String, dstPath: String, options: CopyOptions): CopyResult {
        // 打开源文件
        match (SysFs.openRead(srcPath)) {
            case SysMaybe<Int64>.Err(e) =>
                return CopyResult.error(e, options.method)
            case SysMaybe<Int64>.Ok(srcFd) =>
                // 创建目标文件
                match (SysFs.openWrite(dstPath)) {
                    case SysMaybe<Int64>.Err(e) =>
                        SysFs.close(srcFd)
                        return CopyResult.error(e, options.method)
                    case SysMaybe<Int64>.Ok(dstFd) =>
                        // 执行拷贝
                        let result = copy(srcFd, dstFd, options)
                        // 关闭文件
                        SysFs.close(srcFd)
                        SysFs.close(dstFd)
                        return result
                }
        }
    }

    /// 从 Reader 拷贝到 Writer
    /// 使用 BufferedReader 和 EnhancedBufferedWriter 进行拷贝
    /// 对应 Bun: readableStream.pipeTo(writableStream)
    public static func copyStream(reader: BufferedReader, writer: EnhancedBufferedWriter): CopyResult {
        var totalCopied: Int64 = 0

        while (!reader.isEof()) {
            let fillResult = reader.fillFromFd()
            match (fillResult) {
                case Err(e) =>
                    return CopyResult.error(e, CopyMethod.Userspace)
                case Ok(n) =>
                    if (n == 0) {
                        break
                    }
                    let available = reader.available()
                    if (available > 0) {
                        let data = reader.readBytes(available)
                        match (data) {
                            case Some(bytes) =>
                                let writeResult = writer.writeBytes(bytes)
                                if (!writeResult.isOk()) {
                                    match (writeResult.err) {
                                        case Some(e) =>
                                            return CopyResult.error(e, CopyMethod.Userspace)
                                        case None => ()
                                    }
                                }
                                totalCopied += writeResult.bytesWritten
                            case None => ()
                        }
                    }
            }
        }
        writer.flush()
        return CopyResult(totalCopied, CopyMethod.Userspace)
    }
}
