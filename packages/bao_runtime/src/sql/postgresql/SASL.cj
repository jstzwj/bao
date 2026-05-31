// PostgreSQL SASL/SCRAM-SHA-256 认证 JSC 绑定
// 严格翻译自: bun/src/sql_jsc/postgres/SASL.zig
//   const SASL = @This();
//   nonce_base64_bytes: [nonce_base64_len]u8, ...
package bao_runtime.sql.postgresql

import bao_core.*
import bao_boringssl_sys.*


/// SASL SCRAM-SHA-256 认证状态
/// 对应 Bun SASL (struct)
/// 管理 SCRAM-SHA-256 认证流程的中间状态
public class SASLAuth {
    /// 随机 nonce 长度
    public static let NONCE_BYTE_LEN: Int64 = 18
    /// nonce Base64 编码后的长度
    public static let NONCE_BASE64_LEN: Int64 = 24
    /// 服务器签名字节长度
    public static let SERVER_SIGNATURE_BYTE_LEN: Int64 = 32
    /// 服务器签名 Base64 编码后长度
    public static let SERVER_SIGNATURE_BASE64_LEN: Int64 = 44
    /// 盐值密码字节长度
    public static let SALTED_PASSWORD_BYTE_LEN: Int64 = 32

    /// SASL 认证阶段
    public enum SASLStatus {
        | Init       // 初始阶段
        | Continue   // 继续阶段（已发送客户端响应）
    }

    /// 客户端 nonce (Base64 编码)
    public var nonceBase64: Array<UInt8>
    /// nonce 长度
    public var nonceLen: Int64

    /// 服务器签名 (Base64 编码)
    public var serverSignatureBase64: Array<UInt8>
    /// 服务器签名长度
    public var serverSignatureLen: Int64

    /// 盐值密码
    public var saltedPassword: Array<UInt8>
    /// 是否已生成盐值密码
    public var saltedPasswordCreated: Bool

    /// SASL 状态
    public var status: SASLStatus

    public init() {
        nonceBase64 = Array<UInt8>(SASLAuth.NONCE_BASE64_LEN, item: 0)
        nonceLen = 0
        serverSignatureBase64 = Array<UInt8>(SASLAuth.SERVER_SIGNATURE_BASE64_LEN, item: 0)
        serverSignatureLen = 0
        saltedPassword = Array<UInt8>(SASLAuth.SALTED_PASSWORD_BYTE_LEN, item: 0)
        saltedPasswordCreated = false
        status = SASLStatus.Init
    }

    /// 获取客户端 nonce
    /// 对应 Bun SASL.nonce()
    /// 如果 nonce 尚未生成，则生成一个随机 nonce
    public func nonce(): Array<UInt8> {
        if (nonceLen == 0) {
            // 生成随机字节
            let rawBytes = Array<UInt8>(SASLAuth.NONCE_BYTE_LEN, item: 0)
            for (i in 0..SASLAuth.NONCE_BYTE_LEN) {
                rawBytes[i] = UInt8.random()
            }
            // Base64 编码
            nonceBase64 = base64Encode(rawBytes)
            nonceLen = nonceBase64.size
        }
        return nonceBase64.slice(0, nonceLen)
    }

    /// 获取 nonce 的字符串形式
    public func nonceString(): String {
        let bytes = nonce()
        bytes.toArray().map({ b => Char.fromUInt8(b) }).toString()
    }

    /// 计算盐值密码
    /// 对应 Bun SASL.computeSaltedPassword()
    ///
    /// 参数:
    ///   saltBytes - 服务器发送的盐值 (Base64 解码后)
    ///   iterationCount - 迭代次数
    ///   password - 用户密码
    public func computeSaltedPassword(saltBytes: Array<UInt8>, iterationCount: UInt32, password: Array<UInt8>): Bool {
        saltedPasswordCreated = true
        // PBKDF2-HMAC-SHA256(password, salt, iterations)
        // 通过 BoringSSL PKCS5_PBKDF2_HMAC 实现
        saltedPassword = pbkdf2HmacSHA256(password, saltBytes, iterationCount, SALTED_PASSWORD_BYTE_LEN)
        return true
    }

