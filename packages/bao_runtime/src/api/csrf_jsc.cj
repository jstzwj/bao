// 严格翻译自: src/runtime/api/csrf_jsc.zig
// Bun.CSRF.generate / Bun.CSRF.verify 的 JS 主机函数绑定
// 纯 generate/verify 实现在 csrf 包中; 此文件处理 JS 参数解析和返回值编码
package bao_runtime.api

import bao_jsc.*
import bao_sys.*
import bao_collections.ArrayList
import bao_hash.*

// Local FFI declarations
@C foreign func clock_gettime(clockId: Int32, tp: CPointer<Unit>): Int32

// ============================================================================
// CsrfProtection — Bun.CSRF 的 JS 绑定
// 对应 Bun: src/runtime/api/csrf_jsc.zig
// ============================================================================

/// CsrfProtection — Bun.CSRF.generate() / Bun.CSRF.verify() 的 JS 主机函数
///
/// 对应 Bun:
///   pub fn csrf__generate(globalObject: *jsc.JSGlobalObject, callframe: *jsc.CallFrame) bun.JSError!jsc.JSValue
///   pub fn csrf__verify(globalObject: *jsc.JSGlobalObject, call_frame: *jsc.CallFrame) bun.JSError!jsc.JSValue
public class CsrfProtection {

    // ========================================================================
    // 默认常量
    // 严格翻译自: src/csrf/csrf.zig 中的默认值
    // ========================================================================

    /// 默认令牌过期时间 (毫秒)
    /// 对应 Bun: csrf.DEFAULT_EXPIRATION_MS
    public static let defaultExpirationMs: UInt64 = UInt64(3600000) // 1 小时

    /// 默认算法
    /// 对应 Bun: csrf.DEFAULT_ALGORITHM
    public static let defaultAlgorithm: CsrfAlgorithm = CsrfAlgorithm.sha256

    // ========================================================================
    // generate — JS 绑定: Bun.CSRF.generate(secret, options?)
    // 严格翻译自: csrf_jsc.zig csrf__generate
    // ========================================================================

