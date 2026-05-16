// bao_hash - RapidHash 哈希算法
// 严格翻译自: src/hash/rapidhash.rs (源自 src/bun_core/deprecated.zig)
//   RapidHash 是高速非加密型哈希函数
//   Bun 在 HashObject 中通过 hashWrap(bun.deprecated.RapidHash) 暴露
//   调用 hash(seed: u64, input: []const u8) -> u64
package bao_hash

// ============================================================================
// RapidHash
// 严格翻译自: src/hash/rapidhash.rs
//   移植自 src/bun_core/deprecated.zig (bun.deprecated.RapidHash)
//   HashObject.zig 通过 hashWrap(bun.deprecated.RapidHash) 暴露
//   默认种子 RAPID_SEED = 0xbdd89aa982704029
// ============================================================================

/// RapidHash - 高速非加密哈希
/// 对应 Bun: bun.deprecated.RapidHash
// 128位乘法结果 (低64位, 高64位)
private class MumResult {
    var lo: UInt64
    var hi: UInt64
    init(lo: UInt64, hi: UInt64) {
        this.lo = lo
        this.hi = hi
    }
}

public class RapidHash {

    /// 默认种子
    public static let RAPID_SEED: UInt64 = UInt64(0xbdd89aa982704029)

    // RapidHash 秘钥常量
    private static let RAPID_SECRET_0: UInt64 = UInt64(0x2d358dccaa6c78a5)
    private static let RAPID_SECRET_1: UInt64 = UInt64(0x8bb84b93962eacc9)
    private static let RAPID_SECRET_2: UInt64 = UInt64(0x4b33a62ed433d4a3)

    /// 计算哈希 (使用默认种子)
    public static func hash(input: Array<UInt8>): UInt64 {
        return hashWithSeed(input, RAPID_SEED)
    }

    /// 哈希字符串
    public static func hash(s: String): UInt64 {
        return hash(stringToBytes(s))
    }

    /// 带种子计算哈希
    /// 对应 Bun: RapidHash::hash(seed, input) -> u64
    public static func hashWithSeed(input: Array<UInt8>, seed: UInt64): UInt64 {
        let sc0 = RAPID_SECRET_0
        let sc1 = RAPID_SECRET_1
        let sc2 = RAPID_SECRET_2
        let len = input.size
        var a: UInt64 = UInt64(0)
        var b: UInt64 = UInt64(0)
        var k = input
        var kOff: Int64 = 0  // k 的当前偏移
        // is 数组对应 Zig 的 inline 循环状态
        var is0: UInt64 = seed
        var is1: UInt64 = UInt64(0)
        var is2: UInt64 = UInt64(0)

        is0 = mix(seed ^ sc0, sc1) ^ UInt64(len)

        if (len <= 16) {
            if (len >= 4) {
                let d: Int64 = Int64((len & 24) >> (len >> 3))
                let e = len - 4
                a = (r32(k, kOff) << UInt64(32)) | r32(k, kOff + e)
                b = (r32(k, kOff + d) << UInt64(32)) | r32(k, kOff + e - d)
            } else if (len > 0) {
                a = (UInt64(k[kOff]) << UInt64(56)) |
                    (UInt64(k[kOff + (len >> 1)]) << UInt64(32)) |
                    UInt64(k[kOff + len - 1])
            }
        } else {
            var remain = len

            if (len > 48) {
                is1 = is0
                is2 = is0

                while (remain >= 96) {
                    // 对应 Zig: inline for (0..6)
                    var idx = 0
                    while (idx < 6) {
                        let m1 = r64(k, kOff + Int64(8 * idx * 2))
                        let m2 = r64(k, kOff + Int64(8 * (idx * 2 + 1)))
                        if (idx % 3 == 0) {
                            is0 = mix(m1 ^ sc0, m2 ^ is0)
                        } else if (idx % 3 == 1) {
                            is1 = mix(m1 ^ sc1, m2 ^ is1)
                        } else {
                            is2 = mix(m1 ^ sc2, m2 ^ is2)
                        }
                        idx += 1
                    }
                    kOff += 96
                    remain -= 96
                }

                if (remain >= 48) {
                    // 对应 Zig: inline for (0..3)
                    var idx = 0
                    while (idx < 3) {
                        let m1 = r64(k, kOff + Int64(8 * idx * 2))
                        let m2 = r64(k, kOff + Int64(8 * (idx * 2 + 1)))
                        if (idx == 0) {
                            is0 = mix(m1 ^ sc0, m2 ^ is0)
                        } else if (idx == 1) {
                            is1 = mix(m1 ^ sc1, m2 ^ is1)
                        } else {
                            is2 = mix(m1 ^ sc2, m2 ^ is2)
                        }
                        idx += 1
                    }
                    kOff += 48
                    remain -= 48
                }

                is0 = is0 ^ is1 ^ is2
            }

            if (remain > 16) {
                is0 = mix(r64(k, kOff) ^ sc2, r64(k, kOff + 8) ^ is0 ^ sc1)
                if (remain > 32) {
                    is0 = mix(r64(k, kOff + 16) ^ sc2, r64(k, kOff + 24) ^ is0)
                }
            }

            a = r64(input, Int64(len) - 16)
            b = r64(input, Int64(len) - 8)
        }

        a = a ^ sc1
        b = b ^ is0
        // mum(a, b) 将 a,b 替换为 128 位乘法的低/高 64 位
        // 然后 final2 结果 = mix(a ^ sc0 ^ len, b ^ sc1) = mum(a^sc0^len, b^sc1).lo ^ .hi
        // Rust: mum(&mut a, &mut b); mix(a ^ sc0 ^ len, b ^ sc1)
        // mix 内部也是 mum -> lo ^ hi
        // 所以整个 final2 = mum( mum(a,b).lo ^ sc0 ^ len,  mum(a,b).hi ^ sc1 ).lo ^ .hi
        let mumR = mumPair(a, b)
        return mix(mumR.lo ^ sc0 ^ UInt64(len), mumR.hi ^ sc1)
    }

