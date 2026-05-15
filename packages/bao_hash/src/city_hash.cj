// bao_hash - CityHash 哈希算法
// 严格翻译自: src/hash/cityhash.rs (源自 vendor/zig/lib/std/hash/cityhash.zig)
//   CityHash 是 Google 开发的非加密型哈希函数
//   Bun 在 HashObject 中通过 hashWrap 暴露 cityHash32/cityHash64
package bao_hash

// ============================================================================
// CityHash32 / CityHash64
// 严格翻译自: src/hash/cityhash.rs
//   遵循 Google 的参考实现 / Abseil
//   HashObject.zig 暴露:
//     - cityHash32 -> CityHash32.hash(input) (无 seed, JS seed 被忽略)
//     - cityHash64 -> CityHash64.hashWithSeed(input, seed)
// ============================================================================

// 从字节数组偏移位置读取小端 UInt32
private func fetch32(b: Array<UInt8>, offset: Int64): UInt32 {
    return UInt32(b[offset]) |
           (UInt32(b[offset + 1]) << UInt32(8)) |
           (UInt32(b[offset + 2]) << UInt32(16)) |
           (UInt32(b[offset + 3]) << UInt32(24))
}

// 从字节数组偏移位置读取小端 UInt64
private func fetch64(b: Array<UInt8>, offset: Int64): UInt64 {
    return UInt64(b[offset]) |
           (UInt64(b[offset + 1]) << UInt64(8)) |
           (UInt64(b[offset + 2]) << UInt64(16)) |
           (UInt64(b[offset + 3]) << UInt64(24)) |
           (UInt64(b[offset + 4]) << UInt64(32)) |
           (UInt64(b[offset + 5]) << UInt64(40)) |
           (UInt64(b[offset + 6]) << UInt64(48)) |
           (UInt64(b[offset + 7]) << UInt64(56))
}

// Murmur3 的 fmix32 最终混合
private func fmix32(h: UInt32): UInt32 {
    var x = h
    x = x ^ (x >> UInt32(16))
    x = x * UInt32(0x85ebca6b)
    x = x ^ (x >> UInt32(13))
    x = x * UInt32(0xc2b2ae35)
    x = x ^ (x >> UInt32(16))
    return x
}

// ============================================================================
// CityHash32
// ============================================================================

/// CityHash32 - 32位哈希
/// 对应 Bun: std.hash.CityHash32
/// 无种子版本, JS 端的 seed 参数被忽略
public class CityHash32 {
    // Murmur3 魔术常量
    private static let C1: UInt32 = UInt32(0xcc9e2d51)
    private static let C2: UInt32 = UInt32(0x1b873593)

    private static func rotr32(x: UInt32, r: UInt32): UInt32 {
        return (x >> r) | (x << (UInt32(32) - r))
    }

    // Murmur3 辅助: 合并两个 32 位值
    private static func mur(a: UInt32, h: UInt32): UInt32 {
        var a1 = a
        var h1 = h
        a1 = a1 * C1
        a1 = rotr32(a1, UInt32(17))
        a1 = a1 * C2
        h1 = h1 ^ a1
        h1 = rotr32(h1, UInt32(19))
        return h1 * UInt32(5) + UInt32(0xe6546b64)
    }

    // 0-4 字节
    private static func hash32Len0To4(str: Array<UInt8>): UInt32 {
        let len = UInt32(str.size)
        var b: UInt32 = UInt32(0)
        var c: UInt32 = UInt32(9)
        for (v in str) {
            // Zig: @bitCast(@intCast(@bitCast(v) as i8) as i32) — 符号扩展字节
            let sv = Int64(v)
            let signExtended = if (sv >= 128) { sv - 256 } else { sv }
            b = b * C1 + UInt32(signExtended & UInt64(0xFFFFFFFF))
            c = c ^ b
        }
        return fmix32(mur(b, mur(len, c)))
    }

    // 5-12 字节
    private static func hash32Len5To12(str: Array<UInt8>): UInt32 {
        var a: UInt32 = UInt32(str.size)
        var b: UInt32 = a * UInt32(5)
        let c: UInt32 = UInt32(9)
        let d: UInt32 = b

        a = a + fetch32(str, 0)
        b = b + fetch32(str, str.size - 4)
        let midOff = (str.size >> 1) & 4
        let c1 = c + fetch32(str, midOff)

        return fmix32(mur(c1, mur(b, mur(a, d))))
    }

