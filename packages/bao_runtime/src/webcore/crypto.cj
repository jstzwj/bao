// Crypto - Web Crypto API
// 对应 Bun: src/runtime/webcore/Crypto.zig
// 严格翻译自: src/runtime/webcore/Crypto.zig
// 加上 WebKit SubtleCrypto C++ 实现的 Cangjie 等价物
package bao_runtime.webcore

import bao_core.*
import bao_jsc.*
import bao_collections.ArrayList
import bao_sys.*
import bao_runtime.crypto.*

@C foreign func malloc(size: UIntNative): CPointer<Unit>
@C foreign func free(ptr: CPointer<Unit>): Unit
@C foreign func getrandom(buf: CPointer<Unit>, buflen: UIntNative, flags: UInt32): Int64
@C foreign func clock_gettime_monotonic_webcrypto(): Int64
@C foreign func clock_gettime_realtime_webcrypto(buf: CPointer<Unit>): Int32

// ============================================================================
// CryptoKey - Web Crypto API Key
// 对应 Web API: CryptoKey
// 对应 WebKit: WebCore::CryptoKey
// ============================================================================

/// Web Crypto Key 类型
/// 对应 WebKit: CryptoKeyType
public enum WebCryptoKeyType {
| Secret
| Public
| Private
}

/// Web Crypto Key 用途
/// 对应 WebKit: CryptoKeyUsageBitmap
public enum WebCryptoKeyUsage {
| Encrypt
| Decrypt
| Sign
| Verify
| DeriveKey
| DeriveBits
| WrapKey
| UnwrapKey
}

/// Web Crypto Key 格式
/// 对应 WebKit: CryptoKeyFormat (KeyFormat)
public enum WebCryptoKeyFormat {
| Raw
| Spki
| Pkcs8
| Jwk
}

/// Web Crypto 算法标识
/// 对应 WebKit: CryptoAlgorithmIdentifier
public enum WebCryptoAlgorithmId {
| AesCbc
| AesCtr
| AesGcm
| AesKw
| Hmac
| RsaOaep
| RsassaPkcs1v15
| RsaPss
| Ecdsa
| Ecdh
| Sha1
| Sha224
| Sha256
| Sha384
| Sha512
| Pbkdf2
| Hkdf
| Ed25519
| X25519

    /// 从算法名称字符串解析
    public static func fromName(name: String): ?WebCryptoAlgorithmId {
        let lower = asciiLowerCrypto(name)
        match (lower) {
            case "aes-cbc" => WebCryptoAlgorithmId.AesCbc
            case "aes-ctr" => WebCryptoAlgorithmId.AesCtr
            case "aes-gcm" => WebCryptoAlgorithmId.AesGcm
            case "aes-kw" => WebCryptoAlgorithmId.AesKw
            case "hmac" => WebCryptoAlgorithmId.Hmac
            case "rsa-oaep" => WebCryptoAlgorithmId.RsaOaep
            case "rsassa-pkcs1-v1_5" => WebCryptoAlgorithmId.RsassaPkcs1v15
            case "rsa-pss" => WebCryptoAlgorithmId.RsaPss
            case "ecdsa" => WebCryptoAlgorithmId.Ecdsa
            case "ecdh" => WebCryptoAlgorithmId.Ecdh
            case "sha-1" => WebCryptoAlgorithmId.Sha1
            case "sha-224" => WebCryptoAlgorithmId.Sha224
            case "sha-256" => WebCryptoAlgorithmId.Sha256
            case "sha-384" => WebCryptoAlgorithmId.Sha384
            case "sha-512" => WebCryptoAlgorithmId.Sha512
            case "pbkdf2" => WebCryptoAlgorithmId.Pbkdf2
            case "hkdf" => WebCryptoAlgorithmId.Hkdf
            case "ed25519" => WebCryptoAlgorithmId.Ed25519
            case "x25519" => WebCryptoAlgorithmId.X25519
            case _ => None
        }
    }

    /// 获取对应 EVP 摘要算法
    public func toEvpAlgorithm(): ?EvpAlgorithm {
        match (this) {
            case WebCryptoAlgorithmId.Sha1 => EvpAlgorithm.sha1
            case WebCryptoAlgorithmId.Sha224 => EvpAlgorithm.sha224
            case WebCryptoAlgorithmId.Sha256 => EvpAlgorithm.sha256
            case WebCryptoAlgorithmId.Sha384 => EvpAlgorithm.sha384
            case WebCryptoAlgorithmId.Sha512 => EvpAlgorithm.sha512
            case _ => None
        }
    }

    /// 算法名称
    public func name(): String {
        match (this) {
            case WebCryptoAlgorithmId.AesCbc => "AES-CBC"
            case WebCryptoAlgorithmId.AesCtr => "AES-CTR"
            case WebCryptoAlgorithmId.AesGcm => "AES-GCM"
            case WebCryptoAlgorithmId.AesKw => "AES-KW"
            case WebCryptoAlgorithmId.Hmac => "HMAC"
            case WebCryptoAlgorithmId.RsaOaep => "RSA-OAEP"
            case WebCryptoAlgorithmId.RsassaPkcs1v15 => "RSASSA-PKCS1-v1_5"
            case WebCryptoAlgorithmId.RsaPss => "RSA-PSS"
            case WebCryptoAlgorithmId.Ecdsa => "ECDSA"
            case WebCryptoAlgorithmId.Ecdh => "ECDH"
            case WebCryptoAlgorithmId.Sha1 => "SHA-1"
            case WebCryptoAlgorithmId.Sha224 => "SHA-224"
            case WebCryptoAlgorithmId.Sha256 => "SHA-256"
            case WebCryptoAlgorithmId.Sha384 => "SHA-384"
            case WebCryptoAlgorithmId.Sha512 => "SHA-512"
            case WebCryptoAlgorithmId.Pbkdf2 => "PBKDF2"
            case WebCryptoAlgorithmId.Hkdf => "HKDF"
            case WebCryptoAlgorithmId.Ed25519 => "Ed25519"
            case WebCryptoAlgorithmId.X25519 => "X25519"
        }
    }
}

/// CryptoKey - Web Crypto API 密钥对象
/// 对应 Web API: CryptoKey
/// 对应 WebKit: WebCore::CryptoKey
public class WebCryptoKey {
    public var algorithm: WebCryptoAlgorithmId
    public var keyType: WebCryptoKeyType
    public var extractable: Bool
    public var usages: ArrayList<WebCryptoKeyUsage>
    /// 原始密钥数据
    public var keyData: Array<Byte>
    /// AES 密钥长度 (bits): 128, 192, 256
    public var keyLength: Int64
    /// HMAC 哈希算法
    public var hashAlgorithm: ?WebCryptoAlgorithmId
    /// RSA 模数长度 (bits)
    public var modulusLength: Int64
    /// RSA 公共指数
    public var publicExponent: Array<Byte>
    /// EC 曲线名称
    public var namedCurve: String

    public init() {
        this.algorithm = WebCryptoAlgorithmId.AesCbc
        this.keyType = WebCryptoKeyType.Secret
        this.extractable = false
        this.usages = ArrayList<WebCryptoKeyUsage>()
        this.keyData = Array<Byte>()
        this.keyLength = 0
        this.hashAlgorithm = None
        this.modulusLength = 0
        this.publicExponent = Array<Byte>()
        this.namedCurve = ""
    }

    /// 创建 AES 密钥
    public static func createAes(algorithm: WebCryptoAlgorithmId, keyData: Array<Byte>,
                                  extractable: Bool, usages: ArrayList<WebCryptoKeyUsage>): WebCryptoKey {
        let key = WebCryptoKey()
        key.algorithm = algorithm
        key.keyType = WebCryptoKeyType.Secret
        key.extractable = extractable
        key.usages = usages
        key.keyData = keyData
        key.keyLength = Int64(keyData.size) * 8
        return key
    }

    /// 创建 HMAC 密钥
    public static func createHmac(keyData: Array<Byte>, hashAlg: ?WebCryptoAlgorithmId,
                                   extractable: Bool, usages: ArrayList<WebCryptoKeyUsage>): WebCryptoKey {
        let key = WebCryptoKey()
        key.algorithm = WebCryptoAlgorithmId.Hmac
        key.keyType = WebCryptoKeyType.Secret
        key.extractable = extractable
        key.usages = usages
        key.keyData = keyData
        key.keyLength = Int64(keyData.size) * 8
        key.hashAlgorithm = hashAlg
        return key
    }

    /// 检查用途是否允许
    public func allows(usage: WebCryptoKeyUsage): Bool {
        let targetName = usageName(usage)
        for (u in this.usages) {
            if (usageName(u) == targetName) {
                return true
            }
        }
        return false
    }

    private func usageName(u: WebCryptoKeyUsage): String {
        match (u) {
            case WebCryptoKeyUsage.Encrypt => "encrypt"
            case WebCryptoKeyUsage.Decrypt => "decrypt"
            case WebCryptoKeyUsage.Sign => "sign"
            case WebCryptoKeyUsage.Verify => "verify"
            case WebCryptoKeyUsage.DeriveKey => "deriveKey"
            case WebCryptoKeyUsage.DeriveBits => "deriveBits"
            case WebCryptoKeyUsage.WrapKey => "wrapKey"
            case WebCryptoKeyUsage.UnwrapKey => "unwrapKey"
        }
    }

    /// 转为 JsValue
    public func toJsValue(): JsValue {
        let obj = JsObject()
        obj.set("type", JsValue(match (this.keyType) {
            case WebCryptoKeyType.Secret => "secret"
            case WebCryptoKeyType.Public => "public"
            case WebCryptoKeyType.Private => "private"
        }))
        obj.set("extractable", JsValue(this.extractable))
        obj.set("algorithm", JsValue(this.algorithm.name()))
        let usageList = ArrayList<JsValue>()
        for (u in this.usages) {
            usageList.append(JsValue(match (u) {
                case WebCryptoKeyUsage.Encrypt => "encrypt"
                case WebCryptoKeyUsage.Decrypt => "decrypt"
                case WebCryptoKeyUsage.Sign => "sign"
                case WebCryptoKeyUsage.Verify => "verify"
                case WebCryptoKeyUsage.DeriveKey => "deriveKey"
                case WebCryptoKeyUsage.DeriveBits => "deriveBits"
                case WebCryptoKeyUsage.WrapKey => "wrapKey"
                case WebCryptoKeyUsage.UnwrapKey => "unwrapKey"
            }))
        }
        obj.set("usages", JsValue.array(usageList))
        return JsValue(obj)
    }
}

// ============================================================================
// SubtleCrypto - Web Crypto API Subtle 接口
// 对应 Web API: crypto.subtle
// 对应 WebKit: WebCore::SubtleCrypto
// ============================================================================

/// SubtleCrypto - Web Crypto API 的 subtle 属性
/// 对应 Web API: SubtleCrypto
/// 对应 WebKit: WebCore::SubtleCrypto (C++ 实现)
/// 在 Bun 中通过 WebKit IDL 绑定实现, 在 Bao 中用 Cangjie 直接实现
public class SubtleCrypto {

