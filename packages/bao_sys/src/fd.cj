// bao_sys - 文件描述符扩展
// 严格翻译自: src/sys/fd.rs
//   Fd 的系统调用相关扩展方法
//   fd.rs 定义了 FdExt trait，添加了与系统调用交互的方法
//   包括: close, makeLibUvOwned, makePathU8, deleteTree 等
//   以及 HashMapContext (FD 哈希), MovableIfWindowsFd 等
package bao_sys

import bao_core.*

// ============================================================================
// ErrorCase - close 行为枚举
// 严格翻译自: src/sys/fd.rs:24-28
//   pub enum ErrorCase { CloseOnFail, LeakFdOnFail }
//   用于 make_lib_uv_owned_for_syscall 中失败时的行为选择
// ============================================================================

/// FD 操作失败时的行为 - 对应 Bun ErrorCase
public enum ErrorCase {
    | CloseOnFail     // 失败时关闭 FD
    | LeakFdOnFail    // 失败时不关闭 (泄漏 FD)
}

// ============================================================================
// FdExt - 文件描述符扩展方法
// 严格翻译自: src/sys/fd.rs:45-302
//   FdExt trait 为 Fd 添加系统调用相关方法
//   fd function will NOT CLOSE stdin/stdout/stderr
// ============================================================================

/// 文件描述符扩展方法 - 对应 Bun FdExt
/// 提供安全的 close, makePath, deleteTree 等方法
public class FdExt {
    /// 安全关闭 - 对应 Bun FdExt.close(self)
    /// 不会关闭 stdin/stdout/stderr
    /// fd.zig:236: pub fn close(fd: FD) void
    public static func close(fd: Int64): Unit {
        // 不关闭标准 IO
        if (FdUtils.stdioTag(fd) != None) {
            return
        }
        closeAllowingBadFileDescriptor(fd)
    }

    /// 允许 EBADF 的关闭 - 对应 Bun closeAllowingBadFileDescriptor
    /// fd.zig: 用于 JS 提供的 fd，可能无效
    public static func closeAllowingBadFileDescriptor(fd: Int64): ?SysError {
        // 不关闭标准 IO
        if (FdUtils.stdioTag(fd) != None) {
            return None
        }
        return closeAllowingStandardIo(fd)
    }

    /// 允许关闭标准 IO - 对应 Bun closeAllowingStandardIo
    /// fd.zig: 原始 close 方法，返回错误
    public static func closeAllowingStandardIo(fd: Int64): ?SysError {
        if (!FdUtils.isValid(fd)) {
            return None
        }
        let rc = bao_sys.close(Int32(fd))
        if (rc != 0) {
            let errno = UInt16(Int64(OS.errno()))
            return Some(SysError(errno, SysTag.Close, fd))
        }
        return None
    }

    /// 创建路径 - 对应 Bun FdExt.makePathU8
    /// mkdir -p 语义，递归创建目录
    public static func makePath(fd: Int64, subPath: String): SysMaybe<Unit> {
        return mkdirRecursiveAt(fd, subPath)
    }

    /// 删除目录树 - 对应 Bun FdExt.deleteTree
    /// rm -rf 语义，递归删除
    public static func deleteTree(fd: Int64, subPath: String): SysMaybe<Unit> {
        return DirHelper.deleteTree(fd, subPath)
    }

    /// 转为 socket fd - 对应 Bun FdExt.asSocketFd
    public static func asSocketFd(fd: Int64): Int32 {
        return Int32(fd)
    }
}

// ============================================================================
// MovableFd - 可移动的 FD
// 严格翻译自: src/sys/fd.rs:397-490
//   MovableIfWindowsFd 在 Windows 上表示可能被移动到 libuv 的 FD
//   POSIX 上只是简单的 FD 包装
// ============================================================================

/// 可移动的 FD - 对应 Bun MovableIfWindowsFd
/// POSIX 上是简单的包装，Windows 上有移动语义
public class MovableFd {
    /// 底层 FD
    public var inner: Int64

    public init(fd: Int64) {
        this.inner = fd
    }

    /// 初始化 - 对应 Bun MovableIfWindowsFd.init(fd)
    public static func initFd(fd: Int64): MovableFd {
        return MovableFd(fd)
    }

    /// 获取 FD - 对应 Bun get()
    public func get(): ?Int64 {
        if (FdUtils.isValid(inner)) {
            return Some(inner)
        }
        return None
    }

    /// POSIX 获取 - 对应 Bun getPosix()
    public func getPosix(): Int64 {
        return inner
    }

    /// 关闭 - 对应 Bun close()
    public func close(): Unit {
        FdExt.close(inner)
        inner = INVALID_FD
    }

    /// 是否有效 - 对应 Bun isValid()
    public func isValid(): Bool {
        return FdUtils.isValid(inner)
    }

