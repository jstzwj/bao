// bao_hash - SHA/HMAC 完整实现
// 严格翻译自: src/sha_hmac/
//   Bun 的 SHA 实现:
//   - sha.zig: SHA-1/224/256/384/512/512_256 使用 BoringSSL EVP
//   - hmac.zig: HMAC-SHA256/512 使用 BoringSSL HMAC()
//   - 纯仓颉实现: init/update/finalize 流式 API
//   - HMAC: hmacSha256/hmacSha512
//   - 摘要转 hex/base64
package bao_hash

import bao_core.*

// ============================================================================
// Hex/Base64 编码工具
// ============================================================================

/// Hex 编码工具
public class HexEncode {
    private static let HEX_CHARS: Array<UInt8> = [
        UInt8('0'), UInt8('1'), UInt8('2'), UInt8('3'), UInt8('4'), UInt8('5'), UInt8('6'), UInt8('7'),
        UInt8('8'), UInt8('9'), UInt8('a'), UInt8('b'), UInt8('c'), UInt8('d'), UInt8('e'), UInt8('f')
    ]

    private static let HEX_CHARS_UPPER: Array<UInt8> = [
        UInt8('0'), UInt8('1'), UInt8('2'), UInt8('3'), UInt8('4'), UInt8('5'), UInt8('6'), UInt8('7'),
        UInt8('8'), UInt8('9'), UInt8('A'), UInt8('B'), UInt8('C'), UInt8('D'), UInt8('E'), UInt8('F')
    ]

    /// 字节数组转小写 hex 字符串
    public static func encode(bytes: Array<UInt8>): String {
        let sb = StringBuilder()
        for (b in bytes) {
            let high = (Int64(b) >> 4) & 0x0F
            let low = Int64(b) & 0x0F
            sb.append(Char(Int32(HEX_CHARS[high])))
            sb.append(Char(Int32(HEX_CHARS[low])))
        }
        return sb.toString()
    }

    /// 字节数组转大写 hex 字符串
    public static func encodeUpper(bytes: Array<UInt8>): String {
        let sb = StringBuilder()
        for (b in bytes) {
            let high = (Int64(b) >> 4) & 0x0F
            let low = Int64(b) & 0x0F
            sb.append(Char(Int32(HEX_CHARS_UPPER[high])))
            sb.append(Char(Int32(HEX_CHARS_UPPER[low])))
        }
        return sb.toString()
    }

    /// Hex 字符串解码为字节数组
    public static func decode(hex: String): Array<UInt8> {
        var bytes = Array<UInt8>()
        var i = 0
        while (i + 1 < hex.size) {
            let high = hexCharValue(hex[Int64(i)])
            let low = hexCharValue(hex[Int64(i + 1)])
            bytes.append(UInt8((high << 4) | low))
            i += 2
        }
        return bytes
    }

    private static func hexCharValue(ch: Char): Int64 {
        let v = Int64(ch.value)
        if (v >= Int64('0') && v <= Int64('9')) { return v - Int64('0') }
        if (v >= Int64('a') && v <= Int64('f')) { return v - Int64('a') + 10 }
        if (v >= Int64('A') && v <= Int64('F')) { return v - Int64('A') + 10 }
        return 0
    }
}

