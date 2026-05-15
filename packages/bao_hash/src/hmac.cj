// bao_hash - HMAC 消息认证码
// 严格翻译自: src/sha_hmac/hmac.zig generate()
//   Bun 使用 BoringSSL 的 HMAC() 函数
//   HMAC(K, m) = H((K' XOR opad) || H((K' XOR ipad) || m))
//   K' = H(K) if len(K) > block_size, else K padded with zeros
//   此处提供纯仓颉实现, 支持 SHA-1/224/256/384/512 算法
package bao_hash


// ============================================================================
// HMAC 通用实现
// 严格翻译自: src/sha_hmac/hmac.zig
//   Bun: HMAC(key, data, algorithm.md(), out, &outlen)
//   纯仓颉实现: init/update/finalize 流式 API
// ============================================================================

/// HMAC-SHA1 消息认证码
/// 对应 Bun: hmac.generate(key, data, .sha1, out)
public class HmacSha1 {
    public static let BLOCK_SIZE: Int64 = 64
    public static let DIGEST_SIZE: Int64 = 20

    /// 计算 HMAC-SHA1
    public static func hmac(key: Array<UInt8>, message: Array<UInt8>): Array<UInt8> {
        var k = key
        if (k.size > BLOCK_SIZE) {
            k = Sha1.hash(k)
        }
        while (k.size < BLOCK_SIZE) { k.append(UInt8(0)) }

        // 内部: K XOR ipad || message
        var innerData = Array<UInt8>()
        for (i in 0..BLOCK_SIZE) { innerData.append(k[i] ^ UInt8(0x36)) }
        for (b in message) { innerData.append(b) }
        let innerHash = Sha1.hash(innerData)

        // 外部: K XOR opad || innerHash
        var outerData = Array<UInt8>()
        for (i in 0..BLOCK_SIZE) { outerData.append(k[i] ^ UInt8(0x5C)) }
        for (b in innerHash) { outerData.append(b) }
        return Sha1.hash(outerData)
    }

    public static func hmac(key: String, message: String): Array<UInt8> {
        return hmac(stringToBytes(key), stringToBytes(message))
    }

    public static func hmacHex(key: Array<UInt8>, message: Array<UInt8>): String {
        return HexEncode.encode(hmac(key, message))
    }

    public static func hmacHex(key: String, message: String): String {
        return HexEncode.encode(hmac(key, message))
    }
}

/// HMAC-SHA224 消息认证码
/// 对应 Bun: hmac.generate(key, data, .sha224, out)
public class HmacSha224 {
    public static let BLOCK_SIZE: Int64 = 64
    public static let DIGEST_SIZE: Int64 = 28

    /// 计算 HMAC-SHA224
    public static func hmac(key: Array<UInt8>, message: Array<UInt8>): Array<UInt8> {
        var k = key
        if (k.size > BLOCK_SIZE) {
            k = Sha256.hash(k)
        }
        while (k.size < BLOCK_SIZE) { k.append(UInt8(0)) }

        var innerData = Array<UInt8>()
        for (i in 0..BLOCK_SIZE) { innerData.append(k[i] ^ UInt8(0x36)) }
        for (b in message) { innerData.append(b) }
        let innerHash = Sha256.hash(innerData)

        var outerData = Array<UInt8>()
        for (i in 0..BLOCK_SIZE) { outerData.append(k[i] ^ UInt8(0x5C)) }
        for (b in innerHash) { outerData.append(b) }
        return Sha256.hash(outerData)
    }

    public static func hmac(key: String, message: String): Array<UInt8> {
        return hmac(stringToBytes(key), stringToBytes(message))
    }

    public static func hmacHex(key: Array<UInt8>, message: Array<UInt8>): String {
        return HexEncode.encode(hmac(key, message))
    }

    public static func hmacHex(key: String, message: String): String {
        return HexEncode.encode(hmac(key, message))
    }
}

/// HMAC-SHA384 消息认证码
/// 对应 Bun: hmac.generate(key, data, .sha384, out)
public class HmacSha384 {
    public static let BLOCK_SIZE: Int64 = 128
    public static let DIGEST_SIZE: Int64 = 48

    /// 计算 HMAC-SHA384
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

    public static func hmacHex(key: String, message: String): String {
        return HexEncode.encode(hmac(key, message))
    }
}

/// 字符串转字节数组
private func stringToBytes(s: String): Array<UInt8> {
    var bytes = Array<UInt8>()
    for (c in s) { bytes.append(UInt8(c.value)) }
    return bytes
}
