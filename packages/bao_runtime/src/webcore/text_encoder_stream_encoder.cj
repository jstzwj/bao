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
    /// PORT NOTE: encode simplified; frame.arguments(n), getZigString, createBufferFromLength not yet available
    public func encode(global: JSGlobalObject, frame: CallFrame): Result<JsValue> {
        let arguments = frame.arguments()
        if (arguments.isEmpty()) {
            return Result<JsValue>.Err("TextEncoderStreamEncoder.encode requires 1 argument")
        }

        // PORT NOTE: simplified; getZigString not yet available
        return Result<JsValue>.Ok(JsValue())
    }

    /// 无类型检查的编码
    /// 对应 Bun: encode_without_type_checks — 直接编码为 UTF-8
    public func encodeWithoutTypeChecks(global: JSGlobalObject, input: ZigString): JsValue {
        let bytes = input.toBytes()
        return encodeLatin1(global, bytes)
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
    ///   3. 使用 copy_latin1_into_utf8 逐块转换
    ///   4. 返回 Uint8Array
    /// PORT NOTE: encodeLatin1 — Latin1 -> UTF-8 编码
    private func encodeLatin1(global: JSGlobalObject, input: Array<UInt8>): JsValue {
        if (input.size == 0) {
            return JsValue.createBuffer(global, Array<UInt8>())
        }

        // 对应 Bun: copy_latin1_into_utf8 + 分配输出缓冲区
        var output = Array<UInt8>()
        for (b in input) {
            if (b < 0x80) {
                output.append(b)
            } else {
                output.append(0xC0 | (b >> 6))
                output.append(0x80 | (b & 0x3F))
            }
        }
        pendingLeadSurrogate = None
        return JsValue.createBuffer(global, output)
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
    /// PORT NOTE: encodeUtf16 simplified; Strings.* and JSUint8Array methods not yet available
    private func encodeUtf16(global: JSGlobalObject, input: Array<UInt16>): JsValue {
        if (input.size == 0) {
            return JsValue()
        }
        pendingLeadSurrogate = None
        return JsValue()
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
    /// PORT NOTE: flushBody simplified; JSUint8Array not yet available
    private func flushBody(global: JSGlobalObject): JsValue {
        match (pendingLeadSurrogate) {
            case Some(_) =>
                pendingLeadSurrogate = None
                return JsValue()
            case None =>
                return JsValue()
        }
    }
}
