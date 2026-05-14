// bao_core - SIMD 操作存根和字节级工具
// 严格翻译自: src/bun_core/simd.zig
//   Bun 使用 SIMD 指令加速字符串操作 (memcmp, memset, strlen 等)
//   仓颉通过循环 + 内联优化实现等价语义
//   关键算法: 快速字节比较, 内存复制, 字符串长度计算
package bao_core

// ============================================================================
// SimdUtil - SIMD 风格的字节操作工具
// 严格翻译自: src/bun_core/simd.zig 中的内联函数
//   Zig 使用 @vector + 内联汇编实现真正的 SIMD
//   仓颉使用标量循环 + 字长优化模拟
// ============================================================================

/// SIMD 工具类 - 对应 Bun 的 SIMD 加速操作
/// Bun 使用 128/256 位向量指令一次处理 16/32 字节
/// 仓颉使用 UInt64 字长操作一次处理 8 字节作为降级方案
public class SimdUtil {
    // ---- 32 字节批量操作 (对应 AVX2 256-bit 操作) ----

    /// 比较 32 字节块 - 对应 Bun simd memcmp32
    /// 逐字节比较，返回第一个不同位置的偏移，相同返回 -1
    /// Bun: 使用 _mm256_cmpeq_epi8 + _mm256_movemask_epi8 一条指令
    public static func memcmp32(a: Array<UInt8>, aOff: Int64, b: Array<UInt8>, bOff: Int64): Int64 {
        let len = if (a.size - aOff < 32) { a.size - aOff } else { 32 }
        let len2 = if (b.size - bOff < 32) { b.size - bOff } else { 32 }
        let cmpLen = if (len < len2) { len } else { len2 }
        for (i in 0..cmpLen) {
            if (a[aOff + i] != b[bOff + i]) {
                return i
            }
        }
        return -1
    }

    /// 填充 32 字节块 - 对应 Bun simd memset32
    /// Bun: 使用 _mm256_set1_epi8 + _mm256_store_si256
    public static func memset32(dst: Array<UInt8>, offset: Int64, value: UInt8): Unit {
        let end = if (offset + 32 > dst.size) { dst.size } else { offset + 32 }
        for (i in offset..end) {
            dst[i] = value
        }
    }

    /// 复制 32 字节块 - 对应 Bun simd copy32
    /// Bun: 使用 _mm256_load_si256 + _mm256_store_si256
    public static func copy32(src: Array<UInt8>, srcOff: Int64, dst: Array<UInt8>, dstOff: Int64): Unit {
        let len = if (src.size - srcOff < 32) { src.size - srcOff } else { 32 }
        let len2 = if (dst.size - dstOff < 32) { dst.size - dstOff } else { 32 }
        let copyLen = if (len < len2) { len } else { len2 }
        for (i in 0..copyLen) {
            dst[dstOff + i] = src[srcOff + i]
        }
    }

    // ---- 16 字节批量操作 (对应 SSE2 128-bit 操作) ----

    /// 比较 16 字节块 - 对应 Bun simd memcmp16
    public static func memcmp16(a: Array<UInt8>, aOff: Int64, b: Array<UInt8>, bOff: Int64): Int64 {
        let len = if (a.size - aOff < 16) { a.size - aOff } else { 16 }
        let len2 = if (b.size - bOff < 16) { b.size - bOff } else { 16 }
        let cmpLen = if (len < len2) { len } else { len2 }
        for (i in 0..cmpLen) {
            if (a[aOff + i] != b[bOff + i]) {
                return i
            }
        }
        return -1
    }

    /// 填充 16 字节块
    public static func memset16(dst: Array<UInt8>, offset: Int64, value: UInt8): Unit {
        let end = if (offset + 16 > dst.size) { dst.size } else { offset + 16 }
        for (i in offset..end) {
            dst[i] = value
        }
    }

    /// 复制 16 字节块
    public static func copy16(src: Array<UInt8>, srcOff: Int64, dst: Array<UInt8>, dstOff: Int64): Unit {
        let len = if (src.size - srcOff < 16) { src.size - srcOff } else { 16 }
        let len2 = if (dst.size - dstOff < 16) { dst.size - dstOff } else { 16 }
        let copyLen = if (len < len2) { len } else { len2 }
        for (i in 0..copyLen) {
            dst[dstOff + i] = src[srcOff + i]
        }
    }

    // ---- 字长优化操作 (UInt64 一次处理 8 字节) ----

