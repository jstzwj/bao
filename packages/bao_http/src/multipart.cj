// bao_http multipart - Multipart form-data 解析
// 严格翻译自: src/http/Headers.zig 中 Content-Disposition 解析
// 参考: RFC 2046 (MIME), RFC 7578 (multipart/form-data)
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// MultipartPart - Multipart 部分
// 对应 Bun Headers 中 Content-Disposition 解析
// multipart/form-data 每个部分的格式:
//   --boundary\r\n
//   Content-Disposition: form-data; name="field"; filename="file.txt"\r\n
//   Content-Type: text/plain\r\n
//   \r\n
//   <body>\r\n
// ============================================================================

/// Multipart 部分 - 对应单个 form-data 部分
public class MultipartPart {
    /// 部分头部 - 对应 Bun Headers
    public var headers: HashMap<String, String>
    /// 部分体数据
    public var body: Array<UInt8>
    /// 字段名 - 对应 Content-Disposition 中 name="..."
    public var name: String
    /// 文件名 - 对应 Content-Disposition 中 filename="..."
    public var filename: ?String
    /// Content-Type
    public var contentType: ?String

    public init() {
        headers = HashMap<String, String>()
        body = Array<UInt8>()
        name = ""
        filename = None
        contentType = None
    }

    /// 从 Content-Disposition 头解析 name 和 filename
    /// 格式: form-data; name="field"; filename="file.txt"
    public static func parseContentDisposition(header: String): Tuple2<String, ?String> {
        var name = ""
        var filename: ?String = None

        let parts = splitSemicolon(header)
        for (part in parts) {
            let trimmed = part.trim()
            let eqIdx = trimmed.indexOf("=")
            if (eqIdx >= 0) {
                let key = trimmed.substring(0, eqIdx).trim().toLower()
                let value = trimmed.substring(eqIdx + 1).trim()
                // 去除引号
                let cleanValue = stripQuotes(value)
                if (key == "name") {
                    name = cleanValue
                } else if (key == "filename") {
                    filename = Some(cleanValue)
                }
            }
        }

        return Tuple2<String, ?String>(name, filename)
    }

    /// 是否为文件上传
    public func isFile(): Bool {
        return match (filename) {
            case Some(_) => true
            case None => false
        }
    }

    /// 获取 body 为字符串
    public func text(): String {
        let sb = StringBuilder()
        for (b in body) {
            sb.append(Char(Int32(b)))
        }
        return sb.toString()
    }

    /// 获取 body 大小
    public func size(): Int64 {
        return body.size
    }

    /// 获取指定头部
    public func getHeader(name: String): ?String {
        return headers.get(name.toLower())
    }
}

/// 简单元组
public class Tuple2<T, U> {
    public var first: T
    public var second: U

    public init(first: T, second: U) {
        this.first = first
        this.second = second
    }
}

// ============================================================================
// MultipartParser - Multipart 解析器
// 解析 multipart/form-data 请求体
//
// 格式:
//   --boundary\r\n
//   Content-Disposition: form-data; name="field1"\r\n
//   \r\n
//   value1\r\n
//   --boundary\r\n
//   Content-Disposition: form-data; name="field2"; filename="file.txt"\r\n
//   Content-Type: text/plain\r\n
//   \r\n
//   file content\r\n
//   --boundary--\r\n
// ============================================================================

/// Multipart 解析器
public class MultipartParser {
    /// 边界字符串
    private var boundary: String
    /// 边界字节数组 (含 --)
    private var boundaryBytes: Array<UInt8>
    /// 结束边界字节数组
    private var endBoundaryBytes: Array<UInt8>

    public init(boundary: String) {
        this.boundary = boundary
        // 边界以 "--" 开头
        let fullBoundary = "--${boundary}"
        this.boundaryBytes = stringToBytes(fullBoundary)
        this.endBoundaryBytes = stringToBytes("${fullBoundary}--")
    }

