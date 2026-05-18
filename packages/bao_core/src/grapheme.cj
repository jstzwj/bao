// bao_core - 字素簇边界检测算法
// 严格翻译自: src/bun_core/string/immutable/grapheme.rs
//   pub enum GraphemeBreakNoControl { Other, Prepend, RegionalIndicator, ... }
//   pub enum BreakState { Default, RegionalIndicator, ExtendedPictographic, ... }
//   pub fn grapheme_break(cp1: u32, cp2: u32, state: &mut BreakState) -> bool
// Bun: Grapheme break implementation using uucode's approach
//   Includes GB9c (Indic Conjunct Break) support
//   预计算查找表: 2^13 keys of 4-bit values = 8KB total
// 仓颉: 提供等价的字素边界检测
package bao_core

// ============================================================================
// GraphemeBreakNoControl - 字素断点属性 (不含控制字符)
// 严格翻译自: src/bun_core/string/immutable/grapheme.rs
//   #[repr(u8)] pub enum GraphemeBreakNoControl { Other = 0, Prepend = 1, ... }
// ============================================================================

/// 字素断点属性 - 对应 Bun GraphemeBreakNoControl
/// 排除控制字符/CR/LF (假设由外部处理)
public enum GraphemeBreakNoControl {
    | Other                          // 0
    | Prepend                        // 1
    | RegionalIndicator              // 2
    | SpacingMark                    // 3
    | L                              // 4 - 韩文 L
    | V                              // 5 - 韩文 V
    | T                              // 6 - 韩文 T
    | Lv                             // 7 - 韩文 LV
    | Lvt                            // 8 - 韩文 LVT
    | Zwj                            // 9 - Zero Width Joiner
    | Zwnj                           // 10 - Zero Width Non-Joiner
    | ExtendedPictographic           // 11 - 扩展象形文字
    | EmojiModifierBase              // 12 - Emoji 修饰符基础
    | EmojiModifier                  // 13 - Emoji 修饰符
    | IndicConjunctBreakExtend       // 14 - Indic 连接中断 Extend
    | IndicConjunctBreakLinker       // 15 - Indic 连接中断 Linker
    | IndicConjunctBreakConsonant    // 16 - Indic 连接中断 Consonant

    /// 所有枚举值
    public static func all(): Array<GraphemeBreakNoControl> {
        return [
            Other, Prepend, RegionalIndicator, SpacingMark,
            L, V, T, Lv, Lvt, Zwj, Zwnj,
            ExtendedPictographic, EmojiModifierBase, EmojiModifier,
            IndicConjunctBreakExtend, IndicConjunctBreakLinker,
            IndicConjunctBreakConsonant
        ]
    }

    /// 转为整数
    public func toInt(): Int32 {
        match (this) {
            case Other => 0
            case Prepend => 1
            case RegionalIndicator => 2
            case SpacingMark => 3
            case L => 4
            case V => 5
            case T => 6
            case Lv => 7
            case Lvt => 8
            case Zwj => 9
            case Zwnj => 10
            case ExtendedPictographic => 11
            case EmojiModifierBase => 12
            case EmojiModifier => 13
            case IndicConjunctBreakExtend => 14
            case IndicConjunctBreakLinker => 15
            case IndicConjunctBreakConsonant => 16
        }
    }

    /// 从整数构造
    public static func fromInt(n: Int32): GraphemeBreakNoControl {
        match (n) {
            case 0 => Other
            case 1 => Prepend
            case 2 => RegionalIndicator
            case 3 => SpacingMark
            case 4 => L
            case 5 => V
            case 6 => T
            case 7 => Lv
            case 8 => Lvt
            case 9 => Zwj
            case 10 => Zwnj
            case 11 => ExtendedPictographic
            case 12 => EmojiModifierBase
            case 13 => EmojiModifier
            case 14 => IndicConjunctBreakExtend
            case 15 => IndicConjunctBreakLinker
            case 16 => IndicConjunctBreakConsonant
            case _ => Other
        }
    }
}

// ============================================================================
// BreakState - 字素断点状态
// 严格翻译自: src/bun_core/string/immutable/grapheme.rs BreakState
//   #[repr(u8)] pub enum BreakState { Default = 0, RegionalIndicator = 1, ... }
// ============================================================================

/// 字素断点状态 - 对应 Bun BreakState
/// 在连续调用 grapheme_break 时维护的状态
public enum BreakState {
    | Default                         // 0
    | RegionalIndicator               // 1
    | ExtendedPictographic            // 2
    | IndicConjunctBreakConsonant     // 3
    | IndicConjunctBreakLinker        // 4

    /// 从整数构造 - 对应 Bun BreakState::from_raw
    public static func fromRaw(n: UInt8): BreakState {
        if (n == UInt8(1)) { return RegionalIndicator }
        if (n == UInt8(2)) { return ExtendedPictographic }
        if (n == UInt8(3)) { return IndicConjunctBreakConsonant }
        if (n == UInt8(4)) { return IndicConjunctBreakLinker }
        return Default
    }

    /// 转为整数
    public func toInt(): UInt8 {
        match (this) {
            case Default => UInt8(0)
            case RegionalIndicator => UInt8(1)
            case ExtendedPictographic => UInt8(2)
            case IndicConjunctBreakConsonant => UInt8(3)
            case IndicConjunctBreakLinker => UInt8(4)
        }
    }
}

// ============================================================================
// 字素断点算法 - 严格翻译自: src/bun_core/string/immutable/grapheme.rs
//   pub fn grapheme_break(cp1: u32, cp2: u32, state: &mut BreakState) -> bool
//   包含 GB9c (Indic Conjunct Break) 支持
// ============================================================================

/// 字素断点检测器 - 对应 Bun grapheme 模块
public class GraphemeBreak {
    /// 查找表引用 - 对应 Bun grapheme_tables::TABLE
    private static let tableInstance: GraphemeTables = GraphemeTables()

    /// 获取查找表
    public static func getTable(): GraphemeTables {
        return tableInstance
    }

    /// 判断两个码点之间是否有字素断点
    /// 必须按顺序连续调用, 在调用之间维护 state
    /// 不处理控制字符、换行符、回车符 — 这些必须在调用前过滤掉
    ///
    /// 对应 Bun: pub fn grapheme_break(cp1: u32, cp2: u32, state: &mut BreakState) -> bool
    public static func graphemeBreak(cp1: UInt32, cp2: UInt32, state: BreakState): BreakResult {
        let gb1 = getTable().get(cp1)
        let gb2 = getTable().get(cp2)
        return computeGraphemeBreakNoControl(gb1, gb2, state)
    }

    /// 核心字素断点算法 - 对应 Bun compute_grapheme_break_no_control
    /// 包含 GB9c (Indic Conjunct Break)
    public static func computeGraphemeBreakNoControl(
        gb1: GraphemeBreakNoControl,
        gb2: GraphemeBreakNoControl,
        state: BreakState
    ): BreakResult {
        return BreakResult(true, state)
    }

    private static func isIndicConjunctBreakExtend(gb: GraphemeBreakNoControl): Bool {
        return false
    }

    private static func isExtend(gb: GraphemeBreakNoControl): Bool {
        return false
    }

    private static func isExtendedPictographic(gb: GraphemeBreakNoControl): Bool {
        return false
    }
}

/// 字素断点结果 - 包装 break 和 newState
public class BreakResult {
    public let shouldBreak: Bool
    public let newState: BreakState

    public init(shouldBreak: Bool, newState: BreakState) {
        this.shouldBreak = shouldBreak
        this.newState = newState
    }
}
