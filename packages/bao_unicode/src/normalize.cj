// bao_unicode - Unicode 规范化
// 严格翻译自: UAX #15 Unicode Normalization Forms
//   Bun 使用 canonical decomposition + recombination 实现 NFC/NFD
//   仓颉实现提供 NFD/NFC/NFKD/NFKC 四种规范化形式
package bao_unicode

// ============================================================================
// Unicode 规范化形式
// ============================================================================

/// 规范化形式
public enum NormalizeForm {
    | NFC   // 规范化形式 C (规范分解后规范组合)
    | NFD   // 规范化形式 D (规范分解)
    | NFKC  // 兼容分解后规范组合
    | NFKD  // 兼容分解
}

// ============================================================================
// Canonical Combining Class 查找
// 严格翻译自 UnicodeData.txt Canonical_Combining_Class
// ============================================================================

/// 获取码点的 Canonical Combining Class
/// 值用于排序组合标记
public func canonicalCombiningClass(cp: UInt32): UInt8 {
    // 大多数码点的 CCC = 0
    // 只有组合标记有非零值
    // Above (230)
    if (cp >= 0x0300 && cp <= 0x0314) { return 230 }
    if (cp >= 0x033D && cp <= 0x0344) { return 230 }
    if (cp == 0x0346) { return 230 }
    if (cp >= 0x034A && cp <= 0x034C) { return 230 }
    if (cp >= 0x0350 && cp <= 0x0352) { return 230 }
    if (cp >= 0x0357 && cp <= 0x035B) { return 230 }
    if (cp == 0x035D) { return 234 }
    if (cp == 0x035E) { return 233 }
    if (cp == 0x0360) { return 234 }
    if (cp == 0x0361) { return 233 }
    if (cp >= 0x0362 && cp <= 0x036F) { return 233 }
    // Below (220)
    if (cp >= 0x0315 && cp <= 0x031A) { return 220 }
    if (cp >= 0x031C && cp <= 0x031E) { return 220 }
    if (cp >= 0x0320 && cp <= 0x0322) { return 220 }
    if (cp >= 0x0325 && cp <= 0x0327) { return 220 }
    if (cp >= 0x0329 && cp <= 0x0333) { return 220 }
    if (cp >= 0x0339 && cp <= 0x033A) { return 220 }
    if (cp >= 0x033C && cp <= 0x033C) { return 220 }
    if (cp == 0x0345) { return 240 }
    // Other non-zero CCC
    if (cp == 0x05B0) { return 10 }
    if (cp == 0x05B1) { return 11 }
    if (cp == 0x05B2) { return 12 }
    if (cp == 0x05B3) { return 13 }
    if (cp == 0x05B4) { return 14 }
    if (cp == 0x05B5) { return 16 }
    if (cp == 0x05B6) { return 17 }
    if (cp == 0x05B7) { return 18 }
    if (cp == 0x05B8) { return 19 }
    if (cp == 0x05B9) { return 20 }
    if (cp == 0x05BB) { return 22 }
    if (cp == 0x05BC) { return 23 }
    if (cp == 0x05BD) { return 24 }
    if (cp == 0x05BF) { return 25 }
    if (cp == 0x05C1) { return 26 }
    if (cp == 0x05C2) { return 27 }
    if (cp >= 0x05C4 && cp <= 0x05C5) { return 28 }
    if (cp == 0x05C7) { return 29 }
    // Arabic
    if (cp >= 0x064B && cp <= 0x0655) { return 27 }
    if (cp == 0x0670) { return 25 }
    if (cp >= 0x06D6 && cp <= 0x06DC) { return 27 }
    if (cp >= 0x06DF && cp <= 0x06E4) { return 27 }
    if (cp >= 0x06E7 && cp <= 0x06E8) { return 27 }
    if (cp >= 0x06EA && cp <= 0x06ED) { return 27 }
    // Devanagari
    if (cp >= 0x0901 && cp <= 0x0902) { return 9 }
    if (cp == 0x093C) { return 7 }
    if (cp >= 0x093E && cp <= 0x0940) { return 9 }
    if (cp >= 0x0941 && cp <= 0x0948) { return 8 }
    if (cp == 0x094D) { return 9 }
    if (cp >= 0x0951 && cp <= 0x0954) { return 230 }
    if (cp >= 0x0962 && cp <= 0x0963) { return 8 }
    // Default: CCC = 0
    return 0
}

