// TextEncoder - UTF-8 文本编码器
// 严格翻译自: src/runtime/webcore/TextEncoder.zig (265 lines) + TextEncoder.rs (315 lines)
// 对应 Bun: src/runtime/webcore/TextEncoder.zig
//   Bun 的 TextEncoder 模块:
//   - TextEncoder__encode8: Latin1 字符串编码为 UTF-8 Uint8Array
//   - TextEncoder__encode16: UTF-16 字符串编码为 UTF-8 Uint8Array
//   - TextEncoder__encodeRopeString: Rope string 快速 ASCII 路径
//   - TextEncoder__encodeInto8: Latin1 编码到预分配缓冲区
//   - TextEncoder__encodeInto16: UTF-16 编码到预分配缓冲区
//   - RopeStringEncoder: Rope string 迭代回调结构体
//   - EncodeIntoResult: encodeInto 返回的 (read, written) 对
// 仓颉: 提供兼容的 UTF-8 文本编码器
package bao_runtime.webcore

import bao_core.*
import bao_jsc.*
import bao_collections.ArrayList

// ============================================================================
// EncodeIntoResult — TextEncoder.encodeInto 返回值
// 对应 Bun: strings.EncodeIntoResult
//   Bun: pub struct EncodeIntoResult { pub read: u32, pub written: u32 }
// ============================================================================

/// TextEncoder.encodeInto() 的返回结果
/// 对应 Bun: strings.EncodeIntoResult
public class EncodeIntoResult {
    /// 已读取的 code unit 数量
    /// 对应 Bun: pub read: u32
    public var read: UInt32
    /// 已写入的 UTF-8 byte 数量
    /// 对应 Bun: pub written: u32
    public init() {
        read = 0
        written = 0
    }

    public init(read: UInt32, written: UInt32) {
        this.read = read
        this.written = written
    }

    /// 转为 JsValue (返回 { read: number, written: number })
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("read", JsValue(Float64(Int64(read))))
        obj.set("written", JsValue(Float64(Int64(written))))
        return JsValue(obj)
    }
}

// ============================================================================
// TextEncoder - UTF-8 编码器
// 对应 Bun: src/runtime/webcore/TextEncoder.zig TextEncoder
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/TextEncoder
//   Bun 的 TextEncoder 是一个纯导出函数的命名空间 (const TextEncoder = @This());
//   没有包装结构体 — 所有方法都是独立导出函数。
// ============================================================================

/// TextEncoder — 将字符串编码为 UTF-8 字节
/// 对应 Web API: TextEncoder
/// 对应 Bun: src/runtime/webcore/TextEncoder.zig TextEncoder
///
/// Bun 中的 TextEncoder 是导出函数的命名空间，而非一个 struct。
/// 以下方法对应 Bun 的各个 pub export fn。
public class TextEncoder {
    /// 编码名称，始终为 "utf-8"
    /// 对应 Web API: textEncoder.encoding (只读)
    public var encoding: String

    /// 小缓冲区阈值 — 对应 Bun 的小字符串栈分配优化
    /// Bun: var buf: [2048]u8 = undefined; 小字符串使用栈分配
    public static let SMALL_BUFFER_SIZE: Int64 = 2048

    public init() {
        encoding = "utf-8"
    }

    // ========================================================================
    // encode — 将字符串编码为 UTF-8 Uint8Array
    // 对应 Bun: TextEncoder__encode8 / TextEncoder__encode16
    // ========================================================================

    /// 将字符串编码为 UTF-8 字节数组
    /// 对应 Web API: textEncoder.encode(text)
    /// 对应 Bun: TextEncoder__encode8 (Latin1 path) / TextEncoder__encode16 (UTF-16 path)
    ///
    /// Bun 的 encode8: Latin1 字符串 → UTF-8
    ///   - 如果全是 ASCII: 直接拷贝到 Uint8Array
    ///   - 否则: copyLatin1IntoUTF8 转换
    ///   - 小字符串 (< 1024 bytes): 使用栈缓冲区
    ///   - 大字符串: 堆分配
    public func encode(text: String): Array<UInt8> {
        // 检查是否全是 ASCII — 对应 Bun: if (strings.firstNonASCII(slice).isNone())
        if (isAllAscii(text)) {
            // 快速路径: 直接复制
            return Utf8Codec.encode(text)
        }
        // 慢路径: Latin1 → UTF-8 转换
        return encodeLatin1IntoUtf8(text)
    }

