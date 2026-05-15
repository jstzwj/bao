// bao_install - 安装类型定义
// 严格翻译自:
//   src/install_types/ExternalString.zig - 带预计算哈希的字符串, 用于包解析中的快速比较
//   src/install_types/NodeLinker.zig    - node_modules 链接模式
//   src/install_types/SemverString.zig  - 可使用 semver 规则比较的字符串
//   src/install_types/SlicedString.zig  - 零拷贝字符串视图 (偏移/长度指向共享缓冲区)
package bao_install

import bao_core.*
import bao_semver.*
import bao_hash.*

// ============================================================================
// NodeLinker - node_modules 链接模式
// 严格翻译自: src/install_types/NodeLinker.zig
//   pub const NodeLinker = enum(u8) { auto, hoisted, isolated }
//   提取自 install/PackageManager/PackageManagerOptions.zig, 以便
//   options_types/schema.zig, cli/bunfig.zig, ini/ 可以命名链接器模式
//   而不依赖完整的包管理器
// ============================================================================

/// node_modules 链接模式 - 对应 Bun NodeLinker
/// 决定 node_modules 目录如何构建:
///   - Auto:     使用 workspaces 时为 isolated, 否则 hoisted
///   - Hoisted:  所有依赖提升到根 node_modules
///   - Isolated: 每个包有自己的 node_modules (类似 pnpm)
public enum NodeLinker {
    | Auto      // 当 nodeLinker 未在 package.json/bun.lock/bun.lockb 中指定时使用
    | Hoisted   // 所有依赖扁平提升到根 node_modules
    | Isolated  // 每个包有隔离的 node_modules (类似 pnpm 的符号链接结构)

    /// 从字符串解析 NodeLinker - 对应 Bun NodeLinker.fromStr
    /// 翻译自: src/install_types/NodeLinker.zig
    ///   pub fn fromStr(input: []const u8) ?NodeLinker {
    ///       if (strings.eqlComptime(input, "hoisted")) return .hoisted;
    ///       if (strings.eqlComptime(input, "isolated")) return .isolated;
    ///       return null;
    ///   }
    public static func fromStr(input: String): ?NodeLinker {
        if (input == "hoisted") {
            return NodeLinker.Hoisted
        }
        if (input == "isolated") {
            return NodeLinker.Isolated
        }
        return None
    }

    /// 转为字符串表示
    public func toString(): String {
        match (this) {
            case Auto => "auto"
            case Hoisted => "hoisted"
            case Isolated => "isolated"
        }
    }
}

// ============================================================================
// SemverString - 可使用 semver 规则比较的字符串
// 严格翻译自: src/install_types/SemverString.zig
//   pub const String = extern struct { ... }
//   Bun 的 Semver.String 是一个复杂的 SSO (Small String Optimization) 字符串类型:
//     - 空字符串: 全零字节
//     - 内联字符串: 最后一位 bit 为 0, 字符串数据直接存储在 8 字节中
//     - 外部字符串: 最后一位 bit 为 1, 存储 offset/length 指向外部缓冲区
//   仓颉实现: 使用 String + 可选外部缓冲区偏移/长度, 保持语义一致
// ============================================================================

/// Semver 字符串 - 对应 Bun Semver.String
/// 支持两种模式:
///   1. 内联模式: 字符串直接存储 (<= 8 字节)
///   2. 外部模式: offset/length 指向共享缓冲区 (零拷贝)
public class SemverString {
    /// 最大内联长度 - 对应 Bun String.max_inline_len (8)
    /// 翻译自: pub const max_inline_len: usize = 8
    public static let MAX_INLINE_LEN: Int64 = 8

    /// 内联字符串数据
    /// 对应 Bun: bytes: [max_inline_len]u8
    public var bytes: Array<UInt8>

    /// 是否为内联存储
    public var isInlineFlag: Bool

    /// 外部缓冲区引用 (用于外部模式)
    /// 对应 Bun: Pointer { off: u32, len: u32 }
    public var externalBuf: ?Array<UInt8>
    public var offset: Int64
    public var length: Int64

    /// 空字符串单例 - 对应 Bun String.empty
    public static prop empty: SemverString {
        SemverString()
    }

    public init() {
        bytes = Array<UInt8>(8, item: UInt8(0))
        isInlineFlag = true
        externalBuf = None
        offset = 0
        length = 0
    }

    /// 从内联字符串初始化 - 对应 Bun String.init(buf, in) 中短字符串路径
    /// 翻译自:
    ///   pub fn init(buf: string, in: string) String {
    ///       return switch (in.len) {
    ///           0 => String{},
    ///           1 => String{ .bytes = .{ in[0], 0, ... } },
    ///           ...
    ///       }
    ///   }
    public init(input: String) {
        let len = input.size
        bytes = Array<UInt8>(8, item: UInt8(0))
        isInlineFlag = true
        externalBuf = None
        offset = 0
        length = 0
        if (len > 0 && len <= MAX_INLINE_LEN) {
            var i: Int64 = 0
            while (i < len) {
                bytes[i] = UInt8(input[Int64(i)].value)
                i += 1
            }
        } else if (len > MAX_INLINE_LEN) {
            // 外部模式: 需要外部缓冲区
            isInlineFlag = false
            length = len
            offset = 0
            var arr = Array<UInt8>()
            for (c in input) { arr.append(UInt8(c.value)) }
            externalBuf = arr
        }
    }

