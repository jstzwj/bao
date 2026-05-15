// bao_hash - Adler-32 校验和
// 严格翻译自: src/hash/adler32.rs
//   Adler-32 是 RFC 1950 规定的校验和算法
//   Bun 在 HashObject 中通过 hashWrap(std.hash.Adler32) 暴露
package bao_hash

// ============================================================================
// Adler-32 校验和
// 严格翻译自: src/hash/adler32.rs (源自 vendor/zig/lib/std/hash/Adler32.zig)
//   遵循 https://tools.ietf.org/html/rfc1950#section-9
//   HashObject.zig 通过 hashWrap(std.hash.Adler32) 暴露
//   JS 端的 seed 参数被忽略, 只调用单参数 hash(input)
// ============================================================================

/// Adler-32 校验和算法
/// 对应 Bun: std.hash.Adler32
/// 流式 API: init -> update* -> finalize
public class Adler32 {
    // Adler-32 常量
    private static let BASE: UInt32 = UInt32(65521)
    // NMAX: 最大迭代次数, 使得 s1 不溢出 UInt32
    // BASE-1 = 65520, 每次最多加 255, 65520/255 = 257.0..., 向下取整 = 257
    // 每 16 字节一轮, 257/16 = 16.0625, 向下取整 = 16
    private static let NMAX: Int64 = 5552

    // 内部状态
    private var adler: UInt32

    public init() {
        adler = UInt32(1)
    }

    /// 一次性计算 Adler-32
    /// 对应 Bun: Adler32.hash(input) -> u32
    public static func hash(input: Array<UInt8>): UInt32 {
        return permute(UInt32(1), input)
    }

    /// 哈希字符串
    public static func hash(s: String): UInt32 {
        return hash(stringToBytes(s))
    }

    /// 流式更新
    public func update(input: Array<UInt8>): Unit {
        adler = Adler32.permute(adler, input)
    }

    /// 获取当前校验和
    public func finalize(): UInt32 {
        return adler
    }

    /// 重置状态
    public func reset(): Unit {
        adler = UInt32(1)
    }

    /// 核心计算函数
    /// 对应 Bun: Adler32::permute(state, input) -> u32
    public static func permute(state: UInt32, input: Array<UInt8>): UInt32 {
        var s1 = state & UInt32(0xFFFF)
        var s2 = (state >> UInt32(16)) & UInt32(0xFFFF)
        let len = input.size

        if (len == 1) {
            s1 = s1 + UInt32(input[0])
            if (s1 >= BASE) {
                s1 = s1 - BASE
            }
            s2 = s2 + s1
            if (s2 >= BASE) {
                s2 = s2 - BASE
            }
        } else if (len < 16) {
            var i: Int64 = 0
            while (i < len) {
                s1 = s1 + UInt32(input[i])
                s2 = s2 + s1
                i += 1
            }
            if (s1 >= BASE) {
                s1 = s1 - BASE
            }
            s2 = s2 % BASE
        } else {
            // NMAX / 16 = 5552 / 16 = 347
            let n: Int64 = NMAX / Int64(16)

            var i: Int64 = 0

            // 主循环: 每次处理 NMAX 字节 (5552)
            while (i + NMAX <= len) {
                var rounds: Int64 = 0
                while (rounds < n) {
                    // 16 字节展开
                    var j: Int64 = 0
                    while (j < 16) {
                        s1 = s1 + UInt32(input[i + j])
                        s2 = s2 + s1
                        j += 1
                    }
                    i += 16
                    rounds += 1
                }
                s1 = s1 % BASE
                s2 = s2 % BASE
            }

            // 剩余 16 字节块
            if (i < len) {
                while (i + 16 <= len) {
                    var j: Int64 = 0
                    while (j < 16) {
                        s1 = s1 + UInt32(input[i + j])
                        s2 = s2 + s1
                        j += 1
                    }
                    i += 16
                }
                // 最后零散字节
                while (i < len) {
                    s1 = s1 + UInt32(input[i])
                    s2 = s2 + s1
                    i += 1
                }
                s1 = s1 % BASE
                s2 = s2 % BASE
            }
        }

        return s1 | (s2 << UInt32(16))
    }
}

/// 字符串转字节数组
private func stringToBytes(s: String): Array<UInt8> {
    var bytes = Array<UInt8>()
    for (c in s) { bytes.append(UInt8(c.value)) }
    return bytes
}
