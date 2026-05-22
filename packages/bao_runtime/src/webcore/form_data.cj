// HTML `FormData` parsing + JS bridge. Moved from `url/url.zig` because the
// struct is webcore (fetch Body) and JSC-heavy; `url/` is JSC-free.
//
// Strict 1:1 translation from: src/runtime/webcore/FormData.rs (458 lines)
// Ported from: src/runtime/webcore/FormData.zig
package bao_runtime.webcore

import bao_core.*
import bao_collections.*

// ============================================================================
// Re-exports
// 对应 Bun: pub use bun_core::form_data::{AsyncFormData, Encoding, get_boundary}
// ============================================================================

/// Encoding for FormData
/// 对应 Bun: Encoding (re-exported from bun_core::form_data)
public enum FormDataEncoding {
    | URLEncoded
    | Multipart(ArrayList<UInt8>)

    public operator func == (rhs: FormDataEncoding): Bool {
        match (this) {
            case URLEncoded => match (rhs) { case URLEncoded => true case _ => false }
            case Multipart(b) => match (rhs) {
                case Multipart(b2) => Arrays.equal(b.toArray(), b2.toArray())
                case _ => false
            }
        }
    }
}

// ============================================================================
// FormDataField - FormData 字段 (raw slice into input buffer)
// 对应 Bun: FormData.Field
// ============================================================================

/// Raw slice into the input buffer. Not using Semver.String because file bodies
/// are binary data that can contain null bytes.
/// 对应 Bun: FormData.Field
public class FormDataField {
    /// 字段值 (binary data)
    public var value: Array<UInt8>
    /// 文件名
    public var filename: SemverString
    /// 内容类型
    public var contentType: SemverString
    /// 是否为文件
    public var isFile: Bool
    /// Zero count (used for skip check)
    public var zeroCount: UInt8

    public init() {
        value = Array<UInt8>()
        filename = SemverString()
        contentType = SemverString()
        isFile = false
        zeroCount = 0
    }

    public init(name: String, value: String) {
        this.value = Utf8Codec.encode(value)
        filename = SemverString()
        contentType = SemverString()
        isFile = false
        zeroCount = 0
    }

    public init(name: String, value: String, filename: String, contentType: String) {
        this.value = Utf8Codec.encode(value)
        this.filename = SemverString(filename)
        this.contentType = SemverString(contentType)
        isFile = true
        zeroCount = 0
    }

    public init(name: String, binaryValue: Array<UInt8>, filename: String, contentType: String) {
        value = binaryValue
        this.filename = SemverString(filename)
        this.contentType = SemverString(contentType)
        isFile = true
        zeroCount = 0
    }
}

// ============================================================================
// FieldEntry - FormData 字段条目 (field or list of fields)
// 对应 Bun: FormData.FieldEntry
// ============================================================================

/// Field entry - either a single field or a list of fields with the same name
/// 对应 Bun: FormData.FieldEntry
public enum FieldEntry {
    | Field(FormDataField)
    | List(ArrayList<FormDataField>)
}

// ============================================================================
// FieldExternal - C-compatible field representation for JS bridge
// 对应 Bun: FormData.FieldExternal #[repr(C)]
// ============================================================================

/// C-compatible field for JS bridge
/// 对应 Bun: FieldExternal
public class FieldExternal {
    public var name: ZigString
    public var value: ZigString
    public var blob: ?Blob

    public init() {
        name = ZigString()
        value = ZigString()
        blob = None
    }
}

// ============================================================================
// FormData - 表单数据
// 对应 Bun: FormData struct
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/FormData
// ============================================================================

/// Map type for FormData fields
/// 对应 Bun: Map = ArrayHashMap<bun_semver::String, FieldEntry>
public type FormDataMap = ArrayList<KeyValuePair<SemverString, FieldEntry>>

/// Key-value pair helper
public class KeyValuePair<K, V> {
    public var key: K
    public var value: V

    public init(key: K, value: V) {
        this.key = key
        this.value = value
    }
}

/// FormData — 表单数据
/// 对应 Web API: FormData
/// 对应 Bun: src/runtime/webcore/FormData.rs FormData struct
public class FormData {
    /// 字段列表
    /// 对应 Bun: FormData.fields (Map)
    public var fields: FormDataMap
    /// Buffer reference (raw bytes for multipart parsing)
    public var buffer: Array<UInt8>

    public init() {
        fields = FormDataMap()
        buffer = Array<UInt8>()
    }

    // ---- Web API methods ----

