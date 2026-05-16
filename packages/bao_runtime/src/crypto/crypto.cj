// crypto.cj - 加密模块入口
// 对应 Bun: src/runtime/crypto/crypto.zig + mod.rs
// 严格1:1翻译自 Bun crypto.zig / mod.rs

package bao_runtime.crypto

import bao_core.*

// ============================================================================
// 加密错误创建
// 对应 Bun: crypto.zig - createCryptoError / mod.rs - create_crypto_error
// ============================================================================

/// 创建加密错误
public func createCryptoError(globalThis: JsObject, errCode: UInt32): JsValue {
    return BoringSSLJsc.errToJs(globalThis, errCode)
}

// ============================================================================
// PBKDF2 顶层函数
// ============================================================================

/// PBKDF2 密码派生函数
public func pbkdf2(output: Array<Byte>, password: Array<Byte>, salt: Array<Byte>,
                    iterationCount: UInt32, algorithm: EvpAlgorithm): ?Array<Byte> {
    // output.fill(0)
    for (i in 0..output.size) {
        output[i] = 0
    }

    BoringSSL.errClearError()

    let md = algorithm.md()
    match (md) {
        case None => return None
        case Some(mdVal) =>
            let passwordPtr: ?Array<Byte> = if (password.size > 0) { password } else { None }

            let rc = BoringSSL.pkcs5Pbkdf2Hmac(
                passwordPtr,
                password.size.toInt64(),
                salt, salt.size.toInt64(),
                iterationCount, mdVal,
                output.size.toInt64(), output
            )

            if (rc <= 0) {
                return None
            }
            return output
    }
}

// ============================================================================
// 模块重导出
// ============================================================================
// PasswordObject, CryptoHasher, HMAC, EVP, pwhash etc. are imported via package