    /// 从外部缓冲区和切片初始化 - 对应 Bun String.init(buf, in)
    /// 翻译自:
    ///   pub fn init(buf: string, in: string) String {
    ///       // 当 len > max_inline_len 时存储 Pointer { off, len }
    ///   }
    public init(buf: Array<UInt8>, input: Array<UInt8>) {
        let len = input.size
        bytes = Array<UInt8>(8, item: UInt8(0))
        offset = 0
        length = 0

        if (len <= MAX_INLINE_LEN) {
            isInlineFlag = true
            externalBuf = None
            var i: Int64 = 0
            while (i < len) {
                bytes[i] = input[i]
                i += 1
            }
        } else {
            // 外部模式: 计算偏移量
            // 对应 Bun: Pointer { off = in.ptr - buf.ptr, len = in.len }
            isInlineFlag = false
            externalBuf = buf
            // 在缓冲区中查找 input 的起始位置
            offset = findOffset(buf, input)
            length = len
        }
    }

    /// 从外部缓冲区和字符串切片初始化
    public init(buf: Array<UInt8>, input: String) {
        let len = input.size
        bytes = Array<UInt8>(8, item: UInt8(0))
        offset = 0
        length = 0

        if (len <= MAX_INLINE_LEN) {
            isInlineFlag = true
            externalBuf = None
            var i: Int64 = 0
            while (i < len) {
                bytes[i] = UInt8(input[Int64(i)].value)
                i += 1
            }
        } else {
            isInlineFlag = false
            externalBuf = buf
            offset = 0
            length = len
        }
    }

    /// 是否为内联字符串 - 对应 Bun String.isInline
    /// 翻译自: pub inline fn isInline(this: String) bool {
    ///     return this.bytes[max_inline_len - 1] & 0x80 == 0;
    /// }
    public func isInline(): Bool {
        return isInlineFlag
    }

    /// 是否为空字符串 - 对应 Bun String.isEmpty
    /// 翻译自: pub inline fn isEmpty(this: String) bool {
    ///     return @as(u64, @bitCast(this.bytes)) == 0;
    /// }
    public func isEmpty(): Bool {
        if (isInlineFlag) {
            var allZero = true
            var i: Int64 = 0
            while (i < MAX_INLINE_LEN) {
                if (bytes[i] != UInt8(0)) {
                    allZero = false
                    break
                }
                i += 1
            }
            return allZero
        }
        return length == 0
    }

    /// 字符串长度 - 对应 Bun String.len
    /// 翻译自: pub fn len(this: String) usize { ... }
    public func len(): Int64 {
        if (isInlineFlag) {
            // 内联模式: 查找第一个零字节的位置
            if (bytes[0] == UInt8(0)) {
                return 0
            }
            var i: Int64 = 0
            while (i < MAX_INLINE_LEN) {
                if (bytes[i] == UInt8(0)) {
                    return i
                }
                i += 1
            }
            return MAX_INLINE_LEN
        }
        return length
    }

    /// 获取字符串切片 - 对应 Bun String.slice
    /// 翻译自: pub fn slice(this: *const String, buf: string) string { ... }
    public func slice(buf: ?Array<UInt8>): String {
        if (isInlineFlag) {
            // 内联模式: 直接从 bytes 构建字符串
            var sb = StringBuilder()
            var i: Int64 = 0
            let len_ = len()
            while (i < len_) {
                sb.append(Rune(bytes[i]))
                i += 1
            }
            return sb.toString()
        }
        // 外部模式: 从缓冲区切片
        let extBuf = externalBuf
        if (extBuf != None) {
            let buf_ = extBuf.getOrThrow()
            var sb = StringBuilder()
            let start = offset
            let end = offset + length
            var i = start
            while (i < end) {
                sb.append(Rune(buf_[i]))
                i += 1
            }
            return sb.toString()
        }
        // 没有外部缓冲区, 使用传入的缓冲区
        if (buf != None) {
            let buf_ = buf.getOrThrow()
            var sb = StringBuilder()
            let start = offset
            let end = offset + length
            var i = start
            while (i < end) {
                sb.append(Rune(buf_[i]))
                i += 1
            }
            return sb.toString()
        }
        return ""
    }

    /// 比较顺序 - 对应 Bun String.order
    /// 翻译自: pub inline fn order(lhs, rhs, lhs_buf, rhs_buf) std.math.Order {
    ///     return strings.order(lhs.slice(lhs_buf), rhs.slice(rhs_buf));
    /// }
    public func order(other: SemverString, thisBuf: ?Array<UInt8>, otherBuf: ?Array<UInt8>): Int64 {
        let a = slice(thisBuf)
        let b = other.slice(otherBuf)

        if (a < b) { return -1 }
        if (a > b) { return 1 }
        return 0
    }

    /// 相等比较 - 对应 Bun String.eql
    /// 翻译自: pub fn eql(this, that, this_buf, that_buf) bool { ... }
    public func eql(other: SemverString, thisBuf: ?Array<UInt8>, otherBuf: ?Array<UInt8>): Bool {
        if (isInlineFlag && other.isInline()) {
            // 内联比较: 直接比较字节
            var i: Int64 = 0
            while (i < MAX_INLINE_LEN) {
                if (bytes[i] != other.bytes[i]) {
                    return false
                }
                i += 1
            }
            return true
        }
        if (isInlineFlag != other.isInline()) {
            return false
        }
        // 外部比较: 比较字符串内容
        return slice(thisBuf) == other.slice(otherBuf)
    }