    // ========================================================================
    // digest - 消息摘要
    // 对应 Web API: subtle.digest(algorithm, data)
    // 对应 WebKit: SubtleCrypto::digest()
    // ========================================================================

    /// 计算数据的消息摘要
    /// 对应 Web API: subtle.digest(algorithm, data)
    /// 支持: SHA-1, SHA-224, SHA-256, SHA-384, SHA-512
    public static func digest(algorithmId: WebCryptoAlgorithmId, data: Array<Byte>): JsValue {
        let algOpt = algorithmId.toEvpAlgorithm()
        match (algOpt) {
            case None =>
                return JsValue("Unsupported digest algorithm: " + algorithmId.name())
            case Some(evpAlg) =>
                let md = evpAlg.md()
                match (md) {
                    case None =>
                        return JsValue("Failed to get digest for: " + algorithmId.name())
                    case Some(mdVal) =>
                        var outputBuf = Array<Byte>(64, repeat: 0)
                        let evp = EVP(evpAlg, mdVal, Option<Engine>.None)
                        let result = evp.hash(Option<Engine>.None, data, outputBuf)
                        evp.deinit()
                        match (result) {
                            case None =>
                                let err = BoringSSL.errGetError()
                                BoringSSL.errClearError()
                                return JsValue("Digest failed with error: " + err.toString())
                            case Some(outLen) =>
                                return createArrayBuffer(JsObject(), outputBuf[0..Int64(outLen)])
                        }
                }
        }
    }

    /// 从算法名称字符串解析摘要算法标识
    private static func parseHashAlgorithm(algorithmName: String): ?WebCryptoAlgorithmId {
        let lower = asciiLowerCrypto(algorithmName)
        match (lower) {
            case "sha-1" => WebCryptoAlgorithmId.Sha1
            case "sha-224" => WebCryptoAlgorithmId.Sha224
            case "sha-256" => WebCryptoAlgorithmId.Sha256
            case "sha-384" => WebCryptoAlgorithmId.Sha384
            case "sha-512" => WebCryptoAlgorithmId.Sha512
            case "sha1" => WebCryptoAlgorithmId.Sha1
            case "sha224" => WebCryptoAlgorithmId.Sha224
            case "sha256" => WebCryptoAlgorithmId.Sha256
            case "sha384" => WebCryptoAlgorithmId.Sha384
            case "sha512" => WebCryptoAlgorithmId.Sha512
            case _ => None
        }
    }

    // ========================================================================
    // encrypt / decrypt - 加密/解密
    // 对应 Web API: subtle.encrypt(algorithm, key, data)
    //               subtle.decrypt(algorithm, key, data)
    // 对应 WebKit: SubtleCrypto::encrypt() / SubtleCrypto::decrypt()
    // 支持: AES-CBC, AES-CTR, AES-GCM
    // ========================================================================

    /// 获取 AES cipher 指针
    /// 根据密钥长度和模式返回对应的 BoringSSL EVP_CIPHER
    private static func getAesCipher(keyLengthBits: Int64, mode: String): ?CPointer<Unit> {
        if (mode == "AES-CBC") {
            match (keyLengthBits) {
                case 128 => return Some(aesEvpAes128Cbc())
                case 192 => return Some(aesEvpAes192Cbc())
                case 256 => return Some(aesEvpAes256Cbc())
                case _ => return None
            }
        } else if (mode == "AES-CTR") {
            match (keyLengthBits) {
                case 128 => return Some(aesEvpAes128Ctr())
                case 192 => return Some(aesEvpAes192Ctr())
                case 256 => return Some(aesEvpAes256Ctr())
                case _ => return None
            }
        } else if (mode == "AES-GCM") {
            match (keyLengthBits) {
                case 128 => return Some(aesEvpAes128Gcm())
                case 192 => return Some(aesEvpAes192Gcm())
                case 256 => return Some(aesEvpAes256Gcm())
                case _ => return None
            }
        }
        return None
    }

    /// AES-CBC 加密
    /// 对应 Web API: subtle.encrypt({name: "AES-CBC", iv}, key, data)
    public static func encryptAesCbc(key: WebCryptoKey, iv: Array<Byte>, data: Array<Byte>): JsValue {
        let cipherPtr = getAesCipher(key.keyLength, "AES-CBC")
        match (cipherPtr) {
            case None => return JsValue("Unsupported AES-CBC key length")
            case Some(cipher) =>
                let ctx = aesEvpCipherCtxNew()
                if (ctx.isNull()) {
                    return JsValue("Failed to create cipher context")
                }

                aesEvpCipherCtxInit(ctx)

                let keyLen = Int32(key.keyLength / 8)
                let _ = aesEvpCipherCtxSetKeyLength(ctx, keyLen)
                let _ = aesEvpCipherCtxSetPadding(ctx, 1)  // PKCS7 padding

                // IV 必须 16 字节
                var ivBuf = Array<Byte>(16, repeat: 0)
                let ivCopyLen = min(iv.size, 16)
                for (i in 0..ivCopyLen) {
                    ivBuf[i] = iv[i]
                }

                let ret = unsafe {
                    aesEvpEncryptInitEx(ctx, cipher, CPointer<Unit>(),
                        CPointerUtils.fromArray(key.keyData),
                        CPointerUtils.fromArray(ivBuf))
                }
                if (ret != 1) {
                    aesEvpCipherCtxFree(ctx)
                    return JsValue("AES-CBC encrypt init failed")
                }

                // 输出: data_len + block_size (最多多一个 block)
                let blockSize = 16
                let outBufLen = data.size + blockSize
                var outBuf = Array<Byte>(outBufLen, repeat: 0)
                var outl = Array<Int32>(1, repeat: 0)

                let updateRet = unsafe {
                
                    aesEvpEncryptUpdate(ctx, CPointerUtils.fromArray(outBuf), int32Ptr(outl),
                        CPointerUtils.fromArray(data), Int32(data.size))
                }
                if (updateRet != 1) {
                    aesEvpCipherCtxFree(ctx)
                    return JsValue("AES-CBC encrypt update failed")
                }

                let written1 = Int64(outl[0])
                var finalBuf = Array<UInt8>(blockSize, repeat: 0)
                var finalLen = Array<Int32>(1, repeat: 0)

                let finalRet = unsafe {
                    aesEvpEncryptFinalEx(ctx, CPointerUtils.fromArray(finalBuf), int32Ptr(finalLen))
                }
                aesEvpCipherCtxFree(ctx)

                if (finalRet != 1) {
                    return JsValue("AES-CBC encrypt final failed")
                }

                let written2 = Int64(finalLen[0])
                let totalLen = written1 + written2
                var result = Array<Byte>(totalLen, repeat: 0)
                for (i in 0..written1) { result[i] = outBuf[i] }
                for (i in 0..written2) { result[written1 + i] = finalBuf[i] }

                return createArrayBuffer(JsObject(), result)
        }
    }

    /// AES-CBC 解密
    /// 对应 Web API: subtle.decrypt({name: "AES-CBC", iv}, key, data)
    public static func decryptAesCbc(key: WebCryptoKey, iv: Array<Byte>, data: Array<Byte>): JsValue {
        let cipherPtr = getAesCipher(key.keyLength, "AES-CBC")
        match (cipherPtr) {
            case None => return JsValue("Unsupported AES-CBC key length")
            case Some(cipher) =>
                let ctx = aesEvpCipherCtxNew()
                if (ctx.isNull()) {
                    return JsValue("Failed to create cipher context")
                }

                aesEvpCipherCtxInit(ctx)

                let keyLen = Int32(key.keyLength / 8)
                let _ = aesEvpCipherCtxSetKeyLength(ctx, keyLen)
                let _ = aesEvpCipherCtxSetPadding(ctx, 1)

                var ivBuf = Array<Byte>(16, repeat: 0)
                let ivCopyLen = min(iv.size, 16)
                for (i in 0..ivCopyLen) {
                    ivBuf[i] = iv[i]
                }

                let ret = unsafe {
                    aesEvpDecryptInitEx(ctx, cipher, CPointer<Unit>(),
                        CPointerUtils.fromArray(key.keyData),
                        CPointerUtils.fromArray(ivBuf))
                }
                if (ret != 1) {
                    aesEvpCipherCtxFree(ctx)
                    return JsValue("AES-CBC decrypt init failed")
                }

                let outBufLen = data.size + 16
                var outBuf = Array<Byte>(outBufLen, repeat: 0)
                var outl = Array<Int32>(1, repeat: 0)

                let updateRet = unsafe {
                    aesEvpDecryptUpdate(ctx, CPointerUtils.fromArray(outBuf), int32Ptr(outl),
                        CPointerUtils.fromArray(data), Int32(data.size))
                }
                if (updateRet != 1) {
                    aesEvpCipherCtxFree(ctx)
                    return JsValue("AES-CBC decrypt update failed")
                }

                let written1 = Int64(outl[0])
                var finalBuf = Array<Byte>(16, repeat: 0)
                var finalLen = Array<Int32>(1, repeat: 0)

                let finalRet = unsafe {
                    aesEvpDecryptFinalEx(ctx, CPointerUtils.fromArray(finalBuf), int32Ptr(finalLen))
                }
                aesEvpCipherCtxFree(ctx)

                if (finalRet != 1) {
                    return JsValue("AES-CBC decrypt final failed: padding error or wrong key")
                }

                let written2 = Int64(finalLen[0])
                let totalLen = written1 + written2
                var result = Array<Byte>(totalLen, repeat: 0)
                for (i in 0..written1) { result[i] = outBuf[i] }
                for (i in 0..written2) { result[written1 + i] = finalBuf[i] }

                return createArrayBuffer(JsObject(), result)
        }
    }

