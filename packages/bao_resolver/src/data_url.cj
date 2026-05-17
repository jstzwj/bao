// 严格翻译自: src/resolver/data_url.zig
// data: URL 解析与编解码
package bao_resolver

import bao_core.*
import bao_collections.*
import bao_io.*

// ============================================================================
// DataURL — data: URL 解析
// 严格翻译自: src/resolver/data_url.zig - DataURL / PercentEncoding
// 对应 Bun: 解析 "data:" 前缀的 URL，支持 MIME 类型和 base64 编码
//
// data: URL 格式:
//   data:[<mediatype>][;base64],<data>
// 例如:
//   data:text/plain;charset=UTF-8,Hello%20World
//   data:text/plain;base64,SGVsbG8gV29ybGQ=
// ============================================================================

/// data: URL 解析错误
/// 对应 Bun: PercentEncoding.EncodeError / DataURL 解析错误
public enum DataUrlError {
    | InvalidCharacter     // 非法字符
    | OutOfMemory          // 内存不足
    | InvalidDataUrl       // 无效的 data URL 格式
    | Base64DecodeError    // Base64 解码失败
}

// ============================================================================
// PercentEncoding — 百分号编码/解码
// 严格翻译自: data_url.zig 中的 PercentEncoding struct
// 对应 Bun: URL 百分号编码处理 (RFC 3986)
// 参考: https://github.com/Vexu/zuri/blob/master/src/zuri.zig#L61-L127
// ============================================================================

/// 百分号编码工具
/// 对应 Bun: PercentEncoding
public class PercentEncoding {
    /// 判断字符是否为十六进制数字
    // 对应 Bun: isHex(c)
    public static func isHex(c: UInt8): Bool {
        return (c >= UInt8(48) && c <= UInt8(57)) ||
               (c >= UInt8(97) && c <= UInt8(102)) ||
               (c >= UInt8(65) && c <= UInt8(70))
    }

    /// 判断是否为有效的路径字符或百分号编码八位组
    // 对应 Bun: isPchar(str)
    // 路径字符: a-z A-Z 0-9 - . _ ~ ! $ & ' ( ) * + , ; = : @
    public static func isPchar(str: String, offset: Int64): Bool {
        if (offset >= Int64(str.size)) { return false }
        let c = str[offset]

        // 允许的未编码字符
        if ((c >= UInt8(97) && c <= UInt8(122)) || (c >= UInt8(65) && c <= UInt8(90)) ||
            (c >= UInt8(48) && c <= UInt8(57)) ||
            c == UInt8(45) || c == UInt8(46) || c == UInt8(95) || c == UInt8(126) ||
            c == UInt8(33) || c == UInt8(36) || c == UInt8(38) || c == UInt8(39) ||
            c == UInt8(40) || c == UInt8(41) || c == UInt8(42) || c == UInt8(43) ||
            c == UInt8(44) || c == UInt8(59) || c == UInt8(61) || c == UInt8(58) || c == UInt8(64)) {
            return true
        }

        // 百分号编码: %XX (两个十六进制数字)
        if (c == UInt8(37)) {
            if (Int64(str.size) - offset < 3) { return false }
            return isHex(str[offset + 1]) && isHex(str[offset + 2])
        }

        return false
    }

    /// 十六进制字符转数值
    private static func hexDigit(c: UInt8): Int64 {
        if (c >= UInt8(48) && c <= UInt8(57)) {
            return Int64(c) - Int64(UInt8(48))
        }
        if (c >= UInt8(97) && c <= UInt8(102)) {
            return Int64(c) - Int64(UInt8(97)) + 10
        }
        if (c >= UInt8(65) && c <= UInt8(70)) {
            return Int64(c) - Int64(UInt8(65)) + 10
        }
        return 0
    }

    /// 解码百分号编码字符串
    // 对应 Bun: PercentEncoding.decode(allocator, path)
    // strict=true 时遇到非编码的 URL 不安全字符会报错
    public static func decode(path: String): String {
        return decodeImpl(path, true)
    }

    /// 宽松解码 (不因 URL 不安全字符报错)
    // 对应 Bun: PercentEncoding.decodeUnstrict(allocator, path)
    public static func decodeUnstrict(path: String): String {
        return decodeImpl(path, false)
    }

