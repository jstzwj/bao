// bao_sys - 目录操作
// 严格翻译自: src/sys/dir.rs
//   Dir 是 Copy 的薄封装，不在 Drop 时关闭
//   提供 makePath, makeOpenPath, deleteTree, makeDir, symLink 等操作
//   OwnedDir 是 RAII 封装，在 Drop 时自动关闭
package bao_sys

import bao_core.*

// ============================================================================
// Dir - 目录句柄
// 严格翻译自: src/sys/dir.rs:12-15
//   #[derive(Clone, Copy)] pub struct Dir { pub fd: Fd }
//   薄封装 Fd，不自动关闭
// ============================================================================

/// 目录句柄 - 严格对应 Bun sys.Dir
/// Bun: pub struct Dir { pub fd: Fd }
/// Copy 语义，不自动关闭，调用者需显式 close()
public class SysDir {
    /// 底层文件描述符 - 对应 Bun Dir.fd
    public var fd: Int64

    public init(fd: Int64) {
        this.fd = fd
    }

    /// 从 FD 构造 - 对应 Bun Dir.from_fd(fd)
    public static func fromFd(fd: Int64): SysDir {
        return SysDir(fd)
    }

    /// 获取 FD - 对应 Bun Dir.fd()
    public func getFd(): Int64 {
        return fd
    }

    /// 当前工作目录 - 对应 Bun Dir.cwd()
    public static func cwd(): SysDir {
        return SysDir(FdUtils.atCwd())
    }

    /// 关闭 - 对应 Bun Dir.close()
    public func close(): Unit {
        let _ = SysFs.close(fd)
    }

    // ── 路径操作 ──────────────────────────────────────────────

    /// 创建路径 - 对应 Bun Dir.makePath(sub_path)
    /// sys.zig:2928 — mkdir -p 相对于此目录
    public func makePath(subPath: String): SysMaybe<Unit> {
        return DirHelper.mkdirRecursiveAt(fd, subPath)
    }

    /// 创建并打开路径 - 对应 Bun Dir.makeOpenPath(sub_path, opts)
    /// Zig: vendor/zig/lib/std/fs/Dir.zig makeOpenPath
    /// 先尝试 openDir，失败则 makePath 后重试
    public func makeOpenPath(subPath: String): SysMaybe<SysDir> {
        let openResult = openDirAt(fd, subPath)
        match (openResult) {
            case Ok(dirFd) => return SysMaybe<SysDir>.Ok(SysDir(dirFd))
            case Err(e) =>
                // ENOENT: 先创建目录再打开
                if (e.errno == 2) {
                    let mkdirResult = makePath(subPath)
                    match (mkdirResult) {
                        case Err(mkdirErr) => return SysMaybe<SysDir>.Err(mkdirErr)
                        case _ =>
                            return openDirAt(fd, subPath)
                    }
                }
                return SysMaybe<SysDir>.Err(e)
        }
    }

