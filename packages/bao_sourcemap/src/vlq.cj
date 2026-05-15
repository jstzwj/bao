// VLQ - Variable-Length Quantity 编解码
// 严格翻译自: src/sourcemap/VLQ.zig
//   const VLQ = @This();
//   bytes: [vlq_max_in_bytes]u8,
//   len: u8 = 0,
//   pub fn encode(value: i32) VLQ { ... }
//   pub fn decode(encoded: []const u8, start: usize) VLQResult { ... }
//
// VLQ 编码原理 (用于 Source Map 的 "mappings" 字段):
//   - 将整数编码为可变长度的 Base64 字符序列
//   - 每个 Base64 字符包含 6 位数据
//     - bit 5 (0x20): 继续位 (1 = 还有更多字符)
//     - bit 0: 符号位 (1 = 负数)
//     - bit 1-4: 数值
//   - 编码范围: i32, 最多 7 个字节
//
//   示例:
//     0 -> "A"    (6位: 符号0, 值0000, 继续0 = 000000 = 'A')
//     1 -> "C"    (6位: 符号0, 值0001, 继续0 = 000001 = 'C')
//     -1 -> "D"   (6位: 符号1, 值0000, 继续0 = 000001 = 'D')
//     16 -> "gB"  (第一字节: 符号0, 值0000, 继续1 = 100000 = 'g')
//                    (第二字节: 符号0, 值0001, 继续0 = 000001 = 'B')
package bao_sourcemap.vlq

import bao_core.*

// ============================================================================
// 常量
// ============================================================================

/// Base64 字母表 - 对应 Bun VLQ.base64
public let VLQ_BASE64: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

/// Base64 查找表 - 对应 Bun VLQ.base64_lut
/// 使用 128 元素数组模拟 Zig 的 [maxInt(u7)]u8
/// 无效字符标记为 0xFF
public let VLQ_BASE64_LUT: Array<UInt8> = {
    var lut = Array<UInt8>(128, item: 0xFF.toUInt8())
    for (i in 0..64) {
        lut[VLQ_BASE64[i].toUInt8()] = UInt8(i)
    }
    lut
}()

/// VLQ 最大编码字节数 - 对应 Bun VLQ.vlq_max_in_bytes = 7
public let VLQ_MAX_BYTES: Int64 = 7

// ============================================================================
// VLQ 编码结果 - 对应 Bun VLQ struct
//   bytes: [vlq_max_in_bytes]u8,
//   len: u8 = 0,
//   pub inline fn slice(self: *const VLQ) []const u8
// ============================================================================

/// VLQ 编码后的字节数据
public class VLQEncoded {
    public var bytes: Array<UInt8>
    public var len: Int64

    public init() {
        bytes = Array<UInt8>(VLQ_MAX_BYTES, item: 0)
        len = 0
    }

    public init(bytes: Array<UInt8>, len: Int64) {
        this.bytes = bytes
        this.len = len
    }

    /// 获取有效字节切片 - 对应 Bun VLQ.slice()
    public func slice(): Array<UInt8> {
        bytes.subArray(0, len)
    }

    /// 写入到 StringBuilder
    public func writeTo(sb: StringBuilder): Unit {
        for (i in 0..len) {
            sb.append(Char(Int32(bytes[i])))
        }
    }

    /// 转为字符串
    public func toString(): String {
        var sb = StringBuilder()
        writeTo(sb)
        return sb.toString()
    }
}

// ============================================================================
// VLQ 解码结果 - 对应 Bun VLQ.VLQResult
//   pub const VLQResult = struct {
//       value: i32 = 0,
//       start: usize = 0,
//   }
// ============================================================================

/// VLQ 解码结果
public class VLQResult {
    /// 解码后的值
    public var value: Int64
    /// 解码后的新位置
    public var start: Int64

    public init(value: Int64, start: Int64) {
        this.value = value
        this.start = start
    }
}

// ============================================================================
// VLQ 编解码工具类
// ============================================================================

