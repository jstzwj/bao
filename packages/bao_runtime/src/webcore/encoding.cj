// Encoding - 编码工具
// 对应 Bun: src/runtime/webcore/encoding.zig
// 严格翻译自: src/runtime/webcore/encoding.zig
package bao_runtime

import bao_core.*

// ============================================================================
// Encoding - 编码类型
// 对应 Bun: Encoding enum
// ============================================================================

/// 编码类型
/// 对应 Bun: bun.jsc.Node.Encoding
public enum Encoding {
    | UTF8
    | UTF16LE
    | Latin1
    | ASCII
    | Base64
    | Base64URL
    | Hex
    | Buffer

    /// 从字符串解析编码
    public static func fromString(name: String): ?Encoding {
        let lower = name.toLowerCase().trim()
        if (lower == "utf-8" || lower == "utf8") { return Some(Encoding.UTF8) }
        if (lower == "utf-16le" || lower == "utf16le" || lower == "ucs2" || lower == "ucs-2") { return Some(Encoding.UTF16LE) }
        if (lower == "latin1" || lower == "latin-1" || lower == "binary") { return Some(Encoding.Latin1) }
        if (lower == "ascii") { return Some(Encoding.ASCII) }
        if (lower == "base64") { return Some(Encoding.Base64) }
        if (lower == "base64url") { return Some(Encoding.Base64URL) }
        if (lower == "hex") { return Some(Encoding.Hex) }
        if (lower == "buffer") { return Some(Encoding.Buffer) }
        return None
    }

    /// 获取编码名称字符串
    public func toString(): String {
        match (this) {
            case UTF8 => "utf-8"
            case UTF16LE => "utf-16le"
            case Latin1 => "latin1"
            case ASCII => "ascii"
            case Base64 => "base64"
            case Base64URL => "base64url"
            case Hex => "hex"
            case Buffer => "buffer"
        }
    }
}

// ============================================================================
// EncodingHelper - 编码辅助函数
// 对应 Bun: encoding.zig 中的各种 write/construct 函数
// ============================================================================

/// 编码辅助工具
public class EncodingHelper {
    /// 将 Latin1 字节写入指定编码
    /// 对应 Bun: Bun__encoding__writeLatin1
    public static func writeLatin1(input: Array<UInt8>, encoding: Encoding): Array<UInt8> {
        match (encoding) {
            case Encoding.UTF8 => {
                // Latin1 -> UTF-8 转换
                let result = ArrayList<UInt8>()
                for (b in input) {
                    let cp = Int64(b)
                    if (cp < 0x80) {
                        result.append(b)
                    } else if (cp < 0x100) {
                        result.append(UInt8(0xC0 | (cp >> 6)))
                        result.append(UInt8(0x80 | (cp & 0x3F)))
                    }
                }
                return result.toArray()
            }
            case Encoding.Hex => {
                let result = ArrayList<UInt8>()
                for (b in input) {
                    let hex = Int64(b).toHexString()
                    for (c in hex) {
                        result.append(UInt8(Int64(c)))
                    }
                }
                return result.toArray()
            }
            case Encoding.Base64 => {
                return Base64Codec.encode(input)
            }
            case Encoding.Base64URL => {
                return Base64Codec.encodeURL(input)
            }
            case _ => return input
        }
    }

    /// 将 UTF-16 字节写入指定编码
    /// 对应 Bun: Bun__encoding__writeUTF16
    public static func writeUTF16(input: Array<UInt16>, encoding: Encoding): Array<UInt8> {
        match (encoding) {
            case Encoding.UTF8 => {
                // UTF-16 -> UTF-8 转换
                let result = ArrayList<UInt8>()
                for (u in input) {
                    let cp = Int64(u)
                    if (cp < 0x80) {
                        result.append(UInt8(cp))
                    } else if (cp < 0x800) {
                        result.append(UInt8(0xC0 | (cp >> 6)))
                        result.append(UInt8(0x80 | (cp & 0x3F)))
                    } else if (cp < 0x10000) {
                        result.append(UInt8(0xE0 | (cp >> 12)))
                        result.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
                        result.append(UInt8(0x80 | (cp & 0x3F)))
                    } else {
                        result.append(UInt8(0xF0 | (cp >> 18)))
                        result.append(UInt8(0x80 | ((cp >> 12) & 0x3F)))
                        result.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
                        result.append(UInt8(0x80 | (cp & 0x3F)))
                    }
                }
                return result.toArray()
            }
            case Encoding.Hex => {
                let result = ArrayList<UInt8>()
                for (u in input) {
                    let hex = Int64(u).toHexString()
                    for (c in hex) {
                        result.append(UInt8(Int64(c)))
                    }
                }
                return result.toArray()
            }
            case _ => {
                // 直接字节拷贝
                let result = ArrayList<UInt8>()
                for (u in input) {
                    result.append(UInt8(u & 0xFF))
                    result.append(UInt8((u >> 8) & 0xFF))
                }
                return result.toArray()
            }
        }
    }

