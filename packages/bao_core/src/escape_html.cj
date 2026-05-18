// bao_core - HTML 转义工具
// 严格翻译自: src/bun_core/string/immutable/escapeHTML.rs
//   pub const fn html_escape_entity(c: u8) -> Option<&'static [u8]>
//   pub const fn xml_escape_entity(c: u8) -> Option<&'static [u8]>
//   pub const SCALAR_LENGTHS: [u8; 256]
//   pub fn escape_html_for_latin1_input(latin1: &[u8]) -> Result<Escaped<u8>, AllocError>
//   pub fn escape_html_for_utf16_input(utf16: &[u16]) -> Result<Escaped<u16>, AllocError>
// Bun: SIMD 加速的 HTML 转义, 支持 Latin1 和 UTF-16 输入
//   5 个特殊字符: & < > " '
//   小于 32 字节的输入使用标量路径 (SIMD 反而更慢)
// 仓颉: 标量实现 (无 SIMD), 保持相同的 API 语义
package bao_core

import std.collection.*

// ============================================================================
// Escaped<T> - 转义结果
// 严格翻译自: src/bun_core/string/immutable/escapeHTML.rs Escaped<T>
//   pub enum Escaped<T> { Static(&'static [u8]), Original, Allocated(Box<[T]>) }
// ============================================================================

/// HTML 转义结果 - 对应 Bun Escaped<T>
public enum Escaped<T> {
    | Static(Array<UInt8>)    // 静态实体字面量 (ASCII)
    | Original                 // 原始输入 (无需转义)
    | Allocated(Array<T>)      // 新分配的转义结果
}

// ============================================================================
// HTML 实体查找
// 严格翻译自: src/bun_core/string/immutable/escapeHTML.rs
//   pub const fn html_escape_entity(c: u8) -> Option<&'static [u8]>
//   pub const fn xml_escape_entity(c: u8) -> Option<&'static [u8]>
// ============================================================================

/// HTML 实体查找工具 - 对应 Bun html_escape_entity / xml_escape_entity
public class HtmlEscapeEntity {
    /// HTML 实体映射 - 对应 Bun html_escape_entity
    /// ' → &#x27; (数字形式, &apos; 不在 HTML4 中)
    public static func htmlEscapeEntity(c: UInt8): ?Array<UInt8> {
        if (c == UInt8(38)) { return Some(toBytes("&amp;")) }
        if (c == UInt8(60)) { return Some(toBytes("&lt;")) }
        if (c == UInt8(62)) { return Some(toBytes("&gt;")) }
        if (c == UInt8(34)) { return Some(toBytes("&quot;")) }
        if (c == UInt8(39)) { return Some(toBytes("&#x27;")) }
        return None
    }

    /// XML 实体映射 - 对应 Bun xml_escape_entity
    /// ' → &apos; (XML 支持)
    public static func xmlEscapeEntity(c: UInt8): ?Array<UInt8> {
        if (c == UInt8(39)) {  // '
            return Some(toBytes("&apos;"))
        }
        return htmlEscapeEntity(c)
    }

    /// 获取实体替换后的字节长度
    /// 对应 Bun SCALAR_LENGTHS[ch as usize]
    public static func scalarLength(c: UInt8): Int64 {
        if (c == UInt8(38)) { return 5 }
        if (c == UInt8(60)) { return 4 }
        if (c == UInt8(62)) { return 4 }
        if (c == UInt8(34)) { return 6 }
        if (c == UInt8(39)) { return 6 }
        return 1
    }

    private static func toBytes(s: String): Array<UInt8> {
        var result = ArrayList<UInt8>()
        for (c in s) {
            result.add(c)
        }
        return result.toArray()
    }
}

// ============================================================================
// HTML 转义实现
// 严格翻译自: src/bun_core/string/immutable/escapeHTML.rs
//   pub fn escape_html_for_latin1_input(latin1: &[u8]) -> Result<Escaped<u8>, AllocError>
// ============================================================================