    /// 从 Content-Type 头提取 boundary
    /// 格式: multipart/form-data; boundary=----WebKitFormBoundary...
    public static func extractBoundary(contentType: String): ?String {
        let lower = contentType.toLower()
        let parts = splitSemicolon(lower)
        for (part in parts) {
            let trimmed = part.trim()
            if (trimmed.startsWith("boundary=")) {
                var value = trimmed.substring(9).trim()
                // 去除引号
                value = stripQuotes(value)
                return Some(value)
            }
        }
        return None
    }

    /// 从 Content-Type 自动创建解析器
    public static func fromContentType(contentType: String): ?MultipartParser {
        let boundary = extractBoundary(contentType)
        match (boundary) {
            case Some(b) => return Some(MultipartParser(b))
            case None => return None
        }
    }

    /// 解析 multipart 数据
    public func parse(data: Array<UInt8>): ArrayList<MultipartPart> {
        let parts = ArrayList<MultipartPart>()
        let dataStr = bytesToString(data)

        // 查找所有边界位置
        let positions = findAllBoundaryPositions(data)

        if (positions.size < 2) {
            return parts  // 至少需要起始和结束边界
        }

        // 遍历相邻边界对，提取每部分数据
        for (i in 0..(positions.size - 1)) {
            let startPos = positions[Int64(i)]
            let endPos = positions[Int64(i) + 1]

            // 跳过边界行
            let boundaryEnd = skipBoundaryLine(data, startPos)
            if (boundaryEnd < 0 || boundaryEnd >= endPos) {
                continue
            }

            // 提取部分数据 (从边界行结束到下一个边界前的 \r\n)
            var partEnd = endPos
            // 去除边界前的 \r\n
            if (partEnd >= 2 && data[Int64(partEnd - 1)] == UInt8(10) &&
                data[Int64(partEnd - 2)] == UInt8(13)) {
                partEnd = partEnd - 2
            }

            if (boundaryEnd < partEnd) {
                let partData = sliceArray(data, boundaryEnd, partEnd)
                let part = parseSinglePart(partData)
                match (part) {
                    case Some(p) => parts.append(p)
                    case None => ()
                }
            }
        }

        return parts
    }

    /// 解析单个部分 (头部 + body)
    private func parseSinglePart(data: Array<UInt8>): ?MultipartPart {
        let part = MultipartPart()
        let str = bytesToString(data)

        // 查找头部和 body 的分隔: \r\n\r\n
        let headerEnd = str.indexOf("\r\n\r\n")
        if (headerEnd < 0) {
            // 没有头部，整个都是 body
            part.body = data
            return Some(part)
        }

        let headerSection = str.substring(0, headerEnd)
        let bodyStart = headerEnd + 4
        let bodyStr = if (bodyStart < str.size) { str.substring(bodyStart) } else { "" }
        part.body = stringToBytes(bodyStr)

        // 解析头部
        let lines = splitCRLF(headerSection)
        for (line in lines) {
            let colonIdx = line.indexOf(":")
            if (colonIdx >= 0) {
                let name = line.substring(0, colonIdx).trim()
                let value = line.substring(colonIdx + 1).trim()
                let lowerName = name.toLower()
                part.headers.put(lowerName, value)

                // 解析 Content-Disposition
                if (lowerName == "content-disposition") {
                    let result = MultipartPart.parseContentDisposition(value)
                    part.name = result.first
                    part.filename = result.second
                }

                // 解析 Content-Type
                if (lowerName == "content-type") {
                    part.contentType = Some(value)
                }
            }
        }

        return Some(part)
    }

    /// 查找所有边界位置
    private func findAllBoundaryPositions(data: Array<UInt8>): ArrayList<Int64> {
        let positions = ArrayList<Int64>()
        let dataStr = bytesToString(data)
        let boundaryStr = bytesToString(boundaryBytes)

        var searchFrom: Int64 = 0
        while (searchFrom < dataStr.size) {
            let idx = dataStr.indexOfFrom(boundaryStr, searchFrom)
            if (idx < 0) {
                break
            }
            positions.append(idx)
            searchFrom = idx + boundaryStr.size
        }

        return positions
    }