    /// 能否内联 - 对应 Bun String.canInline
    /// 翻译自: pub inline fn canInline(buf: []const u8) bool {
    ///     return switch (buf.len) {
    ///         0...max_inline_len - 1 => true,
    ///         max_inline_len => buf[max_inline_len - 1] & 0x80 == 0,
    ///         else => false,
    ///     }
    /// }
    public static func canInline(input: Array<UInt8>): Bool {
        let len_ = input.size
        if (len_ < MAX_INLINE_LEN) {
            return true
        }
        if (len_ == MAX_INLINE_LEN) {
            return (input[MAX_INLINE_LEN - 1] & UInt8(0x80)) == UInt8(0)
        }
        return false
    }

    /// 能否内联 (字符串版本)
    public static func canInlineStr(input: String): Bool {
        let len_ = input.size
        if (len_ < MAX_INLINE_LEN) {
            return true
        }
        if (len_ == MAX_INLINE_LEN) {
            return (UInt8(input[Int64(MAX_INLINE_LEN - 1)].value) & UInt8(0x80)) == UInt8(0)
        }
        return false
    }

    /// 转为 SlicedString - 对应 Bun String.sliced
    /// 翻译自: pub inline fn sliced(this, buf) SlicedString {
    ///     return if (this.isInline()) SlicedString.init(this.slice(""), this.slice(""))
    ///            else SlicedString.init(buf, this.slice(buf))
    /// }
    public func sliced(buf: ?Array<UInt8>): SlicedString {
        if (isInline()) {
            let s = slice(None)
            return SlicedString(s, s)
        }
        let s = slice(buf)
        return SlicedString(s, s)
    }

    // 在缓冲区中查找子数组的偏移量
    private static func findOffset(buf: Array<UInt8>, input: Array<UInt8>): Int64 {
        if (input.size == 0 || input.size > buf.size) {
            return 0
        }
        var i: Int64 = 0
        while (i <= buf.size - input.size) {
            var match = true
            var j: Int64 = 0
            while (j < input.size) {
                if (buf[i + j] != input[j]) {
                    match = false
                    break
                }
                j += 1
            }
            if (match) {
                return i
            }
            i += 1
        }
        return 0
    }
}

// ============================================================================
// ExternalString - 带预计算哈希的字符串
// 严格翻译自: src/install_types/ExternalString.zig
//   pub const ExternalString = extern struct {
//       value: String = String{},
//       hash: u64 = 0,
//   }
//   用于包解析中的快速比较: 哈希相等时直接判定为相等, 避免字符串内容比较
// ============================================================================

/// 带预计算哈希的字符串 - 对应 Bun ExternalString
/// 用于包解析中的快速比较: 哈希相等时直接判定为相等
/// 翻译自: src/install_types/ExternalString.zig
///   pub const ExternalString = extern struct {
///       value: String = String{},
///       hash: u64 = 0,
///   }
public class ExternalString {
    /// 字符串值 - 对应 Bun: value: String = String{}
    public var value: SemverString

    /// 预计算的哈希值 - 对应 Bun: hash: u64 = 0
    /// 使用 Wyhash 哈希算法
    public var hash: UInt64

    /// 空字符串单例 - 对应 Bun ExternalString{}
    public init() {
        value = SemverString()
        hash = UInt64(0)
    }

    /// 从字符串创建 - 对应 Bun ExternalString.from
    /// 翻译自:
    ///   pub inline fn from(in: string) ExternalString {
    ///       return ExternalString{
    ///           .value = String.init(in, in),
    ///           .hash = bun.Wyhash.hash(0, in),
    ///       }
    ///   }
    public init(input: String) {
        value = SemverString(input)
        hash = Wyhash11.hash(input)
    }

    /// 从 SemverString 和哈希值初始化 - 对应 Bun ExternalString.init(buf, in, hash)
    /// 翻译自:
    ///   pub inline fn init(buf: string, in: string, hash: u64) ExternalString {
    ///       return ExternalString{
    ///           .value = String.init(buf, in),
    ///           .hash = hash,
    ///       }
    ///   }
    public init(value: SemverString, hash: UInt64) {
        this.value = value
        this.hash = hash
    }

    /// 从缓冲区和切片创建 - 对应 Bun ExternalString.init(buf, in, hash)
    public init(buf: Array<UInt8>, input: Array<UInt8>, hash: UInt64) {
        value = SemverString(buf, input)
        this.hash = hash
    }

    /// 比较顺序 - 对应 Bun ExternalString.order
    /// 翻译自:
    ///   pub fn order(lhs, rhs, lhs_buf, rhs_buf) std.math.Order {
    ///       if (lhs.hash == rhs.hash and lhs.hash > 0) return .eq;
    ///       return lhs.value.order(&rhs.value, lhs_buf, rhs_buf);
    ///   }
    /// 优化: 哈希相等且非零时直接判定为相等, 避免字符串内容比较
    public func order(other: ExternalString, thisBuf: ?Array<UInt8>, otherBuf: ?Array<UInt8>): Int64 {
        // 快速路径: 哈希相等且非零 => 字符串相等
        if (hash == other.hash && hash > UInt64(0)) {
            return 0 // eq
        }
        return value.order(other.value, thisBuf, otherBuf)
    }

    /// 是否为内联字符串 - 对应 Bun ExternalString.isInline
    /// 翻译自: pub inline fn isInline(this: ExternalString) bool {
    ///     return this.value.isInline();
    /// }
    public func isInline(): Bool {
        return value.isInline()
    }

    /// 是否为空字符串 - 对应 Bun ExternalString.isEmpty
    /// 翻译自: pub inline fn isEmpty(this: ExternalString) bool {
    ///     return this.value.isEmpty();
    /// }
    public func isEmpty(): Bool {
        return value.isEmpty()
    }

