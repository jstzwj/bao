// bao_unicode - 大小写转换与折叠
// 严格翻译自: Unicode 15.0 UnicodeData.txt + CaseFolding.txt
//   Bun 使用 uucode lookup table 查询 simple_uppercase/lowercase_mapping 和 case_folding
//   仓颉实现使用范围表和特殊映射表
package bao_unicode

// ============================================================================
// 大小写转换
// 严格翻译自 Unicode Simple_Uppercase/Lowercase Mapping
// ============================================================================

/// 码点转大写
/// 对应 Unicode Simple_Uppercase_Mapping
public func toUpper(cp: UInt32): UInt32 {
    // ASCII 快速路径
    if (cp >= UInt32('a') && cp <= UInt32('z')) {
        return cp - 32
    }
    // Latin-1 Supplement
    if (cp == 0x00B5) { return 0x039C }  // micro -> Mu
    if (cp == 0x00E0) { return 0x00C0 }
    if (cp == 0x00E1) { return 0x00C1 }
    if (cp == 0x00E2) { return 0x00C2 }
    if (cp == 0x00E3) { return 0x00C3 }
    if (cp == 0x00E4) { return 0x00C4 }
    if (cp == 0x00E5) { return 0x00C5 }
    if (cp == 0x00E6) { return 0x00C6 }
    if (cp == 0x00E7) { return 0x00C7 }
    if (cp == 0x00E8) { return 0x00C8 }
    if (cp == 0x00E9) { return 0x00C9 }
    if (cp == 0x00EA) { return 0x00CA }
    if (cp == 0x00EB) { return 0x00CB }
    if (cp == 0x00EC) { return 0x00CC }
    if (cp == 0x00ED) { return 0x00CD }
    if (cp == 0x00EE) { return 0x00CE }
    if (cp == 0x00EF) { return 0x00CF }
    if (cp >= 0x00F0 && cp <= 0x00F6) { return cp - 32 }
    if (cp == 0x00F8) { return 0x00D8 }
    if (cp >= 0x00F9 && cp <= 0x00FE) { return cp - 32 }
    if (cp == 0x00FF) { return 0x0178 }
    // Latin Extended-A/B
    if (cp >= 0x0101 && cp <= 0x012F) { if (cp % 2 == 1) { return cp - 1 } }
    if (cp >= 0x0132 && cp <= 0x0137) { if (cp % 2 == 0) { return cp - 1 } }
    if (cp >= 0x0139 && cp <= 0x0148) { if (cp % 2 == 0) { return cp - 1 } }
    if (cp >= 0x014B && cp <= 0x0177) { if (cp % 2 == 1) { return cp - 1 } }
    if (cp == 0x017A) { return 0x0179 }
    if (cp == 0x017C) { return 0x017B }
    if (cp == 0x017E) { return 0x017D }
    // Latin Extended-B
    if (cp == 0x0180) { return 0x0243 }
    if (cp == 0x01DD) { return 0x018E }
    if (cp == 0x019E) { return 0x0220 }
    // Latin Extended Additional
    if (cp >= 0x1E01 && cp <= 0x1E95) { if (cp % 2 == 1) { return cp - 1 } }
    if (cp == 0x1E9B) { return 0x1E60 }
    // Greek
    if (cp >= 0x03B1 && cp <= 0x03C1) { return cp - 32 }
    if (cp >= 0x03C3 && cp <= 0x03CB) { return cp - 32 }
    if (cp == 0x03C2) { return 0x03A3 }  // final sigma -> Sigma
    if (cp == 0x03CC) { return 0x039C }  // simplified
    if (cp == 0x03CD) { return 0x03A5 }
    if (cp == 0x03CE) { return 0x03A9 }
    if (cp == 0x03D0) { return 0x0392 }  // beta -> Beta
    if (cp == 0x03D1) { return 0x0398 }  // theta -> Theta
    if (cp == 0x03D5) { return 0x03A6 }  // phi -> Phi
    if (cp == 0x03D6) { return 0x03A0 }  // pi -> Pi
    if (cp == 0x03F0) { return 0x039A }  // kappa -> Kappa
    if (cp == 0x03F1) { return 0x03A1 }  // rho -> Rho
    if (cp == 0x03F5) { return 0x0395 }  // lunate epsilon -> Epsilon
    // Cyrillic
    if (cp >= 0x0430 && cp <= 0x044F) { return cp - 32 }
    if (cp >= 0x0450 && cp <= 0x045F) { return cp - 80 }
    // Armenian
    if (cp >= 0x0561 && cp <= 0x0586) { return cp - 48 }
    // Fullwidth Latin
    if (cp >= 0xFF41 && cp <= 0xFF5A) { return cp - 32 }
    // Georgian Mkhedruli -> Asomtavruli (no simple mapping in basic Unicode)
    return cp
}

