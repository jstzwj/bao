// bao_hash - xxHash 快速哈希算法
// 严格翻译自: 外部 xxhash 库 (XXH64)
//   xxHash 是极快的非加密哈希算法
//   Bun 在缓存等场景使用
package bao_hash

import std.collection.*

// ============================================================================
// xxHash64
// 严格翻译自: xxHash 的 XXH64 算法
//   极快的64位非加密哈希, 适用于缓存键计算
// ============================================================================

/// xxHash64 - 对应 Bun 使用的 xxhash 库
/// 高性能64位哈希, 适用于缓存和哈希表
public class XxHash64 {
    private static let PRIME1: UInt64 = (UInt64(0x9E3779B1) << UInt64(32)) | UInt64(0x85EBCA87)
    private static let PRIME2: UInt64 = (UInt64(0xC2B2AE3D) << UInt64(32)) | UInt64(0x27D4EB4F)
    private static let PRIME3: UInt64 = UInt64(0x165667B19E3779F9)
    private static let PRIME4: UInt64 = (UInt64(0x85EBCA77) << UInt64(32)) | UInt64(0xC2B2AE63)
    private static let PRIME5: UInt64 = UInt64(0x27D4EB2F165667C5)

    /// 计算哈希 (种子为0)
    public static func hash(data: Array<UInt8>): UInt64 {
        return hashWithSeed(data, UInt64(0))
    }

    /// 计算字符串哈希
    public static func hash(s: String): UInt64 {
        var bytes = ArrayList<UInt8>()
        for (c in s) { bytes.add(UInt8(UInt32(c))) }
        return hash(bytes.toArray())
    }

    /// 带种子计算哈希
    public static func hashWithSeed(data: Array<UInt8>, seed: UInt64): UInt64 {
        let len = data.size
        var h64: UInt64

        if (len >= 32) {
            var v1 = seed + PRIME1 + PRIME2
            var v2 = seed + PRIME2
            var v3 = seed
            var v4 = seed - PRIME1

            var i: Int64 = 0
            while (i + 32 <= len) {
                v1 = round(v1, readUInt64(data, i)); i += 8
                v2 = round(v2, readUInt64(data, i)); i += 8
                v3 = round(v3, readUInt64(data, i)); i += 8
                v4 = round(v4, readUInt64(data, i)); i += 8
            }

            h64 = rotl(v1, 1) + rotl(v2, 7) + rotl(v3, 12) + rotl(v4, 18)
            h64 = mergeRound(h64, v1)
            h64 = mergeRound(h64, v2)
            h64 = mergeRound(h64, v3)
            h64 = mergeRound(h64, v4)
        } else {
            h64 = seed + PRIME5
        }

        h64 = h64 + UInt64(len)

        // 处理剩余数据 (8字节一组)
        var i: Int64 = len - (len % 32)
        while (i + 8 <= len) {
            h64 = h64 ^ (round(UInt64(0), readUInt64(data, i)) * PRIME1)
            h64 = rotl(h64, 27) * PRIME4 + PRIME3
            i += 8
        }

        // 处理剩余4字节
        if (i + 4 <= len) {
            h64 = h64 ^ (UInt64(readUInt32(data, i)) * PRIME1)
            h64 = rotl(h64, 23) * PRIME2 + PRIME3
            i += 4
        }

        // 处理剩余字节
        while (i < len) {
            h64 = h64 ^ (UInt64(data[i]) * PRIME5)
            h64 = rotl(h64, 11) * PRIME1
            i += 1
        }

        // 最终混合
        h64 = h64 ^ (h64 >> 33)
        h64 = h64 * PRIME2
        h64 = h64 ^ (h64 >> 29)
        h64 = h64 * PRIME3
        h64 = h64 ^ (h64 >> 32)

        return h64
    }

    // xxHash64 round
    private static func round(acc: UInt64, input: UInt64): UInt64 {
        var a = acc
        a = a + (input * PRIME2)
        a = rotl(a, 31)
        a = a * PRIME1
        return a
    }

    // merge round
    private static func mergeRound(acc: UInt64, val: UInt64): UInt64 {
        var a = acc
        a = a ^ (round(UInt64(0), val))
        a = a * PRIME1 + PRIME4
        return a
    }

    private static func rotl(x: UInt64, r: Int64): UInt64 {
        return (x << r) | (x >> (64 - r))
    }

    private static func readUInt64(data: Array<UInt8>, offset: Int64): UInt64 {
        var result: UInt64 = UInt64(0)
        var shift: UInt64 = UInt64(0)
        let end = if (offset + 8 <= data.size) { offset + 8 } else { data.size }
        var i = offset
        while (i < end) {
            result = result | (UInt64(data[i]) << shift)
            shift += 8
            i += 1
        }
        return result
    }

    private static func readUInt32(data: Array<UInt8>, offset: Int64): UInt32 {
        var result: UInt32 = UInt32(0)
        if (offset < data.size) { result = result | UInt32(data[offset]) }
        if (offset + 1 < data.size) { result = result | (UInt32(data[offset + 1]) << 8) }
        if (offset + 2 < data.size) { result = result | (UInt32(data[offset + 2]) << 16) }
        if (offset + 3 < data.size) { result = result | (UInt32(data[offset + 3]) << 24) }
        return result
    }
}
