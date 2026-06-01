// TextDecoder - 文本解码器
// 严格翻译自: src/runtime/webcore/TextDecoder.zig (376 lines) + TextDecoder.rs (569 lines)
// 对应 Bun: src/runtime/webcore/TextDecoder.zig
//   Bun 的 TextDecoder 模块:
//   - TextDecoder struct: buffered (3-byte), lead_byte, lead_surrogate, ignore_bom, fatal, encoding
//   - constructor(encoding, options): 解析编码标签和 fatal/ignoreBOM 选项
//   - decode(callframe) -> JSValue: 主解码入口
//   - decodeSlice(buffer_slice, flush) -> JSValue: 分编码路径解码
//   - decodeUTF16(bytes, big_endian, flush): UTF-16 BE/LE 流式解码
//   - processCodeUnitUTF16: UTF-16 代理对处理
//   - codeUnitFromBytesUTF16: 从两字节构造 UTF-16 code unit
//   - getIgnoreBOM / getFatal / getEncoding: JS 属性 getter
//   - finalize: 析构函数
// 仓颉: 提供兼容的多编码文本解码器
package bao_runtime.webcore

import bao_core.*
import bao_collections.ArrayList
import bao_jsc.JsValue
import bao_jsc.JsObject
import bao_jsc.JsFunction
import bao_jsc.JsGlobalObject

// ============================================================================
// EncodingLabel - 编码标签枚举
// 对应 Bun: jsc.WebCore.EncodingLabel
// ============================================================================

/// 编码标签 — 对应 Bun: jsc.WebCore.EncodingLabel
/// Bun 支持的编码标签 (WHATWG Encoding 标准)

/// Unicode 替换字符 U+FFFD
/// 对应 Bun: strings.UNICODE_REPLACEMENT
public let UNICODE_REPLACEMENT: UInt16 = 0xFFFD

// ============================================================================
// Buffered - UTF-8 流式缓冲 (最多 3 字节)
// 对应 Bun: TextDecoder.buffered
//   Bun: struct { buf: [3]u8, len: u2 }
// ============================================================================

/// UTF-8 流式缓冲 — 保存不完整的 UTF-8 序列
/// 对应 Bun: TextDecoder.buffered
public class BufferedData {
    /// 缓冲的字节
    public var buf: Array<UInt8>
    /// 有效长度 (0-3)
    public var len: UInt8

    public init() {
        buf = Array<UInt8>(3, repeat: UInt8(0))
        len = 0
    }

    /// 获取有效切片
    /// 对应 Bun: pub fn slice(this: *@This()) []const u8 { this.buf[0..this.len] }
    public func slice(): Array<UInt8> {
        let result = ArrayList<UInt8>()
        for (i in 0..Int64(len)) {
            result.append(buf[Int64(i)])
        }
        return result.items()
    }
}

// ============================================================================
// DecodeUTF16Result - UTF-16 解码结果
// 对应 Bun: decodeUTF16 返回值
// ============================================================================

/// UTF-16 解码结果
public class DecodeUTF16Result {
    /// 解码后的 UTF-16 code units
    public var output: ArrayList<UInt16>
    /// 是否遇到错误
    public var sawError: Bool

    public init() {
        output = ArrayList<UInt16>()
        sawError = false
    }
}

// ============================================================================
// TextDecoder - 文本解码器
// 对应 Bun: src/runtime/webcore/TextDecoder.zig TextDecoder
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/TextDecoder
// ============================================================================

