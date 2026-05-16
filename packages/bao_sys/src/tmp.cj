// bao_sys - 临时文件
// 严格翻译自: src/sys/tmp.rs
//   Tmpfile 是一个临时文件结构，用于原子性地写入文件:
//   1. 创建临时文件
//   2. 写入数据
//   3. finish() 时原子性地重命名为目标文件
//   O_TMPFILE 不太可靠，默认禁用 (ALLOW_TMPFILE = false)
package bao_sys

import bao_core.*

// ============================================================================
// Tmpfile - 临时文件
// 严格翻译自: src/sys/tmp.rs:10-101
//   pub struct Tmpfile<'a> {
//       destination_dir: Fd,
//       tmpfilename: &'a ZStr,
//       fd: Fd,
//       using_tmpfile: bool,
//   }
// ============================================================================

/// 临时文件 - 严格对应 Bun Tmpfile
/// Bun: pub struct Tmpfile { destination_dir, tmpfilename, fd, using_tmpfile }
/// 用于原子性地写入文件: 创建临时文件 → 写入 → 重命名
public class Tmpfile {
    /// 目标目录 FD - 对应 Bun destination_dir
    public var destinationDir: Int64
    /// 临时文件名 - 对应 Bun tmpfilename
    public var tmpfilename: String
    /// 临时文件 FD - 对应 Bun fd
    public var fd: Int64
    /// 是否使用 O_TMPFILE - 对应 Bun using_tmpfile
    public var usingTmpfile: Bool

    /// O_TMPFILE 是否可用 - 对应 Bun ALLOW_TMPFILE
    /// linux_syscall.rs: O_TMPFILE doesn't seem to work very well
    public static let ALLOW_TMPFILE: Bool = false

    private init() {
        destinationDir = INVALID_FD
        tmpfilename = ""
        fd = INVALID_FD
        usingTmpfile = false
    }

    /// 创建临时文件 - 对应 Bun Tmpfile.create(destination_dir, tmpfilename)
    /// tmp.rs:20-68
    public static func create(destinationDir: Int64, tmpfilename: String): SysMaybe<Tmpfile> {
        let perm: UInt32 = 0o644
        let tmpfile = Tmpfile()
        tmpfile.destinationDir = destinationDir
        tmpfile.tmpfilename = tmpfilename
        tmpfile.fd = INVALID_FD
        tmpfile.usingTmpfile = ALLOW_TMPFILE

        // ALLOW_TMPFILE = false 的分支
        // 直接用 O_CREAT | O_CLOEXEC | O_WRONLY 创建命名临时文件
        if (ALLOW_TMPFILE) {
            // O_TMPFILE 分支 (禁用)
            let openResult = SysFs.open(tmpfilename,
                OpenFlags.WRONLY | OpenFlags.TMPFILE | OpenFlags.CLOEXEC, perm)
            match (openResult) {
                case Ok(fd) =>
                    tmpfile.fd = fd
                    return SysMaybe<Tmpfile>.Ok(tmpfile)
                case Err(e) =>
                    // EINVAL/ENOTSUP/ENOSYS: 不支持 O_TMPFILE
                    let errno = e.errno
                    if (errno == 22 || errno == 95 || errno == 38) {
                        tmpfile.usingTmpfile = false
                    } else {
                        return SysMaybe<Tmpfile>.Err(e)
                    }
            }
        }

        // 普通创建: O_CREAT | O_CLOEXEC | O_WRONLY
        let createResult = SysFs.open(tmpfilename,
            OpenFlags.CREAT | OpenFlags.CLOEXEC | OpenFlags.WRONLY, perm)
        match (createResult) {
            case Ok(fd) =>
                tmpfile.fd = fd
                return SysMaybe<Tmpfile>.Ok(tmpfile)
            case Err(e) =>
                return SysMaybe<Tmpfile>.Err(e)
        }
    }

    /// 完成写入，原子性重命名 - 对应 Bun Tmpfile.finish(destname)
    /// tmp.rs:71-101
    /// 将临时文件重命名为目标文件名
    public func finish(destName: String): SysMaybe<Unit> {
        // ALLOW_TMPFILE = false 时，走 rename 路径
        if (Tmpfile.ALLOW_TMPFILE && usingTmpfile) {
            // O_TMPFILE 分支: 使用 linkat (禁用)
            // 此分支在 Bun 中使用 linkat_tmpfile，但 ALLOW_TMPFILE = false
            // 永远不会执行
        }

        // 普通 rename 路径: 将 tmpfilename 重命名为 destName
        // 对应 Bun move_file_z_with_handle
        let renameResult = SysFs.rename(tmpfilename, destName)
        return renameResult
    }

    /// 关闭临时文件 (不重命名) - 清理用
    public func abort(): Unit {
        if (FdUtils.isValid(fd)) {
            let _ = SysFs.close(fd)
            fd = INVALID_FD
        }
        // 清理临时文件
        if (!tmpfilename.isEmpty()) {
            let _ = SysFs.unlink(tmpfilename)
        }
    }

    /// 析构 - 确保资源释放
    protected func finalize(): Unit {
        abort()
    }
}
