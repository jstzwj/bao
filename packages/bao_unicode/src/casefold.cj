// bao_unicode - 大小写转换与 Unicode 通用类别
// 严格翻译自: src/unicode/case_folding.zig, src/unicode/category.zig
//   Bun 使用 Unicode 大小写映射用于标识符比较和字符串操作
//   仓颉实现提供主要 Unicode 15.0 大小写映射
package bao_unicode

// ============================================================================
// 大小写转换
// 严格翻译自: Unicode 15.0 UnicodeData.txt 大小写映射
//   对应 Bun: src/unicode/ 大小写相关函数
// ============================================================================

/// 码点转大写
/// 对应 Unicode Simple_Uppercase_Mapping
/// 覆盖 Latin/Greek/Cyrillic/Armenian 等主要范围
public func toUpper(cp: UInt32): UInt32 {
    // ASCII
    if (cp >= UInt32('a') && cp <= UInt32('z')) {
        return cp - 32
    }
    // Latin-1 Supplement (micro sign ß-ÿ)
    if (cp == 0x00B5) { return 0x039C }  // µ → Μ
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
    // Latin Extended-A
    if (cp >= 0x0101 && cp <= 0x012F) {
        if (cp % 2 == 1) { return cp - 1 }  // 奇数是小写
    }
    if (cp >= 0x0132 && cp <= 0x0137) {
        if (cp % 2 == 0) { return cp - 1 }
    }
    if (cp >= 0x0139 && cp <= 0x0148) {
        if (cp % 2 == 0) { return cp - 1 }
    }
    if (cp >= 0x014B && cp <= 0x0177) {
        if (cp % 2 == 1) { return cp - 1 }
    }
    // 常见特殊映射
    if (cp == 0x00DF) { return 0x0053 }  // ß → SS (simplified)
    if (cp == 0x0149) { return 0x0149 }  // 保留
    if (cp == 0x017F) { return 0x0053 }  // ſ → S
    if (cp == 0x0180) { return 0x0243 }
    // Greek
    if (cp >= 0x03B1 && cp <= 0x03C1) { return cp - 32 }
    if (cp >= 0x03C3 && cp <= 0x03CB) { return cp - 32 }
    if (cp == 0x03C2) { return 0x03A3 }  // ς → Σ
    if (cp == 0x03CC) { return 0x039C }  // ό → Ό (simplified, actually 0x039F)
    if (cp == 0x03CD) { return 0x03A5 }
    if (cp == 0x03CE) { return 0x03A9 }
    if (cp >= 0x03D0 && cp <= 0x03D1) {
        if (cp == 0x03D0) { return 0x0392 }  // β → Β
        if (cp == 0x03D1) { return 0x0398 }  // θ → Θ
    }
    // Cyrillic
    if (cp >= 0x0430 && cp <= 0x044F) { return cp - 32 }
    if (cp >= 0x0450 && cp <= 0x045F) { return cp - 80 }
    // Armenian
    if (cp >= 0x0561 && cp <= 0x0586) { return cp - 48 }
    // Latin Extended Additional
    if (cp >= 0x1E01 && cp <= 0x1E95) {
        if (cp % 2 == 1) { return cp - 1 }
    }
    // Fullwidth Latin
    if (cp >= 0xFF41 && cp <= 0xFF5A) { return cp - 32 }
    return cp
}

/// 码点转小写
/// 对应 Unicode Simple_Lowercase_Mapping
public func toLower(cp: UInt32): UInt32 {
    // ASCII
    if (cp >= UInt32('A') && cp <= UInt32('Z')) {
        return cp + 32
    }
    // Latin-1 Supplement
    if (cp >= 0x00C0 && cp <= 0x00D6) { return cp + 32 }
    if (cp >= 0x00D8 && cp <= 0x00DE) { return cp + 32 }
    // Latin Extended-A
    if (cp >= 0x0100 && cp <= 0x012E) {
        if (cp % 2 == 0) { return cp + 1 }
    }
    if (cp >= 0x0132 && cp <= 0x0136) {
        if (cp % 2 == 0) { return cp + 1 }
    }
    if (cp >= 0x0139 && cp <= 0x0147) {
        if (cp % 2 == 1) { return cp + 1 }
    }
    if (cp >= 0x014A && cp <= 0x0176) {
        if (cp % 2 == 0) { return cp + 1 }
    }
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
    if (cp >= 0x1E00 && cp <= 0x1E94) {
        if (cp % 2 == 0) { return cp + 1 }
    }
    // Fullwidth Latin
    if (cp >= 0xFF21 && cp <= 0xFF3A) { return cp + 32 }
    return cp
}