    /// 带种子哈希字符串
    public static func hashWithSeed(s: String, seed: UInt64): UInt64 {
        return hashWithSeed(stringToBytes(s), seed)
    }

    // 128位乘法, 返回 (低64位, 高64位)
    // 对应 Rust: fn mum(a: &mut u64, b: &mut u64) { let r = *a as u128 * *b as u128; *a = r as u64; *b = (r >> 64) as u64; }
    private static func mumPair(a_: UInt64, b_: UInt64): MumResult {
        let aLo = a_ & UInt64(0xFFFFFFFF)
        let aHi = a_ >> UInt64(32)
        let bLo = b_ & UInt64(0xFFFFFFFF)
        let bHi = b_ >> UInt64(32)

        let p0 = aLo * bLo
        let p1 = aHi * bLo
        let p2 = aLo * bHi
        let p3 = aHi * bHi

        let midCarry = (p0 >> UInt64(32)) + (p1 & UInt64(0xFFFFFFFF)) + (p2 & UInt64(0xFFFFFFFF))
        let hi = p3 + (p1 >> UInt64(32)) + (p2 >> UInt64(32)) + (midCarry >> UInt64(32))
        let lo = (midCarry << UInt64(32)) | (p0 & UInt64(0xFFFFFFFF))

        return MumResult(lo, hi)
    }

    // mix = mum(a, b) 然后 a ^ b
    // 对应 Rust: fn mix(a, b) { mum(a, b); a ^ b }
    private static func mix(a: UInt64, b: UInt64): UInt64 {
        let r = mumPair(a, b)
        return r.lo ^ r.hi
    }

    // 从字节数组读取小端 UInt64
    private static func r64(p: Array<UInt8>, off: Int64): UInt64 {
        return UInt64(p[off]) |
               (UInt64(p[off + 1]) << UInt64(8)) |
               (UInt64(p[off + 2]) << UInt64(16)) |
               (UInt64(p[off + 3]) << UInt64(24)) |
               (UInt64(p[off + 4]) << UInt64(32)) |
               (UInt64(p[off + 5]) << UInt64(40)) |
               (UInt64(p[off + 6]) << UInt64(48)) |
               (UInt64(p[off + 7]) << UInt64(56))
    }

    // 从字节数组读取小端 UInt32, 返回 UInt64
    private static func r32(p: Array<UInt8>, off: Int64): UInt64 {
        return UInt64(p[off]) |
               (UInt64(p[off + 1]) << UInt64(8)) |
               (UInt64(p[off + 2]) << UInt64(16)) |
               (UInt64(p[off + 3]) << UInt64(24))
    }
}

/// 字符串转字节数组
private func stringToBytes(s: String): Array<UInt8> {
    var bytes = Array<UInt8>()
    for (c in s) { bytes.append(UInt8(c.value)) }
    return bytes
}