    /// 字符串长度 - 对应 Bun ExternalString.len
    /// 翻译自: pub inline fn len(this: ExternalString) usize {
    ///     return this.value.len();
    /// }
    public func len(): Int64 {
        return value.len()
    }

    /// 获取字符串切片 - 对应 Bun ExternalString.slice
    /// 翻译自: pub inline fn slice(this: *const ExternalString, buf: string) string {
    ///     return this.value.slice(buf);
    /// }
    public func slice(buf: ?Array<UInt8>): String {
        return value.slice(buf)
    }

    /// 格式化输出 - 对应 Bun ExternalString.fmt
    /// 翻译自: pub inline fn fmt(this: *const ExternalString, buf: []const u8) String.Formatter {
    ///     return this.value.fmt(buf);
    /// }
    public func toString(buf: ?Array<UInt8>): String {
        return slice(buf)
    }
}

// ============================================================================
// SlicedString - 零拷贝字符串视图
// 严格翻译自: src/install_types/SlicedString.zig
//   const SlicedString = @This();
//   buf: string,
//   slice: string,
//   表示一个指向共享缓冲区的字符串视图, 零拷贝操作
// ============================================================================

/// 零拷贝字符串视图 - 对应 Bun SlicedString
/// 持有缓冲区引用和切片引用, 切片是缓冲区的子集
/// 翻译自: src/install_types/SlicedString.zig
///   const SlicedString = @This();
///   buf: string,
///   slice: string,
public class SlicedString {
    /// 底层缓冲区 - 对应 Bun: buf: string
    /// 完整的外部缓冲区
    public var buf: Array<UInt8>

    /// 切片 - 对应 Bun: slice: string
    /// buf 的一个子视图
    public var slice_: Array<UInt8>

    /// 初始化 - 对应 Bun SlicedString.init
    /// 翻译自:
    ///   pub inline fn init(buf: string, slice: string) SlicedString {
    ///       return SlicedString{ .buf = buf, .slice = slice };
    ///   }
    /// 注意: Bun 在 debug 模式下断言 buf 指针 <= slice 指针
    public init(buf: Array<UInt8>, slice_: Array<UInt8>) {
        this.buf = buf
        this.slice_ = slice_
    }

    /// 从两个字符串初始化 (字符串形式, 不做零拷贝优化)
    public init(buf: String, slice_: String) {
        var bufArr = Array<UInt8>()
        for (c in buf) { bufArr.append(UInt8(c.value)) }
        this.buf = bufArr

        var sliceArr = Array<UInt8>()
        for (c in slice_) { sliceArr.append(UInt8(c.value)) }
        this.slice_ = sliceArr
    }

    /// 转为 ExternalString - 对应 Bun SlicedString.external
    /// 翻译自:
    ///   pub inline fn external(this: SlicedString) ExternalString {
    ///       return ExternalString.init(this.buf, this.slice, bun.Wyhash11.hash(0, this.slice));
    ///   }
    public func external(): ExternalString {
        let hashVal = Wyhash11.hash(slice_)
        return ExternalString(buf, slice_, hashVal)
    }

    /// 转为 SemverString - 对应 Bun SlicedString.value
    /// 翻译自:
    ///   pub inline fn value(this: SlicedString) String {
    ///       return String.init(this.buf, this.slice);
    ///   }
    public func value(): SemverString {
        return SemverString(buf, slice_)
    }

    /// 创建子视图 - 对应 Bun SlicedString.sub
    /// 翻译自:
    ///   pub inline fn sub(this: SlicedString, input: string) SlicedString {
    ///       // debug 断言: input 必须在 buf 范围内
    ///       return SlicedString{ .buf = this.buf, .slice = input };
    ///   }
    public func sub(input: Array<UInt8>): SlicedString {
        return SlicedString(buf, input)
    }

    /// 获取切片字符串表示
    public func toString(): String {
        var sb = StringBuilder()
        var i: Int64 = 0
        while (i < slice_.size) {
            sb.append(Rune(slice_[i]))
            i += 1
        }
        return sb.toString()
    }

    /// 获取缓冲区字符串表示
    public func bufToString(): String {
        var sb = StringBuilder()
        var i: Int64 = 0
        while (i < buf.size) {
            sb.append(Rune(buf[i]))
            i += 1
        }
        return sb.toString()
    }
}

// ============================================================================
// SemverString.Builder - 字符串构建器
// 严格翻译自: src/install_types/SemverString.zig - String.Builder
//   pub const Builder = struct {
//       len: usize = 0,
//       cap: usize = 0,
//       ptr: ?[*]u8 = null,
//       string_pool: StringPool = undefined,
//   }
//   用于批量构建 SemverString, 避免重复分配
// ============================================================================

/// Semver 字符串构建器 - 对应 Bun String.Builder
/// 翻译自: src/install_types/SemverString.zig - String.Builder
///   pub const Builder = struct {
///       len: usize = 0,
///       cap: usize = 0,
///       ptr: ?[*]u8 = null,
///       string_pool: StringPool = undefined,
///   }
public class SemverStringBuilder {
    /// 已写入的长度 - 对应 Bun: len: usize = 0
    public var writtenLen: Int64

    /// 总容量 - 对应 Bun: cap: usize = 0
    public var capacity: Int64

    /// 底层缓冲区 - 对应 Bun: ptr: ?[*]u8 = null
    public var buffer: ?Array<UInt8>

    /// 字符串池 (哈希 -> SemverString), 用于去重
    /// 对应 Bun: string_pool: StringPool = undefined
    ///   pub const StringPool = std.HashMap(u64, String, IdentityContext(u64), 80)
    public var stringPool: HashMap<UInt64, SemverString>

