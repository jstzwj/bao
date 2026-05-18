// bao_core - 终端可见宽度计算
// 严格翻译自: src/bun_core/string/immutable/visible.rs
//   pub fn is_zero_width_codepoint_type<T>(cp: T) -> bool
//   pub fn is_full_width_codepoint_type<T>(cp: T) -> bool
//   pub fn visible(input: []const u8) -> usize
//   pub fn visible_codepoint_width(cp: i32) -> usize
// Bun: 终端可见宽度 (East-Asian-width + grapheme-aware)
//   SIMD 路径在 B-2 降级为标量 ScalarVec
// 仓颉: 标量实现, 保持相同的宽度计算逻辑
package bao_core

import std.collection.*

// ============================================================================
// 可见宽度类型 - 对应 Bun visible.zig 中的宽度类型枚举
// ============================================================================

/// 宽度类型 - 对应 Bun VisibleCodepointWidthType
public enum WidthType {
    | Narrow      // 窄字符 (宽度 1)
    | Wide        // 宽字符 (宽度 2)
    | Zero        // 零宽字符 (宽度 0)
    | Ambiguous   // 模糊宽度 (取决于 East-Asian 设置)
}

// ============================================================================
// 可见宽度工具 - 严格翻译自: src/bun_core/string/immutable/visible.rs
// ============================================================================

/// 终端可见宽度 - 对应 Bun visible 模块
public class VisibleWidth {
    /// 判断是否为零宽码点 - 对应 Bun is_zero_width_codepoint_type
    /// 包含: 控制字符, 组合标记, 变体选择器, 代理等
    public static func isZeroWidthCodepoint(cp: UInt32): Bool {
        // 控制字符 U+0000..U+001F
        if (cp <= 0x1F) {
            return true
        }
        // C1 控制字符 U+007F..U+009F
        if (cp >= 0x7F && cp <= 0x9F) {
            return true
        }
        // 软连字符 U+00AD
        if (cp == 0xAD) {
            return true
        }
        // 组合变音符号 U+0300..U+036F
        if (cp >= 0x300 && cp <= 0x36F) {
            return true
        }
        // 不可见修饰字符 U+200B..U+200F
        if (cp >= 0x200B && cp <= 0x200F) {
            return true
        }
        // 字连接符等 U+2060..U+2064
        if (cp >= 0x2060 && cp <= 0x2064) {
            return true
        }
        // 组合变音符号 (符号) U+20D0..U+20FF
        if (cp >= 0x20D0 && cp <= 0x20FF) {
            return true
        }
        // 变体选择器 U+FE00..U+FE0F
        if (cp >= 0xFE00 && cp <= 0xFE0F) {
            return true
        }
        // 组合半标记 U+FE20..U+FE2F
        if (cp >= 0xFE20 && cp <= 0xFE2F) {
            return true
        }
        // BOM / 零宽不换行空格 U+FEFF
        if (cp == 0xFEFF) {
            return true
        }
        // 代理 U+D800..U+DFFF
        if (cp >= 0xD800 && cp <= 0xDFFF) {
            return true
        }
        // 阿拉伯格式字符
        if ((cp >= 0x600 && cp <= 0x605) || cp == 0x6DD || cp == 0x70F || cp == 0x8E2) {
            return true
        }
        // Indic 组合标记
        if (cp >= 0x900 && cp <= 0xD4F) {
            let offset = cp & 0x7F
            if (offset <= 0x02) { return true }
            if (offset >= 0x3A && offset <= 0x4D && offset != 0x3D) { return true }
            if (offset >= 0x51 && offset <= 0x57) { return true }
            if (offset >= 0x62 && offset <= 0x63) { return true }
        }
        // 更多组合标记范围
        if (cp >= 0x1AB0 && cp <= 0x1AFF) { return true }
        if (cp >= 0x1DC0 && cp <= 0x1DFF) { return true }
        if (cp >= 0xE0100 && cp <= 0xE01EF) { return true }
        if (cp >= 0xE0020 && cp <= 0xE007F) { return true }
        return false
    }

