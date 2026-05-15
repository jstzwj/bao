// 严格翻译自: src/s3_signing/error.zig
//   Bun 的 S3 错误类型:
//   - ErrorCodeAndMessage: 错误码 + 消息
//   - getSignErrorMessage(): 获取签名错误的用户友好消息
//   - getSignErrorCodeAndMessage(): 获取签名错误的错误码和消息
//   - S3Error: 完整的 S3 错误结构
//   - getJSSignError, throwSignError: JS 绑定 (此处为仓颉等价)
package bao_s3_signing

import bao_core.*

// ============================================================================
// S3 签名错误码
// 严格翻译自: error.zig 中的 anyerror 和 getSignErrorCodeAndMessage 的错误码
//   对应 Zig 错误集:
//     error.MissingCredentials
//     error.InvalidMethod
//     error.InvalidPath
//     error.InvalidEndpoint
//     error.InvalidSessionToken
//     error.SignError
//     error.FailedToGenerateSignature
// ============================================================================

/// S3 签名错误码
/// 对应 Bun: error.zig 中 getSignErrorCodeAndMessage 的各个 case
public enum S3SignError {
    | MissingCredentials        // error.MissingCredentials
    | InvalidMethod             // error.InvalidMethod
    | InvalidPath               // error.InvalidPath
    | InvalidEndpoint           // error.InvalidEndpoint
    | InvalidSessionToken       // error.InvalidSessionToken
    | SignError                 // error.SignError
    | FailedToGenerateSignature // error.FailedToGenerateSignature

    /// 错误码字符串
    /// 对应 Bun: getSignErrorCodeAndMessage 中的 .code 字段
    public func code(): String {
        match (this) {
            case MissingCredentials => "ERR_S3_MISSING_CREDENTIALS"
            case InvalidMethod => "ERR_S3_INVALID_METHOD"
            case InvalidPath => "ERR_S3_INVALID_PATH"
            case InvalidEndpoint => "ERR_S3_INVALID_ENDPOINT"
            case InvalidSessionToken => "ERR_S3_INVALID_SESSION_TOKEN"
            case SignError => "ERR_S3_INVALID_SIGNATURE"
            case FailedToGenerateSignature => "ERR_S3_SIGN_FAILED"
        }
    }
}

// ============================================================================
// ErrorCodeAndMessage - 错误码和消息对
// 严格翻译自: error.zig pub const ErrorCodeAndMessage = struct {
//   code: []const u8,
//   message: []const u8,
// };
// ============================================================================

/// S3 错误码和消息
/// 对应 Bun: ErrorCodeAndMessage = struct { code: []const u8, message: []const u8 }
public class ErrorCodeAndMessage {
    /// 错误码 (如 "ERR_S3_MISSING_CREDENTIALS")
    /// 对应 Bun: code: []const u8
    public var code: String
    /// 错误消息
    /// 对应 Bun: message: []const u8
    public var message: String

    public init(code: String, message: String) {
        this.code = code
        this.message = message
    }
}

// ============================================================================
// S3Error - 完整的 S3 错误
// 严格翻译自: error.zig pub const S3Error = struct {
//   code: []const u8,
//   message: []const u8,
//   pub const toJS = ...
//   pub const toJSWithAsyncStack = ...
// };
// ============================================================================

/// S3 错误
/// 对应 Bun: S3Error = struct { code: []const u8, message: []const u8 }
/// 用于传递 S3 操作中的错误信息
public class S3Error {
    /// 错误码
    /// 对应 Bun: code: []const u8
    public var code: String
    /// 错误消息
    /// 对应 Bun: message: []const u8
    public var message: String

    public init(code: String, message: String) {
        this.code = code
        this.message = message
    }

    /// 从 S3SignError 创建
    public static func fromSignError(err: S3SignError): S3Error {
        return S3Error(
            code: err.code(),
            message: getSignErrorMessage(err)
        )
    }

    /// 格式化为字符串
    public func format(): String {
        return "[${code}] ${message}"
    }

    public func toString(): String {
        return format()
    }
}

// ============================================================================
// getSignErrorMessage - 获取签名错误消息
// 严格翻译自: error.zig
//   pub fn getSignErrorMessage(comptime err: anyerror) [:0]const u8 {
//       return switch (err) {
//           error.MissingCredentials => return "Missing S3 credentials. ...",
//           error.InvalidMethod => return "Method must be GET, PUT, DELETE or HEAD ...",
//           error.InvalidPath => return "Invalid S3 bucket, key combination",
//           error.InvalidEndpoint => return "Invalid S3 endpoint",
//           error.InvalidSessionToken => return "Invalid session token",
//           else => return "Failed to retrieve S3 content. ...",
//       };
//   }
// ============================================================================

/// 获取签名错误消息
/// 对应 Bun: pub fn getSignErrorMessage(comptime err: anyerror) [:0]const u8
/// 返回用户友好的错误描述
public func getSignErrorMessage(err: S3SignError): String {
    match (err) {
        case MissingCredentials => "Missing S3 credentials. 'accessKeyId', 'secretAccessKey', 'bucket', and 'endpoint' are required"
        case InvalidMethod => "Method must be GET, PUT, DELETE or HEAD when using s3:// protocol"
        case InvalidPath => "Invalid S3 bucket, key combination"
        case InvalidEndpoint => "Invalid S3 endpoint"
        case InvalidSessionToken => "Invalid session token"
        case SignError => "Failed to retrieve S3 content. Are the credentials correct?"
        case FailedToGenerateSignature => "Failed to generate S3 signature"
    }
}

// ============================================================================
// getSignErrorCodeAndMessage - 获取签名错误码和消息
// 严格翻译自: error.zig
//   pub fn getSignErrorCodeAndMessage(err: anyerror) ErrorCodeAndMessage {
//       return switch (err) {
//           error.MissingCredentials => .{ .code = "ERR_S3_MISSING_CREDENTIALS", ... },
//           error.InvalidMethod => .{ .code = "ERR_S3_INVALID_METHOD", ... },
//           ...
//       };
//   }
// ============================================================================

/// 获取签名错误码和消息
/// 对应 Bun: pub fn getSignErrorCodeAndMessage(err: anyerror) ErrorCodeAndMessage
/// 保持错误码一致性用于内部错误
public func getSignErrorCodeAndMessage(err: S3SignError): ErrorCodeAndMessage {
    // keep error codes consistent for internal errors
    return ErrorCodeAndMessage(
        code: err.code(),
        message: getSignErrorMessage(err)
    )
}

// ============================================================================
// containsNewlineOrCR - 检查字符串是否包含换行符
// 严格翻译自: credentials.zig
//   fn containsNewlineOrCR(value: []const u8) bool {
//       return strings.indexOfAny(value, "\r\n") != null;
//   }
// 防止 HTTP 头注入
// ============================================================================

/// 检查字符串是否包含换行符 (防止 HTTP 头注入)
/// 对应 Bun: credentials.zig containsNewlineOrCR(value) -> bool
/// 检查字符串是否包含 CR (\r) 或 LF (\n) 字符
public func containsNewlineOrCR(value: String): Bool {
    for (i in 0..value.size) {
        let c = value[Int64(i)]
        if (c == Char('\r') || c == Char('\n')) {
            return true
        }
    }
    return false
}
