// Web API TextEncoder / TextDecoder
// 对应 Bun: src/runtime/api/text_encoder.zig
// 严格翻译自: src/api/text_encoder.zig
package bao_runtime

import bao_core.*
import bao_collections.*

// ============================================================================
// EncodeIntoResult — encodeInto 返回值
// 对应 Bun: src/api/text_encoder.zig EncodeIntoResult
// ============================================================================

/// TextEncoder.encodeInto() 的返回结果
/// 对应 Web API: EncodeIntoResult
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

// ============================================================================
// TextEncoder — UTF-8 编码器
// 对应 Bun: src/api/text_encoder.zig TextEncoder
// ============================================================================

/// TextEncoder — 将字符串编码为 UTF-8 字节
/// 对应 Web API: TextEncoder
/// 对应 Bun: src/api/text_encoder.zig TextEncoder
public class TextEncoder {
    /// 编码名称，始终为 "utf-8"
    public var encoding: String

    public init() {
        encoding = "utf-8"
    }

    /// 将字符串编码为 UTF-8 字节数组
    /// 对应 Web API: textEncoder.encode(text)
    public func encode(text: String): Array<UInt8> {
        return Utf8Codec.encode(text)
    }

    /// 将字符串编码到目标数组中
    /// 对应 Web API: textEncoder.encodeInto(src, dest)
    /// 返回 EncodeIntoResult 包含已读取/已写入的数量
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

