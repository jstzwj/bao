// bao_install_types - SemverString (SSO 字符串类型)
// 严格翻译自: src/install_types/SemverString.zig
//   pub const String = extern struct {
//       pub const max_inline_len: usize = 8;
//       bytes: [max_inline_len]u8 = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
//       ...
//   }
//
// 以及 src/install_types/lib.rs 中的 re-export:
//   pub mod SemverString {
//       pub use bun_semver::String;
//       pub use bun_semver::string::*;
//   }
//
// SemverString 是一个 SSO (Small String Optimization) 字符串:
//   - <=7 字节: 直接内联存储在 [8]u8 中
//   - >7 字节 (或 8 字节但最高位为1): 存储为 (offset, length) 指向外部缓冲区
//   - 最后一个字节的最高位 (0x80) 用作标记位: 0=内联, 1=外部引用
package bao_install_types

import bao_core.*
import bao_hash.*

// ============================================================================
// SemverString - SSO 字符串类型
// 严格翻译自: src/install_types/SemverString.zig
//   pub const String = extern struct {
//       pub const max_inline_len: usize = 8;
//       bytes: [max_inline_len]u8 = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
//       ...
//   }
//
// 在 Cangjie 中, 我们使用 String 直接表示, 因为 Cangjie 的 String
// 已经是 SSO 优化过的. 但是为了保持与 Bun 的接口一致性,
// 我们保留这个类并提供所有原始方法.
// ============================================================================

/// SemverString - 语义化版本字符串
/// 翻译自:
///   pub const String = extern struct {
///       pub const max_inline_len: usize = 8;
///       bytes: [max_inline_len]u8 = [8]u8{ 0, 0, 0, 0, 0, 0, 0, 0 },
///   }
///
/// 在 Bun/Zig 中这是一个紧凑的 8 字节 SSO 字符串:
///   - 如果最后字节最高位为 0: 内联存储 (最多 7 字节 + 长度)
///   - 如果最后字节最高位为 1: 外部引用 (offset + length)
///
/// 在 Cangjie 中我们直接使用 String, 因为 String 已经有 SSO,
/// 但保留这个类以维持与 Bun 的类型对应关系
public class SemverString {
    /// 最大内联长度
    /// 翻译自: pub const max_inline_len: usize = 8
    public static let MAX_INLINE_LEN: Int64 = 8

    /// 内部存储
    public var data: String

    /// 空字符串
    /// 翻译自: pub const empty: String = .{}
    public static let EMPTY: SemverString = SemverString("")

    public init() {
        data = ""
    }

    public init(data: String) {
        this.data = data
    }

    // ── Factory methods ─────────────────────────────────────────────────────

    /// 从缓冲区和子串创建
    /// 翻译自:
    ///   pub fn init(buf: string, in: string) String {
    ///       return switch (in.len) {
    ///           0 => String{},
    ///           1 => String{ .bytes = .{ in[0], 0, ... } },
    ///           ...
    ///           else => ... // 外部引用
    ///       };
    ///   }
    public static func init(buf: String, input: String): SemverString {
        return SemverString(input)
    }

    /// 从内联字符串创建
    /// 翻译自:
    ///   pub fn initInline(in: string) String {
    ///       bun.assertWithLocation(canInline(in), @src());
    ///       return switch (in.len) { ... };
    ///   }
    public static func initInline(input: String): SemverString {
        return SemverString(input)
    }

    // ── Properties ──────────────────────────────────────────────────────────

    /// 是否为空
    /// 翻译自:
    ///   pub inline fn isEmpty(this: String) bool {
    ///       return @as(u64, @bitCast(this.bytes)) == @as(u64, 0);
    ///   }
    public func isEmpty(): Bool {
        return data.length == 0
    }

    /// 字符串长度
    /// 翻译自:
    ///   pub fn len(this: String) usize { ... }
    public func len(): Int64 {
        return data.length
    }

    /// 是否为内联字符串
    /// 翻译自:
    ///   pub inline fn isInline(this: String) bool {
    ///       return this.bytes[max_inline_len - 1] & 0x80 == 0;
    ///   }
    public func isInline(): Bool {
        return data.length <= MAX_INLINE_LEN
    }

    /// 是否可以内联
    /// 翻译自:
    ///   pub inline fn canInline(buf: []const u8) bool {
    ///       return switch (buf.len) {
    ///           0...max_inline_len - 1 => true,
    ///           max_inline_len => buf[max_inline_len - 1] & 0x80 == 0,
    ///           else => false,
    ///       };
    ///   }
    public static func canInline(buf: String): Bool {
        if (buf.length < MAX_INLINE_LEN) { return true }
        if (buf.length == MAX_INLINE_LEN) {
            // Check if highest bit of last byte is 0
            let lastByte = buf[Int64(buf.length) - 1].value
            return (lastByte & 0x80) == 0
        }
        return false
    }

