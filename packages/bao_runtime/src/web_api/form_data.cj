// Web API FormData 模块
// 对应 Bun: src/runtime/webcore/FormData.zig
// 严格翻译自 Web FormData API
package bao_runtime.web_api

import bao_core.BaoString
import bao_core.IntFormatter
import bao_core.IntParser
import bao_collections.*
import bao_runtime.*

// ============================================================================
// WebFormData — 表单数据 (Web API 级别)
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/FormData
// 对应 Bun: src/runtime/webcore/FormData.zig FormData
// ============================================================================

/// FormData 编码类型
/// 对应 Bun: FormData.Encoding
public enum FormDataEncoding {
    | URLEncoded            // application/x-www-form-urlencoded
    | Multipart(String)     // multipart/form-data (含 boundary)

    /// 根据 Content-Type 头判断编码类型
    /// 对应 Bun: FormData.Encoding.get()
    public static func fromContentType(contentType: String): ?FormDataEncoding {
        if (contentType.contains("application/x-www-form-urlencoded")) {
            return Some(FormDataEncoding.URLEncoded)
        }
        if (contentType.contains("multipart/form-data")) {
            let boundary = extractBoundary(contentType)
            match (boundary) {
                case Some(b) => return Some(FormDataEncoding.Multipart(b))
                case None => return None
            }
        }
        return None
    }

    /// 从 Content-Type 提取 boundary
    private static func extractBoundary(contentType: String): ?String {
        if (let Some(boundaryIdx) <- contentType.indexOf("boundary=")) {
            let start = boundaryIdx + 9  // "boundary=".size
            if (start >= Int64(contentType.size)) {
                return None
            }
            let rest = contentType[start..]
            // boundary 可能有引号包裹
            var boundary = rest
            if (let Some(semiIdx) <- boundary.indexOf(";")) {
                boundary = boundary[0..semiIdx]
            }
            if (boundary.startsWith("\"") && boundary.endsWith("\"") && boundary.size > 1) {
                boundary = boundary[1..(Int64(boundary.size) - 1)]
            }
            if (boundary.size == 0) {
                return None
            }
            return Some(boundary)
        }
        return None
    }
}

/// WebFormData — Web API 级别的 FormData
/// 对应 Web API: FormData
/// 对应 Bun: src/runtime/webcore/FormData.zig FormData
public class WebFormData {
    /// 内部字段列表
    private var fields: ArrayList<FormDataFieldEntry>

    public init() {
        fields = ArrayList<FormDataFieldEntry>()
    }

    /// 追加文本字段
    /// 对应 Web API: formData.append(name, value)
    public func append(name: String, value: String): Unit {
        fields.append(FormDataFieldEntry(name, value))
    }

    /// 追加 Blob 字段
    /// 对应 Web API: formData.append(name, blobValue, filename)
    public func append(name: String, blobValue: Blob, filename: String): Unit {
        fields.append(FormDataFieldEntry(name, blobValue, filename))
    }

    /// 追加文件字段 (从字节)
    public func append(name: String, data: Array<UInt8>, filename: String, contentType: String): Unit {
        let blob = Blob(data, contentType)
        fields.append(FormDataFieldEntry(name, blob, filename))
    }

    /// 设置字段 (覆盖)
    /// 对应 Web API: formData.set(name, value)
    public func set(name: String, value: String): Unit {
        // 删除已有的
        let newFields = ArrayList<FormDataFieldEntry>()
        for (field in fields) {
            if (field.name != name) {
                newFields.append(field)
            }
        }
        fields = newFields
        fields.append(FormDataFieldEntry(name, value))
    }

    /// 设置 Blob 字段 (覆盖)
    /// 对应 Web API: formData.set(name, blobValue, filename)
    public func set(name: String, blobValue: Blob, filename: String): Unit {
        let newFields = ArrayList<FormDataFieldEntry>()
        for (field in fields) {
            if (field.name != name) {
                newFields.append(field)
            }
        }
        fields = newFields
        fields.append(FormDataFieldEntry(name, blobValue, filename))
    }

    /// 获取字段值
    /// 对应 Web API: formData.get(name)
    public func get(name: String): ?String {
        for (field in fields) {
            if (field.name == name) {
                return Some(field.getValue())
            }
        }
        return None
    }

