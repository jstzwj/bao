// bao_http http_cert_error - SSL 证书错误处理
// 严格翻译自: src/http/HTTPCertError.rs (62 行)
package bao_http

import bao_core.*

// ============================================================================
// HTTPCertError - SSL 证书错误
// 严格翻译自: bun/src/http/HTTPCertError.rs
//
// Rust HTTPCertError:
//   pub struct HTTPCertError {
//       pub error_no: i32,
//       pub code: &'static ZStr,
//       pub reason: &'static ZStr,
//   }
//   impl Default for HTTPCertError {
//       fn default() -> Self { Self { error_no: 0, code: ZStr::EMPTY, reason: ZStr::EMPTY } }
//   }
//   impl HTTPCertError {
//       pub fn from_verify_error(ssl_error: bun_uws::us_bun_verify_error_t) -> Self
//   }
// ============================================================================

/// SSL 证书错误
/// 严格翻译自: HTTPCertError.rs HTTPCertError struct
public class HTTPCertError {
    /// 错误编号 — 对应 OpenSSL X509_V_ERR_* 常量
    /// 严格翻译自: pub error_no: i32
    public var errorNo: Int32

    /// 错误代码 (静态字符串, 如 "CERT_SIGNATURE_FAILURE")
    /// 严格翻译自: pub code: &'static ZStr
    public var code: String

    /// 错误原因 (静态字符串, 人类可读描述)
    /// 严格翻译自: pub reason: &'static ZStr
    public var reason: String

    public init() {
        errorNo = Int32(0)
        code = ""
        reason = ""
    }

    public init(errorNo: Int32, code: String, reason: String) {
        this.errorNo = errorNo
        this.code = code
        this.reason = reason
    }

    // ========================================================================
    // fromVerifyError - 从 uSockets 验证错误构造
    // 严格翻译自:
    //   pub fn from_verify_error(ssl_error: bun_uws::us_bun_verify_error_t) -> Self {
    //       Self {
    //           error_no: ssl_error.error_no,
    //           code: zstr(ssl_error.code),
    //           reason: if ssl_error.code.is_null() {
    //               ZStr::EMPTY
    //           } else {
    //               zstr(ssl_error.reason)
    //           },
    //       }
    //   }
    // ========================================================================

    /// 从验证错误构造
    /// 严格翻译自: HTTPCertError.from_verify_error
    public static func fromVerifyError(errorNo: Int32, code: String, reason: String): HTTPCertError {
        if (code.size == 0) {
            return HTTPCertError(errorNo, code, "")
        }
        return HTTPCertError(errorNo, code, reason)
    }

    /// 是否为空 (无错误)
    public func isEmpty(): Bool {
        return errorNo == Int32(0) && code.size == 0
    }

    /// 转为字符串描述
    public func toString(): String {
        if (reason.size > 0) {
            return "${code}: ${reason} (code=${errorNo})"
        }
        if (code.size > 0) {
            return "${code} (code=${errorNo})"
        }
        return "no certificate error"
    }
}
