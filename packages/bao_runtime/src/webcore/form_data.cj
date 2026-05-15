// FormData - 表单数据
// 对应 Bun: src/runtime/webcore/FormData.zig
// 严格翻译自: src/runtime/webcore/FormData.zig
package bao_runtime.webcore

import bao_core.*
import bao_collections.*

// ============================================================================
// FormDataField - FormData 字段
// 对应 Bun: FormData.Field
// ============================================================================

/// FormData 字段
/// 对应 Bun: FormData.Field
public class FormDataField {
    /// 字段名
    public var name: String
    /// 字段值
    public var value: String
    /// 二进制值
    public var binaryValue: Array<UInt8>
    /// 文件名
    public var filename: String
    /// 内容类型
    public var contentType: String
    /// 是否为文件
    public var isFile: Bool

    public init(name: String, value: String) {
        this.name = name
        this.value = value
        binaryValue = Array<UInt8>()
        filename = ""
        contentType = ""
        isFile = false
    }

    public init(name: String, value: String, filename: String, contentType: String) {
        this.name = name
        this.value = value
        binaryValue = Array<UInt8>()
        this.filename = filename
        this.contentType = contentType
        isFile = true
    }

    public init(name: String, binaryValue: Array<UInt8>, filename: String, contentType: String) {
        this.name = name
        value = ""
        this.binaryValue = binaryValue
        this.filename = filename
        this.contentType = contentType
        isFile = true
    }
}

// ============================================================================
// FormData - 表单数据
// 对应 Bun: src/runtime/webcore/FormData.zig FormData
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/FormData
// ============================================================================

/// FormData — 表单数据
/// 对应 Web API: FormData
/// 对应 Bun: src/runtime/webcore/FormData.zig FormData
public class FormData {
    /// 字段列表
    /// 对应 Bun: FormData.fields (Map)
    private var fields: ArrayList<FormDataField>

    public init() {
        fields = ArrayList<FormDataField>()
    }

    /// 追加字段
    /// 对应 Web API: formData.append(name, value)
    /// 对应 Bun: FormData.append
    public func append(name: String, value: String): Unit {
        fields.append(FormDataField(name, value))
    }

    /// 追加文件字段
    /// 对应 Web API: formData.append(name, blob, filename)
    public func append(name: String, value: String, filename: String, contentType: String): Unit {
        fields.append(FormDataField(name, value, filename, contentType))
    }

    /// 追加二进制文件字段
    public func append(name: String, binaryValue: Array<UInt8>, filename: String, contentType: String): Unit {
        fields.append(FormDataField(name, binaryValue, filename, contentType))
    }

    /// 设置字段 (覆盖已有值)
    /// 对应 Web API: formData.set(name, value)
    public func set(name: String, value: String): Unit {
        // 先删除已有的
        var i = 0
        while (i < fields.size) {
            if (fields[Int64(i)].name == name) {
                fields.removeAt(Int64(i))
            } else {
                i += 1
            }
        }
        fields.append(FormDataField(name, value))
    }

    /// 获取指定字段值
    /// 对应 Web API: formData.get(name)
    public func get(name: String): ?String {
        for (field in fields) {
            if (field.name == name) {
                return Some(field.value)
            }
        }
        return None
    }

    /// 获取指定字段的所有值
    /// 对应 Web API: formData.getAll(name)
    public func getAll(name: String): ArrayList<String> {
        let result = ArrayList<String>()
        for (field in fields) {
            if (field.name == name) {
                result.append(field.value)
            }
        }
        return result
    }

    /// 判断是否存在指定字段
    /// 对应 Web API: formData.has(name)
    public func has(name: String): Bool {
        for (field in fields) {
            if (field.name == name) {
                return true
            }
        }
        return false
    }

