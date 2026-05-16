// 严格翻译自: src/string/immutable.zig
// 公共字符串工具函数
//   提供字符串操作的核心函数集合:
//   - 编码枚举 (Encoding, AsciiStatus, EncodingNonAscii)
//   - 字符查找 (indexOf, lastIndexOf, indexOfChar)
//   - 字符串比较 (eql, eqlLong, eqlCaseInsensitive)
//   - 前缀/后缀检查 (startsWith, endsWith, hasPrefix)
//   - 字符串分割 (split, splitFirst)
//   - 字符串拼接 (cat, concat, append)
//   - 大小写转换 (copyLowercase)
//   - 十六进制编解码 (decodeHexToBytes, encodeBytesToHex)
//   - 字符修剪 (trim, trimSpaces)
//   - 行操作 (indexOfLineRanges, getLinesInText)
//   - UUID/npm包名/URL密码检测
//   - ANSI迭代器
//   - 字符排序 (sortAsc, sortDesc)
package bao_string

import bao_core.*
import bao_unicode.*

// ============================================================================
// 类型别名
// ============================================================================

/// Unicode 替换字符
/// 严格翻译自 immutable.zig unicode_replacement
public const UNICODE_REPLACEMENT: UInt32 = 0xFFFD

/// 码点类型
/// 严格翻译自 immutable.zig CodePoint
public type CodePoint = Int32

// ============================================================================
// 枚举类型
// ============================================================================

/// 字符串编码类型
/// 严格翻译自 immutable.zig Encoding
public enum Encoding {
    | ASCII
    | UTF8
    | Latin1
    | UTF16
}

/// ASCII 状态
/// 严格翻译自 immutable.zig AsciiStatus
public enum AsciiStatus {
    | Unknown
    | AllASCII
    | NonASCII

    /// 从布尔值创建
    /// 严格翻译自 AsciiStatus.fromBool
    public static func fromBool(isAllASCII: ?Bool): AsciiStatus {
        let val = isAllASCII ?? return Unknown
        if (val) {
            return AllASCII
        }
        return NonASCII
    }
}

/// 编码类型(不含 ASCII 区分)
/// 严格翻译自 immutable.zig EncodingNonAscii
public enum EncodingNonAscii {
    | UTF8
    | UTF16
    | Latin1
}

/// 排序顺序
/// 严格翻译自 std.math.Order
public enum Order {
    | LT
    | EQ
    | GT
}

// ============================================================================
// 字符查找函数
// ============================================================================

/// 判断字符串是否包含指定字符
/// 严格翻译自 immutable.zig containsChar
public func containsChar(self: String, char: Byte): Bool {
    return indexOfChar(self, char) != -1
}

/// 判断字符串是否包含指定子串
/// 严格翻译自 immutable.zig contains
public func contains(self: String, str: String): Bool {
    return indexOf(self, str) != -1
}

/// 大小写不敏感的包含检查
/// 严格翻译自 immutable.zig containsCaseInsensitiveASCII
public func containsCaseInsensitiveASCII(self: String, str: String): Bool {
    if (str.size == 0) {
        return true
    }
    var start: Int64 = 0
    while (start + str.size <= self.size) {
        if (eqlCaseInsensitiveASCIIIgnoreLength(self[start..start + str.size], str)) {
            return true
        }
        start += 1
    }
    return false
}

/// 查找任意字符集中第一个字符的位置
/// 严格翻译自 immutable.zig indexOfAny
public func indexOfAny(slice: String, chars: String): Int64 {
    if (chars.size == 0) {
        return -1
    }
    if (chars.size == 1) {
        return indexOfChar(slice, chars[0])
    }
    for (i in 0..slice.size) {
        for (j in 0..chars.size) {
            if (slice[i] == chars[j]) {
                return i
            }
        }
    }
    return -1
}

/// 在 UTF-16 切片中查找任意字符
/// 严格翻译自 immutable.zig indexOfAny16 / indexOfAnyT
public func indexOfAny16(str: Array<UInt16>, chars: Array<UInt16>): Int64 {
    for (i in 0..str.size) {
        for (j in 0..chars.size) {
            if (str[i] == chars[j]) {
                return i
            }
        }
    }
    return -1
}

/// 查找字符位置(返回有符号整数)
/// 严格翻译自 immutable.zig indexOfCharNeg
public func indexOfCharNeg(self: String, char: Byte): Int32 {
    for (i in 0..self.size) {
        if (self[i] == char) {
            return Int32(i)
        }
    }
    return -1
}

/// 查找子串位置(返回有符号整数)
/// 严格翻译自 immutable.zig indexOfSigned
public func indexOfSigned(self: String, str: String): Int32 {
    let i = indexOf(self, str)
    if (i >= 0) {
        return Int32(i)
    }
    return -1
}

