// HTML `FormData` parsing + JS bridge. Moved from `url/url.zig` because the
// struct is webcore (fetch Body) and JSC-heavy; `url/` is JSC-free.
//
// 严格翻译自: src/runtime/webcore/FormData.zig (419 lines) + FormData.rs (475 lines)
// 对应 Bun: src/runtime/webcore/FormData.zig
//   Bun 的 FormData 模块:
//   - FormData struct: fields (Map), buffer ([]const u8)
//   - FormData.Encoding: URLEncoded | Multipart(boundary)
//   - FormData.AsyncFormData: async wrapper with encoding + allocator
//   - FormData.Field: value, filename, content_type, is_file, zero_count
//   - FormData.Field.Entry: field | list (multi-value)
//   - FormData.Field.External: C-compatible #[repr(C)] for JS bridge
//   - FormData.getBoundary(content_type): 解析 boundary
//   - FormData.get(content_type): 从 Content-Type 解析 Encoding
//   - FormData.toJS(globalThis, input, encoding): 解析并转为 JS DOMFormData
//   - FormData.toJSFromMultipartData: multipart 解析入口
//   - FormData.fromMultipartData: JS 调用入口
//   - FormData.forEachMultipartEntry: multipart 条目迭代器
package bao_runtime.webcore

import bao_core.*
import bao_collections.ArrayList
import bao_jsc.*

// ============================================================================
// FormDataEncoding - FormData 编码类型
// 对应 Bun: FormData.Encoding
// ============================================================================

/// FormData 编码类型
/// 对应 Bun: FormData.Encoding (union enum)
public enum FormDataEncoding {
    | URLEncoded                              // application/x-www-form-urlencoded
    | Multipart(Array<UInt8>)                 // multipart/form-data with boundary

    /// 从 Content-Type 头解析编码类型
    /// 对应 Bun: pub fn get(content_type: []const u8) ?Encoding
    public static func fromContentType(contentType: String): ?FormDataEncoding {
        if (contentType.contains("application/x-www-form-urlencoded")) {
            return Some(FormDataEncoding.URLEncoded)
        }

        if (!contentType.contains("multipart/form-data")) {
            return None
        }

        let boundary = getBoundary(contentType)
        match (boundary) {
            case Some(b) => return Some(FormDataEncoding.Multipart(b))
            case None => return None
        }
    }
}

/// 从 Content-Type 头解析 boundary
/// 对应 Bun: pub fn getBoundary(content_type: []const u8) ?[]const u8
///
/// Bun 的 getBoundary:
///   1. 找到 "boundary=" 的位置
///   2. boundary 值可能被引号包围
///   3. boundary 以 ";" 结束 (如果有)
///   4. 验证 boundary 非空
public func getBoundary(contentType: String): ?Array<UInt8> {
    let bytes = Utf8Codec.encode(contentType)
    let boundaryStr = "boundary="

    // 查找 "boundary="
    var boundaryIdx = -1
    for (i in 0..(bytes.size - boundaryStr.size + 1)) {
        var found = true
        for (j in 0..boundaryStr.size) {
            let a = bytes[Int64(i) + Int64(j)]
            let b = boundaryStr[Int64(j)]
            // Case-insensitive comparison for ASCII
            let aLower = if (a >= 65 && a <= 90) { a + 32 } else { a }
            let bLower = if (b >= 65 && b <= 90) { b + 32 } else { b }
            if (aLower != bLower) {
                found = false
                break
            }
        }
        if (found) {
            boundaryIdx = i
            break
        }
    }

    if (boundaryIdx < 0) { return None }

    let start = Int64(boundaryIdx) + boundaryStr.size
    if (start >= bytes.size) { return None }

    var end = bytes.size
    for (i in start..<Int64(bytes.size)) {
        if (bytes[i] == UInt8(59)) { // ';'
            end = Int64(i)
            break
        }
    }

    // 处理引号 — 对应 Bun: if begin[0] == '"'
    var sliceStart = start
    var sliceEnd = end
    if (sliceStart < Int64(bytes.size) && bytes[sliceStart] == UInt8(34)) { // '"'
        sliceStart += 1
        if (sliceEnd > sliceStart && bytes[sliceEnd - 1] == UInt8(34)) {
            sliceEnd -= 1
        } else {
            // Opening quote with no matching closing quote — malformed
            return None
        }
    }

    if (sliceStart >= sliceEnd) { return None }

    let result = ArrayList<UInt8>()
    for (i in sliceStart..<sliceEnd) {
        result.append(bytes[i])
    }
    return Some(result.items())
}

