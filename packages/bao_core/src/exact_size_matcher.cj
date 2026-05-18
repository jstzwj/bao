// bao_core - 精确大小匹配器
// 严格翻译自: src/bun_core/string/immutable/exact_size_matcher.rs
//   pub struct ExactSizeMatcher<const MAX_BYTES: usize>
//   pub trait ExactSizeInt<const MAX_BYTES: usize> { type T; fn read_le(buf) -> Self::T; }
// Bun: 将短字节切片 (len <= N) 打包为单个无符号整数,
//   以便调用者可以 match/switch 字符串字面量作为整数常量
//   超过 N 的切片映射到 T::MAX ("不匹配" 哨兵值)
//   空切片映射到 0
// 仓颉: 提供等价的精确大小匹配功能
package bao_core

import std.collection.*

// ============================================================================
// ExactSizeMatcher - 精确大小匹配器
// 严格翻译自: src/bun_core/string/immutable/exact_size_matcher.rs
//   Zig: pub fn ExactSizeMatcher(comptime max_bytes: usize) type { return struct { ... } }
//   Rust: pub struct ExactSizeMatcher<const MAX_BYTES: usize>(PhantomData<[u8; MAX_BYTES]>)
//   支持大小: 1, 2, 4, 8, 12, 16
// ============================================================================

/// 精确大小匹配器 - 对应 Bun ExactSizeMatcher
/// Bun: Packs a short byte slice (len <= N) into a single unsigned integer
/// so callers can match/switch on string literals as integer constants.
/// Slices longer than N map to T::MAX (the "no match" sentinel).
public class ExactSizeMatcher {
    private let maxBytes: Int64

    public init(maxBytes: Int64) {
        this.maxBytes = maxBytes
    }

    /// 匹配字节切片 - 对应 Bun ExactSizeMatcher::r#match
    /// Zig: pub fn match(str: anytype) T
    /// 返回: 空切片 → 0, 长度 > maxBytes → MAX, 否则打包为整数
    public func matchBytes(bytes: Array<UInt8>): UInt64 {
        let len = bytes.size
        if (len == 0) {
            return UInt64(0)
        }
        if (len > maxBytes) {
            return UInt64.Max
        }
        // 小端读取
        var result: UInt64 = 0
        var shift: UInt64 = 0
        for (i in 0..len) {
            result = result | (UInt64(bytes[i]) << shift)
            shift += 8
        }
        return result
    }

    /// 匹配字符串 - 对应 Bun ExactSizeMatcher::r#match
    public func matchString(s: String): UInt64 {
        return matchBytes(stringToBytes(s))
    }

    /// 匹配并转小写 - 对应 Bun ExactSizeMatcher::matchLower
    /// Zig: pub fn matchLower(str: anytype) T
    public func matchLower(bytes: Array<UInt8>): UInt64 {
        let len = bytes.size
        if (len == 0) {
            return UInt64(0)
        }
        if (len > maxBytes) {
            return UInt64.Max
        }
        // 小端读取 + 转小写
        var result: UInt64 = 0
        var shift: UInt64 = 0
        for (i in 0..len) {
            var b = bytes[i]
            if (b >= 65 && b <= 90) {  // A-Z → a-z
                b = b + 32
            }
            result = result | (UInt64(b) << shift)
            shift += 8
        }
        return result
    }

    /// 计算常量 case 值 - 对应 Bun ExactSizeMatcher::case
    /// Zig: pub fn case(comptime str: []const u8) T
    public func exactCaseValue(bytes: Array<UInt8>): UInt64 {
        if (bytes.size > maxBytes) {
            throw IllegalArgumentException("str too long for ExactSizeMatcher::case: ${bytes.size} > ${maxBytes}")
        }
        var result: UInt64 = 0
        var shift: UInt64 = 0
        for (i in 0..bytes.size) {
            result = result | (UInt64(bytes[i]) << shift)
            shift += 8
        }
        return result
    }

    private func stringToBytes(s: String): Array<UInt8> {
        var result = ArrayList<UInt8>()
        for (c in s) {
            result.add(c)
        }
        return result.toArray()
    }
}

/// 静态匹配工具 - 对应 Bun exact_case! 宏
/// 提供编译时常量计算等价功能
public class ExactSizeMatcherUtil {
    /// 计算 1 字节 case 值
    public static func exactCase1(b: UInt8): UInt64 {
        return UInt64(b)
    }

    /// 计算 2 字节 case 值 (小端)
    public static func exactCase2(b0: UInt8, b1: UInt8): UInt64 {
        return UInt64(b0) | (UInt64(b1) << 8)
    }

    /// 计算 4 字节 case 值 (小端)
    public static func exactCase4(b0: UInt8, b1: UInt8, b2: UInt8, b3: UInt8): UInt64 {
        return UInt64(b0) | (UInt64(b1) << 8) | (UInt64(b2) << 16) | (UInt64(b3) << 24)
    }

    /// 计算 8 字节 case 值 (小端)
    public static func exactCase8(b0: UInt8, b1: UInt8, b2: UInt8, b3: UInt8,
                                   b4: UInt8, b5: UInt8, b6: UInt8, b7: UInt8): UInt64 {
        return UInt64(b0) | (UInt64(b1) << 8) | (UInt64(b2) << 16) | (UInt64(b3) << 24) |
               (UInt64(b4) << 32) | (UInt64(b5) << 40) | (UInt64(b6) << 48) | (UInt64(b7) << 56)
    }

    /// 从字符串计算 case 值
    public static func exactCase(s: String, maxBytes: Int64): UInt64 {
        let matcher = ExactSizeMatcher(maxBytes)
        var bytes = ArrayList<UInt8>()
        for (c in s) {
            bytes.add(c)
        }
        return matcher.exactCaseValue(bytes.toArray())
    }

    /// 零填充字节数组到指定长度
    /// 对应 Bun __pad<const N: usize>(s: &[u8]) -> [u8; N]
    public static func pad(bytes: Array<UInt8>, n: Int64): Array<UInt8> {
        if (bytes.size > n) {
            throw IllegalArgumentException("str too long for exact_case: ${bytes.size} > ${n}")
        }
        var result = Array<UInt8>(n, { _ => UInt8(0) })
        for (i in 0..bytes.size) {
            result[i] = bytes[i]
        }
        return result
    }
}

/// IllegalArgumentException
public class IllegalArgumentException <: Exception {
    public init(message: String) {
        super(message)
    }
}
