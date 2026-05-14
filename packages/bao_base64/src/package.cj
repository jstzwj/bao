// bao_base64 - Base64 编码/解码
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
    public static let PAD_CHAR: UInt8 = '='.toUInt8()

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
        var lut = Array<UInt8>(256, item: INVALID_CHAR)
        for (i in 0..64) {
            lut[alphabet[i].toUInt8()] = UInt8(i)
        }
        return lut
    }

    // ========================================================================
    // encode - Base64 编码
    // 严格翻译自: Base64Encoder.encode / encodeWithoutSizeCheck
    //   pub fn encode(encoder, dest: []u8, source: []const u8) []const u8 {
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
    //   }
    //
    // 编码原理:
    //   - 每 3 字节 (24 位) 编码为 4 个 Base64 字符 (每字符 6 位)
    //   - 不足 3 字节时用 padding (=) 补齐
    //   - 1 字节 -> 2 字符 + "=="
    //   - 2 字节 -> 3 字符 + "="
    //   - 3 字节 -> 4 字符
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
        var acc = 0      // 累加器 (最多 12 位)
        var accLen = 0   // 累加器中的有效位数

        var i = 0
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
        let encodedLen = result.length
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
    // 严格翻译自: Base64Decoder.decode
    //   pub fn decode(decoder, dest: []u8, source: []const u8) Error!void {
    //       if (decoder.pad_char != null and source.len % 4 != 0) return error.InvalidPadding;
    //       var acc: u12 = 0;
    //       var acc_len: u4 = 0;
    //       var dest_idx: usize = 0;
    //       for (source, 0..) |c, src_idx| {
    //           const d = decoder.char_to_index[c];
    //           if (d == invalid_char) {
    //               if (pad_char == null or c != pad_char.?) return error.InvalidCharacter;
    //               leftover_idx = src_idx; break;
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
    //
    // 解码原理:
    //   - 每 4 个 Base64 字符 (24 位) 解码为 3 字节
    //   - Padding 字符 (=) 表示缺少的字节
    //   - 宽容解码: 忽略空白字符
    // ========================================================================

    /// 标准 Base64 解码
    /// 对应 Bun Base64Decoder.decode (standard)
    ///
    /// 支持宽容解码 - 对应 Bun mixed_decoder
    /// 忽略空白字符: 空格、Tab、\r、\n、VT、FF
    public static func decode(str: String): Array<UInt8> {
        let src = str.toCharArray()
        let len = src.size
        let result = ArrayList<UInt8>()

        // 预计算解码长度 - 对应 Bun decodeLen
        // Bun: source.len / 4 * 3 + 2
        var acc = 0
        var accLen = 0
        var i = 0

        while (i < len) {
            let ch = src[i]

            // 宽容解码: 跳过空白字符
            // 对应 Bun Base64DecoderWithIgnore.char_is_ignored
            if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' ||
                ch == '\u{0B}' || ch == '\u{0C}') {
                i += 1
                continue
            }

            // Padding 字符处理
            if (ch == '='.toUInt8()) {
                // 跳过剩余 padding
                i += 1
                while (i < len) {
                    let pch = src[i]
                    if (pch != '='.toUInt8() && pch != ' ' && pch != '\t' &&
                        pch != '\r' && pch != '\n') {
                        break  // 非法字符在 padding 后
                    }
                    i += 1
                }
                continue
            }

            // 查找字符索引
            let idx = if (ch.toUInt8() < 256) { standardLUT[ch.toUInt8()] } else { INVALID_CHAR }
            if (idx == INVALID_CHAR) {
                i += 1
                continue  // 跳过非法字符
            }

            // 累加 6 位
            // Bun: acc = (acc << 6) + d; acc_len += 6;
            acc = (acc << 6) + Int64(idx)
            accLen += 6

            // 提取完整字节
            // Bun: if (acc_len >= 8) { acc_len -= 8; dest[dest_idx] = truncate(acc >> acc_len); }
            if (accLen >= 8) {
                accLen -= 8
                result.append(UInt8((acc >> accLen) & 0xFF))
            }

            i += 1
        }

        return result.toArray()
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
    ///   return ((source.len * 4) + 2) / 3
    public static func encodeUrlSafe(data: Array<UInt8>): String {
        var result = StringBuilder()
        var acc = 0
        var accLen = 0

        var i = 0
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
    public static func decodeUrlSafe(str: String): Array<UInt8> {
        let src = str.toCharArray()
        let len = src.size
        let result = ArrayList<UInt8>()

        var acc = 0
        var accLen = 0
        var i = 0

        while (i < len) {
            let ch = src[i]

            // 跳过空白
            if (ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n' ||
                ch == '\u{0B}' || ch == '\u{0C}') {
                i += 1
                continue
            }

            // 跳过 padding
            if (ch == '='.toUInt8()) {
                i += 1
                continue
            }

            // URL-safe 字符查找，也接受标准 Base64 字符
            // 对应 Bun mixed_decoder: 合并 url_safe + standard 查找表
            var idx = INVALID_CHAR
            if (ch.toUInt8() < 256) {
                idx = urlSafeLUT[ch.toUInt8()]
                // 宽容: 如果 URL-safe 表找不到，尝试标准表
                if (idx == INVALID_CHAR) {
                    idx = standardLUT[ch.toUInt8()]
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
                result.append(UInt8((acc >> accLen) & 0xFF))
            }

            i += 1
        }

        return result.toArray()
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 计算编码后长度 (标准 Base64, 带 padding)
    /// 对应 Bun encodeLenFromSize:
    ///   return @divTrunc(source_len + 2, 3) * 4
    public static func encodeLen(sourceLen: Int64): Int64 {
        ((sourceLen + 2) / 3) * 4
    }

    /// 计算编码后长度 (URL-safe, 无 padding)
    /// 对应 Bun urlSafeEncodeLen:
    ///   return ((source.len * 4) + 2) / 3
    public static func urlSafeEncodeLen(sourceLen: Int64): Int64 {
        ((sourceLen * 4) + 2) / 3
    }

    /// 计算解码后最大长度 (上限)
    /// 对应 Bun decodeLenUpperBound:
    ///   return source.len / 4 * 3
    public static func decodeLenUpperBound(sourceLen: Int64): Int64 {
        (sourceLen / 4) * 3
    }

    /// 计算解码后的精确长度
    /// 对应 Bun decodeLen:
    ///   return standard.Decoder.calcSizeForSlice(source) catch source.len / 4 * 3 + 2
    public static func decodeLen(str: String): Int64 {
        // 去除 padding 字符计算
        var len = str.size
        while (len > 0 && str[len - 1] == '=') {
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