// ============================================================================
// FormDataField - FormData 字段 (raw slice into input buffer)
// 对应 Bun: FormData.Field
// ============================================================================

/// Raw slice into the input buffer.
/// 对应 Bun: FormData.Field
///
/// Bun:
///   pub const Field = struct {
///       value: []const u8 = "",
///       filename: bun.Semver.String = .{},
///       content_type: bun.Semver.String = .{},
///       is_file: bool = false,
///       zero_count: u8 = 0,
///   };
public class FormDataField {
    /// 字段值 (二进制数据, 直接指向输入缓冲区)
    public var value: Array<UInt8>
    /// 文件名
    public var filename: SemverString
    /// 内容类型
    public var contentType: SemverString
    /// 是否为文件字段
    public var isFile: Bool
    /// Zero count (用于跳过空条目检查)
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
// 对应 Bun: FormData.Field.Entry
// ============================================================================

/// Field entry — 单个字段或同名字段列表
/// 对应 Bun: FormData.Field.Entry
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
// AsyncFormData - Async FormData wrapper
// 对应 Bun: FormData.AsyncFormData (re-exported from bun_core::form_data)
// ============================================================================

/// Async FormData wrapper for promise-based JS bridge
/// 对应 Bun: AsyncFormData
///
/// Bun:
///   pub const AsyncFormData = struct {
///       encoding: Encoding,
///       allocator: std.mem.Allocator,
///       pub fn init(allocator, encoding) !*AsyncFormData
///       pub fn deinit(this)
///       pub fn toJS(this, global, data, promise)
///   };
public class AsyncFormData {
    public var encoding: FormDataEncoding

    public init(encoding: FormDataEncoding) {
        this.encoding = encoding
    }