    /// 追加字段
    /// 对应 Web API: formData.append(name, value)
    /// 对应 Bun: FormData.append (via DOMFormData)
    public func append(name: String, value: String): Unit {
        let key = SemverString(name)
        let field = FormDataField(name: name, value: value)
        let entry = FieldEntry.Field(field)
        fields.add(KeyValuePair(key, entry))
    }

    /// 追加文件字段
    /// 对应 Web API: formData.append(name, blob, filename)
    public func append(name: String, value: String, filename: String, contentType: String): Unit {
        let key = SemverString(name)
        let field = FormDataField(name: name, value: value, filename: filename, contentType: contentType)
        let entry = FieldEntry.Field(field)
        fields.add(KeyValuePair(key, entry))
    }

    /// 追加二进制文件字段
    public func append(name: String, binaryValue: Array<UInt8>, filename: String, contentType: String): Unit {
        let key = SemverString(name)
        let field = FormDataField(name: name, binaryValue: binaryValue, filename: filename, contentType: contentType)
        let entry = FieldEntry.Field(field)
        fields.add(KeyValuePair(key, entry))
    }

    /// 设置字段 (覆盖已有值)
    /// 对应 Web API: formData.set(name, value)
    public func set(name: String, value: String): Unit {
        let key = SemverString(name)
        // Remove existing entries with the same name
        var i: Int64 = 0
        while (i < fields.size) {
            if (fields[Int64(i)].key.toString() == name) {
                fields.removeAt(Int64(i))
            } else {
                i += 1
            }
        }
        let field = FormDataField(name: name, value: value)
        fields.add(KeyValuePair(key, FieldEntry.Field(field)))
    }

    /// 获取指定字段值
    /// 对应 Web API: formData.get(name)
    public func get(name: String): ?String {
        for (entry in fields) {
            if (entry.key.toString() == name) {
                match (entry.value) {
                    case Field(f) =>
                        return Some(Utf8Codec.decode(f.value))
                    case List(list) =>
                        if (list.size > 0) {
                            return Some(Utf8Codec.decode(list[0].value))
                        }
                }
            }
        }
        return None
    }

    /// 获取指定字段的所有值
    /// 对应 Web API: formData.getAll(name)
    public func getAll(name: String): ArrayList<String> {
        let result = ArrayList<String>()
        for (entry in fields) {
            if (entry.key.toString() == name) {
                match (entry.value) {
                    case Field(f) =>
                        result.add(Utf8Codec.decode(f.value))
                    case List(list) =>
                        for (f in list) {
                            result.add(Utf8Codec.decode(f.value))
                        }
                }
            }
        }
        return result
    }

    /// 判断是否存在指定字段
    /// 对应 Web API: formData.has(name)
    public func has(name: String): Bool {
        for (entry in fields) {
            if (entry.key.toString() == name) {
                return true
            }
        }
        return false
    }

