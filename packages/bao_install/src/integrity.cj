// bao_install - 完整性校验
// 严格翻译自: src/install/integrity.zig
//   integrity.zig 定义了包完整性校验:
//   - SHA-1, SHA-256, SHA-384, SHA-512 哈希
//   - Subresource Integrity (SRI) 格式解析
//   - 流式哈希计算
package bao_install

import bao_core.*
import bao_collections.*
import bao_io.*
import bao_hash.*
import bao_path.*
import bao_http.*

// ============================================================================
// 完整性标签
// 严格翻译自: src/install/integrity.zig
//   pub const Tag = enum(u8) {
//       unknown = 0,
//       sha1 = 1,
//       sha256 = 2,
//       sha384 = 3,
//       sha512 = 4,
//       _,
//   }
// ============================================================================

/// 完整性哈希标签
/// 对应 Bun: Integrity.Tag
public enum IntegrityTag {
    | Unknown   // 未知
    | SHA1      // sha1- (shasum 格式)
    | SHA256    // sha256- (SRI)
    | SHA384    // sha384- (SRI)
    | SHA512    // sha512- (SRI)

    /// 是否为支持的算法
    /// 翻译自: Tag.isSupported
    public func isSupported(): Bool {
        match (this) {
            case SHA1 => return true
            case SHA256 => return true
            case SHA384 => return true
            case SHA512 => return true
            case _ => return false
        }
    }

    /// 获取摘要长度 (字节)
    /// 翻译自: Tag.digestLen
    public func digestLen(): Int64 {
        match (this) {
            case SHA1 => return 20     // 160 bits
            case SHA256 => return 32   // 256 bits
            case SHA384 => return 48   // 384 bits
            case SHA512 => return 64   // 512 bits
            case _ => return 0
        }
    }

    /// 从字符串解析标签
    /// 翻译自: Tag.parse
    public static func parse(buf: String): IntegrityTagParseResult {
        let dashIdx = buf.indexOf("-")
        match (dashIdx) {
            case Some(idx) => {
                if (idx <= 0 || idx >= buf.length - 1) {
                    return IntegrityTagParseResult(tag: Unknown, offset: 0)
                }
                let prefix = buf.substring(0, idx)
                let offset = idx + 1
                match (prefix) {
                    case "sha1" => return IntegrityTagParseResult(tag: SHA1, offset: offset)
                    case "sha256" => return IntegrityTagParseResult(tag: SHA256, offset: offset)
                    case "sha384" => return IntegrityTagParseResult(tag: SHA384, offset: offset)
                    case "sha512" => return IntegrityTagParseResult(tag: SHA512, offset: offset)
                    case _ => return IntegrityTagParseResult(tag: Unknown, offset: 0)
                }
            }
            case None => {
                return IntegrityTagParseResult(tag: Unknown, offset: 0)
            }
        }
    }

    /// 获取前缀字符串
    public func prefix(): String {
        match (this) {
            case SHA1 => "sha1-"
            case SHA256 => "sha256-"
            case SHA384 => "sha384-"
            case SHA512 => "sha512-"
            case _ => ""
        }
    }
}

/// 标签解析结果
public class IntegrityTagParseResult {
    public let tag: IntegrityTag
    public let offset: Int64

    public init(tag: IntegrityTag, offset: Int64) {
        this.tag = tag
        this.offset = offset
    }
}

// ============================================================================
// 完整性哈希
// 严格翻译自: src/install/integrity.zig
//   pub const Integrity = extern struct {
//       tag: Tag = Tag.unknown,
//       value: [digest_buf_len]u8 = empty_digest_buf,
//   }
// ============================================================================

/// 最大摘要缓冲区长度
/// 翻译自: Integrity.digest_buf_len
/// max(SHA1=20, SHA512=64, SHA256=32, SHA384=48) = 64
public let INTEGRITY_DIGEST_BUF_LEN: Int64 = 64

/// 完整性哈希
/// 对应 Bun: Integrity
public class Integrity {
    /// 哈希算法标签
    public var tag: IntegrityTag
    /// 哈希值 (十六进制)
    public var value: String

