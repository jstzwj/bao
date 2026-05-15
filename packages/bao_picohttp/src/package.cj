// bao_picohttp - HTTP/1.x 协议解析器类型与常量
// 严格翻译自: bun/src/picohttp/picohttp.zig (387行)
//   基于 picohttpparser 的 HTTP 请求/响应解析类型
package bao.picohttp

import bao_core.*

// ============================================================================
// Header - HTTP 头部键值对
// 严格翻译自: picohttp.zig - Header
//   pub const Header = struct {
//       name: []const u8, value: []const u8,
//       pub fn isMultiline(self) bool
//       pub fn format(self, writer) !void
//       pub fn count(this, builder) void
//       pub fn clone(this, builder) Header
//       pub const CURLFormatter = struct { ... }
//       pub fn curl(self) CURLFormatter
//   };
// ============================================================================

/// HTTP 头部键值对 - 对应 Bun picohttp.Header
/// 兼容 C picohttpparser 的 phr_header 结构
public class Header {
    /// 头部名称
    public var name: String = ""
    /// 头部值
    public var value: String = ""

    public init() {}

    public init(name: String, value: String) {
        this.name = name
        this.value = value
    }

    /// 是否为多行头部 (名称为空表示续行)
    /// 对应 Bun Header.isMultiline()
    ///   pub fn isMultiline(self: Header) bool { return self.name.len == 0; }
    public func isMultiline(): Bool {
        name.size == 0
    }

    /// 格式化为 "name: value"
    /// 对应 Bun Header.format()
    public func format(): String {
        if (isMultiline()) {
            value
        } else {
            "${name}: ${value}"
        }
    }

    /// 克隆头部
    /// 对应 Bun Header.clone()
    public func clone(): Header {
        Header(name, value)
    }

    /// 格式化为 cURL -H 参数
    /// 对应 Bun Header.CURLFormatter.format()
    ///   try writer.print("-H \"{s}: {s}\"", .{ header.name, header.value });
    public func toCurlHeader(): String {
        if (value.size > 0) {
            "-H \"${name}: ${value}\""
        } else {
            "-H \"${name}\""
        }
    }

    /// 大小写不敏感比较名称
    public func nameEquals(other: String): Bool {
        if (name.size != other.size) { return false }
        for (i in 0..name.size) {
            let a = toLower(name[i])
            let b = toLower(other[i])
            if (a != b) { return false }
        }
        true
    }
}

// ============================================================================
// HeaderList - HTTP 头部列表
// 严格翻译自: picohttp.zig - Header.List
//   pub const List = struct {
//       list: []Header = &.{},
//       pub fn get(this, name) ?string
//       pub fn getIfOtherIsAbsent(this, name, other) ?string
//   };
// ============================================================================

/// HTTP 头部列表 - 对应 Bun Header.List
public class HeaderList {
    public var list: ArrayList<Header>

    public init() {
        list = ArrayList<Header>()
    }

    public init(headers: ArrayList<Header>) {
        list = headers
    }

    /// 根据名称获取头部值 (大小写不敏感)
    /// 对应 Bun Header.List.get()
    ///   pub fn get(this: *const List, name: string) ?string {
    ///       for (this.list) |header| {
    ///           if (strings.eqlCaseInsensitiveASCII(header.name, name, true)) return header.value;
    ///       }
    ///       return null;
    ///   }
    public func get(name: String): ?String {
        for (header in list) {
            if (header.nameEquals(name)) {
                return header.value
            }
        }
        None
    }

    /// 获取 name 对应值, 但仅当 other 不存在时
    /// 对应 Bun Header.List.getIfOtherIsAbsent()
    ///   pub fn getIfOtherIsAbsent(this: *const List, name: string, other: string) ?string {
    ///       var value: ?string = null;
    ///       for (this.list) |header| {
    ///           if (strings.eqlCaseInsensitiveASCII(header.name, other, true)) return null;
    ///           if (value == null && strings.eqlCaseInsensitiveASCII(header.name, name, true)) value = header.value;
    ///       }
    ///       return value;
    ///   }
    public func getIfOtherIsAbsent(name: String, other: String): ?String {
        var value: ?String = None
        for (header in list) {
            // 如果 other 头部存在, 返回 null
            if (header.nameEquals(other)) {
                return None
            }
            // 找到第一个匹配 name 的头部
            if (value.isNone() && header.nameEquals(name)) {
                value = header.value
            }
        }
        value
    }

