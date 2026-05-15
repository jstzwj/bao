// bao_install - 文件克隆 (macOS clonefileat)
// 严格翻译自: src/install/isolated_install/FileCloner.zig
//   FileCloner 使用 macOS 的 clonefileat 系统调用进行高效文件克隆
//   包含对 EEXIST/ENOENT 错误的重试逻辑
package bao_install.isolated_install

import bao_core.*
import bao_io.*
import bao_path.*

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
    public var cacheDir: FileDescriptor
    /// 缓存目录子路径
    public var cacheDirSubpath: String
    /// 目标子路径
    public var destSubpath: String

    public init(cacheDir: FileDescriptor, cacheDirSubpath: String, destSubpath: String) {
        this.cacheDir = cacheDir
        this.cacheDirSubpath = cacheDirSubpath
        this.destSubpath = destSubpath
    }

    /// 执行 clonefileat
    /// 翻译自: FileCloner.clonefileat
    ///   fn clonefileat(this: *FileCloner) sys.Maybe(void)
    private func clonefileat(): SyscallResult {
        return bao_sys.Syscall.clonefileat(
            cacheDir,
            cacheDirSubpath,
            FileDescriptor.cwd(),
            destSubpath
        )
    }

    /// 克隆文件
    /// 严格翻译自: FileCloner.clone
    ///   pub fn clone(this: *FileCloner) sys.Maybe(void)
    ///   重试逻辑:
    ///     - EEXIST: 目标已存在, 删除后重试
    ///     - ENOENT: 父目录不存在, 创建后重试
    public func clone(): SyscallResult {
        match (clonefileat()) {
            case Success => return SyscallResult.Success
            case Err(err) => {
                match (err.errno) {
                    case Errno.EXIST => {
                        // 过时的残留文件 (之前的崩溃或重新运行)
                        // 全局存储条目通过 entry-level rename 发布,
                        // 所以在这里擦除并重新克隆总是安全的
                        FileDescriptor.cwd().deleteTree(destSubpath)
                        return clonefileat()
                    }
                    case Errno.NOENT => {
                        let parentDestDir = Path.dirname(destSubpath)
                        if (parentDestDir.length == 0) {
                            return SyscallResult.Err(err)
                        }
                        FileDescriptor.cwd().makePath(parentDestDir)
                        return clonefileat()
                    }
                    case _ => {
                        return SyscallResult.Err(err)
                    }
                }
            }
        }
    }
}