    /// 获取字符串切片
    /// 翻译自:
    ///   pub fn slice(this: *const String, buf: string) string { ... }
    public func slice(buf: String): String {
        if (isEmpty()) { return "" }
        if (isInline()) { return data }
        return data
    }

    /// 获取 SlicedString 视图
    /// 翻译自:
    ///   pub inline fn sliced(this: *const String, buf: []const u8) SlicedString {
    ///       return if (this.isInline())
    ///           SlicedString.init(this.slice(""), this.slice(""))
    ///       else
    ///           SlicedString.init(buf, this.slice(buf));
    ///   }
    public func sliced(buf: String): SlicedString {
        if (isInline() || isEmpty()) {
            return SlicedString.init(data, data)
        }
        return SlicedString.init(buf, data)
    }

    // ── Comparison ──────────────────────────────────────────────────────────

    /// 比较顺序
    /// 翻译自:
    ///   pub inline fn order(lhs: *const String, rhs: *const String,
    ///                       lhs_buf: []const u8, rhs_buf: []const u8) std.math.Order {
    ///       return strings.order(lhs.slice(lhs_buf), rhs.slice(rhs_buf));
    ///   }
    public static func order(lhs: SemverString, rhs: SemverString,
                             lhsBuf: String, rhsBuf: String): Int64 {
        let l = lhs.slice(lhsBuf)
        let r = rhs.slice(rhsBuf)
        if (l < r) { return -1 }
        if (l > r) { return 1 }
        return 0
    }

    /// 相等比较
    /// 翻译自:
    ///   pub fn eql(this: String, that: String, this_buf: []const u8, that_buf: []const u8) bool {
    ///       if (this.isInline() and that.isInline()) {
    ///           return @as(u64, @bitCast(this.bytes)) == @as(u64, @bitCast(that.bytes));
    ///       } else if (this.isInline() != that.isInline()) {
    ///           return false;
    ///       } else {
    ///           const a = this.ptr();
    ///           const b = that.ptr();
    ///           return strings.eql(this_buf[a.off..][0..a.len], that_buf[b.off..][0..b.len]);
    ///       }
    ///   }
    public func eql(that: SemverString, thisBuf: String, thatBuf: String): Bool {
        let thisSlice = slice(thisBuf)
        let thatSlice = that.slice(thatBuf)
        return thisSlice == thatSlice
    }

    /// 相等比较 (无缓冲区)
    public func eqlSimple(that: SemverString): Bool {
        return data == that.data
    }

    // ── Pointer (internal representation) ───────────────────────────────────
    // 翻译自:
    //   pub const Pointer = extern struct {
    //       off: u32 = 0,
    //       len: u32 = 0,
    //       pub inline fn init(buf: string, in: string) Pointer { ... }
    //   };

    /// 内部指针表示 (offset + length)
    /// 翻译自:
    ///   pub const Pointer = extern struct {
    ///       off: u32 = 0,
    ///       len: u32 = 0,
    ///   }
    public class Pointer {
        public var off: UInt32
        public var len_: UInt32

        public init() {
            off = UInt32(0)
            len_ = UInt32(0)
        }

        public init(off: UInt32, len_: UInt32) {
            this.off = off
            this.len_ = len_
        }
    }

    // ── Builder ─────────────────────────────────────────────────────────────
    // 翻译自:
    //   pub const Builder = struct {
    //       len: usize = 0,
    //       cap: usize = 0,
    //       ptr: ?[*]u8 = null,
    //       string_pool: StringPool = undefined,
    //       ...
    //   };

    /// 字符串构建器
    /// 翻译自:
    ///   pub const Builder = struct {
    ///       len: usize = 0,
    ///       cap: usize = 0,
    ///       ptr: ?[*]u8 = null,
    ///       string_pool: StringPool,
    ///       pub fn count(this: *Builder, slice_: string) void { ... }
    ///       pub fn append(this: *Builder, comptime Type: type, slice_: string) Type { ... }
    ///   }
    public class Builder {
        private var buffer: StringBuilder
        private var pool: HashMap<UInt64, SemverString>

        public init() {
            buffer = StringBuilder()
            pool = HashMap<UInt64, SemverString>()
        }

        /// 计算字符串哈希
        /// 翻译自: pub inline fn stringHash(buf: []const u8) u64
        public static func stringHash(buf: String): UInt64 {
            return Wyhash11.hash(buf)
        }

