// bao_hash - Wyhash 哈希算法
// 严格翻译自: src/wyhash/wyhash.zig / src/wyhash/lib.rs
//   Wyhash 是快速非加密型 64 位哈希函数
//   Bun 在 HashObject 中通过 hashWrap(std.hash.Wyhash) 暴露
//   注意: std.hash.Wyhash 是 final4 变体 (48字节轮次, 4个秘钥)
//   另有 Wyhash11 (旧版, 32字节轮次, 5个素数) 用于不同场景
//   这两个算法产生不同的输出, 不可互换
package bao_hash

// ============================================================================
// Wyhash11 (旧版, 32字节轮次, 5个素数)
// 严格翻译自: src/wyhash/lib.rs Wyhash11 / src/wyhash/wyhash.zig WyhashStateless
//   用于 StringHashMap 的短键哈希
// ============================================================================

/// 5 个 Wyhash 素数常量
private let WYHASH_PRIMES_0: UInt64 = UInt64(0xa0761d6478bd642f)
private let WYHASH_PRIMES_1: UInt64 = UInt64(0xe7037ed1a0b428db)
private let WYHASH_PRIMES_2: UInt64 = UInt64(0x8ebc6af09c88c6e3)
private let WYHASH_PRIMES_3: UInt64 = UInt64(0x589965cc75374cc3)
private let WYHASH_PRIMES_4: UInt64 = UInt64(0x1d8e4e27c47d124f)

// 从字节数组读取 1 字节 (返回 UInt64)
private func wyRead1(data: Array<UInt8>, off: Int64): UInt64 {
    return UInt64(data[off])
}

// 从字节数组读取 2 字节小端 (返回 UInt64)
private func wyRead2(data: Array<UInt8>, off: Int64): UInt64 {
    return UInt64(data[off]) | (UInt64(data[off + 1]) << UInt64(8))
}

// 从字节数组读取 4 字节小端 (返回 UInt64)
private func wyRead4(data: Array<UInt8>, off: Int64): UInt64 {
    return UInt64(data[off]) |
           (UInt64(data[off + 1]) << UInt64(8)) |
           (UInt64(data[off + 2]) << UInt64(16)) |
           (UInt64(data[off + 3]) << UInt64(24))
}

// 从字节数组读取 8 字节小端 (返回 UInt64)
private func wyRead8(data: Array<UInt8>, off: Int64): UInt64 {
    return UInt64(data[off]) |
           (UInt64(data[off + 1]) << UInt64(8)) |
           (UInt64(data[off + 2]) << UInt64(16)) |
           (UInt64(data[off + 3]) << UInt64(24)) |
           (UInt64(data[off + 4]) << UInt64(32)) |
           (UInt64(data[off + 5]) << UInt64(40)) |
           (UInt64(data[off + 6]) << UInt64(48)) |
           (UInt64(data[off + 7]) << UInt64(56))
}

// 交换后的 8 字节读取 (高 32 位来自前 4 字节, 低 32 位来自后 4 字节)
private func wyRead8Swapped(data: Array<UInt8>, off: Int64): UInt64 {
    return (wyRead4(data, off) << UInt64(32)) | wyRead4(data, off + 4)
}

// 128位乘法结果: (a*b) 的 (低64位 XOR 高64位)
// 对应 Zig 的 mulWide + (r >> 64) ^ r
private func wyMum(a: UInt64, b: UInt64): UInt64 {
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

    return lo ^ hi
}

private func wyMix0(a: UInt64, b: UInt64, seed: UInt64): UInt64 {
    return wyMum(a ^ seed ^ WYHASH_PRIMES_0, b ^ seed ^ WYHASH_PRIMES_1)
}

private func wyMix1(a: UInt64, b: UInt64, seed: UInt64): UInt64 {
    return wyMum(a ^ seed ^ WYHASH_PRIMES_2, b ^ seed ^ WYHASH_PRIMES_3)
}

