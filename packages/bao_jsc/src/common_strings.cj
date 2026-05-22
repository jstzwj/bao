// 严格翻译自: src/jsc/CommonStrings.zig (71行)
// 来自 BunCommonStrings.h 的常用字符串

package bao_jsc

// ========== CommonStringsForZig 枚举 ==========
// 严格翻译自 CommonStrings.zig CommonStringsForZig
// 常用字符串的枚举标识符，所有 getter 返回 JSC::JSString
public enum CommonStringsForZig {
    | IPv4
    | IPv6
    | IN4Loopback
    | IN6Any
    | IPv4Lower
    | IPv6Lower
    | FetchDefault
    | FetchError
    | FetchInclude
    | Buffer
    | BinaryTypeArrayBuffer
    | BinaryTypeNodeBuffer
    | BinaryTypeUint8Array
    | None

    public func toJS(globalObject: JsGlobalObject): JsValue {
        JsValue(this.toString())
    }

    public func toString(): String {
        match (this) {
            case IPv4 => "IPv4"
            case IPv6 => "IPv6"
            case IN4Loopback => "127.0.0.1"
            case IN6Any => "::"
            case IPv4Lower => "ipv4"
            case IPv6Lower => "ipv6"
            case FetchDefault => "default"
            case FetchError => "error"
            case FetchInclude => "include"
            case Buffer => "buffer"
            case BinaryTypeArrayBuffer => "arraybuffer"
            case BinaryTypeNodeBuffer => "nodebuffer"
            case BinaryTypeUint8Array => "uint8array"
            case None => ""
        }
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
    public func ipv4(): JsValue {
        CommonStringsForZig.IPv4.toJS(globalObject)
    }

    // 严格翻译自 IPv6
    public func ipv6(): JsValue {
        CommonStringsForZig.IPv6.toJS(globalObject)
    }

    // 严格翻译自 127.0.0.1 (IN4Loopback)
    public func loopback(): JsValue {
        CommonStringsForZig.IN4Loopback.toJS(globalObject)
    }

    // 严格翻译自 :: (IN6Any)
    public func in6Any(): JsValue {
        CommonStringsForZig.IN6Any.toJS(globalObject)
    }

    // 严格翻译自 ipv4 (小写)
    public func ipv4Lower(): JsValue {
        CommonStringsForZig.IPv4Lower.toJS(globalObject)
    }

    // 严格翻译自 ipv6 (小写)
    public func ipv6Lower(): JsValue {
        CommonStringsForZig.IPv6Lower.toJS(globalObject)
    }

    // 严格翻译自 default (fetch default)
    public func fetchDefault(): JsValue {
        CommonStringsForZig.FetchDefault.toJS(globalObject)
    }

    // 严格翻译自 error (fetch error)
    public func fetchError(): JsValue {
        CommonStringsForZig.FetchError.toJS(globalObject)
    }

    // 严格翻译自 include (fetch include)
    public func fetchInclude(): JsValue {
        CommonStringsForZig.FetchInclude.toJS(globalObject)
    }

    // 严格翻译自 buffer
    public func buffer(): JsValue {
        CommonStringsForZig.Buffer.toJS(globalObject)
    }

    // 严格翻译自 arraybuffer (binary type)
    public func arrayBuffer(): JsValue {
        CommonStringsForZig.BinaryTypeArrayBuffer.toJS(globalObject)
    }

    // 严格翻译自 nodebuffer (binary type)
    public func nodeBuffer(): JsValue {
        CommonStringsForZig.BinaryTypeNodeBuffer.toJS(globalObject)
    }

    // 严格翻译自 uint8array (binary type)
    public func uint8Array(): JsValue {
        CommonStringsForZig.BinaryTypeUint8Array.toJS(globalObject)
    }
}
