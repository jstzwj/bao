// bao_hash - MurmurHash3 哈希算法
// 严格翻译自: src/hash/murmur.zig
//   MurmurHash3 是非加密型哈希函数
//   Bun 在 resolver 等模块中使用
package bao_hash

import std.collection.*

// ============================================================================
// MurmurHash3 - x86_64 变体
// 严格翻译自: src/hash/murmur.zig
//   用于 resolver 模块的数据结构哈希
// ============================================================================

/// MurmurHash3 - 对应 Bun murmur hash
/// 32位输出变体, 适用于哈希表
public class MurmurHash3 {
    /// MurmurHash3_x86_32
    public static func hash32(data: Array<UInt8>, seed: UInt32): UInt32 {
        let len = data.size
        let c1: UInt32 = UInt32(0xcc9e2d51)
        let c2: UInt32 = UInt32(0x1b873593)
        var h1: UInt32 = seed
        var i: Int64 = 0

        // 处理4字节块
        while (i + 4 <= len) {
            var k1: UInt32 = UInt32(data[i]) | (UInt32(data[i + 1]) << 8) |
                             (UInt32(data[i + 2]) << 16) | (UInt32(data[i + 3]) << 24)
            k1 = k1 * c1
            k1 = rotl32(k1, 15)
            k1 = k1 * c2
            h1 = h1 ^ k1
            h1 = rotl32(h1, 13)
            h1 = h1 * UInt32(5) + UInt32(0xe6546b64)
            i += 4
        }

        // 处理尾部
        var k1: UInt32 = UInt32(0)
        var remaining = len - i
        if (remaining >= 3) { k1 = k1 ^ (UInt32(data[i + 2]) << 16) }
        if (remaining >= 2) { k1 = k1 ^ (UInt32(data[i + 1]) << 8) }
        if (remaining >= 1) {
            k1 = k1 ^ UInt32(data[i])
            k1 = k1 * c1
            k1 = rotl32(k1, 15)
            k1 = k1 * c2
            h1 = h1 ^ k1
        }

        // 最终混合
        h1 = h1 ^ UInt32(len)
        h1 = fmix32(h1)
        return h1
    }

    /// 无种子版本
    public static func hash32(data: Array<UInt8>): UInt32 {
        return hash32(data, UInt32(0))
    }

    public static func hash32(s: String): UInt32 {
        var bytes = ArrayList<UInt8>()
        for (c in s) { bytes.add(UInt8(UInt32(c))) }
        return hash32(bytes.toArray())
    }

    private static func rotl32(x: UInt32, r: Int64): UInt32 {
        return (x << r) | (x >> (32 - r))
    }

    private static func fmix32(h: UInt32): UInt32 {
        var x = h
        x = x ^ (x >> 16)
        x = x * UInt32(0x85ebca6b)
        x = x ^ (x >> 13)
        x = x * UInt32(0xc2b2ae35)
        x = x ^ (x >> 16)
        return x
    }
}
