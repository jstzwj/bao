// bao_unicode - UTF-8 编解码
// 严格翻译自: src/unicode/uucode_lib/src/utf8.zig
//   Bun 使用 Bjoern Hoehrmann 的 DFA 算法进行 UTF-8 解码
//   仓颉实现提供等价的 UTF-8 编解码功能
package bao_unicode

// ============================================================================
// UTF-8 编解码
// 严格翻译自: src/unicode/uucode_lib/src/utf8.zig
//   DFA 表来自 https://bjoern.hoehrmann.de/utf-8/decoder/dfa/
// ============================================================================

/// UTF-8 接受状态
private let UTF8_ACCEPT: UInt8 = 0

/// UTF-8 拒绝状态
private let UTF8_REJECT: UInt8 = 12

/// 字节到字符类映射表
/// 严格翻译自 utf8.zig utf8d
private let utf8d: Array<UInt8> = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9, 9,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7,
    8, 8, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    10, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 4, 3, 3,
    11, 6, 6, 6, 5, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8
]

/// 状态转换表
/// 严格翻译自 utf8.zig state_utf8d
private let state_utf8d: Array<UInt8> = [
    0, 12, 24, 36, 60, 96, 84, 12, 12, 12, 48, 72,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 0, 12, 12, 12, 12, 12, 0, 12, 0, 12, 12,
    12, 24, 12, 12, 12, 12, 12, 24, 12, 24, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 24, 12, 12, 12, 12,
    12, 24, 12, 12, 12, 12, 12, 12, 12, 24, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 36, 12, 36, 12, 12,
    12, 36, 12, 12, 12, 12, 12, 36, 12, 36, 12, 12,
    12, 36, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12
]

/// UTF-8 编码工具
/// 严格翻译自 src/unicode/uucode_lib/src/utf8.zig
public class Iterator {
    private var bytes: Array<UInt8>
    public var i: Int64

    public init(bytes: Array<UInt8>) {
        this.bytes = bytes
        this.i = 0
    }

    /// 获取下一个码点，返回 None 表示结束
    public func next(): ?UInt32 {
        if (i >= bytes.size) {
            return None
        }

        var state: Int64 = Int64(UTF8_ACCEPT)
        var cp: UInt32 = 0

        while (true) {
            let byte = bytes[i]
            let charClass = Int64(utf8d[Int64(byte)])

            if (state != Int64(UTF8_ACCEPT)) {
                cp = (UInt32(byte) & 0x3F) | (cp << 6)
            } else {
                cp = (UInt32(0xFF) >> UInt32(charClass)) & UInt32(byte)
            }

            state = Int64(state_utf8d[state + charClass])
            i += 1

            if (state == Int64(UTF8_ACCEPT) || state == Int64(UTF8_REJECT) || i >= bytes.size) {
                break
            }
        }

        if (state == Int64(UTF8_ACCEPT)) {
            return Some(cp)
        }
        return Some(0xFFFD)
    }

    /// 预览下一个码点但不移动迭代器
    public func peek(): ?UInt32 {
        var it = Iterator(bytes)
        it.i = i
        return it.next()
    }
}

public class Utf8 {

    /// 计算编码码点所需的 UTF-8 字节数
    public static func encodeLength(codepoint: UInt32): Int64 {
        if (codepoint < 0x80) {
            return 1
        } else if (codepoint < 0x800) {
            return 2
        } else if (codepoint < 0x10000) {
            return 3
        } else if (codepoint <= 0x10FFFF) {
            return 4
        }
        return 0
    }

    /// 将 Unicode 码点编码为 UTF-8 字节
    public static func encode(codepoint: UInt32): Array<UInt8> {
        if (codepoint < 0x80) {
            return [UInt8(codepoint)]
        } else if (codepoint < 0x800) {
            return [
                UInt8(0xC0 | ((codepoint >> 6) & 0x1F)),
                UInt8(0x80 | (codepoint & 0x3F))
            ]
        } else if (codepoint < 0x10000) {
            return [
                UInt8(0xE0 | ((codepoint >> 12) & 0x0F)),
                UInt8(0x80 | ((codepoint >> 6) & 0x3F)),
                UInt8(0x80 | (codepoint & 0x3F))
            ]
        } else if (codepoint <= 0x10FFFF) {
            return [
                UInt8(0xF0 | ((codepoint >> 18) & 0x07)),
                UInt8(0x80 | ((codepoint >> 12) & 0x3F)),
                UInt8(0x80 | ((codepoint >> 6) & 0x3F)),
                UInt8(0x80 | (codepoint & 0x3F))
            ]
        }
        return []
    }

