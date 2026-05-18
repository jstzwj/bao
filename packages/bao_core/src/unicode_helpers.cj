// bao_core - Unicode 辅助工具
// 严格翻译自: src/bun_core/string/immutable/unicode.rs
//   pub trait CodePointZero: Copy + Eq + ... { const ZERO_VALUE: Self; fn from_u32(v: u32) -> Self; }
//   pub fn codepoint_size(first_byte: u8) -> u8
//   pub fn decode_wtf8_rune_t(bytes) -> CodePoint
//   pub fn wtf8_byte_sequence_length(first_byte: u8) -> u8
// Bun: WTF-8 解码、码点大小计算、编码转换工具
// 仓颉: 提供等价的 Unicode/WTF-8 工具函数
package bao_core

import std.collection.*

// ============================================================================
// CodePoint 类型 - 对应 Bun CodePoint (i32)
// 严格翻译自: src/bun_core/string/immutable/unicode.rs CodePointZero trait
// ============================================================================

/// Unicode 替换字符 - 对应 Bun UNICODE_REPLACEMENT
public let UNICODE_REPLACEMENT: Int32 = 0xFFFD

/// UTF-8 BOM - 对应 Bun BOM
public let BOM: UInt8 = 0xEF

/// UTF-8 BOM 完整序列
public let UTF8_BOM: Array<UInt8> = [UInt8(0xEF), UInt8(0xBB), UInt8(0xBF)]

// ============================================================================
// 码点大小计算 - 严格翻译自: src/bun_core/string/immutable/unicode.rs
//   pub fn codepoint_size(first_byte: u8) -> u8
// ============================================================================

/// Unicode 工具 - 对应 Bun unicode 模块
public class UnicodeHelpers {
    /// 计算 UTF-8 码点的字节序列长度
    /// 对应 Bun codepoint_size / wtf8_byte_sequence_length
    public static func codepointSize(firstByte: UInt8): Int64 {
        if (firstByte < 0x80) {
            return 1
        }
        if ((firstByte & 0xE0) == 0xC0) {
            return 2
        }
        if ((firstByte & 0xF0) == 0xE0) {
            return 3
        }
        if ((firstByte & 0xF8) == 0xF0) {
            return 4
        }
        return 1  // 无效字节, 当作单字节处理
    }

    /// WTF-8 字节序列长度 (带无效字节检查)
    /// 对应 Bun wtf8_byte_sequence_length_with_invalid
    public static func wtf8ByteSequenceLengthWithInvalid(firstByte: UInt8): Int64 {
        if (firstByte < 0x80) {
            return 1
        }
        if ((firstByte & 0xE0) == 0xC0) {
            return 2
        }
        if ((firstByte & 0xF0) == 0xE0) {
            return 3
        }
        if ((firstByte & 0xF8) == 0xF0) {
            return 4
        }
        return 1  // 无效 → 替换字符
    }