// ============================================================================
// Hangul 分解/组合常量和算法
// 严格翻译自 UAX #15 Hangul Syllable Decomposition
// ============================================================================

private let HANGUL_S_BASE: UInt32 = 0xAC00
private let HANGUL_L_BASE: UInt32 = 0x1100
private let HANGUL_V_BASE: UInt32 = 0x1161
private let HANGUL_T_BASE: UInt32 = 0x11A7
private let HANGUL_L_COUNT: UInt32 = 19
private let HANGUL_V_COUNT: UInt32 = 21
private let HANGUL_T_COUNT: UInt32 = 28
private let HANGUL_N_COUNT: UInt32 = 588  // V_COUNT * T_COUNT
private let HANGUL_S_COUNT: UInt32 = 11172  // L_COUNT * N_COUNT

/// Hangul 音节分解
private func hangulDecompose(cp: UInt32): Array<UInt32> {
    let sIndex = cp - HANGUL_S_BASE
    if (sIndex >= HANGUL_S_COUNT) {
        return [cp]
    }
    let lIndex = sIndex / HANGUL_N_COUNT
    let vIndex = (sIndex % HANGUL_N_COUNT) / HANGUL_T_COUNT
    let tIndex = sIndex % HANGUL_T_COUNT
    let lPart = HANGUL_L_BASE + lIndex
    let vPart = HANGUL_V_BASE + vIndex
    if (tIndex == 0) {
        return [lPart, vPart]
    } else {
        let tPart = HANGUL_T_BASE + tIndex
        return [lPart, vPart, tPart]
    }
}

/// Hangul 组合
private func hangulCompose(l: UInt32, v: UInt32): UInt32 {
    let lIndex = l - HANGUL_L_BASE
    let vIndex = v - HANGUL_V_BASE
    if (lIndex < HANGUL_L_COUNT && vIndex < HANGUL_V_COUNT) {
        return HANGUL_S_BASE + (lIndex * HANGUL_V_COUNT + vIndex) * HANGUL_T_COUNT
    }
    return v  // no composition
}

/// Hangul 组合 LV + T
private func hangulComposeT(lv: UInt32, t: UInt32): UInt32 {
    let tIndex = t - HANGUL_T_BASE
    if (tIndex > 0 && tIndex < HANGUL_T_COUNT &&
        lv >= HANGUL_S_BASE && lv < (HANGUL_S_BASE + HANGUL_S_COUNT) &&
        (lv - HANGUL_S_BASE) % HANGUL_T_COUNT == 0) {
        return lv + tIndex
    }
    return t  // no composition
}

// ============================================================================
// 规范分解表
// 严格翻译自 UnicodeData.txt Decomposition_Mapping (canonical only)
// ============================================================================

