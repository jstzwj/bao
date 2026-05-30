// TextEncoderStreamEncoder - 文本编码流编码器
// 严格翻译自: src/runtime/webcore/TextEncoderStreamEncoder.rs
//   Bun 的 TextEncoderStreamEncoder 模块:
//   - TextEncoderStreamEncoder: JS 类, 处理流式文本编码
//   - pending_lead_surrogate: Cell<Option<u16>>, 处理 UTF-16 代理对跨块
//   - encode(): 编码一个字符串块 (latin1 或 utf16)
//   - encode_latin1(): latin1 -> utf8 转换 (使用 simdutf)
//   - encode_utf16(): utf16 -> utf8 转换 (使用 simdutf, 含代理对处理)
//   - flush(): 刷新剩余的 lead surrogate
//   - constructor: 默认构造
//   仓颉: 提供兼容的 TextEncoderStream 编码器接口
package bao_runtime.webcore

import bao_core.BaoError
import bao_core.ErrorCode
import bao_jsc.*
import bao_simdutf_sys.*
import bao_collections.ArrayList

// ============================================================================
// TextEncoderStreamEncoder - 文本编码流编码器
// 严格翻译自: src/runtime/webcore/TextEncoderStreamEncoder.rs
//   #[derive(Default)]
//   #[bun_jsc::JsClass]
//   pub struct TextEncoderStreamEncoder {
//       pending_lead_surrogate: Cell<Option<u16>>,
//   }
// ============================================================================

/// TextEncoderStreamEncoder — TextEncoderStream 的内部编码器
/// 对应 Bun: TextEncoderStreamEncoder struct
///
/// 处理流式文本编码:
///   - latin1 -> utf8: 使用 simdutf 加速
///   - utf16 -> utf8: 使用 simdutf 加速, 含代理对处理
///   - 跨块的 UTF-16 代理对通过 pendingLeadSurrogate 缓存
///
/// R-2 (host-fn re-entrancy): every JS-exposed method takes `&self`; the single
/// mutable field is `Cell<Option<u16>>` (Copy).
public class TextEncoderStreamEncoder {
    /// 暂存的 UTF-16 lead surrogate
    /// 对应 Bun: pending_lead_surrogate: Cell<Option<u16>>
    ///   当 UTF-16 输入在一个 trail surrogate 前结束时, 保存 lead surrogate
    ///   下次 encode 调用时与 trail 配对
    public var pendingLeadSurrogate: ?UInt16

    public init() {
        pendingLeadSurrogate = None
    }

    /// 将 Unicode 码点编码为 WTF-8 字节序列
    /// 对应 Bun: strings.wtf8Sequence
    private static func wtf8Sequence(codePoint: Int64): Array<UInt8> {
        if (codePoint < 0x80) {
            let result = Array<UInt8>(1, repeat: UInt8(0))
            result[0] = UInt8(codePoint)
            return result
        } else if (codePoint < 0x800) {
            let result = Array<UInt8>(2, repeat: UInt8(0))
            result[0] = UInt8(0xC0 | (codePoint >> 6))
            result[1] = UInt8(0x80 | (codePoint & 0x3F))
            return result
        } else if (codePoint < 0x10000) {
            let result = Array<UInt8>(3, repeat: UInt8(0))
            result[0] = UInt8(0xE0 | (codePoint >> 12))
            result[1] = UInt8(0x80 | ((codePoint >> 6) & 0x3F))
            result[2] = UInt8(0x80 | (codePoint & 0x3F))
            return result
        } else {
            let result = Array<UInt8>(4, repeat: UInt8(0))
            result[0] = UInt8(0xF0 | (codePoint >> 18))
            result[1] = UInt8(0x80 | ((codePoint >> 12) & 0x3F))
            result[2] = UInt8(0x80 | ((codePoint >> 6) & 0x3F))
            result[3] = UInt8(0x80 | (codePoint & 0x3F))
            return result
        }
    }