    /// 删除指定字段
    /// 对应 Web API: formData.delete(name)
    public func delete(name: String): Unit {
        var i = 0
        while (i < fields.size) {
            if (fields[Int64(i)].name == name) {
                fields.removeAt(Int64(i))
            } else {
                i += 1
            }
        }
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

    /// 获取所有字段值
    /// 对应 Web API: formData.values()
    public func values(): ArrayList<String> {
        let result = ArrayList<String>()
        for (field in fields) {
            result.append(field.value)
        }
        return result
    }

    /// 获取所有 [name, value] 对
    /// 对应 Web API: formData.entries()
    public func entries(): ArrayList<(String, String)> {
        let result = ArrayList<(String, String)>()
        for (field in fields) {
            result.append((field.name, field.value))
        }
        return result
    }

    /// 遍历所有字段
    /// 对应 Web API: formData.forEach(callback)
    public func forEach(callback: (String, String, FormData) -> Unit): Unit {
        let self = this
        for (field in fields) {
            callback(field.name, field.value, self)
        }
    }

    /// 获取字段数量
    public func count(): Int64 {
        return fields.size
    }

    /// 编码为 URL 查询字符串 (application/x-www-form-urlencoded)
    /// 对应 Bun: FormData Encoding.URLEncoded
    public func toURLEncoded(): String {
        let sb = StringBuilder()
        var first = true
        for (field in fields) {
            if (!first) { sb.append("&") }
            first = false
            sb.append(urlEncode(field.name))
            sb.append("=")
            sb.append(urlEncode(field.value))
        }
        return sb.toString()
    }

    /// 编码为 multipart/form-data 格式
    /// 对应 Bun: FormData Encoding.Multipart
    public func toMultipart(boundary: String): Array<UInt8> {
        let sb = StringBuilder()
        for (field in fields) {
            sb.append("--")
            sb.append(boundary)
            sb.append("\r\n")
            if (field.isFile) {
                sb.append("Content-Disposition: form-data; name=\"${field.name}\"; filename=\"${field.filename}\"\r\n")
                if (field.contentType.length > 0) {
                    sb.append("Content-Type: ${field.contentType}\r\n")
                }
            } else {
                sb.append("Content-Disposition: form-data; name=\"${field.name}\"\r\n")
            }
            sb.append("\r\n")
            sb.append(field.value)
            sb.append("\r\n")
        }
        sb.append("--")
        sb.append(boundary)
        sb.append("--\r\n")
        return Utf8Codec.encode(sb.toString())
    }

    /// 从 URL 查询字符串解析 FormData
    /// 对应 Bun: FormData.toJS URLEncoded path
    public static func fromURLQuery(query: String): FormData {
        let form = FormData()
        if (query.length == 0) { return form }
        let pairs = query.split("&")
        for (pair in pairs) {
            let eqIdx = pair.indexOf("=")
            if (eqIdx >= 0) {
                let name = urlDecode(pair.substring(0, eqIdx))
                let value = urlDecode(pair.substring(eqIdx + 1))
                form.append(name, value)
            } else {
                let name = urlDecode(pair)
                form.append(name, "")
            }
        }
        return form
    }

    /// 从 multipart 数据解析 FormData
    /// 对应 Bun: FormData.toJSFromMultipartData
    public static func fromMultipart(input: Array<UInt8>, boundary: String): FormData {
        let form = FormData()
        let text = Utf8Codec.decode(input)
        let delimiter = "--${boundary}"
        let parts = text.split(delimiter)

        for (i in 1..parts.size - 1) {
            let part = parts[Int64(i)]
            // 移除前导 \r\n
            var trimmed = part
            if (trimmed.startsWith("\r\n")) {
                trimmed = trimmed.substring(2)
            }
            if (trimmed.startsWith("--")) {
                continue
            }

            // 分离 header 和 body
            let headerEndIdx = trimmed.indexOf("\r\n\r\n")
            if (headerEndIdx >= 0) {
                let headerSection = trimmed.substring(0, headerEndIdx)
                let body = trimmed.substring(headerEndIdx + 4)
                // 移除末尾 \r\n
                var bodyText = body
                if (bodyText.endsWith("\r\n")) {
                    bodyText = bodyText.substring(0, bodyText.length - 2)
                }

                // 解析 Content-Disposition
                let nameIdx = headerSection.indexOf("name=\"")
                if (nameIdx >= 0) {
                    let nameStart = nameIdx + 6
                    let nameEnd = headerSection.indexOf("\"", nameStart)
                    if (nameEnd >= 0) {
                        let name = headerSection.substring(nameStart, nameEnd)
                        // 检查是否有 filename
                        let filenameIdx = headerSection.indexOf("filename=\"")
                        if (filenameIdx >= 0) {
                            let filenameStart = filenameIdx + 10
                            let filenameEnd = headerSection.indexOf("\"", filenameStart)
                            if (filenameEnd >= 0) {
                                let filename = headerSection.substring(filenameStart, filenameEnd)
                                // 解析 Content-Type
                                var ct = "application/octet-stream"
                                let ctIdx = headerSection.indexOf("Content-Type: ")
                                if (ctIdx >= 0) {
                                    let ctStart = ctIdx + 14
                                    let ctEnd = headerSection.indexOf("\r\n", ctStart)
                                    if (ctEnd >= 0) {
                                        ct = headerSection.substring(ctStart, ctEnd)
                                    } else {
                                        ct = headerSection.substring(ctStart)
                                    }
                                }
                                form.append(name, bodyText, filename, ct)
                            }
                        } else {
                            form.append(name, bodyText)
                        }
                    }
                }
            }
        }
        return form
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
            JsValue.UNDEFINED
        }))

        obj.set("set", JsValue.nativeFunction(JsNativeFunction("set") { args =>
            if (args.size >= 2) {
                let name = Interpreter.jsToString(args[0])
                let value = Interpreter.jsToString(args[1])
                self.set(name, value)
            }
            JsValue.UNDEFINED
        }))

        obj.set("get", JsValue.nativeFunction(JsNativeFunction("get") { args =>
            if (args.size >= 1) {
                let name = Interpreter.jsToString(args[0])
                match (self.get(name)) {
                    case Some(v) => return JsValue(BaoString(v))
                    case None => return JsValue.NULL
                }
            }
            JsValue.NULL
        }))

        obj.set("has", JsValue.nativeFunction(JsNativeFunction("has") { args =>
            if (args.size >= 1) {
                return JsValue(self.has(Interpreter.jsToString(args[0])))
            }
            JsValue(false)
        }))

        obj.set("delete", JsValue.nativeFunction(JsNativeFunction("delete") { args =>
            if (args.size >= 1) {
                self.delete(Interpreter.jsToString(args[0]))
            }
            JsValue.UNDEFINED
        }))

        return JsValue(obj)
    }

    /// URL 编码辅助函数
    private static func urlEncode(s: String): String {
        let sb = StringBuilder()
        for (i in 0..s.length) {
            let c = s[Int64(i)]
            if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') ||
                c == '-' || c == '_' || c == '.' || c == '~') {
                sb.append(Char(c))
            } else if (c == ' ') {
                sb.append("+")
            } else {
                let bytes = Utf8Codec.encode(Char(c).toString())
                for (b in bytes) {
                    sb.append("%")
                    sb.append(Int64(b).toHexString().toUpperCase())
                }
            }
        }
        return sb.toString()
    }

    /// URL 解码辅助函数
    private static func urlDecode(s: String): String {
        let sb = StringBuilder()
        var i = 0
        while (i < s.length) {
            let c = s[Int64(i)]
            if (c == '+') {
                sb.append(" ")
                i += 1
            } else if (c == '%' && i + 2 < s.length) {
                let hex = s.substring(Int64(i) + 1, Int64(i) + 3)
                try {
                    let byte = UInt8(Int64.parse(hex, 16))
                    sb.append(Char(Int64(byte)))
                } catch (_: Exception) {
                    sb.append(Char(c))
                }
                i += 3
            } else {
                sb.append(Char(c))
                i += 1
            }
        }
        return sb.toString()
    }
}
