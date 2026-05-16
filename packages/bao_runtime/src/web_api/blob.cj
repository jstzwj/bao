// Web API Blob / File 模块
// 对应 Bun: src/runtime/webcore/Blob.zig
// 严格翻译自 Bun 的 Blob / File API
package bao_runtime.web_api

import bao_core.*
import bao_collections.*

// ============================================================================
// Blob — 二进制大对象
// 对应 Bun: src/runtime/webcore/Blob.zig Blob
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/Blob
// ============================================================================

/// Blob — 二进制大对象
/// 对应 Web API: Blob
/// 对应 Bun: src/runtime/webcore/Blob.zig Blob
public class Blob {
    /// 内部字节数据
    public var data: Array<UInt8>
    /// MIME 类型
    public var type: String
    /// Blob 大小
    public var size: Int64
    /// 编码
    public var encoding: String

    public init() {
        data = Array<UInt8>()
        type = ""
        size = 0
        encoding = "utf-8"
    }

    public init(data: Array<UInt8>, mimeType: String) {
        this.data = data
        this.type = mimeType
        this.size = Int64(data.size)
        this.encoding = "utf-8"
    }

    public init(data: Array<UInt8>, options: BlobOptions) {
        this.data = data
        this.type = options.type
        this.size = Int64(data.size)
        this.encoding = if (options.encoding.length > 0) { options.encoding } else { "utf-8" }
    }

    /// 将 Blob 的内容读取为 ArrayBuffer (Array<UInt8>)
    /// 对应 Web API: blob.arrayBuffer()
    public func arrayBuffer(): Array<UInt8> {
        return data
    }

    /// 将 Blob 的内容读取为文本
    /// 对应 Web API: blob.text()
    public func text(): String {
        return Utf8Codec.decode(data)
    }

    /// 将 Blob 的内容读取为 JSON
    /// 对应 Web API: blob.json() (非标准，Bun 扩展)
    public func json(): JsValue {
        let textContent = text()
        return JsValue(BaoString(textContent))
    }

    /// 将 Blob 的内容转为 Data URL
    /// 对应 Web API: 不标准，但广泛使用
    public func dataURL(): String {
        let base64 = Base64Codec.encode(data)
        let mediaType = if (type.length > 0) { type } else { "application/octet-stream" }
        return "data:${mediaType};base64,${base64}"
    }

    /// 创建一个切片 Blob
    /// 对应 Web API: blob.slice(start, end, contentType)
    public func slice(start: Int64, end: Int64, contentType: String): Blob {
        let effectiveStart = if (start < 0) {
            Int64(Math.max(Int64(0), size + start))
        } else {
            Int64(Math.min(start, size))
        }
        let effectiveEnd = if (end < 0) {
            Int64(Math.max(Int64(0), size + end))
        } else {
            Int64(Math.min(end, size))
        }

        if (effectiveStart >= effectiveEnd) {
            return Blob(Array<UInt8>(), contentType)
        }

        let length = effectiveEnd - effectiveStart
        let sliceData = Array<UInt8>(length, item: UInt8(0))
        for (i in 0..length) {
            sliceData[Int64(i)] = data[effectiveStart + Int64(i)]
        }

        return Blob(sliceData, contentType)
    }

    /// 创建一个切片 Blob (无 contentType)
    /// 对应 Web API: blob.slice(start, end)
    public func slice(start: Int64, end: Int64): Blob {
        return slice(start, end, "")
    }

    /// 创建一个切片 Blob (只有 start)
    /// 对应 Web API: blob.slice(start)
    public func slice(start: Int64): Blob {
        return slice(start, size, "")
    }

    /// 创建一个切片 Blob (无参数)
    /// 对应 Web API: blob.slice()
    public func slice(): Blob {
        return slice(0, size, "")
    }