    /// 是否拥有 - 对应 Bun isOwned()
    /// POSIX 上总是 true
    public func isOwned(): Bool {
        return true
    }
}

// ============================================================================
// HashMapContext - FD 哈希上下文
// 严格翻译自: src/sys/fd.rs:342-386
//   用于以 FD 为键的 HashMap
//   hash(fd) 将 c_int 扩展为 u64
// ============================================================================

/// FD 哈希上下文 - 对应 Bun HashMapContext
/// 提供以 FD 为键的哈希函数
public class FdHashMapContext {
    /// 哈希 FD - 对应 Bun HashMapContext.hash(fd)
    /// fd 是 i32，零开销扩展为 u64
    public static func hash(fd: Int64): UInt64 {
        return UInt64(Int64(fd) & 0xFFFFFFFF)
    }

    /// 比较 FD - 对应 Bun HashMapContext.eql(a, b)
    public static func eql(a: Int64, b: Int64): Bool {
        return a == b
    }
}

/// 预哈希值 - 对应 Bun Prehashed
/// 缓存哈希值避免重复计算
public class PrehashedFd {
    public let value: UInt64
    public let input: Int64

    public init(fd: Int64) {
        this.input = fd
        this.value = FdHashMapContext.hash(fd)
    }

    public func hash(fd: Int64): UInt64 {
        if (fd == input) {
            return value
        }
        return FdHashMapContext.hash(fd)
    }

    public func eql(a: Int64, b: Int64): Bool {
        return a == b
    }
}

// ============================================================================
// DirHelper - 目录辅助操作
// 严格翻译自: src/sys/fd.rs 和 src/sys/dir.rs
//   提供递归目录创建和删除
// ============================================================================

/// 目录辅助操作
public class DirHelper {
    /// 递归创建目录 - 对应 Bun mkdir_recursive_at
    /// mkdir -p 语义: 逐级创建不存在的目录
    public static func mkdirRecursiveAt(dirFd: Int64, subPath: String): SysMaybe<Unit> {
        // 分割路径为各个部分
        let parts = subPath.split('/')
        var currentPath = StringBuilder()
        for (i in 0..parts.size) {
            let part = parts[Int64(i)]
            if (part.isEmpty()) { continue }
            if (currentPath.size > 0) {
                currentPath.append("/")
            }
            currentPath.append(part)
            let path = currentPath.toString()
            // 尝试创建，忽略 EEXIST
            let result = SysFs.mkdir(path, FileMode.DIR)
            match (result) {
                case Err(e) =>
                    // EEXIST (17) 可以忽略
                    if (e.errno != 17) {
                        return SysMaybe<Unit>.Err(e)
                    }
                case _ => continue
            }
        }
        return SysMaybe<Unit>.Ok(())
    }

    /// 递归删除目录树 - 对应 Bun Dir.deleteTree
    /// rm -rf 语义: 先尝试 unlink，如果是目录则递归
    public static func deleteTree(parentFd: Int64, subPath: String): SysMaybe<Unit> {
        // 先尝试作为文件删除
        let unlinkResult = SysFs.unlink(subPath)
        match (unlinkResult) {
            case Ok(_) => return SysMaybe<Unit>.Ok(())
            case Err(e) =>
                // ENOENT - 不存在，完成
                if (e.errno == 2) {
                    return SysMaybe<Unit>.Ok(())
                }
                // EISDIR (21) 或 EPERM (1) - 是目录，需要递归
                if (e.errno != 21 && e.errno != 1) {
                    return SysMaybe<Unit>.Err(e)
                }
        }

        // 是目录，列出内容并递归删除
        let iterResult = DirIterator.open(subPath)
        match (iterResult) {
            case Err(e) => return SysMaybe<Unit>.Err(e)
            case Ok(iter) =>
                while (true) {
                    let entry = iter.next()
                    match (entry) {
                        case None => break
                        case Some(e) =>
                            let fullPath = Path.join([subPath, e.name])
                            if (e.isDirectory()) {
                                let subResult = deleteTree(parentFd, fullPath)
                                match (subResult) {
                                    case Err(err) =>
                                        iter.close()
                                        return SysMaybe<Unit>.Err(err)
                                    case _ => continue
                                }
                            } else {
                                let _ = SysFs.unlink(fullPath)
                            }
                    }
                }
                iter.close()

                // 删除空目录
                let rmdirResult = SysFs.rmdir(subPath)
                match (rmdirResult) {
                    case Err(e) =>
                        // ENOENT 可以忽略
                        if (e.errno != 2) {
                            return SysMaybe<Unit>.Err(e)
                        }
                    case _ => {}
                }
                return SysMaybe<Unit>.Ok(())
        }
    }
}
