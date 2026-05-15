// bao_unicode - ASCII 字符判断
// 严格翻译自: src/unicode/uucode_lib/src/ascii.zig
//   提供 ASCII 范围内的字符分类函数
//   isAlphanumeric, isAlphabetic, isControl, isDigit 等
//   仓颉实现提供等价的 ASCII 判断函数
package bao_unicode.uucode_lib

// ============================================================================
// ASCII 字符判断
// 严格翻译自: src/unicode/uucode_lib/src/ascii.zig
//   所有函数接受 u21 码点参数
//   对于 ASCII 范围内的字符返回 true/false
//   对于非 ASCII 字符一律返回 false (除了 isAscii 本身)
// ============================================================================

/// 是否为字母数字: A-Z, a-z, 0-9
/// 翻译自: pub fn isAlphanumeric(c: u21) bool
public func isAsciiAlphanumeric(c: UInt32): Bool {
    return (c >= 0x30 && c <= 0x39) ||  // 0-9
           (c >= 0x41 && c <= 0x5A) ||  // A-Z
           (c >= 0x61 && c <= 0x7A)     // a-z
}

/// 是否为字母: A-Z, a-z
/// 翻译自: pub fn isAlphabetic(c: u21) bool
public func isAsciiAlphabetic(c: UInt32): Bool {
    return (c >= 0x41 && c <= 0x5A) ||  // A-Z
           (c >= 0x61 && c <= 0x7A)     // a-z
}

/// 是否为控制字符
/// 翻译自: pub fn isControl(c: u21) bool
///   C0 (0x00-0x1F) + DEL (0x7F)
public func isAsciiControl(c: UInt32): Bool {
    return c <= 0x1F || c == 0x7F
}

/// 是否为数字: 0-9
/// 翻译自: pub fn isDigit(c: u21) bool
public func isAsciiDigit(c: UInt32): Bool {
    return c >= 0x30 && c <= 0x39
}

/// 是否为小写字母: a-z
/// 翻译自: pub fn isLower(c: u21) bool
public func isAsciiLower(c: UInt32): Bool {
    return c >= 0x61 && c <= 0x7A
}

/// 是否为可打印字符 (包含空格)
/// 翻译自: pub fn isPrint(c: u21) bool
public func isAsciiPrint(c: UInt32): Bool {
    return isAscii(c) && !isAsciiControl(c)
}

/// 是否为空白字符: space, tab, newline 等
/// 翻译自: pub fn isWhitespace(c: u21) bool
public func isAsciiWhitespace(c: UInt32): Bool {
    return c == 0x20 ||    // space
           (c >= 0x09 && c <= 0x0D)  // tab, newline, vertical tab, form feed, carriage return
}

/// 是否为大写字母: A-Z
/// 翻译自: pub fn isUpper(c: u21) bool
public func isAsciiUpper(c: UInt32): Bool {
    return c >= 0x41 && c <= 0x5A
}

/// 是否为十六进制数字: 0-9, A-F, a-f
/// 翻译自: pub fn isHex(c: u21) bool
public func isAsciiHex(c: UInt32): Bool {
    return (c >= 0x30 && c <= 0x39) ||  // 0-9
           (c >= 0x41 && c <= 0x46) ||  // A-F
           (c >= 0x61 && c <= 0x66)     // a-f
}

/// 是否为 ASCII 字符 (< 128)
/// 翻译自: pub fn isAscii(c: u21) bool
public func isAscii(c: UInt32): Bool {
    return c < 128
}

/// 转为大写
/// 翻译自: pub fn toUpper(c: u21) u21
///   如果是小写字母则转为大写, 否则不变
public func asciiToUpper(c: UInt32): UInt32 {
    if (isAsciiLower(c)) {
        return c ^ 0x20
    }
    return c
}

/// 转为小写
/// 翻译自: pub fn toLower(c: u21) u21
///   如果是大写字母则转为小写, 否则不变
public func asciiToLower(c: UInt32): UInt32 {
    if (isAsciiUpper(c)) {
        return c | 0x20
    }
    return c
}
