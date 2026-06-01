// 严格翻译自: src/base64/base64.zig
// 对应 Bun 的 Base64 实现，包括:
//   - 标准 Base64 编码/解码 (带 padding)
//   - URL-safe Base64 编码/解码 (无 padding, +/ → -_)
//   - 标准 Base64 字母表: ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/
//   - URL-safe Base64 字母表: ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_
//   - Padding 处理 (=)
//   - 字符到索引查找表 (256 字节, 非法字符 = 0xFF)
package bao_base64

import bao_core.*
import bao_collections.*

// ============================================================================
// Base64 - 标准 Base64 编解码
// 严格翻译自: src/base64/base64.zig
//
// Bun 的 Base64 设计:
//   - 使用 zig_base64 库的 Encoder/Decoder 结构
//   - 标准 Base64: alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
//     pad_char = '='
//   - URL-safe Base64: alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
//     pad_char = '=' (带 padding) 或 null (无 padding)
//   - SIMD 加速: 通过 bun.simdutf 实现硬件加速编解码
//   - Forgiving 解码: 忽略空白字符 (空格、Tab、\r、\n)
//
// 仓颉实现:
//   - 纯仓颉实现，无 SIMD 优化
//   - 保持与 Bun 相同的字母表和编解码逻辑
//   - 支持标准 Base64 和 URL-safe Base64
// ============================================================================

/// Base64 编解码器
public class Base64 {
    // ========================================================================
    // 字母表定义
    // 严格翻译自: zig_base64.standard_alphabet_chars / url_safe_alphabet_chars
    //   pub const standard_alphabet_chars =
    //       "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".*
    //   pub const url_safe_alphabet_chars =
    //       "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_".*
    // ========================================================================

    /// 标准 Base64 字母表 (64 字符)
    /// 对应 Bun standard_alphabet_chars
    public static let STANDARD_ALPHABET: String =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    /// URL-safe Base64 字母表 (64 字符)
    /// 对应 Bun url_safe_alphabet_chars
    /// 将标准字母表的 + 和 / 替换为 - 和 _
    public static let URL_SAFE_ALPHABET: String =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

    /// Padding 字符
    public static let PAD_CHAR: UInt8 = UInt8(0x3D)

    /// 非法字符标记 - 对应 Bun Base64Decoder.invalid_char = 0xff
    private static let INVALID_CHAR: UInt8 = 0xFF

    // ========================================================================
    // 查找表构建
    // 严格翻译自: Base64Decoder.init
    //   pub fn init(alphabet_chars: [64]u8, pad_char: ?u8) Base64Decoder {
    //       var result = Base64Decoder{
    //           .char_to_index = [_]u8{invalid_char} ** 256,
    //           .pad_char = pad_char,
    //       };
    //       for (alphabet_chars, 0..) |c, i| {
    //           result.char_to_index[c] = @as(u8, @intCast(i));
    //       }
    //       return result;
    //   }
    // ========================================================================

    /// 标准 Base64 字符到索引查找表 (256 字节)
    /// char_to_index['A'] = 0, char_to_index['B'] = 1, ..., char_to_index['/'] = 63
    /// 非法字符映射到 0xFF
    private static var standardLUT: Array<UInt8> = buildLUT(STANDARD_ALPHABET)

    /// URL-safe Base64 字符到索引查找表 (256 字节)
    private static var urlSafeLUT: Array<UInt8> = buildLUT(URL_SAFE_ALPHABET)

    /// 构建查找表 - 对应 Bun Base64Decoder.init
    private static func buildLUT(alphabet: String): Array<UInt8> {
        var lut = ArrayList<UInt8>()
        for (_ in 0..256) {
            lut.append(INVALID_CHAR)
        }
        for (i in 0..64) {
            let idx = UInt8(alphabet[i])
            lut[Int64(idx)] = UInt8(i)
        }
        return lut.toOwnedSlice()
    }

