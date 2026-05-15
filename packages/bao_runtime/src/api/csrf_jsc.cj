// 严格翻译自: src/runtime/api/csrf_jsc.zig
package bao_runtime

import bao_jsc.*
import bao_core.*

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
    public static func csrfGenerate(globalObject: JsGlobalObject, callframe: JsCallFrame): JsValue {
        let args = callframe.arguments()
        var secret: ?ZigStringSlice = none

        if (args.len >= 1) {
            let jsSecret = args[0]
            if (jsSecret.isEmptyOrUndefinedOrNull()) {
                globalObject.throwInvalidArguments("Secret is required")
                return JsValue.zero
            }
            if (!jsSecret.isString() || try jsSecret.getLength(globalObject) == 0) {
                globalObject.throwInvalidArguments("Secret must be a non-empty string")
                return JsValue.zero
            }
            secret = try jsSecret.toSlice(globalObject, default_allocator)
        }
        defer { if (let s = secret) { s.deinit() } }

        // 默认值
        var expiresIn: UInt64 = Csrf.DEFAULT_EXPIRATION_MS
        var encoding: CsrfTokenFormat = .base64url
        var algorithm: EVPAlgorithm = Csrf.DEFAULT_ALGORITHM

        // 检查选项对象
        if (args.len > 1 && args[1].isObject()) {
            let optionsValue = args[1]

            // 提取 expiresIn
            if (let expiresInJs = try optionsValue.getOptionalInt(globalObject, "expiresIn")) {
                expiresIn = expiresInJs
            }

            // 提取 encoding
            if (let encodingJs = try optionsValue.get(globalObject, "encoding")) {
                // ... 解析编码
            }

            // 提取 algorithm
            if (let algorithmJs = try optionsValue.get(globalObject, "algorithm")) {
                if (!algorithmJs.isString()) {
                    globalObject.throwInvalidArgumentTypeValue("algorithm", "string", algorithmJs)
                    return JsValue.zero
                }
                algorithm = try EVPAlgorithm.map.fromJSCaseInsensitive(globalObject, algorithmJs) ?? {
                    globalObject.throwInvalidArguments("Algorithm not supported")
                    return JsValue.zero
                }
            }
        }

        // 生成令牌
        var tokenBuffer: Array<UInt8> = Array<UInt8>(count: 512, repeating: 0)
        let tokenBytes = try Csrf.generate(
            secret: secret?.slice() ?? globalObject.bunVM().rareData().defaultCSRFSecret(),
            expiresInMs: expiresIn,
            encoding: encoding,
            algorithm: algorithm,
        )

        // 编码令牌
        return encoding.toNodeEncoding().encodeWithMaxSize(globalObject, tokenBytes)
    }

    // ========================================================================
    // csrf__verify - Bun.CSRF.verify(token, options?)
    // ========================================================================

    /// JS 绑定: 验证 CSRF 令牌
    public static func csrfVerify(globalObject: JsGlobalObject, callFrame: JsCallFrame): JsValue {
        let args = callFrame.arguments()
        if (args.len < 1) {
            globalObject.throwInvalidArguments("Missing required token parameter")
            return JsValue.zero
        }

        let jsToken = args[0]
        if (jsToken.isUndefinedOrNull()) {
            globalObject.throwInvalidArguments("Token is required")
            return JsValue.zero
        }
        if (!jsToken.isString() || try jsToken.getLength(globalObject) == 0) {
            globalObject.throwInvalidArguments("Token must be a non-empty string")
            return JsValue.zero
        }

        let token = try jsToken.toSlice(globalObject, default_allocator)
        defer token.deinit()

        // 默认值
        var secret: ?ZigStringSlice = none
        defer { if (let s = secret) { s.deinit() } }
        var maxAge: UInt64 = Csrf.DEFAULT_EXPIRATION_MS
        var encoding: CsrfTokenFormat = .base64url
        var algorithm: EVPAlgorithm = Csrf.DEFAULT_ALGORITHM

        // 解析选项
        if (args.len > 1 && args[1].isObject()) {
            let optionsValue = args[1]

            if (let secretSlice = try optionsValue.getOptional(globalObject, "secret")) {
                if (secretSlice.len == 0) {
                    globalObject.throwInvalidArguments("Secret must be a non-empty string")
                    return JsValue.zero
                }
                secret = secretSlice
            }

            if (let maxAgeJs = try optionsValue.getOptionalInt(globalObject, "maxAge")) {
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

        return JsValue.jsBoolean(isValid)
    }
}