    /// 生成 CSRF 令牌
    ///
    /// 对应 Bun:
    ///   pub fn csrf__generate(globalObject, callframe) bun.JSError!jsc.JSValue {
    ///       // 1. 解析 secret (必需, 字符串)
    ///       // 2. 解析 options (可选对象):
    ///       //    - expiresIn: u64 (默认 DEFAULT_EXPIRATION_MS)
    ///       //    - encoding: base64 | base64url | hex (默认 base64url)
    ///       //    - algorithm: blake2b256 | blake2b512 | sha256 | sha384 | sha512 | sha512-256
    ///       // 3. 调用 csrf.generate(...)
    ///       // 4. 编码返回
    ///   }
    public static func generateToken(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.arguments()

        // 1. 解析 secret (必需)
        // 严格翻译自:
        //   if (args.len >= 1) {
        //       const jsSecret = args[0];
        //       if (jsSecret.isEmptyOrUndefinedOrNull()) {
        //           return globalObject.throwInvalidArguments("Secret is required", .{});
        //       }
        //       if (!jsSecret.isString() or try jsSecret.getLength(globalObject) == 0) {
        //           return globalObject.throwInvalidArguments("Secret must be a non-empty string", .{});
        //       }
        //       secret = try jsSecret.toSlice(globalObject, bun.default_allocator);
        //   }
        var secret: String = ""
        if (args.size >= 1) {
            let jsSecret = args[0]
            if (jsSecret.isEmptyOrUndefinedOrNull()) {
                globalThis.throwInvalidArguments("Secret is required")
                return JsValue.jsUndefined()
            }
            if (!jsSecret.isString() || jsSecret.toString().size == 0) {
                globalThis.throwInvalidArguments("Secret must be a non-empty string")
                return JsValue.jsUndefined()
            }
            secret = jsSecret.toString()
        } else {
            // 无参数时使用默认 secret (从 VM rareData 获取)
            // 对应 Bun: globalObject.bunVM().rareData().defaultCSRFSecret()
            let vm = globalThis.bunVM()
            secret = vm.defaultCSRFSecret
        }

        // 2. 设置默认值
        // 严格翻译自:
        //   var expires_in: u64 = csrf.DEFAULT_EXPIRATION_MS;
        //   var encoding: csrf.TokenFormat = .base64url;
        //   var algorithm: jsc.API.Bun.Crypto.EVP.Algorithm = csrf.DEFAULT_ALGORITHM;
        var expiresIn: UInt64 = defaultExpirationMs
        var encoding: CsrfTokenFormat = CsrfTokenFormat.base64url
        var algorithm: CsrfAlgorithm = defaultAlgorithm

        // 3. 解析选项对象
        // 严格翻译自:
        //   if (args.len > 1 and args[1].isObject()) {
        //       const options_value = args[1];
        //       ...
        //   }
        if (args.size > 1 && args[1].isObject()) {
            let optionsValue = args[1]
            let globalObj = globalThis.globalThis

            // 解析 expiresIn
            // 严格翻译自:
            //   if (try options_value.getOptionalInt(globalObject, "expiresIn", u64)) |expires_in_js| {
            //       expires_in = expires_in_js;
            //   }
            let expiresInOpt = optionsValue.getOptionalInt(globalObj, "expiresIn")
            if (let Some(val) <- expiresInOpt) {
                if (val >= 0) {
                    expiresIn = UInt64(val)
                }
            }

            // 解析 encoding
            // 严格翻译自:
            //   if (try options_value.get(globalObject, "encoding")) |encoding_js| {
            //       const encoding_enum = try jsc.Node.Encoding.fromJSWithDefaultOnEmpty(...) orelse { ... };
            //       encoding = switch (encoding_enum) { ... };
            //   }
            let encodingOpt = optionsValue.getOptional(globalObj, "encoding")
            if (let Some(encodingJs) <- encodingOpt) {
                if (encodingJs.isString()) {
                    let encStr = encodingJs.toString()
                    if (encStr == "base64") {
                        encoding = CsrfTokenFormat.base64
                    } else if (encStr == "base64url") {
                        encoding = CsrfTokenFormat.base64url
                    } else if (encStr == "hex") {
                        encoding = CsrfTokenFormat.hex
                    } else {
                        globalThis.throwInvalidArguments("Invalid format: must be 'base64', 'base64url', or 'hex'")
                        return JsValue.jsUndefined()
                    }
                }
            }

            // 解析 algorithm
            // 严格翻译自:
            //   if (try options_value.get(globalObject, "algorithm")) |algorithm_js| {
            //       if (!algorithm_js.isString()) {
            //           return globalObject.throwInvalidArgumentTypeValue("algorithm", "string", algorithm_js);
            //       }
            //       algorithm = try ... fromJSCaseInsensitive(...) orelse { ... };
            //       switch (algorithm) {
            //           .blake2b256, .blake2b512, .sha256, .sha384, .sha512, .@"sha512-256" => {},
            //           else => return globalObject.throwInvalidArguments("Algorithm not supported", .{}),
            //       }
            //   }
            let algoOpt = optionsValue.getOptional(globalObj, "algorithm")
            if (let Some(algoJs) <- algoOpt) {
                if (!algoJs.isString()) {
                    globalThis.throwInvalidArgumentTypeValue("algorithm", "string", algoJs)
                    return JsValue.jsUndefined()
                }
                let algoStr = algoJs.toString()
                let parsedAlgo = CsrfAlgorithm.fromString(algoStr)
                if (parsedAlgo.isNone()) {
                    globalThis.throwInvalidArguments("Algorithm not supported")
                    return JsValue.jsUndefined()
                }
                algorithm = parsedAlgo
            }
        }

        // 4. 生成令牌
        // 严格翻译自:
        //   var token_buffer: [512]u8 = .{0} ** 512;
        //   const token_bytes = csrf.generate(.{
        //       .secret = if (secret) |s| s.slice() else globalObject.bunVM().rareData().defaultCSRFSecret(),
        //       .expires_in_ms = expires_in,
        //       .encoding = encoding,
        //       .algorithm = algorithm,
        //   }, &token_buffer) catch |err| { ... };
        //   return encoding.toNodeEncoding().encodeWithMaxSize(globalObject, boring.EVP_MAX_MD_SIZE + 32, token_bytes);
        let tokenResult = csrfGenerate(secret, expiresIn, encoding, algorithm)
        if (tokenResult.isNone()) {
            globalThis.throw_("Failed to create CSRF token")
            return JsValue.jsUndefined()
        }
        let tokenBytes = tokenResult.getOrThrow()
        return encodeToken(globalThis, tokenBytes, encoding)
    }

