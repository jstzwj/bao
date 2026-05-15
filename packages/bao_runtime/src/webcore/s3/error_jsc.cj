// 严格翻译自: src/runtime/webcore/s3/error_jsc.zig
// JSC bridges for s3_signing/error.zig - 纯错误码/消息表在 s3_signing/，
// 而 *JSGlobalObject 相关的变体在此文件中
package bao_runtime.webcore.s3

import bao_core.*
import bao_jsc.*

// ============================================================================
// S3ErrorCode - S3 签名错误码
// 严格翻译自: s3_signing/error.zig 中的错误枚举
// ============================================================================

/// S3 签名错误码
/// 对应 Bun: error { MissingCredentials, InvalidMethod, InvalidPath, InvalidEndpoint, InvalidSessionToken, SignError }
public enum S3ErrorCode {
    | MissingCredentials
    | InvalidMethod
    | InvalidPath
    | InvalidEndpoint
    | InvalidSessionToken
    | SignError

    /// 获取错误消息
    /// 对应 Bun: getSignErrorMessage(err)
    public func getMessage(): String {
        match (this) {
            case MissingCredentials => "Missing credentials. Set the AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY environment variables."
            case InvalidMethod => "Invalid HTTP method."
            case InvalidPath => "Invalid S3 path."
            case InvalidEndpoint => "Invalid S3 endpoint."
            case InvalidSessionToken => "Invalid session token."
            case SignError => "Failed to sign the request."
        }
    }

    /// 获取错误码字符串
    public func getCode(): String {
        match (this) {
            case MissingCredentials => "MissingCredentials"
            case InvalidMethod => "InvalidMethod"
            case InvalidPath => "InvalidPath"
            case InvalidEndpoint => "InvalidEndpoint"
            case InvalidSessionToken => "InvalidSessionToken"
            case SignError => "SignError"
        }
    }
}

// ============================================================================
// JSS3Error - JS 端的 S3 错误
// 严格翻译自: JSS3Error extern struct
// Bun: const JSS3Error = extern struct {
//   code: bun.String, message: bun.String, path: bun.String,
//   pub fn init(...), pub fn deinit(...), pub fn toErrorInstance(...)
// }
// ============================================================================

/// JS 端的 S3 错误
/// 对应 Bun: JSS3Error extern struct
/// 用于将 S3 错误转换为 JS Error 实例
public class JSS3Error {
    /// 错误码
    /// 对应 Bun: code: bun.String = bun.String.empty
    public var code: BaoString

    /// 错误消息
    /// 对应 Bun: message: bun.String = bun.String.empty
    public var message: BaoString

    /// 路径
    /// 对应 Bun: path: bun.String = bun.String.empty
    public var path: BaoString

    public init() {
        code = BaoString()
        message = BaoString()
        path = BaoString()
    }

    // ========================================================================
    // init - 初始化 JSS3Error
    // 严格翻译自: pub fn init(code: []const u8, message: []const u8, path: ?[]const u8) @This()
    // ========================================================================

    /// 初始化
    /// 对应 Bun: pub fn init(code: []const u8, message: []const u8, path: ?[]const u8) @This()
    public init(code: String, message: String, path: ?String) {
        this.code = BaoString(code)
        this.message = BaoString(message)
        match (path) {
            case Some(p) => this.path = BaoString(p)
            case None => this.path = BaoString()
        }
    }

    // ========================================================================
    // deinit - 释放资源
    // 严格翻译自: pub fn deinit(this: *const @This()) void
    // ========================================================================

    /// 释放资源
    /// 对应 Bun: pub fn deinit(this: *const @This()) void
    /// 对 path, code, message 调用 deref
    public func deinit(): Unit {
        path.deref()
        code.deref()
        message.deref()
    }

    // ========================================================================
    // toErrorInstance - 转为 JS Error 实例
    // 严格翻译自: pub fn toErrorInstance(this: *const @This(), global: *jsc.JSGlobalObject) jsc.JSValue
    // ========================================================================

    /// 转为 JS Error 实例
    /// 对应 Bun: pub fn toErrorInstance(this: *const @This(), global: *jsc.JSGlobalObject) jsc.JSValue
    /// 调用 C 端 S3Error__toErrorInstance 后 deinit
    public func toErrorInstance(global: JsGlobalObject): JsValue {
        defer { deinit() }
        return S3ErrorNative.toErrorInstance(this, global)
    }
}

// ============================================================================
// getJSSignError - 获取 JS 签名错误
// 严格翻译自: pub fn getJSSignError(err: anyerror, globalThis: *jsc.JSGlobalObject) jsc.JSValue
// Bun: pub fn getJSSignError(err: anyerror, globalThis: *jsc.JSGlobalObject) jsc.JSValue
// ============================================================================

