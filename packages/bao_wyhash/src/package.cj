// bao_wyhash - Wyhash fast non-cryptographic 64-bit hash
// Strictly translated from: src/wyhash/lib.rs + src/wyhash/wyhash.zig
//
// This package provides two Wyhash variants:
//   Wyhash11 - legacy variant (32-byte rounds, 5 primes)
//              Translated from: src/wyhash/wyhash.zig Wyhash11 / WyhashStateless
//              and: src/wyhash/lib.rs Wyhash11 / WyhashStateless
//   Wyhash   - current std.hash.Wyhash (final4 variant, 48-byte rounds, 4 secrets)
//              Translated from: src/wyhash/lib.rs Wyhash
//              Ported from: vendor/zig/lib/std/hash/wyhash.zig
//
// THESE ARE DIFFERENT ALGORITHMS. They produce different outputs for the same input.
package bao_wyhash