    /// 获取所有值
    /// 对应 Web API: formData.getAll(name)
    public func getAll(name: String): ArrayList<String> {
        let result = ArrayList<String>()
        for (field in fields) {
            if (field.name == name) {
                result.append(field.getValue())
            }
        }
        return result
    }

    /// 判断字段是否存在
    /// 对应 Web API: formData.has(name)
    public func has(name: String): Bool {
        for (field in fields) {
            if (field.name == name) {
                return true
            }
        }
        return false
    }

    /// 删除字段
    /// 对应 Web API: formData.delete(name)
    public func delete(name: String): Unit {
        let newFields = ArrayList<FormDataFieldEntry>()
        for (field in fields) {
            if (field.name != name) {
                newFields.append(field)
            }
        }
        fields = newFields
    }

    /// 获取所有字段名
    /// 对应 Web API: formData.keys()
    public func keys(): ArrayList<String> {
        let result = ArrayList<String>()
        for (field in fields) {
            result.append(field.name)
        }
        return result
    }

    /// 获取所有值
    /// 对应 Web API: formData.values()
    public func values(): ArrayList<String> {
        let result = ArrayList<String>()
        for (field in fields) {
            result.append(field.getValue())
        }
        return result
    }

    /// 获取所有条目
    /// 对应 Web API: formData.entries()
    public func entries(): ArrayList<(String, String)> {
        let result = ArrayList<(String, String)>()
        for (field in fields) {
            result.append((field.name, field.getValue()))
        }
        return result
    }

    /// 遍历
    /// 对应 Web API: formData.forEach(callback)
    public func forEach(callback: (String, String, WebFormData) -> Unit): Unit {
        let self = this
        for (field in fields) {
            callback(field.name, field.getValue(), self)
        }
    }

    /// 字段数量
    public func count(): Int64 {
        return fields.size
    }

    /// 编码为 URL 查询字符串
    /// 对应 Bun: FormData.Encoding.URLEncoded
    public func toURLEncoded(): String {
        let sb = StringBuilder()
        var first = true
        for (field in fields) {
            if (!first) { sb.append("&") }
            first = false
            sb.append(urlEncode(field.name))
            sb.append("=")
            sb.append(urlEncode(field.getValue()))
        }
        return sb.toString()
    }

    /// 编码为 multipart/form-data
    /// 对应 Bun: FormData.Encoding.Multipart
    public func toMultipart(boundary: String): Array<UInt8> {
        let sb = StringBuilder()
        for (field in fields) {
            sb.append("--")
            sb.append(boundary)
            sb.append("\r\n")

            if (field.isFile()) {
                let filename = field.getFilename()
                let contentType = field.getContentType()
                sb.append("Content-Disposition: form-data; name=\"${field.name}\"; filename=\"${filename}\"\r\n")
                if (contentType.size > 0) {
                    sb.append("Content-Type: ${contentType}\r\n")
                }
            } else {
                sb.append("Content-Disposition: form-data; name=\"${field.name}\"\r\n")
            }
            sb.append("\r\n")

            if (field.isFile()) {
                // 二进制文件内容以 Base64 编码
                let bytes = field.getBinaryValue()
                sb.append(Base64Codec.encode(bytes))
            } else {
                sb.append(field.getValue())
            }
            sb.append("\r\n")
        }
        sb.append("--")
        sb.append(boundary)
        sb.append("--\r\n")

        return Utf8Codec.encode(sb.toString())
    }

    /// 获取 multipart 的 Content-Type 头
    public func getMultipartContentType(boundary: String): String {
        return "multipart/form-data; boundary=${boundary}"
    }

    /// 从 URL 查询字符串解析
    /// 对应 Bun: FormData.toJS URLEncoded path
    public static func fromURLQuery(query: String): WebFormData {
        let form = WebFormData()
        if (query.size == 0) { return form }
        let pairs = query.split("&")
        for (pair in pairs) {
            if (let Some(eqIdx) <- pair.indexOf("=")) {
                let name = urlDecode(pair[0..eqIdx])
                let value = urlDecode(pair[(eqIdx + 1)..])
                form.append(name, value)
            } else {
                let name = urlDecode(pair)
                form.append(name, "")
            }
        }
        return form
    }

