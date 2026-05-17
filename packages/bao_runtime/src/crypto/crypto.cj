// crypto.cj - 加密模块入口
// 对应 Bun: src/runtime/crypto/crypto.zig + mod.rs
// 严格1:1翻译自 Bun crypto.zig / mod.rs

package bao_runtime.crypto

import bao_core.*
import bao_collections.*
import bao_runtime.*

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
public func pbkdf2Compat(output: Array<Byte>, password: Array<Byte>, salt: Array<Byte>,
                    iterationCount: UInt32, algorithm: EvpAlgorithm): ?Array<Byte> {
    return pbkdf2(output, password, salt, iterationCount, algorithm)
}

// ============================================================================
// 模块重导出
// ============================================================================
// PasswordObject, CryptoHasher, HMAC, EVP, pwhash etc. are imported via package