/// 查找字符最后一次出现的位置
/// 严格翻译自 immutable.zig lastIndexOfChar
public func lastIndexOfChar(self: String, char: Byte): Int64 {
    var i = self.size - 1
    while (i >= 0) {
        if (self[i] == char) {
            return i
        }
        i -= 1
    }
    return -1
}

/// 在另一个字符之前查找指定字符最后出现的位置
/// 严格翻译自 immutable.zig lastIndexBeforeChar
public func lastIndexBeforeChar(input: String, char: Byte, before: Byte): Int64 {
    let beforePos = indexOfChar(input, before)
    let end = beforePos >= 0 ? beforePos : input.size
    return lastIndexOfChar(input[0..end], char)
}

/// 查找子串最后一次出现的位置
/// 严格翻译自 immutable.zig lastIndexOf
public func lastIndexOf(self: String, str: String): Int64 {
    if (str.size == 0) {
        return self.size
    }
    if (str.size > self.size) {
        return -1
    }
    var i = self.size - str.size
    while (i >= 0) {
        if (eqlLong(self[i..i + str.size], str, false)) {
            return i
        }
        i -= 1
    }
    return -1
}

/// 查找子串位置
/// 严格翻译自 immutable.zig indexOf
public func indexOf(self: String, str: String): Int64 {
    if (self.size == 0 || str.size == 0 || self.size < str.size) {
        return -1
    }

    if (str.size == 1) {
        return indexOfChar(self, str[0])
    }

    // 标准 memmem 搜索
    var i: Int64 = 0
    while (i <= self.size - str.size) {
        if (eqlLong(self[i..i + str.size], str, false)) {
            return i
        }
        i += 1
    }
    return -1
}

/// 查找字符位置
/// 严格翻译自 immutable.zig indexOfChar
public func indexOfChar(slice: String, char: Byte): Int64 {
    for (i in 0..slice.size) {
        if (slice[i] == char) {
            return i
        }
    }
    return -1
}

/// 从指定位置开始查找字符
/// 严格翻译自 immutable.zig indexOfCharPos
public func indexOfCharPos(slice: String, char: Byte, startIndex: Int64): Int64 {
    if (startIndex >= slice.size) {
        return -1
    }
    for (i in startIndex..slice.size) {
        if (slice[i] == char) {
            return i
        }
    }
    return -1
}

/// 查找第一个不等于指定字符的位置
/// 严格翻译自 immutable.zig indexOfNotChar
public func indexOfNotChar(slice: String, char: Byte): Int64 {
    if (slice.size == 0) {
        return -1
    }
    for (i in 0..slice.size) {
        if (slice[i] != char) {
            return i
        }
    }
    return -1
}

/// 从指定位置查找任意字符集中的字符
/// 严格翻译自 immutable.zig indexOfAnyPosComptime
public func indexOfAnyPosComptime(slice: String, chars: String, startIndex: Int64): Int64 {
    if (chars.size == 1) {
        return indexOfCharPos(slice, chars[0], startIndex)
    }
    for (i in startIndex..slice.size) {
        for (j in 0..chars.size) {
            if (slice[i] == chars[j]) {
                return i
            }
        }
    }
    return -1
}

// ============================================================================
// 字符串比较函数
// ============================================================================

/// 比较两个字符串是否相等
/// 严格翻译自 immutable.zig eql
public func eql(self: String, other: String): Bool {
    if (self.size != other.size) {
        return false
    }
    return eqlLong(self, other, false)
}

/// 长度优化的字符串比较
/// 严格翻译自 immutable.zig eqlLong
/// 使用 usize 级别的字比较进行优化
public func eqlLong(a: String, b: String, checkLen: Bool): Bool {
    if (checkLen) {
        if (b.size == 0) {
            return a.size == 0
        }
        if (a.size != b.size) {
            return false
        }
    }

    // 简化版本: 逐字节比较 (仓颉不直接支持 unsafe 指针 bitcast)
    for (i in 0..b.size) {
        if (a[i] != b[i]) {
            return false
        }
    }
    return true
}

/// 大小写不敏感的字符串比较(不检查长度)
/// 严格翻译自 immutable.zig eqlCaseInsensitiveASCIIIgnoreLength
public func eqlCaseInsensitiveASCIIIgnoreLength(a: String, b: String): Bool {
    return eqlCaseInsensitiveASCII(a, b, false)
}

/// 大小写不敏感的字符串比较(检查长度)
/// 严格翻译自 immutable.zig eqlCaseInsensitiveASCIIICheckLength
public func eqlCaseInsensitiveASCIIICheckLength(a: String, b: String): Bool {
    return eqlCaseInsensitiveASCII(a, b, true)
}