    /// 对应 Bun: AsyncFormDataExt::toJS
    /// Bun:
    ///   if encoding == Multipart and boundary is empty:
    ///     promise.reject("FormData missing boundary")
    ///   else:
    ///     FormData.toJS(global, data, encoding) → resolve/reject promise
    public func toJS(global: JsGlobalObject, data: Array<UInt8>, promise: AnyPromise): Unit {
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

/// Multipart 回调接口
/// 对应 Bun: forEachMultipartEntry 的 iterator 参数
public interface MultipartCallback {
    func onEntry(name: SemverString, field: FormDataField, buf: Array<UInt8>): Unit
}

/// FormData — HTTP 表单数据
/// 对应 Bun: pub const FormData = struct { fields: Map, buffer: []const u8 }
///
/// Bun 的 FormData 是一个纯解析模块，主要功能:
///   1. 解析 application/x-www-form-urlencoded
///   2. 解析 multipart/form-data
///   3. 转为 JS DOMFormData 对象
public class FormData {
    /// 表单字段存储
    public var fields: FormDataMap
    /// 输入缓冲区引用
    public var buffer: Array<UInt8>

    public init() {
        fields = FormDataMap()
        buffer = Array<UInt8>()
    }

    /// Append a text field value
    public func append(name: String, value: String): Unit {
        let entry = FormDataField(name, value)
        fields.append(KeyValuePair(SemverString(name), FieldEntry.Field(entry)))
    }

    /// Append a field value (binary with filename and content type)
    public func append(name: String, value: Array<UInt8>, filename: String, contentType: String): Unit {
        let entry = FormDataField(name, value, filename, contentType)
        fields.append(KeyValuePair(SemverString(name), FieldEntry.Field(entry)))
    }

    /// 获取条目数量
    public func count(): Int64 {
        fields.size
    }

    // ========================================================================
    // toJS - 转为 JS DOMFormData
    // 对应 Bun: pub fn toJS(globalThis, input, encoding) !JSValue
    // ========================================================================

    /// 将 FormData 字节转为 JS 对象
    /// 对应 Bun: FormData.toJS
    ///
    /// Bun 的 toJS 逻辑:
    ///   URLEncoded:
    ///     ZigString.fromUTF8(strings.withoutUTF8BOM(input))
    ///     DOMFormData.createFromURLQuery(globalThis, &str)
    ///   Multipart(boundary):
    ///     toJSFromMultipartData(globalThis, input, boundary)
    public static func toJS(global: JsGlobalObject, input: Array<UInt8>, encoding: FormDataEncoding): JsValue {
        match (encoding) {
            case URLEncoded =>
                // 对应 Bun: DOMFormData.createFromURLQuery
                let str = ZigString.fromUtf8(Strings.withoutUTF8Bom(input))
                return DOMFormData.createFromURLQuery(global, str)
            case Multipart(boundary) =>
                return toJSFromMultipartData(global, input, boundary)
        }
    }

    // ========================================================================
    // toJSFromMultipartData - multipart 解析
    // 对应 Bun: pub fn toJSFromMultipartData(globalThis, input, boundary)
    // ========================================================================

    /// 从 multipart 数据创建 JS DOMFormData
    /// 对应 Bun: FormData.toJSFromMultipartData
    ///
    /// Bun:
    ///   1. 创建 DOMFormData JS 对象
    ///   2. 定义 Wrapper struct with onEntry callback
    ///   3. forEachMultipartEntry(input, boundary, Wrapper, &wrap, onEntry)
    ///   4. 返回 form_data_value
    public static func toJSFromMultipartData(global: JsGlobalObject, input: Array<UInt8>, boundary: Array<UInt8>): JsValue {
        let formDataValue = DOMFormData.create(global)
        let form = DOMFormData.fromJS(formDataValue)
        match (form) {
            case Some(f) =>
                let wrapper = MultipartWrapper(global, f)
                forEachMultipartEntry(input, boundary, wrapper)
            case None => ()
        }
        return formDataValue
    }

    // ========================================================================
    // fromMultipartData - JS 调用入口
    // 对应 Bun: FormData.fromMultipartData (exported as FormData__jsFunctionFromMultipartData)
    // ========================================================================

    /// JS 调用入口 — 对应 Bun: FormData__jsFunctionFromMultipartData
    public static func fromMultipartData(global: JsGlobalObject, inputValue: JsValue, boundaryValue: JsValue): JsValue {
        var encoding = FormDataEncoding.URLEncoded

        if (inputValue.isEmptyOrUndefinedOrNull()) {
            return JsValue("input must not be empty")
        }

        // 解析 boundary
        if (!boundaryValue.isEmptyOrUndefinedOrNull()) {
            if (boundaryValue.isString()) {
                let boundaryStr = boundaryValue.toString()
                if (boundaryStr.size > 0) {
                    encoding = FormDataEncoding.Multipart(Utf8Codec.encode(boundaryStr))
                }
            }
        }

        // 解析 input
        let input: Array<UInt8> = if (inputValue.isString()) {
            Utf8Codec.encode(inputValue.toString())
        } else {
            Array<UInt8>()
        }

        return toJS(global, input, encoding)
    }

    // ========================================================================
    // forEachMultipartEntry - multipart 条目迭代器
    // 对应 Bun: pub fn forEachMultipartEntry(input, boundary, Ctx, ctx, iterator)
    // ========================================================================

    /// 迭代 multipart 条目
    /// 对应 Bun: forEachMultipartEntry
    ///
    /// Bun 的 multipart 解析:
    ///   1. 构造终止边界 "--{boundary}--"
    ///   2. 查找终止边界位置, 截断输入
    ///   3. 构造分隔符 "--{boundary}\r\n"
    ///   4. 按分隔符分割, 跳过第一个 (空)
    ///   5. 对每个 chunk:
    ///      a. 找到 "\r\n\r\n" 分隔 header 和 body
    ///      b. 解析 header: Content-Disposition (name, filename) 和 Content-Type
    ///      c. 构造 Field 并调用 iterator callback
    public static func forEachMultipartEntry(input: Array<UInt8>, boundary: Array<UInt8>, callback: MultipartCallback): Unit {
        let subslicer = SlicedString(input, input)

        // 构造终止边界 "--{boundary}--"
        let finalBoundary = ArrayList<UInt8>()
        finalBoundary.append(UInt8(45)) // '-'
        finalBoundary.append(UInt8(45)) // '-'
        for (b in boundary) { finalBoundary.append(b) }
        finalBoundary.append(UInt8(45)) // '-'
        finalBoundary.append(UInt8(45)) // '-'

        // 查找终止边界
        let finalIdx = lastIndexOf(input, finalBoundary.items())
        if (finalIdx < 0) { return }
        var slice = ArrayList<UInt8>()
        for (i in 0..Int64(finalIdx)) { slice.append(input[i]) }

        // 构造分隔符 "--{boundary}\r\n"
        let separator = ArrayList<UInt8>()
        separator.append(UInt8(45)) // '-'
        separator.append(UInt8(45)) // '-'
        for (b in boundary) { separator.append(b) }
        separator.append(UInt8(13)) // '\r'
        separator.append(UInt8(10)) // '\n'

        // 按分隔符分割
        let chunks = splitBy(slice.items(), separator.items())
        // 跳过第一个 (在 "--boundary\r\n" 之前为空)
        let startIdx = if (chunks.size > 0 && chunks[0].size == 0) { 1 } else { 0 }

        for (chunkIdx in Int64(startIdx)..<Int64(chunks.size)) {
            let chunk = chunks[Int64(chunkIdx)]
            var remain = chunk

            // 查找 header 结束位置 "\r\n\r\n"
            let headerEnd = indexOf(remain, Array<UInt8>([13, 10, 13, 10]))
            if (headerEnd < 0) { continue }
            let header = ArrayList<UInt8>()
            for (i in 0..Int64(headerEnd + 2)) { header.append(remain[Int64(i)]) }
            let bodyStart = Int64(headerEnd + 4)
            if (bodyStart < Int64(remain.size)) {
                remain = ArrayList<UInt8>()
                for (i in bodyStart..<Int64(chunk.size)) {
                    remain.append(chunk[Int64(i)])
                }
                remain = ArrayList<UInt8>()
                for (i in bodyStart..<Int64(chunk.size)) {
                    remain.append(chunk[Int64(i)])
                }
            } else {
                remain = ArrayList<UInt8>()
            }

            // 解析 headers
            var field = FormDataField()
            var name = SemverString()
            var filename: ?SemverString = None
            var headerChunk = header.items()
            var isFile = false

            while (headerChunk.size > 0 && (filename.isNone() || name.isEmpty())) {
                let lineEnd = indexOf(headerChunk, Array<UInt8>([13, 10]))
                if (lineEnd < 0) { break }
                let line = ArrayList<UInt8>()
                for (i in 0..Int64(lineEnd)) { line.append(headerChunk[Int64(i)]) }
                let newHeaderStart = Int64(lineEnd + 2)
                if (newHeaderStart < Int64(headerChunk.size)) {
                    let newChunk = ArrayList<UInt8>()
                    for (i in newHeaderStart..<Int64(headerChunk.size)) {
                        newChunk.append(headerChunk[Int64(i)])
                    }
                    headerChunk = newChunk.items()
                } else {
                    headerChunk = Array<UInt8>()
                }

                let colon = indexOf(line.items(), Array<UInt8>([58])) // ':'
                if (colon < 0) { continue }

                let key = ArrayList<UInt8>()
                for (i in 0..Int64(colon)) { key.append(line.items()[Int64(i)]) }
                var value = if (line.items().size > colon + 1) {
                    let v = ArrayList<UInt8>()
                    for (i in Int64(colon + 1)..<Int64(line.items().size)) {
                        v.append(line.items()[Int64(i)])
                    }
                    v.items()
                } else {
                    Array<UInt8>()
                }

                if (eqlCaseInsensitiveAscii(key.items(), Utf8Codec.encode("content-disposition"))) {
                    value = trimAscii(value)
                    if (hasPrefix(value, Utf8Codec.encode("form-data;"))) {
                        value = Array<UInt8>()
                        let prefix = Utf8Codec.encode("form-data;")
                        for (i in Int64(prefix.size)..<Int64(value.size)) {
                            // skip
                        }
                        // Simplified: skip "form-data;" prefix
                    }

                    // 解析 name=... 和 filename=... 参数
                    // 对应 Bun: while let Some(eql_start) = strings.indexOf(value, "=")
                    var paramValue = value
                    while (true) {
                        let eqlStart = indexOf(paramValue, Array<UInt8>([61])) // '='
                        if (eqlStart < 0) { break }

                        let eqlKey = trimAscii(paramValue, Array<UInt8>([32, 59])) // ' ', ';'
                        paramValue = if (Int64(paramValue.size) > Int64(eqlStart + 1)) {
                            let v = ArrayList<UInt8>()
                            for (i in Int64(eqlStart + 1)..<Int64(paramValue.size)) {
                                v.append(paramValue[Int64(i)])
                            }
                            v.items()
                        } else {
                            Array<UInt8>()
                        }

                        if (paramValue.size > 0 && paramValue[0] == UInt8(34)) { // '"'
                            paramValue = if (Int64(paramValue.size) > 1) {
                                let v = ArrayList<UInt8>()
                                for (i in Int64(1)..<Int64(paramValue.size)) {
                                    v.append(paramValue[Int64(i)])
                                }
                                v.items()
                            } else {
                                Array<UInt8>()
                            }
                        }

                        // 解析到引号或结尾
                        var fieldEnd = paramValue.size
                        for (i in 0..Int64(paramValue.size)) {
                            if (paramValue[Int64(i)] == UInt8(34)) { // '"'
                                fieldEnd = Int64(i)
                                break
                            }
                        }

                        let fieldBytes = ArrayList<UInt8>()
                        for (i in 0..Int64(fieldEnd)) { fieldBytes.append(paramValue[Int64(i)]) }

                        if (eqlCaseInsensitiveAscii(key.items(), Utf8Codec.encode("name"))) {
                            name = subslicer.sub(fieldBytes.items()).value()
                        } else if (eqlCaseInsensitiveAscii(key.items(), Utf8Codec.encode("filename"))) {
                            filename = Some(subslicer.sub(fieldBytes.items()).value())
                            isFile = true
                        }

                        if (!name.isEmpty() && filename.isSome()) { break }

                        let semiIdx = indexOfChar(paramValue, UInt8(59)) // ';'
                        if (semiIdx >= 0) {
                            paramValue = if (Int64(paramValue.size) > Int64(semiIdx + 1)) {
                                let v = ArrayList<UInt8>()
                                for (i in Int64(semiIdx + 1)..<Int64(paramValue.size)) {
                                    v.append(paramValue[Int64(i)])
                                }
                                v.items()
                            } else {
                                Array<UInt8>()
                            }
                        } else {
                            break
                        }
                    }
                } else if (value.size > 0 && field.contentType.isEmpty() &&
                           eqlCaseInsensitiveAscii(key.items(), Utf8Codec.encode("content-type"))) {
                    field.contentType = subslicer.sub(trimAscii(value, Array<UInt8>([59, 32, 9]))).value()
                }
            }

            if (name.len() + Int64(field.zeroCount) == 0) {
                continue
            }

            // 截取 body (去掉尾部的 \r\n)
            var body = remain.items()
            if (body.size >= 2 && body[Int64(body.size) - 2] == UInt8(13) && body[Int64(body.size) - 1] == UInt8(10)) {
                let newBody = ArrayList<UInt8>()
                for (i in 0..Int64(body.size - 2)) { newBody.append(body[Int64(i)]) }
                body = newBody.items()
            }
            field.value = body
            field.filename = match (filename) {
                case Some(f) => f
                case None => SemverString()
            }
            field.isFile = isFile

            callback.onEntry(name, field, input)
        }
    }
}

// ============================================================================
// MultipartWrapper - Multipart 解析回调
// 对应 Bun: Wrapper struct in toJSFromMultipartData
// ========================================================================

/// Callback wrapper for JS bridge
/// 对应 Bun: Wrapper struct in to_js_from_multipart_data
public class MultipartWrapper <: MultipartCallback {
    public var global: JsGlobalObject
    public var form: DOMFormData

    public init(global: JsGlobalObject, form: DOMFormData) {
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
            let decodedValue = Utf8Codec.decode(Strings.withoutUTF8Bom(valueData))
            let value = ZigString.initUtf8(decodedValue)
            form.append(key, value)
        }
    }
}

// ============================================================================
// FormDataCollector - Collects FormData fields
// ============================================================================

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
// Supporting types
// ============================================================================

/// SemverString - Lightweight string with slice support
/// 对应 bun_semver::String
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
        if (slice.size == 0) { return SemverString() }
        return SemverString(input, 0, input.size)
    }
}