    // 13-24 字节
    private static func hash32Len13To24(str: Array<UInt8>): UInt32 {
        let len = UInt32(str.size)
        let a = fetch32(str, (str.size >> 1) - 4)
        let b = fetch32(str, 4)
        let c = fetch32(str, str.size - 8)
        let d = fetch32(str, str.size >> 1)
        let e = fetch32(str, 0)
        let f = fetch32(str, str.size - 4)

        return fmix32(mur(f, mur(e, mur(d, mur(c, mur(b, mur(a, len)))))))
    }

    /// 计算 CityHash32
    /// 对应 Bun: CityHash32::hash(str) -> u32
    public static func hash(str: Array<UInt8>): UInt32 {
        if (str.size <= 24) {
            if (str.size <= 4) {
                return hash32Len0To4(str)
            } else if (str.size <= 12) {
                return hash32Len5To12(str)
            }
            return hash32Len13To24(str)
        }

        let len = UInt32(str.size)
        var h: UInt32 = len
        var g: UInt32 = C1 * len
        var f: UInt32 = g

        let a0 = rotr32(fetch32(str, str.size - 4) * C1, UInt32(17)) * C2
        let a1 = rotr32(fetch32(str, str.size - 8) * C1, UInt32(17)) * C2
        let a2 = rotr32(fetch32(str, str.size - 16) * C1, UInt32(17)) * C2
        let a3 = rotr32(fetch32(str, str.size - 12) * C1, UInt32(17)) * C2
        let a4 = rotr32(fetch32(str, str.size - 20) * C1, UInt32(17)) * C2

        h = h ^ a0
        h = rotr32(h, UInt32(19))
        h = h * UInt32(5) + UInt32(0xe6546b64)
        h = h ^ a2
        h = rotr32(h, UInt32(19))
        h = h * UInt32(5) + UInt32(0xe6546b64)
        g = g ^ a1
        g = rotr32(g, UInt32(19))
        g = g * UInt32(5) + UInt32(0xe6546b64)
        g = g ^ a3
        g = rotr32(g, UInt32(19))
        g = g * UInt32(5) + UInt32(0xe6546b64)
        f = f + a4
        f = rotr32(f, UInt32(19))
        f = f * UInt32(5) + UInt32(0xe6546b64)

        var iters = (str.size - 1) / 20
        var off: Int64 = 0
        while (iters != 0) {
            let b0 = rotr32(fetch32(str, off) * C1, UInt32(17)) * C2
            let b1 = fetch32(str, off + 4)
            let b2 = rotr32(fetch32(str, off + 8) * C1, UInt32(17)) * C2
            let b3 = rotr32(fetch32(str, off + 12) * C1, UInt32(17)) * C2
            let b4 = fetch32(str, off + 16)

            h = h ^ b0
            h = rotr32(h, UInt32(18))
            h = h * UInt32(5) + UInt32(0xe6546b64)
            f = f + b1
            f = rotr32(f, UInt32(19))
            f = f * C1
            g = g + b2
            g = rotr32(g, UInt32(18))
            g = g * UInt32(5) + UInt32(0xe6546b64)
            h = h ^ (b3 + b1)
            h = rotr32(h, UInt32(19))
            h = h * UInt32(5) + UInt32(0xe6546b64)
            g = g ^ b4
            // Zig: g.swap_bytes() — 字节交换
            g = byteSwap32(g) * UInt32(5)
            h = h + b4 * UInt32(5)
            h = byteSwap32(h)
            f = f + b0
            // 交换 h, f, g 轮转
            let t = h
            h = f
            f = g
            g = t
            off += 20
            iters -= 1
        }

        g = rotr32(g, UInt32(11)) * C1
        g = rotr32(g, UInt32(17)) * C1
        f = rotr32(f, UInt32(11)) * C1
        f = rotr32(f, UInt32(17)) * C1
        h = rotr32(h + g, UInt32(19))
        h = h * UInt32(5) + UInt32(0xe6546b64)
        h = rotr32(h, UInt32(17)) * C1
        h = rotr32(h + f, UInt32(19))
        h = h * UInt32(5) + UInt32(0xe6546b64)
        h = rotr32(h, UInt32(17)) * C1
        return h
    }

    /// 哈希字符串
    public static func hash(s: String): UInt32 {
        return hash(stringToBytes(s))
    }

    private static func byteSwap32(v: UInt32): UInt32 {
        return ((v & UInt32(0xFF)) << UInt32(24)) |
               ((v & UInt32(0xFF00)) << UInt32(8)) |
               ((v & UInt32(0xFF0000)) >> UInt32(8)) |
               ((v >> UInt32(24)) & UInt32(0xFF))
    }
}

