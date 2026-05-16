package bao_wyhash

// Wyhash11 (legacy, 32-byte rounds, 5 primes) + WyhashStateless
// Strictly translated from: src/wyhash/lib.rs lines 17-328
// Also from: src/wyhash/wyhash.zig WyhashStateless + Wyhash11

// ============================================================================
// Constants: 5 Wyhash primes
// Translated from: src/wyhash/lib.rs PRIMES / src/wyhash/wyhash.zig primes
// ============================================================================

/// Prime 0: 0xa0761d6478bd642f
let PRIMES_0: UInt64 = (UInt64(0xa0761d64) << UInt64(32)) | UInt64(0x78bd642f)
/// Prime 1: 0xe7037ed1a0b428db
let PRIMES_1: UInt64 = (UInt64(0xe7037ed1) << UInt64(32)) | UInt64(0xa0b428db)
/// Prime 2: 0x8ebc6af09c88c6e3
let PRIMES_2: UInt64 = (UInt64(0x8ebc6af0) << UInt64(32)) | UInt64(0x9c88c6e3)
/// Prime 3: 0x589965cc75374cc3
let PRIMES_3: UInt64 = UInt64(0x589965cc75374cc3)
/// Prime 4: 0x1d8e4e27c47d124f
let PRIMES_4: UInt64 = UInt64(0x1d8e4e27c47d124f)

// ============================================================================
// read_bytes — unaligned little-endian integer loads
// Translated from: src/wyhash/lib.rs read_bytes<const BYTES> / src/wyhash/wyhash.zig read_bytes
// Zig: inline fn read_bytes(comptime bytes: u8, data: []const u8) u64
// Rust: fn read_bytes<const BYTES: u8>(data: &[u8]) -> u64
// Cangjie does not have const generics; dispatch on the 4 widths used (1/2/4/8).
// ============================================================================

/// Read 1 byte from data[off] as UInt64 (little-endian, 1 byte is trivial)
/// Zig: read_bytes(1, data) -> u64   Rust: read_bytes::<1>(data) -> u64
func readBytes1(data: Array<UInt8>, off: Int64): UInt64 {
    UInt64(data[off])
}

/// Read 2 bytes little-endian from data[off..off+2] as UInt64
/// Zig: read_bytes(2, data) -> u64   Rust: read_bytes::<2>(data) -> u64
func readBytes2(data: Array<UInt8>, off: Int64): UInt64 {
    UInt64(data[off]) | (UInt64(data[off + 1]) << UInt64(8))
}

/// Read 4 bytes little-endian from data[off..off+4] as UInt64
/// Zig: read_bytes(4, data) -> u64   Rust: read_bytes::<4>(data) -> u64
func readBytes4(data: Array<UInt8>, off: Int64): UInt64 {
    UInt64(data[off]) |
        (UInt64(data[off + 1]) << UInt64(8)) |
        (UInt64(data[off + 2]) << UInt64(16)) |
        (UInt64(data[off + 3]) << UInt64(24))
}

/// Read 8 bytes little-endian from data[off..off+8] as UInt64
/// Zig: read_bytes(8, data) -> u64   Rust: read_bytes::<8>(data) -> u64
func readBytes8(data: Array<UInt8>, off: Int64): UInt64 {
    UInt64(data[off]) |
        (UInt64(data[off + 1]) << UInt64(8)) |
        (UInt64(data[off + 2]) << UInt64(16)) |
        (UInt64(data[off + 3]) << UInt64(24)) |
        (UInt64(data[off + 4]) << UInt64(32)) |
        (UInt64(data[off + 5]) << UInt64(40)) |
        (UInt64(data[off + 6]) << UInt64(48)) |
        (UInt64(data[off + 7]) << UInt64(56))
}

/// Read 8 bytes swapped: high 32 bits from first 4 bytes, low 32 bits from next 4 bytes.
/// Zig: read_8bytes_swapped(data) -> u64
/// Rust: read_8bytes_swapped(data) -> u64
func read8bytesSwapped(data: Array<UInt8>, off: Int64): UInt64 {
    (readBytes4(data, off) << UInt64(32)) | readBytes4(data, off + 4)
}

// ============================================================================
// mum — 128-bit multiply then fold: (a*b >> 64) ^ (a*b & 0xFFFF_FFFF_FFFF_FFFF)
// Translated from: src/wyhash/lib.rs fn mum(a: u64, b: u64) -> u64
//   Zig: fn mum(a: u64, b: u64) -> u64 { var r = mulWide(u64, a, b); r = (r >> 64) ^ r; @truncate(r) }
//   Rust: fn mum(a: u64, b: u64) -> u64 { let mut r = (a as u128) * (b as u128); r = (r >> 64) ^ r; r as u64 }
// Cangjie has no u128; implement 64x64->128 multiply via 32-bit halves.
// ============================================================================

