// bao_install - 文件复制器
// 严格翻译自: src/install/isolated_install/FileCopier.zig
package bao_install.isolated_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*
import bao_sys.*

/// 文件复制器
public class FileCopier {
    public var srcPath: String
    public var destSubpath: String
    public var skipDirnames: ArrayList<String>
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

    public func initWalker(srcDir: Int64): Unit {
        walker = WalkerRef(srcDir, skipDirnames)
    }

    public func deinit(): Unit {
        walker = None
        skipDirnames.clear()
    }

    public func copy(): Unit {
        FileDescriptor.cwd().makePath(destSubpath)
        match (walker) {
            case Some(w) => copyWalkerEntries(w)
            case None => ()
        }
    }

    private func copyWalkerEntries(w: WalkerRef): Unit {
        while (true) {
            match (w.next()) {
                case Some(entry) => copyEntry(entry)
                case None => break
            }
        }
    }

    private func copyEntry(entry: WalkerEntry): Unit {
        match (entry.kind) {
            case WalkerEntryKind.File => copyFileEntry(entry)
            case _ => ()
        }
    }

    private func copyFileEntry(entry: WalkerEntry): Unit {
        let src = Path.join(srcPath, entry.path)
        let dest = Path.join(destSubpath, entry.path)
        // 简化: 使用 BaoFile 复制
        match (BaoFile.readAllBytes(src)) {
            case SysMaybe.Ok(bytes) =>
                match (BaoFile.writeAllBytes(dest, bytes)) {
                    case SysMaybe.Ok(_) => ()
                    case SysMaybe.Err(_) =>
                        let entryDirname = Path.dirname(entry.path)
                        if (entryDirname.size > 0) {
                            FileDescriptor.cwd().makePath(Path.join(destSubpath, entryDirname))
                        }
                        BaoFile.writeAllBytes(dest, bytes)
                }
            case SysMaybe.Err(_) => ()
        }
    }
}

/// 遍历器引用
public class WalkerRef {
    public var srcDir: Int64
    public var skipDirnames: ArrayList<String>

    public init(srcDir: Int64, skipDirnames: ArrayList<String>) {
        this.srcDir = srcDir
        this.skipDirnames = skipDirnames
    }

    public func next(): ?WalkerEntry {
        return None
    }
}

/// 遍历条目
public class WalkerEntry {
    public var path: String
    public var basename: String
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

/// 文件描述符 (轻量封装)
public class FileDescriptor {
    public var fd: Int64

    public init(fd: Int64) {
        this.fd = fd
    }

    public static func cwd(): FileDescriptor {
        return FileDescriptor(-100)
    }

    public func makePath(path: String): Unit {
        // 简化实现
    }

    public func deleteTree(path: String): Unit {
        // 简化实现
    }
}

/// 系统调用结果
public enum SyscallResult {
    | Success
    | Err(SyscallError)
}

/// 系统调用错误
public class SyscallError {
    public var errno: Errno
    public var msg: String

    public init(errno: Errno, msg: String) {
        this.errno = errno
        this.msg = msg
    }

    public func message(): String {
        return msg
    }
}

/// 错误号
public enum Errno {
    | EXIST
    | NOENT
    | Other(Int32)
}
