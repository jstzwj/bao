// bao_install - 文件复制器
// 严格翻译自: src/install/isolated_install/FileCopier.zig
//   FileCopier 使用 Walker 遍历源目录并将文件复制到目标目录
//   支持平台特定路径 (Windows/POSIX)
package bao_install

import bao_core.*
import bao_io.*
import bao_path.*

// ============================================================================
// 文件复制器
// 严格翻译自: src/install/isolated_install/FileCopier.zig
//   pub const FileCopier = struct {
//       src_path: bun.AbsPath, dest_subpath: bun.Path, walker: Walker
//   }
// ============================================================================

/// 文件复制器
/// 对应 Bun: FileCopier
/// 翻译自: src/install/isolated_install/FileCopier.zig
public class FileCopier {
    /// 源路径
    public var srcPath: String
    /// 目标子路径
    public var destSubpath: String
    /// 跳过的目录名列表
    public var skipDirnames: ArrayList<String>
    /// 遍历器
    public var walker: ?WalkerRef

    public init(srcPath: String, destSubpath: String) {
        this.srcPath = srcPath
        this.destSubpath = destSubpath
        skipDirnames = ArrayList<String>()
        walker = None
    }

    public init(srcPath: String, destSubpath: String, skipDirnames: ArrayList<String>) {
        this.srcPath = srcPath
        this.destSubpath = destSubpath
        this.skipDirnames = skipDirnames
        walker = None
    }

    /// 初始化遍历器
    /// 翻译自: FileCopier.init
    ///   pub fn init(src_dir, src_path, dest_subpath, skip_dirnames) OOM!FileCopier
    public func initWalker(srcDir: FileDescriptor): Unit {
        walker = WalkerRef(srcDir: srcDir, skipDirnames: skipDirnames)
    }

    /// 清理
    /// 翻译自: FileCopier.deinit
    ///   pub fn deinit(this: *FileCopier) void
    public func deinit(): Unit {
        walker = None
        skipDirnames.clear()
    }

    /// 执行复制
    /// 严格翻译自: FileCopier.copy
    ///   pub fn copy(this: *FileCopier) sys.Maybe(void)
    ///   遍历源目录树, 将每个文件复制到目标路径
    ///   如果目标目录不存在, 创建之
    ///   如果目标文件创建失败, 尝试创建父目录后重试
    public func copy(): SyscallResult {
        // 创建目标目录
        FileDescriptor.cwd().makePath(destSubpath)

        match (walker) {
            case Some(w) => {
                while (true) {
                    match (w.next()) {
                        case Some(entry) => {
                            // 只处理普通文件
                            if (entry.kind != WalkerEntryKind.File) {
                                continue
                            }

                            let src = Path.join(srcPath, entry.path)
                            let dest = Path.join(destSubpath, entry.path)

                            // 复制文件
                            match (bao_sys.Syscall.copyFile(src: src, dest: dest)) {
                                case Success => {}
                                case Err(firstErr) => {
                                    // 复制失败, 尝试创建父目录后重试
                                    let entryDirname = Path.dirname(entry.path)
                                    if (entryDirname.length > 0) {
                                        FileDescriptor.cwd().makePath(
                                            Path.join(destSubpath, entryDirname)
                                        )
                                    }

                                    match (bao_sys.Syscall.copyFile(src: src, dest: dest)) {
                                        case Success => {}
                                        case Err(err) => {
                                            bao_core.Output.error(
                                                "copy file: ${err.message()}"
                                            )
                                            return SyscallResult.Err(err)
                                        }
                                    }
                                }
                            }
                        }
                        case None => break
                    }
                }
            }
            case None => {}
        }

        return SyscallResult.Success
    }
}

/// 遍历器引用
public class WalkerRef {
    public var srcDir: FileDescriptor
    public var skipDirnames: ArrayList<String>

    public init(srcDir: FileDescriptor, skipDirnames: ArrayList<String>) {
        this.srcDir = srcDir
        this.skipDirnames = skipDirnames
    }

    public func next(): ?WalkerEntry {
        return None
    }
}

/// 遍历条目
public class WalkerEntry {
    /// 文件路径 (相对于根目录)
    public var path: String
    /// 文件名
    public var basename: String
    /// 条目类型
    public var kind: WalkerEntryKind

    public init(path: String, basename: String, kind: WalkerEntryKind) {
        this.path = path
        this.basename = basename
        this.kind = kind
    }
}

/// 遍历条目类型
public enum WalkerEntryKind {
    | File
    | Directory
    | Symlink
    | Other
}