/// mum: 128-bit multiply then XOR-fold high and low 64-bit halves.
/// Equivalent to ((a as u128) * (b as u128) >> 64) ^ ((a as u128) * (b as u128) as u64)
func mum(a: UInt64, b: UInt64): UInt64 {
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

    lo ^ hi
}

// ============================================================================
// mix0 / mix1 — mixing helpers used by Wyhash11
// Translated from: src/wyhash/lib.rs mix0 / mix1
//   Zig: fn mix0(a, b, seed) -> u64 { mum(a ^ seed ^ primes[0], b ^ seed ^ primes[1]) }
//   Zig: fn mix1(a, b, seed) -> u64 { mum(a ^ seed ^ primes[2], b ^ seed ^ primes[3]) }
// ============================================================================

/// mix0: mum(a ^ seed ^ PRIMES[0], b ^ seed ^ PRIMES[1])
func mix0(a: UInt64, b: UInt64, seed: UInt64): UInt64 {
    mum(a ^ seed ^ PRIMES_0, b ^ seed ^ PRIMES_1)
}

/// mix1: mum(a ^ seed ^ PRIMES[2], b ^ seed ^ PRIMES[3])
func mix1(a: UInt64, b: UInt64, seed: UInt64): UInt64 {
    mum(a ^ seed ^ PRIMES_2, b ^ seed ^ PRIMES_3)
}

// ============================================================================
// finalLong — cold tail of WyhashStateless.final_ for 17..=31 byte remainders
// Translated from: src/wyhash/lib.rs fn final_long(seed: u64, key: &[u8]) -> u64
// Split out so the common short-key path (0..=16) stays small.
// ============================================================================

/// finalLong: process the 17..=31 byte remainder tail (cold path).
/// Rust: #[cold] #[inline(never)] fn final_long(seed: u64, key: &[u8]) -> u64
func finalLong(seed: UInt64, key: Array<UInt8>): UInt64 {
    let head = mix0(
        read8bytesSwapped(key, 0),
        read8bytesSwapped(key, 8),
        seed,
    )
    let tail = matchKeyLen17To31(seed, key, key.size)
    head ^ tail
}

/// Inner match for 17..=31 byte remainders.
/// Separated to mirror the Rust/Zig match structure.
func matchKeyLen17To31(seed: UInt64, key: Array<UInt8>, remLen: Int64): UInt64 {
    if (remLen == 17) {
        return mix1(readBytes1(key, 16), PRIMES_4, seed)
    }
    if (remLen == 18) {
        return mix1(readBytes2(key, 16), PRIMES_4, seed)
    }
    if (remLen == 19) {
        return mix1(
            (readBytes2(key, 16) << UInt64(8)) | readBytes1(key, 18),
            PRIMES_4,
            seed,
        )
    }
    if (remLen == 20) {
        return mix1(readBytes4(key, 16), PRIMES_4, seed)
    }
    if (remLen == 21) {
        return mix1(
            (readBytes4(key, 16) << UInt64(8)) | readBytes1(key, 20),
            PRIMES_4,
            seed,
        )
    }
    if (remLen == 22) {
        return mix1(
            (readBytes4(key, 16) << UInt64(16)) | readBytes2(key, 20),
            PRIMES_4,
            seed,
        )
    }
    if (remLen == 23) {
        return mix1(
            (readBytes4(key, 16) << UInt64(24)) | (readBytes2(key, 20) << UInt64(8)) | readBytes1(key, 22),
            PRIMES_4,
            seed,
        )
    }
    if (remLen == 24) {
        return mix1(read8bytesSwapped(key, 16), PRIMES_4, seed)
    }
    if (remLen == 25) {
        return mix1(
            read8bytesSwapped(key, 16),
            readBytes1(key, 24),
            seed,
        )
    }
    if (remLen == 26) {
        return mix1(
            read8bytesSwapped(key, 16),
            readBytes2(key, 24),
            seed,
        )
    }
    if (remLen == 27) {
        return mix1(
            read8bytesSwapped(key, 16),
            (readBytes2(key, 24) << UInt64(8)) | readBytes1(key, 26),
            seed,
        )
    }
    if (remLen == 28) {
        return mix1(
            read8bytesSwapped(key, 16),
            readBytes4(key, 24),
            seed,
        )
    }
    if (remLen == 29) {
        return mix1(
            read8bytesSwapped(key, 16),
            (readBytes4(key, 24) << UInt64(8)) | readBytes1(key, 28),
            seed,
        )
    }
    if (remLen == 30) {
        return mix1(
            read8bytesSwapped(key, 16),
            (readBytes4(key, 24) << UInt64(16)) | readBytes2(key, 28),
            seed,
        )
    }
    // remLen == 31
    mix1(
        read8bytesSwapped(key, 16),
        (readBytes4(key, 24) << UInt64(24)) | (readBytes2(key, 28) << UInt64(8)) | readBytes1(key, 30),
        seed,
    )
}