/// 大小写不敏感的 ASCII 字符串比较
/// 严格翻译自 immutable.zig eqlCaseInsensitiveASCII
public func eqlCaseInsensitiveASCII(a: String, b: String, checkLen: Bool): Bool {
    if (checkLen) {
        if (a.size != b.size) {
            return false
        }
        if (a.size == 0) {
            return true
        }
    }

    let minLen = if (a.size < b.size) { a.size } else { b.size }
    for (i in 0..minLen) {
        let ca = a[i]
        let cb = b[i]
        if (toLowerASCII(ca) != toLowerASCII(cb)) {
            return false
        }
    }
    return true
}

// ============================================================================
// 前缀/后缀检查
// ============================================================================

/// 检查是否包含非空前缀
/// 严格翻译自 immutable.zig hasPrefix
public func hasPrefix(self: String, str: String): Bool {
    return str.size > 0 && startsWith(self, str)
}

/// 检查是否以指定字符串开头
/// 严格翻译自 immutable.zig startsWith
public func startsWith(self: String, str: String): Bool {
    if (str.size > self.size) {
        return false
    }
    return eqlLong(self[0..str.size], str, false)
}

/// 大小写不敏感的前缀检查
/// 严格翻译自 immutable.zig startsWithCaseInsensitiveAscii
public func startsWithCaseInsensitiveAscii(self: String, prefix: String): Bool {
    return self.size >= prefix.size && eqlCaseInsensitiveASCII(self[0..prefix.size], prefix, false)
}

/// 检查是否以指定字符开头
/// 严格翻译自 immutable.zig startsWithChar
public func startsWithChar(self: String, char: Byte): Bool {
    return self.size > 0 && self[0] == char
}

/// 检查是否以指定字符串结尾
/// 严格翻译自 immutable.zig endsWith
public func endsWith(self: String, str: String): Bool {
    if (str.size == 0) {
        return true
    }
    if (str.size > self.size) {
        return false
    }
    return eqlLong(self[self.size - str.size..self.size], str, false)
}

/// 检查是否以指定字符结尾
/// 严格翻译自 immutable.zig endsWithChar
public func endsWithChar(self: String, char: Byte): Bool {
    return self.size > 0 && self[self.size - 1] == char
}

/// 检查是否以指定字符结尾或是空字符串
/// 严格翻译自 immutable.zig endsWithCharOrIsZeroLength
public func endsWithCharOrIsZeroLength(self: String, char: Byte): Bool {
    return self.size == 0 || self[self.size - 1] == char
}

/// 检查是否以指定字符集合中的任一字符结尾
/// 严格翻译自 immutable.zig endsWithAny
public func endsWithAny(self: String, str: String): Bool {
    if (self.size == 0) {
        return false
    }
    let end = self[self.size - 1]
    for (c in str) {
        if (c == end) {
            return true
        }
    }
    return false
}

/// 大小写不敏感的前缀检查
/// 严格翻译自 immutable.zig hasPrefixCaseInsensitive
public func hasPrefixCaseInsensitive(str: String, prefix: String): Bool {
    if (str.size < prefix.size) {
        return false
    }
    return eqlCaseInsensitiveASCIIIgnoreLength(str[0..prefix.size], prefix)
}

// ============================================================================
// 字符串操作
// ============================================================================

/// 复制并转为小写
/// 严格翻译自 immutable.zig copyLowercase
public func copyLowercase(input: String): String {
    var bytes = Array<Byte>()
    for (i in 0..input.size) {
        let c = input[i]
        if (c >= Byte('A') && c <= Byte('Z')) {
            bytes.append(toLowerASCII(c))
        } else {
            bytes.append(c)
        }
    }
    return String.fromUtf8(bytes)
}

/// 复制字符串到缓冲区
/// 严格翻译自 immutable.zig copy
public func copy(buf: Array<Byte>, src: Array<Byte>): Array<Byte> {
    let len = if (buf.size < src.size) { buf.size } else { src.size }
    var result = Array<Byte>()
    for (i in 0..len) {
        result.append(src[i])
    }
    return result
}

/// 将字符串追加到新分配的缓冲区
/// 严格翻译自 immutable.zig append
public func append(self: String, other: String): String {
    return self + other
}

/// 连接两个字符串(分配新内存)
/// 严格翻译自 immutable.zig cat
public func cat(first: String, second: String): String {
    return first + second
}

/// 统计字符出现次数
/// 严格翻译自 immutable.zig countChar
public func countChar(self: String, char: Byte): Int64 {
    var total: Int64 = 0
    for (i in 0..self.size) {
        if (self[i] == char) {
            total += 1
        }
    }
    return total
}

/// 获取子串
/// 严格翻译自 immutable.zig substring
public func substring(self: String, start: ?Int64, stop: ?Int64): String {
    let sta = start ?? 0
    let sto = stop ?? self.size
    let begin = if (sta < self.size) { sta } else { self.size }
    let end = if (sto < self.size) { sto } else { self.size }
    return self[begin..end]
}

