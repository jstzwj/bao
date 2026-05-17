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

    public operator func ==(right: IntegrityTag): Bool {
        match (this) {
            case Unknown => match (right) { case Unknown => true case _ => false }
            case SHA1 => match (right) { case SHA1 => true case _ => false }
            case SHA256 => match (right) { case SHA256 => true case _ => false }
            case SHA384 => match (right) { case SHA384 => true case _ => false }
            case SHA512 => match (right) { case SHA512 => true case _ => false }
        }
    }

    public operator func !=(right: IntegrityTag): Bool {
        return !(this == right)
    }

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
            case Some(idx) => parseIntegrityTag(buf, idx)
            case None => IntegrityTagParseResult(Unknown, 0)
        }
    }

    private static func parseIntegrityTag(buf: String, idx: Int64): IntegrityTagParseResult {
        if (idx <= 0 || idx >= buf.size - 1) {
            return IntegrityTagParseResult(Unknown, 0)
        }
        let prefix = buf[..idx]
        let offset = idx + 1
        match (prefix) {
            case "sha1" => IntegrityTagParseResult(SHA1, offset)
            case "sha256" => IntegrityTagParseResult(SHA256, offset)
            case "sha384" => IntegrityTagParseResult(SHA384, offset)
            case "sha512" => IntegrityTagParseResult(SHA512, offset)
            case _ => IntegrityTagParseResult(Unknown, 0)
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

    /// 转为字符串 (不含横杠)
    public func toString(): String {
        match (this) {
            case SHA1 => "sha1"
            case SHA256 => "sha256"
            case SHA384 => "sha384"
            case SHA512 => "sha512"
            case _ => "unknown"
        }
    }

    /// 从字符串解析
    public static func fromString(s: String): IntegrityTag {
        if (s.startsWith("sha512")) { return SHA512 }
        if (s.startsWith("sha1")) { return SHA1 }
        if (s.startsWith("sha256")) { return SHA256 }
        if (s.startsWith("sha384")) { return SHA384 }
        return SHA512
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
/// value 存储 hex 编码的哈希摘要
public class Integrity {
    /// 哈希算法标签
    public var tag: IntegrityTag
    /// 哈希值 (hex 编码字符串)
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
        if (buf.size < 7) {  // "sha256-".size
            return Integrity()
        }

        let result = IntegrityTag.parse(buf)
        let ptag = result.tag
        if (ptag == IntegrityTag.Unknown) {
            return Integrity()
        }

        let expectedLen = ptag.digestLen()
        if (expectedLen == 0) {
            return Integrity()
        }

        let input = buf[Int64(result.offset)..].trimEnd("=")

        // Base64 解码 -- Base64Encode only has encode, so we decode manually
        let decoded = base64Decode(input)
        // Convert bytes to hex string for storage
        let hexValue = HexEncode.encode(decoded)

        return Integrity(ptag, hexValue)
    }

    /// 从 shasum 格式解析 (十六进制)
    /// 严格翻译自: Integrity.parseSHASum
    ///
    /// 输入格式: "3cd0599b099384b815c10f7fa7df0092b62d534f" (40 字符 hex)
    public static func parseSHASum(buf: String): Integrity {
        if (buf.size == 0) {
            return Integrity()
        }

        // 将十六进制字符串取前 40 字符, 直接作为 hex 值存储
        let hexStr = buf[..if (buf.size < 40) { buf.size } else { Int64(40) }]
        return Integrity(IntegrityTag.SHA1, hexStr)
    }

    /// 格式化为 SRI 字符串
    /// 翻译自: Integrity.format
    public func format(): String {
        if (!tag.isSupported()) { return "" }

        // value 是 hex 编码, 需要转为 bytes 再 base64 编码
        let bytes = HexEncode.decode(value)
        let encoded = Base64Encode.encode(bytes)
        return "${tag.prefix()}${encoded}"
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
    public func verify(bytes: ArrayList<UInt8>): Bool {
        return verifyByTag(tag, bytes, value)
    }

    /// 验证字符串数据
    public func verifyString(data: String): Bool {
        // 将字符串转换为字节进行验证
        return verifyByTag(tag, stringToBytes(data), value)
    }

    /// 按标签验证
    /// 翻译自: Integrity.verifyByTag
    public static func verifyByTag(tag: IntegrityTag, bytes: ArrayList<UInt8>, sum: String): Bool {
        if (!tag.isSupported()) { return false }

        let arr = bytes.items()
        let computed = computeHash(tag, arr)

        return computed == sum
    }

    /// 计算指定标签的哈希 (返回 hex)
    public static func computeHash(tag: IntegrityTag, data: Array<UInt8>): String {
        match (tag) {
            case SHA1 => return HexEncode.encode(Sha1.hash(data))
            case SHA256 => return HexEncode.encode(Sha256.hash(data))
            case SHA384 =>
                // SHA-384 = SHA-512 截断到前 48 字节
                let full = Sha512.hash(data)
                var truncated = ArrayList<UInt8>()
                for (i in 0..48) { truncated.append(full[i]) }
                return HexEncode.encode(truncated.items())
            case SHA512 => return HexEncode.encode(Sha512.hash(data))
            case _ => return ""
        }
    }

    /// 从字节数据计算 SHA-512 完整性
    /// 翻译自: Integrity.forBytes
    public static func forBytes(bytes: ArrayList<UInt8>): Integrity {
        let hashHex = HexEncode.encode(Sha512.hash(bytes.items()))
        return Integrity(IntegrityTag.SHA512, hashHex)
    }

    /// 从字符串计算 SHA-512 完整性
    public static func forString(data: String): Integrity {
        return forBytes(stringToBytes(data))
    }

    /// 是否为空
    public func isEmpty(): Bool {
        return tag == IntegrityTag.Unknown || value.size == 0
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
/// 使用 Sha1/Sha256/Sha512 实例作为流式哈希器
public enum StreamingHasher {
    | None
    | SSha1(Sha1)
    | SSha256(Sha256)
    | SSha384(Sha512)  // SHA-384 使用 Sha512 实现, 取前 48 字节
    | SSha512(Sha512)
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
    /// 是否在缺失时也计算
    private var computeIfMissing: Bool

    public init(expected: Integrity, computeIfMissing: Bool) {
        this.expected = expected
        this.computeIfMissing = computeIfMissing
        hasher = match (expected.tag) {
            case IntegrityTag.SHA1 => StreamingHasher.SSha1(Sha1())
            case IntegrityTag.SHA256 => StreamingHasher.SSha256(Sha256())
            case IntegrityTag.SHA384 => StreamingHasher.SSha384(Sha512())
            case IntegrityTag.SHA512 => StreamingHasher.SSha512(Sha512())
            case _ =>
                if (computeIfMissing) {
                    StreamingHasher.SSha512(Sha512())
                } else {
                    StreamingHasher.None
                }
        }
    }

    /// 更新数据
    /// 翻译自: Streaming.update
    public func update(bytes: ArrayList<UInt8>): Unit {
        if (bytes.size == 0) { return }
        let arr = bytes.items()
        match (hasher) {
            case StreamingHasher.None => ()
            case StreamingHasher.SSha1(h) => h.update(arr)
            case StreamingHasher.SSha256(h) => h.update(arr)
            case StreamingHasher.SSha384(h) => h.update(arr)
            case StreamingHasher.SSha512(h) => h.update(arr)
        }
    }

    /// 最终计算
    /// 翻译自: Streaming.final
    public func final(): Integrity {
        match (hasher) {
            case StreamingHasher.None => return Integrity()
            case StreamingHasher.SSha1(h) =>
                return Integrity(IntegrityTag.SHA1, HexEncode.encode(h.finalize()))
            case StreamingHasher.SSha256(h) =>
                return Integrity(IntegrityTag.SHA256, HexEncode.encode(h.finalize()))
            case StreamingHasher.SSha384(h) =>
                // SHA-384: 取 SHA-512 结果的前 48 字节
                let full = h.finalize()
                var truncated = ArrayList<UInt8>()
                for (i in 0..48) { truncated.append(full[i]) }
                return Integrity(IntegrityTag.SHA384, HexEncode.encode(truncated.items()))
            case StreamingHasher.SSha512(h) =>
                return Integrity(IntegrityTag.SHA512, HexEncode.encode(h.finalize()))
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

/// Base64 解码
/// 手动实现, 因为 bao_hash 的 Base64Encode 只有 encode
public func base64Decode(input: String): Array<UInt8> {
    // Base64 解码表
    let table: Array<Int64> = [
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63,
        52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1,
        -1,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
        15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1,
        -1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
        41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
        -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1
    ]

    // 先去除 '=' 填充
    var s = input.trimEnd("=")
    var result = ArrayList<UInt8>()
    var i: Int64 = 0
    while (i + 3 < s.size || i + 2 < s.size) {
        let c0 = Int64(s[i])
        let c1 = Int64(s[i + 1])
        let v0 = if (c0 >= 0 && c0 < table.size) { table[c0] } else { -1 }
        let v1 = if (c1 >= 0 && c1 < table.size) { table[c1] } else { -1 }
        if (v0 < 0 || v1 < 0) {
            i += 4
            continue
        }
        result.append(UInt8(((v0 << 2) | (v1 >> 4)) & 0xFF))

        if (i + 2 < s.size) {
            let c2 = Int64(s[i + 2])
            let v2 = if (c2 >= 0 && c2 < table.size) { table[c2] } else { -1 }
            if (v2 >= 0) {
                result.append(UInt8((((v1 << 4) | (v2 >> 2)) & 0xFF)))
            }

            if (i + 3 < s.size) {
                let c3 = Int64(s[i + 3])
                let v3 = if (c3 >= 0 && c3 < table.size) { table[c3] } else { -1 }
                if (v3 >= 0) {
                    result.append(UInt8((((v2 << 6) | v3) & 0xFF)))
                }
            }
        }
        i += 4
    }
    return result.items()
}

/// 字符串转字节列表
public func stringToBytes(s: String): ArrayList<UInt8> {
    let bytes = ArrayList<UInt8>()
    for (c in s) {
        bytes.append(UInt8(UInt32(c)))
    }
    return bytes
}