// WyhashStateless final 函数: 处理 <32 字节的尾部
private func wyhashStatelessFinal(
    seed: UInt64, msgLen: Int64, b: Array<UInt8>, off: Int64, len: Int64
): UInt64 {
    var newSeed = seed
    let remLen = len

    if (remLen == 0) {
        newSeed = seed
    } else if (remLen == 1) {
        newSeed = wyMix0(wyRead1(b, off), WYHASH_PRIMES_4, seed)
    } else if (remLen == 2) {
        newSeed = wyMix0(wyRead2(b, off), WYHASH_PRIMES_4, seed)
    } else if (remLen == 3) {
        newSeed = wyMix0((wyRead2(b, off) << UInt64(8)) | wyRead1(b, off + 2), WYHASH_PRIMES_4, seed)
    } else if (remLen == 4) {
        newSeed = wyMix0(wyRead4(b, off), WYHASH_PRIMES_4, seed)
    } else if (remLen == 5) {
        newSeed = wyMix0((wyRead4(b, off) << UInt64(8)) | wyRead1(b, off + 4), WYHASH_PRIMES_4, seed)
    } else if (remLen == 6) {
        newSeed = wyMix0((wyRead4(b, off) << UInt64(16)) | wyRead2(b, off + 4), WYHASH_PRIMES_4, seed)
    } else if (remLen == 7) {
        newSeed = wyMix0(
            (wyRead4(b, off) << UInt64(24)) | (wyRead2(b, off + 4) << UInt64(8)) | wyRead1(b, off + 6),
            WYHASH_PRIMES_4, seed
        )
    } else if (remLen == 8) {
        newSeed = wyMix0(wyRead8Swapped(b, off), WYHASH_PRIMES_4, seed)
    } else if (remLen == 9) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead1(b, off + 8), seed)
    } else if (remLen == 10) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead2(b, off + 8), seed)
    } else if (remLen == 11) {
        newSeed = wyMix0(
            wyRead8Swapped(b, off),
            (wyRead2(b, off + 8) << UInt64(8)) | wyRead1(b, off + 10),
            seed
        )
    } else if (remLen == 12) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead4(b, off + 8), seed)
    } else if (remLen == 13) {
        newSeed = wyMix0(
            wyRead8Swapped(b, off),
            (wyRead4(b, off + 8) << UInt64(8)) | wyRead1(b, off + 12),
            seed
        )
    } else if (remLen == 14) {
        newSeed = wyMix0(
            wyRead8Swapped(b, off),
            (wyRead4(b, off + 8) << UInt64(16)) | wyRead2(b, off + 12),
            seed
        )
    } else if (remLen == 15) {
        newSeed = wyMix0(
            wyRead8Swapped(b, off),
            (wyRead4(b, off + 8) << UInt64(24)) | (wyRead2(b, off + 12) << UInt64(8)) | wyRead1(b, off + 14),
            seed
        )
    } else if (remLen == 16) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed)
    } else if (remLen == 17) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1(wyRead1(b, off + 16), WYHASH_PRIMES_4, seed)
    } else if (remLen == 18) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1(wyRead2(b, off + 16), WYHASH_PRIMES_4, seed)
    } else if (remLen == 19) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1((wyRead2(b, off + 16) << UInt64(8)) | wyRead1(b, off + 18), WYHASH_PRIMES_4, seed)
    } else if (remLen == 20) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1(wyRead4(b, off + 16), WYHASH_PRIMES_4, seed)
    } else if (remLen == 21) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1((wyRead4(b, off + 16) << UInt64(8)) | wyRead1(b, off + 20), WYHASH_PRIMES_4, seed)
    } else if (remLen == 22) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1((wyRead4(b, off + 16) << UInt64(16)) | wyRead2(b, off + 20), WYHASH_PRIMES_4, seed)
    } else if (remLen == 23) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1(
                      (wyRead4(b, off + 16) << UInt64(24)) | (wyRead2(b, off + 20) << UInt64(8)) | wyRead1(b, off + 22),
                      WYHASH_PRIMES_4, seed
                  )
    } else if (remLen == 24) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1(wyRead8Swapped(b, off + 16), WYHASH_PRIMES_4, seed)
    } else if (remLen == 25) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1(wyRead8Swapped(b, off + 16), wyRead1(b, off + 24), seed)
    } else if (remLen == 26) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1(wyRead8Swapped(b, off + 16), wyRead2(b, off + 24), seed)
    } else if (remLen == 27) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1(
                      wyRead8Swapped(b, off + 16),
                      (wyRead2(b, off + 24) << UInt64(8)) | wyRead1(b, off + 26),
                      seed
                  )
    } else if (remLen == 28) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1(wyRead8Swapped(b, off + 16), wyRead4(b, off + 24), seed)
    } else if (remLen == 29) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1(
                      wyRead8Swapped(b, off + 16),
                      (wyRead4(b, off + 24) << UInt64(8)) | wyRead1(b, off + 28),
                      seed
                  )
    } else if (remLen == 30) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1(
                      wyRead8Swapped(b, off + 16),
                      (wyRead4(b, off + 24) << UInt64(16)) | wyRead2(b, off + 28),
                      seed
                  )
    } else if (remLen == 31) {
        newSeed = wyMix0(wyRead8Swapped(b, off), wyRead8Swapped(b, off + 8), seed) ^
                  wyMix1(
                      wyRead8Swapped(b, off + 16),
                      (wyRead4(b, off + 24) << UInt64(24)) | (wyRead2(b, off + 28) << UInt64(8)) | wyRead1(b, off + 30),
                      seed
                  )
    }

    let totalLen = UInt64(msgLen + remLen)
    return wyMum(newSeed ^ totalLen, WYHASH_PRIMES_4)
}