    public init() {
        writtenLen = 0
        capacity = 0
        buffer = None
        stringPool = HashMap<UInt64, SemverString>()
    }

    /// 字符串哈希 - 对应 Bun Builder.stringHash
    /// 翻译自: pub inline fn stringHash(buf: []const u8) u64 {
    ///     return bun.Wyhash11.hash(0, buf);
    /// }
    public static func stringHash(input: Array<UInt8>): UInt64 {
        return Wyhash11.hash(input)
    }

    /// 字符串哈希 (String 版本)
    public static func stringHashStr(input: String): UInt64 {
        return Wyhash11.hash(input)
    }

    /// 计入容量 - 对应 Bun Builder.count
    /// 翻译自:
    ///   pub inline fn count(this: *Builder, slice_: string) void {
    ///       return countWithHash(this, slice_,
    ///           if (slice_.len >= String.max_inline_len) stringHash(slice_) else std.math.maxInt(u64));
    ///   }
    public func count(input: Array<UInt8>): Unit {
        let hashVal = if (input.size >= SemverString.MAX_INLINE_LEN) {
            SemverStringBuilder.stringHash(input)
        } else {
            UInt64.MAX
        }
        countWithHash(input, hashVal)
    }

    /// 带哈希计入容量 - 对应 Bun Builder.countWithHash
    /// 翻译自:
    ///   pub inline fn countWithHash(this, slice_, hash) void {
    ///       if (slice_.len <= String.max_inline_len) return;
    ///       if (!this.string_pool.contains(hash)) { this.cap += slice_.len; }
    ///   }
    public func countWithHash(input: Array<UInt8>, hash: UInt64): Unit {
        if (input.size <= SemverString.MAX_INLINE_LEN) {
            return
        }
        if (!stringPool.contains(hash)) {
            capacity += input.size
        }
    }

    /// 获取已分配的切片 - 对应 Bun Builder.allocatedSlice
    /// 翻译自: pub inline fn allocatedSlice(this) []u8 {
    ///     return if (this.cap > 0) this.ptr.?[0..this.cap] else &[_]u8{}
    /// }
    public func allocatedSlice(): Array<UInt8> {
        if (let Some(buf) = buffer) {
            if (capacity > 0) {
                return buf
            }
        }
        return Array<UInt8>()
    }

    /// 分配缓冲区 - 对应 Bun Builder.allocate
    /// 翻译自: pub fn allocate(this, allocator) !void {
    ///     const ptr_ = try allocator.alloc(u8, this.cap);
    ///     this.ptr = ptr_.ptr;
    /// }
    public func allocate(): Unit {
        if (capacity > 0) {
            buffer = Array<UInt8>(capacity, item: UInt8(0))
        } else {
            buffer = Array<UInt8>()
        }
    }

    /// 追加字符串并返回 SemverString - 对应 Bun Builder.append
    /// 翻译自: pub fn append(this, comptime Type, slice_) Type {
    ///     return appendWithHash(this, Type, slice_, stringHash(slice_));
    /// }
    public func append(input: Array<UInt8>): SemverString {
        return appendWithHash(input, SemverStringBuilder.stringHash(input))
    }

    /// 追加字符串并返回 ExternalString - 对应 Bun Builder.append(ExternalString)
    public func appendExternal(input: Array<UInt8>): ExternalString {
        return appendExternalWithHash(input, SemverStringBuilder.stringHash(input))
    }

    /// 带哈希追加 ExternalString - 对应 Bun Builder.appendWithHash(ExternalString)
    /// 翻译自:
    ///   pub fn appendWithHash(this, Type, slice_, hash) Type {
    ///       if (slice_.len <= String.max_inline_len) { ... }
    ///       const string_entry = this.string_pool.getOrPut(hash) catch unreachable;
    ///       if (!string_entry.found_existing) {
    ///           bun.copy(u8, this.ptr.?[this.len..this.cap], slice_);
    ///           const final_slice = this.ptr.?[this.len..this.cap][0..slice_.len];
    ///           this.len += slice_.len;
    ///           string_entry.value_ptr.* = String.init(this.allocatedSlice(), final_slice);
    ///       }
    ///       return ExternalString{ .value = string_entry.value_ptr.*, .hash = hash };
    ///   }
    public func appendExternalWithHash(input: Array<UInt8>, hashVal: UInt64): ExternalString {
        if (input.size <= SemverString.MAX_INLINE_LEN) {
            return ExternalString(value: SemverString(input), hash: hashVal)
        }

        let existing = stringPool.get(hashVal)
        if (existing != None) {
            return ExternalString(value: existing.getOrThrow(), hash: hashVal)
        }

        // 新条目: 复制到缓冲区
        let newStr = appendToBuffer(input)
        stringPool.put(hashVal, newStr)
        return ExternalString(value: newStr, hash: hashVal)
    }

    /// 带哈希追加 SemverString - 对应 Bun Builder.appendWithHash(String)
    public func appendWithHash(input: Array<UInt8>, hashVal: UInt64): SemverString {
        if (input.size <= SemverString.MAX_INLINE_LEN) {
            return SemverString(input)
        }

        let existing = stringPool.get(hashVal)
        if (existing != None) {
            return existing.getOrThrow()
        }

        // 新条目: 复制到缓冲区
        let newStr = appendToBuffer(input)
        stringPool.put(hashVal, newStr)
        return newStr
    }