// ============================================================================
// CityHash64
// ============================================================================

// 弱哈希对
private class WeakPair {
    var first: UInt64
    var second: UInt64
    init(f: UInt64, s: UInt64) {
        first = f
        second = s
    }
}

/// CityHash64 - 64位哈希
/// 对应 Bun: std.hash.CityHash64
/// 支持带种子哈希
public class CityHash64 {
    // 2^63 到 2^64 之间的素数
    private static let K0: UInt64 = UInt64(0xc3a5c85c97cb3127)
    private static let K1: UInt64 = UInt64(0xb492b66fbe98f273)
    private static let K2: UInt64 = UInt64(0x9ae16a3b2f90404f)

    private static func rotr64(x: UInt64, r: UInt32): UInt64 {
        return (x >> r) | (x << (UInt64(64) - r))
    }

    private static func shiftmix(v: UInt64): UInt64 {
        return v ^ (v >> UInt64(47))
    }

    private static func hashLen16(u: UInt64, v: UInt64): UInt64 {
        return hash128to64(u, v)
    }

    private static func hashLen16Mul(low: UInt64, high: UInt64, mul: UInt64): UInt64 {
        var a = (low ^ high) * mul
        a = a ^ (a >> UInt64(47))
        var b = (high ^ a) * mul
        b = b ^ (b >> UInt64(47))
        return b * mul
    }

    private static func hash128to64(low: UInt64, high: UInt64): UInt64 {
        return hashLen16Mul(low, high, UInt64(0x9ddfea08eb382d69))
    }

    // 0-16 字节
    private static func hashLen0To16(str: Array<UInt8>): UInt64 {
        let len = UInt64(str.size)
        if (len >= 8) {
            let mul = K2 + len * UInt64(2)
            let a = fetch64(str, 0) + K2
            let b = fetch64(str, str.size - 8)
            let c = rotr64(b, UInt32(37)) * mul + a
            let d = (rotr64(a, UInt32(25)) + b) * mul
            return hashLen16Mul(c, d, mul)
        }
        if (len >= 4) {
            let mul = K2 + len * UInt64(2)
            let a = UInt64(fetch32(str, 0))
            return hashLen16Mul(
                len + (a << UInt64(3)),
                UInt64(fetch32(str, str.size - 4)),
                mul
            )
        }
        if (len > 0) {
            let a = UInt64(str[0])
            let b = UInt64(str[str.size >> 1])
            let c = UInt64(str[str.size - 1])
            let y: UInt32 = UInt32(a) + (UInt32(b) << UInt32(8))
            let z: UInt32 = UInt32(str.size) + (UInt32(c) << UInt32(2))
            return shiftmix(UInt64(y) * K2 ^ UInt64(z) * K0) * K2
        }
        return K2
    }

    // 17-32 字节
    private static func hashLen17To32(str: Array<UInt8>): UInt64 {
        let len = UInt64(str.size)
        let mul = K2 + len * UInt64(2)
        let a = fetch64(str, 0) * K1
        let b = fetch64(str, 8)
        let c = fetch64(str, str.size - 8) * mul
        let d = fetch64(str, str.size - 16) * K2

        return hashLen16Mul(
            rotr64(a + b, UInt32(43)) + rotr64(c, UInt32(30)) + d,
            a + rotr64(b + K2, UInt32(18)) + c,
            mul
        )
    }

    // 33-64 字节
    private static func hashLen33To64(str: Array<UInt8>): UInt64 {
        let len = UInt64(str.size)
        let mul = K2 + len * UInt64(2)
        let a = fetch64(str, 0) * K2
        let b = fetch64(str, 8)
        let c = fetch64(str, str.size - 24)
        let d = fetch64(str, str.size - 32)
        let e = fetch64(str, 16) * K2
        let f = fetch64(str, 24) * UInt64(9)
        let g = fetch64(str, str.size - 8)
        let h = fetch64(str, str.size - 16) * mul

        let u = rotr64(a + g, UInt32(43)) + (rotr64(b, UInt32(30)) + c) * UInt64(9)
        let v = ((a + g) ^ d) + f + UInt64(1)
        let w = byteSwap64((u + v) * mul) + h
        let x = rotr64(e + f, UInt32(42)) + c
        let y = byteSwap64((v + w) * mul) + g
        let z = e + f + c
        let a1 = byteSwap64((x + z) * mul + y) + b
        let b1 = shiftmix((z + a1) * mul + d + h) * mul
        return b1 + x
    }