    /// 计算服务器签名
    /// 对应 Bun SASL.computeServerSignature()
    ///
    /// 参数:
    ///   authString - 认证字符串
    public func computeServerSignature(authString: Array<UInt8>): Bool {
        if (serverSignatureLen != 0) {
            return false
        }

        // ServerKey = HMAC-SHA256(saltedPassword, "Server Key")
        let serverKey = hmacSHA256(saltedPassword, Array<UInt8>("Server Key".toArray().map({ c => UInt8(c) })))

        // ServerSignature = HMAC-SHA256(ServerKey, authString)
        let serverSignatureBytes = hmacSHA256(serverKey, authString)

        // Base64 编码
        serverSignatureBase64 = base64Encode(serverSignatureBytes)
        serverSignatureLen = serverSignatureBase64.size
        return true
    }

    /// 获取服务器签名
    /// 对应 Bun SASL.serverSignature()
    public func serverSignature(): Array<UInt8> {
        serverSignatureBase64.slice(0, serverSignatureLen)
    }

    /// 获取客户端 Key
    /// 对应 Bun SASL.clientKey()
    public func clientKey(): Array<UInt8> {
        // ClientKey = HMAC-SHA256(saltedPassword, "Client Key")
        hmacSHA256(saltedPassword, Array<UInt8>("Client Key".toArray().map({ c => UInt8(c) })))
    }

    /// 计算客户端 Key 签名
    /// 对应 Bun SASL.clientKeySignature()
    ///
    /// 参数:
    ///   clientKey - 客户端 Key
    ///   authString - 认证字符串
    public func clientKeySignature(clientKey: Array<UInt8>, authString: Array<UInt8>): Array<UInt8> {
        // ClientKeySignature = HMAC-SHA256(SHA256(clientKey), authString)
        let shaDigest = sha256(clientKey)
        hmacSHA256(shaDigest, authString)
    }

    /// 计算 XOR 客户端证明
    /// 对应 Bun SASLContinue 处理中的 XOR 操作
    ///
    /// 参数:
    ///   clientKey - 客户端 Key
    ///   clientKeySignature - 客户端 Key 的签名
    public static func xorClientProof(clientKey: Array<UInt8>, clientKeySignature: Array<UInt8>): Array<UInt8> {
        let result = Array<UInt8>(32, item: 0)
        for (i in 0..32) {
            if (i < clientKey.size && i < clientKeySignature.size) {
                result[i] = clientKey[i] ^ clientKeySignature[i]
            }
        }
        return result
    }

    /// 重置状态
    /// 对应 Bun SASL.deinit()
    public func deinit() {
        nonceLen = 0
        saltedPasswordCreated = false
        serverSignatureLen = 0
        status = SASLStatus.Init
        // 清零敏感数据
        for (i in 0..saltedPassword.size) {
            saltedPassword[i] = 0
        }
        for (i in 0..serverSignatureBase64.size) {
            serverSignatureBase64[i] = 0
        }
        for (i in 0..nonceBase64.size) {
            nonceBase64[i] = 0
        }
    }

    // ========================================================================
    // 密码学原语 (BoringSSL FFI 调用)
    // ========================================================================

    /// HMAC-SHA256
    /// 对应 Bun SASL.hmac(): bun.hmac.generate(password, data, .sha256, &buf)
    /// BoringSSL: HMAC(EVP_sha256(), key, key_len, data, data_len, out, &out_len)
    private static func hmacSHA256(key: Array<UInt8>, data: Array<UInt8>): Array<UInt8> {
        var out = Array<UInt8>(32, item: 0)
        unsafe {
            let md = EVP_sha256()
            let keyPtr = arrayToPtr(key)
            let dataPtr = arrayToPtr(data)
            let outPtr = CPointer<UInt8>(malloc(UIntNative(64)))  // EVP_MAX_MD_SIZE
            var outLen = Array<UIntNative>(1, repeat: UIntNative(0))
            let outLenPtr = CPointer<UIntNative>(malloc(UIntNative(8)))
            // HMAC() 返回非空指针表示成功，返回空指针表示失败
            let hmacResult = HMAC(md, CPointer<Unit>(keyPtr), UIntNative(key.size),
                CPointer<Unit>(dataPtr), UIntNative(data.size),
                outPtr, outLenPtr)
            // 复制结果到数组
            let len = (outLenPtr).read()
            for (i in 0..32) {
                if (i < Int64(len)) {
                    out[i] = (outPtr + i).read()
                }
            }
            free(CPointer<Unit>(keyPtr))
            free(CPointer<Unit>(dataPtr))
            free(CPointer<Unit>(outPtr))
            free(CPointer<Unit>(outLenPtr))
        }
        return out
    }