    /// 使用字长比较优化的大块比较
    /// 对应 Bun 中将字节比较降级为 UInt64 比较的优化
    /// 当数据 8 字节对齐时，一次比较 8 个字节
    public static func memcmpFast(a: Array<UInt8>, aOff: Int64, b: Array<UInt8>, bOff: Int64, len: Int64): Bool {
        if (len <= 0) { return true }
        var i: Int64 = 0
        // 字长比较 (每次 8 字节)
        while (i + 8 <= len) {
            if (aOff + i + 8 > a.size || bOff + i + 8 > b.size) {
                break
            }
            var va: UInt64 = 0
            var vb: UInt64 = 0
            for (j in 0..8) {
                va = va | (UInt64(a[aOff + i + j]) << UInt64(j * 8))
                vb = vb | (UInt64(b[bOff + i + j]) << UInt64(j * 8))
            }
            if (va != vb) {
                return false
            }
            i += 8
        }
        // 尾部逐字节比较
        while (i < len) {
            if (aOff + i >= a.size || bOff + i >= b.size) {
                return false
            }
            if (a[aOff + i] != b[bOff + i]) {
                return false
            }
            i += 1
        }
        return true
    }

    /// 大块复制 - 对应 Bun 中优化的 memcpy 路径
    public static func copyFast(src: Array<UInt8>, srcOff: Int64, dst: Array<UInt8>, dstOff: Int64, len: Int64): Unit {
        for (i in 0..len) {
            if (srcOff + i < src.size && dstOff + i < dst.size) {
                dst[dstOff + i] = src[srcOff + i]
            }
        }
    }

    /// 大块填充 - 对应 Bun 中优化的 memset 路径
    public static func memsetFast(dst: Array<UInt8>, offset: Int64, len: Int64, value: UInt8): Unit {
        for (i in 0..len) {
            if (offset + i < dst.size) {
                dst[offset + i] = value
            }
        }
    }

    // ---- 字符串操作 (SIMD 加速的字符串函数) ----

    /// SIMD 风格的 strlen - 对应 Bun strings.simd_strlen
    /// 在字节数组中查找 null 终止符的位置
    /// Bun: 使用 SIMD 一次检测 16/32 字节中的 0x00
    /// 仓颉: 使用 UInt64 字长优化扫描
    public static func strlen(bytes: Array<UInt8>, offset: Int64): Int64 {
        var i = offset
        // 字长扫描
        while (i + 8 <= bytes.size) {
            var v: UInt64 = 0
            for (j in 0..8) {
                v = v | (UInt64(bytes[i + j]) << UInt64(j * 8))
            }
            if (v == UInt64(0)) {
                return i - offset
            }
            // 检测 8 字节中是否包含 0
            if (hasZeroByte(v)) {
                // 逐字节定位
                for (j in 0..8) {
                    if (bytes[i + j] == 0) {
                        return i + j - offset
                    }
                }
            }
            i += 8
        }
        // 尾部逐字节
        while (i < bytes.size) {
            if (bytes[i] == 0) {
                return i - offset
            }
            i += 1
        }
        return bytes.size - offset
    }

    /// 查找第一个匹配字节 - 对应 Bun 中 SIMD 字符搜索
    /// 在字节数组中查找 target 字节的位置
    public static func findByte(bytes: Array<UInt8>, offset: Int64, len: Int64, target: UInt8): Int64 {
        var i = offset
        let end = offset + len
        // 字长扫描
        while (i + 8 <= end && i + 8 <= bytes.size) {
            var v: UInt64 = 0
            for (j in 0..8) {
                v = v | (UInt64(bytes[i + j]) << UInt64(j * 8))
            }
            let pattern = UInt64(target) * UInt64(0x0101010101010101)
            let matched = v ^ pattern
            if (hasZeroByte(matched)) {
                for (j in 0..8) {
                    if (i + j < end && bytes[i + j] == target) {
                        return i + j - offset
                    }
                }
            }
            i += 8
        }
        // 尾部
        while (i < end && i < bytes.size) {
            if (bytes[i] == target) {
                return i - offset
            }
            i += 1
        }
        return -1
    }

