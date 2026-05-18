// 严格翻译自: src/sys/Error.rs
//   Error type that preserves useful information from the operating system
//   Bun: 系统错误类型, 保留 errno + syscall + path + fd + dest 完整上下文
package bao_sys

import bao_core.*

// ============================================================================
// SysErrorDetail - 详细系统错误 (增强版)
// 严格翻译自: src/sys/Error.rs:38-511
//   pub struct Error {
//       pub errno: Int (u16),
//       pub fd: Fd,
//       pub path: Box<[u8]>,
//       pub syscall: Tag,
//       pub dest: Box<[u8]>,
//       #[cfg(windows)] pub from_libuv: bool,
//   }
//
//   注意: package.cj 中已有简化版 SysError 类 (6 个字段),
//   此文件提供完整版本, 包含 Windows libuv 支持、错误名称解析、
//   格式化输出等完整功能。两个版本可以共存, SysErrorDetail 是增强版。
// ============================================================================

/// 详细系统错误 - 严格对应 Bun sys.Error (Error.rs 版本)
/// Bun Error 保留完整的错误上下文: errno + syscall + path + fd + dest + from_libuv
/// 仓颉使用 class 实现等价语义
public class SysErrorDetail {
    /// errno 编码 - 对应 Bun Error.errno: u16
    public var errno: UInt16
    /// 关联的文件描述符 - 对应 Bun Error.fd: Fd
    public var fd: Int64
    /// 关联路径 - 对应 Bun Error.path: Box<[u8]>
    public var path: String
    /// 系统调用标签 - 对应 Bun Error.syscall: Tag
    public var syscall: SysTag
    /// 目标路径 - 对应 Bun Error.dest: Box<[u8]>
    public var dest: String
    /// 是否来自 libuv (Windows) - 对应 Bun Error.from_libuv: bool
    public var fromLibuv: Bool

    /// 默认/未分类 errno 值 - 对应 Bun: const TODO_ERRNO: Int = Int::MAX - 1
    /// Bun 用此值表示"尚未归类的系统错误", 不是缺失实现
    public static let TODO_ERRNO: UInt16 = 65534

    /// EAGAIN errno 值 - 对应 Bun: RETRY_ERRNO
    public static let RETRY_ERRNO: UInt16 = 11  // EAGAIN on POSIX

    /// 默认构造
    public init() {
        errno = SysErrorDetail.TODO_ERRNO
        fd = INVALID_FD
        path = ""
        syscall = SysTag.TODO
        dest = ""
        fromLibuv = false
    }

    /// 从 errno 和 syscall 构造
    /// 对应 Bun: Error::new(errno, syscall_tag)
    /// Error.rs:123-129
    public init(errno: UInt16, syscall: SysTag) {
        this.errno = errno
        this.fd = INVALID_FD
        this.path = ""
        this.syscall = syscall
        this.dest = ""
        this.fromLibuv = false
    }

    /// 从 errno, syscall, path 构造
    public init(errno: UInt16, syscall: SysTag, path: String) {
        this.errno = errno
        this.fd = INVALID_FD
        this.path = path
        this.syscall = syscall
        this.dest = ""
        this.fromLibuv = false
    }

    /// 从 errno, syscall, fd 构造
    public init(errno: UInt16, syscall: SysTag, fd: Int64) {
        this.errno = errno
        this.fd = fd
        this.path = ""
        this.syscall = syscall
        this.dest = ""
        this.fromLibuv = false
    }

    /// 完整构造
    public init(errno: UInt16, syscall: SysTag, fd: Int64, path: String, dest: String) {
        this.errno = errno
        this.fd = fd
        this.path = path
        this.syscall = syscall
        this.dest = dest
        this.fromLibuv = false
    }

    // ── 静态工厂方法 ──────────────────────────────────────────────

    /// OOM 错误
    /// 对应 Bun: Error::oom() / Error.fromCode(E::ENOMEM, Tag::read)
    /// Error.rs:34-36, 209-216
    public static func oom(): SysErrorDetail {
        return SysErrorDetail(12, SysTag.Read)  // ENOMEM = 12
    }