/// 用指定字符重复填充缓冲区
/// 严格翻译自 immutable.zig repeatingBuf
public func repeatingBuf(buf: Array<Byte>, char: Byte): Unit {
    for (i in 0..buf.size) {
        buf[i] = char
    }
}

/// 将字符串引号化(转义双引号)
/// 严格翻译自 immutable.zig quotedAlloc
public func quotedAlloc(self: String): String {
    var count: Int64 = 0
    for (i in 0..self.size) {
        if (self[i] == Byte('"')) {
            count += 1
        }
    }

    if (count == 0) {
        return self
    }

    var result = StringBuilder()
    for (i in 0..self.size) {
        if (self[i] == Byte('"')) {
            result.append("\\")
        }
        result.append(String.fromByte(self[i]))
    }
    return result.toString()
}

// ============================================================================
// 分割
// ============================================================================

/// 分割迭代器
/// 严格翻译自 immutable.zig SplitIterator
public class SplitIterator {
    private var buffer: String
    private var index: ?Int64
    private var delimiter: String

    public init(buffer: String, delimiter: String) {
        this.buffer = buffer
        this.index = 0
        this.delimiter = delimiter
    }

    /// 获取第一个字段
    /// 严格翻译自 SplitIterator.first
    public func first(): String {
        return next() ?? ""
    }

    /// 获取下一个字段
    /// 严格翻译自 SplitIterator.next
    public func next(): ?String {
        let start = this.index ?? return None
        let endIndex = indexOf(this.buffer[start..this.buffer.size], this.delimiter)
        if (endIndex >= 0) {
            let delimStart = endIndex + start
            this.index = delimStart + this.delimiter.size
            return this.buffer[start..delimStart]
        } else {
            this.index = None
            return this.buffer[start..this.buffer.size]
        }
    }

    /// 获取剩余部分
    /// 严格翻译自 SplitIterator.rest
    public func rest(): String {
        let end = this.buffer.size
        let start = this.index ?? end
        return this.buffer[start..end]
    }

    /// 重置迭代器
    /// 严格翻译自 SplitIterator.reset
    public func reset(): Unit {
        this.index = 0
    }
}

/// 创建分割迭代器
/// 严格翻译自 immutable.zig split
public func split(self: String, delimiter: String): SplitIterator {
    return SplitIterator(self, delimiter)
}

/// 分割第一个字节
/// 严格翻译自 immutable.zig splitFirst
public func splitFirst(self: String): ?Tuple<Byte, String> {
    if (self.size == 0) {
        return None
    }
    let first = self[0]
    return Some((first, self[1..self.size]))
}

// ============================================================================
// 修剪
// ============================================================================

/// 空白字符集
/// 严格翻译自 immutable.zig whitespace_chars
public const WHITESPACE_CHARS: Array<Byte> = [
    Byte(' '), Byte('\t'), Byte('\n'), Byte('\r'),
    0x0B, // VT
    0x0C, // FF
]

/// 修剪字符串两端指定字符
/// 严格翻译自 immutable.zig trim
public func trim(slice: String, valuesToStrip: String): String {
    var begin: Int64 = 0
    var end: Int64 = slice.size

    while (begin < end && containsChar(valuesToStrip, slice[begin])) {
        begin += 1
    }
    while (end > begin && containsChar(valuesToStrip, slice[end - 1])) {
        end -= 1
    }
    return slice[begin..end]
}

/// 修剪空白字符
/// 严格翻译自 immutable.zig trimSpaces
public func trimSpaces(slice: String): String {
    return trim(slice, String.fromUtf8(WHITESPACE_CHARS))
}

/// 判断是否全为空白
/// 严格翻译自 immutable.zig isAllWhitespace
public func isAllWhitespace(slice: String): Bool {
    var begin: Int64 = 0
    let ws = String.fromUtf8(WHITESPACE_CHARS)
    while (begin < slice.size && containsChar(ws, slice[begin])) {
        begin += 1
    }
    return begin == slice.size
}

/// 计算前导空白长度
/// 严格翻译自 immutable.zig lengthOfLeadingWhitespaceASCII
public func lengthOfLeadingWhitespaceASCII(slice: String): Int64 {
    let ws = String.fromUtf8(WHITESPACE_CHARS)
    for (i in 0..slice.size) {
        if (!containsChar(ws, slice[i])) {
            return i
        }
    }
    return slice.size
}

/// 修剪前导指定字符
/// 严格翻译自 immutable.zig trimLeadingChar
public func trimLeadingChar(slice: String, char: Byte): String {
    let i = indexOfNotChar(slice, char)
    if (i >= 0) {
        return slice[i..slice.size]
    }
    return ""
}