/// VLQ 编解码 - 严格翻译自 Bun VLQ.zig
public class VLQ {
    // ========================================================================
    // encode - VLQ 编码
    // 严格翻译自: VLQ.encode / VLQ.encodeSlowPath
    //   fn encode(value: i32) VLQ {
    //       return if (value >= 0 and value <= 255)
    //           vlq_lookup_table[@as(usize, @intCast(value))]
    //       else
    //           encodeSlowPath(value);
    //   }
    //
    //   fn encodeSlowPath(value: i32) VLQ {
    //       var vlq: u32 = if (value >= 0)
    //           @as(u32, @bitCast(value << 1))
    //       else
    //           @as(u32, @bitCast((-value << 1) | 1));
    //       inline for (0..vlq_max_in_bytes) |_| {
    //           var digit = vlq & 31;
    //           vlq >>= 5;
    //           if (vlq != 0) { digit |= 32; }
    //           bytes[len] = base64[digit];
    //           len += 1;
    //           if (vlq == 0) return;
    //       }
    //   }
    //
    // 编码步骤:
    //   1. 将带符号整数转为无符号 VLQ 值:
    //      - 正数: value << 1
    //      - 负数: (-value << 1) | 1
    //   2. 每 5 位一组编码为一个 Base64 字符:
    //      - 低 5 位为数据 (bit 0-4)
    //      - bit 5 为继续位
    //   3. 直到所有位编码完毕
    // ========================================================================

    /// 编码整数为 VLQ Base64 字符串
    public static func encode(value: Int64): String {
        // 特殊情况: 0-255 使用快速路径 (对应 Bun vlq_lookup_table)
        if (value >= 0 && value <= 255) {
            return vlqEncodeSmall(value)
        }

        // 将带符号值转为无符号 VLQ 值
        var vlq = if (value >= 0) {
            value << 1
        } else {
            ((-value) << 1) | 1
        }

        var result = StringBuilder()

        // 每 5 位编码一个字符
        var count = 0
        while (count < VLQ_MAX_BYTES) {
            var digit = vlq & 31  // 取低 5 位
            vlq = vlq >> 5

            // 如果还有更多位，设置继续位 (bit 5)
            if (vlq != 0) {
                digit = digit | 32
            }

            result.append(VLQ_BASE64[digit])
            count += 1

            if (vlq == 0) {
                break
            }
        }

        return result.toString()
    }

    /// 编码整数为 VLQEncoded 对象 - 对应 Bun VLQ.encode 返回结构体
    public static func encodeToBytes(value: Int64): VLQEncoded {
        let result = VLQEncoded()

        var vlq = if (value >= 0) {
            value << 1
        } else {
            ((-value) << 1) | 1
        }

        var count = 0
        while (count < VLQ_MAX_BYTES) {
            var digit = vlq & 31
            vlq = vlq >> 5

            if (vlq != 0) {
                digit = digit | 32
            }

            result.bytes[count] = VLQ_BASE64[digit].toUInt8()
            result.len += 1
            count += 1

            if (vlq == 0) {
                break
            }
        }

        return result
    }

    /// 编码小数值 (0-255) 使用查表优化
    /// 对应 Bun vlq_lookup_table
    private static func vlqEncodeSmall(value: Int64): String {
        var vlq = value << 1
        var digit = vlq & 31
        vlq = vlq >> 5
        if (vlq != 0) {
            digit = digit | 32
        }
        var result = StringBuilder()
        result.append(VLQ_BASE64[digit])

        while (vlq != 0) {
            digit = vlq & 31
            vlq = vlq >> 5
            if (vlq != 0) {
                digit = digit | 32
            }
            result.append(VLQ_BASE64[digit])
        }

        return result.toString()
    }