    // 将数据复制到内部缓冲区并返回 SemverString
    private func appendToBuffer(input: Array<UInt8>): SemverString {
        if (let Some(buf) = buffer) {
            let start = writtenLen
            var i: Int64 = 0
            while (i < input.size) {
                buf[start + i] = input[i]
                i += 1
            }
            writtenLen += input.size

            // 构建从缓冲区切片的 SemverString
            let result = SemverString()
            result.isInlineFlag = false
            result.externalBuf = buf
            result.offset = start
            result.length = input.size
            return result
        }
        // 没有缓冲区时直接创建
        return SemverString(input)
    }
}

// ============================================================================
// SemverString.Buf - 锁文件字符串缓冲区
// 严格翻译自: src/install_types/SemverString.zig - String.Buf
//   pub const Buf = struct {
//       bytes: *std.ArrayListUnmanaged(u8),
//       allocator: std.mem.Allocator,
//       pool: *Builder.StringPool,
//       pub fn init(lockfile), append, appendWithHash, appendExternal, appendExternalWithHash
//   }
//   用于从锁文件读取/写入字符串, 带去重池
// ============================================================================

/// 锁文件字符串缓冲区 - 对应 Bun String.Buf
/// 翻译自: src/install_types/SemverString.zig - String.Buf
///   pub const Buf = struct {
///       bytes: *std.ArrayListUnmanaged(u8),
///       allocator: std.mem.Allocator,
///       pool: *Builder.StringPool,
///   }
public class SemverStringBuf {
    /// 字节缓冲区 - 对应 Bun: bytes: *std.ArrayListUnmanaged(u8)
    public var bytes: ArrayList<UInt8>

    /// 字符串池 - 对应 Bun: pool: *Builder.StringPool
    public var pool: HashMap<UInt64, SemverString>

    public init() {
        bytes = ArrayList<UInt8>()
        pool = HashMap<UInt64, SemverString>()
    }

    /// 追加字符串 - 对应 Bun Buf.append
    /// 翻译自:
    ///   pub fn append(this: *Buf, str: string) OOM!String {
    ///       if (canInline(str)) return String.initInline(str);
    ///       const hash = Builder.stringHash(str);
    ///       const entry = try this.pool.getOrPut(hash);
    ///       if (entry.found_existing) return entry.value_ptr.*;
    ///       const new = try String.initAppend(this.allocator, this.bytes, str);
    ///       entry.value_ptr.* = new;
    ///       return new;
    ///   }
    public func append(input: String): SemverString {
        if (SemverString.canInlineStr(input)) {
            return SemverString(input)
        }
        let hashVal = SemverStringBuilder.stringHashStr(input)
        return appendWithHash(input, hashVal)
    }

    /// 带哈希追加字符串 - 对应 Bun Buf.appendWithHash
    public func appendWithHash(input: String, hashVal: UInt64): SemverString {
        if (SemverString.canInlineStr(input)) {
            return SemverString(input)
        }
        let existing = pool.get(hashVal)
        if (existing != None) {
            return existing.getOrThrow()
        }
        // 新条目
        let newStr = appendBytes(input)
        pool.put(hashVal, newStr)
        return newStr
    }

    /// 追加 ExternalString - 对应 Bun Buf.appendExternal
    /// 翻译自:
    ///   pub fn appendExternal(this: *Buf, str: string) OOM!ExternalString {
    ///       const hash = Builder.stringHash(str);
    ///       if (canInline(str)) return .{ .value = String.initInline(str), .hash = hash };
    ///       const entry = try this.pool.getOrPut(hash);
    ///       if (entry.found_existing) return .{ .value = entry.value_ptr.*, .hash = hash };
    ///       const new = try String.initAppend(this.allocator, this.bytes, str);
    ///       entry.value_ptr.* = new;
    ///       return .{ .value = new, .hash = hash };
    ///   }
    public func appendExternal(input: String): ExternalString {
        let hashVal = SemverStringBuilder.stringHashStr(input)
        if (SemverString.canInlineStr(input)) {
            return ExternalString(value: SemverString(input), hash: hashVal)
        }
        let existing = pool.get(hashVal)
        if (existing != None) {
            return ExternalString(value: existing.getOrThrow(), hash: hashVal)
        }
        let newStr = appendBytes(input)
        pool.put(hashVal, newStr)
        return ExternalString(value: newStr, hash: hashVal)
    }

    /// 带哈希追加 ExternalString - 对应 Bun Buf.appendExternalWithHash
    public func appendExternalWithHash(input: String, hashVal: UInt64): ExternalString {
        if (SemverString.canInlineStr(input)) {
            return ExternalString(value: SemverString(input), hash: hashVal)
        }
        let existing = pool.get(hashVal)
        if (existing != None) {
            return ExternalString(value: existing.getOrThrow(), hash: hashVal)
        }
        let newStr = appendBytes(input)
        pool.put(hashVal, newStr)
        return ExternalString(value: newStr, hash: hashVal)
    }

    // 将字符串的字节追加到内部缓冲区, 返回外部模式的 SemverString
    private func appendBytes(input: String): SemverString {
        let start = bytes.size
        for (c in input) {
            bytes.append(UInt8(c.value))
        }
        let result = SemverString()
        result.isInlineFlag = false
        // 使用当前缓冲区快照
        result.externalBuf = bytes.toArray()
        result.offset = start
        result.length = input.size
        return result
    }
}

