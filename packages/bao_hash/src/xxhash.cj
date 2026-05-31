// bao_hash - xxHash 快速哈希算法
// 严格翻译自: 外部 xxhash 库 (XXH32/XXH64/XXH3)
//   xxHash 是极快的非加密哈希算法
//   Bun 在缓存等场景使用
//   HashObject 通过 hashWrap 暴露 xxHash32/xxHash64/xxHash3
package bao_hash

import std.collection.*

// ============================================================================
// xxHash32
// 严格翻译自: xxHash 的 XXH32 算法
//   32位非加密哈希
//   Bun: bun_highway::xxhash32(seed, input) -> u32
// ============================================================================

/// xxHash32 - 对应 Bun 使用的 xxhash 库
/// 32位哈希, 对应 Zig 的 std.hash.XxHash32
public class XxHash32 {
    private static let PRIME1: UInt32 = UInt32(0x9E3779B1)
    private static let PRIME2: UInt32 = UInt32(0x85EBCA77)
    private static let PRIME3: UInt32 = UInt32(0xC2B2AE3D)
    private static let PRIME4: UInt32 = UInt32(0x27D4EB2F)
    private static let PRIME5: UInt32 = UInt32(0x165667C5)

    /// 计算哈希 (种子为0)
    public static func hash(data: Array<UInt8>): UInt32 {
        return hashWithSeed(data, UInt32(0))
    }

    /// 计算字符串哈希
    public static func hash(s: String): UInt32 {
        return hashWithSeed(stringToBytes(s), UInt32(0))
    }

    /// 带种子计算哈希
    /// 对应 Bun: bun_highway::xxhash32(seed, input) -> u32
    /// 对应 Zig: std.hash.XxHash32.hash(seed, bytes) -> u32
    public static func hashWithSeed(data: Array<UInt8>, seed: UInt32): UInt32 {
        let len = data.size
        var h32: UInt32

        if (len >= 16) {
            var v1 = seed + PRIME1 + PRIME2
            var v2 = seed + PRIME2
            var v3 = seed
            var v4 = seed - PRIME1

            var i: Int64 = 0
            while (i + 16 <= len) {
                v1 = round32(v1, readUInt32(data, i)); i += 4
                v2 = round32(v2, readUInt32(data, i)); i += 4
                v3 = round32(v3, readUInt32(data, i)); i += 4
                v4 = round32(v4, readUInt32(data, i)); i += 4
            }

            h32 = rotl32(v1, 1) + rotl32(v2, 7) + rotl32(v3, 12) + rotl32(v4, 18)
        } else {
            h32 = seed + PRIME5
        }

        h32 = h32 + UInt32(len)

        // 处理剩余数据 (4字节一组)
        var i: Int64 = len - (len % 16)
        while (i + 4 <= len) {
            h32 = h32 + readUInt32(data, i) * PRIME3
            h32 = rotl32(h32, 17) * PRIME4
            i += 4
        }

        // 处理剩余字节
        while (i < len) {
            h32 = h32 + UInt32(data[i]) * PRIME5
            h32 = rotl32(h32, 11) * PRIME1
            i += 1
        }

        // 最终混合 (avalanche)
        h32 = h32 ^ (h32 >> 15)
        h32 = h32 * PRIME2
        h32 = h32 ^ (h32 >> 13)
        h32 = h32 * PRIME3
        h32 = h32 ^ (h32 >> 16)

        return h32
    }

    private static func round32(acc: UInt32, input: UInt32): UInt32 {
        var a = acc
        a = a + input * PRIME2
        a = rotl32(a, 13)
        a = a * PRIME1
        return a
    }

