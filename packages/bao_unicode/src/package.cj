// bao_unicode - Unicode 处理
// 对应 Bun: src/unicode/, src/bun_core/string/immutable/grapheme_tables.zig
// Bun 包含大量预计算的 Unicode 表
package bao_unicode

import bao_core.*

// ============================================================================
// UTF-8 编解码
// 对应 Bun: src/unicode/utf8.zig
// ============================================================================

/// UTF-8 编解码工具
public class Utf8 {
    /// 计算 UTF-8 编码一个 Unicode 码点需要的字节数
    public static func encodeLength(codepoint: UInt32): Int64 {
        if (codepoint < 0x80) {
            return 1
        } else if (codepoint < 0x800) {
            return 2
        } else if (codepoint < 0x10000) {
            return 3
        } else if (codepoint < 0x110000) {
            return 4
        }
        return 0  // 无效码点
    }

    /// 将 Unicode 码点编码为 UTF-8 字节
    public static func encode(codepoint: UInt32): Array<UInt8> {
        if (codepoint < 0x80) {
            return [UInt8(codepoint)]
        } else if (codepoint < 0x800) {
            return [
                UInt8(0xC0 | (codepoint >> 6)),
                UInt8(0x80 | (codepoint & 0x3F))
            ]
        } else if (codepoint < 0x10000) {
            return [
                UInt8(0xE0 | (codepoint >> 12)),
                UInt8(0x80 | ((codepoint >> 6) & 0x3F)),
                UInt8(0x80 | (codepoint & 0x3F))
            ]
        } else if (codepoint < 0x110000) {
            return [
                UInt8(0xF0 | (codepoint >> 18)),
                UInt8(0x80 | ((codepoint >> 12) & 0x3F)),
                UInt8(0x80 | ((codepoint >> 6) & 0x3F)),
                UInt8(0x80 | (codepoint & 0x3F))
            ]
        }
        return []
    }

    /// 解码 UTF-8 字节序列的第一个码点
    public static func decode(bytes: Array<UInt8>, offset: Int64): DecodedRune {
        if (offset >= bytes.size) {
            return DecodedRune(codepoint: 0, length: 0, valid: false)
        }

        let b0 = bytes[offset]

        // ASCII
        if (b0 < 0x80) {
            return DecodedRune(codepoint: UInt32(b0), length: 1, valid: true)
        }

        // 多字节序列
        var len = 0
        var codepoint: UInt32 = 0

        if ((b0 & 0xE0) == 0xC0) {
            len = 2
            codepoint = UInt32(b0 & 0x1F)
        } else if ((b0 & 0xF0) == 0xE0) {
            len = 3
            codepoint = UInt32(b0 & 0x0F)
        } else if ((b0 & 0xF8) == 0xF0) {
            len = 4
            codepoint = UInt32(b0 & 0x07)
        } else {
            return DecodedRune(codepoint: UInt32(b0), length: 1, valid: false)
        }

        // 检查字节长度是否足够
        if (offset + len > bytes.size) {
            return DecodedRune(codepoint: UInt32(b0), length: 1, valid: false)
        }

        // 读取后续字节
        for (i in 1..len) {
            let b = bytes[offset + i]
            if ((b & 0xC0) != 0x80) {
                return DecodedRune(codepoint: UInt32(b0), length: 1, valid: false)
            }
            codepoint = (codepoint << 6) | UInt32(b & 0x3F)
        }

        return DecodedRune(codepoint: codepoint, length: Int64(len), valid: true)
    }

    /// 验证 UTF-8 字节序列
    public static func validate(bytes: Array<UInt8>): Bool {
        var i: Int64 = 0
        while (i < bytes.size) {
            let decoded = decode(bytes, i)
            if (!decoded.valid) {
                return false
            }
            i += decoded.length
        }
        return true
    }

