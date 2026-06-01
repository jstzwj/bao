// Stub types for bao_runtime.webcore
// Types that are referenced from multiple files in the webcore package.

package bao_runtime.webcore

import bao_jsc.*
import bao_collections.ArrayList

/// WTFStringImpl — WebKit 字符串实现 (本地包装)
/// 对应 Bun: WTFStringImpl
public class WTFStringImpl {
    public var str: String

    public init() {
        str = ""
    }

    public init(s: String) {
        str = s
    }

    public static func empty(): WTFStringImpl {
        return WTFStringImpl()
    }

    public func toSlice(): String {
        return str
    }

    public func toUtf8Slice(): String {
        return str
    }

    public func size(): Int64 {
        return Int64(str.size)
    }

    public static func from(s: String): WTFStringImpl {
        return WTFStringImpl(s)
    }

    public func utf8ByteLength(): Int64 {
        return Int64(str.size)
    }

    public func byteSlice(): String {
        return str
    }

    public func memoryCost(): UInt64 {
        return UInt64(str.size)
    }

    public func toUtf8IfNeeded(): ?String {
        return Some(str)
    }

    public func latin1Slice(): String {
        return str
    }

    public func canUseAsUtf8(): Bool {
        return true
    }

    public func ref(): WTFStringImpl {
        return this
    }

    public func deref(): String {
        return str
    }

    public func toString(): String {
        return str
    }
}

/// DrainResult — 消费结果
/// 对应 Bun: DrainResult
public enum DrainResult {
    | Aborted
    | Empty
    | Owned(MutableString, Int64)
    | EstimatedSize(Int64)
}

/// ArrayBufferJSSink — ArrayBuffer JS 接收器
/// 对应 Bun: ArrayBufferJSSink
public class ArrayBufferJSSink {
    public var buffer: Array<UInt8>

    public init() {
        buffer = Array<UInt8>()
    }

    public func detach(): Array<UInt8> {
        let result = buffer
        buffer = Array<UInt8>()
        return result
    }

    public func getBytes(): Array<UInt8> {
        return buffer
    }
}

/// JsStrongOptional — 强引用可选值
/// 对应 Bun: jsc.strong.Optional
public class JsStrongOptional {
    public var value: ?JsValue

    public init() {
        value = None
    }

    public static func empty(): JsStrongOptional {
        return JsStrongOptional()
    }

    public func get(): ?JsValue {
        return value
    }

    public func deinit(): Unit {
        value = None
    }

    public static func create(v: JsValue): JsStrongOptional {
        let opt = JsStrongOptional()
        opt.value = Some(v)
        return opt
    }
}

/// MutableString — 可变字符串缓冲区
/// 对应 Bun: MutableString / std.ArrayList(u8) wrapper
public class MutableString {
    public var buffer: ArrayList<UInt8>

    public init() {
        buffer = ArrayList<UInt8>()
    }

    public func append(b: UInt8): Unit {
        buffer.append(b)
    }

    public func appendAll(data: Array<UInt8>): Unit {
        for (b in data) { buffer.append(b) }
    }

    public func toString(): String {
        return String.fromUtf8(buffer.items())
    }

    public func size(): Int64 {
        return Int64(buffer.size)
    }

    public func clear(): Unit {
        buffer = ArrayList<UInt8>()
    }

    public func write(data: Array<UInt8>): Unit {
        for (b in data) { buffer.append(b) }
    }

    public func asSlice(): Array<UInt8> {
        return buffer.items()
    }
}

/// HTTPHeaderName — HTTP 头名称枚举
/// 对应 Bun: HTTPHeaderName / bun.http.Headers
public enum HTTPHeaderName {
    | accept
    | contentType
    | contentLength
    | authorization
    | host
    | userAgent
    | connection
    | cacheControl
    | location
    | setCookie
    | cookie
    | origin
    | referer
    | accessControlAllowOrigin
    | accessControlAllowMethods
    | accessControlAllowHeaders
    | accessControlAllowCredentials
    | transferEncoding
    | contentEncoding
    | contentDisposition
    | other(String)
}