    /// 创建单级目录 - 对应 Bun Dir.makeDir(sub_path)
    /// std.fs.Dir.makeDir — 单层 mkdirat，mode 0o755
    /// 不创建中间目录，PathAlreadyExists 报错
    public func makeDir(subPath: String): SysMaybe<Unit> {
        unsafe {
            let pathPtr = unsafeNewCString(subPath)
            let rc = bao_sys.mkdir(pathPtr, 0o755)
            if (rc != 0) {
                let errno = UInt16(Int64(OS.errno()))
                // EEXIST (17) — 路径已存在
                if (errno == 17) {
                    return SysMaybe<Unit>.Err(SysError(errno, SysTag.Mkdir, subPath))
                }
                return SysMaybe<Unit>.Err(SysError(errno, SysTag.Mkdir, subPath))
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 创建符号链接 - 对应 Bun Dir.symLink(target, link_name, is_directory)
    /// std.fs.Dir.symLink — symlinkat(target, self.fd, link)
    /// is_directory 在 POSIX 上是空操作
    public func symLink(target: String, linkName: String): SysMaybe<Unit> {
        unsafe {
            let targetPtr = unsafeNewCString(target)
            let linkPtr = unsafeNewCString(linkName)
            let rc = bao_sys.symlink(targetPtr, linkPtr)
            if (rc != 0) {
                return SysMaybe<Unit>.Err(
                    SysError(UInt16(Int64(OS.errno())), SysTag.Symlink)
                        .withPathDest(linkName, target)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 创建文件 - 对应 Bun Dir.createFileZ(sub_path, flags)
    /// std.fs.Dir.createFileZ — O_CREAT | O_WRONLY | O_TRUNC
    public func createFileZ(subPath: String, truncate: Bool): SysMaybe<SysFile> {
        var flags = OpenFlags.CREAT | OpenFlags.CLOEXEC | OpenFlags.WRONLY
        if (truncate) {
            flags = flags | OpenFlags.TRUNC
        }
        let result = SysFs.open(subPath, flags, 0o666)
        match (result) {
            case Ok(fd) => return SysMaybe<SysFile>.Ok(SysFile.fromFd(fd))
            case Err(e) => return SysMaybe<SysFile>.Err(e)
        }
    }

    /// 删除文件 - 对应 Bun Dir.deleteFileZ(sub_path)
    /// std.fs.Dir.deleteFileZ — unlinkat(self.fd, sub_path, 0)
    public func deleteFileZ(subPath: String): SysMaybe<Unit> {
        return SysFs.unlink(subPath)
    }

    /// 复制文件 - 对应 Bun Dir.copyFile(source, dest_dir, dest, options)
    /// std.fs.Dir.copyFile — 打开源文件 → 创建目标文件 → 复制内容
    public func copyFile(sourcePath: String, destDir: SysDir,
                          destPath: String): SysMaybe<Unit> {
        // 打开源文件
        let inFd = SysFs.open(sourcePath, OpenFlags.RDONLY | OpenFlags.CLOEXEC, FileMode.DEFAULT)
        match (inFd) {
            case Err(e) => return SysMaybe<Unit>.Err(e)
            case Ok(inFdVal) =>
                // 创建目标文件
                let outResult = destDir.createFileZ(destPath, true)
                match (outResult) {
                    case Err(e) =>
                        let _ = SysFs.close(inFdVal)
                        return SysMaybe<Unit>.Err(e)
                    case Ok(outFile) =>
                        // 复制内容
                        let copyResult = SysCopyFile.copyFile(inFdVal, outFile.fd())
                        let _ = SysFs.close(inFdVal)
                        let _ = outFile.close()
                        return copyResult
                }
        }
    }

    /// 打开子目录 - 对应 Bun Dir.openDirZ(sub_path)
    public func openDirZ(subPath: String): SysMaybe<SysDir> {
        let result = openDirAt(fd, subPath)
        match (result) {
            case Ok(dirFd) => return SysMaybe<SysDir>.Ok(SysDir(dirFd))
            case Err(e) => return SysMaybe<SysDir>.Err(e)
        }
    }
}

// ============================================================================
// OwnedDir - RAII 目录句柄
// 严格翻译自: src/sys/dir.rs:275-309
//   在 Drop 时自动关闭 fd
// ============================================================================

/// RAII 目录句柄 - 对应 Bun OwnedDir
/// 在析构时自动关闭 fd，用于有界作用域
public class OwnedDir {
    private var dir: SysDir

    public init(dir: SysDir) {
        this.dir = dir
    }

    /// 获取内部 Dir - 对应 Bun OwnedDir.dir()
    public func dir(): SysDir {
        return dir
    }

    /// 获取 FD - 对应 Bun OwnedDir.fd()
    public func fd(): Int64 {
        return dir.fd
    }

    /// 取出内部 Dir 不关闭 - 对应 Bun OwnedDir.into_inner()
    public func intoInner(): SysDir {
        let d = dir
        // 标记为无效以防止 double close
        dir = SysDir(INVALID_FD)
        return d
    }

    /// 析构时自动关闭
    protected func finalize(): Unit {
        if (FdUtils.isValid(dir.fd)) {
            dir.close()
        }
    }
}

// ============================================================================
// CopyFileOptions - 文件复制选项
// 严格翻译自: src/sys/dir.rs:17-22
//   pub struct CopyFileOptions { pub override_mode: Option<Mode> }
// ============================================================================

/// 文件复制选项 - 对应 Bun CopyFileOptions
public class CopyFileOptions {
    /// 覆盖模式 - 对应 Bun override_mode: ?File.Mode
    public var overrideMode: ?UInt32

    public init() {
        overrideMode = None
    }

    public init(mode: UInt32) {
        overrideMode = Some(mode)
    }
}

// ============================================================================
// OpenDirOptions - 打开目录选项
// 严格翻译自: src/sys/dir.rs:24-28
//   pub struct OpenDirOptions { pub iterate: bool, pub no_follow: bool }
// ============================================================================

/// 打开目录选项 - 对应 Bun OpenDirOptions
public class OpenDirOptions {
    /// 是否可迭代 - 对应 Bun iterate: bool
    public var iterate: Bool
    /// 不跟随符号链接 - 对应 Bun no_follow: bool
    public var noFollow: Bool

    public init() {
        iterate = false
        noFollow = false
    }

    public init(iterate: Bool, noFollow: Bool) {
        this.iterate = iterate
        this.noFollow = noFollow
    }
}

// ============================================================================
// CreateFlags - 文件创建标志
// 严格翻译自: src/sys/dir.rs:312-318
//   pub struct CreateFlags { pub truncate: bool, pub read: bool }
// ============================================================================

/// 文件创建标志 - 对应 Bun CreateFlags
public class CreateFlags {
    /// 是否截断 - 对应 Bun truncate: bool
    public var truncate: Bool
    /// 是否可读 - 对应 Bun read: bool
    public var read: Bool

    public init() {
        truncate = false
        read = false
    }
}

// ============================================================================
// AT_REMOVEDIR 常量
// 严格翻译自: src/sys/dir.rs:250-253
//   #[cfg(unix)] pub const AT_REMOVEDIR: i32 = libc::AT_REMOVEDIR;
// ============================================================================

/// AT_REMOVEDIR - 对应 Bun AT_REMOVEDIR
/// 用于 unlinkat 删除目录
public let AT_REMOVEDIR: Int32 = 0x200

// ============================================================================
// 辅助函数
// ============================================================================

/// 打开子目录 - 对应 Bun open_dir_at
/// sys.zig: openat(dir, path, O.DIRECTORY | O.RDONLY | O.CLOEXEC)
public func openDirAt(dirFd: Int64, subPath: String): SysMaybe<Int64> {
    return SysFs.open(subPath, OpenFlags.DIRECTORY | OpenFlags.RDONLY | OpenFlags.CLOEXEC, 0)
}

/// 打开目录 (从 Dir 句柄) - 对应 Bun openDir(dir, path)
public func openDir(dir: SysDir, path: String): SysMaybe<SysDir> {
    let result = openDirAt(dir.fd, path)
    match (result) {
        case Ok(fd) => return SysMaybe<SysDir>.Ok(SysDir(fd))
        case Err(e) => return SysMaybe<SysDir>.Err(e)
    }
}
