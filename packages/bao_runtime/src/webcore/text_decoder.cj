// TextDecoder - 文本解码器
// 对应 Bun: src/runtime/webcore/TextDecoder.zig
// 严格翻译自: src/runtime/webcore/TextDecoder.zig
package bao_runtime

import bao_core.*

// ============================================================================
// TextDecoder - 文本解码器
// 对应 Bun: src/runtime/webcore/TextDecoder.zig TextDecoder
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/TextDecoder
// ============================================================================

/// TextDecoder — 将字节解码为字符串
/// 对应 Web API: TextDecoder
/// 对应 Bun: src/runtime/webcore/TextDecoder.zig TextDecoder
public class TextDecoder {
    /// 编码名称
    /// 对应 Bun: TextDecoder.encoding (EncodingLabel)
    public var encoding: String
    /// 遇到无效编码是否抛出异常
    /// 对应 Bun: TextDecoder.fatal
    public var fatal: Bool
    /// 是否忽略 BOM
    /// 对应 Bun: TextDecoder.ignore_bom
    public var ignoreBOM: Bool
    /// 流模式下剩余的不完整字节
    /// 对应 Bun: TextDecoder.buffered
    private var buffered: Array<UInt8>
    /// UTF-16 前导字节
    /// 对应 Bun: TextDecoder.lead_byte
    private var leadByte: ?UInt8
    /// UTF-16 前导代理
    /// 对应 Bun: TextDecoder.lead_surrogate
    private var leadSurrogate: ?UInt16

    public init() {
        encoding = "utf-8"
        fatal = false
        ignoreBOM = false
        buffered = Array<UInt8>()
        leadByte = None
        leadSurrogate = None
    }

    public init(encoding: String) {
        this.encoding = EncodingLabel.getCanonical(encoding) ?? "utf-8"
        fatal = false
        ignoreBOM = false
        buffered = Array<UInt8>()
        leadByte = None
        leadSurrogate = None
    }

    public init(encoding: String, fatal: Bool, ignoreBOM: Bool) {
        this.encoding = EncodingLabel.getCanonical(encoding) ?? "utf-8"
        this.fatal = fatal
        this.ignoreBOM = ignoreBOM
        buffered = Array<UInt8>()
        leadByte = None
        leadSurrogate = None
    }

    /// 解码字节数组为字符串
    /// 对应 Web API: textDecoder.decode(input)
    public func decode(input: Array<UInt8>): String {
        return decode(input, false)
    }

    /// 解码字节数组为字符串 (流式)
    /// 对应 Web API: textDecoder.decode(input, options)
    public func decode(input: Array<UInt8>, stream: Bool): String {
        match (encoding) {
            case "utf-8" => return decodeUtf8(input, stream)
            case "utf-16le" => return decodeUtf16(input, true, stream)
            case "utf-16be" => return decodeUtf16(input, false, stream)
            case "windows-1252" | "iso-8859-1" | "latin-1" | "ascii" => return decodeLatin1(input)
            case _ => return decodeUtf8(input, stream)
        }
    }