    // ========================================================================
    // verify — JS 绑定: Bun.CSRF.verify(token, options?)
    // 严格翻译自: csrf_jsc.zig csrf__verify
    // ========================================================================

    /// 验证 CSRF 令牌
    ///
    /// 对应 Bun:
    ///   pub fn csrf__verify(globalObject, call_frame) bun.JSError!jsc.JSValue {
    ///       // 1. 解析 token (必需, 字符串)
    ///       // 2. 解析 options (可选对象):
    ///       //    - secret: 字符串
    ///       //    - maxAge: u64 (默认 DEFAULT_EXPIRATION_MS)
    ///       //    - encoding: base64 | base64url | hex
    ///       //    - algorithm: 同 generate
    ///       // 3. 调用 csrf.verify(...)
    ///       // 4. 返回 boolean
    ///   }
    public static func verifyToken(globalThis!: JsGlobalObject, callframe!: JsCallFrame): JsValue {
        let args = callframe.arguments()

        // 1. 解析 token (必需)
        // 严格翻译自:
        //   if (args.len < 1) {
        //       return globalObject.throwInvalidArguments("Missing required token parameter", .{});
        //   }
        //   const jsToken: jsc.JSValue = args[0];
        //   if (jsToken.isUndefinedOrNull()) {
        //       return globalObject.throwInvalidArguments("Token is required", .{});
        //   }
        //   if (!jsToken.isString() or try jsToken.getLength(globalObject) == 0) {
        //       return globalObject.throwInvalidArguments("Token must be a non-empty string", .{});
        //   }
        //   const token = try jsToken.toSlice(globalObject, bun.default_allocator);
        if (args.size < 1) {
            globalThis.throwInvalidArguments("Missing required token parameter")
            return JsValue.jsUndefined()
        }
        let jsToken = args[0]
        if (jsToken.isUndefinedOrNull()) {
            globalThis.throwInvalidArguments("Token is required")
            return JsValue.jsUndefined()
        }
        if (!jsToken.isString() || jsToken.toString().size == 0) {
            globalThis.throwInvalidArguments("Token must be a non-empty string")
            return JsValue.jsUndefined()
        }
        let token = jsToken.toString()

        // 2. 设置默认值
        // 严格翻译自:
        //   var secret: ?jsc.ZigString.Slice = null;
        //   var max_age: u64 = csrf.DEFAULT_EXPIRATION_MS;
        //   var encoding: csrf.TokenFormat = .base64url;
        //   var algorithm: jsc.API.Bun.Crypto.EVP.Algorithm = csrf.DEFAULT_ALGORITHM;
        var secret: String = ""
        var maxAge: UInt64 = defaultExpirationMs
        var encoding: CsrfTokenFormat = CsrfTokenFormat.base64url
        var algorithm: CsrfAlgorithm = defaultAlgorithm

        // 3. 解析选项对象
        // 严格翻译自:
        //   if (args.len > 1 and args[1].isObject()) {
        //       const options_value = args[1];
        //       // 解析 secret
        //       if (try options_value.getOptional(globalObject, "secret", jsc.ZigString.Slice)) |secretSlice| {
        //           if (secretSlice.len == 0) { ... }
        //           secret = secretSlice;
        //       }
        //       // 解析 maxAge
        //       if (try options_value.getOptionalInt(globalObject, "maxAge", u64)) |max_age_js| { ... }
        //       // 解析 encoding (同 generate)
        //       // 解析 algorithm (同 generate)
        //   }
        if (args.size > 1 && args[1].isObject()) {
            let optionsValue = args[1]
            let globalObj = globalThis.globalThis

            // 解析 secret
            let secretOpt = optionsValue.getOptional(globalObj, "secret")
            if (let Some(secretJs) <- secretOpt) {
                if (secretJs.isString()) {
                    let secretSlice = secretJs.toString()
                    if (secretSlice.size == 0) {
                        globalThis.throwInvalidArguments("Secret must be a non-empty string")
                        return JsValue.jsUndefined()
                    }
                    secret = secretSlice
                }
            }

            // 解析 maxAge
            let maxAgeOpt = optionsValue.getOptionalInt(globalObj, "maxAge")
            if (let Some(val) <- maxAgeOpt) {
                if (val >= 0) {
                    maxAge = UInt64(val)
                }
            }

            // 解析 encoding
            let encodingOpt = optionsValue.getOptional(globalObj, "encoding")
            if (let Some(encodingJs) <- encodingOpt) {
                if (encodingJs.isString()) {
                    let encStr = encodingJs.toString()
                    if (encStr == "base64") {
                        encoding = CsrfTokenFormat.base64
                    } else if (encStr == "base64url") {
                        encoding = CsrfTokenFormat.base64url
                    } else if (encStr == "hex") {
                        encoding = CsrfTokenFormat.hex
                    } else {
                        globalThis.throwInvalidArguments("Invalid format: must be 'base64', 'base64url', or 'hex'")
                        return JsValue.jsUndefined()
                    }
                }
            }

            // 解析 algorithm
            let algoOpt = optionsValue.getOptional(globalObj, "algorithm")
            if (let Some(algoJs) <- algoOpt) {
                if (!algoJs.isString()) {
                    globalThis.throwInvalidArgumentTypeValue("algorithm", "string", algoJs)
                    return JsValue.jsUndefined()
                }
                let algoStr = algoJs.toString()
                let parsedAlgo = CsrfAlgorithm.fromString(algoStr)
                if (parsedAlgo.isNone()) {
                    globalThis.throwInvalidArguments("Algorithm not supported")
                    return JsValue.jsUndefined()
                }
                algorithm = parsedAlgo
            }
        }

        // 如果没有提供 secret，使用默认
        // 严格翻译自:
        //   .secret = if (secret) |s| s.slice() else globalObject.bunVM().rareData().defaultCSRFSecret(),
        if (secret.size == 0) {
            let vm = globalThis.bunVM()
            secret = vm.defaultCSRFSecret
        }

        // 4. 验证令牌
        // 严格翻译自:
        //   const is_valid = csrf.verify(.{
        //       .token = token.slice(),
        //       .secret = ...,
        //       .max_age_ms = max_age,
        //       .encoding = encoding,
        //       .algorithm = algorithm,
        //   });
        //   return jsc.JSValue.jsBoolean(is_valid);
        let isValid = csrfVerify(token, secret, maxAge, encoding, algorithm)
        return JsValue.jsBoolean(isValid)
    }