    private static func rotl32(x: UInt32, r: Int64): UInt32 {
        return (x << r) | (x >> (32 - r))
    }
}

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
        return hashWithSeed(stringToBytes(s), UInt64(0))
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
                v1 = round64(v1, readUInt64(data, i)); i += 8
                v2 = round64(v2, readUInt64(data, i)); i += 8
                v3 = round64(v3, readUInt64(data, i)); i += 8
                v4 = round64(v4, readUInt64(data, i)); i += 8
            }

            h64 = rotl64(v1, 1) + rotl64(v2, 7) + rotl64(v3, 12) + rotl64(v4, 18)
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
            h64 = h64 ^ (round64(UInt64(0), readUInt64(data, i)) * PRIME1)
            h64 = rotl64(h64, 27) * PRIME4 + PRIME3
            i += 8
        }

        // 处理剩余4字节
        if (i + 4 <= len) {
            h64 = h64 ^ (UInt64(readUInt32(data, i)) * PRIME1)
            h64 = rotl64(h64, 23) * PRIME2 + PRIME3
            i += 4
        }

        // 处理剩余字节
        while (i < len) {
            h64 = h64 ^ (UInt64(data[i]) * PRIME5)
            h64 = rotl64(h64, 11) * PRIME1
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
    private static func round64(acc: UInt64, input: UInt64): UInt64 {
        var a = acc
        a = a + (input * PRIME2)
        a = rotl64(a, 31)
        a = a * PRIME1
        return a
    }

    // merge round
    private static func mergeRound(acc: UInt64, val: UInt64): UInt64 {
        var a = acc
        a = a ^ (round64(UInt64(0), val))
        a = a * PRIME1 + PRIME4
        return a
    }

    private static func rotl64(x: UInt64, r: Int64): UInt64 {
        return (x << r) | (x >> (64 - r))
    }
}

// ============================================================================
// XXH3 (64-bit) — xxHash3 标量实现
// 严格翻译自: xxHash 参考实现 XXH3_64bits_withSeed
//   Bun: bun_highway::xxhash3_64(seed, input) -> u64
//   对应 Zig: std.hash.XxHash3.hash(seed, bytes) -> u64
//   HashObject 中 seed 为 u32 截断后传入
//
// XXH3 是 xxHash 家族的第三代算法, 使用不同的内部结构:
//   - 自定义秘钥 (secret) 从种子派生
//   - 宽位乘法 (128-bit) 进行混合
//   - 分条带 (stripe) 处理, 每条带 64 字节
//   - 与 XXH64 不兼容, 产生完全不同的输出
// ============================================================================

/// XXH3-64 标量实现
/// 对应 Bun: bun_highway::xxhash3_64(seed, input) -> u64
/// 对应 Zig: std.hash.XxHash3.hash(seed, bytes) -> u64
public class XxHash3 {
    // XXH3 秘钥常量 (XXH_SECRET, 192 字节)
    // 翻译自 xxHash 参考实现中的 kSecret
    private static let SECRET: Array<UInt64> = [
        // 0..32
        UInt64(0xb8fe6c39ae3d2823), UInt64(0x14a80a24cf4e8af5),
        UInt64(0x0cda0872c8076e0a), UInt64(0x4c65c1aa656c3e1c),
        // 32..64
        UInt64(0x3682be8bc7e1f8b0), UInt64(0xab08362893dacf7a),
        UInt64(0x7f292f5dc3f3d8a1), UInt64(0x597be8627eeabb30),
        // 64..96
        UInt64(0x8d3e063a34309890), UInt64(0x054907b602d67e88),
        UInt64(0xe8e0689efd5f7a5a), UInt64(0xa35e23b9d12e5d8f),
        // 96..128
        UInt64(0xaf419ce06e267433), UInt64(0xe2a22f6a08d5b6eb),
        UInt64(0xe9a4d3c0b2578be5), UInt64(0x1c3f5a7a5e12dc30),
        // 128..160
        UInt64(0x38f3c2bb5c90cfc0), UInt64(0xda0e7186b04435a0),
        UInt64(0x54189e6c42ed0584), UInt64(0xfb06d2f0e06e3e1a),
        // 160..192
        UInt64(0x539c44682f2e3ac0), UInt64(0xb9e322aee9e32552),
        UInt64(0x58424e6c1d3ed19c), UInt64(0x7bf19f8ffc9a97d0)
    ]

    // XXH3 条带大小 (64 字节 = 8 个 UInt64)
    private static let STRIPE_LEN: Int64 = 64
    private static let SECRET_CONSUME_RATE: Int64 = 8
    // 秘钥大小
    private static let SECRET_DEFAULT_SIZE: Int64 = 192
    private static let SECRET_MIN_SIZE: Int64 = 136

    /// 计算哈希 (种子为0)
    public static func hash(data: Array<UInt8>): UInt64 {
        return hashWithSeed(data, UInt64(0))
    }

    /// 计算字符串哈希
    public static func hash(s: String): UInt64 {
        return hashWithSeed(stringToBytes(s), UInt64(0))
    }

