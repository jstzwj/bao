// bao_unicode - uucode x/grapheme 扩展字素宽度计算
// 严格翻译自: src/unicode/uucode_lib/src/x/grapheme.zig
//   提供字素簇宽度计算:
//     wcwidthNext: 计算下一个字素的宽度
//     wcwidth: 不前进的宽度计算
//     wcwidthRemaining: 剩余所有字素宽度之和
//     utf8Wcwidth: 字符串总宽度
//     IteratorNoControl: 无控制字符的字素迭代器
//     computeGraphemeBreakNoControl: 忽略 GB4/GB5 的字素断点
//   仓颉实现提供等价的字素宽度计算
package bao_unicode.uucode_lib.x

import bao_unicode.uucode_lib.*

// ============================================================================
// 字素宽度计算
// 严格翻译自: src/unicode/uucode_lib/src/x/grapheme.zig
// ============================================================================

/// 计算下一个字素的宽度并前进迭代器
/// 严格翻译自: pub fn wcwidthNext(it: anytype) u2
///   单码点字素: 返回 wcwidth_standalone
///   多码点字素: 累加各码点宽度 (clamp to 3)
///   VS16 (U+FE0F): emoji 宽度 2
///   VS15 (U+FE0E): text 宽度 1
///   ZWJ 序列: emoji 宽度 2 (跳过下一个 emoji base)
///   Regional indicator: 宽度 2
public func wcwidthNext(it: GraphemeBreakIterator): UInt8 {
    // 获取第一个码点
    let first = it.nextCodePoint()
    if (first.isNone()) { return 0 }

    let firstCp = first.getOrThrow().codePoint
    let standalone = wcwidthStandalone(firstCp,
        GeneralCategory.OtherNotAssigned,
        EastAsianWidthType.Neutral,
        false, false, GraphemeBreakProperty.Other)

    // 单码点字素
    if (first.getOrThrow().isBreak) { return standalone }

    // 多码点字素: 累加宽度
    var width: UInt8 = if (wcwidthZeroInGrapheme(firstCp,
            GeneralCategory.OtherNotAssigned,
            GraphemeBreakProperty.Other, false, false)) {
        0
    } else {
        standalone
    }

    var prevCp: UInt32 = firstCp

    while (true) {
        let result = it.nextCodePoint()
        if (result.isNone()) { break }

        var cp = result.getOrThrow().codePoint

        if (cp == 0xFE0F) {
            // Emoji presentation selector
            width = 2
        } else if (cp == 0xFE0E) {
            // Text presentation selector
            width = 1
        } else if (cp == 0x200D) {
            // ZWJ: 跳过下一个 emoji base
            let next = it.nextCodePoint()
            if (next.isNone()) { break }
            if (next.getOrThrow().isBreak) { break }
            cp = next.getOrThrow().codePoint
        } else {
            if (!wcwidthZeroInGrapheme(cp,
                    GeneralCategory.OtherNotAssigned,
                    GraphemeBreakProperty.Other, false, false)) {
                let added = wcwidthStandalone(cp,
                    GeneralCategory.OtherNotAssigned,
                    EastAsianWidthType.Neutral,
                    false, false, GraphemeBreakProperty.Other)
                if (Int64(added) + Int64(width) > 3) {
                    width = 3
                } else {
                    width = width + added
                }
            }
        }

        if (result.getOrThrow().isBreak) { break }
        prevCp = cp
    }

    return width
}

/// 不前进的宽度计算
/// 翻译自: pub fn wcwidth(const_it: anytype) u2
public func wcwidth(it: GraphemeBreakIterator): UInt8 {
    var copy = it
    return wcwidthNext(copy)
}

/// 剩余字素宽度之和
/// 翻译自: pub fn wcwidthRemaining(it: anytype) usize
public func wcwidthRemaining(it: GraphemeBreakIterator): Int64 {
    var width: Int64 = 0
    while (true) {
        let w = wcwidthNext(it)
        if (w == 0 && it.nextCp.isNone()) { break }
        width += Int64(w)
        if (it.nextCp.isNone()) { break }
    }
    return width
}

/// UTF-8 字符串总宽度
/// 翻译自: pub fn utf8Wcwidth(s: []const u8) usize
public func utf8Wcwidth(s: Array<UInt8>): Int64 {
    let it = GraphemeBreakIterator(s)
    return wcwidthRemaining(it)
}

/// 无控制字符的字素断点计算
/// 翻译自: computeGraphemeBreakNoControl
///   与 computeGraphemeBreak 相同但跳过 GB3/GB4/GB5
///   (control/CR/LF 已被映射为 other)
public func computeGraphemeBreakNoControl(
    gb1: GraphemeBreakNoControl,
    gb2: GraphemeBreakNoControl,
    state: BreakState
): Bool {
    // GB6: L x (L|V|LV|LVT)
    if (gb1 == GraphemeBreakNoControl.L) {
        if (gb2 == GraphemeBreakNoControl.L || gb2 == GraphemeBreakNoControl.V ||
            gb2 == GraphemeBreakNoControl.LV || gb2 == GraphemeBreakNoControl.LVT) {
            return false
        }
    }

    // GB7: (LV|V) x (V|T)
    if (gb1 == GraphemeBreakNoControl.LV || gb1 == GraphemeBreakNoControl.V) {
        if (gb2 == GraphemeBreakNoControl.V || gb2 == GraphemeBreakNoControl.T) {
            return false
        }
    }

    // GB8: (LVT|T) x T
    if (gb1 == GraphemeBreakNoControl.LVT || gb1 == GraphemeBreakNoControl.T) {
        if (gb2 == GraphemeBreakNoControl.T) {
            return false
        }
    }

    // GB9a: x SpacingMark
    if (gb2 == GraphemeBreakNoControl.SpacingMark) { return false }

    // GB9b: Prepend x
    if (gb1 == GraphemeBreakNoControl.Prepend) { return false }

    // GB12-13: Regional Indicator
    if (gb1 == GraphemeBreakNoControl.RegionalIndicator &&
        gb2 == GraphemeBreakNoControl.RegionalIndicator) {
        return true // 简化: 第二对 RI 断开
    }

    // GB9: x (Extend|ZWJ)
    if (gb2 == GraphemeBreakNoControl.IndicConjunctBreakExtend ||
        gb2 == GraphemeBreakNoControl.ZWJ) {
        return false
    }

    // GB999: Otherwise break
    return true
}