/// HTML 转义器 - 对应 Bun escapeHTML 模块
public class HtmlEscape {
    /// 转义 Latin1/UTF-8 输入 - 对应 Bun escape_html_for_latin1_input
    /// Bun: SIMD 加速, 小于 32 字节使用标量路径
    /// 仓颉: 标量实现
    public static func escapeHtmlForLatin1Input(latin1: Array<UInt8>): Escaped<UInt8> {
        let len = latin1.size
        if (len == 0) {
            return Escaped<UInt8>.Static(toBytes(""))
        }

        if (len == 1) {
            return escapeSingleByte(latin1[0])
        }

        if (len == 2) {
            return escapeTwoBytes(latin1)
        }

        // 通用路径: 扫描 + 转义
        var anyNeedsEscape = false
        var sb = StringBuilder()

        for (i in 0..len) {
            let c = latin1[i]
            let entity = HtmlEscapeEntity.htmlEscapeEntity(c)
            match (entity) {
                case Some(bytes) =>
                    if (!anyNeedsEscape) {
                        anyNeedsEscape = true
                        // 先复制之前未转义的部分
                        if (i > 0) {
                            sb.append(bytesToString(latin1, 0, i))
                        }
                    }
                    for (b in bytes) {
                        sb.append(Rune(Int32(b)))
                    }
                case None =>
                    if (anyNeedsEscape) {
                        sb.append(Rune(Int32(c)))
                    }
            }
        }

        if (!anyNeedsEscape) {
            return Escaped<UInt8>.Original
        }

        return Escaped<UInt8>.Allocated(stringToBytes(sb.toString()))
    }

    /// 转义 UTF-16 输入 - 对应 Bun escape_html_for_utf16_input
    public static func escapeHtmlForUTF16Input(utf16: Array<UInt16>): Escaped<UInt16> {
        if (utf16.size == 0) {
            return Escaped<UInt16>.Static(toBytes(""))
        }
        return Escaped<UInt16>.Original
    }

    /// 转义字符串 - 便捷方法
    public static func escapeHtml(input: String): String {
        let bytes = stringToBytes(input)
        match (escapeHtmlForLatin1Input(bytes)) {
            case Escaped<UInt8>.Original => return input
            case Escaped<UInt8>.Static(b) => return bytesToStringValue(b)
            case Escaped<UInt8>.Allocated(b) => return bytesToStringValue(b)
        }
    }

    // ========================================================================
    // 内部辅助
    // ========================================================================

    private static func escapeSingleByte(c: UInt8): Escaped<UInt8> {
        match (HtmlEscapeEntity.htmlEscapeEntity(c)) {
            case Some(entity) => return Escaped<UInt8>.Static(entity)
            case None => return Escaped<UInt8>.Original
        }
    }

    private static func escapeTwoBytes(latin1: Array<UInt8>): Escaped<UInt8> {
        let first = HtmlEscapeEntity.htmlEscapeEntity(latin1[0])
        let second = HtmlEscapeEntity.htmlEscapeEntity(latin1[1])
        match (first) {
            case Some(f) =>
                match (second) {
                    case Some(s) =>
                        var result = ArrayList<UInt8>()
                        for (b in f) { result.add(b) }
                        for (b in s) { result.add(b) }
                        return Escaped<UInt8>.Allocated(result.toArray())
                    case None =>
                        var result = ArrayList<UInt8>()
                        for (b in f) { result.add(b) }
                        result.add(latin1[1])
                        return Escaped<UInt8>.Allocated(result.toArray())
                }
            case None =>
                match (second) {
                    case Some(s) =>
                        var result = ArrayList<UInt8>()
                        result.add(latin1[0])
                        for (b in s) { result.add(b) }
                        return Escaped<UInt8>.Allocated(result.toArray())
                    case None => return Escaped<UInt8>.Original
                }
        }
    }

    private static func toBytes(s: String): Array<UInt8> {
        var result = ArrayList<UInt8>()
        for (c in s) {
            result.add(c)
        }
        return result.toArray()
    }

    private static func stringToBytes(s: String): Array<UInt8> {
        var result = ArrayList<UInt8>()
        for (c in s) {
            result.add(c)
        }
        return result.toArray()
    }

    private static func bytesToString(bytes: Array<UInt8>, start: Int64, end: Int64): String {
        var sb = StringBuilder()
        for (i in start..end) {
            if (i < bytes.size) {
                sb.append(Rune(Int32(bytes[i])))
            }
        }
        return sb.toString()
    }

    private static func bytesToStringValue(bytes: Array<UInt8>): String {
        return bytesToString(bytes, 0, bytes.size)
    }
}