// ============================================================================
// SemverString.HashContext - 哈希上下文
// 严格翻译自: src/install_types/SemverString.zig - String.HashContext
//   pub const HashContext = struct {
//       arg_buf: []const u8,
//       existing_buf: []const u8,
//       pub fn eql(ctx, arg, existing) bool { ... }
//       pub fn hash(ctx, arg) u64 { ... }
//   }
//   用于 HashMap 中以 SemverString 为键时的哈希和相等比较
// ============================================================================

/// SemverString 哈希上下文 - 对应 Bun String.HashContext
/// 翻译自: src/install_types/SemverString.zig - String.HashContext
///   pub const HashContext = struct {
///       arg_buf: []const u8,
///       existing_buf: []const u8,
///   }
public class SemverStringHashContext {
    public var argBuf: ?Array<UInt8>
    public var existingBuf: ?Array<UInt8>

    public init() {
        argBuf = None
        existingBuf = None
    }

    public init(argBuf: ?Array<UInt8>, existingBuf: ?Array<UInt8>) {
        this.argBuf = argBuf
        this.existingBuf = existingBuf
    }

    /// 相等比较 - 对应 Bun HashContext.eql
    /// 翻译自: pub fn eql(ctx: HashContext, arg: String, existing: String) bool {
    ///     return arg.eql(existing, ctx.arg_buf, ctx.existing_buf);
    /// }
    public func eql(arg: SemverString, existing: SemverString): Bool {
        return arg.eql(existing, argBuf, existingBuf)
    }

    /// 哈希计算 - 对应 Bun HashContext.hash
    /// 翻译自: pub fn hash(ctx: HashContext, arg: String) u64 {
    ///     const str = arg.slice(ctx.arg_buf);
    ///     return bun.hash(str);
    /// }
    public func hash(arg: SemverString): UInt64 {
        let s = arg.slice(argBuf)
        return Wyhash11.hash(s)
    }
}

// ============================================================================
// SemverString.ArrayHashContext - 数组哈希上下文
// 严格翻译自: src/install_types/SemverString.zig - String.ArrayHashContext
//   pub const ArrayHashContext = struct {
//       arg_buf: []const u8,
//       existing_buf: []const u8,
//       pub fn eql(ctx, arg, existing, _: usize) bool { ... }
//       pub fn hash(ctx, arg) u32 { ... }
//   }
//   用于数组 HashMap 中以 SemverString 为键时的哈希和相等比较
// ============================================================================

/// SemverString 数组哈希上下文 - 对应 Bun String.ArrayHashContext
/// 翻译自: src/install_types/SemverString.zig - String.ArrayHashContext
///   pub const ArrayHashContext = struct {
///       arg_buf: []const u8,
///       existing_buf: []const u8,
///   }
public class SemverStringArrayHashContext {
    public var argBuf: ?Array<UInt8>
    public var existingBuf: ?Array<UInt8>

    public init() {
        argBuf = None
        existingBuf = None
    }

    public init(argBuf: ?Array<UInt8>, existingBuf: ?Array<UInt8>) {
        this.argBuf = argBuf
        this.existingBuf = existingBuf
    }

    /// 相等比较 - 对应 Bun ArrayHashContext.eql
    /// 翻译自: pub fn eql(ctx, arg, existing, _: usize) bool {
    ///     return arg.eql(existing, ctx.arg_buf, ctx.existing_buf);
    /// }
    public func eql(arg: SemverString, existing: SemverString, index: Int64): Bool {
        return arg.eql(existing, argBuf, existingBuf)
    }

    /// 哈希计算 - 对应 Bun ArrayHashContext.hash
    /// 翻译自: pub fn hash(ctx, arg) u32 {
    ///     const str = arg.slice(ctx.arg_buf);
    ///     return @as(u32, @truncate(bun.hash(str)));
    /// }
    public func hash(arg: SemverString): UInt32 {
        let s = arg.slice(argBuf)
        return UInt32(Wyhash11.hash(s) & UInt64(0xFFFFFFFF))
    }
}

// ============================================================================
// SemverString.Sorter - 排序器
// 严格翻译自: src/install_types/SemverString.zig - String.Sorter
//   pub fn Sorter(comptime direction: enum { asc, desc }) type {
//       return struct {
//           lhs_buf: []const u8,
//           rhs_buf: []const u8,
//           pub fn lessThan(this, lhs, rhs) bool {
//               return lhs.order(&rhs, this.lhs_buf, this.rhs_buf) ==
//                   if (comptime direction == .asc) .lt else .gt
//           }
//       }
//   }
// ============================================================================

/// 排序方向
public enum SortDirection {
    | Asc   // 升序
    | Desc  // 降序
}

/// SemverString 排序器 - 对应 Bun String.Sorter
/// 翻译自: src/install_types/SemverString.zig - String.Sorter
///   pub fn Sorter(comptime direction: enum { asc, desc }) type { ... }
public class SemverStringSorter {
    public var direction: SortDirection
    public var lhsBuf: ?Array<UInt8>
    public var rhsBuf: ?Array<UInt8>

    public init(direction: SortDirection) {
        this.direction = direction
        lhsBuf = None
        rhsBuf = None
    }

    public init(direction: SortDirection, lhsBuf: ?Array<UInt8>, rhsBuf: ?Array<UInt8>) {
        this.direction = direction
        this.lhsBuf = lhsBuf
        this.rhsBuf = rhsBuf
    }

    /// 比较函数 - 对应 Bun Sorter.lessThan
    /// 翻译自: pub fn lessThan(this, lhs, rhs) bool {
    ///     return lhs.order(&rhs, this.lhs_buf, this.rhs_buf) ==
    ///         if (comptime direction == .asc) .lt else .gt
    /// }
    public func lessThan(lhs: SemverString, rhs: SemverString): Bool {
        let ord = lhs.order(rhs, lhsBuf, rhsBuf)
        match (direction) {
            case Asc => ord < 0
            case Desc => ord > 0
        }
    }
}