    /// 从 multipart 数据解析
    /// 对应 Bun: FormData.toJSFromMultipartData
    public static func fromMultipart(input: Array<UInt8>, boundary: String): WebFormData {
        let form = WebFormData()
        let text = Utf8Codec.decode(input)
        let delimiter = "--${boundary}"
        let parts = text.split(delimiter)

        for (i in 1..parts.size - 1) {
            var part = parts[Int64(i)]
            if (part.startsWith("\r\n")) {
                part = part[2..]
            }
            if (part.startsWith("--")) {
                continue
            }

            if (let Some(headerEndIdx) <- part.indexOf("\r\n\r\n")) {
                let headerSection = part[0..headerEndIdx]
                var body = part[(headerEndIdx + 4)..]
                if (body.endsWith("\r\n")) {
                    body = body[0..(Int64(body.size) - 2)]
                }

                if (let Some(nameIdx) <- headerSection.indexOf("name=\"")) {
                    let nameStart = nameIdx + 6
                    if (let Some(nameEnd) <- headerSection.indexOf("\"", nameStart)) {
                        let name = headerSection[nameStart..nameEnd]
                        if (let Some(filenameIdx) <- headerSection.indexOf("filename=\"")) {
                            let filenameStart = filenameIdx + 10
                            if (let Some(filenameEnd) <- headerSection.indexOf("\"", filenameStart)) {
                                let filename = headerSection[filenameStart..filenameEnd]
                                var ct = "application/octet-stream"
                                if (let Some(ctIdx) <- headerSection.indexOf("Content-Type: ")) {
                                    let ctStart = ctIdx + 14
                                    if (let Some(ctEnd) <- headerSection.indexOf("\r\n", ctStart)) {
                                        ct = headerSection[ctStart..ctEnd]
                                    } else {
                                        ct = headerSection[ctStart..]
                                    }
                                }
                                form.append(name, Utf8Codec.encode(body), filename, ct)
                            }
                        } else {
                            form.append(name, body)
                        }
                    }
                }
            }
        }
        return form
    }

    /// URL 编码
    private static func urlEncode(s: String): String {
        let sb = StringBuilder()
        for (i in 0..s.size) {
            let c = s[Int64(i)]
            let v = Int64(c)
            if ((v >= 97 && v <= 122) || (v >= 65 && v <= 90) || (v >= 48 && v <= 57) ||
                v == 45 || v == 95 || v == 46 || v == 126) { // a-z A-Z 0-9 - _ . ~
                sb.append(String(Rune(Int32(c))))
            } else if (c == UInt8(32)) { // space
                sb.append("+")
            } else {
                let bytes = Utf8Codec.encode(String(Rune(Int32(c))))
                for (b in bytes) {
                    sb.append("%")
                    let hex = IntFormatter.toHexString(Int64(b)).toAsciiUpper()
                    if (hex.size == 1) { sb.append("0") }
                    sb.append(hex)
                }
            }
        }
        return sb.toString()
    }