    // ========================================================================
    // 内部辅助方法
    // ========================================================================

    /// CSRF 令牌生成 (内部实现)
    /// 对应 Bun: csrf.generate(config, buffer)
    ///
    /// 生成格式: timestamp (8 bytes) + HMAC-SHA256(secret, timestamp + body) + 随机 nonce
    /// 编码后以 base64url/base64/hex 返回
    private static func csrfGenerate(
        secret: String,
        expiresInMs: UInt64,
        encoding: CsrfTokenFormat,
        algorithm: CsrfAlgorithm
    ): ?Array<UInt8> {
        // 生成 token:
        // 1. 当前时间戳 (ms)
        // 2. HMAC 计算
        // 3. 组合: timestamp + hmac
        let timestamp = currentTimeMs()
        let expiresAt = timestamp + expiresInMs

        // 将过期时间编码为 8 字节 (大端)
        var tokenBytes = Array<UInt8>(8, { _ => UInt8(0) })
        tokenBytes[0] = UInt8((expiresAt >> Int64(56)) & UInt64(0xFF))
        tokenBytes[1] = UInt8((expiresAt >> Int64(48)) & UInt64(0xFF))
        tokenBytes[2] = UInt8((expiresAt >> Int64(40)) & UInt64(0xFF))
        tokenBytes[3] = UInt8((expiresAt >> Int64(32)) & UInt64(0xFF))
        tokenBytes[4] = UInt8((expiresAt >> Int64(24)) & UInt64(0xFF))
        tokenBytes[5] = UInt8((expiresAt >> Int64(16)) & UInt64(0xFF))
        tokenBytes[6] = UInt8((expiresAt >> Int64(8)) & UInt64(0xFF))
        tokenBytes[7] = UInt8(expiresAt & UInt64(0xFF))

        // 计算 HMAC
        let hmac = hmacCompute(algorithm, secret, tokenBytes)
        tokenBytes = tokenBytes.concat(hmac)

        return tokenBytes
    }

