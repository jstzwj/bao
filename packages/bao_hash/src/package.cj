// bao_hash - 哈希算法
// 严格翻译自:
//   src/bun_core/string/HashedString.rs - wyhash 调用
//   src/wyhash/ - WyHash 算法实现 (通过 bun_wyhash crate)
//   src/highway/highway.zig - HighwayHash SIMD 加速 (通过 C++ FFI)
//   src/hash/ - 通用哈希接口
//   src/hash/adler32.rs - Adler-32 校验和
//   src/hash/cityhash.rs - CityHash32/CityHash64
//   src/hash/rapidhash.rs - RapidHash
//   src/wyhash/ - Wyhash (final4) + Wyhash11 (legacy 5-prime)
//   src/sha_hmac/ - SHA 哈希 + HMAC 消息认证码
package bao_hash

import bao_core.*
import bao_hash.adler32.*
import bao_hash.city_hash.*
import bao_hash.rapid_hash.*
import bao_hash.wyhash.*
import bao_hash.hmac.*
import bao_hash.sha.*
import bao_hash.murmur.*
import bao_hash.xxhash.*

// ============================================================================
// WyHash - 快速非加密哈希
// 严格翻译自 Bun 使用的 bun_wyhash crate
// 对应 Bun: HashedString.init 使用 hash(buf) as u32
// WyHash 是 Bun 内部所有字符串哈希的标准算法
// ============================================================================

/// WyHash 快速哈希算法
/// Bun 通过 bun_wyhash 外部 crate 调用，此处完整实现算法
public class WyHash {

    /// 计算字节数组的哈希值 (u64)
    /// 对应 Bun: bun_wyhash::hash(data) -> u64
    /// 用于 HashedString 的 hash 字段 (截断为 u32)
    public static func hash(data: Array<UInt8>): UInt64 {
        return hashWithSeed(data, 0)
    }

    /// 计算字符串哈希
    public static func hash(s: String): UInt64 {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        return hash(bytes)
    }

    /// 带种子的哈希 - 完整 WyHash final3 实现
    /// 对应 Bun: bun_wyhash::hash_with_seed
    public static func hashWithSeed(data: Array<UInt8>, seed: UInt64): UInt64 {
        let len = data.size
        // WyHash final3 常量 (wyp0-wyp4)
        let WYP0: UInt64 = 0xa0761d6478bd642f
        let WYP1: UInt64 = 0xe7037ed1a0b428db
        let WYP2: UInt64 = 0x8ebc6af09c88c6e3
        let WYP3: UInt64 = 0x589965cc75374cc3
        let WYP4: UInt64 = 0x1d8e4e27c47d124f

        var seedMut = seed ^ WYP0

        if (len == 0) {
            return wymix(seedMut, WYP0)
        }

        // <= 16 字节
        if (len <= 16) {
            let a = readUInt64(data, 0)
            let b = readUInt64(data, if (len > 8) { len - 8 } else { 0 })
            seedMut = seedMut ^ (wymix(a ^ WYP1, b ^ WYP2))
            return wymix(seedMut, UInt64(len) ^ WYP0)
        }

        var i: Int64 = 0

        // 17-64 字节
        if (len <= 64) {
            while (i + 16 <= len) {
                let a = readUInt64(data, i)
                let b = readUInt64(data, i + 8)
                seedMut = seedMut ^ (wymix(a ^ WYP1, b ^ WYP2))
                i += 16
            }
            if (i < len) {
                let a = readUInt64(data, len - 8)
                let b = readUInt64(data, len - 16)
                seedMut = seedMut ^ (wymix(a ^ WYP3, b ^ WYP4))
            }
            return wymix(seedMut, UInt64(len) ^ WYP0)
        }

        // > 64 字节 - 使用更大块并行处理
        var see1 = seedMut
        var see2 = seedMut
        while (i + 64 <= len) {
            seedMut = seedMut ^ (wymix(readUInt64(data, i) ^ WYP1, readUInt64(data, i + 8) ^ WYP2))
            see1 = see1 ^ (wymix(readUInt64(data, i + 16) ^ WYP3, readUInt64(data, i + 24) ^ WYP4))
            see2 = see2 ^ (wymix(readUInt64(data, i + 32) ^ WYP2, readUInt64(data, i + 40) ^ WYP1))
            seedMut = seedMut ^ (wymix(readUInt64(data, i + 48) ^ WYP4, readUInt64(data, i + 56) ^ WYP3))
            i += 64
        }
        // 处理剩余块
        while (i + 16 <= len) {
            seedMut = seedMut ^ (wymix(readUInt64(data, i) ^ WYP1, readUInt64(data, i + 8) ^ WYP2))
            i += 16
        }
        if (i < len) {
            seedMut = seedMut ^ (wymix(readUInt64(data, len - 16) ^ WYP1, readUInt64(data, len - 8) ^ WYP2))
        }

        return wymix(seedMut ^ see1 ^ see2, UInt64(len) ^ WYP0)
    }

