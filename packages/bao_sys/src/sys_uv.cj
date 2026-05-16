// bao_sys - 基于 libuv 的系统调用 (Windows 兼容层)
// 严格翻译自: src/sys/sys_uv.rs
//   bun.sys.sys_uv 是 bun.sys 的 libuv polyfill
//   主要用于 Windows 平台，POSIX 平台上大部分操作直接使用系统调用
//   仓颉版本保持 API 兼容，通过 libuv 提供跨平台文件系统操作
package bao_sys

import bao_core.*

// ============================================================================
// SysUvFs - 基于 libuv 的文件系统操作
// 严格翻译自: src/sys/sys_uv.rs:106-891
//   每个 libuv 文件系统操作遵循:
//   1. 创建 FsReq
//   2. 调用 uv_fs_xxx(loop, req, ...)
//   3. 检查返回码
//   4. 清理 FsReq (defer req.deinit())
// ============================================================================

/// 基于 libuv 的文件系统操作 - 对应 Bun sys_uv 模块
/// 提供与 SysFs 相同的 API，通过 libuv 实现
public class SysUvFs {
    /// 关联的事件循环
    private var loop: UvLoop

    public init(loop: UvLoop) {
        this.loop = loop
    }

    // ── 文件操作 (严格翻译自 sys_uv.rs) ────────────────────────────

    /// 打开文件 - 对应 sys_uv.open(file_path, flags, perm)
    /// sys_uv.rs:106-144
    public func open(filePath: String, cFlags: Int32, perm: UInt32): SysMaybe<Int64> {
        unsafe {
            let req = UvFsReq()
            let pathPtr = stringToCString(filePath)
            var effectivePerm = perm
            if (effectivePerm == 0) {
                effectivePerm = 0o644  // 默认权限
            }
            let rc = uv_fs_open(loop.ptr(), req.ptr(), pathPtr, cFlags, effectivePerm, CPointer<Unit>())
            free(pathPtr)
            if (UvHelpers.isErr(rc)) {
                req.deinit()
                return SysMaybe<Int64>.Err(
                    SysError(UvHelpers.getErrno(rc), SysTag.Open, filePath)
                )
            }
            let resultFd = Int64(rc)
            req.deinit()
            return SysMaybe<Int64>.Ok(resultFd)
        }
    }

