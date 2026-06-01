// 严格翻译自: src/csrf/csrf.zig
// CSRF Token implementation for Bun
//   使用 HMAC 签名保护跨站请求伪造攻击
package bao_csrf

import bao_core.*
import bao_hash.*
import bao_collections.*
import std.time.*
import std.random.*
import std.math.*

// Helper: String to Array<Byte>
private func stringToBytes(s: String): Array<Byte> {
    var arr = ArrayList<Byte>()
    for (i in 0..s.size) {
        arr.append(s[i])
    }
    return arr.toOwnedSlice()
}

// ============================================================================
// CsrfTokenFormat - 令牌编码格式
// 严格翻译自: csrf.zig - TokenFormat
//   pub const TokenFormat = enum {
//       base64,
//       base64url,
//       hex,
//       pub fn toNodeEncoding(self: TokenFormat) jsc.Node.Encoding { ... }
//   };
// ============================================================================

/// 令牌编码格式 - 对应 Bun TokenFormat
public enum CsrfTokenFormat {
    | Base64
    | Base64Url
    | Hex

    public operator func == (other: CsrfTokenFormat): Bool {
        match (this) {
            case Base64 => match (other) {
                case Base64 => true
                case _ => false
            }
            case Base64Url => match (other) {
                case Base64Url => true
                case _ => false
            }
            case Hex => match (other) {
                case Hex => true
                case _ => false
            }
        }
    }

    public operator func != (other: CsrfTokenFormat): Bool {
        !(this == other)
    }
}

// ============================================================================
// CsrfGenerateOptions - 生成选项
// 严格翻译自: csrf.zig - GenerateOptions
//   pub const GenerateOptions = struct {
//       secret: []const u8,
//       expires_in_ms: u64 = DEFAULT_EXPIRATION_MS,
//       encoding: TokenFormat = .base64url,
//       algorithm: jsc.API.Bun.Crypto.EVP.Algorithm = DEFAULT_ALGORITHM,
//   };
// ============================================================================

/// CSRF 令牌生成选项 - 对应 Bun GenerateOptions
public class CsrfGenerateOptions {
    /// 签名密钥
    public var secret: String
    /// 过期时间 (毫秒) - 默认 24 小时
    public var expiresInMs: Int64
    /// 编码格式 - 默认 base64url
    public var encoding: CsrfTokenFormat
    /// HMAC 算法 - 默认 sha256
    public var algorithm: String

    public init(secret: String) {
        this.secret = secret
        expiresInMs = 24 * 60 * 60 * 1000 // DEFAULT_EXPIRATION_MS
        encoding = CsrfTokenFormat.Base64Url
        algorithm = "sha256"
    }
}

// ============================================================================
// CsrfVerifyOptions - 验证选项
// 严格翻译自: csrf.zig - VerifyOptions
//   pub const VerifyOptions = struct {
//       token: []const u8,
//       secret: []const u8,
//       max_age_ms: u64 = DEFAULT_EXPIRATION_MS,
//       encoding: TokenFormat = .base64url,
//       algorithm: jsc.API.Bun.Crypto.EVP.Algorithm = DEFAULT_ALGORITHM,
//   };
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
//   pub const Error = error{
//       InvalidToken,
//       ExpiredToken,
//       TokenCreationFailed,
//       DecodingFailed,
//   };
// ============================================================================

/// CSRF 错误 - 对应 Bun CSRF.Error
public enum CsrfError {
    | InvalidToken
    | ExpiredToken
    | TokenCreationFailed
    | DecodingFailed

    public operator func == (other: CsrfError): Bool {
        match (this) {
            case InvalidToken => match (other) {
                case InvalidToken => true
                case _ => false
            }
            case ExpiredToken => match (other) {
                case ExpiredToken => true
                case _ => false
            }
            case TokenCreationFailed => match (other) {
                case TokenCreationFailed => true
                case _ => false
            }
            case DecodingFailed => match (other) {
                case DecodingFailed => true
                case _ => false
            }
        }
    }

    public operator func != (other: CsrfError): Bool {
        !(this == other)
    }
}

// ============================================================================
// CSRF - CSRF 令牌工具
// 严格翻译自: csrf.zig - CSRF (pub const CSRF = @This();)
//
//   pub fn generate(options: GenerateOptions, out_buffer: *[512]u8) ![]u8
//   pub fn verify(options: VerifyOptions) bool
//
// 令牌二进制结构:
//   [0..8]   timestamp (u64, big-endian)
//   [8..24]  nonce (16 bytes, random)
//   [24..32] expires_in_ms (u64, big-endian)
//   [32..]   HMAC signature (depends on algorithm, SHA-256 = 32 bytes)
// ============================================================================