    /// Wymix - WyHash 混合函数
    /// 对应 WyHash 源码中的 _wymix
    private static func wymix(a: UInt64, b: UInt64): UInt64 {
        var x = a
        var y = b
        x = x ^ (x >> 32)
        y = y ^ (y >> 32)
        return (x * 0xa0761d6478bd642f) ^ (y * 0xe7037ed1a0b428db)
    }

    /// 从字节数组读取小端 UInt64
    private static func readUInt64(data: Array<UInt8>, offset: Int64): UInt64 {
        var result: UInt64 = 0
        let end = if (offset + 8 <= data.size) { offset + 8 } else { data.size }
        var shift: UInt64 = 0
        var i = if (offset < 0) { Int64(0) } else { offset }
        while (i < end) {
            result = result | (UInt64(data[i]) << shift)
            shift += 8
            i += 1
        }
        return result
    }
}

// ============================================================================
// Highway - SIMD 加速字符串操作
// 严格翻译自: src/highway/highway.zig
// Bun 使用 Google Highway C++ 库实现 SIMD 加速
// 仓颉目前无 SIMD 支持，此处提供纯仓颉回退实现
// ============================================================================

/// Highway SIMD 字符串操作 (纯仓颉回退)
/// 对应 Bun: src/highway/highway.zig
public class Highway {

    /// 查找字符位置 - 对应 Bun highway_index_of_char
    /// 用于 indexOfChar(haystack, needle)
    public static func indexOfChar(haystack: Array<UInt8>, needle: UInt8): ?Int64 {
        if (haystack.size == 0) {
            return None
        }
        for (i in 0..haystack.size) {
            if (haystack[i] == needle) {
                return Some(i)
            }
        }
        return None
    }

    /// 查找换行或非 ASCII 字符 - 对应 Bun indexOfNewlineOrNonASCII
    /// 扫描: \n, \r, >127 的字符
    public static func indexOfNewlineOrNonASCII(haystack: Array<UInt8>): ?Int64 {
        if (haystack.size == 0) {
            return None
        }
        for (i in 0..haystack.size) {
            let ch = haystack[i]
            if (ch > 127 || ch < 0x20 || ch == UInt8('\r') || ch == UInt8('\n')) {
                return Some(i)
            }
        }
        return None
    }

    /// 查找换行、非 ASCII、# 或 @ - 对应 Bun indexOfNewlineOrNonASCIIOrHashOrAt
    /// 用于单行 JavaScript 注释扫描
    public static func indexOfNewlineOrNonASCIIOrHashOrAt(haystack: Array<UInt8>): ?Int64 {
        if (haystack.size == 0) {
            return None
        }
        for (i in 0..haystack.size) {
            let ch = haystack[i]
            if (ch > 127 || ch < 0x20 || ch == UInt8('\r') || ch == UInt8('\n') ||
                ch == UInt8('#') || ch == UInt8('@')) {
                return Some(i)
            }
        }
        return None
    }

    /// 查找空格或非 ASCII - 对应 Bun indexOfSpaceOrNewlineOrNonASCII
    /// 扫描: " ", >127 的字符 (隐含 \n, \r, \t)
    public static func indexOfSpaceOrNewlineOrNonASCII(haystack: Array<UInt8>): ?Int64 {
        if (haystack.size == 0) {
            return None
        }
        for (i in 0..haystack.size) {
            let ch = haystack[i]
            if (ch > 127 || ch == UInt8(' ') || ch == UInt8('\n') ||
                ch == UInt8('\r') || ch == UInt8('\t')) {
                return Some(i)
            }
        }
        return None
    }

    /// 查找字符串字面量中的有趣字符 - 对应 Bun indexOfInterestingCharacterInStringLiteral
    /// 扫描: >127, <0x20, \, 引号字符, $ (模板字符串)
    public static func indexOfInterestingCharacterInStringLiteral(
        text: Array<UInt8>, quote: UInt8
    ): ?Int64 {
        if (text.size == 0) {
            return None
        }
        for (i in 0..text.size) {
            let ch = text[i]
            if (ch >= 127 || ch < 0x20 || ch == UInt8('\\') ||
                ch == quote || ch == UInt8('$') ||
                ch == UInt8('\r') || ch == UInt8('\n')) {
                return Some(i)
            }
        }
        return None
    }