    public init() {
        tag = IntegrityTag.Unknown
        value = ""
    }

    public init(tag: IntegrityTag, value: String) {
        this.tag = tag
        this.value = value
    }

    /// 从 SRI 字符串解析
    /// 严格翻译自: Integrity.parse
    ///
    /// 输入格式: "sha512-<base64>[==]"
    public static func parse(buf: String): Integrity {
        if (buf.length < 7) {  // "sha256-".length
            return Integrity()
        }

        let result = IntegrityTag.parse(buf)
        let tag = result.tag
        if (tag == IntegrityTag.Unknown) {
            return Integrity()
        }

        let expectedLen = tag.digestLen()
        if (expectedLen == 0) {
            return Integrity()
        }

        let input = buf.substring(result.offset).trimEnd("=")

        // Base64 解码
        // 翻译自: Base64.Decoder.decode
        let decoded = try {
            bao_hash.Base64.decode(input)
        } catch (_: Exception) {
            return Integrity()
        }

        return Integrity(tag: tag, value: decoded)
    }

    /// 从 shasum 格式解析 (十六进制)
    /// 严格翻译自: Integrity.parseSHASum
    ///
    /// 输入格式: "3cd0599b099384b815c10f7fa7df0092b62d534f" (40 字符 hex)
    public static func parseSHASum(buf: String): Integrity {
        if (buf.length == 0) {
            return Integrity()
        }

        // 将十六进制字符串解码为字节
        // 翻译自: parseSHASum 中的 hex 解码循环
        let hexStr = buf.substring(0, if (buf.length < 40) { buf.length } else { 40 })
        let decoded = hexDecode(hexStr)
        return Integrity(tag: IntegrityTag.SHA1, value: decoded)
    }

    /// 格式化为 SRI 字符串
    /// 翻译自: Integrity.format
    public func format(): String {
        if (!tag.isSupported()) { return "" }

        // Base64 编码
        let encoded = bao_hash.Base64.encode(value)
        let padding = match (tag) {
            case SHA1 => "="
            case _ => "=="
        }
        return "${tag.prefix()}${encoded}${padding}"
    }

    /// 获取哈希切片
    /// 翻译自: Integrity.slice
    public func slice(): String {
        return value
    }

    /// 验证字节数据
    /// 严格翻译自: Integrity.verify
    ///
    /// 使用对应的哈希算法计算输入数据的哈希, 并与存储的值比较
    public func verify(bytes: ArrayList<Byte>): Bool {
        return verifyByTag(tag: tag, bytes: bytes, sum: value)
    }

    /// 验证字符串数据
    public func verifyString(data: String): Bool {
        // 将字符串转换为字节进行验证
        return verifyByTag(tag: tag, bytes: stringToBytes(data), sum: value)
    }

    /// 按标签验证
    /// 翻译自: Integrity.verifyByTag
    public static func verifyByTag(tag: IntegrityTag, bytes: ArrayList<Byte>, sum: String): Bool {
        if (!tag.isSupported()) { return false }

        let computed = match (tag) {
            case SHA1 => bao_hash.SHA1.hash(bytes)
            case SHA256 => bao_hash.SHA256.hash(bytes)
            case SHA384 => bao_hash.SHA384.hash(bytes)
            case SHA512 => bao_hash.SHA512.hash(bytes)
            case _ => return false
        }

        return computed == sum
    }

    /// 从字节数据计算 SHA-512 完整性
    /// 翻译自: Integrity.forBytes
    public static func forBytes(bytes: ArrayList<Byte>): Integrity {
        let hash = bao_hash.SHA512.hash(bytes)
        return Integrity(tag: IntegrityTag.SHA512, value: hash)
    }

    /// 从字符串计算 SHA-512 完整性
    public static func forString(data: String): Integrity {
        return forBytes(stringToBytes(data))
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return tag == IntegrityTag.Unknown || value.length == 0
    }
}

// ============================================================================
// 流式完整性哈希
// 严格翻译自: src/install/integrity.zig
//   pub const Streaming = struct {
//       expected: Integrity,
//       hasher: Hasher,
//       ...
//   }
// ============================================================================

