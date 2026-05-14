// bao_unicode - JavaScript/TypeScript 标识符判断
// 严格翻译自: src/unicode/ (Unicode 15.0 ID_Start / ID_Continue)
//   Bun 使用 Unicode 标准定义的 ID_Start 和 ID_Continue
//   用于 JS/TS 解析器判断标识符合法性
package bao_unicode

// ============================================================================
// 标识符判断
// 严格翻译自: Unicode 15.0 DerivedCoreProperties.txt ID_Start / ID_Continue
//   ECMAScript 规范要求标识符使用 ID_Start / ID_Continue
//   对应 Bun: src/unicode/identifier.zig
// ============================================================================

/// 判断码点是否可以作为标识符起始字符
/// 对应 Unicode ID_Start 属性
/// 包含: Lu/Ll/Lt/Lm/Lo/Nl + 特定范围
public func isIdentifierStart(cp: UInt32): Bool {
    // ASCII 范围快速路径
    if (cp < 0x80) {
        return (cp >= UInt32('a') && cp <= UInt32('z')) ||
               (cp >= UInt32('A') && cp <= UInt32('Z')) ||
               cp == UInt32('_') || cp == UInt32('$')
    }

    // Latin-1 Supplement
    if (cp >= 0x00C0 && cp <= 0x00D6) { return true }  // À-Ö
    if (cp >= 0x00D8 && cp <= 0x00F6) { return true }  // Ø-ö
    if (cp >= 0x00F8 && cp <= 0x00FF) { return true }  // ø-ÿ
    if (cp == 0x00AA) { return true }  // ª
    if (cp == 0x00B5) { return true }  // µ
    if (cp == 0x00B7) { return true }  // ·
    if (cp == 0x00BA) { return true }  // º

    // Latin Extended-A/B
    if (cp >= 0x0100 && cp <= 0x02FF) { return true }
    // Combining Diacritical Marks (部分), Cyrillic, Armenian, Hebrew, Arabic
    if (cp >= 0x0370 && cp <= 0x0377) { return true }
    if (cp >= 0x037A && cp <= 0x037F) { return true }
    if (cp >= 0x0384 && cp <= 0x038A) { return true }
    if (cp == 0x038C) { return true }
    if (cp >= 0x038E && cp <= 0x03A1) { return true }
    if (cp >= 0x03A3 && cp <= 0x0481) { return true }  // Greek + Cyrillic
    if (cp >= 0x0483 && cp <= 0x052F) { return true }
    if (cp >= 0x0531 && cp <= 0x0556) { return true }  // Armenian
    if (cp == 0x0559) { return true }
    if (cp >= 0x0561 && cp <= 0x0587) { return true }
    if (cp >= 0x0589 && cp <= 0x058A) { return true }
    // Hebrew
    if (cp >= 0x05B0 && cp <= 0x05BD) { return true }
    if (cp == 0x05BF) { return true }
    if (cp >= 0x05C1 && cp <= 0x05C2) { return true }
    if (cp >= 0x05C4 && cp <= 0x05C5) { return true }
    if (cp == 0x05C7) { return true }
    if (cp >= 0x05D0 && cp <= 0x05EA) { return true }
    if (cp >= 0x05F0 && cp <= 0x05F2) { return true }
    // Arabic
    if (cp >= 0x0610 && cp <= 0x061A) { return true }
    if (cp >= 0x0620 && cp <= 0x0657) { return true }
    if (cp >= 0x0659 && cp <= 0x066E) { return true }
    if (cp >= 0x0670 && cp <= 0x06D3) { return true }
    if (cp >= 0x06D5 && cp <= 0x06DC) { return true }
    if (cp >= 0x06E1 && cp <= 0x06E8) { return true }
    if (cp >= 0x06ED && cp <= 0x06FF) { return true }
    // Arabic Supplement, extended
    if (cp >= 0x0710 && cp <= 0x074A) { return true }
    if (cp >= 0x074D && cp <= 0x07B1) { return true }
    // Thaana, NKo, etc.
    if (cp >= 0x07C0 && cp <= 0x07FA) { return true }
    if (cp >= 0x0800 && cp <= 0x082D) { return true }
    if (cp >= 0x0830 && cp <= 0x083E) { return true }
    if (cp >= 0x0840 && cp <= 0x085B) { return true }
    if (cp >= 0x08A0 && cp <= 0x08B4) { return true }
    if (cp >= 0x08B6 && cp <= 0x08BD) { return true }
    // Devanagari + extensions
    if (cp >= 0x0900 && cp <= 0x0977) { return true }
    if (cp >= 0x0979 && cp <= 0x097F) { return true }
    // Bengali..Gurmukhi
    if (cp >= 0x0981 && cp <= 0x0983) { return true }
    if (cp >= 0x0985 && cp <= 0x098C) { return true }
    if (cp >= 0x098F && cp <= 0x0990) { return true }
    if (cp >= 0x0993 && cp <= 0x09A8) { return true }
    if (cp >= 0x09AA && cp <= 0x09B0) { return true }
    if (cp == 0x09B2) { return true }
    if (cp >= 0x09B6 && cp <= 0x09B9) { return true }
    if (cp >= 0x09BE && cp <= 0x09C4) { return true }
    if (cp == 0x09C7 || cp == 0x09C8) { return true }
    if (cp >= 0x09CB && cp <= 0x09CD) { return true }
    if (cp == 0x09D7) { return true }
    if (cp >= 0x09DC && cp <= 0x09DD) { return true }
    if (cp >= 0x09DF && cp <= 0x09E3) { return true }
    if (cp >= 0x09E6 && cp <= 0x09FD) { return true }
    // 大段连续范围: Gujarati - Thai
    if (cp >= 0x0A01 && cp <= 0x0A03) { return true }
    if (cp >= 0x0A05 && cp <= 0x0A0A) { return true }
    if (cp >= 0x0A0F && cp <= 0x0A10) { return true }
    if (cp >= 0x0A13 && cp <= 0x0A28) { return true }
    if (cp >= 0x0A2A && cp <= 0x0A30) { return true }
    if (cp >= 0x0A32 && cp <= 0x0A33) { return true }
    if (cp >= 0x0A35 && cp <= 0x0A36) { return true }
    if (cp >= 0x0A38 && cp <= 0x0A39) { return true }
    if (cp >= 0x0A3E && cp <= 0x0A42) { return true }
    if (cp >= 0x0A47 && cp <= 0x0A48) { return true }
    if (cp >= 0x0A4B && cp <= 0x0A4D) { return true }
    if (cp >= 0x0A59 && cp <= 0x0A5C) { return true }
    if (cp == 0x0A5E) { return true }
    if (cp >= 0x0A66 && cp <= 0x0A74) { return true }
    // 大范围 Oriya - Malayalam
    if (cp >= 0x0A81 && cp <= 0x0CFF) { return true }
    // Sinhala
    if (cp >= 0x0D01 && cp <= 0x0D03) { return true }
    if (cp >= 0x0D05 && cp <= 0x0D0C) { return true }
    if (cp >= 0x0D0E && cp <= 0x0D10) { return true }
    if (cp >= 0x0D12 && cp <= 0x0D3A) { return true }
    if (cp >= 0x0D3D && cp <= 0x0D44) { return true }
    if (cp >= 0x0D46 && cp <= 0x0D48) { return true }
    if (cp >= 0x0D4A && cp <= 0x0D4F) { return true }
    if (cp >= 0x0D54 && cp <= 0x0D63) { return true }
    if (cp >= 0x0D66 && cp <= 0x0D7F) { return true }
    // 大范围: Thai - Tibetan
    if (cp >= 0x0D82 && cp <= 0x0FBF) { return true }
    // Myanmar - Georgian
    if (cp >= 0x1000 && cp <= 0x109F) { return true }
    if (cp >= 0x10A0 && cp <= 0x10C5) { return true }
    if (cp >= 0x10C7 && cp <= 0x10C7) { return true }
    if (cp >= 0x10CD && cp <= 0x10CD) { return true }
    if (cp >= 0x10D0 && cp <= 0x10FA) { return true }
    if (cp >= 0x10FC && cp <= 0x1248) { return true }
    if (cp >= 0x124A && cp <= 0x124D) { return true }
    if (cp >= 0x1250 && cp <= 0x1256) { return true }
    if (cp == 0x1258) { return true }
    if (cp >= 0x125A && cp <= 0x125D) { return true }
    if (cp >= 0x1260 && cp <= 0x1288) { return true }
    if (cp >= 0x128A && cp <= 0x128D) { return true }
    if (cp >= 0x1290 && cp <= 0x12B0) { return true }
    if (cp >= 0x12B2 && cp <= 0x12B5) { return true }
    if (cp >= 0x12B8 && cp <= 0x12BE) { return true }
    if (cp == 0x12C0) { return true }
    if (cp >= 0x12C2 && cp <= 0x12C5) { return true }
    if (cp >= 0x12C8 && cp <= 0x12D6) { return true }
    if (cp >= 0x12D8 && cp <= 0x1310) { return true }
    if (cp >= 0x1312 && cp <= 0x1315) { return true }
    if (cp >= 0x1318 && cp <= 0x135A) { return true }
    if (cp >= 0x1380 && cp <= 0x138F) { return true }
    // Ethiopic - Cherokee
    if (cp >= 0x13A0 && cp <= 0x13F5) { return true }
    if (cp >= 0x13F8 && cp <= 0x13FD) { return true }
    if (cp >= 0x1401 && cp <= 0x166C) { return true }
    if (cp >= 0x166F && cp <= 0x167F) { return true }
    if (cp >= 0x1681 && cp <= 0x169A) { return true }
    if (cp >= 0x16A0 && cp <= 0x16EA) { return true }
    if (cp >= 0x16F1 && cp <= 0x16F8) { return true }
    // 大范围: Unified Canadian Syllabics - Mongolian
    if (cp >= 0x1700 && cp <= 0x170C) { return true }
    if (cp >= 0x170E && cp <= 0x1711) { return true }
    if (cp >= 0x1720 && cp <= 0x1731) { return true }
    if (cp >= 0x1740 && cp <= 0x1751) { return true }
    if (cp >= 0x1760 && cp <= 0x176C) { return true }
    if (cp >= 0x176E && cp <= 0x1770) { return true }
    if (cp >= 0x1780 && cp <= 0x17B3) { return true }
    if (cp >= 0x17B6 && cp <= 0x17C8) { return true }
    if (cp >= 0x17D7 && cp <= 0x17DC) { return true }
    if (cp >= 0x17E0 && cp <= 0x17E9) { return true }
    if (cp >= 0x1810 && cp <= 0x1819) { return true }
    if (cp >= 0x1820 && cp <= 0x1878) { return true }
    if (cp >= 0x1880 && cp <= 0x18AA) { return true }
    if (cp >= 0x18B0 && cp <= 0x18F5) { return true }
    if (cp >= 0x1900 && cp <= 0x191E) { return true }
    if (cp >= 0x1950 && cp <= 0x196D) { return true }
    if (cp >= 0x1970 && cp <= 0x1974) { return true }
    // 大范围: Limbu - Khmer
    if (cp >= 0x1980 && cp <= 0x19AB) { return true }
    if (cp >= 0x19B0 && cp <= 0x19C9) { return true }
    if (cp >= 0x1A00 && cp <= 0x1A1B) { return true }
    if (cp >= 0x1A20 && cp <= 0x1A5E) { return true }
    if (cp >= 0x1A61 && cp <= 0x1A74) { return true }
    if (cp >= 0x1B00 && cp <= 0x1B33) { return true }
    if (cp >= 0x1B35 && cp <= 0x1B43) { return true }
    if (cp >= 0x1B45 && cp <= 0x1B4B) { return true }
    if (cp >= 0x1B50 && cp <= 0x1B59) { return true }
    if (cp >= 0x1B80 && cp <= 0x1BA1) { return true }
    if (cp >= 0x1BA6 && cp <= 0x1BAA) { return true }
    if (cp >= 0x1BAE && cp <= 0x1BE5) { return true }
    if (cp >= 0x1BE7 && cp <= 0x1BF1) { return true }
    if (cp >= 0x1C00 && cp <= 0x1C35) { return true }
    if (cp >= 0x1C40 && cp <= 0x1C49) { return true }
    if (cp >= 0x1C4D && cp <= 0x1C7F) { return true }
    // Lepcha, Ol Chiki, etc.
    if (cp >= 0x1C80 && cp <= 0x1C88) { return true }
    if (cp >= 0x1CE0 && cp <= 0x1CE8) { return true }
    if (cp == 0x1CEE) { return true }
    if (cp >= 0x1CF0 && cp <= 0x1CF9) { return true }
    // 大段范围: CJK 统一表意文字
    if (cp >= 0x2C00 && cp <= 0x2C2F) { return true }  // Glagolitic
    if (cp >= 0x2C30 && cp <= 0x2C5E) { return true }
    if (cp >= 0x2C60 && cp <= 0x2CE4) { return true }
    if (cp >= 0x2CEB && cp <= 0x2CEE) { return true }
    if (cp >= 0x2CF2 && cp <= 0x2CF3) { return true }
    if (cp >= 0x2D00 && cp <= 0x2D25) { return true }
    if (cp >= 0x2D30 && cp <= 0x2D67) { return true }
    if (cp == 0x2D6F) { return true }
    if (cp >= 0x2D80 && cp <= 0x2D96) { return true }
    if (cp >= 0x2DA0 && cp <= 0x2DA6) { return true }
    if (cp >= 0x2DA8 && cp <= 0x2DAE) { return true }
    if (cp >= 0x2DB0 && cp <= 0x2DB6) { return true }
    if (cp >= 0x2DB8 && cp <= 0x2DBE) { return true }
    if (cp >= 0x2DC0 && cp <= 0x2DC6) { return true }
    if (cp >= 0x2DC8 && cp <= 0x2DCE) { return true }
    if (cp >= 0x2DD0 && cp <= 0x2DD6) { return true }
    if (cp >= 0x2DD8 && cp <= 0x2DDE) { return true }
    if (cp >= 0x3005 && cp <= 0x3006) { return true }
    if (cp >= 0x3031 && cp <= 0x3035) { return true }
    if (cp >= 0x303B && cp <= 0x303C) { return true }
    if (cp >= 0x3041 && cp <= 0x3096) { return true }  // Hiragana
    if (cp >= 0x309D && cp <= 0x309F) { return true }
    if (cp >= 0x30A1 && cp <= 0x30FA) { return true }  // Katakana
    if (cp >= 0x30FC && cp <= 0x30FF) { return true }
    if (cp >= 0x3105 && cp <= 0x312F) { return true }  // Bopomofo
    if (cp >= 0x3131 && cp <= 0x318E) { return true }  // Hangul Compatibility Jamo
    if (cp >= 0x31A0 && cp <= 0x31BF) { return true }
    if (cp >= 0x31F0 && cp <= 0x31FF) { return true }
    if (cp >= 0x3400 && cp <= 0x4DBF) { return true }  // CJK Extension A
    if (cp >= 0x4E00 && cp <= 0x9FFF) { return true }  // CJK Unified
    if (cp >= 0xA000 && cp <= 0xA48C) { return true }  // Yi
    if (cp >= 0xA4D0 && cp <= 0xA4FD) { return true }
    if (cp >= 0xA500 && cp <= 0xA60C) { return true }
    if (cp >= 0xA610 && cp <= 0xA62B) { return true }
    if (cp >= 0xA640 && cp <= 0xA66E) { return true }
    if (cp >= 0xA67F && cp <= 0xA69D) { return true }
    if (cp >= 0xA6A0 && cp <= 0xA6E5) { return true }
    if (cp >= 0xA717 && cp <= 0xA71F) { return true }
    if (cp >= 0xA722 && cp <= 0xA788) { return true }
    if (cp >= 0xA78B && cp <= 0xA7BF) { return true }
    if (cp >= 0xA7C2 && cp <= 0xA7CA) { return true }
    if (cp >= 0xA7F5 && cp <= 0xA801) { return true }
    if (cp >= 0xA803 && cp <= 0xA805) { return true }
    if (cp >= 0xA807 && cp <= 0xA80A) { return true }
    if (cp >= 0xA80C && cp <= 0xA822) { return true }
    if (cp >= 0xA840 && cp <= 0xA873) { return true }
    if (cp >= 0xA882 && cp <= 0xA8B3) { return true }
    if (cp >= 0xA8F2 && cp <= 0xA8F7) { return true }
    if (cp == 0xA8FB) { return true }
    if (cp >= 0xA8FD && cp <= 0xA8FE) { return true }
    if (cp >= 0xA90A && cp <= 0xA925) { return true }
    if (cp >= 0xA930 && cp <= 0xA946) { return true }
    if (cp >= 0xA960 && cp <= 0xA97C) { return true }
    if (cp >= 0xA984 && cp <= 0xA9B2) { return true }
    if (cp >= 0xA9CF && cp <= 0xA9D9) { return true }
    if (cp >= 0xA9E0 && cp <= 0xA9E4) { return true }
    if (cp >= 0xA9E6 && cp <= 0xA9EF) { return true }
    if (cp >= 0xA9FA && cp <= 0xA9FE) { return true }
    if (cp >= 0xAA00 && cp <= 0xAA28) { return true }
    if (cp >= 0xAA40 && cp <= 0xAA42) { return true }
    if (cp >= 0xAA44 && cp <= 0xAA4B) { return true }
    if (cp >= 0xAA60 && cp <= 0xAA6F) { return true }
    if (cp >= 0xAA70 && cp <= 0xAA76) { return true }
    if (cp >= 0xAA7A && cp <= 0xAA7A) { return true }
    if (cp >= 0xAA7E && cp <= 0xAAAF) { return true }
    if (cp == 0xAAB1) { return true }
    if (cp >= 0xAAB5 && cp <= 0xAAB6) { return true }
    if (cp >= 0xAAB9 && cp <= 0xAABD) { return true }
    if (cp == 0xAAC0) { return true }
    if (cp == 0xAAC2) { return true }
    if (cp >= 0xAADB && cp <= 0xAADD) { return true }
    if (cp >= 0xAAE0 && cp <= 0xAAEA) { return true }
    if (cp >= 0xAAF2 && cp <= 0xAAF4) { return true }
    if (cp >= 0xAB01 && cp <= 0xAB06) { return true }
    if (cp >= 0xAB09 && cp <= 0xAB0E) { return true }
    if (cp >= 0xAB11 && cp <= 0xAB16) { return true }
    if (cp >= 0xAB20 && cp <= 0xAB26) { return true }
    if (cp >= 0xAB28 && cp <= 0xAB2E) { return true }
    if (cp >= 0xAB30 && cp <= 0xAB5A) { return true }
    if (cp >= 0xAB5C && cp <= 0xAB69) { return true }
    if (cp >= 0xAB70 && cp <= 0xABE2) { return true }
    // Hangul Syllables
    if (cp >= 0xAC00 && cp <= 0xD7A3) { return true }
    // CJK Extension B-H
    if (cp >= 0xD7B0 && cp <= 0xD7C6) { return true }
    if (cp >= 0xD7CB && cp <= 0xD7FB) { return true }
    if (cp >= 0xF900 && cp <= 0xFA6D) { return true }
    if (cp >= 0xFA70 && cp <= 0xFAD9) { return true }
    // Alphabetic Presentation Forms
    if (cp >= 0xFB00 && cp <= 0xFB06) { return true }
    if (cp >= 0xFB13 && cp <= 0xFB17) { return true }
    if (cp >= 0xFB1D && cp <= 0xFB28) { return true }
    if (cp >= 0xFB2A && cp <= 0xFB36) { return true }
    if (cp >= 0xFB38 && cp <= 0xFB3C) { return true }
    if (cp == 0xFB3E) { return true }
    if (cp >= 0xFB40 && cp <= 0xFB41) { return true }
    if (cp >= 0xFB43 && cp <= 0xFB44) { return true }
    if (cp >= 0xFB46 && cp <= 0xFBB1) { return true }
    if (cp >= 0xFBD3 && cp <= 0xFD3D) { return true }
    if (cp >= 0xFD50 && cp <= 0xFD8F) { return true }
    if (cp >= 0xFD92 && cp <= 0xFDC7) { return true }
    if (cp >= 0xFDF0 && cp <= 0xFDFB) { return true }
    if (cp >= 0xFE70 && cp <= 0xFE74) { return true }
    if (cp >= 0xFE76 && cp <= 0xFEFC) { return true }
    if (cp >= 0xFF21 && cp <= 0xFF3A) { return true }  // Fullwidth Latin
    if (cp >= 0xFF41 && cp <= 0xFF5A) { return true }
    if (cp >= 0xFF66 && cp <= 0xFFBE) { return true }  // Halfwidth Katakana
    if (cp >= 0xFFC2 && cp <= 0xFFC7) { return true }
    if (cp >= 0xFFCA && cp <= 0xFFCF) { return true }
    if (cp >= 0xFFD2 && cp <= 0xFFD7) { return true }
    if (cp >= 0xFFDA && cp <= 0xFFDC) { return true }
    // SMP planes
    if (cp >= 0x10000 && cp <= 0x1000B) { return true }
    if (cp >= 0x1000D && cp <= 0x10026) { return true }
    if (cp >= 0x10028 && cp <= 0x1003A) { return true }
    if (cp >= 0x1003C && cp <= 0x1003D) { return true }
    if (cp >= 0x1003F && cp <= 0x1004D) { return true }
    if (cp >= 0x10050 && cp <= 0x1005D) { return true }
    if (cp >= 0x10080 && cp <= 0x100FA) { return true }
    if (cp >= 0x10140 && cp <= 0x10174) { return true }
    if (cp >= 0x10280 && cp <= 0x1029C) { return true }
    if (cp >= 0x102A0 && cp <= 0x102D0) { return true }
    if (cp >= 0x10300 && cp <= 0x1031F) { return true }
    if (cp >= 0x1032D && cp <= 0x1034A) { return true }
    if (cp >= 0x10350 && cp <= 0x10375) { return true }
    if (cp >= 0x10380 && cp <= 0x1039D) { return true }
    if (cp >= 0x103A0 && cp <= 0x103C3) { return true }
    if (cp >= 0x103C8 && cp <= 0x103CF) { return true }
    if (cp >= 0x103D1 && cp <= 0x103D5) { return true }
    if (cp >= 0x10400 && cp <= 0x1049D) { return true }
    if (cp >= 0x104A0 && cp <= 0x104A9) { return true }
    if (cp >= 0x104B0 && cp <= 0x104D3) { return true }
    if (cp >= 0x104D8 && cp <= 0x104FB) { return true }
    if (cp >= 0x10500 && cp <= 0x10527) { return true }
    if (cp >= 0x10530 && cp <= 0x10563) { return true }
    if (cp >= 0x10600 && cp <= 0x10736) { return true }
    if (cp >= 0x10740 && cp <= 0x10755) { return true }
    if (cp >= 0x10760 && cp <= 0x10767) { return true }
    if (cp >= 0x10800 && cp <= 0x10805) { return true }
    if (cp == 0x10808) { return true }
    if (cp >= 0x1080A && cp <= 0x10835) { return true }
    if (cp >= 0x10837 && cp <= 0x10838) { return true }
    if (cp >= 0x1083C && cp <= 0x1083C) { return true }
    if (cp >= 0x1083F && cp <= 0x10855) { return true }
    if (cp >= 0x10860 && cp <= 0x10876) { return true }
    if (cp >= 0x10880 && cp <= 0x1089E) { return true }
    if (cp >= 0x108E0 && cp <= 0x108F2) { return true }
    if (cp >= 0x108F4 && cp <= 0x108F5) { return true }
    if (cp >= 0x10900 && cp <= 0x10915) { return true }
    if (cp >= 0x10920 && cp <= 0x10939) { return true }
    if (cp >= 0x10980 && cp <= 0x109B7) { return true }
    if (cp >= 0x109BE && cp <= 0x109BF) { return true }
    if (cp >= 0x10A00 && cp <= 0x10A03) { return true }
    if (cp >= 0x10A05 && cp <= 0x10A06) { return true }
    if (cp >= 0x10A0C && cp <= 0x10A13) { return true }
    if (cp >= 0x10A15 && cp <= 0x10A17) { return true }
    if (cp >= 0x10A19 && cp <= 0x10A35) { return true }
    if (cp >= 0x10A38 && cp <= 0x10A3A) { return true }
    if (cp == 0x10A3F) { return true }
    if (cp >= 0x10A60 && cp <= 0x10A7C) { return true }
    if (cp >= 0x10A80 && cp <= 0x10A9C) { return true }
    if (cp >= 0x10AC0 && cp <= 0x10AC7) { return true }
    if (cp >= 0x10AC9 && cp <= 0x10AE6) { return true }
    if (cp >= 0x10B00 && cp <= 0x10B35) { return true }
    if (cp >= 0x10B40 && cp <= 0x10B55) { return true }
    if (cp >= 0x10B60 && cp <= 0x10B72) { return true }
    if (cp >= 0x10B80 && cp <= 0x10B91) { return true }
    if (cp >= 0x10C00 && cp <= 0x10C48) { return true }
    if (cp >= 0x10C80 && cp <= 0x10CB2) { return true }
    if (cp >= 0x10CC0 && cp <= 0x10CF2) { return true }
    if (cp >= 0x10D00 && cp <= 0x10D27) { return true }
    if (cp >= 0x10E80 && cp <= 0x10EA9) { return true }
    if (cp >= 0x10F00 && cp <= 0x10F1C) { return true }
    if (cp >= 0x10F27 && cp <= 0x10F27) { return true }
    if (cp >= 0x10F30 && cp <= 0x10F50) { return true }
    if (cp >= 0x10FE0 && cp <= 0x10FF6) { return true }
    // CJK Extension G-K
    if (cp >= 0x11003 && cp <= 0x11037) { return true }
    if (cp >= 0x11083 && cp <= 0x110AF) { return true }
    if (cp >= 0x110D0 && cp <= 0x110E8) { return true }
    if (cp >= 0x11103 && cp <= 0x11126) { return true }
    if (cp >= 0x11150 && cp <= 0x11172) { return true }
    if (cp >= 0x11183 && cp <= 0x111B2) { return true }
    if (cp >= 0x111C1 && cp <= 0x111C4) { return true }
    if (cp >= 0x11200 && cp <= 0x11211) { return true }
    if (cp >= 0x11213 && cp <= 0x1122B) { return true }
    if (cp >= 0x11280 && cp <= 0x11286) { return true }
    if (cp >= 0x11288 && cp <= 0x11288) { return true }
    if (cp >= 0x1128A && cp <= 0x1128D) { return true }
    if (cp >= 0x1128F && cp <= 0x1129D) { return true }
    if (cp >= 0x1129F && cp <= 0x112A8) { return true }
    if (cp >= 0x112B0 && cp <= 0x112DE) { return true }
    if (cp >= 0x11305 && cp <= 0x1130C) { return true }
    if (cp >= 0x1130F && cp <= 0x11310) { return true }
    if (cp >= 0x11313 && cp <= 0x11328) { return true }
    if (cp >= 0x1132A && cp <= 0x11330) { return true }
    if (cp >= 0x11332 && cp <= 0x11333) { return true }
    if (cp >= 0x11335 && cp <= 0x11339) { return true }
    if (cp >= 0x1135D && cp <= 0x11361) { return true }
    if (cp >= 0x11400 && cp <= 0x11434) { return true }
    if (cp >= 0x11447 && cp <= 0x1144A) { return true }
    if (cp >= 0x11480 && cp <= 0x114AF) { return true }
    if (cp >= 0x114C4 && cp <= 0x114C5) { return true }
    if (cp >= 0x11500 && cp <= 0x11530) { return true }
    if (cp >= 0x11580 && cp <= 0x115AE) { return true }
    if (cp >= 0x11600 && cp <= 0x1162F) { return true }
    if (cp >= 0x11680 && cp <= 0x116AA) { return true }
    if (cp >= 0x11700 && cp <= 0x1171A) { return true }
    if (cp >= 0x11800 && cp <= 0x1182B) { return true }
    if (cp >= 0x118A0 && cp <= 0x118F2) { return true }
    if (cp >= 0x11A00 && cp <= 0x11A00) { return true }
    if (cp >= 0x11A0B && cp <= 0x11A32) { return true }
    if (cp >= 0x11A50 && cp <= 0x11A50) { return true }
    if (cp >= 0x11A5C && cp <= 0x11A89) { return true }
    if (cp >= 0x11AC0 && cp <= 0x11AF8) { return true }
    if (cp >= 0x11C00 && cp <= 0x11C08) { return true }
    if (cp >= 0x11C0A && cp <= 0x11C2E) { return true }
    if (cp >= 0x11C40 && cp <= 0x11C40) { return true }
    if (cp >= 0x11C72 && cp <= 0x11C8F) { return true }
    if (cp >= 0x11D00 && cp <= 0x11D06) { return true }
    if (cp >= 0x11D08 && cp <= 0x11D09) { return true }
    if (cp >= 0x11D0B && cp <= 0x11D30) { return true }
    if (cp >= 0x11D60 && cp <= 0x11D65) { return true }
    if (cp >= 0x11D67 && cp <= 0x11D68) { return true }
    if (cp >= 0x11D6A && cp <= 0x11D89) { return true }
    if (cp >= 0x11EE0 && cp <= 0x11EF2) { return true }
    if (cp >= 0x11F02 && cp <= 0x11F02) { return true }
    if (cp >= 0x11F10 && cp <= 0x11F10) { return true }
    if (cp >= 0x11F12 && cp <= 0x11F35) { return true }
    if (cp >= 0x11F44 && cp <= 0x11F4E) { return true }
    // CJK Unified Ideographs Extension B-K
    if (cp >= 0x12000 && cp <= 0x12399) { return true }  // Cuneiform
    if (cp >= 0x12400 && cp <= 0x1246E) { return true }
    if (cp >= 0x12480 && cp <= 0x12543) { return true }
    if (cp >= 0x13000 && cp <= 0x1342F) { return true }  // Egyptian Hieroglyphs
    if (cp >= 0x13460 && cp <= 0x143FA) { return true }
    if (cp >= 0x14400 && cp <= 0x14646) { return true }
    if (cp >= 0x16800 && cp <= 0x16A38) { return true }  // Bamum
    if (cp >= 0x16A40 && cp <= 0x16A5E) { return true }
    if (cp >= 0x16AD0 && cp <= 0x16AED) { return true }
    if (cp >= 0x16B00 && cp <= 0x16B2F) { return true }
    if (cp >= 0x16B40 && cp <= 0x16B43) { return true }
    if (cp >= 0x16B63 && cp <= 0x16B77) { return true }
    if (cp >= 0x16B7D && cp <= 0x16B8F) { return true }
    if (cp >= 0x16E40 && cp <= 0x16E7F) { return true }  // Medefaidrin
    if (cp >= 0x16F00 && cp <= 0x16F4A) { return true }  // Miao
    if (cp >= 0x16F50 && cp <= 0x16F87) { return true }
    if (cp >= 0x16F8F && cp <= 0x16F9F) { return true }
    if (cp >= 0x1BC00 && cp <= 0x1BC6A) { return true }  // Duployan
    if (cp >= 0x1BC70 && cp <= 0x1BC7C) { return true }
    if (cp >= 0x1BC80 && cp <= 0x1BC88) { return true }
    if (cp >= 0x1BC90 && cp <= 0x1BC99) { return true }
    if (cp >= 0x1BC9D && cp <= 0x1BC9E) { return true }
    if (cp >= 0x1D400 && cp <= 0x1D454) { return true }  // Math Alphanumeric
    if (cp >= 0x1D456 && cp <= 0x1D49C) { return true }
    if (cp >= 0x1D49E && cp <= 0x1D49F) { return true }
    if (cp == 0x1D4A2) { return true }
    if (cp >= 0x1D4A5 && cp <= 0x1D4A6) { return true }
    if (cp == 0x1D4A9) { return true }
    if (cp >= 0x1D4AE && cp <= 0x1D4B9) { return true }
    if (cp == 0x1D4BB) { return true }
    if (cp >= 0x1D4BD && cp <= 0x1D4C3) { return true }
    if (cp >= 0x1D4C5 && cp <= 0x1D505) { return true }
    if (cp >= 0x1D507 && cp <= 0x1D50A) { return true }
    if (cp >= 0x1D50D && cp <= 0x1D514) { return true }
    if (cp >= 0x1D516 && cp <= 0x1D51C) { return true }
    if (cp >= 0x1D51E && cp <= 0x1D539) { return true }
    if (cp >= 0x1D53B && cp <= 0x1D53E) { return true }
    if (cp >= 0x1D540 && cp <= 0x1D544) { return true }
    if (cp == 0x1D546) { return true }
    if (cp >= 0x1D54A && cp <= 0x1D550) { return true }
    if (cp >= 0x1D552 && cp <= 0x1D6A5) { return true }
    if (cp >= 0x1D6A8 && cp <= 0x1D6C0) { return true }
    if (cp >= 0x1D6C2 && cp <= 0x1D6DA) { return true }
    if (cp >= 0x1D6DC && cp <= 0x1D6FA) { return true }
    if (cp >= 0x1D6FC && cp <= 0x1D714) { return true }
    if (cp >= 0x1D716 && cp <= 0x1D734) { return true }
    if (cp >= 0x1D736 && cp <= 0x1D74E) { return true }
    if (cp >= 0x1D750 && cp <= 0x1D76E) { return true }
    if (cp >= 0x1D770 && cp <= 0x1D788) { return true }
    if (cp >= 0x1D78A && cp <= 0x1D7A8) { return true }
    if (cp >= 0x1D7AA && cp <= 0x1D7C2) { return true }
    if (cp >= 0x1D7C4 && cp <= 0x1D7CB) { return true }
    if (cp >= 0x1E100 && cp <= 0x1E12C) { return true }  // Nyiakeng Puachue Hmong
    if (cp >= 0x1E137 && cp <= 0x1E13D) { return true }
    if (cp >= 0x1E14E && cp <= 0x1E14F) { return true }
    if (cp >= 0x1E2C0 && cp <= 0x1E2F9) { return true }  // Wancho
    if (cp >= 0x1E800 && cp <= 0x1E8C4) { return true }  // Mende Kikakui
    if (cp >= 0x1E900 && cp <= 0x1E943) { return true }  // Adlam
    if (cp >= 0x1E94B && cp <= 0x1E94F) { return true }
    if (cp >= 0x1EE00 && cp <= 0x1EE03) { return true }  // Arabic Math
    if (cp >= 0x1EE05 && cp <= 0x1EE1F) { return true }
    if (cp >= 0x1EE21 && cp <= 0x1EE22) { return true }
    if (cp == 0x1EE24) { return true }
    if (cp >= 0x1EE27 && cp <= 0x1EE27) { return true }
    if (cp >= 0x1EE29 && cp <= 0x1EE32) { return true }
    if (cp >= 0x1EE34 && cp <= 0x1EE37) { return true }
    if (cp == 0x1EE39) { return true }
    if (cp >= 0x1EE3B && cp <= 0x1EE3B) { return true }
    if (cp >= 0x1EE42 && cp <= 0x1EE42) { return true }
    if (cp >= 0x1EE47 && cp <= 0x1EE47) { return true }
    if (cp >= 0x1EE49 && cp <= 0x1EE49) { return true }
    if (cp >= 0x1EE4B && cp <= 0x1EE4B) { return true }
    if (cp >= 0x1EE4D && cp <= 0x1EE4F) { return true }
    if (cp >= 0x1EE51 && cp <= 0x1EE52) { return true }
    if (cp >= 0x1EE54 && cp <= 0x1EE54) { return true }
    if (cp >= 0x1EE57 && cp <= 0x1EE57) { return true }
    if (cp >= 0x1EE59 && cp <= 0x1EE59) { return true }
    if (cp >= 0x1EE5B && cp <= 0x1EE5B) { return true }
    if (cp >= 0x1EE5D && cp <= 0x1EE5D) { return true }
    if (cp >= 0x1EE5F && cp <= 0x1EE5F) { return true }
    if (cp >= 0x1EE61 && cp <= 0x1EE62) { return true }
    if (cp >= 0x1EE64 && cp <= 0x1EE64) { return true }
    if (cp >= 0x1EE67 && cp <= 0x1EE6A) { return true }
    if (cp >= 0x1EE6C && cp <= 0x1EE72) { return true }
    if (cp >= 0x1EE74 && cp <= 0x1EE77) { return true }
    if (cp >= 0x1EE79 && cp <= 0x1EE7C) { return true }
    if (cp >= 0x1EE7E && cp <= 0x1EE7E) { return true }
    if (cp >= 0x1EE80 && cp <= 0x1EE89) { return true }
    if (cp >= 0x1EE8B && cp <= 0x1EE9B) { return true }
    if (cp >= 0x1EEA1 && cp <= 0x1EEA3) { return true }
    if (cp >= 0x1EEA5 && cp <= 0x1EEA9) { return true }
    if (cp >= 0x1EEAB && cp <= 0x1EEBB) { return true }
    if (cp >= 0x20000 && cp <= 0x2A6DF) { return true }  // CJK Ext B
    if (cp >= 0x2A700 && cp <= 0x2B739) { return true }  // CJK Ext C
    if (cp >= 0x2B740 && cp <= 0x2B81D) { return true }  // CJK Ext D
    if (cp >= 0x2B820 && cp <= 0x2CEA1) { return true }  // CJK Ext E
    if (cp >= 0x2CEB0 && cp <= 0x2EBE0) { return true }  // CJK Ext F
    if (cp >= 0x2F800 && cp <= 0x2FA1D) { return true }  // CJK Compat
    if (cp >= 0x30000 && cp <= 0x3134A) { return true }  // CJK Ext G
    if (cp >= 0x31350 && cp <= 0x323AF) { return true }  // CJK Ext H

    return false
}