    /// 将 Unicode 码点编码写入缓冲区，返回写入字节数
    public static func encodeInto(codepoint: UInt32, buf: Array<UInt8>, offset: Int64): Int64 {
        if (codepoint < 0x80) {
            buf[offset] = UInt8(codepoint)
            return 1
        } else if (codepoint < 0x800) {
            buf[offset] = UInt8(0xC0 | ((codepoint >> 6) & 0x1F))
            buf[offset + 1] = UInt8(0x80 | (codepoint & 0x3F))
            return 2
        } else if (codepoint < 0x10000) {
            buf[offset] = UInt8(0xE0 | ((codepoint >> 12) & 0x0F))
            buf[offset + 1] = UInt8(0x80 | ((codepoint >> 6) & 0x3F))
            buf[offset + 2] = UInt8(0x80 | (codepoint & 0x3F))
            return 3
        } else if (codepoint <= 0x10FFFF) {
            buf[offset] = UInt8(0xF0 | ((codepoint >> 18) & 0x07))
            buf[offset + 1] = UInt8(0x80 | ((codepoint >> 12) & 0x3F))
            buf[offset + 2] = UInt8(0x80 | ((codepoint >> 6) & 0x3F))
            buf[offset + 3] = UInt8(0x80 | (codepoint & 0x3F))
            return 4
        }
        return 0
    }

    /// 解码 UTF-8 字节序列的第一个码点
    /// 严格对应 Bun utf8.zig Iterator.next()
    public static func decode(bytes: Array<UInt8>, offset: Int64): DecodedRune {
        if (offset >= bytes.size) {
            return DecodedRune(codepoint: 0, length: 0, valid: false)
        }

        var state: Int64 = Int64(UTF8_ACCEPT)
        var cp: UInt32 = 0

        var i = offset
        while (i < bytes.size) {
            let byte = bytes[i]
            let charClass = Int64(utf8d[Int64(byte)])

            if (state != Int64(UTF8_ACCEPT)) {
                cp = ((UInt32(byte) & 0x3F)) | (cp << 6)
            } else {
                cp = (UInt32(0xFF) >> UInt32(charClass)) & UInt32(byte)
            }

            state = Int64(state_utf8d[state + charClass])
            i += 1

            if (state == Int64(UTF8_ACCEPT) || state == Int64(UTF8_REJECT)) {
                break
            }
        }

        if (state == Int64(UTF8_ACCEPT)) {
            return DecodedRune(codepoint: cp, length: i - offset, valid: true)
        }
        // 替换字符 U+FFFD
        return DecodedRune(codepoint: 0xFFFD, length: i - offset, valid: false)
    }

    /// 验证 UTF-8 字节序列
    public static func validate(bytes: Array<UInt8>): Bool {
        var state: Int64 = Int64(UTF8_ACCEPT)
        var cp: UInt32 = 0

        for (i in 0..bytes.size) {
            let byte = bytes[i]
            let charClass = Int64(utf8d[Int64(byte)])

            if (state != Int64(UTF8_ACCEPT)) {
                cp = (UInt32(byte) & 0x3F) | (cp << 6)
            } else {
                cp = (UInt32(0xFF) >> UInt32(charClass)) & UInt32(byte)
            }

            state = Int64(state_utf8d[state + charClass])

            if (state == Int64(UTF8_REJECT)) {
                return false
            }
        }
        return state == Int64(UTF8_ACCEPT)
    }

    /// 计算 UTF-8 字节序列中的码点数量
    /// 严格对应 Bun utf8.zig 的逐码点迭代计数
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

    /// 将 UTF-8 字节数组解码为码点数组
    public static func decodeAll(bytes: Array<UInt8>): Array<UInt32> {
        var result = Array<UInt32>()
        var i: Int64 = 0
        while (i < bytes.size) {
            let decoded = decode(bytes, i)
            if (decoded.valid) {
                result.append(decoded.codepoint)
                i += decoded.length
            } else {
                result.append(0xFFFD)
                i += 1
            }
        }
        return result
    }

    /// 将码点数组编码为 UTF-8 字节数组
    public static func encodeAll(codepoints: Array<UInt32>): Array<UInt8> {
        var result = Array<UInt8>()
        for (cp in codepoints) {
            let bytes = encode(cp)
            for (b in bytes) {
                result.append(b)
            }
        }
        return result
    }

    /// UTF-8 迭代器
    /// 严格翻译自 src/unicode/uucode_lib/src/utf8.zig Iterator
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
