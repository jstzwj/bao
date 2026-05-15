// bao_core - 带哈希的字符串视图
// 严格翻译自: src/string/HashedString.zig
//   const HashedString = @This();
//   ptr: [*]const u8, len: u32, hash: u32,
//   Bun: 存储裸指针 + 长度 + wyhash 哈希值，用于快速字符串比较
//   仓颉: 存储字节数组引用 + 偏移量 + 长度 + wyhash 哈希值
package bao_core

/// 带预计算哈希的字符串视图 - 严格对应 Bun HashedString
/// 用于需要频繁比较的场景 (标识符查找、属性名匹配等)
/// Bun: struct { ptr, len, hash } - 零拷贝字符串视图
/// 仓颉: class { source, offset, len, hash } - GC 管理的字符串视图
public class HashedStringView {
    /// 源数据引用 (对应 Bun ptr: [*]const u8)
    public let source: Array<UInt8>
    /// 起始偏移
    public let offset: Int64
    /// 字节长度 (对应 Bun len: u32)
    public let len: UInt32
    /// 预计算哈希值 (对应 Bun hash: u32，使用 wyhash)
    public let hash: UInt32

    /// 空值常量 - 对应 Bun HashedString.empty
    /// Bun: .{ .ptr = 0xDEADBEEF, .len = 0, .hash = 0 }
    public static let EMPTY = HashedStringView(
        source: [],
        offset: 0,
        len: UInt32(0),
        hash: UInt32(0)
    )

    private init(source: Array<UInt8>, offset: Int64, len: UInt32, hash: UInt32) {
        this.source = source
        this.offset = offset
        this.len = len
        this.hash = hash
    }

    /// 初始化并计算哈希 - 对应 Bun HashedString.init(buf)
    /// pub fn init(buf: []const u8) HashedString {
    ///     return HashedString{
    ///         .ptr = buf.ptr,
    ///         .len = @truncate(buf.len),
    ///         .hash = @truncate(bun.hash(buf)),
    ///     };
    /// }
    public init(buf: Array<UInt8>) {
        this.source = buf
        this.offset = 0
        this.len = UInt32(buf.size)
        this.hash = HashedStringView.wyhash32(buf)
    }

    /// 初始化带偏移的子切片
    public init(buf: Array<UInt8>, offset: Int64, length: Int64) {
        this.source = buf
        this.offset = offset
        this.len = UInt32(length)
        var sub = Array<UInt8>()
        for (i in offset..(offset + length)) {
            if (i >= 0 && i < buf.size) {
                sub.append(buf[Int64(i)])
            }
        }
        this.hash = HashedStringView.wyhash32(sub)
    }

    /// 从原生字符串初始化
    public init(s: String) {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        this.source = bytes
        this.offset = 0
        this.len = UInt32(bytes.size)
        this.hash = HashedStringView.wyhash32(bytes)
    }

    /// 不计算哈希的初始化 - 对应 Bun HashedString.initNoHash
    /// pub fn initNoHash(buf: []const u8) HashedString {
    ///     return .{ .ptr = buf.ptr, .len = @truncate(buf.len), .hash = 0 };
    /// }
    public static func initNoHash(buf: Array<UInt8>): HashedStringView {
        return HashedStringView(source: buf, offset: 0, len: UInt32(buf.size), hash: UInt32(0))
    }

    /// 比较相等 - 对应 Bun HashedString.eql
    /// ((max(this.hash, other.hash) > 0 && this.hash == other.hash) ||
    ///  (this.ptr == other.ptr)) && this.len == other.len
    public func eql(other: HashedStringView): Bool {
        if (this.len != other.len) {
            return false
        }
        // 如果哈希值不同(且非零)，直接返回 false
        if (this.hash > 0 && other.hash > 0 && this.hash != other.hash) {
            return false
        }
        // 哈希相同或为零，逐字节比较
        let s1 = str()
        let s2 = other.str()
        if (s1.size != s2.size) {
            return false
        }
        for (i in 0..s1.size) {
            if (s1[Int64(i)] != s2[Int64(i)]) {
                return false
            }
        }
        return true
    }

    /// 与字节数组比较
    public func eqlBytes(other: Array<UInt8>): Bool {
        if (Int64(this.len) != other.size) {
            return false
        }
        return this.hash == HashedStringView.wyhash32(other)
    }

    /// 与原生字符串比较
    public func eqlString(other: String): Bool {
        if (Int64(this.len) != other.length) {
            return false
        }
        let bytes = str()
        let chars = other.toArray()
        if (bytes.size != chars.size) {
            return false
        }
        for (i in 0..bytes.size) {
            if (bytes[Int64(i)] != UInt8(chars[Int64(i)].value)) {
                return false
            }
        }
        return true
    }