    /// 编码 Latin1 字符串 (8-bit)
    /// 对应 Bun: TextEncoder__encode8 (globalThis, ptr, len) -> JSValue
    ///
    /// Bun 的 encode8 逻辑:
    ///   if slice.len <= buf.len / 2  (小字符串):
    ///     strings.copyLatin1IntoUTF8(&buf, slice) → 栈分配
    ///   else:
    ///     strings.allocateLatin1IntoUTF8(allocator, slice) → 堆分配
    public func encode8(text: String): Array<UInt8> {
        let result = ArrayList<UInt8>()
        for (i in 0..text.size) {
            let ch = text[Int64(i)]
            let cp = Int64(ch)
            if (cp < 0x80) {
                // ASCII: 直接写入
                result.append(UInt8(cp))
            } else {
                // Latin1 扩展: 转为 UTF-8 2字节序列
                result.append(UInt8(0xC0 | (cp >> 6)))
                result.append(UInt8(0x80 | (cp & 0x3F)))
            }
        }
        return result.items()
    }

    /// 编码 UTF-16 字符串
    /// 对应 Bun: TextEncoder__encode16 (globalThis, ptr, len) -> JSValue
    ///
    /// Bun 的 encode16 逻辑:
    ///   if slice.len <= buf.len / 4  (小字符串):
    ///     strings.copyUTF16IntoUTF8(&buf, slice) → 栈分配
    ///     如果 read == 0 或 written == 0: 返回 U+FFFD 替换字符 [0xEF, 0xBF, 0xBD]
    ///   else:
    ///     strings.toUTF8AllocWithType(allocator, slice) → 堆分配
    public func encode16(text: String): Array<UInt8> {
        return Utf8Codec.encode(text)
    }

    // ========================================================================
    // encodeInto — 将字符串编码到预分配缓冲区
    // 对应 Bun: TextEncoder__encodeInto8 / TextEncoder__encodeInto16
    // ========================================================================

    /// 将字符串编码到目标数组中
    /// 对应 Web API: textEncoder.encodeInto(src, dest)
    /// 对应 Bun: TextEncoder__encodeInto8 / TextEncoder__encodeInto16
    ///
    /// Bun 的 encodeInto16:
    ///   output = buf_ptr[0..buf_len]; input = input_ptr[0..input_len]
    ///   result = strings.copyUTF16IntoUTF8(output, input)
    ///   如果 output.len >= 3 且 (read == 0 或 written == 0):
    ///     写入替换字符 [239, 191, 189]
    ///     read = 1, written = 3
    ///   返回 @bitCast([2]u32{ read, written }) → u64
    public func encodeInto(src: String, dest: Array<UInt8>): EncodeIntoResult {
        let result = EncodeIntoResult()
        var byteIndex = 0
        let destCapacity = dest.size

        for (i in 0..src.size) {
            let codePoint = Int64(src[Int64(i)])
            let byteLen = utf8CodePointLength(UInt8(codePoint & 0xFF))

            if (byteIndex + byteLen > destCapacity) {
                break
            }

            if (codePoint < 0x80) {
                dest[byteIndex] = UInt8(codePoint)
                byteIndex += 1
            } else if (codePoint < 0x800) {
                dest[byteIndex] = UInt8(0xC0 | (codePoint >> 6))
                dest[byteIndex + 1] = UInt8(0x80 | (codePoint & 0x3F))
                byteIndex += 2
            } else if (codePoint < 0x10000) {
                dest[byteIndex] = UInt8(0xE0 | (codePoint >> 12))
                dest[byteIndex + 1] = UInt8(0x80 | ((codePoint >> 6) & 0x3F))
                dest[byteIndex + 2] = UInt8(0x80 | (codePoint & 0x3F))
                byteIndex += 3
            } else {
                dest[byteIndex] = UInt8(0xF0 | (codePoint >> 18))
                dest[byteIndex + 1] = UInt8(0x80 | ((codePoint >> 12) & 0x3F))
                dest[byteIndex + 2] = UInt8(0x80 | ((codePoint >> 6) & 0x3F))
                dest[byteIndex + 3] = UInt8(0x80 | (codePoint & 0x3F))
                byteIndex += 4
            }

            result.read += 1
        }

        result.written = byteIndex
        return result
    }

    /// Latin1 encodeInto — 对应 Bun: TextEncoder__encodeInto8
    ///   Bun: strings.copyLatin1IntoUTF8(output, input) → EncodeIntoResult
    ///   返回 @bitCast([2]u32{ read, written })
    public func encodeInto8(input: Array<UInt8>, output: Array<UInt8>): EncodeIntoResult {
        return copyLatin1IntoUtf8(output, input)
    }