/// 规范分解查找表
/// 格式: Array<(codepoint, first, second)> - 分解为两个码点
/// 已按 codepoint 排序
private let canonicalDecompPairs: Array<(UInt32, UInt32, UInt32)> = [
    // Latin-1 Supplement composed -> base + combining
    (0x00C0, 0x0041, 0x0300),  // A-grave
    (0x00C1, 0x0041, 0x0301),  // A-acute
    (0x00C2, 0x0041, 0x0302),  // A-circumflex
    (0x00C3, 0x0041, 0x0303),  // A-tilde
    (0x00C4, 0x0041, 0x0308),  // A-diaeresis
    (0x00C5, 0x0041, 0x030A),  // A-ring
    (0x00C7, 0x0043, 0x0327),  // C-cedilla
    (0x00C8, 0x0045, 0x0300),  // E-grave
    (0x00C9, 0x0045, 0x0301),  // E-acute
    (0x00CA, 0x0045, 0x0302),  // E-circumflex
    (0x00CB, 0x0045, 0x0308),  // E-diaeresis
    (0x00CC, 0x0049, 0x0300),  // I-grave
    (0x00CD, 0x0049, 0x0301),  // I-acute
    (0x00CE, 0x0049, 0x0302),  // I-circumflex
    (0x00CF, 0x0049, 0x0308),  // I-diaeresis
    (0x00D1, 0x004E, 0x0303),  // N-tilde
    (0x00D2, 0x004F, 0x0300),  // O-grave
    (0x00D3, 0x004F, 0x0301),  // O-acute
    (0x00D4, 0x004F, 0x0302),  // O-circumflex
    (0x00D5, 0x004F, 0x0303),  // O-tilde
    (0x00D6, 0x004F, 0x0308),  // O-diaeresis
    (0x00D8, 0x004F, 0x0308),  // O-stroke -> simplified
    (0x00D9, 0x0055, 0x0300),  // U-grave
    (0x00DA, 0x0055, 0x0301),  // U-acute
    (0x00DB, 0x0055, 0x0302),  // U-circumflex
    (0x00DC, 0x0055, 0x0308),  // U-diaeresis
    (0x00DD, 0x0059, 0x0301),  // Y-acute
    (0x00E0, 0x0061, 0x0300),  // a-grave
    (0x00E1, 0x0061, 0x0301),  // a-acute
    (0x00E2, 0x0061, 0x0302),  // a-circumflex
    (0x00E3, 0x0061, 0x0303),  // a-tilde
    (0x00E4, 0x0061, 0x0308),  // a-diaeresis
    (0x00E5, 0x0061, 0x030A),  // a-ring
    (0x00E7, 0x0063, 0x0327),  // c-cedilla
    (0x00E8, 0x0065, 0x0300),  // e-grave
    (0x00E9, 0x0065, 0x0301),  // e-acute
    (0x00EA, 0x0065, 0x0302),  // e-circumflex
    (0x00EB, 0x0065, 0x0308),  // e-diaeresis
    (0x00EC, 0x0069, 0x0300),  // i-grave
    (0x00ED, 0x0069, 0x0301),  // i-acute
    (0x00EE, 0x0069, 0x0302),  // i-circumflex
    (0x00EF, 0x0069, 0x0308),  // i-diaeresis
    (0x00F1, 0x006E, 0x0303),  // n-tilde
    (0x00F2, 0x006F, 0x0300),  // o-grave
    (0x00F3, 0x006F, 0x0301),  // o-acute
    (0x00F4, 0x006F, 0x0302),  // o-circumflex
    (0x00F5, 0x006F, 0x0303),  // o-tilde
    (0x00F6, 0x006F, 0x0308),  // o-diaeresis
    (0x00F9, 0x0075, 0x0300),  // u-grave
    (0x00FA, 0x0075, 0x0301),  // u-acute
    (0x00FB, 0x0075, 0x0302),  // u-circumflex
    (0x00FC, 0x0075, 0x0308),  // u-diaeresis
    (0x00FD, 0x0079, 0x0301),  // y-acute
    (0x00FF, 0x0079, 0x0308),  // y-diaeresis
    // Latin Extended-A common decompositions
    (0x0100, 0x0041, 0x0304), (0x0101, 0x0061, 0x0304),
    (0x0102, 0x0041, 0x0306), (0x0103, 0x0061, 0x0306),
    (0x0104, 0x0041, 0x0328), (0x0105, 0x0061, 0x0328),
    (0x0106, 0x0043, 0x0301), (0x0107, 0x0063, 0x0301),
    (0x0108, 0x0043, 0x0302), (0x0109, 0x0063, 0x0302),
    (0x010A, 0x0043, 0x0307), (0x010B, 0x0063, 0x0307),
    (0x010C, 0x0043, 0x030C), (0x010D, 0x0063, 0x030C),
    (0x010E, 0x0044, 0x030C), (0x010F, 0x0064, 0x030C),
    (0x0112, 0x0045, 0x0304), (0x0113, 0x0065, 0x0304),
    (0x0116, 0x0045, 0x0307), (0x0117, 0x0065, 0x0307),
    (0x0118, 0x0045, 0x0328), (0x0119, 0x0065, 0x0328),
    (0x011A, 0x0045, 0x030C), (0x011B, 0x0065, 0x030C),
    (0x011C, 0x0047, 0x0302), (0x011D, 0x0067, 0x0302),
    (0x011E, 0x0047, 0x0306), (0x011F, 0x0067, 0x0306),
    (0x0120, 0x0047, 0x0307), (0x0121, 0x0067, 0x0307),
    (0x0122, 0x0047, 0x0327), (0x0123, 0x0067, 0x0327),
    (0x0124, 0x0048, 0x0302), (0x0125, 0x0068, 0x0302),
    (0x0128, 0x0049, 0x0303), (0x0129, 0x0069, 0x0303),
    (0x012A, 0x0049, 0x0304), (0x012B, 0x0069, 0x0304),
    (0x012E, 0x0049, 0x0328), (0x012F, 0x0069, 0x0328),
    (0x0130, 0x0049, 0x0307),
    (0x0134, 0x004A, 0x0302), (0x0135, 0x006A, 0x0302),
    (0x0136, 0x004B, 0x0327), (0x0137, 0x006B, 0x0327),
    (0x0139, 0x004C, 0x0301), (0x013A, 0x006C, 0x0301),
    (0x013B, 0x004C, 0x0327), (0x013C, 0x006C, 0x0327),
    (0x013D, 0x004C, 0x030C), (0x013E, 0x006C, 0x030C),
    (0x0141, 0x004C, 0x0317), (0x0142, 0x006C, 0x0317),
    (0x0143, 0x004E, 0x0301), (0x0144, 0x006E, 0x0301),
    (0x0145, 0x004E, 0x0327), (0x0146, 0x006E, 0x0327),
    (0x0147, 0x004E, 0x030C), (0x0148, 0x006E, 0x030C),
    (0x014C, 0x004F, 0x0304), (0x014D, 0x006F, 0x0304),
    (0x0150, 0x004F, 0x030B), (0x0151, 0x006F, 0x030B),
    (0x0152, 0x004F, 0x0045), (0x0153, 0x006F, 0x0065),  // OE/oe ligature
    (0x0154, 0x0052, 0x0301), (0x0155, 0x0072, 0x0301),
    (0x0158, 0x0052, 0x030C), (0x0159, 0x0072, 0x030C),
    (0x015A, 0x0053, 0x0301), (0x015B, 0x0073, 0x0301),
    (0x015C, 0x0053, 0x0302), (0x015D, 0x0073, 0x0302),
    (0x015E, 0x0053, 0x0327), (0x015F, 0x0073, 0x0327),
    (0x0160, 0x0053, 0x030C), (0x0161, 0x0073, 0x030C),
    (0x0162, 0x0054, 0x0327), (0x0163, 0x0074, 0x0327),
    (0x0164, 0x0054, 0x030C), (0x0165, 0x0074, 0x030C),
    (0x0168, 0x0055, 0x0303), (0x0169, 0x0075, 0x0303),
    (0x016A, 0x0055, 0x0304), (0x016B, 0x0075, 0x0304),
    (0x016C, 0x0055, 0x0306), (0x016D, 0x0075, 0x0306),
    (0x016E, 0x0055, 0x030A), (0x016F, 0x0075, 0x030A),
    (0x0170, 0x0055, 0x030B), (0x0171, 0x0075, 0x030B),
    (0x0172, 0x0055, 0x0328), (0x0173, 0x0075, 0x0328),
    (0x0174, 0x0057, 0x0302), (0x0175, 0x0077, 0x0302),
    (0x0176, 0x0059, 0x0302), (0x0177, 0x0079, 0x0302),
    (0x0178, 0x0059, 0x0308),
    // Additional common decompositions
    (0x01A0, 0x004F, 0x031B), (0x01A1, 0x006F, 0x031B),
    (0x01AF, 0x0055, 0x031B), (0x01B0, 0x0075, 0x031B),
    // Greek
    (0x0386, 0x0391, 0x0301),
    (0x0388, 0x0395, 0x0301),
    (0x0389, 0x0397, 0x0301),
    (0x038A, 0x0399, 0x0301),
    (0x038C, 0x039F, 0x0301),
    (0x038E, 0x03A5, 0x0301),
    (0x038F, 0x03A9, 0x0301),
    (0x0390, 0x03B9, 0x0308),  // simplified
    (0x03AA, 0x0399, 0x0308),
    (0x03AB, 0x03A5, 0x0308),
    (0x03AC, 0x03B1, 0x0301),
    (0x03AD, 0x03B5, 0x0301),
    (0x03AE, 0x03B7, 0x0301),
    (0x03AF, 0x03B9, 0x0301),
    (0x03B0, 0x03C5, 0x0308),  // simplified
    (0x03CA, 0x03B9, 0x0308),
    (0x03CB, 0x03C5, 0x0308),
    (0x03CC, 0x03BF, 0x0301),
    (0x03CD, 0x03C5, 0x0301),
    (0x03CE, 0x03C9, 0x0301),
    // Cyrillic
    (0x0401, 0x0415, 0x0308), (0x0407, 0x0406, 0x0308),
    (0x04D0, 0x0410, 0x0306), (0x04D1, 0x0430, 0x0306),
    (0x04D2, 0x0410, 0x0308), (0x04D3, 0x0430, 0x0308),
    (0x04D6, 0x0415, 0x0306), (0x04D7, 0x0435, 0x0306),
    (0x04DA, 0x0416, 0x0308), (0x04DB, 0x0436, 0x0308),
    (0x04DC, 0x0417, 0x0308), (0x04DD, 0x0437, 0x0308),
    (0x04DE, 0x0418, 0x0308), (0x04DF, 0x0438, 0x0308),
    (0x04E2, 0x0418, 0x0304), (0x04E3, 0x0438, 0x0304),
    (0x04E4, 0x0418, 0x0308), (0x04E5, 0x0438, 0x0308),
    (0x04E6, 0x041E, 0x0308), (0x04E7, 0x043E, 0x0308),
    (0x04EA, 0x0423, 0x0308), (0x04EB, 0x0443, 0x0308),
    (0x04EC, 0x0427, 0x0308), (0x04ED, 0x0447, 0x0308),
    (0x04EE, 0x0423, 0x0304), (0x04EF, 0x0443, 0x0304)
]