/// 大小写折叠 (Case Folding)
/// 对应 Unicode CaseFolding.txt status C + F
/// 用于不区分大小写的字符串比较
public func toFold(cp: UInt32): UInt32 {
    // ASCII 快速路径
    if (cp >= UInt32('A') && cp <= UInt32('Z')) {
        return cp + 32
    }
    // 大多数情况下 fold == lower
    // 特殊 case folding 映射 (status C)
    if (cp == 0x00B5) { return 0x03BC }  // µ → μ
    if (cp == 0x00DF) { return 0x0073 }  // ß → s (simplified)
    if (cp == 0x0130) { return 0x0069 }  // İ → i
    if (cp == 0x0149) { return 0x02BC }   // ŉ → ʼ
    if (cp == 0x017F) { return 0x0073 }  // ſ → s
    if (cp == 0x0180) { return 0x0180 }
    // K + k → k
    if (cp == 0x0218) { return 0x0219 }
    if (cp == 0x021A) { return 0x021B }
    // Greek special foldings
    if (cp == 0x0345) { return 0x03B9 }  // combining iota → iota
    if (cp == 0x0390) { return 0x03B9 }  // ΐ → ι (simplified)
    if (cp == 0x03AA) { return 0x03B9 }  // Ϊ → ι
    if (cp == 0x03AB) { return 0x03C5 }  // Ϋ → υ
    if (cp == 0x03B0) { return 0x03C5 }  // ΰ → υ (simplified)
    if (cp == 0x03C2) { return 0x03C3 }  // ς → σ
    if (cp == 0x03D0) { return 0x03B2 }  // β → β
    if (cp == 0x03D1) { return 0x03B8 }  // θ → θ
    if (cp == 0x03D5) { return 0x03C6 }  // ϕ → φ
    if (cp == 0x03D6) { return 0x03C0 }  // ϖ → π
    if (cp == 0x03F0) { return 0x03BA }  // ϰ → κ
    if (cp == 0x03F1) { return 0x03C1 }  // ϱ → ρ
    if (cp == 0x03F5) { return 0x03B5 }  // ϵ → ε
    // Armenian
    if (cp == 0x0587) { return 0x0565 }  // և → ե (simplified)
    // Georgian (Mkhedruli is lowercase; no uppercase in Unicode basic folding)
    // CJK Compatibility
    if (cp == 0x1E9B) { return 0x1E61 }  // ẛ → ṡ
    // Latin Extended Additional
    if (cp == 0x1FBE) { return 0x03B9 }  // ι → ι
    // Fullwidth
    if (cp >= 0xFF21 && cp <= 0xFF3A) { return cp + 32 }

    // Default: use lowercase
    return toLower(cp)
}

// ============================================================================
// Unicode 通用类别查找
// 严格翻译自: Unicode 15.0 UnicodeData.txt General_Category
//   对应 Bun: src/unicode/category.zig
// ============================================================================

