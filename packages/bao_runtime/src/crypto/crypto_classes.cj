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
    public static func createCryptoClass(globalThis: JsObject): JsValue {
        let obj = JsObject()
        // getRandomValues
        obj.set("getRandomValues", JsValue.nativeFunction(
            JsNativeFunction("getRandomValues", { global, args  =>
                if (args.size == 0) { return JsValue.UNDEFINED }
                let value = args[0]
                match (value.arrayData) {
                    case Some(list) =>
                        var bytes = Array<Byte>(list.size, repeat: 0)
                        CryptoRandom.bytes(bytes)
                        for (i in 0..list.size) { list[i] = JsValue(Float64(Int64(bytes[i]))) }
                    case None => ()
                }
                return value
            })
        ))
        // randomUUID
        obj.set("randomUUID", JsValue.nativeFunction(
            JsNativeFunction("randomUUID", { global, _  =>
                var bytes = Array<Byte>(16, repeat: 0)
                CryptoRandom.bytes(bytes)
                bytes[6] = (bytes[6] & 0x0f) | 0x40
                bytes[8] = (bytes[8] & 0x3f) | 0x80
                return JsValue(BaoString(formatUuid(bytes)))
            })
        ))
        // timingSafeEqual
        obj.set("timingSafeEqual", JsValue.nativeFunction(
            JsNativeFunction("timingSafeEqual", { global, args  =>
                if (args.size < 2) { return JsValue(false) }
                let a = jsValueToBytes(args[0])
                let b = jsValueToBytes(args[1])
                if (a.size != b.size) { return JsValue(false) }
                var diff: Int64 = 0
                for (i in 0..a.size) { diff = diff | Int64(a[i] ^ b[i]) }
                return JsValue(diff == 0)
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
    public static func createHasherClass(globalThis: JsObject, name: String): JsValue {
        let obj = JsObject()

        // 静态方法: hash(input, output)
        obj.set("hash", JsValue.nativeFunction(
            JsNativeFunction("hash", { global, args  =>
                if (args.size == 0) { return JsValue.UNDEFINED }
                let input = jsValueToBytes(args[0])
                let output = if (args.size > 1 && args[1].valueType == JsValueType.String) { Some(args[1].stringValue.toString()) } else { None }
                return CryptoHasher.hashStatic(global, name, input, output)
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
    public static func createCryptoHasherClass(globalThis: JsObject): JsValue {
        let obj = JsObject()

        // 静态方法: hash(algorithm, input, output)
        obj.set("hash", JsValue.nativeFunction(
            JsNativeFunction("hash", { global, args  =>
                if (args.size < 2) { return JsValue.UNDEFINED }
                let algorithm = args[0].stringValue.toString()
                let input = jsValueToBytes(args[1])
                let output = if (args.size > 2 && args[2].valueType == JsValueType.String) { Some(args[2].stringValue.toString()) } else { None }
                return CryptoHasher.hashStatic(global, algorithm, input, output)
            })
        ))

        // 静态属性: algorithms (cached)
        obj.set("algorithms", CryptoHasher.getAlgorithms(globalObject))

        return JsValue(obj)
    }

    /// 注册所有加密类到全局对象
    public static func register(globalThis: JsObject): Unit {
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


private func jsValueToBytes(value: JsValue): Array<Byte> {
    match (value.valueType) {
        case JsValueType.String => return value.stringValue.toString().toArray()
        case JsValueType.Array =>
            let list = value.arrayData.getOrThrow()
            var out = Array<Byte>(list.size, { _ => Byte(0) })
            for (i in 0..list.size) { out[i] = Byte(Int64(list[i].toNumber()) & 0xff) }
            return out
        case _ => return Array<Byte>()
    }
}

private func formatUuid(bytes: Array<Byte>): String {
    let hex = "0123456789abcdef"
    var sb = StringBuilder()
    for (i in 0..16) {
        if (i == 4 || i == 6 || i == 8 || i == 10) { sb.append("-") }
        sb.append(hex[(bytes[i].toInt64() >> 4) & 0x0f])
        sb.append(hex[bytes[i].toInt64() & 0x0f])
    }
    return sb.toString()
}