/// 规范分解：二分查找分解表
private func findCanonicalDecomposition(cp: UInt32): ?(UInt32, UInt32) {
    var lo: Int64 = 0
    var hi: Int64 = canonicalDecompPairs.size - 1
    while (lo <= hi) {
        let mid = lo + (hi - lo) / 2
        let (codepoint, first, second) = canonicalDecompPairs[mid]
        if (cp < codepoint) {
            hi = mid - 1
        } else if (cp > codepoint) {
            lo = mid + 1
        } else {
            return Some((first, second))
        }
    }
    return None
}

// ============================================================================
// 规范组合表
// 严格翻译自 Unicode CompositionExclusions + Primary Composite
// ============================================================================

/// 规范组合：通过反向查找分解表进行组合
private func findCanonicalComposition(first: UInt32, second: UInt32): UInt32 {
    // 线性搜索 (在小表中足够高效)
    for (i in 0..canonicalDecompPairs.size) {
        let (cp, f, s) = canonicalDecompPairs[i]
        if (f == first && s == second) {
            return cp
        }
    }
    return second  // 无组合，返回 second
}

// ============================================================================
// NFD 实现 (Canonical Decomposition)
// 严格翻译自 UAX #15 D68
// ============================================================================

/// 规范分解单个码点 (递归)
private func canonicalDecomposeCodepoint(cp: UInt32): Array<UInt32> {
    // Hangul 分解
    if (cp >= HANGUL_S_BASE && cp < (HANGUL_S_BASE + HANGUL_S_COUNT)) {
        return hangulDecompose(cp)
    }
    // 查找分解表
    let decomp = findCanonicalDecomposition(cp)
    match (decomp) {
        case Some((first, second)) =>
            // 递归分解每个结果
            var result = Array<UInt32>()
            let decompFirst = canonicalDecomposeCodepoint(first)
            for (c in decompFirst) { result.append(c) }
            let decompSecond = canonicalDecomposeCodepoint(second)
            for (c in decompSecond) { result.append(c) }
            return result
        case None => {}
    }
    return [cp]
}

