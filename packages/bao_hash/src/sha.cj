// bao_hash - SHA 哈希算法
// 严格翻译自: src/sha_hmac/ (SHA-1/256/512 实现)
//   Bun 使用 sha_hmac crate 提供 SHA 系列哈希
//   用于 HTTP 认证, S3 签名, 完整性校验
package bao_hash

// ============================================================================
// SHA-256
// 严格翻译自: FIPS 180-4 SHA-256 算法
//   Bun 通过 sha_hmac crate 调用
//   此处提供完整的纯仓颉实现
// ============================================================================

/// SHA-256 哈希 - 对应 Bun sha_hmac::Sha256
public class Sha256 {
    /// 哈希值字节数
    public static let HASH_SIZE: Int64 = 32
    /// 块大小
    public static let BLOCK_SIZE: Int64 = 64

    // SHA-256 初始哈希值
    private static let H0: Array<UInt32> = [
        UInt32(0x6a09e667), UInt32(0xbb67ae85), UInt32(0x3c6ef372), UInt32(0xa54ff53a),
        UInt32(0x510e527f), UInt32(0x9b05688c), UInt32(0x1f83d9ab), UInt32(0x5be0cd19)
    ]

    // SHA-256 轮常量
    private static let K: Array<UInt32> = [
        UInt32(0x428a2f98), UInt32(0x71374491), UInt32(0xb5c0fbcf), UInt32(0xe9b5dba5),
        UInt32(0x3956c25b), UInt32(0x59f111f1), UInt32(0x923f82a4), UInt32(0xab1c5ed5),
        UInt32(0xd807aa98), UInt32(0x12835b01), UInt32(0x243185be), UInt32(0x550c7dc3),
        UInt32(0x72be5d74), UInt32(0x80deb1fe), UInt32(0x9bdc06a7), UInt32(0xc19bf174),
        UInt32(0xe49b69c1), UInt32(0xefbe4786), UInt32(0x0fc19dc6), UInt32(0x240ca1cc),
        UInt32(0x2de92c6f), UInt32(0x4a7484aa), UInt32(0x5cb0a9dc), UInt32(0x76f988da),
        UInt32(0x983e5152), UInt32(0xa831c66d), UInt32(0xb00327c8), UInt32(0xbf597fc7),
        UInt32(0xc6e00bf3), UInt32(0xd5a79147), UInt32(0x06ca6351), UInt32(0x14292967),
        UInt32(0x27b70a85), UInt32(0x2e1b2138), UInt32(0x4d2c6dfc), UInt32(0x53380d13),
        UInt32(0x650a7354), UInt32(0x766a0abb), UInt32(0x81c2c92e), UInt32(0x92722c85),
        UInt32(0xa2bfe8a1), UInt32(0xa81a664b), UInt32(0xc24b8b70), UInt32(0xc76c51a3),
        UInt32(0xd192e819), UInt32(0xd6990624), UInt32(0xf40e3585), UInt32(0x106aa070),
        UInt32(0x19a4c116), UInt32(0x1e376c08), UInt32(0x2748774c), UInt32(0x34b0bcb5),
        UInt32(0x391c0cb3), UInt32(0x4ed8aa4a), UInt32(0x5b9cca4f), UInt32(0x682e6ff3),
        UInt32(0x748f82ee), UInt32(0x78a5636f), UInt32(0x84c87814), UInt32(0x8cc70208),
        UInt32(0x90befffa), UInt32(0xa4506ceb), UInt32(0xbef9a3f7), UInt32(0xc67178f2)
    ]