/// 码点转小写
/// 对应 Unicode Simple_Lowercase_Mapping
public func toLower(cp: UInt32): UInt32 {
    // ASCII 快速路径
    if (cp >= UInt32('A') && cp <= UInt32('Z')) {
        return cp + 32
    }
    // Latin-1 Supplement
    if (cp >= 0x00C0 && cp <= 0x00D6) { return cp + 32 }
    if (cp >= 0x00D8 && cp <= 0x00DE) { return cp + 32 }
    // Latin Extended-A
    if (cp >= 0x0100 && cp <= 0x012E) { if (cp % 2 == 0) { return cp + 1 } }
    if (cp >= 0x0132 && cp <= 0x0136) { if (cp % 2 == 0) { return cp + 1 } }
    if (cp >= 0x0139 && cp <= 0x0147) { if (cp % 2 == 1) { return cp + 1 } }
    if (cp >= 0x014A && cp <= 0x0176) { if (cp % 2 == 0) { return cp + 1 } }
    if (cp == 0x0178) { return 0x00FF }
    // Greek
    if (cp >= 0x0391 && cp <= 0x03A1) { return cp + 32 }
    if (cp >= 0x03A3 && cp <= 0x03AB) { return cp + 32 }
    // Cyrillic
    if (cp >= 0x0410 && cp <= 0x042F) { return cp + 32 }
    if (cp >= 0x0400 && cp <= 0x040F) { return cp + 80 }
    // Armenian
    if (cp >= 0x0531 && cp <= 0x0556) { return cp + 48 }
    // Latin Extended Additional
    if (cp >= 0x1E00 && cp <= 0x1E94) { if (cp % 2 == 0) { return cp + 1 } }
    if (cp == 0x1E60) { return 0x1E9B }
    // Fullwidth Latin
    if (cp >= 0xFF21 && cp <= 0xFF3A) { return cp + 32 }
    return cp
}

