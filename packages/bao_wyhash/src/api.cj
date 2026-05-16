package bao_wyhash

// Public convenience functions
// Strictly translated from: src/wyhash/lib.rs bottom-level public functions (lines 809-862)
//
//   pub fn hash(bytes: &[u8]) -> u64             // bun.hash(bytes)
//   pub fn hash32(bytes: &[u8]) -> u32           // truncate to 32-bit
//   pub fn hash_with_seed(seed, bytes) -> u64    // bun.hashWithSeed(seed, bytes)
//   pub fn hash_ascii_lowercase(seed, bytes)     // ASCII-lowercased hash
//   pub fn auto_hash(key: &K) -> u64             // generic hash through OneShotHasher
//   pub fn hash_const(seed, input) -> u64        // const-fn equivalent (runtime)

/// bun.hash(bytes) — std.hash.Wyhash with seed 0.
/// Rust: pub fn hash(bytes: &[u8]) -> u64 { Wyhash::hash(0, bytes) }
public func wyhashHash(bytes: Array<UInt8>): UInt64 {
    Wyhash.hash(UInt64(0), bytes)
}

/// bun.hash truncated to UInt32.
/// Rust: pub fn hash32(bytes: &[u8]) -> u32 { hash(bytes) as u32 }
public func wyhashHash32(bytes: Array<UInt8>): UInt32 {
    UInt32(wyhashHash(bytes) & UInt64(0xFFFFFFFF))
}

/// bun.hashWithSeed(seed, bytes) — std.hash.Wyhash with explicit seed.
/// Rust: pub fn hash_with_seed(seed: u64, bytes: &[u8]) -> u64 { Wyhash::hash(seed, bytes) }
public func wyhashHashWithSeed(seed: UInt64, bytes: Array<UInt8>): UInt64 {
    Wyhash.hash(seed, bytes)
}

/// std.hash.Wyhash over the ASCII-lowercased view of bytes.
/// Streamed through a 48-byte stack scratch so no heap allocation occurs
/// regardless of input length. ASCII-only (A-Z -> a-z); non-ASCII bytes pass
/// through unchanged.
/// Rust: pub fn hash_ascii_lowercase(seed: u64, bytes: &[u8]) -> u64
public func wyhashHashAsciiLowercase(seed: UInt64, bytes: Array<UInt8>): UInt64 {
    let len = bytes.size
    // Fast path: one-shot hash on the lowered copy
    if (len <= 48) {
        var lowered = Array<UInt8>(len, repeat: UInt8(0))
        var i: Int64 = 0
        while (i < len) {
            let b = bytes[i]
            if (b >= UInt8(65) && b <= UInt8(90)) {  // 'A'..'Z'
                lowered[i] = b + UInt8(32)
            } else {
                lowered[i] = b
            }
            i += 1
        }
        return Wyhash.hash(seed, lowered)
    }
    // Long input: streaming 48-byte chunks
    let h = Wyhash(seed)
    var off: Int64 = 0
    while (off < len) {
        let chunkLen = if (off + 48 <= len) { Int64(48) } else { len - off }
        var chunk = Array<UInt8>(chunkLen, repeat: UInt8(0))
        var i: Int64 = 0
        while (i < chunkLen) {
            let b = bytes[off + i]
            if (b >= UInt8(65) && b <= UInt8(90)) {
                chunk[i] = b + UInt8(32)
            } else {
                chunk[i] = b
            }
            i += 1
        }
        h.update(chunk)
        off += chunkLen
    }
    h.final_()
}

/// Generic auto-hash function using OneShotHasher.
/// Rust: pub fn auto_hash<K: Hash + ?Sized>(key: &K) -> u64
public func autoHash(data: Array<UInt8>): UInt64 {
    let h = OneShotHasher()
    h.write(data)
    h.finish()
}

/// Compile-time const hash (runtime equivalent).
/// Rust: pub const fn hash_const(seed: u64, input: &[u8]) -> u64
/// In Rust this is const fn for compile-time symbol name generation.
/// Cangjie has no compile-time evaluation; this is the runtime equivalent.
/// Must produce identical results to Wyhash.hash(seed, input).
public func wyhashHashConst(seed: UInt64, input: Array<UInt8>): UInt64 {
    // Parallel one-shot port of Wyhash::hash for const-eval equivalence.
    // Implementation mirrors Wyhash::hash exactly.
    Wyhash.hash(seed, input)
}

/// Hash any UInt64 integer through the integer-to-integer hash.
/// Rust: pub fn hash_int<T: HashInt>(input: T) -> T
public func hashInt(input: UInt32): UInt32 {
    hashInt32(input)
}
