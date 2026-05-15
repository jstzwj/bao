// crypto_classes.cj - 加密类定义
// 对应 Bun: src/runtime/crypto/crypto.classes.ts
// 严格1:1翻译自 Bun crypto.classes.ts

package bao_runtime.crypto

import bao_core.*

// ============================================================================
// 加密类定义
// 对应 Bun: crypto.classes.ts 中 define() 定义的类
// ============================================================================

/// 加密类定义注册
/// 对应 Bun: crypto.classes.ts export default [...]
///
/// 定义了以下 JS 类:
/// - Crypto: getRandomValues, randomUUID, timingSafeEqual
/// - SHA1, MD5, MD4, SHA224, SHA512, SHA384, SHA256, SHA512_256
/// - CryptoHasher: hash, algorithms, digest, algorithm, update, copy, byteLength
public class CryptoClasses {

    /// 哈希器类名列表
    /// 对应 Bun: const names = ["SHA1", "MD5", "MD4", "SHA224", "SHA512", "SHA384", "SHA256", "SHA512_256"]
    public static let HASHER_NAMES: ArrayList<String> = ArrayList<String>([
        "SHA1", "MD5", "MD4", "SHA224", "SHA512", "SHA384", "SHA256", "SHA512_256"
    ])

    /// 哈希器对应摘要大小
    /// 对应各哈希器的 byteLength 属性
    public static func getDigestSize(name: String): Int64 {
        match (name) {
            case "MD4" => 16
            case "MD5" => 16
            case "SHA1" => 20
            case "SHA224" => 28
            case "SHA256" => 32
            case "SHA384" => 48
            case "SHA512" => 64
            case "SHA512_256" => 32
            case _ => 0
        }
    }

    /// Crypto 类定义
    /// 对应 Bun: define({ name: "Crypto", construct: true, finalize: false, ... })
    ///
    /// proto:
    ///   getRandomValues: fn "getRandomValues"
    ///   randomUUID: fn "randomUUID", length: 1
    ///   timingSafeEqual: fn "timingSafeEqual", length: 2
    /// klass: {}
    public static func createCryptoClass(globalObject: JsObject): JsValue {
        let obj = JsObject()
        // getRandomValues
        obj.set("getRandomValues", JsValue.nativeFunction(
            JsNativeFunction("getRandomValues", { global, args ->
                // TODO: 实现 getRandomValues
                return args[0]
            })
        ))
        // randomUUID
        obj.set("randomUUID", JsValue.nativeFunction(
            JsNativeFunction("randomUUID", { global, _ ->
                // TODO: 实现 randomUUID
                return JsValue(BaoString("00000000-0000-0000-0000-000000000000"))
            })
        ))
        // timingSafeEqual
        obj.set("timingSafeEqual", JsValue.nativeFunction(
            JsNativeFunction("timingSafeEqual", { global, args ->
                // TODO: 实现 timingSafeEqual
                return JsValue(false)
            })
        ))
        return JsValue(obj)
    }

    /// 各哈希器类定义
    /// 对应 Bun: define({ name: name, construct: true, finalize: true, ... })
    ///
    /// 每个哈希器类包含:
    ///   klass:
    ///     hash: fn "hash", length: 2
    ///     byteLength: getter "getByteLengthStatic"
    ///   proto:
    ///     digest: fn "digest", length: 0
    ///     update: fn "update", length: 1
    ///     byteLength: getter "getByteLength"
    public static func createHasherClass(globalObject: JsObject, name: String): JsValue {
        let obj = JsObject()

        // 静态方法: hash(input, output)
        obj.set("hash", JsValue.nativeFunction(
            JsNativeFunction("hash", { global, args ->
                // TODO: 分派到具体哈希器的静态 hash 方法
                return JsValue.UNDEFINED
            })
        ))

        // 静态属性: byteLength
        obj.set("byteLength", JsValue(Float64(getDigestSize(name))))

        return JsValue(obj)
    }

    /// CryptoHasher 类定义
    /// 对应 Bun: define({ name: "CryptoHasher", construct: true, finalize: true, ... })
    ///
    /// klass:
    ///   hash: fn "hash", length: 2
    ///   algorithms: getter "getAlgorithms", cache: true
    /// proto:
    ///   digest: fn "digest", length: 0
    ///   algorithm: getter "getAlgorithm", cache: true
    ///   update: fn "update", length: 2
    ///   copy: fn "copy", length: 0
    ///   byteLength: getter "getByteLength"
    public static func createCryptoHasherClass(globalObject: JsObject): JsValue {
        let obj = JsObject()

        // 静态方法: hash(algorithm, input, output)
        obj.set("hash", JsValue.nativeFunction(
            JsNativeFunction("hash", { global, args ->
                // TODO: 调用 CryptoHasher.hash_
                return JsValue.UNDEFINED
            })
        ))

        // 静态属性: algorithms (cached)
        obj.set("algorithms", CryptoHasher.getAlgorithms(globalObject))

        return JsValue(obj)
    }

    /// 注册所有加密类到全局对象
    public static func register(globalObject: JsObject): Unit {
        // Crypto 类
        globalObject.set("Crypto", createCryptoClass(globalObject))

        // 各静态哈希器类
        for (name in HASHER_NAMES) {
            globalObject.set(name, createHasherClass(globalObject, name))
        }

        // CryptoHasher 类
        globalObject.set("CryptoHasher", createCryptoHasherClass(globalObject))
    }
}
