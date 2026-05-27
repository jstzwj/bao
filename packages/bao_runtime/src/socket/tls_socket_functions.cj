// 严格翻译自: src/runtime/socket/tls_socket_functions.zig
// TLS Socket 函数 — TLS 连接的各种属性和方法
package bao_runtime.socket

import bao_core.*
import bao_collections.*
import bao_jsc.*

// TLS bridge FFI 函数已在 ssl_wrapper.cj 中声明（同包），此处直接使用

// ============================================================================
// TLS Socket 函数
// 对应 Bun: tls_socket_functions.zig
// 提供所有 TLS/TLS Socket 的 JS 可调用方法
// ============================================================================

/// TLS Socket 函数集合
/// 对应 Zig 中的 pub fn getXxx / setXxx 函数集合
/// 所有方法均为 stub 实现 — 等待 BoringSSL FFI 绑定完成后逐步替换
public class TlsSocketFunctions {
    private var socket: TLSSocket

    public init(socket: TLSSocket) {
        this.socket = socket
    }

    /// 获取服务器名称 (SNI)
    /// 对应 Bun: tls_socket_functions.zig getServername
    public func getServername(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        // 需要从 socket 获取 SSL* — TLSSocket 是桩类型，暂时返回 undefined
        // 完整实现需要 TLSSocket 持有 NewSocket 引用并通过 getSslPtr 获取 SSL*
        return JsValue.jsUndefined()
    }

    /// 设置服务器名称 (SNI)
    public func setServername(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 获取对端 X509 证书
    public func getPeerX509Certificate(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 获取本地 X509 证书
    public func getX509Certificate(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 获取 TLS 版本
    public func getTLSVersion(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 设置最大发送分片大小
    public func setMaxSendFragment(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsFalse()
    }

    /// 获取对端证书
    public func getPeerCertificate(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 获取本地证书
    public func getCertificate(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 获取 TLS Finished 消息
    public func getTLSFinishedMessage(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 获取共享的签名算法
    public func getSharedSigalgs(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 获取密码套件信息
    public func getCipher(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 获取 TLS 对端 Finished 消息
    public func getTLSPeerFinishedMessage(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 导出密钥材料
    public func exportKeyingMaterial(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 获取临时密钥信息
    public func getEphemeralKeyInfo(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 获取 ALPN 协议
    public func getALPNProtocol(globalObject: JsGlobalObject): JsValue {
        return JsValue.jsUndefined()
    }

    /// 获取会话
    public func getSession(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 设置会话
    public func setSession(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 获取 TLS 票据
    public func getTLSTicket(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 重协商
    public func renegotiate(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 禁用重协商
    public func disableRenegotiation(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 是否会话重用
    public func isSessionReused(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }

    /// 设置验证模式
    public func setVerifyMode(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
        return JsValue.jsUndefined()
    }
}

/// 获取 SSL 异常
/// 对应 Zig: noinline fn getSSLException
func getSSLException(globalObject: JsGlobalObject, defaultMessage: String): JsValue {
    return JsValue(defaultMessage)
}

// ============================================================================
// 独立 TLS 工具函数 — 直接操作原始 SSL* 指针
// 对应 Bun: tls_socket_functions.zig 中的独立函数
// ============================================================================

/// SSL_is_init_finished — 握手是否已完成
/// 对应 Bun: tls_socket_functions.zig isInitFinished
public func tlsIsInitFinished(sslPtr: CPointer<Unit>): Bool {
    return unsafe { SSL_is_init_finished(sslPtr) } == 1
}

/// SSL_get_servername — 获取 SNI 服务器名称
/// 对应 Bun: tls_socket_functions.zig getServername
/// type_ = 0 for TLSEXT_NAMETYPE_host_name
public func tlsGetServername(sslPtr: CPointer<Unit>): ?String {
    let raw = unsafe { SSL_get_servername(sslPtr, 0) }
    if (raw.isNull()) {
        return None
    }
    return Some(CString(unsafe { CPointer<UInt8>(raw) }).toString())
}

/// SSL_get0_alpn_selected — 获取协商的 ALPN 协议
/// 对应 Bun: tls_socket_functions.zig getALPNProtocol
public func tlsGetAlpnProtocol(sslPtr: CPointer<Unit>): ?Array<Byte> {
    var protoPtr: CPointer<UInt8> = CPointer<UInt8>()
    var protoLen: UInt32 = 0
    unsafe {
        SSL_get0_alpn_selected(
            sslPtr,
            inout protoPtr,
            inout protoLen
        )
    }
    if (protoPtr.isNull() || protoLen == 0) {
        return None
    }
    var result = Array<Byte>(Int64(protoLen), repeat: UInt8(0))
    unsafe {
        for (i in 0..Int64(protoLen)) {
            result[i] = (protoPtr + i).read()
        }
    }
    return Some(result)
}

/// SSL_get_current_cipher / SSL_CIPHER_get_name — 获取当前密码套件名称
/// 对应 Bun: tls_socket_functions.zig getCipher
public func tlsGetCipherName(sslPtr: CPointer<Unit>): ?String {
    let cipher = unsafe { SSL_get_current_cipher(sslPtr) }
    if (cipher.isNull()) {
        return None
    }
    let namePtr = unsafe { SSL_CIPHER_get_name(cipher) }
    if (namePtr.isNull()) {
        return None
    }
    return Some(CString(unsafe { CPointer<UInt8>(namePtr) }).toString())
}

/// SSL_get_version — 获取 TLS 协议版本字符串
/// 对应 Bun: tls_socket_functions.zig getTLSVersion
public func tlsGetVersion(sslPtr: CPointer<Unit>): ?String {
    let raw = unsafe { SSL_get_version(sslPtr) }
    if (raw.isNull()) {
        return None
    }
    return Some(CString(unsafe { CPointer<UInt8>(raw) }).toString())
}