    /// SHA-256
    /// 对应 Bun SASL.clientKeySignature(): bun.sha.SHA256.hash(client_key, &sha_digest, engine)
    /// BoringSSL: SHA256(data, len, out) -> out
    private static func sha256(data: Array<UInt8>): Array<UInt8> {
        var out = Array<UInt8>(32, item: 0)
        unsafe {
            let dataPtr = arrayToPtr(data)
            let outPtr = CPointer<UInt8>(malloc(UIntNative(32)))
            SHA256(dataPtr, UIntNative(data.size), outPtr)
            for (i in 0..32) {
                out[i] = (outPtr + i).read()
            }
            free(CPointer<Unit>(dataPtr))
            free(CPointer<Unit>(outPtr))
        }
        return out
    }

    /// PBKDF2-HMAC-SHA256
    /// 对应 Bun SASL.computeSaltedPassword(): Crypto.EVP.pbkdf2(&out, password, salt, iterations, .sha256)
    /// BoringSSL: PKCS5_PBKDF2_HMAC(password, password_len, salt, salt_len, iterations, EVP_sha256(), key_len, out)
    private static func pbkdf2HmacSHA256(password: Array<UInt8>, salt: Array<UInt8>, iterations: UInt32, dkLen: Int64): Array<UInt8> {
        var out = Array<UInt8>(dkLen, item: 0)
        unsafe {
            let md = EVP_sha256()
            // PKCS5_PBKDF2_HMAC 的 password 参数类型是 CString (以 null 结尾)
            // 需要构造 null-terminated 的密码字节
            var passwordWithNull = Array<UInt8>(password.size + 1, item: 0)
            for (i in 0..password.size) {
                passwordWithNull[i] = password[i]
            }
            passwordWithNull[password.size] = UInt8(0)
            let passwordPtr = arrayToPtr(passwordWithNull)
            let saltPtr = arrayToPtr(salt)
            let outPtr = CPointer<UInt8>(malloc(UIntNative(dkLen)))
            let rc = PKCS5_PBKDF2_HMAC(
                CString(passwordPtr),
                UIntNative(password.size),
                saltPtr,
                UIntNative(salt.size),
                iterations,
                md,
                UIntNative(dkLen),
                outPtr
            )
            if (rc == 1) {
                for (i in 0..dkLen) {
                    out[i] = (outPtr + i).read()
                }
            }
            free(CPointer<Unit>(passwordPtr))
            free(CPointer<Unit>(saltPtr))
            free(CPointer<Unit>(outPtr))
        }
        return out
    }

    /// 将 Array<UInt8> 转换为 CPointer<UInt8>
    private static func arrayToPtr(bytes: Array<UInt8>): CPointer<UInt8> {
        unsafe {
            let ptr = malloc(UIntNative(bytes.size))
            let out = CPointer<UInt8>(ptr)
            for (i in 0..bytes.size) {
                (out + i).write(bytes[i])
            }
            return out
        }
    }

    /// Base64 编码
    private static func base64Encode(data: Array<UInt8>): Array<UInt8> {
        // 简化 Base64 编码实现
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        let result = Array<UInt8>()
        var i = 0
        while (i < data.size) {
            let b0 = data[i]
            let b1 = if (i + 1 < data.size) data[i + 1] else UInt8(0)
            let b2 = if (i + 2 < data.size) data[i + 2] else UInt8(0)

            let c0 = UInt8(b0 >> 2)
            let c1 = UInt8(((b0 & 0x03) << 4) | (b1 >> 4))
            let c2 = UInt8(((b1 & 0x0F) << 2) | (b2 >> 6))
            let c3 = UInt8(b2 & 0x3F)

            result.append(UInt8(chars[c0]))
            result.append(UInt8(chars[c1]))
            if (i + 1 < data.size) {
                result.append(UInt8(chars[c2]))
            } else {
                result.append(UInt8('='))
            }
            if (i + 2 < data.size) {
                result.append(UInt8(chars[c3]))
            } else {
                result.append(UInt8('='))
            }
            i += 3
        }
        return result
    }
}