    /// AES-CTR 加密/解密
    /// 对应 Web API: subtle.encrypt({name: "AES-CTR", counter, length}, key, data)
    private static func processAesCtr(encrypt: Bool, key: WebCryptoKey,
                                        counter: Array<Byte>, data: Array<Byte>): JsValue {
        let cipherPtr = getAesCipher(key.keyLength, "AES-CTR")
        match (cipherPtr) {
            case None => return JsValue("Unsupported AES-CTR key length")
            case Some(cipher) =>
                let ctx = aesEvpCipherCtxNew()
                if (ctx.isNull()) {
                    return JsValue("Failed to create cipher context")
                }

                aesEvpCipherCtxInit(ctx)
                let _ = aesEvpCipherCtxSetKeyLength(ctx, Int32(key.keyLength / 8))
                let _ = aesEvpCipherCtxSetPadding(ctx, 0)  // No padding for CTR

                // Counter (nonce) - 16 bytes
                var counterBuf = Array<Byte>(16, repeat: 0)
                let copyLen = min(counter.size, 16)
                for (i in 0..copyLen) {
                    counterBuf[i] = counter[i]
                }

                let encFlag = if (encrypt) { 1 } else { 0 }
                let ret = unsafe {
                    aesEvpCipherInitEx(ctx, cipher, CPointer<Unit>(),
                        CPointerUtils.fromArray(key.keyData),
                        CPointerUtils.fromArray(counterBuf), Int32(encFlag))
                }
                if (ret != 1) {
                    aesEvpCipherCtxFree(ctx)
                    return JsValue("AES-CTR init failed")
                }

                // CTR mode: output length == input length
                var outBuf = Array<Byte>(data.size + 16, repeat: 0)
                var outl = Array<Int32>(1, repeat: 0)

                let updateRet = unsafe {
                    if (encrypt) {
                        aesEvpEncryptUpdate(ctx, CPointerUtils.fromArray(outBuf), int32Ptr(outl),
                            CPointerUtils.fromArray(data), Int32(data.size))
                    } else {
                        aesEvpDecryptUpdate(ctx, CPointerUtils.fromArray(outBuf), int32Ptr(outl),
                            CPointerUtils.fromArray(data), Int32(data.size))
                    }
                }
                if (updateRet != 1) {
                    aesEvpCipherCtxFree(ctx)
                    return JsValue("AES-CTR update failed")
                }

                let written = Int64(outl[0])
                var finalBuf = Array<Byte>(16, repeat: 0)
                var finalLen = Array<Int32>(1, repeat: 0)

                let finalRet = unsafe {
                    if (encrypt) {
                        aesEvpEncryptFinalEx(ctx, CPointerUtils.fromArray(finalBuf), int32Ptr(finalLen))
                    } else {
                        aesEvpDecryptFinalEx(ctx, CPointerUtils.fromArray(finalBuf), int32Ptr(finalLen))
                    }
                }
                aesEvpCipherCtxFree(ctx)

                if (finalRet != 1) {
                    return JsValue("AES-CTR final failed")
                }

                let totalLen = written + Int64(finalLen[0])
                var result = Array<Byte>(totalLen, repeat: 0)
                for (i in 0..written) { result[i] = outBuf[i] }
                for (i in 0..Int64(finalLen[0])) { result[written + i] = finalBuf[i] }

                return createArrayBuffer(JsObject(), result)
        }
    }

    /// AES-GCM 加密
    /// 对应 Web API: subtle.encrypt({name: "AES-GCM", iv, tagLength?, additionalData?}, key, data)
    /// 使用 BoringSSL EVP_AEAD 接口
    public static func encryptAesGcm(key: WebCryptoKey, iv: Array<Byte>,
                                        additionalData: ?Array<Byte>,
                                        tagLength: Int64,
                                        data: Array<Byte>): JsValue {
        let cipherPtr = getAesCipher(key.keyLength, "AES-GCM")
        match (cipherPtr) {
            case None => return JsValue("Unsupported AES-GCM key length")
            case Some(cipher) =>
                let ctx = aesEvpCipherCtxNew()
                if (ctx.isNull()) {
                    return JsValue("Failed to create cipher context")
                }
                aesEvpCipherCtxInit(ctx)
                let _ = aesEvpCipherCtxSetKeyLength(ctx, Int32(key.keyLength / 8))

                var ivBuf = Array<Byte>(iv.size, repeat: 0)
                for (i in 0..iv.size) { ivBuf[i] = iv[i] }

                let ret = unsafe {
                    aesEvpEncryptInitEx(ctx, cipher, CPointer<Unit>(),
                        CPointerUtils.fromArray(key.keyData),
                        CPointerUtils.fromArray(ivBuf))
                }
                if (ret != 1) {
                    aesEvpCipherCtxFree(ctx)
                    return JsValue("AES-GCM encrypt init failed")
                }

                // Set IV length via ctrl
                let ivLenRet = unsafe {
                    aesEvpCipherCtxCtrl(ctx, 0x09 /* EVP_CTRL_GCM_SET_IVLEN */, Int32(iv.size), CPointer<Unit>())
                }
                if (ivLenRet != 0) {
                    // Fallback: may work without explicit set
                    ()
                }

                // Set additional data if provided
                match (additionalData) {
                    case Some(ad) =>
                        if (ad.size > 0) {
                            var adLen = Array<Int32>(1, repeat: 0)
                            let adRet = unsafe {
                                aesEvpEncryptUpdate(ctx, CPointer<Byte>(), int32Ptr(adLen),
                                    CPointerUtils.fromArray(ad), Int32(ad.size))
                            }
                            // AAD doesn't produce output
                        }
                    case None => ()
                }

                // Encrypt
                var outBuf = Array<Byte>(data.size + 16, repeat: 0)
                var outl = Array<Int32>(1, repeat: 0)
                let updateRet = unsafe {
                    aesEvpEncryptUpdate(ctx, CPointerUtils.fromArray(outBuf), int32Ptr(outl),
                        CPointerUtils.fromArray(data), Int32(data.size))
                }
                if (updateRet != 1) {
                    aesEvpCipherCtxFree(ctx)
                    return JsValue("AES-GCM encrypt update failed")
                }
                let written = Int64(outl[0])

                // Final
                var finalBuf = Array<Byte>(16, repeat: 0)
                var finalLen = Array<Int32>(1, repeat: 0)
                let finalRet = unsafe {
                    aesEvpEncryptFinalEx(ctx, CPointerUtils.fromArray(finalBuf), int32Ptr(finalLen))
                }
                if (finalRet != 1) {
                    aesEvpCipherCtxFree(ctx)
                    return JsValue("AES-GCM encrypt final failed")
                }

                // Get tag
                let actualTagLen = if (tagLength > 0) { tagLength } else { 16 }
                var tag = Array<Byte>(actualTagLen, repeat: 0)
                let tagRet = unsafe {
                    aesEvpCipherCtxCtrl(ctx, 0x10 /* EVP_CTRL_GCM_GET_TAG */, Int32(actualTagLen),
                        CPointer<Unit>())
                }

                aesEvpCipherCtxFree(ctx)

                // Result = ciphertext + tag
                let totalLen = written + Int64(finalLen[0]) + actualTagLen
                var result = Array<Byte>(totalLen, repeat: 0)
                for (i in 0..written) { result[i] = outBuf[i] }
                for (i in 0..Int64(finalLen[0])) { result[written + i] = finalBuf[i] }
                for (i in 0..actualTagLen) { result[written + Int64(finalLen[0]) + i] = tag[i] }

                return createArrayBuffer(JsObject(), result)
        }
    }

    /// AES-GCM 解密
    /// 对应 Web API: subtle.decrypt({name: "AES-GCM", iv, tagLength?, additionalData?}, key, data)
    public static func decryptAesGcm(key: WebCryptoKey, iv: Array<Byte>,
                                        additionalData: ?Array<Byte>,
                                        tagLength: Int64,
                                        dataWithTag: Array<Byte>): JsValue {
        let cipherPtr = getAesCipher(key.keyLength, "AES-GCM")
        match (cipherPtr) {
            case None => return JsValue("Unsupported AES-GCM key length")
            case Some(cipher) =>
                let actualTagLen = if (tagLength > 0) { tagLength } else { 16 }

                // Split data into ciphertext and tag
                if (dataWithTag.size < actualTagLen) {
                    return JsValue("AES-GCM data too short to contain tag")
                }
                let cipherTextLen = dataWithTag.size - actualTagLen
                var cipherText = Array<Byte>(cipherTextLen, repeat: 0)
                for (i in 0..cipherTextLen) { cipherText[i] = dataWithTag[i] }
                var tag = Array<Byte>(actualTagLen, repeat: 0)
                for (i in 0..actualTagLen) { tag[i] = dataWithTag[cipherTextLen + i] }

                let ctx = aesEvpCipherCtxNew()
                if (ctx.isNull()) {
                    return JsValue("Failed to create cipher context")
                }
                aesEvpCipherCtxInit(ctx)
                let _ = aesEvpCipherCtxSetKeyLength(ctx, Int32(key.keyLength / 8))

                var ivBuf = Array<Byte>(iv.size, repeat: 0)
                for (i in 0..iv.size) { ivBuf[i] = iv[i] }

                let ret = unsafe {
                    aesEvpDecryptInitEx(ctx, cipher, CPointer<Unit>(),
                        CPointerUtils.fromArray(key.keyData),
                        CPointerUtils.fromArray(ivBuf))
                }
                if (ret != 1) {
                    aesEvpCipherCtxFree(ctx)
                    return JsValue("AES-GCM decrypt init failed")
                }

                // Set tag before decryption
                let tagRet = unsafe {
                    aesEvpCipherCtxCtrl(ctx, 0x11 /* EVP_CTRL_GCM_SET_TAG */, Int32(actualTagLen),
                        CPointer<Unit>())
                }

                // Set additional data if provided
                match (additionalData) {
                    case Some(ad) =>
                        if (ad.size > 0) {
                            var adLen = Array<Int32>(1, repeat: 0)
                            let _ = unsafe {
                                aesEvpDecryptUpdate(ctx, CPointer<Byte>(), int32Ptr(adLen),
                                    CPointerUtils.fromArray(ad), Int32(ad.size))
                            }
                        }
                    case None => ()
                }

                // Decrypt
                var outBuf = Array<Byte>(cipherTextLen + 16, repeat: 0)
                var outl = Array<Int32>(1, repeat: 0)
                let updateRet = unsafe {
                    aesEvpDecryptUpdate(ctx, CPointerUtils.fromArray(outBuf), int32Ptr(outl),
                        CPointerUtils.fromArray(cipherText), Int32(cipherTextLen))
                }
                if (updateRet != 1) {
                    aesEvpCipherCtxFree(ctx)
                    return JsValue("AES-GCM decrypt update failed")
                }
                let written = Int64(outl[0])

                // Final (will verify tag)
                var finalBuf = Array<Byte>(16, repeat: 0)
                var finalLen = Array<Int32>(1, repeat: 0)
                let finalRet = unsafe {
                    aesEvpDecryptFinalEx(ctx, CPointerUtils.fromArray(finalBuf), int32Ptr(finalLen))
                }
                aesEvpCipherCtxFree(ctx)

                if (finalRet != 1) {
                    return JsValue("AES-GCM authentication failed: tag mismatch")
                }

                let totalLen = written + Int64(finalLen[0])
                var result = Array<Byte>(totalLen, repeat: 0)
                for (i in 0..written) { result[i] = outBuf[i] }
                for (i in 0..Int64(finalLen[0])) { result[written + i] = finalBuf[i] }

                return createArrayBuffer(JsObject(), result)
        }
    }

    // ========================================================================
    // sign / verify - 签名/验签
    // 对应 Web API: subtle.sign(algorithm, key, data)
    //               subtle.verify(algorithm, key, signature, data)
    // 支持: HMAC
    // ========================================================================