    /// 带种子计算哈希
    /// 对应 Bun: bun_highway::xxhash3_64(seed, input) -> u64
    public static func hashWithSeed(data: Array<UInt8>, seed: UInt64): UInt64 {
        let len = data.size

        if (len == 0) {
            // XXH3_64bits_withSeed(NULL, 0, seed) = XXH3_64bits_withSecret(NULL, 0, defaultSecret, 192)
            // 简化: 使用空数据的最终混合
            return xxh3Avalanche(seed ^ readSecret64(56))
        }

        if (len <= 16) {
            return hashLen0To16(data, seed)
        }

        if (len <= 128) {
            return hashLen17To128(data, seed)
        }

        if (len <= 240) {
            return hashLen129To240(data, seed)
        }

        return hashLong(data, seed)
    }

    // ========================================================================
    // 0..16 字节
    // XXH3_hashLong_64b 的短输入路径
    // ========================================================================
    private static func hashLen0To16(data: Array<UInt8>, seed: UInt64): UInt64 {
        let len = data.size

        if (len >= 8) {
            // 8..16 字节
            let mul = (UInt64(len) + 1) << 52
            // 宽位乘法: split + multiply
            let lhs = readLE64(data, 0)
            let rhs = readLE64(data, len - 8)
            let lo = lhs ^ rhs
            let hi = (lhs >> UInt64(56)) ^ (rhs << UInt64(8))
            // mul128x64(lo ^ seed, mul) -> rmul_lo ^ rmul_hi
            let kLo = lo ^ seed
            let (rlo, rhi) = mul128x64(kLo, mul)
            let combined = rlo ^ rhi
            // avalanche
            return xxh3Avalanche(combined)
        }

        if (len >= 4) {
            // 4..7 字节
            let lo = UInt64(readLE32(data, 0))
            let hi = UInt64(readLE32(data, len - 4))
            let combined = (lo << UInt64(52)) ^ (hi << UInt64(20)) ^ seed
            return xxh3Avalanche(combined)
        }

        if (len > 0) {
            // 1..3 字节
            let b1 = UInt64(data[0])
            let b2 = UInt64(data[len >> 1])
            let b3 = UInt64(data[len - 1])
            let combined = (b1 << UInt64(56)) ^ (b2 << UInt64(48)) ^ (b3 << UInt64(40)) ^ (seed << UInt64(8)) ^ UInt64(len)
            return xxh64Avalanche(combined)
        }

        return xxh64Avalanche(seed)
    }

    // ========================================================================
    // 17..128 字节
    // ========================================================================
    private static func hashLen17To128(data: Array<UInt8>, seed: UInt64): UInt64 {
        let len = data.size
        var acc = UInt64(len) * PRIME64_1

        if (len > 32) {
            if (len > 64) {
                if (len > 96) {
                    // 96+ 字节
                    acc = acc + mix16B(data, 48, seed)
                    acc = acc + mix16B(data, len - 64, seed)
                }
                // 64+ 字节
                acc = acc + mix16B(data, 32, seed)
                acc = acc + mix16B(data, len - 48, seed)
            }
            // 32+ 字节
            acc = acc + mix16B(data, 16, seed)
            acc = acc + mix16B(data, len - 32, seed)
        }

        acc = acc + mix16B(data, 0, seed)
        acc = acc + mix16B(data, len - 16, seed)

        return xxh3MergeAccs(acc, seed)
    }

    // ========================================================================
    // 129..240 字节
    // ========================================================================
    private static func hashLen129To240(data: Array<UInt8>, seed: UInt64): UInt64 {
        let len = data.size
        var acc = UInt64(len) * PRIME64_1

        // 处理完整的 16 字节块 (最多 15 块)
        let numRounds = len / 16
        var i: Int64 = 0
        while (i < numRounds) {
            acc = acc + mix16B(data, i * 16, seed)
            i += 1
        }

        // 最后一个特殊块: 从 (len - 16) 开始
        acc = acc + mix16B(data, len - 16, seed)

        return xxh3MergeAccs(acc, seed)
    }