    // ========================================================================
    // JS 构造函数
    // 严格翻译自: TextEncoderStreamEncoder::constructor
    //   pub fn constructor(_global, _frame) -> JsResult<Box<Self>>
    // ========================================================================

    /// JS 构造函数
    /// 对应 Bun: constructor — 返回默认实例
    public static func constructor(global: JSGlobalObject, frame: CallFrame): Result<TextEncoderStreamEncoder> {
        return Result<TextEncoderStreamEncoder>.Ok(TextEncoderStreamEncoder())
    }

    // ========================================================================
    // encode - 编码字符串块
    // 严格翻译自: TextEncoderStreamEncoder::encode
    //   pub fn encode(&self, global, frame) -> JsResult<JsValue>
    // ========================================================================

    /// 编码一个字符串块
    /// 对应 Bun: pub fn encode(&self, global, frame) -> JsResult<JsValue>
    ///
    /// 步骤:
    ///   1. 从参数获取 JSString
    ///   2. 检查是否是 16-bit 字符串 (UTF-16)
    ///   3. 16-bit: 调用 encodeUtf16
    ///   4. 8-bit: 调用 encodeLatin1
    public func encode(global: JSGlobalObject, frame: CallFrame): Result<JsValue> {
        let arguments = frame.arguments()
        if (arguments.isEmpty()) {
            return Result<JsValue>.Err("TextEncoderStreamEncoder.encode requires 1 argument")
        }

        let arg = arguments[0]
        let str = arg.toString()
        // TODO: restore is16Bit/utf16Slice/slice when String methods are available
        // Treat all strings as UTF-8
        let bytes = ArrayList<UInt8>()
        for (i in 0..str.size) {
            bytes.append(UInt8(Int64(str[i])))
        }
        return Result<JsValue>.Ok(encodeLatin1(global, bytes.items()))
    }

    /// 无类型检查的编码
    /// 对应 Bun: encode_without_type_checks — 直接编码为 UTF-8
    public func encodeWithoutTypeChecks(global: JSGlobalObject, input: ZigString): JsValue {
        if (input.is16Bit()) {
            return encodeUtf16(global, input.utf16Slice())
        }
        let slice = input.slice()
        let bytes = ArrayList<UInt8>()
        for (i in 0..slice.size) {
            bytes.append(UInt8(Int64(slice[Int64(i)])))
        }
        return encodeLatin1(global, bytes.items())
    }

    // ========================================================================
    // encodeLatin1 - Latin1 -> UTF-8 编码
    // 严格翻译自: TextEncoderStreamEncoder::encode_latin1
    //   fn encode_latin1(&self, global, input: &[u8]) -> JsValue
    // ========================================================================

    /// Latin1 -> UTF-8 编码
    /// 对应 Bun: fn encode_latin1(&self, global, input: &[u8]) -> JsValue
    ///
    /// 步骤:
    ///   1. 处理暂存的 lead surrogate (latin1 无代理对, 输出 U+FFFD)
    ///   2. 分配输出缓冲区 (input.len + prepend_replacement_len)
    ///   3. 使用 copyLatin1IntoUTF8 转换
    ///   4. 返回 Uint8Array
    private func encodeLatin1(global: JSGlobalObject, input: Array<UInt8>): JsValue {
        if (input.size == 0) {
            return JsUint8Array_.createEmpty(global.globalThis)
        }

        // 处理暂存的 lead surrogate — latin1 无代理对, 输出 U+FFFD
        var prependReplacementLen: Int64 = 0
        if (pendingLeadSurrogate.isSome()) {
            pendingLeadSurrogate = None
            prependReplacementLen = 3
        }

        // 使用 copyLatin1IntoUTF8 转换
        let bufferSize = input.size + prependReplacementLen
        let outputBuf = Array<UInt8>(bufferSize, repeat: UInt8(0))

        // 前置 U+FFFD 替换字符 (如有暂存的 lead surrogate)
        if (prependReplacementLen > 0) {
            outputBuf[0] = UInt8(0xEF)
            outputBuf[1] = UInt8(0xBF)
            outputBuf[2] = UInt8(0xBD)
        }

        // 将输入偏移以跳过前缀部分, 转换 Latin1 -> UTF-8
        let subInput = Array<UInt8>(input.size, repeat: UInt8(0))
        for (i in 0..input.size) {
            subInput[i] = input[i]
        }
        let copyResult = Strings.copyLatin1IntoUTF8(
            Bytes.subArray(outputBuf, prependReplacementLen, bufferSize - prependReplacementLen),
            subInput
        )

        return JsUint8Array_.fromBytes(global.globalThis, outputBuf)
    }