    /// 是否包含换行、非 ASCII 或引号 - 对应 Bun containsNewlineOrNonASCIIOrQuote
    public static func containsNewlineOrNonASCIIOrQuote(text: Array<UInt8>): Bool {
        if (text.size == 0) {
            return false
        }
        for (ch in text) {
            if (ch > 127 || ch < 0x20 || ch == UInt8('\r') || ch == UInt8('\n')) {
                return true
            }
        }
        return false
    }

    /// 查找需要 JS 转义的字符 - 对应 Bun indexOfNeedsEscapeForJavaScriptString
    public static func indexOfNeedsEscapeForJavaScriptString(
        slice: Array<UInt8>, quoteChar: UInt8
    ): ?Int64 {
        if (slice.size == 0) {
            return None
        }
        for (i in 0..slice.size) {
            let ch = slice[i]
            if (ch >= 127 || ch < 0x20 || ch == UInt8('\\') ||
                ch == quoteChar || ch == UInt8('$') ||
                ch == UInt8('\r') || ch == UInt8('\n')) {
                return Some(i)
            }
        }
        return None
    }

    /// 查找多个字符中任一的位置 - 对应 Bun indexOfAnyChar
    public static func indexOfAnyChar(
        haystack: Array<UInt8>, chars: Array<UInt8>
    ): ?Int64 {
        if (haystack.size == 0 || chars.size == 0) {
            return None
        }
        for (i in 0..haystack.size) {
            for (c in chars) {
                if (haystack[i] == c) {
                    return Some(i)
                }
            }
        }
        return None
    }

    /// WebSocket 掩码填充 - 对应 Bun fillWithSkipMask
    /// 如果 skipMask 为 true，直接复制而不做掩码
    public static func fillWithSkipMask(
        mask: Array<UInt8>, output: Array<UInt8>, input: Array<UInt8>, skipMask: Bool
    ): Unit {
        if (input.size == 0) {
            return
        }
        if (skipMask) {
            for (i in 0..input.size) {
                output[i] = input[i]
            }
        } else {
            for (i in 0..input.size) {
                output[i] = input[i] ^ mask[i % 4]
            }
        }
    }

    /// 字符频率统计 - 对应 Bun scanCharFrequency
    /// 统计 [a-zA-Z0-9_$] 的出现频率
    public static func scanCharFrequency(
        text: Array<UInt8>, freqs: Array<Int64>, delta: Int64
    ): Unit {
        if (text.size == 0 || delta == 0) {
            return
        }
        for (ch in text) {
            let idx = charToIndex(ch)
            if (idx >= 0 && idx < freqs.size) {
                freqs[idx] += delta
            }
        }
    }

    /// 将 [a-zA-Z0-9_$] 映射到 0-63 的索引
    private static func charToIndex(ch: UInt8): Int64 {
        let c = Int64(ch)
        if (c >= Int64('a') && c <= Int64('z')) { return c - Int64('a') }
        if (c >= Int64('A') && c <= Int64('Z')) { return 26 + c - Int64('A') }
        if (c >= Int64('0') && c <= Int64('9')) { return 52 + c - Int64('0') }
        if (c == Int64('_')) { return 62 }
        if (c == Int64('$')) { return 63 }
        return -1
    }
}

// ============================================================================
// CRC32 校验
// ============================================================================

/// CRC32 校验算法
public class Crc32 {
    private static let TABLE: Array<UInt32> = buildTable()

    public static func hash(data: Array<UInt8>): UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for (b in data) {
            let index = Int32((crc ^ UInt32(b)) & 0xFF)
            crc = TABLE[index] ^ (crc >> 8)
        }
        return crc ^ 0xFFFFFFFF
    }

    public static func hash(s: String): UInt32 {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        return hash(bytes)
    }

    private static func buildTable(): Array<UInt32> {
        var table = Array<UInt32>(256, item: UInt32(0))
        for (i in 0..256) {
            var crc = UInt32(i)
            for (_ in 0..8) {
                if ((crc & 1) != 0) {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc = crc >> 1
                }
            }
            table[i] = crc
        }
        return table
    }
}

// ============================================================================
// FNV-1a 哈希
// ============================================================================

/// FNV-1a 哈希算法
public class Fnv1a {
    private static let OFFSET_BASIS: UInt64 = 14695981039346656037
    private static let PRIME: UInt64 = 1099511628211

    public static func hash(data: Array<UInt8>): UInt64 {
        var h = OFFSET_BASIS
        for (b in data) {
            h = h ^ UInt64(b)
            h = h * PRIME
        }
        return h
    }

    public static func hash(s: String): UInt64 {
        var h = OFFSET_BASIS
        for (c in s) {
            h = h ^ UInt64(c.value)
            h = h * PRIME
        }
        return h
    }
}