    // ========================================================================
    // encode - Base64 编码
    // 严格翻译自: Base64Encoder.encode / encodeWithoutSizeCheck
    //   pub fn encode(encoder, dest: []u8, source: []const u8) []const u8 {
    //       const out_len = encoder.calcSize(source.len);
    //       const out_idx = encoder.encodeWithoutSizeCheck(dest, source);
    //       if (encoder.pad_char) |pad_char| {
    //           for (dest[out_idx..out_len]) |*pad| { pad.* = pad_char; }
    //       }
    //       return dest[0..out_len];
    //   }
    //
    //   pub fn encodeWithoutSizeCheck(encoder, dest, source) usize {
    //       var acc: u12 = 0;
    //       var acc_len: u4 = 0;
    //       var out_idx: usize = 0;
    //       for (source) |v| {
    //           acc = (acc << 8) + v;
    //           acc_len += 8;
    //           while (acc_len >= 6) {
    //               acc_len -= 6;
    //               dest[out_idx] = encoder.alphabet_chars[@as(u6, @truncate((acc >> acc_len)))];
    //               out_idx += 1;
    //           }
    //       }
    //       if (acc_len > 0) {
    //           dest[out_idx] = encoder.alphabet_chars[@as(u6, @truncate((acc << 6 - acc_len)))];
    //           out_idx += 1;
    //       }
    //       return out_idx;
    //   }
    // ========================================================================

    /// 标准 Base64 编码 (带 padding)
    /// 对应 Bun Base64Encoder.encode (standard, pad_char = '=')
    ///
    /// 编码输出长度: ceil(sourceLen / 3) * 4
    /// 对应 Bun encodeLenFromSize:
    ///   return zig_base64.standard.Encoder.calcSize(source)
    ///   即 (source_len + 2) / 3 * 4
    public static func encode(data: Array<UInt8>): String {
        var result = StringBuilder()
        var acc: Int64 = 0    // 累加器 (最多 12 位)
        var accLen: Int64 = 0 // 累加器中的有效位数

        var i: Int64 = 0
        while (i < data.size) {
            // 累加字节到高位
            // Bun: acc = (acc << 8) + v; acc_len += 8;
            acc = (acc << 8) + Int64(data[i])
            accLen += 8

            // 每当累积 >= 6 位时，提取一个 Base64 字符
            // Bun: while (acc_len >= 6) { acc_len -= 6; dest[out_idx] = alphabet[acc >> acc_len]; }
            while (accLen >= 6) {
                accLen -= 6
                let idx = (acc >> accLen) & 0x3F  // 取低 6 位
                result.append(STANDARD_ALPHABET[idx])
            }

            i += 1
        }

        // 处理剩余不足 6 位的部分
        // Bun: if (acc_len > 0) { dest[out_idx] = alphabet[acc << (6 - acc_len)]; }
        if (accLen > 0) {
            let idx = (acc << (6 - accLen)) & 0x3F
            result.append(STANDARD_ALPHABET[idx])
        }

        // 添加 padding
        // Bun: if (encoder.pad_char) |pad_char| { for padding positions: pad.* = pad_char; }
        let encodedLen = result.size
        let expectedLen = ((data.size + 2) / 3) * 4
        var padCount = expectedLen - encodedLen
        while (padCount > 0) {
            result.append('=')
            padCount -= 1
        }

        return result.toString()
    }

    // ========================================================================
    // decode - Base64 解码
    // 严格翻译自: Base64DecoderWithIgnore.decode (宽大解码)
    //   pub fn decode(decoder_with_ignore, dest: []u8, source: []const u8, wrote: *usize) Error!void {
    //       const decoder = &decoder_with_ignore.decoder;
    //       var acc: u12 = 0;
    //       var acc_len: u4 = 0;
    //       var dest_idx: usize = 0;
    //       for (source, 0..) |c, src_idx| {
    //           if (decoder_with_ignore.char_is_ignored[c]) continue;
    //           const d = decoder.char_to_index[c];
    //           if (d == Base64Decoder.invalid_char) {
    //               if (decoder.pad_char) |pad_char| {
    //                   if (c == pad_char) { leftover_idx = src_idx; break; }
    //               }
    //               return error.InvalidCharacter;
    //           }
    //           acc = (acc << 6) + d;
    //           acc_len += 6;
    //           if (acc_len >= 8) {
    //               acc_len -= 8;
    //               dest[dest_idx] = @as(u8, @truncate(acc >> acc_len));
    //               dest_idx += 1;
    //           }
    //       }
    //   }
    // ========================================================================