    /// 计算 UTF-8 字符串中的字符数 (码点数)
    public static func countCodepoints(bytes: Array<UInt8>): Int64 {
        var count: Int64 = 0
        var i: Int64 = 0
        while (i < bytes.size) {
            let decoded = decode(bytes, i)
            if (decoded.valid) {
                count += 1
                i += decoded.length
            } else {
                count += 1
                i += 1
            }
        }
        return count
    }
}

/// 解码结果
public class DecodedRune {
    public let codepoint: UInt32
    public let length: Int64
    public let valid: Bool

    public init(codepoint: UInt32, length: Int64, valid: Bool) {
        this.codepoint = codepoint
        this.length = length
        this.valid = valid
    }
}

// ============================================================================
// 字素簇 (Grapheme Cluster) 处理
// 对应 Bun: src/bun_core/string/immutable/grapheme_tables.zig
// Bun 包含 35000+ 行的预计算 Unicode 表
// ============================================================================

/// Unicode 通用类别
public enum GeneralCategory {
    | Lu  // 大写字母
    | Ll  // 小写字母
    | Lt  | Lm  | Lo  // 其他字母
    | Mn  // 非间距标记
    | Mc  // 间距组合标记
    | Me  // 封闭标记
    | Nd  // 十进制数字
    | Nl  | No  // 其他数字
    | Pc  | Pd  | Ps  | Pe  | Pi  | Pf  | Po  // 标点
    | Sm  | Sc  | Sk  | So  // 符号
    | Zs  | Zl  | Zp  // 分隔符
    | Cc  | Cf  | Cs  | Co  | Cn  // 控制和其他
}

/// Grapheme 断裂属性
/// 对应 Unicode UAX #29 Grapheme_Cluster_Break
public enum GraphemeBreak {
    | Other
    | CR
    | LF
    | Control
    | Extend
    | ZWJ
    | RegionalIndicator
    | Prepend
    | SpacingMark
    | L
    | V
    | T
    | LV
    | LVT
}

/// 获取码点的 Grapheme 断裂属性
/// 完整实现需要 Unicode 表，此处提供基础版本
public static func graphemeBreak(codepoint: UInt32): GraphemeBreak {
    // 控制字符
    if (codepoint == 0x000D) { return GraphemeBreak.CR }
    if (codepoint == 0x000A) { return GraphemeBreak.LF }
    if (codepoint < 0x0020 && codepoint != 0x000A && codepoint != 0x000D) {
        return GraphemeBreak.Control
    }
    if (codepoint >= 0x007F && codepoint <= 0x009F) {
        return GraphemeBreak.Control
    }

    // 零宽连接符
    if (codepoint == 0x200D) { return GraphemeBreak.ZWJ }

    // Regional Indicator
    if (codepoint >= 0x1F1E6 && codepoint <= 0x1F1FF) {
        return GraphemeBreak.RegionalIndicator
    }

    // Hangul 音节
    if (codepoint >= 0x1100 && codepoint <= 0x115F) { return GraphemeBreak.L }
    if (codepoint >= 0x1160 && codepoint <= 0x11A7) { return GraphemeBreak.V }
    if (codepoint >= 0x11A8 && codepoint <= 0x11FF) { return GraphemeBreak.T }
    if (codepoint >= 0xAC00 && codepoint <= 0xD7A3) {
        let s = codepoint - 0xAC00
        if (s % 28 == 0) { return GraphemeBreak.LV }
        return GraphemeBreak.LVT
    }

    // Extend 类别 (组合标记等)
    if (codepoint >= 0x0300 && codepoint <= 0x036F) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1AB0 && codepoint <= 0x1AFF) { return GraphemeBreak.Extend }
    if (codepoint >= 0x1DC0 && codepoint <= 0x1DFF) { return GraphemeBreak.Extend }
    if (codepoint >= 0xFE00 && codepoint <= 0xFE0F) { return GraphemeBreak.Extend }
    if (codepoint >= 0xFE20 && codepoint <= 0xFE2F) { return GraphemeBreak.Extend }

    // SpacingMark
    if (codepoint >= 0x0903 && codepoint <= 0x0939) { return GraphemeBreak.SpacingMark }

    return GraphemeBreak.Other
}

