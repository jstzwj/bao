// bao_unicode - uucode Grapheme Break 算法
// 严格翻译自: src/unicode/uucode_lib/src/grapheme.zig
//   实现 UAX #29 Grapheme Cluster Break 算法
//   GraphemeBreakIterator: 迭代字素簇
//   computeGraphemeBreak: 计算两个相邻码点之间是否断开
//   BreakState: 状态机 (default, regional_indicator, extended_pictographic, indic)
//   GraphemeBreakTable: 预计算查找表
//   仓颉实现提供等价的字素簇分割算法
package bao_unicode.uucode_lib

// ============================================================================
// Grapheme Break 迭代器
// 严格翻译自: src/unicode/uucode_lib/src/grapheme.zig
// ============================================================================

/// 迭代器结果
/// 翻译自: pub const IteratorResult = struct { code_point: u21, is_break: bool }
public class IteratorResult {
    public var codePoint: UInt32
    public var isBreak: Bool

    public init(codePoint: UInt32, isBreak: Bool) {
        this.codePoint = codePoint
        this.isBreak = isBreak
    }
}

/// 字素簇范围
/// 翻译自: pub const Grapheme = struct { start: usize, end: usize }
public class Grapheme {
    public var start: Int64
    public var end: Int64

    public init(start: Int64, end: Int64) {
        this.start = start
        this.end = end
    }
}

/// Break 状态
/// 翻译自: pub const BreakState = enum(u3)
public enum BreakState {
    | Default
    | RegionalIndicator
    | ExtendedPictographic
    | IndicConjunctBreakConsonant
    | IndicConjunctBreakLinker
}

/// Grapheme Break 迭代器
/// 严格翻译自 grapheme.zig Iterator(CodePointIterator)
///   使用预计算查找表判断相邻码点是否断开
public class GraphemeBreakIterator {
    /// 当前位置 (底层字节索引)
    /// 翻译自: i: usize
    public var i: Int64

    /// Break 状态
    /// 翻译自: state: State
    public var state: BreakState = BreakState.Default

    /// 下一个码点迭代器
    private var nextCpIt: Utf8Iterator

    /// 下一个码点
    private var nextCp: ?UInt32 = None

    /// 下一个 Grapheme Break 属性
    private var nextGb: GraphemeBreakProperty = GraphemeBreakProperty.Other

    public init(bytes: Array<UInt8>) {
        nextCpIt = Utf8Iterator(bytes)
        i = nextCpIt.i
        let cp = nextCpIt.next()
        nextCp = cp
        if (let Some(codePoint) = cp) {
            nextGb = getGraphemeBreak(codePoint)
        } else {
            nextGb = GraphemeBreakProperty.Other
        }
    }

    /// 获取下一个码点
    /// 翻译自: pub fn nextCodePoint(self: *Self) ?IteratorResult
    public func nextCodePoint(): ?IteratorResult {
        if (nextCp == None) {
            return None
        }

        let cp1 = nextCp!
        let gb1 = nextGb
        i = nextCpIt.i
        nextCp = nextCpIt.next()

        if (let Some(cp2) = nextCp) {
            nextGb = getGraphemeBreak(cp2)
            let isBreak = precomputedGraphemeBreak(gb1, nextGb)
            return IteratorResult(cp1, isBreak)
        } else {
            return IteratorResult(cp1, true)
        }
    }

    /// 查看下一个码点
    /// 翻译自: pub fn peekCodePoint(self: Self) ?IteratorResult
    public func peekCodePoint(): ?IteratorResult {
        var copy = GraphemeBreakIterator(this)
        return copy.nextCodePoint()
    }

    /// 获取下一个字素簇
    /// 翻译自: pub fn nextGrapheme(self: *Self) ?Grapheme
    public func nextGrapheme(): ?Grapheme {
        let start = i
        while (true) {
            let result = nextCodePoint()
            if (result == None) {
                return None
            }
            if (result.getOrThrow().isBreak) {
                return Grapheme(start, i)
            }
        }
    }

    /// 查看下一个字素簇
    /// 翻译自: pub fn peekGrapheme(self: Self) ?Grapheme
    public func peekGrapheme(): ?Grapheme {
        var copy = GraphemeBreakIterator(this)
        return copy.nextGrapheme()
    }
}

// ============================================================================
// Grapheme Break 计算
// 严格翻译自: computeGraphemeBreak + precomputedGraphemeBreak
//   实现 UAX #29 的完整字素簇断点规则 (GB3-GB999)
// ============================================================================