/// CSRF 令牌工具 - 对应 Bun CSRF
/// 提供跨站请求伪造保护
public class CSRF {
    /// 默认过期时间 (24小时)
    /// Zig: pub const DEFAULT_EXPIRATION_MS: u64 = 24 * 60 * 60 * 1000;
    public static let DEFAULT_EXPIRATION_MS: Int64 = 24 * 60 * 60 * 1000

    /// 默认算法
    /// Zig: pub const DEFAULT_ALGORITHM: ... = .sha256;
    public static let DEFAULT_ALGORITHM: String = "sha256"

    /// 生成 CSRF 令牌
    /// 严格翻译自: csrf.zig - CSRF.generate()
    ///
    /// Zig:
    ///   pub fn generate(options: GenerateOptions, out_buffer: *[512]u8) ![]u8 {
    ///       var nonce: [16]u8 = .{0} ** 16;
    ///       bun.csprng(&nonce);
    ///       const timestamp = std.time.milliTimestamp();
    ///       const timestamp_u64: u64 = @bitCast(@as(i64, timestamp));
    ///       std.mem.writeInt(u64, &timestamp_bytes, timestamp_u64, .big);
    ///       std.mem.writeInt(u64, &expires_in_bytes, options.expires_in_ms, .big);
    ///       @memcpy(payload_buf[0..8], &timestamp_bytes);
    ///       @memcpy(payload_buf[8..24], &nonce);
    ///       @memcpy(payload_buf[24..32], &expires_in_bytes);
    ///       const digest = hmac.generate(options.secret, &payload_buf, options.algorithm, &digest_buf)
    ///           orelse return Error.TokenCreationFailed;
    ///       @memcpy(out_buffer[0..8], &timestamp_bytes);
    ///       @memcpy(out_buffer[8..24], &nonce);
    ///       @memcpy(out_buffer[24..32], &expires_in_bytes);
    ///       @memcpy(out_buffer[32 .. 32 + digest.len], digest);
    ///       return out_buffer[0 .. 32 + digest.len];
    ///   }
    public static func generate(options: CsrfGenerateOptions): ?String {
        // 生成 16 字节随机 nonce
        // Zig: var nonce: [16]u8 = .{0} ** 16; bun.csprng(&nonce);
        let rng = Random()
        var nonce = ArrayList<Byte>()
        for (_ in 0..16) {
            nonce.append(UInt8(rng.nextBits(UInt64(8))))
        }

        // 获取时间戳 (毫秒)
        // Zig: const timestamp = std.time.milliTimestamp();
        //      const timestamp_u64: u64 = @bitCast(@as(i64, timestamp));
        let timestamp = DateTime.now().toUnixTimeStamp().toMilliseconds()
        let timestampBytes = int64ToBytesBigEndian(timestamp)

        // 过期时间字节 (big-endian)
        // Zig: std.mem.writeInt(u64, &expires_in_bytes, options.expires_in_ms, .big);
        let expiresInBytes = int64ToBytesBigEndian(options.expiresInMs)

        // 构造签名载荷: timestamp(8) + nonce(16) + expires_in(8)
        // Zig: var payload_buf: [32]u8 = ...;
        //      @memcpy(payload_buf[0..8], &timestamp_bytes);
        //      @memcpy(payload_buf[8..24], &nonce);
        //      @memcpy(payload_buf[24..32], &expires_in_bytes);
        let payload = ArrayList<Byte>()
        for (b in timestampBytes) { payload.append(b) }
        for (b in nonce) { payload.append(b) }
        for (b in expiresInBytes) { payload.append(b) }

        // HMAC 签名
        // Zig: const digest = hmac.generate(options.secret, &payload_buf, options.algorithm, &digest_buf)
        //          orelse return Error.TokenCreationFailed;
        let signature = hmacCompute(options.algorithm, stringToBytes(options.secret),
                                      payload.toOwnedSlice())
        if (signature.size == 0) {
            return None
        }

        // 组装最终令牌: timestamp(8) + nonce(16) + expires_in(8) + signature
        // Zig: @memcpy(out_buffer[0..8], &timestamp_bytes);
        //      @memcpy(out_buffer[8..24], &nonce);
        //      @memcpy(out_buffer[24..32], &expires_in_bytes);
        //      @memcpy(out_buffer[32 .. 32 + digest.len], digest);
        //      return out_buffer[0 .. 32 + digest.len];
        let tokenBytes = ArrayList<Byte>()
        for (b in timestampBytes) { tokenBytes.append(b) }
        for (b in nonce) { tokenBytes.append(b) }
        for (b in expiresInBytes) { tokenBytes.append(b) }
        for (b in signature) { tokenBytes.append(b) }

        // 按指定编码格式编码输出
        match (options.encoding) {
            case CsrfTokenFormat.Base64 => base64Encode(tokenBytes.toOwnedSlice())
            case CsrfTokenFormat.Base64Url => base64UrlEncode(tokenBytes.toOwnedSlice())
            case CsrfTokenFormat.Hex => hexEncode(tokenBytes.toOwnedSlice())
        }
    }