/// Wyhash11 (旧版, 32字节轮次)
/// 对应 Bun: src/wyhash/lib.rs Wyhash11 / src/wyhash/wyhash.zig Wyhash11
/// 支持流式 API: init -> update* -> finalize
/// 注意: 与 Wyhash (final4 变体) 是不同算法, 产生不同输出
public class Wyhash11 {
    // 流式状态
    private var seed: UInt64
    private var msgLen: Int64
    private var buf: Array<UInt8>
    private var bufLen: Int64

    public init(seed: UInt64) {
        this.seed = seed
        this.msgLen = 0
        this.buf = Array<UInt8>(32, item: UInt8(0))
        this.bufLen = 0
    }

    /// 一次性哈希 (使用默认种子 0)
    public static func hash(input: Array<UInt8>): UInt64 {
        return hashWithSeed(input, UInt64(0))
    }

    /// 哈希字符串
    public static func hash(s: String): UInt64 {
        return hash(stringToBytes(s))
    }

    /// 一次性带种子哈希
    /// 对应 Bun: Wyhash11::hash(seed, input) -> u64
    public static func hashWithSeed(input: Array<UInt8>, seed: UInt64): UInt64 {
        let len = input.size
        let alignedLen = len - (len % 32)

        // 更新轮次 (32 字节一组)
        var stateSeed = seed
        var stateMsgLen: Int64 = 0

        var off: Int64 = 0
        while (off < alignedLen) {
            // round: 32 字节
            stateSeed = wyMix0(
                wyRead8(input, off), wyRead8(input, off + 8), stateSeed
            ) ^ wyMix1(
                wyRead8(input, off + 16), wyRead8(input, off + 24), stateSeed
            )
            off += 32
        }
        stateMsgLen = alignedLen

        // 尾部
        let tailLen = len - alignedLen
        return wyhashStatelessFinal(stateSeed, stateMsgLen, input, alignedLen, tailLen)
    }

    /// 流式更新
    public func update(b: Array<UInt8>): Unit {
        var off: Int64 = 0

        if (bufLen != 0 && bufLen + b.size >= 32) {
            off = Int64(32) - bufLen
            var i: Int64 = 0
            while (i < off) {
                buf[bufLen + i] = b[i]
                i += 1
            }
            // 处理完整的 32 字节
            seed = wyMix0(
                wyRead8(buf, 0), wyRead8(buf, 8), seed
            ) ^ wyMix1(
                wyRead8(buf, 16), wyRead8(buf, 24), seed
            )
            msgLen += 32
            bufLen = 0
        }

        let remainLen = b.size - off
        let alignedLen = remainLen - (remainLen % 32)

        // 处理完整的 32 字节块
        var i = off
        while (i < off + alignedLen) {
            seed = wyMix0(
                wyRead8(b, i), wyRead8(b, i + 8), seed
            ) ^ wyMix1(
                wyRead8(b, i + 16), wyRead8(b, i + 24), seed
            )
            i += 32
        }
        msgLen += alignedLen

        // 保存尾部到 buf
        let tailStart = off + alignedLen
        let tailLen = b.size - tailStart
        var j: Int64 = 0
        while (j < tailLen) {
            buf[bufLen + j] = b[tailStart + j]
            j += 1
        }
        bufLen += tailLen
    }