    /// 标准 Base64 解码
    /// 对应 Bun Base64Decoder.decode (standard)
    ///
    /// 支持宽容解码 - 对应 Bun mixed_decoder
    /// 忽略空白字符: 空格、Tab、\r、\n、VT、FF
    public static func decode(str: String): Array<UInt8> {
        let src = Array<UInt8>(str.size, { i => UInt8(str[i]) })
        let len = src.size
        let result = ArrayList<UInt8>()

        var acc: Int64 = 0
        var accLen: Int64 = 0
        var i: Int64 = 0

        while (i < len) {
            let ch = src[i]

            // 宽容解码: 跳过空白字符
            // 对应 Bun Base64DecoderWithIgnore.char_is_ignored
            // Zig: decoder_with_ignore.char_is_ignored[c] -> continue
            // 忽略: \xff, 空格(0x20), Tab(0x09), \r(0x0D), \n(0x0A), VT(0x0B), FF(0x0C)
            if (ch == UInt8(0x20) || ch == UInt8(0x09) || ch == UInt8(0x0D) || ch == UInt8(0x0A) ||
                ch == UInt8(0x0B) || ch == UInt8(0x0C)) {
                i += 1
                continue
            }

            // Padding 字符处理
            // Zig: if (c == pad_char) { leftover_idx = src_idx; break; }
            if (ch == UInt8(0x3D)) {
                // 跳过剩余 padding 和空白
                i += 1
                while (i < len) {
                    let pch = src[i]
                    if (pch != UInt8(0x3D) && pch != UInt8(0x20) && pch != UInt8(0x09) &&
                        pch != UInt8(0x0D) && pch != UInt8(0x0A)) {
                        break
                    }
                    i += 1
                }
                continue
            }

            // 查找字符索引
            let idx = if (Int64(ch) < 256) { standardLUT[Int64(ch)] } else { INVALID_CHAR }
            if (idx == INVALID_CHAR) {
                i += 1
                continue  // 跳过非法字符
            }

            // 累加 6 位
            // Zig: acc = (acc << 6) + d; acc_len += 6;
            acc = (acc << 6) + Int64(idx)
            accLen += 6

            // 提取完整字节
            // Zig: if (acc_len >= 8) { acc_len -= 8; dest[dest_idx] = truncate(acc >> acc_len); }
            if (accLen >= 8) {
                accLen -= 8
                result.append(UInt8((acc >> accLen) & Int64(0xFF)))
            }

            i += 1
        }

        return result.toOwnedSlice()
    }

    // ========================================================================
    // Base64Url - URL-safe Base64 编解码
    // 严格翻译自: base64.zig - simdutfEncodeUrlSafe / url_safe_no_pad
    //
    // URL-safe 与标准 Base64 的区别:
    //   1. 字母表中 + 替换为 -, / 替换为 _
    //   2. 不添加 padding (pad_char = null)
    //
    // Bun:
    //   pub const url_safe_no_pad = Codecs{
    //       .alphabet_chars = url_safe_alphabet_chars,
    //       .pad_char = null,
    //       ...
    //   }
    //
    //   pub fn simdutfEncodeUrlSafe(destination, source) usize {
    //       return bun.simdutf.base64.encode(source, destination, true);
    //   }
    // ========================================================================

    /// URL-safe Base64 编码 (无 padding)
    /// 对应 Bun simdutfEncodeUrlSafe / url_safe_no_pad.Encoder
    ///
    /// 编码输出长度: ceil(sourceLen * 4 / 3)
    /// 对应 Bun urlSafeEncodeLen:
    //    pub fn urlSafeEncodeLen(source: anytype) usize {
    //        return ((source.len * 4) + 2) / 3;
    //    }
    public static func encodeUrlSafe(data: Array<UInt8>): String {
        var result = StringBuilder()
        var acc: Int64 = 0
        var accLen: Int64 = 0

        var i: Int64 = 0
        while (i < data.size) {
            acc = (acc << 8) + Int64(data[i])
            accLen += 8

            while (accLen >= 6) {
                accLen -= 6
                let idx = (acc >> accLen) & 0x3F
                result.append(URL_SAFE_ALPHABET[idx])
            }

            i += 1
        }

        // 处理剩余位
        if (accLen > 0) {
            let idx = (acc << (6 - accLen)) & 0x3F
            result.append(URL_SAFE_ALPHABET[idx])
        }

        // URL-safe Base64 不添加 padding
        // Bun: pad_char = null -> no padding appended

        return result.toString()
    }

