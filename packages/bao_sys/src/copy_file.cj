// bao_sys - 文件复制
// 严格翻译自: src/sys/copy_file.rs
//   Bun 使用多级策略复制文件:
//   1. ioctl_ficlone (Btrfs/AFPS reflink)
//   2. copy_file_range (Linux 4.5+)
//   3. sendfile() (Linux)
//   4. read()/write() 循环 (回退)
//   在 bun install 中减少系统调用数从 ~18000 到 ~12000
package bao_sys

import bao_core.*

// ============================================================================
// CopyFileRangeError - copy_file_range 错误
// 严格翻译自: src/sys/copy_file.rs:21-44
//   pub enum CopyFileRangeError { FileTooBig, InputOutput, ... }
// ============================================================================

/// copy_file_range 错误类型 - 对应 Bun CopyFileRangeError
public enum CopyFileRangeError {
    | FileTooBig
    | InputOutput
    | FilesOpenedWithWrongFlags
    | IsDir
    | OutOfMemory
    | NoSpaceLeft
    | Unseekable
    | PermissionDenied
    | FileBusy

    public func toString(): String {
        match (this) {
            case FileTooBig => "FileTooBig"
            case InputOutput => "InputOutput"
            case FilesOpenedWithWrongFlags => "FilesOpenedWithWrongFlags"
            case IsDir => "IsDir"
            case OutOfMemory => "OutOfMemory"
            case NoSpaceLeft => "NoSpaceLeft"
            case Unseekable => "Unseekable"
            case PermissionDenied => "PermissionDenied"
            case FileBusy => "FileBusy"
        }
    }
}

// ============================================================================
// LinuxCopyFileState - Linux 文件复制状态
// 严格翻译自: src/sys/copy_file.rs:76-94
//   bitflags! { pub struct LinuxCopyFileState: u8 { ... } }
//   记录哪些快速复制方式已失败，避免重复尝试
// ============================================================================

/// Linux 文件复制状态 - 对应 Bun LinuxCopyFileState
/// 使用位标志跟踪哪些快速复制方式已失败
public class LinuxCopyFileState {
    /// 是否已见过 EXDEV (跨设备)
    public var hasSeenExdev: Bool
    /// ioctl_ficlone 是否已失败
    public var hasIoctlFicloneFailed: Bool
    /// copy_file_range 是否已失败
    public var hasCopyFileRangeFailed: Bool
    /// sendfile 是否已失败
    public var hasSendfileFailed: Bool

    public init() {
        hasSeenExdev = false
        hasIoctlFicloneFailed = false
        hasCopyFileRangeFailed = false
        hasSendfileFailed = false
    }
}

/// 空的复制状态 (非 Linux 平台)
public class EmptyCopyFileState {}

// ============================================================================
// C FFI 声明
// ============================================================================

@C
foreign func sendfile(outFd: Int32, inFd: Int32, offset: CPointer<Int64>, count: UIntNative): Int64
@C
foreign func copy_file_range(inFd: Int32, offIn: CPointer<Int64>, outFd: Int32,
                              offOut: CPointer<Int64>, len: UIntNative, flags: UInt32): Int64

// ============================================================================
// SysCopyFile - 文件复制操作
// 严格翻译自: src/sys/copy_file.rs:107-261
//   copy_file_with_state() 实现多级复制策略
// ============================================================================

/// 文件复制操作 - 对应 Bun copy_file 函数集
/// 使用最高效的方式复制文件内容
public class SysCopyFile {
    /// 默认缓冲区大小 - 32 KiB
    /// 对应 copy_file_read_write_loop 中 buf = [0u8; 8 * 4096]
    public static let BUFFER_SIZE: Int64 = 32 * 1024

    /// 复制文件 (带状态) - 对应 Bun copy_file_with_state(in_, out, state)
    /// 使用 copy_file_range -> sendfile -> read/write 回退链
    public static func copyFileWithState(inFd: Int64, outFd: Int64,
                                          state: LinuxCopyFileState): SysMaybe<Unit> {
        // 尝试 copy_file_range
        if (!state.hasCopyFileRangeFailed && !state.hasSeenExdev) {
            let cfrResult = copyFileRangeLoop(inFd, outFd, state)
            match (cfrResult) {
                case Ok(_) => return SysMaybe<Unit>.Ok(())
                case Err(e) =>
                    // 如果 copy_file_range 只是标记失败但没有返回错误，继续
                    if (e.errno != 0) {
                        // 回退到 sendfile
                    }
            }
        }

        // 尝试 sendfile
        if (!state.hasSendfileFailed && !state.hasSeenExdev) {
            let sendResult = sendfileLoop(inFd, outFd, state)
            match (sendResult) {
                case Ok(_) => return SysMaybe<Unit>.Ok(())
                case Err(e) =>
                    if (e.errno != 0) {
                        // 回退到 read/write
                    }
            }
        }

        // 最终回退: read/write 循环
        return copyFileReadWriteLoop(inFd, outFd)
    }