/// Base64 编码工具
public class Base64Encode {
    private static let TABLE: Array<UInt8> = [
        UInt8('A'), UInt8('B'), UInt8('C'), UInt8('D'), UInt8('E'), UInt8('F'), UInt8('G'), UInt8('H'),
        UInt8('I'), UInt8('J'), UInt8('K'), UInt8('L'), UInt8('M'), UInt8('N'), UInt8('O'), UInt8('P'),
        UInt8('Q'), UInt8('R'), UInt8('S'), UInt8('T'), UInt8('U'), UInt8('V'), UInt8('W'), UInt8('X'),
        UInt8('Y'), UInt8('Z'), UInt8('a'), UInt8('b'), UInt8('c'), UInt8('d'), UInt8('e'), UInt8('f'),
        UInt8('g'), UInt8('h'), UInt8('i'), UInt8('j'), UInt8('k'), UInt8('l'), UInt8('m'), UInt8('n'),
        UInt8('o'), UInt8('p'), UInt8('q'), UInt8('r'), UInt8('s'), UInt8('t'), UInt8('u'), UInt8('v'),
        UInt8('w'), UInt8('x'), UInt8('y'), UInt8('z'), UInt8('0'), UInt8('1'), UInt8('2'), UInt8('3'),
        UInt8('4'), UInt8('5'), UInt8('6'), UInt8('7'), UInt8('8'), UInt8('9'), UInt8('+'), UInt8('/')
    ]

    /// 编码为 Base64 字符串
    public static func encode(bytes: Array<UInt8>): String {
        let sb = StringBuilder()
        var i = 0
        while (i < bytes.size) {
            let b0 = Int64(bytes[i])
            let b1 = if (i + 1 < bytes.size) { Int64(bytes[i + 1]) } else { 0 }
            let b2 = if (i + 2 < bytes.size) { Int64(bytes[i + 2]) } else { 0 }

            sb.append(Char(Int32(TABLE[(b0 >> 2) & 0x3F])))
            sb.append(Char(Int32(TABLE[((b0 << 4) | (b1 >> 4)) & 0x3F])))

            if (i + 1 < bytes.size) {
                sb.append(Char(Int32(TABLE[((b1 << 2) | (b2 >> 6)) & 0x3F])))
            }
            if (i + 2 < bytes.size) {
                sb.append(Char(Int32(TABLE[b2 & 0x3F])))
            }
            i += 3
        }

        // 补位
        let remainder = bytes.size % 3
        if (remainder == 1) { sb.append("=") }
        if (remainder == 1) { sb.append("=") }
        if (remainder == 2) { sb.append("=") }

        return sb.toString()
    }

    /// 编码计算所需缓冲区长度
    public static func encodeLen(inputLen: Int64): Int64 {
        return 4 * ((inputLen + 2) / 3)
    }
}

// ============================================================================
// 消息填充
// 对应 Bun: BoringSSL 内部的消息填充逻辑
// FIPS 180-4 规定: 追加 0x80, 填充 0 至 mod 56/112, 追加 64/128 位长度
// ============================================================================

/// SHA 填充工具
private class ShaPadding {
    /// 填充 512 位块的消息 (SHA-1/256)
    public static func pad512(data: Array<UInt8>): Array<UInt8> {
        let bitLen = Int64(data.size) * 8
        var padded = Array<UInt8>()
        for (b in data) { padded.append(b) }
        padded.append(UInt8(0x80))
        while ((padded.size % 64) != 56) { padded.append(UInt8(0)) }
        // 追加 64 位大端长度
        for (i in 0..7) {
            padded.append(UInt8((bitLen >> (56 - i * 8)) & 0xFF))
        }
        return padded
    }

    /// 填充 1024 位块的消息 (SHA-384/512)
    public static func pad1024(data: Array<UInt8>): Array<UInt8> {
        let bitLen = Int64(data.size) * 8
        var padded = Array<UInt8>()
        for (b in data) { padded.append(b) }
        padded.append(UInt8(0x80))
        while ((padded.size % 128) != 112) { padded.append(UInt8(0)) }
        // 追加 128 位大端长度
        for (i in 0..15) {
            padded.append(UInt8((bitLen >> (120 - i * 8)) & 0xFF))
        }
        return padded
    }
}

// ============================================================================
// SHA-1
// 严格翻译自: FIPS 180-4 SHA-1
// Bun: src/sha_hmac/sha.zig SHA1 -> EVP.SHA1 -> EVP_sha1
// 摘要长度 20 字节, 块大小 64 字节
// ============================================================================