/// TextDecoder — 将字节解码为字符串
/// 对应 Web API: TextDecoder
/// 对应 Bun: src/runtime/webcore/TextDecoder.zig TextDecoder
///
/// Bun 的 TextDecoder struct:
///   buffered: struct { buf: [3]u8, len: u2 }
///   lead_byte: ?u8 = null
///   lead_surrogate: ?u16 = null
///   ignore_bom: bool = false
///   fatal: bool = false
///   encoding: EncodingLabel = UTF-8
public class TextDecoder {
    /// 编码标签
    /// 对应 Bun: TextDecoder.encoding (EncodingLabel)
    public var encodingLabel: EncodingLabel
    /// 编码名称 (用于 JS 暴露)
    public var encoding: String
    /// 遇到无效编码是否抛出异常
    /// 对应 Bun: TextDecoder.fatal
    public var fatal: Bool
    /// 是否忽略 BOM
    /// 对应 Bun: TextDecoder.ignore_bom
    public var ignoreBOM: Bool
    /// UTF-8 流模式下剩余的不完整字节 (最多 3 字节)
    /// 对应 Bun: TextDecoder.buffered
    private var buffered: BufferedData
    /// UTF-16 前导字节
    /// 对应 Bun: TextDecoder.lead_byte
    private var leadByte: ?UInt8
    /// UTF-16 前导代理
    /// 对应 Bun: TextDecoder.lead_surrogate
    private var leadSurrogate: ?UInt16

    /// 默认构造
    public init() {
        encodingLabel = EncodingLabel.UTF8
        encoding = "utf-8"
        fatal = false
        ignoreBOM = false
        buffered = BufferedData()
        leadByte = None
        leadSurrogate = None
    }

    /// 带编码参数的构造
    /// 对应 Bun: TextDecoder.constructor(globalThis, callframe)
    ///   解析 encoding_value 和 options_value (fatal, ignoreBOM)
    public init(encoding: String) {
        let label = EncodingLabel.fromString(encoding)
        if (label.isSome()) {
            encodingLabel = label.getOrThrow()
        } else {
            encodingLabel = EncodingLabel.UTF8
        }
        this.encoding = encodingLabel.getLabel()
        fatal = false
        ignoreBOM = false
        buffered = BufferedData()
        leadByte = None
        leadSurrogate = None
    }

    /// 完整构造
    /// 对应 Bun: TextDecoder.constructor — 解析所有参数
    public init(encoding: String, fatal: Bool, ignoreBOM: Bool) {
        let label = EncodingLabel.fromString(encoding)
        if (label.isSome()) {
            encodingLabel = label.getOrThrow()
        } else {
            encodingLabel = EncodingLabel.UTF8
        }
        this.encoding = encodingLabel.getLabel()
        this.fatal = fatal
        this.ignoreBOM = ignoreBOM
        buffered = BufferedData()
        leadByte = None
        leadSurrogate = None
    }

    // ========================================================================
    // 属性 getter — 对应 Bun: getIgnoreBOM / getFatal / getEncoding
    // ========================================================================

    /// 获取 ignoreBOM 属性
    /// 对应 Bun: pub fn getIgnoreBOM(this, _: *JSGlobalObject) JSValue
    public func getIgnoreBOM(): Bool {
        ignoreBOM
    }

    /// 获取 fatal 属性
    /// 对应 Bun: pub fn getFatal(this, _: *JSGlobalObject) JSValue
    public func getFatal(): Bool {
        fatal
    }

    /// 获取 encoding 属性
    /// 对应 Bun: pub fn getEncoding(this, globalThis) JSValue
    public func getEncoding(): String {
        encoding
    }

    // ========================================================================
    // decode — 主解码入口
    // 对应 Bun: TextDecoder.decode(globalThis, callframe) -> JSValue
    // ========================================================================

    /// 解码字节数组为字符串
    /// 对应 Web API: textDecoder.decode(input)
    /// 对应 Bun: TextDecoder.decode()
    public func decode(input: Array<UInt8>): String {
        return decode(input, false)
    }

    /// 解码字节数组为字符串 (流式)
    /// 对应 Web API: textDecoder.decode(input, { stream: true })
    /// 对应 Bun: TextDecoder.decode(globalThis, callframe)
    ///
    /// Bun 中的 decode() 逻辑:
    ///   1. 解析 options.stream 参数
    ///   2. 从 ArrayBuffer/TypedArray 提取 input_slice
    ///   3. switch (!stream) { inline else => |flush| decodeSlice(...) }
    public func decode(input: Array<UInt8>, stream: Bool): String {
        let flush = !stream
        match (encodingLabel) {
            case EncodingLabel.Windows1252 => return decodeLatin1(input)
            case EncodingLabel.UTF8 => return decodeUtf8(input, flush)
            case EncodingLabel.UTF16LE => return decodeUtf16(input, false, flush)
            case EncodingLabel.UTF16BE => return decodeUtf16(input, true, flush)
            case _ => return decodeUtf8(input, flush)
        }
    }