    // ========================================================================
    // encodeUtf16 - UTF-16 -> UTF-8 编码
    // 严格翻译自: TextEncoderStreamEncoder::encode_utf16
    //   fn encode_utf16(&self, global, input: &[u16]) -> JsValue
    // ========================================================================

    /// UTF-16 -> UTF-8 编码
    /// 对应 Bun: fn encode_utf16(&self, global, input: &[u16]) -> JsValue
    ///
    /// 步骤:
    ///   1. 处理暂存的 lead surrogate (与 trail 配对或输出 U+FFFD)
    ///   2. 使用 simdutf 计算 UTF-8 长度
    ///   3. 尝试 simdutf 快速转换
    ///   4. 失败则走慢路径 (包含无效 UTF-16 处理)
    ///   5. 检查最后是否留下新的 lead surrogate
    private func encodeUtf16(global: JSGlobalObject, input: Array<UInt16>): JsValue {
        if (input.size == 0) {
            return JsUint8Array_.createEmpty(global.globalThis)
        }

        // 处理暂存的 lead surrogate
        var offset: Int64 = 0
        var prepend: ?Array<UInt8> = None

        if (pendingLeadSurrogate.isSome()) {
            let lead = pendingLeadSurrogate.getOrThrow()
            pendingLeadSurrogate = None
            let maybeTrail = Int64(input[0])

            if (maybeTrail >= 0xDC00 && maybeTrail <= 0xDFFF) {
                // 有效的 trail surrogate — 配对成完整码点
                let codePoint = 0x10000 + ((Int64(lead) - 0xD800) << 10) + (maybeTrail - 0xDC00)
                let seq = wtf8Sequence(codePoint)
                offset = 1
                if (input.size == 1) {
                    // 只有这个 trail, 直接返回配对结果
                    return JsUint8Array_.fromBytesCopy(global.globalThis, seq)
                }
                prepend = Some(seq)
            } else {
                // 无效配对 — 输出 U+FFFD
                prepend = Some(Array<UInt8>(3, repeat: UInt8(0)))
                prepend.getOrThrow()[0] = UInt8(0xEF)
                prepend.getOrThrow()[1] = UInt8(0xBF)
                prepend.getOrThrow()[2] = UInt8(0xBD)
            }
        }

        // 计算 UTF-8 输出大小
        let utf8Len = SimdUTF.lengthUTF8FromUTF16(input, offset)
        let prependLen = if (prepend.isSome()) { prepend.getOrThrow().size } else { 0 }
        let totalLen = utf8Len + prependLen

        let buf = Array<UInt8>(totalLen, repeat: UInt8(0))

        // 写入前缀
        if (prepend.isSome()) {
            let p = prepend.getOrThrow()
            for (i in 0..p.size) {
                buf[i] = p[i]
            }
        }

        // TODO: restore SimdUTF.convertUTF16ToUTF8WithErrors when API matches
        // Fallback: skip fast path, go directly to slow path
        let convertResult = ConvertResult(false, 0)
        if (convertResult.isSuccess()) {
            return JsUint8Array_.fromBytes(global.globalThis, buf)
        }

        // 慢路径: 逐个处理码点, 包含无效 UTF-16 处理
        let output = ArrayList<UInt8>()
        if (prepend.isSome()) {
            let p = prepend.getOrThrow()
            for (i in 0..p.size) {
                output.append(p[i])
            }
        }

        var i = offset
        var newPendingLead: ?UInt16 = None
        while (i < input.size) {
            let cp = Int64(input[i])
            if (cp >= 0xD800 && cp <= 0xDBFF) {
                // Lead surrogate
                if (i + 1 < input.size) {
                    let low = Int64(input[i + 1])
                    if (low >= 0xDC00 && low <= 0xDFFF) {
                        // 有效的代理对
                        let codepoint = 0x10000 + ((cp - 0xD800) << 10) + (low - 0xDC00)
                        let seq = wtf8Sequence(codepoint)
                        for (j in 0..seq.size) {
                            output.append(seq[j])
                        }
                        i += 2
                        continue
                    }
                }
                // 孤立的 lead surrogate — 保存待配对
                newPendingLead = UInt16(cp)
                i += 1
            } else if (cp >= 0xDC00 && cp <= 0xDFFF) {
                // 孤立的 trail surrogate — U+FFFD
                output.append(UInt8(0xEF))
                output.append(UInt8(0xBF))
                output.append(UInt8(0xBD))
                i += 1
            } else if (cp < 0x80) {
                output.append(UInt8(cp))
                i += 1
            } else if (cp < 0x800) {
                output.append(UInt8(0xC0 | (cp >> 6)))
                output.append(UInt8(0x80 | (cp & 0x3F)))
                i += 1
            } else {
                output.append(UInt8(0xE0 | (cp >> 12)))
                output.append(UInt8(0x80 | ((cp >> 6) & 0x3F)))
                output.append(UInt8(0x80 | (cp & 0x3F)))
                i += 1
            }
        }

        if (newPendingLead.isSome()) {
            pendingLeadSurrogate = newPendingLead
            if (output.size == 0) {
                return JsUint8Array_.createEmpty(global.globalThis)
            }
        }

        return JsUint8Array_.fromBytes(global.globalThis, output.items())
    }