/// SHA-1 哈希 (流式 API)
/// 对应 Bun: NewHasher(20, SHA_CTX, SHA1, SHA1_Init, SHA1_Update, SHA1_Final)
public class Sha1 {
    /// 摘要长度 (字节)
    public static let DIGEST_SIZE: Int64 = 20
    /// 块大小 (字节)
    public static let BLOCK_SIZE: Int64 = 64

    // 初始哈希值 H0
    private static let H0: Array<UInt32> = [
        UInt32(0x67452301), UInt32(0xEFCDAB89), UInt32(0x98BADCFE),
        UInt32(0x10325476), UInt32(0xC3D2E1F0)
    ]

    // 内部状态
    private var h0: UInt32
    private var h1: UInt32
    private var h2: UInt32
    private var h3: UInt32
    private var h4: UInt32
    private var buffer: Array<UInt8>
    private var bufferSize: Int64
    private var totalBytes: Int64

    public init() {
        h0 = H0[0]; h1 = H0[1]; h2 = H0[2]; h3 = H0[3]; h4 = H0[4]
        buffer = Array<UInt8>(64, item: UInt8(0))
        bufferSize = 0
        totalBytes = 0
    }

    /// 一次性哈希
    public static func hash(data: Array<UInt8>): Array<UInt8> {
        let hasher = Sha1()
        hasher.update(data)
        return hasher.finalize()
    }

    /// 哈希字符串
    public static func hash(s: String): Array<UInt8> {
        return hash(stringToBytes(s))
    }

    /// 哈希并返回 hex
    public static func hashHex(data: Array<UInt8>): String {
        return HexEncode.encode(hash(data))
    }

    /// 流式更新
    public func update(data: Array<UInt8>): Unit {
        var offset = 0
        totalBytes += data.size

        // 先填满 buffer
        if (bufferSize > 0) {
            let needed = 64 - bufferSize
            let toCopy = if (data.size < needed) { data.size } else { needed }
            for (i in 0..toCopy) {
                buffer[bufferSize + i] = data[i]
            }
            bufferSize += toCopy
            offset += toCopy
            if (bufferSize == 64) {
                processBlock(buffer)
                bufferSize = 0
            }
        }

        // 处理完整的 64 字节块
        while (offset + 64 <= data.size) {
            var block = Array<UInt8>(64, item: UInt8(0))
            for (i in 0..64) { block[i] = data[offset + i] }
            processBlock(block)
            offset += 64
        }

        // 保存剩余
        if (offset < data.size) {
            for (i in offset..data.size) {
                buffer[bufferSize] = data[i]
                bufferSize += 1
            }
        }
    }

    /// 完成哈希, 返回 20 字节摘要
    public func finalize(): Array<UInt8> {
        // 填充
        let bitLen = (totalBytes * 8)
        buffer[bufferSize] = UInt8(0x80)
        bufferSize += 1

        if (bufferSize > 56) {
            while (bufferSize < 64) {
                buffer[bufferSize] = UInt8(0)
                bufferSize += 1
            }
            processBlock(buffer)
            bufferSize = 0
        }

        while (bufferSize < 56) {
            buffer[bufferSize] = UInt8(0)
            bufferSize += 1
        }

        // 追加 64 位长度
        for (i in 0..7) {
            buffer[56 + i] = UInt8((bitLen >> (56 - i * 8)) & 0xFF)
        }
        processBlock(buffer)

        // 输出
        var result = Array<UInt8>()
        for (h in [h0, h1, h2, h3, h4]) {
            result.append(UInt8((h >> 24) & UInt32(0xFF)))
            result.append(UInt8((h >> 16) & UInt32(0xFF)))
            result.append(UInt8((h >> 8) & UInt32(0xFF)))
            result.append(UInt8(h & UInt32(0xFF)))
        }
        return result
    }