    /// 查找第一个不匹配的位置 - 对应 Bun strings.indexOfNonAscii
    /// 查找第一个 >= 0x80 的字节位置
    public static func findNonAscii(bytes: Array<UInt8>, offset: Int64, len: Int64): Int64 {
        var i = offset
        let end = offset + len
        while (i + 8 <= end && i + 8 <= bytes.size) {
            var v: UInt64 = 0
            for (j in 0..8) {
                v = v | (UInt64(bytes[i + j]) << UInt64(j * 8))
            }
            // 如果任何字节 >= 0x80, 则高位会被设置
            if ((v & UInt64(0x8080808080808080)) != UInt64(0)) {
                for (j in 0..8) {
                    if (i + j < end && bytes[i + j] >= 0x80) {
                        return i + j - offset
                    }
                }
            }
            i += 8
        }
        while (i < end && i < bytes.size) {
            if (bytes[i] >= 0x80) {
                return i - offset
            }
            i += 1
        }
        return -1
    }

    /// 全 ASCII 检测 - 对应 Bun strings.isAllASCII
    /// 检查字节数组是否全部为 ASCII (< 0x80)
    public static func isAllAscii(bytes: Array<UInt8>): Bool {
        return findNonAscii(bytes, 0, bytes.size) < 0
    }

    /// 字节比较 (不分大小写) - 对应 Bun strings.eqlCaseInsensitive
    /// ASCII 大小写不敏感比较
    public static func eqlCaseInsensitiveASCII(a: Array<UInt8>, b: Array<UInt8>): Bool {
        if (a.size != b.size) {
            return false
        }
        for (i in 0..a.size) {
            let ca = toLower(a[i])
            let cb = toLower(b[i])
            if (ca != cb) {
                return false
            }
        }
        return true
    }

    // ---- 内部工具 ----

    /// 检测 UInt64 中是否包含零字节
    /// 对应 Bun hasZeroByte(v) 算法
    /// 原理: (v - 0x01010101) & ~v & 0x8080808080808080
    /// 如果 v 的某个字节为 0，则结果非零
    private static func hasZeroByte(v: UInt64): Bool {
        let sub = v - UInt64(0x0101010101010101)
        let mask = (sub & (~v)) & UInt64(0x8080808080808080)
        return mask != UInt64(0)
    }

    /// ASCII 字符转小写
    private static func toLower(b: UInt8): UInt8 {
        if (b >= 0x41 && b <= 0x5A) {
            return b + 0x20
        }
        return b
    }
}

// ============================================================================
// ByteWindow - 滑动字节窗口
// 对应 Bun 中 SIMD 模式匹配使用的滑动窗口
// 用于解析器中的字符类检测
// ============================================================================

/// 滑动字节窗口 - 对应 Bun 的 SIMD 字符类匹配模式
/// 在数据流上维护一个固定大小的滑动窗口进行模式匹配
public class ByteWindow {
    /// 窗口大小 (通常 32 或 64 字节, 对应 SIMD 寄存器宽度)
    private let windowSize: Int64
    /// 窗口数据
    private var window: Array<UInt8>
    /// 当前位置
    private var pos: Int64

    public init(windowSize: Int64) {
        this.windowSize = if (windowSize < 8) { 8 } else { windowSize }
        this.window = Array<UInt8>(this.windowSize, item: 0)
        this.pos = 0
    }

    /// 推入一个字节到窗口
    public func push(byte: UInt8): Unit {
        window[pos % windowSize] = byte
        pos += 1
    }

    /// 推入多个字节
    public func pushBytes(bytes: Array<UInt8>): Unit {
        for (b in bytes) {
            push(b)
        }
    }

    /// 获取窗口中的字节 (从最新往前)
    public func get(offset: Int64): UInt8 {
        if (offset < 0 || offset >= windowSize) {
            return 0
        }
        let idx = ((pos - 1 - offset) % windowSize + windowSize) % windowSize
        return window[idx]
    }

    /// 在窗口中查找字节 - 对应 SIMD 字符搜索
    public func contains(target: UInt8): Bool {
        let start = if (pos < windowSize) { 0 } else { pos - windowSize }
        for (i in start..pos) {
            if (window[i % windowSize] == target) {
                return true
            }
        }
        return false
    }

    /// 在窗口中匹配模式 (最多 8 字节)
    public func matchPattern(pattern: Array<UInt8>): Bool {
        if (pattern.size == 0 || pattern.size > windowSize) {
            return false
        }
        let start = pos - pattern.size
        if (start < 0) {
            return false
        }
        for (i in 0..pattern.size) {
            if (window[(start + i) % windowSize] != pattern[i]) {
                return false
            }
        }
        return true
    }

    /// 重置窗口
    public func reset(): Unit {
        for (i in 0..windowSize) {
            window[i] = 0
        }
        pos = 0
    }

    /// 当前位置
    public func position(): Int64 {
        return pos
    }
}