    /// 添加头部
    public func append(name: String, value: String): Unit {
        list.append(Header(name, value))
    }

    /// 添加头部
    public func append(header: Header): Unit {
        list.append(header)
    }

    /// 头部数量
    public func size(): Int64 {
        list.size
    }

    /// 获取指定索引的头部
    public func get(index: Int64): Header {
        list[index]
    }
}

// ============================================================================
// HttpMethod - HTTP 方法常量
// 严格翻译自: picohttp.zig 中对 method 的使用
// ============================================================================

/// HTTP 方法 - 对应 Bun HTTP 方法字符串常量
public class HttpMethod {
    public static let GET: String = "GET"
    public static let POST: String = "POST"
    public static let PUT: String = "PUT"
    public static let DELETE: String = "DELETE"
    public static let PATCH: String = "PATCH"
    public static let HEAD: String = "HEAD"
    public static let OPTIONS: String = "OPTIONS"
    public static let CONNECT: String = "CONNECT"
    public static let TRACE: String = "TRACE"
}

// ============================================================================
// Request - HTTP 请求
// 严格翻译自: picohttp.zig - Request
//   pub const Request = struct {
//       method: []const u8, path: []const u8, minor_version: usize,
//       headers: []Header, bytes_read: u32 = 0,
//       pub const CURLFormatter = struct { ... }
//       pub fn curl(self, ignore_insecure, body) CURLFormatter
//       pub fn clone(this, headers, builder) Request
//       pub fn format(self, writer) !void
//       pub fn parse(buf, src) !Request
//   };
// ============================================================================

/// HTTP 请求 - 对应 Bun picohttp.Request
public class HttpRequest {
    /// HTTP 方法
    public var method: String = "GET"
    /// 请求路径
    public var path: String = "/"
    /// HTTP 次版本号 (0 = HTTP/1.0, 1 = HTTP/1.1)
    public var minorVersion: Int64 = 1
    /// 请求头部列表
    public var headers: HeaderList
    /// 已读取字节数
    public var bytesRead: UInt32 = 0

    public init() {
        headers = HeaderList()
    }

    public init(method: String, path: String, minorVersion: Int64,
                headers: HeaderList, bytesRead: UInt32) {
        this.method = method
        this.path = path
        this.minorVersion = minorVersion
        this.headers = headers
        this.bytesRead = bytesRead
    }

    /// 格式化请求摘要
    /// 对应 Bun Request.format()
    ///   try writer.print("> HTTP/1.1 {s} {s}\n", .{ self.method, self.path });
    public func format(): String {
        let sb = StringBuilder()
        sb.append("> HTTP/1.${minorVersion} ${method} ${path}\n")
        for (header in headers.list) {
            sb.append("> ${header.format()}\n")
        }
        sb.toString()
    }

    /// 克隆请求
    /// 对应 Bun Request.clone()
    public func clone(): HttpRequest {
        let newHeaders = HeaderList()
        for (header in headers.list) {
            newHeaders.append(header.clone())
        }
        HttpRequest(method, path, minorVersion, newHeaders, bytesRead)
    }

    /// 格式化为 cURL 命令
    /// 对应 Bun Request.CURLFormatter.format()
    ///   curl --http1.1 "path" [-X METHOD] [-H headers] [--compressed] [--data-raw body]
    public func toCurl(ignoreInsecure: Bool, body: String): String {
        let sb = StringBuilder()
        sb.append("curl --http1.1 \"${path}\"")

        // 方法 (非 GET 时显示)
        if (method != HttpMethod.GET) {
            sb.append(" -X ${method}")
        }

        // 忽略证书
        if (ignoreInsecure) {
            sb.append(" -k")
        }

        // 头部
        var contentType = ""
        for (header in headers.list) {
            sb.append(" ${header.toCurlHeader()}")

            // 跟踪 Content-Type
            if (contentType == "" && header.nameEquals("content-type")) {
                contentType = header.value
            }

            // Accept-Encoding 自动添加 --compressed
            if (header.nameEquals("accept-encoding")) {
                sb.append(" --compressed")
            }
        }

        // Body (仅当内容类型可打印时)
        if (body.size > 0 && isPrintableBody(contentType)) {
            sb.append(" --data-raw '${body}'")
        }

        sb.toString()
    }

    /// 简化版 toCurl (无 body)
    public func toCurl(ignoreInsecure: Bool): String {
        toCurl(ignoreInsecure, "")
    }

