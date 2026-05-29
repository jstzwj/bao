// 严格翻译自: src/runtime/api/csrf_jsc.zig
package bao_runtime.api

import bao_jsc.*
import bao_core.*
import bao_csrf.*

// ============================================================================
// EVPAlgorithm - HMAC/签名算法枚举 (桩定义)
// 对应 Bun 中的 EVP 摘要算法, 用于 CSRF 签名
// ============================================================================

/// EVP 摘要算法枚举 - 对应 BoringSSL EVP_MD 算法
public enum EVPAlgorithm {
    | Sha1
    | Sha256
    | Sha384
    | Sha512

    /// 默认算法
    public static let DEFAULT: EVPAlgorithm = Sha256

    /// 从 JS 字符串(不区分大小写)映射到算法枚举
    public static func fromStringIgnoreCase(algo: String): ?EVPAlgorithm {
        let lower = algo.toLowerCase()
        if (lower == "sha1") { return Some(Sha1) }
        if (lower == "sha256") { return Some(Sha256) }
        if (lower == "sha384") { return Some(Sha384) }
        if (lower == "sha512") { return Some(Sha512) }
        return None
    }
}

// ============================================================================
// csrf_jsc - Bun.CSRF.generate / Bun.CSRF.verify 的 JS 绑定
// 对应 Bun: src/runtime/api/csrf_jsc.zig
// ============================================================================

/// CSRF JS 绑定函数
public class CsrfJsc {

    // ========================================================================
    // csrf__generate - Bun.CSRF.generate(secret, options?)
    // ========================================================================

    /// JS 绑定: 生成 CSRF 令牌
    public static func csrfGenerate(jsGlobalObject!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.arguments()
        var secret: ?ZigStringSlice = none

        if (args.len >= 1) {
            let jsSecret = args[0]
            if (jsSecret.isEmptyOrUndefinedOrNull()) {
                globalObject.throwInvalidArguments("Secret is required")
                return JsValue.jsUndefined()
            }
            if (!jsSecret.isString() || jsSecret.getLength(globalObject)  == 0) {
                globalObject.throwInvalidArguments("Secret must be a non-empty string")
                return JsValue.jsUndefined()
            }
            secret = jsSecret.toSlice(globalObject, default_allocator) 
        }
        // 默认值
        var expiresIn: UInt64 = Csrf.DEFAULT_EXPIRATION_MS
        var encoding: CsrfTokenFormat = CsrfTokenFormat.Base64Url
        var algorithm: EVPAlgorithm = EVPAlgorithm.DEFAULT

        // 检查选项对象
        if (args.len > 1 && args[1].isObject()) {
            let optionsValue = args[1]

            // 提取 expiresIn
            if (let expiresInJs <- optionsValue.getOptionalInt(globalObject, "expiresIn") ) {
                expiresIn = expiresInJs
            }

            // 提取 encoding
            if (let encodingJs <- optionsValue.get(globalObject, "encoding") ) {
                // ... 解析编码
            }

            // 提取 algorithm
            if (let algorithmJs <- optionsValue.get(globalObject, "algorithm") ) {
                if (!algorithmJs.isString()) {
                    globalObject.throwInvalidArgumentTypeValue("algorithm", "string", algorithmJs)
                    return JsValue.jsUndefined()
                }
                let algoStr = algorithmJs.toSlice(globalObject, default_allocator)
                let algoOpt = EVPAlgorithm.fromStringIgnoreCase(algoStr.slice())
                if (algoOpt.isNone()) {
                    globalObject.throwInvalidArguments("Algorithm not supported")
                    return JsValue.jsUndefined()
                }
                algorithm = algoOpt.get()
            }
        }

        // 生成令牌
        var tokenBuffer: Array<UInt8> = Array<UInt8>(count: 512, repeating: 0)
        let tokenBytes = Csrf.generate (
            secret: secret?.slice() ?? globalObject.bunVM().rareData().defaultCSRFSecret(),
            expiresInMs: expiresIn,
            encoding: encoding,
            algorithm: algorithm,
        )

        // 编码令牌
        let result = encoding.toNodeEncoding().encodeWithMaxSize(globalObject, tokenBytes)
        if (let s <- secret) { s.deinit() }
        return result
    }

    // ========================================================================
    // csrf__verify - Bun.CSRF.verify(token, options?)
    // ========================================================================

    /// JS 绑定: 验证 CSRF 令牌
    public static func csrfVerify(jsGlobalObject!: JsGlobalObject, callFrame!: JsCallFrame): JsValue {
        let args = callFrame.arguments()
        if (args.len < 1) {
            globalObject.throwInvalidArguments("Missing required token parameter")
            return JsValue.jsUndefined()
        }

        let jsToken = args[0]
        if (jsToken.isUndefinedOrNull()) {
            globalObject.throwInvalidArguments("Token is required")
            return JsValue.jsUndefined()
        }
        if (!jsToken.isString() || jsToken.getLength(globalObject)  == 0) {
            globalObject.throwInvalidArguments("Token must be a non-empty string")
            return JsValue.jsUndefined()
        }

        let token = jsToken.toSlice(globalObject, default_allocator)
        // 默认值
        var secret: ?ZigStringSlice = none
        var maxAge: UInt64 = Csrf.DEFAULT_EXPIRATION_MS
        var encoding: CsrfTokenFormat = CsrfTokenFormat.Base64Url
        var algorithm: EVPAlgorithm = EVPAlgorithm.DEFAULT

        // 解析选项
        if (args.len > 1 && args[1].isObject()) {
            let optionsValue = args[1]

            if (let secretSlice <- optionsValue.getOptional(globalObject, "secret") ) {
                if (secretSlice.len == 0) {
                    globalObject.throwInvalidArguments("Secret must be a non-empty string")
                    return JsValue.jsUndefined()
                }
                secret = secretSlice
            }

            if (let maxAgeJs <- optionsValue.getOptionalInt(globalObject, "maxAge") ) {
                maxAge = maxAgeJs
            }

            // ... 解析 encoding 和 algorithm
        }

        // 验证令牌
        let isValid = Csrf.verify(
            token: token.slice(),
            secret: secret?.slice() ?? globalObject.bunVM().rareData().defaultCSRFSecret(),
            maxAgeMs: maxAge,
            encoding: encoding,
            algorithm: algorithm,
        )

        let boolResult = JsValue.jsBoolean(isValid)
        if (let s <- secret) { s.deinit() }
        token.deinit()
        return boolResult
    }
}