    /// 处理一个 512 位 (64 字节) 块
    private func processBlock(block: Array<UInt8>): Unit {
        // 展开消息调度
        var w = Array<UInt32>(80, item: UInt32(0))
        for (j in 0..16) {
            let off = j * 4
            w[j] = (UInt32(block[off]) << 24) | (UInt32(block[off + 1]) << 16) |
                    (UInt32(block[off + 2]) << 8) | UInt32(block[off + 3])
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
    }

    private static func rotl(x: UInt32, n: Int64): UInt32 {
        return (x << n) | (x >> (32 - n))
    }
}

// ============================================================================
// SHA-256
// 严格翻译自: FIPS 180-4 SHA-256
// Bun: src/sha_hmac/sha.zig SHA256 -> EVP.SHA256 -> EVP_sha256
// 摘要长度 32 字节, 块大小 64 字节
// ============================================================================

/// SHA-256 哈希 (流式 API)
/// 对应 Bun: NewHasher(32, SHA256_CTX, SHA256, SHA256_Init, SHA256_Update, SHA256_Final)
public class Sha256 {
    public static let DIGEST_SIZE: Int64 = 32
    public static let BLOCK_SIZE: Int64 = 64

    // 初始哈希值
    private static let H0: Array<UInt32> = [
        UInt32(0x6a09e667), UInt32(0xbb67ae85), UInt32(0x3c6ef372), UInt32(0xa54ff53a),
        UInt32(0x510e527f), UInt32(0x9b05688c), UInt32(0x1f83d9ab), UInt32(0x5be0cd19)
    ]

    // 64 个轮常量 K
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

    private var h0: UInt32; private var h1: UInt32
    private var h2: UInt32; private var h3: UInt32
    private var h4: UInt32; private var h5: UInt32
    private var h6: UInt32; private var h7: UInt32
    private var buffer: Array<UInt8>
    private var bufferSize: Int64
    private var totalBytes: Int64

    public init() {
        h0 = H0[0]; h1 = H0[1]; h2 = H0[2]; h3 = H0[3]
        h4 = H0[4]; h5 = H0[5]; h6 = H0[6]; h7 = H0[7]
        buffer = Array<UInt8>(64, item: UInt8(0))
        bufferSize = 0
        totalBytes = 0
    }

    public static func hash(data: Array<UInt8>): Array<UInt8> {
        let hasher = Sha256()
        hasher.update(data)
        return hasher.finalize()
    }

    public static func hash(s: String): Array<UInt8> {
        return hash(stringToBytes(s))
    }

    public static func hashHex(data: Array<UInt8>): String {
        return HexEncode.encode(hash(data))
    }

    public func update(data: Array<UInt8>): Unit {
        var offset = 0
        totalBytes += data.size

        if (bufferSize > 0) {
            let needed = 64 - bufferSize
            let toCopy = if (data.size < needed) { data.size } else { needed }
            for (i in 0..toCopy) { buffer[bufferSize + i] = data[i] }
            bufferSize += toCopy
            offset += toCopy
            if (bufferSize == 64) { processBlock(buffer); bufferSize = 0 }
        }

        while (offset + 64 <= data.size) {
            var block = Array<UInt8>(64, item: UInt8(0))
            for (i in 0..64) { block[i] = data[offset + i] }
            processBlock(block)
            offset += 64
        }

        if (offset < data.size) {
            for (i in offset..data.size) { buffer[bufferSize] = data[i]; bufferSize += 1 }
        }
    }

    public func finalize(): Array<UInt8> {
        let bitLen = totalBytes * 8
        buffer[bufferSize] = UInt8(0x80); bufferSize += 1
        if (bufferSize > 56) {
            while (bufferSize < 64) { buffer[bufferSize] = UInt8(0); bufferSize += 1 }
            processBlock(buffer); bufferSize = 0
        }
        while (bufferSize < 56) { buffer[bufferSize] = UInt8(0); bufferSize += 1 }
        for (i in 0..7) { buffer[56 + i] = UInt8((bitLen >> (56 - i * 8)) & 0xFF) }
        processBlock(buffer)

        var result = Array<UInt8>()
        for (h in [h0, h1, h2, h3, h4, h5, h6, h7]) {
            result.append(UInt8((h >> 24) & UInt32(0xFF)))
            result.append(UInt8((h >> 16) & UInt32(0xFF)))
            result.append(UInt8((h >> 8) & UInt32(0xFF)))
            result.append(UInt8(h & UInt32(0xFF)))
        }
        return result
    }

