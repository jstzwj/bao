// HTTPStatusText - HTTP 状态码对应的文本描述
// 严格翻译自: Bun src/runtime/server/HTTPStatusText.zig
// 对应: HTTPStatusText.get(code) => ?[]const u8
package bao_runtime.server

// ============================================================================
// HTTPStatusText - HTTP 状态码文本映射
// 严格翻译自: src/runtime/server/HTTPStatusText.zig
// Bun: pub fn get(code: u16) ?[]const u8
// ============================================================================

/// HTTP 状态码对应的文本描述
/// 对应 Bun HTTPStatusText.get(code: u16) ?[]const u8
/// 翻译自 Zig switch(code) { ... else => null }
public class HTTPStatusText {

    /// 根据状态码获取对应的 HTTP 状态文本
    /// 严格翻译自: Bun HTTPStatusText.zig -> pub fn get(code: u16) ?[]const u8
    /// Zig 原始实现: return switch (code) { 100 => "100 Continue", ... else => null }
    public static func get(code: Int64): ?String {
        match (code) {
            // 1xx Informational
            // 对应 Zig: 100 => "100 Continue"
            case 100 => Some("100 Continue")
            // 对应 Zig: 101 => "101 Switching protocols"
            case 101 => Some("101 Switching protocols")
            // 对应 Zig: 102 => "102 Processing"
            case 102 => Some("102 Processing")
            // 对应 Zig: 103 => "103 Early Hints"
            case 103 => Some("103 Early Hints")

            // 2xx Success
            // 对应 Zig: 200 => "200 OK"
            case 200 => Some("200 OK")
            case 201 => Some("201 Created")
            case 202 => Some("202 Accepted")
            case 203 => Some("203 Non-Authoritative Information")
            case 204 => Some("204 No Content")
            case 205 => Some("205 Reset Content")
            case 206 => Some("206 Partial Content")
            case 207 => Some("207 Multi-Status")
            case 208 => Some("208 Already Reported")
            case 226 => Some("226 IM Used")

            // 3xx Redirection
            case 300 => Some("300 Multiple Choices")
            case 301 => Some("301 Moved Permanently")
            case 302 => Some("302 Found")
            case 303 => Some("303 See Other")
            case 304 => Some("304 Not Modified")
            case 305 => Some("305 Use Proxy")
            case 306 => Some("306 Switch Proxy")
            case 307 => Some("307 Temporary Redirect")
            case 308 => Some("308 Permanent Redirect")

            // 4xx Client Error
            case 400 => Some("400 Bad Request")
            case 401 => Some("401 Unauthorized")
            case 402 => Some("402 Payment Required")
            case 403 => Some("403 Forbidden")
            case 404 => Some("404 Not Found")
            case 405 => Some("405 Method Not Allowed")
            case 406 => Some("406 Not Acceptable")
            case 407 => Some("407 Proxy Authentication Required")
            case 408 => Some("408 Request Timeout")
            case 409 => Some("409 Conflict")
            case 410 => Some("410 Gone")
            case 411 => Some("411 Length Required")
            case 412 => Some("412 Precondition Failed")
            case 413 => Some("413 Payload Too Large")
            case 414 => Some("414 URI Too Long")
            case 415 => Some("415 Unsupported Media Type")
            case 416 => Some("416 Range Not Satisfiable")
            case 417 => Some("417 Expectation Failed")
            case 418 => Some("418 I'm a Teapot")
            case 421 => Some("421 Misdirected Request")
            case 422 => Some("422 Unprocessable Entity")
            case 423 => Some("423 Locked")
            case 424 => Some("424 Failed Dependency")
            case 425 => Some("425 Too Early")
            case 426 => Some("426 Upgrade Required")
            case 428 => Some("428 Precondition Required")
            case 429 => Some("429 Too Many Requests")
            case 431 => Some("431 Request Header Fields Too Large")
            case 451 => Some("451 Unavailable For Legal Reasons")

            // 5xx Server Error
            case 500 => Some("500 Internal Server Error")
            case 501 => Some("501 Not Implemented")
            case 502 => Some("502 Bad Gateway")
            case 503 => Some("503 Service Unavailable")
            case 504 => Some("504 Gateway Timeout")
            case 505 => Some("505 HTTP Version Not Supported")
            case 506 => Some("506 Variant Also Negotiates")
            case 507 => Some("507 Insufficient Storage")
            case 508 => Some("508 Loop Detected")
            case 510 => Some("510 Not Extended")
            case 511 => Some("511 Network Authentication Required")

            // 对应 Zig: else => null
            case _ => None
        }
    }
}