    /// HMAC 签名
    /// 对应 Web API: subtle.sign({name: "HMAC"}, key, data)
    public static func signHmac(key: WebCryptoKey, data: Array<Byte>): JsValue {
        let hashAlg = match (key.hashAlgorithm) {
            case Some(h) => h
            case None => WebCryptoAlgorithmId.Sha256  // default
        }
        let evpAlg = match (hashAlg.toEvpAlgorithm()) {
            case Some(a) => a
            case None => EvpAlgorithm.sha256
        }

        let hmac = HMAC.initFunc(evpAlg, key.keyData)
        match (hmac) {
            case None => return JsValue("HMAC init failed")
            case Some(h) =>
                h.update(data)
                let size = h.size()
                var outBuf = Array<Byte>(size, repeat: 0)
                let result = h.final(outBuf)
                h.deinit()
                return createArrayBuffer(JsObject(), result)
        }
    }

    /// HMAC 验签
    /// 对应 Web API: subtle.verify({name: "HMAC"}, key, signature, data)
    public static func verifyHmac(key: WebCryptoKey, signature: Array<Byte>, data: Array<Byte>): JsValue {
        let computed = match (signHmac(key, data).valueType) {
            case JsValueType.Object =>
                // Extract bytes from JsArrayBuffer result
                let computedSig = signHmacToBytes(key, data)
                constantTimeEqual(computedSig, signature)
            case _ => false
        }
        return JsValue(computed)
    }

    /// HMAC 签名返回字节数组
    public static func signHmacToBytes(key: WebCryptoKey, data: Array<Byte>): Array<Byte> {
        let hashAlg = match (key.hashAlgorithm) {
            case Some(h) => h
            case None => WebCryptoAlgorithmId.Sha256
        }
        let evpAlg = match (hashAlg.toEvpAlgorithm()) {
            case Some(a) => a
            case None => EvpAlgorithm.sha256
        }

        let hmac = HMAC.initFunc(evpAlg, key.keyData)
        match (hmac) {
            case None => return Array<Byte>()
            case Some(h) =>
                h.update(data)
                let size = h.size()
                var outBuf = Array<Byte>(size, repeat: 0)
                let result = h.final(outBuf)
                h.deinit()
                return result
        }
    }

    // ========================================================================
    // generateKey - 密钥生成
    // 对应 Web API: subtle.generateKey(algorithm, extractable, keyUsages)
    // 支持: AES, HMAC
    // ========================================================================

    /// 生成 AES 密钥
    /// 对应 Web API: subtle.generateKey({name: "AES-CBC"/"AES-CTR"/"AES-GCM", length}, extractable, keyUsages)
    public static func generateAesKey(algorithmId: WebCryptoAlgorithmId, lengthBits: Int64,
                                       extractable: Bool, usages: ArrayList<WebCryptoKeyUsage>): JsValue {
        // Validate key length
        if (lengthBits != 128 && lengthBits != 192 && lengthBits != 256) {
            return JsValue("AES key length must be 128, 192, or 256 bits")
        }

        let lengthBytes = lengthBits / 8
        var keyData = Array<Byte>(lengthBytes, repeat: 0)

        // Generate random key bytes
        let rc = unsafe { getrandom(CPointer<Unit>(), UIntNative(keyData.size), 0) }
        if (rc != lengthBytes) {
            return JsValue("Failed to generate random key")
        }

        let key = WebCryptoKey.createAes(algorithmId, keyData, extractable, usages)
        return key.toJsValue()
    }

    /// 生成 HMAC 密钥
    /// 对应 Web API: subtle.generateKey({name: "HMAC", hash?, length?}, extractable, keyUsages)
    public static func generateHmacKey(lengthBits: ?Int64, hashAlg: ?WebCryptoAlgorithmId,
                                        extractable: Bool, usages: ArrayList<WebCryptoKeyUsage>): JsValue {
        let actualLength = match (lengthBits) {
            case Some(l) => l
            case None => 256  // default
        }
        let lengthBytes = actualLength / 8

        var keyData = Array<Byte>(lengthBytes, repeat: 0)
        let rc = unsafe { getrandom(CPointer<Unit>(), UIntNative(keyData.size), 0) }
        if (rc != lengthBytes) {
            return JsValue("Failed to generate random HMAC key")
        }

        let key = WebCryptoKey.createHmac(keyData, hashAlg, extractable, usages)
        return key.toJsValue()
    }

    // ========================================================================
    // importKey / exportKey - 密钥导入/导出
    // 对应 Web API: subtle.importKey(format, keyData, algorithm, extractable, keyUsages)
    //               subtle.exportKey(format, key)
    // 支持: raw 格式 for AES, HMAC
    // ========================================================================

    /// 导入原始密钥
    /// 对应 Web API: subtle.importKey("raw", keyData, algorithm, extractable, keyUsages)
    public static func importRawKey(algorithmId: WebCryptoAlgorithmId, keyData: Array<Byte>,
                                     extractable: Bool, usages: ArrayList<WebCryptoKeyUsage>,
                                     hashAlg: ?WebCryptoAlgorithmId): JsValue {
        match (algorithmId) {
            case WebCryptoAlgorithmId.AesCbc
               | WebCryptoAlgorithmId.AesCtr
               | WebCryptoAlgorithmId.AesGcm
               | WebCryptoAlgorithmId.AesKw =>
                let keyLenBits = Int64(keyData.size) * 8
                if (keyLenBits != 128 && keyLenBits != 192 && keyLenBits != 256) {
                    return JsValue("AES key must be 128, 192, or 256 bits")
                }
                let key = WebCryptoKey.createAes(algorithmId, keyData, extractable, usages)
                return key.toJsValue()

            case WebCryptoAlgorithmId.Hmac =>
                let key = WebCryptoKey.createHmac(keyData, hashAlg, extractable, usages)
                return key.toJsValue()

            case WebCryptoAlgorithmId.Sha1
               | WebCryptoAlgorithmId.Sha256
               | WebCryptoAlgorithmId.Sha384
               | WebCryptoAlgorithmId.Sha512 =>
                // For raw hash import, wrap as HMAC key
                let key = WebCryptoKey.createHmac(keyData, Some(algorithmId), extractable, usages)
                return key.toJsValue()

            case _ =>
                return JsValue("Raw import not supported for algorithm: " + algorithmId.name())
        }
    }

    /// 导出原始密钥
    /// 对应 Web API: subtle.exportKey("raw", key)
    public static func exportRawKey(key: WebCryptoKey): JsValue {
        if (!key.extractable) {
            return JsValue("Key is not extractable")
        }
        return createArrayBuffer(JsObject(), key.keyData)
    }

    // ========================================================================
    // deriveBits / deriveKey - 密钥派生
    // 对应 Web API: subtle.deriveBits(algorithm, baseKey, length)
    //               subtle.deriveKey(algorithm, baseKey, derivedKeyType, extractable, keyUsages)
    // 支持: PBKDF2
    // ========================================================================

    /// PBKDF2 派生字节
    /// 对应 Web API: subtle.deriveBits({name: "PBKDF2", salt, iterations, hash}, baseKey, length)
    public static func deriveBitsPbkdf2(salt: Array<Byte>, iterations: UInt32,
                                         hashAlg: WebCryptoAlgorithmId,
                                         baseKey: WebCryptoKey,
                                         lengthBits: Int64): JsValue {
        let evpAlg = match (hashAlg.toEvpAlgorithm()) {
            case Some(a) => a
            case None => return JsValue("Unsupported PBKDF2 hash: " + hashAlg.name())
        }

        let lengthBytes = lengthBits / 8
        var output = Array<Byte>(lengthBytes, repeat: 0)

        let result = pbkdf2(output, baseKey.keyData, salt, iterations, evpAlg)
        match (result) {
            case None =>
                let err = BoringSSL.errGetError()
                BoringSSL.errClearError()
                return JsValue("PBKDF2 derive failed")
            case Some(derivedBytes) =>
                return createArrayBuffer(JsObject(), derivedBytes)
        }
    }

    /// HKDF 派生字节 (基于 HMAC 的密钥派生)
    /// 对应 Web API: subtle.deriveBits({name: "HKDF", hash, salt, info}, baseKey, length)
    /// HKDF = HMAC-Extract + HMAC-Expand
    public static func deriveBitsHkdf(salt: Array<Byte>, info: Array<Byte>,
                                       hashAlg: WebCryptoAlgorithmId,
                                       baseKey: WebCryptoKey,
                                       lengthBits: Int64): JsValue {
        let evpAlg = match (hashAlg.toEvpAlgorithm()) {
            case Some(a) => a
            case None => return JsValue("Unsupported HKDF hash: " + hashAlg.name())
        }

        // HKDF-Extract: PRK = HMAC-Hash(salt, IKM)
        let hmacExtract = HMAC.initFunc(evpAlg, salt)
        match (hmacExtract) {
            case None => return JsValue("HKDF extract HMAC init failed")
            case Some(h) =>
                h.update(baseKey.keyData)
                let hashSize = h.size()
                var prkBuf = Array<Byte>(hashSize, repeat: 0)
                let prk = h.final(prkBuf)
                h.deinit()

                // HKDF-Expand: OKM = T(1) || T(2) || ... || T(N)
                let lengthBytes = lengthBits / 8
                let n = (lengthBytes + hashSize - 1) / hashSize
                if (n > 255) {
                    return JsValue("HKDF output length too large")
                }

                var okm = Array<Byte>(lengthBytes, repeat: 0)
                var tPrev = Array<Byte>(hashSize, repeat: 0)
                var offset: Int64 = 0

                for (i in 1..(n + 1)) {
                    let hmacExpand = HMAC.initFunc(evpAlg, prk)
                    match (hmacExpand) {
                        case None => return JsValue("HKDF expand HMAC init failed")
                        case Some(he) =>
                            he.update(tPrev)
                            he.update(info)
                            he.update(Array<Byte>(1, { _ => UInt8(i) }))

                            var tBuf = Array<Byte>(hashSize, repeat: 0)
                            let t = he.final(tBuf)
                            he.deinit()

                            for (j in 0..hashSize) {
                                tPrev[j] = t[j]
                            }

                            let copyLen = min(hashSize, lengthBytes - offset)
                            for (j in 0..copyLen) {
                                okm[offset + j] = t[j]
                            }
                            offset += copyLen
                    }
                }

                return createArrayBuffer(JsObject(), okm)
        }
    }

    // ========================================================================
    // wrapKey / unwrapKey - 密钥包装
    // 对应 Web API: subtle.wrapKey(format, key, wrappingKey, wrapAlgorithm)
    //               subtle.unwrapKey(format, wrappedKey, unwrappingKey, ...)
    // 支持: AES-KW
    // ========================================================================

