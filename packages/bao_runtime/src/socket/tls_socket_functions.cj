// 严格翻译自: src/runtime/socket/tls_socket_functions.zig
// TLS Socket 函数 — TLS 连接的各种属性和方法
package bao_runtime.socket

import bao_core.*
import bao_collections.*
import bao_jsc.*

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
    public func getServername(globalObject: JsGlobalObject, callFrame: CallFrame): JsValue {
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