// ============================================================================
// WyhashStateless — stateless Wyhash (no partial-buffer handling)
// Translated from: src/wyhash/lib.rs struct WyhashStateless
//   Zig: const WyhashStateless = struct { seed: u64, msg_len: usize, ... }
//   Rust: struct WyhashStateless { seed: u64, msg_len: usize }
// This maximizes speed for the short-key case by using the non-iterative API.
// ============================================================================

/// WyhashStateless: Wyhash variant without internal buffer state.
/// Used for maximum short-key performance via the non-iterative one-shot API.
public class WyhashStateless {
    var seed: UInt64
    var msgLen: Int64

    public init(seed: UInt64) {
        this.seed = seed
        this.msgLen = 0
    }

    /// round: process a 32-byte aligned block.
    /// Zig: inline fn round(self: *WyhashStateless, b: []const u8) void
    /// Rust: fn round(&mut self, b: &[u8]) { debug_assert!(b.len() == 32); ... }
    func round(b: Array<UInt8>) {
        // b.size == 32
        seed = mix0(
            readBytes8(b, 0),
            readBytes8(b, 8),
            seed,
        ) ^ mix1(
            readBytes8(b, 16),
            readBytes8(b, 24),
            seed,
        )
    }

    /// update: process 32-byte-aligned input in rounds.
    /// Zig: pub inline fn update(self: *WyhashStateless, b: []const u8) void
    /// Rust: pub(crate) fn update(&mut self, b: &[u8]) { debug_assert!(b.len() % 32 == 0); ... }
    public func update(b: Array<UInt8>) {
        // b.size % 32 == 0
        var off: Int64 = 0
        while (off < b.size) {
            // round on b[off..off+32]
            seed = mix0(
                readBytes8(b, off),
                readBytes8(b, off + 8),
                seed,
            ) ^ mix1(
                readBytes8(b, off + 16),
                readBytes8(b, off + 24),
                seed,
            )
            off += 32
        }
        msgLen += b.size
    }

    /// final_: process the <32-byte remainder and return the hash.
    /// Zig: pub inline fn final(self: *WyhashStateless, b: []const u8) u64
    /// Rust: pub(crate) fn final_(&mut self, b: &[u8]) -> u64
    /// This is the StringHashMap short-key hash path.
    public func final_(b: Array<UInt8>): UInt64 {
        // b.size < 32
        let seed_ = seed
        let remLen = b.size
        let remKey = b

        if (remLen == 0) {
            seed = seed_
        } else if (remLen == 1) {
            seed = mix0(readBytes1(remKey, 0), PRIMES_4, seed_)
        } else if (remLen == 2) {
            seed = mix0(readBytes2(remKey, 0), PRIMES_4, seed_)
        } else if (remLen == 3) {
            seed = mix0(
                (readBytes2(remKey, 0) << UInt64(8)) | readBytes1(remKey, 2),
                PRIMES_4,
                seed_,
            )
        } else if (remLen == 4) {
            seed = mix0(readBytes4(remKey, 0), PRIMES_4, seed_)
        } else if (remLen == 5) {
            seed = mix0(
                (readBytes4(remKey, 0) << UInt64(8)) | readBytes1(remKey, 4),
                PRIMES_4,
                seed_,
            )
        } else if (remLen == 6) {
            seed = mix0(
                (readBytes4(remKey, 0) << UInt64(16)) | readBytes2(remKey, 4),
                PRIMES_4,
                seed_,
            )
        } else if (remLen == 7) {
            seed = mix0(
                (readBytes4(remKey, 0) << UInt64(24)) | (readBytes2(remKey, 4) << UInt64(8)) | readBytes1(remKey, 6),
                PRIMES_4,
                seed_,
            )
        } else if (remLen == 8) {
            seed = mix0(read8bytesSwapped(remKey, 0), PRIMES_4, seed_)
        } else if (remLen == 9) {
            seed = mix0(
                read8bytesSwapped(remKey, 0),
                readBytes1(remKey, 8),
                seed_,
            )
        } else if (remLen == 10) {
            seed = mix0(
                read8bytesSwapped(remKey, 0),
                readBytes2(remKey, 8),
                seed_,
            )
        } else if (remLen == 11) {
            seed = mix0(
                read8bytesSwapped(remKey, 0),
                (readBytes2(remKey, 8) << UInt64(8)) | readBytes1(remKey, 10),
                seed_,
            )
        } else if (remLen == 12) {
            seed = mix0(
                read8bytesSwapped(remKey, 0),
                readBytes4(remKey, 8),
                seed_,
            )
        } else if (remLen == 13) {
            seed = mix0(
                read8bytesSwapped(remKey, 0),
                (readBytes4(remKey, 8) << UInt64(8)) | readBytes1(remKey, 12),
                seed_,
            )
        } else if (remLen == 14) {
            seed = mix0(
                read8bytesSwapped(remKey, 0),
                (readBytes4(remKey, 8) << UInt64(16)) | readBytes2(remKey, 12),
                seed_,
            )
        } else if (remLen == 15) {
            seed = mix0(
                read8bytesSwapped(remKey, 0),
                (readBytes4(remKey, 8) << UInt64(24)) | (readBytes2(remKey, 12) << UInt64(8)) | readBytes1(remKey, 14),
                seed_,
            )
        } else if (remLen == 16) {
            seed = mix0(
                read8bytesSwapped(remKey, 0),
                read8bytesSwapped(remKey, 8),
                seed_,
            )
        } else {
            // remLen 17..=31: cold tail — keep out of line
            seed = finalLong(seed_, remKey)
        }

        msgLen += b.size
        mum(seed ^ UInt64(msgLen), PRIMES_4)
    }