    // ========================================================================
    // decode - VLQ 解码
    // 严格翻译自: VLQ.decode
    //   pub fn decode(encoded: []const u8, start: usize) VLQResult {
    //       var shift: u8 = 0;
    //       var vlq: u32 = 0;
    //       inline for (0..vlq_max_in_bytes + 1) |i| {
    //           const index = @as(u32, base64_lut[@as(u7, @truncate(encoded_[i]))]);
    //           vlq |= (index & 31) << @as(u5, @truncate(shift));
    //           shift += 5;
    //           if ((index & 32) == 0) {
    //               return VLQResult{
    //                   .start = start + i + 1,
    //                   .value = if ((vlq & 1) == 0) vlq >> 1
    //                            else -@as(i32, @intCast(vlq >> 1)),
    //               };
    //           }
    //       }
    //   }
    //
    // 解码步骤:
    //   1. 逐个读取 Base64 字符
    //   2. 查找字符索引 (6 位值)
    //   3. 低 5 位为数据，按位移累加到 vlq
    //   4. bit 5 为继续位: 1 = 继续读取, 0 = 结束
    //   5. 从 vlq 恢复带符号值:
    //      - 最低位为 0: vlq >> 1 (正数)
    //      - 最低位为 1: -(vlq >> 1) (负数)
    // ========================================================================

    /// 解码 VLQ Base64 字符串
    /// 从指定位置开始解码一个 VLQ 值，返回值和新位置
    public static func decode(encoded: String, start: Int64): VLQResult {
        var shift = 0
        var vlq = 0
        var i = start
        let len = encoded.size

        while (i < len && (i - start) < VLQ_MAX_BYTES + 1) {
            let ch = encoded[i]
            // 查找字符索引 - 对应 Bun base64_lut[@as(u7, @truncate(encoded_[i]))]
            if (ch.toUInt8() >= 128) {
                return VLQResult(0, i)
            }
            let idx = VLQ_BASE64_LUT[ch.toUInt8()]
            if (idx == 0xFF.toUInt8()) {
                return VLQResult(0, i)
            }

            // 累加数据位 - 对应 vlq |= (index & 31) << shift
            vlq = vlq | ((Int64(idx) & 31) << shift)
            shift += 5
            i += 1

            // 检查继续位 (bit 5) - 对应 if ((index & 32) == 0)
            if ((Int64(idx) & 32) == 0) {
                // 无继续位 -> 解码完成
                // 恢复带符号值
                let value = if ((vlq & 1) == 0) {
                    vlq >> 1
                } else {
                    -(vlq >> 1)
                }
                return VLQResult(value, i)
            }
        }

        return VLQResult(0, i)
    }

    /// 解码 VLQ (假设输入有效) - 对应 Bun VLQ.decodeAssumeValid
    /// 跳过有效性检查，用于已知合法的 mappings 字符串
    public static func decodeAssumeValid(encoded: String, start: Int64): VLQResult {
        var shift = 0
        var vlq = 0
        var i = start
        let len = encoded.size

        while (i < len && (i - start) < VLQ_MAX_BYTES + 1) {
            let ch = encoded[i]
            // 直接查找 - 假设输入合法
            let idx = VLQ_BASE64_LUT[ch.toUInt8()]

            vlq = vlq | ((Int64(idx) & 31) << shift)
            shift += 5
            i += 1

            if ((Int64(idx) & 32) == 0) {
                let value = if ((vlq & 1) == 0) {
                    vlq >> 1
                } else {
                    -(vlq >> 1)
                }
                return VLQResult(value, i)
            }
        }

        return VLQResult(0, i)
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 编码多个值为 VLQ 字符串 (用于 source map mappings)
    /// 多个值按顺序编码，无分隔符
    public static func vlqEncode(values: Array<Int64>): String {
        var sb = StringBuilder()
        for (i in 0..values.size) {
            sb.append(encode(values[i]))
        }
        return sb.toString()
    }

    /// 从 VLQ 字符串解码多个值
    /// 返回所有解码值和最终位置
    public static func vlqDecode(str: String): Array<Int64> {
        let result = ArrayList<Int64>()
        var pos = 0
        while (pos < str.size) {
            let r = decode(str, pos)
            if (r.start == pos) {
                break  // 无法继续解码
            }
            result.append(r.value)
            pos = r.start
        }
        return result.toArray()
    }

    /// 饱和减法 - 对应 Zig 的 -| 操作符
    /// a -| b = if (a >= b) a - b else 0
    public static func saturatingSub(a: Int64, b: Int64): Int64 {
        if (a >= b) {
            a - b
        } else {
            0
        }
    }
}
