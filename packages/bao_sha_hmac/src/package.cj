// package.cj - bao_sha_hmac crate root
// 严格翻译自 Bun: src/sha_hmac/lib.rs + src/sha_hmac/sha.zig + src/sha_hmac/hmac.zig
//
// 对应 Bun 源文件:
//   - lib.rs: crate root, pub mod hmac/sha, re-exports
//   - sha.rs/sha.zig: NewHasher, NewEVP, evp::Algorithm
//   - hmac.rs/hmac.zig: HMAC generate()
//
// 本文件重新导出所有公开类型, 使得依赖方可以:
//   import bao_sha_hmac.*
// 使用 SHA256/EVP/Algorithm/generate 等

package bao_sha_hmac

// ============================================================================
// 重新导出 sha.cj 中的类型 (对应 lib.rs: pub use sha::*)
// ============================================================================

// EVP 哈希器类型 (对应 sha.zig: pub const SHA1 = EVP.SHA1 等)
// 这些在 sha.cj 中定义, 此处通过 import 获取

// ============================================================================
// 重新导出 hmac.cj 中的函数 (对应 lib.rs: pub use hmac::generate)
// ============================================================================

// HMAC.generate() 在 hmac.cj 中定义

// ============================================================================
// 便捷常量 (对应 lib.rs: pub const EVP_MAX_MD_SIZE)
// ============================================================================

/// EVP_MAX_MD_SIZE = 64 (SHA-512 is the longest digest)
/// 对应 Bun: sha.rs ffi::EVP_MAX_MD_SIZE / sha.zig boring.EVP_MAX_MD_SIZE
public const EVP_MAX_MD_SIZE: Int64 = 64

// ============================================================================
// 标签常量 (对应 sha.rs: LABELS / sha.zig: labels)
// ============================================================================

/// 算法标签 (对应 sha.rs: LABELS)
public let LABELS: Array<String> = [
    "SHA1", "SHA512", "SHA384", "SHA256", "SHA512_256", "Blake2", "Blake3"
]