/// 修剪后续前导字符(保留一个)
/// 严格翻译自 immutable.zig trimSubsequentLeadingChars
public func trimSubsequentLeadingChars(slice: String, char: Byte): String {
    if (slice.size == 0) {
        return slice
    }
    var end = slice.size - 1
    var endEnd = slice.size
    while (end > 0 && slice[end] == char) {
        endEnd = end + 1
        end -= 1
    }
    return slice[0..endEnd]
}

/// 修剪前导双字节模式
/// 严格翻译自 immutable.zig trimLeadingPattern2
public func trimLeadingPattern2(slice: String, byte1: Byte, byte2: Byte): String {
    var s = slice
    while (s.size >= 2) {
        if (s[0] == byte1 && s[1] == byte2) {
            s = s[2..s.size]
        } else {
            break
        }
    }
    return s
}

// ============================================================================
// 十六进制编解码
// ============================================================================

/// 无效字符标记
private const INVALID_CHAR: Byte = 0xFF

/// 十六进制查找表
/// 严格翻译自 immutable.zig hex_table
private let hexTable: Array<Byte> = [
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, 10, 11, 12, 13, 14, 15,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, 10, 11, 12, 13, 14, 15,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR,
    INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR, INVALID_CHAR
]

/// 十六进制解码
/// 严格翻译自 immutable.zig decodeHexToBytes
public func decodeHexToBytes(source: String): ?Array<Byte> {
    if (source.size % 2 != 0) {
        return None
    }

    var result = Array<Byte>()
    var i: Int64 = 0
    while (i + 1 < source.size) {
        let a = hexTable[Int64(source[i])]
        let b = hexTable[Int64(source[i + 1])]
        if (a == INVALID_CHAR || b == INVALID_CHAR) {
            return None
        }
        result.append((a << 4) | b)
        i += 2
    }
    return result
}

/// 十六进制解码(截断无效部分)
/// 严格翻译自 immutable.zig decodeHexToBytesTruncate
public func decodeHexToBytesTruncate(source: String): Array<Byte> {
    return decodeHexToBytes(source) ?? Array<Byte>()
}

/// 字节转十六进制字符
private func byte2hex(char: Byte): Byte {
    if (char <= 9) {
        return char + Byte('0')
    }
    return char - 10 + Byte('a')
}

/// 十六进制编码
/// 严格翻译自 immutable.zig encodeBytesToHex
public func encodeBytesToHex(source: Array<Byte>): String {
    if (source.size == 0) {
        return ""
    }

    var result = Array<Byte>()
    for (c in source) {
        result.append(byte2hex((c >> 4) & 0xF))
        result.append(byte2hex(c & 0xF))
    }
    return String.fromUtf8(result)
}

// ============================================================================
// UUID / npm 包名检测
// ============================================================================

/// UUID 字符串长度
/// 严格翻译自 immutable.zig uuid_len
public const UUID_LEN: Int64 = 36

/// 判断是否为 UUID
/// 严格翻译自 immutable.zig isUUID
public func isUUID(str: String): Bool {
    if (str.size != UUID_LEN) {
        return false
    }

    // 8 hex chars
    for (i in 0..Int64(8)) {
        if (!isHexChar(str[i])) {
            return false
        }
    }
    if (str[8] != Byte('-')) {
        return false
    }
    // 4 hex chars
    for (i in Int64(9)..Int64(13)) {
        if (!isHexChar(str[i])) {
            return false
        }
    }
    if (str[13] != Byte('-')) {
        return false
    }
    // 4 hex chars
    for (i in Int64(14)..Int64(18)) {
        if (!isHexChar(str[i])) {
            return false
        }
    }
    if (str[18] != Byte('-')) {
        return false
    }
    // 4 hex chars
    for (i in Int64(19)..Int64(23)) {
        if (!isHexChar(str[i])) {
            return false
        }
    }
    if (str[23] != Byte('-')) {
        return false
    }
    // 12 hex chars
    for (i in Int64(24)..Int64(36)) {
        if (!isHexChar(str[i])) {
            return false
        }
    }
    return true
}

/// 判断字符串是否以 UUID 开头
/// 严格翻译自 immutable.zig startsWithUUID
public func startsWithUUID(str: String): Bool {
    let end = if (str.size < UUID_LEN) { str.size } else { UUID_LEN }
    return isUUID(str[0..end])
}

/// 判断是否为有效的 npm 包名
/// 严格翻译自 immutable.zig isNPMPackageName
public func isNPMPackageName(target: String): Bool {
    if (target.size > 214) {
        return false
    }
    return isNPMPackageNameIgnoreLength(target)
}

