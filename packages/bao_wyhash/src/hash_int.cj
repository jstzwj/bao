package bao_wyhash

// hash_int — integer-to-integer hashing (same width in, same width out)
// Strictly translated from: src/wyhash/lib.rs hash_int / trait HashInt (lines 959-1006)
//
// Zig's version is anytype-generic; Rust covers 16/32/64 via a sealed trait.
// All current callers pass u32.

/// HashInt16: hash a UInt16 to UInt16.
/// Source: https://github.com/skeeto/hash-prospector
/// Rust: impl HashInt for u16 { fn hash_int(self) -> u16 { ... } }
public func hashInt16(input: UInt16): UInt16 {
    var x = input
    x = (x ^ (x >> UInt16(7))) * UInt16(0x2993)
    x = (x ^ (x >> UInt16(5))) * UInt16(0xe877)
    x = (x ^ (x >> UInt16(9))) * UInt16(0x0235)
    x ^ (x >> UInt16(10))
}

/// HashInt32: hash a UInt32 to UInt32.
/// Source: https://github.com/skeeto/hash-prospector
/// Rust: impl HashInt for u32 { fn hash_int(self) -> u32 { ... } }
public func hashInt32(input: UInt32): UInt32 {
    var x = input
    x = (x ^ (x >> UInt32(17))) * UInt32(0xed5ad4bb)
    x = (x ^ (x >> UInt32(11))) * UInt32(0xac4c1b51)
    x = (x ^ (x >> UInt32(15))) * UInt32(0x31848bab)
    x ^ (x >> UInt32(14))
}

/// HashInt64: hash a UInt64 to UInt64.
/// Source: https://github.com/jonmaiga/mx3
/// Rust: impl HashInt for u64 { fn hash_int(self) -> u64 { ... } }
public func hashInt64(input: UInt64): UInt64 {
    let c: UInt64 = (UInt64(0xbea225f9) << UInt64(32)) | UInt64(0xeb34556d)
    var x = input
    x = (x ^ (x >> UInt64(32))) * c
    x = (x ^ (x >> UInt64(29))) * c
    x = (x ^ (x >> UInt64(32))) * c
    x ^ (x >> UInt64(29))
}