    /// 解码 WTF-8 码点
    /// 对应 Bun decode_wtf8_rune_t
    /// 返回 (码点, 字节长度)
    public static func decodeWtf8Rune(bytes: Array<UInt8>, offset: Int64): DecodeResult {
        if (offset >= bytes.size) {
            return DecodeResult(UNICODE_REPLACEMENT, 0)
        }
        let b0 = bytes[offset]
        if (b0 < 0x80) {
            return DecodeResult(Int32(b0), 1)
        }
        if ((b0 & 0xE0) == 0xC0) {
            if (offset + 1 >= bytes.size) {
                return DecodeResult(UNICODE_REPLACEMENT, 1)
            }
            let b1 = bytes[offset + 1]
            if ((b1 & 0xC0) != 0x80) {
                return DecodeResult(UNICODE_REPLACEMENT, 1)
            }
            let cp = (Int32(b0 & 0x1F) << 6) | Int32(b1 & 0x3F)
            return DecodeResult(cp, 2)
        }
        if ((b0 & 0xF0) == 0xE0) {
            if (offset + 2 >= bytes.size) {
                return DecodeResult(UNICODE_REPLACEMENT, Int64(MathMin(2, bytes.size - offset)))
            }
            let b1 = bytes[offset + 1]
            let b2 = bytes[offset + 2]
            if ((b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80) {
                return DecodeResult(UNICODE_REPLACEMENT, 1)
            }
            let cp = (Int32(b0 & 0x0F) << 12) | (Int32(b1 & 0x3F) << 6) | Int32(b2 & 0x3F)
            // WTF-8: 允许代理对 (U+D800..U+DFFF)
            return DecodeResult(cp, 3)
        }
        if ((b0 & 0xF8) == 0xF0) {
            if (offset + 3 >= bytes.size) {
                return DecodeResult(UNICODE_REPLACEMENT, Int64(MathMin(3, bytes.size - offset)))
            }
            let b1 = bytes[offset + 1]
            let b2 = bytes[offset + 2]
            let b3 = bytes[offset + 3]
            if ((b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80 || (b3 & 0xC0) != 0x80) {
                return DecodeResult(UNICODE_REPLACEMENT, 1)
            }
            let cp = (Int32(b0 & 0x07) << 18) | (Int32(b1 & 0x3F) << 12) |
                     (Int32(b2 & 0x3F) << 6) | Int32(b3 & 0x3F)
            return DecodeResult(cp, 4)
        }
        return DecodeResult(UNICODE_REPLACEMENT, 1)
    }

    /// 解码多字节 WTF-8 (已知首字节不是 ASCII)
    /// 对应 Bun decode_wtf8_rune_t_multibyte
    public static func decodeWtf8RuneMultibyte(b0: UInt8, bytes: Array<UInt8>, offset: Int64): DecodeResult {
        if ((b0 & 0xE0) == 0xC0) {
            if (offset >= bytes.size) {
                return DecodeResult(UNICODE_REPLACEMENT, 1)
            }
            let b1 = bytes[offset]
            if ((b1 & 0xC0) != 0x80) {
                return DecodeResult(UNICODE_REPLACEMENT, 1)
            }
            let cp = (Int32(b0 & 0x1F) << 6) | Int32(b1 & 0x3F)
            return DecodeResult(cp, 2)
        }
        if ((b0 & 0xF0) == 0xE0) {
            if (offset + 1 >= bytes.size) {
                return DecodeResult(UNICODE_REPLACEMENT, 1)
            }
            let b1 = bytes[offset]
            let b2 = bytes[offset + 1]
            if ((b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80) {
                return DecodeResult(UNICODE_REPLACEMENT, 1)
            }
            let cp = (Int32(b0 & 0x0F) << 12) | (Int32(b1 & 0x3F) << 6) | Int32(b2 & 0x3F)
            return DecodeResult(cp, 3)
        }
        if ((b0 & 0xF8) == 0xF0) {
            if (offset + 2 >= bytes.size) {
                return DecodeResult(UNICODE_REPLACEMENT, 1)
            }
            let b1 = bytes[offset]
            let b2 = bytes[offset + 1]
            let b3 = bytes[offset + 2]
            if ((b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80 || (b3 & 0xC0) != 0x80) {
                return DecodeResult(UNICODE_REPLACEMENT, 1)
            }
            let cp = (Int32(b0 & 0x07) << 18) | (Int32(b1 & 0x3F) << 12) |
                     (Int32(b2 & 0x3F) << 6) | Int32(b3 & 0x3F)
            return DecodeResult(cp, 4)
        }
        return DecodeResult(UNICODE_REPLACEMENT, 1)
    }

    /// 查找第一个非 ASCII 字节的位置 - 对应 Bun first_non_ascii
    public static func firstNonAscii(bytes: Array<UInt8>): Int64 {
        for (i in 0..bytes.size) {
            if (bytes[i] >= 0x80) {
                return i
            }
        }
        return -1
    }

    /// 检查是否包含非 BMP 码点 - 对应 Bun contains_non_bmp_code_point
    public static func containsNonBmpCodePoint(bytes: Array<UInt8>): Bool {
        var i = 0
        while (i < bytes.size) {
            let b = bytes[i]
            if (b >= 0xF0) {
                return true  // 4 字节序列一定是 non-BMP
            }
            if (b >= 0xC0) {
                i += codepointSize(b)
            } else {
                i += 1
            }
        }
        return false
    }

    /// UTF-16 码点解码 - 对应 Bun utf16_codepoint
    /// 返回码点和 UTF-16 单元数 (1 或 2)
    public static func utf16Codepoint(chars: Array<UInt16>, offset: Int64): Utf16CodepointResult {
        if (offset >= chars.size) {
            return Utf16CodepointResult(UInt32(0), 0)
        }
        let ch = UInt32(chars[offset])
        // 高代理
        if (ch >= 0xD800 && ch <= 0xDBFF) {
            if (offset + 1 < chars.size) {
                let low = UInt32(chars[offset + 1])
                if (low >= 0xDC00 && low <= 0xDFFF) {
                    let cp = ((ch - 0xD800) << 10) + (low - 0xDC00) + 0x10000
                    return Utf16CodepointResult(cp, 2)
                }
            }
            // 孤立高代理
            return Utf16CodepointResult(ch, 1)
        }
        return Utf16CodepointResult(ch, 1)
    }

    /// UTF-16 码点解码 (带 FFFD 替换) - 对应 Bun utf16_codepoint_with_fffd
    public static func utf16CodepointWithFffd(chars: Array<UInt16>, offset: Int64): Utf16CodepointResult {
        let result = utf16Codepoint(chars, offset)
        if (result.codepoint >= 0xD800 && result.codepoint <= 0xDFFF) {
            return Utf16CodepointResult(UInt32(0xFFFD), result.length)
        }
        return result
    }

    /// U+16 是否为前导代理 - 对应 Bun u16_is_lead
    public static func u16IsLead(c: UInt16): Bool {
        return c >= 0xD800 && c <= 0xDBFF
    }

    /// U+16 是否为尾随代理 - 对应 Bun u16_is_trail
    public static func u16IsTrail(c: UInt16): Bool {
        return c >= 0xDC00 && c <= 0xDFFF
    }

    /// U+16 是否为代理 - 对应 Bun u16_is_surrogate
    public static func u16IsSurrogate(c: UInt16): Bool {
        return c >= 0xD800 && c <= 0xDFFF
    }

    /// 解码代理对 - 对应 Bun decode_surrogate_pair
    public static func decodeSurrogatePair(high: UInt16, low: UInt16): UInt32 {
        return ((UInt32(high) - 0xD800) << 10) + (UInt32(low) - 0xDC00) + 0x10000
    }

    /// 将码点编码为 WTF-8 字节序列 - 对应 Bun wtf8_sequence
    public static func wtf8Sequence(cp: Int32): Array<UInt8> {
        if (cp < 0) {
            return [UInt8(0xEF), UInt8(0xBF), UInt8(0xBD)]  // U+FFFD
        }
        if (cp < 0x80) {
            return [UInt8(cp)]
        }
        if (cp < 0x800) {
            return [
                UInt8(0xC0 | (cp >> 6)),
                UInt8(0x80 | (cp & 0x3F))
            ]
        }
        if (cp < 0x10000) {
            return [
                UInt8(0xE0 | (cp >> 12)),
                UInt8(0x80 | ((cp >> 6) & 0x3F)),
                UInt8(0x80 | (cp & 0x3F))
            ]
        }
        if (cp < 0x110000) {
            return [
                UInt8(0xF0 | (cp >> 18)),
                UInt8(0x80 | ((cp >> 12) & 0x3F)),
                UInt8(0x80 | ((cp >> 6) & 0x3F)),
                UInt8(0x80 | (cp & 0x3F))
            ]
        }
        return [UInt8(0xEF), UInt8(0xBF), UInt8(0xBD)]  // U+FFFD
    }

    /// 复制 Latin1 到 UTF-8 - 对应 Bun copy_latin1_into_utf8
    public static func copyLatin1IntoUtf8(src: Array<UInt8>): Array<UInt8> {
        var result = ArrayList<UInt8>()
        for (b in src) {
            if (b < 0x80) {
                result.add(b)
            } else {
                result.add(UInt8(0xC0 | (b >> 6)))
                result.add(UInt8(0x80 | (b & 0x3F)))
            }
        }
        return result.toArray()
    }

    private static func MathMin(a: Int64, b: Int64): Int64 {
        if (a < b) { return a }
        return b
    }
}

/// 解码结果 - 对应 Bun decode_wtf8_rune_t 的返回值
public class DecodeResult {
    /// 码点值 (对应 Bun CodePoint / i32)
    public let codepoint: Int32
    /// 消费的字节数
    public let length: Int64

    public init(codepoint: Int32, length: Int64) {
        this.codepoint = codepoint
        this.length = length
    }
}

/// UTF-16 码点结果 - 对应 Bun utf16_codepoint 返回值
public class Utf16CodepointResult {
    public let codepoint: UInt32
    public let length: Int64

    public init(codepoint: UInt32, length: Int64) {
        this.codepoint = codepoint
        this.length = length
    }
}

// ============================================================================
// CodepointIterator - 码点迭代器
// 严格翻译自: src/bun_core/string/immutable/unicode.rs CodepointIterator
// ============================================================================

/// 码点迭代器 - 对应 Bun CodepointIterator
public class CodepointIterator {
    private let bytes: Array<UInt8>
    private var pos: Int64

    public init(bytes: Array<UInt8>) {
        this.bytes = bytes
        this.pos = 0
    }

    /// 是否有下一个码点
    public func hasNext(): Bool {
        return pos < bytes.size
    }

    /// 获取下一个码点
    public func next(): DecodeResult {
        if (pos >= bytes.size) {
            return DecodeResult(UNICODE_REPLACEMENT, 0)
        }
        let result = UnicodeHelpers.decodeWtf8Rune(bytes, pos)
        pos += result.length
        return result
    }

    /// 获取当前位置
    public func position(): Int64 {
        return pos
    }

    /// 重置到起始位置
    public func reset(): Unit {
        pos = 0
    }
}
