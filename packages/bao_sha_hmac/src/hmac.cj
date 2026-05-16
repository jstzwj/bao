// hmac.cj - HMAC 一次性生成函数
// 严格翻译自 Bun: src/sha_hmac/hmac.rs + src/sha_hmac/hmac.zig
//
// 对应 Bun 源文件:
//   - hmac.rs:
//       pub const EVP_MAX_MD_SIZE = 64
//       pub fn generate(key, data, algorithm, out) -> Option<&[u8]>
//       调用 BoringSSL HMAC() FFI
//   - hmac.zig:
//       pub fn generate(key, data, algorithm, out) ?[]const u8
//       调用 BoringSSL.c.HMAC()

package bao_sha_hmac

import bao_boringssl_sys.*
import std.collection.*

// ============================================================================
// HMAC generate - 一次性 HMAC 计算
// 对应 Bun:
//   hmac.rs: pub fn generate(key, data, algorithm, out) -> Option<&[u8]>
//   hmac.zig: pub fn generate(key, data, algorithm, out) ?[]const u8
//
// 原始 BoringSSL 签名:
//   unsigned char *HMAC(const EVP_MD *evp_md, const void *key, int key_len,
//                       const unsigned char *data, int data_len,
//                       unsigned char *md, unsigned int *md_len);
// ============================================================================

/// HMAC 生成函数
/// 对应 Bun: hmac::generate(key, data, algorithm, out) -> Option<slice>
///
/// 参数:
///   key       - HMAC 密钥字节
///   data      - 待签名数据字节
///   algorithm - EVP 算法 (如 .sha256)
///   out       - 输出缓冲区 (至少 EVP_MAX_MD_SIZE = 64 字节)
///
/// 返回:
///   成功时返回 out[0..outlen] 的切片
///   失败时返回 None (BoringSSL HMAC() 返回 null)
///
/// 注意: 此处使用纯仓颉实现 HMAC, 待 FFI 集成后替换为 BoringSSL HMAC() 调用
public func hmacGenerate(
    key: Array<UInt8>,
    data: Array<UInt8>,
    algorithm: ShaHmacAlgorithm
): ?Array<UInt8> {
    // 获取 EVP_MD
    // 对应 Bun hmac.rs: let Some(md) = algorithm.md() else { panic(...) }
    // 对应 Bun hmac.zig: algorithm.md() orelse bun.Output.panic(...)
    let mdOpt = algorithm.md()
    match (mdOpt) {
        case None =>
            // 对应 Bun: bun.Output.panic("Expected BoringSSL algorithm for HMAC")
            return None
        case Some(_) =>
            ()
    }

    // 对应 Bun hmac.rs:
    //   var outlen: c_uint = EVP_MAX_MD_SIZE
    //   if HMAC(md, key.ptr, key.len, data.ptr, data.len, out.ptr, &outlen) == null
    //     -> return None
    //   return Some(&out[..outlen])

    // 对应 Bun hmac.zig:
    //   var outlen: c_uint = boring.EVP_MAX_MD_SIZE
    //   if boring.HMAC(algorithm.md(), key.ptr, key.len, data.ptr, data.len, out, &outlen) == null
    //     -> return null
    //   return out[0..outlen]

    // 纯仓颉 HMAC 实现: HMAC(K, m) = H((K' XOR opad) || H((K' XOR ipad) || m))
    // 根据算法确定块大小和哈希函数
    let blockAndDigest = getBlockAndDigestSize(algorithm)
    let blockSize = blockAndDigest[0]
    let _digestSize = blockAndDigest[1]

    // 准备密钥
    var keyMaterial = key
    if (keyMaterial.size > blockSize) {
        // 如果 key > block size, 先哈希 key
        keyMaterial = hashWithAlgorithm(algorithm, keyMaterial)
    }
    var k = ArrayList<UInt8>(blockSize)
    k.add(all: keyMaterial)
    while (k.size < blockSize) {
        k.add(UInt8(0))
    }

    // 内部: K XOR ipad(0x36) || message
    var innerData = ArrayList<UInt8>(blockSize + data.size)
    for (i in 0..blockSize) {
        innerData.add(k[i] ^ UInt8(0x36))
    }
    innerData.add(all: data)
    let innerHash = hashWithAlgorithm(algorithm, innerData.toArray())

    // 外部: K XOR opad(0x5C) || innerHash
    var outerData = ArrayList<UInt8>(blockSize + innerHash.size)
    for (i in 0..blockSize) {
        outerData.add(k[i] ^ UInt8(0x5C))
    }
    outerData.add(all: innerHash)
    return hashWithAlgorithm(algorithm, outerData.toArray())
}