    /// 验证 CSRF 令牌
    /// 严格翻译自: csrf.zig - CSRF.verify()
    ///
    /// Zig:
    ///   pub fn verify(options: VerifyOptions) bool {
    ///       // Decode token based on encoding format
    ///       const decoded: []const u8 = brk: switch (encoding) {
    ///           .base64url, .base64 => {
    ///               const slice = bun.strings.trim(token, "\r\n\t " ++ ...);
    ///               const outlen = bun.base64.decodeLen(slice);
    ///               const wrote = bun.base64.decode(buf[0..outlen], slice).count;
    ///               break :brk buf[0..wrote];
    ///           },
    ///           .hex => { ... },
    ///       };
    ///       if (decoded.len < 64) return false;
    ///       const timestamp = std.mem.readInt(u64, decoded[0..8], .big);
    ///       const current_time = @as(u64, @bitCast(std.time.milliTimestamp()));
    ///       const expires_in = std.mem.readInt(u64, decoded[24..32], .big);
    ///       // Check expiration
    ///       if (expires_in > 0) { if (current_time > timestamp + expires_in) return false; }
    ///       // Verify HMAC signature
    ///       const payload = decoded[0..32];
    ///       const received_signature = decoded[32..];
    ///       const signature = hmac.generate(options.secret, payload, options.algorithm, ...) orelse return false;
    ///       if (received_signature.len != signature.len) return false;
    ///       return boring.CRYPTO_memcmp(received_signature.ptr, signature.ptr, signature.len) == 0;
    ///   }
    public static func verify(options: CsrfVerifyOptions): Bool {
        // Strip trailing null byte
        // Zig: if (token.len > 0 and token[token.len - 1] == 0) { token = token[0 .. token.len - 1]; }
        var tokenStr = options.token
        if (tokenStr.size > 0 && tokenStr[tokenStr.size - 1] == UInt8(0)) {
            tokenStr = tokenStr[0..tokenStr.size - 1]
        }

        // 解码令牌
        // Zig: const decoded: []const u8 = brk: switch (encoding) { ... }
        var decoded: Array<Byte>
        match (options.encoding) {
            case CsrfTokenFormat.Base64 =>
                decoded = base64Decode(tokenStr)
            case CsrfTokenFormat.Base64Url =>
                decoded = base64UrlDecode(tokenStr)
            case CsrfTokenFormat.Hex =>
                if (tokenStr.size % 2 != 0) { return false }
                decoded = hexDecode(tokenStr)
        }

        // 最小长度: 8 (timestamp) + 16 (nonce) + 8 (expires_in) + 32 (HMAC-SHA256)
        // Zig: if (decoded.len < 64) { return false; }
        if (decoded.size < 64) {
            return false
        }

        // 提取时间戳 (前 8 字节, big-endian)
        // Zig: const timestamp = std.mem.readInt(u64, decoded[0..8], .big);
        let timestamp = bytesToInt64BigEndian(decoded, 0)

        // 获取当前时间
        // Zig: const current_time = @as(u64, @bitCast(std.time.milliTimestamp()));
        let currentTime = DateTime.now().toUnixTimeStamp().toMilliseconds()

        // 提取 expires_in (字节 24-32, big-endian)
        // Zig: const expires_in = std.mem.readInt(u64, decoded[24..32], .big);
        let expiresIn = bytesToInt64BigEndian(decoded, 24)

        // 检查令牌内置过期时间
        // Zig: if (expires_in > 0) {
        //     if (std.math.maxInt(u64) - timestamp < expires_in) return false;
        //     if (current_time > timestamp + expires_in) return false;
        // }
        if (expiresIn > 0) {
            // 溢出保护
            if (Int64.Max - timestamp < expiresIn) {
                return false
            }
            if (currentTime > timestamp + expiresIn) {
                return false
            }
        }

        // 检查 options.max_age_ms
        // Zig: const expiry = options.max_age_ms;
        //     if (expiry > 0) {
        //         if (std.math.maxInt(u64) - timestamp < expiry) return false;
        //         if (current_time > timestamp + expiry) return false;
        //     }
        if (options.maxAgeMs > 0) {
            if (Int64.Max - timestamp < options.maxAgeMs) {
                return false
            }
            if (currentTime > timestamp + options.maxAgeMs) {
                return false
            }
        }

        // 提取载荷和签名
        // Zig: const payload = decoded[0..32];
        //      const received_signature = decoded[32..];
        let payload = decoded[0..32]
        let receivedSignature = decoded[32..]

        // 计算期望签名
        // Zig: const signature = hmac.generate(options.secret, payload, options.algorithm, &expected_signature)
        //          orelse return false;
        let expectedSignature = hmacCompute(options.algorithm,
                                              stringToBytes(options.secret), payload)
        if (expectedSignature.size == 0) {
            return false
        }
        if (expectedSignature.size != receivedSignature.size) {
            return false
        }

        // 常量时间比较 (防止时序攻击)
        // Zig: return boring.CRYPTO_memcmp(received_signature.ptr, signature.ptr, signature.len) == 0;
        constantTimeEqual(receivedSignature, expectedSignature)
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// Int64 转大端字节数组 (8 字节)
    /// Zig: std.mem.writeInt(u64, &bytes, value, .big)
    static func int64ToBytesBigEndian(v: Int64): Array<Byte> {
        let arr = Array<UInt8>(8, repeat: UInt8(0))
        var val = v
        for (i in 0..8) {
            arr[Int64(7) - i] = UInt8(val & 0xFF)
            val = val >> 8
        }
        arr
    }

    /// 从字节数组读取 Int64 (大端, 8 字节)
    /// Zig: std.mem.readInt(u64, bytes[offset..][0..8], .big)
    static func bytesToInt64BigEndian(arr: Array<Byte>, offset: Int64): Int64 {
        var result: Int64 = 0
        for (i in 0..8) {
            result = (result << 8) | Int64(arr[offset + i])
        }
        result
    }

    /// 十六进制编码
    static func hexEncode(bytes: Array<Byte>): String {
        let hex = "0123456789abcdef"
        let sb = StringBuilder()
        for (b in bytes) {
            let v = Int64(b)
            sb.append(Rune(Int32(hex[v >> 4])))
            sb.append(Rune(Int32(hex[v & 0x0F])))
        }
        sb.toString()
    }

    /// 十六进制解码
    /// Zig: const result = bun.strings.decodeHexToBytesTruncate(buf[0..decoded_len], u8, token);
    static func hexDecode(hex: String): Array<Byte> {
        if (hex.size % 2 != 0) { return Array<Byte>() }
        let result = Array<UInt8>(hex.size / 2, repeat: UInt8(0))
        for (i in 0..(hex.size / 2)) {
            let high = hexCharToInt(hex[i * 2])
            let low = hexCharToInt(hex[i * 2 + 1])
            if (high < 0 || low < 0) { return Array<Byte>() }
            result[i] = UInt8(high * 16 + low)
        }
        result
    }

    static func hexCharToInt(ch: UInt8): Int64 {
        let v = Int64(ch)
        if (v >= 0x30 && v <= 0x39) { return v - 0x30 }  // '0'-'9'
        if (v >= 0x61 && v <= 0x66) { return v - 0x61 + 10 } // 'a'-'f'
        if (v >= 0x41 && v <= 0x46) { return v - 0x41 + 10 } // 'A'-'F'
        -1
    }

    /// 常量时间比较 - 防止时序攻击
    /// Zig: boring.CRYPTO_memcmp(a.ptr, b.ptr, a.len) == 0
    static func constantTimeEqual(a: Array<Byte>, b: Array<Byte>): Bool {
        if (a.size != b.size) { return false }
        var result: Int64 = 0
        for (i in 0..a.size) {
            result = result | (Int64(a[i]) ^ Int64(b[i]))
        }
        result == 0
    }

    /// HMAC 分发 - 根据算法名选择 HMAC 实现
    /// Zig: const digest = hmac.generate(options.secret, &payload_buf, options.algorithm, &digest_buf)
    ///          orelse return Error.TokenCreationFailed;
    static func hmacCompute(algorithm: String, key: Array<Byte>, data: Array<Byte>): Array<Byte> {
        match (algorithm) {
            case "sha1" => HmacSha1.hmac(key, data)
            case "sha256" => HmacSha256.hmac(key, data)
            case "sha384" => HmacSha384.hmac(key, data)
            case "sha512" => HmacSha512.hmac(key, data)
            case _ => HmacSha256.hmac(key, data)
        }
    }

    /// 标准 Base64 编码 (带 padding)
    static func base64Encode(bytes: Array<Byte>): String {
        let ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        let sb = StringBuilder()
        var acc: Int64 = 0
        var accLen: Int64 = 0
        for (b in bytes) {
            acc = (acc << 8) + Int64(b)
            accLen += 8
            while (accLen >= 6) {
                accLen -= 6
                sb.append(ALPHABET[(acc >> accLen) & 0x3F])
            }
        }
        if (accLen > 0) {
            sb.append(ALPHABET[(acc << (6 - accLen)) & 0x3F])
        }
        // 添加 padding
        let expectedLen = ((bytes.size + 2) / 3) * 4
        while (sb.size < expectedLen) {
            sb.append('=')
        }
        sb.toString()
    }

    /// Base64 解码 (宽容模式，跳过空白和非法字符)
    /// Zig: bun.base64.decode(dest, slice).count
    static func base64Decode(s: String): Array<Byte> {
        // 先建立查找表
        let ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        var lut = ArrayList<UInt8>()
        for (_ in 0..256) { lut.append(UInt8(0xFF)) }
        for (i in 0..64) {
            let idx = ALPHABET[Int64(i)]
            lut[Int64(idx)] = UInt8(i)
        }
        let lutArr = lut.toOwnedSlice()

        var result = ArrayList<Byte>()
        var buf: Int64 = 0
        var bits: Int64 = 0
        for (i in 0..s.size) {
            let c = s[i]
            if (c == UInt8(0x3D)) { break } // '=' padding
            // 跳过空白
            if (c == UInt8(0x20) || c == UInt8(0x09) || c == UInt8(0x0D) || c == UInt8(0x0A)) {
                continue
            }
            if (Int64(c) >= 256) { continue }
            let idx = lutArr[Int64(c)]
            if (idx == UInt8(0xFF)) { continue }
            buf = (buf << 6) | Int64(idx)
            bits += 6
            if (bits >= 8) {
                bits -= 8
                result.append(UInt8((buf >> bits) & 0xFF))
            }
        }
        result.toOwnedSlice()
    }

    /// Base64 URL-safe 编码 (替换 + 为 -, / 为 _, 去掉 padding)
    /// Zig: pub fn simdutfEncodeUrlSafe(destination, source) usize
    static func base64UrlEncode(bytes: Array<Byte>): String {
        let ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        let sb = StringBuilder()
        var acc: Int64 = 0
        var accLen: Int64 = 0
        for (b in bytes) {
            acc = (acc << 8) + Int64(b)
            accLen += 8
            while (accLen >= 6) {
                accLen -= 6
                sb.append(ALPHABET[(acc >> accLen) & 0x3F])
            }
        }
        if (accLen > 0) {
            sb.append(ALPHABET[(acc << (6 - accLen)) & 0x3F])
        }
        // URL-safe 不添加 padding
        sb.toString()
    }

    /// Base64 URL-safe 解码
    /// Zig: .base64url => { const slice = bun.strings.trim(token, ...); ... }
    static func base64UrlDecode(s: String): Array<Byte> {
        // 先建立 URL-safe 查找表
        let ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        var lut = ArrayList<UInt8>()
        for (_ in 0..256) { lut.append(UInt8(0xFF)) }
        for (i in 0..64) {
            let idx = ALPHABET[Int64(i)]
            lut[Int64(idx)] = UInt8(i)
        }
        // 也接受标准 Base64 字符
        lut[Int64(43)] = UInt8(62)   // '+'
        lut[Int64(47)] = UInt8(63)   // '/'
        let lutArr = lut.toOwnedSlice()

        var result = ArrayList<Byte>()
        var buf: Int64 = 0
        var bits: Int64 = 0
        for (i in 0..s.size) {
            let c = s[i]
            if (c == UInt8(0x3D)) { break }
            if (c == UInt8(0x20) || c == UInt8(0x09) || c == UInt8(0x0D) || c == UInt8(0x0A)) {
                continue
            }
            if (Int64(c) >= 256) { continue }
            let idx = lutArr[Int64(c)]
            if (idx == UInt8(0xFF)) { continue }
            buf = (buf << 6) | Int64(idx)
            bits += 6
            if (bits >= 8) {
                bits -= 8
                result.append(UInt8((buf >> bits) & 0xFF))
            }
        }
        result.toOwnedSlice()
    }
}