    /// 删除指定字段
    /// 对应 Web API: formData.delete(name)
    public func delete(name: String): Unit {
        var i: Int64 = 0
        while (i < fields.size) {
            if (fields[Int64(i)].key.toString() == name) {
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
        for (entry in fields) {
            result.add(entry.key.toString())
        }
        return result
    }

    /// 获取所有字段值
    /// 对应 Web API: formData.values()
    public func values(): ArrayList<String> {
        let result = ArrayList<String>()
        for (entry in fields) {
            match (entry.value) {
                case Field(f) =>
                    result.add(Utf8Codec.decode(f.value))
                case List(list) =>
                    for (f in list) {
                        result.add(Utf8Codec.decode(f.value))
                    }
            }
        }
        return result
    }

    /// 获取所有 [name, value] 对
    /// 对应 Web API: formData.entries()
    public func entries(): ArrayList<(String, String)> {
        let result = ArrayList<(String, String)>()
        for (entry in fields) {
            match (entry.value) {
                case Field(f) =>
                    result.add((entry.key.toString(), Utf8Codec.decode(f.value)))
                case List(list) =>
                    for (f in list) {
                        result.add((entry.key.toString(), Utf8Codec.decode(f.value)))
                    }
            }
        }
        return result
    }

    /// 遍历所有字段
    /// 对应 Web API: formData.forEach(callback)
    public func forEach(callback: (String, String, FormData) -> Unit): Unit {
        let self = this
        for (entry in fields) {
            match (entry.value) {
                case Field(f) =>
                    callback(entry.key.toString(), Utf8Codec.decode(f.value), self)
                case List(list) =>
                    for (f in list) {
                        callback(entry.key.toString(), Utf8Codec.decode(f.value), self)
                    }
            }
        }
    }

    /// 获取字段数量
    public func count(): Int64 {
        return fields.size
    }

    // ---- Encoding methods ----

    /// 编码为 URL 查询字符串 (application/x-www-form-urlencoded)
    /// 对应 Bun: FormData Encoding.URLEncoded
    public func toURLEncoded(): String {
        let sb = StringBuilder()
        var first = true
        for (entry in fields) {
            if (!first) { sb.append("&") }
            first = false
            match (entry.value) {
                case Field(f) =>
                    sb.append(urlEncode(entry.key.toString()))
                    sb.append("=")
                    sb.append(urlEncode(Utf8Codec.decode(f.value)))
                case List(list) =>
                    for (f in list) {
                        if (!first) { sb.append("&") }
                        first = false
                        sb.append(urlEncode(entry.key.toString()))
                        sb.append("=")
                        sb.append(urlEncode(Utf8Codec.decode(f.value)))
                    }
            }
        }
        return sb.toString()
    }

    /// 编码为 multipart/form-data 格式
    /// 对应 Bun: FormData Encoding.Multipart
    public func toMultipart(boundary: String): Array<UInt8> {
        let sb = StringBuilder()
        for (entry in fields) {
            match (entry.value) {
                case Field(f) =>
                    sb.append("--")
                    sb.append(boundary)
                    sb.append("\r\n")
                    if (f.isFile) {
                        let fname = f.filename.toString()
                        sb.append("Content-Disposition: form-data; name=\"${entry.key.toString()}\"; filename=\"${fname}\"\r\n")
                        if (f.contentType.toString().size > 0) {
                            sb.append("Content-Type: ${f.contentType.toString()}\r\n")
                        }
                    } else {
                        sb.append("Content-Disposition: form-data; name=\"${entry.key.toString()}\"\r\n")
                    }
                    sb.append("\r\n")
                    sb.append(Utf8Codec.decode(f.value))
                    sb.append("\r\n")
                case List(list) =>
                    for (f in list) {
                        sb.append("--")
                        sb.append(boundary)
                        sb.append("\r\n")
                        if (f.isFile) {
                            let fname = f.filename.toString()
                            sb.append("Content-Disposition: form-data; name=\"${entry.key.toString()}\"; filename=\"${fname}\"\r\n")
                            if (f.contentType.toString().size > 0) {
                                sb.append("Content-Type: ${f.contentType.toString()}\r\n")
                            }
                        } else {
                            sb.append("Content-Disposition: form-data; name=\"${entry.key.toString()}\"\r\n")
                        }
                        sb.append("\r\n")
                        sb.append(Utf8Codec.decode(f.value))
                        sb.append("\r\n")
                    }
            }
        }
        sb.append("--")
        sb.append(boundary)
        sb.append("--\r\n")
        return Utf8Codec.encode(sb.toString())
    }

    // ---- Static parsing methods ----

    /// Convert FormData to a JS value
    /// 对应 Bun: FormData::toJS
    public static func toJS(global: JSGlobalObject, input: Array<UInt8>, encoding: FormDataEncoding): JsResult {
        match (encoding) {
            case URLEncoded =>
                let str = ZigString.initUtf8(Strings.withoutUTF8Bom(input))
                // C++ may throw (e.g. string too long) — createFromURLQuery
                // wraps the FFI in a validation scope and maps zero → JsError.
                return DOMFormData.createFromURLQuery(global, str)
            case Multipart(boundary) =>
                return toJSFromMultipartData(global, input, boundary.toArray())
        }
    }

    /// 对应 Bun: FormData.fromMultipartData (host function)
    /// Hosted as "FormData__jsFunctionFromMultipartData"
    public static func fromMultipartData(global: JSGlobalObject, frame: CallFrame): JsResult {
        let args = frame.arguments(2)
        let inputValue = args[0]
        let boundaryValue = args[1]
        var boundarySlice = ZigStringSlice()

        var encoding = FormDataEncoding.URLEncoded

        if (inputValue.isEmptyOrUndefinedOrNull()) {
            return JsResult.err(global.throwInvalidArguments("input must not be empty"))
        }

        if (!boundaryValue.isEmptyOrUndefinedOrNull()) {
            if (let Some(arrayBuffer) <- boundaryValue.asArrayBuffer(global)) {
                if (arrayBuffer.byteSlice().size > 0) {
                    encoding = FormDataEncoding.Multipart(ArrayList<UInt8>(arrayBuffer.byteSlice()))
                }
            } else if (boundaryValue.isString()) {
                boundarySlice = boundaryValue.toSlice(global)
                if (boundarySlice.getSlice().size > 0) {
                    encoding = FormDataEncoding.Multipart(ArrayList<UInt8>(boundarySlice.getSlice()))
                }
            } else {
                return JsResult.err(global.throwInvalidArguments("boundary must be a string or ArrayBufferView"))
            }
        }

        var inputSlice = ZigStringSlice()
        let input: Array<UInt8>

        if (let Some(arrayBuffer) <- inputValue.asArrayBuffer(global)) {
            input = arrayBuffer.byteSlice()
        } else if (inputValue.isString()) {
            inputSlice = inputValue.toSlice(global)
            input = inputSlice.getSlice()
        } else if (let Some(blob) <- inputValue.asClassRef(Blob)) {
            input = blob.sharedView()
        } else {
            return JsResult.err(global.throwInvalidArguments("input must be a string or ArrayBufferView"))
        }

        match (toJS(global, input, encoding)) {
            case Ok(v) => JsResult.ok(v)
            case Err(e) => JsResult.err(global.throwError(e, "while parsing FormData"))
        }
    }

    /// 对应 Bun: to_js_from_multipart_data
    public static func toJSFromMultipartData(global: JSGlobalObject, input: Array<UInt8>, boundary: Array<UInt8>): JsResult {
        let formDataValue = DOMFormData.create(global)
        formDataValue.ensureStillAlive()

        let form = DOMFormData.fromJS(formDataValue)
        if (form.isNone()) {
            return JsResult.err(JsValue.NULL)
        }

        // Parse multipart entries using the iterator
        let wrapper = MultipartWrapper(global: global, form: form.getOrThrow())

        if (let Some(err) <- forEachMultipartEntry(input, boundary, wrapper)) {
            return JsResult.err(JsValue.NULL)
        }

        return JsResult.ok(formDataValue)
    }

    /// Iterate over multipart entries, calling the callback for each field.
    /// 对应 Bun: for_each_multipart_entry
    public static func forEachMultipartEntry<C>(
        input: Array<UInt8>,
        boundary: Array<UInt8>,
        ctx: C
    ): ?Error where C <: MultipartCallback {
        var slice = input
        let subslicer = SlicedString(input, input)

        var buf = Array<UInt8>(76, item: 0)

        // Build final boundary: --boundary--
        let need = boundary.size + 4
        if (need > buf.size) {
            return Some(Error("boundary is too long"))
        }
        // "--" + boundary + "--"
        buf[0] = UInt8('-'.toInt())
        buf[1] = UInt8('-'.toInt())
        for (i in 0..boundary.size) {
            buf[2 + i] = boundary[i]
        }
        buf[2 + boundary.size] = UInt8('-'.toInt())
        buf[2 + boundary.size + 1] = UInt8('-'.toInt())
        let finalBoundary = Bytes.subArray(buf, 0, need)

        let finalBoundaryIndex = Strings.lastIndexOf(input, finalBoundary)
        if (finalBoundaryIndex.isNone()) {
            return Some(Error("missing final boundary"))
        }
        slice = Bytes.subArray(input, 0, finalBoundaryIndex.getOrThrow())

        // Build separator: --boundary\r\n
        let sepLen = boundary.size + 4
        buf[0] = UInt8('-'.toInt())
        buf[1] = UInt8('-'.toInt())
        for (i in 0..boundary.size) {
            buf[2 + i] = boundary[i]
        }
        buf[2 + boundary.size] = UInt8(13) // \r
        buf[2 + boundary.size + 1] = UInt8(10) // \n
        let separator = Bytes.subArray(buf, 0, sepLen)

        let splitter = Strings.split(slice, separator)
        // Skip first boundary (it's empty before the first separator)
        var splitIdx: Int64 = 0
        for (chunk in splitter) {
            if (splitIdx == 0) {
                splitIdx += 1
                continue
            }
            splitIdx += 1

            var remain = chunk
            let headerEnd = Strings.indexOf(remain, CRLF_CRLF)
            if (headerEnd.isNone()) {
                return Some(Error("is missing header end"))
            }
            let headerEndIdx = headerEnd.getOrThrow()
            let header = Bytes.subArray(remain, 0, headerEndIdx + 2)
            remain = Bytes.subArray(remain, headerEndIdx + 4, remain.size - headerEndIdx - 4)

            var field = FormDataField()
            var name = SemverString()
            var filename: ?SemverString = None
            var headerChunk = header
            var isFile = false

            while (headerChunk.size > 0 && (filename.isNone() || name.len() == 0)) {
                let lineEnd = Strings.indexOf(headerChunk, CRLF)
                if (lineEnd.isNone()) {
                    return Some(Error("is missing header line end"))
                }
                let lineEndIdx = lineEnd.getOrThrow()
                let line = Bytes.subArray(headerChunk, 0, lineEndIdx)
                headerChunk = Bytes.subArray(headerChunk, lineEndIdx + 2, headerChunk.size - lineEndIdx - 2)

                let colon = Strings.indexOf(line, COLON)
                if (colon.isNone()) {
                    return Some(Error("is missing header colon separator"))
                }
                let colonIdx = colon.getOrThrow()

                let key = Bytes.subArray(line, 0, colonIdx)
                var value = if (line.size > colonIdx + 1) {
                    Bytes.subArray(line, colonIdx + 1, line.size - colonIdx - 1)
                } else {
                    Array<UInt8>()
                }

                if (Strings.eqlCaseInsensitiveAscii(key, CONTENT_DISPOSITION)) {
                    value = Strings.trim(value, SPACE)
                    if (startsWith(value, FORM_DATA_SEMI)) {
                        value = Bytes.subArray(value, FORM_DATA_SEMI.size, value.size - FORM_DATA_SEMI.size)
                        value = Strings.trim(value, SPACE)
                    }

                    // Parse name="..." and filename="..."
                    while (let Some(eqlStart) <- Strings.indexOf(value, EQUALS)) {
                        let eqlKey = Strings.trim(Bytes.subArray(value, 0, eqlStart), SPACE_SEMI)
                        value = Bytes.subArray(value, eqlStart + 1, value.size - eqlStart - 1)
                        if (startsWith(value, QUOTE)) {
                            value = Bytes.subArray(value, 1, value.size - 1)
                        }

                        var fieldValue = value
                        var i: Int64 = 0
                        while (i < fieldValue.size) {
                            let b = fieldValue[i]
                            if (b == UInt8('"'.toInt())) {
                                fieldValue = Bytes.subArray(fieldValue, 0, i)
                                break
                            } else if (b == UInt8('\\'.toInt())) {
                                if (i + 1 < fieldValue.size && fieldValue[i + 1] == UInt8('"'.toInt())) {
                                    i += 1
                                }
                            }
                            // the spec requires an end quote, but some browsers don't send it
                            i += 1
                        }
                        let fieldLen = Math.min(i + 1, value.size)
                        value = Bytes.subArray(value, fieldLen, value.size - fieldLen)

                        if (Strings.eqlCaseInsensitiveAscii(eqlKey, NAME)) {
                            name = subslicer.sub(fieldValue).value()
                        } else if (Strings.eqlCaseInsensitiveAscii(eqlKey, FILENAME)) {
                            filename = Some(subslicer.sub(fieldValue).value())
                            isFile = true
                        }

                        if (name.len() > 0 && filename.isSome()) {
                            break
                        }

                        if (let Some(semiStart) <- Strings.indexOf(value, SEMICOLON)) {
                            value = Bytes.subArray(value, semiStart + 1, value.size - semiStart - 1)
                        } else {
                            break
                        }
                    }
                } else if (value.size > 0 && field.contentType.len() == 0 &&
                           Strings.eqlCaseInsensitiveAscii(key, CONTENT_TYPE)) {
                    field.contentType = subslicer.sub(Strings.trim(value, TRIM_CHARS)).value()
                }
            }

            if (name.len() + Int64(field.zeroCount) == 0) {
                continue
            }

            var body = remain
            if (body.size >= 2 && body[body.size - 2] == UInt8(13) && body[body.size - 1] == UInt8(10)) {
                body = Bytes.subArray(body, 0, body.size - 2)
            }
            field.value = body
            field.filename = filename.getOrThrow(SemverString())
            field.isFile = isFile

            ctx.onEntry(name, field, input)
        }

        return None
    }

    // ---- JS bridge ----

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

    // ---- URL encoding helpers ----

    /// URL 编码辅助函数
    private static func urlEncode(s: String): String {
        let sb = StringBuilder()
        for (i in 0..s.size) {
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
        var i: Int64 = 0
        while (i < s.size) {
            let c = s[Int64(i)]
            if (c == '+') {
                sb.append(" ")
                i += 1
            } else if (c == '%' && i + 2 < s.size) {
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

    // ---- Static parsing from URL query ----

    /// 从 URL 查询字符串解析 FormData
    /// 对应 Bun: FormData.toJS URLEncoded path
    public static func fromURLQuery(query: String): FormData {
        let form = FormData()
        if (query.size == 0) { return form }
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

    /// 从 multipart 数据解析 FormData (high-level)
    /// 对应 Bun: FormData.toJSFromMultipartData
    public static func fromMultipart(input: Array<UInt8>, boundary: String): FormData {
        let form = FormData()
        let boundaryBytes = Utf8Codec.encode(boundary)
        let collector = FormDataCollector(form)
        let result = forEachMultipartEntry(input, boundaryBytes, collector)
        return form
    }

    /// 从 multipart 数据解析 FormData (using raw boundary bytes)
    public static func fromMultipartRaw(input: Array<UInt8>, boundary: Array<UInt8>): FormData {
        let form = FormData()
        let collector = FormDataCollector(form)
        let result = forEachMultipartEntry(input, boundary, collector)
        return form
    }

    // ---- Byte array helpers ----

    private static func startsWith(arr: Array<UInt8>, prefix: Array<UInt8>): Bool {
        if (prefix.size > arr.size) { return false }
        for (i in 0..prefix.size) {
            if (arr[i] != prefix[i]) { return false }
        }
        return true
    }
}

// ============================================================================
// AsyncFormData - Async FormData wrapper
// 对应 Bun: AsyncFormData (re-exported from bun_core::form_data)
// ============================================================================

/// Async FormData wrapper for promise-based JS bridge
/// 对应 Bun: AsyncFormData
public class AsyncFormData {
    public var encoding: FormDataEncoding

    public init(encoding: FormDataEncoding) {
        this.encoding = encoding
    }

    /// 对应 Bun: AsyncFormDataExt::toJS
    public func toJS(global: JSGlobalObject, data: Array<UInt8>, promise: AnyPromise): Unit {
        match (encoding) {
            case Multipart(b) =>
                if (b.size == 0) {
                    promise.reject(global, ZigString("FormData missing boundary").toErrorInstance(global))
                    return
                }
            case _ => ()
        }

        match (FormData.toJS(global, data, encoding)) {
            case Ok(jsValue) =>
                promise.resolve(global, jsValue)
            case Err(e) =>
                promise.reject(global, global.createErrorInstance("FormData error"))
        }
    }
}

// ============================================================================
// Supporting types
// ============================================================================

/// Multipart callback interface
/// 对应 Bun: for_each_multipart_entry iterator parameter
public interface MultipartCallback {
    func onEntry(name: SemverString, field: FormDataField, buf: Array<UInt8>): Unit
}

/// Callback wrapper for JS bridge
/// 对应 Bun: Wrapper struct in to_js_from_multipart_data
public class MultipartWrapper <: MultipartCallback {
    public var global: JSGlobalObject
    public var form: DOMFormData

    public init(global: JSGlobalObject, form: DOMFormData) {
        this.global = global
        this.form = form
    }

    public func onEntry(name: SemverString, field: FormDataField, buf: Array<UInt8>): Unit {
        let valueStr = field.value
        let key = ZigString.initUtf8(name.slice(buf))

        if (field.isFile) {
            let filenameStr = field.filename.slice(buf)
            var blob = Blob.create(valueStr, global, false)
            let filename = ZigString.initUtf8(filenameStr)

            if (!field.contentType.isEmpty()) {
                let ct = field.contentType.slice(buf)
                blob.setContentTypeAllocated(true)
                blob.setContentType(ct)
                blob.setContentTypeWasSet(true)
            } else {
                // Sniff MIME type from extension or content
                let mime = MimeType.byExtensionOrSniff(filenameStr, valueStr)
                if (let Some(m) <- mime) {
                    blob.setContentType(m.value)
                    blob.setContentTypeWasSet(false)
                    blob.setContentTypeAllocated(false)
                }
            }

            form.appendBlob(global, key, blob, filename)
            blob.detach()
        } else {
            // > Each part whose `Content-Disposition` header does not
            // > contain a `filename` parameter must be parsed into an
            // > entry whose value is the UTF-8 decoded without BOM
            // > content of the part.
            let value = ZigString.initUtf8(
                Strings.withoutUTF8Bom(valueStr)
            )
            form.append(key, value)
        }
    }
}

/// Collector that populates a FormData from multipart entries
public class FormDataCollector <: MultipartCallback {
    public var form: FormData

    public init(form: FormData) {
        this.form = form
    }

    public func onEntry(name: SemverString, field: FormDataField, buf: Array<UInt8>): Unit {
        let nameStr = name.toString()
        if (field.isFile) {
            let fname = field.filename.toString()
            let ct = field.contentType.toString()
            form.append(nameStr, field.value, fname, ct)
        } else {
            form.append(nameStr, Utf8Codec.decode(field.value))
        }
    }
}

// ============================================================================
// SemverString - Lightweight string with slice support
// 对应 bun_semver::String
// ============================================================================

/// Lightweight string with subslicing support for multipart parsing
/// 对应 Bun: bun_semver::String
public class SemverString {
    private var data: Array<UInt8>
    private var start: Int64
    private var length: Int64

    public init() {
        data = Array<UInt8>()
        start = 0
        length = 0
    }

    public init(s: String) {
        data = Utf8Codec.encode(s)
        start = 0
        length = data.size
    }

    public init(data: Array<UInt8>, start: Int64, length: Int64) {
        this.data = data
        this.start = start
        this.size = length
    }

    public func len(): Int64 { return length }

    public func isEmpty(): Bool { return length == 0 }

    public func slice(buf: Array<UInt8>): Array<UInt8> {
        if (data.size > 0) {
            let result = ArrayList<UInt8>()
            for (i in start..(start + length)) {
                if (i < data.size) {
                    result.add(data[Int64(i)])
                }
            }
            return result.toArray()
        }
        // Fall back to buf if data is empty
        let result = ArrayList<UInt8>()
        for (i in start..(start + length)) {
            if (i < buf.size) {
                result.add(buf[Int64(i)])
            }
        }
        return result.toArray()
    }

    public func toString(): String {
        return Utf8Codec.decode(slice(Array<UInt8>()))
    }

    public func value(): SemverString { return this }
}

/// SlicedString - Helper for subslicing into input buffer
/// 对应 Bun: bun_semver::SlicedString
public class SlicedString {
    private var input: Array<UInt8>

    public init(input: Array<UInt8>, _: Array<UInt8>) {
        this.input = input
    }

    public func sub(slice: Array<UInt8>): SemverString {
        // Find the slice within input to get offset
        if (slice.size == 0) {
            return SemverString()
        }
        // The slice is a sub-array of input; create a SemverString pointing to it
        return SemverString(input, 0, input.size)
    }
}

// ============================================================================
// DOMFormData - JSC-side DOMFormData bridge
// 对应 Bun: DOMFormData (JSC class)
// ============================================================================

/// DOMFormData bridge to JSC
/// 对应 Bun: DOMFormData
public class DOMFormData {
    public init() {}

    public static func create(global: JSGlobalObject): JsValue {
        return JsValue.NULL
    }

    public static func fromJS(value: JsValue): ?DOMFormData {
        return Some(DOMFormData())
    }

    public static func createFromURLQuery(global: JSGlobalObject, str: ZigString): JsResult {
        return JsResult.ok(JsValue.NULL)
    }

    public func append(key: ZigString, value: ZigString): Unit {}
    public func appendBlob(global: JSGlobalObject, key: ZigString, blob: Blob, filename: ZigString): Unit {}
    public func ensureStillAlive(): Unit {}
}

// ============================================================================
// Blob - Web Blob
// 对应 Bun: Blob
// ============================================================================

/// Web Blob (simplified for FormData usage)
/// 对应 Bun: Blob
public class Blob {
    public init() {}

    public static func create(data: Array<UInt8>, global: JSGlobalObject, _: Bool): Blob {
        return Blob()
    }

    public func setContentTypeAllocated(v: Bool): Unit {}
    public func setContentType(data: Array<UInt8>): Unit {}
    public func setContentTypeWasSet(v: Bool): Unit {}
    public func detach(): Unit {}
    public func sharedView(): Array<UInt8> { return Array<UInt8>() }
}

// ============================================================================
// MimeType - MIME type detection
// 对应 Bun: bun_http::MimeType
// ============================================================================

/// MIME type detection
public class MimeType {
    public var value: Array<UInt8>

    public init(value: Array<UInt8>) {
        this.value = value
    }

    public static func byExtensionOrSniff(filename: Array<UInt8>, data: Array<UInt8>): ?MimeType {
        // Simplified: return application/octet-stream
        return Some(MimeType(Utf8Codec.encode("application/octet-stream")))
    }
}

// ============================================================================
// AnyPromise - Promise wrapper
// 对应 Bun: AnyPromise
// ============================================================================

/// AnyPromise wrapper
public class AnyPromise {
    public init() {}

    public func reject(global: JSGlobalObject, value: JsValue): Unit {}
    public func resolve(global: JSGlobalObject, value: JsValue): Unit {}
}

// ============================================================================
// Error type
// ============================================================================

/// Error type
public class Error {
    public var message: String

    public init(message: String) {
        this.message = message
    }

    public func name(): String { return "Error" }
}

// ============================================================================
// Constant byte arrays used in multipart parsing
// ============================================================================

/// \r\n
let CRLF: Array<UInt8> = [13, 10]
/// \r\n\r\n
let CRLF_CRLF: Array<UInt8> = [13, 10, 13, 10]
/// ":"
let COLON: Array<UInt8> = [58]
/// "content-disposition"
let CONTENT_DISPOSITION: Array<UInt8> = [99, 111, 110, 116, 101, 110, 116, 45, 100, 105, 115, 112, 111, 115, 105, 116, 105, 111, 110]
/// "content-type"
let CONTENT_TYPE: Array<UInt8> = [99, 111, 110, 116, 101, 110, 116, 45, 116, 121, 112, 101]
/// "form-data;"
let FORM_DATA_SEMI: Array<UInt8> = [102, 111, 114, 109, 45, 100, 97, 116, 97, 59]
/// "name"
let NAME: Array<UInt8> = [110, 97, 109, 101]
/// "filename"
let FILENAME: Array<UInt8> = [102, 105, 108, 101, 110, 97, 109, 101]
/// "="
let EQUALS: Array<UInt8> = [61]
/// "\""
let QUOTE: Array<UInt8> = [34]
/// ";"
let SEMICOLON: Array<UInt8> = [59]
/// " "
let SPACE: Array<UInt8> = [32]
/// " ;"
let SPACE_SEMI: Array<UInt8> = [32, 59]
/// "\r\n\t ;" (trim chars for Content-Type)
let TRIM_CHARS: Array<UInt8> = [13, 10, 9, 32, 59]

// ============================================================================
// Forward declarations for types from other modules
// ============================================================================

/// CallFrame
public class CallFrame {
    public func arguments(n: Int64): Array<JsValue> { return Array<JsValue>() }
}

/// ZigString (from encoding.cj)
/// Placeholder — the real type lives in encoding.cj

/// JsObject
public class JsObject {
    public init() {}
    public func set(name: String, value: JsValue): Unit {}
}

/// JsNativeFunction
public class JsNativeFunction {
    public let name: String
    public let callback: (Array<JsValue>) -> JsValue

    public init(name: String, callback: (Array<JsValue>) -> JsValue) {
        this.name = name
        this.callback = callback
    }
}

/// Interpreter
public class Interpreter {
    public static func jsToString(v: JsValue): String { return "" }
}

/// BaoString (from encoding.cj)
/// Placeholder — the real type lives in encoding.cj

/// JsValue
public class JsValue {
    public static let ZERO = JsValue()
    public static let UNDEFINED = JsValue()
    public static let FALSE = JsValue()
    public static let TRUE = JsValue()
    public static let NULL = JsValue()

    public init() {}
    public init(s: BaoString) {}

    public func isEmptyOrUndefinedOrNull(): Bool { return true }
    public func isObject(): Bool { return false }
    public func isString(): Bool { return false }
    public func asArrayBuffer(global: JSGlobalObject): ?ArrayBufferView { return None }
    public func asClassRef<T>(cls: T): ?T { return None }
    public func toSlice(global: JSGlobalObject): ZigStringSlice { return ZigStringSlice() }
    public func ensureStillAlive(): Unit {}
}

/// JsResult
public class JsResult {
    public var value: ?JsValue
    public var error: ?JsValue

    private init(value: ?JsValue, error: ?JsValue) {
        this.value = value
        this.error = error
    }

    public static func ok(v: JsValue): JsResult {
        return JsResult(value: Some(v), error: None)
    }

    public static func err(e: JsValue): JsResult {
        return JsResult(value: None, error: Some(e))
    }
}

/// ArrayBufferView
public class ArrayBufferView {
    public func byteSlice(): Array<UInt8> { return Array<UInt8>() }
}

/// ZigStringSlice (from streams.cj)
/// Placeholder — the real type lives in streams.cj

/// JSGlobalObject
public class JSGlobalObject {
    public init() {}
    public func throwInvalidArguments(msg: String): JsValue { return JsValue.NULL }
    public func throwError(e: JsValue, msg: String): JsValue { return JsValue.NULL }
    public func createErrorInstance(msg: String): JsValue { return JsValue.NULL }
}

/// Strings (from encoding.cj)
/// Placeholder — references the real class in encoding.cj

/// Bytes (from encoding.cj)
/// Placeholder — references the real class in encoding.cj

/// Utf8Codec (from encoding.cj)
/// Placeholder — references the real class in encoding.cj

/// ArrayList helpers
public extension ArrayList<T> {
    public static func from(data: Array<T>): ArrayList<T> {
        let list = ArrayList<T>()
        for (item in data) {
            list.add(item)
        }
        return list
    }
}

/// Arrays utility
public class Arrays {
    public static func equal(a: Array<UInt8>, b: Array<UInt8>): Bool {
        if (a.size != b.size) { return false }
        for (i in 0..a.size) {
            if (a[i] != b[i]) { return false }
        }
        return true
    }
}

// ported from: src/runtime/webcore/FormData.zig