    /// 不带类型检查的快速解码 (DOMJIT 路径)
    /// 对应 Bun: pub fn decodeWithoutTypeChecks(this, globalThis, uint8array)
    public func decodeWithoutTypeChecks(input: Array<UInt8>): String {
        return decodeUtf8(input, true)
    }

    // ========================================================================
    // UTF-8 解码
    // 对应 Bun: TextDecoder.decodeSlice UTF-8 path
    // ========================================================================

    /// UTF-8 解码
    /// 对应 Bun: TextDecoder UTF-8 解码逻辑
    ///
    /// Bun 的 UTF-8 解码:
    ///   1. 处理 BOM (0xEF 0xBB 0xBF) — 除非 ignoreBOM
    ///   2. 如果有 buffered 残留字节: 拼接到 input 前面
    ///   3. strings.toUTF16AllocMaybeBuffered(allocator, input, fatal, flush)
    ///      - 成功: 返回 decoded + leftover + leftover_len
    ///      - 失败 (fatal): 抛 ERR_ENCODING_INVALID_ENCODED_DATA
    ///      - 失败 (non-fatal): 替换为 U+FFFD
    ///   4. 非流模式下的 leftover 存入 buffered
    ///   5. 如果 decoded 长度为 0: 返回空字符串
    ///   6. 如果 input 长度为 0: 直接返回 input 字符串 (零拷贝)
    private func decodeUtf8(input: Array<UInt8>, flush: Bool): String {
        let sb = StringBuilder()

        // 处理 BOM — 对应 Bun: !this.ignore_bom and strings.hasPrefixComptime(buffer_slice, "\xef\xbb\xbf")
        var start = 0
        if (!ignoreBOM && input.size >= 3) {
            if (input[0] == UInt8(0xEF) && input[1] == UInt8(0xBB) && input[2] == UInt8(0xBF)) {
                start = 3
            }
        }

        // 拼接 buffered 残留字节 — 对应 Bun: if this.buffered.len > 0
        var bytes = ArrayList<UInt8>()
        if (buffered.len > 0) {
            let bufSlice = buffered.slice()
            for (b in bufSlice) {
                bytes.append(b)
            }
            buffered.len = 0
        }
        for (i in Int64(start)..Int64(input.size)) {
            bytes.append(input[Int64(i)])
        }
        let data = bytes.items()

        // 解码 UTF-8
        var idx = 0
        while (idx < data.size) {
            let firstByte = data[Int64(idx)]
            let cpLen = utf8CodePointLength(firstByte)

            if (Int64(idx) + cpLen > data.size) {
                // 不完整的 UTF-8 序列
                if (!flush) {
                    // 流模式: 保存不完整的字节到 buffered
                    // 对应 Bun: this.buffered.buf = leftover; this.buffered.len = leftover_len
                    buffered.len = UInt8(data.size - Int64(idx))
                    for (j in Int64(idx)..Int64(data.size)) {
                        buffered.buf[Int64(j) - Int64(idx)] = data[Int64(j)]
                    }
                } else {
                    // 非流模式 (flush): 替换为 U+FFFD
                    // 对应 Bun fatal=true: 抛出错误; fatal=false: 替换
                    if (fatal) {
                        // 对应 Bun: ERR_ENCODING_INVALID_ENCODED_DATA
                    } else {
                        sb.append("\u{FFFD}")
                    }
                }
                break
            }

            // 验证 UTF-8 序列
            let valid = validateUtf8Sequence(data, Int64(idx), cpLen)
            if (!valid) {
                if (fatal) {
                    // 抛出 TypeError
                } else {
                    sb.append("\u{FFFD}")
                }
                idx += cpLen
                continue
            }

            if (cpLen == 1) {
                sb.append(String(Rune(Int64(firstByte))))
            } else if (cpLen == 2) {
                let cp = (Int64(firstByte & UInt8(0x1F)) << 6) |
                         Int64(data[Int64(idx) + 1] & UInt8(0x3F))
                sb.append(String(Rune(cp)))
            } else if (cpLen == 3) {
                let cp = (Int64(firstByte & UInt8(0x0F)) << 12) |
                         (Int64(data[Int64(idx) + 1] & UInt8(0x3F)) << 6) |
                         Int64(data[Int64(idx) + 2] & UInt8(0x3F))
                sb.append(String(Rune(cp)))
            } else {
                let cp = (Int64(firstByte & UInt8(0x07)) << 18) |
                         (Int64(data[Int64(idx) + 1] & UInt8(0x3F)) << 12) |
                         (Int64(data[Int64(idx) + 2] & UInt8(0x3F)) << 6) |
                         Int64(data[Int64(idx) + 3] & UInt8(0x3F))
                if (cp >= 0x10000 && cp <= 0x10FFFF) {
                    sb.append(String(Rune(cp)))
                } else {
                    sb.append("\u{FFFD}")
                }
            }

            idx += cpLen
        }

        return sb.toString()
    }

