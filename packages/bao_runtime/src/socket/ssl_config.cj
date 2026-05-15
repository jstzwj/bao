// SSL/TLS 配置
// 对应 Bun: src/runtime/socket/SSLConfig.zig
// 管理 TLS 证书、密钥、密码套件等配置
package bao_runtime.socket

import bao_core.*
import bao_collections.*

// ============================================================================
// SSL 配置
// 对应 Bun: SSLConfig struct
// ============================================================================

/// SSL/TLS 配置选项
/// 对应 Zig: const SSLConfig = @This()
public class SSLConfig {
    /// 服务器名称 (SNI)
    public var serverName: ?String
    /// 密钥文件路径
    public var keyFileName: ?String
    /// 证书文件路径
    public var certFileName: ?String
    /// CA 证书文件路径
    public var caFileName: ?String
    /// DH 参数文件路径
    public var dhParamsFileName: ?String
    /// 密码
    public var passphrase: ?String
    /// 密钥 (PEM 内容)
    public var key: ?ArrayList<String>
    /// 证书 (PEM 内容)
    public var cert: ?ArrayList<String>
    /// CA 证书 (PEM 内容)
    public var ca: ?ArrayList<String>
    /// 安全选项位掩码
    public var secureOptions: UInt32
    /// 是否请求客户端证书
    public var requestCert: Int32
    /// 是否拒绝未授权连接
    public var rejectUnauthorized: Int32
    /// SSL 密码套件列表
    public var sslCiphers: ?String
    /// ALPN 协议列表
    public var protos: ?String
    /// 客户端重协商限制
    public var clientRenegotiationLimit: UInt32
    /// 客户端重协商窗口
    public var clientRenegotiationWindow: UInt32
    /// 是否需要自定义请求上下文
    public var requiresCustomRequestCtx: Bool
    /// 是否使用默认密码套件
    public var isUsingDefaultCiphers: Bool
    /// 低内存模式
    public var lowMemoryMode: Bool
    /// 缓存的哈希值
    public var cachedHash: UInt64

    /// 零值 (tls:true 的默认配置)
    public static let ZERO = SSLConfig()

    public init() {
        serverName = None
        keyFileName = None
        certFileName = None
        caFileName = None
        dhParamsFileName = None
        passphrase = None
        key = None
        cert = None
        ca = None
        secureOptions = 0
        requestCert = 0
        rejectUnauthorized = 0
        sslCiphers = None
        protos = None
        clientRenegotiationLimit = 0
        clientRenegotiationWindow = 0
        requiresCustomRequestCtx = false
        isUsingDefaultCiphers = true
        lowMemoryMode = false
        cachedHash = 0
    }

    /// 从 JS 值构造 SSL 配置
    /// 对应 Zig: fromJS
    public static func fromJS(value: JsValue): ?SSLConfig {
        // tls: true → 默认配置
        if (value.valueType == JsValueType.Boolean) {
            if (value.toBoolean()) {
                return SSLConfig.ZERO
            }
            return None
        }

        if (value.valueType != JsValueType.Object) {
            return None
        }

        let config = SSLConfig()

        match (value.objectData) {
            case Some(obj) => {
                // 读取服务器名称
                let sni = obj.get("serverName")
                if (sni.valueType == JsValueType.String) {
                    config.serverName = Some(sni.toString())
                }

                // 读取密钥文件
                let keyFile = obj.get("keyFile")
                if (keyFile.valueType == JsValueType.String) {
                    config.keyFileName = Some(keyFile.toString())
                }

                // 读取证书文件
                let certFile = obj.get("certFile")
                if (certFile.valueType == JsValueType.String) {
                    config.certFileName = Some(certFile.toString())
                }

                // 读取 CA 文件
                let caFile = obj.get("caFile")
                if (caFile.valueType == JsValueType.String) {
                    config.caFileName = Some(caFile.toString())
                }

                // 读取密码
                let pass = obj.get("passphrase")
                if (pass.valueType == JsValueType.String) {
                    config.passphrase = Some(pass.toString())
                }

                // 读取密码套件
                let ciphers = obj.get("ciphers")
                if (ciphers.valueType == JsValueType.String) {
                    config.sslCiphers = Some(ciphers.toString())
                    config.isUsingDefaultCiphers = false
                }

                // 读取 ALPN 协议
                let protos = obj.get("ALPNProtocols")
                if (protos.valueType == JsValueType.String) {
                    config.protos = Some(protos.toString())
                }

                // 读取请求证书
                let reqCert = obj.get("requestCert")
                if (reqCert.valueType == JsValueType.Boolean) {
                    config.requestCert = if (reqCert.toBoolean()) { 1 } else { 0 }
                }

                // 读取拒绝未授权
                let rejUnauth = obj.get("rejectUnauthorized")
                if (rejUnauth.valueType == JsValueType.Boolean) {
                    config.rejectUnauthorized = if (rejUnauth.toBoolean()) { 1 } else { 0 }
                }

                // 读取低内存模式
                let lowMem = obj.get("lowMemoryMode")
                if (lowMem.valueType == JsValueType.Boolean) {
                    config.lowMemoryMode = lowMem.toBoolean()
                }
            }
            case None => ()
        }

        return config
    }

    /// 提取 ALPN 协议 (转移所有权)
    /// 对应 Zig: takeProtos
    public func takeProtos(): ?String {
        let result = protos
        protos = None
        return result
    }

    /// 提取服务器名称 (转移所有权)
    /// 对应 Zig: takeServerName
    public func takeServerName(): ?String {
        let result = serverName
        serverName = None
        return result
    }

    /// 转为 uWS Socket 上下文选项
    /// 对应 Zig: asUSockets
    public func asUSockets(): BunSocketContextOptions {
        let opts = BunSocketContextOptions()

        match (keyFileName) {
            case Some(f) => opts.keyFileName = f
            case None => ()
        }
        match (certFileName) {
            case Some(f) => opts.certFileName = f
            case None => ()
        }
        match (caFileName) {
            case Some(f) => opts.caFileName = f
            case None => ()
        }
        match (dhParamsFileName) {
            case Some(f) => opts.dhParamsFileName = f
            case None => ()
        }
        match (passphrase) {
            case Some(p) => opts.passphrase = p
            case None => ()
        }

        opts.lowMemory = lowMemoryMode

        return opts
    }

    /// 释放资源
    /// 对应 Zig: deinit
    public func deinit(): Unit {
        serverName = None
        keyFileName = None
        certFileName = None
        caFileName = None
        dhParamsFileName = None
        passphrase = None
        key = None
        cert = None
        ca = None
        sslCiphers = None
        protos = None
    }
}

// ============================================================================
// uWS Socket 上下文选项
// 对应 Bun: uws.SocketContext.BunSocketContextOptions
// ============================================================================

/// uWS Socket 上下文选项
public class BunSocketContextOptions {
    public var keyFileName: String
    public var certFileName: String
    public var caFileName: String
    public var dhParamsFileName: String
    public var passphrase: String
    public var lowMemory: Bool

    public init() {
        keyFileName = ""
        certFileName = ""
        caFileName = ""
        dhParamsFileName = ""
        passphrase = ""
        lowMemory = false
    }

    /// 创建 SSL 上下文
    /// 对应 Zig: createSSLContext
    public func createSSLContext(): ?SslContext {
        // 通过 bao_sys 创建 SSL_CTX
        return SslContext()
    }
}