    /// 获取流式 Reader (简化实现)
    /// 对应 Web API: blob.stream()
    public func stream(): BlobStreamReader {
        return BlobStreamReader(this)
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("size", JsValue(Float64(self.size)))
        obj.set("type", JsValue(BaoString(self.type)))

        obj.set("arrayBuffer", JsValue.nativeFunction(JsNativeFunction("arrayBuffer") { _ =>
            let bytes = self.arrayBuffer()
            let arr = ArrayList<JsValue>()
            for (b in bytes) {
                arr.append(JsValue(Float64(Int64(b))))
            }
            return JsValue.array(arr)
        }))

        obj.set("text", JsValue.nativeFunction(JsNativeFunction("text") { _ =>
            JsValue(BaoString(self.text()))
        }))

        obj.set("json", JsValue.nativeFunction(JsNativeFunction("json") { _ =>
            self.json()
        }))

        obj.set("slice", JsValue.nativeFunction(JsNativeFunction("slice") { args =>
            let start = if (args.size >= 1) { Int64(Interpreter.jsToNumber(args[0])) } else { Int64(0) }
            let end = if (args.size >= 2) { Int64(Interpreter.jsToNumber(args[1])) } else { self.size }
            let contentType = if (args.size >= 3) { Interpreter.jsToString(args[2]) } else { "" }
            return self.slice(start, end, contentType).toJsValue()
        }))

        obj.set("stream", JsValue.nativeFunction(JsNativeFunction("stream") { _ =>
            self.stream().toJsValue()
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// BlobOptions — Blob 构造选项
// 对应 Bun: BlobPropertyBag
// ============================================================================

/// Blob 构造选项
/// 对应 Web API: BlobPropertyBag
public class BlobOptions {
    /// MIME 类型
    public var type: String
    /// 编码
    public var encoding: String
    /// 结尾符 (transparent / native)
    public var endings: String

    public init() {
        type = ""
        encoding = "utf-8"
        endings = "transparent"
    }

    public init(type: String) {
        this.type = type
        this.encoding = "utf-8"
        this.endings = "transparent"
    }

    public init(type: String, encoding: String, endings: String) {
        this.type = type
        this.encoding = encoding
        this.endings = endings
    }
}

// ============================================================================
// File — 文件对象 (继承自 Blob)
// 对应 Bun: src/runtime/webcore/Blob.zig (is_jsdom_file)
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/File
// ============================================================================

/// File — 文件对象
/// 继承 Blob 的所有功能，并增加文件名和最后修改时间
/// 对应 Web API: File
/// 对应 Bun: src/runtime/webcore/Blob.zig (File variant)
public class File extends Blob {
    /// 文件名
    public var name: String
    /// 最后修改时间 (毫秒时间戳)
    public var lastModified: Int64

    public init(data: Array<UInt8>, name: String, mimeType: String) {
        super(data, mimeType)
        this.name = name
        this.lastModified = currentTimeMillis()
    }

    public init(data: Array<UInt8>, name: String, options: FileOptions) {
        super(data, BlobOptions(options.type))
        this.name = name
        this.lastModified = if (options.lastModified >= 0) {
            options.lastModified
        } else {
            currentTimeMillis()
        }
    }

    public init(name: String) {
        super()
        this.name = name
        this.lastModified = currentTimeMillis()
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("size", JsValue(Float64(self.size)))
        obj.set("type", JsValue(BaoString(self.type)))
        obj.set("name", JsValue(BaoString(self.name)))
        obj.set("lastModified", JsValue(Float64(self.lastModified)))

        obj.set("arrayBuffer", JsValue.nativeFunction(JsNativeFunction("arrayBuffer") { _ =>
            let bytes = self.arrayBuffer()
            let arr = ArrayList<JsValue>()
            for (b in bytes) {
                arr.append(JsValue(Float64(Int64(b))))
            }
            return JsValue.array(arr)
        }))

        obj.set("text", JsValue.nativeFunction(JsNativeFunction("text") { _ =>
            JsValue(BaoString(self.text()))
        }))

        obj.set("json", JsValue.nativeFunction(JsNativeFunction("json") { _ =>
            self.json()
        }))

        obj.set("slice", JsValue.nativeFunction(JsNativeFunction("slice") { args =>
            let start = if (args.size >= 1) { Int64(Interpreter.jsToNumber(args[0])) } else { Int64(0) }
            let end = if (args.size >= 2) { Int64(Interpreter.jsToNumber(args[1])) } else { self.size }
            let contentType = if (args.size >= 3) { Interpreter.jsToString(args[2]) } else { "" }
            return self.slice(start, end, contentType).toJsValue()
        }))

        return JsValue(obj)
    }

    /// 获取当前时间戳 (毫秒)
    private static func currentTimeMillis(): Int64 {
        return bao_sys.SysModule.currentTimeMillis()
    }
}

// ============================================================================
// FileOptions — File 构造选项
// 对应 Web API: FilePropertyBag
// ============================================================================

/// File 构造选项
/// 对应 Web API: FilePropertyBag
public class FileOptions {
    /// MIME 类型
    public var type: String
    /// 最后修改时间
    public var lastModified: Int64

    public init() {
        type = ""
        lastModified = -1
    }

    public init(type: String, lastModified: Int64) {
        this.type = type
        this.lastModified = lastModified
    }
}

// ============================================================================
// BlobStreamReader — Blob 流式读取器
// 对应 Web API: Blob.stream() 返回的 ReadableStream
// ============================================================================

/// Blob 流式读取器
/// 对应 Web API: ReadableStream (Blob.stream() 返回)
public class BlobStreamReader {
    private var blob: Blob
    private var position: Int64
    private var done: Bool
    /// 默认 chunk 大小 (64KB)
    public static let DEFAULT_CHUNK_SIZE: Int64 = 65536

    public init(blob: Blob) {
        this.blob = blob
        this.position = 0
        this.done = false
    }

    /// 读取下一个 chunk
    public func read(): ?Array<UInt8> {
        if (done || position >= blob.size) {
            done = true
            return None
        }

        let remaining = blob.size - position
        let chunkSize = Math.min(DEFAULT_CHUNK_SIZE, remaining)
        let chunk = Array<UInt8>(chunkSize, item: UInt8(0))

        for (i in 0..chunkSize) {
            chunk[Int64(i)] = blob.data[position + Int64(i)]
        }

        position += chunkSize
        if (position >= blob.size) {
            done = true
        }

        return Some(chunk)
    }

    /// 是否读取完毕
    public func isDone(): Bool {
        return done
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("read", JsValue.nativeFunction(JsNativeFunction("read") { _ =>
            match (self.read()) {
                case Some(chunk) => {
                    let arr = ArrayList<JsValue>()
                    for (b in chunk) {
                        arr.append(JsValue(Float64(Int64(b))))
                    }
                    let chunkObj = JsObject()
                    chunkObj.set("done", JsValue(false))
                    chunkObj.set("value", JsValue.array(arr))
                    return JsValue(chunkObj)
                }
                case None => {
                    let doneObj = JsObject()
                    doneObj.set("done", JsValue(true))
                    doneObj.set("value", JsValue.NULL)
                    return JsValue(doneObj)
                }
            }
        }))

        obj.set("closed", JsValue(false))

        return JsValue(obj)
    }
}

// ============================================================================
// Base64Codec — Base64 编解码工具
// ============================================================================

/// Base64 编解码工具
public class Base64Codec {
    private static let BASE64_CHARS: String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

    /// 将字节数组编码为 Base64 字符串
    public static func encode(data: Array<UInt8>): String {
        let sb = StringBuilder()
        var i = 0
        let len = data.size

        while (i + 2 < len) {
            let b0 = Int64(data[Int64(i)])
            let b1 = Int64(data[Int64(i + 1)])
            let b2 = Int64(data[Int64(i + 2)])

            sb.append(base64Char((b0 >> 2) & 0x3F))
            sb.append(base64Char(((b0 & 0x03) << 4) | ((b1 >> 4) & 0x0F)))
            sb.append(base64Char(((b1 & 0x0F) << 2) | ((b2 >> 6) & 0x03)))
            sb.append(base64Char(b2 & 0x3F))

            i += 3
        }

        if (i < len) {
            let b0 = Int64(data[Int64(i)])
            sb.append(base64Char((b0 >> 2) & 0x3F))
            sb.append(base64Char((b0 & 0x03) << 4))

            if (i + 1 < len) {
                let b1 = Int64(data[Int64(i + 1)])
                sb.append(base64Char(((b1 & 0x0F) << 2)))
            } else {
                sb.append('=')
            }
            sb.append('=')
        }

        return sb.toString()
    }

    /// 将 Base64 字符串解码为字节数组
    public static func decode(str: String): Array<UInt8> {
        let result = ArrayList<UInt8>()
        var buffer: Int64 = 0
        var bits: Int64 = 0

        for (c in str) {
            if (c == '=') { break }
            let val = base64Value(c)
            if (val < 0) { continue }
            buffer = (buffer << 6) | val
            bits += 6
            if (bits >= 8) {
                bits -= 8
                result.append(UInt8((buffer >> bits) & 0xFF))
            }
        }

        return result.toArray()
    }

    private static func base64Char(index: Int64): Char {
        return BASE64_CHARS[Int64(index)]
    }

    private static func base64Value(c: Char): Int64 {
        if (c >= 'A' && c <= 'Z') { return Int64(c) - Int64('A') }
        if (c >= 'a' && c <= 'z') { return Int64(c) - Int64('a') + 26 }
        if (c >= '0' && c <= '9') { return Int64(c) - Int64('0') + 52 }
        if (c == '+') { return 62 }
        if (c == '/') { return 63 }
        return -1
    }
}

// ============================================================================
// BlobModule — Blob/File 模块导出
// ============================================================================

/// Blob/File 模块导出 — 将 Blob/File 注册到全局
public class BlobModule {
    /// 将 Blob/File 注册到全局环境
    public static func registerGlobals(env: Environment): Unit {
        // Blob 构造函数
        env.define("Blob", Interpreter.makeNativeFn("Blob") { args =>
            var data = Array<UInt8>()
            var mimeType = ""

            // 解析第一个参数 (blobParts)
            if (args.size >= 1) {
                match (args[0].arrayData) {
                    case Some(arr) => {
                        let bytes = ArrayList<UInt8>()
                        for (v in arr) {
                            bytes.append(UInt8(Int64(Interpreter.jsToNumber(v))))
                        }
                        data = bytes.toArray()
                    }
                    case None => {
                        // 尝试从字符串创建
                        let str = Interpreter.jsToString(args[0])
                        data = Utf8Codec.encode(str)
                    }
                }
            }

            // 解析第二个参数 (options)
            if (args.size >= 2) {
                match (args[1].objectData) {
                    case Some(obj) => {
                        let typeVal = obj.get("type")
                        if (typeVal.valueType == JsValueType.String) {
                            mimeType = typeVal.stringValue.toString()
                        }
                    }
                    case None => ()
                }
            }

            let blob = Blob(data, mimeType)
            return blob.toJsValue()
        }, false)

        // File 构造函数
        env.define("File", Interpreter.makeNativeFn("File") { args =>
            var data = Array<UInt8>()
            var name = "unknown"
            var mimeType = ""
            var lastModified = Int64(-1)

            // 解析第一个参数 (fileParts)
            if (args.size >= 1) {
                match (args[0].arrayData) {
                    case Some(arr) => {
                        let bytes = ArrayList<UInt8>()
                        for (v in arr) {
                            bytes.append(UInt8(Int64(Interpreter.jsToNumber(v))))
                        }
                        data = bytes.toArray()
                    }
                    case None => {
                        let str = Interpreter.jsToString(args[0])
                        data = Utf8Codec.encode(str)
                    }
                }
            }

            // 解析第二个参数 (fileName)
            if (args.size >= 2) {
                name = Interpreter.jsToString(args[1])
            }

            // 解析第三个参数 (options)
            if (args.size >= 3) {
                match (args[2].objectData) {
                    case Some(obj) => {
                        let typeVal = obj.get("type")
                        if (typeVal.valueType == JsValueType.String) {
                            mimeType = typeVal.stringValue.toString()
                        }
                        let lmVal = obj.get("lastModified")
                        if (lmVal.valueType == JsValueType.Number) {
                            lastModified = Int64(Interpreter.jsToNumber(lmVal))
                        }
                    }
                    case None => ()
                }
            }

            let options = FileOptions(mimeType, lastModified)
            let file = File(data, name, options)
            return file.toJsValue()
        }, false)
    }
}