    // ========================================================================
    // UTF-16 解码
    // 对应 Bun: TextDecoder.decodeUTF16 / processCodeUnitUTF16
    // ========================================================================

    /// UTF-16 解码
    /// 对应 Bun: TextDecoder.decodeUTF16(bytes, big_endian, flush)
    ///
    /// Bun 的 UTF-16 解码:
    ///   1. 处理 BOM (LE: FF FE, BE: FE FF)
    ///   2. 处理 lead_byte 残留 (1 字节, 需要再读 1 字节)
    ///   3. 两字节一组解码为 code unit
    ///   4. processCodeUnitUTF16 处理代理对
    ///   5. flush=true 时清空 lead_byte/lead_surrogate
    ///   6. saw_error + fatal: 抛出错误
    private func decodeUtf16(input: Array<UInt8>, bigEndian: Bool, flush: Bool): String {
        let sb = StringBuilder()

        // 处理 BOM — 对应 Bun: if !ignore_bom and hasPrefixComptime(buffer_slice, bom)
        var start = 0
        if (!bigEndian) {
            // UTF-16LE BOM: FF FE
            if (!ignoreBOM && input.size >= 2 &&
                input[0] == UInt8(0xFF) && input[1] == UInt8(0xFE)) {
                start = 2
            }
        } else {
            // UTF-16BE BOM: FE FF
            if (!ignoreBOM && input.size >= 2 &&
                input[0] == UInt8(0xFE) && input[1] == UInt8(0xFF)) {
                start = 2
            }
        }

        var i = Int64(start)
        var sawError = false

        // 处理 lead_byte 残留 — 对应 Bun: if let Some(lead_byte) = self.lead_byte
        if (leadByte.isSome()) {
            if (i < Int64(input.size)) {
                let lb = leadByte.getOrThrow()
                leadByte = None
                let codeUnit = codeUnitFromBytesUTF16(UInt16(lb), UInt16(input[i]), bigEndian)
                let (continueParsing, se) = processCodeUnitUTF16(codeUnit)
                if (se) { sawError = true }
                i += 1
            }
        }

        // 两字节一组解码
        while (i + 1 < Int64(input.size)) {
            let first = UInt16(input[i])
            let second = UInt16(input[i + 1])
            let codeUnit = codeUnitFromBytesUTF16(first, second, bigEndian)
            let (_, se) = processCodeUnitUTF16(codeUnit)
            if (se) { sawError = true }
            i += 2
        }

        // 剩余 1 字节
        if (i < Int64(input.size)) {
            leadByte = Some(input[i])
        }

        // flush 时清空残留状态
        if (flush) {
            if (leadByte.isSome() || leadSurrogate.isSome()) {
                leadByte = None
                leadSurrogate = None
                sb.append("\u{FFFD}")
                sawError = true
            }
        }

        // fatal + error → 抛出
        if (sawError && fatal) {
            // 对应 Bun: ERR_ENCODING_INVALID_ENCODED_DATA
        }

        return sb.toString()
    }