    private func processBlock(block: Array<UInt8>): Unit {
        var w = Array<UInt32>(64, item: UInt32(0))
        for (j in 0..16) {
            let off = j * 4
            w[j] = (UInt32(block[off]) << 24) | (UInt32(block[off + 1]) << 16) |
                    (UInt32(block[off + 2]) << 8) | UInt32(block[off + 3])
        }
        for (j in 16..64) {
            let s0 = rotr(w[j - 15], 7) ^ rotr(w[j - 15], 18) ^ (w[j - 15] >> 3)
            let s1 = rotr(w[j - 2], 17) ^ rotr(w[j - 2], 19) ^ (w[j - 2] >> 10)
            w[j] = w[j - 16] + s0 + w[j - 7] + s1
        }

        var a = h0; var b = h1; var c = h2; var d = h3
        var e = h4; var f = h5; var g = h6; var h = h7

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

        h0 = h0 + a; h1 = h1 + b; h2 = h2 + c; h3 = h3 + d
        h4 = h4 + e; h5 = h5 + f; h6 = h6 + g; h7 = h7 + h
    }

    private static func rotr(x: UInt32, n: Int64): UInt32 {
        return (x >> n) | (x << (32 - n))
    }
}

// ============================================================================
// SHA-512
// 严格翻译自: FIPS 180-4 SHA-512
// Bun: src/sha_hmac/sha.zig SHA512 -> EVP.SHA512 -> EVP_sha512
// 摘要长度 64 字节, 块大小 128 字节
// 使用 UInt64 运算
// ============================================================================

/// SHA-512 哈希 (流式 API)
/// 对应 Bun: NewHasher(64, SHA512_CTX, SHA512, SHA512_Init, SHA512_Update, SHA512_Final)
public class Sha512 {
    public static let DIGEST_SIZE: Int64 = 64
    public static let BLOCK_SIZE: Int64 = 128

    // 初始哈希值 (前8个素数的立方根的小数部分前64位)
    private static let H0: Array<UInt64> = [
        UInt64(0x6a09e667f3bcc908), UInt64(0xbb67ae8584caa73b),
        UInt64(0x3c6ef372fe94f82b), UInt64(0xa54ff53a5f1d36f1),
        UInt64(0x510e527fade682d1), UInt64(0x9b05688c2b3e6c1f),
        UInt64(0x1f83d9abfb41bd6b), UInt64(0x5be0cd19137e2179)
    ]

