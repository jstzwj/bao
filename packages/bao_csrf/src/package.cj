// bao_csrf - CSRF 令牌生成与验证
// 严格翻译自: bun/src/csrf/csrf.zig (220行)
//   使用 HMAC 签名保护跨站请求伪造攻击
package bao_csrf

import bao_core.*
import bao_hash.*

// ============================================================================
// CsrfTokenFormat - 令牌编码格式
// 严格翻译自: csrf.zig - TokenFormat
//   pub const TokenFormat = enum { base64, base64url, hex };
// ============================================================================

/// 令牌编码格式 - 对应 Bun TokenFormat
public enum CsrfTokenFormat {
    | Base64
    | Base64Url
    | Hex
}

// ============================================================================
// CsrfGenerateOptions - 生成选项
// 严格翻译自: csrf.zig - GenerateOptions
// ============================================================================

/// CSRF 令牌生成选项 - 对应 Bun GenerateOptions
public class CsrfGenerateOptions {
    /// 签名密钥
    public var secret: String
    /// 过期时间 (毫秒)
    public var expiresInMs: Int64
    /// 编码格式
    public var encoding: CsrfTokenFormat
    /// HMAC 算法
    public var algorithm: String

    public init(secret: String) {
        this.secret = secret
        expiresInMs = 24 * 60 * 60 * 1000 // 24小时
        encoding = CsrfTokenFormat.Base64Url
        algorithm = "sha256"
    }
}

// ============================================================================
// CsrfVerifyOptions - 验证选项
// 严格翻译自: csrf.zig - VerifyOptions
// ============================================================================

/// CSRF 令牌验证选项 - 对应 Bun VerifyOptions
public class CsrfVerifyOptions {
    /// 待验证令牌
    public var token: String
    /// 签名密钥
    public var secret: String
    /// 最大存活时间 (毫秒)
    public var maxAgeMs: Int64
    /// 编码格式
    public var encoding: CsrfTokenFormat
    /// HMAC 算法
    public var algorithm: String

    public init(token: String, secret: String) {
        this.token = token
        this.secret = secret
        maxAgeMs = 24 * 60 * 60 * 1000
        encoding = CsrfTokenFormat.Base64Url
        algorithm = "sha256"
    }
}

// ============================================================================
// CsrfError - CSRF 错误类型
// 严格翻译自: csrf.zig - Error
// ============================================================================

/// CSRF 错误 - 对应 Bun CSRF.Error
public enum CsrfError {
    | InvalidToken
    | ExpiredToken
    | TokenCreationFailed
    | DecodingFailed
}

// ============================================================================
// CSRF - CSRF 令牌工具
// 严格翻译自: csrf.zig - CSRF
//   pub const CSRF = @This();
//   pub fn generate(options, out_buffer) ![]u8
//   pub fn verify(options) bool
// ============================================================================

/// CSRF 令牌工具 - 对应 Bun CSRF
/// 提供跨站请求伪造保护
public class CSRF {
    /// 默认过期时间 (24小时)
    public static let DEFAULT_EXPIRATION_MS: Int64 = 24 * 60 * 60 * 1000

    /// 默认算法
    public static let DEFAULT_ALGORITHM: String = "sha256"

    /// 生成 CSRF 令牌
    /// 对应 Bun CSRF.generate()
    /// 令牌结构: timestamp(8) | nonce(16) | expires_in(8) | signature(32)
    public static func generate(options: CsrfGenerateOptions): ?String {
        // 生成 16 字节随机 nonce
        var nonce = ArrayList<Byte>()
        for (_ in 0..16) {
            nonce.append(Byte(randomInt(0, 255)))
        }

        // 获取时间戳
        let timestamp = DateTime.now().toUnixMillis()
        let timestampBytes = int64ToBytes(timestamp)

        // 过期时间字节
        let expiresInBytes = int64ToBytes(options.expiresInMs)

        // 构造签名载荷: timestamp(8) + nonce(16) + expires_in(8)
        let payload = ArrayList<Byte>()
        for (b in timestampBytes) { payload.append(b) }
        for (b in nonce) { payload.append(b) }
        for (b in expiresInBytes) { payload.append(b) }

        // HMAC 签名
        let signature = HMAC.compute(options.algorithm, options.secret.toArray(),
                                      payload.toArray())
        if (signature.size == 0) {
            return None
        }

        // 组装最终令牌
        let tokenBytes = ArrayList<Byte>()
        for (b in timestampBytes) { tokenBytes.append(b) }
        for (b in nonce) { tokenBytes.append(b) }
        for (b in expiresInBytes) { tokenBytes.append(b) }
        for (b in signature) { tokenBytes.append(b) }

        // 编码
        match (options.encoding) {
            case Base64 => Base64.encode(tokenBytes.toArray())
            case Base64Url => Base64.encodeUrl(tokenBytes.toArray())
            case Hex => hexEncode(tokenBytes.toArray())
        }
    }

