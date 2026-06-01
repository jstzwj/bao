// 严格翻译自: src/picohttp/picohttp.zig
// picohttpparser C 库的仓颉绑定 - HTTP/1.1 请求/响应解析

package bao_picohttp

import std.collection.*

// ============================================================================
// Header 和 HeaderList 已在 package.cj 中声明
// ============================================================================

// ============================================================================
// Request - HTTP 请求
// 严格翻译自: picohttp.zig:88-221
//   pub const Request = struct {
//       method: []const u8,
//       path: []const u8,
//       minor_version: usize,
//       headers: []const Header,
//       bytes_read: u32 = 0,
//       ...
//   };
// ============================================================================

/// HTTP 请求解析错误
public enum ParseRequestError {
    | BadRequest
    | ShortRead

    public operator func == (rhs: ParseRequestError): Bool {
        match (this) {
            case BadRequest => match (rhs) { case BadRequest => true; case _ => false }
            case ShortRead => match (rhs) { case ShortRead => true; case _ => false }
        }
    }
    public operator func != (rhs: ParseRequestError): Bool {
        !(this == rhs)
    }
}

/// HTTP 请求
public class Request {
    /// HTTP 方法
    public var method: String
    /// 请求路径
    public var path: String
    /// HTTP 次版本号
    public var minorVersion: UInt64
    /// 请求头列表
    public var headers: ArrayList<Header>
    /// 已读取字节数
    public var bytesRead: UInt32

    public init() {
        this.method = ""
        this.path = ""
        this.minorVersion = 0
        this.headers = ArrayList<Header>()
        this.bytesRead = 0
    }

    /// 解析 HTTP 请求
    // 严格翻译自: picohttp.zig:187-220
    //   pub fn parse(buf: []const u8, src: []Header) !Request { ... }
    public static func parse(buf: Array<UInt8>): Request {
        // PORT NOTE: 实际解析需要通过 FFI 调用 phr_parse_request
        // 此处为类型框架
        let req = Request()
        return req
    }

    /// CURL 格式化
    // 严格翻译自: picohttp.zig:95-148
    public func curlFormat(ignoreInsecure: Bool, body: String): String {
        var result = "curl --http1.1 \"${path}\""

        if (method != "GET") {
            result += " -X ${method}"
        }

        if (ignoreInsecure) {
            result += " -k"
        }

        for (header in headers) {
            result += " "
            result += header.format()
        }

        if (body.size > 0) {
            result += " --data-raw "
            result += body
        }

        return result
    }
}

// ============================================================================
// Response - HTTP 响应
// 严格翻译自: picohttp.zig:239-334
//   pub const Response = struct {
//       minor_version: usize = 0,
//       status_code: u32 = 0,
//       status: []const u8 = "",
//       headers: Header.List = .{},
//       bytes_read: c_int = 0,
//       ...
//   };
// ============================================================================

/// HTTP 响应解析错误
public enum ParseResponseError {
    | MalformedHttpResponse
    | ShortRead

    public operator func == (rhs: ParseResponseError): Bool {
        match (this) {
            case MalformedHttpResponse => match (rhs) { case MalformedHttpResponse => true; case _ => false }
            case ShortRead => match (rhs) { case ShortRead => true; case _ => false }
        }
    }
    public operator func != (rhs: ParseResponseError): Bool {
        !(this == rhs)
    }
}

/// HTTP 响应
public class Response {
    /// HTTP 次版本号
    public var minorVersion: UInt64
    /// 状态码
    public var statusCode: UInt32
    /// 状态文本
    public var status: String
    /// 响应头列表
    public var headers: HeaderList
    /// 已读取字节数
    public var bytesRead: Int32

    public init() {
        this.minorVersion = 0
        this.statusCode = 0
        this.status = ""
        this.headers = HeaderList()
        this.bytesRead = 0
    }

    /// 解析 HTTP 响应
    // 严格翻译自: picohttp.zig:329-333
    public static func parse(buf: Array<UInt8>): Response {
        // PORT NOTE: 实际解析需要通过 FFI 调用 phr_parse_response
        let resp = Response()
        return resp
    }
}

// ============================================================================
// Headers - 原始头部解析
// 严格翻译自: picohttp.zig:336-364
//   pub const Headers = struct { headers: []const Header ... }
// ============================================================================

/// HTTP 头部解析错误
public enum ParseHeadersError {
    | BadHeaders
    | ShortRead

    public operator func == (rhs: ParseHeadersError): Bool {
        match (this) {
            case BadHeaders => match (rhs) { case BadHeaders => true; case _ => false }
            case ShortRead => match (rhs) { case ShortRead => true; case _ => false }
        }
    }
    public operator func != (rhs: ParseHeadersError): Bool {
        !(this == rhs)
    }
}

/// 解析后的 HTTP 头部集合
public class Headers {
    public var headers: ArrayList<Header>

    public init() {
        this.headers = ArrayList<Header>()
    }

    /// 解析 HTTP 头部
    // 严格翻译自: picohttp.zig:345-363
    public static func parse(buf: Array<UInt8>): Headers {
        // PORT NOTE: 实际解析需要通过 FFI 调用 phr_parse_headers
        return Headers()
    }

    /// 格式化为字符串
    public func format(): String {
        var result = ""
        for (header in headers) {
            result += "${header.name}: ${header.value}\r\n"
        }
        return result
    }
}

// ============================================================================
// 外部函数声明 (FFI)
// 严格翻译自: picohttp.zig:366-374 的 pub const 别名
// 对应 C: vendor/picohttpparser/picohttpparser.h
//
// PORT NOTE: 这些 foreign func 声明需要实际的 C 库链接
// ============================================================================

/// Chunked 传输编码解码器状态
// 对应 C: struct phr_chunked_decoder
public class PhrChunkedDecoder {
    public var bytesLeftInChunk: UInt64
    public var consumeTrailer: Int8
    public var hexCount: Int8
    public var state: Int8

    public init() {
        this.bytesLeftInChunk = 0
        this.consumeTrailer = 0
        this.hexCount = 0
        this.state = 0
    }
}