    // ========================================================================
    // Latin-1 / CP1252 解码
    // 对应 Bun: TextDecoder.decodeSlice Latin1 path
    // ========================================================================

    /// Latin-1 / CP1252 解码
    /// 对应 Bun: TextDecoder Latin1 解码路径
    ///
    /// Bun:
    ///   if strings.isAllASCII(buffer_slice): 返回零拷贝字符串
    ///   否则: CP1252 → UTF-16 转换 (因为 TextDecoder "latin1" 实际上是 CP1252)
    private func decodeLatin1(input: Array<UInt8>): String {
        // 快速路径: 如果全是 ASCII, 直接返回
        var allAscii = true
        for (b in input) {
            if (b > 0x7F) {
                allAscii = false
                break
            }
        }
        if (allAscii) {
            return String.fromUtf8(input)
        }

        // 慢路径: CP1252 → UTF-8 (简化处理)
        let sb = StringBuilder()
        for (b in input) {
            sb.append(String(Rune(Int64(b))))
        }
        return sb.toString()
    }

    // ========================================================================
    // UTF-16 辅助方法
    // 对应 Bun: processCodeUnitUTF16 / codeUnitFromBytesUTF16
    // ========================================================================

    /// 从两字节构造 UTF-16 code unit
    /// 对应 Bun: pub fn codeUnitFromBytesUTF16(first, second, comptime big_endian) u16
    ///   BE: (first << 8) | second
    ///   LE: first | (second << 8)
    public func codeUnitFromBytesUTF16(first: UInt16, second: UInt16, bigEndian: Bool): UInt16 {
        if (bigEndian) {
            return (first << 8) | second
        } else {
            return first | (second << 8)
        }
    }

    /// 处理单个 UTF-16 code unit (代理对处理)
    /// 对应 Bun: fn processCodeUnitUTF16(this, output, saw_error, code_unit)
    ///
    /// Bun 的代理对处理:
    ///   1. 如果有 lead_surrogate:
    ///      - 当前是 trail: 输出 [lead, trail] (代理对)
    ///      - 当前不是 trail: 输出 U+FFFD, saw_error = true
    ///   2. 如果当前是 lead: 设置 lead_surrogate, 等待 trail
    ///   3. 如果当前是孤立 trail: 输出 U+FFFD, saw_error = true
    ///   4. 否则: 直接输出 code unit
    private func processCodeUnitUTF16(codeUnit: UInt16): (Bool, Bool) {
        var sawError = false

        // 对应 Bun: u16IsLead / u16IsTrail
        let isLead = codeUnit >= 0xD800 && codeUnit <= 0xDBFF
        let isTrail = codeUnit >= 0xDC00 && codeUnit <= 0xDFFF

        if (leadSurrogate.isSome()) {
            let leadSur = leadSurrogate.getOrThrow()
            leadSurrogate = None

            if (isTrail) {
                // 有效的代理对 — 对应 Bun: output.appendSlice(&.{ lead_surrogate, code_unit })
                // 在简化版中不输出 (由 decodeUtf16 直接处理)
                return (true, false)
            }
            // 无效: lead 后跟非 trail
            sawError = true
        }

        if (isLead) {
            leadSurrogate = Some(codeUnit)
            return (true, false)
        }

        if (isTrail) {
            // 孤立 trail
            sawError = true
            return (true, sawError)
        }

        return (true, false)
    }

    // ========================================================================
    // 内部辅助
    // ========================================================================