        /// 预留空间
        /// 翻译自: pub fn count(this: *Builder, slice_: string) void
        public func count(slice_: String): Unit {
            // In Cangjie, StringBuilder handles allocation automatically
        }

        /// 追加字符串并返回 SemverString
        /// 翻译自: pub fn append(this: *Builder, comptime Type: type, slice_: string) Type
        public func append(slice_: String): SemverString {
            let hash = Builder.stringHash(slice_)
            if (canInline(slice_)) {
                return SemverString(slice_)
            }

            // Check pool for dedup
            match (pool.get(hash)) {
                case Some(existing) => return existing
                case None => ()
            }

            let s = SemverString(slice_)
            pool.put(hash, s)
            return s
        }

        /// 追加并返回 ExternalString
        /// 翻译自: pub fn appendExternal(this: *Builder, str: string) OOM!ExternalString
        public func appendExternal(slice_: String): ExternalString {
            let hash = Builder.stringHash(slice_)
            if (canInline(slice_)) {
                return ExternalString(value: slice_, hash: hash)
            }

            match (pool.get(hash)) {
                case Some(existing) => {
                    return ExternalString(value: existing.data, hash: hash)
                }
                case None => ()
            }

            let s = SemverString(slice_)
            pool.put(hash, s)
            return ExternalString(value: slice_, hash: hash)
        }

        private static func canInline(s: String): Bool {
            return SemverString.canInline(s)
        }
    }

    // ── Formatter ───────────────────────────────────────────────────────────
    // 翻译自:
    //   pub const Formatter = struct {
    //       str: *const String,
    //       buf: string,
    //       pub fn format(formatter: Formatter, writer: *std.Io.Writer) ...void { ... }
    //   };

    /// 格式化器
    /// 翻译自: pub const Formatter = struct { str, buf, format() }
    public func fmt(buf: String): String {
        return slice(buf)
    }

    /// JSON 格式化
    /// 翻译自:
    ///   pub const JsonFormatter = struct { ... }
    public func fmtJson(buf: String, quote: Bool): String {
        let s = slice(buf)
        if (quote) {
            return "\"${s}\""
        }
        return s
    }

    /// Store 路径格式化
    /// 翻译自:
    ///   pub const StorePathFormatter = struct { ... }
    ///   将 / \ : # 替换为 +
    public func fmtStorePath(buf: String): String {
        let s = slice(buf)
        let sb = StringBuilder()
        for (c in s) {
            let v = c.value
            if (v == 47 || v == 92 || v == 58 || v == 35) {  // / \ : #
                sb.append("+")
            } else {
                sb.append(c)
            }
        }
        return sb.toString()
    }

    // ── HashContext ─────────────────────────────────────────────────────────
    // 翻译自:
    //   pub const HashContext = struct {
    //       arg_buf: []const u8,
    //       existing_buf: []const u8,
    //       pub fn eql(ctx, arg, existing) bool { ... }
    //       pub fn hash(ctx, arg) u64 { ... }
    //   };

    /// 哈希上下文
    /// 翻译自: pub const HashContext = struct { arg_buf, existing_buf }
    public class HashContext {
        public var argBuf: String
        public var existingBuf: String

        public init(argBuf: String, existingBuf: String) {
            this.argBuf = argBuf
            this.existingBuf = existingBuf
        }

        /// 翻译自: pub fn eql(ctx: HashContext, arg: String, existing: String) bool
        public func eql(arg: SemverString, existing: SemverString): Bool {
            return arg.eql(existing, argBuf, existingBuf)
        }

        /// 翻译自: pub fn hash(ctx: HashContext, arg: String) u64
        public func hash(arg: SemverString): UInt64 {
            return Wyhash11.hash(arg.slice(argBuf))
        }
    }

    /// 排序器
    /// 翻译自:
    ///   pub fn Sorter(comptime direction: enum { asc, desc }) type {
    ///       return struct {
    ///           lhs_buf: []const u8,
    ///           rhs_buf: []const u8,
    ///           pub fn lessThan(this, lhs, rhs) bool { ... }
    ///       };
    ///   }
    public class Sorter {
        public var lhsBuf: String
        public var rhsBuf: String
        public var ascending: Bool

        public init(lhsBuf: String, rhsBuf: String, ascending: Bool) {
            this.lhsBuf = lhsBuf
            this.rhsBuf = rhsBuf
            this.ascending = ascending
        }

        public func lessThan(lhs: SemverString, rhs: SemverString): Bool {
            let cmp = SemverString.order(lhs, rhs, lhsBuf, rhsBuf)
            return if (ascending) { cmp < 0 } else { cmp > 0 }
        }
    }
}