// ============================================================================
// SemverString.Formatter - 格式化器
// 严格翻译自: src/install_types/SemverString.zig - String.Formatter
//   pub const Formatter = struct {
//       str: *const String,
//       buf: string,
//       pub fn format(formatter, writer) !void {
//           try writer.writeAll(str.slice(formatter.buf));
//       }
//   }
// ============================================================================

/// SemverString 格式化器 - 对应 Bun String.Formatter
public class SemverStringFormatter {
    public var str: SemverString
    public var buf: ?Array<UInt8>

    public init(str: SemverString, buf: ?Array<UInt8>) {
        this.str = str
        this.buf = buf
    }

    /// 格式化为字符串 - 对应 Bun Formatter.format
    /// 翻译自: pub fn format(formatter, writer) !void {
    ///     try writer.writeAll(str.slice(formatter.buf));
    /// }
    public func format(): String {
        return str.slice(buf)
    }
}

// ============================================================================
// SemverString.JsonFormatter - JSON 格式化器
// 严格翻译自: src/install_types/SemverString.zig - String.JsonFormatter
//   pub const JsonFormatter = struct {
//       str: *const String,
//       buf: string,
//       opts: Options,
//       pub const Options = struct { quote: bool = true }
//       pub fn format(formatter, writer) !void {
//           try writer.print("{f}", .{bun.fmt.formatJSONStringUTF8(formatter.str.slice(formatter.buf), .{ .quote = formatter.opts.quote })});
//       }
//   }
// ============================================================================

/// JSON 格式化选项 - 对应 Bun String.JsonFormatter.Options
public class JsonFormatOptions {
    /// 是否用引号包裹
    public var quote: Bool

    public init() {
        quote = true
    }

    public init(quote: Bool) {
        this.quote = quote
    }
}

/// SemverString JSON 格式化器 - 对应 Bun String.JsonFormatter
public class SemverStringJsonFormatter {
    public var str: SemverString
    public var buf: ?Array<UInt8>
    public var opts: JsonFormatOptions

    public init(str: SemverString, buf: ?Array<UInt8>, opts: JsonFormatOptions) {
        this.str = str
        this.buf = buf
        this.opts = opts
    }

    /// 格式化为 JSON 字符串 - 对应 Bun JsonFormatter.format
    /// 翻译自: pub fn format(formatter, writer) !void {
    ///     try writer.print("{f}", .{bun.fmt.formatJSONStringUTF8(formatter.str.slice(formatter.buf), .{ .quote = formatter.opts.quote })});
    /// }
    public func format(): String {
        let s = str.slice(buf)
        if (opts.quote) {
            return "\"" + escapeJsonString(s) + "\""
        }
        return escapeJsonString(s)
    }

    // JSON 字符串转义 (基本实现)
    private func escapeJsonString(s: String): String {
        var sb = StringBuilder()
        for (c in s) {
            let v = c.value
            if (v == 0x22) {        // "
                sb.append("\\\"")
            } else if (v == 0x5C) { // \
                sb.append("\\\\")
            } else if (v == 0x0A) { // \n
                sb.append("\\n")
            } else if (v == 0x0D) { // \r
                sb.append("\\r")
            } else if (v == 0x09) { // \t
                sb.append("\\t")
            } else if (v < 0x20) {  // 控制字符
                sb.append(c)
            } else {
                sb.append(c)
            }
        }
        return sb.toString()
    }
}

// ============================================================================
// SemverString.StorePathFormatter - 存储路径格式化器
// 严格翻译自: src/install_types/SemverString.zig - String.StorePathFormatter
//   pub const StorePathFormatter = struct {
//       str: *const String,
//       buf: string,
//       pub fn format(this, writer) !void {
//           for (this.str.slice(this.buf)) |c| {
//               const n = switch (c) {
//                   '/' => '+', '\\' => '+', ':' => '+', '#' => '+',
//                   else => c,
//               };
//               try writer.writeByte(n);
//           }
//       }
//   }
// ============================================================================

/// 存储路径格式化器 - 对应 Bun String.StorePathFormatter
/// 将路径中的特殊字符替换为 '+'
/// 翻译自: src/install_types/SemverString.zig - String.StorePathFormatter
public class StorePathFormatter {
    public var str: SemverString
    public var buf: ?Array<UInt8>

    public init(str: SemverString, buf: ?Array<UInt8>) {
        this.str = str
        this.buf = buf
    }

    /// 格式化为存储路径 - 对应 Bun StorePathFormatter.format
    /// 翻译自:
    ///   pub fn format(this, writer) !void {
    ///       for (this.str.slice(this.buf)) |c| {
    ///           const n = switch (c) {
    ///               '/' => '+', '\\' => '+', ':' => '+', '#' => '+',
    ///               else => c,
    ///           };
    ///           try writer.writeByte(n);
    ///       }
    ///   }
    public func format(): String {
        let s = str.slice(buf)
        var sb = StringBuilder()
        for (c in s) {
            let v = c.value
            if (v == 0x2F) {        // /
                sb.append(Rune('+'))
            } else if (v == 0x5C) { // \
                sb.append(Rune('+'))
            } else if (v == 0x3A) { // :
                sb.append(Rune('+'))
            } else if (v == 0x23) { // #
                sb.append(Rune('+'))
            } else {
                sb.append(c)
            }
        }
        return sb.toString()
    }
}