    /// 解析 HTTP 请求
    /// 对应 Bun Request.parse()
    ///   const rc = c.phr_parse_request(buf.ptr, buf.len, &method, &path,
    ///       &minor_version, @ptrCast(src.ptr), &num_headers, 0);
    ///   switch (rc) { -1 => error.BadRequest, -2 => error.ShortRead, else => Request{...} }
    public static func parse(buf: Array<Byte>): ?ParseResult {
        parse(String.fromUtf8(buf))
    }

    /// 从字符串解析 HTTP 请求
    public static func parse(buf: String): ?ParseResult {
        let request = HttpRequest()

        // 找到请求行结束
        let lineEnd = buf.indexOf("\r\n")
        if (lineEnd < 0) { return None }

        // 解析请求行: METHOD PATH HTTP/1.x
        let requestLine = buf.subString(0, lineEnd)
        let parts = splitSpaces(requestLine)
        if (parts.size < 3) { return None }

        request.method = parts[0]
        request.path = parts[1]

        // 解析 HTTP 版本
        let versionStr = parts[2]
        if (versionStr.startsWith("HTTP/1.")) {
            request.minorVersion = Int64.parse(versionStr.subString(7)).getOr(1)
        }

        // 解析头部
        var pos = lineEnd + 2
        while (pos < buf.size) {
            let nextEnd = buf.indexOf("\r\n", pos)
            if (nextEnd < 0) { break }

            let line = buf.subString(pos, nextEnd - pos)
            if (line == "") {
                // 空行表示头部结束
                request.bytesRead = UInt32(nextEnd + 2)
                break
            }

            let colonIdx = line.indexOf(": ")
            if (colonIdx >= 0) {
                let name = line.subString(0, colonIdx)
                let value = line.subString(colonIdx + 2)
                request.headers.append(name, value)
            }

            pos = nextEnd + 2
        }

        ParseResult(request, true)
    }

    /// 判断 body 是否为可打印内容
    /// 对应 Bun Request.CURLFormatter.isPrintableBody()
    ///   return bun.strings.hasPrefixComptime(content_type, "text/") or
    ///       bun.strings.hasPrefixComptime(content_type, "application/json") or ...
    static func isPrintableBody(contentType: String): Bool {
        if (contentType == "") { return false }
        contentType.startsWith("text/") ||
        contentType.startsWith("application/json") ||
        contentType.contains("json") ||
        contentType.startsWith("application/x-www-form-urlencoded")
    }
}

// ============================================================================
// Response - HTTP 响应
// 严格翻译自: picohttp.zig - Response
//   pub const Response = struct {
//       minor_version: usize = 0, status_code: u32 = 0, status: []const u8 = "",
//       headers: Header.List = .{}, bytes_read: c_int = 0,
//       pub fn format(self, writer) !void
//       pub fn count(this, builder) void
//       pub fn clone(this, headers, builder) Response
//       pub fn parseParts(buf, src, offset) !Response
//       pub fn parse(buf, src) !Response
//   };
// ============================================================================

/// HTTP 响应 - 对应 Bun picohttp.Response
public class HttpResponse {
    /// HTTP 次版本号
    public var minorVersion: Int64 = 0
    /// 状态码
    public var statusCode: UInt32 = 0
    /// 状态文本
    public var status: String = ""
    /// 响应头部列表
    public var headers: HeaderList
    /// 已读取字节数
    public var bytesRead: Int32 = 0

    public init() {
        headers = HeaderList()
    }

    public init(minorVersion: Int64, statusCode: UInt32, status: String,
                headers: HeaderList, bytesRead: Int32) {
        this.minorVersion = minorVersion
        this.statusCode = statusCode
        this.status = status
        this.headers = headers
        this.bytesRead = bytesRead
    }

    /// 格式化响应摘要
    /// 对应 Bun Response.format()
    ///   try writer.print("< {f} {s}\n", .{ StatusCodeFormatter{.code = self.status_code}, self.status });
    public func format(): String {
        let sb = StringBuilder()
        sb.append("< HTTP/1.${minorVersion} ${statusCode} ${status}\n")
        for (header in headers.list) {
            sb.append("< ${header.format()}\n")
        }
        sb.toString()
    }

    /// 克隆响应
    /// 对应 Bun Response.clone()
    public func clone(): HttpResponse {
        let newHeaders = HeaderList()
        for (header in headers.list) {
            newHeaders.append(header.clone())
        }
        HttpResponse(minorVersion, statusCode, status, newHeaders, bytesRead)
    }

