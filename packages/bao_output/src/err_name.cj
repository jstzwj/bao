// 严格翻译自: src/bun_core/output.rs:2560-2653
//   pub trait ErrName { fn name(&self) -> &[u8]; fn as_sys_err_info(&self) -> Option<SysErrInfo>; }
//   pub struct SysErrInfo { tag_name, errno, syscall }
//   impl ErrName for &str { ... }
//   impl ErrName for &[u8] { ... }
//
// 也翻译自: src/bun_core/output.zig:1196-1271
//   pub inline fn err(error_name: anytype, comptime fmt: []const u8, args: anytype) void { ... }
package bao_output

// ============================================================================
// SysErrInfo - 系统错误信息
// 严格翻译自: src/bun_core/output.rs:2618-2623
//   pub struct SysErrInfo {
//       pub tag_name: &'static [u8],
//       pub errno: i32,
//       pub syscall: &'static str,
//   }
// ============================================================================

/// 系统错误信息 - 对应 Bun SysErrInfo
/// pub struct SysErrInfo { tag_name: &'static [u8], errno: i32, syscall: &'static str }
public class SysErrInfo {
    /// 错误标签名
    public let tagName: String
    /// 错误号
    public let errno: Int32
    /// 系统调用名
    public let syscall: String

    public init(tagName: String, errno: Int32, syscall: String) {
        this.tagName = tagName
        this.errno = errno
        this.syscall = syscall
    }
}

// ============================================================================
// ErrName - 错误名称接口
// 严格翻译自: src/bun_core/output.rs:2630-2653
//   pub trait ErrName {
//       fn name(&self) -> &[u8];
//       fn as_sys_err_info(&self) -> Option<SysErrInfo> { None }
//   }
//   impl ErrName for &str { fn name(&self) -> &[u8] { self.as_bytes() } }
//   impl ErrName for &[u8] { fn name(&self) -> &[u8] { self } }
// ============================================================================

/// 错误名称接口 - 对应 Bun ErrName trait
/// pub trait ErrName { fn name(&self) -> &[u8]; fn as_sys_err_info(&self) -> Option<SysErrInfo>; }
public interface ErrName {
    /// 获取错误名称
    func name(): String
    /// 获取系统错误信息 (可选)
    func asSysErrInfo(): ?SysErrInfo
}

/// 字符串错误名称 - 对应 Bun impl ErrName for &str
public class StringErrName <: ErrName {
    private let errName: String

    public init(errName: String) {
        this.errName = errName
    }

    public func name(): String {
        return errName
    }

    public func asSysErrInfo(): ?SysErrInfo {
        let noInfo: Option<SysErrInfo> = Option<SysErrInfo>.None
        return noInfo
    }
}

/// 系统错误名称 - 对应 Bun impl ErrName for bun_sys::Error
public class SysCallErrName <: ErrName {
    private let tagName: String
    private let errno: Int32
    private let syscall: String

    public init(tagName: String, errno: Int32, syscall: String) {
        this.tagName = tagName
        this.errno = errno
        this.syscall = syscall
    }

    public func name(): String {
        return tagName
    }

    public func asSysErrInfo(): ?SysErrInfo {
        return Some(SysErrInfo(tagName, errno, syscall))
    }
}
