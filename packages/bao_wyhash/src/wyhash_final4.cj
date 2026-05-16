package bao_wyhash

// Wyhash (std.hash.Wyhash — final4 variant, 48-byte rounds, 4 secrets)
// Strictly translated from: src/wyhash/lib.rs lines 401-705
//   struct Wyhash { a: u64, b: u64, state: [u64; 3], total_len: usize, buf: [u8; 48], buf_len: usize }
// Ported from vendor/zig/lib/std/hash/wyhash.zig
//
// NOT interchangeable with Wyhash11.

// ============================================================================
// Constants: 4 Wyhash final4 secrets
// Translated from: src/wyhash/lib.rs Wyhash::SECRET
// ============================================================================

/// Secret 0: 0xa0761d6478bd642f
let SECRET_0: UInt64 = (UInt64(0xa0761d64) << UInt64(32)) | UInt64(0x78bd642f)
/// Secret 1: 0xe7037ed1a0b428db
let SECRET_1: UInt64 = (UInt64(0xe7037ed1) << UInt64(32)) | UInt64(0xa0b428db)
/// Secret 2: 0x8ebc6af09c88c6e3
let SECRET_2: UInt64 = (UInt64(0x8ebc6af0) << UInt64(32)) | UInt64(0x9c88c6e3)
/// Secret 3: 0x589965cc75374cc3
let SECRET_3: UInt64 = UInt64(0x589965cc75374cc3)

// ============================================================================
// mum_ — 128-bit multiply returning both low and high 64-bit halves
// Translated from: src/wyhash/lib.rs Wyhash::mum_
//   Rust: fn mum_(a: &mut u64, b: &mut u64) { let x = (*a as u128).wrapping_mul(*b as u128); *a = x as u64; *b = (x >> 64) as u64; }
// ============================================================================

/// MumResult holds the low and high 64-bit halves of a 128-bit multiply.
class MumResult {
    var lo: UInt64
    var hi: UInt64
    init(lo: UInt64, hi: UInt64) {
        this.lo = lo
        this.hi = hi
    }
}

/// mum_: 64x64->128 multiply, returning (lo, hi).
/// Rust: fn mum_(a: &mut u64, b: &mut u64)
func mum_(a: UInt64, b: UInt64): MumResult {
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

    MumResult(lo, hi)
}

/// mix: mum_ then XOR low and high halves.
/// Rust: fn mix(a_: u64, b_: u64) -> u64 { let mut a = a_; let mut b = b_; Self::mum_(&mut a, &mut b); a ^ b }
func wyMix(a_: UInt64, b_: UInt64): UInt64 {
    let r = mum_(a_, b_)
    r.lo ^ r.hi
}

// ============================================================================
// read4 / read8 — little-endian reads for the final4 variant
// Translated from: src/wyhash/lib.rs Wyhash::read4 / Wyhash::read8
// ============================================================================

/// Read 4 bytes little-endian as UInt64.
/// Rust: fn read4(data: &[u8]) -> u64
func wyRead4(data: Array<UInt8>, off: Int64): UInt64 {
    UInt64(data[off]) |
        (UInt64(data[off + 1]) << UInt64(8)) |
        (UInt64(data[off + 2]) << UInt64(16)) |
        (UInt64(data[off + 3]) << UInt64(24))
}

/// Read 8 bytes little-endian as UInt64.
/// Rust: fn read8(data: &[u8]) -> u64
func wyRead8(data: Array<UInt8>, off: Int64): UInt64 {
    UInt64(data[off]) |
        (UInt64(data[off + 1]) << UInt64(8)) |
        (UInt64(data[off + 2]) << UInt64(16)) |
        (UInt64(data[off + 3]) << UInt64(24)) |
        (UInt64(data[off + 4]) << UInt64(32)) |
        (UInt64(data[off + 5]) << UInt64(40)) |
        (UInt64(data[off + 6]) << UInt64(48)) |
        (UInt64(data[off + 7]) << UInt64(56))
}

// ============================================================================
// Wyhash — std.hash.Wyhash (final4 variant)
// Translated from: src/wyhash/lib.rs pub struct Wyhash { ... }
//   Used by bun.hash(), RuntimeTranspilerCache, the router, and Zig's std HashMap.
// ============================================================================

/// Wyhash: the final4 variant of Wyhash with 48-byte rounds and 4 secrets.
/// Supports streaming API: init -> update* -> final_
/// NOT interchangeable with Wyhash11.
public class Wyhash {
    var a: UInt64
    var b: UInt64
    var state0: UInt64
    var state1: UInt64
    var state2: UInt64
    var totalLen: Int64
    var buf: Array<UInt8>
    var bufLen: Int64

    public init(seed: UInt64) {
        let s0 = seed ^ wyMix(seed ^ SECRET_0, SECRET_1)
        a = UInt64(0)
        b = UInt64(0)
        state0 = s0
        state1 = s0
        state2 = s0
        totalLen = 0
        buf = Array<UInt8>(48, repeat: UInt8(0))
        bufLen = 0
    }