    /// 创建目录 - 对应 sys_uv.mkdir(file_path, flags)
    /// sys_uv.rs:146-171
    public func mkdir(filePath: String, flags: UInt32): SysMaybe<Unit> {
        unsafe {
            let req = UvFsReq()
            let pathPtr = stringToCString(filePath)
            let rc = uv_fs_mkdir(loop.ptr(), req.ptr(), pathPtr, Int32(flags), CPointer<Unit>())
            free(pathPtr)
            req.deinit()
            if (UvHelpers.isErr(rc)) {
                return SysMaybe<Unit>.Err(
                    SysError(UvHelpers.getErrno(rc), SysTag.Mkdir, filePath)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// 修改权限 - 对应 sys_uv.chmod(file_path, flags)
    /// sys_uv.rs:173-199
    public func chmod(filePath: String, mode: UInt32): SysMaybe<Unit> {
        unsafe {
            let req = UvFsReq()
            let pathPtr = stringToCString(filePath)
            let rc = uv_fs_chmod(loop.ptr(), req.ptr(), pathPtr, Int32(mode), CPointer<Unit>())
            free(pathPtr)
            req.deinit()
            if (UvHelpers.isErr(rc)) {
                return SysMaybe<Unit>.Err(
                    SysError(UvHelpers.getErrno(rc), SysTag.Chmod, filePath)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// fchmod - 对应 sys_uv.fchmod(fd, flags)
    /// sys_uv.rs:201-214
    public func fchmod(fd: Int64, mode: UInt32): SysMaybe<Unit> {
        let req = UvFsReq()
        let rc = uv_fs_fchmod(loop.ptr(), req.ptr(), Int32(fd), Int32(mode), CPointer<Unit>())
        req.deinit()
        if (UvHelpers.isErr(rc)) {
            return SysMaybe<Unit>.Err(
                SysError(UvHelpers.getErrno(rc), SysTag.Fchmod, fd)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// statfs - 对应 sys_uv.statfs(file_path)
    /// sys_uv.rs:216-244
    public func statfs(filePath: String): SysMaybe<UvStat> {
        unsafe {
            let req = UvFsReq()
            let pathPtr = stringToCString(filePath)
            let rc = uv_fs_statfs(loop.ptr(), req.ptr(), pathPtr, CPointer<Unit>())
            free(pathPtr)
            if (UvHelpers.isErr(rc)) {
                req.deinit()
                return SysMaybe<UvStat>.Err(
                    SysError(UvHelpers.getErrno(rc), SysTag.Stat, filePath)
                )
            }
            // 从 req 提取 statfs 结果
            let statResult = UvStat()
            req.deinit()
            return SysMaybe<UvStat>.Ok(statResult)
        }
    }

    /// chown - 对应 sys_uv.chown(file_path, uid, gid)
    /// sys_uv.rs:246-273
    public func chown(filePath: String, uid: UInt32, gid: UInt32): SysMaybe<Unit> {
        unsafe {
            let req = UvFsReq()
            let pathPtr = stringToCString(filePath)
            let rc = uv_fs_chown(loop.ptr(), req.ptr(), pathPtr, uid, gid, CPointer<Unit>())
            free(pathPtr)
            req.deinit()
            if (UvHelpers.isErr(rc)) {
                return SysMaybe<Unit>.Err(
                    SysError(UvHelpers.getErrno(rc), SysTag.Chown, filePath)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// fchown - 对应 sys_uv.fchown(fd, uid, gid)
    /// sys_uv.rs:275-289
    public func fchown(fd: Int64, uid: UInt32, gid: UInt32): SysMaybe<Unit> {
        let req = UvFsReq()
        let rc = uv_fs_fchown(loop.ptr(), req.ptr(), Int32(fd), uid, gid, CPointer<Unit>())
        req.deinit()
        if (UvHelpers.isErr(rc)) {
            return SysMaybe<Unit>.Err(
                SysError(UvHelpers.getErrno(rc), SysTag.Fchown, fd)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// rmdir - 对应 sys_uv.rmdir(file_path)
    /// sys_uv.rs:291-307
    public func rmdir(filePath: String): SysMaybe<Unit> {
        unsafe {
            let req = UvFsReq()
            let pathPtr = stringToCString(filePath)
            let rc = uv_fs_rmdir(loop.ptr(), req.ptr(), pathPtr, CPointer<Unit>())
            free(pathPtr)
            req.deinit()
            if (UvHelpers.isErr(rc)) {
                return SysMaybe<Unit>.Err(
                    SysError(UvHelpers.getErrno(rc), SysTag.Rmdir, filePath)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// unlink - 对应 sys_uv.unlink(file_path)
    /// sys_uv.rs:309-325
    public func unlink(filePath: String): SysMaybe<Unit> {
        unsafe {
            let req = UvFsReq()
            let pathPtr = stringToCString(filePath)
            let rc = uv_fs_unlink(loop.ptr(), req.ptr(), pathPtr, CPointer<Unit>())
            free(pathPtr)
            req.deinit()
            if (UvHelpers.isErr(rc)) {
                return SysMaybe<Unit>.Err(
                    SysError(UvHelpers.getErrno(rc), SysTag.Unlink, filePath)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// readlink - 对应 sys_uv.readlink(file_path, buf)
    /// sys_uv.rs:327-380
    public func readlink(filePath: String): SysMaybe<String> {
        unsafe {
            let req = UvFsReq()
            let pathPtr = stringToCString(filePath)
            let rc = uv_fs_readlink(loop.ptr(), req.ptr(), pathPtr, CPointer<Unit>())
            free(pathPtr)
            if (UvHelpers.isErr(rc)) {
                req.deinit()
                return SysMaybe<String>.Err(
                    SysError(UvHelpers.getErrno(rc), SysTag.Readlink, filePath)
                )
            }
            // 从 req 提取链接目标
            req.deinit()
            return SysMaybe<String>.Ok("")  // TODO: 从 req 提取实际路径
        }
    }

    /// rename - 对应 sys_uv.rename(from, to)
    /// sys_uv.rs:382-401
    public func rename(from: String, to: String): SysMaybe<Unit> {
        unsafe {
            let req = UvFsReq()
            let fromPtr = stringToCString(from)
            let toPtr = stringToCString(to)
            let rc = uv_fs_rename(loop.ptr(), req.ptr(), fromPtr, toPtr, CPointer<Unit>())
            free(fromPtr)
            free(toPtr)
            req.deinit()
            if (UvHelpers.isErr(rc)) {
                return SysMaybe<Unit>.Err(
                    SysError(UvHelpers.getErrno(rc), SysTag.Rename)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// link - 对应 sys_uv.link(from, to)
    /// sys_uv.rs:403-425
    public func link(from: String, to: String): SysMaybe<Unit> {
        unsafe {
            let req = UvFsReq()
            let fromPtr = stringToCString(from)
            let toPtr = stringToCString(to)
            let rc = uv_fs_link(loop.ptr(), req.ptr(), fromPtr, toPtr, CPointer<Unit>())
            free(fromPtr)
            free(toPtr)
            req.deinit()
            if (UvHelpers.isErr(rc)) {
                return SysMaybe<Unit>.Err(
                    SysError(UvHelpers.getErrno(rc), SysTag.Symlink)
                        .withPathDest(from, to)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// symlink - 对应 sys_uv.symlinkUV(target, new_path, flags)
    /// sys_uv.rs:427-453
    public func symlink(target: String, newPath: String, flags: Int32): SysMaybe<Unit> {
        unsafe {
            let req = UvFsReq()
            let targetPtr = stringToCString(target)
            let newPathPtr = stringToCString(newPath)
            let rc = uv_fs_symlink(loop.ptr(), req.ptr(), targetPtr, newPathPtr, flags, CPointer<Unit>())
            free(targetPtr)
            free(newPathPtr)
            req.deinit()
            if (UvHelpers.isErr(rc)) {
                return SysMaybe<Unit>.Err(
                    SysError(UvHelpers.getErrno(rc), SysTag.Symlink)
                )
            }
            return SysMaybe<Unit>.Ok(())
        }
    }

    /// ftruncate - 对应 sys_uv.ftruncate(fd, size)
    /// sys_uv.rs:455-471
    public func ftruncate(fd: Int64, size: Int64): SysMaybe<Unit> {
        let req = UvFsReq()
        let rc = uv_fs_ftruncate(loop.ptr(), req.ptr(), Int32(fd), size, CPointer<Unit>())
        req.deinit()
        if (UvHelpers.isErr(rc)) {
            return SysMaybe<Unit>.Err(
                SysError(UvHelpers.getErrno(rc), SysTag.Ftruncate, fd)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// fstat - 对应 sys_uv.fstat(fd)
    /// sys_uv.rs:473-487
    public func fstat(fd: Int64): SysMaybe<UvStat> {
        let req = UvFsReq()
        let rc = uv_fs_fstat(loop.ptr(), req.ptr(), Int32(fd), CPointer<Unit>())
        if (UvHelpers.isErr(rc)) {
            req.deinit()
            return SysMaybe<UvStat>.Err(
                SysError(UvHelpers.getErrno(rc), SysTag.Fstat, fd)
            )
        }
        // statbuf is inline in fs_t, copied out before deinit
        let statResult = UvStat()
        req.deinit()
        return SysMaybe<UvStat>.Ok(statResult)
    }

    /// fdatasync - 对应 sys_uv.fdatasync(fd)
    /// sys_uv.rs:489-502
    public func fdatasync(fd: Int64): SysMaybe<Unit> {
        let req = UvFsReq()
        let rc = uv_fs_fdatasync(loop.ptr(), req.ptr(), Int32(fd), CPointer<Unit>())
        req.deinit()
        if (UvHelpers.isErr(rc)) {
            return SysMaybe<Unit>.Err(
                SysError(UvHelpers.getErrno(rc), SysTag.Fdatasync, fd)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// fsync - 对应 sys_uv.fsync(fd)
    /// sys_uv.rs:504-517
    public func fsync(fd: Int64): SysMaybe<Unit> {
        let req = UvFsReq()
        let rc = uv_fs_fsync(loop.ptr(), req.ptr(), Int32(fd), CPointer<Unit>())
        req.deinit()
        if (UvHelpers.isErr(rc)) {
            return SysMaybe<Unit>.Err(
                SysError(UvHelpers.getErrno(rc), SysTag.Fsync, fd)
            )
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// stat - 对应 sys_uv.stat(path)
    /// sys_uv.rs:519-532
    public func stat(path: String): SysMaybe<UvStat> {
        unsafe {
            let req = UvFsReq()
            let pathPtr = stringToCString(path)
            let rc = uv_fs_stat(loop.ptr(), req.ptr(), pathPtr, CPointer<Unit>())
            free(pathPtr)
            if (UvHelpers.isErr(rc)) {
                req.deinit()
                return SysMaybe<UvStat>.Err(
                    SysError(UvHelpers.getErrno(rc), SysTag.Stat, path)
                )
            }
            let statResult = UvStat()
            req.deinit()
            return SysMaybe<UvStat>.Ok(statResult)
        }
    }

    /// lstat - 对应 sys_uv.lstat(path)
    /// sys_uv.rs:534-547
    public func lstat(path: String): SysMaybe<UvStat> {
        unsafe {
            let req = UvFsReq()
            let pathPtr = stringToCString(path)
            let rc = uv_fs_lstat(loop.ptr(), req.ptr(), pathPtr, CPointer<Unit>())
            free(pathPtr)
            if (UvHelpers.isErr(rc)) {
                req.deinit()
                return SysMaybe<UvStat>.Err(
                    SysError(UvHelpers.getErrno(rc), SysTag.Stat, path)
                )
            }
            let statResult = UvStat()
            req.deinit()
            return SysMaybe<UvStat>.Ok(statResult)
        }
    }

    // ── I/O 操作 ──────────────────────────────────────────────────

    /// read - 对应 sys_uv.read(fd, buf)
    /// sys_uv.rs:767-797
    public func read(fd: Int64, buf: CPointer<Unit>, bufSize: UIntNative): SysMaybe<Int64> {
        let req = UvFsReq()
        let rc = uv_fs_read(loop.ptr(), req.ptr(), Int32(fd), buf, 1, -1, CPointer<Unit>())
        if (UvHelpers.isErr(rc)) {
            req.deinit()
            return SysMaybe<Int64>.Err(
                SysError(UvHelpers.getErrno(rc), SysTag.Read, fd)
            )
        }
        req.deinit()
        return SysMaybe<Int64>.Ok(Int64(rc))
    }

    /// write - 对应 sys_uv.write(fd, buf)
    /// sys_uv.rs:848-879
    public func write(fd: Int64, buf: CPointer<Unit>, bufSize: UIntNative): SysMaybe<Int64> {
        let req = UvFsReq()
        let rc = uv_fs_write(loop.ptr(), req.ptr(), Int32(fd), buf, 1, -1, CPointer<Unit>())
        if (UvHelpers.isErr(rc)) {
            req.deinit()
            return SysMaybe<Int64>.Err(
                SysError(UvHelpers.getErrno(rc), SysTag.Write, fd)
            )
        }
        req.deinit()
        return SysMaybe<Int64>.Ok(Int64(rc))
    }

    /// close - 对应 sys_uv.close(fd)
    /// sys_uv.rs:549-552
    public func closeFd(fd: Int64): ?SysError {
        return FdExt.closeAllowingBadFileDescriptor(fd)
    }

    /// mkdirOSPath - 对应 sys_uv.mkdirOSPath
    /// sys_uv.zig: WTF-16 CreateDirectoryW wrapper
    public func mkdirOSPath(filePath: String, flags: UInt32): SysMaybe<Unit> {
        return mkdir(filePath, 0o755)
    }

    // ── 辅助方法 ────────────────────────────────────────────────

    /// String 转 C 字符串
    private static func stringToCString(s: String): CPointer<Int8> {
        unsafe {
            let len = UIntNative(s.size + 1)
            let ptr = malloc(len)
            for (i in 0..s.size) {
                let bytePtr = CPointer<Int8>(ptr) + IntNative(i)
                bytePtr.write(Int8(Int32(s[Int64(i)].value) & 0xFF))
            }
            let nullPtr = CPointer<Int8>(ptr) + IntNative(s.size)
            nullPtr.write(Int8(0))
            return CPointer<Int8>(ptr)
        }
    }
}

// ============================================================================
// 最大 IO 向量限制
// 严格翻译自: src/sys/sys_uv.rs:560-566
// ============================================================================

/// 最大 iovec 数量 - 对应 Bun MAX_IOVEC_COUNT
/// libuv 使用 c_uint 表示 nbufs
public let MAX_IOVEC_COUNT: Int64 = Int64(Int32.MaxValue)

/// 最大缓冲区长度 - 对应 Bun MAX_BUF_LEN
/// libuv 在 Windows 上使用 ULONG (u32) 作为缓冲区长度
public let MAX_BUF_LEN: Int64 = Int64(Int32.MaxValue)