    /// hash: one-shot hash (seed + input -> u64).
    /// Zig: pub fn hash(seed: u64, input: []const u8) u64
    /// Rust: pub(crate) fn hash(seed: u64, input: &[u8]) -> u64
    public static func hash(seed: UInt64, input: Array<UInt8>): UInt64 {
        let alignedLen = input.size - (input.size % 32)
        let c = WyhashStateless(seed)
        c.update(arraySlice(input, 0, alignedLen))
        c.final_(arraySlice(input, alignedLen, input.size - alignedLen))
    }
}

// ============================================================================
// Wyhash11 — streaming Wyhash (legacy, 32-byte rounds, 5 primes)
// Translated from: src/wyhash/lib.rs pub struct Wyhash11
//   Zig: pub const Wyhash11 = struct { state: WyhashStateless, buf: [32]u8, buf_len: usize, ... }
//   Rust: pub struct Wyhash11 { state: WyhashStateless, buf: [u8; 32], buf_len: usize }
// Fast non-cryptographic 64bit hash function.
// See https://github.com/wangyi-fudan/wyhash
// ============================================================================

/// Wyhash11: the legacy Wyhash variant with 32-byte rounds and 5 primes.
/// Supports streaming API: init -> update* -> final_
/// NOT interchangeable with Wyhash (final4 variant).
public class Wyhash11 {
    var state: WyhashStateless
    var buf: Array<UInt8>
    var bufLen: Int64

    public init(seed: UInt64) {
        state = WyhashStateless(seed)
        buf = Array<UInt8>(32, repeat: UInt8(0))
        bufLen = 0
    }

    /// update: feed data into the streaming hash.
    /// Zig: pub fn update(self: *Wyhash11, b: []const u8) void
    /// Rust: pub fn update(&mut self, b: &[u8])
    public func update(b: Array<UInt8>): Unit {
        var off: Int64 = 0

        if (bufLen != 0 && bufLen + b.size >= 32) {
            off = Int64(32) - bufLen
            // copy b[0..off] into buf[bufLen..bufLen+off]
            var j: Int64 = 0
            while (j < off) {
                buf[bufLen + j] = b[j]
                j += 1
            }
            state.update(buf)
            bufLen = 0
        }

        let remainLen = b.size - off
        let alignedLen = remainLen - (remainLen % 32)
        state.update(arraySlice(b, off, alignedLen))

        // copy tail into buf
        let tailStart = off + alignedLen
        let tailLen = b.size - tailStart
        var k: Int64 = 0
        while (k < tailLen) {
            buf[bufLen + k] = b[tailStart + k]
            k += 1
        }
        bufLen += tailLen
    }

    /// final_: return the finalized hash value.
    /// Zig: pub fn final(self: *Wyhash11) u64
    /// Rust: pub fn final_(&mut self) -> u64
    public func final_(): UInt64 {
        state.final_(arraySlice(buf, 0, bufLen))
    }

    /// hash: one-shot hash (seed + input -> u64). Delegates to WyhashStateless.
    /// Zig: pub fn hash(seed: u64, input: []const u8) u64
    /// Rust: pub fn hash(seed: u64, input: &[u8]) -> u64
    public static func hash(seed: UInt64, input: Array<UInt8>): UInt64 {
        WyhashStateless.hash(seed, input)
    }
}

// ============================================================================
// Helper: slice a sub-array without allocation (returns a new array view).
// In Cangjie, Array<T> slicing creates a copy; this matches Rust's &[u8] semantics.
// ============================================================================
func arraySlice(arr: Array<UInt8>, start: Int64, len: Int64): Array<UInt8> {
    if (len <= 0) {
        return Array<UInt8>()
    }
    return Array<UInt8>(len, { i => arr[start + i] })
}