    /// update: feed data into the streaming hash.
    /// This is subtly different from other hash function update calls.
    /// Wyhash requires the last full 48-byte block to be run through final1
    /// if it is exactly aligned to 48-bytes.
    /// Rust: pub fn update(&mut self, input: &[u8])
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
            var block = Array<UInt8>(48, repeat: UInt8(0))
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
            let rem = Int64(16) - remaining
            var j: Int64 = 0
            while (j < rem) {
                buf[Int64(48) - rem + j] = input[i - rem + j]
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

    /// final_: return the finalized hash value.
    /// Rust: pub fn final_(&self) -> u64
    public func final_(): UInt64 {
        // shallow copy for idempotency
        var a_ = a
        var b_ = b
        var s0 = state0
        var s1 = state1
        var s2 = state2
        let total = totalLen

        if (total <= 16) {
            // small_key path
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
            // Build input_lb and offset
            var scratch = Array<UInt8>(16, repeat: UInt8(0))
            var offset: Int64 = 0

            if (bufLen < 16) {
                let rem = Int64(16) - bufLen
                var j2: Int64 = 0
                while (j2 < rem) {
                    scratch[j2] = buf[Int64(48) - rem + j2]
                    j2 += 1
                }
                var k: Int64 = 0
                while (k < bufLen) {
                    scratch[rem + k] = buf[k]
                    k += 1
                }
                offset = rem

                // final0
                s0 = s0 ^ s1 ^ s2

                // final1 with scratch as input_lb
                // scratch length = rem + bufLen = 16
                // input = scratch[offset..16], length = bufLen (< 16)
                // j + 16 < input.len won't trigger since offset + 16 >= 16
                a_ = wyRead8(scratch, 0)
                b_ = wyRead8(scratch, 8)
            } else {
                // final0
                s0 = s0 ^ s1 ^ s2

                // final1 with buf as input_lb
                var j2: Int64 = 0
                while (j2 + 16 < bufLen) {
                    s0 = wyMix(
                        wyRead8(buf, j2) ^ SECRET_1,
                        wyRead8(buf, j2 + 8) ^ s0,
                    )
                    j2 += 16
                }
                a_ = wyRead8(buf, bufLen - 16)
                b_ = wyRead8(buf, bufLen - 8)
            }
        }

        // final2
        a_ = a_ ^ SECRET_1
        b_ = b_ ^ s0
        let mumR = mum_(a_, b_)
        wyMix(
            mumR.lo ^ SECRET_0 ^ UInt64(total),
            mumR.hi ^ SECRET_1,
        )
    }

    /// round: process a 48-byte aligned block.
    /// Rust: fn round(&mut self, input: &[u8; 48])
    func round(input: Array<UInt8>): Unit {
        // inline for (0..3) |i| — manually unrolled
        state0 = wyMix(
            wyRead8(input, 0) ^ SECRET_1,
            wyRead8(input, 8) ^ state0,
        )
        state1 = wyMix(
            wyRead8(input, 16) ^ SECRET_2,
            wyRead8(input, 24) ^ state1,
        )
        state2 = wyMix(
            wyRead8(input, 32) ^ SECRET_3,
            wyRead8(input, 40) ^ state2,
        )
    }

    /// hash: one-shot hash (seed + input -> u64).
    /// Rust: pub fn hash(seed: u64, input: &[u8]) -> u64
    public static func hash(seed: UInt64, input: Array<UInt8>): UInt64 {
        let s0 = seed ^ wyMix(seed ^ SECRET_0, SECRET_1)
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
                // Hot path: round loop (48-byte blocks)
                let bound = len - 48
                while (i < bound) {
                    state0 = wyMix(
                        wyRead8(input, i) ^ SECRET_1,
                        wyRead8(input, i + 8) ^ state0,
                    )
                    state1 = wyMix(
                        wyRead8(input, i + 16) ^ SECRET_2,
                        wyRead8(input, i + 24) ^ state1,
                    )
                    state2 = wyMix(
                        wyRead8(input, i + 32) ^ SECRET_3,
                        wyRead8(input, i + 40) ^ state2,
                    )
                    i += 48
                }
                // final0
                state0 = state0 ^ state1 ^ state2
            }
            // final1
            var j = i
            while (j + 16 < len) {
                state0 = wyMix(
                    wyRead8(input, j) ^ SECRET_1,
                    wyRead8(input, j + 8) ^ state0,
                )
                j += 16
            }
            a = wyRead8(input, len - 16)
            b = wyRead8(input, len - 8)
        }

        // final2 (mum_ inlined)
        a = a ^ SECRET_1
        b = b ^ state0
        let mumR = mum_(a, b)
        wyMix(
            mumR.lo ^ SECRET_0 ^ UInt64(len),
            mumR.hi ^ SECRET_1,
        )
    }
}