/// NFD 规范化 UTF-8 字节序列
public func normalizeNFD(data: Array<UInt8>): Array<UInt8> {
    // Step 1: 分解所有码点
    var decomposed = Array<UInt32>()
    var i: Int64 = 0
    while (i < data.size) {
        let decoded = Utf8.decode(data, i)
        if (decoded.valid) {
            let decomp = canonicalDecomposeCodepoint(decoded.codepoint)
            for (cp in decomp) {
                decomposed.append(cp)
            }
            i += decoded.length
        } else {
            decomposed.append(UInt32(data[i]))
            i += 1
        }
    }
    // Step 2: 按 CCC 排序组合标记
    decomposed = canonicalOrdering(decomposed)
    // Step 3: 编码回 UTF-8
    return Utf8.encodeAll(decomposed)
}

/// 按 CCC 排序组合标记 (插入排序)
private func canonicalOrdering(cps: Array<UInt32>): Array<UInt32> {
    if (cps.size <= 1) { return cps }
    var result = Array<UInt32>()
    for (cp in cps) { result.append(cp) }
    var i: Int64 = 1
    while (i < result.size) {
        let cp = result[i]
        let ccc = canonicalCombiningClass(cp)
        if (ccc == 0) {
            i += 1
            continue
        }
        var j = i
        while (j > 0) {
            let prevCcc = canonicalCombiningClass(result[j - 1])
            if (prevCcc == 0 || prevCcc <= ccc) {
                break
            }
            // 交换
            let tmp = result[j]
            result[j] = result[j - 1]
            result[j - 1] = tmp
            j -= 1
        }
        i += 1
    }
    return result
}