    /// 内部解码实现
    // 对应 Bun: _decode(allocator, path, strict)
    private static func decodeImpl(path: String, strict: Bool): String {
        let sb = StringBuilder()
        var i: Int64 = 0

        while (i < Int64(path.size)) {
            let c = path[i]
            if (c == UInt8(37) && Int64(path.size) - i >= 3 &&
                isHex(path[i + 1]) && isHex(path[i + 2])) {
                // 解码 %XX
                let hi = hexDigit(path[i + 1])
                let lo = hexDigit(path[i + 2])
                let decoded = hi << 4 | lo
                sb.append(UInt8(decoded))
                i += 3
            } else if (strict && c != UInt8(47) && !isPchar(path, i)) {
                // strict 模式下遇到非法字符返回原字符串
                return path
            } else {
                sb.append(c)
                i += 1
            }
        }

        return sb.toString()
    }
}

// ============================================================================
// DataURL — data: URL 结构
// 严格翻译自: data_url.zig 中的 DataURL struct
// 对应 Bun: data: URL 解析结果
// ============================================================================

/// data: URL 解析结果
/// 对应 Bun: DataURL struct
public class DataURL {
    /// 原始 URL 字符串
    // 对应 Bun: url: bun.String
    public var url: String

    /// MIME 类型 (不含 ;base64 后缀)
    // 对应 Bun: mime_type: string
    public var mimeType: String

    /// 数据部分 (逗号后的内容)
    // 对应 Bun: data: string
    public var data: String

    /// 是否为 base64 编码
    // 对应 Bun: is_base64: bool
    public var isBase64: Bool

    public init() {
        url = ""
        mimeType = ""
        data = ""
        isBase64 = false
    }

    /// 解析 data: URL
    // 对应 Bun: DataURL.parse(url)
    // 返回 None 表示不是 data URL，抛出异常表示格式错误
    public static func parse(url: String): ?DataURL {
        if (!url.startsWith("data:")) {
            return None
        }
        return parseWithoutCheck(url)
    }

    /// 跳过前缀检查的解析
    // 对应 Bun: DataURL.parseWithoutCheck(url)
    public static func parseWithoutCheck(url: String): ?DataURL {
        // 查找逗号分隔符
        let commaIndexOpt = url.indexOf(",")
        if (let Some(commaIndex) <- commaIndexOpt) {
            let parsed = DataURL()
            parsed.url = url
            parsed.mimeType = url[Int64(5)..commaIndex]  // "data:".length == 5
            parsed.data = url[commaIndex + Int64(1)..Int64(url.size)]

            // 检测 base64 编码
            if (parsed.mimeType.endsWith(";base64")) {
                parsed.mimeType = parsed.mimeType[Int64(0)..Int64(parsed.mimeType.size - 7)]  // ";base64".length == 7
                parsed.isBase64 = true
            }

            return parsed
        }
        return None
    }

    /// 解码 MIME 类型
    // 对应 Bun: DataURL.decodeMimeType()
    public func decodeMimeType(): String {
        // 简化实现: 返回原始 MIME 类型字符串
        // Bun 中使用 bun.http.MimeType.init() 解析
        return mimeType
    }

    /// 解码 data: URL 中的数据
    // 对应 Bun: DataURL.decodeData(url, allocator)
    // 如果是 base64 编码则先解码 base64，否则解码百分号编码
    public func decodeData(): String {
        // 先进行百分号解码
        let percentDecoded = PercentEncoding.decodeUnstrict(data)

        if (isBase64) {
            // Base64 解码
            return decodeBase64(percentDecoded)
        }

        return percentDecoded
    }

    /// 将字符串编码为最短的 data URL (base64 或百分号编码)
    // 对应 Bun: DataURL.encodeStringAsShortestDataURL(allocator, mime_type, text)
    public static func encodeAsShortestDataURL(
        mimeType: String,
        text: String
    ): String {
        // 计算 base64 版本长度
        let base64Len = encodeBase64Length(Int64(text.size))
        let totalBase64Len = Int64(5) + Int64(mimeType.size) + Int64(8) + base64Len  // "data:" + mime + ";base64," + data

        // 计算百分号编码版本长度
        let percentLen = percentEncodeLength(text)
        let totalPercentLen = Int64(5) + Int64(mimeType.size) + Int64(1) + percentLen  // "data:" + mime + "," + data

        // 选择较短的
        if (totalPercentLen <= totalBase64Len) {
            let sb = StringBuilder()
            sb.append("data:")
            sb.append(mimeType)
            sb.append(',')
            sb.append(percentEncode(text))
            return sb.toString()
        }

        // 使用 base64
        let sb = StringBuilder()
        sb.append("data:")
        sb.append(mimeType)
        sb.append(";base64,")
        sb.append(encodeBase64(text))
        return sb.toString()
    }

    // ------------------------------------------------------------------
    // Base64 编解码 (简化实现)
    // 对应 Bun: bun.base64.decode / encode
    // ------------------------------------------------------------------