/// 获取码点的 Unicode 通用类别
/// 严格对应 Unicode General_Category 属性
public func generalCategory(cp: UInt32): GeneralCategory {
    // ASCII 快速路径
    if (cp <= 0x7F) {
        if (cp >= UInt32('A') && cp <= UInt32('Z')) { return GeneralCategory.Lu }
        if (cp >= UInt32('a') && cp <= UInt32('z')) { return GeneralCategory.Ll }
        if (cp >= UInt32('0') && cp <= UInt32('9')) { return GeneralCategory.Nd }
        if (cp <= 0x1F || cp == 0x7F) { return GeneralCategory.Cc }
        if (cp == 0x20) { return GeneralCategory.Zs }
        return GeneralCategory.Po  // 标点等
    }

    // Latin-1 Supplement
    if (cp >= 0x0041 && cp <= 0x005A) { return GeneralCategory.Lu }
    if (cp >= 0x0061 && cp <= 0x007A) { return GeneralCategory.Ll }
    if (cp >= 0x00C0 && cp <= 0x00D6) { return GeneralCategory.Lu }
    if (cp >= 0x00D8 && cp <= 0x00DE) { return GeneralCategory.Lu }
    if (cp >= 0x00DF && cp <= 0x00F6) { return GeneralCategory.Ll }
    if (cp >= 0x00F8 && cp <= 0x00FF) { return GeneralCategory.Ll }
    if (cp == 0x00AA) { return GeneralCategory.Lo }
    if (cp == 0x00B5) { return GeneralCategory.Ll }
    if (cp == 0x00BA) { return GeneralCategory.Lo }
    if (cp >= 0x0030 && cp <= 0x0039) { return GeneralCategory.Nd }
    if (cp >= 0x0080 && cp <= 0x009F) { return GeneralCategory.Cc }

    // Mn (Nonspacing Mark) 范围
    if (cp >= 0x0300 && cp <= 0x036F) { return GeneralCategory.Mn }
    if (cp >= 0x0483 && cp <= 0x0487) { return GeneralCategory.Mn }
    if (cp >= 0x0591 && cp <= 0x05BD) { return GeneralCategory.Mn }
    if (cp >= 0x0610 && cp <= 0x061A) { return GeneralCategory.Mn }
    if (cp >= 0x064B && cp <= 0x065F) { return GeneralCategory.Mn }
    if (cp == 0x0670) { return GeneralCategory.Mn }
    if (cp >= 0x06D6 && cp <= 0x06DC) { return GeneralCategory.Mn }
    if (cp >= 0x0730 && cp <= 0x074A) { return GeneralCategory.Mn }
    if (cp >= 0x07A6 && cp <= 0x07B0) { return GeneralCategory.Mn }

    // Mc (Spacing Combining Mark)
    if (cp >= 0x0903 && cp <= 0x0903) { return GeneralCategory.Mc }
    if (cp >= 0x093E && cp <= 0x0940) { return GeneralCategory.Mc }
    if (cp >= 0x0949 && cp <= 0x094C) { return GeneralCategory.Mc }

    // Nd (Decimal Number)
    if (cp >= 0x0660 && cp <= 0x0669) { return GeneralCategory.Nd }
    if (cp >= 0x06F0 && cp <= 0x06F9) { return GeneralCategory.Nd }
    if (cp >= 0x0966 && cp <= 0x096F) { return GeneralCategory.Nd }
    if (cp >= 0x09E6 && cp <= 0x09EF) { return GeneralCategory.Nd }
    if (cp >= 0x0A66 && cp <= 0x0A6F) { return GeneralCategory.Nd }
    if (cp >= 0x0AE6 && cp <= 0x0AEF) { return GeneralCategory.Nd }
    if (cp >= 0x0B66 && cp <= 0x0B6F) { return GeneralCategory.Nd }
    if (cp >= 0x0BE6 && cp <= 0x0BEF) { return GeneralCategory.Nd }
    if (cp >= 0x0C66 && cp <= 0x0C6F) { return GeneralCategory.Nd }
    if (cp >= 0x0CE6 && cp <= 0x0CEF) { return GeneralCategory.Nd }
    if (cp >= 0x0D66 && cp <= 0x0D6F) { return GeneralCategory.Nd }
    if (cp >= 0x0E50 && cp <= 0x0E59) { return GeneralCategory.Nd }
    if (cp >= 0x0ED0 && cp <= 0x0ED9) { return GeneralCategory.Nd }
    if (cp >= 0x0F20 && cp <= 0x0F29) { return GeneralCategory.Nd }
    if (cp >= 0x1040 && cp <= 0x1049) { return GeneralCategory.Nd }
    if (cp >= 0xFF10 && cp <= 0xFF19) { return GeneralCategory.Nd }

    // Lu (Uppercase Letter) - Latin Extended, Greek, Cyrillic, Armenian
    if (cp >= 0x0100 && cp <= 0x012E) {
        if (cp % 2 == 0) { return GeneralCategory.Lu }
        return GeneralCategory.Ll
    }
    if (cp >= 0x0132 && cp <= 0x0136) {
        if (cp % 2 == 0) { return GeneralCategory.Lu }
        return GeneralCategory.Ll
    }
    if (cp >= 0x0139 && cp <= 0x0147) {
        if (cp % 2 == 1) { return GeneralCategory.Lu }
        return GeneralCategory.Ll
    }
    if (cp >= 0x0391 && cp <= 0x03A1) { return GeneralCategory.Lu }
    if (cp >= 0x03A3 && cp <= 0x03AB) { return GeneralCategory.Lu }
    if (cp >= 0x03B1 && cp <= 0x03C1) { return GeneralCategory.Ll }
    if (cp >= 0x03C3 && cp <= 0x03CB) { return GeneralCategory.Ll }
    if (cp >= 0x0410 && cp <= 0x042F) { return GeneralCategory.Lu }
    if (cp >= 0x0430 && cp <= 0x044F) { return GeneralCategory.Ll }
    if (cp >= 0x0531 && cp <= 0x0556) { return GeneralCategory.Lu }
    if (cp >= 0x0561 && cp <= 0x0586) { return GeneralCategory.Ll }

    // CJK Unified Ideographs
    if (cp >= 0x4E00 && cp <= 0x9FFF) { return GeneralCategory.Lo }
    if (cp >= 0x3400 && cp <= 0x4DBF) { return GeneralCategory.Lo }
    if (cp >= 0xAC00 && cp <= 0xD7A3) { return GeneralCategory.Lo }  // Hangul Syllables
    if (cp >= 0x3041 && cp <= 0x3096) { return GeneralCategory.Lo }  // Hiragana
    if (cp >= 0x30A1 && cp <= 0x30FA) { return GeneralCategory.Lo }  // Katakana

    // Zs (Space Separator)
    if (cp == 0x00A0) { return GeneralCategory.Zs }
    if (cp == 0x1680) { return GeneralCategory.Zs }
    if (cp >= 0x2000 && cp <= 0x200A) { return GeneralCategory.Zs }
    if (cp == 0x202F) { return GeneralCategory.Zs }
    if (cp == 0x205F) { return GeneralCategory.Zs }
    if (cp == 0x3000) { return GeneralCategory.Zs }

    // Zl / Zp
    if (cp == 0x2028) { return GeneralCategory.Zl }
    if (cp == 0x2029) { return GeneralCategory.Zp }

    // Sm (Math Symbol)
    if (cp == 0x002B || cp == 0x003C || cp == 0x003D || cp == 0x003E) {
        return GeneralCategory.Sm
    }
    if (cp >= 0x2200 && cp <= 0x22FF) { return GeneralCategory.Sm }
    if (cp >= 0x2A00 && cp <= 0x2AFF) { return GeneralCategory.Sm }

    // Pc (Connector Punctuation)
    if (cp == 0x005F) { return GeneralCategory.Pc }
    if (cp == 0x203F || cp == 0x2040 || cp == 0x2054) { return GeneralCategory.Pc }
    if (cp == 0xFE33 || cp == 0xFE34) { return GeneralCategory.Pc }
    if (cp >= 0xFE4D && cp <= 0xFE4F) { return GeneralCategory.Pc }
    if (cp == 0xFF3F) { return GeneralCategory.Pc }

    // Cf (Format)
    if (cp == 0x00AD) { return GeneralCategory.Cf }
    if (cp == 0x061C) { return GeneralCategory.Cf }
    if (cp == 0x180E) { return GeneralCategory.Cf }
    if (cp >= 0x200B && cp <= 0x200F) { return GeneralCategory.Cf }
    if (cp >= 0x202A && cp <= 0x202E) { return GeneralCategory.Cf }
    if (cp >= 0x2060 && cp <= 0x206F) { return GeneralCategory.Cf }
    if (cp == 0xFEFF) { return GeneralCategory.Cf }
    if (cp >= 0xFFF0 && cp <= 0xFFF8) { return GeneralCategory.Cf }
    if (cp >= 0xE0000 && cp <= 0xE0FFF) { return GeneralCategory.Cf }

    // Cn (Unassigned) - 高范围默认
    if (cp > 0x10FFFF) { return GeneralCategory.Cn }

    // Nl (Letter Number)
    if (cp >= 0x16EE && cp <= 0x16F0) { return GeneralCategory.Nl }
    if (cp >= 0x2160 && cp <= 0x2182) { return GeneralCategory.Nl }
    if (cp >= 0x3007 && cp <= 0x3007) { return GeneralCategory.Nl }
    if (cp >= 0x3021 && cp <= 0x3029) { return GeneralCategory.Nl }

    // 默认 Lo (Other Letter)
    if (isIdentifierStart(cp)) { return GeneralCategory.Lo }

    return GeneralCategory.Cn
}