    /// 跳过边界行 (边界 + \r\n)
    private func skipBoundaryLine(data: Array<UInt8>, startPos: Int64): Int64 {
        var pos = startPos + boundaryBytes.size
        // 跳过 \r\n
        if (pos < data.size && data[pos] == UInt8(13)) {
            pos += 1
        }
        if (pos < data.size && data[pos] == UInt8(10)) {
            pos += 1
        }
        return pos
    }
}

// ============================================================================
// FormData2 - 增强版 FormData
// 对应 Bun FormData API，支持 multipart/form-data 解析和构建
// ============================================================================

/// FormData 条目 - 对应 Bun FormData 条目
public class FormDataEntry2 {
    public var name: String
    public var value: ?String       // 文本值
    public var body: ?Array<UInt8>  // 二进制值
    public var filename: ?String
    public var contentType: ?String

    public init(name: String, value: String) {
        this.name = name
        this.value = Some(value)
        this.body = None
        this.filename = None
        this.contentType = None
    }

    public init(name: String, body: Array<UInt8>, filename: ?String, contentType: ?String) {
        this.name = name
        this.value = None
        this.body = Some(body)
        this.filename = filename
        this.contentType = contentType
    }

    /// 是否为文件
    public func isFile(): Bool {
        return match (filename) {
            case Some(_) => true
            case None => false
        }
    }

    /// 获取字符串值
    public func text(): ?String {
        return value
    }
}

/// FormData - 对应 Bun FormData (Web API)
/// 支持从 multipart/form-data 解析和序列化
public class FormData2 {
    /// 条目列表
    private var entries: ArrayList<FormDataEntry2>

    public init() {
        entries = ArrayList<FormDataEntry2>()
    }

    /// 追加文本字段
    public func append(name: String, value: String): Unit {
        entries.append(FormDataEntry2(name, value))
    }

    /// 追加文件字段
    public func append(name: String, body: Array<UInt8>, filename: String, contentType: String): Unit {
        entries.append(FormDataEntry2(name, body, Some(filename), Some(contentType)))
    }

    /// 追加二进制字段
    public func append(name: String, body: Array<UInt8>): Unit {
        entries.append(FormDataEntry2(name, body, None, None))
    }

    /// 获取指定名称的第一个值
    public func get(name: String): ?String {
        for (entry in entries) {
            if (entry.name == name) {
                return entry.text()
            }
        }
        return None
    }

    /// 获取指定名称的所有值
    public func getAll(name: String): ArrayList<String> {
        let result = ArrayList<String>()
        for (entry in entries) {
            if (entry.name == name) {
                match (entry.text()) {
                    case Some(t) => result.append(t)
                    case None => ()
                }
            }
        }
        return result
    }

    /// 是否包含指定名称
    public func has(name: String): Bool {
        for (entry in entries) {
            if (entry.name == name) {
                return true
            }
        }
        return false
    }

    /// 删除指定名称
    public func delete(name: String): Unit {
        let newEntries = ArrayList<FormDataEntry2>()
        for (entry in entries) {
            if (entry.name != name) {
                newEntries.append(entry)
            }
        }
        entries = newEntries
    }

    /// 获取所有条目
    public func entries(): ArrayList<FormDataEntry2> {
        return entries
    }

    /// 条目数量
    public func size(): Int64 {
        return entries.size
    }

    /// 从 multipart 请求体解析
    /// 对应 Bun 从 fetch Request.formData() 解析
    public static func parse(body: Array<UInt8>, contentType: String): ?FormData2 {
        let parser = MultipartParser.fromContentType(contentType)
        match (parser) {
            case Some(p) => {
                let parts = p.parse(body)
                let form = FormData2()
                for (part in parts) {
                    if (part.isFile()) {
                        let ct = match (part.contentType) {
                            case Some(c) => c
                            case None => "application/octet-stream"
                        }
                        form.append(part.name, part.body,
                            match (part.filename) {
                                case Some(f) => f
                                case None => "unknown"
                            },
                            ct)
                    } else {
                        form.append(part.name, part.text())
                    }
                }
                return Some(form)
            }
            case None => None
        }
    }

