// bao_install_types - ExternalString (带预计算哈希的字符串)
// 严格翻译自: src/install_types/ExternalString.zig
//   pub const ExternalString = extern struct {
//       value: String = String{},
//       hash: u64 = 0,
//       ...
//   }
//
// 以及 src/install_types/lib.rs 中的 re-export:
//   pub mod ExternalString {
//       pub use bun_semver::ExternalString;
//       pub(crate) use bun_semver::external_string::*;
//   }
//
// ExternalString 是 SemverString + 预计算的 Wyhash 哈希值,
// 用于 lockfile 中快速比较 (先比较哈希, 再比较内容)
package bao_install_types

import bao_core.*
import bao_hash.*

// ============================================================================
// ExternalString - 带预计算哈希的字符串
// 严格翻译自: src/install_types/ExternalString.zig
//   pub const ExternalString = extern struct {
//       value: String = String{},
//       hash: u64 = 0,
//
//       pub inline fn fmt(this: *const ExternalString, buf: []const u8) String.Formatter { ... }
//       pub fn order(lhs, rhs, lhs_buf, rhs_buf) std.math.Order { ... }
//       pub inline fn from(in: string) ExternalString { ... }
//       pub inline fn isInline(this) bool { ... }
//       pub inline fn isEmpty(this) bool { ... }
//       pub inline fn len(this) usize { ... }
//       pub inline fn init(buf, in, hash) ExternalString { ... }
//       pub inline fn slice(this, buf) string { ... }
//   }
// ============================================================================

/// 带预计算哈希的字符串
/// 翻译自:
///   pub const ExternalString = extern struct {
///       value: String = String{},
///       hash: u64 = 0,
///   }
/// value 是 SemverString (内联或外部缓冲区引用)
/// hash 是 value 内容的 Wyhash 哈希, 用于快速比较
public class ExternalString {
    /// 字符串值
    /// 翻译自: value: String = String{}
    public var value: String

    /// 预计算的哈希值
    /// 翻译自: hash: u64 = 0
    public var hash: UInt64

    public init() {
        value = ""
        hash = UInt64(0)
    }

    public init(value: String, hash: UInt64) {
        this.value = value
        this.hash = hash
    }

    /// 从字符串创建 ExternalString (自动计算哈希)
    /// 翻译自:
    ///   pub inline fn from(in: string) ExternalString {
    ///       return ExternalString{
    ///           .value = String.init(in, in),
    ///           .hash = bun.Wyhash.hash(0, in),
    ///       };
    ///   }
    public static func from(input: String): ExternalString {
        return ExternalString(
            value: input,
            hash: Wyhash11.hash(input)
        )
    }

    /// 初始化 (带指定缓冲区引用和哈希)
    /// 翻译自:
    ///   pub inline fn init(buf: string, in: string, hash: u64) ExternalString {
    ///       return ExternalString{ .value = String.init(buf, in), .hash = hash };
    ///   }
    public static func init(buf: String, input: String, hash: UInt64): ExternalString {
        return ExternalString(value: input, hash: hash)
    }

    /// 比较顺序
    /// 翻译自:
    ///   pub fn order(lhs: *const ExternalString, rhs: *const ExternalString,
    ///                lhs_buf: []const u8, rhs_buf: []const u8) std.math.Order {
    ///       if (lhs.hash == rhs.hash and lhs.hash > 0) return .eq;
    ///       return lhs.value.order(&rhs.value, lhs_buf, rhs_buf);
    ///   }
    public static func order(lhs: ExternalString, rhs: ExternalString): Int64 {
        // 先比较哈希: 如果哈希相等且非零, 则认为相等
        if (lhs.hash == rhs.hash && lhs.hash > UInt64(0)) {
            return 0
        }
        // 回退到字符串比较
        if (lhs.value < rhs.value) { return -1 }
        if (lhs.value > rhs.value) { return 1 }
        return 0
    }

    /// 是否为空
    /// 翻译自:
    ///   pub inline fn isEmpty(this: ExternalString) bool {
    ///       return this.value.isEmpty();
    ///   }
    public func isEmpty(): Bool {
        return value.length == 0
    }

    /// 字符串长度
    /// 翻译自:
    ///   pub inline fn len(this: ExternalString) usize {
    ///       return this.value.len();
    ///   }
    public func len(): Int64 {
        return value.length
    }

    /// 获取字符串切片
    /// 翻译自:
    ///   pub inline fn slice(this: *const ExternalString, buf: string) string {
    ///       return this.value.slice(buf);
    ///   }
    public func slice(buf: String): String {
        return value
    }

    /// 格式化
    /// 翻译自:
    ///   pub inline fn fmt(this: *const ExternalString, buf: []const u8) String.Formatter {
    ///       return this.value.fmt(buf);
    ///   }
    public func fmt(buf: String): String {
        return value
    }

    /// 相等比较
    public func eql(other: ExternalString): Bool {
        if (hash == other.hash && hash > UInt64(0)) {
            return true
        }
        return value == other.value
    }
}
