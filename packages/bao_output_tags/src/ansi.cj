// 严格翻译自: src/bun_output_tags/lib.rs:10-62
//   pub mod ansi  { pub const RESET / BOLD / DIM / ... }
//   pub mod ansi_b { pub const RESET / BOLD / DIM / ... (byte slices) }
//
// Bun 的 bun_output_tags 是 #![no_std] 零依赖叶子包，
// 为 proc-macro crate 和 runtime crate 提供统一的 ANSI 转义常量表，
// 避免重复声明。仓颉翻译保持相同的常量名和值。
package bao_output_tags

// ============================================================================
// Ansi - 命名 ANSI SGR 转义序列 (字符串形式)
// 严格翻译自: src/bun_output_tags/lib.rs:17-36
//   pub mod ansi {
//       pub const RESET: &str      = "\x1b[0m";
//       pub const BOLD: &str       = "\x1b[1m";
//       pub const DIM: &str        = "\x1b[2m";
//       pub const ITALIC: &str     = "\x1b[3m";
//       pub const UNDERLINE: &str  = "\x1b[4m";
//       pub const INVERT: &str     = "\x1b[7m";
//       pub const STRIKETHROUGH: &str = "\x1b[9m";
//       pub const BLACK: &str      = "\x1b[30m";
//       pub const RED: &str        = "\x1b[31m";
//       pub const GREEN: &str      = "\x1b[32m";
//       pub const YELLOW: &str     = "\x1b[33m";
//       pub const BLUE: &str       = "\x1b[34m";
//       pub const MAGENTA: &str    = "\x1b[35m";
//       pub const CYAN: &str       = "\x1b[36m";
//       pub const WHITE: &str      = "\x1b[37m";
//       pub const BRIGHT_WHITE: &str = "\x1b[97m";
//       pub const BG_RED: &str     = "\x1b[41m";
//       pub const BG_GREEN: &str   = "\x1b[42m";
//   }
//
// WHITE 是 SGR 37 (正常亮度). printDiff.zig:177 使用 SGR 97 即 BRIGHT_WHITE。
// ============================================================================

/// ANSI SGR 转义序列常量 (字符串形式) - 对应 Bun pub mod ansi
/// 每个常量一个规范的字面量，其他 crate 引用此对象而非重复声明转义字节。
public class Ansi {

    /// 重置所有属性 - SGR 0
    public static let RESET: String          = "\u{1b}[0m"

    /// 粗体 - SGR 1
    public static let BOLD: String           = "\u{1b}[1m"

    /// 暗淡 - SGR 2
    public static let DIM: String            = "\u{1b}[2m"

    /// 斜体 - SGR 3
    public static let ITALIC: String         = "\u{1b}[3m"

    /// 下划线 - SGR 4
    public static let UNDERLINE: String      = "\u{1b}[4m"

    /// 反转前景/背景 - SGR 7
    public static let INVERT: String         = "\u{1b}[7m"

    /// 删除线 - SGR 9
    public static let STRIKETHROUGH: String  = "\u{1b}[9m"

    /// 前景黑色 - SGR 30
    public static let BLACK: String          = "\u{1b}[30m"

    /// 前景红色 - SGR 31
    public static let RED: String            = "\u{1b}[31m"

    /// 前景绿色 - SGR 32
    public static let GREEN: String          = "\u{1b}[32m"

    /// 前景黄色 - SGR 33
    public static let YELLOW: String         = "\u{1b}[33m"

    /// 前景蓝色 - SGR 34
    public static let BLUE: String           = "\u{1b}[34m"

    /// 前景品红 - SGR 35
    public static let MAGENTA: String        = "\u{1b}[35m"

    /// 前景青色 - SGR 36
    public static let CYAN: String           = "\u{1b}[36m"

    /// 前景白色 - SGR 37
    public static let WHITE: String          = "\u{1b}[37m"

    /// 前景亮白色 - SGR 97 (与 WHITE 不同，保持与 Bun printDiff 输出字节一致)
    public static let BRIGHT_WHITE: String   = "\u{1b}[97m"

    /// 背景红色 - SGR 41
    public static let BG_RED: String         = "\u{1b}[41m"

    /// 背景绿色 - SGR 42
    public static let BG_GREEN: String       = "\u{1b}[42m"
}

// ============================================================================
// AnsiBytes - ANSI SGR 转义序列 (字节切片形式)
// 严格翻译自: src/bun_output_tags/lib.rs:42-62
//   pub mod ansi_b {
//       pub const RESET: &[u8] = ansi::RESET.as_bytes();
//       ...
//   }
//
// 对应 Rust 的 &[u8] 字节切片视图，仓颉用 Array<UInt8> 表示。
// 与 Ansi 共享相同的静态存储（仓颉 String.toArray() 返回拷贝，
// 这里通过常量保持语义一致）。
// ============================================================================

/// ANSI SGR 转义序列常量 (字节形式) - 对应 Bun pub mod ansi_b
/// 用于向 &[u8] 缓冲区写入的场景 (如 md ANSI 渲染器、stack-frame 颜色码)。
public class AnsiBytes {

    /// 重置所有属性
    public static let RESET: Array<UInt8>         = Ansi.RESET.toArray()

    /// 粗体
    public static let BOLD: Array<UInt8>          = Ansi.BOLD.toArray()

    /// 暗淡
    public static let DIM: Array<UInt8>           = Ansi.DIM.toArray()

    /// 斜体
    public static let ITALIC: Array<UInt8>        = Ansi.ITALIC.toArray()

    /// 下划线
    public static let UNDERLINE: Array<UInt8>     = Ansi.UNDERLINE.toArray()

    /// 反转前景/背景
    public static let INVERT: Array<UInt8>        = Ansi.INVERT.toArray()

    /// 删除线
    public static let STRIKETHROUGH: Array<UInt8> = Ansi.STRIKETHROUGH.toArray()

    /// 前景黑色
    public static let BLACK: Array<UInt8>         = Ansi.BLACK.toArray()

    /// 前景红色
    public static let RED: Array<UInt8>           = Ansi.RED.toArray()

    /// 前景绿色
    public static let GREEN: Array<UInt8>         = Ansi.GREEN.toArray()

    /// 前景黄色
    public static let YELLOW: Array<UInt8>        = Ansi.YELLOW.toArray()

    /// 前景蓝色
    public static let BLUE: Array<UInt8>          = Ansi.BLUE.toArray()

    /// 前景品红
    public static let MAGENTA: Array<UInt8>       = Ansi.MAGENTA.toArray()

    /// 前景青色
    public static let CYAN: Array<UInt8>          = Ansi.CYAN.toArray()

    /// 前景白色
    public static let WHITE: Array<UInt8>         = Ansi.WHITE.toArray()

    /// 前景亮白色
    public static let BRIGHT_WHITE: Array<UInt8>  = Ansi.BRIGHT_WHITE.toArray()

    /// 背景红色
    public static let BG_RED: Array<UInt8>        = Ansi.BG_RED.toArray()

    /// 背景绿色
    public static let BG_GREEN: Array<UInt8>      = Ansi.BG_GREEN.toArray()
}