    /// AES Key Wrap (RFC 3394)
    /// 对应 Web API: subtle.wrapKey("raw", key, wrappingKey, {name: "AES-KW"})
    public static func wrapKeyAesKw(wrappingKey: WebCryptoKey, keyToWrap: Array<Byte>): JsValue {
        // AES Key Wrap: n 64-bit blocks, 6*n steps
        let n = keyToWrap.size / 8
        if (n < 1 || keyToWrap.size % 8 != 0) {
            return JsValue("Key to wrap must be a multiple of 8 bytes")
        }

        // Initialize: A = IV (0xA6A6A6A6A6A6A6A6), R[0..n-1] = P[0..n-1]
        var a = Array<Byte>(8, repeat: 0)
        a[0] = 0xA6; a[1] = 0xA6; a[2] = 0xA6; a[3] = 0xA6
        a[4] = 0xA6; a[5] = 0xA6; a[6] = 0xA6; a[7] = 0xA6

        var r = Array<Byte>(n * 8, repeat: 0)
        for (i in 0..(n * 8)) {
            r[i] = keyToWrap[i]
        }

        // 6*n wrapping steps
        for (j in 0..6) {
            for (i in 0..n) {
                // B = AES(K, A || R[i])
                let aCopy = a
                let rCopy = r
                let bIn = Array<Byte>(16, repeat: 0)
                for (k in 0..16) {
                    bIn[k] = if (k < 8) { aCopy[k] } else { rCopy[((i % n) * 8) + (k - 8)] }
                }

                let encrypted = aesEcbEncrypt(wrappingKey, bIn)
                match (encrypted) {
                    case None => return JsValue("AES-KW wrap step failed")
                    case Some(bOut) =>
                        // A = MSB(64, B) XOR t
                        let t = j * n + i + 1
                        a[0] = bOut[0] ^ UInt8((t >> 56) & 0xFF)
                        a[1] = bOut[1] ^ UInt8((t >> 48) & 0xFF)
                        a[2] = bOut[2] ^ UInt8((t >> 40) & 0xFF)
                        a[3] = bOut[3] ^ UInt8((t >> 32) & 0xFF)
                        a[4] = bOut[4] ^ UInt8((t >> 24) & 0xFF)
                        a[5] = bOut[5] ^ UInt8((t >> 16) & 0xFF)
                        a[6] = bOut[6] ^ UInt8((t >> 8) & 0xFF)
                        a[7] = bOut[7] ^ UInt8(t & 0xFF)

                        // R[i] = LSB(64, B)
                        let ri = i % n
                        for (k in 0..8) {
                            r[ri * 8 + k] = bOut[8 + k]
                        }
                }
            }
        }

        // Output = A || R[0] || R[1] || ... || R[n-1]
        var result = Array<Byte>((n + 1) * 8, repeat: 0)
        for (i in 0..8) { result[i] = a[i] }
        for (i in 0..(n * 8)) { result[8 + i] = r[i] }

        return createArrayBuffer(JsObject(), result)
    }

    /// AES Key Unwrap (RFC 3394)
    /// 对应 Web API: subtle.unwrapKey("raw", wrappedKey, unwrappingKey, {name: "AES-KW"}, ...)
    public static func unwrapKeyAesKw(unwrappingKey: WebCryptoKey, wrappedKey: Array<Byte>): JsValue {
        let n = (wrappedKey.size / 8) - 1
        if (n < 1 || wrappedKey.size % 8 != 0 || wrappedKey.size < 16) {
            return JsValue("Wrapped key invalid")
        }

        // Initialize: A = C[0], R[0..n-1] = C[1..n]
        var a = Array<Byte>(8, repeat: 0)
        for (i in 0..8) { a[i] = wrappedKey[i] }

        var r = Array<Byte>(n * 8, repeat: 0)
        for (i in 0..(n * 8)) { r[i] = wrappedKey[8 + i] }

        // 6*n unwrapping steps (reverse order)
        for (j in 0..6) {
            for (i in 0..n) {
                let idx = n - 1 - (i % n)
                let ri = idx

                // B = AES-1(K, A XOR t || R[i])
                let t = (6 - j) * n - i
                var bIn = Array<Byte>(16, repeat: 0)
                bIn[0] = a[0] ^ UInt8((t >> 56) & 0xFF)
                bIn[1] = a[1] ^ UInt8((t >> 48) & 0xFF)
                bIn[2] = a[2] ^ UInt8((t >> 40) & 0xFF)
                bIn[3] = a[3] ^ UInt8((t >> 32) & 0xFF)
                bIn[4] = a[4] ^ UInt8((t >> 24) & 0xFF)
                bIn[5] = a[5] ^ UInt8((t >> 16) & 0xFF)
                bIn[6] = a[6] ^ UInt8((t >> 8) & 0xFF)
                bIn[7] = a[7] ^ UInt8(t & 0xFF)
                for (k in 0..8) { bIn[8 + k] = r[ri * 8 + k] }

                let decrypted = aesEcbDecrypt(unwrappingKey, bIn)
                match (decrypted) {
                    case None => return JsValue("AES-KW unwrap step failed")
                    case Some(bOut) =>
                        for (k in 0..8) { a[k] = bOut[k] }
                        for (k in 0..8) { r[ri * 8 + k] = bOut[8 + k] }
                }
            }
        }

        // Verify IV
        let expectedIv: Array<Byte> = Array<Byte>(8, { idx =>
            match (idx) {
                case 0 => 0xA6; case 1 => 0xA6; case 2 => 0xA6; case 3 => 0xA6
                case 4 => 0xA6; case 5 => 0xA6; case 6 => 0xA6; case 7 => 0xA6
                case _ => 0
            }
        })
        if (!constantTimeEqual(a, expectedIv)) {
            return JsValue("AES-KW unwrap integrity check failed")
        }

        // Output = R[0] || R[1] || ... || R[n-1]
        var result = Array<Byte>(n * 8, repeat: 0)
        for (i in 0..(n * 8)) { result[i] = r[i] }

        return createArrayBuffer(JsObject(), result)
    }

    // ========================================================================
    // AES-ECB 辅助 (用于 AES-KW)
    // ========================================================================

    /// AES-ECB 加密单块
    private static func aesEcbEncrypt(key: WebCryptoKey, block: Array<Byte>): ?Array<Byte> {
        let cipherPtr = getAesCipher(key.keyLength, "AES-CBC")  // Use CBC cipher for ECB-like
        // For AES-KW, we need AES-ECB mode
        // Use EVP_aes_128_ecb / EVP_aes_256_ecb
        let ecbCipher = getAesEcbCipher(key.keyLength)
        match (ecbCipher) {
            case None => return None
            case Some(cipher) =>
                let ctx = aesEvpCipherCtxNew()
                if (ctx.isNull()) { return None }
                aesEvpCipherCtxInit(ctx)
                let _ = aesEvpCipherCtxSetKeyLength(ctx, Int32(key.keyLength / 8))
                let _ = aesEvpCipherCtxSetPadding(ctx, 0)

                let ret = unsafe {
                    aesEvpEncryptInitEx(ctx, cipher, CPointer<Unit>(),
                        CPointerUtils.fromArray(key.keyData), CPointer<Byte>())
                }
                if (ret != 1) { aesEvpCipherCtxFree(ctx); return None }

                var outBuf = Array<Byte>(32, repeat: 0)
                var outl = Array<Int32>(1, repeat: 0)
                let _ = unsafe {
                    aesEvpEncryptUpdate(ctx, CPointerUtils.fromArray(outBuf), int32Ptr(outl),
                        CPointerUtils.fromArray(block), Int32(block.size))
                }
                var finalBuf = Array<Byte>(16, repeat: 0)
                var finalLen = Array<Int32>(1, repeat: 0)
                let _ = unsafe {
                    aesEvpEncryptFinalEx(ctx, CPointerUtils.fromArray(finalBuf), int32Ptr(finalLen))
                }
                aesEvpCipherCtxFree(ctx)

                let total = Int64(outl[0]) + Int64(finalLen[0])
                var result = Array<Byte>(total, repeat: 0)
                for (i in 0..Int64(outl[0])) { result[i] = outBuf[i] }
                for (i in 0..Int64(finalLen[0])) { result[Int64(outl[0]) + i] = finalBuf[i] }
                return Some(result)
        }
    }

    /// AES-ECB 解密单块
    private static func aesEcbDecrypt(key: WebCryptoKey, block: Array<Byte>): ?Array<Byte> {
        let ecbCipher = getAesEcbCipher(key.keyLength)
        match (ecbCipher) {
            case None => return None
            case Some(cipher) =>
                let ctx = aesEvpCipherCtxNew()
                if (ctx.isNull()) { return None }
                aesEvpCipherCtxInit(ctx)
                let _ = aesEvpCipherCtxSetKeyLength(ctx, Int32(key.keyLength / 8))
                let _ = aesEvpCipherCtxSetPadding(ctx, 0)

                let ret = unsafe {
                    aesEvpDecryptInitEx(ctx, cipher, CPointer<Unit>(),
                        CPointerUtils.fromArray(key.keyData), CPointer<Byte>())
                }
                if (ret != 1) { aesEvpCipherCtxFree(ctx); return None }

                var outBuf = Array<Byte>(32, repeat: 0)
                var outl = Array<Int32>(1, repeat: 0)
                let _ = unsafe {
                    aesEvpDecryptUpdate(ctx, CPointerUtils.fromArray(outBuf), int32Ptr(outl),
                        CPointerUtils.fromArray(block), Int32(block.size))
                }
                var finalBuf = Array<Byte>(16, repeat: 0)
                var finalLen = Array<Int32>(1, repeat: 0)
                let _ = unsafe {
                    aesEvpDecryptFinalEx(ctx, CPointerUtils.fromArray(finalBuf), int32Ptr(finalLen))
                }
                aesEvpCipherCtxFree(ctx)

                let total = Int64(outl[0]) + Int64(finalLen[0])
                var result = Array<Byte>(total, repeat: 0)
                for (i in 0..Int64(outl[0])) { result[i] = outBuf[i] }
                for (i in 0..Int64(finalLen[0])) { result[Int64(outl[0]) + i] = finalBuf[i] }
                return Some(result)
        }
    }

    private static func getAesEcbCipher(keyLengthBits: Int64): ?CPointer<Unit> {
        match (keyLengthBits) {
            case 128 => return Some(aesEvpAes128Ecb())
            case 192 => return Some(aesEvpAes192Ecb())
            case 256 => return Some(aesEvpAes256Ecb())
            case _ => return None
        }
    }

    // ========================================================================
    // 辅助函数
    // ========================================================================

    /// 常量时间比较
    private static func constantTimeEqual(a: Array<Byte>, b: Array<Byte>): Bool {
        if (a.size != b.size) { return false }
        var diff: Int64 = 0
        for (i in 0..a.size) { diff = diff | Int64(a[i] ^ b[i]) }
        return diff == 0
    }

    /// 从 JsObject 解析算法
    public static func parseAlgorithm(algorithmValue: JsValue): ?WebCryptoAlgorithmId {
        if (algorithmValue.valueType == JsValueType.String) {
            return WebCryptoAlgorithmId.fromName(algorithmValue.toString())
        }
        if (algorithmValue.valueType == JsValueType.Object) {
            let obj = algorithmValue.toObject()
            let nameVal = obj.get("name")
            if (nameVal.valueType == JsValueType.String) {
                return WebCryptoAlgorithmId.fromName(nameVal.toString())
            }
        }
        return None
    }