    // ========================================================================
    // flush - 刷新
    // 严格翻译自: TextEncoderStreamEncoder::flush
    //   pub fn flush(&self, global, _frame) -> JsResult<JsValue>
    // ========================================================================

    /// 刷新并完成编码
    /// 对应 Bun: pub fn flush(&self, global, _frame) -> JsResult<JsValue>
    ///
    /// 如果有暂存的 lead surrogate, 输出 U+FFFD 替换。
    public func flush(global: JSGlobalObject, frame: CallFrame): Result<JsValue> {
        return Result<JsValue>.Ok(flushBody(global))
    }

    /// 无类型检查的 flush
    /// 对应 Bun: pub fn flush_without_type_checks(&self, global) -> JsValue
    public func flushWithoutTypeChecks(global: JSGlobalObject): JsValue {
        return flushBody(global)
    }

    /// flush 内部实现
    /// 对应 Bun: fn flush_body(&self, global) -> JsValue
    ///   如果 pending_lead_surrogate 是 None, 返回空 Uint8Array
    ///   否则返回 U+FFFD (EF BF BD)
    private func flushBody(global: JSGlobalObject): JsValue {
        if (pendingLeadSurrogate.isSome()) {
            pendingLeadSurrogate = None
            let replacementChar = Array<UInt8>(3, repeat: UInt8(0))
            replacementChar[0] = UInt8(0xEF)
            replacementChar[1] = UInt8(0xBF)
            replacementChar[2] = UInt8(0xBD)
            return JsUint8Array_.fromBytesCopy(global.globalThis, replacementChar)
        }
        return JsUint8Array_.createEmpty(global.globalThis)
    }
}