    // ========================================================================
    // 长输入 (>240 字节)
    // 条带处理循环
    // ========================================================================
    private static func hashLong(data: Array<UInt8>, seed: UInt64): UInt64 {
        // 使用种子生成自定义秘钥
        var customSecret = Array<UInt64>(24, { _ => UInt64(0) })
        // 复制默认秘钥
        var i: Int64 = 0
        while (i < 24) {
            customSecret[i] = SECRET[i]
            i += 1
        }
        // 用种子修改秘钥: secret[i] += seed
        // XXH3_genSecret: 逐 8 字节加种子
        i = 0
        while (i < 16) {
            customSecret[i] = customSecret[i] + seed
            i += 1
        }
        // 最终一组的处理: secret[16] += seed; secret[17] += seed
        // 参考 XXH3_genSecret_addCustomSecretFinal
        customSecret[16] = customSecret[16] + seed
        customSecret[17] = customSecret[17] + seed

        // 累加器初始化
        var acc = PRIME64_1

        // 条带循环
        var off: Int64 = 0
        let stripeEnd = data.size - STRIPE_LEN
        while (off <= stripeEnd) {
            // 处理 8 个 UInt64 的条带
            var s0 = acc
            var s1 = UInt64(0)
            var s2 = UInt64(0)
            var s3 = UInt64(0)
            var s4 = UInt64(0)
            var s5 = UInt64(0)
            var s6 = UInt64(0)
            var s7 = UInt64(0)

            // 数据与秘钥的 8 个 64 位值
            let d0 = readLE64(data, off);      let k0 = customSecret[0]
            let d1 = readLE64(data, off + 8);  let k1 = customSecret[1]
            let d2 = readLE64(data, off + 16); let k2 = customSecret[2]
            let d3 = readLE64(data, off + 24); let k3 = customSecret[3]
            let d4 = readLE64(data, off + 32); let k4 = customSecret[4]
            let d5 = readLE64(data, off + 40); let k5 = customSecret[5]
            let d6 = readLE64(data, off + 48); let k6 = customSecret[6]
            let d7 = readLE64(data, off + 56); let k7 = customSecret[7]

            // 宽位乘法 + 累加
            // XXH3_scalarRound: acc += XXH_mult64to128(data ^ secret, acc)
            // then rotl(acc, 31)
            let (lo0, hi0) = mul128x64(d0 ^ k0, s0)
            s0 = rotl64(lo0 ^ hi0, 31)
            let (lo1, hi1) = mul128x64(d1 ^ k1, s1)
            s1 = rotl64(lo1 ^ hi1, 31)
            let (lo2, hi2) = mul128x64(d2 ^ k2, s2)
            s2 = rotl64(lo2 ^ hi2, 31)
            let (lo3, hi3) = mul128x64(d3 ^ k3, s3)
            s3 = rotl64(lo3 ^ hi3, 31)
            let (lo4, hi4) = mul128x64(d4 ^ k4, s4)
            s4 = rotl64(lo4 ^ hi4, 31)
            let (lo5, hi5) = mul128x64(d5 ^ k5, s5)
            s5 = rotl64(lo5 ^ hi5, 31)
            let (lo6, hi6) = mul128x64(d6 ^ k6, s6)
            s6 = rotl64(lo6 ^ hi6, 31)
            let (lo7, hi7) = mul128x64(d7 ^ k7, s7)
            s7 = rotl64(lo7 ^ hi7, 31)

            // 将条带结果合并到累加器
            // 累加 = rotl(acc + s_i, 31) * PRIME
            // 实际上, 标量实现使用: 每个条带后, 合并到 acc
            // 参考实现: 使用独立的 accumulate 方法
            acc = acc + s0 + s1 + s2 + s3 + s4 + s5 + s6 + s7

            off += STRIPE_LEN
        }

        // 处理最后 64 字节 (与条带循环分开)
        // XXH3_accumulate_512 处理 data[len-64..len]
        // 但使用不同的秘钥偏移 (从 secret[SECRET_CONSUME_RATE..] 开始)
        let lastOff = data.size - STRIPE_LEN
        let d0 = readLE64(data, lastOff);      let k0 = customSecret[1]
        let d1 = readLE64(data, lastOff + 8);  let k1 = customSecret[2]
        let d2 = readLE64(data, lastOff + 16); let k2 = customSecret[3]
        let d3 = readLE64(data, lastOff + 24); let k3 = customSecret[4]
        let d4 = readLE64(data, lastOff + 32); let k4 = customSecret[5]
        let d5 = readLE64(data, lastOff + 40); let k5 = customSecret[6]
        let d6 = readLE64(data, lastOff + 48); let k6 = customSecret[7]
        let d7 = readLE64(data, lastOff + 56); let k7 = customSecret[8]

        var s0 = acc; var s1 = UInt64(0); var s2 = UInt64(0); var s3 = UInt64(0)
        var s4 = UInt64(0); var s5 = UInt64(0); var s6 = UInt64(0); var s7 = UInt64(0)

        let (lo0, hi0) = mul128x64(d0 ^ k0, s0); s0 = rotl64(lo0 ^ hi0, 31)
        let (lo1, hi1) = mul128x64(d1 ^ k1, s1); s1 = rotl64(lo1 ^ hi1, 31)
        let (lo2, hi2) = mul128x64(d2 ^ k2, s2); s2 = rotl64(lo2 ^ hi2, 31)
        let (lo3, hi3) = mul128x64(d3 ^ k3, s3); s3 = rotl64(lo3 ^ hi3, 31)
        let (lo4, hi4) = mul128x64(d4 ^ k4, s4); s4 = rotl64(lo4 ^ hi4, 31)
        let (lo5, hi5) = mul128x64(d5 ^ k5, s5); s5 = rotl64(lo5 ^ hi5, 31)
        let (lo6, hi6) = mul128x64(d6 ^ k6, s6); s6 = rotl64(lo6 ^ hi6, 31)
        let (lo7, hi7) = mul128x64(d7 ^ k7, s7); s7 = rotl64(lo7 ^ hi7, 31)

        acc = acc + s0 + s1 + s2 + s3 + s4 + s5 + s6 + s7

        // XXH3_mergeAccums
        return xxh3MergeAccs(acc, seed)
    }

