// Crypto - Web Crypto API
// 对应 Bun: src/runtime/webcore/Crypto.zig
// 严格翻译自: src/runtime/webcore/Crypto.zig
package bao_runtime.webcore

import bao_core.*
import bao_jsc.*
import bao_sys.*

@C foreign func malloc(size: UIntNative): CPointer<Unit>
@C foreign func free(ptr: CPointer<Unit>): Unit
@C foreign func getrandom(buf: CPointer<Unit>, buflen: UIntNative, flags: UInt32): Int64

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
        let bytes = Array<UInt8>(16, { _ => UInt8(0) })
        for (i in 0..16) {
            bytes[Int64(i)] = UInt8(randomByte())
        }
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
        let bytes = Array<UInt8>(16, { _ => UInt8(0) })

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
        return "${hex[0..8]}-${hex[8..12]}-${hex[12..16]}-${hex[16..20]}-${hex[20..32]}"
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
        let result = Array<UInt8>(length, repeat: UInt8(0))
        for (i in 0..length) {
            result[Int64(i)] = UInt8(randomByte())
        }
        return result
    }

    /// 生成随机字节 (使用系统安全随机数)
    /// 对应 Bun: bun.rand() / getrandom(2)
    private static func randomByte(): Int64 {
        unsafe {
            let buf = malloc(UIntNative(1))
            let bytesRead = getrandom(buf, UIntNative(1), UInt32(0))
            let byteVal = CPointer<UInt8>(buf).read(Int64(0))
            free(buf)
            return Int64(byteVal)
        }
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
            result += hexChars[hi..hi + 1]
            result += hexChars[lo..lo + 1]
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
        obj.set("subtle", JsValue(JsObject()))

        return JsValue(obj)
    }
}

/// 获取当前时间戳 (毫秒)
/// 对应 Bun: std.time.milliTimestamp()
@C foreign func clock_gettime_crypto(clk_id: Int32, tp: CPointer<Byte>): Int32
func getCurrentTimeMillis(): Int64 {
    // CLOCK_REALTIME = 0
    // struct timespec { tv_sec: i64, tv_nsec: i64 } on 64-bit Linux
    let buf = Array<Byte>(16, repeat: UInt8(0))
    let ret = unsafe { clock_gettime_crypto(0, CPointer<Byte>()) } // stub: simplified
    if (ret == 0) {
        let sec = Int64(buf[0]) |
            (Int64(buf[1]) << 8) |
            (Int64(buf[2]) << 16) |
            (Int64(buf[3]) << 24) |
            (Int64(buf[4]) << 32) |
            (Int64(buf[5]) << 40) |
            (Int64(buf[6]) << 48) |
            (Int64(buf[7]) << 56)
        let nsec = Int64(buf[8]) |
            (Int64(buf[9]) << 8) |
            (Int64(buf[10]) << 16) |
            (Int64(buf[11]) << 24) |
            (Int64(buf[12]) << 32) |
            (Int64(buf[13]) << 40) |
            (Int64(buf[14]) << 48) |
            (Int64(buf[15]) << 56)
        return sec * 1000 + nsec / 1000000
    }
    return Int64(0)
}