    // 80 个轮常量 (前80个素数的立方根的小数部分前64位)
    private static let K: Array<UInt64> = [
        UInt64(0x428a2f98d728ae22), UInt64(0x7137449123ef65cd), UInt64(0xb5c0fbcfec4d3b2f), UInt64(0xe9b5dba58189dbbc),
        UInt64(0x3956c25bf348b538), UInt64(0x59f111f1b605d019), UInt64(0x923f82a4af194f9b), UInt64(0xab1c5ed5da6d8118),
        UInt64(0xd807aa98a3030242), UInt64(0x12835b0145706fbe), UInt64(0x243185be4ee4b28c), UInt64(0x550c7dc3d5ffb4e2),
        UInt64(0x72be5d74f27b896f), UInt64(0x80deb1fe3b1696b1), UInt64(0x9bdc06a725c71235), UInt64(0xc19bf174cf692694),
        UInt64(0xe49b69c19ef14ad2), UInt64(0xefbe4786384f25e3), UInt64(0x0fc19dc68b8cd5b5), UInt64(0x240ca1cc77ac9c65),
        UInt64(0x2de92c6f592b0275), UInt64(0x4a7484aa6ea6e483), UInt64(0x5cb0a9dcbd41fbd4), UInt64(0x76f988da831153b5),
        UInt64(0x983e5152ee66dfab), UInt64(0xa831c66d2db43210), UInt64(0xb00327c898fb213f), UInt64(0xbf597fc7beef0ee4),
        UInt64(0xc6e00bf33da88fc2), UInt64(0xd5a79147930aa725), UInt64(0x06ca6351e003826f), UInt64(0x142929670a0e6e70),
        UInt64(0x27b70a8546d22ffc), UInt64(0x2e1b21385c26c926), UInt64(0x4d2c6dfc5ac42aed), UInt64(0x53380d139d95b3df),
        UInt64(0x650a73548baf63de), UInt64(0x766a0abb3c77b2a8), UInt64(0x81c2c92e47edaee6), UInt64(0x92722c851482353b),
        UInt64(0xa2bfe8a14cf10364), UInt64(0xa81a664bbc423001), UInt64(0xc24b8b70d0f89791), UInt64(0xc76c51a30654be30),
        UInt64(0xd192e819d6ef5218), UInt64(0xd69906245565a910), UInt64(0xf40e35855771202a), UInt64(0x106aa07032bbd1b8),
        UInt64(0x19a4c116b8d2d0c8), UInt64(0x1e376c085141ab53), UInt64(0x2748774cdf8eeb99), UInt64(0x34b0bcb5e19b48a8),
        UInt64(0x391c0cb3c5c95a63), UInt64(0x4ed8aa4ae3418acb), UInt64(0x5b9cca4f7763e373), UInt64(0x682e6ff3d6b2b8a3),
        UInt64(0x748f82ee5defb2fc), UInt64(0x78a5636f43172f60), UInt64(0x84c87814a1f0ab72), UInt64(0x8cc702081a6439ec),
        UInt64(0x90befffa23631e28), UInt64(0xa4506cebde82bde9), UInt64(0xbef9a3f7b2c67915), UInt64(0xc67178f2e372532b),
        UInt64(0xca273eceea26619c), UInt64(0xd186b8c721c0c207), UInt64(0xeada7dd6cde0eb1e), UInt64(0xf57d4f7fee6ed178),
        UInt64(0x06f067aa72176fba), UInt64(0x0a637dc5a2c898a6), UInt64(0x113f9804bef90dae), UInt64(0x1b710b35131c471b),
        UInt64(0x28db77f523047d84), UInt64(0x32caab7b40c72493), UInt64(0x3c9ebe0a15c9bebc), UInt64(0x431d67c49c100d4c),
        UInt64(0x4cc5d4becb3e42b6), UInt64(0x597f299cfc657e2a), UInt64(0x5fcb6fab3ad6faec), UInt64(0x6c44198c4a475817)
    ]

    private var h0: UInt64; private var h1: UInt64
    private var h2: UInt64; private var h3: UInt64
    private var h4: UInt64; private var h5: UInt64
    private var h6: UInt64; private var h7: UInt64
    private var buffer: Array<UInt8>
    private var bufferSize: Int64
    private var totalBytes: Int64

    public init() {
        h0 = H0[0]; h1 = H0[1]; h2 = H0[2]; h3 = H0[3]
        h4 = H0[4]; h5 = H0[5]; h6 = H0[6]; h7 = H0[7]
        buffer = Array<UInt8>(128, item: UInt8(0))
        bufferSize = 0
        totalBytes = 0
    }

    public static func hash(data: Array<UInt8>): Array<UInt8> {
        let hasher = Sha512()
        hasher.update(data)
        return hasher.finalize()
    }

    public static func hash(s: String): Array<UInt8> {
        return hash(stringToBytes(s))
    }

    public static func hashHex(data: Array<UInt8>): String {
        return HexEncode.encode(hash(data))
    }