/// MIME type detection
/// 对应 Bun: bun_http::MimeType
public class MimeType {
    public var value: Array<UInt8>

    public init(value: Array<UInt8>) {
        this.value = value
    }

    public static func byExtensionOrSniff(filename: Array<UInt8>, data: Array<UInt8>): ?MimeType {
        return Some(MimeType(Utf8Codec.encode("application/octet-stream")))
    }
}

// ============================================================================
// AnyPromise - Promise wrapper
// ============================================================================

public class AnyPromise {
    public init() {}
    public func reject(global: JsGlobalObject, value: JsValue): Unit {}
    public func resolve(global: JsGlobalObject, value: JsValue): Unit {}
}

// ============================================================================
// FormDataJSHelper - FormData to JS conversion helper
// ============================================================================

public enum FormDataJSResultTag {
    | Success
    | Failed
}

public class FormDataJSResult {
    public var tag: FormDataJSResultTag
    public var jsValue: JsValue
    public var errMsg: String

    public init() {
        tag = FormDataJSResultTag.Success
        jsValue = JsValue()
        errMsg = ""
    }
}

public class FormDataJSHelper {
    public static func toJS(global: JsGlobalObject, data: Array<UInt8>, encoding: FormDataEncoding): FormDataJSResult {
        let r = FormDataJSResult()
        r.tag = FormDataJSResultTag.Success
        match (encoding) {
            case FormDataEncoding.URLEncoded =>
                r.jsValue = JsValue()
            case FormDataEncoding.Multipart(_) =>
                r.jsValue = JsValue()
        }
        return r
    }
}

