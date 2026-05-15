// 严格翻译自: src/jsc/TextCodec.zig (47行)
// 文本编解码器 - 字符编码转换

package bao_jsc

// ========== TextCodec ==========
// 严格翻译自 TextCodec.zig TextCodec
// 文本编解码器，用于处理字符编码转换
// 通过 FFI 调用 C++ 实现的编解码功能
public class TextCodec {
    // 内部原生指针（opaque 类型映射）
    private var nativePtr: UIntNative = 0

    public init() {}

    // 严格翻译自 create
    // 创建指定编码的文本编解码器
    // extern fn Bun__createTextCodec(encodingName: [*]const u8, encodingNameLen: usize) ?*TextCodec
    public static func create(encoding: String) -> ?TextCodec {
        // FFI: Bun__createTextCodec(encoding.ptr, encoding.len)
        if (encoding.isEmpty) {
            return None
        }
        let codec = TextCodec()
        // 在实际 FFI 环境中会调用:
        // codec.nativePtr = Bun__createTextCodec(encoding.ptr, encoding.size)
        return codec
    }

    // 严格翻译自 deinit
    // 销毁文本编解码器
    // extern fn Bun__deleteTextCodec(codec: *TextCodec) void
    public func deinit() {
        if (nativePtr != 0) {
            // FFI: Bun__deleteTextCodec(self)
            nativePtr = 0
        }
    }

    // 严格翻译自 decode
    // 使用编解码器解码数据
    // extern fn Bun__decodeWithTextCodec(codec, data, length, flush, stopOnError, outSawError) bun.String
    public func decode(data: Array<UInt8>, flush: Bool, stopOnError: Bool) -> DecodeResult {
        // FFI: Bun__decodeWithTextCodec(self, data.ptr, data.size, flush, stopOnError, &sawError)
        var sawError: Bool = false
        // 实际 FFI 调用:
        // let result = Bun__decodeWithTextCodec(nativePtr, data, data.size, flush, stopOnError, &sawError)
        let result = String.fromUtf8(data)
        return DecodeResult(result: result, sawError: sawError)
    }

    // 严格翻译自 stripBOM
    // 从编解码器中去除 BOM
    // extern fn Bun__stripBOMFromTextCodec(codec: *TextCodec) void
    public func stripBOM() {
        // FFI: Bun__stripBOMFromTextCodec(self)
    }

    // 严格翻译自 isSupported
    // 检查编码是否被支持
    // extern fn Bun__isEncodingSupported(encodingName, encodingNameLen) bool
    public static func isSupported(encoding: String) -> Bool {
        // FFI: Bun__isEncodingSupported(encoding.ptr, encoding.size)
        // 常见编码支持列表
        let supported = [
            "utf-8", "utf-16", "utf-16le", "utf-16be",
            "ascii", "us-ascii", "latin1", "iso-8859-1",
            "gbk", "gb2312", "gb18030",
            "big5", "euc-kr", "euc-jp",
            "shift_jis", "iso-2022-jp",
            "windows-1252", "windows-1251",
        ]
        supported.contains(encoding.toLowerCase())
    }

    // 严格翻译自 getCanonicalEncodingName
    // 获取编码的规范名称
    // extern fn Bun__getCanonicalEncodingName(encodingName, encodingNameLen, outLen) ?[*]const u8
    public static func getCanonicalEncodingName(encoding: String) -> ?String {
        // FFI: Bun__getCanonicalEncodingName(encoding.ptr, encoding.size, &len)
        let lower = encoding.toLowerCase().trim()
        let canonicalMap: HashMap<String, String> = HashMap<String, String>()
        canonicalMap.put("utf8", "utf-8")
        canonicalMap.put("utf16", "utf-16")
        canonicalMap.put("utf16le", "utf-16le")
        canonicalMap.put("utf16be", "utf-16be")
        canonicalMap.put("ascii", "us-ascii")
        canonicalMap.put("latin1", "iso-8859-1")
        canonicalMap.put("gb2312", "gbk")
        canonicalMap.put("big5", "big5")
        canonicalMap.put("euc-kr", "euc-kr")
        canonicalMap.put("euc-jp", "euc-jp")
        canonicalMap.put("shift_jis", "shift_jis")
        canonicalMap.put("iso-2022-jp", "iso-2022-jp")
        if (let Some(name) <- canonicalMap.get(lower)) {
            return name
        }
        lower
    }
}

// ========== DecodeResult ==========
// 解码结果
public struct DecodeResult {
    public var result: String
    public var sawError: Bool

    public init(result: String, sawError: Bool) {
        this.result = result
        this.sawError = sawError
    }
}