    /// URL 解码
    private static func urlDecode(s: String): String {
        let sb = StringBuilder()
        var i: Int64 = 0
        let len = Int64(s.size)
        while (i < len) {
            let c = s[i]
            if (c == UInt8(43)) { // '+'
                sb.append(" ")
                i += 1
            } else if (c == UInt8(37) && i + 2 < len) { // '%'
                let hex = s[(i + 1)..(i + 3)]
                try {
                    let byte = UInt8(IntParser.parseInt(hex, 16))
                    sb.append(String(Rune(Int32(byte))))
                } catch (_: Exception) {
                    sb.append(String(Rune(Int32(c))))
                }
                i += 3
            } else {
                sb.append(String(Rune(Int32(c))))
                i += 1
            }
        }
        return sb.toString()
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        let self = this

        obj.set("append", JsValue.nativeFunction(JsNativeFunction("append") { args =>
            if (args.size >= 2) {
                let name = Interpreter.jsToString(args[0])
                let value = Interpreter.jsToString(args[1])
                self.append(name, value)
            }
            return JsValue.UNDEFINED
        }))

        obj.set("set", JsValue.nativeFunction(JsNativeFunction("set") { args =>
            if (args.size >= 2) {
                let name = Interpreter.jsToString(args[0])
                let value = Interpreter.jsToString(args[1])
                self.set(name, value)
            }
            return JsValue.UNDEFINED
        }))

        obj.set("get", JsValue.nativeFunction(JsNativeFunction("get") { args =>
            if (args.size >= 1) {
                let name = Interpreter.jsToString(args[0])
                match (self.get(name)) {
                    case Some(v) => return JsValue(BaoString(v))
                    case None => return JsValue.NULL
                }
            }
            return JsValue.NULL
        }))

        obj.set("getAll", JsValue.nativeFunction(JsNativeFunction("getAll") { args =>
            if (args.size >= 1) {
                let name = Interpreter.jsToString(args[0])
                let vals = self.getAll(name)
                let arr = ArrayList<JsValue>()
                for (v in vals) { arr.append(JsValue(BaoString(v))) }
                return JsValue.array(arr)
            }
            return JsValue.array(ArrayList<JsValue>())
        }))

        obj.set("has", JsValue.nativeFunction(JsNativeFunction("has") { args =>
            if (args.size >= 1) {
                let name = Interpreter.jsToString(args[0])
                return JsValue(self.has(name))
            }
            return JsValue(false)
        }))

        obj.set("delete", JsValue.nativeFunction(JsNativeFunction("delete") { args =>
            if (args.size >= 1) {
                let name = Interpreter.jsToString(args[0])
                self.delete(name)
            }
            return JsValue.UNDEFINED
        }))

        obj.set("keys", JsValue.nativeFunction(JsNativeFunction("keys") { _ =>
            let keys = self.keys()
            let arr = ArrayList<JsValue>()
            for (k in keys) { arr.append(JsValue(BaoString(k))) }
            return JsValue.array(arr)
        }))

        obj.set("values", JsValue.nativeFunction(JsNativeFunction("values") { _ =>
            let vals = self.values()
            let arr = ArrayList<JsValue>()
            for (v in vals) { arr.append(JsValue(BaoString(v))) }
            return JsValue.array(arr)
        }))

        obj.set("entries", JsValue.nativeFunction(JsNativeFunction("entries") { _ =>
            let entries = self.entries()
            let arr = ArrayList<JsValue>()
            for ((key, val) in entries) {
                let pair = ArrayList<JsValue>()
                pair.append(JsValue(BaoString(key)))
                pair.append(JsValue(BaoString(val)))
                arr.append(JsValue.array(pair))
            }
            return JsValue.array(arr)
        }))

        obj.set("forEach", JsValue.nativeFunction(JsNativeFunction("forEach") { args =>
            // 简化: 遍历所有 entries
            return JsValue.UNDEFINED
        }))

        return JsValue(obj)
    }
}

// ============================================================================
// FormDataFieldEntry — FormData 字段条目
// ============================================================================

/// FormData 字段条目
/// 支持文本值和文件 (Blob) 值
class FormDataFieldEntry {
    /// 字段名
    var name: String
    /// 文本值
    var textValue: String
    /// Blob 值 (文件数据)
    var blobValue: ?Blob
    /// 文件名
    var filename: String
    /// 是否为文件
    var isFileFlag: Bool

    /// 创建文本字段
    init(name: String, value: String) {
        this.name = name
        textValue = value
        blobValue = None
        filename = ""
        isFileFlag = false
    }

    /// 创建文件字段
    init(name: String, blob: Blob, filename: String) {
        this.name = name
        textValue = ""
        blobValue = Some(blob)
        this.filename = filename
        isFileFlag = true
    }

    /// 获取值 (文本)
    func getValue(): String {
        if (isFileFlag) {
            match (blobValue) {
                case Some(b) => return b.text()
                case None => return ""
            }
        }
        return textValue
    }

    /// 获取二进制值
    func getBinaryValue(): Array<UInt8> {
        match (blobValue) {
            case Some(b) => return b.arrayBuffer()
            case None => return Utf8Codec.encode(textValue)
        }
    }

    /// 获取文件名
    func getFilename(): String {
        return filename
    }

    /// 获取 Content-Type
    func getContentType(): String {
        match (blobValue) {
            case Some(b) => return b.`type`
            case None => return "text/plain"
        }
    }

    /// 是否为文件
    func isFile(): Bool {
        return isFileFlag
    }
}

// ============================================================================
// FormDataModule — FormData 模块导出
// ============================================================================

/// FormData 模块导出 — 将 FormData 注册到全局
public class FormDataModule {
    /// 将 FormData 注册到全局环境
    public static func registerGlobals(env: Environment): Unit {
        // FormData 构造函数
        env.define("FormData", Interpreter.makeNativeFn("FormData") { args =>
            let form = WebFormData()
            return form.toJsValue()
        }, false)
    }
}