    /// 是否为成功状态码 (2xx)
    public func isSuccess(): Bool {
        statusCode >= 200 && statusCode < 300
    }

    /// 是否为重定向 (3xx)
    public func isRedirect(): Bool {
        statusCode >= 300 && statusCode < 400
    }

    /// 是否为客户端错误 (4xx)
    public func isClientError(): Bool {
        statusCode >= 400 && statusCode < 500
    }

    /// 是否为服务器错误 (5xx)
    public func isServerError(): Bool {
        statusCode >= 500 && statusCode < 600
    }

    /// 解析 HTTP 响应
    /// 对应 Bun Response.parse()
    ///   const rc = c.phr_parse_response(buf.ptr, buf.len, &minor_version,
    ///       &status_code, &status, @ptrCast(src.ptr), &num_headers, offset.*);
    ///   switch (rc) { -1 => error.Malformed_HTTP_Response, -2 => error.ShortRead, else => Response{...} }
    public static func parse(buf: String): ?ParseResult {
        let response = HttpResponse()

        // 找到状态行结束
        let lineEnd = buf.indexOf("\r\n")
        if (lineEnd < 0) { return None }

        // 解析状态行: HTTP/1.x STATUS_CODE STATUS_TEXT
        let statusLine = buf.subString(0, lineEnd)
        let parts = splitSpaces(statusLine)
        if (parts.size < 2) { return None }

        // 解析 HTTP 版本
        let versionStr = parts[0]
        if (versionStr.startsWith("HTTP/1.")) {
            response.minorVersion = Int64.parse(versionStr.subString(7)).getOr(1)
        }

        // 解析状态码
        response.statusCode = UInt32(Int32.parse(parts[1]).getOr(0))

        // 解析状态文本
        if (parts.size >= 3) {
            let restStart = statusLine.indexOf(" ", statusLine.indexOf(" ") + 1)
            if (restStart >= 0) {
                response.status = statusLine.subString(restStart + 1)
            }
        }

        // 解析头部
        var pos = lineEnd + 2
        while (pos < buf.size) {
            let nextEnd = buf.indexOf("\r\n", pos)
            if (nextEnd < 0) { break }

            let line = buf.subString(pos, nextEnd - pos)
            if (line == "") {
                response.bytesRead = Int32(nextEnd + 2)
                break
            }

            let colonIdx = line.indexOf(": ")
            if (colonIdx >= 0) {
                let name = line.subString(0, colonIdx)
                let value = line.subString(colonIdx + 2)
                response.headers.append(name, value)
            }

            pos = nextEnd + 2
        }

        ParseResult(response, true)
    }

    /// 从字节数组解析 HTTP 响应
    public static func parse(buf: Array<Byte>): ?ParseResult {
        parse(String.fromUtf8(buf))
    }
}

// ============================================================================
// Headers - HTTP 头部集合 (用于 parse_headers)
// 严格翻译自: picohttp.zig - Headers
//   pub const Headers = struct {
//       headers: []const Header,
//       pub fn format(self, writer) !void
//       pub fn parse(buf, src) !Headers
//   };
// ============================================================================

/// HTTP 头部集合 - 对应 Bun picohttp.Headers
/// 仅用于解析头部 (不解析请求行/状态行)
public class HttpHeaders {
    public var headers: ArrayList<Header>

    public init() {
        headers = ArrayList<Header>()
    }

    /// 格式化为字符串
    /// 对应 Bun Headers.format()
    ///   try writer.print("{s}: {s}\r\n", .{ header.name, header.value });
    public func format(): String {
        let sb = StringBuilder()
        for (header in headers) {
            sb.append("${header.name}: ${header.value}\r\n")
        }
        sb.toString()
    }

    /// 解析 HTTP 头部块
    /// 对应 Bun Headers.parse()
    ///   const rc = c.phr_parse_headers(buf.ptr, buf.len,
    ///       @ptrCast(src.ptr), @ptrCast(&num_headers), 0);
    public static func parse(buf: String): ?ParseResult {
        let result = HttpHeaders()
        var pos = 0

        while (pos < buf.size) {
            let lineEnd = buf.indexOf("\r\n", pos)
            if (lineEnd < 0) { break }

            let line = buf.subString(pos, lineEnd - pos)
            if (line == "") {
                break
            }

            let colonIdx = line.indexOf(": ")
            if (colonIdx >= 0) {
                result.headers.append(Header(line.subString(0, colonIdx),
                                              line.subString(colonIdx + 2)))
            }

            pos = lineEnd + 2
        }

        ParseResult(result, true)
    }