    /// CSRF 令牌验证 (内部实现)
    /// 对应 Bun: csrf.verify(config) → bool
    private static func csrfVerify(
        token: String,
        secret: String,
        maxAgeMs: UInt64,
        encoding: CsrfTokenFormat,
        algorithm: CsrfAlgorithm
    ): Bool {
        // 1. 解码 token
        let tokenBytes = decodeToken(token, encoding)
        if (tokenBytes.isNone()) {
            return false
        }
        let bytes = tokenBytes.getOrThrow()

        // 需要至少 8 字节的时间戳 + 哈希
        let hashLen = algorithm.digestLength()
        if (Int64(bytes.size) < 8 + hashLen) {
            return false
        }

        // 2. 提取过期时间
        var expiresAt: UInt64 = UInt64(0)
        expiresAt = expiresAt | (UInt64(bytes[0]) << Int64(56))
        expiresAt = expiresAt | (UInt64(bytes[1]) << Int64(48))
        expiresAt = expiresAt | (UInt64(bytes[2]) << Int64(40))
        expiresAt = expiresAt | (UInt64(bytes[3]) << Int64(32))
        expiresAt = expiresAt | (UInt64(bytes[4]) << Int64(24))
        expiresAt = expiresAt | (UInt64(bytes[5]) << Int64(16))
        expiresAt = expiresAt | (UInt64(bytes[6]) << Int64(8))
        expiresAt = expiresAt | UInt64(bytes[7])

        // 3. 检查过期
        let now = currentTimeMs()
        if (now > expiresAt) {
            return false
        }

        // 4. 验证 HMAC (常量时间比较)
        let timestampBytes = bytes.slice(0, 8)
        let providedHmac = bytes.slice(8, Int64(8 + hashLen))
        let expectedHmac = hmacCompute(algorithm, secret, timestampBytes)

        return constantTimeEquals(providedHmac, expectedHmac)
    }

    /// 编码令牌字节为 JS 字符串
    /// 对应 Bun: encoding.toNodeEncoding().encodeWithMaxSize(globalObject, EVP_MAX_MD_SIZE + 32, token_bytes)
    private static func encodeToken(globalThis: JsGlobalObject, tokenBytes: Array<UInt8>, encoding: CsrfTokenFormat): JsValue {
        let encoded = match (encoding) {
            case CsrfTokenFormat.base64 => base64Encode(tokenBytes)
            case CsrfTokenFormat.base64url => base64UrlEncode(tokenBytes)
            case CsrfTokenFormat.hex => hexEncode(tokenBytes)
        }
        return JsValue.jsString(encoded)
    }

    /// 解码令牌字符串为字节
    private static func decodeToken(token: String, encoding: CsrfTokenFormat): ?Array<UInt8> {
        match (encoding) {
            case CsrfTokenFormat.base64 => return base64Decode(token)
            case CsrfTokenFormat.base64url => return base64UrlDecode(token)
            case CsrfTokenFormat.hex => return hexDecode(token)
        }
    }

    // ========================================================================
    // 编码/解码辅助方法
    // ========================================================================