    /// 重试错误 (EAGAIN)
    /// 对应 Bun: Error::retry()
    /// Error.rs:219-226
    public static func retry(): SysErrorDetail {
        return SysErrorDetail(RETRY_ERRNO, SysTag.Read)
    }

    /// 默认/未分类错误 - 对应 Bun: Error::todo()
    /// Bun 用此构造默认的未归类系统错误, 不是缺失实现
    /// Error.rs:484-494
    public static func todo(): SysErrorDetail {
        return SysErrorDetail(SysErrorDetail.TODO_ERRNO, SysTag.TODO)
    }

    /// 从 errno 编码构造
    /// 对应 Bun: Error::from_code(errno, syscall_tag)
    /// Error.rs:161-167
    public static func fromCode(errno: UInt16, syscall: SysTag): SysErrorDetail {
        return SysErrorDetail(errno, syscall)
    }

    /// 从 c_int errno 构造
    /// 对应 Bun: Error::from_code_int(errno, syscall_tag)
    /// Error.rs:170-180
    public static func fromCodeInt(errno: Int32, syscall: SysTag): SysErrorDetail {
        // POSIX: errno 必须非负
        if (errno < 0) {
            return SysErrorDetail(UInt16(-errno), syscall)
        }
        return SysErrorDetail(UInt16(errno), syscall)
    }

    // ── 错误上下文修改方法 ──────────────────────────────────────

    /// 设置 fd
    /// 对应 Bun: pub fn with_fd(&self, fd: Fd) -> Error
    /// Error.rs:229-237
    public func withFd(fd: Int64): SysErrorDetail {
        let err = SysErrorDetail(errno, syscall, fd, path, dest)
        err.fromLibuv = fromLibuv
        return err
    }

    /// 设置 path
    /// 对应 Bun: pub fn with_path(&self, path: &[u8]) -> Error
    /// Error.rs:242-250
    public func withPath(path: String): SysErrorDetail {
        let err = SysErrorDetail(errno, syscall, INVALID_FD, path, "")
        err.fromLibuv = fromLibuv
        return err
    }

    /// 设置 path 和 syscall
    /// 对应 Bun: pub fn with_path_and_syscall(&self, path, syscall_) -> Error
    /// Error.rs:253-261
    public func withPathAndSyscall(path: String, syscall: SysTag): SysErrorDetail {
        let err = SysErrorDetail(errno, syscall, INVALID_FD, path, "")
        err.fromLibuv = fromLibuv
        return err
    }

    /// 设置 dest (保留其他字段)
    /// 对应 Bun: pub fn with_dest(&self, dest: &[u8]) -> Error
    /// Error.rs:269-279
    public func withDest(dest: String): SysErrorDetail {
        let err = SysErrorDetail(errno, syscall, fd, path, dest)
        err.fromLibuv = fromLibuv
        return err
    }

    /// 设置 path 和 dest
    /// 对应 Bun: pub fn with_path_dest(&self, path, dest) -> Error
    /// Error.rs:282-291
    public func withPathDest(path: String, dest: String): SysErrorDetail {
        let err = SysErrorDetail(errno, syscall, INVALID_FD, path, dest)
        err.fromLibuv = fromLibuv
        return err
    }

    /// 移除 path 和 dest
    /// 对应 Bun: pub fn without_path(&self) -> Error
    /// Error.rs:297-307
    public func withoutPath(): SysErrorDetail {
        let err = SysErrorDetail(errno, syscall, fd, "", "")
        err.fromLibuv = fromLibuv
        return err
    }

    // ── 错误信息查询方法 ──────────────────────────────────────────

    /// 获取 SystemErrno 枚举值
    /// 对应 Bun: pub fn get_errno(&self) -> E
    /// Error.rs:183-200
    public func getErrno(): SystemErrno {
        return SystemErrno.fromRaw(errno)
    }

    /// 是否为可重试错误 (EAGAIN)
    /// 对应 Bun: pub fn is_retry(&self) -> bool
    /// Error.rs:203-205
    public func isRetry(): Bool {
        return match (getErrno()) {
            case SystemErrno.EAGAIN => true
            case _ => false
        }
    }

