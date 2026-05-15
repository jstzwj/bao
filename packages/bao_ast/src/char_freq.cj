// 严格翻译自: src/ast/char_freq.zig
// CharFreq: 字符频率统计, 用于标识符压缩 (NameMinifier)
package bao_ast

import bao_core.*
import bao_collections.*

// ============================================================================
// CharFreq - 字符频率统计
// 严格翻译自: src/ast/char_freq.zig:1-138
// Bun: pub const CharFreq = struct {
//   freqs: Buffer align(1) = undefined,
//   scan(), scanBig(), scanSmall(), include(), compile()
// }
// ============================================================================

/// 字符频率计数常量 - 对应 Bun char_freq_count = 64
/// a-z (26) + A-Z (26) + 0-9 (10) + _ + $ = 64
public let CHAR_FREQ_COUNT: Int64 = Int64(64)

/// 字符及计数 - 对应 Bun CharAndCount
/// Bun: pub const CharAndCount = struct { char: u8 = 0, count: i32 = 0, index: usize = 0 }
public class CharAndCount implements Comparable<CharAndCount> {
    public var char_: UInt8
    public var count: Int32
    public var index: Int64

    public init(char_: UInt8, count: Int32, index: Int64) {
        this.char_ = char_
        this.count = count
        this.index = index
    }

    public init() {
        this.char_ = UInt8(0)
        this.count = Int32(0)
        this.index = Int64(0)
    }

    /// 比较函数 - 对应 Bun CharAndCount.lessThan()
    /// Bun: pub fn lessThan(_: void, a: CharAndCount, b: CharAndCount) bool
    /// 降序排列计数, 然后升序排列索引, 最后升序排列字符
    public func compareTo(other: CharAndCount): Int64 {
        if (count != other.count) {
            // 降序: 大计数在前
            return Int64(other.count) - Int64(count)
        }
        if (index != other.index) {
            // 升序: 小索引在前
            return Int64(index) - Int64(other.index)
        }
        return Int64(char_) - Int64(other.char_)
    }
}

/// 默认尾部字符 - 对应 Bun NameMinifier.default_tail
/// 用于标识符压缩的字符集: a-z, A-Z, 0-9, _, $
public let DEFAULT_TAIL: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_$"

/// 默认头部字符 - 对应 Bun NameMinifier.default_head
/// 头部不能以数字开头: a-z, A-Z, _, $
public let DEFAULT_HEAD: String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_$"

/// 名称压缩器 - 对应 Bun NameMinifier
/// Bun: 用于将长标识符名替换为短标识符名
public class NameMinifier {
    public var head: ArrayList<UInt8>
    public var tail: ArrayList<UInt8>

    public init() {
        head = ArrayList<UInt8>()
        tail = ArrayList<UInt8>()
    }

    /// 初始化 - 对应 Bun NameMinifier.init()
    public static func init(allocator: Any): NameMinifier {
        return NameMinifier()
    }

    /// 根据索引生成短名称
    public func generate(index: Int64): String {
        var sb = StringBuilder()
        if (index < head.size) {
            sb.append(Char(head[index]))
        } else {
            var i = index
            sb.append(Char(head[Int64(i % head.size)]))
            i = i / head.size
            while (i > Int64(0)) {
                i -= Int64(1)
                if (i < tail.size) {
                    sb.append(Char(tail[Int64(i)]))
                }
                i = i / tail.size
            }
        }
        return sb.toString()
    }
}

/// CharFreq - 字符频率统计
/// 严格翻译自 Bun CharFreq
/// 用于统计标识符中各字符的频率, 以便在压缩时优先使用高频字符
public class CharFreq {
    /// 频率数组 - 长度 CHAR_FREQ_COUNT (64)
    /// 索引: 0-25 = a-z, 26-51 = A-Z, 52-61 = 0-9, 62 = _, 63 = $
    public var freqs: ArrayList<Int32>

    /// 扫描块大小 - 对应 Bun scan_big_chunk_size = 32
    private static let SCAN_BIG_CHUNK_SIZE: Int64 = Int64(32)

    public init() {
        freqs = ArrayList<Int32>()
        var i = Int64(0)
        while (i < CHAR_FREQ_COUNT) {
            freqs.append(Int32(0))
            i += Int64(1)
        }
    }

    /// 扫描文本统计字符频率 - 对应 Bun CharFreq.scan()
    /// Bun: pub fn scan(this: *CharFreq, text: string, delta: i32) void
    public func scan(text: String, delta: Int32): Unit {
        if (delta == Int32(0)) {
            return
        }
        scanSmall(text, delta)
    }

    /// 小文本扫描 - 对应 Bun CharFreq.scanSmall()
    /// Bun: fn scanSmall(out: *align(1) Buffer, text: string, delta: i32) void
    private func scanSmall(text: String, delta: Int32): Unit {
        for (c in text) {
            let code = c.toInt()
            let idx: Int64 = getCharIndex(code)
            if (idx >= Int64(0) && idx < CHAR_FREQ_COUNT) {
                freqs[Int64(idx)] = freqs[Int64(idx)] + delta
            }
        }
    }

    /// 包含另一个 CharFreq - 对应 Bun CharFreq.include()
    /// Bun: pub fn include(this: *CharFreq, other: CharFreq) void
    public func include(other: CharFreq): Unit {
        var i = Int64(0)
        while (i < CHAR_FREQ_COUNT) {
            freqs[i] = freqs[i] + other.freqs[i]
            i += Int64(1)
        }
    }

    /// 编译为 NameMinifier - 对应 Bun CharFreq.compile()
    /// Bun: pub fn compile(this: *const CharFreq, allocator: std.mem.Allocator) NameMinifier
    public func compile(): NameMinifier {
        // 构建字符计数数组
        let array = ArrayList<CharAndCount>()
        var i = Int64(0)
        while (i < CHAR_FREQ_COUNT) {
            let ch = getTailChar(i)
            array.append(CharAndCount(ch, freqs[i], i))
            i += Int64(1)
        }

        // 按频率降序排序
        array.sortWith { a, b =>
            a.compareTo(b)
        }

        // 构建 minifier
        let minifier = NameMinifier()
        for (item in array) {
            // 头部不能包含数字
            let ch = item.char_
            if (ch < UInt8(48) || ch > UInt8(57)) {  // '0' = 48, '9' = 57
                minifier.head.append(ch)
            }
            minifier.tail.append(ch)
        }

        return minifier
    }

    /// 获取字符索引 - 将字符映射到频率数组索引
    /// 对应 Bun scanSmall 中的 switch
    private static func getCharIndex(code: Int): Int64 {
        if (code >= Int('a') && code <= Int('z')) {
            return Int64(code - Int('a'))
        }
        if (code >= Int('A') && code <= Int('Z')) {
            return Int64(code - Int('A') + Int(26))
        }
        if (code >= Int('0') && code <= Int('9')) {
            return Int64(code - Int('0') + Int(52))
        }
        if (code == Int('_')) {
            return Int64(62)
        }
        if (code == Int('$')) {
            return Int64(63)
        }
        return Int64(-1)
    }

    /// 获取尾部字符 - 将索引映射回字符
    private static func getTailChar(index: Int64): UInt8 {
        if (index < Int64(26)) {
            return UInt8(Int('a') + Int(index))
        }
        if (index < Int64(52)) {
            return UInt8(Int('A') + Int(index) - Int(26))
        }
        if (index < Int64(62)) {
            return UInt8(Int('0') + Int(index) - Int(52))
        }
        if (index == Int64(62)) {
            return UInt8('_')
        }
        return UInt8('$')  // index == 63
    }
}
