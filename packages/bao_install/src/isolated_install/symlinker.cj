// bao_install - 符号链接创建器
// 严格翻译自: src/install/isolated_install/Symlinker.zig
//   Symlinker 负责创建符号链接, 包含三种策略:
//     expect_existing: 预期目标已存在
//     expect_missing: 预期目标不存在
//     ignore_failure: 忽略失败
package bao_install.isolated_install

import bao_core.*
import bao_io.*
import bao_path.*

// ============================================================================
// 符号链接策略
// 严格翻译自: src/install/isolated_install/Symlinker.zig
//   pub const Strategy = enum { expect_existing, expect_missing, ignore_failure }
// ============================================================================

/// 符号链接策略
/// 对应 Bun: Symlinker.Strategy
public enum SymlinkStrategy {
    | ExpectExisting    // 预期目标已存在
    | ExpectMissing     // 预期目标不存在
    | IgnoreFailure     // 忽略失败
}

// ============================================================================
// 符号链接创建器
// 严格翻译自: src/install/isolated_install/Symlinker.zig
//   pub const Symlinker = struct {
//       dest: bun.Path, target: bun.RelPath, fallback_junction_target: bun.AbsPath
//   }
// ============================================================================

/// 符号链接创建器
/// 对应 Bun: Symlinker
/// 翻译自: src/install/isolated_install/Symlinker.zig
public class Symlinker {
    /// 目标路径 (符号链接所在位置)
    public var dest: String
    /// 目标链接路径 (符号链接指向的位置)
    public var target: String
    /// Windows 回退 junction 目标
    public var fallbackJunctionTarget: String

    public init(dest: String, target: String, fallbackJunctionTarget: String) {
        this.dest = dest
        this.target = target
        this.fallbackJunctionTarget = fallbackJunctionTarget
    }

    /// 创建符号链接
    /// 翻译自: Symlinker.symlink
    ///   pub fn symlink(this: *const @This()) sys.Maybe(void)
    public func symlink(): SyscallResult {
        return bao_sys.Syscall.symlink(target: target, dest: dest)
    }

    /// 确保符号链接存在
    /// 严格翻译自: Symlinker.ensureSymlink
    ///   pub fn ensureSymlink(this: *const @This(), strategy: Strategy) sys.Maybe(void)
    ///   根据策略处理各种错误情况
    public func ensureSymlink(strategy: SymlinkStrategy): SyscallResult {
        match (strategy) {
            case IgnoreFailure => {
                match (symlink()) {
                    case Success => return SyscallResult.Success
                    case Err(err) => {
                        match (err.errno) {
                            case Errno.NOENT => {
                                let destParent = Path.dirname(dest)
                                if (destParent.length == 0) {
                                    return SyscallResult.Success
                                }
                                FileDescriptor.cwd().makePath(destParent)
                                symlink()
                                return SyscallResult.Success
                            }
                            case _ => return SyscallResult.Success
                        }
                    }
                }
            }
            case ExpectMissing => {
                match (symlink()) {
                    case Success => return SyscallResult.Success
                    case Err(err) => {
                        match (err.errno) {
                            case Errno.NOENT => {
                                let destParent = Path.dirname(dest)
                                if (destParent.length == 0) {
                                    return SyscallResult.Err(err)
                                }
                                FileDescriptor.cwd().makePath(destParent)
                                return symlink()
                            }
                            case Errno.EXIST => {
                                FileDescriptor.cwd().deleteTree(dest)
                                return symlink()
                            }
                            case _ => return SyscallResult.Err(err)
                        }
                    }
                }
            }
            case ExpectExisting => {
                // 读取当前链接
                match (bao_sys.Syscall.readlink(dest)) {
                    case Success(currentLink) => {
                        // 去掉末尾斜杠
                        var normalizedLink = Path.withoutTrailingSlash(currentLink)

                        // 检查当前链接是否已经指向正确目标
                        if (normalizedLink == target) {
                            return SyscallResult.Success
                        }

                        if (normalizedLink == fallbackJunctionTarget) {
                            return SyscallResult.Success
                        }

                        // 当前链接指向错误的包, 需要重新创建
                        bao_sys.Syscall.unlink(dest)
                        return symlink()
                    }
                    case Err(readlinkErr) => {
                        match (readlinkErr.errno) {
                            case Errno.NOENT => {
                                // 目标不存在, 直接创建
                                match (symlink()) {
                                    case Success => return SyscallResult.Success
                                    case Err(symlinkErr) => {
                                        match (symlinkErr.errno) {
                                            case Errno.NOENT => {
                                                let destParent = Path.dirname(dest)
                                                if (destParent.length == 0) {
                                                    return SyscallResult.Err(symlinkErr)
                                                }
                                                FileDescriptor.cwd().makePath(destParent)
                                                return symlink()
                                            }
                                            case _ => return SyscallResult.Err(symlinkErr)
                                        }
                                    }
                                }
                            }
                            case _ => {
                                // readlink 失败, 但不是因为 NOENT
                                // dest 存在但不是符号链接
                                // 如果是目录, 保持不变 (bun patch 工作区)
                                // 如果是普通文件, 替换它
                                let isDir = bao_sys.Syscall.isPathDirectory(dest)
                                if (isDir) {
                                    return SyscallResult.Success
                                }
                                bao_sys.Syscall.unlink(dest)
                                return symlink()
                            }
                        }
                    }
                }
            }
        }
    }
}
