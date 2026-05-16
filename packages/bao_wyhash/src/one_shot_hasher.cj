package bao_wyhash

// OneShotHasher — one-shot hasher for HashMap-style hashing
// Strictly translated from: src/wyhash/lib.rs OneShotHasher (lines 739-807)
//
// Unlike Wyhash's streaming Hasher impl (which buffers into a 48-byte scratch
// and re-zeroes it on every init/shallow_copy), this folds each write through
// the stateless one-shot path seeded by the running hash. Matches Zig's
// std.hash_map.getAutoHashFn shape: no buffering, no per-key allocation.

/// OneShotHasher: fast hasher for HashMap-style usage.
/// Rust: pub struct OneShotHasher { hash: u64 }
/// Each write re-seeds from the previous output, so multi-write keys still mix
/// without buffering. For the overwhelmingly common single-write case this is
/// one stateless wyhash over the slice.
public class OneShotHasher {
    var hashValue: UInt64

    public init() {
        hashValue = UInt64(0)
    }

    /// write: feed bytes into the hasher.
    /// Rust: fn write(&mut self, bytes: &[u8]) { self.hash = Wyhash11::hash(self.hash, bytes); }
    public func write(bytes: Array<UInt8>): Unit {
        hashValue = Wyhash11.hash(hashValue, bytes)
    }

    /// writeU8: hash a UInt8 value.
    /// Rust: fn write_u8(&mut self, n: u8) { self.write_u64(u64::from(n)); }
    public func writeU8(n: UInt8): Unit {
        writeU64(UInt64(n))
    }

    /// writeU16: hash a UInt16 value.
    /// Rust: fn write_u16(&mut self, n: u16) { self.write_u64(u64::from(n)); }
    public func writeU16(n: UInt16): Unit {
        writeU64(UInt64(n))
    }

    /// writeU32: hash a UInt32 value.
    /// Rust: fn write_u32(&mut self, n: u32) { self.write_u64(u64::from(n)); }
    public func writeU32(n: UInt32): Unit {
        writeU64(UInt64(n))
    }

    /// writeU64: hash a UInt64 value via cheap diffusion (one 128-bit multiply).
    /// Rust: fn write_u64(&mut self, n: u64) { self.hash = mum(self.hash ^ n, PRIMES[4]); }
    public func writeU64(n: UInt64): Unit {
        hashValue = mum(hashValue ^ n, PRIMES_4)
    }

    /// writeLengthPrefix: no-op.
    /// Rust: fn write_length_prefix(&mut self, _len: usize) {}
    /// Keys hashed through this hasher are never cross-type, so the prefix-freedom
    /// guarantee is unused. Skipping it makes <[u8] as Hash> collapse to a single write(bytes).
    public func writeLengthPrefix(len: Int64): Unit {
        // intentionally no-op
    }

    /// writeUSize: hash a usize value.
    /// Rust: fn write_usize(&mut self, n: usize) { self.write_u64(n as u64); }
    public func writeUSize(n: Int64): Unit {
        writeU64(UInt64(n))
    }

    /// finish: return the current hash value.
    /// Rust: fn finish(&self) -> u64 { self.hash }
    public func finish(): UInt64 {
        hashValue
    }
}