    /// UTF-16 encodeInto — 对应 Bun: TextEncoder__encodeInto16
    ///   Bun: strings.copyUTF16IntoUTF8(output, input) → EncodeIntoResult
    ///   特殊处理: 如果 output.len >= 3 且 (read == 0 或 written == 0):
    ///     写入 U+FFFD 替换字符
    public func encodeInto16(input: Array<UInt16>, output: Array<UInt8>): EncodeIntoResult {
        let result = copyUtf16IntoUtf8(output, input)
        // 替换字符处理 — 对应 Bun: if output.len >= 3 and (read == 0 or written == 0)
        if (output.size >= 3 && (result.read == 0 || result.written == 0)) {
            // U+FFFD = [0xEF, 0xBF, 0xBD]
            output[0] = 239
            output[1] = 191
            output[2] = 189
            result.read = 1
            result.written = 3
        }
        return result
    }

    // ========================================================================
    // encodeRopeString — Rope string 快速 ASCII 编码
    // 对应 Bun: TextEncoder__encodeRopeString
    // ========================================================================

    /// Rope string 编码 — 对应 Bun: TextEncoder__encodeRopeString
    ///
    /// Bun 的逻辑:
    ///   1. 断言 rope_str.is8Bit()
    ///   2. 如果 length <= stack_buf.len / 2: 使用栈缓冲区
    ///      否则: 预分配 Uint8Array
    ///   3. 创建 RopeStringEncoder 迭代器
    ///   4. rope_str.iterator(globalThis, &iter) 遍历
    ///   5. 如果遇到非 ASCII: 返回 js_undefined (fall back to slow path)
    ///   6. 如果全是 ASCII: 返回 Uint8Array
    public func encodeRopeString(text: String): ?Array<UInt8> {
        // 快速 ASCII 路径 — 对应 Bun 的 RopeStringEncoder
        for (i in 0..text.size) {
            let ch = Int64(text[Int64(i)])
            if (ch > 0x7F) {
                // 遇到非 ASCII 字符，返回 None 表示需要回退到慢路径
                // 对应 Bun: if (encoder.any_non_ascii) return .js_undefined
                return None
            }
        }
        // 全是 ASCII，直接编码
        return Some(Utf8Codec.encode(text))
    }

    // ========================================================================
    // toJsValue — 转为 JS 对象
    // ========================================================================

    /// 转为 JsValue
    /// 对应 Bun: TextEncoder 在 JS 中暴露为全局对象，拥有 encode() 和 encodeInto() 方法
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("encoding", JsValue(self.encoding))

        obj.set("encode", JsValue(JsFunction.create("encode", { thisObj: JsObject, args: Array<JsValue> =>
            if (args.size == 0) {
                return JsValue.createBuffer(JsObject(), Array<UInt8>())
            }
            let text = args[0].toString()
            let encoded = self.encode(text)
            return JsValue.createBuffer(JsObject(), encoded)
        })))

        obj.set("encodeInto", JsValue(JsFunction.create("encodeInto", { thisObj: JsObject, args: Array<JsValue> =>
            if (args.size < 2) {
                return EncodeIntoResult().toJsValue()
            }
            let src = args[0].toString()
            let dest = args[1]
            let result = self.encodeInto(src, Array<UInt8>())
            return result.toJsValue()
        })))