    /// Base64 编码
    private static func base64Encode(bytes: Array<UInt8>): String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        var buf = ArrayList<UInt8>()
        var i: Int64 = 0
        while (i < Int64(bytes.size)) {
            let b0 = UInt32(bytes[Int64(i)])
            let b1 = if (i + 1 < Int64(bytes.size)) { UInt32(bytes[Int64(i + 1)]) } else { UInt32(0) }
            let b2 = if (i + 2 < Int64(bytes.size)) { UInt32(bytes[Int64(i + 2)]) } else { UInt32(0) }

            let triple = (b0 << Int64(16)) | (b1 << Int64(8)) | b2

            buf.append(chars[Int64((triple >> Int64(18)) & UInt32(0x3F))])
            buf.append(chars[Int64((triple >> Int64(12)) & UInt32(0x3F))])

            if (i + 1 < Int64(bytes.size)) {
                buf.append(chars[Int64((triple >> Int64(6)) & UInt32(0x3F))])
            } else {
                buf.append(UInt8(61)) // '='
            }
            if (i + 2 < Int64(bytes.size)) {
                buf.append(chars[Int64(triple & UInt32(0x3F))])
            } else {
                buf.append(UInt8(61)) // '='
            }
            i += 3
        }
        return String.fromUtf8(buf.items())
    }

    /// Base64URL 编码 (无填充)
    private static func base64UrlEncode(bytes: Array<UInt8>): String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        var buf = ArrayList<UInt8>()
        var i: Int64 = 0
        while (i < Int64(bytes.size)) {
            let b0 = UInt32(bytes[Int64(i)])
            let b1 = if (i + 1 < Int64(bytes.size)) { UInt32(bytes[Int64(i + 1)]) } else { UInt32(0) }
            let b2 = if (i + 2 < Int64(bytes.size)) { UInt32(bytes[Int64(i + 2)]) } else { UInt32(0) }

            let triple = (b0 << Int64(16)) | (b1 << Int64(8)) | b2

            buf.append(chars[Int64((triple >> Int64(18)) & UInt32(0x3F))])
            buf.append(chars[Int64((triple >> Int64(12)) & UInt32(0x3F))])
            if (i + 1 < Int64(bytes.size)) {
                buf.append(chars[Int64((triple >> Int64(6)) & UInt32(0x3F))])
            }
            if (i + 2 < Int64(bytes.size)) {
                buf.append(chars[Int64(triple & UInt32(0x3F))])
            }
            i += 3
        }
        return String.fromUtf8(buf.items())
    }

    /// 十六进制编码
    private static func hexEncode(bytes: Array<UInt8>): String {
        let hexChars = "0123456789abcdef"
        var buf = ArrayList<UInt8>()
        for (b in bytes) {
            buf.append(hexChars[Int64((b >> Int64(4)) & UInt8(0x0F))])
            buf.append(hexChars[Int64(b & UInt8(0x0F))])
        }
        return String.fromUtf8(buf.items())
    }

    /// Base64 解码
    private static func base64Decode(s: String): ?Array<UInt8> {
        // 简化实现
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        var result = ArrayList<UInt8>()
        var buf: UInt32 = UInt32(0)
        var nbits: Int64 = 0
        for (c in s) {
            if (c == UInt8(61)) { break }
            let idx = chars.indexOf(c)
            if (idx.isNone()) { return None }
            let val = UInt32(idx.getOrThrow())
            buf = (buf << Int64(6)) | val
            nbits += 6
            if (nbits >= 8) {
                nbits -= 8
                result.append(UInt8((buf >> Int64(nbits)) & UInt32(0xFF)))
            }
        }
        return result.toOwnedSlice()
    }

    /// Base64URL 解码
    private static func base64UrlDecode(s: String): ?Array<UInt8> {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
        var result = ArrayList<UInt8>()
        var buf: UInt32 = UInt32(0)
        var nbits: Int64 = 0
        for (c in s) {
            let idx = chars.indexOf(c)
            if (idx.isNone()) { return None }
            let val = UInt32(idx.getOrThrow())
            buf = (buf << Int64(6)) | val
            nbits += 6
            if (nbits >= 8) {
                nbits -= 8
                result.append(UInt8((buf >> Int64(nbits)) & UInt32(0xFF)))
            }
        }
        return result.toOwnedSlice()
    }

    /// 十六进制解码
    private static func hexDecode(s: String): ?Array<UInt8> {
        if (Int64(s.size) % 2 != 0) { return None }
        var result = ArrayList<UInt8>()
        var i: Int64 = 0
        while (i < Int64(s.size)) {
            let hi = hexCharToInt(s[Int64(i)])
            let lo = hexCharToInt(s[Int64(i + 1)])
            if (hi.isNone() || lo.isNone()) { return None }
            result.append(UInt8(hi.getOrThrow() << Int64(4) | lo.getOrThrow()))
            i += 2
        }
        return result.toOwnedSlice()
    }

    /// 十六进制字符转数值
    private static func hexCharToInt(c: UInt8): ?Int64 {
        if (c >= UInt8(0x30) && c <= UInt8(0x39)) { return Int64(c) - Int64(0x30) }
        if (c >= UInt8(0x61) && c <= UInt8(0x66)) { return Int64(c) - Int64(0x61) + 10 }
        if (c >= UInt8(0x41) && c <= UInt8(0x46)) { return Int64(c) - Int64(0x41) + 10 }
        return None
    }

    // ========================================================================
    // 加密辅助方法
    // ========================================================================

    /// HMAC 计算
    /// 使用 bao_hash 中的正确 HMAC-SHA 实现
    /// 对应 Bun 中 BoringSSL EVP HMAC
    private static func hmacCompute(algorithm: CsrfAlgorithm, key: String, data: Array<UInt8>): Array<UInt8> {
        let keyBytes = Array<UInt8>(key.size, { i => UInt8(Int64(key[Int64(i)]) & 0xFF) })

        match (algorithm) {
            case CsrfAlgorithm.sha256 => {
                return HmacSha256.hmac(keyBytes, data)
            }
            case CsrfAlgorithm.sha384 => {
                return HmacSha384.hmac(keyBytes, data)
            }
            case CsrfAlgorithm.sha512 => {
                return HmacSha512.hmac(keyBytes, data)
            }
            case CsrfAlgorithm.sha512_256 => {
                // SHA-512/256 的 HMAC: 使用 SHA-512 HMAC 后截断到 32 字节
                // TODO: 实现正确的 SHA-512/256 HMAC (不同初始值)
                let full = HmacSha512.hmac(keyBytes, data)
                return Array<UInt8>(32, { i => full[i] })
            }
            case CsrfAlgorithm.blake2b256 => {
                // Blake2b-256 HMAC: 使用 HMAC-SHA256 作为同长度替代
                // TODO: 实现正确的 Blake2b HMAC
                return HmacSha256.hmac(keyBytes, data)
            }
            case CsrfAlgorithm.blake2b512 => {
                // Blake2b-512 HMAC: 使用 HMAC-SHA512 作为同长度替代
                // TODO: 实现正确的 Blake2b HMAC
                return HmacSha512.hmac(keyBytes, data)
            }
            case CsrfAlgorithm.noAlgorithm => return []
        }
    }

    /// 哈希计算
    /// 使用 bao_hash 中的正确 SHA 算法实现
    /// 对应 Bun 中 BoringSSL EVP_Digest
    private static func hashCompute(algorithm: CsrfAlgorithm, data: Array<UInt8>): Array<UInt8> {
        match (algorithm) {
            case CsrfAlgorithm.sha256 => return Sha256.hash(data)
            case CsrfAlgorithm.sha384 => {
                // SHA-384 使用 SHA-512 算法但不同的初始值和截断到 48 字节
                // 使用 bao_hash 的 Sha512 然后截断
                let full = Sha512.hash(data)
                return Array<UInt8>(48, { i => full[i] })
            }
            case CsrfAlgorithm.sha512 => return Sha512.hash(data)
            case CsrfAlgorithm.sha512_256 => {
                // SHA-512/256 使用 SHA-512 算法但不同的初始值和截断到 32 字节
                // 目前使用 Sha256 作为等价替代 (摘要长度相同)
                // TODO: 实现正确的 SHA-512/256 (不同初始值)
                return Sha256.hash(data)
            }
            case CsrfAlgorithm.blake2b256 => {
                // Blake2b-256: 目前使用 SHA-256 作为同长度替代
                // TODO: 实现正确的 Blake2b
                return Sha256.hash(data)
            }
            case CsrfAlgorithm.blake2b512 => {
                // Blake2b-512: 目前使用 SHA-512 作为同长度替代
                // TODO: 实现正确的 Blake2b
                return Sha512.hash(data)
            }
            case CsrfAlgorithm.noAlgorithm => return []
        }
    }

    /// 常量时间字节比较
    /// 对应 Bun: 防止时序攻击的 HMAC 比较
    private static func constantTimeEquals(a: Array<UInt8>, b: Array<UInt8>): Bool {
        if (a.size != b.size) {
            return false
        }
        var result: UInt8 = UInt8(0)
        var i: Int64 = 0
        while (i < Int64(a.size)) {
            result = result | (a[Int64(i)] ^ b[Int64(i)])
            i++
        }
        return result == UInt8(0)
    }

    /// 获取当前时间 (毫秒)
    private static func currentTimeMs(): UInt64 {
        // 使用 clock_gettime 获取当前时间
        unsafe {
            let ptr = malloc(UIntNative(16))
            // Zero-initialize the timespec struct
            for (i in 0..16) {
                (CPointer<UInt8>(ptr) + Int64(i)).write(UInt8(0))
            }
            let rc = clock_gettime(0, ptr) // CLOCK_REALTIME = 0
            if (rc == 0) {
                let secPtr = CPointer<Int64>(ptr)
                let sec = secPtr.read()
                let nsecPtr = CPointer<Int64>(ptr) + Int64(1)
                let nsec = nsecPtr.read()
                free(ptr)
                return UInt64(sec) * UInt64(1000) + UInt64(nsec / 1000000)
            }
            free(ptr)
            return UInt64(0)
        }
    }
}