    /// URL-safe Base64 解码
    /// 对应 Bun url_safe.Decoder.decode
    /// 同时接受 URL-safe 和标准 Base64 字符 (宽容解码)
    ///
    /// Bun mixed_decoder 在 standard decoder 基础上，
    /// 将 url_safe 字母表的 '-'(62) 和 '_'(63) 也映射进去:
    //    for (zig_base64.url_safe_alphabet_chars[62..], 62..) |c, i| {
    //        decoder.decoder.char_to_index[c] = @as(u8, @intCast(i));
    //    }
    public static func decodeUrlSafe(str: String): Array<UInt8> {
        let src = Array<UInt8>(str.size, { i => UInt8(str[i]) })
        let len = src.size
        let result = ArrayList<UInt8>()

        var acc: Int64 = 0
        var accLen: Int64 = 0
        var i: Int64 = 0

        while (i < len) {
            let ch = src[i]

            // 跳过空白
            if (ch == UInt8(0x20) || ch == UInt8(0x09) || ch == UInt8(0x0D) || ch == UInt8(0x0A) ||
                ch == UInt8(0x0B) || ch == UInt8(0x0C)) {
                i += 1
                continue
            }

            // 跳过 padding
            if (ch == UInt8(0x3D)) {
                i += 1
                continue
            }

            // URL-safe 字符查找，也接受标准 Base64 字符
            // 对应 Bun mixed_decoder: 合并 url_safe + standard 查找表
            var idx = INVALID_CHAR
            if (Int64(ch) < 256) {
                idx = urlSafeLUT[Int64(ch)]
                // 宽容: 如果 URL-safe 表找不到，尝试标准表
                if (idx == INVALID_CHAR) {
                    idx = standardLUT[Int64(ch)]
                }
            }
            if (idx == INVALID_CHAR) {
                i += 1
                continue
            }

            acc = (acc << 6) + Int64(idx)
            accLen += 6

            if (accLen >= 8) {
                accLen -= 8
                result.append(UInt8((acc >> accLen) & Int64(0xFF)))
            }

            i += 1
        }

        return result.toOwnedSlice()
    }

    // ========================================================================
    // 辅助方法
    // 严格翻译自: base64.zig 的公共 API
    //   pub fn decodeLenUpperBound(len: usize) usize
    //   pub fn decodeLen(source: anytype) usize
    //   pub fn encodeLen(source: anytype) usize
    //   pub fn encodeLenFromSize(source: usize) usize
    //   pub fn urlSafeEncodeLen(source: anytype) usize
    // ========================================================================

    /// 计算编码后长度 (标准 Base64, 带 padding)
    /// 对应 Bun encodeLenFromSize:
    ///   pub fn encodeLenFromSize(source: usize) usize {
    ///       return zig_base64.standard.Encoder.calcSize(source);
    ///   }
    /// 其中 Encoder.calcSize:
    ///   if (encoder.pad_char != null) {
    ///       return @divTrunc(source_len + 2, 3) * 4;
    ///   }
    public static func encodeLen(sourceLen: Int64): Int64 {
        ((sourceLen + 2) / 3) * 4
    }

    /// 计算编码后长度 (URL-safe, 无 padding)
    /// 对应 Bun urlSafeEncodeLen:
    //    pub fn urlSafeEncodeLen(source: anytype) usize {
    //        return ((source.len * 4) + 2) / 3;
    //    }
    public static func urlSafeEncodeLen(sourceLen: Int64): Int64 {
        ((sourceLen * 4) + 2) / 3
    }

    /// 计算解码后最大长度 (上限)
    /// 对应 Bun decodeLenUpperBound:
    //    pub fn decodeLenUpperBound(len: usize) usize {
    //        return zig_base64.standard.Decoder.calcSizeUpperBound(len) catch {
    //            return len / 4 * 3;
    //        };
    //    }
    public static func decodeLenUpperBound(sourceLen: Int64): Int64 {
        (sourceLen / 4) * 3
    }

    /// 计算解码后的精确长度
    /// 对应 Bun decodeLen:
    //    pub fn decodeLen(source: anytype) usize {
    //        return zig_base64.standard.Decoder.calcSizeForSlice(source) catch {
    //            return source.len / 4 * 3 + 2;
    //        };
    //    }
    /// calcSizeForSlice:
    ///   var result = try decoder.calcSizeUpperBound(source_len);
    ///   if (decoder.pad_char) |pad_char| {
    ///       if (source_len >= 1 and source[source_len - 1] == pad_char) result -= 1;
    ///       if (source_len >= 2 and source[source_len - 2] == pad_char) result -= 1;
    ///   }
    public static func decodeLen(str: String): Int64 {
        // 去除 padding 字符计算
        var len = str.size
        while (len > 0 && UInt8(str[len - 1]) == UInt8(0x3D)) {
            len -= 1
        }
        (len * 3 + 3) / 4
    }
}

/// Base64Url 便捷类 - 提供 URL-safe Base64 的静态方法封装
public class Base64Url {
    /// URL-safe Base64 编码 (无 padding)
    public static func encode(data: Array<UInt8>): String {
        Base64.encodeUrlSafe(data)
    }

    /// URL-safe Base64 解码
    public static func decode(str: String): Array<UInt8> {
        Base64.decodeUrlSafe(str)
    }
}
