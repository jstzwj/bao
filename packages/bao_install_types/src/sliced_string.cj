// bao_install_types - SlicedString (零拷贝字符串视图)
// 严格翻译自: src/install_types/SlicedString.zig
//   const SlicedString = @This();
//   buf: string,
//   slice: string,
//
// 以及 src/install_types/lib.rs 中的 re-export:
//   pub mod SlicedString {
//       pub use bun_semver::SlicedString;
//       pub(crate) use bun_semver::sliced_string::*;
//   }
//
// SlicedString 持有指向外部缓冲区的引用 (buf + slice),
// slice 始终是 buf 的子串. 用于零拷贝地传递字符串.
package bao_install_types

import bao_core.*
import bao_hash.*

// ============================================================================
// SlicedString - 零拷贝字符串视图
// 严格翻译自: src/install_types/SlicedString.zig
//   const SlicedString = @This();
//   buf: string,
//   slice: string,
//
//   pub inline fn init(buf: string, slice: string) SlicedString { ... }
//   pub inline fn external(this: SlicedString) ExternalString { ... }
//   pub inline fn value(this: SlicedString) String { ... }
//   pub inline fn sub(this: SlicedString, input: string) SlicedString { ... }
// ============================================================================

/// 零拷贝字符串视图
/// 翻译自:
///   const SlicedString = @This();
///   buf: string,
///   slice: string,
/// slice 始终是 buf 的子串, 用于零拷贝地引用外部缓冲区中的字符串数据
public class SlicedString {
    /// 完整缓冲区
    /// 翻译自: buf: string
    public var buf: String

    /// 切片 (buf 的子串)
    /// 翻译自: slice: string
    public var slice_: String

    public init() {
        buf = ""
        slice_ = ""
    }

    public init(buf: String, slice_: String) {
        this.buf = buf
        this.slice_ = slice_
    }

    /// 初始化
    /// 翻译自:
    ///   pub inline fn init(buf: string, slice: string) SlicedString {
    ///       if (Environment.allow_assert and !@inComptime()) {
    ///           if (@intFromPtr(buf.ptr) > @intFromPtr(slice.ptr)) {
    ///               @panic("SlicedString.init buf is not in front of slice");
    ///           }
    ///       }
    ///       return SlicedString{ .buf = buf, .slice = slice };
    ///   }
    public static func init(buf: String, slice_: String): SlicedString {
        return SlicedString(buf: buf, slice_: slice_)
    }

    /// 转为 ExternalString (带哈希)
    /// 翻译自:
    ///   pub inline fn external(this: SlicedString) ExternalString {
    ///       return ExternalString.init(this.buf, this.slice, bun.Wyhash11.hash(0, this.slice));
    ///   }
    public func external(): ExternalString {
        return ExternalString.init(buf, slice_, Wyhash11.hash(slice_))
    }

    /// 获取 String 值
    /// 翻译自:
    ///   pub inline fn value(this: SlicedString) String {
    ///       return String.init(this.buf, this.slice);
    ///   }
    public func value(): String {
        return slice_
    }

    /// 创建子切片
    /// 翻译自:
    ///   pub inline fn sub(this: SlicedString, input: string) SlicedString {
    ///       // debug assert: input is substring of this.buf
    ///       return SlicedString{ .buf = this.buf, .slice = input };
    ///   }
    public func sub(input: String): SlicedString {
        return SlicedString(buf: buf, slice_: input)
    }

    /// 获取切片内容
    public func slice(): String {
        return slice_
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return slice_.length == 0
    }

    /// 字符串长度
    public func len(): Int64 {
        return slice_.length
    }
}