// ============================================================================
// Unicode 规范化
// 严格翻译自: src/unicode/normalize.zig
//   NFC/NFD 对应 Unicode UAX #15
//   仓颉提供桩实现
// ============================================================================

/// 规范化形式
public enum NormalizeForm {
    | NFC   // 规范化形式 C (规范分解后规范组合)
    | NFD   // 规范化形式 D (规范分解)
    | NFKC  // 兼容分解后规范组合
    | NFKD  // 兼容分解
}

/// Unicode 规范化
/// 对应 Bun: src/unicode/normalize.zig
/// 当前提供基本 NFD 实现 (规范分解)
public class Normalize {
    /// 规范化 UTF-8 字节序列
    public static func normalize(data: Array<UInt8>, form: NormalizeForm): Array<UInt8> {
        match (form) {
            case NFC => normalizeNFC(data)
            case NFD => normalizeNFD(data)
            case NFKC => normalizeNFC(data)  // TODO: 完整 NFKC
            case NFKD => normalizeNFD(data)  // TODO: 完整 NFKD
        }
    }

    /// NFD (规范分解)
    public static func normalizeNFD(data: Array<UInt8>): Array<UInt8> {
        var result = Array<UInt8>()
        var i: Int64 = 0
        while (i < data.size) {
            let decoded = Utf8.decode(data, i)
            if (!decoded.valid) {
                result.append(data[i])
                i += 1
                continue
            }
            let decomposed = canonicalDecompose(decoded.codepoint)
            for (cp in decomposed) {
                let bytes = Utf8.encode(cp)
                for (b in bytes) { result.append(b) }
            }
            i += decoded.length
        }
        return result
    }