    /// 完成哈希
    public func finalize(): UInt64 {
        return wyhashStatelessFinal(seed, msgLen, buf, 0, bufLen)
    }
}

// ============================================================================
// Wyhash (std.hash.Wyhash — final4 变体, 48字节轮次, 4个秘钥)
// 严格翻译自: src/wyhash/lib.rs Wyhash / vendor/zig/lib/std/hash/wyhash.zig
//   用于 Bun.hash(), RuntimeTranspilerCache, router, Zig std HashMap
//   注意: 与 Wyhash11 不可互换
// ============================================================================

/// 4 个 Wyhash final4 秘钥
private let WYHASH_SECRET_0: UInt64 = UInt64(0xa0761d6478bd642f)
private let WYHASH_SECRET_1: UInt64 = UInt64(0xe7037ed1a0b428db)
private let WYHASH_SECRET_2: UInt64 = UInt64(0x8ebc6af09c88c6e3)
private let WYHASH_SECRET_3: UInt64 = UInt64(0x589965cc75374cc3)

// Wyhash final4 mix: (a*b) 的低64位和高64位的异或
private func wyFinal4Mix(a: UInt64, b: UInt64): UInt64 {
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

    return lo ^ hi
}

// mum_: 将 a, b 替换为 128 位乘法的低 64 位和高 64 位
// 返回 (lo, hi) 对
private class MumResult {
    var lo: UInt64
    var hi: UInt64
    init(lo: UInt64, hi: UInt64) {
        this.lo = lo
        this.hi = hi
    }
}

