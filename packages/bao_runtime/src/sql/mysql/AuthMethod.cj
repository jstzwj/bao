// MySQL 认证方法
// 严格翻译自: src/sql/mysql/AuthMethod.zig
package bao_runtime.sql.mysql

import bao_core.*
import bao_boringssl_sys.*

/// MySQL 认证方法枚举
/// 对应 Bun: AuthMethod (enum)
public enum AuthMethod {
    | mysql_native_password
    | caching_sha2_password
    | sha256_password

    /// 认证混淆码长度
    /// 对应 Bun: AuthMethod.scrambleLength
    public func scrambleLength(): Int64 {
        match (this) {
            case mysql_native_password => 20
            case caching_sha2_password => 32
            case sha256_password => 32
        }
    }

    /// 从字符串解析认证方法
    /// 对应 Bun: AuthMethod.fromString
    public static func fromString(name: String): ?AuthMethod {
        if (name == "mysql_native_password") {
            return AuthMethod.mysql_native_password
        } else if (name == "caching_sha2_password") {
            return AuthMethod.caching_sha2_password
        } else if (name == "sha256_password") {
            return AuthMethod.sha256_password
        }
        return None
    }
}

/// MySQL 认证工具类
/// 对应 Bun: Auth.zig
/// 包含 mysql_native_password 和 caching_sha2_password 的 scramble 实现
public class MySQLAuth {

    /// mysql_native_password 混淆码生成
    /// 对应 Bun: Auth.mysql_native_password.scramble
    /// 算法: SHA1(password) XOR SHA1(nonce + SHA1(SHA1(password)))
    public static func scrambleNativePassword(password: Array<UInt8>, nonce: Array<UInt8>): ?Array<UInt8> {
        if (password.size == 0) {
            return Array<UInt8>()
        }
        if (nonce.size < 20) {
            return None  // MissingAuthData
        }

        // Stage 1: SHA1(password)
        let stage1 = CryptoHasher.sha1Hash(password)

        // Stage 2: SHA1(SHA1(password))
        let stage2 = CryptoHasher.sha1Hash(stage1)

        // Stage 3: SHA1(nonce + SHA1(SHA1(password)))
        var combined = Array<UInt8>()
        for (i in 0..8) {
            combined.append(nonce[i])
        }
        for (i in 8..20) {
            combined.append(nonce[i])
        }
        for (b in stage2) {
            combined.append(b)
        }
        let stage3 = CryptoHasher.sha1Hash(combined)

        // Final: stage1 XOR stage3
        let result = Array<UInt8>(20, item: 0)
        for (i in 0..20) {
            result[i] = stage1[i] ^ stage3[i]
        }
        return result
    }

    /// caching_sha2_password 混淆码生成
    /// 对应 Bun: Auth.caching_sha2_password.scramble
    /// 算法: XOR(SHA256(password), SHA256(SHA256(SHA256(password)), nonce))
    public static func scrambleCachingSHA2Password(password: Array<UInt8>, nonce: Array<UInt8>): ?Array<UInt8> {
        // SHA256(password)
        let digest1 = CryptoHasher.sha256Hash(password)

        // SHA256(SHA256(password))
        let digest2 = CryptoHasher.sha256Hash(digest1)

        // SHA256(SHA256(SHA256(password)) + nonce)
        var combined = Array<UInt8>()
        for (b in digest2) {
            combined.append(b)
        }
        for (b in nonce) {
            combined.append(b)
        }
        let digest3 = CryptoHasher.sha256Hash(combined)

        // XOR(SHA256(password), digest3)
        let result = Array<UInt8>(32, item: 0)
        for (i in 0..32) {
            result[i] = digest1[i] ^ digest3[i]
        }
        return result
    }

    /// 根据认证方法生成混淆码
    /// 对应 Bun: AuthMethod.scramble
    public static func scramble(method: AuthMethod, password: Array<UInt8>, authData: Array<UInt8>): ?Array<UInt8> {
        if (password.size == 0) {
            return Array<UInt8>()
        }
        match (method) {
            case mysql_native_password => scrambleNativePassword(password, authData)
            case caching_sha2_password => scrambleCachingSHA2Password(password, authData)
            case sha256_password => scrambleCachingSHA2Password(password, authData)
        }
    }
}

/// 简单的 SHA1/SHA256 哈希封装
/// 使用 BoringSSL FFI 实现
/// 对应 Bun: bun.sha.SHA1.hash / bun.sha.SHA256.hash
public class CryptoHasher {
    /// SHA1 哈希
    /// 对应 Bun: bun.sha.SHA1.hash(data, &out, engine)
    /// BoringSSL: SHA1(data, len, out) -> out
    public static func sha1Hash(data: Array<UInt8>): Array<UInt8> {
        var out = Array<UInt8>(20, item: 0)
        unsafe {
            let dataPtr = arrayToPtr(data)
            let outPtr = CPointer<UInt8>(malloc(UIntNative(20)))
            SHA1(dataPtr, UIntNative(data.size), outPtr)
            for (i in 0..20) {
                out[i] = (outPtr + i).read()
            }
            free(CPointer<Unit>(dataPtr))
            free(CPointer<Unit>(outPtr))
        }
        return out
    }

    /// SHA256 哈希
    /// 对应 Bun: bun.sha.SHA256.hash(data, &out, engine)
    /// BoringSSL: SHA256(data, len, out) -> out
    public static func sha256Hash(data: Array<UInt8>): Array<UInt8> {
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
}

/// caching_sha2_password 快速认证状态
/// 对应 Bun: Auth.caching_sha2_password.FastAuthStatus
public enum FastAuthStatus <: UInt8 {
    | success(0x03)
    | continue_auth(0x04)
}