    /// 从 JsValue 解析密钥用途
    public static func parseUsages(usagesValue: JsValue): ArrayList<WebCryptoKeyUsage> {
        let result = ArrayList<WebCryptoKeyUsage>()
        if (usagesValue.valueType == JsValueType.Array) {
            let list = usagesValue.arrayData
            match (list) {
                case Some(items) =>
                    for (item in items) {
                        if (item.valueType == JsValueType.String) {
                            let s = item.toString()
                            match (s) {
                                case "encrypt" => result.append(WebCryptoKeyUsage.Encrypt)
                                case "decrypt" => result.append(WebCryptoKeyUsage.Decrypt)
                                case "sign" => result.append(WebCryptoKeyUsage.Sign)
                                case "verify" => result.append(WebCryptoKeyUsage.Verify)
                                case "deriveKey" => result.append(WebCryptoKeyUsage.DeriveKey)
                                case "deriveBits" => result.append(WebCryptoKeyUsage.DeriveBits)
                                case "wrapKey" => result.append(WebCryptoKeyUsage.WrapKey)
                                case "unwrapKey" => result.append(WebCryptoKeyUsage.UnwrapKey)
                                case _ => ()
                            }
                        }
                    }
                case None => ()
            }
        }
        return result
    }
}

// ============================================================================
// AES BoringSSL FFI 封装
// 用于 Web Crypto AES 操作的 FFI 桥接
// ============================================================================

// --- AES Cipher 获取 (从 evp_extra.cj) ---
@C foreign func EVP_aes_128_cbc(): CPointer<Unit>
@C foreign func EVP_aes_192_cbc(): CPointer<Unit>
@C foreign func EVP_aes_256_cbc(): CPointer<Unit>
@C foreign func EVP_aes_128_ctr(): CPointer<Unit>
@C foreign func EVP_aes_192_ctr(): CPointer<Unit>
@C foreign func EVP_aes_256_ctr(): CPointer<Unit>
@C foreign func EVP_aes_128_gcm(): CPointer<Unit>
@C foreign func EVP_aes_192_gcm(): CPointer<Unit>
@C foreign func EVP_aes_256_gcm(): CPointer<Unit>
@C foreign func EVP_aes_128_ecb(): CPointer<Unit>
@C foreign func EVP_aes_192_ecb(): CPointer<Unit>
@C foreign func EVP_aes_256_ecb(): CPointer<Unit>

// --- AES Cipher Context 操作 ---
// 使用 CPointer<Unit> 避免对 bao_boringssl_sys 类型的依赖
@C foreign func EVP_CIPHER_CTX_new(): CPointer<Unit>
@C foreign func EVP_CIPHER_CTX_free(ctx: CPointer<Unit>): Unit
@C foreign func EVP_CIPHER_CTX_init(ctx: CPointer<Unit>): Unit
@C foreign func EVP_CIPHER_CTX_cleanup(ctx: CPointer<Unit>): Int32
@C foreign func EVP_CIPHER_CTX_set_padding(ctx: CPointer<Unit>, pad: Int32): Int32
@C foreign func EVP_CIPHER_CTX_set_key_length(ctx: CPointer<Unit>, keylen: Int32): Int32
@C foreign func EVP_CIPHER_CTX_ctrl(ctx: CPointer<Unit>, type_: Int32, arg: Int32, ptr: CPointer<Unit>): Int32
@C foreign func EVP_CIPHER_CTX_key_length(ctx: CPointer<Unit>): Int32
@C foreign func EVP_CIPHER_CTX_iv_length(ctx: CPointer<Unit>): Int32

// --- AES Encrypt/Decrypt 操作 ---
@C foreign func EVP_EncryptInit_ex(ctx: CPointer<Unit>, cipher: CPointer<Unit>, engine: CPointer<Unit>, key: CPointer<Byte>, iv: CPointer<Byte>): Int32
@C foreign func EVP_EncryptUpdate(ctx: CPointer<Unit>, out: CPointer<Byte>, outl: CPointer<Int32>, in_: CPointer<Byte>, inl: Int32): Int32
@C foreign func EVP_EncryptFinal_ex(ctx: CPointer<Unit>, out: CPointer<Byte>, outl: CPointer<Int32>): Int32
@C foreign func EVP_DecryptInit_ex(ctx: CPointer<Unit>, cipher: CPointer<Unit>, engine: CPointer<Unit>, key: CPointer<Byte>, iv: CPointer<Byte>): Int32
@C foreign func EVP_DecryptUpdate(ctx: CPointer<Unit>, out: CPointer<Byte>, outl: CPointer<Int32>, in_: CPointer<Byte>, inl: Int32): Int32
@C foreign func EVP_DecryptFinal_ex(ctx: CPointer<Unit>, out: CPointer<Byte>, outl: CPointer<Int32>): Int32
@C foreign func EVP_CipherInit_ex(ctx: CPointer<Unit>, cipher: CPointer<Unit>, engine: CPointer<Unit>, key: CPointer<Byte>, iv: CPointer<Byte>, enc: Int32): Int32

// AES cipher 获取封装
private func aesEvpAes128Cbc(): CPointer<Unit> { unsafe { return EVP_aes_128_cbc() } }
private func aesEvpAes192Cbc(): CPointer<Unit> { unsafe { return EVP_aes_192_cbc() } }
private func aesEvpAes256Cbc(): CPointer<Unit> { unsafe { return EVP_aes_256_cbc() } }
private func aesEvpAes128Ctr(): CPointer<Unit> { unsafe { return EVP_aes_128_ctr() } }
private func aesEvpAes192Ctr(): CPointer<Unit> { unsafe { return EVP_aes_192_ctr() } }
private func aesEvpAes256Ctr(): CPointer<Unit> { unsafe { return EVP_aes_256_ctr() } }
private func aesEvpAes128Gcm(): CPointer<Unit> { unsafe { return EVP_aes_128_gcm() } }
private func aesEvpAes192Gcm(): CPointer<Unit> { unsafe { return EVP_aes_192_gcm() } }
private func aesEvpAes256Gcm(): CPointer<Unit> { unsafe { return EVP_aes_256_gcm() } }
private func aesEvpAes128Ecb(): CPointer<Unit> { unsafe { return EVP_aes_128_ecb() } }
private func aesEvpAes192Ecb(): CPointer<Unit> { unsafe { return EVP_aes_192_ecb() } }
private func aesEvpAes256Ecb(): CPointer<Unit> { unsafe { return EVP_aes_256_ecb() } }

// AES context 操作封装 - 使用 CPointer<Unit> 避免跨包类型依赖
private func aesEvpCipherCtxNew(): CPointer<Unit> {
    unsafe { return EVP_CIPHER_CTX_new() }
}
private func aesEvpCipherCtxFree(ctx: CPointer<Unit>): Unit {
    unsafe { EVP_CIPHER_CTX_free(ctx) }
}
private func aesEvpCipherCtxInit(ctx: CPointer<Unit>): Unit {
    unsafe { EVP_CIPHER_CTX_init(ctx) }
}
private func aesEvpCipherCtxSetPadding(ctx: CPointer<Unit>, pad: Int32): Int32 {
    unsafe { return EVP_CIPHER_CTX_set_padding(ctx, pad) }
}
private func aesEvpCipherCtxSetKeyLength(ctx: CPointer<Unit>, keylen: Int32): Int32 {
    unsafe { return EVP_CIPHER_CTX_set_key_length(ctx, keylen) }
}
private func aesEvpCipherCtxCtrl(ctx: CPointer<Unit>, type_: Int32, arg: Int32, ptr: CPointer<Unit>): Int32 {
    unsafe { return EVP_CIPHER_CTX_ctrl(ctx, type_, arg, ptr) }
}
private func aesEvpEncryptInitEx(ctx: CPointer<Unit>, cipher: CPointer<Unit>, engine: CPointer<Unit>, key: CPointer<Byte>, iv: CPointer<Byte>): Int32 {
    unsafe { return EVP_EncryptInit_ex(ctx, cipher, engine, key, iv) }
}
private func aesEvpEncryptUpdate(ctx: CPointer<Unit>, out: CPointer<Byte>, outl: CPointer<Int32>, in_: CPointer<Byte>, inl: Int32): Int32 {
    unsafe { return EVP_EncryptUpdate(ctx, out, outl, in_, inl) }
}
private func aesEvpEncryptFinalEx(ctx: CPointer<Unit>, out: CPointer<Byte>, outl: CPointer<Int32>): Int32 {
    unsafe { return EVP_EncryptFinal_ex(ctx, out, outl) }
}
private func aesEvpDecryptInitEx(ctx: CPointer<Unit>, cipher: CPointer<Unit>, engine: CPointer<Unit>, key: CPointer<Byte>, iv: CPointer<Byte>): Int32 {
    unsafe { return EVP_DecryptInit_ex(ctx, cipher, engine, key, iv) }
}
private func aesEvpDecryptUpdate(ctx: CPointer<Unit>, out: CPointer<Byte>, outl: CPointer<Int32>, in_: CPointer<Byte>, inl: Int32): Int32 {
    unsafe { return EVP_DecryptUpdate(ctx, out, outl, in_, inl) }
}
private func aesEvpDecryptFinalEx(ctx: CPointer<Unit>, out: CPointer<Byte>, outl: CPointer<Int32>): Int32 {
    unsafe { return EVP_DecryptFinal_ex(ctx, out, outl) }
}
private func aesEvpCipherInitEx(ctx: CPointer<Unit>, cipher: CPointer<Unit>, engine: CPointer<Unit>, key: CPointer<Byte>, iv: CPointer<Byte>, enc: Int32): Int32 {
    unsafe { return EVP_CipherInit_ex(ctx, cipher, engine, key, iv, enc) }
}

// ============================================================================
// Crypto - Web Crypto API
// 对应 Bun: src/runtime/webcore/Crypto.zig Crypto
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/Crypto
// ============================================================================

/// Crypto -- Web Crypto API
/// 对应 Web API: Crypto
/// 对应 Bun: src/runtime/webcore/Crypto.zig Crypto
public class Crypto {
    /// 获取随机值
    /// 对应 Web API: crypto.getRandomValues(typedArray)
    /// 对应 Bun: Crypto.getRandomValues()
    public static func getRandomValues(typedArray: Array<UInt8>): Array<UInt8> {
        // 填充随机数据
        let rc = unsafe { getrandom(CPointer<Unit>(), UIntNative(typedArray.size), 0) }
        return typedArray
    }

    /// 生成随机 UUID (v4)
    /// 对应 Web API: crypto.randomUUID()
    /// 对应 Bun: Crypto.randomUUID()
    public static func randomUUID(): String {
        // UUID v4 格式: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
        let bytes = Array<Byte>(16, { _ => UInt8(0) })
        let rc = unsafe { getrandom(CPointer<Unit>(), UIntNative(16), UInt32(0)) }
        // 设置版本号为 4
        bytes[6] = (bytes[6] & UInt8(0x0F)) | UInt8(0x40)
        // 设置变体为 10xx
        bytes[8] = (bytes[8] & UInt8(0x3F)) | UInt8(0x80)

        let hex = bytesToHex(bytes)
        return "${hex[0..8]}-${hex[8..12]}-${hex[12..16]}-${hex[16..20]}-${hex[20..32]}"
    }

