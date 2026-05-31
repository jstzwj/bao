// EncodingSniffer - encoding detection from byte streams
// 严格翻译自: src/runtime/webcore/encoding.zig (encoding sniffer portion)
// Also references: WHATWG Encoding Standard https://encoding.spec.whatwg.org/
package bao_runtime.webcore

import bao_core.*
import bao_jsc.*
import bao_collections.ArrayList

// ============================================================================
// BOM markers (Byte Order Marks)
// ============================================================================

/// UTF-8 BOM: EF BB BF
let BOM_UTF8: Array<UInt8> = [0xEF, 0xBB, 0xBF]

/// UTF-16 Big Endian BOM: FE FF
let BOM_UTF16_BE: Array<UInt8> = [0xFE, 0xFF]

/// UTF-16 Little Endian BOM: FF FE
let BOM_UTF16_LE: Array<UInt8> = [0xFF, 0xFE]

// ============================================================================
// SniffingResult - result of encoding sniffing
// ============================================================================

/// Result of encoding sniffing
/// Corresponds to: Bun: encoding sniffer result
public enum SniffingResult {
    | Utf8         // No BOM, or UTF-8 BOM
    | Utf16Be      // Big-endian UTF-16 BOM
    | Utf16Le      // Little-endian UTF-16 BOM
    | Unknown      // Could not determine encoding
    | ContentHint(String)  // From content-type header hint

    public func toString(): String {
        match (this) {
            case Utf8 => "utf-8"
            case Utf16Be => "utf-16be"
            case Utf16Le => "utf-16le"
            case Unknown => "utf-8"  // Default fallback
            case ContentHint(hint) => hint
        }
    }
}

// ============================================================================
// EncodingSniffer - detects encoding from byte stream headers
// Corresponds to: WHATWG encoding sniffing algorithm
// Also: Bun src/runtime/webcore/encoding.zig encoding sniffer portions
// ============================================================================

/// Encoding Sniffer — detects character encoding from byte stream headers.
///
/// This implements the WHATWG encoding sniffing algorithm:
/// 1. Check for BOM (Byte Order Mark)
/// 2. Check Content-Type header for charset
/// 3. Check for prescan of byte stream
/// 4. Fallback to UTF-8
///
/// Corresponds to: Bun encoding sniffer logic in encoding.zig
public class EncodingSniffer {