    /// 计算 SHA-256 哈希
    public static func hash(data: Array<UInt8>): Array<UInt8> {
        // 填充
        var padded = padMessage(data)
        // 初始化哈希值
        var h0 = H0[0]; var h1 = H0[1]; var h2 = H0[2]; var h3 = H0[3]
        var h4 = H0[4]; var h5 = H0[5]; var h6 = H0[6]; var h7 = H0[7]
        // 处理每个512位块
        var i: Int64 = 0
        while (i < padded.size) {
            // 准备消息调度表
            var w = Array<UInt32>(64, item: UInt32(0))
            for (j in 0..16) {
                let off = i + j * 4
                w[j] = (UInt32(padded[off]) << 24) | (UInt32(padded[off + 1]) << 16) |
                        (UInt32(padded[off + 2]) << 8) | UInt32(padded[off + 3])
            }
            for (j in 16..64) {
                let s0 = rotr(w[j - 15], 7) ^ rotr(w[j - 15], 18) ^ (w[j - 15] >> 3)
                let s1 = rotr(w[j - 2], 17) ^ rotr(w[j - 2], 19) ^ (w[j - 2] >> 10)
                w[j] = w[j - 16] + s0 + w[j - 7] + s1
            }
            // 初始化工作变量
            var a = h0; var b = h1; var c = h2; var d = h3
            var e = h4; var f = h5; var g = h6; var h = h7
            // 压缩
            for (j in 0..64) {
                let S1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)
                let ch = (e & f) ^ (~e & g)
                let temp1 = h + S1 + ch + K[j] + w[j]
                let S0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = S0 + maj
                h = g; g = f; f = e; e = d + temp1
                d = c; c = b; b = a; a = temp1 + temp2
            }
            // 更新哈希值
            h0 = h0 + a; h1 = h1 + b; h2 = h2 + c; h3 = h3 + d
            h4 = h4 + e; h5 = h5 + f; h6 = h6 + g; h7 = h7 + h
            i += 64
        }
        // 输出
        var result = Array<UInt8>()
        for (h in [h0, h1, h2, h3, h4, h5, h6, h7]) {
            result.append(UInt8((h >> 24) & UInt32(0xFF)))
            result.append(UInt8((h >> 16) & UInt32(0xFF)))
            result.append(UInt8((h >> 8) & UInt32(0xFF)))
            result.append(UInt8(h & UInt32(0xFF)))
        }
        return result
    }

    /// 哈希字符串
    public static func hash(s: String): Array<UInt8> {
        var bytes = Array<UInt8>()
        for (c in s) {
            bytes.append(UInt8(c.value))
        }
        return hash(bytes)
    }

    // 循环右移
    private static func rotr(x: UInt32, n: Int64): UInt32 {
        return (x >> n) | (x << (32 - n))
    }

    // 填充消息
    private static func padMessage(data: Array<UInt8>): Array<UInt8> {
        let bitLen = Int64(data.size) * 8
        var padded = Array<UInt8>()
        for (b in data) { padded.append(b) }
        // 追加 0x80
        padded.append(UInt8(0x80))
        // 填充0直到长度 ≡ 56 mod 64
        while ((padded.size % 64) != 56) {
            padded.append(UInt8(0))
        }
        // 追加原始长度 (大端, 64位)
        for (i in 0..7) {
            padded.append(UInt8((bitLen >> (56 - i * 8)) & 0xFF))
        }
        return padded
    }
}

// ============================================================================
// SHA-1
// 严格翻译自: FIPS 180-4 SHA-1 算法
// ============================================================================

/// SHA-1 哈希 - 对应 Bun sha_hmac::Sha1
public class Sha1 {
    public static let HASH_SIZE: Int64 = 20

    private static let H0: Array<UInt32> = [
        UInt32(0x67452301), UInt32(0xEFCDAB89), UInt32(0x98BADCFE),
        UInt32(0x10325476), UInt32(0xC3D2E1F0)
    ]