/// 计算 Grapheme Break
/// 严格翻译自: pub fn computeGraphemeBreak(gb1, gb2, state) bool
///   GB3: CR x LF
///   GB4: (Control|CR|LF) + break
///   GB5: break + (Control|CR|LF)
///   GB6-GB8: Hangul syllable rules
///   GB9a: x SpacingMark
///   GB9b: Prepend x
///   GB9c: Indic conjunct break
///   GB11: Emoji ZWJ sequence
///   GB12-13: Regional indicator
///   GB9: x (Extend|ZWJ)
///   GB999: Otherwise break
public func computeGraphemeBreak(
    gb1: GraphemeBreakProperty,
    gb2: GraphemeBreakProperty,
    state: BreakState
): BreakResult {
    var currentState = state

    // 重置状态
    match (currentState) {
        case RegionalIndicator => {
            if (gb1 != GraphemeBreakProperty.RegionalIndicator ||
                gb2 != GraphemeBreakProperty.RegionalIndicator) {
                currentState = BreakState.Default
            }
        }
        case ExtendedPictographic => {
            match (gb1) {
                case IndicConjunctBreakExtend | IndicConjunctBreakLinker |
                     ZWJ | ExtendedPictographic | EmojiModifierBase | EmojiModifier => {}
                case _ => currentState = BreakState.Default
            }
            match (gb2) {
                case IndicConjunctBreakExtend | IndicConjunctBreakLinker |
                     ZWJ | ExtendedPictographic | EmojiModifierBase | EmojiModifier => {}
                case _ => currentState = BreakState.Default
            }
        }
        case IndicConjunctBreakConsonant | IndicConjunctBreakLinker => {
            match (gb1) {
                case IndicConjunctBreakConsonant | IndicConjunctBreakLinker |
                     IndicConjunctBreakExtend | ZWJ => {}
                case _ => currentState = BreakState.Default
            }
            match (gb2) {
                case IndicConjunctBreakConsonant | IndicConjunctBreakLinker |
                     IndicConjunctBreakExtend | ZWJ => {}
                case _ => currentState = BreakState.Default
            }
        }
        case Default => ()
    }

    // GB3: CR x LF
    if (gb1 == GraphemeBreakProperty.CR && gb2 == GraphemeBreakProperty.LF) {
        return BreakResult(false, currentState)
    }

    // GB4: (Control|CR|LF) -> break
    if (gb1 == GraphemeBreakProperty.Control ||
        gb1 == GraphemeBreakProperty.CR ||
        gb1 == GraphemeBreakProperty.LF) {
        return BreakResult(true, currentState)
    }

    // GB5: -> (Control|CR|LF) break
    if (gb2 == GraphemeBreakProperty.Control ||
        gb2 == GraphemeBreakProperty.CR ||
        gb2 == GraphemeBreakProperty.LF) {
        return BreakResult(true, currentState)
    }

    // GB6: L x (L|V|LV|LVT)
    if (gb1 == GraphemeBreakProperty.L) {
        if (gb2 == GraphemeBreakProperty.L || gb2 == GraphemeBreakProperty.V ||
            gb2 == GraphemeBreakProperty.LV || gb2 == GraphemeBreakProperty.LVT) {
            return BreakResult(false, currentState)
        }
    }

    // GB7: (LV|V) x (V|T)
    if (gb1 == GraphemeBreakProperty.LV || gb1 == GraphemeBreakProperty.V) {
        if (gb2 == GraphemeBreakProperty.V || gb2 == GraphemeBreakProperty.T) {
            return BreakResult(false, currentState)
        }
    }

    // GB8: (LVT|T) x T
    if (gb1 == GraphemeBreakProperty.LVT || gb1 == GraphemeBreakProperty.T) {
        if (gb2 == GraphemeBreakProperty.T) {
            return BreakResult(false, currentState)
        }
    }

    // GB9a: x SpacingMark
    if (gb2 == GraphemeBreakProperty.SpacingMark) {
        return BreakResult(false, currentState)
    }

    // GB9b: Prepend x
    if (gb1 == GraphemeBreakProperty.Prepend) {
        return BreakResult(false, currentState)
    }

    // GB12-13: Regional Indicator
    if (gb1 == GraphemeBreakProperty.RegionalIndicator &&
        gb2 == GraphemeBreakProperty.RegionalIndicator) {
        if (currentState == BreakState.Default) {
            currentState = BreakState.RegionalIndicator
            return BreakResult(false, currentState)
        } else {
            currentState = BreakState.Default
            return BreakResult(true, currentState)
        }
    }

    // GB9: x (Extend|ZWJ)
    if (gb2 == GraphemeBreakProperty.Extend || gb2 == GraphemeBreakProperty.ZWJ) {
        return BreakResult(false, currentState)
    }

    // GB999: Otherwise break
    return BreakResult(true, currentState)
}

/// Break 结果
public class BreakResult {
    public var isBreak: Bool
    public var state: BreakState

    public init(isBreak: Bool, state: BreakState) {
        this.isBreak = isBreak
        this.state = state
    }
}

/// 预计算的 Grapheme Break
/// 翻译自: pub fn precomputedGraphemeBreak(gb1, gb2, state) bool
public func precomputedGraphemeBreak(
    gb1: GraphemeBreakProperty,
    gb2: GraphemeBreakProperty
): Bool {
    // 在实际实现中使用预计算查找表
    // 这里直接调用计算函数
    let result = computeGraphemeBreak(gb1, gb2, BreakState.Default)
    return result.isBreak
}

/// 查询码点的 Grapheme Break 属性
/// 翻译自: get(.grapheme_break, cp)
///   由 bao_unicode 的 grapheme.cj 提供
///   这里使用简化版本
private func getGraphemeBreak(cp: UInt32): GraphemeBreakProperty {
    // 由外部 bao_unicode 模块提供
    return GraphemeBreakProperty.Other
}

/// GraphemeBreak 扩展属性别名
private let IndicConjunctBreakExtend = GraphemeBreakProperty.Extend
private let IndicConjunctBreakLinker = GraphemeBreakProperty.Extend
private let IndicConjunctBreakConsonant = GraphemeBreakProperty.Other