    /// Detect encoding from byte BOM (Byte Order Mark)
    /// Corresponds to: WHATWG "BOM sniff" step
    public static func sniffBom(bytes: Array<UInt8>): SniffingResult {
        if (bytes.size >= 3 &&
            bytes[0] == 0xEF &&
            bytes[1] == 0xBB &&
            bytes[2] == 0xBF) {
            return SniffingResult.Utf8
        }

        if (bytes.size >= 2) {
            if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
                return SniffingResult.Utf16Be
            }
            if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
                return SniffingResult.Utf16Le
            }
        }

        return SniffingResult.Unknown
    }

    /// Detect encoding from Content-Type header value
    /// Corresponds to: WHATWG "extract character encoding from meta charset"
    /// e.g. "text/html; charset=utf-8" -> "utf-8"
    public static func sniffContentType(contentType: String): ?String {
        if (contentType.size == 0) {
            return None
        }

        let lower = contentType.toAsciiLower()
        let charsetIdx = lower.indexOf("charset=")
        if (charsetIdx.isNone()) {
            return None
        }
        let idx = charsetIdx.getOrThrow() + 8  // skip "charset="
        if (idx >= lower.size) {
            return None
        }

        // Extract the charset value
        var end = idx
        while (end < lower.size) {
            let c = lower[end]
            if (c == ';' || c == ',' || c == ' ' || c == '\t' || c == '\r' || c == '\n') {
                break
            }
            end += 1
        }

        if (end <= idx) {
            return None
        }

        var charset = lower[idx..end]

        // Strip surrounding quotes if present
        if (charset.size >= 2) {
            if ((charset[0] == '"' && charset[charset.size - 1] == '"') ||
                (charset[0] == '\'' && charset[charset.size - 1] == '\'')) {
                charset = charset[1..charset.size - 1]
            }
        }

        // Normalize encoding name
        return Some(normalizeEncoding(charset))
    }

    /// Prescan byte stream to detect encoding (simplified)
    /// Corresponds to: WHATWG "prescan a byte stream to determine its encoding"
    /// This looks for <meta charset="..."> or <meta http-equiv="Content-Type">
    public static func prescan(bytes: Array<UInt8>): ?String {
        let limit = min(Int64(bytes.size), 1024)  // Only scan first 1024 bytes
        let content = Utf8Codec.decode(bytes[0..limit])

        // Look for <meta charset="...">
        let patterns = ["charset=", "Charset=", "CHARSET="]
        for (pattern in patterns) {
            let idxOpt = content.indexOf(pattern)
            if (idxOpt.isSome()) {
                let idx = idxOpt.getOrThrow() + pattern.size
                if (idx < content.size) {
                    // Skip whitespace and quotes
                    var start = idx
                    while (start < content.size) {
                        let c = content[start]
                        if (c != ' ' && c != '\t' && c != '"' && c != '\'') {
                            break
                        }
                        start += 1
                    }
                    // Find end of charset value
                    var end = start
                    while (end < content.size) {
                        let c = content[end]
                        if (c == '"' || c == '\'' || c == '>' || c == ';' || c == ' ' || c == '\t') {
                            break
                        }
                        end += 1
                    }
                    if (end > start) {
                        let encoding = content[start..end]
                        return Some(normalizeEncoding(encoding))
                    }
                }
            }
        }

        return None
    }

    /// Full sniffing algorithm
    /// Corresponds to: WHATWG encoding sniffing algorithm
    public static func sniff(bytes: Array<UInt8>, contentType: ?String): SniffingResult {
        // Step 1: BOM sniffing
        let bomResult = sniffBom(bytes)
        if (let SniffingResult.Utf8 = bomResult) {
            return SniffingResult.Utf8
        }
        if (let SniffingResult.Utf16Be = bomResult) {
            return SniffingResult.Utf16Be
        }
        if (let SniffingResult.Utf16Le = bomResult) {
            return SniffingResult.Utf16Le
        }

        // Step 2: Content-Type sniffing
        match (contentType) {
            case Some(ct) =>
                let encoding = sniffContentType(ct)
                if (encoding.isSome()) {
                    return SniffingResult.ContentHint(encoding.getOrThrow())
                }
            case None => ()
        }

        // Step 3: Prescan
        let prescanResult = prescan(bytes)
        if (prescanResult.isSome()) {
            return SniffingResult.ContentHint(prescanResult.getOrThrow())
        }

        // Step 4: Fallback to UTF-8
        return SniffingResult.Utf8
    }

    /// Normalize encoding name to canonical form
    /// Corresponds to: WHATWG "get an encoding"
    public static func normalizeEncoding(label: String): String {
        let lower = label.toAsciiLower().trimAscii{
            c => c == ' ' || c == '\t' || c == '\r' || c == '\n'
        }

        match (lower) {
            case "unicode-1-1-utf-8" | "utf-8" | "utf8" => return "utf-8"
            case "utf-16" | "utf16" => return "utf-16le"
            case "utf-16le" | "utf16le" => return "utf-16le"
            case "utf-16be" | "utf16be" => return "utf-16be"
            case "iso-8859-1" | "latin1" | "l1" => return "windows-1252"
            case "iso-8859-2" | "latin2" => return "iso-8859-2"
            case "iso-8859-3" | "latin3" => return "iso-8859-3"
            case "iso-8859-4" | "latin4" => return "iso-8859-4"
            case "iso-8859-5" | "cyrillic" => return "iso-8859-5"
            case "iso-8859-6" | "arabic" => return "iso-8859-6"
            case "iso-8859-7" | "greek" | "greek8" => return "iso-8859-7"
            case "iso-8859-8" | "hebrew" => return "iso-8859-8"
            case "iso-8859-9" | "latin5" => return "iso-8859-9"
            case "iso-8859-10" | "latin6" => return "iso-8859-10"
            case "iso-8859-13" | "latin7" => return "iso-8859-13"
            case "iso-8859-14" | "latin8" => return "iso-8859-14"
            case "iso-8859-15" | "latin9" => return "iso-8859-15"
            case "iso-8859-16" | "latin10" => return "iso-8859-16"
            case "windows-1250" => return "windows-1250"
            case "windows-1251" => return "windows-1251"
            case "windows-1252" | "ascii" | "us-ascii" | "ansi_x3.4-1968" => return "windows-1252"
            case "windows-1253" => return "windows-1253"
            case "windows-1254" => return "windows-1254"
            case "windows-1255" => return "windows-1255"
            case "windows-1256" => return "windows-1256"
            case "windows-1257" => return "windows-1257"
            case "windows-1258" => return "windows-1258"
            case "shift_jis" | "shift-jis" | "sjis" | "csshiftjis" => return "shift_jis"
            case "euc-jp" | "eucjp" => return "euc-jp"
            case "iso-2022-jp" => return "iso-2022-jp"
            case "gbk" | "gb2312" | "x-gbk" => return "gbk"
            case "gb18030" => return "gb18030"
            case "big5" | "big5-hkscs" | "cn-big5" => return "big5"
            case "euc-kr" | "euckr" | "korean" => return "euc-kr"
            case "replacement" => return "replacement"
            case _ => return lower
        }
    }
}