/// 判断是否为有效的 npm 包名(不检查长度)
/// 严格翻译自 immutable.zig isNPMPackageNameIgnoreLength
public func isNPMPackageNameIgnoreLength(target: String): Bool {
    if (target.size == 0) {
        return false
    }

    let firstChar = target[0]
    var scoped = false

    if ((firstChar >= Byte('A') && firstChar <= Byte('Z')) ||
        (firstChar >= Byte('a') && firstChar <= Byte('z')) ||
        (firstChar >= Byte('0') && firstChar <= Byte('9')) ||
        firstChar == Byte('$') || firstChar == Byte('-')) {
        scoped = false
    } else if (firstChar == Byte('@')) {
        scoped = true
    } else {
        return false
    }

    var slashIndex: Int64 = 0
    for (i in 1..target.size) {
        let c = target[i]
        if ((c >= Byte('A') && c <= Byte('Z')) ||
            (c >= Byte('a') && c <= Byte('z')) ||
            (c >= Byte('0') && c <= Byte('9')) ||
            c == Byte('-') || c == Byte('_') || c == Byte('.')) {
            // ok
        } else if (c == Byte('/')) {
            if (!scoped) {
                return false
            }
            if (slashIndex > 0) {
                return false
            }
            slashIndex = i
        } else if (c == Byte('!') || c == Byte('~') || c == Byte('*') ||
                   c == Byte('\'') || c == Byte('(') || c == Byte(')')) {
            if (!scoped || slashIndex > 0) {
                return false
            }
        } else {
            return false
        }
    }

    return !scoped || (slashIndex > 0 && slashIndex + 1 < target.size)
}

/// 判断是否以 npm 密钥开头,返回密钥长度
/// 严格翻译自 immutable.zig startsWithNpmSecret
public func startsWithNpmSecret(str: String): Int64 {
    let prefixLen = Int64(4) // "npm".size
    if (str.size < prefixLen + 36) {
        return 0
    }

    if (!hasPrefixCaseInsensitive(str[0..3], "npm")) {
        return 0
    }

    var i: Int64 = 3

    if (str[i] == Byte('_')) {
        i += 1
    } else if (str[i] == Byte('s') || str[i] == Byte('S')) {
        i += 1
        if (i >= str.size || str[i] != Byte('_')) {
            return 0
        }
        i += 1
    } else {
        return 0
    }

    let minLen = i + 36
    let maxLen = i + 48

    while (i < maxLen) {
        if (i == str.size) {
            return if (i >= minLen) { i } else { 0 }
        }

        let c = str[i]
        if ((c >= Byte('0') && c <= Byte('9')) ||
            (c >= Byte('a') && c <= Byte('z')) ||
            (c >= Byte('A') && c <= Byte('Z'))) {
            i += 1
        } else {
            return if (i >= minLen) { i } else { 0 }
        }
    }

    return i
}

// ============================================================================
// 字符串排序
// ============================================================================

/// 字符串比较排序
/// 严格翻译自 immutable.zig order
public func order(a: String, b: String): Order {
    let len = if (a.size < b.size) { a.size } else { b.size }
    let minLen = if (len > 0) { len } else { 0 }

    for (i in 0..minLen) {
        if (a[i] < b[i]) {
            return Order.LT
        }
        if (a[i] > b[i]) {
            return Order.GT
        }
    }

    if (a.size < b.size) {
        return Order.LT
    }
    if (a.size > b.size) {
        return Order.GT
    }
    return Order.EQ
}

/// 升序比较器
/// 严格翻译自 immutable.zig cmpStringsAsc
public func cmpStringsAsc(a: String, b: String): Bool {
    return order(a, b) == Order.LT
}

/// 降序比较器
/// 严格翻译自 immutable.zig cmpStringsDesc
public func cmpStringsDesc(a: String, b: String): Bool {
    return order(a, b) == Order.GT
}

// ============================================================================
// 行操作
// ============================================================================

/// 行范围
/// 严格翻译自 immutable.zig LineRange
public class LineRange {
    public var start: UInt32
    public var end: UInt32

    public init(start: UInt32, end: UInt32) {
        this.start = start
        this.end = end
    }
}