    /// 计算 SHA-1 哈希
    public static func hash(data: Array<UInt8>): Array<UInt8> {
        var padded = padMessage(data)
        var h0 = H0[0]; var h1 = H0[1]; var h2 = H0[2]; var h3 = H0[3]; var h4 = H0[4]
        var i: Int64 = 0
        while (i < padded.size) {
            var w = Array<UInt32>(80, item: UInt32(0))
            for (j in 0..16) {
                let off = i + j * 4
                w[j] = (UInt32(padded[off]) << 24) | (UInt32(padded[off + 1]) << 16) |
                        (UInt32(padded[off + 2]) << 8) | UInt32(padded[off + 3])
            }
            for (j in 16..80) {
                let val = w[j - 3] ^ w[j - 8] ^ w[j - 14] ^ w[j - 16]
                w[j] = rotl(val, 1)
            }
            var a = h0; var b = h1; var c = h2; var d = h3; var e = h4
            for (j in 0..80) {
                var f: UInt32 = UInt32(0)
                var k: UInt32 = UInt32(0)
                if (j < 20) {
                    f = (b & c) | (~b & d); k = UInt32(0x5A827999)
                } else if (j < 40) {
                    f = b ^ c ^ d; k = UInt32(0x6ED9EBA1)
                } else if (j < 60) {
                    f = (b & c) | (b & d) | (c & d); k = UInt32(0x8F1BBCDC)
                } else {
                    f = b ^ c ^ d; k = UInt32(0xCA62C1D6)
                }
                let temp = rotl(a, 5) + f + e + k + w[j]
                e = d; d = c; c = rotl(b, 30); b = a; a = temp
            }
            h0 = h0 + a; h1 = h1 + b; h2 = h2 + c; h3 = h3 + d; h4 = h4 + e
            i += 64
        }
        var result = Array<UInt8>()
        for (h in [h0, h1, h2, h3, h4]) {
            result.append(UInt8((h >> 24) & UInt32(0xFF)))
            result.append(UInt8((h >> 16) & UInt32(0xFF)))
            result.append(UInt8((h >> 8) & UInt32(0xFF)))
            result.append(UInt8(h & UInt32(0xFF)))
        }
        return result
    }

    public static func hash(s: String): Array<UInt8> {
        var bytes = Array<UInt8>()
        for (c in s) { bytes.append(UInt8(c.value)) }
        return hash(bytes)
    }

    private static func rotl(x: UInt32, n: Int64): UInt32 {
        return (x << n) | (x >> (32 - n))
    }

    private static func padMessage(data: Array<UInt8>): Array<UInt8> {
        let bitLen = Int64(data.size) * 8
        var padded = Array<UInt8>()
        for (b in data) { padded.append(b) }
        padded.append(UInt8(0x80))
        while ((padded.size % 64) != 56) { padded.append(UInt8(0)) }
        for (i in 0..7) { padded.append(UInt8((bitLen >> (56 - i * 8)) & 0xFF)) }
        return padded
    }
}

// ============================================================================
// HMAC - 基于 SHA-256
// ============================================================================

/// HMAC-SHA256 - 对应 Bun sha_hmac::Hmac<Sha256>
public class HmacSha256 {
    /// 计算 HMAC-SHA256
    public static func hmac(key: Array<UInt8>, message: Array<UInt8>): Array<UInt8> {
        // HMAC(K, m) = H((K' XOR opad) || H((K' XOR ipad) || m))
        var k = key
        // 如果 key > 64字节，先哈希
        if (k.size > 64) {
            k = Sha256.hash(k)
        }
        // 填充到64字节
        while (k.size < 64) { k.append(UInt8(0)) }
        // 内部: K XOR ipad || message
        var innerData = Array<UInt8>()
        for (i in 0..64) { innerData.append(k[i] ^ UInt8(0x36)) }
        for (b in message) { innerData.append(b) }
        let innerHash = Sha256.hash(innerData)
        // 外部: K XOR opad || innerHash
        var outerData = Array<UInt8>()
        for (i in 0..64) { outerData.append(k[i] ^ UInt8(0x5C)) }
        for (b in innerHash) { outerData.append(b) }
        return Sha256.hash(outerData)
    }

    public static func hmac(key: String, message: String): Array<UInt8> {
        var keyBytes = Array<UInt8>()
        for (c in key) { keyBytes.append(UInt8(c.value)) }
        var msgBytes = Array<UInt8>()
        for (c in message) { msgBytes.append(UInt8(c.value)) }
        return hmac(keyBytes, msgBytes)
    }
}