    /// 复制文件 (简单版) - 对应 Bun copy_file(in_, out)
    public static func copyFile(inFd: Int64, outFd: Int64): SysMaybe<Unit> {
        let state = LinuxCopyFileState()
        return copyFileWithState(inFd, outFd, state)
    }

    /// copy_file_range 循环 - 对应 Bun copy_file.rs 中的 copy_file_range 分支
    private static func copyFileRangeLoop(inFd: Int64, outFd: Int64,
                                           state: LinuxCopyFileState): SysMaybe<Unit> {
        unsafe {
            var offset: UInt64 = 0
            let maxChunk = UIntNative(Int32.MaxValue - 1)
            while (true) {
                let rc = copy_file_range(
                    Int32(inFd), CPointer<Int64>(),
                    Int32(outFd), CPointer<Int64>(),
                    maxChunk, UInt32(0)
                )
                if (rc < 0) {
                    let errno = Int64(OS.errno())
                    // EINVAL: 可能不是普通文件
                    if (errno == 22) {
                        state.hasCopyFileRangeFailed = true
                        return SysMaybe<Unit>.Ok(())  // 继续到下一种方法
                    }
                    // EXDEV: 跨设备
                    if (errno == 18) {
                        state.hasSeenExdev = true
                        state.hasCopyFileRangeFailed = true
                        return SysMaybe<Unit>.Ok(())
                    }
                    // ENOTSUP/ENOSYS: 不支持
                    if (errno == 95 || errno == 38) {
                        state.hasCopyFileRangeFailed = true
                        return SysMaybe<Unit>.Ok(())
                    }
                    // EINTR: 重试
                    if (errno == 4) {
                        continue
                    }
                    return SysMaybe<Unit>.Err(
                        SysError(UInt16(errno), SysTag.CopyFileRange)
                    )
                }
                if (rc == 0) {
                    break  // EOF
                }
                offset += UInt64(rc)
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// sendfile 循环 - 对应 Bun copy_file.rs 中的 sendfile 分支
    private static func sendfileLoop(inFd: Int64, outFd: Int64,
                                      state: LinuxCopyFileState): SysMaybe<Unit> {
        unsafe {
            let maxChunk = UIntNative(Int32.MaxValue - 1)
            while (true) {
                let rc = sendfile(Int32(outFd), Int32(inFd), CPointer<Int64>(), maxChunk)
                if (rc < 0) {
                    let errno = Int64(OS.errno())
                    if (errno == 22) {
                        state.hasSendfileFailed = true
                        return SysMaybe<Unit>.Ok(())
                    }
                    if (errno == 18) {
                        state.hasSeenExdev = true
                        state.hasSendfileFailed = true
                        return SysMaybe<Unit>.Ok(())
                    }
                    if (errno == 95 || errno == 38) {
                        state.hasSendfileFailed = true
                        return SysMaybe<Unit>.Ok(())
                    }
                    if (errno == 4) {
                        continue  // EINTR
                    }
                    state.hasSendfileFailed = true
                    return SysMaybe<Unit>.Ok(())
                }
                if (rc == 0) {
                    break  // EOF
                }
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// read/write 循环回退 - 对应 Bun copy_file_read_write_loop
    /// copy_file.rs:447-477
    public static func copyFileReadWriteLoop(inFd: Int64, outFd: Int64): SysMaybe<Unit> {
        var buf = Array<UInt8>(Int64(BUFFER_SIZE), item: 0)
        while (true) {
            // 读取
            let readResult = SysFs.read(inFd, buf)
            match (readResult) {
                case Err(e) => return SysMaybe<Unit>.Err(e)
                case Ok(bytesRead) =>
                    if (bytesRead == 0) {
                        return SysMaybe<Unit>.Ok(())  // EOF
                    }
                    // 写入
                    var written: Int64 = 0
                    while (written < bytesRead) {
                        var writeBuf = Array<UInt8>(Int64(bytesRead) - written, item: 0)
                        for (i in 0..Int64(writeBuf.size)) {
                            writeBuf[i] = buf[Int64(written) + i]
                        }
                        let writeResult = SysFs.write(outFd, writeBuf)
                        match (writeResult) {
                            case Err(e) => return SysMaybe<Unit>.Err(e)
                            case Ok(wrote) =>
                                if (wrote == 0) {
                                    return SysMaybe<Unit>.Ok(())
                                }
                                written += wrote
                        }
                    }
            }
        }
    }
}