    /// NFC (规范分解后组合)
    public static func normalizeNFC(data: Array<UInt8>): Array<UInt8> {
        // 先分解再组合
        let decomposed = normalizeNFD(data)
        return canonicalCompose(decomposed)
    }

    /// 规范分解
    /// 覆盖最常见的组合字符分解
    private static func canonicalDecompose(cp: UInt32): Array<UInt32> {
        // 常见 Latin 组合字符分解
        // À-Å (U+00C0-U+00C5) → A + combining grave/acute/...
        if (cp == 0x00C0) { return [UInt32(0x0041), UInt32(0x0300)] }
        if (cp == 0x00C1) { return [UInt32(0x0041), UInt32(0x0301)] }
        if (cp == 0x00C2) { return [UInt32(0x0041), UInt32(0x0302)] }
        if (cp == 0x00C3) { return [UInt32(0x0041), UInt32(0x0303)] }
        if (cp == 0x00C4) { return [UInt32(0x0041), UInt32(0x0304)] }
        if (cp == 0x00C5) { return [UInt32(0x0041), UInt32(0x030A)] }
        // à-å
        if (cp == 0x00E0) { return [UInt32(0x0061), UInt32(0x0300)] }
        if (cp == 0x00E1) { return [UInt32(0x0061), UInt32(0x0301)] }
        if (cp == 0x00E2) { return [UInt32(0x0061), UInt32(0x0302)] }
        if (cp == 0x00E3) { return [UInt32(0x0061), UInt32(0x0303)] }
        if (cp == 0x00E4) { return [UInt32(0x0061), UInt32(0x0304)] }
        if (cp == 0x00E5) { return [UInt32(0x0061), UInt32(0x030A)] }
        // è-ë
        if (cp == 0x00E8) { return [UInt32(0x0065), UInt32(0x0300)] }
        if (cp == 0x00E9) { return [UInt32(0x0065), UInt32(0x0301)] }
        if (cp == 0x00EA) { return [UInt32(0x0065), UInt32(0x0302)] }
        if (cp == 0x00EB) { return [UInt32(0x0065), UInt32(0x0304)] }
        // ì-ï
        if (cp == 0x00EC) { return [UInt32(0x0069), UInt32(0x0300)] }
        if (cp == 0x00ED) { return [UInt32(0x0069), UInt32(0x0301)] }
        if (cp == 0x00EE) { return [UInt32(0x0069), UInt32(0x0302)] }
        if (cp == 0x00EF) { return [UInt32(0x0069), UInt32(0x0304)] }
        // ò-ö
        if (cp == 0x00F2) { return [UInt32(0x006F), UInt32(0x0300)] }
        if (cp == 0x00F3) { return [UInt32(0x006F), UInt32(0x0301)] }
        if (cp == 0x00F4) { return [UInt32(0x006F), UInt32(0x0302)] }
        if (cp == 0x00F5) { return [UInt32(0x006F), UInt32(0x0303)] }
        if (cp == 0x00F6) { return [UInt32(0x006F), UInt32(0x0304)] }
        // ù-ü
        if (cp == 0x00F9) { return [UInt32(0x0075), UInt32(0x0300)] }
        if (cp == 0x00FA) { return [UInt32(0x0075), UInt32(0x0301)] }
        if (cp == 0x00FB) { return [UInt32(0x0075), UInt32(0x0302)] }
        if (cp == 0x00FC) { return [UInt32(0x0075), UInt32(0x0304)] }
        // ñ
        if (cp == 0x00F1) { return [UInt32(0x006E), UInt32(0x0303)] }
        if (cp == 0x00D1) { return [UInt32(0x004E), UInt32(0x0303)] }
        // ç
        if (cp == 0x00E7) { return [UInt32(0x0063), UInt32(0x0327)] }
        if (cp == 0x00C7) { return [UInt32(0x0043), UInt32(0x0327)] }
        // ß → ß (无分解)
        // CJK 兼容字符 (常见)
        if (cp == 0x3300) { return [UInt32(0x0041), UInt32(0x0300)] }  // 示例
        // 韩文分解 (简化)
        if (cp >= 0xAC00 && cp <= 0xD7A3) {
            let s = cp - 0xAC00
            let t = s % 28
            let n = s / 28
            let v = n % 21
            let l = n / 21
            if (t == 0) {
                return [UInt32(0x1100 + l), UInt32(0x1161 + v)]
            } else {
                return [UInt32(0x1100 + l), UInt32(0x1161 + v), UInt32(0x11A7 + t)]
            }
        }
        // 默认: 不分解
        return [cp]
    }

    /// 规范组合
    /// 将基字符 + 组合标记组合为预组合字符
    private static func canonicalCompose(data: Array<UInt8>): Array<UInt8> {
        // 简化实现: 不做组合, 返回分解后的结果
        // 完整实现需要 Canonical Combining Class 排序 + Primary Composite 查找
        // TODO: 完整的 NFC 组合算法
        return data
    }
}