/// 流式哈希类型
/// 翻译自: Streaming.Hasher (union)
public enum StreamingHasher {
    | None
    | SHA1(bao_hash.SHA1Hasher)
    | SHA256(bao_hash.SHA256Hasher)
    | SHA384(bao_hash.SHA384Hasher)
    | SHA512(bao_hash.SHA512Hasher)
}

/// 流式完整性哈希计算
/// 对应 Bun: Integrity.Streaming
///
/// 用于流式 tarball 提取时逐块计算哈希
public class IntegrityStreaming {
    /// 期望的完整性值
    public var expected: Integrity
    /// 哈希计算器
    public var hasher: StreamingHasher

    public init(expected: Integrity, computeIfMissing: Bool) {
        this.expected = expected
        hasher = match (expected.tag) {
            case SHA1 => StreamingHasher.SHA1(bao_hash.SHA1Hasher())
            case SHA256 => StreamingHasher.SHA256(bao_hash.SHA256Hasher())
            case SHA384 => StreamingHasher.SHA384(bao_hash.SHA384Hasher())
            case SHA512 => StreamingHasher.SHA512(bao_hash.SHA512Hasher())
            case _ => {
                if (computeIfMissing) {
                    StreamingHasher.SHA512(bao_hash.SHA512Hasher())
                } else {
                    StreamingHasher.None
                }
            }
        }
    }

    /// 更新数据
    /// 翻译自: Streaming.update
    public func update(bytes: ArrayList<Byte>): Unit {
        if (bytes.size == 0) { return }
        match (hasher) {
            case StreamingHasher.None => {}
            case StreamingHasher.SHA1(h) => h.update(bytes)
            case StreamingHasher.SHA256(h) => h.update(bytes)
            case StreamingHasher.SHA384(h) => h.update(bytes)
            case StreamingHasher.SHA512(h) => h.update(bytes)
        }
    }

    /// 最终计算
    /// 翻译自: Streaming.final
    public func final(): Integrity {
        match (hasher) {
            case StreamingHasher.None => return Integrity()
            case StreamingHasher.SHA1(h) => return Integrity(tag: IntegrityTag.SHA1, value: h.finalHash())
            case StreamingHasher.SHA256(h) => return Integrity(tag: IntegrityTag.SHA256, value: h.finalHash())
            case StreamingHasher.SHA384(h) => return Integrity(tag: IntegrityTag.SHA384, value: h.finalHash())
            case StreamingHasher.SHA512(h) => return Integrity(tag: IntegrityTag.SHA512, value: h.finalHash())
        }
    }

    /// 验证
    /// 翻译自: Streaming.verify
    public func verify(): Bool {
        if (!expected.tag.isSupported()) { return true }
        let computed = final()
        if (computed.tag != expected.tag) { return false }
        return computed.value == expected.value
    }
}

// ============================================================================
// 辅助方法
// ============================================================================

/// 十六进制解码
/// 翻译自: Integrity.parseSHASum 中的 hex 解码逻辑
public func hexDecode(hex: String): String {
    let sb = StringBuilder()
    var i = 0
    while (i + 1 < hex.length) {
        let high = hexCharToInt(hex[i])
        let low = hexCharToInt(hex[i + 1])
        if (high < 0 || low < 0) { break }
        sb.append(Char((high << 4) | low))
        i += 2
    }
    return sb.toString()
}

/// 十六进制字符转整数
public func hexCharToInt(c: Char): Int64 {
    if (c >= '0' && c <= '9') { return Int64(c) - Int64('0') }
    if (c >= 'A' && c <= 'F') { return Int64(c) - Int64('A') + 10 }
    if (c >= 'a' && c <= 'f') { return Int64(c) - Int64('a') + 10 }
    return -1
}

/// 字符串转字节列表
public func stringToBytes(s: String): ArrayList<Byte> {
    let bytes = ArrayList<Byte>()
    for (i in 0..s.length) {
        bytes.append(Byte(s[i]))
    }
    return bytes
}