/// 查找文本中的行范围
/// 严格翻译自 immutable.zig indexOfLineRanges
public func indexOfLineRanges(text: String, targetLine: UInt32, lineRangeCount: Int64): Array<LineRange> {
    var ranges = Array<LineRange>()

    if (text.size == 0) {
        return ranges
    }

    var currentLine: UInt32 = 0
    var prevEnd: UInt32 = 0

    // 遍历字符查找换行符
    var i: Int64 = 0
    while (i < text.size) {
        let c = text[i]

        if (c == Byte('\n')) {
            if (currentLine == UInt32(0)) {
                ranges.append(LineRange(start: 0, end: UInt32(i)))
            } else {
                ranges.append(LineRange(start: prevEnd, end: UInt32(i) + 1))
            }
            prevEnd = UInt32(i) + 1

            if (ranges.size > lineRangeCount && currentLine <= targetLine) {
                ranges.remove(0)
            }

            currentLine += 1

            if (currentLine > targetLine) {
                return ranges
            }
        } else if (c == Byte('\r')) {
            if (i + 1 < text.size && text[i + 1] == Byte('\n')) {
                if (currentLine == UInt32(0)) {
                    ranges.append(LineRange(start: 0, end: UInt32(i)))
                } else {
                    ranges.append(LineRange(start: prevEnd, end: UInt32(i)))
                }
                prevEnd = UInt32(i) + 1
                i += 1

                if (ranges.size > lineRangeCount && currentLine <= targetLine) {
                    ranges.remove(0)
                }

                currentLine += 1

                if (currentLine > targetLine) {
                    return ranges
                }
            }
        }

        i += 1
    }

    return ranges
}

// ============================================================================
// ANSI 迭代器
// 严格翻译自 immutable.zig ANSIIterator
// ============================================================================

/// ANSI 转义序列迭代器
/// 严格翻译自 immutable.zig ANSIIterator
public class ANSIIterator {
    private var input: String
    private var cursor: Int64

    public init(input: String) {
        this.input = input
        this.cursor = 0
    }

    /// 获取下一个非 ANSI 文本切片
    /// 严格翻译自 ANSIIterator.next
    public func next(): ?String {
        if (cursor >= input.size) {
            return None
        }

        // 跳过 ANSI 转义序列
        var start = cursor
        while (cursor < input.size) {
            if (input[cursor] == Byte('\u{1b}')) {
                // 找到 ESC 序列,返回之前的文本
                if (cursor > start) {
                    let result = input[start..cursor]
                    return result
                }
                // 跳过 ANSI 序列
                cursor += 1
                if (cursor < input.size && input[cursor] == Byte('[')) {
                    cursor += 1
                    while (cursor < input.size) {
                        let c = input[cursor]
                        cursor += 1
                        if ((c >= Byte('@') && c <= Byte('~'))) {
                            break
                        }
                    }
                }
                start = cursor
            } else {
                cursor += 1
            }
        }

        if (cursor > start) {
            return input[start..cursor]
        }
        return None
    }
}

// ============================================================================
// UTF-8 边界检查
// ============================================================================

/// 判断是否在 UTF-8 字符边界上
/// 严格翻译自 immutable.zig isOnCharBoundary
public func isOnCharBoundary(self: String, idx: Int64): Bool {
    if (idx == 0) {
        return true
    }
    if (idx >= self.size) {
        return idx == self.size
    }
    return isUtf8CharBoundary(self[idx])
}

/// 判断字节是否为 UTF-8 起始字节
/// 严格翻译自 immutable.zig isUtf8CharBoundary
public func isUtf8CharBoundary(c: Byte): Bool {
    // 等价于: c < 128 || c >= 192
    let signed = Int8(c)
    return signed >= Int8(-64) // -0x40
}

// ============================================================================
// 辅助函数
// ============================================================================

/// ASCII 大写转小写
private func toLowerASCII(c: Byte): Byte {
    if (c >= Byte('A') && c <= Byte('Z')) {
        return c + 32
    }
    return c
}

/// ASCII 小写转大写
public func toUpperASCII(c: Byte): Byte {
    if (c >= Byte('a') && c <= Byte('z')) {
        return c - 32
    }
    return c
}

/// 判断是否为十六进制字符
/// 严格翻译自 immutable.zig isASCIIHexDigit
public func isASCIIHexDigit(c: Byte): Bool {
    return (c >= Byte('0') && c <= Byte('9')) ||
           (c >= Byte('A') && c <= Byte('F')) ||
           (c >= Byte('a') && c <= Byte('f'))
}

/// 十六进制字符转数值
/// 严格翻译自 immutable.zig toASCIIHexValue
public func toASCIIHexValue(character: Byte): Byte {
    if (character < Byte('A')) {
        return character - Byte('0')
    }
    return (character - Byte('A') + 10) & 0xF
}

/// 判断字符是否为十六进制字符的辅助函数
private func isHexChar(c: Byte): Bool {
    return (c >= Byte('0') && c <= Byte('9')) ||
           (c >= Byte('a') && c <= Byte('f')) ||
           (c >= Byte('A') && c <= Byte('F'))
}

// ============================================================================
// URL 百分号编码
// ============================================================================