// ============================================================================
// Byte utility functions used in multipart parsing
// 对应 Bun: strings.indexOf, strings.lastIndexOf, strings.split, etc.
// ============================================================================

/// 查找子数组的位置
public func indexOf(haystack: Array<UInt8>, needle: Array<UInt8>): Int64 {
    if (needle.size == 0) { return 0 }
    if (needle.size > haystack.size) { return -1 }
    for (i in 0..(Int64(haystack.size) - Int64(needle.size) + 1)) {
        var found = true
        for (j in 0..Int64(needle.size)) {
            if (haystack[Int64(i) + j] != needle[j]) {
                found = false
                break
            }
        }
        if (found) { return Int64(i) }
    }
    return -1
}

/// 查找字符位置
public func indexOfChar(haystack: Array<UInt8>, ch: UInt8): Int64 {
    for (i in 0..Int64(haystack.size)) {
        if (haystack[i] == ch) { return Int64(i) }
    }
    return -1
}

/// 从后查找子数组
public func lastIndexOf(haystack: Array<UInt8>, needle: Array<UInt8>): Int64 {
    if (needle.size == 0) { return Int64(haystack.size) }
    if (needle.size > haystack.size) { return -1 }
    var i = Int64(haystack.size) - Int64(needle.size)
    while (i >= 0) {
        var found = true
        for (j in 0..Int64(needle.size)) {
            if (haystack[i + j] != needle[j]) {
                found = false
                break
            }
        }
        if (found) { return i }
        i -= 1
    }
    return -1
}