private func wyMumPair(a_: UInt64, b_: UInt64): MumResult {
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

/// Wyhash (final4 变体) - std.hash.Wyhash
/// 对应 Bun: src/wyhash/lib.rs Wyhash
/// 用于 Bun.hash(), RuntimeTranspilerCache, router
/// 支持流式 API: init -> update* -> finalize
public class Wyhash {
    private var a: UInt64
    private var b: UInt64
    private var state0: UInt64
    private var state1: UInt64
    private var state2: UInt64
    private var totalLen: Int64
    private var buf: Array<UInt8>
    private var bufLen: Int64

    public init(seed: UInt64) {
        let s0 = seed ^ wyFinal4Mix(seed ^ WYHASH_SECRET_0, WYHASH_SECRET_1)
        this.a = UInt64(0)
        this.b = UInt64(0)
        this.state0 = s0
        this.state1 = s0
        this.state2 = s0
        this.totalLen = 0
        this.buf = Array<UInt8>(48, item: UInt8(0))
        this.bufLen = 0
    }

    /// 一次性哈希 (种子为 0)
    public static func hash(input: Array<UInt8>): UInt64 {
        return hashWithSeed(input, UInt64(0))
    }

    /// 哈希字符串
    public static func hash(s: String): UInt64 {
        return hash(stringToBytes(s))
    }

    /// 一次性带种子哈希
    /// 对应 Bun: Wyhash::hash(seed, input) -> u64
    public static func hashWithSeed(input: Array<UInt8>, seed: UInt64): UInt64 {
        let s0 = seed ^ wyFinal4Mix(seed ^ WYHASH_SECRET_0, WYHASH_SECRET_1)
        var state0 = s0
        var state1 = s0
        var state2 = s0
        let len = input.size
        var a: UInt64 = UInt64(0)
        var b: UInt64 = UInt64(0)

        if (len <= 16) {
            // small_key
            if (len >= 4) {
                let end = len - 4
                let quarter = (len >> 3) << 2
                a = (wyRead4(input, 0) << UInt64(32)) | wyRead4(input, quarter)
                b = (wyRead4(input, end) << UInt64(32)) | wyRead4(input, end - quarter)
            } else if (len > 0) {
                a = (UInt64(input[0]) << UInt64(16)) |
                    (UInt64(input[len >> 1]) << UInt64(8)) |
                    UInt64(input[len - 1])
                b = UInt64(0)
            } else {
                a = UInt64(0)
                b = UInt64(0)
            }
        } else {
            var i: Int64 = 0
            if (len >= 48) {
                // round 循环
                while (i + 48 < len) {
                    state0 = wyFinal4Mix(
                        wyRead8(input, i) ^ WYHASH_SECRET_1,
                        wyRead8(input, i + 8) ^ state0
                    )
                    state1 = wyFinal4Mix(
                        wyRead8(input, i + 16) ^ WYHASH_SECRET_2,
                        wyRead8(input, i + 24) ^ state1
                    )
                    state2 = wyFinal4Mix(
                        wyRead8(input, i + 32) ^ WYHASH_SECRET_3,
                        wyRead8(input, i + 40) ^ state2
                    )
                    i += 48
                }
                // final0
                state0 = state0 ^ state1 ^ state2
            }
            // final1
            var j = i
            while (j + 16 < len) {
                state0 = wyFinal4Mix(
                    wyRead8(input, j) ^ WYHASH_SECRET_1,
                    wyRead8(input, j + 8) ^ state0
                )
                j += 16
            }
            a = wyRead8(input, len - 16)
            b = wyRead8(input, len - 8)
        }

        // final2
        a = a ^ WYHASH_SECRET_1
        b = b ^ state0
        let mumR = wyMumPair(a, b)
        return wyFinal4Mix(
            mumR.lo ^ WYHASH_SECRET_0 ^ UInt64(len),
            mumR.hi ^ WYHASH_SECRET_1
        )
    }

    /// 带种子哈希字符串
    public static func hashWithSeed(s: String, seed: UInt64): UInt64 {
        return hashWithSeed(stringToBytes(s), seed)
    }

    /// 哈希并截断为 UInt32
    public static func hash32(input: Array<UInt8>): UInt32 {
        return UInt32(hash(input) & UInt64(0xFFFFFFFF))
    }

    /// 流式更新
    public func update(input: Array<UInt8>): Unit {
        totalLen += input.size

        if (input.size <= 48 - bufLen) {
            var i: Int64 = 0
            while (i < input.size) {
                buf[bufLen + i] = input[i]
                i += 1
            }
            bufLen += input.size
            return
        }

        var i: Int64 = 0

        if (bufLen > 0) {
            i = Int64(48) - bufLen
            var j: Int64 = 0
            while (j < i) {
                buf[bufLen + j] = input[j]
                j += 1
            }
            round(buf)
            bufLen = 0
        }

        while (i + 48 < input.size) {
            var block = Array<UInt8>(48, item: UInt8(0))
            var j: Int64 = 0
            while (j < 48) {
                block[j] = input[i + j]
                j += 1
            }
            round(block)
            i += 48
        }

        let remaining = input.size - i
        if (remaining < 16 && i >= 48) {
            let rem = 16 - remaining
            var j: Int64 = 0
            while (j < rem) {
                buf[48 - rem + j] = input[i - rem + j]
                j += 1
            }
        }
        var j: Int64 = 0
        while (j < remaining) {
            buf[j] = input[i + j]
            j += 1
        }
        bufLen = remaining
    }

    /// 完成哈希
    public func finalize(): UInt64 {
        // 创建浅拷贝以确保幂等
        var a_ = a
        var b_ = b
        var s0 = state0
        var s1 = state1
        var s2 = state2
        let total = totalLen

        if (total <= 16) {
            // small_key
            if (bufLen >= 4) {
                let end = bufLen - 4
                let quarter = (bufLen >> 3) << 2
                a_ = (wyRead4(buf, 0) << UInt64(32)) | wyRead4(buf, quarter)
                b_ = (wyRead4(buf, end) << UInt64(32)) | wyRead4(buf, end - quarter)
            } else if (bufLen > 0) {
                a_ = (UInt64(buf[0]) << UInt64(16)) |
                     (UInt64(buf[bufLen >> 1]) << UInt64(8)) |
                     UInt64(buf[bufLen - 1])
                b_ = UInt64(0)
            } else {
                a_ = UInt64(0)
                b_ = UInt64(0)
            }
        } else {
            // 构建 input_lb 和 offset
            var scratch = Array<UInt8>(16, item: UInt8(0))
            var offset: Int64 = 0

            if (bufLen < 16) {
                let rem = 16 - bufLen
                var j: Int64 = 0
                while (j < rem) {
                    scratch[j] = buf[48 - rem + j]
                    j += 1
                }
                var k: Int64 = 0
                while (k < bufLen) {
                    scratch[rem + k] = buf[k]
                    k += 1
                }
                offset = rem
                // scratch 长度 = rem + bufLen = 16
                // final0
                s0 = s0 ^ s1 ^ s2
                // final1: input_lb = scratch, start_pos = offset = rem
                // input = scratch[rem..16], 其长度 = bufLen (< 16)
                // 不可能进入 while 循环 (offset + 16 > scratch.size)
                // input_lb[input_lb.len() - 16..] = scratch[0..8]
                // input_lb[input_lb.len() - 8..]  = scratch[8..16]
                a_ = wyRead8(scratch, 0)
                b_ = wyRead8(scratch, 8)
            } else {
                // final0
                s0 = s0 ^ s1 ^ s2
                // final1
                var j2: Int64 = 0
                while (j2 + 16 < bufLen) {
                    s0 = wyFinal4Mix(
                        wyRead8(buf, j2) ^ WYHASH_SECRET_1,
                        wyRead8(buf, j2 + 8) ^ s0
                    )
                    j2 += 16
                }
                a_ = wyRead8(buf, bufLen - 16)
                b_ = wyRead8(buf, bufLen - 8)
            }
        }

        // final2
        a_ = a_ ^ WYHASH_SECRET_1
        b_ = b_ ^ s0
        let mumR = wyMumPair(a_, b_)
        return wyFinal4Mix(
            mumR.lo ^ WYHASH_SECRET_0 ^ UInt64(total),
            mumR.hi ^ WYHASH_SECRET_1
        )
    }

    // 48 字节轮处理
    private func round(input: Array<UInt8>): Unit {
        state0 = wyFinal4Mix(
            wyRead8(input, 0) ^ WYHASH_SECRET_1,
            wyRead8(input, 8) ^ state0
        )
        state1 = wyFinal4Mix(
            wyRead8(input, 16) ^ WYHASH_SECRET_2,
            wyRead8(input, 24) ^ state1
        )
        state2 = wyFinal4Mix(
            wyRead8(input, 32) ^ WYHASH_SECRET_3,
            wyRead8(input, 40) ^ state2
        )
    }
}

// ============================================================================
// 整数哈希 (std.hash.int)
// 对应 Bun: src/wyhash/lib.rs hash_int
//   整数到整数的哈希 (相同宽度输入输出)
// ============================================================================

/// 整数哈希工具
public class HashInt {
    /// UInt16 哈希
    /// 来源: https://github.com/skeeto/hash-prospector
    public static func hash16(x: UInt16): UInt16 {
        var v = x
        v = (v ^ (v >> UInt16(7))) * UInt16(0x2993)
        v = (v ^ (v >> UInt16(5))) * UInt16(0xe877)
        v = (v ^ (v >> UInt16(9))) * UInt16(0x0235)
        return v ^ (v >> UInt16(10))
    }

    /// UInt32 哈希
    /// 来源: https://github.com/skeeto/hash-prospector
    public static func hash32(x: UInt32): UInt32 {
        var v = x
        v = (v ^ (v >> UInt32(17))) * UInt32(0xed5ad4bb)
        v = (v ^ (v >> UInt32(11))) * UInt32(0xac4c1b51)
        v = (v ^ (v >> UInt32(15))) * UInt32(0x31848bab)
        return v ^ (v >> UInt32(14))
    }

    /// UInt64 哈希
    /// 来源: https://github.com/jonmaiga/mx3
    public static func hash64(x: UInt64): UInt64 {
        let c: UInt64 = UInt64(0xbea225f9eb34556d)
        var v = x
        v = (v ^ (v >> UInt64(32))) * c
        v = (v ^ (v >> UInt64(29))) * c
        v = (v ^ (v >> UInt64(32))) * c
        return v ^ (v >> UInt64(29))
    }
}

/// 字符串转字节数组
private func stringToBytes(s: String): Array<UInt8> {
    var bytes = Array<UInt8>()
    for (c in s) { bytes.append(UInt8(c.value)) }
    return bytes
}