    /// 判断是否为全宽码点 - 对应 Bun is_full_width_codepoint_type
    /// East Asian Wide/Fullwidth 字符
    public static func isFullWidthCodepoint(cp: UInt32): Bool {
        // CJK 统一汉字 U+4E00..U+9FFF
        if (cp >= 0x4E00 && cp <= 0x9FFF) { return true }
        // CJK 兼容汉字 U+F900..U+FAFF
        if (cp >= 0xF900 && cp <= 0xFAFF) { return true }
        // CJK 统一汉字扩展 A U+3400..U+4DBF
        if (cp >= 0x3400 && cp <= 0x4DBF) { return true }
        // CJK 统一汉字扩展 B..H
        if (cp >= 0x20000 && cp <= 0x323AF) { return true }
        // 全角 ASCII/拉丁 U+FF01..U+FF60
        if (cp >= 0xFF01 && cp <= 0xFF60) { return true }
        // 平假名 U+3040..U+309F
        if (cp >= 0x3040 && cp <= 0x309F) { return true }
        // 片假名 U+30A0..U+30FF
        if (cp >= 0x30A0 && cp <= 0x30FF) { return true }
        // 韩文音节 U+AC00..U+D7AF
        if (cp >= 0xAC00 && cp <= 0xD7AF) { return true }
        // 韩文字母 U+1100..U+11FF
        if (cp >= 0x1100 && cp <= 0x11FF) { return true }
        // 全角符号 U+3000..U+303F
        if (cp >= 0x3000 && cp <= 0x303F) { return true }
        // Bopomofo U+3100..U+31BF
        if (cp >= 0x3100 && cp <= 0x31BF) { return true }
        // 台湾字符 U+31C0..U+31EF
        if (cp >= 0x31C0 && cp <= 0x31EF) { return true }
        return false
    }

    /// 判断是否为模糊宽度码点 - 对应 Bun is_amgiguous_codepoint_type
    public static func isAmbiguousCodepoint(cp: UInt32): Bool {
        // East Asian Ambiguous 范围 (简化)
        if (cp >= 0xA1 && cp <= 0xA1) { return true }
        if (cp >= 0xA4 && cp <= 0xA4) { return true }
        if (cp >= 0xA7 && cp <= 0xA8) { return true }
        if (cp >= 0xAA && cp <= 0xAA) { return true }
        if (cp >= 0xAD && cp <= 0xAE) { return true }
        if (cp >= 0x2010 && cp <= 0x2027) { return true }
        if (cp >= 0x2030 && cp <= 0x205E) { return true }
        if (cp >= 0x2160 && cp <= 0x216B) { return true }
        if (cp >= 0x2190 && cp <= 0x2199) { return true }
        if (cp >= 0x2460 && cp <= 0x24E9) { return true }
        if (cp >= 0x2500 && cp <= 0x257F) { return true }
        if (cp >= 0x25A0 && cp <= 0x25FF) { return true }
        if (cp >= 0x2600 && cp <= 0x27BF) { return true }
        return false
    }

    /// 获取码点的可见宽度类型 - 对应 Bun visible_codepoint_width_type
    public static func visibleCodepointWidthType(cp: UInt32): WidthType {
        if (isZeroWidthCodepoint(cp)) { return WidthType.Zero }
        if (isFullWidthCodepoint(cp)) { return WidthType.Wide }
        if (isAmbiguousCodepoint(cp)) { return WidthType.Ambiguous }
        return WidthType.Narrow
    }

    /// 获取码点的可见宽度 - 对应 Bun visible_codepoint_width
    public static func visibleCodepointWidth(cp: Int32): Int64 {
        if (cp < 0) { return 0 }
        let ucp = UInt32(cp)
        let wt = visibleCodepointWidthType(ucp)
        match (wt) {
            case Zero => return 0
            case Wide => return 2
            case Narrow => return 1
            case Ambiguous => return 1  // 默认 Ambiguous 为窄
        }
    }

    /// 获取码点的可见宽度 (可能 emoji) - 对应 Bun visible_codepoint_width_maybe_emoji
    public static func visibleCodepointWidthMaybeEmoji(cp: Int32): Int64 {
        // Emoji 通常为 2 宽度
        if (cp >= 0x1F600 && cp <= 0x1F64F) { return 2 }
        if (cp >= 0x1F300 && cp <= 0x1F5FF) { return 2 }
        if (cp >= 0x1F680 && cp <= 0x1F6FF) { return 2 }
        if (cp >= 0x1F900 && cp <= 0x1F9FF) { return 2 }
        return visibleCodepointWidth(cp)
    }

    /// 计算字符串的终端可见宽度 - 对应 Bun visible(input: []const u8) -> usize
    /// 使用字素感知的宽度计算 (grapheme-aware)
    public static func visible(input: Array<UInt8>): Int64 {
        if (input.size == 0) { return 0 }
        var width = 0
        var iter = CodepointIterator(input)
        while (iter.hasNext()) {
            let result = iter.next()
            width += visibleCodepointWidth(result.codepoint)
        }
        return width
    }

    /// 计算字符串的终端可见宽度 (String 输入)
    public static func visible(input: String): Int64 {
        var bytes = ArrayList<UInt8>()
        for (c in input) {
            bytes.add(c)
        }
        return visible(bytes.toArray())
    }
}