    /// 从字节数组解析
    public static func parse(buf: Array<Byte>): ?ParseResult {
        parse(String.fromUtf8(buf))
    }
}

// ============================================================================
// ParseResult - 解析结果
// 严格翻译自: picohttp.zig 中 phr_parse_* 的返回值语义
//   -1 => error.BadRequest, -2 => error.ShortRead, else => Result
// ============================================================================

/// HTTP 解析结果 - 对应 Bun phr_parse_* 的返回值
public class ParseResult {
    /// 解析出的对象
    public var value: Any
    /// 是否成功
    public var success: Bool

    public init(value: Any, success: Bool) {
        this.value = value
        this.success = success
    }
}

// ============================================================================
// ParseError - 解析错误
// 严格翻译自: picohttp.zig 中的错误类型
//   error.BadRequest, error.ShortRead, error.Malformed_HTTP_Response,
//   error.BadHeaders, error.Fail
// ============================================================================

/// HTTP 解析错误 - 对应 Bun picohttp 解析错误
public enum ParseError {
    | BadRequest
    | ShortRead
    | MalformedResponse
    | BadHeaders
    | Fail

    public func message(): String {
        match (this) {
            case BadRequest => "Bad request"
            case ShortRead => "Short read (incomplete data)"
            case MalformedResponse => "Malformed HTTP response"
            case BadHeaders => "Bad headers"
            case Fail => "Parse failed"
        }
    }
}

// ============================================================================
// HttpStatusCode - HTTP 状态码常量
// 严格翻译自: picohttp.zig 中状态码的使用 (StatusCodeFormatter)
// ============================================================================

/// HTTP 状态码 - 对应常用 HTTP 状态码
public class HttpStatusCode {
    // 1xx 信息
    public static let CONTINUE: UInt32 = 100
    public static let SWITCHING_PROTOCOLS: UInt32 = 101

    // 2xx 成功
    public static let OK: UInt32 = 200
    public static let CREATED: UInt32 = 201
    public static let ACCEPTED: UInt32 = 202
    public static let NO_CONTENT: UInt32 = 204

    // 3xx 重定向
    public static let MOVED_PERMANENTLY: UInt32 = 301
    public static let FOUND: UInt32 = 302
    public static let SEE_OTHER: UInt32 = 303
    public static let NOT_MODIFIED: UInt32 = 304
    public static let TEMPORARY_REDIRECT: UInt32 = 307
    public static let PERMANENT_REDIRECT: UInt32 = 308

    // 4xx 客户端错误
    public static let BAD_REQUEST: UInt32 = 400
    public static let UNAUTHORIZED: UInt32 = 401
    public static let FORBIDDEN: UInt32 = 403
    public static let NOT_FOUND: UInt32 = 404
    public static let METHOD_NOT_ALLOWED: UInt32 = 405
    public static let REQUEST_TIMEOUT: UInt32 = 408
    public static let CONFLICT: UInt32 = 409
    public static let GONE: UInt32 = 410
    public static let PAYLOAD_TOO_LARGE: UInt32 = 413
    public static let URI_TOO_LONG: UInt32 = 414
    public static let UNSUPPORTED_MEDIA_TYPE: UInt32 = 415
    public static let TOO_MANY_REQUESTS: UInt32 = 429

    // 5xx 服务器错误
    public static let INTERNAL_SERVER_ERROR: UInt32 = 500
    public static let NOT_IMPLEMENTED: UInt32 = 501
    public static let BAD_GATEWAY: UInt32 = 502
    public static let SERVICE_UNAVAILABLE: UInt32 = 503
    public static let GATEWAY_TIMEOUT: UInt32 = 504
}

// ============================================================================
// ChunkedDecoder - 分块传输编码解码器
// 严格翻译自: picohttp.zig - phr_chunked_decoder
//   pub const phr_chunked_decoder = c.phr_chunked_decoder;
//   pub const phr_decode_chunked = c.phr_decode_chunked;
//   pub const phr_decode_chunked_is_in_data = c.phr_decode_chunked_is_in_data;
// ============================================================================

/// 分块传输编码解码器状态 - 对应 Bun phr_chunked_decoder
public class ChunkedDecoder {
    /// 状态: 0 = 读取 chunk 大小, 1 = 读取 chunk 数据
    public var state: Int64 = 0
    /// 剩余 chunk 大小
    public var chunkSize: Int64 = 0
    /// 已消费字节数
    public var bytesConsumed: Int64 = 0