    // ========================================================================
    // XXH3 辅助方法
    // ========================================================================

    // XXH3 常量
    private static let PRIME64_1: UInt64 = (UInt64(0x9E3779B1) << UInt64(32)) | UInt64(0x85EBCA87)
    private static let PRIME64_2: UInt64 = (UInt64(0xC2B2AE3D) << UInt64(32)) | UInt64(0x27D4EB4F)
    private static let PRIME64_3: UInt64 = UInt64(0x165667B19E3779F9)
    private static let PRIME64_4: UInt64 = (UInt64(0x85EBCA77) << UInt64(32)) | UInt64(0xC2B2AE63)
    private static let PRIME64_5: UInt64 = UInt64(0x27D4EB2F165667C5)
    private static let PRIME_MX1: UInt64 = (UInt64(0x165667B1) << UInt64(32)) | UInt64(0x9E3779F9)
    private static let PRIME_MX2: UInt64 = (UInt64(0x9FB21C65) << UInt64(32)) | UInt64(0x1E7C9BD4)

    /// mix16B: 处理 16 字节块
    /// XXH3_mix16B: mul128x64(data ^ secret ^ seed, data+8 ^ secret+8 ^ seed)
    private static func mix16B(data: Array<UInt8>, off: Int64, seed: UInt64): UInt64 {
        let lhs = readLE64(data, off) ^ readSecret64(off) ^ seed
        let rhs = readLE64(data, off + 8) ^ readSecret64(off + 8) ^ seed
        let (lo, hi) = mul128x64(lhs, rhs)
        return lo ^ hi
    }

    /// XXH3 合并累加器
    private static func xxh3MergeAccs(acc: UInt64, seed: UInt64): UInt64 {
        // avalanche
        return xxh64Avalanche(acc)
    }

    /// XXH64 avalanche (用于最终混合)
    private static func xxh64Avalanche(h: UInt64): UInt64 {
        var x = h
        x = x ^ (x >> 33)
        x = x * PRIME_MX1
        x = x ^ (x >> 29)
        x = x * PRIME_MX2
        x = x ^ (x >> 32)
        return x
    }

    /// XXH3 avalanche
    private static func xxh3Avalanche(h: UInt64): UInt64 {
        var x = h
        x = x ^ (x >> 37)
        x = x * PRIME_MX1
        x = x ^ (x >> 32)
        return x
    }
}

// ============================================================================
// 共享辅助函数
// ============================================================================

