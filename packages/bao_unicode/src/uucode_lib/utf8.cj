// bao_unicode - uucode UTF-8 解码器
// 严格翻译自: src/unicode/uucode_lib/src/utf8.zig
//   使用 Bjoern Hoehrmann 的 DFA UTF-8 解码器
//   UTF-8 迭代器: 逐码点遍历字节序列
//   仓颉实现提供等价的 UTF-8 解码
package bao_unicode.uucode_lib

// ============================================================================
// UTF-8 解码器
// 严格翻译自: src/unicode/uucode_lib/src/utf8.zig
//   使用 Hoehrmann DFA (确定性有限自动机) 解码 UTF-8
//   utf8d: 字符类表 (128 字节)
//   state_utf8d: 状态转移表 (72 字节)
// ============================================================================

/// UTF-8 接受状态
/// 翻译自: const UTF8_ACCEPT = 0
private let UTF8_ACCEPT: UInt8 = 0

/// UTF-8 拒绝状态
/// 翻译自: const UTF8_REJECT = 12
private let UTF8_REJECT: UInt8 = 12

/// 字符分类表
/// 严格翻译自: const utf8d = [_]u8{...}
///   将每个字节映射到字符类 (0-11)
private let UTF8D: Array<UInt8> = [
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
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

/// 状态转移表
/// 严格翻译自: const state_utf8d = [_]u8{...}
///   根据当前状态和字符类确定下一个状态
private let STATE_UTF8D: Array<UInt8> = [
    0, 12, 24, 36, 60, 96, 84, 12, 12, 12, 48, 72, 12, 12, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 12, 12, 0, 12, 12, 12, 12, 12, 0,
    12, 0, 12, 12, 12, 24, 12, 12, 12, 12, 12, 24, 12, 24, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 24, 12, 12, 12, 12, 12, 24, 12, 12,
    12, 12, 12, 12, 12, 12, 12, 24, 12, 12, 12, 12, 12, 12, 12, 12,
    12, 36, 12, 36, 12, 12, 12, 36, 12, 12, 12, 12, 12, 36, 12, 36,
    12, 12, 12, 36, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12
]

/// 解码单个字节
/// 翻译自: fn decodeByte(state: *usize, cp: *u21, byte: u8) void
private func decodeByte(state: Int64, cp: Int64, byte: UInt8): DecodeResult {
    let byteIdx = Int64(byte)
    let class_ = if (byteIdx < UTF8D.size) { Int64(UTF8D[byteIdx]) } else { Int64(0) }
    let mask: UInt32 = 0xFF

    let newCp = if (state != Int64(UTF8_ACCEPT)) {
        ((UInt32(byte) & 0x3F) | (UInt32(cp) << 6))
    } else {
        ((mask >> UInt32(class_)) & UInt32(byte))
    }

    let stateIdx = state + Int64(class_)
    let newState = if (stateIdx < STATE_UTF8D.size) { Int64(STATE_UTF8D[stateIdx]) } else { 12 }

    return DecodeResult(newCp, newState)
}

/// 检查是否完成解码
/// 翻译自: fn isDoneDecoding(state: usize) bool
private func isDoneDecoding(state: Int64): Bool {
    return state == Int64(UTF8_ACCEPT) || state == Int64(UTF8_REJECT)
}

// ============================================================================
// UTF-8 迭代器
// 严格翻译自: pub const Iterator = struct
//   逐码点遍历字节序列
//   i: 当前字节位置
//   bytes: 底层字节数组
//   next(): 返回下一个码点
//   peek(): 查看下一个码点但不前进
// ============================================================================

/// 解码结果
private class DecodeResult {
    public var cp: UInt32
    public var state: Int64

    public init(cp: UInt32, state: Int64) {
        this.cp = cp
        this.state = state
    }
}

/// UTF-8 迭代器
/// 严格翻译自 grapheme.zig 引用的 utf8.Iterator
public class Utf8Iterator {
    /// 当前位置 (文档化 API)
    /// 翻译自: i: usize = 0
    public var i: Int64 = 0

    /// 底层字节
    /// 翻译自: bytes: []const u8
    public var bytes: Array<UInt8> = []

    public init(bytes: Array<UInt8>) {
        this.bytes = bytes
    }

    /// 获取下一个码点
    /// 翻译自: pub fn next(self: *Self) ?u21
    ///   使用 DFA 解码器逐字节处理
    ///   有效 UTF-8 返回码点, 无效返回 U+FFFD
    public func next(): ?UInt32 {
        if (i >= bytes.size) {
            return None
        }

        var cp: UInt32 = 0
        var state: Int64 = Int64(UTF8_ACCEPT)

        while (true) {
            let result = decodeByte(state, Int64(cp), bytes[i])
            cp = result.cp
            state = result.state
            i += 1
            if (isDoneDecoding(state) || i >= bytes.size) {
                break
            }
        }

        if (state == Int64(UTF8_ACCEPT)) {
            return cp
        }
        return 0xFFFD // 替换字符
    }

    /// 查看下一个码点但不前进
    /// 翻译自: pub fn peek(self: Self) ?u21
    public func peek(): ?UInt32 {
        var copy = Utf8Iterator(bytes)
        copy.i = i
        return copy.next()
    }
}
