// EncodingLabel - 编码标签
// 对应 Bun: src/runtime/webcore/EncodingLabel.zig
// 严格翻译自: src/runtime/webcore/EncodingLabel.zig
package bao_runtime.webcore

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
    /// 对应 Bun: EncodingLabel.string_map (ComptimeStringMap, case-insensitive)
    /// 严格翻译自 EncodingLabel.zig string_map 全部条目
    public static func fromString(label: String): ?EncodingLabel {
        let lower = label.toAsciiLower().trimAscii()

        // ── Windows-1252 (Latin1) aliases ──
        // 对应 Bun: string_map "l1" ... "iso_8859-1:1987"
        if (lower == "l1" || lower == "ascii" || lower == "cp819" ||
            lower == "cp1252" || lower == "ibm819" || lower == "latin1" ||
            lower == "iso88591" || lower == "us-ascii" || lower == "x-cp1252" ||
            lower == "iso8859-1" || lower == "iso_8859-1" || lower == "iso-8859-1" ||
            lower == "iso-ir-100" || lower == "csisolatin1" || lower == "windows-1252" ||
            lower == "ansi_x3.4-1968" || lower == "iso_8859-1:1987") {
            return Some(EncodingLabel.Windows1252)
        }

        // ── UTF-16LE aliases ──
        if (lower == "ucs-2" || lower == "utf-16" || lower == "unicode" ||
            lower == "utf-16le" || lower == "csunicode" || lower == "unicodefeff" ||
            lower == "iso-10646-ucs-2") {
            return Some(EncodingLabel.UTF16LE)
        }

        // ── UTF-16BE aliases ──
        if (lower == "utf-16be") {
            return Some(EncodingLabel.UTF16BE)
        }

        // ── UTF-8 aliases ──
        if (lower == "utf8" || lower == "utf-8" || lower == "unicode11utf8" ||
            lower == "unicode20utf8" || lower == "x-unicode20utf8" ||
            lower == "unicode-1-1-utf-8") {
            return Some(EncodingLabel.UTF8)
        }

        // ── IBM866 aliases ──
        if (lower == "ibm866" || lower == "cp866" || lower == "866" ||
            lower == "csibm866") {
            return Some(EncodingLabel.IBM866)
        }

        // ── ISO-8859-3 aliases ──
        if (lower == "iso-8859-3" || lower == "iso8859-3" || lower == "iso_8859-3" ||
            lower == "latin3" || lower == "csisolatin3" || lower == "iso-ir-109" ||
            lower == "l3") {
            return Some(EncodingLabel.ISO88593)
        }

        // ── ISO-8859-6 aliases ──
        if (lower == "iso-8859-6" || lower == "iso8859-6" || lower == "iso_8859-6" ||
            lower == "arabic" || lower == "csisolatinarabic" || lower == "iso-ir-127" ||
            lower == "asmo-708" || lower == "ecma-114") {
            return Some(EncodingLabel.ISO88596)
        }

        // ── ISO-8859-7 aliases ──
        if (lower == "iso-8859-7" || lower == "iso8859-7" || lower == "iso_8859-7" ||
            lower == "greek" || lower == "greek8" || lower == "csisolatingreek" ||
            lower == "iso-ir-126" || lower == "ecma-118" || lower == "elot_928") {
            return Some(EncodingLabel.ISO88597)
        }

        // ── ISO-8859-8 aliases ──
        if (lower == "iso-8859-8" || lower == "iso8859-8" || lower == "iso_8859-8" ||
            lower == "hebrew" || lower == "csisolatinhebrew" || lower == "iso-ir-138" ||
            lower == "visual") {
            return Some(EncodingLabel.ISO88598)
        }

        // ── ISO-8859-8-I aliases ──
        if (lower == "iso-8859-8-i" || lower == "logical" || lower == "csiso88598i") {
            return Some(EncodingLabel.ISO88598I)
        }

        // ── KOI8-U aliases ──
        if (lower == "koi8-u" || lower == "koi8-ru") {
            return Some(EncodingLabel.KOI8U)
        }

        // ── Windows-874 aliases ──
        if (lower == "windows-874" || lower == "dos-874" || lower == "iso-8859-11" ||
            lower == "iso8859-11" || lower == "iso885911" || lower == "iso_8859-11" ||
            lower == "tis-620") {
            return Some(EncodingLabel.Windows874)
        }

        // ── Windows-1253 aliases ──
        if (lower == "windows-1253" || lower == "cp1253" || lower == "x-cp1253") {
            return Some(EncodingLabel.Windows1253)
        }

        // ── Windows-1255 aliases ──
        if (lower == "windows-1255" || lower == "cp1255" || lower == "x-cp1255") {
            return Some(EncodingLabel.Windows1255)
        }

        // ── Windows-1257 aliases ──
        if (lower == "windows-1257" || lower == "cp1257" || lower == "x-cp1257") {
            return Some(EncodingLabel.Windows1257)
        }

        // ── Big5 aliases ──
        if (lower == "big5" || lower == "big5-hkscs" || lower == "cn-big5" ||
            lower == "csbig5" || lower == "x-x-big5") {
            return Some(EncodingLabel.Big5)
        }

        // ── EUC-JP aliases ──
        if (lower == "euc-jp" || lower == "cseucpkdfmtjapanese" || lower == "x-euc-jp") {
            return Some(EncodingLabel.EUCJP)
        }

        // ── ISO-2022-JP aliases ──
        if (lower == "iso-2022-jp" || lower == "csiso2022jp") {
            return Some(EncodingLabel.ISO2022JP)
        }

        // ── Shift_JIS aliases ──
        if (lower == "shift_jis" || lower == "shift-jis" || lower == "sjis" ||
            lower == "csshiftjis" || lower == "ms932" || lower == "ms_kanji" ||
            lower == "windows-31j" || lower == "x-sjis") {
            return Some(EncodingLabel.ShiftJIS)
        }

        // ── EUC-KR aliases ──
        if (lower == "euc-kr" || lower == "cseuckr" || lower == "csksc56011987" ||
            lower == "iso-ir-149" || lower == "korean" || lower == "ks_c_5601-1987" ||
            lower == "ks_c_5601-1989" || lower == "ksc5601" || lower == "ksc_5601" ||
            lower == "windows-949") {
            return Some(EncodingLabel.EUCKR)
        }

        // ── GBK aliases ──
        if (lower == "gbk" || lower == "gb2312" || lower == "chinese" ||
            lower == "csgb2312" || lower == "csiso58gb231280" || lower == "gb_2312" ||
            lower == "gb_2312-80" || lower == "iso-ir-58" || lower == "x-gbk") {
            return Some(EncodingLabel.GBK)
        }

        // ── GB18030 ──
        if (lower == "gb18030") {
            return Some(EncodingLabel.GB18030)
        }

        // ── Other ──
        if (lower == "x-user-defined") {
            return Some(EncodingLabel.XUserDefined)
        }
        if (lower == "replacement") {
            return Some(EncodingLabel.Replacement)
        }

        return None
    }
}

/// Latin1 别名 (cannot be inside enum in Cangjie)
public let latin1 = EncodingLabel.Windows1252

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
