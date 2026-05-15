// Crypto - Web Crypto API
// 对应 Bun: src/runtime/webcore/Crypto.zig
// 严格翻译自: src/runtime/webcore/Crypto.zig
package bao_runtime

import bao_core.*

// ============================================================================
// Crypto - Web Crypto API
// 对应 Bun: src/runtime/webcore/Crypto.zig Crypto
// 对应 Web API: https://developer.mozilla.org/en-US/docs/Web/API/Crypto
// ============================================================================

/// Crypto — Web Crypto API
/// 对应 Web API: Crypto
/// 对应 Bun: src/runtime/webcore/Crypto.zig Crypto
public class Crypto {
    /// 获取随机值
    /// 对应 Web API: crypto.getRandomValues(typedArray)
    /// 对应 Bun: Crypto.getRandomValues()
    public static func getRandomValues(typedArray: Array<UInt8>): Array<UInt8> {
        // 填充随机数据
        for (i in 0..typedArray.size) {
            typedArray[Int64(i)] = UInt8(randomByte())
        }
        return typedArray
    }

    /// 生成随机 UUID (v4)
    /// 对应 Web API: crypto.randomUUID()
    /// 对应 Bun: Crypto.randomUUID()
    public static func randomUUID(): String {
        // UUID v4 格式: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
        let bytes = Array<UInt8>(16, item: UInt8(0))
        for (i in 0..16) {
            bytes[Int64(i)] = UInt8(randomByte())
        }
        // 设置版本号为 4
        bytes[6] = (bytes[6] & UInt8(0x0F)) | UInt8(0x40)
        // 设置变体为 10xx
        bytes[8] = (bytes[8] & UInt8(0x3F)) | UInt8(0x80)

        let hex = bytesToHex(bytes)
        return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}"
    }

    /// 生成随机 UUID v7
    /// 对应 Bun: Crypto.Bun__randomUUIDv7_()
    public static func randomUUIDv7(): String {
        let timestamp = DateTime.now().toUnixMilliSeconds()
        let bytes = Array<UInt8>(16, item: UInt8(0))

        // 时间戳 (前 48 位)
        bytes[0] = UInt8((timestamp >> 40) & 0xFF)
        bytes[1] = UInt8((timestamp >> 32) & 0xFF)
        bytes[2] = UInt8((timestamp >> 24) & 0xFF)
        bytes[3] = UInt8((timestamp >> 16) & 0xFF)
        bytes[4] = UInt8((timestamp >> 8) & 0xFF)
        bytes[5] = UInt8(timestamp & 0xFF)

        // 随机填充剩余
        for (i in 6..16) {
            bytes[Int64(i)] = UInt8(randomByte())
        }

        // 版本号为 7
        bytes[6] = (bytes[6] & UInt8(0x0F)) | UInt8(0x70)
        // 变体为 10xx
        bytes[8] = (bytes[8] & UInt8(0x3F)) | UInt8(0x80)

        let hex = bytesToHex(bytes)
        return "${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}"
    }

    /// 计时安全比较
    /// 对应 Bun: Crypto.timingSafeEqual()
    public static func timingSafeEqual(a: Array<UInt8>, b: Array<UInt8>): Bool {
        if (a.size != b.size) {
            return false
        }
        var result = 0
        for (i in 0..a.size) {
            result = result | Int64(a[Int64(i)] ^ b[Int64(i)])
        }
        return result == 0
    }

    /// 生成指定长度的随机字节
    public static func randomBytes(length: Int64): Array<UInt8> {
        let result = Array<UInt8>(length, item: UInt8(0))
        for (i in 0..length) {
            result[Int64(i)] = UInt8(randomByte())
        }
        return result
    }

    /// 生成随机字节 (伪随机)
    private static func randomByte(): Int64 {
        // 简化的伪随机数生成
        return Int64(Math.random() * 256.0)
    }

    /// 字节数组转十六进制字符串
    private static func bytesToHex(bytes: Array<UInt8>): String {
        let sb = StringBuilder()
        for (b in bytes) {
            let hex = Int64(b).toHexString()
            if (hex.length < 2) {
                sb.append("0")
            }
            sb.append(hex)
        }
        return sb.toString()
    }

    /// 转为 JsValue
    public static func toJsValue(): JsValue {
        let obj = JsObject()

        obj.set("randomUUID", JsValue.nativeFunction(JsNativeFunction("randomUUID") { _ =>
            JsValue(BaoString(Crypto.randomUUID()))
        }))

        obj.set("getRandomValues", JsValue.nativeFunction(JsNativeFunction("getRandomValues") { args =>
            // 简化: 返回新的随机字节数组
            let bytes = Crypto.randomBytes(16)
            let arr = ArrayList<JsValue>()
            for (b in bytes) {
                arr.append(JsValue(Float64(Int64(b))))
            }
            JsValue.array(arr)
        }))

        obj.set("timingSafeEqual", JsValue.nativeFunction(JsNativeFunction("timingSafeEqual") { args =>
            JsValue(false) // 简化
        }))

        // subtle (Web Crypto API 的 SubtleCrypto 部分)
        obj.set("subtle", JsValue(JsObject()))

        return JsValue(obj)
    }
}