    public func update(data: Array<UInt8>): Unit {
        var offset = 0
        totalBytes += data.size

        if (bufferSize > 0) {
            let needed = 128 - bufferSize
            let toCopy = if (data.size < needed) { data.size } else { needed }
            for (i in 0..toCopy) { buffer[bufferSize + i] = data[i] }
            bufferSize += toCopy
            offset += toCopy
            if (bufferSize == 128) { processBlock(buffer); bufferSize = 0 }
        }

        while (offset + 128 <= data.size) {
            var block = Array<UInt8>(128, item: UInt8(0))
            for (i in 0..128) { block[i] = data[offset + i] }
            processBlock(block)
            offset += 128
        }

        if (offset < data.size) {
            for (i in offset..data.size) { buffer[bufferSize] = data[i]; bufferSize += 1 }
        }
    }

    public func finalize(): Array<UInt8> {
        let bitLen = totalBytes * 8
        buffer[bufferSize] = UInt8(0x80); bufferSize += 1
        if (bufferSize > 112) {
            while (bufferSize < 128) { buffer[bufferSize] = UInt8(0); bufferSize += 1 }
            processBlock(buffer); bufferSize = 0
        }
        while (bufferSize < 112) { buffer[bufferSize] = UInt8(0); bufferSize += 1 }
        // 128 位长度 (前 64 位为 0, 因为消息长度远小于 2^64 位)
        for (i in 0..7) { buffer[112 + i] = UInt8(0) }
        for (i in 0..7) { buffer[120 + i] = UInt8((bitLen >> (56 - i * 8)) & 0xFF) }
        processBlock(buffer)

        var result = Array<UInt8>()
        for (h in [h0, h1, h2, h3, h4, h5, h6, h7]) {
            result.append(UInt8((h >> 56) & UInt64(0xFF)))
            result.append(UInt8((h >> 48) & UInt64(0xFF)))
            result.append(UInt8((h >> 40) & UInt64(0xFF)))
            result.append(UInt8((h >> 32) & UInt64(0xFF)))
            result.append(UInt8((h >> 24) & UInt64(0xFF)))
            result.append(UInt8((h >> 16) & UInt64(0xFF)))
            result.append(UInt8((h >> 8) & UInt64(0xFF)))
            result.append(UInt8(h & UInt64(0xFF)))
        }
        return result
    }

    private func processBlock(block: Array<UInt8>): Unit {
        var w = Array<UInt64>(80, item: UInt64(0))
        for (j in 0..16) {
            let off = j * 8
            w[j] = (UInt64(block[off]) << 56) | (UInt64(block[off + 1]) << 48) |
                    (UInt64(block[off + 2]) << 40) | (UInt64(block[off + 3]) << 32) |
                    (UInt64(block[off + 4]) << 24) | (UInt64(block[off + 5]) << 16) |
                    (UInt64(block[off + 6]) << 8) | UInt64(block[off + 7])
        }
        for (j in 16..80) {
            let s0 = rotr64(w[j - 15], 1) ^ rotr64(w[j - 15], 8) ^ (w[j - 15] >> 7)
            let s1 = rotr64(w[j - 2], 19) ^ rotr64(w[j - 2], 61) ^ (w[j - 2] >> 6)
            w[j] = w[j - 16] + s0 + w[j - 7] + s1
        }

        var a = h0; var b = h1; var c = h2; var d = h3
        var e = h4; var f = h5; var g = h6; var h = h7

        for (j in 0..80) {
            let S1 = rotr64(e, 14) ^ rotr64(e, 18) ^ rotr64(e, 41)
            let ch = (e & f) ^ (~e & g)
            let temp1 = h + S1 + ch + K[j] + w[j]
            let S0 = rotr64(a, 28) ^ rotr64(a, 34) ^ rotr64(a, 39)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = S0 + maj
            h = g; g = f; f = e; e = d + temp1
            d = c; c = b; b = a; a = temp1 + temp2
        }

        h0 = h0 + a; h1 = h1 + b; h2 = h2 + c; h3 = h3 + d
        h4 = h4 + e; h5 = h5 + f; h6 = h6 + g; h7 = h7 + h
    }