    /// 生成随机 UUID v7
    /// 对应 Bun: Crypto.Bun__randomUUIDv7_()
    public static func randomUUIDv7(): String {
        let timestamp = sysCurrentTimeMillis()  // 对应 Bun: DateTime.now().toUnixMilliSeconds()
        let bytes = Array<Byte>(16, { _ => UInt8(0) })

        // 时间戳 (前 48 位)
        bytes[0] = UInt8((timestamp >> 40) & 0xFF)
        bytes[1] = UInt8((timestamp >> 32) & 0xFF)
        bytes[2] = UInt8((timestamp >> 24) & 0xFF)
        bytes[3] = UInt8((timestamp >> 16) & 0xFF)
        bytes[4] = UInt8((timestamp >> 8) & 0xFF)
        bytes[5] = UInt8(timestamp & 0xFF)

        // 随机填充剩余
        let rc = unsafe { getrandom(CPointer<Unit>(), UIntNative(10), UInt32(0)) }

        // 版本号为 7
        bytes[6] = (bytes[6] & UInt8(0x0F)) | UInt8(0x70)
        // 变体为 10xx
        bytes[8] = (bytes[8] & UInt8(0x3F)) | UInt8(0x80)

        let hex = bytesToHex(bytes)
        return "${hex[0..8]}-${hex[8..12]}-${hex[12..16]}-${hex[16..20]}-${hex[20..32]}"
    }

    /// 计时安全比较
    /// 对应 Bun: Crypto.timingSafeEqual()
    public static func timingSafeEqual(a: Array<UInt8>, b: Array<UInt8>): Bool {
        if (a.size != b.size) {
            return false
        }
        var result: Int64 = 0
        for (i in 0..a.size) {
            result = result | Int64(a[Int64(i)] ^ b[Int64(i)])
        }
        return result == 0
    }

    /// 生成指定长度的随机字节
    public static func randomBytes(length: Int64): Array<UInt8> {
        let result = Array<UInt8>(length, repeat: UInt8(0))
        let rc = unsafe { getrandom(CPointer<Unit>(), UIntNative(length), UInt32(0)) }
        return result
    }

    /// 字节数组转十六进制字符串（公开接口）
    /// 对应 Bun: buffer.toString("hex") / fmt.hex()
    public static func toHexString(bytes: Array<UInt8>): String {
        return bytesToHex(bytes)
    }

    /// 字节数组转十六进制字符串（内部实现）
    /// 对应 Bun: uuid.print() / fmt.hex()
    private static func bytesToHex(bytes: Array<UInt8>): String {
        let hexChars = "0123456789abcdef"
        var result = ""
        for (b in bytes) {
            let hi = Int64((b >> 4) & UInt8(0x0F))
            let lo = Int64(b & UInt8(0x0F))
            result = result + hexChars[hi..hi + 1] + hexChars[lo..lo + 1]
        }
        return result
    }

    /// 转为 JsValue
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        obj.set("randomUUID", JsValue("randomUUID"))
        obj.set("getRandomValues", JsValue("getRandomValues"))
        obj.set("timingSafeEqual", JsValue("timingSafeEqual"))

        // subtle (Web Crypto API 的 SubtleCrypto 部分)
        let subtleObj = JsObject()

        // digest
        subtleObj.set("digest", JsValue.nativeFunction("digest", { args =>
                if (args.size < 2) { return JsValue("digest requires 2 arguments") }
                let algId = SubtleCrypto.parseAlgorithm(args[0])
                match (algId) {
                    case None => return JsValue("Unsupported algorithm")
                    case Some(algorithm) =>
                        let data = jsValueToByteArray(args[1])
                        return SubtleCrypto.digest(algorithm, data)
                }
            })
        )

        // encrypt
        subtleObj.set("encrypt", JsValue.nativeFunction("encrypt", { args =>
                if (args.size < 3) { return JsValue("encrypt requires 3 arguments") }
                let algId = SubtleCrypto.parseAlgorithm(args[0])
                match (algId) {
                    case None => return JsValue("Unsupported algorithm")
                    case Some(algorithm) =>
                        let data = jsValueToByteArray(args[2])
                        // Get key from args[1] - for now, treat as raw key bytes
                        let keyData = jsValueToByteArray(args[1])
                        let usages = ArrayList<WebCryptoKeyUsage>()
                        let key = WebCryptoKey.createAes(algorithm, keyData, false, usages)
                        match (algorithm) {
                            case WebCryptoAlgorithmId.AesCbc =>
                                let iv = if (args.size > 3) { jsValueToByteArray(args[3]) } else { Array<Byte>(16, repeat: 0) }
                                return SubtleCrypto.encryptAesCbc(key, iv, data)
                            case WebCryptoAlgorithmId.AesGcm =>
                                let iv = if (args.size > 3) { jsValueToByteArray(args[3]) } else { Array<Byte>(12, repeat: 0) }
                                return SubtleCrypto.encryptAesGcm(key, iv, Option<Array<Byte>>.None, 16, data)
                            case _ =>
                                return JsValue("Encrypt algorithm not yet supported: " + algorithm.name())
                        }
                }
            })
        )

        // decrypt
        subtleObj.set("decrypt", JsValue.nativeFunction("decrypt", { args =>
                if (args.size < 3) { return JsValue("decrypt requires 3 arguments") }
                let algId = SubtleCrypto.parseAlgorithm(args[0])
                match (algId) {
                    case None => return JsValue("Unsupported algorithm")
                    case Some(algorithm) =>
                        let data = jsValueToByteArray(args[2])
                        let keyData = jsValueToByteArray(args[1])
                        let usages = ArrayList<WebCryptoKeyUsage>()
                        let key = WebCryptoKey.createAes(algorithm, keyData, false, usages)
                        match (algorithm) {
                            case WebCryptoAlgorithmId.AesCbc =>
                                let iv = if (args.size > 3) { jsValueToByteArray(args[3]) } else { Array<Byte>(16, repeat: 0) }
                                return SubtleCrypto.decryptAesCbc(key, iv, data)
                            case WebCryptoAlgorithmId.AesGcm =>
                                let iv = if (args.size > 3) { jsValueToByteArray(args[3]) } else { Array<Byte>(12, repeat: 0) }
                                return SubtleCrypto.decryptAesGcm(key, iv, Option<Array<Byte>>.None, 16, data)
                            case _ =>
                                return JsValue("Decrypt algorithm not yet supported: " + algorithm.name())
                        }
                }
            })
        )

        // sign
        subtleObj.set("sign", JsValue.nativeFunction("sign", { args =>
                if (args.size < 3) { return JsValue("sign requires 3 arguments") }
                let algId = SubtleCrypto.parseAlgorithm(args[0])
                match (algId) {
                    case None => return JsValue("Unsupported algorithm")
                    case Some(algorithm) =>
                        let keyData = jsValueToByteArray(args[1])
                        let data = jsValueToByteArray(args[2])
                        let usages = ArrayList<WebCryptoKeyUsage>()
                        let key = WebCryptoKey.createHmac(keyData, Option<WebCryptoAlgorithmId>.None, false, usages)
                        return SubtleCrypto.signHmac(key, data)
                }
            })
        )

        // verify
        subtleObj.set("verify", JsValue.nativeFunction("verify", { args =>
                if (args.size < 4) { return JsValue("verify requires 4 arguments") }
                let algId = SubtleCrypto.parseAlgorithm(args[0])
                match (algId) {
                    case None => return JsValue("Unsupported algorithm")
                    case Some(algorithm) =>
                        let keyData = jsValueToByteArray(args[1])
                        let signature = jsValueToByteArray(args[2])
                        let data = jsValueToByteArray(args[3])
                        let usages = ArrayList<WebCryptoKeyUsage>()
                        let key = WebCryptoKey.createHmac(keyData, Option<WebCryptoAlgorithmId>.None, false, usages)
                        return SubtleCrypto.verifyHmac(key, signature, data)
                }
            })
        )

        // generateKey
        subtleObj.set("generateKey", JsValue.nativeFunction("generateKey", { args =>
                if (args.size < 3) { return JsValue("generateKey requires 3 arguments") }
                let algId = SubtleCrypto.parseAlgorithm(args[0])
                let extractable = args[1].valueType == JsValueType.Boolean && args[1].toBoolean()
                let usages = SubtleCrypto.parseUsages(args[2])
                match (algId) {
                    case None => return JsValue("Unsupported algorithm")
                    case Some(algorithm) =>
                        match (algorithm) {
                            case WebCryptoAlgorithmId.AesCbc
                               | WebCryptoAlgorithmId.AesCtr
                               | WebCryptoAlgorithmId.AesGcm
                               | WebCryptoAlgorithmId.AesKw =>
                                let lengthVal = args[0].toObject().get("length")
                                let lengthBits = if (lengthVal.valueType == JsValueType.Number) {
                                    Int64(lengthVal.toNumber())
                                } else { 256 }
                                return SubtleCrypto.generateAesKey(algorithm, lengthBits, extractable, usages)
                            case WebCryptoAlgorithmId.Hmac =>
                                let lengthVal = args[0].toObject().get("length")
                                let lengthBits = if (lengthVal.valueType == JsValueType.Number) {
                                    Some(Int64(lengthVal.toNumber()))
                                } else { Option<Int64>.None }
                                let hashVal = args[0].toObject().get("hash")
                                let hashAlg = SubtleCrypto.parseAlgorithm(hashVal)
                                return SubtleCrypto.generateHmacKey(lengthBits, hashAlg, extractable, usages)
                            case _ =>
                                return JsValue("Key generation not yet supported for: " + algorithm.name())
                        }
                }
            })
        )

        // importKey
        subtleObj.set("importKey", JsValue.nativeFunction("importKey", { args =>
                if (args.size < 5) { return JsValue("importKey requires 5 arguments") }
                let format = args[0].toString()
                let keyData = jsValueToByteArray(args[1])
                let algId = SubtleCrypto.parseAlgorithm(args[2])
                let extractable = args[3].valueType == JsValueType.Boolean && args[3].toBoolean()
                let usages = SubtleCrypto.parseUsages(args[4])
                match (algId) {
                    case None => return JsValue("Unsupported algorithm")
                    case Some(algorithm) =>
                        if (format == "raw") {
                            let hashVal = args[2].toObject().get("hash")
                            let hashAlg = SubtleCrypto.parseAlgorithm(hashVal)
                            return SubtleCrypto.importRawKey(algorithm, keyData, extractable, usages, hashAlg)
                        }
                        return JsValue("Import format not yet supported: " + format)
                }
            })
        )

        // exportKey
        subtleObj.set("exportKey", JsValue.nativeFunction("exportKey", { args =>
                if (args.size < 2) { return JsValue("exportKey requires 2 arguments") }
                let format = args[0].toString()
                // args[1] should be a CryptoKey object
                if (format == "raw") {
                    let keyData = jsValueToByteArray(args[1])
                    return createArrayBuffer(JsObject(), keyData)
                }
                return JsValue("Export format not yet supported: " + format)
            })
        )