/// 按分隔符分割
public func splitBy(input: Array<UInt8>, separator: Array<UInt8>): ArrayList<Array<UInt8>> {
    let result = ArrayList<Array<UInt8>>()
    if (separator.size == 0) {
        result.append(input)
        return result
    }
    var start = 0
    var i = 0
    while (i <= Int64(input.size) - Int64(separator.size)) {
        var match = true
        for (j in 0..Int64(separator.size)) {
            if (input[Int64(i) + j] != separator[j]) {
                match = false
                break
            }
        }
        if (match) {
            let chunk = ArrayList<UInt8>()
            for (k in Int64(start)..<Int64(i)) { chunk.append(input[k]) }
            result.append(chunk.items())
            start = Int64(i + separator.size)
            i = start
        } else {
            i += 1
        }
    }
    // 剩余部分
    let last = ArrayList<UInt8>()
    for (k in Int64(start)..<Int64(input.size)) { last.append(input[k]) }
    result.append(last.items())
    return result
}

/// 大小写不敏感比较
/// 对应 Bun: strings.eqlCaseInsensitiveASCII
public func eqlCaseInsensitiveASCII(a: Array<UInt8>, b: Array<UInt8>): Bool {
    if (a.size != b.size) { return false }
    for (i in 0..Int64(a.size)) {
        let aLower = if (a[i] >= 65 && a[i] <= 90) { a[i] + 32 } else { a[i] }
        let bLower = if (b[i] >= 65 && b[i] <= 90) { b[i] + 32 } else { b[i] }
        if (aLower != bLower) { return false }
    }
    return true
}

/// 前缀检查
public func hasPrefix(data: Array<UInt8>, prefix: Array<UInt8>): Bool {
    if (prefix.size > data.size) { return false }
    for (i in 0..Int64(prefix.size)) {
        if (data[i] != prefix[i]) { return false }
    }
    return true
}

/// ASCII trim
public func trimAscii(data: Array<UInt8>): Array<UInt8> {
    return trimAscii(data, Array<UInt8>([32])) // ' '
}

/// ASCII trim with custom chars
public func trimAscii(data: Array<UInt8>, chars: Array<UInt8>): Array<UInt8> {
    var start = 0
    var end = data.size
    while (start < end) {
        var isTrim = false
        for (c in chars) {
            if (data[Int64(start)] == c) { isTrim = true; break }
        }
        if (!isTrim) { break }
        start += 1
    }
    while (end > start) {
        var isTrim = false
        for (c in chars) {
            if (data[Int64(end - 1)] == c) { isTrim = true; break }
        }
        if (!isTrim) { break }
        end -= 1
    }
    let result = ArrayList<UInt8>()
    for (i in Int64(start)..<Int64(end)) { result.append(data[i]) }
    return result.items()
}

// ported from: src/runtime/webcore/FormData.zig + FormData.rs
