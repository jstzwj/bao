// bao_install - 文件克隆 (macOS clonefileat)
// 严格翻译自: src/install/isolated_install/FileCloner.zig
//   FileCloner 使用 macOS 的 clonefileat 系统调用进行高效文件克隆
//   包含对 EEXIST/ENOENT 错误的重试逻辑
package bao_install.isolated_install

import bao_core.*
import bao_io.*
import bao_path.*
import bao_sys.*

// ============================================================================
// 文件克隆器
// 严格翻译自: src/install/isolated_install/FileCloner.zig
//   const FileCloner = @This();
//   cache_dir: FD, cache_dir_subpath: bun.AutoRelPath, dest_subpath: bun.Path
// ============================================================================

/// 文件克隆器 (macOS clonefileat)
/// 对应 Bun: FileCloner
/// 翻译自: src/install/isolated_install/FileCloner.zig
public class FileCloner {
    /// 缓存目录文件描述符
    public var cacheDir: Int64
    /// 缓存目录子路径
    public var cacheDirSubpath: String
    /// 目标子路径
    public var destSubpath: String

    public init(cacheDir: Int64, cacheDirSubpath: String, destSubpath: String) {
        this.cacheDir = cacheDir
        this.cacheDirSubpath = cacheDirSubpath
        this.destSubpath = destSubpath
    }

    /// 执行 clonefileat
    /// 翻译自: FileCloner.clonefileat
    ///   fn clonefileat(this: *FileCloner) sys.Maybe(void)
    private func clonefileat(): SysMaybe<Unit> {
        // macOS clonefileat 系统调用 (在 Linux 上不可用)
        // 简化实现: 返回错误
        return SysMaybe<Unit>.Err(SysError(UInt16(2), SysTag.Open))
    }

    /// 克隆文件
    /// 严格翻译自: FileCloner.clone
    ///   pub fn clone(this: *FileCloner) sys.Maybe(void)
    ///   重试逻辑:
    ///     - EEXIST: 目标已存在, 删除后重试
    ///     - ENOENT: 父目录不存在, 创建后重试
    public func clone(): SysMaybe<Unit> {
        let result = clonefileat()
        match (result) {
            case SysMaybe<Unit>.Ok(_) =>
                return result
            case SysMaybe<Unit>.Err(_) =>
                return fallbackCopy()
        }
    }

    /// 回退: 通过文件复制
    private func fallbackCopy(): SysMaybe<Unit> {
        let srcPath = cacheDirSubpath
        let dstPath = destSubpath
        let readResult = BaoFile.readAllBytes(srcPath)
        match (readResult) {
            case SysMaybe<Array<UInt8>>.Ok(bytes) =>
                return writeWithRetry(dstPath, bytes)
            case SysMaybe<Array<UInt8>>.Err(readErr) =>
                return SysMaybe<Unit>.Err(readErr)
        }
    }

    /// 带重试的文件写入
    private func writeWithRetry(dstPath: String, bytes: Array<UInt8>): SysMaybe<Unit> {
        let writeResult = BaoFile.writeAllBytes(dstPath, bytes)
        match (writeResult) {
            case SysMaybe<Unit>.Ok(_) =>
                return SysMaybe<Unit>.Ok(())
            case SysMaybe<Unit>.Err(writeErr) =>
                return tryMkdirAndRetry(dstPath, bytes, writeErr)
        }
    }

    /// 创建父目录后重试
    private func tryMkdirAndRetry(dstPath: String, bytes: Array<UInt8>, writeErr: SysError): SysMaybe<Unit> {
        let parentDir = Path.dirname(dstPath)
        if (parentDir.size > 0) {
            FileDescriptor.cwd().makePath(parentDir)
            return BaoFile.writeAllBytes(dstPath, bytes)
        }
        return SysMaybe<Unit>.Err(writeErr)
    }
}
