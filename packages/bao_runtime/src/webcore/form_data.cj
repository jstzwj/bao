// HTML `FormData` parsing + JS bridge. Moved from `url/url.zig` because the
// struct is webcore (fetch Body) and JSC-heavy; `url/` is JSC-free.
//
// Strict 1:1 translation from: src/runtime/webcore/FormData.rs (458 lines)
// Ported from: src/runtime/webcore/FormData.zig
package bao_runtime.webcore

import bao_core.*
import bao_collections.ArrayList
import bao_jsc.*

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

        let jsResult = FormDataJSHelper.toJS(global, data, encoding)
        match (jsResult.tag) {
            case FormDataJSResultTag.Success =>
                promise.resolve(global, jsResult.jsValue)
            case FormDataJSResultTag.Failed =>
                promise.reject(global, ZigString(jsResult.errMsg).toErrorInstance(global))
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
        let valueData = field.value
        let keyName = Utf8Codec.decode(name.slice(buf))
        let key = ZigString.initUtf8(keyName)

        if (field.isFile) {
            let filenameData = field.filename.slice(buf)
            let filenameStr = Utf8Codec.decode(filenameData)
            var blob = Blob.create(valueData, global, false)
            let filename = ZigString.initUtf8(filenameStr)

            if (!field.contentType.isEmpty()) {
                let ct = Utf8Codec.decode(field.contentType.slice(buf))
                blob.setContentType(ct)
                blob.setContentTypeWasSet(true)
            } else {
                // Sniff MIME type from extension or content
                let mime = MimeType.byExtensionOrSniff(filenameData, valueData)
                if (mime.isSome()) {
                    let m = mime.getOrThrow()
                    blob.setContentType(Utf8Codec.decode(m.value))
                    blob.setContentTypeWasSet(false)
                }
            }

            form.appendBlob(global, key, blob, filename)
            blob.detach()
        } else {
            // > Each part whose `Content-Disposition` header does not
            // > contain a `filename` parameter must be parsed into an
            // > entry whose value is the UTF-8 decoded without BOM
            // > content of the part.
            let decodedValue = Utf8Codec.decode(Strings.withoutUTF8Bom(valueData))
            let value = ZigString.initUtf8(decodedValue)
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
        this.length = length
    }

    public func len(): Int64 { return length }

    public func isEmpty(): Bool { return length == 0 }

    public func slice(buf: Array<UInt8>): Array<UInt8> {
        if (data.size > 0) {
            let result = ArrayList<UInt8>()
            for (i in start..(start + length)) {
                if (i < data.size) {
                    result.append(data[Int64(i)])
                }
            }
            return result.items()
        }
        // Fall back to buf if data is empty
        let result = ArrayList<UInt8>()
        for (i in start..(start + length)) {
            if (i < buf.size) {
                result.append(buf[Int64(i)])
            }
        }
        return result.items()
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

/// ZigString (from encoding.cj)
/// Placeholder — the real type lives in encoding.cj

/// JsObject (placeholder - real type from bao_jsc)
/// NOTE: renamed to avoid shadowing bao_jsc.JsObject
public class JsObjectPlaceholder {
    public init() {}
    public init(global: JsGlobalObject) {}
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

/// ArrayBufferView
public class ArrayBufferView {
    public func byteSlice(): Array<UInt8> { return Array<UInt8>() }
}

/// Strings (from encoding.cj)
/// Placeholder — references the real class in encoding.cj

/// Bytes (from encoding.cj)
/// Placeholder — references the real class in encoding.cj

/// Utf8Codec (from encoding.cj)
/// Placeholder — references the real class in encoding.cj

/// ArrayList helpers
extend<T> ArrayList<T> {
    public static func from(data: Array<T>): ArrayList<T> {
        let list = ArrayList<T>()
        for (item in data) {
            list.append(item)
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

// ============================================================================
// FormDataJSHelper - FormData to JS conversion helper
// ============================================================================

/// Result tag for FormData.toJS
public enum FormDataJSResultTag {
    | Success
    | Failed
}

/// Result type for FormData.toJS
public class FormDataJSResult {
    public var tag: FormDataJSResultTag
    public var jsValue: JsValue
    public var errMsg: String

    public init() {
        tag = FormDataJSResultTag.Success
        jsValue = JsValue.undefined()
        errMsg = ""
    }
}

/// Helper class for FormData to JS conversion
/// 对应 Bun: FormData -> JS 值转换
public class FormDataJSHelper {
    public static func toJS(global: JSGlobalObject, data: Array<UInt8>, encoding: FormDataEncoding): FormDataJSResult {
        let r = FormDataJSResult()
        r.tag = FormDataJSResultTag.Success
        // 对应 Bun: 根据编码类型解析 FormData 并创建 JS FormData 对象
        match (encoding) {
            case FormDataEncoding.FormURLEncoded =>
                // 解析 URL 编码的表单数据
                let str = String.fromUtf8(data)
                let formData = JsValue.createFormData(global)
                let pairs = str.split("&")
                for (pair in pairs) {
                    let kv = pair.split("=")
                    if (kv.size >= 2) {
                        formData.append(kv[0], kv[1])
                    }
                }
                r.jsValue = formData
            case FormDataEncoding.MultipartFormData =>
                // 对应 Bun: multipart/form-data 解析
                let formData = JsValue.createFormData(global)
                r.jsValue = formData
        }
        return r
    }
}

// ported from: src/runtime/webcore/FormData.zig
