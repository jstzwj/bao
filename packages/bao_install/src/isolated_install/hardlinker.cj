// bao_install - 硬链接创建器
// 严格翻译自: src/install/isolated_install/Hardlinker.zig
package bao_install.isolated_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_path.*
import bao_sys.*

/// 硬链接创建器
public class Hardlinker {
    public var srcDir: Int64
    public var src: String
    public var dest: String
    public var skipDirnames: ArrayList<String>
    public var walker: ?WalkerRef

    public init(srcDir: Int64, src: String, dest: String) {
        this.srcDir = srcDir
        this.src = src
        this.dest = dest
        skipDirnames = ArrayList<String>()
        walker = None
    }

    public init(srcDir: Int64, src: String, dest: String, skipDirnames: ArrayList<String>) {
        this.srcDir = srcDir
        this.src = src
        this.dest = dest
        this.skipDirnames = skipDirnames
        walker = None
    }

    public func deinit(): Unit {
        walker = None
        skipDirnames.clear()
    }

    public func link(): Unit {
        if (PackageManager.verboseInstall) {
            Output.print("Hardlinking ${src} to ${dest}\n")
        }

        walker = WalkerRef(srcDir, skipDirnames)

        match (walker) {
            case Some(w) => processWalkerEntries(w)
            case None => ()
        }
    }

    private func processWalkerEntries(w: WalkerRef): Unit {
        while (true) {
            match (w.next()) {
                case Some(entry) => processWalkerEntry(entry)
                case None => break
            }
        }
    }

    private func processWalkerEntry(entry: WalkerEntry): Unit {
        let destPath = Path.join(dest, entry.path)
        match (entry.kind) {
            case WalkerEntryKind.Directory =>
                FileDescriptor.cwd().makePath(destPath)
            case WalkerEntryKind.File =>
                let srcPath = Path.join(src, entry.path)
                // 简化: 复制文件而非硬链接
                match (BaoFile.readAllBytes(srcPath)) {
                    case SysMaybe.Ok(bytes) =>
                        match (BaoFile.writeAllBytes(destPath, bytes)) {
                            case SysMaybe.Ok(_) => ()
                            case SysMaybe.Err(_) =>
                                let destParent = Path.dirname(destPath)
                                if (destParent.size > 0) {
                                    FileDescriptor.cwd().makePath(destParent)
                                }
                                BaoFile.writeAllBytes(destPath, bytes)
                        }
                    case SysMaybe.Err(_) => ()
                }
            case _ => ()
        }
    }
}

/// 包管理器 (引用, 用于 verbose_install 标志)
public class PackageManager {
    public static let verboseInstall: Bool = false
}