    /// 序列化为 multipart/form-data 请求体
    public func serialize(): Tuple2<String, Array<UInt8>> {
        // 生成边界
        let boundary = "----BaoFormBoundary${currentTimeMillis().toString()}"
        let sb = StringBuilder()

        for (entry in entries) {
            sb.append("--${boundary}\r\n")

            if (entry.isFile()) {
                let fname = match (entry.filename) {
                    case Some(f) => f
                    case None => "unknown"
                }
                let ct = match (entry.contentType) {
                    case Some(c) => c
                    case None => "application/octet-stream"
                }
                sb.append("Content-Disposition: form-data; name=\"${entry.name}\"; filename=\"${fname}\"\r\n")
                sb.append("Content-Type: ${ct}\r\n")
                sb.append("\r\n")
                // 二进制数据需要特殊处理
                match (entry.body) {
                    case Some(b) => {
                        for (byte in b) {
                            sb.append(Char(Int32(byte)))
                        }
                    }
                    case None => ()
                }
                sb.append("\r\n")
            } else {
                sb.append("Content-Disposition: form-data; name=\"${entry.name}\"\r\n")
                sb.append("\r\n")
                match (entry.value) {
                    case Some(v) => sb.append(v)
                    case None => ()
                }
                sb.append("\r\n")
            }
        }

        sb.append("--${boundary}--\r\n")

        let contentType = "multipart/form-data; boundary=${boundary}"
        return Tuple2<String, Array<UInt8>>(contentType, stringToBytes(sb.toString()))
    }
}

// ============================================================================
// URL 编码表单解析
// application/x-www-form-urlencoded
// ============================================================================

/// URL 编码表单解析器
public class UrlEncodedParser {
    /// 解析 URL 编码的表单数据
    /// 格式: key1=value1&key2=value2
    public static func parse(data: String): HashMap<String, String> {
        let result = HashMap<String, String>()
        let pairs = split(data, "&")
        for (pair in pairs) {
            let eqIdx = pair.indexOf("=")
            if (eqIdx >= 0) {
                let key = urlDecode(pair.substring(0, eqIdx))
                let value = urlDecode(pair.substring(eqIdx + 1))
                result.put(key, value)
            } else {
                result.put(urlDecode(pair), "")
            }
        }
        return result
    }

    /// 序列化为 URL 编码格式
    public static func serialize(data: HashMap<String, String>): String {
        let parts = ArrayList<String>()
        for (key in data.keys()) {
            match (data.get(key)) {
                case Some(value) => parts.append("${urlEncode(key)}=${urlEncode(value)}")
                case None => parts.append(urlEncode(key))
            }
        }
        let sb = StringBuilder()
        for (i in 0..parts.size) {
            if (i > 0) { sb.append("&") }
            sb.append(parts[Int64(i)])
        }
        return sb.toString()
    }

    /// URL 解码 - 对应 Bun decodeURIComponent
    public static func urlDecode(s: String): String {
        let sb = StringBuilder()
        var i = 0
        while (i < s.size) {
            if (s[Int64(i)] == '%' && i + 2 < s.size) {
                let hex = s.substring(Int64(i) + 1, Int64(i) + 3)
                let byte = hexToInt(hex)
                sb.append(Char(Int32(byte)))
                i += 3
            } else if (s[Int64(i)] == '+') {
                sb.append(' ')
                i += 1
            } else {
                sb.append(s[Int64(i)])
                i += 1
            }
        }
        return sb.toString()
    }