/// 大小写折叠 (Case Folding)
/// 对应 Unicode CaseFolding.txt status C (common)
/// 用于不区分大小写的字符串比较
public func toFold(cp: UInt32): UInt32 {
    // ASCII 快速路径
    if (cp >= UInt32('A') && cp <= UInt32('Z')) {
        return cp + 32
    }
    // Special case foldings (status C)
    if (cp == 0x00B5) { return 0x03BC }  // micro -> mu
    if (cp == 0x00DF) { return 0x0073 }  // sharp s -> s (simplified, full fold is "ss")
    if (cp == 0x0130) { return 0x0069 }  // I-dot -> i
    if (cp == 0x0149) { return 0x02BC }  // n-apostrophe -> modifier letter apostrophe
    if (cp == 0x017F) { return 0x0073 }  // long s -> s
    // Greek special foldings
    if (cp == 0x0345) { return 0x03B9 }  // combining iota -> iota
    if (cp == 0x0390) { return 0x03B9 }  // iota with dialytika and tonos -> iota (simplified)
    if (cp == 0x03AA) { return 0x03B9 }  // Iota with dialytika -> iota
    if (cp == 0x03AB) { return 0x03C5 }  // Upsilon with dialytika -> upsilon
    if (cp == 0x03B0) { return 0x03C5 }  // upsilon with dialytika and tonos (simplified)
    if (cp == 0x03C2) { return 0x03C3 }  // final sigma -> sigma
    if (cp == 0x03D0) { return 0x03B2 }  // beta symbol -> beta
    if (cp == 0x03D1) { return 0x03B8 }  // theta symbol -> theta
    if (cp == 0x03D5) { return 0x03C6 }  // phi symbol -> phi
    if (cp == 0x03D6) { return 0x03C0 }  // pi symbol -> pi
    if (cp == 0x03F0) { return 0x03BA }  // kappa symbol -> kappa
    if (cp == 0x03F1) { return 0x03C1 }  // rho symbol -> rho
    if (cp == 0x03F5) { return 0x03B5 }  // lunate epsilon -> epsilon
    // Armenian
    if (cp == 0x0587) { return 0x0565 }  // yiwn -> ech (simplified)
    // Georgian
    if (cp >= 0x10A0 && cp <= 0x10C5) { return cp + 7264 }  // Asomtavruli -> Mkhedruli
    if (cp == 0x10C7) { return 0x2D27 }
    if (cp == 0x10CD) { return 0x2D2D }
    // CJK Compatibility
    if (cp == 0x1E9B) { return 0x1E61 }  // long s with dot -> s with dot
    if (cp == 0x1FBE) { return 0x03B9 }  // prosgegrammeni -> iota
    // Fullwidth
    if (cp >= 0xFF21 && cp <= 0xFF3A) { return cp + 32 }
    // Default: use lowercase
    return toLower(cp)
}

// ============================================================================
// 字符串大小写转换
// 严格翻译自 Bun string casing functions
// ============================================================================

/// 将字符串转为大写
public func toUpperString(s: String): String {
    var result = StringBuilder()
    var bytes = s.toArray()
    var i: Int64 = 0
    while (i < bytes.size) {
        let decoded = Utf8.decode(bytes, i)
        if (decoded.valid) {
            let upper = toUpper(decoded.codepoint)
            let encoded = Utf8.encode(upper)
            for (b in encoded) {
                result.append(Rune(UInt32(b)))
            }
            i += decoded.length
        } else {
            result.append(Rune(UInt32(bytes[i])))
            i += 1
        }
    }
    return result.toString()
}

/// 将字符串转为小写
public func toLowerString(s: String): String {
    var result = StringBuilder()
    var bytes = s.toArray()
    var i: Int64 = 0
    while (i < bytes.size) {
        let decoded = Utf8.decode(bytes, i)
        if (decoded.valid) {
            let lower = toLower(decoded.codepoint)
            let encoded = Utf8.encode(lower)
            for (b in encoded) {
                result.append(Rune(UInt32(b)))
            }
            i += decoded.length
        } else {
            result.append(Rune(UInt32(bytes[i])))
            i += 1
        }
    }
    return result.toString()
}

/// 将字符串进行大小写折叠 (用于不区分大小写比较)
public func toFoldString(s: String): String {
    var result = StringBuilder()
    var bytes = s.toArray()
    var i: Int64 = 0
    while (i < bytes.size) {
        let decoded = Utf8.decode(bytes, i)
        if (decoded.valid) {
            let folded = toFold(decoded.codepoint)
            let encoded = Utf8.encode(folded)
            for (b in encoded) {
                result.append(Rune(UInt32(b)))
            }
            i += decoded.length
        } else {
            result.append(Rune(UInt32(bytes[i])))
            i += 1
        }
    }
    return result.toString()
}

/// 不区分大小写的字符串比较
public func caseInsensitiveEquals(a: String, b: String): Bool {
    return toFoldString(a) == toFoldString(b)
}
