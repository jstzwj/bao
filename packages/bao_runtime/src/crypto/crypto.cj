// crypto.cj - 加密模块入口
// 对应 Bun: src/runtime/crypto/crypto.zig
// 严格1:1翻译自 Bun crypto.zig

package bao_runtime

import bao_core.*
import bao_runtime.crypto.CryptoHasher
import bao_runtime.crypto.EVP
import bao_runtime.crypto.HMAC
import bao_runtime.crypto.PasswordObject
import bao_runtime.crypto.PBKDF2
import bao_runtime.crypto.BoringSSLJsc

// ============================================================================
// 加密错误创建
// 对应 Bun: crypto.zig - createCryptoError
// ============================================================================

/// 创建加密错误
/// 对应 Bun: pub fn createCryptoError(globalThis: *jsc.JSGlobalObject, err_code: u32) JSValue
public func createCryptoError(globalThis: JsObject, errCode: UInt32): JsValue {
    return BoringSSLJsc.errToJs(globalThis, errCode)
}

// ============================================================================
// 模块重导出
// 对应 Bun: crypto.zig 中的 pub const 声明
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