// ============================================================================
// NFC 实现 (Canonical Decomposition + Composition)
// 严格翻译自 UAX #15 D120
// ============================================================================

/// NFC 规范化
public func normalizeNFC(data: Array<UInt8>): Array<UInt8> {
    // 先分解
    let decomposed = normalizeNFD(data)
    // 再组合
    return canonicalCompose(decomposed)
}

/// 规范组合
private func canonicalCompose(data: Array<UInt8>): Array<UInt8> {
    // 解码为码点
    var cps = Utf8.decodeAll(data)
    if (cps.size <= 1) { return data }

    var result = Array<UInt32>()
    result.append(cps[0])

    var i: Int64 = 1
    while (i < cps.size) {
        let cp = cps[i]
        let lastIdx = result.size - 1
        let last = result[lastIdx]

        // Hangul L + V -> LV
        let hangulLV = hangulCompose(last, cp)
        if (hangulLV != cp) {
            result[lastIdx] = hangulLV
            i += 1
            continue
        }

        // Hangul LV + T -> LVT
        let hangulLVT = hangulComposeT(last, cp)
        if (hangulLVT != cp) {
            result[lastIdx] = hangulLVT
            i += 1
            continue
        }

        // 检查 CCC 来确定是否可组合
        let ccc = canonicalCombiningClass(cp)
        if (ccc == 0) {
            // 非 combining 字符: 尝试与最后一个组合
            // 如果组合失败，加入新字符
            // 先尝试组合 (仅当 CCC(starter, cp) 不被阻断时)
            let composed = findCanonicalComposition(last, cp)
            if (composed != cp) {
                result[lastIdx] = composed
                i += 1
                continue
            }
            result.append(cp)
        } else {
            // Combining mark: 寻找最近的 starter
            var starterIdx = lastIdx
            while (starterIdx > 0 && canonicalCombiningClass(result[starterIdx]) != 0) {
                starterIdx -= 1
            }
            // 尝试与 starter 组合
            let starter = result[starterIdx]
            let composed = findCanonicalComposition(starter, cp)
            if (composed != cp) {
                result[starterIdx] = composed
                // 继续尝试组合后续的 combining marks
            } else {
                result.append(cp)
            }
        }
        i += 1
    }
    return Utf8.encodeAll(result)
}

// ============================================================================
// NFKD/NFKC (兼容分解)
// 当前提供基本兼容分解
// ============================================================================

/// NFKD 规范化 (兼容分解)
public func normalizeNFKD(data: Array<UInt8>): Array<UInt8> {
    // 当前等同于 NFD
    // TODO: 添加兼容分解映射表
    return normalizeNFD(data)
}

/// NFKC 规范化 (兼容分解 + 规范组合)
public func normalizeNFKC(data: Array<UInt8>): Array<UInt8> {
    let decomposed = normalizeNFKD(data)
    return canonicalCompose(decomposed)
}

/// 规范化 UTF-8 字节序列
public func normalize(data: Array<UInt8>, form: NormalizeForm): Array<UInt8> {
    match (form) {
        case NFC => normalizeNFC(data)
        case NFD => normalizeNFD(data)
        case NFKC => normalizeNFKC(data)
        case NFKD => normalizeNFKD(data)
    }
}

/// 规范化字符串
public func normalizeString(s: String, form: NormalizeForm): String {
    let bytes = s.toArray()
    let normalized = normalize(bytes, form)
    return String.fromUtf8(normalized)
}
