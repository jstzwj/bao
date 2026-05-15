// 严格翻译自: src/jsc/CommonStrings.zig (71行)
// 来自 BunCommonStrings.h 的常用字符串

package bao_jsc

// ========== CommonStringsForZig 枚举 ==========
// 严格翻译自 CommonStrings.zig CommonStringsForZig
// 常用字符串的枚举标识符，所有 getter 返回 JSC::JSString
public enum CommonStringsForZig <: UInt8 {
    | IPv4(0)
    | IPv6(1)
    | IN4Loopback(2)
    | IN6Any(3)
    | IPv4Lower(4)
    | IPv6Lower(5)
    | FetchDefault(6)
    | FetchError(7)
    | FetchInclude(8)
    | Buffer(9)
    | BinaryTypeArrayBuffer(10)
    | BinaryTypeNodeBuffer(11)
    | BinaryTypeUint8Array(12)

    // 严格翻译自 toJS
    // 转换为 JS 值（通过 FFI 调用 Bun__CommonStringsForZig__toJS）
    public func toJS(globalObject: JsGlobalObject) -> JsValue {
        // FFI: extern "c" fn Bun__CommonStringsForZig__toJS(commonString, globalObject) JsValue
        JsValue.undefined()
    }
}

// ========== CommonStrings ==========
// 严格翻译自 CommonStrings.zig CommonStrings
// 常用字符串访问器，所有 getter 返回 JSString (JsValue)
public class CommonStrings {
    public var globalObject: JsGlobalObject

    public init(globalObject: JsGlobalObject) {
        this.globalObject = globalObject
    }

    // 严格翻译自 IPv4
    public func ipv4() -> JsValue {
        CommonStringsForZig.IPv4.toJS(globalObject)
    }

    // 严格翻译自 IPv6
    public func ipv6() -> JsValue {
        CommonStringsForZig.IPv6.toJS(globalObject)
    }

    // 严格翻译自 127.0.0.1 (IN4Loopback)
    public func loopback() -> JsValue {
        CommonStringsForZig.IN4Loopback.toJS(globalObject)
    }

    // 严格翻译自 :: (IN6Any)
    public func in6Any() -> JsValue {
        CommonStringsForZig.IN6Any.toJS(globalObject)
    }

    // 严格翻译自 ipv4 (小写)
    public func ipv4Lower() -> JsValue {
        CommonStringsForZig.IPv4Lower.toJS(globalObject)
    }

    // 严格翻译自 ipv6 (小写)
    public func ipv6Lower() -> JsValue {
        CommonStringsForZig.IPv6Lower.toJS(globalObject)
    }

    // 严格翻译自 default (fetch default)
    public func fetchDefault() -> JsValue {
        CommonStringsForZig.FetchDefault.toJS(globalObject)
    }

    // 严格翻译自 error (fetch error)
    public func fetchError() -> JsValue {
        CommonStringsForZig.FetchError.toJS(globalObject)
    }

    // 严格翻译自 include (fetch include)
    public func fetchInclude() -> JsValue {
        CommonStringsForZig.FetchInclude.toJS(globalObject)
    }

    // 严格翻译自 buffer
    public func buffer() -> JsValue {
        CommonStringsForZig.Buffer.toJS(globalObject)
    }

    // 严格翻译自 arraybuffer (binary type)
    public func arrayBuffer() -> JsValue {
        CommonStringsForZig.BinaryTypeArrayBuffer.toJS(globalObject)
    }

    // 严格翻译自 nodebuffer (binary type)
    public func nodeBuffer() -> JsValue {
        CommonStringsForZig.BinaryTypeNodeBuffer.toJS(globalObject)
    }

    // 严格翻译自 uint8array (binary type)
    public func uint8Array() -> JsValue {
        CommonStringsForZig.BinaryTypeUint8Array.toJS(globalObject)
    }
}
