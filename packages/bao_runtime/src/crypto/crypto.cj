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
/// 对应 Bun: pub fn createCryptoError(globalThis: *jsc.JSGlobalObject, err_code: u32) JSValue
/// 对应 Bun mod.rs: pub fn create_crypto_error(global_this: &JSGlobalObject, err_code: u32) -> JSValue
public func createCryptoError(globalThis: JsObject, errCode: UInt32): JsValue {
    return BoringSSLJsc.errToJs(globalThis, errCode)
}

// ============================================================================
// PBKDF2 顶层函数
// 对应 Bun: mod.rs - pub fn pbkdf2(output, password, salt, iteration_count, algorithm) -> Option<&[u8]>
// ============================================================================

/// PBKDF2 密码派生函数
/// 对应 Bun mod.rs: pub fn pbkdf2<'a>(output, password, salt, iteration_count, algorithm) -> Option<&'a [u8]>
/// 用于 Rust 端 PBKDF2 (对应 Zig: src/runtime/crypto/PBKDF2.zig pub fn pbkdf2)
///
/// 返回 Some(output) 成功, None BoringSSL 错误
public func pbkdf2(output: Array<Byte>, password: Array<Byte>, salt: Array<Byte>,
                    iterationCount: UInt32, algorithm: EVP.Algorithm): ?Array<Byte> {
    // output.fill(0)
    for (i in 0..output.size) {
        output[i] = 0
    }

    // BoringSSL.ERR_clear_error()
    BoringSSL.errClearError()

    // algorithm.md() 获取 EVP_MD; 如果不支持则返回 None
    let md = algorithm.md()
    match (md) {
        case None => return None
        case Some(mdVal) => {
            // PKCS5_PBKDF2_HMAC(password, password.len, salt, salt.len,
            //                    iteration_count, digest, output.len, output)
            let passwordPtr = if (password.size == 0) {
                CPointer<Byte>.null()
            } else {
                CPointer<Byte>.fromArray(password)
            }

            let rc = BoringSSL.pkcs5Pbkdf2Hmac(
                password, password.size.toInt64(),
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
}

// ============================================================================
// 模块重导出
// 对应 Bun: mod.rs / crypto.zig 中的 pub const 声明
// ============================================================================

// PasswordObject - 密码哈希对象
// 对应 Bun: pub const PasswordObject = @import("./PasswordObject.zig").PasswordObject
// 对应 Bun: pub const JSPasswordObject = @import("./PasswordObject.zig").JSPasswordObject

// CryptoHasher - 加密哈希器
// 对应 Bun: pub const CryptoHasher = @import("./CryptoHasher.zig").CryptoHasher

// 静态哈希器类型 - 对应 Bun 中 StaticCryptoHasher 生成的类型
// 对应 Bun: pub const MD4 = @import("./CryptoHasher.zig").MD4
// 对应 Bun: pub const MD5 = @import("./CryptoHasher.zig").MD5
// 对应 Bun: pub const SHA1 = @import("./CryptoHasher.zig").SHA1
// 对应 Bun: pub const SHA224 = @import("./CryptoHasher.zig").SHA224
// 对应 Bun: pub const SHA256 = @import("./CryptoHasher.zig").SHA256
// 对应 Bun: pub const SHA384 = @import("./CryptoHasher.zig").SHA384
// 对应 Bun: pub const SHA512 = @import("./CryptoHasher.zig").SHA512
// 对应 Bun: pub const SHA512_256 = @import("./CryptoHasher.zig").SHA512_256

// HMAC - 消息认证码
// 对应 Bun: pub const HMAC = @import("./HMAC.zig")

// EVP - 高级加密接口
// 对应 Bun: pub const EVP = @import("./EVP.zig")

// pwhash - 密码哈希 shim (argon2 + bcrypt)
// 对应 Bun: #[path = "pwhash.rs"] pub mod pwhash
// 已在 pwhash.cj 中实现

// ported from: src/runtime/crypto/crypto.zig + mod.rs
