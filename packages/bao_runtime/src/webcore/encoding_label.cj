// EncodingLabel - 编码标签
// 对应 Bun: src/runtime/webcore/EncodingLabel.zig
// 严格翻译自: src/runtime/webcore/EncodingLabel.zig
package bao_runtime

import bao_core.*

// ============================================================================
// EncodingLabel - 编码标签
// 对应 Bun: src/runtime/webcore/EncodingLabel.zig EncodingLabel
// 参考: https://encoding.spec.whatwg.org/encodings.json
// ============================================================================

/// EncodingLabel — 编码标签枚举
/// 对应 Bun: EncodingLabel
/// 参考: WHATWG Encoding Standard
public enum EncodingLabel {
    | UTF8               // "UTF-8"
    | IBM866             // "IBM866"
    | ISO88593           // "ISO-8859-3"
    | ISO88596           // "ISO-8859-6"
    | ISO88597           // "ISO-8859-7"
    | ISO88598           // "ISO-8859-8"
    | ISO88598I          // "ISO-8859-8-I"
    | KOI8U              // "KOI8-U"
    | Windows874         // "windows-874"
    | Windows1252        // "windows-1252" (Latin1/ASCII)
    | Windows1253        // "windows-1253"
    | Windows1255        // "windows-1255"
    | Windows1257        // "windows-1257"
    | Big5               // "Big5"
    | EUCJP              // "EUC-JP"
    | ISO2022JP          // "ISO-2022-JP"
    | ShiftJIS           // "Shift_JIS"
    | EUCKR              // "EUC-KR"
    | UTF16BE            // "UTF-16BE"
    | UTF16LE            // "UTF-16LE"
    | XUserDefined       // "x-user-defined"
    | Replacement        // "replacement"
    | GBK                // "GBK"
    | GB18030            // "GB18030"

    /// Latin1 别名
    public static let latin1 = EncodingLabel.Windows1252

    /// 获取标签字符串
    /// 对应 Bun: EncodingLabel.getLabel()
    public func getLabel(): String {
        match (this) {
            case UTF8 => "utf-8"
            case UTF16LE => "utf-16le"
            case UTF16BE => "utf-16be"
            case Windows1252 => "windows-1252"
            case IBM866 => "ibm866"
            case ISO88593 => "iso-8859-3"
            case ISO88596 => "iso-8859-6"
            case ISO88597 => "iso-8859-7"
            case ISO88598 => "iso-8859-8"
            case ISO88598I => "iso-8859-8-i"
            case KOI8U => "koi8-u"
            case Windows874 => "windows-874"
            case Windows1253 => "windows-1253"
            case Windows1255 => "windows-1255"
            case Windows1257 => "windows-1257"
            case Big5 => "big5"
            case EUCJP => "euc-jp"
            case ISO2022JP => "iso-2022-jp"
            case ShiftJIS => "shift_jis"
            case EUCKR => "euc-kr"
            case XUserDefined => "x-user-defined"
            case Replacement => "replacement"
            case GBK => "gbk"
            case GB18030 => "gb18030"
        }
    }

    /// 从字符串解析编码标签
    /// 对应 Bun: EncodingLabel string_map 查找
    public static func fromString(label: String): ?EncodingLabel {
        let lower = label.toLowerCase().trim()

        // UTF-8 别名
        if (lower == "utf-8" || lower == "utf8" || lower == "unicode11utf8" ||
            lower == "unicode20utf8" || lower == "x-unicode20utf8" || lower == "unicode-1-1-utf-8") {
            return Some(EncodingLabel.UTF8)
        }

        // UTF-16LE 别名
        if (lower == "utf-16le" || lower == "utf-16" || lower == "ucs-2" ||
            lower == "unicode" || lower == "unicodefeff" || lower == "csunicode" ||
            lower == "iso-10646-ucs-2") {
            return Some(EncodingLabel.UTF16LE)
        }

        // UTF-16BE 别名
        if (lower == "utf-16be") {
            return Some(EncodingLabel.UTF16BE)
        }

        // Latin1 / ASCII 别名 (windows-1252)
        if (lower == "windows-1252" || lower == "latin1" || lower == "latin-1" ||
            lower == "l1" || lower == "ascii" || lower == "us-ascii" ||
            lower == "cp819" || lower == "cp1252" || lower == "ibm819" ||
            lower == "iso88591" || lower == "iso8859-1" || lower == "iso_8859-1" ||
            lower == "iso-8859-1" || lower == "iso-ir-100" || lower == "csisolatin1" ||
            lower == "x-cp1252" || lower == "ansi_x3.4-1968" || lower == "iso_8859-1:1987") {
            return Some(EncodingLabel.Windows1252)
        }

        // 其他编码
        if (lower == "ibm866") { return Some(EncodingLabel.IBM866) }
        if (lower == "iso-8859-3") { return Some(EncodingLabel.ISO88593) }
        if (lower == "iso-8859-6") { return Some(EncodingLabel.ISO88596) }
        if (lower == "iso-8859-7") { return Some(EncodingLabel.ISO88597) }
        if (lower == "iso-8859-8") { return Some(EncodingLabel.ISO88598) }
        if (lower == "iso-8859-8-i") { return Some(EncodingLabel.ISO88598I) }
        if (lower == "koi8-u") { return Some(EncodingLabel.KOI8U) }
        if (lower == "windows-874") { return Some(EncodingLabel.Windows874) }
        if (lower == "windows-1253") { return Some(EncodingLabel.Windows1253) }
        if (lower == "windows-1255") { return Some(EncodingLabel.Windows1255) }
        if (lower == "windows-1257") { return Some(EncodingLabel.Windows1257) }
        if (lower == "big5") { return Some(EncodingLabel.Big5) }
        if (lower == "euc-jp") { return Some(EncodingLabel.EUCJP) }
        if (lower == "iso-2022-jp") { return Some(EncodingLabel.ISO2022JP) }
        if (lower == "shift_jis") { return Some(EncodingLabel.ShiftJIS) }
        if (lower == "euc-kr") { return Some(EncodingLabel.EUCKR) }
        if (lower == "x-user-defined") { return Some(EncodingLabel.XUserDefined) }
        if (lower == "replacement") { return Some(EncodingLabel.Replacement) }
        if (lower == "gbk") { return Some(EncodingLabel.GBK) }
        if (lower == "gb18030") { return Some(EncodingLabel.GB18030) }

        return None
    }
}

// ============================================================================
// EncodingLabel 工具类
// ============================================================================

/// EncodingLabel 工具类
public class EncodingLabelHelper {
    /// 获取规范化编码名称
    /// 对应 Bun: EncodingLabel 查找并返回标签
    public static func getCanonical(label: String): ?String {
        let result = EncodingLabel.fromString(label)
        match (result) {
            case Some(enc) => Some(enc.getLabel())
            case None => None
        }
    }
}