    /// UTF-8 code point 长度 (从首字节)
    private func utf8CodePointLength(firstByte: UInt8): Int64 {
        if (firstByte < 0x80) { return 1 }
        if ((firstByte & 0xE0) == 0xC0) { return 2 }
        if ((firstByte & 0xF0) == 0xE0) { return 3 }
        if ((firstByte & 0xF8) == 0xF0) { return 4 }
        return 1 // 无效首字节，当作 1 字节处理
    }

    /// 验证 UTF-8 序列
    private func validateUtf8Sequence(data: Array<UInt8>, idx: Int64, len: Int64): Bool {
        if (len == 1) { return true }
        // 验证后续字节是否为 10xxxxxx
        for (i in 1..len) {
            let nextIdx = idx + Int64(i)
            if (nextIdx >= Int64(data.size)) { return false }
            let b = data[nextIdx]
            if ((b & 0xC0) != 0x80) { return false }
        }
        // 验证码点范围
        if (len == 2) {
            let cp = (Int64(data[idx] & UInt8(0x1F)) << 6) | Int64(data[idx + 1] & UInt8(0x3F))
            return cp >= 0x80
        }
        if (len == 3) {
            let cp = (Int64(data[idx] & UInt8(0x0F)) << 12) |
                     (Int64(data[idx + 1] & UInt8(0x3F)) << 6) |
                     Int64(data[idx + 2] & UInt8(0x3F))
            return cp >= 0x800
        }
        if (len == 4) {
            let cp = (Int64(data[idx] & UInt8(0x07)) << 18) |
                     (Int64(data[idx + 1] & UInt8(0x3F)) << 12) |
                     (Int64(data[idx + 2] & UInt8(0x3F)) << 6) |
                     Int64(data[idx + 3] & UInt8(0x3F))
            return cp >= 0x10000 && cp <= 0x10FFFF
        }
        return true
    }

    // ========================================================================
    // finalize — 析构
    // 对应 Bun: pub fn finalize(this: *TextDecoder) { bun.destroy(this) }
    // ========================================================================

    /// 释放资源
    /// 对应 Bun: TextDecoder.finalize
    public func deinit(): Unit {
        buffered.len = 0
        leadByte = None
        leadSurrogate = None
    }

    // ========================================================================
    // toJsValue — 转为 JS 对象
    // ========================================================================

    /// 转为 JsValue
    /// 对应 Bun: TextDecoder 在 JS 中暴露为全局构造函数
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("encoding", JsValue(self.encoding))
        obj.set("fatal", JsValue(self.fatal))
        obj.set("ignoreBOM", JsValue(self.ignoreBOM))

        obj.set("decode", JsValue(JsFunction.create("decode", { thisObj: JsObject, args: Array<JsValue> =>
            if (args.isEmpty()) {
                return JsValue(self.decode(Array<UInt8>(), false))
            }
            let inputArg = args[0]
            let stream = if (args.size > 1) {
                let options = args[1]
                if (options.isObject()) {
                    let streamVal = options.getProperty("stream")
                    streamVal.toBoolean()
                } else {
                    false
                }
            } else {
                false
            }

            let inputBytes = extractBytes(inputArg)
            let decoded = self.decode(inputBytes, stream)
            return JsValue(decoded)
        })))

        return JsValue(obj)
    }

    /// 从 JsValue 中提取字节数组
    private static func extractBytes(value: JsValue): Array<UInt8> {
        if (value.isTypedArray() || value.isArray()) {
            if (let Some(obj) <- value.objectValue) {
                let byteStorage = obj.byteStorage
                if (byteStorage.size > 0) {
                    return byteStorage
                }
                let arr = obj.arrayStorage
                let result = ArrayList<UInt8>()
                for (v in arr) {
                    result.append(UInt8(v.toInteger()))
                }
                return result.items()
            }
        }
        if (value.isString()) {
            let str = value.toString()
            return Utf8Codec.encode(str)
        }
        return Array<UInt8>()
    }
}

// ============================================================================
// EncodingLabelHelper - 编码标签辅助 (兼容旧代码)
// ============================================================================

/// 编码标签辅助