    private static func rotr64(x: UInt64, n: Int64): UInt64 {
        return (x >> n) | (x << (64 - n))
    }
}

// ============================================================================
// HMAC
// 严格翻译自: src/sha_hmac/hmac.zig generate()
//   Bun: HMAC(key, data, algorithm.md(), out, &outlen)
//   HMAC(K, m) = H((K' XOR opad) || H((K' XOR ipad) || m))
//   K' = H(K) if len(K) > block_size, else K padded with zeros
// ============================================================================

/// HMAC-SHA256
/// 对应 Bun: hmac.generate(key, data, .sha256, out)
public class HmacSha256 {
    public static let BLOCK_SIZE: Int64 = 64
    public static let DIGEST_SIZE: Int64 = 32

    /// 计算 HMAC-SHA256
    public static func hmac(key: Array<UInt8>, message: Array<UInt8>): Array<UInt8> {
        var k = key
        // 如果 key > block size, 先哈希
        if (k.size > BLOCK_SIZE) {
            k = Sha256.hash(k)
        }
        // 填充到 block size
        while (k.size < BLOCK_SIZE) { k.append(UInt8(0)) }

        // 内部: K XOR ipad || message
        var innerData = Array<UInt8>()
        for (i in 0..BLOCK_SIZE) { innerData.append(k[i] ^ UInt8(0x36)) }
        for (b in message) { innerData.append(b) }
        let innerHash = Sha256.hash(innerData)

        // 外部: K XOR opad || innerHash
        var outerData = Array<UInt8>()
        for (i in 0..BLOCK_SIZE) { outerData.append(k[i] ^ UInt8(0x5C)) }
        for (b in innerHash) { outerData.append(b) }
        return Sha256.hash(outerData)
    }

    public static func hmac(key: String, message: String): Array<UInt8> {
        return hmac(stringToBytes(key), stringToBytes(message))
    }

    /// HMAC-SHA256 并返回 hex
    public static func hmacHex(key: Array<UInt8>, message: Array<UInt8>): String {
        return HexEncode.encode(hmac(key, message))
    }

    public static func hmacHex(key: String, message: String): String {
        return HexEncode.encode(hmac(key, message))
    }
}

/// HMAC-SHA512
/// 对应 Bun: hmac.generate(key, data, .sha512, out)
public class HmacSha512 {
    public static let BLOCK_SIZE: Int64 = 128
    public static let DIGEST_SIZE: Int64 = 64

    public static func hmac(key: Array<UInt8>, message: Array<UInt8>): Array<UInt8> {
        var k = key
        if (k.size > BLOCK_SIZE) {
            k = Sha512.hash(k)
        }
        while (k.size < BLOCK_SIZE) { k.append(UInt8(0)) }

        var innerData = Array<UInt8>()
        for (i in 0..BLOCK_SIZE) { innerData.append(k[i] ^ UInt8(0x36)) }
        for (b in message) { innerData.append(b) }
        let innerHash = Sha512.hash(innerData)

        var outerData = Array<UInt8>()
        for (i in 0..BLOCK_SIZE) { outerData.append(k[i] ^ UInt8(0x5C)) }
        for (b in innerHash) { outerData.append(b) }
        return Sha512.hash(outerData)
    }

    public static func hmac(key: String, message: String): Array<UInt8> {
        return hmac(stringToBytes(key), stringToBytes(message))
    }

    public static func hmacHex(key: Array<UInt8>, message: Array<UInt8>): String {
        return HexEncode.encode(hmac(key, message))
    }
}

// ============================================================================
// 工具函数
// ============================================================================

/// 字符串转字节数组
private func stringToBytes(s: String): Array<UInt8> {
    var bytes = Array<UInt8>()
    for (c in s) { bytes.append(UInt8(c.value)) }
    return bytes
}