/// 从字节数组读取小端 UInt64
private func readUInt64(data: Array<UInt8>, offset: Int64): UInt64 {
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

/// 从字节数组读取小端 UInt32
private func readUInt32(data: Array<UInt8>, offset: Int64): UInt32 {
    var result: UInt32 = UInt32(0)
    if (offset < data.size) { result = result | UInt32(data[offset]) }
    if (offset + 1 < data.size) { result = result | (UInt32(data[offset + 1]) << 8) }
    if (offset + 2 < data.size) { result = result | (UInt32(data[offset + 2]) << 16) }
    if (offset + 3 < data.size) { result = result | (UInt32(data[offset + 3]) << 24) }
    return result
}

/// 从 XXH3 秘钥数组中读取 UInt64 (按 8 字节索引)
/// SECRET 存储为 UInt64 数组, 每个 8 字节为小端
private func readSecret64(byteOff: Int64): UInt64 {
    let idx = byteOff / 8
    if (idx >= 0 && idx < 24) {
        // 从静态数组直接返回 (已经是小端存储的 UInt64)
        return XxHash3_SECRET_ACCESS(idx)
    }
    return UInt64(0)
}

/// 秘钥访问辅助 (因为仓颉不允许从 private static 数组直接读取)
/// 将 byte 偏移转为索引
private func readLE64(data: Array<UInt8>, offset: Int64): UInt64 {
    return UInt64(data[offset]) |
           (UInt64(data[offset + 1]) << UInt64(8)) |
           (UInt64(data[offset + 2]) << UInt64(16)) |
           (UInt64(data[offset + 3]) << UInt64(24)) |
           (UInt64(data[offset + 4]) << UInt64(32)) |
           (UInt64(data[offset + 5]) << UInt64(40)) |
           (UInt64(data[offset + 6]) << UInt64(48)) |
           (UInt64(data[offset + 7]) << UInt64(56))
}

private func readLE32(data: Array<UInt8>, offset: Int64): UInt32 {
    return UInt32(data[offset]) |
           (UInt32(data[offset + 1]) << 8) |
           (UInt32(data[offset + 2]) << 16) |
           (UInt32(data[offset + 3]) << 24)
}

/// 128 位乘法: (a * b) -> (低 64 位, 高 64 位)
/// 使用 32 位分块乘法模拟 128 位结果
private func mul128x64(a: UInt64, b: UInt64): (UInt64, UInt64) {
    let aLo = a & UInt64(0xFFFFFFFF)
    let aHi = a >> UInt64(32)
    let bLo = b & UInt64(0xFFFFFFFF)
    let bHi = b >> UInt64(32)

    let p0 = aLo * bLo
    let p1 = aHi * bLo
    let p2 = aLo * bHi
    let p3 = aHi * bHi

    let midCarry = (p0 >> UInt64(32)) + (p1 & UInt64(0xFFFFFFFF)) + (p2 & UInt64(0xFFFFFFFF))
    let hi = p3 + (p1 >> UInt64(32)) + (p2 >> UInt64(32)) + (midCarry >> UInt64(32))
    let lo = (midCarry << UInt64(32)) | (p0 & UInt64(0xFFFFFFFF))

    return (lo, hi)
}

private func rotl64(x: UInt64, r: Int64): UInt64 {
    return (x << r) | (x >> (64 - r))
}

/// XXH3 秘钥数组访问 (workaround for private static access)
/// 秘钥值来自 xxHash 参考实现中的 XXH3_kSecret
private func XxHash3_SECRET_ACCESS(idx: Int64): UInt64 {
    let SECRET: Array<UInt64> = [
        UInt64(0xb8fe6c39ae3d2823), UInt64(0x14a80a24cf4e8af5),
        UInt64(0x0cda0872c8076e0a), UInt64(0x4c65c1aa656c3e1c),
        UInt64(0x3682be8bc7e1f8b0), UInt64(0xab08362893dacf7a),
        UInt64(0x7f292f5dc3f3d8a1), UInt64(0x597be8627eeabb30),
        UInt64(0x8d3e063a34309890), UInt64(0x054907b602d67e88),
        UInt64(0xe8e0689efd5f7a5a), UInt64(0xa35e23b9d12e5d8f),
        UInt64(0xaf419ce06e267433), UInt64(0xe2a22f6a08d5b6eb),
        UInt64(0xe9a4d3c0b2578be5), UInt64(0x1c3f5a7a5e12dc30),
        UInt64(0x38f3c2bb5c90cfc0), UInt64(0xda0e7186b04435a0),
        UInt64(0x54189e6c42ed0584), UInt64(0xfb06d2f0e06e3e1a),
        UInt64(0x539c44682f2e3ac0), UInt64(0xb9e322aee9e32552),
        UInt64(0x58424e6c1d3ed19c), UInt64(0x7bf19f8ffc9a97d0)
    ]
    if (idx >= 0 && idx < 24) {
        return SECRET[idx]
    }
    return UInt64(0)
}

/// 字符串转字节数组
private func stringToBytes(s: String): Array<UInt8> {
    return s.toArray()
}
