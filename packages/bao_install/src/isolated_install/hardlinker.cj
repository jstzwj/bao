// bao_install - 硬链接创建器
// 严格翻译自: src/install/isolated_install/Hardlinker.zig
//   Hardlinker 使用 Walker 遍历源目录并创建硬链接到目标目录
//   包含对 EEXIST/ENOENT 错误的重试逻辑
package bao_install

import bao_core.*
import bao_io.*
import bao_path.*

// ============================================================================
// 硬链接创建器
// 严格翻译自: src/install/isolated_install/Hardlinker.zig
//   const Hardlinker = @This();
//   src_dir: FD, src: bun.AbsPath, dest: bun.Path, walker: Walker
// ============================================================================

/// 硬链接创建器
/// 对应 Bun: Hardlinker
/// 翻译自: src/install/isolated_install/Hardlinker.zig
public class Hardlinker {
    /// 源目录文件描述符
    public var srcDir: FileDescriptor
    /// 源路径
    public var src: String
    /// 目标路径
    public var dest: String
    /// 跳过的目录名列表
    public var skipDirnames: ArrayList<String>
    /// 遍历器
    public var walker: ?WalkerRef

    public init(srcDir: FileDescriptor, src: String, dest: String) {
        this.srcDir = srcDir
        this.src = src
        this.dest = dest
        skipDirnames = ArrayList<String>()
        walker = None
    }

    public init(srcDir: FileDescriptor, src: String, dest: String, skipDirnames: ArrayList<String>) {
        this.srcDir = srcDir
        this.src = src
        this.dest = dest
        this.skipDirnames = skipDirnames
        walker = None
    }

    /// 清理
    /// 翻译自: Hardlinker.deinit
    ///   pub fn deinit(this: *Hardlinker) void
    public func deinit(): Unit {
        walker = None
        skipDirnames.clear()
    }

    /// 执行硬链接
    /// 严格翻译自: Hardlinker.link
    ///   pub fn link(this: *Hardlinker) OOM!sys.Maybe(void)
    ///   遍历源目录树, 为每个文件创建硬链接
    ///   目录: 创建目标目录
    ///   文件: 创建硬链接, 失败时重试 (EEXIST 删除后重试, ENOENT 创建父目录后重试)
    public func link(): SyscallResult {
        if (PackageManager.verboseInstall) {
            bao_core.Output.print("Hardlinking ${src} to ${dest}\n")
        }

        // 初始化遍历器
        walker = WalkerRef(srcDir: srcDir, skipDirnames: skipDirnames)

        match (walker) {
            case Some(w) => {
                while (true) {
                    match (w.next()) {
                        case Some(entry) => {
                            let destPath = Path.join(dest, entry.path)

                            match (entry.kind) {
                                case WalkerEntryKind.Directory => {
                                    FileDescriptor.cwd().makePath(destPath)
                                }
                                case WalkerEntryKind.File => {
                                    let srcPath = Path.join(src, entry.path)

                                    match (bao_sys.Syscall.linkat(
                                        srcDir: srcDir,
                                        srcPath: srcPath,
                                        destDir: FileDescriptor.cwd(),
                                        destPath: destPath
                                    )) {
                                        case Success => ()
                                        case Err(linkErr1) => {
                                            match (linkErr1.errno) {
                                                case Errno.EXIST => {
                                                    // 目标已存在, 删除后重试
                                                    FileDescriptor.cwd().deleteTree(destPath)
                                                    match (bao_sys.Syscall.linkat(
                                                        srcDir: srcDir,
                                                        srcPath: srcPath,
                                                        destDir: FileDescriptor.cwd(),
                                                        destPath: destPath
                                                    )) {
                                                        case Success => ()
                                                        case Err(linkErr2) => return SyscallResult.Err(linkErr2)
                                                    }
                                                }
                                                case Errno.NOENT => {
                                                    // 父目录不存在, 创建后重试
                                                    let destParent = Path.dirname(destPath)
                                                    if (destParent.length == 0) {
                                                        return SyscallResult.Err(linkErr1)
                                                    }
                                                    FileDescriptor.cwd().makePath(destParent)
                                                    match (bao_sys.Syscall.linkat(
                                                        srcDir: srcDir,
                                                        srcPath: srcPath,
                                                        destDir: FileDescriptor.cwd(),
                                                        destPath: destPath
                                                    )) {
                                                        case Success => ()
                                                        case Err(linkErr2) => return SyscallResult.Err(linkErr2)
                                                    }
                                                }
                                                case _ => return SyscallResult.Err(linkErr1)
                                            }
                                        }
                                    }
                                }
                                case _ => ()
                            }
                        }
                        case None => break
                    }
                }
            }
            case None => ()
        }

        return SyscallResult.Success
    }
}

/// 包管理器 (引用, 用于 verbose_install 标志)
public class PackageManager {
    public static let verboseInstall: Bool = false
}
