// 严格翻译自: src/bun_output_tags/lib.rs (完整文件)
//   pub const COLOR_TABLE: &[(&str, &str)]
//   pub fn color_for(name: &str) -> Option<&'static str>
//   pub fn color_for_bytes(name: &[u8]) -> Option<&'static str>
//
// Bun 的 bun_output_tags 是 #![no_std] 零依赖叶子包:
//   1. ansi 模块 - 命名 ANSI SGR 转义常量 (字符串)
//   2. ansi_b 模块 - 同上 (字节切片)
//   3. COLOR_TABLE - (tag, ansi_escape) 对表
//   4. color_for / color_for_bytes - 标签到 ANSI 转义查找
//
// 仓颉翻译将 ansi / ansi_b 放在 ansi.cj 中，
// 本文件包含 COLOR_TABLE、color_for、color_for_bytes 以及包声明。
package bao_output_tags

// ============================================================================
// 重导出 Ansi / AnsiBytes - 对应 Bun pub use ansi / pub use ansi_b
// ============================================================================
// import bao_output_tags.Ansi 和 AnsiBytes 在 ansi.cj 中定义
// 下游通过 import bao_output_tags.* 即可使用

// ============================================================================
// COLOR_TABLE - (tag, ansi_escape) 对表
// 严格翻译自: src/bun_output_tags/lib.rs:66-81
//   pub const COLOR_TABLE: &[(&str, &str)] = &[
//       ("b", ansi::BOLD),
//       ("d", ansi::DIM),
//       ("i", ansi::ITALIC),
//       ("u", ansi::UNDERLINE),
//       ("black", ansi::BLACK),
//       ("red", ansi::RED),
//       ("green", ansi::GREEN),
//       ("yellow", ansi::YELLOW),
//       ("blue", ansi::BLUE),
//       ("magenta", ansi::MAGENTA),
//       ("cyan", ansi::CYAN),
//       ("white", ansi::WHITE),
//       ("bgred", ansi::BG_RED),
//       ("bggreen", ansi::BG_GREEN),
//   ];
//
// 14 项。线性扫描是有意为之 —— 仅在诊断输出路径的 <tag> 标记处命中。
// ============================================================================

/// 颜色标签条目 - 对应 Bun (&str, &str) 对
public class ColorEntry {
    public let tag: String
    public let ansiEscape: String

    public init(tag: String, ansiEscape: String) {
        this.tag = tag
        this.ansiEscape = ansiEscape
    }
}

/// 标签到 ANSI 转义的查找表 - 对应 Bun COLOR_TABLE
/// 14 项。线性扫描; 仅在诊断输出路径的 <tag> 标记处命中。
public class ColorTable {

    /// 颜色表内容 (不可变)
    public static let ENTRIES: Array<ColorEntry> = [
        ColorEntry("b",        Ansi.BOLD),
        ColorEntry("d",        Ansi.DIM),
        ColorEntry("i",        Ansi.ITALIC),
        ColorEntry("u",        Ansi.UNDERLINE),
        ColorEntry("black",    Ansi.BLACK),
        ColorEntry("red",      Ansi.RED),
        ColorEntry("green",    Ansi.GREEN),
        ColorEntry("yellow",   Ansi.YELLOW),
        ColorEntry("blue",     Ansi.BLUE),
        ColorEntry("magenta",  Ansi.MAGENTA),
        ColorEntry("cyan",     Ansi.CYAN),
        ColorEntry("white",    Ansi.WHITE),
        ColorEntry("bgred",    Ansi.BG_RED),
        ColorEntry("bggreen",  Ansi.BG_GREEN)
    ]
}

// ============================================================================
// RESET - 重置序列
// 严格翻译自: src/bun_output_tags/lib.rs:84
//   pub use ansi::RESET;
// ============================================================================

/// 重置序列 - 对应 Bun pub use ansi::RESET
/// </…> 或 <r> 标签的结束序列。
public let RESET: String = Ansi.RESET

// ============================================================================
// color_for - 根据标签名查找 ANSI 转义 (字符串形式)
// 严格翻译自: src/bun_output_tags/lib.rs:87-95
//   #[inline]
//   pub fn color_for(name: &str) -> Option<&'static str> {
//       for &(k, v) in COLOR_TABLE {
//           if k == name {
//               return Some(v);
//           }
//       }
//       None
//   }
// ============================================================================

/// 根据标签名查找 ANSI 转义字符串 - 对应 Bun color_for()
/// 返回 None 表示未知标签。
public func colorFor(name: String): ?String {
    for (entry in ColorTable.ENTRIES) {
        if (entry.tag == name) {
            let result: Option<String> = Some(entry.ansiEscape)
            return result
        }
    }
    let none: Option<String> = Option<String>.None
    return none
}

// ============================================================================
// color_for_bytes - 根据标签名字节查找 ANSI 转义
// 严格翻译自: src/bun_output_tags/lib.rs:99-107
//   #[inline]
//   pub fn color_for_bytes(name: &[u8]) -> Option<&'static str> {
//       for &(k, v) in COLOR_TABLE {
//           if k.as_bytes() == name {
//               return Some(v);
//           }
//       }
//       None
//   }
//
// 用于在 &[u8] 模板上工作的调用者 (对应 Zig 的 ComptimeStringMap.get)。
// ============================================================================

/// 根据标签名字节查找 ANSI 转义字符串 - 对应 Bun color_for_bytes()
/// 用于在字节缓冲区上工作的调用者。
public func colorForBytes(name: Array<UInt8>): ?String {
    for (entry in ColorTable.ENTRIES) {
        let tagBytes = entry.tag.toArray()
        if (tagBytes.size == name.size) {
            var matches = true
            var i: Int64 = 0
            while (i < name.size) {
                if (tagBytes[i] != name[i]) {
                    matches = false
                    break
                }
                i += 1
            }
            if (matches) {
                return Some(entry.ansiEscape)
            }
        }
    }
    return Option<String>.None
}