    /// URL 编码 - 对应 Bun encodeURIComponent
    public static func urlEncode(s: String): String {
        let unreserved = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~"
        let sb = StringBuilder()
        for (c in s) {
            if (unreserved.contains(c)) {
                sb.append(c)
            } else if (c == ' ') {
                sb.append('+')
            } else {
                let hex = "0123456789ABCDEF"
                let v = Int32(c.value) & 0xFF
                sb.append('%')
                sb.append(hex[Int64(v >> 4)])
                sb.append(hex[Int64(v & 0x0F)])
            }
        }
        return sb.toString()
    }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 按分号分割
private func splitSemicolon(s: String): ArrayList<String> {
    let parts = ArrayList<String>()
    var current = StringBuilder()
    for (c in s) {
        if (c == ';') {
            parts.append(current.toString())
            current = StringBuilder()
        } else {
            current.append(c)
        }
    }
    if (current.toString().size > 0) {
        parts.append(current.toString())
    }
    return parts
}

/// 按 & 分割
private func split(s: String, sep: String): ArrayList<String> {
    let parts = ArrayList<String>()
    var remaining = s
    while (true) {
        let idx = remaining.indexOf(sep)
        if (idx < 0) {
            parts.append(remaining)
            break
        }
        parts.append(remaining.substring(0, idx))
        remaining = remaining.substring(idx + sep.size)
    }
    return parts
}

/// 按 \r\n 分割
private func splitCRLF(s: String): ArrayList<String> {
    let lines = ArrayList<String>()
    var current = StringBuilder()
    var i = 0
    while (i < s.size) {
        if (i + 1 < s.size && s[Int64(i)] == '\r' && s[Int64(i + 1)] == '\n') {
            lines.append(current.toString())
            current = StringBuilder()
            i += 2
        } else {
            current.append(s[Int64(i)])
            i += 1
        }
    }
    if (current.toString().size > 0) {
        lines.append(current.toString())
    }
    return lines
}

/// 去除字符串两端引号
private func stripQuotes(s: String): String {
    if (s.size >= 2 && s[0] == '"' && s[s.size - 1] == '"') {
        return s.substring(1, s.size - 1)
    }
    return s
}

/// 十六进制字符串转整数
private func hexToInt(hex: String): Int64 {
    var result: Int64 = 0
    for (c in hex) {
        result = result * 16
        if (c >= '0' && c <= '9') {
            result += Int64(c.value) - 48
        } else if (c >= 'a' && c <= 'f') {
            result += Int64(c.value) - 87
        } else if (c >= 'A' && c <= 'F') {
            result += Int64(c.value) - 55
        }
    }
    return result
}

/// 字节数组切片
private func sliceArray(arr: Array<UInt8>, start: Int64, end: Int64): Array<UInt8> {
    let result = Array<UInt8>()
    for (i in start..end) {
        result.append(arr[Int64(i)])
    }
    return result
}

/// 字节数组转字符串
private func bytesToString(bytes: Array<UInt8>): String {
    let sb = StringBuilder()
    for (b in bytes) {
        sb.append(Char(Int32(b)))
    }
    return sb.toString()
}

/// 字符串转字节数组
private func stringToBytes(s: String): Array<UInt8> {
    var bytes = Array<UInt8>()
    for (c in s) {
        bytes.append(UInt8(c.value & 0xFF))
    }
    return bytes
}

/// 当前时间 (毫秒)
private func currentTimeMillis(): Int64 {
    unsafe {
        var ts = Array<Int64>(2, item: 0)
        clock_gettime(0, ts.toArray().unsafePtr())
        return ts[0] * 1000 + ts[1] / 1000000
    }
}

/// indexOf 从指定位置开始查找
private func indexOfFrom(s: String, target: String, fromIndex: Int64): Int64 {
    let sub = s.substring(fromIndex)
    let idx = sub.indexOf(target)
    if (idx < 0) { return -1 }
    return fromIndex + idx
}

@C
foreign func clock_gettime(clockid: Int32, tp: CPointer<Int64>): Int32