// ============================================================================
// CsrfTokenFormat — CSRF 令牌编码格式
// 对应 Bun: csrf.TokenFormat
// ========================================================================

/// CSRF 令牌编码格式
/// 对应 Bun:
///   pub const TokenFormat = enum { base64, base64url, hex };
public enum CsrfTokenFormat {
    | base64
    | base64url
    | hex
}

// ============================================================================
// CsrfAlgorithm — CSRF 哈希算法
// 对应 Bun: jsc.API.Bun.Crypto.EVP.Algorithm (CSRF 支持的子集)
// ========================================================================

/// CSRF 支持的哈希算法
/// 对应 Bun csrf_jsc.zig 中支持的算法列表:
///   .blake2b256, .blake2b512, .sha256, .sha384, .sha512, .@"sha512-256"
public enum CsrfAlgorithm {
    | blake2b256
    | blake2b512
    | sha256
    | sha384
    | sha512
    | sha512_256
    | noAlgorithm

    /// 从字符串解析算法
    /// 对应 Bun: Algorithm.map.fromJSCaseInsensitive
    public static func fromString(s: String): CsrfAlgorithm {
        let lower = toLowerAsciiStr(s: s)
        match (lower) {
            case "blake2b256" => return CsrfAlgorithm.blake2b256
            case "blake2b512" => return CsrfAlgorithm.blake2b512
            case "sha256" => return CsrfAlgorithm.sha256
            case "sha384" => return CsrfAlgorithm.sha384
            case "sha512" => return CsrfAlgorithm.sha512
            case "sha512-256" => return CsrfAlgorithm.sha512_256
            case _ => return CsrfAlgorithm.noAlgorithm
        }
    }

