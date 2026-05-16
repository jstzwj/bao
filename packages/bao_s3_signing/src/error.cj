// bao_http - S3 错误处理
// 严格翻译自: src/s3_signing/error.zig
//   Bun 的 S3 错误类型:
//   - ErrorCodeAndMessage: 错误码 + 消息
//   - getSignErrorMessage(): 获取签名错误的用户友好消息
//   - getSignErrorCodeAndMessage(): 获取签名错误的错误码和消息
//   - S3Error: 完整的 S3 错误结构
package bao_s3_signing

import bao_core.*

// ============================================================================
// S3 错误码
// 严格翻译自: error.zig getSignErrorCodeAndMessage 中的错误码
// ============================================================================

/// S3 签名错误码
/// 对应 Bun: error.zig 中的错误码常量
public enum S3ErrorCode {
    | MissingCredentials       // ERR_S3_MISSING_CREDENTIALS
    | InvalidMethod            // ERR_S3_INVALID_METHOD
    | InvalidPath              // ERR_S3_INVALID_PATH
    | InvalidEndpoint          // ERR_S3_INVALID_ENDPOINT
    | InvalidSessionToken      // ERR_S3_INVALID_SESSION_TOKEN
    | InvalidSignature         // ERR_S3_INVALID_SIGNATURE
    | FailedToGenerateSignature // 签名生成失败

    public func code(): String {
        match (this) {
            case MissingCredentials => "ERR_S3_MISSING_CREDENTIALS"
            case InvalidMethod => "ERR_S3_INVALID_METHOD"
            case InvalidPath => "ERR_S3_INVALID_PATH"
            case InvalidEndpoint => "ERR_S3_INVALID_ENDPOINT"
            case InvalidSessionToken => "ERR_S3_INVALID_SESSION_TOKEN"
            case InvalidSignature => "ERR_S3_INVALID_SIGNATURE"
            case FailedToGenerateSignature => "ERR_S3_SIGN_FAILED"
        }
    }
}

// ============================================================================
// ErrorCodeAndMessage - 错误码和消息对
// 严格翻译自: error.zig ErrorCodeAndMessage struct
// ============================================================================

/// S3 错误码和消息
/// 对应 Bun: ErrorCodeAndMessage = struct { code: []const u8, message: []const u8 }
public class S3ErrorCodeAndMessage {
    /// 错误码 (如 "ERR_S3_MISSING_CREDENTIALS")
    public var code: String
    /// 错误消息
    public var message: String

    public init(code: String, message: String) {
        this.code = code
        this.message = message
    }
}

// ============================================================================
// S3Error - 完整的 S3 错误
// 严格翻译自: error.zig S3Error struct
// ============================================================================

/// S3 错误
/// 对应 Bun: S3Error = struct { code: []const u8, message: []const u8 }
/// 用于传递 S3 操作中的错误信息
public class S3Error {
    /// 错误码
    public var code: String
    /// 错误消息
    public var message: String

    public init(code: String, message: String) {
        this.code = code
        this.message = message
    }

    /// 从 S3ErrorCode 创建
    public static func fromErrorCode(errorCode: S3ErrorCode): S3Error {
        return S3Error(errorCode.code(), getSignErrorMessage(errorCode))
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
// 错误消息获取
// 严格翻译自: error.zig getSignErrorMessage / getSignErrorCodeAndMessage
// ============================================================================

/// 获取签名错误消息
/// 对应 Bun: pub fn getSignErrorMessage(comptime err: anyerror) [:0]const u8
/// 返回用户友好的错误描述
public func getSignErrorMessage(errorCode: S3ErrorCode): String {
    match (errorCode) {
        case MissingCredentials => "Missing S3 credentials. 'accessKeyId', 'secretAccessKey', 'bucket', and 'endpoint' are required"
        case InvalidMethod => "Method must be GET, PUT, DELETE or HEAD when using s3:// protocol"
        case InvalidPath => "Invalid S3 bucket, key combination"
        case InvalidEndpoint => "Invalid S3 endpoint"
        case InvalidSessionToken => "Invalid session token"
        case InvalidSignature => "Failed to retrieve S3 content. Are the credentials correct?"
        case FailedToGenerateSignature => "Failed to generate S3 signature"
    }
}

/// 获取签名错误码和消息
/// 对应 Bun: pub fn getSignErrorCodeAndMessage(err: anyerror) ErrorCodeAndMessage
/// 返回错误码常量 (保持内部错误码一致性)
public func getSignErrorCodeAndMessage(errorCode: S3ErrorCode): S3ErrorCodeAndMessage {
    return S3ErrorCodeAndMessage(errorCode.code(), getSignErrorMessage(errorCode))
}

/// 从异常创建 S3 错误
/// 对应 Bun: 错误处理中的 catch |err| 模式
public func s3ErrorFromException(e: BaoError): S3Error {
    match (e.code) {
        case InvalidArgument => S3Error.fromErrorCode(S3ErrorCode.MissingCredentials)
        case _ => S3Error("ERR_S3_UNKNOWN", e.message)
    }
}

/// 检查字符串是否包含换行符 (防止 HTTP 头注入)
/// 对应 Bun: error.zig/credentials.zig containsNewlineOrCR(value) -> bool
/// 检查字符串是否包含 CR (\r) 或 LF (\n) 字符
public func containsNewlineOrCR(value: String): Bool {
    for (i in 0..value.size) {
        let c = value[Int64(i)]
        if (c == UInt8(13) || c == UInt8(10)) {
            return true
        }
    }
    return false
}