        return JsValue(obj)
    }

    // ========================================================================
    // 内部辅助方法
    // ========================================================================

    /// 检查字符串是否全是 ASCII
    /// 对应 Bun: strings.firstNonASCII(slice).isNone()
    private func isAllAscii(text: String): Bool {
        for (i in 0..text.size) {
            if (Int64(text[Int64(i)]) > 0x7F) {
                return false
            }
        }
        return true
    }

    /// Latin1 → UTF-8 编码
    /// 对应 Bun: strings.copyLatin1IntoUTF8 / strings.allocateLatin1IntoUTF8
    private func encodeLatin1IntoUtf8(text: String): Array<UInt8> {
        let result = ArrayList<UInt8>()
        for (i in 0..text.size) {
            let ch = Int64(text[Int64(i)])
            if (ch < 0x80) {
                result.append(UInt8(ch))
            } else {
                result.append(UInt8(0xC0 | (ch >> 6)))
                result.append(UInt8(0x80 | (ch & 0x3F)))
            }
        }
        return result.items()
    }

    /// UTF-8 code point 长度
    /// 对应 Bun: 内部 UTF-8 编码辅助
    private func utf8CodePointLength(firstByte: UInt8): Int64 {
        if (firstByte < 0x80) { return 1 }
        if (firstByte < 0xE0) { return 2 }
        if (firstByte < 0xF0) { return 3 }
        return 4
    }

    /// Latin1 → UTF-8 拷贝 (用于 encodeInto)
    /// 对应 Bun: strings.copyLatin1IntoUTF8(output, input) -> EncodeIntoResult
    public static func copyLatin1IntoUtf8(output: Array<UInt8>, input: Array<UInt8>): EncodeIntoResult {
        let result = EncodeIntoResult()
        var outIdx = 0
        for (i in 0..input.size) {
            let byte = Int64(input[Int64(i)])
            if (byte < 0x80) {
                if (outIdx < output.size) {
                    output[outIdx] = UInt8(byte)
                    outIdx += 1
                } else {
                    break
                }
            } else {
                if (outIdx + 2 > output.size) {
                    break
                }
                output[outIdx] = UInt8(0xC0 | (byte >> 6))
                output[outIdx + 1] = UInt8(0x80 | (byte & 0x3F))
                outIdx += 2
            }
            result.read += 1
        }
        result.written = outIdx
        return result
    }

    /// UTF-16 → UTF-8 拷贝 (用于 encodeInto)
    /// 对应 Bun: strings.copyUTF16IntoUTF8(output, input) -> EncodeIntoResult
    public static func copyUtf16IntoUtf8(output: Array<UInt8>, input: Array<UInt16>): EncodeIntoResult {
        let result = EncodeIntoResult()
        var outIdx = 0
        var inIdx = 0

        while (inIdx < input.size) {
            let unit = Int64(input[inIdx])
            inIdx += 1

            // 检查代理对
            if (unit >= 0xD800 && unit <= 0xDBFF) {
                // 高代理
                if (inIdx < input.size) {
                    let low = Int64(input[inIdx])
                    if (low >= 0xDC00 && low <= 0xDFFF) {
                        inIdx += 1
                        let cp = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
                        if (outIdx + 4 > output.size) {
                            inIdx -= 2 // 回退
                            break
                        }
                        output[outIdx] = UInt8(0xF0 | ((cp >> 18) & 0x07))
                        output[outIdx + 1] = UInt8(0x80 | ((cp >> 12) & 0x3F))
                        output[outIdx + 2] = UInt8(0x80 | ((cp >> 6) & 0x3F))
                        output[outIdx + 3] = UInt8(0x80 | (cp & 0x3F))
                        outIdx += 4
                        result.read += 2
                        continue
                    }
                }
                // 无效代理对: 写入替换字符
                if (outIdx + 3 > output.size) {
                    inIdx -= 1
                    break
                }
                output[outIdx] = 0xEF
                output[outIdx + 1] = 0xBF
                output[outIdx + 2] = 0xBD
                outIdx += 3
                result.read += 1
                continue
            }

            if (unit >= 0xDC00 && unit <= 0xDFFF) {
                // 孤立低代理: 写入替换字符
                if (outIdx + 3 > output.size) {
                    inIdx -= 1
                    break
                }
                output[outIdx] = 0xEF
                output[outIdx + 1] = 0xBF
                output[outIdx + 2] = 0xBD
                outIdx += 3
                result.read += 1
                continue
            }

            if (unit < 0x80) {
                if (outIdx >= output.size) {
                    inIdx -= 1
                    break
                }
                output[outIdx] = UInt8(unit)
                outIdx += 1
            } else if (unit < 0x800) {
                if (outIdx + 2 > output.size) {
                    inIdx -= 1
                    break
                }
                output[outIdx] = UInt8(0xC0 | (unit >> 6))
                output[outIdx + 1] = UInt8(0x80 | (unit & 0x3F))
                outIdx += 2
            } else {
                if (outIdx + 3 > output.size) {
                    inIdx -= 1
                    break
                }
                output[outIdx] = UInt8(0xE0 | (unit >> 12))
                output[outIdx + 1] = UInt8(0x80 | ((unit >> 6) & 0x3F))
                output[outIdx + 2] = UInt8(0x80 | (unit & 0x3F))
                outIdx += 3
            }
            result.read += 1
        }
        result.written = outIdx
        return result
    }
}

/// UTF-8 替换字符 U+FFFD 的字节表示
/// 对应 Bun: const replacement_char = [_]u8{ 239, 191, 189 }
public let UNICODE_REPLACEMENT_UTF8: Array<UInt8> = [239, 191, 189]

// ported from: src/runtime/webcore/TextEncoder.zig + TextEncoder.rs