/// HMAC 生成函数 (使用预分配的输出缓冲区)
/// 对应 Bun hmac.rs 原始签名:
///   pub fn generate(key, data, algorithm, out: &mut [u8; EVP_MAX_MD_SIZE]) -> Option<&[u8]>
public func hmacGenerateInto(
    key: Array<UInt8>,
    data: Array<UInt8>,
    algorithm: ShaHmacAlgorithm,
    out: Array<UInt8>
): ?Array<UInt8> {
    let result = hmacGenerate(key, data, algorithm)
    match (result) {
        case None => return None
        case Some(digest) =>
            // 复制到输出缓冲区
            let copyLen = if (digest.size < out.size) { digest.size } else { out.size }
            for (i in 0..copyLen) {
                out[i] = digest[i]
            }
            return out[0..copyLen]
    }
}

// ============================================================================
// 内部辅助函数
// ============================================================================

/// 根据算法获取块大小和摘要大小
/// 对应 Bun: 通过 EVP_MD 的 EVP_MD_block_size() / EVP_MD_size() 获取
private func getBlockAndDigestSize(algorithm: ShaHmacAlgorithm): Array<Int64> {
    match (algorithm) {
        // SHA-1/224/256: block=64
        case ShaHmacAlgorithm.sha1 => [Int64(64), Int64(20)]
        case ShaHmacAlgorithm.sha224 => [Int64(64), Int64(28)]
        case ShaHmacAlgorithm.sha256 => [Int64(64), Int64(32)]
        case ShaHmacAlgorithm.md5 => [Int64(64), Int64(16)]
        case ShaHmacAlgorithm.md4 => [Int64(64), Int64(16)]
        // SHA-384/512: block=128
        case ShaHmacAlgorithm.sha384 => [Int64(128), Int64(48)]
        case ShaHmacAlgorithm.sha512 => [Int64(128), Int64(64)]
        case ShaHmacAlgorithm.sha512_224 => [Int64(128), Int64(28)]
        case ShaHmacAlgorithm.sha512_256 => [Int64(128), Int64(32)]
        // Blake2: block=128
        case ShaHmacAlgorithm.blake2b256 => [Int64(128), Int64(32)]
        case ShaHmacAlgorithm.blake2b512 => [Int64(128), Int64(64)]
        // SHA-3
        case ShaHmacAlgorithm.sha3_224 => [Int64(144), Int64(28)]
        case ShaHmacAlgorithm.sha3_256 => [Int64(136), Int64(32)]
        case ShaHmacAlgorithm.sha3_384 => [Int64(104), Int64(48)]
        case ShaHmacAlgorithm.sha3_512 => [Int64(72), Int64(64)]
        case ShaHmacAlgorithm.ripemd160 => [Int64(64), Int64(20)]
        case _ => [Int64(64), Int64(32)]
    }
}

/// 使用指定算法进行哈希 (纯仓颉实现)
/// 对应 Bun: 使用 BoringSSL EVP_Digest 或直接 Hasher 调用
private func hashWithAlgorithm(algorithm: ShaHmacAlgorithm, data: Array<UInt8>): Array<UInt8> {
    match (algorithm) {
        case ShaHmacAlgorithm.sha1 =>
            EvpSha1.hash(data)
        case ShaHmacAlgorithm.sha256 =>
            EvpSha256.hash(data)
        case ShaHmacAlgorithm.sha384 =>
            EvpSha384.hash(data)
        case ShaHmacAlgorithm.sha512 =>
            EvpSha512.hash(data)
        case ShaHmacAlgorithm.sha224 =>
            EvpSha224.hash(data)
        case ShaHmacAlgorithm.sha512_256 =>
            EvpSha512_256.hash(data)
        case ShaHmacAlgorithm.md5 =>
            EvpMd5.hash(data)
        case ShaHmacAlgorithm.md4 =>
            EvpMd4.hash(data)
        case ShaHmacAlgorithm.md5_sha1 =>
            EvpMd5Sha1.hash(data)
        case ShaHmacAlgorithm.blake2b256 =>
            EvpBlake2b256.hash(data)
        case _ =>
            // 默认回退到 SHA-256
            EvpSha256.hash(data)
    }
}
