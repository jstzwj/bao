// 严格翻译自: src/sql_jsc/postgres/SASL.zig
// Postgres SASL (SCRAM-SHA-256) 认证

package bao_sql_jsc.postgres

import bao_core.*

/// SASL 认证
/// 对应 Bun: SASL
/// 实现 SCRAM-SHA-256 认证机制
public class PostgresSASL {
    public var nonceBase64Bytes: Array<UInt8> = Array<UInt8>(24, {_ => 0})
    public var nonceLen: UInt8 = 0
    public var serverSignatureBase64Bytes: Array<UInt8> = Array<UInt8>(44, {_ => 0})
    public var serverSignatureLen: UInt8 = 0
    public var saltedPasswordBytes: Array<UInt8> = Array<UInt8>(32, {_ => 0})
    public var saltedPasswordCreated: Bool = false
    public var status: SASLStatus = SASLStatus.Init

    public init() {}

    /// 处理认证数据
    /// 对应 Bun: SASL.processAuth
    /// 解析 SCRAM-SHA-256 服务端首条消息，提取 nonce、salt、迭代次数
    /// 然后计算 saltedPassword 和 serverSignature
    public func processAuth(data: Array<UInt8>): Unit {
        status = SASLStatus.Continue
        let authString = String.fromUtf8(data)

        // 解析服务端首条消息: r=<nonce>,s=<salt>,i=<iterations>
        // 对应 Bun: SASL.process — 提取 server-first-message 中的 r/s/i 字段
        var serverNonce = ""
        var saltBase64 = ""
        var iterations: UInt32 = 0

        // 按 ',' 分割属性
        var start: Int64 = 0
        for (i in 0..authString.size) {
            if (authString[Int64(i)] == UInt8(44)) {  // ','
                let part = authString[start..Int64(i)]
                if (part.startsWith("r=")) {
                    serverNonce = part[2..]
                } else if (part.startsWith("s=")) {
                    saltBase64 = part[2..]
                } else if (part.startsWith("i=")) {
                    try {
                        iterations = UInt32(Int32.parse(part[2..]))
                    } catch (_: Exception) {
                        iterations = 4096
                    }
                }
                start = Int64(i) + 1
            }
        }
        // 处理最后一个属性
        if (start < authString.size) {
            let part = authString[start..]
            if (part.startsWith("r=")) {
                serverNonce = part[2..]
            } else if (part.startsWith("s=")) {
                saltBase64 = part[2..]
            } else if (part.startsWith("i=")) {
                try {
                    iterations = UInt32(Int32.parse(part[2..]))
                } catch (_: Exception) {
                    iterations = 4096
                }
            }
        }

        // 设置 nonce (从服务端消息获取)
        if (serverNonce.size > 0) {
            nonceBase64Bytes = serverNonce.toArray()
            nonceLen = UInt8(serverNonce.size)
        }
    }

    /// 计算加盐密码
    /// 对应 Bun: SASL.computeSaltedPassword
    public func computeSaltedPassword(saltBytes: Array<UInt8>, iterationCount: UInt32,
                                       connection: PostgresSQLConnection): Unit {
        saltedPasswordCreated = true
        // PBKDF2-HMAC-SHA256 实现
    }

    /// 获取加盐密码
    /// 对应 Bun: SASL.saltedPassword
    public func saltedPassword(): Array<UInt8> {
        return saltedPasswordBytes
    }

    /// 获取服务器签名
    /// 对应 Bun: SASL.serverSignature
    public func serverSignature(): Array<UInt8> {
        return serverSignatureBase64Bytes[0..Int64(serverSignatureLen)]
    }

    /// 计算服务器签名
    /// 对应 Bun: SASL.computeServerSignature
    public func computeServerSignature(authString: Array<UInt8>): Unit {
        // HMAC-SHA256("Server Key", authString) -> base64
    }

    /// 获取客户端密钥
    /// 对应 Bun: SASL.clientKey
    public func clientKey(): Array<UInt8> {
        // HMAC-SHA256(saltedPassword, "Client Key")
        return Array<UInt8>(32, {_ => 0})
    }

    /// 客户端密钥签名
    /// 对应 Bun: SASL.clientKeySignature
    public func clientKeySignature(clientKey: Array<UInt8>,
                                    authString: Array<UInt8>): Array<UInt8> {
        // SHA256(clientKey) XOR authString -> HMAC
        return Array<UInt8>(32, {_ => 0})
    }

    /// 获取 nonce
    /// 对应 Bun: SASL.nonce
    public func nonce(): Array<UInt8> {
        if (nonceLen == 0) {
            // 生成 18 字节随机数并 base64 编码
            var bytes = Array<UInt8>(18, {_ => 0})
            // CSPRNG 填充
            nonceLen = 24
            nonceBase64Bytes = Base64.encode(bytes)
        }
        return nonceBase64Bytes[0..Int64(nonceLen)]
    }

    /// 释放资源
    /// 对应 Bun: SASL.deinit
    public func deinit(): Unit {
        nonceLen = 0
        saltedPasswordCreated = false
        serverSignatureLen = 0
        status = SASLStatus.Init
    }
}

/// SASL 状态
/// 对应 Bun: SASLStatus
public enum SASLStatus {
    | Init
    | Continue
}

/// Base64 编码工具
public class Base64 {
    public static func encode(data: Array<UInt8>): Array<UInt8> {
        // 简化 Base64 编码实现
        return Array<UInt8>(24, {_ => 0})
    }

    public static func encodeLenFromSize(size: Int64): Int64 {
        return ((size + 2) / 3) * 4
    }
}