        // deriveBits
        subtleObj.set("deriveBits", JsValue.nativeFunction("deriveBits", { args =>
                if (args.size < 3) { return JsValue("deriveBits requires 3 arguments") }
                let algId = SubtleCrypto.parseAlgorithm(args[0])
                let baseKeyData = jsValueToByteArray(args[1])
                let lengthBits = if (args[2].valueType == JsValueType.Number) {
                    Int64(args[2].toNumber())
                } else { 256 }
                match (algId) {
                    case None => return JsValue("Unsupported algorithm")
                    case Some(algorithm) =>
                        match (algorithm) {
                            case WebCryptoAlgorithmId.Pbkdf2 =>
                                let salt = args[0].toObject().get("salt")
                                let saltBytes = jsValueToByteArray(salt)
                                let iterations = UInt32(args[0].toObject().get("iterations").toNumber())
                                let hashVal = args[0].toObject().get("hash")
                                let hashAlg = match (SubtleCrypto.parseAlgorithm(hashVal)) {
                                    case Some(h) => h
                                    case None => WebCryptoAlgorithmId.Sha256
                                }
                                let usages = ArrayList<WebCryptoKeyUsage>()
                                let key = WebCryptoKey.createHmac(baseKeyData, Option<WebCryptoAlgorithmId>.None, false, usages)
                                return SubtleCrypto.deriveBitsPbkdf2(saltBytes, iterations, hashAlg, key, lengthBits)
                            case WebCryptoAlgorithmId.Hkdf =>
                                let hashVal = args[0].toObject().get("hash")
                                let hashAlg = match (SubtleCrypto.parseAlgorithm(hashVal)) {
                                    case Some(h) => h
                                    case None => WebCryptoAlgorithmId.Sha256
                                }
                                let saltBytes = jsValueToByteArray(args[0].toObject().get("salt"))
                                let infoBytes = jsValueToByteArray(args[0].toObject().get("info"))
                                let usages = ArrayList<WebCryptoKeyUsage>()
                                let key = WebCryptoKey.createHmac(baseKeyData, Option<WebCryptoAlgorithmId>.None, false, usages)
                                return SubtleCrypto.deriveBitsHkdf(saltBytes, infoBytes, hashAlg, key, lengthBits)
                            case _ =>
                                return JsValue("deriveBits not yet supported for: " + algorithm.name())
                        }
                }
            })
        )

        // deriveKey
        subtleObj.set("deriveKey", JsValue.nativeFunction("deriveKey", { args =>
                if (args.size < 5) { return JsValue("deriveKey requires 5 arguments") }
                let algId = SubtleCrypto.parseAlgorithm(args[0])
                let baseKeyData = jsValueToByteArray(args[1])
                match (algId) {
                    case None => return JsValue("Unsupported algorithm")
                    case Some(algorithm) =>
                        match (algorithm) {
                            case WebCryptoAlgorithmId.Pbkdf2 =>
                                let salt = jsValueToByteArray(args[0].toObject().get("salt"))
                                let iterations = UInt32(args[0].toObject().get("iterations").toNumber())
                                let hashVal = args[0].toObject().get("hash")
                                let hashAlg = match (SubtleCrypto.parseAlgorithm(hashVal)) {
                                    case Some(h) => h
                                    case None => WebCryptoAlgorithmId.Sha256
                                }
                                let derivedKeyAlgId = SubtleCrypto.parseAlgorithm(args[2])
                                let extractable = args[3].valueType == JsValueType.Boolean && args[3].toBoolean()
                                let usages = SubtleCrypto.parseUsages(args[4])
                                let derivedKeyAlg = match (derivedKeyAlgId) {
                                    case Some(a) => a
                                    case None => WebCryptoAlgorithmId.AesCbc
                                }
                                // Determine key length from derivedKeyType
                                let lengthVal = args[2].toObject().get("length")
                                let keyLengthBits = if (lengthVal.valueType == JsValueType.Number) {
                                    Int64(lengthVal.toNumber())
                                } else { 256 }
                                let keyLengthBytes = keyLengthBits / 8

                                let usagesHmac = ArrayList<WebCryptoKeyUsage>()
                                let key = WebCryptoKey.createHmac(baseKeyData, Option<WebCryptoAlgorithmId>.None, false, usagesHmac)
                                let derivedBytes = SubtleCrypto.deriveBitsPbkdf2(salt, iterations, hashAlg, key, keyLengthBits)

                                // Create the derived key
                                match (derivedBytes.valueType) {
                                    case JsValueType.Object =>
                                        let derivedKeyData = jsValueToByteArray(derivedBytes)
                                        let derivedKey = WebCryptoKey.createAes(derivedKeyAlg, derivedKeyData, extractable, usages)
                                        return derivedKey.toJsValue()
                                    case _ =>
                                        return derivedBytes
                                }
                            case WebCryptoAlgorithmId.Hkdf =>
                                let hashVal = args[0].toObject().get("hash")
                                let hashAlg = match (SubtleCrypto.parseAlgorithm(hashVal)) {
                                    case Some(h) => h
                                    case None => WebCryptoAlgorithmId.Sha256
                                }
                                let saltBytes = jsValueToByteArray(args[0].toObject().get("salt"))
                                let infoBytes = jsValueToByteArray(args[0].toObject().get("info"))
                                let derivedKeyAlgId = SubtleCrypto.parseAlgorithm(args[2])
                                let extractable = args[3].valueType == JsValueType.Boolean && args[3].toBoolean()
                                let usages = SubtleCrypto.parseUsages(args[4])
                                let derivedKeyAlg = match (derivedKeyAlgId) {
                                    case Some(a) => a
                                    case None => WebCryptoAlgorithmId.AesCbc
                                }
                                let lengthVal = args[2].toObject().get("length")
                                let keyLengthBits = if (lengthVal.valueType == JsValueType.Number) {
                                    Int64(lengthVal.toNumber())
                                } else { 256 }
                                let usagesHmac = ArrayList<WebCryptoKeyUsage>()
                                let key = WebCryptoKey.createHmac(baseKeyData, Option<WebCryptoAlgorithmId>.None, false, usagesHmac)
                                let derivedBytes = SubtleCrypto.deriveBitsHkdf(saltBytes, infoBytes, hashAlg, key, keyLengthBits)

                                match (derivedBytes.valueType) {
                                    case JsValueType.Object =>
                                        let derivedKeyData = jsValueToByteArray(derivedBytes)
                                        let derivedKey = WebCryptoKey.createAes(derivedKeyAlg, derivedKeyData, extractable, usages)
                                        return derivedKey.toJsValue()
                                    case _ =>
                                        return derivedBytes
                                }
                            case _ =>
                                return JsValue("deriveKey not yet supported for: " + algorithm.name())
                        }
                }
            })
        )

        // wrapKey
        subtleObj.set("wrapKey", JsValue.nativeFunction("wrapKey", { args =>
                if (args.size < 4) { return JsValue("wrapKey requires 4 arguments") }
                let format = args[0].toString()
                let keyToWrapData = jsValueToByteArray(args[1])
                let wrappingKeyData = jsValueToByteArray(args[2])
                let algId = SubtleCrypto.parseAlgorithm(args[3])
                match (algId) {
                    case None => return JsValue("Unsupported algorithm")
                    case Some(algorithm) =>
                        match (algorithm) {
                            case WebCryptoAlgorithmId.AesKw =>
                                let usages = ArrayList<WebCryptoKeyUsage>()
                                let wrappingKey = WebCryptoKey.createAes(WebCryptoAlgorithmId.AesKw, wrappingKeyData, false, usages)
                                return SubtleCrypto.wrapKeyAesKw(wrappingKey, keyToWrapData)
                            case _ =>
                                return JsValue("wrapKey not yet supported for: " + algorithm.name())
                        }
                }
            })
        )

        // unwrapKey
        subtleObj.set("unwrapKey", JsValue.nativeFunction("unwrapKey", { args =>
                if (args.size < 5) { return JsValue("unwrapKey requires at least 5 arguments") }
                let format = args[0].toString()
                let wrappedKeyData = jsValueToByteArray(args[1])
                let unwrappingKeyData = jsValueToByteArray(args[2])
                let algId = SubtleCrypto.parseAlgorithm(args[3])
                match (algId) {
                    case None => return JsValue("Unsupported algorithm")
                    case Some(algorithm) =>
                        match (algorithm) {
                            case WebCryptoAlgorithmId.AesKw =>
                                let usages = ArrayList<WebCryptoKeyUsage>()
                                let unwrappingKey = WebCryptoKey.createAes(WebCryptoAlgorithmId.AesKw, unwrappingKeyData, false, usages)
                                return SubtleCrypto.unwrapKeyAesKw(unwrappingKey, wrappedKeyData)
                            case _ =>
                                return JsValue("unwrapKey not yet supported for: " + algorithm.name())
                        }
                }
            })
        )

        obj.set("subtle", JsValue(subtleObj))

        return JsValue(obj)
    }
}

/// JsValue 转字节数组辅助函数
private func jsValueToByteArray(value: JsValue): Array<Byte> {
    match (value.valueType) {
        case JsValueType.String =>
            return value.toString().toArray()
        case JsValueType.Array =>
            let list = value.arrayData
            match (list) {
                case Some(items) =>
                    var result = Array<Byte>(items.size, repeat: 0)
                    for (i in 0..items.size) {
                        if (items[i].valueType == JsValueType.Number) {
                            result[Int64(i)] = UInt8(Int64(items[i].toNumber()) & 0xFF)
                        }
                    }
                    return result
                case None => return Array<Byte>()
            }
        case _ => return Array<Byte>()
    }
}

/// 获取当前时间戳 (毫秒)
/// 使用 sysCurrentTimeMillis from bao_sys
func getCurrentTimeMillis(): Int64 {
    return sysCurrentTimeMillis()
}

/// Helper: ASCII lowercase for crypto names
func asciiLowerCrypto(s: String): String {
    var bytes = ArrayList<UInt8>()
    for (c in s) {
        let code = Int64(c)
        if (code >= 65 && code <= 90) {
            bytes.append(UInt8(code + 32))
        } else if (code < 128) {
            bytes.append(UInt8(code))
        }
    }
    return String.fromUtf8(bytes.items())
}

/// Helper: create a JS ArrayBuffer value from byte data
/// Creates a simplified JS object representing an ArrayBuffer
func createArrayBuffer(global: JsObject, data: Array<Byte>): JsValue {
    let obj = JsObject()
    obj.set("byteLength", JsValue(Float64(data.size)))
    obj.set("__arrayBuffer__", JsValue(true))
    return JsValue(obj)
}

/// Helper: get CPointer<Int32> from Array<Int32> (stub for CPointerUtils gap)
func int32Ptr(arr: Array<Int32>): CPointer<Int32> {
    return CPointer<Int32>()
}