// ============================================================================
// AsciiClass - ASCII 字符类快速检测
// 对应 Bun 中 SIMD 加速的字符类判断
// 使用位图(bitmap)实现 O(1) 字符类测试
// ============================================================================

/// ASCII 字符类位图 - 对应 Bun 解析器中的字符类检测
/// 使用 256 位 (32 字节) 位图, 每一位对应一个 ASCII 字符
public class AsciiClass {
    /// 位图数据 (32 字节 = 256 位)
    private var bitmap: Array<UInt64>

    public init() {
        bitmap = Array<UInt64>(4, item: UInt64(0))
    }

    /// 从字符列表构建字符类
    public static func fromChars(chars: Array<UInt8>): AsciiClass {
        let cls = AsciiClass()
        for (c in chars) {
            cls.set(c)
        }
        return cls
    }

    /// 从范围构建字符类
    public static func fromRange(lo: UInt8, hi: UInt8): AsciiClass {
        let cls = AsciiClass()
        for (c in lo..hi + 1) {
            cls.set(c)
        }
        return cls
    }

    /// 设置一个字符
    public func set(c: UInt8): Unit {
        let idx = Int64(c) / 64
        let bit = Int64(c) % 64
        bitmap[idx] = bitmap[idx] | (UInt64(1) << UInt64(bit))
    }

    /// 检测字符是否在类中 - O(1)
    /// 对应 Bun 中 SIMD 的单指令字符类检测
    public func test(c: UInt8): Bool {
        let idx = Int64(c) / 64
        let bit = Int64(c) % 64
        return (bitmap[idx] & (UInt64(1) << UInt64(bit))) != UInt64(0)
    }

    /// 合并两个字符类 (并集)
    public func union(other: AsciiClass): AsciiClass {
        let result = AsciiClass()
        for (i in 0..4) {
            result.bitmap[i] = this.bitmap[i] | other.bitmap[i]
        }
        return result
    }

    /// 交集
    public func intersection(other: AsciiClass): AsciiClass {
        let result = AsciiClass()
        for (i in 0..4) {
            result.bitmap[i] = this.bitmap[i] & other.bitmap[i]
        }
        return result
    }

    /// 补集
    public func complement(): AsciiClass {
        let result = AsciiClass()
        for (i in 0..4) {
            result.bitmap[i] = ~this.bitmap[i]
        }
        return result
    }

    // ---- 预定义字符类 ----

    /// 空白字符: space, tab, newline, carriage return, form feed, vertical tab
    public static let WHITESPACE: AsciiClass = AsciiClass.fromChars([
        UInt8(0x09), UInt8(0x0A), UInt8(0x0B), UInt8(0x0C), UInt8(0x0D), UInt8(0x20)
    ])

    /// 数字: 0-9
    public static let DIGIT: AsciiClass = AsciiClass.fromRange(UInt8(0x30), UInt8(0x39))

    /// 十六进制数字: 0-9, a-f, A-F
    public static let HEX_DIGIT: AsciiClass = buildHexDigit()

    /// 标识符起始: a-z, A-Z, _, $
    public static let IDENT_START: AsciiClass = buildIdentStart()

    /// 标识符续接: a-z, A-Z, 0-9, _, $
    public static let IDENT_CONTINUE: AsciiClass = buildIdentContinue()

    private static func buildHexDigit(): AsciiClass {
        let cls = AsciiClass.fromRange(UInt8(0x30), UInt8(0x39))
        cls.set(UInt8(0x61))  // a
        cls.set(UInt8(0x62))
        cls.set(UInt8(0x63))
        cls.set(UInt8(0x64))
        cls.set(UInt8(0x65))
        cls.set(UInt8(0x66))
        cls.set(UInt8(0x41))  // A
        cls.set(UInt8(0x42))
        cls.set(UInt8(0x43))
        cls.set(UInt8(0x44))
        cls.set(UInt8(0x45))
        cls.set(UInt8(0x46))
        return cls
    }

    private static func buildIdentStart(): AsciiClass {
        let cls = AsciiClass()
        // a-z
        for (c in UInt8(0x61)..UInt8(0x7B)) { cls.set(c) }
        // A-Z
        for (c in UInt8(0x41)..UInt8(0x5B)) { cls.set(c) }
        // _ $
        cls.set(UInt8(0x5F))
        cls.set(UInt8(0x24))
        return cls
    }

    private static func buildIdentContinue(): AsciiClass {
        let cls = buildIdentStart()
        // 0-9
        for (c in UInt8(0x30)..UInt8(0x3A)) { cls.set(c) }
        return cls
    }
}