    /// 将字节转为指定编码的字符串
    /// 对应 Bun: encoding.toString()
    public static func toString(input: Array<UInt8>, encoding: Encoding): String {
        match (encoding) {
            case Encoding.UTF8 | Encoding.Buffer => return Utf8Codec.decode(input)
            case Encoding.ASCII | Encoding.Latin1 => {
                let sb = StringBuilder()
                for (b in input) {
                    sb.append(Char(Int64(b & 0x7F)))
                }
                return sb.toString()
            }
            case Encoding.Hex => {
                let sb = StringBuilder()
                for (b in input) {
                    let hex = Int64(b).toHexString()
                    if (hex.length < 2) {
                        sb.append("0")
                    }
                    sb.append(hex)
                }
                return sb.toString()
            }
            case Encoding.Base64 => return Base64Codec.encodeToString(input)
            case Encoding.Base64URL => return Base64Codec.encodeURLString(input)
            case _ => return Utf8Codec.decode(input)
        }
    }

    /// 从指定编码构造字节数组
    /// 对应 Bun: Bun__encoding__constructFromLatin1
    public static func constructFromLatin1(input: Array<UInt8>, encoding: Encoding): Array<UInt8> {
        match (encoding) {
            case Encoding.Hex => {
                let result = ArrayList<UInt8>()
                for (b in input) {
                    let hex = Int64(b).toHexString()
                    if (hex.length < 2) {
                        result.append(UInt8(Int64('0')))
                    }
                    for (c in hex) {
                        result.append(UInt8(Int64(c)))
                    }
                }
                return result.toArray()
            }
            case Encoding.Base64 => return Base64Codec.encode(input)
            case Encoding.Base64URL => return Base64Codec.encodeURL(input)
            case _ => return input
        }
    }
}

// ============================================================================
// Base64Codec - Base64 编解码
// ============================================================================

/// Base64 编解码器
public class Base64Codec {
    private static let BASE64_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    private static let BASE64URL_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

    /// Base64 编码
    public static func encode(input: Array<UInt8>): Array<UInt8> {
        let str = encodeToString(input)
        return Utf8Codec.encode(str)
    }

    /// Base64 编码为字符串
    public static func encodeToString(input: Array<UInt8>): String {
        let sb = StringBuilder()
        var i = 0
        while (i < input.size) {
            let b0 = Int64(input[Int64(i)])
            let b1 = if (i + 1 < input.size) { Int64(input[Int64(i) + 1]) } else { 0 }
            let b2 = if (i + 2 < input.size) { Int64(input[Int64(i) + 2]) } else { 0 }

            let n = (b0 << 16) | (b1 << 8) | b2

            sb.append(Char(BASE64_CHARS[Int64((n >> 18) & 0x3F)]))
            sb.append(Char(BASE64_CHARS[Int64((n >> 12) & 0x3F)]))

            if (i + 1 < input.size) {
                sb.append(Char(BASE64_CHARS[Int64((n >> 6) & 0x3F)]))
            } else {
                sb.append("=")
            }

            if (i + 2 < input.size) {
                sb.append(Char(BASE64_CHARS[Int64(n & 0x3F)]))
            } else {
                sb.append("=")
            }

            i += 3
        }
        return sb.toString()
    }

    /// Base64URL 编码
    public static func encodeURL(input: Array<UInt8>): Array<UInt8> {
        let str = encodeURLString(input)
        return Utf8Codec.encode(str)
    }

    /// Base64URL 编码为字符串
    public static func encodeURLString(input: Array<UInt8>): String {
        let sb = StringBuilder()
        var i = 0
        while (i < input.size) {
            let b0 = Int64(input[Int64(i)])
            let b1 = if (i + 1 < input.size) { Int64(input[Int64(i) + 1]) } else { 0 }
            let b2 = if (i + 2 < input.size) { Int64(input[Int64(i) + 2]) } else { 0 }

            let n = (b0 << 16) | (b1 << 8) | b2

            sb.append(Char(BASE64URL_CHARS[Int64((n >> 18) & 0x3F)]))
            sb.append(Char(BASE64URL_CHARS[Int64((n >> 12) & 0x3F)]))

            if (i + 1 < input.size) {
                sb.append(Char(BASE64URL_CHARS[Int64((n >> 6) & 0x3F)]))
            }
            if (i + 2 < input.size) {
                sb.append(Char(BASE64URL_CHARS[Int64(n & 0x3F)]))
            }

            i += 3
        }
        return sb.toString()
    }

    /// Base64 解码
    public static func decode(input: String): Array<UInt8> {
        let result = ArrayList<UInt8>()
        let chars = BASE64_CHARS
        var i = 0
        while (i < input.length) {
            var n = 0
            var padding = 0

            for (j in 0..4) {
                let idx = i + j
                if (idx >= input.length) { break }
                let c = input[Int64(idx)]
                if (c == '=') {
                    padding += 1
                    n = n << 6
                } else {
                    var val = 0
                    for (k in 0..64) {
                        if (Char(chars[Int64(k)]) == c) {
                            val = k
                            break
                        }
                    }
                    n = (n << 6) | val
                }
            }

            if (padding < 2) {
                result.append(UInt8((n >> 16) & 0xFF))
            }
            if (padding < 1) {
                result.append(UInt8((n >> 8) & 0xFF))
            }
            if (padding == 0) {
                result.append(UInt8(n & 0xFF))
            }

            i += 4
        }
        return result.toArray()
    }
}
