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

import bao_core.*
import bao_jsc.*
import bao_simdutf_sys.simdutf

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
    //   pub fn encode(&self, global, frame) -> JsResult<JSValue>
    // ========================================================================

    /// 编码一个字符串块
    /// 对应 Bun: pub fn encode(&self, global, frame) -> JsResult<JSValue>
    ///
    /// 步骤:
    ///   1. 从参数获取 JSString
    ///   2. 检查是否是 16-bit 字符串 (UTF-16)
    ///   3. 16-bit: 调用 encodeUtf16
    ///   4. 8-bit: 调用 encodeLatin1
    public func encode(global: JSGlobalObject, frame: CallFrame): Result<JSValue> {
        let arguments = frame.arguments(1)
        if (arguments.isEmpty()) {
            return Result<JSValue>.Err(
                BaoError(ErrorCode.MissingArgs, "TextEncoderStreamEncoder.encode requires 1 argument")
            )
        }

        let str = arguments[0].getZigString(global)
        match (str) {
            case Ok(jsStr) => {
                if (jsStr.is16Bit()) {
                    return Result<JSValue>.Ok(encodeUtf16(global, jsStr.utf16SliceAligned()))
                }
                return Result<JSValue>.Ok(encodeLatin1(global, jsStr.slice()))
            }
            case Err(e) => return Result<JSValue>.Err(e)
        }
    }

    /// 无类型检查的编码
    /// 对应 Bun: pub fn encode_without_type_checks(&self, global, input) -> JSValue
    public func encodeWithoutTypeChecks(global: JSGlobalObject, input: JSString): JSValue {
        let str = input.getZigString(global)
        if (str.is16Bit()) {
            return encodeUtf16(global, str.utf16SliceAligned())
        }
        return encodeLatin1(global, str.slice())
    }

    // ========================================================================
    // encodeLatin1 - Latin1 -> UTF-8 编码
    // 严格翻译自: TextEncoderStreamEncoder::encode_latin1
    //   fn encode_latin1(&self, global, input: &[u8]) -> JSValue
    // ========================================================================

    /// Latin1 -> UTF-8 编码
    /// 对应 Bun: fn encode_latin1(&self, global, input: &[u8]) -> JSValue
    ///
    /// 步骤:
    ///   1. 处理暂存的 lead surrogate (latin1 无代理对, 输出 U+FFFD)
    ///   2. 分配输出缓冲区 (input.len + prepend_replacement_len)
    ///   3. 使用 copy_latin1_into_utf8 逐块转换
    ///   4. 返回 Uint8Array
    private func encodeLatin1(global: JSGlobalObject, input: Array<UInt8>): JSValue {
        if (input.size == 0) {
            return JSUint8Array.createEmpty(global)
        }

        // 处理暂存的 lead surrogate
        let prependReplacementLen: Int64 = match (pendingLeadSurrogate) {
            case Some(_) => {
                pendingLeadSurrogate = None
                3  // U+FFFD = EF BF BD
            }
            case None => 0
        }

        // 分配输出缓冲区
        var buffer = Array<UInt8>()
        buffer.reserve(input.size + prependReplacementLen)

        if (prependReplacementLen > 0) {
            buffer.append(0xef)
            buffer.append(0xbf)
            buffer.append(0xbd)
        }

        // Latin1 -> UTF-8 转换
        var remain = input
        while (remain.size > 0) {
            let result = Strings.copyLatin1IntoUtf8(buffer, remain)
            // result.written: 写入的 UTF-8 字节数
            // result.read: 消耗的 Latin1 字节数
            if (result.written == 0 && result.read == 0) {
                buffer.reserve(buffer.size + 2)
            } else if (buffer.size == buffer.capacity() && remain.size > result.read) {
                buffer.reserve(buffer.size + remain.size - result.read + 1)
            }
            remain = remain.slice(Int64(result.read))
        }

        return JSUint8Array.fromBytes(global, buffer)
    }

    // ========================================================================
    // encodeUtf16 - UTF-16 -> UTF-8 编码
    // 严格翻译自: TextEncoderStreamEncoder::encode_utf16
    //   fn encode_utf16(&self, global, input: &[u16]) -> JSValue
    // ========================================================================

    /// UTF-16 -> UTF-8 编码
    /// 对应 Bun: fn encode_utf16(&self, global, input: &[u16]) -> JSValue
    ///
    /// 步骤:
    ///   1. 处理暂存的 lead surrogate (与 trail 配对或输出 U+FFFD)
    ///   2. 使用 simdutf 计算 UTF-8 长度
    ///   3. 尝试 simdutf 快速转换
    ///   4. 失败则走慢路径 (包含无效 UTF-16 处理)
    ///   5. 检查最后是否留下新的 lead surrogate
    private func encodeUtf16(global: JSGlobalObject, input: Array<UInt16>): JSValue {
        if (input.size == 0) {
            return JSUint8Array.createEmpty(global)
        }

        var remain = input

        // 处理暂存的 lead surrogate
        var prepend: ?Array<UInt8> = None
        match (pendingLeadSurrogate) {
            case Some(lead) => {
                pendingLeadSurrogate = None
                if (input.size > 0) {
                    let maybeTrail = input[0]
                    if (Strings.u16IsTrail(maybeTrail)) {
                        // 配对成功: 转换代理对
                        let converted = Strings.utf16CodepointWithFffd(lead, maybeTrail)
                        let sequence = Strings.wtf8Sequence(converted.codePoint)
                        remain = input.slice(1)
                        if (remain.size == 0) {
                            return JSUint8Array.fromBytesCopy(global, sequence.slice(0, Int64(converted.utf8Width)))
                        }
                        prepend = sequence.slice(0, Int64(converted.utf8Width))
                    } else {
                        // 未配对: U+FFFD
                        let replacement: Array<UInt8> = [0xef, 0xbf, 0xbd]
                        prepend = replacement
                    }
                } else {
                    // 输入为空但有 lead surrogate — 不应该到这里
                    let replacement: Array<UInt8> = [0xef, 0xbf, 0xbd]
                    prepend = replacement
                }
            }
            case None => ()
        }

        // 计算输出长度
        let length = SimdUtf.lengthUtf8FromUtf16Le(remain)

        var prependLen: Int64 = 0
        match (prepend) {
            Some(pre) => prependLen = pre.size
            None => ()
        }

        // 分配输出缓冲区
        var buf = Array<UInt8>()
        buf.reserve(length + prependLen)

        match (prepend) {
            case Some(pre) => {
                for (b in pre) {
                    buf.append(b)
                }
            }
            case None => ()
        }

        // 尝试 simdutf 快速转换
        let result = SimdUtf.convertUtf16ToUtf8Le(remain, buf)
        if (result.status == SimdUtfStatus.SUCCESS) {
            return JSUint8Array.fromBytes(global, buf)
        }

        // 慢路径: 有无效 UTF-16, 使用手动转换
        let leadSurrogate = Strings.toUtf8ListWithTypeBun(buf, remain)
        match (leadSurrogate) {
            case Some(pendingLead) => {
                pendingLeadSurrogate = pendingLead
                if (buf.size == 0) {
                    return JSUint8Array.createEmpty(global)
                }
            }
            case None => ()
        }

        return JSUint8Array.fromBytes(global, buf)
    }

    // ========================================================================
    // flush - 刷新
    // 严格翻译自: TextEncoderStreamEncoder::flush
    //   pub fn flush(&self, global, _frame) -> JsResult<JSValue>
    // ========================================================================

    /// 刷新并完成编码
    /// 对应 Bun: pub fn flush(&self, global, _frame) -> JsResult<JSValue>
    ///
    /// 如果有暂存的 lead surrogate, 输出 U+FFFD 替换。
    public func flush(global: JSGlobalObject, frame: CallFrame): Result<JSValue> {
        return Result<JSValue>.Ok(flushBody(global))
    }

    /// 无类型检查的 flush
    /// 对应 Bun: pub fn flush_without_type_checks(&self, global) -> JSValue
    public func flushWithoutTypeChecks(global: JSGlobalObject): JSValue {
        return flushBody(global)
    }

    /// flush 内部实现
    /// 对应 Bun: fn flush_body(&self, global) -> JSValue
    ///   如果 pending_lead_surrogate 是 None, 返回空 Uint8Array
    ///   否则返回 U+FFFD (EF BF BD)
    private func flushBody(global: JSGlobalObject): JSValue {
        match (pendingLeadSurrogate) {
            case Some(_) => {
                pendingLeadSurrogate = None
                let replacement: Array<UInt8> = [0xef, 0xbf, 0xbd]
                return JSUint8Array.fromBytesCopy(global, replacement)
            }
            case None => {
                return JSUint8Array.createEmpty(global)
            }
        }
    }
}