    private static func weakHashLen32WithSeedsHelper(
        w: UInt64, x: UInt64, y: UInt64, z: UInt64,
        a: UInt64, b: UInt64
    ): WeakPair {
        var a1 = a
        var b1 = b
        a1 = a1 + w
        b1 = rotr64(b1 + a1 + z, UInt32(21))
        let c = a1
        a1 = a1 + x + y
        b1 = b1 + rotr64(a1, UInt32(44))
        return WeakPair(a1 + z, b1 + c)
    }

    private static func weakHashLen32WithSeeds(
        str: Array<UInt8>, off: Int64, a: UInt64, b: UInt64
    ): WeakPair {
        return weakHashLen32WithSeedsHelper(
            fetch64(str, off),
            fetch64(str, off + 8),
            fetch64(str, off + 16),
            fetch64(str, off + 24),
            a, b
        )
    }

    /// 计算 CityHash64 (无种子)
    public static func hash(str: Array<UInt8>): UInt64 {
        if (str.size <= 32) {
            if (str.size <= 16) {
                return hashLen0To16(str)
            }
            return hashLen17To32(str)
        } else if (str.size <= 64) {
            return hashLen33To64(str)
        }

        var len = UInt64(str.size)

        var x = fetch64(str, str.size - 40)
        var y = fetch64(str, str.size - 16) + fetch64(str, str.size - 56)
        var z = hashLen16(
            fetch64(str, str.size - 48) + len,
            fetch64(str, str.size - 24)
        )
        var v = weakHashLen32WithSeeds(str, str.size - 64, len, z)
        var w = weakHashLen32WithSeeds(str, str.size - 32, y + K1, x)

        x = x * K1 + fetch64(str, 0)
        len = (len - UInt64(1)) & (^(UInt64(63)))  // ~63u64

        var off: Int64 = 0
        while (true) {
            x = rotr64(x + y + v.first + fetch64(str, off + 8), UInt32(37)) * K1
            y = rotr64(y + v.second + fetch64(str, off + 48), UInt32(42)) * K1
            x = x ^ w.second
            y = y + v.first + fetch64(str, off + 40)
            z = rotr64(z + w.first, UInt32(33)) * K1
            v = weakHashLen32WithSeeds(str, off, v.second * K1, x + w.first)
            w = weakHashLen32WithSeeds(str, off + 32, z + w.second, y + fetch64(str, off + 16))
            // 交换 z 和 x
            let tmp = z
            z = x
            x = tmp

            off += 64
            len = len - UInt64(64)
            if (len == UInt64(0)) {
                break
            }
        }

        return hashLen16(
            hashLen16(v.first, w.first) + shiftmix(y) * K1 + z,
            hashLen16(v.second, w.second) + x
        )
    }

    /// 带种子的 CityHash64
    /// 对应 Bun: CityHash64::hash_with_seed(str, seed) -> u64
    public static func hashWithSeed(str: Array<UInt8>, seed: UInt64): UInt64 {
        return hashWithSeeds(str, K2, seed)
    }

    /// 双种子的 CityHash64
    public static func hashWithSeeds(str: Array<UInt8>, seed0: UInt64, seed1: UInt64): UInt64 {
        return hashLen16(hash(str) - seed0, seed1)
    }

    /// 哈希字符串
    public static func hash(s: String): UInt64 {
        return hash(stringToBytes(s))
    }

    /// 带种子哈希字符串
    public static func hashWithSeed(s: String, seed: UInt64): UInt64 {
        return hashWithSeed(stringToBytes(s), seed)
    }

    private static func byteSwap64(v: UInt64): UInt64 {
        return ((v & UInt64(0xFF)) << UInt64(56)) |
               ((v & UInt64(0xFF00)) << UInt64(40)) |
               ((v & UInt64(0xFF0000)) << UInt64(24)) |
               ((v & UInt64(0xFF000000)) << UInt64(8)) |
               ((v >> UInt64(8)) & UInt64(0xFF000000)) |
               ((v >> UInt64(24)) & UInt64(0xFF0000)) |
               ((v >> UInt64(40)) & UInt64(0xFF00)) |
               ((v >> UInt64(56)) & UInt64(0xFF))
    }
}

/// 字符串转字节数组
private func stringToBytes(s: String): Array<UInt8> {
    var bytes = Array<UInt8>()
    for (c in s) { bytes.append(UInt8(c.value)) }
    return bytes
}