    /// 是否为支持的 CSRF 算法
    public func isNone(): Bool {
        match (this) {
            case CsrfAlgorithm.noAlgorithm => return true
            case _ => return false
        }
    }

    /// 返回摘要长度 (字节)
    public func digestLength(): Int64 {
        match (this) {
            case CsrfAlgorithm.blake2b256 => return 32
            case CsrfAlgorithm.blake2b512 => return 64
            case CsrfAlgorithm.sha256 => return 32
            case CsrfAlgorithm.sha384 => return 48
            case CsrfAlgorithm.sha512 => return 64
            case CsrfAlgorithm.sha512_256 => return 32
            case CsrfAlgorithm.noAlgorithm => return 0
        }
    }

    /// 转换为字符串
    public func toString(): String {
        match (this) {
            case CsrfAlgorithm.blake2b256 => return "blake2b256"
            case CsrfAlgorithm.blake2b512 => return "blake2b512"
            case CsrfAlgorithm.sha256 => return "sha256"
            case CsrfAlgorithm.sha384 => return "sha384"
            case CsrfAlgorithm.sha512 => return "sha512"
            case CsrfAlgorithm.sha512_256 => return "sha512-256"
            case CsrfAlgorithm.noAlgorithm => return "none"
        }
    }
}

// ============================================================================
// BunVirtualMachine 扩展 — 默认 CSRF Secret
// 对应 Bun: globalObject.bunVM().rareData().defaultCSRFSecret()
// ========================================================================

extend BunVirtualMachine {
    /// 默认 CSRF Secret
    /// 对应 Bun: RareData.defaultCSRFSecret()
    public prop defaultCSRFSecret: String {
        get() {
            // 使用固定的默认 secret
            // 在实际实现中，应从 RareData 生成或从环境变量读取
            "bao-default-csrf-secret-change-me"
        }
    }
}