/// 判断码点是否可以作为标识符续接字符
/// 对应 Unicode ID_Continue 属性
/// ID_Continue = ID_Start + Mn/Mc/Nd/Pc + 特定范围
public func isIdentifierContinue(cp: UInt32): Bool {
    // 快速路径: ID_Start 包含的内容
    if (isIdentifierStart(cp)) { return true }

    // ASCII digits
    if (cp >= UInt32('0') && cp <= UInt32('9')) { return true }
    // ZWNJ (U+200C) and ZWJ (U+200E) - ECMAScript 允许
    if (cp == 0x200C || cp == 0x200D) { return true }

    // Mn (Nonspacing Mark) - 组合标记
    if (cp >= 0x0300 && cp <= 0x036F) { return true }
    if (cp >= 0x0483 && cp <= 0x0487) { return true }
    if (cp >= 0x0591 && cp <= 0x05BD) { return true }
    if (cp == 0x05BF) { return true }
    if (cp >= 0x05C1 && cp <= 0x05C2) { return true }
    if (cp >= 0x05C4 && cp <= 0x05C5) { return true }
    if (cp == 0x05C7) { return true }
    if (cp >= 0x0610 && cp <= 0x061A) { return true }
    if (cp >= 0x064B && cp <= 0x065F) { return true }
    if (cp == 0x0670) { return true }
    if (cp >= 0x06D6 && cp <= 0x06DC) { return true }
    if (cp >= 0x06DF && cp <= 0x06E4) { return true }
    if (cp >= 0x06E7 && cp <= 0x06E8) { return true }
    if (cp >= 0x06EA && cp <= 0x06ED) { return true }
    if (cp >= 0x0711 && cp <= 0x0711) { return true }
    if (cp >= 0x0730 && cp <= 0x074A) { return true }
    if (cp >= 0x07A6 && cp <= 0x07B0) { return true }
    if (cp >= 0x07EB && cp <= 0x07F3) { return true }
    if (cp == 0x07FD) { return true }
    if (cp >= 0x0816 && cp <= 0x0819) { return true }
    if (cp >= 0x081B && cp <= 0x0823) { return true }
    if (cp >= 0x0825 && cp <= 0x0827) { return true }
    if (cp >= 0x0829 && cp <= 0x082D) { return true }
    if (cp >= 0x0859 && cp <= 0x085B) { return true }
    if (cp >= 0x08D3 && cp <= 0x08E1) { return true }
    if (cp >= 0x08E3 && cp <= 0x0902) { return true }
    if (cp == 0x093A) { return true }
    if (cp == 0x093C) { return true }
    if (cp >= 0x0941 && cp <= 0x0948) { return true }
    if (cp >= 0x094D && cp <= 0x094D) { return true }
    if (cp >= 0x0951 && cp <= 0x0957) { return true }
    if (cp >= 0x0962 && cp <= 0x0963) { return true }
    if (cp >= 0x0981 && cp <= 0x0981) { return true }
    if (cp == 0x09BC) { return true }
    if (cp == 0x09BE) { return true }
    if (cp >= 0x09C1 && cp <= 0x09C4) { return true }
    if (cp == 0x09CD) { return true }
    if (cp == 0x09D7) { return true }
    if (cp >= 0x09E2 && cp <= 0x09E3) { return true }
    if (cp >= 0x09FE && cp <= 0x09FE) { return true }
    if (cp >= 0x0A01 && cp <= 0x0A02) { return true }
    if (cp == 0x0A3C) { return true }
    if (cp >= 0x0A41 && cp <= 0x0A42) { return true }
    if (cp >= 0x0A47 && cp <= 0x0A48) { return true }
    if (cp >= 0x0A4B && cp <= 0x0A4D) { return true }
    if (cp == 0x0A51) { return true }
    if (cp >= 0x0A70 && cp <= 0x0A71) { return true }
    if (cp == 0x0A75) { return true }
    if (cp >= 0x0A81 && cp <= 0x0A82) { return true }
    if (cp == 0x0ABC) { return true }
    if (cp >= 0x0AC1 && cp <= 0x0AC5) { return true }
    if (cp >= 0x0AC7 && cp <= 0x0AC8) { return true }
    if (cp == 0x0ACD) { return true }
    if (cp >= 0x0AE2 && cp <= 0x0AE3) { return true }
    if (cp >= 0x0AFA && cp <= 0x0AFF) { return true }
    if (cp >= 0x0B01 && cp <= 0x0B01) { return true }
    if (cp == 0x0B3C) { return true }
    if (cp == 0x0B3E) { return true }
    if (cp >= 0x0B3F && cp <= 0x0B3F) { return true }
    if (cp >= 0x0B41 && cp <= 0x0B44) { return true }
    if (cp == 0x0B4D) { return true }
    if (cp >= 0x0B55 && cp <= 0x0B56) { return true }
    if (cp == 0x0B57) { return true }
    if (cp >= 0x0B62 && cp <= 0x0B63) { return true }
    if (cp == 0x0B82) { return true }
    if (cp == 0x0BBE) { return true }
    if (cp == 0x0BC0) { return true }
    if (cp >= 0x0BCD && cp <= 0x0BCD) { return true }
    if (cp == 0x0BD7) { return true }
    if (cp >= 0x0C00 && cp <= 0x0C00) { return true }
    if (cp >= 0x0C04 && cp <= 0x0C04) { return true }
    if (cp == 0x0C3C) { return true }
    if (cp >= 0x0C3E && cp <= 0x0C40) { return true }
    if (cp >= 0x0C46 && cp <= 0x0C48) { return true }
    if (cp >= 0x0C4A && cp <= 0x0C4D) { return true }
    if (cp >= 0x0C55 && cp <= 0x0C56) { return true }
    if (cp >= 0x0C62 && cp <= 0x0C63) { return true }
    if (cp >= 0x0C81 && cp <= 0x0C81) { return true }
    if (cp == 0x0CBC) { return true }
    if (cp == 0x0CBF) { return true }
    if (cp == 0x0CC2) { return true }
    if (cp == 0x0CC6) { return true }
    if (cp >= 0x0CCC && cp <= 0x0CCD) { return true }
    if (cp >= 0x0CD5 && cp <= 0x0CD6) { return true }
    if (cp >= 0x0CE2 && cp <= 0x0CE3) { return true }
    if (cp >= 0x0D00 && cp <= 0x0D01) { return true }
    if (cp >= 0x0D3B && cp <= 0x0D3C) { return true }
    if (cp == 0x0D3E) { return true }
    if (cp >= 0x0D41 && cp <= 0x0D44) { return true }
    if (cp == 0x0D4D) { return true }
    if (cp == 0x0D57) { return true }
    if (cp >= 0x0D62 && cp <= 0x0D63) { return true }

    // Mc (Spacing Combining Mark)
    if (cp >= 0x0903 && cp <= 0x0903) { return true }
    if (cp >= 0x093B && cp <= 0x093B) { return true }
    if (cp >= 0x093E && cp <= 0x0940) { return true }
    if (cp >= 0x0949 && cp <= 0x094C) { return true }
    if (cp >= 0x094E && cp <= 0x094F) { return true }
    if (cp >= 0x0982 && cp <= 0x0983) { return true }
    if (cp >= 0x09BF && cp <= 0x09C0) { return true }
    if (cp >= 0x09C7 && cp <= 0x09C8) { return true }
    if (cp >= 0x09CB && cp <= 0x09CC) { return true }

    // Nd (Decimal Number)
    if (cp >= 0x0660 && cp <= 0x0669) { return true }  // Arabic-Indic
    if (cp >= 0x06F0 && cp <= 0x06F9) { return true }  // Extended Arabic-Indic
    if (cp >= 0x07C0 && cp <= 0x07C9) { return true }  // NKo
    if (cp >= 0x0966 && cp <= 0x096F) { return true }  // Devanagari
    if (cp >= 0x09E6 && cp <= 0x09EF) { return true }  // Bengali
    if (cp >= 0x0A66 && cp <= 0x0A6F) { return true }  // Gurmukhi
    if (cp >= 0x0AE6 && cp <= 0x0AEF) { return true }  // Gujarati
    if (cp >= 0x0B66 && cp <= 0x0B6F) { return true }  // Oriya
    if (cp >= 0x0BE6 && cp <= 0x0BEF) { return true }  // Tamil
    if (cp >= 0x0C66 && cp <= 0x0C6F) { return true }  // Telugu
    if (cp >= 0x0CE6 && cp <= 0x0CEF) { return true }  // Kannada
    if (cp >= 0x0D66 && cp <= 0x0D6F) { return true }  // Malayalam
    if (cp >= 0x0DE6 && cp <= 0x0DEF) { return true }  // Sinhala
    if (cp >= 0x0E50 && cp <= 0x0E59) { return true }  // Thai
    if (cp >= 0x0ED0 && cp <= 0x0ED9) { return true }  // Lao
    if (cp >= 0x0F20 && cp <= 0x0F29) { return true }  // Tibetan
    if (cp >= 0x1040 && cp <= 0x1049) { return true }  // Myanmar
    if (cp >= 0x1090 && cp <= 0x1099) { return true }
    if (cp >= 0x17E0 && cp <= 0x17E9) { return true }  // Khmer
    if (cp >= 0x1810 && cp <= 0x1819) { return true }  // Mongolian
    if (cp >= 0x1946 && cp <= 0x194F) { return true }  // Limbu
    if (cp >= 0x19D0 && cp <= 0x19D9) { return true }  // New Tai Lue
    if (cp >= 0x1A80 && cp <= 0x1A89) { return true }  // Tai Tham Hora
    if (cp >= 0x1A90 && cp <= 0x1A99) { return true }  // Tai Tham
    if (cp >= 0x1B50 && cp <= 0x1B59) { return true }  // Balinese
    if (cp >= 0x1BB0 && cp <= 0x1BB9) { return true }  // Sundanese
    if (cp >= 0x1C40 && cp <= 0x1C49) { return true }  // Lepcha
    if (cp >= 0x1C50 && cp <= 0x1C59) { return true }  // Ol Chiki
    if (cp >= 0xA620 && cp <= 0xA629) { return true }  // Vai
    if (cp >= 0xA8D0 && cp <= 0xA8D9) { return true }  // Saurashtra
    if (cp >= 0xA900 && cp <= 0xA909) { return true }  // Kayah Li
    if (cp >= 0xA9D0 && cp <= 0xA9D9) { return true }  // Javanese
    if (cp >= 0xA9F0 && cp <= 0xA9F9) { return true }  // Myanmar Extended-B
    if (cp >= 0xAA50 && cp <= 0xAA59) { return true }  // Cham
    if (cp >= 0xABF0 && cp <= 0xABF9) { return true }  // Meetei Mayek
    if (cp >= 0xFF10 && cp <= 0xFF19) { return true }  // Fullwidth
    if (cp >= 0x104A0 && cp <= 0x104A9) { return true }  // Osmanya
    if (cp >= 0x11066 && cp <= 0x1106F) { return true }  // Brahmi
    if (cp >= 0x110F0 && cp <= 0x110F9) { return true }  // Sora Sompeng
    if (cp >= 0x11136 && cp <= 0x1113F) { return true }  // Chakma
    if (cp >= 0x111D0 && cp <= 0x111D9) { return true }  // Sharada
    if (cp >= 0x112F0 && cp <= 0x112F9) { return true }  // Khojki
    if (cp >= 0x11450 && cp <= 0x11459) { return true }  // Newa
    if (cp >= 0x114D0 && cp <= 0x114D9) { return true }  // Tirhuta
    if (cp >= 0x11650 && cp <= 0x11659) { return true }  // Modi
    if (cp >= 0x116C0 && cp <= 0x116C9) { return true }  // Takri
    if (cp >= 0x11730 && cp <= 0x11739) { return true }  // Ahom
    if (cp >= 0x118E0 && cp <= 0x118E9) { return true }  // Warang Citi
    if (cp >= 0x11C50 && cp <= 0x11C59) { return true }  // Bhaiksuki
    if (cp >= 0x11D50 && cp <= 0x11D59) { return true }  // Masaram Gondi
    if (cp >= 0x16A60 && cp <= 0x16A69) { return true }  // Mro
    if (cp >= 0x16B50 && cp <= 0x16B59) { return true }  // Pahawh Hmong
    if (cp >= 0x1D7CE && cp <= 0x1D7FF) { return true }  // Math digits
    if (cp >= 0x1E140 && cp <= 0x1E149) { return true }  // Nyiakeng Puachue Hmong
    if (cp >= 0x1E2F0 && cp <= 0x1E2F9) { return true }  // Wancho
    if (cp >= 0x1E950 && cp <= 0x1E959) { return true }  // Adlam

    // Pc (Connector Punctuation)
    if (cp == 0x005F) { return true }  // _
    if (cp == 0x203F || cp == 0x2040) { return true }  // ‿ ⁀
    if (cp == 0x2054) { return true }  // ⁔
    if (cp == 0xFE33 || cp == 0xFE34) { return true }  // ︳ ︴
    if (cp == 0xFE4D || cp == 0xFE4E || cp == 0xFE4F) { return true }  // ﹍ ﹎ ﹏
    if (cp == 0xFF3F) { return true }  // ＿

    return false
}