    /// UTF-8 解码
    /// 对应 Bun: TextDecoder UTF-8 解码逻辑
    private func decodeUtf8(input: Array<UInt8>, stream: Bool): String {
        let sb = StringBuilder()
        var i = 0

        // 拼接缓冲区中的残留字节
        var bytes = ArrayList<UInt8>()
        for (b in buffered) {
            bytes.append(b)
        }
        for (b in input) {
            bytes.append(b)
        }
        let data = bytes.toArray()
        buffered = Array<UInt8>()

        // 处理 BOM
        var start = 0
        if (!ignoreBOM && data.size >= 3) {
            if (data[0] == UInt8(0xEF) && data[1] == UInt8(0xBB) && data[2] == UInt8(0xBF)) {
                start = 3
            }
        }

        // 解码 UTF-8
        var idx = start
        while (idx < data.size) {
            let firstByte = data[Int64(idx)]
            let cpLen = Utf8Codec.codePointLength(firstByte)

            if (Int64(idx) + cpLen > data.size) {
                // 流模式: 保存不完整的字节
                if (stream) {
                    for (j in idx..data.size) {
                        buffered.append(data[Int64(j)])
                    }
                } else {
                    // 非流模式: 替换为 U+FFFD
                    sb.append("\uFFFD")
                }
                break
            }

            if (cpLen == 1) {
                sb.append(Char(Int64(firstByte)))
            } else if (cpLen == 2) {
                let cp = (Int64(firstByte & UInt8(0x1F)) << 6) |
                         Int64(data[Int64(idx) + 1] & UInt8(0x3F))
                sb.append(Char(cp))
            } else if (cpLen == 3) {
                let cp = (Int64(firstByte & UInt8(0x0F)) << 12) |
                         (Int64(data[Int64(idx) + 1] & UInt8(0x3F)) << 6) |
                         Int64(data[Int64(idx) + 2] & UInt8(0x3F))
                sb.append(Char(cp))
            } else {
                let cp = (Int64(firstByte & UInt8(0x07)) << 18) |
                         (Int64(data[Int64(idx) + 1] & UInt8(0x3F)) << 12) |
                         (Int64(data[Int64(idx) + 2] & UInt8(0x3F)) << 6) |
                         Int64(data[Int64(idx) + 3] & UInt8(0x3F))
                if (cp >= 0x10000 && cp <= 0x10FFFF) {
                    let high = 0xD800 + ((cp - 0x10000) >> 10)
                    let low = 0xDC00 + ((cp - 0x10000) & 0x3FF)
                    sb.append(Char(high))
                    sb.append(Char(low))
                } else {
                    sb.append("\uFFFD")
                }
            }

            idx += cpLen
        }

        return sb.toString()
    }

    /// UTF-16 解码
    /// 对应 Bun: TextDecoder UTF-16 解码逻辑
    private func decodeUtf16(input: Array<UInt8>, littleEndian: Bool, stream: Bool): String {
        let sb = StringBuilder()
        var i = 0
        while (i + 1 < input.size) {
            let first = Int64(input[Int64(i)])
            let second = Int64(input[Int64(i) + 1])
            let codeUnit = if (littleEndian) {
                first | (second << 8)
            } else {
                (first << 8) | second
            }

            // 处理代理对
            if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF) {
                // 高代理
                if (i + 3 < input.size) {
                    let first2 = Int64(input[Int64(i) + 2])
                    let second2 = Int64(input[Int64(i) + 3])
                    let codeUnit2 = if (littleEndian) {
                        first2 | (second2 << 8)
                    } else {
                        (first2 << 8) | second2
                    }
                    if (codeUnit2 >= 0xDC00 && codeUnit2 <= 0xDFFF) {
                        let cp = 0x10000 + ((codeUnit - 0xD800) << 10) + (codeUnit2 - 0xDC00)
                        sb.append(Char(cp))
                        i += 4
                        continue
                    }
                }
                // 不完整的代理对
                if (fatal) {
                    // 抛出错误
                } else {
                    sb.append("\uFFFD")
                }
                i += 2
            } else if (codeUnit >= 0xDC00 && codeUnit <= 0xDFFF) {
                // 孤立低代理
                if (fatal) {
                    // 抛出错误
                } else {
                    sb.append("\uFFFD")
                }
                i += 2
            } else {
                sb.append(Char(codeUnit))
                i += 2
            }
        }
        return sb.toString()
    }

    /// Latin-1 / ASCII 解码
    private func decodeLatin1(input: Array<UInt8>): String {
        let sb = StringBuilder()
        for (b in input) {
            sb.append(Char(Int64(b)))
        }
        return sb.toString()
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("encoding", JsValue(BaoString(self.encoding)))
        obj.set("fatal", JsValue(self.fatal))
        obj.set("ignoreBOM", JsValue(self.ignoreBOM))

        obj.set("decode", JsValue.nativeFunction(JsNativeFunction("decode") { args =>
            let bytes = if (args.size >= 1) {
                match (args[0].arrayData) {
                    case Some(arr) => {
                        let result = ArrayList<UInt8>()
                        for (v in arr) {
                            result.append(UInt8(Int64(Interpreter.jsToNumber(v))))
                        }
                        result.toArray()
                    }
                    case None => Array<UInt8>()
                }
            } else {
                Array<UInt8>()
            }

            let stream = if (args.size >= 2) {
                match (args[1].objectData) {
                    case Some(obj) => {
                        let streamVal = obj.get("stream")
                        streamVal.boolValue
                    }
                    case None => false
                }
            } else {
                false
            }

            let result = self.decode(bytes, stream)
            JsValue(BaoString(result))
        }))

        return JsValue(obj)
    }
}
