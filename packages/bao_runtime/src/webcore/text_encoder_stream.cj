// TextEncoderStreamEncoder - 文本编码流
// 对应 Bun: src/runtime/webcore/TextEncoderStreamEncoder.zig
// 严格翻译自: src/runtime/webcore/TextEncoderStreamEncoder.zig
package bao_runtime

import bao_core.*

// ============================================================================
// TextEncoderStreamEncoder - 文本编码流编码器
// 对应 Bun: src/runtime/webcore/TextEncoderStreamEncoder.zig
// ============================================================================

/// TextEncoderStreamEncoder — TextEncoderStream 的内部编码器
/// 对应 Bun: src/runtime/webcore/TextEncoderStreamEncoder.zig
public class TextEncoderStreamEncoder {
    /// 编码器状态
    public var encoding: String
    /// 是否已完成
    public var done: Bool

    public init() {
        encoding = "utf-8"
        done = false
    }

    /// 编码一个字符串块
    /// 对应 Bun: TextEncoderStreamEncoder.encode()
    public func encode(chunk: String): Array<UInt8> {
        if (done) {
            return Array<UInt8>()
        }
        return Utf8Codec.encode(chunk)
    }

    /// 刷新并完成编码
    /// 对应 Bun: TextEncoderStreamEncoder.flush()
    public func flush(): Array<UInt8> {
        done = true
        return Array<UInt8>()
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("encoding", JsValue(BaoString(self.encoding)))

        obj.set("encode", JsValue.nativeFunction(JsNativeFunction("encode") { args =>
            let text = if (args.size >= 1) { Interpreter.jsToString(args[0]) } else { "" }
            let bytes = self.encode(text)
            let arr = ArrayList<JsValue>()
            for (b in bytes) {
                arr.append(JsValue(Float64(Int64(b))))
            }
            JsValue.array(arr)
        }))

        return JsValue(obj)
    }
}