    /// 获取底层字节切片 - 对应 Bun HashedString.str → []const u8
    /// pub fn str(this: HashedString) []const u8 {
    ///     return this.ptr[0..this.len];
    /// }
    public func str(): Array<UInt8> {
        var result = Array<UInt8>()
        let end = offset + Int64(len)
        for (i in offset..end) {
            if (i >= 0 && i < source.size) {
                result.append(source[Int64(i)])
            }
        }
        return result
    }

    /// 转为仓颉字符串
    public func toString(): String {
        var sb = StringBuilder()
        let bytes = str()
        for (b in bytes) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return len == UInt32(0)
    }

    /// 长度
    public func length(): Int64 {
        return Int64(len)
    }

    /// WyHash-32 计算 (与 Bun 的 bun.hash 输出截断为 u32 一致)
    private static func wyhash32(data: Array<UInt8>): UInt32 {
        if (data.size == 0) {
            return UInt32(0)
        }
        return UInt32(wyhash64(data) & UInt64(0xFFFFFFFF))
    }

    /// WyHash-64 完整实现
    private static func wyhash64(data: Array<UInt8>): UInt64 {
        let len = data.size
        let WYP0: UInt64 = 0xa0761d6478bd642f
        let WYP1: UInt64 = 0xe7037ed1a0b428db
        let WYP2: UInt64 = 0x8ebc6af09c88c6e3
        let WYP3: UInt64 = 0x589965cc75374cc3
        let WYP4: UInt64 = 0x1d8e4e27c47d124f

        var seed = WYP0

        if (len <= 16) {
            let a = readUInt64(data, 0, len)
            let b = readUInt64(data, if (len > 8) { len - 8 } else { 0 }, len)
            seed = seed ^ (wymix(a ^ WYP1, b ^ WYP2))
            return wymix(seed, UInt64(len) ^ WYP0)
        }

        var i: Int64 = 0
        if (len <= 64) {
            while (i + 16 <= len) {
                let a = readUInt64(data, i, len)
                let b = readUInt64(data, i + 8, len)
                seed = seed ^ (wymix(a ^ WYP1, b ^ WYP2))
                i += 16
            }
            if (i < len) {
                let a = readUInt64(data, len - 8, len)
                let b = readUInt64(data, len - 16, len)
                seed = seed ^ (wymix(a ^ WYP3, b ^ WYP4))
            }
            return wymix(seed, UInt64(len) ^ WYP0)
        }

        var see1 = seed
        var see2 = seed
        while (i + 64 <= len) {
            seed = seed ^ (wymix(readUInt64(data, i, len) ^ WYP1, readUInt64(data, i + 8, len) ^ WYP2))
            see1 = see1 ^ (wymix(readUInt64(data, i + 16, len) ^ WYP3, readUInt64(data, i + 24, len) ^ WYP4))
            see2 = see2 ^ (wymix(readUInt64(data, i + 32, len) ^ WYP2, readUInt64(data, i + 40, len) ^ WYP1))
            seed = seed ^ (wymix(readUInt64(data, i + 48, len) ^ WYP4, readUInt64(data, i + 56, len) ^ WYP3))
            i += 64
        }
        while (i + 16 <= len) {
            seed = seed ^ (wymix(readUInt64(data, i, len) ^ WYP1, readUInt64(data, i + 8, len) ^ WYP2))
            i += 16
        }
        if (i < len) {
            seed = seed ^ (wymix(readUInt64(data, len - 16, len) ^ WYP1, readUInt64(data, len - 8, len) ^ WYP2))
        }
        return wymix(seed ^ see1 ^ see2, UInt64(len) ^ WYP0)
    }

    private static func wymix(a: UInt64, b: UInt64): UInt64 {
        var x = a
        var y = b
        x = x ^ (x >> 32)
        y = y ^ (y >> 32)
        return (x * 0xa0761d6478bd642f) ^ (y * 0xe7037ed1a0b428db)
    }

    private static func readUInt64(data: Array<UInt8>, offset: Int64, limit: Int64): UInt64 {
        var result: UInt64 = 0
        let end = if (offset + 8 <= limit) { offset + 8 } else { limit }
        var shift: UInt64 = 0
        for (i in offset..end) {
            if (i >= 0 && i < data.size) {
                result = result | (UInt64(data[Int64(i)]) << shift)
                shift += 8
            }
        }
        return result
    }
}