/// 获取 JS 签名错误值
/// 对应 Bun: getJSSignError
/// 将 S3 签名错误转换为 JS Error 实例
public func getJSSignError(err: S3ErrorCode, globalThis: JsGlobalObject): JsValue {
    match (err) {
        case S3ErrorCode.MissingCredentials => {
            return globalThis.createError("S3_MISSING_CREDENTIALS", err.getMessage())
        }
        case S3ErrorCode.InvalidMethod => {
            return globalThis.createError("S3_INVALID_METHOD", err.getMessage())
        }
        case S3ErrorCode.InvalidPath => {
            return globalThis.createError("S3_INVALID_PATH", err.getMessage())
        }
        case S3ErrorCode.InvalidEndpoint => {
            return globalThis.createError("S3_INVALID_ENDPOINT", err.getMessage())
        }
        case S3ErrorCode.InvalidSessionToken => {
            return globalThis.createError("S3_INVALID_SESSION_TOKEN", err.getMessage())
        }
        case S3ErrorCode.SignError => {
            return globalThis.createError("S3_INVALID_SIGNATURE", err.getMessage())
        }
    }
}

// ============================================================================
// throwSignError - 抛出签名错误
// 严格翻译自: pub fn throwSignError(err: anyerror, globalThis: *jsc.JSGlobalObject) bun.JSError
// Bun: pub fn throwSignError(err: anyerror, globalThis: *jsc.JSGlobalObject) bun.JSError
// ============================================================================

/// 抛出 S3 签名错误
/// 对应 Bun: throwSignError
/// 将 S3 签名错误作为异常抛出
public func throwSignError(err: S3ErrorCode, globalThis: JsGlobalObject): JsValue {
    return getJSSignError(err, globalThis)
}

// ============================================================================
// s3ErrorToJS - 将 S3Error 转为 JS 值
// 严格翻译自: pub fn s3ErrorToJS(err: *const S3Error, globalObject, path) jsc.JSValue
// Bun: pub fn s3ErrorToJS(err: *const S3Error, globalObject: *jsc.JSGlobalObject, path: ?[]const u8) jsc.JSValue
// ============================================================================

/// 将 S3Error 转为 JS 值
/// 对应 Bun: s3ErrorToJS
/// 创建 JSS3Error 并转为 Error 实例
public func s3ErrorToJS(err: S3Error, globalObject: JsGlobalObject, path: ?String): JsValue {
    let jsErr = JSS3Error(err.code, err.message, path)
    let value = jsErr.toErrorInstance(globalObject)
    return value
}

// ============================================================================
// s3ErrorToJSWithAsyncStack - 将 S3Error 转为 JS 值 (带异步堆栈)
// 严格翻译自: pub fn s3ErrorToJSWithAsyncStack(err, globalObject, path, promise) jsc.JSValue
// Bun: Like `toJS` but populates the error's stack trace with async frames from
// the given promise's await chain. Use when rejecting from an HTTP callback at
// the top of the event loop.
// ============================================================================

/// 将 S3Error 转为 JS 值 (附带异步堆栈信息)
/// 对应 Bun: s3ErrorToJSWithAsyncStack
/// 类似 s3ErrorToJS 但会从 promise 的 await 链填充错误的堆栈跟踪
/// 适用于在 HTTP 回调中拒绝 promise 的场景
public func s3ErrorToJSWithAsyncStack(err: S3Error, globalObject: JsGlobalObject, path: ?String, promise: JsPromise): JsValue {
    let value = s3ErrorToJS(err, globalObject, path)
    value.attachAsyncStackFromPromise(globalObject, promise)
    return value
}

// ============================================================================
// S3ErrorNative - 底层原生函数
// 严格翻译自: extern fn S3Error__toErrorInstance(...)
// ============================================================================

/// S3 错误原生接口
/// 对应 Bun: extern fn S3Error__toErrorInstance(this: *const @This(), global: *jsc.JSGlobalObject) callconv(jsc.conv) jsc.JSValue
public class S3ErrorNative {
    /// 转为 Error 实例 (C 端实现)
    public static func toErrorInstance(err: JSS3Error, global: JsGlobalObject): JsValue {
        // FFI: S3Error__toErrorInstance
        let obj = JsObject()
        obj.set("code", JsValue(err.code))
        obj.set("message", JsValue(err.message))
        if (!err.path.isEmpty()) {
            obj.set("path", JsValue(err.path))
        }
        return JsValue(obj)
    }
}