    public init() {}

    /// 解码分块数据
    /// 对应 Bun phr_decode_chunked()
    /// 返回解码后的数据, 或 None 如果数据不完整
    public func decode(data: Array<Byte>): ?Array<Byte> {
        let output = ArrayList<Byte>()
        var pos = 0

        while (pos < data.size) {
            if (state == 0) {
                // 读取 chunk 大小行
                let lineEnd = findCRLF(data, pos)
                if (lineEnd < 0) {
                    // 数据不完整
                    bytesConsumed = pos
                    if (output.size > 0) { return output.toArray() }
                    return None
                }

                let sizeStr = String.fromUtf8(data[pos..lineEnd])
                // 移除分块扩展 (; 后面的内容)
                let semiIdx = sizeStr.indexOf(";")
                let sizePart = if (semiIdx >= 0) { sizeStr.subString(0, semiIdx) } else { sizeStr }
                chunkSize = Int64.parse(sizePart, 16).getOr(-1)

                if (chunkSize < 0) {
                    return None // 无效的 chunk 大小
                }

                if (chunkSize == 0) {
                    // 最后一个 chunk (大小为 0)
                    bytesConsumed = lineEnd + 2
                    state = 2 // 完成
                    return output.toArray()
                }

                pos = lineEnd + 2
                state = 1
            } else if (state == 1) {
                // 读取 chunk 数据
                let remaining = data.size - pos
                let toRead = if (remaining < chunkSize) { remaining } else { chunkSize }
                for (i in 0..toRead) {
                    output.append(data[pos + i])
                }
                pos += toRead
                chunkSize -= toRead

                if (chunkSize == 0) {
                    // chunk 数据后应该有 CRLF
                    if (pos + 2 <= data.size && data[pos] == '\r' && data[pos + 1] == '\n') {
                        pos += 2
                    }
                    state = 0
                } else {
                    // 数据不完整
                    bytesConsumed = pos
                    return output.toArray()
                }
            }
        }

        bytesConsumed = pos
        output.toArray()
    }

    /// 是否正在读取数据
    /// 对应 Bun phr_decode_chunked_is_in_data()
    public func isInData(): Bool {
        state == 1
    }

    /// 查找 CRLF 位置
    static func findCRLF(data: Array<Byte>, start: Int64): Int64 {
        var i = start
        while (i < data.size - 1) {
            if (data[i] == '\r' && data[i + 1] == '\n') {
                return i
            }
            i += 1
        }
        -1
    }
}

// ============================================================================
// C API 类型别名
// 严格翻译自: picohttp.zig 中的 C API 导出
//   pub const phr_header = c.phr_header;
//   pub const phr_chunked_decoder = c.phr_chunked_decoder;
//   pub const phr_parse_request = c.phr_parse_request;
//   pub const phr_parse_response = c.phr_parse_response;
//   pub const phr_parse_headers = c.phr_parse_headers;
//   pub const phr_decode_chunked = c.phr_decode_chunked;
// ============================================================================

/// picohttpparser C API 返回码常量 - 对应 Bun C API 绑定
public class PhrReturnCode {
    /// 解析错误
    public static let ERROR: Int32 = -1
    /// 数据不完整
    public static let SHORT_READ: Int32 = -2
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 字符转小写
static func toLower(c: Char): Char {
    if (c >= 'A' && c <= 'Z') {
        Char(c.value + 32)
    } else {
        c
    }
}

/// 按空格分割字符串
static func splitSpaces(s: String): ArrayList<String> {
    let parts = ArrayList<String>()
    let sb = StringBuilder()
    for (c in s) {
        if (c == ' ' || c == '\t') {
            if (sb.size() > 0) {
                parts.append(sb.toString())
                sb.clear()
            }
        } else {
            sb.append(c)
        }
    }
    if (sb.size() > 0) {
        parts.append(sb.toString())
    }
    parts
}

/// 字符串查找 (从指定位置开始)
static func indexOf(s: String, target: String, start: Int64): Int64 {
    if (target == "") { return start }
    var i = start
    while (i <= s.size - target.size) {
        var match = true
        for (j in 0..target.size) {
            if (s[i + j] != target[j]) {
                match = false
                break
            }
        }
        if (match) { return i }
        i += 1
    }
    -1
}