    /// Base64 字母表
    private static let BASE64_CHARS: String =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    /// Base64 解码
    private static func decodeBase64(input: String): String {
        let sb = StringBuilder()
        var i: Int64 = 0
        let chars = input

        while (i + 3 < Int64(chars.size)) {
            let a = base64Value(chars[i])
            let b = base64Value(chars[i + 1])
            let c = base64Value(chars[i + 2])
            let d = base64Value(chars[i + 3])
            sb.append(UInt8((a << 2) | (b >> 4)))
            if (chars[i + 2] != UInt8(61)) {
                sb.append(UInt8(((b & 0xF) << 4) | (c >> 2)))
            }
            if (chars[i + 3] != UInt8(61)) {
                sb.append(UInt8(((c & 0x3) << 6) | d))
            }
            i += 4
        }
        return sb.toString()
    }

    /// Base64 编码
    private static func encodeBase64(input: String): String {
        let sb = StringBuilder()
        var i: Int64 = 0
        while (i + 2 < Int64(input.size)) {
            let a = Int64(input[i])
            let b = Int64(input[i + 1])
            let c = Int64(input[i + 2])
            sb.append(BASE64_CHARS[(a >> 2) & 0x3F])
            sb.append(BASE64_CHARS[((a << 4) | (b >> 4)) & 0x3F])
            sb.append(BASE64_CHARS[((b << 2) | (c >> 6)) & 0x3F])
            sb.append(BASE64_CHARS[c & 0x3F])
            i += 3
        }
        // 处理剩余字符
        if (i < Int64(input.size)) {
            let a = Int64(input[i])
            sb.append(BASE64_CHARS[(a >> 2) & 0x3F])
            if (i + 1 < Int64(input.size)) {
                let b = Int64(input[i + 1])
                sb.append(BASE64_CHARS[((a << 4) | (b >> 4)) & 0x3F])
                sb.append(BASE64_CHARS[(b << 2) & 0x3F])
            } else {
                sb.append(BASE64_CHARS[(a << 4) & 0x3F])
                sb.append('=')
            }
            sb.append('=')
        }
        return sb.toString()
    }

    /// Base64 编码后长度
    private static func encodeBase64Length(inputLen: Int64): Int64 {
        return ((inputLen + 2) / 3) * 4
    }

    /// Base64 字符值
    private static func base64Value(c: UInt8): Int64 {
        if (c >= UInt8(65) && c <= UInt8(90)) { return Int64(c) - Int64(UInt8(65)) }
        if (c >= UInt8(97) && c <= UInt8(122)) { return Int64(c) - Int64(UInt8(97)) + 26 }
        if (c >= UInt8(48) && c <= UInt8(57)) { return Int64(c) - Int64(UInt8(48)) + 52 }
        if (c == UInt8(43)) { return 62 }
        if (c == UInt8(47)) { return 63 }
        return 0
    }

    // ------------------------------------------------------------------
    // 百分号编码
    // 对应 Bun: DataURL.encodeStringAsPercentEscapedDataURL
    // ------------------------------------------------------------------

    /// 百分号编码
    private static func percentEncode(text: String): String {
        let hex = "0123456789ABCDEF"
        let sb = StringBuilder()

        // 找到尾部需要编码的字符的起始位置
        var trailingStart: Int64 = Int64(text.size)
        while (trailingStart > 0) {
            let c = text[trailingStart - 1]
            if (c > UInt8(32) || c == UInt8(9) || c == UInt8(10) || c == UInt8(13)) {
                break
            }
            trailingStart -= 1
        }

        var i: Int64 = 0
        while (i < Int64(text.size)) {
            let c = text[i]
            // 判断是否需要编码
            var needsEscape = false
            if (c == UInt8(9) || c == UInt8(10) || c == UInt8(13) || c == UInt8(35)) {
                needsEscape = true
            } else if (i >= trailingStart) {
                needsEscape = true
            } else if (c == UInt8(37) && i + 2 < Int64(text.size) &&
                       PercentEncoding.isHex(UInt8(c)) &&
                       PercentEncoding.isHex(UInt8(text[i + 2]))) {
                needsEscape = true
            }

            if (needsEscape) {
                let byte = Int64(c)
                sb.append('%')
                sb.append(hex[(byte >> 4) & 0xF])
                sb.append(hex[byte & 0xF])
            } else {
                sb.append(c)
            }
            i += 1
        }

        return sb.toString()
    }

    /// 估算百分号编码后的长度
    private static func percentEncodeLength(text: String): Int64 {
        // 最坏情况: 每个字符编码为 3 个字符 (%XX)
        return Int64(text.size) * 3
    }
}