/// 字素簇迭代器
public class GraphemeIterator {
    private var bytes: Array<UInt8>
    private var pos: Int64

    public init(bytes: Array<UInt8>) {
        this.bytes = bytes
        this.pos = 0
    }

    /// 是否还有下一个字素簇
    public func hasNext(): Bool {
        return pos < bytes.size
    }

    /// 获取下一个字素簇的字节范围
    public func next(): GraphemeCluster {
        if (pos >= bytes.size) {
            return GraphemeCluster(start: pos, end: pos, bytes: [])
        }

        let start = pos
        var prevBreak = graphemeBreakFromBytes(pos)

        // 第一个码点
        let firstDecoded = Utf8.decode(bytes, pos)
        pos += firstDecoded.length

        // 继续添加属于同一字素簇的码点
        while (pos < bytes.size) {
            let currentBreak = graphemeBreakFromBytes(pos)
            if (shouldBreak(prevBreak, current: currentBreak)) {
                break
            }
            let decoded = Utf8.decode(bytes, pos)
            pos += decoded.length
            prevBreak = currentBreak
        }

        var clusterBytes = Array<UInt8>()
        for (i in start..pos) {
            clusterBytes.append(bytes[i])
        }
        return GraphemeCluster(start: start, end: pos, bytes: clusterBytes)
    }

    /// 重置迭代器
    public func reset(): Unit {
        pos = 0
    }

    /// 获取当前位置
    public func position(): Int64 {
        return pos
    }

    private func graphemeBreakFromBytes(offset: Int64): GraphemeBreak {
        let decoded = Utf8.decode(bytes, offset)
        return graphemeBreak(decoded.codepoint)
    }

    /// 判断是否应该在这里断裂字素簇
    private func shouldBreak(prev: GraphemeBreak, current: GraphemeBreak): Bool {
        // GB3: CR × LF
        if (prev == GraphemeBreak.CR && current == GraphemeBreak.LF) {
            return false
        }
        // GB4: (Control|CR|LF) ÷
        if (prev == GraphemeBreak.Control || prev == GraphemeBreak.CR || prev == GraphemeBreak.LF) {
            return true
        }
        // GB5: ÷ (Control|CR|LF)
        if (current == GraphemeBreak.Control || current == GraphemeBreak.CR || current == GraphemeBreak.LF) {
            return true
        }
        // GB6: L × (L|V|LV|LVT)
        if (prev == GraphemeBreak.L) {
            if (current == GraphemeBreak.L || current == GraphemeBreak.V ||
                current == GraphemeBreak.LV || current == GraphemeBreak.LVT) {
                return false
            }
        }
        // GB7: (LV|V) × (V|T)
        if (prev == GraphemeBreak.LV || prev == GraphemeBreak.V) {
            if (current == GraphemeBreak.V || current == GraphemeBreak.T) {
                return false
            }
        }
        // GB8: (LVT|T) × T
        if (prev == GraphemeBreak.LVT || prev == GraphemeBreak.T) {
            if (current == GraphemeBreak.T) {
                return false
            }
        }
        // GB9: × (Extend|ZWJ)
        if (current == GraphemeBreak.Extend || current == GraphemeBreak.ZWJ) {
            return false
        }
        // GB9a: × SpacingMark
        if (current == GraphemeBreak.SpacingMark) {
            return false
        }
        // GB11: ExtPict Extend* ZWJ × ExtPict (简化版)
        // GB12/13: Regional_Indicator × RI (简化版)
        return true
    }
}

/// 字素簇
public class GraphemeCluster {
    public let start: Int64
    public let end: Int64
    public let bytes: Array<UInt8>

    public init(start: Int64, end: Int64, bytes: Array<UInt8>) {
        this.start = start
        this.end = end
        this.bytes = bytes
    }

    /// 获取簇的字节长度
    public func byteLength(): Int64 {
        return end - start
    }
}
