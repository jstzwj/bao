// TextEncoder - 文本编码器
// 对应 Bun: src/runtime/webcore/TextEncoder.zig
// 严格翻译自: src/runtime/webcore/TextEncoder.zig
package bao_runtime

import bao_core.*

// ============================================================================
// TextEncoder - UTF-8 编码器
// 对应 Bun: src/runtime/webcore/TextEncoder.zig TextEncoder
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/TextEncoder
// ============================================================================

/// TextEncoder — 将字符串编码为 UTF-8 字节
/// 对应 Web API: TextEncoder
/// 对应 Bun: src/runtime/webcore/TextEncoder.zig TextEncoder
public class TextEncoder {
    /// 编码名称，始终为 "utf-8"
    public var encoding: String

    public init() {
        encoding = "utf-8"
    }

    /// 将字符串编码为 UTF-8 字节数组
    /// 对应 Web API: textEncoder.encode(text)
    /// 对应 Bun: TextEncoder__encode8 / TextEncoder__encode16
    public func encode(text: String): Array<UInt8> {
        return Utf8Codec.encode(text)
    }

    /// 将字符串编码到目标数组中
    /// 对应 Web API: textEncoder.encodeInto(src, dest)
    public func encodeInto(src: String, dest: Array<UInt8>): EncodeIntoResult {
        let result = EncodeIntoResult()
        var byteIndex = 0
        let destCapacity = dest.size

        for (i in 0..src.length) {
            let codePoint = Int64(src[Int64(i)])
            let byteLen = Utf8Codec.codePointLength(UInt8(codePoint & 0xFF))

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

    /// 编码 Latin1 字符串 (8-bit)
    /// 对应 Bun: TextEncoder__encode8
    public func encode8(text: String): Array<UInt8> {
        let result = ArrayList<UInt8>()
        for (i in 0..text.length) {
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
        return result.toArray()
    }

    /// 编码 UTF-16 字符串
    /// 对应 Bun: TextEncoder__encode16
    public func encode16(text: String): Array<UInt8> {
        return Utf8Codec.encode(text)
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

        obj.set("encodeInto", JsValue.nativeFunction(JsNativeFunction("encodeInto") { args =>
            if (args.size >= 1) {
                let text = Interpreter.jsToString(args[0])
                let bytes = self.encode(text)
                let result = EncodeIntoResult(0, bytes.size)
                result.read = text.length
                return result.toJsValue()
            }
            EncodeIntoResult().toJsValue()
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// EncodeIntoResult — encodeInto 返回值
// 对应 Bun: TextEncoder.encodeInto result
// ============================================================================

/// TextEncoder.encodeInto() 的返回结果
public class EncodeIntoResult {
    /// 已读取的 UTF-16 code unit 数量
    public var read: Int64
    /// 已写入的 UTF-8 byte 数量
    public var written: Int64

    public init() {
        read = 0
        written = 0
    }

    public init(read: Int64, written: Int64) {
        this.read = read
        this.written = written
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("read", JsValue(Float64(read)))
        obj.set("written", JsValue(Float64(written)))
        return JsValue(obj)
    }
}