/// 查找需要 URL 编码的字符位置
/// 严格翻译自 immutable.zig indexOfNeedsURLEncode
public func indexOfNeedsURLEncode(slice: String): Int64 {
    if (slice.size == 0) {
        return -1
    }

    for (i in 0..slice.size) {
        let char = slice[i]
        if (char > 127 || char < 0x20 ||
            char == Byte('%') || char == Byte('\\') || char == Byte('"') ||
            char == Byte('#') || char == Byte('?') || char == Byte('[') ||
            char == Byte(']') || char == Byte('^') || char == Byte('|') ||
            char == Byte('~')) {
            return i
        }
    }
    return -1
}

/// URL 百分号编码
/// 严格翻译自 immutable.zig percentEncodeWrite
public func percentEncodeWrite(utf8Input: String): String {
    var result = StringBuilder()
    var remaining = utf8Input

    while (true) {
        let j = indexOfNeedsURLEncode(remaining)
        if (j < 0) {
            break
        }

        result.append(remaining[0..j])

        let codePointLen = wtf8ByteSequenceLengthWithInvalid(remaining[j])
        if (j + codePointLen > remaining.size) {
            // 不完整的 UTF-8 序列
            result.append(remaining[j..remaining.size])
            break
        }

        let toEncode = remaining[j..j + codePointLen]
        remaining = remaining[j + codePointLen..remaining.size]

        // URL 编码
        for (b in toEncode.toArray()) {
            result.append(String.fromByte(Byte('%')))
            result.append(String.fromByte(byte2hex((b >> 4) & 0xF)))
            result.append(String.fromByte(byte2hex(b & 0xF)))
        }
    }

    result.append(remaining)
    return result.toString()
}

// ============================================================================
// 连接
// ============================================================================

/// 连接字符串数组
/// 严格翻译自 immutable.zig join
public func join(slices: Array<String>, delimiter: String): String {
    if (slices.size == 0) {
        return ""
    }
    var result = StringBuilder()
    result.append(slices[0])
    for (i in 1..slices.size) {
        result.append(delimiter)
        result.append(slices[i])
    }
    return result.toString()
}

/// 连接字符串数组(带总长度)
/// 严格翻译自 immutable.zig concatWithLength
public func concatWithLength(args: Array<String>, length: Int64): String {
    var result = StringBuilder()
    for (arg in args) {
        result.append(arg)
    }
    return result.toString()
}

/// 连接字符串数组
/// 严格翻译自 immutable.zig concat
public func concat(args: Array<String>): String {
    var totalLength: Int64 = 0
    for (arg in args) {
        totalLength += arg.size
    }
    return concatWithLength(args, totalLength)
}

// ============================================================================
// 可见宽度相关重导出
// (依赖 bao_unicode 包的实现)
// ============================================================================

/// WTF-8 字节序列长度 (含无效序列)
/// 严格翻译自 immutable.zig wtf8ByteSequenceLengthWithInvalid
public func wtf8ByteSequenceLengthWithInvalid(byte: Byte): Int64 {
    if (byte <= 0x7F) {
        return 1
    } else if (byte >= 0xC2 && byte <= 0xDF) {
        return 2
    } else if (byte >= 0xE0 && byte <= 0xEF) {
        return 3
    } else if (byte >= 0xF0 && byte <= 0xF4) {
        return 4
    }
    return 1 // 无效字节视为单字节
}

/// YAML 字符串是否需要转义
/// 严格翻译自 immutable.zig mustEscapeYAMLString
public func mustEscapeYAMLString(contents: String): Bool {
    if (contents.size == 0) {
        return true
    }

    let first = contents[0]
    if ((first >= Byte('A') && first <= Byte('Z')) || (first >= Byte('a') && first <= Byte('z'))) {
        return hasPrefix(contents, "Yes") || hasPrefix(contents, "No") ||
               hasPrefix(contents, "true") || hasPrefix(contents, "false") ||
               indexOfAny(contents[1..contents.size], ": \t\r\n\u{0B}\u{0C}\\\",[]") >= 0
    }
    return true
}

/// 查找 URL 中的密码部分
/// 严格翻译自 immutable.zig findUrlPassword
public func findUrlPassword(text: String): ?Tuple<Int64, Int64> {
    if (!hasPrefix(text, "http")) {
        return None
    }
    var offset: Int64 = 4
    if (hasPrefix(text[4..text.size], "://")) {
        offset += 3
    } else if (hasPrefix(text[4..text.size], "s://")) {
        offset += 4
    } else {
        return None
    }

    let remain = text[offset..text.size]
    let end = indexOfChar(remain, Byte('\n')) ?? remain.size
    let afterNewline = remain[0..end]
    let at = indexOfChar(afterNewline, Byte('@')) ?? return None
    let beforeAt = afterNewline[0..at]
    let colon = indexOfCharNeg(beforeAt, Byte(':'))
    if (colon < 0 || Int64(colon) == at - 1) {
        return None
    }
    offset += Int64(colon) + 1
    let len: Int64 = at - Int64(colon) - 1
    return (offset, len)
}
