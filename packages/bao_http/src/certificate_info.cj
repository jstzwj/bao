// bao_http CertificateInfo - SSL 证书信息
// 严格翻译自: src/http/CertificateInfo.zig
package bao_http

import bao_core.*
import bao_collections.*

// ============================================================================
// CertificateInfo - SSL/TLS 证书信息
// 严格翻译自: bun/src/http/CertificateInfo.zig
//
// Bun:
//   pub const CertificateInfo = @This();
//   cert: []const u8,
//   cert_error: HTTPCertError,
//   hostname: []const u8,
//
// 在 SSL 握手完成后，CertificateInfo 保存:
//   - DER 编码的证书数据
//   - 证书验证错误 (如果有)
//   - 主机名
//
// 证书提取流程:
//   1. SSL_get_peer_certificate(ssl) — 获取对端证书
//   2. i2d_X509(cert, &out) — 导出 DER 编码
//   3. SSL_get_verify_result(ssl) — 获取验证结果
//   4. 检查主机名匹配
// ============================================================================

/// 证书信息
/// 严格翻译自: bun/src/http/CertificateInfo.zig CertificateInfo struct
public class CertificateInfo {
    /// DER 编码的证书数据
    /// 严格翻译自: cert: []const u8
    public var cert: Array<UInt8>

    /// 证书验证错误
    /// 严格翻译自: cert_error: HTTPCertError
    public var certError: HTTPCertError

    /// 主机名
    /// 严格翻译自: hostname: []const u8
    public var hostname: String

    /// 证书主题 (CN)
    public var subject: String

    /// 证书颁发者
    public var issuer: String

    /// 有效期开始 (Unix 时间戳)
    public var notBefore: Int64

    /// 有效期结束 (Unix 时间戳)
    public var notAfter: Int64

    /// 是否有效
    public var valid: Bool

    public init() {
        cert = Array<UInt8>()
        certError = HTTPCertError()
        hostname = ""
        subject = ""
        issuer = ""
        notBefore = 0
        notAfter = 0
        valid = false
    }

    public init(cert: Array<UInt8>, hostname: String, certError: HTTPCertError) {
        this.cert = cert
        this.hostname = hostname
        this.certError = certError
        this.subject = ""
        this.issuer = ""
        this.notBefore = 0
        this.notAfter = 0
        this.valid = certError.errorNo == Int32(0)
    }

    // ========================================================================
    // deinit - 清理资源
    // ========================================================================

    /// 清理资源
    public func deinit(): Unit {
        cert = Array<UInt8>()
        hostname = ""
        subject = ""
        issuer = ""
    }

    // ========================================================================
    // isExpired - 是否过期
    // ========================================================================

    /// 是否过期
    public func isExpired(): Bool {
        return !valid
    }

    /// 获取描述
    public func toString(): String {
        if (certError.code.size > 0) {
            return "Certificate error for ${hostname}: ${certError.toString()}"
        }
        return "Certificate for ${hostname}: subject=${subject}, issuer=${issuer}"
    }
}

/// 证书验证常见错误码 (X509_V_ERR_*)
/// 对应 OpenSSL X509_V_ERR_* 常量
public class CertVerifyErrors {
    /// 0 - 验证成功
    public static let OK: UInt32 = UInt32(0)
    /// 2 - 无法获取颁发者证书
    public static let UNABLE_TO_GET_ISSUER_CERT: UInt32 = UInt32(2)
    /// 3 - 无法解密证书签名
    public static let UNABLE_TO_DECRYPT_CERT_SIGNATURE: UInt32 = UInt32(3)
    /// 7 - 证书签名失败
    public static let CERT_SIGNATURE_FAILURE: UInt32 = UInt32(7)
    /// 18 - 自签名证书
    public static let DEPTH_ZERO_SELF_SIGNED_CERT: UInt32 = UInt32(18)
    /// 19 - 自签名证书链中
    public static let SELF_SIGNED_CERT_IN_CHAIN: UInt32 = UInt32(19)
    /// 20 - 无法获取本地颁发者证书
    public static let UNABLE_TO_GET_LOCAL_ISSUER_CERT: UInt32 = UInt32(20)
    /// 21 - 无法验证第一个证书
    public static let UNABLE_TO_VERIFY_LEAF_SIGNATURE: UInt32 = UInt32(21)
    /// 23 - 证书链过长
    public static let CERT_CHAIN_TOO_LONG: UInt32 = UInt32(23)
    /// 24 - 证书撤销
    public static let CERT_REVOKED: UInt32 = UInt32(23)
    /// 26 - 证书未生效
    public static let CERT_NOT_YET_VALID: UInt32 = UInt32(26)
    /// 27 - 证书已过期
    public static let CERT_HAS_EXPIRED: UInt32 = UInt32(27)
    /// 28 - 证书撤销列表未生效
    public static let CRL_NOT_YET_VALID: UInt32 = UInt32(28)
    /// 29 - 证书撤销列表已过期
    public static let CRL_HAS_EXPIRED: UInt32 = UInt32(29)
    /// 62 - 主机名不匹配
    public static let HOSTNAME_MISMATCH: UInt32 = UInt32(62)

    /// 获取错误描述
    public static func message(errorNo: UInt32): String {
        if (errorNo == UInt32(0)) { return "OK" }
        if (errorNo == UInt32(2)) { return "Unable to get issuer certificate" }
        if (errorNo == UInt32(3)) { return "Unable to decrypt certificate signature" }
        if (errorNo == UInt32(7)) { return "Certificate signature failure" }
        if (errorNo == UInt32(18)) { return "Self-signed certificate" }
        if (errorNo == UInt32(19)) { return "Self-signed certificate in chain" }
        if (errorNo == UInt32(20)) { return "Unable to get local issuer certificate" }
        if (errorNo == UInt32(21)) { return "Unable to verify leaf signature" }
        if (errorNo == UInt32(23)) { return "Certificate chain too long" }
        if (errorNo == UInt32(26)) { return "Certificate not yet valid" }
        if (errorNo == UInt32(27)) { return "Certificate has expired" }
        if (errorNo == UInt32(62)) { return "Hostname mismatch" }
        return "Unknown certificate error (${errorNo})"
    }
}