    /// 验证 CSRF 令牌
    /// 对应 Bun CSRF.verify()
    public static func verify(options: CsrfVerifyOptions): Bool {
        // 解码令牌
        let decoded = match (options.encoding) {
            case Base64 => Base64.decode(options.token)
            case Base64Url => Base64.decodeUrl(options.token)
            case Hex => hexDecode(options.token)
        }

        if (decoded.size < 64) {
            return false // 最小长度: 8+16+8+32
        }

        // 提取时间戳 (前 8 字节)
        let timestamp = bytesToInt64(decoded, 0)

        // 检查过期
        let currentTime = DateTime.now().toUnixMillis()
        let expiresIn = bytesToInt64(decoded, 24)

        if (expiresIn > 0 && currentTime > timestamp + expiresIn) {
            return false
        }
        if (options.maxAgeMs > 0 && currentTime > timestamp + options.maxAgeMs) {
            return false
        }

        // 提取载荷和签名
        let payload = decoded[0..32]
        let receivedSignature = decoded[32..]

        // 计算期望签名
        let expectedSignature = HMAC.compute(options.algorithm,
                                              options.secret.toArray(), payload)
        if (expectedSignature.size != receivedSignature.size) {
            return false
        }

        // 常量时间比较 (防止时序攻击)
        constantTimeEqual(receivedSignature, expectedSignature)
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// Int64 转大端字节
    static func int64ToBytes(v: Int64): Array<Byte> {
        let arr = Array<Byte>(8)
        var val = v
        for (i in 0..8) {
            arr[7 - i] = Byte(val % 256)
            val /= 256
        }
        arr
    }

    /// 从字节数组读取 Int64 (大端)
    static func bytesToInt64(arr: Array<Byte>, offset: Int64): Int64 {
        var result = 0
        for (i in 0..8) {
            result = result * 256 + Int64(arr[offset + i].value)
        }
        result
    }

    /// 十六进制编码
    static func hexEncode(bytes: Array<Byte>): String {
        let sb = StringBuilder()
        for (b in bytes) {
            let v = b.value
            let hex = "0123456789abcdef"
            sb.append(hex[v / 16])
            sb.append(hex[v % 16])
        }
        sb.toString()
    }

    /// 十六进制解码
    static func hexDecode(hex: String): Array<Byte> {
        if (hex.size % 2 != 0) { return Array<Byte>() }
        let result = Array<Byte>(hex.size / 2)
        for (i in 0..(hex.size / 2)) {
            let high = hexCharToInt(hex[i * 2])
            let low = hexCharToInt(hex[i * 2 + 1])
            if (high < 0 || low < 0) { return Array<Byte>() }
            result[i] = Byte(high * 16 + low)
        }
        result
    }

    static func hexCharToInt(c: Char): Int64 {
        match (c.value) {
            case v where v >= '0'.value && v <= '9'.value => Int64(v) - Int64('0'.value)
            case v where v >= 'a'.value && v <= 'f'.value => Int64(v) - Int64('a'.value) + 10
            case v where v >= 'A'.value && v <= 'F'.value => Int64(v) - Int64('A'.value) + 10
            case _ => -1
        }
    }

    /// 常量时间比较 - 防止时序攻击
    static func constantTimeEqual(a: Array<Byte>, b: Array<Byte>): Bool {
        if (a.size != b.size) { return false }
        var result = 0
        for (i in 0..a.size) {
            result = result | (Int64(a[i].value) ~ Int64(b[i].value))
        }
        result == 0
    }
}