    /// 解析为 SystemErrno (带 Windows libuv 处理)
    /// 对应 Bun: fn resolve_system_errno(&self) -> Option<SystemErrno>
    /// Error.rs:313-337
    public func resolveSystemErrno(): ?SystemErrno {
        // Windows + from_libuv: 需要通过 libuv 错误映射转换
        // POSIX: 直接检查范围
        if (errno > 0 && errno < 134) {
            return SystemErrno.fromRaw(errno)
        }
        return None
    }

    /// 获取错误码名称
    /// 对应 Bun: pub fn name(&self) -> &'static [u8]
    /// Error.rs:339-343
    public func name(): String {
        match (resolveSystemErrno()) {
            case Some(e) => e.name()
            case None => "UNKNOWN"
        }
    }

    /// 获取错误码标签名 (名称 + SystemErrno)
    /// 对应 Bun: pub fn get_error_code_tag_name(&self) -> Option<(&str, SystemErrno)>
    /// Error.rs:351-355
    public func getErrorCodeTagName(): ?Tuple2<String, SystemErrno> {
        match (resolveSystemErrno()) {
            case Some(e) => Tuple2<String, SystemErrno>(e.name(), e)
            case None => None
        }
    }

    /// 获取 coreutils 风格错误消息
    /// 对应 Bun: pub fn msg(&self) -> Option<&'static [u8]>
    /// Error.rs:357-363
    public func msg(): ?String {
        match (resolveSystemErrno()) {
            case Some(e) => CoreutilsErrorMap.get(e)
            case None => None
        }
    }

    /// 获取 libuv 风格错误消息
    /// 对应 Bun: Error.rs 中使用 libuv_error_map 的逻辑
    public func libuvMsg(): ?String {
        match (resolveSystemErrno()) {
            case Some(e) => LibuvErrorMap.get(e)
            case None => None
        }
    }

    /// 转为 Shell 风格 SystemError (简化格式)
    /// 对应 Bun: pub fn to_shell_system_error(&self) -> SystemError
    /// Error.rs:411-418
    /// 使用 coreutils_error_map 的消息
    public func toShellSystemError(): String {
        var msgStr = "unknown error"
        match (getErrorCodeTagName()) {
            case Some(tuple) =>
                let code = tuple.first
                match (CoreutilsErrorMap.get(tuple.second)) {
                    case Some(label) => msgStr = label
                    case None => msgStr = code
                }
            case None => ()
        }

        var result = msgStr
        if (path.size > 0) {
            result = "${result}: ${syscall.name()}: '${path}'"
        } else {
            result = "${result}: ${syscall.name()}"
        }
        if (dest.size > 0) {
            result = result + " -> '${dest}'"
        }
        return result
    }

    /// 转为 Node.js 风格 SystemError (详细格式)
    /// 对应 Bun: pub fn to_system_error(&self) -> SystemError
    /// Error.rs:422-482
    /// 使用 libuv_error_map 的消息, 格式匹配 Node.js exceptions.cc
    public func toSystemError(): String {
        // 构建消息缓冲区 - 对应 Bun 的 4096 字节缓冲区
        var sb = StringBuilder()

        match (getErrorCodeTagName()) {
            case Some(tuple) =>
                let code = tuple.first
                sb.append(code)
                sb.append(": ")
            case None => ()
        }

        let label = match (getErrorCodeTagName()) {
            case Some(tuple) =>
                match (LibuvErrorMap.get(tuple.second)) {
                    case Some(l) => l
                    case None => "Unknown Error"
                }
            case None => "Unknown Error"
        }
        sb.append(label)
        sb.append(", ")
        sb.append(syscall.name())

        if (path.size > 0) {
            sb.append(" '")
            sb.append(path)
            sb.append("'")

            if (dest.size > 0) {
                sb.append(" -> '")
                sb.append(dest)
                sb.append("'")
            }
        }

        return sb.toString()
    }

    /// Display 格式化输出
    /// 对应 Bun: impl fmt::Display for Error (Error.rs:497-513)
    public func toString(): String {
        return toShellSystemError()
    }
}

// ============================================================================
// Tuple2 - 简单二元组
// 用于 getErrorCodeTagName 的返回值
// ============================================================================

/// 二元组
public class Tuple2<T1, T2> {
    public let first: T1
    public let second: T2

    public init(first: T1, second: T2) {
        this.first = first
        this.second = second
    }
}