            // 编码 UTF-8 字节
            if (codePoint < 0x80) {
                // 1-byte: 0xxxxxxx
                dest[byteIndex] = UInt8(codePoint)
                byteIndex += 1
            } else if (codePoint < 0x800) {
                // 2-byte: 110xxxxx 10xxxxxx
                dest[byteIndex] = UInt8(0xC0 | (codePoint >> 6))
                dest[byteIndex + 1] = UInt8(0x80 | (codePoint & 0x3F))
                byteIndex += 2
            } else if (codePoint < 0x10000) {
                // 3-byte: 1110xxxx 10xxxxxx 10xxxxxx
                dest[byteIndex] = UInt8(0xE0 | (codePoint >> 12))
                dest[byteIndex + 1] = UInt8(0x80 | ((codePoint >> 6) & 0x3F))
                dest[byteIndex + 2] = UInt8(0x80 | (codePoint & 0x3F))
                byteIndex += 3
            } else {
                // 4-byte: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
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
            return JsValue.array(arr)
        }))

        obj.set("encodeInto", JsValue.nativeFunction(JsNativeFunction("encodeInto") { args =>
            // 简化: 需要传入 src 和 Uint8Array dest
            if (args.size >= 1) {
                let text = Interpreter.jsToString(args[0])
                let bytes = self.encode(text)
                let result = EncodeIntoResult(0, bytes.size)
                result.read = text.length
                return result.toJsValue()
            }
            return EncodeIntoResult().toJsValue()
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// TextDecoderOptions — TextDecoder 构造选项
// ============================================================================

/// TextDecoder 构造选项
/// 对应 Web API: TextDecoderOptions
public class TextDecoderOptions {
    /// 是否在遇到无效编码时抛出异常
    public var fatal: Bool
    /// 是否忽略 BOM (Byte Order Mark)
    public var ignoreBOM: Bool

    public init() {
        fatal = false
        ignoreBOM = false
    }

    public init(fatal: Bool, ignoreBOM: Bool) {
        this.fatal = fatal
        this.ignoreBOM = ignoreBOM
    }
}

// ============================================================================
// TextDecodeOptions — TextDecoder.decode() 选项
// ============================================================================

/// TextDecoder.decode() 的选项
/// 对应 Web API: TextDecodeOptions
public class TextDecodeOptions {
    /// 是否以流模式解码 (允许多次调用 decode 处理分块数据)
    public var stream: Bool

    public init() {
        stream = false
    }

    public init(stream: Bool) {
        this.stream = stream
    }
}

// ============================================================================
// TextDecoder — 文本解码器
// 对应 Bun: src/api/text_encoder.zig TextDecoder
// ============================================================================

/// TextDecoder — 将字节解码为字符串
/// 对应 Web API: TextDecoder
/// 对应 Bun: src/api/text_encoder.zig TextDecoder
public class TextDecoder {
    /// 编码名称 (utf-8, utf-16le, utf-16be 等)
    public var encoding: String
    /// 遇到无效编码是否抛出异常
    public var fatal: Bool
    /// 是否忽略 BOM
    public var ignoreBOM: Bool
    /// 流模式下剩余的不完整字节
    private var pendingBytes: ArrayList<UInt8>

    public init() {
        encoding = "utf-8"
        fatal = false
        ignoreBOM = false
        pendingBytes = ArrayList<UInt8>()
    }

    public init(encoding: String) {
        this.encoding = normalizeEncoding(encoding)
        this.fatal = false
        this.ignoreBOM = false
        pendingBytes = ArrayList<UInt8>()
    }

    public init(encoding: String, options: TextDecoderOptions) {
        this.encoding = normalizeEncoding(encoding)
        this.fatal = options.fatal
        this.ignoreBOM = options.ignoreBOM
        pendingBytes = ArrayList<UInt8>()
    }

    /// 解码字节数组为字符串
    /// 对应 Web API: textDecoder.decode(input)
    public func decode(input: Array<UInt8>): String {
        return decode(input, TextDecodeOptions())
    }

    /// 解码字节数组为字符串 (带选项)
    /// 对应 Web API: textDecoder.decode(input, options)
    public func decode(input: Array<UInt8>, options: TextDecodeOptions): String {
        match (encoding) {
            case "utf-8" => return decodeUtf8(input, options)
            case "utf-16le" => return decodeUtf16(input, true)
            case "utf-16be" => return decodeUtf16(input, false)
            case "iso-8859-1" | "latin-1" | "ascii" => return decodeLatin1(input)
            case _ => return decodeUtf8(input, options)  // 默认使用 UTF-8
        }
    }

    /// UTF-8 解码
    private func decodeUtf8(input: Array<UInt8>, options: TextDecodeOptions): String {
        var bytes = ArrayList<UInt8>()

        // 流模式: 拼接上次剩余的字节
        if (options.stream && pendingBytes.size > 0) {
            for (b in pendingBytes) {
                bytes.append(b)
            }
            pendingBytes.clear()
        }

        for (b in input) {
            bytes.append(b)
        }

        let arr = bytes.toArray()

        // 处理 BOM
        var start = 0
        if (!ignoreBOM && arr.size >= 3) {
            if (arr[0] == UInt8(0xEF) && arr[1] == UInt8(0xBB) && arr[2] == UInt8(0xBF)) {
                start = 3
            }
        }

        // 流模式下: 保留末尾不完整的字节序列
        if (options.stream && arr.size > start) {
            var lastCompleteEnd = arr.size
            // 检查最后一个字符是否完整
            let lastByte = arr[arr.size - 1]
            // 如果以多字节序列的起始字节结尾，说明不完整
            if (lastByte >= UInt8(0xC0) && lastByte < UInt8(0xFE)) {
                lastCompleteEnd = arr.size - 1
            } else if (arr.size >= 2) {
                let secondLast = arr[arr.size - 2]
                if (secondLast >= UInt8(0xE0) && secondLast < UInt8(0xF0) &&
                    (lastByte >= UInt8(0x80) && lastByte < UInt8(0xC0))) {
                    // 3 字节序列只完成了 2 字节
                    lastCompleteEnd = arr.size - 2
                }
            }

            if (lastCompleteEnd < arr.size) {
                for (i in lastCompleteEnd..arr.size) {
                    pendingBytes.append(arr[Int64(i)])
                }
            }

            return Utf8Codec.decode(arr, Int64(start), Int64(lastCompleteEnd - start))
        }

        return Utf8Codec.decode(arr, Int64(start), Int64(arr.size - start))
    }

    /// UTF-16 解码 (LE 或 BE)
    private func decodeUtf16(input: Array<UInt8>, littleEndian: Bool): String {
        let sb = StringBuilder()
        var i = 0
        while (i + 1 < input.size) {
            let lo = Int64(input[Int64(i)])
            let hi = Int64(input[Int64(i + 1)])
            let codeUnit = if (littleEndian) {
                lo | (hi << 8)
            } else {
                hi | (lo << 8)
            }
            sb.append(Char(codeUnit))
            i += 2
        }
        return sb.toString()
    }

    /// Latin-1 / ASCII 解码 (每字节直接映射到字符)
    private func decodeLatin1(input: Array<UInt8>): String {
        let sb = StringBuilder()
        for (b in input) {
            sb.append(Char(Int64(b)))
        }
        return sb.toString()
    }

    /// 规范化编码名称
    private static func normalizeEncoding(name: String): String {
        let lower = name.toLowerCase()
        // 处理常见别名
        if (lower == "utf-8" || lower == "utf8") { return "utf-8" }
        if (lower == "utf-16le" || lower == "utf-16-le" || lower == "utf16le") { return "utf-16le" }
        if (lower == "utf-16be" || lower == "utf-16-be" || lower == "utf16be") { return "utf-16be" }
        if (lower == "iso-8859-1" || lower == "iso8859-1" || lower == "iso_8859_1") { return "iso-8859-1" }
        if (lower == "latin1" || lower == "latin-1" || lower == "l1") { return "latin-1" }
        if (lower == "ascii" || lower == "us-ascii") { return "ascii" }
        return lower
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
                // 从 JsValue 中提取字节数组
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

            let opts = TextDecodeOptions()
            if (args.size >= 2) {
                match (args[1].objectData) {
                    case Some(obj) => {
                        let stream = obj.get("stream")
                        if (stream.valueType == JsValueType.Boolean) {
                            opts.stream = stream.boolValue
                        }
                    }
                    case None => ()
                }
            }

            let result = self.decode(bytes, opts)
            return JsValue(BaoString(result))
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// Utf8Codec — UTF-8 编解码器
// 对应 Bun: src/api/text_encoder.zig Utf8Codec
// ============================================================================

/// UTF-8 编解码工具
/// 对应 Bun: src/api/text_encoder.zig 中 UTF-8 编解码实现
public class Utf8Codec {
    /// 将字符串编码为 UTF-8 字节数组
    /// 对应 Bun: bun.strings.encodeUtf8
    public static func encode(text: String): Array<UInt8> {
        let bytes = ArrayList<UInt8>()
        for (i in 0..text.length) {
            let codePoint = Int64(text[Int64(i)])

            if (codePoint < 0x80) {
                // 1-byte: 0xxxxxxx (ASCII)
                bytes.append(UInt8(codePoint))
            } else if (codePoint < 0x800) {
                // 2-byte: 110xxxxx 10xxxxxx
                bytes.append(UInt8(0xC0 | (codePoint >> 6)))
                bytes.append(UInt8(0x80 | (codePoint & 0x3F)))
            } else if (codePoint < 0x10000) {
                // 3-byte: 1110xxxx 10xxxxxx 10xxxxxx
                bytes.append(UInt8(0xE0 | (codePoint >> 12)))
                bytes.append(UInt8(0x80 | ((codePoint >> 6) & 0x3F)))
                bytes.append(UInt8(0x80 | (codePoint & 0x3F)))
            } else {
                // 4-byte: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
                bytes.append(UInt8(0xF0 | (codePoint >> 18)))
                bytes.append(UInt8(0x80 | ((codePoint >> 12) & 0x3F)))
                bytes.append(UInt8(0x80 | ((codePoint >> 6) & 0x3F)))
                bytes.append(UInt8(0x80 | (codePoint & 0x3F)))
            }
        }
        return bytes.toArray()
    }

    /// 将 UTF-8 字节数组解码为字符串
    /// 对应 Bun: bun.strings.decodeUtf8
    public static func decode(bytes: Array<UInt8>): String {
        return decode(bytes, 0, bytes.size)
    }

    /// 将 UTF-8 字节数组的子范围解码为字符串
    /// 对应 Bun: bun.strings.decodeUtf8WithOffset
    public static func decode(bytes: Array<UInt8>, offset: Int64, length: Int64): String {
        let sb = StringBuilder()
        var i = offset
        let end = offset + length

        while (i < end) {
            let firstByte = bytes[i]
            let cpLen = codePointLength(firstByte)

            if (i + cpLen > end) {
                // 不完整的序列，替换为 U+FFFD
                sb.append("\uFFFD")
                i += 1
                continue
            }

            if (cpLen == 1) {
                // ASCII: 0xxxxxxx
                sb.append(Char(Int64(firstByte)))
                i += 1
            } else if (cpLen == 2) {
                // 2-byte: 110xxxxx 10xxxxxx
                let cp = (Int64(firstByte & UInt8(0x1F)) << 6) |
                         Int64(bytes[Int64(i) + 1] & UInt8(0x3F))
                sb.append(Char(cp))
                i += 2
            } else if (cpLen == 3) {
                // 3-byte: 1110xxxx 10xxxxxx 10xxxxxx
                let cp = (Int64(firstByte & UInt8(0x0F)) << 12) |
                         (Int64(bytes[Int64(i) + 1] & UInt8(0x3F)) << 6) |
                         Int64(bytes[Int64(i) + 2] & UInt8(0x3F))
                sb.append(Char(cp))
                i += 3
            } else {
                // 4-byte: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
                let cp = (Int64(firstByte & UInt8(0x07)) << 18) |
                         (Int64(bytes[Int64(i) + 1] & UInt8(0x3F)) << 12) |
                         (Int64(bytes[Int64(i) + 2] & UInt8(0x3F)) << 6) |
                         Int64(bytes[Int64(i) + 3] & UInt8(0x3F))
                // 超出 BMP 的字符需要 surrogate pair
                if (cp > 0x10FFFF) {
                    sb.append("\uFFFD")
                } else if (cp >= 0x10000) {
                    // 代理对编码
                    let high = 0xD800 + ((cp - 0x10000) >> 10)
                    let low = 0xDC00 + ((cp - 0x10000) & 0x3FF)
                    sb.append(Char(high))
                    sb.append(Char(low))
                } else {
                    sb.append(Char(cp))
                }
                i += 4
            }
        }

        return sb.toString()
    }

    /// 根据 UTF-8 首字节计算 code point 长度
    /// 对应 Bun: bun.strings.utf8CodePointLength
    public static func codePointLength(firstByte: UInt8): Int64 {
        if (firstByte < UInt8(0x80)) {
            return 1  // 0xxxxxxx
        } else if (firstByte < UInt8(0xE0)) {
            return 2  // 110xxxxx
        } else if (firstByte < UInt8(0xF0)) {
            return 3  // 1110xxxx
        } else if (firstByte < UInt8(0xF8)) {
            return 4  // 11110xxx
        } else {
            return 1  // 非法字节，当作 1 字节处理
        }
    }

    /// 检查字节数组是否为合法的 UTF-8 编码
    /// 对应 Bun: bun.strings.isValidUtf8
    public static func isValidUtf8(bytes: Array<UInt8>): Bool {
        var i = 0
        while (i < bytes.size) {
            let firstByte = bytes[Int64(i)]
            let cpLen = codePointLength(firstByte)

            // 检查长度是否越界
            if (Int64(i) + cpLen > bytes.size) {
                return false
            }

            if (cpLen == 1) {
                // ASCII 范围检查
                if (firstByte >= UInt8(0x80)) {
                    return false
                }
            } else {
                // 检查首字节合法性
                if (cpLen == 2 && firstByte < UInt8(0xC2)) {
                    return false  // 过长编码: C0, C1 非法
                }

                // 检查后续字节是否为 10xxxxxx
                for (j in 1..cpLen) {
                    let b = bytes[Int64(i) + Int64(j)]
                    if (b < UInt8(0x80) || b >= UInt8(0xC0)) {
                        return false
                    }
                }

                // 检查是否为代理对范围 (非法 UTF-8)
                if (cpLen == 3) {
                    let cp = (Int64(firstByte & UInt8(0x0F)) << 12) |
                             (Int64(bytes[Int64(i) + 1] & UInt8(0x3F)) << 6) |
                             Int64(bytes[Int64(i) + 2] & UInt8(0x3F))
                    if (cp >= 0xD800 && cp <= 0xDFFF) {
                        return false  // UTF-16 代理对范围
                    }
                }
            }

            i += cpLen
        }
        return true
    }
}

// ============================================================================
// TextEncodingModule — TextEncoding 模块导出
// ============================================================================

/// TextEncoding 模块导出 — 将 TextEncoder/TextDecoder 注册到全局
public class TextEncodingModule {
    /// 将 TextEncoder/TextDecoder 注册到全局环境
    public static func registerGlobals(env: Environment): Unit {
        // TextEncoder 构造函数
        env.define("TextEncoder", Interpreter.makeNativeFn("TextEncoder") { args =>
            let encoder = TextEncoder()
            return encoder.toJsValue()
        }, false)

        // TextDecoder 构造函数
        env.define("TextDecoder", Interpreter.makeNativeFn("TextDecoder") { args =>
            let decoder = if (args.size >= 1) {
                let encoding = Interpreter.jsToString(args[0])
                if (args.size >= 2) {
                    // 解析 options
                    let opts = TextDecoderOptions()
                    match (args[1].objectData) {
                        case Some(obj) => {
                            let fatal = obj.get("fatal")
                            if (fatal.valueType == JsValueType.Boolean) {
                                opts.fatal = fatal.boolValue
                            }
                            let ignoreBOM = obj.get("ignoreBOM")
                            if (ignoreBOM.valueType == JsValueType.Boolean) {
                                opts.ignoreBOM = ignoreBOM.boolValue
                            }
                        }
                        case None => ()
                    }
                    TextDecoder(encoding, opts)
                } else {
                    TextDecoder(encoding)
                }
            } else {
                TextDecoder()
            }
            return decoder.toJsValue()
        }, false)
    }
}
